import { Response } from 'express';
import * as admin from 'firebase-admin';
import { AuthRequest } from '../../shared/middlewares/auth.middleware';
import {
  PomodoroTimerSchema,
  PomodoroMembersSchema,
  PomodoroSessionSchema,
} from './pomodoro.model';
import { zodError } from '../../shared/zod-error';

const firestore = () => admin.firestore();

const getTimerOr404 = async (id: string) => {
  const doc = await firestore().collection('pomodoroTimers').doc(id).get();
  if (!doc.exists) return null;
  return doc;
};

// Status is derived from timestamps, never stored — active while now is
// before startedAt + durationSec, unless the session was cancelled early.
const sessionStatus = (data: FirebaseFirestore.DocumentData) => {
  if (data.cancelledAt) return 'cancelled';
  const startedAtMs = data.startedAt?.toMillis?.() ?? 0;
  const endsAtMs = startedAtMs + data.durationSec * 1000;
  return Date.now() < endsAtMs ? 'active' : 'completed';
};

const areFriends = async (uidA: string, uidB: string) => {
  const [sent, received] = await Promise.all([
    firestore()
      .collection('friendRequests')
      .where('fromUid', '==', uidA)
      .where('toUid', '==', uidB)
      .where('status', '==', 'accepted')
      .limit(1)
      .get(),
    firestore()
      .collection('friendRequests')
      .where('fromUid', '==', uidB)
      .where('toUid', '==', uidA)
      .where('status', '==', 'accepted')
      .limit(1)
      .get(),
  ]);
  return !sent.empty || !received.empty;
};

export const createTimer = async (req: AuthRequest, res: Response) => {
  try {
    const uid = req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'Unauthorized' });

    const { purpose } = PomodoroTimerSchema.parse(req.body);
    const docRef = firestore().collection('pomodoroTimers').doc();
    await docRef.set({
      ownerUid: uid,
      purpose,
      memberUids: [uid],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return res.status(201).json({ message: 'Timer created', id: docRef.id });
  } catch (error: any) {
    return res.status(400).json({ error: zodError(error) });
  }
};

export const listTimers = async (req: AuthRequest, res: Response) => {
  try {
    const uid = req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'Unauthorized' });

    const snap = await firestore()
      .collection('pomodoroTimers')
      .where('memberUids', 'array-contains', uid)
      .get();

    const timers = snap.docs.map(doc => {
      const data = doc.data();
      return {
        id: doc.id,
        purpose: data.purpose,
        ownerUid: data.ownerUid,
        memberCount: (data.memberUids || []).length,
      };
    });

    return res.status(200).json(timers);
  } catch (error: any) {
    return res.status(500).json({ error: error.message });
  }
};

// One call for the whole detail screen: timer + member profiles + sessions
// (with derived status) so the client never has to stitch multiple requests.
export const getTimerDetail = async (req: AuthRequest, res: Response) => {
  try {
    const uid = req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'Unauthorized' });

    const timerDoc = await getTimerOr404(req.params.id as string);
    if (!timerDoc) return res.status(404).json({ error: 'Timer not found' });

    const timer = timerDoc.data()!;
    const memberUids: string[] = timer.memberUids || [];
    if (!memberUids.includes(uid))
      return res.status(403).json({ error: 'Not a member of this timer' });

    const [memberDocs, sessionsSnap] = await Promise.all([
      Promise.all(memberUids.map(m => firestore().collection('users').doc(m).get())),
      firestore()
        .collection('pomodoroSessions')
        .where('timerId', '==', timerDoc.id)
        .orderBy('startedAt', 'desc')
        .limit(50)
        .get(),
    ]);

    const members = memberDocs
      .filter(d => d.exists)
      .map(d => ({ uid: d.id, name: d.data()!.name, profilePic: d.data()!.profilePic || null }));

    const sessions = sessionsSnap.docs.map(doc => {
      const data = doc.data();
      return {
        id: doc.id,
        uid: data.uid,
        mode: data.mode,
        durationSec: data.durationSec,
        startedAt: data.startedAt?.toDate?.().toISOString() ?? null,
        status: sessionStatus(data),
      };
    });

    return res.status(200).json({
      timer: { id: timerDoc.id, purpose: timer.purpose, ownerUid: timer.ownerUid },
      members,
      sessions,
    });
  } catch (error: any) {
    return res.status(500).json({ error: error.message });
  }
};

export const addMembers = async (req: AuthRequest, res: Response) => {
  try {
    const uid = req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'Unauthorized' });

    const timerDoc = await getTimerOr404(req.params.id as string);
    if (!timerDoc) return res.status(404).json({ error: 'Timer not found' });

    const timer = timerDoc.data()!;
    if (timer.ownerUid !== uid)
      return res.status(403).json({ error: 'Only the owner can share this timer' });

    const { addUids } = PomodoroMembersSchema.parse(req.body);
    const friendChecks = await Promise.all(addUids.map(other => areFriends(uid, other)));
    if (friendChecks.some(isFriend => !isFriend)) {
      return res.status(400).json({ error: 'Can only share with friends' });
    }

    await timerDoc.ref.update({
      memberUids: admin.firestore.FieldValue.arrayUnion(...addUids),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return res.status(200).json({ message: 'Timer shared' });
  } catch (error: any) {
    return res.status(400).json({ error: zodError(error) });
  }
};

export const startSession = async (req: AuthRequest, res: Response) => {
  try {
    const uid = req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'Unauthorized' });

    const timerDoc = await getTimerOr404(req.params.id as string);
    if (!timerDoc) return res.status(404).json({ error: 'Timer not found' });
    if (!((timerDoc.data()!.memberUids || []) as string[]).includes(uid)) {
      return res.status(403).json({ error: 'Not a member of this timer' });
    }

    const { mode, durationSec } = PomodoroSessionSchema.parse(req.body);
    const docRef = firestore().collection('pomodoroSessions').doc();
    await docRef.set({
      timerId: timerDoc.id,
      uid,
      mode,
      durationSec,
      startedAt: admin.firestore.FieldValue.serverTimestamp(),
      cancelledAt: null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return res.status(201).json({ message: 'Session started', id: docRef.id });
  } catch (error: any) {
    return res.status(400).json({ error: zodError(error) });
  }
};

export const cancelSession = async (req: AuthRequest, res: Response) => {
  try {
    const uid = req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'Unauthorized' });

    const ref = firestore()
      .collection('pomodoroSessions')
      .doc(req.params.id as string);
    const doc = await ref.get();
    if (!doc.exists) return res.status(404).json({ error: 'Session not found' });
    if (doc.data()!.uid !== uid) return res.status(403).json({ error: 'Not your session' });

    await ref.update({ cancelledAt: admin.firestore.FieldValue.serverTimestamp() });

    return res.status(200).json({ message: 'Session cancelled' });
  } catch (error: any) {
    return res.status(500).json({ error: error.message });
  }
};

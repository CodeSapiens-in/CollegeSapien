import { Response } from 'express';
import * as admin from 'firebase-admin';
import { AuthRequest } from '../../shared/middlewares/auth.middleware';
import { AddFriendSchema } from './friends.model';
import { zodError } from '../../shared/zod-error';

const firestore = () => admin.firestore();

const publicProfile = (uid: string, data: FirebaseFirestore.DocumentData) => ({
  uid,
  name: data.name,
  email: data.email,
  profilePic: data.profilePic || null,
});

// Any non-rejected request between the two uids, in either direction.
const findLink = async (uidA: string, uidB: string) => {
  const [sent, received] = await Promise.all([
    firestore()
      .collection('friendRequests')
      .where('fromUid', '==', uidA)
      .where('toUid', '==', uidB)
      .limit(1)
      .get(),
    firestore()
      .collection('friendRequests')
      .where('fromUid', '==', uidB)
      .where('toUid', '==', uidA)
      .limit(1)
      .get(),
  ]);
  return sent.docs[0] || received.docs[0] || null;
};

export const getOverview = async (req: AuthRequest, res: Response) => {
  try {
    const uid = req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'Unauthorized' });

    const [fromSnap, toSnap] = await Promise.all([
      firestore().collection('friendRequests').where('fromUid', '==', uid).get(),
      firestore().collection('friendRequests').where('toUid', '==', uid).get(),
    ]);

    const acceptedUids: string[] = [];
    const incoming: { id: string; fromUid: string }[] = [];

    fromSnap.docs.forEach(doc => {
      const data = doc.data();
      if (data.status === 'accepted') acceptedUids.push(data.toUid);
    });
    toSnap.docs.forEach(doc => {
      const data = doc.data();
      if (data.status === 'accepted') acceptedUids.push(data.fromUid);
      else if (data.status === 'pending') incoming.push({ id: doc.id, fromUid: data.fromUid });
    });

    const otherUids = [...new Set([...acceptedUids, ...incoming.map(i => i.fromUid)])];
    const profiles = new Map<string, FirebaseFirestore.DocumentData>();
    await Promise.all(
      otherUids.map(async otherUid => {
        const doc = await firestore().collection('users').doc(otherUid).get();
        if (doc.exists) profiles.set(otherUid, doc.data()!);
      })
    );

    const friends = acceptedUids
      .filter(otherUid => profiles.has(otherUid))
      .map(otherUid => publicProfile(otherUid, profiles.get(otherUid)!));
    const incomingRequests = incoming
      .filter(r => profiles.has(r.fromUid))
      .map(r => ({ id: r.id, ...publicProfile(r.fromUid, profiles.get(r.fromUid)!) }));

    return res.status(200).json({ friends, incomingRequests });
  } catch (error: any) {
    return res.status(500).json({ error: error.message });
  }
};

// Always returns a generic success response — never reveals whether the
// email matched an account, to avoid email enumeration.
export const sendRequest = async (req: AuthRequest, res: Response) => {
  const generic = () =>
    res.status(200).json({ message: 'If that email is registered, a request was sent.' });

  try {
    const uid = req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'Unauthorized' });

    const { email } = AddFriendSchema.parse(req.body);

    const snap = await firestore()
      .collection('users')
      .where('email', '==', email)
      .where('deletedAt', '==', null)
      .limit(1)
      .get();
    if (snap.empty) return generic();

    const toUid = snap.docs[0].id;
    if (toUid === uid) return generic();

    const existingLink = await findLink(uid, toUid);
    if (existingLink && existingLink.data().status !== 'rejected') return generic();

    await firestore().collection('friendRequests').add({
      fromUid: uid,
      toUid,
      status: 'pending',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return generic();
  } catch (error: any) {
    return res.status(400).json({ error: zodError(error) });
  }
};

const respondToRequest = (accept: boolean) => async (req: AuthRequest, res: Response) => {
  try {
    const uid = req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'Unauthorized' });

    const ref = firestore()
      .collection('friendRequests')
      .doc(req.params.id as string);
    const doc = await ref.get();
    if (!doc.exists) return res.status(404).json({ error: 'Request not found' });

    const data = doc.data()!;
    if (data.toUid !== uid)
      return res.status(403).json({ error: 'Not your request to respond to' });
    if (data.status !== 'pending')
      return res.status(400).json({ error: 'Request already handled' });

    await ref.update({
      status: accept ? 'accepted' : 'rejected',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return res
      .status(200)
      .json({ message: accept ? 'Friend request accepted' : 'Friend request rejected' });
  } catch (error: any) {
    return res.status(500).json({ error: error.message });
  }
};

export const acceptRequest = respondToRequest(true);
export const rejectRequest = respondToRequest(false);

export const removeFriend = async (req: AuthRequest, res: Response) => {
  try {
    const uid = req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'Unauthorized' });

    const link = await findLink(uid, req.params.uid as string);
    if (link && link.data().status === 'accepted') {
      await link.ref.delete();
    }

    return res.status(200).json({ message: 'Friend removed' });
  } catch (error: any) {
    return res.status(500).json({ error: error.message });
  }
};

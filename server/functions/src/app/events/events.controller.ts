import { Response } from 'express';
import { AuthRequest } from '../../shared/middlewares/auth.middleware';
import * as admin from 'firebase-admin';
import { EventSchema, EventEditSchema } from './events.model';
import { zodError } from '../../shared/zod-error';

const firestore = () => admin.firestore();

// 1. Get all approved events (public or authenticated)
export const getApprovedEvents = async (req: AuthRequest, res: Response) => {
  try {
    const snapshot = await firestore()
      .collection('events')
      .where('status', '==', 'approved')
      .where('deletedAt', '==', null)
      .get();

    const data = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    return res.status(200).json(data);
  } catch (error: any) {
    return res.status(500).json({ error: error.message });
  }
};

// 2. Submit a new event (pending moderation)
export const createEvent = async (req: AuthRequest, res: Response) => {
  try {
    const uid = req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'Unauthorized' });

    const validated = EventSchema.parse({
      ...req.body,
      createdBy: uid,
      status: 'pending_moderation',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      deletedAt: null,
    });

    const { id, ...eventData } = validated;
    const docRef = id
      ? firestore().collection('events').doc(id)
      : firestore().collection('events').doc();

    if (id) {
      const existing = await docRef.get();
      if (existing.exists) {
        return res.status(409).json({ error: 'Event ID already exists' });
      }
    }

    await docRef.set(eventData);

    return res.status(201).json({
      message: 'Event created and pending moderation',
      id: docRef.id,
    });
  } catch (error: any) {
    return res.status(400).json({ error: zodError(error) });
  }
};

// 3. List pending events for moderation
export const getPendingEvents = async (req: AuthRequest, res: Response) => {
  try {
    const snapshot = await firestore()
      .collection('events')
      .where('status', '==', 'pending_moderation')
      .where('deletedAt', '==', null)
      .get();

    const data = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    return res.status(200).json(data);
  } catch (error: any) {
    return res.status(500).json({ error: error.message });
  }
};

// 4. Approve an event (optionally editing its fields first)
export const approveEvent = async (req: AuthRequest, res: Response) => {
  try {
    const uid = req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'Unauthorized' });

    let edits;
    try {
      edits = EventEditSchema.parse(req.body ?? {});
    } catch (error: any) {
      return res.status(400).json({ error: zodError(error) });
    }

    const id = req.params.id as string;
    const docRef = firestore().collection('events').doc(id);
    const doc = await docRef.get();

    if (!doc.exists || doc.data()?.deletedAt) {
      return res.status(404).json({ error: 'Event not found' });
    }
    if (doc.data()?.status !== 'pending_moderation') {
      return res.status(400).json({ error: 'Event is not pending moderation' });
    }

    await docRef.update({
      ...edits,
      status: 'approved',
      approvedBy: uid,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return res.status(200).json({ message: 'Event approved successfully' });
  } catch (error: any) {
    return res.status(500).json({ error: error.message });
  }
};

// 5. Reject an event
export const rejectEvent = async (req: AuthRequest, res: Response) => {
  try {
    const uid = req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'Unauthorized' });

    const id = req.params.id as string;
    const reason =
      typeof req.body?.reason === 'string' && req.body.reason.trim().length > 0
        ? req.body.reason.trim()
        : null;

    const docRef = firestore().collection('events').doc(id);
    const doc = await docRef.get();

    if (!doc.exists || doc.data()?.deletedAt) {
      return res.status(404).json({ error: 'Event not found' });
    }
    if (doc.data()?.status !== 'pending_moderation') {
      return res.status(400).json({ error: 'Event is not pending moderation' });
    }

    await docRef.update({
      status: 'rejected',
      deletedAt: admin.firestore.FieldValue.serverTimestamp(),
      rejectedBy: uid,
      rejectionReason: reason,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return res.status(200).json({ message: 'Event rejected and archived successfully' });
  } catch (error: any) {
    return res.status(500).json({ error: error.message });
  }
};

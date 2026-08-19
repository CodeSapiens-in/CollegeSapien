import { Response } from 'express';
import { AuthRequest } from '../../shared/middlewares/auth.middleware';
import { SubjectSchema } from './subjects.model';
import * as admin from 'firebase-admin';
import { zodError } from '../../shared/zod-error';
import { log } from '../../shared/logger';

export const createSubject = async (req: AuthRequest, res: Response) => {
  try {
    const uid = req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'Unauthorized' });

    const userDoc = await admin.firestore().collection('users').doc(uid!).get();
    const userCollegeId = userDoc.data()?.collegeId;

    if (!userCollegeId && req.user?.role !== 'superadmin') {
      return res.status(400).json({ error: 'User must belong to a college to create subjects' });
    }

    const collegeIdToUse = req.user?.role === 'superadmin' ? req.body.collegeId : userCollegeId;

    if (!collegeIdToUse) {
      return res.status(400).json({ error: 'collegeId is required' });
    }

    const validated = SubjectSchema.parse({
      ...req.body,
      code: String(req.body.code || '')
        .trim()
        .toUpperCase(),
      collegeId: collegeIdToUse,
      createdBy: uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      deletedAt: null,
    });

    const duplicate = await admin
      .firestore()
      .collection('subjects')
      .where('collegeId', '==', validated.collegeId)
      .where('code', '==', validated.code)
      .where('deletedAt', '==', null)
      .limit(1)
      .get();

    if (!duplicate.empty) {
      return res.status(409).json({ error: 'Subject already exists for this college' });
    }

    const docRef = await admin.firestore().collection('subjects').add(validated);
    return res.status(201).json({ message: 'Subject created', id: docRef.id });
  } catch (error: any) {
    return res.status(400).json({ error: zodError(error) });
  }
};

export const listSubjectsForCollege = async (req: AuthRequest, res: Response) => {
  try {
    const { collegeId } = req.params;
    const snapshot = await admin
      .firestore()
      .collection('subjects')
      .where('collegeId', '==', collegeId)
      .where('deletedAt', '==', null)
      .get();

    const data = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    return res.status(200).json(data);
  } catch (error: any) {
    log.error('Unhandled error', { path: res.req?.path, error: String(error) });
    return res.status(500).json({ error: 'Internal server error' });
  }
};

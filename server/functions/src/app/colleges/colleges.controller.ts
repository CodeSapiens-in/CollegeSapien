import { Response } from 'express';
import { AuthRequest } from '../../shared/middlewares/auth.middleware';
import { CollegeSchema } from './colleges.model';
import * as admin from 'firebase-admin';
import { zodError } from '../../shared/zod-error';
import { log } from '../../shared/logger';

export const createCollege = async (req: AuthRequest, res: Response) => {
  try {
    const validated = CollegeSchema.parse({
      ...req.body,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      deletedAt: null,
    });

    const docRef = await admin.firestore().collection('colleges').add(validated);
    return res.status(201).json({ message: 'College created', id: docRef.id });
  } catch (error: any) {
    return res.status(400).json({ error: zodError(error) });
  }
};

export const listColleges = async (req: AuthRequest, res: Response) => {
  try {
    const snapshot = await admin
      .firestore()
      .collection('colleges')
      .where('deletedAt', '==', null)
      .get();
    const data = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    return res.status(200).json(data);
  } catch (error: any) {
    log.error('Unhandled error', { path: res.req?.path, error: String(error) });
    return res.status(500).json({ error: 'Internal server error' });
  }
};

export const updateCollege = async (req: AuthRequest, res: Response) => {
  try {
    const id = req.params.id as string;
    const validated = CollegeSchema.partial().parse({
      ...req.body,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    await admin.firestore().collection('colleges').doc(id).update(validated);
    return res.status(200).json({ message: 'College updated' });
  } catch (error: any) {
    return res.status(400).json({ error: zodError(error) });
  }
};

export const deleteCollege = async (req: AuthRequest, res: Response) => {
  try {
    const id = req.params.id as string;
    // Soft delete
    await admin.firestore().collection('colleges').doc(id).update({
      deletedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return res.status(200).json({ message: 'College soft-deleted' });
  } catch (error: any) {
    log.error('Unhandled error', { path: res.req?.path, error: String(error) });
    return res.status(500).json({ error: 'Internal server error' });
  }
};

import { DepartmentSchema } from './colleges.model';

export const listCombined = async (req: AuthRequest, res: Response) => {
  try {
    const collegesSnapshot = await admin
      .firestore()
      .collection('colleges')
      .where('deletedAt', '==', null)
      .get();
      
    const departmentsSnapshot = await admin
      .firestore()
      .collection('departments')
      .where('deletedAt', '==', null)
      .get();
      
    const colleges = collegesSnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    const departments = departmentsSnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    
    return res.status(200).json({ colleges, departments });
  } catch (error: any) {
    log.error('Unhandled error', { path: res.req?.path, error: String(error) });
    return res.status(500).json({ error: 'Internal server error' });
  }
};

export const createDepartment = async (req: AuthRequest, res: Response) => {
  try {
    const validated = DepartmentSchema.parse({
      ...req.body,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      deletedAt: null,
    });
    
    const docRef = await admin.firestore().collection('departments').add(validated);
    return res.status(201).json({ message: 'Department created', id: docRef.id });
  } catch (error: any) {
    return res.status(400).json({ error: zodError(error) });
  }
};

export const listDepartments = async (req: AuthRequest, res: Response) => {
  try {
    const snapshot = await admin
      .firestore()
      .collection('departments')
      .where('deletedAt', '==', null)
      .get();
    const data = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    return res.status(200).json(data);
  } catch (error: any) {
    log.error('Unhandled error', { path: res.req?.path, error: String(error) });
    return res.status(500).json({ error: 'Internal server error' });
  }
};

export const updateDepartment = async (req: AuthRequest, res: Response) => {
  try {
    const id = req.params.id as string;
    const validated = DepartmentSchema.partial().parse({
      ...req.body,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    await admin.firestore().collection('departments').doc(id).update(validated);
    return res.status(200).json({ message: 'Department updated' });
  } catch (error: any) {
    return res.status(400).json({ error: zodError(error) });
  }
};

export const deleteDepartment = async (req: AuthRequest, res: Response) => {
  try {
    const id = req.params.id as string;
    // Soft delete
    await admin.firestore().collection('departments').doc(id).update({
      deletedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return res.status(200).json({ message: 'Department soft-deleted' });
  } catch (error: any) {
    log.error('Unhandled error', { path: res.req?.path, error: String(error) });
    return res.status(500).json({ error: 'Internal server error' });
  }
};

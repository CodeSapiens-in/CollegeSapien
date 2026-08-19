import { Response } from 'express';
import { AuthRequest } from '../../shared/middlewares/auth.middleware';
import * as admin from 'firebase-admin';
import { z } from 'zod';
import {
  archiveResourceForModeration,
  getModeratorScopeError,
  resolvePendingReportsForResource,
} from '../resources/resources.moderation';
import { log } from '../../shared/logger';

const firestore = () => admin.firestore();

const AssignRoleSchema = z.object({
  uid: z.string().min(1),
  role: z.enum(['user', 'ambassador', 'moderator', 'admin', 'superadmin']),
  collegeId: z.string().optional(),
});

const ResolveReportSchema = z.object({
  action: z.enum(['dismiss', 'ban_user', 'delete_resource']),
});

export const assignRole = async (req: AuthRequest, res: Response) => {
  try {
    const { uid, role, collegeId } = AssignRoleSchema.parse(req.body);

    const updateData: any = { role, updatedAt: admin.firestore.FieldValue.serverTimestamp() };
    if (collegeId) updateData.collegeId = collegeId;
    if (role === 'user') updateData.collegeId = admin.firestore.FieldValue.delete();

    await firestore().collection('users').doc(uid).update(updateData);

    // Update custom claims in Firebase Auth for secure token-based role check
    await admin.auth().setCustomUserClaims(uid, {
      role,
      ...(role !== 'user' && collegeId ? { collegeId } : {}),
    });

    return res.status(200).json({ message: `Role ${role} assigned to user ${uid}` });
  } catch (error: any) {
    log.error('Unhandled error', { path: res.req?.path, error: String(error) });
    return res.status(500).json({ error: 'Internal server error' });
  }
};

// Generic list users (Admin panel)
export const listUsers = async (req: AuthRequest, res: Response) => {
  try {
    const snapshot = await firestore().collection('users').where('deletedAt', '==', null).get();
    const data = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    return res.status(200).json(data);
  } catch (error: any) {
    log.error('Unhandled error', { path: res.req?.path, error: String(error) });
    return res.status(500).json({ error: 'Internal server error' });
  }
};

// Resolve a report
export const resolveReport = async (req: AuthRequest, res: Response) => {
  try {
    const uid = req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'Unauthorized' });

    const id = req.params.id as string;
    const { action } = ResolveReportSchema.parse(req.body);

    const reportRef = firestore().collection('reports').doc(id);
    const reportDoc = await reportRef.get();

    if (!reportDoc.exists) {
      return res.status(404).json({ error: 'Report not found' });
    }

    const reportData = reportDoc.data()!;
    if (reportData.status !== 'pending') {
      return res.status(400).json({ error: 'Report is already processed' });
    }

    const reportScopeError = getModeratorScopeError(
      req.user as any,
      reportData.collegeId,
      'Report'
    );
    if (reportScopeError) {
      return res.status(403).json({ error: reportScopeError });
    }

    const resourceId = typeof reportData.resourceId === 'string' ? reportData.resourceId : null;
    if (!resourceId) {
      return res.status(400).json({ error: 'Invalid report: missing resourceId' });
    }

    if (action === 'delete_resource' || action === 'ban_user') {
      const resourceRef = firestore().collection('hub_resources').doc(resourceId);
      const resourceDoc = await resourceRef.get();
      if (!resourceDoc.exists || resourceDoc.data()?.deletedAt) {
        return res.status(404).json({ error: 'Resource not found' });
      }

      const resourceScopeError = getModeratorScopeError(
        req.user as any,
        resourceDoc.data()?.collegeId,
        'Resource'
      );
      if (resourceScopeError) {
        return res.status(403).json({ error: resourceScopeError });
      }

      if (action === 'delete_resource') {
        const reason =
          typeof reportData.reason === 'string' && reportData.reason.trim().length > 0
            ? reportData.reason.trim()
            : 'Removed after report review';
        await archiveResourceForModeration(resourceRef, uid, reason);
        const resolvedCount = await resolvePendingReportsForResource(
          resourceId,
          uid,
          'delete_resource'
        );
        if (resolvedCount === 0) {
          await reportRef.update({
            status: 'resolved',
            resolutionAction: 'delete_resource',
            resolvedBy: uid,
            resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
        return res.status(200).json({ message: `Report resolved with action: ${action}` });
      }

      const uploaderId = resourceDoc.data()?.uploadedBy;
      if (uploaderId) {
        await admin.auth().updateUser(uploaderId, { disabled: true });
      }
    }

    await reportRef.update({
      status: action === 'dismiss' ? 'dismissed' : 'resolved',
      resolutionAction: action,
      resolvedBy: uid,
      resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return res.status(200).json({ message: `Report resolved with action: ${action}` });
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ error: error.issues[0]?.message || 'Invalid request payload' });
    }
    console.error('resolveReport failed', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
};

export const getUserById = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params as { id: string };
    const [docSnap, authUser] = await Promise.all([
      firestore().collection('users').doc(id).get(),
      admin
        .auth()
        .getUser(id)
        .catch(() => null),
    ]);
    if (!docSnap.exists) return res.status(404).json({ error: 'User not found' });
    return res.status(200).json({
      id: docSnap.id,
      ...docSnap.data(),
      disabled: authUser?.disabled ?? false,
    });
  } catch (error: any) {
    log.error('Unhandled error', { path: res.req?.path, error: String(error) });
    return res.status(500).json({ error: 'Internal server error' });
  }
};

export const banUser = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params as { id: string };
    await Promise.all([
      admin.auth().updateUser(id, { disabled: true }),
      firestore().collection('users').doc(id).update({
        bannedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }),
    ]);
    return res.status(200).json({ message: 'User banned' });
  } catch (error: any) {
    log.error('Unhandled error', { path: res.req?.path, error: String(error) });
    return res.status(500).json({ error: 'Internal server error' });
  }
};

export const unbanUser = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params as { id: string };
    await Promise.all([
      admin.auth().updateUser(id, { disabled: false }),
      firestore().collection('users').doc(id).update({
        bannedAt: admin.firestore.FieldValue.delete(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }),
    ]);
    return res.status(200).json({ message: 'User unbanned' });
  } catch (error: any) {
    log.error('Unhandled error', { path: res.req?.path, error: String(error) });
    return res.status(500).json({ error: 'Internal server error' });
  }
};

export const unarchiveResource = async (req: AuthRequest, res: Response) => {
  try {
    const uid = req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'Unauthorized' });

    const id = req.params.id as string;
    const docRef = firestore().collection('hub_resources').doc(id);
    const doc = await docRef.get();

    if (!doc.exists) return res.status(404).json({ error: 'Resource not found' });
    if (!doc.data()?.deletedAt) return res.status(400).json({ error: 'Resource is not archived' });

    const scopeError = getModeratorScopeError(req.user as any, doc.data()?.collegeId, 'Resource');
    if (scopeError) return res.status(403).json({ error: scopeError });

    await docRef.update({
      status: 'approved',
      deletedAt: null,
      rejectedBy: admin.firestore.FieldValue.delete(),
      rejectedReason: admin.firestore.FieldValue.delete(),
      rejectedAt: admin.firestore.FieldValue.delete(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return res.status(200).json({ message: 'Resource restored to approved' });
  } catch (error: any) {
    log.error('Unhandled error', { path: res.req?.path, error: String(error) });
    return res.status(500).json({ error: 'Internal server error' });
  }
};

export const getResourceStats = async (_req: AuthRequest, res: Response) => {
  try {
    const db = firestore();
    const [approvedNotes, approvedQPs, pending, syllabus] = await Promise.all([
      db
        .collection('hub_resources')
        .where('status', '==', 'approved')
        .where('category', '==', 'Notes')
        .where('deletedAt', '==', null)
        .count()
        .get(),
      db
        .collection('hub_resources')
        .where('status', '==', 'approved')
        .where('category', '==', 'QP')
        .where('deletedAt', '==', null)
        .count()
        .get(),
      db
        .collection('hub_resources')
        .where('status', '==', 'pending_moderation')
        .where('deletedAt', '==', null)
        .count()
        .get(),
      db
        .collection('hub_resources')
        .where('category', '==', 'Syllabus')
        .where('deletedAt', '==', null)
        .count()
        .get(),
    ]);
    return res.status(200).json({
      approvedNotes: approvedNotes.data().count,
      approvedQPs: approvedQPs.data().count,
      pendingModeration: pending.data().count,
      syllabus: syllabus.data().count,
    });
  } catch (error: any) {
    log.error('Unhandled error', { path: res.req?.path, error: String(error) });
    return res.status(500).json({ error: 'Internal server error' });
  }
};

export const getCmsContent = async (_req: AuthRequest, res: Response) => {
  try {
    const snapshot = await firestore().collection('app_content').orderBy('label').get();
    const entries = snapshot.docs.map(doc => ({ key: doc.id, ...doc.data() }));
    return res.status(200).json(entries);
  } catch (error: any) {
    log.error('Unhandled error', { path: res.req?.path, error: String(error) });
    return res.status(500).json({ error: 'Internal server error' });
  }
};

const UpdateCmsSchema = z.object({ value: z.string() });

export const updateCmsContent = async (req: AuthRequest, res: Response) => {
  try {
    const uid = req.user?.uid;
    const { key } = req.params as { key: string };
    const { value } = UpdateCmsSchema.parse(req.body);
    await firestore()
      .collection('app_content')
      .doc(key)
      .set(
        { value, updatedBy: uid, updatedAt: admin.firestore.FieldValue.serverTimestamp() },
        { merge: true }
      );
    return res.status(200).json({ message: 'CMS entry updated' });
  } catch (error: any) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ error: error.issues[0]?.message });
    }
    log.error('Unhandled error', { path: res.req?.path, error: String(error) });
    return res.status(500).json({ error: 'Internal server error' });
  }
};

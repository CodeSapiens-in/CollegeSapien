import { Response } from 'express';
import { AuthRequest } from '../../shared/middlewares/auth.middleware';
import * as admin from 'firebase-admin';
import { HubResourceSchema, ReportSchema } from './resources.model';
import { zodError } from '../../shared/zod-error';
import {
  archiveResourceForModeration,
  getModeratorScopeError,
  resolvePendingReportsForResource,
} from './resources.moderation';

const firestore = () => admin.firestore();

const getUserProfile = async (uid: string) => {
  const doc = await firestore().collection('users').doc(uid).get();
  return doc.exists ? doc.data() : null;
};

export const getSyllabus = async (req: AuthRequest, res: Response) => {
  try {
    const uid = req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'Unauthorized' });

    const { department, semester, regulation, query } = (req.query ?? {}) as Record<
      string,
      string | undefined
    >;
    const profile = await getUserProfile(uid);
    let ref: admin.firestore.Query = firestore()
      .collection('hub_resources')
      .where('category', '==', 'Syllabus')
      .where('status', '==', 'approved')
      .where('deletedAt', '==', null);

    if (profile?.collegeId) ref = ref.where('collegeId', '==', profile.collegeId);
    if (department) ref = ref.where('department', '==', department);
    if (regulation) ref = ref.where('regulation', '==', regulation);
    if (semester) ref = ref.where('semester', '==', Number(semester));

    const snapshot = await ref.get();
    let data = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));

    if (query) {
      const q = (query as string).toLowerCase();
      data = data.filter((item: any) => item.name?.toLowerCase().includes(q));
    }

    return res.status(200).json(data);
  } catch (error: any) {
    return res.status(500).json({ error: error.message });
  }
};

export const getHubResources = async (req: AuthRequest, res: Response) => {
  try {
    const uid = req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'Unauthorized' });

    const { category, type, department, semester, regulation } = (req.query ?? {}) as Record<
      string,
      string | undefined
    >; // category: Notes, QP
    const profile = await getUserProfile(uid);
    let ref: admin.firestore.Query = firestore().collection('hub_resources');

    if (profile?.collegeId) ref = ref.where('collegeId', '==', profile.collegeId);
    if (category) ref = ref.where('category', '==', category);
    if (type) ref = ref.where('type', '==', type);
    if (department) ref = ref.where('department', '==', department);
    if (regulation) ref = ref.where('regulation', '==', regulation);
    if (semester) ref = ref.where('semester', '==', Number(semester));
    ref = ref.where('status', '==', 'approved').where('deletedAt', '==', null);

    const snapshot = await ref.get();
    const data = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));

    return res.status(200).json(data);
  } catch (error: any) {
    return res.status(500).json({ error: error.message });
  }
};

export const listPendingResources = async (req: AuthRequest, res: Response) => {
  try {
    const uid = req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'Unauthorized' });

    const { category } = (req.query ?? {}) as Record<string, string | undefined>;
    let ref: admin.firestore.Query = firestore()
      .collection('hub_resources')
      .where('status', '==', 'pending_moderation')
      .where('deletedAt', '==', null);

    const role = (req.user as any)?.role;
    const collegeId = (req.user as any)?.collegeId;
    const scopeError = getModeratorScopeError(req.user as any, collegeId, 'Resource');
    if (scopeError) {
      return res.status(403).json({ error: scopeError });
    }

    if (role === 'moderator') {
      ref = ref.where('collegeId', '==', collegeId);
    }
    if (category) ref = ref.where('category', '==', category);

    const snapshot = await ref.get();
    const data = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    return res.status(200).json(data);
  } catch (error: any) {
    return res.status(500).json({ error: error.message });
  }
};

export const listApprovedResources = async (req: AuthRequest, res: Response) => {
  try {
    const uid = req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'Unauthorized' });

    const { category } = (req.query ?? {}) as Record<string, string | undefined>;
    const role = (req.user as any)?.role;
    const collegeId = (req.user as any)?.collegeId;

    let ref: admin.firestore.Query = firestore()
      .collection('hub_resources')
      .where('status', '==', 'approved')
      .where('deletedAt', '==', null);

    if (role === 'moderator') ref = ref.where('collegeId', '==', collegeId);
    if (category) ref = ref.where('category', '==', category);

    const snapshot = await ref.get();
    return res.status(200).json(snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() })));
  } catch (error: any) {
    return res.status(500).json({ error: error.message });
  }
};

export const listArchivedResources = async (req: AuthRequest, res: Response) => {
  try {
    const uid = req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'Unauthorized' });

    const { category } = (req.query ?? {}) as Record<string, string | undefined>;
    const role = (req.user as any)?.role;
    const collegeId = (req.user as any)?.collegeId;

    let ref: admin.firestore.Query = firestore()
      .collection('hub_resources')
      .where('deletedAt', '!=', null);

    if (role === 'moderator') ref = ref.where('collegeId', '==', collegeId);
    if (category) ref = ref.where('category', '==', category);

    const snapshot = await ref.get();
    return res.status(200).json(snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() })));
  } catch (error: any) {
    return res.status(500).json({ error: error.message });
  }
};

export const approveResource = async (req: AuthRequest, res: Response) => {
  try {
    const uid = req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'Unauthorized' });

    const id = req.params.id as string;
    const docRef = firestore().collection('hub_resources').doc(id);
    const doc = await docRef.get();

    if (!doc.exists || doc.data()?.deletedAt) {
      return res.status(404).json({ error: 'Resource not found' });
    }
    if (doc.data()?.status !== 'pending_moderation') {
      return res.status(400).json({ error: 'Resource is not pending moderation' });
    }

    const scopeError = getModeratorScopeError(req.user as any, doc.data()?.collegeId, 'Resource');
    if (scopeError) {
      return res.status(403).json({ error: scopeError });
    }

    await docRef.update({
      status: 'approved',
      approvedBy: uid,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return res.status(200).json({ message: 'Resource approved' });
  } catch (error: any) {
    return res.status(500).json({ error: error.message });
  }
};

export const rejectResource = async (req: AuthRequest, res: Response) => {
  try {
    const uid = req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'Unauthorized' });

    const id = req.params.id as string;
    const reason =
      typeof req.body?.reason === 'string' && req.body.reason.trim().length > 0
        ? req.body.reason.trim()
        : null;

    const docRef = firestore().collection('hub_resources').doc(id);
    const doc = await docRef.get();

    if (!doc.exists || doc.data()?.deletedAt) {
      return res.status(404).json({ error: 'Resource not found' });
    }
    if (doc.data()?.status !== 'pending_moderation') {
      return res.status(400).json({ error: 'Resource is not pending moderation' });
    }

    const scopeError = getModeratorScopeError(req.user as any, doc.data()?.collegeId, 'Resource');
    if (scopeError) {
      return res.status(403).json({ error: scopeError });
    }

    await archiveResourceForModeration(docRef, uid, reason);
    await resolvePendingReportsForResource(id, uid, 'delete_resource');

    return res.status(200).json({ message: 'Resource rejected and archived' });
  } catch (error) {
    console.error('rejectResource failed', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
};

export const uploadResource = async (req: AuthRequest, res: Response) => {
  try {
    const uid = req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'Unauthorized' });

    const profile = await getUserProfile(uid);
    if (!profile?.collegeId) {
      return res.status(400).json({ error: 'Complete onboarding before uploading resources' });
    }

    const validated = HubResourceSchema.parse({
      ...req.body,
      collegeId: profile.collegeId,
      department: req.body.department || profile.department,
      uploadedBy: uid,
      status: 'pending_moderation',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      deletedAt: null,
    });

    const { id, ...validatedResource } = validated;
    const resourceData = {
      ...validatedResource,
      uploaderName: profile.name || '',
    };

    const docRef = id
      ? firestore().collection('hub_resources').doc(id)
      : firestore().collection('hub_resources').doc();
    if (id && (await docRef.get()).exists) {
      return res.status(409).json({ error: 'Resource id already exists' });
    }
    await docRef.set(resourceData);

    return res.status(201).json({
      message: 'Resource uploaded and pending moderation',
      id: docRef.id,
    });
  } catch (error: any) {
    return res.status(400).json({ error: zodError(error) });
  }
};

export const reportResource = async (req: AuthRequest, res: Response) => {
  try {
    const uid = req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'Unauthorized' });

    const validated = ReportSchema.parse(req.body);
    const resourceDoc = await firestore()
      .collection('hub_resources')
      .doc(validated.resourceId)
      .get();
    if (!resourceDoc.exists || resourceDoc.data()?.deletedAt) {
      return res.status(404).json({ error: 'Resource not found' });
    }

    await firestore()
      .collection('reports')
      .add({
        ...validated,
        reportedBy: uid,
        collegeId: resourceDoc.data()?.collegeId || null,
        status: 'pending',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        deletedAt: null,
      });

    return res.status(201).json({ message: 'Report submitted' });
  } catch (error: any) {
    return res.status(400).json({ error: zodError(error) });
  }
};

export const updateResourceFileUrl = async (req: AuthRequest, res: Response) => {
  try {
    const uid = req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'Unauthorized' });

    const id = req.params.id as string;
    const { fileUrl, name } = req.body as { fileUrl?: string; name?: string };
    if (fileUrl !== undefined && typeof fileUrl !== 'string') {
      return res.status(400).json({ error: 'fileUrl must be a string' });
    }
    if (name !== undefined && (typeof name !== 'string' || !name.trim())) {
      return res.status(400).json({ error: 'name must be a non-empty string' });
    }
    if (fileUrl === undefined && name === undefined) {
      return res.status(400).json({ error: 'fileUrl or name is required' });
    }

    const docRef = firestore().collection('hub_resources').doc(id);
    const doc = await docRef.get();

    if (!doc.exists || doc.data()?.deletedAt) {
      return res.status(404).json({ error: 'Resource not found' });
    }
    if (doc.data()?.uploadedBy !== uid) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    await docRef.update({
      ...(fileUrl !== undefined ? { fileUrl } : {}),
      ...(name !== undefined ? { name: name.trim() } : {}),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return res.status(200).json({ message: 'Resource updated' });
  } catch (error: any) {
    return res.status(500).json({ error: error.message });
  }
};

export const deleteResource = async (req: AuthRequest, res: Response) => {
  try {
    const uid = req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'Unauthorized' });

    const id = req.params.id as string;
    const reason =
      typeof req.body?.reason === 'string' && req.body.reason.trim().length > 0
        ? req.body.reason.trim()
        : null;

    const resourceRef = firestore().collection('hub_resources').doc(id);
    const resourceDoc = await resourceRef.get();
    if (!resourceDoc.exists || resourceDoc.data()?.deletedAt) {
      return res.status(404).json({ error: 'Resource not found' });
    }

    const scopeError = getModeratorScopeError(
      req.user as any,
      resourceDoc.data()?.collegeId,
      'Resource'
    );
    if (scopeError) {
      return res.status(403).json({ error: scopeError });
    }

    await archiveResourceForModeration(resourceRef, uid, reason);
    await resolvePendingReportsForResource(id, uid, 'delete_resource');

    return res.status(200).json({ message: 'Resource rejected and archived' });
  } catch (error) {
    console.error('deleteResource failed', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
};

export const getReports = async (req: AuthRequest, res: Response) => {
  try {
    let ref: admin.firestore.Query = firestore()
      .collection('reports')
      .where('status', '==', 'pending');
    const role = (req.user as any)?.role;
    const collegeId = (req.user as any)?.collegeId;
    const scopeError = getModeratorScopeError(req.user as any, collegeId, 'Report');
    if (scopeError) {
      return res.status(403).json({ error: scopeError });
    }

    if (role === 'moderator') {
      ref = ref.where('collegeId', '==', collegeId);
    }

    const snapshot = await ref.get();
    const data = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    return res.status(200).json(data);
  } catch (error: any) {
    return res.status(500).json({ error: error.message });
  }
};

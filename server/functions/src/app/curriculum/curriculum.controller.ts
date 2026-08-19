import { Response } from 'express';
import * as admin from 'firebase-admin';
import { AuthRequest } from '../../shared/middlewares/auth.middleware';
import { zodError } from '../../shared/zod-error';
import { CurriculumEnvelopeSchema, CurriculumUpdateSchema, curriculumDocId } from './curriculum.model';
import { log } from '../../shared/logger';

const firestore = () => admin.firestore();

export const getCurriculum = async (req: AuthRequest, res: Response) => {
  try {
    const { collegeCode, courseCode, regulation } = (req.query ?? {}) as Record<
      string,
      string | undefined
    >;

    if (!collegeCode || !courseCode) {
      return res.status(400).json({ error: 'collegeCode and courseCode are required' });
    }

    if (regulation) {
      const doc = await firestore().collection('curricula').doc(
        curriculumDocId(collegeCode, courseCode, regulation)
      ).get();
      if (!doc.exists) {
        return res.status(404).json({ error: 'Curriculum not found' });
      }
      res.setHeader('Cache-Control', 'public, max-age=21600, s-maxage=21600');
      return res.status(200).json({ ...doc.data(), availableRegulations: [regulation] });
    }

    const snapshot = await firestore()
      .collection('curricula')
      .where('collegeCode', '==', collegeCode)
      .where('courseCode', '==', courseCode)
      .get();

    if (snapshot.empty) {
      return res.status(404).json({ error: 'Curriculum not found' });
    }

    const docs = snapshot.docs.map(d => d.data());
    const availableRegulations = docs
      .map(d => d.regulation)
      .filter((r): r is string => typeof r === 'string' && r.length > 0)
      .sort((a, b) => b.localeCompare(a));
    const latest = docs.find(d => d.regulation === availableRegulations[0]);
    if (!latest) {
      return res.status(404).json({ error: 'Curriculum not found' });
    }

    res.setHeader('Cache-Control', 'public, max-age=21600, s-maxage=21600');
    return res.status(200).json({ ...latest, availableRegulations });
  } catch (error: any) {
    log.error('getCurriculum error', { error: String(error), stack: error?.stack });
    return res.status(500).json({ error: error.message || 'Internal server error' });
  }
};

export const uploadPendingCurricula = async (req: AuthRequest, res: Response) => {
  try {
    const uid = req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'Unauthorized' });

    const items = req.body?.items;
    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ error: 'items[] is required and must not be empty' });
    }

    const overwriteKeys: string[] = Array.isArray(req.body?.overwriteKeys)
      ? req.body.overwriteKeys
      : [];

    const results = await Promise.all(
      items.map(async (item: any) => {
        const fileName = typeof item?.fileName === 'string' ? item.fileName : undefined;
        try {
          const envelope = CurriculumEnvelopeSchema.parse(item?.data ?? item);
          const key = `${envelope.college_code}|${envelope.course_code}|${envelope.regulation}`;
          const approvedId = curriculumDocId(envelope.college_code, envelope.course_code, envelope.regulation);

          const [approvedDoc, pendingSnapshot] = await Promise.all([
            firestore().collection('curricula').doc(approvedId).get(),
            firestore()
              .collection('curricula_pending')
              .where('collegeCode', '==', envelope.college_code)
              .where('courseCode', '==', envelope.course_code)
              .where('regulation', '==', envelope.regulation)
              .get(),
          ]);

          const existsInApproved = approvedDoc.exists;
          const existsInPending = !pendingSnapshot.empty;

          if ((existsInApproved || existsInPending) && !overwriteKeys.includes(key)) {
            return {
              fileName,
              conflict: true,
              collegeCode: envelope.college_code,
              courseCode: envelope.course_code,
              regulation: envelope.regulation,
              existsIn: existsInApproved && existsInPending ? 'both' : existsInApproved ? 'approved' : 'pending',
            };
          }

          const timestamp = admin.firestore.FieldValue.serverTimestamp();
          const docRef = firestore().collection('curricula_pending').doc();
          const batch = firestore().batch();
          pendingSnapshot.docs.forEach(d => batch.delete(d.ref));
          batch.set(docRef, {
            collegeCode: envelope.college_code,
            courseCode: envelope.course_code,
            regulation: envelope.regulation,
            college: envelope.college,
            course: envelope.course,
            subjects: envelope.subjects,
            status: 'pending',
            fileName: fileName ?? null,
            uploadedBy: uid,
            uploadedAt: timestamp,
            createdAt: timestamp,
            updatedAt: timestamp,
          });
          await batch.commit();

          return {
            fileName,
            id: docRef.id,
            collegeCode: envelope.college_code,
            courseCode: envelope.course_code,
            regulation: envelope.regulation,
            subjectCount: envelope.subjects.length,
          };
        } catch (error: any) {
          return { fileName, error: zodError(error) };
        }
      })
    );

    return res.status(200).json({ results });
  } catch (error: any) {
    log.error('uploadPendingCurricula error', { error: String(error), stack: error?.stack });
    return res.status(500).json({ error: error.message || 'Internal server error' });
  }
};

export const listPendingCurricula = async (req: AuthRequest, res: Response) => {
  try {
    const { collegeCode, courseCode, regulation } = (req.query ?? {}) as Record<
      string,
      string | undefined
    >;
    let ref: admin.firestore.Query = firestore().collection('curricula_pending');
    if (collegeCode) ref = ref.where('collegeCode', '==', collegeCode);
    if (courseCode) ref = ref.where('courseCode', '==', courseCode);
    if (regulation) ref = ref.where('regulation', '==', regulation);

    const snapshot = await ref.get();
    const data = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    return res.status(200).json(data);
  } catch (error: any) {
    log.error('Unhandled error', { path: res.req?.path, error: String(error) });
    return res.status(500).json({ error: 'Internal server error' });
  }
};

export const getPendingCurriculum = async (req: AuthRequest, res: Response) => {
  try {
    const id = req.params.id as string;
    const doc = await firestore().collection('curricula_pending').doc(id).get();
    if (!doc.exists) {
      return res.status(404).json({ error: 'Pending curriculum not found' });
    }
    return res.status(200).json({ id: doc.id, ...doc.data() });
  } catch (error: any) {
    log.error('Unhandled error', { path: res.req?.path, error: String(error) });
    return res.status(500).json({ error: 'Internal server error' });
  }
};

export const updatePendingCurriculum = async (req: AuthRequest, res: Response) => {
  try {
    const id = req.params.id as string;
    const docRef = firestore().collection('curricula_pending').doc(id);
    const doc = await docRef.get();
    if (!doc.exists) {
      return res.status(404).json({ error: 'Pending curriculum not found' });
    }

    const validated = CurriculumUpdateSchema.parse(req.body);
    await docRef.update({
      college: validated.college,
      collegeCode: validated.collegeCode,
      course: validated.course,
      courseCode: validated.courseCode,
      regulation: validated.regulation,
      subjects: validated.subjects,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const updated = await docRef.get();
    return res.status(200).json({ id: updated.id, ...updated.data() });
  } catch (error: any) {
    if (error?.issues) return res.status(400).json({ error: zodError(error) });
    log.error('updatePendingCurriculum error', { error: String(error), stack: error?.stack });
    return res.status(500).json({ error: error.message || 'Internal server error' });
  }
};

export const updateCurriculum = async (req: AuthRequest, res: Response) => {
  try {
    const uid = req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'Unauthorized' });

    const id = req.params.id as string;
    const docRef = firestore().collection('curricula').doc(id);
    const doc = await docRef.get();
    if (!doc.exists) {
      return res.status(404).json({ error: 'Curriculum not found' });
    }

    const validated = CurriculumUpdateSchema.parse(req.body);
    const existing = doc.data()!;
    const newId = curriculumDocId(validated.collegeCode, validated.courseCode, validated.regulation);
    const timestamp = admin.firestore.FieldValue.serverTimestamp();
    const updatedData = {
      college: validated.college,
      collegeCode: validated.collegeCode,
      course: validated.course,
      courseCode: validated.courseCode,
      regulation: validated.regulation,
      subjects: validated.subjects,
      status: 'approved',
      approvedBy: existing.approvedBy ?? uid,
      approvedAt: existing.approvedAt ?? timestamp,
      createdAt: existing.createdAt ?? timestamp,
      updatedAt: timestamp,
    };

    if (newId === id) {
      await docRef.update(updatedData);
      const updated = await docRef.get();
      return res.status(200).json({ id: updated.id, ...updated.data() });
    }

    const newRef = firestore().collection('curricula').doc(newId);
    if ((await newRef.get()).exists) {
      return res.status(409).json({
        error: `A curriculum already exists for ${validated.collegeCode}/${validated.courseCode}/${validated.regulation}`,
      });
    }

    const batch = firestore().batch();
    batch.set(newRef, updatedData);
    batch.delete(docRef);
    await batch.commit();

    return res.status(200).json({ id: newId, ...updatedData });
  } catch (error: any) {
    if (error?.issues) return res.status(400).json({ error: zodError(error) });
    log.error('updateCurriculum error', { error: String(error), stack: error?.stack });
    return res.status(500).json({ error: error.message || 'Internal server error' });
  }
};

export const listCurricula = async (req: AuthRequest, res: Response) => {
  try {
    const { collegeCode, courseCode, regulation } = (req.query ?? {}) as Record<
      string,
      string | undefined
    >;
    let ref: admin.firestore.Query = firestore().collection('curricula');
    if (collegeCode) ref = ref.where('collegeCode', '==', collegeCode);
    if (courseCode) ref = ref.where('courseCode', '==', courseCode);
    if (regulation) ref = ref.where('regulation', '==', regulation);

    const snapshot = await ref.get();
    const data = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    return res.status(200).json(data);
  } catch (error: any) {
    log.error('Unhandled error', { path: res.req?.path, error: String(error) });
    return res.status(500).json({ error: 'Internal server error' });
  }
};

const BATCH_CHUNK_SIZE = 500;

export const approvePendingCurricula = async (req: AuthRequest, res: Response) => {
  try {
    const uid = req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'Unauthorized' });

    const ids = req.body?.ids;
    if (!Array.isArray(ids) || ids.length === 0) {
      return res.status(400).json({ error: 'ids[] is required and must not be empty' });
    }

    const approved: string[] = [];
    const failed: { id: string; error: string }[] = [];

    for (let i = 0; i < ids.length; i += BATCH_CHUNK_SIZE) {
      const chunk = ids.slice(i, i + BATCH_CHUNK_SIZE) as string[];
      const batch = firestore().batch();
      const timestamp = admin.firestore.FieldValue.serverTimestamp();

      const pendingDocs = await Promise.all(
        chunk.map(id => firestore().collection('curricula_pending').doc(id).get())
      );

      pendingDocs.forEach((doc, idx) => {
        const id = chunk[idx];
        if (!doc.exists) {
          failed.push({ id, error: 'Pending curriculum not found' });
          return;
        }
        const data = doc.data()!;
        const targetRef = firestore()
          .collection('curricula')
          .doc(curriculumDocId(data.collegeCode, data.courseCode, data.regulation));

        batch.set(targetRef, {
          collegeCode: data.collegeCode,
          courseCode: data.courseCode,
          regulation: data.regulation,
          college: data.college,
          course: data.course,
          subjects: data.subjects,
          status: 'approved',
          approvedBy: uid,
          approvedAt: timestamp,
          createdAt: data.createdAt ?? timestamp,
          updatedAt: timestamp,
        });
        batch.delete(doc.ref);
        approved.push(id);
      });

      await batch.commit();
    }

    return res.status(200).json({ approved, failed });
  } catch (error: any) {
    log.error('approvePendingCurricula error', { error: String(error), stack: error?.stack });
    return res.status(500).json({ error: error.message || 'Internal server error' });
  }
};

export const rejectPendingCurricula = async (req: AuthRequest, res: Response) => {
  try {
    const ids = req.body?.ids;
    if (!Array.isArray(ids) || ids.length === 0) {
      return res.status(400).json({ error: 'ids[] is required and must not be empty' });
    }

    for (let i = 0; i < ids.length; i += BATCH_CHUNK_SIZE) {
      const chunk = ids.slice(i, i + BATCH_CHUNK_SIZE) as string[];
      const batch = firestore().batch();
      chunk.forEach(id => batch.delete(firestore().collection('curricula_pending').doc(id)));
      await batch.commit();
    }

    return res.status(200).json({ rejected: ids });
  } catch (error: any) {
    log.error('rejectPendingCurricula error', { error: String(error), stack: error?.stack });
    return res.status(500).json({ error: error.message || 'Internal server error' });
  }
};

export const deleteCurriculum = async (req: AuthRequest, res: Response) => {
  try {
    const id = req.params.id as string;
    const docRef = firestore().collection('curricula').doc(id);
    const doc = await docRef.get();
    if (!doc.exists) {
      return res.status(404).json({ error: 'Curriculum not found' });
    }
    await docRef.delete();
    return res.status(200).json({ success: true, message: 'Curriculum deleted successfully' });
  } catch (error: any) {
    log.error('deleteCurriculum error', { error: String(error), stack: error?.stack });
    return res.status(500).json({ error: error.message || 'Internal server error' });
  }
};

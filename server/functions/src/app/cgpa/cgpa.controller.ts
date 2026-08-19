import { Response } from 'express';
import { AuthRequest } from '../../shared/middlewares/auth.middleware';
import { InternalMarksSchema, SemestersSchema } from './cgpa.model';
import type { GoogleGenerativeAI } from '@google/generative-ai';
import * as admin from 'firebase-admin';
import { log } from '../../shared/logger';

// calculateCGPA (the only caller) is currently disabled — see its early 503 return below.
// Defer loading @google/generative-ai (~700KB) so it doesn't cost every cold start of this route.
let genAIPromise: Promise<GoogleGenerativeAI> | undefined;

function getGenAI(): Promise<GoogleGenerativeAI> {
  genAIPromise ??= import('@google/generative-ai').then(
    ({ GoogleGenerativeAI }) => new GoogleGenerativeAI(process.env.GEMINI_API_KEY || '')
  );
  return genAIPromise;
}

export const calculateCGPA = async (req: AuthRequest, res: Response) => {
  return res.status(503).json({ error: 'CGPA image scanning is temporarily unavailable.' });

  try {
    const { imageBase64 } = req.body;
    if (!imageBase64) return res.status(400).json({ error: 'Image data is required' });

    const genAI = await getGenAI();
    const model = genAI.getGenerativeModel({ model: 'gemini-3.1-pro-preview' });
    const prompt =
      "Parse this grade sheet image and calculate the GPA and CGPA. Return a JSON object with fields 'gpa', 'cgpa', and 'subjects' (array of { name, grade, credits }).";

    const result = await model.generateContent([
      prompt,
      {
        inlineData: {
          data: imageBase64,
          mimeType: 'image/png',
        },
      },
    ]);

    const response = await result.response;
    const text = response.text();
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    const resultJson = jsonMatch
      ? JSON.parse(jsonMatch![0])
      : { error: 'Could not parse JSON', raw: text };

    return res.status(200).json(resultJson);
  } catch (error: any) {
    log.error('Unhandled error', { path: res.req?.path, error: String(error) });
    return res.status(500).json({ error: 'Internal server error' });
  }
};

export const predictExternalMarks = async (req: AuthRequest, res: Response) => {
  try {
    const validated = InternalMarksSchema.parse(req.body);
    const { internalMarks, maxInternalMarks, targetGrade } = validated;

    if (internalMarks > maxInternalMarks) {
      return res.status(400).json({ error: 'Internal marks cannot exceed max internal marks' });
    }

    // Grade to Points (Anna University style example)
    const gradePoints: Record<string, number> = {
      O: 91,
      'A+': 81,
      A: 71,
      'B+': 61,
      B: 51,
    };

    const targetTotal = gradePoints[targetGrade];
    const externalWeightage = 100 - maxInternalMarks;

    // Total needed from external = Target - Internal
    const externalNeeded = targetTotal - internalMarks;

    // Scale external needed to 100 if exam is out of 100.
    // If the exam is out of 100 but weightage is `externalWeightage`,
    // then (marks_obtained / 100) * externalWeightage = externalNeeded.
    // marks_obtained = (externalNeeded / externalWeightage) * 100
    const marksToGetOutOf100 = Math.ceil((externalNeeded / externalWeightage) * 100);

    return res.status(200).json({
      targetGrade,
      internalMarks,
      maxInternalMarks,
      requiredInExternalOutOf100: Math.max(0, marksToGetOutOf100),
      message:
        marksToGetOutOf100 > 100
          ? 'Impossible to reach this grade with current internals, machi!'
          : `You need ${Math.max(0, marksToGetOutOf100)} out of 100 in external to get ${targetGrade}. Semma target!`,
    });
  } catch (error: any) {
    return res.status(400).json({ error: error.message });
  }
};

export const getSemesters = async (req: AuthRequest, res: Response) => {
  try {
    const uid = req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'Unauthorized' });

    const doc = await admin
      .firestore()
      .collection('users')
      .doc(uid)
      .collection('cgpa')
      .doc('semesters')
      .get();

    if (!doc.exists) return res.status(200).json({ semesters: [] });
    return res.status(200).json(doc.data());
  } catch (error: any) {
    log.error('Unhandled error', { path: res.req?.path, error: String(error) });
    return res.status(500).json({ error: 'Internal server error' });
  }
};

export const saveSemesters = async (req: AuthRequest, res: Response) => {
  try {
    const uid = req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'Unauthorized' });

    const validated = SemestersSchema.parse(req.body);

    await admin
      .firestore()
      .collection('users')
      .doc(uid)
      .collection('cgpa')
      .doc('semesters')
      .set({
        ...validated,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    return res.status(200).json({ message: 'Semesters saved' });
  } catch (error: any) {
    return res.status(400).json({ error: error.message });
  }
};

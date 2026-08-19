import { Response } from 'express';
import { AuthRequest } from '../../shared/middlewares/auth.middleware';
import { TimetableSchema } from './timetable.model';
import * as admin from 'firebase-admin';
import type { GoogleGenerativeAI } from '@google/generative-ai';
import { zodError } from '../../shared/zod-error';
import { log } from '../../shared/logger';

// parseTimetable (the only caller) is currently disabled — see its early 503 return below.
// Defer loading @google/generative-ai (~700KB) so it doesn't cost every cold start of this route.
let genAIPromise: Promise<GoogleGenerativeAI> | undefined;

function getGenAI(): Promise<GoogleGenerativeAI> {
  genAIPromise ??= import('@google/generative-ai').then(
    ({ GoogleGenerativeAI }) => new GoogleGenerativeAI(process.env.GEMINI_API_KEY || '')
  );
  return genAIPromise;
}

export const uploadTimetable = async (req: AuthRequest, res: Response) => {
  try {
    const uid = req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'Unauthorized' });

    const userDoc = await admin.firestore().collection('users').doc(uid).get();
    const currentSemester = userDoc.data()?.semester || 1;

    const validatedData = TimetableSchema.parse(req.body);

    const timetableRef = admin
      .firestore()
      .collection('users')
      .doc(uid)
      .collection('semesters')
      .doc(String(currentSemester));
    const existingTimetable = await timetableRef.get();
    const attendanceTrackingStartDate = existingTimetable.data()?.attendanceTrackingStartDate;

    await timetableRef.set(
      {
        ...validatedData,
        ...(attendanceTrackingStartDate
          ? {}
          : { attendanceTrackingStartDate: new Date().toISOString().slice(0, 10) }),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return res.status(200).json({ message: 'Timetable updated successfully' });
  } catch (error: any) {
    return res.status(400).json({ error: zodError(error) });
  }
};

export const getTimetable = async (req: AuthRequest, res: Response) => {
  try {
    const uid = req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'Unauthorized' });

    const userDoc = await admin.firestore().collection('users').doc(uid).get();
    const currentSemester = userDoc.data()?.semester || 1;

    const timetableDoc = await admin
      .firestore()
      .collection('users')
      .doc(uid)
      .collection('semesters')
      .doc(String(currentSemester))
      .get();

    if (!timetableDoc.exists) {
      return res.status(404).json({ error: 'Timetable not found' });
    }

    return res.status(200).json(timetableDoc.data());
  } catch (error: any) {
    log.error('Unhandled error', { path: res.req?.path, error: String(error) });
    return res.status(500).json({ error: 'Internal server error' });
  }
};

export const deleteTimetable = async (req: AuthRequest, res: Response) => {
  try {
    const uid = req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'Unauthorized' });

    const userDoc = await admin.firestore().collection('users').doc(uid).get();
    const semester = String(userDoc.data()?.semester || 1);
    const ref = admin
      .firestore()
      .collection('users')
      .doc(uid)
      .collection('semesters')
      .doc(semester);

    if (!(await ref.get()).exists) {
      return res.status(404).json({ error: 'Timetable not found' });
    }

    await ref.delete();
    return res.status(200).json({ message: 'Timetable deleted' });
  } catch (error: any) {
    log.error('Unhandled error', { path: res.req?.path, error: String(error) });
    return res.status(500).json({ error: 'Internal server error' });
  }
};

const codeFromName = (name: string): string => {
  const words = name.split(/\s+/).filter(w => w.length > 2);
  if (words.length >= 2) return words.map(w => w[0].toUpperCase()).join('');
  return name.replace(/\s+/g, '').slice(0, 4).toUpperCase() || 'SUB';
};

export const parseTimetable = async (req: AuthRequest, res: Response) => {
  return res.status(503).json({ error: 'Timetable image scanning is temporarily unavailable.' });

  try {
    const { imageBase64 } = req.body;
    if (!imageBase64) return res.status(400).json({ error: 'Image data is required' });

    const genAI = await getGenAI();
    const model = genAI.getGenerativeModel({ model: 'gemini-3.1-pro-preview' });
    const prompt =
      'Extract the college timetable from this image. Return ONLY a raw JSON object (no markdown, no code fences) matching this schema: { "subjects": [{ "id": "string", "name": "string", "code": "string", "classes": [{ "day": "MON|TUE|WED|THU|FRI|SAT|SUN", "startTime": "HH:MM", "endTime": "HH:MM", "room": "string", "type": "CORE|LAB|BREAK" }] }] }. Rules: (1) All field values must be strings. (2) Days must be MON, TUE, WED, THU, FRI, SAT, or SUN. (3) If a subject code is not visible in the image, derive one by taking the first letter of each significant word in the subject name (e.g. "Data Structures" → "DS"). (4) If a room or location is not shown, use an empty string "". (5) Use the subject code as the id if no separate id is present. (6) Do NOT include Lunch, Break, Free Period, Interval, or any non-academic time slots as subjects — skip them entirely. These are not subjects and must not appear in the subjects array.';

    const result = await model.generateContent([
      prompt,
      {
        inlineData: {
          data: imageBase64,
          mimeType: 'image/jpeg',
        },
      },
    ]);

    const response = await result.response;
    const text = response.text();
    const stripped = text.replace(/```(?:json)?\n?/g, '').trim();
    const jsonMatch = stripped.match(/\{[\s\S]*\}/);
    if (!jsonMatch) {
      return res.status(200).json({ error: 'Could not parse JSON', raw: text });
    }

    const resultJson = JSON.parse(jsonMatch![0]);

    // Normalize subjects so missing code/id/room never reach the Flutter app as null
    if (Array.isArray(resultJson.subjects)) {
      resultJson.subjects = resultJson.subjects.map((subject: any) => {
        const name: string = subject.name?.toString() || 'Untitled Subject';
        const code: string = subject.code?.toString().trim() || codeFromName(name);
        const id: string = subject.id?.toString().trim() || code;
        const classes = (subject.classes || []).map((cls: any) => ({
          ...cls,
          room: cls.room?.toString() ?? '',
        }));
        return { ...subject, id, name, code, classes };
      });
    }

    return res.status(200).json(resultJson);
  } catch (error: any) {
    log.error('Unhandled error', { path: res.req?.path, error: String(error) });
    return res.status(500).json({ error: 'Internal server error' });
  }
};

import { Response } from 'express';
import { AuthRequest } from '../../shared/middlewares/auth.middleware';
import { OnboardingSchema, ProfileUpdateSchema } from './auth.model';
import * as admin from 'firebase-admin';
import { zodError } from '../../shared/zod-error';
import {
  computeAttendanceSummary,
  ensureAttendanceTrackingStartDate,
} from '../attendance/attendance.controller';

const COOKIE_OPTIONS = {
  httpOnly: true,
  secure: true,
  sameSite: 'none' as const,
  maxAge: parseInt(process.env.COOKIE_MAX_AGE_DAYS || '5') * 24 * 60 * 60 * 1000,
};

const firestore = () => admin.firestore();

const getBearerOrCookieToken = (req: AuthRequest) =>
  req.headers.authorization?.split('Bearer ')[1] || req.cookies?.__session;

const setSessionCookie = (req: AuthRequest, res: Response) => {
  const idToken = getBearerOrCookieToken(req);
  if (idToken) {
    res.cookie('__session', idToken, COOKIE_OPTIONS);
  }
};

const normalizeDomain = (email: string) => email.split('@')[1]?.toLowerCase();

const findCollege = async (input: { collegeId?: string; collegeName?: string }) => {
  if (input.collegeId) {
    const doc = await firestore().collection('colleges').doc(input.collegeId).get();
    if (!doc.exists || doc.data()?.deletedAt) return null;
    return { id: doc.id, data: doc.data()! };
  }

  const snapshot = await firestore()
    .collection('colleges')
    .where('name', '==', input.collegeName)
    .where('deletedAt', '==', null)
    .limit(1)
    .get();

  if (snapshot.empty) return null;
  return { id: snapshot.docs[0].id, data: snapshot.docs[0].data() };
};

const assertCollegeAllowed = (college: { id: string; data: any }, email: string) => {
  const domains = (college.data.domains || []).map((domain: string) => domain.toLowerCase());
  if (domains.length === 0) return;

  const emailDomain = normalizeDomain(email);
  if (!emailDomain || !domains.includes(emailDomain)) {
    throw new Error(`Please use your official college email (${domains.join(', ')})`);
  }
};

const buildAuthSnapshot = (req: AuthRequest) => ({
  uid: req.user?.uid,
  email: req.user?.email,
  emailVerified: Boolean(req.user?.email_verified),
  role: (req.user as any)?.role || 'user',
  collegeId: (req.user as any)?.collegeId,
});

export const syncAuthProfile = async (req: AuthRequest, res: Response) => {
  try {
    const uid = req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'Unauthorized' });

    const userRef = firestore().collection('users').doc(uid);
    const userDoc = await userRef.get();

    if (!userDoc.exists) {
      return res.status(200).json({
        message: 'Authenticated. Onboarding required.',
        onboardingRequired: true,
        auth: buildAuthSnapshot(req),
        user: null,
      });
    }

    const patch: Record<string, unknown> = {
      lastLogin: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    const userData = userDoc.data()!;
    if (!userData.isVerified && req.user?.email_verified) {
      patch.isVerified = true;
    }

    const [, updatedDoc] = await Promise.all([userRef.update(patch), userRef.get()]);
    setSessionCookie(req, res);

    const finalData = updatedDoc.data()!;
    const onboardingRequired = !finalData.collegeId || !finalData.department || !finalData.semester;

    if (onboardingRequired) {
      return res.status(200).json({
        message: 'Profile synchronized',
        onboardingRequired,
        auth: buildAuthSnapshot(req),
        user: finalData,
      });
    }

    const semester = finalData.semester || 1;
    const [attendanceSnapshot, timetableDoc, syllabusDoc] = await Promise.all([
      userRef.collection('attendance').get(),
      userRef.collection('semesters').doc(String(semester)).get(),
      userRef.collection('syllabus').doc(String(semester)).get(),
    ]);

    let attendanceSummary: unknown[] = [];
    const timetable = timetableDoc.data();
    if (timetable?.subjects) {
      const timetableRef = userRef.collection('semesters').doc(String(semester));
      const attendanceTrackingStartDate = await ensureAttendanceTrackingStartDate(
        timetableRef,
        timetable
      );
      const threshold = (finalData.attendanceThreshold || 75) / 100;
      const timezoneOffsetMinutes = Number.parseInt(
        req.query?.timezoneOffsetMinutes?.toString() || '0',
        10
      );
      const safeTimezoneOffsetMinutes = Number.isNaN(timezoneOffsetMinutes)
        ? 0
        : timezoneOffsetMinutes;
      attendanceSummary = computeAttendanceSummary(
        timetable.subjects,
        attendanceSnapshot.docs.map(doc => doc.data()),
        threshold,
        attendanceTrackingStartDate,
        new Date(),
        safeTimezoneOffsetMinutes
      );
    }

    return res.status(200).json({
      message: 'Profile synchronized',
      onboardingRequired,
      auth: buildAuthSnapshot(req),
      user: finalData,
      attendanceSummary,
      timetable: timetable?.subjects ? { subjects: timetable.subjects } : null,
      savedSubjects: syllabusDoc.exists ? syllabusDoc.data() : null,
    });
  } catch (error: any) {
    return res.status(500).json({ error: error.message });
  }
};

export const onboard = async (req: AuthRequest, res: Response) => {
  try {
    const uid = req.user?.uid;
    const email = req.user?.email;

    if (!uid || !email) {
      return res.status(401).json({ error: 'Unauthorized: Invalid token payload' });
    }

    if (!req.user?.email_verified) {
      return res.status(403).json({ error: 'Please verify your email before onboarding.' });
    }

    const validated = OnboardingSchema.parse(req.body);
    const college = await findCollege(validated);

    if (!college) {
      return res.status(400).json({ error: 'College not found in our directory' });
    }

    try {
      assertCollegeAllowed(college, email);
    } catch (error: any) {
      return res.status(403).json({ error: error.message });
    }

    const userRef = firestore().collection('users').doc(uid);
    const existingDoc = await userRef.get();
    const existing = existingDoc.data();
    const profileData = {
      uid,
      email,
      name: validated.name,
      collegeName: college.data.name,
      collegeId: college.id,
      department: validated.department,
      semester: validated.semester,
      role: existing?.role || 'user',
      isVerified: true,
      attendanceThreshold: validated.attendanceThreshold,
      profilePic: existing?.profilePic || null,
      createdAt: existing?.createdAt || admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastLogin: admin.firestore.FieldValue.serverTimestamp(),
      deletedAt: null,
    };

    await userRef.set(profileData, { merge: true });
    setSessionCookie(req, res);

    return res.status(existingDoc.exists ? 200 : 201).json({
      message: existingDoc.exists ? 'Onboarding updated' : 'Onboarding complete',
      onboardingRequired: false,
      user: profileData,
    });
  } catch (error: any) {
    return res.status(400).json({ error: zodError(error) });
  }
};

export const signup = async (req: AuthRequest, res: Response) => {
  try {
    const uid = req.user?.uid;
    const email = req.user?.email;

    if (!uid || !email) {
      return res.status(401).json({ error: 'Unauthorized: Invalid token payload' });
    }

    const { name } = req.body;
    if (!name) {
      return res.status(400).json({ error: 'Name is required' });
    }

    const profileData = {
      uid,
      email,
      name,
      role: 'user',
      isVerified: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastLogin: admin.firestore.FieldValue.serverTimestamp(),
      deletedAt: null,
    };

    await firestore().collection('users').doc(uid).set(profileData, { merge: true });

    return res.status(201).json({
      message: 'Signup successful. Please verify your email via the link sent by Firebase.',
      user: profileData,
    });
  } catch (error: any) {
    return res.status(400).json({ error: error.message });
  }
};

/**
 * Session login and verification sync.
 * Client passes ID token. Backend syncs `isVerified` flag if Firebase token says email is verified.
 * @param {AuthRequest} req
 * @param {Response} res
 */
export const login = async (req: AuthRequest, res: Response) => {
  try {
    const uid = req.user?.uid;
    const emailVerified = req.user?.email_verified || false;

    if (!uid) return res.status(401).json({ error: 'Unauthorized' });

    const userDoc = await firestore().collection('users').doc(uid).get();

    if (!userDoc.exists) {
      return res.status(404).json({ error: 'User profile not found. Please signup.' });
    }

    const userData = userDoc.data()!;

    // Sync verification status if user clicked the email link
    if (!userData.isVerified && emailVerified) {
      await firestore().collection('users').doc(uid).update({
        isVerified: true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      userData.isVerified = true;
    }

    if (!userData.isVerified) {
      return res.status(403).json({ error: 'Please verify your email via the link sent to you.' });
    }

    await firestore().collection('users').doc(uid).update({
      lastLogin: admin.firestore.FieldValue.serverTimestamp(),
    });

    setSessionCookie(req, res);

    return res.status(200).json({ message: 'Login successful', user: userData });
  } catch (error: any) {
    return res.status(500).json({ error: error.message });
  }
};

export const logout = async (req: AuthRequest, res: Response) => {
  res.clearCookie('__session', COOKIE_OPTIONS);
  return res.status(200).json({ message: 'Logged out successfully' });
};

export const getMe = async (req: AuthRequest, res: Response) => {
  try {
    const uid = req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'Unauthorized' });

    const userDoc = await firestore().collection('users').doc(uid).get();

    if (!userDoc.exists) {
      return res.status(404).json({ error: 'User not found' });
    }

    return res.status(200).json(userDoc.data());
  } catch (error: any) {
    return res.status(500).json({ error: error.message });
  }
};

const deleteSubcollection = async (
  userRef: admin.firestore.DocumentReference,
  name: string
) => {
  const snap = await userRef.collection(name).get();
  if (snap.empty) return;
  // Firestore batches cap at 500 operations — chunk large subcollections
  for (let i = 0; i < snap.docs.length; i += 400) {
    const batch = firestore().batch();
    snap.docs.slice(i, i + 400).forEach(doc => batch.delete(doc.ref));
    await batch.commit();
  }
};

export const updateMe = async (req: AuthRequest, res: Response) => {
  try {
    const uid = req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'Unauthorized' });

    const validatedData = ProfileUpdateSchema.parse(req.body);
    const patch: Record<string, unknown> = {
      ...validatedData,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (validatedData.collegeId) {
      const college = await findCollege({ collegeId: validatedData.collegeId });
      if (!college) {
        return res.status(400).json({ error: 'College not found' });
      }
      patch.collegeName = college.data.name;
    }

    const userRef = firestore().collection('users').doc(uid);
    const existingDoc = await userRef.get();
    const existing = existingDoc.data() || {};

    // A different college or department invalidates everything tied to the
    // old curriculum — attendance records, per-semester timetables and saved
    // subjects. The client confirms with the user before sending this change.
    const collegeChanged = Boolean(
      validatedData.collegeId && validatedData.collegeId !== existing.collegeId
    );
    const departmentChanged = Boolean(
      validatedData.department && validatedData.department !== existing.department
    );
    const clearedAcademicData = collegeChanged || departmentChanged;

    if (clearedAcademicData) {
      await Promise.all([
        deleteSubcollection(userRef, 'attendance'),
        deleteSubcollection(userRef, 'semesters'),
        deleteSubcollection(userRef, 'syllabus'),
      ]);
    }

    await userRef.update(patch);

    return res.status(200).json({ message: 'Profile updated', clearedAcademicData });
  } catch (error: any) {
    return res.status(400).json({ error: zodError(error) });
  }
};

export const deleteAccount = async (req: AuthRequest, res: Response) => {
  try {
    const uid = req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'Unauthorized' });

    const userRef = firestore().collection('users').doc(uid);

    const subcollections = ['attendance', 'semesters', 'syllabus', 'cgpa'];
    for (const sub of subcollections) {
      await deleteSubcollection(userRef, sub);
    }

    await userRef.delete();
    await admin.auth().deleteUser(uid);

    return res.status(200).json({ message: 'Account and all associated data deleted.' });
  } catch (error: any) {
    return res.status(500).json({ error: error.message });
  }
};

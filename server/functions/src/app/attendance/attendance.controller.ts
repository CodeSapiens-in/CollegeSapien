import { Response } from 'express';
import { AuthRequest } from '../../shared/middlewares/auth.middleware';
import { AttendanceSchema, AttendanceSyncSchema } from './attendance.model';
import * as admin from 'firebase-admin';
import { zodError } from '../../shared/zod-error';
import { log } from '../../shared/logger';

type TimetableClass = {
  day: string;
  startTime: string;
  endTime: string;
  room?: string;
  type: string;
};

type TimetableSubject = {
  id: string;
  name: string;
  code: string;
  classes: TimetableClass[];
};

type AttendanceRecord = {
  subjectId?: string;
  date?: string;
  dateKey?: string;
  slotStartTime?: string;
  slotEndTime?: string;
  status?: string;
};

const dayCodes = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

const toDateKey = (value: string | undefined): string => {
  if (!value) return new Date().toISOString().slice(0, 10);
  return value.split('T')[0];
};

const dayCodeForDateKey = (dateKey: string): string => {
  const date = new Date(`${dateKey}T00:00:00Z`);
  return dayCodes[date.getUTCDay()];
};

const dateKeyForInstant = (date: Date, timezoneOffsetMinutes: number): string => {
  const localTime = date.getTime() + timezoneOffsetMinutes * 60 * 1000;
  return new Date(localTime).toISOString().slice(0, 10);
};

const localSlotEndToUtc = (
  dateKey: string,
  endTime: string,
  timezoneOffsetMinutes: number
): Date | null => {
  const [year, month, day] = dateKey.split('-').map(value => Number.parseInt(value, 10));
  const [hour, minute] = endTime.split(':').map(value => Number.parseInt(value, 10));
  if ([year, month, day, hour, minute].some(value => Number.isNaN(value))) return null;

  return new Date(
    Date.UTC(year, month - 1, day, hour, minute, 0, 0) - timezoneOffsetMinutes * 60 * 1000
  );
};

const sanitizeDocPart = (value: string): string => value.replace(/[^A-Za-z0-9-]/g, '');

const slotDocId = (dateKey: string, subjectId: string, startTime: string, endTime: string) =>
  `${dateKey}_${sanitizeDocPart(subjectId)}_${sanitizeDocPart(startTime)}_${sanitizeDocPart(
    endTime
  )}`;

const slotKey = (dateKey: string, subjectId: string, startTime: string, endTime: string) =>
  `${dateKey}|${subjectId}|${startTime}|${endTime}`;

const subjectMatches = (recordSubjectId: string | undefined, subject: TimetableSubject) =>
  recordSubjectId === subject.id || recordSubjectId === subject.code;

const getCurrentTimetableRef = async (uid: string) => {
  const userDoc = await admin.firestore().collection('users').doc(uid).get();
  const currentSemester = userDoc.data()?.semester || 1;
  return admin
    .firestore()
    .collection('users')
    .doc(uid)
    .collection('semesters')
    .doc(String(currentSemester));
};

const resolveAttendanceSlot = (
  subjects: TimetableSubject[],
  subjectId: string,
  dateKey: string,
  slotStartTime?: string,
  slotEndTime?: string
) => {
  const subject = subjects.find(item => item.id === subjectId || item.code === subjectId);
  if (!subject) {
    throw new Error('Subject is not present in the current timetable');
  }

  const day = dayCodeForDateKey(dateKey);
  const scheduledSlots = subject.classes.filter(cls => cls.day === day);
  const nonBreakSlots = scheduledSlots.filter(cls => cls.type !== 'BREAK');
  const matchingSlots =
    slotStartTime && slotEndTime
      ? scheduledSlots.filter(cls => cls.startTime === slotStartTime && cls.endTime === slotEndTime)
      : nonBreakSlots;

  if (matchingSlots.length === 0) {
    throw new Error('No matching timetable class exists for this subject and slot');
  }

  if (!slotStartTime || !slotEndTime) {
    if (matchingSlots.length !== 1) {
      throw new Error(
        'slotStartTime and slotEndTime are required when a subject has multiple slots'
      );
    }
  }

  const slot = matchingSlots[0];
  if (slot.type === 'BREAK') {
    throw new Error('Break slots cannot be marked for attendance');
  }

  return { subject, slot };
};

const getElapsedDateKeys = (
  startDateKey: string,
  now: Date,
  timezoneOffsetMinutes = 0
): string[] => {
  const result: string[] = [];
  const cursor = new Date(`${startDateKey}T00:00:00Z`);
  // Use local today so records stored with local dateKeys are included
  const todayKey = dateKeyForInstant(now, timezoneOffsetMinutes);
  const end = new Date(`${todayKey}T00:00:00Z`);

  while (cursor <= end) {
    result.push(cursor.toISOString().slice(0, 10));
    cursor.setUTCDate(cursor.getUTCDate() + 1);
  }

  return result;
};

const hasSlotElapsed = (
  dateKey: string,
  endTime: string,
  now: Date,
  timezoneOffsetMinutes: number
): boolean => {
  const todayKey = dateKeyForInstant(now, timezoneOffsetMinutes);
  if (dateKey < todayKey) return true;
  if (dateKey > todayKey) return false;

  const end = localSlotEndToUtc(dateKey, endTime, timezoneOffsetMinutes);
  if (!end) return false;
  return end <= now;
};

export const markAttendance = async (req: AuthRequest, res: Response) => {
  try {
    const uid = req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'Unauthorized' });

    const validatedData = AttendanceSchema.parse(req.body);
    const dateKey = validatedData.dateKey || toDateKey(validatedData.date);
    const timetableRef = await getCurrentTimetableRef(uid);
    const timetableDoc = await timetableRef.get();
    const subjects = (timetableDoc.data()?.subjects || []) as TimetableSubject[];
    const { subject, slot } = resolveAttendanceSlot(
      subjects,
      validatedData.subjectId,
      dateKey,
      validatedData.slotStartTime,
      validatedData.slotEndTime
    );

    const docId = slotDocId(dateKey, subject.id, slot.startTime, slot.endTime);
    const attendanceRef = admin
      .firestore()
      .collection('users')
      .doc(uid)
      .collection('attendance')
      .doc(docId);

    if (validatedData.status === 'None') {
      // If setting to None, we can either delete or mark as none
      await attendanceRef.delete();
      return res.status(200).json({ message: 'Attendance reset' });
    }

    await attendanceRef.set(
      {
        ...validatedData,
        subjectId: subject.id,
        dateKey,
        slotStartTime: slot.startTime,
        slotEndTime: slot.endTime,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return res.status(201).json({ message: 'Attendance updated successfully' });
  } catch (error: any) {
    return res.status(400).json({ error: zodError(error) });
  }
};

export const syncAttendance = async (req: AuthRequest, res: Response) => {
  try {
    const uid = req.user?.uid;
    const { updates } = AttendanceSyncSchema.parse(req.body); // Array of { date, subjectId, status }

    if (!uid) return res.status(401).json({ error: 'Unauthorized' });

    const batch = admin.firestore().batch();
    const userRef = admin.firestore().collection('users').doc(uid);
    const timetableRef = await getCurrentTimetableRef(uid);
    const timetableDoc = await timetableRef.get();
    const subjects = (timetableDoc.data()?.subjects || []) as TimetableSubject[];

    for (const update of updates) {
      const dateKey = update.dateKey || toDateKey(update.date);
      const { subject, slot } = resolveAttendanceSlot(
        subjects,
        update.subjectId,
        dateKey,
        update.slotStartTime,
        update.slotEndTime
      );
      const docId = slotDocId(dateKey, subject.id, slot.startTime, slot.endTime);
      const ref = userRef.collection('attendance').doc(docId);

      if (update.status === 'None') {
        batch.delete(ref);
      } else {
        batch.set(
          ref,
          {
            ...update,
            subjectId: subject.id,
            dateKey,
            slotStartTime: slot.startTime,
            slotEndTime: slot.endTime,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      }
    }

    await batch.commit();
    return res.status(200).json({ message: 'Bulk attendance synced' });
  } catch (error: any) {
    return res.status(400).json({ error: zodError(error) });
  }
};

/**
 * Resolves (and self-heals) the attendanceTrackingStartDate for a semester's timetable doc.
 * Shared by the standalone attendance-summary endpoint and the auth sync endpoint.
 */
export const ensureAttendanceTrackingStartDate = async (
  timetableRef: FirebaseFirestore.DocumentReference,
  timetable: FirebaseFirestore.DocumentData
): Promise<string> => {
  let attendanceTrackingStartDate = timetable.attendanceTrackingStartDate as string | undefined;
  if (!attendanceTrackingStartDate) {
    attendanceTrackingStartDate = new Date().toISOString().slice(0, 10);
    await timetableRef.set({ attendanceTrackingStartDate }, { merge: true });
  }
  return attendanceTrackingStartDate;
};

/**
 * Pure computation: timetable subjects + raw attendance records -> per-subject summary.
 * Shared by the standalone attendance-summary endpoint and the auth sync endpoint.
 */
export const computeAttendanceSummary = (
  subjects: TimetableSubject[],
  records: AttendanceRecord[],
  threshold: number,
  attendanceTrackingStartDate: string,
  now: Date,
  timezoneOffsetMinutes: number
) => {
  const elapsedDateKeys = getElapsedDateKeys(
    attendanceTrackingStartDate,
    now,
    timezoneOffsetMinutes
  );

  return subjects.map((subject: TimetableSubject) => {
    const explicitBySlot = new Map<string, AttendanceRecord>();
    const legacyByDate = new Map<string, AttendanceRecord>();
    for (const record of records) {
      if (!subjectMatches(record.subjectId, subject)) continue;
      const recordDateKey = record.dateKey || toDateKey(record.date);
      if (record.slotStartTime && record.slotEndTime) {
        explicitBySlot.set(
          slotKey(recordDateKey, subject.id, record.slotStartTime, record.slotEndTime),
          record
        );
      } else {
        legacyByDate.set(recordDateKey, record);
      }
    }

    let attended = 0;
    let absent = 0;
    let leave = 0;
    let odMl = 0;

    for (const dateKey of elapsedDateKeys) {
      const day = dayCodeForDateKey(dateKey);
      const slots = (subject.classes || []).filter(cls => {
        if (cls.day !== day || cls.type === 'BREAK') return false;
        if (hasSlotElapsed(dateKey, cls.endTime, now, timezoneOffsetMinutes)) return true;
        // Count explicitly marked slots even if class hasn't ended yet
        return explicitBySlot.has(slotKey(dateKey, subject.id, cls.startTime, cls.endTime));
      });

      for (const slot of slots) {
        const record =
          explicitBySlot.get(slotKey(dateKey, subject.id, slot.startTime, slot.endTime)) ||
          (slots.length === 1 ? legacyByDate.get(dateKey) : undefined);
        const status = record?.status || 'Absent';

        if (status === 'Present') attended += 1;
        if (status === 'Absent') absent += 1;
        if (status === 'Leave') leave += 1;
        if (status === 'OD_ML') odMl += 1;
      }
    }

    // OD_ML is excused — not counted in total, doesn't affect percentage
    const total = attended + absent;

    const percentage = total === 0 ? 0 : (attended / total) * 100;
    const calculatedSafeSkips = total === 0 ? 0 : Math.floor(attended / threshold - total);
    // OD_ML classes count toward safeToSkip since they're excused absences
    const safeToSkip = Math.max(0, calculatedSafeSkips) + odMl;

    return {
      subjectId: subject.id,
      subjectName: subject.name,
      subjectCode: subject.code,
      attended,
      absent,
      leave,
      odMl,
      total,
      percentage: Math.round(percentage * 100) / 100,
      safeToSkip,
      requiredToReachThreshold:
        calculatedSafeSkips < 0 ? Math.ceil((threshold * total - attended) / (1 - threshold)) : 0,
    };
  });
};

export const getAttendanceSummary = async (req: AuthRequest, res: Response) => {
  try {
    const uid = req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'Unauthorized' });

    const userRef = admin.firestore().collection('users').doc(uid);
    const [attendanceSnapshot, userDoc] = await Promise.all([
      userRef.collection('attendance').get(),
      userRef.get(),
    ]);

    const userData = userDoc.data();
    const currentSemester = userData?.semester || 1;

    // Get timetable for current semester
    const timetableRef = userRef.collection('semesters').doc(String(currentSemester));
    const timetableDoc = await timetableRef.get();

    const timetable = timetableDoc.data();
    if (!timetable || !timetable.subjects) return res.status(200).json([]);

    const attendanceTrackingStartDate = await ensureAttendanceTrackingStartDate(
      timetableRef,
      timetable
    );

    const subjects = timetable.subjects as TimetableSubject[];
    const records = attendanceSnapshot.docs.map(doc => doc.data() as AttendanceRecord);
    const threshold = (userData?.attendanceThreshold || 75) / 100;
    const now = new Date();
    const timezoneOffsetMinutes = Number.parseInt(
      req.query?.timezoneOffsetMinutes?.toString() || '0',
      10
    );
    const safeTimezoneOffsetMinutes = Number.isNaN(timezoneOffsetMinutes)
      ? 0
      : timezoneOffsetMinutes;

    const summary = computeAttendanceSummary(
      subjects,
      records,
      threshold,
      attendanceTrackingStartDate,
      now,
      safeTimezoneOffsetMinutes
    );

    return res.status(200).json(summary);
  } catch (error: any) {
    log.error('Unhandled error', { path: res.req?.path, error: String(error) });
    return res.status(500).json({ error: 'Internal server error' });
  }
};

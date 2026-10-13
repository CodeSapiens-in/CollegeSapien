import { createHash } from 'node:crypto';
import type { Request, Response } from 'express';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { WaitlistSchema, scoreAnswers, WAITLIST_AREAS } from './campus.model';

const firestore = () => getFirestore();
const sha = (value: string) => createHash('sha256').update(value).digest('hex');

const RATE_LIMIT = 5; // submissions per IP per window
const RATE_WINDOW_MS = 10 * 60 * 1000;

// ponytail: Firestore counter per IP+window; swap for Cloud Armor/App Check if abused at scale.
const overLimit = async (req: Request) => {
  const ip = String(req.headers['x-forwarded-for'] ?? req.ip ?? '').split(',')[0].trim();
  const window = Math.floor(Date.now() / RATE_WINDOW_MS);
  const ref = firestore().collection('campusWaitlistRate').doc(`${sha(ip)}_${window}`);
  return firestore().runTransaction(async tx => {
    const count = (await tx.get(ref)).data()?.count ?? 0;
    if (count >= RATE_LIMIT) return true;
    tx.set(ref, { count: count + 1, expiresAt: new Date(Date.now() + 2 * RATE_WINDOW_MS) });
    return false;
  });
};

// Public: POST /api/waitlist
export const joinWaitlist = async (req: Request, res: Response) => {
  const parsed = WaitlistSchema.safeParse(req.body);
  if (!parsed.success) {
    const emailBad = parsed.error.issues.some(i => i.path[0] === 'email');
    return res.status(400).json({ ok: false, error: emailBad ? 'invalid_email' : 'invalid_request' });
  }
  const { email, company, answers } = parsed.data;
  if (company) return res.status(200).json({ ok: true, status: 'joined' }); // bot: pretend success, store nothing

  try {
    if (await overLimit(req)) return res.status(429).json({ ok: false, error: 'rate_limited' });

    const ref = firestore().collection('campusWaitlist').doc(sha(email));
    const now = FieldValue.serverTimestamp();
    const quiz = answers
      ? { answers, scores: scoreAnswers(answers), quizVersion: 1, quizAt: now }
      : {}; // no quiz: keep any answers from an earlier signup
    await firestore().runTransaction(async tx => {
      const exists = (await tx.get(ref)).exists;
      tx.set(
        ref,
        { email, consent: true, source: 'sapienscampus', updatedAt: now, ...(exists ? {} : { createdAt: now }), ...quiz },
        { merge: true }
      );
    });
    return res.status(200).json({ ok: true, status: 'joined' });
  } catch (error) {
    console.error('waitlist write failed', error);
    return res.status(500).json({ ok: false, error: 'server_error' });
  }
};

// Superadmin: GET /api/v1/campus/waitlist
export const listWaitlist = async (_req: Request, res: Response) => {
  const snap = await firestore().collection('campusWaitlist').orderBy('updatedAt', 'desc').limit(5000).get();
  const data = snap.docs.map(d => {
    const v = d.data();
    const scores = v.scores as Record<string, number> | undefined;
    const max = scores ? Math.max(...WAITLIST_AREAS.map(a => scores[a])) : null;
    return {
      id: d.id,
      email: v.email,
      answers: v.answers ?? null,
      scores: scores ?? null,
      top: scores ? WAITLIST_AREAS.filter(a => scores[a] === max) : [],
      createdAt: v.createdAt?.toDate?.().toISOString() ?? null,
      updatedAt: v.updatedAt?.toDate?.().toISOString() ?? null,
    };
  });
  return res.status(200).json(data);
};

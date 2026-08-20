import { NextFunction, Request, Response } from 'express';
import * as admin from 'firebase-admin';
import { z } from 'zod';
import { AuthRequest } from '../../shared/middlewares/auth.middleware';
import { log } from '../../shared/logger';
import { zodError } from '../../shared/zod-error';
import {
  CHALLENGES,
  CHALLENGE_BY_ID,
  POW_DIFFICULTY,
  RELAY_HOPS,
  RULES,
  TOTAL_POINTS,
} from './ctf.challenges';
import {
  challengeEtag,
  ctfEnabled,
  fingerprint,
  fingerprintFromFlag,
  parseRelayHop,
  personalFlag,
  powHash,
  powSeed,
  relayHopToken,
  safeEqual,
  staticFlag,
} from './ctf.flags';

const firestore = () => admin.firestore();
const progressRef = (uid: string) => firestore().collection('ctf_progress').doc(uid);

const rot13 = (input: string) =>
  input.replace(/[a-zA-Z]/g, char => {
    const base = char <= 'Z' ? 65 : 97;
    return String.fromCharCode(((char.charCodeAt(0) - base + 13) % 26) + base);
  });

const b64 = (input: string) => Buffer.from(input, 'utf8').toString('base64');
const b64url = (input: string) => Buffer.from(input, 'utf8').toString('base64url');

// Every challenge's answer, resolved for whoever is asking.
const expectedFlag = (challengeId: string, uid?: string) => {
  const challenge = CHALLENGE_BY_ID.get(challengeId);
  if (!challenge) return null;
  if (!challenge.personal) return staticFlag(challengeId);
  return uid ? personalFlag(challengeId, uid) : null;
};

export const briefing = async (req: Request, res: Response) => {
  // ch01: the flag is right here, in a header. You have to actually look.
  res.setHeader('X-Ctf-Ch01-Flag', staticFlag('ch01'));

  return res.status(200).json({
    name: 'CodeSapiens CTF',
    why: 'We would rather find people by watching them solve things than by reading their CV.',
    flagFormat: 'CS{...}',
    totalPoints: TOTAL_POINTS,
    rules: RULES,
    submit: 'POST /submit with { challengeId, flag } and a Firebase ID token.',
    challenges: CHALLENGES.map(c => ({
      id: c.id,
      name: c.name,
      points: c.points,
      requiresAuth: c.requiresAuth,
      teaches: c.teaches,
      brief: c.brief,
      hint: c.hint,
      path: `/${c.id}`,
    })),
  });
};

export const ch02 = async (_req: Request, res: Response) => {
  // base64( rot13( base64( flag ) ) ) — three layers, two of them the same idea.
  const payload = b64(rot13(b64(staticFlag('ch02'))));
  return res.status(200).json({
    challenge: 'ch02',
    hint: 'Three layers. Peel them.',
    payload,
  });
};

export const ch03 = async (req: Request, res: Response) => {
  const etag = challengeEtag('ch03');
  const ifMatch = req.header('If-Match');

  if (!ifMatch) {
    res.setHeader('ETag', etag);
    return res.status(428).json({
      challenge: 'ch03',
      error: 'Precondition Required',
      hint: 'I just told you which version I am. Ask again and tell me you know.',
    });
  }

  if (!safeEqual(ifMatch.trim(), etag)) {
    return res.status(412).json({
      challenge: 'ch03',
      error: 'Precondition Failed',
      hint: 'Close. Send the ETag back exactly as it was given to you, quotes and all.',
    });
  }

  return res.status(200).json({ challenge: 'ch03', flag: staticFlag('ch03') });
};

export const ch04 = async (req: AuthRequest, res: Response) => {
  const uid = req.user!.uid;

  // A deliberately inert token: alg "none", a signature that signs nothing.
  // It is shaped like the real thing so the anatomy lesson lands, but it
  // authenticates nothing anywhere and never could.
  const header = b64url(JSON.stringify({ alg: 'none', typ: 'JWT' }));
  const body = b64url(
    JSON.stringify({
      iss: 'codesapiens-ctf',
      sub: fingerprint(uid),
      note: 'Inert demo token. It authenticates nothing. Do not go looking for a lock it opens.',
      flag: personalFlag('ch04', uid),
    })
  );
  const signature = b64url('this-signature-signs-nothing');

  return res.status(200).json({
    challenge: 'ch04',
    token: `${header}.${body}.${signature}`,
    hint: 'Three parts, split on dots. The middle one is encoded, not encrypted.',
  });
};

export const ch05Start = async (req: AuthRequest, res: Response) => {
  const uid = req.user!.uid;
  res.setHeader('X-Next-Hop', relayHopToken(uid, 0));
  return res.status(200).json({
    challenge: 'ch05',
    hops: RELAY_HOPS,
    next: `/ch05/hop/${relayHopToken(uid, 0)}`,
    hint: 'Follow X-Next-Hop until it stops coming.',
  });
};

export const ch05Hop = async (req: AuthRequest, res: Response) => {
  const uid = req.user!.uid;
  const index = parseRelayHop(uid, req.params.token as string);

  if (index === null) {
    return res.status(404).json({
      challenge: 'ch05',
      error: 'That hop is not part of your chain.',
      hint: 'Chains are per-solver. Start your own at /ch05/start.',
    });
  }

  if (index >= RELAY_HOPS) {
    return res.status(200).json({ challenge: 'ch05', flag: personalFlag('ch05', uid) });
  }

  const next = relayHopToken(uid, index + 1);
  res.setHeader('X-Next-Hop', next);
  return res.status(200).json({
    challenge: 'ch05',
    hop: index + 1,
    of: RELAY_HOPS,
    next: `/ch05/hop/${next}`,
  });
};

export const ch06Challenge = async (req: AuthRequest, res: Response) => {
  const uid = req.user!.uid;
  return res.status(200).json({
    challenge: 'ch06',
    seed: powSeed(uid),
    difficulty: POW_DIFFICULTY,
    rule: `Find a nonce where sha256(seed + nonce) starts with ${POW_DIFFICULTY} zeros.`,
    submit: 'POST /ch06 with { nonce }',
    note: 'Your seed is derived from your account. Copying somebody else answer will not work.',
  });
};

const PowSchema = z.object({ nonce: z.string().min(1).max(256) });

export const ch06Submit = async (req: AuthRequest, res: Response) => {
  try {
    const uid = req.user!.uid;
    const { nonce } = PowSchema.parse(req.body);

    const digest = powHash(powSeed(uid), nonce);
    if (!digest.startsWith('0'.repeat(POW_DIFFICULTY))) {
      return res.status(400).json({
        challenge: 'ch06',
        ok: false,
        yourHash: digest,
        hint: `Needs ${POW_DIFFICULTY} leading zeros. Keep going.`,
      });
    }

    return res.status(200).json({
      challenge: 'ch06',
      ok: true,
      hash: digest,
      flag: personalFlag('ch06', uid),
    });
  } catch (error) {
    return res.status(400).json({ error: zodError(error) });
  }
};

export const ch07 = async (req: AuthRequest, res: Response) => {
  const uid = req.user!.uid;
  const snap = await progressRef(uid).get();
  const solved = (snap.data()?.solved ?? {}) as Record<string, unknown>;

  const required = CHALLENGES.filter(c => c.id !== 'ch07').map(c => c.id);
  const missing = required.filter(id => !solved[id]);

  if (missing.length > 0) {
    return res.status(403).json({
      challenge: 'ch07',
      error: 'Not yet.',
      missing,
      hint: 'Submit the other six first.',
    });
  }

  return res.status(200).json({
    challenge: 'ch07',
    flag: personalFlag('ch07', uid),
    invitation: {
      message:
        'You solved all seven. That took curiosity, HTTP fluency and actual code — which is the whole list of things we were testing for.',
      whatNow:
        'Email opensource@collegesapien.com with this flag. Your solve history is your application; we already know what you can do.',
      alsoWorthKnowing:
        'If you found something on the way that we did not plant, that is worth more than the flag. Tell us at security@collegesapien.com.',
    },
  });
};

const SubmitSchema = z.object({
  challengeId: z.string().min(1).max(16),
  flag: z.string().min(1).max(128),
});

export const submitFlag = async (req: AuthRequest, res: Response) => {
  try {
    const uid = req.user!.uid;
    const { challengeId, flag } = SubmitSchema.parse(req.body);

    const challenge = CHALLENGE_BY_ID.get(challengeId);
    if (!challenge) {
      return res.status(404).json({ error: 'No such challenge' });
    }

    const expected = expectedFlag(challengeId, uid);
    const submitted = flag.trim();

    if (!expected || !safeEqual(submitted, expected)) {
      // A well-formed flag carrying somebody else's fingerprint is not a wrong
      // answer — it is a borrowed one, and we can see exactly whose it was.
      const theirs = fingerprintFromFlag(submitted);
      if (theirs && theirs !== fingerprint(uid)) {
        await progressRef(uid).set(
          {
            uid,
            borrowedFlagAttempts: admin.firestore.FieldValue.increment(1),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
        log.warn('ctf.borrowed_flag', { uid, challengeId, ownerFingerprint: theirs });
        return res.status(403).json({
          ok: false,
          error: 'That flag was issued to somebody else.',
          hint: 'Flags past ch03 are minted per solver. Go and earn your own — it is more fun anyway.',
        });
      }

      return res.status(400).json({ ok: false, error: 'Incorrect flag.' });
    }

    const snap = await progressRef(uid).get();
    const existing = snap.data() ?? {};
    const solved = (existing.solved ?? {}) as Record<string, { points?: number }>;

    if (solved[challengeId]) {
      return res.status(200).json({
        ok: true,
        alreadySolved: true,
        totalPoints: existing.totalPoints ?? 0,
      });
    }

    const totalPoints = (existing.totalPoints ?? 0) + challenge.points;
    await progressRef(uid).set(
      {
        uid,
        email: req.user?.email ?? null,
        // Nested map + merge, not a dotted key — in set() a dotted key would
        // create a field literally named "solved.ch01" instead of nesting.
        solved: {
          [challengeId]: {
            points: challenge.points,
            at: admin.firestore.Timestamp.now(),
          },
        },
        totalPoints,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    log.info('ctf.solved', { uid, challengeId, points: challenge.points, totalPoints });

    const solvedCount = Object.keys(solved).length + 1;
    return res.status(200).json({
      ok: true,
      challengeId,
      points: challenge.points,
      totalPoints,
      solvedCount,
      of: CHALLENGES.length,
    });
  } catch (error) {
    return res.status(400).json({ error: zodError(error) });
  }
};

export const myProgress = async (req: AuthRequest, res: Response) => {
  const uid = req.user!.uid;
  const snap = await progressRef(uid).get();
  const data = snap.data() ?? {};
  const solved = (data.solved ?? {}) as Record<string, unknown>;

  return res.status(200).json({
    fingerprint: fingerprint(uid),
    totalPoints: data.totalPoints ?? 0,
    of: TOTAL_POINTS,
    leaderboardOptIn: data.leaderboardOptIn ?? false,
    handle: data.handle ?? null,
    solved: Object.keys(solved),
    remaining: CHALLENGES.filter(c => !solved[c.id]).map(c => c.id),
  });
};

const OptInSchema = z.object({
  leaderboardOptIn: z.boolean(),
  handle: z.string().trim().min(2).max(24).optional(),
});

export const setLeaderboardOptIn = async (req: AuthRequest, res: Response) => {
  try {
    const uid = req.user!.uid;
    const { leaderboardOptIn, handle } = OptInSchema.parse(req.body);

    await progressRef(uid).set(
      {
        uid,
        leaderboardOptIn,
        ...(handle ? { handle } : {}),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return res.status(200).json({ ok: true, leaderboardOptIn });
  } catch (error) {
    return res.status(400).json({ error: zodError(error) });
  }
};

export const leaderboard = async (_req: Request, res: Response) => {
  const snapshot = await firestore()
    .collection('ctf_progress')
    .where('leaderboardOptIn', '==', true)
    .orderBy('totalPoints', 'desc')
    .limit(25)
    .get();

  // Only ever expose the opt-in handle — never the email or uid.
  const rows = snapshot.docs.map((doc, index) => {
    const data = doc.data();
    return {
      rank: index + 1,
      handle: data.handle || 'anonymous',
      points: data.totalPoints ?? 0,
      solved: Object.keys(data.solved ?? {}).length,
    };
  });

  return res.status(200).json({ leaderboard: rows, of: TOTAL_POINTS });
};

// Guard so the CTF fails closed rather than running on a guessable secret.
export const requireCtfEnabled = (_req: Request, res: Response, next: NextFunction) => {
  if (!ctfEnabled()) {
    return res.status(503).json({ error: 'CTF is not configured.' });
  }
  return next();
};

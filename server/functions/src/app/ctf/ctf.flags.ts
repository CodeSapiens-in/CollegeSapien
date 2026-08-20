import { createHmac, createHash, timingSafeEqual } from 'crypto';

// Flag derivation for the CodeSapiens CTF.
//
// This repository is public, so a hardcoded flag would be discoverable with a
// single `git grep` and would be worthless as a signal. Every flag is instead
// derived at runtime via HMAC from CTF_FLAG_SECRET, which lives only in the
// function environment. Nothing in the source tree reveals an answer.

const FLAG_PREFIX = 'CS';

// Dev-only fallback so the emulator works out of the box. In production the
// CTF disables itself entirely rather than run on a guessable secret.
const DEV_SECRET = 'dev-only-insecure-ctf-secret';

const resolveSecret = () => {
  const configured = process.env.CTF_FLAG_SECRET || '';
  if (configured) return configured;
  return process.env.NODE_ENV === 'production' ? '' : DEV_SECRET;
};

// The CTF refuses to serve anything unless a real secret is configured.
export const ctfEnabled = () => resolveSecret().length > 0;

const hmac = (...parts: string[]) =>
  createHmac('sha256', resolveSecret()).update(parts.join(':')).digest('hex');

// Short, stable, non-reversible handle for a user. Embedded in personal flags
// so a flag pasted into a group chat still points back at whoever earned it.
export const fingerprint = (uid: string) => hmac('fingerprint', uid).slice(0, 8);

// Same for everyone. Used by the anonymous warm-up challenges.
export const staticFlag = (challengeId: string) =>
  `${FLAG_PREFIX}{${challengeId}_${hmac('static', challengeId).slice(0, 16)}}`;

// Unique per solver, and carries the solver's fingerprint.
export const personalFlag = (challengeId: string, uid: string) =>
  `${FLAG_PREFIX}{${challengeId}_${fingerprint(uid)}_${hmac('personal', challengeId, uid).slice(0, 16)}}`;

// ETag for ch03. Derived under its own HMAC label rather than sliced out of
// the flag — an ETag cut from the flag would hand every visitor half of that
// flag's secret material just for making a plain GET.
export const challengeEtag = (challengeId: string) =>
  `"${challengeId}-${hmac('etag', challengeId).slice(0, 8)}"`;

// Constant-time compare so flag checking can't be probed byte by byte.
export const safeEqual = (a: string, b: string) => {
  const bufA = Buffer.from(a, 'utf8');
  const bufB = Buffer.from(b, 'utf8');
  if (bufA.length !== bufB.length) return false;
  return timingSafeEqual(bufA, bufB);
};

// Pull the fingerprint out of a personal flag, if it has one. Lets us tell
// "wrong answer" apart from "right answer, but it belongs to someone else".
export const fingerprintFromFlag = (flag: string): string | null => {
  const match = /^CS\{[a-z0-9]+_([0-9a-f]{8})_[0-9a-f]{16}\}$/.exec(flag.trim());
  return match ? match[1] : null;
};

// --- ch05 relay: stateless per-user hop chain -------------------------------

export const relayHopToken = (uid: string, index: number) =>
  `${index}.${hmac('relay', uid, String(index)).slice(0, 12)}`;

export const parseRelayHop = (uid: string, token: string): number | null => {
  const [rawIndex, digest] = token.split('.');
  const index = Number.parseInt(rawIndex, 10);
  if (!Number.isInteger(index) || index < 0 || !digest) return null;
  return safeEqual(relayHopToken(uid, index), token) ? index : null;
};

// --- ch06 grind: per-user proof of work -------------------------------------

// Seed is derived from the solver, so a shared nonce is useless to anyone else.
export const powSeed = (uid: string) => hmac('pow', uid).slice(0, 16);

export const powHash = (seed: string, nonce: string) =>
  createHash('sha256').update(`${seed}${nonce}`).digest('hex');

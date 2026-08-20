import { rateLimit } from 'express-rate-limit';

// Coarse global abuse guard, applied to every request in app.ts.
export const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 600,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many requests, please try again later.' },
});

// Sensitive auth actions (signup/login/onboard). Kept generous rather than
// tight — many students share one public IP behind campus wifi NAT, and a
// low per-IP limit would lock out an entire hostel over a few minutes of
// normal traffic.
export const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 50,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many requests, please try again later.' },
});

// Upload/report endpoints — cheap to abuse for storage/Firestore cost if
// left unbounded.
export const uploadLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 30,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many requests, please try again later.' },
});

// CTF flag submission. Every wrong guess is a Firestore read, so this is both
// an anti-brute-force control and a billing control. Flags are 16 hex chars,
// so guessing was never realistic — this just keeps the cost bounded.
export const ctfLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 60,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many submissions, please slow down.' },
});

// Proof-of-work verification is pure CPU with no database access, so it can
// afford a looser limit than flag submission — solvers legitimately retry.
export const ctfSolveLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 120,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many attempts, please slow down.' },
});

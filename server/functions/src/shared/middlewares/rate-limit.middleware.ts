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

import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import * as admin from 'firebase-admin';
import ctfRoutes from './app/ctf/ctf.route';
import { globalLimiter } from './shared/middlewares/rate-limit.middleware';
import { requestLogger } from './shared/logger';

/**
 * The CTF runs as its own Express app behind its own Cloud Function so that a
 * burst of players — or someone hammering it — cannot eat the instance budget
 * the student-facing API depends on.
 */
const ctfApp = express();
ctfApp.set('query parser', 'extended');

ctfApp.use((req, _res, next) => {
  if (req.query === undefined) {
    const queryIndex = req.url.indexOf('?');
    (req as { query: Record<string, string> }).query =
      queryIndex >= 0 ? Object.fromEntries(new URLSearchParams(req.url.slice(queryIndex + 1))) : {};
  }
  next();
});

if (admin.apps.length === 0) {
  admin.initializeApp();
}

// Deliberately open to any origin, and deliberately WITHOUT credentials. No
// cookie-parser is mounted here, so the auth middleware can only ever read a
// Bearer token — which means there is no ambient authority for a hostile page
// to ride, and reflecting the origin costs us nothing. Solvers can therefore
// play from a scratch page, a notebook or curl.
//
// exposedHeaders matters more than it looks: several challenges hide their
// answer in a response header, and a browser cannot read a non-safelisted
// header unless it is listed here. Without this, ch01/ch03/ch05 would be
// solvable with curl but mysteriously impossible in a browser.
ctfApp.use(
  cors({
    origin: true,
    credentials: false,
    exposedHeaders: ['X-Ctf-Ch01-Flag', 'X-Next-Hop', 'ETag'],
  })
);

ctfApp.use(
  helmet({
    contentSecurityPolicy: false,
    crossOriginEmbedderPolicy: false,
  })
);

ctfApp.use(globalLimiter);

ctfApp.use((req: any, res, next) => {
  if (req.rawBody !== undefined) {
    // Cloud Run pre-consumes the stream; rawBody is a Buffer.
    if (!req.body || Object.keys(req.body).length === 0) {
      try {
        req.body = req.rawBody.length ? JSON.parse(req.rawBody.toString('utf8')) : {};
      } catch {
        req.body = {};
      }
    }
    return next();
  }
  express.json({ limit: '64kb' })(req, res, next);
});

ctfApp.use(requestLogger);

ctfApp.use('/', ctfRoutes);

export { ctfApp };

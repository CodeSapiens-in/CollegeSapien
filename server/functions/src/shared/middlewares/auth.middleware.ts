import type { NextFunction, Request, Response } from 'express';
import * as admin from 'firebase-admin';
import { log } from '../logger';

export interface AuthRequest extends Request {
  user?: admin.auth.DecodedIdToken;
}

export const authenticate = async (req: AuthRequest, res: Response, next: NextFunction) => {
  let idToken: string | undefined;

  // Check Authorization header
  if (req.headers.authorization?.startsWith('Bearer ')) {
    idToken = req.headers.authorization.split('Bearer ')[1];
  }
  // Check __session cookie (Firebase preferred)
  else if (req.cookies?.__session) {
    idToken = req.cookies.__session;
  }

  if (!idToken) {
    return res.status(401).json({ error: 'Unauthorized: No token provided' });
  }

  try {
    let decodedToken: admin.auth.DecodedIdToken;

    if (process.env.FIREBASE_AUTH_EMULATOR_HOST) {
      const payload = JSON.parse(Buffer.from(idToken.split('.')[1], 'base64').toString('utf8'));
      // Emulator tokens are unsigned JWTs — decode without signature verification
      decodedToken = payload as admin.auth.DecodedIdToken;
    } else {
      const checkRevoked = process.env.CHECK_REVOKED_TOKENS === 'true';
      decodedToken = await admin.auth().verifyIdToken(idToken, checkRevoked);
    }

    req.user = decodedToken;
    return next();
  } catch (error) {
    log.error('Error verifying token', { error: String(error) });
    return res.status(401).json({ error: 'Unauthorized: Invalid token' });
  }
};

export const requireVerifiedEmail = (req: AuthRequest, res: Response, next: NextFunction) => {
  if (!req.user?.email_verified) {
    return res.status(403).json({ error: 'Please verify your email before continuing.' });
  }

  return next();
};

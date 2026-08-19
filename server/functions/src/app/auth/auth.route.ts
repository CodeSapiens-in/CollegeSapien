import { Router } from 'express';
import {
  getMe,
  updateMe,
  deleteAccount,
  logout,
  signup,
  login,
  syncAuthProfile,
  onboard,
} from './auth.controller';
import { authenticate, requireVerifiedEmail } from '../../shared/middlewares/auth.middleware';
import { authLimiter } from '../../shared/middlewares/rate-limit.middleware';

// OpenAPI documentation for these routes lives in ./auth.openapi.ts

const router = Router();

router.post('/signup', authLimiter, authenticate, signup);

router.post('/sync', authenticate, syncAuthProfile);

router.post('/onboard', authLimiter, authenticate, requireVerifiedEmail, onboard);

router.post('/login', authLimiter, authenticate, login);

router.post('/logout', logout);

router.get('/me', authenticate, getMe);

router.patch('/me', authenticate, requireVerifiedEmail, updateMe);
router.delete('/me', authenticate, deleteAccount);

export default router;

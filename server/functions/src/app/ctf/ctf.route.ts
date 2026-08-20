import { Router } from 'express';
import {
  briefing,
  ch02,
  ch03,
  ch04,
  ch05Hop,
  ch05Start,
  ch06Challenge,
  ch06Submit,
  ch07,
  leaderboard,
  myProgress,
  requireCtfEnabled,
  setLeaderboardOptIn,
  submitFlag,
} from './ctf.controller';
import { authenticate, requireVerifiedEmail } from '../../shared/middlewares/auth.middleware';
import { ctfLimiter, ctfSolveLimiter } from '../../shared/middlewares/rate-limit.middleware';

const router = Router();

router.use(requireCtfEnabled);

// Top of the funnel — no account needed, so a curious visitor can start now.
router.get('/', briefing);
router.get('/ch02', ch02);
router.get('/ch03', ch03);
router.get('/leaderboard', leaderboard);

// Everything past here is attributable to a real, verified student.
const asStudent = [authenticate, requireVerifiedEmail];

router.get('/ch04', ...asStudent, ch04);
router.get('/ch05/start', ...asStudent, ch05Start);
router.get('/ch05/hop/:token', ...asStudent, ch05Hop);
router.get('/ch06', ...asStudent, ch06Challenge);
router.post('/ch06', ctfSolveLimiter, ...asStudent, ch06Submit);
router.get('/ch07', ...asStudent, ch07);

router.post('/submit', ctfLimiter, ...asStudent, submitFlag);
router.get('/progress', ...asStudent, myProgress);
router.post('/leaderboard/opt-in', ctfLimiter, ...asStudent, setLeaderboardOptIn);

export default router;

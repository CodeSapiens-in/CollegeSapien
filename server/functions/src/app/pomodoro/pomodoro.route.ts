import { Router } from 'express';
import {
  createTimer,
  listTimers,
  getTimerDetail,
  addMembers,
  startSession,
  cancelSession,
} from './pomodoro.controller';
import { authenticate, requireVerifiedEmail } from '../../shared/middlewares/auth.middleware';

const router = Router();

router.post('/timers', authenticate, requireVerifiedEmail, createTimer);
router.get('/timers', authenticate, requireVerifiedEmail, listTimers);
router.get('/timers/:id/detail', authenticate, requireVerifiedEmail, getTimerDetail);
router.patch('/timers/:id/members', authenticate, requireVerifiedEmail, addMembers);
router.post('/timers/:id/sessions', authenticate, requireVerifiedEmail, startSession);
router.post('/sessions/:id/cancel', authenticate, requireVerifiedEmail, cancelSession);

export default router;

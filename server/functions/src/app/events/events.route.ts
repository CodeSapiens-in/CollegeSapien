import { Router } from 'express';
import {
  getApprovedEvents,
  createEvent,
  getPendingEvents,
  approveEvent,
  rejectEvent,
} from './events.controller';
import { authenticate, requireVerifiedEmail } from '../../shared/middlewares/auth.middleware';
import { isEventModerator } from '../../shared/middlewares/role.middleware';

const router = Router();

// Public / Authenticated endpoints for regular users
router.get('/', authenticate, requireVerifiedEmail, getApprovedEvents);
router.post('/', authenticate, requireVerifiedEmail, createEvent);

// Moderator / Admin / Ambassador endpoints
router.get('/pending', authenticate, requireVerifiedEmail, isEventModerator, getPendingEvents);
router.patch('/:id/approve', authenticate, requireVerifiedEmail, isEventModerator, approveEvent);
router.patch('/:id/reject', authenticate, requireVerifiedEmail, isEventModerator, rejectEvent);

export default router;

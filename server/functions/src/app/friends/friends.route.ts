import { Router } from 'express';
import {
  getOverview,
  sendRequest,
  acceptRequest,
  rejectRequest,
  removeFriend,
} from './friends.controller';
import { authenticate, requireVerifiedEmail } from '../../shared/middlewares/auth.middleware';

const router = Router();

router.get('/overview', authenticate, requireVerifiedEmail, getOverview);
router.post('/requests', authenticate, requireVerifiedEmail, sendRequest);
router.post('/requests/:id/accept', authenticate, requireVerifiedEmail, acceptRequest);
router.post('/requests/:id/reject', authenticate, requireVerifiedEmail, rejectRequest);
router.delete('/:uid', authenticate, requireVerifiedEmail, removeFriend);

export default router;

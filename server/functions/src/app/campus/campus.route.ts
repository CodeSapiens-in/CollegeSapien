import { Router } from 'express';
import { listWaitlist } from './campus.controller';
import { authenticate, requireVerifiedEmail } from '../../shared/middlewares/auth.middleware';
import { isSuperAdmin } from '../../shared/middlewares/role.middleware';

const router = Router();
router.get('/waitlist', authenticate, requireVerifiedEmail, isSuperAdmin, listWaitlist);
export default router;

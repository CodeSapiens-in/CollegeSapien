import { Router } from 'express';
import { markAttendance, getAttendanceSummary, syncAttendance } from './attendance.controller';
import { authenticate, requireVerifiedEmail } from '../../shared/middlewares/auth.middleware';

// OpenAPI documentation for these routes lives in ./attendance.openapi.ts

const router = Router();

router.post('/', authenticate, requireVerifiedEmail, markAttendance);

router.post('/sync', authenticate, requireVerifiedEmail, syncAttendance);

router.get('/summary', authenticate, requireVerifiedEmail, getAttendanceSummary);

export default router;

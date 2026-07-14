import { Router } from 'express';
import {
  uploadTimetable,
  getTimetable,
  parseTimetable,
  deleteTimetable,
} from './timetable.controller';
import { authenticate, requireVerifiedEmail } from '../../shared/middlewares/auth.middleware';

// OpenAPI documentation for these routes lives in ./timetable.openapi.ts

const router = Router();

router.post('/', authenticate, requireVerifiedEmail, uploadTimetable);

router.post('/parse', authenticate, requireVerifiedEmail, parseTimetable);

router.get('/', authenticate, requireVerifiedEmail, getTimetable);

router.delete('/', authenticate, requireVerifiedEmail, deleteTimetable);

export default router;

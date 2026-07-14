import { Router } from 'express';
import {
  calculateCGPA,
  predictExternalMarks,
  getSemesters,
  saveSemesters,
} from './cgpa.controller';
import { authenticate, requireVerifiedEmail } from '../../shared/middlewares/auth.middleware';

// OpenAPI documentation for these routes lives in ./cgpa.openapi.ts

const router = Router();

router.post('/calculate', authenticate, requireVerifiedEmail, calculateCGPA);

router.post('/predict', authenticate, requireVerifiedEmail, predictExternalMarks);

router.get('/semesters', authenticate, requireVerifiedEmail, getSemesters);
router.post('/semesters', authenticate, requireVerifiedEmail, saveSemesters);

export default router;

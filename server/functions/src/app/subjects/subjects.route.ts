import { Router } from 'express';
import { createSubject, listSubjectsForCollege } from './subjects.controller';
import { authenticate, requireVerifiedEmail } from '../../shared/middlewares/auth.middleware';

// OpenAPI documentation for these routes lives in ./subjects.openapi.ts

const router = Router();

router.get('/college/:collegeId', listSubjectsForCollege);

router.post('/', authenticate, requireVerifiedEmail, createSubject);

export default router;

import { Router } from 'express';
import {
  getSyllabus,
  getHubResources,
  uploadResource,
  updateResourceFileUrl,
  reportResource,
} from './resources.controller';
import { authenticate, requireVerifiedEmail } from '../../shared/middlewares/auth.middleware';
import { uploadLimiter } from '../../shared/middlewares/rate-limit.middleware';

// OpenAPI documentation for these routes lives in ./resources.openapi.ts

const router = Router();

router.get('/syllabus', authenticate, requireVerifiedEmail, getSyllabus);

router.get('/hub', authenticate, requireVerifiedEmail, getHubResources);

router.post('/upload', uploadLimiter, authenticate, requireVerifiedEmail, uploadResource);
router.patch('/:id', authenticate, requireVerifiedEmail, updateResourceFileUrl);

router.post('/report', uploadLimiter, authenticate, requireVerifiedEmail, reportResource);

export default router;

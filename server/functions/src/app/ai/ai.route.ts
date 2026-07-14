import { Router } from 'express';
import { roastResume, memeIt } from './ai.controller';
import { authenticate, requireVerifiedEmail } from '../../shared/middlewares/auth.middleware';

// OpenAPI documentation for these routes lives in ./ai.openapi.ts

const router = Router();

router.post('/roast-resume', authenticate, requireVerifiedEmail, roastResume);

router.post('/meme-it', authenticate, requireVerifiedEmail, memeIt);

export default router;

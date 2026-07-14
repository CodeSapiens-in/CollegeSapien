import { Router } from 'express';
import {
  getCurriculum,
  uploadPendingCurricula,
  listPendingCurricula,
  getPendingCurriculum,
  listCurricula,
  approvePendingCurricula,
  rejectPendingCurricula,
  updatePendingCurriculum,
  updateCurriculum,
  deleteCurriculum,
} from './curriculum.controller';
import { authenticate, requireVerifiedEmail } from '../../shared/middlewares/auth.middleware';
import { isAdmin } from '../../shared/middlewares/role.middleware';

// OpenAPI documentation for these routes lives in ./curriculum.openapi.ts

const router = Router();

router.get('/', getCurriculum);

router.post('/pending', authenticate, requireVerifiedEmail, isAdmin, uploadPendingCurricula);
router.get('/pending', authenticate, requireVerifiedEmail, isAdmin, listPendingCurricula);

router.post(
  '/pending/approve',
  authenticate,
  requireVerifiedEmail,
  isAdmin,
  approvePendingCurricula
);

router.post('/pending/reject', authenticate, requireVerifiedEmail, isAdmin, rejectPendingCurricula);

router.get('/pending/:id', authenticate, requireVerifiedEmail, isAdmin, getPendingCurriculum);

router.patch('/pending/:id', authenticate, requireVerifiedEmail, isAdmin, updatePendingCurriculum);

router.get('/admin', authenticate, requireVerifiedEmail, isAdmin, listCurricula);

router.patch('/admin/:id', authenticate, requireVerifiedEmail, isAdmin, updateCurriculum);
router.delete('/admin/:id', authenticate, requireVerifiedEmail, isAdmin, deleteCurriculum);

export default router;

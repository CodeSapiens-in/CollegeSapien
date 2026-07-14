import { Router } from 'express';
import {
  assignRole,
  listUsers,
  resolveReport,
  getUserById,
  banUser,
  unbanUser,
  getResourceStats,
  unarchiveResource,
  getCmsContent,
  updateCmsContent,
} from './admin.controller';
import {
  getReports,
  deleteResource,
  listPendingResources,
  listApprovedResources,
  listArchivedResources,
  approveResource,
  rejectResource,
} from '../resources/resources.controller';
import { authenticate, requireVerifiedEmail } from '../../shared/middlewares/auth.middleware';
import { isSuperAdmin, isModerator } from '../../shared/middlewares/role.middleware';

// OpenAPI documentation for these routes lives in ./admin.openapi.ts

const router = Router();

router.post('/assign-role', authenticate, requireVerifiedEmail, isSuperAdmin, assignRole);

router.get('/users', authenticate, requireVerifiedEmail, isSuperAdmin, listUsers);
router.get('/users/:id', authenticate, requireVerifiedEmail, isSuperAdmin, getUserById);
router.patch('/users/:id/ban', authenticate, requireVerifiedEmail, isSuperAdmin, banUser);
router.patch('/users/:id/unban', authenticate, requireVerifiedEmail, isSuperAdmin, unbanUser);

router.get('/reports', authenticate, requireVerifiedEmail, isModerator, getReports);

router.patch(
  '/reports/:id/resolve',
  authenticate,
  requireVerifiedEmail,
  isModerator,
  resolveReport
);

router.get('/resources/stats', authenticate, requireVerifiedEmail, isSuperAdmin, getResourceStats);
router.get(
  '/resources/approved',
  authenticate,
  requireVerifiedEmail,
  isModerator,
  listApprovedResources
);
router.get(
  '/resources/archived',
  authenticate,
  requireVerifiedEmail,
  isModerator,
  listArchivedResources
);
router.patch(
  '/resources/:id/unarchive',
  authenticate,
  requireVerifiedEmail,
  isModerator,
  unarchiveResource
);
router.delete('/resources/:id', authenticate, requireVerifiedEmail, isModerator, deleteResource);

router.get(
  '/resources/pending',
  authenticate,
  requireVerifiedEmail,
  isModerator,
  listPendingResources
);

router.patch(
  '/resources/:id/approve',
  authenticate,
  requireVerifiedEmail,
  isModerator,
  approveResource
);

router.patch(
  '/resources/:id/reject',
  authenticate,
  requireVerifiedEmail,
  isModerator,
  rejectResource
);

router.get('/cms', authenticate, requireVerifiedEmail, isModerator, getCmsContent);
router.put('/cms/:key', authenticate, requireVerifiedEmail, isSuperAdmin, updateCmsContent);

export default router;

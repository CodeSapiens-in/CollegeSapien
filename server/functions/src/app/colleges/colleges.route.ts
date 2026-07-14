import { Router } from 'express';
import { createCollege, listColleges, updateCollege, deleteCollege, listCombined, createDepartment, listDepartments, updateDepartment, deleteDepartment } from './colleges.controller';
import { authenticate, requireVerifiedEmail } from '../../shared/middlewares/auth.middleware';
import { isSuperAdmin } from '../../shared/middlewares/role.middleware';

// OpenAPI documentation for these routes lives in ./colleges.openapi.ts

const router = Router();

router.get('/', listColleges);

router.get('/combined', listCombined);
router.get('/departments', listDepartments);
router.post('/departments', authenticate, requireVerifiedEmail, isSuperAdmin, createDepartment);
router.put('/departments/:id', authenticate, requireVerifiedEmail, isSuperAdmin, updateDepartment);
router.delete('/departments/:id', authenticate, requireVerifiedEmail, isSuperAdmin, deleteDepartment);

router.post('/', authenticate, requireVerifiedEmail, isSuperAdmin, createCollege);

router.put('/:id', authenticate, requireVerifiedEmail, isSuperAdmin, updateCollege);

router.delete('/:id', authenticate, requireVerifiedEmail, isSuperAdmin, deleteCollege);

export default router;

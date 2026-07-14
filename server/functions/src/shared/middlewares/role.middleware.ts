import type { NextFunction, Response } from 'express';
import type { AuthRequest } from './auth.middleware';

export const checkRole = (roles: string[]) => {
  return (req: AuthRequest, res: Response, next: NextFunction) => {
    if (!req.user) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const userRole = (req.user as any)?.role || 'user';

    if (!roles.includes(userRole)) {
      return res.status(403).json({ error: 'Forbidden: Insufficient permissions' });
    }

    return next();
  };
};

export const isModerator = checkRole(['moderator', 'admin', 'superadmin']);
export const isAdmin = checkRole(['admin', 'superadmin']);
export const isSuperAdmin = checkRole(['superadmin']);

// Events moderation is additionally delegated to ambassadors.
export const isEventModerator = checkRole(['ambassador', 'moderator', 'admin', 'superadmin']);

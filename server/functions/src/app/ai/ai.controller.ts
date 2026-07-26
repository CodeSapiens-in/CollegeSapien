import { Response } from 'express';
import { AuthRequest } from '../../shared/middlewares/auth.middleware';

export const roastResume = async (_req: AuthRequest, res: Response) => {
  return res.status(503).json({ error: 'Resume roast is temporarily unavailable.' });
};

export const memeIt = async (_req: AuthRequest, res: Response) => {
  return res.status(503).json({ error: 'Meme generation is temporarily unavailable.' });
};

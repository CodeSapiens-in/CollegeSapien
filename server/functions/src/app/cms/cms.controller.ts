import { Request, Response } from 'express';
import * as admin from 'firebase-admin';
import { log } from '../../shared/logger';

export const getPublicCmsContent = async (req: Request, res: Response) => {
  try {
    const db = admin.firestore();
    const snapshot = await db.collection('app_content').get();

    // Convert to a simple key-value map for the app to consume easily
    const content: Record<string, any> = {};
    snapshot.docs.forEach(doc => {
      content[doc.id] = doc.data().value;
    });

    // Cache 1-hourly via Cache-Control header
    res.setHeader('Cache-Control', 'public, max-age=3600, s-maxage=3600');
    return res.status(200).json(content);
  } catch (error: any) {
    log.error('Unhandled error', { path: res.req?.path, error: String(error) });
    return res.status(500).json({ error: 'Internal server error' });
  }
};

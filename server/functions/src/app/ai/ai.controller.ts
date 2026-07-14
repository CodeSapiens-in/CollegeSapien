import { Response } from 'express';
import { AuthRequest } from '../../shared/middlewares/auth.middleware';
import type { GoogleGenerativeAI } from '@google/generative-ai';
import * as admin from 'firebase-admin';

// AI features are currently disabled (see roastResume/memeIt below and index.ts). Loading
// @google/generative-ai costs ~700KB of eager parse/require on every cold start of this
// function if imported at the top level, so defer it until something actually calls a
// Gemini-backed code path.
let genAIPromise: Promise<GoogleGenerativeAI> | undefined;

function getGenAI(): Promise<GoogleGenerativeAI> {
  genAIPromise ??= import('@google/generative-ai').then(
    ({ GoogleGenerativeAI }) => new GoogleGenerativeAI(process.env.GEMINI_API_KEY || '')
  );
  return genAIPromise;
}

export const roastResume = async (req: AuthRequest, res: Response) => {
  return res.status(503).json({ error: 'Resume roast is temporarily unavailable.' });

  try {
    const { resumeText, storagePath, mimeType, fileBase64 } = req.body;
    if (!resumeText && !storagePath && !fileBase64) {
      return res.status(400).json({ error: 'resumeText, storagePath, or fileBase64 is required' });
    }

    const genAI = await getGenAI();
    const model = genAI.getGenerativeModel({ model: 'gemini-3.5-flash' });
    const prompt = `Roast this student's resume in a funny way. Keep it light-hearted but savage. Use a bit of Tanglish (Tamil + English) for flavor.`;

    let result;

    if (storagePath) {
      // Handle file from Firebase Storage
      const bucket = admin.storage().bucket();
      const [fileBuffer] = await bucket.file(storagePath).download();
      const base64 = fileBuffer.toString('base64');
      const fileMimeType = (mimeType as string) || 'application/pdf';

      result = await withRetry(() =>
        model.generateContent([prompt, { inlineData: { data: base64, mimeType: fileMimeType } }])
      );
    } else if (fileBase64) {
      // Handle inline base64 file sent directly from app
      const fileMimeType = (mimeType as string) || 'application/pdf';
      result = await withRetry(() =>
        model.generateContent([
          prompt,
          { inlineData: { data: fileBase64 as string, mimeType: fileMimeType } },
        ])
      );
    } else {
      // Handle pasted text
      result = await model.generateContent(`${prompt} Resume content: ${resumeText}`);
    }

    const response = await result.response;
    const text = response.text();

    return res.status(200).json({ roast: text });
  } catch (error: any) {
    return res.status(500).json({ error: error.message });
  }
};

interface ResourceAnalysis {
  categoryMatchesExpected: boolean;
  aiSuggestedCategory: 'Notes' | 'QP' | 'Syllabus' | null;
  isSpam: boolean;
  keywords: string[];
}

async function withRetry<T>(fn: () => Promise<T>, maxRetries = 3, baseDelayMs = 2000): Promise<T> {
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      return await fn();
    } catch (err: any) {
      if (attempt === maxRetries - 1) throw err;
      await new Promise(res => setTimeout(res, baseDelayMs * Math.pow(2, attempt)));
    }
  }
  throw new Error('Unreachable');
}

export const processResourceDocument = async (
  resourceId: string,
  data: Record<string, any>
): Promise<void> => {
  const docRef = admin.firestore().collection('hub_resources').doc(resourceId);

  try {
    const genAI = await getGenAI();
    const model = genAI.getGenerativeModel({ model: 'gemini-3.1-pro-preview' });
    const expectedCategory = data.category as string;
    const resourceName = (data.name as string) ?? '';

    const prompt = `You are reviewing an academic resource upload. The uploader tagged it as category: "${expectedCategory}".
Resource name: "${resourceName}"
${data.storagePath ? 'The document content is attached.' : ''}

Return ONLY a JSON object (no markdown, no extra text) with these fields:
{
  "categoryMatchesExpected": true/false,
  "aiSuggestedCategory": "Notes" | "QP" | "Syllabus" | null,
  "isSpam": true/false,
  "keywords": ["keyword1", "keyword2", ...]
}

Rules:
- categoryMatchesExpected: does the document actually match "${expectedCategory}"?
- aiSuggestedCategory: what category does it actually belong to? null if it matches.
- isSpam: true if the content is irrelevant to academics, offensive, or clearly not educational material.
- keywords: 5-10 relevant academic keywords extracted from the document.`;

    let analysis: ResourceAnalysis;

    if (data.storagePath) {
      const bucket = admin.storage().bucket();
      const [fileBuffer] = await bucket.file(data.storagePath).download();
      const base64 = fileBuffer.toString('base64');
      const mimeType = (data.mimeType as string) || 'application/pdf';

      const result = await withRetry(() =>
        model.generateContent([prompt, { inlineData: { data: base64, mimeType } }])
      );
      analysis = parseAnalysisResponse(result.response.text());
    } else {
      const result = await withRetry(() => model.generateContent(prompt));
      analysis = parseAnalysisResponse(result.response.text());
    }

    const update: Record<string, any> = {
      keywords: analysis.keywords,
      aiSpamFlag: analysis.isSpam,
      aiSuggestedCategory: analysis.aiSuggestedCategory,
      aiProcessed: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (analysis.isSpam) {
      update.status = 'rejected';
      update.rejectedReason = 'AI spam detection';
      update.rejectedAt = admin.firestore.FieldValue.serverTimestamp();
    } else if (analysis.categoryMatchesExpected) {
      update.status = 'approved';
      update.approvedBy = 'ai-auto-approval';
    }

    await docRef.update(update);
  } catch (err) {
    console.error(`processResourceDocument failed for ${resourceId}:`, err);
    await docRef
      .update({ aiProcessed: true, updatedAt: admin.firestore.FieldValue.serverTimestamp() })
      .catch(updateError => {
        console.error('Failed to mark AI processing status', updateError);
      });
  }
};

function parseAnalysisResponse(text: string): ResourceAnalysis {
  try {
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (!jsonMatch) throw new Error('No JSON in response');
    const parsed = JSON.parse(jsonMatch[0]);
    return {
      categoryMatchesExpected: Boolean(parsed.categoryMatchesExpected),
      aiSuggestedCategory: parsed.aiSuggestedCategory ?? null,
      isSpam: Boolean(parsed.isSpam),
      keywords: Array.isArray(parsed.keywords) ? parsed.keywords.slice(0, 10) : [],
    };
  } catch {
    return {
      categoryMatchesExpected: true,
      aiSuggestedCategory: null,
      isSpam: false,
      keywords: [],
    };
  }
}

export const memeIt = async (req: AuthRequest, res: Response) => {
  return res.status(503).json({ error: 'Meme generation is temporarily unavailable.' });

  try {
    const { content } = req.body;
    if (!content) return res.status(400).json({ error: 'Content is required' });

    const genAI = await getGenAI();
    const model = genAI.getGenerativeModel({ model: 'gemini-3.5-flash' });
    const prompt = `Convert this student's profile or achievement into a funny Tamil Meme description. Be creative. Content: ${content}`;

    const result = await model.generateContent(prompt);
    const response = await result.response;
    const text = response.text();

    return res.status(200).json({ memeDescription: text });
  } catch (error: any) {
    return res.status(500).json({ error: error.message });
  }
};

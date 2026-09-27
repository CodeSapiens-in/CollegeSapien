import type { NextFunction, Request, Response } from 'express';

// Applied to every JSON route. Nothing here is meant to be rendered as a
// document, so the policy denies everything and re-opens only the handful of
// directives a plain API response can legitimately need.
const API_CSP = [
  "default-src 'none'",
  "base-uri 'none'",
  "form-action 'none'",
  "frame-ancestors 'none'",
  "object-src 'none'",
].join('; ');

// Swagger UI is the one browser-rendered surface on this server, and it is
// served from node_modules rather than a CDN, so 'self' covers every asset it
// pulls. The inline-style allowance is required by the `customCss` option and
// by the initializer script swagger-ui-express generates.
const DOCS_CSP = [
  "default-src 'self'",
  "base-uri 'none'",
  "form-action 'self'",
  "frame-ancestors 'none'",
  "object-src 'none'",
  "img-src 'self' data: blob:",
  "font-src 'self' data:",
  "style-src 'self' 'unsafe-inline'",
  "script-src 'self'",
  "connect-src 'self'",
  "worker-src 'self' blob:",
].join('; ');

const PERMISSIONS_POLICY = [
  'accelerometer=()',
  'autoplay=(self)',
  'camera=()',
  'display-capture=()',
  'geolocation=()',
  'gyroscope=()',
  'magnetometer=()',
  'microphone=()',
  'midi=()',
  'payment=()',
  'usb=()',
].join(', ');

const isDocsRequest = (req: Request) =>
  req.path === '/api/docs' || req.path.startsWith('/api/docs/');

export const securityHeaders = (req: Request, res: Response, next: NextFunction) => {
  res.setHeader('Content-Security-Policy', isDocsRequest(req) ? DOCS_CSP : API_CSP);
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('Referrer-Policy', 'no-referrer');
  res.setHeader('Permissions-Policy', PERMISSIONS_POLICY);
  res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
  res.removeHeader('X-Powered-By');
  next();
};

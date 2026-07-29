import express from 'express';
import cors from 'cors';
import cookieParser from 'cookie-parser';
import * as admin from 'firebase-admin';
import swaggerUi from 'swagger-ui-express';
import { getSpecs } from './shared/docs/swagger';
import { enforceAppCheck } from './shared/middlewares/app-check.middleware';
import { requestLogger } from './shared/logger';
import authRoutes from './app/auth/auth.route';
import attendanceRoutes from './app/attendance/attendance.route';
import timetableRoutes from './app/timetable/timetable.route';
import cgpaRoutes from './app/cgpa/cgpa.route';
import resourceRoutes from './app/resources/resources.route';
import aiRoutes from './app/ai/ai.route';
import adminRoutes from './app/admin/admin.route';
import collegeRoutes from './app/colleges/colleges.route';
import subjectRoutes from './app/subjects/subjects.route';
import syllabusRoutes from './app/syllabus/syllabus.route';
import cmsRoutes from './app/cms/cms.route';
import curriculumRoutes from './app/curriculum/curriculum.route';
import eventsRoutes from './app/events/events.route';
import friendsRoutes from './app/friends/friends.route';
import pomodoroRoutes from './app/pomodoro/pomodoro.route';

const app = express();
app.set('query parser', 'extended');

// functions-framework v5 (Cloud Functions gen2) fronts this app with Express 5, where
// req.query is a prototype getter. Express 4 skips its own query parsing when it sees
// that getter, then discards it on re-init — leaving req.query undefined. Re-parse it.
app.use((req, _res, next) => {
  if (req.query === undefined) {
    const queryIndex = req.url.indexOf('?');
    (req as { query: Record<string, string> }).query =
      queryIndex >= 0 ? Object.fromEntries(new URLSearchParams(req.url.slice(queryIndex + 1))) : {};
  }
  next();
});

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const corsOrigins = (process.env.CORS_ORIGINS || '')
  .split(',')
  .map(origin => origin.trim())
  .filter(Boolean);

app.use(
  cors({
    origin: corsOrigins.length > 0 ? corsOrigins : true,
    credentials: true,
  })
);
app.use(cookieParser());
app.use((req: any, res, next) => {
  if (req.rawBody !== undefined) {
    // Cloud Run (Firebase Functions v2) pre-consumes the stream; rawBody is a Buffer
    if (!req.body || Object.keys(req.body).length === 0) {
      try {
        req.body = req.rawBody.length ? JSON.parse(req.rawBody.toString('utf8')) : {};
      } catch {
        req.body = {};
      }
    }
    return next();
  }
  express.json({ limit: '8mb' })(req, res, next);
});
app.use(requestLogger);
app.use((req, res, next) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('Referrer-Policy', 'no-referrer');
  res.setHeader('X-Frame-Options', 'DENY');
  next();
});

// Handle Swagger Redirect Issue in Firebase Emulator
// We use a custom path for swagger-ui-express to prevent incorrect absolute redirects
const swaggerOptions = {
  swaggerOptions: {
    url: '/api/docs/swagger.json',
  },
};

app.get('/api/docs/swagger.json', (req, res) => {
  res.setHeader('Content-Type', 'application/json');
  res.send(getSpecs());
});

// Serve Swagger UI with specific paths to avoid emulator redirect issues
app.use('/api/docs', swaggerUi.serve);
let swaggerUiHandler: ReturnType<typeof swaggerUi.setup> | undefined;
app.get('/api/docs', (req, res, next) => {
  swaggerUiHandler ??= swaggerUi.setup(getSpecs(), {
    ...swaggerOptions,
    customCss: '.swagger-ui .topbar { display: none }',
  });
  swaggerUiHandler(req, res, next);
});

app.get('/api/v1/health', (req, res) => {
  res.status(200).json({ status: 'ok', message: 'CodeSapiens API is healthy' });
});

app.use(enforceAppCheck);

app.use('/api/v1/auth', authRoutes);
app.use('/api/v1/attendance', attendanceRoutes);
app.use('/api/v1/timetable', timetableRoutes);
app.use('/api/v1/cgpa', cgpaRoutes);
app.use('/api/v1/resources', resourceRoutes);
app.use('/api/v1/ai', aiRoutes);
app.use('/api/v1/admin', adminRoutes);
app.use('/api/v1/colleges', collegeRoutes);
app.use('/api/v1/subjects', subjectRoutes);
app.use('/api/v1/syllabus', syllabusRoutes);
app.use('/api/v1/curriculum', curriculumRoutes);
app.use('/api/v1/events', eventsRoutes);
app.use('/api/v1/friends', friendsRoutes);
app.use('/api/v1/pomodoro', pomodoroRoutes);

app.use('/api/v1/cms', cmsRoutes);

export { app };

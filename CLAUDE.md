# CollegeSapien (CodeSapiens)

University attendance, timetable, and syllabus management platform.

## Monorepo Structure

```
app/          → Flutter mobile app (iOS/Android/Web) — Dart, SDK >=3.0
admin/        → Admin dashboard — Nuxt 3, Vue, UnoCSS, Pinia, pnpm
server/       → Backend — Firebase Cloud Functions (TypeScript, Node 22)
website/      → Marketing site — static HTML hosted on Firebase
data/         → Syllabus datasets (data/syllabus/)
.github/      → CI workflows (see CI/CD section)
```

## App (`app/`)

Flutter app. Entry: `lib/main.dart`. Key directories under `lib/`:

- `screens/` — feature screens: home, auth, onboarding, attendance, syllabus, cgpa, pomodoro, ai_features, resources, profile
- `models/` — data models
- `providers/` — global app state (cache-first with background refresh, e.g. `app_state_notifier.dart`)
- `services/` — API and platform services (`services/platform/` for platform-specific)
- `data/` — local data layer
- `widgets/` — shared widgets
- `utils/` — utilities
- `core/` — core app infrastructure

Auth: Firebase Auth + Google Sign-In. Storage: Firebase Storage + SharedPreferences.
Tests: `test/` (unit/widget), `integration_test/` (integration).

Run: `cd app && flutter run`
Test: `cd app && flutter test`
Integration test: `cd app && flutter test integration_test/`

## Admin (`admin/`)

Nuxt 3 app. Key directories under `app/`:

- `pages/` — ambassadors, cms, colleges, events, moderation, reports, resources, syllabus, users
- `components/`, `composables/`, `stores/` (Pinia), `layouts/`, `middleware/`, `plugins/`, `public/`, `utils/`

Run: `cd admin && pnpm dev`
Build: `cd admin && pnpm build`
Lint: `cd admin && pnpm lint`

## Server (`server/`)

Firebase project: `collegesapiens`. Functions source: `server/functions/src/`. Express 5.0, npm (package-lock.json; not pnpm).

Domain modules under `src/app/`: admin, ai, attendance, auth, cgpa, cms, colleges, curriculum, events, resources, subjects, syllabus, timetable.
Shared: `src/shared/` (docs, middlewares), `src/db/` (Firestore helpers), `src/ses/` (email via AWS SES).

Firestore rules: `server/firestore.rules`
Storage rules: `server/storage.rules`
Database rules: `server/database.rules.json`

Build: `cd server/functions && npx tsc`
Deploy functions: `cd server && firebase deploy --only functions`
Emulators: `cd server/functions && npm run serve`

## Firebase Hosting Targets

- `app1` / `app2` → Flutter web app
- `admin` → Admin dashboard (`admin-collegesapiens`)
- Note: 4 separate `firebase.json` files exist (root, `app/`, `server/`, `website/`); root's only defines `app1`/`app2`.

## CI/CD (`.github/workflows/`)

- `android-release-build.yml` — manual, signed/obfuscated Android release bundle
- `firebase-functions-deploy.yml` — manual, deploys Firebase Functions
- `firebase-hosting-merge.yml` — deploys hosting on push to `main`
- `firebase-hosting-pull-request.yml` — deploys hosting preview on PRs

## Conventions

- Server functions: TypeScript with ESLint
- Admin: ESLint + Prettier, Husky pre-commit hooks
- App: Dart analysis via `analysis_options.yaml`
- Environment variables: `admin/.env` (see `.env.example`)

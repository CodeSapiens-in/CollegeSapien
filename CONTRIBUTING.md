# Contributing to CollegeSapien

Thanks for taking the time to contribute.

## Code of Conduct

By participating, you agree to follow the [Code of Conduct](./CODE_OF_CONDUCT.md).

## Contributing Content

### Syllabus (via Pull Request)

Syllabus data lives in `data/syllabus/` as flat `.csv` or `.json` files, one per college/regulation/course combo.

1. Name the file `<COLLEGE_CODE>_<REGULATION>_<COURSE_CODE>.csv` (or `.json`), e.g. `RMD_R2021_AIML.csv`.
2. Use one of the existing files as a template and follow its column/field structure — see the [Syllabus Data & CSV Structure](./README.md#-syllabus-data--csv-structure) section of the README for the full field reference (`college`, `college_code`, `course`, `course_code`, `regulation`, `semester`, `subject_code`, `subject_name`, `credits`, `category`, `elective_type`, `record_type`).
3. For `.json` files, the header fields (`college`, `college_code`, `course`, `course_code`, `regulation`) are set once at the top level, with per-subject fields nested under a `subjects` array.
4. `record_type` is `core` for mandatory subjects or `option` for elective-pool subjects; set `elective_type` to the pool name for `option` rows, otherwise `null`.
5. Open a PR with just the new/updated file(s) in `data/syllabus/`. It goes through admin review (Syllabus Uploader validates schema) before being published in the app.

### Events, Question Papers & Notes (via the app)

These are submitted directly from the mobile app, not through a PR:

- **Events** — Home tab → create/submit an event (`create_event_screen.dart`). Goes to admin moderation before appearing publicly.
- **Question Papers** — Resources → Question Papers (`qp_hub_screen.dart`) → upload.
- **Notes** — Resources → Notes (`notes_hub_screen.dart`) → upload.

All submissions are reviewed/moderated in the admin portal before going live.

## Repository Layout

- `admin/` — Nuxt 3 admin dashboard
- `server/` — Firebase backend (Cloud Functions + rules)
- `app/` — Flutter mobile app

## Getting Started

### Admin (Nuxt 3)

```bash
cd admin
pnpm install
pnpm dev
```

### Server (Firebase Functions)

```bash
cd server/functions
pnpm install
pnpm build
pnpm serve
```

### Mobile App (Flutter)

```bash
cd app
flutter pub get
flutter run
```

## Running Checks

### Admin

```bash
cd admin
pnpm lint
pnpm build
```

### Server

```bash
cd server/functions
pnpm lint
pnpm build
```

### Mobile App

```bash
cd app
flutter analyze
flutter test
```

## Commit Messages

Use short conventional commits in the format: `type: summary` (example: `feat: add subject filters`).

## Pull Requests

- Keep PRs focused and scoped to one area of the repo.
- Include a brief description, checks run, and screenshots for UI changes.
- Avoid committing secrets or local environment files.

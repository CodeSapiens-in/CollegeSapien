# Security Headers

Every browser-facing surface in this repo sets a baseline set of response
headers. This file records what is set, where, and — more importantly — **why
the non-obvious exceptions exist**, so nobody tightens a directive and breaks
production in the process.

| Surface | Configured in | Served by |
| --- | --- | --- |
| Marketing site | `firebase.json` (`hosting:app2`) | Firebase Hosting |
| Marketing site (standalone config) | `website/firebase.json` | Firebase Hosting |
| Flutter web app | `firebase.json` (`hosting:app1`) | Firebase Hosting |
| Admin dashboard | `admin/nuxt.config.ts` → `routeRules` | Nitro (Nuxt) |
| REST API + Swagger | `server/functions/src/shared/middlewares/security-headers.middleware.ts` | Cloud Functions |

`firebase.json` at the repo root is what CI actually deploys
(`firebase-hosting-merge.yml` and `firebase-hosting-website.yml` both run
`firebase deploy --only hosting:app1|app2` from the root). `website/firebase.json`
is kept byte-for-byte equivalent to the `app2` block so the site is also
deployable from `website/` directly. **If you change one, change both.**

## The directives

| Directive | Value | Why |
| --- | --- | --- |
| `X-Content-Type-Options` | `nosniff` | Stops MIME sniffing turning a JSON response or an upload into script. |
| `X-Frame-Options` | `DENY` | Clickjacking. Belt-and-braces with CSP `frame-ancestors 'none'`. |
| `Strict-Transport-Security` | `max-age=31536000` | HTTPS-only. |
| `Referrer-Policy` | `strict-origin-when-cross-origin` (web) / `no-referrer` (API) | The API never needs referrer data; the site wants origin-level only. |
| `Permissions-Policy` | camera/mic/geo/etc. disabled | No surface in this repo uses them. `image_picker` is only ever called with `ImageSource.gallery`, which is a file input, not `getUserMedia`. |
| `Cross-Origin-Opener-Policy` | `same-origin-allow-popups` | `signInWithPopup` needs `window.opener` intact. The strict `same-origin` value severs it and **breaks Google sign-in in the admin panel**. |
| `Content-Security-Policy` | per-surface, see below | |

`Strict-Transport-Security` deliberately omits `includeSubDomains` on the web
surfaces. Those are served from subdomains of `codesapiens.in`, and
`includeSubDomains` is a statement about *every* subdomain, not just this one —
it should be a deliberate domain-level decision, not something a single
hosting config opts into. It is safe on the API host because that is a dedicated
`*.a.run.app` subdomain.

`Cross-Origin-Resource-Policy` is intentionally **not** set anywhere.
`frame-ancestors 'none'` plus `X-Frame-Options: DENY` already block framing
completely, and CORP would additionally break the tweaks panel's `postMessage`
host protocol, which expects to be embedded during design review.

## Why the website CSP is as loose as it is

The marketing site serves three different documents from one host — the
landing page, the legal pages, and `app/data/delete/` — behind a single
`"source": "**"` glob. Firebase Hosting merges matching header blocks, and
rather than depend on that merge order the policy below is the **union** of
what all three documents need. It is the safe choice: a per-page policy that
gets the glob order wrong takes a page down.

The landing page loads React and Babel standalone from `unpkg.com` and
transpiles `tweaks-panel.jsx` in the browser, which is why the policy needs
`'unsafe-inline'` and `'unsafe-eval'`. **Both are required.** Babel compiles
JSX via `new Function`; without `eval` the tweaks panel and the theme switcher
throw and nothing on the page initialises.

That is the main thing to fix someday: drop the in-browser Babel step, then
`'unsafe-eval'` and the `unpkg.com` allowance both become removable. Until
then, do not tighten this directive — you will break the site.

`connect-src` covers the account-deletion page, which signs in against Firebase
Auth (`*.googleapis.com`) and calls the API (`*.run.app`).

## Why the admin CSP differs

- **No `'unsafe-eval'`.** Nuxt ships the Vue runtime-only build, so unlike the
  marketing site it genuinely does not need it. This is the directive that
  actually carries weight.
- **`'unsafe-inline'` for scripts is still required** — Nuxt inlines the entry
  and payload scripts. A nonce would fix this properly; Nuxt does not expose one
  for the payload script without custom app-level plumbing.
- **`connect-src` lists the Iconify endpoints** because no `@iconify-json/*`
  collections are installed, so `@nuxt/icon` can fall back to fetching icons at
  runtime. Adding a server bundle would let these be dropped:

  ```ts
  icon: { serverBundle: { collections: ["heroicons"] } },
  ```

- **The CSP is attached to production builds only** (`process.env.NODE_ENV ===
  "production"`). Vite's dev client needs `eval` and injected styles, so
  applying it in development breaks HMR.
- **`img-src` allows bare `https:`** because resource thumbnails and profile
  photos come from user-controlled Storage paths, not just `*.googleapis.com`.
  SVG loaded through `<img>` cannot execute script, so this is low risk.

## Why the API CSP differs

The API returns JSON. CSP only applies to browser *document* contexts — it has
no effect on `fetch`/XHR responses or on the Flutter mobile clients at all — so
the useful part here is `default-src 'none'` on JSON routes, which keeps a
mis-typed response from ever being treated as a document.

`/api/docs` is the one genuinely rendered surface, so it gets its own relaxed
policy. It is served from `node_modules` rather than a CDN, so `'self'` covers
every asset Swagger UI pulls; `'unsafe-inline'` for styles is required by the
`customCss` option and the generated initializer script.

`X-Powered-By` is disabled outright (`app.disable('x-powered-by')`), which stops
the API advertising Express.

## The admin's deployment path (worth knowing)

`admin/nuxt.config.ts` sets `ssr: false`, so this is a single-page app. The
documented build (`pnpm build` → `nuxt build`) still emits a Nitro server
(`.output/server/index.mjs`) that serves the SPA, so **`routeRules` headers are
applied on that path** — verified by running the built server and inspecting the
response.

Two caveats:

- If anyone switches to `pnpm generate` and uploads `.output/public` to a static
  host, the headers are silently lost. `nuxt generate` does not emit a response
  header config. A `_headers` file (Netlify/Cloudflare Pages) would survive that;
  a Firebase Hosting `headers` block in an `admin/firebase.json` would not be
  picked up by a non-Firebase host.
- **There is no deployment configuration for the admin anywhere in the repo** —
  no workflow references it, no `admin/firebase.json` exists, and there is no
  `netlify.toml` / `vercel.json` / `Dockerfile`. The `admin` target in
  `.firebaserc` is therefore not deployable as-is, because `firebase deploy
  --only hosting:admin` needs a matching `firebase.json` entry. The admin is
  evidently published out of band, which is a gap worth closing in its own right:
  whatever process does it should be captured in the repo so these headers can't
  be lost without anyone noticing.

## The Flutter web app has no CSP yet

`app/web/index.html` is the standard async-bootstrap template, and the app uses
Firebase Auth (including Google sign-in) and the `*.run.app` API. The
non-execution-related headers *are* already applied to `hosting:app1`; only the
CSP is missing, because the built output isn't in the repo and a wrong directive
takes the deployed app down with no way to catch it in review.

Derived from `app/web/index.html` and the engine's requirements, this is the
policy to start from — **validate it against a real `flutter build web` in a
preview channel before shipping**, in particular whether the renderer is
CanvasKit or skwasm and whether `flutter_bootstrap.js` injects inline script:

```
default-src 'self';
script-src 'self' 'unsafe-inline' https://www.gstatic.com 'wasm-unsafe-eval';
style-src 'self' 'unsafe-inline';
font-src 'self' data:;
img-src 'self' data: blob: https:;
connect-src 'self' https://*.googleapis.com https://*.firebaseapp.com https://*.run.app https://www.gstatic.com blob:;
worker-src 'self' blob:;
frame-src 'self' https://accounts.google.com https://*.firebaseapp.com;
manifest-src 'self';
object-src 'none';
base-uri 'self';
form-action 'self';
frame-ancestors 'none';
```

Notes on the non-obvious entries: `wasm-unsafe-eval` and `worker-src blob:` are
both required by the CanvasKit/skwasm renderers; `gstatic.com` is where the
engine's WASM and canvaskit bundles are fetched from unless you bundle them
locally with `--wasm`; `frame-src` is there because Google sign-in renders in a
cross-origin frame. Bundling canvaskit locally (`--source-maps` aside, the
`FLUTTER_WASM`/canvaskit local bundle) would let the `gstatic.com` allowance be
dropped.

Also note `app/firebase.json` is a legacy single-site config with no `target`,
so it deploys to the project's *default* site rather than `app1`. CI uses the
root `firebase.json`, which is what carries the headers.

## Remaining gaps

- **The admin still sends `x-powered-by: Nuxt`.** Suppressing it needs a Nitro
  server middleware, which — per the deployment notes above — would not run at
  all if the built output is served from a static host. Not worth the extra
  moving part for a cosmetic header on a Firebase-Auth-gated app.
- **The Flutter web CSP above is unvalidated.** See the preceding section.

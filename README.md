# SlamDone — GitHub PWA

SlamDone is the GitHub-hosted continuation of Autivra4 V6.4.1. It keeps the planner data model and core screens while moving daily use to one installable web app for PC and Android.

Production URL after Pages is enabled:

`https://Sallam101.github.io/SlamDone/`

## Architecture

- Flutter web/PWA hosted by GitHub Pages.
- Browser-persistent SQLite (WASM + IndexedDB) remains the local-first database.
- Firebase Authentication provides Google sign-in.
- Cloud Firestore synchronizes each signed-in user's planner records across devices.
- Large embedded NorthStar images are split into UID-scoped Firestore chunk documents so no planner document exceeds Firestore's per-document size limit; Firebase Storage is not required for this migration baseline.
- Autivra migration happens from a private migration JSON chosen in the browser; personal migration files are never committed to GitHub.

The planner UI writes to local SQLite first. SlamDone then queues changed records for Firestore. Cloud records merge back into local SQLite using the existing Autivra ordering: higher revision, then newer `client_updated_at`, then device ID as deterministic tie-break.

## SlamDone 7.3 daily-use upgrade

- Branded SlamDone header/drawer with **Plan • Focus • Finish**.
- Big Picture quick status toggles for Active, Completed, Archived, and All.
- Journal period filters (Week/Month/Year/All) and four display densities.
- Resizable floating timer.
- Consistent spatial navigation guidance: wheel pan, middle-drag 4-way pan, Ctrl+wheel zoom.
- Explicit phone hamburger navigation with every planner section in the drawer.

## SlamDone 7.2 workflow improvements

- Completing a nested **Task** starts a four-second **Undo** grace period, then archives it automatically. Parent goals/projects are never auto-archived.
- Big Picture and Mind Map hide archived items by default and can filter them back in for review/unarchive.
- Structured Big Picture, Free Canvas/Mind Map, and NorthStar support middle-mouse panning and Ctrl+wheel zoom.
- Free Canvas cards preserve compact status/progress chips as cards are resized.
- Focus includes a draggable in-app floating timer overlay, so the PWA does not depend on a Windows EXE.

## Deploy

1. Create the GitHub repository `Sallam101/SlamDone` with `main` as the production branch.
2. Follow [FIREBASE_SETUP.md](FIREBASE_SETUP.md) and add the Firebase web configuration as GitHub **Repository variables**.
3. In GitHub **Settings → Pages**, choose **GitHub Actions** as the source.
4. Push to `main`. `.github/workflows/pages.yml` runs the contract tests, Flutter tests, release web build, and Pages deployment.
5. Open `https://Sallam101.github.io/SlamDone/` and sign in with Google.
6. On Android Chrome, use **Add to Home screen / Install app** if you want the app-like launcher experience.

Required repository variables:

- `FIREBASE_API_KEY`
- `FIREBASE_AUTH_DOMAIN`
- `FIREBASE_PROJECT_ID`
- `FIREBASE_STORAGE_BUCKET`
- `FIREBASE_MESSAGING_SENDER_ID`
- `FIREBASE_APP_ID`
- `FIREBASE_MEASUREMENT_ID` — optional; leave empty if the Firebase web app does not provide one.

Firebase web configuration is client configuration, not an admin credential. Firestore Security Rules are the data-access boundary. Never commit service-account JSON, Admin SDK credentials, private keys, `.db` files, or personal migration JSON.

## One-time Autivra migration

See [MIGRATION_AUTIVRA4.md](MIGRATION_AUTIVRA4.md). The complete migration format includes the normal planner entities plus journal history and timer state that were not present in the old standard Autivra JSON export.

After a successful import, SlamDone records the source checksum so importing the same migration file again is idempotent rather than duplicating records.

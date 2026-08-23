# SupeSlam — GitHub PWA

SupeSlam is the GitHub-hosted continuation of Autivra4 V6.4.1. It keeps the planner data model and core screens while moving daily use to one installable web app for PC and Android.

Production URL after Pages is enabled:

`https://Sallam101.github.io/SupeSlam/`

## Architecture

- Flutter web/PWA hosted by GitHub Pages.
- Browser-persistent SQLite (WASM + IndexedDB) remains the local-first database.
- Firebase Authentication provides Google sign-in.
- Cloud Firestore synchronizes each signed-in user's planner records across devices.
- Large embedded NorthStar images are split into UID-scoped Firestore chunk documents so no planner document exceeds Firestore's per-document size limit; Firebase Storage is not required for this migration baseline.
- Autivra migration happens from a private migration JSON chosen in the browser; personal migration files are never committed to GitHub.

The planner UI writes to local SQLite first. SupeSlam then queues changed records for Firestore. Cloud records merge back into local SQLite using the existing Autivra ordering: higher revision, then newer `client_updated_at`, then device ID as deterministic tie-break.

## Deploy

1. Create the GitHub repository `Sallam101/SupeSlam` with `main` as the production branch.
2. Follow [FIREBASE_SETUP.md](FIREBASE_SETUP.md) and add the Firebase web configuration as GitHub **Repository variables**.
3. In GitHub **Settings → Pages**, choose **GitHub Actions** as the source.
4. Push to `main`. `.github/workflows/pages.yml` runs the contract tests, Flutter tests, release web build, and Pages deployment.
5. Open `https://Sallam101.github.io/SupeSlam/` and sign in with Google.
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

After a successful import, SupeSlam records the source checksum so importing the same migration file again is idempotent rather than duplicating records.

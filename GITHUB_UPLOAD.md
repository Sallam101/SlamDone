# Put SlamDone on GitHub without returning to the EXE workflow

This repository is the web/PWA branch. Do not upload an Autivra database or the private migration JSON into the repository.

## Repository

Target: `Sallam101/SlamDone`

1. Create the repository if it does not already exist, or open the existing SlamDone repository.
2. Put the **contents** of the SlamDone GitHub package at the repository root (so `pubspec.yaml`, `lib/`, `.github/`, `firestore.rules`, etc. are at the top level).
3. Commit to `main`.
4. In **Settings → Pages**, choose **GitHub Actions**.
5. Add the Firebase repository variables listed in `FIREBASE_SETUP.md`.
6. Push/commit. The Pages workflow runs the Python contracts, Flutter tests, web build, and deployment.

## Import your existing Autivra progress

Keep `Autivra4_to_SlamDone_Migration_2026-08-23.json` private and outside GitHub.

After the Pages deployment is green:

1. Open `https://Sallam101.github.io/SlamDone/`.
2. Sign in with the Google account that will own the planner data.
3. Open **Settings → Migration, saving and backup**.
4. Select **Import Existing Autivra4 Progress**.
5. Choose `Autivra4_to_SlamDone_Migration_2026-08-23.json`.
6. Verify Big Picture, Mind Map, Journal, Focus history, Habits, NorthStar, Rewards, Study Tables, and Settings.
7. Open SlamDone on the phone, sign into the same Google account, and allow Firestore sync to populate that device.

The import is stable-ID/checksum based, so re-selecting the same migration file is designed not to duplicate the planner records.

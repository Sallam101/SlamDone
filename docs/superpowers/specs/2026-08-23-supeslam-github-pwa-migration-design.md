# SupeSlam GitHub PWA + Autivra4 Migration Design

**Date:** 2026-08-23  
**Source baseline:** Autivra4 Android/Windows V6.4.1 (`6.4.1+91`)  
**Target:** SupeSlam web/PWA hosted from GitHub, Firebase-backed, with one-time full migration of existing Autivra4 progress

## 1. Goal

Convert the latest Autivra4 planner into **SupeSlam**, a GitHub-hosted Flutter web/PWA that runs from one URL on PC and Android, can be installed from the browser, updates through GitHub deployments, and preserves the user's existing Autivra4 planner data.

This is an **upgrade path**, not a rewrite from zero. The existing models, controller behavior, hierarchy logic, timers, rewards, habits, journals, NorthStar, study tables, layouts, and most UI code should be retained wherever they are platform-neutral.

The native Windows EXE / Android APK distribution path is no longer the primary product path for SupeSlam.

## 2. Success criteria

The migration is successful when all of the following are true:

1. `Sallam101/SupeSlam` can be deployed as a GitHub Pages PWA from `main` using GitHub Actions.
2. The app opens on desktop Chrome/Edge and Android Chrome from the same HTTPS URL.
3. The app is installable as a PWA on PC and phone.
4. Google sign-in identifies the user through Firebase Authentication.
5. Each Firebase user can only read/write their own planner records.
6. Local changes save immediately even when offline.
7. When connectivity returns, local changes sync to Firestore.
8. The user's existing Autivra4 database can be imported once without recreating records manually.
9. Import preserves stable IDs so hierarchy relationships, layouts, habit entries, and journal links remain intact.
10. Import does not seed demo/sample planner records first.
11. After migration, the imported record counts and key settings match the source database.
12. GitHub never contains the user's private database, exported progress, journals, Firebase admin credentials, or other private user content.
13. Future SupeSlam code updates do not require downloading or rebuilding the large native Windows/Android source package.

## 3. Recovered source reality

The V6.4.1 source is a Flutter native app with these main layers:

- models
- `LocalDatabase` using SQLite/sqflite
- `AppRepository`
- `AppController`
- `SyncService`
- screens/widgets
- timer/export helpers

The existing local-first design is valuable and should be preserved. It already stores stable record IDs, revisions, timestamps, device IDs, and soft-deletion metadata.

### 3.1 Native-only blockers

The current source cannot compile directly to web because several reachable files use:

- `dart:io`
- `Platform.isWindows` / `Platform.isAndroid`
- filesystem `File` and `Directory`
- `path_provider`
- Windows `window_manager`
- native-only file export/import paths
- Google Drive desktop-folder synchronization
- native timer-process launching

These must be isolated behind platform abstractions or replaced in the web target.

### 3.2 Existing data export gap

Autivra4's existing JSON export already covers the major synchronized entity tables plus settings, but it omits:

- `journal_versions`
- `timer_state`

For the requested **whole-progress migration**, SupeSlam migration must include those two tables as well. `sync_queue` is intentionally not migrated because it is transport state, not user progress.

## 4. Source database to migrate

The recovered strong-master database passed SQLite `PRAGMA integrity_check` with `ok`.

Current record inventory:

| Table | Rows | Migration |
|---|---:|---|
| `work_items` | 34 | Yes |
| `canvas_layouts` | 67 | Yes |
| `habits` | 7 | Yes |
| `habit_entries` | 7 | Yes |
| `journal_entries` | 2 | Yes |
| `journal_versions` | 0 | Yes, schema supported even when empty |
| `northstar_notes` | 5 | Yes |
| `reward_ranks` | 9 | Yes |
| `study_tables` | 4 | Yes |
| `time_sessions` | 4 | Yes |
| `timer_state` | 1 | Yes |
| `app_settings` | 42 | Yes |
| `sync_queue` | 0 | No |

The migration process must validate counts after import and report discrepancies before marking migration complete.

## 5. Target architecture

### 5.1 Hosting and delivery

- Repository: `Sallam101/SupeSlam`
- Branch: `main`
- Host: GitHub Pages
- Deployment: GitHub Actions on pushes to `main`
- Build target: Flutter web release
- Base href: repository Pages path
- PWA manifest/service worker included in build output

The GitHub repository contains application code and public Firebase web configuration only. Public Firebase web configuration identifies the Firebase project but is not an admin secret; security is enforced by Firebase Authentication and Firestore Security Rules.

### 5.2 Local-first persistence

Use SQLite semantics in the browser to minimize rewriting the existing repository/database code.

Recommended implementation:

- shared SQLite API through `sqflite_common/sqlite_api.dart`
- native database factory removed from the SupeSlam target
- web factory supplied by `sqflite_common_ffi_web`
- SQLite WASM stored in the web build
- browser persistence backed by IndexedDB

Reason: the current app repository is deeply SQL-shaped. Preserving the SQL schema avoids rewriting every repository query into Firestore-specific operations and reduces regression risk.

Important constraint: `sqflite_common_ffi_web` is currently documented as experimental. Therefore the storage layer must remain behind a small interface so it can later be replaced without rewriting screens/controllers.

### 5.3 Cloud sync

Replace the SupeSlam web target's Supabase/Drive sync path with **Firebase Authentication + Cloud Firestore**.

Local SQLite remains the immediate source of truth for UI responsiveness. Firestore is the cross-device synchronization layer.

Flow:

`UI -> Repository -> Local SQLite -> sync queue -> Firestore`

and

`Firestore snapshots -> conflict comparison -> Local SQLite -> controller refresh`

### 5.4 Firebase document structure

Use a per-user namespace:

`users/{uid}/entities/{entityType}/records/{id}` is too deep/awkward for querying, so use one subcollection per entity type:

- `users/{uid}/work_items/{id}`
- `users/{uid}/canvas_layouts/{id}`
- `users/{uid}/journal_entries/{id}`
- `users/{uid}/journal_versions/{id}`
- `users/{uid}/time_sessions/{id}`
- `users/{uid}/habits/{id}`
- `users/{uid}/habit_entries/{id}`
- `users/{uid}/northstar_notes/{id}`
- `users/{uid}/reward_ranks/{id}`
- `users/{uid}/study_tables/{id}`
- `users/{uid}/settings/{settingKey}`
- `users/{uid}/meta/timer_state`
- `users/{uid}/meta/migration`

Every synchronized entity retains:

- stable `id`
- `revision`
- `client_updated_at`
- `device_id`
- `deleted_at` when applicable

### 5.5 Conflict behavior

Retain Autivra4's existing deterministic merge order for entity rows:

1. higher revision wins
2. if equal, newer `client_updated_at` wins
3. if equal, device ID provides deterministic tie-break

For Firestore writes, use this metadata to reject older incoming snapshots at the local merge layer.

No blind overwrite of a newer local record by an older cloud record.

For settings, use `updated_at` plus device ID metadata in the Firestore setting document because the existing `app_settings` table does not carry revision/device fields per setting.

## 6. Authentication and privacy

### 6.1 Authentication

Primary login: Google through Firebase Authentication.

Desktop web may use popup sign-in. Mobile web should support redirect sign-in when popup behavior is unreliable.

### 6.2 Firestore rules

Security Rules must enforce:

- user must be authenticated
- path UID must equal `request.auth.uid`
- users cannot enumerate or access another user's namespace

There must be no global public planner collection.

### 6.3 GitHub privacy boundary

Never commit:

- `.db` files
- Autivra JSON migration files containing user content
- local exported backups
- service-account JSON
- private keys
- Firebase Admin SDK credentials
- environment files containing secrets

Firebase web config (`apiKey`, `authDomain`, project ID, etc.) may be included because it is client configuration, not authorization. Firestore rules remain the security boundary.

## 7. Migration design

### 7.1 Migration artifact

Create a one-time file named similar to:

`Autivra4_to_SupeSlam_Migration_2026-08-23.json`

It contains:

```json
{
  "format": "supeslam-autivra-migration",
  "formatVersion": 1,
  "source": {
    "application": "Autivra4",
    "version": "6.4.1",
    "databaseSchema": 6
  },
  "exportedAt": "...",
  "entities": {
    "work_items": [],
    "canvas_layouts": [],
    "journal_entries": [],
    "journal_versions": [],
    "time_sessions": [],
    "habits": [],
    "habit_entries": [],
    "northstar_notes": [],
    "reward_ranks": [],
    "study_tables": []
  },
  "timer_state": {},
  "settings": {},
  "validation": {
    "sourceCounts": {}
  }
}
```

This migration file is private user data and stays outside GitHub.

### 7.2 Import workflow

In SupeSlam Settings:

1. User signs in with Google.
2. User chooses **Import Existing Autivra4 Progress**.
3. Browser file picker selects the migration JSON.
4. SupeSlam validates format/version and source counts before changing data.
5. SupeSlam checks the current Firebase user namespace.
6. If the namespace already contains real data, SupeSlam offers merge-safe import rather than destructive replacement.
7. Records are written first to local SQLite in a transaction/batched sequence.
8. Stable IDs are preserved.
9. All imported records are queued for Firestore sync under the signed-in UID.
10. Settings and timer state are applied.
11. Controllers reload.
12. A validation screen compares source counts vs imported local counts.
13. Firestore sync completes.
14. Migration metadata records completion and source checksum.

### 7.3 Idempotency

Importing the same migration file twice must not duplicate records.

Use stable record IDs plus a migration checksum. Existing IDs are merged by the same revision/timestamp rules.

### 7.4 Demo data protection

The current `AppRepository.initialize()` inserts sample work items if `work_items` is empty and also inserts default reward ranks / a default study table.

For SupeSlam:

- sample work-item seeding must be disabled
- first-run default ranks/tables may only be created after the app knows the user is starting fresh
- migration mode must never create defaults before the import finishes

This prevents demo records from mixing with real Autivra data.

## 8. Platform refactor

### 8.1 Database boundary

Create a small database bootstrap abstraction:

- web implementation uses `databaseFactoryFfiWeb`
- all shared DB methods continue using a platform-neutral `Database` API
- remove direct `dart:io` and `path_provider` decisions from shared database code

### 8.2 Platform information

Replace direct `Platform.isWindows/Android` in shared controller/UI with a platform capability service, for example:

- `isWeb`
- `isDesktopViewport`
- `supportsNativeFloatingWindow`
- `supportsFileSystemFolderSync`
- `supportsBrowserDownload`

The SupeSlam web target reports native folder sync and native floating-process support as false.

### 8.3 File import/export

Web-safe behavior:

- JSON import: browser file picker / bytes
- backup export: browser download
- CSV/Excel/Word exports: generate bytes in memory and download from browser
- NorthStar image import: browser-selected bytes, not `File(path)`

No filesystem path is required.

### 8.4 Timer behavior

Retain the in-app focus timer, time-session records, streaks, goals, reward points, and history.

Remove the Windows-specific secondary executable/process model.

If a floating timer is later desired in the PWA, implement it as a normal responsive overlay / picture-in-picture-style web UI where supported, not a second Windows process.

## 9. UI and branding

Visible branding changes to **SupeSlam**.

Keep the existing major sections and workflows:

- Overview
- Do First
- Big Picture
- Mind Map
- Focus To Win
- Tasks & Checklists
- Calendar
- Habits
- Journal
- NorthStar
- Rewards
- GTD + PARA
- Study Tables
- Settings

Responsive behavior:

- wide desktop: sidebar/top navigation and larger canvas/workspace
- phone: compact navigation, vertical panels, touch-friendly controls

Do not re-architect planner logic merely for visual rebranding.

## 10. GitHub repository contents

Expected top-level structure:

```text
SupeSlam/
  .github/
    workflows/
      pages.yml
  assets/
  docs/
    superpowers/specs/
  lib/
  test/
  web/
    index.html
    manifest.json
    icons/
    sqlite3.wasm
    sqflite_sw.js
  firestore.rules
  firebase.json
  pubspec.yaml
  README.md
  .gitignore
```

No native installer BAT files are required in the SupeSlam web repository.

## 11. GitHub Actions deployment

On push to `main`:

1. checkout
2. install pinned Flutter stable version compatible with the project
3. `flutter pub get`
4. generate/verify sqflite web WASM support assets
5. `flutter analyze`
6. `flutter test`
7. `flutter build web --release --base-href /SupeSlam/`
8. upload Pages artifact
9. deploy to GitHub Pages

Deployment must fail if analyze/tests/build fail.

## 12. Testing strategy

### 12.1 Unit tests

- model map round-trips
- conflict comparator
- migration parser
- migration idempotency
- settings migration
- timer-state migration
- source-count validation
- no-default-seed behavior during migration

### 12.2 Database tests

- create schema on web factory
- load/save each entity type
- hierarchy parent relationships survive reload
- canvas layouts preserve device-class keys
- local database survives browser refresh

### 12.3 Firebase tests

Using Firebase Emulator Suite where practical:

- user A cannot read user B
- user A cannot write user B
- offline local writes queue and later push
- incoming newer cloud row merges
- incoming older cloud row is ignored
- deletion tombstones sync correctly

### 12.4 Migration acceptance test

Using a sanitized copy of the recovered Autivra DB/export:

- source counts are captured
- import completes with no duplicate IDs
- destination counts match expected counts
- sample items are absent unless present in source
- settings values match
- goal hierarchy resolves with no orphan parent IDs
- habit entry references resolve
- layouts resolve to existing work items where applicable
- timer history and current state load
- Firestore receives the imported dataset under only the signed-in user

## 13. Rollout sequence

### Phase A — Web-compile baseline

Make shared code compile and run as Flutter web with local browser SQLite only. No cloud migration yet.

### Phase B — Firebase identity + sync

Add Firebase Authentication, Firestore adapter, rules, and local-to-cloud queue processing.

### Phase C — Migration

Add full Autivra migration schema, private migration-file generator, web import UI, validation, idempotency, and cloud upload.

### Phase D — GitHub Pages

Add workflow, PWA metadata/icons, base-path handling, README, and deployment configuration.

### Phase E — Validation

Import the recovered master data into a test user, compare counts/settings, test PC/phone sync, then perform the user's real migration.

## 14. Non-goals for this migration

To avoid restarting from square one, this migration will not initially:

- redesign every screen
- replace the hierarchy model
- replace the rewards model
- add unrelated new productivity systems
- preserve the Windows floating EXE process
- preserve Google Drive desktop-folder sync
- commit private user data to GitHub

Those can be handled later after the GitHub/PWA baseline is stable.

## 15. Key risks and mitigations

### Risk: web SQLite package is experimental

Mitigation: isolate the database factory/bootstrap and keep repository access through shared SQLite API. If the package becomes unsuitable, replace only the persistence adapter rather than screens/controllers.

### Risk: `dart:io` is spread across multiple screens/services

Mitigation: remove reachability through explicit platform services and web-safe byte-based import/export helpers, not ad-hoc compile flags in every widget.

### Risk: migration accidentally adds defaults

Mitigation: migration-aware initialization plus tests proving sample seeding is disabled before import.

### Risk: old and new devices overwrite each other

Mitigation: keep stable IDs/revisions/timestamps/device IDs and deterministic conflict rules.

### Risk: Firestore data becomes public

Mitigation: per-UID paths and Firestore Security Rules tested against unauthorized reads/writes before production deployment.

### Risk: GitHub Pages route/base path breaks assets

Mitigation: build with `/SupeSlam/` base href and test service worker/WASM paths in the Pages deployment.

## 16. Final architecture decision

Proceed with:

**Flutter web/PWA + GitHub Pages + browser-persistent SQLite + Firebase Authentication + Firestore row-level sync + one-time full Autivra4 JSON migration.**

This approach preserves the largest amount of the working V6.4.1 planner, avoids native EXE/APK update friction, and creates the same operational pattern the user wants from MathFreak/USCrisp: code updates through GitHub, one web app on PC/phone, and user-specific cloud progress.

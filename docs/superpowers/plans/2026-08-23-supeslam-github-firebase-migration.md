# SupeSlam GitHub Firebase Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert the recovered Autivra4 V6.4.1 planner into a GitHub Pages Flutter PWA named SupeSlam, keep browser-local SQLite as the UI source of truth, add Google/Firebase/Firestore per-user sync, and import the complete August 23 Autivra migration dataset without losing layout, focus-time, journal-history, timer, habit, NorthStar, reward, study-table, or settings state.

**Architecture:** Preserve the existing SQL-shaped repository and `sqflite_common_ffi_web` local persistence. Replace the recovered Supabase web adapter with a Firebase Authentication + Cloud Firestore adapter using per-UID collections, while retaining stable IDs/revisions/timestamps/device IDs and existing conflict ordering. Generate a private one-time migration JSON from the consolidated SQLite master and import it transactionally/idempotently; never commit the user's migration data to GitHub.

**Tech Stack:** Flutter 3.44+, Dart 3.12+, `sqflite_common_ffi_web`, Firebase Core/Auth/Cloud Firestore, GitHub Actions, GitHub Pages, Python 3 for migration generation/contract verification.

**Spec:** `docs/superpowers/specs/2026-08-23-supeslam-github-pwa-migration-design.md`

## Global Constraints

- Visible product name is `SupeSlam`.
- Web/PWA only for this branch; no EXE/APK deployment path.
- GitHub repository contains application code only; never commit `.db`, `.db-wal`, `.db-shm`, private migration JSON, service-account credentials, or private keys.
- Local SQLite remains the immediate source of truth.
- Cloud data is isolated under `users/{uid}/...` and Firestore rules require `request.auth.uid == uid`.
- Preserve stable IDs and merge ordering: higher revision, then newer `client_updated_at`, then lexicographically larger `device_id`.
- Import must include journal versions and timer state in addition to the standard Autivra JSON entities.
- Importing the same migration file twice must not duplicate entity records.
- GitHub Pages build uses base href `/SupeSlam/`.
- Firebase web configuration is client configuration; authorization is enforced by Auth + Firestore Security Rules.

---

### Task 1: Establish privacy and deployment contracts

**Files:**
- Modify: `.gitignore`
- Create: `tool_tests/test_repo_contract.py`
- Create: `firestore.rules`
- Modify: `.github/workflows/pages.yml`

**Interfaces:**
- Consumes: GitHub Pages repository root and the agreed `SupeSlam` repository name.
- Produces: `python -m unittest tool_tests.test_repo_contract`, secure Firestore rules, and a Pages workflow that tests/builds Flutter web.

- [ ] **Step 1: Write the failing repository contract test**

```python
class RepoContractTest(unittest.TestCase):
    def test_private_migration_artifacts_are_ignored(self):
        text = (ROOT / '.gitignore').read_text()
        for pattern in ('*.db', '*.db-wal', '*.db-shm', '*Migration*.json'):
            self.assertIn(pattern, text)

    def test_firestore_rules_are_uid_scoped(self):
        rules = (ROOT / 'firestore.rules').read_text()
        self.assertIn('match /users/{uid}/{document=**}', rules)
        self.assertIn('request.auth.uid == uid', rules)

    def test_pages_build_targets_supeslam_base_href(self):
        workflow = (ROOT / '.github/workflows/pages.yml').read_text()
        self.assertIn('flutter test', workflow)
        self.assertIn('flutter build web --release --base-href /SupeSlam/', workflow)
        self.assertIn('actions/upload-pages-artifact@v4', workflow)
        self.assertIn('actions/deploy-pages@v4', workflow)
```

- [ ] **Step 2: Run it and verify RED**

Run: `python -m unittest tool_tests.test_repo_contract -v`
Expected: FAIL because Firebase rules and the new workflow/privacy patterns are not present yet.

- [ ] **Step 3: Implement the contract files**

Use rules equivalent to:

```text
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
  }
}
```

The workflow must run `flutter pub get`, `flutter test`, `flutter build web --release --base-href /SupeSlam/`, upload `build/web`, and deploy Pages.

- [ ] **Step 4: Run the contract test and verify GREEN**

Run: `python -m unittest tool_tests.test_repo_contract -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add .gitignore firestore.rules .github/workflows/pages.yml tool_tests/test_repo_contract.py
git commit -m "build: secure SupeSlam GitHub Pages deployment"
```

### Task 2: Replace Supabase bootstrap with Firebase configuration and Google auth

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/main.dart`
- Create: `lib/src/firebase/firebase_config.dart`
- Modify: `lib/src/services/sync_service.dart`
- Modify: `lib/src/screens/settings_screen.dart`
- Create: `tool_tests/test_firebase_source_contract.py`

**Interfaces:**
- Consumes: Firebase values supplied by `--dart-define=FIREBASE_*` in GitHub Actions.
- Produces: `FirebaseConfig.isConfigured`, `FirebaseConfig.options`, `SyncService.signInWithGoogle()`, `SyncService.signOut()`, `SyncService.currentUser`.

- [ ] **Step 1: Write the failing Firebase source contract test**

```python
class FirebaseSourceContractTest(unittest.TestCase):
    def test_pubspec_uses_flutterfire_not_supabase(self):
        text = (ROOT / 'pubspec.yaml').read_text()
        self.assertIn('firebase_core:', text)
        self.assertIn('firebase_auth:', text)
        self.assertIn('cloud_firestore:', text)
        self.assertNotIn('supabase_flutter:', text)

    def test_main_initializes_firebase_conditionally(self):
        text = (ROOT / 'lib/main.dart').read_text()
        self.assertIn('Firebase.initializeApp', text)
        self.assertIn('FirebaseConfig.isConfigured', text)

    def test_settings_uses_google_sign_in(self):
        text = (ROOT / 'lib/src/screens/settings_screen.dart').read_text()
        self.assertIn('Continue with Google', text)
        self.assertNotIn('Create account', text)
```

- [ ] **Step 2: Run RED**

Run: `python -m unittest tool_tests.test_firebase_source_contract -v`
Expected: FAIL on all three Firebase expectations.

- [ ] **Step 3: Add FlutterFire dependencies and config**

Use:

```yaml
firebase_core: ^4.13.0
firebase_auth: ^6.5.7
cloud_firestore: ^6.8.0
```

`FirebaseConfig.options` must construct `FirebaseOptions` from `String.fromEnvironment` values named `FIREBASE_API_KEY`, `FIREBASE_AUTH_DOMAIN`, `FIREBASE_PROJECT_ID`, `FIREBASE_STORAGE_BUCKET`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_APP_ID`, and optional `FIREBASE_MEASUREMENT_ID`.

- [ ] **Step 4: Replace auth UI and service API**

`signInWithGoogle()` uses `GoogleAuthProvider()` and web popup first, then redirect fallback on popup failure. Remove email/password account creation fields from Settings.

- [ ] **Step 5: Run GREEN**

Run: `python -m unittest tool_tests.test_firebase_source_contract -v`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml lib/main.dart lib/src/firebase/firebase_config.dart lib/src/services/sync_service.dart lib/src/screens/settings_screen.dart tool_tests/test_firebase_source_contract.py
git commit -m "feat: add Firebase Google authentication"
```

### Task 3: Implement Firestore row-level sync with existing conflict semantics

**Files:**
- Modify: `lib/src/database/local_database.dart`
- Modify: `lib/src/services/sync_service.dart`
- Create: `tool_tests/test_firestore_sync_contract.py`
- Create: `test/local_database_conflict_test.dart`

**Interfaces:**
- Consumes: existing `LocalDatabase.loadSyncQueue`, `cloudPayload`, `mergeRemoteRows`, stable entity metadata.
- Produces: Firestore paths `users/{uid}/{entityType}/{id}`, realtime collection subscriptions, setting/timer metadata sync.

- [ ] **Step 1: Write failing static Firestore path tests**

```python
class FirestoreSyncContractTest(unittest.TestCase):
    def test_sync_service_uses_uid_namespaced_collections(self):
        text = (ROOT / 'lib/src/services/sync_service.dart').read_text()
        self.assertIn("collection('users').doc(user.uid)", text)
        self.assertIn("collection(entityType)", text)
        self.assertNotIn('Supabase.instance', text)

    def test_all_required_cloud_tables_are_declared(self):
        text = (ROOT / 'lib/src/services/sync_service.dart').read_text()
        for table in ('work_items','canvas_layouts','journal_entries','journal_versions','time_sessions','habits','habit_entries','northstar_notes','reward_ranks','study_tables'):
            self.assertIn("'$table'", text)
```

- [ ] **Step 2: Run RED**

Run: `python -m unittest tool_tests.test_firestore_sync_contract -v`
Expected: FAIL because sync still calls Supabase and omits journal versions.

- [ ] **Step 3: Expose journal-version/settings/timer cloud payload helpers**

Add database methods that return rows/maps without changing UI models, and retain `_incomingIsNewer` comparison for revisioned entity records.

- [ ] **Step 4: Implement Firestore queue push and collection pull/listeners**

For each revisioned entity, write the document with merge semantics to `users/{uid}/{entityType}/{id}` and apply snapshots through `mergeRemoteRows`. Synchronize settings to `users/{uid}/settings/{key}` and timer state to `users/{uid}/meta/timer_state`.

- [ ] **Step 5: Run static GREEN**

Run: `python -m unittest tool_tests.test_firestore_sync_contract -v`
Expected: PASS.

- [ ] **Step 6: Add Dart conflict regression tests for GitHub Actions**

Test higher revision, then newer timestamp, then device ID tie-break. GitHub Actions must run these with `flutter test` before deployment.

- [ ] **Step 7: Commit**

```bash
git add lib/src/database/local_database.dart lib/src/services/sync_service.dart tool_tests/test_firestore_sync_contract.py test/local_database_conflict_test.dart
git commit -m "feat: sync SupeSlam records through Firestore"
```

### Task 4: Generate the complete private Autivra migration artifact

**Files:**
- Create: `tools/generate_autivra_migration.py`
- Create: `tool_tests/test_migration_generator.py`
- Private output outside repo: `/mnt/data/Autivra4_to_SupeSlam_Migration_2026-08-23.json`

**Interfaces:**
- Consumes: `/mnt/data/supeslam_migration_master/SupeSlam_Autivra_Migration_Master_2026-08-23.db`.
- Produces: migration format `supeslam-autivra-migration`, version `1`, with standard entities plus `journal_versions`, `timer_state`, settings, counts, and SHA-256 source checksum.

- [ ] **Step 1: Write the failing generator test**

The test invokes the generator on a temporary SQLite fixture and asserts all required sections exist, counts match SQL counts, and no `sync_queue` content is exported.

- [ ] **Step 2: Run RED**

Run: `python -m unittest tool_tests.test_migration_generator -v`
Expected: FAIL because the generator does not exist.

- [ ] **Step 3: Implement minimal generator**

Export these tables: `work_items`, `canvas_layouts`, `journal_entries`, `journal_versions`, `time_sessions`, `habits`, `habit_entries`, `northstar_notes`, `reward_ranks`, `study_tables`; export `app_settings` as an object and `timer_state` as one object; omit `sync_queue`.

- [ ] **Step 4: Run GREEN**

Run: `python -m unittest tool_tests.test_migration_generator -v`
Expected: PASS.

- [ ] **Step 5: Generate and validate the user's real private migration file**

Run:

```bash
python tools/generate_autivra_migration.py \
  /mnt/data/supeslam_migration_master/SupeSlam_Autivra_Migration_Master_2026-08-23.db \
  /mnt/data/Autivra4_to_SupeSlam_Migration_2026-08-23.json
```

Expected source counts must equal the verified August 23 database counts.

- [ ] **Step 6: Commit only generator/test, never private output**

```bash
git add tools/generate_autivra_migration.py tool_tests/test_migration_generator.py
git commit -m "feat: generate complete Autivra migration artifact"
```

### Task 5: Implement complete idempotent migration import in SupeSlam

**Files:**
- Modify: `lib/src/database/local_database.dart`
- Modify: `lib/src/repositories/app_repository.dart`
- Modify: `lib/src/controllers/app_controller.dart`
- Modify: `lib/src/screens/settings_screen.dart`
- Create: `lib/src/migration/migration_models.dart`
- Create: `tool_tests/test_import_source_contract.py`
- Create: `test/migration_import_test.dart`

**Interfaces:**
- Consumes: private `supeslam-autivra-migration` JSON.
- Produces: `AppRepository.importMigrationJson(String) -> MigrationImportResult`, local count validation, queueing for Firestore, idempotent stable-ID import, timer/settings application, migration checksum metadata.

- [ ] **Step 1: Write failing import contract tests**

Static tests assert source mentions `journal_versions`, `timer_state`, migration `formatVersion`, checksum, and duplicate-safe stable-ID behavior. Dart tests construct a small migration, import twice, and assert row counts are unchanged on the second import.

- [ ] **Step 2: Run RED static test**

Run: `python -m unittest tool_tests.test_import_source_contract -v`
Expected: FAIL because current importer only handles standard entity lists/settings.

- [ ] **Step 3: Add migration model/validation**

Reject incorrect `format`, unsupported `formatVersion`, missing `validation.sourceCounts`, and malformed entity rows before any transaction writes.

- [ ] **Step 4: Add database transaction import**

Insert missing stable IDs, merge newer same-ID revisioned rows using existing conflict comparison, import journal versions by their IDs, apply timer state/settings, enqueue revisioned records, and store migration checksum metadata.

- [ ] **Step 5: Update Settings migration UI**

Button label: `Import Existing Autivra4 Progress`. Require Firebase sign-in before cloud upload, show pre-import counts and post-import counts, then expose `Sync now`.

- [ ] **Step 6: Run static GREEN**

Run: `python -m unittest tool_tests.test_import_source_contract -v`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/src/migration lib/src/database/local_database.dart lib/src/repositories/app_repository.dart lib/src/controllers/app_controller.dart lib/src/screens/settings_screen.dart tool_tests/test_import_source_contract.py test/migration_import_test.dart
git commit -m "feat: import complete Autivra progress into SupeSlam"
```

### Task 6: Finalize GitHub-ready PWA documentation and verification

**Files:**
- Modify: `README.md`
- Modify: `MIGRATION_AUTIVRA4.md`
- Create: `FIREBASE_SETUP.md`
- Create: `docs/DEPLOYMENT_CHECKLIST.md`
- Modify: `.github/workflows/pages.yml`

**Interfaces:**
- Consumes: Firebase Web App config and GitHub repository variables.
- Produces: one repeatable GitHub setup path and deploy verification checklist.

- [ ] **Step 1: Extend the repository contract test for docs/config variable names**

Assert README/setup include every `FIREBASE_*` variable used by the build and the exact GitHub Pages URL pattern `https://Sallam101.github.io/SupeSlam/`.

- [ ] **Step 2: Run RED**

Run: `python -m unittest discover -s tool_tests -v`
Expected: FAIL until docs/workflow are aligned.

- [ ] **Step 3: Write setup/deployment docs and workflow variable wiring**

Workflow passes GitHub repository variables to Flutter using `--dart-define=FIREBASE_API_KEY=${{ vars.FIREBASE_API_KEY }}` etc. Document Firebase Authorized Domains and Firestore rules deployment.

- [ ] **Step 4: Run local contract suite GREEN**

Run: `python -m unittest discover -s tool_tests -v`
Expected: PASS, zero failures.

- [ ] **Step 5: Run privacy scan**

Run:

```bash
find . -type f \( -name '*.db' -o -name '*.db-wal' -o -name '*.db-shm' \) -print
find . -type f -iname '*Migration*.json' -print
```
Expected: no private migration/database files inside repository.

- [ ] **Step 6: Verify Git status and create release archive**

Create `/mnt/data/SupeSlam_GitHub_Firebase_V7_1_0.zip` excluding `.git`, `.worktrees`, generated builds, and private data.

- [ ] **Step 7: Commit**

```bash
git add README.md MIGRATION_AUTIVRA4.md FIREBASE_SETUP.md docs/DEPLOYMENT_CHECKLIST.md .github/workflows/pages.yml tool_tests
git commit -m "docs: make SupeSlam GitHub Firebase deployment repeatable"
```

- [ ] **Step 8: GitHub execution gate**

If an authenticated GitHub write connection exists, create/update `Sallam101/SupeSlam`, push `main`, enable Pages through Actions, and inspect the first workflow run. If no authenticated write connection exists, provide the verified repository ZIP and exact upload/settings steps; do not claim it was pushed.

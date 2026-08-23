# SlamDone V7.9 Primary-PC Reconciliation + Tasks Command Center Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix dependency-safe phone reconciliation, add a Primary-PC authority policy with additive phone progress, and make Tasks a compact high-use filtered command center.

**Architecture:** Keep the existing local-first SQLite + Firestore design, but split structural authority from additive progress. Reconcile work items parent-first before layouts/sessions, add explicit primary-device metadata to sync settings, and implement Tasks filtering as pure presentation/query logic over the existing WorkItem model.

**Tech Stack:** Flutter/Dart, sqflite_common_ffi_web SQLite WASM, Firebase Auth + Cloud Firestore, Python repository contract tests.

**Spec:** `docs/superpowers/specs/2026-08-23-primary-pc-mobile-reconciliation-tasks-filters-design.md`

## Global Constraints

- Preserve existing Firebase user paths and authentication.
- Preserve WorkItem wire/storage serialization.
- Preserve desktop Structured Big Picture, hierarchy layout engine, and Free Canvas behavior.
- Never delete local planner records during reconciliation.
- Primary PC wins structural conflicts; phone progress/new IDs remain additive.
- Work-item inserts must be parent-before-child.
- Task smart filters combine by OR; search/level restrictions narrow by AND.

---

### Task 1: Reproduce and guard the foreign-key failure

**Files:**
- Create: `tool_tests/test_slamdone_v79_contract.py`
- Modify: `lib/src/data/local_database.dart`

**Interfaces:**
- Consumes: existing `LocalDatabase.applyRemoteRecord(...)` / work-item write path.
- Produces: dependency-safe `applyRemoteWorkItemsParentFirst(List<Map<String,dynamic>> records)` helper (or equivalent focused helper).

- [ ] **Step 1: Write a failing source contract** that requires a parent-first work-item reconciliation helper, deferred-child loop, explicit orphan detection, and usage from the full sync path.
- [ ] **Step 2: Run** `python3 -m unittest tool_tests.test_slamdone_v79_contract -v` and confirm failure.
- [ ] **Step 3: Implement parent-first reconciliation** so rows with empty parent insert first, children only insert after their parent exists locally, and unresolved parent IDs are returned/reported rather than inserted.
- [ ] **Step 4: Run the focused test** and confirm pass.

### Task 2: Primary-PC authority metadata and structural merge policy

**Files:**
- Modify: `lib/src/sync/firestore_sync_service.dart`
- Modify: `lib/src/app_controller.dart`
- Modify: `lib/src/screens/settings_screen.dart`
- Test: `tool_tests/test_slamdone_v79_contract.py`

**Interfaces:**
- Produces: `isPrimaryDevice`, `setPrimaryDevice()`, primary-device id stored in sync metadata/settings, and merge policy hooks for structural tables.

- [ ] **Step 1: Add failing contracts** for a visible `Make this my Primary PC` action, a stored primary device id, and primary-authority merge decisions.
- [ ] **Step 2: Run focused tests and verify failure.**
- [ ] **Step 3: Implement primary-device metadata** without changing Firebase auth/user roots.
- [ ] **Step 4: Implement structural conflict resolution** so existing records from the designated primary device win against stale non-primary structural copies, while new remote IDs are still accepted.
- [ ] **Step 5: Expose Primary-PC status in Settings** and require explicit user action to change it.
- [ ] **Step 6: Run focused tests and confirm pass.**

### Task 3: Additive phone progress reconciliation

**Files:**
- Modify: `lib/src/sync/firestore_sync_service.dart`
- Modify: `lib/src/data/local_database.dart` only if required for safe merge helpers
- Test: `tool_tests/test_slamdone_v79_contract.py`

**Interfaces:**
- Consumes stable IDs/revision/timestamp/device metadata.
- Produces additive acceptance for new quick tasks, completion/checklist state, habit entries, and time sessions without duplication.

- [ ] **Step 1: Add failing contracts** proving new IDs from non-primary devices are accepted and stable IDs prevent duplicate reinsertion.
- [ ] **Step 2: Run focused tests and confirm failure.**
- [ ] **Step 3: Implement additive progress merge rules** without making the phone authoritative for structural fields.
- [ ] **Step 4: Run focused tests and confirm pass.**

### Task 4: Tasks command-center toggles

**Files:**
- Modify: `lib/src/screens/tasks_screen.dart`
- Test: `tool_tests/test_slamdone_v79_contract.py`

**Interfaces:**
- Produces per-device UI state for `Active`, `Uncategorized`, `Completed`, `Archived`, `Urgent`, `Overdue`, `Due Today`, `This Week`, `Undated`, plus `All active` and `Clear filters`.

- [ ] **Step 1: Add failing contracts** for all requested toggle labels, default states, quick-task Uncategorized behavior, horizontal phone strip, and OR semantics for smart filters.
- [ ] **Step 2: Run focused tests and verify failure.**
- [ ] **Step 3: Implement filter state and query predicates** while leaving the existing detailed task editor unchanged.
- [ ] **Step 4: Save filter UI preferences locally per device** using the existing app-setting/local UI preference mechanism.
- [ ] **Step 5: Implement compact responsive toolbar** with horizontal scrolling on narrow screens.
- [ ] **Step 6: Run focused tests and confirm pass.**

### Task 5: Diagnostics, versioning, regression protection, package

**Files:**
- Modify: `pubspec.yaml`
- Modify: `CHANGELOG.md`
- Modify: `README.md`
- Modify: `tool_tests/test_slamdone_v79_contract.py`

**Interfaces:**
- Produces release `7.9.0`, validation report, small GitHub patch ZIP, and full source ZIP.

- [ ] **Step 1: Add contracts** requiring V7.9 version labels and diagnostics for primary device + orphan/deferred work items.
- [ ] **Step 2: Run full repository suite** with `python3 -m unittest discover -s tool_tests -v`.
- [ ] **Step 3: Run Dart structural scan** over every `lib/**/*.dart` file.
- [ ] **Step 4: Compare protected desktop spatial files against V7.8** and confirm unchanged where required.
- [ ] **Step 5: Scan release trees** for private DB/migration/backup artifacts and duplicate workflows.
- [ ] **Step 6: Package a minimal patch and full source ZIP**, then re-extract the full ZIP and rerun the repository test suite on the exact packaged tree.

# SlamDone V7.7 Mobile Sync Repair Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Deliver verified full cross-device reconciliation, compact mobile controls, and an Autivra4 v6-compatible reverse export.

**Architecture:** Extend the current local-first Firebase sync service rather than replacing it. Full reconciliation repairs missing cloud/local rows while the existing dirty queue remains the fast path. Mobile presentation changes are width-gated and leave desktop renderers untouched.

**Tech Stack:** Flutter/Dart, sqflite_common_ffi_web, Firebase Auth/Firestore, Python source-contract tests.

**Spec:** `docs/superpowers/specs/2026-08-23-mobile-sync-repair-design.md`

## Global Constraints
- Keep stable record IDs and existing revision/timestamp/device conflict semantics.
- Keep existing Firestore paths and security rules.
- Do not modify desktop hierarchy/canvas renderer behavior.
- Do not include private user data in repository artifacts.
- Reverse export must match native Autivra4 backup root/entity structure and exclude transport-local settings.

---

### Task 1: Verified full reconciliation
**Files:** `lib/src/services/sync_service.dart`, `lib/src/database/local_database.dart`, `lib/src/screens/settings_screen.dart`, `tool_tests/test_slamdone_v77_contract.py`
- [x] Write failing source contracts for full entity reconciliation, verified counts/status, and repair action.
- [x] Run V7.7 contracts and confirm RED.
- [x] Add all-row sync reader and union reconcile algorithm.
- [x] Change realtime status to connected/verifying unless full audit completed.
- [x] Surface verified local/cloud-equivalent counts in Settings.
- [x] Run V7.7 contracts and confirm GREEN.

### Task 2: Compact phone controls
**Files:** `lib/src/screens/big_picture_screen.dart`, `journal_screen.dart`, `do_first_screen.dart`, `northstar_screen.dart`, `focus_screen.dart`, `tool_tests/test_slamdone_v77_contract.py`
- [x] Add failing contracts for mobile compact/collapsible controls.
- [x] Confirm RED.
- [x] Add width-gated collapsed mobile control headers while preserving desktop branches.
- [x] Confirm GREEN.

### Task 3: Autivra4-compatible reverse export
**Files:** `lib/src/repositories/app_repository.dart`, `lib/src/controllers/app_controller.dart`, `lib/src/screens/settings_screen.dart`, `tool_tests/test_slamdone_v77_contract.py`
- [x] Add failing contracts for `version: 6`, `application: Autivra4`, nine entity tables, and local transport-setting exclusion.
- [x] Confirm RED.
- [x] Implement export and Settings button.
- [x] Confirm GREEN.

### Task 4: Regression/package verification
**Files:** `pubspec.yaml`, `CHANGELOG.md`, repository package.
- [x] Bump version to 7.7.0.
- [x] Run full Python contract suite.
- [x] Run Dart structural delimiter scan.
- [x] Verify one Pages workflow and no private DB/migration artifacts.
- [x] Build patch and full-source ZIPs plus validation report.

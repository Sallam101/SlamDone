# SlamDone Mobile Reliability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make SlamDone usable and reliably synced on phones while preserving the desktop planner structure.

**Architecture:** Add a debounced push hook to the existing sync queue and resume-aware reconciliation, then branch only presentation at phone widths. Reuse WorkItemTreeList for mobile Big Picture so the hierarchy model stays identical while avoiding the 720px desktop canvas minimum.

**Tech Stack:** Flutter Web/PWA, Dart, sqflite_common_ffi_web, Firebase Auth/Firestore.

**Spec:** `docs/superpowers/specs/2026-08-23-mobile-reliability-design.md`

## Global Constraints
- No Firestore schema, migration format, SQLite schema, or ID changes.
- Desktop Big Picture Structured/Free Canvas behavior must remain available unchanged.
- Local writes must remain safe if cloud sync is unavailable.

---

### Task 1: Mobile-aware sync draining

**Files:**
- Modify: `lib/src/services/sync_service.dart`
- Modify: `lib/src/controllers/app_controller.dart`
- Modify: `lib/src/screens/home_shell.dart`
- Test: `tool_tests/test_slamdone_v76_mobile_contract.py`

**Interfaces:**
- Produces: `SyncService.schedulePush()` and `SyncService.handleAppResumed()`.

- [ ] Write a contract test requiring a debounced push scheduler, busy retry, and resume sync.
- [ ] Run the test and verify it fails on V7.5.2.
- [ ] Implement the scheduler and lifecycle resume hook.
- [ ] Schedule pushes after user-facing task, habit, layout, and NorthStar mutations.
- [ ] Run the contract test and verify it passes.

### Task 2: Phone-first habits

**Files:**
- Modify: `lib/src/screens/habits_screen.dart`
- Test: `tool_tests/test_slamdone_v76_mobile_contract.py`

**Interfaces:**
- Consumes: existing `AppController.setHabitValue`.
- Produces: phone cards keyed to one selected date.

- [ ] Add failing contract assertions for a mobile breakpoint, selected-day card UI, checkbox logging, and +/- number controls.
- [ ] Run and verify failure.
- [ ] Add the phone card view while leaving the desktop month grid path intact.
- [ ] Run and verify pass.

### Task 3: Compact phone tasks

**Files:**
- Modify: `lib/src/screens/tasks_screen.dart`
- Modify: `lib/src/widgets/work_item_tree_list.dart`
- Test: `tool_tests/test_slamdone_v76_mobile_contract.py`

**Interfaces:**
- Consumes: existing filters and `WorkItemTreeList` hierarchy.
- Produces: phone toolbar with collapsible filters and overflow task actions.

- [ ] Add failing contract assertions for the compact phone toolbar and overflow actions.
- [ ] Run and verify failure.
- [ ] Implement phone-only compact presentation; preserve desktop toolbar/actions.
- [ ] Run and verify pass.

### Task 4: Phone Big Picture hierarchy

**Files:**
- Modify: `lib/src/screens/big_picture_screen.dart`
- Do not modify: `lib/src/widgets/structured_hierarchy_view.dart`
- Do not modify: `lib/src/widgets/hierarchy_layout.dart`
- Test: `tool_tests/test_slamdone_v76_mobile_contract.py`

**Interfaces:**
- Consumes: existing visible item filter and `WorkItemTreeList`.
- Produces: phone hierarchy default with optional Canvas mode.

- [ ] Add failing contract assertions requiring phone hierarchy mode and preserving desktop StructuredHierarchyView.
- [ ] Run and verify failure.
- [ ] Implement the mobile branch and compact mode selector.
- [ ] Verify protected desktop layout files are unchanged.
- [ ] Run full repository contracts.

### Task 5: Version, docs, and packaging

**Files:**
- Modify: `pubspec.yaml`
- Modify: `CHANGELOG.md`

- [ ] Bump to V7.6.0.
- [ ] Document mobile reliability changes.
- [ ] Run all repository contract tests.
- [ ] Run structural scans and private-file/workflow checks.

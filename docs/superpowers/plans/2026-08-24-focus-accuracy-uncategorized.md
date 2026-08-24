# SlamDone V7.14 Focus Accuracy + Uncategorized Visibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make SlamDone focus time conservative/reversible and add non-destructive Uncategorized visibility filters to Big Picture and Mind Map.

**Architecture:** Keep `time_sessions` as the authoritative focus ledger and keep `TimerEngine` as the single timer state owner. Add a shared uncategorized predicate, repository/controller ledger operations, daily squares bound to real session IDs, and conservative timer suspension detection that freezes the last persisted heartbeat instead of reconciling through sleep/close gaps.

**Tech Stack:** Flutter/Dart, sqflite_common / sqflite_common_ffi_web, existing Firestore sync queue, Python repository contract tests, GitHub Actions Flutter web build.

**Spec:** `docs/superpowers/specs/2026-08-24-focus-accuracy-uncategorized-design.md`

## Global Constraints

- Preserve the existing Firestore collections, schema, rules, sync entity names, conflict resolution, and `deleted_at` tombstone semantics.
- Preserve Patreon support and the browser-only `.github/workflows/pages.yml` build -> deploy workflow.
- Do not delete or rewrite Big Picture/Mind Map stored layout rows when Uncategorized items are hidden.
- Daily manual add/remove changes session ledger data only; weekly/monthly/yearly/quarterly goal settings remain unchanged.
- Undoing a focus session must not reverse linked work-item checklist progress.
- Timer interruption policy is conservative: any detected suspension gap freezes the last known elapsed/remaining values and requires explicit Resume.
- Version target: `7.14.0+240`.

---

### Task 1: Shared Uncategorized predicate and canvas filters

**Files:**
- Create: `lib/src/utils/work_item_filters.dart`
- Modify: `lib/src/screens/tasks_screen.dart:148-151`
- Modify: `lib/src/screens/big_picture_screen.dart:21-111,147-176,396-521`
- Modify: `lib/src/screens/mind_map_screen.dart:18-175`
- Test: `tool_tests/test_slamdone_v714_contract.py`

**Interfaces:**
- Produces: `bool isUncategorizedTask(WorkItem item)`.
- Big Picture and Mind Map consume this predicate without mutating `WorkItem` or `CanvasLayout`.

- [ ] **Step 1: Write the failing contract tests**

```python
def test_shared_uncategorized_predicate_is_used_by_all_three_views(self):
    util = self.read('lib/src/utils/work_item_filters.dart')
    tasks = self.read('lib/src/screens/tasks_screen.dart')
    big = self.read('lib/src/screens/big_picture_screen.dart')
    mind = self.read('lib/src/screens/mind_map_screen.dart')
    self.assertIn('bool isUncategorizedTask(WorkItem item)', util)
    self.assertIn('isUncategorizedTask(item)', tasks)
    self.assertIn('isUncategorizedTask(item)', big)
    self.assertIn('isUncategorizedTask(item)', mind)

def test_big_picture_and_mind_map_have_default_on_uncategorized_chips(self):
    big = self.read('lib/src/screens/big_picture_screen.dart')
    mind = self.read('lib/src/screens/mind_map_screen.dart')
    self.assertIn('_showUncategorized = true', big)
    self.assertIn("Text('Uncategorized')", big)
    self.assertIn('_showUncategorized = true', mind)
    self.assertIn("Text('Uncategorized')", mind)
```

- [ ] **Step 2: Run the new contract tests and verify RED**

Run: `python3 -m unittest tool_tests.test_slamdone_v714_contract -v`
Expected: FAIL because the shared utility and new view chips do not exist yet.

- [ ] **Step 3: Add the shared predicate**

```dart
import '../models/models.dart';

bool isUncategorizedTask(WorkItem item) =>
    !item.isDeleted &&
    item.type == WorkItemType.task &&
    item.parentId == null &&
    (item.folder.trim().isEmpty || item.folder == 'Uncategorized');
```

Replace the private Tasks predicate with this function.

- [ ] **Step 4: Add Big Picture visibility state and chip**

Add `bool _showUncategorized = true;`. Compute `uncategorizedCount` from non-deleted work items. Before hierarchy filtering/layout creation, exclude only `isUncategorizedTask(item)` when `_showUncategorized == false`. Add a selected-by-default `FilterChip` beside Active/Completed/Archived on both desktop and mobile controls. The chip changes local view state only.

- [ ] **Step 5: Add Mind Map visibility state and chip**

Add `bool _showUncategorized = true;`. Apply the same predicate before layout creation and `visibleHierarchyItems`. Add a selected-by-default `FilterChip` in the toolbar. Auto-arrange receives the already-filtered item list and does not delete stored layouts.

- [ ] **Step 6: Run the targeted contract test**

Run: `python3 -m unittest tool_tests.test_slamdone_v714_contract -v`
Expected: PASS for the Uncategorized tests.

---

### Task 2: Reversible focus-session ledger operations

**Files:**
- Protect unchanged: `lib/src/models/models.dart`
- Modify: `lib/src/repositories/app_repository.dart:86-99,690-691`
- Modify: `lib/src/controllers/app_controller.dart:557-560,1179-1219`
- Test: `test/models_test.dart`
- Test: `tool_tests/test_slamdone_v714_contract.py`

**Interfaces:**
- Keeps `TimeSession` model byte-for-byte unchanged; tombstone copies are constructed in the repository.
- Produces: `Future<TimeSession> createManualFocusSession({required int minutes, DateTime? now})`.
- Produces: `Future<TimeSession?> softDeleteTimeSession(String id)` and `Future<TimeSession?> restoreTimeSession(String id)`.
- Produces controller getters/actions: `todayFocusSessions`, `addManualFocusSession()`, `removeFocusSession(String id)`, `restoreFocusSession(String id)`.

- [ ] **Step 1: Add failing repository/controller contract tests**

Require the manual marker `slamdone:manual-focus`, UUID creation, repository tombstone copy helper, revision increment, and normal `database.saveTimeSession` enqueue path.

- [ ] **Step 2: Run tests and verify RED**

Run: `python3 -m unittest tool_tests.test_slamdone_v714_contract -v`
Expected: FAIL on missing ledger interfaces.

- [ ] **Step 3: Implement repository manual create**

Create a completed `TimerMode.general` session with `plannedSeconds == elapsedSeconds == minutes * 60`, stable UUID, current timestamp, device ID, and `[slamdone:manual-focus]` note.

- [ ] **Step 4: Implement repository soft-delete and restore without editing models.dart**

Construct a new `TimeSession` from the current row with every original field preserved, revision incremented, current device/timestamp, and `deletedAt` set/cleared. Save via `database.saveTimeSession` so the existing sync queue carries the tombstone.

- [ ] **Step 5: Add controller ledger actions and stable today list**

`todayFocusSessions` filters completed non-stopwatch sessions for the local day and sorts start/end/ID. Add/remove/restore refresh sessions and schedule the normal cloud push.

- [ ] **Step 6: Run targeted contracts and protected hierarchy hash**

Run `python3 -m unittest tool_tests.test_slamdone_v714_contract -v` and the V7.5.2 hierarchy protection test. Both must pass.

---

### Task 3: Today squares bind to exact session records

**Files:**
- Modify: `lib/src/screens/focus_screen.dart:290-412`
- Test: `tool_tests/test_slamdone_v714_contract.py`

**Interfaces:**
- Consumes: `controller.todayFocusSessions`, `addManualFocusSession`, `removeFocusSession`, `restoreFocusSession`.
- Produces: exact-ID reversible day UI; no period-goal mutations.

- [ ] **Step 1: Write failing UI contract tests**

Require `max(controller.dailySessionGoal, todaySessions.length)`, green square access to `session.id`, calls to add/remove/restore controller methods, and Tooltip content using actual `elapsedSeconds`.

- [ ] **Step 2: Run targeted contract test and verify RED**

Run: `python3 -m unittest tool_tests.test_slamdone_v714_contract -v`
Expected: FAIL because the current squares are count-only `AnimatedContainer`s.

- [ ] **Step 3: Replace count-only squares with ledger-bound buttons**

Build `todaySessions = controller.todayFocusSessions`; set `displayCount = max(total, todaySessions.length)`. For occupied indexes, wrap a 25x25 green square in `Tooltip` + `InkWell`, with tooltip showing title/source, local time, and `formatDuration(session.elapsedSeconds)`. For empty indexes, render the same neutral square as tappable manual-add.

- [ ] **Step 4: Implement manual add confirmation/Undo**

On an empty square tap, await `controller.addManualFocusSession()`, then show SnackBar `Logged <N> min manual focus.` with `Undo` calling `removeFocusSession(created.id)`.

- [ ] **Step 5: Implement exact session remove/Undo**

On a green square tap, call `removeFocusSession(session.id)`, then show SnackBar `Removed <actual duration>.` with `Undo` calling `restoreFocusSession(session.id)`. The period goal fields are never changed.

- [ ] **Step 6: Run targeted contracts**

Run: `python3 -m unittest tool_tests.test_slamdone_v714_contract -v`
Expected: PASS for daily ledger UI contracts.

---

### Task 4: Conservative timer sleep/close/suspend safety

**Files:**
- Modify: `lib/src/services/timer_engine.dart:22-128,164-195,258-340`
- Test: `tool_tests/test_slamdone_v714_contract.py`

**Interfaces:**
- Produces: `static const Duration suspensionGapThreshold = Duration(seconds: 5)`.
- Produces internal `_freezeForInterruption(DateTime now)` that does not call `_calculateCurrent`.
- Existing `pause()` remains the explicit short-gap accounting path.

- [ ] **Step 1: Write failing timer safety contracts**

Require the 5-second threshold, initialize-time freeze of persisted `running=true`, pulse gap detection using `_state.updatedAt`, clearing `startedAt/endAt`, `running:false`, `paused:true`, and explicit Pause still calling `_calculateCurrent`.

- [ ] **Step 2: Run contract test and verify RED**

Run: `python3 -m unittest tool_tests.test_slamdone_v714_contract -v`
Expected: FAIL because current initialize/pulse reconcile wall-clock time through suspension.

- [ ] **Step 3: Freeze persisted-running state during initialize/reload**

After `loadTimerState`, if `running && !paused`, copy the persisted elapsed/remaining values unchanged into `running:false`, `paused:true`, `startedAt:null`, `endAt:null`, updated timestamp, persist once, then start ticker. Apply the same conservative rule in `reloadFromDatabase` when remote state represents a stale running timer after reload.

- [ ] **Step 4: Detect long heartbeat gaps in `_pulse`**

Before `_calculateCurrent`, compute `now.difference(_state.updatedAt)`. If greater than five seconds, freeze the current persisted/in-memory values without catch-up, persist, notify, and return. Do not call completion or auto-repeat on that pulse.

- [ ] **Step 5: Preserve explicit Pause behavior**

Keep `pause()` using `_calculateCurrent(_state, now)` before freezing, so a normal button click accounts for legitimate seconds since the last pulse. Resume rebuilds `startedAt/endAt` from the frozen remaining value and never auto-resumes after lifecycle interruption.

- [ ] **Step 6: Run targeted timer contracts**

Run: `python3 -m unittest tool_tests.test_slamdone_v714_contract -v`
Expected: PASS for timer safety contracts.

---

### Task 5: Release/version contracts and full verification

**Files:**
- Modify: `pubspec.yaml:3`
- Modify: `CHANGELOG.md:1`
- Modify: `README.md` release notes section
- Modify: `tool_tests/test_slamdone_v713_contract.py:11-14`
- Final package: `/mnt/data/SlamDone_GitHub_Firebase_V7_14_0_FOCUS_ACCURACY_FULL_SOURCE.zip`

**Interfaces:**
- No runtime interface changes beyond Tasks 1-4.

- [ ] **Step 1: Update release metadata**

Set `version: 7.14.0+240`. Add V7.14 changelog/README notes covering Uncategorized filters, exact day-ledger add/remove, aggregate recalculation, and conservative interrupted timer behavior.

- [ ] **Step 2: Make the historical V7.13 contract accept V7.13.1 or newer**

Replace exact string assertion with a semantic version regex/tuple comparison so a valid V7.14 release does not fail a historical rollback contract. Keep all browser-only/native-companion isolation assertions unchanged.

- [ ] **Step 3: Run complete Python repository contract suite**

Run: `python3 -m unittest discover -s tool_tests -v`
Expected: all active tests PASS; only intentionally retired V7.12 tests are skipped.

- [ ] **Step 4: Run static source checks available in this environment**

Run Python scripts to verify balanced Dart delimiters, no unescaped `$` currency literals introduced in Dart strings, `.github/workflows/pages.yml` contains no `windows-latest`/companion job, Patreon URL/bridge remains present, and ZIP contains `.github/workflows/pages.yml`.

- [ ] **Step 5: Record Flutter verification boundary**

If `flutter` is available, run `flutter test` and `flutter build web --release --base-href /SlamDone/`. If it is unavailable, do not claim compiler success; document GitHub Actions as the final Flutter compiler gate.

- [ ] **Step 6: Package complete source**

Create one full repository ZIP from the validated V7.14 tree, excluding Python cache/temp artifacts while preserving hidden `.github`. Generate SHA-256 and a validation report with exact test counts and environment limitations.

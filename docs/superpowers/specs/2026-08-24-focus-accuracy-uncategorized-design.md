# SlamDone Focus Accuracy + Uncategorized Visibility Design

Date: 2026-08-24
Baseline: SlamDone V7.13.1 Patreon full source

## Goal

Make focus tracking conservative and reversible so SlamDone records only time the user actually intends to count, while adding a simple visibility control for uncategorized root tasks in Big Picture and Mind Map.

This release must preserve the existing Firebase/Firestore data model, existing work-item hierarchy/layout data, Patreon support, and the browser-only GitHub Pages workflow.

## User-approved behavior

1. Big Picture and Mind Map each get an `Uncategorized` visibility chip/button. Uncategorized tasks are visible by default. Turning the chip off hides them from that view without deleting, archiving, moving, or editing them.
2. “Uncategorized task” uses the same definition already used by Tasks: a non-deleted root work item whose `type == task`, `parentId == null`, and whose folder is empty or exactly `Uncategorized`.
3. The main timer and floating timer remain one shared timer state. Pause/Resume from either surface acts on the same persisted timer immediately.
4. PC sleep, app/browser close, shutdown, or a long suspended execution gap must never be counted as focus time. On return/reopen the timer is paused and resumes only when the user explicitly presses Resume.
5. Today’s focus squares become a real session ledger UI:
   - Clicking an empty square creates one completed manual focus session using the current `Min/session` value.
   - Clicking a green square soft-deletes that exact session and therefore removes its exact elapsed time from totals.
   - Timer-created sessions retain their real elapsed time; undoing a 23:39 timer session removes 23:39, not a nominal 25 minutes.
   - Manual sessions are created with elapsed/planned seconds equal to the current daily minutes-per-session setting.
6. Add/remove operations update Today, week, month, quarter, year, rewards/statistics, exports, and synced devices automatically because all aggregate views are derived from the same `time_sessions` ledger.
7. Weekly/monthly/yearly/quarterly goal settings are never edited by checking or unchecking Today’s squares. Only session data changes.
8. Undoing a focus session does not roll back a linked work item’s checklist/task progress; focus history and work-item progress remain separate records.

## Approach options considered

### A. Wall-clock deadlines plus lifecycle flags
Keep `endAt` authoritative and try to catch every sleep/close lifecycle event. This is fragile on web/PWA because shutdown and OS sleep do not guarantee a final lifecycle callback. Rejected as the sole mechanism.

### B. Tick-only timer
Count only periodic timer callbacks. This never counts sleep but can undercount legitimate focus when Chrome throttles background pages. Rejected as the sole mechanism.

### C. Conservative hybrid heartbeat (selected)
Keep the existing deadline-based display for smooth normal operation, but add interruption protection:
- detect an unexpectedly long gap before applying wall-clock catch-up;
- freeze the last known state and mark it paused instead of charging the gap;
- on app initialization, convert any persisted `running=true` state into paused without catch-up;
- explicit user Pause still calculates the short normal interval up to the click.

This gives the requested “never silently count sleep/closed-app time” behavior while preserving accurate normal countdowns and the existing floating-timer architecture.

## Component design

### 1. Shared uncategorized predicate
Create one reusable predicate for uncategorized tasks and use it in Tasks, Big Picture, and Mind Map. This prevents three views from drifting into different definitions.

Big Picture:
- add `_showUncategorized = true` local view state;
- add an `Uncategorized <count>` FilterChip alongside Active / Completed / Archived on desktop and mobile controls;
- exclude matching items before hierarchy/layout visibility is computed.

Mind Map:
- add `_showUncategorized = true` local view state;
- add the same `Uncategorized <count>` FilterChip in the toolbar;
- filter items before automatic layout/visible hierarchy calculation so hidden nodes do not leave active canvas rectangles/connections.

No work-item data is mutated and no layout rows are deleted.

### 2. Timer interruption safety
`TimerEngine` remains the single source of truth.

Add a short suspension-gap threshold and a helper that pauses without applying wall-clock catch-up. On each pulse:
- compute the gap since the last in-memory `updatedAt` heartbeat;
- if the timer is running and the gap exceeds the threshold, freeze the current stored `remainingSeconds` / `elapsedSeconds`, set `running=false`, `paused=true`, clear `startedAt` and `endAt`, persist, and notify;
- otherwise continue the current normal calculation.

On `initialize()` / reload after an app restart:
- if persisted state says `running=true`, do not reconcile to `endAt`;
- convert it to paused at the persisted remaining/elapsed values;
- this makes browser close, PWA close, reboot, or shutdown conservative even when no unload event ran.

Explicit `pause()` continues to calculate the current short interval before freezing so a normal Pause click does not lose legitimate seconds.

Floating timer actions already call the same `TimerEngine`; no second timer engine or native companion is introduced.

### 3. Session ledger operations
Add repository/controller operations for manual create and reversible soft-delete.

Manual add:
- create UUID;
- `mode = general`;
- `title = Manual focus`;
- `plannedSeconds = elapsedSeconds = defaultSessionMinutes * 60`;
- `completed = true`;
- `startedAt`/`endedAt` are placed on the current local day and stored UTC;
- mark notes with a small internal manual-origin marker that is safe in exports;
- save through the existing `time_sessions` table, enqueue sync, refresh controller sessions, and schedule cloud push.

Undo:
- target a specific current-day completed non-stopwatch `TimeSession` by ID;
- write the same row back with `deletedAt=now`, incremented revision, updatedAt/deviceId;
- existing `loadTimeSessions()` already filters tombstones, and sync already carries `deleted_at`, so the deletion propagates to other devices without a schema change.

Do not hard-delete rows. Tombstones are required so Firebase does not resurrect an undone session from another device.

### 4. Today session-square mapping
Replace count-only green boxes with an ordered list of today’s completed non-stopwatch session records.

- Sort today sessions by start/end time ascending for stable left-to-right history.
- Render `max(dailySessionGoal, todaySessions.length)` squares so sessions above the goal are still visible and reversible.
- For index `< todaySessions.length`, render a green clickable square tied to that session ID.
- Tooltip for a green square shows source/title, local time, and actual duration.
- Clicking green asks for no destructive multi-step workflow; it immediately soft-deletes that exact session and gives a SnackBar Undo action that can restore the tombstone if needed.
- Empty goal squares are clickable; clicking creates one manual session using the current daily minutes-per-session setting.
- Manual creation also gives a brief confirmation/Undo SnackBar.

Metrics continue to derive from the controller’s session list, so week/month/year/quarter totals immediately follow the ledger.

### 5. Sync and aggregate consistency
No new Firestore collection or field is required.

Existing `time_sessions` already contains ID, elapsed seconds, completed, revision, device ID, and `deleted_at`; the sync service already includes `time_sessions`. Therefore add/remove operations use the normal sync queue and conflict rules.

All aggregate calculations must continue to ignore stopwatch sessions and tombstoned rows. The controller list is loaded from `deleted_at IS NULL`, so existing aggregate helpers remain compatible.

## Error handling / edge cases

- If manual add is tapped repeatedly, every tap is a separate uniquely identified session.
- If a green session was already removed remotely before local undo, refresh simply leaves it absent; no negative totals are possible.
- If daily goal is reduced below completed-session count, all completed sessions remain visible as green overflow squares so none become impossible to undo.
- If daily goal is increased, new empty squares appear and can be manually logged.
- If the timer is sleeping/suspended when its nominal deadline passes, no completion record or checklist advancement is generated from that suspended interval.
- Auto-repeat never starts another cycle across a detected suspend gap; the interrupted cycle is paused.
- Closing only the floating Picture-in-Picture window does not stop the timer; it is just a surface. Closing/restarting the SlamDone app/PWA causes any persisted running timer to reopen paused.
- Session undo affects focus/reward/statistical totals but intentionally does not reverse work-item checklist progress.

## Tests required before release

### Dart/unit tests
- manual session creation uses exact daily minutes and completed general mode;
- soft-delete session removes it from normal loads and enqueues a tombstone;
- today session selection returns real records in stable order;
- aggregate counts/minutes decrease after delete and increase after manual add;
- persisted-running timer initializes paused without wall-clock catch-up;
- large heartbeat gap pauses without changing elapsed/remaining by the gap;
- normal short pulse and explicit pause still count legitimate seconds;
- auto-repeat does not complete across a suspend gap.

### Widget/contract tests
- Big Picture Uncategorized chip exists, is visible by default, and hides only the existing uncategorized predicate;
- Mind Map has equivalent control;
- Today empty square is tappable and logs a session;
- Today green square targets the exact underlying session and can be undone;
- overflow completed sessions beyond the daily goal remain visible;
- existing Patreon support strings and browser-only Pages workflow remain intact.

### Release verification
- full Python repository contract suite passes;
- full Flutter test suite passes;
- `flutter build web --release --base-href /SlamDone/` passes in GitHub Actions;
- active `.github/workflows/pages.yml` remains browser-only build -> deploy with no Windows companion;
- package the complete source ZIP, not a patch-only ZIP.

## Files expected to change

Primary:
- `lib/src/services/timer_engine.dart`
- `lib/src/controllers/app_controller.dart`
- `lib/src/repositories/app_repository.dart`
- `lib/src/models/models.dart` (only if a safe `TimeSession.copyWith` helper is needed)
- `lib/src/screens/focus_screen.dart`
- `lib/src/screens/big_picture_screen.dart`
- `lib/src/screens/mind_map_screen.dart`
- `lib/src/screens/tasks_screen.dart` or a shared work-item filter utility

Tests:
- targeted Dart tests under `test/`
- targeted contract tests under `tool_tests/`

Explicitly protected unless a test proves a required change:
- Firebase schema/rules
- sync collection names
- Patreon support bridge
- `.github/workflows/pages.yml`
- Big Picture/Mind Map stored layout rows

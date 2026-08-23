# Desktop Pinned Timer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a true desktop always-on-top timer surface for supported Chrome/Edge, reliable soft-chime playback, and optional timer opacity while preserving the single existing timer state.

**Architecture:** Inject a Document Picture-in-Picture JavaScript bridge into the generated web shell, access it through conditional Dart JS interop, and have HomeShell mirror TimerEngine state into that surface. Keep all timer mutations in TimerEngine and use a token-deduplicated web audio helper for completion sound.

**Tech Stack:** Flutter/Dart 3.12+, JavaScript Document Picture-in-Picture API, `dart:js_interop`, GitHub Pages PWA, Python source-contract tests, Node syntax validation.

**Spec:** `docs/superpowers/specs/2026-08-23-desktop-pinned-timer-design.md`

## Global Constraints

- Baseline is SlamDone `7.10.0+200`.
- New release is `7.11.0+210`.
- Preserve the existing in-app timer structure and one shared TimerEngine state.
- Preserve all V7.10 Overview analytics, V7.9 Primary-PC sync, Tasks command center, and desktop spatial core.
- Desktop PiP must be runtime feature-detected and have a safe in-app fallback.
- Opacity range is 25% to 100%, hidden slider by default.
- Use `assets/audio/soft_chime.wav`; do not use `SystemSoundType.alert` for timer completion.
- Do not ship private DB, migration, or backup data.

---

### Task 1: Add V7.11 source contracts

**Files:**
- Create: `tool_tests/test_slamdone_v711_contract.py`

**Interfaces:**
- Consumes: V7.10 source layout.
- Produces: failing contracts for PiP bridge injection, conditional Dart bridge, chime asset use, opacity controls, HomeShell PiP state mirroring, and release version.

- [ ] **Step 1: Write failing tests** asserting:
  - `pubspec.yaml` is `7.11.0+210`.
  - `tools/brand_web.py` injects `documentPictureInPicture`, `slamDoneDesktopTimer`, `soft_chime.wav`, and completion-token dedupe.
  - conditional bridge files exist and use `dart:js_interop` only in the web implementation.
  - HomeShell feature-detects the bridge, listens to TimerEngine, and uses PiP on desktop while preserving fallback.
  - floating timer exposes opacity icon/slider with `.25` minimum.
  - TimerEngine no longer imports/uses `SystemSoundType.alert` and calls the completion-chime helper with a token.
  - PiP actions route to existing TimerEngine methods rather than maintaining a separate timer.

- [ ] **Step 2: Run** `python3 -m unittest tool_tests.test_slamdone_v711_contract -v` and confirm RED because V7.11 files/markers do not exist.

### Task 2: Inject the desktop timer browser bridge

**Files:**
- Modify: `tools/brand_web.py`
- Test: `tool_tests/test_slamdone_v711_contract.py`

**Interfaces:**
- Produces global JS functions under `window.slamDoneDesktopTimer`: `supported`, `open`, `update`, `close`, `isOpen`, `primeChime`, `playChime`.
- Produces callbacks to Dart through `window.slamDoneTimerPipAction` and `window.slamDoneTimerPipClosed`.

- [ ] **Step 1:** Run the focused contract and retain the expected bridge failures.
- [ ] **Step 2:** Inject a readable `<script id="slamdone-desktop-timer-bridge">` before `</body>` from `brand_web.py`.
- [ ] **Step 3:** Implement Document PiP open/setup, responsive timer HTML/CSS, a visible `setInterval` driven by `endAtMs`, action forwarding, token-deduplicated chime playback, color controls, and temporary opacity slider.
- [ ] **Step 4:** Generate a temporary Flutter-style `web/index.html`, run `brand_web.py`, extract the injected script, and validate it with `node --check`.
- [ ] **Step 5:** Run focused tests and confirm the browser-bridge assertions pass.

### Task 3: Add conditional Dart browser and chime bridges

**Files:**
- Create: `lib/src/services/desktop_timer_bridge.dart`
- Create: `lib/src/services/desktop_timer_bridge_stub.dart`
- Create: `lib/src/services/desktop_timer_bridge_web.dart`
- Create: `lib/src/services/timer_completion_chime.dart`
- Create: `lib/src/services/timer_completion_chime_stub.dart`
- Create: `lib/src/services/timer_completion_chime_web.dart`
- Modify: `pubspec.yaml`

**Interfaces:**
- `DesktopTimerBridge({required void Function(String) onAction, required VoidCallback onClosed})`
- `bool get supported`
- `bool get isOpen`
- `Future<bool> open(String snapshotJson)`
- `void update(String snapshotJson)`
- `void close()`
- `void primeChime()`
- `void dispose()`
- `void primeTimerCompletionChime()`
- `Future<void> playTimerCompletionChime(String completionToken)`

- [ ] **Step 1:** Run focused tests and confirm conditional-bridge assertions remain RED.
- [ ] **Step 2:** Add common conditional exports plus non-web no-op implementations.
- [ ] **Step 3:** Add the web implementation using `dart:js_interop` globals supplied by Task 2 and register Dart callbacks with `.toJS`.
- [ ] **Step 4:** Keep JS interop out of the common/stub files so VM tests remain compilable.
- [ ] **Step 5:** Run focused tests and confirm bridge assertions pass.

### Task 4: Make TimerEngine chime reliable and deadline-callable

**Files:**
- Modify: `lib/src/services/timer_engine.dart`
- Test: `tool_tests/test_slamdone_v711_contract.py`

**Interfaces:**
- Produces `Future<void> reconcileNow()` which runs the same protected `_pulse()` calculation immediately.
- Completion calls `playTimerCompletionChime(completedState.completionToken)`.

- [ ] **Step 1:** Run focused test and confirm it fails on `SystemSoundType.alert` / missing token helper.
- [ ] **Step 2:** Remove the SystemSound completion implementation and import the conditional completion-chime helper.
- [ ] **Step 3:** Prime chime from explicit user start/resume actions and call token-deduplicated playback at completion.
- [ ] **Step 4:** Add `reconcileNow()` for the visible PiP deadline callback.
- [ ] **Step 5:** Run focused tests and confirm TimerEngine assertions pass.

### Task 5: Integrate PiP, color, and opacity into HomeShell and existing timer UI

**Files:**
- Modify: `lib/src/screens/home_shell.dart`
- Modify: `lib/src/widgets/floating_timer_overlay.dart`
- Test: `tool_tests/test_slamdone_v711_contract.py`

**Interfaces:**
- HomeShell creates/disposes `DesktopTimerBridge`, subscribes to TimerEngine, serializes timer snapshots, and handles PiP actions.
- Floating timer receives `double opacity`, `int colorIndex`, `ValueChanged<double> onOpacityChanged`, and `ValueChanged<int> onColorChanged`.

- [ ] **Step 1:** Run focused tests and confirm HomeShell/opacity assertions are RED.
- [ ] **Step 2:** Add HomeShell state for bridge-open, color index, and opacity; attach/detach a TimerEngine listener as AppController changes.
- [ ] **Step 3:** Serialize mode/title/timing/progress/endAt/completionToken/autoRepeat/color/opacity into the PiP snapshot and update it on every TimerEngine notification.
- [ ] **Step 4:** On desktop Pin, call the PiP bridge immediately from the user gesture; on success hide only the duplicate in-app card. On unsupported/mobile, retain old pinned behavior.
- [ ] **Step 5:** Route PiP actions to existing TimerEngine methods; `deadline` calls `reconcileNow`, `unpin` closes PiP and restores in-app display, `close` hides the timer.
- [ ] **Step 6:** Add the temporary opacity popover/slider to the Flutter overlay and synchronize color/opacity with PiP without changing timer dimensions.
- [ ] **Step 7:** Run focused V7.11 tests and confirm GREEN.

### Task 6: Version, docs, regression, and packaging

**Files:**
- Modify: `pubspec.yaml`
- Modify: `CHANGELOG.md`
- Modify: `README.md`
- Modify: legacy version-regex tool tests only if they reject 7.11 numerically.

**Interfaces:**
- Produces V7.11 GitHub patch, full source ZIP, and validation report.

- [ ] **Step 1:** Set `version: 7.11.0+210` and document Desktop Pin, fallback limitations, chime, and opacity.
- [ ] **Step 2:** Run `python3 -m unittest discover -s tool_tests -v`; update only stale version guards if needed, then rerun to zero failures.
- [ ] **Step 3:** Run Python `compileall`, Dart delimiter/source scan, `git diff --check` equivalent whitespace scan, workflow-count and private-artifact guards.
- [ ] **Step 4:** Verify protected files from V7.10 are byte-for-byte unchanged where not required by this timer release: hierarchy layout, structured hierarchy, canvas workspace, sync service, tasks screen, overview screen, planner models.
- [ ] **Step 5:** Exercise `brand_web.py` against a generated index fixture and run `node --check` on the exact injected bridge script.
- [ ] **Step 6:** Package a small V7.11 patch and full-source ZIP, re-extract the full ZIP, rerun the full repository suite on the packaged copy, and write `SlamDone_V7_11_0_Validation.txt`.

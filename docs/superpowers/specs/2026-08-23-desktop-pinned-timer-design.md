# SlamDone V7.11 Desktop Pinned Timer Design

**Date:** 2026-08-23
**Baseline:** SlamDone V7.10.0

## Goal

Make the floating timer remain visible above other Windows applications when SlamDone is minimized, while preserving the current timer structure and shared timer state. Add a reliable soft completion chime and an optional temporary opacity control without changing the rest of SlamDone.

## Approved behavior

- On supported desktop Chrome/Edge, pressing the existing Pin control opens the timer in a Document Picture-in-Picture window.
- The PiP timer is always-on-top and remains visible when the main SlamDone PWA/browser window is minimized.
- Closing SlamDone entirely may close the PiP window; the implementation must not claim native-process independence.
- Unsupported browsers and mobile retain the existing in-app pinned timer behavior.
- There is only one timer state. PiP is a second presentation surface, not a second timer engine.
- The current title, analog/digital clock, Start/Pause/Resume, Reset, Stop & log, Stopwatch, color choice, and auto-repeat semantics remain.
- The existing in-app timer remains available when unpinned.
- Opacity is adjustable from 25% to 100%. The slider is hidden by default and is shown only after pressing a small opacity control.
- Opacity affects the timer surface only and does not alter countdown state or layout dimensions.
- Completion plays the existing `assets/audio/soft_chime.wav` rather than `SystemSoundType.alert`.
- Chime playback is deduplicated by completion token so PiP deadline detection and Flutter completion cannot ring twice.
- Timer deadlines continue to derive from the persisted `endAt` timestamp. The PiP surface also calculates its visible countdown from `endAt`, so the display remains accurate when the main page is throttled.

## Architecture

### Browser bridge

`tools/brand_web.py` injects a small `window.slamDoneDesktopTimer` JavaScript bridge into the generated `web/index.html` after `flutter create`. The bridge owns Document Picture-in-Picture capability detection, the PiP HTML/CSS surface, its visible ticker, the soft-chime `Audio` element, opacity rendering, and forwarding PiP control clicks back to Dart.

### Dart bridge

A conditional Dart bridge isolates browser-only JS interop from VM tests/non-web targets:

- `desktop_timer_bridge.dart` selects the web or stub implementation.
- `desktop_timer_bridge_web.dart` uses `dart:js_interop` to call the injected JavaScript bridge and register callbacks.
- `desktop_timer_bridge_stub.dart` reports unsupported and keeps existing in-app behavior.

### HomeShell integration

`HomeShell` owns the presentation state: PiP open/closed, timer color index, and opacity. It listens directly to `TimerEngine` and pushes serialized timer snapshots to the PiP bridge. A successful desktop pin hides the duplicate in-app card while the PiP card is open. Closing/unpinning the PiP card returns the existing in-app timer without stopping or resetting it.

### Completion chime

`TimerEngine` delegates completion sound to a conditional completion-chime helper. On web it calls the injected audio bridge with the current completion token. The browser bridge primes audio from user interactions and deduplicates identical tokens. The stub remains a harmless no-op on non-web targets.

## PiP interaction contract

PiP controls send the following actions to Dart:

- `toggle` — Start / Pause / Resume
- `reset`
- `stop`
- `stopwatch`
- `unpin`
- `close`
- `deadline` — asks TimerEngine to reconcile immediately against `DateTime.now()` when the visible PiP ticker reaches zero
- `color:<index>`
- `opacity:<double>`

The bridge never writes planner data directly. All timer mutations remain inside `TimerEngine`/`AppController`.

## Safety and compatibility

- No changes to Big Picture, hierarchy layout, Firebase sync, Tasks, Overview analytics, migration formats, or planner models.
- No private data is added to GitHub source.
- Document PiP is feature-detected at runtime.
- GitHub Actions remains the final Flutter web compile/build gate because the local execution environment has no Flutter SDK.

# SlamDone Sprint 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the first GitHub/PWA SlamDone upgrade: rebrand, safe child-task auto-archive with Undo, shared archive filters, corrected canvas input, and an in-app floating timer.

**Architecture:** Keep the existing Flutter web + browser SQLite + Firebase architecture. Add interaction policy in `AppController`, shared visibility semantics in models, pointer behavior in canvas widgets, and a HomeShell overlay for the timer.

**Tech Stack:** Flutter 3.44.8, Dart 3.12, sqflite_common_ffi_web, Firebase Auth/Firestore, GitHub Pages Actions, Python unittest source-contract suite.

**Spec:** `docs/superpowers/specs/2026-08-23-slamdone-sprint1-design.md`

## Global Constraints
- No Windows or Android native deployment trees.
- Do not include private migration JSON/database artifacts in the GitHub ZIP.
- Preserve migration format `supeslam-autivra-migration` and browser DB name `supeslam.db`.
- Auto-archive only child tasks, after 4 seconds, with Undo.
- Parent items archive manually only.
- Wheel zoom requires Ctrl; middle mouse pans.
- Floating timer remains inside the PWA.

---

### Task 1: Contract tests and branding
**Files:** create `tool_tests/test_slamdone_sprint1_contract.py`; modify `pubspec.yaml`, `.github/workflows/pages.yml`, `tools/brand_web.py`, app copy/docs.
- [ ] Write failing source-contract assertions for SlamDone package/title/base href and retained legacy migration/database identifiers.
- [ ] Run the new contract test and confirm it fails on SupeSlam branding.
- [ ] Rename visible/package branding and GitHub Pages path while retaining migration/database compatibility identifiers.
- [ ] Run the contract suite.

### Task 2: Delayed auto-archive + Undo
**Files:** modify `lib/src/models/models.dart`, `lib/src/controllers/app_controller.dart`, `lib/src/screens/home_shell.dart`; update contract test.
- [ ] Add failing contract assertions for child-task eligibility, 4-second schedule, archive write, and undo entry point.
- [ ] Implement shared visibility enum/helpers and controller scheduling state.
- [ ] Route completion methods through the scheduler and publish an Undo notice.
- [ ] HomeShell displays the one-shot SnackBar and invokes Undo.
- [ ] Run contract suite.

### Task 3: Big Picture + Mind Map archive filters
**Files:** modify `lib/src/screens/big_picture_screen.dart`, `lib/src/screens/mind_map_screen.dart`; update contract test.
- [ ] Add failing assertions that both screens default to hiding archived and expose state filters.
- [ ] Implement compact state filter controls shared by semantics.
- [ ] Ensure layouts operate on visible/non-deleted source without deleting archived layout records.
- [ ] Run contract suite.

### Task 4: Canvas/NorthStar input rules
**Files:** modify `lib/src/widgets/canvas_workspace.dart`, `lib/src/screens/northstar_screen.dart`; update contract test.
- [ ] Add failing assertions for Ctrl-gated wheel zoom and middle-button pan handlers.
- [ ] Implement pointer listeners and disable accidental InteractiveViewer scroll scaling.
- [ ] Preserve existing touch pan/pinch and on-screen zoom buttons.
- [ ] Run contract suite.

### Task 5: PWA floating timer overlay
**Files:** create `lib/src/widgets/floating_timer_overlay.dart`; modify `lib/src/controllers/app_controller.dart`, `lib/src/screens/home_shell.dart`, `lib/src/screens/focus_screen.dart`; update contract test.
- [ ] Add failing assertions for overlay widget and controller visibility/launch behavior.
- [ ] Implement draggable overlay bound to the existing `TimerEngine`.
- [ ] Add a Focus-screen button and HomeShell Stack integration.
- [ ] Run full Python suite and source hygiene checks.

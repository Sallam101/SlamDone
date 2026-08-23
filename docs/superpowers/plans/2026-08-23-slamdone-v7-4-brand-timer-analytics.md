# SlamDone V7.4 Brand, Timer & Analytics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the reference-matching SlamDone identity, true mini-to-large floating timer, dashboard analytics, GTD restore flow, and advanced table editing without changing migrated planner data.

**Architecture:** Keep all existing persistence/sync contracts intact. Add responsive presentation/controller logic on top of current models, store table display/format preferences through existing UI settings, and derive analytics from existing work items/time sessions rather than introducing new tables.

**Tech Stack:** Flutter web, Dart, browser SQLite/WASM, Firebase Auth + Firestore, GitHub Pages, `excel` 5.0.0 for client-side XLSX decode.

**Spec:** `docs/superpowers/specs/2026-08-23-slamdone-v7-4-brand-timer-analytics-design.md`

## Global Constraints

- Preserve migration wire format and browser database identifier.
- Preserve Firebase schema and stable record IDs.
- Keep Journal V7.3 behavior unchanged.
- PWA base href remains `/SlamDone/`.
- No private migration JSON or database files in repository packages.

---

### Task 1: Reference brand identity

**Files:**
- Modify: `lib/src/widgets/slamdone_brand.dart`
- Modify: `tools/brand_web.py`
- Test: `tool_tests/test_slamdone_v74_contract.py`

- [x] Write a failing contract for the exact slogan, green, speed-check mark and web identity.
- [x] Verify the contract fails on V7.3.
- [x] Implement the Flutter vector mark/wordmark and web SVG/metadata.
- [x] Verify the contract passes.

### Task 2: Responsive floating timer

**Files:**
- Modify: `lib/src/widgets/floating_timer_overlay.dart`
- Modify: `lib/src/screens/home_shell.dart`
- Test: `tool_tests/test_slamdone_v74_contract.py`

- [x] Write a failing contract for mini/max size and responsive timer densities.
- [x] Verify failure on the V7.3 timer.
- [x] Implement mini/compact/regular/spacious timer layouts and larger resize hit target.
- [x] Lower minimum dimensions and increase maximum dimensions in HomeShell.
- [x] Verify the contract passes.

### Task 3: Overview drilldowns and trends

**Files:**
- Modify: `lib/src/screens/overview_screen.dart`
- Test: `tool_tests/test_slamdone_v74_contract.py`

- [x] Write a failing contract for KPI drilldowns, daily trends and project focus.
- [x] Implement clickable KPI detail sheets.
- [x] Implement selectable daily trend line chart with hover feedback.
- [x] Implement workItemId-based focus-by-project/goal aggregation.
- [x] Verify the contract passes.

### Task 4: GTD/PARA restore workflow

**Files:**
- Modify: `lib/src/screens/gtd_para_screen.dart`
- Test: `tool_tests/test_slamdone_v74_contract.py`

- [x] Write a failing contract for explicit Unarchive/Restore actions.
- [x] Add card restore menu wired to the shared AppController.
- [x] Verify the contract passes.

### Task 5: Study Tables advanced editing

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/src/screens/study_tables_screen.dart`
- Test: `tool_tests/test_slamdone_v74_contract.py`

- [x] Write a failing contract for XLSX import, row resize and cell formatting.
- [x] Add `excel: ^5.0.0` and XLSX decode path.
- [x] Add persisted row heights and drag resize controls.
- [x] Add selected-cell bold/background formatting persisted through UI settings.
- [x] Verify the contract passes.

### Task 6: Release validation and packaging

**Files:**
- Modify: `README.md`
- Modify: `CHANGELOG.md`
- Modify: `AUTIVRA4_V6_REQUIREMENTS_MATRIX.md`

- [x] Update release docs and requirement matrix.
- [x] Run all repository contract tests.
- [x] Run source/diff/privacy/package validation.
- [ ] Commit and create V7.4 full + update packages.

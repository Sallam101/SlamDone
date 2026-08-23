# SlamDone V7.3 Daily-Use Upgrade Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete the highest-priority missing SlamDone daily-use UI features while preserving imported Autivra/Firebase data.

**Architecture:** Keep the V7.2.2 local-first SQLite/Firebase architecture unchanged. Add focused UI widgets/state in the existing screens and keep all migration/database compatibility identifiers intact.

**Tech Stack:** Flutter 3.44.8, Material 3, sqflite_common_ffi_web, Firebase Auth/Firestore, GitHub Pages.

**Spec:** `docs/superpowers/specs/2026-08-23-slamdone-v7-3-daily-use-design.md`

## Global Constraints

- Visible product name: `SlamDone`.
- Visible slogan: `Plan • Focus • Finish`.
- Preserve physical database name `supeslam.db` for compatibility.
- Preserve migration format `supeslam-autivra-migration`.
- Plain wheel pans; Ctrl+wheel zooms; middle mouse pans in two axes.
- Parent work items never auto-archive; completed child tasks retain the existing 4-second Undo flow.

---

### Task 1: Brand identity
**Files:** Create `lib/src/widgets/slamdone_brand.dart`; modify `lib/src/screens/home_shell.dart`, `lib/src/screens/settings_screen.dart`, `tools/brand_web.py`.
- [ ] Add failing source-contract assertions for mark, slogan, and hidden legacy database label.
- [ ] Implement branded header/drawer and PWA SVG icon metadata.
- [ ] Run contract tests.

### Task 2: Big Picture compact status toggles
**Files:** Modify `lib/src/screens/big_picture_screen.dart`.
- [ ] Add failing contract assertions for independent Active/Completed/Archived toggles.
- [ ] Replace state dropdown with compact chips; retain collapsible advanced filters.
- [ ] Run contract tests.

### Task 3: Journal period and view controls
**Files:** Modify `lib/src/screens/journal_screen.dart`.
- [ ] Add failing contract assertions for Week/Month/Year/All and Large/Medium/Small/List.
- [ ] Implement period filtering, navigation, and responsive card/list rendering.
- [ ] Run contract tests.

### Task 4: Resizable floating timer
**Files:** Modify `lib/src/screens/home_shell.dart`, `lib/src/widgets/floating_timer_overlay.dart`.
- [ ] Add failing contract assertions for size state and resize callback/handle.
- [ ] Implement bounded resize and adaptive timer content.
- [ ] Run contract tests.

### Task 5: Spatial navigation consistency and mobile drawer
**Files:** Modify `lib/src/widgets/structured_hierarchy_view.dart`, `lib/src/widgets/canvas_workspace.dart`, `lib/src/screens/northstar_screen.dart`, `lib/src/screens/home_shell.dart`.
- [ ] Add failing contract assertions for navigation hint/cursor and explicit mobile hamburger.
- [ ] Implement consistent move cursor/help hint and mobile brand drawer.
- [ ] Run full Python contract suite and `git diff --check`.

# SlamDone V7.5 Refinement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Make the timer clock-first and smoothly resizable/pinnable, use the approved SlamDone icon for browser/PWA surfaces, improve chart hover labels, and make NorthStar cards easier to move/resize.

**Architecture:** Keep the V7.4.1 persistence and Firebase layers unchanged. Implement UI behavior in `floating_timer_overlay.dart`, `home_shell.dart`, `slamdone_brand.dart`, `overview_screen.dart`, and `northstar_screen.dart`; generate exact web icon assets through `tools/brand_web.py`.

**Tech Stack:** Flutter 3.44.8, Dart, GitHub Pages PWA, Python branding build helper.

**Spec:** `docs/superpowers/specs/2026-08-23-v75-timer-brand-northstar-design.md`

## Global Constraints
- Preserve all migration/database/Firebase identifiers.
- Do not put private user data in repository packages.
- Keep `/SlamDone/` GitHub Pages base href.
- Write contract tests before production changes.

---

### Task 1: Timer layout and pin state
**Files:**
- Modify: `lib/src/widgets/floating_timer_overlay.dart`
- Modify: `lib/src/screens/home_shell.dart`
- Test: `tool_tests/test_slamdone_v75_contract.py`

**Interfaces:**
- Consumes: `TimerEngine`, `AppController`, current timer size/offset state.
- Produces: `pinned`, `onPinnedChanged`, edge/corner resize callbacks, compact clock-first layout.

- [x] Add failing contract assertions for thin title-only header, pin/unpin, smaller control sizing, smaller min dimensions, and edge resize affordances.
- [x] Run the V7.5 contract and confirm failure.
- [x] Implement pinned/unpinned state in `HomeShell` and pass it to the overlay.
- [x] Implement thin header, clock-first responsive body, small controls, and edge/corner resize targets.
- [x] Run contract and full repository tests.

### Task 2: Exact icon and adaptive wordmark
**Files:**
- Create: `assets/branding/slamdone_app_icon.png`
- Modify: `lib/src/widgets/slamdone_brand.dart`
- Modify: `lib/src/screens/home_shell.dart`
- Modify: `tools/brand_web.py`
- Modify: `pubspec.yaml`
- Test: `tool_tests/test_slamdone_v75_contract.py`

**Interfaces:**
- Consumes: approved user icon raster and effective background color.
- Produces: exact favicon/PWA icon and `SlamDoneBrand(backgroundColor: ...)` contrast behavior.

- [x] Add failing assertions for PNG icon web copy and brightness-based adaptive `Slam` ink.
- [x] Run contract and confirm failure.
- [x] Add the approved icon asset and web-copy/manifest logic.
- [x] Add effective-background contrast handling to the in-app wordmark and pass AppBar background from `HomeShell`.
- [x] Run contract and full repository tests.

### Task 3: Weekday chart hover labels
**Files:**
- Modify: `lib/src/screens/overview_screen.dart`
- Test: `tool_tests/test_slamdone_v75_contract.py`

**Interfaces:**
- Consumes: `_DailyTrendPoint.day` and current metric label/value.
- Produces: `_trendHoverDate(DateTime)` formatted weekday/date label.

- [x] Add a failing assertion requiring weekday plus date in trend hover copy.
- [x] Run contract and confirm failure.
- [x] Add formatter and use it in hover tooltip.
- [x] Run contract and full repository tests.

### Task 4: NorthStar move/resize affordances
**Files:**
- Modify: `lib/src/screens/northstar_screen.dart`
- Test: `tool_tests/test_slamdone_v75_contract.py`

**Interfaces:**
- Consumes: current canvas scale and `NorthStarNote` geometry.
- Produces: dedicated move grip plus right/bottom/corner resize zones that persist geometry on pointer up.

- [x] Add failing assertions for dedicated move grip and three resize zones.
- [x] Run contract and confirm failure.
- [x] Refactor card manipulation targets while preserving double-click edit and persistence behavior.
- [x] Run contract and full repository tests.

### Task 5: Version, package, and verify
**Files:**
- Modify: `pubspec.yaml`
- Modify: `CHANGELOG.md`
- Test: all `tool_tests`

**Interfaces:**
- Produces: SlamDone V7.5.0 GitHub source and small update patch.

- [x] Bump version to `7.5.0+150` and document the refinement.
- [x] Run `python3 -m unittest discover -s tool_tests -v` and require zero failures.
- [x] Run `git diff --check`.
- [x] Scan ZIP contents for private migration/database files and duplicate workflows.
- [x] Build full and patch ZIPs plus a validation report.

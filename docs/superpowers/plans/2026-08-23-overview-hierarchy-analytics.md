# SlamDone V7.10 Overview Hierarchy Analytics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Week/Month/Quarter/Year Overview analytics with six clickable hierarchy completion KPIs, six hierarchy trend charts, palette colors, and an Excel export while preserving every existing Overview metric.

**Architecture:** Keep calculations local to Overview and add a focused export service for workbook generation. Replace the boolean Week/Month selector with an internal period enum and derive all ranges/targets/navigation from that enum. Add hierarchy aggregation helpers that are pure and testable.

**Tech Stack:** Flutter/Dart, existing WorkItem/TimeSession/Habit models, existing file_picker/archive spreadsheet infrastructure.

**Spec:** `docs/superpowers/specs/2026-08-23-overview-hierarchy-analytics-design.md`

## Global Constraints
- Preserve all existing Overview widgets and analytics.
- Preserve existing palette colors at indexes 0-5.
- Do not modify sync, Big Picture, Tasks, hierarchy layout, or Firebase schema.
- Completion period uses WorkItem.updatedAt for completed/archived live records.
- Excel export uses selected period only.

---

### Task 1: Period model and navigation
**Files:**
- Modify: `lib/src/screens/overview_screen.dart`
- Test: `tool_tests/test_slamdone_v710_contract.py`

**Interfaces:**
- Produces `_OverviewPeriod { week, month, quarter, year }`, period range/label/previous/navigation helpers.

- [ ] Write a failing source contract for four period buttons, quarter/year labels, and period-aware target logic.
- [ ] Run the focused contract and confirm it fails on V7.9.
- [ ] Replace `_monthly` with `_OverviewPeriod _period` and update range/label/navigation/previous-target logic.
- [ ] Run focused contract until green.

### Task 2: Hierarchy completion KPIs and drilldowns
**Files:**
- Modify: `lib/src/screens/overview_screen.dart`
- Test: `tool_tests/test_slamdone_v710_contract.py`

**Interfaces:**
- Produces hierarchy count and matching-item helpers for all six `WorkItemType` values.

- [ ] Add failing contracts for six hierarchy KPI labels and clickable drilldowns.
- [ ] Implement six KPI cards after existing metrics, using palette indexes 6-11.
- [ ] Ensure archived completed items are included and deleted items excluded.
- [ ] Run focused contracts.

### Task 3: Hierarchy completion trend charts
**Files:**
- Modify: `lib/src/screens/overview_screen.dart`
- Test: `tool_tests/test_slamdone_v710_contract.py`

**Interfaces:**
- Produces bucketed hierarchy completion series and six mini charts.

- [ ] Add failing contracts for six trend charts and bucket labels.
- [ ] Implement daily buckets for Week/Month, weekly buckets for Quarter, monthly buckets for Year.
- [ ] Make each mini chart clickable to the same period detail list.
- [ ] Run focused contracts.

### Task 4: Dashboard palettes
**Files:**
- Modify: `lib/src/screens/overview_screen.dart`
- Test: `tool_tests/test_slamdone_v710_contract.py`

**Interfaces:**
- Existing `dashboardPaletteIndex` remains unchanged; palettes expand from 6 to 12 colors.

- [ ] Add failing contract asserting every palette contains 12 colors and original first six values remain.
- [ ] Extend all palettes with six distinct hierarchy colors.
- [ ] Run focused contract.

### Task 5: Overview Excel export
**Files:**
- Create: `lib/src/services/overview_export_service.dart`
- Modify: `lib/src/screens/overview_screen.dart`
- Test: `tool_tests/test_slamdone_v710_contract.py`

**Interfaces:**
- Produces `OverviewExportService.export(...)` accepting period label, summary rows, hierarchy detail rows, hierarchy trend rows, daily trend rows, and project-focus rows.

- [ ] Add failing contract for Export Overview button and multi-sheet export service.
- [ ] Implement a standards-compliant `.xlsx` workbook with sheets Summary, Hierarchy Completed, Hierarchy Trend, Daily Trend, Focus by Project.
- [ ] Wire Export Overview to current period analytics.
- [ ] Run focused contract.

### Task 6: Regression, docs, packaging
**Files:**
- Modify: `CHANGELOG.md`, `README.md`
- Test: full `python3 -m unittest discover -s tool_tests -v`

- [ ] Update version/docs to V7.10.0.
- [ ] Run the complete repository contract suite.
- [ ] Run Dart delimiter/structure scan.
- [ ] Verify protected non-Overview files are unchanged from V7.9.
- [ ] Package small update ZIP and full-source ZIP; re-extract and rerun full tests.

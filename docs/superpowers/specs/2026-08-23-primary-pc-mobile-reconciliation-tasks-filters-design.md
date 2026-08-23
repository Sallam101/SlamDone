# SlamDone V7.9 Primary-PC Reconciliation + Tasks Command Center Design

**Date:** 2026-08-23

## Goal

Make SlamDone reliable as a two-device planner where the main PC is the authoritative planner-structure source and the phone is a safe capture/progress device, while turning Tasks into a fast daily command center.

## Problem being solved

V7.8 diagnostics show SQLite `FOREIGN KEY constraint failed (787)` on phone reconciliation for `work_items`, followed by dependent failures for `canvas_layouts` and `time_sessions`. The phone therefore receives independent tables such as habits/journals but not the work-item hierarchy and dependent focus/layout records.

The current two-way newest-record conflict strategy is also too symmetric for the user's intended workflow. A stale mobile copy must not overwrite planner structure that was curated on the primary PC, but mobile progress and newly captured tasks must still flow back without duplication.

## Reconciliation policy

### Primary PC authority

A device can be explicitly marked **Primary PC** from Settings. The designation is stored in sync metadata and includes the device id. Structural planner fields originating from that device are authoritative during reconciliation.

Primary-PC authority covers:

- work-item title/type/parent hierarchy
- folder/project placement
- due dates
- priorities and energy labels
- planner notes/descriptions
- card layout/geometry/color/font presentation
- Big Picture / Mind Map / NorthStar structural layout settings

A stale phone copy may not overwrite these fields on records that already exist in the PC/cloud master dataset.

### Additive mobile progress

The phone remains writable for progress/capture actions. These are accepted and merged into the master dataset:

- new Quick Tasks / Uncategorized tasks
- task completion status changes
- checklist progress
- habit check-ins / numeric habit entries
- new focus sessions
- new journal entries/versions where IDs are new

Stable record IDs and existing revision/timestamp/device metadata remain in use so repeated reconciliation does not duplicate records.

### Dependency-safe phone restore

Phone reconciliation must write dependent data in safe order:

1. top-level work items
2. work-item descendants in parent-before-child topological order
3. canvas layouts
4. focus/time sessions
5. other independent planner tables

For `work_items`, records whose parent is not yet present are deferred until the parent has been inserted. If no progress can be made, reconciliation reports the orphan IDs instead of attempting inserts that violate SQLite foreign keys.

## Sync diagnostics

Settings continues to show per-table repair diagnostics. Work-item reconciliation reports:

- cloud/local counts
- number inserted/updated/skipped
- number of deferred parent-dependent records
- explicit orphan IDs if any remain
- Primary-PC state and device ID

A sync is only labeled **Verified** when the core planner tables reconcile without errors and local/cloud record counts agree for those tables.

## Tasks command center

Quick Task remains a one-line capture field on desktop and phone. New Quick Tasks are active Tasks with no parent/project and are treated as **Uncategorized** until edited later using the existing full editor.

### Main visibility toggles

Compact independent toggle buttons:

- Active — ON by default
- Uncategorized — OFF by default
- Completed — OFF by default
- Archived — OFF by default

These determine which status/category groups are included in the list.

### Smart filters

Compact independent filter buttons:

- Urgent
- Overdue
- Due Today
- This Week
- Undated

When more than one smart filter is enabled, they combine using **OR**. Search text and hierarchy/level filters continue to narrow the result with **AND** semantics.

### Convenience controls

- **All active** resets status/category visibility to normal active work and clears smart filters.
- **Clear filters** clears smart filters/search-related toggle state without deleting tasks.
- Filter preferences are saved locally per device, so a compact phone view does not force desktop preferences.
- Phone renders the buttons in a compact horizontally scrollable strip instead of a large vertical panel.

## Data-safety constraints

- Do not alter the desktop Structured Big Picture hierarchy renderer, hierarchy layout engine, Free Canvas workspace, or WorkItem serialization format except where sync policy metadata requires separate sync-side logic.
- Do not delete or reset local planner data during repair.
- Do not re-import the original Autivra migration as part of this upgrade.
- Existing Firebase authentication and per-user Firestore paths remain unchanged.
- Existing Autivra4 export remains available.

## Success criteria

1. Phone full repair no longer produces SQLite 787 for parent-dependent work items.
2. A full PC dataset appears on a fresh/empty phone after Verify & repair sync.
3. Primary PC can be explicitly designated and reported in Settings.
4. Existing PC planner structure wins over stale phone structural copies.
5. New phone Quick Tasks sync back once without duplication.
6. Phone task completion/checklist/habit/focus progress is retained and merged.
7. Tasks can isolate Uncategorized quick tasks with one tap.
8. Completed, Archived, Urgent, Overdue, Due Today, This Week, and Undated can be shown/hidden with compact buttons.
9. Desktop Big Picture/card hierarchy behavior remains unchanged.

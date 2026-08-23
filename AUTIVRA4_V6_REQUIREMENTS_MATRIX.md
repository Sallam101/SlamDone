# Autivra4 V6 — Requirements Matrix

This file maps the requested PC-first feature set to the V6 implementation.

| Area | Implemented in V6 |
|---|---|
| Focus To Win | General focus, linked focus, stopwatch, editable minutes, auto-repeat, soft completion chime, daily session boxes, completed/left/minutes/hours counters, week strip, level and due filters, quick-focus icons, separate always-on-top resizable timer window. |
| Big Picture | Structured and free-canvas modes, hierarchy-aware reparenting, sibling ordering, auto-arrange, collapse descendants, independent card resizing, stronger card colors, title sizing/boldness, notes, due/priority/urgent tags, checklist progress, add child, focus, edit, color, and delete controls. |
| Tasks / Do First | Due, overdue, today, week, month, completed, undated and level filters; hierarchy toggles; completed strike-through styling; recurring item cloning; quick focus. |
| Mind Map | Pan/zoom, free node placement, independent resize, stronger colors and text contrast, centered fitted titles, level labels, collapse, edit, focus, and hierarchy connections. |
| Calendar | ISO year-week view by default, week numbers, current week highlight, past/upcoming styling, due-item tooltips, remaining weeks, plus quarter/month/week/day modes. |
| Habits | Unlimited rows, checkbox/number habits, +/- and direct input, weekday + day headers, current-day green, missed-day red, horizontal scrolling, frozen title and total/progress columns. |
| Journal | Renamed Journal, separate daily editor, editable recurring questions, movable/reorderable prompt cards, local-first saving, folders, archive, history snapshots. |
| NorthStar | Colorful movable/resizable notes, multiple pinned notes, font weight, hide/show, folders, checklists, links, and embedded images. |
| Rewards | Editable rank names, thresholds, colors and icons; configurable focus-minute and hierarchy-level point values. |
| GTD + PARA | Drag items between Inbox, To Be Done, In Progress, Completed and Archive; shared records update every other view. |
| Study Tables | Multiple tabbed tables, editable headers/rows/columns, CSV/TSV import, CSV export, archive and delete. |
| Appearance / Tabs | Light/dark/system, accent/background/card/text colors, font family and scale, reset, tab names, colors and order, horizontal tab scrolling. |
| Overview | Weekly/monthly glance with completed items, focus minutes/hours, focus streak, goals hit, and period navigation. |
| Sync / Backup | Immediate local SQLite save; append-only per-record Google Drive desktop-folder sync across PCs; optional Supabase row-level sync for future Android; JSON export/import and V4 migration. |
| Distribution | Windows release build script, portable installer ZIP, local installer script, desktop and Start-menu shortcuts. |

## Intentional PC-first boundary

V6 concentrates on a stable Windows build. The data model and Supabase schema remain cross-platform so the Android client can be added without re-entering records. Google Drive desktop-folder sync is designed for Windows PCs; Supabase is the recommended future phone synchronization path.

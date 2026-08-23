# SlamDone V7.3.0 — Daily-Use Upgrade

- Added a purpose-built SlamDone mark and the visible slogan **Plan • Focus • Finish** in the app header/mobile drawer and PWA metadata.
- Replaced the Big Picture state dropdown with independent **Active / Completed / Archived / All** toggle chips while keeping advanced filters collapsible.
- Added Journal **Week / Month / Year / All** period filtering with previous/next navigation.
- Added Journal **Large / Medium / Small / List** review layouts.
- Made the in-app floating timer resizable with bounded drag-resize behavior and adaptive dial/control layout.
- Added visible spatial-navigation guidance and middle-pan cursor feedback to Structured Big Picture, Free Canvas/Mind Map, and NorthStar.
- Added an explicit mobile hamburger button and branded all-sections drawer.
- Hid the legacy `supeslam.db` filename from product-facing Settings while retaining the internal key for migration/data compatibility.
- Preserved Firebase schema, imported Autivra record IDs, migration wire format, auto-archive Undo policy, and existing cloud sync.

# SlamDone V7.2.2

- GitHub Actions hotfix: remove Flutter's generated `test/widget_test.dart` immediately after `flutter create`.
- Prevents the obsolete template `MyApp()` test from failing CI before the SlamDone web build.
- Added a repository regression contract requiring the cleanup step before `flutter test`.

# Changelog

## 7.2.0 SlamDone Sprint 1 + floating timer

- Rebranded the GitHub/PWA product from SupeSlam to **SlamDone** while preserving the legacy migration wire-format and browser database filename for safe Autivra continuity.
- Added child-task completion policy: nested Tasks auto-archive after a four-second grace period with **Undo**; parent items remain manual-archive only.
- Applied the same auto-archive policy when a linked focus timer completes the final checklist/session step.
- Added shared Big Picture and Mind Map archive visibility filters, with archived items hidden by default and explicit **Unarchive item** actions.
- Added middle-mouse panning and Ctrl+wheel zoom to Structured Big Picture, Free Canvas/Mind Map, and NorthStar; ordinary wheel input pans/scrolls instead of accidentally zooming.
- Improved resized Free Canvas cards with compact priority, status, urgent, energy, due-date, and checklist-progress chips.
- Restored the floating timer as a draggable in-app PWA overlay with analog/digital display, Start/Pause/Resume/Reset, Log & stop, Stopwatch, close, and color selection.
- Kept GitHub source free of personal migration databases and JSON; migration remains a separate private import file.

## 5.0.0 Native rebuild

- Replaced browser HTML/localStorage with Flutter and SQLite.
- Replaced shared whole-file JSON synchronization with optional Supabase record sync.
- Added smooth local Big Picture movement, resizing, snap-to-grid, lock, auto arrange, reordering, and reparenting.
- Added independently synchronized desktop/mobile canvas layouts.
- Added freely movable/resizable Mind Map nodes with live connection lines.
- Added separate daily Brain Dumping editor pages, local autosave, editor conflict lock, snapshots, and restoration.
- Added General Focus without item selection, Linked Focus, Study Stopwatch, hidden timer panel, logged time, and Windows floating timer process.
- Added V4 ID-preserving migration and V5 backup export.

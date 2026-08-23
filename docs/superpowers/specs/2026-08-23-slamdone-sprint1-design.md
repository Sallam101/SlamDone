# SlamDone Sprint 1 Design

## Goal
Turn the recovered SupeSlam GitHub/Firebase PWA branch into SlamDone without returning to native EXE/APK delivery, while preserving the Autivra migration format and user data compatibility.

## Product rules
- Visible product name is **SlamDone**.
- GitHub Pages target is `Sallam101/SlamDone` with base path `/SlamDone/`.
- The existing private Autivra migration JSON remains valid; its legacy `supeslam-autivra-migration` format identifier is retained for compatibility.
- The browser SQLite database name remains `supeslam.db` so an already-created browser database is not silently abandoned.
- A completed **child task** (`type == task` and `parentId != null`) remains visible briefly, shows an undo opportunity, then archives automatically.
- A top-level task or any non-task parent item never auto-archives. Manual archive remains available.
- Undo cancels the scheduled archive and restores the task's pre-completion status, GTD status, and checklist progress using the current revision as the write base.
- Archived items are hidden by default in Big Picture and Mind Map, but filters can show active, completed, archived, or combined states.
- Canvas/NorthStar wheel zoom requires Ctrl. Middle-mouse drag pans on desktop/web. Existing on-screen zoom controls remain.
- Floating timer is a draggable in-app PWA overlay using the existing persisted `TimerEngine`; no native window/process is introduced.

## Architecture
### Auto archive
`AppController` owns delayed auto-archive scheduling because the delay and Undo are interaction behavior. Repository persistence remains unchanged. The controller snapshots the pre-completion task, schedules a 4-second archive, publishes a one-shot notice, and exposes `undoAutoArchive(id)`.

### Filters
A shared `WorkItemVisibilityFilter` enum and predicate live with the work item model. Big Picture and Mind Map use the same semantics so archived visibility is consistent.

### Input behavior
CanvasWorkspace and NorthStar wrap their InteractiveViewer with pointer listeners. Pointer-signal wheel events only adjust scale when Control is pressed. Middle-button drag applies translation to the TransformationController. InteractiveViewer trackpad/wheel scaling is disabled to avoid accidental zoom.

### Floating timer
HomeShell owns a `SlamDoneFloatingTimerOverlay` in a Stack above the selected screen. `launchFloatingTimer()` sets controller overlay visibility instead of attempting native launch. The overlay listens to the existing timer engine and offers start/pause/resume/reset/stop plus drag positioning.

## Testing
- Python source-contract tests run in this environment and are written before production edits.
- Existing 28 repository/migration tests must remain green.
- Flutter tests remain in the GitHub Actions workflow and will verify compilation after push because Flutter is unavailable in this container.

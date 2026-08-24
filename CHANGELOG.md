# V7.14.1 - Current-week, habit navigation, Undo timeout + light timer themes

- 52 Weeks now opens on the current week row for the current ISO year instead of starting at Week 1.
- Habit Month moves the horizontal day scrollbar directly below the day header and automatically positions the current month around today's column on first view/month return.
- Manual focus log/remove Undo snackbars now have a hard five-minute lifetime, including an explicit close timer so they cannot remain indefinitely.
- Floating timer keeps the original eight accent choices and adds eight light full-background choices: White, Soft gray, Cream, Mint, Ice blue, Lavender, Blush, and Pale yellow. The browser Picture-in-Picture timer uses the same 16-choice palette.
- Preserved the V7.14 focus ledger, Firebase schema, Autivra migration format, planner hierarchy, browser-only GitHub Pages deployment, NorthStar, and Rewards data.

# V7.14.0 - Focus accuracy + Uncategorized visibility

- Added selected-by-default **Uncategorized** visibility chips to Big Picture and Mind Map. Hiding them is view-only and does not delete, archive, move, or rewrite stored layouts.
- Today's focus goal squares now represent real completed focus-session records. Empty squares can log a manual session using the current Min/session setting; green squares remove that exact session with Undo.
- Manual add/remove uses the existing `time_sessions` ledger and tombstone sync, so Today/week/month/quarter/year totals, rewards, exports, and other synced devices follow the same corrected history automatically while goal settings remain unchanged.
- Timer interruption handling is conservative: persisted running timers reopen paused, and a suspended heartbeat gap freezes the last known elapsed/remaining values instead of counting PC sleep, shutdown, closed-app time, or a long execution suspension.
- Explicit Pause/Resume from the main or floating timer continues to use the same TimerEngine state; a detected interruption never auto-resumes or auto-repeats.
- Preserved the Firebase schema, hierarchy model, canvas layout data, Patreon support, and browser-only GitHub Pages workflow.

# V7.13.1 - Upload-safe browser timer rollback

- Keeps the V7.13 browser-only Picture-in-Picture timer rollback.
- Makes the rollback safe when GitHub web uploads leave the old V7.12 `windows_timer_companion/` folder behind. Those stale files are inert and are not called by SlamDone.
- Adds `Remove-Old-SlamDone-Timer-Companion.cmd` to stop and remove any V7.12 companion previously installed in Windows startup.
- CI tests now verify runtime isolation from the native companion instead of requiring GitHub to physically delete an old folder during an upload-only patch.

# V7.13.0 — Stable browser-only timer rollback

- Fully removed the V7.12 Windows timer companion, loopback bridge, installer, background startup entry, and Windows CI build.
- Restored the V7.11 browser/PWA floating timer runtime exactly for stability.
- Desktop Pin again uses Chromium Document Picture-in-Picture only.
- Restored the original timer color palette and original optional opacity/fade control.
- Kept the V7.11 bundled soft completion chime.
- No planner, sync, Tasks, Overview, Big Picture, hierarchy, or Firebase data model changes.

# SlamDone V7.12.0

- Added the optional Windows Timer Companion: a borderless, always-on-top native timer with true Windows opacity so apps behind the timer remain visible.
- Consolidated the native timer to one sleek SlamDone header: task title, transparency, theme/background, pin/unpin, and close. Browser PiP fallback no longer duplicates its own close button underneath Chromium's title bar.
- Expanded timer styling from eight accent-only colors to sixteen full themes with background + accent + automatic foreground contrast, including White, Soft gray, Cream, Mint, Ice blue, Lavender, Blush, and Pale yellow.
- Added a hidden-until-needed 20–100% transparency slider to the native timer. The whole native window becomes genuinely translucent; browser PiP fading remains only a fallback.
- Added a loopback-only (`127.0.0.1:37110`) timer bridge. It exchanges timer state/actions only and has no Firestore/planner access.
- The existing GitHub Pages workflow now also builds a self-contained Windows companion ZIP and publishes it under the Pages `downloads` directory.

# SlamDone V7.11.0 — Desktop-Pinned Focus Timer

- Desktop Pin now uses Chromium Document Picture-in-Picture on supported Chrome/Edge desktop so the timer stays always-on-top when the main SlamDone PWA/window is minimized.
- The PiP timer mirrors the existing TimerEngine; it is a second presentation surface, not a second timer or database state.
- Added a browser-visible deadline ticker based on the persisted `endAt` timestamp so the pinned display remains accurate when the main page is background-throttled.
- Replaced the unreliable web `SystemSound` completion alert with the bundled `assets/audio/soft_chime.wav`, deduplicated by completion token.
- Added an optional 25–100% transparency slider to both the in-app floating timer and desktop-pinned timer; the slider is hidden until the opacity button is pressed.
- Timer color, Start/Pause/Resume, Reset, Stop & log, Stopwatch, title, and countdown structure remain available; unsupported browsers/mobile keep the existing in-app pin fallback.
- Closing SlamDone completely may also close the browser-owned PiP window; Desktop Pin is designed to survive minimizing/switching apps, not exiting the PWA process.

# SlamDone V7.10.0 — Overview Hierarchy Analytics + Excel

- Expanded Overview period selection to Week, Month, Quarter, and Year with period-aware navigation and comparisons.
- Added clickable completion KPI cards for Goals, Milestones, Projects, Subprojects, Modules, and Tasks.
- Added six hierarchy completion trend charts with daily, weekly, or monthly buckets depending on the selected period.
- Extended dashboard palettes from six to twelve colors so the new hierarchy analytics follow the existing color selector.
- Added **Export Overview** multi-sheet Excel export for the selected period, including Summary, Hierarchy Completed, Hierarchy Trend, Daily Trend, and Focus by Project.
- Preserved all existing Overview analytics and the V7.9 Primary-PC/Tasks workflow.

# SlamDone V7.9.0 — Primary PC Reconciliation + Tasks Command Center

- Fixed phone restore ordering so `work_items` reconcile parent-before-child and unresolved parent links are reported instead of causing SQLite foreign-key error 787.
- Dependent card layouts and focus sessions now skip unresolved work-item foreign keys during repair instead of crashing the whole table pass.
- Added explicit **Make this my Primary PC** authority. Primary-PC planner structure wins stale mobile structural conflicts while newer phone completion/checklist progress and new stable IDs remain additive.
- Added Primary-PC and work-item repair diagnostics to Settings.
- Rebuilt Tasks around compact independent visibility toggles for Active, Uncategorized, Completed, Archived plus smart OR filters for Urgent, Overdue, Due Today, This Week, and Undated.
- Added **All active** and **Clear filters** shortcuts. Task filter preferences are local to each device and the phone uses a horizontally scrollable compact filter strip.
- Preserved Quick Task capture and the existing full task editor.

# SlamDone V7.8.0 — Verified Repair + Smooth Capture

- Reworked **Verify & repair sync** into an isolated, deterministic repair pass that pauses realtime listeners, reconciles every planner table, re-reads Firestore after writes, and only reports Verified when actual local/cloud counts match.
- Added per-table sync progress and visible repair diagnostics so a failed entity can no longer collapse into an endless generic Pending state.
- Background 15-second queue drains no longer overwrite the last full-repair error/status. One bad queued record no longer blocks unrelated planner tables from syncing.
- Journal autosave no longer rebuilds the whole editor on every keystroke. Status uses a lightweight notifier, saves are debounced to 900 ms, and global UI notification is deferred until editing ends.
- Added **Quick task** capture to Tasks on desktop and phone. Enter a title and press Enter/+ to create an Inbox task labelled `Uncategorized`; the existing detailed Task editor remains unchanged for later editing/categorizing.

# SlamDone V7.6.1 — Mobile Build Hotfix

- Fixed a Flutter compile error in Big Picture mobile mode: the `mobile` viewport flag is now declared inside `build()` where the hierarchy/canvas branches use it.
- Added a regression contract that fails if the mobile viewport flag is moved outside the Big Picture build scope again.
- No Firebase schema, migration format, desktop hierarchy layout, connector, or card-position changes.

# SlamDone V7.6.0 — Mobile Reliability

- Phone changes now schedule a prompt debounced Firestore push instead of relying only on the 15-second timer.
- Returning to SlamDone resumes realtime listeners and reconciles cloud/local state.
- Habits use phone-first daily cards with large checkbox logging and +/- number controls.
- Tasks use a compact phone toolbar and overflow actions so nested task titles/checklists keep usable width.
- Big Picture defaults to a vertical hierarchy on phone, with Canvas optional; desktop Structured/Free Canvas remains unchanged.

# SlamDone V7.5.2

- Big Picture header can now tuck secondary controls while keeping Big Picture, Active, Completed, Archived, and + Goal visible.
- Removed the two instruction lines under Big Picture.
- Structured and Free Canvas card status tags now wrap to additional lines as cards narrow instead of hiding in a horizontal strip.
- Added quick Title smaller / Title larger actions to both Big Picture card types.
- Hierarchy data, automatic layout engine, parent/child model, and controller logic are unchanged.

## 7.5.1 - 2026-08-23
- Big Picture filter controls can now be fully collapsed behind a single Filters button while Structured/Free Canvas and + Goal remain visible.
- Active, Completed, and Archived remain independent status toggles; All is now a one-click show-all shortcut.
- Filter-panel visibility is remembered in SlamDone UI settings.
- Card hierarchy, card renderers, canvas layout, connectors, sizing, and drag behavior are unchanged from V7.5.0.

# SlamDone Changelog

## V7.5.0 — 2026-08-23

- Floating timer is now clock-first with a thin task-title strip, smaller controls, true pin/unpin behavior, smaller minimum size, and right/bottom/corner resize targets.
- Unpinned timers belong to the current planner page and move with vertical page scrolling; pinned timers remain fixed over SlamDone.
- Browser/PWA icon now uses the exact approved S/check icon supplied for SlamDone branding.
- In-app SlamDone wordmark chooses black/white “Slam” ink from the actual surface brightness so theme colors cannot wash it out.
- Overview trend hover labels now include weekday, calendar date, metric name, and value.
- NorthStar notes now have a dedicated move grip and larger right/bottom/corner resize zones with scale-correct pointer movement.

## 7.4.1 - 2026-08-23

- Fixed GitHub Actions dependency resolution by replacing the unpublished `excel ^5.0.0` package reference with published `excel_community ^2.2.1`.
- Updated the XLSX importer to use the maintained web/WASM-compatible community fork while keeping SlamDone's existing `archive 4.x` exports unchanged.

# SlamDone V7.4.0 — Brand, Timer & Analytics Upgrade

- Replaced the generic purple mark with the approved **S/check speed mark**, black/white/green wordmark treatment, and **STOP PLANNING. START FINISHING.** slogan.
- Reworked the PWA icon/metadata to the same black + white + green identity.
- Made the floating timer smoothly resizable from a true mini panel (184×176 desktop / 172×164 mobile) up to 760×840 with mini, compact, regular, and spacious layouts.
- Added clickable Overview KPI drilldowns, daily trend-line charts with hover values, and focus-by-project/goal analytics.
- Added direct **Unarchive** and **Restore to active** actions in GTD/PARA cards.
- Upgraded Study Tables with XLSX import, row-height resizing, and per-cell bold/background-color formatting while retaining CSV/TSV import/export and Excel export.
- Preserved the existing Firebase schema, browser database identifier, Autivra migration wire format, record IDs, and imported progress.

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

## 7.7.0 — Verified Sync Repair + Compact Phone Controls
- Replaced transport-only “synced” messaging with a verified full-table reconciliation audit.
- Full startup/manual/resume reconciliation now uploads missing existing local records even when they are absent from the dirty queue, while preserving revision/timestamp/device conflict rules.
- Fixed Google sign-in busy-gate behavior that could suppress the first full sync while still showing a connected account.
- Realtime entity changes invalidate stale audit counts and trigger a debounced re-verification.
- Added **Verify & repair sync** and local/cloud audit counts in Settings.
- Phone Big Picture, Journal, Do First, NorthStar, and Focus goal controls now default compact/collapsed.
- Added **Export for Autivra4** using the recovered native V6 backup root/entity format and excluding browser/device transport settings; export reconciles cloud first.
- Documented the recovered Autivra4 V6.4.1 importer limitation: it adds missing stable IDs but does not overwrite existing entity IDs without a native importer upgrade.

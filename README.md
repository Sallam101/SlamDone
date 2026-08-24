# SlamDone — GitHub PWA

SlamDone is the GitHub-hosted continuation of Autivra4 V6.4.1. It keeps the planner data model and core screens while moving daily use to one installable web app for PC and Android.

Production URL after Pages is enabled:

`https://Sallam101.github.io/SlamDone/`

## Architecture

- Flutter web/PWA hosted by GitHub Pages.
- Browser-persistent SQLite (WASM + IndexedDB) remains the local-first database.
- Firebase Authentication provides Google sign-in.
- Cloud Firestore synchronizes each signed-in user's planner records across devices.
- Large embedded NorthStar images are split into UID-scoped Firestore chunk documents so no planner document exceeds Firestore's per-document size limit; Firebase Storage is not required for this migration baseline.
- Autivra migration happens from a private migration JSON chosen in the browser; personal migration files are never committed to GitHub.

The planner UI writes to local SQLite first. SlamDone then queues changed records for Firestore. Cloud records merge back into local SQLite using the existing Autivra ordering: higher revision, then newer `client_updated_at`, then device ID as deterministic tie-break.

## SlamDone 7.4 brand, timer and analytics upgrade

- Approved S/check speed-mark identity with **STOP PLANNING. START FINISHING.** across the header, drawer, PWA icon and metadata.
- Floating timer now ranges from a true mini panel to a large workspace panel and reflows controls at four responsive densities.
- Overview KPI cards open detail drilldowns; daily Focus/Tasks/Habits/Goals trend lines show hover values.
- Focus-by-project/goal analytics show where focus time is actually going.
- GTD/PARA cards can explicitly Unarchive or Restore to active without drag gymnastics.
- Study Tables accept XLSX/CSV/TSV imports and add row resizing plus per-cell bold/background formatting.

## SlamDone 7.3 daily-use upgrade

- Big Picture quick status toggles for Active, Completed, Archived, and All.
- Journal period filters (Week/Month/Year/All) and four display densities.
- Consistent spatial navigation guidance: wheel pan, middle-drag 4-way pan, Ctrl+wheel zoom.
- Explicit phone hamburger navigation with every planner section in the drawer.

## SlamDone 7.2 workflow improvements

- Completing a nested **Task** starts a four-second **Undo** grace period, then archives it automatically. Parent goals/projects are never auto-archived.
- Big Picture and Mind Map hide archived items by default and can filter them back in for review/unarchive.
- Structured Big Picture, Free Canvas/Mind Map, and NorthStar support middle-mouse panning and Ctrl+wheel zoom.
- Free Canvas cards preserve compact status/progress chips as cards are resized.
- Focus includes a draggable in-app floating timer overlay, so the PWA does not depend on a Windows EXE.

## Deploy

1. Create the GitHub repository `Sallam101/SlamDone` with `main` as the production branch.
2. Follow [FIREBASE_SETUP.md](FIREBASE_SETUP.md) and add the Firebase web configuration as GitHub **Repository variables**.
3. In GitHub **Settings → Pages**, choose **GitHub Actions** as the source.
4. Push to `main`. `.github/workflows/pages.yml` runs the contract tests, Flutter tests, release web build, and Pages deployment.
5. Open `https://Sallam101.github.io/SlamDone/` and sign in with Google.
6. On Android Chrome, use **Add to Home screen / Install app** if you want the app-like launcher experience.

Required repository variables:

- `FIREBASE_API_KEY`
- `FIREBASE_AUTH_DOMAIN`
- `FIREBASE_PROJECT_ID`
- `FIREBASE_STORAGE_BUCKET`
- `FIREBASE_MESSAGING_SENDER_ID`
- `FIREBASE_APP_ID`
- `FIREBASE_MEASUREMENT_ID` — optional; leave empty if the Firebase web app does not provide one.

Firebase web configuration is client configuration, not an admin credential. Firestore Security Rules are the data-access boundary. Never commit service-account JSON, Admin SDK credentials, private keys, `.db` files, or personal migration JSON.

## One-time Autivra migration

See [MIGRATION_AUTIVRA4.md](MIGRATION_AUTIVRA4.md). The complete migration format includes the normal planner entities plus journal history and timer state that were not present in the old standard Autivra JSON export.

After a successful import, SlamDone records the source checksum so importing the same migration file again is idempotent rather than duplicating records.


## V7.8 repair diagnostics, smoother typing, and quick capture
V7.8 makes **Verify & repair sync** deterministic: realtime listeners pause during the repair, each planner table is reconciled, Firestore is re-read after repair writes, and any failing table is shown in Settings instead of leaving the app in an unexplained Pending state. Ordinary records are uploaded in Firestore batches to make first-time PC publication much faster.

Journal autosave is now typing-first: keystrokes do not rebuild the entire editor, local saves wait for a 900 ms pause, and the rest of the app is notified when editing ends. The Tasks tab also has a **Quick task** field on desktop and phone; pressing Enter or the quick-add button creates an Inbox task with the folder label `Uncategorized`, while the original full Task editor remains available for later organization.

## V7.7 verified cross-device repair
If a device is signed in but shows missing planner data, use **Settings → Verify & repair sync**. V7.7 reconciles every planner entity table in both directions and reports verified local/cloud counts instead of treating a successful Firestore connection as proof that data matches.

For a currently incomplete cloud, open SlamDone on the PC that has the full planner first and run **Verify & repair sync**. After it reports non-zero verified counts, open the phone and run the same action. Realtime listeners then keep normal edits flowing automatically.

### Export back to Autivra4
**Settings → Export for Autivra4** first reconciles SlamDone, then downloads a native Autivra4 V6-shaped JSON with the nine native entity tables and compatible settings while excluding device/Drive/Firebase transport identity. The recovered Autivra4 V6.4.1 importer adds missing IDs but skips existing entity IDs, so use this file as a fresh/full restore or missing-record import unless the native importer is upgraded to merge newer existing IDs.

## V7.9 Primary PC reconciliation and Tasks command center

Designate the computer that contains the curated planner as **Settings → Make this my Primary PC**. During full repair SlamDone restores work items parent-first, then dependent layouts and focus sessions. The Primary PC is authoritative for structural planner fields while phone-created task IDs and newer completion/checklist progress remain additive and deduplicated by stable IDs.

Tasks now includes compact toggles for **Active, Uncategorized, Completed, Archived, Urgent, Overdue, Due Today, This Week, and Undated**. Smart date/priority filters combine with OR semantics; search and hierarchy restrictions continue narrowing results. Filter preferences stay local to each device so the phone can keep a compact daily setup without changing the PC toolbar.


## V7.10 Overview analytics
Overview supports Week / Month / Quarter / Year, six clickable hierarchy completion KPIs and trends, palette colors, and a selected-period Excel export.
## V7.11 desktop-pinned focus timer

On supported desktop Chrome/Edge, pressing **Pin** moves the existing SlamDone floating timer into a browser Document Picture-in-Picture window. That window is always-on-top, so minimizing SlamDone or switching to another study/work application no longer hides the timer. The PiP card mirrors the same TimerEngine state; unpinning returns the same running timer to SlamDone rather than starting a second timer.

The timer now uses the bundled **soft_chime.wav** for completion instead of the unreliable Flutter web system alert. A small opacity button reveals a temporary dimming slider, then hides it again when not needed. Browser PiP cannot provide true see-through Windows transparency. The in-app timer keeps the same title, analog/digital clock, Start/Pause/Resume, Reset, Stop & log, Stopwatch, resize, and color behavior. Unsupported browsers and mobile fall back to the existing in-app pin. Closing the entire SlamDone PWA may close the browser-owned PiP window; the always-on-top guarantee applies while SlamDone remains running/minimized.


## V7.12 Windows companion — retired

The V7.12 native Windows timer companion experiment was removed in V7.13. It is no longer built, required, or contacted by SlamDone.

## V7.13 browser-only pinned timer

V7.13 restores the stable V7.11 floating-timer implementation: Chrome/Edge Document Picture-in-Picture only, the existing soft completion chime, original timer colors, and the original optional opacity/fade control. There is no Windows companion, local loopback server, installer, or background process. True Windows-level see-through transparency is intentionally not provided in this rollback.

## V7.13.1 browser-only timer rollback

V7.13.1 does not require or connect to the retired V7.12 Windows timer companion. Desktop Pin uses the browser Picture-in-Picture timer again. This intentionally restores the V7.11 behavior: browser Picture-in-Picture keeps its browser-owned title bar, and its opacity control is only a visual fade rather than true Windows see-through transparency. No native background process is required. If V7.12's companion was previously installed, run `Remove-Old-SlamDone-Timer-Companion.cmd` once to remove its Windows startup entry and local files. Old companion source files left behind in a GitHub repository by an upload-only update are inert and do not affect SlamDone.


## V7.14.4 Tables + GTD drag corrective fix

V7.14.4 is cumulative over V7.14.3. Tables now use a bounded spreadsheet-style viewport designed for repeated row/column growth, with drag-resizable columns and rows and cell text that reflows inside the resized cell. GTD workflow cards can now be dragged in either direction across Inbox, To Be Done, In Progress, Completed, and Archive; completed checklist state is reconciled with the destination so a restored item does not snap back to Completed. No Firebase or local-database schema changes are introduced.

## V7.14.3 table + journal corrective fix

V7.14.3 is cumulative over V7.14.2. It replaces the Tables editor's fragile nested viewport body with an explicitly bounded two-axis editing canvas so a newly created table can render immediately, then add/edit/delete rows and columns normally. Journal cards now show a direct trash button in addition to the three-dot Delete entry; both use the existing confirmation and synced soft-delete flow. No Firebase or local-database schema changes are introduced.

## V7.14.2 corrective hotfix

V7.14.2 repairs the Journal loading regression, restores clickable checklist habits, stabilizes the Tables editor so new tables can immediately add/edit rows and columns, and gives journal pages a confirmed Delete action in addition to Archive/Restore. Transient action and Undo messages are hard-limited to five seconds. The visible labels are now **Focus** and **Tables** while exact legacy default labels are migrated automatically for existing users. No Firebase or local-database schema changes are introduced.

## V7.14.1 usability patch

- 52 Weeks opens around the current week.
- Habit Month day scrolling is available directly under the day headers and recenters on today when the current month is opened.
- Focus add/remove Undo stays available for five seconds, then closes automatically.
- Floating timer adds eight light background themes while keeping all original color choices and browser Picture-in-Picture behavior.

## V7.14.0 focus accuracy and reversible daily sessions

V7.14 makes focus tracking intentionally conservative. A timer that survives a browser/PC suspension no longer charges the suspended wall-clock gap: on reopen or a detected long heartbeat gap it is paused at the last known elapsed/remaining values and waits for an explicit Resume. Today's focus squares are now backed by actual completed `time_sessions`: click an empty square to log one manual session using the current Min/session value, or click a green square to remove that exact recorded session with Undo. Because week/month/quarter/year analytics are derived from the same ledger, corrections propagate to all totals without changing any period goal settings.

Big Picture and Mind Map also include a selected-by-default **Uncategorized** chip. Turning it off hides root Uncategorized tasks from that view only; no work item or saved canvas layout is modified.

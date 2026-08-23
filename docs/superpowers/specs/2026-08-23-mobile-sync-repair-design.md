# SlamDone V7.7 Mobile Sync Repair Design

## Goal
Make cross-device sync verifiably complete rather than merely connected, make phone control panels compact by default, and add an Autivra4 v6-compatible reverse-export JSON from SlamDone desktop.

## Root cause
The existing Firestore status is transport-oriented: any successful snapshot, including an empty collection, can set the UI to "SlamDone Firestore synced". Local uploads primarily use `sync_queue`; existing browser rows that are not queued are never guaranteed to be uploaded. This can leave Firestore partially populated while both devices report a successful connection.

## Sync design
Manual/startup/resume sync performs a full union reconciliation for every synced entity table. Remote rows are merged locally using existing revision/timestamp/device conflict rules. Then every local row is compared against the remote snapshot; missing or newer local rows are uploaded even if no dirty-queue entry exists. Queue draining remains for fast normal edits. Settings and timer state receive the same reconciliation treatment.

The service records local and cloud-equivalent counts after reconciliation. "Verified sync" is shown only after reconciliation finishes; realtime snapshot callbacks invalidate stale verification and trigger a debounced re-audit rather than claiming full parity on their own. Google sign-in releases its busy gate before the first full reconciliation so authentication cannot silently suppress initial sync. Settings exposes a compact audit with counts and a "Verify & repair sync" action.

## Mobile UI design
On widths under 700 px, large control/filter panels default collapsed. Big Picture uses a compact title row with filter and add controls; Journal, Do First, and NorthStar use compact headers with a Controls/Filters expander. Focus day/week/month goal editors also tuck behind one compact Focus goals row. Existing desktop layouts and hierarchy renderers remain unchanged.

## Autivra4 reverse export
Desktop Settings adds "Export for Autivra4". The JSON uses the native Autivra4 v6 root format: `version: 6`, `application: Autivra4`, `exportedAt`, the same nine entity tables as an Autivra4 backup, and only settings keys known to the recovered native Autivra4 backup format. Device/sync transport settings are excluded so importing the update does not replace the native app's local sync identity/path. Export first performs a full SlamDone reconciliation so the PC file includes newer cloud/phone edits.

Recovered Autivra4 V6.4.1 source confirms its current importer skips entity IDs that already exist. Therefore this JSON is a native-format full/fresh restore backup and can add missing records to an existing Autivra4 database, but overwriting newer versions of already-existing IDs requires a future one-time native importer upgrade. SlamDone must state this limitation rather than promising an overwrite the old importer cannot perform.

## Safety
No Firebase collection or local database schema rename. Stable IDs, revisions, timestamps, soft deletions, and existing conflict semantics are retained. The export is a new explicit action and does not alter SlamDone data.

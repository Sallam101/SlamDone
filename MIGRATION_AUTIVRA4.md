# Autivra4 → SlamDone migration

SlamDone uses a **complete private migration JSON** generated from the final Autivra SQLite database. This is intentionally more complete than the legacy Autivra backup JSON because it can also preserve journal-version history and timer state.

## Data carried forward

The migration format supports:

- work items and hierarchy
- Big Picture / Mind Map canvas layouts
- journal entries
- journal version history
- Focus / General time sessions
- habits and habit history
- NorthStar notes
- reward ranks
- study tables
- compatible app settings
- timer state

Large embedded NorthStar images remain intact. SlamDone removes the base64 image from the main note document during cloud upload, stores it as bounded `northstar_assets/{noteId}/chunks/*` documents under the same UID, and reassembles it into local SQLite on each device.

Stable record IDs, revisions, client timestamps, device metadata, and deletion markers are retained where the source table supplies them.

Device-specific legacy transport settings are deliberately not imported: the old device ID, Google Drive sync folder/mode, and floating-Windows-timer command/heartbeat belong to Autivra's native transport layer. A migrated floating timer is reassigned to SlamDone's main web timer while its timing state is preserved.

## Import steps

1. Keep the private migration JSON (for this release: `Autivra4_to_SlamDone_Migration_2026-08-23.json`) somewhere outside the GitHub repository.
2. Open `https://Sallam101.github.io/SlamDone/`.
3. Sign in with the Google account that should own the SlamDone data.
4. Open **Settings → Migration, saving and backup**.
5. Choose **Import Existing Autivra4 Progress**.
6. Select the complete private migration JSON.
7. SlamDone validates the format, version, source counts, and source checksum before applying it.
8. The import writes to local SQLite first, reloads the planner/controllers, then syncs the imported records into that Firebase user's Firestore namespace.
9. Review Big Picture positions, Focus history, Habits, Journal, NorthStar, Study Tables, Rewards, and Settings before retiring Autivra.

## Duplicate protection

The migration is checksum-aware and stable-ID based. Re-selecting the same migration file does not create a second copy of the planner rows. Existing newer local rows win over older source rows using revision → timestamp → device-ID ordering.

## Privacy

Never upload the migration JSON, original Autivra `.db`, `.db-wal`, or `.db-shm` to the GitHub repository. GitHub stores the application source only; personal planner data belongs in local browser storage and the authenticated Firestore namespace.

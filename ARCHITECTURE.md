# Autivra4 V6 Architecture

Autivra4 is a Flutter Windows application with local-first SQLite storage. The user interface reads and writes local rows immediately; synchronization runs separately so typing, dragging, journaling, and timers are never blocked by the network.

## Layers

- **Models:** hierarchy items, layouts, timer state and sessions, journals, habits, NorthStar notes, rewards, study tables, and tab preferences.
- **Local database:** SQLite/WAL, record revisions, device IDs, soft deletion, and an outgoing sync queue.
- **Repository:** normalization, recurring-task creation, hierarchy reorder/reparent operations, migration, and backups.
- **Sync:** append-only Google Drive desktop-folder records or optional Supabase row-level sync.
- **Controller:** observable application state and device-local appearance/layout settings.
- **UI:** top-row configurable sections, structured and free canvas views, separate journal editor, and a separate always-on-top timer process.

## Duplicate and conflict protection

Each synchronized record has a stable ID, revision, client update time, device ID, and deletion marker. The merge order is revision → timestamp → device ID. Google Drive sync writes immutable per-record versions instead of replacing one whole JSON file.

## Desktop / future Android boundary

V6 is PC-first. Data entities and the Supabase schema remain cross-platform. Desktop canvas coordinates stay device-class-specific so a future phone layout cannot destroy the Windows layout.

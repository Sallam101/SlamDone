# Migrating V4 data into V5 Native

## Before importing

1. Stop editing V4 on other devices.
2. From the V4 device with the most accurate data, create a JSON export.
3. Keep an untouched copy of that export.
4. Test V5 locally before enabling Supabase.

## Import

Open V5 → Settings & Sync → **Import V4 JSON**.

The importer attempts to migrate:

- hierarchy and permanent item IDs
- titles, notes, due dates, priority, completion, timer minutes, and up to 200 checklist units
- Big Picture and Mind Map dimensions/positions when present
- Brain Dumping entries
- completed focus sessions

## Duplicate protection

The importer checks each old permanent ID against the local SQLite database. If the same ID already exists, it skips that record. This makes an accidental second import safe for ID-based V4 exports.

## After importing

1. Review parent-child relationships in Big Picture.
2. Use Auto Arrange once if old coordinates are unsuitable.
3. Review journal dates and recent sessions.
4. Export a V5 backup.
5. Only then configure Supabase and sign into the second device.

## Data the importer cannot infer

If an older V4 export does not contain stable IDs, journal date keys, or hierarchy fields, V5 cannot reconstruct them perfectly. The importer does not invent missing relationships.

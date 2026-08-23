# SlamDone Mobile Reliability Design

## Goal
Make the phone/PWA version reliable for cloud sync, daily habit logging, task use, and Big Picture navigation without changing desktop hierarchy/card behavior or migration/Firebase data formats.

## Scope
- Sync: debounce local writes into prompt Firestore pushes and resync on app resume.
- Habits: phone-first vertical cards with a selected day, large checkbox logging target, and number decrement/increment controls.
- Tasks: compact phone toolbar and compact task actions while preserving desktop controls.
- Big Picture: phone defaults to a vertical hierarchy list; Canvas remains optional; desktop Structured/Free Canvas remains unchanged.

## Constraints
- Keep Firestore collection names, IDs, migration format, SQLite schema, and conflict resolution unchanged.
- Do not change desktop StructuredHierarchyView layout behavior.
- Do not change parent/child relationships, saved canvas layouts, or auto-archive semantics.
- Browser-local saving remains authoritative when offline; cloud pushes resume when Firebase is available.

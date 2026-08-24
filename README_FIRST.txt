SlamDone V7.14.3 — TABLE + JOURNAL CORRECTIVE HOTFIX

This is a cumulative successor to:
SlamDone V7.14.1 Combined Build + 5-Second Hotfix
and includes the V7.14.2 corrective fixes.

Fixed in this release
=====================
1. A newly created table now opens in a bounded two-axis editing canvas instead of falling into
   the layout-recovery screen.
2. New tables start with Topic / Status and one editable blank row. Add row and Add column remain
   immediately available, along with row/column delete and resize controls.
3. The default table title is now "New table" instead of "New study table".
4. Every Journal card now has a directly visible trash button. Delete also remains in the
   three-dot menu. Both ask for confirmation and then use the existing synced soft-delete flow.
5. All V7.14.2 fixes remain included: Journal question-page loading, Habits checklist clicking,
   five-second action/Undo messages, Focus naming, and Tables naming.

Protected / unchanged
=====================
- Firebase/Firestore schema
- local database schema
- migration/import formats
- planner hierarchy and saved layouts
- focus ledger/history
- existing journal/habit/table data
- GitHub Pages base-href workflow
- floating timer themes and browser-only timer behavior

Use the ROOT OVERLAY ZIP for an existing V7.14.1 repository. The ZIP contains lib/, tool_tests/,
and root files directly — there is no extra wrapper folder.

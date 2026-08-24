SlamDone V7.14.2 — CORRECTIVE GITHUB HOTFIX

This is the corrective successor to:
SlamDone V7.14.1 Combined Build + 5-Second Hotfix

Fixed in this release
=====================
1. Journal question pages now rebuild after async loading instead of remaining on the spinner.
2. Journal cards now have Delete (with confirmation) in addition to Archive/Restore.
3. Habit Month reserves a dedicated 16 px strip for its horizontal scrollbar so the scrollbar
   no longer intercepts the first checklist habit row; checkbox completion remains direct.
4. Tables uses a bounded 58 px header instead of the fragile intrinsic-height header, new
   tables start with one blank editable row, and Add row / Add column are explicit.
5. Focus Logged/Removed Undo, child-task completion/archive Undo, and app-bar transient
   status messages have a hard five-second lifetime.
6. Focus To Win is renamed Focus.
7. Study Tables is renamed Tables, including exact legacy default tab labels already saved
   by existing users.

Protected / unchanged
=====================
- Firebase/Firestore schema
- local database schema
- migration/import formats
- planner hierarchy and saved layouts
- focus ledger/history
- existing journal/habit/table data
- GitHub Pages base-href workflow
- floating timer themes and current browser-only timer behavior

See VALIDATION.txt for the verification evidence and UPLOAD_INSTRUCTIONS.txt for deployment.

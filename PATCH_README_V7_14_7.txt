SlamDone V7.14.7 Responsive + Tables Stability ROOT PATCH
Base: SlamDone_GitHub_Firebase_V7_14_6_CORRECTIVE_FULL_SOURCE.zip

HOW TO APPLY
1. Open the root of your SlamDone GitHub repository.
2. Extract this ZIP.
3. Upload the extracted files/folders to the REPOSITORY ROOT, preserving the included paths.
4. Allow GitHub to replace/overwrite files with the same names.
5. Do NOT delete your other repository files.
6. Let the existing GitHub Pages workflow finish, then hard-refresh/reopen the installed PWA.

WHAT THIS PATCH CHANGES
- Tasks: filters wrap onto additional rows at narrow widths and remain visible; filters are shown by default and can be collapsed/expanded.
- Do First: filter panel is collapsed by default; queue priority is urgent+overdue, overdue, urgent+due, due; adds Category/Uncategorized, Energy, Recurrence, and Reset filters; controls wrap responsively.
- Appearance: fresh/default theme is Light with the existing green accent; Settings adds Top bar color (Auto + palette), including installed web/PWA theme-color updating.
- Floating timer: smaller minimum resize and active task name inside the timer circle.
- Tables: serialized Add Row/Add Column mutations, grid-shape normalization, bounded safe canvas width, clipped cell editor content to prevent the layout-recovery path and oversized new-row rendering.

DATA SAFETY
No Firebase rules/schema, SQLite database schema, migration model, repository data model, or sync service changes are included.

VERSION
7.14.7+247

# SlamDone V7.4 Brand, Timer & Analytics Design

## Goal
Continue the deployed GitHub/PWA SlamDone branch without resetting migrated Autivra data. Correct the visual identity to the approved black/white/green S-check speed mark, make the floating timer genuinely small-to-large and smooth to resize, and advance the highest-value remaining backlog items.

## Compatibility constraints
- Keep the existing SQLite browser database identifier unchanged.
- Keep the Autivra/SupeSlam migration wire format unchanged.
- Keep Firebase collection/schema behavior unchanged.
- Keep stable planner record IDs unchanged.
- Do not alter the already-approved V7.3 Journal period/view behavior.

## Branding
Use the approved reference direction: italic speed-style `S`, motion lines, green completion check, `Slam` in neutral ink, `Done` in green. The exact slogan is `STOP PLANNING. START FINISHING.` The green is `#78D12F`; dark branded surfaces use `#090D12`. Apply the identity to the Flutter header/drawer/timer mark and the generated web/PWA SVG/metadata, while retaining user-selectable planner colors elsewhere.

## Floating timer
The timer supports four responsive densities: mini, compact, regular, spacious. The minimum size is 184×176 on desktop and 172×164 on mobile; the maximum build target is 760×840 subject to viewport bounds. Mini mode uses digital time, a progress strip, and icon controls so resizing never clips full-size buttons. A larger bottom-right drag hit area provides smooth resize behavior.

## Overview analytics
KPI cards become clickable drilldowns. Add a daily selectable line chart for focus minutes, completed tasks, habit check-ins, and goals hit, with hover date/value feedback. Add focus-by-project/goal aggregation using each TimeSession `workItemId` and the work-item hierarchy, including most/least focused summaries.

## GTD/PARA
Archived or completed cards expose direct restore actions. Archived cards can `Unarchive`; completed/archived cards can `Restore to active`, updating the shared work item so all views remain consistent.

## Study Tables
Keep CSV/TSV import/export and Excel export, and add XLSX import. Persist column widths, row heights, selected cell formatting, font size, and wrapping through synced UI settings. Cells support bold and background color. Rows expose a vertical drag handle for height resizing.

## Validation
Use repository contract tests first, including new V7.4 source contracts. Run the complete Python contract suite, `git diff --check`, modified-Dart delimiter checks, archive privacy checks, and Git source status. GitHub Actions remains the final Flutter compile/web-build verification because Flutter is not installed in the local execution environment.

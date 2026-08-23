# SlamDone V7.10 Overview Hierarchy Analytics Design

## Goal
Extend the existing Overview without removing or changing its current analytics. Add hierarchy-completion analytics for all six work-item levels (Goal, Milestone, Project, Subproject, Module, Task), expand the dashboard period selector to Week/Month/Quarter/Year, make the new metrics and charts clickable for details, keep palette-based color customization, and export the selected Overview period to Excel.

## Approved behavior
- Existing six KPI cards, completion progress, daily trend, focus-by-project, performance charts, goal comparisons, and current-vs-previous comparisons remain.
- Period selector becomes Week / Month / Quarter / Year and controls the complete Overview page.
- Navigation arrows move one selected period at a time; Today returns to the current period.
- New hierarchy KPI cards appear after the existing KPI cards: Goals completed, Milestones completed, Projects completed, Subprojects completed, Modules completed, Tasks completed.
- A completion belongs to the selected period when the item is live (not deleted), is completed/archived, and its updatedAt timestamp is inside the period. Archived completed items count because archive retains accomplishment history.
- Each hierarchy KPI card is clickable and opens the matching completed items with title, completion date, status, and hierarchy type.
- Add a hierarchy trend section with a separate mini line chart for each of the six levels. Week and Month use daily buckets; Quarter uses weekly buckets; Year uses monthly buckets.
- Each hierarchy trend chart is clickable and opens all completed items for that hierarchy level in the selected period.
- Existing Dashboard Colors control remains the color customization mechanism. Existing six palette colors stay unchanged; each palette gains six additional distinct colors for the new hierarchy analytics.
- Add Export Overview to Excel. Export always uses the currently selected period and includes at least: Summary, Hierarchy Completed, Hierarchy Trend, Existing Daily Trend, Focus by Project/Goal. The workbook contains raw rows behind the clickable hierarchy details so Excel can be used for follow-up analysis.
- Export works on PC/web using the existing save-file mechanism.
- Responsive behavior: KPI cards and mini charts wrap on narrow screens instead of causing page-level horizontal scrolling.

## Period definitions
- Week: ISO week, Monday through Sunday.
- Month: calendar month.
- Quarter: calendar quarter (Jan-Mar, Apr-Jun, Jul-Sep, Oct-Dec).
- Year: calendar year.
- Previous-period comparison uses the immediately previous period of the same type.
- Session targets: Week uses weekly goal; Month uses monthly goal; Quarter uses 3 × monthly goal; Year uses 12 × monthly goal. Minutes/session follows the matching weekly/monthly setting.

## Non-goals / protection
- Do not modify Big Picture hierarchy, Tasks filtering, sync policy, Primary PC reconciliation, card rendering, or Firebase schema.
- Do not remove any existing Overview analytics.

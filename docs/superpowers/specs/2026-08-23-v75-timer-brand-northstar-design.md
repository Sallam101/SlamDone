# SlamDone V7.5 Timer, Brand, Charts, and NorthStar Refinement Design

## Goal
Refine the deployed SlamDone PWA without changing the Autivra migration format, browser database key, Firebase collection structure, or existing user data.

## 1. Floating timer
The floating timer becomes a clock-first utility rather than a branded card. The header is a thin drag strip containing the current task/session title and only utility controls: pin/unpin, timer color, and close. The words “SlamDone Timer” are removed.

The timer has four responsive density states. Mini and compact states use icon-first controls; regular/spacious states use small pill controls. The analog dial and digital time receive the majority of available height. Minimum size is reduced below V7.4 while the maximum remains large. Resizing is available from the right edge, bottom edge, and bottom-right corner with larger hit targets.

Pinned mode remains fixed in the viewport while navigating tabs and scrolling. Unpinned mode remains movable but is logically attached to page content: page scroll deltas move it with the current page instead of keeping it fixed to the viewport.

## 2. Brand and app icon
The browser favicon and PWA/app icon use a raster crop of the exact approved S/check icon supplied by the user, stored in `assets/branding/slamdone_app_icon.png`. The web branding script copies this asset into the generated Flutter web shell and declares it in `manifest.json` and `index.html`.

The in-app wordmark remains vector/text so it can adapt to themes. “Slam” chooses black or white by estimating the brightness of the actual surface behind the logo; “Done” stays SlamDone green. Call sites may pass the effective background color when the logo is on an AppBar or branded surface.

## 3. Overview hover labels
Trend hover text shows weekday, localized calendar date, metric name, and raw value, e.g. `Sun • Aug 23, 2026 • Focus minutes: 42`. The chart itself and data model remain unchanged.

## 4. NorthStar manipulation
NorthStar cards keep edit and drag separate. The header contains a dedicated move grip, while double-clicking the content/title still opens editing. Resize hit targets are expanded to the right edge, bottom edge, and corner. Resizing uses scale-correct pointer deltas and updates the database only when manipulation ends. A selected card receives a visible resize affordance. This reduces accidental edits and makes resizing easier without changing note data.

## Compatibility constraints
- Preserve `supeslam.db` internal browser database key if it exists in source.
- Preserve `supeslam-autivra-migration` migration format/version.
- Preserve Firebase UID-namespaced collections and stable entity IDs.
- Do not add private migration JSON or database files to the GitHub package.
- GitHub Pages remains `/SlamDone/`.

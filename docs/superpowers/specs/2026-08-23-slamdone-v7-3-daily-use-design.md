# SlamDone V7.3 Daily-Use Upgrade Design

## Goal
Finish the missing daily-use experience on the GitHub/PWA branch without changing the existing Firebase schema, migration wire format, or browser database identity that protects already-imported Autivra progress.

## Brand
Visible product identity is **SlamDone** with a purpose-built mark and the compact slogan **Plan • Focus • Finish**. The app header and mobile drawer show the mark, name, and slogan. The PWA manifest uses SlamDone naming and a generated SVG brand icon. Legacy internal identifiers such as `supeslam.db` and `supeslam-autivra-migration` remain only for compatibility and are not presented as the product name.

## Big Picture
Replace the bulky state dropdown with a compact status toggle row. Active, Completed, and Archived are independently toggleable, which naturally supports all combinations. Advanced filters remain collapsible for search, level, priority, descendants, and auto-arrange. Structured Big Picture and Free Canvas both show navigation guidance and support ordinary-wheel pan, middle-mouse 4-way pan, and Ctrl+wheel zoom.

## Journal
Add period filters: Week, Month, Year, All. Add display modes: Large, Medium, Small, List. The filtered period can move backward/forward without changing journal records. Cards remain editable and archiveable, and the current daily-editor workflow is preserved.

## Floating Timer
Keep the existing in-app PWA floating timer but make it resizable from the bottom-right corner. Resize is bounded to usable minimums and the current viewport. Drag and resize work independently. Dial size and controls adapt to the current timer size, with scroll fallback when compact.

## Spatial Navigation
Structured Big Picture, Free Canvas/Mind Map, and NorthStar share the same interaction contract: wheel pans, Ctrl+wheel zooms, middle-mouse drag pans in both axes, and the cursor changes while middle-pan is active. The app must not make plain wheel input an implicit zoom.

## Mobile Navigation
Phone layout has an explicit hamburger button, branded drawer, all app sections in the drawer, and the existing high-frequency bottom destinations. The slogan appears in the drawer brand header.

## Compatibility
Do not rename the physical browser database or the Autivra migration format. Do not modify Firestore document schema for this UI batch. Existing migrated records and cloud sync must continue to load unchanged.

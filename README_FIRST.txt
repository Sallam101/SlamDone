SlamDone V7.14.1 — COMBINED GITHUB BUILD + 5-SECOND UNDO HOTFIX

Purpose
=======
This is one combined upload for the current SlamDone main branch after GitHub Actions run #43.

It contains ONLY the files needed to:
1. Fix the Flutter web compile failure introduced by the Habit Month scrollbar change.
2. Change the Focus Logged/Removed Undo message lifetime from 5 minutes to 5 seconds.
3. Preserve the Flutter $FLUTTER_BASE_HREF placeholder required by the GitHub Pages build.
4. Update the V7.14.1 repository contract test so it guards the corrected behavior.

Root cause fixed
================
V7.14.1 passed `crossAxisMargin` directly to Material `Scrollbar(...)`.
Material Scrollbar does not expose that constructor parameter. The corrected code keeps
Material Scrollbar and applies `crossAxisMargin: _dayHeaderHeight` through a LOCAL
ScrollbarThemeData.copyWith(...) wrapper instead. This preserves the requested visible
horizontal scrollbar directly under the day header without using an invalid constructor argument.

Upload instructions
===================
1. Extract this ZIP.
2. Open the extracted SlamDone_V7_14_1_COMBINED_BUILD_5SEC_HOTFIX folder.
3. Upload the CONTENTS of that folder into the ROOT of your existing SlamDone GitHub repository.
4. Keep the folder paths exactly as shown and replace the four matching files:
   - lib/src/screens/habits_screen.dart
   - lib/src/screens/focus_screen.dart
   - tool_tests/test_slamdone_v7141_usability_patch_contract.py
   - web/index.html
5. Commit once and let GitHub Actions run once.

Do NOT delete Firebase, Firestore, progress, migration, journal, habit, focus, or user data.
This patch changes no database schema and no stored user data.

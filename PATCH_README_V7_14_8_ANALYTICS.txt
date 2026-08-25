SlamDone V7.14.8 — Analytics + V7.14.7 Cumulative Root Overlay
================================================================

WHAT THIS PATCH DOES
- Keeps the V7.14.7 responsive Tasks/Do First, theme/top-bar, timer, Tables fixes.
- Keeps the V7.14.7 GitHub Flutter compile hotfix.
- Adds FlutterFire Firebase Analytics (firebase_analytics 12.5.0).
- Tracks privacy-safe aggregate events only:
  * slamdone_opened
  * section_opened
  * work_item_created
  * work_item_completed
  * habit_checkin
  * focus_started
  * focus_completed
  * cloud_sync_enabled
- Adds Settings > Privacy & analytics > Anonymous usage analytics toggle.
- Analytics preference is browser-local and is never synced to Firestore.

PRIVATE CONTENT IS NOT SENT
No task titles, journal text, NorthStar text, habit names, table contents,
email addresses, Firebase UIDs, record IDs, or other user-authored planner text
are included in SlamDone custom Analytics events.

IMPORTANT GITHUB VARIABLE
Your workflow already reads FIREBASE_MEASUREMENT_ID. In GitHub open:
  SlamDone repository > Settings > Secrets and variables > Actions > Variables
Make sure this repository variable exists:
  Name:  FIREBASE_MEASUREMENT_ID
  Value: G-DNTJ4ZB1N2

This Measurement ID is configuration, not a password/secret.

INSTALL
1. Extract this ZIP.
2. Open your SlamDone GitHub repository.
3. Upload EVERYTHING inside the extracted folder into the repository ROOT.
4. Preserve folder paths and replace/overwrite matching files.
5. Commit the upload. GitHub Actions will run automatically.

VERIFY AFTER DEPLOYMENT
1. Open: https://sallam101.github.io/SlamDone/
2. Use SlamDone for 1-2 minutes: open Tasks, Focus, Habits, etc.
3. Open Google Analytics > Reports > Realtime.
4. You should begin seeing an active user and events after Analytics receives data.
5. Normal non-Realtime reports can take longer to populate.

PRIVACY SWITCH
SlamDone > Settings > Privacy & analytics > Anonymous usage analytics
- ON (default): aggregate usage events are allowed.
- OFF: custom Analytics events stop and Firebase Analytics collection is disabled
  for that browser/device.

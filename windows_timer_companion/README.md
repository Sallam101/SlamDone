# SlamDone Timer Companion

The Windows companion provides the behavior a browser-owned Picture-in-Picture window cannot: a borderless always-on-top timer with real Windows opacity so content behind the timer is visible.

## Install
1. Download and extract `SlamDoneTimerCompanion.zip`.
2. Double-click `Install-SlamDoneTimer.cmd`.
3. Open SlamDone and the floating timer. If the browser asks for loopback/local-network access, allow it for SlamDone.
4. Press **Pin**. SlamDone uses the native companion when it is available and keeps browser Picture-in-Picture as fallback.

The companion installs only for the current Windows user under `%LOCALAPPDATA%\SlamDone\TimerCompanion`; administrator access is not required.

## Privacy
The companion listens only on `127.0.0.1:37110`. It receives timer-only snapshots and does not contain Firebase credentials, Firestore access, journals, goals, habits, or other planner data.

## Uninstall
Run `Uninstall-SlamDoneTimer.cmd` from the downloaded package.

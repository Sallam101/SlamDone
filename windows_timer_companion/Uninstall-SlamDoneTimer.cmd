@echo off
setlocal
set "APPDIR=%LOCALAPPDATA%\SlamDone\TimerCompanion"
taskkill /IM SlamDoneTimerCompanion.exe /F >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "SlamDoneTimerCompanion" /f >nul 2>&1
rmdir /S /Q "%APPDIR%" >nul 2>&1
echo SlamDone Timer Companion removed from this Windows account.
pause

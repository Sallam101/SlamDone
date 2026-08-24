@echo off
setlocal

echo Removing the retired SlamDone V7.12 native timer companion...
taskkill /IM SlamDoneTimerCompanion.exe /F >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "SlamDoneTimerCompanion" /f >nul 2>&1
rmdir /S /Q "%LOCALAPPDATA%\SlamDone\TimerCompanion" >nul 2>&1

echo.
echo The old background timer companion has been removed for this Windows account.
echo SlamDone V7.13.1 uses the browser-only floating timer and does not require a background program.
pause

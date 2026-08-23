@echo off
setlocal
set "APPDIR=%LOCALAPPDATA%\SlamDone\TimerCompanion"
set "EXE=%APPDIR%\SlamDoneTimerCompanion.exe"
if not exist "%APPDIR%" mkdir "%APPDIR%"
taskkill /IM SlamDoneTimerCompanion.exe /F >nul 2>&1
copy /Y "%~dp0SlamDoneTimerCompanion.exe" "%EXE%" >nul
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "SlamDoneTimerCompanion" /t REG_SZ /d "\"%EXE%\" --background" /f >nul
start "" "%EXE%" --background
echo.
echo SlamDone Timer Companion installed for this Windows account.
echo Open SlamDone, open the floating timer, then press Pin.
echo The first connection may ask for permission to access the local companion.
pause

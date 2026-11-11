@echo off
chcp 65001 >nul
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall-Russian.ps1"
set "RC=%ERRORLEVEL%"
echo.
if not "%RC%"=="0" echo Restore failed. Read the error above.
echo Press any key to close this window...
pause >nul
exit /b %RC%

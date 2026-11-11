@echo off
chcp 65001 >nul
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-Russian.ps1"
set "RC=%ERRORLEVEL%"
echo.
if not "%RC%"=="0" echo Installation failed. Read the error above. Do not retry blindly.
echo Press any key to close this window...
pause >nul
exit /b %RC%

@echo off
setlocal EnableExtensions
cd /d "%~dp0"

echo Starting patched ExorcistGame2046 server...
echo.

where powershell.exe >nul 2>nul
if not errorlevel 1 (
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\serve.ps1" -Port 8080
    if not errorlevel 1 goto :eof
)

echo PowerShell server failed. Trying Node.js fallback...
where node.exe >nul 2>nul
if not errorlevel 1 (
    start "" "http://localhost:8080/"
    node.exe "%~dp0scripts\server.mjs"
    goto :eof
)

echo.
echo ERROR: Patched server could not start.
echo Windows PowerShell or Node.js is required.
echo Do not use a plain Python static server for this build: it will not inject the runtime repair.
echo.
pause

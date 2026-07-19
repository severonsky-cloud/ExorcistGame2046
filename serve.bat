@echo off
setlocal EnableExtensions
cd /d "%~dp0"

echo Starting ExorcistGame2046...
echo.

where powershell.exe >nul 2>nul
if not errorlevel 1 (
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\serve.ps1" -Port 8080
    if not errorlevel 1 goto :eof
)

echo PowerShell server failed. Trying Python fallback...
where py.exe >nul 2>nul
if not errorlevel 1 (
    start "" "http://localhost:8080/play.html"
    py.exe -3 -m http.server 8080 --bind 127.0.0.1
    goto :eof
)

where python.exe >nul 2>nul
if not errorlevel 1 (
    start "" "http://localhost:8080/play.html"
    python.exe -m http.server 8080 --bind 127.0.0.1
    goto :eof
)

echo.
echo ERROR: Could not start the local server.
echo Install Python or run npm start if Node.js is installed.
echo.
pause

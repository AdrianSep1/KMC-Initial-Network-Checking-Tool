@echo off
echo Starting Kratos Network Checking Tool...
echo.

:: Set the working directory to the script's location
cd /d "%~dp0"

powershell.exe -ExecutionPolicy Bypass -File "%~dp0Kratos Script.ps1"

echo.
echo Press any key to exit...
pause > nul 
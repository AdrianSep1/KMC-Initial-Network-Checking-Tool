@echo off
echo Starting KMC Network Checking Tool...
echo.

:: Set the working directory to the script's location
cd /d "%~dp0"

powershell.exe -ExecutionPolicy Bypass -File "%~dp0KMC Initial Network Checking Tool.ps1"

echo.
echo Press any key to exit...
pause > nul 
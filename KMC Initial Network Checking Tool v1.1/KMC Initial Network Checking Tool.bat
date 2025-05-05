@echo off
echo Starting KMC Network Checking Tool...
echo.

powershell.exe -ExecutionPolicy Bypass -File "%~dp0KMC Initial Network Checking Tool.ps1"

echo.
echo Press any key to exit...
pause > nul 
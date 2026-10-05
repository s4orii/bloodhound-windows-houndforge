@echo off
chcp 65001 >nul
title HoundForge Installer
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-BloodHoundCE.ps1" -OpenBrowser
if errorlevel 1 (
  echo.
  echo Installation could not be completed. Review the message above.
  pause
  exit /b 1
)
echo.
echo HoundForge installed BloodHound CE successfully.
pause

@echo off
chcp 65001 >nul
title Instalador de BloodHound CE
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-BloodHoundCE.ps1" -OpenBrowser
if errorlevel 1 (
  echo.
  echo La instalacion no pudo completarse. Revise el mensaje anterior.
  pause
  exit /b 1
)
echo.
echo BloodHound CE quedo instalado correctamente.
pause

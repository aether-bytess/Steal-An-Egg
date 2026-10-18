@echo off
title Steal An Egg - Universal Launcher
cd /d "%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0launch_hub.ps1"
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [!] Launcher exited with error code %ERRORLEVEL%.
    pause
)

@echo off
chcp 65001 >nul
title Steal An Egg - Универсальный Лаунчер
cd /d "%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0launch_hub.ps1"
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [!] Лаунчер завершился с кодом ошибки %ERRORLEVEL%.
    pause
)

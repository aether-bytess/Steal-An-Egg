@echo off
title Steal An Egg - Companion Launcher
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0launch_hub.ps1"
pause

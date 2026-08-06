@echo off
rem DeltaForceBooster launcher v0.1 (keep ASCII-only for codepage safety)
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "gui\DeltaForceBooster-GUI.ps1"

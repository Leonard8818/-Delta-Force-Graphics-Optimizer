@echo off
rem DeltaForceBooster fallback launcher v0.2 (keep ASCII-only for codepage safety)
set "DFB_EXE=%~dp0启动优化工具.exe"
cd /d "%SystemRoot%\System32"
start "" "%DFB_EXE%"

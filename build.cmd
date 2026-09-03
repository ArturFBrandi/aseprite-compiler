@echo off
rem Double-clickable entry point: runs build.ps1 next to this file.
rem First run downloads + compiles Aseprite and launches it; later runs just launch it.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build.ps1" %*
if errorlevel 1 pause

@echo off
rem Double-click entry for the Japanese initialization flow.
rem Pass -Shutdown to power off 60s after the app starts.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0init-ja.ps1" %*
if errorlevel 1 pause

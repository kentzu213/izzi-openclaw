@echo off
:: ─────────────────────────────────────────────────────────────
:: Izzi x OpenClaw Connector — Quick Installer (CMD wrapper)
:: Usage: install.bat izzi-YOUR_KEY_HERE
::        install.bat --uninstall
:: ─────────────────────────────────────────────────────────────

:: Handle --uninstall
if /i "%~1"=="--uninstall" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" -Uninstall
    goto :eof
)
if /i "%~1"=="-uninstall" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" -Uninstall
    goto :eof
)

:: Handle no arguments — interactive mode
if "%~1"=="" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
    goto :eof
)

:: Handle API key argument
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" -ApiKey "%~1"

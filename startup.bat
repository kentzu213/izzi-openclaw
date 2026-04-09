@echo off
:: ---------------------------------------------------------------
:: OpenClaw Auto-Start Manager (CMD wrapper)
:: Usage: startup.bat install    - Enable auto-start on Windows boot
::        startup.bat uninstall  - Disable auto-start
::        startup.bat status     - Check auto-start status
:: ---------------------------------------------------------------

chcp 65001 >nul 2>&1

:: Fix ExecutionPolicy first (silent)
powershell -NoProfile -Command "if ((Get-ExecutionPolicy -Scope CurrentUser) -eq 'Restricted' -or (Get-ExecutionPolicy -Scope CurrentUser) -eq 'Undefined') { Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force }" 2>nul

if /i "%~1"=="install" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0startup.ps1" -Install
    goto :eof
)

if /i "%~1"=="uninstall" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0startup.ps1" -Uninstall
    goto :eof
)

if /i "%~1"=="status" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0startup.ps1" -Status
    goto :eof
)

:: Default: show status + usage
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0startup.ps1" -Status
echo.
echo   Usage:
echo     startup.bat install    - Enable auto-start on Windows boot
echo     startup.bat uninstall  - Disable auto-start
echo     startup.bat status     - Check current status
echo.

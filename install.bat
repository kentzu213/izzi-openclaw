@echo off
:: ---------------------------------------------------------------
:: Izzi x OpenClaw Connector - Quick Installer (CMD wrapper)
:: Usage: install.bat izzi-YOUR_KEY_HERE
::        install.bat --uninstall
:: ---------------------------------------------------------------

:: Force UTF-8 codepage
chcp 65001 >nul 2>&1

:: ---------------------------------------------------------------
:: STEP 0: Fix PowerShell Execution Policy (prevents PSSecurityException)
:: This sets RemoteSigned for current user only — safe for local scripts
:: ---------------------------------------------------------------
echo.
echo   [Pre-flight] Checking PowerShell Execution Policy...
powershell -NoProfile -Command "if ((Get-ExecutionPolicy -Scope CurrentUser) -eq 'Restricted' -or (Get-ExecutionPolicy -Scope CurrentUser) -eq 'Undefined') { Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force; Write-Host '    [FIXED] ExecutionPolicy set to RemoteSigned (CurrentUser)' -ForegroundColor Green } else { Write-Host '    [OK] ExecutionPolicy already configured:' (Get-ExecutionPolicy -Scope CurrentUser) -ForegroundColor Green }" 2>nul
echo.

:: Handle --uninstall
if /i "%~1"=="--uninstall" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" -Uninstall
    goto :eof
)
if /i "%~1"=="-uninstall" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" -Uninstall
    goto :eof
)

:: Handle --autostart
if /i "%~1"=="--autostart" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0startup.ps1" -Install
    goto :eof
)

:: Handle no arguments - interactive mode (prompts for key)
if "%~1"=="" (
    echo.
    echo   Izzi x OpenClaw Connector - Installer
    echo   ======================================
    echo.
    echo   Usage: install.bat YOUR_IZZI_API_KEY
    echo   Example: install.bat izzi-abc123def456...
    echo.
    echo   Get your key at: https://izziapi.com/dashboard
    echo.
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
    goto :eof
)

:: Handle API key argument
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" -ApiKey "%~1"

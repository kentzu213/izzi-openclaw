@echo off
:: Izzi x OpenClaw — Auto-Fix Tool (CMD wrapper)
:: Usage: fix.bat [--diagnose] [--auto]

set "ARGS="
if /i "%~1"=="--diagnose" set "ARGS=-Diagnose"
if /i "%~1"=="-diagnose"  set "ARGS=-Diagnose"
if /i "%~1"=="--auto"     set "ARGS=-Auto"
if /i "%~1"=="-auto"      set "ARGS=-Auto"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0fix.ps1" %ARGS%

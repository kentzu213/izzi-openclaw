<#
.SYNOPSIS
    Izzi × OpenClaw — Auto-Fix Tool
.DESCRIPTION
    Scans and fixes ALL known compatibility issues between Izzi API and OpenClaw.
.PARAMETER Auto
    Fix all issues without prompting.
.PARAMETER Diagnose
    Report issues only, no changes.
.EXAMPLE
    .\fix.ps1 -Diagnose
    .\fix.ps1 -Auto
#>

param(
    [switch]$Auto,
    [switch]$Diagnose
)

$ErrorActionPreference = "Continue"
$OC_DIR = Join-Path $env:USERPROFILE ".openclaw"
$Issues = @()
$Fixed = 0

Write-Host ""
Write-Host "  ╔══════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║     🔧 Izzi × OpenClaw Auto-Fix Tool    ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $OC_DIR)) {
    Write-Host "  ❌ OpenClaw not found at $OC_DIR" -ForegroundColor Red
    exit 1
}

# ─── Collect all config files ───

$configFiles = @()
$globalConfig = Join-Path $OC_DIR "openclaw.json"
if (Test-Path $globalConfig) { $configFiles += $globalConfig }

Get-ChildItem (Join-Path $OC_DIR "agents") -Recurse -Filter "models.json" -ErrorAction SilentlyContinue | ForEach-Object {
    $configFiles += $_.FullName
}

Write-Host "  Scanning $($configFiles.Count) config file(s)..." -ForegroundColor Gray
Write-Host ""

# ─── Issue 1: Double /v1 prefix in baseUrl ───

Write-Host "  [1/5] Checking for /v1 suffix in baseUrl..." -ForegroundColor White

foreach ($f in $configFiles) {
    $content = Get-Content $f -Raw
    if ($content -match '"baseUrl":\s*"[^"]+/v1"') {
        $shortName = $f.Replace($OC_DIR, "~\.openclaw")
        $Issues += @{ ID = 1; File = $f; Desc = "baseUrl has /v1 suffix in $shortName" }
        Write-Host "    ⚠ FOUND: /v1 suffix in $shortName" -ForegroundColor Yellow

        if (-not $Diagnose) {
            $ts = Get-Date -Format "yyyyMMddHHmmss"
            Copy-Item $f "$f.bak.$ts" -Force
            $fixed = $content -replace '("baseUrl":\s*"[^"]+)/v1"', '$1"'
            $fixed | Set-Content $f -Encoding utf8 -NoNewline
            Write-Host "    ✓ FIXED: removed /v1 suffix" -ForegroundColor Green
            $Fixed++
        }
    }
}

if ($Issues.Count -eq 0) { Write-Host "    ✓ No /v1 suffix issues" -ForegroundColor Green }

# ─── Issue 2: Production URL when localhost expected (or vice versa) ───

Write-Host "  [2/5] Checking baseUrl consistency..." -ForegroundColor White

$baseUrls = @()
foreach ($f in $configFiles) {
    $content = Get-Content $f -Raw
    if ($content -match '"izzi":\s*\{[^}]*?"baseUrl":\s*"([^"]*)"') {
        $baseUrls += @{ File = $f; Url = $Matches[1] }
    }
}

$uniqueUrls = $baseUrls | ForEach-Object { $_.Url } | Sort-Object -Unique
if ($uniqueUrls.Count -gt 1) {
    Write-Host "    ⚠ MISMATCH: Multiple baseUrls found:" -ForegroundColor Yellow
    foreach ($u in $baseUrls) {
        $shortName = $u.File.Replace($OC_DIR, "~\.openclaw")
        Write-Host "      $shortName → $($u.Url)" -ForegroundColor Gray
    }
    $Issues += @{ ID = 2; Desc = "Multiple baseUrl values across config files" }

    if (-not $Diagnose -and ($Auto -or (Read-Host "    Sync all to $($baseUrls[0].Url)? [y/N]") -eq "y")) {
        $targetUrl = $baseUrls[0].Url
        foreach ($f in $configFiles) {
            $content = Get-Content $f -Raw
            $content = $content -replace '("izzi":\s*\{[^}]*?"baseUrl":\s*")[^"]*"', "`${1}$targetUrl`""
            $content | Set-Content $f -Encoding utf8 -NoNewline
        }
        Write-Host "    ✓ FIXED: All configs synced to $targetUrl" -ForegroundColor Green
        $Fixed++
    }
} else {
    Write-Host "    ✓ All configs use same baseUrl" -ForegroundColor Green
}

# ─── Issue 3: Stale model names ───

Write-Host "  [3/5] Checking for stale upstream model names..." -ForegroundColor White

$staleModels = @(
    @{ Old = "deepseek/deepseek-r1:free"; New = "qwen/qwen3.6-plus:free" }
    @{ Old = "deepseek/deepseek-chat-v3-0324:free"; New = "qwen/qwen3.6-plus:free" }
    @{ Old = "mistralai/mistral-small-3.1-24b-instruct:free"; New = "google/gemma-3-27b-it:free" }
    @{ Old = "qwen/qwen3-4b:free"; New = "google/gemma-3-4b-it:free" }
)

# Check backend router.ts
$routerPath = "f:\Ai Tools\Web bán APIs\izzi-backend\src\services\router.ts"
if (Test-Path $routerPath) {
    $routerContent = Get-Content $routerPath -Raw
    foreach ($m in $staleModels) {
        if ($routerContent -match [regex]::Escape($m.Old)) {
            $Issues += @{ ID = 3; Desc = "Stale model: $($m.Old) → $($m.New)" }
            Write-Host "    ⚠ FOUND: $($m.Old)" -ForegroundColor Yellow

            if (-not $Diagnose) {
                $routerContent = $routerContent -replace [regex]::Escape($m.Old), $m.New
                $Fixed++
            }
        }
    }
    if (-not $Diagnose -and $Fixed -gt 0) {
        $routerContent | Set-Content $routerPath -Encoding utf8 -NoNewline
        Write-Host "    ✓ FIXED: Updated stale model mappings" -ForegroundColor Green
    }
} else {
    Write-Host "    · Backend router not found at default path (OK for client-only)" -ForegroundColor Gray
}

# ─── Issue 4: Missing izzi provider ───

Write-Host "  [4/5] Checking izzi provider presence..." -ForegroundColor White

foreach ($f in $configFiles) {
    $content = Get-Content $f -Raw
    if ($content -notmatch '"izzi"') {
        $shortName = $f.Replace($OC_DIR, "~\.openclaw")
        $Issues += @{ ID = 4; File = $f; Desc = "izzi provider missing in $shortName" }
        Write-Host "    ⚠ MISSING: izzi provider in $shortName" -ForegroundColor Yellow
        Write-Host "      Run: .\install.ps1 -ApiKey YOUR_KEY" -ForegroundColor Gray
    }
}

if (-not ($Issues | Where-Object { $_.ID -eq 4 })) {
    Write-Host "    ✓ izzi provider present in all configs" -ForegroundColor Green
}

# ─── Issue 5: Gateway running old config ───

Write-Host "  [5/5] Checking gateway status..." -ForegroundColor White

try {
    $gatewayProc = Get-Process -Name "openclaw*" -ErrorAction SilentlyContinue
    if ($gatewayProc) {
        $uptime = (Get-Date) - $gatewayProc[0].StartTime
        if ($uptime.TotalHours -gt 24) {
            $Issues += @{ ID = 5; Desc = "Gateway running for $([math]::Round($uptime.TotalHours, 1))h — may have stale config" }
            Write-Host "    ⚠ Gateway running $([math]::Round($uptime.TotalHours, 1))h — consider restart" -ForegroundColor Yellow
        } else {
            Write-Host "    ✓ Gateway uptime OK ($([math]::Round($uptime.TotalMinutes))m)" -ForegroundColor Green
        }
    } else {
        Write-Host "    · Gateway not detected as running process" -ForegroundColor Gray
    }
} catch {
    Write-Host "    · Could not check gateway status" -ForegroundColor Gray
}

# ─── Report ───

Write-Host ""
Write-Host "  ════════════════════════════════════════════" -ForegroundColor Cyan

if ($Issues.Count -eq 0) {
    Write-Host "  ✅ No issues found! Everything looks good." -ForegroundColor Green
} elseif ($Diagnose) {
    Write-Host "  📋 Found $($Issues.Count) issue(s) — run without -Diagnose to fix" -ForegroundColor Yellow
    Write-Host ""
    foreach ($i in $Issues) {
        Write-Host "    [$($i.ID)] $($i.Desc)" -ForegroundColor Yellow
    }
} else {
    Write-Host "  🔧 Fixed $Fixed of $($Issues.Count) issue(s)" -ForegroundColor Green
}

Write-Host ""

<#
.SYNOPSIS
    Izzi x OpenClaw Connector - Windows Installer
.DESCRIPTION
    Connects your Izzi API key to OpenClaw so all agents can use Izzi models.
    Applies known compatibility fixes automatically.
    Model configs are fetched securely from the Izzi API server.
.PARAMETER ApiKey
    Your Izzi API key (starts with "izzi-"). Get one at https://izziapi.com/dashboard
.PARAMETER BaseUrl
    API base URL. Default: https://api.izziapi.com
.PARAMETER Uninstall
    Remove Izzi provider from OpenClaw config.
.EXAMPLE
    .\install.ps1 -ApiKey "izzi-abc123..."
.LINK
    https://github.com/kentzu213/izzi-openclaw
.NOTES
    Licensed under BSL-1.1. Copyright (c) 2026 izziapi.com
#>

param(
    [string]$ApiKey = "",
    [string]$BaseUrl = "https://api.izziapi.com",
    [switch]$Uninstall,
    [switch]$SkipRestart
)

$ErrorActionPreference = "Stop"
$Version = "3.0.0"
$OC_DIR = Join-Path $env:USERPROFILE ".openclaw"
$OC_CONFIG = Join-Path $OC_DIR "openclaw.json"

# --- Helpers ---

function Write-Banner {
    Write-Host ""
    Write-Host "  ============================================" -ForegroundColor Cyan
    Write-Host "       Izzi x OpenClaw Connector v$Version" -ForegroundColor Cyan
    Write-Host "  ============================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step {
    param([int]$N, [int]$Total, [string]$Msg)
    Write-Host "  [$N/$Total] $Msg" -ForegroundColor White
}

function Write-Ok {
    param([string]$Msg)
    Write-Host "    [OK] $Msg" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Msg)
    Write-Host "    [WARN] $Msg" -ForegroundColor Yellow
}

function Write-Err {
    param([string]$Msg)
    Write-Host "    [FAIL] $Msg" -ForegroundColor Red
}

function Backup-File {
    param([string]$Path)
    if (Test-Path $Path) {
        $ts = Get-Date -Format "yyyyMMddHHmmss"
        Copy-Item $Path "$Path.bak.$ts" -Force
    }
}

# --- Pre-flight checks ---

Write-Banner

# --- Step 0: Fix ExecutionPolicy (prevents PSSecurityException) ---

try {
    $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
    if ($currentPolicy -eq 'Restricted' -or $currentPolicy -eq 'Undefined') {
        Write-Host "  [FIX] PowerShell ExecutionPolicy is '$currentPolicy' - fixing..." -ForegroundColor Yellow
        Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Write-Host "  [OK] ExecutionPolicy set to RemoteSigned (CurrentUser)" -ForegroundColor Green
        Write-Host "        OpenClaw commands will now work in any PowerShell window." -ForegroundColor Gray
        Write-Host ""
    }
} catch {
    Write-Host "  [WARN] Could not auto-fix ExecutionPolicy. Run manually:" -ForegroundColor Yellow
    Write-Host "         Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force" -ForegroundColor Gray
    Write-Host ""
}

if (-not (Test-Path $OC_DIR)) {
    Write-Host "  [FAIL] OpenClaw not found at $OC_DIR" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Install OpenClaw first:" -ForegroundColor Yellow
    Write-Host "    npm install -g openclaw" -ForegroundColor Gray
    Write-Host "    openclaw setup" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Then run this script again." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

Write-Host "  [OK] OpenClaw found at $OC_DIR" -ForegroundColor Green
Write-Host ""

# --- Uninstall mode ---

if ($Uninstall) {
    Write-Host "  ============================================" -ForegroundColor Yellow
    Write-Host "       Izzi Provider Uninstaller" -ForegroundColor Yellow
    Write-Host "  ============================================" -ForegroundColor Yellow
    Write-Host ""

    $step = 1
    $total = 3

    # Step 1: Remove from openclaw.json
    Write-Step $step $total "Cleaning openclaw.json..."
    if (Test-Path $OC_CONFIG) {
        Backup-File $OC_CONFIG
        $config = Get-Content $OC_CONFIG -Raw | ConvertFrom-Json
        if ($config.models.providers.PSObject.Properties["izzi"]) {
            $config.models.providers.PSObject.Properties.Remove("izzi")
            $config | ConvertTo-Json -Depth 20 | Set-Content $OC_CONFIG -Encoding utf8
            Write-Ok "Removed izzi provider from openclaw.json"
        }
        else {
            Write-Ok "No izzi provider found (already clean)"
        }
    }
    $step++

    # Step 2: Remove from agent configs
    Write-Step $step $total "Cleaning agent configs..."
    $agentDirs = Get-ChildItem (Join-Path $OC_DIR "agents") -Directory -ErrorAction SilentlyContinue
    foreach ($agent in $agentDirs) {
        $modelsFile = Join-Path $agent.FullName "agent\models.json"
        if (Test-Path $modelsFile) {
            Backup-File $modelsFile
            $models = Get-Content $modelsFile -Raw | ConvertFrom-Json
            if ($models.providers.PSObject.Properties["izzi"]) {
                $models.providers.PSObject.Properties.Remove("izzi")
                $models | ConvertTo-Json -Depth 20 | Set-Content $modelsFile -Encoding utf8
                Write-Ok "Cleaned $($agent.Name)/agent/models.json"
            }
        }
    }
    $step++

    # Step 3: Restart gateway
    Write-Step $step $total "Restarting gateway..."
    try {
        openclaw gateway restart 2>$null
    }
    catch { }
    Write-Ok "Gateway restart triggered"

    Write-Host ""
    Write-Host "  [DONE] Izzi provider removed from OpenClaw!" -ForegroundColor Green
    Write-Host ""
    exit 0
}

# --- Install mode ---

# Get API key
if (-not $ApiKey) {
    $ApiKey = Read-Host "  Enter your Izzi API key"
    if (-not $ApiKey) {
        Write-Host ""
        Write-Err "No API key provided."
        Write-Host "  Get your key at: https://izziapi.com/dashboard" -ForegroundColor Gray
        Write-Host ""
        exit 1
    }
}

# ======================================================
# SECURITY GATE: Mandatory API Key Validation
# See SECURITY-RULES.md — Rules #1, #2
# This block MUST NOT be removed or made optional.
# ======================================================

# Check 1: Reject placeholder
if ($ApiKey -eq "YOUR_IZZI_API_KEY") {
    Write-Err "Invalid placeholder key. Get a real key at: https://izziapi.com/dashboard"
    exit 1
}

# Check 2: Format — must start with izzi-
if (-not $ApiKey.StartsWith("izzi-")) {
    Write-Err "API key must start with 'izzi-'. Get your key at: https://izziapi.com/dashboard"
    exit 1
}

# Check 3: Minimum length (izzi- + 43 hex = 48 chars)
if ($ApiKey.Length -lt 48) {
    Write-Err "API key too short ($($ApiKey.Length) chars, need 48+). Check your key at: https://izziapi.com/dashboard"
    exit 1
}

# Check 4: BLOCKING server verification (SECURITY-RULES.md Rule #1)
Write-Host "  Verifying API key with server..." -ForegroundColor White
try {
    $verifyUrl = "$BaseUrl/v1/models"
    $verifyHeaders = @{ "x-api-key" = $ApiKey; "Content-Type" = "application/json" }
    $verifyResponse = Invoke-RestMethod -Uri $verifyUrl -Headers $verifyHeaders -TimeoutSec 15 -ErrorAction Stop
    $modelCount = if ($verifyResponse.data) { $verifyResponse.data.Count } else { 0 }
    Write-Ok "API key verified ($modelCount models available)"
}
catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 401) {
        Write-Err "API key is INVALID (server returned 401). Check your key at: https://izziapi.com/dashboard"
    } elseif ($statusCode -eq 403) {
        Write-Err "API key is REVOKED (server returned 403). Create new key at: https://izziapi.com/dashboard"
    } else {
        Write-Err "Cannot verify API key (server error: $statusCode). Check network and try again."
    }
    Write-Host ""
    Write-Host "  Installation ABORTED. No config files were modified." -ForegroundColor Red
    Write-Host ""
    exit 1
}

# Check 5: ADMIN KEY REJECTION (prevents admin key leaks — see SECURITY-RULES.md)
# After confirming the key is valid, verify it's NOT an admin key
Write-Host "  Checking key ownership..." -ForegroundColor White
try {
    $keyInfoUrl = "$BaseUrl/v1/key-info"
    $keyInfoHeaders = @{ "x-api-key" = $ApiKey; "Content-Type" = "application/json" }
    $keyInfo = Invoke-RestMethod -Uri $keyInfoUrl -Headers $keyInfoHeaders -TimeoutSec 10 -ErrorAction Stop
    
    if ($keyInfo.role -eq "admin") {
        Write-Host ""
        Write-Err "SECURITY BLOCKED: This is an ADMIN API key!"
        Write-Host ""
        Write-Host "    Admin keys must NOT be used in customer installations." -ForegroundColor Red
        Write-Host "    Using admin keys on external machines creates security risks." -ForegroundColor Red
        Write-Host ""
        Write-Host "    Instead, create a USER-level key:" -ForegroundColor Yellow
        Write-Host "      1. Log in at https://izziapi.com/dashboard" -ForegroundColor Gray
        Write-Host "      2. Go to 'API Keys' and create a new key" -ForegroundColor Gray
        Write-Host "      3. Use that key with this installer" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  Installation ABORTED. No config files were modified." -ForegroundColor Red
        Write-Host ""
        exit 1
    }
    
    # Show key owner info for confirmation
    Write-Ok "Key verified: $($keyInfo.key_name) ($($keyInfo.email_masked)) [Plan: $($keyInfo.plan)]"
}
catch {
    # /v1/key-info not available — warn but continue (backward compatibility)
    Write-Warn "Could not verify key ownership (server may need update). Proceeding..."
}

# ==============================
# END SECURITY GATE
# ==============================

Write-Host "  Base URL: $BaseUrl" -ForegroundColor Gray
Write-Host "  API Key:  $($ApiKey.Substring(0, [Math]::Min(16, $ApiKey.Length)))..." -ForegroundColor Gray
Write-Host ""

# ==============================
# PROVISION: Fetch config from server
# Model definitions, pricing, and agent configs are NOT stored in this script.
# They are fetched securely from the Izzi API at install time.
# ==============================

Write-Host "  Fetching configuration from server..." -ForegroundColor White
$provisionData = $null
try {
    $provisionUrl = "$BaseUrl/v1/provision"
    $provisionHeaders = @{
        "x-api-key" = $ApiKey
        "Content-Type" = "application/json"
        "User-Agent" = "izzi-installer/$Version (PowerShell)"
        "X-Installer-Version" = $Version
        "X-Platform" = "windows"
    }
    $provisionBody = @{
        installer_version = $Version
        platform = "windows"
    } | ConvertTo-Json
    $provisionData = Invoke-RestMethod -Uri $provisionUrl -Method Post -Headers $provisionHeaders -Body $provisionBody -TimeoutSec 20 -ErrorAction Stop
    Write-Ok "Configuration received ($($provisionData.agent_models.Count) models)"
}
catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 429) {
        Write-Err "Rate limited. Please wait a moment and try again."
    } else {
        Write-Warn "Could not fetch config from server (error: $statusCode). Using fallback mode..."
    }
}

$step = 1
$total = 5

# --- Step 1: Update openclaw.json ---

Write-Step $step $total "Updating openclaw.json..."

if (Test-Path $OC_CONFIG) {
    Backup-File $OC_CONFIG
    $config = Get-Content $OC_CONFIG -Raw | ConvertFrom-Json

    # Ensure models.providers exists
    if (-not $config.models) {
        $config | Add-Member -NotePropertyName "models" -NotePropertyValue ([PSCustomObject]@{ providers = [PSCustomObject]@{} })
    }
    if (-not $config.models.providers) {
        $config.models | Add-Member -NotePropertyName "providers" -NotePropertyValue ([PSCustomObject]@{})
    }

    # Build provider config from server data or fallback
    if ($provisionData -and $provisionData.provider) {
        $providerConfig = @{
            baseUrl = $BaseUrl
            api     = $provisionData.provider.api
            apiKey  = $ApiKey
            models  = $provisionData.provider.models
        }
    } else {
        # Fallback: minimal config (server will resolve models at runtime)
        $providerConfig = @{
            baseUrl = $BaseUrl
            api     = "openai-completions"
            apiKey  = $ApiKey
            models  = @(
                @{ id = "auto"; name = "Smart Router (Auto)" }
            )
        }
        Write-Warn "Using minimal fallback config. Re-run installer when server is available for full model list."
    }

    # Add/update izzi provider
    if ($config.models.providers.PSObject.Properties["izzi"]) {
        $config.models.providers.izzi = [PSCustomObject]$providerConfig
        Write-Ok "Updated existing izzi provider"
    }
    else {
        $config.models.providers | Add-Member -NotePropertyName "izzi" -NotePropertyValue ([PSCustomObject]$providerConfig)
        Write-Ok "Added izzi provider"
    }

    # Set default model
    if ($config.agents -and $config.agents.defaults -and $config.agents.defaults.model) {
        $config.agents.defaults.model.primary = "izzi/auto"
        Write-Ok "Set default model to izzi/auto"
    }

    $config | ConvertTo-Json -Depth 20 | Set-Content $OC_CONFIG -Encoding utf8
}
else {
    Write-Warn "openclaw.json not found - run 'openclaw setup' first"
}

$step++

# --- Step 2: Update ALL agent models.json ---

Write-Step $step $total "Updating agent configs..."

$agentDirs = Get-ChildItem (Join-Path $OC_DIR "agents") -Directory -ErrorAction SilentlyContinue
$updated = 0

foreach ($agent in $agentDirs) {
    $modelsFile = Join-Path $agent.FullName "agent\models.json"
    if (Test-Path $modelsFile) {
        Backup-File $modelsFile
        $models = Get-Content $modelsFile -Raw | ConvertFrom-Json

        # Build agent model definitions from server data or fallback
        if ($provisionData -and $provisionData.agent_models) {
            $agentModelDef = $provisionData.agent_models
        } else {
            # Fallback: auto-only
            $agentModelDef = @(
                @{ id = "auto"; name = "Smart Router (Auto)"; reasoning = $false; input = @("text"); cost = @{ input = 0; output = 0; cacheRead = 0; cacheWrite = 0 }; contextWindow = 200000; maxTokens = 8192; api = "openai-completions" }
            )
        }

        # Add/update izzi provider with full model definitions
        $izziAgent = [PSCustomObject]@{
            baseUrl = $BaseUrl
            apiKey  = $ApiKey
            api     = "openai-completions"
            models  = $agentModelDef
        }

        if ($models.providers.PSObject.Properties["izzi"]) {
            $models.providers.izzi = $izziAgent
        }
        else {
            $models.providers | Add-Member -NotePropertyName "izzi" -NotePropertyValue $izziAgent
        }

        $models | ConvertTo-Json -Depth 20 | Set-Content $modelsFile -Encoding utf8
        $updated++
        Write-Ok "$($agent.Name)/agent/models.json"
    }
}

if ($updated -eq 0) {
    Write-Warn "No agent model configs found"
}

$step++

# --- Step 3: Apply known fixes ---

Write-Step $step $total "Applying compatibility fixes..."

$fixes = 0

# Fix 1: Remove /v1 suffix from baseUrl (OpenClaw adds it via api type)
$allConfigs = @($OC_CONFIG) + (Get-ChildItem (Join-Path $OC_DIR "agents") -Recurse -Filter "models.json" -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })

foreach ($f in $allConfigs) {
    if (Test-Path $f) {
        $raw = Get-Content $f -Raw
        if ($raw -match '"baseUrl":\s*"[^"]+/v1"') {
            $raw = $raw -replace '("baseUrl":\s*"[^"]+)/v1"', '$1"'
            $raw | Set-Content $f -Encoding utf8 -NoNewline
            $fixes++
            Write-Ok "Fixed: removed /v1 suffix in $(Split-Path $f -Leaf)"
        }
    }
}

if ($fixes -eq 0) {
    Write-Ok "No URL fixes needed"
}

$step++

# --- Step 4: Connectivity re-check (already verified in Security Gate) ---

Write-Step $step $total "Confirming API access..."
Write-Ok "Already verified in pre-flight check"

$step++

# --- Step 5: Restart gateway ---

Write-Step $step $total "Restarting OpenClaw gateway..."

if (-not $SkipRestart) {
    try {
        $null = & openclaw gateway restart 2>&1
        Write-Ok "Gateway restart triggered"
    }
    catch {
        Write-Warn "Could not restart gateway - restart OpenClaw manually"
    }
}
else {
    Write-Ok "Skipped (use -SkipRestart to disable)"
}

# --- Done ---

Write-Host ""
Write-Host "  ============================================" -ForegroundColor Cyan
Write-Host "  [DONE] Installation complete! (v$Version)" -ForegroundColor Green
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor White
Write-Host ""
Write-Host "  1. Restart OpenClaw (close and reopen)" -ForegroundColor Gray
Write-Host ""
Write-Host "  2. Select model 'auto - izzi' in chat" -ForegroundColor Gray
Write-Host ""
Write-Host "  3. Send a message - it should work!" -ForegroundColor Gray
Write-Host ""
Write-Host "  Dashboard:  https://izziapi.com/dashboard" -ForegroundColor DarkGray
Write-Host "  Docs:       https://izziapi.com/docs" -ForegroundColor DarkGray
Write-Host "  Issues:     https://github.com/kentzu213/izzi-openclaw/issues" -ForegroundColor DarkGray
Write-Host ""

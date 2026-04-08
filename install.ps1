<#
.SYNOPSIS
    Izzi x OpenClaw Connector - Windows Installer
.DESCRIPTION
    Connects your Izzi API key to OpenClaw so all agents can use Izzi models.
    Applies known compatibility fixes automatically.
.PARAMETER ApiKey
    Your Izzi API key (starts with "izzi-"). Get one at https://izziapi.com/dashboard
.PARAMETER BaseUrl
    API base URL. Default: https://izziapi.com
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
    [switch]$SkipRestart,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$Version = "2.0.0"
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
        Write-Host "  Get your key at: $BaseUrl/dashboard" -ForegroundColor Gray
        Write-Host ""
        exit 1
    }
}

# Validate key format
if (-not $ApiKey.StartsWith("izzi-")) {
    if (-not $Force) {
        Write-Warn "API key does not start with 'izzi-'. Use -Force to override."
        exit 1
    }
}

Write-Host "  Base URL: $BaseUrl" -ForegroundColor Gray
Write-Host "  API Key:  $($ApiKey.Substring(0, [Math]::Min(16, $ApiKey.Length)))..." -ForegroundColor Gray
Write-Host ""

$step = 1
$total = 5

# --- Provider definition (template) ---

$providerConfig = @{
    baseUrl = $BaseUrl
    api     = "openai-completions"
    apiKey  = $ApiKey
    models  = @(
        @{ id = "auto"; name = "Smart Router (Auto)" }
        @{ id = "llama-3.3-70b"; name = "Llama 3.3 70B (Free)" }
        @{ id = "qwen3-235b"; name = "Qwen3 235B (Free)" }
        @{ id = "gemini-2.5-flash"; name = "Gemini 2.5 Flash" }
        @{ id = "gpt-4.1-mini"; name = "GPT-4.1 Mini" }
        @{ id = "REDACTED_MODEL"; name = "GPT-5.1 via 9R (30% off)" }
        @{ id = "gpt-5.1"; name = "GPT-5.1" }
        @{ id = "claude-haiku-4.5"; name = "Claude Haiku 4.5" }
        @{ id = "claude-sonnet-4"; name = "Claude Sonnet 4" }
        @{ id = "gpt-5.4"; name = "GPT-5.4" }
        @{ id = "gpt-5.2"; name = "GPT-5.2" }
        @{ id = "gemini-2.5-pro"; name = "Gemini 2.5 Pro" }
    )
}

$agentModelDef = @(
    @{ id = "auto"; name = "Smart Router (Auto)"; reasoning = $false; input = @("text"); cost = @{ input = 0; output = 0; cacheRead = 0; cacheWrite = 0 }; contextWindow = 200000; maxTokens = 8192; api = "openai-completions" }
    @{ id = "llama-3.3-70b"; name = "Llama 3.3 70B (Free)"; reasoning = $false; input = @("text"); cost = @{ input = 0; output = 0; cacheRead = 0; cacheWrite = 0 }; contextWindow = 200000; maxTokens = 8192; api = "openai-completions" }
    @{ id = "qwen3-235b"; name = "Qwen3 235B (Free)"; reasoning = $true; input = @("text"); cost = @{ input = 0; output = 0; cacheRead = 0; cacheWrite = 0 }; contextWindow = 200000; maxTokens = 8192; api = "openai-completions" }
    @{ id = "gemini-2.5-flash"; name = "Gemini 2.5 Flash"; reasoning = $true; input = @("text"); cost = @{ input = 0.33; output = 2.75; cacheRead = 0; cacheWrite = 0.04 }; contextWindow = 200000; maxTokens = 8192; api = "openai-completions" }
    @{ id = "gpt-4.1-mini"; name = "GPT-4.1 Mini"; reasoning = $false; input = @("text"); cost = @{ input = 0.44; output = 1.76; cacheRead = 0; cacheWrite = 0.11 }; contextWindow = 200000; maxTokens = 16384; api = "openai-completions" }
    @{ id = "REDACTED_MODEL"; name = "GPT-5.1 via 9R (30% off)"; reasoning = $false; input = @("text"); cost = @{ input = 0.70; output = 5.60; cacheRead = 0; cacheWrite = 0.35 }; contextWindow = 200000; maxTokens = 8192; api = "openai-completions" }
    @{ id = "gpt-5.1"; name = "GPT-5.1"; reasoning = $false; input = @("text"); cost = @{ input = 1.10; output = 8.80; cacheRead = 0; cacheWrite = 0.55 }; contextWindow = 200000; maxTokens = 8192; api = "openai-completions" }
    @{ id = "claude-haiku-4.5"; name = "Claude Haiku 4.5"; reasoning = $false; input = @("text"); cost = @{ input = 0.88; output = 4.40; cacheRead = 0; cacheWrite = 0.44 }; contextWindow = 200000; maxTokens = 8192; api = "openai-completions" }
    @{ id = "claude-sonnet-4"; name = "Claude Sonnet 4"; reasoning = $false; input = @("text"); cost = @{ input = 3.30; output = 16.50; cacheRead = 0; cacheWrite = 1.65 }; contextWindow = 200000; maxTokens = 8192; api = "openai-completions" }
    @{ id = "gpt-5.4"; name = "GPT-5.4"; reasoning = $false; input = @("text"); cost = @{ input = 2.75; output = 16.50; cacheRead = 0; cacheWrite = 1.38 }; contextWindow = 200000; maxTokens = 8192; api = "openai-completions" }
    @{ id = "gpt-5.2"; name = "GPT-5.2"; reasoning = $true; input = @("text"); cost = @{ input = 1.925; output = 15.40; cacheRead = 0; cacheWrite = 0.96 }; contextWindow = 200000; maxTokens = 8192; api = "openai-completions" }
    @{ id = "gemini-2.5-pro"; name = "Gemini 2.5 Pro"; reasoning = $true; input = @("text"); cost = @{ input = 1.375; output = 11.00; cacheRead = 0; cacheWrite = 0.35 }; contextWindow = 200000; maxTokens = 8192; api = "openai-completions" }
)

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

# --- Step 4: Connectivity test ---

Write-Step $step $total "Testing connectivity..."

try {
    $testUrl = "$BaseUrl/v1/models"
    $headers = @{ "x-api-key" = $ApiKey; "Content-Type" = "application/json" }
    $response = Invoke-RestMethod -Uri $testUrl -Headers $headers -TimeoutSec 10 -ErrorAction Stop
    $modelCount = if ($response.data) { $response.data.Count } else { "?" }
    Write-Ok "Connected to Izzi API ($modelCount models available)"
}
catch {
    Write-Warn "Could not reach $BaseUrl - this is OK if using localhost"
    Write-Host "    You can test later with: openclaw models list" -ForegroundColor Gray
}

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
Write-Host "  [DONE] Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor White
Write-Host ""
Write-Host "  1. Restart OpenClaw (close and reopen)" -ForegroundColor Gray
Write-Host ""
Write-Host "  2. Select model 'auto - izzi' in chat" -ForegroundColor Gray
Write-Host ""
Write-Host "  3. Send a message - it should work!" -ForegroundColor Gray
Write-Host ""
Write-Host "  Dashboard: $BaseUrl/dashboard" -ForegroundColor DarkGray
Write-Host "  Docs:      $BaseUrl/docs" -ForegroundColor DarkGray
Write-Host "  Issues:    https://github.com/kentzu213/izzi-openclaw/issues" -ForegroundColor DarkGray
Write-Host ""

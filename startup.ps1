<#
.SYNOPSIS
    OpenClaw Gateway Auto-Start Manager (Windows Task Scheduler)
.DESCRIPTION
    Creates/removes a scheduled task that starts OpenClaw gateway when user logs in.
.PARAMETER Install
    Create the auto-start scheduled task.
.PARAMETER Uninstall
    Remove the auto-start scheduled task.
.PARAMETER Status
    Check if the auto-start task exists and its status.
.EXAMPLE
    .\startup.ps1 -Install
    .\startup.ps1 -Uninstall
    .\startup.ps1 -Status
.LINK
    https://github.com/kentzu213/izzi-openclaw
#>

param(
    [switch]$Install,
    [switch]$Uninstall,
    [switch]$Status
)

$TaskName = "OpenClaw-Gateway-AutoStart"
$TaskDescription = "Start OpenClaw gateway automatically when user logs in. Managed by izzi-openclaw."

# --- Helpers ---

function Write-Banner {
    Write-Host ""
    Write-Host "  ============================================" -ForegroundColor Cyan
    Write-Host "       OpenClaw Auto-Start Manager" -ForegroundColor Cyan
    Write-Host "  ============================================" -ForegroundColor Cyan
    Write-Host ""
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

function Find-OpenClawCmd {
    # Try npm global bin first
    $npmGlobal = & npm config get prefix 2>$null
    if ($npmGlobal) {
        $cmdPath = Join-Path $npmGlobal "openclaw.cmd"
        if (Test-Path $cmdPath) { return $cmdPath }
    }

    # Try common locations
    $commonPaths = @(
        (Join-Path $env:APPDATA "npm\openclaw.cmd"),
        (Join-Path $env:LOCALAPPDATA "npm\openclaw.cmd"),
        (Join-Path $env:ProgramFiles "nodejs\openclaw.cmd")
    )

    foreach ($p in $commonPaths) {
        if (Test-Path $p) { return $p }
    }

    # Last resort: where.exe
    $whereResult = & where.exe openclaw.cmd 2>$null
    if ($whereResult) { return $whereResult.Split("`n")[0].Trim() }

    return $null
}

# --- Status ---

if ($Status -or (-not $Install -and -not $Uninstall)) {
    Write-Banner
    Write-Host "  Checking auto-start status..." -ForegroundColor White
    Write-Host ""

    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($task) {
        Write-Ok "Task '$TaskName' exists"
        Write-Host "    State:   $($task.State)" -ForegroundColor Gray
        Write-Host "    Trigger: At user logon" -ForegroundColor Gray

        $info = Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction SilentlyContinue
        if ($info -and $info.LastRunTime -ne $null) {
            Write-Host "    Last Run: $($info.LastRunTime)" -ForegroundColor Gray
            Write-Host "    Result:   $($info.LastTaskResult)" -ForegroundColor Gray
        }
    } else {
        Write-Warn "Auto-start is NOT configured."
        Write-Host "    Run: startup.bat install" -ForegroundColor Gray
    }

    Write-Host ""
    if (-not $Install -and -not $Uninstall) { exit 0 }
}

# --- Install ---

if ($Install) {
    Write-Banner
    Write-Host "  Installing auto-start task..." -ForegroundColor White
    Write-Host ""

    # Check if already exists
    $existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Warn "Task already exists. Removing old task first..."
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    }

    # Find openclaw.cmd
    $ocCmd = Find-OpenClawCmd
    if (-not $ocCmd) {
        Write-Err "Could not find openclaw.cmd"
        Write-Host "    Make sure OpenClaw is installed: npm install -g openclaw" -ForegroundColor Gray
        Write-Host ""
        exit 1
    }

    Write-Ok "Found OpenClaw at: $ocCmd"

    # Create the scheduled task
    try {
        # Action: run openclaw gateway start via cmd.exe (avoids PS execution policy issues)
        $action = New-ScheduledTaskAction `
            -Execute "cmd.exe" `
            -Argument "/c `"$ocCmd`" gateway start"

        # Trigger: at user logon, with 30s delay to let network/services initialize
        $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
        $trigger.Delay = "PT30S"

        # Settings: allow running on battery, don't stop on battery, run hidden
        $settings = New-ScheduledTaskSettingsSet `
            -AllowStartIfOnBatteries `
            -DontStopIfGoingOnBatteries `
            -StartWhenAvailable `
            -ExecutionTimeLimit (New-TimeSpan -Hours 0) `
            -RestartCount 3 `
            -RestartInterval (New-TimeSpan -Minutes 1)

        # Register the task
        Register-ScheduledTask `
            -TaskName $TaskName `
            -Description $TaskDescription `
            -Action $action `
            -Trigger $trigger `
            -Settings $settings `
            -RunLevel Limited | Out-Null

        Write-Ok "Scheduled task created: '$TaskName'"
        Write-Host "    Trigger: At logon (30s delay for network)" -ForegroundColor Gray
        Write-Host "    Action:  openclaw gateway start" -ForegroundColor Gray
        Write-Host "    Retries: 3 (every 1 min on failure)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  OpenClaw will auto-start next time you log in!" -ForegroundColor Green

        # Offer to start now
        Write-Host ""
        $startNow = Read-Host "  Start gateway now? [Y/n]"
        if ($startNow -notmatch '^[nN]') {
            Write-Host "  Starting OpenClaw gateway..." -ForegroundColor Gray
            Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$ocCmd`" gateway start" -WindowStyle Hidden
            Start-Sleep -Seconds 2
            Write-Ok "Gateway start triggered (running in background)"
        }
    }
    catch {
        Write-Err "Failed to create scheduled task: $_"
        Write-Host ""
        Write-Host "  Try running this script as Administrator:" -ForegroundColor Yellow
        Write-Host "    Right-click PowerShell -> Run as Administrator" -ForegroundColor Gray
        Write-Host "    Then run: .\startup.ps1 -Install" -ForegroundColor Gray
        exit 1
    }

    Write-Host ""
    exit 0
}

# --- Uninstall ---

if ($Uninstall) {
    Write-Banner
    Write-Host "  Removing auto-start task..." -ForegroundColor White
    Write-Host ""

    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($task) {
        # Stop if running
        if ($task.State -eq "Running") {
            Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
            Write-Ok "Stopped running task"
        }

        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Ok "Removed scheduled task '$TaskName'"

        # Also try to stop the gateway
        Write-Host "  Stopping OpenClaw gateway..." -ForegroundColor Gray
        try {
            $ocCmd = Find-OpenClawCmd
            if ($ocCmd) {
                & cmd.exe /c "`"$ocCmd`" gateway stop" 2>$null
                Write-Ok "Gateway stop triggered"
            }
        } catch { }
    }
    else {
        Write-Ok "Task '$TaskName' not found (already removed)"
    }

    Write-Host ""
    Write-Host "  Auto-start disabled. OpenClaw will NOT start on boot." -ForegroundColor Yellow
    Write-Host ""
    exit 0
}

# 🔧 Troubleshooting Guide — Izzi × OpenClaw

This document covers all known compatibility issues between Izzi API and OpenClaw, with step-by-step manual fixes.

> **Quick fix**: Run `.\fix.ps1 -Auto` (Windows) or `./fix.sh --auto` (macOS/Linux) to fix all issues automatically.

---

## Issue #1: 404 Upstream Error

**Symptoms:**
```
Error: 404 Upstream - No endpoints found
```

**Root Cause:** OpenClaw constructs the API URL as `baseUrl + /v1/chat/completions`. If your `baseUrl` already includes `/v1`, the final URL becomes `/v1/v1/chat/completions` → 404.

**Fix:**

Remove `/v1` from the `baseUrl` in ALL config files:

```diff
- "baseUrl": "https://izziapi.com/v1"
+ "baseUrl": "https://izziapi.com"
```

**Files to check:**
- `~/.openclaw/openclaw.json`
- `~/.openclaw/agents/*/agent/models.json` (every agent!)

---

## Issue #2: Agent Config Overrides Global Config

**Symptoms:** You changed `openclaw.json` but the agent still uses the old URL/key.

**Root Cause:** OpenClaw prioritizes `agents/{name}/agent/models.json` over local `openclaw.json` for each agent. If the agent has its own `izzi` provider block, the global config is **ignored**.

**Fix:**

Ensure ALL agent model configs have the **same** izzi provider settings:

```powershell
# Windows — check all configs
Get-ChildItem "$env:USERPROFILE\.openclaw\agents" -Recurse -Filter "models.json" |
  ForEach-Object { 
    $content = Get-Content $_.FullName | Select-String "baseUrl"
    "$($_.FullName): $content"
  }
```

```bash
# macOS/Linux
find ~/.openclaw/agents -name "models.json" -exec grep -l "baseUrl" {} \;
```

Run the installer again to sync all configs:
```powershell
.\install.ps1 -ApiKey "izzi-YOUR_KEY" -Force
```

---

## Issue #3: Stale Model Names (OpenRouter)

**Symptoms:**
```
Error: No endpoints found for deepseek/deepseek-r1:free
```

**Root Cause:** OpenRouter periodically removes or renames free-tier models. The `:free` variants get deprecated.

**Affected models (as of April 2026):**

| Old (removed) | Replacement |
|----------------|-------------|
| `deepseek/deepseek-r1:free` | `qwen/qwen3.6-plus:free` |
| `deepseek/deepseek-chat-v3-0324:free` | `qwen/qwen3.6-plus:free` |
| `mistralai/mistral-small-3.1-24b-instruct:free` | `google/gemma-3-27b-it:free` |
| `qwen/qwen3-4b:free` | `google/gemma-3-4b-it:free` |

**Fix:** This is a **backend** issue. If you run the Izzi backend locally, update `src/services/router.ts` with the new model names. The auto-fix tool handles this automatically.

---

## Issue #4: Gateway Not Picking Up Config Changes

**Symptoms:** You changed the config but OpenClaw still uses old settings.

**Root Cause:** The OpenClaw gateway loads config into memory at startup. Config file changes are **not hot-reloaded**.

**Fix:**

1. Close OpenClaw completely (right-click tray icon → Exit)
2. Reopen OpenClaw
3. Verify the gateway is using new config

Or restart the gateway via CLI:
```bash
openclaw gateway restart
```

---

## Issue #5: ESM Module Error (Backend)

**Symptoms:**
```
ReferenceError: require is not defined in ES module scope
```

**Root Cause:** The izzi-backend uses ES modules (`"type": "module"` in package.json). Using `require()` is not compatible.

**Fix:** Use `import` instead of `require`:

```diff
- const fs = require("fs");
+ import { appendFileSync } from "node:fs";
```

---

## Diagnostic Commands

### Check your current config
```powershell
# Windows
Get-Content "$env:USERPROFILE\.openclaw\openclaw.json" | Select-String "izzi" -Context 3
```

```bash
# macOS/Linux
grep -A 5 "izzi" ~/.openclaw/openclaw.json
```

### Test API connectivity
```powershell
# Windows
$h = @{ "x-api-key" = "izzi-YOUR_KEY"; "Content-Type" = "application/json" }
$b = '{"model":"auto","messages":[{"role":"user","content":"say OK"}]}'
Invoke-RestMethod "https://izziapi.com/v1/chat/completions" -Method POST -Headers $h -Body $b
```

```bash
# macOS/Linux
curl -X POST "https://izziapi.com/v1/chat/completions" \
  -H "x-api-key: izzi-YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"auto","messages":[{"role":"user","content":"say OK"}]}'
```

### Check debug logs (local backend)
```bash
tail -f izzi-backend/izzi-debug.log
```

---

## Still having issues?

1. Run the auto-fix tool: `.\fix.ps1 -Diagnose`
2. Open an issue: [GitHub Issues](https://github.com/kentzu213/izzi-openclaw/issues)
3. Include your debug log output and diagnostic commands results

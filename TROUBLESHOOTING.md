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
- "baseUrl": "https://api.izziapi.com/v1"
+ "baseUrl": "https://api.izziapi.com"
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
| `qwen3-235b` (old Izzi name) | `qwen3.6-plus-free` |

**Fix:** Re-run the installer to get updated model IDs, or manually update your config.

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

## Issue #6: "network connection error" — baseUrl Points to localhost ⭐ NEW

**Symptoms:**
```
LLM request failed: network connection error
```

**Root Cause:** The `baseUrl` in `openclaw.json` is set to `http://localhost:8787` instead of the production API URL. This happens when:
- Installing from an old template that assumed local backend
- Manual config editing with wrong URL
- Copy-pasting config from a development environment

**Fix:**

```diff
- "baseUrl": "http://localhost:8787"
+ "baseUrl": "https://api.izziapi.com"
```

**Verification:**
```powershell
# Windows — check current baseUrl
Get-Content "$env:USERPROFILE\.openclaw\openclaw.json" | Select-String "baseUrl"
```

```bash
# macOS/Linux
grep "baseUrl" ~/.openclaw/openclaw.json
```

**Must be:** `https://api.izziapi.com` (NOT `localhost`, NOT `izziapi.com`, NOT `api.izziapi.com/v1`)

---

## Issue #7: ERR_TOO_MANY_REDIRECTS (Cloudflare + Caddy) ⭐ NEW

**Symptoms:**
```
Error: ERR_TOO_MANY_REDIRECTS at https://api.izziapi.com/
```
Or the browser shows "This page isn't working — redirected you too many times".

**Root Cause:** Cloudflare SSL/TLS mode is set to "Flexible" (terminates HTTPS at Cloudflare edge, sends HTTP to origin), but Caddy on the VPS has auto-HTTPS enabled which redirects HTTP → HTTPS, creating an infinite loop:

```
User → HTTPS → Cloudflare → HTTP → Caddy → HTTPS redirect → Cloudflare → HTTP → Caddy → ...
```

**Fix (VPS Caddy):**

Configure Caddy to listen on `:80` only (no auto-HTTPS) since Cloudflare handles TLS:

```caddyfile
:80 {
    reverse_proxy localhost:8787 {
        flush_interval -1
    }
}
```

**Or Fix (Cloudflare):**

Change SSL/TLS mode to "Full (Strict)" and let Caddy handle TLS with its own cert.

---

## Issue #8: Provider Key Missing — 503 Error ⭐ NEW

**Symptoms:**
```
{"error":{"message":"No API keys configured for provider: openrouter","type":"provider_error"}}
```
Or: `503 Service Unavailable`

**Root Cause:** The Izzi backend doesn't have API keys configured for the upstream provider (OpenRouter, Cerebras, etc.) in its `.env` file.

**Fix (Backend admin):**

Add required keys to `/root/izzi-backend/.env`:
```env
OPENROUTER_API_KEYS=sk-or-v1-your-key-here
CEREBRAS_API_KEYS=csk-your-key-here
```

Then restart the backend:
```bash
docker restart izzi-backend
```

**Note:** This is a **server-side** issue. End users cannot fix this — contact the API administrator.

---

## Issue #9: Non-existent Model ID Returns 400 ⭐ NEW

**Symptoms:**
```
{"error":{"message":"Model 'qwen3-235b' not found","type":"invalid_request_error"}}
```

**Root Cause:** The model ID in your config doesn't match any model registered in the Izzi backend router. Model IDs change over time as new models are added and old ones deprecated.

**Current valid free models (April 2026):**

| Model ID | Provider | Description |
|----------|----------|-------------|
| `auto` | Smart Router | Auto-selects best model |
| `qwen3.6-plus-free` | OpenRouter | Qwen 3.6 Plus (recommended) |
| `llama-3.3-70b` | Groq | Meta Llama 3.3 70B |
| `deepseek-r1-free` | OpenRouter | DeepSeek R1 reasoning |
| `llama-3.1-8b` | Groq/Cerebras | Meta Llama 3.1 8B (fastest) |

**Fix:** Re-run the installer to get the latest model list, or manually update your config.

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
# Windows (PowerShell 7+)
curl.exe -s "https://api.izziapi.com/health"
# Expected: {"status":"ok","timestamp":"..."}
```

```bash
# macOS/Linux
curl -s "https://api.izziapi.com/health"
```

### Test API with your key
```powershell
# Windows
curl.exe -s "https://api.izziapi.com/v1/models" -H "x-api-key: izzi-YOUR_KEY"
```

```bash
# macOS/Linux
curl -s "https://api.izziapi.com/v1/models" -H "x-api-key: izzi-YOUR_KEY"
```

### Full chat test
```bash
curl -X POST "https://api.izziapi.com/v1/chat/completions" \
  -H "x-api-key: izzi-YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"auto","messages":[{"role":"user","content":"say OK"}]}'
```

### Check debug logs (gateway)
```powershell
# Windows — find today's log
Get-Content "$env:TEMP\openclaw\openclaw-$(Get-Date -Format 'yyyy-MM-dd').log" -Tail 50
```

```bash
# macOS/Linux
tail -50 /tmp/openclaw/openclaw-$(date +%Y-%m-%d).log
```

---

## Bug Timeline & Resolution History

| Date | Bug | Root Cause | Status |
|------|-----|------------|--------|
| 2026-04-01 | 404 Upstream `/v1/v1` | Double prefix in baseUrl | ✅ Fixed |
| 2026-04-01 | Agent overrides global config | Per-agent models.json priority | ✅ Fixed |
| 2026-04-03 | Stale OpenRouter models | Deprecated `:free` variants | ✅ Fixed |
| 2026-04-03 | Gateway ignores config changes | No hot-reload | ✅ Documented |
| 2026-04-06 | `network connection error` | baseUrl = localhost:8787 | ✅ Fixed |
| 2026-04-06 | ERR_TOO_MANY_REDIRECTS | Cloudflare/Caddy TLS conflict | ✅ Fixed |
| 2026-04-06 | Provider 503 | Missing upstream API keys | ✅ Fixed |
| 2026-04-07 | Model not found 400 | `qwen3-235b` doesn't exist | ✅ Fixed |

---

## Still having issues?

1. Run the auto-fix tool: `.\fix.ps1 -Diagnose`
2. Open an issue: [GitHub Issues](https://github.com/kentzu213/izzi-openclaw/issues)
3. Include your debug log output and diagnostic commands results

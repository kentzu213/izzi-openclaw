# Changelog

All notable changes to this project will be documented in this file.

## [2.3.0] — 2026-04-09

### Added
- **`install-vps.sh`** — Full VPS/server installer for Ubuntu 20.04+ and Debian 11+
  - Auto-installs Node.js 20 LTS via NodeSource
  - Auto-installs OpenClaw globally via npm
  - Configures Izzi provider with v4.2 verified models
  - Creates systemd service (`openclaw-gateway`) for auto-restart on boot
  - System hardening: `NoNewPrivileges`, `ProtectSystem=strict`
  - Optional UFW firewall config (`--with-ufw`)
  - Configurable Node version (`--node=22`), port (`--port=8080`)
- **VPS section in README.md** — One-liner install + service management commands
- **jq fallback** — VPS installer uses jq (auto-installed) when python3 unavailable

### Security
- VPS installer follows identical SECURITY-RULES.md contract (6 rules)
- API key verified server-side BEFORE any system modification
- Node.js and OpenClaw only installed AFTER key passes validation

## [2.2.0] — 2026-04-09

### Breaking Changes
- **REMOVED `-Force` flag** — Key validation can no longer be bypassed
- **API key verification is now BLOCKING** — Installer will abort if key is invalid/revoked/unreachable

### Added
- **SECURITY-RULES.md** — Permanent security contract for this repo. Defines 6 immutable rules
- **Mandatory server-side API key verification** — Installer calls `GET /v1/models` with key BEFORE writing any config
- **Format enforcement** — API key must: start with `izzi-`, be 48+ chars, not be placeholder
- **macOS curl one-liner** — `curl -fsSL ...install.sh | bash -s -- "izzi-KEY"`
- **.gitattributes** — Enforces LF for `.sh` files, CRLF for `.bat/.ps1`

### Fixed
- **CRITICAL: install.sh CRLF line endings** — Windows line endings broke bash on macOS
- **CRITICAL: install.sh allowed invalid API keys** — Only warned but continued installation
- **install.sh dead models** — Synced from v2.0.0 (12 dead) to v4.2 verified (7 working)
- **openclaw-provider.json** — Pruned 30 dead models to 7 verified v4.2

### Changed
- Version bumped to **2.2.0** in `install.ps1` and `install.sh`
- Connectivity test moved from Step 4 to pre-flight Security Gate
- install.sh now uses v4.2 cx/ model namespace

## [2.1.0] — 2026-04-09

### Added
- **Auto-start on Windows boot** — `startup.bat install` creates a Task Scheduler task that runs `openclaw gateway start` at login (30s delay for network)
- **`startup.ps1` / `startup.bat`** — Manage auto-start: install, uninstall, status
- **ExecutionPolicy auto-fix** — Installer now detects `Restricted` policy and sets `RemoteSigned` (CurrentUser scope) automatically
- **Issue #12** in TROUBLESHOOTING.md: PSSecurityException / UnauthorizedAccess
- **Issue #13** in TROUBLESHOOTING.md: OpenClaw not running after reboot

### Fixed
- **CRITICAL: PSSecurityException blocks OpenClaw commands** — Windows PowerShell `Restricted` policy prevents `openclaw.ps1` wrapper from running. Both `install.bat` and `install.ps1` now auto-fix this.
- **Dead models in installer** — Removed ALL non-working models (`llama-3.3-70b`, `qwen3-235b`, `gemini-2.5-flash`, `gpt-4.1-mini`, `claude-sonnet-4`, `gpt-5.1`, `gemini-2.5-pro`, etc.) that 404 on ninerouter
- **Model list synced to v4.2** — Only E2E verified `cx/` models remain: `REDACTED_MODEL`, `REDACTED_MODEL`, `REDACTED_MODEL`, `REDACTED_MODEL`, `REDACTED_MODEL`, `REDACTED_MODEL`

### Changed
- Version bumped to **2.1.0** in `install.ps1`
- `install.bat` now fixes ExecutionPolicy before calling `.ps1`
- Installer adds Step 6: auto-start prompt during installation
- Updated valid model table in TROUBLESHOOTING.md

## [2.0.0] — 2026-04-09

### Breaking Changes
- **Removed invalid models**: `deepseek-r1-free`, `llama-3.1-8b`, `llama-4-maverick-17b-128e`, `llama-4-scout-17b-16e` — these models do not exist in the backend and caused 404 errors.

### Added
- **25+ new models** — Total model count: 7 → 30+ (synced from backend `router.ts`)
- **4-tier pricing system**: Maintained (Free), Budget, Standard, Premium
- **9R discount models** — `REDACTED_MODEL`, `REDACTED_MODEL`, `REDACTED_MODEL`, `9r-auto` — same premium models at 30% lower price via 9Router free tier
- **Budget models**: `gemini-2.5-flash-lite`, `gpt-4o-mini`, `gpt-5.4-nano`, `grok-4.1-fast`, `gemini-2.5-flash`, `gpt-4.1-mini`, `gpt-5.4-mini`
- **Standard models**: `claude-haiku-4.5`, `gpt-5.1`, `gpt-5.1-codex`, `o3-mini`, `gpt-4.1`, `gpt-4o`
- **Premium models**: `claude-sonnet-4.5`, `claude-opus-4`, `gemini-2.5-pro`, `gpt-5.2`, `grok-4`
- **Accurate pricing** in `templates/models.json` — costs now match backend rates
- **Bug #10-11** in TROUBLESHOOTING.md: cx/ prefix routing fix, 9Router model name mismatch

### Fixed
- **CRITICAL: cx/ prefix routing** — GPT-5.x models in backend now correctly use `cx/` prefix for 9Router, preventing 404 errors
- **Model pricing mismatch** — `templates/models.json` costs were all `0` for paid models, now shows actual credit costs

### Changed
- Version bumped to **2.0.0** in `install.ps1` and `install.sh`
- `templates/openclaw-provider.json` updated to 30 models (was 10)
- `templates/models.json` updated to 30+ models with pricing (was 7)
- README.md completely rewritten with model tier tables
- Installer now registers 12 popular models (up from 7)


## [1.2.0] — 2026-04-07

### Fixed (Server-Side — No reinstall needed)
- **CRITICAL: Google login returns 401 "Invalid API key"** — Proxy middleware was intercepting dashboard JWT auth routes (`/api/auth/me`). Fixed by adding path guard in `authMiddleware` to skip `/api/*` paths.
- **CORS duplicate headers blocking all API calls** — Both Caddy and Hono set `Access-Control-Allow-Origin`, browsers rejected the duplicate. Removed CORS from Caddy, letting Hono handle exclusively.
- **HTTP 404 "Endpoint not found" for root-level paths** — `/chat/completions` (without `/v1/`) returned 404. Fixed by restoring root-level proxy route with auth guard.

### Added
- **3 new bug entries** in TROUBLESHOOTING.md (Issues #10-12)

### Note
> These fixes are **server-side only**. Users do NOT need to reinstall or update their OpenClaw config. The backend now correctly handles both `/v1/chat/completions` and `/chat/completions` paths.

## [1.1.0] — 2026-04-07

### Fixed
- **CRITICAL: baseUrl pointed to localhost** — Changed default `baseUrl` from `http://localhost:8787` to `https://api.izziapi.com` in all templates. This was the root cause of "network connection error" for most users. (#6)
- **Model ID `qwen3-235b` doesn't exist** — Replaced with `qwen3.6-plus-free` (Qwen 3.6 Plus via OpenRouter). (#9)
- **models.json template had wrong baseUrl** — Was `https://izziapi.com`, now `https://api.izziapi.com`. (#1 variant)

### Added
- `CHANGELOG.md` — Version history tracking
- **4 new bug entries** in TROUBLESHOOTING.md:
  - Issue #6: baseUrl localhost → network connection error
  - Issue #7: Cloudflare/Caddy ERR_TOO_MANY_REDIRECTS
  - Issue #8: Provider 503 (missing upstream API keys)
  - Issue #9: Non-existent model ID returns 400
- **Bug Timeline table** — Complete resolution history with dates
- **Quick Health Check** commands in README
- **Model naming tip** — Use specific model IDs for transparency
- `reasoning: true` flag for Qwen 3.6 Plus and DeepSeek R1 models

### Changed
- Updated model list across all files:
  - `README.md` — Split into Free/Premium categories
  - `templates/openclaw-provider.json` — Already correct
  - `templates/models.json` — Fixed baseUrl and model IDs
- Improved diagnostic commands (gateway logs, full chat test)
- Updated troubleshooting API test URLs to use `api.izziapi.com`

## [1.0.2] — 2026-04-04

### Fixed
- Removed Unicode emoji from PS1 scripts — fixes CMD encoding crash
- Added `.bat` wrappers for CMD users — `.ps1` opens Notepad in CMD

## [1.0.0] — 2026-04-01

### Added
- Initial release: Izzi × OpenClaw connector
- `install.ps1` / `install.sh` — One-command installer
- `fix.ps1` / `fix.sh` — Auto-fix tool for known issues
- `TROUBLESHOOTING.md` — Issues #1-5 documented
- Provider and model templates
- BSL-1.1 license

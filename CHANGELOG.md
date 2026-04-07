# Changelog

All notable changes to this project will be documented in this file.

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

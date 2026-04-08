# 🦞 Izzi × OpenClaw Connector

Connect [Izzi API](https://izziapi.com) to [OpenClaw](https://tryopenclaw.io) in under 1 minute. Access GPT-5.4, Claude Sonnet 4, Gemini 2.5 Pro, and 30+ models — through a single API key.

## ⚡ Quick Start

### 1. Get your API key
[Sign up](https://izziapi.com/dashboard) and copy your API key from the dashboard.

### 2. Run the installer

**Windows (CMD / Terminal)** ⭐ Recommended
```cmd
git clone https://github.com/kentzu213/izzi-openclaw.git
cd izzi-openclaw
install.bat izzi-YOUR_KEY_HERE
```

**Windows (PowerShell)**
```powershell
git clone https://github.com/kentzu213/izzi-openclaw.git
cd izzi-openclaw
powershell -ExecutionPolicy Bypass -File .\install.ps1 -ApiKey "izzi-YOUR_KEY_HERE"
```

**macOS / Linux**
```bash
git clone https://github.com/kentzu213/izzi-openclaw.git
cd izzi-openclaw
chmod +x install.sh
./install.sh "izzi-YOUR_KEY_HERE"
```

### 3. Restart OpenClaw
Close and reopen OpenClaw. Select `auto · izzi` as your model, and start chatting!

## 📊 Available Models (30+)

The installer automatically configures 12 popular models. All 30+ models are available via `templates/models.json`.

### 🆓 Free / Maintained (no credit cost)
| Model ID | Name | Notes |
|----------|------|-------|
| `auto` | Smart Router | ⭐ Auto-selects best model |
| `qwen3-235b` | Qwen3 235B | Largest free model |
| `llama-3.3-70b` | Llama 3.3 70B | Fast, reliable |
| `nemotron-3-super-free` | Nemotron 3 Super | NVIDIA |
| `devstral-2-free` | Devstral 2 | Code specialist |
| `gemma-3-27b-free` | Gemma 3 27B | Google |

### 💰 Budget (< $1/M tokens)
| Model ID | Name | Input / Output |
|----------|------|----------------|
| `gemini-2.5-flash-lite` | Gemini 2.5 Flash Lite | $0.14 / $0.83 |
| `gpt-4o-mini` | GPT-4o Mini | $0.17 / $0.66 |
| `gpt-5.4-nano` | GPT-5.4 Nano | $0.22 / $1.38 |
| `gemini-2.5-flash` | Gemini 2.5 Flash | $0.33 / $2.75 |
| `gpt-4.1-mini` | GPT-4.1 Mini | $0.44 / $1.76 |
| `gpt-5.4-mini` | GPT-5.4 Mini | $0.83 / $4.95 |

### ⚡ Standard ($1-3/M tokens)
| Model ID | Name | Input / Output |
|----------|------|----------------|
| `REDACTED_MODEL` | GPT-5.1 via 9R 🏷️ | $0.70 / $5.60 |
| `REDACTED_MODEL` | GPT-5.1 Codex via 9R | $0.70 / $5.60 |
| `claude-haiku-4.5` | Claude Haiku 4.5 | $0.88 / $4.40 |
| `gpt-5.1` | GPT-5.1 | $1.10 / $8.80 |
| `gpt-5.1-codex` | GPT-5.1 Codex | $1.10 / $8.80 |
| `o3-mini` | O3 Mini | $1.21 / $4.84 |
| `gpt-4.1` | GPT-4.1 | $2.20 / $8.80 |
| `gpt-4o` | GPT-4o | $2.75 / $11.00 |

> 🏷️ **9R models** = Same premium model at **30% lower price** via 9Router free tier

### 💎 Premium ($3+/M tokens)
| Model ID | Name | Input / Output |
|----------|------|----------------|
| `REDACTED_MODEL` | GPT-5.2 via 9R 🏷️ | $1.23 / $9.80 |
| `REDACTED_MODEL` | GPT-5.4 via 9R 🏷️ | $1.75 / $10.50 |
| `gemini-2.5-pro` | Gemini 2.5 Pro | $1.38 / $11.00 |
| `gpt-5.2` | GPT-5.2 | $1.93 / $15.40 |
| `gpt-5.4` | GPT-5.4 | $2.75 / $16.50 |
| `claude-sonnet-4.5` | Claude Sonnet 4.5 | $3.30 / $16.50 |
| `claude-sonnet-4` | Claude Sonnet 4 | $3.30 / $16.50 |
| `claude-opus-4` | Claude Opus 4 | $5.50 / $27.50 |
| `grok-4` | Grok 4 | $3.30 / $16.50 |

> 💡 **Tip**: Use `izzi/REDACTED_MODEL` instead of `izzi/gpt-5.1` to save 30% — same model, lower price!

## 🛠️ What the installer does

The installer automatically:
- Sets `baseUrl` to `https://api.izziapi.com`
- Injects your API key into OpenClaw config
- Registers 12 popular models in all agent configs
- Removes `/v1` suffix if present (prevents double-prefix bug)
- Tests connectivity to Izzi API
- Restarts OpenClaw gateway

## 🔧 Troubleshooting

Having issues? Run the auto-fix tool:

**Windows (CMD)**
```cmd
fix.bat --diagnose    &:: Report issues only
fix.bat --auto        &:: Fix everything automatically
```

**Windows (PowerShell)**
```powershell
powershell -ExecutionPolicy Bypass -File .\fix.ps1 -Diagnose
powershell -ExecutionPolicy Bypass -File .\fix.ps1 -Auto
```

**macOS / Linux**
```bash
./fix.sh --diagnose   # Report issues only
./fix.sh --auto       # Fix everything automatically
```

### Common Issues
See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for detailed solutions to:
- ❌ `LLM request failed: network connection error` — baseUrl pointing to localhost
- ❌ `404 Upstream` — double `/v1/v1` URL prefix
- ❌ `ERR_TOO_MANY_REDIRECTS` — Cloudflare/Caddy TLS conflict
- ❌ `Model not found` — outdated model IDs
- ❌ Agent config overriding global config
- ❌ Gateway not picking up config changes
- ❌ Provider 503 — missing upstream API keys
- ❌ `cx/` prefix routing failures (9Router models)

### Quick Health Check
```bash
# Test if API is online
curl -s https://api.izziapi.com/health
# Expected: {"status":"ok","timestamp":"..."}

# Test with your API key
curl -s https://api.izziapi.com/v1/models -H "x-api-key: izzi-YOUR_KEY"
```

## 🗑️ Uninstall

**Windows (CMD)**
```cmd
install.bat --uninstall
```

**Windows (PowerShell)**
```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Uninstall
```

**macOS / Linux**
```bash
./install.sh --uninstall
```

## 📁 Project Structure
```
izzi-openclaw/
├── install.bat          # ⭐ Windows CMD installer (recommended)
├── install.ps1          # Windows PowerShell installer
├── install.sh           # macOS/Linux installer
├── fix.bat              # ⭐ Windows CMD auto-fix tool
├── fix.ps1              # Windows PowerShell auto-fix tool
├── fix.sh               # macOS/Linux auto-fix tool
├── templates/
│   ├── openclaw-provider.json  # Provider config (30 models)
│   └── models.json             # Full agent model definitions
├── README.md
├── TROUBLESHOOTING.md   # Known issues & fixes (10 bugs documented)
├── CHANGELOG.md
└── LICENSE              # BSL-1.1
```

## 🔐 Security
- No API keys are stored in this repo — keys are only written to your local OpenClaw config
- Backups created before any config modification (`.bak` files)
- Key validation ensures proper `izzi-` prefix format

## 📄 License
This project is licensed under the [Business Source License 1.1](LICENSE).
- ✅ Free for personal and internal use
- ✅ View and modify the source code
- ❌ Cannot be used to create competing commercial products
- The license converts to Apache 2.0 on 2030-04-04

## 🔗 Links
- Izzi API: [izziapi.com](https://izziapi.com)
- Dashboard: [izziapi.com/dashboard](https://izziapi.com/dashboard)
- Docs: [izziapi.com/docs](https://izziapi.com/docs)
- OpenClaw: [tryopenclaw.io](https://tryopenclaw.io)
- Issues: [GitHub Issues](https://github.com/kentzu213/izzi-openclaw/issues)

---

Made with 🦞 by [izziapi.com](https://izziapi.com)

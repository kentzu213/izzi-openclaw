# 🦞 Izzi × OpenClaw Connector

Connect [Izzi API](https://izziapi.com) to [OpenClaw](https://tryopenclaw.io) in under 1 minute. Access GPT-5.4, GPT-5.2, GPT-5.1 Codex and more — through a single API key.

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

## 📊 Available Models (E2E Verified v4.2)

All models are verified working on production. Use `auto` for best value.

### 💰 Budget
| Model ID | Name | Input / Output |
|----------|------|----------------|
| `auto` | Smart Router v4.2 | ⭐ Auto-selects best model |
| `REDACTED_MODEL` | GPT-5 Mini | $0.35 / $2.80 |
| `REDACTED_MODEL` | GPT-5.1 Mini | $0.44 / $3.50 |

### ⚡ Standard
| Model ID | Name | Input / Output |
|----------|------|----------------|
| `REDACTED_MODEL` | GPT-5.1 | $0.70 / $5.60 |
| `REDACTED_MODEL` | GPT-5.1 Codex | $0.70 / $5.60 |

### 💎 Premium
| Model ID | Name | Input / Output |
|----------|------|----------------|
| `REDACTED_MODEL` | GPT-5.2 | $1.23 / $9.80 |
| `REDACTED_MODEL` | GPT-5.4 | $1.75 / $10.50 |

> 💡 **Tip**: Use `izzi/auto` for best quality-per-dollar — the Smart Router picks the optimal model automatically.

## 🛠️ What the installer does

The installer automatically:
- Fixes PowerShell ExecutionPolicy (prevents PSSecurityException)
- Sets `baseUrl` to `https://api.izziapi.com`
- Injects your API key into OpenClaw config
- Registers 7 verified models in all agent configs
- Removes `/v1` suffix if present (prevents double-prefix bug)
- Tests connectivity to Izzi API
- Restarts OpenClaw gateway
- Optionally sets up auto-start on Windows boot

## 🚀 Auto-Start on Windows Boot

Make OpenClaw gateway start automatically when you log in:

```cmd
startup.bat install      :: Enable auto-start
startup.bat status       :: Check status
startup.bat uninstall    :: Disable auto-start
```

This creates a Windows Task Scheduler task (`OpenClaw-Gateway-AutoStart`) that runs `openclaw gateway start` at user login with a 30-second delay for network initialization.

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
- ❌ `PSSecurityException: UnauthorizedAccess` — ExecutionPolicy blocks scripts (auto-fixed in v2.1)
- ❌ `LLM request failed: network connection error` — baseUrl pointing to localhost
- ❌ `404 Upstream` — double `/v1/v1` URL prefix
- ❌ `ERR_TOO_MANY_REDIRECTS` — Cloudflare/Caddy TLS conflict
- ❌ `Model not found` — outdated model IDs
- ❌ OpenClaw not running after reboot — use `startup.bat install`
- ❌ Agent config overriding global config
- ❌ Gateway not picking up config changes
- ❌ Provider 503 — missing upstream API keys

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
├── startup.bat          # ⭐ Auto-start manager (Windows)
├── startup.ps1          # Task Scheduler automation
├── fix.bat              # Windows CMD auto-fix tool
├── fix.ps1              # Windows PowerShell auto-fix tool
├── fix.sh               # macOS/Linux auto-fix tool
├── templates/
│   ├── openclaw-provider.json  # Provider config
│   └── models.json             # Full agent model definitions (v4.2)
├── README.md
├── TROUBLESHOOTING.md   # Known issues & fixes (13 bugs documented)
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

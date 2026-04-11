# 🦞 Izzi × OpenClaw Connector

Connect [Izzi API](https://izziapi.com) to [OpenClaw](https://tryopenclaw.io) in under 1 minute. Access GPT-5.4, GPT-5.2, GPT-5.1 Codex and more — through a single API key.

> ⚠️ **API key is MANDATORY.** You must have a valid `izzi-` API key before installation. Get one at [izziapi.com/dashboard](https://izziapi.com/dashboard).

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

**macOS / Linux** ⭐ One-liner
```bash
curl -fsSL https://raw.githubusercontent.com/kentzu213/izzi-openclaw/main/install.sh | bash -s -- "izzi-YOUR_KEY_HERE"
```

**macOS / Linux** (manual clone)
```bash
git clone https://github.com/kentzu213/izzi-openclaw.git
cd izzi-openclaw
chmod +x install.sh
./install.sh "izzi-YOUR_KEY_HERE"
```

**VPS / Server (Ubuntu 20.04+)** 🖥️
```bash
curl -fsSL https://raw.githubusercontent.com/kentzu213/izzi-openclaw/main/install-vps.sh | bash -s -- "izzi-YOUR_KEY_HERE"
```
> Auto-installs Node.js, OpenClaw, configures Izzi, and creates a systemd service.

### 3. Restart OpenClaw
Close and reopen OpenClaw. Select `auto · izzi` as your model, and start chatting!

## 📊 Available Models

Models are fetched securely from the server at install time. Use `auto` for best value.

> 💡 **Tip**: Use `izzi/auto` for best quality-per-dollar — the Smart Router picks the optimal model automatically.
>
> Run the installer with your API key to see all available models and pricing for your plan.

## 🔧 Binary Installer (Recommended)

Pre-compiled binaries are available for all platforms — no source code exposure:

```bash
# Download from GitHub releases
# https://github.com/kentzu213/izzi-openclaw/releases/latest

# Then run:
./izzi install izzi-YOUR_API_KEY      # Linux/macOS
izzi.exe install izzi-YOUR_API_KEY    # Windows
```

| Platform | Binary |
|----------|--------|
| Windows x64 | `izzi-installer-windows-amd64.exe` |
| macOS x64 | `izzi-installer-darwin-amd64` |
| macOS ARM (M1/M2) | `izzi-installer-darwin-arm64` |
| Linux x64 | `izzi-installer-linux-amd64` |
| Linux ARM64 | `izzi-installer-linux-arm64` |

### Verify Integrity
```bash
./izzi verify                           # Binary self-check
sha256sum -c SHA256SUMS.txt            # Manual checksum verify
```

## 🛠️ What the installer does

The installer automatically:
- **Verifies API key with server** (BLOCKING — invalid key = abort)
- Fixes PowerShell ExecutionPolicy (prevents PSSecurityException)
- Sets `baseUrl` to `https://api.izziapi.com`
- Injects your API key into OpenClaw config
- Registers 7 verified models in all agent configs
- Removes `/v1` suffix if present (prevents double-prefix bug)
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

## 🖥️ VPS / Server Installation

For headless servers (Ubuntu 20.04+, Debian 11+):

```bash
# Basic install
curl -fsSL https://raw.githubusercontent.com/kentzu213/izzi-openclaw/main/install-vps.sh | bash -s -- "izzi-YOUR_KEY"

# With UFW firewall rules
curl -fsSL https://raw.githubusercontent.com/kentzu213/izzi-openclaw/main/install-vps.sh | bash -s -- "izzi-YOUR_KEY" --with-ufw

# Custom Node.js version + port
./install-vps.sh "izzi-KEY" --node=22 --port=8080
```

The VPS installer automatically:
- Installs Node.js 20 LTS (configurable)
- Installs OpenClaw globally via npm
- Configures Izzi provider with v4.2 verified models
- Creates a **systemd service** (`openclaw-gateway`) for auto-restart
- Optionally configures UFW firewall

### Service Management
```bash
sudo systemctl status openclaw-gateway    # Check status
sudo systemctl restart openclaw-gateway   # Restart
sudo journalctl -u openclaw-gateway -f    # View logs
```

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
├── install.sh           # macOS/Linux desktop installer
├── install-vps.sh       # 🖥️ VPS/Server full installer (Ubuntu/Debian)
├── cli/                 # 🔧 Go binary installer (v3.1.0+)
│   ├── cmd/izzi/        #    Entry point
│   └── internal/        #    Installer + security packages
├── startup.bat          # ⭐ Auto-start manager (Windows)
├── startup.ps1          # Task Scheduler automation
├── fix.bat              # Windows CMD auto-fix tool
├── fix.ps1              # Windows PowerShell auto-fix tool
├── fix.sh               # macOS/Linux auto-fix tool
├── templates/
│   └── README.md        # Server-config notice (no model data)
├── .github/workflows/   # 🔒 Auto release + binary builds
├── .goreleaser.yml      # Cross-platform build config
├── SECURITY.md          # 🔒 Vulnerability reporting
├── SECURITY-RULES.md    # 🔒 Security contract (6 rules)
├── CONTRIBUTING.md      # 📋 CLA + contribution guidelines
├── TRADEMARK.md         # ™ Trademark notice
├── TROUBLESHOOTING.md   # Known issues & fixes
├── CHANGELOG.md
├── .gitattributes       # Line ending enforcement
└── LICENSE              # BSL-1.1
```

## 🔐 Security

- ✅ API key verified with server BEFORE any config write
- ✅ Invalid/expired/revoked keys are rejected immediately
- ✅ No API keys stored in this repo — keys only in local config
- ✅ Installer self-verification (SHA256 checksums)
- ✅ Device fingerprinting for abuse detection
- ✅ Version outdated warnings
- ✅ Compiled binary option to prevent source code exposure
- ❌ No `-Force` bypass for key validation

| Document | Purpose |
|----------|--------|
| [SECURITY.md](SECURITY.md) | 🔒 Vulnerability reporting & response process |
| [SECURITY-RULES.md](SECURITY-RULES.md) | 🔒 Security contract (6 binding rules) |
| [CONTRIBUTING.md](CONTRIBUTING.md) | 📋 CLA + contribution guidelines |
| [TRADEMARK.md](TRADEMARK.md) | ™ Trademark usage guidelines |

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

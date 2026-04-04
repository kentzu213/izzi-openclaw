# 🦞 Izzi × OpenClaw Connector

> Connect [Izzi API](https://izziapi.com) to [OpenClaw](https://tryopenclaw.io) in under 1 minute.  
> Access GPT-5.4, Claude Sonnet 4, Llama 3.3, Qwen3 235B, and more — through a single API key.

[![License: BSL-1.1](https://img.shields.io/badge/license-BSL--1.1-blue.svg)](LICENSE)
[![OpenClaw Compatible](https://img.shields.io/badge/OpenClaw-compatible-brightgreen.svg)](https://tryopenclaw.io)

---

## ⚡ Quickstart

### 1. Get your API key

[Sign up](https://izziapi.com/dashboard) and copy your API key from the dashboard.

### 2. Run the installer

**Windows (CMD / Terminal)**
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

Close and reopen OpenClaw. Select **auto · izzi** as your model, and start chatting!

---

## 📋 What it does

The installer automatically:

| Step | Action |
|------|--------|
| 1 | Detects your OpenClaw installation |
| 2 | Backs up existing configuration |
| 3 | Adds Izzi as an AI provider (global + per-agent) |
| 4 | Sets Smart Router as default model |
| 5 | Applies all known compatibility fixes |
| 6 | Tests API connectivity |
| 7 | Restarts the OpenClaw gateway |

---

## 🤖 Available Models

| Model | Type | Speed |
|-------|------|-------|
| `auto` | Smart Router — auto-selects best model | ⚡⚡⚡ |
| `llama-3.3-70b` | Meta Llama 3.3 70B | ⚡⚡⚡ |
| `qwen3-235b` | Alibaba Qwen3 235B | ⚡⚡ |
| `deepseek-r1-free` | DeepSeek R1 (reasoning) | ⚡⚡ |
| `llama-3.1-8b` | Meta Llama 3.1 8B (fast) | ⚡⚡⚡⚡ |
| `claude-sonnet-4` | Anthropic Claude Sonnet 4 | ⚡⚡ |
| `gpt-5.4` | OpenAI GPT-5.4 | ⚡⚡ |

---

## 🔧 Troubleshooting

Having issues? Run the auto-fix tool:

**Windows (CMD)**
```cmd
fix.bat --diagnose     &:: Report issues only
fix.bat --auto         &:: Fix everything automatically
```

**Windows (PowerShell)**
```powershell
powershell -ExecutionPolicy Bypass -File .\fix.ps1 -Diagnose
powershell -ExecutionPolicy Bypass -File .\fix.ps1 -Auto
```

**macOS / Linux**
```bash
./fix.sh --diagnose    # Report issues only
./fix.sh --auto        # Fix everything automatically
```

### Common Issues

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for detailed solutions to:

- ❌ `404 Upstream` errors
- ❌ Double `/v1/v1` URL prefix
- ❌ Agent config overriding global config
- ❌ Stale model names on OpenRouter
- ❌ Gateway not picking up config changes

---

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

---

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
│   ├── openclaw-provider.json    # Provider config template
│   └── models.json               # Agent model definitions
├── README.md            # This file
├── TROUBLESHOOTING.md   # Known issues & fixes
└── LICENSE              # BSL-1.1
```

---

## 🔐 Security

- **No API keys are stored in this repo** — keys are only written to your local OpenClaw config
- **Backups created** before any config modification (`.bak` files)
- **Key validation** ensures proper `izzi-` prefix format

---

## 📄 License

This project is licensed under the [Business Source License 1.1](LICENSE).

- ✅ Free for personal and internal use
- ✅ View and modify the source code
- ❌ Cannot be used to create competing commercial products
- The license converts to Apache 2.0 on 2030-04-04

---

## 🔗 Links

- **Izzi API**: [izziapi.com](https://izziapi.com)
- **Dashboard**: [izziapi.com/dashboard](https://izziapi.com/dashboard)
- **Docs**: [izziapi.com/docs](https://izziapi.com/docs)
- **OpenClaw**: [tryopenclaw.io](https://tryopenclaw.io)
- **Issues**: [GitHub Issues](https://github.com/kentzu213/izzi-openclaw/issues)

---

<p align="center">
  Made with 🦞 by <a href="https://izziapi.com">izziapi.com</a>
</p>

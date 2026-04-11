#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# Izzi × OpenClaw Connector — VPS Ubuntu Installer v3.0.0
#
# Full headless installer for VPS/server environments.
# Installs Node.js, OpenClaw, configures Izzi provider,
# and creates a systemd service for auto-restart.
#
# Model configs are fetched from the Izzi API server at install time.
# This script does NOT contain model IDs, pricing, or architecture details.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/kentzu213/izzi-openclaw/main/install-vps.sh | bash -s -- "izzi-YOUR_KEY"
#   ./install-vps.sh "izzi-YOUR_API_KEY"
#   ./install-vps.sh "izzi-YOUR_API_KEY" --with-ufw
#
# Requirements: Ubuntu 20.04+ / Debian 11+ (amd64 or arm64)
# ─────────────────────────────────────────────────────────────
set -e

VERSION="3.0.0"
BASE_URL="https://api.izziapi.com"
API_KEY=""
WITH_UFW=false
NODE_MAJOR=20
GATEWAY_PORT=3000

# ─── Parse args ───
for arg in "$@"; do
  case "$arg" in
    --with-ufw)       WITH_UFW=true ;;
    --base-url=*)     BASE_URL="${arg#*=}" ;;
    --port=*)         GATEWAY_PORT="${arg#*=}" ;;
    --node=*)         NODE_MAJOR="${arg#*=}" ;;
    *)                [ -z "$API_KEY" ] && API_KEY="$arg" ;;
  esac
done

OC_DIR="$HOME/.openclaw"
OC_CONFIG="$OC_DIR/openclaw.json"

# ─── Helpers ───
banner() {
  echo ""
  echo "  ╔══════════════════════════════════════════════╗"
  echo "  ║  🦞 Izzi × OpenClaw VPS Installer v$VERSION   ║"
  echo "  ╚══════════════════════════════════════════════╝"
  echo ""
}

step()  { echo "  [$1/$2] $3"; }
ok()    { echo "    ✓ $1"; }
warn()  { echo "    ⚠ $1"; }
err()   { echo "    ✗ $1"; }

need_sudo() {
  if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
      echo "sudo"
    else
      err "This step requires root access. Run as root or install sudo."
      exit 1
    fi
  else
    echo ""
  fi
}

backup_file() {
  [ -f "$1" ] && cp "$1" "${1}.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
}

# ─── Pre-flight ───
banner

# Check OS
if [ ! -f /etc/os-release ]; then
  err "Cannot detect OS. This installer requires Ubuntu 20.04+ or Debian 11+."
  exit 1
fi

. /etc/os-release
echo "  OS: $PRETTY_NAME"
echo "  Arch: $(uname -m)"
echo ""

# ═══════════════════════════════════════════════════════
# SECURITY GATE: Mandatory API Key Validation
# See SECURITY-RULES.md — Rules #1, #2, #4
# This block MUST NOT be removed or made optional.
# ═══════════════════════════════════════════════════════

# Step A: Get API key if not provided
if [ -z "$API_KEY" ]; then
  printf "  Enter your Izzi API key: "
  if [ -t 0 ]; then
    read -r API_KEY
  else
    read -r API_KEY < /dev/tty 2>/dev/null || true
  fi

  if [ -z "$API_KEY" ]; then
    echo ""
    err "No API key provided."
    echo "  Get your key at: https://izziapi.com/dashboard"
    echo ""
    exit 1
  fi
  echo ""
fi

# Check 1: Reject placeholder
if [ "$API_KEY" = "YOUR_IZZI_API_KEY" ]; then
  err "Invalid placeholder key. Get a real key at: https://izziapi.com/dashboard"
  exit 1
fi

# Check 2: Must start with izzi-
case "$API_KEY" in
  izzi-*) ;;
  *)
    err "API key must start with 'izzi-'. Get your key at: https://izziapi.com/dashboard"
    exit 1
    ;;
esac

# Check 3: Minimum length (izzi- + 43 hex = 48 chars)
KEY_LEN=${#API_KEY}
if [ "$KEY_LEN" -lt 48 ]; then
  err "API key too short ($KEY_LEN chars, need 48+). Check your key at: https://izziapi.com/dashboard"
  exit 1
fi

# Check 4: BLOCKING server verification (SECURITY-RULES.md Rule #1)
echo "  Verifying API key with server..."
if command -v curl >/dev/null 2>&1; then
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "x-api-key: $API_KEY" \
    -H "Content-Type: application/json" \
    "$BASE_URL/v1/models" 2>/dev/null || echo "000")

  if [ "$HTTP_CODE" = "200" ]; then
    ok "API key verified (HTTP 200)"
  elif [ "$HTTP_CODE" = "401" ]; then
    err "API key is INVALID (server returned 401). Check your key at: https://izziapi.com/dashboard"
    echo ""
    echo "  Installation ABORTED. No changes were made to your system."
    echo ""
    exit 1
  elif [ "$HTTP_CODE" = "403" ]; then
    err "API key is REVOKED (server returned 403). Create new key at: https://izziapi.com/dashboard"
    echo ""
    echo "  Installation ABORTED. No changes were made to your system."
    echo ""
    exit 1
  else
    err "Cannot verify API key (HTTP $HTTP_CODE). Check network and try again."
    echo ""
    echo "  Installation ABORTED. No changes were made to your system."
    echo ""
    exit 1
  fi
else
  err "curl not found — cannot verify API key. Install curl first: sudo apt install curl"
  exit 1
fi

# ═════════════════════════
# END SECURITY GATE
# ═════════════════════════

echo "  Base URL: $BASE_URL"
echo "  API Key:  ${API_KEY:0:16}..."
echo ""

TOTAL=7
SUDO_CMD=$(need_sudo)

# ─── Step 1: Install system dependencies ───
step 1 $TOTAL "Installing system dependencies..."

NEEDED_PKGS=""
for pkg in curl git jq; do
  if ! command -v "$pkg" >/dev/null 2>&1; then
    NEEDED_PKGS="$NEEDED_PKGS $pkg"
  fi
done

if [ -n "$NEEDED_PKGS" ]; then
  $SUDO_CMD apt-get update -qq >/dev/null 2>&1
  $SUDO_CMD apt-get install -y -qq $NEEDED_PKGS >/dev/null 2>&1
  ok "Installed:$NEEDED_PKGS"
else
  ok "All dependencies present (curl, git, jq)"
fi

# ─── Step 2: Install Node.js ───
step 2 $TOTAL "Setting up Node.js $NODE_MAJOR LTS..."

if command -v node >/dev/null 2>&1; then
  CURRENT_NODE=$(node -v 2>/dev/null | sed 's/v//' | cut -d. -f1)
  if [ "$CURRENT_NODE" -ge "$NODE_MAJOR" ] 2>/dev/null; then
    ok "Node.js $(node -v) already installed (>= $NODE_MAJOR)"
  else
    warn "Node.js $(node -v) found but need v$NODE_MAJOR+. Upgrading..."
    # Install via NodeSource
    $SUDO_CMD mkdir -p /etc/apt/keyrings
    curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | $SUDO_CMD bash - >/dev/null 2>&1
    $SUDO_CMD apt-get install -y -qq nodejs >/dev/null 2>&1
    ok "Upgraded to Node.js $(node -v)"
  fi
else
  echo "    Installing Node.js $NODE_MAJOR LTS via NodeSource..."
  $SUDO_CMD mkdir -p /etc/apt/keyrings
  curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | $SUDO_CMD bash - >/dev/null 2>&1
  $SUDO_CMD apt-get install -y -qq nodejs >/dev/null 2>&1
  ok "Installed Node.js $(node -v)"
fi

# Verify npm
if ! command -v npm >/dev/null 2>&1; then
  err "npm not found after Node.js install. Aborting."
  exit 1
fi
ok "npm $(npm -v)"

# ─── Step 3: Install OpenClaw ───
step 3 $TOTAL "Installing OpenClaw..."

if command -v openclaw >/dev/null 2>&1; then
  OC_VER=$(openclaw --version 2>/dev/null || echo "unknown")
  ok "OpenClaw already installed ($OC_VER)"
else
  echo "    Installing openclaw globally via npm..."
  npm install -g openclaw >/dev/null 2>&1 || $SUDO_CMD npm install -g openclaw >/dev/null 2>&1
  ok "OpenClaw installed ($(openclaw --version 2>/dev/null || echo 'OK'))"
fi

# Run setup if needed
if [ ! -d "$OC_DIR" ]; then
  echo "    Running openclaw setup..."
  openclaw setup --non-interactive 2>/dev/null || openclaw setup 2>/dev/null || true
fi

if [ ! -d "$OC_DIR" ]; then
  # Manual setup fallback
  mkdir -p "$OC_DIR"
  cat > "$OC_CONFIG" << 'INITJSON'
{
  "models": {
    "providers": {}
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "izzi/auto"
      }
    }
  },
  "gateway": {
    "mode": "local"
  }
}
INITJSON
  ok "Created minimal openclaw.json"
fi

ok "OpenClaw directory: $OC_DIR"

# ═════════════════════════════════════════════════════════
# PROVISION: Fetch config from server
# Model definitions and pricing are NOT stored in this script.
# They are fetched securely from the Izzi API at install time.
# ═════════════════════════════════════════════════════════
# Generate device fingerprint for security tracking
DEVICE_ID="unknown"
if command -v sha256sum >/dev/null 2>&1; then
  DEVICE_ID=$(echo -n "$(hostname)" | sha256sum | cut -c1-16)
elif command -v shasum >/dev/null 2>&1; then
  DEVICE_ID=$(echo -n "$(hostname)" | shasum -a 256 | cut -c1-16)
fi

echo "  Fetching configuration from server..."
PROVISION_JSON=""
PROVISION_JSON=$(curl -s -X POST \
  -H "x-api-key: $API_KEY" \
  -H "Content-Type: application/json" \
  -H "User-Agent: izzi-installer/$VERSION (bash-vps)" \
  -H "X-Installer-Version: $VERSION" \
  -H "X-Platform: $(uname -s | tr '[:upper:]' '[:lower:]')-vps" \
  -H "X-Device-ID: $DEVICE_ID" \
  -d "{\"installer_version\":\"$VERSION\",\"platform\":\"$(uname -s | tr '[:upper:]' '[:lower:]')-vps\"}" \
  "$BASE_URL/v1/provision" 2>/dev/null || echo "")

# Check if provision succeeded
PROVISION_OK=false
if [ -n "$PROVISION_JSON" ] && echo "$PROVISION_JSON" | grep -q '"provider"' 2>/dev/null; then
  MODEL_COUNT=$(echo "$PROVISION_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('agent_models',[])))" 2>/dev/null || echo "0")
  ok "Configuration received ($MODEL_COUNT models)"
  PROVISION_OK=true

  # Handle server warnings (Phase 2: abuse detection feedback)
  WARNINGS=$(echo "$PROVISION_JSON" | python3 -c "
import sys,json
d=json.load(sys.stdin)
for w in d.get('warnings',[]):
    print('    ⚠ ' + w)
" 2>/dev/null || true)
  [ -n "$WARNINGS" ] && echo "$WARNINGS"
else
  warn "Could not fetch config from server. Using fallback mode..."
fi

# ═════════════════════════════════════════════════════════
# INTEGRITY CHECK: Verify this installer hasn't been tampered
# Phase 3 Security: SHA256 self-verification against server checksums
# ═════════════════════════════════════════════════════════

if [ "$PROVISION_OK" = true ]; then
  SELF_HASH=""
  if [ -f "$0" ]; then
    if command -v sha256sum >/dev/null 2>&1; then
      SELF_HASH=$(sha256sum "$0" | cut -d' ' -f1)
    elif command -v shasum >/dev/null 2>&1; then
      SELF_HASH=$(shasum -a 256 "$0" | cut -d' ' -f1)
    fi
  fi

  if [ -n "$SELF_HASH" ]; then
    SERVER_HASH=$(echo "$PROVISION_JSON" | python3 -c "
import sys,json
d=json.load(sys.stdin)
print(d.get('checksums',{}).get('install-vps.sh',''))
" 2>/dev/null || echo "")

    if [ -n "$SERVER_HASH" ]; then
      if [ "$SELF_HASH" = "$SERVER_HASH" ]; then
        ok "Installer integrity verified (SHA256 match)"
      else
        warn "Installer checksum mismatch! This file may have been modified."
        echo "    Expected: $SERVER_HASH"
        echo "    Actual:   $SELF_HASH"
        echo "    Download official: https://github.com/kentzu213/izzi-openclaw/releases/latest"
        echo ""
      fi
    fi
  fi

  LATEST_VER=$(echo "$PROVISION_JSON" | python3 -c "
import sys,json
d=json.load(sys.stdin)
print(d.get('installer_latest',''))
" 2>/dev/null || echo "")

  if [ -n "$LATEST_VER" ] && [ "$LATEST_VER" != "$VERSION" ]; then
    warn "Installer v$VERSION is outdated. Latest: v$LATEST_VER"
    echo "    Download latest: https://github.com/kentzu213/izzi-openclaw/releases/latest"
    echo ""
  fi
fi

# ─── Step 4: Configure Izzi provider ───
step 4 $TOTAL "Configuring Izzi provider..."

if [ -f "$OC_CONFIG" ]; then
  backup_file "$OC_CONFIG"

  if command -v python3 >/dev/null 2>&1; then
    if [ "$PROVISION_OK" = true ]; then
      # Use server-provided config
      python3 -c "
import json
with open('$OC_CONFIG', 'r') as f: data = json.load(f)
provision = json.loads('''$PROVISION_JSON''')
provider_cfg = provision.get('provider', {})
provider_cfg['apiKey'] = '$API_KEY'
provider_cfg['baseUrl'] = '$BASE_URL'
if 'models' not in data: data['models'] = {}
if 'providers' not in data['models']: data['models']['providers'] = {}
data['models']['providers']['izzi'] = provider_cfg
if 'agents' in data and 'defaults' in data['agents']:
    if 'model' not in data['agents']['defaults']:
        data['agents']['defaults']['model'] = {}
    data['agents']['defaults']['model']['primary'] = 'izzi/auto'
with open('$OC_CONFIG', 'w') as f:
    json.dump(data, f, indent=2); f.write('\n')
print('    ✓ Added izzi provider + set default to izzi/auto')
" 2>/dev/null || warn "python3 failed — trying jq..."
    else
      # Fallback: minimal auto-only config
      python3 -c "
import json
with open('$OC_CONFIG', 'r') as f: data = json.load(f)
provider = {'baseUrl':'$BASE_URL','api':'openai-completions','apiKey':'$API_KEY','models':[{'id':'auto','name':'Smart Router (Auto)'}]}
if 'models' not in data: data['models'] = {}
if 'providers' not in data['models']: data['models']['providers'] = {}
data['models']['providers']['izzi'] = provider
if 'agents' in data and 'defaults' in data['agents']:
    if 'model' not in data['agents']['defaults']:
        data['agents']['defaults']['model'] = {}
    data['agents']['defaults']['model']['primary'] = 'izzi/auto'
with open('$OC_CONFIG', 'w') as f:
    json.dump(data, f, indent=2); f.write('\n')
print('    ✓ Added izzi provider (fallback mode)')
" 2>/dev/null || warn "python3 failed"
    fi
  fi

  # jq fallback
  if ! grep -q '"izzi"' "$OC_CONFIG" 2>/dev/null && command -v jq >/dev/null 2>&1; then
    TMP_CONFIG=$(mktemp)
    FALLBACK_PROVIDER="{\"baseUrl\":\"$BASE_URL\",\"api\":\"openai-completions\",\"apiKey\":\"$API_KEY\",\"models\":[{\"id\":\"auto\",\"name\":\"Smart Router (Auto)\"}]}"
    jq --argjson provider "$FALLBACK_PROVIDER" \
      '.models.providers.izzi = $provider | .agents.defaults.model.primary = "izzi/auto"' \
      "$OC_CONFIG" > "$TMP_CONFIG" 2>/dev/null && mv "$TMP_CONFIG" "$OC_CONFIG"
    ok "Added izzi provider via jq (fallback)"
  fi
else
  warn "openclaw.json not found — creating..."
  mkdir -p "$OC_DIR"
  FALLBACK_PROVIDER="{\"baseUrl\":\"$BASE_URL\",\"api\":\"openai-completions\",\"apiKey\":\"$API_KEY\",\"models\":[{\"id\":\"auto\",\"name\":\"Smart Router (Auto)\"}]}"
  cat > "$OC_CONFIG" << NEWCONF
{
  "models": {
    "providers": {
      "izzi": $FALLBACK_PROVIDER
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "izzi/auto"
      }
    }
  },
  "gateway": {
    "mode": "local"
  }
}
NEWCONF
  ok "Created openclaw.json with izzi provider"
fi

# Update agent configs if they exist
if [ -d "$OC_DIR/agents" ]; then
  find "$OC_DIR/agents" -name "models.json" -path "*/agent/*" 2>/dev/null | while read -r f; do
    backup_file "$f"
    if command -v python3 >/dev/null 2>&1; then
      if [ "$PROVISION_OK" = true ]; then
        python3 -c "
import json
with open('$f', 'r') as fh: data = json.load(fh)
provision = json.loads('''$PROVISION_JSON''')
agent_models = provision.get('agent_models', [])
data.setdefault('providers', {})['izzi'] = {'baseUrl':'$BASE_URL','apiKey':'$API_KEY','api':'openai-completions','models':agent_models}
with open('$f', 'w') as fh:
    json.dump(data, fh, indent=2); fh.write('\n')
" 2>/dev/null && ok "$(basename $(dirname $(dirname "$f")))/agent/models.json"
      else
        python3 -c "
import json
with open('$f', 'r') as fh: data = json.load(fh)
auto_model = {'id':'auto','name':'Smart Router (Auto)','reasoning':False,'input':['text'],'cost':{'input':0,'output':0,'cacheRead':0,'cacheWrite':0},'contextWindow':200000,'maxTokens':8192,'api':'openai-completions'}
data.setdefault('providers', {})['izzi'] = {'baseUrl':'$BASE_URL','apiKey':'$API_KEY','api':'openai-completions','models':[auto_model]}
with open('$f', 'w') as fh:
    json.dump(data, fh, indent=2); fh.write('\n')
" 2>/dev/null && ok "$(basename $(dirname $(dirname "$f")))/agent/models.json (fallback)"
      fi
    fi
  done
fi

# ─── Step 5: Apply compatibility fixes ───
step 5 $TOTAL "Applying compatibility fixes..."

FIXES=0
find "$OC_DIR" -name "*.json" \( -name "openclaw.json" -o -name "models.json" \) 2>/dev/null | while read -r f; do
  if grep -q '/v1"' "$f" 2>/dev/null; then
    sed -i 's|/v1"||g' "$f" 2>/dev/null
    ok "Fixed: removed /v1 suffix in $(basename "$f")"
    FIXES=$((FIXES + 1))
  fi
done

if [ "$FIXES" -eq 0 ] 2>/dev/null; then
  ok "No URL fixes needed"
fi

# ─── Step 6: Create systemd service ───
step 6 $TOTAL "Creating systemd service..."

SERVICE_NAME="openclaw-gateway"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
CURRENT_USER=$(whoami)
NODE_PATH=$(which node 2>/dev/null || echo "/usr/bin/node")
OC_PATH=$(which openclaw 2>/dev/null || echo "$(npm root -g)/openclaw/bin/openclaw")
NPM_GLOBAL_BIN=$(npm bin -g 2>/dev/null || dirname "$NODE_PATH")

# Find real openclaw binary path
if command -v openclaw >/dev/null 2>&1; then
  OC_BIN=$(command -v openclaw)
else
  OC_BIN="$NPM_GLOBAL_BIN/openclaw"
fi

SERVICE_CONTENT="[Unit]
Description=OpenClaw Gateway (Izzi API) — izzi-openclaw v$VERSION
Documentation=https://github.com/kentzu213/izzi-openclaw
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$CURRENT_USER
WorkingDirectory=$HOME
ExecStart=$OC_BIN gateway start
ExecReload=$OC_BIN gateway restart
Restart=on-failure
RestartSec=10
StartLimitBurst=5
StartLimitIntervalSec=60

# Environment
Environment=NODE_ENV=production
Environment=HOME=$HOME
Environment=PATH=$NPM_GLOBAL_BIN:/usr/local/bin:/usr/bin:/bin

# Hardening
NoNewPrivileges=true
ProtectSystem=strict
ReadWritePaths=$OC_DIR $HOME/.npm $HOME/.config
ProtectHome=false

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=$SERVICE_NAME

[Install]
WantedBy=multi-user.target
"

if [ -f "$SERVICE_FILE" ]; then
  ok "Service file already exists — updating..."
fi

echo "$SERVICE_CONTENT" | $SUDO_CMD tee "$SERVICE_FILE" >/dev/null 2>&1
$SUDO_CMD systemctl daemon-reload 2>/dev/null
$SUDO_CMD systemctl enable "$SERVICE_NAME" 2>/dev/null
ok "Created $SERVICE_FILE"
ok "Service enabled (auto-start on boot)"

# Start the service
$SUDO_CMD systemctl restart "$SERVICE_NAME" 2>/dev/null || true
sleep 2

if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
  ok "Service is running ✓"
else
  warn "Service may not have started — check: sudo journalctl -u $SERVICE_NAME -n 20"
fi

# ─── Step 7: UFW Firewall (optional) ───
step 7 $TOTAL "Configuring firewall..."

if [ "$WITH_UFW" = true ]; then
  if command -v ufw >/dev/null 2>&1; then
    # Allow SSH (prevent lockout!)
    $SUDO_CMD ufw allow ssh >/dev/null 2>&1
    # Block external access to OpenClaw gateway port
    $SUDO_CMD ufw deny "$GATEWAY_PORT" >/dev/null 2>&1
    # Enable UFW if not active
    if ! $SUDO_CMD ufw status | grep -q "active" 2>/dev/null; then
      echo "y" | $SUDO_CMD ufw enable >/dev/null 2>&1
    fi
    ok "UFW: SSH allowed, port $GATEWAY_PORT blocked from external"
    ok "Gateway only accessible via localhost"
  else
    warn "UFW not installed. Run: sudo apt install ufw"
  fi
else
  ok "Skipped (use --with-ufw to enable)"
fi

# ─── Done ───
echo ""
echo "  ════════════════════════════════════════════════"
echo "  ✅ VPS Installation complete! (v$VERSION)"
echo ""
echo "  ┌─────────────────────────────────────────────┐"
echo "  │ Service Commands:                           │"
echo "  │                                             │"
echo "  │  sudo systemctl status $SERVICE_NAME   │"
echo "  │  sudo systemctl restart $SERVICE_NAME  │"
echo "  │  sudo journalctl -u $SERVICE_NAME -f   │"
echo "  │                                             │"
echo "  │ Quick Test:                                 │"
echo "  │                                             │"
echo "  │  curl -s http://localhost:$GATEWAY_PORT/health     │"
echo "  │                                             │"
echo "  │ Dashboard: https://izziapi.com/dashboard    │"
echo "  │ Docs:      https://izziapi.com/docs         │"
echo "  │ Issues:    github.com/kentzu213/izzi-openclaw│"
echo "  └─────────────────────────────────────────────┘"
echo ""

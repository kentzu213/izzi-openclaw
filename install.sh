#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# Izzi × OpenClaw Connector — macOS/Linux Installer v3.0.0
# Usage:
#   ./install.sh "izzi-YOUR_API_KEY"
#   curl -fsSL https://raw.githubusercontent.com/.../install.sh | bash -s -- "izzi-KEY"
#
# Model configs are fetched from the Izzi API server at install time.
# This script does NOT contain model IDs, pricing, or architecture details.
# ─────────────────────────────────────────────────────────────
set -e

VERSION="3.0.0"
BASE_URL="https://api.izziapi.com"
API_KEY=""
ACTION="install"
SKIP_RESTART=false

# ─── Parse args ───
for arg in "$@"; do
  case "$arg" in
    --uninstall)    ACTION="uninstall" ;;
    --skip-restart) SKIP_RESTART=true ;;
    --base-url=*)   BASE_URL="${arg#*=}" ;;
    *)              [ -z "$API_KEY" ] && API_KEY="$arg" ;;
  esac
done

OC_DIR="$HOME/.openclaw"
OC_CONFIG="$OC_DIR/openclaw.json"

# ─── Helpers ───
banner() {
  echo ""
  echo "  ╔══════════════════════════════════════════╗"
  echo "  ║     🦞 Izzi × OpenClaw Connector v$VERSION  ║"
  echo "  ╚══════════════════════════════════════════╝"
  echo ""
}

step()  { echo "  [$1/$2] $3"; }
ok()    { echo "    ✓ $1"; }
warn()  { echo "    ⚠ $1"; }
err()   { echo "    ✗ $1"; }

backup_file() {
  [ -f "$1" ] && cp "$1" "${1}.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
}

# ─── Pre-flight ───
banner

if [ ! -d "$OC_DIR" ]; then
  echo "  ❌ OpenClaw not found at $OC_DIR"
  echo ""
  echo "  Install OpenClaw first:"
  echo "    npm install -g openclaw"
  echo "    openclaw setup"
  echo ""
  exit 1
fi

echo "  Status: 🟢 OpenClaw found at $OC_DIR"
echo ""

# ─── Uninstall ───
if [ "$ACTION" = "uninstall" ]; then
  echo "  ╔══════════════════════════════════════════╗"
  echo "  ║       🗑️  Izzi Provider Uninstaller      ║"
  echo "  ╚══════════════════════════════════════════╝"
  echo ""

  step 1 3 "Cleaning openclaw.json..."
  if [ -f "$OC_CONFIG" ] && command -v python3 >/dev/null 2>&1; then
    backup_file "$OC_CONFIG"
    python3 -c "
import json
with open('$OC_CONFIG', 'r') as f: data = json.load(f)
if 'models' in data and 'providers' in data['models']:
    data['models']['providers'].pop('izzi', None)
with open('$OC_CONFIG', 'w') as f:
    json.dump(data, f, indent=2); f.write('\n')
print('    ✓ Removed izzi from openclaw.json')
" 2>/dev/null || warn "Could not clean openclaw.json"
  elif [ -f "$OC_CONFIG" ] && command -v node >/dev/null 2>&1; then
    backup_file "$OC_CONFIG"
    node -e "
const fs = require('fs');
const data = JSON.parse(fs.readFileSync('$OC_CONFIG', 'utf8'));
if (data.models?.providers?.izzi) delete data.models.providers.izzi;
fs.writeFileSync('$OC_CONFIG', JSON.stringify(data, null, 2) + '\n');
console.log('    ✓ Removed izzi from openclaw.json');
" 2>/dev/null || warn "Could not clean openclaw.json"
  fi

  step 2 3 "Cleaning agent configs..."
  find "$OC_DIR/agents" -name "models.json" -path "*/agent/*" 2>/dev/null | while read -r f; do
    if grep -q '"izzi"' "$f" 2>/dev/null; then
      backup_file "$f"
      if command -v python3 >/dev/null 2>&1; then
        python3 -c "
import json
with open('$f', 'r') as fh: data = json.load(fh)
data.get('providers', {}).pop('izzi', None)
with open('$f', 'w') as fh:
    json.dump(data, fh, indent=2); fh.write('\n')
" 2>/dev/null && ok "Cleaned $(basename $(dirname $(dirname "$f")))/agent/models.json"
      fi
    fi
  done

  step 3 3 "Restarting gateway..."
  openclaw gateway restart 2>/dev/null || true
  ok "Done"

  echo ""
  echo "  ✅ Izzi provider removed from OpenClaw!"
  echo ""
  exit 0
fi

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
    echo "  Installation ABORTED. No config files were modified."
    echo ""
    exit 1
  elif [ "$HTTP_CODE" = "403" ]; then
    err "API key is REVOKED (server returned 403). Create new key at: https://izziapi.com/dashboard"
    echo ""
    echo "  Installation ABORTED. No config files were modified."
    echo ""
    exit 1
  else
    err "Cannot verify API key (HTTP $HTTP_CODE). Check network and try again."
    echo ""
    echo "  Installation ABORTED. No config files were modified."
    echo ""
    exit 1
  fi
else
  err "curl not found — cannot verify API key. Install curl first."
  exit 1
fi

# ═════════════════════════
# END SECURITY GATE
# ═════════════════════════

echo "  Base URL: $BASE_URL"
echo "  API Key:  ${API_KEY:0:16}..."
echo ""

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
if command -v curl >/dev/null 2>&1; then
  PROVISION_JSON=$(curl -s -X POST \
    -H "x-api-key: $API_KEY" \
    -H "Content-Type: application/json" \
    -H "User-Agent: izzi-installer/$VERSION (bash)" \
    -H "X-Installer-Version: $VERSION" \
    -H "X-Platform: $(uname -s | tr '[:upper:]' '[:lower:]')" \
    -H "X-Device-ID: $DEVICE_ID" \
    -d "{\"installer_version\":\"$VERSION\",\"platform\":\"$(uname -s | tr '[:upper:]' '[:lower:]')\"}" \
    "$BASE_URL/v1/provision" 2>/dev/null || echo "")
fi

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
  # Self-checksum verification
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
print(d.get('checksums',{}).get('install.sh',''))
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

  # Version check: warn if installer is outdated
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

TOTAL=4

# ─── Step 1: Update openclaw.json ───

step 1 $TOTAL "Updating openclaw.json..."

if [ -f "$OC_CONFIG" ]; then
  backup_file "$OC_CONFIG"

  if command -v python3 >/dev/null 2>&1; then
    if [ "$PROVISION_OK" = true ]; then
      # Use server-provided config
      python3 -c "
import json, sys
with open('$OC_CONFIG', 'r') as f: data = json.load(f)
provision = json.loads('''$PROVISION_JSON''')
provider_cfg = provision.get('provider', {})
provider_cfg['apiKey'] = '$API_KEY'
provider_cfg['baseUrl'] = '$BASE_URL'
if 'models' not in data: data['models'] = {}
if 'providers' not in data['models']: data['models']['providers'] = {}
data['models']['providers']['izzi'] = provider_cfg
if 'agents' in data and 'defaults' in data['agents'] and 'model' in data['agents']['defaults']:
    data['agents']['defaults']['model']['primary'] = 'izzi/auto'
with open('$OC_CONFIG', 'w') as f:
    json.dump(data, f, indent=2); f.write('\n')
print('    ✓ Added izzi provider + set default to izzi/auto')
" 2>/dev/null || warn "python3 failed — trying node..."
    else
      # Fallback: minimal auto-only config
      python3 -c "
import json
with open('$OC_CONFIG', 'r') as f: data = json.load(f)
provider = {'baseUrl':'$BASE_URL','api':'openai-completions','apiKey':'$API_KEY','models':[{'id':'auto','name':'Smart Router (Auto)'}]}
if 'models' not in data: data['models'] = {}
if 'providers' not in data['models']: data['models']['providers'] = {}
data['models']['providers']['izzi'] = provider
if 'agents' in data and 'defaults' in data['agents'] and 'model' in data['agents']['defaults']:
    data['agents']['defaults']['model']['primary'] = 'izzi/auto'
with open('$OC_CONFIG', 'w') as f:
    json.dump(data, f, indent=2); f.write('\n')
print('    ✓ Added izzi provider (fallback mode)')
" 2>/dev/null || warn "python3 failed"
    fi
  fi

  if command -v node >/dev/null 2>&1 && ! grep -q '"izzi"' "$OC_CONFIG" 2>/dev/null; then
    if [ "$PROVISION_OK" = true ]; then
      node -e "
const fs = require('fs');
const data = JSON.parse(fs.readFileSync('$OC_CONFIG', 'utf8'));
const provision = JSON.parse(\`$PROVISION_JSON\`);
const provider = provision.provider || {};
provider.apiKey = '$API_KEY';
provider.baseUrl = '$BASE_URL';
if (!data.models) data.models = {};
if (!data.models.providers) data.models.providers = {};
data.models.providers.izzi = provider;
if (data.agents?.defaults?.model) data.agents.defaults.model.primary = 'izzi/auto';
fs.writeFileSync('$OC_CONFIG', JSON.stringify(data, null, 2) + '\n');
console.log('    ✓ Added izzi provider + set default to izzi/auto');
" 2>/dev/null || warn "Could not update openclaw.json"
    else
      node -e "
const fs = require('fs');
const data = JSON.parse(fs.readFileSync('$OC_CONFIG', 'utf8'));
const provider = {baseUrl:'$BASE_URL',api:'openai-completions',apiKey:'$API_KEY',models:[{id:'auto',name:'Smart Router (Auto)'}]};
if (!data.models) data.models = {};
if (!data.models.providers) data.models.providers = {};
data.models.providers.izzi = provider;
if (data.agents?.defaults?.model) data.agents.defaults.model.primary = 'izzi/auto';
fs.writeFileSync('$OC_CONFIG', JSON.stringify(data, null, 2) + '\n');
console.log('    ✓ Added izzi provider (fallback mode)');
" 2>/dev/null || warn "Could not update openclaw.json"
    fi
  fi
else
  warn "openclaw.json not found — run 'openclaw setup' first"
fi

# ─── Step 2: Update agent configs ───
step 2 $TOTAL "Updating agent configs..."

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

# ─── Step 3: Apply compatibility fixes ───
step 3 $TOTAL "Applying compatibility fixes..."

find "$OC_DIR" -name "*.json" \( -name "openclaw.json" -o -name "models.json" \) 2>/dev/null | while read -r f; do
  if grep -q '/v1"' "$f" 2>/dev/null; then
    sed -i.tmp 's|/v1"||g' "$f" 2>/dev/null || sed -i '' 's|/v1"||g' "$f" 2>/dev/null
    rm -f "${f}.tmp"
    ok "Fixed: removed /v1 suffix in $(basename "$f")"
  fi
done

# ─── Step 4: Restart ───
step 4 $TOTAL "Restarting OpenClaw gateway..."

if [ "$SKIP_RESTART" = false ]; then
  openclaw gateway restart 2>/dev/null && ok "Gateway restarted" || warn "Could not restart — restart OpenClaw manually"
else
  ok "Skipped"
fi

# ─── Done ───
echo ""
echo "  ════════════════════════════════════════════"
echo "  ✅ Installation complete!"
echo ""
echo "  Next steps:"
echo ""
echo "  1. Restart OpenClaw (close and reopen)"
echo ""
echo "  2. Select model 'auto · izzi' in chat"
echo ""
echo "  3. Send a message — it should work!"
echo ""
echo "  Dashboard: https://izziapi.com/dashboard"
echo "  Docs:      https://izziapi.com/docs"
echo "  Issues:    https://github.com/kentzu213/izzi-openclaw/issues"
echo ""

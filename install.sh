#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# Izzi × OpenClaw Connector — macOS/Linux Installer v2.2.0
# Usage:
#   ./install.sh "izzi-YOUR_API_KEY"
#   curl -fsSL https://raw.githubusercontent.com/.../install.sh | bash -s -- "izzi-KEY"
# ─────────────────────────────────────────────────────────────
set -e

VERSION="2.2.0"
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
    echo "  Get your key at: $BASE_URL/dashboard"
    echo ""
    exit 1
  fi
  echo ""
fi

# Check 1: Reject placeholder
if [ "$API_KEY" = "YOUR_IZZI_API_KEY" ]; then
  err "Invalid placeholder key. Get a real key at: $BASE_URL/dashboard"
  exit 1
fi

# Check 2: Must start with izzi-
case "$API_KEY" in
  izzi-*) ;;
  *)
    err "API key must start with 'izzi-'. Get your key at: $BASE_URL/dashboard"
    exit 1
    ;;
esac

# Check 3: Minimum length (izzi- + 43 hex = 48 chars)
KEY_LEN=${#API_KEY}
if [ "$KEY_LEN" -lt 48 ]; then
  err "API key too short ($KEY_LEN chars, need 48+). Check your key at: $BASE_URL/dashboard"
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
    err "API key is INVALID (server returned 401). Check your key at: $BASE_URL/dashboard"
    echo ""
    echo "  Installation ABORTED. No config files were modified."
    echo ""
    exit 1
  elif [ "$HTTP_CODE" = "403" ]; then
    err "API key is REVOKED (server returned 403). Create new key at: $BASE_URL/dashboard"
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

TOTAL=4

# ─── Step 1: Update openclaw.json (E2E Verified v4.2 Models) ───

step 1 $TOTAL "Updating openclaw.json..."

PROVIDER_JSON=$(cat <<PJSON
{
  "baseUrl": "$BASE_URL",
  "api": "openai-completions",
  "apiKey": "$API_KEY",
  "models": [
    { "id": "auto", "name": "Smart Router v4.2 (Auto)" },
    { "id": "REDACTED_MODEL", "name": "GPT-5 Mini (Budget)" },
    { "id": "REDACTED_MODEL", "name": "GPT-5.1 Mini (Budget)" },
    { "id": "REDACTED_MODEL", "name": "GPT-5.1 (Standard)" },
    { "id": "REDACTED_MODEL", "name": "GPT-5.1 Codex (Code)" },
    { "id": "REDACTED_MODEL", "name": "GPT-5.2 (Premium)" },
    { "id": "REDACTED_MODEL", "name": "GPT-5.4 (Premium)" }
  ]
}
PJSON
)

if [ -f "$OC_CONFIG" ]; then
  backup_file "$OC_CONFIG"

  if command -v python3 >/dev/null 2>&1; then
    python3 -c "
import json
with open('$OC_CONFIG', 'r') as f: data = json.load(f)
provider = json.loads('''$PROVIDER_JSON''')
if 'models' not in data: data['models'] = {}
if 'providers' not in data['models']: data['models']['providers'] = {}
data['models']['providers']['izzi'] = provider
if 'agents' in data and 'defaults' in data['agents'] and 'model' in data['agents']['defaults']:
    data['agents']['defaults']['model']['primary'] = 'izzi/auto'
with open('$OC_CONFIG', 'w') as f:
    json.dump(data, f, indent=2); f.write('\n')
print('    ✓ Added izzi provider + set default to izzi/auto')
" 2>/dev/null || warn "python3 failed — trying node..."
  fi

  if command -v node >/dev/null 2>&1 && ! grep -q '"izzi"' "$OC_CONFIG" 2>/dev/null; then
    node -e "
const fs = require('fs');
const data = JSON.parse(fs.readFileSync('$OC_CONFIG', 'utf8'));
const provider = JSON.parse(\`$PROVIDER_JSON\`);
if (!data.models) data.models = {};
if (!data.models.providers) data.models.providers = {};
data.models.providers.izzi = provider;
if (data.agents?.defaults?.model) data.agents.defaults.model.primary = 'izzi/auto';
fs.writeFileSync('$OC_CONFIG', JSON.stringify(data, null, 2) + '\n');
console.log('    ✓ Added izzi provider + set default to izzi/auto');
" 2>/dev/null || warn "Could not update openclaw.json"
  fi
else
  warn "openclaw.json not found — run 'openclaw setup' first"
fi

# ─── Step 2: Update agent configs (v4.2 Verified) ───
step 2 $TOTAL "Updating agent configs..."

find "$OC_DIR/agents" -name "models.json" -path "*/agent/*" 2>/dev/null | while read -r f; do
  backup_file "$f"
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "
import json
with open('$f', 'r') as fh: data = json.load(fh)
models_list = [
    {'id':'auto','name':'Smart Router v4.2 (Auto)','reasoning':False,'input':['text'],'cost':{'input':0,'output':0,'cacheRead':0,'cacheWrite':0},'contextWindow':200000,'maxTokens':8192,'api':'openai-completions'},
    {'id':'REDACTED_MODEL','name':'GPT-5 Mini (Budget)','reasoning':False,'input':['text'],'cost':{REDACTED_COST,REDACTED_COST,REDACTED_COST,'cacheWrite':0},'contextWindow':200000,'maxTokens':8192,'api':'openai-completions'},
    {'id':'REDACTED_MODEL','name':'GPT-5.1 Mini (Budget)','reasoning':False,'input':['text'],'cost':{REDACTED_COST,REDACTED_COST,REDACTED_COST,'cacheWrite':0},'contextWindow':200000,'maxTokens':8192,'api':'openai-completions'},
    {'id':'REDACTED_MODEL','name':'GPT-5.1 (Standard)','reasoning':False,'input':['text'],'cost':{REDACTED_COST,REDACTED_COST,REDACTED_COST,'cacheWrite':0},'contextWindow':200000,'maxTokens':8192,'api':'openai-completions'},
    {'id':'REDACTED_MODEL','name':'GPT-5.1 Codex (Code)','reasoning':False,'input':['text'],'cost':{REDACTED_COST,REDACTED_COST,REDACTED_COST,'cacheWrite':0},'contextWindow':200000,'maxTokens':8192,'api':'openai-completions'},
    {'id':'REDACTED_MODEL','name':'GPT-5.2 (Premium)','reasoning':True,'input':['text'],'cost':{REDACTED_COST,REDACTED_COST,REDACTED_COST,'cacheWrite':0},'contextWindow':200000,'maxTokens':8192,'api':'openai-completions'},
    {'id':'REDACTED_MODEL','name':'GPT-5.4 (Premium)','reasoning':True,'input':['text'],'cost':{REDACTED_COST,REDACTED_COST,REDACTED_COST,'cacheWrite':0},'contextWindow':200000,'maxTokens':8192,'api':'openai-completions'}
]
data.setdefault('providers', {})['izzi'] = {'baseUrl':'$BASE_URL','apiKey':'$API_KEY','api':'openai-completions','models':models_list}
with open('$f', 'w') as fh:
    json.dump(data, fh, indent=2); fh.write('\n')
" 2>/dev/null && ok "$(basename $(dirname $(dirname "$f")))/agent/models.json"
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
echo "  Dashboard: $BASE_URL/dashboard"
echo "  Docs:      $BASE_URL/docs"
echo "  Issues:    https://github.com/kentzu213/izzi-openclaw/issues"
echo ""

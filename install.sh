#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# Izzi × OpenClaw Connector — macOS/Linux Installer
# Usage: curl -fsSL "https://raw.githubusercontent.com/kentzu213/izzi-openclaw/main/install.sh" | bash -s -- "izzi-YOUR_KEY"
# License: BSL-1.1 — Copyright (c) 2026 izziapi.com
# ─────────────────────────────────────────────────────────────
set -e

VERSION="1.0.0"
BASE_URL="https://izziapi.com"
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

# ─── Install mode ───

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

# Validate
case "$API_KEY" in
  izzi-*) ;;
  *) warn "Key doesn't start with 'izzi-' — continuing anyway" ;;
esac

echo "  Base URL: $BASE_URL"
echo "  API Key:  ${API_KEY:0:16}..."
echo ""

TOTAL=5

# ─── Step 1: Update openclaw.json ───

step 1 $TOTAL "Updating openclaw.json..."

PROVIDER_JSON=$(cat <<PJSON
{
  "baseUrl": "$BASE_URL",
  "api": "openai-completions",
  "apiKey": "$API_KEY",
  "models": [
    { "id": "auto", "name": "Smart Router (Auto)" },
    { "id": "llama-3.3-70b", "name": "Llama 3.3 70B" },
    { "id": "qwen3-235b", "name": "Qwen3 235B" },
    { "id": "deepseek-r1-free", "name": "DeepSeek R1" },
    { "id": "llama-3.1-8b", "name": "Llama 3.1 8B (Fast)" },
    { "id": "claude-sonnet-4", "name": "Claude Sonnet 4" },
    { "id": "gpt-5.4", "name": "GPT-5.4" }
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

# ─── Step 2: Update agent configs ───

step 2 $TOTAL "Updating agent configs..."

MODEL_TEMPLATE='{"id":"%s","name":"%s","reasoning":false,"input":["text"],"cost":{"input":0,"output":0,"cacheRead":0,"cacheWrite":0},"contextWindow":200000,"maxTokens":8192,"api":"openai-completions"}'

UPDATED=0
find "$OC_DIR/agents" -name "models.json" -path "*/agent/*" 2>/dev/null | while read -r f; do
  backup_file "$f"
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "
import json
with open('$f', 'r') as fh: data = json.load(fh)
models_list = [
    {'id':'auto','name':'Smart Router (Auto)','reasoning':False,'input':['text'],'cost':{'input':0,'output':0,'cacheRead':0,'cacheWrite':0},'contextWindow':200000,'maxTokens':8192,'api':'openai-completions'},
    {'id':'llama-3.3-70b','name':'Llama 3.3 70B','reasoning':False,'input':['text'],'cost':{'input':0,'output':0,'cacheRead':0,'cacheWrite':0},'contextWindow':200000,'maxTokens':8192,'api':'openai-completions'},
    {'id':'qwen3-235b','name':'Qwen3 235B','reasoning':False,'input':['text'],'cost':{'input':0,'output':0,'cacheRead':0,'cacheWrite':0},'contextWindow':200000,'maxTokens':8192,'api':'openai-completions'},
    {'id':'deepseek-r1-free','name':'DeepSeek R1','reasoning':False,'input':['text'],'cost':{'input':0,'output':0,'cacheRead':0,'cacheWrite':0},'contextWindow':200000,'maxTokens':8192,'api':'openai-completions'},
    {'id':'llama-3.1-8b','name':'Llama 3.1 8B (Fast)','reasoning':False,'input':['text'],'cost':{'input':0,'output':0,'cacheRead':0,'cacheWrite':0},'contextWindow':200000,'maxTokens':8192,'api':'openai-completions'},
    {'id':'claude-sonnet-4','name':'Claude Sonnet 4','reasoning':False,'input':['text'],'cost':{'input':0,'output':0,'cacheRead':0,'cacheWrite':0},'contextWindow':200000,'maxTokens':8192,'api':'openai-completions'},
    {'id':'gpt-5.4','name':'GPT-5.4','reasoning':False,'input':['text'],'cost':{'input':0,'output':0,'cacheRead':0,'cacheWrite':0},'contextWindow':200000,'maxTokens':8192,'api':'openai-completions'}
]
data.setdefault('providers', {})['izzi'] = {'baseUrl':'$BASE_URL','apiKey':'$API_KEY','api':'openai-completions','models':models_list}
with open('$f', 'w') as fh:
    json.dump(data, fh, indent=2); fh.write('\n')
" 2>/dev/null && ok "$(basename $(dirname $(dirname "$f")))/agent/models.json"
  fi
done

# ─── Step 3: Apply fixes ───

step 3 $TOTAL "Applying compatibility fixes..."

FIXES=0
find "$OC_DIR" -name "*.json" \( -name "openclaw.json" -o -name "models.json" \) 2>/dev/null | while read -r f; do
  if grep -q '/v1"' "$f" 2>/dev/null; then
    sed -i.tmp 's|/v1"|"|g' "$f" 2>/dev/null || sed -i '' 's|/v1"|"|g' "$f" 2>/dev/null
    rm -f "${f}.tmp"
    ok "Fixed: removed /v1 suffix in $(basename "$f")"
  fi
done

# ─── Step 4: Connectivity test ───

step 4 $TOTAL "Testing connectivity..."

if command -v curl >/dev/null 2>&1; then
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "x-api-key: $API_KEY" "$BASE_URL/v1/models" 2>/dev/null || echo "000")
  if [ "$HTTP_CODE" = "200" ]; then
    ok "Connected to Izzi API (HTTP $HTTP_CODE)"
  elif [ "$HTTP_CODE" = "000" ]; then
    warn "Could not reach $BASE_URL — check your network"
  else
    warn "Izzi responded HTTP $HTTP_CODE — verify your API key"
  fi
else
  warn "curl not found — skipping connectivity test"
fi

# ─── Step 5: Restart ───

step 5 $TOTAL "Restarting OpenClaw gateway..."

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

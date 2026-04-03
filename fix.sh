#!/usr/bin/env bash
# Izzi × OpenClaw — Auto-Fix Tool (macOS/Linux)
# Usage: ./fix.sh [--diagnose] [--auto]
set -e

OC_DIR="$HOME/.openclaw"
ISSUES=0
FIXED=0
DIAGNOSE=false
AUTO=false

for arg in "$@"; do
  case "$arg" in
    --diagnose) DIAGNOSE=true ;;
    --auto)     AUTO=true ;;
  esac
done

echo ""
echo "  ╔══════════════════════════════════════════╗"
echo "  ║     🔧 Izzi × OpenClaw Auto-Fix Tool    ║"
echo "  ╚══════════════════════════════════════════╝"
echo ""

[ ! -d "$OC_DIR" ] && echo "  ❌ OpenClaw not found at $OC_DIR" && exit 1

# Collect configs
CONFIGS=$(find "$OC_DIR" -name "openclaw.json" -o \( -name "models.json" -path "*/agent/*" \) 2>/dev/null)
CONFIG_COUNT=$(echo "$CONFIGS" | wc -l)
echo "  Scanning $CONFIG_COUNT config file(s)..."
echo ""

# Issue 1: /v1 suffix
echo "  [1/5] Checking for /v1 suffix in baseUrl..."
for f in $CONFIGS; do
  if grep -q '/v1"' "$f" 2>/dev/null; then
    ISSUES=$((ISSUES + 1))
    SHORT=$(echo "$f" | sed "s|$OC_DIR|~/.openclaw|")
    echo "    ⚠ FOUND: /v1 suffix in $SHORT"
    if [ "$DIAGNOSE" = false ]; then
      cp "$f" "${f}.bak.$(date +%Y%m%d%H%M%S)"
      sed -i.tmp 's|/v1"|"|g' "$f" 2>/dev/null || sed -i '' 's|/v1"|"|g' "$f" 2>/dev/null
      rm -f "${f}.tmp"
      echo "    ✓ FIXED"
      FIXED=$((FIXED + 1))
    fi
  fi
done
[ $ISSUES -eq 0 ] && echo "    ✓ No /v1 suffix issues"

# Issue 2: baseUrl consistency
echo "  [2/5] Checking baseUrl consistency..."
URLS=$(grep -h '"baseUrl"' $CONFIGS 2>/dev/null | grep -o '"http[^"]*"' | sort -u)
URL_COUNT=$(echo "$URLS" | wc -l)
if [ "$URL_COUNT" -gt 1 ]; then
  echo "    ⚠ Multiple baseUrls detected"
  ISSUES=$((ISSUES + 1))
else
  echo "    ✓ All configs use same baseUrl"
fi

# Issue 3: Stale models (check backend if available)
echo "  [3/5] Checking for stale model names..."
ROUTER_PATH="$(pwd)/izzi-backend/src/services/router.ts"
if [ -f "$ROUTER_PATH" ] && grep -q "deepseek/deepseek-r1:free" "$ROUTER_PATH" 2>/dev/null; then
  echo "    ⚠ FOUND: stale deepseek/deepseek-r1:free"
  ISSUES=$((ISSUES + 1))
  if [ "$DIAGNOSE" = false ]; then
    sed -i.tmp 's|deepseek/deepseek-r1:free|qwen/qwen3.6-plus:free|g' "$ROUTER_PATH" 2>/dev/null
    rm -f "${ROUTER_PATH}.tmp"
    echo "    ✓ FIXED"
    FIXED=$((FIXED + 1))
  fi
else
  echo "    ✓ No stale model names"
fi

# Issue 4: Missing izzi provider
echo "  [4/5] Checking izzi provider presence..."
for f in $CONFIGS; do
  if ! grep -q '"izzi"' "$f" 2>/dev/null; then
    SHORT=$(echo "$f" | sed "s|$OC_DIR|~/.openclaw|")
    echo "    ⚠ MISSING: izzi provider in $SHORT"
    ISSUES=$((ISSUES + 1))
  fi
done
[ $ISSUES -eq 0 ] && echo "    ✓ izzi provider present in all configs"

# Issue 5: Gateway check
echo "  [5/5] Checking gateway status..."
if pgrep -f "openclaw" >/dev/null 2>&1; then
  echo "    ✓ Gateway process detected"
else
  echo "    · Gateway not running"
fi

# Report
echo ""
echo "  ════════════════════════════════════════════"
if [ $ISSUES -eq 0 ]; then
  echo "  ✅ No issues found!"
elif [ "$DIAGNOSE" = true ]; then
  echo "  📋 Found $ISSUES issue(s) — run without --diagnose to fix"
else
  echo "  🔧 Fixed $FIXED of $ISSUES issue(s)"
fi
echo ""

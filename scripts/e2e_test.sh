#!/usr/bin/env bash
# E2E test — verifies full pipeline: API Key → IzziAPI → Provider → Response
# Usage: bash scripts/e2e_test.sh [API_BASE_URL]

set -euo pipefail

BASE="${1:-http://localhost:8787}"

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  SMART ROUTER E2E PIPELINE TEST                     ║"
echo "║  User → API Key → izziapi → Router → Provider       ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# Health check
echo "=== Health Check ==="
HTTP=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/health")
if [ "$HTTP" = "200" ]; then
  echo "  ✅ Health: OK"
else
  echo "  ❌ Health: FAIL (HTTP $HTTP)"
  exit 1
fi

# Models count
echo ""
echo "=== Models Endpoint ==="
MODELS=$(curl -s "$BASE/v1/models" 2>/dev/null)
COUNT=$(echo "$MODELS" | python3 -c "import json,sys; print(len(json.load(sys.stdin).get('data',[])))" 2>/dev/null || echo "?")
echo "  Models available: $COUNT"

# Test with API key (requires IZZI_TEST_KEY env var)
if [ -n "${IZZI_TEST_KEY:-}" ]; then
  echo ""
  echo "=== Chat Completion Tests ==="

  test_model() {
    local model=$1
    local label=$2
    local start=$(date +%s%N)

    RESP=$(curl -s -w "\n%{http_code}" "$BASE/v1/chat/completions" \
      -H "Authorization: Bearer $IZZI_TEST_KEY" \
      -H "Content-Type: application/json" \
      -d "{\"model\":\"$model\",\"messages\":[{\"role\":\"user\",\"content\":\"say hi\"}],\"max_tokens\":5}")

    local end=$(date +%s%N)
    local http_code=$(echo "$RESP" | tail -1)
    local body=$(echo "$RESP" | sed '$d')
    local elapsed=$(echo "scale=2; ($end - $start) / 1000000000" | bc 2>/dev/null || echo "?")

    if [ "$http_code" = "200" ]; then
      local rmodel=$(echo "$body" | python3 -c "import json,sys; print(json.load(sys.stdin).get('model','?'))" 2>/dev/null || echo "?")
      echo "  ✅ $label | HTTP=$http_code | Model=$rmodel | Time=${elapsed}s"
    else
      echo "  ❌ $label | HTTP=$http_code | Time=${elapsed}s"
    fi
  }

  test_model "9r-auto"        "9r-auto → 9Router"
  test_model "llama-3.3-70b"  "Cerebras Llama"
  test_model "qwen3-235b"     "Cerebras Qwen"
  test_model "sn-llama-3.3-70b" "SambaNova Llama (OR)"
  test_model "sn-qwq-32b"    "SambaNova QwQ (OR)"
else
  echo ""
  echo "⚠️  Set IZZI_TEST_KEY to run chat completion tests"
  echo "   Example: IZZI_TEST_KEY=izzi-xxx bash scripts/e2e_test.sh"
fi

echo ""
echo "=== DONE ==="

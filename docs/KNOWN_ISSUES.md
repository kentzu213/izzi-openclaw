# IzziAPI — Known Issues & Fix Guide

> Tài liệu tổng hợp các lỗi đã phát hiện và cách sửa. Dùng làm reference khi gặp lại.

## Issue #1: DB `routing_decisions` missing `fallback_model` column

**Triệu chứng:** Logs hiện `DB flush failed` liên tục, routing metrics không lưu được.

**Root cause:** Table `routing_decisions` thiếu column `fallback_model` (schema drift giữa code và DB).

**Fix:**
```sql
ALTER TABLE routing_decisions
  ADD COLUMN IF NOT EXISTS fallback_model TEXT;
```

**Prevention:** Luôn chạy migration scripts khi update backend code.

---

## Issue #2: SambaNova/NIM models 404 qua 9Router

**Triệu chứng:** Request đến model SambaNova (e.g., `Meta-Llama-3.3-70B-Instruct`) trả 404/400.

**Root cause:** 9Router không có native OpenAI API keys. Khi IzziAPI proxy request với provider=`ninerouter`, 9Router nhận nhưng không có upstream key để forward.

**Fix:** Remap tất cả SambaNova/NIM models từ provider `ninerouter` sang `openrouter` với `:free` suffix trong `router.ts`:
```typescript
// TRƯỚC (broken):
{ model: "sn-llama-3.3-70b", provider: "ninerouter", ... }

// SAU (fixed):
{ model: "sn-llama-3.3-70b", upstreamModel: "meta-llama/llama-3.3-70b-instruct:free", provider: "openrouter", ... }
```

---

## Issue #3: `9r-auto` model 404

**Triệu chứng:** Model `9r-auto` trả 404 khi gọi qua IzziAPI.

**Root cause:** `9r-auto` mapped upstream model = `auto`, nhưng 9Router không có model tên `auto`.

**Fix:** Map `9r-auto` đến model cụ thể có sẵn trên 9Router:
```typescript
{ model: "9r-auto", upstreamModel: "cx/gpt-5.2", provider: "ninerouter", ... }
```

---

## Issue #4: Cerebras upstream model names thay đổi

**Triệu chứng:** Cerebras models (`llama-3.3-70b`, `qwen-3-235b`) trả 404.

**Root cause:** Cerebras đổi catalog model:
- `llama-3.3-70b` → bị xóa, thay bằng `llama3.1-8b`
- `qwen-3-235b` → đổi thành `qwen-3-235b-a22b-instruct-2507`

**Fix:** Cập nhật `upstreamModel` trong `router.ts`:
```typescript
// Cerebras models — check https://api.cerebras.ai/v1/models for current list
{ model: "llama-3.3-70b", upstreamModel: "llama3.1-8b", provider: "cerebras" }
{ model: "qwen3-235b", upstreamModel: "qwen-3-235b-a22b-instruct-2507", provider: "cerebras" }
```

**Auto-check script:**
```bash
curl -s https://api.cerebras.ai/v1/models \
  -H "Authorization: Bearer $CEREBRAS_API_KEY" | jq '.data[].id'
```

---

## Issue #5: OpenRouter free models bị xóa/đổi tên

**Triệu chứng:** OpenRouter models trả 404 (model not found) hoặc 429 (rate limit).

**Root cause:** OpenRouter thường xuyên thay đổi danh sách free models. 9/10 models cũ bị xóa.

**Fix mapping (April 2026):**

| IzziAPI Model | Old upstream (broken) | New upstream (working) |
|---|---|---|
| `sn-llama-3.1-405b` | `meta-llama/llama-3.1-405b-instruct:free` | `nousresearch/hermes-3-llama-3.1-405b:free` |
| `sn-qwq-32b` | `qwen/qwq-32b:free` | `qwen/qwen3-coder:free` |
| `sn-deepseek-r1` | `deepseek/deepseek-r1:free` | `google/gemma-4-31b-it:free` |
| `sn-deepseek-v3` | `deepseek/deepseek-v3-0324:free` | `google/gemma-3-27b-it:free` |
| `sn-qwen3-32b` | `qwen/qwen3-32b:free` | `qwen/qwen3-next-80b-a3b-instruct:free` |
| `nim-nemotron-70b` | `nvidia/llama-3.1-nemotron-70b:free` | `nvidia/nemotron-3-super-120b-a12b:free` |
| `nim-mistral-7b` | `mistralai/mistral-7b-v0.3:free` | `cognitivecomputations/dolphin-mistral-24b:free` |
| `nim-llama-3.1-8b` | `meta-llama/llama-3.1-8b:free` | `meta-llama/llama-3.2-3b-instruct:free` |
| `nemotron-3-super-free` | `nvidia/nemotron-3-super-120b:free` | `nvidia/nemotron-3-super-120b-a12b:free` |

**Auto-check script (chạy định kỳ):**
```bash
curl -s https://openrouter.ai/api/v1/models | \
  python3 -c "
import json, sys
d = json.load(sys.stdin)
free = [m['id'] for m in d.get('data', []) if ':free' in m['id']]
print('Available free models:')
for m in sorted(free): print(f'  {m}')
"
```

---

## Issue #6: OpenRouter 429 Rate Limit

**Triệu chứng:** Response 429 `"is temporarily rate-limited upstream"`.

**Root cause:** OpenRouter free tier giới hạn ~20 req/min. Khi nhiều user cùng dùng => rate limit.

**Fix (short-term):** Retry logic đã có trong Smart Router. 429 sẽ tự retry.

**Fix (long-term):** Thêm nhiều OpenRouter API keys hoặc dùng paid models.

---

## Issue #7: 9Router crash loop (port binding)

**Triệu chứng:** `pm2 logs 9router` hiện `EADDRINUSE: port 20128`.

**Root cause:** Instance cũ chưa release port.

**Fix:**
```bash
pm2 stop 9router
sleep 2
lsof -ti:20128 | xargs kill -9 2>/dev/null
pm2 start 9router
pm2 save
```

---

## Monitoring Commands

```bash
# Check all services
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
pm2 ls

# Health check
curl -s http://localhost:8787/health | jq
curl -s http://localhost:20128/health | jq

# Check 9Router models
curl -s http://localhost:20128/v1/models | jq '.data[].id'

# Check Cerebras available models
curl -s https://api.cerebras.ai/v1/models -H "Authorization: Bearer $CEREBRAS_KEY" | jq '.data[].id'

# E2E test (replace KEY with valid API key)
curl -s http://localhost:8787/v1/chat/completions \
  -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"9r-auto","messages":[{"role":"user","content":"hello"}],"max_tokens":10}'
```

---

## Architecture Reference

```
User Request
    │
    ▼
┌──────────────────────────┐
│   Caddy (reverse proxy)  │  api.izziapi.com → localhost:8787
└──────────┬───────────────┘
           │
           ▼
┌──────────────────────────┐
│   IzziAPI (Docker:8787)  │  Auth → Rate Limit → Smart Router
│   src/routes/proxy.ts    │
│   src/services/router.ts │  Model → Provider mapping
└──────────┬───────────────┘
           │
     ┌─────┼──────────┐
     │     │          │
     ▼     ▼          ▼
┌────────┐ ┌────────┐ ┌──────────┐
│9Router │ │Cerebras│ │OpenRouter│
│PM2:20128│ │  API   │ │   API    │
│cx/gpt-5.2│ │llama3.1│ │:free tier│
└────────┘ └────────┘ └──────────┘
```

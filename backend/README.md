# IzziAPI Backend

Smart AI Router proxy — routes requests to optimal providers (9Router, Cerebras, OpenRouter).

## Quick Start

```bash
cp .env.example .env   # Fill in your keys
npm install
npm run dev             # Development (tsx watch)
```

## Production (Docker)

```bash
docker compose build api --no-cache
docker compose up -d api
```

## Architecture

```
proxy.ts → router.ts → provider APIs
                ↓
         routerMetrics.ts → Supabase (routing_decisions)
         smartRouter.ts   → Adaptive scoring
```

## Key Files

| File | Purpose |
|------|---------|
| `src/routes/proxy.ts` | Main proxy endpoint — `/v1/chat/completions` |
| `src/services/router.ts` | Model → Provider mapping (most frequently updated) |
| `src/services/routerMetrics.ts` | Routing decision logging |
| `src/services/smartRouter.ts` | Adaptive model selection |
| `src/services/providers.ts` | Provider configuration & API keys |
| `src/middleware/auth.ts` | SHA-256 API key validation via Supabase |

## Updating Model Mappings

When upstream providers change their catalogs, update `src/services/router.ts`:

1. Check current models: See scripts in `docs/KNOWN_ISSUES.md`
2. Update `upstreamModel` field in the model config
3. Rebuild: `docker compose build api --no-cache`
4. Restart: `docker compose up -d api`
5. Test: `bash scripts/e2e_test.sh`

## See Also

- [Known Issues & Fix Guide](../docs/KNOWN_ISSUES.md)

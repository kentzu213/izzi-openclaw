# 🔒 SECURITY RULES — izzi-openclaw

> **This file is a BINDING CONTRACT for this repository.**
> Any commit that violates these rules MUST be reverted immediately.
> These rules exist to protect user billing integrity and prevent unauthorized API usage.

---

## Rule #1: API Key MUST Be Verified Before Config Write

**MANDATORY.** The installer MUST verify the API key against the live backend (`GET /v1/models` with `x-api-key` header) BEFORE writing any config files.

- If the server returns HTTP 401 → **exit 1** immediately
- If the server is unreachable → **exit 1** immediately (no "warn and continue")
- Config files (`openclaw.json`, `models.json`) MUST NOT be modified until verification passes

```
✅ CORRECT: Verify key → HTTP 200 → Write config
❌ WRONG:   Write config → Test key → Warn if fails
❌ WRONG:   Skip verification → Write config anyway
```

## Rule #2: API Key Format Is Strictly Enforced

- Key MUST start with `izzi-` prefix
- Key MUST be at least 48 characters long
- Key MUST NOT be the placeholder `YOUR_IZZI_API_KEY`
- Key MUST NOT be empty or whitespace-only
- Failing ANY of these checks → **exit 1** (no `-Force` bypass, no "continue anyway")

## Rule #3: No Hardcoded API Keys In Source Code

- Template files MUST use placeholder: `YOUR_IZZI_API_KEY`
- Real API keys MUST only exist in user's local config (`~/.openclaw/`)
- `.gitignore` MUST exclude any file containing real keys
- No test keys, no admin keys, no "default" keys

## Rule #4: Connectivity Test Is a BLOCKING Gate

The connectivity test is NOT optional. It is a security gate:

```
Step 0: Verify key with backend  ← BLOCKING (exit 1 on failure)
Step 1: Write openclaw.json      ← Only after Step 0 passes
Step 2: Write agent configs       ← Only after Step 0 passes
...
```

Any refactoring of the installer MUST preserve this order.

## Rule #5: Version Bumps Do NOT Override Security

When bumping version numbers or adding features:
- Security validation steps MUST remain intact
- Key verification MUST NOT be moved to a later step
- Key verification MUST NOT be made optional
- The `-Force` flag MUST NOT bypass key verification

## Rule #6: Templates Are Inert

Template files (`templates/*.json`) contain placeholders only:
- They MUST NOT function as valid API configurations
- They MUST contain `YOUR_IZZI_API_KEY` as the apiKey value
- They are reference files, NOT deployable configs

---

## Enforcement

| Violation | Action |
|---|---|
| Commit removes key verification | **Revert immediately** |
| Commit makes verification optional | **Revert immediately** |
| Commit adds hardcoded API key | **Revert + rotate key** |
| Commit bypasses format check | **Revert immediately** |
| PR weakens security gates | **Block merge** |

---

## Changelog

| Date | Change | Author |
|------|--------|--------|
| 2026-04-09 | Created — Rules #1-6 established | System |

---

*This file was created to prevent regression of critical security fixes.*
*Last verified: v2.2.0*

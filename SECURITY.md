# 🔒 Security Policy

## Supported Versions

| Version | Supported          |
|---------|--------------------|
| 3.1.x   | ✅ Active support  |
| 3.0.x   | ✅ Security fixes  |
| 2.x     | ❌ End of life     |
| 1.x     | ❌ End of life     |

## Reporting a Vulnerability

**DO NOT** create public GitHub issues for security vulnerabilities.

### How to Report

1. **Email**: Send details to **security@izziapi.com**
2. **Subject**: `[SECURITY] Brief description of the issue`
3. **Include**:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact assessment
   - Your suggested fix (if any)

### What to Expect

| Timeline | Action |
|----------|--------|
| **24 hours** | Acknowledgment of your report |
| **72 hours** | Initial assessment and severity rating |
| **7 days** | Detailed response with remediation plan |
| **30 days** | Fix deployed (critical) or scheduled (low) |

### Severity Levels

| Level | Description | Response Time |
|-------|-------------|---------------|
| 🔴 **Critical** | API key exposure, auth bypass, data breach | < 24 hours |
| 🟠 **High** | Rate limit bypass, abuse detection evasion | < 72 hours |
| 🟡 **Medium** | Information disclosure, config issues | < 7 days |
| 🟢 **Low** | Minor issues, documentation gaps | < 30 days |

### Scope

The following are **in scope** for security reports:

- `install.ps1`, `install.sh`, `install-vps.sh` — Installer scripts
- `cli/` — Go binary installer
- API interactions with `api.izziapi.com`
- Authentication and key validation logic
- Device fingerprinting implementation
- Checksum verification logic

The following are **out of scope**:

- Third-party dependencies (report to the respective project)
- Social engineering attacks
- Denial of service attacks
- Issues in the izziapi.com web dashboard (report separately)

### Safe Harbor

We support responsible disclosure. If you follow this policy:

- We will **not** take legal action against you
- We will **not** suspend your API access for good-faith testing
- We will credit you in our security advisories (with your permission)
- We may offer bug bounties for critical vulnerabilities at our discretion

### PGP Key

For encrypted communication, you may request our PGP public key by emailing security@izziapi.com with the subject: `[PGP] Request public key`.

---

*Last updated: 2026-04-11*
*Security contact: security@izziapi.com*

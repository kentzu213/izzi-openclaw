# Contributing to izzi-openclaw

Thank you for your interest in contributing to izzi-openclaw!

## ⚠️ Important: Contributor License Agreement (CLA)

**By submitting a pull request or contribution to this project, you agree to the following terms:**

### 1. Ownership Transfer

You irrevocably assign and transfer all rights, title, and interest in your contribution to **izziapi.com**, including but not limited to:
- Copyright and related rights
- Patent rights (if applicable)
- Trade secret rights

### 2. License Grant

You grant izziapi.com a **perpetual, worldwide, royalty-free, irrevocable, exclusive license** to use, modify, distribute, sublicense, and incorporate your contributions into the Licensed Work.

### 3. Non-Competition Clause

You agree that you will **NOT** use your contributions, or knowledge gained during contribution, to:
- Create, operate, or contribute to a competing API proxy, gateway, or aggregation service
- Reverse engineer or reconstruct the server-side business logic
- Assist any third party in doing the above

### 4. Representations

By contributing, you represent that:
- You are legally entitled to grant the above rights
- Your contribution is your original work
- Your contribution does not violate any third-party rights
- You have the authority to agree to these terms (if contributing on behalf of an employer, your employer has authorized this)

### 5. Acknowledgment

You acknowledge that izziapi.com may:
- Accept, reject, or modify your contribution at its sole discretion
- Use your contribution in proprietary products without further notice
- Not be obligated to maintain attribution for your contribution

---

## How to Contribute

### Reporting Bugs

1. Check if the issue already exists in [GitHub Issues](https://github.com/kentzu213/izzi-openclaw/issues)
2. If not, create a new issue with:
   - Clear title describing the problem
   - Steps to reproduce
   - Expected vs actual behavior
   - Platform and version info

### Suggesting Features

1. Open a [GitHub Discussion](https://github.com/kentzu213/izzi-openclaw/discussions) or Issue
2. Describe the use case and expected behavior
3. Wait for maintainer approval before starting work

### Submitting Code

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Make your changes
4. Test thoroughly on your platform
5. Submit a pull request with:
   - Clear description of changes
   - Reference to related issue(s)
   - Test results

### Code Standards

- **Shell scripts**: POSIX-compatible where possible, tested on Ubuntu LTS
- **PowerShell**: Compatible with PowerShell 5.1+ and pwsh 7+
- **Go code**: `go vet` and `go fmt` must pass
- **No hardcoded secrets**: Use `YOUR_IZZI_API_KEY` placeholder

### What We Accept

| Type | Accepted |
|------|----------|
| Bug fixes | ✅ Welcome |
| Documentation improvements | ✅ Welcome |
| Platform compatibility fixes | ✅ Welcome |
| New platform support | ✅ After discussion |
| UI/UX improvements | ✅ After discussion |
| Security improvements | ✅ Via SECURITY.md process |
| Feature changes to installer logic | ⚠️ Requires approval |
| Changes to API interaction | ⚠️ Requires approval |

---

## Security Contributions

For security-related contributions, please follow the process in [SECURITY.md](SECURITY.md).

**DO NOT** submit security fixes as public pull requests.

---

*By submitting a contribution, you confirm that you have read and agree to the terms above.*

*Last updated: 2026-04-11*

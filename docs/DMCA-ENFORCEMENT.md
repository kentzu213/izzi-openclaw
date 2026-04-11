# DMCA Enforcement Guide

> **Internal document** — Use this template when filing DMCA takedown requests
> for unauthorized copies/forks of izzi-openclaw.

---

## When to File

File a DMCA takedown when you discover:
- ❌ **Direct clones** that remove or modify the BSL-1.1 license
- ❌ **Forks** that operate a competing API proxy/gateway service
- ❌ **Copies** on other platforms (GitLab, Bitbucket, etc.) that violate the license
- ❌ **Modified versions** that strip attribution to izziapi.com
- ❌ **Resellers** distributing the software as part of a commercial product

## How to File on GitHub

### Step 1: Gather Evidence

| Required | Description |
|----------|-------------|
| Original repo URL | `https://github.com/kentzu213/izzi-openclaw` |
| Infringing repo URL | `https://github.com/<violator>/<repo>` |
| License clause violated | BSL-1.1 Usage Limitation (lines 92-99 of LICENSE) |
| Specific infringing content | List files/commits that prove violation |
| Your identity | Full name and contact as copyright owner |

### Step 2: File at GitHub

**URL**: https://github.com/contact/dmca

### Step 3: Use This Template

```
Subject: DMCA Takedown Request — Unauthorized Use of izzi-openclaw

I am the copyright owner of the following work:

Repository: https://github.com/kentzu213/izzi-openclaw
Copyright: © 2026 izziapi.com
License: Business Source License 1.1 (BSL-1.1)

The following repository infringes on my copyright:

Infringing URL: https://github.com/<VIOLATOR>/<REPO>

Nature of Infringement:
The infringing repository is a [clone/fork/modified copy] of my original
work that violates the BSL-1.1 license terms, specifically:

1. USAGE LIMITATION VIOLATION: The infringing repository is being used to
   [operate a competing API proxy service / resell as a commercial product /
   create derivative works that compete with izziapi.com services], which
   is explicitly prohibited under lines 92-99 of the LICENSE file.

2. LICENSE REMOVAL: [If applicable] The infringing repository has removed
   or modified the BSL-1.1 license, which is required to be displayed
   conspicuously on all copies per the license terms.

3. ATTRIBUTION REMOVAL: [If applicable] Copyright notices and attribution
   to izziapi.com have been removed.

I have a good faith belief that use of the material in the manner complained
of is not authorized by the copyright owner, its agent, or the law.

I swear, under penalty of perjury, that the information in this notification
is accurate and that I am the copyright owner, or am authorized to act on
behalf of the copyright owner.

Signed,
[Your Full Legal Name]
[Your Email]
[Your Physical Address]
[Date]
```

### Step 4: Follow Up

| Timeline | Action |
|----------|--------|
| Day 0 | Submit DMCA request via GitHub form |
| Day 1-3 | GitHub reviews and forwards to violator |
| Day 10-14 | If no counter-notice, repo is removed |
| Day 14+ | If counter-notice filed, consider legal action |

---

## For Non-GitHub Platforms

### GitLab
- Contact: https://about.gitlab.com/handbook/legal/dmca/
- Same template as above, adapted to their form

### Bitbucket
- Contact: https://www.atlassian.com/legal/dmca
- Same template as above

### Other Hosting
- Contact the platform's abuse/legal team
- Include all evidence listed in Step 1

---

## Prevention Monitoring

### Regular Checks (Monthly)

```bash
# Search GitHub for potential clones
# (Run manually — GitHub search doesn't support automated DMCA)

# Search for repos containing our distinctive file names
# https://github.com/search?q=izzi-openclaw+OR+izziapi&type=repositories

# Search for repos with similar installer patterns
# https://github.com/search?q=%22api.izziapi.com%22&type=code
```

### Automated Alerts

Consider setting up:
- **Google Alerts**: `"izzi-openclaw" OR "izziapi" -site:github.com/kentzu213`
- **GitHub search bookmarks**: Check monthly for forks/clones
- **Domain monitoring**: Watch for domains similar to `izziapi.com`

---

*This document is for internal use only.*
*Last updated: 2026-04-11*

# License Options Summary

This document provides an overview of common open-source licenses to help you choose the right license for the Linux Sleep Warning System project.

## Quick Comparison

| License | Permissiveness | Commercial Use | Modifications | Distribution | Copyleft | Patent Grant | Complexity |
|---------|---------------|----------------|---------------|--------------|----------|--------------|------------|
| **MIT** | Very High | ✅ Yes | ✅ Yes | ✅ Yes | ❌ No | ❌ No | ⭐ Very Simple |
| **Apache 2.0** | Very High | ✅ Yes | ✅ Yes | ✅ Yes | ❌ No | ✅ Yes | ⭐⭐ Simple |
| **BSD 2-Clause** | Very High | ✅ Yes | ✅ Yes | ✅ Yes | ❌ No | ❌ No | ⭐ Very Simple |
| **BSD 3-Clause** | Very High | ✅ Yes | ✅ Yes | ✅ Yes | ❌ No | ❌ No | ⭐ Very Simple |
| **GPL v3** | Medium | ✅ Yes* | ✅ Yes* | ✅ Yes* | ✅ Yes | ✅ Yes | ⭐⭐⭐ Moderate |
| **LGPL v3** | Medium-High | ✅ Yes | ✅ Yes | ✅ Yes | ⚠️ Partial | ✅ Yes | ⭐⭐⭐ Moderate |
| **AGPL v3** | Low | ✅ Yes* | ✅ Yes* | ✅ Yes* | ✅ Yes | ✅ Yes | ⭐⭐⭐ Moderate |

\* *With copyleft restrictions (see details below)*

---

## Permissive Licenses (Recommended for Utilities)

### MIT License

**Rights Granted:**
- ✅ Commercial use
- ✅ Modification
- ✅ Distribution
- ✅ Private use
- ✅ Sublicensing

**Requirements:**
- ✅ Include original copyright notice
- ✅ Include license text

**Restrictions:**
- ❌ None (most permissive)

**Ease of Using:**
- ⭐⭐⭐⭐⭐ **Very Easy**
- Short, simple text (~200 words)
- Most widely recognized and trusted
- No compatibility issues
- Works well with all other licenses
- Preferred by many developers and companies

**Best For:**
- Utilities and tools (like this project)
- Libraries you want maximum adoption for
- Projects where you want minimal friction

**Example Users:** jQuery, Ruby on Rails, Node.js

---

### Apache License 2.0

**Rights Granted:**
- ✅ Commercial use
- ✅ Modification
- ✅ Distribution
- ✅ Private use
- ✅ Sublicensing
- ✅ **Patent grant** (explicit protection)

**Requirements:**
- ✅ Include original copyright notice
- ✅ Include license text
- ✅ State significant changes made
- ✅ Include NOTICE file if provided

**Restrictions:**
- ❌ None (very permissive)

**Ease of Using:**
- ⭐⭐⭐⭐ **Easy**
- Longer than MIT (~500 words) but still readable
- Explicit patent protection (good for corporate users)
- Slightly more requirements than MIT
- Compatible with GPL v3

**Best For:**
- Projects where patent protection is important
- Corporate-friendly projects
- Projects that may involve patents

**Example Users:** Android, Apache projects, Kubernetes

---

### BSD 2-Clause License

**Rights Granted:**
- ✅ Commercial use
- ✅ Modification
- ✅ Distribution
- ✅ Private use
- ✅ Sublicensing

**Requirements:**
- ✅ Include original copyright notice
- ✅ Include license text

**Restrictions:**
- ❌ None (very permissive)

**Ease of Using:**
- ⭐⭐⭐⭐⭐ **Very Easy**
- Extremely short (~50 words)
- Even simpler than MIT
- Minimal requirements

**Best For:**
- Projects wanting maximum simplicity
- Minimal legal text preferred

**Example Users:** FreeBSD, PostgreSQL, LLVM

---

### BSD 3-Clause License

**Rights Granted:**
- ✅ Commercial use
- ✅ Modification
- ✅ Distribution
- ✅ Private use
- ✅ Sublicensing

**Requirements:**
- ✅ Include original copyright notice
- ✅ Include license text
- ✅ **No endorsement** (cannot use author's name to promote)

**Restrictions:**
- ❌ None (very permissive)

**Ease of Using:**
- ⭐⭐⭐⭐⭐ **Very Easy**
- Same as BSD 2-Clause but with endorsement clause
- Protects against unauthorized endorsement

**Best For:**
- Projects where you want to prevent unauthorized endorsement
- Similar use cases to BSD 2-Clause

**Example Users:** Go programming language, Rust (parts)

---

## Copyleft Licenses (Viral Licenses)

### GNU GPL v3 (General Public License)

**Rights Granted:**
- ✅ Commercial use
- ✅ Modification
- ✅ Distribution
- ✅ Private use
- ✅ Patent grant

**Requirements:**
- ✅ Include original copyright notice
- ✅ Include license text
- ✅ **Disclose source code** when distributing
- ✅ **License derivatives under GPL v3** (copyleft)
- ✅ State significant changes made

**Restrictions:**
- ⚠️ **Copyleft**: Derivatives must also be GPL v3
- ⚠️ Cannot combine with incompatible licenses
- ⚠️ Must provide source code with binaries

**Ease of Using:**
- ⭐⭐⭐ **Moderate**
- Longer license text (~600 words)
- More requirements and restrictions
- Can create compatibility issues
- Some companies avoid GPL due to copyleft

**Best For:**
- Projects where you want to ensure derivatives stay open source
- Software you want to remain free
- Projects aligned with Free Software Foundation philosophy

**Example Users:** Linux kernel, GCC, GIMP

**Note:** GPL is "viral" - if someone combines your code with theirs, their code must also be GPL. This can limit commercial adoption.

---

### GNU LGPL v3 (Lesser General Public License)

**Rights Granted:**
- ✅ Commercial use
- ✅ Modification
- ✅ Distribution
- ✅ Private use
- ✅ Patent grant

**Requirements:**
- ✅ Include original copyright notice
- ✅ Include license text
- ✅ **Disclose source code** for LGPL parts
- ✅ **Allow linking** with non-LGPL code (key difference from GPL)
- ✅ Provide mechanism to replace LGPL library

**Restrictions:**
- ⚠️ **Partial copyleft**: Only LGPL parts must remain LGPL
- ⚠️ Modifications to LGPL code must be LGPL
- ⚠️ Can link with proprietary code (unlike GPL)

**Ease of Using:**
- ⭐⭐⭐ **Moderate**
- Similar complexity to GPL
- More permissive than GPL for libraries
- Better for libraries used in proprietary software

**Best For:**
- Libraries that need to be usable in proprietary software
- Shared libraries where you want some protection

**Example Users:** GTK, glibc (parts)

---

### GNU AGPL v3 (Affero General Public License)

**Rights Granted:**
- ✅ Commercial use
- ✅ Modification
- ✅ Distribution
- ✅ Private use
- ✅ Patent grant

**Requirements:**
- ✅ Include original copyright notice
- ✅ Include license text
- ✅ **Disclose source code** when distributing
- ✅ **Disclose source code** for network/web services (key difference)
- ✅ **License derivatives under AGPL v3**

**Restrictions:**
- ⚠️ **Strong copyleft**: Derivatives must be AGPL v3
- ⚠️ **Network copyleft**: Web services must provide source
- ⚠️ Most restrictive for SaaS/web applications

**Ease of Using:**
- ⭐⭐ **More Complex**
- Similar to GPL but with network clause
- Very restrictive for web services
- Limits commercial SaaS adoption

**Best For:**
- Web services where you want to prevent proprietary forks
- Projects where you want to ensure web versions stay open

**Example Users:** MongoDB (formerly), some web frameworks

---

## Recommendations for This Project

### For Maximum Adoption (Recommended)
**MIT License** - Best choice for a utility tool like this:
- ✅ Maximum compatibility
- ✅ Easiest for users to understand and use
- ✅ No barriers to adoption
- ✅ Works well with all other licenses
- ✅ Most developers are familiar with it

### For Patent Protection
**Apache 2.0** - If you're concerned about patents:
- ✅ Similar permissiveness to MIT
- ✅ Explicit patent grant
- ✅ Corporate-friendly

### For Keeping It Free
**GPL v3** - If you want derivatives to stay open source:
- ⚠️ Will limit some commercial adoption
- ⚠️ More complex requirements
- ✅ Ensures code remains free

---

## How to Choose

**Choose MIT if:**
- You want maximum adoption and minimal friction
- You're building a utility/tool (like this project)
- You want the simplest license possible
- You don't need patent protection

**Choose Apache 2.0 if:**
- You want patent protection
- You're targeting corporate users
- You want similar permissiveness to MIT with extra protection

**Choose GPL v3 if:**
- You want to ensure derivatives stay open source
- You're aligned with Free Software philosophy
- You're okay with limiting some commercial adoption

**Choose BSD if:**
- You want even simpler than MIT
- You prefer minimal legal text

---

## Implementation Steps

Once you choose a license:

1. **Create LICENSE file** in repository root
2. **Add license text** (copy from choosealicense.com or official source)
3. **Update README.md** to reference the license
4. **Add copyright notice** to source files (optional but recommended)

Example copyright notice for source files:
```bash
# Copyright (c) [YEAR] [YOUR NAME]
# Licensed under the MIT License
```

---

## Resources

- **Choose a License**: https://choosealicense.com/
- **License Comparison**: https://tldrlegal.com/
- **SPDX License List**: https://spdx.org/licenses/
- **GitHub License Chooser**: https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository

---

## Summary Table: Ease of Use

| License | For Users | For Contributors | For Companies | Overall |
|---------|-----------|------------------|---------------|---------|
| MIT | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| Apache 2.0 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| BSD 2/3-Clause | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| LGPL v3 | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |
| GPL v3 | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ |
| AGPL v3 | ⭐⭐ | ⭐⭐ | ⭐ | ⭐⭐ |

**Note:** For a utility tool like the Sleep Warning System, permissive licenses (MIT, Apache, BSD) are generally recommended for maximum adoption and ease of use.

# License Options Summary

This document compares licenses that were considered for TimerWarning. It is background. The root [`LICENSE`](../../LICENSE) file is the terms.

## Decision (2026-10-24)

TimerWarning is licensed under the **Apache License, Version 2.0**, with the **Commons Clause License Condition v1.0**. The owner chose that combination on 2026-10-24 so that personal use, modification, redistribution, and a company's own internal use remain allowed, while someone else may not sell the software as defined by the Commons Clause.

The combination is **source-available**. It is not an OSI-approved open source license. Apache 2.0 by itself is OSI-approved. Adding the Commons Clause removes that status. Do not describe the project as open source.

Sell, in the Commons Clause, means providing the software to third parties, for a fee or other consideration (including fees for hosting or consulting/support services related to the software), as a product or service whose value derives, entirely or substantially, from the functionality of the software. Uses that are not that kind of sale stay under the Apache 2.0 terms. Every copy must keep the copyright notice, the Commons Clause, and the Apache License.

No third-party source is vendored in this repository, and source files had no existing copyright headers. System tools the software calls, such as yad, zenity, kdialog, systemd, and the macOS frameworks, remain under their own licenses. Per-file copyright headers were not added. The notice lives in `LICENSE`.

Sections below that recommend MIT, or that describe noncommercial licenses as allowing internal business use, are not the project license. See [What the license texts actually say](#what-the-license-texts-actually-say).

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

### For Maximum Adoption
**MIT License** was the older suggestion for maximum adoption. The 2026-10-24 decision did not select it. For the comparison:
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

The project already chose the Apache License 2.0 with the Commons Clause. Use the questions below only when comparing other projects.

**Choose MIT if:**
- You want maximum adoption and minimal friction
- You're building a utility and want the fewest conditions
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

**Note:** Permissive licenses maximize adoption. This project did not choose one. TimerWarning uses the Apache License 2.0 with the Commons Clause, which is source-available.

---

## Non-Commercial and Proprietary Options

### Important Note: Non-Commercial ≠ Open Source

**If you want to restrict commercial use, your project cannot be "open source"** according to the OSI definition. The Open Source Definition requires that licenses must not restrict use in any field of endeavor, including business/commercial use. However, you can still share your source code publicly—it would be considered "source-available" rather than "open source."

### What the license texts actually say

"Commercial use" is not one rule shared by every restrictive license. Read the license you are applying.

**PolyForm Noncommercial 1.0.0** permits noncommercial purposes, listed noncommercial organizations, and personal use for research, study, hobby, and similar activities without any anticipated commercial application. It does not grant a for-profit company ordinary internal use.

**CC BY-NC 4.0** defines NonCommercial as use not primarily intended for or directed toward commercial advantage or monetary compensation. It does not contain a blanket permission for internal business use. Creative Commons also recommends a software license for code, so this was not selected.

**Commons Clause v1.0 on Apache 2.0**, the license in effect, does allow a company's own internal use. It removes only the right to Sell, using the definition in the [decision](#decision-2026-10-24) above and in [`LICENSE`](../../LICENSE). It does not ban every activity that earns money. A product whose value does not derive entirely or substantially from this software is outside that Sell definition. Paid hosting or support is inside the definition when the product or service being sold derives entirely or substantially from this software.

### Option 1: Non-Commercial Licenses

**License Zero Noncommercial (L0-NC)**
- ✅ Allows free non-commercial use
- ✅ Requires permission/licensing for commercial use
- ✅ Designed specifically for software (unlike Creative Commons)
- ❌ Not OSI-approved (not "open source")
- ⚠️ You'll need to manage commercial licensing requests

**Custom Non-Commercial License**
- ✅ Full control over terms
- ✅ Can tailor restrictions to your needs
- ❌ Requires legal review
- ❌ Not standardized (users may be confused)
- ❌ Not OSI-approved

**Best For:**
- Projects where you want to share source code but control commercial use
- Projects where you plan to sell commercial licenses
- Projects where you want to prevent commercial repackaging

### Option 2: Dual Licensing

**How It Works:**
- Offer the same codebase under two licenses:
  - **Open Source License**: GPL v3 or AGPL v3 (free, but copyleft restrictions)
  - **Commercial License**: Proprietary license (paid, no restrictions)
- Users choose based on their needs

**Requirements:**
- You must own all copyrights (or have Contributor License Agreements)
- Clear documentation of both license options
- Infrastructure to sell/manage commercial licenses

**Benefits:**
- ✅ Free version attracts users and builds community
- ✅ Commercial licenses generate revenue
- ✅ Open source version serves as product demo
- ✅ Community contributions improve the product

**Examples:** MySQL, Qt Framework, MongoDB (formerly)

**Best For:**
- Projects where you want both community adoption and revenue
- Projects where copyleft restrictions incentivize commercial licensing
- Projects with significant commercial value

### Option 3: Proprietary/Closed Source

**How It Works:**
- Keep source code private
- Distribute only binaries (or source with proprietary license)
- Control who uses it and how

**Distribution Options:**
- GitHub Releases (free hosting for binaries)
- Your own website
- Package managers (with proprietary license)
- No need to rent a domain—GitHub provides free hosting

**For Bash Scripts:**
- Since bash scripts are text files, you'd distribute them with a proprietary license
- Users can read the code, but usage is restricted by license terms
- Enforcement relies on legal terms, not technical obfuscation

**Best For:**
- Maximum control over usage
- Projects where you want to prevent any unauthorized use
- Projects where you're building a commercial product

### Option 4: Source-Available with Restrictions

**How It Works:**
- Share source code publicly
- License as proprietary with specific restrictions
- Example: "Free for personal/non-commercial use; commercial use requires license"

**Best For:**
- Projects where you want transparency but control commercial use
- Projects where you want community contributions but commercial licensing

---

## Recommendations for Restricting Commercial Use

The project already chose the Commons Clause on Apache 2.0. The list below is historical comparison, not an open decision.

**If you want to prevent commercial repackaging:**

1. **Dual Licensing (Recommended)** - GPL v3 for free use, commercial license for paid use
   - ✅ Best of both worlds: community adoption + revenue potential
   - ✅ Copyleft restrictions make commercial licensing attractive
   - ⚠️ Requires managing commercial licensing

2. **Non-Commercial License** - License Zero Noncommercial or custom
   - ✅ Simple: one license, clear restrictions
   - ⚠️ Not "open source" (may limit adoption)
   - ⚠️ Need to handle commercial licensing requests

3. **Proprietary License** - Keep it closed or source-available with restrictions
   - ✅ Maximum control
   - ❌ Limits community contributions
   - ❌ May reduce adoption

**Important Considerations:**
- **Enforcement**: Restricting commercial use requires monitoring and legal enforcement
- **Community**: Non-commercial restrictions may limit community contributions
- **Adoption**: Restrictions reduce adoption compared to permissive licenses
- **Revenue**: Dual licensing can generate revenue while maintaining community

---

## Resources for Non-Commercial Licensing

- **License Zero**: https://licensezero.com/ (non-commercial public license)
- **Dual Licensing Guide**: https://fossa.com/blog/dual-licensing-models-explained/
- **Open Source Definition**: https://opensource.org/osd (explains why non-commercial isn't "open source")

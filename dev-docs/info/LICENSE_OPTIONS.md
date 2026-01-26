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

---

## Non-Commercial and Proprietary Options

### Important Note: Non-Commercial ≠ Open Source

**If you want to restrict commercial use, your project cannot be "open source"** according to the OSI definition. The Open Source Definition requires that licenses must not restrict use in any field of endeavor, including business/commercial use. However, you can still share your source code publicly—it would be considered "source-available" rather than "open source."

### What Does "Commercial Use" Mean?

"Commercial use" in software licensing typically refers to **monetizing or selling the software itself**, not just using it in a business context. Here are the key distinctions:

#### ✅ Usually NOT Considered Commercial Use (Allowed Under Non-Commercial Licenses)

1. **Internal Business Use**
   - A company installing your Sleep Warning System for their employees
   - Using it as a tool within a business for operational purposes
   - Example: A company uses your tool to help employees manage screen time

2. **Using Software as a Tool to Create Commercial Products**
   - Using the software to create something else you sell
   - Example: A developer uses your tool while creating a commercial game (the tool is a utility, not the product)

#### ❌ Usually Considered Commercial Use (Prohibited Under Non-Commercial Licenses)

1. **Selling/Repackaging the Software**
   - Taking your code and selling it as-is or with modifications
   - Bundling it into a commercial product you sell
   - Example: Someone takes your Sleep Warning System, rebrands it, and sells it as "Premium Screen Time Manager Pro"

2. **Incorporating Into a Commercial Product**
   - Including your code in software you sell
   - Example: A company includes your tool as a feature in their commercial Linux distribution

3. **Selling Support/Services for the Software**
   - Charging for installation, configuration, or support services
   - Example: A consultant charges clients to install and configure your tool

#### ⚠️ Gray Areas (Varies by License)

- **SaaS/Cloud Services**: Hosting the software as a service (depends on license terms)
- **Indirect Commercial Benefit**: Using software to maintain infrastructure that enables sales (usually allowed if software isn't the product)

#### For Your Sleep Warning System

If you want to prevent someone from:
- **Repackaging and selling it** → Non-commercial license would prevent this
- **Including it in a commercial Linux distribution** → Non-commercial license would require their permission/licensing

If you're okay with:
- **Companies using it internally** → Most non-commercial licenses allow this
- **People using it as a personal tool** → Non-commercial licenses allow this

**Key Point**: Most non-commercial licenses focus on preventing **monetization of the software itself**, not preventing businesses from using it as an internal tool.

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

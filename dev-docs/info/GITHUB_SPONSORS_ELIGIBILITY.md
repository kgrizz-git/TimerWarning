# GitHub Sponsors Eligibility Requirements

This document summarizes the eligibility requirements for GitHub Sponsors, based on official GitHub documentation.

## Overview

**What is GitHub Sponsors?**

GitHub Sponsors is a platform that allows the developer community to financially support open source contributors and organizations directly on GitHub. It's essentially a voluntary donation/support system where:

- **Sponsors** (individuals or organizations) choose to financially support developers/projects they value
- **Sponsored developers** receive payments from sponsors who appreciate their work
- **100% of sponsorships from personal accounts** go to the sponsored developer (no fees)
- Sponsors can choose from **monthly or one-time** payment tiers
- It's completely **voluntary** - sponsors decide who and how much to support

Think of it like Patreon or Ko-fi, but integrated directly into GitHub. Sponsors can see your profile, repositories, and choose to support you because they find your work valuable.

**Eligibility Overview**

To become eligible to receive sponsorships through GitHub Sponsors, you must meet specific requirements related to open source contributions.

## Eligibility Requirements

### For Individual Developers

1. **Contribute to Open Source Projects**
   - You must contribute to an open source project
   - Contributions include (but are not limited to):
     - Bug reports
     - Issue triage
     - Code contributions
     - Documentation
     - Leadership
     - Business development
     - Project management
     - Mentorship
     - Design work

2. **Reside in a Supported Region**
   - You must live in a region supported by GitHub Sponsors
   - The United States is a supported region
   - If your region isn't supported, you can join the waitlist

3. **Compliance**
   - Must comply with GitHub's policies, including:
     - GitHub Community Guidelines
     - GitHub Sponsors Additional Terms

### For Organizations

1. **Contribute to Open Source Projects** (same types of contributions as individuals)
2. **Legally Operate in a Supported Region**
3. **Compliance** (same as individuals)

## What Counts as "Contributing to Open Source"?

GitHub's definition is intentionally broad. Simply having a public repository with an open source license that you actively maintain and develop qualifies as contributing to open source. This includes:

- Creating and maintaining your own open source projects
- Contributing code, documentation, or other work to existing projects
- Providing leadership, project management, or mentorship in open source communities
- Reporting bugs, triaging issues, or helping with design

**Important**: Your project must have an open source license (e.g., MIT, GPL, Apache) to be considered open source. A public repository without a license is not legally open source.

### OSI Approval and Non-Commercial Licenses

**Does GitHub Sponsors require OSI-approved licenses?**

GitHub's documentation states that you must "contribute to an open source project" but doesn't explicitly require OSI approval. However, GitHub generally considers projects with standard open source licenses (MIT, GPL, Apache, BSD, etc.) as "open source."

**What about non-commercial licenses?**

Non-commercial licenses (like License Zero Noncommercial) are **not OSI-approved** and are considered "source-available" rather than "open source." GitHub's eligibility requirements are somewhat ambiguous on this point:

- GitHub requires contributing to "an open source project"
- Non-commercial licenses restrict commercial use, which violates the Open Source Definition
- GitHub may or may not accept non-commercial licenses for GitHub Sponsors eligibility

**Recommendation**: If you want to ensure GitHub Sponsors eligibility, use an OSI-approved open source license (MIT, GPL, Apache, etc.). If you use a non-commercial license, you may need to contact GitHub Support to confirm eligibility, as the documentation doesn't explicitly address this scenario.

**Alternative**: You can still accept donations through other platforms (Patreon, Ko-fi, PayPal) regardless of your license choice.

## Project Eligibility Assessment

For the LinuxTimerWarning project, as of the 2026-10-24 license decision:

- **License**: [`LICENSE`](../../LICENSE) is the Apache License 2.0 with the Commons Clause. That combination is source-available. It is not an OSI open-source license, so this repository does not by itself meet a Sponsors requirement for an open-source license.
- **Publication**: The development repository is still private. A public staging repository is later work in the [publication plan](../plans/plan-public-repo-prep-2026-10-16.md).
- **Donations**: PayPal links stay until the owner reopens removal (deferred 2026-10-24). This note does not add a donation integration.

**Conclusion**: Do not treat the current license as satisfying GitHub Sponsors' open-source-license expectation.

## Application Process

Once you meet the requirements:

1. Complete your sponsored developer profile
2. Create sponsorship tiers (optional, up to 10 monthly and 10 one-time tiers)
3. Submit bank and tax information
4. Enable two-factor authentication on your GitHub account
5. Review and accept the GitHub Sponsors Additional Terms and Privacy Statement

GitHub may contact applicants for additional information to verify eligibility or investigate potential terms violations.

## Fees

- **Personal accounts**: GitHub Sponsors does not charge any fees for sponsorships from personal accounts, so 100% of sponsorships go to the sponsored developer
- **Organization accounts**: GitHub Sponsors charges a fee of up to 6% for sponsorships from organization accounts
  - 3% credit card processing fee
  - 3% GitHub service processing fee
  - Organizations can save the 3% credit card processing fee by switching to invoiced billing

## GitHub Sponsors Matching Fund

**Note**: Eligibility for the GitHub Sponsors Matching Fund has passed. Applications received after January 1, 2020 are not eligible for matching funds.

## Supported Regions

The United States is fully supported. For a complete list of supported regions, see the [official GitHub Sponsors documentation](https://docs.github.com/en/sponsors/getting-started-with-github-sponsors/about-github-sponsors#supported-regions-for-github-sponsors).

## References

- [About GitHub Sponsors](https://docs.github.com/en/sponsors/getting-started-with-github-sponsors/about-github-sponsors)
- [About GitHub Sponsors for open source contributors](https://docs.github.com/en/sponsors/receiving-sponsorships-through-github-sponsors/about-github-sponsors-for-open-source-contributors)
- [Setting up GitHub Sponsors for your personal account](https://docs.github.com/en/sponsors/receiving-sponsorships-through-github-sponsors/setting-up-github-sponsors-for-your-personal-account)
- [GitHub Sponsors Additional Terms](https://docs.github.com/en/site-policy/github-terms/github-sponsors-additional-terms)

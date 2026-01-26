# General and Reusable Information Files

This document catalogs all markdown files in the project that contain general information or are designed to be reusable reference material. These files are intended to be **portable and reusable across different projects**—they can be copied to other projects, used as reference material, or adapted for different contexts.

These files are not plans, implementation details, or project-specific documentation, but rather informational resources that provide:
- General knowledge about technologies, tools, or concepts
- Reusable templates for common tasks
- Reference information that applies beyond this specific project
- Best practices and comparisons that are broadly applicable

**Purpose**: This catalog makes it easy to identify which files are portable and useful for reference or copying to other projects.

**Last Updated**: 2026-01-26

---

## Quick Reference: Most Portable Files

### Ready to Copy (⭐⭐⭐⭐⭐)
These files can be copied directly to other projects with minimal or no changes:

**Information Files:**
- `audio-tools-options.md` - Linux audio tool reference
- `cursor-hooks-pii-secrets-scanning.md` - Cursor IDE security
- `detecting-fullscreen-exclusive-mode.md` - Display detection techniques
- `dialog-tools-options.md` - Dialog tool comparison (minor SteamOS examples may need adaptation)
- `DISTRIBUTION_OPTIONS.md` - Software distribution overview
- `DISTRIBUTION_OPTIONS_DETAILED.md` - Detailed distribution platform info
- `GITHUB_SPONSORS_ELIGIBILITY.md` - GitHub Sponsors reference
- `LICENSE_OPTIONS.md` - Open source license comparison
- `wayland-gamescope-window-tools.md` - Display system reference

**Template Files:**
- `functionality-integrity-assessment-template.md` - Code functionality assessment
- `future-and-remaining-assessment-template.md` - Project planning template
- `qi-assessment-template.md` - Quality improvement assessment
- `refactor-assessment-template.md` - Code refactoring assessment
- `safety-scan-template.md` - Security/safety scanning template
- `testing-assessment-template.md` - Testing assessment template

### May Need Minor Customization (⭐⭐⭐⭐)
- `doc-assessment-template.md` - May need adaptation for project-specific doc structure
- `doc-refactor-assessment-template.md` - May need adaptation for project-specific doc structure
- `scan-general-reusable-info-template.md` - May need customization for directory structures

---

## Information Files (`dev-docs/info/`)

### audio-tools-options.md

**Location**: `dev-docs/info/audio-tools-options.md`

**Summary**: Provides detailed information about command-line audio playback tools available on Linux systems. Covers tool availability, capabilities, limitations, and distribution-specific considerations for implementing audio alerts in shell scripts. Includes comparisons of tools like `paplay`, `aplay`, `ffplay`, `mpv`, and others.

**Category**: Technical Reference - Audio Tools

**Useful For**: Implementing audio alerts, choosing audio playback tools, understanding audio tool compatibility across Linux distributions.

**Portability**: ⭐⭐⭐⭐⭐ Highly portable - Contains general Linux audio tool information with no project-specific references. Can be copied directly to any Linux project needing audio playback capabilities.

---

### cursor-hooks-pii-secrets-scanning.md

**Location**: `dev-docs/info/cursor-hooks-pii-secrets-scanning.md`

**Summary**: Detailed information about using Cursor hooks to scan for Personally Identifiable Information (PII) and secrets before content leaves your machine. Explains how Cursor hooks work, key hooks for security scanning, implementation examples, and best practices for preventing sensitive data from being sent to AI services.

**Category**: Security Reference - Development Tools

**Useful For**: Setting up security scanning in Cursor, preventing accidental exposure of sensitive data, understanding Cursor hook system.

**Portability**: ⭐⭐⭐⭐⭐ Highly portable - Universal Cursor IDE information applicable to any project using Cursor. Can be copied directly.

---

### detecting-fullscreen-exclusive-mode.md

**Location**: `dev-docs/info/detecting-fullscreen-exclusive-mode.md`

**Summary**: Explains various methods to determine if a game or application is running in fullscreen exclusive mode on Linux systems. Covers window manager tools for X11, Wayland-specific methods, Gamescope detection, and practical implementation approaches.

**Category**: Technical Reference - Display Detection

**Useful For**: Detecting fullscreen applications, understanding display modes, implementing display-aware features.

**Portability**: ⭐⭐⭐⭐⭐ Highly portable - General Linux display detection techniques with no project-specific code. Can be copied directly to any Linux project needing fullscreen detection.

---

### dialog-tools-options.md

**Location**: `dev-docs/info/dialog-tools-options.md`

**Summary**: Comprehensive comparison of three command-line dialog tools for Linux shell scripts: Zenity, KDialog, and YAD (Yet Another Dialog). Focuses on availability, sizing behavior, window management capabilities, and compatibility across different environments—particularly on SteamOS and Gamescope. Includes detailed feature comparisons and usage examples.

**Category**: Tool Comparison - Dialog Tools

**Useful For**: Choosing dialog tools for shell scripts, understanding tool capabilities and limitations, implementing cross-platform dialog solutions.

**Portability**: ⭐⭐⭐⭐⭐ Highly portable - Comprehensive tool comparison with general information. Can be copied directly to any Linux shell script project. Some SteamOS-specific examples may need adaptation for other distributions.

---

### DISTRIBUTION_OPTIONS.md

**Location**: `dev-docs/info/DISTRIBUTION_OPTIONS.md`

**Summary**: High-level overview of distribution and packaging options for software projects. Covers open source vs closed source distribution, various platforms (GitHub Releases, package managers, proprietary platforms), costs, setup difficulty, and user adoption considerations. Includes acronym definitions and quick reference comparisons.

**Category**: Project Planning - Distribution

**Useful For**: Planning software distribution, understanding distribution platform options, comparing hosting and distribution costs.

**Portability**: ⭐⭐⭐⭐⭐ Highly portable - General distribution information applicable to any software project. Can be copied directly. Some cost examples may need updating over time.

---

### DISTRIBUTION_OPTIONS_DETAILED.md

**Location**: `dev-docs/info/DISTRIBUTION_OPTIONS_DETAILED.md`

**Summary**: Detailed information about each distribution platform option, including costs, setup difficulty, user access methods, landing pages, and payment support. Provides in-depth analysis of platforms like GitHub Releases, GitLab, SourceForge, proprietary platforms, and package managers. For a high-level overview, see DISTRIBUTION_OPTIONS.md.

**Category**: Project Planning - Distribution (Detailed)

**Useful For**: Detailed distribution platform research, cost analysis, understanding platform-specific features and limitations.

**Portability**: ⭐⭐⭐⭐⭐ Highly portable - Detailed platform information applicable to any software project. Can be copied directly. Cost information may need periodic updates.

---

### GITHUB_SPONSORS_ELIGIBILITY.md

**Location**: `dev-docs/info/GITHUB_SPONSORS_ELIGIBILITY.md`

**Summary**: Summarizes the eligibility requirements for GitHub Sponsors based on official GitHub documentation. Explains what GitHub Sponsors is, eligibility requirements for individual developers and organizations, the application process, and requirements for maintaining eligibility. Includes information about supported regions and compliance requirements.

**Category**: Project Planning - Funding

**Useful For**: Understanding GitHub Sponsors eligibility, planning open source funding strategies, meeting sponsorship requirements.

**Portability**: ⭐⭐⭐⭐⭐ Highly portable - General GitHub Sponsors information based on official documentation. Can be copied directly to any open source project.

---

### LICENSE_OPTIONS.md

**Location**: `dev-docs/info/LICENSE_OPTIONS.md`

**Summary**: Overview of common open-source licenses to help choose the right license for projects. Provides quick comparison tables, detailed explanations of permissive licenses (MIT, Apache 2.0, BSD variants), copyleft licenses (GPL, LGPL, AGPL), and guidance on license selection. Includes information about license compatibility and ease of use.

**Category**: Legal Reference - Licensing

**Useful For**: Choosing project licenses, understanding license implications, comparing license options.

**Portability**: ⭐⭐⭐⭐⭐ Highly portable - General license comparison information applicable to any software project. Can be copied directly.

---

### wayland-gamescope-window-tools.md

**Location**: `dev-docs/info/wayland-gamescope-window-tools.md`

**Summary**: Explains what Wayland and Gamescope are, and what the lack of window manager tools means for projects. Covers Wayland architecture, Gamescope compositor specifics, environment detection methods, and limitations of window management tools in these environments. Provides context for why certain tools may not work in Wayland/Gamescope environments.

**Category**: Technical Reference - Display Systems

**Useful For**: Understanding Wayland and Gamescope environments, troubleshooting window management issues, implementing display-aware features.

**Portability**: ⭐⭐⭐⭐⭐ Highly portable - General technical information about Wayland and Gamescope with no project-specific code. Can be copied directly to any Linux project working with these display systems.

---

## Template Files (`dev-docs/templates/`)

### doc-assessment-template.md

**Location**: `dev-docs/templates/doc-assessment-template.md`

**Summary**: Template for systematically assessing the accuracy, agreement, and completion of project documentation against the actual codebase. Provides a structured approach to verify that documentation correctly describes features, configuration options, installation procedures, and system requirements. Includes instructions for creating timestamped assessment copies.

**Category**: Template - Documentation Assessment

**Useful For**: Conducting documentation audits, ensuring documentation accuracy, systematic documentation review processes.

**Portability**: ⭐⭐⭐⭐ Highly portable - Universal template for documentation assessment. Can be copied to any project. May need minor customization for project-specific documentation structure.

---

### doc-refactor-assessment-template.md

**Location**: `dev-docs/templates/doc-refactor-assessment-template.md`

**Summary**: Template for assessing documentation that needs refactoring or reorganization. Provides structure for evaluating documentation structure, identifying areas for improvement, and planning documentation refactoring efforts.

**Category**: Template - Documentation Refactoring

**Useful For**: Planning documentation reorganization, identifying documentation structure issues, systematic documentation improvement.

**Portability**: ⭐⭐⭐⭐ Highly portable - Universal template for documentation refactoring. Can be copied to any project. May need minor customization for project-specific documentation structure.

---

### functionality-integrity-assessment-template.md

**Location**: `dev-docs/templates/functionality-integrity-assessment-template.md`

**Summary**: Template for assessing the integrity and correctness of code functionality. Provides a systematic approach to verify that code behaves as expected, handles edge cases properly, and maintains functional requirements.

**Category**: Template - Code Assessment

**Useful For**: Code quality reviews, functionality verification, systematic code assessment.

**Portability**: ⭐⭐⭐⭐⭐ Highly portable - Universal template for code functionality assessment. Can be copied directly to any software project.

---

### future-and-remaining-assessment-template.md

**Location**: `dev-docs/templates/future-and-remaining-assessment-template.md`

**Summary**: Template for assessing future enhancements and remaining work items. Provides structure for evaluating proposed features, prioritizing work, and tracking remaining tasks.

**Category**: Template - Project Planning

**Useful For**: Planning future work, prioritizing enhancements, tracking project progress.

**Portability**: ⭐⭐⭐⭐⭐ Highly portable - Universal template for project planning and enhancement tracking. Can be copied directly to any software project.

---

### qi-assessment-template.md

**Location**: `dev-docs/templates/qi-assessment-template.md`

**Summary**: Template for quality improvement assessments. Provides structure for evaluating code quality, identifying improvement opportunities, and planning quality enhancement efforts.

**Category**: Template - Quality Assessment

**Useful For**: Code quality reviews, identifying improvement areas, planning quality enhancement initiatives.

**Portability**: ⭐⭐⭐⭐⭐ Highly portable - Universal template for quality improvement assessment. Can be copied directly to any software project.

---

### refactor-assessment-template.md

**Location**: `dev-docs/templates/refactor-assessment-template.md`

**Summary**: Template for assessing code that needs refactoring. Provides structure for evaluating code structure, identifying refactoring opportunities, and planning code improvement efforts.

**Category**: Template - Code Refactoring

**Useful For**: Planning code refactoring, identifying code structure issues, systematic code improvement.

**Portability**: ⭐⭐⭐⭐⭐ Highly portable - Universal template for code refactoring assessment. Can be copied directly to any software project.

---

### safety-scan-template.md

**Location**: `dev-docs/templates/safety-scan-template.md`

**Summary**: Template for conducting safety scans of code and documentation. Provides structure for identifying security issues, safety concerns, and potential vulnerabilities.

**Category**: Template - Security Assessment

**Useful For**: Security audits, safety reviews, vulnerability assessment.

**Portability**: ⭐⭐⭐⭐⭐ Highly portable - Universal template for security and safety scanning. Can be copied directly to any software project.

---

### scan-general-reusable-info-template.md

**Location**: `dev-docs/templates/scan-general-reusable-info-template.md`

**Summary**: Template that instructs scanning project documentation for markdown files containing general information or reusable reference material. Provides guidelines for identifying general/reusable info files, instructions for updating this catalog, and format guidelines for entries.

**Category**: Template - Documentation Cataloging

**Useful For**: Maintaining this catalog, identifying reusable information files, documenting general reference materials.

**Portability**: ⭐⭐⭐⭐ Highly portable - Universal template for cataloging reusable information. Can be copied to any project. May need customization for project-specific directory structures.

---

### testing-assessment-template.md

**Location**: `dev-docs/templates/testing-assessment-template.md`

**Summary**: Template for assessing testing coverage, test quality, and testing strategies. Provides structure for evaluating test completeness, identifying gaps in test coverage, and planning testing improvements.

**Category**: Template - Testing Assessment

**Useful For**: Test coverage reviews, planning testing improvements, systematic testing assessment.

**Portability**: ⭐⭐⭐⭐⭐ Highly portable - Universal template for testing assessment. Can be copied directly to any software project.

---

## Portability Guide

### Portability Ratings

- ⭐⭐⭐⭐⭐ **Highly portable** - Can be copied directly to other projects with minimal or no changes
- ⭐⭐⭐⭐ **Portable** - Can be copied but may need minor customization for project-specific structures
- ⭐⭐⭐ **Moderately portable** - Contains some project-specific references that need adaptation
- ⭐⭐ **Low portability** - Requires significant modification for use in other projects
- ⭐ **Not portable** - Project-specific and not suitable for reuse

### Copying Files to Other Projects

When copying these files to other projects:

1. **Information files** (`dev-docs/info/`): Most can be copied directly. Check for any project-specific examples or references that may need updating.

2. **Template files** (`dev-docs/templates/`): Can generally be copied directly. Some may reference project-specific directory structures that should be adapted.

3. **Best practices**:
   - Review files for project-specific references before copying
   - Update any examples or references to match the new project
   - Maintain attribution if the original source is important
   - Consider creating a similar catalog in the new project

## How to Update This File

When scanning for new general/reusable information files:

1. **Follow the template**: Use `dev-docs/templates/scan-general-reusable-info-template.md` for guidance
2. **Only modify this file**: Do not edit the source information files or templates
3. **Add new entries**: Include file name, location, summary, category, use cases, and portability rating
4. **Review existing entries**: Check for accuracy and update summaries if information has changed
5. **Verify links**: Ensure all file paths and links are correct
6. **Assess portability**: Consider how easily each file can be copied to other projects

## Notes

- This catalog focuses on **general/reusable information** files, not project-specific plans or implementation details
- Template files are included as they are reusable resources for various assessment and documentation tasks
- Files in `dev-docs/enhancements/` are not included as they describe specific project features
- Plan files and completed plans are not included as they are project-specific implementation documents
- The primary purpose is to make it **easy to identify and copy useful reference materials to other projects**

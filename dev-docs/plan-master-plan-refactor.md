# Plan: Master Plan Refactor (High-Level + Detailed Subplans)

## Goal
Convert `dev-docs/linux-warning-system-plan.md` into a high-level master plan with summaries and top-level checklists, and split detailed checklists into multiple smaller plan files referenced by the master plan.

## Scope
- **In scope**: Documentation restructuring and file creation.
- **Out of scope**: Any code changes.

## Files to Update/Create
- Update: `dev-docs/linux-warning-system-plan.md` (master overview only)
- Create: section plan files (detailed checklists), proposed below

## Proposed New Plan Files
1. `dev-docs/plan-core-implementation.md`
   - Phase 1 details (scripts, config, popup behavior)
2. `dev-docs/plan-display-detection.md`
   - 1.4a, 1.4b, 1.4c detailed checklists
3. `dev-docs/plan-systemd-integration.md`
   - Phase 2 details
4. `dev-docs/plan-installation-deployment.md`
   - Phase 3 details
5. `dev-docs/plan-testing-validation.md`
   - Phase 4 details (functional, edge, install/uninstall, integration)
6. `dev-docs/plan-documentation-maintenance.md`
   - Phase 5 details (docs, maintenance, accessibility)
7. `dev-docs/plan-licensing-donations.md`
   - Phase 5.4/5.5 details

## Master Plan Content (High-Level)
- High-level description, scope, and goals
- Phase summaries with 3–8 top-level checklist items each
- Links to detailed plan files for each phase

## Implementation Steps
1. Extract detailed checklists from `dev-docs/linux-warning-system-plan.md` into the new plan files.
2. Replace detailed content in `dev-docs/linux-warning-system-plan.md` with:
   - Brief phase summaries
   - Top-level checklist bullets
   - Links to the new plan files
3. Ensure cross-links between master and subplans are correct.

## Approval Needed
Please confirm this plan and the proposed file split (or suggest adjustments) before I proceed.

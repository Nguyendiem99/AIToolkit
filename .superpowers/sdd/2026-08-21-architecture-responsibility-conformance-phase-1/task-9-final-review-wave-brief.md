# Task 9 final-review fix wave

## Baseline and constraints

- Worktree HEAD: `1001e2ce525d84bec710d93232498583a6d82b67`.
- Task 9 BASE: `0cbb95afb835263ecf3b52b36f5ec0605f903435`.
- Preserve exactly one Task 9 commit over BASE; amend only.
- Verify every finding against actual producer/contract before editing, then use strict RED -> GREEN.
- No overlapping suites and no source edit while a suite is active.
- Do not run the default/full mutation suite in the implementation wave.
- Do not touch Phase 2, `main`, or `issue/`.

## Required findings

1. Independent review inventory must account for every canonically classified changed Git path, including markerless `M/A/R/C` production paths, and compare pinned base versus final content so responsibility blocks/owners removed from surviving modified files enter deletion reconciliation. Every changed production path must reconcile to Change Hygiene plus approved responsibility/deletion authority. Reject markerless route/provider changes, omitted paths, and removed blocks. Do not classify irrelevant docs as production without canonical classification.
2. Require exact `approved` / `complete` / `human` lifecycle, canonical front matter, run binding, and order for every executable downstream assurance artifact at steps 12-15. Scope/terminal validation must inspect every chain node. Add stage-specific draft/blocked/auto/cross-run negatives.
3. An overall review conclusion other than canonical PASS/Approve is non-executable. Bind exact review conclusion/verdict to review handoff and queue eligibility; reject `Reject`, `BLOCKED`, Critical-bearing, or otherwise non-PASS reviews even when the architecture subverdict says PASS.
4. Incremental generic and `none` adapter flows must include regression before KB; greenfield may omit regression. Derive this from pinned approved external mode and adapter authority, not self-declared artifact text. Align migrate/KB skills, validator, templates/fixtures.
5. Resolve comparable-exemplar schema authority around one canonical 13-column discovery schema, or an explicit versioned adapter only if legacy compatibility is contractually required. Producers, target validation, responsibility validation, templates, enums, and examples must be compatible. Reject ambiguous seven-column/thirteen-column mixtures; test composed producer-to-target behavior.
6. Implementation Change Hygiene must canonically represent `File Kind = deleted`, with source/base/removal-diff evidence and no final-tree path requirement, matching independent-review reconciliation. Align skill/schema/template/validator and add a real deletion positive plus missing/stale/foreign evidence negatives.

## Verification and handoff

- Run affected focused scenarios.
- Run the corrected 13 short gates verbatim from `task-9-brief.md`: seven scenario scripts; `validate-migration-framework.ps1 -Check Contracts`, `Skills`, `Templates`, `All`, `SourceIntegrityOnly`; `git diff --check`.
- Run only the focused mutation selector `validate-migration-framework.Tests.ps1 -ResponsibilityConformanceOnly` (17 mutations).
- Append RED/GREEN/RCA and exact evidence to `task-9-report.md` and `progress.md`.
- Audit scope, stage only approved files, amend the sole Task 9 commit, and run exact-HEAD focused, All, SourceIntegrityOnly, diff/status/count checks.
- Return `DONE`, amended SHA, concise test evidence, and concerns. Do not dispatch subagents or reviewers.

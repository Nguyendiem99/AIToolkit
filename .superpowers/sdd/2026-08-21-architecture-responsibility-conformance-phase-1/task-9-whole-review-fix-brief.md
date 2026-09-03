# Task 9 whole-review final fix wave

## Baseline and constraints

- Exact clean starting HEAD: `c0acc0b823acfa7967400a188c4ba7d32cdc31ab`.
- Task 9 BASE: `0cbb95afb835263ecf3b52b36f5ec0605f903435`; preserve one amended Task 9 commit.
- Verify every finding against actual contracts/producers before editing; strict focused RED -> GREEN.
- One implementer owns the complete list. No subagents or reviewers.
- Do not run the default/full mutation suite. No overlap; no edits while any suite is active.
- No Phase 2, `main`, or `issue/` changes.

## Critical findings

1. Derive Verification Ownership aggregate PASS from every required verification row. Each row must have exact PASS, canonical non-placeholder Evidence Path, and non-placeholder Evidence Symbol or Scenario; BLOCKED/blank/pending must prevent structural PASS.
2. Remove discovery evidence extension allowlists. Validate safe canonical language-agnostic evidence references; accept Java/Python and other canonical paths, reject malformed/traversal/ambiguous references.
3. Pinned production inventory must reject framework-neutral markerless executable content before, between, or after valid responsibility blocks while preserving legitimate blank/comment-only content.
4. Bind ordinary body-only edits inside a responsibility block to that owner/path without requiring each added hunk to repeat metadata tokens. Add literal/control-flow/body positives and true out-of-block negatives.
5. Immutable JSON authority must require runtime Boolean type and exact `$true`; strings such as `"false"` must reject at every authority path.
6. Bind terminal-chain index 0 review `source_artifact_reference` to its implementation predecessor; later nodes remain immediate-predecessor bound.
7. Bind every terminal-chain SHA/evidence pair to immutable Task Provenance, not merely self-consistent values. Reject all-node forged SHA/evidence values.
8. Approved plan authority must bind exact `master_spec_id`, `master_spec_revision`, current immutable master plan, plan ID and revision before its mode controls regression ordering. Reject cross-spec/current-plan drift.
9. Review provenance must bind the reviewed final-tree SHA to the actual authorized checkout/current HEAD and require clean/source-integrity state; stale-but-existing SHAs cannot approve a later checkout.

## Important findings

10. Parse required verdict/control fields only from semantic visible Markdown. Fenced/commented examples must not satisfy responsibility or architecture review/template verdicts.
11. `SourceIntegrityOnly` must prove mutation/coverage assertions are active executable registrations, not raw token occurrences in comments/fences/inert text. Commented-out coverage must fail; active registrations pass.

## Verification

- Add focused real-behavior probes for every finding under Windows PowerShell 5.1.
- Run affected scenario suites, corrected 13 short gates verbatim, focused `-ResponsibilityConformanceOnly` 17 mutations, scope/AST/diff audit.
- Append RCA/RED/GREEN/evidence to `task-9-report.md` and `progress.md`.
- Stage only approved files, amend sole Task 9 commit, run exact-HEAD focused/All/SourceIntegrity/diff/status/count.
- Return DONE, SHA, tests, concerns. Full remains controller-owned.

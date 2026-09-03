# Task 8 implementation report

Status: DONE

Commit: `f4c1a38ad9458f3a832cae99a77690c5d1c7bd72 feat: block terminal scope on responsibility defects`

Task 8 now fails closed before queue selection and terminal completion when responsibility provenance is absent, non-v1, mixed, stale, cross-run, or structurally blocked. The migration orchestrator derives `architecture_conformance_state` from Tree Conformance, Responsibility Conformance, and Verification Ownership; a blocked sub-verdict prevents dependent selection and all downstream parity, regression, delivery, Knowledge Base, and terminal completion. Runtime `auto-waive` cannot replace a structural verdict.

Terminal authority now resolves immutable work-item artifacts, exact v1 handoffs, independent responsibility evidence, and an exact terminal Evidence Index. The FlexibleScope path requires the ordered incremental handoff chain `11-ai-review -> 12-verification-testing -> 13-verify-parity -> 14-verify-regression -> 15-knowledge-base`; the orchestrator contract also declares the greenfield chain `11-ai-review -> 12-verification-testing -> 13-verify-parity -> 15-knowledge-base`. Missing, reordered, skipped, duplicate, stale, cross-run, or caller-synthesized chains are not terminal authority.

## Requirements mapping

| Requirement | Implementation and evidence |
|---|---|
| Derive architecture from all three structural sub-verdicts | Scope engine and FlexibleScope calculate the conjunction of Tree, Responsibility, Verification Ownership, and the derived aggregate. Queue-global tests cover each blocked sub-verdict and forged aggregate PASS. |
| Stop queue and dependent work | Selection performs the structural stop before eligibility or fallback selection, returns `scope-blocked`, and leaves the selected work-item ID empty. |
| Stop parity, regression, delivery, KB, and terminal completion | `migrate/SKILL.md` contains the executable rollout/safe-stop table and the exact post-implementation stop chain; mutation tests remove or weaken each required clause. |
| Approved design/master-plan revision required to resume | The rollout table requires approved revision authority for structural defects, mixed evidence, and in-progress pre-v1 backfill. No automatic resume is permitted. |
| Completed pre-v1 is historical-only | The rollout contract makes it non-executable; the E2E terminal negative replaces executable terminal authority with historical evidence and is rejected. |
| In-progress pre-v1 and mixed v1/v2 block | Responsibility rollout mutations and E2E negative controls reject incomplete historical lifecycle and mixed responsibility versions. |
| Exact v1 handoff and immutable evidence | Scope completion resolves exact registry references, immutable work-item terminal artifacts, exact v1 handoff fields, independent review evidence, and the report-level evidence set. FlexibleScope digest-checks every ordered chain artifact and calls `Test-ResponsibilityHandoff` for every adjacent pair. |
| Auto-waive never overrides structural provenance | Scope/E2E tests preserve runtime waiver behavior while rejecting Responsibility BLOCKED under an aggregate PASS. |
| No Phase 2 auto-remediation | The orchestrator explicitly forbids automatically creating a Phase 2 artifact or work item, covered by mutation validation. |
| Exact 21 E2E scenarios | Responsibility negatives are subcases of the existing S19/S20 scenarios; the top-level fixture remains exactly 21 unique scenarios. |

## RED evidence

Focused REDs were captured before their corresponding production changes:

```text
responsibility-handoff.Tests.ps1
Missing command: Test-MigrationResponsibilityRollout

responsibility-handoff.Tests.ps1 (validator added, rollout contract absent)
migration-responsibility-rollout-invalid

scope-engine.Tests.ps1 (queue-global structural cases)
Expected: scope-blocked / no selected work item
Actual: selected / eligible-by-depth-plan-order-id

scope-engine.Tests.ps1 (terminal provenance cases)
Missing v1 and mixed v1/v2 terminal evidence both returned:
scope-complete / master-plan-completion-calculation

flexible-scope-e2e.Tests.ps1 (forged responsibility evidence)
Expected: terminal-scope-report-invalid / scope-blocked
Actual: scope-completion-calculated / scope-complete

flexible-scope-e2e.Tests.ps1 (aggregate PASS with Responsibility BLOCKED and auto-waive override)
Expected: structural-assurance-blocked / scope-blocked
Actual: terminal-scope-report-invalid / scope-blocked

flexible-scope-e2e.Tests.ps1 (exact ordered chain)
Exit 1: Flexible scope E2E fixture must declare the exact evidence envelope
S20 skipped-stage negative was accepted before responsibility_chain_refs enforcement.
```

Intermediate GREEN work exposed and corrected one tokenization typo (`Count -ne1`), field-order mismatch in the exact fixture envelope, and two unsafe first-row accesses. Each correction was followed by the focused E2E rerun before the final gate sequence.

## Fresh final GREEN evidence

All commands were run from the Task 8 worktree on the unchanged final source tree before staging:

```text
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\scope-engine.Tests.ps1
PASS: scope engine behavioral scenarios
Exit 0

powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-handoff.Tests.ps1
PASS: responsibility handoff scenarios
Exit 0

powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\flexible-scope-e2e.Tests.ps1
PASS: flexible migration scope orchestration (21 isolated E2E scenarios)
Exit 0

powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check All
PASS: migration framework (All)
Exit 0

git diff --check
Exit 0
```

Strict UTF-8 decoding passed for both modified Markdown source files. Before commit, `git diff --name-only` and the cached-path audit contained exactly the eight Task 8-owned files; the final diff was 694 insertions and 51 deletions. The Task 8 range from `8c0e78b` contains exactly the single required commit.

## Pending non-owned seam

This Task 8 result does not claim the entire migration producer pipeline is complete. The current Task 6 producer schema is not yet compatible with the Task 7/8 terminal consumer contract:

- `aitoolkit/templates/migration/review-report.md` emits `status: draft` and does not contain `Task Provenance` or `Architecture Responsibility Handoff`.
- `aitoolkit/skills/shared/ai-review/SKILL.md` does not instruct the producer to emit that exact v1 handoff/provenance envelope.

Those files are outside Task 8 ownership and were not changed. Closing the seam requires a Task 6-owned update to those two files plus focused Task 6 architecture-review/responsibility validation. Until then, Task 8's terminal enforcement is proven with explicit Task 7-contract fixtures, but the live Task 6 review artifact cannot yet originate that chain unchanged.

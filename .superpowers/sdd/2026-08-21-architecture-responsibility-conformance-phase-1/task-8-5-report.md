# Task 8.5 implementation report

Status: DONE; scoped review clean

Base: `548756e2ab8089c391c87471eaab138a50532f7d`

Commit: `0cbb95afb835263ecf3b52b36f5ec0605f903435 fix: emit responsibility review handoff evidence`

## Authoritative producer routing

The authoritative migration producer template is `aitoolkit/templates/migration/review-report.md`:

- `skills/aitoolkit/migrate/SKILL.md` explicitly routes migration step 11 to it and excludes the shared legacy template from migration rendering.
- `tests/validate-migration-framework.ps1` registers `shared/ai-review -> templates/migration/review-report.md` while retaining `templates/review-report.md` for feature/bugfix.
- Template integrity checks validate the migration-specific title, activation envelope, selected-unit routing, lifecycle, Task Provenance, and Architecture Responsibility Handoff on that path.

`aitoolkit/templates/review-report.md` was not changed.

## Implementation

- Added the canonical bounded migration review front matter with step 11 identity, lifecycle, approval source, production date, and responsibility contract v1 discriminator. Draft output omits `approval_source`; approved output uses the canonical `human | auto | auto-waive` enum, while executable terminal authority remains `approved/complete/human`.
- Expanded `Master Scope Context` to the exact eight-field current-run/master/work-item envelope consumed by the Task 8 initial-review resolver, while keeping adapter kind as a separate producer field for conditional selected-unit rendering.
- Added exact `Task Provenance` and `Architecture Responsibility Handoff` tables. The handoff derives architecture from the three independent review verdicts and binds evidence to `source-diff:<task-base>..<final-tree>#<work-item>`.
- Updated `shared/ai-review` to distinguish draft/pending production from approved/complete/human downstream authority, require the exact immediate predecessor, reject stale/cross-run/mismatched provenance, and forbid implementation self-attestation as handoff evidence.
- Rendered the real migration review template in both the focused Task 7 handoff suite and the Task 8 exact-21 FlexibleScope E2E fixture. The E2E rehashes and rebinds an artifact with a foreign immediate-predecessor path and proves the existing consumer rejects it; no consumer validation was weakened.
- Extended architecture/template integrity validation to protect the new producer schema and routing.

## TDD evidence

RED command:

```text
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-handoff.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\flexible-scope-e2e.Tests.ps1
```

Both exited `1` before producer changes with:

```text
Migration review producer template is missing seam token: status: <draft | approved>
```

This was the expected failure: artifacts rendered from the authoritative producer lacked the lifecycle/provenance/handoff v1 envelope required by the existing consumers.

GREEN evidence on the implementation tree:

```text
responsibility-handoff.Tests.ps1
PASS: producer-rendered migration review starts the responsibility handoff chain
PASS: producer-rendered migration review cannot omit task provenance
PASS: producer-rendered migration review cannot bind a stale final-tree SHA
PASS: responsibility handoff scenarios

architecture-review.Tests.ps1
PASS: architecture review scenarios

flexible-scope-e2e.Tests.ps1
PASS: flexible migration scope orchestration (21 isolated E2E scenarios)

validate-migration-framework.ps1 -Check Skills
PASS: migration framework (Skills)

validate-migration-framework.ps1 -Check Templates
PASS: migration framework (Templates)

validate-migration-framework.ps1 -Check All
PASS: migration framework (All)
```

The full mutation suite was intentionally not run, as required by Task 8.5.

## Scoped review fix round 1

The initial independent review reported 0 Critical and 2 Important findings:

- `approval_source: pending` was outside the activation contract's canonical `human | auto | auto-waive` enum. RED: `-Check Templates` rejected the old producer token. The producer template, instructions, renderers, and integrity gate now use the canonical enum and explicitly omit the field for draft artifacts.
- The producer seam lacked an E2E negative for a wrong `Task Provenance.Source Artifact`. The exact-21 E2E now mutates the rendered review to `foreign-implementation-report.md`, recomputes immutable references, rebinds the chain, and proves the terminal consumer rejects it.

All focused gates above passed after both corrections. The existing implementation commit was amended in place, preserving exactly one commit from base. Scoped re-review of amended SHA `0cbb95afb835263ecf3b52b36f5ec0605f903435` returned APPROVE with 0 Critical and 0 Important findings; both prior findings were explicitly marked ADDRESSED.

## Files changed

- `aitoolkit/skills/shared/ai-review/SKILL.md`
- `aitoolkit/templates/migration/review-report.md`
- `aitoolkit/tests/scenarios/architecture-review.Tests.ps1`
- `aitoolkit/tests/scenarios/flexible-scope-e2e.Tests.ps1`
- `aitoolkit/tests/scenarios/responsibility-handoff.Tests.ps1`
- `aitoolkit/tests/validate-migration-framework.ps1`
- `aitoolkit/tests/validation/architecture-review.validation.ps1`

No `issue/`, legacy feature/bugfix review template, or broad mutation-suite source was changed.

## Self-review

- Producer and consumer use one existing canonical handoff schema; no new enum or parallel schema was introduced.
- The consumer remains fail-closed and retains approved/complete/human, current-run/master/work-item, immutable digest, 40-character SHA, and exact source-diff checks.
- The producer handoff is derived only after independent Task 6 inventory review and does not copy implementation PASS.
- `git diff --check` is clean; scoped independent re-review is clean with 0 Critical and 0 Important findings.

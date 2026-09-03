# Task 3 Report — Technical design responsibility and verification matrices

## Status

DONE

## Commit

`9985bee` — `feat: require responsibility evidence in designs`

## Files

- Updated the technical-design skill and template with v1 responsibility front matter and exactly one canonical File Responsibility Matrix plus Verification Ownership Matrix after Planned File Tree.
- Implemented `Test-ResponsibilityDesign` for bounded v1 artifact evidence, exact planned-tree/owner tuple coverage, unique IDs, discovery-authority consumption, co-location policy, mode authority, controlled verification disposition, and two-way production verification binding.
- Routed target conformance to the design helper only after its existing discovery/exemplar, matrix, planned-tree, boundary, activation, and approved-deviation checks pass.
- Added responsibility fixtures for aggregate rejection, feature-local/shared-foundation/atomic acceptance, legacy-debt rejection, trace-versus-capability separation, cross-language owner paths, and target rejection of missing matrices.

## RED evidence

Before the implementation, the responsibility scenario failed as expected because a multi-capability aggregate had no diagnostic:

```text
aggregate capabilities require approval expected co-location-approval-missing but got:
```

Before target integration, the target scenario failed as expected because a technical design without responsibility matrices was accepted:

```text
target conformance rejects a design without responsibility matrices should fail but passed
```

## GREEN evidence

All required Task 3 gates completed with exit code 0:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-conformance.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\target-conformance.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Contracts
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Templates
```

Focused output includes the five required design fixtures, all three Dart/Java/Python owner paths with the same verdict, the missing-matrix target rejection, and both scenario suite PASS lines.

## Self-review

- The template uses the canonical 20/11 column orders without copying enum definitions.
- Capability and trace identifiers are parsed separately; `REQ-101`, `AC-202`, and `WORK-ADMIN-LOCK` remain valid traces for one capability.
- Discovery classification authority/evidence are required and target exemplars resolve against approved discovery evidence.
- Matrix cardinality, controlled sentinels, atomic/shared/multi-capability policy, greenfield authority, and production binding fail closed.
- `git diff --check` and `git diff --cached --check` were clean before commit. Only the six Task 3-owned paths were staged; no `issue/` path changed.

## Concerns

None for the required focused gates.

## Fix round 1/5

Independent review findings were addressed before amending the single Task 3 commit:

- Duplicate File Responsibility/Verification Ownership headings now fail closed.
- A row claiming `Boundary Kind = test` must also live under a test path and declare verification work; otherwise it cannot evade production verification coverage.
- Verification verdicts are constrained to the canonical PASS/BLOCKED set.
- Atomic ownership now requires Tech Lead approval evidence in addition to the transaction/lifecycle/revert boundary.
- Multi-capability deviations require a matching approved structural-deviation row and approval reference.
- Target conformance preserves its registered entry signature and derives greenfield mode only from the exact `Architecture` table's `Mode / Policy` value before forwarding it to responsibility validation; unbounded body text cannot override mode.
- Contradictory or duplicate canonical mode rows now block target conformance instead of selecting a mode opportunistically.

The focused responsibility scenario includes regressions for duplicate matrices, the self-labeled-test bypass, and a noncanonical verification verdict.

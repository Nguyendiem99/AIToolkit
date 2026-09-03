# Task 5 Report — Code-migration responsibility pre-edit gate

## Status

DONE

## Base

`2d89b8cf6685ad6e10204399acefb9224f12995e`

## Delivered

- Added the v1 discriminator and exact Actual File Responsibility Matrix, Actual Verification Ownership Matrix, and Architecture Responsibility Verdicts to the implementation template.
- Updated code-migration to resolve approved responsibility design/plan evidence before RED/TDD, baseline capture, worktree mutation, or target edit, and to record source/diff-backed actual ownership after implementation.
- Implemented exact two-way planned/actual responsibility and verification comparison, including authoritative path/symbol, public symbols, capabilities/traces, effects, architecture/co-location authority, verification production binding, actual evidence, controlled disposition, and derived architecture state.
- Integrated discovery, design, selected migration-plan owner binding, and implementation responsibility validation into the structural gate without weakening existing tree, selector, boundary, activation, deviation, or assurance checks.
- Uplifted the stale canonical structural fixture to the approved Task 1–4 contracts: 13-column discovery, `DESIGN-401@6`, exact 20/11 design matrices, exact plan work-item owner references, and exact actual/evidence matrices.
- Added structural cases for tree-preserving extra public symbol/effect, runtime waiver, missing/extra owner, capability/effect/co-location drift, fake production binding, and forbidden `not-applicable-approved`.

## TDD evidence

Compatibility baseline after fixture uplift and before Task 5 enforcement:

```text
PASS: structural gate (130 scenarios)
```

RED after adding Task 5 cases, before enforcement:

```text
behavior owner cannot use not-applicable-approved verification expected verification-disposition-invalid but got: verification-production-binding-missing
tree match cannot hide extra ownership expected error containing 'responsibility-public-symbol-mismatch', got:
```

GREEN after implementation:

```text
PASS: responsibility conformance contract
PASS: structural gate (139 scenarios)
PASS: target conformance scenarios
PASS: migration framework (Skills)
PASS: migration framework (Templates)
```

Commands:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-conformance.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\structural-gate.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\target-conformance.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Skills
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Templates
```

All listed GREEN commands exited `0`. `git diff --check` exited `0`; Git emitted only line-ending conversion warnings.

## Scope

Only the six Task 5-owned paths were modified. No `issue/` path changed.

## Review fix round 1

The scoped review found three blocking gaps: structural PASS did not require all responsibility sub-verdicts to PASS; generic/none adapters skipped approved plan-owner validation; and actual comparison used every design owner instead of the selected work-item owner set.

Fixes:

- Added exact `Responsibility Plan Reference` and copied `Responsibility Owner References` evidence to the implementation report.
- Scoped planned/actual responsibility and verification comparison to the selected owner IDs, with an accepted multi-work-item design regression.
- Required every adapter kind to resolve the explicit approved step-08 plan and exact owner-reference row; generic adapters use `Migration Unit ID = not-applicable` without inventing a unit.
- Required Tree, Responsibility, Verification Ownership, and derived Architecture Conformance verdicts all to be `PASS` for structural success.

Fix-round RED evidence:

```text
selected owner set should exclude unrelated design work but got: responsibility-owner-missing; verification-owner-missing
structural PASS requires every responsibility sub-verdict PASS expected error containing 'Structural gate tree, responsibility, and verification ownership verdicts must all PASS', got:
```

Fix-round GREEN evidence:

```text
PASS: actual comparison is scoped to selected plan owners
PASS: responsibility conformance contract
PASS: structural gate (141 scenarios)
```

## Review fix round 2

Scoped re-review confirmed the original three findings were addressed, then found two Important fix-diff issues: structural validation required the whole plan owner table to have one row, and generic plan authority lacked an exact plan revision binding.

Fixes:

- Structural validation now selects exactly the current work-item adapter/owner row from a multi-work-item plan and validates a selected-row projection, leaving unrelated plan rows outside this isolated gate.
- `Responsibility Plan Reference` now carries the exact positive plan revision; the gate matches it to bounded approved plan front matter and binds the selected plan adapter to the current master-plan path/revision and design revision.

Fix-round GREEN evidence:

```text
PASS: structural gate (143 scenarios)
```

New scenarios accept a multi-work-item responsibility plan for the current selected row and reject a stale generic responsibility-plan revision.

## Review fix round 3

Re-review found that a generic/none responsibility-plan adapter row could still invent a concrete `UNIT-*`. The structural gate now requires the selected plan adapter's Migration Unit ID to equal the canonical external ID only for `migration-unit`; every other adapter kind requires exact `not-applicable`.

RED:

```text
generic adapter responsibility plan cannot invent a migration unit expected error containing 'responsibility-owner-extra', got:
```

GREEN:

```text
PASS: structural gate (144 scenarios)
```

## Final review and commit

Fresh scoped review completed after three bounded fix rounds. Final verdict: all findings addressed, no new Critical/Important breakage.

Commit:

`454ae86` — `feat: gate migration edits on responsibility`

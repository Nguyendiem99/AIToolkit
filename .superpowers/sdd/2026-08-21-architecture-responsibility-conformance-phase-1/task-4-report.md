# Task 4 Report — Bind plan-waves work items to responsibility owners

## Status

DONE

## Base and commit

- Base: `9985beeb812a865b5ebbde20a05d584a4ab05b38`
- Commit: `2d89b8c` — `feat: bind migration plans to responsibility owners`

## Delivered contract

- `Test-ResponsibilityPlan` now fail-closes plan evidence: it validates the approved technical-design stage/revision, plan stage/result, exact bidirectional `Work Item ID` cardinality between adapter trace and owner references, exact ordered owner groups, design-owned verification references, and immutable boundary evidence.
- `Responsibility Owner References` separates concrete, shared-foundation, and integration/composition `RESP-*` IDs and must preserve the exact ordered design set.
- The migration-plan template and plan-waves skill preserve the contract without restating the canonical responsibility matrices. Skills/Templates selector checks reject removal or mutation of the required contract tokens/columns.

## RED → GREEN evidence

Initial RED failed because `Test-ResponsibilityPlan` returned only a contract-version check; the missing-owner case received no diagnostic.

The focused suite subsequently verified rejection of missing, foreign, duplicate, wrong-category, stale (including both plan/adapter fields), unapproved, cross-work-item, duplicate-work-item, and unbound-adapter references; forged boundary prose; wrong plan stage; and missing design revision.

Focused GREEN commands (all exit 0):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-conformance.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\target-conformance.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Skills
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Templates
git diff --check
```

## Review ledger

### Fix round 1

Initial independent review found two Critical issues and one Major: owner-reference rows were not bidirectional with adapter rows; design revision was only compared within the plan; and boundary evidence accepted forged prose. Fixed with exact adapter/reference set matching, authoritative design revision matching, and canonical immutable reference parsing.

### Fix round 2 / authorized seam exception

Re-review found that the Task 3 technical-design template did not emit the new authoritative revision and that plan stage was unchecked. Parent authorized the narrow seam expansion. The technical-design template/skill now emit and document `revision: DESIGN-*@<positive integer>`; the responsibility validator and target fixture enforce/use it; Skills/Templates integrity checks protect it. `Test-ResponsibilityPlan` now requires `step_id: 08-plan-waves`, an allowed plan status, and `result: complete`.

No unrelated Task 3 semantics were changed.

### Fix round 3

Fresh review found a duplicate adapter-heading bypass, absent migration-unit identity validation, and a generic-adapter trace contradiction. The plan helper now requires exactly one adapter heading, unique work-item rows, and unique canonical `UNIT-*` IDs for migration-unit rows. Generic adapters use the same adapter-trace mechanism with `Migration Unit ID = not-applicable`, preserving their external work-item taxonomy while keeping responsibility binding bidirectional. A regression covers each added fail-closed path. The claim that pipe-delimited verification references are canonical was checked against the existing Task 3 validator: Markdown cells are parsed with comma/semicolon lists there, so Task 4 preserves that existing executable representation rather than introducing an incompatible raw-pipe table cell.

### Final scoped review

Fresh scoped re-review approved the final diff with no Critical, Important, or Minor findings.

## Scope

Task 4 ownership was modified, plus the explicitly authorized technical-design revision seam and the target-conformance integration fixture required to keep that seam executable. No `issue/` path changed.

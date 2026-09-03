# Task 1 Report — Canonical responsibility contract and validation core

## Status

DONE

## Files

- Created `aitoolkit/contracts/file-responsibility-conformance.md`.
- Created `aitoolkit/tests/validation/responsibility-conformance.validation.ps1`.
- Created `aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1`.
- Updated `aitoolkit/contracts/target-structure-conformance.md` with the sole-authority route and Structural PASS formula.
- Updated `aitoolkit/skills/aitoolkit-schemas/SKILL.md` to route responsibility fields to the canonical contract without copying enums.
- Updated `aitoolkit/tests/validate-migration-framework.ps1` to validate the canonical resource, helper parseability, schema route, and all public entry points.
- Updated `aitoolkit/tests/validate-migration-framework.Tests.ps1` with deletion, table-order, evidence-kind/disposition, and entry-point mutation registration.

## Commit

- `7d3aa74377845b3a4d0b48c691df7c00d88c89b3` — `feat: define responsibility conformance contract`

## RED evidence

Command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-conformance.Tests.ps1
```

Observed failure before implementation:

```text
Responsibility contract file is missing
```

The failure came from the intentionally absent canonical contract, not a PowerShell parse error.

## GREEN evidence

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-conformance.Tests.ps1
```

```text
PASS: responsibility conformance contract
```

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Contracts
```

```text
PASS: migration framework (Contracts)
```

Additional fresh checks passed:

```text
PASS: responsibility contract mutation checks
PASS: responsibility stage domain-invalid diagnostic
```

## Self-review

- The canonical matrices use the approved ordinal 20/11 column schemas.
- `Owned Capability IDs` and `Trace IDs` remain separate; no class-name or line-range heuristic is accepted as responsibility evidence.
- `approved-greenfield-design` is independent architecture authority; `not-applicable-approved` is only a verification disposition; runtime waivers do not alter the structural PASS/BLOCKED verdict.
- Markdown parsing checks duplicate headings, exact table columns, doubled boundaries, missing separators, mixed sentinels, and mixed CRLF/LF input.
- Stage functions return stable diagnostics for domain-invalid contract text. No `issue/` path was changed.
- `git diff --cached --check` was clean before commit.

## Concerns

None for the required focused gates.

## Fix round 1/5

### Status

DONE

### Findings fixed

1. Verification rows now parse their `Evidence Kind` and `Verification Disposition` cells independently. Both sentinel orderings reject a sentinel in the Evidence Kind column with the stable `ARC-CONTRACT-VERIFICATION-EVIDENCE-KIND` diagnostic.
2. All six stage gates now read `version: 1` and `applicability: required` only from bounded front matter through `Get-ArcBoundedFrontMatter`; raw body lines are rejected.

### Files

- Updated `aitoolkit/tests/validation/responsibility-conformance.validation.ps1`.
- Updated `aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1`.
- Updated `aitoolkit/tests/validate-migration-framework.Tests.ps1`.

### Commit

- `1e9c3a3f031079eeb1fdb4c3d2483cf5750f5ac6` — `fix: harden responsibility conformance validation`

### RED evidence

After adding the two ordering cases, before the production fix:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-conformance.Tests.ps1
```

```text
Expected evidence-kind diagnostic for verification evidence kind cannot use required before not-applicable-approved disposition:
```

This proved the old whole-row, order-dependent sentinel regex emitted no diagnostic. The new stage cases likewise target a body containing only raw `version: 1` and `applicability: required` lines.

### GREEN evidence

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-conformance.Tests.ps1
```

```text
PASS: responsibility conformance contract
```

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Contracts
```

```text
PASS: migration framework (Contracts)
```

```text
PASS: mutation suite parse
```

### Self-review and concerns

- The regression scenario executes both sentinel orderings and all six public stage gates against raw body-only version fields.
- The mutation suite registers both sentinel orderings against the canonical verification row.
- `git diff --cached --check` passed before the fix commit.
- Concerns: none for the required focused gates.

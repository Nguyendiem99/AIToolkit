# Activation Slice Remediation Cycle 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore the established step-10 baseline-waiver resume path while completing machine-readable implementation/test linkage and strict Source Reference enrichment.

**Architecture:** Keep Activation Slice validation one-way with respect to global artifact lifecycle: activation errors force `draft/blocked`, while a structurally valid slice may coexist with the exact pre-existing step-10 `approved/partial/auto-waive` tuple. Extend the canonical contract with explicit resume/linkage/enrichment rules and derive focused validator behavior and fixtures from those rules.

**Tech Stack:** Markdown Agent Skills/templates/contracts, PowerShell validator and mutation/scenario tests, Git.

## Global Constraints

- Scope is limited to the three residual final-review findings from F-01.
- Preserve the existing baseline-waiver semantics: a valid resumed step-10 artifact remains exactly `status: approved`, `result: partial`, `approval_source: auto-waive`.
- Activation errors still require exactly `status: draft`, `result: blocked`; they can never be waived or reported partial.
- A structurally valid Activation Slice must not prohibit a globally valid partial outcome caused by a non-activation concern.
- Step-10 initial implementation accepts approved step-08/09 predecessors; step-10 waiver resume additionally accepts only the exact approved/partial/auto-waive prior step-10 tuple and preserves its envelope.
- Every structured changed-file/test record has non-empty contract-declared fields, ASCII `UNIT-[0-9]{3}`, and the same selected unit across selected-unit, changed-file, test-evidence, current step, and predecessor records.
- Source Reference enrichment is either exact retention or exact prefix `"<predecessor>; "` followed by non-whitespace new evidence.
- `aitoolkit/contracts/activation-slice.md` remains the single rule source.
- Do not modify command lifecycle, waiver eligibility, snapshot workspace, immutable-attempt, or terminal Knowledge Base semantics.
- Do not edit or stage the user-owned `aitoolkit/skills/aitoolkit/migrate/SKILL.md`.
- Preserve UTF-8 and avoid unrelated/EOL churn.

---

### Task 1: Waiver Resume Compatibility and Complete Structured Linkage

**Files:**
- Modify: `aitoolkit/contracts/activation-slice.md`
- Modify: `aitoolkit/skills/migration/code-migration/SKILL.md` only if the canonical resume/linkage wording needs alignment
- Modify: `aitoolkit/templates/migration/implementation-report.md` only if a required selected-unit/link field is absent
- Modify: `aitoolkit/tests/validate-migration-framework.ps1`
- Modify: `aitoolkit/tests/validate-migration-framework.Tests.ps1`

**Interfaces:**
- Consumes: Existing Activation Slice contract definition, step-10 resume tuple, selected migration unit table, structured changed-file/test tables, artifact/handoff/link validators.
- Produces: Contract-derived lifecycle exception for valid non-activation partial resume, exact resume predecessor validation, complete unit/file/test record validation, and strict append-only Source Reference enrichment.

- [ ] **Step 1: Add failing waiver-resume lifecycle and predecessor scenarios**

Add focused fixtures through the real artifact/link validator:

```text
PASS: structurally valid step-10 resume artifact with status approved, result partial, approval_source auto-waive, exact waiver tuple, and prior approved/partial step-10 predecessor
BLOCK: activation-invalid slice using approved/partial/auto-waive
BLOCK: partial artifact without exact approved baseline waiver
BLOCK: prior step-10 predecessor missing approved/partial/auto-waive tuple
BLOCK: prior step-10 predecessor changes/losses Activation Slice envelope
BLOCK: non-step-10 predecessor attempts resume path
```

Run:

```powershell
& .\aitoolkit\tests\validate-migration-framework.Tests.ps1 -ActivationSliceScenariosOnly
```

Expected RED: the valid resume fixture is rejected by the current nonblocking lifecycle and predecessor rules.

- [ ] **Step 2: Implement minimal canonical lifecycle/resume rules**

In the canonical contract, distinguish:

```text
activation-blocking lifecycle: draft/blocked only
ordinary nonblocking lifecycle: draft/complete | approved/complete
step-10 baseline-waiver resume lifecycle: approved/partial/auto-waive only when the exact existing waiver tuple is present and activation validation itself is nonblocking
```

Declare allowed predecessor roles:

```text
initial step 10: approved step 08 or approved step 09
resumed step 10: approved/partial/auto-waive prior step 10 with exact envelope preservation
```

Parse these declarations into the existing contract definition object and apply them without weakening activation-blocking behavior.

- [ ] **Step 3: Verify waiver-resume GREEN**

Run the focused scenario suite. Expected: valid resume passes; every invalid resume/activation-blocking fixture fails with its specific diagnostic.

- [ ] **Step 4: Add failing complete structured-record scenarios**

Mutate real step-10 fixtures one field at a time:

```text
Changed Files: blank Migration Unit ID, File, Change, Activation Slice ID, Seam, or Trace IDs
Test Evidence: blank Migration Unit ID, Test, Command, Result, Activation Slice ID, Seam, or Trace IDs
Invalid/non-ASCII unit ID
Changed-file unit differs from Selected Migration Unit
Test-evidence unit differs from Selected Migration Unit
Current artifact unit differs from predecessor selected unit
Changed-file and test records resolve to a real slice/seam but not the selected unit
```

Expected RED: current validator accepts at least the non-link blank/inconsistent fields identified by review.

- [ ] **Step 5: Implement complete linkage validation**

Consume the canonical structured-record column declarations. Require every declared field non-empty, validate ASCII `UNIT-[0-9]{3}`, extract exactly one Selected Migration Unit, and enforce the same unit across current selected-unit, predecessor selected-unit, changed-file rows, and test-evidence rows. Retain existing slice/seam/trace resolution.

- [ ] **Step 6: Add failing strict Source Reference enrichment scenarios**

Add predecessor/successor handoff cases:

```text
PASS: exact retention
PASS: `<predecessor>; <non-whitespace evidence>`
BLOCK: `<predecessor>;`
BLOCK: `<predecessor>;   `
BLOCK: `<predecessor>;new evidence`
BLOCK: replacement or non-prefix enrichment
```

Expected RED: empty/unspaced suffix cases currently pass.

- [ ] **Step 7: Implement strict append-only enrichment**

Require either ordinal exact equality or ordinal prefix `"$predecessor; "` with a trimmed, non-empty suffix. Add the rule to the canonical contract and validate its token/shape through Contracts tests.

- [ ] **Step 8: Run focused and selector verification**

Run:

```powershell
& .\aitoolkit\tests\validate-migration-framework.Tests.ps1 -ActivationSliceScenariosOnly
& .\aitoolkit\tests\validate-migration-framework.Tests.ps1 -ActivationSliceContractOnly
& .\aitoolkit\tests\validate-migration-framework.ps1 -Target Contracts
& .\aitoolkit\tests\validate-migration-framework.ps1 -Target Templates
& .\aitoolkit\tests\validate-migration-framework.ps1 -Target Skills
& .\aitoolkit\tests\validate-migration-framework.ps1 -Target Encoding
```

Expected: every command exits 0. Run every other public selector independently. Run the full harness once; do not claim it passes if the excluded dirty migrate skill remains its blocker.

- [ ] **Step 9: Inspect and commit scoped changes**

Run scoped `git diff --check`, inspect `git diff --cached --name-only`, confirm `migrate/SKILL.md` is absent, then commit:

```powershell
git commit -m "fix: preserve activation slice waiver resume"
```

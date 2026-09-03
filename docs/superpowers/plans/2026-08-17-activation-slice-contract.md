# Activation Slice Contract Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enforce one traceable, end-to-end Activation Slice contract across migration discovery, planning, implementation, and review so a config/profile/capability-driven module cannot be declared ready while an activation seam is missing.

**Architecture:** Add one canonical reference contract under `aitoolkit/contracts/`, then make each relevant skill consume and preserve that contract through a fixed `## Activation Slice` template section. Extend the existing PowerShell validator and its mutation-based regression suite before editing production skill/template content, so missing resources, sections, columns, gate language, seam coverage, and handoff rules fail deterministically.

**Tech Stack:** Markdown Agent Skills, Markdown artifact templates, PowerShell validator/tests, Git.

## Global Constraints

- Scope is F-01 only; do not change command lifecycle, waiver, snapshot workspace, or immutable-attempt semantics.
- `aitoolkit/contracts/activation-slice.md` is the single definition source; step skills reference it and add only step-specific responsibilities.
- Applicable slices use stable `ACT-###` IDs and exactly nine semantic seams.
- Missing activation seam evidence that can prevent activation yields `status: draft` and `result: blocked`; it cannot degrade to `partial`.
- `deferred-approved` requires both a decision reference and a destination migration unit ID.
- Router ownership and asynchronous reselection/lifecycle decisions must be explicit before technical design is executable.
- Preserve the user's existing uncommitted change in `aitoolkit/skills/aitoolkit/migrate/SKILL.md`.
- Preserve UTF-8 artifact content and avoid whole-file formatting or line-ending churn.

---

### Task 1: Canonical Activation Slice Contract and Contract Validation

**Files:**
- Create: `aitoolkit/contracts/activation-slice.md`
- Modify: `aitoolkit/tests/validate-migration-framework.ps1`
- Modify: `aitoolkit/tests/validate-migration-framework.Tests.ps1`

**Interfaces:**
- Consumes: Design enums and gate rules from `docs/superpowers/specs/2026-08-17-activation-slice-contract-design.md`.
- Produces: Canonical headings/tokens and a validator contract that later skills/templates reference: `Activation Slice`, `ACT-###`, nine seam names, applicability/disposition/status enums, router policies, async lifecycle fields, and blocking semantics.

- [ ] **Step 1: Write failing resource/contract tests**

Append mutation tests that call the public `Contracts` selector and assert failures for a missing resource and for each mandatory token group. The test shape must restore exact original bytes in `finally` blocks:

```powershell
$activationContractFixture = Join-Path $PSScriptRoot '../contracts/activation-slice.md'
$contracts = Invoke-Validator 'Contracts'
Assert-True ($contracts.ExitCode -eq 1) "Missing Activation Slice contract should fail. Output: $($contracts.Output)"
Assert-Contains $contracts.Output 'FAIL: Missing Activation Slice contract resource' 'Activation Slice resource'
```

After the file exists, add mutation cases replacing canonical tokens such as `upstream-response`, `deferred-approved`, `compatibility-dual-path`, and `result: blocked`, and assert the validator reports the exact missing contract token.

- [ ] **Step 2: Run RED tests and confirm the expected failure**

Run:

```powershell
& .\aitoolkit\tests\validate-migration-framework.Tests.ps1
```

Expected: FAIL at the new Activation Slice resource assertion because `aitoolkit/contracts/activation-slice.md` does not exist. Confirm it is not a syntax/path error.

- [ ] **Step 3: Add minimal validator production behavior**

In `Test-Contracts`, resolve `../contracts/activation-slice.md`, fail with `Missing Activation Slice contract resource` when absent, and use `Require-Token` for:

```text
ACT-###
applicable | not-applicable-approved | unknown
upstream-response
requested-key
parse-model
state-holder
selector
construct
render
downstream-consumer
test
implement | reuse | deferred-approved | not-applicable-approved
verified | missing | conflict | unknown
base-owned
specialized-owned
injected-strategy
compatibility-dual-path
result: blocked
```

- [ ] **Step 4: Create the minimal canonical contract**

Write `aitoolkit/contracts/activation-slice.md` with these focused sections:

```markdown
# Activation Slice Contract

## Applicability
## Canonical seams
## Artifact row schema
## Completion and blocking rules
## Router ownership
## Async lifecycle
## Handoff invariants
## Quick reference
## Common mistakes
```

Define exact row columns:

```text
Activation Slice ID | Applicability | Seam | Input | Output | Source Reference | Trace IDs | Disposition | Status | Decision Reference | Deferred Unit ID
```

- [ ] **Step 5: Run GREEN contract validation**

Run:

```powershell
& .\aitoolkit\tests\validate-migration-framework.ps1 -Target Contracts
```

Expected: `PASS` and exit code 0.

- [ ] **Step 6: Commit Task 1**

```powershell
git add -- aitoolkit/contracts/activation-slice.md aitoolkit/tests/validate-migration-framework.ps1 aitoolkit/tests/validate-migration-framework.Tests.ps1
git commit -m "feat: define activation slice contract"
```

### Task 2: Template Envelope and Schema Drift Validation

**Files:**
- Modify: `aitoolkit/templates/migration/discovery.md`
- Modify: `aitoolkit/templates/migration/inventory.md`
- Modify: `aitoolkit/templates/migration/mapping.md`
- Modify: `aitoolkit/templates/migration/gaps-conflicts.md`
- Modify: `aitoolkit/templates/migration/technical-design.md`
- Modify: `aitoolkit/templates/migration/migration-plan.md`
- Modify: `aitoolkit/templates/migration/implementation-report.md`
- Modify: `aitoolkit/templates/migration/review-report.md`
- Modify: `aitoolkit/tests/validate-migration-framework.ps1`
- Modify: `aitoolkit/tests/validate-migration-framework.Tests.ps1`

**Interfaces:**
- Consumes: Canonical section name and row columns from Task 1.
- Produces: A fixed `## Activation Slice` envelope in every discovery-to-review artifact template and template validation that rejects drift.

- [ ] **Step 1: Write failing template mutation tests**

For every listed template, call the public `Templates` selector after mutating one real fixture at a time. Assert rejection for:

```text
missing ## Activation Slice
Activation Slice ID renamed
Applicability missing
Seam missing
Source Reference missing
Trace IDs missing
Disposition missing
Status missing
Decision Reference missing
Deferred Unit ID missing
```

Use exact-byte restoration:

```powershell
$originalBytes = [IO.File]::ReadAllBytes($fixture)
try {
  $mutated = $original.Replace('## Activation Slice', '## Activation Path')
  [IO.File]::WriteAllText($fixture, $mutated, [Text.UTF8Encoding]::new($false))
  $templates = Invoke-Validator 'Templates'
  Assert-True ($templates.ExitCode -eq 1) "Missing canonical Activation Slice heading should fail. Output: $($templates.Output)"
} finally {
  [IO.File]::WriteAllBytes($fixture, $originalBytes)
}
```

- [ ] **Step 2: Run RED and verify missing-section failure**

Run:

```powershell
& .\aitoolkit\tests\validate-migration-framework.Tests.ps1
```

Expected: FAIL because current migration templates do not contain `## Activation Slice`.

- [ ] **Step 3: Add minimal template validator behavior**

Add a helper that extracts the canonical section and validates the exact Markdown table header. Invoke it for exactly these templates:

```powershell
@(
  'discovery.md',
  'inventory.md',
  'mapping.md',
  'gaps-conflicts.md',
  'technical-design.md',
  'migration-plan.md',
  'implementation-report.md',
  'review-report.md'
)
```

The helper must reject a missing section, duplicate heading, missing column, or duplicate column. It must not infer translated aliases.

- [ ] **Step 4: Add the canonical envelope to templates**

Insert this section before each template's evidence/unknowns tail:

```markdown
## Activation Slice

Ghi `not-applicable-approved` với evidence và decision reference khi unit không có activation selector; không được bỏ section.

| Activation Slice ID | Applicability | Seam | Input | Output | Source Reference | Trace IDs | Disposition | Status | Decision Reference | Deferred Unit ID |
|---|---|---|---|---|---|---|---|---|---|---|
| <ACT-001> | <applicable / not-applicable-approved / unknown> | <canonical seam> | <input> | <output> | <source reference> | <trace IDs> | <implement / reuse / deferred-approved / not-applicable-approved> | <verified / missing / conflict / unknown> | <approval reference hoặc not-applicable> | <UNIT-* hoặc not-applicable> |
```

Do not add technology-specific examples to language-agnostic templates.

- [ ] **Step 5: Run GREEN template validation**

Run:

```powershell
& .\aitoolkit\tests\validate-migration-framework.ps1 -Target Templates
```

Expected: `PASS` and exit code 0.

- [ ] **Step 6: Commit Task 2**

```powershell
git add -- aitoolkit/templates/migration aitoolkit/tests/validate-migration-framework.ps1 aitoolkit/tests/validate-migration-framework.Tests.ps1
git commit -m "feat: carry activation slice artifact envelope"
```

### Task 3: Step Responsibilities, Handoff Gates, and Review Severity

**Files:**
- Modify: `aitoolkit/skills/migration/discovery/SKILL.md`
- Modify: `aitoolkit/skills/migration/build-inventory/SKILL.md`
- Modify: `aitoolkit/skills/migration/feature-mapping/SKILL.md`
- Modify: `aitoolkit/skills/migration/analyze-gaps-conflicts/SKILL.md`
- Modify: `aitoolkit/skills/migration/technical-design/SKILL.md`
- Modify: `aitoolkit/skills/migration/plan-waves/SKILL.md`
- Modify: `aitoolkit/skills/migration/code-migration/SKILL.md`
- Modify: `aitoolkit/skills/shared/ai-review/SKILL.md`
- Modify: `aitoolkit/tests/validate-migration-framework.ps1`
- Modify: `aitoolkit/tests/validate-migration-framework.Tests.ps1`

**Interfaces:**
- Consumes: Contract resource and template envelope from Tasks 1-2.
- Produces: Step-local behavior that discovers, maps, resolves, designs, plans, implements, reviews, and preserves the same Activation Slice without redefining its schema.

- [ ] **Step 1: Write failing skill pressure/mutation tests**

Add test cases that mutate each skill's step-specific rule and invoke `Skills`. Required failures:

```text
discovery no longer reads contracts/activation-slice.md
discovery permits missing parser/request/downstream seam to remain partial
inventory does not preserve ACT-### and seam trace
mapping permits deferred-approved without decision and destination unit
gaps does not block unresolved router ownership
technical design omits async loading/watch/reselection/failure/test lifecycle
plan permits activatable acceptance while required seams are deferred
code migration does not validate the approved Activation Slice at entry
AI review does not classify a non-activatable missing seam as Critical
AI review does not classify untraced ownership/lifecycle duplication at least Major
```

Each mutation must change the production fixture, invoke the public selector, assert the exact failure, and restore exact bytes.

- [ ] **Step 2: Run RED and confirm missing skill contract failures**

Run:

```powershell
& .\aitoolkit\tests\validate-migration-framework.Tests.ps1
```

Expected: FAIL because the current skills neither read nor preserve the Activation Slice contract.

- [ ] **Step 3: Add minimal skill validator requirements**

Extend `Test-Skills` with per-skill required tokens instead of duplicating the whole contract. For example:

```powershell
$activationSkillTokens = @{
  'discovery' = @('contracts/activation-slice.md', 'requested-key', 'parse-model', 'downstream-consumer', 'result: blocked')
  'build-inventory' = @('Activation Slice ID', 'ACT-###', 'seam')
  'feature-mapping' = @('deferred-approved', 'Decision Reference', 'Deferred Unit ID')
  'analyze-gaps-conflicts' = @('router ownership', 'result: blocked')
  'technical-design' = @('initial loading', 'reselection', 'failure behavior', 'lifecycle test')
  'plan-waves' = @('deferred-approved', 'activatable')
  'code-migration' = @('Activation Slice', 'Entry gate')
  'ai-review' = @('Activation Slice', 'Critical', 'Major')
}
```

Use context-specific error messages so a failure identifies the owning skill and missing responsibility.

- [ ] **Step 4: Update discovery through gaps/conflicts skills**

For each skill:

- read `aitoolkit/contracts/activation-slice.md`;
- preserve the same `ACT-###` and all rows from the immediate predecessor;
- add only the step-specific behavior defined in the design;
- state the blocking rule explicitly;
- include Activation Slice in the output contract.

Do not embed a second copy of the nine-row schema.

- [ ] **Step 5: Update design, planning, implementation, and review skills**

Add:

- technical design router policy and async lifecycle decision requirements;
- plan-wave dependency/deferred-unit acceptance restrictions;
- code-migration entry validation and changed-file/test trace to seams;
- AI review severity rules: missing seam that prevents activation is Critical; untraced duplicate ownership or missing lifecycle coverage is at least Major and becomes Critical when it causes correctness failure.

Preserve existing workflow, waiver, change-hygiene, and selected-unit wording.

- [ ] **Step 6: Run GREEN skill validation**

Run:

```powershell
& .\aitoolkit\tests\validate-migration-framework.ps1 -Target Skills
```

Expected: `PASS` and exit code 0.

- [ ] **Step 7: Commit Task 3**

```powershell
git add -- aitoolkit/skills/migration aitoolkit/skills/shared/ai-review/SKILL.md aitoolkit/tests/validate-migration-framework.ps1 aitoolkit/tests/validate-migration-framework.Tests.ps1
git commit -m "feat: enforce activation slice migration handoff"
```

Before committing, verify `git diff --cached --name-only` does not include `aitoolkit/skills/aitoolkit/migrate/SKILL.md`.

### Task 4: End-to-End Regression Scenarios and Final Verification

**Files:**
- Modify: `aitoolkit/tests/validate-migration-framework.Tests.ps1`
- Modify only if required by a demonstrated test failure: files created or modified in Tasks 1-3

**Interfaces:**
- Consumes: Complete contract, templates, skill behavior, and validator rules.
- Produces: End-to-end evidence for all F-01 acceptance scenarios and a clean final diff.

- [ ] **Step 1: Add positive and negative end-to-end fixtures**

Represent each scenario as a Markdown Activation Slice fixture passed through a test helper that validates applicability, exact seam set, row identity, evidence fields, disposition dependencies, and handoff identity:

```text
PASS: all nine seams verified with stable ACT-001
BLOCK: parse-model missing while provider/router/render exist
BLOCK: requested-key missing while model field exists
BLOCK: downstream-consumer missing
BLOCK: async selector has one-shot read without reselection/lifecycle test
BLOCK: construct has unresolved dual router ownership
BLOCK: deferred-approved lacks Decision Reference
BLOCK: deferred-approved lacks Deferred Unit ID
BLOCK: successor changes ACT-001 to ACT-002 or drops a seam
```

- [ ] **Step 2: Run RED for the new scenario helper**

Run the test suite before adding validator support for the fixture helper.

Expected: FAIL on the first scenario validation assertion because no artifact-level Activation Slice validator exists yet.

- [ ] **Step 3: Implement minimal artifact-level validation helper**

Add a validator helper that accepts Markdown text and checks:

```text
one canonical section
one stable slice ID per slice
exactly nine unique canonical seams when applicable
non-empty Source Reference and Trace IDs
valid disposition/status pairs
deferred-approved dependency fields
construct router policy evidence
async lifecycle evidence when selector is asynchronous
same slice ID and seam set across predecessor/successor fixtures
```

Keep it language-agnostic and reuse existing Markdown section/table helpers.

- [ ] **Step 4: Run focused validators**

Run:

```powershell
& .\aitoolkit\tests\validate-migration-framework.ps1 -Target Contracts
& .\aitoolkit\tests\validate-migration-framework.ps1 -Target Templates
& .\aitoolkit\tests\validate-migration-framework.ps1 -Target Skills
```

Expected: all three print `PASS` and exit 0.

- [ ] **Step 5: Run the complete regression suite**

Run:

```powershell
& .\aitoolkit\tests\validate-migration-framework.Tests.ps1
```

Expected: exit code 0. If runtime exceeds the current environment limit, record the timeout as incomplete evidence, run every public selector independently, and do not claim the full suite passed.

- [ ] **Step 6: Inspect final scope and encoding**

Run:

```powershell
git diff --check
git status --short
git diff --name-only HEAD~3..HEAD
& .\aitoolkit\tests\validate-migration-framework.ps1 -Target Encoding
```

Expected: no whitespace errors; Encoding passes; the pre-existing `aitoolkit/skills/aitoolkit/migrate/SKILL.md` change remains outside F-01 commits.

- [ ] **Step 7: Commit final regression coverage**

```powershell
git add -- aitoolkit/tests/validate-migration-framework.Tests.ps1 aitoolkit/tests/validate-migration-framework.ps1
git commit -m "test: cover activation slice failure modes"
```

If Step 3 required no production-validator change beyond previous tasks, stage only the test file.

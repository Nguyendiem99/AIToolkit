# Migration Pipeline Boundaries Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rút migration pipeline còn 15 bước kết thúc tại Knowledge Capture, sửa greenfield foundation lifecycle và thêm onboarding document-path/inbox contract.

**Architecture:** Migration orchestrator tiếp tục là Superpowers-native Markdown skill, không manifest/state engine. Gerrit, CCC và Release giữ nguyên dưới dạng skill độc lập nhưng không còn route/handoff trong migration. Foundation baseline được tạo bởi bootstrap của unit đầu tiên và được later greenfield units resolve từ approved project baseline; onboarding tự sinh profile/pack từ explicit paths hoặc optional inbox.

**Tech Stack:** Markdown skills/templates/docs, YAML project profile, PowerShell structural validator/focused mutation suite.

## Global Constraints

- Migration orchestrator có đúng 15 bước và kết thúc bằng `shared/knowledge-base`.
- Không có route `shared/gerrit-automation`, `shared/ccc-automation` hoặc `shared/release` trong migration orchestrator.
- Ba delivery skill vẫn tồn tại, độc lập và không nhận migration handoff ngầm.
- Foundation unit đầu tiên dùng `Bootstrap Scope: required` và không cần baseline tồn tại trước step 09.
- Later greenfield unit dùng `Bootstrap Scope: not-required` và approved `foundation_baseline_id`; thiếu/stale/unapproved baseline ⇒ `result: blocked`.
- Incremental không bootstrap và regression vẫn bắt buộc.
- Onboarding tự sinh profile/project pack; explicit document paths ưu tiên, inbox là optional fallback.
- Onboarding không move/sửa tài liệu gốc hoặc production source.
- Runtime vẫn thuần prompt; không thêm workflow manifest, state file, private run store hoặc resume engine.
- Manual/plugin evidence phải giữ PASS/BLOCKED trung thực.
- Mỗi task theo TDD, có task-scoped review và commit riêng.

---

## File Map

| File/khu vực | Trách nhiệm |
|---|---|
| `aitoolkit/skills/aitoolkit/migrate/SKILL.md` | 15-step pipeline và terminal handoff |
| `aitoolkit/skills/migration/{plan-waves,bootstrap-target,code-migration}/SKILL.md` | Foundation lifecycle |
| `aitoolkit/templates/migration/{migration-plan,bootstrap-report,implementation-report}.md` | Foundation baseline contracts |
| `aitoolkit/skills/aitoolkit/migration-onboarding/SKILL.md` | Onboarding argument/input policy |
| `aitoolkit/commands/migration-onboarding.md` | User-facing flags |
| `aitoolkit/skills/migration-onboarding/{inspect-project,classify-mode,create-project-pack}/SKILL.md` | Document discovery/evidence/pack generation |
| `aitoolkit/templates/migration/{project-inspection,mode-proposal,project-pack-review}.md` | Document source/evidence trace |
| `aitoolkit/tests/validate-migration-framework*.ps1` | Structural regression and real-file mutations |
| `aitoolkit/{README.md,CONTRIBUTING.md,docs/*}` | User workflow và acceptance evidence |

### Task 1: Remove delivery stages and terminate at Knowledge Capture

**Files:**
- Modify: `AIToolkit-main/aitoolkit/skills/aitoolkit/migrate/SKILL.md`
- Modify: `AIToolkit-main/aitoolkit/skills/shared/knowledge-base/SKILL.md`
- Modify: `AIToolkit-main/aitoolkit/tests/validate-migration-framework.ps1`
- Modify: `AIToolkit-main/aitoolkit/tests/validate-migration-framework.Tests.ps1`

**Interfaces:**
- Consumes: parity artifact for greenfield, regression artifact for incremental.
- Produces: 15-step pipeline; Knowledge Capture là terminal consumer.

- [ ] **Step 1: Add failing boundary mutations**

Focused tests mutate the real orchestrator and require failure when:

```text
- step count is not exactly 15;
- any Gerrit/CCC/Release route appears in the migration table;
- Knowledge Capture is not step 15/last;
- greenfield knowledge predecessor is not parity;
- incremental knowledge predecessor is not regression;
- removed delivery-envelope wording remains required after parity/regression.
```

Also assert the three independent shared skill files still exist and contain their independent HARD/optional behavior.

- [ ] **Step 2: Run RED**

Run from `AIToolkit/AIToolkit-main`:

```powershell
& .\aitoolkit\tests\validate-migration-framework.Tests.ps1
```

Expected: FAIL because current orchestrator has 18 steps and delivery routes.

- [ ] **Step 3: Rewrite orchestrator terminal stages**

Keep steps 01–14 unchanged except greenfield bootstrap condition owned by Task 2. Replace steps 15–18 with:

```markdown
| 15 | shared/knowledge-base | kb-entry.md | none | always; terminal |
```

Terminal predecessor policy:

```text
greenfield → 13-parity-report.md → knowledge-base
incremental → 14-regression-report.md → knowledge-base
```

Remove migration-specific Gerrit/CCC/Release handoff requirements. Update Knowledge Base input wording to accept the orchestrator-provided terminal artifact and scan all artifacts in `RUN_DIR`.

- [ ] **Step 4: Run GREEN**

```powershell
& .\aitoolkit\tests\validate-migration-framework.ps1 -Check Orchestrators
& .\aitoolkit\tests\validate-migration-framework.Tests.ps1
& .\aitoolkit\tests\validate-migration-framework.ps1 -Check All
git diff --check
```

Expected: all PASS/exit 0.

- [ ] **Step 5: Commit**

```powershell
git add AIToolkit-main/aitoolkit/skills/aitoolkit/migrate/SKILL.md AIToolkit-main/aitoolkit/skills/shared/knowledge-base/SKILL.md AIToolkit-main/aitoolkit/tests
git commit -m "refactor: end migration at knowledge capture"
```

### Task 2: Fix greenfield foundation lifecycle

**Files:**
- Modify: `AIToolkit-main/aitoolkit/skills/aitoolkit/migrate/SKILL.md`
- Modify: `AIToolkit-main/aitoolkit/skills/migration/plan-waves/SKILL.md`
- Modify: `AIToolkit-main/aitoolkit/skills/migration/bootstrap-target/SKILL.md`
- Modify: `AIToolkit-main/aitoolkit/skills/migration/code-migration/SKILL.md`
- Modify: `AIToolkit-main/aitoolkit/skills/shared/knowledge-base/SKILL.md`
- Modify: `AIToolkit-main/aitoolkit/templates/migration/migration-plan.md`
- Modify: `AIToolkit-main/aitoolkit/templates/migration/bootstrap-report.md`
- Modify: `AIToolkit-main/aitoolkit/templates/migration/implementation-report.md`
- Modify: `AIToolkit-main/aitoolkit/tests/validate-migration-framework.ps1`
- Modify: `AIToolkit-main/aitoolkit/tests/validate-migration-framework.Tests.ps1`

**Interfaces:**
- Foundation unit: `Bootstrap Scope=required`, `Foundation Baseline=pending-bootstrap`.
- Later unit: `Bootstrap Scope=not-required`, non-null approved `Foundation Baseline ID`.

- [ ] **Step 1: Add RED scenarios and mutations**

Use `writing-skills` pressure scenarios plus real-file mutations:

1. First greenfield unit has no baseline yet → plan/step09 allowed.
2. Later greenfield unit has approved baseline → step09 skipped, implementation allowed.
3. Later unit missing/stale/unapproved baseline → blocked.
4. Incremental unit declaring required bootstrap → blocked.

Mutations must fail when plan/template/skill:

- requires baseline for `pending-bootstrap` foundation unit;
- bootstraps a `not-required` unit;
- accepts later greenfield unit without baseline ID/approval reference;
- loses `foundation_baseline_id` through implementation/knowledge update proposal.

- [ ] **Step 2: Run RED**

```powershell
& .\aitoolkit\tests\validate-migration-framework.ps1 -Check Skills
& .\aitoolkit\tests\validate-migration-framework.Tests.ps1
```

Expected: failure on the existing step08-before-step09 deadlock contract.

- [ ] **Step 3: Implement exact lifecycle**

Migration plan unit table fields:

```text
Migration Unit ID | Bootstrap Scope | Foundation Baseline ID | Foundation Approval Reference | ...
```

Rules:

```text
greenfield + required:
  Foundation Baseline ID = pending-bootstrap
  step09 runs
  bootstrap emits approved FOUNDATION-* record
  step10 validates bootstrap record matches selected unit

greenfield + not-required:
  Foundation Baseline ID = approved FOUNDATION-* ID
  step09 skips
  step10 resolves ID/reference from approved target baseline/project pack

incremental:
  Bootstrap Scope = not-required
  Foundation Baseline ID = not-applicable
  step09 skips
```

Knowledge Capture emits a project-pack update proposal for a newly created baseline; it never edits canonical pack without review.

- [ ] **Step 4: Run GREEN pressure and static checks**

```powershell
& .\aitoolkit\tests\validate-migration-framework.ps1 -Check Skills
& .\aitoolkit\tests\validate-migration-framework.ps1 -Check Orchestrators
& .\aitoolkit\tests\validate-migration-framework.Tests.ps1
& .\aitoolkit\tests\validate-migration-framework.ps1 -Check All
git diff --check
```

Expected: PASS; pressure agents choose bootstrap/skip/block correctly.

- [ ] **Step 5: Commit**

```powershell
git add AIToolkit-main/aitoolkit/skills/aitoolkit/migrate AIToolkit-main/aitoolkit/skills/migration AIToolkit-main/aitoolkit/skills/shared/knowledge-base AIToolkit-main/aitoolkit/templates/migration AIToolkit-main/aitoolkit/tests
git commit -m "fix: support greenfield foundation lifecycle"
```

### Task 3: Add onboarding document paths and optional inbox

**Files:**
- Modify: `AIToolkit-main/aitoolkit/commands/migration-onboarding.md`
- Modify: `AIToolkit-main/aitoolkit/skills/aitoolkit/migration-onboarding/SKILL.md`
- Modify: `AIToolkit-main/aitoolkit/skills/migration-onboarding/inspect-project/SKILL.md`
- Modify: `AIToolkit-main/aitoolkit/skills/migration-onboarding/classify-mode/SKILL.md`
- Modify: `AIToolkit-main/aitoolkit/skills/migration-onboarding/create-project-pack/SKILL.md`
- Modify: `AIToolkit-main/aitoolkit/templates/migration/project-inspection.md`
- Modify: `AIToolkit-main/aitoolkit/templates/migration/mode-proposal.md`
- Modify: `AIToolkit-main/aitoolkit/templates/migration/project-pack-review.md`
- Modify: `AIToolkit-main/aitoolkit/codex/skills/aitoolkit/SKILL.md`
- Modify: `AIToolkit-main/aitoolkit/tests/validate-migration-framework.ps1`
- Modify: `AIToolkit-main/aitoolkit/tests/validate-migration-framework.Tests.ps1`

**Interfaces:**
- Flags: `--legacy`, `--target`, repeatable `--requirements`, `--uiux`, `--migration-docs`, `--architecture-docs`.
- Inbox: `docs/aitoolkit/inputs/{requirements,uiux,migration,architecture}/`.

- [ ] **Step 1: Add RED parsing/resolution mutations**

Cover:

- project root derived from current target context, never positional;
- explicit file and directory flags accepted/repeatable;
- explicit paths precede inbox, then lists merge and canonical-path dedupe;
- missing/unreadable path blocks;
- unreadable format blocks instead of silent skip;
- no source document is moved or modified;
- step03 forwards document evidence through the single predecessor seam;
- generated profile lists categorized document paths and source authority.

- [ ] **Step 2: Run RED**

```powershell
& .\aitoolkit\tests\validate-migration-framework.ps1 -Check Onboarding
& .\aitoolkit\tests\validate-migration-framework.Tests.ps1
```

Expected: FAIL because current launcher/orchestrator has no complete flag/inbox contract.

- [ ] **Step 3: Implement resolver contract**

Priority:

```text
explicit flag paths
→ matching inbox directory if present
→ canonical-path merge/dedupe
→ readability/format validation
→ categorized Evidence records
```

Each record contains:

```text
Category | Canonical Path | Input Source (explicit|inbox) | Format | Readability | Evidence ID
```

Onboarding only stages profile/pack changes; canonical publish remains after Tech Lead HARD gate.

- [ ] **Step 4: Run GREEN**

```powershell
& .\aitoolkit\tests\validate-migration-framework.ps1 -Check Onboarding
& .\aitoolkit\tests\validate-migration-framework.Tests.ps1
& .\aitoolkit\tests\validate-migration-framework.ps1 -Check All
git diff --check
```

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add AIToolkit-main/aitoolkit/commands/migration-onboarding.md AIToolkit-main/aitoolkit/skills/aitoolkit/migration-onboarding AIToolkit-main/aitoolkit/skills/migration-onboarding AIToolkit-main/aitoolkit/templates/migration AIToolkit-main/aitoolkit/codex/skills/aitoolkit/SKILL.md AIToolkit-main/aitoolkit/tests
git commit -m "feat: resolve migration onboarding documents"
```

### Task 4: Update docs, fixtures and final acceptance

**Files:**
- Modify: `AIToolkit-main/aitoolkit/README.md`
- Modify: `AIToolkit-main/aitoolkit/CONTRIBUTING.md`
- Modify: `AIToolkit-main/aitoolkit/docs/MIGRATION-FRAMEWORK.md`
- Modify: `AIToolkit-main/aitoolkit/docs/RUN-ON-CODEX.md`
- Modify: `AIToolkit-main/aitoolkit/examples/migration/{greenfield,incremental}/docs/aitoolkit/project.yaml`
- Modify: `AIToolkit-main/aitoolkit/tests/validate-migration-framework.ps1`
- Modify: `AIToolkit-main/aitoolkit/tests/validate-migration-framework.Tests.ps1`

**Interfaces:**
- Produces: user workflow, 12-criterion follow-up acceptance matrix, truthful verification evidence.

- [ ] **Step 1: Add Docs RED mutations**

Require docs to state, in order:

```text
prepare sources/documents
→ migration-onboarding with flags or inbox
→ review generated profile/pack
→ Tech Lead approval
→ migrate feature slug
→ migration ends at Knowledge Capture
→ delivery skills are separate explicit calls
```

Reject docs claiming migration runs Gerrit/CCC/Release, has 18 steps, or requires user-authored pack.

- [ ] **Step 2: Run RED**

```powershell
& .\aitoolkit\tests\validate-migration-framework.ps1 -Check Docs
& .\aitoolkit\tests\validate-migration-framework.Tests.ps1
```

Expected: FAIL on current 18-step/delivery-stage documentation.

- [ ] **Step 3: Update docs/fixtures/acceptance matrix**

Greenfield fixture includes a foundation unit scenario and later-unit baseline scenario. Incremental fixture remains `preserve-existing`, no bootstrap, regression required. Acceptance matrix maps all 12 follow-up criteria to files, validator checks and runtime evidence.

- [ ] **Step 4: Full verification**

```powershell
& .\aitoolkit\tests\validate-migration-framework.ps1 -Check All
& .\aitoolkit\tests\validate-migration-framework.Tests.ps1
claude plugin validate .\aitoolkit
git diff --check
git status --short
```

Expected:

- static/focused validators PASS;
- plugin validation PASS if CLI available, otherwise docs/report retain truthful BLOCKED with reason;
- diff check clean;
- status contains only task files before commit.

- [ ] **Step 5: Manual scenario evidence**

Run onboarding and both mode scenarios to first relevant gate if runtime available. Record observed artifact/gate evidence. If unavailable, keep `BLOCKED`; do not claim PASS.

- [ ] **Step 6: Commit**

```powershell
git add AIToolkit-main/aitoolkit/README.md AIToolkit-main/aitoolkit/CONTRIBUTING.md AIToolkit-main/aitoolkit/docs AIToolkit-main/aitoolkit/examples/migration AIToolkit-main/aitoolkit/tests
git commit -m "docs: publish streamlined migration workflow"
```

## Self-Review

- **Spec coverage:** Task 1 pipeline boundaries; Task 2 both greenfield paths and incremental invariant; Task 3 ownership/input resolution; Task 4 user workflow/docs/evidence.
- **Contract consistency:** `foundation_baseline_id` is `pending-bootstrap`, approved `FOUNDATION-*`, or `not-applicable` according to mode/scope; no task uses Gerrit/CCC/Release handoff.
- **Backward compatibility:** Delivery skill files remain independent; feature/bugfix workflows are outside this follow-up except validator guards.
- **No placeholders:** Every task includes exact files, RED behaviors, GREEN commands, interfaces and commit.

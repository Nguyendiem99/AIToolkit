# Migration Automation Modes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Thêm `interactive | auto | auto-waive` cho migration và mặc định sinh toàn bộ artifact Markdown bằng tiếng Việt mà không làm giả evidence.

**Architecture:** Codex launcher và migration orchestrator resolve một `automation_mode` theo `CLI -> project profile -> interactive`, sau đó orchestrator là authority duy nhất quyết định approval/waiver. Step-skill vẫn sinh verdict thật; `auto-waive` chỉ chuyển environment-unavailable blocker thành truthful partial waiver. Schema/profile và template quy định `artifact_language: vi`; prose/heading dùng tiếng Việt trong khi machine seams giữ nguyên.

**Tech Stack:** Markdown skills/templates/docs, YAML project profile, PowerShell structural validator và real-file mutation suite.

## Global Constraints

- Exact modes: `interactive | auto | auto-waive`.
- Exact CLI flags: `--auto` và `--auto-waive`; hai flag loại trừ nhau.
- Resolution order: CLI flag → `project.yaml automation.mode` → `interactive`.
- `auto` tự duyệt non-blocked soft gates nhưng dừng ở mọi blocker.
- `auto-waive` chỉ waive blocker `environment-unavailable`; correctness/schema/path/selector/regression/scope/HARD-gate failure luôn dừng.
- Waived check giữ verdict thật `NOT_RUN + WAIVED`; không ghi `PASS`.
- Artifact có waiver dùng `status: approved`, `result: partial`, `approval_source: auto-waive` và exact waiver fields.
- Default artifact language là `vi`; onboarding sinh `output.artifact_language: vi`; profile cũ thiếu field degrade về `vi`.
- Human-facing prose/headings là tiếng Việt UTF-8; frontmatter keys, enum, ID, path, route, command, log và machine-contract fields không dịch.
- Source documents không bị dịch, di chuyển hay sửa.
- Migration vẫn 15 step, Knowledge Capture terminal; delivery skills độc lập.
- Feature/bugfix gate behavior không thay đổi.
- Không thêm manifest, state store, private run store hay resume engine.
- Mỗi task theo TDD, có review và commit riêng.

---

## File Map

| Khu vực | Trách nhiệm |
|---|---|
| `aitoolkit/codex/skills/aitoolkit/SKILL.md` | Parse/forward hai CLI flags |
| `aitoolkit/commands/migrate.md` | User-facing invocation contract |
| `aitoolkit/skills/aitoolkit-schemas/SKILL.md` | Profile, automation, approval và waiver schema |
| `aitoolkit/templates/migration/project-profile.yaml` | Default `automation.mode` và `output.artifact_language` |
| `aitoolkit/skills/aitoolkit/{migration-onboarding,migrate}/SKILL.md` | Resolve mode/language và gate policy |
| `aitoolkit/skills/migration/code-migration/SKILL.md` | Pre-mutation environment blocker classification |
| `aitoolkit/skills/shared/{verification-testing,knowledge-base}/SKILL.md` | Truthful waived verification và terminal roll-up |
| `aitoolkit/templates/migration/*.md` | Vietnamese migration/onboarding artifact prose |
| `aitoolkit/templates/{review-report,verification-report,kb-entry}.md` | Vietnamese prose for shared artifacts used by migration |
| `aitoolkit/{README.md,CONTRIBUTING.md,docs/*}` | User workflow and safety semantics |
| `aitoolkit/tests/validate-migration-framework*.ps1` | Static contracts and real-file mutations |

### Task 1: Add automation and language profile contracts

**Files:**
- Modify: `AIToolkit-main/aitoolkit/skills/aitoolkit-schemas/SKILL.md`
- Modify: `AIToolkit-main/aitoolkit/templates/migration/project-profile.yaml`
- Modify: `AIToolkit-main/aitoolkit/examples/migration/greenfield/docs/aitoolkit/project.yaml`
- Modify: `AIToolkit-main/aitoolkit/examples/migration/incremental/docs/aitoolkit/project.yaml`
- Modify: `AIToolkit-main/aitoolkit/skills/migration-onboarding/create-project-pack/SKILL.md`
- Modify: `AIToolkit-main/aitoolkit/tests/validate-migration-framework.ps1`
- Modify: `AIToolkit-main/aitoolkit/tests/validate-migration-framework.Tests.ps1`

**Interfaces:**
- Produces: `automation.mode: interactive|auto|auto-waive`, `output.artifact_language: vi`.
- Produces artifact fields: `approval_source: human|auto|auto-waive` and waiver record fields `policy`, `category`, `original_verdict`, `effective_action`, `evidence`.

- [ ] **Step 1: Add failing profile/schema mutations**

Mutate real template/fixtures and require rejection for:

```text
automation.mode missing from newly generated profile
automation.mode = fully-automatic
output.artifact_language missing or not vi
approval_source outside human|auto|auto-waive
waiver missing any exact field or containing an extra field
waiver paired with result: complete or approval_source: auto
```

Also add a compatibility case proving a legacy profile without `automation`/`output` resolves to `interactive` and `vi` rather than failing.

- [ ] **Step 2: Run RED**

```powershell
& .\aitoolkit\tests\validate-migration-framework.ps1 -Check Contracts
& .\aitoolkit\tests\validate-migration-framework.Tests.ps1
```

Expected: FAIL on missing mode/language/waiver contracts.

- [ ] **Step 3: Implement exact schemas and generated defaults**

Add to generated profile and both fixtures:

```yaml
automation:
  mode: interactive
output:
  artifact_language: vi
```

Document legacy fallback and exact waiver schema in `aitoolkit-schemas`. Require `create-project-pack` to stage these defaults without changing source documents.

- [ ] **Step 4: Run GREEN**

```powershell
& .\aitoolkit\tests\validate-migration-framework.ps1 -Check Contracts
& .\aitoolkit\tests\validate-migration-framework.ps1 -Check Onboarding
& .\aitoolkit\tests\validate-migration-framework.Tests.ps1
& .\aitoolkit\tests\validate-migration-framework.ps1 -Check All
git diff --check
```

- [ ] **Step 5: Commit**

```powershell
git add AIToolkit-main/aitoolkit/skills/aitoolkit-schemas AIToolkit-main/aitoolkit/skills/migration-onboarding/create-project-pack AIToolkit-main/aitoolkit/templates/migration/project-profile.yaml AIToolkit-main/aitoolkit/examples/migration AIToolkit-main/aitoolkit/tests
git commit -m "feat: define migration automation profiles"
```

### Task 2: Implement CLI resolution and automatic soft gates

**Files:**
- Modify: `AIToolkit-main/aitoolkit/codex/skills/aitoolkit/SKILL.md`
- Modify: `AIToolkit-main/aitoolkit/commands/migrate.md`
- Modify: `AIToolkit-main/aitoolkit/skills/aitoolkit/migrate/SKILL.md`
- Modify: `AIToolkit-main/aitoolkit/tests/validate-migration-framework.ps1`
- Modify: `AIToolkit-main/aitoolkit/tests/validate-migration-framework.Tests.ps1`

**Interfaces:**
- Consumes: Task 1 `automation.mode`.
- Produces: per-run `automation_mode` forwarded to every migration step.

- [ ] **Step 1: Add RED parsing and gate-policy mutations**

Cover exact scenarios:

```text
no CLI + no profile field => interactive
profile auto => auto
profile auto-waive => auto-waive
--auto overrides profile interactive/auto-waive
--auto-waive overrides profile interactive/auto
both flags => blocked before step 01
unknown profile enum => blocked before step 01
auto complete/partial non-blocked soft gate => approved without question
auto blocked artifact => stop
any HARD gate => stop in every mode
```

- [ ] **Step 2: Run RED**

```powershell
& .\aitoolkit\tests\validate-migration-framework.ps1 -Check Orchestrators
& .\aitoolkit\tests\validate-migration-framework.Tests.ps1
```

Expected: FAIL because launcher/orchestrator do not parse or apply automation mode.

- [ ] **Step 3: Implement resolution and approval protocol**

Codex launcher forwards exact flags unchanged. Orchestrator resolves mode once before step 01, records it in each artifact invocation, and applies:

```text
interactive + soft => ask
auto + non-blocked soft => status approved, approval_source auto
auto-waive + non-blocked soft => status approved, approval_source auto-waive
blocked => Task 3 classifier
HARD => always stop for explicit confirmation
```

Do not change the 15-row pipeline or feature/bugfix orchestrators.

- [ ] **Step 4: Run GREEN**

```powershell
& .\aitoolkit\tests\validate-migration-framework.ps1 -Check Orchestrators
& .\aitoolkit\tests\validate-migration-framework.Tests.ps1
& .\aitoolkit\tests\validate-migration-framework.ps1 -Check All
git diff --check
```

- [ ] **Step 5: Commit**

```powershell
git add AIToolkit-main/aitoolkit/codex/skills/aitoolkit AIToolkit-main/aitoolkit/commands/migrate.md AIToolkit-main/aitoolkit/skills/aitoolkit/migrate AIToolkit-main/aitoolkit/tests
git commit -m "feat: automate migration soft gates"
```

### Task 3: Implement truthful environment waivers

**Files:**
- Modify: `AIToolkit-main/aitoolkit/skills/aitoolkit/migrate/SKILL.md`
- Modify: `AIToolkit-main/aitoolkit/skills/migration/code-migration/SKILL.md`
- Modify: `AIToolkit-main/aitoolkit/skills/shared/verification-testing/SKILL.md`
- Modify: `AIToolkit-main/aitoolkit/skills/shared/knowledge-base/SKILL.md`
- Modify: `AIToolkit-main/aitoolkit/templates/migration/implementation-report.md`
- Modify: `AIToolkit-main/aitoolkit/templates/verification-report.md`
- Modify: `AIToolkit-main/aitoolkit/templates/kb-entry.md`
- Modify: `AIToolkit-main/aitoolkit/tests/validate-migration-framework.ps1`
- Modify: `AIToolkit-main/aitoolkit/tests/validate-migration-framework.Tests.ps1`

**Interfaces:**
- Consumes: Task 2 `automation_mode`.
- Produces: truthful `result: partial`, `NOT_RUN + WAIVED` and exact waiver record for eligible environment blockers.

- [ ] **Step 1: Add RED taxonomy pressure scenarios and mutations**

Eligible cases must continue only in `auto-waive`:

```text
dependency/tool executable absent
device/emulator/service unavailable
network dependency unavailable
command cannot start because environment capability is absent
pre-mutation baseline cannot be collected solely for one of those reasons
```

Ineligible cases must stop in all modes:

```text
command ran and returned failure
schema/frontmatter/handoff invalid
source/target path invalid or outside scope
mode/policy/unit/foundation selector invalid, stale or ambiguous
parity/regression detects a new failure
destructive target is outside scope
HARD gate
```

Mutations must prove `WAIVED` cannot coexist with `PASS`, `result: complete`, missing evidence, or `approval_source: auto`.

- [ ] **Step 2: Run RED**

```powershell
& .\aitoolkit\tests\validate-migration-framework.ps1 -Check Skills
& .\aitoolkit\tests\validate-migration-framework.Tests.ps1
```

- [ ] **Step 3: Implement the classifier at the orchestrator seam**

Step-skill records the native blocker and evidence. Orchestrator validates category and, only for `auto-waive + environment-unavailable`, changes the continuation artifact to:

```yaml
status: approved
result: partial
approval_source: auto-waive
waiver:
  policy: auto-waive
  category: environment-unavailable
  original_verdict: blocked
  effective_action: continue
  evidence: <verbatim capability/command error reference>
```

Verification records the check as `NOT_RUN + WAIVED`. Knowledge Capture lists every waiver and never promotes it to PASS. Feature/bugfix invocations retain existing behavior.

- [ ] **Step 4: Run GREEN**

```powershell
& .\aitoolkit\tests\validate-migration-framework.ps1 -Check Skills
& .\aitoolkit\tests\validate-migration-framework.ps1 -Check Templates
& .\aitoolkit\tests\validate-migration-framework.Tests.ps1
& .\aitoolkit\tests\validate-migration-framework.ps1 -Check All
git diff --check
```

- [ ] **Step 5: Commit**

```powershell
git add AIToolkit-main/aitoolkit/skills/aitoolkit/migrate AIToolkit-main/aitoolkit/skills/migration/code-migration AIToolkit-main/aitoolkit/skills/shared/verification-testing AIToolkit-main/aitoolkit/skills/shared/knowledge-base AIToolkit-main/aitoolkit/templates AIToolkit-main/aitoolkit/tests
git commit -m "feat: support truthful migration waivers"
```

### Task 4: Default generated migration Markdown to Vietnamese

**Files:**
- Modify: every `AIToolkit-main/aitoolkit/templates/migration/*.md`
- Modify: `AIToolkit-main/aitoolkit/templates/review-report.md`
- Modify: `AIToolkit-main/aitoolkit/templates/verification-report.md`
- Modify: `AIToolkit-main/aitoolkit/templates/kb-entry.md`
- Modify: `AIToolkit-main/aitoolkit/skills/aitoolkit/migration-onboarding/SKILL.md`
- Modify: `AIToolkit-main/aitoolkit/skills/aitoolkit/migrate/SKILL.md`
- Modify: migration and onboarding step skills under `aitoolkit/skills/migration*`
- Modify: `AIToolkit-main/aitoolkit/README.md`
- Modify: `AIToolkit-main/aitoolkit/CONTRIBUTING.md`
- Modify: `AIToolkit-main/aitoolkit/docs/MIGRATION-FRAMEWORK.md`
- Modify: `AIToolkit-main/aitoolkit/docs/RUN-ON-CODEX.md`
- Modify: `AIToolkit-main/aitoolkit/tests/validate-migration-framework.ps1`
- Modify: `AIToolkit-main/aitoolkit/tests/validate-migration-framework.Tests.ps1`

**Interfaces:**
- Consumes: Task 1 `output.artifact_language: vi` with legacy fallback `vi`.
- Produces: UTF-8 Vietnamese prose/headings while preserving exact machine seams.

- [ ] **Step 1: Add RED language and immutability mutations**

Require:

```text
every migration/onboarding generated template declares Vietnamese output intent
human-facing title/summary/blocker/recommendation/gate content is Vietnamese
frontmatter keys, enum, artifact paths and exact contract table fields remain unchanged
no mojibake patterns
source document paths are read-only and never translated/re-written
legacy profile language fallback is vi
```

Add real-file mutations that insert English-only placeholder prose, translate a machine field, insert mojibake, or authorize source-document translation; each must fail.

- [ ] **Step 2: Run RED**

```powershell
& .\aitoolkit\tests\validate-migration-framework.ps1 -Check Templates
& .\aitoolkit\tests\validate-migration-framework.ps1 -Check Encoding
& .\aitoolkit\tests\validate-migration-framework.Tests.ps1
```

- [ ] **Step 3: Translate human-facing generated content**

Translate headings, instructions, summaries and non-contract table labels across migration/onboarding templates and their producing skills. Preserve exact frontmatter, enum, filenames, IDs, trace fields, commands/logs and validator-owned table schemas. State in both orchestrators that all generated prose uses resolved `artifact_language`, currently only supported value `vi`.

- [ ] **Step 4: Update user documentation**

Document:

```text
migration artifacts default to Vietnamese
--auto = no questions, no waiver
--auto-waive = no questions, environment waiver only
profile defaults and CLI precedence
truthful PASS/FAIL/BLOCKED/WAIVED/NOT_RUN semantics
```

- [ ] **Step 5: Full verification**

```powershell
& .\aitoolkit\tests\validate-migration-framework.ps1 -Check Encoding
& .\aitoolkit\tests\validate-migration-framework.ps1 -Check Templates
& .\aitoolkit\tests\validate-migration-framework.ps1 -Check Docs
& .\aitoolkit\tests\validate-migration-framework.Tests.ps1
& .\aitoolkit\tests\validate-migration-framework.ps1 -Check All
git diff --check
git status --short
```

Run manual Codex scenarios when runtime is available:

```text
interactive default => pauses at soft gate
--auto => crosses soft gates, stops at environment blocker
--auto-waive => crosses same blocker with partial/WAIVED evidence
```

Unavailable runtime/plugin evidence remains `BLOCKED`; do not claim PASS.

- [ ] **Step 6: Commit**

```powershell
git add AIToolkit-main/aitoolkit/templates AIToolkit-main/aitoolkit/skills AIToolkit-main/aitoolkit/README.md AIToolkit-main/aitoolkit/CONTRIBUTING.md AIToolkit-main/aitoolkit/docs AIToolkit-main/aitoolkit/tests
git commit -m "docs: generate migration artifacts in Vietnamese"
```

## Self-Review

- **Spec coverage:** Task 1 schema/defaults; Task 2 CLI and auto gates; Task 3 waiver taxonomy/evidence; Task 4 Vietnamese output/docs/acceptance.
- **Interface consistency:** one `automation_mode`; exact `interactive|auto|auto-waive`; exact `approval_source`; exact five-field waiver record; `artifact_language: vi`.
- **Safety:** no waiver for correctness, contract, selector, regression, scope, destructive operation or HARD gate.
- **Compatibility:** migration remains 15 steps; feature/bugfix and independent delivery skills retain existing behavior.
- **No placeholders:** every task names files, RED failures, implementation contracts, GREEN commands and commit.

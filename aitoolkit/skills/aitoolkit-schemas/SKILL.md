---
name: aitoolkit-schemas
description: Hợp đồng dữ liệu của AIToolKit — cấu trúc artifact .md (front-matter) và project profile. Orchestrator và mọi step-skill PHẢI đọc skill này để đọc/ghi đúng định dạng.
---

# AIToolKit — Data Contracts

Các định dạng dưới đây là "seam" giữa các thành phần. KHÔNG thành phần nào được phá vỡ chúng.

## 1. Artifact `.md`

Mỗi bước ghi đúng MỘT file artifact. Front-matter YAML bắt buộc:

```yaml
---
step_id: 01-discovery      # id bước (khớp Bảng bước của orchestrator)
status: draft              # draft khi vừa sinh; approved sau khi qua gate
produced_at: 2026-08-06
---
```
Thân file theo template của bước.

**Đặt tên & input:**
- Bước đặc thù workflow (nửa đầu): tên theo bước, vd `01-discovery.md`, `03-fix.md`.
- Bước khung dùng chung (`shared/*`): tên theo vai trò, ổn định qua mọi workflow — `review-report.md`, `verification-report.md`, `gerrit-report.md`, `ccc-package.md`, `release-report.md`, `kb-entry.md`.
- Mọi artifact ghi vào **RUN_DIR** do orchestrator truyền (`<project>/docs/aitoolkit/<date>-<workflow>-<slug>/`).
- **Input bước trước = đường dẫn artifact orchestrator truyền vào**, KHÔNG tra state lưu riêng, KHÔNG hardcode tên file workflow khác.

## 2. Project profile (language-agnostic layer)

Các bước `shared/*` KHÔNG được hardcode ngôn ngữ/lệnh (không `flutter test`, `npm test`…). Chúng lấy lệnh test/lint/build của repo qua **profile**, theo thứ tự ưu tiên (degrade gracefully):

Command resolution order: `explicit profile -> existing project scripts/config -> marker detection -> human gate`.

1. **Khai báo tường minh** — file tuỳ chọn `<project>/docs/aitoolkit/project.yaml` (team điền 1 lần). Trường nào có thì dùng nguyên văn:
   ```yaml
   language: dart            # tuỳ chọn, chỉ để ghi chú
   base_branch: origin/main  # tuỳ chọn — mốc diff cho ai-review; thiếu ⇒ fallback HEAD~1
   test_cmd: flutter test
   lint_cmd: flutter analyze
   build_cmd: flutter build apk --debug
   coverage_cmd: flutter test --coverage   # tuỳ chọn
   review_focus:                            # tuỳ chọn, bơm thêm vào ai-review
     - "Riverpod: không giữ ref sau dispose"
   ```

**Workflow type là dữ liệu theo từng run, không phải cấu hình bền vững của project.** Caller/orchestrator phải truyền đúng một `workflow_type: feature | bugfix | migration` cho mỗi shared step. Giá trị caller-provided này là authoritative, kể cả khi `project.yaml` có namespace `migration`; shared skill không được đọc, suy hoặc override workflow type từ profile. Top-level legacy `change_type` không phải authority và không được onboarding sinh lại. Thiếu hoặc sai enum `workflow_type` thì step ghi blocker và dừng thay vì đoán từ profile hay tên `RUN_DIR`.
2. **Project scripts/config hiện có** (khi thiếu trường ở bước 1) — ưu tiên lệnh đã được repo định nghĩa trong scripts, task runner hoặc config hiện hữu; dùng nguyên văn và không tự chế biến lệnh mới.
3. **Tự dò marker** (khi hai bước trên chưa xác định được lệnh) — nhận diện qua marker file ở gốc repo. Bảng dò chuẩn nằm ở `shared/verification-testing/command-detection.md`; ví dụ: `pubspec.yaml`→dart/flutter, `package.json`→npm/pnpm/yarn, `Cargo.toml`→cargo, `go.mod`→go, `pom.xml`/`build.gradle`→mvn/gradle, `pyproject.toml`→pytest, `*.csproj`→dotnet.
4. **Hỏi qua gate** (khi vẫn không xác định được) — bước ghi rõ trong report "lệnh chưa xác định", nêu phán đoán, để gate người dùng xác nhận; TUYỆT ĐỐI không bịa lệnh rồi tuyên bố đã chạy.

Mọi shared skill đọc profile theo đúng thứ tự này. Lệnh dùng thực tế PHẢI được ghi verbatim vào artifact để truy vết.

## 3. Migration project profile v1

Migration workflows may start from `docs/aitoolkit/project.yaml` using this profile shape. The existing fields in §2 remain supported so shared verification can read the same command and review settings.

```yaml
schema_version: 1
project: { id: unknown }
migration: { mode: unknown, unit: feature, architecture_policy: unknown }
automation: { mode: interactive }
output: { artifact_language: vi }
legacy: { path: null, language: unknown, framework: unknown }
target: { path: null, language: unknown, framework: unknown }
documents:
  requirements: []
  uiux: []
  migration: []
  architecture: []
base_branch: null
test_cmd: null
lint_cmd: null
build_cmd: null
coverage_cmd: null
review_focus: []
verification: { behavior_parity: required, regression: optional, visual_fidelity: optional }
project_pack:
  path: docs/aitoolkit/migration-project
  reviewed_at: null
  review_evidence: null
```

Newly generated profiles must explicitly set `automation.mode` to one of `interactive | auto | auto-waive` and currently support exactly `output.artifact_language: vi`. The generated defaults are `automation.mode: interactive` and `output.artifact_language: vi`.

A legacy profile that omits `automation` and `output` resolves to `automation.mode: interactive` and `output.artifact_language: vi`; it remains valid and is not rewritten merely to apply these fallbacks.

Every non-empty item in any of the four `documents` lists has **exactly** this structured entry schema; missing or extra keys block onboarding publication:

```yaml
- path: <canonical path copied from Canonical Path>
  input_source: <explicit | inbox>
  format: <detected format>
  readability: readable
  evidence_id: <unique Evidence ID>
```

Migration artifacts additionally use this front matter field:

```yaml
result: complete # complete | partial | blocked
approval_source: human # human | auto | auto-waive
```

For migration artifacts, `status: draft|approved` is the artifact review lifecycle. `result: complete | partial | blocked` is the execution outcome enum, not generic authorization to emit every value on every route. The canonical Activation Slice contract permits `partial` only for the approved step-01 input-qualification predecessor and the exact step-10 `approved/partial/auto-waive` baseline-waiver tuple; steps 02–09 and 11–14 use `complete | blocked`. A `blocked` result stops the orchestrator; an execution failure must not be recorded as a completed artifact.

The required approval-source enum is:

```text
approval_source: human | auto | auto-waive
```

An artifact with an automation waiver uses exactly this YAML shape:

```yaml
status: approved
result: partial
approval_source: auto-waive
waiver:
  policy: auto-waive
  category: environment-unavailable
  original_verdict: blocked
  effective_action: continue
  evidence: <command/error/capability evidence>
```

The `waiver` record is optional, but when present it has exactly `policy`, `category`, `original_verdict`, `effective_action`, and `evidence`, with no missing or extra fields. An artifact containing `waiver` is valid only when it contains exactly one `status: approved`, exactly one `result: partial`, and exactly one `approval_source: auto-waive`; missing, duplicate, `draft`, or any other status is invalid, as is `result: complete` or `approval_source: human|auto`. Evidence must identify the command, error, or unavailable capability and must not claim an unexecuted check passed.

Migration invariants: `greenfield` uses `architecture_policy: design-new`; `incremental` uses `architecture_policy: preserve-existing`.

Before a migration run consumes the project pack, `project_pack.reviewed_at` must be a non-null RFC 3339 timestamp and `project_pack.review_evidence` must reference an approved pack-review artifact. That artifact records content revisions for the profile (excluding review metadata), pack, and cited source/target/documents. A missing timestamp/evidence, revision mismatch, newer cited evidence, or unprovable comparison is stale and yields `result: blocked`.

## 4. Migration selected-unit handoff

After step 08 approval and selector choice, an executed migration artifact preserves exact `Delivery Adapter Kind` and one exact `Delivery Adapter Mode Constraint` from approved plan authority. It preserves exactly one `Selected Migration Unit` row only when `Delivery Adapter Kind = migration-unit`. For `task | story | package | phase | milestone | none`, the section is absent, bootstrap scope is implicitly `not-required`, and the generic assurance identity is `Master Scope Context.Work Item ID`; a producer must not invent `UNIT-*`:

- Migration Unit ID, plan reference, approval reference, mode constraint, Bootstrap Scope;
- Foundation Baseline ID, Foundation Baseline Reference, Foundation Baseline Approval Reference;
- pre-change regression Baseline Reference and full Trace IDs.

For a greenfield foundation unit, step 09 creates an approved foundation baseline record. A later greenfield `Bootstrap Scope = not-required` unit skips step 09 and resolves its Foundation Baseline ID in the approved migration plan. Incremental records the three foundation-baseline values as `not-applicable`.

Steps 11-13 and terminal step 15 preserve this conditional envelope, including exact `Delivery Adapter Mode Constraint`. Incremental step 14 additionally preserves the parity verdict and adds regression applicability/verdict; greenfield proceeds from step 13 directly to terminal Knowledge Capture. Standalone Gerrit delivery resolves the approved plan plus the complete ordered review -> verification -> parity -> optional mode-required regression -> terminal KB chain before consuming the exact KB envelope. It retains the same conditional cardinality: one selected-unit row for `migration-unit`, zero for every generic adapter. Paired KB/Gerrit equality without that lineage is not authority.

## 5. Migration scope orchestration artifacts

The canonical tables, enums, selection order, transitions, and completion rules
live in `contracts/migration-scope-orchestration.md`. The canonical target
exemplar, conformance, assurance-state, structural-gate, and review rules live in
`contracts/target-structure-conformance.md`. The shapes below reference those
contracts and do not redefine their value sets.

File responsibility artifact fields (owned capability IDs, trace IDs, atomic
boundary IDs, classification, architecture authority, co-location, actual
responsibility evidence, verification ownership, evidence kind, verification
disposition, and verdict) are routed exclusively to
`contracts/file-responsibility-conformance.md`. This schema does not copy its
enums or table columns.

The canonical master spec front matter is:

```yaml
---
artifact_type: migration-master-spec
master_spec_id: SPEC-<SCOPE>-<NNN>
revision: <positive integer>
status: <artifact lifecycle value>
result: <artifact result value>
approval_source: <approval source>
requested_scope_kind: <value from migration-scope-orchestration.md>
requested_scope_id: <stable scope ID>
produced_at: <date>
supersedes: <artifact-id>@<revision> | not-applicable
---
```

Its body carries the requested-scope boundary, stable requirement IDs, actors
and journeys, behaviors and failure paths, constraints, architecture
applicability, measurable success criteria, out-of-scope items, assumptions and
unknowns, evidence index, approval record, and revision history.

The canonical master plan front matter is:

```yaml
---
artifact_type: migration-master-plan
master_plan_id: PLAN-<SCOPE>-<NNN>
master_spec_id: SPEC-<SCOPE>-<NNN>
master_spec_revision: <positive integer>
revision: <positive integer>
status: <artifact lifecycle value>
scope_status: <value from migration-scope-orchestration.md>
execution_policy: dependency-ready
max_concurrency: 1
produced_at: <date>
supersedes: <artifact-id>@<revision> | not-applicable
responsibility_contract:
  version: 1
  applicability: required
---
```

Each work-item record uses this machine shape; its field meanings and allowed
values come from the canonical contract:

```yaml
work_item_id: WORK-<SCOPE>-<NAME>
title: <independently reviewable outcome>
required: <contract value>
dependencies: [<work-item IDs>]
plan_order: <unique positive integer>
acceptance: [<requirement or success-criterion IDs and measurable outcome>]
trace_ids: [<stable trace IDs>]
delivery_adapter: <adapter record or none>
status: <work-item state from migration-scope-orchestration.md>
latest_attempt: <attempt ID or none>
terminal_evidence: <artifact reference or none>
approval_reference: <exact approval or pending>
```

The approved master-plan body contains complete, order-aligned `Delivery Adapter Selection` and `Responsibility Owner References` tables for the same Work Item set. Its bounded front matter declares exactly one canonical `responsibility_contract` block with `version: 1` and `applicability: required`; missing, pre-v1, unsupported, duplicate, or mixed plan discriminators are non-executable. Together with the exact approved technical-design artifact matching each row's `Design Revision`, those tables are the pre-edit planned responsibility authority. They are not a post-review handoff and no synthetic queue-authority artifact is part of this schema.

Optional adapter and decomposition records use these shapes:

```yaml
delivery_adapter:
  kind: <value from migration-scope-orchestration.md>
  external_id: <canonical external ID or not-applicable>
  authority: <canonical authority or not-applicable>
  authority_revision: <revision or not-applicable>
  approval_reference: <exact approval or not-applicable>
  parent_selector: <canonical selector or not-applicable>

decomposition:
  parent_work_item_id: <stable work-item ID>
  child_work_item_ids: [<stable child work-item IDs>]
  decision_reference: <approved decision reference>
```

Attempts and revisions are immutable records:

```yaml
attempt_id: ATTEMPT-<WORK-ITEM>-<NN>
work_item_id: WORK-<SCOPE>-<NAME>
plan_revision: <approved plan revision>
status: <attempt status from migration-scope-orchestration.md>
artifact_reference: <immutable artifact reference>
```

```yaml
artifact_id: <stable master artifact ID>
revision: <positive integer>
supersedes: <artifact-id>@<revision> | not-applicable
change_summary: <approved change summary>
affected_work_items: [<stable work-item IDs>]
approval_reference: <exact approval or pending>
```

Artifacts that report assurance use field names only from this shape and obtain
their values and waiver semantics from the canonical conformance contract:

```yaml
assurance:
  runtime_evidence_state: <value from target-structure-conformance.md>
  architecture_conformance_state: <value from target-structure-conformance.md>
  selector_schema_state: <value from target-structure-conformance.md>
```

Historical unit-only artifacts remain readable, but they must not resume to production mutation before compatibility conversion.

Compatibility conversion creates master-spec revision 1 and master-plan
revision 1 from approved evidence, creates one work item per canonical legacy
unit, preserves exact selectors and only contract-valid terminal evidence,
passes a new approval gate, and never infers requested-scope completion from a
single unit.

The canonical terminal scope report front matter is:

```yaml
---
artifact_type: migration-scope-terminal-report
master_spec_id: SPEC-<SCOPE>-<NNN>
master_spec_revision: <positive integer>
master_plan_id: PLAN-<SCOPE>-<NNN>
master_plan_revision: <positive integer>
status: <artifact lifecycle value>
result: <artifact result value>
approval_source: <approval source>
scope_status: <value from migration-scope-orchestration.md>
produced_at: <date>
---
```

Its `Work Item Terminal Evidence` table enumerates the exact current approved
master-plan work-item set in both directions. Each row binds Work Item ID,
required disposition, status, immutable terminal evidence, the three assurance
fields from `target-structure-conformance.md`, blocker, and plan revision. Its
`Scope Completion Calculation` derives the terminal verdict from the canonical
contract; it never trusts a caller-provided completion boolean or infers scope
completion from one legacy unit, attempt, or artifact.

Every terminal-success `Terminal Evidence` artifact contains exactly one v1
`Architecture Responsibility Handoff` whose `Evidence References` is the
review-originated source-diff, followed by exactly one `Terminal Chain
Reference` table with columns `Work Item ID | Artifact Reference`. The row
binds that Work Item to the immutable final mode-aware chain/KB
`artifact#sha256:<digest>` reference. The terminal scope report preserves
master-plan order, aggregates the source-diffs in its handoff, and maps the
separate final references in its Evidence Index; these two reference classes
are never interchangeable.

Compatibility conversion output is not executable authority by itself. The
new revision-1 master spec, revision-1 master plan, exact legacy-unit adapter
mapping, and preserved terminal evidence must pass a fresh human approval gate
before any production mutation or resume.

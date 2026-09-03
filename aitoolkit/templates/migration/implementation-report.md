---
step_id: <orchestrator-provided>
status: draft
result: complete
produced_at: <yyyy-mm-dd>
responsibility_contract:
  version: 1
  applicability: required
---

<!-- artifact_language: vi -->

# Báo cáo triển khai migration

## Master Scope Context

| Master Spec Reference | Master Spec ID | Master Spec Revision | Master Plan Reference | Master Plan ID | Master Plan Revision | Work Item ID | Work Item Approval Reference |
|---|---|---|---|---|---|---|---|
| <master-spec.md> | <SPEC-*> | <revision> | <master-plan.md> | <PLAN-*> | <revision> | <WORK-*> | <approval:TECH-LEAD-*> |

## Canonical Adapter Evidence

Mỗi work item có đúng một row. `Canonical Match` chỉ là `PASS` khi toàn bộ 13 field selector khớp ordinal với canonical Task 5 và các field Acceptance/Trace/Delivery Adapter liên quan khớp Work Item authority; adapter `none` giữ exact sentinel theo contract.

| Work Item ID | Adapter Kind | External ID | Authority | Authority Revision | Approval Reference | Parent Selector | Acceptance | Trace IDs | Mode Constraint | Design Revision | Parent Work Item ID | Decomposition Decision Reference | Canonical Match |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| <WORK-*> | <migration-unit, task, story, package, phase, milestone hoặc none> | <external ID hoặc not-applicable> | <authority hoặc not-applicable> | <revision hoặc not-applicable> | <approval hoặc not-applicable> | <parent selector hoặc not-applicable> | <exact Work Item acceptance> | <exact Work Item trace IDs> | <mode constraint> | <DESIGN-ID@revision> | <WORK-* hoặc not-applicable> | <DEC-* hoặc not-applicable> | <PASS hoặc BLOCKED> |

## Conformance Matrix Reference

`Design Reference` phải giữ nguyên exact canonical Task 6 `draft/complete`; không mutate Task 6 thành approved và không thêm `approval_source`. `Design Approval Evidence Reference` là explicit safe relative path tới external approval artifact có bounded front matter schema `step_id`, `status: approved`, `result: complete`, `approval_source: human`, `produced_at` và đúng một `Technical Design Approval` row. Row đó bind exact design ID/revision, SHA-256 content digest, Tech Lead decision, approval reference và approved status; report không được tự khai hoặc derive approval.

| Work Item ID | Discovery Reference | Design Reference | Design Revision | Design Approval Evidence Reference | Matrix Approval Reference | Matrix Status |
|---|---|---|---|---|---|---|
| <WORK-*> | <02-discovery.md> | <07-technical-design.md> | <revision> | <external approval artifact path> | <approval:TECH-LEAD-*> | <approved hoặc blocked> |

## Exemplar Read Evidence

Ghi đủ tám concern canonical từ contract. `Read Status` phải là `read-complete`; citation chung chung không được coi là đã đọc.

| Concern | Path | Inspected Symbols | Evidence | Read Status |
|---|---|---|---|---|
| <canonical concern> | <real target path> | <fully inspected symbols> | <exact evidence> | <read-complete hoặc unread> |

## Actual File Tree vs Planned File Tree

| Planned Path | Planned Symbol | Actual Path | Actual Symbol | Match | Evidence |
|---|---|---|---|---|---|
| <planned path> | <planned symbol> | <actual path> | <actual symbol> | <yes hoặc no> | <diff/test evidence> |

## Target Boundary Conformance

Ghi đúng một row cho `provider`, `router`, `localization`, `subscription` và `lifecycle`. Widget không gọi trực tiếp service/router; localization phải dùng mechanism của target.

| Boundary | Planned Owner Path/Symbol | Actual Owner Path/Symbol | Invocation Path | Mechanism | Lifecycle/Failure Evidence | Verdict |
|---|---|---|---|---|---|---|
| <canonical boundary> | <path#symbol> | <path#symbol> | <ordered invocation path> | <target mechanism> | <exact evidence> | <PASS hoặc BLOCKED> |

## Exemplar Deviations

Nếu không có deviation, ghi một row `not-applicable`. Mọi abstraction mới phải có resolved decision và Tech Lead approval.

| Deviation Reference | Concern | Conflict Reference | Actual Abstraction | Resolved Decision | Tech Lead Approval | Status |
|---|---|---|---|---|---|---|
| <DEV-* hoặc not-applicable> | <canonical concern hoặc not-applicable> | <CONFLICT-* hoặc not-applicable> | <abstraction hoặc not-applicable> | <resolved:DECISION-*: ... hoặc not-applicable> | <approval:TECH-LEAD-* hoặc not-applicable> | <approved, blocked hoặc not-applicable> |

## Production Activation Path Evidence

Với slice applicable, `Registration` được derive chính xác thành `<router Owner Path/Symbol> @ <construct.Output>` từ boundary và `Activation Slice` Task 6. `Production Evidence` được derive chính xác thành `<test.Output> @ <test.Source Reference>`. Không thêm private key-value evidence vào Task 6.

| Applicability | Decision Reference | Entry Point | Registration | Runtime Path | Production Evidence | Verdict |
|---|---|---|---|---|---|---|
| <applicable hoặc not-applicable-approved> | <approval:TECH-LEAD-* hoặc not-applicable> | <path#symbol hoặc not-applicable> | <path#symbol hoặc not-applicable> | <ordered production path hoặc not-applicable> | <integration evidence hoặc not-applicable> | <PASS, BLOCKED hoặc NOT_APPLICABLE> |

## Assurance State

Ba state độc lập; runtime waiver không thay đổi architecture hay selector/schema.

| Runtime Evidence State | Architecture Conformance State | Selector Schema State |
|---|---|---|
| <PASS, FAIL, NOT_RUN hoặc WAIVED> | <PASS hoặc BLOCKED> | <PASS hoặc BLOCKED> |

## Responsibility Plan Reference

| Work Item ID | Plan Reference | Plan Revision | Design Revision |
|---|---|---|---|
| <WORK-*> | <explicit approved step-08 plan path> | <positive approved revision> | <DESIGN-*@revision> |

## Responsibility Owner References

Copy the selected work-item row exactly from the approved plan. These IDs scope the actual matrices; do not include unrelated design owners.

| Work Item ID | Design Revision | Responsibility IDs | Shared Foundation IDs | Integration Responsibility IDs | Independent Boundary Evidence |
|---|---|---|---|---|---|
| <WORK-*> | <DESIGN-*@revision> | <ordered RESP-* or not-applicable> | <ordered RESP-* or not-applicable> | <ordered RESP-* or not-applicable> | <exact approved immutable evidence> |

## Actual File Responsibility Matrix

Copy every approved `File Responsibility Matrix` field exactly and add source or final-diff evidence for the observed owner, public symbols and effects. This actual inventory is not a self-attestation that can create semantic PASS.

For real source and verification files, emit every contract payload with the language-valid semantic marker documented by the responsibility contract: exact whole-line `// arc:<payload>` for slash-comment languages or `# arc:<payload>` for hash-comment/PowerShell languages. Every owner has a same-ID `@ownership-begin RESP-*` / `@ownership-end RESP-*` pair. Put all imports, re-exports, directives, module declarations, shared wiring, and owned symbols inside one non-nesting range; content outside is unowned. Apply the sentinel to `@...`, `route ...`, and `scenario ...`; bare language-invalid pseudo-statements and inferred brace/indent/first-symbol boundaries are not producer formats.

| Responsibility ID | Owner Path | Owner Symbol | Boundary Kind | Primary Responsibility | Owned Capability IDs | Trace IDs | Atomic Boundary ID | Public Symbols | External Effects | Target Exemplar | Exemplar Classification | Classification Authority | Classification Evidence | Architecture Authority | Co-location Policy | Co-location Evidence | Verification Owner References | Conformance | Deviation Reference | Actual Evidence |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| <RESP-*> | <path> | <symbol> | <approved value> | <approved value> | <CAP-*> | <trace IDs> | <approved value> | <symbols> | <effects> | <approved value> | <approved value> | <approved value> | <approved value> | <approved value> | <approved value> | <approved value> | <VERIFY-OWNER-*> | <yes or no> | <DEV-* or not-applicable> | <source/diff evidence> |

## Actual Verification Ownership Matrix

| Verification Owner ID | Production Responsibility ID | Capability ID | Evidence Path | Evidence Symbol or Scenario | Evidence Kind | Verification Disposition | Production Binding Evidence | Decision Reference | Verdict | Deviation Reference | Actual Evidence |
|---|---|---|---|---|---|---|---|---|---|---|---|
| <VERIFY-OWNER-*> | <RESP-*> | <CAP-*> | <path> | <symbol/scenario> | <approved kind> | <required or not-applicable-approved> | <production binding> | <decision or not-applicable> | <PASS or BLOCKED> | <DEV-* or not-applicable> | <source/diff evidence> |

## Architecture Responsibility Verdicts

`Architecture Conformance State` is derived only: PASS iff Tree Conformance, Responsibility Conformance and Verification Ownership are all PASS; runtime or auto-waive cannot alter these verdicts.

| Responsibility Contract Version | Tree Conformance | Responsibility Conformance | Verification Ownership | Architecture Conformance State | Evidence References |
|---|---|---|---|---|---|
| 1 | <PASS or BLOCKED> | <PASS or BLOCKED> | <PASS or BLOCKED> | <PASS or BLOCKED> | <design/diff/review evidence> |

## Selected Migration Unit

`Plan Reference`: `<selector authority>@<positive authority revision>` (exact canonical composite).

Chỉ giữ section này khi `Adapter Kind = migration-unit`; với adapter khác, xóa toàn bộ section và không phát minh `migration_unit_id`.

Ô `Foundation Baseline ID` ghi chính xác `foundation_baseline_id` được predecessor đã duyệt chọn hoặc tạo.

| Migration Unit ID | Plan Reference | Approval Reference | Mode Constraint | Bootstrap Scope | Foundation Baseline ID | Foundation Baseline Reference | Foundation Baseline Approval Reference | Baseline Reference | Trace IDs |
|---|---|---|---|---|---|---|---|---|---|
| <UNIT-001> | <tham chiếu plan> | <tham chiếu duyệt đơn vị> | <ràng buộc mode/policy> | <required hoặc not-required> | <FOUNDATION-* ID đã duyệt hoặc not-applicable> | <tham chiếu target-baseline đã duyệt hoặc not-applicable> | <tham chiếu duyệt hoặc not-applicable> | <tham chiếu bằng chứng hồi quy hoặc not-applicable> | <trace IDs> |

## File đã thay đổi

Lặp một row khi cùng file liên kết tới nhiều seam đã duyệt.

| Migration Unit ID | Activation Slice ID | Seam | File | Change | Trace IDs |
|---|---|---|---|---|---|
| <UNIT-001> | <ACT-001> | <canonical seam> | <path> | <thay đổi> | <approved slice/seam trace IDs> |

Chỉ giữ bảng legacy phía trên khi adapter là `migration-unit`. Mọi adapter phải dùng bảng authoritative theo work item dưới đây.

## Work Item Changed Files

Required for normal `draft/complete` and `approved/complete` implementation output. A truthful `draft/blocked` pre-mutation report may omit this section and `Work Item Test Evidence`, and must stop before target edit. Each non-empty `Trace IDs` cell is a canonical subset of both the external work item and the cited predecessor `(Activation Slice ID, Seam)` trace set.

| Work Item ID | Activation Slice ID | Seam | File | Change | Trace IDs |
|---|---|---|---|---|---|
| <WORK-*> | <ACT-001> | <canonical seam> | <path> | <thay đổi> | <approved slice/seam trace IDs> |

## Activation Slice Test Evidence

Lặp một row khi cùng test chứng minh nhiều seam đã duyệt.

| Migration Unit ID | Activation Slice ID | Seam | Test | Command | Result | Trace IDs |
|---|---|---|---|---|---|---|
| <UNIT-001> | <ACT-001> | <canonical seam> | <test/scenario> | <lệnh> | <PASS / FAIL / BLOCKED> | <approved slice/seam trace IDs> |

Chỉ giữ bảng legacy phía trên khi adapter là `migration-unit`. Mọi adapter phải dùng bảng authoritative theo work item dưới đây.

## Work Item Test Evidence

Required for normal `draft/complete` and `approved/complete` implementation output. Do not create placeholder implementation evidence to make a blocked gate look complete.

| Work Item ID | Activation Slice ID | Seam | Test | Command | Result | Trace IDs |
|---|---|---|---|---|---|---|
| <WORK-*> | <ACT-001> | <canonical seam> | <test/scenario> | <lệnh> | <PASS / FAIL / BLOCKED> | <approved slice/seam trace IDs> |

## Trace ID triển khai

| Trace ID | Implementation Reference |
|---|---|
| <REQ-001> | <path hoặc symbol> |

## Change Hygiene

List every pinned `task-base..final-tree` changed Git path exactly once from the NUL-delimited Git inventory; duplicate, surplus, stale, or omitted rows are blocking. Normalize repository path separators to `/` and Unicode to NFC before writing the row. Embedded spaces and Unicode are valid; absolute paths, empty or dot segments, traversal, control characters, and contract-delimiter ambiguity are invalid. Use exact `File Kind`: `A/C = new`, `M/R = existing`, `D = deleted`. `Edited Region / Symbol` is one exact identifier or an exact comma-and-space-separated identifier list, never a placeholder, wildcard, whole-file, or repository-wide claim. `Formatter Command` is exact `none` or a safe command containing and scoped to the row's canonical path; `.`, `*`, and `--all` repository-wide operands are forbidden. `Unrelated Diff` is exact `none` or `confirmed:MAJOR-*`; a confirmed disposition must be independently reviewed as a blocking Major. Every deleted path is resolved from task-base whether or not it contains an owner and does not need to exist in final-tree; set `Checkpoint History` to exact `source:<task-base SHA>:<deleted path>; diff:<task-base SHA>..<final-tree SHA>:<deleted path>`. For a removed responsibility block in a surviving file, use `existing` and the same base-source/removal-diff evidence for that owner symbol. A rename keeps the destination in `File`, preserves old/new authority, and requires exact `source:<task-base SHA>:<old path>; diff:<task-base SHA>..<final-tree SHA>:<old path>-><new path>`. Omitted, duplicate, surplus, stale, foreign, or status-mismatched rows are blocking.

| Task / Unit | File | File Kind | Edited Region / Symbol | Formatter Command | Unrelated Diff | Checkpoint History | Task-base SHA | Final-tree SHA |
|---|---|---|---|---|---|---|---|---|
| <WORK-*> | <path> | <new, existing, or deleted> | <canonical region or symbol identifiers> | <path-scoped command or none> | <none or confirmed:MAJOR-*> | <checkpoint SHAs, deletion evidence, or none> | <sha> | <sha> |

## Lệnh và kết quả

| Command | Result | Evidence |
|---|---|---|
| <lệnh> | <kết quả> | <tham chiếu> |

## Blocker gốc

Ghi `not-applicable` khi không có blocker. Nếu có, giữ nguyên kết luận `BLOCKED`, vai trò lệnh, vòng đời lệnh bắt buộc và lỗi command/capability verbatim của bước. Mọi lệnh bắt buộc đã khởi chạy đều không đủ điều kiện waiver; chỉ availability probe riêng biệt với vòng đời lệnh bắt buộc `not-started` mới có thể là ứng viên environment waiver. Bước giữ artifact ở draft/blocked; chỉ orchestrator được thêm automation waiver đã duyệt.

| Stage / Check | Native Verdict | Command Role | Required Command Lifecycle | Command / Capability | Observed Error | Evidence Reference |
|---|---|---|---|---|---|---|
| <baseline trước mutation hoặc kiểm tra triển khai> | `BLOCKED` | <availability probe hoặc lệnh test/build/baseline bắt buộc> | <not-started, started-without-correctness/regression-result hoặc started-and-produced-correctness/regression-result> | <command hoặc capability verbatim> | <lỗi quan sát được verbatim> | <tham chiếu bằng chứng> |

## Approved Baseline Waiver

<!-- Chỉ dùng khi orchestrator re-invoke step 10 bằng waiver baseline đã duyệt; nếu không dùng ghi `not-applicable`. -->

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

## Step 10 Waiver Resume State

| Resume Phase | Baseline Action | Implementation Status | Target Mutation Evidence | Waiver Evidence |
|---|---|---|---|---|
| `not-applicable` hoặc `resume-required` hoặc `resume-consumed` | `skip-pre-mutation-baseline-only` hoặc not-applicable | <normal outcome hoặc blocked> | <target source mutation + unit/trace evidence, hoặc none> | <exact approved waiver evidence, hoặc not-applicable> |

## Activation Slice

Ghi `not-applicable-approved` với evidence và decision reference khi unit không có activation selector; không được bỏ section.

Preserve every external `ACT-[0-9]{3}` slice with exactly the nine canonical seams, in canonical order, and legal disposition/status combinations from `contracts/activation-slice.md`. `Source Reference` may be exact or append `; <non-whitespace evidence>`; all other authority fields remain exact.

| Activation Slice ID | Applicability | Seam | Input | Output | Source Reference | Trace IDs | Disposition | Status | Decision Reference | Deferred Unit ID |
|---|---|---|---|---|---|---|---|---|---|---|
| <ACT-001> | <applicable / not-applicable-approved / unknown> | <canonical seam> | <input> | <output> | <source reference> | <trace IDs> | <implement / reuse / deferred-approved / not-applicable-approved> | <verified / missing / conflict / unknown> | <approval reference hoặc not-applicable> | <UNIT-* hoặc not-applicable> |

## Bằng chứng

| Evidence | Location | Notes |
|---|---|---|
| <bằng chứng> | <tham chiếu> | <ghi chú> |

## Domain Blocker

Chỉ giữ section này khi front matter là `result: blocked` và Activation Slice/handoff vẫn hợp lệ; mọi output khác phải xóa toàn bộ section. Giá trị placeholder không phải evidence hợp lệ.

| Blocker | Evidence Reference |
|---|---|
| <blocker cụ thể> | <tham chiếu bằng chứng cụ thể> |
## Điểm chưa rõ

- <điểm chưa rõ hoặc giả định>

## Kết luận

<ready | partial | blocked>

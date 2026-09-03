---
step_id: <orchestrator-provided>
status: draft
result: complete
produced_at: <yyyy-mm-dd>
---

<!-- artifact_language: vi -->

# Báo cáo triển khai migration

## Master Scope Context

| Master Spec Reference | Master Spec ID | Master Spec Revision | Master Plan Reference | Master Plan ID | Master Plan Revision | Work Item ID | Work Item Approval Reference |
|---|---|---|---|---|---|---|---|
| <master-spec.md> | <SPEC-*> | <revision> | <master-plan.md> | <PLAN-*> | <revision> | <WORK-*> | <approval:TECH-LEAD-*> |

## Canonical Adapter Evidence

Mỗi work item có đúng một row. `Canonical Match` chỉ là `PASS` khi selector khớp canonical Task 5; adapter `none` dùng `not-applicable` cho bốn field selector.

| Work Item ID | Adapter Kind | External ID | Authority | Authority Revision | Approval Reference | Canonical Match |
|---|---|---|---|---|---|---|
| <WORK-*> | <migration-unit, task, story, package, phase, milestone hoặc none> | <external ID hoặc not-applicable> | <authority hoặc not-applicable> | <revision hoặc not-applicable> | <approval hoặc not-applicable> | <PASS hoặc BLOCKED> |

## Conformance Matrix Reference

`Matrix Approval Reference` resolves to the canonical approved master-plan Work Item authority. Task 6 remains in its actual canonical `draft/complete` lifecycle; do not invent technical-design approval front matter or approval tables.

| Work Item ID | Discovery Reference | Design Reference | Design Revision | Matrix Approval Reference | Matrix Status |
|---|---|---|---|---|---|
| <WORK-*> | <02-discovery.md> | <07-technical-design.md> | <revision> | <approval:TECH-LEAD-*> | <approved hoặc blocked> |

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

| Deviation Reference | Concern | Actual Abstraction | Resolved Decision | Tech Lead Approval | Status |
|---|---|---|---|---|---|
| <DEV-* hoặc not-applicable> | <canonical concern hoặc not-applicable> | <abstraction hoặc not-applicable> | <resolved:DECISION-*: ... hoặc not-applicable> | <approval:TECH-LEAD-* hoặc not-applicable> | <approved, blocked hoặc not-applicable> |

## Production Activation Path Evidence

For an applicable slice, `Registration` and `Production Evidence` come from the external approved Activation Slice `construct.Source Reference` and `test.Source Reference`; report prose cannot create this authority.

| Applicability | Decision Reference | Entry Point | Registration | Runtime Path | Production Evidence | Verdict |
|---|---|---|---|---|---|---|
| <applicable hoặc not-applicable-approved> | <approval:TECH-LEAD-* hoặc not-applicable> | <path#symbol hoặc not-applicable> | <path#symbol hoặc not-applicable> | <ordered production path hoặc not-applicable> | <integration evidence hoặc not-applicable> | <PASS, BLOCKED hoặc NOT_APPLICABLE> |

## Assurance State

Ba state độc lập; runtime waiver không thay đổi architecture hay selector/schema.

| Runtime Evidence State | Architecture Conformance State | Selector Schema State |
|---|---|---|
| <PASS, FAIL, NOT_RUN hoặc WAIVED> | <PASS hoặc BLOCKED> | <PASS hoặc BLOCKED> |

## Selected Migration Unit

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

| Task / Unit | File | File Kind | Edited Region / Symbol | Formatter Command | Unrelated Diff | Checkpoint History | Task-base SHA | Final-tree SHA |
|---|---|---|---|---|---|---|---|---|
| <WORK-*> | <path> | <new or existing> | <region or symbol> | <command or none> | none | <checkpoint SHAs or none> | <sha> | <sha> |

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

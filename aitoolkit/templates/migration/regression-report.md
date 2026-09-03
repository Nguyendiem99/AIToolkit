---
step_id: <orchestrator-provided>
status: draft
result: complete
approval_source: <human | auto | auto-waive>
produced_at: <yyyy-mm-dd>
responsibility_contract:
  version: 1
  applicability: required
---

Executable output renders exactly `status: approved`, `result: complete`, and `approval_source: human`; draft, blocked, or automatic output is non-executable.

<!-- artifact_language: vi -->

# Báo cáo hồi quy migration

## Master Scope Context

| Run ID | Master Spec Reference | Master Spec ID | Master Spec Revision | Master Plan Reference | Master Plan ID | Master Plan Revision | Work Item ID |
|---|---|---|---|---|---|---|---|
| <RUN-*> | <master spec reference> | <SPEC-*> | <revision> | <master plan reference> | <PLAN-*> | <revision> | <WORK-*> |

- Delivery Adapter Kind: <migration-unit | task | story | package | phase | milestone | none>
- Delivery Adapter Mode Constraint: <incremental/preserve-existing | greenfield/design-new>

## Task Provenance

| Task / Unit | Task-base SHA | Final-tree SHA | Source Artifact |
|---|---|---|---|
| <UNIT-* for migration-unit; WORK-* otherwise> | <sha> | <sha> | <parity-report path> |

Preserve the approved adapter-aware assurance identity ordinally.

## Architecture Responsibility Handoff

Chép nguyên văn đúng một bảng từ `13-parity-report.md` là artifact ngay trước. Xác thực version trước mọi matrix, giữ thứ tự sub-verdict/evidence và trạng thái aggregate suy diễn; không dựng lại từ artifact tích lũy hoặc quét thư mục.

| Responsibility Contract Version | Tree Conformance | Responsibility Conformance | Verification Ownership | Architecture Conformance State | Evidence References |
|---|---|---|---|---|---|
| 1 | PASS | PASS | PASS | PASS | source-diff:<task-base SHA>..<final-tree SHA>#<WORK-*> |

## Selected Migration Unit

`Plan Reference`: `<selector authority>@<positive authority revision>` (exact canonical composite).

Keep `Selected Migration Unit` only when `Delivery Adapter Kind` is `migration-unit`; otherwise omit it.

| Migration Unit ID | Plan Reference | Approval Reference | Mode Constraint | Bootstrap Scope | Foundation Baseline ID | Foundation Baseline Reference | Foundation Baseline Approval Reference | Baseline Reference | Trace IDs |
|---|---|---|---|---|---|---|---|---|---|
| <UNIT-001> | <tham chiếu plan> | <tham chiếu duyệt đơn vị> | <incremental/preserve-existing> | <not-required> | <not-applicable> | <not-applicable> | <not-applicable> | <tham chiếu bằng chứng hồi quy trước thay đổi> | <trace IDs> |

## Activation Slice

Chuyển tiếp nguyên vẹn envelope từ artifact ngay trước: toàn bộ stable slice ID, Applicability, chín seam row, Source Reference và Trace IDs; không dựng lại từ artifact tích lũy.

| Activation Slice ID | Applicability | Seam | Input | Output | Source Reference | Trace IDs | Disposition | Status | Decision Reference | Deferred Unit ID |
|---|---|---|---|---|---|---|---|---|---|---|
| <ACT-001> | <applicable / not-applicable-approved / unknown> | <canonical seam> | <input> | <output> | <source reference> | <trace IDs> | <implement / reuse / deferred-approved / not-applicable-approved> | <verified / missing / conflict / unknown> | <approval reference hoặc not-applicable> | <UNIT-* hoặc not-applicable> |

## Kết luận xác minh migration

| Parity Verdict | Regression Applicability | Regression Verdict | Evidence Reference |
|---|---|---|---|
| <pass hoặc fail> | <required> | <pass, fail hoặc blocked> | <tham chiếu bằng chứng parity và regression> |

## Kịch bản

| Scenario | Baseline | Actual | Delta Class | Waiver Reference | Trace IDs | Verdict |
|---|---|---|---|---|---|---|
| <kịch bản> | <hành vi baseline> | <hành vi thực tế> | <expected / new-regression / existing-failure> | <waiver hoặc not-applicable> | <trace IDs> | <pass / fail / blocked> |

## Lệnh / Bằng chứng

| Command | Evidence | Result |
|---|---|---|
| <lệnh> | <tham chiếu> | <kết quả> |

## Bằng chứng

| Evidence | Location | Notes |
|---|---|---|
| <bằng chứng> | <tham chiếu> | <ghi chú> |

## Điểm chưa rõ

- <điểm chưa rõ hoặc giả định>

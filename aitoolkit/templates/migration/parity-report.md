---
step_id: <orchestrator-provided>
status: draft
result: complete
produced_at: <yyyy-mm-dd>
---

<!-- artifact_language: vi -->

# Báo cáo tương đương migration

## Task Provenance

| Task / Unit | Task-base SHA | Final-tree SHA | Source Artifact |
|---|---|---|---|
| <UNIT-001> | <sha> | <sha> | <verification-report path> |

## Selected Migration Unit

| Migration Unit ID | Plan Reference | Approval Reference | Mode Constraint | Bootstrap Scope | Foundation Baseline ID | Foundation Baseline Reference | Foundation Baseline Approval Reference | Baseline Reference | Trace IDs |
|---|---|---|---|---|---|---|---|---|---|
| <UNIT-001> | <tham chiếu plan> | <tham chiếu duyệt đơn vị> | <ràng buộc mode/policy> | <required hoặc not-required> | <FOUNDATION-001 hoặc not-applicable> | <tham chiếu target-baseline đã duyệt hoặc not-applicable> | <tham chiếu duyệt hoặc not-applicable> | <tham chiếu bằng chứng hồi quy hoặc not-applicable> | <trace IDs> |

## Activation Slice

Chuyển tiếp nguyên vẹn envelope từ artifact ngay trước: toàn bộ stable slice ID, Applicability, chín seam row, Source Reference và Trace IDs; không dựng lại từ artifact tích lũy.

| Activation Slice ID | Applicability | Seam | Input | Output | Source Reference | Trace IDs | Disposition | Status | Decision Reference | Deferred Unit ID |
|---|---|---|---|---|---|---|---|---|---|---|
| <ACT-001> | <applicable / not-applicable-approved / unknown> | <canonical seam> | <input> | <output> | <source reference> | <trace IDs> | <implement / reuse / deferred-approved / not-applicable-approved> | <verified / missing / conflict / unknown> | <approval reference hoặc not-applicable> | <UNIT-* hoặc not-applicable> |

## Parity Verdict

| Parity Verdict | Evidence Reference |
|---|---|
| <pass / fail / blocked> | <tham chiếu bằng chứng verdict tổng thể> |

## Kịch bản

| Scenario | Baseline | Actual | Verdict |
|---|---|---|---|
| <kịch bản> | <hành vi nguồn> | <hành vi đích> | <pass / fail / blocked> |

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

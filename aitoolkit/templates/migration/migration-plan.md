---
step_id: <orchestrator-provided>
status: draft
result: complete
produced_at: <yyyy-mm-dd>
---

<!-- artifact_language: vi -->

# Kế hoạch migration

## Các đơn vị migration theo thứ tự

| Order | Migration Unit ID | Bootstrap Scope | Foundation Baseline ID | Foundation Approval Reference | Dependencies | Acceptance | Mode Constraint | Trace IDs | Delivery Change Boundary | Approval Reference | Approval Status |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | <UNIT-001> | <required hoặc not-required> | <pending-bootstrap, FOUNDATION-* ID đã duyệt hoặc not-applicable> | <pending-step09-approval, tham chiếu foundation đã duyệt hoặc not-applicable> | <dependency> | <tiêu chí chấp nhận> | <ràng buộc mode/policy> | <trace IDs> | one-unit-one-change | <tham chiếu duyệt đơn vị> | <approved hoặc pending> |

## Baseline nền tảng đã duyệt

| Foundation Baseline ID | Target Baseline Reference | Approval Reference | Approval Status | Evidence |
|---|---|---|---|---|
| <FOUNDATION-001> | <bản ghi target-baseline đã duyệt> | <tham chiếu duyệt> | <approved> | <bằng chứng revision/độ mới> |

## Activation Slice

Ghi `not-applicable-approved` với evidence và decision reference khi unit không có activation selector; không được bỏ section.

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

<ready | blocked>

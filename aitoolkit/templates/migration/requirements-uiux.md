---
step_id: <orchestrator-provided>
status: draft
result: complete
produced_at: <yyyy-mm-dd>
---

<!-- artifact_language: vi -->

# Yêu cầu và UI/UX migration

## Yêu cầu

| Requirement ID | UIUX ID | Discovery IDs | State / Interaction | Source | Acceptance |
|---|---|---|---|---|---|
| <REQ-001> | <UIUX-001> | <discovery IDs> | <trạng thái hoặc tương tác> | <tham chiếu nguồn> | <tiêu chí chấp nhận> |

## Activation Slice

Chuyển tiếp nguyên vẹn envelope từ artifact ngay trước: toàn bộ stable slice ID, Applicability, chín seam row, Source Reference và Trace IDs; không dựng lại từ artifact tích lũy.

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

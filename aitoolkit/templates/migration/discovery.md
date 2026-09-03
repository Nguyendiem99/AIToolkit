---
step_id: <orchestrator-provided>
status: draft
result: complete
produced_at: <yyyy-mm-dd>
---

<!-- artifact_language: vi -->

# Khảo sát migration

## Danh mục khảo sát

| Type | Name | Source Reference | Notes |
|---|---|---|---|
| Feature | <tính năng> | <tham chiếu nguồn> | <ghi chú> |
| Screen | <màn hình> | <tham chiếu nguồn> | <ghi chú> |
| Component | <thành phần> | <tham chiếu nguồn> | <ghi chú> |
| State | <trạng thái> | <tham chiếu nguồn> | <ghi chú> |
| Service | <dịch vụ> | <tham chiếu nguồn> | <ghi chú> |
| Dependency | <dependency> | <tham chiếu nguồn> | <ghi chú> |

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

---
step_id: <orchestrator-provided>
status: draft
result: complete
produced_at: <yyyy-mm-dd>
---

<!-- artifact_language: vi -->

# Báo cáo bootstrap migration

Báo cáo này nhận `pending-bootstrap` từ đơn vị bắt buộc đã chọn và sinh một bản ghi `FOUNDATION-*`. Bản nháp vẫn ở trạng thái chờ; phê duyệt step 09 sẽ chốt tham chiếu và trạng thái trong cùng một thao tác.

## Selected Migration Unit

`Plan Reference`: `<selector authority>@<positive authority revision>` (exact canonical composite).

| Migration Unit ID | Plan Reference | Approval Reference | Mode Constraint | Bootstrap Scope | Foundation Baseline ID | Foundation Baseline Reference | Foundation Baseline Approval Reference | Baseline Reference | Trace IDs |
|---|---|---|---|---|---|---|---|---|---|
| <UNIT-001> | <tham chiếu migration-plan> | <tham chiếu duyệt đơn vị> | <greenfield/design-new> | <required> | <FOUNDATION-001> | <bản ghi target-baseline đã tạo> | <pending-step09-approval> | <not-applicable> | <trace IDs> |

## Activation Slice

Chuyển tiếp nguyên vẹn envelope từ artifact ngay trước: toàn bộ stable slice ID, Applicability, chín seam row, Source Reference và Trace IDs; không dựng lại từ artifact tích lũy.

| Activation Slice ID | Applicability | Seam | Input | Output | Source Reference | Trace IDs | Disposition | Status | Decision Reference | Deferred Unit ID |
|---|---|---|---|---|---|---|---|---|---|---|
| <ACT-001> | <applicable / not-applicable-approved / unknown> | <canonical seam> | <input> | <output> | <source reference> | <trace IDs> | <implement / reuse / deferred-approved / not-applicable-approved> | <verified / missing / conflict / unknown> | <approval reference hoặc not-applicable> | <UNIT-* hoặc not-applicable> |

Chỉ giữ section baseline nền tảng dưới đây cho `draft/complete` hoặc `approved/complete`. Với `result: blocked`, xóa toàn bộ section này, giữ tuple pending trong `Selected Migration Unit`, không ghi target mutation, và điền `Domain Blocker` (`blocked-foundation-section=absent`; `blocked-selected-state=pending`).

## Bản ghi baseline nền tảng

| Foundation Baseline ID | Source Migration Unit ID | Target Baseline Reference | Approval Reference | Approval Status | Evidence |
|---|---|---|---|---|---|
| <FOUNDATION-001> | <UNIT-001> | <bản ghi target-baseline đã tạo> | <pending-step09-approval; thay nguyên tử bằng tham chiếu artifact bootstrap đã duyệt chính xác> | <pending-approval; đặt nguyên tử thành approved tại gate> | <bằng chứng revision thiết kế, độ mới, path thay đổi và lệnh> |

Khi gate step 09 được duyệt, cập nhật hàng `Selected Migration Unit`, Bản ghi baseline nền tảng này và frontmatter trong cùng một thao tác; không ghi trước tham chiếu duyệt trong bản nháp.

## Kết quả bootstrap

| Item | Command | Result | Notes |
|---|---|---|---|
| <hạng mục bootstrap> | <lệnh> | <kết quả> | <ghi chú> |

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

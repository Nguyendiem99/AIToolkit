---
step_id: <shared: orchestrator truyền>
status: draft
# Chỉ migration: thêm `result: complete | blocked`
produced_at: <yyyy-mm-dd>
---

<!-- artifact_language: vi -->

# Báo cáo AI Review — <tên module>

## Selected Migration Unit

| Migration Unit ID | Plan Reference | Approval Reference | Mode Constraint | Bootstrap Scope | Foundation Baseline ID | Foundation Baseline Reference | Foundation Baseline Approval Reference | Baseline Reference | Trace IDs |
|---|---|---|---|---|---|---|---|---|---|
| <UNIT-001> | <tham chiếu plan> | <tham chiếu duyệt đơn vị> | <ràng buộc mode/policy> | <required hoặc not-required> | <FOUNDATION-001 hoặc not-applicable> | <tham chiếu target-baseline đã duyệt hoặc not-applicable> | <tham chiếu duyệt hoặc not-applicable> | <tham chiếu bằng chứng hồi quy hoặc not-applicable> | <trace IDs> |

## Tổng quan
- Phạm vi review (SHA): `<BASE>..<HEAD>`
- Project rules áp dụng: <path profile/pack + rule bắt buộc + khoảng trống tùy chọn/độ phủ suy giảm>

## Rule Resolution
- **State:** `RESOLVED | BLOCKED`
- **Mandatory rule gaps:** <không có hoặc khoảng trống blocking chính xác>
- **Optional gaps/degraded coverage:** <không có hoặc độ phủ suy giảm đã ghi nhận>

## Critical
| File:line | Vấn đề | Fix đề xuất |
|---|---|---|

## Major
| File:line | Vấn đề | Fix đề xuất |
|---|---|---|

## Minor
| File:line | Vấn đề | Fix đề xuất |
|---|---|---|

## Change Hygiene

| Task / Unit | Scope Evidence | Formatter Evidence | Unrelated Diff | Severity | Task-base SHA | Final-tree SHA |
|---|---|---|---|---|---|---|
| <UNIT-001> | <changed files/symbols> | <commands or none> | <none or finding> | <none, Major, or Critical> | <sha> | <sha> |

## Activation Slice

Ghi `not-applicable-approved` với evidence và decision reference khi unit không có activation selector; không được bỏ section.

| Activation Slice ID | Applicability | Seam | Input | Output | Source Reference | Trace IDs | Disposition | Status | Decision Reference | Deferred Unit ID |
|---|---|---|---|---|---|---|---|---|---|---|
| <ACT-001> | <applicable / not-applicable-approved / unknown> | <canonical seam> | <input> | <output> | <source reference> | <trace IDs> | <implement / reuse / deferred-approved / not-applicable-approved> | <verified / missing / conflict / unknown> | <approval reference hoặc not-applicable> | <UNIT-* hoặc not-applicable> |

## Bằng chứng
- <tham chiếu diff/rule/evidence>

## Domain Blocker

Chỉ giữ section này khi front matter là `result: blocked` và Activation Slice/handoff vẫn hợp lệ; mọi output khác phải xóa toàn bộ section. Giá trị placeholder không phải evidence hợp lệ.

| Blocker | Evidence Reference |
|---|---|
| <blocker cụ thể> | <tham chiếu bằng chứng cụ thể> |
## Điểm chưa rõ
- <không có hoặc điểm chưa rõ>

## Kết luận
- **Critical count:** <số nguyên dùng để gate>
- **Verdict:** `Approve` | `Approve-with-fixes` | `Reject`

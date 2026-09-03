---
name: validate-inputs
description: Use when a migration run must establish whether its profile, project pack, source, documents, and prior artifacts are usable.
---

# Migration 01 — Validate Inputs

**Core principle:** Không có evidence thì ghi unknown; unknown chặn quyết định thì ghi `result: blocked`.

## Ngôn ngữ artifact

Nhận `artifact_language` do orchestrator truyền. Hiện chỉ hỗ trợ `artifact_language: vi`: viết tiêu đề, tóm tắt, blocker, khuyến nghị và nội dung gate bằng tiếng Việt UTF-8; giữ nguyên mọi field machine-readable, enum, ID, path, command, log, trace field và cột bảng contract.

## Inputs

Orchestrator truyền `RUN_DIR`, đường dẫn project profile, project pack, source, tài liệu và mọi artifact có trước. Không tự tìm state khác hoặc thay đường dẫn được truyền bằng đường dẫn suy đoán.

## Quy trình

1. Đọc `aitoolkit-schemas`, project profile, project pack và artifact path orchestrator truyền.
2. Validate `project_pack.reviewed_at` and `project_pack.review_evidence` before using any migration rule. The timestamp must be non-null and parseable as RFC 3339; review evidence must point to an approved pack-review artifact with matching timestamp and recorded content revisions.
3. Compare recorded revisions with the current profile (excluding review metadata), pack files, and cited source/target/document evidence. Evidence created or changed newer than `project_pack.reviewed_at`, a revision mismatch, or an inability to establish the comparison makes the review stale.
4. A missing, null, invalid, or stale `project_pack.reviewed_at` yields `result: blocked`. Readability alone is never proof that a pack is reviewed or current.
5. Chỉ dùng taxonomy, mapping và toolchain có Evidence trong input hoặc do project pack cung cấp.
6. Gán stable ID `INPUT-###` và Evidence cho từng input; kiểm tra đường dẫn, khả năng đọc, phiên bản contract và quan hệ giữa các input.
7. Ghi artifact theo `aitoolkit/templates/migration/input-report.md` trong `RUN_DIR`.
8. Phân biệt input vắng, input không đọc được và input có nội dung mâu thuẫn. Không biến tên file hoặc cấu trúc thư mục mơ hồ thành nhận diện công nghệ.

## Evidence và Unknowns

- `Evidence` ghi stable ID, đường dẫn/section kiểm chứng được và điều nó chứng minh.
- `Unknowns` ghi trường thiếu, tác động và evidence hoặc quyết định cần bổ sung.
- Thiếu profile/pack/source bắt buộc hoặc không xác định được contract cần cho bước sau thì dùng `result: blocked`.
- Input tùy chọn vắng nhưng không chặn bước sau có thể dùng `result: partial` và phải nêu giới hạn.

## Hợp đồng đầu ra

- File: `<RUN_DIR>/01-input-report.md`.
- Front matter: `step_id: 01-validate-inputs`, `status: draft`, `result: complete | partial | blocked`, `produced_at`.
- Giữ các phần `Inputs`, `Evidence`, `Unknowns`, `Verdict` của template.
- Mỗi verdict phải truy ngược được tới stable ID; không tuyên bố `complete` khi còn unknown chặn quyết định.

## Quick reference

| Tình trạng | Kết quả |
|---|---|
| Đủ input bắt buộc và kiểm chứng được | `complete` |
| Chỉ thiếu input tùy chọn | `partial` |
| Thiếu evidence/input cần cho quyết định tiếp theo | `blocked` |

## Common mistakes

- Đoán taxonomy từ tên file mơ hồ thay vì ghi unknown.
- Gộp nhiều input vào một record không có stable ID riêng.
- Ghi `complete` dù profile và project pack mâu thuẫn chưa có quyết định.
- Chỉ kiểm tra pack path tồn tại mà bỏ qua `reviewed_at` hoặc review-evidence revisions.

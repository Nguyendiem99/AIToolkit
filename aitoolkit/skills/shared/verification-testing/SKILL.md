---
name: verification-testing
description: Bước Verification & Testing (khung dùng chung, mọi workflow) — kiểm chứng hành vi, sinh & chạy test tự động, đo coverage. Đọc review-report.md, ghi verification-report.md.
---

# Shared — Verification & Testing

Conductor gọi với `step_id`, `run_id`, `run_dir`. Bước nặng → subagent.

## Việc cần làm
1. Đọc `aitoolkit-schemas`, template `verification-report.md`, `<run_dir>/review-report.md`.
2. Sinh test cho phần vừa đổi (dùng superpowers:test-driven-development khi khả thi); chạy `flutter test` (hoặc test suite tương ứng).
3. **Kiểm chứng hành vi**: với migration là so sánh Native vs Flutter; với bugfix là xác nhận bug hết & không hồi quy.
4. Áp superpowers:verification-before-completion: KHÔNG kết luận "đạt" nếu chưa có bằng chứng test.
5. Ghi `<run_dir>/verification-report.md` (kiểm chứng, kết quả test, coverage), `step_id` conductor truyền, `status: draft`. Trả về đường dẫn.

## Ranh giới
- Nếu test fail / hành vi lệch → nêu rõ để quay lại bước tạo code, KHÔNG che giấu.

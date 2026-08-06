---
name: verification-testing
description: Bước 06 migration (khung dùng chung) — so sánh hành vi Native vs Flutter, sinh & chạy test tự động, đo coverage. Đọc 05-review-report.md + source, ghi 06-verification-report.md.
---

# Shared 06 — Verification & Testing

Conductor gọi với `step_id=06-verification-testing`, `run_id`, `run_dir`. Bước nặng → subagent.

## Việc cần làm
1. Đọc `aitoolkit-schemas`, template `verification-report.md`, `<run_dir>/05-review-report.md`.
2. Sinh test cho phần đã migrate (dùng superpowers:test-driven-development khi khả thi); chạy `flutter test`.
3. **So sánh hành vi Native vs Flutter** theo kịch bản chính (từ discovery/mapping).
4. Áp superpowers:verification-before-completion: KHÔNG kết luận "đạt" nếu chưa có bằng chứng test.
5. Ghi `<run_dir>/06-verification-report.md` (comparison, test result, coverage), `status: draft`. Trả về đường dẫn.

## Ranh giới
- Nếu test fail / hành vi lệch nghiêm trọng → nêu rõ để quay lại bước 04, KHÔNG che giấu.

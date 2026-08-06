---
name: ai-review
description: Bước AI Review (khung dùng chung, mọi workflow) — review code theo rule LGE (convention, performance, security, null-safety), phân loại Critical/Major/Minor. Đọc artifact code/fix của bước ngay trước, ghi review-report.md.
---

# Shared — AI Review

Conductor gọi với `step_id` (do manifest quyết định), `run_id`, `run_dir`. Bước nặng → chạy trong subagent.

## Việc cần làm
1. Đọc `aitoolkit-schemas`, template `review-report.md`, và `lge-rules` (mọi mục; mục còn mốc «LGE team điền» ⇒ bỏ qua).
2. Xác định code cần review: tra `state.json` lấy **artifact của bước NGAY TRƯỚC** (vd `04-code-migration.md` với migration, `03-fix.md` với bugfix) để biết nhánh + file đã đổi.
3. Dùng superpowers:requesting-code-review để review code trên nhánh đó; áp thêm rule LGE đã điền.
4. Phân loại phát hiện thành **Critical / Major / Minor**, kèm `file:line` + đề xuất.
5. Ghi `<run_dir>/review-report.md` theo template, front-matter `step_id` = giá trị conductor truyền, `status: draft`. Trả về đường dẫn.

## Ranh giới
- CHỈ review + báo cáo; KHÔNG tự sửa code (dev sửa, hoặc quay lại bước tạo code nếu Critical).
- KHÔNG upload Gerrit.

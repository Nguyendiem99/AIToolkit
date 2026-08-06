---
name: ai-review
description: Bước 05 migration (khung dùng chung) — review code Flutter theo rule LGE (convention, performance, security, null-safety), phân loại Critical/Major/Minor. Đọc 04-migration-report.md + source, ghi 05-review-report.md.
---

# Shared 05 — AI Review

Conductor gọi với `step_id=05-ai-review`, `run_id`, `run_dir`. Bước nặng → chạy trong subagent.

## Việc cần làm
1. Đọc `aitoolkit-schemas`, template `review-report.md`, `<run_dir>/04-migration-report.md` (để biết nhánh + file đã sinh), và `lge-rules` (mọi mục; mục còn mốc «LGE team điền» ⇒ bỏ qua).
2. Dùng superpowers:requesting-code-review để review code trên nhánh migration; áp thêm rule LGE đã điền (convention, performance, security, null-safety).
3. Phân loại phát hiện thành **Critical / Major / Minor**, ghi kèm `file:line` + đề xuất.
4. Ghi `<run_dir>/05-review-report.md` theo template, `status: draft`. Trả về đường dẫn.

## Ranh giới
- CHỈ review + báo cáo; KHÔNG tự sửa code (dev sửa, hoặc quay lại bước 04 nếu Critical).
- KHÔNG upload Gerrit (bước 07).

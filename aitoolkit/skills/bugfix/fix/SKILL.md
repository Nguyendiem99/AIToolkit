---
name: fix
description: Bước 03 bugfix — sửa lỗi theo root-cause trong git worktree riêng, viết test chứng minh bug đã hết (TDD). Đọc 02-root-cause.md, ghi 03-fix.md.
---

# Bugfix 03 — Fix

Conductor gọi với `step_id=03-fix`, `run_id`, `run_dir`. Bước nặng → chạy trong subagent (isolate).

## Việc cần làm
1. Đọc `aitoolkit-schemas`, template `fix-report.md`, `<run_dir>/02-root-cause.md`, `lge-rules` (`code-convention`, `null-safety`; degrade khi còn mốc).
2. Tạo workspace cô lập: dùng superpowers:using-git-worktrees để tạo worktree + branch cho fix.
3. Áp superpowers:test-driven-development: viết **test tái hiện bug (đỏ)** trước → sửa code theo root-cause → test **xanh**. Áp `code-convention`/`null-safety` nếu có.
4. Chạy `flutter analyze` + `flutter test`; ghi kết quả.
5. Ghi `<run_dir>/03-fix.md` (fix-report): nhánh, worktree, bảng file đã đổi, test bổ sung (trước/sau fix), ghi chú build. `status: draft`. Trả về đường dẫn.

## Ranh giới
- CHỈ sửa theo nguyên nhân đã chốt (bước 02). Phát sinh ngoài phạm vi phải ghi rõ.
- KHÔNG upload Gerrit (bước Gerrit ở nửa sau), KHÔNG tự merge nhánh.

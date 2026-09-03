---
name: implement
description: Bước 03 feature — hiện thực tính năng theo design trong git worktree riêng, dùng writing-plans → executing-plans + TDD. Đọc 02-design.md, ghi 03-implement.md.
---

# Feature 03 — Implement

Read `shared/change-hygiene.md` before editing. Trace every edit to this feature task, distinguish new from existing files, record formatter commands, and inspect the final diff. Remove unrelated formatting or whole-file churn; local checkpoints must consolidate into one final delivery commit.

Orchestrator gọi skill này, truyền: `run_dir` + đường dẫn `<run_dir>/02-design.md`. Chạy inline.

## Việc cần làm
1. Đọc `aitoolkit-schemas`, template `implement-report.md`, `<run_dir>/02-design.md`, `lge-rules` (`code-convention`, `null-safety`; degrade khi còn mốc).
2. Tạo workspace cô lập: dùng superpowers:using-git-worktrees để tạo worktree + branch.
3. Biến design thành kế hoạch rồi thực thi: superpowers:writing-plans → executing-plans, áp test-driven-development. Sinh theo layer Clean Architecture + Riverpod: entity/usecase → repository/provider → widget/UI. Áp `code-convention`/`null-safety` nếu có.
4. Chạy `flutter analyze` + `flutter test`; ghi kết quả.
5. Ghi `<run_dir>/03-implement.md` (implement-report): nhánh, worktree, file tạo/sửa, test (TDD), ghi chú build và structured `Change Hygiene` gồm task-base SHA, file kind, edited region/symbol, formatter command, unrelated-diff verdict, checkpoint history. `status: draft`.

## Ranh giới
- CHỈ hiện thực theo design đã duyệt (bước 02). Lệch design phải ghi rõ.
- KHÔNG upload Gerrit (nửa sau), KHÔNG tự merge nhánh.

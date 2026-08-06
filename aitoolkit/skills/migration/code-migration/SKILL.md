---
name: code-migration
description: Bước 04 migration — sinh code Flutter (UI, logic, service, provider, repository) theo tech-design, trong git worktree riêng. Đọc 03-tech-design.md, ghi 04-migration-report.md.
---

# Migration 04 — Code Migration

Conductor gọi với `step_id=04-code-migration`, `run_id`, `run_dir`. Bước nặng → conductor chạy trong subagent (isolate).

## Việc cần làm
1. Đọc `aitoolkit-schemas`, template `migration-report.md`, `<run_dir>/03-tech-design.md`, `lge-rules` (`code-convention`, `null-safety`; degrade khi còn mốc).
2. Tạo workspace cô lập: dùng superpowers:using-git-worktrees để tạo worktree + feature branch cho lần migrate này.
3. Biến tech-design thành kế hoạch code rồi thực thi: dùng superpowers:writing-plans → executing-plans (TDD khi khả thi) để sinh theo layer Clean Architecture + Riverpod: entity/usecase → repository/provider → widget/UI. Áp `code-convention`/`null-safety` nếu có.
4. Chạy `flutter analyze` (và `flutter test` nếu có test) để bắt lỗi hiển nhiên; ghi kết quả.
5. Ghi `<run_dir>/04-migration-report.md`: tên nhánh, đường dẫn worktree, bảng file đã sinh (kèm nguồn Native), ghi chú build. `status: draft`. Trả về đường dẫn.

## Ranh giới
- CHỈ sinh code theo design đã duyệt (bước 03). Lệch design phải ghi rõ trong report.
- KHÔNG upload Gerrit (bước 07), KHÔNG tự merge nhánh.

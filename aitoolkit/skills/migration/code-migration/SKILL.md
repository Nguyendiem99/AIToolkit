---
name: code-migration
description: Bước 04 migration — sinh code Flutter (UI, logic, service, provider, repository) theo tech-design, trong git worktree riêng. Đọc 03-tech-design.md, ghi 04-migration-report.md.
---

# Migration 04 — Code Migration

Orchestrator gọi skill này, truyền: run_dir + đường dẫn artifact bước trước. Chạy inline.

## Việc cần làm
1. Đọc `aitoolkit-schemas`, template `migration-report.md`, `<run_dir>/03-tech-design.md` (artifact bước trước = đường dẫn orchestrator truyền vào), `lge-rules` (`code-convention`, `null-safety`; degrade khi còn mốc).
2. Tạo workspace cô lập: dùng superpowers:using-git-worktrees để tạo worktree + feature branch cho lần migrate này.
3. Biến tech-design thành kế hoạch code rồi thực thi: dùng superpowers:writing-plans → executing-plans (TDD khi khả thi) để sinh theo layer Clean Architecture + Riverpod: entity/usecase → repository/provider → widget/UI. Áp `code-convention`/`null-safety` nếu có.
4. Chạy `flutter analyze` (và `flutter test` nếu có test) để bắt lỗi hiển nhiên; ghi kết quả.
5. Ghi `<run_dir>/04-migration-report.md`: tên nhánh, đường dẫn worktree, bảng file đã sinh (kèm nguồn Native), ghi chú build. `status: draft`.

## Ranh giới
- CHỈ sinh code theo design đã duyệt (bước 03). Lệch design phải ghi rõ trong report.
- KHÔNG upload Gerrit (bước 07), KHÔNG tự merge nhánh.

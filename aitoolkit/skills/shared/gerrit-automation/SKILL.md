---
name: gerrit-automation
description: Bước Gerrit (khung dùng chung, mọi workflow) — tạo commit message + change description theo quy ước LGE, chuẩn bị upload Gerrit. Đọc verification-report.md, ghi gerrit-report.md. Upload chỉ sau HARD gate.
---

# Shared — Gerrit Automation

Orchestrator gọi skill này, truyền: run_dir + đường dẫn artifact bước trước. Chạy inline. Bước này có HARD gate (không đảo ngược khi upload).

## Việc cần làm
1. Đọc `aitoolkit-schemas`, template `gerrit-report.md`, `<run_dir>/verification-report.md`, `lge-rules` (`gerrit-commit`; nếu còn mốc dùng Conventional Commits mặc định).
2. Chuẩn bị nhánh: dùng superpowers:finishing-a-development-branch để đảm bảo nhánh sạch, test xanh.
3. Soạn **commit message** + **change description** theo `gerrit-commit`.
4. Ghi `<run_dir>/gerrit-report.md` với trạng thái "chưa upload".
5. **CHỜ orchestrator qua HARD gate** (Reviewer xác nhận). CHỈ SAU khi được duyệt mới thực hiện upload Gerrit (push refs/for/...), rồi cập nhật report + Change-Id.

## Ranh giới
- TUYỆT ĐỐI không upload trước khi HARD gate được duyệt.
- Không tự merge trên Gerrit (người/CI quyết).

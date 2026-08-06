---
name: gerrit-automation
description: Bước 07 migration (khung dùng chung) — tạo commit message + change description theo quy ước LGE, chuẩn bị upload Gerrit. Đọc 06-verification-report.md, ghi 07-gerrit-report.md. Upload chỉ sau HARD gate.
---

# Shared 07 — Gerrit Automation

Conductor gọi với `step_id=07-gerrit-automation`, `run_id`, `run_dir`. Chạy INLINE. Bước này có HARD gate (không đảo ngược khi upload).

## Việc cần làm
1. Đọc `aitoolkit-schemas`, template `gerrit-report.md`, `<run_dir>/06-verification-report.md`, `lge-rules` (`gerrit-commit`; nếu còn mốc dùng Conventional Commits mặc định).
2. Chuẩn bị nhánh: dùng superpowers:finishing-a-development-branch để đảm bảo nhánh sạch, test xanh.
3. Soạn **commit message** + **change description** theo `gerrit-commit`.
4. Ghi `<run_dir>/07-gerrit-report.md` với trạng thái "chưa upload".
5. **CHỜ conductor qua HARD gate** (Reviewer xác nhận). CHỈ SAU khi được duyệt mới thực hiện upload Gerrit (push refs/for/...), rồi cập nhật report + Change-Id.

## Ranh giới
- TUYỆT ĐỐI không upload trước khi HARD gate được duyệt.
- Không tự merge trên Gerrit (người/CI quyết).

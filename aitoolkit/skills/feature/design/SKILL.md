---
name: design
description: Bước 02 feature — thiết kế kỹ thuật cho tính năng mới (Clean Architecture + Riverpod): layer, folder, sequence, data flow, tác động phần hiện có. Đọc 01-requirements.md, ghi 02-design.md.
---

# Feature 02 — Design

Conductor gọi với `step_id=02-design`, `run_id`, `run_dir`. Chạy INLINE (cần bàn) — conductor dừng ở gate Tech Lead.

## Việc cần làm
1. Đọc `aitoolkit-schemas`, template `design.md`, `<run_dir>/01-requirements.md` (bắt buộc; thiếu → báo lỗi), và `lge-rules` (`code-convention`; degrade khi còn mốc).
2. Thiết kế theo **Clean Architecture + Riverpod**: chia Presentation / Domain (usecase, entity) / Data (repository, provider); folder feature-first `lib/features/<feature>/{presentation,domain,data}`; sequence luồng chính; data flow (provider giữ state gì).
3. Nêu **tác động lên phần hiện có** (thành phần bị ảnh hưởng, thay đổi).
4. Ghi `<run_dir>/02-design.md`, `status: draft`. Trả về đường dẫn.

## Ranh giới
- Thiết kế, CHƯA code (bước 03). Bám yêu cầu bước 01; phát sinh ngoài yêu cầu phải nêu rõ.

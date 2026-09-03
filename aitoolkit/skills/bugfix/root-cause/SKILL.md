---
name: root-cause
description: Bước 02 bugfix — truy nguyên nhân gốc bằng systematic-debugging (giả thuyết → kiểm chứng), xác định phạm vi ảnh hưởng. Đọc 01-reproduce.md, ghi 02-root-cause.md.
---

# Bugfix 02 — Root Cause

Orchestrator gọi skill này, truyền: `run_dir` + đường dẫn `<run_dir>/01-reproduce.md`. Chạy inline.

## Việc cần làm
1. Đọc `aitoolkit-schemas`, template `root-cause.md`, `<run_dir>/01-reproduce.md` (bắt buộc; thiếu → báo lỗi).
2. Dùng superpowers:systematic-debugging: đặt giả thuyết, kiểm chứng từng cái bằng bằng chứng thật (log, test, đọc code) — KHÔNG đoán bừa rồi sửa.
3. Xác định **nguyên nhân gốc** chính xác (kèm `file:line`), **phạm vi ảnh hưởng**, và **hướng sửa đề xuất**.
4. Ghi `<run_dir>/02-root-cause.md`, `status: draft`.

## Ranh giới
- CHỈ truy nguyên nhân + đề xuất hướng; CHƯA sửa code (bước 03).
- Nếu chưa đủ bằng chứng để chốt nguyên nhân → nói rõ, KHÔNG kết luận vội.

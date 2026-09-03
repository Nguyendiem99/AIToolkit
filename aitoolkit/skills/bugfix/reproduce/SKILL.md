---
name: reproduce
description: Bước 01 bugfix — tái hiện bug từ issue/ticket: các bước lặp lại, kỳ vọng vs thực tế, môi trường, log. Ghi 01-reproduce.md.
---

# Bugfix 01 — Reproduce

Orchestrator gọi skill này, truyền: `run_dir` + mô tả bug / link issue do người dùng cung cấp. Chạy inline.

## Việc cần làm
1. Đọc `aitoolkit-schemas`, template `aitoolkit/templates/reproduce.md`.
2. Từ mô tả bug: dựng **các bước tái hiện** rõ ràng, ghi **kỳ vọng vs thực tế**, môi trường, log/stack trace.
3. Cố gắng tái hiện thật (chạy app/test); ghi trạng thái: ổn định / chập chờn / chưa tái hiện được (kèm lý do).
4. Ghi `<run_dir>/01-reproduce.md`, `status: draft`.

## Ranh giới
- CHỈ tái hiện & mô tả; CHƯA truy nguyên nhân (bước 02), CHƯA sửa (bước 03).
- Nếu không tái hiện được → nêu rõ, KHÔNG đoán nguyên nhân.

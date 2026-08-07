---
name: technical-design
description: Bước 03 migration — thiết kế kiến trúc Flutter (Clean Architecture + Riverpod) cho phần đã map: layer, folder, sequence, data flow. Đọc 02-mapping.md, ghi 03-tech-design.md.
---

# Migration 03 — Technical Design

Orchestrator gọi skill này, truyền: run_dir + đường dẫn artifact bước trước. Chạy inline (cần bàn với người) — orchestrator dừng ở gate Tech Lead.

## Việc cần làm
1. Đọc `aitoolkit-schemas`, template `tech-design.md`, `<run_dir>/02-mapping.md` (artifact bước trước = đường dẫn orchestrator truyền vào), và `lge-rules` (mục `code-convention`; nếu còn mốc «LGE team điền» thì dùng mặc định Clean Architecture + feature-first folder).
2. Thiết kế theo **Clean Architecture + Riverpod**:
   - Chia **Presentation / Domain (usecase, entity) / Data (repository, provider)**.
   - **Folder** feature-first: `lib/features/<feature>/{presentation,domain,data}`.
   - **Sequence** luồng chính: UI → provider → usecase → repository → (platform channel tới Luna Service nếu cần).
   - **Data flow**: provider nào giữ state gì.
3. Ghi `<run_dir>/03-tech-design.md`, `status: draft`.

## Ranh giới
- Thiết kế, CHƯA sinh code (bước 04).
- Bám mapping ở bước 02; phát sinh ngoài mapping phải nêu rõ.

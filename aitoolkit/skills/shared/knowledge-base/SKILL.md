---
name: knowledge-base
description: Bước 10 migration (khung dùng chung) — lưu trữ toàn bộ tri thức của run (tóm tắt, liên kết artifact, bài học) vào knowledge base. Ghi 10-kb-entry.md. Không gate.
---

# Shared 10 — Knowledge Base

Conductor gọi với `step_id=10-knowledge-base`, `run_id`, `run_dir`. Bước nặng → subagent. KHÔNG gate.

## Việc cần làm
1. Đọc `aitoolkit-schemas`, template `kb-entry.md`, và LIỆT KÊ mọi artifact trong `run_dir`.
2. Tổng hợp **KB entry**: tóm tắt run (workflow, kết quả Go/No-Go), bảng liên kết artifact theo bước, bài học/vấn đề & cách xử lý.
3. (Tuỳ chọn) nếu có codebase-memory-mcp: gợi ý ingest artifact để truy vấn sau.
4. Ghi `<run_dir>/10-kb-entry.md`. Đây là bước cuối — báo pipeline hoàn tất.

## Ranh giới
- Chỉ tổng hợp & lưu; không thay đổi code hay artifact bước khác.

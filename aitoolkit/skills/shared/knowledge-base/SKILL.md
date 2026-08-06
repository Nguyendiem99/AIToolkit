---
name: knowledge-base
description: Bước Knowledge Base (khung dùng chung, mọi workflow) — lưu trữ toàn bộ tri thức của run (tóm tắt, liên kết artifact, bài học) vào knowledge base. Ghi kb-entry.md. Không gate.
---

# Shared — Knowledge Base

Conductor gọi với `step_id`, `run_id`, `run_dir`. Bước nặng → subagent. KHÔNG gate.

## Việc cần làm
1. Đọc `aitoolkit-schemas`, template `kb-entry.md`, và LIỆT KÊ mọi artifact trong `run_dir` (tra `state.json`).
2. Tổng hợp **KB entry**: tóm tắt run (workflow gì, kết quả Go/No-Go), bảng liên kết artifact theo bước, bài học/vấn đề & cách xử lý.
3. (Tuỳ chọn) nếu có codebase-memory-mcp: gợi ý ingest artifact để truy vấn sau.
4. Ghi `<run_dir>/kb-entry.md`, `step_id` conductor truyền. Đây là bước cuối — báo pipeline hoàn tất.

## Ranh giới
- Chỉ tổng hợp & lưu; không thay đổi code hay artifact bước khác.

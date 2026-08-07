---
name: knowledge-base
description: Bước Knowledge Base (khung dùng chung, mọi workflow) — lưu trữ toàn bộ tri thức của run (tóm tắt, liên kết artifact, bài học) vào knowledge base. Ghi kb-entry.md. Không gate.
---

# Shared — Knowledge Base

Orchestrator gọi skill này, truyền: run_dir + đường dẫn artifact bước trước. Chạy inline. KHÔNG gate.

## Việc cần làm
1. Đọc `aitoolkit-schemas`, template `kb-entry.md`, và liệt kê mọi file `.md` trong `run_dir`.
2. Tổng hợp **KB entry**: tóm tắt run (workflow gì, kết quả Go/No-Go), bảng liên kết artifact theo bước, bài học/vấn đề & cách xử lý.
3. (Tuỳ chọn) nếu có codebase-memory-mcp: gợi ý ingest artifact để truy vấn sau.
4. Ghi `<run_dir>/kb-entry.md`. Đây là bước cuối — báo pipeline hoàn tất.

## Ranh giới
- Chỉ tổng hợp & lưu; không thay đổi code hay artifact bước khác.

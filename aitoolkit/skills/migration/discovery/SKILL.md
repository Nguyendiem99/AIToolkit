---
name: discovery
description: Bước 01 migration — phân tích codebase webOS Native legacy: liệt kê feature, screen, dependency, Luna Service; đánh giá rủi ro & ước lượng. Ghi 01-discovery.md.
---

# Migration 01 — Discovery

Orchestrator gọi skill này, truyền: run_dir + đường dẫn source legacy + PRD/BRD (nếu có). Chạy inline.

## Việc cần làm
1. Đọc `aitoolkit-schemas` (front-matter) và template `aitoolkit/templates/discovery.md`.
2. Khảo sát source legacy: dùng codebase-memory-mcp nếu đã index (get_architecture, search_graph), nếu chưa thì Grep/Glob. Với webOS chú ý: file `appinfo.json`, lời gọi **Luna Service** (`luna://`), QML/Enact component, handler sự kiện.
3. Điền template:
   - **Feature list / Screen list**: từ route/QML/`appinfo.json`.
   - **Dependencies**: Luna Service, native module, package.
   - **Rủi ro & Ước lượng**: chỗ khó (native-only API, dịch vụ hệ thống), effort thô.
4. Ghi `<run_dir>/01-discovery.md` với front-matter đúng (`step_id: 01-discovery`, `status: draft`, `produced_at`).

## Ranh giới
- Chỉ PHÂN TÍCH, không thiết kế Flutter (để bước 03), không map (bước 02).
- Không đoán bừa: mục không xác định được thì ghi rõ "cần xác nhận".

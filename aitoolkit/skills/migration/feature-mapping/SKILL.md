---
name: feature-mapping
description: Bước 02 migration — ánh xạ từng thành phần webOS Native sang tương ứng Flutter, chốt scope, phân tích gap. Đọc 01-discovery.md, ghi 02-mapping.md.
---

# Migration 02 — Feature Mapping

Conductor gọi với `step_id=02-feature-mapping`, `run_id`, `run_dir`.

## Việc cần làm
1. Đọc `aitoolkit-schemas`, template `aitoolkit/templates/mapping.md`, và `<run_dir>/01-discovery.md` (bắt buộc phải có — thiếu thì báo lỗi).
2. Với mỗi feature/screen/dependency trong discovery, điền **mapping matrix**: thành phần Native → widget/pattern Flutter tương ứng (vd QML view → Flutter Widget; Luna Service call → service/repository + platform channel).
3. Chốt **scope**: cái gì migrate, cái gì tạm ngoài phạm vi.
4. **Gap analysis**: thứ không có tương ứng thẳng (native-only) → hướng xử lý.
5. Ghi `<run_dir>/02-mapping.md`, `status: draft`. Trả về đường dẫn.

## Ranh giới
- Map ở mức thành phần, CHƯA thiết kế chi tiết kiến trúc (bước 03).

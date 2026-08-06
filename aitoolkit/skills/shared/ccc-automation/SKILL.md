---
name: ccc-automation
description: Bước 08 migration (khung dùng chung, OPTIONAL) — dựng CCC checklist theo chuẩn LGE, thu thập evidence, sinh release note nháp, phân tích ảnh hưởng. Ghi 08-ccc-package.md.
---

# Shared 08 — CCC Automation

Conductor gọi với `step_id=08-ccc-automation`, `run_id`, `run_dir`. Bước nặng → subagent. OPTIONAL (tắt được qua --disable).

## Việc cần làm
1. Đọc `aitoolkit-schemas`, template `ccc-package.md`, các report `05/06/07`, và `lge-rules` (`ccc-checklist`).
2. Dựng **CCC checklist**: nếu `ccc-checklist` đã điền → theo đúng hạng mục LGE; nếu còn mốc → dùng checklist tối thiểu (review đạt, test đạt, gerrit sẵn sàng) và ghi chú "cần CCC checklist LGE".
3. **Thu thập evidence**: trỏ tới các report + kết quả test/review.
4. Sinh **release note nháp** + phân tích ảnh hưởng.
5. Ghi `<run_dir>/08-ccc-package.md`, `status: draft`. Trả về đường dẫn.

## Ranh giới
- Chỉ đóng gói CCC; quyết định release ở bước 09.

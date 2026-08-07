---
name: ccc-automation
description: Bước CCC (khung dùng chung, mọi workflow, OPTIONAL) — dựng CCC checklist theo chuẩn LGE, thu thập evidence, sinh release note nháp, phân tích ảnh hưởng. Ghi ccc-package.md.
---

# Shared — CCC Automation

Orchestrator gọi skill này, truyền: run_dir + đường dẫn artifact bước trước. Chạy inline. (bước optional — orchestrator có thể bỏ)

## Việc cần làm
1. Đọc `aitoolkit-schemas`, template `ccc-package.md`, các report `review-report.md` / `verification-report.md` / `gerrit-report.md`, và `lge-rules` (`ccc-checklist`).
2. Dựng **CCC checklist**: nếu `ccc-checklist` đã điền → theo đúng hạng mục LGE; nếu còn mốc → dùng checklist tối thiểu (review đạt, test đạt, gerrit sẵn sàng) và ghi chú "cần CCC checklist LGE".
3. **Thu thập evidence**: trỏ tới các report + kết quả test/review.
4. Sinh **release note nháp** + phân tích ảnh hưởng.
5. Ghi `<run_dir>/ccc-package.md`, `status: draft`.

## Ranh giới
- Chỉ đóng gói CCC; quyết định release ở bước Release.

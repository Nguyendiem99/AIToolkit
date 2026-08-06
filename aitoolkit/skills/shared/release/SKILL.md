---
name: release
description: Bước Release (khung dùng chung, mọi workflow, OPTIONAL) — kiểm điều kiện release, tổng hợp Go/No-Go, chốt release note. Ghi release-report.md. HARD gate PM.
---

# Shared — Release

Conductor gọi với `step_id`, `run_id`, `run_dir`. Chạy INLINE. OPTIONAL. HARD gate (PM).

## Việc cần làm
1. Đọc `aitoolkit-schemas`, template `release-report.md`, các report `review-report.md` / `verification-report.md` / `gerrit-report.md` / `ccc-package.md` (ccc có thể vắng nếu bị tắt).
2. Kiểm **điều kiện release**: review duyệt, test đạt, Gerrit merged, CCC đạt (nếu bật).
3. Tổng hợp **Go/No-Go** kèm lý do; chốt **release note**.
4. Ghi `<run_dir>/release-report.md`, `step_id` conductor truyền, `status: draft`.
5. **CHỜ HARD gate PM.** Không công bố release trước khi được duyệt.

## Ranh giới
- Nếu điều kiện chưa đạt → No-Go, nêu rõ thiếu gì; KHÔNG ép Go.

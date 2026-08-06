---
name: release
description: Bước 09 migration (khung dùng chung, OPTIONAL) — kiểm điều kiện release, tổng hợp Go/No-Go, chốt release note. Ghi 09-release-report.md. HARD gate PM.
---

# Shared 09 — Release

Conductor gọi với `step_id=09-release`, `run_id`, `run_dir`. Chạy INLINE. OPTIONAL. HARD gate (PM).

## Việc cần làm
1. Đọc `aitoolkit-schemas`, template `release-report.md`, các report `05–08` (08 có thể vắng nếu bị tắt).
2. Kiểm **điều kiện release**: review duyệt (05), test đạt (06), Gerrit merged (07), CCC đạt (08 nếu bật).
3. Tổng hợp **Go/No-Go** kèm lý do; chốt **release note**.
4. Ghi `<run_dir>/09-release-report.md`, `status: draft`.
5. **CHỜ HARD gate PM.** Không công bố release trước khi được duyệt.

## Ranh giới
- Nếu điều kiện chưa đạt → No-Go, nêu rõ thiếu gì; KHÔNG ép Go.

---
name: ccc-automation
description: Bước CCC (khung dùng chung, mọi workflow, OPTIONAL) — dựng CCC checklist theo rule dự án, thu thập evidence, sinh release note nháp, phân tích ảnh hưởng. Ghi ccc-package.md.
---

# Shared — CCC Automation

Caller/orchestrator gọi skill này, truyền: run_dir + `workflow_type` + đường dẫn artifact bước trước. Chạy inline. (bước optional — orchestrator có thể bỏ)

## Project rule resolution

1. The caller-provided `workflow_type` is authoritative for this run, including when `docs/aitoolkit/project.yaml` contains a `migration` section. Never read or override workflow type from the persistent profile; use explicit verification/release values verbatim only after classification.
2. When a profile supplies `project_pack.path`, resolve it relative to the project root and route through the index to `references/definition-of-done.md`; use `references/testing-rules.md` only for applicable evidence supplements.
3. For `workflow_type: migration`, a reviewed project pack is mandatory: require the profile, current `project_pack.reviewed_at`, pack index, and applicable `mandatory-release` rules. Missing/stale input or mandatory evidence records `Rule Resolution: BLOCKED`, adds migration `result: blocked`, and cannot be presented as release-ready.
4. For feature/bugfix without an explicit mandatory rule declaration, degrade gracefully: do not require a migration profile or project pack; keep Rule Resolution RESOLVED, use the default checklist from existing review/verification/Gerrit reports, and record degraded coverage.
5. A feature/bugfix rule becomes blocking only when a readable profile or pack explicitly declares an applicable `mandatory-release` rule. Missing explicitly mandatory evidence blocks with the existing non-migration schema.
6. Testing supplements remain optional unless explicitly promoted; never claim absent evidence was collected.

## Việc cần làm
1. Đọc `aitoolkit-schemas`, template `ccc-package.md`, các report `review-report.md` / `verification-report.md` / `gerrit-report.md`, rồi resolve profile/project pack theo `Project rule resolution`.
2. Dựng **CCC checklist** theo mandatory release rules; thêm optional evidence đã resolve và ghi rõ degraded coverage.
3. **Thu thập evidence**: trỏ tới các report + kết quả test/review.
4. Sinh **release note nháp** + phân tích ảnh hưởng.
5. Ghi `<run_dir>/ccc-package.md`, `status: draft`.

## Ranh giới
- Chỉ đóng gói CCC; quyết định release ở bước Release.

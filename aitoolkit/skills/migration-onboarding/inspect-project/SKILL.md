---
name: inspect-project
description: Use when migration onboarding must inspect legacy, target, project documents, and toolchain evidence without changing either codebase.
---

# Inspect Migration Project

Khảo sát read-only để biến source, docs và project configuration thành một inventory có reference. Không suy architecture hay command từ marker đơn lẻ.

## Ngôn ngữ artifact

Nhận `artifact_language` do orchestrator truyền. Hiện chỉ hỗ trợ `artifact_language: vi`: viết tiêu đề, tóm tắt, blocker, khuyến nghị và nội dung gate bằng tiếng Việt UTF-8; giữ nguyên mọi field machine-readable, enum, ID, path, command, log, trace field và cột bảng contract.

## Inputs

- Categorized document Evidence records from step 01, each with `Category`, `Canonical Path`, `Input Source`, `Format`, `Readability`, and `Evidence ID`.

- `<RUN_DIR>` và `<project>`.
- `<RUN_DIR>/01-onboarding-input.md` đã có `result: complete` hoặc `partial` và chứa các path đã kiểm tra.
- Legacy, target và document paths từ artifact đó.

## Evidence contract

Treat step-01 document records as source-authority data, not hints. Preserve all six fields unchanged in `Bản ghi bằng chứng tài liệu`; inspect document contents read-only and cite their Evidence IDs in findings. A record that is missing, stale, no longer readable, or whose format can no longer be opened makes the inspection `result: blocked`; never silently omit it or reconstruct it from an inbox.

Thu evidence theo bốn nhóm độc lập:

| Area | Evidence cần ghi | Không được tự suy |
|---|---|---|
| legacy | entry points, modules/features, behavior, dependencies và path cụ thể | taxonomy hoặc behavior chỉ dựa vào tên |
| target | source tree, migrated features, repeated conventions, architecture decisions và placeholder-only indicators | placeholder đồng nghĩa greenfield |
| documents | requirements, migration/UIUX/architecture decisions, owner và approval state | draft đồng nghĩa approved |
| toolchain | scripts/config, workspace boundary, candidate commands, location và evidence chạy nếu có | marker đồng nghĩa command có thẩm quyền |

Một README, empty scaffold hoặc file giữ chỗ phải được ghi là `placeholder-only`, không phải architecture baseline. Với nhiều workspace, ghi từng candidate và scope; không gộp thành một command toàn repo.

## Procedure

1. Đọc input artifact; nếu path bắt buộc không còn đọc được, ghi blocker và dừng.
2. Liệt kê evidence cùng location ổn định (path, section, config key hoặc command record).
3. Tách finding, inference và unknown. Inference chưa có nguồn xác nhận luôn đi vào Unknowns.
4. Đánh dấu command là authoritative chỉ khi profile explicit hoặc project script/config xác định rõ scope; marker detection chỉ tạo candidate.
5. Nếu evidence không đủ cho step phân loại an toàn, dùng `result: partial` khi step 03 vẫn có thể đề xuất `unknown`, hoặc `result: blocked` khi thiếu chính input cần khảo sát.

## Output contract

Inspection must not move, rename, rewrite, or modify any source document or any file under legacy/target roots. Reading, decoding, hashing, and listing are allowed only when they do not mutate source bytes or metadata.

Onboarding không sinh production code.

Ghi duy nhất `<RUN_DIR>/02-project-inspection.md` theo `templates/migration/project-inspection.md`, gồm Inspection Results, Evidence, Unknowns và Verdict. Không sửa file dưới legacy/target và không tạo project profile ở step này.

## Common mistakes

- Đếm số file thay vì đánh giá architecture/feature có evidence.
- Chọn command gần root nhất dù workspace scope mơ hồ.
- Biến phỏng đoán thành fact để đáp ứng deadline.

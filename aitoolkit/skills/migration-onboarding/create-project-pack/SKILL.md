---
name: create-project-pack
description: Use when an approved migration mode proposal must become a version-controlled project profile and evidence-backed migration reference pack.
---

# Create Migration Project Pack

Tạo hoặc cập nhật profile và reference pack dưới `docs/aitoolkit/`. Đây là tài liệu dự án để migration core đọc, không phải generator source hay scaffold target.

## Ngôn ngữ artifact

Nhận `artifact_language` do orchestrator truyền. Hiện chỉ hỗ trợ `artifact_language: vi`: viết tiêu đề, tóm tắt, blocker, khuyến nghị và nội dung gate bằng tiếng Việt UTF-8; giữ nguyên mọi field machine-readable, enum, ID, path, command, log, trace field và cột bảng contract.

## Inputs

- `Immediate predecessor artifact = exactly one orchestrator-provided path`.
- `<RUN_DIR>`, `<project>` và immediate predecessor `<RUN_DIR>/03-mode-proposal.md` có `status: approved`, `result: complete | partial`.
- Profile/pack hiện có nếu đây là update.

Read all inspection evidence references and command authority/source/scope/blocker data from that one step 03 predecessor. Do not load step 02 directly. Mode/policy chưa approved, command blocker chưa giải quyết hoặc forwarded evidence reference không còn đọc được làm output review có `result: blocked`; không nạp older artifact để lấp chỗ trống.

## Procedure

1. Khởi tạo staged profile từ `templates/migration/project-profile.yaml`; chỉ điền field có evidence. Giữ `unknown`/`null` cho field chưa xác định và ghi blocker nếu downstream bắt buộc field đó. Không thêm top-level `change_type`; workflow hiện tại do orchestrator truyền theo từng run, còn `migration` chỉ là namespace cấu hình project.
2. Áp invariant `greenfield => design-new`, `incremental => preserve-existing`; copy command đã xác nhận nguyên văn và đúng workspace scope.
3. Tạo/cập nhật bảy reference file. Mỗi rule quan trọng phải có source/evidence; conflict hoặc unknown có owner và trạng thái.
4. Tạo index ngắn chỉ route consumer tới reference phù hợp.
5. Nếu cập nhật pack, diff rule/profile, liệt kê run/artifact cũ có thể cần review; không tự sửa hoặc invalidate chúng.
6. Record deterministic content revisions for the staged profile (excluding review metadata), every pack file, and cited source/target/document evidence in `Độ mới của review`.
7. Ghi toàn bộ draft dưới `<RUN_DIR>/project-draft/` và review artifact ở `status: draft`; để `project_pack.reviewed_at: null` và `project_pack.review_evidence: null` cho tới HARD gate của orchestrator.

## Project profile document contract

Read document Evidence records only from the approved `<RUN_DIR>/03-mode-proposal.md`. In staged `project.yaml`, `documents` contains exactly the four categorized lists `requirements`, `uiux`, `migration`, and `architecture`. Each non-empty list entry contains exactly `path`, `input_source`, `format`, `readability`, and `evidence_id`, with no missing or extra keys: copy `path` from `Canonical Path`, `input_source` from `Input Source` (`explicit` or `inbox`), and the remaining values from `Format`, `Readability`, and `Evidence ID`. Do not collapse entries to unqualified strings or lose source authority.

Copy the same six-field records into the review artifact's `Bằng chứng tài liệu profile` table so the Tech Lead can compare the generated profile to the single predecessor. Missing fields, duplicate Evidence IDs, a non-readable record, or a staged profile/review mismatch makes `04-project-pack-review.md` `result: blocked`. Do not read step 01/02, rescan inbox directories, or replace forwarded authority with a guess.

## Pack index contract

`migration-project/SKILL.md` là route-only index: ánh xạ nhu cầu của migration/shared skills tới file dưới `references/`; index không chứa project knowledge, command hay rule chi tiết. Consumer đọc path trong `project.yaml`, không dựa vào runtime auto-discovery.

Không tạo `scripts/` mặc định. Chỉ một yêu cầu dự án riêng, đã được duyệt, mới có thể bổ sung automation ngoài onboarding này.

## Staging contract

Step này ghi complete candidate set dưới `<RUN_DIR>/project-draft/` và must not modify canonical `docs/aitoolkit/project.yaml` hoặc `docs/aitoolkit/migration-project/`. Review report trỏ tới staged files để Tech Lead xem diff/evidence. Chỉ orchestrator HARD gate được publish canonical outputs sau explicit approval; từ chối hoặc sửa không ảnh hưởng canonical pack đang dùng.

## Output contract

Onboarding không sinh production code.

Trước gate, tạo staged outputs:

- `<RUN_DIR>/project-draft/project.yaml`
- `<RUN_DIR>/project-draft/migration-project/SKILL.md` và bảy reference tương ứng dưới `references/`
- `<RUN_DIR>/04-project-pack-review.md` theo `templates/migration/project-pack-review.md`

Every newly staged profile preserves the template defaults `automation.mode: interactive` and `output.artifact_language: vi`; staging must not modify source documents. Existing evidence may populate other staged fields, but source documents remain byte-for-byte unchanged.

Sau HARD approval, orchestrator publish đúng final outputs sau:

- `<project>/docs/aitoolkit/project.yaml`
- `<project>/docs/aitoolkit/migration-project/SKILL.md`
- `<project>/docs/aitoolkit/migration-project/references/legacy-system.md`
- `<project>/docs/aitoolkit/migration-project/references/target-baseline.md`
- `<project>/docs/aitoolkit/migration-project/references/architecture-rules.md`
- `<project>/docs/aitoolkit/migration-project/references/mapping-rules.md`
- `<project>/docs/aitoolkit/migration-project/references/uiux-rules.md`
- `<project>/docs/aitoolkit/migration-project/references/testing-rules.md`
- `<project>/docs/aitoolkit/migration-project/references/definition-of-done.md`

At the HARD gate, set the canonical profile's `reviewed_at` to the RFC 3339 approval time and `review_evidence` to the approved `<RUN_DIR>/04-project-pack-review.md`. Its `Độ mới của review` table preserves the content revisions published by the gate; any changed staged byte requires renewed review.

Không sửa file ngoài staged paths trước gate hoặc canonical paths trong gate action. Review report liệt kê file tạo/sửa, evidence coverage, Unknowns, rule delta, affected historical runs và Tech Lead decision.

## Common mistakes

- Nhét toàn bộ knowledge vào index thay vì route reference.
- Điền command từ marker hoặc README chưa xác nhận.
- Đánh dấu `reviewed_at` trước HARD gate.

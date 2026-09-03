---
name: knowledge-base
description: Bước Knowledge Base (khung dùng chung, mọi workflow) — lưu trữ toàn bộ tri thức của run (tóm tắt, liên kết artifact, bài học) vào knowledge base. Ghi kb-entry.md. Không gate.
---

# Shared — Knowledge Base

Orchestrator gọi skill này, truyền: `RUN_DIR` + authoritative `workflow_type` + `knowledge_step_id` + đường dẫn terminal artifact do orchestrator cung cấp. `knowledge_step_id` là `15-knowledge-base` cho migration và `09-knowledge-base` cho feature/bugfix. Chạy inline. KHÔNG gate.

`Terminal input artifact = exactly one orchestrator-provided path`.

## Ngôn ngữ artifact

Nhận `artifact_language` do orchestrator truyền khi `workflow_type: migration`. Hiện chỉ hỗ trợ `artifact_language: vi`: viết tiêu đề, tóm tắt, blocker, khuyến nghị và nội dung gate bằng tiếng Việt UTF-8; giữ nguyên mọi field machine-readable, enum, ID, path, command, log, trace field và cột bảng contract. Feature/bugfix giữ contract hiện có.

## Workflow-aware terminal verdict

For migration, an executable step-15 Knowledge Base artifact uses the exact canonical front matter keys and lifecycle `status: approved`, `result: complete`, `approval_source: human`. Draft, blocked, partial, automatic, duplicate-key, extra-key, or cross-run output is not terminal authority.

- Validate `workflow_type: feature | bugfix | migration` and render it verbatim into the template; never infer it from persistent profile configuration.
- Migration greenfield yêu cầu terminal input `13-parity-report.md`; migration incremental yêu cầu `14-regression-report.md`. Copy identity của đơn vị được chọn và kết luận parity/regression thực tế vào `Xác minh đầu cuối`, chuẩn hóa terminal verdict thực sự đạt thành `Verification Verdict: PASS`. Chỉ đặt `Completion Verdict: complete` khi không có automation waiver, terminal artifact đã resolve nằm trong `RUN_DIR` này, có `status: approved`, `result: complete` và workflow verdict là pass; incremental còn yêu cầu parity evidence cùng run đã duyệt với result complete và verdict pass. Waiver hợp lệ tuân theo partial policy bên dưới. Mọi artifact draft, partial, failed, blocked, mismatched, missing hoặc cross-run khác làm Completion Verdict thành `blocked`.
- Migration chỉ có thể đặt `Completion Verdict: complete` khi terminal input có đúng một `Architecture Responsibility Handoff` table, table này PASS theo phép hội của ba sub-verdict và giữ nguyên ordinal version/sub-verdict/evidence từ immediate predecessor. `Evidence References` remains the exact immutable `source-diff:<task-base>..<final-tree>#<WORK-*>` originated by AI Review; the KB artifact itself is the separate final responsibility-chain artifact referenced later by `Terminal Chain Reference` and the terminal Evidence Index. Missing, stale/cross-run, unsupported/mixed version, mutated source-diff evidence, hoặc bất kỳ sub-verdict `BLOCKED` nào đều làm Completion Verdict `blocked`. Runtime/`auto-waive` chỉ thay runtime state, không được thay responsibility table.
- Feature and bugfix resolve their `verification-report.md` within the same `RUN_DIR` and record its actual verification verdict. Set Completion Verdict `complete` only when every non-skipped required workflow artifact is present/approved and the orchestrator-provided latest executed terminal artifact records success; use `partial` when nonblocking work remains and `blocked` for missing/failed required evidence. They do not require migration envelopes even when the project profile contains a `migration` section.
- Record Release Verdict `Go` or `No-Go` only when a real `release-report.md` exists in this run. If release was skipped or is outside the workflow, record `not-run`; do not reuse a generic Go/No-Go as the run completion verdict.
- Mọi `Artifact Path` và `Terminal Verification Artifact` phải được canonicalize và nằm trong `RUN_DIR`. Ghi path tương đối với `RUN_DIR` để delivery skill độc lập về sau resolve đúng bằng chứng mà không cần implicit handoff.

## Migration automation waivers

For `workflow_type: migration`, scan every artifact in `RUN_DIR` and list every canonical waiver in `Automation waiver`. Validate exactly five waiver fields (`policy`, `category`, `original_verdict`, `effective_action`, `evidence`) plus the required top-level `status: approved`, `result: partial`, and `approval_source: auto-waive`; missing evidence or any other pairing is invalid and blocks completion.

Keep each unavailable check as `NOT_RUN + WAIVED` with its verbatim evidence. If the terminal check itself is waived, record `Verification Verdict: WAIVED`; never normalize that check to `PASS`. When at least one valid automation waiver exists and no waiver-ineligible failure or invalid artifact exists, record `Completion Verdict: partial`, never `complete`, even if a later non-waived terminal check passed. A real `FAIL`, new parity/regression failure, or remaining native `BLOCKED` stays failed/blocked and cannot be hidden by a waiver.

This aggregation is migration-only; feature and bugfix behavior is unchanged and those workflows do not acquire automation-waiver requirements from a migration profile.

## Migration foundation update proposal

For a migration run, inspect the bootstrap, implementation artifact, and terminal artifact for a newly approved foundation baseline. When present, append a `project-pack update proposal` to `kb-entry.md` for `target-baseline.md` with the exact `foundation_baseline_id`, Source Migration Unit ID, target baseline reference, Foundation Baseline Approval Reference, approval status, design revision, freshness evidence, and changed-path evidence. The ID and references must match across the implementation artifact and terminal artifact; report any mismatch as an unresolved proposal blocker rather than inventing a value.

This output is a proposal only. Knowledge Capture never edits the canonical project pack or `target-baseline.md`; applying the proposal requires the normal project-pack review gate. If the run did not create a foundation baseline, record `not-applicable` and do not manufacture a proposal.

## Scope-aware migration capture

For migration, record the work-item verdict, exact master-plan transition, required items remaining, next eligible item or blocker, and calculated scope status from the approved master plan. Calculate scope status with the canonical Scope-completion formula. Never infer `scope-complete` from one execution artifact, one completed work item, or a successful attempt. A completed work item with any required item remaining is `scope-in-progress`.

Đối chiếu transition với đúng `Master Plan Reference` và `Master Plan Revision`; giữ terminal evidence của work item tách biệt với verdict của requested scope. Nếu không có item eligible nhưng còn required blocker, ghi `scope-blocked` cùng blocker/evidence. Chỉ ghi `scope-complete` khi master plan chứng minh toàn bộ điều kiện của công thức canonical, không dựa vào riêng terminal input artifact của lần chạy hiện tại.

Concrete `scope-complete` requires: `Required Items Remaining = none`; `Next Eligible Item = none`; `Blocker = none`; `Dependency Graph State = valid`; `Required Items Terminal-success = all-terminal-success`; `Architecture Conformance State = PASS`; `Selector Schema State = PASS`; và `Terminal Scope Report` trỏ tới `scope-terminal-report.md#<evidence-index>` đã liệt kê đầy đủ evidence. `Calculation Evidence` phải chứa marker `all-required-terminal-evidence`. Thiếu một điều kiện phải reject phép tính complete. Khi work-item verdict là `complete`, còn required item và không có blocker, `Calculated Scope Status` bắt buộc là `scope-in-progress`.

## Việc cần làm
1. Đọc `aitoolkit-schemas`, template `kb-entry.md`, terminal input artifact, và scan all `.md` artifacts in `RUN_DIR`.
2. Tổng hợp **KB entry**: copy orchestrator-provided workflow/step ID, workflow-appropriate terminal verification, completion verdict, mọi migration automation waiver, bảng liên kết artifact theo bước, và bài học/vấn đề & cách xử lý. Với migration, bắt buộc ghi work-item verdict, master-plan transition và phép tính scope theo `Scope-aware migration capture`.
3. (Tuỳ chọn) nếu có codebase-memory-mcp: gợi ý ingest artifact để truy vấn sau.
4. Ghi `<run_dir>/kb-entry.md`. Với migration, preserve nguyên văn và theo đúng thứ tự canonical từ terminal verification artifact: `Master Scope Context`, đúng một `Delivery Adapter Kind`, đúng một `Delivery Adapter Mode Constraint`, `Task Provenance`, conditional `Selected Migration Unit`, rồi đúng một `Architecture Responsibility Handoff` v1. Greenfield nhận trực tiếp step 13 và giữ mode `greenfield/design-new`; incremental nhận step 14 và giữ mode `incremental/preserve-existing`. `Selected Migration Unit` bắt buộc chỉ cho adapter `migration-unit` và phải bị omit cho mọi generic adapter; `Task / Unit` là selected unit ID cho `migration-unit`, còn generic adapter dùng Work Item ID. Missing, reordered, mutated, cross-run, cross-scope, wrong-adapter hoặc mismatched provenance blocks completion. Đây là bước cuối của execution attempt; chỉ báo requested scope hoàn tất khi `Calculated Scope Status` là `scope-complete` theo master plan.
5. Với migration, copy exactly one `Architecture Responsibility Handoff` table từ terminal input artifact; không hoàn tất KB nếu table/evidence không preserve exact review-originated source-diff trong cùng run. Resolve terminal-chain authority separately from the completed KB artifact; never place that artifact reference in the immutable handoff cell. Không tái tạo handoff từ prose hay kết quả tổng hợp KB.

## Ranh giới
- Chỉ tổng hợp & lưu; không thay đổi code hay artifact bước khác.

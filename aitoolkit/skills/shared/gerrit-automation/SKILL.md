---
name: gerrit-automation
description: Bước Gerrit (khung dùng chung, mọi workflow) — tạo commit message + change description theo quy ước dự án, chuẩn bị upload Gerrit. Đọc verification-report.md, ghi gerrit-report.md. Upload chỉ sau HARD gate.
---

# Shared — Gerrit Automation

Caller có thể gọi skill này độc lập hoặc qua feature/bugfix orchestrator. Luôn truyền `workflow_type`; bước này có HARD gate (không đảo ngược khi upload). Read `shared/change-hygiene.md` before branch preparation; its task boundary, diff scope, task-local consolidation, and non-waivable integrity rules apply to every workflow.

## Project rule resolution

1. The caller-provided `workflow_type` is authoritative for this run, including when `docs/aitoolkit/project.yaml` contains a `migration` section. Never read or override workflow type from the persistent profile; use explicit branch/review values only after classification. A missing profile does not turn feature/bugfix into migration.
2. When a profile supplies `project_pack.path`, resolve it relative to the project root and route through its index to `references/definition-of-done.md` and `references/testing-rules.md`; read `references/architecture-rules.md` for applicable integration and convention rules.
3. For `workflow_type: migration`, a reviewed project pack is mandatory: require the profile, current `project_pack.reviewed_at`, pack index, and applicable `mandatory-release` rules. Missing/stale input or mandatory evidence records `Rule Resolution: BLOCKED`, adds migration `result: blocked`, keeps upload pending, and stops before the HARD gate.
4. For feature/bugfix without an explicit mandatory rule declaration, degrade gracefully: do not require a migration profile or project pack; keep Rule Resolution RESOLVED with the gap recorded and use Conventional Commits for the draft.
5. A feature/bugfix rule becomes blocking only when a readable profile or pack explicitly declares an applicable `mandatory-release` rule. Missing explicitly mandatory evidence blocks with the existing non-migration schema.
6. Architecture/convention supplements are optional unless explicitly promoted; never describe the fallback as a project convention.

## Standalone migration invocation

Migration delivery starts only from an explicit completed run and never requires an implicit migration-orchestrator handoff.

1. Require authoritative `workflow_type: migration` plus either an explicit completed `RUN_DIR`, an explicit terminal `kb-entry.md` path, or both. When only `kb-entry.md` is supplied, derive `RUN_DIR` from its parent. When both are supplied, canonicalize them and require the KB entry to be inside that same run directory; reject traversal, cross-run links, missing paths, or ambiguous candidates.
2. Read the terminal KB artifact and require `step_id: 15-knowledge-base`, `Workflow Type: migration`, exactly `Completion Verdict: complete` (reject `partial` and `blocked`), and exactly one Terminal Verification row. This proves Knowledge Capture completed the run; do not accept a parity/regression artifact as a substitute entry point.
3. Require the KB Terminal Verification row to record `Verification Verdict: PASS`. Resolve its Terminal Verification Artifact link, canonicalize it, and require it to remain within the resolved `RUN_DIR` with `status: approved`, `result: complete`, and a passing workflow verdict. Greenfield / `design-new` resolves `13-parity-report.md` and must not resolve or execute step 14. Incremental / `preserve-existing` resolves `14-regression-report.md` and must link same-run approved parity evidence; both regression and parity evidence must have complete results and pass verdicts.
4. Resolve the approved master plan and the complete ordered assurance chain before validating Gerrit: review -> verification -> parity -> regression -> Knowledge Base for incremental mode, or review -> verification -> parity -> Knowledge Base for greenfield mode. Run the same canonical responsibility-handoff gate on every edge; a KB/Gerrit equality comparison is never sufficient authority, and the public Gerrit gate must fail closed when any ordered predecessor is absent.
5. Validate workflow/mode consistency and the KB's exact adapter-aware envelope, including one exact `Delivery Adapter Mode Constraint` preserved from the approved plan through every assurance edge. For `Delivery Adapter Kind = migration-unit`, require exactly one `Selected Migration Unit`, require the same `migration_unit_id` across the approved plan and the resolved assurance chain, validate its canonical ID, unversioned-authority-plus-positive-revision Plan Reference, resolved approval, exact mode/bootstrap/foundation/baseline state, and trace IDs against the approved plan, then preserve all ten fields ordinally through review, verification, parity, optional regression, KB, and Gerrit. For `task | story | package | phase | milestone | none`, require zero `Selected Migration Unit` sections and use `Master Scope Context.Work Item ID` as the delivery identity; never invent `UNIT-*`. Also validate parity verdict, regression applicability/verdict, immutable source-diff handoff evidence, and exact Master Scope/Task Provenance. Draft, partial, failed, blocked, cross-run, wrong-cardinality, or mismatched evidence yields `result: blocked` before branch preparation or the HARD gate.
6. Preserve `Master Scope Context`, exact `Delivery Adapter Kind`, exact `Delivery Adapter Mode Constraint`, `Task Provenance`, conditional `Selected Migration Unit`, and `Architecture Responsibility Handoff` ordinally in `gerrit-report.md`; never reconstruct them from source, a fixed filename outside the KB link, or an implicit orchestrator predecessor.

## Feature and bugfix invocation

For feature/bugfix, retain existing behavior: the orchestrator provides `workflow_type` and the verification predecessor; read `<RUN_DIR>/verification-report.md`, require its normal verdict, and do not require migration-only sections or a migration project pack unless an applicable rule explicitly makes it mandatory.

## Branch and commit integrity

Resolve integration values from the reviewed project pack; never invent an upstream branch or command. When a mandatory rule declares upstream synchronization, perform its ancestry-preserving operation before consolidation and verification. Reject snapshot-copy or squash-copy synchronization.

Require task-base SHA and final-tree SHA provenance forwarded through the explicit verification predecessor; never discover or hard-code an implementation artifact path. Validate the lineage against review and verification evidence. Preserve task-base for scope review. For delivery commit counting, use the verified post-rebase upstream tip as delivery base when an integration upstream applies; otherwise use task-base. Compute the actual task commit count from delivery base to final commit SHA, record that observed value, and require exactly `1`; never prefill or assume the count. `Branch and Commit Integrity.Task / Unit ID` is the selected migration-unit ID only for `migration-unit`; every generic adapter uses the canonical Work Item ID. Task-local checkpoint commits may be consolidated into one final task commit without changing the verified tree. Reject mixed task/unit scope.

When project rules require upstream integration, also record upstream ref, upstream SHA and merge-base SHA. Resolve applicable `references/testing-rules.md` commands and require fresh command, output, exit-status, and upstream-SHA evidence after integration. Before the HARD gate, record final commit SHA, task/unit ID, diff-scope verdict, formatter evidence, and post-integration verification. A stale merge base, failed verification, multiple final task commits, unrelated diff, or missing/mismatched task provenance is blocked and not waiver-eligible.

## Việc cần làm
1. Đọc `aitoolkit-schemas`, template `gerrit-report.md`, then apply the invocation contract above: standalone migration resolves the terminal KB link from its explicit completed run; feature/bugfix reads `<RUN_DIR>/verification-report.md`. Resolve project rules only after applying authoritative `workflow_type`.
2. Chuẩn bị nhánh: dùng superpowers:finishing-a-development-branch để đảm bảo nhánh sạch, test xanh.
3. Soạn **commit message** + **change description** theo mandatory release/Gerrit rule đã resolve; chỉ dùng fallback đã ghi rõ khi optional convention thiếu.
4. Ghi `<run_dir>/gerrit-report.md` với trạng thái "chưa upload"; migration preserves the canonical envelope and `Migration Verification Verdicts`, keeping `Selected Migration Unit` only for adapter `migration-unit` and omitting it for every generic adapter.
5. **CHỜ orchestrator qua HARD gate** (Reviewer xác nhận). CHỈ SAU khi được duyệt mới thực hiện upload Gerrit (push refs/for/...), rồi cập nhật report + Change-Id.

## Ranh giới
- TUYỆT ĐỐI không upload trước khi HARD gate được duyệt.
- Không tự merge trên Gerrit (người/CI quyết).

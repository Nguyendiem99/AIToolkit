---
step_id: <orchestrator-provided-step-id>
status: draft
result: <complete | partial | blocked>
# Chỉ migration: thêm `result: complete | partial | blocked`
approval_source: <human | auto | auto-waive>
produced_at: <yyyy-mm-dd>
responsibility_contract:
  version: 1
  applicability: required
---

Migration terminal authority is executable only with exactly `status: approved`, `result: complete`, and `approval_source: human`; draft, blocked, partial, or automatic output cannot complete the chain.

<!-- artifact_language: vi -->

# Mục Knowledge Base — <tên mô-đun>

## Master Scope Context

| Run ID | Master Spec Reference | Master Spec ID | Master Spec Revision | Master Plan Reference | Master Plan ID | Master Plan Revision | Work Item ID |
|---|---|---|---|---|---|---|---|
| <RUN-*> | <master spec reference> | <SPEC-*> | <revision> | <master plan reference> | <PLAN-*> | <revision> | <WORK-*> |

- Delivery Adapter Kind: <migration-unit | task | story | package | phase | milestone | none>
- Delivery Adapter Mode Constraint: <incremental/preserve-existing | greenfield/design-new>

## Task Provenance

| Task / Unit | Task-base SHA | Final-tree SHA | Source Artifact |
|---|---|---|---|
| <task or UNIT-###> | <sha> | <sha> | <terminal verification artifact> |

Resolve `Task / Unit` only from approved adapter authority: selected Migration Unit ID for `migration-unit`, current Work Item ID for every generic adapter.

Keep `Selected Migration Unit` only when `Delivery Adapter Kind` is `migration-unit`; otherwise omit it.

## Selected Migration Unit

`Plan Reference`: `<selector authority>@<positive authority revision>` (exact canonical composite).

| Migration Unit ID | Plan Reference | Approval Reference | Mode Constraint | Bootstrap Scope | Foundation Baseline ID | Foundation Baseline Reference | Foundation Baseline Approval Reference | Baseline Reference | Trace IDs |
|---|---|---|---|---|---|---|---|---|---|
| <UNIT-001> | <tham chiếu plan> | <tham chiếu duyệt đơn vị> | <ràng buộc mode/policy> | <required hoặc not-required> | <FOUNDATION-001 hoặc not-applicable> | <tham chiếu target-baseline đã duyệt hoặc not-applicable> | <tham chiếu duyệt hoặc not-applicable> | <tham chiếu bằng chứng hồi quy hoặc not-applicable> | <trace IDs> |

## Architecture Responsibility Handoff

Chép nguyên văn đúng một bảng từ terminal verification artifact được orchestrator truyền. Chỉ completion khi bảng PASS và `Evidence References` remains the review-originated source-diff, preserved ordinally from the immediate predecessor in the same run; runtime waiver không được đổi bảng này. The final Knowledge Base artifact is separate terminal-chain authority and never replaces this handoff cell.

| Responsibility Contract Version | Tree Conformance | Responsibility Conformance | Verification Ownership | Architecture Conformance State | Evidence References |
|---|---|---|---|---|---|
| 1 | PASS | PASS | PASS | PASS | source-diff:<task-base SHA>..<final-tree SHA>#<WORK-*> |

## Tóm tắt run
- Workflow Type: <orchestrator-provided-workflow-type>
- Terminal Input Artifact: <path do orchestrator cung cấp trong RUN_DIR>
- Completion Verdict: <complete / partial / blocked, sao chép từ bằng chứng run được dẫn>
- Release Verdict: <Go / No-Go chỉ khi có release artifact; nếu không thì not-run>

## Xác minh đầu cuối

| Workflow Type | Mode | Migration Unit ID | Terminal Verification Artifact | Verification Verdict | Completion Verdict |
|---|---|---|---|---|---|
| <orchestrator-provided-workflow-type> | <greenfield / incremental / not-applicable> | <UNIT-* / not-applicable> | <path đã xác minh tương đối với RUN_DIR> | <PASS / FAIL / BLOCKED / WAIVED / not-applicable> | <complete / partial / blocked> |

## Work Item and Master Plan Transition

| Work Item ID | Work Item Verdict | Master Plan Reference | Master Plan Revision | Transition | Terminal Evidence |
|---|---|---|---|---|---|
| <WORK-*> | <complete / blocked / cancelled-approved / not-applicable-approved> | <master-plan path> | <revision> | <prior state -> new state> | <artifact tương đối với RUN_DIR> |

## Scope Status Calculation

| Required Items Remaining | Next Eligible Item | Blocker | Dependency Graph State | Required Items Terminal-success | Architecture Conformance State | Selector Schema State | Terminal Scope Report | Calculated Scope Status | Calculation Evidence |
|---|---|---|---|---|---|---|---|---|---|
| <count và Work Item IDs hoặc none> | <WORK-* hoặc none> | <blocker/evidence hoặc none> | <valid / invalid> | <all-terminal-success / remaining> | <PASS / BLOCKED> | <PASS / BLOCKED> | <scope-terminal-report.md#evidence-index hoặc not-applicable> | <planned / scope-in-progress / scope-blocked / scope-complete / scope-cancelled-approved> | <master-plan revision + terminal evidence set; scope-complete cần all-required-terminal-evidence> |

## Automation waiver

<!-- Chỉ giữ section này khi caller-provided workflow_type=migration; feature/bugfix bỏ section. -->
Chỉ migration: liệt kê mọi waiver hợp lệ. Giữ nguyên `NOT_RUN + WAIVED` và bằng chứng verbatim; không bao giờ đổi nhãn thành `PASS` hoặc biến run thành `complete`. Ghi `not-applicable` nếu migration run không có waiver.

| Artifact | Stage / Check | Outcome | Category | Original Verdict | Evidence |
|---|---|---|---|---|---|
| <artifact tương đối với RUN_DIR hoặc not-applicable> | <stage/check hoặc not-applicable> | <`NOT_RUN + WAIVED` hoặc not-applicable> | <`environment-unavailable` hoặc not-applicable> | <`blocked` hoặc not-applicable> | <tham chiếu bằng chứng verbatim hoặc not-applicable> |

## Liên kết artifact

| Step ID | Artifact Path | Status | Result / Verdict |
|---|---|---|---|
| <step id> | <path tương đối với RUN_DIR> | <draft / approved> | <complete / partial / blocked / verdict> |

## Bài học và cách xử lý

| Issue / Lesson | Resolution |
|---|---|

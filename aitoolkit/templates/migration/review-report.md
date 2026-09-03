---
step_id: 11-ai-review
status: <draft | approved>
result: <complete | blocked>
# Chỉ migration: thêm `result: complete | blocked`
approval_source: <human | auto | auto-waive>
produced_at: <yyyy-mm-dd>
responsibility_contract:
  version: 1
  applicability: required
---

<!-- artifact_language: vi -->

Draft output removes the `approval_source` line. Approved output renders exactly one canonical value; the executable terminal chain requires `approval_source: human`.

# Báo cáo AI Review — <tên module>

## Master Scope Context

| Run ID | Master Spec Reference | Master Spec ID | Master Spec Revision | Master Plan Reference | Master Plan ID | Master Plan Revision | Work Item ID |
|---|---|---|---|---|---|---|---|
| <RUN-*> | <master spec reference> | <SPEC-*> | <revision> | <master plan reference> | <PLAN-*> | <revision> | <WORK-*> |

- Delivery Adapter Kind: <migration-unit | task | story | package | phase | milestone | none>
- Delivery Adapter Mode Constraint: <incremental/preserve-existing | greenfield/design-new>

## Task Provenance

| Task / Unit | Task-base SHA | Final-tree SHA | Source Artifact |
|---|---|---|---|
| <UNIT-* for migration-unit; WORK-* otherwise> | <task-base SHA> | <final-tree SHA> | <immediate predecessor artifact path> |

Resolve `Task / Unit` only from approved adapter authority: selected Migration Unit ID for `migration-unit`, current Work Item ID for every generic adapter.

Keep `Selected Migration Unit` only when `Delivery Adapter Kind` is `migration-unit`; otherwise omit it.

## Selected Migration Unit

`Plan Reference`: `<selector authority>@<positive authority revision>` (exact canonical composite).

| Migration Unit ID | Plan Reference | Approval Reference | Mode Constraint | Bootstrap Scope | Foundation Baseline ID | Foundation Baseline Reference | Foundation Baseline Approval Reference | Baseline Reference | Trace IDs |
|---|---|---|---|---|---|---|---|---|---|
| <UNIT-001> | <tham chiếu plan> | <tham chiếu duyệt đơn vị> | <ràng buộc mode/policy> | <required hoặc not-required> | <FOUNDATION-001 hoặc not-applicable> | <tham chiếu target-baseline đã duyệt hoặc not-applicable> | <tham chiếu duyệt hoặc not-applicable> | <tham chiếu bằng chứng hồi quy hoặc not-applicable> | <trace IDs> |

## Tổng quan
- Phạm vi review (SHA): `<BASE>..<HEAD>`
- Project rules áp dụng: <path profile/pack + rule bắt buộc + khoảng trống tùy chọn/độ phủ suy giảm>

## Rule Resolution
- Rule Resolution Verdict: <RESOLVED | BLOCKED>
- **Mandatory rule gaps:** <không có hoặc khoảng trống blocking chính xác>
- **Optional gaps/degraded coverage:** <không có hoặc độ phủ suy giảm đã ghi nhận>

## Canonical Selector

- Canonical Selector Verdict: <PASS | BLOCKED>
- Evidence: <adapter kind, canonical selector/authority, work-item binding và approval evidence>

## Architecture Conformance

- Architecture Conformance Verdict: <PASS | BLOCKED>
- Conformance Matrix Reference: <tham chiếu matrix đã duyệt>
- Exemplars: <path/symbol exemplar đã đọc>
- Actual File Tree vs Planned File Tree: <đối chiếu path/symbol và drift>
- Approved Structural Deviations: <decision/approval hoặc not-applicable>

## Responsibility Review Evidence

- Tree Conformance Verdict: <PASS | BLOCKED>
- Responsibility Conformance Verdict: <PASS | BLOCKED>
- Verification Ownership Verdict: <PASS | BLOCKED>
- Reviewer inspects the task-base/final-tree diff independently; implementation self-attestation is not semantic PASS evidence.
- Derive every pinned `M/A/R/C/D` changed Git path and reconcile it one-to-one to exactly one implementation `Change Hygiene` row (`A/C = new`, `M/R = existing`, `D = deleted`). Normalize `\` to `/` once before all design/review/Git/hygiene/source comparisons and reject aliases or traversal segments. Apply the canonical production-root classifier independently of responsibility markers; parse owners only for production-classified or explicitly selected authority paths. Markerless executable content beside a valid owner block, omitted/duplicate/surplus rows, and stale/foreign/status-mismatched evidence are `BLOCKED`, while irrelevant docs are not promoted by incidental markers.
- Compare pinned base and final contents for every surviving `M/R` path. A responsibility block removed from a surviving file enters the same approved deletion reconciliation as a deleted file, but uses `File Kind = existing` plus exact task-base source/removal-diff evidence.
- Require exact task-base source/removal-diff checkpoint evidence for every deleted Git path, even without an owner. For every base-only deleted responsibility, require one approved design removal decision naming the complete deleted ownership/effect inventory, one implementation `Change Hygiene` row with `File Kind = deleted`, and one row below whose immutable evidence uses the task-base source and removal diff. A rename is production when either old or new path is production and uses explicit `<old path>-><new path>` diff mapping while source evidence resolves the old path. Use exact `removed` for both Actual columns; an absent or partial approval is `BLOCKED`.

| Responsibility ID | Source/Diff Evidence | Planned Public Symbols | Actual Public Symbols | Planned Effects | Actual Effects | Verdict |
|---|---|---|---|---|---|---|

## Verification Ownership Source Evidence

Resolve every row independently from the pinned final-tree `Evidence Path` and named scenario. Bind its verification owner, production responsibility, capability, evidence kind, disposition, production path/symbol, and—when `production-composition`—the exact production route/provider. An unchanged evidence file uses final-tree source evidence and must not invent a diff anchor.

| Verification Owner ID | Final-tree Evidence Path | Scenario | Production Responsibility ID | Capability ID | Evidence Kind | Verification Disposition | Production Binding | Production Route / Provider | Verdict |
|---|---|---|---|---|---|---|---|---|---|

## Architecture Responsibility Handoff

Chỉ phát hành hàng `PASS` sau khi reviewer đã kiểm tra độc lập final inventory và diff `task-base..final-tree`. `Architecture Conformance State` là phép hội suy diễn của ba sub-verdict, không phải caller assertion. `Evidence References` bind chính xác cặp SHA trong `Task Provenance` và work item hiện tại.

| Responsibility Contract Version | Tree Conformance | Responsibility Conformance | Verification Ownership | Architecture Conformance State | Evidence References |
|---|---|---|---|---|---|
| 1 | <tree verdict> | <responsibility verdict> | <verification verdict> | <derived architecture state> | source-diff:<task-base SHA>..<final-tree SHA>#<WORK-*> |

## Production Activation Path

- Production Activation-path Verdict: <PASS | BLOCKED | NOT_APPLICABLE>
- Production Activation Path Evidence: <production route/render/registration evidence hoặc not-applicable>
- Production Subscription Key: <key + owner + consumer evidence hoặc not-applicable>
- Lifecycle Gate: <lifecycle owner/gate evidence hoặc not-applicable>

## Behavior, Failure Modes, Security, Performance, and Tests

- Behavior Analysis State: <NOT_RUN | COMPLETE>
- Phân tích hành vi: <chỉ thực hiện sau khi các gate phía trên không BLOCKED>
- Failure modes và edge cases: <bằng chứng>
- Security/performance/concurrency: <bằng chứng>
- Test coverage và production-boundary tests: <bằng chứng>

## Critical
| File:line | Vấn đề | Fix đề xuất |
|---|---|---|

## Major
| File:line | Vấn đề | Fix đề xuất |
|---|---|---|

## Minor
| File:line | Vấn đề | Fix đề xuất |
|---|---|---|

## Change Hygiene

- Change Hygiene Verdict: <PASS | BLOCKED>

Reconcile every implementation `Change Hygiene` row exactly once. `Scope
Evidence` is exact `<canonical path>#<edited region>`, formatter evidence and
pinned SHAs are copied exactly, and severity is `none` only for `Unrelated
Diff = none`; `confirmed:MAJOR-*` uses `Major`, one matching `Major` finding,
and a `BLOCKED` hygiene verdict. Missing, duplicate, surplus, or contradictory
rows are blocking.

| Task / Unit | Scope Evidence | Formatter Evidence | Unrelated Diff | Severity | Task-base SHA | Final-tree SHA |
|---|---|---|---|---|---|---|
| <UNIT-001> | <canonical path>#<edited region> | <exact command or none> | <none or confirmed:MAJOR-*> | <none or Major> | <sha> | <sha> |

## Activation Slice

Ghi `not-applicable-approved` với evidence và decision reference khi unit không có activation selector; không được bỏ section.

| Activation Slice ID | Applicability | Seam | Input | Output | Source Reference | Trace IDs | Disposition | Status | Decision Reference | Deferred Unit ID |
|---|---|---|---|---|---|---|---|---|---|---|
| <ACT-001> | <applicable / not-applicable-approved / unknown> | <canonical seam> | <input> | <output> | <source reference> | <trace IDs> | <implement / reuse / deferred-approved / not-applicable-approved> | <verified / missing / conflict / unknown> | <approval reference hoặc not-applicable> | <UNIT-* hoặc not-applicable> |

## Bằng chứng
- <tham chiếu diff/rule/evidence>

## Domain Blocker

Chỉ giữ section này khi front matter là `result: blocked` và Activation Slice/handoff vẫn hợp lệ; mọi output khác phải xóa toàn bộ section. Giá trị placeholder không phải evidence hợp lệ.

| Blocker | Evidence Reference |
|---|---|
| <blocker cụ thể> | <tham chiếu bằng chứng cụ thể> |
## Điểm chưa rõ
- <không có hoặc điểm chưa rõ>

## Kết luận
- **Critical count:** <non-negative integer>
- **Major count:** <non-negative integer>
- Verdict: <Approve | Approve-with-fixes | Reject>

Only exact `Critical count: 0` with exact `Verdict: Approve` is executable downstream. `Approve-with-fixes`, `Reject`, a positive/invalid Critical count, or any `BLOCKED` architecture verdict must not seed verification.

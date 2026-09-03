---
step_id: 07-gerrit-automation
status: draft
# Migration only:
result: <complete | partial | blocked>
produced_at: <yyyy-mm-dd>
responsibility_contract:
  version: 1
  applicability: required
---

# Gerrit Report — <tên module>

<!-- Chỉ giữ các section migration envelope khi caller-provided workflow_type=migration; feature/bugfix bỏ qua. Trước khi render, resolve approved plan và exact ordered review -> verification -> parity -> optional mode-required regression -> terminal KB chain; paired KB/Gerrit equality alone is not authority. -->
## Master Scope Context

| Run ID | Master Spec Reference | Master Spec ID | Master Spec Revision | Master Plan Reference | Master Plan ID | Master Plan Revision | Work Item ID |
|---|---|---|---|---|---|---|---|
| <RUN-*> | <master spec reference> | <SPEC-*> | <revision> | <master plan reference> | <PLAN-*> | <revision> | <WORK-*> |

- Delivery Adapter Kind: <migration-unit | task | story | package | phase | milestone | none>
- Delivery Adapter Mode Constraint: <incremental/preserve-existing | greenfield/design-new>

## Task Provenance

| Task / Unit | Task-base SHA | Final-tree SHA | Source Artifact |
|---|---|---|---|
| <UNIT-* only for migration-unit; otherwise exact WORK-*> | <task-base SHA> | <final-tree SHA> | <immediate predecessor artifact path copied unchanged from terminal Knowledge Base Task Provenance> |

Keep `Selected Migration Unit` exactly once only when `Delivery Adapter Kind` is `migration-unit`; for `task | story | package | phase | milestone | none`, omit the entire section and use `Master Scope Context.Work Item ID` as the generic identity.

## Selected Migration Unit

`Plan Reference`: `<selector authority>@<positive authority revision>` (exact canonical composite).

| Migration Unit ID | Plan Reference | Approval Reference | Mode Constraint | Bootstrap Scope | Foundation Baseline ID | Foundation Baseline Reference | Foundation Baseline Approval Reference | Baseline Reference | Trace IDs |
|---|---|---|---|---|---|---|---|---|---|
| <UNIT-001> | <plan reference> | <unit approval reference> | <mode/policy constraint> | <required or not-required> | <FOUNDATION-001 or not-applicable> | <approved target-baseline reference or not-applicable> | <approval reference or not-applicable> | <regression evidence reference or not-applicable> | <trace IDs> |

## Architecture Responsibility Handoff

| Responsibility Contract Version | Tree Conformance | Responsibility Conformance | Verification Ownership | Architecture Conformance State | Evidence References |
|---|---|---|---|---|---|
| 1 | <PASS or BLOCKED> | <PASS or BLOCKED> | <PASS or BLOCKED> | <derived PASS or BLOCKED> | source-diff:<task-base SHA>..<final-tree SHA>#<WORK-*> |

## Migration Verification Verdicts

| Parity Verdict | Regression Applicability | Regression Verdict | Evidence Reference |
|---|---|---|---|
| <pass, fail, or blocked> | <required or not-applicable> | <pass, fail, blocked, or not-applicable> | <immediate predecessor evidence> |

## Rule Resolution
- **State:** `RESOLVED | BLOCKED`
- **Mandatory rule gaps:** <none or exact blocking gaps>
- **Optional gaps/degraded coverage:** <none or recorded degraded coverage>

## Commit message
```
<theo mandatory project rule đã resolve; optional convention thiếu ⇒ ghi degraded fallback Conventional Commits>
```

## Change description
<mô tả thay đổi, phạm vi, cách test>

## Branch and Commit Integrity

| Task-base SHA | Upstream Ref | Upstream SHA | Merge-base SHA | Final Commit SHA | Actual Task Commit Count | Task / Unit ID | Diff-scope Verdict | Formatter Evidence | Post-integration Verification |
|---|---|---|---|---|---|---|---|---|---|
| <sha> | <resolved ref or not-applicable> | <sha or not-applicable> | <sha or not-applicable> | <sha> | <observed integer> | <task or UNIT-###> | <PASS or BLOCKED> | <commands or none> | <commands, output, exits, upstream SHA, evidence> |

## Thông tin upload
- Change-Id:
- Reviewer đề xuất:
- Trạng thái: <chưa upload / đã upload sau HARD gate>

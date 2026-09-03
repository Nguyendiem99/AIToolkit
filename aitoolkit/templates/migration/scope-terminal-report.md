---
artifact_type: migration-scope-terminal-report
master_spec_id: SPEC-<PHẠM-VI>-<NNN>
master_spec_revision: <số nguyên dương>
master_plan_id: PLAN-<PHẠM-VI>-<NNN>
master_plan_revision: <số nguyên dương>
status: draft
result: complete
approval_source: human
scope_status: <trạng thái scope theo hợp đồng>
produced_at: <YYYY-MM-DD>
---

# Báo cáo kết thúc phạm vi migration

## Master Revision Context

| Master Spec Reference | Master Spec Revision | Master Plan Reference | Master Plan Revision | Terminal Report Reference |
|---|---:|---|---:|---|
| <tham chiếu master spec bất biến> | <revision> | <tham chiếu master plan bất biến> | <revision> | <tham chiếu artifact hiện tại> |

## Work Item Terminal Evidence

| Work Item ID | Required | Status | Terminal Evidence | Runtime Evidence State | Architecture Conformance State | Selector Schema State | Blocker | Plan Revision |
|---|---|---|---|---|---|---|---|---:|
| WORK-<PHẠM-VI>-<TÊN> | yes | complete | <tham chiếu evidence bất biến> | PASS | PASS | PASS | none | <revision> |

For each terminal-success row, `Terminal Evidence` resolves only the immutable work-item terminal artifact. That artifact contains the exact v1 `Architecture Responsibility Handoff`, whose `Evidence References` remains the review-originated source-diff, followed by exactly one `## Terminal Chain Reference` table with columns `Work Item ID | Artifact Reference`. Its only row binds the same Work Item to the immutable final KB artifact of the mode-aware ordered chain. Pending and other non-terminal rows use `none` and do not declare a responsibility chain.

## Scope Completion Calculation

| Graph State | Required Items | Required Terminal Evidence | Tree Conformance | Responsibility Conformance | Verification Ownership | Architecture State | Selector Schema State | Remaining Blockers | Calculated Terminal Verdict |
|---|---|---|---|---|---|---|---|---|---|
| valid | all-terminal-success | all-required-terminal-evidence | PASS | PASS | PASS | PASS | PASS | none | scope-complete |

## Architecture Responsibility Handoff

| Responsibility Contract Version | Tree Conformance | Responsibility Conformance | Verification Ownership | Architecture Conformance State | Evidence References |
|---|---|---|---|---|---|
| 1 | PASS | PASS | PASS | PASS | <ordered immutable source-diff references preserved from each work-item handoff> |

The handoff row preserves only the review-originated source-diff references. The separate Evidence Index contains the ordered immutable terminal evidence references resolved from Work Item Terminal Evidence; it never overwrites or overloads the handoff cells.

## Evidence Index

| Evidence ID | Artifact Reference | Work Item ID | Purpose |
|---|---|---|---|
| EVIDENCE-ARCH-WORK-<PHẠM-VI>-<TÊN> | <final KB artifact from the work-item Terminal Chain Reference> | WORK-<PHẠM-VI>-<TÊN> | architecture-responsibility-sub-verdicts |

Each Evidence Index row binds the same final ordered-chain artifact referenced by the work-item terminal handoff through that artifact's separate `Terminal Chain Reference`; the immutable handoff `Evidence References` remains the exact source diff.

## Blockers and Dispositions

| Work Item ID | Blocker | Disposition | Decision Reference |
|---|---|---|---|
| WORK-<PHẠM-VI>-<TÊN> | none | not-applicable | not-applicable |

## Approval Record

| Decision | Approver | Evidence | Decided At |
|---|---|---|---|
| pending | pending | pending | pending |

## Revision History

| Artifact ID | Revision | Supersedes | Change Summary | Affected Work Items | Approval Reference |
|---|---:|---|---|---|---|
| REPORT-<PHẠM-VI>-<NNN> | 1 | not-applicable | Khởi tạo báo cáo kết thúc phạm vi | WORK-<PHẠM-VI>-<TÊN> | pending |

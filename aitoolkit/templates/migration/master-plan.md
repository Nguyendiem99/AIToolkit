---
artifact_type: migration-master-plan
master_plan_id: PLAN-<SCOPE>-<NNN>
master_spec_id: SPEC-<SCOPE>-<NNN>
master_spec_revision: <positive integer>
revision: <positive integer>
status: <artifact lifecycle value>
scope_status: planned
execution_policy: dependency-ready
max_concurrency: 1
produced_at: <yyyy-mm-dd>
supersedes: not-applicable
responsibility_contract:
  version: 1
  applicability: required
---

<!-- artifact_language: vi -->

# Master plan migration

## Requested Scope

| Kind | ID | Statement | Source | Resolution Evidence |
|---|---|---|---|---|
| <scope kind> | <stable scope ID> | <kết quả người dùng yêu cầu> | user | <tham chiếu evidence ổn định> |

## Work Items

| Work Item ID | Title | Required | Dependencies | Plan Order | Acceptance | Trace IDs | Delivery Adapter | Status | Latest Attempt | Terminal Evidence | Approval Reference |
|---|---|---|---|---|---|---|---|---|---|---|---|
| WORK-<SCOPE>-<NAME> | <outcome độc lập, review được> | <yes/no> | none | <positive integer> | <REQ/SC IDs và kết quả đo được> | <stable trace IDs> | none | in-progress | ATTEMPT-<WORK-ITEM>-<NN> | none | pending |

## Delivery Adapter Selection

| Work Item ID | Adapter Kind | External ID | Authority | Authority Revision | Approval Reference | Parent Selector | Acceptance | Trace IDs | Mode Constraint | Design Revision | Parent Work Item ID | Decomposition Decision Reference |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| WORK-<SCOPE>-<NAME> | none | not-applicable | not-applicable | not-applicable | not-applicable | not-applicable | <REQ/SC IDs và kết quả đo được> | <stable trace IDs> | <approved mode/architecture policy> | <approved design revision> | not-applicable | not-applicable |

## Responsibility Owner References

Copy exactly one row per Work Item from the approved technical-design responsibility model. The row and `Delivery Adapter Selection.Design Revision` jointly form pre-edit planned authority; they never substitute for the later review handoff.

| Work Item ID | Design Revision | Responsibility IDs | Shared Foundation IDs | Integration Responsibility IDs | Independent Boundary Evidence |
|---|---|---|---|---|---|
| WORK-<SCOPE>-<NAME> | <approved design revision> | <ordered concrete RESP-* IDs> | <ordered shared RESP-* IDs or not-applicable> | <ordered integration RESP-* IDs or not-applicable> | <immutable rule/decision/approval evidence> |

## Dependency Graph

| Work Item ID | Dependency Work Item ID | Relationship | Evidence |
|---|---|---|---|
| WORK-<SCOPE>-<NAME> | none | no-dependency | <tham chiếu quyết định> |

## Attempt History

| Attempt ID | Work Item ID | Plan Revision | Status | Artifact Reference |
|---|---|---|---|---|
| ATTEMPT-<WORK-ITEM>-<NN> | WORK-<SCOPE>-<NAME> | <positive integer> | in-progress | <immutable artifact reference> |

## State Transition Log

| Work Item ID | From State | To State | Evidence or Decision | Plan Revision |
|---|---|---|---|---|
| WORK-<SCOPE>-<NAME> | ready | in-progress | ATTEMPT-<WORK-ITEM>-<NN> | <positive integer> |

## Scope Completion Calculation

| Required Work Items | Terminal-Success Items | Blockers | Dependency Graph | Architecture Conformance | Selector/Schema | Scope Status |
|---|---|---|---|---|---|---|
| <count/reference> | <count/reference> | none | valid | PASS | PASS | planned |

## Evidence

| Evidence | Location | Notes |
|---|---|---|
| <evidence ID> | <artifact reference> | <ghi chú> |

## Unknowns

| ID | Unknown | Impact | Disposition |
|---|---|---|---|
| UNK-### | <điểm chưa rõ> | <scope/architecture/acceptance impact> | <resolved/blocked/accepted> |

## Approval Record

| Approval Reference | Status | Approved At |
|---|---|---|
| <approval reference> | pending | <yyyy-mm-dd> |

## Revision History

| Artifact ID | Revision | Supersedes | Change Summary | Affected Work Items | Approval Reference |
|---|---|---|---|---|---|
| PLAN-<SCOPE>-<NNN> | <positive integer> | not-applicable | <tóm tắt thay đổi được duyệt> | none | pending |

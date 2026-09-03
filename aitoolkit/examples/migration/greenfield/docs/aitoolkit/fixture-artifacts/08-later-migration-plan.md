---
step_id: 08-plan-waves
status: approved
result: complete
approval_source: human
produced_at: 2026-08-11
---

# Later Migration Plan Fixture

## Activation Slice

| Activation Slice ID | Applicability | Seam | Input | Output | Source Reference | Trace IDs | Disposition | Status | Decision Reference | Deferred Unit ID |
|---|---|---|---|---|---|---|---|---|---|---|
| ACT-001 | applicable | upstream-response | profile response | activation key | legacy/service:10 | TR-REQ-001, TR-UP-001 | reuse | verified | not-applicable | not-applicable |
| ACT-001 | applicable | requested-key | profile request | requested activation key | legacy/request:20 | TR-REQ-001, TR-KEY-001 | implement | verified | not-applicable | not-applicable |
| ACT-001 | applicable | parse-model | activation key | parsed model field | legacy/parser:30 | TR-REQ-001, TR-PARSE-001 | implement | verified | not-applicable | not-applicable |
| ACT-001 | applicable | state-holder | parsed model field | activation state | legacy/state:40 | TR-REQ-001, TR-STATE-001 | implement | verified | not-applicable | not-applicable |
| ACT-001 | applicable | selector | async-classification=async; activation state | initial-loading=spinner; update-watch=subscription; reselection=rerun; state-preservation-reset=preserve; failure-behavior=error | legacy/selector:50 | TR-REQ-001, TR-SELECT-001 | implement | verified | not-applicable | not-applicable |
| ACT-001 | applicable | construct | selected module | base-owned | legacy/router:60 | TR-REQ-001, TR-ROUTER-001 | reuse | verified | not-applicable | not-applicable |
| ACT-001 | applicable | render | constructed module | visible module | legacy/render:70 | TR-REQ-001, TR-RENDER-001 | reuse | verified | not-applicable | not-applicable |
| ACT-001 | applicable | downstream-consumer | selected module | deeplink and action flow | legacy/consumer:80 | TR-REQ-001, TR-CONSUME-001 | implement | verified | not-applicable | not-applicable |
| ACT-001 | applicable | test | complete activation flow | lifecycle-test-trace=TR-LIFECYCLE-001 | legacy/tests:90 | TR-REQ-001, TR-LIFECYCLE-001 | implement | verified | not-applicable | not-applicable |

## Các đơn vị migration theo thứ tự

| Order | Migration Unit ID | Bootstrap Scope | Foundation Baseline ID | Foundation Approval Reference | Dependencies | Acceptance | Mode Constraint | Trace IDs | Delivery Change Boundary | Approval Reference | Approval Status |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | UNIT-002 | not-required | FOUNDATION-EXAMPLE-001 | docs/aitoolkit/fixture-artifacts/09-bootstrap-report.md#FOUNDATION-EXAMPLE-001 | UNIT-001 | Preserve the approved target foundation | greenfield/design-new | TR-REQ-001, TR-RENDER-001 | one-unit-one-change | docs/aitoolkit/fixture-artifacts/08-later-migration-plan.md#UNIT-002 | approved |

## Approved Foundation Baselines

| Foundation Baseline ID | Target Baseline Reference | Approval Reference | Approval Status | Evidence |
|---|---|---|---|---|
| FOUNDATION-EXAMPLE-001 | docs/aitoolkit/migration-project/references/target-baseline.md#FOUNDATION-EXAMPLE-001 | docs/aitoolkit/fixture-artifacts/09-bootstrap-report.md#FOUNDATION-EXAMPLE-001 | approved | design revision DESIGN-EXAMPLE-001; Freshness Evidence current |

## Evidence

| Evidence | Location | Notes |
|---|---|---|
| Approved target baseline | docs/aitoolkit/migration-project/references/target-baseline.md#FOUNDATION-EXAMPLE-001 | Resolves one approved, current foundation record. |

## Unknowns

- None for this fixture.

## Verdict

ready

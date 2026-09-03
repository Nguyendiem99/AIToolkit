---
step_id: 07-gerrit-automation
status: draft
# Migration only: add `result: complete | partial | blocked`
produced_at: <yyyy-mm-dd>
---

# Gerrit Report — <tên module>

<!-- Chỉ giữ hai section migration này khi caller-provided workflow_type=migration; feature/bugfix bỏ qua. -->
## Selected Migration Unit

| Migration Unit ID | Plan Reference | Approval Reference | Mode Constraint | Bootstrap Scope | Foundation Baseline ID | Foundation Baseline Reference | Foundation Baseline Approval Reference | Baseline Reference | Trace IDs |
|---|---|---|---|---|---|---|---|---|---|
| <UNIT-001> | <plan reference> | <unit approval reference> | <mode/policy constraint> | <required or not-required> | <FOUNDATION-001 or not-applicable> | <approved target-baseline reference or not-applicable> | <approval reference or not-applicable> | <regression evidence reference or not-applicable> | <trace IDs> |

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

---
step_id: <shared: orchestrator provided>
status: draft
produced_at: <yyyy-mm-dd>
---

# AI Review Report — <module name>

## Overview
- Review scope (SHA): `<BASE>..<HEAD>`
- Applied project rules: <profile/pack path + mandatory rules + optional gaps/degraded coverage>

## Rule Resolution
- **State:** `RESOLVED | BLOCKED`
- **Mandatory rule gaps:** <none or exact blocking gaps>
- **Optional gaps/degraded coverage:** <none or recorded degraded coverage>

## Critical
| File:line | Issue | Proposed fix |
|---|---|---|

## Major
| File:line | Issue | Proposed fix |
|---|---|---|

## Minor
| File:line | Issue | Proposed fix |
|---|---|---|

## Change Hygiene

| Task / Unit | Scope Evidence | Formatter Evidence | Unrelated Diff | Severity | Task-base SHA | Final-tree SHA |
|---|---|---|---|---|---|---|
| <task or unit> | <changed files/symbols> | <commands or none> | <none or finding> | <none, Major, or Critical> | <sha> | <sha> |

## Verdict
- **Critical count:** <integer used by the gate>
- **Verdict:** `Approve` | `Approve-with-fixes` | `Reject`

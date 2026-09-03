---
step_id: <shared: orchestrator provided>
status: draft
produced_at: <yyyy-mm-dd>
---

# Verification & Testing Report — <module name>

## Task Provenance

| Task / Unit | Task-base SHA | Final-tree SHA | Source Artifact |
|---|---|---|---|
| <task> | <sha> | <sha> | <review-report path> |

## Commands Run (verbatim)
| Type | Command | Source (profile/detection/gate) |
|---|---|---|
| test |  |  |
| lint |  |  |
| build |  |  |

## Raw Results
- Test: <pass/fail count>, exit code:
- Lint: <error count>, exit code:
- Build: exit code: <or "N/A" when the ecosystem has no build step>
- Failure output excerpt:

## Behavior Checks
| Requirement / Scenario | Proof command | Actual result |
|---|---|---|

<!-- Bugfix: record red-green proof (revert→FAIL→restore→PASS). -->

## Coverage (when coverage_cmd exists)
| Component | % | Coverage quality notes |
|---|---|---|

## Gaps / Risks
- Not covered:
- Remaining risks:

## Verdict
`PASS` | `FAIL` | `BLOCKED` — <one evidence-backed sentence>

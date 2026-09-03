---
name: verify-parity
description: Use when migrated behavior must be compared with an evidence-backed source baseline before acceptance.
---

# Migration 13 — Verify Parity

**Core principle:** Parity is a scenario-by-scenario comparison against a real baseline; implementation similarity and assumed behavior are not evidence.

## Ngôn ngữ artifact

Nhận `artifact_language` do orchestrator truyền. Hiện chỉ hỗ trợ `artifact_language: vi`: viết tiêu đề, tóm tắt, blocker, khuyến nghị và nội dung gate bằng tiếng Việt UTF-8; giữ nguyên mọi field machine-readable, enum, ID, path, command, log, trace field và cột bảng contract.

## Inputs

The orchestrator provides `RUN_DIR`, project profile, project pack, source/target locations, and one explicit predecessor artifact path.

`Immediate predecessor artifact = exactly one orchestrator-provided path`.

## Activation Slice responsibilities

Read `aitoolkit/contracts/activation-slice.md` as the sole canonical definition. Preserve the immediate predecessor Activation Slice envelope without loss: keep the complete case-sensitive slice ID set, Applicability, all nine canonical seam rows, and every predecessor Source Reference and Trace ID. Source Reference enrichment is append-only, and predecessor Trace IDs remain a subset of successor Trace IDs. Never reconstruct it from cumulative artifacts.

Validate and copy that envelope before parity execution. Scenario evidence may enrich Source Reference and Trace IDs only under the canonical append-only handoff rules; missing or reclassified slices block.

Use forwarded acceptance scenarios and trace IDs; do not load cumulative numbered artifacts or maintain private workflow state.

## Baseline gate

Determine parity policy from `verification.behavior_parity`.

- When parity is required, every scenario needs a `required baseline`: a fresh runnable source result or an approved golden expectation with its source reference.
- If any required baseline is missing, stale, ambiguous, or cannot be reproduced, record `result: blocked` and a blocked verdict. Never mark that scenario or the report PASS.
- A changed behavior passes only when an approved decision explicitly replaces the old expectation and the report cites that decision and affected trace IDs.

## Migration-only handoff extension

This skill runs for `workflow_type: migration`; feature and bugfix shared flows do not use this extension. Its immediate predecessor must contain exactly one `Selected Migration Unit` section.

- Validate and copy `migration_unit_id`, plan reference, approval reference, mode constraint, `Bootstrap Scope`, Foundation Baseline ID, foundation baseline reference, foundation baseline approval reference, baseline reference, and trace IDs into the parity report.
- The output keeps `result: complete | blocked`; missing, ambiguous, or mismatched handoff evidence yields `result: blocked` before parity execution.
- Never reconstruct the selected unit or incremental baseline reference from cumulative artifacts.

## Procedure

1. Read `aitoolkit-schemas`, the profile, project pack, predecessor artifact, and `aitoolkit/templates/migration/parity-report.md`; validate the migration-only handoff extension.
2. Build one scenario per approved acceptance behavior and edge case, forwarding the full trace ID set.
3. Capture the source/golden baseline, input, environment, and evidence location before testing the target.
4. Resolve commands through `explicit profile -> existing project scripts/config -> marker detection -> human gate`; use repository commands verbatim and do not invent commands.
5. Run the same scenario inputs against baseline and target when runnable. Capture commands, exit codes, outputs, and differences as fresh Evidence.
6. Classify each scenario: `pass` only for equivalent observed behavior; `fail` for an unexplained difference; `blocked` for missing baseline, command, or environment.
7. The report passes only when every required scenario passes. Any fail makes it fail; any unresolved required scenario makes it blocked.

## Evidence and Unknowns

Evidence identifies baseline provenance, exact inputs, environments, commands, raw outcomes, approved behavior changes, and trace IDs. Unknowns list missing baselines or execution capability and the scenarios they block.

## Hợp đồng đầu ra

Preserve the validated `Task Provenance` lineage from the verification predecessor: task/unit ID, task-base SHA, and final-tree SHA remain ordinally exact, while `Source Artifact` resolves to that exact immediate verification artifact path. Missing, unrelated-source, or mismatched lineage yields `result: blocked`.

- File: `<RUN_DIR>/13-parity-report.md`.
- Front matter: `step_id: 13-verify-parity`, `status: draft`, `result: complete | blocked`, `produced_at`.
- Preserve `Activation Slice` from the verification predecessor with the identical slice set, Applicability, all nine rows, Source Reference evidence, and Trace IDs.
- Preserve `Selected Migration Unit` with selector, plan/approval, bootstrap-scope, foundation-baseline ID/reference/approval, regression baseline, and trace references.
- Write exactly one structured `Parity Verdict` row with the canonical `Parity Verdict` and non-empty `Evidence Reference` fields defined by `aitoolkit/contracts/activation-slice.md`.
- Preserve `Scenarios`, `Command / Evidence`, `Evidence`, and `Unknowns`.
- The structured `Parity Verdict` row is the sole overall verdict surface. Its value is `pass | fail | blocked` and must agree with scenario evidence and front-matter result.

## Quick reference

| Evidence | Verdict |
|---|---|
| Baseline and target equivalent for every required scenario | Pass |
| Unapproved behavioral difference | Fail |
| Required baseline or command missing | Blocked |

## Common mistakes

- Reconstructing expected behavior from the migrated implementation.
- Calling an unexecuted or baseline-free scenario pass.
- Hiding an approved behavior change inside notes instead of citing its decision.

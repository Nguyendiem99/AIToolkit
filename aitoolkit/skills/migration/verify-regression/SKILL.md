---
name: verify-regression
description: Use when an incremental migration candidate must be compared with its pre-change target baseline and existing failures may need classification.
---

# Migration 14 — Verify Regression

**Core principle:** A regression is a candidate-only or worsened failure relative to the pre-change baseline, not every post-migration failure.

## Ngôn ngữ artifact

Nhận `artifact_language` do orchestrator truyền. Hiện chỉ hỗ trợ `artifact_language: vi`: viết tiêu đề, tóm tắt, blocker, khuyến nghị và nội dung gate bằng tiếng Việt UTF-8; giữ nguyên mọi field machine-readable, enum, ID, path, command, log, trace field và cột bảng contract.

## Inputs

The orchestrator provides `RUN_DIR`, profile, project pack, source/target, and one predecessor path.

`Immediate predecessor artifact = exactly one orchestrator-provided path`.

## Activation Slice responsibilities

Read `aitoolkit/contracts/activation-slice.md` as the sole canonical definition. Preserve the immediate predecessor Activation Slice envelope without loss: keep the complete case-sensitive slice ID set, Applicability, all nine canonical seam rows, and every predecessor Source Reference and Trace ID. Source Reference enrichment is append-only, and predecessor Trace IDs remain a subset of successor Trace IDs. Never reconstruct it from cumulative artifacts.

Validate and copy that envelope before regression execution. Regression evidence may enrich Source Reference and Trace IDs only under the canonical append-only handoff rules; missing or reclassified slices block.

Use forwarded trace IDs and pre-change evidence; do not load cumulative artifacts or create private state.

## Applicability and baseline gate

Regression verification is mandatory for incremental / `preserve-existing` and cannot be waived or skipped. Other mode/policy pairs yield `result: blocked` without a regression claim.

Require a regression command resolved before comparison and a pre-change target run captured before implementation. Resolve the command through `explicit profile -> existing project scripts/config -> marker detection -> human gate`. A missing command or comparable baseline yields `result: blocked`; do not infer a baseline from the candidate.

## Migration-only handoff extension

This skill runs for `workflow_type: migration`; feature and bugfix shared flows do not use this extension. The immediate predecessor must contain exactly one `Selected Migration Unit` section plus the structured `Parity Verdict` row and evidence reference required by `aitoolkit/contracts/activation-slice.md`.

- Validate and copy `migration_unit_id`, plan reference, approval reference, mode constraint, `Bootstrap Scope`, Foundation Baseline ID, foundation baseline reference, foundation baseline approval reference, baseline reference, and trace IDs from the immediate predecessor.
- Preserve a lifecycle-valid predecessor parity verdict (`pass | fail`), add the regression verdict, and write `result: complete | blocked`. A blocked parity report stops before step 14. Missing, ambiguous, or mismatched selected-unit, baseline, or verdict evidence yields `result: blocked` before executing regression.
- Never reconstruct the envelope or parity verdict from cumulative artifacts. For feature and bugfix, this extension is not applicable.

## Procedure

1. Read `aitoolkit-schemas`, the profile, project pack, immediate predecessor artifact, and `aitoolkit/templates/migration/regression-report.md`; validate the migration-only handoff extension.
2. Validate that baseline and candidate use the same command, environment, configuration, and scenarios. Non-comparable evidence is blocked.
3. Run the candidate command and capture fresh exit code, output, environment, and trace IDs.
4. Match failures by stable check/scenario identity and meaningful failure signature:
   - present only in the candidate, or materially worse there: new regression, `fail`;
   - same identity and outcome in both runs: pre-existing `baseline failure`, not a new regression;
   - present only in the baseline: resolved pre-existing failure, record it separately.
5. Each continuing baseline failure needs an approved `waiver` scoped to identity, owner, rationale, and validity. Missing or expired waiver blocks; it is not a new-regression fail.
6. A waiver never covers a candidate-only or worsened failure. Any new regression makes the report fail.
7. Pass only when comparison is complete, no new regression exists, and every baseline failure has a valid waiver.

## Evidence and Unknowns

Evidence includes command provenance, comparable runs, failure identities, deltas, waivers, and trace IDs. Unknowns list missing command, baseline, comparability, identity, or waiver.

## Hợp đồng đầu ra

Preserve the validated `Task Provenance` lineage from the parity predecessor: task/unit ID, task-base SHA, and final-tree SHA remain ordinally exact, while `Source Artifact` resolves to that exact immediate parity artifact path. Missing, unrelated-source, or mismatched lineage yields `result: blocked`.

- File: `<RUN_DIR>/14-regression-report.md`.
- Front matter: `step_id: 14-verify-regression`, `status: draft`, `result: complete | blocked`, `produced_at`.
- Preserve `Activation Slice` from the parity predecessor with the identical slice set, Applicability, all nine rows, Source Reference evidence, and Trace IDs.
- Preserve `Selected Migration Unit` with the full migration handoff envelope.
- Preserve `Kết luận xác minh migration` with parity verdict, regression applicability/verdict, and evidence references.
- Preserve `Scenarios`, `Command / Evidence`, `Evidence`, and `Unknowns`. The structured `Kết luận xác minh migration` row is the sole overall verdict surface and agrees with scenario evidence.
- Each scenario states baseline outcome, candidate outcome, delta class, waiver reference when needed, and trace IDs.

## Quick reference

| Comparison | Verdict effect |
|---|---|
| Candidate-only or worsened failure | Fail |
| Same baseline failure, valid waiver | Not a new regression; may pass |
| Same baseline failure, no valid waiver | Blocked |
| Command/baseline unavailable | Blocked |

## Common mistakes

- Counting every candidate failure as migration-caused.
- Capturing the baseline after implementation.
- Using a broad waiver for an unrelated new failure.

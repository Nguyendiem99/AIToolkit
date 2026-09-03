---
name: code-migration
description: Use when an approved migration unit is ready for isolated, traceable implementation against an approved mode-aware plan.
---

# Migration 10 — Code Migration

**Core principle:** Implement exactly one approved migration unit, preserve mode constraints, and prove behavior with traceable tests.

**REQUIRED SUB-SKILLS:** Use `superpowers:using-git-worktrees`, `superpowers:writing-plans`, `superpowers:executing-plans`, and `superpowers:test-driven-development`.

## Ngôn ngữ artifact

Nhận `artifact_language` do orchestrator truyền. Hiện chỉ hỗ trợ `artifact_language: vi`: viết tiêu đề, tóm tắt, blocker, khuyến nghị và nội dung gate bằng tiếng Việt UTF-8; giữ nguyên mọi field machine-readable, enum, ID, path, command, log, trace field và cột bảng contract.

## Inputs

The orchestrator provides `RUN_DIR`, profile, project pack, source/target, one predecessor path, `migration_unit_id`, `foundation_baseline_id` for a greenfield `not-required` unit, and the resolved per-run `automation_mode`, alongside that path. On an incremental baseline-waiver resume, it also provides the exact approved waiver artifact.

`Immediate predecessor artifact = exactly one orchestrator-provided path`.

Preserve the immediate predecessor Activation Slice envelope without loss: keep the complete case-sensitive slice ID set, Applicability, all nine canonical seam rows, and every predecessor Source Reference and Trace ID. Source Reference enrichment is append-only, and predecessor Trace IDs remain a subset of successor Trace IDs. Never reconstruct it from cumulative artifacts.
Never load cumulative artifacts or create private state.

The approved Activation Slice is part of the selected-unit input. Read `aitoolkit/contracts/activation-slice.md` as the sole definition source and preserve the same stable slice ID, every seam row, and trace IDs; do not reconstruct or narrow it from the implementation diff.

## Entry gate

Resolve `migration_unit_id`. Require exactly one approved migration unit whose acceptance, mode/policy, design revision, and trace IDs agree; never select implicitly.

Validate the approved `Activation Slice` at the `Entry gate` before any target edit. Require its preserved ID, all seam rows, dispositions, approval/deferred references, and trace IDs to agree with the selected unit. Missing, conflicting, draft, or narrowed activation evidence that can prevent activation yields `status: draft` and `result: blocked`, never partial.

- `greenfield` / `design-new` with `Bootstrap Scope = required`: require the approved plan selection to have entered step 09 with `Foundation Baseline ID = pending-bootstrap`, then require a preserved bootstrap record and preserved `Bootstrap Scope = required`; the record itself must be approved. It must contain exactly one approved `FOUNDATION-*` record whose `Source Migration Unit ID` matches the selected `migration_unit_id`. Plan/approval references must identify the same approved unit; selector mismatch yields `result: blocked`. Preserve the created Foundation Baseline ID/reference/approval reference.
- `greenfield` / `design-new` with greenfield `Bootstrap Scope = not-required`: the immediate predecessor is the approved migration plan, not a bootstrap record. Resolve `foundation_baseline_id` to exactly one approved foundation baseline record from the approved target baseline/project pack referenced by that plan and require its target baseline reference, foundation baseline approval reference, design revision, and freshness evidence. Missing, stale, ambiguous, or mismatched foundation evidence yields `result: blocked`; do not bootstrap or select a baseline implicitly.
- `incremental` / `preserve-existing`: resolve the selector directly against the immediate predecessor migration plan. Require incremental `Bootstrap Scope = not-required`, target conformance, and no bootstrap. Baseline capture belongs to the pre-mutation gate below, not to invocation eligibility.
- Missing, ambiguous, draft, unapproved, or selector-mismatched evidence yields `result: blocked`.
- Unknown, invalid, or mismatched pairs: block before editing.

## Pre-mutation gate

For incremental mode, absence before invocation is not a blocker: this invocation must resolve required commands and capture a comparable pre-change regression baseline before any target edit.

- Resolve the regression command through the project command-resolution contract before opening an implementation plan.
- Run the resolved command against the unchanged target and record command, source, environment, exit code, output, failure identities, and evidence reference.
- If command resolution or baseline capture fails, write `result: blocked` and stop before editing. Never infer or capture the baseline from the candidate.
- Greenfield records the baseline reference as `not-applicable`; it does not invent an incremental comparison.

## Native blocker evidence

Treat `automation_mode` as orchestration context, not permission for this step to continue. When a required executable is absent, a command did not start because an environment capability is unavailable, or the pre-mutation baseline cannot be collected for that reason, keep `status: draft`, write `result: blocked`, and stop before any target edit. Record the resolved command or capability, the verbatim lookup/start error, exit code when one exists, environment details, and an evidence reference in `Blocker gốc`.

For each native blocker, record one command role and the required-command lifecycle. An executable lookup or a device, emulator, service, or network check is an `availability probe`; record `not-started` only when the `required test/build/baseline command` did not begin. A failed `availability probe` may establish that the required command cannot start because the named capability is absent, but the probe's nonzero exit is capability evidence rather than a correctness/regression result. Only this separate-probe plus `not-started` evidence is an environment-waiver candidate.

The command whose test, build, or baseline behavior is being judged is the `required test/build/baseline command`. Record `started-without-correctness/regression-result` when its process begins and fails before producing such a result; record `started-and-produced-correctness/regression-result` when it produces one. Any started required command is waiver-ineligible, whether or not it produces a correctness/regression result. If the required command starts and returns a correctness/regression failure while an environment symptom also exists, record the executed command, exit code, output, and failure identities as the native blocker. Do not relabel it as an unavailable environment. Missing, ambiguous, or contradictory command role or lifecycle evidence remains blocked in every mode.

The step-skill does not approve its artifact and does not add a `waiver`; only the migration orchestrator may validate the blocker taxonomy and change continuation state. Missing or vague evidence remains `result: blocked` in every automation mode.

## Approved baseline-waiver resume

Accept resume only for an incremental pre-mutation baseline blocker whose separate availability probe proves the required command remained `not-started`, whose target is still unedited, and whose exact environment-unavailable waiver was approved by the orchestrator. Validate the same `migration_unit_id`, plan/approval references, mode constraint, source/target, and `automation_mode`; stale or mismatched input remains blocked. The resumed invocation may skip only pre-mutation baseline collection. Its `Baseline Reference` cites the approved waiver evidence, and its `Approved Baseline Waiver` retains the exact approved waiver and native evidence verbatim.

The resumed invocation still performs selector validation, target source edits, TDD, and the required implementation flow. A waiver never substitutes for source mutation. Because the canonical `waiver` remains present, the resumed artifact must remain exactly `status: approved`, `result: partial`, and `approval_source: auto-waive`; `result: complete` is invalid even after target mutation.

| Resume outcome | Result | Waiver retention | Downstream eligibility |
|---|---|---|---|
| target source mutation recorded with selected unit and trace evidence; normal implementation outcome | `status: approved`; `result: partial`; `approval_source: auto-waive` | retain exact approved waiver and native evidence verbatim | allowed only on this exact valid partial outcome |
| no target source mutation | `blocked` | retain exact approved waiver and native evidence verbatim | forbidden |
| waiver/evidence missing, stale, mismatched, or altered | `blocked` | report mismatch; do not reconstruct | forbidden |
| waiver-ineligible blocker, started required command, or HARD gate | `blocked` | retain supplied evidence verbatim | forbidden |

## Procedure

1. Read `aitoolkit-schemas`, `aitoolkit/contracts/activation-slice.md`, `shared/change-hygiene.md`, inputs, and `aitoolkit/templates/migration/implementation-report.md`; validate the selected-unit Entry gate and approved Activation Slice. Treat the shared scope, formatting, final-diff, and commit-boundary rules as mandatory before any edit.
2. Use `superpowers:using-git-worktrees` to create or verify an isolated worktree and branch without editing the target.
3. Resolve required commands in this command resolution order: `explicit profile -> existing project scripts/config -> marker detection -> human gate`. Use repository commands verbatim; never invent or translate one.
4. In incremental mode, capture a comparable pre-change regression baseline against the unchanged target and preserve its evidence reference. On a valid Approved baseline-waiver resume, skip only that collection and cite the exact approved waiver evidence as `Baseline Reference`. Greenfield records `not-applicable`.
5. Evaluate the pre-mutation gate or validate the exact Approved baseline-waiver resume. An unresolved command or failed/non-comparable baseline capture records `result: blocked` plus its native blocker evidence before any edit; invalid resume evidence also blocks.
6. Use `superpowers:writing-plans` to translate only the approved unit into steps and review checkpoints.
7. Within `superpowers:executing-plans`, apply `superpowers:test-driven-development`: write an acceptance test, observe RED, implement the minimum, observe GREEN, then refactor while staying green.
8. Record each changed-file row and each test as a structured `Activation Slice ID`, `Seam`, and `Trace IDs` link resolved against the approved immediate-predecessor Activation Slice envelope. Every linked slice/seam must exist there and every linked trace ID must belong to that exact predecessor `(Activation Slice ID, Seam)` pair; repeat rows for multi-seam files or tests. Also record unit ID, whether each file is `new` or `existing`, edited regions/symbols, and every formatter command. Inspect the final diff, remove all untraced or formatting-only changes, and block unrelated whole-file churn. Capture commands, sources, exit codes, and Evidence. Local checkpoint commits are non-delivery history; this unit must become one final delivery commit. Do not upload, merge, or mutate unrelated work.

## Evidence and Unknowns

Evidence includes approval, conformance, RED/GREEN output, commands, changes, and trace IDs. Unknowns identify missing evidence.

## Hợp đồng đầu ra

- File: `<RUN_DIR>/10-implementation-report.md`.
- Front matter: `step_id: 10-code-migration`, `status: draft`, `result: complete | partial | blocked`, `produced_at`.
- Preserve `Selected Migration Unit` with `migration_unit_id`, plan reference, approval reference, mode constraint, `Bootstrap Scope`, Foundation Baseline ID, foundation baseline reference, foundation baseline approval reference, baseline reference, and trace IDs.
- Preserve `Activation Slice` with the same ID and all seam rows; implementation never narrows the selected slice.
- Every changed-file row and every test evidence record must link to the approved Activation Slice seam and its trace IDs.
- Use the structured changed-file and `Activation Slice Test Evidence` tables; prose-only linkage is invalid.
- Preserve the exact resolved selector as `foundation_baseline_id` in the implementation artifact and every downstream migration handoff; never rename, omit, or regenerate it.
- Preserve `Changed Files`, `Trace IDs`, `Commands and Results`, `Evidence`, `Unknowns`, and `Verdict`.
- Preserve `Change Hygiene` with file kind, edited region/symbol, formatter command, and unrelated-diff verdict for every changed file.
- Preserve `Blocker gốc` with the native verdict, command/capability, observed error, and evidence reference even if the orchestrator later appends an automation waiver.
- For a routed `result: blocked` artifact whose Activation Slice and immediate-predecessor handoff are otherwise valid, emit exactly one `Domain Blocker` table with non-placeholder `Blocker` and `Evidence Reference` values; omit that section for non-blocked output.
- Every changed-file row names one approved unit and at least one trace ID.
- On baseline-waiver resume, preserve `Approved Baseline Waiver` and `Step 10 Waiver Resume State`; without target source mutation evidence the result is `blocked`.

## Quick reference

| Condition | Action |
|---|---|
| Approved unit and resolved commands | TDD in isolated worktree |
| Later greenfield unit and approved foundation baseline | Skip bootstrap; implement against that baseline |
| Incremental architecture conflict | Stop and request approved conflict decision |
| Required command unresolved | Block at human gate |
| Executable/capability absent before command start | Record native blocker and verbatim evidence; stop |
| Command started and returned failure | Record executed failure; stop without waiver |
| Extra untraced change appears | Remove or separately approve |

## Common mistakes

- Implementing a whole wave because one unit is approved.
- Bootstrapping or redesigning an incremental target.
- Running a familiar command not supported by profile, repository, detection, or gate.

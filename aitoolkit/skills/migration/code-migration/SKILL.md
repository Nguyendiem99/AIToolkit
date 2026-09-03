---
name: code-migration
description: Use when an approved migration work item is ready for isolated, structurally gated, traceable implementation against an approved mode-aware plan.
---

# Migration 10 — Code Migration

**Core principle:** Implement exactly one approved work item only after its master scope, canonical adapter, target structure, and production activation path pass the non-waivable structural gate; preserve mode constraints and prove behavior with traceable tests.

**REQUIRED SUB-SKILLS:** Use `superpowers:using-git-worktrees`, `superpowers:writing-plans`, `superpowers:executing-plans`, and `superpowers:test-driven-development`.

## Ngôn ngữ artifact

Nhận `artifact_language` do orchestrator truyền. Hiện chỉ hỗ trợ `artifact_language: vi`: viết tiêu đề, tóm tắt, blocker, khuyến nghị và nội dung gate bằng tiếng Việt UTF-8; giữ nguyên mọi field machine-readable, enum, ID, path, command, log, trace field và cột bảng contract.

## Inputs

The orchestrator provides `RUN_DIR`, profile, project pack, source/target, one predecessor path, exact `master_spec_id`/revision, exact `master_plan_id`/revision, one approved `work_item_id`, its canonical delivery-adapter evidence, conformance matrix, the explicit external technical-design approval artifact path, exemplar-read evidence, planned file tree and boundaries, production activation evidence, `foundation_baseline_id` when applicable, and the resolved per-run `automation_mode`, alongside that path. A `migration_unit_id` is present only when the selected adapter kind is `migration-unit`. On an incremental baseline-waiver resume, it also provides the exact approved waiver artifact.

`Immediate predecessor artifact = exactly one orchestrator-provided path`.

Preserve the immediate predecessor Activation Slice envelope without loss: keep the complete case-sensitive slice ID set, Applicability, all nine canonical seam rows, and every predecessor Source Reference and Trace ID. Source Reference enrichment is append-only, and predecessor Trace IDs remain a subset of successor Trace IDs. Never reconstruct it from cumulative artifacts.
Never load cumulative artifacts or create private state. Resolve these references explicitly; never scan a directory to infer a master revision, work item, selector, exemplar, or design.

The approved Activation Slice is part of the selected-unit input. Read `aitoolkit/contracts/activation-slice.md` as the sole definition source and preserve the same stable slice ID, every seam row, and trace IDs; do not reconstruct or narrow it from the implementation diff.

## Structural pre-edit gate

Run this gate before the legacy Entry gate, incremental runtime baseline gate, worktree implementation plan, TDD, or target edit. Validate in this exact fail-fast order:

1. responsibility contract: resolve explicit approved design and plan revisions, validate the canonical v1 File Responsibility Matrix and Verification Ownership Matrix, resolve the exact selected work-item Responsibility Owner References (including generic adapters without inventing `UNIT-*`), and reject absent exemplar/deviation authority before RED/TDD, baseline capture, worktree mutation, or target edit;
2. master scope: resolve the explicit master-spec/master-plan paths without directory scanning, then match exact approved IDs/revisions, one approved `work_item_id`, membership, acceptance and approval in that external current master-plan revision; a well-formed report row is never authority by itself;
3. canonical adapter: resolve exactly one external Task 5 selector row for the work item and compare all 13 selector fields ordinally, including acceptance, trace IDs, mode, design revision, parent/decomposition fields and exact non-`none` external ID; also bind relevant Work Item acceptance, trace and delivery-adapter fields. `migration-unit` additionally resolves the cited external approved step-08 canonical unit plus its work-item trace, while generic/`none` adapters retain their exact external canonical selection;
4. conformance matrix: resolve the explicit external Task 6 design path using only its bounded first front matter and preserve its exact canonical `draft/complete` schema without `approval_source`; never mutate Task 6 to approved. Resolve the separately supplied external approval artifact and require exact global migration lifecycle front matter (`step_id`, `status: approved`, `result: complete`, `approval_source: human`, `produced_at`), rejecting missing, auto, auto-waive, extra or malformed fields. Its sole approval row binds exact design ID/revision, normalized SHA-256 content digest, Tech Lead decision, approval reference and approved status. Report values or a derived approval string are never authority. Bind every report deviation exactly to the Task 6 `Approved Structural Deviations` row (including conflict, decision and approval); do not add fields or approval tables to Task 6;
5. exemplar read: resolve the explicit external discovery path and require every report row to exactly match its real path, fully inspected symbols and evidence for all applicable canonical concerns with `read-complete` status;
6. planned file tree and target boundaries: compare the complete actual mapping against the external approved planned tree; provider, router, localization, subscription and lifecycle owner/mechanism must equal the external approved design evidence; direct widget-to-service/router edges are forbidden for literal, identifier, qualified, member and call forms, without classifying presenter/controller identifiers as widgets;
7. production activation path: when applicable, derive registration exactly as `<router Owner Path/Symbol> @ <construct.Output>` and production evidence as `<test.Output> @ <test.Source Reference>` from the canonical Task 6 boundary/slice rows; require a runtime chain containing both subscription and lifecycle with `PASS`. Never add private key-value evidence to Task 6. `not-applicable-approved` requires an explicit Tech Lead decision/reference and exact `not-applicable` sentinel fields;
8. assurance states: `architecture_conformance_state` and `selector_schema_state` are independently `PASS` before runtime baseline classification.

Any responsibility, verification ownership, master, architecture, exemplar, selector, schema, tree, boundary, deviation, or activation failure yields `status: draft`, `result: blocked`, and stops before edit. These failures never enter the environment-waiver classifier. Only after all checks pass may incremental runtime baseline collection, worktree/plan/TDD, and target editing begin. After implementation, record Actual File Responsibility Matrix and Actual Verification Ownership Matrix with source/diff evidence; self-attestation is not final semantic PASS, and any planned-versus-actual mismatch remains draft/blocked.

Record the gate in `Master Scope Context`, `Canonical Adapter Evidence`, `Conformance Matrix Reference`, `Responsibility Plan Reference`, `Responsibility Owner References`, `Exemplar Read Evidence`, `Actual File Tree vs Planned File Tree`, `Actual File Responsibility Matrix`, `Actual Verification Ownership Matrix`, `Architecture Responsibility Verdicts`, `Target Boundary Conformance`, `Exemplar Deviations`, `Production Activation Path Evidence`, and `Assurance State`. `Responsibility Plan Reference` binds the explicit approved step-08 path and revision; the selected owner row must match that plan exactly. Tables use unique headings, exact columns, strict single-pipe framing and exact cardinality; malformed, filtered, doubled-pipe, unknown/extra-row or mixed-sentinel evidence blocks. A new abstraction requires a resolved decision and `approval:TECH-LEAD-*`; otherwise block.

## Entry gate

Resolve the exact approved `work_item_id` and its one canonical adapter selection; never select implicitly. When `Adapter Kind = migration-unit`, resolve `migration_unit_id` and require exactly one approved migration unit whose acceptance, mode/policy, design revision, and trace IDs agree. For `task | story | package | phase | milestone | none`, keep the canonical adapter evidence and work-item trace without inventing or requiring a migration-unit ID.

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

1. Read `aitoolkit-schemas`, both scope/conformance contracts, `aitoolkit/contracts/activation-slice.md`, `shared/change-hygiene.md`, explicit inputs, and `aitoolkit/templates/migration/implementation-report.md`.
2. Run the Structural pre-edit gate in its exact order. On any failure, write the structured evidence as `status: draft`, `result: blocked`, and stop without runtime-waiver classification or target edit.
3. Validate the selected adapter's legacy Entry gate and approved Activation Slice. For `migration-unit`, retain `migration_unit_id`; for any other adapter, do not invent one. Treat the shared scope, formatting, final-diff, and commit-boundary rules as mandatory.
4. Resolve required commands in this command resolution order: `explicit profile -> existing project scripts/config -> marker detection -> human gate`. Use repository commands verbatim; never invent or translate one.
5. In incremental mode, capture a comparable pre-change regression baseline against the unchanged target and preserve its evidence reference. On a valid Approved baseline-waiver resume, skip only that collection and cite the exact approved waiver evidence as `Baseline Reference`. Greenfield records `not-applicable`.
6. After baseline capture, evaluate the pre-mutation gate for runtime evidence or validate the exact Approved baseline-waiver resume. An unresolved command or failed/non-comparable baseline capture records `result: blocked` plus its native blocker evidence before any edit; invalid resume evidence also blocks. A runtime waiver cannot change structural assurance states.
7. Use `superpowers:using-git-worktrees` to create or verify an isolated worktree and branch without editing the target, then use `superpowers:writing-plans` to translate only the approved work item into steps and review checkpoints.
8. Within `superpowers:executing-plans`, apply `superpowers:test-driven-development`: write an acceptance test, observe RED, implement the minimum, observe GREEN, then refactor while staying green.
   When a real source or verification file carries responsibility-contract metadata, emit the contract's language-valid semantic marker form: exact whole-line `// arc:<payload>` in the documented slash-comment languages or `# arc:<payload>` in the documented hash-comment/PowerShell languages. Every owner uses exact paired `@ownership-begin RESP-*` / `@ownership-end RESP-*` delimiters with the same ID; ranges never nest or overlap. Put module imports/re-exports, docstrings, future/directive prologues, package/namespace/preprocessor declarations, attributes, shared wiring, and every owned declaration/body inside exactly one range. Use the sentinel for every `@...`, `route ...`, and `scenario ...` payload; never infer range extent from braces, indentation, a first symbol, the next owner, or EOF.
9. Resolve the external Activation Slice contract before editing: report and external authority must have exact Slice ID set/cardinality equality in both directions, including every `not-applicable-approved` group; every `ACT-[0-9]{3}` slice has exactly the nine canonical seams in order, legal disposition/status state, and router/async evidence. Derive the production handoff only from the canonical router boundary plus construct/test fields; never add private evidence keys to Task 6. Preserve each row exactly except canonical `Source Reference` enrichment (`<predecessor>; <non-whitespace evidence>`); predecessor Trace IDs are a non-empty subset of successor Trace IDs, which may append only Work Item-authorized IDs. Record each changed-file row and each test by `Work Item ID`, plus a structured `Activation Slice ID`, `Seam`, and non-empty canonical `Trace IDs` subset resolved against both the approved work item and the exact predecessor seam; repeat rows for multi-seam files or tests. A truthful `draft/blocked` pre-mutation artifact may omit both implementation-evidence sections and must stop before edit; normal `draft/complete` and `approved/complete` output requires real changed/test evidence. Unit-specific IDs are recorded only inside conditional `Selected Migration Unit` evidence when the adapter is `migration-unit`; generic adapters never invent `UNIT-*`. Also record whether each file is `new` or `existing`, edited regions/symbols, actual/planned tree evidence, boundary/activation evidence, and every formatter command. Inspect the final diff, remove all untraced or formatting-only changes, and block unrelated whole-file churn. Capture commands, sources, exit codes, and Evidence. Local checkpoint commits are non-delivery history; this work item must become one final delivery commit. Do not upload, merge, or mutate unrelated work.

## Evidence and Unknowns

Evidence includes approval, conformance, RED/GREEN output, commands, changes, and trace IDs. Unknowns identify missing evidence.

## Hợp đồng đầu ra

- File: `<RUN_DIR>/10-implementation-report.md`.
- Front matter: `step_id: 10-code-migration`, canonical lifecycle, `produced_at`; normal implementation output may be `draft/complete`, approved output may be `approved/complete` with canonical `approval_source`, and pre-edit failure remains `draft/blocked` with no fabricated changes/tests.
- Preserve the exact `Master Scope Context`, canonical adapter row, conformance-matrix approval, eight exemplar-read rows, actual/planned file mapping, five target-boundary rows, deviation dispositions, activation evidence, and three independent assurance states.
- `architecture_conformance_state` and `selector_schema_state` must both be `PASS` for editing; neither can be waived. Runtime `WAIVED` does not alter them.
- Preserve `Selected Migration Unit` with `migration_unit_id`, plan reference, approval reference, mode constraint, `Bootstrap Scope`, Foundation Baseline ID, foundation baseline reference, foundation baseline approval reference, baseline reference, and trace IDs only when `Adapter Kind = migration-unit`; omit that section for every other canonical adapter.
- Preserve `Activation Slice` with canonical `ACT-[0-9]{3}`, all nine canonical seam rows in order, legal states, and exact fields except allowed append-only Source Reference enrichment.
- Every changed-file row and every test evidence record must link to the approved Activation Slice seam and its trace IDs.
- Each link carries non-empty canonical Trace IDs that are a subset of both seam and Work Item authority; whole-set equality is not required.
- Those rows use the exact approved `Work Item ID`; generic adapters contain no invented unit ID.
- Use the structured changed-file and `Activation Slice Test Evidence` tables; prose-only linkage is invalid.
- Preserve the exact resolved selector as `foundation_baseline_id` in the implementation artifact and every downstream migration handoff; never rename, omit, or regenerate it.
- Preserve `Changed Files`, `Trace IDs`, `Commands and Results`, `Evidence`, `Unknowns`, and `Verdict`.
- Preserve `Change Hygiene` with adapter-aware assurance identity for every changed Git path: `Task / Unit` is the exact selected Migration Unit ID for `migration-unit`, otherwise the approved current Work Item ID. Reconcile the pinned status exactly as `A/C = new`, `M/R = existing`, or `D = deleted`; also preserve edited region/symbol, formatter command, and unrelated-diff verdict. A `deleted` row has no final-tree path requirement and must carry exact `source:<task-base SHA>:<path>; diff:<task-base SHA>..<final-tree SHA>:<path>` base/removal evidence. A responsibility block removed from a surviving file uses `existing` with that same evidence pair for the removed owner. Omitted, stale, foreign, or status-mismatched evidence blocks output.
- Preserve `Blocker gốc` with the native verdict, command/capability, observed error, and evidence reference even if the orchestrator later appends an automation waiver.
- For a routed `result: blocked` artifact whose Activation Slice and immediate-predecessor handoff are otherwise valid, emit exactly one `Domain Blocker` table with non-placeholder `Blocker` and `Evidence Reference` values; omit that section for non-blocked output.
- Every changed-file row names one approved work item and at least one trace ID.
- On baseline-waiver resume, preserve `Approved Baseline Waiver` and `Step 10 Waiver Resume State`; without target source mutation evidence the result is `blocked`.

## Quick reference

| Condition | Action |
|---|---|
| Approved work item, structural PASS, and resolved commands | TDD in isolated worktree |
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

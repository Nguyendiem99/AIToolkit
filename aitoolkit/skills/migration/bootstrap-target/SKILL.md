---
name: bootstrap-target
description: Use when an approved greenfield migration plan requires creation of its initial target structure before implementation units can run.
---

# Migration 09 — Bootstrap Target

**Core principle:** Bootstrap creates only the greenfield foundation; it never redesigns the target or rewrites an incremental baseline.

## Ngôn ngữ artifact

Nhận `artifact_language` do orchestrator truyền. Hiện chỉ hỗ trợ `artifact_language: vi`: viết tiêu đề, tóm tắt, blocker, khuyến nghị và nội dung gate bằng tiếng Việt UTF-8; giữ nguyên mọi field machine-readable, enum, ID, path, command, log, trace field và cột bảng contract.

## Inputs

The orchestrator provides `RUN_DIR`, project profile, project pack, source/target locations, one explicit predecessor artifact path, and `migration_unit_id` alongside that path.

`Immediate predecessor artifact = exactly one orchestrator-provided path`.

## Activation Slice responsibilities

Read `aitoolkit/contracts/activation-slice.md` as the sole canonical definition. Preserve the immediate predecessor Activation Slice envelope without loss: keep the complete case-sensitive slice ID set, Applicability, all nine canonical seam rows, and every predecessor Source Reference and Trace ID. Source Reference enrichment is append-only, and predecessor Trace IDs remain a subset of successor Trace IDs. Never reconstruct it from cumulative artifacts.

The selected plan is the only Activation Slice source for bootstrap. Preserve the envelope while replacing only the approved foundation sentinels owned by this step; missing or changed activation evidence blocks before target mutation.

Use only IDs and approvals forwarded by that artifact; never load cumulative artifacts.

## Mode gate

- Proceed only for the exact pair `greenfield` / `design-new`.
- Resolve `migration_unit_id` against the immediate predecessor migration plan. Require exactly one approved bootstrap-scoped migration unit with matching mode/policy, design revision, trace IDs, acceptance, plan reference, and approval reference.
- Require the selected greenfield unit's `Bootstrap Scope = required`. Missing, invalid, `not-required`, or scope mismatch yields `result: blocked` before mutation; never choose an eligible unit implicitly.
- Require the selected plan row to carry `Foundation Baseline ID = pending-bootstrap` and `Foundation Approval Reference = pending-step09-approval`, and verify that no approved foundation baseline exists. This required foundation route does not require an existing foundation baseline before step 09; any approved `FOUNDATION-*` selector on the same required row is a scope mismatch and blocks.
- Require the forwarded Tech Lead design approval for the selected unit and design revision.
- For `incremental`, `preserve-existing`, unknown, or mismatched values, refuse execution with `result: blocked`; incremental uses its existing target.

## Procedure

1. Read `aitoolkit-schemas`, the profile, project pack, predecessor artifact, and `aitoolkit/templates/migration/bootstrap-report.md`.
2. Validate unit ID, mode, design revision, `Bootstrap Scope`, trace IDs, plan reference, and approval reference before changing the target.
3. Resolve any required command or generator through `explicit profile -> existing project scripts/config -> marker detection -> human gate`. Use repository-defined commands verbatim; never invent a technology-specific command.
4. If resolution reaches the human gate, record the missing command and block before mutation.
5. Create only the directories, configuration, entry points, and dependency declarations named by the approved bootstrap unit. Do not implement feature behavior.
6. Run the resolved bootstrap checks, capture command, source, exit code, and output Evidence verbatim.
7. Record changed paths with unit and trace IDs. Replace the plan's `pending-bootstrap` sentinel in the draft by emitting exactly one stable `FOUNDATION-*` record with `Source Migration Unit ID` equal to the selected `migration_unit_id`, its target baseline reference, the `pending-step09-approval` sentinel as its Foundation Baseline Approval Reference, `Approval Status = pending-approval`, design revision, freshness evidence, and changed paths. The step-09 gate atomically changes the artifact front matter to approved, replaces the pending reference in both `Selected Migration Unit` and `Bản ghi baseline nền tảng` with the exact approved bootstrap artifact reference, and sets `Approval Status = approved`; only that finalized record is usable.
8. Preserve the selected unit ID, plan/approval references, mode constraint, `Bootstrap Scope`, Foundation Baseline ID, foundation baseline reference, foundation baseline approval reference, baseline reference `not-applicable`, and full trace IDs. Unapproved additions block.

## Evidence and Unknowns

Evidence identifies mode/policy, approved design revision, selected unit, plan/approval references, command source, changed paths, and outputs. Unknowns identify missing approvals, commands, environment, or scope.

## Hợp đồng đầu ra

- File: `<RUN_DIR>/09-bootstrap-report.md`.
- Front matter: `step_id: 09-bootstrap-target`, `status: draft`, `result: complete | blocked`, `produced_at`.
- Preserve `Activation Slice` from the selected plan predecessor with the identical slice set, Applicability, all nine rows, Source Reference evidence, and Trace IDs.
- Preserve `Selected Migration Unit` with `migration_unit_id`, plan reference, approval reference, mode constraint, `Bootstrap Scope`, `Foundation Baseline ID`, foundation baseline reference, foundation baseline approval reference, baseline reference `not-applicable`, and trace IDs.
- Preserve `Bootstrap Results`, `Evidence`, `Unknowns`, and `Verdict`.
- For `draft/complete` or `approved/complete`, preserve one `Bản ghi baseline nền tảng` containing the `FOUNDATION-*` ID, matching Source Migration Unit ID, target baseline reference, Foundation Baseline Approval Reference, approval status, and evidence. The draft is pending; the approved artifact carries the atomic gate transition described above.
- A blocked refusal records no target mutation, retains the canonical pending selected-unit tuple, omits the entire `Bản ghi baseline nền tảng` section, and emits exactly one `Domain Blocker` table with non-placeholder `Blocker` and `Evidence Reference` values.

## Quick reference

| Condition | Action |
|---|---|
| Greenfield and one selected approved bootstrap unit | Bootstrap approved scope |
| Incremental target | Refuse; orchestrator skips this step |
| Command unresolved | Human gate, blocked |
| Feature behavior requested during bootstrap | Leave for implementation unit |

## Common mistakes

- Bootstrapping because the incremental target looks untidy.
- Treating a design proposal as approval.
- Selecting a bootstrap unit when the selector is missing or ambiguous.
- Inventing a command from personal technology knowledge.

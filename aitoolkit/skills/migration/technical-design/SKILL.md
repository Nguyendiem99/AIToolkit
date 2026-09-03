---
name: technical-design
description: Use when resolved migration gaps and conflicts must become a mode-aware target design before implementation planning.
---

# Migration 07 — Technical Design

**Core principle:** Mode and architecture policy constrain the design; preference, deadline, and familiarity do not override target evidence or approval.

## Ngôn ngữ artifact

Nhận `artifact_language` do orchestrator truyền. Hiện chỉ hỗ trợ `artifact_language: vi`: viết tiêu đề, tóm tắt, blocker, khuyến nghị và nội dung gate bằng tiếng Việt UTF-8; giữ nguyên mọi field machine-readable, enum, ID, path, command, log, trace field và cột bảng contract.

## Inputs

The orchestrator provides `RUN_DIR`, project profile, project pack, source/target locations, and one explicit predecessor artifact path.

`Immediate predecessor artifact = exactly one orchestrator-provided path`.

Preserve the immediate predecessor Activation Slice envelope without loss: keep the complete case-sensitive slice ID set, Applicability, all nine canonical seam rows, and every predecessor Source Reference and Trace ID. Source Reference enrichment is append-only, and predecessor Trace IDs remain a subset of successor Trace IDs. Never reconstruct it from cumulative artifacts.
Use stable trace IDs forwarded by that artifact; do not discover or load a cumulative numbered artifact list.

## Activation Slice responsibilities

Read `aitoolkit/contracts/activation-slice.md` as the sole definition source. Preserve the same stable Activation Slice ID, every seam row, and all trace IDs from the immediate predecessor; enrich only design-owned evidence and do not reproduce the canonical schema.

Resolve the end-to-end data flow and select exactly one approved router policy. When activation state can arrive or change asynchronously, record initial loading, update/watch, reselection, failure behavior, and lifecycle test evidence, plus state preservation/reset behavior. Unresolved router ownership, async behavior, test strategy, or any missing seam that prevents activation keeps `status: draft` and `result: blocked`; the design is not executable or complete until the whole Activation Slice is activatable end to end.

## Mode policy

| Profile values | Required behavior |
|---|---|
| `greenfield` / `design-new` | Propose a new architecture from requirements, constraints, and Evidence. Record alternatives and the selected proposal. Stop at the `Tech Lead gate`; bootstrap and implementation remain blocked until explicit Tech Lead approval. |
| `incremental` / `preserve-existing` | Inspect the target baseline and design for target conformance. Preserve existing architecture, module boundaries, conventions, and extension points. A conflicting requirement becomes a traced conflict requiring an approved owner decision; it is not permission to redesign. No bootstrap is allowed. |
| Any unknown, unsupported, or mismatched combination | Record the invalid combination and `result: blocked`; do not propose an executable design. |

An approval applies only to the cited design revision and trace IDs. A meeting, deadline, or implementation request is not approval.

## Procedure

1. Read `aitoolkit-schemas`, `aitoolkit/contracts/activation-slice.md`, the profile, project pack, predecessor artifact, and `aitoolkit/templates/migration/technical-design.md`.
2. Validate mode/policy before designing. Forward affected requirement, inventory, mapping, discovery, gap, and conflict trace IDs.
3. For `design-new`, describe boundaries, responsibilities, data/control flow, interfaces, dependencies, and acceptance constraints without assuming a technology.
4. For `preserve-existing`, cite target Evidence for each proposed extension and show conformance; route architecture changes to an approval conflict.
5. Put unsupported assumptions in `Unknowns`. Any unknown that blocks architecture, scope, or acceptance makes the result blocked.
6. Write the artifact and request the Tech Lead gate when approval is required.

## Evidence and Unknowns

Evidence must locate the profile decision, target observations, requirement/constraint sources, trace IDs, and approval identity/revision. Unknowns name missing evidence, owner, or decision and the downstream work it blocks.

## Hợp đồng đầu ra

- File: `<RUN_DIR>/07-technical-design.md`.
- Front matter: `step_id: 07-technical-design`, `status: draft`, `result: complete | blocked`, `produced_at`.
- Preserve the template sections `Architecture`, `Evidence`, `Unknowns`, and `Verdict`.
- Preserve `Activation Slice` with the same ID, all seam rows, and trace IDs; add the resolved data flow, router policy, async lifecycle, and test-strategy evidence owned by this step.
- For a routed `result: blocked` artifact whose Activation Slice and immediate-predecessor handoff are otherwise valid, emit exactly one `Domain Blocker` table with non-placeholder `Blocker` and `Evidence Reference` values; omit that section for non-blocked output.
- `complete` means the design is ready for approval, not that approval has occurred. Only the orchestrator may advance an explicitly approved revision.

## Quick reference

| Pressure | Decision |
|---|---|
| Implement greenfield before approval | Block at Tech Lead gate |
| Incremental requirement suggests a different architecture | Preserve target; open traced conflict |
| Mode and policy disagree | Block |

## Common mistakes

- Treating `design-new` as permission to hardcode a familiar stack.
- Replacing incremental architecture because the proposed design looks cleaner.
- Treating a draft or verbal request as Tech Lead approval.

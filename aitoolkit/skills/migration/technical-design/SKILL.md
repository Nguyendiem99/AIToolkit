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

Đọc `aitoolkit/contracts/target-structure-conformance.md` như nguồn duy nhất cho concern, cột matrix và semantics deviation; không tái định nghĩa contract trong skill này.

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

## Target structure conformance responsibilities

Với `preserve-existing`, lập `Target Structure Conformance Matrix` với exact columns và exact set/cardinality tám concern do canonical target-structure contract định nghĩa; reject missing, duplicate và invented concern. Mỗi row phải dùng working exemplar thật dạng `<path>#<qualified-symbol>` và structured observed evidence `path=<same exemplar>; symbols=<explicit list>; boundary=<name>; mechanism=<name>`; presentation thêm `wrapper=<symbol>`. Phrase framework/MVVM/architecture/state-management dù đi cùng proposed path vẫn không thay thế structured evidence.

Trước `Work Item Trace`, ghi đúng một `Approved Master Plan Evidence` snapshot: canonical plan ref/ID/revision, `status: approved`, exact Acceptance, Trace IDs, Delivery Adapter, decomposition, Tech Lead approval và evidence reference. Snapshot không phải authority: exact `master-plan.md#PLAN-*` phải resolve file `master-plan.md` bên dưới run root. File external phải có bounded first front matter đúng canonical `migration-master-plan`, exact ID/revision/status approved và linked master-spec scope; ID sau `#` là identity trong front matter, không phải heading riêng.

Resolve đúng một cited row trong canonical `## Work Items` table với exact columns từ migration-scope contract. Row phải có current approved `Approval Reference` trong `Approval Record`, current `Revision History`, và exact-match snapshot/trace cho Acceptance, Trace IDs, Delivery Adapter. Missing/draft/stale artifact, wrong front matter, duplicate/missing work item, stale row, hoặc coherent local forgery đều block. Giữ canonical `WORK-<SCOPE>-*`, `master-plan.md#PLAN-<SCOPE>-*`, positive revision, unique `REQ-* | SC-* | AC-*`; scope phải bằng nhau.

Decomposition dùng canonical YAML `decomposition:` record trong `Work Items`, với exact `parent_work_item_id`, `child_work_item_ids`, `decision_reference` của current approved revision; không tạo alternate table. Child trace phải resolve đúng một record, parent và tất cả child phải là canonical Work Items của revision và Revision History phải liệt kê parent/child bị ảnh hưởng. Nếu không decomposition, cả snapshot và trace dùng exact sentinel `not-applicable` và cited child không được có decomposition record.

Mỗi `Conforms = no` phải dùng canonical `DEV-*` và trỏ đúng một row trong `Approved Structural Deviations` có `CONFLICT-*`, `resolved:DECISION-<ID>: <nội dung cụ thể>` và `approval:TECH-LEAD-<ID>`. Reject placeholder semantic ở bất kỳ vị trí nào (`pending`, `unknown`, `none`, `TBD`, `review`, ...). Presentation concern luôn cần cả observed/proposed wrapper token; wrapper nhận full qualified symbol và so ordinal toàn bộ segments, `yes` exact-match, `no` chỉ được khác qua approved deviation.

`Planned File Tree` liệt kê mỗi file và qualified symbol sẽ tạo/sửa. Path grammar chấp nhận root file (`main.dart#App`), `/` hoặc `\`, optional drive/absolute root; reject blank, malformed và `..` traversal. So sánh matrix/planned bằng canonical path normalize separator nhưng giữ nguyên artifact text; unique path sets phải exact, không thiếu/unrelated/duplicate. `Provider/Router/Localization/Subscription Boundaries` ghi riêng provider, router, localization, subscription và lifecycle owner với input/output/policy/evidence end-to-end.

Hợp đồng đầu ra giữ `Approved Master Plan Evidence`, `Work Item Trace`, `Target Structure Conformance Matrix`, `Approved Structural Deviations`, `Planned File Tree`, và `Provider/Router/Localization/Subscription Boundaries`; complete chỉ khi approved-plan binding, coverage/boundary/path relation đầy đủ và mọi non-conforming row có approved decision.

## Responsibility and verification ownership

Read `aitoolkit/contracts/file-responsibility-conformance.md` as the sole authority for responsibility/verification columns, enums, sentinel semantics, and diagnostics; do not copy or redefine that contract here. Consume the approved discovery classification together with its exact authority and immutable evidence. A discovery agent's opinion is never design authority.

Immediately after `Planned File Tree`, emit exactly one `File Responsibility Matrix` and exactly one `Verification Ownership Matrix` with the canonical 20/11 column order. The set of `(Planned Path, Planned Symbol)` tuples and the responsibility owner tuples must be exact and bidirectional. `Owner Symbol` is the primary public owner or module export; `Public Symbols` may list several feature-local public symbols, while private helpers do not get separate rows.

Keep owned capability IDs separate from requirement, acceptance, mapping, and work-item trace IDs. Multiple traces for one capability are not an aggregate owner. A multi-capability owner needs an exact approved deviation and non-placeholder Tech Lead approval evidence. `Atomic Boundary ID` is only valid for an atomic owner. A shared foundation owns only its shared capability and cannot contain concrete registration, route, handler, or feature-specific effect.

For incremental work, preferred exemplar authority uses the validated target exemplar; compatibility-only, legacy-debt, and no-equivalent structures require the canonical approved-deviation route. Legacy debt is never propagated as new native structure. For greenfield no-equivalent work, use approved greenfield design authority, not a fabricated deviation. Every non-test production responsibility has production-bound verification coverage in both directions. `not-applicable-approved` is a controlled verification disposition only for the canonical config/manifest/generated/schema/build route; it is forbidden for behavior, routing, lifecycle, external effects, destructive action, and production composition.

## Evidence and Unknowns

Evidence must locate the profile decision, target observations, requirement/constraint sources, trace IDs, and approval identity/revision. Unknowns name missing evidence, owner, or decision and the downstream work it blocks.

## Hợp đồng đầu ra

- File: `<RUN_DIR>/07-technical-design.md`.
- Front matter: `step_id: 07-technical-design`, `status: draft`, `result: complete | blocked`, `produced_at`, and canonical `revision: DESIGN-*@<positive integer>`.
- Preserve the template sections `Architecture`, `Evidence`, `Unknowns`, and `Verdict`.
- Preserve `Activation Slice` with the same ID, all seam rows, and trace IDs; add the resolved data flow, router policy, async lifecycle, and test-strategy evidence owned by this step.
- Include the responsibility-contract v1 front-matter block and the two canonical ownership matrices immediately after `Planned File Tree`; a missing, mixed, or unsupported responsibility contract version blocks the design.
- For a routed `result: blocked` artifact whose Activation Slice and immediate-predecessor handoff are otherwise valid, emit exactly one `Domain Blocker` table with non-placeholder `Blocker` and `Evidence Reference` values; omit that section for non-blocked output.
- `complete` means the design is ready for approval, not that approval has occurred. Only the orchestrator may advance an explicitly approved revision. The approved design artifact's bounded `revision` field is the sole authority plan-waves may cite; plan-local or master-plan revision is never a substitute.

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

---
name: plan-waves
description: Use when an approved mode-aware migration design must be divided into dependency-ordered, reviewable implementation units.
---

# Migration 08 — Plan Waves

**Core principle:** Execution scope is an approved migration unit with traceable acceptance, never an informal feature request or an entire migration at once.

## Ngôn ngữ artifact

Nhận `artifact_language` do orchestrator truyền. Hiện chỉ hỗ trợ `artifact_language: vi`: viết tiêu đề, tóm tắt, blocker, khuyến nghị và nội dung gate bằng tiếng Việt UTF-8; giữ nguyên mọi field machine-readable, enum, ID, path, command, log, trace field và cột bảng contract.

## Inputs

The orchestrator provides `RUN_DIR`, project profile, project pack, source/target locations, and one explicit predecessor artifact path.

`Immediate predecessor artifact = exactly one orchestrator-provided path`.

Preserve the immediate predecessor Activation Slice envelope without loss: keep the complete case-sensitive slice ID set, Applicability, all nine canonical seam rows, and every predecessor Source Reference and Trace ID. Source Reference enrichment is append-only, and predecessor Trace IDs remain a subset of successor Trace IDs. Never reconstruct it from cumulative artifacts.
Use only stable IDs and decisions forwarded by that artifact; do not load a cumulative numbered artifact list.

## Work item and decomposition trace

Nhận orchestrator-provided `work_item_id`, `master_plan_ref`, `master_plan_revision` và validate đúng một `Work Item Trace` row liên tục từ steps 04, 05, 06 và 07. Preserve `Work Item ID`, `Parent Work Item ID`, `Master Plan Reference`, `Master Plan Revision`, `Acceptance`, `Mode Constraint`, full append-only Trace IDs, approved `Design Revision` và `Decomposition Decision Reference`.

Child không được xuất hiện lần đầu tại plan-waves. Với child, từng step 04–07 phải chứa cùng Parent Work Item ID và Decomposition Decision Reference; missing/bypass/mismatch làm `result: blocked`. Parent selector chỉ được gắn sau khi row step 08 của child được duyệt.

Current master plan phải có `status: approved`. `work_item_id` phải resolve đúng một canonical `Work Items` row trong revision đó; child còn phải resolve đúng một parent row và đúng một approved decomposition record có cùng parent, child, decision và master-plan revision. Mọi canonical step 04–08 được dùng để cấp selector phải có `status: approved` và `result: complete`.

Mỗi canonical Work Item trong scope, kể cả kind `none`, có đúng một `Delivery Adapter Selection`; zero-selection và duplicate-selection đều block. Mỗi cặp adapter kind/external selector chỉ thuộc một Work Item. Adapter `migration-unit` còn yêu cầu external ID đúng `UNIT-*` format, resolve đúng một ordered unit row và một `Work Item Adapter Trace` row, đồng thời giữ exact Dependencies equivalence giữa canonical master Work Item và unit plan cùng mode, acceptance, trace và design equivalence.

Với generic child có adapter kind khác `none`, `Parent Selector` phải bằng exact external selector trong chính adapter selection của canonical parent Work Item đã nêu trong approved decomposition. Nếu parent adapter là `none`, canonical parent-selector semantics là `not-applicable`; không được phát minh external parent ID. Với child adapter kind `none`, mọi selector field gồm `Parent Selector` luôn là `not-applicable` dù parent dùng adapter nào; quan hệ cha-con được ràng buộc bằng `Parent Work Item ID`, current master Work Item row và exact approved decomposition record, không bằng external selector của parent.

`UNIT-* is the canonical migration-unit adapter ID, not a generic work-item taxonomy`. Project dùng adapter `none`, `task`, `story`, `package`, `phase` hoặc `milestone` giữ nguyên generic `WORK-*`; plan-waves không tạo `UNIT-*` cho chúng.

Generic adapters preserve Work Item Trace through steps 04-08. `none` giữ toàn bộ selector fields là `not-applicable`; `task`, `story`, `package`, `phase` và `milestone` giữ external ID, authority, authority revision, approval reference và parent-selector semantics của adapter thay vì đi qua migration-unit plan.

## Activation Slice responsibilities

Read `aitoolkit/contracts/activation-slice.md` as the sole definition source. Preserve the same stable Activation Slice ID, all seam rows, and trace IDs from the immediate predecessor without reproducing the canonical schema. Order units by seam dependencies so upstream activation evidence and ownership decisions precede dependent construction, rendering, consumer, and test work.

A unit may implement only part of a slice when every remaining required seam is `deferred-approved` with its Decision Reference and destination Deferred Unit ID. Acceptance must not declare the module `activatable` while any required seam is `deferred-approved`. A missing dependency, decision, destination unit, seam row, or trace that can prevent activation keeps `status: draft` and `result: blocked`, never partial.

## Procedure

1. Read `aitoolkit-schemas`, `aitoolkit/contracts/activation-slice.md`, the profile, project pack, predecessor artifact, and `aitoolkit/templates/migration/migration-plan.md`.
2. Require a non-blocked technical design. For `greenfield` / `design-new`, require explicit Tech Lead approval of the cited revision. For `incremental` / `preserve-existing`, proceed through target conformance without a Tech Lead gate; only a documented architecture conflict requires approval from its owner. Missing required greenfield approval or unresolved conflict approval yields `result: blocked`.
3. Chỉ khi selected work item dùng delivery adapter `migration-unit`, divide design thành dependency-ordered waves và định nghĩa canonical row. Define one `UNIT-###` as one independently reviewable Gerrit change that is independently implementable, testable, and revertible, with one final delivery commit; không gộp hai units trong một delivery change.
4. Với `migration-unit`, assign stable `UNIT-###` adapter ID và forward complete trace ID set: requirements, inventory, mappings, discovery, gaps/conflicts và design decisions. Giữ `Work Item ID`, `Parent Work Item ID`, `Master Plan Reference`, `Master Plan Revision`, `Decomposition Decision Reference` và approved design revision từ canonical chain.
5. For every unit specify dependencies, target area, acceptance, evidence, mode constraint, and `Bootstrap Scope`. Allowed values are exactly `required | not-required`.
6. For `greenfield` / `design-new`, use `required` only for the unique initial foundation unit when no approved foundation baseline exists; other units use `not-required` and must satisfy the Foundation baseline contract below. A second or later `required` unit yields `result: blocked`. For `incremental` / `preserve-existing`, every unit uses `not-required` and Foundation Baseline ID is `not-applicable`; wrong-mode scope yields `result: blocked`.
7. Mark approval owner and status per unit. Only a unit with explicit approval is an `approved migration unit`; approval of one unit or wave does not approve another.
8. Put unresolved dependencies, scope, trace links, or acceptance criteria in `Unknowns`; blocking unknowns make the result blocked.
9. Trước approval, đối chiếu one-to-one Work Item/adapter selector, exact dependency/mode/acceptance/trace/design equivalence, master-plan state và canonical parent/decomposition chain. Draft, blocked, incomplete, duplicate, external-only hoặc stale record làm `result: blocked`.

## Foundation baseline contract

A greenfield / `design-new` unit with `Bootstrap Scope = not-required` must select exactly one approved `Foundation Baseline ID`.

- Exactly one initial greenfield foundation unit may use `Bootstrap Scope = required`, only when no approved foundation baseline exists. It records `Foundation Baseline ID = pending-bootstrap` and `Foundation Approval Reference = pending-step09-approval`. This sentinel is the explicit authorization for step 09 and must not resolve or require an existing foundation baseline before step 09.
- For a later greenfield `Bootstrap Scope = not-required` unit, resolve the selector in `Baseline nền tảng đã duyệt`; require a target baseline reference, approval reference/status, design revision, and freshness Evidence that all describe the current target foundation. Its ordered-unit row carries the approved `FOUNDATION-*` ID and the corresponding Foundation Approval Reference. A missing ID or approval reference, stale evidence, unapproved record, or selector mismatch yields `result: blocked`.
- If a current approved foundation baseline already exists, all subsequent greenfield units use `Bootstrap Scope = not-required`; `required` is a lifecycle mismatch and yields `result: blocked` rather than rerunning bootstrap.
- An incremental unit records `Foundation Baseline ID = not-applicable` and `Foundation Approval Reference = not-applicable` because its target-conformance path is not a greenfield foundation selector. Incremental `Bootstrap Scope = required` is invalid and yields `result: blocked`.
- A later greenfield unit never reruns bootstrap merely because it is greenfield. A missing, stale, or mismatched selector/record yields `result: blocked`.

## Evidence and Unknowns

Evidence links each unit to its approved design revision and trace IDs. Unknowns identify missing ownership, dependency, acceptance, or approval rather than filling gaps with assumptions.

## Hợp đồng đầu ra

- File: `<RUN_DIR>/08-migration-plan.md`.
- Front matter: `step_id: 08-plan-waves`, `status: draft`, `result: complete | blocked`, `produced_at`.
- Preserve `Các đơn vị migration theo thứ tự`, `Bằng chứng`, `Điểm chưa rõ` và `Kết luận`.
- Preserve `Activation Slice` with the same ID, all seam rows, and trace IDs; record the owning or deferred unit for each seam without narrowing the approved slice.
- For a routed `result: blocked` artifact whose Activation Slice and immediate-predecessor handoff are otherwise valid, emit exactly one `Domain Blocker` table with non-placeholder `Blocker` and `Evidence Reference` values; omit that section for non-blocked output.
- Mỗi ordered migration-unit adapter row có đúng một row cùng `UNIT-###` trong `Work Item Adapter Trace`, chứa `Work Item ID`, `Parent Work Item ID`, `Master Plan Reference`, `Master Plan Revision`, `Decomposition Decision Reference` và `Design Revision`; ordered row tiếp tục giữ wave/order, dependencies, trace IDs, acceptance, mode constraint, `Bootstrap Scope`, `Foundation Baseline ID`, `Foundation Approval Reference` và approval owner/status.
- Với generic adapter, không sinh ordered `UNIT-*`; emit approved-complete step-08 `Work Item Trace` giữ canonical Work Item, master revision, dependencies qua master-plan authority, acceptance, trace và decomposition identity.
- Each ordered row includes `Delivery Change Boundary = one-unit-one-change` so implementation and delivery can reject mixed-unit diffs.
- Preserve `Baseline nền tảng đã duyệt` with stable ID, target baseline reference, approval reference/status, and freshness Evidence.

## Quick reference

| Condition | Result |
|---|---|
| Approved design, independently testable units | Plan waves |
| Required greenfield design or conflict approval missing | Block |
| Unit lacks trace ID or acceptance evidence | Block that unit |
| Approval exists only for another unit | Not approved |

## Common mistakes

- Treating the plan artifact itself as approval.
- Creating units by folder instead of behavior and dependency.
- Dropping upstream trace IDs when grouping work into waves.

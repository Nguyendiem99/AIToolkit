---
step_id: <orchestrator-provided>
status: draft
result: complete
produced_at: <yyyy-mm-dd>
revision: <DESIGN-SCOPE@positive integer>
responsibility_contract:
  version: 1
  applicability: required
---

<!-- artifact_language: vi -->

# Thiết kế kỹ thuật migration

## Kiến trúc

| Mode / Policy | Target Conformance / New Architecture | Trace IDs | Decision |
|---|---|---|---|
| <mode/policy> | <mức tuân thủ hoặc kiến trúc> | <REQ/ITEM IDs> | <quyết định> |

## Approved Master Plan Evidence

Snapshot đúng một approved master-plan/work-item row; mọi field selector phải khớp `Work Item Trace` bên dưới. Snapshot không tự cấp authority: `master-plan.md#PLAN-*` phải resolve file ngoài `master-plan.md` dưới run root. File external phải có bounded first front matter canonical `migration-master-plan`, exact plan ID/revision/status approved và linked spec scope; sau đó resolve đúng một row trong `## Work Items` với exact columns từ migration-scope contract. Acceptance giữ nguyên requirement/success-criterion references cộng measurable outcome; Trace IDs được parse độc lập. Acceptance, Trace IDs, Delivery Adapter, current approval/revision và snapshot phải exact-match authority; `Acceptance Traces` chỉ khớp các canonical REQ/SC references trích từ Acceptance.

| Master Plan Reference | Master Plan ID | Revision | Status | Work Item ID | Acceptance | Trace IDs | Delivery Adapter | Decomposition Decision Reference | Approval Reference | Evidence Reference |
|---|---|---|---|---|---|---|---|---|---|---|
| <master-plan.md#PLAN-SCOPE-ID> | <PLAN-SCOPE-ID> | <revision nguyên dương> | approved | <WORK-SCOPE-ID> | <REQ-001; SC-001; measurable outcome> | <trace IDs exact từ Work Items> | <adapter record hoặc none> | <DEC-* hoặc not-applicable> | <approval:TECH-LEAD-*> | <tham chiếu master-plan@revision=n:WORK-*> |

## Work Item Trace

Giữ đúng work item do master plan giao. `WORK-<SCOPE>-*` và `master-plan.md#PLAN-<SCOPE>-*` phải cùng scope; revision là số nguyên dương. `Acceptance Traces` chỉ gồm unique canonical `REQ-*`, `SC-*` trích theo đúng thứ tự từ Acceptance authority; không chép measurable outcome vào cột trace và không suy trace từ `Trace IDs`. Với child tạo bởi decomposition, dùng exact `DEC-*` từ canonical YAML `decomposition:` record trong `Work Items`; record phải cùng current approved revision và exact parent/child/decision. Nếu không áp dụng, ghi exact sentinel `not-applicable`; không tạo bảng decomposition khác.

| Work Item ID | Master Plan Reference | Master Plan Revision | Acceptance Traces | Decomposition Decision Reference |
|---|---|---|---|---|
| <WORK-*> | <master-plan.md#PLAN-*> | <revision nguyên dương> | <REQ-001, SC-001> | <DEC-* hoặc not-applicable> |

## Target Structure Conformance Matrix

Giữ exact set/cardinality tám concern canonical. `Working Exemplar` dùng `đường-dẫn-thật#ký-hiệu-định-danh`; `Observed Target Pattern` dùng `path=cùng-exemplar; symbols=danh-sách-tường-minh; boundary=tên; mechanism=tên`. Presentation luôn thêm observed/proposed `wrapper=ký-hiệu-định-danh-đầy-đủ`; so ordinal toàn bộ qualified segments, `yes` exact-match, `no` cần approved deviation.

| Concern | Working Exemplar | Observed Target Pattern | Proposed Path/Symbol | Conforms | Deviation Reference |
|---|---|---|---|---|---|
| module/container composition | <tham chiếu exemplar> | <pattern target quan sát được> | <path và symbol dự kiến> | <yes / no> | <not-applicable hoặc DEV-*> |
| main/child presentation boundaries | <tham chiếu exemplar> | <wrapper và child boundary> | <path, symbol và wrapper dự kiến> | <yes / no> | <not-applicable hoặc DEV-*> |
| unit/component organization | <tham chiếu exemplar> | <pattern target quan sát được> | <path và symbol dự kiến> | <yes / no> | <not-applicable hoặc DEV-*> |
| controller/provider/state pattern | <tham chiếu exemplar> | <pattern target quan sát được> | <path và symbol dự kiến> | <yes / no> | <not-applicable hoặc DEV-*> |
| routing and lifecycle | <tham chiếu exemplar> | <pattern target quan sát được> | <path và symbol dự kiến> | <yes / no> | <not-applicable hoặc DEV-*> |
| localization | <tham chiếu exemplar> | <pattern target quan sát được> | <path và symbol dự kiến> | <yes / no> | <not-applicable hoặc DEV-*> |
| service/config subscription and normalization | <tham chiếu exemplar> | <pattern target quan sát được> | <path và symbol dự kiến> | <yes / no> | <not-applicable hoặc DEV-*> |
| test harness and production-boundary tests | <tham chiếu exemplar> | <pattern target quan sát được> | <path và symbol dự kiến> | <yes / no> | <not-applicable hoặc DEV-*> |

## Approved Structural Deviations

Mỗi row `Conforms = no` cần canonical `DEV-*`, `CONFLICT-*`, `resolved:DECISION-<ID>: <quyết định cụ thể>` và `approval:TECH-LEAD-<ID>` không chứa placeholder semantic. Nếu mọi row conform, ghi `none` với các field còn lại là `not-applicable`.

| Deviation Reference | Concern | Conflict Reference | Resolved Decision | Tech Lead Approval |
|---|---|---|---|---|
| <DEV-* hoặc none> | <concern canonical hoặc not-applicable> | <CONFLICT-* hoặc not-applicable> | <resolved: quyết định hoặc not-applicable> | <approval:* hoặc not-applicable> |

## Planned File Tree

Unique `Planned Path` set phải khớp chính xác path set từ mọi matrix `Proposed Path/Symbol` sau normalize `\` thành `/`; giữ nguyên text artifact. Cho phép root file, Windows/POSIX separator và qualified symbol; reject blank/malformed/`..` traversal.

| Planned Path | Planned Symbol | Responsibility | Exemplar or Deviation Reference |
|---|---|---|---|
| <đường dẫn file sẽ tạo hoặc sửa> | <symbol dự kiến> | <trách nhiệm cấu trúc> | <exemplar hoặc DEV-*> |

## File Responsibility Matrix

Use `aitoolkit/contracts/file-responsibility-conformance.md` as the sole authority for column meanings, enums, approvals, and controlled sentinels. Every `(Planned Path, Planned Symbol)` has exactly one row. `Owner Symbol` is the primary public owner/module export; list feature-local public symbols in `Public Symbols`, while private helpers do not receive their own row.

| Responsibility ID | Owner Path | Owner Symbol | Boundary Kind | Primary Responsibility | Owned Capability IDs | Trace IDs | Atomic Boundary ID | Public Symbols | External Effects | Target Exemplar | Exemplar Classification | Classification Authority | Classification Evidence | Architecture Authority | Co-location Policy | Co-location Evidence | Verification Owner References | Conformance | Deviation Reference |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| <RESP-*> | <planned path> | <primary public symbol/module export> | <boundary kind> | <one concrete reason to change> | <CAP-*> | <REQ/AC/WORK trace IDs> | <ATOM-* or not-applicable> | <public symbols or none> | <concrete effects or none> | <path#symbol or no-equivalent> | <canonical classification> | <exact authority> | <immutable evidence> | <canonical architecture authority> | <canonical policy> | <exact evidence/rationale> | <VERIFY-OWNER-* or not-applicable> | <yes/no/blocked> | <DEV-* or not-applicable> |

## Verification Ownership Matrix

Use one row per production responsibility/capability binding. `Evidence Kind` and `Verification Disposition` are separate fields. A controlled `not-applicable-approved` route is limited by the canonical contract; behavior, routing, lifecycle, external effects, destructive actions, and production composition require production-bound verification.

| Verification Owner ID | Production Responsibility ID | Capability ID | Evidence Path | Evidence Symbol or Scenario | Evidence Kind | Verification Disposition | Production Binding Evidence | Decision Reference | Verdict | Deviation Reference |
|---|---|---|---|---|---|---|---|---|---|---|
| <VERIFY-OWNER-*> | <RESP-*> | <CAP-*> | <test/artifact path> | <test/scenario/evidence ID> | <canonical evidence kind> | <required/not-applicable-approved> | <production owner binding or approved rationale> | <not-applicable or approval> | <PASS/BLOCKED> | <DEV-* or not-applicable> |

## Provider/Router/Localization/Subscription Boundaries

| Boundary | Owner Path/Symbol | Input | Output | Lifecycle/Failure Policy | Evidence |
|---|---|---|---|---|---|
| provider | <owner path/symbol> | <input> | <state/output> | <loading, update và failure policy> | <evidence> |
| router | <owner path/symbol> | <route input> | <destination> | <guard, reselection và disposal> | <evidence> |
| localization | <owner path/symbol> | <locale/key> | <localized output> | <lookup và fallback policy> | <evidence> |
| subscription | <owner path/symbol> | <service/config event> | <normalized update> | <subscribe, normalize và cancel> | <evidence> |
| lifecycle | <owner path/symbol> | <mount/update/dispose> | <owned state/subscription> | <preserve/reset, failure và cancel> | <evidence> |

## Activation Slice

Ghi `not-applicable-approved` với evidence và decision reference khi unit không có activation selector; không được bỏ section.

| Activation Slice ID | Applicability | Seam | Input | Output | Source Reference | Trace IDs | Disposition | Status | Decision Reference | Deferred Unit ID |
|---|---|---|---|---|---|---|---|---|---|---|
| <ACT-001> | <applicable / not-applicable-approved / unknown> | <canonical seam> | <input> | <output> | <source reference> | <trace IDs> | <implement / reuse / deferred-approved / not-applicable-approved> | <verified / missing / conflict / unknown> | <approval reference hoặc not-applicable> | <UNIT-* hoặc not-applicable> |

## Bằng chứng

| Evidence | Location | Notes |
|---|---|---|
| <bằng chứng> | <tham chiếu> | <ghi chú> |

## Domain Blocker

Chỉ giữ section này khi front matter là `result: blocked` và Activation Slice/handoff vẫn hợp lệ; mọi output khác phải xóa toàn bộ section. Giá trị placeholder không phải evidence hợp lệ.

| Blocker | Evidence Reference |
|---|---|
| <blocker cụ thể> | <tham chiếu bằng chứng cụ thể> |
## Điểm chưa rõ

- <điểm chưa rõ hoặc giả định>

## Kết luận

<ready | blocked>

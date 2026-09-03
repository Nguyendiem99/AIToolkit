---
step_id: <orchestrator-provided>
status: draft
result: complete
produced_at: <yyyy-mm-dd>
responsibility_contract:
  version: 1
  applicability: required
---

<!-- artifact_language: vi -->

# Khảo sát migration

## Danh mục khảo sát

| Type | Name | Source Reference | Notes |
|---|---|---|---|
| Feature | <tính năng> | <tham chiếu nguồn> | <ghi chú> |
| Screen | <màn hình> | <tham chiếu nguồn> | <ghi chú> |
| Component | <thành phần> | <tham chiếu nguồn> | <ghi chú> |
| State | <trạng thái> | <tham chiếu nguồn> | <ghi chú> |
| Service | <dịch vụ> | <tham chiếu nguồn> | <ghi chú> |
| Dependency | <dependency> | <tham chiếu nguồn> | <ghi chú> |

## Comparable Target Exemplars

Giữ exact set/cardinality tám concern canonical: không thiếu, duplicate hoặc invented concern. Mỗi row applicable cần path thật, toàn bộ symbol explicit đã inspect (không wildcard/`all`), pattern quan sát được, primary responsibility, owned capabilities, verification owner, lý do comparability cụ thể, evidence chính xác, inspection status và classification authority/evidence immutable. `unknown` làm artifact blocked; `no-equivalent` cần resolved row trong `No-equivalent Gaps`. Classification không phải self-attestation của agent: `preferred` cần repeated working evidence và không authoritative conflict; `compatibility-only` cần project-pack rule hoặc approved owner decision; `legacy-debt` cần project documentation, debt record hoặc Tech Lead-approved conflict; `no-equivalent` cần factual search/inspection evidence.

| Concern | Path | Inspected Symbols | Observed Pattern | Primary Responsibility | Owned Capabilities | Verification Owner | Comparable Reason | Evidence | Inspection Status | Classification | Classification Authority | Classification Evidence |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| module/container composition | <đường dẫn target thật> | <symbols đã inspect đầy đủ> | <pattern đang hoạt động> | <primary reason-to-change> | <CAP-###> | <VERIFY-OWNER-###> | <lý do comparable> | <path:line hoặc evidence chính xác> | <verified / no-equivalent / unknown> | <preferred / compatibility-only / legacy-debt / no-equivalent> | <preferred/no-equivalent: factual-discovery-evidence; compatibility-only: project-pack-rule / approved-owner-decision; legacy-debt: project-documentation / debt-record / tech-lead-approved-conflict> | <tham chiếu immutable đúng với authority> |
| main/child presentation boundaries | <đường dẫn target thật> | <symbols đã inspect đầy đủ> | <pattern đang hoạt động> | <primary reason-to-change> | <CAP-###> | <VERIFY-OWNER-###> | <lý do comparable> | <path:line hoặc evidence chính xác> | <verified / no-equivalent / unknown> | <preferred / compatibility-only / legacy-debt / no-equivalent> | <preferred/no-equivalent: factual-discovery-evidence; compatibility-only: project-pack-rule / approved-owner-decision; legacy-debt: project-documentation / debt-record / tech-lead-approved-conflict> | <tham chiếu immutable đúng với authority> |
| unit/component organization | <đường dẫn target thật> | <symbols đã inspect đầy đủ> | <pattern đang hoạt động> | <primary reason-to-change> | <CAP-###> | <VERIFY-OWNER-###> | <lý do comparable> | <path:line hoặc evidence chính xác> | <verified / no-equivalent / unknown> | <preferred / compatibility-only / legacy-debt / no-equivalent> | <preferred/no-equivalent: factual-discovery-evidence; compatibility-only: project-pack-rule / approved-owner-decision; legacy-debt: project-documentation / debt-record / tech-lead-approved-conflict> | <tham chiếu immutable đúng với authority> |
| controller/provider/state pattern | <đường dẫn target thật> | <symbols đã inspect đầy đủ> | <pattern đang hoạt động> | <primary reason-to-change> | <CAP-###> | <VERIFY-OWNER-###> | <lý do comparable> | <path:line hoặc evidence chính xác> | <verified / no-equivalent / unknown> | <preferred / compatibility-only / legacy-debt / no-equivalent> | <preferred/no-equivalent: factual-discovery-evidence; compatibility-only: project-pack-rule / approved-owner-decision; legacy-debt: project-documentation / debt-record / tech-lead-approved-conflict> | <tham chiếu immutable đúng với authority> |
| routing and lifecycle | <đường dẫn target thật> | <symbols đã inspect đầy đủ> | <pattern đang hoạt động> | <primary reason-to-change> | <CAP-###> | <VERIFY-OWNER-###> | <lý do comparable> | <path:line hoặc evidence chính xác> | <verified / no-equivalent / unknown> | <preferred / compatibility-only / legacy-debt / no-equivalent> | <preferred/no-equivalent: factual-discovery-evidence; compatibility-only: project-pack-rule / approved-owner-decision; legacy-debt: project-documentation / debt-record / tech-lead-approved-conflict> | <tham chiếu immutable đúng với authority> |
| localization | <đường dẫn target thật> | <symbols đã inspect đầy đủ> | <pattern đang hoạt động> | <primary reason-to-change> | <CAP-###> | <VERIFY-OWNER-###> | <lý do comparable> | <path:line hoặc evidence chính xác> | <verified / no-equivalent / unknown> | <preferred / compatibility-only / legacy-debt / no-equivalent> | <preferred/no-equivalent: factual-discovery-evidence; compatibility-only: project-pack-rule / approved-owner-decision; legacy-debt: project-documentation / debt-record / tech-lead-approved-conflict> | <tham chiếu immutable đúng với authority> |
| service/config subscription and normalization | <đường dẫn target thật> | <symbols đã inspect đầy đủ> | <pattern đang hoạt động> | <primary reason-to-change> | <CAP-###> | <VERIFY-OWNER-###> | <lý do comparable> | <path:line hoặc evidence chính xác> | <verified / no-equivalent / unknown> | <preferred / compatibility-only / legacy-debt / no-equivalent> | <preferred/no-equivalent: factual-discovery-evidence; compatibility-only: project-pack-rule / approved-owner-decision; legacy-debt: project-documentation / debt-record / tech-lead-approved-conflict> | <tham chiếu immutable đúng với authority> |
| test harness and production-boundary tests | <đường dẫn target thật> | <symbols đã inspect đầy đủ> | <pattern đang hoạt động> | <primary reason-to-change> | <CAP-###> | <VERIFY-OWNER-###> | <lý do comparable> | <path:line hoặc evidence chính xác> | <verified / no-equivalent / unknown> | <preferred / compatibility-only / legacy-debt / no-equivalent> | <preferred/no-equivalent: factual-discovery-evidence; compatibility-only: project-pack-rule / approved-owner-decision; legacy-debt: project-documentation / debt-record / tech-lead-approved-conflict> | <tham chiếu immutable đúng với authority> |

## Inspected Symbols

Giữ exact columns và ít nhất một evidence row; tokenize danh sách bằng dấu phẩy/chấm phẩy, mỗi token là explicit/qualified symbol, không dùng `*`, `all`, `any`, `generic`, `symbol(s)`, `controller(s)`, `provider(s)`, `category/categories` hoặc generic controller/provider/category.

| Concern | Path | Symbol | Inspection Scope | Evidence |
|---|---|---|---|---|
| <concern canonical> | <đường dẫn thật> | <symbol cụ thể> | <declaration, consumers và lifecycle đã đọc> | <path:line> |

## Target Data-flow Trace

Giữ exact columns và đúng thứ tự end-to-end dưới đây; output của mỗi stage exact-match input của stage kế tiếp. Mỗi transformation dùng `operation=<identifier>; owner=<path#qualified-symbol>`.

| Stage | Path/Symbol | Input | Transformation | Output/Consumer | Evidence |
|---|---|---|---|---|---|
| source | <path#symbol nguồn> | <source event> | <operation=read; owner=path#symbol> | <raw input> | <path:line> |
| subscription | <path#symbol subscription> | <raw input> | <operation=subscribe; owner=path#symbol> | <subscribed input> | <path:line> |
| normalization | <path#symbol normalization> | <subscribed input> | <operation=normalize; owner=path#symbol> | <normalized input> | <path:line> |
| state | <path#symbol state> | <normalized input> | <operation=store; owner=path#symbol> | <feature state> | <path:line> |
| selection | <path#symbol selector> | <feature state> | <operation=select; owner=path#symbol> | <selected state> | <path:line> |
| render | <path#symbol render> | <selected state> | <operation=render; owner=path#symbol> | <production view> | <path:line> |
| test | <path#symbol test> | <production view> | <operation=verify; owner=path#symbol> | <verified boundary> | <path:line> |

## No-equivalent Gaps

Set gap rows phải khớp chính xác concern có `Inspection Status = no-equivalent`; dùng `resolved:DECISION-<ID>: <quyết định cụ thể>` và `approval:TECH-LEAD-<ID>`, không chứa placeholder semantic. Nếu không có gap thật, ghi đúng một sentinel `none` với các field còn lại là `not-applicable`.

| Concern | Gap Reference | Conflict Reference | Resolved Decision | Approval Reference |
|---|---|---|---|---|
| <concern canonical hoặc none> | <GAP-* hoặc not-applicable> | <CONFLICT-* hoặc not-applicable> | <resolved: quyết định hoặc not-applicable> | <approval:* hoặc not-applicable> |

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

# Thiết kế Scope Orchestration linh động cho Migration

**Ngày:** 2026-08-19
**Trạng thái:** đã duyệt hướng thiết kế trong hội thoại

## Mục tiêu

Mọi migration phải rõ ràng và truy vết được từ requested scope của người dùng đến work item bắt buộc cuối cùng, đồng thời không ép project dùng một taxonomy delivery cố định. Trước mọi production mutation, workflow phải có master spec và master plan đã duyệt. Hoàn tất một work item không bao giờ được báo thành hoàn tất toàn bộ module hoặc project.

Thiết kế xử lý đồng thời hai khoảng trống:

1. orchestrator đi vào `migration_unit_id` quá sớm, không giữ requested scope và không có persistent execution queue;
2. incremental migration có thể khai báo target conformance mà không chứng minh đã đọc và làm theo complete working target exemplars.

## Nguyên tắc bất biến

1. Resolve `requested_scope` trước khi chọn execution item.
2. Master spec đã duyệt định nghĩa kết quả cần đạt; master plan đã duyệt định nghĩa cách hoàn thành scope.
3. `work_item` là taxonomy tổng quát; `migration_unit_id` chỉ là delivery adapter tùy chọn.
4. Không production mutation khi master spec/plan thiếu, draft, stale, forked hoặc blocked.
5. Phiên bản đầu chỉ chạy một dependency-ready work item tại một thời điểm.
6. Attempt completion, work-item completion và requested-scope completion là ba trạng thái độc lập.
7. Thay đổi approved scope, dependency, acceptance, selector hoặc architecture phải tạo revision bất biến mới.
8. Runtime waiver không bao giờ waiver architecture inspection, conformance, selector, schema hoặc static review.
9. Incremental migration thiếu comparable exemplar phải mở gap; không được phát minh pattern lúc implementation.
10. Với cùng approved plan revision và evidence state, resume luôn chọn cùng một next eligible item.

## Phạm vi

Bao gồm:

- scope resolution và ambiguity handling;
- master-spec/master-plan contracts;
- generic work items và optional delivery adapters;
- dependency graph, selection, resume, revision và completion;
- canonical migration-unit decomposition/selector validation;
- target exemplar và structure-conformance gates;
- architecture-first AI Review;
- automation/waiver separation;
- compatibility conversion cho historical unit-only runs;
- validator và mutation-test isolation.

Không bao gồm:

- database-backed hoặc distributed workflow engine;
- concurrent target mutation trong phiên bản đầu;
- ép project dùng project/story/task/package/phase/milestone terminology;
- tự động upload Gerrit, merge, release hoặc destructive delivery;
- redesign feature/bugfix workflow không liên quan.

## Mô hình scope

| Cấp | Ý nghĩa | Ví dụ |
|---|---|---|
| Requested scope | Goal người dùng yêu cầu | migrate module Admin |
| Delivery scope | Toàn bộ behavior/acceptance đã duyệt | mọi Admin settings flow |
| Work item | Outcome dependency-ready, reviewable độc lập | Simple Locks behavior |
| Delivery adapter | Ánh xạ tùy chọn sang taxonomy project | `UNIT-ADM-002` |
| Execution attempt | Một lần chạy bất biến cho một item | attempt 02 |

Tên folder, menu, package hoặc file chỉ là evidence; không tự resolve requested scope.

## Kiến trúc hai tầng

### Scope plane

Scope plane quản lý:

- scope resolution;
- master-spec/master-plan revision chains;
- work-item dependency graph và approvals;
- next-eligible selection;
- work-item/scope state transitions;
- scope-change decisions;
- terminal evidence references.

Scope plane không sửa target source.

### Execution plane

Execution plane nhận đúng một approved work item và chạy adapter-specific delivery flow. Adapter `migration-unit` gọi canonical AIToolKit migration delivery cho đúng một approved `migration_unit_id`.

Execution plane trả attempt evidence và work-item verdict. Nó không được thêm item, đổi dependency, thu hẹp acceptance hoặc khai báo requested scope complete.

### Luồng dữ liệu

```text
user intent
  -> scope resolution
  -> master spec revision
  -> master plan revision
  -> deterministic next-eligible selection
  -> optional delivery-adapter resolution
  -> one execution attempt
  -> terminal evidence
  -> atomic master-plan transition
  -> next item hoặc scope terminal verdict
```

Immediate-predecessor contract hiện tại vẫn giữ nguyên. Orchestrator truyền thêm `master_spec_ref`, `master_plan_ref`, `master_plan_revision` và `work_item_id`; step-skill không quét cumulative artifact directory.

## Scope resolution contract

Allowed kinds:

```text
project | module | feature | task | explicit-item | unresolved
```

| Request | Hành vi |
|---|---|
| `Migrate module Admin` | Spec/plan toàn module trước execution |
| `Migrate Lock Mode` | Resolve feature boundary và một hoặc nhiều work items |
| `Migrate UNIT-ADM-004` | Tạo scope tối thiểu cho item và dependency context, không mở rộng thành module |
| `Migrate Admin` khi taxonomy mơ hồ | Hỏi đúng một scope question rồi block |
| Project không có unit | Dùng generic work items, không sinh `UNIT-*` |

Canonical record:

```yaml
requested_scope:
  kind: module
  id: ADMIN
  statement: Migrate the complete Admin module
  source: user
  resolution_evidence: conversation:<stable-reference>
```

`unresolved` không được tạo executable work item.

## Master spec contract

Canonical file: `<RUN_DIR>/master-spec.md`.

```yaml
---
artifact_type: migration-master-spec
master_spec_id: SPEC-ADMIN-001
revision: 1
status: draft
result: complete
approval_source: human
requested_scope_kind: module
requested_scope_id: ADMIN
produced_at: 2026-08-19
supersedes: not-applicable
---
```

Các section bắt buộc:

1. vấn đề và intended outcome;
2. requested-scope boundary;
3. actors và journeys;
4. behaviors, states và failure paths;
5. constraints và project rules;
6. architecture/conformance applicability;
7. measurable success criteria;
8. explicitly out-of-scope items;
9. assumptions và unknowns;
10. trace/evidence index;
11. approval record;
12. revision history.

Requirement dùng stable `REQ-###`. Mỗi success criterion phải tham chiếu ít nhất một requirement. Unknown ảnh hưởng scope, architecture hoặc acceptance làm artifact `draft/blocked`.

## Master plan contract

Canonical file: `<RUN_DIR>/master-plan.md`.

```yaml
---
artifact_type: migration-master-plan
master_plan_id: PLAN-ADMIN-001
master_spec_id: SPEC-ADMIN-001
master_spec_revision: 1
revision: 1
status: draft
scope_status: planned
execution_policy: dependency-ready
max_concurrency: 1
produced_at: 2026-08-19
supersedes: not-applicable
---
```

Allowed scope states:

```text
planned | scope-in-progress | scope-blocked | scope-complete | scope-cancelled-approved
```

Allowed work-item states:

```text
proposed | pending | ready | in-progress | blocked | complete | cancelled-approved | not-applicable-approved
```

Mỗi work-item row có:

| Field | Contract |
|---|---|
| Work Item ID | Stable `WORK-<SCOPE>-<NAME>` |
| Title | Outcome, không chỉ tên folder |
| Required | `yes | no` |
| Dependencies | Work Item IDs hoặc `none` |
| Plan Order | Số nguyên dương, unique trong revision |
| Acceptance | Requirement/success-criterion IDs cộng measurable outcome |
| Trace IDs | Requirement, discovery, mapping, gap và design IDs |
| Delivery Adapter | Adapter record hoặc `none` |
| Status | Work-item state enum |
| Latest Attempt | Attempt ID hoặc `none` |
| Terminal Evidence | Exact artifact reference hoặc `none` |
| Approval Reference | Exact approval hoặc `pending` |

## Delivery adapter contract

Allowed kinds:

```text
migration-unit | task | story | package | phase | milestone | none
```

```yaml
delivery_adapter:
  kind: migration-unit
  external_id: UNIT-ADM-002
  authority: 08-migration-plan.md
  authority_revision: 3
  approval_reference: approval:UNIT-ADM-002
  parent_selector: not-applicable
```

Với `kind: none`, selector fields còn lại là `not-applicable`. Orchestrator không phát minh external ID.

Với `migration-unit`, external ID phải resolve đúng một approved canonical row có mode, acceptance, trace, dependency và design revision khớp. Draft, duplicate, stale, mismatch hoặc external-only selector phải block. One-unit-one-change vẫn bắt buộc.

## Decomposition contract

Chỉ tách work item khi item không independently implementable/testable/revertible, behaviors có dependency khác nhau, target boundary đã chứng minh yêu cầu boundary khác, hoặc approved scope revision đổi delivery boundary.

```yaml
decomposition:
  parent_work_item_id: WORK-ADMIN-LOCKS
  child_work_item_ids:
    - WORK-ADMIN-SIMPLE-LOCKS
    - WORK-ADMIN-ADVANCED-LOCKS
  decision_reference: DEC-ARCH-014
```

Decomposition tạo master-plan revision mới. Child dùng migration-unit adapter phải quay lại inventory, mapping, gaps/conflicts, technical design và plan-waves. Chỉ gắn adapter sau khi canonical plan duyệt child selector. Execution-only `UNIT-002A` là invalid.

## Dependency và selection algorithm

Item chỉ eligible khi:

1. required hoặc optional execution đã approved;
2. state là `pending` hoặc `ready`;
3. mọi dependency terminal-success;
4. approval hợp lệ cho current plan revision;
5. không có blocking unknown/conflict;
6. adapter tùy chọn resolve canonical;
7. architecture và selector/schema đều `PASS`;
8. không có item khác `in-progress`.

Terminal-success states: `complete`, `cancelled-approved`, `not-applicable-approved`.

Selection order:

1. dependency depth tăng dần;
2. `Plan Order` tăng dần;
3. ordinal `Work Item ID` tăng dần.

Không có eligible item nhưng còn required blocker thì `scope-blocked`. Mọi required item terminal-success thì `scope-complete`. Cycle hoặc missing dependency làm plan invalid/blocked.

## Attempt và atomic transition

Trước execution, atomically chuyển một item `ready -> in-progress`, ghi immutable attempt ID và plan revision. Sau execution:

- valid successful terminal artifact: `in-progress -> complete`;
- native blocker: `in-progress -> blocked`;
- approved cancellation: `pending|ready|blocked -> cancelled-approved`;
- approved non-applicability: `pending|ready -> not-applicable-approved`.

Không overwrite attempt artifact. Master plan trỏ tới terminal evidence mới nhất và giữ attempt history.

## Resume contract

Resume phải:

1. resolve latest approved master-spec revision;
2. resolve latest approved master-plan revision liên kết đúng spec revision;
3. validate freshness và một linear revision chain;
4. reconcile `in-progress` item với attempt artifact;
5. áp dụng missing terminal transition nếu evidence hợp lệ;
6. resume non-terminal attempt thay vì chọn item mới;
7. nếu không có in-progress item thì chạy deterministic selection;
8. không brainstorm lại approved scope trừ khi user yêu cầu scope change.

Missing, forked, cyclic hoặc stale revision chain phải block resume.

## Revision contract

Thay đổi requested boundary, requirement, success criterion, required disposition, work-item set, dependency, order, acceptance, adapter, selector hoặc structural decision đều tạo revision mới.

Revision mới phải giữ stable master ID, tăng revision đúng một, trỏ `supersedes` tới prior artifact, ghi change summary/affected items, invalidate affected approvals, giữ unaffected completed evidence và chạy approval gate phù hợp. Approved revision là bất biến.

## Target exemplar evidence

Incremental discovery cần complete working exemplar cho mọi applicable concern:

- module/container composition;
- main/child presentation boundaries;
- unit/component organization;
- controller/provider/state pattern;
- routing và lifecycle;
- localization;
- service/config subscription và normalization;
- test harness và production-boundary tests.

Mỗi row có concern, real path, fully inspected symbols, observed pattern, comparable reason, evidence và `verified | no-equivalent | unknown`. `no-equivalent` phải đi qua gaps/conflicts. Missing hoặc unknown concern làm discovery blocked.

## Target Structure Conformance Matrix

Technical design bắt buộc có:

| Concern | Working Exemplar | Observed Target Pattern | Proposed Path/Symbol | Conforms | Deviation Reference |
|---|---|---|---|---|---|

Mọi applicable concern phải đủ coverage. `Conforms = no` cần resolved conflict và Tech Lead approval. “Use Riverpod” hoặc “follow Clean Architecture” không phải evidence. Planned file tree và provider/router/localization/subscription/lifecycle boundaries là bắt buộc.

## Structural pre-edit gate

Trước target mutation, code-migration phải kiểm:

1. work item thuộc approved master-plan revision;
2. adapter selector canonical và khớp work item;
3. conformance matrix đã duyệt;
4. exemplar paths/symbols đã đọc đầy đủ;
5. proposed files/classes khớp planned file tree;
6. state/routing/localization/subscription/lifecycle dùng target boundaries;
7. abstraction mới có approved deviation;
8. production activation path hoàn chỉnh khi áp dụng;
9. architecture và selector/schema verdict đều `PASS`.

Failure block trước edit và không waiver-eligible.

Implementation report thêm `Master Scope Context`, `Conformance Matrix Reference`, `Actual File Tree vs Planned File Tree`, `Exemplar Deviations` và `Production Activation Path Evidence`.

## Architecture-first AI Review

Thứ tự review:

1. master-scope/work-item alignment;
2. project rule resolution;
3. canonical selector;
4. architecture conformance với matrix/exemplars;
5. production activation path;
6. behavior, failure modes, security, performance và tests;
7. change hygiene.

Mandatory checks gồm invented aggregate state, direct widget service/router call, raw layout thay target wrapper, thiếu unit boundary, sai localization mechanism, thiếu lifecycle gate, test bypass production provider, thiếu production subscription key, planned/actual tree drift và unapproved structural deviation.

Unapproved structural deviation ít nhất là Major. Deviation làm feature không activate/route/render là Critical.

Review report có:

```text
Architecture Conformance Verdict: PASS | BLOCKED
Canonical Selector Verdict: PASS | BLOCKED
Production Activation-path Verdict: PASS | BLOCKED | NOT_APPLICABLE
```

Bất kỳ verdict `BLOCKED` nào cũng làm overall verdict `Reject`.

## Automation và waiver

Artifact báo ba state độc lập:

```yaml
runtime_evidence_state: PASS | FAIL | NOT_RUN | WAIVED
architecture_conformance_state: PASS | BLOCKED
selector_schema_state: PASS | BLOCKED
```

`auto-waive` chỉ được chuyển eligible runtime evidence từ `NOT_RUN + BLOCKED` thành `NOT_RUN + WAIVED`. Không được waiver master approval, exemplar inspection, conformance matrix, canonical selector, schema validation, static architecture review hoặc correctness failure.

## Completion semantics

Attempt chỉ terminal khi có immutable contract-valid terminal artifact. Work item chỉ complete khi acceptance riêng của item có terminal evidence.

Requested scope chỉ `scope-complete` khi mọi required item terminal-success, không còn blocker, graph hợp lệ, completed items có architecture/selector-schema `PASS`, và terminal scope report liệt kê toàn bộ evidence.

Một item complete trong khi required item khác còn lại thì verdict duy nhất hợp lệ là `scope-in-progress`.

## Compatibility

Historical runs vẫn đọc được nhưng không resume trực tiếp tới mutation. Conversion tạo master-spec revision 1 từ approved evidence và master-plan revision 1 với một work item cho mỗi canonical legacy unit. Nó giữ exact selector, chỉ preserve contract-valid terminal evidence, phải qua approval gate mới và không suy module completion từ một unit.

## Validation scenarios

1. Module request tạo scope-wide spec/plan trước code.
2. Explicit unit request không mở rộng thành module.
3. Ambiguous taxonomy hỏi một scope question rồi block.
4. Project không dùng unit vẫn chạy generic work items.
5. Một item complete cộng required item pending cho `scope-in-progress`.
6. Selection deterministic qua resume.
7. Hard blocker ngăn dependent item.
8. Scope change tạo revision, không sửa approved artifact.
9. Cycle và missing dependency bị reject.
10. External-only selector bị step 10 reject.
11. Decomposition quay lại canonical steps 04–08.
12. Generic controller citation thiếu complete exemplar làm discovery block.
13. “Use Riverpod” thiếu structural evidence làm design block.
14. Thay required panel wrapper cần approved deviation.
15. Actual/planned file-tree drift block trước edit hoặc tại review.
16. Review thiếu conformance matrix bị Reject trước behavior analysis.
17. Thiếu production subscription key là Critical.
18. Runtime waiver vẫn yêu cầu architecture và selector/schema PASS.
19. Legacy conversion không suy scope completion.
20. Mọi required item terminal-success tạo `scope-complete`.
21. Mutation tests chạy trên isolated copy và để source tree byte-identical.

## Definition of Done

- Mọi migration mới có approved master spec và master plan trước production mutation.
- Scope resolution độc lập với migration-unit selection.
- Generic work items chạy được khi không có adapter.
- Migration-unit adapters chỉ resolve canonical approved selectors.
- Dependency graph, selection, resume, revision và completion có executable validation.
- Incremental discovery không complete khi thiếu exemplar hoặc approved no-equivalent decision.
- Technical design không complete khi thiếu conformance matrix/planned file tree.
- Code migration không edit khi structural gate fail.
- AI Review chạy architecture-first và có đủ ba verdict.
- `auto-waive` chỉ ảnh hưởng eligible runtime evidence.
- Legacy conversion không tạo scope completion giả.
- Validator/mutation tests pass trên isolated copy và source bytes không đổi.
- Cả 21 scenarios có automated coverage.

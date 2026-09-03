# AIToolkit issue: architecture conformance chỉ kiểm file tree, chưa kiểm responsibility boundary

## Metadata

- Type: workflow architecture / contract / review-gate defect
- Scope: AIToolkit migration workflow, language-agnostic, framework-agnostic
- Affected modes: `incremental/preserve-existing` và `greenfield/design-new`
- Suggested severity: Major; Critical khi boundary defect làm sai activation, routing, lifecycle, data ownership hoặc khiến verification không đại diện cho production
- Components likely affected:
  - `contracts/target-structure-conformance.md`
  - `skills/migration/discovery`
  - `skills/migration/technical-design`
  - `skills/migration/plan-waves`
  - `skills/migration/code-migration`
  - `skills/shared/ai-review`
  - migration templates, schemas và contract tests liên quan

## Summary

AIToolkit hiện kiểm tra khá chặt việc implementation có nằm trong approved file tree, có dùng đúng namespace/layer, có khớp planned paths và có giữ các provider/router/subscription/lifecycle boundary đã khai báo hay không. Tuy nhiên workflow chưa có contract đủ mạnh để xác định **một file hoặc module đang sở hữu bao nhiêu responsibility độc lập** và việc co-location đó có phù hợp với kiến trúc target hay không.

Vì vậy một design có thể:

1. gom nhiều feature, controller, provider, component và test độc lập vào vài aggregate files;
2. khai báo chính các aggregate files đó trong `Planned File Tree`;
3. implementation khớp hoàn toàn allowlist/path đã duyệt;
4. các structural gate kết luận `PASS` dù module boundary thực tế không theo target exemplar hoặc không còn reviewable/testable/revertible độc lập.

Đây là defect chung của conformance model: **“actual tree khớp planned tree” không chứng minh “planned tree có responsibility boundaries đúng”.**

## Why this is a toolkit-level issue

Lỗi không phụ thuộc Flutter, Riverpod, UI hay một project cụ thể. Nó có thể xuất hiện ở mọi stack:

- một React file chứa nhiều page, hook và API mutation độc lập;
- một Spring service chứa nhiều bounded-context use case;
- một Python module gom nhiều adapters và command handlers;
- một Rust module gom nhiều domain capabilities không cùng reason-to-change;
- một migration database gom nhiều ownership domain vào một change không thể rollback độc lập.

Nếu approved design đã tạo aggregate boundary sai, các bước sau chỉ kiểm exact tree sẽ hợp thức hóa lỗi thiết kế đó. Coding agent không thể tự tách file vì việc thêm path mới lại bị coi là unapproved tree drift.

Project-specific rules có thể làm lỗi dễ thấy hơn, nhưng sửa riêng project pack không ngăn lỗi tái diễn ở project khác.

## Existing AIToolkit intent

AIToolkit đã có đúng intent ở mức nguyên tắc:

- `incremental/preserve-existing` phải giữ architecture, module boundaries, conventions và extension points của target;
- discovery/technical design phải dùng working target exemplars;
- structural pre-edit gate phải so planned/actual tree và target boundaries;
- architecture-first review phải phát hiện `missing unit boundary`, invented aggregate state và unapproved structural deviation.

Khoảng trống nằm ở chỗ các khái niệm `module boundary`, `unit boundary` và `aggregate` chưa được chuyển thành evidence schema và validation procedure có thể kiểm tra nhất quán.

## Current behavior

### Design stage

`Planned File Tree` chủ yếu mô tả path và symbol. Nó chưa bắt buộc khai báo:

- primary responsibility của file;
- feature/capability/work-item IDs mà file sở hữu;
- public symbols và external effects theo từng responsibility;
- reason-to-change;
- lý do nhiều responsibility được co-locate;
- target exemplar nào chứng minh cách co-location này là convention được phép mở rộng;
- test owner và rollback/revert boundary.

Do đó một path hợp lệ về namespace vẫn có thể là một aggregate boundary không hợp lệ.

### Planning stage

Một migration unit được yêu cầu reviewable, testable và revertible, nhưng không có kiểm tra rằng file ownership bên trong unit cũng giữ được các thuộc tính đó. Một unit nhỏ vẫn có thể tạo một file sở hữu nhiều capability độc lập.

### Pre-edit stage

`code-migration` kiểm tra implementation khớp approved tree. Nếu approved tree đã aggregate sai, exact-tree gate không phát hiện lỗi và còn ngăn agent sửa cấu trúc nếu chưa có amendment.

### Review stage

`ai-review` yêu cầu tìm `missing unit boundary` nhưng chưa bắt buộc reviewer tạo các evidence sau:

- symbol-to-file responsibility inventory;
- feature/capability ownership count;
- planned-versus-actual responsibility comparison;
- co-location rationale validation;
- test-to-production-owner mapping;
- verification rằng integration/order tests bám production composition thay vì duplicate constants hoặc test-only registries.

Kết quả phụ thuộc vào nhận định tự do của reviewer và dễ bị bỏ sót khi behavior tests hoặc allowlist checks đều xanh.

## Expected behavior

AIToolkit phải đánh giá architecture conformance ở hai tầng độc lập:

1. **Tree conformance:** actual path/symbol khớp approved design.
2. **Responsibility conformance:** mỗi planned và actual owner có boundary phù hợp target evidence, có reason-to-change rõ, có test owner và có rationale được duyệt khi co-location nhiều capability.

Cả hai tầng phải `PASS` trước khi implementation/review được xem là structurally conforming.

## Canonical responsibility model

Thêm một contract language-agnostic, ví dụ `contracts/file-responsibility-conformance.md`.

### File Responsibility Matrix

Mỗi production file/module được tạo hoặc thay đổi phải có một row:

| Field | Required meaning |
|---|---|
| Owner path | Exact planned file/module path |
| Owner symbol | Qualified primary owner symbol hoặc module export |
| Layer / boundary kind | Domain, data, application, presentation, adapter, integration, test, config hoặc project-defined kind |
| Primary responsibility | Một mô tả cụ thể về reason-to-change chính |
| Owned capability IDs | Stable feature/capability/work-item IDs |
| Public symbols | Public classes/functions/providers/routes/handlers/exports |
| External effects | Service calls, writes, subscriptions, routing, filesystem, network, process hoặc `none` |
| Target exemplar | Exact path/symbol và inspected evidence |
| Exemplar classification | `preferred`, `compatibility-only`, `legacy-debt`, `no-equivalent` |
| Co-location rationale | Bắt buộc khi có nhiều capability hoặc nhiều independent effects |
| Test owner | Exact test path/symbol kiểm chứng production owner |
| Revert boundary | Cách owner được rollback/revert mà không kéo theo capability không liên quan |
| Conformance | `yes`, `no`, `blocked` |
| Deviation reference | Approved decision hoặc `not-applicable` |

### Responsibility semantics

Không dùng rule máy móc `one class = one file` hoặc line-count threshold.

Co-location hợp lệ khi các symbol:

- có cùng primary reason-to-change;
- cùng lifecycle và dependency boundary;
- cùng capability ownership;
- thường được review/test/revert cùng nhau;
- phù hợp một `preferred` target exemplar hoặc có approved rationale.

Co-location cần review/deviation khi một owner chứa:

- nhiều capability IDs độc lập;
- nhiều routes/commands/settings/service methods không cùng lifecycle;
- generic/shared engine cùng concrete registrations của nhiều feature;
- composition/router logic cùng feature business behavior;
- nhiều UI units/pages có thể thay đổi độc lập;
- test aggregate không map được về production owners;
- behavior có thể release/revert độc lập nhưng bị buộc chung file/change.

Một target file lớn đang tồn tại không tự động trở thành exemplar tốt. Nó phải được phân loại `preferred`, `compatibility-only` hoặc `legacy-debt` bằng evidence.

## Required workflow changes

### 1. Discovery: classify exemplars, not merely find them

Với mỗi comparable exemplar, discovery phải ghi:

- responsibility và owned capabilities;
- reason-to-change;
- cách test owner map tới production owner;
- trạng thái `preferred | compatibility-only | legacy-debt | no-equivalent`;
- lý do exemplar phù hợp cho code mới.

`preserve-existing` nghĩa là tương thích với target architecture, không phải nhân rộng mọi technical debt đang tồn tại.

### 2. Technical design: require responsibility evidence

Ngoài `Target Structure Conformance Matrix` và `Planned File Tree`, technical design phải sinh `File Responsibility Matrix` đầy đủ.

Gate:

- missing owner row hoặc missing test owner: `blocked`;
- nhiều independent capability IDs nhưng thiếu co-location rationale: `blocked`;
- dùng `compatibility-only`/`legacy-debt` làm mẫu cho code mới mà không có approved deviation: `blocked`;
- planned symbol không xuất hiện trong responsibility matrix hoặc ngược lại: `blocked`;
- extra planned/actual public symbol không có ownership record: structural deviation.

### 3. Plan waves: align migration unit and responsibility boundaries

Mỗi implementation unit phải chỉ ra:

- responsibility rows thuộc unit;
- dependencies giữa các owners;
- integration/composition owner riêng;
- test owner tương ứng;
- lý do unit vẫn independently implementable, reviewable, testable và revertible.

Nếu một unit cần nhiều capability, plan phải phân biệt shared foundation, concrete feature owners và integration owner thay vì gom tất cả vào một aggregate file mặc định.

### 4. Code migration: structural responsibility preflight

Trước RED/TDD và trước target mutation:

1. Validate exact File Responsibility Matrix từ approved design.
2. Resolve planned symbols/capabilities/test owners.
3. Compare với target exemplar classification.
4. Block unapproved aggregate ownership.
5. Sau implementation, inventory actual public symbols/effects và so hai chiều với planned responsibility rows.

Exact path match không được phép override responsibility mismatch.

### 5. AI review: operationalize `missing unit boundary`

Migration review phải ghi riêng:

- `Tree Conformance Verdict: PASS | BLOCKED`;
- `Responsibility Conformance Verdict: PASS | BLOCKED`;
- `Test Ownership Verdict: PASS | BLOCKED`.

Reviewer phải kiểm:

- planned/actual capability-to-owner mapping;
- unplanned public symbols và external effects;
- generic abstraction có chứa concrete feature ownership hay không;
- composition/router owner có chứa business behavior hay không;
- tests có import/exercise production owner/composition thật hay chỉ kiểm duplicate metadata;
- co-location rationale có target evidence hoặc approval hợp lệ hay không.

Unapproved aggregate boundary là ít nhất Major. Nó là Critical nếu che giấu hoặc gây lỗi activation, routing, state lifecycle, destructive action, security/data ownership, hoặc làm verification PASS trên một path không được production sử dụng.

### 6. Structural remediation route

Khi defect được phát hiện sau implementation:

1. Pause work item và không advance queue.
2. Sinh immutable architecture-audit artifact.
3. Tạo design/master-plan revision thay thế affected responsibility tree.
4. Chèn structural-remediation work item trước feature phụ thuộc tiếp theo.
5. Cho phép approved tree replacement theo revision, không bắt buộc nhiều amendment path rời rạc.
6. Re-run architecture review, production-boundary tests và terminal verification.

Runtime waiver không được waive structural responsibility mismatch.

### 7. Templates and schemas

Các template/schema phải định nghĩa exact headings, columns, enums và cross-reference rules cho:

- File Responsibility Matrix;
- Exemplar Classification;
- Responsibility Conformance Verdict;
- Test Ownership Matrix;
- Structural Remediation Reference.

Prose-only claims như “boundary is clear”, “follows architecture” hoặc “same pattern” không phải evidence hợp lệ.

## Reproduction case: Signage Admin migration

Case này chỉ là một fixture chứng minh defect, không phải phạm vi của fix.

Observed examples:

- một access controller file sở hữu nhiều Admin actions độc lập;
- một lock unit file sở hữu switch, radio panel và alert widgets cho nhiều lock capabilities;
- một FOTA unit file sở hữu entry, version, settings switches, progress/action body và alerts;
- một panel file sở hữu registry, container, main panel, route item và placeholder child panel;
- aggregate controller tests kiểm nhiều production owners;
- planned tree đã duyệt các aggregate paths, nên exact-tree/static gates vẫn PASS.

Target evidence đồng thời cho thấy nuance cần giữ:

- một số controller files hiện hữu cũng aggregate nhiều controller, vì vậy không thể kết luận chỉ dựa vào số class/file;
- unit/component exemplars thường có owner file riêng, nên presentation aggregation là mismatch mạnh hơn;
- target debt phải được phân loại, không được mặc định là preferred convention.

Case này chứng minh cần responsibility evidence thay vì heuristic theo file size hoặc class count.

## Acceptance criteria

- [ ] Có canonical responsibility contract language-agnostic.
- [ ] Discovery phân loại exemplar thành `preferred`, `compatibility-only`, `legacy-debt`, `no-equivalent`.
- [ ] Technical design bắt buộc có File Responsibility Matrix.
- [ ] Planned File Tree và Responsibility Matrix có exact bidirectional coverage cho path và public symbol.
- [ ] Multi-capability co-location thiếu rationale bị block trước mutation.
- [ ] Code migration so planned-versus-actual responsibility, không chỉ path allowlist.
- [ ] AI review luôn ghi Responsibility Conformance và Test Ownership verdict.
- [ ] Integration/order tests phải chứng minh production composition thật.
- [ ] Runtime/automation waiver không thể waive structural responsibility gate.
- [ ] Có structural remediation route và plan revision mechanism.
- [ ] Không áp dụng one-class-per-file hoặc line-count rule máy móc.
- [ ] Existing target debt không tự động trở thành preferred exemplar.
- [ ] Contract tests bao phủ fixtures accept/reject bên dưới.

## Required contract-test fixtures

### Fixture A — reject aggregate feature ownership

Một planned file sở hữu nhiều independent capability IDs, routes và service writes; không có co-location rationale.

Expected: technical design hoặc pre-edit gate `BLOCKED`.

### Fixture B — reject exact-tree false positive

Actual paths khớp planned allowlist 100%, nhưng actual file có extra public symbols/effects không xuất hiện trong responsibility matrix.

Expected: `Tree Conformance = PASS`, `Responsibility Conformance = BLOCKED`, overall reject.

### Fixture C — accept feature-local co-location

Một file chứa state, controller và private helpers cho cùng một capability, cùng lifecycle/test/revert boundary.

Expected: PASS; không yêu cầu tách class máy móc.

### Fixture D — accept shared engine with separate registrations

Generic engine nằm ở shared owner; concrete feature registrations và UI owners được map riêng; mỗi feature có test owner.

Expected: PASS.

### Fixture E — reject debt exemplar propagation

Target có aggregate legacy file nhưng exemplar được phân loại `legacy-debt`. Design mới sao chép pattern này mà không có deviation approval.

Expected: BLOCKED.

### Fixture F — reject test-only composition proof

Order/integration test chỉ kiểm duplicate constant hoặc fake registry, không exercise production composition owner.

Expected: Test Ownership `BLOCKED` hoặc Major/Critical theo blast radius.

### Fixture G — accept approved co-location

Nhiều capability bắt buộc có chung atomic transaction/lifecycle/revert boundary, có target evidence và Tech Lead approval.

Expected: PASS với preserved rationale/reference.

### Fixture H — remediation after implementation

Review phát hiện aggregate boundary sau khi source đã được tạo.

Expected: queue pause, architecture-audit artifact, approved design/plan revision, remediation work item; không tiếp tục feature kế tiếp trên tree cũ.

### Fixture I — cross-language equivalence

Chạy cùng responsibility contract trên ít nhất ba fixture thuộc các hệ khác nhau, ví dụ UI component tree, backend service/handler và data/adapter pipeline.

Expected: cùng semantics và verdict, không phụ thuộc tên `controller`, `provider`, `widget` hoặc framework cụ thể.

## Non-goals

- Không bắt buộc một class/function/component trên mỗi file.
- Không dùng số dòng, số class hoặc cyclomatic complexity làm authority duy nhất.
- Không ép target phải copy file tree của legacy source.
- Không tự động refactor toàn bộ technical debt hiện hữu.
- Không thay thế behavior, parity, security hoặc runtime verification gates.
- Không cho reviewer tự phát minh project convention khi thiếu evidence.

## Definition of done

Issue hoàn tất khi AIToolkit có responsibility contract, schema/template, pre-edit validation, review verdict, remediation route và automated fixtures chứng minh rằng:

1. exact-tree match không còn đủ để tạo structural PASS;
2. unapproved aggregate ownership bị phát hiện trước mutation hoặc bắt buộc chặn ở review;
3. valid co-location vẫn được chấp nhận bằng reason-to-change và evidence;
4. target technical debt không bị nhân rộng như preferred architecture;
5. cùng rule hoạt động trên nhiều ngôn ngữ, framework và loại module.

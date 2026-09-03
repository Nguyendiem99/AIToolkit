# Thiết kế kiểm tra tính phù hợp của responsibility kiến trúc — Phase 1

## Trạng thái và quyết định

Thiết kế này xử lý `AITOOLKIT-ISSUE-architecture-responsibility-conformance.md` bằng cách bổ sung một contract responsibility không phụ thuộc ngôn ngữ vào workflow migration.

Phase 1 đóng false-positive quan trọng nhất: implementation không được nhận structural PASS chỉ vì path và symbol thực tế khớp approved file tree. Structural conformance chỉ PASS khi tree shape, responsibility ownership và verification ownership đều có verdict PASS độc lập.

Phase 1 chưa tự động hóa remediation sau implementation. Architecture-audit artifact, chèn remediation work item và thay thế plan tự động được để sang Phase 2. Trong Phase 1, responsibility defect làm workflow dừng và yêu cầu design/master-plan revision được duyệt qua revision mechanism hiện có.

## Vấn đề

Target-structure contract hiện tại kiểm tra target exemplar, planned path/symbol, boundary owner, activation và planned-versus-actual tree. Nó chưa chứng minh một planned hoặc actual owner có đang chứa nhiều reason-to-change, capability, public entry point hoặc external effect độc lập hay không.

Vì vậy một design aggregate có thể tự khai báo các aggregate file là approved tree. Implementation sau đó khớp chính xác tree này và vượt structural checks, dù feature ownership không còn reviewable, testable hoặc revertible độc lập.

Invariant đang thiếu là:

```text
Tree conformance không suy ra Responsibility conformance.
```

## Mục tiêu

Phase 1 phải:

1. định nghĩa một responsibility contract canonical, framework-neutral;
2. phân biệt exemplar đã được kiểm tra với exemplar phù hợp để nhân rộng;
3. bind mọi planned path/symbol với một responsibility owner rõ ràng;
4. yêu cầu evidence hoặc approval cho multi-capability co-location;
5. bind production responsibility với test thực sự exercise production owner;
6. chặn responsibility defect trước target mutation;
7. so sánh planned và actual responsibility sau implementation;
8. cung cấp cho AI review ba verdict về tree, responsibility và verification ownership;
9. không cho runtime/automation waiver thay đổi structural verdict;
10. không dùng rule máy móc theo số class, số dòng hoặc one-class-per-file.

## Ngoài phạm vi

Phase 1 không:

- bắt mỗi class, function, component hoặc test phải có file riêng;
- sao chép file tree của legacy source sang target;
- suy chất lượng kiến trúc chỉ từ file size, class count hoặc complexity;
- xây language-specific AST analyzer;
- refactor target debt không thuộc selected work item;
- thay thế behavior, parity, activation, security hoặc runtime verification;
- tự động tạo hoặc chạy structural-remediation work item.

## Hướng kiến trúc

Thêm `aitoolkit/contracts/file-responsibility-conformance.md` làm nguồn canonical duy nhất cho responsibility tables, enums, co-location semantics, coverage rules, verdicts và waiver behavior.

`target-structure-conformance.md` vẫn là contract điều phối structural canonical. Nó tham chiếu contract mới và đổi structural PASS thành phép hội:

```text
Structural PASS =
  Tree Conformance PASS
  AND Responsibility Conformance PASS
  AND Verification Ownership PASS
  AND các selector, architecture, activation và assurance gate hiện có PASS
```

Skills và templates chỉ tham chiếu canonical responsibility contract, không sao chép lại value set.

## Mô hình dữ liệu canonical

### Contract version

Mọi artifact Phase 1 có responsibility evidence phải khai báo discriminator sau trong bounded front matter, trước khi validator đọc các matrix:

```yaml
responsibility_contract:
  version: 1
  applicability: required
```

Chỉ version `1` và applicability `required` được executable trong Phase 1. Missing, duplicate, unsupported, mixed-version hoặc cross-run responsibility evidence đều `blocked`; validator không được đoán version từ việc một heading có tồn tại hay không.

### Phân loại exemplar

Discovery giữ riêng trạng thái đã kiểm tra và mức phù hợp để nhân rộng:

```text
Inspection Status: verified | no-equivalent | unknown
Classification: preferred | compatibility-only | legacy-debt | no-equivalent
Classification Authority: <project-pack rule | approved owner decision | factual discovery evidence>
Classification Evidence: <exact immutable reference>
```

- `preferred`: target pattern đã được kiểm tra và phù hợp để mở rộng.
- `compatibility-only`: code mới phải tương thích nhưng không được sao chép ownership pattern nếu thiếu approved deviation.
- `legacy-debt`: target debt đã biết; đây là compatibility evidence, không phải authority cho cấu trúc mới.
- `no-equivalent`: không có target pattern tương đương; incremental cần approved deviation, greenfield cần exact approved design authority.

Classification không phải self-attestation của discovery agent:

- `no-equivalent` cần factual discovery evidence chứng minh không có target pattern so sánh được;
- `preferred` cần repeated working target evidence và không có authoritative source mâu thuẫn;
- `compatibility-only` cần project-pack rule hoặc approved owner decision;
- `legacy-debt` cần project documentation, existing debt record hoặc Tech Lead-approved conflict decision.

Agent không được tự gắn `compatibility-only` hoặc `legacy-debt` chỉ từ nhận định chủ quan.

`preserve-existing` nghĩa là tương thích với target architecture và approved extension points. Nó không biến mọi aggregate file đang tồn tại thành preferred exemplar.

### File Responsibility Matrix

Mỗi tuple `(Planned Path, Planned Symbol)` có đúng một responsibility row. Quy tắc áp dụng cho production, config, integration và verification owner để coverage với Planned File Tree là exact và hai chiều.

| Cột | Contract |
|---|---|
| Responsibility ID | ID `RESP-*` ổn định và duy nhất trong design revision |
| Owner Path | Exact planned file/module path |
| Owner Symbol | Exact qualified primary symbol hoặc module export |
| Boundary Kind | `domain`, `data`, `application`, `presentation`, `adapter`, `integration`, `config`, `test` hoặc `project-defined` |
| Primary Responsibility | Primary reason-to-change cụ thể; placeholder và generic architecture claim không hợp lệ |
| Owned Capability IDs | Danh sách non-empty chỉ gồm các capability độc lập mà owner sở hữu |
| Trace IDs | Requirement, acceptance, mapping và work-item IDs liên quan; nhiều trace của cùng capability không tạo multi-capability ownership |
| Atomic Boundary ID | Exact stable boundary ID cho `atomic-owner`; `not-applicable` với policy khác |
| Public Symbols | Exact planned public class, function, provider, route, handler hoặc export; chỉ dùng `none` khi đúng sự thật |
| External Effects | Exact service call, write, subscription, routing, filesystem, network, process effect hoặc `none` |
| Target Exemplar | Exact `path#qualified-symbol` hoặc `no-equivalent` |
| Exemplar Classification | Classification canonical ở trên |
| Classification Authority | Exact authority cho exemplar classification |
| Classification Evidence | Exact immutable evidence của authority |
| Architecture Authority | `target-exemplar`, `approved-greenfield-design` hoặc `approved-structural-deviation` |
| Co-location Policy | Policy canonical ở phần tiếp theo |
| Co-location Evidence | Exact evidence và rationale; chỉ dùng `not-applicable` khi contract cho phép |
| Verification Owner References | Một hoặc nhiều `VERIFY-OWNER-*` ID cho non-verification owner; `not-applicable` cho verification owner |
| Conformance | `yes`, `no` hoặc `blocked` |
| Deviation Reference | Exact approved `DEV-*` hoặc `not-applicable` |

`Responsibility ID` là stable key để plan-waves và implementation report tham chiếu. Path/symbol vẫn là authority cho tree coverage; một ID không được che giấu tuple đã đổi.

`Owner Symbol` là primary public owner hoặc module export, không phải mọi class/function trong file. `Public Symbols` liệt kê toàn bộ planned public API thuộc responsibility đó. Private helper không cần responsibility row riêng. Một responsibility có thể sở hữu nhiều feature-local symbol khi chúng có cùng capability, lifecycle, verification và revert boundary. Extra actual public symbol, provider, route, handler hoặc external effect luôn là unplanned ownership dù path vẫn khớp.

### Co-location policy

Các policy hợp lệ:

- `feature-local`: state, controller và private helper cùng một capability, lifecycle, verification owner và reason-to-change;
- `shared-foundation`: generic abstraction sở hữu một shared capability riêng, không chứa concrete feature registration, route, handler hoặc feature-specific behavior;
- `atomic-owner`: nhiều behavior thật sự dùng chung một transaction, lifecycle, test và revert boundary không thể tách;
- `approved-deviation`: cấu trúc nằm ngoài preferred target evidence nhưng có exact approved deviation;
- `not-applicable`: owner đơn giản chỉ có một responsibility, không cần claim co-location.

Ownership và consumption là hai khái niệm khác nhau. Shared engine sở hữu shared capability của chính nó; nó không liệt kê mọi feature sử dụng engine là owned capability. Concrete registration vẫn thuộc concrete feature owner.

Các luật bắt buộc:

1. Nhiều distinct owned capability ID dưới cùng owner path cần rationale không placeholder và exact Tech Lead-approved deviation. Nhiều `Trace IDs` của cùng một capability không kích hoạt rule này.
2. `feature-local` yêu cầu các symbol co-located có cùng capability set, lifecycle và verification ownership.
3. `shared-foundation` không hợp lệ nếu owner đồng thời chứa concrete feature registration hoặc feature-specific effect.
4. `atomic-owner` cần `preferred` exemplar và evidence về shared transaction/lifecycle/revert boundary; nếu không phải dùng `approved-deviation`.
5. `compatibility-only`, `legacy-debt` và incremental `no-equivalent` không thể conform nếu thiếu exact approved deviation.
6. Các câu như “cùng module”, “code liên quan”, “dễ quản lý” hoặc “theo kiến trúc hiện tại” không phải evidence.
7. Approved deviation hợp lệ có thể làm responsibility gate PASS trong khi row vẫn ghi `Conformance = no`; contract không đổi tên deviation thành native conformance.

Architecture authority tách greenfield design khỏi deviation:

- incremental dùng target exemplar hợp lệ với `Architecture Authority = target-exemplar`;
- incremental `no-equivalent` hoặc cấu trúc lệch exemplar dùng `approved-structural-deviation` và exact `DEV-*`;
- greenfield `no-equivalent` dùng `approved-greenfield-design` và exact approved design revision;
- không tạo `DEV-*` giả chỉ vì greenfield chưa có target exemplar.

### Verification Ownership Matrix

| Cột | Contract |
|---|---|
| Verification Owner ID | ID `VERIFY-OWNER-*` ổn định và duy nhất |
| Production Responsibility ID | Exact non-test `RESP-*` owner |
| Capability ID | Exact capability được production owner sở hữu |
| Evidence Path | Exact test, artifact, generated output hoặc structural evidence path |
| Evidence Symbol or Scenario | Exact test, scenario, generator check hoặc evidence ID |
| Evidence Kind | `unit`, `integration`, `contract`, `production-composition`, `static-structure` hoặc `generator-verification` |
| Verification Disposition | `required` hoặc `not-applicable-approved` |
| Production Binding Evidence | Evidence chứng minh verification exercise/inspect production owner thật; hoặc exact approved rationale cho controlled not-applicable route |
| Decision Reference | Exact owner/approval decision khi disposition là `not-applicable-approved`; ngược lại `not-applicable` |
| Verdict | `PASS` hoặc `BLOCKED` |
| Deviation Reference | Exact approved `DEV-*` hoặc `not-applicable` |

Mọi non-verification responsibility phải có ít nhất một verification row tương ứng. Coverage là hai chiều: mọi referenced verification owner phải tồn tại; mọi verification-ownership row phải resolve được production responsibility và capability thật.

`not-applicable-approved` không phải Evidence Kind. Nó chỉ hợp lệ cho config, manifest, generated owner, schema hoặc build wiring khi có exact decision, owner và rationale. Behavior, routing, lifecycle, external effect, destructive action và production composition không được dùng disposition này.

Claim về router, ordering, registration và composition cần `production-composition` evidence. Duplicate constant, fake registry, test-only composition hoặc copied metadata không chứng minh được production composition.

Một verification owner có thể cover nhiều production responsibility bằng nhiều row riêng. Nhờ đó aggregate test/artifact vẫn được phép nhưng traceability theo owner không bị mất.

### Actual responsibility evidence

Implementation report có `Actual File Responsibility Matrix` và `Actual Verification Ownership Matrix`.

Actual responsibility table giữ nguyên mọi approved planned field và thêm `Actual Evidence`, trỏ tới final diff, inspected symbol/effect hoặc implementation evidence cụ thể. Actual evidence được so hai chiều với approved design:

- không planned responsibility nào được biến mất;
- không xuất hiện unplanned owner, public symbol, capability hoặc external effect;
- co-location không rộng hơn policy đã duyệt;
- verification binding vẫn trỏ production owner thật;
- path equality không ghi đè responsibility mismatch.

Authority được phân định rõ:

- generic validator kiểm tra contract version, schema, enum, cardinality, ID và cross-reference;
- code-migration agent ghi actual symbol/effect inventory kèm source/diff evidence;
- AI review independently inspect final source/diff và xác minh inventory không thiếu owner, public symbol hoặc external effect;
- implementation self-attestation không đủ để tạo final Responsibility PASS.

Phase 1 không giả vờ rằng một framework-neutral Markdown validator có thể tự phát hiện public symbol/effect của mọi ngôn ngữ. Final semantic responsibility verdict thuộc architecture-first AI review.

## Tích hợp workflow

### Discovery

`Comparable Target Exemplars` bổ sung `Classification`, `Classification Authority`, `Classification Evidence`, `Primary Responsibility`, `Owned Capabilities` và `Verification Owner`.

Với incremental, tám canonical structural concern vẫn phải có exact coverage. `unknown` vẫn block. Exemplar đã verified nhưng chưa có classification hợp lệ vẫn incomplete. `no-equivalent` được chuyển qua gaps/conflicts thay vì trở thành convention do agent tự nghĩ.

Greenfield discovery có thể ghi `no-equivalent`; design authority sau đó đến từ exact human-approved design revision.

### Technical design

Technical design thêm đúng một `File Responsibility Matrix` và một `Verification Ownership Matrix` sau `Planned File Tree`.

Trước khi design complete, validator yêu cầu:

1. exact bidirectional `(path, symbol)` coverage giữa Planned File Tree và File Responsibility Matrix;
2. unique responsibility/verification-owner IDs;
3. capability, trace và verification reference hợp lệ;
4. exemplar classification và co-location policy hợp lệ;
5. exact deviation approval khi cần;
6. không có planned public owner chưa được sở hữu;
7. không có production responsibility thiếu verification ownership hợp lệ.

Failure tạo `status: draft`, `result: blocked`. Blocked design không được cấp executable selector.

### Plan waves

Phase 1 thêm `Responsibility Owner References` vào mỗi planned implementation unit. Giá trị là exact ordered set các `RESP-*` ID thuộc unit.

Plan validation yêu cầu:

- mọi referenced responsibility thuộc approved design revision;
- không responsibility nào được gán sang unrelated work item nếu thiếu approved decomposition decision;
- shared-foundation, concrete feature và integration/composition owner vẫn phân biệt được;
- unit vẫn independently implementable, reviewable, testable và revertible theo approved owner set.

Plan-waves không tái định nghĩa responsibility schema.

### Code migration pre-edit gate

Trước RED/TDD, baseline capture, worktree mutation hoặc target edit, code migration:

1. resolve explicit approved design/plan revisions;
2. validate hai responsibility matrices theo canonical contract;
3. resolve exact responsibility-owner set của selected work item;
4. kiểm tra exemplar classification và deviation approval;
5. ghi ba responsibility-related verdict.

Bất kỳ responsibility, verification-ownership, exemplar, selector hoặc approval failure nào đều tạo `status: draft`, `result: blocked` và dừng trước mutation. Failure này không đi vào environment-waiver classifier.

### Sau implementation và AI review

Code migration ghi actual matrices từ final task tree. Nếu actual ownership khác approved ownership, implementation vẫn nằm trong isolated worktree, report là `draft/blocked`, queue không advance và delivery bị cấm.

AI review kiểm tra theo thứ tự:

```text
master/work-item alignment
-> project rule resolution
-> canonical selector
-> tree conformance
-> responsibility conformance
-> verification ownership
-> activation path
-> behavior/security/performance
-> change hygiene
```

Review report ghi:

```text
Tree Conformance Verdict: PASS | BLOCKED
Responsibility Conformance Verdict: PASS | BLOCKED
Verification Ownership Verdict: PASS | BLOCKED
```

Bất kỳ verdict `BLOCKED` nào cũng làm overall review `Reject`. Unapproved aggregate boundary ít nhất là Major. Nó là Critical nếu gây ra hoặc che giấu lỗi activation, routing, lifecycle, destructive action, security/data ownership hoặc production verification.

### Downstream handoff và terminal completion

`architecture_conformance_state` vẫn là assurance state top-level canonical; không tạo ba assurance state top-level mới. Giá trị này được derive, không được caller tự khai:

```text
architecture_conformance_state = PASS
chỉ khi:
  Tree Conformance Verdict = PASS
  AND Responsibility Conformance Verdict = PASS
  AND Verification Ownership Verdict = PASS
```

Ba sub-verdict cùng exact evidence references phải được preserve qua `verification-testing`, parity, regression, knowledge-base, migrate orchestrator và terminal scope report. Downstream artifact không được chỉ copy aggregate PASS rồi làm mất provenance.

Bất kỳ sub-verdict `BLOCKED` nào phải giữ `architecture_conformance_state: BLOCKED`, dừng orchestrator, cấm parity/regression/delivery/KB completion và không được vào runtime-waiver classifier. Terminal completion formula phải resolve sub-verdict evidence từ immutable terminal artifact trước khi chấp nhận aggregate architecture PASS.

## Failure behavior và diagnostics

Diagnostics phải ổn định và cụ thể:

- `responsibility-owner-missing`
- `responsibility-owner-extra`
- `responsibility-capability-mismatch`
- `responsibility-public-symbol-mismatch`
- `responsibility-external-effect-mismatch`
- `co-location-policy-invalid`
- `co-location-approval-missing`
- `debt-exemplar-propagation`
- `verification-owner-missing`
- `verification-owner-extra`
- `verification-production-binding-missing`
- `production-composition-test-missing`
- `verification-disposition-invalid`
- `exemplar-classification-authority-missing`
- `greenfield-authority-invalid`
- `responsibility-contract-version-invalid`
- `responsibility-contract-version-mixed`
- `responsibility-waiver-forbidden`

Nếu defect được phát hiện sau implementation, Phase 1 phải chứng minh chuỗi stop an toàn sau: implementation `draft/blocked` → AI review `Reject` → queue không advance → dependent work không được chọn → parity/regression/delivery/KB/terminal completion bị cấm → yêu cầu approved design/master-plan revision. Isolated task tree được giữ làm evidence; workflow không amend từng path rời rạc hoặc tiếp tục dependent feature trên rejected ownership tree.

Runtime `auto-waive` không bao giờ được đổi Tree, Responsibility hoặc Verification Ownership từ BLOCKED thành PASS.

## Compatibility và rollout

Completed historical artifact trước v1 vẫn đọc được ở chế độ `historical-only` nhưng không tự động trở thành responsibility-conformance evidence.

Existing in-progress design/plan thiếu v1 là non-executable ở production mutation tiếp theo. Nó phải có approved design/master-plan revision backfill discriminator, matrices và owner references. Run mới bắt buộc v1. Cross-run hoặc mixed-version responsibility evidence bị block. Toolkit không silently grandfather unproven tree vì như vậy sẽ giữ nguyên false-positive mà issue này cần sửa.

Đây là safe migration boundary có chủ đích, không phải yêu cầu tự động refactor completed target code.

## Phạm vi file dự kiến thay đổi

Phase 1 dự kiến thay đổi:

- `aitoolkit/contracts/file-responsibility-conformance.md` (mới);
- `aitoolkit/contracts/target-structure-conformance.md`;
- các skill discovery, technical-design, plan-waves, code-migration, AI-review, verification-testing, parity, regression, knowledge-base và migrate orchestrator;
- các template discovery, technical-design, plan, implementation, review, verification, parity, regression, KB và terminal scope report;
- schema routing/documentation tham chiếu contract mới;
- target-conformance và structural-gate validation;
- một focused responsibility-conformance validator hoặc shared validation helper;
- scenario/mutation tests cho schema, cross-reference, gate, waiver và review behavior.

Implementation phải centralize Markdown table parsing và responsibility semantics thay vì copy validator giữa các workflow stage.

## Thiết kế test

Focused contract scenarios bao phủ:

1. reject multi-capability aggregate thiếu approval;
2. tree conformance PASS nhưng responsibility conformance BLOCKED vì extra actual symbol/effect;
3. accept feature-local state, controller và private helper;
4. accept shared engine với concrete registration tách riêng;
5. reject việc nhân rộng `legacy-debt` exemplar;
6. reject test-only composition proof;
7. accept atomic co-location có preferred evidence và Tech Lead approval;
8. giữ cùng semantics cho UI, backend và adapter/data artifact fixtures;
9. accept nhiều Trace IDs thuộc cùng một capability mà không kích hoạt multi-capability gate;
10. accept legitimate static/generated/config verification qua controlled evidence route;
11. accept approved greenfield design authority mà không tạo structural deviation;
12. reject classification thiếu authority/evidence;
13. reject mixed/missing responsibility contract version;
14. reject implementation self-attestation khi independent AI review phát hiện inventory thiếu;
15. chứng minh post-implementation mismatch dừng queue và mọi downstream completion.

Mutation coverage gồm: xóa/duplicate matrix row, path/symbol drift, capability/trace drift, extra public symbol/effect, đổi classification/authority, giả greenfield deviation, thiếu approval/rationale, fake verification binding, invalid not-applicable disposition, mixed contract version, mixed sentinel, malformed Markdown framing và cố dùng runtime waiver ghi đè structural verdict.

Verification chạy theo phạm vi tăng dần:

1. focused responsibility-contract scenarios;
2. target-conformance và structural-gate scenarios;
3. selectors Skills, Templates, Contracts và All;
4. source-integrity và syntax checks;
5. full migration mutation suite đúng một lần trên final tree.

## Acceptance criteria

Phase 1 hoàn thành khi:

- canonical responsibility contract tồn tại và được tham chiếu thay vì copy;
- exemplar inspection và exemplar suitability là hai field độc lập;
- exemplar classification có exact authority và evidence hợp lệ;
- `Owned Capability IDs` tách khỏi `Trace IDs`; nhiều trace của cùng capability không kích hoạt multi-capability violation;
- greenfield approved design dùng `approved-greenfield-design`, không bị biểu diễn thành structural deviation;
- planned tree và responsibility rows có exact bidirectional path/symbol coverage;
- multi-capability ownership thiếu required evidence/approval bị block trước mutation;
- actual responsibility được so với planned responsibility;
- legitimate static/generated/config owner có controlled verification route; behavior/routing/lifecycle/effect không được miễn verification;
- mọi production responsibility có production-bound verification ownership;
- AI review ghi đủ ba verdict;
- AI review independently xác minh actual inventory; implementation self-attestation không đủ tạo PASS;
- responsibility sub-verdict và evidence được preserve tới terminal completion;
- responsibility contract version được resolve trước matrix validation và mixed-version bị block;
- extra actual public symbol/effect bị block dù path vẫn khớp;
- post-implementation mismatch dừng queue, dependent selection và delivery trong Phase 1;
- runtime waiver không thể thay đổi responsibility verdict;
- feature-local, shared-foundation và approved atomic co-location hợp lệ vẫn được accept;
- cross-language fixtures nhận cùng semantic verdict;
- existing in-progress plan thiếu evidence không được silently resume;
- mọi focused/full verification gate PASS trên final implementation tree.

Sau Phase 1, trạng thái issue phải được ghi chính xác:

```text
Core false-positive: fixed
Prevention gates: complete
Safe post-implementation stop: complete
Automated remediation: pending Phase 2
Original issue: partially resolved
```

## Phase 2 để lại

Phase 2 sẽ thiết kế và triển khai automated structural-remediation route:

- immutable architecture-audit artifact;
- biểu diễn automatic queue pause;
- approved responsibility-tree replacement revision;
- chèn structural-remediation work item;
- scan future work bị ảnh hưởng;
- re-review và terminal-verification routing.

Phase 2 phải dùng lại Phase 1 contract, không tạo responsibility model thứ hai.

Original issue chỉ được đóng hoàn toàn sau khi Phase 2 hoàn tất automated remediation và các acceptance liên quan. Phase 1 không được đánh dấu toàn bộ issue là closed.

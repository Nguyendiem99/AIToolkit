# Kế hoạch triển khai Scope Orchestration linh động cho Migration

> **Dành cho agent thực thi:** BẮT BUỘC dùng `superpowers:subagent-driven-development` (khuyến nghị) hoặc `superpowers:executing-plans` để triển khai lần lượt từng task. Mọi bước dùng checkbox `- [ ]` để theo dõi.

**Mục tiêu:** Bổ sung master spec/master plan bắt buộc, generic work items theo dependency, delivery adapter tùy chọn có canonical selector và target-structure evidence gate cho AIToolKit migration.

**Kiến trúc:** Thêm scope plane bền vững phía trên execution plane hiện có. Scope plane dùng các revision Markdown bất biến để quản lý requested scope, dependency graph, queue, resume và completion; execution plane tiếp tục xử lý đúng một item nguyên tử. Validator được tách thành module để các nhóm scope, adapter và conformance có thể triển khai song song rồi tích hợp qua interface cố định.

**Công nghệ:** Markdown skill/contract/template, PowerShell tương thích Windows PowerShell 5.1, Git worktree.

**Spec:** `docs/superpowers/specs/2026-08-19-flexible-migration-scope-orchestration-design-vi.md`

## Ràng buộc toàn cục

- Mọi migration làm thay đổi production target phải có `master-spec.md` và `master-plan.md` đã duyệt.
- `work_item` là khái niệm tổng quát; `migration_unit_id` chỉ xuất hiện qua delivery adapter tùy chọn.
- Phiên bản đầu chỉ thực thi một work item tại một thời điểm: `max_concurrency: 1`.
- Approved master revision và execution attempt là bất biến.
- Resume chọn item theo thứ tự: dependency depth, `Plan Order`, rồi ordinal `Work Item ID`.
- Incremental migration phải có exemplar hoàn chỉnh hoặc approved no-equivalent decision.
- Architecture, selector và schema blocker không bao giờ được waiver.
- Giữ nguyên one-unit-one-change, immediate predecessor, Activation Slice, baseline waiver và foundation baseline hiện có.
- PowerShell không dùng cú pháp chỉ có trong PowerShell 7.
- Mutation test chỉ sửa isolated temporary copy và phải chứng minh source checkout không đổi byte.
- Giữ UTF-8, không tạo line-ending hoặc formatting churn ngoài phạm vi.
- Không ghi đè thay đổi đang có trong `aitoolkit/skills/aitoolkit/migrate/SKILL.md`; Task 1 phải ghi nhận và đối chiếu exact diff trước.

---

## Đánh giá khả năng chạy song song

Không nên mở tất cả worktree ngay từ đầu vì bốn file là shared hotspot:

```text
aitoolkit/skills/aitoolkit/migrate/SKILL.md
aitoolkit/skills/aitoolkit-schemas/SKILL.md
aitoolkit/tests/validate-migration-framework.ps1
aitoolkit/tests/validate-migration-framework.Tests.ps1
```

Hai wave đầu phải chạy tuần tự để ổn định baseline và định nghĩa interface. Sau đó bốn task có thể chạy song song trong worktree riêng vì mỗi task sở hữu tập file khác nhau.

| Wave | Task | Song song | Mục tiêu |
|---|---|---|---|
| 0 | Task 1 | Không | Làm sạch baseline và cô lập mutation tests |
| 1 | Task 2 | Không | Tạo contract, schema và validator interfaces |
| 2 | Task 3, 4, 5, 6 | Có, tối đa bốn worktree | Artifact, orchestrator, adapter và conformance |
| 3 | Task 7, 8 | Có, sau dependency của Wave 2 | Pre-edit gate và architecture-first review |
| 4 | Task 9 | Không | Merge, compatibility, E2E và nghiệm thu |

### Worktree đề xuất

Chạy từ `C:\Users\diemnk2\Downloads\AIToolkit\AIToolkit\AIToolkit-main` sau commit của Task 2:

```powershell
git worktree add .claude/worktrees/fmso-artifacts -b fmso/artifacts
git worktree add .claude/worktrees/fmso-orchestrator -b fmso/orchestrator
git worktree add .claude/worktrees/fmso-adapters -b fmso/adapters
git worktree add .claude/worktrees/fmso-conformance -b fmso/conformance
```

Mọi worktree phải bắt đầu từ cùng commit hoàn tất Wave 1. Không merge branch task trực tiếp vào nhau; chỉ merge về integration branch.

### Quyền sở hữu file khi chạy song song

| Task | File/nhóm file sở hữu độc quyền |
|---|---|
| Task 3 | master templates và `scope-artifacts.validation.ps1` |
| Task 4 | `migrate/SKILL.md` và `scope-engine.validation.ps1` |
| Task 5 | plan-waves, migration-plan template và `delivery-adapters.validation.ps1` |
| Task 6 | discovery/technical-design skills/templates và `target-conformance.validation.ps1` |
| Task 7 | code-migration, implementation-report và `structural-gate.validation.ps1` |
| Task 8 | AI Review, Knowledge Base, review/KB templates và `architecture-review.validation.ps1` |

Task 9 là task duy nhất được sửa danh sách dispatch chung của validator, schema aggregation cuối cùng và end-to-end fixtures sau khi merge các nhánh song song.

---

### Task 1: Khôi phục baseline tin cậy và cô lập mutation tests

**File:**
- Sửa: `aitoolkit/tests/validate-migration-framework.ps1`
- Sửa: `aitoolkit/tests/validate-migration-framework.Tests.ps1`
- Sửa sau khi duyệt exact diff: `aitoolkit/skills/aitoolkit/migrate/SKILL.md`
- Tạo: `aitoolkit/tests/helpers/IsolatedFixture.ps1`

**Interface:**
- Nhận: validator selectors hiện có, source-root resolution, mutation fixtures và dirty diff của migrate skill.
- Cung cấp: tham số `-Root`, isolated fixture helper, byte-integrity assertion và baseline validator pass.

- [ ] **Bước 1: Ghi nhận dirty state trước khi sửa**

Chạy:

```powershell
git status --short
git diff -- aitoolkit/skills/aitoolkit/migrate/SKILL.md
git diff --check
```

Lưu exact diff vào implementation report. Xác minh dòng rời `exactly one approved migration unit` ở cuối file trùng mutation locality của test và không xóa thay đổi người dùng không liên quan.

- [ ] **Bước 2: Viết source-integrity test đang fail**

Thêm scenario băm toàn bộ source tree trước và sau một mutation:

```powershell
$before = Get-TreeDigest -Root $SourceRoot
Invoke-IsolatedMutation -SourceRoot $SourceRoot -Mutation $mutation
$after = Get-TreeDigest -Root $SourceRoot
Assert-True ($after -ceq $before) 'Mutation suite changed source checkout bytes'
```

Chạy:

```powershell
& .\aitoolkit\tests\validate-migration-framework.Tests.ps1 -SourceIntegrityOnly
```

Kỳ vọng RED: test hiện tại ghi trực tiếp lên repository và phụ thuộc vào restore.

- [ ] **Bước 3: Hiện thực isolated fixture helper**

Tạo đúng bốn function:

```powershell
function New-IsolatedAitoolkitFixture([string]$SourceRoot) { }
function Get-TreeDigest([string]$Root) { }
function Invoke-IsolatedMutation([string]$SourceRoot, [scriptblock]$Mutation) { }
function Remove-IsolatedAitoolkitFixture([string]$FixtureRoot) { }
```

`New-IsolatedAitoolkitFixture` tạo thư mục duy nhất dưới `[IO.Path]::GetTempPath()`, copy cây `aitoolkit` và trả absolute path. `Get-TreeDigest` sort canonical relative paths theo ordinal rồi hash path cộng raw bytes. Cleanup chỉ nhận validated temp path, tuyệt đối không nhận source path.

- [ ] **Bước 4: Parameterize validator root**

Thêm vào parameter block:

```powershell
[string]$Root = (Join-Path $PSScriptRoot '..')
```

Resolve đúng một lần bằng `[IO.Path]::GetFullPath($Root)`. Mọi path contract/template/skill/test phải xuất phát từ root này.

- [ ] **Bước 5: Chuyển mọi mutation sang isolated copy**

Dùng mẫu:

```powershell
$fixtureRoot = New-IsolatedAitoolkitFixture -SourceRoot $sourceRoot
try {
  $fixturePath = Join-Path $fixtureRoot $fixture.RelativePath
  [IO.File]::WriteAllText($fixturePath, $mutatedText, [Text.UTF8Encoding]::new($false))
  $result = Invoke-Validator -Target $fixture.Check -Root $fixtureRoot
}
finally {
  Remove-IsolatedAitoolkitFixture -FixtureRoot $fixtureRoot
}
```

- [ ] **Bước 6: Khôi phục selector locality tối thiểu**

Trong `## Mode and migration unit gate`, khôi phục yêu cầu `migration_unit_id` resolve đúng một approved migration unit. Chỉ xóa token rời ở EOF; không thay nội dung khác.

- [ ] **Bước 7: Chạy GREEN baseline**

```powershell
& .\aitoolkit\tests\validate-migration-framework.ps1 -Target All
& .\aitoolkit\tests\validate-migration-framework.Tests.ps1 -SourceIntegrityOnly
& .\aitoolkit\tests\validate-migration-framework.Tests.ps1
git diff --check
```

Kỳ vọng: tất cả exit 0 và source digest không đổi.

- [ ] **Bước 8: Commit**

```powershell
git add aitoolkit/tests aitoolkit/skills/aitoolkit/migrate/SKILL.md
git commit -m "test: isolate migration framework mutations"
```

---

### Task 2: Định nghĩa scope và conformance contracts dùng chung

**File:**
- Tạo: `aitoolkit/contracts/migration-scope-orchestration.md`
- Tạo: `aitoolkit/contracts/target-structure-conformance.md`
- Tạo: `aitoolkit/tests/validation/scope-artifacts.validation.ps1`
- Tạo: `aitoolkit/tests/validation/scope-engine.validation.ps1`
- Tạo: `aitoolkit/tests/validation/delivery-adapters.validation.ps1`
- Tạo: `aitoolkit/tests/validation/target-conformance.validation.ps1`
- Tạo: `aitoolkit/tests/validation/structural-gate.validation.ps1`
- Tạo: `aitoolkit/tests/validation/architecture-review.validation.ps1`
- Sửa: `aitoolkit/skills/aitoolkit-schemas/SKILL.md`
- Sửa: `aitoolkit/tests/validate-migration-framework.ps1`

**Interface:**
- Nhận: spec đã duyệt và artifact/front-matter convention hiện tại.
- Cung cấp: enum/table chuẩn, function signature cho validator modules, schema additions và dispatch seam.

- [ ] **Bước 1: Viết contract-resource tests đang fail**

Test sự tồn tại của hai contract, exact enum, exact table columns, adapter shape, independent assurance states và revision rules.

```powershell
& .\aitoolkit\tests\validate-migration-framework.ps1 -Target Contracts
```

Kỳ vọng RED: resource và token mới chưa tồn tại.

- [ ] **Bước 2: Tạo scope orchestration contract**

Định nghĩa chính xác bốn bảng:

```text
Requested Scope: Kind, ID, Statement, Source, Resolution Evidence
Work Item: Work Item ID, Title, Required, Dependencies, Plan Order, Acceptance, Trace IDs, Delivery Adapter, Status, Latest Attempt, Terminal Evidence, Approval Reference
Attempt: Attempt ID, Work Item ID, Plan Revision, Status, Artifact Reference
Revision: Artifact ID, Revision, Supersedes, Change Summary, Affected Work Items, Approval Reference
```

Ghi selection order, transition table, terminal-success states, cycle/missing-node behavior, resume reconciliation và scope-completion formula đúng theo spec.

- [ ] **Bước 3: Tạo target-structure contract**

Định nghĩa:

```text
Comparable Target Exemplars: Concern, Path, Inspected Symbols, Observed Pattern, Comparable Reason, Evidence, Status
Target Structure Conformance Matrix: Concern, Working Exemplar, Observed Target Pattern, Proposed Path/Symbol, Conforms, Deviation Reference
Assurance State: Runtime Evidence State, Architecture Conformance State, Selector Schema State
```

Khai báo đủ tám exemplar concerns và các finding bắt buộc của architecture-first review.

- [ ] **Bước 4: Khai báo validator interfaces**

Mỗi module export đúng một entry function:

```powershell
function Test-ScopeArtifacts([string]$Root, [string]$ContractText) { }
function Test-ScopeEngine([string]$Root, [string]$ContractText) { }
function Test-DeliveryAdapters([string]$Root, [string]$ContractText) { }
function Test-TargetConformance([string]$Root, [string]$ContractText) { }
function Test-StructuralGate([string]$Root, [string]$ContractText) { }
function Test-ArchitectureReview([string]$Root, [string]$ContractText) { }
```

Task này chỉ tạo interface và dispatch. Logic chi tiết thuộc task sở hữu module.

- [ ] **Bước 5: Mở rộng schema, giữ legacy read**

Thêm master spec, master plan, work item, adapter, revision, attempt và assurance-state contracts. Ghi rõ historical unit-only artifact chỉ đọc được; không resume tới production mutation trước compatibility conversion.

- [ ] **Bước 6: Chạy validator**

Dot-source sáu module, gọi chúng từ target tương ứng, chạy `Contracts` và legacy `All`. Empty body chỉ được chấp nhận trong commit foundation này; Task 9 phải loại bỏ mọi empty/unreachable module.

- [ ] **Bước 7: Commit**

```powershell
git add aitoolkit/contracts aitoolkit/tests/validation aitoolkit/skills/aitoolkit-schemas/SKILL.md aitoolkit/tests/validate-migration-framework.ps1
git commit -m "feat: define migration scope contracts"
```

---

### Task 3: Master spec và master plan artifacts

**Worktree:** `.claude/worktrees/fmso-artifacts`
**Branch:** `fmso/artifacts`

**File:**
- Tạo: `aitoolkit/templates/migration/master-spec.md`
- Tạo: `aitoolkit/templates/migration/master-plan.md`
- Sửa: `aitoolkit/tests/validation/scope-artifacts.validation.ps1`
- Tạo: `aitoolkit/tests/scenarios/scope-artifacts.Tests.ps1`

**Interface:**
- Nhận: schema và table definitions từ Task 2.
- Cung cấp: hai artifact có thể render và `Test-ScopeArtifacts` validation.

- [ ] **Bước 1: Viết artifact-shape scenarios đang fail**

Bao phủ missing/duplicate front matter, thiếu section, revision không liên tục, spec reference mismatch, duplicate Work Item ID/Plan Order, acceptance rỗng và approval reference thiếu.

```powershell
& .\aitoolkit\tests\scenarios\scope-artifacts.Tests.ps1
```

Kỳ vọng RED: template và validation chưa tồn tại.

- [ ] **Bước 2: Tạo master-spec template**

Dùng exact front matter và 12 section bắt buộc trong spec. Có bảng cố định cho requirements, success criteria, evidence index, approval record và revision history. Nội dung người đọc bằng tiếng Việt; machine field và enum giữ nguyên.

- [ ] **Bước 3: Tạo master-plan template**

Tạo các section:

```text
Requested Scope
Work Items
Dependency Graph
Attempt History
State Transition Log
Scope Completion Calculation
Evidence
Unknowns
Approval Record
Revision History
```

Dùng canonical Work Item columns, không thêm `Migration Unit ID` bắt buộc.

- [ ] **Bước 4: Hiện thực artifact validation**

Kiểm front-matter locality, table exactness, stable ID, unique order, dependency reference, revision-chain field và scope/work-item enums. Reject blank cell thay vì tự hiểu là `not-applicable`.

- [ ] **Bước 5: GREEN và commit**

```powershell
& .\aitoolkit\tests\scenarios\scope-artifacts.Tests.ps1
& .\aitoolkit\tests\validate-migration-framework.ps1 -Target Templates
& .\aitoolkit\tests\validate-migration-framework.ps1 -Target Encoding
git add aitoolkit/templates/migration aitoolkit/tests/validation/scope-artifacts.validation.ps1 aitoolkit/tests/scenarios/scope-artifacts.Tests.ps1
git commit -m "feat: add migration master artifacts"
```

---

### Task 4: Scope orchestrator, queue, resume và completion

**Worktree:** `.claude/worktrees/fmso-orchestrator`
**Branch:** `fmso/orchestrator`

**File:**
- Sửa: `aitoolkit/skills/aitoolkit/migrate/SKILL.md`
- Sửa: `aitoolkit/tests/validation/scope-engine.validation.ps1`
- Tạo: `aitoolkit/tests/scenarios/scope-engine.Tests.ps1`

**Interface:**
- Nhận: master artifact contracts và explicit orchestration context.
- Cung cấp: scope resolution, deterministic selection, atomic transition, resume/revision và completion.

- [ ] **Bước 1: Viết scope-resolution scenarios đang fail**

Test module, feature, explicit-item, project không dùng unit và unresolved request. Unresolved input chỉ được hỏi một scope question và không được tới step 01.

- [ ] **Bước 2: Viết graph/selection scenarios đang fail**

Kiểm công thức:

```text
eligible = required-or-approved-optional
  AND pending-or-ready
  AND dependencies-terminal-success
  AND current approval
  AND no blocker
  AND adapter-valid
  AND assurance-pass
```

Bao phủ cycle, missing node, blocked dependency, một item đang in-progress và deterministic resume.

- [ ] **Bước 3: Viết completion/revision scenarios đang fail**

Một item complete cộng một required item pending phải là `scope-in-progress`. Tất cả required items terminal-success mới là `scope-complete`. Scope change tăng revision, giữ unaffected evidence và invalidate affected approval.

- [ ] **Bước 4: Thêm scope plane vào run preparation**

Trước pipeline 15 bước, thêm thứ tự:

```text
Resolve requested scope
Create/resolve master spec
Create/resolve master plan
Validate approved revision chain
Select/resume one work item
Resolve optional adapter
Run execution pipeline
Apply atomic transition
Continue queue without repeated soft-scope prompt
```

- [ ] **Bước 5: Hiện thực resume và revision rules**

Require đúng một latest approved linear revision. Reconcile `in-progress` attempt trước khi chọn item mới. Cấm directory scan và sửa approved artifact tại chỗ.

- [ ] **Bước 6: Sửa completion semantics**

Step 15 chỉ hoàn tất execution attempt/work item hiện tại. Chỉ master plan được kết luận requested scope complete.

- [ ] **Bước 7: GREEN và commit**

```powershell
& .\aitoolkit\tests\scenarios\scope-engine.Tests.ps1
& .\aitoolkit\tests\validate-migration-framework.ps1 -Target Orchestrators
git add aitoolkit/skills/aitoolkit/migrate/SKILL.md aitoolkit/tests/validation/scope-engine.validation.ps1 aitoolkit/tests/scenarios/scope-engine.Tests.ps1
git commit -m "feat: orchestrate migration master scope"
```

---

### Task 5: Canonical delivery adapters và decomposition

**Worktree:** `.claude/worktrees/fmso-adapters`
**Branch:** `fmso/adapters`

**File:**
- Sửa: `aitoolkit/skills/migration/build-inventory/SKILL.md`
- Sửa: `aitoolkit/skills/migration/feature-mapping/SKILL.md`
- Sửa: `aitoolkit/skills/migration/analyze-gaps-conflicts/SKILL.md`
- Sửa: `aitoolkit/skills/migration/plan-waves/SKILL.md`
- Sửa: `aitoolkit/templates/migration/migration-plan.md`
- Sửa: `aitoolkit/tests/validation/delivery-adapters.validation.ps1`
- Tạo: `aitoolkit/tests/scenarios/delivery-adapters.Tests.ps1`

**Interface:**
- Nhận: generic work-item và adapter contract.
- Cung cấp: canonical mapping, decomposition trace và selector validation.

- [ ] **Bước 1: Viết adapter scenarios đang fail**

Bao phủ `none`, task/story/package adapter, valid migration-unit adapter, external-only unit, duplicate selector, stale design revision, trace mismatch và child bỏ qua steps 04–08.

- [ ] **Bước 2: Truyền work-item trace qua front-half**

Ba step liên quan phải giữ `Work Item ID`, master-plan revision, acceptance traces và decomposition decision. Child không được xuất hiện lần đầu ở plan-waves.

- [ ] **Bước 3: Cập nhật plan-waves**

Giữ canonical `UNIT-###` cho migration adapter nhưng không coi đó là taxonomy chung. Thêm `Parent Work Item ID` và `Decomposition Decision Reference`.

- [ ] **Bước 4: Cập nhật migration-plan template**

Thêm `Parent Work Item ID`, `Master Plan Reference`, `Master Plan Revision` và `Decomposition Decision Reference`. Không đưa các field này thành migration-unit requirement trong generic master plan.

- [ ] **Bước 5: Hiện thực adapter validator**

Kiểm one-to-one selector, mode/acceptance/trace/design equivalence, parent-child trace và canonical step chain. Reject ID chỉ có trong master/execution plan.

- [ ] **Bước 6: GREEN và commit**

```powershell
& .\aitoolkit\tests\scenarios\delivery-adapters.Tests.ps1
& .\aitoolkit\tests\validate-migration-framework.ps1 -Target Skills
& .\aitoolkit\tests\validate-migration-framework.ps1 -Target Templates
git add aitoolkit/skills/migration aitoolkit/templates/migration/migration-plan.md aitoolkit/tests/validation/delivery-adapters.validation.ps1 aitoolkit/tests/scenarios/delivery-adapters.Tests.ps1
git commit -m "feat: canonicalize migration delivery adapters"
```

---

### Task 6: Target exemplars và design conformance

**Worktree:** `.claude/worktrees/fmso-conformance`
**Branch:** `fmso/conformance`

**File:**
- Sửa: `aitoolkit/skills/migration/discovery/SKILL.md`
- Sửa: `aitoolkit/skills/migration/technical-design/SKILL.md`
- Sửa: `aitoolkit/templates/migration/discovery.md`
- Sửa: `aitoolkit/templates/migration/technical-design.md`
- Sửa: `aitoolkit/tests/validation/target-conformance.validation.ps1`
- Tạo: `aitoolkit/tests/scenarios/target-conformance.Tests.ps1`

**Interface:**
- Nhận: target-structure contract và evidence/unknown rules hiện tại.
- Cung cấp: exemplar inventory, conformance matrix, planned file tree và approved deviations.

- [ ] **Bước 1: Viết discovery scenarios đang fail**

Test generic-controller-only evidence, thiếu concern, inspected symbol rỗng, exemplar không comparable, approved no-equivalent gap và complete eight-concern coverage.

- [ ] **Bước 2: Viết design scenarios đang fail**

Test “use Riverpod”, thiếu planned file tree, `Conforms = no` thiếu decision, panel-wrapper mismatch, thiếu lifecycle boundary và complete conforming design.

- [ ] **Bước 3: Mở rộng discovery skill/template**

Thêm:

```text
Comparable Target Exemplars
Inspected Symbols
Target Data-flow Trace
No-equivalent Gaps
```

Discovery block khi applicable concern thiếu hoặc unknown.

- [ ] **Bước 4: Mở rộng technical-design skill/template**

Thêm:

```text
Target Structure Conformance Matrix
Approved Structural Deviations
Planned File Tree
Provider/Router/Localization/Subscription Boundaries
```

Mọi non-conforming row phải có resolved decision.

- [ ] **Bước 5: Hiện thực conformance validator**

Parse contract-derived concerns và exact columns. Require path, symbol, comparable reason, evidence, proposed path/symbol và decision semantics không rỗng.

- [ ] **Bước 6: GREEN và commit**

```powershell
& .\aitoolkit\tests\scenarios\target-conformance.Tests.ps1
& .\aitoolkit\tests\validate-migration-framework.ps1 -Target Skills
& .\aitoolkit\tests\validate-migration-framework.ps1 -Target Templates
git add aitoolkit/skills/migration/discovery aitoolkit/skills/migration/technical-design aitoolkit/templates/migration/discovery.md aitoolkit/templates/migration/technical-design.md aitoolkit/tests/validation/target-conformance.validation.ps1 aitoolkit/tests/scenarios/target-conformance.Tests.ps1
git commit -m "feat: require target conformance evidence"
```

---

### Task 7: Structural pre-edit gate cho code migration

**Phụ thuộc:** Task 5 và Task 6 đã merge.

**File:**
- Sửa: `aitoolkit/skills/migration/code-migration/SKILL.md`
- Sửa: `aitoolkit/templates/migration/implementation-report.md`
- Sửa: `aitoolkit/tests/validation/structural-gate.validation.ps1`
- Tạo: `aitoolkit/tests/scenarios/structural-gate.Tests.ps1`

**Interface:**
- Nhận: approved work item, canonical adapter, conformance matrix, exemplars, planned tree và activation evidence.
- Cung cấp: non-waivable structural verdict trước edit và actual/planned evidence.

- [ ] **Bước 1: Viết pre-edit scenarios đang fail**

Bao phủ missing master context, non-canonical selector, unread exemplar, file-tree mismatch, direct widget service/router call, sai localization boundary, thiếu subscription/lifecycle path, unapproved abstraction và fully conforming input.

- [ ] **Bước 2: Đặt structural gate đúng thứ tự**

```text
master scope validation
canonical adapter validation
conformance matrix validation
exemplar-read validation
planned file-tree/boundary validation
activation-path validation khi áp dụng
incremental runtime baseline gate
worktree/plan/TDD/edit
```

Architecture/selector/schema failure trả `draft/blocked` và không đi vào environment-waiver classifier.

- [ ] **Bước 3: Mở rộng implementation report**

Thêm `Master Scope Context`, `Conformance Matrix Reference`, `Actual File Tree vs Planned File Tree`, `Exemplar Deviations` và `Production Activation Path Evidence`.

- [ ] **Bước 4: Hiện thực structural validation**

Require exact master IDs/revisions, work-item ID, selector evidence, matrix reference, exemplar list, planned/actual mapping và independent assurance states.

- [ ] **Bước 5: GREEN và commit**

```powershell
& .\aitoolkit\tests\scenarios\structural-gate.Tests.ps1
& .\aitoolkit\tests\validate-migration-framework.ps1 -Target Skills
& .\aitoolkit\tests\validate-migration-framework.ps1 -Target Templates
git add aitoolkit/skills/migration/code-migration aitoolkit/templates/migration/implementation-report.md aitoolkit/tests/validation/structural-gate.validation.ps1 aitoolkit/tests/scenarios/structural-gate.Tests.ps1
git commit -m "feat: gate migration edits on structure"
```

---

### Task 8: Architecture-first review và scope-aware Knowledge Capture

**Phụ thuộc:** Task 6 đã merge; có thể chạy song song với Task 7.

**File:**
- Sửa: `aitoolkit/skills/shared/ai-review/SKILL.md`
- Sửa: `aitoolkit/skills/shared/knowledge-base/SKILL.md`
- Sửa: `aitoolkit/templates/migration/review-report.md`
- Sửa: `aitoolkit/templates/kb-entry.md`
- Sửa: `aitoolkit/tests/validation/architecture-review.validation.ps1`
- Tạo: `aitoolkit/tests/scenarios/architecture-review.Tests.ps1`

**Interface:**
- Nhận: master context, implementation report, matrix, exemplars, actual/planned tree và activation evidence.
- Cung cấp: ordered review, ba mandatory verdict và scope-aware terminal record.

- [ ] **Bước 1: Viết review-order/verdict scenarios đang fail**

Thiếu matrix hoặc selector phải block trước behavior review. Ba verdict xuất hiện đúng một lần. Một verdict blocked làm overall Reject. Thiếu production subscription key là Critical.

- [ ] **Bước 2: Sắp xếp lại AI Review**

Thực hiện thứ tự: master alignment, rule resolution, selector, architecture, activation, behavior/security/tests, change hygiene. Giữ các dimension hiện có sau architecture gates.

- [ ] **Bước 3: Mở rộng review report**

Thêm `Master Scope Context`, `Architecture Conformance`, `Canonical Selector` và `Production Activation Path` trước findings. Chỉ giữ Selected Migration Unit khi adapter là `migration-unit`.

- [ ] **Bước 4: Làm Knowledge Capture hiểu scope**

Ghi work-item verdict, master-plan transition, required items còn lại, next eligible item hoặc blocker và calculated scope status. Không báo scope complete từ một execution artifact.

- [ ] **Bước 5: Hiện thực review validator**

Kiểm section order, exact verdict enum, verdict-to-overall mapping, mandatory finding coverage và KB scope evidence.

- [ ] **Bước 6: GREEN và commit**

```powershell
& .\aitoolkit\tests\scenarios\architecture-review.Tests.ps1
& .\aitoolkit\tests\validate-migration-framework.ps1 -Target Skills
& .\aitoolkit\tests\validate-migration-framework.ps1 -Target Templates
git add aitoolkit/skills/shared/ai-review aitoolkit/skills/shared/knowledge-base aitoolkit/templates/migration/review-report.md aitoolkit/templates/kb-entry.md aitoolkit/tests/validation/architecture-review.validation.ps1 aitoolkit/tests/scenarios/architecture-review.Tests.ps1
git commit -m "feat: review migration architecture first"
```

---

### Task 9: Tích hợp, legacy conversion và end-to-end gates

**Phụ thuộc:** Tất cả task trước đã hoàn tất và merge vào integration branch.

**File:**
- Sửa: `aitoolkit/skills/aitoolkit/migrate/SKILL.md`
- Sửa: `aitoolkit/skills/aitoolkit-schemas/SKILL.md`
- Sửa: `aitoolkit/tests/validate-migration-framework.ps1`
- Sửa: `aitoolkit/tests/validate-migration-framework.Tests.ps1`
- Tạo: `aitoolkit/templates/migration/scope-terminal-report.md`
- Tạo: `aitoolkit/tests/scenarios/flexible-scope-e2e.Tests.ps1`
- Sửa: `aitoolkit/README.md`
- Sửa: `aitoolkit/docs/MIGRATION-FRAMEWORK.md`

**Interface:**
- Nhận: tất cả modules và focused scenario suites.
- Cung cấp: final orchestration, compatibility conversion, waiver separation, terminal scope report và 21 E2E scenarios.

- [ ] **Bước 1: Merge và kiểm tra từng branch**

Merge theo thứ tự Task 3, 4, 5, 6, 7, 8. Sau mỗi merge chạy focused suite của branch và `git diff --check`. Resolve theo contract name; không sao chép enum/table definition vào skill.

- [ ] **Bước 2: Viết 21 E2E fixtures đang fail**

Mỗi fixture nằm dưới isolated temp root, có explicit master spec, master plan, predecessor, target evidence và expected diagnostic/scope state. Bao phủ toàn bộ scenarios trong spec.

- [ ] **Bước 3: Hiện thực legacy conversion**

Tạo revision-1 master artifacts từ approved historical evidence, một work item cho mỗi canonical legacy unit, exact adapter reference và không suy module completion. Conversion phải qua approval gate mới trước mutation.

- [ ] **Bước 4: Tách assurance states và waiver logic**

Require:

```yaml
runtime_evidence_state: PASS | FAIL | NOT_RUN | WAIVED
architecture_conformance_state: PASS | BLOCKED
selector_schema_state: PASS | BLOCKED
```

Chỉ runtime `NOT_RUN + BLOCKED` hợp lệ được chuyển thành `NOT_RUN + WAIVED`. Architecture hoặc selector/schema blocked phải dừng queue.

- [ ] **Bước 5: Tạo terminal scope report**

Liệt kê mọi required/optional item, status, terminal evidence, assurance states, blocker, revision references và calculated terminal verdict.

- [ ] **Bước 6: Loại bỏ empty/unreachable validator module**

Mỗi module từ Task 2 phải có real entry function, ít nhất một contract-derived rule và được gọi từ public validator target.

- [ ] **Bước 7: Cập nhật tài liệu sử dụng**

Giải thích two-plane model, master artifacts, generic work items, adapter examples, resume/revision và work-item/scope completion. Có một ví dụ dùng unit và một ví dụ không dùng unit.

- [ ] **Bước 8: Chạy focused verification**

```powershell
& .\aitoolkit\tests\scenarios\scope-artifacts.Tests.ps1
& .\aitoolkit\tests\scenarios\scope-engine.Tests.ps1
& .\aitoolkit\tests\scenarios\delivery-adapters.Tests.ps1
& .\aitoolkit\tests\scenarios\target-conformance.Tests.ps1
& .\aitoolkit\tests\scenarios\structural-gate.Tests.ps1
& .\aitoolkit\tests\scenarios\architecture-review.Tests.ps1
& .\aitoolkit\tests\scenarios\flexible-scope-e2e.Tests.ps1
```

Kỳ vọng: mọi lệnh exit 0.

- [ ] **Bước 9: Chạy full verification**

```powershell
& .\aitoolkit\tests\validate-migration-framework.ps1 -Target All
& .\aitoolkit\tests\validate-migration-framework.Tests.ps1
git diff --check
git status --short
```

Kỳ vọng: tất cả validator/test pass, không có source-integrity failure và status chỉ chứa intended files.

- [ ] **Bước 10: Audit độ phủ spec**

Map từng invariant, contract và 21 scenario sang tên automated test cụ thể trong implementation report. Thiếu một mapping thì chưa hoàn tất.

- [ ] **Bước 11: Commit integration**

```powershell
git add aitoolkit docs/superpowers/specs/2026-08-19-flexible-migration-scope-orchestration-design.md docs/superpowers/plans/2026-08-19-flexible-migration-scope-orchestration.md
git commit -m "feat: add flexible migration scope orchestration"
```

---

## Quy tắc merge và điều phối

1. Task branch chỉ được merge khi focused tests pass và diff đã review theo interface của task.
2. Wave 2 không được sửa file thuộc quyền sở hữu độc quyền của task khác. Nếu thiếu shared interface, dừng task và bổ sung Task 2 trên integration branch trước.
3. Task 7 bắt đầu từ integration đã có Task 5 và 6. Task 8 bắt đầu từ integration đã có Task 6.
4. Không chuyển merge conflict chưa giải quyết sang worktree khác; resolve và test trên integration branch.
5. Mỗi task có đúng một final delivery commit. Chỉ squash checkpoint commits của chính task đó.
6. Full validator phải pass sau từng wave, không chờ đến Task 9.

## Bằng chứng hoàn tất

Chỉ coi implementation hoàn tất khi:

- đủ chín task commits theo dependency order;
- mọi focused suite pass;
- main validator và mutation suite pass;
- source-integrity evidence chứng minh checkout không đổi sau mutation tests;
- cả 21 spec scenarios map tới automated test;
- không còn placeholder, detached validator token, duplicate contract enum hoặc unreachable module;
- tài liệu cuối phân biệt rõ requested scope, work item, adapter, attempt và completion level.

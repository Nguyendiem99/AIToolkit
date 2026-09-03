# Architecture Responsibility Conformance Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bổ sung responsibility contract v1 để AIToolkit chỉ cho structural PASS khi tree, responsibility và verification ownership cùng PASS, đồng thời giữ nguyên provenance tới terminal completion.

**Architecture:** Tạo một canonical contract và một PowerShell validation helper dùng chung, rồi nối helper vào discovery/design, plan-waves, structural gate, AI review và downstream handoff. Generic validator chỉ kiểm schema/cross-reference; code-migration ghi actual inventory và AI review phải kiểm tra source/diff độc lập trước khi tạo semantic PASS.

**Tech Stack:** Markdown contracts/templates/skills; Windows PowerShell 5.1; PowerShell scenario validators; Git.

## Global Constraints

- Bắt đầu execution trong worktree riêng được tạo bằng `superpowers:using-git-worktrees`, từ commit chứa spec `3c42f46` hoặc descendant đã được người dùng duyệt.
- Canonical responsibility contract là `aitoolkit/contracts/file-responsibility-conformance.md`; không sao chép enums hoặc table definitions sang skill.
- Artifact executable dùng đúng `responsibility_contract.version: 1` và `applicability: required`; missing, unsupported, cross-run hoặc mixed-version evidence phải block.
- `Owned Capability IDs` chỉ chứa capability độc lập; requirement, acceptance, mapping và work-item nằm trong `Trace IDs`.
- Không dùng line count, class count hoặc one-class-per-file làm authority.
- `not-applicable-approved` là `Verification Disposition`, không phải `Evidence Kind`, và bị cấm cho behavior, routing, lifecycle, external effect, destructive action và production composition.
- Greenfield dùng `approved-greenfield-design`; không tạo `DEV-*` giả chỉ vì không có target exemplar.
- Runtime/`auto-waive` không được thay đổi Tree, Responsibility hoặc Verification Ownership verdict.
- Mọi file Markdown mới/sửa giữ UTF-8; mọi mutation phải có alter-or-fail guard và không phụ thuộc LF/CRLF.
- Không sửa hoặc commit thư mục untracked `issue/`.
- Phase 1 chỉ đánh dấu original issue `partially resolved`; automated remediation thuộc Phase 2.

---

### Task 1: Canonical responsibility contract và validation core

**Files:**
- Create: `aitoolkit/contracts/file-responsibility-conformance.md`
- Create: `aitoolkit/tests/validation/responsibility-conformance.validation.ps1`
- Create: `aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1`
- Modify: `aitoolkit/contracts/target-structure-conformance.md`
- Modify: `aitoolkit/skills/aitoolkit-schemas/SKILL.md`
- Modify: `aitoolkit/tests/validate-migration-framework.ps1`
- Modify: `aitoolkit/tests/validate-migration-framework.Tests.ps1`

**Interfaces:**
- Produces: `Test-ResponsibilityContractSchema([string]$ContractText)` → danh sách lỗi dạng string qua pipeline.
- Produces: `Test-ResponsibilityDiscovery([string]$DiscoveryText, [ValidateSet('incremental','greenfield')][string]$Mode, [string]$ContractText)`.
- Produces: `Test-ResponsibilityDesign([string]$DiscoveryText, [string]$DesignText, [ValidateSet('incremental','greenfield')][string]$Mode, [string]$ContractText)`.
- Produces: `Test-ResponsibilityPlan([string]$DesignText, [string]$PlanText, [string]$WorkItemId, [string]$ContractText)`.
- Produces: `Test-ResponsibilityImplementation([string]$DesignText, [string]$ImplementationText, [string]$ContractText)`.
- Produces: `Test-ResponsibilityReview([string]$ImplementationText, [string]$ReviewText, [string]$ContractText)`.
- Produces: `Test-ResponsibilityHandoff([string]$SourceText, [string]$TargetText, [string]$ContractText)`.
- Contract rule: các hàm không throw vì input domain-invalid; chúng trả diagnostics ổn định. Chỉ lỗi I/O/programming mới throw.

- [ ] **Step 1: Viết RED test cho contract file, version và exported entry points**

Trong `responsibility-conformance.Tests.ps1`, dot-source helper rồi kiểm contract token/schema thực:

```powershell
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$contractPath = Join-Path $root 'contracts/file-responsibility-conformance.md'
$validatorPath = Join-Path $root 'tests/validation/responsibility-conformance.validation.ps1'

if (-not (Test-Path -LiteralPath $contractPath)) {
  throw 'Responsibility contract file is missing'
}
. $validatorPath
$contract = Get-Content -Raw -Encoding utf8 -LiteralPath $contractPath
$errors = @(Test-ResponsibilityContractSchema -ContractText $contract)
if ($errors.Count -ne 0) { throw ($errors -join "`n") }

foreach ($entry in @(
  'Test-ResponsibilityDiscovery',
  'Test-ResponsibilityDesign',
  'Test-ResponsibilityPlan',
  'Test-ResponsibilityImplementation',
  'Test-ResponsibilityReview',
  'Test-ResponsibilityHandoff'
)) {
  if (-not (Get-Command $entry -ErrorAction SilentlyContinue)) {
    throw "Missing responsibility validator entry point: $entry"
  }
}
```

- [ ] **Step 2: Chạy RED test và xác nhận failure đúng nguyên nhân**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-conformance.Tests.ps1
```

Expected: FAIL với `Responsibility contract file is missing` hoặc missing validator entry point; không được fail vì PowerShell parse error.

- [ ] **Step 3: Viết canonical contract đầy đủ**

`file-responsibility-conformance.md` phải chứa đúng các section canonical:

```markdown
## Contract Version
## Exemplar Classification
## Architecture Authority
## File Responsibility Matrix
## Co-location Semantics
## Verification Ownership Matrix
## Actual Responsibility Evidence
## Review Verdicts
## Downstream Handoff
## Compatibility and Rollout
## Stable Diagnostics
```

Contract phải định nghĩa chính xác:

```text
version = 1
applicability = required
Inspection Status = verified | no-equivalent | unknown
Classification = preferred | compatibility-only | legacy-debt | no-equivalent
Architecture Authority = target-exemplar | approved-greenfield-design | approved-structural-deviation
Co-location Policy = feature-local | shared-foundation | atomic-owner | approved-deviation | not-applicable
Evidence Kind = unit | integration | contract | production-composition | static-structure | generator-verification
Verification Disposition = required | not-applicable-approved
Verdict = PASS | BLOCKED
```

File Responsibility Matrix dùng đúng 20 cột đã duyệt trong spec, gồm `Owned Capability IDs`, `Trace IDs`, `Atomic Boundary ID`, classification authority/evidence, architecture authority và verification references. Verification Ownership Matrix dùng đúng 11 cột đã duyệt, giữ `Evidence Kind` tách khỏi `Verification Disposition`.

- [ ] **Step 4: Viết validation core tối thiểu và strict Markdown parser dùng chung**

Trong `responsibility-conformance.validation.ps1`:

```powershell
Set-StrictMode -Version Latest

function Test-ResponsibilityContractSchema {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$ContractText)
  $errors = [Collections.Generic.List[string]]::new()
  # Validate unique headings, exact columns, exact enums and stable diagnostics.
  return $errors.ToArray()
}
```

Tạo private helpers prefix `Arc` để không va chạm khi dot-source cùng validators hiện có:

```powershell
Get-ArcBoundedFrontMatter
Get-ArcStrictMarkdownTable
Split-ArcCanonicalList
Test-ArcExactSet
```

Parser phải reject duplicate heading, doubled boundary pipe, missing separator, extra/missing column, mixed sentinel và CRLF/LF drift. Khai báo sáu public stage functions với parameter signatures trong Interfaces; ở Task 1 chúng chỉ validate contract version rồi trả diagnostics stage-specific, các semantics được hoàn thiện ở task sau.

- [ ] **Step 5: Route canonical contract vào target contract, schema và main validator**

Trong `target-structure-conformance.md`, thêm responsibility contract làm sole authority và đổi công thức:

```text
Structural PASS = Tree PASS AND Responsibility PASS AND Verification Ownership PASS
```

Trong `aitoolkit-schemas/SKILL.md`, route artifact responsibility fields sang contract mới và không copy enums. Trong `validate-migration-framework.ps1`, thêm contract/helper vào Contracts/source-integrity routing. Trong mutation suite, đăng ký file/helper/entry points để deletion hoặc stale route làm test fail.

- [ ] **Step 6: Chạy GREEN focused tests**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-conformance.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Contracts
```

Expected: cả hai exit `0`; scenario in `PASS: responsibility conformance contract`.

- [ ] **Step 7: Commit Task 1**

```powershell
git add -- aitoolkit/contracts/file-responsibility-conformance.md aitoolkit/contracts/target-structure-conformance.md aitoolkit/skills/aitoolkit-schemas/SKILL.md aitoolkit/tests/validation/responsibility-conformance.validation.ps1 aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1 aitoolkit/tests/validate-migration-framework.ps1 aitoolkit/tests/validate-migration-framework.Tests.ps1
git commit -m "feat: define responsibility conformance contract"
```

---

### Task 2: Discovery exemplar classification có authority

**Files:**
- Modify: `aitoolkit/skills/migration/discovery/SKILL.md`
- Modify: `aitoolkit/templates/migration/discovery.md`
- Modify: `aitoolkit/tests/validation/responsibility-conformance.validation.ps1`
- Modify: `aitoolkit/tests/validation/target-conformance.validation.ps1`
- Modify: `aitoolkit/tests/scenarios/target-conformance.Tests.ps1`
- Modify: `aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1`

**Interfaces:**
- Consumes: `Test-ResponsibilityDiscovery` và canonical exemplar enums từ Task 1.
- Produces: exact discovery rows với `Classification Authority` và `Classification Evidence` được technical design dùng ở Task 3.

- [ ] **Step 1: Thêm RED cases cho unauthorized classification**

Thêm fixtures:

```powershell
Assert-Rejected 'agent cannot self-declare legacy debt' {
  param($root)
  Set-DiscoveryClassification $root 'legacy-debt' 'agent-opinion' 'looks aggregate'
} 'exemplar-classification-authority-missing'

Assert-Accepted 'project pack may classify compatibility-only' {
  param($root)
  Set-DiscoveryClassification $root 'compatibility-only' 'project-pack-rule' 'architecture-rules.md#RULE-007'
}
```

Thêm RED cho `preferred` chỉ có một generic file, `no-equivalent` thiếu factual search evidence, duplicate classification row và missing version.

- [ ] **Step 2: Chạy RED target/discovery scenarios**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-conformance.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\target-conformance.Tests.ps1
```

Expected: các case mới FAIL vì template/helper chưa có classification authority.

- [ ] **Step 3: Cập nhật discovery template và skill**

`Comparable Target Exemplars` thêm đúng các cột:

```text
Concern | Path | Inspected Symbols | Observed Pattern | Primary Responsibility | Owned Capabilities | Verification Owner | Comparable Reason | Evidence | Inspection Status | Classification | Classification Authority | Classification Evidence
```

Skill phải yêu cầu:

- `preferred`: repeated working evidence, không có authoritative conflict;
- `compatibility-only`: project-pack rule hoặc approved owner decision;
- `legacy-debt`: project documentation, debt record hoặc Tech Lead-approved conflict;
- `no-equivalent`: factual search/inspection evidence;
- agent opinion không phải classification authority.

- [ ] **Step 4: Hoàn thiện discovery validation và target-conformance integration**

`Test-ResponsibilityDiscovery` kiểm exact cardinality tám concerns với incremental, authority/evidence pairs, version và mode rules. `Test-TargetConformance` gọi helper bằng discovery text đang được validate, không tự copy classification enums.

- [ ] **Step 5: Chạy GREEN scenarios và selectors**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-conformance.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\target-conformance.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Skills
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Templates
```

Expected: tất cả exit `0`; debt classification không authority vẫn rejected.

- [ ] **Step 6: Commit Task 2**

```powershell
git add -- aitoolkit/skills/migration/discovery/SKILL.md aitoolkit/templates/migration/discovery.md aitoolkit/tests/validation/responsibility-conformance.validation.ps1 aitoolkit/tests/validation/target-conformance.validation.ps1 aitoolkit/tests/scenarios/target-conformance.Tests.ps1 aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1
git commit -m "feat: classify migration exemplars by authority"
```

---

### Task 3: Technical design responsibility và verification matrices

**Files:**
- Modify: `aitoolkit/skills/migration/technical-design/SKILL.md`
- Modify: `aitoolkit/templates/migration/technical-design.md`
- Modify: `aitoolkit/tests/validation/responsibility-conformance.validation.ps1`
- Modify: `aitoolkit/tests/validation/target-conformance.validation.ps1`
- Modify: `aitoolkit/tests/scenarios/target-conformance.Tests.ps1`
- Modify: `aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1`

**Interfaces:**
- Consumes: approved discovery classifications from Task 2.
- Produces: v1 `File Responsibility Matrix` và `Verification Ownership Matrix`; stable `RESP-*`/`VERIFY-OWNER-*` IDs cho plan-waves.

- [ ] **Step 1: Viết RED design fixtures A, C, D, E, G và cross-language**

Tạo concrete cases:

```powershell
Assert-DesignRejected 'aggregate capabilities require approval' $aggregateDesign 'co-location-approval-missing'
Assert-DesignAccepted 'feature-local symbols share one capability' $featureLocalDesign
Assert-DesignAccepted 'shared engine owns shared capability only' $sharedFoundationDesign
Assert-DesignRejected 'legacy debt cannot be propagated' $debtExemplarDesign 'debt-exemplar-propagation'
Assert-DesignAccepted 'approved atomic owner' $atomicDesign
```

Cross-language fixtures dùng ba owner cụ thể nhưng cùng contract:

```text
ui/admin_panel.dart#AdminPanel
backend/AdminCommandService.java#AdminCommandService
adapter/admin_pipeline.py#AdminPipeline
```

Thêm positive case một capability có `REQ-101, AC-202, WORK-ADMIN-LOCK` trong `Trace IDs` để chứng minh không bị coi multi-capability.

- [ ] **Step 2: Chạy RED focused scenarios**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-conformance.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\target-conformance.Tests.ps1
```

Expected: FAIL tại missing matrices/authority semantics.

- [ ] **Step 3: Thêm exact template sections và v1 front matter**

Trong technical-design template, thêm bounded front matter:

```yaml
responsibility_contract:
  version: 1
  applicability: required
```

Sau `Planned File Tree`, thêm đúng một `File Responsibility Matrix` và một `Verification Ownership Matrix` với exact columns từ canonical contract. `Owner Symbol` là primary public owner/module export; `Public Symbols` có thể chứa nhiều feature-local symbols; private helper không có row riêng.

- [ ] **Step 4: Implement design semantics**

`Test-ResponsibilityDesign` phải kiểm:

- exact bidirectional `(Planned Path, Planned Symbol)` coverage;
- unique `RESP-*` và `VERIFY-OWNER-*`;
- capability/trace tách biệt;
- `Atomic Boundary ID` chỉ dùng với `atomic-owner`;
- multi-capability owner cần exact approved deviation;
- shared-foundation không chứa concrete registration/effect;
- incremental authority và greenfield `approved-greenfield-design` đúng mode;
- controlled `not-applicable-approved` chỉ cho config/manifest/generated/schema/build wiring;
- behavior/routing/lifecycle/effects/destructive/composition không được miễn;
- mọi production responsibility có verification coverage hai chiều.

- [ ] **Step 5: Nối helper vào target conformance và giữ current eight-concern gates**

`Test-TargetConformance` gọi design helper sau khi current exemplar/matrix authority đã pass. Không xóa hoặc làm yếu planned-tree, boundary, activation và approved-deviation checks hiện có.

- [ ] **Step 6: Chạy GREEN và regression scenarios**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-conformance.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\target-conformance.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Contracts
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Templates
```

Expected: exit `0`; cross-language cases có cùng semantic verdict.

- [ ] **Step 7: Commit Task 3**

```powershell
git add -- aitoolkit/skills/migration/technical-design/SKILL.md aitoolkit/templates/migration/technical-design.md aitoolkit/tests/validation/responsibility-conformance.validation.ps1 aitoolkit/tests/validation/target-conformance.validation.ps1 aitoolkit/tests/scenarios/target-conformance.Tests.ps1 aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1
git commit -m "feat: require responsibility evidence in designs"
```

---

### Task 4: Bind plan-waves work items với responsibility owners

**Files:**
- Modify: `aitoolkit/skills/migration/plan-waves/SKILL.md`
- Modify: `aitoolkit/templates/migration/migration-plan.md`
- Modify: `aitoolkit/tests/validation/responsibility-conformance.validation.ps1`
- Modify: `aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1`
- Modify: `aitoolkit/tests/validate-migration-framework.ps1`

**Interfaces:**
- Consumes: `RESP-*` set và approved design revision từ Task 3.
- Produces: exact `Responsibility Owner References` row cho mỗi work item/unit.

- [ ] **Step 1: Viết RED plan binding cases**

Thêm table fixture:

```markdown
## Responsibility Owner References

| Work Item ID | Design Revision | Responsibility IDs | Shared Foundation IDs | Integration Responsibility IDs | Independent Boundary Evidence |
|---|---|---|---|---|---|
| WORK-ADMIN-LOCK | DESIGN-ADMIN@2 | RESP-WIFI, RESP-WIRED | RESP-LOCK-GUARD | RESP-LOCK-COMPOSITION | architecture-rules.md#RULE-007 |
```

RED cases: missing `RESP-WIRED`, foreign responsibility từ work item khác, duplicate owner, stale design revision, shared foundation bị khai là concrete owner và unapproved cross-work-item reuse.

- [ ] **Step 2: Chạy RED responsibility scenarios**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-conformance.Tests.ps1
```

Expected: FAIL tại missing `Test-ResponsibilityPlan` semantics.

- [ ] **Step 3: Cập nhật plan template/skill và validation**

Plan-waves phải preserve exact ordered owner set, không định nghĩa lại matrix schema. `Test-ResponsibilityPlan` resolve IDs từ approved design, kiểm selected work item/decomposition và xác nhận unit vẫn independently implementable, reviewable, verifiable và revertible.

- [ ] **Step 4: Route plan responsibility evidence qua main validator**

Thêm template/skill contract tokens vào `validate-migration-framework.ps1`; mutation/removal của heading hoặc owner references phải làm `Templates`/`Skills` fail.

- [ ] **Step 5: Chạy GREEN**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-conformance.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Skills
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Templates
```

- [ ] **Step 6: Commit Task 4**

```powershell
git add -- aitoolkit/skills/migration/plan-waves/SKILL.md aitoolkit/templates/migration/migration-plan.md aitoolkit/tests/validation/responsibility-conformance.validation.ps1 aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1 aitoolkit/tests/validate-migration-framework.ps1
git commit -m "feat: bind migration plans to responsibility owners"
```

---

### Task 5: Code-migration pre-edit và planned-versus-actual responsibility gate

**Files:**
- Modify: `aitoolkit/skills/migration/code-migration/SKILL.md`
- Modify: `aitoolkit/templates/migration/implementation-report.md`
- Modify: `aitoolkit/tests/validation/responsibility-conformance.validation.ps1`
- Modify: `aitoolkit/tests/validation/structural-gate.validation.ps1`
- Modify: `aitoolkit/tests/scenarios/structural-gate.Tests.ps1`
- Modify: `aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1`

**Interfaces:**
- Consumes: approved design matrices và selected plan owner set.
- Produces: `Actual File Responsibility Matrix`, `Actual Verification Ownership Matrix` và derived sub-verdict evidence.

- [ ] **Step 1: Viết RED exact-tree false-positive và waiver cases**

Tạo fixture B: planned/actual path giống nhau nhưng actual có `WifiResetProvider` và `settings.write:wifi-reset` ngoài approved inventory. Assert:

```powershell
Assert-StructuralRejected 'tree match cannot hide extra ownership' $root 'responsibility-public-symbol-mismatch'
Assert-StructuralRejected 'runtime waiver cannot waive responsibility' $waivedRoot 'responsibility-waiver-forbidden'
```

Thêm cases: missing planned owner, extra owner, capability drift, external-effect drift, co-location rộng hơn plan, fake production binding và invalid `not-applicable-approved`.

- [ ] **Step 2: Chạy RED structural scenarios**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\structural-gate.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-conformance.Tests.ps1
```

Expected: new cases FAIL trong khi existing 130 structural cases vẫn là baseline cần giữ.

- [ ] **Step 3: Cập nhật implementation template và code-migration protocol**

Thêm v1 discriminator và exact sections:

```markdown
## Actual File Responsibility Matrix
## Actual Verification Ownership Matrix
## Architecture Responsibility Verdicts
```

Verdict table:

```text
Responsibility Contract Version | Tree Conformance | Responsibility Conformance | Verification Ownership | Architecture Conformance State | Evidence References
```

Code-migration pre-edit phải validate approved matrices trước RED/TDD/baseline/worktree mutation. Sau implementation, agent ghi actual public symbols/effects kèm source/diff evidence; self-attestation chưa phải final semantic PASS.

- [ ] **Step 4: Implement exact two-way comparison trong helper và structural gate**

`Test-ResponsibilityImplementation` so approved/actual theo `Responsibility ID` và authoritative `(path, Owner Symbol)`, rồi kiểm Public Symbols, Effects, Capability IDs, Trace IDs, architecture/co-location authority và verification rows. `Test-StructuralGate` gọi helper ngoài current tree/activation/boundary checks.

Derived state:

```powershell
$architecture = if (
  $tree -ceq 'PASS' -and
  $responsibility -ceq 'PASS' -and
  $verification -ceq 'PASS'
) { 'PASS' } else { 'BLOCKED' }
```

Caller-provided aggregate state khác derived state phải block.

- [ ] **Step 5: Chạy GREEN structural regressions**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\structural-gate.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-conformance.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Skills
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Templates
```

Expected: exit `0`; existing activation/selector/deviation checks vẫn PASS.

- [ ] **Step 6: Commit Task 5**

```powershell
git add -- aitoolkit/skills/migration/code-migration/SKILL.md aitoolkit/templates/migration/implementation-report.md aitoolkit/tests/validation/responsibility-conformance.validation.ps1 aitoolkit/tests/validation/structural-gate.validation.ps1 aitoolkit/tests/scenarios/structural-gate.Tests.ps1 aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1
git commit -m "feat: gate migration edits on responsibility"
```

---

### Task 6: Architecture-first AI review xác minh inventory độc lập

**Files:**
- Modify: `aitoolkit/skills/shared/ai-review/SKILL.md`
- Modify: `aitoolkit/templates/migration/review-report.md`
- Modify: `aitoolkit/tests/validation/responsibility-conformance.validation.ps1`
- Modify: `aitoolkit/tests/validation/architecture-review.validation.ps1`
- Modify: `aitoolkit/tests/scenarios/architecture-review.Tests.ps1`
- Modify: `aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1`

**Interfaces:**
- Consumes: implementation actual inventory và final task-base/final-tree diff.
- Produces: final semantic Tree, Responsibility và Verification Ownership verdicts cùng immutable evidence references.

- [ ] **Step 1: Viết RED self-attestation bypass case**

Fixture cho implementation tự khai PASS nhưng final source evidence có extra route/provider. Review phải reject:

```powershell
Assert-FailsLike 'review independently rejects omitted actual owner' {
  param($root)
  Add-SourceSymbolEvidence $root 'AdminRoute.factoryReset' 'RESP-UNPLANNED'
  Keep-ImplementationSelfAttestationPass $root
} 'responsibility-owner-extra|responsibility-public-symbol-mismatch'
```

Thêm RED cases cho thiếu từng sub-verdict, thiếu evidence reference, fake production composition và Responsibility PASS khi Verification BLOCKED.

- [ ] **Step 2: Chạy RED architecture review**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\architecture-review.Tests.ps1
```

Expected: new bypass case chưa bị reject.

- [ ] **Step 3: Cập nhật review skill/template**

Review order exact:

```text
master/work-item -> rules -> selector -> tree -> responsibility -> verification ownership -> activation -> behavior/security/performance -> hygiene
```

Template thêm `Responsibility Review Evidence`:

```text
Responsibility ID | Source/Diff Evidence | Planned Public Symbols | Actual Public Symbols | Planned Effects | Actual Effects | Verdict
```

Và thêm ba exact verdict lines. Reviewer phải inspect source/diff độc lập, không copy implementation PASS.

- [ ] **Step 4: Implement review validator**

`Test-ResponsibilityReview` kiểm exact row coverage, actual inventory evidence, verdict derivation và evidence provenance. `Test-ArchitectureReview` gọi helper trước behavior analysis; bất kỳ sub-verdict BLOCKED nào làm overall Reject, bất kể severity count.

- [ ] **Step 5: Chạy GREEN architecture scenarios**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\architecture-review.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-conformance.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Skills
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Templates
```

- [ ] **Step 6: Commit Task 6**

```powershell
git add -- aitoolkit/skills/shared/ai-review/SKILL.md aitoolkit/templates/migration/review-report.md aitoolkit/tests/validation/responsibility-conformance.validation.ps1 aitoolkit/tests/validation/architecture-review.validation.ps1 aitoolkit/tests/scenarios/architecture-review.Tests.ps1 aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1
git commit -m "feat: review migration responsibility independently"
```

---

### Task 7: Preserve responsibility provenance qua verification, parity, regression và KB

**Files:**
- Create: `aitoolkit/tests/scenarios/responsibility-handoff.Tests.ps1`
- Modify: `aitoolkit/skills/shared/verification-testing/SKILL.md`
- Modify: `aitoolkit/skills/migration/verify-parity/SKILL.md`
- Modify: `aitoolkit/skills/migration/verify-regression/SKILL.md`
- Modify: `aitoolkit/skills/shared/knowledge-base/SKILL.md`
- Modify: `aitoolkit/templates/migration/verification-report.md`
- Modify: `aitoolkit/templates/migration/parity-report.md`
- Modify: `aitoolkit/templates/migration/regression-report.md`
- Modify: `aitoolkit/templates/kb-entry.md`
- Modify: `aitoolkit/tests/validation/responsibility-conformance.validation.ps1`
- Modify: `aitoolkit/tests/validate-migration-framework.ps1`

**Interfaces:**
- Consumes: final AI review sub-verdicts/evidence từ Task 6.
- Produces: exact `Architecture Responsibility Handoff` table ở từng downstream artifact.

- [ ] **Step 1: Viết RED handoff loss/mutation scenarios**

Mỗi downstream artifact dùng table exact:

```markdown
## Architecture Responsibility Handoff

| Responsibility Contract Version | Tree Conformance | Responsibility Conformance | Verification Ownership | Architecture Conformance State | Evidence References |
|---|---|---|---|---|---|
| 1 | PASS | PASS | PASS | PASS | review-report.md#responsibility-evidence |
```

RED mutations: drop table ở parity, đổi Responsibility PASS thành BLOCKED nhưng giữ aggregate PASS, đổi evidence reference, dùng version 2, lấy table từ run khác và runtime waiver cố đổi state.

- [ ] **Step 2: Chạy RED handoff suite**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-handoff.Tests.ps1
```

Expected: FAIL vì templates/helper chưa preserve handoff.

- [ ] **Step 3: Cập nhật bốn skills và templates**

Mỗi stage phải copy exact sub-verdict/evidence từ immediate predecessor, validate version trước matrices và giữ derived aggregate. Stage không được reconstruct từ cumulative artifacts hoặc directory scan.

Knowledge Base chỉ được tính completed khi handoff PASS và evidence reference resolve immutable terminal artifact. Runtime waiver chỉ thay runtime state, không thay responsibility table.

- [ ] **Step 4: Implement handoff validator**

`Test-ResponsibilityHandoff` kiểm:

- đúng một table ở source/target;
- version/applicability hợp lệ;
- exact ordinal sub-verdict/evidence preservation;
- aggregate state đúng phép hội;
- same-run/current work-item provenance;
- BLOCKED không được chuyển thành PASS.

- [ ] **Step 5: Chạy GREEN handoff và template checks**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-handoff.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Skills
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Templates
```

- [ ] **Step 6: Commit Task 7**

```powershell
git add -- aitoolkit/skills/shared/verification-testing/SKILL.md aitoolkit/skills/migration/verify-parity/SKILL.md aitoolkit/skills/migration/verify-regression/SKILL.md aitoolkit/skills/shared/knowledge-base/SKILL.md aitoolkit/templates/migration/verification-report.md aitoolkit/templates/migration/parity-report.md aitoolkit/templates/migration/regression-report.md aitoolkit/templates/kb-entry.md aitoolkit/tests/validation/responsibility-conformance.validation.ps1 aitoolkit/tests/scenarios/responsibility-handoff.Tests.ps1 aitoolkit/tests/validate-migration-framework.ps1
git commit -m "feat: preserve responsibility verdict provenance"
```

---

### Task 8: Orchestrator, terminal formula, rollout và safe post-implementation stop

**Files:**
- Modify: `aitoolkit/skills/aitoolkit/migrate/SKILL.md`
- Modify: `aitoolkit/templates/migration/scope-terminal-report.md`
- Modify: `aitoolkit/tests/validation/scope-engine.validation.ps1`
- Modify: `aitoolkit/tests/validation/architecture-review.validation.ps1`
- Modify: `aitoolkit/tests/scenarios/scope-engine.Tests.ps1`
- Modify: `aitoolkit/tests/scenarios/flexible-scope-e2e.Tests.ps1`
- Modify: `aitoolkit/tests/scenarios/responsibility-handoff.Tests.ps1`
- Modify: `aitoolkit/tests/validate-migration-framework.ps1`

**Interfaces:**
- Consumes: terminal evidence chain có v1 handoff từ Task 7.
- Produces: fail-closed queue/terminal behavior và compatibility rollout semantics.

- [ ] **Step 1: Viết RED terminal provenance và safe-stop cases**

Thêm E2E case concrete:

```text
actual responsibility mismatch
-> implementation draft/blocked
-> review Reject
-> work item blocked
-> dependent item remains non-eligible
-> delivery and scope completion blocked
-> approved design/master-plan revision required
```

Thêm cases: aggregate PASS với Responsibility BLOCKED, missing evidence link, mixed v1/v2, historical-only artifact dùng làm executable authority, in-progress pre-v1 resume và auto-waive override.

- [ ] **Step 2: Chạy RED scope/E2E**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\scope-engine.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\flexible-scope-e2e.Tests.ps1
```

Expected: new provenance/stop cases FAIL; existing exactly-21 fixture count phải được cập nhật bằng subcases, không tăng top-level E2E count nếu suite giữ invariant 21.

- [ ] **Step 3: Cập nhật migrate orchestrator và terminal template**

Orchestrator phải:

- derive `architecture_conformance_state` từ ba sub-verdict;
- stop queue trước parity/regression/delivery/KB khi một sub-verdict BLOCKED;
- không chọn dependent work;
- require approved design/master-plan revision để resume;
- coi completed pre-v1 là `historical-only`;
- block in-progress pre-v1 và mixed-version evidence;
- không tự tạo Phase 2 remediation artifact/work item.

Terminal template thêm exact `Architecture Responsibility Handoff` và Evidence Index references; scope-complete formula phải resolve immutable sub-verdict evidence.

- [ ] **Step 4: Implement terminal/scope validation**

Trong scope engine/FlexibleScope path, kiểm phép hội:

```powershell
$architecturePass =
  $tree -ceq 'PASS' -and
  $responsibility -ceq 'PASS' -and
  $verification -ceq 'PASS' -and
  $architectureState -ceq 'PASS'
```

Nếu false, diagnostic phải là `structural-assurance-blocked` hoặc responsibility diagnostic cụ thể, state `scope-blocked`, next eligible item `none`, terminal verdict không phải `scope-complete`.

- [ ] **Step 5: Chạy GREEN scope, E2E và handoff suites**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\scope-engine.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-handoff.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\flexible-scope-e2e.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check All
```

Expected: tất cả exit `0`; E2E vẫn báo exact expected scenario count.

- [ ] **Step 6: Commit Task 8**

```powershell
git add -- aitoolkit/skills/aitoolkit/migrate/SKILL.md aitoolkit/templates/migration/scope-terminal-report.md aitoolkit/tests/validation/scope-engine.validation.ps1 aitoolkit/tests/validation/architecture-review.validation.ps1 aitoolkit/tests/scenarios/scope-engine.Tests.ps1 aitoolkit/tests/scenarios/flexible-scope-e2e.Tests.ps1 aitoolkit/tests/scenarios/responsibility-handoff.Tests.ps1 aitoolkit/tests/validate-migration-framework.ps1
git commit -m "feat: block terminal scope on responsibility defects"
```

---

### Task 9: Mutation coverage, toàn bộ regression gates và final evidence

**Files:**
- Modify: `aitoolkit/tests/validate-migration-framework.Tests.ps1`
- Modify: `aitoolkit/tests/validate-migration-framework.ps1`
- Modify only if a proven mutation failure requires it: responsibility-related files from Tasks 1–8

**Interfaces:**
- Consumes: final Phase 1 behavior từ Tasks 1–8.
- Produces: mutation evidence cho fixtures A–G/I, downstream preservation, safe stop và exact final-tree PASS.

- [ ] **Step 1: Viết RED mutation cases với alter-or-fail guard**

Mỗi mutation dùng helper tương đương:

```powershell
function Replace-ExactOrFail([string]$Text, [string]$From, [string]$To, [string]$Name) {
  $changed = $Text.Replace($From, $To)
  if ($changed -ceq $Text) { throw "$Name mutation was a silent no-op" }
  return $changed
}
```

Bao phủ tối thiểu:

- contract version missing/mixed;
- capability/trace conflation;
- classification authority loss;
- greenfield converted to fake deviation;
- multi-capability approval removal;
- extra public symbol/effect while tree matches;
- invalid verification not-applicable;
- fake production composition;
- implementation self-attestation bypass;
- sub-verdict loss/mutation downstream;
- runtime waiver override;
- post-implementation queue advance.

- [ ] **Step 2: Chạy focused RED mutation cluster**

Nếu suite chưa có selector riêng, thêm `-ResponsibilityConformanceOnly` vào `validate-migration-framework.Tests.ps1` và bảo đảm default invocation vẫn chạy toàn bộ suite.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.Tests.ps1 -ResponsibilityConformanceOnly
```

Expected: FAIL trước khi registration/mutations hoàn chỉnh; không có silent no-op.

- [ ] **Step 3: Hoàn thiện mutation routing và source-integrity registration**

Main validator phải nhận new contract/helper/scenarios trong Contracts, Skills, Templates, Docs và SourceIntegrity paths phù hợp. Mutation suite phải chạy fixture copy riêng, dùng LF/CRLF-independent replacement và xác nhận source digest không đổi sau mỗi isolated mutation.

- [ ] **Step 4: Chạy toàn bộ focused gates trước full suite**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-conformance.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-handoff.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\target-conformance.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\structural-gate.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\architecture-review.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\scope-engine.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\flexible-scope-e2e.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Contracts
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Skills
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Templates
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check All
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check SourceIntegrityOnly
git diff --check
```

Expected: mọi command exit `0`. Không chạy full mutation suite nếu bất kỳ focused gate nào fail.

- [ ] **Step 5: Commit final mutation coverage trước long gate**

```powershell
git add -- aitoolkit/tests/validate-migration-framework.Tests.ps1 aitoolkit/tests/validate-migration-framework.ps1 aitoolkit/contracts aitoolkit/skills aitoolkit/templates aitoolkit/tests/validation aitoolkit/tests/scenarios
git status --short
git commit -m "test: cover responsibility conformance workflow"
```

Trước commit, xác nhận `git status --short` không stage `issue/` hoặc file ngoài Phase 1.

- [ ] **Step 6: Chạy full mutation suite đúng một lần trên exact final HEAD**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.Tests.ps1
```

Expected: exit `0`, output `PASS: focused migration framework tests`. Không sửa source trong lúc suite chạy. Nếu FAIL, dừng, giữ exact diagnostics và không claim completion; chỉ chạy lại sau khi có fix mới và authorization rõ ràng cho long gate khác.

- [ ] **Step 7: Chạy fresh short gates sau full PASS**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check All
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check SourceIntegrityOnly
git diff --check HEAD^ HEAD
git status --short
git log -1 --oneline
```

Expected: All/SourceIntegrity PASS, diff check exit `0`; status chỉ còn known untracked `issue/`; HEAD không đổi sau full suite.

- [ ] **Step 8: Ghi final completion status đúng phạm vi**

Handoff phải ghi:

```text
Core false-positive: fixed
Prevention gates: complete
Safe post-implementation stop: complete
Automated remediation: pending Phase 2
Original issue: partially resolved
```

Không tuyên bố original issue closed và không tự bắt đầu Phase 2.

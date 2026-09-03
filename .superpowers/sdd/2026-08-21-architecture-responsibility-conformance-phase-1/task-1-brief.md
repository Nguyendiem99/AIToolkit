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


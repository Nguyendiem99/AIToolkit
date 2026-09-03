$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$script:passed = 0
$script:errors = [Collections.Generic.List[string]]::new()
$aitoolkitRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$validatorPath = Join-Path $aitoolkitRoot 'tests/validation/structural-gate.validation.ps1'
$deliveryValidatorPath = Join-Path $aitoolkitRoot 'tests/validation/delivery-adapters.validation.ps1'
$targetValidatorPath = Join-Path $aitoolkitRoot 'tests/validation/target-conformance.validation.ps1'
$contractPath = Join-Path $aitoolkitRoot 'contracts/target-structure-conformance.md'
$scopeContractPath = Join-Path $aitoolkitRoot 'contracts/migration-scope-orchestration.md'
$activationContractPath = Join-Path $aitoolkitRoot 'contracts/activation-slice.md'
$responsibilityContractPath = Join-Path $aitoolkitRoot 'contracts/file-responsibility-conformance.md'
$caseRoot = Join-Path ([IO.Path]::GetTempPath()) ("aitoolkit-structural-gate-{0}" -f [guid]::NewGuid().ToString('N'))

function Require-Token([string]$Text, [string]$Token, [string]$Context) {
  if ($Text -notmatch [regex]::Escape($Token)) {
    $script:errors.Add("$Context missing: $Token")
  }
}

function Test-MarkdownTableExactColumns {
  param([string]$Text, [string]$Heading, [string[]]$ExpectedColumns, [string]$Context)
  $headingMatch = [regex]::Match($Text, '(?m)^##\s+' + [regex]::Escape($Heading) + '\s*$')
  if (-not $headingMatch.Success) { $script:errors.Add("$Context missing table: $Heading"); return }
  $row = [regex]::Match($Text.Substring($headingMatch.Index + $headingMatch.Length), '(?m)^\|(?<row>[^\r\n]+)\|\s*$')
  if (-not $row.Success) { $script:errors.Add("$Context missing table header: $Heading"); return }
  $actual = @($row.Groups['row'].Value.Split('|') | ForEach-Object { $_.Trim() })
  if (($actual -join '|') -cne ($ExpectedColumns -join '|')) {
    $script:errors.Add("$Context $Heading table columns must be exactly: $($ExpectedColumns -join ' | ')")
  }
}

function Write-Utf8([string]$Path, [string]$Text) {
  $parent = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $parent)) {
    [void](New-Item -ItemType Directory -Path $parent -Force)
  }
  [IO.File]::WriteAllText($Path, $Text, [Text.UTF8Encoding]::new($false))
}

function Get-DesignDigest([string]$Text) {
  $normalized = (($Text -replace "`r`n", "`n") -replace "`r", "`n")
  $bytes = [Text.Encoding]::UTF8.GetBytes($normalized)
  $hash = [Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
  return 'sha256:' + (($hash | ForEach-Object { $_.ToString('x2') }) -join '')
}

function Write-DesignApproval([string]$Root, [string]$Status = 'approved', [string]$ApprovalReference = 'approval:TECH-LEAD-DESIGN-401') {
  $fixture = Join-Path $Root 'structural-gate-fixture'
  $designText = Get-Content -Raw -Encoding utf8 -LiteralPath (Join-Path $fixture '07-technical-design.md')
  $digest = Get-DesignDigest $designText
  Write-Utf8 (Join-Path $fixture '07-technical-design.approval.md') @"
---
step_id: technical-design-approval
status: approved
result: complete
approval_source: human
produced_at: 2026-08-19
---

## Technical Design Approval

| Design ID | Design Revision | Design Digest | Approval Reference | Tech Lead Decision | Approval Status |
|---|---|---|---|---|---|
| DESIGN-401 | 6 | $digest | $ApprovalReference | approve exact design revision for implementation | $Status |
"@
}

function Set-ApprovedStructuralDeviation([string]$Root) {
  $path = Join-Path $Root 'structural-gate-fixture/07-technical-design.md'
  $design = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $design = $design -replace '(\| controller/provider/state pattern \|[^\r\n]+?\| lib/admin/lock_controller.dart#LockController \|) yes \| not-applicable \|', '$1 no | DEV-LOCK-01 |'
  $design = $design -replace '\| none \| not-applicable \| not-applicable \| not-applicable \| not-applicable \|', '| DEV-LOCK-01 | controller/provider/state pattern | CONFLICT-LOCK-01 | resolved:DECISION-LOCK-01: introduce approved aggregate | approval:TECH-LEAD-LOCK-01 |'
  Write-Utf8 $path $design
  Write-DesignApproval $Root
}

function Add-ActivationGroup([string]$Path, [string]$SliceId, [bool]$NotApplicable = $false) {
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $Path
  $rows = @($text -split '\r?\n' | Where-Object { $_.StartsWith('| ACT-001 |', [StringComparison]::Ordinal) })
  if ($rows.Count -ne 9) { throw "expected one canonical ACT-001 group in $Path; got $($rows.Count)" }
  $clone = ($rows -join "`n") -replace 'ACT-001', $SliceId
  if ($NotApplicable) {
    $clone = $clone -replace '\| applicable \|', '| not-applicable-approved |'
    $clone = $clone -replace '\| implement \| verified \| not-applicable \| not-applicable \|', '| not-applicable-approved | verified | approval:TECH-LEAD-ACT-002 | not-applicable |'
  }
  $lastRow = $rows[-1]
  Write-Utf8 $Path ($text.Replace($lastRow, "$lastRow`n$clone"))
}

function New-Case([string]$Name) {
  $root = Join-Path $caseRoot $Name
  [void](New-Item -ItemType Directory -Path (Join-Path $root 'contracts') -Force)
  [void](New-Item -ItemType Directory -Path (Join-Path $root 'templates/migration') -Force)
  Copy-Item -LiteralPath $contractPath -Destination (Join-Path $root 'contracts/target-structure-conformance.md')
  Copy-Item -LiteralPath $scopeContractPath -Destination (Join-Path $root 'contracts/migration-scope-orchestration.md')
  Copy-Item -LiteralPath $activationContractPath -Destination (Join-Path $root 'contracts/activation-slice.md')
  Copy-Item -LiteralPath $responsibilityContractPath -Destination (Join-Path $root 'contracts/file-responsibility-conformance.md')
  Copy-Item -LiteralPath (Join-Path $aitoolkitRoot 'templates/migration/implementation-report.md') -Destination (Join-Path $root 'templates/migration/implementation-report.md')
  foreach ($relativePath in @(
    'skills/migration/build-inventory/SKILL.md',
    'skills/migration/feature-mapping/SKILL.md',
    'skills/migration/analyze-gaps-conflicts/SKILL.md',
    'skills/migration/plan-waves/SKILL.md',
    'templates/migration/migration-plan.md'
  )) {
    $destination = Join-Path $root $relativePath
    [void](New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force)
    Copy-Item -LiteralPath (Join-Path $aitoolkitRoot $relativePath) -Destination $destination
  }
  return $root
}

function Write-CanonicalTask5Fixture([string]$Root) {
  $fixture = Join-Path $Root 'delivery-adapter-fixture'
  Write-Utf8 (Join-Path $fixture 'master-plan.md') @'
---
artifact_type: migration-master-plan
master_plan_id: PLAN-ADMIN-001
revision: 7
status: approved
---

## Work Items

| Work Item ID | Title | Required | Dependencies | Plan Order | Acceptance | Trace IDs | Delivery Adapter | Status | Latest Attempt | Terminal Evidence | Approval Reference |
|---|---|---|---|---|---|---|---|---|---|---|---|
| WORK-ADMIN-LOCKS | Lock behavior | yes | none | 1 | REQ-101: lock mode persists | REQ-101, ITEM-201, MAP-301, DESIGN-401 | migration-unit:UNIT-ADM-002 | ready | none | none | approval:WORK-ADMIN-LOCKS |

## Delivery Adapter Selection

| Work Item ID | Adapter Kind | External ID | Authority | Authority Revision | Approval Reference | Parent Selector | Acceptance | Trace IDs | Mode Constraint | Design Revision | Parent Work Item ID | Decomposition Decision Reference |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| WORK-ADMIN-LOCKS | migration-unit | UNIT-ADM-002 | 08-migration-plan.md | 3 | approval:UNIT-ADM-002 | not-applicable | REQ-101: lock mode persists | REQ-101, ITEM-201, MAP-301, DESIGN-401 | incremental/preserve-existing | DESIGN-401@4 | not-applicable | not-applicable |

## Decomposition Records

| Parent Work Item ID | Child Work Item IDs | Decision Reference | Master Plan Revision | Approval Reference | Approval Status |
|---|---|---|---|---|---|
'@
  foreach ($step in 4..7) {
    $names = @{ 4 = '04-inventory.md'; 5 = '05-mapping.md'; 6 = '06-gaps-conflicts.md'; 7 = '07-technical-design.md' }
    $ids = @{ 4 = '04-build-inventory'; 5 = '05-feature-mapping'; 6 = '06-analyze-gaps-conflicts'; 7 = '07-technical-design' }
    Write-Utf8 (Join-Path $fixture $names[$step]) @"
---
step_id: $($ids[$step])
status: approved
result: complete
produced_at: 2026-08-19
responsibility_contract:
  version: 1
  applicability: required
---

## Work Item Trace

| Work Item ID | Parent Work Item ID | Master Plan Reference | Master Plan Revision | Acceptance | Trace IDs | Mode Constraint | Design Revision | Decomposition Decision Reference |
|---|---|---|---|---|---|---|---|---|
| WORK-ADMIN-LOCKS | not-applicable | master-plan.md | 7 | REQ-101: lock mode persists | REQ-101, ITEM-201, MAP-301, DESIGN-401 | incremental/preserve-existing | DESIGN-401@4 | not-applicable |
"@
  }
  $orderedUnitsHeading = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('Q8OhYyDEkcahbiB24buLIG1pZ3JhdGlvbiB0aGVvIHRo4bupIHThu7E='))
  Write-Utf8 (Join-Path $fixture '08-migration-plan.md') @"
---
step_id: 08-plan-waves
status: approved
result: complete
approval_source: human
run_id: RUN-ADMIN-001
revision: 3
produced_at: 2026-08-19
responsibility_contract:
  version: 1
  applicability: required
---

## $orderedUnitsHeading

| Order | Migration Unit ID | Bootstrap Scope | Foundation Baseline ID | Foundation Approval Reference | Dependencies | Acceptance | Mode Constraint | Trace IDs | Delivery Change Boundary | Approval Reference | Approval Status |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | UNIT-ADM-002 | not-required | not-applicable | not-applicable | none | REQ-101: lock mode persists | incremental/preserve-existing | REQ-101, ITEM-201, MAP-301, DESIGN-401 | one-unit-one-change | approval:UNIT-ADM-002 | approved |

## Work Item Adapter Trace

| Migration Unit ID | Work Item ID | Parent Work Item ID | Master Plan Reference | Master Plan Revision | Decomposition Decision Reference | Design Revision |
|---|---|---|---|---|---|---|
| UNIT-ADM-002 | WORK-ADMIN-LOCKS | not-applicable | master-plan.md | 7 | not-applicable | DESIGN-401@4 |
"@
}

function Get-ValidReport {
  return @'
---
step_id: 10-code-migration
status: draft
result: complete
produced_at: 2026-08-19
responsibility_contract:
  version: 1
  applicability: required
---

## Master Scope Context

| Master Spec Reference | Master Spec ID | Master Spec Revision | Master Plan Reference | Master Plan ID | Master Plan Revision | Work Item ID | Work Item Approval Reference |
|---|---|---|---|---|---|---|---|
| master-spec.md | SPEC-ADMIN-001 | 2 | master-plan.md | PLAN-ADMIN-001 | 4 | WORK-ADMIN-LOCKS | approval:TECH-LEAD-WORK-ADMIN-LOCKS |

## Canonical Adapter Evidence

| Work Item ID | Adapter Kind | External ID | Authority | Authority Revision | Approval Reference | Parent Selector | Acceptance | Trace IDs | Mode Constraint | Design Revision | Parent Work Item ID | Decomposition Decision Reference | Canonical Match |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| WORK-ADMIN-LOCKS | migration-unit | UNIT-ADM-002 | 08-migration-plan.md | 4 | approval:UNIT-ADM-002 | not-applicable | REQ-101; SC-101; all lock changes finish within 2 seconds | REQ-101, SC-101, DESIGN-401 | incremental/preserve-existing | DESIGN-401@6 | not-applicable | not-applicable | PASS |

## Selected Migration Unit

| Migration Unit ID | Plan Reference | Approval Reference | Mode Constraint | Bootstrap Scope | Foundation Baseline ID | Foundation Baseline Reference | Foundation Baseline Approval Reference | Baseline Reference | Trace IDs |
|---|---|---|---|---|---|---|---|---|---|
| UNIT-ADM-002 | 08-migration-plan.md@4 | approval:UNIT-ADM-002 | incremental/preserve-existing | not-required | not-applicable | not-applicable | not-applicable | baseline.md#BASE-ADMIN-001 | REQ-101, SC-101, DESIGN-401 |

## Conformance Matrix Reference

| Work Item ID | Discovery Reference | Design Reference | Design Revision | Design Approval Evidence Reference | Matrix Approval Reference | Matrix Status |
|---|---|---|---|---|---|---|
| WORK-ADMIN-LOCKS | 02-discovery.md | 07-technical-design.md | 6 | 07-technical-design.approval.md | approval:TECH-LEAD-DESIGN-401 | approved |

## Responsibility Plan Reference

| Work Item ID | Plan Reference | Plan Revision | Design Revision |
|---|---|---|---|
| WORK-ADMIN-LOCKS | 08-migration-plan.md | 4 | DESIGN-401@6 |

## Exemplar Read Evidence

| Concern | Path | Inspected Symbols | Evidence | Read Status |
|---|---|---|---|---|
| module/container composition | lib/admin/admin_module.dart | AdminModule.build | discovery.md#EX-01 | read-complete |
| main/child presentation boundaries | lib/admin/admin_panel.dart | AdminPanel.build | discovery.md#EX-02 | read-complete |
| unit/component organization | lib/admin/lock_section.dart | LockSection.build | discovery.md#EX-03 | read-complete |
| controller/provider/state pattern | lib/admin/lock_controller.dart | LockController.build | discovery.md#EX-04 | read-complete |
| routing and lifecycle | lib/admin/admin_route.dart | AdminRoute.build | discovery.md#EX-05 | read-complete |
| localization | lib/l10n/admin_strings.dart | AdminStrings.lockTitle | discovery.md#EX-06 | read-complete |
| service/config subscription and normalization | lib/admin/lock_subscription.dart | LockSubscription.start | discovery.md#EX-07 | read-complete |
| test harness and production-boundary tests | test/admin/lock_test.dart | main | discovery.md#EX-08 | read-complete |

## Actual File Tree vs Planned File Tree

| Planned Path | Planned Symbol | Actual Path | Actual Symbol | Match | Evidence |
|---|---|---|---|---|---|
| lib/admin/lock_controller.dart | LockController | lib/admin/lock_controller.dart | LockController | yes | diff#lock-controller |
| lib/admin/lock_panel.dart | LockPanel | lib/admin/lock_panel.dart | LockPanel | yes | diff#lock-panel |

## Actual File Responsibility Matrix

| Responsibility ID | Owner Path | Owner Symbol | Boundary Kind | Primary Responsibility | Owned Capability IDs | Trace IDs | Atomic Boundary ID | Public Symbols | External Effects | Target Exemplar | Exemplar Classification | Classification Authority | Classification Evidence | Architecture Authority | Co-location Policy | Co-location Evidence | Verification Owner References | Conformance | Deviation Reference | Actual Evidence |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| RESP-LOCK-CONTROLLER | lib/admin/lock_controller.dart | LockController | application | own lock state | CAP-LOCK-STATE | REQ-101; SC-101; DESIGN-401; WORK-ADMIN-LOCKS | not-applicable | LockController | none | lib/admin/lock_controller.dart#LockController.build | preferred | factual-discovery-evidence | inspection:lib/admin/lock_controller.dart:1-40; inspection:test/admin/lock_test.dart:1-40 | target-exemplar | feature-local | same capability lifecycle verification and revert boundary | VERIFY-OWNER-LOCK-CONTROLLER | yes | not-applicable | diff:lib/admin/lock_controller.dart#LockController |
| RESP-LOCK-PANEL | lib/admin/lock_panel.dart | LockPanel | presentation | render lock panel | CAP-LOCK-PRESENTATION | REQ-101; SC-101; DESIGN-401; WORK-ADMIN-LOCKS | not-applicable | LockPanel | none | lib/admin/admin_panel.dart#AdminPanel.build | preferred | factual-discovery-evidence | inspection:lib/admin/admin_panel.dart:1-40; inspection:test/admin/lock_test.dart:1-40 | target-exemplar | feature-local | same capability lifecycle verification and revert boundary | VERIFY-OWNER-LOCK-PANEL | yes | not-applicable | diff:lib/admin/lock_panel.dart#LockPanel |

## Responsibility Owner References

| Work Item ID | Design Revision | Responsibility IDs | Shared Foundation IDs | Integration Responsibility IDs | Independent Boundary Evidence |
|---|---|---|---|---|---|
| WORK-ADMIN-LOCKS | DESIGN-401@6 | RESP-LOCK-CONTROLLER, RESP-LOCK-PANEL | not-applicable | not-applicable | architecture-rules.md#RULE-LOCK-001: independently implementable, reviewable, verifiable, and revertible |

## Actual Verification Ownership Matrix

| Verification Owner ID | Production Responsibility ID | Capability ID | Evidence Path | Evidence Symbol or Scenario | Evidence Kind | Verification Disposition | Production Binding Evidence | Decision Reference | Verdict | Deviation Reference | Actual Evidence |
|---|---|---|---|---|---|---|---|---|---|---|---|
| VERIFY-OWNER-LOCK-CONTROLLER | RESP-LOCK-CONTROLLER | CAP-LOCK-STATE | test/admin/lock_test.dart | lock controller contract | contract | required | invokes lib/admin/lock_controller.dart#LockController | not-applicable | PASS | not-applicable | diff:test/admin/lock_test.dart#lock-controller-contract |
| VERIFY-OWNER-LOCK-PANEL | RESP-LOCK-PANEL | CAP-LOCK-PRESENTATION | test/admin/lock_test.dart | lock panel contract | contract | required | invokes lib/admin/lock_panel.dart#LockPanel | not-applicable | PASS | not-applicable | diff:test/admin/lock_test.dart#lock-panel-contract |

## Architecture Responsibility Verdicts

| Responsibility Contract Version | Tree Conformance | Responsibility Conformance | Verification Ownership | Architecture Conformance State | Evidence References |
|---|---|---|---|---|---|
| 1 | PASS | PASS | PASS | PASS | 07-technical-design.md#file-responsibility-matrix; diff:HEAD |

## Target Boundary Conformance

| Boundary | Planned Owner Path/Symbol | Actual Owner Path/Symbol | Invocation Path | Mechanism | Lifecycle/Failure Evidence | Verdict |
|---|---|---|---|---|---|---|
| provider | lib/admin/lock_controller.dart#LockController | lib/admin/lock_controller.dart#LockController | widget -> provider -> service | targetProvider | test#provider | PASS |
| router | lib/admin/admin_route.dart#AdminRoute | lib/admin/admin_route.dart#AdminRoute | navigation-action -> router -> route | targetRouter | test#router | PASS |
| localization | lib/l10n/admin_strings.dart#AdminStrings | lib/l10n/admin_strings.dart#AdminStrings | widget -> localization -> resource | targetLocalization | test#localization | PASS |
| subscription | lib/admin/lock_subscription.dart#LockSubscription | lib/admin/lock_subscription.dart#LockSubscription | service -> subscription -> provider | targetSubscription | test#subscription-key | PASS |
| lifecycle | lib/admin/lock_controller.dart#LockController | lib/admin/lock_controller.dart#LockController | route -> lifecycle -> subscription | targetLifecycle | test#dispose | PASS |

## Exemplar Deviations

| Deviation Reference | Concern | Conflict Reference | Actual Abstraction | Resolved Decision | Tech Lead Approval | Status |
|---|---|---|---|---|---|---|
| not-applicable | not-applicable | not-applicable | not-applicable | not-applicable | not-applicable | not-applicable |

## Production Activation Path Evidence

| Applicability | Decision Reference | Entry Point | Registration | Runtime Path | Production Evidence | Verdict |
|---|---|---|---|---|---|---|
| applicable | not-applicable | lib/admin/admin_route.dart#AdminRoute | lib/admin/admin_route.dart#AdminRoute @ policy=base-owned | route -> panel -> provider -> subscription -> lifecycle | lifecycle-test-trace=DESIGN-401 @ source#test | PASS |

## Assurance State

| Runtime Evidence State | Architecture Conformance State | Selector Schema State |
|---|---|---|
| NOT_RUN | PASS | PASS |

## Work Item Changed Files

| Work Item ID | Activation Slice ID | Seam | File | Change | Trace IDs |
|---|---|---|---|---|---|
| WORK-ADMIN-LOCKS | ACT-001 | state-holder | lib/admin/lock_controller.dart | update provider | REQ-101, DESIGN-401 |
| WORK-ADMIN-LOCKS | ACT-001 | render | lib/admin/lock_panel.dart | update panel | SC-101, DESIGN-401 |

## Work Item Test Evidence

| Work Item ID | Activation Slice ID | Seam | Test | Command | Result | Trace IDs |
|---|---|---|---|---|---|---|
| WORK-ADMIN-LOCKS | ACT-001 | test | lock behavior | test admin locks | PASS | SC-101, DESIGN-401 |

## Activation Slice

| Activation Slice ID | Applicability | Seam | Input | Output | Source Reference | Trace IDs | Disposition | Status | Decision Reference | Deferred Unit ID |
|---|---|---|---|---|---|---|---|---|---|---|
| ACT-001 | applicable | upstream-response | service request | raw config | source#upstream; implementation=lib/admin/lock_subscription.dart | REQ-101, SC-101, DESIGN-401 | implement | verified | not-applicable | not-applicable |
| ACT-001 | applicable | requested-key | raw config | lock key | source#key; implementation=lib/admin/lock_subscription.dart | REQ-101, SC-101, DESIGN-401 | implement | verified | not-applicable | not-applicable |
| ACT-001 | applicable | parse-model | lock key | parsed lock | source#parse; implementation=lib/config_normalizer.dart | REQ-101, SC-101, DESIGN-401 | implement | verified | not-applicable | not-applicable |
| ACT-001 | applicable | state-holder | parsed lock | lock state | source#state; implementation=lib/admin/lock_controller.dart | REQ-101, SC-101, DESIGN-401 | implement | verified | not-applicable | not-applicable |
| ACT-001 | applicable | selector | async-classification=immutable | selected lock | source#selector; immutability-evidence=config snapshot; implementation=lib/admin/lock_controller.dart | REQ-101, SC-101, DESIGN-401 | implement | verified | not-applicable | not-applicable |
| ACT-001 | applicable | construct | selected lock | policy=base-owned | source#construct; implementation=lib/admin/admin_route.dart | REQ-101, SC-101, DESIGN-401 | implement | verified | not-applicable | not-applicable |
| ACT-001 | applicable | render | lock state | lock panel | source#render; implementation=lib/admin/lock_panel.dart | REQ-101, SC-101, DESIGN-401 | implement | verified | not-applicable | not-applicable |
| ACT-001 | applicable | downstream-consumer | lock panel | production view | source#consumer; implementation=lib/admin/admin_panel.dart | REQ-101, SC-101, DESIGN-401 | implement | verified | not-applicable | not-applicable |
| ACT-001 | applicable | test | production view | lifecycle-test-trace=DESIGN-401 | source#test; implementation=test/admin/lock_test.dart | REQ-101, SC-101, DESIGN-401 | implement | verified | not-applicable | not-applicable |
'@
}

function Write-Report([string]$Root, [string]$Text) {
  Write-Utf8 (Join-Path $Root 'structural-gate-fixture/10-implementation-report.md') $Text
  Write-AuthorityArtifacts $Root
}

function Set-CompatibilityDualPath([string]$Root, [bool]$IncludeReason = $true, [bool]$IncludeOwner = $true, [bool]$IncludeParity = $true, [string]$Decision = 'approval:TECH-LEAD-ROUTER-COMPAT') {
  $reason = if ($IncludeReason) { '; compatibility-reason=legacy route transition' } else { '' }
  $owner = if ($IncludeOwner) { '; router-owner=lib/admin/admin_route.dart#AdminRoute' } else { '' }
  foreach ($relativePath in @('10-implementation-report.md', 'master-plan.md', '08-migration-plan.md', '07-technical-design.md')) {
    $path = Join-Path $Root "structural-gate-fixture/$relativePath"
    $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
    if ($IncludeParity) { $text = $text -replace 'REQ-101, SC-101, DESIGN-401', 'REQ-101, SC-101, DESIGN-401, PARITY-001' }
    $text = $text -replace 'policy=base-owned', 'policy=compatibility-dual-path'
    $text = $text -replace 'source#construct(?=;|\s+\|)', "source#construct$reason$owner"
    $text = $text -replace '(\| ACT-001 \| applicable \| construct \|[^\r\n]+?\| implement \| verified \|) not-applicable (\| not-applicable \|)', "`$1 $Decision `$2"
    Write-Utf8 $path $text
  }
  Write-DesignApproval $Root
}

function Add-ExtraWorkItemTraceAuthority([string]$Root) {
  foreach ($relativePath in @('master-plan.md', '08-migration-plan.md')) {
    $path = Join-Path $Root "structural-gate-fixture/$relativePath"
    Write-Utf8 $path ((Get-Content -Raw -Encoding utf8 -LiteralPath $path) -replace 'REQ-101, SC-101, DESIGN-401', 'REQ-101, SC-101, DESIGN-401, EXTRA-501')
  }
  $path = Join-Path $Root 'structural-gate-fixture/07-technical-design.md'
  $design = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $design = $design.Replace(
    '| REQ-101, SC-101, DESIGN-401 | migration-unit:UNIT-ADM-002 |',
    '| REQ-101, SC-101, DESIGN-401, EXTRA-501 | migration-unit:UNIT-ADM-002 |'
  )
  Write-Utf8 $path $design
  Write-DesignApproval $Root
}

function Write-AuthorityArtifacts([string]$Root, [string]$AdapterKind = 'migration-unit') {
  $fixture = Join-Path $Root 'structural-gate-fixture'
  Write-Utf8 (Join-Path $fixture 'master-spec.md') @'
---
artifact_type: migration-master-spec
master_spec_id: SPEC-ADMIN-001
revision: 2
status: approved
result: complete
approval_source: human
---
'@
  $adapter = switch ($AdapterKind) {
    'none' { 'none | not-applicable | not-applicable | not-applicable | not-applicable' }
    'task' { 'task | TASK-42 | jira:ADMIN | 12 | approval:TASK-42' }
    'story' { 'story | STORY-9 | ado:ADMIN | 6 | approval:STORY-9' }
    'package' { 'package | pkg:admin-locks | repo:packages | 4 | approval:PACKAGE-4' }
    'phase' { 'phase | PHASE-2 | plan:ADMIN | 8 | approval:PHASE-2' }
    'milestone' { 'milestone | MILESTONE-Q3 | roadmap:ADMIN | 5 | approval:MILESTONE-Q3' }
    default { 'migration-unit | UNIT-ADM-002 | 08-migration-plan.md | 4 | approval:UNIT-ADM-002' }
  }
  $workItemAdapter = switch ($AdapterKind) {
    'none' { 'none' }
    'task' { 'task:TASK-42' }
    'story' { 'story:STORY-9' }
    'package' { 'package:pkg:admin-locks' }
    'phase' { 'phase:PHASE-2' }
    'milestone' { 'milestone:MILESTONE-Q3' }
    default { 'migration-unit:UNIT-ADM-002' }
  }
  Write-Utf8 (Join-Path $fixture 'master-plan.md') @"
---
artifact_type: migration-master-plan
master_plan_id: PLAN-ADMIN-001
master_spec_id: SPEC-ADMIN-001
master_spec_revision: 2
revision: 4
status: approved
scope_status: scope-in-progress
execution_policy: dependency-ready
max_concurrency: 1
produced_at: 2026-08-19
supersedes: PLAN-ADMIN-001@3
---

## Work Items

| Work Item ID | Title | Required | Dependencies | Plan Order | Acceptance | Trace IDs | Delivery Adapter | Status | Latest Attempt | Terminal Evidence | Approval Reference |
|---|---|---|---|---|---|---|---|---|---|---|---|
| WORK-ADMIN-LOCKS | Lock behavior | yes | none | 1 | REQ-101; SC-101; all lock changes finish within 2 seconds | REQ-101, SC-101, DESIGN-401 | $workItemAdapter | ready | none | none | approval:TECH-LEAD-WORK-ADMIN-LOCKS |

## Delivery Adapter Selection

| Work Item ID | Adapter Kind | External ID | Authority | Authority Revision | Approval Reference | Parent Selector | Acceptance | Trace IDs | Mode Constraint | Design Revision | Parent Work Item ID | Decomposition Decision Reference |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| WORK-ADMIN-LOCKS | $adapter | not-applicable | REQ-101; SC-101; all lock changes finish within 2 seconds | REQ-101, SC-101, DESIGN-401 | incremental/preserve-existing | DESIGN-401@6 | not-applicable | not-applicable |

## Approval Record

| Approval Reference | Status | Approved At |
|---|---|---|
| approval:TECH-LEAD-WORK-ADMIN-LOCKS | approved | 2026-08-19 |

## Revision History

| Artifact ID | Revision | Supersedes | Change Summary | Affected Work Items | Approval Reference |
|---|---|---|---|---|---|
| PLAN-ADMIN-001 | 4 | PLAN-ADMIN-001@3 | approved lock work | WORK-ADMIN-LOCKS | approval:TECH-LEAD-WORK-ADMIN-LOCKS |
"@
  $planUnitId = if ($AdapterKind -eq 'migration-unit') { 'UNIT-ADM-002' } else { 'not-applicable' }
  $orderedUnitsHeading = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('Q8OhYyDEkcahbiB24buLIG1pZ3JhdGlvbiB0aGVvIHRo4bupIHThu7E='))
  $orderedUnitsSection = if ($AdapterKind -eq 'migration-unit') {
@"
## $orderedUnitsHeading

| Order | Migration Unit ID | Bootstrap Scope | Foundation Baseline ID | Foundation Approval Reference | Dependencies | Acceptance | Mode Constraint | Trace IDs | Delivery Change Boundary | Approval Reference | Approval Status |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | UNIT-ADM-002 | not-required | not-applicable | not-applicable | none | REQ-101; SC-101; all lock changes finish within 2 seconds | incremental/preserve-existing | REQ-101, SC-101, DESIGN-401 | one-unit-one-change | approval:UNIT-ADM-002 | approved |
"@
  } else { '' }
  Write-Utf8 (Join-Path $fixture '08-migration-plan.md') @"
---
step_id: 08-plan-waves
status: approved
result: complete
approval_source: human
run_id: RUN-ADMIN-001
revision: 4
produced_at: 2026-08-19
responsibility_contract:
  version: 1
  applicability: required
---

$orderedUnitsSection

## Work Item Adapter Trace

| Migration Unit ID | Work Item ID | Parent Work Item ID | Master Plan Reference | Master Plan Revision | Decomposition Decision Reference | Design Revision |
|---|---|---|---|---|---|---|
| $planUnitId | WORK-ADMIN-LOCKS | not-applicable | master-plan.md | 4 | not-applicable | DESIGN-401@6 |

## Responsibility Owner References

| Work Item ID | Design Revision | Responsibility IDs | Shared Foundation IDs | Integration Responsibility IDs | Independent Boundary Evidence |
|---|---|---|---|---|---|
| WORK-ADMIN-LOCKS | DESIGN-401@6 | RESP-LOCK-CONTROLLER, RESP-LOCK-PANEL | not-applicable | not-applicable | architecture-rules.md#RULE-LOCK-001: independently implementable, reviewable, verifiable, and revertible |
"@
  Write-Utf8 (Join-Path $fixture '02-discovery.md') @'
---
step_id: 02-discovery
status: approved
result: complete
produced_at: 2026-08-19
responsibility_contract:
  version: 1
  applicability: required
---

## Comparable Target Exemplars

| Concern | Path | Inspected Symbols | Observed Pattern | Primary Responsibility | Owned Capabilities | Verification Owner | Comparable Reason | Evidence | Inspection Status | Classification | Classification Authority | Classification Evidence |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| module/container composition | lib/admin/admin_module.dart | AdminModule.build | module pattern | compose admin module | CAP-ADMIN-MODULE | VERIFY-OWNER-ADMIN-MODULE | same production responsibility and activation path | discovery.md#EX-01 | verified | preferred | factual-discovery-evidence | inspection:lib/admin/admin_module.dart:1-40; inspection:test/admin/lock_test.dart:1-40 |
| main/child presentation boundaries | lib/admin/admin_panel.dart | AdminPanel.build | panel pattern | render admin panel | CAP-ADMIN-PANEL | VERIFY-OWNER-ADMIN-PANEL | same production responsibility and activation path | discovery.md#EX-02 | verified | preferred | factual-discovery-evidence | inspection:lib/admin/admin_panel.dart:1-40; inspection:test/admin/lock_test.dart:1-40 |
| unit/component organization | lib/admin/lock_section.dart | LockSection.build | section pattern | compose lock section | CAP-LOCK-SECTION | VERIFY-OWNER-LOCK-SECTION | same production responsibility and activation path | discovery.md#EX-03 | verified | preferred | factual-discovery-evidence | inspection:lib/admin/lock_section.dart:1-40; inspection:test/admin/lock_test.dart:1-40 |
| controller/provider/state pattern | lib/admin/lock_controller.dart | LockController.build | provider pattern | own lock state | CAP-LOCK-STATE | VERIFY-OWNER-LOCK-STATE | same production responsibility and activation path | discovery.md#EX-04 | verified | preferred | factual-discovery-evidence | inspection:lib/admin/lock_controller.dart:1-40; inspection:test/admin/lock_test.dart:1-40 |
| routing and lifecycle | lib/admin/admin_route.dart | AdminRoute.build | route pattern | own route lifecycle | CAP-ADMIN-ROUTE | VERIFY-OWNER-ADMIN-ROUTE | same production responsibility and activation path | discovery.md#EX-05 | verified | preferred | factual-discovery-evidence | inspection:lib/admin/admin_route.dart:1-40; inspection:test/admin/lock_test.dart:1-40 |
| localization | lib/l10n/admin_strings.dart | AdminStrings.lockTitle | l10n pattern | own lock strings | CAP-ADMIN-L10N | VERIFY-OWNER-ADMIN-L10N | same production responsibility and activation path | discovery.md#EX-06 | verified | preferred | factual-discovery-evidence | inspection:lib/l10n/admin_strings.dart:1-40; inspection:test/admin/lock_test.dart:1-40 |
| service/config subscription and normalization | lib/admin/lock_subscription.dart | LockSubscription.start | subscription pattern | own config subscription | CAP-LOCK-SUBSCRIPTION | VERIFY-OWNER-LOCK-SUBSCRIPTION | same production responsibility and activation path | discovery.md#EX-07 | verified | preferred | factual-discovery-evidence | inspection:lib/admin/lock_subscription.dart:1-40; inspection:test/admin/lock_test.dart:1-40 |
| test harness and production-boundary tests | test/admin/lock_test.dart | main | harness pattern | verify production lock boundary | CAP-LOCK-TEST | VERIFY-OWNER-LOCK-TEST | same production responsibility and activation path | discovery.md#EX-08 | verified | preferred | factual-discovery-evidence | inspection:test/admin/lock_test.dart:1-40; inspection:lib/admin/lock_panel.dart:1-40 |

## Inspected Symbols

| Concern | Path | Symbol | Inspection Scope | Evidence |
|---|---|---|---|---|
| controller/provider/state pattern | lib/admin/lock_controller.dart | LockController.build | complete declaration and consumers | discovery.md#EX-04 |

## Target Data-flow Trace

| Stage | Path/Symbol | Input | Transformation | Output/Consumer | Evidence |
|---|---|---|---|---|---|
| source | lib/config_service.dart#ConfigSource | service event | operation=read; owner=lib/config_service.dart#ConfigSource | raw config | config.dart:10-30 |
| subscription | lib/admin/lock_subscription.dart#LockSubscription.start | raw config | operation=subscribe; owner=lib/admin/lock_subscription.dart#LockSubscription.start | subscribed config | subscription.dart:10-30 |
| normalization | lib/config_normalizer.dart#ConfigNormalizer.normalize | subscribed config | operation=normalize; owner=lib/config_normalizer.dart#ConfigNormalizer.normalize | normalized config | normalizer.dart:10-30 |
| state | lib/admin/lock_controller.dart#LockController.build | normalized config | operation=store; owner=lib/admin/lock_controller.dart#LockController.build | feature state | controller.dart:10-30 |
| selection | lib/admin/lock_controller.dart#LockController.select | feature state | operation=select; owner=lib/admin/lock_controller.dart#LockController.select | selected state | controller.dart:31-50 |
| render | lib/admin/lock_panel.dart#LockPanel.build | selected state | operation=render; owner=lib/admin/lock_panel.dart#LockPanel.build | production view | panel.dart:10-30 |
| test | test/admin/lock_test.dart#main | production view | operation=verify; owner=test/admin/lock_test.dart#main | verified boundary | lock_test.dart:10-30 |

## No-equivalent Gaps

| Concern | Gap Reference | Conflict Reference | Resolved Decision | Approval Reference |
|---|---|---|---|---|
| none | not-applicable | not-applicable | not-applicable | not-applicable |
'@
  Write-Utf8 (Join-Path $fixture '07-technical-design.md') @"
---
step_id: 07-technical-design
status: draft
result: complete
produced_at: 2026-08-19
revision: DESIGN-401@6
responsibility_contract:
  version: 1
  applicability: required
---

## Approved Master Plan Evidence

| Master Plan Reference | Master Plan ID | Revision | Status | Work Item ID | Acceptance | Trace IDs | Delivery Adapter | Decomposition Decision Reference | Approval Reference | Evidence Reference |
|---|---|---|---|---|---|---|---|---|---|---|
| master-plan.md#PLAN-ADMIN-001 | PLAN-ADMIN-001 | 4 | approved | WORK-ADMIN-LOCKS | REQ-101; SC-101; all lock changes finish within 2 seconds | REQ-101, SC-101, DESIGN-401 | $workItemAdapter | not-applicable | approval:TECH-LEAD-WORK-ADMIN-LOCKS | master-plan.md#PLAN-ADMIN-001@revision=4:WORK-ADMIN-LOCKS |

## Work Item Trace

| Work Item ID | Master Plan Reference | Master Plan Revision | Acceptance Traces | Decomposition Decision Reference |
|---|---|---|---|---|
| WORK-ADMIN-LOCKS | master-plan.md#PLAN-ADMIN-001 | 4 | REQ-101, SC-101 | not-applicable |

## Target Structure Conformance Matrix

| Concern | Working Exemplar | Observed Target Pattern | Proposed Path/Symbol | Conforms | Deviation Reference |
|---|---|---|---|---|---|
| module/container composition | lib/admin/admin_module.dart#AdminModule.build | path=lib/admin/admin_module.dart#AdminModule.build; symbols=AdminModule.build, AdminModule; boundary=module; mechanism=targetModule | lib/admin/lock_controller.dart#LockController | yes | not-applicable |
| main/child presentation boundaries | lib/admin/admin_panel.dart#AdminPanel.build | path=lib/admin/admin_panel.dart#AdminPanel.build; symbols=AdminPanel.build, AdminPanel; boundary=presentation; mechanism=targetPanel; wrapper=AdminPanel.build | lib/admin/lock_panel.dart#LockPanel; wrapper=AdminPanel.build | yes | not-applicable |
| unit/component organization | lib/admin/lock_section.dart#LockSection.build | path=lib/admin/lock_section.dart#LockSection.build; symbols=LockSection.build, LockSection; boundary=component; mechanism=targetComponent | lib/admin/lock_panel.dart#LockPanel | yes | not-applicable |
| controller/provider/state pattern | lib/admin/lock_controller.dart#LockController.build | path=lib/admin/lock_controller.dart#LockController.build; symbols=LockController.build, LockController; boundary=provider; mechanism=targetProvider | lib/admin/lock_controller.dart#LockController | yes | not-applicable |
| routing and lifecycle | lib/admin/admin_route.dart#AdminRoute.build | path=lib/admin/admin_route.dart#AdminRoute.build; symbols=AdminRoute.build, AdminRoute; boundary=router; mechanism=targetRouter | lib/admin/lock_panel.dart#LockPanel | yes | not-applicable |
| localization | lib/l10n/admin_strings.dart#AdminStrings.lockTitle | path=lib/l10n/admin_strings.dart#AdminStrings.lockTitle; symbols=AdminStrings.lockTitle, AdminStrings; boundary=localization; mechanism=targetLocalization | lib/admin/lock_panel.dart#LockPanel | yes | not-applicable |
| service/config subscription and normalization | lib/admin/lock_subscription.dart#LockSubscription.start | path=lib/admin/lock_subscription.dart#LockSubscription.start; symbols=LockSubscription.start, LockSubscription; boundary=subscription; mechanism=targetSubscription | lib/admin/lock_controller.dart#LockController | yes | not-applicable |
| test harness and production-boundary tests | test/admin/lock_test.dart#main | path=test/admin/lock_test.dart#main; symbols=main, TestHarness; boundary=test; mechanism=targetHarness | lib/admin/lock_panel.dart#LockPanel | yes | not-applicable |

## Approved Structural Deviations

| Deviation Reference | Concern | Conflict Reference | Resolved Decision | Tech Lead Approval |
|---|---|---|---|---|
| none | not-applicable | not-applicable | not-applicable | not-applicable |

## Planned File Tree

| Planned Path | Planned Symbol | Responsibility | Exemplar or Deviation Reference |
|---|---|---|---|
| lib/admin/lock_controller.dart | LockController | state/subscription owner | discovery.md#EX-04 |
| lib/admin/lock_panel.dart | LockPanel | presentation | discovery.md#EX-02 |

## File Responsibility Matrix

| Responsibility ID | Owner Path | Owner Symbol | Boundary Kind | Primary Responsibility | Owned Capability IDs | Trace IDs | Atomic Boundary ID | Public Symbols | External Effects | Target Exemplar | Exemplar Classification | Classification Authority | Classification Evidence | Architecture Authority | Co-location Policy | Co-location Evidence | Verification Owner References | Conformance | Deviation Reference |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| RESP-LOCK-CONTROLLER | lib/admin/lock_controller.dart | LockController | application | own lock state | CAP-LOCK-STATE | REQ-101; SC-101; DESIGN-401; WORK-ADMIN-LOCKS | not-applicable | LockController | none | lib/admin/lock_controller.dart#LockController.build | preferred | factual-discovery-evidence | inspection:lib/admin/lock_controller.dart:1-40; inspection:test/admin/lock_test.dart:1-40 | target-exemplar | feature-local | same capability lifecycle verification and revert boundary | VERIFY-OWNER-LOCK-CONTROLLER | yes | not-applicable |
| RESP-LOCK-PANEL | lib/admin/lock_panel.dart | LockPanel | presentation | render lock panel | CAP-LOCK-PRESENTATION | REQ-101; SC-101; DESIGN-401; WORK-ADMIN-LOCKS | not-applicable | LockPanel | none | lib/admin/admin_panel.dart#AdminPanel.build | preferred | factual-discovery-evidence | inspection:lib/admin/admin_panel.dart:1-40; inspection:test/admin/lock_test.dart:1-40 | target-exemplar | feature-local | same capability lifecycle verification and revert boundary | VERIFY-OWNER-LOCK-PANEL | yes | not-applicable |

## Verification Ownership Matrix

| Verification Owner ID | Production Responsibility ID | Capability ID | Evidence Path | Evidence Symbol or Scenario | Evidence Kind | Verification Disposition | Production Binding Evidence | Decision Reference | Verdict | Deviation Reference |
|---|---|---|---|---|---|---|---|---|---|---|
| VERIFY-OWNER-LOCK-CONTROLLER | RESP-LOCK-CONTROLLER | CAP-LOCK-STATE | test/admin/lock_test.dart | lock controller contract | contract | required | invokes lib/admin/lock_controller.dart#LockController | not-applicable | PASS | not-applicable |
| VERIFY-OWNER-LOCK-PANEL | RESP-LOCK-PANEL | CAP-LOCK-PRESENTATION | test/admin/lock_test.dart | lock panel contract | contract | required | invokes lib/admin/lock_panel.dart#LockPanel | not-applicable | PASS | not-applicable |

## Provider/Router/Localization/Subscription Boundaries

| Boundary | Owner Path/Symbol | Input | Output | Lifecycle/Failure Policy | Evidence |
|---|---|---|---|---|---|
| provider | lib/admin/lock_controller.dart#LockController | command | state | mechanism=targetProvider; dispose on route exit | design#provider |
| router | lib/admin/admin_route.dart#AdminRoute | navigation | route | mechanism=targetRouter; route guard | design#router |
| localization | lib/l10n/admin_strings.dart#AdminStrings | key | string | mechanism=targetLocalization; fallback policy | design#localization |
| subscription | lib/admin/lock_subscription.dart#LockSubscription | config | normalized state | mechanism=targetSubscription; reconnect/error | design#subscription |
| lifecycle | lib/admin/lock_controller.dart#LockController | route event | subscription state | mechanism=targetLifecycle; dispose/restart | design#lifecycle |

## Activation Slice

| Activation Slice ID | Applicability | Seam | Input | Output | Source Reference | Trace IDs | Disposition | Status | Decision Reference | Deferred Unit ID |
|---|---|---|---|---|---|---|---|---|---|---|
| ACT-001 | applicable | upstream-response | service request | raw config | source#upstream | REQ-101, SC-101, DESIGN-401 | implement | verified | not-applicable | not-applicable |
| ACT-001 | applicable | requested-key | raw config | lock key | source#key | REQ-101, SC-101, DESIGN-401 | implement | verified | not-applicable | not-applicable |
| ACT-001 | applicable | parse-model | lock key | parsed lock | source#parse | REQ-101, SC-101, DESIGN-401 | implement | verified | not-applicable | not-applicable |
| ACT-001 | applicable | state-holder | parsed lock | lock state | source#state | REQ-101, SC-101, DESIGN-401 | implement | verified | not-applicable | not-applicable |
| ACT-001 | applicable | selector | async-classification=immutable | selected lock | source#selector; immutability-evidence=config snapshot | REQ-101, SC-101, DESIGN-401 | implement | verified | not-applicable | not-applicable |
| ACT-001 | applicable | construct | selected lock | policy=base-owned | source#construct | REQ-101, SC-101, DESIGN-401 | implement | verified | not-applicable | not-applicable |
| ACT-001 | applicable | render | lock state | lock panel | source#render | REQ-101, SC-101, DESIGN-401 | implement | verified | not-applicable | not-applicable |
| ACT-001 | applicable | downstream-consumer | lock panel | production view | source#consumer | REQ-101, SC-101, DESIGN-401 | implement | verified | not-applicable | not-applicable |
| ACT-001 | applicable | test | production view | lifecycle-test-trace=DESIGN-401 | source#test | REQ-101, SC-101, DESIGN-401 | implement | verified | not-applicable | not-applicable |
"@
  Write-DesignApproval $Root
}

function Invoke-StructuralValidation([string]$Root) {
  $script:errors.Clear()
  $contract = Get-Content -Raw -Encoding utf8 (Join-Path $Root 'contracts/target-structure-conformance.md')
  Test-StructuralGate $Root $contract
  return @($script:errors)
}

function Assert-Accepted([string]$Name, [string]$Root) {
  $actual = @(Invoke-StructuralValidation $Root)
  if ($actual.Count -ne 0) {
    throw "$Name expected PASS, got: $($actual -join ' || ')"
  }
  $script:passed++
}

function Assert-Rejected([string]$Name, [string]$Root, [string]$Expected) {
  $actual = @(Invoke-StructuralValidation $Root)
  if (-not ($actual -match [regex]::Escape($Expected))) {
    throw "$Name expected error containing '$Expected', got: $($actual -join ' || ')"
  }
  $script:passed++
}

function Get-AuthorityTextRevision([string]$Text) {
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Text.Replace("`r`n", "`n"))
    return 'sha256:' + ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '')
  }
  finally { $sha.Dispose() }
}

function Get-AuthorityTreeRevision([string]$Root) {
  $manifest = @(Get-ChildItem -LiteralPath $Root -File -Recurse | Sort-Object { $_.FullName.Substring($Root.Length).Replace('\', '/') } | ForEach-Object {
    $relative = $_.FullName.Substring($Root.Length).TrimStart('\', '/').Replace('\', '/')
    $content = Get-Content -Raw -Encoding utf8 -LiteralPath $_.FullName
    "$relative`n$($content.Replace("`r`n", "`n"))"
  }) -join "`n"
  return Get-AuthorityTextRevision $manifest
}

function Write-ApprovedProjectProfile([string]$FixtureRoot) {
  $docs = Join-Path $FixtureRoot 'docs/aitoolkit'
  $pack = Join-Path $docs 'migration-project'
  [void](New-Item -ItemType Directory -Path $pack -Force)
  Write-Utf8 (Join-Path $pack 'SKILL.md') "# Approved structural-gate fixture pack`n"
  $reviewedAt = '2026-08-20T12:00:00Z'
  $reviewEvidence = 'docs/aitoolkit/project-pack-review.md'
  $profile = @"
schema_version: 1
project:
  id: structural-gate-fixture
migration:
  mode: incremental
  unit: feature
  architecture_policy: preserve-existing
automation:
  mode: interactive
output:
  artifact_language: vi
legacy:
  path: null
  language: unknown
  framework: unknown
target:
  path: null
  language: unknown
  framework: unknown
documents:
  requirements: []
  uiux: []
  migration: []
  architecture: []
base_branch: null
test_cmd: null
lint_cmd: null
build_cmd: null
coverage_cmd: null
review_focus: []
verification:
  behavior_parity: required
  regression: optional
  visual_fidelity: optional
project_pack:
  path: docs/aitoolkit/migration-project
  reviewed_at: $reviewedAt
  review_evidence: $reviewEvidence
"@
  $profileRevision = Get-AuthorityTextRevision ($profile.Replace("reviewed_at: $reviewedAt", 'reviewed_at: <review-metadata>').Replace("review_evidence: $reviewEvidence", 'review_evidence: <review-metadata>'))
  $packRevision = Get-AuthorityTreeRevision $pack
  Write-Utf8 (Join-Path $docs 'project.yaml') $profile
  Write-Utf8 (Join-Path $docs 'project-pack-review.md') "---`nstep_id: 04-project-pack-review`nstatus: approved`nresult: complete`napproval_source: human`nproduced_at: 2026-08-20`n---`n`n## Độ mới của review`n`n| Reviewed At | Profile Revision | Pack Revision | Source/Target/Document Revisions | Approval Evidence |`n|---|---|---|---|---|`n| $reviewedAt | $profileRevision | $packRevision | not-applicable | approval:TECH-LEAD-PROJECT-PACK-001 |`n"
}

function Set-StructuralMode([string]$Root, [switch]$UseGreenfieldAuthority) {
  $fixture = Join-Path $Root 'structural-gate-fixture'
  foreach ($relativePath in @('10-implementation-report.md', 'master-plan.md', '08-migration-plan.md')) {
    $path = Join-Path $fixture $relativePath
    $text = (Get-Content -Raw -Encoding utf8 -LiteralPath $path).Replace('incremental/preserve-existing', 'greenfield/design-new')
    Write-Utf8 $path $text
  }
  if ($UseGreenfieldAuthority) {
    foreach ($relativePath in @('10-implementation-report.md', '07-technical-design.md')) {
      $path = Join-Path $fixture $relativePath
      $text = (Get-Content -Raw -Encoding utf8 -LiteralPath $path).Replace('target-exemplar', 'approved-greenfield-design')
      Write-Utf8 $path $text
    }
    Write-DesignApproval $Root
  }
}

try {
  . $validatorPath
  . $deliveryValidatorPath
  . $targetValidatorPath
  $canonicalSelectorReportRow = '| WORK-ADMIN-LOCKS | migration-unit | UNIT-ADM-002 | 08-migration-plan.md | 4 | approval:UNIT-ADM-002 | not-applicable | REQ-101; SC-101; all lock changes finish within 2 seconds | REQ-101, SC-101, DESIGN-401 | incremental/preserve-existing | DESIGN-401@6 | not-applicable | not-applicable | PASS |'
  $canonicalTaskSelectorReportRow = '| WORK-ADMIN-LOCKS | task | TASK-42 | jira:ADMIN | 12 | approval:TASK-42 | not-applicable | REQ-101; SC-101; all lock changes finish within 2 seconds | REQ-101, SC-101, DESIGN-401 | incremental/preserve-existing | DESIGN-401@6 | not-applicable | not-applicable | PASS |'

  $root = New-Case 'canonical-task5-selector-fixture'
  Write-CanonicalTask5Fixture $root
  $script:errors.Clear()
  Test-DeliveryAdapters $root (Get-Content -Raw -Encoding utf8 (Join-Path $root 'contracts/migration-scope-orchestration.md'))
  if ($script:errors.Count -ne 0) { throw "canonical Task 5 fixture expected PASS, got: $($script:errors -join ' || ')" }
  $script:passed++

  $root = New-Case 'greenfield-responsibility-mode'
  Write-Report $root ((Get-ValidReport).Replace('incremental/preserve-existing', 'greenfield/design-new'))
  Set-StructuralMode $root -UseGreenfieldAuthority
  Assert-Accepted 'structural gate passes the approved greenfield mode to responsibility validators' $root

  $root = New-Case 'greenfield-responsibility-mode-mismatch'
  Write-Report $root ((Get-ValidReport).Replace('incremental/preserve-existing', 'greenfield/design-new'))
  Set-StructuralMode $root
  Assert-Rejected 'structural gate rejects design authority that mismatches approved greenfield mode' $root 'greenfield-authority-invalid'

  $root = New-Case 'missing-master-context'
  Write-Report $root ((Get-ValidReport) -replace '(?s)## Master Scope Context.*?(?=## Canonical Adapter Evidence)', '')
  Assert-Rejected 'missing master context blocks before edit' $root 'Structural gate missing Master Scope Context'

  $root = New-Case 'mismatched-master-scope'
  Write-Report $root ((Get-ValidReport) -replace 'PLAN-ADMIN-001', 'PLAN-BILLING-001')
  Assert-Rejected 'mismatched master IDs block before edit' $root 'Structural gate Master Scope Context IDs must share the same scope'

  $root = New-Case 'non-canonical-selector'
  Write-Report $root ((Get-ValidReport) -replace [regex]::Escape($canonicalSelectorReportRow), ($canonicalSelectorReportRow -replace 'PASS \|$', 'BLOCKED |'))
  Assert-Rejected 'non-canonical selector blocks before edit' $root 'Structural gate canonical adapter must resolve with PASS'

  $root = New-Case 'stale-selected-plan-reference'
  Write-Report $root ((Get-ValidReport).Replace('| UNIT-ADM-002 | 08-migration-plan.md@4 | approval:UNIT-ADM-002 |', '| UNIT-ADM-002 | 08-migration-plan.md@3 | approval:UNIT-ADM-002 |'))
  Assert-Rejected 'selected migration unit rejects a stale plan revision' $root 'Structural gate migration-unit adapter requires exact Selected Migration Unit evidence'

  $root = New-Case 'selector-authority-embeds-revision'
  Write-Report $root ((Get-ValidReport).Replace('| migration-unit | UNIT-ADM-002 | 08-migration-plan.md | 4 |', '| migration-unit | UNIT-ADM-002 | 08-migration-plan.md@4 | 4 |'))
  Assert-Rejected 'selector authority and revision remain separate canonical sources' $root 'Structural gate canonical adapter must resolve with PASS'

  $root = New-Case 'unread-exemplar'
  Write-Report $root ((Get-ValidReport) -replace '\| read-complete \|', '| unread |')
  Assert-Rejected 'unread exemplar blocks before edit' $root 'Structural gate exemplar must be read-complete'

  $root = New-Case 'file-tree-mismatch'
  Write-Report $root ((Get-ValidReport) -replace 'lib/admin/lock_panel.dart \| LockPanel \| yes', 'lib/admin/other_panel.dart | OtherPanel | yes')
  Assert-Rejected 'actual file tree drift blocks before edit' $root 'Structural gate actual file tree must match the complete external approved planned path and symbol'

  $root = New-Case 'tree-match-extra-responsibility'
  $responsibilityDrift = (Get-ValidReport).Replace('| LockController | none | lib/admin/lock_controller.dart#LockController.build |', '| LockController; WifiResetProvider | settings.write:wifi-reset | lib/admin/lock_controller.dart#LockController.build |')
  Write-Report $root $responsibilityDrift
  Assert-Rejected 'tree match cannot hide extra ownership' $root 'responsibility-public-symbol-mismatch'

  $root = New-Case 'runtime-waiver-responsibility-drift'
  $waivedResponsibilityDrift = $responsibilityDrift.Replace('| NOT_RUN | PASS | PASS |', '| WAIVED | PASS | PASS |')
  Write-Report $root $waivedResponsibilityDrift
  Assert-Rejected 'runtime waiver cannot waive responsibility' $root 'responsibility-waiver-forbidden'

  $root = New-Case 'missing-actual-responsibility-owner'
  Write-Report $root ((Get-ValidReport) -replace '(?m)^\| RESP-LOCK-PANEL \|.*\r?\n', '')
  Assert-Rejected 'missing planned responsibility owner blocks' $root 'responsibility-owner-missing'

  $root = New-Case 'extra-actual-responsibility-owner'
  $report = Get-ValidReport
  $controllerRow = [regex]::Match($report, '(?m)^\| RESP-LOCK-CONTROLLER \|.*$').Value
  Write-Report $root ($report.Replace($controllerRow, "$controllerRow`n$controllerRow"))
  Assert-Rejected 'extra actual responsibility owner blocks' $root 'responsibility-owner-extra'

  $root = New-Case 'actual-responsibility-capability-drift'
  Write-Report $root ((Get-ValidReport).Replace('| CAP-LOCK-STATE | REQ-101; SC-101; DESIGN-401; WORK-ADMIN-LOCKS |', '| CAP-WIFI-RESET | REQ-101; SC-101; DESIGN-401; WORK-ADMIN-LOCKS |'))
  Assert-Rejected 'actual responsibility capability drift blocks' $root 'responsibility-capability-mismatch'

  $root = New-Case 'actual-responsibility-effect-drift'
  Write-Report $root ((Get-ValidReport).Replace('| LockController | none | lib/admin/lock_controller.dart#LockController.build |', '| LockController | settings.write:wifi-reset | lib/admin/lock_controller.dart#LockController.build |'))
  Assert-Rejected 'actual responsibility external-effect drift blocks' $root 'responsibility-external-effect-mismatch'

  $root = New-Case 'actual-responsibility-colocation-drift'
  Write-Report $root ((Get-ValidReport).Replace('| target-exemplar | feature-local | same capability lifecycle verification and revert boundary | VERIFY-OWNER-LOCK-CONTROLLER |', '| target-exemplar | shared-foundation | widened ownership after approval | VERIFY-OWNER-LOCK-CONTROLLER |'))
  Assert-Rejected 'actual responsibility cannot broaden co-location' $root 'co-location-policy-invalid'

  $root = New-Case 'actual-verification-fake-binding'
  Write-Report $root ((Get-ValidReport).Replace('invokes lib/admin/lock_controller.dart#LockController | not-applicable | PASS | not-applicable | diff:test/admin/lock_test.dart#lock-controller-contract', 'invokes test/fake_registry.dart#LockController | not-applicable | PASS | not-applicable | diff:test/admin/lock_test.dart#lock-controller-contract'))
  Assert-Rejected 'actual verification must bind the production owner' $root 'verification-production-binding-missing'

  $root = New-Case 'actual-verification-invalid-not-applicable'
  $invalidNotApplicableReport = (Get-ValidReport).Replace('| contract | required | invokes lib/admin/lock_controller.dart#LockController | not-applicable | PASS | not-applicable |', '| contract | not-applicable-approved | invokes lib/admin/lock_controller.dart#LockController | approval:OWNER-LOCK | PASS | not-applicable |')
  Write-Report $root $invalidNotApplicableReport
  Assert-Rejected 'behavior owner cannot use not-applicable-approved verification' $root 'verification-disposition-invalid'

  $root = New-Case 'responsibility-subverdict-blocked'
  $blockedResponsibilityReport = (Get-ValidReport).Replace('| 1 | PASS | PASS | PASS | PASS |', '| 1 | PASS | BLOCKED | PASS | BLOCKED |')
  Write-Report $root $blockedResponsibilityReport
  Assert-Rejected 'structural PASS requires every responsibility sub-verdict PASS' $root 'Structural gate tree, responsibility, and verification ownership verdicts must all PASS'

  $root = New-Case 'direct-widget-service-router'
  Write-Report $root ((Get-ValidReport) -replace 'widget -> provider -> service', 'widget -> service')
  Assert-Rejected 'direct widget service call blocks before edit' $root 'Structural gate provider boundary forbids direct widget service or router calls'

  foreach ($path in @('button -> widget -> service', 'panel -> WIDGET -> Router', 'button  ->  Widget -> SERVICE -> result')) {
    $root = New-Case ('nested-direct-widget-edge-' + [guid]::NewGuid().ToString('N'))
    Write-Report $root ((Get-ValidReport) -replace 'widget -> provider -> service', $path)
    Assert-Rejected "nested direct edge '$path' blocks before edit" $root 'Structural gate provider boundary forbids direct widget service or router calls'
  }

  $root = New-Case 'widget-provider-service-is-not-direct'
  Write-Report $root ((Get-ValidReport) -replace 'widget -> provider -> service', 'button -> widget -> provider -> service')
  Assert-Accepted 'provider between widget and service avoids false positive' $root

  foreach ($path in @(
    'AdminWidget -> service',
    'widget.build() -> router.navigate()',
    'ui.AdminWidget.build() -> navigation.AdminRouter.navigate()',
    ' panel.AdminWidget ( )  ->  api.LockService.fetch ( ) '
  )) {
    $root = New-Case ('member-direct-widget-edge-' + [guid]::NewGuid().ToString('N'))
    Write-Report $root ((Get-ValidReport) -replace 'widget -> provider -> service', $path)
    Assert-Rejected "identifier/member direct edge '$path' blocks before edit" $root 'Structural gate provider boundary forbids direct widget service or router calls'
  }

  foreach ($path in @('AdminWidgetPresenter -> router.navigate()', 'WidgetController -> service.fetch()', 'AdminPresenter -> AdminRouter.navigate()')) {
    $root = New-Case ('non-widget-identifier-' + [guid]::NewGuid().ToString('N'))
    Write-Report $root ((Get-ValidReport) -replace 'widget -> provider -> service', $path)
    Assert-Accepted "presenter/controller '$path' is not a direct widget edge" $root
  }

  $root = New-Case 'wrong-localization-boundary'
  Write-Report $root ((Get-ValidReport) -replace 'targetLocalization', 'inline-string')
  Assert-Rejected 'wrong localization mechanism blocks before edit' $root 'Structural gate localization must use the external approved target localization boundary'

  $root = New-Case 'missing-subscription-lifecycle'
  $report = Get-ValidReport
  $report = $report -replace '(?m)^\| subscription \|.*\r?\n', ''
  $report = $report -replace '(?m)^\| lifecycle \|.*\r?\n', ''
  Write-Report $root $report
  Assert-Rejected 'missing subscription and lifecycle paths block before edit' $root 'Structural gate missing required boundary: subscription'
  Assert-Rejected 'missing lifecycle path blocks before edit' $root 'Structural gate missing required boundary: lifecycle'

  $root = New-Case 'unapproved-abstraction'
  Write-Report $root ((Get-ValidReport) -replace '\| not-applicable \| not-applicable \| not-applicable \| not-applicable \| not-applicable \| not-applicable \| not-applicable \|', '| DEV-LOCK-01 | controller/provider/state pattern | CONFLICT-LOCK-01 | LockAggregate | resolved:DECISION-LOCK-01: introduce aggregate | pending | proposed |')
  Assert-Rejected 'unapproved abstraction blocks before edit' $root 'Structural gate deviation must exactly bind Task 6 approved conflict, decision and Tech Lead approval'

  $approvedDeviationRow = '| DEV-LOCK-01 | controller/provider/state pattern | CONFLICT-LOCK-01 | LockAggregate | resolved:DECISION-LOCK-01: introduce approved aggregate | approval:TECH-LEAD-LOCK-01 | approved |'
  $deviationSentinel = '| not-applicable | not-applicable | not-applicable | not-applicable | not-applicable | not-applicable | not-applicable |'

  $root = New-Case 'canonical-approved-structural-deviation'
  Write-Report $root ((Get-ValidReport) -replace [regex]::Escape($deviationSentinel), $approvedDeviationRow)
  Set-ApprovedStructuralDeviation $root
  Assert-Accepted 'report deviation exactly binds Task 6 approval record' $root

  $root = New-Case 'missing-approved-structural-deviation'
  Write-Report $root (Get-ValidReport)
  Set-ApprovedStructuralDeviation $root
  Assert-Rejected 'report cannot omit Task 6 approved deviation' $root 'Structural gate deviations must exactly match external approved matrix dispositions'

  $root = New-Case 'forged-approved-structural-deviation'
  Write-Report $root ((Get-ValidReport) -replace [regex]::Escape($deviationSentinel), ($approvedDeviationRow -replace 'approval:TECH-LEAD-LOCK-01', 'approval:TECH-LEAD-FORGED'))
  Set-ApprovedStructuralDeviation $root
  Assert-Rejected 'report cannot forge Task 6 deviation approval' $root 'Structural gate deviation must exactly bind Task 6 approved conflict, decision and Tech Lead approval'

  $root = New-Case 'extra-approved-structural-deviation'
  $extraDeviation = '| DEV-LOCK-02 | localization | CONFLICT-LOCK-02 | OtherAggregate | resolved:DECISION-LOCK-02: extra | approval:TECH-LEAD-LOCK-02 | approved |'
  Write-Report $root ((Get-ValidReport) -replace [regex]::Escape($deviationSentinel), "$approvedDeviationRow`n$extraDeviation")
  Set-ApprovedStructuralDeviation $root
  Assert-Rejected 'report cannot add a deviation absent from Task 6' $root 'Structural gate deviations must exactly match external approved matrix dispositions'

  $root = New-Case 'missing-activation-path'
  Write-Report $root ((Get-ValidReport) -replace '(?s)## Production Activation Path Evidence.*?(?=## Assurance State)', '')
  Assert-Rejected 'missing production activation path blocks before edit' $root 'Structural gate missing Production Activation Path Evidence'

  $root = New-Case 'architecture-blocked-runtime-waived'
  Write-Report $root ((Get-ValidReport) -replace '\| NOT_RUN \| PASS \| PASS \|', '| WAIVED | BLOCKED | PASS |')
  Assert-Rejected 'runtime waiver cannot waive architecture' $root 'Structural gate architecture and selector/schema states must both be PASS and are not waiver-eligible'

  $root = New-Case 'selector-schema-blocked-runtime-waived'
  Write-Report $root ((Get-ValidReport) -replace '\| NOT_RUN \| PASS \| PASS \|', '| WAIVED | PASS | BLOCKED |')
  Assert-Rejected 'runtime waiver cannot waive selector schema' $root 'Structural gate architecture and selector/schema states must both be PASS and are not waiver-eligible'

  $root = New-Case 'canonical-none-adapter'
  $noneRow = '| WORK-ADMIN-LOCKS | none | not-applicable | not-applicable | not-applicable | not-applicable | not-applicable | REQ-101; SC-101; all lock changes finish within 2 seconds | REQ-101, SC-101, DESIGN-401 | incremental/preserve-existing | DESIGN-401@6 | not-applicable | not-applicable | PASS |'
  $report = (Get-ValidReport) -replace [regex]::Escape($canonicalSelectorReportRow), $noneRow
  $report = $report -replace '(?s)## Selected Migration Unit.*?(?=## Conformance Matrix Reference)', ''
  Write-Report $root $report
  Write-AuthorityArtifacts $root 'none'
  Assert-Accepted 'canonical work item without migration-unit adapter' $root

  $root = New-Case 'canonical-none-selector-approved-generic-delivery'
  $report = (Get-ValidReport) -replace [regex]::Escape($canonicalSelectorReportRow), $noneRow
  $report = $report -replace '(?s)## Selected Migration Unit.*?(?=## Conformance Matrix Reference)', ''
  Write-Report $root $report
  Write-AuthorityArtifacts $root 'none'
  $genericMasterPlanPath = Join-Path $root 'structural-gate-fixture/master-plan.md'
  $genericMasterPlan = (Get-Content -Raw -Encoding utf8 -LiteralPath $genericMasterPlanPath).Replace('| none | ready |', '| generic:admin-locks | ready |')
  Write-Utf8 $genericMasterPlanPath $genericMasterPlan
  $genericDesignPath = Join-Path $root 'structural-gate-fixture/07-technical-design.md'
  $genericDesign = (Get-Content -Raw -Encoding utf8 -LiteralPath $genericDesignPath).Replace('| none | not-applicable | approval:TECH-LEAD-WORK-ADMIN-LOCKS |', '| generic:admin-locks | not-applicable | approval:TECH-LEAD-WORK-ADMIN-LOCKS |')
  Write-Utf8 $genericDesignPath $genericDesign
  Write-DesignApproval $root
  Assert-Accepted 'none selector preserves the exact approved generic delivery adapter' $root

  $root = New-Case 'none-selector-concrete-parent-selector'
  $noneWithParentRow = '| WORK-ADMIN-LOCKS | none | not-applicable | not-applicable | not-applicable | not-applicable | parent:TASK-1 | REQ-101; SC-101; all lock changes finish within 2 seconds | REQ-101, SC-101, DESIGN-401 | incremental/preserve-existing | DESIGN-401@6 | not-applicable | not-applicable | PASS |'
  $report = (Get-ValidReport) -replace [regex]::Escape($canonicalSelectorReportRow), $noneWithParentRow
  $report = $report -replace '(?s)## Selected Migration Unit.*?(?=## Conformance Matrix Reference)', ''
  Write-Report $root $report
  Write-AuthorityArtifacts $root 'none'
  $parentSelectorPlanPath = Join-Path $root 'structural-gate-fixture/master-plan.md'
  $parentSelectorPlan = (Get-Content -Raw -Encoding utf8 -LiteralPath $parentSelectorPlanPath).Replace(
    '| none | not-applicable | not-applicable | not-applicable | not-applicable | not-applicable | REQ-101;',
    '| none | not-applicable | not-applicable | not-applicable | not-applicable | parent:TASK-1 | REQ-101;'
  )
  Write-Utf8 $parentSelectorPlanPath $parentSelectorPlan
  Assert-Rejected 'none selector rejects a concrete parent selector even when report and plan agree' $root 'Structural gate canonical adapter must resolve with PASS'

  $root = New-Case 'none-selector-stale-generic-delivery'
  $report = (Get-ValidReport) -replace [regex]::Escape($canonicalSelectorReportRow), $noneRow
  $report = $report -replace '(?s)## Selected Migration Unit.*?(?=## Conformance Matrix Reference)', ''
  Write-Report $root $report
  Write-AuthorityArtifacts $root 'none'
  $staleGenericPlanPath = Join-Path $root 'structural-gate-fixture/master-plan.md'
  Write-Utf8 $staleGenericPlanPath ((Get-Content -Raw -Encoding utf8 -LiteralPath $staleGenericPlanPath).Replace('| none | ready |', '| generic:stale-admin-locks | ready |'))
  Assert-Rejected 'none selector rejects a generic delivery adapter that mismatches approved Task 6 evidence' $root 'Structural gate report must bind through exact Task 6 approved-plan and work-item trace tables'

  foreach ($adapter in @(
    @{ Kind = 'task'; External = 'TASK-42'; Authority = 'jira:ADMIN'; Revision = '12'; Approval = 'approval:TASK-42' },
    @{ Kind = 'story'; External = 'STORY-9'; Authority = 'ado:ADMIN'; Revision = '6'; Approval = 'approval:STORY-9' },
    @{ Kind = 'package'; External = 'pkg:admin-locks'; Authority = 'repo:packages'; Revision = '4'; Approval = 'approval:PACKAGE-4' },
    @{ Kind = 'phase'; External = 'PHASE-2'; Authority = 'plan:ADMIN'; Revision = '8'; Approval = 'approval:PHASE-2' },
    @{ Kind = 'milestone'; External = 'MILESTONE-Q3'; Authority = 'roadmap:ADMIN'; Revision = '5'; Approval = 'approval:MILESTONE-Q3' }
  )) {
    $root = New-Case "canonical-$($adapter.Kind)-adapter"
    $row = "| WORK-ADMIN-LOCKS | $($adapter.Kind) | $($adapter.External) | $($adapter.Authority) | $($adapter.Revision) | $($adapter.Approval) | not-applicable | REQ-101; SC-101; all lock changes finish within 2 seconds | REQ-101, SC-101, DESIGN-401 | incremental/preserve-existing | DESIGN-401@6 | not-applicable | not-applicable | PASS |"
    $report = (Get-ValidReport) -replace [regex]::Escape($canonicalSelectorReportRow), $row
    $report = $report -replace '(?s)## Selected Migration Unit.*?(?=## Conformance Matrix Reference)', ''
    Write-Report $root $report
    Write-AuthorityArtifacts $root $adapter.Kind
    Assert-Accepted "canonical $($adapter.Kind) work item without invented unit" $root
  }

  $root = New-Case 'generic-adapter-missing-approved-responsibility-owner'
  $taskReport = (Get-ValidReport) -replace [regex]::Escape($canonicalSelectorReportRow), $canonicalTaskSelectorReportRow
  $taskReport = $taskReport -replace '(?s)## Selected Migration Unit.*?(?=## Conformance Matrix Reference)', ''
  Write-Report $root $taskReport
  Write-AuthorityArtifacts $root 'task'
  $responsibilityPlanPath = Join-Path $root 'structural-gate-fixture/08-migration-plan.md'
  Write-Utf8 $responsibilityPlanPath ((Get-Content -Raw -Encoding utf8 -LiteralPath $responsibilityPlanPath).Replace('RESP-LOCK-CONTROLLER, RESP-LOCK-PANEL', 'RESP-LOCK-CONTROLLER'))
  Assert-Rejected 'generic adapter must preserve the complete approved responsibility owner set' $root 'responsibility-owner-missing'

  $root = New-Case 'generic-adapter-invented-responsibility-plan-unit'
  $inventedUnitReport = (Get-ValidReport) -replace [regex]::Escape($canonicalSelectorReportRow), $canonicalTaskSelectorReportRow
  $inventedUnitReport = $inventedUnitReport -replace '(?s)## Selected Migration Unit.*?(?=## Conformance Matrix Reference)', ''
  Write-Report $root $inventedUnitReport
  Write-AuthorityArtifacts $root 'task'
  $inventedUnitPlanPath = Join-Path $root 'structural-gate-fixture/08-migration-plan.md'
  Write-Utf8 $inventedUnitPlanPath ((Get-Content -Raw -Encoding utf8 -LiteralPath $inventedUnitPlanPath).Replace('| not-applicable | WORK-ADMIN-LOCKS |', '| UNIT-INVENTED | WORK-ADMIN-LOCKS |'))
  Assert-Rejected 'generic adapter responsibility plan cannot invent a migration unit' $root 'responsibility-owner-extra'

  $root = New-Case 'generic-adapter-stale-responsibility-plan-revision'
  $stalePlanReport = ((Get-ValidReport) -replace [regex]::Escape($canonicalSelectorReportRow), $canonicalTaskSelectorReportRow).Replace('| WORK-ADMIN-LOCKS | 08-migration-plan.md | 4 | DESIGN-401@6 |', '| WORK-ADMIN-LOCKS | 08-migration-plan.md | 2 | DESIGN-401@6 |')
  $stalePlanReport = $stalePlanReport -replace '(?s)## Selected Migration Unit.*?(?=## Conformance Matrix Reference)', ''
  Write-Report $root $stalePlanReport
  Write-AuthorityArtifacts $root 'task'
  Assert-Rejected 'generic adapter must bind the exact approved responsibility-plan revision' $root 'responsibility-owner-extra'

  $root = New-Case 'generic-adapter-multi-work-item-responsibility-plan'
  $multiPlanReport = (Get-ValidReport) -replace [regex]::Escape($canonicalSelectorReportRow), $canonicalTaskSelectorReportRow
  $multiPlanReport = $multiPlanReport -replace '(?s)## Selected Migration Unit.*?(?=## Conformance Matrix Reference)', ''
  Write-Report $root $multiPlanReport
  Write-AuthorityArtifacts $root 'task'
  $multiPlanPath = Join-Path $root 'structural-gate-fixture/08-migration-plan.md'
  $multiPlan = Get-Content -Raw -Encoding utf8 -LiteralPath $multiPlanPath
  $multiPlan = $multiPlan.Replace('| not-applicable | WORK-ADMIN-LOCKS | not-applicable | master-plan.md | 4 | not-applicable | DESIGN-401@6 |', "| not-applicable | WORK-ADMIN-LOCKS | not-applicable | master-plan.md | 4 | not-applicable | DESIGN-401@6 |`n| not-applicable | WORK-OTHER | not-applicable | master-plan.md | 4 | not-applicable | DESIGN-OTHER@1 |")
  $multiPlan = $multiPlan.Replace('| WORK-ADMIN-LOCKS | DESIGN-401@6 | RESP-LOCK-CONTROLLER, RESP-LOCK-PANEL | not-applicable | not-applicable | architecture-rules.md#RULE-LOCK-001: independently implementable, reviewable, verifiable, and revertible |', "| WORK-ADMIN-LOCKS | DESIGN-401@6 | RESP-LOCK-CONTROLLER, RESP-LOCK-PANEL | not-applicable | not-applicable | architecture-rules.md#RULE-LOCK-001: independently implementable, reviewable, verifiable, and revertible |`n| WORK-OTHER | DESIGN-OTHER@1 | RESP-OTHER | not-applicable | not-applicable | architecture-rules.md#RULE-OTHER-001: independently implementable, reviewable, verifiable, and revertible |")
  Write-Utf8 $multiPlanPath $multiPlan
  Assert-Rejected 'structural gate validates sibling responsibility-plan rows instead of projecting them away' $root 'responsibility-owner-extra'

  foreach ($selectorMutation in @(
    @{ Field = 'Adapter Kind'; From = '| task | TASK-42 |'; To = '| story | TASK-42 |' },
    @{ Field = 'External ID'; From = '| TASK-42 | jira:ADMIN |'; To = '| TASK-99 | jira:ADMIN |' },
    @{ Field = 'Authority'; From = '| jira:ADMIN | 12 |'; To = '| jira:OTHER | 12 |' },
    @{ Field = 'Authority Revision'; From = '| 12 | approval:TASK-42 |'; To = '| 13 | approval:TASK-42 |' },
    @{ Field = 'Approval Reference'; From = '| approval:TASK-42 | not-applicable |'; To = '| approval:TASK-99 | not-applicable |' },
    @{ Field = 'Parent Selector'; From = '| not-applicable | REQ-101;'; To = '| parent:TASK-1 | REQ-101;' },
    @{ Field = 'Acceptance'; From = 'all lock changes finish within 2 seconds | REQ-101, SC-101'; To = 'all lock changes finish within 3 seconds | REQ-101, SC-101' },
    @{ Field = 'Trace IDs'; From = '| REQ-101, SC-101, DESIGN-401 | incremental/preserve-existing |'; To = '| REQ-101, DESIGN-401 | incremental/preserve-existing |' },
    @{ Field = 'Mode Constraint'; From = '| incremental/preserve-existing | DESIGN-401@6 |'; To = '| greenfield/design-new | DESIGN-401@6 |' },
    @{ Field = 'Design Revision'; From = '| DESIGN-401@6 | not-applicable | not-applicable | PASS |'; To = '| DESIGN-401@7 | not-applicable | not-applicable | PASS |' },
    @{ Field = 'Parent Work Item ID'; From = '| DESIGN-401@6 | not-applicable | not-applicable | PASS |'; To = '| DESIGN-401@6 | WORK-ADMIN-PARENT | not-applicable | PASS |' },
    @{ Field = 'Decomposition Decision Reference'; From = '| not-applicable | not-applicable | PASS |'; To = '| not-applicable | DEC-ADMIN-001 | PASS |' }
  )) {
    $root = New-Case ('generic-selector-field-' + ($selectorMutation.Field -replace ' ', '-').ToLowerInvariant())
    $report = (Get-ValidReport) -replace [regex]::Escape($canonicalSelectorReportRow), $canonicalTaskSelectorReportRow
    $report = $report.Replace($selectorMutation.From, $selectorMutation.To)
    $report = $report -replace '(?s)## Selected Migration Unit.*?(?=## Conformance Matrix Reference)', ''
    Write-Report $root $report
    Write-AuthorityArtifacts $root 'task'
    Assert-Rejected "generic selector field must bind exactly: $($selectorMutation.Field)" $root "Structural gate report selector does not match external canonical selector: $($selectorMutation.Field)"
  }

  $root = New-Case 'forged-external-master-plan'
  Write-Report $root (Get-ValidReport)
  $path = Join-Path $root 'structural-gate-fixture/master-plan.md'
  Write-Utf8 $path ((Get-Content -Raw -LiteralPath $path) -replace 'PLAN-ADMIN-001', 'PLAN-ADMIN-999')
  Assert-Rejected 'well-formed report cannot forge external master revision' $root 'Structural gate report must match the external approved master plan revision exactly'

  $root = New-Case 'forged-external-selector'
  Write-Report $root (Get-ValidReport)
  $path = Join-Path $root 'structural-gate-fixture/master-plan.md'
  Write-Utf8 $path ((Get-Content -Raw -LiteralPath $path) -replace 'migration-unit \| UNIT-ADM-002', 'migration-unit | UNIT-ADM-999')
  Assert-Rejected 'self-declared selector PASS cannot override external selector' $root 'Structural gate report selector does not match external canonical selector: External ID'

  $root = New-Case 'forged-canonical-migration-unit'
  Write-Report $root (Get-ValidReport)
  $path = Join-Path $root 'structural-gate-fixture/08-migration-plan.md'
  Write-Utf8 $path ((Get-Content -Raw -Encoding utf8 -LiteralPath $path) -replace 'approval:UNIT-ADM-002', 'approval:UNIT-ADM-999')
  Assert-Rejected 'master selector cannot override canonical migration plan content' $root 'Structural gate migration-unit selector must match the external canonical unit and work-item trace exactly'

  $root = New-Case 'self-declared-tree-forgery'
  Write-Report $root ((Get-ValidReport) -replace 'lib/admin/lock_panel.dart \| LockPanel \| lib/admin/lock_panel.dart \| LockPanel', 'lib/admin/evil_panel.dart | EvilPanel | lib/admin/evil_panel.dart | EvilPanel')
  Assert-Rejected 'same-row planned equals actual cannot override external planned tree' $root 'Structural gate actual file tree must match the complete external approved planned path and symbol'

  $root = New-Case 'invented-provider-mechanism'
  Write-Report $root ((Get-ValidReport) -replace 'targetProvider', 'invented-provider')
  Assert-Rejected 'report cannot invent provider mechanism' $root 'Structural gate boundary must match external approved owner and mechanism: provider'

  $root = New-Case 'activation-bypasses-lifecycle'
  Write-Report $root ((Get-ValidReport) -replace 'subscription -> lifecycle', 'subscription')
  Assert-Rejected 'activation must prove lifecycle after subscription' $root 'Structural gate applicable production activation path must match external registration/production authority, prove subscription and lifecycle, and PASS'

  $root = New-Case 'activation-invents-entry-point'
  Write-Report $root ((Get-ValidReport) -replace 'lib/admin/admin_route.dart#AdminRoute \| lib/admin/admin_route.dart#AdminRoute @ policy=base-owned', 'lib/evil/route.dart#EvilRoute | lib/admin/admin_route.dart#AdminRoute @ policy=base-owned')
  Assert-Rejected 'activation entry point must come from approved design' $root 'Structural gate applicable production activation path must match external registration/production authority, prove subscription and lifecycle, and PASS'

  $root = New-Case 'unapproved-not-applicable-activation'
  $notApplicable = '| not-applicable-approved | not-applicable | not-applicable | not-applicable | not-applicable | not-applicable | NOT_APPLICABLE |'
  Write-Report $root ((Get-ValidReport) -replace '\| applicable \| not-applicable \| lib/admin/admin_route.dart#AdminRoute \| lib/admin/admin_route.dart#AdminRoute @ policy=base-owned \| route -> panel -> provider -> subscription -> lifecycle \| lifecycle-test-trace=DESIGN-401 @ source#test \| PASS \|', $notApplicable)
  Assert-Rejected 'activation non-applicability requires approved decision' $root 'Structural gate non-applicable activation requires an explicit external approved decision and exact sentinel fields'

  $root = New-Case 'doubled-table-boundary'
  Write-Report $root ((Get-ValidReport) -replace '(?m)^\| Master Spec Reference', '|| Master Spec Reference')
  Assert-Rejected 'doubled Markdown boundary cannot be filtered away' $root 'Structural gate malformed Markdown table framing: Master Scope Context'

  $root = New-Case 'extra-exemplar-row'
  $extra = '| invented concern | lib/evil.dart | Evil.run | evil#1 | read-complete |'
  Write-Report $root ((Get-ValidReport) -replace '(?m)^(\| test harness and production-boundary tests [^\r\n]*\|)[ \t]*\r?$', "`$1`r`n$extra")
  Assert-Rejected 'unknown extra exemplar row is rejected' $root 'Structural gate exemplar cardinality must exactly match the external approved discovery'

  $root = New-Case 'mixed-deviation-sentinel'
  $mixed = '| not-applicable | controller/provider/state pattern | not-applicable | EvilAggregate | not-applicable | not-applicable | not-applicable |'
  Write-Report $root ((Get-ValidReport) -replace '\| not-applicable \| not-applicable \| not-applicable \| not-applicable \| not-applicable \| not-applicable \| not-applicable \|', $mixed)
  Assert-Rejected 'mixed not-applicable deviation sentinel is rejected' $root 'Structural gate deviation sentinel must be one exact all-not-applicable row'

  $root = New-Case 'duplicate-planned-tree-row'
  $duplicate = '| lib/admin/lock_controller.dart | LockController | lib/admin/lock_controller.dart | LockController | yes | diff#duplicate |'
  Write-Report $root ((Get-ValidReport) -replace '(?m)^(\| lib/admin/lock_panel.dart \| LockPanel \| lib/admin/lock_panel.dart \| LockPanel \| yes \| diff#lock-panel \|)[ \t]*\r?$', $duplicate)
  Assert-Rejected 'duplicate mapping cannot omit an external planned row' $root 'Structural gate actual/planned mapping must be one-to-one with the external approved planned tree'

  $root = New-Case 'generic-trace-invents-unit'
  Write-Report $root (Get-ValidReport)
  $path = Join-Path $root 'templates/migration/implementation-report.md'
  Write-Utf8 $path ((Get-Content -Raw -LiteralPath $path) -replace '\| Work Item ID \| Activation Slice ID \| Seam \| File', '| Migration Unit ID | Activation Slice ID | Seam | File')
  Assert-Rejected 'generic changed-file trace cannot require invented unit' $root 'Structural gate implementation report changed-file evidence must be keyed by Work Item ID'

  $root = New-Case 'generic-report-retains-selected-unit'
  $report = (Get-ValidReport) -replace [regex]::Escape($canonicalSelectorReportRow), $canonicalTaskSelectorReportRow
  Write-Report $root $report
  Write-AuthorityArtifacts $root 'task'
  Assert-Rejected 'generic adapter report cannot retain unit-specific section' $root 'Structural gate generic adapter must omit Selected Migration Unit and all unit-specific IDs'

  $root = New-Case 'migration-unit-missing-selected-unit'
  Write-Report $root ((Get-ValidReport) -replace '(?s)## Selected Migration Unit.*?(?=## Conformance Matrix Reference)', '')
  Assert-Rejected 'migration-unit adapter requires selected unit evidence' $root 'Structural gate migration-unit adapter requires exact Selected Migration Unit evidence'

  $root = New-Case 'migration-unit-missing-changed-files'
  Write-Report $root ((Get-ValidReport) -replace '(?s)## Work Item Changed Files.*?(?=## Work Item Test Evidence)', '')
  Assert-Rejected 'migration-unit report requires changed-file trace' $root 'Structural gate report requires Work Item Changed Files evidence'

  $root = New-Case 'migration-unit-duplicate-changed-file'
  $duplicateChanged = '| WORK-ADMIN-LOCKS | ACT-001 | state-holder | lib/admin/lock_controller.dart | duplicate provider | REQ-101, DESIGN-401 |'
  Write-Report $root ((Get-ValidReport) -replace '(?m)^(\| WORK-ADMIN-LOCKS \| ACT-001 \| render \|)', "$duplicateChanged`n`$1")
  Assert-Rejected 'migration-unit duplicate changed-file trace is rejected' $root 'Structural gate changed-file evidence must uniquely bind Work Item ID, Activation Slice, file and Trace IDs'

  $root = New-Case 'migration-unit-mismatched-runtime-trace'
  Write-Report $root ((Get-ValidReport) -replace 'lock behavior \| test admin locks \| PASS \| SC-101, DESIGN-401', 'lock behavior | test admin locks | PASS | REQ-999')
  Assert-Rejected 'migration-unit runtime evidence must bind canonical traces' $root 'Structural gate test evidence Trace IDs must be a non-empty canonical subset'

  $root = New-Case 'migration-unit-forged-activation-slice'
  $report = Get-ValidReport
  $report = $report -replace 'source#render; implementation=lib/admin/lock_panel.dart', 'source#invented; implementation=lib/admin/lock_panel.dart'
  Write-Report $root $report
  Assert-Rejected 'migration-unit activation slice must bind external Task 6' $root 'Structural gate report Activation Slice Source Reference must preserve or canonically enrich external authority'

  $root = New-Case 'generic-missing-test-evidence'
  $report = (Get-ValidReport) -replace [regex]::Escape($canonicalSelectorReportRow), $canonicalTaskSelectorReportRow
  $report = $report -replace '(?s)## Selected Migration Unit.*?(?=## Conformance Matrix Reference)', ''
  $report = $report -replace '(?s)## Work Item Test Evidence.*?(?=## Activation Slice)', ''
  Write-Report $root $report
  Write-AuthorityArtifacts $root 'task'
  Assert-Rejected 'generic report requires runtime test evidence' $root 'Structural gate report requires Work Item Test Evidence'

  $root = New-Case 'generic-mismatched-work-item-evidence'
  $report = (Get-ValidReport) -replace [regex]::Escape($canonicalSelectorReportRow), $canonicalTaskSelectorReportRow
  $report = $report -replace '(?s)## Selected Migration Unit.*?(?=## Conformance Matrix Reference)', ''
  $report = $report -replace '\| WORK-ADMIN-LOCKS \| ACT-001 \| state-holder \| lib/admin/lock_controller.dart', '| WORK-ADMIN-OTHER | ACT-001 | state-holder | lib/admin/lock_controller.dart'
  Write-Report $root $report
  Write-AuthorityArtifacts $root 'task'
  Assert-Rejected 'generic changed-file evidence binds Work Item ID' $root 'Structural gate changed-file evidence must uniquely bind Work Item ID, Activation Slice, file and Trace IDs'

  $root = New-Case 'generic-duplicate-test-evidence'
  $report = (Get-ValidReport) -replace [regex]::Escape($canonicalSelectorReportRow), $canonicalTaskSelectorReportRow
  $report = $report -replace '(?s)## Selected Migration Unit.*?(?=## Conformance Matrix Reference)', ''
  $duplicateTest = '| WORK-ADMIN-LOCKS | ACT-001 | test | lock behavior | test admin locks duplicate | PASS | SC-101, DESIGN-401 |'
  $report = $report -replace '(?m)^(\| WORK-ADMIN-LOCKS \| ACT-001 \| test \| lock behavior \| test admin locks \| PASS \| SC-101, DESIGN-401 \|)[ \t]*\r?$', "`$1`r`n$duplicateTest"
  Write-Report $root $report
  Write-AuthorityArtifacts $root 'task'
  Assert-Rejected 'generic duplicate test evidence is rejected' $root 'Structural gate test evidence must uniquely bind Work Item ID, Activation Slice and Trace IDs'

  $root = New-Case 'empty-runtime-trace'
  Write-Report $root ((Get-ValidReport) -replace 'lock behavior \| test admin locks \| PASS \| SC-101, DESIGN-401', 'lock behavior | test admin locks | PASS | ')
  Assert-Rejected 'empty runtime trace is rejected' $root 'Structural gate report requires Work Item Test Evidence'

  $root = New-Case 'foreign-runtime-trace'
  Write-Report $root ((Get-ValidReport) -replace 'lock behavior \| test admin locks \| PASS \| SC-101, DESIGN-401', 'lock behavior | test admin locks | PASS | SC-101, FOREIGN-999')
  Assert-Rejected 'foreign runtime trace is rejected' $root 'Structural gate test evidence Trace IDs must be a non-empty canonical subset'

  $root = New-Case 'invalid-activation-id'
  Write-Report $root ((Get-ValidReport) -replace 'ACT-001', 'ACT-ADMIN-001')
  Assert-Rejected 'noncanonical activation ID is rejected' $root 'Structural gate report Activation Slice set must equal external authority in both directions'

  $root = New-Case 'omitted-external-activation-slice-group'
  Write-Report $root (Get-ValidReport)
  $path = Join-Path $root 'structural-gate-fixture/07-technical-design.md'
  Add-ActivationGroup $path 'ACT-002'
  Assert-Rejected 'report cannot omit an external applicable slice group' $root 'Structural gate report Activation Slice set must equal external authority in both directions'

  $root = New-Case 'omitted-external-na-activation-slice-group'
  Write-Report $root (Get-ValidReport)
  $path = Join-Path $root 'structural-gate-fixture/07-technical-design.md'
  Add-ActivationGroup $path 'ACT-002' $true
  Assert-Rejected 'report cannot omit an external not-applicable-approved slice group' $root 'Structural gate report Activation Slice set must equal external authority in both directions'

  $root = New-Case 'extra-report-activation-slice-group'
  Write-Report $root (Get-ValidReport)
  $path = Join-Path $root 'structural-gate-fixture/10-implementation-report.md'
  Add-ActivationGroup $path 'ACT-002'
  Assert-Rejected 'report cannot invent an extra slice group' $root 'Structural gate report Activation Slice set must equal external authority in both directions'

  $root = New-Case 'missing-canonical-activation-seam'
  Write-Report $root (Get-ValidReport)
  $path = Join-Path $root 'structural-gate-fixture/07-technical-design.md'
  Write-Utf8 $path ((Get-Content -Raw -Encoding utf8 -LiteralPath $path) -replace '(?m)^\| ACT-001 \| applicable \| requested-key \|.*\r?\n', '')
  Assert-Rejected 'all nine activation seams are required' $root 'Structural gate report Activation Slice set must equal external authority in both directions'

  $root = New-Case 'wrong-canonical-activation-order'
  $report = Get-ValidReport
  $report = $report -replace '\| upstream-response \|', '| seam-swap |'
  $report = $report -replace '\| requested-key \|', '| upstream-response |'
  $report = $report -replace '\| seam-swap \|', '| requested-key |'
  Write-Report $root $report
  Assert-Rejected 'all nine activation seams keep canonical order' $root 'Structural gate report Activation Slice violates canonical activation-slice contract'

  $root = New-Case 'illegal-activation-disposition'
  Write-Report $root (Get-ValidReport)
  $path = Join-Path $root 'structural-gate-fixture/07-technical-design.md'
  Write-Utf8 $path ((Get-Content -Raw -Encoding utf8 -LiteralPath $path) -replace '\| applicable \| upstream-response \| service request \| raw config \| source#upstream \| REQ-101, SC-101, DESIGN-401 \| implement \| verified \|', '| applicable | upstream-response | service request | raw config | source#upstream | REQ-101, SC-101, DESIGN-401 | deferred-approved | verified |')
  Assert-Rejected 'illegal activation combination is rejected' $root 'Structural gate external Activation Slice violates canonical activation-slice contract'

  $root = New-Case 'canonical-not-applicable-approved-slice'
  $report = Get-ValidReport
  $report = $report -replace '\| ACT-001 \| applicable \|', '| ACT-001 | not-applicable-approved |'
  $report = $report -replace '\| implement \| verified \| not-applicable \| not-applicable \|', '| not-applicable-approved | verified | approval:TECH-LEAD-ACT-001 | not-applicable |'
  $report = $report -replace '\| applicable \| not-applicable \| lib/admin/admin_route.dart#AdminRoute \| lib/admin/admin_route.dart#AdminRoute @ policy=base-owned \| route -> panel -> provider -> subscription -> lifecycle \| lifecycle-test-trace=DESIGN-401 @ source#test \| PASS \|', '| not-applicable-approved | approval:TECH-LEAD-ACT-001 | not-applicable | not-applicable | not-applicable | not-applicable | NOT_APPLICABLE |'
  Write-Report $root $report
  $path = Join-Path $root 'structural-gate-fixture/07-technical-design.md'
  $design = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $design = $design -replace '\| ACT-001 \| applicable \|', '| ACT-001 | not-applicable-approved |'
  $design = $design -replace '\| implement \| verified \| not-applicable \| not-applicable \|', '| not-applicable-approved | verified | approval:TECH-LEAD-ACT-001 | not-applicable |'
  Write-Utf8 $path $design
  Write-DesignApproval $root
  Assert-Accepted 'canonical not-applicable-approved nine-seam slice' $root

  $root = New-Case 'compatibility-dual-path-complete'
  Write-Report $root (Get-ValidReport)
  Set-CompatibilityDualPath $root
  Assert-Accepted 'compatibility dual path with full router authority' $root

  $root = New-Case 'compatibility-missing-reason'
  Write-Report $root (Get-ValidReport)
  Set-CompatibilityDualPath $root $false $true $true
  Assert-Rejected 'compatibility dual path requires reason' $root 'Structural gate external Activation Slice violates canonical activation-slice contract'

  $root = New-Case 'compatibility-missing-owner'
  Write-Report $root (Get-ValidReport)
  Set-CompatibilityDualPath $root $true $false $true
  Assert-Rejected 'compatibility dual path requires router owner' $root 'Structural gate external Activation Slice violates canonical activation-slice contract'

  $root = New-Case 'compatibility-missing-approval'
  Write-Report $root (Get-ValidReport)
  Set-CompatibilityDualPath $root $true $true $true 'not-applicable'
  Assert-Rejected 'compatibility dual path requires approval decision' $root 'Structural gate external Activation Slice violates canonical activation-slice contract'

  $root = New-Case 'compatibility-missing-parity'
  Write-Report $root (Get-ValidReport)
  Set-CompatibilityDualPath $root $true $true $false
  Assert-Rejected 'compatibility dual path requires parity trace' $root 'Structural gate external Activation Slice violates canonical activation-slice contract'

  $root = New-Case 'activation-trace-append-only-enrichment'
  $report = (Get-ValidReport) -replace 'REQ-101, SC-101, DESIGN-401', 'REQ-101, SC-101, DESIGN-401, EXTRA-501'
  Write-Report $root $report
  Add-ExtraWorkItemTraceAuthority $root
  Assert-Accepted 'Step 10 activation trace may append Work Item-authorized evidence' $root

  $root = New-Case 'activation-trace-dropped-predecessor'
  $report = Get-ValidReport
  $report = $report -replace '(\| ACT-001 \| applicable \| state-holder \|[^\r\n]+?\| )REQ-101, SC-101, DESIGN-401( \| implement \|)', '$1REQ-101, DESIGN-401$2'
  Write-Report $root $report
  Assert-Rejected 'Step 10 activation trace cannot drop predecessor evidence' $root 'Structural gate report Activation Slice Trace IDs must preserve predecessor traces with append-only enrichment'

  $root = New-Case 'activation-trace-foreign-enrichment'
  $report = Get-ValidReport
  $report = $report -replace '(\| ACT-001 \| applicable \| state-holder \|[^\r\n]+?\| )REQ-101, SC-101, DESIGN-401( \| implement \|)', '$1REQ-101, SC-101, DESIGN-401, FOREIGN-999$2'
  Write-Report $root $report
  Assert-Rejected 'Step 10 activation trace cannot append foreign evidence' $root 'Structural gate report Activation Slice violates canonical activation-slice contract'

  $root = New-Case 'canonical-task6-draft-complete-with-external-approval'
  Write-Report $root (Get-ValidReport)
  $path = Join-Path $root 'structural-gate-fixture/07-technical-design.md'
  Write-Utf8 $path ((Get-Content -Raw -Encoding utf8 -LiteralPath $path) -replace 'status: approved', 'status: draft')
  Write-DesignApproval $root
  Assert-Accepted 'canonical Task 6 remains draft complete while external human approval authorizes exact digest' $root

  $root = New-Case 'mutated-task6-approved-complete-schema'
  Write-Report $root (Get-ValidReport)
  $path = Join-Path $root 'structural-gate-fixture/07-technical-design.md'
  Write-Utf8 $path ((Get-Content -Raw -Encoding utf8 -LiteralPath $path) -replace 'status: draft', 'status: approved')
  Write-DesignApproval $root
  Assert-Rejected 'Task 6 technical design schema cannot be mutated to approved' $root 'Structural gate external technical design must remain canonical Task 6 draft/complete'

  $root = New-Case 'missing-external-approval-source'
  Write-Report $root (Get-ValidReport)
  $path = Join-Path $root 'structural-gate-fixture/07-technical-design.approval.md'
  Write-Utf8 $path ((Get-Content -Raw -Encoding utf8 -LiteralPath $path) -replace '(?m)^approval_source: human\r?\n', '')
  Assert-Rejected 'external technical-design approval requires human approval_source' $root 'Structural gate external technical-design approval lifecycle must be approved/complete/human'

  foreach ($invalidSource in @('auto', 'auto-waive')) {
    $root = New-Case "invalid-external-approval-source-$invalidSource"
    Write-Report $root (Get-ValidReport)
    $path = Join-Path $root 'structural-gate-fixture/07-technical-design.approval.md'
    Write-Utf8 $path ((Get-Content -Raw -Encoding utf8 -LiteralPath $path) -replace 'approval_source: human', "approval_source: $invalidSource")
    Assert-Rejected "external approval_source $invalidSource cannot approve design" $root 'Structural gate external technical-design approval lifecycle must be approved/complete/human'
  }

  $root = New-Case 'extra-external-approval-frontmatter'
  Write-Report $root (Get-ValidReport)
  $path = Join-Path $root 'structural-gate-fixture/07-technical-design.approval.md'
  Write-Utf8 $path ((Get-Content -Raw -Encoding utf8 -LiteralPath $path) -replace 'approval_source: human', "approval_source: human`nextra_authority: forbidden")
  Assert-Rejected 'external approval rejects extra frontmatter authority' $root 'Structural gate external technical-design approval lifecycle must be approved/complete/human'

  $root = New-Case 'malformed-external-approval-frontmatter'
  Write-Report $root (Get-ValidReport)
  $path = Join-Path $root 'structural-gate-fixture/07-technical-design.approval.md'
  Write-Utf8 $path ((Get-Content -Raw -Encoding utf8 -LiteralPath $path) -replace 'approval_source: human', 'approval_source human')
  Assert-Rejected 'external approval rejects malformed frontmatter' $root 'Structural gate external technical-design approval lifecycle must be approved/complete/human'

  $root = New-Case 'missing-external-design-approval'
  Write-Report $root (Get-ValidReport)
  Remove-Item -LiteralPath (Join-Path $root 'structural-gate-fixture/07-technical-design.approval.md') -Force
  Assert-Rejected 'edit path requires the supplied external design approval file' $root 'Structural gate technical design approval authority is unreadable'

  $root = New-Case 'unapproved-external-design-approval'
  Write-Report $root (Get-ValidReport)
  Write-DesignApproval $root 'pending'
  Assert-Rejected 'pending external design decision cannot authorize edit' $root 'Structural gate matrix approval must bind one external approved exact design revision'

  $root = New-Case 'self-declared-external-design-approval'
  Write-Report $root ((Get-ValidReport) -replace 'approval:TECH-LEAD-DESIGN-401 \| approved \|', 'approval:TECH-LEAD-WORK-ADMIN-LOCKS | approved |')
  Write-DesignApproval $root 'approved' 'approval:TECH-LEAD-WORK-ADMIN-LOCKS'
  Assert-Rejected 'external approval cannot reuse the earlier Work Item approval' $root 'Structural gate matrix approval must bind one external approved exact design revision'

  $root = New-Case 'changed-design-after-approval'
  Write-Report $root (Get-ValidReport)
  $path = Join-Path $root 'structural-gate-fixture/07-technical-design.md'
  Write-Utf8 $path ((Get-Content -Raw -Encoding utf8 -LiteralPath $path) + "`n## Approval-stale note`nDesign content changed after approval.`n")
  Assert-Rejected 'design mutation after approval invalidates content digest' $root 'Structural gate technical design content digest must match the external approval artifact'

  $root = New-Case 'forged-design-approval-digest'
  Write-Report $root (Get-ValidReport)
  $path = Join-Path $root 'structural-gate-fixture/07-technical-design.approval.md'
  Write-Utf8 $path ((Get-Content -Raw -Encoding utf8 -LiteralPath $path) -replace 'sha256:[0-9a-f]{64}', ('sha256:' + ('0' * 64)))
  Assert-Rejected 'forged external design digest cannot authorize edit' $root 'Structural gate technical design content digest must match the external approval artifact'

  $root = New-Case 'self-approved-matrix'
  Write-Report $root ((Get-ValidReport) -replace 'approval:TECH-LEAD-DESIGN-401 \| approved \|', 'approval:TECH-LEAD-WORK-ADMIN-LOCKS | approved |')
  Assert-Rejected 'earlier work-item approval cannot self-approve the later matrix' $root 'Structural gate matrix approval must bind one external approved exact design revision'

  $root = New-Case 'unbound-design-matrix-approval'
  Write-Report $root ((Get-ValidReport) -replace 'approval:TECH-LEAD-DESIGN-401 \| approved \|', 'approval:TECH-LEAD-DESIGN-999 | approved |')
  Assert-Rejected 'matrix approval must bind the exact selector design identity' $root 'Structural gate matrix approval must bind one external approved exact design revision'

  $root = New-Case 'approved-complete-step10'
  $report = (Get-ValidReport) -replace 'status: draft', 'status: approved'
  $report = $report -replace 'result: complete', "result: complete`napproval_source: human"
  Write-Report $root $report
  Assert-Accepted 'approved complete Step 10 lifecycle remains canonical' $root

  $root = New-Case 'forged-registration-evidence'
  Write-Report $root ((Get-ValidReport) -replace 'lib/admin/admin_route.dart#AdminRoute @ policy=base-owned \| route ->', 'lib/app/other_router.dart#routes @ policy=base-owned | route ->')
  Assert-Rejected 'report registration must match external activation authority' $root 'Structural gate applicable production activation path must match external registration/production authority, prove subscription and lifecycle, and PASS'

  $root = New-Case 'forged-production-evidence'
  Write-Report $root ((Get-ValidReport) -replace 'lifecycle-test-trace=DESIGN-401 @ source#test \| PASS', 'lifecycle-test-trace=DESIGN-401 @ invented-test#admin-locks | PASS')
  Assert-Rejected 'report production evidence must match external activation authority' $root 'Structural gate applicable production activation path must match external registration/production authority, prove subscription and lifecycle, and PASS'

  foreach ($lineEnding in @("`n", "`r`n")) {
    $endingName = if ($lineEnding -eq "`n") { 'lf' } else { 'crlf' }

    $root = New-Case "report-body-frontmatter-spoof-$endingName"
    $report = (Get-ValidReport) + "$lineEnding## Notes$lineEnding`status: approved$lineEnding"
    if ($lineEnding -eq "`r`n") { $report = $report -replace "(?<!`r)`n", "`r`n" }
    Write-Report $root $report
    Assert-Rejected "report body cannot spoof frontmatter under $endingName" $root 'Structural gate implementation report frontmatter is invalid or spoofed'

    $root = New-Case "master-spec-body-frontmatter-spoof-$endingName"
    Write-Report $root (Get-ValidReport)
    $path = Join-Path $root 'structural-gate-fixture/master-spec.md'
    $text = (Get-Content -Raw -Encoding utf8 -LiteralPath $path) + "$lineEnding## Notes$lineEnding`status: draft$lineEnding"
    if ($lineEnding -eq "`r`n") { $text = $text -replace "(?<!`r)`n", "`r`n" }
    Write-Utf8 $path $text
    Assert-Rejected "master spec body cannot spoof frontmatter under $endingName" $root 'Structural gate master spec frontmatter is invalid or spoofed'

    $root = New-Case "master-plan-body-frontmatter-spoof-$endingName"
    Write-Report $root (Get-ValidReport)
    $path = Join-Path $root 'structural-gate-fixture/master-plan.md'
    $text = (Get-Content -Raw -Encoding utf8 -LiteralPath $path) + "$lineEnding## Notes$lineEnding`revision: 999$lineEnding"
    if ($lineEnding -eq "`r`n") { $text = $text -replace "(?<!`r)`n", "`r`n" }
    Write-Utf8 $path $text
    Assert-Rejected "master plan body cannot spoof frontmatter under $endingName" $root 'Structural gate master plan frontmatter is invalid or spoofed'

    $root = New-Case "canonical-plan-body-frontmatter-spoof-$endingName"
    Write-Report $root (Get-ValidReport)
    $path = Join-Path $root 'structural-gate-fixture/08-migration-plan.md'
    $text = (Get-Content -Raw -Encoding utf8 -LiteralPath $path) + "$lineEnding## Notes$lineEnding`status: draft$lineEnding"
    if ($lineEnding -eq "`r`n") { $text = $text -replace "(?<!`r)`n", "`r`n" }
    Write-Utf8 $path $text
    Assert-Rejected "canonical plan body cannot spoof frontmatter under $endingName" $root 'Structural gate canonical migration plan frontmatter is invalid or spoofed'
  }

  $root = New-Case 'report-duplicate-frontmatter-key'
  Write-Report $root ((Get-ValidReport) -replace 'status: draft', "status: draft`nstatus: approved")
  Assert-Rejected 'duplicate report frontmatter key is rejected' $root 'Structural gate implementation report frontmatter is invalid or spoofed'

  $root = New-Case 'report-unclosed-frontmatter'
  Write-Report $root ((Get-ValidReport) -replace '(?m)^---\r?\n\r?\n## Master Scope Context', '## Master Scope Context')
  Assert-Rejected 'unclosed report frontmatter is rejected' $root 'Structural gate implementation report frontmatter is invalid or spoofed'

  $root = New-Case 'report-absent-frontmatter'
  Write-Report $root ((Get-ValidReport) -replace '\A---\r?\n', '')
  Assert-Rejected 'absent report frontmatter is rejected' $root 'Structural gate implementation report frontmatter is invalid or spoofed'

  foreach ($authorityCase in @(
    @{ Name = 'master-spec'; File = 'master-spec.md'; Duplicate = 'status: approved'; DuplicateValue = "status: approved`nstatus: draft"; Heading = 'master spec'; Expected = 'Structural gate master spec frontmatter is invalid or spoofed' },
    @{ Name = 'master-plan'; File = 'master-plan.md'; Duplicate = 'revision: 4'; DuplicateValue = "revision: 4`nrevision: 999"; Heading = 'Work Items'; Expected = 'Structural gate master plan frontmatter is invalid or spoofed' },
    @{ Name = 'canonical-plan'; File = '08-migration-plan.md'; Duplicate = 'revision: 4'; DuplicateValue = "revision: 4`nrevision: 999"; Heading = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('Q8OhYyDEkcahbiB24buLIG1pZ3JhdGlvbiB0aGVvIHRo4bupIHThu7E=')); Expected = 'Structural gate canonical migration plan frontmatter is invalid or spoofed' }
  )) {
    $root = New-Case "$($authorityCase.Name)-duplicate-frontmatter-key"
    Write-Report $root (Get-ValidReport)
    $path = Join-Path $root "structural-gate-fixture/$($authorityCase.File)"
    Write-Utf8 $path ((Get-Content -Raw -Encoding utf8 -LiteralPath $path).Replace($authorityCase.Duplicate, $authorityCase.DuplicateValue))
    Assert-Rejected "$($authorityCase.Name) duplicate key is rejected" $root $authorityCase.Expected

    $root = New-Case "$($authorityCase.Name)-unclosed-frontmatter"
    Write-Report $root (Get-ValidReport)
    $path = Join-Path $root "structural-gate-fixture/$($authorityCase.File)"
    $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
    $frontMatterBlock = [regex]::Match($text, '\A---\r?\n(?s:.*?)\r?\n(?<closing>---)(?:\r?\n|\z)')
    $text = $text.Remove($frontMatterBlock.Groups['closing'].Index, $frontMatterBlock.Groups['closing'].Length)
    Write-Utf8 $path $text
    Assert-Rejected "$($authorityCase.Name) unclosed block is rejected" $root $authorityCase.Expected

    $root = New-Case "$($authorityCase.Name)-absent-frontmatter"
    Write-Report $root (Get-ValidReport)
    $path = Join-Path $root "structural-gate-fixture/$($authorityCase.File)"
    Write-Utf8 $path ((Get-Content -Raw -Encoding utf8 -LiteralPath $path) -replace '\A---\r?\n', '')
    Assert-Rejected "$($authorityCase.Name) absent block is rejected" $root $authorityCase.Expected
  }

  $root = New-Case 'draft-blocked-stops-before-edit'
  $report = Get-ValidReport
  $report = $report -replace 'result: complete', 'result: blocked'
  $report = $report -replace '(?s)## Work Item Changed Files.*?(?=## Activation Slice)', ''
  Write-Report $root $report
  Assert-Rejected 'draft blocked report may omit implementation evidence but stops before edit' $root 'Structural gate draft/blocked state stops before edit'

  $root = New-Case 'invented-task6-frontmatter'
  Write-Report $root (Get-ValidReport)
  $path = Join-Path $root 'structural-gate-fixture/07-technical-design.md'
  Write-Utf8 $path ((Get-Content -Raw -Encoding utf8 -LiteralPath $path) -replace 'status: draft', "status: draft`nrevision: 6")
  Assert-Rejected 'technical design rejects invented authority frontmatter' $root 'Structural gate technical design frontmatter must contain only the canonical Task 6 fields'

  $root = New-Case 'forged-task6-work-item-trace'
  Write-Report $root (Get-ValidReport)
  $path = Join-Path $root 'structural-gate-fixture/07-technical-design.md'
  Write-Utf8 $path ((Get-Content -Raw -Encoding utf8 -LiteralPath $path) -replace '\| WORK-ADMIN-LOCKS \| master-plan.md#PLAN-ADMIN-001 \| 4 \| REQ-101, SC-101 \| not-applicable \|', '| WORK-ADMIN-LOCKS | master-plan.md#PLAN-ADMIN-001 | 4 | REQ-101 | not-applicable |')
  Assert-Rejected 'well-formed Task 6 trace cannot narrow approved acceptance' $root 'Structural gate report must bind through exact Task 6 approved-plan and work-item trace tables'

  $root = New-Case 'canonical-template-produced-migration-unit-report'
  Write-Report $root (Get-ValidReport)
  Assert-Accepted 'canonical template-produced migration-unit report' $root

  foreach ($semanticDecoy in @(
    [pscustomobject]@{ Name = 'fenced'; Text = "~~~markdown`n## Work Item Changed Files`n| decoy |`n|---|`n| ignored |`n~~~" },
    [pscustomobject]@{ Name = 'commented'; Text = "<!--`n## Work Item Changed Files`n| decoy |`n|---|`n| ignored |`n-->" },
    [pscustomobject]@{ Name = 'indented'; Text = "    ## Work Item Changed Files`n    | decoy |`n    |---|`n    | ignored |" }
  )) {
    $root = New-Case "semantic-markdown-$($semanticDecoy.Name)"
    Write-Report $root ((Get-ValidReport) + "`n$($semanticDecoy.Text)`n")
    Assert-Accepted "$($semanticDecoy.Name) Markdown examples do not inflate structural authority" $root
  }

  foreach ($semanticLineEnding in @(
    [pscustomobject]@{ Name = 'LF'; NewLine = "`n" },
    [pscustomobject]@{ Name = 'CRLF'; NewLine = "`r`n" }
  )) {
    foreach ($selectedUnitDecoy in @(
      [pscustomobject]@{ Name = 'fenced'; Text = "~~~markdown`n## Selected Migration Unit`n| Migration Unit ID |`n|---|`n| UNIT-DECOY-001 |`n~~~" },
      [pscustomobject]@{ Name = 'commented'; Text = "<!--`n## Selected Migration Unit`n| Migration Unit ID |`n|---|`n| UNIT-DECOY-001 |`n-->" },
      [pscustomobject]@{ Name = 'indented'; Text = "    ## Selected Migration Unit`n    | Migration Unit ID |`n    |---|`n    | UNIT-DECOY-001 |" }
    )) {
      $renderedDecoy = [regex]::Replace($selectedUnitDecoy.Text, '\r\n|\n|\r', $semanticLineEnding.NewLine)

      $root = New-Case "selected-unit-semantic-$($selectedUnitDecoy.Name)-$($semanticLineEnding.Name)"
      $migrationReport = [regex]::Replace((Get-ValidReport), '\r\n|\n|\r', $semanticLineEnding.NewLine)
      Write-Report $root ($migrationReport + $semanticLineEnding.NewLine + $renderedDecoy + $semanticLineEnding.NewLine)
      Assert-Accepted "$($selectedUnitDecoy.Name) Selected Migration Unit decoy does not inflate migration-unit cardinality ($($semanticLineEnding.Name))" $root

      $root = New-Case "generic-unit-semantic-$($selectedUnitDecoy.Name)-$($semanticLineEnding.Name)"
      $genericReport = (Get-ValidReport) -replace [regex]::Escape($canonicalSelectorReportRow), $canonicalTaskSelectorReportRow
      $genericReport = $genericReport -replace '(?s)## Selected Migration Unit.*?(?=## Conformance Matrix Reference)', ''
      $genericReport = [regex]::Replace($genericReport, '\r\n|\n|\r', $semanticLineEnding.NewLine)
      Write-Report $root ($genericReport + $semanticLineEnding.NewLine + $renderedDecoy + $semanticLineEnding.NewLine)
      Write-AuthorityArtifacts $root 'task'
      Assert-Accepted "$($selectedUnitDecoy.Name) Selected Migration Unit and UNIT-row decoys stay inert for a generic adapter ($($semanticLineEnding.Name))" $root
    }

    $root = New-Case "generic-visible-unit-row-$($semanticLineEnding.Name)"
    $genericReport = (Get-ValidReport) -replace [regex]::Escape($canonicalSelectorReportRow), $canonicalTaskSelectorReportRow
    $genericReport = $genericReport -replace '(?s)## Selected Migration Unit.*?(?=## Conformance Matrix Reference)', ''
    $genericReport = [regex]::Replace($genericReport, '\r\n|\n|\r', $semanticLineEnding.NewLine)
    $visibleUnitRow = [regex]::Replace("## Notes`n`n| Kind | ID |`n|---|---|`n| leaked | UNIT-ROGUE-001 |", '\r\n|\n|\r', $semanticLineEnding.NewLine)
    Write-Report $root ($genericReport + $semanticLineEnding.NewLine + $visibleUnitRow + $semanticLineEnding.NewLine)
    Write-AuthorityArtifacts $root 'task'
    if ($semanticLineEnding.Name -ceq 'CRLF') {
      $writtenReport = [IO.File]::ReadAllText((Join-Path $root 'structural-gate-fixture/10-implementation-report.md'))
      if ($writtenReport.IndexOf("| leaked | UNIT-ROGUE-001 |`r`n", [StringComparison]::Ordinal) -lt 0) {
        throw 'CRLF visible UNIT-row fixture was not preserved on disk'
      }
    }
    Assert-Rejected "visible UNIT row remains forbidden for a generic adapter ($($semanticLineEnding.Name))" $root 'Structural gate generic adapter must omit Selected Migration Unit and all unit-specific IDs'
  }

  $root = New-Case 'canonical-crlf-authority-chain'
  Write-Report $root (Get-ValidReport)
  foreach ($relativePath in @('10-implementation-report.md', 'master-spec.md', 'master-plan.md', '08-migration-plan.md', '02-discovery.md', '07-technical-design.md', '07-technical-design.approval.md')) {
    $path = Join-Path $root "structural-gate-fixture/$relativePath"
    $text = ((Get-Content -Raw -Encoding utf8 -LiteralPath $path) -replace "`r`n", "`n") -replace "`r", "`n"
    Write-Utf8 $path ($text -replace "`n", "`r`n")
  }
  Assert-Accepted 'canonical external approval and authority chain accept CRLF' $root

  $root = New-Case 'canonical-template-produced-migration-unit-report-for-task6'
  Write-Report $root (Get-ValidReport)
  [void](New-Item -ItemType Directory -Path (Join-Path $root 'structural-gate-fixture/contracts') -Force)
  Copy-Item -LiteralPath (Join-Path $root 'contracts/target-structure-conformance.md') -Destination (Join-Path $root 'structural-gate-fixture/contracts/target-structure-conformance.md')
  Copy-Item -LiteralPath (Join-Path $root 'contracts/migration-scope-orchestration.md') -Destination (Join-Path $root 'structural-gate-fixture/contracts/migration-scope-orchestration.md')
  Copy-Item -LiteralPath (Join-Path $root 'contracts/activation-slice.md') -Destination (Join-Path $root 'structural-gate-fixture/contracts/activation-slice.md')
  Write-ApprovedProjectProfile (Join-Path $root 'structural-gate-fixture')
  $script:errors.Clear()
  Test-TargetConformance (Join-Path $root 'structural-gate-fixture') (Get-Content -Raw -Encoding utf8 (Join-Path $root 'contracts/target-structure-conformance.md'))
  if ($script:errors.Count -ne 0) { throw "canonical Task 6 fixture expected PASS, got: $($script:errors -join ' || ')" }
  $script:passed++

  "PASS: structural gate ($script:passed scenarios)"
}
finally {
  if (Test-Path -LiteralPath $caseRoot) {
    Remove-Item -LiteralPath $caseRoot -Recurse -Force
  }
}

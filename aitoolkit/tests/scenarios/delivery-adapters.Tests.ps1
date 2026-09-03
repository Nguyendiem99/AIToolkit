$ErrorActionPreference = 'Stop'

$toolkitRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$validatorPath = Join-Path $toolkitRoot 'tests/validation/delivery-adapters.validation.ps1'
$utf8NoBom = New-Object Text.UTF8Encoding($false)
$caseRoot = Join-Path ([IO.Path]::GetTempPath()) ("aitk-delivery-adapters-" + [guid]::NewGuid().ToString('N'))
$script:errors = [Collections.Generic.List[string]]::new()
$script:passed = 0

function Require-Token([string]$Text, [string]$Token, [string]$Context) {
  if ($Text -notmatch [regex]::Escape($Token)) { $script:errors.Add("$Context missing: $Token") }
}

function Write-Utf8([string]$Path, [string]$Text) {
  $parent = Split-Path $Path -Parent
  if (-not (Test-Path -LiteralPath $parent)) {
    [void](New-Item -ItemType Directory -Force $parent)
  }
  [IO.File]::WriteAllText($Path, $Text, $utf8NoBom)
}

function New-Case([string]$Name) {
  $root = Join-Path $caseRoot $Name
  [void](New-Item -ItemType Directory -Force (Join-Path $root 'contracts'))
  [IO.File]::Copy(
    (Join-Path $toolkitRoot 'contracts/migration-scope-orchestration.md'),
    (Join-Path $root 'contracts/migration-scope-orchestration.md'),
    $true
  )
  foreach ($relativePath in @(
    'skills/migration/build-inventory/SKILL.md',
    'skills/migration/feature-mapping/SKILL.md',
    'skills/migration/analyze-gaps-conflicts/SKILL.md',
    'skills/migration/plan-waves/SKILL.md',
    'templates/migration/migration-plan.md'
  )) {
    $destination = Join-Path $root $relativePath
    [void](New-Item -ItemType Directory -Force (Split-Path $destination -Parent))
    [IO.File]::Copy((Join-Path $toolkitRoot $relativePath), $destination, $true)
  }
  [void](New-Item -ItemType Directory -Force (Join-Path $root 'delivery-adapter-fixture'))
  return $root
}

function Write-MasterPlan(
  [string]$Root,
  [string]$Kind,
  [string]$ExternalId,
  [string]$Authority,
  [string]$AuthorityRevision,
  [string]$ParentSelector,
  [string]$WorkItemId = 'WORK-ADMIN-LOCKS',
  [string]$Acceptance = 'REQ-101: lock mode persists',
  [string]$TraceIds = 'REQ-101, ITEM-201, MAP-301, DESIGN-401',
  [string]$Mode = 'incremental/preserve-existing',
  [string]$DesignRevision = 'DESIGN-401@4',
  [string]$ParentWorkItemId = 'not-applicable',
  [string]$DecisionReference = 'not-applicable',
  [string]$Dependencies = 'none',
  [string]$Status = 'approved',
  [string[]]$WorkItemRows = @(),
  [string[]]$DecompositionRows = @(),
  [string[]]$AdditionalSelectionRows = @(),
  [bool]$OmitPrimarySelection = $false
) {
  $approval = if ($Kind -eq 'none') { 'not-applicable' } else { "approval:$ExternalId" }
  $adapterCell = if ($Kind -eq 'none') { 'none' } else { "$($Kind):$ExternalId" }
  if ($WorkItemRows.Count -eq 0) {
    $WorkItemRows = @("| $WorkItemId | Lock behavior | yes | $Dependencies | 1 | $Acceptance | $TraceIds | $adapterCell | ready | none | none | approval:$WorkItemId |")
  }
  $primarySelectionRow = if ($OmitPrimarySelection) {
    ''
  }
  else {
    "| $WorkItemId | $Kind | $ExternalId | $Authority | $AuthorityRevision | $approval | $ParentSelector | $Acceptance | $TraceIds | $Mode | $DesignRevision | $ParentWorkItemId | $DecisionReference |"
  }
  $existingSelectionIds = @($AdditionalSelectionRows | ForEach-Object {
    $cells = @($_.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
    if ($cells.Count -gt 0) { $cells[0] }
  })
  foreach ($workItemRow in $WorkItemRows) {
    $cells = @($workItemRow.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
    if ($cells.Count -lt 8 -or $cells[0] -ceq $WorkItemId -or $existingSelectionIds -ccontains $cells[0]) { continue }
    $rowAdapter = $cells[7]
    $rowKind = if ($rowAdapter -ceq 'none') { 'none' } else { $rowAdapter.Substring(0, $rowAdapter.IndexOf(':')) }
    $rowExternal = if ($rowKind -ceq 'none') { 'not-applicable' } else { $rowAdapter.Substring($rowAdapter.IndexOf(':') + 1) }
    $rowAuthority = if ($rowKind -ceq 'none') { 'not-applicable' } elseif ($rowKind -ceq 'migration-unit') { '08-migration-plan.md' } else { $Authority }
    $rowRevision = if ($rowKind -ceq 'none') { 'not-applicable' } else { $AuthorityRevision }
    $rowApproval = if ($rowKind -ceq 'none') { 'not-applicable' } else { "approval:$rowExternal" }
    $AdditionalSelectionRows += "| $($cells[0]) | $rowKind | $rowExternal | $rowAuthority | $rowRevision | $rowApproval | not-applicable | $($cells[5]) | $($cells[6]) | $Mode | $DesignRevision | not-applicable | not-applicable |"
  }
  $text = @"
---
artifact_type: migration-master-plan
master_plan_id: PLAN-ADMIN-001
revision: 7
status: $Status
---

# Master plan

## Work Items

| Work Item ID | Title | Required | Dependencies | Plan Order | Acceptance | Trace IDs | Delivery Adapter | Status | Latest Attempt | Terminal Evidence | Approval Reference |
|---|---|---|---|---|---|---|---|---|---|---|---|
$($WorkItemRows -join [Environment]::NewLine)

## Delivery Adapter Selection

| Work Item ID | Adapter Kind | External ID | Authority | Authority Revision | Approval Reference | Parent Selector | Acceptance | Trace IDs | Mode Constraint | Design Revision | Parent Work Item ID | Decomposition Decision Reference |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
$primarySelectionRow
$($AdditionalSelectionRows -join [Environment]::NewLine)

## Decomposition Records

| Parent Work Item ID | Child Work Item IDs | Decision Reference | Master Plan Revision | Approval Reference | Approval Status |
|---|---|---|---|---|---|
$($DecompositionRows -join [Environment]::NewLine)
"@
  Write-Utf8 (Join-Path $Root 'delivery-adapter-fixture/master-plan.md') $text
}

function Get-UnitRow(
  [string]$UnitId = 'UNIT-ADM-002',
  [string]$WorkItemId = 'WORK-ADMIN-LOCKS',
  [string]$Acceptance = 'REQ-101: lock mode persists',
  [string]$TraceIds = 'REQ-101, ITEM-201, MAP-301, DESIGN-401',
  [string]$Mode = 'incremental/preserve-existing',
  [string]$DesignRevision = 'DESIGN-401@4',
  [string]$ParentWorkItemId = 'not-applicable',
  [string]$DecisionReference = 'not-applicable',
  [string]$Dependencies = 'none'
) {
  return "| 1 | $UnitId | $WorkItemId | $ParentWorkItemId | master-plan.md | 7 | $DecisionReference | not-required | not-applicable | not-applicable | $Dependencies | $Acceptance | $Mode | $TraceIds | $DesignRevision | one-unit-one-change | approval:$UnitId | approved |"
}

function Get-ChildWorkItemRows {
  return @(
    '| WORK-ADMIN-LOCKS | Parent lock behavior | yes | none | 1 | REQ-101: lock mode persists | REQ-101, ITEM-201, MAP-301, DESIGN-401 | migration-unit:UNIT-ADM-002 | complete | ATTEMPT-002 | evidence:parent | approval:WORK-ADMIN-LOCKS |',
    '| WORK-ADMIN-SIMPLE-LOCKS | Simple lock behavior | yes | none | 2 | REQ-101: lock mode persists | REQ-101, ITEM-201, MAP-301, DESIGN-401 | migration-unit:UNIT-ADM-002A | ready | none | none | approval:WORK-ADMIN-SIMPLE-LOCKS |'
  )
}

function Get-ApprovedDecompositionRows {
  return @('| WORK-ADMIN-LOCKS | WORK-ADMIN-SIMPLE-LOCKS | DEC-ARCH-014 | 7 | approval:DEC-ARCH-014 | approved |')
}

function Get-GenericChildWorkItemRows {
  return @(
    '| WORK-ADMIN-LOCKS | Parent lock behavior | yes | none | 1 | REQ-101: lock mode persists | REQ-101, ITEM-201, MAP-301, DESIGN-401 | task:TASK-41 | complete | ATTEMPT-041 | evidence:parent | approval:WORK-ADMIN-LOCKS |',
    '| WORK-ADMIN-SIMPLE-LOCKS | Simple lock behavior | yes | none | 2 | REQ-101: lock mode persists | REQ-101, ITEM-201, MAP-301, DESIGN-401 | task:TASK-42 | ready | none | none | approval:WORK-ADMIN-SIMPLE-LOCKS |'
  )
}

function Get-NoneChildWorkItemRows {
  return @(
    '| WORK-ADMIN-LOCKS | Parent lock behavior | yes | none | 1 | REQ-101: lock mode persists | REQ-101, ITEM-201, MAP-301, DESIGN-401 | none | complete | ATTEMPT-041 | evidence:parent | approval:WORK-ADMIN-LOCKS |',
    '| WORK-ADMIN-SIMPLE-LOCKS | Simple lock behavior | yes | none | 2 | REQ-101: lock mode persists | REQ-101, ITEM-201, MAP-301, DESIGN-401 | none | ready | none | none | approval:WORK-ADMIN-SIMPLE-LOCKS |'
  )
}

function Get-NoneChildUnderTaskParentWorkItemRows {
  return @(
    '| WORK-ADMIN-LOCKS | Parent lock behavior | yes | none | 1 | REQ-101: lock mode persists | REQ-101, ITEM-201, MAP-301, DESIGN-401 | task:TASK-41 | complete | ATTEMPT-041 | evidence:parent | approval:WORK-ADMIN-LOCKS |',
    '| WORK-ADMIN-SIMPLE-LOCKS | Simple lock behavior | yes | none | 2 | REQ-101: lock mode persists | REQ-101, ITEM-201, MAP-301, DESIGN-401 | none | ready | none | none | approval:WORK-ADMIN-SIMPLE-LOCKS |'
  )
}

function Get-TaskParentSelectionRow {
  return '| WORK-ADMIN-LOCKS | task | TASK-41 | jira:ADMIN | 12 | approval:TASK-41 | not-applicable | REQ-101: lock mode persists | REQ-101, ITEM-201, MAP-301, DESIGN-401 | incremental/preserve-existing | DESIGN-401@4 | not-applicable | not-applicable |'
}

function Write-MigrationPlan(
  [string]$Root,
  [string[]]$Rows,
  [string]$Status = 'approved',
  [string]$Result = 'complete'
) {
  $orderedUnitsHeading = [Text.Encoding]::UTF8.GetString(
    [Convert]::FromBase64String('Q8OhYyDEkcahbiB24buLIG1pZ3JhdGlvbiB0aGVvIHRo4bupIHThu7E=')
  )
  $orderedRows = [Collections.Generic.List[string]]::new()
  $traceRows = [Collections.Generic.List[string]]::new()
  foreach ($row in $Rows) {
    $cells = @($row.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
    $orderedRows.Add("| $($cells[0]) | $($cells[1]) | $($cells[7]) | $($cells[8]) | $($cells[9]) | $($cells[10]) | $($cells[11]) | $($cells[12]) | $($cells[13]) | $($cells[15]) | $($cells[16]) | $($cells[17]) |")
    $traceRows.Add("| $($cells[1]) | $($cells[2]) | $($cells[3]) | $($cells[4]) | $($cells[5]) | $($cells[6]) | $($cells[14]) |")
  }
  $text = @"
---
step_id: 08-plan-waves
status: $Status
result: $Result
revision: 3
produced_at: 2026-08-19
---

# Migration plan

## $orderedUnitsHeading

| Order | Migration Unit ID | Bootstrap Scope | Foundation Baseline ID | Foundation Approval Reference | Dependencies | Acceptance | Mode Constraint | Trace IDs | Delivery Change Boundary | Approval Reference | Approval Status |
|---|---|---|---|---|---|---|---|---|---|---|---|
$($orderedRows -join [Environment]::NewLine)

## Work Item Adapter Trace

| Migration Unit ID | Work Item ID | Parent Work Item ID | Master Plan Reference | Master Plan Revision | Decomposition Decision Reference | Design Revision |
|---|---|---|---|---|---|---|
$($traceRows -join [Environment]::NewLine)
"@
  Write-Utf8 (Join-Path $Root 'delivery-adapter-fixture/08-migration-plan.md') $text
}

function Write-FrontHalf(
  [string]$Root,
  [string]$WorkItemId = 'WORK-ADMIN-LOCKS',
  [string]$Acceptance = 'REQ-101: lock mode persists',
  [string]$TraceIds = 'REQ-101, ITEM-201, MAP-301, DESIGN-401',
  [string]$Mode = 'incremental/preserve-existing',
  [string]$DesignRevision = 'DESIGN-401@4',
  [string]$ParentWorkItemId = 'not-applicable',
  [string]$DecisionReference = 'not-applicable',
  [int[]]$Steps = @(4, 5, 6, 7),
  [int]$OverrideStep = 0,
  [string]$OverrideStatus = 'approved',
  [string]$OverrideResult = 'complete'
) {
  $names = @{
    4 = '04-inventory.md'; 5 = '05-mapping.md'; 6 = '06-gaps-conflicts.md'; 7 = '07-technical-design.md'; 8 = '08-work-item-plan.md'
  }
  $ids = @{
    4 = '04-build-inventory'; 5 = '05-feature-mapping'; 6 = '06-analyze-gaps-conflicts'; 7 = '07-technical-design'; 8 = '08-plan-waves'
  }
  foreach ($step in $Steps) {
    $stepStatus = if ($step -eq $OverrideStep) { $OverrideStatus } else { 'approved' }
    $stepResult = if ($step -eq $OverrideStep) { $OverrideResult } else { 'complete' }
    $traceRows = [Collections.Generic.List[string]]::new()
    $traceRows.Add("| $WorkItemId | $ParentWorkItemId | master-plan.md | 7 | $Acceptance | $TraceIds | $Mode | $DesignRevision | $DecisionReference |")
    if ($ParentWorkItemId -cne 'not-applicable') {
      $traceRows.Add("| $ParentWorkItemId | not-applicable | master-plan.md | 7 | $Acceptance | $TraceIds | $Mode | $DesignRevision | not-applicable |")
    }
    $text = @"
---
step_id: $($ids[$step])
status: $stepStatus
result: $stepResult
produced_at: 2026-08-19
---

## Work Item Trace

| Work Item ID | Parent Work Item ID | Master Plan Reference | Master Plan Revision | Acceptance | Trace IDs | Mode Constraint | Design Revision | Decomposition Decision Reference |
|---|---|---|---|---|---|---|---|---|
$($traceRows -join [Environment]::NewLine)
"@
    Write-Utf8 (Join-Path $Root "delivery-adapter-fixture/$($names[$step])") $text
  }
}

function Invoke-AdapterValidation([string]$Root) {
  $script:errors.Clear()
  $contract = Get-Content -Raw -Encoding utf8 (Join-Path $Root 'contracts/migration-scope-orchestration.md')
  Test-DeliveryAdapters $Root $contract
  return @($script:errors)
}

function Assert-Accepted([string]$Name, [string]$Root) {
  $actual = @(Invoke-AdapterValidation $Root)
  if ($actual.Count -ne 0) {
    throw "$Name expected PASS, got: $($actual -join ' || ')"
  }
  $script:passed++
}

function Assert-Rejected([string]$Name, [string]$Root, [string]$Expected) {
  $actual = @(Invoke-AdapterValidation $Root)
  if (-not ($actual -match [regex]::Escape($Expected))) {
    throw "$Name expected error containing '$Expected', got: $($actual -join ' || ')"
  }
  $script:passed++
}

try {
  . $validatorPath

  foreach ($adapter in @(
    @{ Name = 'none'; Kind = 'none'; External = 'not-applicable'; Authority = 'not-applicable'; Revision = 'not-applicable'; Parent = 'not-applicable' },
    @{ Name = 'task'; Kind = 'task'; External = 'TASK-42'; Authority = 'jira:ADMIN'; Revision = '12'; Parent = 'not-applicable' },
    @{ Name = 'story'; Kind = 'story'; External = 'STORY-9'; Authority = 'ado:ADMIN'; Revision = '6'; Parent = 'not-applicable' },
    @{ Name = 'package'; Kind = 'package'; External = 'pkg:admin-locks'; Authority = 'repo:packages'; Revision = '4'; Parent = 'not-applicable' },
    @{ Name = 'phase'; Kind = 'phase'; External = 'PHASE-2'; Authority = 'plan:ADMIN'; Revision = '8'; Parent = 'not-applicable' },
    @{ Name = 'milestone'; Kind = 'milestone'; External = 'MILESTONE-Q3'; Authority = 'roadmap:ADMIN'; Revision = '5'; Parent = 'not-applicable' }
  )) {
    $root = New-Case "valid-$($adapter.Name)"
    Write-MasterPlan $root $adapter.Kind $adapter.External $adapter.Authority $adapter.Revision $adapter.Parent
    Write-FrontHalf $root -Steps @(4, 5, 6, 7, 8)
    Assert-Accepted "valid $($adapter.Name) adapter" $root
  }

  $root = New-Case 'zero-selection-work-item'
  Write-MasterPlan $root 'none' 'not-applicable' 'not-applicable' 'not-applicable' 'not-applicable' -OmitPrimarySelection $true
  Write-FrontHalf $root -Steps @(4, 5, 6, 7, 8)
  Assert-Rejected 'canonical Work Item without adapter selection' $root 'Delivery adapter work item WORK-ADMIN-LOCKS must have exactly one Delivery Adapter Selection row; found 0'

  $root = New-Case 'generic-missing-step04'
  Write-MasterPlan $root 'task' 'TASK-42' 'jira:ADMIN' '12' 'not-applicable'
  Write-FrontHalf $root -Steps @(5, 6, 7, 8)
  Assert-Rejected 'generic task bypasses step 04' $root 'missing canonical work-item trace at step 04'

  $root = New-Case 'valid-generic-child'
  Write-MasterPlan $root 'task' 'TASK-42' 'jira:ADMIN' '12' 'TASK-41' `
    -WorkItemId 'WORK-ADMIN-SIMPLE-LOCKS' `
    -ParentWorkItemId 'WORK-ADMIN-LOCKS' `
    -DecisionReference 'DEC-ARCH-014' `
    -WorkItemRows @(Get-GenericChildWorkItemRows) `
    -DecompositionRows @(Get-ApprovedDecompositionRows)
  Write-FrontHalf $root `
    -WorkItemId 'WORK-ADMIN-SIMPLE-LOCKS' `
    -ParentWorkItemId 'WORK-ADMIN-LOCKS' `
    -DecisionReference 'DEC-ARCH-014' `
    -Steps @(4, 5, 6, 7, 8)
  Assert-Accepted 'valid generic child task adapter' $root

  $root = New-Case 'generic-child-parent-selector-mismatch'
  Write-MasterPlan $root 'task' 'TASK-42' 'jira:ADMIN' '12' 'TASK-404' `
    -WorkItemId 'WORK-ADMIN-SIMPLE-LOCKS' `
    -ParentWorkItemId 'WORK-ADMIN-LOCKS' `
    -DecisionReference 'DEC-ARCH-014' `
    -WorkItemRows @(Get-GenericChildWorkItemRows) `
    -DecompositionRows @(Get-ApprovedDecompositionRows)
  Write-FrontHalf $root `
    -WorkItemId 'WORK-ADMIN-SIMPLE-LOCKS' `
    -ParentWorkItemId 'WORK-ADMIN-LOCKS' `
    -DecisionReference 'DEC-ARCH-014' `
    -Steps @(4, 5, 6, 7, 8)
  Assert-Rejected 'generic child Parent Selector mismatch' $root 'Parent Selector TASK-404 does not match canonical parent selector TASK-41'

  $root = New-Case 'generic-child-decomposition-missing'
  Write-MasterPlan $root 'task' 'TASK-42' 'jira:ADMIN' '12' 'TASK-41' `
    -WorkItemId 'WORK-ADMIN-SIMPLE-LOCKS' `
    -ParentWorkItemId 'WORK-ADMIN-LOCKS' `
    -DecisionReference 'DEC-ARCH-014' `
    -WorkItemRows @(Get-GenericChildWorkItemRows)
  Write-FrontHalf $root `
    -WorkItemId 'WORK-ADMIN-SIMPLE-LOCKS' `
    -ParentWorkItemId 'WORK-ADMIN-LOCKS' `
    -DecisionReference 'DEC-ARCH-014' `
    -Steps @(4, 5, 6, 7, 8)
  Assert-Rejected 'generic child without decomposition record' $root 'must resolve exactly one approved decomposition record; found 0'

  $root = New-Case 'valid-none-child'
  Write-MasterPlan $root 'none' 'not-applicable' 'not-applicable' 'not-applicable' 'not-applicable' `
    -WorkItemId 'WORK-ADMIN-SIMPLE-LOCKS' `
    -ParentWorkItemId 'WORK-ADMIN-LOCKS' `
    -DecisionReference 'DEC-ARCH-014' `
    -WorkItemRows @(Get-NoneChildWorkItemRows) `
    -DecompositionRows @(Get-ApprovedDecompositionRows)
  Write-FrontHalf $root `
    -WorkItemId 'WORK-ADMIN-SIMPLE-LOCKS' `
    -ParentWorkItemId 'WORK-ADMIN-LOCKS' `
    -DecisionReference 'DEC-ARCH-014' `
    -Steps @(4, 5, 6, 7, 8)
  Assert-Accepted 'valid child with none adapter' $root

  $root = New-Case 'valid-none-child-under-task-parent'
  Write-MasterPlan $root 'none' 'not-applicable' 'not-applicable' 'not-applicable' 'not-applicable' `
    -WorkItemId 'WORK-ADMIN-SIMPLE-LOCKS' `
    -ParentWorkItemId 'WORK-ADMIN-LOCKS' `
    -DecisionReference 'DEC-ARCH-014' `
    -WorkItemRows @(Get-NoneChildUnderTaskParentWorkItemRows) `
    -DecompositionRows @(Get-ApprovedDecompositionRows) `
    -AdditionalSelectionRows @(Get-TaskParentSelectionRow)
  Write-FrontHalf $root `
    -WorkItemId 'WORK-ADMIN-SIMPLE-LOCKS' `
    -ParentWorkItemId 'WORK-ADMIN-LOCKS' `
    -DecisionReference 'DEC-ARCH-014' `
    -Steps @(4, 5, 6, 7, 8)
  Assert-Accepted 'none child under task parent keeps not-applicable selector' $root

  $root = New-Case 'none-child-wrong-decomposition-parent'
  Write-MasterPlan $root 'none' 'not-applicable' 'not-applicable' 'not-applicable' 'not-applicable' `
    -WorkItemId 'WORK-ADMIN-SIMPLE-LOCKS' `
    -ParentWorkItemId 'WORK-ADMIN-LOCKS' `
    -DecisionReference 'DEC-ARCH-014' `
    -WorkItemRows @(Get-NoneChildUnderTaskParentWorkItemRows) `
    -DecompositionRows @('| WORK-ADMIN-OTHER | WORK-ADMIN-SIMPLE-LOCKS | DEC-ARCH-014 | 7 | approval:DEC-ARCH-014 | approved |') `
    -AdditionalSelectionRows @(Get-TaskParentSelectionRow)
  Write-FrontHalf $root `
    -WorkItemId 'WORK-ADMIN-SIMPLE-LOCKS' `
    -ParentWorkItemId 'WORK-ADMIN-LOCKS' `
    -DecisionReference 'DEC-ARCH-014' `
    -Steps @(4, 5, 6, 7, 8)
  Assert-Rejected 'none child decomposition names wrong parent' $root 'none:not-applicable must resolve exactly one approved decomposition record; found 0'

  $root = New-Case 'none-child-decomposition-missing'
  Write-MasterPlan $root 'none' 'not-applicable' 'not-applicable' 'not-applicable' 'not-applicable' `
    -WorkItemId 'WORK-ADMIN-SIMPLE-LOCKS' `
    -ParentWorkItemId 'WORK-ADMIN-LOCKS' `
    -DecisionReference 'DEC-ARCH-014' `
    -WorkItemRows @(Get-NoneChildWorkItemRows)
  Write-FrontHalf $root `
    -WorkItemId 'WORK-ADMIN-SIMPLE-LOCKS' `
    -ParentWorkItemId 'WORK-ADMIN-LOCKS' `
    -DecisionReference 'DEC-ARCH-014' `
    -Steps @(4, 5, 6, 7, 8)
  Assert-Rejected 'none child without decomposition record' $root 'none:not-applicable must resolve exactly one approved decomposition record; found 0'

  $root = New-Case 'valid-migration-unit'
  Write-MasterPlan $root 'migration-unit' 'UNIT-ADM-002' '08-migration-plan.md' '3' 'not-applicable'
  Write-FrontHalf $root
  Write-MigrationPlan $root @(Get-UnitRow)
  Assert-Accepted 'valid canonical migration-unit adapter' $root

  $root = New-Case 'draft-master-plan'
  Write-MasterPlan $root 'migration-unit' 'UNIT-ADM-002' '08-migration-plan.md' '3' 'not-applicable' -Status 'draft'
  Write-FrontHalf $root
  Write-MigrationPlan $root @(Get-UnitRow)
  Assert-Rejected 'draft current master plan' $root 'Current master plan must be approved'

  $root = New-Case 'blocked-front-half-step'
  Write-MasterPlan $root 'migration-unit' 'UNIT-ADM-002' '08-migration-plan.md' '3' 'not-applicable'
  Write-FrontHalf $root -OverrideStep 6 -OverrideStatus 'draft' -OverrideResult 'blocked'
  Write-MigrationPlan $root @(Get-UnitRow)
  Assert-Rejected 'blocked canonical step 06' $root 'step 06 must be approved and complete'

  $root = New-Case 'draft-migration-step08'
  Write-MasterPlan $root 'migration-unit' 'UNIT-ADM-002' '08-migration-plan.md' '3' 'not-applicable'
  Write-FrontHalf $root
  Write-MigrationPlan $root @(Get-UnitRow) -Status 'draft' -Result 'blocked'
  Assert-Rejected 'draft canonical migration step 08' $root 'canonical plan is not approved and complete'

  $root = New-Case 'blocked-generic-step08'
  Write-MasterPlan $root 'task' 'TASK-42' 'jira:ADMIN' '12' 'not-applicable'
  Write-FrontHalf $root -Steps @(4, 5, 6, 7, 8) -OverrideStep 8 -OverrideStatus 'draft' -OverrideResult 'blocked'
  Assert-Rejected 'blocked generic canonical step 08' $root 'step 08 must be approved and complete'

  $root = New-Case 'external-only'
  Write-MasterPlan $root 'migration-unit' 'UNIT-ADM-404' '08-migration-plan.md' '3' 'not-applicable'
  Write-FrontHalf $root
  Write-MigrationPlan $root @(Get-UnitRow)
  Assert-Rejected 'external-only selector' $root 'must resolve exactly one canonical migration unit; found 0'

  $root = New-Case 'invalid-migration-unit-id'
  Write-MasterPlan $root 'migration-unit' 'TASK-42' '08-migration-plan.md' '3' 'not-applicable'
  Write-FrontHalf $root
  Write-MigrationPlan $root @(Get-UnitRow -UnitId 'TASK-42')
  Assert-Rejected 'invalid migration-unit external ID' $root 'external ID must match canonical UNIT-* format'

  $root = New-Case 'duplicate-selector'
  Write-MasterPlan $root 'migration-unit' 'UNIT-ADM-002' '08-migration-plan.md' '3' 'not-applicable'
  Write-FrontHalf $root
  Write-MigrationPlan $root @((Get-UnitRow), (Get-UnitRow))
  Assert-Rejected 'duplicate selector' $root 'must resolve exactly one canonical migration unit; found 2'

  $root = New-Case 'duplicate-work-item-selection'
  Write-MasterPlan $root 'task' 'TASK-42' 'jira:ADMIN' '12' 'not-applicable' `
    -AdditionalSelectionRows @('| WORK-ADMIN-LOCKS | story | STORY-9 | ado:ADMIN | 6 | approval:STORY-9 | not-applicable | REQ-101: lock mode persists | REQ-101, ITEM-201, MAP-301, DESIGN-401 | incremental/preserve-existing | DESIGN-401@4 | not-applicable | not-applicable |')
  Assert-Rejected 'one work item with duplicate adapter selections' $root 'must have exactly one Delivery Adapter Selection row; found 2'

  $root = New-Case 'duplicate-external-selector'
  Write-MasterPlan $root 'task' 'TASK-42' 'jira:ADMIN' '12' 'not-applicable' `
    -WorkItemRows @(
      '| WORK-ADMIN-LOCKS | Lock behavior | yes | none | 1 | REQ-101: lock mode persists | REQ-101, ITEM-201, MAP-301, DESIGN-401 | task:TASK-42 | ready | none | none | approval:WORK-ADMIN-LOCKS |',
      '| WORK-ADMIN-AUDIT | Audit behavior | yes | none | 2 | REQ-102: audit persists | REQ-102 | task:TASK-42 | ready | none | none | approval:WORK-ADMIN-AUDIT |'
    ) `
    -AdditionalSelectionRows @('| WORK-ADMIN-AUDIT | task | TASK-42 | jira:ADMIN | 12 | approval:TASK-42 | not-applicable | REQ-102: audit persists | REQ-102 | incremental/preserve-existing | DESIGN-402@1 | not-applicable | not-applicable |')
  Assert-Rejected 'duplicate external selector across work items' $root 'external selector task:TASK-42 is assigned to more than one Work Item ID'

  $root = New-Case 'stale-design'
  Write-MasterPlan $root 'migration-unit' 'UNIT-ADM-002' '08-migration-plan.md' '3' 'not-applicable' -DesignRevision 'DESIGN-401@5'
  Write-FrontHalf $root
  Write-MigrationPlan $root @(Get-UnitRow)
  Assert-Rejected 'stale design revision' $root 'Design Revision mismatch'

  $root = New-Case 'acceptance-mismatch'
  Write-MasterPlan $root 'migration-unit' 'UNIT-ADM-002' '08-migration-plan.md' '3' 'not-applicable' `
    -Acceptance 'REQ-101: lock mode persists and audits'
  Write-FrontHalf $root -Acceptance 'REQ-101: lock mode persists and audits'
  Write-MigrationPlan $root @(Get-UnitRow)
  Assert-Rejected 'acceptance mismatch' $root 'Acceptance mismatch'

  $root = New-Case 'mode-mismatch'
  Write-MasterPlan $root 'migration-unit' 'UNIT-ADM-002' '08-migration-plan.md' '3' 'not-applicable' `
    -Mode 'greenfield/design-new'
  Write-FrontHalf $root -Mode 'greenfield/design-new'
  Write-MigrationPlan $root @(Get-UnitRow)
  Assert-Rejected 'mode mismatch' $root 'Mode Constraint mismatch'

  $root = New-Case 'trace-mismatch'
  Write-MasterPlan $root 'migration-unit' 'UNIT-ADM-002' '08-migration-plan.md' '3' 'not-applicable' -TraceIds 'REQ-101, ITEM-999, MAP-301, DESIGN-401'
  Write-FrontHalf $root
  Write-MigrationPlan $root @(Get-UnitRow)
  Assert-Rejected 'trace mismatch' $root 'Trace IDs mismatch'

  $root = New-Case 'dependency-mismatch'
  Write-MasterPlan $root 'migration-unit' 'UNIT-ADM-002' '08-migration-plan.md' '3' 'not-applicable' `
    -Dependencies 'WORK-ADMIN-FOUNDATION'
  Write-FrontHalf $root
  Write-MigrationPlan $root @(Get-UnitRow)
  Assert-Rejected 'dependency mismatch' $root 'Dependencies mismatch'

  $root = New-Case 'valid-child'
  Write-MasterPlan $root 'migration-unit' 'UNIT-ADM-002A' '08-migration-plan.md' '3' 'UNIT-ADM-002' `
    -WorkItemId 'WORK-ADMIN-SIMPLE-LOCKS' `
    -ParentWorkItemId 'WORK-ADMIN-LOCKS' `
    -DecisionReference 'DEC-ARCH-014' `
    -WorkItemRows @(Get-ChildWorkItemRows) `
    -DecompositionRows @(Get-ApprovedDecompositionRows)
  Write-FrontHalf $root `
    -WorkItemId 'WORK-ADMIN-SIMPLE-LOCKS' `
    -ParentWorkItemId 'WORK-ADMIN-LOCKS' `
    -DecisionReference 'DEC-ARCH-014'
  Write-MigrationPlan $root @(
    (Get-UnitRow),
    (Get-UnitRow `
      -UnitId 'UNIT-ADM-002A' `
      -WorkItemId 'WORK-ADMIN-SIMPLE-LOCKS' `
      -ParentWorkItemId 'WORK-ADMIN-LOCKS' `
      -DecisionReference 'DEC-ARCH-014')
  )
  Assert-Accepted 'valid canonical child migration-unit adapter' $root

  $root = New-Case 'duplicate-child-work-item-row'
  $duplicateChildRows = @(Get-ChildWorkItemRows)
  $duplicateChildRows += $duplicateChildRows[1]
  Write-MasterPlan $root 'migration-unit' 'UNIT-ADM-002A' '08-migration-plan.md' '3' 'UNIT-ADM-002' `
    -WorkItemId 'WORK-ADMIN-SIMPLE-LOCKS' `
    -ParentWorkItemId 'WORK-ADMIN-LOCKS' `
    -DecisionReference 'DEC-ARCH-014' `
    -WorkItemRows $duplicateChildRows `
    -DecompositionRows @(Get-ApprovedDecompositionRows)
  Write-FrontHalf $root `
    -WorkItemId 'WORK-ADMIN-SIMPLE-LOCKS' `
    -ParentWorkItemId 'WORK-ADMIN-LOCKS' `
    -DecisionReference 'DEC-ARCH-014'
  Write-MigrationPlan $root @(
    (Get-UnitRow),
    (Get-UnitRow `
      -UnitId 'UNIT-ADM-002A' `
      -WorkItemId 'WORK-ADMIN-SIMPLE-LOCKS' `
      -ParentWorkItemId 'WORK-ADMIN-LOCKS' `
      -DecisionReference 'DEC-ARCH-014')
  )
  Assert-Rejected 'duplicate child Work Item row' $root 'must resolve exactly one current master Work Item row; found 2'

  $root = New-Case 'child-decomposition-missing'
  Write-MasterPlan $root 'migration-unit' 'UNIT-ADM-002A' '08-migration-plan.md' '3' 'UNIT-ADM-002' `
    -WorkItemId 'WORK-ADMIN-SIMPLE-LOCKS' `
    -ParentWorkItemId 'WORK-ADMIN-LOCKS' `
    -DecisionReference 'DEC-ARCH-014' `
    -WorkItemRows @(Get-ChildWorkItemRows)
  Write-FrontHalf $root `
    -WorkItemId 'WORK-ADMIN-SIMPLE-LOCKS' `
    -ParentWorkItemId 'WORK-ADMIN-LOCKS' `
    -DecisionReference 'DEC-ARCH-014'
  Write-MigrationPlan $root @(
    (Get-UnitRow),
    (Get-UnitRow `
      -UnitId 'UNIT-ADM-002A' `
      -WorkItemId 'WORK-ADMIN-SIMPLE-LOCKS' `
      -ParentWorkItemId 'WORK-ADMIN-LOCKS' `
      -DecisionReference 'DEC-ARCH-014')
  )
  Assert-Rejected 'child without approved decomposition' $root 'must resolve exactly one approved decomposition record; found 0'

  $root = New-Case 'parent-selector-mismatch'
  Write-MasterPlan $root 'migration-unit' 'UNIT-ADM-002A' '08-migration-plan.md' '3' 'UNIT-ADM-404' `
    -WorkItemId 'WORK-ADMIN-SIMPLE-LOCKS' `
    -ParentWorkItemId 'WORK-ADMIN-LOCKS' `
    -DecisionReference 'DEC-ARCH-014' `
    -WorkItemRows @(Get-ChildWorkItemRows) `
    -DecompositionRows @(Get-ApprovedDecompositionRows)
  Write-FrontHalf $root `
    -WorkItemId 'WORK-ADMIN-SIMPLE-LOCKS' `
    -ParentWorkItemId 'WORK-ADMIN-LOCKS' `
    -DecisionReference 'DEC-ARCH-014' `
    -WorkItemRows @(Get-ChildWorkItemRows) `
    -DecompositionRows @(Get-ApprovedDecompositionRows)
  Write-MigrationPlan $root @(
    (Get-UnitRow),
    (Get-UnitRow `
      -UnitId 'UNIT-ADM-002A' `
      -WorkItemId 'WORK-ADMIN-SIMPLE-LOCKS' `
      -ParentWorkItemId 'WORK-ADMIN-LOCKS' `
      -DecisionReference 'DEC-ARCH-014')
  )
  Assert-Rejected 'child parent selector mismatch' $root 'parent selector must resolve exactly one canonical parent migration unit; found 0'

  $root = New-Case 'child-bypass'
  Write-MasterPlan $root 'migration-unit' 'UNIT-ADM-002A' '08-migration-plan.md' '3' 'UNIT-ADM-002' `
    -WorkItemId 'WORK-ADMIN-SIMPLE-LOCKS' `
    -ParentWorkItemId 'WORK-ADMIN-LOCKS' `
    -DecisionReference 'DEC-ARCH-014'
  Write-MigrationPlan $root @(
    (Get-UnitRow),
    (Get-UnitRow `
      -UnitId 'UNIT-ADM-002A' `
      -WorkItemId 'WORK-ADMIN-SIMPLE-LOCKS' `
      -ParentWorkItemId 'WORK-ADMIN-LOCKS' `
      -DecisionReference 'DEC-ARCH-014')
  )
  Assert-Rejected 'child bypasses canonical steps 04-08' $root 'missing canonical child trace at step 04'

  "PASS: delivery adapters ($script:passed scenarios)"
}
finally {
  if (Test-Path -LiteralPath $caseRoot) {
    Remove-Item -LiteralPath $caseRoot -Recurse -Force
  }
}

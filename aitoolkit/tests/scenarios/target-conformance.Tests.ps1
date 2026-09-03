$ErrorActionPreference = 'Stop'

$toolkitRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$contractPath = Join-Path $toolkitRoot 'contracts/target-structure-conformance.md'
$scopeContractPath = Join-Path $toolkitRoot 'contracts/migration-scope-orchestration.md'
$validatorPath = Join-Path $toolkitRoot 'tests/validation/target-conformance.validation.ps1'
$contractText = Get-Content -Raw -Encoding utf8 -LiteralPath $contractPath
$scopeContractText = Get-Content -Raw -Encoding utf8 -LiteralPath $scopeContractPath

function Require-Token([string]$Text, [string]$Token, [string]$Context) {
  if ($Text -notmatch [regex]::Escape($Token)) {
    $script:errors.Add("$Context missing: $Token")
  }
}

function Test-MarkdownTableExactColumns {
  param(
    [string]$Text,
    [string]$Heading,
    [string[]]$ExpectedColumns,
    [string]$Context
  )

  $headingPattern = '(?m)^##\s+' + [regex]::Escape($Heading) + '\s*$'
  $headingMatch = [regex]::Match($Text, $headingPattern)
  if (-not $headingMatch.Success) {
    $script:errors.Add("$Context missing table: $Heading")
    return
  }
  $tail = $Text.Substring($headingMatch.Index + $headingMatch.Length)
  $rowMatch = [regex]::Match($tail, '(?m)^\|(?<row>[^\r\n]+)\|\s*$')
  if (-not $rowMatch.Success) {
    $script:errors.Add("$Context missing table header: $Heading")
    return
  }
  $actualColumns = @($rowMatch.Groups['row'].Value.Split('|') | ForEach-Object { $_.Trim() })
  if (($actualColumns -join '|') -cne ($ExpectedColumns -join '|')) {
    $script:errors.Add("$Context $Heading table columns must be exactly: $($ExpectedColumns -join ' | ')")
  }
}

. $validatorPath

$concerns = @(
  'module/container composition',
  'main/child presentation boundaries',
  'unit/component organization',
  'controller/provider/state pattern',
  'routing and lifecycle',
  'localization',
  'service/config subscription and normalization',
  'test harness and production-boundary tests'
)

function New-ScenarioRoot {
  $scenarioRoot = Join-Path ([IO.Path]::GetTempPath()) ('aitoolkit-target-conformance-' + [guid]::NewGuid().ToString('N'))
  [void](New-Item -ItemType Directory -Path (Join-Path $scenarioRoot 'contracts') -Force)
  Set-Content -Encoding utf8 -LiteralPath (Join-Path $scenarioRoot 'contracts/target-structure-conformance.md') -Value $contractText
  Set-Content -Encoding utf8 -LiteralPath (Join-Path $scenarioRoot 'contracts/migration-scope-orchestration.md') -Value $scopeContractText
  return $scenarioRoot
}

function New-DiscoveryArtifact {
  param(
    [string[]]$IncludedConcerns = $concerns,
    [string]$BlankSymbolsConcern = '',
    [string]$NotComparableConcern = '',
    [string]$UnknownConcern = '',
    [string]$NoEquivalentConcern = '',
    [switch]$ExtraConcern,
    [switch]$DuplicateConcern,
    [switch]$WildcardSymbols,
    [switch]$EmptyInspectedSymbols,
    [switch]$EmptyDataFlow,
    [switch]$MeaninglessDataFlow,
    [switch]$StrayGapRow,
    [switch]$InvalidGapSentinel,
    [switch]$WeakGapDecision,
    [switch]$PendingGapApproval,
    [string]$GapDecisionOverride = '',
    [string]$GapApprovalOverride = '',
    [switch]$GenericSymbolList,
    [switch]$SingleProviderDataFlow,
    [switch]$UnstructuredTransformation,
    [switch]$DisconnectedDataFlow,
    [string]$ComparableSymbolsOverride = '',
    [string]$InspectedSymbolOverride = ''
  )

  $rows = foreach ($concern in $IncludedConcerns) {
    $symbols = if (
      -not [string]::IsNullOrWhiteSpace($ComparableSymbolsOverride) -and
      $concern -ceq 'controller/provider/state pattern'
    ) {
      $ComparableSymbolsOverride
    }
    elseif ($concern -ceq $BlankSymbolsConcern) {
      ''
    }
    elseif ($WildcardSymbols -and $concern -ceq 'controller/provider/state pattern') {
      '*'
    }
    elseif ($GenericSymbolList -and $concern -ceq 'controller/provider/state pattern') {
      'TargetController, all; GenericProvider'
    }
    else {
      'TargetShell, TargetController'
    }
    $comparableReason = if ($concern -ceq $NotComparableConcern) { 'not comparable' } else { 'same production responsibility and activation path' }
    $status = if ($concern -ceq $UnknownConcern) {
      'unknown'
    }
    elseif ($concern -ceq $NoEquivalentConcern) {
      'no-equivalent'
    }
    else {
      'verified'
    }
    "| $concern | lib/target_shell.dart | $symbols | working target pattern for $concern | $comparableReason | lib/target_shell.dart:10-80 | $status |"
  }
  if ($ExtraConcern) {
    $rows += '| invented concern | lib/invented.dart | InventedController | invented pattern | same production responsibility and activation path | lib/invented.dart:1-20 | verified |'
  }
  if ($DuplicateConcern) {
    $rows += '| module/container composition | lib/duplicate.dart | DuplicateShell | duplicate pattern | same production responsibility and activation path | lib/duplicate.dart:1-20 | verified |'
  }

  $gapDecision = if (-not [string]::IsNullOrWhiteSpace($GapDecisionOverride)) {
    $GapDecisionOverride
  }
  elseif ($WeakGapDecision) {
    'resolved: none'
  }
  else {
    'resolved:DECISION-014: reuse adjacent target boundary'
  }
  $gapApproval = if (-not [string]::IsNullOrWhiteSpace($GapApprovalOverride)) {
    $GapApprovalOverride
  }
  elseif ($PendingGapApproval) {
    'approval:pending'
  }
  else {
    'approval:TECH-LEAD-014'
  }
  $gapRow = if ($StrayGapRow) {
    '| localization | GAP-099 | CONFLICT-099 | resolved: use approved localization boundary | approval:TECH-LEAD-099 |'
  }
  elseif ($InvalidGapSentinel) {
    '| none | GAP-FAKE | not-applicable | resolved: none | approval:pending |'
  }
  elseif ([string]::IsNullOrWhiteSpace($NoEquivalentConcern)) {
    '| none | not-applicable | not-applicable | not-applicable | not-applicable |'
  }
  else {
    "| $NoEquivalentConcern | GAP-014 | CONFLICT-014 | $gapDecision | $gapApproval |"
  }

  $inspectedSymbolRow = if ($EmptyInspectedSymbols) {
    ''
  }
  else {
    $inspectedSymbol = if ([string]::IsNullOrWhiteSpace($InspectedSymbolOverride)) { 'TargetController' } else { $InspectedSymbolOverride }
    "| controller/provider/state pattern | lib/target_shell.dart | $inspectedSymbol | complete declaration and production consumers | lib/target_shell.dart:10-80 |"
  }
  $dataFlowRows = if ($EmptyDataFlow) {
    @()
  }
  elseif ($MeaninglessDataFlow) {
    @('| provider | none | none | state management | none | none |')
  }
  elseif ($SingleProviderDataFlow) {
    @('| state | lib/target_shell.dart#TargetController | normalized config | operation=store; owner=lib/target_shell.dart#TargetController | selected state | lib/target_shell.dart:10-80 |')
  }
  else {
    @(
      '| source | lib/config_service.dart#ConfigSource | service event | operation=read; owner=lib/config_service.dart#ConfigSource | raw config | lib/config_service.dart:10-30 |',
      '| subscription | lib/config_service.dart#ConfigSubscription | raw config | operation=subscribe; owner=lib/config_service.dart#ConfigSubscription | subscribed config | lib/config_service.dart:31-50 |',
      '| normalization | lib/config_normalizer.dart#ConfigNormalizer.normalize | subscribed config | operation=normalize; owner=lib/config_normalizer.dart#ConfigNormalizer.normalize | normalized config | lib/config_normalizer.dart:10-35 |',
      '| state | lib/target_shell.dart#TargetController | normalized config | operation=store; owner=lib/target_shell.dart#TargetController | feature state | lib/target_shell.dart:10-45 |',
      '| selection | lib/target_shell.dart#TargetSelector.select | feature state | operation=select; owner=lib/target_shell.dart#TargetSelector.select | selected state | lib/target_shell.dart:46-65 |',
      '| render | lib/target_shell.dart#TargetShell.render | selected state | operation=render; owner=lib/target_shell.dart#TargetShell.render | production view | lib/target_shell.dart:66-80 |',
      '| test | test/target_shell_test.dart#productionBoundary | production view | operation=verify; owner=test/target_shell_test.dart#productionBoundary | verified boundary | test/target_shell_test.dart:10-60 |'
    )
  }
  if ($UnstructuredTransformation -and $dataFlowRows.Count -gt 0) {
    $dataFlowRows[2] = '| normalization | lib/config_normalizer.dart#ConfigNormalizer.normalize | subscribed config | normalize everything somehow | normalized config | lib/config_normalizer.dart:10-35 |'
  }
  if ($DisconnectedDataFlow -and $dataFlowRows.Count -gt 0) {
    $dataFlowRows[3] = '| state | lib/target_shell.dart#TargetController | unrelated payload | operation=store; owner=lib/target_shell.dart#TargetController | feature state | lib/target_shell.dart:10-45 |'
  }
  return @"
---
step_id: 02-discovery
status: draft
result: complete
produced_at: 2026-08-19
---

# Discovery

## Comparable Target Exemplars

| Concern | Path | Inspected Symbols | Observed Pattern | Comparable Reason | Evidence | Status |
|---|---|---|---|---|---|---|
$($rows -join "`n")

## Inspected Symbols

| Concern | Path | Symbol | Inspection Scope | Evidence |
|---|---|---|---|---|
$inspectedSymbolRow

## Target Data-flow Trace

| Stage | Path/Symbol | Input | Transformation | Output/Consumer | Evidence |
|---|---|---|---|---|---|
$($dataFlowRows -join "`n")

## No-equivalent Gaps

| Concern | Gap Reference | Conflict Reference | Resolved Decision | Approval Reference |
|---|---|---|---|---|
$gapRow
"@
}

function New-DesignArtifact {
  param(
    [string[]]$IncludedConcerns = $concerns,
    [string]$VagueConcern = '',
    [string]$VagueValue = 'Use Riverpod',
    [switch]$VagueObservedOnly,
    [string]$NonConformingConcern = '',
    [switch]$ResolveDeviation,
    [switch]$OmitWorkItemTrace,
    [switch]$OmitApprovedPlanEvidence,
    [switch]$OmitPlannedTree,
    [switch]$PanelWrapperMismatch,
    [switch]$OmitLifecycleBoundary,
    [switch]$ExtraConcern,
    [switch]$DuplicateConcern,
    [switch]$WeakDeviationDecision,
    [switch]$PendingDeviationApproval,
    [string]$DeviationDecisionOverride = '',
    [string]$DeviationApprovalOverride = '',
    [switch]$OmitProposedWrapper,
    [switch]$OmitObservedWrapper,
    [switch]$OmitPlannedMatrixPath,
    [switch]$AddUnrelatedPlannedPath,
    [switch]$WindowsProposedPaths,
    [switch]$RootProposedPaths,
    [switch]$TraversalProposedPath,
    [switch]$MalformedProposedPath,
    [string]$WorkItemId = 'WORK-ADMIN-TARGET',
    [string]$MasterPlanReference = 'master-plan.md#PLAN-ADMIN-001',
    [string]$MasterPlanRevision = '2',
    [string]$Acceptance = 'REQ-001; SC-001; measurable outcome',
    [string]$AcceptanceTraces = 'REQ-001, SC-001',
    [string]$TraceIds = 'TRACE-001',
    [string]$DeliveryAdapter = 'none',
    [string]$DecompositionReference = 'not-applicable',
    [string]$ObservedSymbolsOverride = '',
    [string]$ObservedWrapperOverride = '',
    [string]$ProposedWrapperOverride = '',
    [switch]$ForgeApprovedPlanAndTrace,
    [switch]$BindApprovedPlanToTrace
  )

  $approvedPlanId = 'PLAN-ADMIN-001'
  $approvedWorkItemId = 'WORK-ADMIN-TARGET'
  $approvedPlanReference = 'master-plan.md#PLAN-ADMIN-001'
  $approvedPlanRevision = '2'
  $approvedAcceptance = 'REQ-001; SC-001; measurable outcome'
  $approvedTraceIds = 'TRACE-001'
  $approvedDeliveryAdapter = 'none'
  $approvedDecompositionReference = 'not-applicable'
  if ($ForgeApprovedPlanAndTrace) {
    $WorkItemId = 'WORK-FAKE-TARGET'
    $MasterPlanReference = 'master-plan.md#PLAN-FAKE-001'
    $MasterPlanRevision = '9'
    $Acceptance = 'REQ-FAKE-014; SC-FAKE-014; measurable forged outcome'
    $AcceptanceTraces = 'REQ-FAKE-014, SC-FAKE-014'
    $TraceIds = 'TRACE-FAKE-014'
    $DeliveryAdapter = 'task:TASK-FAKE-014'
    $DecompositionReference = 'DEC-FAKE-014'
    $approvedPlanId = 'PLAN-FAKE-001'
    $approvedWorkItemId = $WorkItemId
    $approvedPlanReference = $MasterPlanReference
    $approvedPlanRevision = $MasterPlanRevision
    $approvedAcceptance = $Acceptance
    $approvedTraceIds = $TraceIds
    $approvedDeliveryAdapter = $DeliveryAdapter
    $approvedDecompositionReference = $DecompositionReference
  }
  elseif ($BindApprovedPlanToTrace) {
    $approvedPlanId = @($MasterPlanReference.Split('#'))[-1]
    $approvedWorkItemId = $WorkItemId
    $approvedPlanReference = $MasterPlanReference
    $approvedPlanRevision = $MasterPlanRevision
    $approvedAcceptance = $Acceptance
    $approvedTraceIds = $TraceIds
    $approvedDeliveryAdapter = $DeliveryAdapter
    $approvedDecompositionReference = $DecompositionReference
  }

  $featureProposed = 'lib/admin/target_feature.dart#TargetFeature'
  $panelProposed = 'lib/admin/target_panel.dart#TargetFeaturePanel'
  $plannedFeaturePath = 'lib/admin/target_feature.dart'
  $plannedFeatureSymbol = 'TargetFeature'
  $plannedPanelPath = 'lib/admin/target_panel.dart'
  $plannedPanelSymbol = 'TargetFeaturePanel'
  if ($WindowsProposedPaths) {
    $featureProposed = 'lib\admin\target_feature.dart#App.TargetFeature'
    $panelProposed = 'lib\admin\target_panel.dart#App.TargetFeaturePanel'
    $plannedFeatureSymbol = 'App.TargetFeature'
    $plannedPanelSymbol = 'App.TargetFeaturePanel'
  }
  elseif ($RootProposedPaths) {
    $featureProposed = 'main.dart#App.TargetFeature'
    $panelProposed = 'panel.dart#App.TargetFeaturePanel'
    $plannedFeaturePath = 'main.dart'
    $plannedFeatureSymbol = 'App.TargetFeature'
    $plannedPanelPath = 'panel.dart'
    $plannedPanelSymbol = 'App.TargetFeaturePanel'
  }
  elseif ($TraversalProposedPath) {
    $featureProposed = 'lib/../secret.dart#TargetFeature'
    $plannedFeaturePath = 'lib/../secret.dart'
  }
  elseif ($MalformedProposedPath) {
    $featureProposed = '#MissingPath'
    $plannedFeaturePath = 'missing-path'
    $plannedFeatureSymbol = 'MissingPath'
  }

  $rows = foreach ($concern in $IncludedConcerns) {
    $exemplar = 'lib/exemplars/target_pattern.dart#TargetPattern'
    $observed = 'path=lib/exemplars/target_pattern.dart#TargetPattern; symbols=TargetPattern, TargetBoundary; boundary=TargetBoundary; mechanism=extendTargetPattern'
    if (
      -not [string]::IsNullOrWhiteSpace($ObservedSymbolsOverride) -and
      $concern -ceq 'controller/provider/state pattern'
    ) {
      $observed = "path=lib/exemplars/target_pattern.dart#TargetPattern; symbols=$ObservedSymbolsOverride; boundary=TargetBoundary; mechanism=extendTargetPattern"
    }
    $proposed = $featureProposed
    if ($concern -ceq 'main/child presentation boundaries') {
      $observed = 'path=lib/exemplars/target_panel.dart#TargetPanel; symbols=TargetPanel, TargetPanelChild; boundary=PresentationBoundary; mechanism=composeChild'
      if (-not $OmitObservedWrapper) {
        $observedWrapper = if ([string]::IsNullOrWhiteSpace($ObservedWrapperOverride)) { 'TargetPanel' } else { $ObservedWrapperOverride }
        $observed += "; wrapper=$observedWrapper"
      }
      $exemplar = 'lib/exemplars/target_panel.dart#TargetPanel'
      $wrapper = if (-not [string]::IsNullOrWhiteSpace($ProposedWrapperOverride)) {
        $ProposedWrapperOverride
      }
      elseif ($PanelWrapperMismatch) {
        'RawContainer'
      }
      else {
        'TargetPanel'
      }
      $proposed = if ($OmitProposedWrapper) {
        $panelProposed
      }
      else {
        "$panelProposed; wrapper=$wrapper"
      }
    }
    if ($concern -ceq $VagueConcern) {
      $observed = $VagueValue
      if (-not $VagueObservedOnly) {
        $proposed = $VagueValue
      }
    }
    $conforms = if ($concern -ceq $NonConformingConcern) { 'no' } else { 'yes' }
    $deviation = if ($conforms -ceq 'no') { 'DEV-014' } else { 'not-applicable' }
    "| $concern | $exemplar | $observed | $proposed | $conforms | $deviation |"
  }
  if ($ExtraConcern) {
    $rows += '| invented concern | 02-discovery.md#invented | invented concrete pattern | lib/admin/invented.dart#Invented | yes | not-applicable |'
  }
  if ($DuplicateConcern) {
    $rows += '| module/container composition | 02-discovery.md#duplicate | duplicate concrete pattern | lib/admin/duplicate.dart#Duplicate | yes | not-applicable |'
  }

  $deviationDecision = if (-not [string]::IsNullOrWhiteSpace($DeviationDecisionOverride)) {
    $DeviationDecisionOverride
  }
  elseif ($WeakDeviationDecision) {
    'resolved: none'
  }
  else {
    'resolved:DECISION-014: approved alternate panel wrapper'
  }
  $deviationApproval = if (-not [string]::IsNullOrWhiteSpace($DeviationApprovalOverride)) {
    $DeviationApprovalOverride
  }
  elseif ($PendingDeviationApproval) {
    'approval:pending'
  }
  else {
    'approval:TECH-LEAD-014'
  }
  $deviationRow = if ($ResolveDeviation) {
    "| DEV-014 | main/child presentation boundaries | CONFLICT-014 | $deviationDecision | $deviationApproval |"
  }
  else {
    '| none | not-applicable | not-applicable | not-applicable | not-applicable |'
  }

  $plannedTreeRows = @(
    "| $plannedFeaturePath | $plannedFeatureSymbol | provider-owned feature state | 02-discovery.md#controller/provider/state-pattern |"
  )
  if (-not $OmitPlannedMatrixPath) {
    $plannedTreeRows += "| $plannedPanelPath | $plannedPanelSymbol | TargetPanel child presentation | 02-discovery.md#main-child-presentation-boundaries |"
  }
  if ($AddUnrelatedPlannedPath) {
    $plannedTreeRows += '| lib/admin/unrelated.dart | Unrelated | unrelated structure | 02-discovery.md#module-container-composition |'
  }
  $plannedTree = if ($OmitPlannedTree) {
    ''
  }
  else {
@"
## Planned File Tree

| Planned Path | Planned Symbol | Responsibility | Exemplar or Deviation Reference |
|---|---|---|---|
$($plannedTreeRows -join "`n")
"@
  }

  $boundaryRows = @(
    '| provider | lib/admin/target_feature.dart#TargetFeatureProvider | config input | normalized state | loading/error/data policy | 02-discovery.md#controller-provider-state |',
    '| router | lib/router.dart#targetRoute | route request | TargetFeaturePanel | route guard and disposal | 02-discovery.md#routing-lifecycle |',
    '| localization | lib/l10n/app_localizations.dart#targetLabel | locale key | localized label | generated localization lookup | 02-discovery.md#localization |',
    '| subscription | lib/admin/target_feature.dart#TargetSubscription | service event | provider update | subscribe, normalize, cancel | 02-discovery.md#service-config |'
  )
  if (-not $OmitLifecycleBoundary) {
    $boundaryRows += '| lifecycle | lib/admin/target_panel.dart#TargetFeaturePanel | mount/update/dispose | subscription ownership | watch, reselection, failure, cancel | 02-discovery.md#routing-lifecycle |'
  }

  $workItemTrace = if ($OmitWorkItemTrace) {
    ''
  }
  else {
@"
## Work Item Trace

| Work Item ID | Master Plan Reference | Master Plan Revision | Acceptance Traces | Decomposition Decision Reference |
|---|---|---|---|---|
| $WorkItemId | $MasterPlanReference | $MasterPlanRevision | $AcceptanceTraces | $DecompositionReference |
"@
  }

  $approvedPlanEvidence = if ($OmitApprovedPlanEvidence) {
    ''
  }
  else {
@"
## Approved Master Plan Evidence

| Master Plan Reference | Master Plan ID | Revision | Status | Work Item ID | Acceptance | Trace IDs | Delivery Adapter | Decomposition Decision Reference | Approval Reference | Evidence Reference |
|---|---|---|---|---|---|---|---|---|---|---|
| $approvedPlanReference | $approvedPlanId | $approvedPlanRevision | approved | $approvedWorkItemId | $approvedAcceptance | $approvedTraceIds | $approvedDeliveryAdapter | $approvedDecompositionReference | approval:TECH-LEAD-PLAN-014 | $approvedPlanReference@revision=$($approvedPlanRevision):$approvedWorkItemId |
"@
  }
  return @"
---
step_id: 07-technical-design
status: draft
result: complete
produced_at: 2026-08-19
---

# Technical Design

$approvedPlanEvidence

$workItemTrace

## Target Structure Conformance Matrix

| Concern | Working Exemplar | Observed Target Pattern | Proposed Path/Symbol | Conforms | Deviation Reference |
|---|---|---|---|---|---|
$($rows -join "`n")

## Approved Structural Deviations

| Deviation Reference | Concern | Conflict Reference | Resolved Decision | Tech Lead Approval |
|---|---|---|---|---|
$deviationRow

$plannedTree

## Provider/Router/Localization/Subscription Boundaries

| Boundary | Owner Path/Symbol | Input | Output | Lifecycle/Failure Policy | Evidence |
|---|---|---|---|---|---|
$($boundaryRows -join "`n")
"@
}

function New-MasterPlanArtifact {
  param(
    [string]$Status = 'approved',
    [string]$Revision = '2',
    [string]$ArtifactType = 'migration-master-plan',
    [string]$MasterPlanId = 'PLAN-ADMIN-001',
    [string]$MasterSpecId = 'SPEC-ADMIN-001',
    [string]$MasterSpecRevision = '1',
    [string]$WorkItemId = 'WORK-ADMIN-TARGET',
    [string]$Acceptance = 'REQ-001; SC-001; measurable outcome',
    [string]$TraceIds = 'TRACE-001',
    [string]$DeliveryAdapter = 'none',
    [string]$ApprovalReference = 'approval:TECH-LEAD-PLAN-014',
    [string]$ApprovalStatus = 'approved',
    [string]$RevisionApprovalReference = '',
    [ValidateSet('not-applicable', 'approved', 'missing', 'stale', 'duplicate', 'wrong-parent')]
    [string]$Decomposition = 'not-applicable',
    [switch]$DuplicateWorkItem,
    [switch]$MissingWorkItem,
    [switch]$MalformedWorkDelimiter,
    [switch]$SingleCellWorkDelimiter,
    [switch]$ExtraCellWorkDelimiter,
    [switch]$OmitFrontMatter
  )

  $supersedes = if ($Revision -ceq '1') { 'not-applicable' } else { "$MasterPlanId@$([int]$Revision - 1)" }
  $frontMatter = if ($OmitFrontMatter) {
    ''
  }
  else {
@"
---
artifact_type: $ArtifactType
master_plan_id: $MasterPlanId
master_spec_id: $MasterSpecId
master_spec_revision: $MasterSpecRevision
revision: $Revision
status: $Status
scope_status: scope-in-progress
execution_policy: dependency-ready
max_concurrency: 1
produced_at: 2026-08-19
supersedes: $supersedes
---
"@
  }
  $workRows = [Collections.Generic.List[string]]::new()
  if ($Decomposition -cne 'not-applicable') {
    $workRows.Add('| WORK-ADMIN-PARENT | Parent outcome replaced by approved children | yes | none | 1 | REQ-013; SC-013; measurable parent outcome | TRACE-013 | none | cancelled-approved | none | approval:DEC-ARCH-014 | approval:TECH-LEAD-PLAN-014 |')
  }
  if (-not $MissingWorkItem) {
    $workRows.Add("| $WorkItemId | Implement target conformance | yes | none | 2 | $Acceptance | $TraceIds | $DeliveryAdapter | in-progress | ATTEMPT-$WorkItemId-01 | none | $ApprovalReference |")
    if ($DuplicateWorkItem) {
      $workRows.Add("| $WorkItemId | Duplicate target conformance | yes | none | 3 | $Acceptance | $TraceIds | $DeliveryAdapter | in-progress | ATTEMPT-$WorkItemId-01 | none | $ApprovalReference |")
    }
  }
  else {
    $workRows.Add('| WORK-ADMIN-OTHER | Unrelated approved outcome | yes | none | 2 | REQ-099; SC-099; measurable unrelated outcome | TRACE-099 | none | in-progress | ATTEMPT-WORK-ADMIN-OTHER-01 | none | approval:TECH-LEAD-PLAN-014 |')
  }
  $activeWorkItemId = if ($MissingWorkItem) { 'WORK-ADMIN-OTHER' } else { $WorkItemId }
  $affectedWorkItems = if ($Decomposition -cne 'not-applicable') { "WORK-ADMIN-PARENT, $activeWorkItemId" } else { $activeWorkItemId }
  $revisionApproval = if ([string]::IsNullOrWhiteSpace($RevisionApprovalReference)) { $ApprovalReference } else { $RevisionApprovalReference }
  $dependencyRows = [Collections.Generic.List[string]]::new()
  if ($Decomposition -cne 'not-applicable') {
    $dependencyRows.Add('| WORK-ADMIN-PARENT | none | no-dependency | approval:TECH-LEAD-PLAN-014 |')
  }
  $dependencyRows.Add("| $activeWorkItemId | none | no-dependency | approval:TECH-LEAD-PLAN-014 |")
  $requiredWorkItemCount = if ($Decomposition -cne 'not-applicable') { '2' } else { '1' }
  $terminalWorkItemCount = if ($Decomposition -cne 'not-applicable') { '1' } else { '0' }
  $workItemDelimiter = if ($MalformedWorkDelimiter) {
    '| not | a | canonical | delimiter |'
  }
  elseif ($SingleCellWorkDelimiter) {
    '|---|'
  }
  elseif ($ExtraCellWorkDelimiter) {
    '|---|---|---|---|---|---|---|---|---|---|---|---|---|'
  }
  else {
    '|---|---|---|---|---|---|---|---|---|---|---|---|'
  }
  $decompositionDecision = if ($Decomposition -ceq 'stale') { 'DEC-ARCH-013' } else { 'DEC-ARCH-014' }
  $decompositionParent = if ($Decomposition -ceq 'wrong-parent') { 'WORK-ADMIN-OTHER-PARENT' } else { 'WORK-ADMIN-PARENT' }
  $decompositionRecord = if ($Decomposition -ceq 'missing' -or $Decomposition -ceq 'not-applicable') {
    ''
  }
  else {
@"

decomposition:
  parent_work_item_id: $decompositionParent
  child_work_item_ids:
    - $WorkItemId
  decision_reference: $decompositionDecision
"@
  }
  if ($Decomposition -ceq 'duplicate') {
    $decompositionRecord += $decompositionRecord
  }

  return @"
$frontMatter

# Master plan migration

## Requested Scope

| Kind | ID | Statement | Source | Resolution Evidence |
|---|---|---|---|---|
| module | ADMIN | Migrate the approved admin target | user | master-spec.md#SPEC-ADMIN-001 |

## Work Items

| Work Item ID | Title | Required | Dependencies | Plan Order | Acceptance | Trace IDs | Delivery Adapter | Status | Latest Attempt | Terminal Evidence | Approval Reference |
$workItemDelimiter
$($workRows -join "`n")
$decompositionRecord

## Dependency Graph

| Work Item ID | Dependency Work Item ID | Relationship | Evidence |
|---|---|---|---|
$($dependencyRows -join "`n")

## Attempt History

| Attempt ID | Work Item ID | Plan Revision | Status | Artifact Reference |
|---|---|---|---|---|
| ATTEMPT-$activeWorkItemId-01 | $activeWorkItemId | $Revision | in-progress | attempts/ATTEMPT-$activeWorkItemId-01.md |

## State Transition Log

| Work Item ID | From State | To State | Evidence or Decision | Plan Revision |
|---|---|---|---|---|
| $activeWorkItemId | ready | in-progress | ATTEMPT-$activeWorkItemId-01 | $Revision |

## Scope Completion Calculation

| Required Work Items | Terminal-Success Items | Blockers | Dependency Graph | Architecture Conformance | Selector/Schema | Scope Status |
|---|---|---|---|---|---|---|
| $requiredWorkItemCount | $terminalWorkItemCount | none | valid | PASS | PASS | scope-in-progress |

## Evidence

| Evidence | Location | Notes |
|---|---|---|
| PLAN-EVIDENCE-001 | master-spec.md#SPEC-ADMIN-001 | approved scope evidence |

## Unknowns

| ID | Unknown | Impact | Disposition |
|---|---|---|---|
| none | not-applicable | not-applicable | resolved |

## Approval Record

| Approval Reference | Status | Approved At |
|---|---|---|
| $ApprovalReference | $ApprovalStatus | 2026-08-19 |

## Revision History

| Artifact ID | Revision | Supersedes | Change Summary | Affected Work Items | Approval Reference |
|---|---|---|---|---|---|
| $MasterPlanId | $Revision | $supersedes | Approved target conformance work | $affectedWorkItems | $revisionApproval |
"@
}

function New-FauxMasterPlanArtifact {
  return @"
---
step_id: master-plan
status: approved
revision: 2
produced_at: 2026-08-19
---

# Master Plan

## PLAN-ADMIN-001

| Plan ID | Revision | Status | Work Item ID | Acceptance Traces | Decomposition Decision Reference |
|---|---|---|---|---|---|
| PLAN-ADMIN-001 | 2 | approved | WORK-ADMIN-TARGET | REQ-014, SC-014 | not-applicable |
"@
}

function Invoke-ConformanceCase {
  param(
    [string]$Name,
    [string]$DiscoveryText = '',
    [string]$DesignText = '',
    [bool]$ShouldPass,
    [string]$ExpectedError = '',
    [ValidateSet(
      'approved', 'missing', 'draft', 'stale', 'faux', 'missing-front-matter',
      'wrong-artifact-type', 'wrong-plan-id', 'duplicate-work-item', 'missing-work-item',
      'malformed-work-delimiter', 'single-cell-work-delimiter', 'extra-cell-work-delimiter',
      'wrong-spec-scope', 'invalid-spec-revision', 'stale-acceptance', 'stale-trace',
      'comma-acceptance', 'missing-acceptance-outcome', 'missing-acceptance-trace',
      'malformed-acceptance-reference',
      'stale-adapter', 'stale-approval', 'stale-approval-status', 'stale-revision-approval',
      'decomposition', 'missing-decomposition', 'stale-decomposition',
      'duplicate-decomposition', 'wrong-decomposition-parent', 'unexpected-decomposition'
    )]
    [string]$PlanFixture = 'approved'
  )

  $scenarioRoot = New-ScenarioRoot
  try {
    if (-not [string]::IsNullOrWhiteSpace($DiscoveryText)) {
      Set-Content -Encoding utf8 -LiteralPath (Join-Path $scenarioRoot '02-discovery.md') -Value $DiscoveryText
    }
    if (-not [string]::IsNullOrWhiteSpace($DesignText)) {
      Set-Content -Encoding utf8 -LiteralPath (Join-Path $scenarioRoot '07-technical-design.md') -Value $DesignText
      if ($PlanFixture -cne 'missing') {
        $masterPlanText = switch ($PlanFixture) {
          'draft' { New-MasterPlanArtifact -Status 'draft' }
          'stale' { New-MasterPlanArtifact -Revision '1' }
          'faux' { New-FauxMasterPlanArtifact }
          'missing-front-matter' { New-MasterPlanArtifact -OmitFrontMatter }
          'wrong-artifact-type' { New-MasterPlanArtifact -ArtifactType 'migration-master-spec' }
          'wrong-plan-id' { New-MasterPlanArtifact -MasterPlanId 'PLAN-ADMIN-002' }
          'wrong-spec-scope' { New-MasterPlanArtifact -MasterSpecId 'SPEC-SETTINGS-001' }
          'invalid-spec-revision' { New-MasterPlanArtifact -MasterSpecRevision '0' }
          'duplicate-work-item' { New-MasterPlanArtifact -DuplicateWorkItem }
          'missing-work-item' { New-MasterPlanArtifact -MissingWorkItem }
          'malformed-work-delimiter' { New-MasterPlanArtifact -MalformedWorkDelimiter }
          'single-cell-work-delimiter' { New-MasterPlanArtifact -SingleCellWorkDelimiter }
          'extra-cell-work-delimiter' { New-MasterPlanArtifact -ExtraCellWorkDelimiter }
          'stale-acceptance' { New-MasterPlanArtifact -Acceptance 'REQ-013; SC-013; stale measurable outcome' }
          'stale-trace' { New-MasterPlanArtifact -TraceIds 'TRACE-013' }
          'comma-acceptance' { New-MasterPlanArtifact -Acceptance 'REQ-001, SC-001, measurable outcome' }
          'missing-acceptance-outcome' { New-MasterPlanArtifact -Acceptance 'REQ-001; SC-001' }
          'missing-acceptance-trace' { New-MasterPlanArtifact -Acceptance 'REQ-001; measurable outcome' }
          'malformed-acceptance-reference' { New-MasterPlanArtifact -Acceptance 'REQ--001; SC-001; measurable outcome' }
          'stale-adapter' { New-MasterPlanArtifact -DeliveryAdapter 'task:TASK-ADMIN-013' }
          'stale-approval' { New-MasterPlanArtifact -ApprovalReference 'pending' }
          'stale-approval-status' { New-MasterPlanArtifact -ApprovalStatus 'pending' }
          'stale-revision-approval' { New-MasterPlanArtifact -RevisionApprovalReference 'approval:TECH-LEAD-PLAN-013' }
          'decomposition' { New-MasterPlanArtifact -WorkItemId 'WORK-ADMIN-CHILD' -Decomposition 'approved' }
          'missing-decomposition' { New-MasterPlanArtifact -WorkItemId 'WORK-ADMIN-CHILD' -Decomposition 'missing' }
          'stale-decomposition' { New-MasterPlanArtifact -WorkItemId 'WORK-ADMIN-CHILD' -Decomposition 'stale' }
          'duplicate-decomposition' { New-MasterPlanArtifact -WorkItemId 'WORK-ADMIN-CHILD' -Decomposition 'duplicate' }
          'wrong-decomposition-parent' { New-MasterPlanArtifact -WorkItemId 'WORK-ADMIN-CHILD' -Decomposition 'wrong-parent' }
          'unexpected-decomposition' { New-MasterPlanArtifact -Decomposition 'approved' }
          default { New-MasterPlanArtifact }
        }
        Set-Content -Encoding utf8 -LiteralPath (Join-Path $scenarioRoot 'master-plan.md') -Value $masterPlanText
      }
    }

    $script:errors = [Collections.Generic.List[string]]::new()
    Test-TargetConformance $scenarioRoot $contractText

    if ($ShouldPass -and $script:errors.Count -gt 0) {
      throw "$Name should pass but failed: $($script:errors -join '; ')"
    }
    if (-not $ShouldPass -and $script:errors.Count -eq 0) {
      throw "$Name should fail but passed"
    }
    if (-not $ShouldPass -and -not [string]::IsNullOrWhiteSpace($ExpectedError)) {
      $matchingError = @($script:errors | Where-Object { $_ -match [regex]::Escape($ExpectedError) })
      if ($matchingError.Count -eq 0) {
        throw "$Name did not report '$ExpectedError': $($script:errors -join '; ')"
      }
    }
    Write-Output "PASS: $Name"
  }
  finally {
    if (Test-Path -LiteralPath $scenarioRoot) {
      Remove-Item -LiteralPath $scenarioRoot -Recurse -Force
    }
  }
}

Invoke-ConformanceCase `
  'discovery rejects generic controller-only evidence' `
  (New-DiscoveryArtifact -IncludedConcerns @('controller/provider/state pattern')) `
  '' `
  $false `
  'missing applicable concern'
Invoke-ConformanceCase `
  'discovery rejects one missing concern' `
  (New-DiscoveryArtifact -IncludedConcerns $concerns[0..6]) `
  '' `
  $false `
  'test harness and production-boundary tests'
Invoke-ConformanceCase `
  'discovery rejects an invented extra concern' `
  (New-DiscoveryArtifact -ExtraConcern) `
  '' `
  $false `
  'unexpected concern'
Invoke-ConformanceCase `
  'discovery rejects duplicate concern coverage' `
  (New-DiscoveryArtifact -DuplicateConcern) `
  '' `
  $false `
  'must appear exactly once'
Invoke-ConformanceCase `
  'discovery rejects blank inspected symbols' `
  (New-DiscoveryArtifact -BlankSymbolsConcern 'controller/provider/state pattern') `
  '' `
  $false `
  'Inspected Symbols must not be blank'
Invoke-ConformanceCase `
  'discovery rejects wildcard inspected symbols' `
  (New-DiscoveryArtifact -WildcardSymbols) `
  '' `
  $false `
  'Inspected Symbols must contain only explicit symbol tokens'
Invoke-ConformanceCase `
  'discovery rejects generic terms inside symbol lists' `
  (New-DiscoveryArtifact -GenericSymbolList) `
  '' `
  $false `
  'Inspected Symbols must contain only explicit symbol tokens'
$genericSymbolTokens = @(
  '*', 'all', 'any', 'generic', 'symbol', 'symbols', 'controller', 'controllers',
  'provider', 'providers', 'category', 'categories', 'GenericController',
  'GenericProvider', 'GenericCategory'
)
foreach ($genericSymbolToken in $genericSymbolTokens) {
  Invoke-ConformanceCase `
    "discovery comparable symbols reject isolated generic token $genericSymbolToken" `
    (New-DiscoveryArtifact -ComparableSymbolsOverride $genericSymbolToken) `
    '' `
    $false `
    'Inspected Symbols must contain only explicit symbol tokens'
  Invoke-ConformanceCase `
    "discovery inspected-symbol table rejects isolated generic token $genericSymbolToken" `
    (New-DiscoveryArtifact -InspectedSymbolOverride $genericSymbolToken) `
    '' `
    $false `
    'Inspected Symbols rows require explicit path, symbol, scope, and evidence'
}
Invoke-ConformanceCase `
  'discovery rejects empty inspected-symbol rows' `
  (New-DiscoveryArtifact -EmptyInspectedSymbols) `
  '' `
  $false `
  'Inspected Symbols requires at least one evidence row'
Invoke-ConformanceCase `
  'discovery rejects wrong inspected-symbol columns' `
  ((New-DiscoveryArtifact).Replace(
    '| Concern | Path | Symbol | Inspection Scope | Evidence |',
    '| Path | Concern | Symbol | Inspection Scope | Evidence |'
  )) `
  '' `
  $false `
  'Inspected Symbols table columns must be exactly'
Invoke-ConformanceCase `
  'discovery rejects empty target data-flow rows' `
  (New-DiscoveryArtifact -EmptyDataFlow) `
  '' `
  $false `
  'Target Data-flow Trace requires at least one evidence row'
Invoke-ConformanceCase `
  'discovery rejects meaningless target data-flow endpoints' `
  (New-DiscoveryArtifact -MeaninglessDataFlow) `
  '' `
  $false `
  'Target Data-flow Trace requires meaningful endpoints and evidence'
Invoke-ConformanceCase `
  'discovery rejects a single-provider data-flow citation' `
  (New-DiscoveryArtifact -SingleProviderDataFlow) `
  '' `
  $false `
  'must cover ordered end-to-end stages'
Invoke-ConformanceCase `
  'discovery rejects unstructured transformation prose' `
  (New-DiscoveryArtifact -UnstructuredTransformation) `
  '' `
  $false `
  'requires structured operation and owner evidence'
Invoke-ConformanceCase `
  'discovery rejects a disconnected end-to-end data-flow trace' `
  (New-DiscoveryArtifact -DisconnectedDataFlow) `
  '' `
  $false `
  'must connect each stage output to the next stage input'
Invoke-ConformanceCase `
  'discovery rejects gap rows without no-equivalent status' `
  (New-DiscoveryArtifact -StrayGapRow) `
  '' `
  $false `
  'No-equivalent Gaps must match no-equivalent statuses exactly'
Invoke-ConformanceCase `
  'discovery rejects malformed no-gap sentinel' `
  (New-DiscoveryArtifact -InvalidGapSentinel) `
  '' `
  $false `
  'No-equivalent Gaps sentinel must be canonical'
Invoke-ConformanceCase `
  'discovery rejects a non-comparable reason' `
  (New-DiscoveryArtifact -NotComparableConcern 'localization') `
  '' `
  $false `
  'Comparable Reason must explain comparability'
Invoke-ConformanceCase `
  'discovery rejects unknown exemplar status' `
  (New-DiscoveryArtifact -UnknownConcern 'routing and lifecycle') `
  '' `
  $false `
  'unknown status blocks discovery'
Invoke-ConformanceCase `
  'discovery accepts approved no-equivalent gap' `
  (New-DiscoveryArtifact -NoEquivalentConcern 'localization') `
  '' `
  $true
Invoke-ConformanceCase `
  'discovery rejects placeholder resolved gap decision' `
  (New-DiscoveryArtifact -NoEquivalentConcern 'localization' -WeakGapDecision) `
  '' `
  $false `
  'resolved gap/conflict decision'
Invoke-ConformanceCase `
  'discovery rejects pending gap approval' `
  (New-DiscoveryArtifact -NoEquivalentConcern 'localization' -PendingGapApproval) `
  '' `
  $false `
  'resolved gap/conflict decision'
Invoke-ConformanceCase `
  'discovery rejects pending Tech Lead review hidden in decision' `
  (New-DiscoveryArtifact -NoEquivalentConcern 'localization' -GapDecisionOverride 'resolved:DECISION-099: pending Tech Lead review') `
  '' `
  $false `
  'resolved gap/conflict decision'
Invoke-ConformanceCase `
  'discovery rejects placeholder inside canonical-looking approval' `
  (New-DiscoveryArtifact -NoEquivalentConcern 'localization' -GapApprovalOverride 'approval:TECH-LEAD-PENDING') `
  '' `
  $false `
  'resolved gap/conflict decision'
Invoke-ConformanceCase `
  'discovery accepts complete eight-concern evidence' `
  (New-DiscoveryArtifact) `
  '' `
  $true

Invoke-ConformanceCase `
  'design accepts canonical Acceptance references plus measurable outcome prose' `
  '' `
  (New-DesignArtifact) `
  $true
Invoke-ConformanceCase `
  'design accepts comma-separated canonical Acceptance references plus measurable outcome prose' `
  '' `
  (New-DesignArtifact -Acceptance 'REQ-001, SC-001, measurable outcome' -BindApprovedPlanToTrace) `
  $true `
  '' `
  'comma-acceptance'
Invoke-ConformanceCase `
  'design rejects vague Riverpod guidance' `
  '' `
  (New-DesignArtifact -VagueConcern 'controller/provider/state pattern') `
  $false `
  'requires structured concrete pattern evidence'
Invoke-ConformanceCase `
  'design rejects vague state-management variant' `
  '' `
  (New-DesignArtifact -VagueConcern 'controller/provider/state pattern' -VagueValue 'Adopt state management provider pattern') `
  $false `
  'requires structured concrete pattern evidence'
Invoke-ConformanceCase `
  'design rejects vague clean-architecture variant' `
  '' `
  (New-DesignArtifact -VagueConcern 'controller/provider/state pattern' -VagueValue 'Follow Clean Architecture with state management') `
  $false `
  'requires structured concrete pattern evidence'
Invoke-ConformanceCase `
  'design rejects MVVM phrase despite a concrete proposed path' `
  '' `
  (New-DesignArtifact -VagueConcern 'controller/provider/state pattern' -VagueValue 'Adopt MVVM' -VagueObservedOnly) `
  $false `
  'requires structured concrete pattern evidence'
Invoke-ConformanceCase `
  'design rejects an invented extra concern' `
  '' `
  (New-DesignArtifact -ExtraConcern) `
  $false `
  'unexpected concern'
Invoke-ConformanceCase `
  'design rejects duplicate concern coverage' `
  '' `
  (New-DesignArtifact -DuplicateConcern) `
  $false `
  'must appear exactly once'
foreach ($genericSymbolToken in $genericSymbolTokens) {
  Invoke-ConformanceCase `
    "design observed symbols reject isolated generic token $genericSymbolToken" `
    '' `
    (New-DesignArtifact -ObservedSymbolsOverride $genericSymbolToken) `
    $false `
    'requires structured concrete pattern evidence'
}
Invoke-ConformanceCase `
  'design accepts Windows separators normalized against planned paths' `
  '' `
  (New-DesignArtifact -WindowsProposedPaths) `
  $true
Invoke-ConformanceCase `
  'design accepts root files and qualified symbols' `
  '' `
  (New-DesignArtifact -RootProposedPaths) `
  $true
Invoke-ConformanceCase `
  'design rejects traversal in proposed paths' `
  '' `
  (New-DesignArtifact -TraversalProposedPath) `
  $false `
  'rejects traversal or malformed path/symbol'
Invoke-ConformanceCase `
  'design rejects malformed proposed path/symbol' `
  '' `
  (New-DesignArtifact -MalformedProposedPath) `
  $false `
  'rejects traversal or malformed path/symbol'
Invoke-ConformanceCase `
  'design rejects missing planned file tree' `
  '' `
  (New-DesignArtifact -OmitPlannedTree) `
  $false `
  'missing Planned File Tree'
Invoke-ConformanceCase `
  'design rejects missing work-item trace' `
  '' `
  (New-DesignArtifact -OmitWorkItemTrace) `
  $false `
  'missing Work Item Trace'
Invoke-ConformanceCase `
  'design rejects missing approved master-plan evidence' `
  '' `
  (New-DesignArtifact -OmitApprovedPlanEvidence) `
  $false `
  'missing Approved Master Plan Evidence'
Invoke-ConformanceCase `
  'design rejects a coherent fake work-item tuple' `
  '' `
  (New-DesignArtifact -WorkItemId 'WORK-FAKE-TARGET' -MasterPlanReference 'master-plan.md#PLAN-FAKE-001') `
  $false `
  'must match approved master-plan evidence exactly'
Invoke-ConformanceCase `
  'design rejects a coherent local snapshot and trace forgery against the external plan' `
  '' `
  (New-DesignArtifact -ForgeApprovedPlanAndTrace) `
  $false `
  'must resolve the cited external approved master plan'
Invoke-ConformanceCase `
  'design rejects a missing external master-plan artifact' `
  '' `
  (New-DesignArtifact) `
  $false `
  'must resolve the cited external approved master plan' `
  'missing'
Invoke-ConformanceCase `
  'design rejects a draft external master plan' `
  '' `
  (New-DesignArtifact) `
  $false `
  'must resolve the cited external approved master plan' `
  'draft'
Invoke-ConformanceCase `
  'design rejects a stale external master-plan revision' `
  '' `
  (New-DesignArtifact) `
  $false `
  'must resolve the cited external approved master plan' `
  'stale'
Invoke-ConformanceCase `
  'design rejects the former faux master-plan shape' `
  '' `
  (New-DesignArtifact) `
  $false `
  'must resolve the cited external approved master plan' `
  'faux'
Invoke-ConformanceCase `
  'design rejects an external plan missing canonical front matter' `
  '' `
  (New-DesignArtifact) `
  $false `
  'must resolve the cited external approved master plan' `
  'missing-front-matter'
Invoke-ConformanceCase `
  'design rejects the wrong external artifact type' `
  '' `
  (New-DesignArtifact) `
  $false `
  'must resolve the cited external approved master plan' `
  'wrong-artifact-type'
Invoke-ConformanceCase `
  'design rejects an external front-matter plan ID mismatch' `
  '' `
  (New-DesignArtifact) `
  $false `
  'must resolve the cited external approved master plan' `
  'wrong-plan-id'
Invoke-ConformanceCase `
  'design rejects an external linked-spec scope mismatch' `
  '' `
  (New-DesignArtifact) `
  $false `
  'must resolve the cited external approved master plan' `
  'wrong-spec-scope'
Invoke-ConformanceCase `
  'design rejects a nonpositive linked-spec revision' `
  '' `
  (New-DesignArtifact) `
  $false `
  'must resolve the cited external approved master plan' `
  'invalid-spec-revision'
Invoke-ConformanceCase `
  'design rejects a duplicate cited canonical work item' `
  '' `
  (New-DesignArtifact) `
  $false `
  'must resolve the cited external approved master plan' `
  'duplicate-work-item'
Invoke-ConformanceCase `
  'design rejects a missing cited canonical work item' `
  '' `
  (New-DesignArtifact) `
  $false `
  'must resolve the cited external approved master plan' `
  'missing-work-item'
Invoke-ConformanceCase `
  'design rejects a malformed canonical Work Items delimiter' `
  '' `
  (New-DesignArtifact) `
  $false `
  'must resolve the cited external approved master plan' `
  'malformed-work-delimiter'
Invoke-ConformanceCase `
  'design rejects a one-cell delimiter under a canonical twelve-cell Work Items header and row' `
  '' `
  (New-DesignArtifact) `
  $false `
  'must resolve the cited external approved master plan' `
  'single-cell-work-delimiter'
Invoke-ConformanceCase `
  'design rejects a Work Items delimiter with an extra cell' `
  '' `
  (New-DesignArtifact) `
  $false `
  'must resolve the cited external approved master plan' `
  'extra-cell-work-delimiter'
Invoke-ConformanceCase `
  'design rejects canonical Acceptance without measurable outcome prose' `
  '' `
  (New-DesignArtifact -Acceptance 'REQ-001; SC-001' -BindApprovedPlanToTrace) `
  $false `
  'must resolve the cited external approved master plan' `
  'missing-acceptance-outcome'
Invoke-ConformanceCase `
  'design rejects canonical Acceptance without a success-criterion trace' `
  '' `
  (New-DesignArtifact -Acceptance 'REQ-001; measurable outcome' -AcceptanceTraces 'REQ-001' -BindApprovedPlanToTrace) `
  $false `
  'must resolve the cited external approved master plan' `
  'missing-acceptance-trace'
Invoke-ConformanceCase `
  'design rejects malformed canonical Acceptance references' `
  '' `
  (New-DesignArtifact -Acceptance 'REQ--001; SC-001; measurable outcome' -AcceptanceTraces 'REQ--001, SC-001' -BindApprovedPlanToTrace) `
  $false `
  'must resolve the cited external approved master plan' `
  'malformed-acceptance-reference'
Invoke-ConformanceCase `
  'design rejects Acceptance Traces missing a canonical required reference' `
  '' `
  (New-DesignArtifact -AcceptanceTraces 'REQ-001') `
  $false `
  'must match approved master-plan evidence exactly'
Invoke-ConformanceCase `
  'design rejects stale canonical work-item acceptance' `
  '' `
  (New-DesignArtifact) `
  $false `
  'must resolve the cited external approved master plan' `
  'stale-acceptance'
Invoke-ConformanceCase `
  'design rejects stale canonical work-item trace IDs' `
  '' `
  (New-DesignArtifact) `
  $false `
  'must resolve the cited external approved master plan' `
  'stale-trace'
Invoke-ConformanceCase `
  'design rejects stale canonical work-item delivery adapter' `
  '' `
  (New-DesignArtifact) `
  $false `
  'must resolve the cited external approved master plan' `
  'stale-adapter'
Invoke-ConformanceCase `
  'design rejects a work item without current plan approval' `
  '' `
  (New-DesignArtifact) `
  $false `
  'must resolve the cited external approved master plan' `
  'stale-approval'
Invoke-ConformanceCase `
  'design rejects a non-approved current approval record' `
  '' `
  (New-DesignArtifact) `
  $false `
  'must resolve the cited external approved master plan' `
  'stale-approval-status'
Invoke-ConformanceCase `
  'design rejects a stale current revision approval' `
  '' `
  (New-DesignArtifact) `
  $false `
  'must resolve the cited external approved master plan' `
  'stale-revision-approval'
Invoke-ConformanceCase `
  'design accepts an approved canonical child decomposition' `
  '' `
  (New-DesignArtifact -WorkItemId 'WORK-ADMIN-CHILD' -DecompositionReference 'DEC-ARCH-014' -BindApprovedPlanToTrace) `
  $true `
  '' `
  'decomposition'
foreach ($decompositionFixture in @(
  'missing-decomposition',
  'stale-decomposition',
  'duplicate-decomposition',
  'wrong-decomposition-parent'
)) {
  Invoke-ConformanceCase `
    "design rejects $decompositionFixture for a canonical child" `
    '' `
    (New-DesignArtifact -WorkItemId 'WORK-ADMIN-CHILD' -DecompositionReference 'DEC-ARCH-014' -BindApprovedPlanToTrace) `
    $false `
    'must resolve the cited external approved master plan' `
    $decompositionFixture
}
Invoke-ConformanceCase `
  'design rejects a decomposition when trace uses not-applicable' `
  '' `
  (New-DesignArtifact) `
  $false `
  'must resolve the cited external approved master plan' `
  'unexpected-decomposition'
Invoke-ConformanceCase `
  'design rejects missing master-plan revision' `
  '' `
  (New-DesignArtifact -MasterPlanRevision '') `
  $false `
  'positive master-plan revision'
Invoke-ConformanceCase `
  'design rejects duplicate acceptance traces' `
  '' `
  (New-DesignArtifact -AcceptanceTraces 'REQ-014, REQ-014') `
  $false `
  'requires only canonical acceptance trace IDs'
Invoke-ConformanceCase `
  'design rejects placeholder decomposition reference' `
  '' `
  (New-DesignArtifact -DecompositionReference 'DEC-PENDING') `
  $false `
  'decomposition decision reference or not-applicable'
Invoke-ConformanceCase `
  'design rejects noncanonical master-plan reference' `
  '' `
  (New-DesignArtifact -MasterPlanReference 'notes.md#PLAN-ADMIN-001') `
  $false `
  'canonical master-plan reference'
Invoke-ConformanceCase `
  'design rejects cross-scope work-item and master-plan binding' `
  '' `
  (New-DesignArtifact -MasterPlanReference 'master-plan.md#PLAN-SETTINGS-001') `
  $false `
  'must bind the same scope'
Invoke-ConformanceCase `
  'design rejects malformed acceptance trace tokens' `
  '' `
  (New-DesignArtifact -AcceptanceTraces 'REQ-014, garbage, SC-014') `
  $false `
  'requires only canonical acceptance trace IDs'
Invoke-ConformanceCase `
  'design rejects malformed canonical-like acceptance IDs' `
  '' `
  (New-DesignArtifact -AcceptanceTraces 'REQ--014, SC-014') `
  $false `
  'requires only canonical acceptance trace IDs'
Invoke-ConformanceCase `
  'design rejects unresolved structural deviation' `
  '' `
  (New-DesignArtifact -NonConformingConcern 'main/child presentation boundaries') `
  $false `
  'requires a resolved decision and Tech Lead approval'
Invoke-ConformanceCase `
  'design accepts approved structural deviation' `
  '' `
  (New-DesignArtifact -NonConformingConcern 'main/child presentation boundaries' -ResolveDeviation) `
  $true
Invoke-ConformanceCase `
  'design rejects placeholder resolved deviation decision' `
  '' `
  (New-DesignArtifact -NonConformingConcern 'main/child presentation boundaries' -ResolveDeviation -WeakDeviationDecision) `
  $false `
  'resolved decision and Tech Lead approval'
Invoke-ConformanceCase `
  'design rejects pending deviation approval' `
  '' `
  (New-DesignArtifact -NonConformingConcern 'main/child presentation boundaries' -ResolveDeviation -PendingDeviationApproval) `
  $false `
  'resolved decision and Tech Lead approval'
Invoke-ConformanceCase `
  'design rejects review placeholder hidden in deviation decision' `
  '' `
  (New-DesignArtifact -NonConformingConcern 'main/child presentation boundaries' -ResolveDeviation -DeviationDecisionOverride 'resolved:DECISION-099: pending architecture review') `
  $false `
  'resolved decision and Tech Lead approval'
Invoke-ConformanceCase `
  'design rejects placeholder inside canonical-looking Tech Lead approval' `
  '' `
  (New-DesignArtifact -NonConformingConcern 'main/child presentation boundaries' -ResolveDeviation -DeviationApprovalOverride 'approval:TECH-LEAD-PENDING') `
  $false `
  'resolved decision and Tech Lead approval'
Invoke-ConformanceCase `
  'design rejects panel-wrapper mismatch' `
  '' `
  (New-DesignArtifact -PanelWrapperMismatch) `
  $false `
  'panel wrapper does not conform'
Invoke-ConformanceCase `
  'design rejects a qualified panel-wrapper mismatch' `
  '' `
  (New-DesignArtifact -ObservedWrapperOverride 'App.TargetPanel' -ProposedWrapperOverride 'App.OtherPanel') `
  $false `
  'panel wrapper does not conform'
Invoke-ConformanceCase `
  'design accepts an exact qualified panel-wrapper match' `
  '' `
  (New-DesignArtifact -ObservedWrapperOverride 'App.TargetPanel' -ProposedWrapperOverride 'App.TargetPanel') `
  $true
Invoke-ConformanceCase `
  'design rejects missing proposed panel wrapper' `
  '' `
  (New-DesignArtifact -OmitProposedWrapper) `
  $false `
  'proposed panel wrapper is required'
Invoke-ConformanceCase `
  'design rejects missing observed panel wrapper' `
  '' `
  (New-DesignArtifact -OmitObservedWrapper) `
  $false `
  'observed panel wrapper is required'
Invoke-ConformanceCase `
  'design rejects missing observed wrapper on deviating row' `
  '' `
  (New-DesignArtifact -NonConformingConcern 'main/child presentation boundaries' -ResolveDeviation -OmitObservedWrapper) `
  $false `
  'observed panel wrapper is required'
Invoke-ConformanceCase `
  'design rejects missing proposed wrapper on deviating row' `
  '' `
  (New-DesignArtifact -NonConformingConcern 'main/child presentation boundaries' -ResolveDeviation -OmitProposedWrapper) `
  $false `
  'proposed panel wrapper is required'
Invoke-ConformanceCase `
  'design accepts approved panel-wrapper deviation' `
  '' `
  (New-DesignArtifact -NonConformingConcern 'main/child presentation boundaries' -PanelWrapperMismatch -ResolveDeviation) `
  $true
Invoke-ConformanceCase `
  'design rejects planned tree missing a matrix path' `
  '' `
  (New-DesignArtifact -OmitPlannedMatrixPath) `
  $false `
  'Planned File Tree path set must exactly match matrix proposed paths'
Invoke-ConformanceCase `
  'design rejects unrelated planned tree path' `
  '' `
  (New-DesignArtifact -AddUnrelatedPlannedPath) `
  $false `
  'Planned File Tree path set must exactly match matrix proposed paths'
Invoke-ConformanceCase `
  'design rejects missing lifecycle boundary' `
  '' `
  (New-DesignArtifact -OmitLifecycleBoundary) `
  $false `
  'missing required boundary: lifecycle'
Invoke-ConformanceCase `
  'design accepts complete conforming evidence' `
  '' `
  (New-DesignArtifact) `
  $true

Write-Output 'PASS: target conformance scenarios'

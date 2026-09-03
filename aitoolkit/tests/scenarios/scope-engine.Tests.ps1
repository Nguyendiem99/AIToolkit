param()

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$OutputEncoding = [Console]::OutputEncoding

$toolkitRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$validatorPath = Join-Path $toolkitRoot 'tests/validation/scope-engine.validation.ps1'
$failures = [Collections.Generic.List[string]]::new()
$script:errors = [Collections.Generic.List[string]]::new()

function Require-Token([string]$Text, [string]$Token, [string]$Context) {
  if ($Text -notmatch [regex]::Escape($Token)) {
    $script:errors.Add("$Context missing: $Token")
  }
}

function Assert-Equal([object]$Actual, [object]$Expected, [string]$Message) {
  if ([string]$Actual -cne [string]$Expected) {
    $failures.Add("$Message (expected='$Expected', actual='$Actual')")
  }
}

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { $failures.Add($Message) }
}

function Replace-RawScopeJsonExactOrFail([string]$Text, [string]$From, [string]$To, [string]$Name) {
  $matchCount = @([regex]::Matches($Text, [regex]::Escape($From))).Count
  if ($matchCount -ne 1) {
    throw "$Name raw JSON anchor must appear exactly once; found $matchCount"
  }
  return $Text.Replace($From, $To)
}

function Invoke-RawScopeScenario([string]$Json) {
  return Test-ScopeEngine $toolkitRoot $Json
}

function Invoke-ScopeScenario([hashtable]$Fixture) {
  $generatedContext = $false
  if (
    @('select', 'transition', 'complete-scope') -ccontains [string]$Fixture.operation -and
    -not $Fixture.ContainsKey('orchestration_context')
  ) {
    $Fixture.orchestration_context = New-ApprovedOrchestrationContext
    $generatedContext = $true
  }
  if (
    @('select', 'transition', 'complete-scope') -ccontains [string]$Fixture.operation -and
    -not $Fixture.ContainsKey('current_plan_revision')
  ) {
    $Fixture.current_plan_revision = [int]$Fixture.orchestration_context.current_plan_revision
  }
  if ($generatedContext) {
    $currentPlan = @($Fixture.orchestration_context.plan_revisions | Where-Object {
      [int]$_.revision -eq [int]$Fixture.orchestration_context.current_plan_revision
    })[0]
    $currentPlan.work_items = @($Fixture.work_items)
    $currentPlan.delivery_adapter_selections = @($Fixture.work_items | ForEach-Object { New-PlannedAdapterSelection $_ })
    $currentPlan.responsibility_owner_references = @($Fixture.work_items | ForEach-Object { New-PlannedResponsibilityOwnerReference $_ })
    $resolvedArtifacts = [Collections.Generic.List[object]]::new()
    foreach ($item in @($Fixture.work_items)) {
      foreach ($attempt in @($item.attempt_history)) {
        $suppliedTerminalArtifacts = @()
        if ($Fixture.ContainsKey('terminal_artifact')) { $suppliedTerminalArtifacts += @($Fixture.terminal_artifact) }
        if ($Fixture.ContainsKey('terminal_artifacts')) { $suppliedTerminalArtifacts += @($Fixture.terminal_artifacts) }
        if (@($suppliedTerminalArtifacts | Where-Object { [string]$_.artifact_reference -ceq [string]$attempt.artifact_reference }).Count -eq 1) {
          continue
        }
        $resolvedArtifacts.Add(@{
          artifact_reference = [string]$attempt.artifact_reference
          attempt_id = [string]$attempt.attempt_id
          work_item_id = [string]$attempt.work_item_id
          plan_revision = [int]$attempt.plan_revision
          status = [string]$attempt.status
          immutable = $true
        })
      }
    }
    foreach ($artifactField in @('terminal_artifact', 'blocker_artifact', 'decision_artifact')) {
      if ($Fixture.ContainsKey($artifactField)) { $resolvedArtifacts.Add($Fixture[$artifactField]) }
    }
    foreach ($artifactListField in @('terminal_artifacts', 'responsibility_evidence_artifacts', 'responsibility_chain_artifacts', 'planned_design_artifacts')) {
      if ($Fixture.ContainsKey($artifactListField)) {
        foreach ($artifact in @($Fixture[$artifactListField])) { $resolvedArtifacts.Add($artifact) }
      }
    }
    if ($Fixture.ContainsKey('terminal_scope_report')) {
      $Fixture.terminal_scope_report_ref = [string]$Fixture.terminal_scope_report.artifact_reference
      $resolvedArtifacts.Add($Fixture.terminal_scope_report)
    }
    foreach ($item in @($Fixture.work_items)) {
      if ([bool]$item.test_omit_planned_authority) { continue }
      $designReference = "runs/technical-design-$([string]$item.work_item_id).md"
      if (@($resolvedArtifacts | Where-Object { [string]$_.artifact_reference -ceq $designReference }).Count -eq 0) {
        $resolvedArtifacts.Add((New-PlannedResponsibilityDesignArtifact $item))
      }
    }
    $Fixture.orchestration_context.resolved_artifacts = @($resolvedArtifacts)
  }
  if (@('select', 'transition', 'complete-scope') -ccontains [string]$Fixture.operation) {
    $currentPlan = @($Fixture.orchestration_context.plan_revisions | Where-Object {
      [int]$_.revision -eq [int]$Fixture.orchestration_context.current_plan_revision
    })[0]
    if ($null -eq $currentPlan.PSObject.Properties['delivery_adapter_selections']) {
      $currentPlan | Add-Member -NotePropertyName delivery_adapter_selections -NotePropertyValue @($currentPlan.work_items | ForEach-Object { New-PlannedAdapterSelection $_ })
    }
    if ($null -eq $currentPlan.PSObject.Properties['responsibility_owner_references']) {
      $currentPlan | Add-Member -NotePropertyName responsibility_owner_references -NotePropertyValue @($currentPlan.work_items | ForEach-Object { New-PlannedResponsibilityOwnerReference $_ })
    }
    $resolvedArtifacts = [Collections.Generic.List[object]]::new()
    foreach ($artifact in @($Fixture.orchestration_context.resolved_artifacts)) { $resolvedArtifacts.Add($artifact) }
    foreach ($item in @($currentPlan.work_items)) {
      if ([bool]$item.test_omit_planned_authority) { continue }
      $designReference = "runs/technical-design-$([string]$item.work_item_id).md"
      if (@($resolvedArtifacts | Where-Object { [string]$_.artifact_reference -ceq $designReference }).Count -eq 0) {
        $resolvedArtifacts.Add((New-PlannedResponsibilityDesignArtifact $item))
      }
    }
    $Fixture.orchestration_context.resolved_artifacts = @($resolvedArtifacts)
  }
  $json = $Fixture | ConvertTo-Json -Depth 20 -Compress
  return Test-ScopeEngine $toolkitRoot $json
}

function New-ApprovedOrchestrationContext {
  return @{
    requested_scope = @{
      kind = 'module'
      id = 'ADMIN'
      statement = 'Migrate the complete Admin module'
      source = 'user'
      resolution_evidence = 'conversation:scope-approved'
    }
    master_spec_id = 'SPEC-ADMIN-001'
    master_plan_id = 'PLAN-ADMIN-001'
    run_id = 'RUN-ADMIN-001'
    master_spec_ref = 'runs/master-spec@2.md'
    master_plan_ref = 'runs/master-plan@3.md'
    latest_spec_revision = 2
    spec_revisions = @(
      @{ artifact_id = 'SPEC-ADMIN-001'; revision = 1; supersedes = 'not-applicable'; status = 'approved'; result = 'complete'; approval_reference = 'approval:spec@1'; freshness_evidence = 'review:spec@1'; stale = $false },
      @{ artifact_reference = 'runs/master-spec@2.md'; artifact_type = 'migration-master-spec'; artifact_id = 'SPEC-ADMIN-001'; revision = 2; supersedes = 'SPEC-ADMIN-001@1'; immutable = $true; status = 'approved'; result = 'complete'; approval_reference = 'approval:spec@2'; freshness_evidence = 'review:spec@2'; stale = $false }
    )
    current_plan_revision = 3
    plan_revisions = @(
      @{ artifact_id = 'PLAN-ADMIN-001'; revision = 1; supersedes = 'not-applicable'; status = 'approved'; result = 'complete'; approval_reference = 'approval:plan@1'; freshness_evidence = 'review:plan@1'; master_spec_id = 'SPEC-ADMIN-001'; master_spec_revision = 1; stale = $false },
      @{ artifact_id = 'PLAN-ADMIN-001'; revision = 2; supersedes = 'PLAN-ADMIN-001@1'; status = 'approved'; result = 'complete'; approval_reference = 'approval:plan@2'; freshness_evidence = 'review:plan@2'; master_spec_id = 'SPEC-ADMIN-001'; master_spec_revision = 2; stale = $false },
      @{ artifact_reference = 'runs/master-plan@3.md'; artifact_type = 'migration-master-plan'; artifact_id = 'PLAN-ADMIN-001'; revision = 3; supersedes = 'PLAN-ADMIN-001@2'; immutable = $true; status = 'approved'; result = 'complete'; approval_reference = 'approval:plan@3'; freshness_evidence = 'review:plan@3'; master_spec_ref = 'runs/master-spec@2.md'; master_spec_id = 'SPEC-ADMIN-001'; master_spec_revision = 2; stale = $false; responsibility_contract = [ordered]@{ version = 1; applicability = 'required' }; work_items = @() }
    )
  }
}

function New-WorkItem(
  [string]$Id,
  [int]$PlanOrder,
  [string[]]$Dependencies = @(),
  [string]$Status = 'ready',
  [bool]$Required = $true
) {
  return @{
    work_item_id = $Id
    required = $Required
    optional_execution_approved = $false
    dependencies = $Dependencies
    plan_order = $PlanOrder
    status = $Status
    approval_revision = 3
    has_blocker = $false
    adapter_kind = 'none'
    adapter_valid = $true
    tree_conformance = 'PASS'
    responsibility_conformance = 'PASS'
    verification_ownership = 'PASS'
    architecture_state = 'PASS'
    selector_schema_state = 'PASS'
    mode_constraint = 'incremental/preserve-existing'
    acceptance = 'REQ-001; SC-001; completes within 2 seconds'
    trace_ids = @('REQ-001')
    terminal_evidence = 'none'
    latest_attempt = 'none'
    attempt_history = @()
  }
}

function New-PlannedAdapterSelection([object]$Item) {
  $externalId = if ([string]$Item.adapter_kind -ceq 'none') { 'not-applicable' } else { [string]$Item.external_id }
  $authority = if ([string]$Item.adapter_kind -ceq 'none') { 'not-applicable' } else { "authority:$([string]$Item.work_item_id)" }
  $authorityRevision = if ([string]$Item.adapter_kind -ceq 'none') { 'not-applicable' } else { '1' }
  $approvalReference = if ([string]$Item.adapter_kind -ceq 'none') { 'not-applicable' } else { "approval:$([string]$Item.work_item_id)" }
  return @{
    work_item_id = [string]$Item.work_item_id
    adapter_kind = [string]$Item.adapter_kind
    external_id = $externalId
    authority = $authority
    authority_revision = $authorityRevision
    approval_reference = $approvalReference
    parent_selector = 'not-applicable'
    acceptance = [string]$Item.acceptance
    trace_ids = @($Item.trace_ids)
    mode_constraint = [string]$Item.mode_constraint
    design_revision = 'DESIGN-ADMIN@2'
    parent_work_item_id = 'not-applicable'
    decomposition_decision_reference = 'not-applicable'
  }
}

function New-PlannedResponsibilityOwnerReference([object]$Item) {
  return @{
    work_item_id = [string]$Item.work_item_id
    design_revision = 'DESIGN-ADMIN@2'
    responsibility_ids = @("RESP-$([string]$Item.work_item_id)")
    shared_foundation_ids = @('not-applicable')
    integration_responsibility_ids = @('not-applicable')
    independent_boundary_evidence = "approval:OWNER-$([string]$Item.work_item_id): independently implementable, reviewable, verifiable, and revertible"
  }
}

function New-PlannedResponsibilityRow(
  [object]$Item,
  [string]$ResponsibilityId = '',
  [string]$VerificationOwnerId = ''
) {
  if ($ResponsibilityId -ceq '') { $ResponsibilityId = "RESP-$([string]$Item.work_item_id)" }
  if ($VerificationOwnerId -ceq '') { $VerificationOwnerId = "VERIFY-OWNER-$([string]$Item.work_item_id)" }
  $ownerPath = "src/responsibilities/$($ResponsibilityId.ToLowerInvariant()).ps1"
  $ownerSymbol = "Invoke$($ResponsibilityId -replace '[^A-Za-z0-9]', '')"
  $greenfield = [string]$Item.mode_constraint -ceq 'greenfield/design-new'
  return [ordered]@{
    responsibility_id = $ResponsibilityId
    owner_path = $ownerPath
    owner_symbol = $ownerSymbol
    boundary_kind = 'application'
    primary_responsibility = "Own $ResponsibilityId behavior"
    owned_capability_ids = @("CAP-$($ResponsibilityId.Substring(5))")
    trace_ids = @($Item.trace_ids)
    atomic_boundary_id = 'not-applicable'
    public_symbols = @($ownerSymbol)
    external_effects = @('none')
    target_exemplar = if ($greenfield) { 'no-equivalent' } else { "src/exemplars/$($ResponsibilityId.ToLowerInvariant()).ps1#InvokeApprovedExemplar" }
    exemplar_classification = if ($greenfield) { 'no-equivalent' } else { 'preferred' }
    classification_authority = 'factual-discovery-evidence'
    classification_evidence = if ($greenfield) {
      "search:evidence/$($ResponsibilityId.ToLowerInvariant()).json#query=$($ResponsibilityId.ToLowerInvariant()),result=0"
    } else {
      "inspection:${ownerPath}:1-40; working-evidence:tests/responsibilities/$($ResponsibilityId.ToLowerInvariant()).Tests.ps1:1-40"
    }
    architecture_authority = if ($greenfield) { 'approved-greenfield-design' } else { 'target-exemplar' }
    co_location_policy = 'feature-local'
    co_location_evidence = "design-boundary:$ResponsibilityId"
    verification_owner_references = @($VerificationOwnerId)
    conformance = 'yes'
    deviation_reference = 'not-applicable'
  }
}

function New-PlannedVerificationRow(
  [object]$Item,
  [string]$ResponsibilityId = '',
  [string]$VerificationOwnerId = ''
) {
  if ($ResponsibilityId -ceq '') { $ResponsibilityId = "RESP-$([string]$Item.work_item_id)" }
  if ($VerificationOwnerId -ceq '') { $VerificationOwnerId = "VERIFY-OWNER-$([string]$Item.work_item_id)" }
  $ownerPath = "src/responsibilities/$($ResponsibilityId.ToLowerInvariant()).ps1"
  $ownerSymbol = "Invoke$($ResponsibilityId -replace '[^A-Za-z0-9]', '')"
  return [ordered]@{
    verification_owner_id = $VerificationOwnerId
    production_responsibility_id = $ResponsibilityId
    capability_id = "CAP-$($ResponsibilityId.Substring(5))"
    evidence_path = "tests/responsibilities/$($ResponsibilityId.ToLowerInvariant()).Tests.ps1"
    evidence_symbol_or_scenario = "verifies-$($ResponsibilityId.ToLowerInvariant())"
    evidence_kind = 'unit'
    verification_disposition = 'required'
    production_binding_evidence = "source:$ownerPath#$ownerSymbol"
    decision_reference = 'not-applicable'
    verdict = 'PASS'
    deviation_reference = 'not-applicable'
  }
}

function New-PlannedResponsibilityDesignArtifact([object]$Item) {
  return @{
    artifact_reference = "runs/technical-design-$([string]$Item.work_item_id).md"
    step_id = '07-technical-design'
    immutable = $true
    status = 'approved'
    result = 'complete'
    approval_source = 'human'
    run_id = 'RUN-ADMIN-001'
    master_spec_ref = 'runs/master-spec@2.md'
    master_spec_id = 'SPEC-ADMIN-001'
    master_spec_revision = 2
    master_plan_ref = 'runs/master-plan@3.md'
    master_plan_id = 'PLAN-ADMIN-001'
    master_plan_revision = 3
    work_item_id = [string]$Item.work_item_id
    revision = 'DESIGN-ADMIN@2'
    mode_constraint = [string]$Item.mode_constraint
    responsibility_contract = @{ version = 1; applicability = 'required' }
    approved_deviation_rows = @()
    responsibility_rows = @(New-PlannedResponsibilityRow -Item $Item)
    verification_rows = @(New-PlannedVerificationRow -Item $Item)
  }
}

function New-PlannedResponsibilityContext([object[]]$Items) {
  $context = New-ApprovedOrchestrationContext
  $currentPlan = $context.plan_revisions[2]
  $currentPlan.work_items = @($Items)
  $currentPlan.delivery_adapter_selections = @($Items | ForEach-Object { New-PlannedAdapterSelection $_ })
  $currentPlan.responsibility_owner_references = @($Items | ForEach-Object { New-PlannedResponsibilityOwnerReference $_ })
  $context.resolved_artifacts = @($Items | ForEach-Object { New-PlannedResponsibilityDesignArtifact $_ })
  return $context
}

function New-ResponsibilityEvidenceArtifact([string]$Reference, [string]$WorkItemId) {
  return @{
    artifact_reference = $Reference
    artifact_type = 'architecture-responsibility-review'
    immutable = $true
    work_item_id = $WorkItemId
    responsibility_contract_version = 1
    tree_conformance = 'PASS'
    responsibility_conformance = 'PASS'
    verification_ownership = 'PASS'
    architecture_state = 'PASS'
    evidence_reference = "source-diff:$WorkItemId"
  }
}

function New-ResponsibilityChain([string]$Prefix, [string]$WorkItemId, [string]$ModeConstraint = 'incremental/preserve-existing') {
  $steps = if ($ModeConstraint -ceq 'greenfield/design-new') {
    @('11-ai-review', '12-verification-testing', '13-verify-parity', '15-knowledge-base')
  }
  else {
    @('11-ai-review', '12-verification-testing', '13-verify-parity', '14-verify-regression', '15-knowledge-base')
  }
  $artifacts = [Collections.Generic.List[object]]::new()
  $references = [Collections.Generic.List[string]]::new()
  $previousReference = 'implementation-report.md'
  foreach ($step in $steps) {
    $reference = "$Prefix-$step.md"
    $artifact = @{
      artifact_reference = $reference
      artifact_type = 'migration-responsibility-handoff'
      immutable = $true
      run_id = 'RUN-ADMIN-001'
      master_spec_ref = 'runs/master-spec@2.md'
      master_spec_id = 'SPEC-ADMIN-001'
      master_spec_revision = 2
      master_plan_ref = 'runs/master-plan@3.md'
      master_plan_id = 'PLAN-ADMIN-001'
      master_plan_revision = 3
      work_item_id = $WorkItemId
      mode_constraint = $ModeConstraint
      step_id = $step
      status = 'approved'
      result = 'complete'
      approval_source = 'human'
      source_artifact_reference = $previousReference
      responsibility_contract_version = 1
      tree_conformance = 'PASS'
      responsibility_conformance = 'PASS'
      verification_ownership = 'PASS'
      architecture_state = 'PASS'
      task_base_sha = '1111111111111111111111111111111111111111'
      final_tree_sha = '2222222222222222222222222222222222222222'
      evidence_reference = "source-diff:1111111111111111111111111111111111111111..2222222222222222222222222222222222222222#$WorkItemId"
    }
    $artifacts.Add($artifact)
    $references.Add($reference)
    $previousReference = $reference
  }
  return [pscustomobject]@{
    WorkItemId = $WorkItemId
    ModeConstraint = $ModeConstraint
    Artifacts = @($artifacts)
    References = @($references)
    FinalReference = [string]$references[-1]
  }
}

function New-TerminalResponsibilityArtifact(
  [string]$Reference,
  [string]$WorkItemId,
  [string]$Status,
  [string]$TerminalChainReference,
  [string[]]$ChainReferences = @(),
  [string]$ModeConstraint = 'incremental/preserve-existing',
  [string]$TaskUnit = ''
) {
  if ([string]::IsNullOrWhiteSpace($TaskUnit)) { $TaskUnit = $WorkItemId }
  return @{
    artifact_reference = $Reference
    artifact_type = 'migration-work-item-terminal'
    immutable = $true
    run_id = 'RUN-ADMIN-001'
    master_spec_ref = 'runs/master-spec@2.md'
    master_spec_id = 'SPEC-ADMIN-001'
    master_spec_revision = 2
    master_plan_ref = 'runs/master-plan@3.md'
    master_plan_id = 'PLAN-ADMIN-001'
    master_plan_revision = 3
    work_item_id = $WorkItemId
    plan_revision = 3
    status = $Status
    result = 'complete'
    mode_constraint = $ModeConstraint
    responsibility_chain_references = @($ChainReferences)
    terminal_chain_reference = if ([string]::IsNullOrWhiteSpace($TerminalChainReference)) { 'none' } else { $TerminalChainReference }
    task_provenance = @{
      task_unit = $TaskUnit
      task_base_sha = '1111111111111111111111111111111111111111'
      final_tree_sha = '2222222222222222222222222222222222222222'
      source_artifact_reference = 'implementation-report.md'
      evidence_reference = "source-diff:1111111111111111111111111111111111111111..2222222222222222222222222222222222222222#$WorkItemId"
    }
    responsibility_handoff = @{
      responsibility_contract_version = 1
      tree_conformance = 'PASS'
      responsibility_conformance = 'PASS'
      verification_ownership = 'PASS'
      architecture_state = 'PASS'
      evidence_reference = "source-diff:1111111111111111111111111111111111111111..2222222222222222222222222222222222222222#$WorkItemId"
    }
  }
}

function Invoke-ReconciliationAuthorityCase(
  [string]$Suffix,
  [bool]$IncludeTerminalAuthority = $true,
  [scriptblock]$MutateAuthority = $null,
  [bool]$NextItemDependsOnReconciled = $false,
  [string]$MigrationUnitId = ''
) {
  $reconciledItem = New-WorkItem "WORK-ADMIN-RECONCILE-$Suffix" 1 @() 'in-progress'
  if (-not [string]::IsNullOrWhiteSpace($MigrationUnitId)) {
    $reconciledItem.adapter_kind = 'migration-unit'
    $reconciledItem.external_id = $MigrationUnitId
  }
  $reconciledItem.latest_attempt = "ATTEMPT-WORK-ADMIN-RECONCILE-$Suffix-01"
  $reconciledItem.attempt_status = 'complete'
  $reconciledItem.terminal_evidence = "runs/reconcile-$($Suffix.ToLowerInvariant())-terminal.md"
  $reconciledItem.attempt_history = @(
    @{ attempt_id = $reconciledItem.latest_attempt; work_item_id = $reconciledItem.work_item_id; plan_revision = 3; status = 'complete'; artifact_reference = $reconciledItem.terminal_evidence }
  )
  $nextItemKind = if ($NextItemDependsOnReconciled) { 'DEPENDENT' } else { 'UNRELATED' }
  $nextItemDependencies = if ($NextItemDependsOnReconciled) { @($reconciledItem.work_item_id) } else { @() }
  $nextItem = New-WorkItem "WORK-ADMIN-$nextItemKind-$Suffix" 2 $nextItemDependencies
  $fixture = @{
    scenario_type = 'scope-engine'; operation = 'select'; current_plan_revision = 3
    work_items = @($reconciledItem, $nextItem)
  }
  if ($IncludeTerminalAuthority) {
    $chain = New-ResponsibilityChain "runs/reconcile-$($Suffix.ToLowerInvariant())-chain" $reconciledItem.work_item_id $reconciledItem.mode_constraint
    $taskUnit = if ($reconciledItem.adapter_kind -ceq 'migration-unit') { [string]$reconciledItem.external_id } else { [string]$reconciledItem.work_item_id }
    $terminal = New-TerminalResponsibilityArtifact $reconciledItem.terminal_evidence $reconciledItem.work_item_id 'complete' $chain.FinalReference $chain.References $chain.ModeConstraint $taskUnit
    $terminal.attempt_id = $reconciledItem.latest_attempt
    $terminal.result = 'complete'
    if ($null -ne $MutateAuthority) { & $MutateAuthority $terminal $chain }
    $fixture.terminal_artifacts = @($terminal)
    $fixture.responsibility_chain_artifacts = @($chain.Artifacts)
  }
  return [pscustomobject]@{
    Result = Invoke-ScopeScenario $fixture
    ReconciledItem = $reconciledItem
    NextItem = $nextItem
    UnrelatedItem = $nextItem
  }
}

function Invoke-NoDependentReconciliationCase(
  [string]$Suffix,
  [bool]$IncludeTerminalAuthority = $true,
  [scriptblock]$MutateAuthority = $null
) {
  return (Invoke-ReconciliationAuthorityCase $Suffix $IncludeTerminalAuthority $MutateAuthority $false)
}

function New-TerminalScopeReport(
  [string]$Reference,
  [object[]]$Items,
  [object[]]$Chains,
  [bool]$IncludeEvidenceIndex = $true
) {
  $chainByWorkItem = @{}
  foreach ($chain in @($Chains)) { $chainByWorkItem[[string]$chain.WorkItemId] = $chain }
  $reportRows = [Collections.Generic.List[object]]::new()
  $evidenceRows = [Collections.Generic.List[object]]::new()
  $evidenceReferences = [Collections.Generic.List[string]]::new()
  foreach ($item in @($Items)) {
    $reportRows.Add(@{
      work_item_id = [string]$item.work_item_id
      status = [string]$item.status
      terminal_evidence = [string]$item.terminal_evidence
      architecture_state = [string]$item.architecture_state
      selector_schema_state = [string]$item.selector_schema_state
    })
    if (@('complete', 'cancelled-approved', 'not-applicable-approved') -ccontains [string]$item.status) {
      $chain = $chainByWorkItem[[string]$item.work_item_id]
      if ($null -ne $chain) {
        $evidenceReferences.Add([string]$chain.Artifacts[0].evidence_reference)
        $evidenceRows.Add(@{
          evidence_id = "EVIDENCE-$([string]$item.work_item_id)"
          artifact_reference = [string]$chain.FinalReference
          work_item_id = [string]$item.work_item_id
          purpose = 'architecture-responsibility-sub-verdicts'
        })
      }
    }
  }
  $report = @{
    artifact_reference = $Reference
    artifact_type = 'migration-scope-terminal-report'
    run_id = 'RUN-ADMIN-001'
    master_spec_ref = 'runs/master-spec@2.md'
    master_spec_id = 'SPEC-ADMIN-001'
    master_spec_revision = 2
    master_plan_ref = 'runs/master-plan@3.md'
    master_plan_id = 'PLAN-ADMIN-001'
    master_plan_revision = 3
    immutable = $true
    responsibility_handoff = @{
      responsibility_contract_version = 1
      tree_conformance = 'PASS'
      responsibility_conformance = 'PASS'
      verification_ownership = 'PASS'
      architecture_state = 'PASS'
      evidence_references = @($evidenceReferences)
    }
    items = @($reportRows)
  }
  if ($IncludeEvidenceIndex) { $report.evidence_index = @($evidenceRows) }
  return $report
}

if (-not (Test-Path -LiteralPath $validatorPath -PathType Leaf)) {
  Write-Output 'FAIL: Missing scope-engine validator'
  exit 1
}
. $validatorPath

# Scope resolution: the production break caught here is selecting an item before
# preserving the user-requested boundary, or inventing a migration-unit adapter.
foreach ($kind in @('module', 'feature', 'project', 'task')) {
  $resolved = Invoke-ScopeScenario @{
    scenario_type = 'scope-engine'
    operation = 'resolve-scope'
    requested_scope = @{
      kind = $kind
      id = "SCOPE-$($kind.ToUpperInvariant())"
      statement = "Migrate requested $kind"
      source = 'user'
      resolution_evidence = 'conversation:scope-001'
    }
  }
  Assert-Equal $resolved.result 'scope-resolved' "$kind request must resolve before execution"
  Assert-Equal $resolved.requested_scope_kind $kind "$kind request kind must be preserved"
  Assert-Equal $resolved.scope_question_count 0 "$kind request must not ask a scope question"
  Assert-True ([bool]$resolved.can_run_step_01) "$kind request must become eligible for run preparation"
}

$explicit = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'
  operation = 'resolve-scope'
  requested_scope = @{
    kind = 'explicit-item'
    id = 'UNIT-ADM-004'
    statement = 'Migrate UNIT-ADM-004'
    source = 'user'
    resolution_evidence = 'conversation:scope-002'
  }
}
Assert-Equal $explicit.result 'scope-resolved' 'Explicit item request must resolve'
Assert-Equal $explicit.boundary 'minimum-item-and-dependency-context' 'Explicit item must not expand to module scope'

$unresolved = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'
  operation = 'resolve-scope'
  requested_scope = @{
    kind = 'unresolved'
    id = 'ADMIN'
    statement = 'Migrate Admin'
    source = 'user'
    resolution_evidence = 'conversation:scope-003'
  }
}
Assert-Equal $unresolved.result 'scope-question-required' 'Ambiguous scope must block for clarification'
Assert-Equal $unresolved.scope_question_count 1 'Ambiguous scope must ask exactly one scope question'
Assert-True (-not [bool]$unresolved.can_run_step_01) 'Ambiguous scope must not reach step 01'
$emittedQuestions = @($unresolved.questions)
Assert-Equal $emittedQuestions.Count 1 'Unresolved scope must emit exactly one real question block'
Assert-Equal $emittedQuestions[0].id 'requested-scope' 'Scope question block must have a stable machine ID'
$expectedScopeQuestion = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('QuG6oW4gbXXhu5FuIG1pZ3JhdGUgQURNSU4g4bufIHBo4bqhbSB2aSBwcm9qZWN0LCBtb2R1bGUsIGZlYXR1cmUsIHRhc2sgaGF5IGV4cGxpY2l0IGl0ZW0/'))
Assert-Equal $emittedQuestions[0].prompt $expectedScopeQuestion 'Scope question must contain the concrete ambiguous scope ID and allowed boundary choices'

# Executable operations must enforce scope resolution, then master spec, then
# master plan approval/revision evidence before touching queue behavior.
$gateItem = New-WorkItem 'WORK-ADMIN-GATED' 1
$unresolvedGate = New-ApprovedOrchestrationContext
$unresolvedGate.requested_scope.kind = 'unresolved'
$unresolvedGate.requested_scope.resolution_evidence = 'conversation:ambiguous'
$unresolvedGate.spec_revisions[1].status = 'draft'
$unresolvedGate.plan_revisions[2].status = 'draft'
$scopeGateResult = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'
  operation = 'select'
  current_plan_revision = 3
  orchestration_context = $unresolvedGate
  work_items = @($gateItem)
}
Assert-Equal $scopeGateResult.result 'orchestration-blocked' 'Queue selection must not run before requested-scope resolution'
Assert-Equal $scopeGateResult.reason 'requested-scope-unresolved' 'Scope gate must run before draft master-artifact checks'

$draftSpecGate = New-ApprovedOrchestrationContext
$draftSpecGate.spec_revisions[1].status = 'draft'
$specGateResult = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'
  operation = 'select'
  current_plan_revision = 3
  orchestration_context = $draftSpecGate
  work_items = @($gateItem)
}
Assert-Equal $specGateResult.result 'orchestration-blocked' 'Queue selection must require current approved master spec evidence'
Assert-Equal $specGateResult.reason 'approved-master-spec-revision-missing' 'Master-spec approval must fail before master-plan execution'

$stalePlanGate = New-ApprovedOrchestrationContext
$stalePlanGate.plan_revisions[2].stale = $true
$planGateResult = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'
  operation = 'select'
  current_plan_revision = 3
  orchestration_context = $stalePlanGate
  work_items = @($gateItem)
}
Assert-Equal $planGateResult.result 'orchestration-blocked' 'Queue selection must require a fresh current master plan revision'
Assert-Equal $planGateResult.reason 'stale-revision-chain' 'Stale master plan must block before selection'

$pendingReferenceGate = New-ApprovedOrchestrationContext
$pendingReferenceGate.master_spec_ref = 'pending'
$pendingReferenceResult = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'select'; current_plan_revision = 3
  orchestration_context = $pendingReferenceGate; work_items = @($gateItem)
}
Assert-Equal $pendingReferenceResult.result 'orchestration-blocked' 'Executable operation must require an explicit resolved master-spec reference'
Assert-Equal $pendingReferenceResult.reason 'master-artifact-reference-invalid' 'Pending master reference must be rejected as a placeholder'

$placeholderApprovalGate = New-ApprovedOrchestrationContext
$placeholderApprovalGate.spec_revisions[1].approval_reference = 'none'
$placeholderApprovalResult = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'select'; current_plan_revision = 3
  orchestration_context = $placeholderApprovalGate; work_items = @($gateItem)
}
Assert-Equal $placeholderApprovalResult.result 'orchestration-blocked' 'Approved status must have real non-placeholder approval evidence'
Assert-Equal $placeholderApprovalResult.reason 'master-spec-evidence-invalid' 'Placeholder approval evidence must be rejected'

$blankEvidenceGate = New-ApprovedOrchestrationContext
$blankEvidenceGate.plan_revisions[2].freshness_evidence = '   '
$blankEvidenceResult = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'select'; current_plan_revision = 3
  orchestration_context = $blankEvidenceGate; work_items = @($gateItem)
}
Assert-Equal $blankEvidenceResult.result 'orchestration-blocked' 'Whitespace-only freshness evidence must not satisfy approved master-plan binding'
Assert-Equal $blankEvidenceResult.reason 'master-plan-evidence-invalid' 'Blank master-plan evidence must be rejected as placeholder'

$canonicalPlanItem = New-WorkItem 'WORK-ADMIN-CANONICAL' 1
$forgedQueueItem = New-WorkItem 'WORK-ADMIN-FORGED' 1
$forgedQueueGate = New-ApprovedOrchestrationContext
$forgedQueueGate.plan_revisions[2].work_items = @($canonicalPlanItem)
$forgedQueueResult = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'select'; current_plan_revision = 3
  orchestration_context = $forgedQueueGate; work_items = @($forgedQueueItem)
}
Assert-Equal $forgedQueueResult.result 'orchestration-blocked' 'Queue input must be the exact current approved master-plan rows'
Assert-Equal $forgedQueueResult.reason 'work-items-not-bound-to-master-plan' 'Arbitrary caller queue must be rejected before selection'

foreach ($stringImmutableCase in @('master-spec', 'master-plan', 'planned-responsibility-design')) {
  $stringImmutableItem = New-WorkItem "WORK-ADMIN-STRING-IMMUTABLE-$($stringImmutableCase.ToUpperInvariant())" 1
  $stringImmutableContext = New-ApprovedOrchestrationContext
  $stringImmutableContext.plan_revisions[2].work_items = @($stringImmutableItem)
  $stringImmutableAuthority = New-PlannedResponsibilityDesignArtifact $stringImmutableItem
  switch ($stringImmutableCase) {
    'master-spec' { $stringImmutableContext.spec_revisions[1].immutable = 'false' }
    'master-plan' { $stringImmutableContext.plan_revisions[2].immutable = 'false' }
    'planned-responsibility-design' { $stringImmutableAuthority.immutable = 'false' }
  }
  $stringImmutableContext.resolved_artifacts = @($stringImmutableAuthority)
  $stringImmutableResult = Invoke-ScopeScenario @{
    scenario_type = 'scope-engine'; operation = 'select'; current_plan_revision = 3
    orchestration_context = $stringImmutableContext; work_items = @($stringImmutableItem)
  }
  Assert-True ($stringImmutableResult.result -cin @('orchestration-blocked', 'scope-blocked')) "String false immutable must reject at $stringImmutableCase authority"
}

# Generic projects: a valid `none` adapter must remain generic and selectable.
$genericItem = New-WorkItem 'WORK-GENERIC-SHELL' 1
$generic = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'
  operation = 'select'
  current_plan_revision = 3
  work_items = @($genericItem)
}
Assert-Equal $generic.result 'selected' 'Generic work item must be selectable without a migration unit'
Assert-Equal $generic.work_item_id 'WORK-GENERIC-SHELL' 'Generic selector must return the work item ID'
Assert-Equal $generic.adapter_kind 'none' 'Generic selector must preserve adapter kind none'
Assert-Equal $generic.migration_unit_id 'not-applicable' 'Generic selector must not invent a UNIT ID'

# Initial eligibility is produced by the approved master plan's selector and
# responsibility-owner rows plus the exact approved technical-design revision.
$plannedAuthorityItem = New-WorkItem 'WORK-ADMIN-PLANNED-AUTHORITY' 1
$plannedAuthorityContext = New-PlannedResponsibilityContext @($plannedAuthorityItem)
$plannedAuthorityResult = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'select'; current_plan_revision = 3
  orchestration_context = $plannedAuthorityContext; work_items = @($plannedAuthorityItem)
}
Assert-Equal $plannedAuthorityResult.result 'selected' 'Master-plan selector and responsibility rows must authorize initial selection from the approved design'

# The real master-plan producer must render one canonical discriminator that
# survives projection into the current-plan resolver before planned rows run.
$masterPlanProducerText = ((Get-Content -Raw -Encoding utf8 (Join-Path $toolkitRoot 'templates/migration/master-plan.md')) -replace "`r`n", "`n") -replace "`r", "`n"
$masterPlanFrontMatter = [regex]::Match($masterPlanProducerText, '\A---\n(?<body>.*?)\n---(?:\n|\z)', [Text.RegularExpressions.RegexOptions]::Singleline)
$masterPlanContractMatches = if ($masterPlanFrontMatter.Success) {
  @([regex]::Matches($masterPlanFrontMatter.Groups['body'].Value, '(?m)^responsibility_contract:\n  version: (?<version>[^\n]+)\n  applicability: (?<applicability>[^\n]+)$'))
}
else { @() }
Assert-Equal $masterPlanContractMatches.Count 1 'Master-plan producer must render exactly one canonical responsibility contract discriminator'
if ($masterPlanContractMatches.Count -eq 1) {
  $producerAuthorityItem = New-WorkItem 'WORK-ADMIN-PRODUCER-AUTHORITY' 1
  $producerAuthorityContext = New-PlannedResponsibilityContext @($producerAuthorityItem)
  $producerAuthorityContext.plan_revisions[2].responsibility_contract = [ordered]@{
    version = [int]$masterPlanContractMatches[0].Groups['version'].Value
    applicability = $masterPlanContractMatches[0].Groups['applicability'].Value
  }
  $producerAuthorityResult = Invoke-ScopeScenario @{
    scenario_type = 'scope-engine'; operation = 'select'; current_plan_revision = 3
    orchestration_context = $producerAuthorityContext; work_items = @($producerAuthorityItem)
  }
  Assert-Equal $producerAuthorityResult.result 'selected' 'Canonical master-plan producer discriminator must authorize scope selection'
}

foreach ($planContractCase in @(
  @{ Name = 'missing'; Mutate = { param($plan) [void]$plan.Remove('responsibility_contract') } },
  @{ Name = 'pre-v1'; Mutate = { param($plan) $plan.responsibility_contract = [ordered]@{ version = 0; applicability = 'required' } } },
  @{ Name = 'unsupported'; Mutate = { param($plan) $plan.responsibility_contract = [ordered]@{ version = 2; applicability = 'required' } } },
  @{ Name = 'duplicate'; Mutate = { param($plan) $plan.responsibility_contract = @([ordered]@{ version = 1; applicability = 'required' }, [ordered]@{ version = 1; applicability = 'required' }) } },
  @{ Name = 'mixed-plan'; Mutate = { param($plan) $plan.responsibility_contract = @([ordered]@{ version = 1; applicability = 'required' }, [ordered]@{ version = 2; applicability = 'required' }) } }
)) {
  $planContractItem = New-WorkItem "WORK-ADMIN-PLAN-CONTRACT-$($planContractCase.Name.ToUpperInvariant())" 1
  $planContractContext = New-PlannedResponsibilityContext @($planContractItem)
  $currentPlan = $planContractContext.plan_revisions[2]
  & $planContractCase.Mutate $currentPlan
  $currentPlan.delivery_adapter_selections = @()
  $currentPlan.responsibility_owner_references = @()
  $planContractResult = Invoke-ScopeScenario @{
    scenario_type = 'scope-engine'; operation = 'select'; current_plan_revision = 3
    orchestration_context = $planContractContext; work_items = @($planContractItem)
  }
  Assert-Equal $planContractResult.result 'orchestration-blocked' "$($planContractCase.Name) master-plan discriminator must block scope before planned rows"
  Assert-Equal $planContractResult.reason 'responsibility-contract-version-invalid' "$($planContractCase.Name) master-plan discriminator must emit the canonical diagnostic"
  Assert-Equal $planContractResult.gate 'master-plan' "$($planContractCase.Name) master-plan discriminator must remain a master-plan gate"
}

# Raw JSON validation must run before Windows PowerShell 5.1 ConvertFrom-Json
# collapses duplicate keys or coerces singleton arrays through string casts.
$rawCurrentPlanContext = New-ApprovedOrchestrationContext
$rawCurrentPlanJson = [ordered]@{
  scenario_type = 'scope-engine'
  operation = 'select'
  current_plan_revision = 3
  orchestration_context = $rawCurrentPlanContext
  work_items = @()
} | ConvertTo-Json -Depth 20 -Compress
$canonicalRawPlanContract = '"responsibility_contract":{"version":1,"applicability":"required"}'

$rawCurrentPlanContractCases = @(
  @{
    Name = 'duplicate plan key invalid-first-valid-last'
    Json = Replace-RawScopeJsonExactOrFail $rawCurrentPlanJson $canonicalRawPlanContract ('"responsibility_contract":{"version":2,"applicability":"required"},' + $canonicalRawPlanContract) 'current duplicate invalid-first'
  },
  @{
    Name = 'duplicate plan key valid-first-invalid-last'
    Json = Replace-RawScopeJsonExactOrFail $rawCurrentPlanJson $canonicalRawPlanContract ($canonicalRawPlanContract + ',"responsibility_contract":{"version":2,"applicability":"required"}') 'current duplicate valid-first'
  },
  @{
    Name = 'duplicate version child invalid-first-valid-last'
    Json = Replace-RawScopeJsonExactOrFail $rawCurrentPlanJson $canonicalRawPlanContract '"responsibility_contract":{"version":2,"version":1,"applicability":"required"}' 'current duplicate version'
  },
  @{
    Name = 'duplicate applicability child invalid-first-valid-last'
    Json = Replace-RawScopeJsonExactOrFail $rawCurrentPlanJson $canonicalRawPlanContract '"responsibility_contract":{"version":1,"applicability":"optional","applicability":"required"}' 'current duplicate applicability'
  },
  @{
    Name = 'contract array'
    Json = Replace-RawScopeJsonExactOrFail $rawCurrentPlanJson $canonicalRawPlanContract '"responsibility_contract":[{"version":1,"applicability":"required"}]' 'current contract array'
  },
  @{
    Name = 'string version'
    Json = Replace-RawScopeJsonExactOrFail $rawCurrentPlanJson $canonicalRawPlanContract '"responsibility_contract":{"version":"1","applicability":"required"}' 'current string version'
  },
  @{
    Name = 'array version child'
    Json = Replace-RawScopeJsonExactOrFail $rawCurrentPlanJson $canonicalRawPlanContract '"responsibility_contract":{"version":[1],"applicability":"required"}' 'current array version'
  },
  @{
    Name = 'object applicability child'
    Json = Replace-RawScopeJsonExactOrFail $rawCurrentPlanJson $canonicalRawPlanContract '"responsibility_contract":{"version":1,"applicability":{"value":"required"}}' 'current object applicability'
  },
  @{
    Name = 'extra child'
    Json = Replace-RawScopeJsonExactOrFail $rawCurrentPlanJson $canonicalRawPlanContract '"responsibility_contract":{"version":1,"applicability":"required","extra":true}' 'current extra child'
  },
  @{
    Name = 'decimal current revision with string version'
    Json = Replace-RawScopeJsonExactOrFail (Replace-RawScopeJsonExactOrFail $rawCurrentPlanJson '"revision":3' '"revision":3.0' 'current decimal revision') $canonicalRawPlanContract '"responsibility_contract":{"version":"1","applicability":"required"}' 'current decimal revision string contract'
  },
  @{
    Name = 'duplicate current revision invalid-first-valid-last with string version'
    Json = Replace-RawScopeJsonExactOrFail (Replace-RawScopeJsonExactOrFail $rawCurrentPlanJson '"revision":3' '"revision":2,"revision":3' 'current duplicate revision') $canonicalRawPlanContract '"responsibility_contract":{"version":"1","applicability":"required"}' 'current duplicate revision string contract'
  }
)
foreach ($rawCurrentPlanContractCase in $rawCurrentPlanContractCases) {
  $rawCurrentPlanContractResult = Invoke-RawScopeScenario $rawCurrentPlanContractCase.Json
  Assert-Equal $rawCurrentPlanContractResult.result 'orchestration-blocked' "$($rawCurrentPlanContractCase.Name) raw current-plan discriminator must block before JSON projection"
  Assert-Equal $rawCurrentPlanContractResult.reason 'responsibility-contract-version-invalid' "$($rawCurrentPlanContractCase.Name) raw current-plan discriminator must emit the canonical diagnostic"
  Assert-Equal $rawCurrentPlanContractResult.gate 'master-plan' "$($rawCurrentPlanContractCase.Name) raw current-plan discriminator must remain a master-plan gate"
}

$rootPathAuthorityItem = New-WorkItem 'WORK-ADMIN-ROOT-PATH-AUTHORITY' 1
$rootPathAuthorityContext = New-PlannedResponsibilityContext @($rootPathAuthorityItem)
$rootPathDesign = $rootPathAuthorityContext.resolved_artifacts[0]
$rootPathOwner = $rootPathDesign.responsibility_rows[0]
$rootPathVerification = $rootPathDesign.verification_rows[0]
$rootPathOwner.owner_path = 'main.ps1'
$rootPathOwner.target_exemplar = 'approved-exemplar.ps1#InvokeApprovedExemplar'
$rootPathOwner.classification_evidence = 'inspection:approved-exemplar.ps1:1-40; working-evidence:approved-exemplar.Tests.ps1:1-40'
$rootPathVerification.evidence_path = 'main.Tests.ps1'
$rootPathVerification.production_binding_evidence = "source:main.ps1#$($rootPathOwner.owner_symbol)"
$rootPathAuthorityResult = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'select'; current_plan_revision = 3
  orchestration_context = $rootPathAuthorityContext; work_items = @($rootPathAuthorityItem)
}
Assert-Equal $rootPathAuthorityResult.result 'selected' 'Canonical root-level repository paths must remain valid planned design authority'

# Initial selection consumes the complete canonical twenty/eleven-column
# design authority. A valid selector/owner projection cannot hide malformed
# ownership, capability, classification, or verification semantics.
foreach ($fullDesignAuthorityCase in @(
  @{ Name = 'missing-owner-path'; Mutate = {
      param($design)
      [void]$design.responsibility_rows[0].Remove('owner_path')
    } },
  @{ Name = 'traversal-owner-path'; Mutate = {
      param($design)
      $design.responsibility_rows[0].owner_path = '../outside/forged.ps1'
    } },
  @{ Name = 'placeholder-owner-symbol'; Mutate = {
      param($design)
      $design.responsibility_rows[0].owner_symbol = '<owner-symbol>'
    } },
  @{ Name = 'forged-architecture-authority'; Mutate = {
      param($design)
      $design.responsibility_rows[0].architecture_authority = 'forged-authority'
    } },
  @{ Name = 'invalid-capability'; Mutate = {
      param($design)
      $design.responsibility_rows[0].owned_capability_ids = @('not-a-capability')
    } },
  @{ Name = 'placeholder-classification-evidence'; Mutate = {
      param($design)
      $design.responsibility_rows[0].classification_evidence = 'pending'
    } },
  @{ Name = 'forged-classification-authority'; Mutate = {
      param($design)
      $design.responsibility_rows[0].classification_authority = 'forged-authority'
    } },
  @{ Name = 'forged-classification-evidence'; Mutate = {
      param($design)
      $design.responsibility_rows[0].classification_evidence = 'forged:evidence'
    } },
  @{ Name = 'invalid-evidence-kind'; Mutate = {
      param($design)
      $design.verification_rows[0].evidence_kind = 'banana'
    } },
  @{ Name = 'invalid-verification-disposition'; Mutate = {
      param($design)
      $design.verification_rows[0].verification_disposition = 'self-approved'
    } },
  @{ Name = 'foreign-production-binding'; Mutate = {
      param($design)
      $design.verification_rows[0].production_binding_evidence = 'source:src/foreign.ps1#InvokeForeign'
    } },
  @{ Name = 'capability-binding-mismatch'; Mutate = {
      param($design)
      $design.verification_rows[0].capability_id = 'CAP-FOREIGN'
    } },
  @{ Name = 'missing-verification-evidence-path'; Mutate = {
      param($design)
      [void]$design.verification_rows[0].Remove('evidence_path')
    } }
)) {
  $invalidFullDesignItem = New-WorkItem "WORK-ADMIN-FULL-DESIGN-$($fullDesignAuthorityCase.Name.ToUpperInvariant())" 1
  $invalidFullDesignContext = New-PlannedResponsibilityContext @($invalidFullDesignItem)
  & $fullDesignAuthorityCase.Mutate $invalidFullDesignContext.resolved_artifacts[0]
  $invalidFullDesignResult = Invoke-ScopeScenario @{
    scenario_type = 'scope-engine'; operation = 'select'; current_plan_revision = 3
    orchestration_context = $invalidFullDesignContext; work_items = @($invalidFullDesignItem)
  }
  Assert-Equal $invalidFullDesignResult.result 'scope-blocked' "$($fullDesignAuthorityCase.Name) full design authority must block initial selection"
  Assert-Equal $invalidFullDesignResult.reason 'planned-responsibility-authority-invalid' "$($fullDesignAuthorityCase.Name) must use the planned-authority diagnostic"
}

$canonicalGreenfieldAuthorityItem = New-WorkItem 'WORK-ADMIN-CANONICAL-GREENFIELD-AUTHORITY' 1
$canonicalGreenfieldAuthorityItem.mode_constraint = 'greenfield/design-new'
$canonicalGreenfieldAuthorityContext = New-PlannedResponsibilityContext @($canonicalGreenfieldAuthorityItem)
$canonicalGreenfieldAuthorityResult = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'select'; current_plan_revision = 3
  orchestration_context = $canonicalGreenfieldAuthorityContext; work_items = @($canonicalGreenfieldAuthorityItem)
}
Assert-Equal $canonicalGreenfieldAuthorityResult.result 'selected' 'Canonical greenfield design authority must authorize initial selection'

$wrongGreenfieldAuthorityContext = New-PlannedResponsibilityContext @($canonicalGreenfieldAuthorityItem)
$wrongGreenfieldAuthorityContext.resolved_artifacts[0].responsibility_rows[0].architecture_authority = 'target-exemplar'
$wrongGreenfieldAuthorityResult = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'select'; current_plan_revision = 3
  orchestration_context = $wrongGreenfieldAuthorityContext; work_items = @($canonicalGreenfieldAuthorityItem)
}
Assert-Equal $wrongGreenfieldAuthorityResult.result 'scope-blocked' 'Greenfield target-exemplar authority must not authorize initial selection'
Assert-Equal $wrongGreenfieldAuthorityResult.reason 'planned-responsibility-authority-invalid' 'Wrong greenfield architecture authority must use the planned-authority diagnostic'

# The scope engine consumes the canonical technical-design row vocabulary. It
# must not invent a second PASS-valued responsibility schema, and it must keep
# the contract's test boundary and approved-deviation semantics intact.
$canonicalTestAuthorityItem = New-WorkItem 'WORK-ADMIN-CANONICAL-TEST-AUTHORITY' 1
$canonicalTestAuthorityContext = New-PlannedResponsibilityContext @($canonicalTestAuthorityItem)
$canonicalTestResponsibilityId = 'RESP-WORK-ADMIN-CANONICAL-TEST-AUTHORITY-TEST'
$canonicalTestRow = New-PlannedResponsibilityRow -Item $canonicalTestAuthorityItem -ResponsibilityId $canonicalTestResponsibilityId -VerificationOwnerId 'VERIFY-OWNER-NOT-USED'
$canonicalTestRow.owner_path = 'tests/responsibilities/canonical-test-authority.Tests.ps1'
$canonicalTestRow.owner_symbol = 'TestCanonicalAuthority'
$canonicalTestRow.boundary_kind = 'test'
$canonicalTestRow.primary_responsibility = 'Verify canonical test authority'
$canonicalTestRow.public_symbols = @('TestCanonicalAuthority')
$canonicalTestRow.verification_owner_references = @('not-applicable')
$canonicalTestAuthorityContext.resolved_artifacts[0].responsibility_rows += @($canonicalTestRow)
$canonicalTestAuthorityContext.plan_revisions[2].responsibility_owner_references[0].responsibility_ids += @($canonicalTestResponsibilityId)
$canonicalTestAuthorityResult = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'select'; current_plan_revision = 3
  orchestration_context = $canonicalTestAuthorityContext; work_items = @($canonicalTestAuthorityItem)
}
Assert-Equal $canonicalTestAuthorityResult.result 'selected' 'Canonical Boundary Kind=test with Conformance=yes must authorize initial selection'

$approvedDeviationAuthorityItem = New-WorkItem 'WORK-ADMIN-APPROVED-DEVIATION-AUTHORITY' 1
$approvedDeviationAuthorityContext = New-PlannedResponsibilityContext @($approvedDeviationAuthorityItem)
$approvedDeviationDesign = $approvedDeviationAuthorityContext.resolved_artifacts[0]
$approvedDeviationDesign.responsibility_rows[0].conformance = 'no'
$approvedDeviationDesign.responsibility_rows[0].architecture_authority = 'approved-structural-deviation'
$approvedDeviationDesign.responsibility_rows[0].exemplar_classification = 'compatibility-only'
$approvedDeviationDesign.responsibility_rows[0].classification_authority = 'project-pack-rule'
$approvedDeviationDesign.responsibility_rows[0].classification_evidence = 'architecture-rules.md#RULE-ADMIN-APPROVED-AUTHORITY'
$approvedDeviationDesign.responsibility_rows[0].deviation_reference = 'DEV-ADMIN-APPROVED-AUTHORITY'
$approvedDeviationDesign.verification_rows[0].deviation_reference = 'DEV-ADMIN-APPROVED-AUTHORITY'
$approvedDeviationDesign.approved_deviation_rows = @(@{
  deviation_reference = 'DEV-ADMIN-APPROVED-AUTHORITY'
  concern = 'responsibility ownership'
  conflict_reference = 'CONFLICT-ADMIN-APPROVED-AUTHORITY'
  resolved_decision = 'resolved:DECISION-ADMIN-APPROVED-AUTHORITY: preserve the approved compatibility owner'
  tech_lead_approval = 'approval:TECH-LEAD-ADMIN-APPROVED-AUTHORITY'
})
$approvedDeviationAuthorityResult = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'select'; current_plan_revision = 3
  orchestration_context = $approvedDeviationAuthorityContext; work_items = @($approvedDeviationAuthorityItem)
}
Assert-Equal $approvedDeviationAuthorityResult.result 'selected' 'Canonical Conformance=no must authorize selection only through its exact approved DEV join'

$yesWithDeviationItem = New-WorkItem 'WORK-ADMIN-YES-WITH-DEVIATION' 1
$yesWithDeviationContext = New-PlannedResponsibilityContext @($yesWithDeviationItem)
$yesWithDeviationContext.resolved_artifacts[0].responsibility_rows[0].deviation_reference = 'DEV-ADMIN-YES-WITH-DEVIATION'
$yesWithDeviationResult = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'select'; current_plan_revision = 3
  orchestration_context = $yesWithDeviationContext; work_items = @($yesWithDeviationItem)
}
Assert-Equal $yesWithDeviationResult.result 'scope-blocked' 'Conformance=yes must reject a contradictory deviation reference'
Assert-Equal $yesWithDeviationResult.reason 'planned-responsibility-authority-invalid' 'Contradictory yes/deviation authority must use the planned-authority diagnostic'

foreach ($invalidDeviationCase in @(
  @{ Name = 'missing-row'; Mutate = {
      param($design)
      $design.approved_deviation_rows = @()
    } },
  @{ Name = 'duplicate-row'; Mutate = {
      param($design)
      $design.approved_deviation_rows = @($design.approved_deviation_rows[0], $design.approved_deviation_rows[0])
    } },
  @{ Name = 'foreign-row'; Mutate = {
      param($design)
      $design.approved_deviation_rows[0].deviation_reference = 'DEV-ADMIN-FOREIGN'
    } },
  @{ Name = 'malformed-approval'; Mutate = {
      param($design)
      $design.approved_deviation_rows[0].tech_lead_approval = 'approval:OWNER-NOT-TECH-LEAD'
    } },
  @{ Name = 'mixed-valid-malformed-duplicate'; Mutate = {
      param($design)
      $validRow = $design.approved_deviation_rows[0]
      $design.approved_deviation_rows = @($validRow, @{
        deviation_reference = $validRow.deviation_reference
        concern = 'responsibility ownership'
        conflict_reference = $validRow.conflict_reference
        resolved_decision = $validRow.resolved_decision
        tech_lead_approval = 'approval:OWNER-FORGED'
      })
    } },
  @{ Name = 'placeholder-concern'; Mutate = {
      param($design)
      $design.approved_deviation_rows[0].concern = 'pending'
    } },
  @{ Name = 'placeholder-decision'; Mutate = {
      param($design)
      $reference = [string]$design.approved_deviation_rows[0].deviation_reference
      $design.approved_deviation_rows[0].resolved_decision = "resolved:DECISION-$($reference.Substring(4)): pending"
    } }
)) {
  $invalidDeviationItem = New-WorkItem "WORK-ADMIN-INVALID-DEVIATION-$($invalidDeviationCase.Name.ToUpperInvariant())" 1
  $invalidDeviationContext = New-PlannedResponsibilityContext @($invalidDeviationItem)
  $invalidDeviationDesign = $invalidDeviationContext.resolved_artifacts[0]
  $invalidDeviationReference = "DEV-ADMIN-INVALID-DEVIATION-$($invalidDeviationCase.Name.ToUpperInvariant())"
  $invalidDeviationDesign.responsibility_rows[0].conformance = 'no'
  $invalidDeviationDesign.responsibility_rows[0].architecture_authority = 'approved-structural-deviation'
  $invalidDeviationDesign.responsibility_rows[0].exemplar_classification = 'compatibility-only'
  $invalidDeviationDesign.responsibility_rows[0].deviation_reference = $invalidDeviationReference
  $invalidDeviationDesign.verification_rows[0].deviation_reference = $invalidDeviationReference
  $invalidDeviationDesign.approved_deviation_rows = @(@{
    deviation_reference = $invalidDeviationReference
    concern = 'responsibility ownership'
    conflict_reference = "CONFLICT-ADMIN-INVALID-DEVIATION-$($invalidDeviationCase.Name.ToUpperInvariant())"
    resolved_decision = "resolved:DECISION-ADMIN-INVALID-DEVIATION-$($invalidDeviationCase.Name.ToUpperInvariant()): preserve the approved compatibility owner"
    tech_lead_approval = "approval:TECH-LEAD-ADMIN-INVALID-DEVIATION-$($invalidDeviationCase.Name.ToUpperInvariant())"
  })
  & $invalidDeviationCase.Mutate $invalidDeviationDesign
  $invalidDeviationResult = Invoke-ScopeScenario @{
    scenario_type = 'scope-engine'; operation = 'select'; current_plan_revision = 3
    orchestration_context = $invalidDeviationContext; work_items = @($invalidDeviationItem)
  }
  Assert-Equal $invalidDeviationResult.result 'scope-blocked' "$($invalidDeviationCase.Name) Conformance=no authority must fail closed"
  Assert-Equal $invalidDeviationResult.reason 'planned-responsibility-authority-invalid' "$($invalidDeviationCase.Name) deviation failure must use the planned-authority diagnostic"
}

$blockedConformanceItem = New-WorkItem 'WORK-ADMIN-BLOCKED-CONFORMANCE' 1
$blockedConformanceContext = New-PlannedResponsibilityContext @($blockedConformanceItem)
$blockedConformanceContext.resolved_artifacts[0].responsibility_rows[0].conformance = 'blocked'
$blockedConformanceResult = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'select'; current_plan_revision = 3
  orchestration_context = $blockedConformanceContext; work_items = @($blockedConformanceItem)
}
Assert-Equal $blockedConformanceResult.result 'scope-blocked' 'Conformance=blocked must never authorize initial selection'
Assert-Equal $blockedConformanceResult.reason 'planned-responsibility-authority-invalid' 'Blocked design conformance must use the planned-authority diagnostic'

$noncanonicalPassAuthorityItem = New-WorkItem 'WORK-ADMIN-NONCANONICAL-PASS-AUTHORITY' 1
$noncanonicalPassAuthorityContext = New-PlannedResponsibilityContext @($noncanonicalPassAuthorityItem)
$noncanonicalPassAuthorityContext.resolved_artifacts[0].responsibility_rows[0].conformance = 'PASS'
$noncanonicalPassAuthorityResult = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'select'; current_plan_revision = 3
  orchestration_context = $noncanonicalPassAuthorityContext; work_items = @($noncanonicalPassAuthorityItem)
}
Assert-Equal $noncanonicalPassAuthorityResult.result 'scope-blocked' 'Synthetic Conformance=PASS must not replace the canonical technical-design enum'
Assert-Equal $noncanonicalPassAuthorityResult.reason 'planned-responsibility-authority-invalid' 'Synthetic design conformance must use the planned-authority diagnostic'

$canonicalSelectorItem = New-WorkItem 'WORK-ADMIN-CANONICAL-SELECTOR' 1
$canonicalSelectorItem.adapter_kind = 'migration-unit'
$canonicalSelectorItem.external_id = 'UNIT-ADMIN-CANONICAL-SELECTOR'
$canonicalSelectorContext = New-PlannedResponsibilityContext @($canonicalSelectorItem)
$canonicalSelectorResult = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'select'; current_plan_revision = 3
  orchestration_context = $canonicalSelectorContext; work_items = @($canonicalSelectorItem)
}
Assert-Equal $canonicalSelectorResult.result 'selected' 'Canonical unversioned UNIT selector authority must authorize initial selection'

foreach ($selectorAuthorityCase in @(
  @{ Name = 'precomposed-authority'; Mutate = {
      param($item, $context)
      $context.plan_revisions[2].delivery_adapter_selections[0].authority = 'authority:WORK-ADMIN-CANONICAL-SELECTOR@1'
    } },
  @{ Name = 'malformed-external-id'; Mutate = {
      param($item, $context)
      $item.external_id = 'not a canonical id'
      $context.plan_revisions[2].delivery_adapter_selections[0].external_id = 'not a canonical id'
    } },
  @{ Name = 'wrong-kind-external-id'; Mutate = {
      param($item, $context)
      $item.external_id = 'TASK-ADMIN-CANONICAL-SELECTOR'
      $context.plan_revisions[2].delivery_adapter_selections[0].external_id = 'TASK-ADMIN-CANONICAL-SELECTOR'
    } },
  @{ Name = 'foreign-root-parent-selector'; Mutate = {
      param($item, $context)
      $context.plan_revisions[2].delivery_adapter_selections[0].parent_selector = 'UNIT-FOREIGN'
    } },
  @{ Name = 'noncanonical-approval'; Mutate = {
      param($item, $context)
      $context.plan_revisions[2].delivery_adapter_selections[0].approval_reference = 'approval:lower/path'
    } },
  @{ Name = 'noncanonical-mode'; Mutate = {
      param($item, $context)
      $item.mode_constraint = 'banana'
      $context.plan_revisions[2].work_items[0].mode_constraint = 'banana'
      $context.plan_revisions[2].delivery_adapter_selections[0].mode_constraint = 'banana'
      $context.resolved_artifacts[0].mode_constraint = 'banana'
    } }
)) {
  $selectorCaseItem = New-WorkItem "WORK-ADMIN-SELECTOR-$($selectorAuthorityCase.Name.ToUpperInvariant())" 1
  $selectorCaseItem.adapter_kind = 'migration-unit'
  $selectorCaseItem.external_id = "UNIT-ADMIN-SELECTOR-$($selectorAuthorityCase.Name.ToUpperInvariant())"
  $selectorCaseContext = New-PlannedResponsibilityContext @($selectorCaseItem)
  & $selectorAuthorityCase.Mutate $selectorCaseItem $selectorCaseContext
  $selectorCaseResult = Invoke-ScopeScenario @{
    scenario_type = 'scope-engine'; operation = 'select'; current_plan_revision = 3
    orchestration_context = $selectorCaseContext; work_items = @($selectorCaseItem)
  }
  Assert-Equal $selectorCaseResult.result 'scope-blocked' "$($selectorAuthorityCase.Name) selector authority must fail closed before selection"
  Assert-Equal $selectorCaseResult.reason 'planned-responsibility-authority-invalid' "$($selectorAuthorityCase.Name) selector authority must use the planned-authority diagnostic"
}

$parentSelectorItem = New-WorkItem 'WORK-ADMIN-SELECTOR-PARENT' 1
$parentSelectorItem.adapter_kind = 'task'
$parentSelectorItem.external_id = 'TASK-ADMIN-SELECTOR-PARENT'
$childSelectorItem = New-WorkItem 'WORK-ADMIN-SELECTOR-CHILD' 2 @('WORK-ADMIN-SELECTOR-PARENT')
$childSelectorItem.adapter_kind = 'story'
$childSelectorItem.external_id = 'STORY-ADMIN-SELECTOR-CHILD'
$parentChildSelectorContext = New-PlannedResponsibilityContext @($parentSelectorItem, $childSelectorItem)
$parentChildSelectorContext.plan_revisions[2].delivery_adapter_selections[1].parent_work_item_id = 'WORK-ADMIN-SELECTOR-PARENT'
$parentChildSelectorContext.plan_revisions[2].delivery_adapter_selections[1].decomposition_decision_reference = 'DEC-ADMIN-SELECTOR-CHILD'
$parentChildSelectorContext.plan_revisions[2].delivery_adapter_selections[1].parent_selector = 'TASK-ADMIN-SELECTOR-PARENT'
$parentChildSelectorResult = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'select'; current_plan_revision = 3
  orchestration_context = $parentChildSelectorContext; work_items = @($parentSelectorItem, $childSelectorItem)
}
Assert-Equal $parentChildSelectorResult.result 'selected' 'A child selector must resolve its exact earlier parent selector from the complete plan map'

$mismatchedParentSelectorContext = New-PlannedResponsibilityContext @($parentSelectorItem, $childSelectorItem)
$mismatchedParentSelectorContext.plan_revisions[2].delivery_adapter_selections[1].parent_work_item_id = 'WORK-ADMIN-SELECTOR-PARENT'
$mismatchedParentSelectorContext.plan_revisions[2].delivery_adapter_selections[1].decomposition_decision_reference = 'DEC-ADMIN-SELECTOR-CHILD'
$mismatchedParentSelectorContext.plan_revisions[2].delivery_adapter_selections[1].parent_selector = 'TASK-FOREIGN-PARENT'
$mismatchedParentSelectorResult = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'select'; current_plan_revision = 3
  orchestration_context = $mismatchedParentSelectorContext; work_items = @($parentSelectorItem, $childSelectorItem)
}
Assert-Equal $mismatchedParentSelectorResult.result 'scope-blocked' 'A child selector must reject a foreign parent selector even when its Parent Work Item ID is valid'
Assert-Equal $mismatchedParentSelectorResult.reason 'planned-responsibility-authority-invalid' 'A foreign parent selector must use the planned-authority diagnostic'

$duplicateSelectorA = New-WorkItem 'WORK-ADMIN-DUPLICATE-SELECTOR-A' 1
$duplicateSelectorA.adapter_kind = 'task'
$duplicateSelectorA.external_id = 'TASK-ADMIN-DUPLICATE-SELECTOR'
$duplicateSelectorB = New-WorkItem 'WORK-ADMIN-DUPLICATE-SELECTOR-B' 2
$duplicateSelectorB.adapter_kind = 'task'
$duplicateSelectorB.external_id = 'TASK-ADMIN-DUPLICATE-SELECTOR'
$duplicateSelectorContext = New-PlannedResponsibilityContext @($duplicateSelectorA, $duplicateSelectorB)
$duplicateSelectorResult = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'select'; current_plan_revision = 3
  orchestration_context = $duplicateSelectorContext; work_items = @($duplicateSelectorA, $duplicateSelectorB)
}
Assert-Equal $duplicateSelectorResult.result 'scope-blocked' 'Two work items must not share one canonical selector identity'
Assert-Equal $duplicateSelectorResult.reason 'planned-responsibility-authority-invalid' 'Duplicate selector identities must use the planned-authority diagnostic'

$mixedModeItemA = New-WorkItem 'WORK-ADMIN-MIXED-MODE-A' 1
$mixedModeItemB = New-WorkItem 'WORK-ADMIN-MIXED-MODE-B' 2
$mixedModeItemB.mode_constraint = 'greenfield/design-new'
$mixedModeContext = New-PlannedResponsibilityContext @($mixedModeItemA, $mixedModeItemB)
$mixedModeResult = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'select'; current_plan_revision = 3
  orchestration_context = $mixedModeContext; work_items = @($mixedModeItemA, $mixedModeItemB)
}
Assert-Equal $mixedModeResult.result 'scope-blocked' 'One approved master plan must not mix selector mode authorities'
Assert-Equal $mixedModeResult.reason 'planned-responsibility-authority-invalid' 'Mixed plan modes must use the planned-authority diagnostic'

foreach ($incompleteChildCase in @(
  @{ Name = 'missing-parent'; Parent = 'not-applicable'; Decision = 'DEC-ADMIN-INCOMPLETE-CHILD' },
  @{ Name = 'missing-decision'; Parent = 'WORK-ADMIN-SELECTOR-PARENT'; Decision = 'not-applicable' }
)) {
  $incompleteChildContext = New-PlannedResponsibilityContext @($parentSelectorItem, $childSelectorItem)
  $incompleteChildRow = $incompleteChildContext.plan_revisions[2].delivery_adapter_selections[1]
  $incompleteChildRow.parent_work_item_id = $incompleteChildCase.Parent
  $incompleteChildRow.decomposition_decision_reference = $incompleteChildCase.Decision
  $incompleteChildRow.parent_selector = 'TASK-ADMIN-SELECTOR-PARENT'
  $incompleteChildResult = Invoke-ScopeScenario @{
    scenario_type = 'scope-engine'; operation = 'select'; current_plan_revision = 3
    orchestration_context = $incompleteChildContext; work_items = @($parentSelectorItem, $childSelectorItem)
  }
  Assert-Equal $incompleteChildResult.result 'scope-blocked' "$($incompleteChildCase.Name) child selector authority must fail closed"
  Assert-Equal $incompleteChildResult.reason 'planned-responsibility-authority-invalid' "$($incompleteChildCase.Name) child selector failure must use the planned-authority diagnostic"
}

foreach ($boundaryEvidenceCase in @(
  'approval:OWNER-BOUNDARY: independently implementable, reviewable, verifiable, and revertible',
  'approval:TECH-LEAD-BOUNDARY: independently implementable, reviewable, testable, and revertible',
  'docs/architecture.md#RULE-BOUNDARY: independently implementable, reviewable, verifiable, and revertible',
  'docs/architecture.md#DECISION-BOUNDARY: independently implementable, reviewable, testable, and revertible',
  'docs/architecture.md#APPROVAL-BOUNDARY: independently implementable, reviewable, verifiable, and revertible'
)) {
  $boundaryEvidenceItem = New-WorkItem 'WORK-ADMIN-BOUNDARY-EVIDENCE' 1
  $boundaryEvidenceContext = New-PlannedResponsibilityContext @($boundaryEvidenceItem)
  $boundaryEvidenceContext.plan_revisions[2].responsibility_owner_references[0].independent_boundary_evidence = $boundaryEvidenceCase
  $boundaryEvidenceResult = Invoke-ScopeScenario @{
    scenario_type = 'scope-engine'; operation = 'select'; current_plan_revision = 3
    orchestration_context = $boundaryEvidenceContext; work_items = @($boundaryEvidenceItem)
  }
  Assert-Equal $boundaryEvidenceResult.result 'selected' "Canonical independent-boundary authority must select: $boundaryEvidenceCase"
}

foreach ($plannedAuthorityCase in @(
  @{ Name = 'missing-selector'; Mutate = { param($context) $context.plan_revisions[2].delivery_adapter_selections = @() } },
  @{ Name = 'missing-owner'; Mutate = { param($context) $context.plan_revisions[2].responsibility_owner_references = @() } },
  @{ Name = 'stale-selector'; Mutate = { param($context) $context.plan_revisions[2].delivery_adapter_selections[0].design_revision = 'DESIGN-ADMIN@1' } },
  @{ Name = 'stale-design'; Mutate = { param($context) $context.resolved_artifacts[0].revision = 'DESIGN-ADMIN@1' } },
  @{ Name = 'foreign-design'; Mutate = { param($context) $context.resolved_artifacts[0].run_id = 'RUN-FOREIGN-999' } },
  @{ Name = 'duplicate-selector'; Mutate = { param($context) $context.plan_revisions[2].delivery_adapter_selections += @($context.plan_revisions[2].delivery_adapter_selections[0]) } },
  @{ Name = 'duplicate-owner'; Mutate = { param($context) $context.plan_revisions[2].responsibility_owner_references += @($context.plan_revisions[2].responsibility_owner_references[0]) } },
  @{ Name = 'duplicate-design'; Mutate = { param($context) $context.resolved_artifacts += @($context.resolved_artifacts[0]) } },
  @{ Name = 'pre-v1-design'; Mutate = { param($context) $context.resolved_artifacts[0].responsibility_contract.version = 0 } },
  @{ Name = 'forged-boundary-approval'; Mutate = { param($context) $context.plan_revisions[2].responsibility_owner_references[0].independent_boundary_evidence = 'approval:FORGED: independently implementable, reviewable, verifiable, and revertible' } },
  @{ Name = 'incomplete-boundary-evidence'; Mutate = { param($context) $context.plan_revisions[2].responsibility_owner_references[0].independent_boundary_evidence = 'approval:OWNER-INCOMPLETE: independently implementable and reviewable' } },
  @{ Name = 'design-category-mismatch'; Mutate = { param($context) $context.resolved_artifacts[0].responsibility_rows[0].co_location_policy = 'shared-foundation' } },
  @{ Name = 'overlapping-owner-category'; Mutate = {
      param($context)
      $context.plan_revisions[2].responsibility_owner_references[0].shared_foundation_ids = @($context.plan_revisions[2].responsibility_owner_references[0].responsibility_ids[0])
    } },
  @{ Name = 'reused-verification-owner'; Mutate = {
      param($context)
      $workItemId = [string]$context.plan_revisions[2].work_items[0].work_item_id
      $verificationOwnerId = "VERIFY-OWNER-$workItemId"
      $context.plan_revisions[2].responsibility_owner_references[0].responsibility_ids += @("RESP-$workItemId-SECOND")
      $context.resolved_artifacts[0].responsibility_rows += @(
        New-PlannedResponsibilityRow -Item $context.plan_revisions[2].work_items[0] -ResponsibilityId "RESP-$workItemId-SECOND" -VerificationOwnerId $verificationOwnerId
      )
    } }
)) {
  $caseItem = New-WorkItem "WORK-ADMIN-PLANNED-$($plannedAuthorityCase.Name.ToUpperInvariant())" 1
  $caseContext = New-PlannedResponsibilityContext @($caseItem)
  & $plannedAuthorityCase.Mutate $caseContext
  $caseResult = Invoke-ScopeScenario @{
    scenario_type = 'scope-engine'; operation = 'select'; current_plan_revision = 3
    orchestration_context = $caseContext; work_items = @($caseItem)
  }
  Assert-Equal $caseResult.result 'scope-blocked' "$($plannedAuthorityCase.Name) planned responsibility authority must block initial selection"
  Assert-Equal $caseResult.reason 'planned-responsibility-authority-invalid' "$($plannedAuthorityCase.Name) planned responsibility authority must emit the canonical diagnostic"
}

$planWideAuthorityCases = @(
  @{ Name = 'reordered-selectors'; Mutate = {
      param($context, $first, $second)
      $rows = @($context.plan_revisions[2].delivery_adapter_selections)
      $context.plan_revisions[2].delivery_adapter_selections = @($rows[1], $rows[0])
    } },
  @{ Name = 'reordered-owners'; Mutate = {
      param($context, $first, $second)
      $rows = @($context.plan_revisions[2].responsibility_owner_references)
      $context.plan_revisions[2].responsibility_owner_references = @($rows[1], $rows[0])
    } },
  @{ Name = 'foreign-selector'; Mutate = {
      param($context, $first, $second)
      $foreign = New-WorkItem 'WORK-ADMIN-FOREIGN-AUTHORITY' 99
      $context.plan_revisions[2].delivery_adapter_selections += @(New-PlannedAdapterSelection $foreign)
    } },
  @{ Name = 'foreign-owner'; Mutate = {
      param($context, $first, $second)
      $foreign = New-WorkItem 'WORK-ADMIN-FOREIGN-AUTHORITY' 99
      $context.plan_revisions[2].responsibility_owner_references += @(New-PlannedResponsibilityOwnerReference $foreign)
    } },
  @{ Name = 'missing-optional-owner'; Mutate = {
      param($context, $first, $second)
      $context.plan_revisions[2].responsibility_owner_references = @($context.plan_revisions[2].responsibility_owner_references[0])
    } },
  @{ Name = 'cross-work-responsibility-reuse'; Mutate = {
      param($context, $first, $second)
      $reusedId = [string]$context.plan_revisions[2].responsibility_owner_references[0].responsibility_ids[0]
      $context.plan_revisions[2].responsibility_owner_references[1].responsibility_ids = @($reusedId)
      $context.resolved_artifacts[1].responsibility_rows[0].responsibility_id = $reusedId
      $context.resolved_artifacts[1].verification_rows[0].production_responsibility_id = $reusedId
    } },
  @{ Name = 'cross-work-verification-reuse'; Mutate = {
      param($context, $first, $second)
      $reusedId = [string]$context.resolved_artifacts[0].responsibility_rows[0].verification_owner_references[0]
      $context.resolved_artifacts[1].responsibility_rows[0].verification_owner_references = @($reusedId)
      $context.resolved_artifacts[1].verification_rows[0].verification_owner_id = $reusedId
    } }
)
foreach ($planWideAuthorityCase in $planWideAuthorityCases) {
  $planWideFirst = New-WorkItem "WORK-ADMIN-$($planWideAuthorityCase.Name.ToUpperInvariant())-A" 1
  $planWideSecond = New-WorkItem "WORK-ADMIN-$($planWideAuthorityCase.Name.ToUpperInvariant())-B" 2 @() 'ready' $false
  $planWideContext = New-PlannedResponsibilityContext @($planWideFirst, $planWideSecond)
  & $planWideAuthorityCase.Mutate $planWideContext $planWideFirst $planWideSecond
  $planWideResult = Invoke-ScopeScenario @{
    scenario_type = 'scope-engine'; operation = 'select'; current_plan_revision = 3
    orchestration_context = $planWideContext; work_items = @($planWideFirst, $planWideSecond)
  }
  Assert-Equal $planWideResult.result 'scope-blocked' "$($planWideAuthorityCase.Name) must fail the plan-wide responsibility authority gate"
  Assert-Equal $planWideResult.reason 'planned-responsibility-authority-invalid' "$($planWideAuthorityCase.Name) must use the canonical planned-authority diagnostic"
}

$orderedCategoryItem = New-WorkItem 'WORK-ADMIN-ORDERED-CATEGORY' 1
$orderedCategoryContext = New-PlannedResponsibilityContext @($orderedCategoryItem)
$orderedCategoryOwner = $orderedCategoryContext.plan_revisions[2].responsibility_owner_references[0]
$orderedCategoryDesign = $orderedCategoryContext.resolved_artifacts[0]
$orderedCategoryOwner.responsibility_ids += @('RESP-WORK-ADMIN-ORDERED-CATEGORY-SECOND')
$orderedCategoryDesign.responsibility_rows += @(
  New-PlannedResponsibilityRow -Item $orderedCategoryItem -ResponsibilityId 'RESP-WORK-ADMIN-ORDERED-CATEGORY-SECOND' -VerificationOwnerId 'VERIFY-OWNER-WORK-ADMIN-ORDERED-CATEGORY-SECOND'
)
$orderedCategoryDesign.verification_rows += @(
  New-PlannedVerificationRow -Item $orderedCategoryItem -ResponsibilityId 'RESP-WORK-ADMIN-ORDERED-CATEGORY-SECOND' -VerificationOwnerId 'VERIFY-OWNER-WORK-ADMIN-ORDERED-CATEGORY-SECOND'
)
$orderedCategoryOwner.responsibility_ids = @($orderedCategoryOwner.responsibility_ids[1], $orderedCategoryOwner.responsibility_ids[0])
$orderedCategoryResult = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'select'; current_plan_revision = 3
  orchestration_context = $orderedCategoryContext; work_items = @($orderedCategoryItem)
}
Assert-Equal $orderedCategoryResult.result 'scope-blocked' 'Responsibility IDs reordered relative to the approved design must block'
Assert-Equal $orderedCategoryResult.reason 'planned-responsibility-authority-invalid' 'Responsibility order drift must use the canonical planned-authority diagnostic'

# Queue/resume responsibility state is evidence-derived. Scalar PASS fields on
# a caller row cannot replace the current immutable v1 authority artifact.
$missingQueueAuthority = New-WorkItem 'WORK-ADMIN-MISSING-QUEUE-AUTHORITY' 1
$missingQueueAuthority.test_omit_planned_authority = $true
$missingQueueAuthorityResult = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'select'
  work_items = @($missingQueueAuthority)
}
Assert-Equal $missingQueueAuthorityResult.result 'scope-blocked' 'Missing responsibility authority must block before queue selection'
Assert-Equal $missingQueueAuthorityResult.reason 'planned-responsibility-authority-invalid' 'Missing queue authority must derive the planned-authority blocker'
Assert-Equal $missingQueueAuthorityResult.work_item_id '' 'Missing queue authority must leave next eligible item empty'

$preV1Resume = New-WorkItem 'WORK-ADMIN-PRE-V1-RESUME' 1 @() 'in-progress'
$preV1Resume.latest_attempt = 'ATTEMPT-WORK-ADMIN-PRE-V1-RESUME-01'
$preV1Resume.attempt_history = @(
  @{ attempt_id = 'ATTEMPT-WORK-ADMIN-PRE-V1-RESUME-01'; work_item_id = 'WORK-ADMIN-PRE-V1-RESUME'; plan_revision = 3; status = 'in-progress'; artifact_reference = 'runs/pre-v1-resume-01.md' }
)
$preV1Authority = New-PlannedResponsibilityDesignArtifact $preV1Resume
$preV1Authority.Remove('responsibility_rows')
$preV1ResumeResult = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'select'
  work_items = @($preV1Resume)
  planned_design_artifacts = @($preV1Authority)
}
Assert-Equal $preV1ResumeResult.result 'scope-blocked' 'An in-progress pre-v1 item must not resume from scalar PASS fields'
Assert-Equal $preV1ResumeResult.reason 'planned-responsibility-authority-invalid' 'Pre-v1 resume evidence must derive BLOCKED'

$mismatchedDependency = New-WorkItem 'WORK-ADMIN-MISMATCHED-DEPENDENCY' 1 @() 'complete'
$dependentAfterMismatch = New-WorkItem 'WORK-ADMIN-AFTER-MISMATCH' 2 @('WORK-ADMIN-MISMATCHED-DEPENDENCY')
$mismatchedDependencyAuthority = New-PlannedResponsibilityDesignArtifact $mismatchedDependency
$mismatchedDependencyAuthority.work_item_id = 'WORK-ADMIN-FOREIGN'
$mismatchedDependencyResult = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'select'
  work_items = @($mismatchedDependency, $dependentAfterMismatch)
  planned_design_artifacts = @($mismatchedDependencyAuthority)
}
Assert-Equal $mismatchedDependencyResult.result 'scope-blocked' 'Mismatched terminal dependency authority must not unlock its dependent'
Assert-Equal $mismatchedDependencyResult.work_item_id '' 'A dependent must remain unselected when predecessor evidence is mismatched'

foreach ($chainIndex in 1..4) {
  $completeDependency = New-WorkItem "WORK-ADMIN-COMPLETE-DOWNSTREAM-$chainIndex" 1 @() 'complete'
  $completeDependency.terminal_evidence = "runs/complete-downstream-$chainIndex-terminal.md"
  $dependentAfterInvalidChain = New-WorkItem "WORK-ADMIN-AFTER-DOWNSTREAM-$chainIndex" 2 @($completeDependency.work_item_id)
  $dependencyChain = New-ResponsibilityChain "runs/complete-downstream-$chainIndex-chain" $completeDependency.work_item_id
  $dependencyChain.Artifacts[$chainIndex].approval_source = 'automation'
  $dependencyTerminal = New-TerminalResponsibilityArtifact $completeDependency.terminal_evidence $completeDependency.work_item_id $completeDependency.status $dependencyChain.FinalReference $dependencyChain.References $dependencyChain.ModeConstraint
  $dependencyResult = Invoke-ScopeScenario @{
    scenario_type = 'scope-engine'; operation = 'select'
    work_items = @($completeDependency, $dependentAfterInvalidChain)
    terminal_artifacts = @($dependencyTerminal)
    responsibility_chain_artifacts = @($dependencyChain.Artifacts)
  }
  Assert-Equal $dependencyResult.result 'scope-blocked' "A completed dependency with invalid downstream step $chainIndex must not unlock its dependent"
  Assert-Equal $dependencyResult.work_item_id '' "Invalid downstream dependency step $chainIndex must leave the dependent unselected"
}

$crossRunAuthorityItem = New-WorkItem 'WORK-ADMIN-CROSS-RUN-AUTHORITY' 1
$crossRunAuthority = New-PlannedResponsibilityDesignArtifact $crossRunAuthorityItem
$crossRunAuthority.run_id = 'RUN-FOREIGN-999'
$crossRunAuthorityResult = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'select'
  work_items = @($crossRunAuthorityItem)
  planned_design_artifacts = @($crossRunAuthority)
}
Assert-Equal $crossRunAuthorityResult.result 'scope-blocked' 'Cross-run responsibility authority must not select a work item'
Assert-Equal $crossRunAuthorityResult.work_item_id '' 'Cross-run queue evidence must leave next eligible item empty'

# Deterministic selection: depth wins before Plan Order, then Plan Order wins.
$rootLater = New-WorkItem 'WORK-ADMIN-ZETA' 9
$rootFirst = New-WorkItem 'WORK-ADMIN-ALPHA' 4
$deepEarly = New-WorkItem 'WORK-ADMIN-DEEP' 1 @('WORK-ADMIN-ZETA')
$ordered = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'
  operation = 'select'
  current_plan_revision = 3
  work_items = @($deepEarly, $rootLater, $rootFirst)
}
Assert-Equal $ordered.result 'selected' 'Valid graph must select one item'
Assert-Equal $ordered.work_item_id 'WORK-ADMIN-ALPHA' 'Dependency depth must sort before Plan Order'

# Every eligibility predicate is independently required. The broken lower-order
# item must be skipped and the valid fallback must be selected.
$eligibilityMutations = @(
  @{ Name = 'required-or-approved-optional'; Apply = { param($item) $item.required = $false; $item.optional_execution_approved = $false } },
  @{ Name = 'pending-or-ready'; Apply = { param($item) $item.status = 'proposed' } },
  @{ Name = 'current-approval'; Apply = { param($item) $item.approval_revision = 2 } },
  @{ Name = 'no-blocker'; Apply = { param($item) $item.has_blocker = $true } },
  @{ Name = 'adapter-valid'; Apply = { param($item) $item.adapter_valid = $false } },
  @{ Name = 'selector-schema-pass'; Apply = { param($item) $item.selector_schema_state = 'BLOCKED' } }
)
foreach ($mutation in $eligibilityMutations) {
  $candidate = New-WorkItem 'WORK-ADMIN-CANDIDATE' 1
  & $mutation.Apply $candidate
  $fallback = New-WorkItem 'WORK-ADMIN-FALLBACK' 2
  $selection = Invoke-ScopeScenario @{
    scenario_type = 'scope-engine'
    operation = 'select'
    current_plan_revision = 3
    work_items = @($candidate, $fallback)
  }
  Assert-Equal $selection.work_item_id 'WORK-ADMIN-FALLBACK' "Eligibility predicate '$($mutation.Name)' must reject the candidate"
}

# The production break caught here is treating an independent fallback as safe
# after any structural sub-verdict in the approved queue has blocked. The queue
# must stop globally so no parity/regression/delivery/KB successor can advance.
$structuralBlockers = @(
  @{ Name = 'Tree'; Field = 'tree_conformance' },
  @{ Name = 'Responsibility'; Field = 'responsibility_conformance' },
  @{ Name = 'Verification Ownership'; Field = 'verification_ownership' },
  @{ Name = 'Architecture aggregate'; Field = 'architecture_state' }
)
foreach ($blocker in $structuralBlockers) {
  $blockedCandidate = New-WorkItem "WORK-ADMIN-$($blocker.Name.ToUpperInvariant().Replace(' ', '-'))-BLOCKED" 1
  $blockedCandidate[$blocker.Field] = 'BLOCKED'
  $independentFallback = New-WorkItem 'WORK-ADMIN-INDEPENDENT-FALLBACK' 2
  $blockedSelection = Invoke-ScopeScenario @{
    scenario_type = 'scope-engine'; operation = 'select'
    work_items = @($blockedCandidate, $independentFallback)
  }
  Assert-Equal $blockedSelection.result 'scope-blocked' "$($blocker.Name) BLOCKED must stop the entire queue"
  Assert-Equal $blockedSelection.reason 'structural-assurance-blocked' "$($blocker.Name) BLOCKED must emit the stable structural diagnostic"
  Assert-Equal $blockedSelection.scope_status 'scope-blocked' "$($blocker.Name) BLOCKED must set scope-blocked"
  Assert-Equal $blockedSelection.work_item_id '' "$($blocker.Name) BLOCKED must leave next eligible item as none"
}

$allResponsibilityBlocked = New-WorkItem 'WORK-ADMIN-ALL-RESPONSIBILITY-BLOCKED' 1
$allResponsibilityBlocked.responsibility_conformance = 'BLOCKED'
$allResponsibilityBlockedSelection = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'select'
  work_items = @($allResponsibilityBlocked)
}
Assert-Equal $allResponsibilityBlockedSelection.result 'scope-blocked' 'A required responsibility blocker must stop the queue before dependent work can be selected'
Assert-Equal $allResponsibilityBlockedSelection.scope_status 'scope-blocked' 'A responsibility blocker must set scope-blocked'

$responsibilityBlockedRoot = New-WorkItem 'WORK-ADMIN-RESPONSIBILITY-ROOT' 1
$responsibilityBlockedRoot.responsibility_conformance = 'BLOCKED'
$responsibilityDependent = New-WorkItem 'WORK-ADMIN-RESPONSIBILITY-DEPENDENT' 2 @('WORK-ADMIN-RESPONSIBILITY-ROOT')
$responsibilityChainSelection = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'select'
  work_items = @($responsibilityBlockedRoot, $responsibilityDependent)
}
Assert-Equal $responsibilityChainSelection.result 'scope-blocked' 'A responsibility mismatch must stop the whole dependent chain'
Assert-Equal $responsibilityChainSelection.reason 'structural-assurance-blocked' 'A responsibility mismatch without a more specific diagnostic must use the stable structural diagnostic'
Assert-Equal $responsibilityChainSelection.work_item_id '' 'No dependent item may be selected after a responsibility mismatch'

$dependencyBlocked = New-WorkItem 'WORK-ADMIN-DEPENDENCY' 1 @() 'blocked'
$dependent = New-WorkItem 'WORK-ADMIN-DEPENDENT' 2 @('WORK-ADMIN-DEPENDENCY')
$blockedSelection = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'
  operation = 'select'
  current_plan_revision = 3
  work_items = @($dependencyBlocked, $dependent)
}
Assert-Equal $blockedSelection.result 'scope-blocked' 'Hard blocker must prevent dependent execution'
Assert-Equal $blockedSelection.scope_status 'scope-blocked' 'Required blocker must block the scope'

$missingDependency = New-WorkItem 'WORK-ADMIN-MISSING' 1 @('WORK-ADMIN-NOT-IN-PLAN')
$missing = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'
  operation = 'select'
  current_plan_revision = 3
  work_items = @($missingDependency)
}
Assert-Equal $missing.result 'plan-invalid' 'Missing dependency node must invalidate the plan'
Assert-Equal $missing.reason 'missing-dependency' 'Missing dependency must report its exact reason'

$cycleA = New-WorkItem 'WORK-ADMIN-CYCLE-A' 1 @('WORK-ADMIN-CYCLE-B')
$cycleB = New-WorkItem 'WORK-ADMIN-CYCLE-B' 2 @('WORK-ADMIN-CYCLE-A')
$cycle = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'
  operation = 'select'
  current_plan_revision = 3
  work_items = @($cycleA, $cycleB)
}
Assert-Equal $cycle.result 'plan-invalid' 'Dependency cycle must invalidate the plan'
Assert-Equal $cycle.reason 'dependency-cycle' 'Dependency cycle must report its exact reason'

# Resume always reconciles the only in-progress attempt before new selection.
$running = New-WorkItem 'WORK-ADMIN-RUNNING' 1 @() 'in-progress'
$running.latest_attempt = 'ATTEMPT-WORK-ADMIN-RUNNING-01'
$running.attempt_status = 'in-progress'
$running.attempt_history = @(
  @{ attempt_id = 'ATTEMPT-WORK-ADMIN-RUNNING-01'; work_item_id = 'WORK-ADMIN-RUNNING'; plan_revision = 3; status = 'in-progress'; artifact_reference = 'runs/running-01.md' }
)
$waiting = New-WorkItem 'WORK-ADMIN-WAITING' 2
$resume = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'
  operation = 'select'
  current_plan_revision = 3
  work_items = @($running, $waiting)
}
Assert-Equal $resume.result 'resume-attempt' 'Non-terminal attempt must resume instead of selecting another item'
Assert-Equal $resume.work_item_id 'WORK-ADMIN-RUNNING' 'Resume must keep the deterministic in-progress item'

$runningWithEvidence = New-WorkItem 'WORK-ADMIN-RUNNING' 1 @() 'in-progress'
$runningWithEvidence.latest_attempt = 'ATTEMPT-WORK-ADMIN-RUNNING-01'
$runningWithEvidence.attempt_status = 'complete'
$runningWithEvidence.attempt_evidence_valid = $true
$runningWithEvidence.terminal_evidence = 'runs/attempt-running-01.md'
$runningWithEvidence.attempt_history = @(
  @{ attempt_id = 'ATTEMPT-WORK-ADMIN-RUNNING-01'; work_item_id = 'WORK-ADMIN-RUNNING'; plan_revision = 3; status = 'complete'; artifact_reference = 'runs/attempt-running-01.md' }
)
$waitingAfterReconcile = New-WorkItem 'WORK-ADMIN-WAITING-AFTER-RECONCILE' 2 @($runningWithEvidence.work_item_id)
$runningChain = New-ResponsibilityChain 'runs/running-reconcile-chain' $runningWithEvidence.work_item_id $runningWithEvidence.mode_constraint
$runningTerminal = New-TerminalResponsibilityArtifact $runningWithEvidence.terminal_evidence $runningWithEvidence.work_item_id 'complete' $runningChain.FinalReference $runningChain.References $runningChain.ModeConstraint
$runningTerminal.attempt_id = $runningWithEvidence.latest_attempt
$runningTerminal.result = 'complete'
$afterReconcile = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'
  operation = 'select'
  current_plan_revision = 3
  work_items = @($runningWithEvidence, $waitingAfterReconcile)
  terminal_artifacts = @($runningTerminal)
  responsibility_chain_artifacts = @($runningChain.Artifacts)
}
Assert-Equal $afterReconcile.result 'selected' 'Valid terminal evidence must be reconciled before selecting again'
Assert-Equal $afterReconcile.reconciled_work_item_id 'WORK-ADMIN-RUNNING' 'Resume must expose the reconciled item'
Assert-Equal $afterReconcile.work_item_id 'WORK-ADMIN-WAITING-AFTER-RECONCILE' 'Canonical terminal responsibility authority must unlock the dependent after reconciliation'

$reconciledWithoutAuthority = New-WorkItem 'WORK-ADMIN-RECONCILED-WITHOUT-AUTHORITY' 1 @() 'in-progress'
$reconciledWithoutAuthority.latest_attempt = 'ATTEMPT-WORK-ADMIN-RECONCILED-WITHOUT-AUTHORITY-01'
$reconciledWithoutAuthority.attempt_status = 'complete'
$reconciledWithoutAuthority.terminal_evidence = 'runs/reconciled-without-authority.md'
$reconciledWithoutAuthority.attempt_history = @(
  @{ attempt_id = $reconciledWithoutAuthority.latest_attempt; work_item_id = $reconciledWithoutAuthority.work_item_id; plan_revision = 3; status = 'complete'; artifact_reference = $reconciledWithoutAuthority.terminal_evidence }
)
$dependentAfterReconcile = New-WorkItem 'WORK-ADMIN-DEPENDENT-AFTER-RECONCILE' 2 @($reconciledWithoutAuthority.work_item_id)
$untrustedReconcile = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'select'; current_plan_revision = 3
  work_items = @($reconciledWithoutAuthority, $dependentAfterReconcile)
}
Assert-Equal $untrustedReconcile.result 'scope-blocked' 'Reconciliation must not unlock a dependent without canonical terminal responsibility authority'
Assert-Equal $untrustedReconcile.reason 'terminal-responsibility-authority-invalid' 'Missing reconciled terminal chain must fail the dependency authority gate'
Assert-Equal $untrustedReconcile.work_item_id '' 'A reconciled dependency without terminal authority must leave its dependent unselected'

$canonicalNoDependent = Invoke-NoDependentReconciliationCase 'CANONICAL'
Assert-Equal $canonicalNoDependent.Result.result 'selected' 'A reconciled item with canonical terminal authority may permit unrelated selection'
Assert-Equal $canonicalNoDependent.Result.scope_status 'scope-in-progress' 'Canonical no-dependent reconciliation must preserve the in-progress scope state'
Assert-Equal $canonicalNoDependent.Result.work_item_id $canonicalNoDependent.UnrelatedItem.work_item_id 'Canonical no-dependent reconciliation must select the unrelated eligible item'
Assert-Equal $canonicalNoDependent.Result.reconciled_work_item_id $canonicalNoDependent.ReconciledItem.work_item_id 'Canonical no-dependent reconciliation must expose the reconciled completion'

$migrationUnitReconciliation = Invoke-ReconciliationAuthorityCase 'MIGRATION-UNIT' $true $null $false 'UNIT-RECONCILE-001'
Assert-Equal $migrationUnitReconciliation.Result.result 'selected' 'Reconciliation must accept terminal Task Provenance bound to the approved selected migration-unit ID'
Assert-Equal $migrationUnitReconciliation.Result.reconciled_work_item_id $migrationUnitReconciliation.ReconciledItem.work_item_id 'Migration-unit reconciliation must preserve the enclosing Work Item identity'

$workItemSubstitutedForUnit = Invoke-ReconciliationAuthorityCase 'MIGRATION-UNIT-WRONG-TASK' $true {
  param($terminal, $chain)
  $terminal.task_provenance.task_unit = [string]$terminal.work_item_id
} $false 'UNIT-RECONCILE-002'
Assert-Equal $workItemSubstitutedForUnit.Result.result 'scope-blocked' 'Migration-unit reconciliation must reject Work Item ID substituted for selected Task / Unit authority'
Assert-Equal $workItemSubstitutedForUnit.Result.reason 'terminal-responsibility-authority-invalid' 'Wrong migration-unit Task Provenance must fail terminal responsibility authority'

$missingNoDependentAuthority = Invoke-NoDependentReconciliationCase 'MISSING-AUTHORITY' $false
Assert-Equal $missingNoDependentAuthority.Result.result 'scope-blocked' 'A newly reconciled completion must require terminal authority even when it has no dependent'
Assert-Equal $missingNoDependentAuthority.Result.reason 'terminal-responsibility-authority-invalid' 'Missing no-dependent terminal authority must emit the canonical reason'
Assert-Equal $missingNoDependentAuthority.Result.scope_status 'scope-blocked' 'Missing no-dependent terminal authority must block scope'
Assert-Equal $missingNoDependentAuthority.Result.work_item_id '' 'Missing no-dependent terminal authority must not select unrelated work'

foreach ($terminalAuthorityCase in @(
  @{ Name = 'TERMINAL-PRE-V1'; Mutate = { param($terminal, $chain) $terminal.responsibility_handoff.responsibility_contract_version = 0 } },
  @{ Name = 'TERMINAL-CROSS-RUN'; Mutate = { param($terminal, $chain) $terminal.run_id = 'RUN-FOREIGN-999' } },
  @{ Name = 'TERMINAL-EVIDENCE-MISMATCH'; Mutate = { param($terminal, $chain) $terminal.responsibility_handoff.evidence_reference = 'runs/foreign-terminal-chain.md' } }
)) {
  $invalidTerminalAuthority = Invoke-NoDependentReconciliationCase $terminalAuthorityCase.Name $true $terminalAuthorityCase.Mutate
  Assert-Equal $invalidTerminalAuthority.Result.result 'scope-blocked' "No-dependent reconciliation must reject $($terminalAuthorityCase.Name) authority"
  Assert-Equal $invalidTerminalAuthority.Result.reason 'terminal-responsibility-authority-invalid' "No-dependent $($terminalAuthorityCase.Name) must emit the canonical authority reason"
  Assert-Equal $invalidTerminalAuthority.Result.scope_status 'scope-blocked' "No-dependent $($terminalAuthorityCase.Name) must block scope"
  Assert-Equal $invalidTerminalAuthority.Result.work_item_id '' "No-dependent $($terminalAuthorityCase.Name) must not select unrelated work"
}
$stringImmutableTerminalReconciliation = Invoke-NoDependentReconciliationCase 'TERMINAL-STRING-IMMUTABLE' $true { param($terminal, $chain) $terminal.immutable = 'false' }
Assert-Equal $stringImmutableTerminalReconciliation.Result.result 'plan-invalid' 'String false immutable terminal must reject during reconciliation'
Assert-Equal $stringImmutableTerminalReconciliation.Result.reason 'attempt-artifact-binding-invalid' 'String false immutable terminal must fail the earliest attempt authority gate'

$forgedInitialPredecessor = Invoke-NoDependentReconciliationCase 'FORGED-INITIAL-PREDECESSOR' $true {
  param($terminal, $chain)
  $chain.Artifacts[0].source_artifact_reference = 'forged-predecessor.md'
}
Assert-Equal $forgedInitialPredecessor.Result.result 'scope-blocked' 'Terminal chain review must bind index 0 to the implementation predecessor'
Assert-Equal $forgedInitialPredecessor.Result.reason 'terminal-responsibility-authority-invalid' 'Forged index-0 predecessor must fail terminal responsibility authority'

$allNodeForgedProvenance = Invoke-NoDependentReconciliationCase 'ALL-NODE-FORGED-PROVENANCE' $true {
  param($terminal, $chain)
  foreach ($artifact in @($chain.Artifacts)) {
    $artifact.task_base_sha = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
    $artifact.final_tree_sha = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
    $artifact.evidence_reference = "source-diff:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa..bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb#$($terminal.work_item_id)"
  }
}
Assert-Equal $allNodeForgedProvenance.Result.result 'scope-blocked' 'All-node forged SHA/evidence pairs must not replace immutable Task Provenance during reconciliation'
Assert-Equal $allNodeForgedProvenance.Result.reason 'terminal-responsibility-authority-invalid' 'All-node provenance forgery must fail terminal responsibility authority'

foreach ($chainIndex in 0..4) {
  foreach ($lifecycleCase in @(
    @{ Name = 'STATUS'; Mutate = { param($artifact) $artifact.status = 'draft' } },
    @{ Name = 'RESULT'; Mutate = { param($artifact) $artifact.result = 'blocked' } },
    @{ Name = 'APPROVAL'; Mutate = { param($artifact) $artifact.approval_source = 'automation' } },
    @{ Name = 'STRING-IMMUTABLE'; Mutate = { param($artifact) $artifact.immutable = 'false' } }
  )) {
    $caseName = "CHAIN-$chainIndex-$($lifecycleCase.Name)"
    $mutation = {
      param($terminal, $chain)
      & $lifecycleCase.Mutate $chain.Artifacts[$chainIndex]
    }.GetNewClosure()
    $invalidChainAuthority = Invoke-NoDependentReconciliationCase $caseName $true $mutation
    Assert-Equal $invalidChainAuthority.Result.result 'scope-blocked' "No-dependent reconciliation must reject $caseName lifecycle/authority"
    Assert-Equal $invalidChainAuthority.Result.reason 'terminal-responsibility-authority-invalid' "No-dependent $caseName must emit the canonical authority reason"
    Assert-Equal $invalidChainAuthority.Result.scope_status 'scope-blocked' "No-dependent $caseName must block scope"
    Assert-Equal $invalidChainAuthority.Result.work_item_id '' "No-dependent $caseName must not select unrelated work"
  }
}

# A successful reconciliation must apply the same exact terminal-result authority
# as the normal successful-terminal-artifact transition before any next selection.
foreach ($selectionCase in @(
  @{ Name = 'UNRELATED'; DependsOnReconciled = $false },
  @{ Name = 'DEPENDENT'; DependsOnReconciled = $true }
)) {
  foreach ($terminalResultCase in @(
    @{ Name = 'COMPLETE'; Value = 'complete'; Canonical = $true },
    @{ Name = 'BLOCKED'; Value = 'blocked'; Canonical = $false },
    @{ Name = 'FAIL'; Value = 'fail'; Canonical = $false },
    @{ Name = 'EMPTY'; Value = ''; Canonical = $false },
    @{ Name = 'NONCANONICAL'; Value = 'Complete'; Canonical = $false }
  )) {
    $caseName = "$($selectionCase.Name)-TERMINAL-RESULT-$($terminalResultCase.Name)"
    $terminalResultMutation = {
      param($terminal, $chain)
      $terminal.result = [string]$terminalResultCase.Value
    }.GetNewClosure()
    $resultAuthority = Invoke-ReconciliationAuthorityCase $caseName $true $terminalResultMutation $selectionCase.DependsOnReconciled

    if ($terminalResultCase.Canonical) {
      Assert-Equal $resultAuthority.Result.result 'selected' "$caseName must permit next selection only for exact terminal result complete"
      Assert-Equal $resultAuthority.Result.scope_status 'scope-in-progress' "$caseName must preserve the exact selected scope status"
      Assert-Equal $resultAuthority.Result.reconciled_work_item_id $resultAuthority.ReconciledItem.work_item_id "$caseName must expose the exact reconciled work-item ID"
      Assert-Equal $resultAuthority.Result.work_item_id $resultAuthority.NextItem.work_item_id "$caseName must select the expected next item"
    }
    else {
      Assert-Equal $resultAuthority.Result.result 'scope-blocked' "$caseName must reject non-complete terminal result authority"
      Assert-Equal $resultAuthority.Result.reason 'terminal-responsibility-authority-invalid' "$caseName must emit the canonical terminal authority reason"
      Assert-Equal $resultAuthority.Result.scope_status 'scope-blocked' "$caseName must return the exact blocked scope status"
      Assert-Equal $resultAuthority.Result.reconciled_work_item_id $resultAuthority.ReconciledItem.work_item_id "$caseName must expose the exact reconciled work-item ID"
      Assert-Equal $resultAuthority.Result.work_item_id '' "$caseName must not select another item"
    }
  }
}

$secondRunning = New-WorkItem 'WORK-ADMIN-SECOND-RUNNING' 2 @() 'in-progress'
$secondRunning.latest_attempt = 'ATTEMPT-WORK-ADMIN-SECOND-RUNNING-01'
$secondRunning.attempt_status = 'in-progress'
$secondRunning.attempt_history = @(
  @{ attempt_id = 'ATTEMPT-WORK-ADMIN-SECOND-RUNNING-01'; work_item_id = 'WORK-ADMIN-SECOND-RUNNING'; plan_revision = 3; status = 'in-progress'; artifact_reference = 'runs/second-running-01.md' }
)
$multipleRunning = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'
  operation = 'select'
  current_plan_revision = 3
  work_items = @($running, $secondRunning)
}
Assert-Equal $multipleRunning.result 'plan-invalid' 'More than one in-progress item must invalidate max-concurrency 1'
Assert-Equal $multipleRunning.reason 'multiple-in-progress-attempts' 'Concurrency violation must report active immutable attempts before forged item states'

$mismatchedAttemptItem = New-WorkItem 'WORK-ADMIN-MISMATCH' 1 @() 'in-progress'
$mismatchedAttemptItem.latest_attempt = 'ATTEMPT-WORK-ADMIN-MISMATCH-01'
$mismatchedAttemptItem.attempt_status = 'in-progress'
$mismatchedAttemptItem.attempt_history = @(
  @{ attempt_id = 'ATTEMPT-WORK-ADMIN-MISMATCH-01'; work_item_id = 'WORK-ADMIN-OTHER'; plan_revision = 3; status = 'in-progress'; artifact_reference = 'runs/mismatch-01.md' }
)
$mismatchedAttempt = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'
  operation = 'select'
  current_plan_revision = 3
  work_items = @($mismatchedAttemptItem)
}
Assert-Equal $mismatchedAttempt.result 'plan-invalid' 'Resume must reject an attempt bound to another work item'
Assert-Equal $mismatchedAttempt.reason 'attempt-work-item-mismatch' 'Resume must report work-item binding mismatch'

$staleAttemptItem = New-WorkItem 'WORK-ADMIN-STALE-ATTEMPT' 1 @() 'in-progress'
$staleAttemptItem.latest_attempt = 'ATTEMPT-WORK-ADMIN-STALE-ATTEMPT-01'
$staleAttemptItem.attempt_status = 'in-progress'
$staleAttemptItem.attempt_history = @(
  @{ attempt_id = 'ATTEMPT-WORK-ADMIN-STALE-ATTEMPT-01'; work_item_id = 'WORK-ADMIN-STALE-ATTEMPT'; plan_revision = 2; status = 'in-progress'; artifact_reference = 'runs/stale-attempt-01.md' }
)
$staleAttempt = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'
  operation = 'select'
  current_plan_revision = 3
  work_items = @($staleAttemptItem)
}
Assert-Equal $staleAttempt.result 'plan-invalid' 'Resume must reject an attempt bound to a stale plan revision'
Assert-Equal $staleAttempt.reason 'attempt-plan-revision-mismatch' 'Resume must report exact plan-revision mismatch'

$artifactMismatchItem = New-WorkItem 'WORK-ADMIN-ARTIFACT-MISMATCH' 1 @() 'in-progress'
$artifactMismatchItem.latest_attempt = 'ATTEMPT-WORK-ADMIN-ARTIFACT-MISMATCH-01'
$artifactMismatchItem.attempt_history = @(
  @{ attempt_id = 'ATTEMPT-WORK-ADMIN-ARTIFACT-MISMATCH-01'; work_item_id = 'WORK-ADMIN-ARTIFACT-MISMATCH'; plan_revision = 3; status = 'complete'; artifact_reference = 'runs/artifact-mismatch-terminal.md' }
)
$artifactMismatchItem.terminal_evidence = 'runs/artifact-mismatch-terminal.md'
$artifactMismatchContext = New-ApprovedOrchestrationContext
$artifactMismatchContext.plan_revisions[2].work_items = @($artifactMismatchItem)
$artifactMismatchContext.resolved_artifacts = @(
  @{ artifact_reference = 'runs/artifact-mismatch-terminal.md'; attempt_id = 'ATTEMPT-WORK-ADMIN-OTHER-01'; work_item_id = 'WORK-ADMIN-ARTIFACT-MISMATCH'; plan_revision = 3; status = 'complete'; immutable = $true }
)
$artifactMismatchResume = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'select'; current_plan_revision = 3
  orchestration_context = $artifactMismatchContext; work_items = @($artifactMismatchItem)
}
Assert-Equal $artifactMismatchResume.result 'plan-invalid' 'Resume must resolve and validate the immutable attempt artifact object'
Assert-Equal $artifactMismatchResume.reason 'attempt-artifact-binding-invalid' 'Attempt artifact identity mismatch must block reconciliation'

$stringImmutableAttemptItem = New-WorkItem 'WORK-ADMIN-STRING-IMMUTABLE-ATTEMPT' 1 @() 'in-progress'
$stringImmutableAttemptItem.latest_attempt = 'ATTEMPT-WORK-ADMIN-STRING-IMMUTABLE-ATTEMPT-01'
$stringImmutableAttemptItem.attempt_history = @(
  @{ attempt_id = $stringImmutableAttemptItem.latest_attempt; work_item_id = $stringImmutableAttemptItem.work_item_id; plan_revision = 3; status = 'in-progress'; artifact_reference = 'runs/string-immutable-attempt.md' }
)
$stringImmutableAttemptContext = New-ApprovedOrchestrationContext
$stringImmutableAttemptContext.plan_revisions[2].work_items = @($stringImmutableAttemptItem)
$stringImmutableAttemptContext.resolved_artifacts = @(
  (New-PlannedResponsibilityDesignArtifact $stringImmutableAttemptItem),
  @{ artifact_reference = 'runs/string-immutable-attempt.md'; attempt_id = $stringImmutableAttemptItem.latest_attempt; work_item_id = $stringImmutableAttemptItem.work_item_id; plan_revision = 3; status = 'in-progress'; immutable = 'false' }
)
$stringImmutableAttemptResult = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'select'; current_plan_revision = 3
  orchestration_context = $stringImmutableAttemptContext; work_items = @($stringImmutableAttemptItem)
}
Assert-Equal $stringImmutableAttemptResult.reason 'attempt-artifact-binding-invalid' 'String false immutable must reject at attempt artifact authority'

$activeRecordA = New-WorkItem 'WORK-ADMIN-ACTIVE-RECORD-A' 1 @() 'ready'
$activeRecordA.latest_attempt = 'ATTEMPT-WORK-ADMIN-ACTIVE-RECORD-A-01'
$activeRecordA.attempt_history = @(
  @{ attempt_id = 'ATTEMPT-WORK-ADMIN-ACTIVE-RECORD-A-01'; work_item_id = 'WORK-ADMIN-ACTIVE-RECORD-A'; plan_revision = 3; status = 'in-progress'; artifact_reference = 'runs/active-record-a.md' }
)
$activeRecordB = New-WorkItem 'WORK-ADMIN-ACTIVE-RECORD-B' 2 @() 'ready'
$activeRecordB.latest_attempt = 'ATTEMPT-WORK-ADMIN-ACTIVE-RECORD-B-01'
$activeRecordB.attempt_history = @(
  @{ attempt_id = 'ATTEMPT-WORK-ADMIN-ACTIVE-RECORD-B-01'; work_item_id = 'WORK-ADMIN-ACTIVE-RECORD-B'; plan_revision = 3; status = 'in-progress'; artifact_reference = 'runs/active-record-b.md' }
)
$multipleActiveRecords = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'select'; current_plan_revision = 3
  work_items = @($activeRecordA, $activeRecordB)
}
Assert-Equal $multipleActiveRecords.result 'plan-invalid' 'Single-in-progress gate must count active attempt records even when item states are forged ready'
Assert-Equal $multipleActiveRecords.reason 'multiple-in-progress-attempts' 'Two active immutable attempts must be reported explicitly'

$activeOwner = New-WorkItem 'WORK-ADMIN-ACTIVE-OWNER' 1 @() 'ready'
$activeOwner.latest_attempt = 'ATTEMPT-WORK-ADMIN-ACTIVE-OWNER-01'
$activeOwner.attempt_history = @(
  @{ attempt_id = 'ATTEMPT-WORK-ADMIN-ACTIVE-OWNER-01'; work_item_id = 'WORK-ADMIN-ACTIVE-OWNER'; plan_revision = 3; status = 'in-progress'; artifact_reference = 'runs/active-owner-01.md' }
)
$forgedInProgressOwner = New-WorkItem 'WORK-ADMIN-FORGED-IN-PROGRESS' 2 @() 'in-progress'
$forgedInProgressOwner.latest_attempt = 'ATTEMPT-WORK-ADMIN-FORGED-IN-PROGRESS-01'
$forgedInProgressOwner.terminal_evidence = 'runs/forged-in-progress-01.md'
$forgedInProgressOwner.attempt_history = @(
  @{ attempt_id = 'ATTEMPT-WORK-ADMIN-FORGED-IN-PROGRESS-01'; work_item_id = 'WORK-ADMIN-FORGED-IN-PROGRESS'; plan_revision = 3; status = 'complete'; artifact_reference = 'runs/forged-in-progress-01.md' }
)
$activeOwnerMismatch = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'select'; current_plan_revision = 3
  work_items = @($activeOwner, $forgedInProgressOwner)
}
Assert-Equal $activeOwnerMismatch.result 'plan-invalid' 'Sole active attempt must belong to the sole in-progress work item'
Assert-Equal $activeOwnerMismatch.reason 'active-attempt-item-mismatch' 'Resume must identify active attempt ownership mismatch before reconciliation or selection'

$latestPointerMismatch = New-WorkItem 'WORK-ADMIN-LATEST-POINTER' 1 @() 'in-progress'
$latestPointerMismatch.latest_attempt = 'ATTEMPT-WORK-ADMIN-LATEST-POINTER-02'
$latestPointerMismatch.terminal_evidence = 'runs/latest-pointer-02.md'
$latestPointerMismatch.attempt_history = @(
  @{ attempt_id = 'ATTEMPT-WORK-ADMIN-LATEST-POINTER-01'; work_item_id = 'WORK-ADMIN-LATEST-POINTER'; plan_revision = 3; status = 'in-progress'; artifact_reference = 'runs/latest-pointer-01.md' },
  @{ attempt_id = 'ATTEMPT-WORK-ADMIN-LATEST-POINTER-02'; work_item_id = 'WORK-ADMIN-LATEST-POINTER'; plan_revision = 3; status = 'complete'; artifact_reference = 'runs/latest-pointer-02.md' }
)
$activeLatestMismatch = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'select'; current_plan_revision = 3
  work_items = @($latestPointerMismatch)
}
Assert-Equal $activeLatestMismatch.result 'plan-invalid' 'Sole active attempt must equal the in-progress item latest_attempt pointer'
Assert-Equal $activeLatestMismatch.reason 'active-attempt-latest-mismatch' 'Resume must identify stale active-attempt pointer before terminal reconciliation'

$structurallyBlockedResume = New-WorkItem 'WORK-ADMIN-STRUCTURAL-RESUME' 1 @() 'in-progress'
$structurallyBlockedResume.latest_attempt = 'ATTEMPT-WORK-ADMIN-STRUCTURAL-RESUME-01'
$structurallyBlockedResume.responsibility_conformance = 'BLOCKED'
$structurallyBlockedResume.responsibility_diagnostic = 'responsibility-owner-mismatch'
$structurallyBlockedResume.architecture_state = 'BLOCKED'
$structurallyBlockedResume.attempt_history = @(
  @{ attempt_id = 'ATTEMPT-WORK-ADMIN-STRUCTURAL-RESUME-01'; work_item_id = 'WORK-ADMIN-STRUCTURAL-RESUME'; plan_revision = 3; status = 'in-progress'; artifact_reference = 'runs/structural-resume-01.md' }
)
$blockedResumeSelection = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'select'; current_plan_revision = 3
  work_items = @($structurallyBlockedResume)
}
Assert-Equal $blockedResumeSelection.result 'scope-blocked' 'Structural assurance must stop an in-progress item before resume reconciliation'
Assert-Equal $blockedResumeSelection.reason 'responsibility-owner-mismatch' 'Blocked resume must preserve the responsibility diagnostic'
Assert-Equal $blockedResumeSelection.work_item_id '' 'Blocked in-progress work must not resume production'

$forgedReadyResume = New-WorkItem 'WORK-ADMIN-FORGED-READY-RESUME' 1 @() 'ready'
$forgedReadyResume.latest_attempt = 'ATTEMPT-WORK-ADMIN-FORGED-READY-RESUME-01'
$forgedReadyResume.attempt_history = @(
  @{ attempt_id = 'ATTEMPT-WORK-ADMIN-FORGED-READY-RESUME-01'; work_item_id = 'WORK-ADMIN-FORGED-READY-RESUME'; plan_revision = 3; status = 'in-progress'; artifact_reference = 'runs/forged-ready-resume-01.md' }
)
$forgedReadySelection = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'select'; current_plan_revision = 3
  work_items = @($forgedReadyResume)
}
Assert-Equal $forgedReadySelection.result 'plan-invalid' 'Selection must not choose an item that owns an active attempt under forged ready state'
Assert-Equal $forgedReadySelection.reason 'attempt-item-state-mismatch' 'Forged ready owner must fail active-attempt/item-state reconciliation'

# Attempt, work-item, and scope completion are independent outcomes.
$completeItem = New-WorkItem 'WORK-ADMIN-COMPLETE' 1 @() 'complete'
$completeItem.terminal_evidence = 'runs/complete.md'
$pendingItem = New-WorkItem 'WORK-ADMIN-PENDING' 2
$partialCompletion = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'
  operation = 'complete-scope'
  work_items = @($completeItem, $pendingItem)
}
Assert-Equal $partialCompletion.scope_status 'scope-in-progress' 'One complete item cannot complete a scope with required work pending'

$cancelled = New-WorkItem 'WORK-ADMIN-CANCELLED' 2 @() 'cancelled-approved'
$cancelled.terminal_evidence = 'decisions/cancelled.md'
$notApplicable = New-WorkItem 'WORK-ADMIN-NA' 3 @() 'not-applicable-approved'
$notApplicable.terminal_evidence = 'decisions/not-applicable.md'
$completeReview = New-ResponsibilityEvidenceArtifact 'runs/review-complete.md' $completeItem.work_item_id
$cancelledReview = New-ResponsibilityEvidenceArtifact 'runs/review-cancelled.md' $cancelled.work_item_id
$notApplicableReview = New-ResponsibilityEvidenceArtifact 'runs/review-not-applicable.md' $notApplicable.work_item_id
$completeChain = New-ResponsibilityChain 'runs/complete-chain' $completeItem.work_item_id
$cancelledChain = New-ResponsibilityChain 'runs/cancelled-chain' $cancelled.work_item_id
$notApplicableChain = New-ResponsibilityChain 'runs/not-applicable-chain' $notApplicable.work_item_id
$completeTerminal = New-TerminalResponsibilityArtifact $completeItem.terminal_evidence $completeItem.work_item_id $completeItem.status $completeChain.FinalReference $completeChain.References $completeChain.ModeConstraint
$cancelledTerminal = New-TerminalResponsibilityArtifact $cancelled.terminal_evidence $cancelled.work_item_id $cancelled.status $cancelledChain.FinalReference $cancelledChain.References $cancelledChain.ModeConstraint
$notApplicableTerminal = New-TerminalResponsibilityArtifact $notApplicable.terminal_evidence $notApplicable.work_item_id $notApplicable.status $notApplicableChain.FinalReference $notApplicableChain.References $notApplicableChain.ModeConstraint
$allCompleteReport = New-TerminalScopeReport 'runs/scope-terminal.md' @($completeItem, $cancelled, $notApplicable) @($completeChain, $cancelledChain, $notApplicableChain)
$allComplete = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'
  operation = 'complete-scope'
  work_items = @($completeItem, $cancelled, $notApplicable)
  terminal_artifacts = @($completeTerminal, $cancelledTerminal, $notApplicableTerminal)
  responsibility_chain_artifacts = @($completeChain.Artifacts + $cancelledChain.Artifacts + $notApplicableChain.Artifacts)
  terminal_scope_report = $allCompleteReport
}
Assert-Equal $allComplete.scope_status 'scope-complete' 'All required terminal-success items with scope evidence must complete the scope'

$mutatedHandoffTerminal = ($completeTerminal | ConvertTo-Json -Depth 20 | ConvertFrom-Json)
$mutatedHandoffTerminal.responsibility_handoff.evidence_reference = $completeChain.FinalReference
$mutatedHandoffCompletion = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'complete-scope'; work_items = @($completeItem)
  terminal_artifacts = @($mutatedHandoffTerminal); responsibility_chain_artifacts = @($completeChain.Artifacts)
  terminal_scope_report = (New-TerminalScopeReport 'runs/mutated-handoff-scope.md' @($completeItem) @($completeChain))
}
Assert-Equal $mutatedHandoffCompletion.scope_status 'scope-blocked' 'Terminal aggregation cannot replace immutable source-diff handoff evidence with the final KB artifact'

$mutatedChainReferenceTerminal = ($completeTerminal | ConvertTo-Json -Depth 20 | ConvertFrom-Json)
$mutatedChainReferenceTerminal.terminal_chain_reference = [string]$mutatedChainReferenceTerminal.responsibility_handoff.evidence_reference
$mutatedChainReferenceCompletion = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'complete-scope'; work_items = @($completeItem)
  terminal_artifacts = @($mutatedChainReferenceTerminal); responsibility_chain_artifacts = @($completeChain.Artifacts)
  terminal_scope_report = (New-TerminalScopeReport 'runs/mutated-chain-reference-scope.md' @($completeItem) @($completeChain))
}
Assert-Equal $mutatedChainReferenceCompletion.scope_status 'scope-blocked' 'Terminal chain reference cannot be substituted with immutable source-diff evidence'

$mutatedTerminalReport = New-TerminalScopeReport 'runs/mutated-terminal-report.md' @($completeItem) @($completeChain)
$mutatedTerminalReport.responsibility_handoff.evidence_references = @($completeChain.FinalReference)
$mutatedTerminalReportCompletion = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'complete-scope'; work_items = @($completeItem)
  terminal_artifacts = @($completeTerminal); responsibility_chain_artifacts = @($completeChain.Artifacts)
  terminal_scope_report = $mutatedTerminalReport
}
Assert-Equal $mutatedTerminalReportCompletion.scope_status 'scope-blocked' 'Terminal report handoff cannot mutate the preserved source-diff into a KB artifact reference'

$mutatedTerminalIndex = New-TerminalScopeReport 'runs/mutated-terminal-index.md' @($completeItem) @($completeChain)
$mutatedTerminalIndex.evidence_index[0].artifact_reference = [string]$completeChain.Artifacts[0].evidence_reference
$mutatedTerminalIndexCompletion = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'complete-scope'; work_items = @($completeItem)
  terminal_artifacts = @($completeTerminal); responsibility_chain_artifacts = @($completeChain.Artifacts)
  terminal_scope_report = $mutatedTerminalIndex
}
Assert-Equal $mutatedTerminalIndexCompletion.scope_status 'scope-blocked' 'Evidence Index must bind the final KB chain artifact, not duplicate source-diff handoff evidence'

$migrationUnitCompleteItem = New-WorkItem 'WORK-ADMIN-UNIT-COMPLETE' 1 @() 'complete'
$migrationUnitCompleteItem.adapter_kind = 'migration-unit'
$migrationUnitCompleteItem.external_id = 'UNIT-COMPLETE-001'
$migrationUnitCompleteItem.terminal_evidence = 'runs/unit-complete.md'
$migrationUnitCompleteChain = New-ResponsibilityChain 'runs/unit-complete-chain' $migrationUnitCompleteItem.work_item_id
$migrationUnitCompleteTerminal = New-TerminalResponsibilityArtifact $migrationUnitCompleteItem.terminal_evidence $migrationUnitCompleteItem.work_item_id $migrationUnitCompleteItem.status $migrationUnitCompleteChain.FinalReference $migrationUnitCompleteChain.References $migrationUnitCompleteChain.ModeConstraint $migrationUnitCompleteItem.external_id
$migrationUnitScopeComplete = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'complete-scope'; work_items = @($migrationUnitCompleteItem)
  terminal_artifacts = @($migrationUnitCompleteTerminal)
  responsibility_chain_artifacts = @($migrationUnitCompleteChain.Artifacts)
  terminal_scope_report = (New-TerminalScopeReport 'runs/unit-complete-scope.md' @($migrationUnitCompleteItem) @($migrationUnitCompleteChain))
}
Assert-Equal $migrationUnitScopeComplete.scope_status 'scope-complete' 'Scope completion must accept Task / Unit derived from the approved migration-unit selector'

$migrationUnitWrongCompletionTerminal = New-TerminalResponsibilityArtifact $migrationUnitCompleteItem.terminal_evidence $migrationUnitCompleteItem.work_item_id $migrationUnitCompleteItem.status $migrationUnitCompleteChain.FinalReference $migrationUnitCompleteChain.References $migrationUnitCompleteChain.ModeConstraint $migrationUnitCompleteItem.work_item_id
$migrationUnitWrongScopeComplete = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'complete-scope'; work_items = @($migrationUnitCompleteItem)
  terminal_artifacts = @($migrationUnitWrongCompletionTerminal)
  responsibility_chain_artifacts = @($migrationUnitCompleteChain.Artifacts)
  terminal_scope_report = (New-TerminalScopeReport 'runs/unit-wrong-scope.md' @($migrationUnitCompleteItem) @($migrationUnitCompleteChain))
}
Assert-Equal $migrationUnitWrongScopeComplete.scope_status 'scope-blocked' 'Scope completion must reject Work Item ID substituted for migration-unit Task / Unit authority'

$forgedInitialCompletionChain = New-ResponsibilityChain 'runs/forged-initial-completion-chain' $completeItem.work_item_id
$forgedInitialCompletionChain.Artifacts[0].source_artifact_reference = 'forged-predecessor.md'
$forgedInitialCompletionTerminal = New-TerminalResponsibilityArtifact $completeItem.terminal_evidence $completeItem.work_item_id $completeItem.status $forgedInitialCompletionChain.FinalReference $forgedInitialCompletionChain.References $forgedInitialCompletionChain.ModeConstraint
$forgedInitialCompletion = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'complete-scope'; work_items = @($completeItem)
  terminal_artifacts = @($forgedInitialCompletionTerminal)
  responsibility_chain_artifacts = @($forgedInitialCompletionChain.Artifacts)
  terminal_scope_report = (New-TerminalScopeReport 'runs/forged-initial-completion-report.md' @($completeItem) @($forgedInitialCompletionChain))
}
Assert-Equal $forgedInitialCompletion.scope_status 'scope-blocked' 'Scope completion must reject a forged index-0 implementation predecessor'

$allNodeForgedCompletionChain = New-ResponsibilityChain 'runs/all-node-forged-completion-chain' $completeItem.work_item_id
foreach ($artifact in @($allNodeForgedCompletionChain.Artifacts)) {
  $artifact.task_base_sha = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
  $artifact.final_tree_sha = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
  $artifact.evidence_reference = "source-diff:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa..bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb#$($completeItem.work_item_id)"
}
$allNodeForgedCompletionTerminal = New-TerminalResponsibilityArtifact $completeItem.terminal_evidence $completeItem.work_item_id $completeItem.status $allNodeForgedCompletionChain.FinalReference $allNodeForgedCompletionChain.References $allNodeForgedCompletionChain.ModeConstraint
$allNodeForgedCompletion = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'complete-scope'; work_items = @($completeItem)
  terminal_artifacts = @($allNodeForgedCompletionTerminal)
  responsibility_chain_artifacts = @($allNodeForgedCompletionChain.Artifacts)
  terminal_scope_report = (New-TerminalScopeReport 'runs/all-node-forged-completion-report.md' @($completeItem) @($allNodeForgedCompletionChain))
}
Assert-Equal $allNodeForgedCompletion.scope_status 'scope-blocked' 'Scope completion must bind every chain SHA/evidence pair to immutable Task Provenance'

foreach ($terminalStringImmutableCase in @('terminal-report', 'terminal-artifact', 'terminal-chain-node')) {
  $stringImmutableChain = New-ResponsibilityChain "runs/string-immutable-$terminalStringImmutableCase-chain" $completeItem.work_item_id
  $stringImmutableTerminal = New-TerminalResponsibilityArtifact $completeItem.terminal_evidence $completeItem.work_item_id $completeItem.status $stringImmutableChain.FinalReference $stringImmutableChain.References $stringImmutableChain.ModeConstraint
  $stringImmutableReport = New-TerminalScopeReport "runs/string-immutable-$terminalStringImmutableCase-report.md" @($completeItem) @($stringImmutableChain)
  switch ($terminalStringImmutableCase) {
    'terminal-report' { $stringImmutableReport.immutable = 'false' }
    'terminal-artifact' { $stringImmutableTerminal.immutable = 'false' }
    'terminal-chain-node' { $stringImmutableChain.Artifacts[2].immutable = 'false' }
  }
  $stringImmutableCompletion = Invoke-ScopeScenario @{
    scenario_type = 'scope-engine'; operation = 'complete-scope'; work_items = @($completeItem)
    terminal_artifacts = @($stringImmutableTerminal)
    responsibility_chain_artifacts = @($stringImmutableChain.Artifacts)
    terminal_scope_report = $stringImmutableReport
  }
  Assert-Equal $stringImmutableCompletion.scope_status 'scope-blocked' "String false immutable must reject at complete-scope $terminalStringImmutableCase authority"
}

$missingEvidenceIndexReport = New-TerminalScopeReport 'runs/scope-terminal-missing-index.md' @($completeItem) @($completeChain) $false
$missingEvidenceIndex = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'complete-scope'
  work_items = @($completeItem)
  terminal_artifacts = @($completeTerminal)
  responsibility_chain_artifacts = @($completeChain.Artifacts)
  terminal_scope_report = $missingEvidenceIndexReport
}
Assert-Equal $missingEvidenceIndex.scope_status 'scope-blocked' 'Scope completion must require the terminal Evidence Index'
Assert-Equal $missingEvidenceIndex.reason 'structural-assurance-blocked' 'A missing Evidence Index must fail the canonical structural terminal gate'

$corruptEvidenceIndexReport = New-TerminalScopeReport 'runs/scope-terminal-corrupt-index.md' @($completeItem) @($completeChain)
$corruptEvidenceIndexReport.evidence_index[0].purpose = 'caller-attested-summary'
$corruptEvidenceIndex = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'complete-scope'
  work_items = @($completeItem)
  terminal_artifacts = @($completeTerminal)
  responsibility_chain_artifacts = @($completeChain.Artifacts)
  terminal_scope_report = $corruptEvidenceIndexReport
}
Assert-Equal $corruptEvidenceIndex.scope_status 'scope-blocked' 'Evidence Index purpose and mapping must be exact'
Assert-Equal $corruptEvidenceIndex.reason 'structural-assurance-blocked' 'A corrupt Evidence Index must fail the structural terminal gate'

$directReviewOnlyTerminal = New-TerminalResponsibilityArtifact $completeItem.terminal_evidence $completeItem.work_item_id $completeItem.status $completeReview.artifact_reference
$directReviewOnlyTerminal.mode_constraint = 'incremental/preserve-existing'
$directReviewOnlyTerminal.responsibility_chain_references = @($completeReview.artifact_reference)
$directReviewOnlyCompletion = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'
  operation = 'complete-scope'
  work_items = @($completeItem)
  terminal_artifacts = @($directReviewOnlyTerminal)
  responsibility_evidence_artifacts = @($completeReview)
  terminal_scope_report = @{
    artifact_reference = 'runs/scope-terminal-direct-review.md'
    artifact_type = 'migration-scope-terminal-report'
    master_plan_ref = 'runs/master-plan@3.md'
    master_plan_revision = 3
    immutable = $true
    responsibility_handoff = @{
      responsibility_contract_version = 1
      tree_conformance = 'PASS'
      responsibility_conformance = 'PASS'
      verification_ownership = 'PASS'
      architecture_state = 'PASS'
      evidence_references = @('runs/complete.md')
    }
    items = @(
      @{ work_item_id = 'WORK-ADMIN-COMPLETE'; status = 'complete'; terminal_evidence = 'runs/complete.md'; architecture_state = 'PASS'; selector_schema_state = 'PASS' }
    )
  }
}
Assert-Equal $directReviewOnlyCompletion.scope_status 'scope-blocked' 'A direct review reference cannot replace the ordered verification/parity/regression/KB terminal chain'
Assert-Equal $directReviewOnlyCompletion.reason 'structural-assurance-blocked' 'An incomplete terminal responsibility chain must emit the structural diagnostic'

$missingV1Terminal = New-TerminalResponsibilityArtifact $completeItem.terminal_evidence $completeItem.work_item_id $completeItem.status $completeChain.FinalReference $completeChain.References $completeChain.ModeConstraint
$missingV1Terminal.Remove('responsibility_handoff')
$missingV1Completion = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'
  operation = 'complete-scope'
  work_items = @($completeItem)
  terminal_artifacts = @($missingV1Terminal)
  responsibility_chain_artifacts = @($completeChain.Artifacts)
  terminal_scope_report = @{
    artifact_reference = 'runs/scope-terminal-missing-v1.md'
    artifact_type = 'migration-scope-terminal-report'
    master_plan_ref = 'runs/master-plan@3.md'
    master_plan_revision = 3
    immutable = $true
    responsibility_handoff = @{
      responsibility_contract_version = 1
      tree_conformance = 'PASS'
      responsibility_conformance = 'PASS'
      verification_ownership = 'PASS'
      architecture_state = 'PASS'
      evidence_references = @($completeChain.FinalReference)
    }
    items = @(
      @{ work_item_id = 'WORK-ADMIN-COMPLETE'; status = 'complete'; terminal_evidence = 'runs/complete.md'; architecture_state = 'PASS'; selector_schema_state = 'PASS' }
    )
  }
}
Assert-Equal $missingV1Completion.scope_status 'scope-blocked' 'A terminal artifact without the exact v1 responsibility handoff cannot complete scope'
Assert-Equal $missingV1Completion.reason 'structural-assurance-blocked' 'Missing v1 terminal responsibility provenance must emit the structural diagnostic'

$mixedVersionTerminal = New-TerminalResponsibilityArtifact $completeItem.terminal_evidence $completeItem.work_item_id $completeItem.status $completeChain.FinalReference $completeChain.References $completeChain.ModeConstraint
$mixedVersionTerminal.responsibility_handoff.responsibility_contract_version = 2
$mixedVersionCompletion = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'
  operation = 'complete-scope'
  work_items = @($completeItem)
  terminal_artifacts = @($mixedVersionTerminal)
  responsibility_chain_artifacts = @($completeChain.Artifacts)
  terminal_scope_report = @{
    artifact_reference = 'runs/scope-terminal-mixed-v1-v2.md'
    artifact_type = 'migration-scope-terminal-report'
    master_plan_ref = 'runs/master-plan@3.md'
    master_plan_revision = 3
    immutable = $true
    responsibility_handoff = @{
      responsibility_contract_version = 1
      tree_conformance = 'PASS'
      responsibility_conformance = 'PASS'
      verification_ownership = 'PASS'
      architecture_state = 'PASS'
      evidence_references = @($completeChain.FinalReference)
    }
    items = @(
      @{ work_item_id = 'WORK-ADMIN-COMPLETE'; status = 'complete'; terminal_evidence = 'runs/complete.md'; architecture_state = 'PASS'; selector_schema_state = 'PASS' }
    )
  }
}
Assert-Equal $mixedVersionCompletion.scope_status 'scope-blocked' 'Mixed v1/v2 terminal evidence cannot complete scope'
Assert-Equal $mixedVersionCompletion.reason 'structural-assurance-blocked' 'Mixed responsibility versions must emit the structural diagnostic'

$selfLabeledGreenfieldChain = New-ResponsibilityChain 'runs/self-labeled-greenfield-chain' $completeItem.work_item_id 'greenfield/design-new'
$selfLabeledGreenfieldTerminal = New-TerminalResponsibilityArtifact $completeItem.terminal_evidence $completeItem.work_item_id $completeItem.status $selfLabeledGreenfieldChain.FinalReference $selfLabeledGreenfieldChain.References 'greenfield/design-new'
$selfLabeledGreenfield = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'complete-scope'
  work_items = @($completeItem)
  terminal_artifacts = @($selfLabeledGreenfieldTerminal)
  responsibility_chain_artifacts = @($selfLabeledGreenfieldChain.Artifacts)
  terminal_scope_report = (New-TerminalScopeReport 'runs/scope-terminal-self-labeled-greenfield.md' @($completeItem) @($selfLabeledGreenfieldChain))
}
Assert-Equal $selfLabeledGreenfield.scope_status 'scope-blocked' 'An incremental approved work item cannot self-label greenfield to omit regression'
Assert-Equal $selfLabeledGreenfield.reason 'structural-assurance-blocked' 'Mode/chain mismatch must fail the structural terminal gate'

$approvedGreenfieldItem = New-WorkItem 'WORK-ADMIN-GREENFIELD' 1 @() 'complete'
$approvedGreenfieldItem.mode_constraint = 'greenfield/design-new'
$approvedGreenfieldItem.terminal_evidence = 'runs/greenfield-terminal.md'
$approvedGreenfieldChain = New-ResponsibilityChain 'runs/approved-greenfield-chain' $approvedGreenfieldItem.work_item_id $approvedGreenfieldItem.mode_constraint
$approvedGreenfieldTerminal = New-TerminalResponsibilityArtifact $approvedGreenfieldItem.terminal_evidence $approvedGreenfieldItem.work_item_id $approvedGreenfieldItem.status $approvedGreenfieldChain.FinalReference $approvedGreenfieldChain.References $approvedGreenfieldItem.mode_constraint
$approvedGreenfield = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'complete-scope'
  work_items = @($approvedGreenfieldItem)
  terminal_artifacts = @($approvedGreenfieldTerminal)
  responsibility_chain_artifacts = @($approvedGreenfieldChain.Artifacts)
  terminal_scope_report = (New-TerminalScopeReport 'runs/scope-terminal-approved-greenfield.md' @($approvedGreenfieldItem) @($approvedGreenfieldChain))
}
Assert-Equal $approvedGreenfield.scope_status 'scope-complete' 'An authoritative greenfield work item must use the legitimate four-stage terminal chain'

foreach ($lifecycleMutation in @(
  @{ Name = 'result'; Field = 'result'; Value = 'partial' },
  @{ Name = 'approval-source'; Field = 'approval_source'; Value = 'automation' },
  @{ Name = 'status'; Field = 'status'; Value = 'draft' }
)) {
  $lifecycleChain = New-ResponsibilityChain "runs/lifecycle-$($lifecycleMutation.Name)-chain" $completeItem.work_item_id
  $lifecycleChain.Artifacts[0][$lifecycleMutation.Field] = $lifecycleMutation.Value
  $lifecycleTerminal = New-TerminalResponsibilityArtifact $completeItem.terminal_evidence $completeItem.work_item_id $completeItem.status $lifecycleChain.FinalReference $lifecycleChain.References $lifecycleChain.ModeConstraint
  $lifecycleCompletion = Invoke-ScopeScenario @{
    scenario_type = 'scope-engine'; operation = 'complete-scope'
    work_items = @($completeItem)
    terminal_artifacts = @($lifecycleTerminal)
    responsibility_chain_artifacts = @($lifecycleChain.Artifacts)
    terminal_scope_report = (New-TerminalScopeReport "runs/scope-terminal-lifecycle-$($lifecycleMutation.Name).md" @($completeItem) @($lifecycleChain))
  }
  Assert-Equal $lifecycleCompletion.scope_status 'scope-blocked' "Initial review $($lifecycleMutation.Name) must be approved/complete/human"
}

foreach ($chainIndex in 1..4) {
 foreach ($lifecycleMutation in @(
    @{ Name = 'status'; Field = 'status'; Value = 'draft' },
    @{ Name = 'result'; Field = 'result'; Value = 'partial' },
    @{ Name = 'approval-source'; Field = 'approval_source'; Value = 'automation' }
  )) {
  $downstreamLifecycleChain = New-ResponsibilityChain "runs/downstream-lifecycle-$chainIndex-$($lifecycleMutation.Name)-chain" $completeItem.work_item_id
  $downstreamLifecycleChain.Artifacts[$chainIndex][$lifecycleMutation.Field] = $lifecycleMutation.Value
  $downstreamLifecycleTerminal = New-TerminalResponsibilityArtifact $completeItem.terminal_evidence $completeItem.work_item_id $completeItem.status $downstreamLifecycleChain.FinalReference $downstreamLifecycleChain.References $downstreamLifecycleChain.ModeConstraint
  $downstreamLifecycleCompletion = Invoke-ScopeScenario @{
    scenario_type = 'scope-engine'; operation = 'complete-scope'
    work_items = @($completeItem)
    terminal_artifacts = @($downstreamLifecycleTerminal)
    responsibility_chain_artifacts = @($downstreamLifecycleChain.Artifacts)
    terminal_scope_report = (New-TerminalScopeReport "runs/scope-terminal-downstream-lifecycle-$chainIndex-$($lifecycleMutation.Name).md" @($completeItem) @($downstreamLifecycleChain))
  }
  Assert-Equal $downstreamLifecycleCompletion.scope_status 'scope-blocked' "Every downstream assurance chain node $chainIndex must reject $($lifecycleMutation.Name)"
 }
}

$sourceDiffMismatchChain = New-ResponsibilityChain 'runs/source-diff-mismatch-chain' $completeItem.work_item_id
foreach ($artifact in @($sourceDiffMismatchChain.Artifacts)) {
  $artifact.evidence_reference = "source-diff:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa..bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb#$($completeItem.work_item_id)"
}
$sourceDiffMismatchTerminal = New-TerminalResponsibilityArtifact $completeItem.terminal_evidence $completeItem.work_item_id $completeItem.status $sourceDiffMismatchChain.FinalReference $sourceDiffMismatchChain.References $sourceDiffMismatchChain.ModeConstraint
$sourceDiffMismatchCompletion = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'complete-scope'
  work_items = @($completeItem)
  terminal_artifacts = @($sourceDiffMismatchTerminal)
  responsibility_chain_artifacts = @($sourceDiffMismatchChain.Artifacts)
  terminal_scope_report = (New-TerminalScopeReport 'runs/scope-terminal-source-diff-mismatch.md' @($completeItem) @($sourceDiffMismatchChain))
}
Assert-Equal $sourceDiffMismatchCompletion.scope_status 'scope-blocked' 'Source-diff SHA pair must equal immutable Task Provenance SHAs'

$crossRunChain = New-ResponsibilityChain 'runs/cross-run-chain' $completeItem.work_item_id
foreach ($artifact in @($crossRunChain.Artifacts)) { $artifact.run_id = 'RUN-FOREIGN-999' }
$crossRunTerminal = New-TerminalResponsibilityArtifact $completeItem.terminal_evidence $completeItem.work_item_id $completeItem.status $crossRunChain.FinalReference $crossRunChain.References $crossRunChain.ModeConstraint
$crossRunCompletion = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'complete-scope'
  work_items = @($completeItem)
  terminal_artifacts = @($crossRunTerminal)
  responsibility_chain_artifacts = @($crossRunChain.Artifacts)
  terminal_scope_report = (New-TerminalScopeReport 'runs/scope-terminal-cross-run.md' @($completeItem) @($crossRunChain))
}
Assert-Equal $crossRunCompletion.scope_status 'scope-blocked' 'A digest-valid responsibility chain from another run cannot complete scope'

$foreignPlanChain = New-ResponsibilityChain 'runs/foreign-plan-chain' $completeItem.work_item_id
foreach ($artifact in @($foreignPlanChain.Artifacts)) { $artifact.master_plan_ref = 'runs/foreign-master-plan.md' }
$foreignPlanTerminal = New-TerminalResponsibilityArtifact $completeItem.terminal_evidence $completeItem.work_item_id $completeItem.status $foreignPlanChain.FinalReference $foreignPlanChain.References $foreignPlanChain.ModeConstraint
$foreignPlanCompletion = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'complete-scope'
  work_items = @($completeItem)
  terminal_artifacts = @($foreignPlanTerminal)
  responsibility_chain_artifacts = @($foreignPlanChain.Artifacts)
  terminal_scope_report = (New-TerminalScopeReport 'runs/scope-terminal-foreign-plan.md' @($completeItem) @($foreignPlanChain))
}
Assert-Equal $foreignPlanCompletion.scope_status 'scope-blocked' 'Responsibility artifacts must bind the current approved master plan'

$optionalBlocker = New-WorkItem 'WORK-ADMIN-OPTIONAL-BLOCKED' 4 @() 'blocked' $false
$optionalBlocker.has_blocker = $true
$blockedCompletion = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'
  operation = 'complete-scope'
  work_items = @($completeItem, $optionalBlocker)
}
Assert-Equal $blockedCompletion.scope_status 'scope-blocked' 'Any remaining blocker must prevent requested-scope completion'

$completionMissingDependency = New-WorkItem 'WORK-ADMIN-COMPLETE-MISSING' 1 @('WORK-ADMIN-NOT-IN-PLAN') 'complete'
$completionMissingDependency.terminal_evidence = 'runs/missing-dependency.md'
$missingDependencyCompletion = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'
  operation = 'complete-scope'
  graph_valid = $true
  terminal_scope_report_complete = $true
  work_items = @($completionMissingDependency)
  terminal_scope_report = @{
    artifact_reference = 'runs/claimed-complete.md'; immutable = $true
    items = @(
      @{ work_item_id = 'WORK-ADMIN-COMPLETE-MISSING'; status = 'complete'; terminal_evidence = 'runs/missing-dependency.md'; architecture_state = 'PASS'; selector_schema_state = 'PASS' }
    )
  }
}
Assert-Equal $missingDependencyCompletion.scope_status 'scope-blocked' 'Completion must calculate and reject a missing dependency regardless caller flags'
Assert-Equal $missingDependencyCompletion.reason 'missing-dependency' 'Completion must report graph evidence failure'

$completionCycleA = New-WorkItem 'WORK-ADMIN-COMPLETE-CYCLE-A' 1 @('WORK-ADMIN-COMPLETE-CYCLE-B') 'complete'
$completionCycleA.terminal_evidence = 'runs/cycle-a.md'
$completionCycleB = New-WorkItem 'WORK-ADMIN-COMPLETE-CYCLE-B' 2 @('WORK-ADMIN-COMPLETE-CYCLE-A') 'complete'
$completionCycleB.terminal_evidence = 'runs/cycle-b.md'
$cycleCompletion = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'
  operation = 'complete-scope'
  graph_valid = $true
  terminal_scope_report_complete = $true
  work_items = @($completionCycleA, $completionCycleB)
  terminal_scope_report = @{ artifact_reference = 'runs/claimed-cycle-complete.md'; immutable = $true; items = @() }
}
Assert-Equal $cycleCompletion.scope_status 'scope-blocked' 'Completion must calculate and reject dependency cycles regardless caller flags'
Assert-Equal $cycleCompletion.reason 'dependency-cycle' 'Completion must report dependency-cycle evidence failure'

$incompleteReport = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'
  operation = 'complete-scope'
  graph_valid = $true
  terminal_scope_report_complete = $true
  work_items = @($completeItem, $cancelled)
  terminal_scope_report = @{
    artifact_reference = 'runs/incomplete-scope-report.md'; artifact_type = 'migration-scope-terminal-report'; master_plan_ref = 'runs/master-plan@3.md'; master_plan_revision = 3; immutable = $true
    items = @(
      @{ work_item_id = 'WORK-ADMIN-COMPLETE'; status = 'complete'; terminal_evidence = 'runs/complete.md'; architecture_state = 'PASS'; selector_schema_state = 'PASS' }
    )
  }
}
Assert-Equal $incompleteReport.scope_status 'scope-blocked' 'Terminal scope report must enumerate every required item and evidence'
Assert-Equal $incompleteReport.reason 'terminal-scope-report-id-set-mismatch' 'Missing report row must block exact terminal-report ID binding'

$optionalTerminal = New-WorkItem 'WORK-ADMIN-OPTIONAL-TERMINAL' 2 @() 'complete' $false
$optionalTerminal.optional_execution_approved = $true
$optionalTerminal.terminal_evidence = 'runs/optional-terminal.md'
$missingOptionalReportRow = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'complete-scope'
  work_items = @($completeItem, $optionalTerminal)
  terminal_scope_report = @{
    artifact_reference = 'runs/missing-optional-report.md'; artifact_type = 'migration-scope-terminal-report'; master_plan_ref = 'runs/master-plan@3.md'; master_plan_revision = 3; immutable = $true
    items = @(
      @{ work_item_id = 'WORK-ADMIN-COMPLETE'; status = 'complete'; terminal_evidence = 'runs/complete.md'; architecture_state = 'PASS'; selector_schema_state = 'PASS' }
    )
  }
}
Assert-Equal $missingOptionalReportRow.scope_status 'scope-blocked' 'Terminal scope report must enumerate exact approved plan rows, including approved optional execution'
Assert-Equal $missingOptionalReportRow.reason 'terminal-scope-report-id-set-mismatch' 'Omitted optional approved row must block exact report binding'

$planCompleteA = New-WorkItem 'WORK-ADMIN-PLAN-A' 1 @() 'complete'
$planCompleteA.terminal_evidence = 'runs/plan-a.md'
$planCompleteB = New-WorkItem 'WORK-ADMIN-PLAN-B' 2 @() 'complete'
$planCompleteB.terminal_evidence = 'runs/plan-b.md'
$subsetCompletionContext = New-ApprovedOrchestrationContext
$subsetCompletionContext.plan_revisions[2].work_items = @($planCompleteA, $planCompleteB)
$subsetCompletionContext.resolved_artifacts = @(
  @{ artifact_reference = 'runs/subset-report.md'; immutable = $true; artifact_type = 'migration-scope-terminal-report'; master_plan_ref = 'runs/master-plan@3.md'; master_plan_revision = 3; items = @(
    @{ work_item_id = 'WORK-ADMIN-PLAN-A'; status = 'complete'; terminal_evidence = 'runs/plan-a.md'; architecture_state = 'PASS'; selector_schema_state = 'PASS' }
  ) }
)
$subsetCompletion = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'complete-scope'; current_plan_revision = 3
  orchestration_context = $subsetCompletionContext
  work_items = @($planCompleteA)
  terminal_scope_report_ref = 'runs/subset-report.md'
  terminal_scope_report_complete = $true
}
Assert-Equal $subsetCompletion.result 'orchestration-blocked' 'Completion must reject a caller subset that omits a required approved plan row'
Assert-Equal $subsetCompletion.reason 'work-items-not-bound-to-master-plan' 'Omitted required item must fail at plan-row binding gate'

$reportBoundContext = New-ApprovedOrchestrationContext
$reportBoundContext.plan_revisions[2].work_items = @($planCompleteA)
$reportBoundContext.resolved_artifacts = @()
$forgedTerminalReport = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'complete-scope'; current_plan_revision = 3
  orchestration_context = $reportBoundContext
  work_items = @($planCompleteA)
  terminal_scope_report_ref = 'runs/forged-report.md'
  terminal_scope_report = @{
    artifact_reference = 'runs/forged-report.md'; immutable = $true
    items = @(
      @{ work_item_id = 'WORK-ADMIN-PLAN-A'; status = 'complete'; terminal_evidence = 'runs/plan-a.md'; architecture_state = 'PASS'; selector_schema_state = 'PASS' }
    )
  }
}
Assert-Equal $forgedTerminalReport.scope_status 'scope-blocked' 'Completion must resolve terminal report by exact registry reference'
Assert-Equal $forgedTerminalReport.reason 'terminal-scope-report-resolution-invalid' 'Caller-injected terminal report object must not be trusted'

$supersetTerminalReport = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'complete-scope'
  work_items = @($planCompleteA)
  terminal_scope_report = @{
    artifact_reference = 'runs/superset-scope-report.md'; artifact_type = 'migration-scope-terminal-report'; master_plan_ref = 'runs/master-plan@3.md'; master_plan_revision = 3; immutable = $true
    items = @(
      @{ work_item_id = 'WORK-ADMIN-PLAN-A'; status = 'complete'; terminal_evidence = 'runs/plan-a.md'; architecture_state = 'PASS'; selector_schema_state = 'PASS' },
      @{ work_item_id = 'WORK-ADMIN-FORGED'; status = 'complete'; terminal_evidence = 'runs/forged.md'; architecture_state = 'PASS'; selector_schema_state = 'PASS' }
    )
  }
}
Assert-Equal $supersetTerminalReport.scope_status 'scope-blocked' 'Registered terminal report must reject an extra forged Work Item ID'
Assert-Equal $supersetTerminalReport.reason 'terminal-scope-report-id-set-mismatch' 'Terminal report superset must fail exact bidirectional ID-set binding'

$duplicateTerminalReport = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'complete-scope'
  work_items = @($planCompleteA)
  terminal_scope_report = @{
    artifact_reference = 'runs/duplicate-scope-report.md'; artifact_type = 'migration-scope-terminal-report'; master_plan_ref = 'runs/master-plan@3.md'; master_plan_revision = 3; immutable = $true
    items = @(
      @{ work_item_id = 'WORK-ADMIN-PLAN-A'; status = 'complete'; terminal_evidence = 'runs/plan-a.md'; architecture_state = 'PASS'; selector_schema_state = 'PASS' },
      @{ work_item_id = 'WORK-ADMIN-PLAN-A'; status = 'complete'; terminal_evidence = 'runs/plan-a.md'; architecture_state = 'PASS'; selector_schema_state = 'PASS' }
    )
  }
}
Assert-Equal $duplicateTerminalReport.scope_status 'scope-blocked' 'Registered terminal report must reject duplicate Work Item IDs'
Assert-Equal $duplicateTerminalReport.reason 'terminal-scope-report-id-set-mismatch' 'Terminal report duplicate rows must fail exact cardinality binding'

$retryItem = New-WorkItem 'WORK-ADMIN-RETRY' 1
$retryItem.latest_attempt = 'ATTEMPT-WORK-ADMIN-RETRY-02'
$retryItem.attempt_history = @(
  @{ attempt_id = 'ATTEMPT-WORK-ADMIN-RETRY-01'; work_item_id = 'WORK-ADMIN-RETRY'; plan_revision = 2; status = 'blocked'; artifact_reference = 'runs/retry-01.md' },
  @{ attempt_id = 'ATTEMPT-WORK-ADMIN-RETRY-02'; work_item_id = 'WORK-ADMIN-RETRY'; plan_revision = 3; status = 'blocked'; artifact_reference = 'runs/retry-02.md' }
)
$retryStart = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'
  operation = 'transition'
  current_plan_revision = 3
  transition = 'start-attempt'
  work_item_id = 'WORK-ADMIN-RETRY'
  attempt_id = 'ATTEMPT-WORK-ADMIN-RETRY-03'
  work_items = @($retryItem)
}
Assert-Equal $retryStart.result 'transitioned' 'A new immutable attempt may follow prior attempt history'
Assert-Equal $retryStart.attempt_id 'ATTEMPT-WORK-ADMIN-RETRY-03' 'Retry must append the new attempt ID'

$overwriteAttempt = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'
  operation = 'transition'
  current_plan_revision = 3
  transition = 'start-attempt'
  work_item_id = 'WORK-ADMIN-RETRY'
  attempt_id = 'ATTEMPT-WORK-ADMIN-RETRY-01'
  work_items = @($retryItem)
}
Assert-Equal $overwriteAttempt.result 'transition-invalid' 'Attempt history must reject overwriting an existing attempt ID'
Assert-Equal $overwriteAttempt.reason 'attempt-id-already-exists' 'Attempt overwrite must report its exact reason'

$pendingStartItem = New-WorkItem 'WORK-ADMIN-PENDING-START' 1 @() 'pending'
$pendingStart = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'
  operation = 'transition'
  current_plan_revision = 3
  transition = 'start-attempt'
  work_item_id = 'WORK-ADMIN-PENDING-START'
  attempt_id = 'ATTEMPT-WORK-ADMIN-PENDING-START-01'
  work_items = @($pendingStartItem)
}
Assert-Equal $pendingStart.result 'transitioned' 'Selected pending item must atomically become ready before attempt start'
Assert-Equal $pendingStart.readiness_transition 'pending-to-ready' 'Pending eligibility must have an explicit readiness transition'

$otherRunning = New-WorkItem 'WORK-ADMIN-OTHER-RUNNING' 2 @() 'in-progress'
$otherRunning.latest_attempt = 'ATTEMPT-WORK-ADMIN-OTHER-RUNNING-01'
$otherRunning.attempt_history = @(
  @{ attempt_id = 'ATTEMPT-WORK-ADMIN-OTHER-RUNNING-01'; work_item_id = 'WORK-ADMIN-OTHER-RUNNING'; plan_revision = 3; status = 'in-progress'; artifact_reference = 'runs/other-running-01.md' }
)
$concurrentStartItem = New-WorkItem 'WORK-ADMIN-CONCURRENT' 1
$concurrentStart = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'
  operation = 'transition'
  current_plan_revision = 3
  transition = 'start-attempt'
  work_item_id = 'WORK-ADMIN-CONCURRENT'
  attempt_id = 'ATTEMPT-WORK-ADMIN-CONCURRENT-01'
  work_items = @($concurrentStartItem, $otherRunning)
}
Assert-Equal $concurrentStart.result 'transition-invalid' 'Attempt start must reject a second globally in-progress item'
Assert-Equal $concurrentStart.reason 'another-attempt-in-progress' 'Concurrent attempt start must report max-concurrency violation'

$forgedReadyActive = New-WorkItem 'WORK-ADMIN-FORGED-READY-ACTIVE' 1 @() 'ready'
$forgedReadyActive.latest_attempt = 'ATTEMPT-WORK-ADMIN-FORGED-READY-ACTIVE-01'
$forgedReadyActive.attempt_history = @(
  @{ attempt_id = 'ATTEMPT-WORK-ADMIN-FORGED-READY-ACTIVE-01'; work_item_id = 'WORK-ADMIN-FORGED-READY-ACTIVE'; plan_revision = 3; status = 'in-progress'; artifact_reference = 'runs/forged-ready-active-01.md' }
)
$sameItemSecondStart = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'transition'; current_plan_revision = 3
  transition = 'start-attempt'; work_item_id = 'WORK-ADMIN-FORGED-READY-ACTIVE'; attempt_id = 'ATTEMPT-WORK-ADMIN-FORGED-READY-ACTIVE-02'
  work_items = @($forgedReadyActive)
}
Assert-Equal $sameItemSecondStart.result 'transition-invalid' 'Attempt start must count active history even when the same item state is forged ready'
Assert-Equal $sameItemSecondStart.reason 'another-attempt-in-progress' 'Same-item second active attempt must be rejected explicitly'

$transitionCurrent = New-WorkItem 'WORK-ADMIN-CURRENT' 1 @() 'in-progress'
$transitionCurrent.latest_attempt = 'ATTEMPT-WORK-ADMIN-CURRENT-01'
$transitionCurrent.attempt_history = @(
  @{ attempt_id = 'ATTEMPT-WORK-ADMIN-CURRENT-01'; work_item_id = 'WORK-ADMIN-CURRENT'; plan_revision = 3; status = 'in-progress'; artifact_reference = 'runs/current-01-in-progress.md' }
)
$transitionNext = New-WorkItem 'WORK-ADMIN-NEXT' 2
$transitionChain = New-ResponsibilityChain 'runs/current-transition-chain' $transitionCurrent.work_item_id $transitionCurrent.mode_constraint
$transitionTerminal = New-TerminalResponsibilityArtifact 'runs/current-01.md' $transitionCurrent.work_item_id 'complete' $transitionChain.FinalReference $transitionChain.References $transitionChain.ModeConstraint
$transitionTerminal.attempt_id = 'ATTEMPT-WORK-ADMIN-CURRENT-01'
$transitionTerminal.result = 'complete'
$transition = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'
  operation = 'transition'
  current_plan_revision = 3
  transition = 'successful-terminal-artifact'
  work_item_id = 'WORK-ADMIN-CURRENT'
  attempt_id = 'ATTEMPT-WORK-ADMIN-CURRENT-01'
  terminal_evidence = 'runs/current-01.md'
  terminal_evidence_valid = $true
  terminal_artifact = $transitionTerminal
  responsibility_chain_artifacts = @($transitionChain.Artifacts)
  work_items = @($transitionCurrent, $transitionNext)
}
Assert-Equal $transition.result 'transitioned' 'Valid terminal evidence must atomically finish the attempt and item'
Assert-Equal $transition.attempt_status 'complete' 'Attempt completion must be explicit'
Assert-Equal $transition.work_item_status 'complete' 'Work-item completion must be explicit'
Assert-Equal $transition.scope_status 'scope-in-progress' 'Attempt completion must not imply requested-scope completion'
Assert-Equal $transition.terminal_evidence 'runs/current-01.md' 'Atomic transition must preserve immutable terminal evidence reference'

$nativeBlockerTarget = New-WorkItem 'WORK-ADMIN-PLAN-WIDE-NATIVE-BLOCKER-TARGET' 1 @() 'in-progress'
$nativeBlockerAttempt = 'ATTEMPT-WORK-ADMIN-PLAN-WIDE-NATIVE-BLOCKER-TARGET-01'
$nativeBlockerTarget.latest_attempt = $nativeBlockerAttempt
$nativeBlockerTarget.attempt_history = @(
  @{ attempt_id = $nativeBlockerAttempt; work_item_id = $nativeBlockerTarget.work_item_id; plan_revision = 3; status = 'in-progress'; artifact_reference = 'runs/plan-wide-native-blocker-target-in-progress.md' }
)
$nativeBlockerSibling = New-WorkItem 'WORK-ADMIN-PLAN-WIDE-NATIVE-BLOCKER-SIBLING' 2
$nativeBlockerSibling.test_omit_planned_authority = $true
$nativeBlockerReference = 'runs/plan-wide-native-blocker.md'
$nativeBlockerCompatibility = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'transition'; transition = 'native-blocker'
  work_item_id = $nativeBlockerTarget.work_item_id; attempt_id = $nativeBlockerAttempt
  terminal_evidence = $nativeBlockerReference
  blocker_artifact = @{
    artifact_reference = $nativeBlockerReference; attempt_id = $nativeBlockerAttempt
    work_item_id = $nativeBlockerTarget.work_item_id; plan_revision = 3; result = 'blocked'; immutable = $true
  }
  work_items = @($nativeBlockerTarget, $nativeBlockerSibling)
}
Assert-Equal $nativeBlockerCompatibility.result 'transitioned' 'Plan-wide production authority stop must not prevent recording a native blocker'
Assert-Equal $nativeBlockerCompatibility.reason 'native-blocker' 'Native blocker must retain its transition diagnostic when a sibling lacks production authority'
Assert-Equal $nativeBlockerCompatibility.work_item_status 'blocked' 'Native blocker must still block the target work item'

$planWideTransitionAuthorityCases = @(
  @{ Name='missing'; Mutate={ param($item, $authority) $item.test_omit_planned_authority = $true; return $null } },
  @{ Name='pre-v1'; Mutate={ param($item, $authority) [void]$authority.Remove('responsibility_rows'); return $authority } },
  @{ Name='mismatched'; Mutate={ param($item, $authority) $authority.work_item_id = 'WORK-ADMIN-FOREIGN'; return $authority } },
  @{ Name='cross-run'; Mutate={ param($item, $authority) $authority.run_id = 'RUN-FOREIGN-999'; return $authority } }
)

foreach ($authorityCase in $planWideTransitionAuthorityCases) {
  foreach ($executableClass in @('required', 'approved-optional')) {
    $caseSuffix = "$($authorityCase.Name.ToUpperInvariant())-$($executableClass.ToUpperInvariant())"
    $startTarget = New-WorkItem "WORK-ADMIN-PLAN-WIDE-START-TARGET-$caseSuffix" 1
    $startBlocker = New-WorkItem "WORK-ADMIN-PLAN-WIDE-START-BLOCKER-$caseSuffix" 2
    if ($executableClass -ceq 'approved-optional') {
      $startBlocker.required = $false
      $startBlocker.optional_execution_approved = $true
    }
    $startBlockerAuthority = New-PlannedResponsibilityDesignArtifact $startBlocker
    $startBlockerAuthority = & $authorityCase.Mutate $startBlocker $startBlockerAuthority
    $startFixture = @{
      scenario_type = 'scope-engine'; operation = 'transition'; transition = 'start-attempt'
      work_item_id = $startTarget.work_item_id
      attempt_id = "ATTEMPT-$($startTarget.work_item_id)-01"
      work_items = @($startTarget, $startBlocker)
    }
    if ($null -ne $startBlockerAuthority) { $startFixture.planned_design_artifacts = @($startBlockerAuthority) }
    $startResult = Invoke-ScopeScenario $startFixture
    Assert-Equal $startResult.result 'scope-blocked' "Attempt start for valid A must stop when $executableClass B has $($authorityCase.Name) responsibility authority"
    Assert-Equal $startResult.reason 'planned-responsibility-authority-invalid' "Attempt start must derive a planned-authority blocker from $executableClass B's $($authorityCase.Name) authority"
    Assert-Equal $startResult.scope_status 'scope-blocked' "Attempt start must keep scope blocked when $executableClass B has $($authorityCase.Name) authority"
    Assert-Equal $startResult.work_item_id '' "Attempt start must select no work when $executableClass B has $($authorityCase.Name) authority"

    $successTarget = New-WorkItem "WORK-ADMIN-PLAN-WIDE-SUCCESS-TARGET-$caseSuffix" 1 @() 'in-progress'
    $successAttempt = "ATTEMPT-$($successTarget.work_item_id)-01"
    $successTarget.latest_attempt = $successAttempt
    $successTarget.attempt_history = @(
      @{ attempt_id = $successAttempt; work_item_id = $successTarget.work_item_id; plan_revision = 3; status = 'in-progress'; artifact_reference = "runs/plan-wide-success-target-$($authorityCase.Name)-$executableClass-in-progress.md" }
    )
    $successBlocker = New-WorkItem "WORK-ADMIN-PLAN-WIDE-SUCCESS-BLOCKER-$caseSuffix" 2
    if ($executableClass -ceq 'approved-optional') {
      $successBlocker.required = $false
      $successBlocker.optional_execution_approved = $true
    }
    $successBlockerAuthority = New-PlannedResponsibilityDesignArtifact $successBlocker
    $successBlockerAuthority = & $authorityCase.Mutate $successBlocker $successBlockerAuthority
    $successChain = New-ResponsibilityChain "runs/plan-wide-success-$($authorityCase.Name)-$executableClass-chain" $successTarget.work_item_id $successTarget.mode_constraint
    $successTerminalReference = "runs/plan-wide-success-$($authorityCase.Name)-$executableClass-terminal.md"
    $successTerminal = New-TerminalResponsibilityArtifact $successTerminalReference $successTarget.work_item_id 'complete' $successChain.FinalReference $successChain.References $successChain.ModeConstraint
    $successTerminal.attempt_id = $successAttempt
    $successTerminal.result = 'complete'
    $successFixture = @{
      scenario_type = 'scope-engine'; operation = 'transition'; transition = 'successful-terminal-artifact'
      work_item_id = $successTarget.work_item_id; attempt_id = $successAttempt
      terminal_evidence = $successTerminalReference; terminal_artifact = $successTerminal
      responsibility_chain_artifacts = @($successChain.Artifacts)
      work_items = @($successTarget, $successBlocker)
    }
    if ($null -ne $successBlockerAuthority) { $successFixture.planned_design_artifacts = @($successBlockerAuthority) }
    $successResult = Invoke-ScopeScenario $successFixture
    Assert-Equal $successResult.result 'scope-blocked' "Successful terminal artifact for valid A must stop when $executableClass B has $($authorityCase.Name) responsibility authority"
    Assert-Equal $successResult.reason 'planned-responsibility-authority-invalid' "Successful transition must derive a planned-authority blocker from $executableClass B's $($authorityCase.Name) authority"
    Assert-Equal $successResult.scope_status 'scope-blocked' "Successful transition must keep scope blocked when $executableClass B has $($authorityCase.Name) authority"
    Assert-Equal $successResult.work_item_id '' "Successful transition must select no work when $executableClass B has $($authorityCase.Name) authority"
  }
}

$missingTransitionStartAuthority = New-WorkItem 'WORK-ADMIN-TRANSITION-START-NO-AUTHORITY' 1
$missingTransitionStartAuthority.test_omit_planned_authority = $true
$blockedTransitionStart = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'transition'; transition = 'start-attempt'
  work_item_id = $missingTransitionStartAuthority.work_item_id
  attempt_id = 'ATTEMPT-WORK-ADMIN-TRANSITION-START-NO-AUTHORITY-01'
  work_items = @($missingTransitionStartAuthority)
}
Assert-Equal $blockedTransitionStart.result 'transition-invalid' 'Attempt start must resolve current v1 responsibility authority before production'
Assert-Equal $blockedTransitionStart.reason 'planned-responsibility-authority-invalid' 'Missing transition-start authority must derive the planned-authority blocker'
Assert-Equal $blockedTransitionStart.scope_status 'scope-blocked' 'Missing transition-start authority must keep scope blocked'

foreach ($authorityCase in @(
  @{ Name='missing'; Mutate={ param($item, $authority) $item.test_omit_planned_authority = $true; return $null } },
  @{ Name='pre-v1'; Mutate={ param($item, $authority) [void]$authority.Remove('responsibility_rows'); return $authority } },
  @{ Name='mismatched'; Mutate={ param($item, $authority) $authority.work_item_id = 'WORK-ADMIN-FOREIGN'; return $authority } },
  @{ Name='cross-run'; Mutate={ param($item, $authority) $authority.run_id = 'RUN-FOREIGN-999'; return $authority } }
)) {
  $caseItem = New-WorkItem "WORK-ADMIN-TRANSITION-$($authorityCase.Name.ToUpperInvariant())" 1 @() 'in-progress'
  $caseAttempt = "ATTEMPT-$($caseItem.work_item_id)-01"
  $caseItem.latest_attempt = $caseAttempt
  $caseItem.attempt_history = @(
    @{ attempt_id = $caseAttempt; work_item_id = $caseItem.work_item_id; plan_revision = 3; status = 'in-progress'; artifact_reference = "runs/$($authorityCase.Name)-transition-in-progress.md" }
  )
  $caseChain = New-ResponsibilityChain "runs/$($authorityCase.Name)-transition-chain" $caseItem.work_item_id $caseItem.mode_constraint
  $caseTerminalReference = "runs/$($authorityCase.Name)-transition-terminal.md"
  $caseTerminal = New-TerminalResponsibilityArtifact $caseTerminalReference $caseItem.work_item_id 'complete' $caseChain.FinalReference $caseChain.References $caseChain.ModeConstraint
  $caseTerminal.attempt_id = $caseAttempt
  $caseTerminal.result = 'complete'
  $caseAuthority = New-PlannedResponsibilityDesignArtifact $caseItem
  $caseAuthority = & $authorityCase.Mutate $caseItem $caseAuthority
  $caseFixture = @{
    scenario_type = 'scope-engine'; operation = 'transition'; transition = 'successful-terminal-artifact'
    work_item_id = $caseItem.work_item_id; attempt_id = $caseAttempt
    terminal_evidence = $caseTerminalReference; terminal_artifact = $caseTerminal
    responsibility_chain_artifacts = @($caseChain.Artifacts); work_items = @($caseItem)
  }
  if ($null -ne $caseAuthority) { $caseFixture.planned_design_artifacts = @($caseAuthority) }
  $caseResult = Invoke-ScopeScenario $caseFixture
  Assert-Equal $caseResult.result 'transition-invalid' "Successful transition must reject $($authorityCase.Name) responsibility authority"
  Assert-Equal $caseResult.reason 'planned-responsibility-authority-invalid' "Transition $($authorityCase.Name) authority must derive BLOCKED"
  Assert-Equal $caseResult.scope_status 'scope-blocked' "Transition $($authorityCase.Name) authority must not complete the work item"
}

foreach ($terminalAuthorityCase in @(
  @{ Name='missing'; Mutate={ param($artifact) [void]$artifact.Remove('responsibility_handoff') } },
  @{ Name='pre-v1'; Mutate={ param($artifact) $artifact.responsibility_handoff.responsibility_contract_version = 0 } },
  @{ Name='mismatched'; Mutate={ param($artifact) $artifact.responsibility_handoff.evidence_reference = 'runs/foreign-terminal-chain.md' } },
  @{ Name='cross-run'; Mutate={ param($artifact) $artifact.run_id = 'RUN-FOREIGN-999' } }
)) {
  $caseItem = New-WorkItem "WORK-ADMIN-TERMINAL-$($terminalAuthorityCase.Name.ToUpperInvariant())" 1 @() 'in-progress'
  $caseAttempt = "ATTEMPT-$($caseItem.work_item_id)-01"
  $caseItem.latest_attempt = $caseAttempt
  $caseItem.attempt_history = @(
    @{ attempt_id = $caseAttempt; work_item_id = $caseItem.work_item_id; plan_revision = 3; status = 'in-progress'; artifact_reference = "runs/$($terminalAuthorityCase.Name)-terminal-in-progress.md" }
  )
  $caseChain = New-ResponsibilityChain "runs/$($terminalAuthorityCase.Name)-terminal-authority-chain" $caseItem.work_item_id $caseItem.mode_constraint
  $caseTerminalReference = "runs/$($terminalAuthorityCase.Name)-terminal-authority.md"
  $caseTerminal = New-TerminalResponsibilityArtifact $caseTerminalReference $caseItem.work_item_id 'complete' $caseChain.FinalReference $caseChain.References $caseChain.ModeConstraint
  $caseTerminal.attempt_id = $caseAttempt
  $caseTerminal.result = 'complete'
  & $terminalAuthorityCase.Mutate $caseTerminal
  $caseResult = Invoke-ScopeScenario @{
    scenario_type = 'scope-engine'; operation = 'transition'; transition = 'successful-terminal-artifact'
    work_item_id = $caseItem.work_item_id; attempt_id = $caseAttempt
    terminal_evidence = $caseTerminalReference; terminal_artifact = $caseTerminal
    responsibility_chain_artifacts = @($caseChain.Artifacts); work_items = @($caseItem)
  }
  Assert-Equal $caseResult.result 'transition-invalid' "Successful transition must reject $($terminalAuthorityCase.Name) terminal responsibility authority"
  Assert-Equal $caseResult.reason 'terminal-responsibility-authority-invalid' "Terminal $($terminalAuthorityCase.Name) responsibility envelope must block completion"
  Assert-Equal $caseResult.scope_status 'scope-blocked' "Terminal $($terminalAuthorityCase.Name) authority must not complete the work item"
}

$stringImmutableTransitionItem = New-WorkItem 'WORK-ADMIN-TERMINAL-STRING-IMMUTABLE' 1 @() 'in-progress'
$stringImmutableTransitionAttempt = 'ATTEMPT-WORK-ADMIN-TERMINAL-STRING-IMMUTABLE-01'
$stringImmutableTransitionItem.latest_attempt = $stringImmutableTransitionAttempt
$stringImmutableTransitionItem.attempt_history = @(
  @{ attempt_id = $stringImmutableTransitionAttempt; work_item_id = $stringImmutableTransitionItem.work_item_id; plan_revision = 3; status = 'in-progress'; artifact_reference = 'runs/string-immutable-transition-in-progress.md' }
)
$stringImmutableTransitionChain = New-ResponsibilityChain 'runs/string-immutable-transition-chain' $stringImmutableTransitionItem.work_item_id
$stringImmutableTransitionTerminal = New-TerminalResponsibilityArtifact 'runs/string-immutable-transition-terminal.md' $stringImmutableTransitionItem.work_item_id 'complete' $stringImmutableTransitionChain.FinalReference $stringImmutableTransitionChain.References $stringImmutableTransitionChain.ModeConstraint
$stringImmutableTransitionTerminal.attempt_id = $stringImmutableTransitionAttempt
$stringImmutableTransitionTerminal.immutable = 'false'
$stringImmutableTransitionResult = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'transition'; transition = 'successful-terminal-artifact'
  work_item_id = $stringImmutableTransitionItem.work_item_id; attempt_id = $stringImmutableTransitionAttempt
  terminal_evidence = $stringImmutableTransitionTerminal.artifact_reference; terminal_artifact = $stringImmutableTransitionTerminal
  responsibility_chain_artifacts = @($stringImmutableTransitionChain.Artifacts); work_items = @($stringImmutableTransitionItem)
}
Assert-Equal $stringImmutableTransitionResult.reason 'terminal-artifact-binding-invalid' 'String false immutable must reject at successful terminal authority'

foreach ($chainIndex in 1..4) {
  $caseItem = New-WorkItem "WORK-ADMIN-DOWNSTREAM-TRANSITION-$chainIndex" 1 @() 'in-progress'
  $caseAttempt = "ATTEMPT-$($caseItem.work_item_id)-01"
  $caseItem.latest_attempt = $caseAttempt
  $caseItem.attempt_history = @(
    @{ attempt_id = $caseAttempt; work_item_id = $caseItem.work_item_id; plan_revision = 3; status = 'in-progress'; artifact_reference = "runs/downstream-transition-$chainIndex-in-progress.md" }
  )
  $caseChain = New-ResponsibilityChain "runs/downstream-transition-$chainIndex-chain" $caseItem.work_item_id $caseItem.mode_constraint
  $caseChain.Artifacts[$chainIndex].status = 'draft'
  $caseTerminalReference = "runs/downstream-transition-$chainIndex-terminal.md"
  $caseTerminal = New-TerminalResponsibilityArtifact $caseTerminalReference $caseItem.work_item_id 'complete' $caseChain.FinalReference $caseChain.References $caseChain.ModeConstraint
  $caseTerminal.attempt_id = $caseAttempt
  $caseTerminal.result = 'complete'
  $caseResult = Invoke-ScopeScenario @{
    scenario_type = 'scope-engine'; operation = 'transition'; transition = 'successful-terminal-artifact'
    work_item_id = $caseItem.work_item_id; attempt_id = $caseAttempt
    terminal_evidence = $caseTerminalReference; terminal_artifact = $caseTerminal
    responsibility_chain_artifacts = @($caseChain.Artifacts); work_items = @($caseItem)
  }
  Assert-Equal $caseResult.result 'transition-invalid' "Successful transition must reject non-approved downstream step $chainIndex"
  Assert-Equal $caseResult.reason 'terminal-responsibility-authority-invalid' "Downstream transition step $chainIndex must fail terminal responsibility authority"
}

$mismatchedTransitionChain = New-ResponsibilityChain 'runs/mismatched-transition-chain' $transitionCurrent.work_item_id $transitionCurrent.mode_constraint
$mismatchedTransitionTerminal = New-TerminalResponsibilityArtifact 'runs/current-01.md' $transitionCurrent.work_item_id 'complete' $mismatchedTransitionChain.FinalReference $mismatchedTransitionChain.References $mismatchedTransitionChain.ModeConstraint
$mismatchedTransitionTerminal.attempt_id = 'ATTEMPT-WORK-ADMIN-OTHER-01'
$mismatchedTransitionTerminal.result = 'complete'
$mismatchedTerminalArtifact = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'
  operation = 'transition'
  current_plan_revision = 3
  transition = 'successful-terminal-artifact'
  work_item_id = 'WORK-ADMIN-CURRENT'
  attempt_id = 'ATTEMPT-WORK-ADMIN-CURRENT-01'
  terminal_evidence = 'runs/current-01.md'
  terminal_evidence_valid = $true
  terminal_artifact = $mismatchedTransitionTerminal
  responsibility_chain_artifacts = @($mismatchedTransitionChain.Artifacts)
  work_items = @($transitionCurrent)
}
Assert-Equal $mismatchedTerminalArtifact.result 'transition-invalid' 'Successful transition must validate terminal artifact binding instead of trusting a boolean'
Assert-Equal $mismatchedTerminalArtifact.reason 'terminal-artifact-binding-invalid' 'Terminal artifact mismatch must report exact binding failure'

$blockerWithoutEvidence = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'
  operation = 'transition'
  current_plan_revision = 3
  transition = 'native-blocker'
  work_item_id = 'WORK-ADMIN-CURRENT'
  attempt_id = 'ATTEMPT-WORK-ADMIN-CURRENT-01'
  terminal_evidence = 'none'
  work_items = @($transitionCurrent)
}
Assert-Equal $blockerWithoutEvidence.result 'transition-invalid' 'Native blocker transition must require immutable blocker evidence'
Assert-Equal $blockerWithoutEvidence.reason 'blocker-evidence-missing' 'Native blocker must report missing evidence'

$blockerWithoutArtifact = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'
  operation = 'transition'
  current_plan_revision = 3
  transition = 'native-blocker'
  work_item_id = 'WORK-ADMIN-CURRENT'
  attempt_id = 'ATTEMPT-WORK-ADMIN-CURRENT-01'
  terminal_evidence = 'runs/current-blocked.md'
  work_items = @($transitionCurrent)
}
Assert-Equal $blockerWithoutArtifact.result 'transition-invalid' 'Native blocker reference alone must not replace a bound immutable artifact'
Assert-Equal $blockerWithoutArtifact.reason 'blocker-artifact-binding-invalid' 'Native blocker must report artifact binding failure'

$stringImmutableBlocker = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'transition'; current_plan_revision = 3
  transition = 'native-blocker'; work_item_id = 'WORK-ADMIN-CURRENT'; attempt_id = 'ATTEMPT-WORK-ADMIN-CURRENT-01'
  terminal_evidence = 'runs/current-string-immutable-blocked.md'
  blocker_artifact = @{
    artifact_reference = 'runs/current-string-immutable-blocked.md'; attempt_id = 'ATTEMPT-WORK-ADMIN-CURRENT-01'
    work_item_id = 'WORK-ADMIN-CURRENT'; plan_revision = 3; result = 'blocked'; immutable = 'false'
  }
  work_items = @($transitionCurrent)
}
Assert-Equal $stringImmutableBlocker.reason 'blocker-artifact-binding-invalid' 'String false immutable must reject at native-blocker authority'

$nonLatestBlockerItem = New-WorkItem 'WORK-ADMIN-NONLATEST-BLOCKER' 1 @() 'in-progress'
$nonLatestBlockerItem.latest_attempt = 'ATTEMPT-WORK-ADMIN-NONLATEST-BLOCKER-02'
$nonLatestBlockerItem.attempt_history = @(
  @{ attempt_id = 'ATTEMPT-WORK-ADMIN-NONLATEST-BLOCKER-01'; work_item_id = 'WORK-ADMIN-NONLATEST-BLOCKER'; plan_revision = 3; status = 'blocked'; artifact_reference = 'runs/nonlatest-01.md' },
  @{ attempt_id = 'ATTEMPT-WORK-ADMIN-NONLATEST-BLOCKER-02'; work_item_id = 'WORK-ADMIN-NONLATEST-BLOCKER'; plan_revision = 3; status = 'in-progress'; artifact_reference = 'runs/nonlatest-02.md' }
)
$nonLatestBlocker = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'transition'; current_plan_revision = 3
  transition = 'native-blocker'; work_item_id = 'WORK-ADMIN-NONLATEST-BLOCKER'
  attempt_id = 'ATTEMPT-WORK-ADMIN-NONLATEST-BLOCKER-01'; terminal_evidence = 'runs/nonlatest-blocker.md'
  blocker_artifact = @{ artifact_reference = 'runs/nonlatest-blocker.md'; attempt_id = 'ATTEMPT-WORK-ADMIN-NONLATEST-BLOCKER-01'; work_item_id = 'WORK-ADMIN-NONLATEST-BLOCKER'; plan_revision = 3; result = 'blocked'; immutable = $true }
  work_items = @($nonLatestBlockerItem)
}
Assert-Equal $nonLatestBlocker.result 'transition-invalid' 'Native blocker must target exactly the latest attempt'
Assert-Equal $nonLatestBlocker.reason 'attempt-not-latest' 'Non-latest blocker transition must report exact binding failure'

$cancelItem = New-WorkItem 'WORK-ADMIN-CANCEL' 1
$cancelWithoutApproval = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'
  operation = 'transition'
  current_plan_revision = 3
  transition = 'approved-cancellation'
  work_item_id = 'WORK-ADMIN-CANCEL'
  terminal_evidence = 'decision:cancel'
  approval_reference = 'pending'
  work_items = @($cancelItem)
}
Assert-Equal $cancelWithoutApproval.result 'transition-invalid' 'Cancellation must require approved decision evidence'
Assert-Equal $cancelWithoutApproval.reason 'approval-evidence-missing' 'Cancellation must report missing approval evidence'

$cancelWithoutArtifact = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'
  operation = 'transition'
  current_plan_revision = 3
  transition = 'approved-cancellation'
  work_item_id = 'WORK-ADMIN-CANCEL'
  terminal_evidence = 'decision:cancel'
  approval_reference = 'approval:cancel'
  work_items = @($cancelItem)
}
Assert-Equal $cancelWithoutArtifact.result 'transition-invalid' 'Cancellation must require a structured immutable decision artifact'
Assert-Equal $cancelWithoutArtifact.reason 'decision-artifact-binding-invalid' 'Cancellation must report decision binding failure'

$stringImmutableCancellation = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'transition'; current_plan_revision = 3
  transition = 'approved-cancellation'; work_item_id = 'WORK-ADMIN-CANCEL'
  terminal_evidence = 'decision:cancel'; approval_reference = 'approval:cancel'
  decision_artifact = @{
    artifact_reference = 'decision:cancel'; work_item_id = 'WORK-ADMIN-CANCEL'; plan_revision = 3
    decision = 'cancelled-approved'; approval_reference = 'approval:cancel'; immutable = 'false'
  }
  work_items = @($cancelItem)
}
Assert-Equal $stringImmutableCancellation.reason 'decision-artifact-binding-invalid' 'String false immutable must reject at cancellation authority'

$naItem = New-WorkItem 'WORK-ADMIN-NA-DECISION' 1
$naWithoutApproval = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'
  operation = 'transition'
  current_plan_revision = 3
  transition = 'approved-non-applicability'
  work_item_id = 'WORK-ADMIN-NA-DECISION'
  terminal_evidence = 'decision:not-applicable'
  approval_reference = 'pending'
  work_items = @($naItem)
}
Assert-Equal $naWithoutApproval.result 'transition-invalid' 'Non-applicability must require approved decision evidence'
Assert-Equal $naWithoutApproval.reason 'approval-evidence-missing' 'Non-applicability must report missing approval evidence'

$naWithoutArtifact = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'
  operation = 'transition'
  current_plan_revision = 3
  transition = 'approved-non-applicability'
  work_item_id = 'WORK-ADMIN-NA-DECISION'
  terminal_evidence = 'decision:not-applicable'
  approval_reference = 'approval:not-applicable'
  work_items = @($naItem)
}
Assert-Equal $naWithoutArtifact.result 'transition-invalid' 'Non-applicability must require a structured immutable decision artifact'
Assert-Equal $naWithoutArtifact.reason 'decision-artifact-binding-invalid' 'Non-applicability must report decision binding failure'

$stringImmutableNonApplicability = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'transition'; current_plan_revision = 3
  transition = 'approved-non-applicability'; work_item_id = 'WORK-ADMIN-NA-DECISION'
  terminal_evidence = 'decision:not-applicable'; approval_reference = 'approval:not-applicable'
  decision_artifact = @{
    artifact_reference = 'decision:not-applicable'; work_item_id = 'WORK-ADMIN-NA-DECISION'; plan_revision = 3
    decision = 'not-applicable-approved'; approval_reference = 'approval:not-applicable'; immutable = 'false'
  }
  work_items = @($naItem)
}
Assert-Equal $stringImmutableNonApplicability.reason 'decision-artifact-binding-invalid' 'String false immutable must reject at non-applicability authority'

# Scope changes create a new immutable revision, invalidate affected approval,
# and preserve unaffected completed evidence.
$revision = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'
  operation = 'revise'
  current = @{
    artifact_id = 'PLAN-ADMIN-001'
    revision = 3
    status = 'approved'
    work_items = @(
      @{ work_item_id = 'WORK-ADMIN-STABLE'; required = $true; dependencies = @(); plan_order = 1; acceptance = @('REQ-001'); trace_ids = @('REQ-001'); delivery_adapter = @{ kind = 'none'; external_id = 'not-applicable' }; status = 'complete'; approval_reference = 'approval:stable@3'; terminal_evidence = 'runs/stable.md' },
      @{ work_item_id = 'WORK-ADMIN-CHANGED'; required = $true; dependencies = @('WORK-ADMIN-STABLE'); plan_order = 2; acceptance = @('REQ-002'); trace_ids = @('REQ-002'); delivery_adapter = @{ kind = 'none'; external_id = 'not-applicable' }; status = 'ready'; approval_reference = 'approval:changed@3'; terminal_evidence = 'none' }
    )
  }
  proposed = @{
    artifact_id = 'PLAN-ADMIN-001'
    revision = 4
    supersedes = 'PLAN-ADMIN-001@3'
    change_summary = 'Change acceptance for WORK-ADMIN-CHANGED'
    affected_work_items = @('WORK-ADMIN-CHANGED')
    work_items = @(
      @{ work_item_id = 'WORK-ADMIN-STABLE'; required = $true; dependencies = @(); plan_order = 1; acceptance = @('REQ-001'); trace_ids = @('REQ-001'); delivery_adapter = @{ kind = 'none'; external_id = 'not-applicable' }; status = 'complete'; approval_reference = 'approval:stable@3'; terminal_evidence = 'runs/stable.md' },
      @{ work_item_id = 'WORK-ADMIN-CHANGED'; required = $true; dependencies = @('WORK-ADMIN-STABLE'); plan_order = 2; acceptance = @('REQ-002-REVISED'); trace_ids = @('REQ-002'); delivery_adapter = @{ kind = 'none'; external_id = 'not-applicable' }; status = 'pending'; approval_reference = 'pending'; terminal_evidence = 'none' }
    )
  }
}
Assert-Equal $revision.result 'revision-valid' 'Scope change must create the next immutable revision'
Assert-True ([bool]$revision.unaffected_evidence_preserved) 'Revision must preserve unaffected completed evidence'
Assert-True ([bool]$revision.affected_approval_invalidated) 'Revision must invalidate approval for affected items'

$undeclaredMasterChange = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'
  operation = 'revise'
  current = @{
    artifact_id = 'PLAN-ADMIN-001'; revision = 3; status = 'approved'
    requested_scope = @{ kind = 'module'; id = 'ADMIN'; boundary = 'complete-admin' }
    requirements = @('REQ-001: existing behavior')
    success_criteria = @('SC-001: existing outcome')
    required_disposition = @('WORK-ADMIN-STABLE:required')
    structural_decisions = @('DEC-001: existing architecture')
    work_items = @()
  }
  proposed = @{
    artifact_id = 'PLAN-ADMIN-001'; revision = 4; supersedes = 'PLAN-ADMIN-001@3'; change_summary = 'Change master requirement'; affected_work_items = @()
    requested_scope = @{ kind = 'module'; id = 'ADMIN'; boundary = 'complete-admin' }
    requirements = @('REQ-001: revised behavior')
    success_criteria = @('SC-001: existing outcome')
    required_disposition = @('WORK-ADMIN-STABLE:required')
    structural_decisions = @('DEC-001: existing architecture')
    work_items = @()
  }
}
Assert-Equal $undeclaredMasterChange.result 'revision-invalid' 'Requested boundary/requirements/success/disposition/structural decisions must participate in revision comparison'
Assert-Equal $undeclaredMasterChange.reason 'master-structural-change-requires-affected-items' 'Undeclared master-level change must require affected approval invalidation'

$fakeAffectedBypass = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'revise'
  current = @{
    artifact_id = 'PLAN-ADMIN-001'; revision = 3; status = 'approved'; requirements = @('REQ-OLD')
    work_items = @(
      @{ work_item_id = 'WORK-ADMIN-REAL'; required = $true; dependencies = @(); plan_order = 1; acceptance = @('REQ-OLD'); trace_ids = @('REQ-OLD'); delivery_adapter = @{ kind = 'none'; external_id = 'not-applicable' }; status = 'ready'; approval_reference = 'approval:real@3'; terminal_evidence = 'none' }
    )
  }
  proposed = @{
    artifact_id = 'PLAN-ADMIN-001'; revision = 4; supersedes = 'PLAN-ADMIN-001@3'; change_summary = 'Attempt fake affected bypass'; requirements = @('REQ-NEW'); affected_work_items = @('[FAKE]')
    work_items = @(
      @{ work_item_id = 'WORK-ADMIN-REAL'; required = $true; dependencies = @(); plan_order = 1; acceptance = @('REQ-OLD'); trace_ids = @('REQ-OLD'); delivery_adapter = @{ kind = 'none'; external_id = 'not-applicable' }; status = 'ready'; approval_reference = 'approval:real@3'; terminal_evidence = 'none' }
    )
  }
}
Assert-Equal $fakeAffectedBypass.result 'revision-invalid' 'Every affected_work_items entry must resolve to a canonical current or proposed row'
Assert-Equal $fakeAffectedBypass.reason 'affected-work-item-not-canonical' 'A fake affected ID must not bypass master-change invalidation'

$partialMasterCoverage = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'revise'
  current = @{
    artifact_id = 'PLAN-ADMIN-001'; revision = 3; status = 'approved'; success_criteria = @('SC-OLD')
    work_items = @(
      @{ work_item_id = 'WORK-ADMIN-MASTER-A'; required = $true; dependencies = @(); plan_order = 1; acceptance = @('REQ-A'); trace_ids = @('REQ-A'); delivery_adapter = @{ kind = 'none'; external_id = 'not-applicable' }; status = 'ready'; approval_reference = 'approval:a@3'; terminal_evidence = 'none' },
      @{ work_item_id = 'WORK-ADMIN-MASTER-B'; required = $true; dependencies = @(); plan_order = 2; acceptance = @('REQ-B'); trace_ids = @('REQ-B'); delivery_adapter = @{ kind = 'none'; external_id = 'not-applicable' }; status = 'ready'; approval_reference = 'approval:b@3'; terminal_evidence = 'none' }
    )
  }
  proposed = @{
    artifact_id = 'PLAN-ADMIN-001'; revision = 4; supersedes = 'PLAN-ADMIN-001@3'; change_summary = 'Change unmappable master success criteria'; success_criteria = @('SC-NEW'); affected_work_items = @('WORK-ADMIN-MASTER-A')
    work_items = @(
      @{ work_item_id = 'WORK-ADMIN-MASTER-A'; required = $true; dependencies = @(); plan_order = 1; acceptance = @('REQ-A'); trace_ids = @('REQ-A'); delivery_adapter = @{ kind = 'none'; external_id = 'not-applicable' }; status = 'pending'; approval_reference = 'pending'; terminal_evidence = 'none' },
      @{ work_item_id = 'WORK-ADMIN-MASTER-B'; required = $true; dependencies = @(); plan_order = 2; acceptance = @('REQ-B'); trace_ids = @('REQ-B'); delivery_adapter = @{ kind = 'none'; external_id = 'not-applicable' }; status = 'ready'; approval_reference = 'approval:b@3'; terminal_evidence = 'none' }
    )
  }
}
Assert-Equal $partialMasterCoverage.result 'revision-invalid' 'Unmappable master-level change must conservatively invalidate every canonical work item'
Assert-Equal $partialMasterCoverage.reason 'master-change-affected-coverage-incomplete' 'Partial affected coverage must identify the master-level coverage gap'

$completeMasterCoverage = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'revise'
  current = @{
    artifact_id = 'PLAN-ADMIN-001'; revision = 3; status = 'approved'; structural_decisions = @('DEC-OLD')
    work_items = @(
      @{ work_item_id = 'WORK-ADMIN-COVER-A'; required = $true; dependencies = @(); plan_order = 1; acceptance = @('REQ-A'); trace_ids = @('REQ-A'); delivery_adapter = @{ kind = 'none'; external_id = 'not-applicable' }; status = 'ready'; approval_reference = 'approval:a@3'; terminal_evidence = 'none' },
      @{ work_item_id = 'WORK-ADMIN-COVER-B'; required = $true; dependencies = @(); plan_order = 2; acceptance = @('REQ-B'); trace_ids = @('REQ-B'); delivery_adapter = @{ kind = 'none'; external_id = 'not-applicable' }; status = 'ready'; approval_reference = 'approval:b@3'; terminal_evidence = 'none' }
    )
  }
  proposed = @{
    artifact_id = 'PLAN-ADMIN-001'; revision = 4; supersedes = 'PLAN-ADMIN-001@3'; change_summary = 'Change structural decision with complete coverage'; structural_decisions = @('DEC-NEW'); affected_work_items = @('WORK-ADMIN-COVER-A', 'WORK-ADMIN-COVER-B')
    work_items = @(
      @{ work_item_id = 'WORK-ADMIN-COVER-A'; required = $true; dependencies = @(); plan_order = 1; acceptance = @('REQ-A'); trace_ids = @('REQ-A'); delivery_adapter = @{ kind = 'none'; external_id = 'not-applicable' }; status = 'pending'; approval_reference = 'pending'; terminal_evidence = 'none' },
      @{ work_item_id = 'WORK-ADMIN-COVER-B'; required = $true; dependencies = @(); plan_order = 2; acceptance = @('REQ-B'); trace_ids = @('REQ-B'); delivery_adapter = @{ kind = 'none'; external_id = 'not-applicable' }; status = 'pending'; approval_reference = 'pending'; terminal_evidence = 'none' }
    )
  }
}
Assert-Equal $completeMasterCoverage.result 'revision-valid' 'Master-level change is valid when every canonical item is affected and approvals are pending'

$duplicateCurrentRows = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'revise'
  current = @{ artifact_id = 'PLAN-ADMIN-001'; revision = 3; status = 'approved'; work_items = @(
    @{ work_item_id = 'WORK-ADMIN-DUPLICATE'; approval_reference = 'approval:one' },
    @{ work_item_id = 'WORK-ADMIN-DUPLICATE'; approval_reference = 'approval:two' }
  ) }
  proposed = @{ artifact_id = 'PLAN-ADMIN-001'; revision = 4; supersedes = 'PLAN-ADMIN-001@3'; change_summary = 'No-op'; affected_work_items = @(); work_items = @() }
}
Assert-Equal $duplicateCurrentRows.result 'revision-invalid' 'Revision must reject duplicate current work-item IDs before dictionary construction'
Assert-Equal $duplicateCurrentRows.reason 'duplicate-current-work-item-id' 'Duplicate current ID must report exact source side'

$duplicateProposedRows = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'; operation = 'revise'
  current = @{ artifact_id = 'PLAN-ADMIN-001'; revision = 3; status = 'approved'; work_items = @() }
  proposed = @{ artifact_id = 'PLAN-ADMIN-001'; revision = 4; supersedes = 'PLAN-ADMIN-001@3'; change_summary = 'Duplicate rows'; affected_work_items = @('WORK-ADMIN-DUPLICATE'); work_items = @(
    @{ work_item_id = 'WORK-ADMIN-DUPLICATE'; approval_reference = 'pending' },
    @{ work_item_id = 'WORK-ADMIN-DUPLICATE'; approval_reference = 'pending' }
  ) }
}
Assert-Equal $duplicateProposedRows.result 'revision-invalid' 'Revision must reject duplicate proposed work-item IDs before dictionary construction'
Assert-Equal $duplicateProposedRows.reason 'duplicate-proposed-work-item-id' 'Duplicate proposed ID must report exact target side'

$undeclaredStructuralChange = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'
  operation = 'revise'
  current = @{
    artifact_id = 'PLAN-ADMIN-001'; revision = 3; status = 'approved'
    work_items = @(
      @{ work_item_id = 'WORK-ADMIN-STABLE'; required = $true; dependencies = @(); plan_order = 1; acceptance = @('REQ-001'); trace_ids = @('REQ-001'); delivery_adapter = @{ kind = 'none'; external_id = 'not-applicable' }; status = 'complete'; approval_reference = 'approval:stable@3'; terminal_evidence = 'runs/stable.md' }
    )
  }
  proposed = @{
    artifact_id = 'PLAN-ADMIN-001'; revision = 4; supersedes = 'PLAN-ADMIN-001@3'; change_summary = 'Undeclared dependency change'; affected_work_items = @()
    work_items = @(
      @{ work_item_id = 'WORK-ADMIN-STABLE'; required = $true; dependencies = @('WORK-ADMIN-NEW'); plan_order = 1; acceptance = @('REQ-001'); trace_ids = @('REQ-001'); delivery_adapter = @{ kind = 'none'; external_id = 'not-applicable' }; status = 'complete'; approval_reference = 'approval:stable@3'; terminal_evidence = 'runs/stable.md' }
    )
  }
}
Assert-Equal $undeclaredStructuralChange.result 'revision-invalid' 'Every structural work-item change must be declared affected'
Assert-Equal $undeclaredStructuralChange.reason 'changed-item-not-declared-affected' 'Undeclared dependency change must be identified'

$newItemApproved = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'
  operation = 'revise'
  current = @{ artifact_id = 'PLAN-ADMIN-001'; revision = 3; status = 'approved'; work_items = @() }
  proposed = @{
    artifact_id = 'PLAN-ADMIN-001'; revision = 4; supersedes = 'PLAN-ADMIN-001@3'; change_summary = 'Add work item'; affected_work_items = @('WORK-ADMIN-NEW')
    work_items = @(
      @{ work_item_id = 'WORK-ADMIN-NEW'; required = $true; dependencies = @(); plan_order = 1; acceptance = @('REQ-NEW'); trace_ids = @('REQ-NEW'); delivery_adapter = @{ kind = 'task'; external_id = 'TASK-9'; authority_revision = 4 }; status = 'ready'; approval_reference = 'approval:copied'; terminal_evidence = 'none' }
    )
  }
}
Assert-Equal $newItemApproved.result 'revision-invalid' 'New affected item must not carry a pre-existing approval'
Assert-Equal $newItemApproved.reason 'affected-approval-not-invalidated' 'New item approval must be pending in the new revision'

$inPlace = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'
  operation = 'revise'
  current = @{ artifact_id = 'PLAN-ADMIN-001'; revision = 3; status = 'approved'; work_items = @() }
  proposed = @{
    artifact_id = 'PLAN-ADMIN-001'
    revision = 3
    supersedes = 'PLAN-ADMIN-001@3'
    change_summary = 'Edit approved revision in place'
    affected_work_items = @('WORK-ADMIN-CHANGED')
    work_items = @()
  }
}
Assert-Equal $inPlace.result 'revision-invalid' 'Approved artifact must never be edited in place'
Assert-Equal $inPlace.reason 'revision-must-increment-by-one' 'In-place edit must report revision increment failure'

$resumeChain = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'
  operation = 'validate-resume'
  master_spec_id = 'SPEC-ADMIN-001'
  latest_spec_revision = 2
  spec_revisions = @(
    @{ artifact_id = 'SPEC-ADMIN-001'; revision = 1; supersedes = 'not-applicable'; status = 'approved'; stale = $false },
    @{ artifact_id = 'SPEC-ADMIN-001'; revision = 2; supersedes = 'SPEC-ADMIN-001@1'; status = 'approved'; stale = $false }
  )
  revisions = @(
    @{ artifact_id = 'PLAN-ADMIN-001'; revision = 1; supersedes = 'not-applicable'; status = 'approved'; master_spec_revision = 1; stale = $false },
    @{ artifact_id = 'PLAN-ADMIN-001'; revision = 2; supersedes = 'PLAN-ADMIN-001@1'; status = 'approved'; master_spec_revision = 2; stale = $false },
    @{ artifact_id = 'PLAN-ADMIN-001'; revision = 3; supersedes = 'PLAN-ADMIN-001@1'; status = 'approved'; master_spec_revision = 2; stale = $false }
  )
}
Assert-Equal $resumeChain.result 'resume-blocked' 'Forked approved revision chain must block resume'
Assert-Equal $resumeChain.reason 'forked-revision-chain' 'Resume must identify a forked chain'

$forkedSpecChain = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'
  operation = 'validate-resume'
  master_spec_id = 'SPEC-ADMIN-001'
  latest_spec_revision = 3
  spec_revisions = @(
    @{ artifact_id = 'SPEC-ADMIN-001'; revision = 1; supersedes = 'not-applicable'; status = 'approved'; stale = $false },
    @{ artifact_id = 'SPEC-ADMIN-001'; revision = 2; supersedes = 'SPEC-ADMIN-001@1'; status = 'approved'; stale = $false },
    @{ artifact_id = 'SPEC-ADMIN-001'; revision = 3; supersedes = 'SPEC-ADMIN-001@1'; status = 'approved'; stale = $false }
  )
  revisions = @(
    @{ artifact_id = 'PLAN-ADMIN-001'; revision = 1; supersedes = 'not-applicable'; status = 'approved'; master_spec_revision = 3; stale = $false }
  )
}
Assert-Equal $forkedSpecChain.result 'resume-blocked' 'Forked approved master-spec chain must block resume before plan selection'
Assert-Equal $forkedSpecChain.reason 'forked-master-spec-chain' 'Resume must identify the master-spec chain as the blocker'

$changedPlanIdChain = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'
  operation = 'validate-resume'
  master_spec_id = 'SPEC-ADMIN-001'
  latest_spec_revision = 1
  spec_revisions = @(
    @{ artifact_id = 'SPEC-ADMIN-001'; revision = 1; supersedes = 'not-applicable'; status = 'approved'; stale = $false }
  )
  revisions = @(
    @{ artifact_id = 'PLAN-ADMIN-001'; revision = 1; supersedes = 'not-applicable'; status = 'approved'; master_spec_revision = 1; stale = $false },
    @{ artifact_id = 'PLAN-ADMIN-CHANGED'; revision = 2; supersedes = 'PLAN-ADMIN-001@1'; status = 'approved'; master_spec_revision = 1; stale = $false }
  )
}
Assert-Equal $changedPlanIdChain.result 'resume-blocked' 'Linear revision chain must preserve stable master-plan artifact ID'
Assert-Equal $changedPlanIdChain.reason 'master-plan-id-changed' 'Resume must report a changed master-plan ID'

# Standalone resume validates only the latest executable approved plan. Older
# approved pre-v1 revisions remain readable historical chain members.
$resumeContractFixture = [ordered]@{
  scenario_type = 'scope-engine'
  operation = 'validate-resume'
  master_spec_id = 'SPEC-ADMIN-001'
  latest_spec_revision = 2
  spec_revisions = @(
    [ordered]@{ artifact_id = 'SPEC-ADMIN-001'; revision = 1; supersedes = 'not-applicable'; status = 'approved'; stale = $false },
    [ordered]@{ artifact_id = 'SPEC-ADMIN-001'; revision = 2; supersedes = 'SPEC-ADMIN-001@1'; status = 'approved'; stale = $false }
  )
  revisions = @(
    [ordered]@{ artifact_id = 'PLAN-ADMIN-001'; revision = 1; supersedes = 'not-applicable'; status = 'approved'; result = 'complete'; master_spec_revision = 1; stale = $false },
    [ordered]@{ artifact_id = 'PLAN-ADMIN-001'; revision = 2; supersedes = 'PLAN-ADMIN-001@1'; status = 'approved'; result = 'complete'; master_spec_revision = 2; stale = $false; responsibility_contract = [ordered]@{ version = 0; applicability = 'required' } },
    [ordered]@{ artifact_id = 'PLAN-ADMIN-001'; revision = 3; supersedes = 'PLAN-ADMIN-001@2'; status = 'approved'; result = 'complete'; master_spec_revision = 2; stale = $false; responsibility_contract = [ordered]@{ version = 1; applicability = 'required' } }
  )
}
$resumeContractJson = $resumeContractFixture | ConvertTo-Json -Depth 20 -Compress
$historicalPreV1Resume = Invoke-RawScopeScenario $resumeContractJson
Assert-Equal $historicalPreV1Resume.result 'resume-ready' 'Historical missing and pre-v1 plan discriminators must remain readable when the latest approved plan is canonical v1'
Assert-Equal $historicalPreV1Resume.latest_plan_revision 3 'Historical compatibility must still select the latest canonical plan revision'

$resumeContractCases = @(
  @{
    Name = 'missing latest discriminator'
    Json = Replace-RawScopeJsonExactOrFail $resumeContractJson (',' + $canonicalRawPlanContract) '' 'resume missing latest discriminator'
  },
  @{
    Name = 'latest pre-v1 discriminator'
    Json = Replace-RawScopeJsonExactOrFail $resumeContractJson $canonicalRawPlanContract '"responsibility_contract":{"version":0,"applicability":"required"}' 'resume pre-v1'
  },
  @{
    Name = 'latest unsupported discriminator'
    Json = Replace-RawScopeJsonExactOrFail $resumeContractJson $canonicalRawPlanContract '"responsibility_contract":{"version":2,"applicability":"required"}' 'resume unsupported'
  },
  @{
    Name = 'duplicate latest plan key invalid-first-valid-last'
    Json = Replace-RawScopeJsonExactOrFail $resumeContractJson $canonicalRawPlanContract ('"responsibility_contract":{"version":2,"applicability":"required"},' + $canonicalRawPlanContract) 'resume duplicate invalid-first'
  },
  @{
    Name = 'duplicate latest plan key valid-first-invalid-last'
    Json = Replace-RawScopeJsonExactOrFail $resumeContractJson $canonicalRawPlanContract ($canonicalRawPlanContract + ',"responsibility_contract":{"version":2,"applicability":"required"}') 'resume duplicate valid-first'
  },
  @{
    Name = 'duplicate latest version child invalid-first-valid-last'
    Json = Replace-RawScopeJsonExactOrFail $resumeContractJson $canonicalRawPlanContract '"responsibility_contract":{"version":2,"version":1,"applicability":"required"}' 'resume duplicate version'
  },
  @{
    Name = 'duplicate latest applicability child invalid-first-valid-last'
    Json = Replace-RawScopeJsonExactOrFail $resumeContractJson $canonicalRawPlanContract '"responsibility_contract":{"version":1,"applicability":"optional","applicability":"required"}' 'resume duplicate applicability'
  },
  @{
    Name = 'latest contract array'
    Json = Replace-RawScopeJsonExactOrFail $resumeContractJson $canonicalRawPlanContract '"responsibility_contract":[{"version":1,"applicability":"required"}]' 'resume contract array'
  },
  @{
    Name = 'latest string version'
    Json = Replace-RawScopeJsonExactOrFail $resumeContractJson $canonicalRawPlanContract '"responsibility_contract":{"version":"1","applicability":"required"}' 'resume string version'
  },
  @{
    Name = 'latest array version child'
    Json = Replace-RawScopeJsonExactOrFail $resumeContractJson $canonicalRawPlanContract '"responsibility_contract":{"version":[1],"applicability":"required"}' 'resume array version'
  },
  @{
    Name = 'latest object applicability child'
    Json = Replace-RawScopeJsonExactOrFail $resumeContractJson $canonicalRawPlanContract '"responsibility_contract":{"version":1,"applicability":{"value":"required"}}' 'resume object applicability'
  },
  @{
    Name = 'latest array applicability child'
    Json = Replace-RawScopeJsonExactOrFail $resumeContractJson $canonicalRawPlanContract '"responsibility_contract":{"version":1,"applicability":["required"]}' 'resume array applicability'
  },
  @{
    Name = 'latest missing version child'
    Json = Replace-RawScopeJsonExactOrFail $resumeContractJson $canonicalRawPlanContract '"responsibility_contract":{"applicability":"required"}' 'resume missing version'
  },
  @{
    Name = 'latest extra child'
    Json = Replace-RawScopeJsonExactOrFail $resumeContractJson $canonicalRawPlanContract '"responsibility_contract":{"version":1,"applicability":"required","extra":true}' 'resume extra child'
  }
)
foreach ($resumeContractCase in $resumeContractCases) {
  $resumeContractResult = Invoke-RawScopeScenario $resumeContractCase.Json
  Assert-Equal $resumeContractResult.result 'resume-blocked' "$($resumeContractCase.Name) must block standalone resume"
  Assert-Equal $resumeContractResult.reason 'responsibility-contract-version-invalid' "$($resumeContractCase.Name) must emit the canonical resume diagnostic"
}

$resumeProjectedIdentityCases = @(
  @{
    Name = 'decimal latest revision with string version'
    Json = '{"scenario_type":"scope-engine","operation":"validate-resume","master_spec_id":"SPEC-ADMIN-001","latest_spec_revision":1,"spec_revisions":[{"artifact_id":"SPEC-ADMIN-001","revision":1,"supersedes":"not-applicable","status":"approved","stale":false}],"revisions":[{"artifact_id":"PLAN-ADMIN-001","revision":1.0,"supersedes":"not-applicable","status":"approved","master_spec_revision":1,"stale":false,"responsibility_contract":{"version":"1","applicability":"required"}}]}'
  },
  @{
    Name = 'duplicate latest revision invalid-first-valid-last with string version'
    Json = '{"scenario_type":"scope-engine","operation":"validate-resume","master_spec_id":"SPEC-ADMIN-001","latest_spec_revision":1,"spec_revisions":[{"artifact_id":"SPEC-ADMIN-001","revision":1,"supersedes":"not-applicable","status":"approved","stale":false}],"revisions":[{"artifact_id":"PLAN-ADMIN-001","revision":0,"revision":1,"supersedes":"not-applicable","status":"approved","master_spec_revision":1,"stale":false,"responsibility_contract":{"version":"1","applicability":"required"}}]}'
  },
  @{
    Name = 'string latest revision without discriminator'
    Json = '{"scenario_type":"scope-engine","operation":"validate-resume","master_spec_id":"SPEC-ADMIN-001","latest_spec_revision":1,"spec_revisions":[{"artifact_id":"SPEC-ADMIN-001","revision":1,"supersedes":"not-applicable","status":"approved","stale":false}],"revisions":[{"artifact_id":"PLAN-ADMIN-001","revision":"1","supersedes":"not-applicable","status":"approved","master_spec_revision":1,"stale":false}]}'
  },
  @{
    Name = 'boolean latest revision without discriminator'
    Json = '{"scenario_type":"scope-engine","operation":"validate-resume","master_spec_id":"SPEC-ADMIN-001","latest_spec_revision":1,"spec_revisions":[{"artifact_id":"SPEC-ADMIN-001","revision":1,"supersedes":"not-applicable","status":"approved","stale":false}],"revisions":[{"artifact_id":"PLAN-ADMIN-001","revision":true,"supersedes":"not-applicable","status":"approved","master_spec_revision":1,"stale":false}]}'
  }
)
foreach ($resumeProjectedIdentityCase in $resumeProjectedIdentityCases) {
  $resumeProjectedIdentityResult = Invoke-RawScopeScenario $resumeProjectedIdentityCase.Json
  Assert-Equal $resumeProjectedIdentityResult.result 'resume-blocked' "$($resumeProjectedIdentityCase.Name) must not bypass raw standalone-resume validation"
  Assert-Equal $resumeProjectedIdentityResult.reason 'responsibility-contract-version-invalid' "$($resumeProjectedIdentityCase.Name) must emit the canonical raw resume diagnostic"
}

if ($failures.Count -gt 0) {
  $failures | ForEach-Object { Write-Output "FAIL: $_" }
  exit 1
}

Write-Output 'PASS: scope engine behavioral scenarios'
exit 0

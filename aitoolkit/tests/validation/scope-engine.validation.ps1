$convertToArcScopeRawJsonDocument = {
  param([string]$JsonText)
  [void](Add-Type -AssemblyName System.Runtime.Serialization -ErrorAction Stop)
  $bytes = [Text.Encoding]::UTF8.GetBytes($JsonText)
  $reader = $null
  try {
    $reader = [System.Runtime.Serialization.Json.JsonReaderWriterFactory]::CreateJsonReader(
      $bytes,
      [Xml.XmlDictionaryReaderQuotas]::Max
    )
    $document = [Xml.XmlDocument]::new()
    $document.Load($reader)
    return $document
  }
  finally {
    if ($null -ne $reader) { $reader.Close() }
  }
}

$getArcScopeRawJsonMembers = {
  param([Xml.XmlElement]$Parent, [string]$Name)
  if ($null -eq $Parent) { return }
  foreach ($child in @($Parent.ChildNodes)) {
    if (
      $child.NodeType -eq [Xml.XmlNodeType]::Element -and
      [string]$child.LocalName -ceq $Name
    ) {
      Write-Output $child
    }
  }
}

$getArcScopeRawJsonLastMember = {
  param([Xml.XmlElement]$Parent, [string]$Name)
  $members = @(& $getArcScopeRawJsonMembers $Parent $Name)
  if ($members.Count -eq 0) { return $null }
  return $members[$members.Count - 1]
}

$testArcScopeRawPlanResponsibilityContract = {
  param([Xml.XmlElement]$Plan)
  $contractMembers = @(& $getArcScopeRawJsonMembers $Plan 'responsibility_contract')
  if (
    $contractMembers.Count -ne 1 -or
    [string]$contractMembers[0].GetAttribute('type') -cne 'object'
  ) {
    return $false
  }

  $contractChildren = @($contractMembers[0].ChildNodes | Where-Object {
    $_.NodeType -eq [Xml.XmlNodeType]::Element
  })
  $versionMembers = @(& $getArcScopeRawJsonMembers $contractMembers[0] 'version')
  $applicabilityMembers = @(& $getArcScopeRawJsonMembers $contractMembers[0] 'applicability')
  return (
    $contractChildren.Count -eq 2 -and
    $versionMembers.Count -eq 1 -and
    $applicabilityMembers.Count -eq 1 -and
    [string]$versionMembers[0].GetAttribute('type') -ceq 'number' -and
    @($versionMembers[0].ChildNodes | Where-Object { $_.NodeType -eq [Xml.XmlNodeType]::Element }).Count -eq 0 -and
    [string]$versionMembers[0].InnerText -ceq '1' -and
    [string]$applicabilityMembers[0].GetAttribute('type') -ceq 'string' -and
    @($applicabilityMembers[0].ChildNodes | Where-Object { $_.NodeType -eq [Xml.XmlNodeType]::Element }).Count -eq 0 -and
    [string]$applicabilityMembers[0].InnerText -ceq 'required'
  )
}

$getArcScopeRawPlanResponsibilityContractStates = {
  param([Xml.XmlDocument]$Document)
  $root = $Document.DocumentElement
  $getStates = {
    param([Xml.XmlElement]$RevisionArray)
    if (
      $null -eq $RevisionArray -or
      [string]$RevisionArray.GetAttribute('type') -cne 'array'
    ) {
      return
    }
    foreach ($revision in @($RevisionArray.ChildNodes | Where-Object {
      $_.NodeType -eq [Xml.XmlNodeType]::Element
    })) {
      Write-Output ([bool](
        [string]$revision.LocalName -ceq 'item' -and
        [string]$revision.GetAttribute('type') -ceq 'object' -and
        (& $testArcScopeRawPlanResponsibilityContract $revision)
      ))
    }
  }

  $currentStates = @()
  $resumeStates = @()
  if (
    $null -ne $root -and
    [string]$root.GetAttribute('type') -ceq 'object'
  ) {
    $context = & $getArcScopeRawJsonLastMember $root 'orchestration_context'
    if (
      $null -ne $context -and
      [string]$context.GetAttribute('type') -ceq 'object'
    ) {
      $currentStates = @(& $getStates (& $getArcScopeRawJsonLastMember $context 'plan_revisions'))
    }
    $resumeStates = @(& $getStates (& $getArcScopeRawJsonLastMember $root 'revisions'))
  }

  return [pscustomobject]@{
    Current = $currentStates
    Resume = $resumeStates
  }
}

function Test-ScopeEngine([string]$Root, [string]$ContractText) {
  $contractPath = Join-Path $Root 'contracts/migration-scope-orchestration.md'
  if (-not (Test-Path -LiteralPath $contractPath -PathType Leaf)) {
    $errors.Add('Missing migration scope orchestration contract resource')
    return
  }

  $candidateText = if ($null -eq $ContractText) { '' } else { $ContractText.TrimStart() }
  if ($candidateText.StartsWith('{', [StringComparison]::Ordinal)) {
    try {
      $rawJsonDocument = & $convertToArcScopeRawJsonDocument $ContractText
      $rawPlanContractStates = & $getArcScopeRawPlanResponsibilityContractStates $rawJsonDocument
      $scenario = $ContractText | ConvertFrom-Json
    }
    catch {
      return [pscustomobject]@{ result = 'scenario-invalid'; reason = 'invalid-json' }
    }
    if ($scenario.scenario_type -cne 'scope-engine') {
      return [pscustomobject]@{ result = 'scenario-invalid'; reason = 'invalid-scenario-type' }
    }
    $isExactJsonTrue = { param([object]$Value) $Value -is [bool] -and $Value -eq $true }

    if ($scenario.operation -ceq 'resolve-scope') {
      $scope = $scenario.requested_scope
      $allowedKinds = @('project', 'module', 'feature', 'task', 'explicit-item', 'unresolved')
      if (
        $null -eq $scope -or
        $allowedKinds -cnotcontains [string]$scope.kind -or
        [string]::IsNullOrWhiteSpace([string]$scope.id) -or
        [string]::IsNullOrWhiteSpace([string]$scope.statement) -or
        [string]::IsNullOrWhiteSpace([string]$scope.source) -or
        [string]::IsNullOrWhiteSpace([string]$scope.resolution_evidence)
      ) {
        return [pscustomobject]@{
          result = 'scope-invalid'
          requested_scope_kind = [string]$scope.kind
          scope_question_count = 0
          can_run_step_01 = $false
          boundary = 'unresolved'
        }
      }
      if ($scope.kind -ceq 'unresolved') {
        $questionTemplate = [Text.Encoding]::UTF8.GetString(
          [Convert]::FromBase64String('QuG6oW4gbXXhu5FuIG1pZ3JhdGUgezB9IOG7nyBwaOG6oW0gdmkgcHJvamVjdCwgbW9kdWxlLCBmZWF0dXJlLCB0YXNrIGhheSBleHBsaWNpdCBpdGVtPw==')
        )
        return [pscustomobject]@{
          result = 'scope-question-required'
          requested_scope_kind = 'unresolved'
          scope_question_count = 1
          can_run_step_01 = $false
          boundary = 'unresolved'
          questions = @(
            [pscustomobject]@{
              id = 'requested-scope'
              prompt = [string]::Format([Globalization.CultureInfo]::InvariantCulture, $questionTemplate, [string]$scope.id)
            }
          )
        }
      }
      $boundary = if ($scope.kind -ceq 'explicit-item') {
        'minimum-item-and-dependency-context'
      }
      else {
        'requested-scope'
      }
      return [pscustomobject]@{
        result = 'scope-resolved'
        requested_scope_kind = [string]$scope.kind
        scope_question_count = 0
        can_run_step_01 = $true
        boundary = $boundary
      }
    }

    if (@('select', 'transition', 'complete-scope') -ccontains [string]$scenario.operation) {
      $context = $scenario.orchestration_context
      $scope = $context.requested_scope
      $allowedKinds = @('project', 'module', 'feature', 'task', 'explicit-item')
      if (
        $null -eq $context -or
        $null -eq $scope -or
        $allowedKinds -cnotcontains [string]$scope.kind -or
        [string]::IsNullOrWhiteSpace([string]$scope.id) -or
        [string]::IsNullOrWhiteSpace([string]$scope.statement) -or
        [string]::IsNullOrWhiteSpace([string]$scope.resolution_evidence)
      ) {
        return [pscustomobject]@{ result = 'orchestration-blocked'; reason = 'requested-scope-unresolved'; gate = 'requested-scope' }
      }

      $placeholderValues = @('', 'pending', 'none', 'not-applicable')
      if (
        [string]::IsNullOrWhiteSpace([string]$context.master_spec_ref) -or
        [string]::IsNullOrWhiteSpace([string]$context.master_plan_ref) -or
        $placeholderValues -ccontains ([string]$context.master_spec_ref).Trim() -or
        $placeholderValues -ccontains ([string]$context.master_plan_ref).Trim()
      ) {
        return [pscustomobject]@{ result = 'orchestration-blocked'; reason = 'master-artifact-reference-invalid'; gate = 'master-artifacts' }
      }

      $currentSpecs = @($context.spec_revisions | Where-Object {
        [string]$_.artifact_reference -ceq [string]$context.master_spec_ref -and
        [string]$_.artifact_id -ceq [string]$context.master_spec_id -and
        [int]$_.revision -eq [int]$context.latest_spec_revision
      })
      if (
        $currentSpecs.Count -ne 1 -or
        $currentSpecs[0].artifact_type -cne 'migration-master-spec' -or
        -not (& $isExactJsonTrue $currentSpecs[0].immutable)
      ) {
        return [pscustomobject]@{ result = 'orchestration-blocked'; reason = 'master-spec-artifact-resolution-invalid'; gate = 'master-spec' }
      }
      if (
        $currentSpecs[0].status -cne 'approved' -or
        $currentSpecs[0].result -cne 'complete'
      ) {
        return [pscustomobject]@{ result = 'orchestration-blocked'; reason = 'approved-master-spec-revision-missing'; gate = 'master-spec' }
      }
      if (
        [string]::IsNullOrWhiteSpace([string]$currentSpecs[0].approval_reference) -or
        [string]::IsNullOrWhiteSpace([string]$currentSpecs[0].freshness_evidence) -or
        $placeholderValues -ccontains ([string]$currentSpecs[0].approval_reference).Trim() -or
        $placeholderValues -ccontains ([string]$currentSpecs[0].freshness_evidence).Trim()
      ) {
        return [pscustomobject]@{ result = 'orchestration-blocked'; reason = 'master-spec-evidence-invalid'; gate = 'master-spec' }
      }

      $projectedPlanRevisions = @($context.plan_revisions)
      $currentPlans = @()
      $currentPlanIndexes = @()
      for ($planRevisionIndex = 0; $planRevisionIndex -lt $projectedPlanRevisions.Count; $planRevisionIndex++) {
        $planRevision = $projectedPlanRevisions[$planRevisionIndex]
        if (
          [string]$planRevision.artifact_reference -ceq [string]$context.master_plan_ref -and
          [string]$planRevision.artifact_id -ceq [string]$context.master_plan_id -and
          [int]$planRevision.revision -eq [int]$context.current_plan_revision
        ) {
          $currentPlans += $planRevision
          $currentPlanIndexes += $planRevisionIndex
        }
      }
      if (
        $currentPlans.Count -ne 1 -or
        $currentPlans[0].artifact_type -cne 'migration-master-plan' -or
        -not (& $isExactJsonTrue $currentPlans[0].immutable)
      ) {
        return [pscustomobject]@{ result = 'orchestration-blocked'; reason = 'master-plan-artifact-resolution-invalid'; gate = 'master-plan' }
      }
      if (
        $currentPlans[0].status -cne 'approved' -or
        $currentPlans[0].result -cne 'complete'
      ) {
        return [pscustomobject]@{ result = 'orchestration-blocked'; reason = 'approved-master-plan-revision-missing'; gate = 'master-plan' }
      }
      if (
        [string]::IsNullOrWhiteSpace([string]$currentPlans[0].approval_reference) -or
        [string]::IsNullOrWhiteSpace([string]$currentPlans[0].freshness_evidence) -or
        $placeholderValues -ccontains ([string]$currentPlans[0].approval_reference).Trim() -or
        $placeholderValues -ccontains ([string]$currentPlans[0].freshness_evidence).Trim()
      ) {
        return [pscustomobject]@{ result = 'orchestration-blocked'; reason = 'master-plan-evidence-invalid'; gate = 'master-plan' }
      }
      if (
        [int]$scenario.current_plan_revision -ne [int]$context.current_plan_revision -or
        [string]$currentPlans[0].master_spec_ref -cne [string]$context.master_spec_ref -or
        [string]$currentPlans[0].master_spec_id -cne [string]$context.master_spec_id -or
        [int]$currentPlans[0].master_spec_revision -ne [int]$context.latest_spec_revision
      ) {
        return [pscustomobject]@{ result = 'orchestration-blocked'; reason = 'master-plan-current-link-mismatch'; gate = 'master-plan' }
      }

      $currentRawPlanContractStates = @($rawPlanContractStates.Current)
      $currentPlanIndex = if ($currentPlanIndexes.Count -eq 1) { [int]$currentPlanIndexes[0] } else { -1 }
      if (
        $currentRawPlanContractStates.Count -ne $projectedPlanRevisions.Count -or
        $currentPlanIndex -lt 0 -or
        $currentPlanIndex -ge $currentRawPlanContractStates.Count -or
        -not [bool]$currentRawPlanContractStates[$currentPlanIndex]
      ) {
        return [pscustomobject]@{ result = 'orchestration-blocked'; reason = 'responsibility-contract-version-invalid'; gate = 'master-plan' }
      }

      $planContractProperties = @($currentPlans[0].PSObject.Properties | Where-Object {
        [string]$_.Name -ceq 'responsibility_contract'
      })
      $planContract = if ($planContractProperties.Count -eq 1) { $planContractProperties[0].Value } else { $null }
      $planContractChildren = if ($null -ne $planContract -and -not ($planContract -is [array])) {
        @($planContract.PSObject.Properties)
      }
      else { @() }
      if (
        $planContractProperties.Count -ne 1 -or
        $planContractChildren.Count -ne 2 -or
        @($planContractChildren | Where-Object { [string]$_.Name -ceq 'version' }).Count -ne 1 -or
        @($planContractChildren | Where-Object { [string]$_.Name -ceq 'applicability' }).Count -ne 1 -or
        [string]$planContract.version -cne '1' -or
        [string]$planContract.applicability -cne 'required'
      ) {
        return [pscustomobject]@{ result = 'orchestration-blocked'; reason = 'responsibility-contract-version-invalid'; gate = 'master-plan' }
      }

      $resumeFixture = @{
        scenario_type = 'scope-engine'
        operation = 'validate-resume'
        master_spec_id = [string]$context.master_spec_id
        latest_spec_revision = [int]$context.latest_spec_revision
        spec_revisions = @($context.spec_revisions)
        revisions = @($context.plan_revisions)
      } | ConvertTo-Json -Depth 20 -Compress
      $resumeGate = Test-ScopeEngine $Root $resumeFixture
      if ($resumeGate.result -cne 'resume-ready') {
        return [pscustomobject]@{ result = 'orchestration-blocked'; reason = [string]$resumeGate.reason; gate = 'revision-chain' }
      }
      if ([int]$resumeGate.latest_plan_revision -ne [int]$context.current_plan_revision) {
        return [pscustomobject]@{ result = 'orchestration-blocked'; reason = 'latest-master-plan-revision-mismatch'; gate = 'revision-chain' }
      }
      $approvedPlanRows = @($currentPlans[0].work_items) | ConvertTo-Json -Depth 30 -Compress
      $operationRows = @($scenario.work_items) | ConvertTo-Json -Depth 30 -Compress
      if ($approvedPlanRows -cne $operationRows) {
        return [pscustomobject]@{ result = 'orchestration-blocked'; reason = 'work-items-not-bound-to-master-plan'; gate = 'master-plan-work-items' }
      }
    }

    $testExactOrdinalValues = {
      param([object[]]$Actual, [object[]]$Expected)
      if ($Actual.Count -ne $Expected.Count) { return $false }
      for ($ordinalIndex = 0; $ordinalIndex -lt $Expected.Count; $ordinalIndex++) {
        if ([string]$Actual[$ordinalIndex] -cne [string]$Expected[$ordinalIndex]) { return $false }
      }
      return $true
    }
    $testIndependentBoundaryEvidence = {
      param([string]$Value)
      return (
        -not [string]::IsNullOrWhiteSpace($Value) -and
        $Value -cnotmatch '^(?:<[^>]+>|unknown|none|not-applicable|pending|tbd)$' -and
        $Value -match '(?i)implementable' -and
        $Value -match '(?i)reviewable' -and
        $Value -match '(?i)verifiable|testable' -and
        $Value -match '(?i)revertible' -and
        $Value -match '^(?:(?:[A-Za-z0-9_.-]+/)*[A-Za-z0-9_.-]+\.md#(?:RULE|DECISION|APPROVAL)-[A-Z0-9-]+|approval:(?:TECH-LEAD|OWNER)-[A-Z0-9-]+)(?::\s*.+)?$'
      )
    }

    $testPlannedResponsibilityAuthority = {
      param([object]$Item)

      $selectionRows = @($currentPlans[0].delivery_adapter_selections | Where-Object {
        [string]$_.work_item_id -ceq [string]$Item.work_item_id
      })
      $ownerRows = @($currentPlans[0].responsibility_owner_references | Where-Object {
        [string]$_.work_item_id -ceq [string]$Item.work_item_id
      })
      if ($selectionRows.Count -ne 1 -or $ownerRows.Count -ne 1) { return $false }
      $selection = $selectionRows[0]
      $owner = $ownerRows[0]
      $itemTraceIds = @($Item.trace_ids)
      $selectionTraceIds = @($selection.trace_ids)
      $adapterKind = [string]$selection.adapter_kind
      $adapterAuthorityValid = if ($adapterKind -ceq 'none') {
        @('external_id', 'authority', 'authority_revision', 'approval_reference', 'parent_selector') |
          Where-Object { [string]$selection.$_ -cne 'not-applicable' } |
          Measure-Object |
          Select-Object -ExpandProperty Count
      }
      else {
        $externalIdValid = if ($adapterKind -ceq 'migration-unit') {
          [string]$selection.external_id -cmatch '^UNIT-[A-Z0-9]+(?:-[A-Z0-9]+)*$'
        }
        else {
          [string]$selection.external_id -cmatch '^[A-Za-z0-9][A-Za-z0-9:._/-]*$'
        }
        if (
          $adapterKind -cnotin @('migration-unit', 'task', 'story', 'package', 'phase', 'milestone') -or
          -not $externalIdValid -or
          [string]$selection.external_id -cin $placeholderValues -or
          [string]::IsNullOrWhiteSpace([string]$selection.authority) -or
          [string]$selection.authority -cnotmatch '^[A-Za-z0-9][A-Za-z0-9:._/-]*$' -or
          [string]$selection.authority -match '@' -or
          [string]$selection.authority -cin $placeholderValues -or
          [string]$selection.authority_revision -cnotmatch '^[1-9][0-9]*$' -or
          [string]$selection.approval_reference -cnotmatch '^approval:(?![^\r\n]*(?:PENDING|TBD|UNKNOWN|PLACEHOLDER))[A-Z0-9]+(?:-[A-Z0-9]+)*$'
        ) { 1 } else { 0 }
      }
      if (
        $adapterAuthorityValid -ne 0 -or
        [string]$selection.adapter_kind -cne [string]$Item.adapter_kind -or
        ($adapterKind -cne 'none' -and [string]$selection.external_id -cne [string]$Item.external_id) -or
        [string]$selection.acceptance -cne [string]$Item.acceptance -or
        ($selectionTraceIds -join '|') -cne ($itemTraceIds -join '|') -or
        [string]$selection.mode_constraint -cnotin @('incremental/preserve-existing', 'greenfield/design-new') -or
        [string]$selection.mode_constraint -cne [string]$Item.mode_constraint -or
        [string]$selection.design_revision -cnotmatch '^DESIGN-[A-Z0-9]+(?:-[A-Z0-9]+)*@[1-9][0-9]*$' -or
        [string]$owner.design_revision -cne [string]$selection.design_revision -or
        -not (& $testIndependentBoundaryEvidence ([string]$owner.independent_boundary_evidence))
      ) { return $false }

      $concreteResponsibilityIds = @($owner.responsibility_ids)
      $sharedResponsibilityIds = @($owner.shared_foundation_ids)
      $integrationResponsibilityIds = @($owner.integration_responsibility_ids)
      $sharedCategoryValid = (
        $sharedResponsibilityIds.Count -eq 1 -and [string]$sharedResponsibilityIds[0] -ceq 'not-applicable'
      ) -or (
        $sharedResponsibilityIds.Count -gt 0 -and
        @($sharedResponsibilityIds | Where-Object { [string]$_ -cnotmatch '^RESP-[A-Z0-9]+(?:-[A-Z0-9]+)*$' }).Count -eq 0 -and
        @($sharedResponsibilityIds | Group-Object | Where-Object Count -ne 1).Count -eq 0
      )
      $integrationCategoryValid = (
        $integrationResponsibilityIds.Count -eq 1 -and [string]$integrationResponsibilityIds[0] -ceq 'not-applicable'
      ) -or (
        $integrationResponsibilityIds.Count -gt 0 -and
        @($integrationResponsibilityIds | Where-Object { [string]$_ -cnotmatch '^RESP-[A-Z0-9]+(?:-[A-Z0-9]+)*$' }).Count -eq 0 -and
        @($integrationResponsibilityIds | Group-Object | Where-Object Count -ne 1).Count -eq 0
      )
      if (
        $concreteResponsibilityIds.Count -eq 0 -or
        @($concreteResponsibilityIds | Where-Object { [string]$_ -cnotmatch '^RESP-[A-Z0-9]+(?:-[A-Z0-9]+)*$' }).Count -gt 0 -or
        @($concreteResponsibilityIds | Group-Object | Where-Object Count -ne 1).Count -gt 0 -or
        -not $sharedCategoryValid -or
        -not $integrationCategoryValid
      ) { return $false }
      $allConcreteIds = @($concreteResponsibilityIds + @($sharedResponsibilityIds | Where-Object { $_ -cne 'not-applicable' }) + @($integrationResponsibilityIds | Where-Object { $_ -cne 'not-applicable' }))
      if (@($allConcreteIds | Group-Object | Where-Object Count -ne 1).Count -gt 0) { return $false }

      $designArtifacts = @($scenario.orchestration_context.resolved_artifacts | Where-Object {
        [string]$_.step_id -ceq '07-technical-design' -and
        [string]$_.work_item_id -ceq [string]$Item.work_item_id -and
        [string]$_.revision -ceq [string]$owner.design_revision
      })
      if ($designArtifacts.Count -ne 1) { return $false }
      $design = $designArtifacts[0]
      if (
        -not (& $isExactJsonTrue $design.immutable) -or
        [string]$design.step_id -cne '07-technical-design' -or
        [string]$design.status -cne 'approved' -or
        [string]$design.result -cne 'complete' -or
        [string]$design.approval_source -cne 'human' -or
        [string]$design.run_id -cne [string]$context.run_id -or
        [string]$design.master_spec_ref -cne [string]$context.master_spec_ref -or
        [string]$design.master_spec_id -cne [string]$context.master_spec_id -or
        [int]$design.master_spec_revision -ne [int]$context.latest_spec_revision -or
        [string]$design.master_plan_ref -cne [string]$context.master_plan_ref -or
        [string]$design.master_plan_id -cne [string]$context.master_plan_id -or
        [int]$design.master_plan_revision -ne [int]$context.current_plan_revision -or
        [string]$design.work_item_id -cne [string]$Item.work_item_id -or
        [string]$design.revision -cne [string]$owner.design_revision -or
        [string]$design.mode_constraint -cne [string]$Item.mode_constraint -or
        $null -eq $design.PSObject.Properties['responsibility_contract'] -or
        [int]$design.responsibility_contract.version -ne 1 -or
        [string]$design.responsibility_contract.applicability -cne 'required'
      ) { return $false }
      $designResponsibilities = @($design.responsibility_rows)
      $designVerifications = @($design.verification_rows)
      $designDeviations = @($design.approved_deviation_rows)
      $responsibilitySchema = @(
        'responsibility_id', 'owner_path', 'owner_symbol', 'boundary_kind',
        'primary_responsibility', 'owned_capability_ids', 'trace_ids', 'atomic_boundary_id',
        'public_symbols', 'external_effects', 'target_exemplar', 'exemplar_classification',
        'classification_authority', 'classification_evidence', 'architecture_authority',
        'co_location_policy', 'co_location_evidence', 'verification_owner_references',
        'conformance', 'deviation_reference'
      )
      $verificationSchema = @(
        'verification_owner_id', 'production_responsibility_id', 'capability_id',
        'evidence_path', 'evidence_symbol_or_scenario', 'evidence_kind',
        'verification_disposition', 'production_binding_evidence', 'decision_reference',
        'verdict', 'deviation_reference'
      )
      $deviationSchema = @('deviation_reference', 'concern', 'conflict_reference', 'resolved_decision', 'tech_lead_approval')
      $testExactObjectSchema = {
        param([object]$Row, [string[]]$Expected)
        $actual = @($Row.PSObject.Properties.Name)
        if ($actual.Count -ne $Expected.Count) { return $false }
        foreach ($name in $Expected) {
          if (@($actual | Where-Object { [string]$_ -ceq $name }).Count -ne 1) { return $false }
        }
        return $true
      }
      if (
        $designResponsibilities.Count -eq 0 -or
        @($designResponsibilities | Where-Object { -not (& $testExactObjectSchema $_ $responsibilitySchema) }).Count -ne 0 -or
        @($designVerifications | Where-Object { -not (& $testExactObjectSchema $_ $verificationSchema) }).Count -ne 0 -or
        @($designDeviations | Where-Object { -not (& $testExactObjectSchema $_ $deviationSchema) }).Count -ne 0
      ) { return $false }
      $canonicalValidatorPath = Join-Path $Root 'tests/validation/responsibility-conformance.validation.ps1'
      if (-not (Test-Path -LiteralPath $canonicalValidatorPath -PathType Leaf)) { return $false }
      if ($null -eq (Get-Command -Name Test-ArcCanonicalDesignAuthorityRows -CommandType Function -ErrorAction SilentlyContinue)) {
        . $canonicalValidatorPath
      }
      if ($null -eq (Get-Command -Name Test-ArcCanonicalDesignAuthorityRows -CommandType Function -ErrorAction SilentlyContinue)) { return $false }
      $joinProjectionList = {
        param([object]$Value)
        return (@($Value | ForEach-Object { [string]$_ }) -join '; ')
      }
      $canonicalResponsibilities = @($designResponsibilities | ForEach-Object {
        $row = $_
        [ordered]@{
          'Responsibility ID' = [string]$row.responsibility_id
          'Owner Path' = [string]$row.owner_path
          'Owner Symbol' = [string]$row.owner_symbol
          'Boundary Kind' = [string]$row.boundary_kind
          'Primary Responsibility' = [string]$row.primary_responsibility
          'Owned Capability IDs' = & $joinProjectionList $row.owned_capability_ids
          'Trace IDs' = & $joinProjectionList $row.trace_ids
          'Atomic Boundary ID' = [string]$row.atomic_boundary_id
          'Public Symbols' = & $joinProjectionList $row.public_symbols
          'External Effects' = & $joinProjectionList $row.external_effects
          'Target Exemplar' = [string]$row.target_exemplar
          'Exemplar Classification' = [string]$row.exemplar_classification
          'Classification Authority' = [string]$row.classification_authority
          'Classification Evidence' = [string]$row.classification_evidence
          'Architecture Authority' = [string]$row.architecture_authority
          'Co-location Policy' = [string]$row.co_location_policy
          'Co-location Evidence' = [string]$row.co_location_evidence
          'Verification Owner References' = & $joinProjectionList $row.verification_owner_references
          'Conformance' = [string]$row.conformance
          'Deviation Reference' = [string]$row.deviation_reference
        }
      })
      $canonicalVerifications = @($designVerifications | ForEach-Object {
        $row = $_
        [ordered]@{
          'Verification Owner ID' = [string]$row.verification_owner_id
          'Production Responsibility ID' = [string]$row.production_responsibility_id
          'Capability ID' = [string]$row.capability_id
          'Evidence Path' = [string]$row.evidence_path
          'Evidence Symbol or Scenario' = [string]$row.evidence_symbol_or_scenario
          'Evidence Kind' = [string]$row.evidence_kind
          'Verification Disposition' = [string]$row.verification_disposition
          'Production Binding Evidence' = [string]$row.production_binding_evidence
          'Decision Reference' = [string]$row.decision_reference
          'Verdict' = [string]$row.verdict
          'Deviation Reference' = [string]$row.deviation_reference
        }
      })
      $canonicalDeviations = @($designDeviations | ForEach-Object {
        $row = $_
        [ordered]@{
          'Deviation Reference' = [string]$row.deviation_reference
          'Concern' = [string]$row.concern
          'Conflict Reference' = [string]$row.conflict_reference
          'Resolved Decision' = [string]$row.resolved_decision
          'Tech Lead Approval' = [string]$row.tech_lead_approval
        }
      })
      $canonicalDesignDiagnostics = @(Test-ArcCanonicalDesignAuthorityRows `
        -ResponsibilityRows $canonicalResponsibilities `
        -VerificationRows $canonicalVerifications `
        -ApprovedDeviationRows $canonicalDeviations `
        -ModeConstraint ([string]$design.mode_constraint)
      )
      if ($canonicalDesignDiagnostics.Count -ne 0) { return $false }
      $expectedConcreteResponsibilityIds = @($designResponsibilities | Where-Object {
        [string]$_.co_location_policy -cne 'shared-foundation' -and [string]$_.boundary_kind -cne 'integration'
      } | ForEach-Object { [string]$_.responsibility_id })
      $expectedSharedResponsibilityIds = @($designResponsibilities | Where-Object {
        [string]$_.co_location_policy -ceq 'shared-foundation'
      } | ForEach-Object { [string]$_.responsibility_id })
      $expectedIntegrationResponsibilityIds = @($designResponsibilities | Where-Object {
        [string]$_.co_location_policy -cne 'shared-foundation' -and [string]$_.boundary_kind -ceq 'integration'
      } | ForEach-Object { [string]$_.responsibility_id })
      $expectedSharedOwnerCell = if ($expectedSharedResponsibilityIds.Count -eq 0) { @('not-applicable') } else { $expectedSharedResponsibilityIds }
      $expectedIntegrationOwnerCell = if ($expectedIntegrationResponsibilityIds.Count -eq 0) { @('not-applicable') } else { $expectedIntegrationResponsibilityIds }
      if (
        -not (& $testExactOrdinalValues $concreteResponsibilityIds $expectedConcreteResponsibilityIds) -or
        -not (& $testExactOrdinalValues $sharedResponsibilityIds $expectedSharedOwnerCell) -or
        -not (& $testExactOrdinalValues $integrationResponsibilityIds $expectedIntegrationOwnerCell)
      ) { return $false }
      $verificationOwnerIds = @($designResponsibilities | ForEach-Object {
        @($_.verification_owner_references | Where-Object { [string]$_ -cne 'not-applicable' })
      })
      if (
        $verificationOwnerIds.Count -eq 0 -or
        @($verificationOwnerIds | Where-Object { [string]$_ -cnotmatch '^VERIFY-OWNER-[A-Z0-9]+(?:-[A-Z0-9]+)*$' }).Count -gt 0 -or
        @($verificationOwnerIds | Group-Object | Where-Object Count -ne 1).Count -gt 0
      ) { return $false }
      if ($designResponsibilities.Count -ne $allConcreteIds.Count -or $designVerifications.Count -ne $verificationOwnerIds.Count) { return $false }
      foreach ($responsibilityId in $allConcreteIds) {
        $responsibilityMatches = @($designResponsibilities | Where-Object { [string]$_.responsibility_id -ceq [string]$responsibilityId })
        if ($responsibilityMatches.Count -ne 1) { return $false }
      }
      return $true
    }

    $resolvePlanWideResponsibilityBlock = {
      param([object[]]$Items)
      $workItemAuthorityIds = @($currentPlans[0].work_items | ForEach-Object { [string]$_.work_item_id })
      $selectorAuthorityIds = @($currentPlans[0].delivery_adapter_selections | ForEach-Object { [string]$_.work_item_id })
      $ownerAuthorityIds = @($currentPlans[0].responsibility_owner_references | ForEach-Object { [string]$_.work_item_id })
      $authorityIdsValid = (
        $workItemAuthorityIds.Count -gt 0 -and
        @($workItemAuthorityIds | Where-Object { $_ -cnotmatch '^WORK-[A-Z0-9]+(?:-[A-Z0-9]+)*$' }).Count -eq 0 -and
        @($workItemAuthorityIds | Group-Object | Where-Object Count -ne 1).Count -eq 0 -and
        (& $testExactOrdinalValues $selectorAuthorityIds $workItemAuthorityIds) -and
        (& $testExactOrdinalValues $ownerAuthorityIds $workItemAuthorityIds)
      )
      $selectorRows = @($currentPlans[0].delivery_adapter_selections)
      $selectorByWorkItem = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
      $selectorIndexByWorkItem = [Collections.Generic.Dictionary[string, int]]::new([StringComparer]::Ordinal)
      $selectorIdentityOwners = [Collections.Generic.Dictionary[string, string]]::new([StringComparer]::Ordinal)
      $selectorMapValid = $authorityIdsValid
      $canonicalSelectorMode = ''
      $canonicalSelectorDesignRevision = ''
      for ($selectorIndex = 0; $selectorIndex -lt $selectorRows.Count; $selectorIndex++) {
        $selectorRow = $selectorRows[$selectorIndex]
        $selectorWorkItemId = [string]$selectorRow.work_item_id
        if ($selectorByWorkItem.ContainsKey($selectorWorkItemId)) { $selectorMapValid = $false; continue }
        $selectorByWorkItem.Add($selectorWorkItemId, $selectorRow)
        $selectorIndexByWorkItem.Add($selectorWorkItemId, $selectorIndex)
        if ([string]$selectorRow.adapter_kind -cne 'none') {
          $selectorIdentity = [string]$selectorRow.external_id
          if ($selectorIdentityOwners.ContainsKey($selectorIdentity)) { $selectorMapValid = $false }
          else { $selectorIdentityOwners.Add($selectorIdentity, $selectorWorkItemId) }
        }
        $selectorMode = [string]$selectorRow.mode_constraint
        $selectorDesignRevision = [string]$selectorRow.design_revision
        if ($selectorMode -cnotin @('incremental/preserve-existing', 'greenfield/design-new')) { $selectorMapValid = $false }
        elseif ($canonicalSelectorMode -ceq '') { $canonicalSelectorMode = $selectorMode }
        elseif ($selectorMode -cne $canonicalSelectorMode) { $selectorMapValid = $false }
        if ($selectorDesignRevision -cnotmatch '^DESIGN-[A-Z0-9]+(?:-[A-Z0-9]+)*@[1-9][0-9]*$') { $selectorMapValid = $false }
        elseif ($canonicalSelectorDesignRevision -ceq '') { $canonicalSelectorDesignRevision = $selectorDesignRevision }
        elseif ($selectorDesignRevision -cne $canonicalSelectorDesignRevision) { $selectorMapValid = $false }
      }
      foreach ($selectorRow in $selectorRows) {
        $selectorWorkItemId = [string]$selectorRow.work_item_id
        $parentWorkItemId = [string]$selectorRow.parent_work_item_id
        $decompositionDecision = [string]$selectorRow.decomposition_decision_reference
        $isRootSelector = $parentWorkItemId -ceq 'not-applicable' -and $decompositionDecision -ceq 'not-applicable'
        if ($isRootSelector) {
          if ([string]$selectorRow.parent_selector -cne 'not-applicable') { $selectorMapValid = $false }
          continue
        }
        if (
          $parentWorkItemId -cnotmatch '^WORK-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -or
          $parentWorkItemId -ceq $selectorWorkItemId -or
          $decompositionDecision -cnotmatch '^DEC-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -or
          -not $selectorByWorkItem.ContainsKey($parentWorkItemId)
        ) { $selectorMapValid = $false; continue }
        $parentSelectorRow = $selectorByWorkItem[$parentWorkItemId]
        $expectedParentSelector = if (
          [string]$selectorRow.adapter_kind -ceq 'none' -or
          [string]$parentSelectorRow.adapter_kind -ceq 'none'
        ) { 'not-applicable' } else { [string]$parentSelectorRow.external_id }
        if (
          [string]$selectorRow.parent_selector -cne $expectedParentSelector -or
          $selectorIndexByWorkItem[$parentWorkItemId] -ge $selectorIndexByWorkItem[$selectorWorkItemId]
        ) { $selectorMapValid = $false }
      }
      $authorityIdsValid = $authorityIdsValid -and $selectorMapValid
      $seenPlannedResponsibilityIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
      $seenPlannedVerificationOwnerIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
      $invalidAuthorityItem = $null
      foreach ($candidateItem in $Items) {
        $candidateAuthorityValid = $authorityIdsValid -and (& $testPlannedResponsibilityAuthority $candidateItem)
        if ($candidateAuthorityValid) {
          $candidateOwner = @($currentPlans[0].responsibility_owner_references | Where-Object { [string]$_.work_item_id -ceq [string]$candidateItem.work_item_id })[0]
          $candidateResponsibilityIds = @(
            @($candidateOwner.responsibility_ids) +
            @($candidateOwner.shared_foundation_ids | Where-Object { [string]$_ -cne 'not-applicable' }) +
            @($candidateOwner.integration_responsibility_ids | Where-Object { [string]$_ -cne 'not-applicable' })
          )
          foreach ($candidateResponsibilityId in $candidateResponsibilityIds) {
            if (-not $seenPlannedResponsibilityIds.Add([string]$candidateResponsibilityId)) { $candidateAuthorityValid = $false }
          }
          $candidateDesign = @($scenario.orchestration_context.resolved_artifacts | Where-Object {
            [string]$_.step_id -ceq '07-technical-design' -and
            [string]$_.work_item_id -ceq [string]$candidateItem.work_item_id -and
            [string]$_.revision -ceq [string]$candidateOwner.design_revision
          })[0]
          foreach ($candidateVerificationOwnerId in @($candidateDesign.responsibility_rows | ForEach-Object {
            @($_.verification_owner_references | Where-Object { [string]$_ -cne 'not-applicable' })
          })) {
            if (-not $seenPlannedVerificationOwnerIds.Add([string]$candidateVerificationOwnerId)) { $candidateAuthorityValid = $false }
          }
        }
        if (-not $candidateAuthorityValid) {
          $candidateItem.tree_conformance = 'BLOCKED'
          $candidateItem.responsibility_conformance = 'BLOCKED'
          $candidateItem.verification_ownership = 'BLOCKED'
          $candidateItem.architecture_state = 'BLOCKED'
          $existingDiagnostic = if ($null -ne $candidateItem.PSObject.Properties['responsibility_diagnostic']) { [string]$candidateItem.responsibility_diagnostic } else { '' }
          if ([string]::IsNullOrWhiteSpace($existingDiagnostic) -or $existingDiagnostic -ceq 'none') {
            $candidateItem | Add-Member -NotePropertyName responsibility_diagnostic -NotePropertyValue 'planned-responsibility-authority-invalid' -Force
          }
          if ($null -eq $invalidAuthorityItem) { $invalidAuthorityItem = $candidateItem }
        }
      }

      if ($null -ne $invalidAuthorityItem) {
        return [pscustomobject]@{
          result = 'scope-blocked'
          reason = 'planned-responsibility-authority-invalid'
          scope_status = 'scope-blocked'
          work_item_id = ''
          reconciled_work_item_id = ''
        }
      }

      $structuralBlockers = @($Items | Where-Object {
        ([bool]$_.required -or [bool]$_.optional_execution_approved) -and
        (
          [string]$_.tree_conformance -cne 'PASS' -or
          [string]$_.responsibility_conformance -cne 'PASS' -or
          [string]$_.verification_ownership -cne 'PASS' -or
          [string]$_.architecture_state -cne 'PASS'
        )
      })
      if ($structuralBlockers.Count -eq 0) { return $null }

      $responsibilityBlocker = @($structuralBlockers | Where-Object {
        [string]$_.responsibility_conformance -cne 'PASS'
      } | Select-Object -First 1)
      $responsibilityDiagnostic = if ($responsibilityBlocker.Count -eq 1) {
        [string]$responsibilityBlocker[0].responsibility_diagnostic
      }
      else { '' }
      return [pscustomobject]@{
        result = 'scope-blocked'
        reason = if (
          [string]::IsNullOrWhiteSpace($responsibilityDiagnostic) -or
          $responsibilityDiagnostic -ceq 'none'
        ) { 'structural-assurance-blocked' } else { $responsibilityDiagnostic }
        scope_status = 'scope-blocked'
        work_item_id = ''
        reconciled_work_item_id = ''
      }
    }

    $testTerminalResponsibilityAuthority = {
      param([object]$Item, [string]$Reference)
      $terminalArtifacts = @($scenario.orchestration_context.resolved_artifacts | Where-Object {
        [string]$_.artifact_reference -ceq $Reference
      })
      if ($terminalArtifacts.Count -ne 1) { return $false }
      $terminalArtifact = $terminalArtifacts[0]
      if ($null -eq $terminalArtifact.PSObject.Properties['responsibility_handoff']) { return $false }
      $handoff = $terminalArtifact.responsibility_handoff
      $taskProvenance = if ($null -ne $terminalArtifact.PSObject.Properties['task_provenance']) {
        $terminalArtifact.task_provenance
      }
      else { $null }
      $expectedTaskUnit = if ([string]$Item.adapter_kind -ceq 'migration-unit') {
        [string]$Item.external_id
      }
      else { [string]$Item.work_item_id }
      $expectedTaskEvidence = if ($null -ne $taskProvenance) {
        "source-diff:$([string]$taskProvenance.task_base_sha)..$([string]$taskProvenance.final_tree_sha)#$([string]$Item.work_item_id)"
      }
      else { '' }
      $derivedArchitecture = if (
        [string]$handoff.tree_conformance -ceq 'PASS' -and
        [string]$handoff.responsibility_conformance -ceq 'PASS' -and
        [string]$handoff.verification_ownership -ceq 'PASS'
      ) { 'PASS' } else { 'BLOCKED' }
      $expectedSteps = if ([string]$Item.mode_constraint -ceq 'incremental/preserve-existing') {
        @('11-ai-review', '12-verification-testing', '13-verify-parity', '14-verify-regression', '15-knowledge-base')
      }
      elseif ([string]$Item.mode_constraint -ceq 'greenfield/design-new') {
        @('11-ai-review', '12-verification-testing', '13-verify-parity', '15-knowledge-base')
      }
      else { @() }
      $chainReferences = @($terminalArtifact.responsibility_chain_references)
      $terminalChainReference = if ($null -ne $terminalArtifact.PSObject.Properties['terminal_chain_reference']) { [string]$terminalArtifact.terminal_chain_reference } else { '' }
      if (
        [string]$terminalArtifact.artifact_reference -cne $Reference -or
        -not (& $isExactJsonTrue $terminalArtifact.immutable) -or
        [string]$terminalArtifact.artifact_type -cne 'migration-work-item-terminal' -or
        [string]$terminalArtifact.work_item_id -cne [string]$Item.work_item_id -or
        [int]$terminalArtifact.plan_revision -ne [int]$scenario.current_plan_revision -or
        [string]$terminalArtifact.result -cne 'complete' -or
        [string]$terminalArtifact.run_id -cne [string]$context.run_id -or
        [string]$terminalArtifact.master_spec_ref -cne [string]$context.master_spec_ref -or
        [string]$terminalArtifact.master_spec_id -cne [string]$context.master_spec_id -or
        [int]$terminalArtifact.master_spec_revision -ne [int]$context.latest_spec_revision -or
        [string]$terminalArtifact.master_plan_ref -cne [string]$context.master_plan_ref -or
        [string]$terminalArtifact.master_plan_id -cne [string]$context.master_plan_id -or
        [int]$terminalArtifact.master_plan_revision -ne [int]$context.current_plan_revision -or
        [string]$terminalArtifact.mode_constraint -cne [string]$Item.mode_constraint -or
        $null -eq $taskProvenance -or
        [string]::IsNullOrWhiteSpace($expectedTaskUnit) -or
        [string]$taskProvenance.task_unit -cne $expectedTaskUnit -or
        [string]$taskProvenance.task_base_sha -cnotmatch '^[0-9a-f]{40}$' -or
        [string]$taskProvenance.final_tree_sha -cnotmatch '^[0-9a-f]{40}$' -or
        [string]$taskProvenance.source_artifact_reference -cne 'implementation-report.md' -or
        [string]$taskProvenance.evidence_reference -cne $expectedTaskEvidence -or
        [int]$handoff.responsibility_contract_version -ne 1 -or
        [string]$handoff.tree_conformance -cne 'PASS' -or
        [string]$handoff.responsibility_conformance -cne 'PASS' -or
        [string]$handoff.verification_ownership -cne 'PASS' -or
        [string]$handoff.architecture_state -cne $derivedArchitecture -or
        $derivedArchitecture -cne 'PASS' -or
        $expectedSteps.Count -eq 0 -or
        $chainReferences.Count -ne $expectedSteps.Count -or
        @($chainReferences | Group-Object | Where-Object Count -ne 1).Count -gt 0 -or
        [string]$handoff.evidence_reference -cne $expectedTaskEvidence -or
        $terminalChainReference -cne [string]$chainReferences[-1] -or
        [string]$Item.tree_conformance -cne [string]$handoff.tree_conformance -or
        [string]$Item.responsibility_conformance -cne [string]$handoff.responsibility_conformance -or
        [string]$Item.verification_ownership -cne [string]$handoff.verification_ownership -or
        [string]$Item.architecture_state -cne [string]$handoff.architecture_state
      ) { return $false }

      $previousReference = ''
      $canonicalSourceDiff = ''
      for ($chainIndex = 0; $chainIndex -lt $chainReferences.Count; $chainIndex++) {
        $chainReference = [string]$chainReferences[$chainIndex]
        $chainArtifacts = @($scenario.orchestration_context.resolved_artifacts | Where-Object {
          [string]$_.artifact_reference -ceq $chainReference
        })
        if ($chainArtifacts.Count -ne 1) { return $false }
        $chainArtifact = $chainArtifacts[0]
        $chainArchitecture = if (
          [string]$chainArtifact.tree_conformance -ceq 'PASS' -and
          [string]$chainArtifact.responsibility_conformance -ceq 'PASS' -and
          [string]$chainArtifact.verification_ownership -ceq 'PASS'
        ) { 'PASS' } else { 'BLOCKED' }
        if (
          -not (& $isExactJsonTrue $chainArtifact.immutable) -or
          [string]$chainArtifact.artifact_type -cne 'migration-responsibility-handoff' -or
          [string]$chainArtifact.run_id -cne [string]$context.run_id -or
          [string]$chainArtifact.master_spec_ref -cne [string]$context.master_spec_ref -or
          [string]$chainArtifact.master_spec_id -cne [string]$context.master_spec_id -or
          [int]$chainArtifact.master_spec_revision -ne [int]$context.latest_spec_revision -or
          [string]$chainArtifact.master_plan_ref -cne [string]$context.master_plan_ref -or
          [string]$chainArtifact.master_plan_id -cne [string]$context.master_plan_id -or
          [int]$chainArtifact.master_plan_revision -ne [int]$context.current_plan_revision -or
          [string]$chainArtifact.work_item_id -cne [string]$Item.work_item_id -or
          [string]$chainArtifact.mode_constraint -cne [string]$Item.mode_constraint -or
          [string]$chainArtifact.step_id -cne [string]$expectedSteps[$chainIndex] -or
          [int]$chainArtifact.responsibility_contract_version -ne 1 -or
          $chainArchitecture -cne 'PASS' -or
          [string]$chainArtifact.architecture_state -cne $chainArchitecture -or
          [string]$chainArtifact.task_base_sha -cnotmatch '^[0-9a-f]{40}$' -or
          [string]$chainArtifact.final_tree_sha -cnotmatch '^[0-9a-f]{40}$' -or
          [string]$chainArtifact.evidence_reference -cne ("source-diff:$([string]$chainArtifact.task_base_sha)..$([string]$chainArtifact.final_tree_sha)#$([string]$Item.work_item_id)") -or
          [string]$chainArtifact.task_base_sha -cne [string]$taskProvenance.task_base_sha -or
          [string]$chainArtifact.final_tree_sha -cne [string]$taskProvenance.final_tree_sha -or
          [string]$chainArtifact.evidence_reference -cne [string]$taskProvenance.evidence_reference -or
          [string]$chainArtifact.status -cne 'approved' -or
          [string]$chainArtifact.result -cne 'complete' -or
          [string]$chainArtifact.approval_source -cne 'human' -or
          ($chainIndex -eq 0 -and [string]$chainArtifact.source_artifact_reference -cne [string]$taskProvenance.source_artifact_reference) -or
          ($chainIndex -gt 0 -and [string]$chainArtifact.source_artifact_reference -cne $previousReference) -or
          ($chainIndex -gt 0 -and [string]$chainArtifact.evidence_reference -cne $canonicalSourceDiff)
        ) { return $false }
        foreach ($field in @('tree_conformance', 'responsibility_conformance', 'verification_ownership', 'architecture_state')) {
          if ([string]$chainArtifact.$field -cne [string]$handoff.$field) { return $false }
        }
        if ($chainIndex -eq 0) { $canonicalSourceDiff = [string]$chainArtifact.evidence_reference }
        $previousReference = $chainReference
      }
      return $true
    }

    if ($scenario.operation -ceq 'select') {
      $items = @($scenario.work_items)
      $itemById = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
      foreach ($item in $items) {
        $itemId = [string]$item.work_item_id
        if ([string]::IsNullOrWhiteSpace($itemId) -or $itemById.ContainsKey($itemId)) {
          return [pscustomobject]@{ result = 'plan-invalid'; reason = 'duplicate-or-missing-work-item-id'; scope_status = 'scope-blocked' }
        }
        $itemById.Add($itemId, $item)
      }

      foreach ($item in $items) {
        foreach ($dependency in @($item.dependencies)) {
          $dependencyId = [string]$dependency
          if (
            -not [string]::IsNullOrWhiteSpace($dependencyId) -and
            $dependencyId -cne 'none' -and
            -not $itemById.ContainsKey($dependencyId)
          ) {
            return [pscustomobject]@{ result = 'plan-invalid'; reason = 'missing-dependency'; scope_status = 'scope-blocked' }
          }
        }
      }

      $depthById = [Collections.Generic.Dictionary[string, int]]::new([StringComparer]::Ordinal)
      $remainingIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
      foreach ($item in $items) { [void]$remainingIds.Add([string]$item.work_item_id) }
      $madeProgress = $true
      while ($remainingIds.Count -gt 0 -and $madeProgress) {
        $madeProgress = $false
        foreach ($item in $items) {
          $itemId = [string]$item.work_item_id
          if (-not $remainingIds.Contains($itemId)) { continue }
          $dependenciesReady = $true
          $maximumParentDepth = -1
          foreach ($dependency in @($item.dependencies)) {
            $dependencyId = [string]$dependency
            if ([string]::IsNullOrWhiteSpace($dependencyId) -or $dependencyId -ceq 'none') { continue }
            if (-not $depthById.ContainsKey($dependencyId)) {
              $dependenciesReady = $false
              break
            }
            if ($depthById[$dependencyId] -gt $maximumParentDepth) {
              $maximumParentDepth = $depthById[$dependencyId]
            }
          }
          if ($dependenciesReady) {
            $depthById.Add($itemId, $maximumParentDepth + 1)
            [void]$remainingIds.Remove($itemId)
            $madeProgress = $true
          }
        }
      }
      if ($remainingIds.Count -gt 0) {
        return [pscustomobject]@{ result = 'plan-invalid'; reason = 'dependency-cycle'; scope_status = 'scope-blocked' }
      }

      $attemptById = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
      $activeAttemptCount = 0
      $activeAttemptRecord = $null
      foreach ($item in $items) {
        foreach ($attempt in @($item.attempt_history)) {
          $attemptId = [string]$attempt.attempt_id
          if ([string]::IsNullOrWhiteSpace($attemptId) -or $attemptById.ContainsKey($attemptId)) {
            return [pscustomobject]@{ result = 'plan-invalid'; reason = 'duplicate-or-missing-attempt-id'; scope_status = 'scope-blocked' }
          }
          if ([string]$attempt.work_item_id -cne [string]$item.work_item_id) {
            return [pscustomobject]@{ result = 'plan-invalid'; reason = 'attempt-work-item-mismatch'; scope_status = 'scope-blocked' }
          }
          if (
            [int]$attempt.plan_revision -lt 1 -or
            @('in-progress', 'complete', 'blocked') -cnotcontains [string]$attempt.status -or
            [string]::IsNullOrWhiteSpace([string]$attempt.artifact_reference)
          ) {
            return [pscustomobject]@{ result = 'plan-invalid'; reason = 'attempt-record-invalid'; scope_status = 'scope-blocked' }
          }
          $resolvedAttemptArtifacts = @($scenario.orchestration_context.resolved_artifacts | Where-Object {
            [string]$_.artifact_reference -ceq [string]$attempt.artifact_reference
          })
          if (
            $resolvedAttemptArtifacts.Count -ne 1 -or
            -not (& $isExactJsonTrue $resolvedAttemptArtifacts[0].immutable) -or
            [string]$resolvedAttemptArtifacts[0].attempt_id -cne [string]$attempt.attempt_id -or
            [string]$resolvedAttemptArtifacts[0].work_item_id -cne [string]$attempt.work_item_id -or
            [int]$resolvedAttemptArtifacts[0].plan_revision -ne [int]$attempt.plan_revision -or
            [string]$resolvedAttemptArtifacts[0].status -cne [string]$attempt.status
          ) {
            return [pscustomobject]@{ result = 'plan-invalid'; reason = 'attempt-artifact-binding-invalid'; scope_status = 'scope-blocked' }
          }
          if ($attempt.status -ceq 'in-progress') {
            $activeAttemptCount++
            $activeAttemptRecord = $attempt
          }
          $attemptById.Add($attemptId, $attempt)
        }
        $latestAttemptId = [string]$item.latest_attempt
        if (-not [string]::IsNullOrWhiteSpace($latestAttemptId) -and $latestAttemptId -cne 'none') {
          if (-not $attemptById.ContainsKey($latestAttemptId)) {
            return [pscustomobject]@{ result = 'plan-invalid'; reason = 'latest-attempt-missing-from-history'; scope_status = 'scope-blocked' }
          }
          $latestAttemptRecord = $attemptById[$latestAttemptId]
          if ([string]$latestAttemptRecord.work_item_id -cne [string]$item.work_item_id) {
            return [pscustomobject]@{ result = 'plan-invalid'; reason = 'attempt-work-item-mismatch'; scope_status = 'scope-blocked' }
          }
          if ($item.status -ceq 'in-progress' -and [int]$latestAttemptRecord.plan_revision -ne [int]$scenario.current_plan_revision) {
            return [pscustomobject]@{ result = 'plan-invalid'; reason = 'attempt-plan-revision-mismatch'; scope_status = 'scope-blocked' }
          }
        }
      }
      if ($activeAttemptCount -gt 1) {
        return [pscustomobject]@{ result = 'plan-invalid'; reason = 'multiple-in-progress-attempts'; scope_status = 'scope-blocked' }
      }

      $inProgressItems = @($items | Where-Object { $_.status -ceq 'in-progress' })
      if ($inProgressItems.Count -gt 1) {
        return [pscustomobject]@{ result = 'plan-invalid'; reason = 'multiple-in-progress'; scope_status = 'scope-blocked' }
      }
      if ($activeAttemptCount -eq 1 -and $inProgressItems.Count -eq 0) {
        return [pscustomobject]@{ result = 'plan-invalid'; reason = 'attempt-item-state-mismatch'; scope_status = 'scope-blocked' }
      }
      if ($activeAttemptCount -eq 1 -and $inProgressItems.Count -eq 1) {
        if ([string]$activeAttemptRecord.work_item_id -cne [string]$inProgressItems[0].work_item_id) {
          return [pscustomobject]@{ result = 'plan-invalid'; reason = 'active-attempt-item-mismatch'; scope_status = 'scope-blocked' }
        }
        if ([string]$activeAttemptRecord.attempt_id -cne [string]$inProgressItems[0].latest_attempt) {
          return [pscustomobject]@{ result = 'plan-invalid'; reason = 'active-attempt-latest-mismatch'; scope_status = 'scope-blocked' }
        }
      }

      $planWideResponsibilityBlock = & $resolvePlanWideResponsibilityBlock $items
      if ($null -ne $planWideResponsibilityBlock) { return $planWideResponsibilityBlock }

      $dependencyIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
      foreach ($item in $items) {
        foreach ($dependency in @($item.dependencies)) {
          if (-not [string]::IsNullOrWhiteSpace([string]$dependency) -and [string]$dependency -cne 'none') {
            [void]$dependencyIds.Add([string]$dependency)
          }
        }
      }
      $reconciledWorkItemId = ''
      if ($inProgressItems.Count -eq 1) {
        $inProgressItem = $inProgressItems[0]
        $latestAttemptRecord = $attemptById[[string]$inProgressItem.latest_attempt]
        $hasValidTerminalEvidence =
          $null -ne $latestAttemptRecord -and
          @('complete', 'blocked') -ccontains [string]$latestAttemptRecord.status -and
          -not [string]::IsNullOrWhiteSpace([string]$inProgressItem.terminal_evidence) -and
          [string]$inProgressItem.terminal_evidence -cne 'none' -and
          [string]$latestAttemptRecord.artifact_reference -ceq [string]$inProgressItem.terminal_evidence
        if ($latestAttemptRecord.status -ceq 'complete' -and $hasValidTerminalEvidence) {
          $inProgressItem.status = 'complete'
          $reconciledWorkItemId = [string]$inProgressItem.work_item_id
        }
        elseif ($latestAttemptRecord.status -ceq 'blocked' -and $hasValidTerminalEvidence) {
          $inProgressItem.status = 'blocked'
          $reconciledWorkItemId = [string]$inProgressItem.work_item_id
        }
        else {
          return [pscustomobject]@{
            result = 'resume-attempt'
            reason = 'non-terminal-attempt'
            scope_status = 'scope-in-progress'
            work_item_id = [string]$inProgressItem.work_item_id
            adapter_kind = [string]$inProgressItem.adapter_kind
            migration_unit_id = if ($inProgressItem.adapter_kind -ceq 'migration-unit') { [string]$inProgressItem.external_id } else { 'not-applicable' }
            reconciled_work_item_id = ''
          }
        }
      }

      if (
        -not [string]::IsNullOrWhiteSpace($reconciledWorkItemId) -and
        [string]$inProgressItem.status -ceq 'complete' -and
        (
          [string]::IsNullOrWhiteSpace([string]$inProgressItem.terminal_evidence) -or
          [string]$inProgressItem.terminal_evidence -ceq 'none' -or
          -not (& $testTerminalResponsibilityAuthority $inProgressItem ([string]$inProgressItem.terminal_evidence))
        )
      ) {
        return [pscustomobject]@{
          result = 'scope-blocked'
          reason = 'terminal-responsibility-authority-invalid'
          scope_status = 'scope-blocked'
          work_item_id = ''
          reconciled_work_item_id = $reconciledWorkItemId
        }
      }

      foreach ($dependencyId in $dependencyIds) {
        $dependencyItem = $itemById[$dependencyId]
        if (
          [string]$dependencyItem.status -ceq 'complete' -and
          (
            [string]::IsNullOrWhiteSpace([string]$dependencyItem.terminal_evidence) -or
            [string]$dependencyItem.terminal_evidence -ceq 'none' -or
            -not (& $testTerminalResponsibilityAuthority $dependencyItem ([string]$dependencyItem.terminal_evidence))
          )
        ) {
          return [pscustomobject]@{
            result = 'scope-blocked'
            reason = 'terminal-responsibility-authority-invalid'
            scope_status = 'scope-blocked'
            work_item_id = ''
            reconciled_work_item_id = $reconciledWorkItemId
          }
        }
      }

      $terminalSuccessStates = @('complete', 'cancelled-approved', 'not-applicable-approved')
      $selectedItem = $null
      foreach ($item in $items) {
        $requiredOrApprovedOptional = [bool]$item.required -or [bool]$item.optional_execution_approved
        $selectableState = @('pending', 'ready') -ccontains [string]$item.status
        $dependenciesTerminal = $true
        foreach ($dependency in @($item.dependencies)) {
          $dependencyId = [string]$dependency
          if ([string]::IsNullOrWhiteSpace($dependencyId) -or $dependencyId -ceq 'none') { continue }
          if ($terminalSuccessStates -cnotcontains [string]$itemById[$dependencyId].status) {
            $dependenciesTerminal = $false
            break
          }
        }
        $approvalCurrent = [int]$item.approval_revision -eq [int]$scenario.current_plan_revision
        $noBlocker = -not [bool]$item.has_blocker
        $adapterValid = [bool]$item.adapter_valid
        $tree = [string]$item.tree_conformance
        $responsibility = [string]$item.responsibility_conformance
        $verification = [string]$item.verification_ownership
        $architectureState = [string]$item.architecture_state
        $architecturePass =
          $tree -ceq 'PASS' -and
          $responsibility -ceq 'PASS' -and
          $verification -ceq 'PASS' -and
          $architectureState -ceq 'PASS'
        $assurancePass = $architecturePass -and $item.selector_schema_state -ceq 'PASS'
        if (
          -not $requiredOrApprovedOptional -or
          -not $selectableState -or
          -not $dependenciesTerminal -or
          -not $approvalCurrent -or
          -not $noBlocker -or
          -not $adapterValid -or
          -not $assurancePass
        ) {
          continue
        }

        if ($null -eq $selectedItem) {
          $selectedItem = $item
          continue
        }
        $candidateDepth = $depthById[[string]$item.work_item_id]
        $selectedDepth = $depthById[[string]$selectedItem.work_item_id]
        $candidatePrecedes =
          $candidateDepth -lt $selectedDepth -or
          (
            $candidateDepth -eq $selectedDepth -and
            (
              [int]$item.plan_order -lt [int]$selectedItem.plan_order -or
              (
                [int]$item.plan_order -eq [int]$selectedItem.plan_order -and
                [StringComparer]::Ordinal.Compare([string]$item.work_item_id, [string]$selectedItem.work_item_id) -lt 0
              )
            )
          )
        if ($candidatePrecedes) { $selectedItem = $item }
      }

      if ($null -ne $selectedItem) {
        return [pscustomobject]@{
          result = 'selected'
          reason = 'eligible-by-depth-plan-order-id'
          scope_status = 'scope-in-progress'
          work_item_id = [string]$selectedItem.work_item_id
          adapter_kind = [string]$selectedItem.adapter_kind
          migration_unit_id = if ($selectedItem.adapter_kind -ceq 'migration-unit') { [string]$selectedItem.external_id } else { 'not-applicable' }
          reconciled_work_item_id = $reconciledWorkItemId
        }
      }

      $requiredNonTerminal = @($items | Where-Object {
        [bool]$_.required -and $terminalSuccessStates -cnotcontains [string]$_.status
      })
      if ($requiredNonTerminal.Count -gt 0) {
        $responsibilityBlocked = @($requiredNonTerminal | Where-Object {
          [string]$_.responsibility_conformance -cne 'PASS'
        })
        return [pscustomobject]@{
          result = 'scope-blocked'
          reason = if ($responsibilityBlocked.Count -gt 0) {
            $diagnostic = [string]$responsibilityBlocked[0].responsibility_diagnostic
            if ([string]::IsNullOrWhiteSpace($diagnostic) -or $diagnostic -ceq 'none') { 'structural-assurance-blocked' } else { $diagnostic }
          } else { 'required-work-remains-without-eligible-item' }
          scope_status = 'scope-blocked'
          work_item_id = ''
          reconciled_work_item_id = $reconciledWorkItemId
        }
      }
      return [pscustomobject]@{
        result = 'no-eligible-item'
        reason = 'master-plan-must-calculate-scope-completion'
        scope_status = 'scope-in-progress'
        work_item_id = ''
        reconciled_work_item_id = $reconciledWorkItemId
      }
    }

    if ($scenario.operation -ceq 'complete-scope') {
      $items = @($scenario.work_items)
      $terminalSuccessStates = @('complete', 'cancelled-approved', 'not-applicable-approved')
      $itemById = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
      foreach ($item in $items) {
        $itemId = [string]$item.work_item_id
        if ([string]::IsNullOrWhiteSpace($itemId) -or $itemById.ContainsKey($itemId)) {
          return [pscustomobject]@{ result = 'scope-not-complete'; reason = 'duplicate-or-missing-work-item-id'; scope_status = 'scope-blocked' }
        }
        $itemById.Add($itemId, $item)
      }
      foreach ($item in $items) {
        foreach ($dependency in @($item.dependencies)) {
          $dependencyId = [string]$dependency
          if (
            -not [string]::IsNullOrWhiteSpace($dependencyId) -and
            $dependencyId -cne 'none' -and
            -not $itemById.ContainsKey($dependencyId)
          ) {
            return [pscustomobject]@{ result = 'scope-not-complete'; reason = 'missing-dependency'; scope_status = 'scope-blocked' }
          }
        }
      }
      $resolvedGraphIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
      $madeProgress = $true
      while ($resolvedGraphIds.Count -lt $items.Count -and $madeProgress) {
        $madeProgress = $false
        foreach ($item in $items) {
          $itemId = [string]$item.work_item_id
          if ($resolvedGraphIds.Contains($itemId)) { continue }
          $dependenciesResolved = $true
          foreach ($dependency in @($item.dependencies)) {
            $dependencyId = [string]$dependency
            if ([string]::IsNullOrWhiteSpace($dependencyId) -or $dependencyId -ceq 'none') { continue }
            if (-not $resolvedGraphIds.Contains($dependencyId)) {
              $dependenciesResolved = $false
              break
            }
          }
          if ($dependenciesResolved) {
            [void]$resolvedGraphIds.Add($itemId)
            $madeProgress = $true
          }
        }
      }
      if ($resolvedGraphIds.Count -ne $items.Count) {
        return [pscustomobject]@{ result = 'scope-not-complete'; reason = 'dependency-cycle'; scope_status = 'scope-blocked' }
      }
      $remainingBlockers = @($items | Where-Object { $_.status -ceq 'blocked' -or [bool]$_.has_blocker })
      if ($remainingBlockers.Count -gt 0) {
        return [pscustomobject]@{ result = 'scope-not-complete'; reason = 'blocker-remains'; scope_status = 'scope-blocked' }
      }
      $requiredNonTerminal = @($items | Where-Object {
        [bool]$_.required -and $terminalSuccessStates -cnotcontains [string]$_.status
      })
      if ($requiredNonTerminal.Count -gt 0) {
        return [pscustomobject]@{ result = 'scope-not-complete'; reason = 'required-work-remains'; scope_status = 'scope-in-progress' }
      }
      $terminalReportRef = [string]$scenario.terminal_scope_report_ref
      $terminalReports = @($scenario.orchestration_context.resolved_artifacts | Where-Object {
        [string]$_.artifact_reference -ceq $terminalReportRef
      })
      if (
        @('', 'pending', 'none', 'not-applicable') -ccontains $terminalReportRef -or
        $terminalReports.Count -ne 1 -or
        $terminalReports[0].artifact_type -cne 'migration-scope-terminal-report' -or
        -not (& $isExactJsonTrue $terminalReports[0].immutable) -or
        [string]$terminalReports[0].master_plan_ref -cne [string]$scenario.orchestration_context.master_plan_ref -or
        [int]$terminalReports[0].master_plan_revision -ne [int]$scenario.current_plan_revision
      ) {
        return [pscustomobject]@{ result = 'scope-not-complete'; reason = 'terminal-scope-report-resolution-invalid'; scope_status = 'scope-blocked' }
      }
      $terminalReport = $terminalReports[0]
      $reportRows = @($terminalReport.items)
      $planReportIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
      foreach ($item in $items) { [void]$planReportIds.Add([string]$item.work_item_id) }
      $reportedIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
      $reportIdSetValid = $reportRows.Count -eq $items.Count
      foreach ($reportRow in $reportRows) {
        $reportItemId = [string]$reportRow.work_item_id
        if (
          [string]::IsNullOrWhiteSpace($reportItemId) -or
          -not $reportedIds.Add($reportItemId) -or
          -not $planReportIds.Contains($reportItemId)
        ) {
          $reportIdSetValid = $false
        }
      }
      foreach ($planItemId in $planReportIds) {
        if (-not $reportedIds.Contains($planItemId)) { $reportIdSetValid = $false }
      }
      if (-not $reportIdSetValid) {
        return [pscustomobject]@{ result = 'scope-not-complete'; reason = 'terminal-scope-report-id-set-mismatch'; scope_status = 'scope-blocked' }
      }

      $resolvedHandoffEvidenceReferences = [Collections.Generic.List[string]]::new()
      $resolvedTerminalChainReferences = [Collections.Generic.List[string]]::new()
      foreach ($item in $items) {
        if ($terminalSuccessStates -cnotcontains [string]$item.status) { continue }
        $tree = [string]$item.tree_conformance
        $responsibility = [string]$item.responsibility_conformance
        $verification = [string]$item.verification_ownership
        $architectureState = [string]$item.architecture_state
        $architecturePass =
          $tree -ceq 'PASS' -and
          $responsibility -ceq 'PASS' -and
          $verification -ceq 'PASS' -and
          $architectureState -ceq 'PASS'
        if (
          [string]::IsNullOrWhiteSpace([string]$item.terminal_evidence) -or
          [string]$item.terminal_evidence -ceq 'none' -or
          -not $architecturePass -or
          $item.selector_schema_state -cne 'PASS'
        ) {
          $diagnostic = [string]$item.responsibility_diagnostic
          $reason = if ($responsibility -cne 'PASS' -and -not [string]::IsNullOrWhiteSpace($diagnostic) -and $diagnostic -cne 'none') { $diagnostic } else { 'structural-assurance-blocked' }
          return [pscustomobject]@{ result = 'scope-not-complete'; reason = $reason; scope_status = 'scope-blocked' }
        }

        $terminalArtifacts = @($scenario.orchestration_context.resolved_artifacts | Where-Object {
          [string]$_.artifact_reference -ceq [string]$item.terminal_evidence
        })
        if (
          $terminalArtifacts.Count -ne 1 -or
          -not (& $isExactJsonTrue $terminalArtifacts[0].immutable) -or
          [string]$terminalArtifacts[0].artifact_type -cne 'migration-work-item-terminal' -or
          [string]$terminalArtifacts[0].work_item_id -cne [string]$item.work_item_id -or
          [int]$terminalArtifacts[0].plan_revision -ne [int]$scenario.current_plan_revision -or
          [string]$terminalArtifacts[0].status -cne [string]$item.status -or
          [string]$terminalArtifacts[0].run_id -cne [string]$scenario.orchestration_context.run_id -or
          [string]$terminalArtifacts[0].master_spec_ref -cne [string]$scenario.orchestration_context.master_spec_ref -or
          [string]$terminalArtifacts[0].master_spec_id -cne [string]$scenario.orchestration_context.master_spec_id -or
          [int]$terminalArtifacts[0].master_spec_revision -ne [int]$scenario.orchestration_context.latest_spec_revision -or
          [string]$terminalArtifacts[0].master_plan_ref -cne [string]$scenario.orchestration_context.master_plan_ref -or
          [string]$terminalArtifacts[0].master_plan_id -cne [string]$scenario.orchestration_context.master_plan_id -or
          [int]$terminalArtifacts[0].master_plan_revision -ne [int]$scenario.current_plan_revision -or
          [string]$terminalArtifacts[0].mode_constraint -cne [string]$item.mode_constraint
        ) {
          return [pscustomobject]@{ result = 'scope-not-complete'; reason = 'structural-assurance-blocked'; scope_status = 'scope-blocked' }
        }
        if (-not (& $testTerminalResponsibilityAuthority $item ([string]$item.terminal_evidence))) {
          return [pscustomobject]@{ result = 'scope-not-complete'; reason = 'structural-assurance-blocked'; scope_status = 'scope-blocked' }
        }

        $terminalArtifact = $terminalArtifacts[0]
        $handoff = $terminalArtifact.responsibility_handoff
        $taskProvenance = if ($null -ne $terminalArtifact.PSObject.Properties['task_provenance']) {
          $terminalArtifact.task_provenance
        }
        else { $null }
        $expectedTaskUnit = if ([string]$item.adapter_kind -ceq 'migration-unit') {
          [string]$item.external_id
        }
        else { [string]$item.work_item_id }
        $expectedTaskEvidence = if ($null -ne $taskProvenance) {
          "source-diff:$([string]$taskProvenance.task_base_sha)..$([string]$taskProvenance.final_tree_sha)#$([string]$item.work_item_id)"
        }
        else { '' }
        $derivedArchitecture = if (
          [string]$handoff.tree_conformance -ceq 'PASS' -and
          [string]$handoff.responsibility_conformance -ceq 'PASS' -and
          [string]$handoff.verification_ownership -ceq 'PASS'
        ) { 'PASS' } else { 'BLOCKED' }
        $modeConstraint = [string]$item.mode_constraint
        $expectedResponsibilitySteps = if ($modeConstraint -ceq 'incremental/preserve-existing') {
          @('11-ai-review', '12-verification-testing', '13-verify-parity', '14-verify-regression', '15-knowledge-base')
        }
        elseif ($modeConstraint -ceq 'greenfield/design-new') {
          @('11-ai-review', '12-verification-testing', '13-verify-parity', '15-knowledge-base')
        }
        else { @() }
        $responsibilityChainReferences = @($terminalArtifact.responsibility_chain_references)
        $terminalChainReference = if ($null -ne $terminalArtifact.PSObject.Properties['terminal_chain_reference']) { [string]$terminalArtifact.terminal_chain_reference } else { '' }
        if (
          $null -eq $handoff -or
          [int]$handoff.responsibility_contract_version -ne 1 -or
          [string]$handoff.tree_conformance -cne 'PASS' -or
          [string]$handoff.responsibility_conformance -cne 'PASS' -or
          [string]$handoff.verification_ownership -cne 'PASS' -or
          [string]$handoff.architecture_state -cne $derivedArchitecture -or
          $derivedArchitecture -cne 'PASS' -or
          $null -eq $taskProvenance -or
          [string]::IsNullOrWhiteSpace($expectedTaskUnit) -or
          [string]$taskProvenance.task_unit -cne $expectedTaskUnit -or
          [string]$taskProvenance.task_base_sha -cnotmatch '^[0-9a-f]{40}$' -or
          [string]$taskProvenance.final_tree_sha -cnotmatch '^[0-9a-f]{40}$' -or
          [string]$taskProvenance.source_artifact_reference -cne 'implementation-report.md' -or
          [string]$taskProvenance.evidence_reference -cne $expectedTaskEvidence -or
          $expectedResponsibilitySteps.Count -eq 0 -or
          $responsibilityChainReferences.Count -ne $expectedResponsibilitySteps.Count -or
          @($responsibilityChainReferences | Group-Object | Where-Object Count -ne 1).Count -gt 0 -or
          [string]$handoff.evidence_reference -cne $expectedTaskEvidence -or
          $terminalChainReference -cne [string]$responsibilityChainReferences[-1] -or
          $tree -cne [string]$handoff.tree_conformance -or
          $responsibility -cne [string]$handoff.responsibility_conformance -or
          $verification -cne [string]$handoff.verification_ownership -or
          $architectureState -cne [string]$handoff.architecture_state
        ) {
          $diagnostic = [string]$item.responsibility_diagnostic
          $reason = if ([string]$handoff.responsibility_conformance -cne 'PASS' -and -not [string]::IsNullOrWhiteSpace($diagnostic) -and $diagnostic -cne 'none') { $diagnostic } else { 'structural-assurance-blocked' }
          return [pscustomobject]@{ result = 'scope-not-complete'; reason = $reason; scope_status = 'scope-blocked' }
        }

        $previousResponsibilityReference = ''
        $canonicalSourceDiff = ''
        $finalResponsibilityArtifact = $null
        for ($chainIndex = 0; $chainIndex -lt $responsibilityChainReferences.Count; $chainIndex++) {
          $chainReference = [string]$responsibilityChainReferences[$chainIndex]
          $chainArtifacts = @($scenario.orchestration_context.resolved_artifacts | Where-Object {
            [string]$_.artifact_reference -ceq $chainReference
          })
          if ($chainArtifacts.Count -ne 1) {
            return [pscustomobject]@{ result = 'scope-not-complete'; reason = 'structural-assurance-blocked'; scope_status = 'scope-blocked' }
          }
          $chainArtifact = $chainArtifacts[0]
          $chainArchitecture = if (
            [string]$chainArtifact.tree_conformance -ceq 'PASS' -and
            [string]$chainArtifact.responsibility_conformance -ceq 'PASS' -and
            [string]$chainArtifact.verification_ownership -ceq 'PASS'
          ) { 'PASS' } else { 'BLOCKED' }
          if (
            -not (& $isExactJsonTrue $chainArtifact.immutable) -or
            [string]$chainArtifact.artifact_type -cne 'migration-responsibility-handoff' -or
            [string]$chainArtifact.run_id -cne [string]$scenario.orchestration_context.run_id -or
            [string]$chainArtifact.master_spec_ref -cne [string]$scenario.orchestration_context.master_spec_ref -or
            [string]$chainArtifact.master_spec_id -cne [string]$scenario.orchestration_context.master_spec_id -or
            [int]$chainArtifact.master_spec_revision -ne [int]$scenario.orchestration_context.latest_spec_revision -or
            [string]$chainArtifact.master_plan_ref -cne [string]$scenario.orchestration_context.master_plan_ref -or
            [string]$chainArtifact.master_plan_id -cne [string]$scenario.orchestration_context.master_plan_id -or
            [int]$chainArtifact.master_plan_revision -ne [int]$scenario.current_plan_revision -or
            [string]$chainArtifact.work_item_id -cne [string]$item.work_item_id -or
            [string]$chainArtifact.mode_constraint -cne $modeConstraint -or
            [string]$chainArtifact.step_id -cne [string]$expectedResponsibilitySteps[$chainIndex] -or
            [int]$chainArtifact.responsibility_contract_version -ne 1 -or
            $chainArchitecture -cne 'PASS' -or
            [string]$chainArtifact.architecture_state -cne $chainArchitecture -or
            [string]::IsNullOrWhiteSpace([string]$chainArtifact.evidence_reference) -or
            [string]$chainArtifact.evidence_reference -ceq 'none' -or
            [string]$chainArtifact.task_base_sha -cnotmatch '^[0-9a-f]{40}$' -or
            [string]$chainArtifact.final_tree_sha -cnotmatch '^[0-9a-f]{40}$' -or
            [string]$chainArtifact.evidence_reference -cne ("source-diff:$([string]$chainArtifact.task_base_sha)..$([string]$chainArtifact.final_tree_sha)#$([string]$item.work_item_id)") -or
            [string]$chainArtifact.task_base_sha -cne [string]$taskProvenance.task_base_sha -or
            [string]$chainArtifact.final_tree_sha -cne [string]$taskProvenance.final_tree_sha -or
            [string]$chainArtifact.evidence_reference -cne [string]$taskProvenance.evidence_reference -or
            (
              [string]$chainArtifact.status -cne 'approved' -or
              [string]$chainArtifact.result -cne 'complete' -or
              [string]$chainArtifact.approval_source -cne 'human'
            ) -or
            ($chainIndex -eq 0 -and [string]$chainArtifact.source_artifact_reference -cne [string]$taskProvenance.source_artifact_reference) -or
            ($chainIndex -gt 0 -and [string]$chainArtifact.source_artifact_reference -cne $previousResponsibilityReference) -or
            ($chainIndex -gt 0 -and [string]$chainArtifact.evidence_reference -cne $canonicalSourceDiff)
          ) {
            return [pscustomobject]@{ result = 'scope-not-complete'; reason = 'structural-assurance-blocked'; scope_status = 'scope-blocked' }
          }
          foreach ($field in @('tree_conformance', 'responsibility_conformance', 'verification_ownership', 'architecture_state')) {
            if ([string]$chainArtifact.$field -cne [string]$handoff.$field) {
              return [pscustomobject]@{ result = 'scope-not-complete'; reason = 'structural-assurance-blocked'; scope_status = 'scope-blocked' }
            }
          }
          if ($chainIndex -eq 0) { $canonicalSourceDiff = [string]$chainArtifact.evidence_reference }
          $previousResponsibilityReference = $chainReference
          $finalResponsibilityArtifact = $chainArtifact
        }
        if ($null -eq $finalResponsibilityArtifact) {
          return [pscustomobject]@{ result = 'scope-not-complete'; reason = 'structural-assurance-blocked'; scope_status = 'scope-blocked' }
        }
        $resolvedHandoffEvidenceReferences.Add([string]$handoff.evidence_reference)
        $resolvedTerminalChainReferences.Add($terminalChainReference)
      }
      $reportHandoff = $terminalReport.responsibility_handoff
      $reportArchitecture = if (
        [string]$reportHandoff.tree_conformance -ceq 'PASS' -and
        [string]$reportHandoff.responsibility_conformance -ceq 'PASS' -and
        [string]$reportHandoff.verification_ownership -ceq 'PASS'
      ) { 'PASS' } else { 'BLOCKED' }
      $reportedTerminalReferences = @($reportHandoff.evidence_references)
      if (
        $null -eq $reportHandoff -or
        [int]$reportHandoff.responsibility_contract_version -ne 1 -or
        [string]$reportHandoff.tree_conformance -cne 'PASS' -or
        [string]$reportHandoff.responsibility_conformance -cne 'PASS' -or
        [string]$reportHandoff.verification_ownership -cne 'PASS' -or
        [string]$reportHandoff.architecture_state -cne $reportArchitecture -or
        $reportArchitecture -cne 'PASS' -or
        ($reportedTerminalReferences -join '|') -cne ($resolvedHandoffEvidenceReferences.ToArray() -join '|') -or
        [string]$terminalReport.run_id -cne [string]$scenario.orchestration_context.run_id -or
        [string]$terminalReport.master_spec_ref -cne [string]$scenario.orchestration_context.master_spec_ref -or
        [string]$terminalReport.master_spec_id -cne [string]$scenario.orchestration_context.master_spec_id -or
        [int]$terminalReport.master_spec_revision -ne [int]$scenario.orchestration_context.latest_spec_revision -or
        [string]$terminalReport.master_plan_id -cne [string]$scenario.orchestration_context.master_plan_id
      ) {
        return [pscustomobject]@{ result = 'scope-not-complete'; reason = 'structural-assurance-blocked'; scope_status = 'scope-blocked' }
      }
      if ($null -ne $terminalReport.PSObject.Properties['evidence_index']) {
        $evidenceIndexRows = @($terminalReport.evidence_index)
      }
      else { $evidenceIndexRows = @() }
      $terminalSuccessIds = @($items | Where-Object { $terminalSuccessStates -ccontains [string]$_.status } | ForEach-Object { [string]$_.work_item_id })
      $indexedWorkItemIds = @($evidenceIndexRows | ForEach-Object { [string]$_.work_item_id })
      if (
        $evidenceIndexRows.Count -ne $terminalSuccessIds.Count -or
        ($indexedWorkItemIds -join '|') -cne ($terminalSuccessIds -join '|') -or
        @($evidenceIndexRows | Group-Object evidence_id | Where-Object Count -ne 1).Count -gt 0
      ) {
        return [pscustomobject]@{ result = 'scope-not-complete'; reason = 'structural-assurance-blocked'; scope_status = 'scope-blocked' }
      }
      for ($evidenceIndex = 0; $evidenceIndex -lt $evidenceIndexRows.Count; $evidenceIndex++) {
        if (
          [string]::IsNullOrWhiteSpace([string]$evidenceIndexRows[$evidenceIndex].evidence_id) -or
          [string]$evidenceIndexRows[$evidenceIndex].artifact_reference -cne [string]$resolvedTerminalChainReferences[$evidenceIndex] -or
          [string]$evidenceIndexRows[$evidenceIndex].purpose -cne 'architecture-responsibility-sub-verdicts'
        ) {
          return [pscustomobject]@{ result = 'scope-not-complete'; reason = 'structural-assurance-blocked'; scope_status = 'scope-blocked' }
        }
      }
      foreach ($item in $items) {
        $matchingRows = @($reportRows | Where-Object { $_.work_item_id -ceq [string]$item.work_item_id })
        if (
          $matchingRows.Count -ne 1 -or
          (
            $terminalSuccessStates -ccontains [string]$item.status -and
            (
              [string]::IsNullOrWhiteSpace([string]$item.terminal_evidence) -or
              [string]$item.terminal_evidence -ceq 'none'
            )
          )
        ) {
          return [pscustomobject]@{ result = 'scope-not-complete'; reason = 'terminal-scope-report-incomplete'; scope_status = 'scope-blocked' }
        }
        $reportRow = $matchingRows[0]
        if (
          [string]$reportRow.status -cne [string]$item.status -or
          [string]$reportRow.terminal_evidence -cne [string]$item.terminal_evidence -or
          [string]$reportRow.architecture_state -cne [string]$item.architecture_state -or
          [string]$reportRow.selector_schema_state -cne [string]$item.selector_schema_state
        ) {
          return [pscustomobject]@{ result = 'scope-not-complete'; reason = 'terminal-scope-report-incomplete'; scope_status = 'scope-blocked' }
        }
      }
      return [pscustomobject]@{ result = 'scope-completed'; reason = 'master-plan-completion-calculation'; scope_status = 'scope-complete' }
    }

    if ($scenario.operation -ceq 'transition') {
      $items = @($scenario.work_items)
      $selected = @($items | Where-Object { $_.work_item_id -ceq [string]$scenario.work_item_id })
      if ($selected.Count -ne 1) {
        return [pscustomobject]@{ result = 'transition-invalid'; reason = 'work-item-not-unique' }
      }
      $item = $selected[0]
      if (-not (& $testPlannedResponsibilityAuthority $item)) {
        return [pscustomobject]@{ result = 'transition-invalid'; reason = 'planned-responsibility-authority-invalid'; scope_status = 'scope-blocked' }
      }
      $attemptById = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
      $activeAttemptCount = 0
      foreach ($historyItem in $items) {
        foreach ($attempt in @($historyItem.attempt_history)) {
          $historyAttemptId = [string]$attempt.attempt_id
          if ([string]::IsNullOrWhiteSpace($historyAttemptId) -or $attemptById.ContainsKey($historyAttemptId)) {
            return [pscustomobject]@{ result = 'transition-invalid'; reason = 'duplicate-or-missing-attempt-id' }
          }
          if (
            [string]$attempt.work_item_id -cne [string]$historyItem.work_item_id -or
            [int]$attempt.plan_revision -lt 1 -or
            @('in-progress', 'complete', 'blocked') -cnotcontains [string]$attempt.status -or
            [string]::IsNullOrWhiteSpace([string]$attempt.artifact_reference)
          ) {
            return [pscustomobject]@{ result = 'transition-invalid'; reason = 'attempt-record-invalid' }
          }
          $resolvedAttemptArtifacts = @($scenario.orchestration_context.resolved_artifacts | Where-Object {
            [string]$_.artifact_reference -ceq [string]$attempt.artifact_reference
          })
          if (
            $resolvedAttemptArtifacts.Count -ne 1 -or
            -not (& $isExactJsonTrue $resolvedAttemptArtifacts[0].immutable) -or
            [string]$resolvedAttemptArtifacts[0].attempt_id -cne [string]$attempt.attempt_id -or
            [string]$resolvedAttemptArtifacts[0].work_item_id -cne [string]$attempt.work_item_id -or
            [int]$resolvedAttemptArtifacts[0].plan_revision -ne [int]$attempt.plan_revision -or
            [string]$resolvedAttemptArtifacts[0].status -cne [string]$attempt.status
          ) {
            return [pscustomobject]@{ result = 'transition-invalid'; reason = 'attempt-artifact-binding-invalid' }
          }
          if ($attempt.status -ceq 'in-progress') { $activeAttemptCount++ }
          $attemptById.Add($historyAttemptId, $attempt)
        }
      }
      if ($activeAttemptCount -gt 1) {
        return [pscustomobject]@{ result = 'transition-invalid'; reason = 'multiple-in-progress-attempts' }
      }
      if (@('start-attempt', 'successful-terminal-artifact') -ccontains [string]$scenario.transition) {
        $planWideResponsibilityBlock = & $resolvePlanWideResponsibilityBlock $items
        if ($null -ne $planWideResponsibilityBlock) { return $planWideResponsibilityBlock }
      }
      if ($scenario.transition -ceq 'start-attempt') {
        if (
          @('pending', 'ready') -cnotcontains [string]$item.status -or
          [string]::IsNullOrWhiteSpace([string]$scenario.attempt_id)
        ) {
          return [pscustomobject]@{ result = 'transition-invalid'; reason = 'attempt-start-precondition' }
        }
        if ($attemptById.ContainsKey([string]$scenario.attempt_id)) {
          return [pscustomobject]@{ result = 'transition-invalid'; reason = 'attempt-id-already-exists' }
        }
        if ($activeAttemptCount -gt 0) {
          return [pscustomobject]@{ result = 'transition-invalid'; reason = 'another-attempt-in-progress' }
        }
        $otherInProgress = @($items | Where-Object {
          $_.work_item_id -cne [string]$scenario.work_item_id -and $_.status -ceq 'in-progress'
        })
        if ($otherInProgress.Count -gt 0) {
          return [pscustomobject]@{ result = 'transition-invalid'; reason = 'another-attempt-in-progress' }
        }
        $readinessTransition = if ($item.status -ceq 'pending') { 'pending-to-ready' } else { 'already-ready' }
        return [pscustomobject]@{
          result = 'transitioned'
          reason = 'ready-to-in-progress'
          readiness_transition = $readinessTransition
          attempt_id = [string]$scenario.attempt_id
          plan_revision = [int]$scenario.current_plan_revision
          attempt_status = 'in-progress'
          work_item_status = 'in-progress'
          scope_status = 'scope-in-progress'
          terminal_evidence = 'none'
        }
      }
      if ($scenario.transition -ceq 'successful-terminal-artifact') {
        $attemptRecord = if ($attemptById.ContainsKey([string]$scenario.attempt_id)) { $attemptById[[string]$scenario.attempt_id] } else { $null }
        if (
          $item.status -cne 'in-progress' -or
          [string]$item.latest_attempt -cne [string]$scenario.attempt_id -or
          $null -eq $attemptRecord -or
          [string]$attemptRecord.work_item_id -cne [string]$item.work_item_id -or
          [int]$attemptRecord.plan_revision -ne [int]$scenario.current_plan_revision -or
          [string]$attemptRecord.status -cne 'in-progress' -or
          [string]::IsNullOrWhiteSpace([string]$scenario.terminal_evidence) -or
          [string]$scenario.terminal_evidence -ceq 'none'
        ) {
          return [pscustomobject]@{ result = 'transition-invalid'; reason = 'successful-transition-precondition' }
        }
        $terminalArtifacts = @($scenario.orchestration_context.resolved_artifacts | Where-Object {
          [string]$_.artifact_reference -ceq [string]$scenario.terminal_evidence
        })
        $terminalArtifact = if ($terminalArtifacts.Count -eq 1) { $terminalArtifacts[0] } else { $null }
        if (
          $null -eq $terminalArtifact -or
          [string]$terminalArtifact.artifact_reference -cne [string]$scenario.terminal_evidence -or
          [string]$terminalArtifact.attempt_id -cne [string]$scenario.attempt_id -or
          [string]$terminalArtifact.work_item_id -cne [string]$item.work_item_id -or
          [int]$terminalArtifact.plan_revision -ne [int]$scenario.current_plan_revision -or
          [string]$terminalArtifact.status -cne 'complete' -or
          [string]$terminalArtifact.result -cne 'complete' -or
          -not (& $isExactJsonTrue $terminalArtifact.immutable)
        ) {
          return [pscustomobject]@{ result = 'transition-invalid'; reason = 'terminal-artifact-binding-invalid' }
        }
        if (-not (& $testTerminalResponsibilityAuthority $item ([string]$scenario.terminal_evidence))) {
          return [pscustomobject]@{ result = 'transition-invalid'; reason = 'terminal-responsibility-authority-invalid'; scope_status = 'scope-blocked' }
        }
        return [pscustomobject]@{
          result = 'transitioned'
          reason = 'valid-successful-terminal-artifact'
          attempt_id = [string]$scenario.attempt_id
          plan_revision = [int]$scenario.current_plan_revision
          attempt_status = 'complete'
          work_item_status = 'complete'
          scope_status = 'scope-in-progress'
          terminal_evidence = [string]$scenario.terminal_evidence
        }
      }
      if (
        $scenario.transition -ceq 'native-blocker' -and
        $item.status -ceq 'in-progress' -and
        (
          [string]::IsNullOrWhiteSpace([string]$scenario.terminal_evidence) -or
          [string]$scenario.terminal_evidence -ceq 'none'
        )
      ) {
        return [pscustomobject]@{ result = 'transition-invalid'; reason = 'blocker-evidence-missing' }
      }
      if ($scenario.transition -ceq 'native-blocker' -and $item.status -ceq 'in-progress') {
        if ([string]$item.latest_attempt -cne [string]$scenario.attempt_id) {
          return [pscustomobject]@{ result = 'transition-invalid'; reason = 'attempt-not-latest' }
        }
        $attemptRecord = if ($attemptById.ContainsKey([string]$scenario.attempt_id)) { $attemptById[[string]$scenario.attempt_id] } else { $null }
        $blockerArtifacts = @($scenario.orchestration_context.resolved_artifacts | Where-Object {
          [string]$_.artifact_reference -ceq [string]$scenario.terminal_evidence
        })
        $blockerArtifact = if ($blockerArtifacts.Count -eq 1) { $blockerArtifacts[0] } else { $null }
        if (
          $null -eq $attemptRecord -or
          [string]$attemptRecord.work_item_id -cne [string]$item.work_item_id -or
          [int]$attemptRecord.plan_revision -ne [int]$scenario.current_plan_revision -or
          [string]$attemptRecord.status -cne 'in-progress' -or
          $null -eq $blockerArtifact -or
          [string]$blockerArtifact.artifact_reference -cne [string]$scenario.terminal_evidence -or
          [string]$blockerArtifact.attempt_id -cne [string]$scenario.attempt_id -or
          [string]$blockerArtifact.work_item_id -cne [string]$item.work_item_id -or
          [int]$blockerArtifact.plan_revision -ne [int]$scenario.current_plan_revision -or
          [string]$blockerArtifact.result -cne 'blocked' -or
          -not (& $isExactJsonTrue $blockerArtifact.immutable)
        ) {
          return [pscustomobject]@{ result = 'transition-invalid'; reason = 'blocker-artifact-binding-invalid' }
        }
        return [pscustomobject]@{
          result = 'transitioned'
          reason = 'native-blocker'
          attempt_id = [string]$scenario.attempt_id
          plan_revision = [int]$scenario.current_plan_revision
          attempt_status = 'blocked'
          work_item_status = 'blocked'
          scope_status = 'scope-blocked'
          terminal_evidence = [string]$scenario.terminal_evidence
        }
      }
      if (
        $scenario.transition -ceq 'approved-cancellation' -and
        @('pending', 'ready', 'blocked') -ccontains [string]$item.status
      ) {
        if (
          [string]::IsNullOrWhiteSpace([string]$scenario.approval_reference) -or
          [string]$scenario.approval_reference -ceq 'pending' -or
          [string]::IsNullOrWhiteSpace([string]$scenario.terminal_evidence) -or
          [string]$scenario.terminal_evidence -ceq 'none'
        ) {
          return [pscustomobject]@{ result = 'transition-invalid'; reason = 'approval-evidence-missing' }
        }
        $decisionArtifacts = @($scenario.orchestration_context.resolved_artifacts | Where-Object {
          [string]$_.artifact_reference -ceq [string]$scenario.terminal_evidence
        })
        $decisionArtifact = if ($decisionArtifacts.Count -eq 1) { $decisionArtifacts[0] } else { $null }
        if (
          $null -eq $decisionArtifact -or
          [string]$decisionArtifact.artifact_reference -cne [string]$scenario.terminal_evidence -or
          [string]$decisionArtifact.work_item_id -cne [string]$item.work_item_id -or
          [int]$decisionArtifact.plan_revision -ne [int]$scenario.current_plan_revision -or
          [string]$decisionArtifact.decision -cne 'cancelled-approved' -or
          [string]$decisionArtifact.approval_reference -cne [string]$scenario.approval_reference -or
          -not (& $isExactJsonTrue $decisionArtifact.immutable)
        ) {
          return [pscustomobject]@{ result = 'transition-invalid'; reason = 'decision-artifact-binding-invalid' }
        }
        return [pscustomobject]@{ result = 'transitioned'; reason = 'approved-cancellation'; attempt_status = 'not-applicable'; work_item_status = 'cancelled-approved'; scope_status = 'scope-in-progress'; terminal_evidence = [string]$scenario.terminal_evidence }
      }
      if (
        $scenario.transition -ceq 'approved-non-applicability' -and
        @('pending', 'ready') -ccontains [string]$item.status
      ) {
        if (
          [string]::IsNullOrWhiteSpace([string]$scenario.approval_reference) -or
          [string]$scenario.approval_reference -ceq 'pending' -or
          [string]::IsNullOrWhiteSpace([string]$scenario.terminal_evidence) -or
          [string]$scenario.terminal_evidence -ceq 'none'
        ) {
          return [pscustomobject]@{ result = 'transition-invalid'; reason = 'approval-evidence-missing' }
        }
        $decisionArtifacts = @($scenario.orchestration_context.resolved_artifacts | Where-Object {
          [string]$_.artifact_reference -ceq [string]$scenario.terminal_evidence
        })
        $decisionArtifact = if ($decisionArtifacts.Count -eq 1) { $decisionArtifacts[0] } else { $null }
        if (
          $null -eq $decisionArtifact -or
          [string]$decisionArtifact.artifact_reference -cne [string]$scenario.terminal_evidence -or
          [string]$decisionArtifact.work_item_id -cne [string]$item.work_item_id -or
          [int]$decisionArtifact.plan_revision -ne [int]$scenario.current_plan_revision -or
          [string]$decisionArtifact.decision -cne 'not-applicable-approved' -or
          [string]$decisionArtifact.approval_reference -cne [string]$scenario.approval_reference -or
          -not (& $isExactJsonTrue $decisionArtifact.immutable)
        ) {
          return [pscustomobject]@{ result = 'transition-invalid'; reason = 'decision-artifact-binding-invalid' }
        }
        return [pscustomobject]@{ result = 'transitioned'; reason = 'approved-non-applicability'; attempt_status = 'not-applicable'; work_item_status = 'not-applicable-approved'; scope_status = 'scope-in-progress'; terminal_evidence = [string]$scenario.terminal_evidence }
      }
      return [pscustomobject]@{ result = 'transition-invalid'; reason = 'transition-not-allowed' }
    }

    if ($scenario.operation -ceq 'revise') {
      $current = $scenario.current
      $proposed = $scenario.proposed
      if ([int]$proposed.revision -ne ([int]$current.revision + 1)) {
        return [pscustomobject]@{ result = 'revision-invalid'; reason = 'revision-must-increment-by-one'; unaffected_evidence_preserved = $false; affected_approval_invalidated = $false }
      }
      if ([string]$proposed.artifact_id -cne [string]$current.artifact_id) {
        return [pscustomobject]@{ result = 'revision-invalid'; reason = 'stable-master-id-changed'; unaffected_evidence_preserved = $false; affected_approval_invalidated = $false }
      }
      $expectedSupersedes = "$([string]$current.artifact_id)@$([int]$current.revision)"
      if ([string]$proposed.supersedes -cne $expectedSupersedes) {
        return [pscustomobject]@{ result = 'revision-invalid'; reason = 'supersedes-not-immediate-predecessor'; unaffected_evidence_preserved = $false; affected_approval_invalidated = $false }
      }
      if ([string]::IsNullOrWhiteSpace([string]$proposed.change_summary)) {
        return [pscustomobject]@{ result = 'revision-invalid'; reason = 'change-summary-missing'; unaffected_evidence_preserved = $false; affected_approval_invalidated = $false }
      }

      $currentIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
      foreach ($item in @($current.work_items)) {
        $itemId = [string]$item.work_item_id
        if ([string]::IsNullOrWhiteSpace($itemId) -or -not $currentIds.Add($itemId)) {
          return [pscustomobject]@{ result = 'revision-invalid'; reason = 'duplicate-current-work-item-id'; unaffected_evidence_preserved = $false; affected_approval_invalidated = $false }
        }
      }
      $proposedIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
      foreach ($item in @($proposed.work_items)) {
        $itemId = [string]$item.work_item_id
        if ([string]::IsNullOrWhiteSpace($itemId) -or -not $proposedIds.Add($itemId)) {
          return [pscustomobject]@{ result = 'revision-invalid'; reason = 'duplicate-proposed-work-item-id'; unaffected_evidence_preserved = $false; affected_approval_invalidated = $false }
        }
      }

      $currentMasterShape = [ordered]@{
        requested_scope = $current.requested_scope
        requirements = @($current.requirements)
        success_criteria = @($current.success_criteria)
        required_disposition = @($current.required_disposition)
        structural_decisions = @($current.structural_decisions)
      } | ConvertTo-Json -Depth 20 -Compress
      $proposedMasterShape = [ordered]@{
        requested_scope = $proposed.requested_scope
        requirements = @($proposed.requirements)
        success_criteria = @($proposed.success_criteria)
        required_disposition = @($proposed.required_disposition)
        structural_decisions = @($proposed.structural_decisions)
      } | ConvertTo-Json -Depth 20 -Compress
      $masterShapeChanged = $currentMasterShape -cne $proposedMasterShape
      if ($masterShapeChanged -and @($proposed.affected_work_items).Count -eq 0) {
        return [pscustomobject]@{ result = 'revision-invalid'; reason = 'master-structural-change-requires-affected-items'; unaffected_evidence_preserved = $false; affected_approval_invalidated = $false }
      }

      $affectedIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
      foreach ($affectedId in @($proposed.affected_work_items)) { [void]$affectedIds.Add([string]$affectedId) }
      $canonicalIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
      foreach ($currentId in $currentIds) { [void]$canonicalIds.Add($currentId) }
      foreach ($proposedId in $proposedIds) { [void]$canonicalIds.Add($proposedId) }
      foreach ($affectedId in $affectedIds) {
        if (-not $canonicalIds.Contains($affectedId)) {
          return [pscustomobject]@{ result = 'revision-invalid'; reason = 'affected-work-item-not-canonical'; unaffected_evidence_preserved = $false; affected_approval_invalidated = $false }
        }
      }
      if ($masterShapeChanged) {
        foreach ($canonicalId in $canonicalIds) {
          if (-not $affectedIds.Contains($canonicalId)) {
            return [pscustomobject]@{ result = 'revision-invalid'; reason = 'master-change-affected-coverage-incomplete'; unaffected_evidence_preserved = $false; affected_approval_invalidated = $false }
          }
        }
      }
      $currentById = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
      foreach ($item in @($current.work_items)) { $currentById[[string]$item.work_item_id] = $item }
      $proposedById = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
      foreach ($item in @($proposed.work_items)) { $proposedById[[string]$item.work_item_id] = $item }
      $unaffectedEvidencePreserved = $true
      $affectedApprovalInvalidated = $true
      foreach ($currentItem in @($current.work_items)) {
        $currentItemId = [string]$currentItem.work_item_id
        if (-not $proposedById.ContainsKey($currentItemId)) {
          if (-not $affectedIds.Contains($currentItemId)) {
            return [pscustomobject]@{ result = 'revision-invalid'; reason = 'changed-item-not-declared-affected'; unaffected_evidence_preserved = $false; affected_approval_invalidated = $false }
          }
          continue
        }
        $proposedItem = $proposedById[$currentItemId]
        $currentShape = [ordered]@{
          title = [string]$currentItem.title
          required = [bool]$currentItem.required
          dependencies = @($currentItem.dependencies)
          plan_order = [int]$currentItem.plan_order
          acceptance = @($currentItem.acceptance)
          trace_ids = @($currentItem.trace_ids)
          delivery_adapter = $currentItem.delivery_adapter
        } | ConvertTo-Json -Depth 12 -Compress
        $proposedShape = [ordered]@{
          title = [string]$proposedItem.title
          required = [bool]$proposedItem.required
          dependencies = @($proposedItem.dependencies)
          plan_order = [int]$proposedItem.plan_order
          acceptance = @($proposedItem.acceptance)
          trace_ids = @($proposedItem.trace_ids)
          delivery_adapter = $proposedItem.delivery_adapter
        } | ConvertTo-Json -Depth 12 -Compress
        if ($currentShape -cne $proposedShape -and -not $affectedIds.Contains($currentItemId)) {
          return [pscustomobject]@{ result = 'revision-invalid'; reason = 'changed-item-not-declared-affected'; unaffected_evidence_preserved = $false; affected_approval_invalidated = $false }
        }
        if ($affectedIds.Contains($currentItemId)) {
          if ([string]$proposedItem.approval_reference -cne 'pending') { $affectedApprovalInvalidated = $false }
        }
        elseif (
          $currentItem.status -ceq 'complete' -and
          (
            $proposedItem.status -cne 'complete' -or
            [string]$proposedItem.terminal_evidence -cne [string]$currentItem.terminal_evidence -or
            [string]$proposedItem.approval_reference -cne [string]$currentItem.approval_reference
          )
        ) {
          $unaffectedEvidencePreserved = $false
        }
      }
      foreach ($proposedItem in @($proposed.work_items)) {
        $proposedItemId = [string]$proposedItem.work_item_id
        if (-not $currentById.ContainsKey($proposedItemId) -and -not $affectedIds.Contains($proposedItemId)) {
          return [pscustomobject]@{ result = 'revision-invalid'; reason = 'changed-item-not-declared-affected'; unaffected_evidence_preserved = $false; affected_approval_invalidated = $false }
        }
        if ($affectedIds.Contains($proposedItemId) -and [string]$proposedItem.approval_reference -cne 'pending') {
          $affectedApprovalInvalidated = $false
        }
      }
      if (-not $unaffectedEvidencePreserved) {
        return [pscustomobject]@{ result = 'revision-invalid'; reason = 'unaffected-completed-evidence-changed'; unaffected_evidence_preserved = $false; affected_approval_invalidated = $affectedApprovalInvalidated }
      }
      if (-not $affectedApprovalInvalidated) {
        return [pscustomobject]@{ result = 'revision-invalid'; reason = 'affected-approval-not-invalidated'; unaffected_evidence_preserved = $true; affected_approval_invalidated = $false }
      }
      return [pscustomobject]@{ result = 'revision-valid'; reason = 'new-immutable-linear-revision'; unaffected_evidence_preserved = $true; affected_approval_invalidated = $true }
    }

    if ($scenario.operation -ceq 'validate-resume') {
      $specRevisions = @($scenario.spec_revisions | Where-Object { $_.status -ceq 'approved' })
      if ($specRevisions.Count -eq 0) {
        return [pscustomobject]@{ result = 'resume-blocked'; reason = 'approved-master-spec-revision-missing' }
      }
      $specByNumber = [Collections.Generic.Dictionary[int, object]]::new()
      $specChildCountByReference = [Collections.Generic.Dictionary[string, int]]::new([StringComparer]::Ordinal)
      foreach ($specRevision in $specRevisions) {
        $specRevisionNumber = [int]$specRevision.revision
        if ($specByNumber.ContainsKey($specRevisionNumber)) {
          return [pscustomobject]@{ result = 'resume-blocked'; reason = 'forked-master-spec-chain' }
        }
        $specByNumber.Add($specRevisionNumber, $specRevision)
        $specParentReference = [string]$specRevision.supersedes
        if ($specParentReference -cne 'not-applicable') {
          if (-not $specChildCountByReference.ContainsKey($specParentReference)) { $specChildCountByReference.Add($specParentReference, 0) }
          $specChildCountByReference[$specParentReference] = $specChildCountByReference[$specParentReference] + 1
          if ($specChildCountByReference[$specParentReference] -gt 1) {
            return [pscustomobject]@{ result = 'resume-blocked'; reason = 'forked-master-spec-chain' }
          }
        }
      }
      $orderedSpecRevisions = @($specRevisions | Sort-Object -Property @{ Expression = { [int]$_.revision }; Ascending = $true })
      for ($specIndex = 0; $specIndex -lt $orderedSpecRevisions.Count; $specIndex++) {
        $specRevision = $orderedSpecRevisions[$specIndex]
        if ([string]$specRevision.artifact_id -cne [string]$scenario.master_spec_id) {
          return [pscustomobject]@{ result = 'resume-blocked'; reason = 'master-spec-id-mismatch' }
        }
        if ([bool]$specRevision.stale) {
          return [pscustomobject]@{ result = 'resume-blocked'; reason = 'stale-master-spec-chain' }
        }
        if ($specIndex -eq 0) {
          if ([string]$specRevision.supersedes -cne 'not-applicable') {
            return [pscustomobject]@{ result = 'resume-blocked'; reason = 'cyclic-or-missing-master-spec-chain' }
          }
          continue
        }
        $previousSpec = $orderedSpecRevisions[$specIndex - 1]
        $expectedSpecParent = "$([string]$previousSpec.artifact_id)@$([int]$previousSpec.revision)"
        if (
          [int]$specRevision.revision -ne ([int]$previousSpec.revision + 1) -or
          [string]$specRevision.supersedes -cne $expectedSpecParent
        ) {
          return [pscustomobject]@{ result = 'resume-blocked'; reason = 'cyclic-or-missing-master-spec-chain' }
        }
      }
      $latestSpec = $orderedSpecRevisions[$orderedSpecRevisions.Count - 1]
      if ([int]$latestSpec.revision -ne [int]$scenario.latest_spec_revision) {
        return [pscustomobject]@{ result = 'resume-blocked'; reason = 'latest-master-spec-revision-mismatch' }
      }

      $resumePlanRevisions = @($scenario.revisions)
      $revisions = @($resumePlanRevisions | Where-Object { $_.status -ceq 'approved' })
      if ($revisions.Count -eq 0) {
        return [pscustomobject]@{ result = 'resume-blocked'; reason = 'approved-revision-missing' }
      }
      $revisionByNumber = [Collections.Generic.Dictionary[int, object]]::new()
      $childCountByReference = [Collections.Generic.Dictionary[string, int]]::new([StringComparer]::Ordinal)
      foreach ($revision in $revisions) {
        $revisionNumber = [int]$revision.revision
        if ($revisionByNumber.ContainsKey($revisionNumber)) {
          return [pscustomobject]@{ result = 'resume-blocked'; reason = 'forked-revision-chain' }
        }
        $revisionByNumber.Add($revisionNumber, $revision)
        $parentReference = [string]$revision.supersedes
        if ($parentReference -cne 'not-applicable') {
          if (-not $childCountByReference.ContainsKey($parentReference)) { $childCountByReference.Add($parentReference, 0) }
          $childCountByReference[$parentReference] = $childCountByReference[$parentReference] + 1
          if ($childCountByReference[$parentReference] -gt 1) {
            return [pscustomobject]@{ result = 'resume-blocked'; reason = 'forked-revision-chain' }
          }
        }
      }
      $orderedRevisions = @($revisions | Sort-Object -Property @{ Expression = { [int]$_.revision }; Ascending = $true })
      $stablePlanId = [string]$orderedRevisions[0].artifact_id
      for ($index = 0; $index -lt $orderedRevisions.Count; $index++) {
        $revision = $orderedRevisions[$index]
        if ([string]$revision.artifact_id -cne $stablePlanId) {
          return [pscustomobject]@{ result = 'resume-blocked'; reason = 'master-plan-id-changed' }
        }
        if ([bool]$revision.stale) {
          return [pscustomobject]@{ result = 'resume-blocked'; reason = 'stale-revision-chain' }
        }
        if ($index -eq 0) {
          if ([string]$revision.supersedes -cne 'not-applicable') {
            return [pscustomobject]@{ result = 'resume-blocked'; reason = 'cyclic-or-missing-revision-chain' }
          }
          continue
        }
        $previous = $orderedRevisions[$index - 1]
        $expectedParent = "$([string]$previous.artifact_id)@$([int]$previous.revision)"
        if (
          [int]$revision.revision -ne ([int]$previous.revision + 1) -or
          [string]$revision.supersedes -cne $expectedParent
        ) {
          return [pscustomobject]@{ result = 'resume-blocked'; reason = 'cyclic-or-missing-revision-chain' }
        }
      }
      $latest = $orderedRevisions[$orderedRevisions.Count - 1]
      if ([int]$latest.master_spec_revision -ne [int]$scenario.latest_spec_revision) {
        return [pscustomobject]@{ result = 'resume-blocked'; reason = 'master-spec-revision-mismatch' }
      }
      $latestPlanIndex = -1
      for ($resumePlanIndex = 0; $resumePlanIndex -lt $resumePlanRevisions.Count; $resumePlanIndex++) {
        if ([object]::ReferenceEquals($resumePlanRevisions[$resumePlanIndex], $latest)) {
          $latestPlanIndex = $resumePlanIndex
          break
        }
      }
      $resumeRawPlanContractStates = @($rawPlanContractStates.Resume)
      if (
        $resumeRawPlanContractStates.Count -ne $resumePlanRevisions.Count -or
        $latestPlanIndex -lt 0 -or
        $latestPlanIndex -ge $resumeRawPlanContractStates.Count -or
        -not [bool]$resumeRawPlanContractStates[$latestPlanIndex]
      ) {
        return [pscustomobject]@{ result = 'resume-blocked'; reason = 'responsibility-contract-version-invalid' }
      }
      return [pscustomobject]@{ result = 'resume-ready'; reason = 'latest-approved-linear-revision'; latest_plan_revision = [int]$latest.revision }
    }

    return [pscustomobject]@{ result = 'scenario-invalid'; reason = 'unsupported-operation' }
  }

  @(
    '## Deterministic selection order',
    'Selection order: dependency depth ascending -> Plan Order ascending -> ordinal Work Item ID ascending.',
    'Terminal-success states: `complete | cancelled-approved | not-applicable-approved`.',
    'Resume reconciliation applies a missing terminal transition from valid evidence before selecting another work item.',
    'Approved revisions are immutable and form one linear, non-forked, non-cyclic chain.'
  ) | ForEach-Object {
    Require-Token $ContractText $_ 'Migration scope engine contract'
  }

  $orchestratorPath = Join-Path $Root 'skills/aitoolkit/migrate/SKILL.md'
  if (-not (Test-Path -LiteralPath $orchestratorPath -PathType Leaf)) {
    $errors.Add('Missing migration orchestrator for scope-engine validation')
    return
  }
  $orchestratorText = Get-Content -Raw -Encoding utf8 $orchestratorPath
  $scopePlaneTokens = @(
    'Resolve requested scope',
    'Create/resolve master spec',
    'Create/resolve master plan',
    'Validate approved revision chain',
    'Select/resume one work item',
    'Resolve optional adapter',
    'Run execution pipeline',
    'Apply atomic transition',
    'Continue queue without repeated soft-scope prompt'
  )
  $previousTokenIndex = -1
  foreach ($token in $scopePlaneTokens) {
    $tokenIndex = $orchestratorText.IndexOf($token, [StringComparison]::Ordinal)
    if ($tokenIndex -lt 0) {
      $errors.Add("Migration orchestrator scope-plane ordering missing: $token")
    }
    elseif ($tokenIndex -le $previousTokenIndex) {
      $errors.Add("Migration orchestrator scope-plane ordering invalid at: $token")
    }
    $previousTokenIndex = $tokenIndex
  }
  @(
    'unresolved` asks exactly one scope question and blocks before step 01',
    'do not scan directories to infer requested scope or revision state',
    'exactly one latest approved linear revision',
    'do not edit an approved master artifact in place',
    'required-or-approved-optional AND pending-or-ready AND dependencies-terminal-success AND current approval AND no blocker AND adapter-valid AND assurance-pass',
    'dependency depth ascending, then `Plan Order` ascending, then ordinal `Work Item ID` ascending',
    'adapter `none` keeps `migration_unit_id: not-applicable`',
    'reconcile an `in-progress` attempt before selecting a new work item',
    'Step 15 completes only the current execution attempt and work item',
    'Only the approved master plan may conclude `scope-complete`',
    'Executable operations validate requested scope, then current approved master spec, then current approved linked master plan before queue or transition logic.',
    'Selection starts atomically as `pending -> ready -> in-progress` or `ready -> in-progress`.',
    'Validate immutable `attempt_history` globally by unique attempt ID, exact `work_item_id`, exact current `plan_revision`, status and artifact reference.',
    'Blocker, cancellation and non-applicability transitions require exact immutable terminal or approval evidence.',
    'Every work-item structural change must be declared in `affected_work_items`, including added or removed items, and every affected item in the new revision has `approval_reference: pending`.',
    'Scope completion calculates the dependency graph and validates every required terminal-report row; it never trusts caller-provided graph-valid or report-complete booleans.',
    '`unresolved` emits exactly one question block with a stable ID and concrete prompt.',
    'Executable input requires explicit `master_spec_ref` and `master_plan_ref` that resolve exact immutable current artifact type, ID and revision; blank, `pending`, `none` and `not-applicable` references or evidence are invalid.',
    'Queue operations consume exactly the work-item rows bound to the current approved master-plan artifact, never a caller subset or forged queue.',
    'Attempt and terminal artifacts resolve from the explicit artifact registry by exact reference and bind immutable status, attempt ID, work-item ID and plan revision.',
    'Single-in-progress validation counts both work-item states and every immutable attempt record; native blocker transition targets exactly `latest_attempt`.',
    'Terminal scope report resolves from the artifact registry, binds the current master-plan reference/revision and enumerates the exact approved plan rows.',
    'Revision comparison includes requested boundary, requirements, success criteria, required disposition and structural decisions, and rejects duplicate current or proposed work-item IDs before map construction.',
    'Terminal scope report Work Item IDs have bidirectional exact set and cardinality equality with current approved plan rows; duplicate, missing or extra IDs block.',
    'Every affected_work_items ID resolves in the current/proposed canonical union; unmappable master-level change conservatively affects every canonical item.',
    "The sole active attempt must belong to the sole in-progress item and equal that item's latest_attempt before resume reconciliation.",
    'exactly one bounded `responsibility_contract` block with `version: 1` and `applicability: required`'
  ) | ForEach-Object {
    Require-Token $orchestratorText $_ 'Migration orchestrator scope engine policy'
  }
}

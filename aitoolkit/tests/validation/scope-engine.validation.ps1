function Test-ScopeEngine([string]$Root, [string]$ContractText) {
  $contractPath = Join-Path $Root 'contracts/migration-scope-orchestration.md'
  if (-not (Test-Path -LiteralPath $contractPath -PathType Leaf)) {
    $errors.Add('Missing migration scope orchestration contract resource')
    return
  }

  $candidateText = if ($null -eq $ContractText) { '' } else { $ContractText.TrimStart() }
  if ($candidateText.StartsWith('{', [StringComparison]::Ordinal)) {
    try {
      $scenario = $ContractText | ConvertFrom-Json
    }
    catch {
      return [pscustomobject]@{ result = 'scenario-invalid'; reason = 'invalid-json' }
    }
    if ($scenario.scenario_type -cne 'scope-engine') {
      return [pscustomobject]@{ result = 'scenario-invalid'; reason = 'invalid-scenario-type' }
    }

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
        -not [bool]$currentSpecs[0].immutable
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

      $currentPlans = @($context.plan_revisions | Where-Object {
        [string]$_.artifact_reference -ceq [string]$context.master_plan_ref -and
        [string]$_.artifact_id -ceq [string]$context.master_plan_id -and
        [int]$_.revision -eq [int]$context.current_plan_revision
      })
      if (
        $currentPlans.Count -ne 1 -or
        $currentPlans[0].artifact_type -cne 'migration-master-plan' -or
        -not [bool]$currentPlans[0].immutable
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
            -not [bool]$resolvedAttemptArtifacts[0].immutable -or
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
        $assurancePass =
          $item.architecture_state -ceq 'PASS' -and
          $item.selector_schema_state -ceq 'PASS'
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
        return [pscustomobject]@{
          result = 'scope-blocked'
          reason = 'required-work-remains-without-eligible-item'
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
      foreach ($item in $items) {
        if ($item.status -cne 'complete') { continue }
        if (
          [string]::IsNullOrWhiteSpace([string]$item.terminal_evidence) -or
          [string]$item.terminal_evidence -ceq 'none' -or
          $item.architecture_state -cne 'PASS' -or
          $item.selector_schema_state -cne 'PASS'
        ) {
          return [pscustomobject]@{ result = 'scope-not-complete'; reason = 'completed-item-evidence-or-assurance-invalid'; scope_status = 'scope-blocked' }
        }
      }
      $terminalReportRef = [string]$scenario.terminal_scope_report_ref
      $terminalReports = @($scenario.orchestration_context.resolved_artifacts | Where-Object {
        [string]$_.artifact_reference -ceq $terminalReportRef
      })
      if (
        @('', 'pending', 'none', 'not-applicable') -ccontains $terminalReportRef -or
        $terminalReports.Count -ne 1 -or
        $terminalReports[0].artifact_type -cne 'migration-scope-terminal-report' -or
        -not [bool]$terminalReports[0].immutable -or
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
            -not [bool]$resolvedAttemptArtifacts[0].immutable -or
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
          [string]$terminalArtifact.result -cne 'complete' -or
          -not [bool]$terminalArtifact.immutable
        ) {
          return [pscustomobject]@{ result = 'transition-invalid'; reason = 'terminal-artifact-binding-invalid' }
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
          -not [bool]$blockerArtifact.immutable
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
          -not [bool]$decisionArtifact.immutable
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
          -not [bool]$decisionArtifact.immutable
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

      $revisions = @($scenario.revisions | Where-Object { $_.status -ceq 'approved' })
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
    "The sole active attempt must belong to the sole in-progress item and equal that item's latest_attempt before resume reconciliation."
  ) | ForEach-Object {
    Require-Token $orchestratorText $_ 'Migration orchestrator scope engine policy'
  }
}

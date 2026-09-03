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
    $resolvedArtifacts = [Collections.Generic.List[object]]::new()
    foreach ($item in @($Fixture.work_items)) {
      foreach ($attempt in @($item.attempt_history)) {
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
    if ($Fixture.ContainsKey('terminal_scope_report')) {
      $Fixture.terminal_scope_report_ref = [string]$Fixture.terminal_scope_report.artifact_reference
      $resolvedArtifacts.Add($Fixture.terminal_scope_report)
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
      @{ artifact_reference = 'runs/master-plan@3.md'; artifact_type = 'migration-master-plan'; artifact_id = 'PLAN-ADMIN-001'; revision = 3; supersedes = 'PLAN-ADMIN-001@2'; immutable = $true; status = 'approved'; result = 'complete'; approval_reference = 'approval:plan@3'; freshness_evidence = 'review:plan@3'; master_spec_ref = 'runs/master-spec@2.md'; master_spec_id = 'SPEC-ADMIN-001'; master_spec_revision = 2; stale = $false; work_items = @() }
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
    architecture_state = 'PASS'
    selector_schema_state = 'PASS'
    terminal_evidence = 'none'
    latest_attempt = 'none'
    attempt_history = @()
  }
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
  @{ Name = 'adapter-valid'; Apply = { param($item) $item.adapter_kind = 'task'; $item.adapter_valid = $false } },
  @{ Name = 'architecture-pass'; Apply = { param($item) $item.architecture_state = 'BLOCKED' } },
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
$afterReconcile = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'
  operation = 'select'
  current_plan_revision = 3
  work_items = @($runningWithEvidence, $waiting)
}
Assert-Equal $afterReconcile.result 'selected' 'Valid terminal evidence must be reconciled before selecting again'
Assert-Equal $afterReconcile.reconciled_work_item_id 'WORK-ADMIN-RUNNING' 'Resume must expose the reconciled item'
Assert-Equal $afterReconcile.work_item_id 'WORK-ADMIN-WAITING' 'Resume must select the next deterministic item after reconciliation'

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
$allComplete = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'
  operation = 'complete-scope'
  work_items = @($completeItem, $cancelled, $notApplicable)
  terminal_scope_report = @{
    artifact_reference = 'runs/scope-terminal.md'
    artifact_type = 'migration-scope-terminal-report'
    master_plan_ref = 'runs/master-plan@3.md'
    master_plan_revision = 3
    immutable = $true
    items = @(
      @{ work_item_id = 'WORK-ADMIN-COMPLETE'; status = 'complete'; terminal_evidence = 'runs/complete.md'; architecture_state = 'PASS'; selector_schema_state = 'PASS' },
      @{ work_item_id = 'WORK-ADMIN-CANCELLED'; status = 'cancelled-approved'; terminal_evidence = 'decisions/cancelled.md'; architecture_state = 'PASS'; selector_schema_state = 'PASS' },
      @{ work_item_id = 'WORK-ADMIN-NA'; status = 'not-applicable-approved'; terminal_evidence = 'decisions/not-applicable.md'; architecture_state = 'PASS'; selector_schema_state = 'PASS' }
    )
  }
}
Assert-Equal $allComplete.scope_status 'scope-complete' 'All required terminal-success items with scope evidence must complete the scope'

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
$transition = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'
  operation = 'transition'
  current_plan_revision = 3
  transition = 'successful-terminal-artifact'
  work_item_id = 'WORK-ADMIN-CURRENT'
  attempt_id = 'ATTEMPT-WORK-ADMIN-CURRENT-01'
  terminal_evidence = 'runs/current-01.md'
  terminal_evidence_valid = $true
  terminal_artifact = @{
    artifact_reference = 'runs/current-01.md'
    attempt_id = 'ATTEMPT-WORK-ADMIN-CURRENT-01'
    work_item_id = 'WORK-ADMIN-CURRENT'
    plan_revision = 3
    result = 'complete'
    immutable = $true
  }
  work_items = @($transitionCurrent, $transitionNext)
}
Assert-Equal $transition.result 'transitioned' 'Valid terminal evidence must atomically finish the attempt and item'
Assert-Equal $transition.attempt_status 'complete' 'Attempt completion must be explicit'
Assert-Equal $transition.work_item_status 'complete' 'Work-item completion must be explicit'
Assert-Equal $transition.scope_status 'scope-in-progress' 'Attempt completion must not imply requested-scope completion'
Assert-Equal $transition.terminal_evidence 'runs/current-01.md' 'Atomic transition must preserve immutable terminal evidence reference'

$mismatchedTerminalArtifact = Invoke-ScopeScenario @{
  scenario_type = 'scope-engine'
  operation = 'transition'
  current_plan_revision = 3
  transition = 'successful-terminal-artifact'
  work_item_id = 'WORK-ADMIN-CURRENT'
  attempt_id = 'ATTEMPT-WORK-ADMIN-CURRENT-01'
  terminal_evidence = 'runs/current-01.md'
  terminal_evidence_valid = $true
  terminal_artifact = @{
    artifact_reference = 'runs/current-01.md'
    attempt_id = 'ATTEMPT-WORK-ADMIN-OTHER-01'
    work_item_id = 'WORK-ADMIN-CURRENT'
    plan_revision = 3
    result = 'complete'
    immutable = $true
  }
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

if ($failures.Count -gt 0) {
  $failures | ForEach-Object { Write-Output "FAIL: $_" }
  exit 1
}

Write-Output 'PASS: scope engine behavioral scenarios'
exit 0

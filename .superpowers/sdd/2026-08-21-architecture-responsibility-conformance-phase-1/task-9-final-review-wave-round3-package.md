# Review package: ed6e436f9d7a7cf24981bf0a06178329a70b94f0..bb0ee9612943bc2d9836c2ad66b762f56535fe1c

## Commits
bb0ee96 test: cover responsibility conformance workflow

## Files changed
 .../tests/scenarios/scope-engine.Tests.ps1         | 76 ++++++++++++++++++++++
 .../tests/validation/scope-engine.validation.ps1   | 18 +++++
 2 files changed, 94 insertions(+)

## Diff
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/scope-engine.Tests.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/scope-engine.Tests.ps1
index 90750e8..ee37835 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/scope-engine.Tests.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/scope-engine.Tests.ps1
@@ -278,20 +278,53 @@ function New-TerminalResponsibilityArtifact(
       responsibility_contract_version = 1
       tree_conformance = 'PASS'
       responsibility_conformance = 'PASS'
       verification_ownership = 'PASS'
       architecture_state = 'PASS'
       evidence_reference = $EvidenceReference
     }
   }
 }
 
+function Invoke-NoDependentReconciliationCase(
+  [string]$Suffix,
+  [bool]$IncludeTerminalAuthority = $true,
+  [scriptblock]$MutateAuthority = $null
+) {
+  $reconciledItem = New-WorkItem "WORK-ADMIN-RECONCILE-$Suffix" 1 @() 'in-progress'
+  $reconciledItem.latest_attempt = "ATTEMPT-WORK-ADMIN-RECONCILE-$Suffix-01"
+  $reconciledItem.attempt_status = 'complete'
+  $reconciledItem.terminal_evidence = "runs/reconcile-$($Suffix.ToLowerInvariant())-terminal.md"
+  $reconciledItem.attempt_history = @(
+    @{ attempt_id = $reconciledItem.latest_attempt; work_item_id = $reconciledItem.work_item_id; plan_revision = 3; status = 'complete'; artifact_reference = $reconciledItem.terminal_evidence }
+  )
+  $unrelatedItem = New-WorkItem "WORK-ADMIN-UNRELATED-$Suffix" 2
+  $fixture = @{
+    scenario_type = 'scope-engine'; operation = 'select'; current_plan_revision = 3
+    work_items = @($reconciledItem, $unrelatedItem)
+  }
+  if ($IncludeTerminalAuthority) {
+    $chain = New-ResponsibilityChain "runs/reconcile-$($Suffix.ToLowerInvariant())-chain" $reconciledItem.work_item_id $reconciledItem.mode_constraint
+    $terminal = New-TerminalResponsibilityArtifact $reconciledItem.terminal_evidence $reconciledItem.work_item_id 'complete' $chain.FinalReference $chain.References $chain.ModeConstraint
+    $terminal.attempt_id = $reconciledItem.latest_attempt
+    $terminal.result = 'complete'
+    if ($null -ne $MutateAuthority) { & $MutateAuthority $terminal $chain }
+    $fixture.terminal_artifacts = @($terminal)
+    $fixture.responsibility_chain_artifacts = @($chain.Artifacts)
+  }
+  return [pscustomobject]@{
+    Result = Invoke-ScopeScenario $fixture
+    ReconciledItem = $reconciledItem
+    UnrelatedItem = $unrelatedItem
+  }
+}
+
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
@@ -724,20 +757,63 @@ $reconciledWithoutAuthority.attempt_history = @(
 )
 $dependentAfterReconcile = New-WorkItem 'WORK-ADMIN-DEPENDENT-AFTER-RECONCILE' 2 @($reconciledWithoutAuthority.work_item_id)
 $untrustedReconcile = Invoke-ScopeScenario @{
   scenario_type = 'scope-engine'; operation = 'select'; current_plan_revision = 3
   work_items = @($reconciledWithoutAuthority, $dependentAfterReconcile)
 }
 Assert-Equal $untrustedReconcile.result 'scope-blocked' 'Reconciliation must not unlock a dependent without canonical terminal responsibility authority'
 Assert-Equal $untrustedReconcile.reason 'terminal-responsibility-authority-invalid' 'Missing reconciled terminal chain must fail the dependency authority gate'
 Assert-Equal $untrustedReconcile.work_item_id '' 'A reconciled dependency without terminal authority must leave its dependent unselected'
 
+$canonicalNoDependent = Invoke-NoDependentReconciliationCase 'CANONICAL'
+Assert-Equal $canonicalNoDependent.Result.result 'selected' 'A reconciled item with canonical terminal authority may permit unrelated selection'
+Assert-Equal $canonicalNoDependent.Result.scope_status 'scope-in-progress' 'Canonical no-dependent reconciliation must preserve the in-progress scope state'
+Assert-Equal $canonicalNoDependent.Result.work_item_id $canonicalNoDependent.UnrelatedItem.work_item_id 'Canonical no-dependent reconciliation must select the unrelated eligible item'
+Assert-Equal $canonicalNoDependent.Result.reconciled_work_item_id $canonicalNoDependent.ReconciledItem.work_item_id 'Canonical no-dependent reconciliation must expose the reconciled completion'
+
+$missingNoDependentAuthority = Invoke-NoDependentReconciliationCase 'MISSING-AUTHORITY' $false
+Assert-Equal $missingNoDependentAuthority.Result.result 'scope-blocked' 'A newly reconciled completion must require terminal authority even when it has no dependent'
+Assert-Equal $missingNoDependentAuthority.Result.reason 'terminal-responsibility-authority-invalid' 'Missing no-dependent terminal authority must emit the canonical reason'
+Assert-Equal $missingNoDependentAuthority.Result.scope_status 'scope-blocked' 'Missing no-dependent terminal authority must block scope'
+Assert-Equal $missingNoDependentAuthority.Result.work_item_id '' 'Missing no-dependent terminal authority must not select unrelated work'
+
+foreach ($terminalAuthorityCase in @(
+  @{ Name = 'TERMINAL-PRE-V1'; Mutate = { param($terminal, $chain) $terminal.responsibility_handoff.responsibility_contract_version = 0 } },
+  @{ Name = 'TERMINAL-CROSS-RUN'; Mutate = { param($terminal, $chain) $terminal.run_id = 'RUN-FOREIGN-999' } },
+  @{ Name = 'TERMINAL-EVIDENCE-MISMATCH'; Mutate = { param($terminal, $chain) $terminal.responsibility_handoff.evidence_reference = 'runs/foreign-terminal-chain.md' } }
+)) {
+  $invalidTerminalAuthority = Invoke-NoDependentReconciliationCase $terminalAuthorityCase.Name $true $terminalAuthorityCase.Mutate
+  Assert-Equal $invalidTerminalAuthority.Result.result 'scope-blocked' "No-dependent reconciliation must reject $($terminalAuthorityCase.Name) authority"
+  Assert-Equal $invalidTerminalAuthority.Result.reason 'terminal-responsibility-authority-invalid' "No-dependent $($terminalAuthorityCase.Name) must emit the canonical authority reason"
+  Assert-Equal $invalidTerminalAuthority.Result.scope_status 'scope-blocked' "No-dependent $($terminalAuthorityCase.Name) must block scope"
+  Assert-Equal $invalidTerminalAuthority.Result.work_item_id '' "No-dependent $($terminalAuthorityCase.Name) must not select unrelated work"
+}
+
+foreach ($chainIndex in 0..4) {
+  foreach ($lifecycleCase in @(
+    @{ Name = 'STATUS'; Mutate = { param($artifact) $artifact.status = 'draft' } },
+    @{ Name = 'RESULT'; Mutate = { param($artifact) $artifact.result = 'blocked' } },
+    @{ Name = 'APPROVAL'; Mutate = { param($artifact) $artifact.approval_source = 'automation' } }
+  )) {
+    $caseName = "CHAIN-$chainIndex-$($lifecycleCase.Name)"
+    $mutation = {
+      param($terminal, $chain)
+      & $lifecycleCase.Mutate $chain.Artifacts[$chainIndex]
+    }.GetNewClosure()
+    $invalidChainAuthority = Invoke-NoDependentReconciliationCase $caseName $true $mutation
+    Assert-Equal $invalidChainAuthority.Result.result 'scope-blocked' "No-dependent reconciliation must reject $caseName lifecycle/authority"
+    Assert-Equal $invalidChainAuthority.Result.reason 'terminal-responsibility-authority-invalid' "No-dependent $caseName must emit the canonical authority reason"
+    Assert-Equal $invalidChainAuthority.Result.scope_status 'scope-blocked' "No-dependent $caseName must block scope"
+    Assert-Equal $invalidChainAuthority.Result.work_item_id '' "No-dependent $caseName must not select unrelated work"
+  }
+}
+
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
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/scope-engine.validation.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/scope-engine.validation.ps1
index 16004bc..7af2ec2 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/scope-engine.validation.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/scope-engine.validation.ps1
@@ -535,20 +535,38 @@ function Test-ScopeEngine([string]$Root, [string]$ContractText) {
             reason = 'non-terminal-attempt'
             scope_status = 'scope-in-progress'
             work_item_id = [string]$inProgressItem.work_item_id
             adapter_kind = [string]$inProgressItem.adapter_kind
             migration_unit_id = if ($inProgressItem.adapter_kind -ceq 'migration-unit') { [string]$inProgressItem.external_id } else { 'not-applicable' }
             reconciled_work_item_id = ''
           }
         }
       }
 
+      if (
+        -not [string]::IsNullOrWhiteSpace($reconciledWorkItemId) -and
+        [string]$inProgressItem.status -ceq 'complete' -and
+        (
+          [string]::IsNullOrWhiteSpace([string]$inProgressItem.terminal_evidence) -or
+          [string]$inProgressItem.terminal_evidence -ceq 'none' -or
+          -not (& $testTerminalResponsibilityAuthority $inProgressItem ([string]$inProgressItem.terminal_evidence))
+        )
+      ) {
+        return [pscustomobject]@{
+          result = 'scope-blocked'
+          reason = 'terminal-responsibility-authority-invalid'
+          scope_status = 'scope-blocked'
+          work_item_id = ''
+          reconciled_work_item_id = $reconciledWorkItemId
+        }
+      }
+
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

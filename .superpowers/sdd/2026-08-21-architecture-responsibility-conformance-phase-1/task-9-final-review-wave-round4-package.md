# Review package: bb0ee9612943bc2d9836c2ad66b762f56535fe1c..c0acc0b823acfa7967400a188c4ba7d32cdc31ab

## Commits
c0acc0b test: cover responsibility conformance workflow

## Files changed
 .../tests/scenarios/scope-engine.Tests.ps1         | 59 ++++++++++++++++++++--
 .../tests/validation/scope-engine.validation.ps1   |  1 +
 2 files changed, 55 insertions(+), 5 deletions(-)

## Diff
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/scope-engine.Tests.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/scope-engine.Tests.ps1
index ee37835..27bb5c2 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/scope-engine.Tests.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/scope-engine.Tests.ps1
@@ -265,66 +265,79 @@ function New-TerminalResponsibilityArtifact(
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
+    result = 'complete'
     mode_constraint = $ModeConstraint
     responsibility_chain_references = @($ChainReferences)
     responsibility_handoff = @{
       responsibility_contract_version = 1
       tree_conformance = 'PASS'
       responsibility_conformance = 'PASS'
       verification_ownership = 'PASS'
       architecture_state = 'PASS'
       evidence_reference = $EvidenceReference
     }
   }
 }
 
-function Invoke-NoDependentReconciliationCase(
+function Invoke-ReconciliationAuthorityCase(
   [string]$Suffix,
   [bool]$IncludeTerminalAuthority = $true,
-  [scriptblock]$MutateAuthority = $null
+  [scriptblock]$MutateAuthority = $null,
+  [bool]$NextItemDependsOnReconciled = $false
 ) {
   $reconciledItem = New-WorkItem "WORK-ADMIN-RECONCILE-$Suffix" 1 @() 'in-progress'
   $reconciledItem.latest_attempt = "ATTEMPT-WORK-ADMIN-RECONCILE-$Suffix-01"
   $reconciledItem.attempt_status = 'complete'
   $reconciledItem.terminal_evidence = "runs/reconcile-$($Suffix.ToLowerInvariant())-terminal.md"
   $reconciledItem.attempt_history = @(
     @{ attempt_id = $reconciledItem.latest_attempt; work_item_id = $reconciledItem.work_item_id; plan_revision = 3; status = 'complete'; artifact_reference = $reconciledItem.terminal_evidence }
   )
-  $unrelatedItem = New-WorkItem "WORK-ADMIN-UNRELATED-$Suffix" 2
+  $nextItemKind = if ($NextItemDependsOnReconciled) { 'DEPENDENT' } else { 'UNRELATED' }
+  $nextItemDependencies = if ($NextItemDependsOnReconciled) { @($reconciledItem.work_item_id) } else { @() }
+  $nextItem = New-WorkItem "WORK-ADMIN-$nextItemKind-$Suffix" 2 $nextItemDependencies
   $fixture = @{
     scenario_type = 'scope-engine'; operation = 'select'; current_plan_revision = 3
-    work_items = @($reconciledItem, $unrelatedItem)
+    work_items = @($reconciledItem, $nextItem)
   }
   if ($IncludeTerminalAuthority) {
     $chain = New-ResponsibilityChain "runs/reconcile-$($Suffix.ToLowerInvariant())-chain" $reconciledItem.work_item_id $reconciledItem.mode_constraint
     $terminal = New-TerminalResponsibilityArtifact $reconciledItem.terminal_evidence $reconciledItem.work_item_id 'complete' $chain.FinalReference $chain.References $chain.ModeConstraint
     $terminal.attempt_id = $reconciledItem.latest_attempt
     $terminal.result = 'complete'
     if ($null -ne $MutateAuthority) { & $MutateAuthority $terminal $chain }
     $fixture.terminal_artifacts = @($terminal)
     $fixture.responsibility_chain_artifacts = @($chain.Artifacts)
   }
   return [pscustomobject]@{
     Result = Invoke-ScopeScenario $fixture
     ReconciledItem = $reconciledItem
-    UnrelatedItem = $unrelatedItem
+    NextItem = $nextItem
+    UnrelatedItem = $nextItem
   }
 }
 
+function Invoke-NoDependentReconciliationCase(
+  [string]$Suffix,
+  [bool]$IncludeTerminalAuthority = $true,
+  [scriptblock]$MutateAuthority = $null
+) {
+  return (Invoke-ReconciliationAuthorityCase $Suffix $IncludeTerminalAuthority $MutateAuthority $false)
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
@@ -800,20 +813,56 @@ foreach ($chainIndex in 0..4) {
       & $lifecycleCase.Mutate $chain.Artifacts[$chainIndex]
     }.GetNewClosure()
     $invalidChainAuthority = Invoke-NoDependentReconciliationCase $caseName $true $mutation
     Assert-Equal $invalidChainAuthority.Result.result 'scope-blocked' "No-dependent reconciliation must reject $caseName lifecycle/authority"
     Assert-Equal $invalidChainAuthority.Result.reason 'terminal-responsibility-authority-invalid' "No-dependent $caseName must emit the canonical authority reason"
     Assert-Equal $invalidChainAuthority.Result.scope_status 'scope-blocked' "No-dependent $caseName must block scope"
     Assert-Equal $invalidChainAuthority.Result.work_item_id '' "No-dependent $caseName must not select unrelated work"
   }
 }
 
+# A successful reconciliation must apply the same exact terminal-result authority
+# as the normal successful-terminal-artifact transition before any next selection.
+foreach ($selectionCase in @(
+  @{ Name = 'UNRELATED'; DependsOnReconciled = $false },
+  @{ Name = 'DEPENDENT'; DependsOnReconciled = $true }
+)) {
+  foreach ($terminalResultCase in @(
+    @{ Name = 'COMPLETE'; Value = 'complete'; Canonical = $true },
+    @{ Name = 'BLOCKED'; Value = 'blocked'; Canonical = $false },
+    @{ Name = 'FAIL'; Value = 'fail'; Canonical = $false },
+    @{ Name = 'EMPTY'; Value = ''; Canonical = $false },
+    @{ Name = 'NONCANONICAL'; Value = 'Complete'; Canonical = $false }
+  )) {
+    $caseName = "$($selectionCase.Name)-TERMINAL-RESULT-$($terminalResultCase.Name)"
+    $terminalResultMutation = {
+      param($terminal, $chain)
+      $terminal.result = [string]$terminalResultCase.Value
+    }.GetNewClosure()
+    $resultAuthority = Invoke-ReconciliationAuthorityCase $caseName $true $terminalResultMutation $selectionCase.DependsOnReconciled
+
+    if ($terminalResultCase.Canonical) {
+      Assert-Equal $resultAuthority.Result.result 'selected' "$caseName must permit next selection only for exact terminal result complete"
+      Assert-Equal $resultAuthority.Result.scope_status 'scope-in-progress' "$caseName must preserve the exact selected scope status"
+      Assert-Equal $resultAuthority.Result.reconciled_work_item_id $resultAuthority.ReconciledItem.work_item_id "$caseName must expose the exact reconciled work-item ID"
+      Assert-Equal $resultAuthority.Result.work_item_id $resultAuthority.NextItem.work_item_id "$caseName must select the expected next item"
+    }
+    else {
+      Assert-Equal $resultAuthority.Result.result 'scope-blocked' "$caseName must reject non-complete terminal result authority"
+      Assert-Equal $resultAuthority.Result.reason 'terminal-responsibility-authority-invalid' "$caseName must emit the canonical terminal authority reason"
+      Assert-Equal $resultAuthority.Result.scope_status 'scope-blocked' "$caseName must return the exact blocked scope status"
+      Assert-Equal $resultAuthority.Result.reconciled_work_item_id $resultAuthority.ReconciledItem.work_item_id "$caseName must expose the exact reconciled work-item ID"
+      Assert-Equal $resultAuthority.Result.work_item_id '' "$caseName must not select another item"
+    }
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
index 7af2ec2..200a1f0 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/scope-engine.validation.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/scope-engine.validation.ps1
@@ -292,20 +292,21 @@ function Test-ScopeEngine([string]$Root, [string]$ContractText) {
         @('11-ai-review', '12-verification-testing', '13-verify-parity', '15-knowledge-base')
       }
       else { @() }
       $chainReferences = @($terminalArtifact.responsibility_chain_references)
       if (
         [string]$terminalArtifact.artifact_reference -cne $Reference -or
         -not [bool]$terminalArtifact.immutable -or
         [string]$terminalArtifact.artifact_type -cne 'migration-work-item-terminal' -or
         [string]$terminalArtifact.work_item_id -cne [string]$Item.work_item_id -or
         [int]$terminalArtifact.plan_revision -ne [int]$scenario.current_plan_revision -or
+        [string]$terminalArtifact.result -cne 'complete' -or
         [string]$terminalArtifact.run_id -cne [string]$context.run_id -or
         [string]$terminalArtifact.master_spec_ref -cne [string]$context.master_spec_ref -or
         [string]$terminalArtifact.master_spec_id -cne [string]$context.master_spec_id -or
         [int]$terminalArtifact.master_spec_revision -ne [int]$context.latest_spec_revision -or
         [string]$terminalArtifact.master_plan_ref -cne [string]$context.master_plan_ref -or
         [string]$terminalArtifact.master_plan_id -cne [string]$context.master_plan_id -or
         [int]$terminalArtifact.master_plan_revision -ne [int]$context.current_plan_revision -or
         [string]$terminalArtifact.mode_constraint -cne [string]$Item.mode_constraint -or
         [int]$handoff.responsibility_contract_version -ne 1 -or
         [string]$handoff.tree_conformance -cne 'PASS' -or

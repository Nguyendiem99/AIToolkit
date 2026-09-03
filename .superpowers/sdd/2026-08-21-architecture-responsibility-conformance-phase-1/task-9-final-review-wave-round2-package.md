# Review package: e04242560502ea8c9d5e99998c57bff56fe460d3..ed6e436f9d7a7cf24981bf0a06178329a70b94f0

## Commits
ed6e436 test: cover responsibility conformance workflow

## Files changed
 .../tests/scenarios/architecture-review.Tests.ps1  | 94 ++++++++++++++++++----
 .../tests/scenarios/scope-engine.Tests.ps1         | 33 +++++++-
 .../responsibility-conformance.validation.ps1      | 72 ++++++++++++-----
 .../tests/validation/scope-engine.validation.ps1   | 40 ++++-----
 4 files changed, 185 insertions(+), 54 deletions(-)

## Diff
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/architecture-review.Tests.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/architecture-review.Tests.ps1
index 1a0ccc5..71f7469 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/architecture-review.Tests.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/architecture-review.Tests.ps1
@@ -634,64 +634,92 @@ function Add-DeletedNonOwnerPath([string]$Root, [bool]$ValidCheckpoint) {
   $anchorRows = @($implementation -split '\r?\n' | Where-Object { $_ -cmatch '^\| WORK-ADMIN \| src/admin_route\.source \|' })
   if ($anchorRows.Count -ne 1) { throw 'Deleted non-owner Change Hygiene anchor is missing or duplicated' }
   $deletedRow = "| WORK-ADMIN | README | deleted | repository readme | none | none | $checkpoint | $taskBaseSha | $finalTreeSha |"
   Set-Content -Encoding utf8 -LiteralPath $implementationPath -Value $implementation.Replace($anchorRows[0], "$($anchorRows[0])`n$deletedRow")
   $reviewPath = Join-Path $Root 'artifacts/review-report.md'
   $review = (Get-Content -Raw -Encoding utf8 -LiteralPath $reviewPath).Replace($previousFinalTreeSha, $finalTreeSha)
   Set-Content -Encoding utf8 -LiteralPath $reviewPath -Value $review
   Set-Content -Encoding utf8 -LiteralPath $provenancePath -Value "Source Root: $sourceRoot`nTask-base SHA: $taskBaseSha`nFinal-tree SHA: $finalTreeSha`n"
 }
 
-function Rename-ProductionOwner([string]$Root, [bool]$ExplicitMapping) {
+function Rename-ProductionOwner(
+  [string]$Root,
+  [bool]$ExplicitMapping,
+  [string]$DestinationPath = 'docs/admin_route.source'
+) {
   $provenancePath = Join-Path $Root 'artifacts/review-provenance.md'
   $provenance = Get-Content -Raw -Encoding utf8 -LiteralPath $provenancePath
   $sourceRoot = [regex]::Match($provenance, '(?m)^Source Root:\s*(?<value>.+)$').Groups['value'].Value.Trim()
   $taskBaseSha = [regex]::Match($provenance, '(?im)^Task-base SHA:[ \t]*(?<value>[0-9a-f]{40})[ \t]*\r?$').Groups['value'].Value
   $previousFinalTreeSha = [regex]::Match($provenance, '(?im)^Final-tree SHA:[ \t]*(?<value>[0-9a-f]{40})[ \t]*\r?$').Groups['value'].Value
-  [void](New-Item -ItemType Directory -Force -Path (Join-Path $sourceRoot 'docs'))
-  Move-Item -LiteralPath (Join-Path $sourceRoot 'src/admin_route.source') -Destination (Join-Path $sourceRoot 'docs/admin_route.source')
+  $destinationFullPath = Join-Path $sourceRoot $DestinationPath
+  [void](New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destinationFullPath))
+  Move-Item -LiteralPath (Join-Path $sourceRoot 'src/admin_route.source') -Destination $destinationFullPath
   $verificationPath = Join-Path $sourceRoot 'test/admin_route_test.ps1'
-  $verificationText = (Get-Content -Raw -Encoding utf8 -LiteralPath $verificationPath).Replace('@production-binding src/admin_route.source#AdminRoute', '@production-binding docs/admin_route.source#AdminRoute')
+  $verificationText = (Get-Content -Raw -Encoding utf8 -LiteralPath $verificationPath).Replace('@production-binding src/admin_route.source#AdminRoute', "@production-binding ${DestinationPath}#AdminRoute")
   Set-Content -Encoding utf8 -LiteralPath $verificationPath -Value $verificationText
-  Invoke-PinnedSourceGit $sourceRoot @('add', '--all', '--', 'src/admin_route.source', 'docs/admin_route.source', 'test/admin_route_test.ps1') | Out-Null
+  Invoke-PinnedSourceGit $sourceRoot @('add', '--all', '--', 'src/admin_route.source', $DestinationPath, 'test/admin_route_test.ps1') | Out-Null
   Invoke-PinnedSourceGit $sourceRoot @('commit', '-m', 'rename production owner to docs') | Out-Null
   $finalTreeSha = Invoke-PinnedSourceGit $sourceRoot @('rev-parse', 'HEAD')
   foreach ($relativePath in @('artifacts/design-report.md', 'artifacts/implementation-report.md', 'artifacts/review-report.md')) {
     $path = Join-Path $Root $relativePath
-    $text = (Get-Content -Raw -Encoding utf8 -LiteralPath $path).Replace($previousFinalTreeSha, $finalTreeSha).Replace('src/admin_route.source', 'docs/admin_route.source')
+    $text = (Get-Content -Raw -Encoding utf8 -LiteralPath $path).Replace($previousFinalTreeSha, $finalTreeSha).Replace('src/admin_route.source', $DestinationPath)
     Set-Content -Encoding utf8 -LiteralPath $path -Value $text
   }
   $implementationPath = Join-Path $Root 'artifacts/implementation-report.md'
   $implementation = Get-Content -Raw -Encoding utf8 -LiteralPath $implementationPath
-  $sourceRows = @($implementation -split '\r?\n' | Where-Object { $_ -cmatch '^\| WORK-ADMIN \| docs/admin_route\.source \|' })
+  $sourceRows = @($implementation -split '\r?\n' | Where-Object { $_ -cmatch ('^\| WORK-ADMIN \| ' + [regex]::Escape($DestinationPath) + ' \|') })
   if ($sourceRows.Count -ne 1) { throw 'Renamed production Change Hygiene row is missing or duplicated' }
-  $checkpoint = if ($ExplicitMapping) { "source:${taskBaseSha}:src/admin_route.source; diff:${taskBaseSha}..${finalTreeSha}:src/admin_route.source->docs/admin_route.source" } else { "source:${taskBaseSha}:src/admin_route.source; diff:${taskBaseSha}..${finalTreeSha}:docs/admin_route.source" }
+  $checkpoint = if ($ExplicitMapping) { "source:${taskBaseSha}:src/admin_route.source; diff:${taskBaseSha}..${finalTreeSha}:src/admin_route.source->${DestinationPath}" } else { "source:${taskBaseSha}:src/admin_route.source; diff:${taskBaseSha}..${finalTreeSha}:${DestinationPath}" }
   $updatedSourceRow = [regex]::Replace($sourceRows[0], '\| none \| (?=[0-9a-f]{40} \| [0-9a-f]{40} \|$)', "| $checkpoint | ")
   if ($updatedSourceRow -ceq $sourceRows[0]) { throw 'Renamed production checkpoint replacement failed' }
   Set-Content -Encoding utf8 -LiteralPath $implementationPath -Value $implementation.Replace($sourceRows[0], $updatedSourceRow)
   $reviewPath = Join-Path $Root 'artifacts/review-report.md'
   $review = Get-Content -Raw -Encoding utf8 -LiteralPath $reviewPath
   if ($ExplicitMapping) {
-    $review = $review.Replace("diff:${taskBaseSha}..${finalTreeSha}:docs/admin_route.source#", "diff:${taskBaseSha}..${finalTreeSha}:src/admin_route.source->docs/admin_route.source#")
+    $review = $review.Replace("diff:${taskBaseSha}..${finalTreeSha}:${DestinationPath}#", "diff:${taskBaseSha}..${finalTreeSha}:src/admin_route.source->${DestinationPath}#")
   }
   Set-Content -Encoding utf8 -LiteralPath $reviewPath -Value $review
   Set-Content -Encoding utf8 -LiteralPath $provenancePath -Value "Source Root: $sourceRoot`nTask-base SHA: $taskBaseSha`nFinal-tree SHA: $finalTreeSha`n"
 }
 
-function Convert-ReviewPathsToWindows([string]$Root) {
+function Set-PinnedProductionBindings(
+  [string]$Root,
+  [string[]]$BindingPaths,
+  [bool]$UseWindowsArtifactPaths = $false
+) {
+  $provenancePath = Join-Path $Root 'artifacts/review-provenance.md'
+  $provenance = Get-Content -Raw -Encoding utf8 -LiteralPath $provenancePath
+  $sourceRoot = [regex]::Match($provenance, '(?m)^Source Root:\s*(?<value>.+)$').Groups['value'].Value.Trim()
+  $taskBaseSha = [regex]::Match($provenance, '(?im)^Task-base SHA:[ \t]*(?<value>[0-9a-f]{40})[ \t]*\r?$').Groups['value'].Value
+  $previousFinalTreeSha = [regex]::Match($provenance, '(?im)^Final-tree SHA:[ \t]*(?<value>[0-9a-f]{40})[ \t]*\r?$').Groups['value'].Value
+  $verificationPath = Join-Path $sourceRoot 'test/admin_route_test.ps1'
+  $verificationText = Get-Content -Raw -Encoding utf8 -LiteralPath $verificationPath
+  $replacement = @($BindingPaths | ForEach-Object { "@production-binding ${_}#AdminRoute" }) -join "`n"
+  $updatedVerification = [regex]::Replace($verificationText, '(?m)^@production-binding[^\r\n]+$', $replacement)
+  if ($updatedVerification -ceq $verificationText) { throw 'Pinned production-binding fixture replacement failed' }
+  Set-Content -Encoding utf8 -LiteralPath $verificationPath -Value $updatedVerification
+  Invoke-PinnedSourceGit $sourceRoot @('add', '--', 'test/admin_route_test.ps1') | Out-Null
+  Invoke-PinnedSourceGit $sourceRoot @('commit', '-m', 'change pinned production binding') | Out-Null
+  $finalTreeSha = Invoke-PinnedSourceGit $sourceRoot @('rev-parse', 'HEAD')
+
   foreach ($relativePath in @('artifacts/design-report.md', 'artifacts/implementation-report.md', 'artifacts/review-report.md')) {
     $path = Join-Path $Root $relativePath
-    $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
-    $updated = $text.Replace('src/admin_route.source', 'src\admin_route.source')
-    if ($updated -ceq $text) { throw "Windows path fixture did not change $relativePath" }
+    $text = (Get-Content -Raw -Encoding utf8 -LiteralPath $path).Replace($previousFinalTreeSha, $finalTreeSha)
+    $updated = if ($UseWindowsArtifactPaths) { $text.Replace('src/admin_route.source', 'src\admin_route.source') } else { $text }
     Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
   }
+  Set-Content -Encoding utf8 -LiteralPath $provenancePath -Value "Source Root: $sourceRoot`nTask-base SHA: $taskBaseSha`nFinal-tree SHA: $finalTreeSha`n"
+}
+
+function Convert-ReviewPathsToWindows([string]$Root) {
+  Set-PinnedProductionBindings $Root @('src\admin_route.source') $true
 }
 
 function Keep-ImplementationSelfAttestationPass([string]$Root) {
   $path = Join-Path $Root 'artifacts/implementation-report.md'
   $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
   $updated = $text.Replace('Architecture Conformance State: NOT_REVIEWED', 'Architecture Conformance State: PASS')
   if ($updated -ceq $text) { throw 'Implementation self-attestation fixture replacement failed' }
   Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
 }
 
@@ -941,24 +969,62 @@ Assert-Pass 'deleted non-owner Git path accepts exact base-source and removal-di
 Assert-FailsLike 'renamed owner rejects destination-only checkpoint and review evidence' {
   param($root)
   Rename-ProductionOwner $root $false
 } 'responsibility-evidence-missing' $true $true
 
 Assert-Pass 'renamed owner accepts explicit old-to-new checkpoint and review reconciliation' {
   param($root)
   Rename-ProductionOwner $root $true
 } $true $true
 
+Assert-Pass 'review evidence accepts canonical hyphenated repository paths' {
+  param($root)
+  Rename-ProductionOwner $root $true 'src/admin-route.source'
+} $true $true
+
+Assert-FailsLike 'review evidence rejects a source item with a rename delimiter' {
+  param($root)
+  $path = Join-Path $root 'artifacts/review-report.md'
+  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
+  $updated = [regex]::Replace($text, '(source:[0-9a-f]{40}:)src/admin_route\.source#', '$1src/admin_route.source->src/admin-route.source#')
+  if ($updated -ceq $text) { throw 'Source delimiter fixture replacement failed' }
+  Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
+} 'responsibility-evidence-missing' $true
+
+Assert-FailsLike 'review evidence rejects parent traversal in a repository path' {
+  param($root)
+  $path = Join-Path $root 'artifacts/review-report.md'
+  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
+  $updated = $text.Replace('src/admin_route.source', 'src/../src/admin_route.source')
+  if ($updated -ceq $text) { throw 'Review parent traversal fixture replacement failed' }
+  Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
+} 'responsibility-evidence-missing' $true
+
 Assert-Pass 'composed review normalizes Windows repository paths before every authority comparison' {
   param($root)
   Convert-ReviewPathsToWindows $root
-} $true
+} $true $true
+
+Assert-FailsLike 'pinned verification rejects slash-backslash alias duplicate production bindings' {
+  param($root)
+  Set-PinnedProductionBindings $root @('src/admin_route.source', 'src\admin_route.source')
+} 'verification-production-binding-missing' $true $true
+
+Assert-FailsLike 'pinned verification rejects parent traversal in a production binding' {
+  param($root)
+  Set-PinnedProductionBindings $root @('src\..\src\admin_route.source')
+} 'verification-production-binding-missing' $true $true
+
+Assert-FailsLike 'pinned verification rejects a canonical production-binding mismatch' {
+  param($root)
+  Set-PinnedProductionBindings $root @('src/other_route.source')
+} 'verification-production-binding-missing' $true $true
 
 Assert-FailsLike 'canonical normalization rejects slash-backslash alias duplication in Change Hygiene' {
   param($root)
   $path = Join-Path $root 'artifacts/implementation-report.md'
   $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
   $rows = @($text -split '\r?\n' | Where-Object { $_ -cmatch '^\| WORK-ADMIN \| src/admin_route\.source \|' })
   if ($rows.Count -ne 1) { throw 'Path alias Change Hygiene anchor is missing or duplicated' }
   $aliasRow = $rows[0].Replace('src/admin_route.source', 'src\admin_route.source')
   Set-Content -Encoding utf8 -LiteralPath $path -Value $text.Replace($rows[0], "$($rows[0])`n$aliasRow")
 } 'responsibility-evidence-missing' $true
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/scope-engine.Tests.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/scope-engine.Tests.ps1
index ec321ee..90750e8 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/scope-engine.Tests.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/scope-engine.Tests.ps1
@@ -41,20 +41,26 @@ function Invoke-ScopeScenario([hashtable]$Fixture) {
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
+        $suppliedTerminalArtifacts = @()
+        if ($Fixture.ContainsKey('terminal_artifact')) { $suppliedTerminalArtifacts += @($Fixture.terminal_artifact) }
+        if ($Fixture.ContainsKey('terminal_artifacts')) { $suppliedTerminalArtifacts += @($Fixture.terminal_artifacts) }
+        if (@($suppliedTerminalArtifacts | Where-Object { [string]$_.artifact_reference -ceq [string]$attempt.artifact_reference }).Count -eq 1) {
+          continue
+        }
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
@@ -685,29 +691,52 @@ Assert-Equal $resume.result 'resume-attempt' 'Non-terminal attempt must resume i
 Assert-Equal $resume.work_item_id 'WORK-ADMIN-RUNNING' 'Resume must keep the deterministic in-progress item'
 
 $runningWithEvidence = New-WorkItem 'WORK-ADMIN-RUNNING' 1 @() 'in-progress'
 $runningWithEvidence.latest_attempt = 'ATTEMPT-WORK-ADMIN-RUNNING-01'
 $runningWithEvidence.attempt_status = 'complete'
 $runningWithEvidence.attempt_evidence_valid = $true
 $runningWithEvidence.terminal_evidence = 'runs/attempt-running-01.md'
 $runningWithEvidence.attempt_history = @(
   @{ attempt_id = 'ATTEMPT-WORK-ADMIN-RUNNING-01'; work_item_id = 'WORK-ADMIN-RUNNING'; plan_revision = 3; status = 'complete'; artifact_reference = 'runs/attempt-running-01.md' }
 )
+$waitingAfterReconcile = New-WorkItem 'WORK-ADMIN-WAITING-AFTER-RECONCILE' 2 @($runningWithEvidence.work_item_id)
+$runningChain = New-ResponsibilityChain 'runs/running-reconcile-chain' $runningWithEvidence.work_item_id $runningWithEvidence.mode_constraint
+$runningTerminal = New-TerminalResponsibilityArtifact $runningWithEvidence.terminal_evidence $runningWithEvidence.work_item_id 'complete' $runningChain.FinalReference $runningChain.References $runningChain.ModeConstraint
+$runningTerminal.attempt_id = $runningWithEvidence.latest_attempt
+$runningTerminal.result = 'complete'
 $afterReconcile = Invoke-ScopeScenario @{
   scenario_type = 'scope-engine'
   operation = 'select'
   current_plan_revision = 3
-  work_items = @($runningWithEvidence, $waiting)
+  work_items = @($runningWithEvidence, $waitingAfterReconcile)
+  terminal_artifacts = @($runningTerminal)
+  responsibility_chain_artifacts = @($runningChain.Artifacts)
 }
 Assert-Equal $afterReconcile.result 'selected' 'Valid terminal evidence must be reconciled before selecting again'
 Assert-Equal $afterReconcile.reconciled_work_item_id 'WORK-ADMIN-RUNNING' 'Resume must expose the reconciled item'
-Assert-Equal $afterReconcile.work_item_id 'WORK-ADMIN-WAITING' 'Resume must select the next deterministic item after reconciliation'
+Assert-Equal $afterReconcile.work_item_id 'WORK-ADMIN-WAITING-AFTER-RECONCILE' 'Canonical terminal responsibility authority must unlock the dependent after reconciliation'
+
+$reconciledWithoutAuthority = New-WorkItem 'WORK-ADMIN-RECONCILED-WITHOUT-AUTHORITY' 1 @() 'in-progress'
+$reconciledWithoutAuthority.latest_attempt = 'ATTEMPT-WORK-ADMIN-RECONCILED-WITHOUT-AUTHORITY-01'
+$reconciledWithoutAuthority.attempt_status = 'complete'
+$reconciledWithoutAuthority.terminal_evidence = 'runs/reconciled-without-authority.md'
+$reconciledWithoutAuthority.attempt_history = @(
+  @{ attempt_id = $reconciledWithoutAuthority.latest_attempt; work_item_id = $reconciledWithoutAuthority.work_item_id; plan_revision = 3; status = 'complete'; artifact_reference = $reconciledWithoutAuthority.terminal_evidence }
+)
+$dependentAfterReconcile = New-WorkItem 'WORK-ADMIN-DEPENDENT-AFTER-RECONCILE' 2 @($reconciledWithoutAuthority.work_item_id)
+$untrustedReconcile = Invoke-ScopeScenario @{
+  scenario_type = 'scope-engine'; operation = 'select'; current_plan_revision = 3
+  work_items = @($reconciledWithoutAuthority, $dependentAfterReconcile)
+}
+Assert-Equal $untrustedReconcile.result 'scope-blocked' 'Reconciliation must not unlock a dependent without canonical terminal responsibility authority'
+Assert-Equal $untrustedReconcile.reason 'terminal-responsibility-authority-invalid' 'Missing reconciled terminal chain must fail the dependency authority gate'
+Assert-Equal $untrustedReconcile.work_item_id '' 'A reconciled dependency without terminal authority must leave its dependent unselected'
 
 $secondRunning = New-WorkItem 'WORK-ADMIN-SECOND-RUNNING' 2 @() 'in-progress'
 $secondRunning.latest_attempt = 'ATTEMPT-WORK-ADMIN-SECOND-RUNNING-01'
 $secondRunning.attempt_status = 'in-progress'
 $secondRunning.attempt_history = @(
   @{ attempt_id = 'ATTEMPT-WORK-ADMIN-SECOND-RUNNING-01'; work_item_id = 'WORK-ADMIN-SECOND-RUNNING'; plan_revision = 3; status = 'in-progress'; artifact_reference = 'runs/second-running-01.md' }
 )
 $multipleRunning = Invoke-ScopeScenario @{
   scenario_type = 'scope-engine'
   operation = 'select'
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1
index 14a8388..571dd68 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1
@@ -1349,20 +1349,54 @@ function ConvertTo-ArcCanonicalRepositoryPath {
   if ([string]::IsNullOrWhiteSpace($Path) -or $Path -cne $Path.Trim()) { return '' }
   $canonicalPath = $Path.Replace('\', '/')
   if (
     $canonicalPath -cnotmatch '^(?:[A-Za-z0-9_.-]+/)*[A-Za-z0-9_.-]+$' -or
     $canonicalPath -match '^(?:/|[A-Za-z]:)' -or
     @($canonicalPath -split '/' | Where-Object { $_ -cin @('.', '..') }).Count -gt 0
   ) { return '' }
   return $canonicalPath
 }
 
+function ConvertTo-ArcCanonicalReviewEvidenceItem {
+  [CmdletBinding()]
+  param([Parameter(Mandatory)][AllowEmptyString()][string]$EvidenceItem)
+
+  $match = [regex]::Match(
+    $EvidenceItem,
+    '^(?<kind>source|diff):(?<task>[0-9a-f]{40})(?<range>\.\.(?<final>[0-9a-f]{40}))?:(?<paths>[^#;\r\n]+)#(?<anchor>[A-Za-z][A-Za-z0-9_.:-]*)$'
+  )
+  if (-not $match.Success) { return '' }
+  $kind = $match.Groups['kind'].Value
+  $hasRange = $match.Groups['range'].Success
+  if (($kind -ceq 'source' -and $hasRange) -or ($kind -ceq 'diff' -and -not $hasRange)) { return '' }
+
+  $rawPaths = $match.Groups['paths'].Value
+  $delimiterCount = [regex]::Matches($rawPaths, '->').Count
+  if (($kind -ceq 'source' -and $delimiterCount -ne 0) -or ($kind -ceq 'diff' -and $delimiterCount -gt 1)) { return '' }
+  $pathParts = @([regex]::Split($rawPaths, '->'))
+  if (($kind -ceq 'source' -and $pathParts.Count -ne 1) -or ($kind -ceq 'diff' -and $pathParts.Count -notin @(1, 2))) { return '' }
+
+  $canonicalPaths = [Collections.Generic.List[string]]::new()
+  foreach ($pathPart in $pathParts) {
+    $canonicalPath = ConvertTo-ArcCanonicalRepositoryPath -Path $pathPart
+    if ($canonicalPath -ceq '') { return '' }
+    $canonicalPaths.Add($canonicalPath)
+  }
+  $shaRange = if ($kind -ceq 'source') {
+    $match.Groups['task'].Value
+  }
+  else {
+    "$($match.Groups['task'].Value)..$($match.Groups['final'].Value)"
+  }
+  return "${kind}:${shaRange}:$($canonicalPaths -join '->')#$($match.Groups['anchor'].Value)"
+}
+
 function Test-ArcCanonicalProductionPath {
   [CmdletBinding()]
   param([Parameter(Mandatory)][string]$Path)
 
   # Phase 1 uses repository-relative roots as the language-neutral production
   # classifier. Tests, docs, tooling, generated output, and repository metadata
   # remain non-production unless an approved responsibility selects them.
   $canonicalPath = ConvertTo-ArcCanonicalRepositoryPath -Path $Path
   if ($canonicalPath -ceq '') { return $false }
   return $canonicalPath -cmatch '^(?:(?:src|lib|app|apps/[^/]+/(?:src|lib|app)|packages/[^/]+/(?:src|lib|app)|server|client|frontend|backend)/)' -and
@@ -1712,25 +1746,24 @@ function Get-ArcPinnedSourceInventory {
 function Test-ArcPinnedVerificationOwnershipEvidence {
   [CmdletBinding()]
   param(
     [Parameter(Mandatory)][hashtable]$VerificationRow,
     [Parameter(Mandatory)][string]$SourceRoot,
     [Parameter(Mandatory)][string]$FinalTreeSha,
     [Parameter(Mandatory)][hashtable]$ProductionOwnersById,
     [Parameter(Mandatory)][AllowEmptyCollection()][Collections.Generic.List[string]]$Errors
   )
 
-  $path = $VerificationRow['Evidence Path']
+  $path = ConvertTo-ArcCanonicalRepositoryPath -Path $VerificationRow['Evidence Path']
   $scenario = $VerificationRow['Evidence Symbol or Scenario']
   if (
-    $path -cnotmatch '^(?:[A-Za-z0-9_.-]+/)*[A-Za-z0-9_.-]+$' -or
-    $path -match '^(?:/|[A-Za-z]:|.*(?:^|/)\.\.(?:/|$))' -or
+    $path -ceq '' -or
     $scenario -cnotmatch '^[A-Za-z][A-Za-z0-9_.:-]*$'
   ) {
     $Errors.Add('verification-production-binding-missing')
     return $false
   }
   try { $evidenceText = Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('show', "${FinalTreeSha}:$path") }
   catch {
     $Errors.Add('verification-production-binding-missing')
     return $false
   }
@@ -1754,35 +1787,44 @@ function Test-ArcPinnedVerificationOwnershipEvidence {
     if ($matches.Count -ne 1 -or $matches[0].Groups['value'].Value -cne $requiredMarkers[$marker]) {
       $Errors.Add('verification-production-binding-missing')
       return $false
     }
   }
   if (@([regex]::Matches($block, '(?m)^\s*scenario\s+' + [regex]::Escape($scenario) + '\s*$')).Count -ne 1) {
     $Errors.Add('verification-production-binding-missing')
     return $false
   }
 
-  $plannedBinding = [regex]::Match($VerificationRow['Production Binding Evidence'], '^invokes\s+(?<path>(?:[A-Za-z0-9_.-]+/)*[A-Za-z0-9_.-]+)#(?<symbol>[A-Za-z][A-Za-z0-9_.:-]*)$')
-  $sourceBindings = @([regex]::Matches($block, '(?m)^\s*@production-binding\s+(?<path>(?:[A-Za-z0-9_.-]+/)*[A-Za-z0-9_.-]+)#(?<symbol>[A-Za-z][A-Za-z0-9_.:-]*)\s*$'))
-  if (-not $plannedBinding.Success -or $sourceBindings.Count -ne 1 -or $sourceBindings[0].Groups['path'].Value -cne $plannedBinding.Groups['path'].Value -or $sourceBindings[0].Groups['symbol'].Value -cne $plannedBinding.Groups['symbol'].Value) {
+  $plannedBinding = [regex]::Match($VerificationRow['Production Binding Evidence'], '^invokes\s+(?<path>[^#\r\n]+)#(?<symbol>[A-Za-z][A-Za-z0-9_.:-]*)$')
+  $plannedBindingPath = if ($plannedBinding.Success) { ConvertTo-ArcCanonicalRepositoryPath -Path $plannedBinding.Groups['path'].Value } else { '' }
+  $sourceBindings = @([regex]::Matches($block, '(?m)^\s*@production-binding\s+(?<path>[^#\r\n]+)#(?<symbol>[A-Za-z][A-Za-z0-9_.:-]*)\s*$'))
+  $sourceBindingPath = if ($sourceBindings.Count -eq 1) { ConvertTo-ArcCanonicalRepositoryPath -Path $sourceBindings[0].Groups['path'].Value } else { '' }
+  if (
+    -not $plannedBinding.Success -or
+    $plannedBindingPath -ceq '' -or
+    $sourceBindings.Count -ne 1 -or
+    $sourceBindingPath -ceq '' -or
+    $sourceBindingPath -cne $plannedBindingPath -or
+    $sourceBindings[0].Groups['symbol'].Value -cne $plannedBinding.Groups['symbol'].Value
+  ) {
     $Errors.Add('verification-production-binding-missing')
     return $false
   }
 
   $responsibilityId = $VerificationRow['Production Responsibility ID']
   if (-not $ProductionOwnersById.ContainsKey($responsibilityId)) {
     $Errors.Add('verification-production-binding-missing')
     return $false
   }
   $productionOwner = $ProductionOwnersById[$responsibilityId]
   if (
-    $productionOwner.Path -cne $plannedBinding.Groups['path'].Value -or
+    $productionOwner.Path -cne $plannedBindingPath -or
     ($productionOwner.OwnerSymbols -cnotcontains $plannedBinding.Groups['symbol'].Value -and $productionOwner.Symbols -cnotcontains $plannedBinding.Groups['symbol'].Value) -or
     $productionOwner.Capabilities -cnotcontains $VerificationRow['Capability ID'] -or
     $productionOwner.VerificationOwners -cnotcontains $VerificationRow['Verification Owner ID']
   ) {
     $Errors.Add('verification-production-binding-missing')
     return $false
   }
 
   if ($VerificationRow['Evidence Kind'] -ceq 'production-composition') {
     $routeMatches = @([regex]::Matches($block, '(?m)^\s*@production-route\s+(?<symbol>[A-Za-z][A-Za-z0-9_.:-]*)\s*->\s*(?<provider>[A-Za-z][A-Za-z0-9_.:-]*)\s*$'))
@@ -1963,30 +2005,23 @@ function Test-ResponsibilityReview {
     $canonicalBindingPath = if ($bindingMatch.Success) { ConvertTo-ArcCanonicalRepositoryPath -Path $bindingMatch.Groups['path'].Value } else { '' }
     if ($canonicalEvidencePath -ceq '' -or $canonicalBindingPath -ceq '') { $errors.Add('responsibility-evidence-missing') }
     else {
       $verificationRow['Evidence Path'] = $canonicalEvidencePath
       $verificationRow['Production Binding Evidence'] = "invokes $canonicalBindingPath#$($bindingMatch.Groups['symbol'].Value)"
     }
   }
   foreach ($reviewRow in $reviewRows) {
     $canonicalEvidenceItems = [Collections.Generic.List[string]]::new()
     foreach ($evidenceItem in @($reviewRow['Source/Diff Evidence'] -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })) {
-      $evidenceMatch = [regex]::Match($evidenceItem, '^(?<prefix>source:[0-9a-f]{40}:|diff:[0-9a-f]{40}\.\.[0-9a-f]{40}:)(?<paths>[^#]+)#(?<anchor>[A-Za-z][A-Za-z0-9_.:-]*)$')
-      if (-not $evidenceMatch.Success) { $errors.Add('responsibility-evidence-missing'); continue }
-      $canonicalPaths = [Collections.Generic.List[string]]::new()
-      foreach ($evidencePath in @($evidenceMatch.Groups['paths'].Value -split '->')) {
-        $canonicalEvidencePath = ConvertTo-ArcCanonicalRepositoryPath -Path $evidencePath
-        if ($canonicalEvidencePath -ceq '') { $errors.Add('responsibility-evidence-missing') }
-        else { $canonicalPaths.Add($canonicalEvidencePath) }
-      }
-      if ($canonicalPaths.Count -notin @(1, 2)) { $errors.Add('responsibility-evidence-missing'); continue }
-      $canonicalEvidenceItems.Add("$($evidenceMatch.Groups['prefix'].Value)$($canonicalPaths -join '->')#$($evidenceMatch.Groups['anchor'].Value)")
+      $canonicalEvidenceItem = ConvertTo-ArcCanonicalReviewEvidenceItem -EvidenceItem $evidenceItem
+      if ($canonicalEvidenceItem -ceq '') { $errors.Add('responsibility-evidence-missing'); continue }
+      $canonicalEvidenceItems.Add($canonicalEvidenceItem)
     }
     $reviewRow['Source/Diff Evidence'] = $canonicalEvidenceItems -join '; '
   }
   if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }
   $toMap = { param([object[]]$Rows, [string]$IdColumn, [string]$DuplicateDiagnostic) $map = @{}; foreach ($row in $Rows) { $id = $row[$IdColumn]; if ($map.ContainsKey($id)) { $errors.Add($DuplicateDiagnostic) } else { $map[$id] = $row } }; return $map }
   $allPlannedById = & $toMap $allPlannedResponsibilities 'Responsibility ID' 'responsibility-owner-extra'
   $referencedOwnerIds = @()
   if ($ownerReferenceRows.Count -ne 1 -or $ownerReferenceRows[0]['Design Revision'] -cne $designRevision) {
     $errors.Add('responsibility-owner-extra')
   }
@@ -2100,21 +2135,22 @@ function Test-ResponsibilityReview {
       $evidenceInvalid = $evidenceItems -cnotcontains $expectedSource -or
         ($requiresDiff -and $evidenceItems -cnotcontains $expectedDiff) -or
         $hasAnyDiffForUnchangedAnchor
       if ($evidenceInvalid) {
         $errors.Add('responsibility-evidence-missing')
         if ($evidenceItems -cnotcontains $expectedSource -or $sourceVerificationOwners -ccontains $anchor) { $errors.Add('verification-production-binding-missing') }
         $treePass = $false; $verificationPass = $false
       }
     }
     foreach ($evidence in $evidenceItems) {
-      if ($evidence -cnotmatch '^(?:source:[0-9a-f]{40}:[^#;\r\n>-]+#[A-Za-z][A-Za-z0-9_.:-]*|diff:[0-9a-f]{40}\.\.[0-9a-f]{40}:[^#;\r\n>-]+(?:->[^#;\r\n>-]+)?#[A-Za-z][A-Za-z0-9_.:-]*)$') { $errors.Add('responsibility-evidence-missing'); $treePass = $false; $verificationPass = $false }
+      $canonicalEvidence = ConvertTo-ArcCanonicalReviewEvidenceItem -EvidenceItem $evidence
+      if ($canonicalEvidence -ceq '' -or $canonicalEvidence -cne $evidence) { $errors.Add('responsibility-evidence-missing'); $treePass = $false; $verificationPass = $false }
     }
     $rowPass = (Test-ArcExactSet -Actual @(& $splitList $review['Actual Public Symbols']) -Expected $sourceSymbols) -and $review['Actual Effects'] -ceq ($sourceEffects -join '; ')
     $expectedRowVerdict = if ($rowPass) { 'PASS' } else { 'BLOCKED' }
     if ($review['Verdict'] -cne $expectedRowVerdict) { $errors.Add('responsibility-waiver-forbidden'); $responsibilityPass = $false }
   }
   if ($deletedById.Count -gt 0) {
     $deviationColumns = @('Deviation Reference', 'Concern', 'Conflict Reference', 'Resolved Decision', 'Tech Lead Approval')
     $deviationTable = @(Get-ArcStrictMarkdownTable -Text $DesignText -Heading 'Approved Structural Deviations' -Columns $deviationColumns -Errors $errors)
     $deviationRows = if ($deviationTable.Count -ge 3) { @($deviationTable | Select-Object -Skip 2 | ForEach-Object { & $toRow $_ $deviationColumns }) } else { @() }
     $joinDeletionValues = { param([object]$Values) $items = @($Values | Select-Object -Unique); if ($items.Count -eq 0) { return 'not-applicable' }; return ($items -join ',') }
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/scope-engine.validation.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/scope-engine.validation.ps1
index c5fc453..16004bc 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/scope-engine.validation.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/scope-engine.validation.ps1
@@ -504,40 +504,20 @@ function Test-ScopeEngine([string]$Root, [string]$ContractText) {
       if ($null -ne $planWideResponsibilityBlock) { return $planWideResponsibilityBlock }
 
       $dependencyIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
       foreach ($item in $items) {
         foreach ($dependency in @($item.dependencies)) {
           if (-not [string]::IsNullOrWhiteSpace([string]$dependency) -and [string]$dependency -cne 'none') {
             [void]$dependencyIds.Add([string]$dependency)
           }
         }
       }
-      foreach ($dependencyId in $dependencyIds) {
-        $dependencyItem = $itemById[$dependencyId]
-        if (
-          [string]$dependencyItem.status -ceq 'complete' -and
-          (
-            [string]::IsNullOrWhiteSpace([string]$dependencyItem.terminal_evidence) -or
-            [string]$dependencyItem.terminal_evidence -ceq 'none' -or
-            -not (& $testTerminalResponsibilityAuthority $dependencyItem ([string]$dependencyItem.terminal_evidence))
-          )
-        ) {
-          return [pscustomobject]@{
-            result = 'scope-blocked'
-            reason = 'terminal-responsibility-authority-invalid'
-            scope_status = 'scope-blocked'
-            work_item_id = ''
-            reconciled_work_item_id = ''
-          }
-        }
-      }
-
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
@@ -555,20 +535,40 @@ function Test-ScopeEngine([string]$Root, [string]$ContractText) {
             reason = 'non-terminal-attempt'
             scope_status = 'scope-in-progress'
             work_item_id = [string]$inProgressItem.work_item_id
             adapter_kind = [string]$inProgressItem.adapter_kind
             migration_unit_id = if ($inProgressItem.adapter_kind -ceq 'migration-unit') { [string]$inProgressItem.external_id } else { 'not-applicable' }
             reconciled_work_item_id = ''
           }
         }
       }
 
+      foreach ($dependencyId in $dependencyIds) {
+        $dependencyItem = $itemById[$dependencyId]
+        if (
+          [string]$dependencyItem.status -ceq 'complete' -and
+          (
+            [string]::IsNullOrWhiteSpace([string]$dependencyItem.terminal_evidence) -or
+            [string]$dependencyItem.terminal_evidence -ceq 'none' -or
+            -not (& $testTerminalResponsibilityAuthority $dependencyItem ([string]$dependencyItem.terminal_evidence))
+          )
+        ) {
+          return [pscustomobject]@{
+            result = 'scope-blocked'
+            reason = 'terminal-responsibility-authority-invalid'
+            scope_status = 'scope-blocked'
+            work_item_id = ''
+            reconciled_work_item_id = $reconciledWorkItemId
+          }
+        }
+      }
+
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

# Review package: e80ca585f6cc9b1dedf6bc988b0fc984225a1f8e..8b0b73dd01d0dd2815118377d26f85e0ca11fcef

## Commits
8b0b73d test: cover responsibility conformance workflow

## Files changed
 .../scenarios/responsibility-conformance.Tests.ps1 | 121 +++++++++++++++++++++
 .../responsibility-conformance.validation.ps1      |  61 ++++++++++-
 2 files changed, 179 insertions(+), 3 deletions(-)

## Diff
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1
index 456d7fe..64a5557 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1
@@ -73,20 +73,83 @@ $stageCases = @(
   [pscustomobject]@{ Name = 'HANDOFF'; Invoke = { param($text) Test-ResponsibilityHandoff -SourceText '' -TargetText '' -ContractText $text } }
 )
 foreach ($stageCase in $stageCases) {
   $stageErrors = @(& $stageCase.Invoke $rawVersionBody)
   $expected = "ARC-$($stageCase.Name)-CONTRACT-VERSION: responsibility contract requires version 1 and applicability required"
   if ($stageErrors -notcontains $expected) {
     throw "Expected bounded-front-matter diagnostic for $($stageCase.Name): $($stageErrors -join '; ')"
   }
 }
 
+function Get-TestH2SectionMatch {
+  param([string]$Text, [string]$Heading)
+
+  $pattern = '(?ms)^##[ \t]+' + [regex]::Escape($Heading) + '[ \t]*\r?\n.*?(?=^##[ \t]+|\z)'
+  $matches = @([regex]::Matches($Text, $pattern))
+  if ($matches.Count -ne 1) { throw "Expected one test section for $Heading, found $($matches.Count)" }
+  return $matches[0]
+}
+
+function Add-TestH2SectionDuplicate {
+  param(
+    [string]$Text,
+    [string]$Heading,
+    [ValidateSet('before','after')][string]$Position,
+    [ValidateSet('exact','malformed','conflicting')][string]$CopyKind = 'exact',
+    [string]$ConflictFrom = '',
+    [string]$ConflictTo = ''
+  )
+
+  $section = Get-TestH2SectionMatch -Text $Text -Heading $Heading
+  $copy = $section.Value
+  $lineEnding = if ($copy.Contains("`r`n")) { "`r`n" } else { "`n" }
+  $headingLine = [regex]::Match($copy, '\A[^\r\n]+\r?\n')
+  if (-not $headingLine.Success) { throw "Cannot locate heading line for $Heading" }
+  $copy = $copy.Insert($headingLine.Length, "### duplicate-$Position test scope$lineEnding$lineEnding")
+  if ($CopyKind -ceq 'malformed') {
+    $separator = [regex]::Match($copy, '(?m)^\|(?:[ \t]*:?-{3,}:?[ \t]*\|)+\r?$')
+    if (-not $separator.Success) { throw "Cannot locate table separator for $Heading" }
+    $malformedSeparator = $separator.Value.Replace('-', '=')
+    $copy = $copy.Remove($separator.Index, $separator.Length).Insert($separator.Index, $malformedSeparator)
+  }
+  elseif ($CopyKind -ceq 'conflicting') {
+    if ([string]::IsNullOrEmpty($ConflictFrom)) { throw "Conflicting copy for $Heading requires a source value" }
+    $updatedCopy = $copy.Replace($ConflictFrom, $ConflictTo)
+    if ($updatedCopy -ceq $copy) { throw "Conflicting copy mutation was a silent no-op for $Heading" }
+    $copy = $updatedCopy
+  }
+  $replacement = if ($Position -ceq 'before') { $copy + $section.Value } else { $section.Value + $copy }
+  return $Text.Remove($section.Index, $section.Length).Insert($section.Index, $replacement)
+}
+
+function Add-TestHeadingCodeExample {
+  param([string]$Text, [string]$Heading)
+
+  $section = Get-TestH2SectionMatch -Text $Text -Heading $Heading
+  $lineEnding = if ($Text.Contains("`r`n")) { "`r`n" } else { "`n" }
+  $example = @(
+    "Prose mention of $Heading is not a heading.",
+    "### $Heading",
+    "> ## $Heading",
+    '```markdown',
+    "## $Heading",
+    '| code | example |',
+    '```',
+    ''
+  ) -join $lineEnding
+  return $Text.Insert($section.Index, $example + $lineEnding)
+}
+
+function Convert-TestLineEndings([string]$Text, [string]$NewLine) {
+  return [regex]::Replace($Text, '\r?\n', $NewLine)
+}
+
 $missingDiscoveryErrors = @(Test-ResponsibilityDiscovery -DiscoveryText '' -Mode incremental -ContractText $contract)
 if ($missingDiscoveryErrors -notcontains 'responsibility-discovery-missing') {
   throw "Empty discovery evidence must be rejected: $($missingDiscoveryErrors -join '; ')"
 }
 
 $discoveryConcerns = @(
   'module/container composition',
   'main/child presentation boundaries',
   'unit/component organization',
   'controller/provider/state pattern',
@@ -486,20 +549,36 @@ Assert-DesignAccepted 'shared engine owns shared capability only' $sharedFoundat
 
 $debtExemplarDesign = New-ResponsibilityDesignFixture -ExemplarClassification 'legacy-debt' -ClassificationAuthority 'debt-record' -ClassificationEvidence 'debt-record:DEBT-ADMIN-001'
 Assert-DesignRejected 'legacy debt cannot be propagated' $debtExemplarDesign 'debt-exemplar-propagation'
 
 $atomicDesign = New-ResponsibilityDesignFixture -CoLocationPolicy 'atomic-owner' -AtomicBoundaryId 'ATOM-ADMIN-LOCK' -CoLocationEvidence 'shared transaction lifecycle test and revert boundary; approval:TECH-LEAD-ADMIN-LOCK'
 Assert-DesignAccepted 'approved atomic owner' $atomicDesign
 
 $duplicateMatrix = $featureLocalDesign + "`n`n" + [regex]::Match($featureLocalDesign, '(?s)## File Responsibility Matrix.*?(?=## Verification Ownership Matrix)').Value
 Assert-DesignRejected 'duplicate responsibility matrix is rejected' $duplicateMatrix 'responsibility-owner-extra'
 
+foreach ($lineEndingCase in @(
+  [pscustomobject]@{ Name = 'LF'; NewLine = "`n" }
+  [pscustomobject]@{ Name = 'CRLF'; NewLine = "`r`n" }
+)) {
+  $designWithLineEndings = Convert-TestLineEndings $featureLocalDesign $lineEndingCase.NewLine
+  Assert-DesignAccepted "canonical single Planned File Tree is accepted ($($lineEndingCase.Name))" $designWithLineEndings
+  foreach ($position in @('before', 'after')) {
+    $duplicateTree = Add-TestH2SectionDuplicate -Text $designWithLineEndings -Heading 'Planned File Tree' -Position $position
+    Assert-DesignRejected "Planned File Tree rejects a duplicate $position the canonical section ($($lineEndingCase.Name))" $duplicateTree 'ARC-CONTRACT-HEADING-CARDINALITY: Planned File Tree'
+  }
+  $malformedSecondTree = Add-TestH2SectionDuplicate -Text $designWithLineEndings -Heading 'Planned File Tree' -Position after -CopyKind malformed
+  Assert-DesignRejected "Planned File Tree rejects a malformed second copy ($($lineEndingCase.Name))" $malformedSecondTree 'ARC-CONTRACT-HEADING-CARDINALITY: Planned File Tree'
+  Assert-DesignAccepted "Planned File Tree ignores prose, H3, blockquote, and fenced-code mentions ($($lineEndingCase.Name))" `
+    (Add-TestHeadingCodeExample -Text $designWithLineEndings -Heading 'Planned File Tree')
+}
+
 $selfLabeledTestOwner = $featureLocalDesign.Replace('| ui/admin_panel.dart | AdminPanel | presentation |', '| ui/admin_panel.dart | AdminPanel | test |')
 Assert-DesignRejected 'production owner cannot self-label as test to evade verification' $selfLabeledTestOwner 'verification-owner-missing'
 
 $invalidVerificationVerdict = $featureLocalDesign.Replace('| PASS | not-applicable |', '| UNKNOWN | not-applicable |')
 Assert-DesignRejected 'verification verdict must be canonical' $invalidVerificationVerdict 'verification-disposition-invalid'
 
 foreach ($eligibleCase in @(
   [pscustomobject]@{ Name = 'config'; Path = 'config/admin_lock.yaml'; Primary = 'declare admin lock configuration'; Kind = 'static-structure' }
   [pscustomobject]@{ Name = 'manifest'; Path = 'manifests/admin_lock.yaml'; Primary = 'declare deployment manifest'; Kind = 'static-structure' }
   [pscustomobject]@{ Name = 'generated'; Path = 'generated/admin_lock.g.dart'; Primary = 'emit generated configuration'; Kind = 'generator-verification' }
@@ -1091,20 +1170,47 @@ $canonicalEnvelopeReview = New-ResponsibilityReviewFixture -PinnedSource $validR
 Assert-ReviewRejected 'review envelope rejects a substituted run' ($canonicalEnvelopeReview.Replace('RUN-ADMIN-001', 'RUN-FOREIGN-001')) 'responsibility-evidence-missing'
 Assert-ReviewRejected 'review envelope rejects a substituted work item' ($canonicalEnvelopeReview.Replace('WORK-ADMIN-LOCK', 'WORK-FOREIGN')) 'responsibility-evidence-missing'
 Assert-ReviewRejected 'review envelope rejects a substituted delivery adapter' ($canonicalEnvelopeReview.Replace('- Delivery Adapter Kind: none', '- Delivery Adapter Kind: task')) 'responsibility-evidence-missing'
 Assert-ReviewRejected 'review envelope rejects a substituted final-tree SHA' ($canonicalEnvelopeReview.Replace($validReviewSource.FinalTreeSha, '4444444444444444444444444444444444444444')) 'responsibility-evidence-missing'
 Assert-ReviewRejected 'review envelope rejects a substituted source artifact' ($canonicalEnvelopeReview.Replace('implementation-report.md', 'other-implementation.md')) 'responsibility-evidence-missing'
 Assert-ReviewRejected 'review envelope rejects stale source-diff evidence' ($canonicalEnvelopeReview.Replace("source-diff:$($validReviewSource.TaskBaseSha)..$($validReviewSource.FinalTreeSha)#WORK-ADMIN-LOCK", "source-diff:$($validReviewSource.TaskBaseSha)..3333333333333333333333333333333333333333#WORK-ADMIN-LOCK")) 'responsibility-evidence-missing'
 Assert-ReviewRejected 'review envelope rejects a non-v1 responsibility handoff' ($canonicalEnvelopeReview.Replace('| 1 | PASS | PASS | PASS | PASS | source-diff:', '| 2 | PASS | PASS | PASS | PASS | source-diff:')) 'responsibility-contract-version-invalid'
 Assert-ReviewRejected 'review envelope rejects a cross-plan implementation context' $canonicalEnvelopeReview 'responsibility-evidence-missing' -ImplementationText ($validImplementation.Replace('PLAN-ADMIN-001', 'PLAN-FOREIGN-001'))
 Assert-ReviewRejected 'review envelope rejects an unapproved substituted plan authority' $canonicalEnvelopeReview 'responsibility-evidence-missing' -ApprovedPlanText ($script:validReviewPlan.Replace('status: approved', 'status: draft'))
 Assert-ReviewAccepted 'review resolves unchanged verification evidence from the pinned final tree' $canonicalEnvelopeReview
+foreach ($lineEndingCase in @(
+  [pscustomobject]@{ Name = 'LF'; NewLine = "`n" }
+  [pscustomobject]@{ Name = 'CRLF'; NewLine = "`r`n" }
+)) {
+  $reviewWithLineEndings = Convert-TestLineEndings $canonicalEnvelopeReview $lineEndingCase.NewLine
+  Assert-ReviewAccepted "canonical single review envelope headings are accepted ($($lineEndingCase.Name))" $reviewWithLineEndings
+  foreach ($heading in @('Master Scope Context', 'Task Provenance', 'Architecture Responsibility Handoff', 'Responsibility Review Evidence')) {
+    foreach ($position in @('before', 'after')) {
+      $duplicateReviewSection = Add-TestH2SectionDuplicate -Text $reviewWithLineEndings -Heading $heading -Position $position
+      Assert-ReviewRejected "$heading rejects a duplicate $position the canonical section ($($lineEndingCase.Name))" $duplicateReviewSection "ARC-CONTRACT-HEADING-CARDINALITY: $heading"
+    }
+    $malformedSecondSection = Add-TestH2SectionDuplicate -Text $reviewWithLineEndings -Heading $heading -Position after -CopyKind malformed
+    Assert-ReviewRejected "$heading rejects a malformed second copy ($($lineEndingCase.Name))" $malformedSecondSection "ARC-CONTRACT-HEADING-CARDINALITY: $heading"
+    Assert-ReviewAccepted "$heading ignores prose, H3, blockquote, and fenced-code mentions ($($lineEndingCase.Name))" `
+      (Add-TestHeadingCodeExample -Text $reviewWithLineEndings -Heading $heading)
+  }
+  $conflictingReviewEvidence = Add-TestH2SectionDuplicate -Text $reviewWithLineEndings -Heading 'Responsibility Review Evidence' -Position after -CopyKind conflicting -ConflictFrom '| AdminWifi | AdminWifi | none | none | PASS |' -ConflictTo '| AdminWifi | AdminWifiConflict | none | none | BLOCKED |'
+  Assert-ReviewRejected "Responsibility Review Evidence rejects a conflicting second copy ($($lineEndingCase.Name))" $conflictingReviewEvidence 'ARC-CONTRACT-HEADING-CARDINALITY: Responsibility Review Evidence'
+
+  $adapterLine = '- Delivery Adapter Kind: none'
+  foreach ($position in @('before', 'after')) {
+    $duplicateAdapter = $reviewWithLineEndings.Replace($adapterLine, "$adapterLine$($lineEndingCase.NewLine)$adapterLine")
+    Assert-ReviewRejected "Delivery Adapter Kind rejects a duplicate $position the canonical line ($($lineEndingCase.Name))" $duplicateAdapter 'responsibility-evidence-missing'
+  }
+  $malformedSecondAdapter = $reviewWithLineEndings.Replace($adapterLine, "$adapterLine$($lineEndingCase.NewLine)- Delivery Adapter Kind: unsupported")
+  Assert-ReviewRejected "Delivery Adapter Kind rejects a malformed second line ($($lineEndingCase.Name))" $malformedSecondAdapter 'responsibility-evidence-missing'
+}
 foreach ($verificationCase in @(
   [pscustomobject]@{ Variant = 'missing-path'; Name = 'missing verification evidence path' }
   [pscustomobject]@{ Variant = 'missing-scenario'; Name = 'missing verification scenario' }
   [pscustomobject]@{ Variant = 'foreign-owner'; Name = 'foreign verification owner binding' }
   [pscustomobject]@{ Variant = 'stale-scenario'; Name = 'stale verification scenario in the final tree' }
   [pscustomobject]@{ Variant = 'self-attested'; Name = 'self-attested verification binding' }
   [pscustomobject]@{ Variant = 'fake-registry'; Name = 'test-only fake production registry' }
   [pscustomobject]@{ Variant = 'fake-provider'; Name = 'fake provider instead of real production composition' }
 )) {
   $variantSource = New-ResponsibilityReviewSourceFixture -VerificationVariant $verificationCase.Variant
@@ -1127,20 +1233,35 @@ $migrationSelectedUnitBlock = @"
 $noneImplementationSelectorRow = '| WORK-ADMIN-LOCK | none | not-applicable | not-applicable | not-applicable | not-applicable | not-applicable | REQ-101; SC-101; completes within 2 seconds | REQ-101 | incremental/preserve-existing | DESIGN-ADMIN@2 | not-applicable | not-applicable | PASS |'
 $migrationImplementation = $validImplementation.Replace($noneImplementationSelectorRow, $migrationImplementationSelectorRow).Replace('## Actual File Responsibility Matrix', "$migrationSelectedUnitBlock## Actual File Responsibility Matrix")
 $changeHygieneRow = "| WORK-ADMIN-LOCK | ui/admin_wifi.dart | existing | AdminWifi | none | none | none | $($validReviewSource.TaskBaseSha) | $($validReviewSource.FinalTreeSha) |"
 $migrationImplementation = $migrationImplementation.Replace($changeHygieneRow, $changeHygieneRow.Replace('WORK-ADMIN-LOCK', 'UNIT-ADMIN-LOCK'))
 $migrationPlan = $script:validReviewPlan.Replace('| WORK-ADMIN-LOCK | none | not-applicable | not-applicable | not-applicable | not-applicable | not-applicable | REQ-101; SC-101; completes within 2 seconds | REQ-101 | incremental/preserve-existing | DESIGN-ADMIN@2 | not-applicable | not-applicable |', $migrationSelectorRow).Replace('| REQ-101 | none | in-progress |', '| REQ-101 | migration-unit:UNIT-ADMIN-LOCK | in-progress |')
 $migrationReview = $canonicalEnvelopeReview.Replace('- Delivery Adapter Kind: none', '- Delivery Adapter Kind: migration-unit').Replace('| WORK-ADMIN-LOCK | ' + $validReviewSource.TaskBaseSha + ' |', '| UNIT-ADMIN-LOCK | ' + $validReviewSource.TaskBaseSha + ' |').Replace('## Architecture Conformance', "$migrationSelectedUnitBlock## Architecture Conformance")
 $migrationImplementationDiagnostics = @(Test-ResponsibilityImplementation -DesignText $validReviewDesign -ImplementationText $migrationImplementation -ContractText $contract)
 if ($migrationImplementationDiagnostics.Count -ne 0) { throw "migration implementation envelope should pass but got: $($migrationImplementationDiagnostics -join '; ')" }
 Write-Output 'PASS: migration implementation preserves canonical Authority@Revision selected row'
 Assert-ReviewAccepted 'migration review preserves the exact implementation selected row and approved selector authority' $migrationReview $validReviewDesign $migrationImplementation $validReviewSource $migrationPlan
+foreach ($lineEndingCase in @(
+  [pscustomobject]@{ Name = 'LF'; NewLine = "`n" }
+  [pscustomobject]@{ Name = 'CRLF'; NewLine = "`r`n" }
+)) {
+  $migrationReviewWithLineEndings = Convert-TestLineEndings $migrationReview $lineEndingCase.NewLine
+  $migrationImplementationWithLineEndings = Convert-TestLineEndings $migrationImplementation $lineEndingCase.NewLine
+  $migrationPlanWithLineEndings = Convert-TestLineEndings $migrationPlan $lineEndingCase.NewLine
+  Assert-ReviewAccepted "canonical conditional Selected Migration Unit is accepted ($($lineEndingCase.Name))" $migrationReviewWithLineEndings $validReviewDesign $migrationImplementationWithLineEndings $validReviewSource $migrationPlanWithLineEndings
+  foreach ($position in @('before', 'after')) {
+    $duplicateSelectedUnit = Add-TestH2SectionDuplicate -Text $migrationReviewWithLineEndings -Heading 'Selected Migration Unit' -Position $position
+    Assert-ReviewRejected "Selected Migration Unit rejects a duplicate $position the canonical section ($($lineEndingCase.Name))" $duplicateSelectedUnit 'responsibility-evidence-missing' -ImplementationText $migrationImplementationWithLineEndings -ApprovedPlanText $migrationPlanWithLineEndings
+  }
+  $malformedSecondSelectedUnit = Add-TestH2SectionDuplicate -Text $migrationReviewWithLineEndings -Heading 'Selected Migration Unit' -Position after -CopyKind malformed
+  Assert-ReviewRejected "Selected Migration Unit rejects a malformed second copy ($($lineEndingCase.Name))" $malformedSecondSelectedUnit 'responsibility-evidence-missing' -ImplementationText $migrationImplementationWithLineEndings -ApprovedPlanText $migrationPlanWithLineEndings
+}
 $staleMigrationImplementationDiagnostics = @(Test-ResponsibilityImplementation -DesignText $validReviewDesign -ImplementationText ($migrationImplementation.Replace('08-migration-plan.md@2', '08-migration-plan.md@1')) -ContractText $contract)
 if ($staleMigrationImplementationDiagnostics -notcontains 'responsibility-evidence-missing') { throw "stale implementation selected plan reference should be rejected but got: $($staleMigrationImplementationDiagnostics -join '; ')" }
 Write-Output 'PASS: migration implementation rejects stale selected Plan Reference'
 Assert-ReviewRejected 'migration review rejects a selected Plan Reference mismatch' ($migrationReview.Replace('08-migration-plan.md@2', '08-migration-plan.md@1')) 'responsibility-evidence-missing' -ImplementationText $migrationImplementation -ApprovedPlanText $migrationPlan
 
 $approvedMigrationReview = $migrationReview.Replace('status: draft', "status: approved`napproval_source: human")
 $migrationVerification = @"
 ---
 step_id: 12-verification-testing
 status: draft
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1
index dd11148..a637515 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1
@@ -23,35 +23,90 @@ function Test-ArcExactSet {
     [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Expected
   )
 
   if ($Actual.Count -ne $Expected.Count) { return $false }
   for ($index = 0; $index -lt $Expected.Count; $index++) {
     if ($Actual[$index] -cne $Expected[$index]) { return $false }
   }
   return $true
 }
 
+function Get-ArcMarkdownH2HeadingMatches {
+  [CmdletBinding()]
+  param(
+    [Parameter(Mandatory)][string]$Text,
+    [Parameter(Mandatory)][string]$Heading
+  )
+
+  $headingMatches = [Collections.Generic.List[object]]::new()
+  $insideFence = $false
+  $fenceCharacter = ''
+  $fenceLength = 0
+  foreach ($lineMatch in @([regex]::Matches($Text, '(?m)^[^\r\n]*(?:\r\n|\n|$)'))) {
+    if ($lineMatch.Length -eq 0) { continue }
+    $line = $lineMatch.Value
+    if ($line.EndsWith("`r`n", [StringComparison]::Ordinal)) {
+      $line = $line.Substring(0, $line.Length - 2)
+    }
+    elseif ($line.EndsWith("`n", [StringComparison]::Ordinal)) {
+      $line = $line.Substring(0, $line.Length - 1)
+    }
+
+    if ($insideFence) {
+      $closingPattern = '^[ ]{0,3}' + [regex]::Escape($fenceCharacter) + '{' + $fenceLength + ',}[ \t]*$'
+      if ($line -cmatch $closingPattern) {
+        $insideFence = $false
+        $fenceCharacter = ''
+        $fenceLength = 0
+      }
+      continue
+    }
+
+    $openingFence = [regex]::Match($line, '^[ ]{0,3}(?<fence>`{3,}|~{3,}).*$')
+    if ($openingFence.Success) {
+      $insideFence = $true
+      $fenceCharacter = [string]$openingFence.Groups['fence'].Value[0]
+      $fenceLength = $openingFence.Groups['fence'].Value.Length
+      continue
+    }
+
+    $headingMatch = [regex]::Match($line, '^##[ \t]+' + [regex]::Escape($Heading) + '[ \t]*$')
+    if ($headingMatch.Success) {
+      $headingMatches.Add([pscustomobject]@{
+        Index = $lineMatch.Index + $headingMatch.Index
+        Length = $headingMatch.Length
+        Value = $headingMatch.Value
+      })
+    }
+  }
+  return $headingMatches.ToArray()
+}
+
 function Get-ArcStrictMarkdownTable {
   [CmdletBinding()]
   param(
     [Parameter(Mandatory)][string]$Text,
     [Parameter(Mandatory)][string]$Heading,
     [Parameter(Mandatory)][string[]]$Columns,
     [Parameter(Mandatory)][AllowEmptyCollection()][Collections.Generic.List[string]]$Errors
   )
 
-  $headingPattern = '(?m)^##\s+' + [regex]::Escape($Heading) + '\s*$'
-  $headingMatch = [regex]::Match($Text, $headingPattern)
-  if (-not $headingMatch.Success) {
+  $headingMatches = @(Get-ArcMarkdownH2HeadingMatches -Text $Text -Heading $Heading)
+  if ($headingMatches.Count -eq 0) {
     $Errors.Add("ARC-CONTRACT-MISSING-TABLE: $Heading")
     return @()
   }
+  if ($headingMatches.Count -ne 1) {
+    $Errors.Add("ARC-CONTRACT-HEADING-CARDINALITY: $Heading")
+    return @()
+  }
+  $headingMatch = $headingMatches[0]
   $remaining = $Text.Substring($headingMatch.Index + $headingMatch.Length)
   $lines = @($remaining -split '\r?\n')
   $tableLines = [Collections.Generic.List[string]]::new()
   foreach ($line in $lines) {
     if ([string]::IsNullOrWhiteSpace($line) -and $tableLines.Count -eq 0) { continue }
     if ($line -match '^##\s+') { break }
     if ($line -match '^\|') { $tableLines.Add($line); continue }
     if ($tableLines.Count -gt 0) { break }
   }
   if ($tableLines.Count -lt 3) {

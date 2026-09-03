# Review package: 8b0b73dd01d0dd2815118377d26f85e0ca11fcef..0a703bcc9812510643076ae3143713478ef4b873

## Commits
0a703bc test: cover responsibility conformance workflow

## Files changed
 .../tests/scenarios/architecture-review.Tests.ps1  |   2 +-
 .../scenarios/responsibility-conformance.Tests.ps1 | 351 ++++++++++++++++++++-
 .../scenarios/responsibility-handoff.Tests.ps1     |  42 ++-
 .../tests/validate-migration-framework.Tests.ps1   |   2 +-
 .../tests/validate-migration-framework.ps1         |   2 +-
 .../responsibility-conformance.validation.ps1      | 238 +++++++++-----
 6 files changed, 518 insertions(+), 119 deletions(-)

## Diff
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/architecture-review.Tests.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/architecture-review.Tests.ps1
index 8e1c50a..128f383 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/architecture-review.Tests.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/architecture-review.Tests.ps1
@@ -632,21 +632,21 @@ foreach ($lineEndingCase in @(
     $path = Join-Path $root 'artifacts/review-provenance.md'
     $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
     [IO.File]::WriteAllText($path, [regex]::Replace($text, '\r?\n', $lineEndingCase.NewLine), [Text.UTF8Encoding]::new($false))
     SubstituteReviewProvenanceFinalTree $root
   } 'responsibility-evidence-missing' $true
 
   Assert-FailsLike "review rejects missing implementation Change Hygiene provenance ($($lineEndingCase.Name))" {
     param($root)
     Set-ArtifactLineEndings $root 'artifacts/implementation-report.md' $lineEndingCase.NewLine "missing Change Hygiene ($($lineEndingCase.Name))"
     Remove-ImplementationChangeHygiene $root
-  } 'responsibility-evidence-missing' $true
+  } '^ARC-CONTRACT-MISSING-TABLE: Change Hygiene$' $true
 
   Assert-Pass "review accepts incremental owner edit whose declaration predates task base ($($lineEndingCase.Name))" {
     param($root)
     Set-ArtifactLineEndings $root 'artifacts/design-report.md' $lineEndingCase.NewLine "incremental owner edit ($($lineEndingCase.Name))"
     Set-ArtifactLineEndings $root 'artifacts/implementation-report.md' $lineEndingCase.NewLine "incremental owner edit ($($lineEndingCase.Name))"
     Set-ArtifactLineEndings $root 'artifacts/review-report.md' $lineEndingCase.NewLine "incremental owner edit ($($lineEndingCase.Name))"
     Set-ArtifactLineEndings $root 'artifacts/review-provenance.md' $lineEndingCase.NewLine "incremental owner edit ($($lineEndingCase.Name))"
     Add-LineEndingProbe $root $lineEndingCase.NewLine "incremental owner edit ($($lineEndingCase.Name))"
   } $true $true
 
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1
index 64a5557..01f6659 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1
@@ -110,21 +110,22 @@ function Add-TestH2SectionDuplicate {
     if (-not $separator.Success) { throw "Cannot locate table separator for $Heading" }
     $malformedSeparator = $separator.Value.Replace('-', '=')
     $copy = $copy.Remove($separator.Index, $separator.Length).Insert($separator.Index, $malformedSeparator)
   }
   elseif ($CopyKind -ceq 'conflicting') {
     if ([string]::IsNullOrEmpty($ConflictFrom)) { throw "Conflicting copy for $Heading requires a source value" }
     $updatedCopy = $copy.Replace($ConflictFrom, $ConflictTo)
     if ($updatedCopy -ceq $copy) { throw "Conflicting copy mutation was a silent no-op for $Heading" }
     $copy = $updatedCopy
   }
-  $replacement = if ($Position -ceq 'before') { $copy + $section.Value } else { $section.Value + $copy }
+  $sectionSeparator = if ($section.Value.EndsWith($lineEnding, [StringComparison]::Ordinal)) { '' } else { $lineEnding }
+  $replacement = if ($Position -ceq 'before') { $copy + $sectionSeparator + $section.Value } else { $section.Value + $sectionSeparator + $copy }
   return $Text.Remove($section.Index, $section.Length).Insert($section.Index, $replacement)
 }
 
 function Add-TestHeadingCodeExample {
   param([string]$Text, [string]$Heading)
 
   $section = Get-TestH2SectionMatch -Text $Text -Heading $Heading
   $lineEnding = if ($Text.Contains("`r`n")) { "`r`n" } else { "`n" }
   $example = @(
     "Prose mention of $Heading is not a heading.",
@@ -132,24 +133,112 @@ function Add-TestHeadingCodeExample {
     "> ## $Heading",
     '```markdown',
     "## $Heading",
     '| code | example |',
     '```',
     ''
   ) -join $lineEnding
   return $Text.Insert($section.Index, $example + $lineEnding)
 }
 
+function Add-TestCommentedH2SectionDuplicate {
+  param(
+    [string]$Text,
+    [string]$Heading,
+    [ValidateSet('before','after')][string]$Position
+  )
+
+  $section = Get-TestH2SectionMatch -Text $Text -Heading $Heading
+  $lineEnding = if ($Text.Contains("`r`n")) { "`r`n" } else { "`n" }
+  $commentedCopy = "<!--$lineEnding$($section.Value)-->$lineEnding"
+  $insertionIndex = if ($Position -ceq 'before') { $section.Index } else { $section.Index + $section.Length }
+  return $Text.Insert($insertionIndex, $commentedCopy)
+}
+
+function Convert-TestH2SectionToCommentOnly {
+  param([string]$Text, [string]$Heading)
+
+  $section = Get-TestH2SectionMatch -Text $Text -Heading $Heading
+  $lineEnding = if ($Text.Contains("`r`n")) { "`r`n" } else { "`n" }
+  $commentedSection = "<!--$lineEnding$($section.Value)-->$lineEnding"
+  return $Text.Remove($section.Index, $section.Length).Insert($section.Index, $commentedSection)
+}
+
+function Remove-TestH2Section {
+  param([string]$Text, [string]$Heading)
+
+  $section = Get-TestH2SectionMatch -Text $Text -Heading $Heading
+  return $Text.Remove($section.Index, $section.Length)
+}
+
+function Add-TestFencedH2SectionExample {
+  param(
+    [string]$Text,
+    [string]$Heading,
+    [ValidateSet('`','~')][char]$FenceCharacter,
+    [int]$OpeningLength,
+    [int]$ClosingLength,
+    [string]$InfoString = '',
+    [string]$ClosingSuffix = ''
+  )
+
+  $section = Get-TestH2SectionMatch -Text $Text -Heading $Heading
+  $lineEnding = if ($Text.Contains("`r`n")) { "`r`n" } else { "`n" }
+  $openingFence = [string]::new($FenceCharacter, $OpeningLength) + $InfoString
+  $closingFence = [string]::new($FenceCharacter, $ClosingLength) + $ClosingSuffix
+  $example = "$openingFence$lineEnding$($section.Value)$closingFence$lineEnding"
+  return $Text.Insert($section.Index, $example)
+}
+
 function Convert-TestLineEndings([string]$Text, [string]$NewLine) {
   return [regex]::Replace($Text, '\r?\n', $NewLine)
 }
 
+function Replace-TestFixtureText([string]$Text, [string]$OldValue, [string]$NewValue, [string]$Context) {
+  $updated = $Text.Replace($OldValue, $NewValue)
+  if ($updated -ceq $Text) { throw "$Context fixture replacement failed" }
+  return $updated
+}
+
+function Assert-TestExactDiagnostics {
+  param(
+    [string]$Name,
+    [AllowEmptyCollection()][string[]]$Actual,
+    [AllowEmptyCollection()][string[]]$Expected
+  )
+
+  if ($Actual.Count -ne $Expected.Count) {
+    throw "$Name expected exactly $($Expected.Count) diagnostic(s) [$($Expected -join '; ')] but got $($Actual.Count) [$($Actual -join '; ')]"
+  }
+  for ($index = 0; $index -lt $Expected.Count; $index++) {
+    if ($Actual[$index] -cne $Expected[$index]) {
+      throw "$Name diagnostic $index expected exact <$($Expected[$index])> but got <$($Actual[$index])>; full list: $($Actual -join '; ')"
+    }
+  }
+  Write-Output "PASS: $Name"
+}
+
+foreach ($lineEndingCase in @(
+  [pscustomobject]@{ Name = 'LF'; NewLine = "`n" }
+  [pscustomobject]@{ Name = 'CRLF'; NewLine = "`r`n" }
+)) {
+  $contractWithLineEndings = Convert-TestLineEndings $contract $lineEndingCase.NewLine
+  $duplicateContractMatrix = Add-TestH2SectionDuplicate -Text $contractWithLineEndings -Heading 'File Responsibility Matrix' -Position after
+  Assert-TestExactDiagnostics "contract schema emits only the exact File Responsibility Matrix duplicate diagnostic ($($lineEndingCase.Name))" `
+    @(Test-ResponsibilityContractSchema -ContractText $duplicateContractMatrix) `
+    @('ARC-CONTRACT-HEADING-CARDINALITY: File Responsibility Matrix')
+  $missingContractMatrix = Remove-TestH2Section -Text $contractWithLineEndings -Heading 'File Responsibility Matrix'
+  Assert-TestExactDiagnostics "contract schema emits only the exact File Responsibility Matrix missing diagnostic ($($lineEndingCase.Name))" `
+    @(Test-ResponsibilityContractSchema -ContractText $missingContractMatrix) `
+    @('ARC-CONTRACT-MISSING-TABLE: File Responsibility Matrix')
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
@@ -547,36 +636,121 @@ Assert-DesignRejected 'design requires canonical approved revision' $designWitho
 $sharedFoundationDesign = New-ResponsibilityDesignFixture -CoLocationPolicy 'shared-foundation' -CoLocationEvidence 'shared engine capability with no concrete registration or feature effect'
 Assert-DesignAccepted 'shared engine owns shared capability only' $sharedFoundationDesign
 
 $debtExemplarDesign = New-ResponsibilityDesignFixture -ExemplarClassification 'legacy-debt' -ClassificationAuthority 'debt-record' -ClassificationEvidence 'debt-record:DEBT-ADMIN-001'
 Assert-DesignRejected 'legacy debt cannot be propagated' $debtExemplarDesign 'debt-exemplar-propagation'
 
 $atomicDesign = New-ResponsibilityDesignFixture -CoLocationPolicy 'atomic-owner' -AtomicBoundaryId 'ATOM-ADMIN-LOCK' -CoLocationEvidence 'shared transaction lifecycle test and revert boundary; approval:TECH-LEAD-ADMIN-LOCK'
 Assert-DesignAccepted 'approved atomic owner' $atomicDesign
 
 $duplicateMatrix = $featureLocalDesign + "`n`n" + [regex]::Match($featureLocalDesign, '(?s)## File Responsibility Matrix.*?(?=## Verification Ownership Matrix)').Value
-Assert-DesignRejected 'duplicate responsibility matrix is rejected' $duplicateMatrix 'responsibility-owner-extra'
+Assert-TestExactDiagnostics 'duplicate responsibility matrix emits only its exact cardinality diagnostic' `
+  @(Test-ResponsibilityDesign -DiscoveryText (New-DiscoveryClassificationFixture) -DesignText $duplicateMatrix -Mode incremental -ContractText $contract) `
+  @('ARC-CONTRACT-HEADING-CARDINALITY: File Responsibility Matrix')
 
 foreach ($lineEndingCase in @(
   [pscustomobject]@{ Name = 'LF'; NewLine = "`n" }
   [pscustomobject]@{ Name = 'CRLF'; NewLine = "`r`n" }
 )) {
   $designWithLineEndings = Convert-TestLineEndings $featureLocalDesign $lineEndingCase.NewLine
   Assert-DesignAccepted "canonical single Planned File Tree is accepted ($($lineEndingCase.Name))" $designWithLineEndings
+  $duplicateResponsibilityMatrix = Add-TestH2SectionDuplicate -Text $designWithLineEndings -Heading 'File Responsibility Matrix' -Position after
+  Assert-TestExactDiagnostics "design emits only the exact File Responsibility Matrix duplicate diagnostic ($($lineEndingCase.Name))" `
+    @(Test-ResponsibilityDesign -DiscoveryText (New-DiscoveryClassificationFixture) -DesignText $duplicateResponsibilityMatrix -Mode incremental -ContractText $contract) `
+    @('ARC-CONTRACT-HEADING-CARDINALITY: File Responsibility Matrix')
+  $missingResponsibilityMatrix = Remove-TestH2Section -Text $designWithLineEndings -Heading 'File Responsibility Matrix'
+  Assert-TestExactDiagnostics "design emits only the exact File Responsibility Matrix missing diagnostic ($($lineEndingCase.Name))" `
+    @(Test-ResponsibilityDesign -DiscoveryText (New-DiscoveryClassificationFixture) -DesignText $missingResponsibilityMatrix -Mode incremental -ContractText $contract) `
+    @('ARC-CONTRACT-MISSING-TABLE: File Responsibility Matrix')
   foreach ($position in @('before', 'after')) {
     $duplicateTree = Add-TestH2SectionDuplicate -Text $designWithLineEndings -Heading 'Planned File Tree' -Position $position
-    Assert-DesignRejected "Planned File Tree rejects a duplicate $position the canonical section ($($lineEndingCase.Name))" $duplicateTree 'ARC-CONTRACT-HEADING-CARDINALITY: Planned File Tree'
+    Assert-TestExactDiagnostics "Planned File Tree emits only its exact duplicate diagnostic $position the canonical section ($($lineEndingCase.Name))" `
+      @(Test-ResponsibilityDesign -DiscoveryText (New-DiscoveryClassificationFixture) -DesignText $duplicateTree -Mode incremental -ContractText $contract) `
+      @('ARC-CONTRACT-HEADING-CARDINALITY: Planned File Tree')
+  }
+  foreach ($position in @('before', 'after')) {
+    $malformedSecondTree = Add-TestH2SectionDuplicate -Text $designWithLineEndings -Heading 'Planned File Tree' -Position $position -CopyKind malformed
+    Assert-TestExactDiagnostics "Planned File Tree emits only its exact malformed-copy diagnostic $position the canonical section ($($lineEndingCase.Name))" `
+      @(Test-ResponsibilityDesign -DiscoveryText (New-DiscoveryClassificationFixture) -DesignText $malformedSecondTree -Mode incremental -ContractText $contract) `
+      @('ARC-CONTRACT-HEADING-CARDINALITY: Planned File Tree')
   }
-  $malformedSecondTree = Add-TestH2SectionDuplicate -Text $designWithLineEndings -Heading 'Planned File Tree' -Position after -CopyKind malformed
-  Assert-DesignRejected "Planned File Tree rejects a malformed second copy ($($lineEndingCase.Name))" $malformedSecondTree 'ARC-CONTRACT-HEADING-CARDINALITY: Planned File Tree'
   Assert-DesignAccepted "Planned File Tree ignores prose, H3, blockquote, and fenced-code mentions ($($lineEndingCase.Name))" `
     (Add-TestHeadingCodeExample -Text $designWithLineEndings -Heading 'Planned File Tree')
+  foreach ($position in @('before', 'after')) {
+    $commentedTree = Add-TestCommentedH2SectionDuplicate -Text $designWithLineEndings -Heading 'Planned File Tree' -Position $position
+    Assert-DesignAccepted "Planned File Tree ignores a multiline HTML-comment duplicate $position the canonical section ($($lineEndingCase.Name))" $commentedTree
+  }
+  $inlineHeadingComment = Replace-TestFixtureText $designWithLineEndings '## Planned File Tree' '## Planned<!-- parser note --> File Tree' 'inline heading comment'
+  Assert-DesignAccepted "Planned File Tree ignores a single-line inline HTML comment in the canonical heading ($($lineEndingCase.Name))" $inlineHeadingComment
+  $spacedInlineHeadingComment = Replace-TestFixtureText $designWithLineEndings '## Planned File Tree' '## Planned <!-- parser note --> File Tree' 'spaced inline heading comment'
+  Assert-DesignAccepted "Planned File Tree normalizes whitespace around an ignored inline HTML comment ($($lineEndingCase.Name))" $spacedInlineHeadingComment
+  $inlineTableComment = Replace-TestFixtureText $designWithLineEndings '| ui/admin_panel.dart | AdminPanel |' '| ui/admin_panel.dart | <!-- parser note --> AdminPanel |' 'inline table comment'
+  Assert-DesignAccepted "Planned File Tree ignores a single-line HTML comment in canonical table content ($($lineEndingCase.Name))" $inlineTableComment
+  $plannedTreeHeadingPrefix = "## Planned File Tree$($lineEndingCase.NewLine)$($lineEndingCase.NewLine)"
+  $commentedTableExample = Replace-TestFixtureText $designWithLineEndings $plannedTreeHeadingPrefix `
+    "$plannedTreeHeadingPrefix<!--$($lineEndingCase.NewLine)| hidden | table | example | only |$($lineEndingCase.NewLine)|---|---|---|---|$($lineEndingCase.NewLine)| fake | fake | fake | fake |$($lineEndingCase.NewLine)-->$($lineEndingCase.NewLine)" `
+    'multiline commented table'
+  Assert-DesignAccepted "Planned File Tree ignores a multiline HTML-comment table before canonical content ($($lineEndingCase.Name))" $commentedTableExample
+  $fencedTableExample = Replace-TestFixtureText $designWithLineEndings $plannedTreeHeadingPrefix `
+    "$plannedTreeHeadingPrefix~~~markdown$($lineEndingCase.NewLine)| hidden | table | example | only |$($lineEndingCase.NewLine)|---|---|---|---|$($lineEndingCase.NewLine)| fake | fake | fake | fake |$($lineEndingCase.NewLine)~~~~$($lineEndingCase.NewLine)" `
+    'fenced table'
+  Assert-DesignAccepted "Planned File Tree ignores a fenced table before canonical content ($($lineEndingCase.Name))" $fencedTableExample
+  $commentPrefixedTableExample = Replace-TestFixtureText $designWithLineEndings $plannedTreeHeadingPrefix `
+    "$plannedTreeHeadingPrefix<!-- parser note -->| Planned Path | Planned Symbol | Responsibility | Exemplar or Deviation Reference |$($lineEndingCase.NewLine)<!-- parser note -->|---|---|---|---|$($lineEndingCase.NewLine)<!-- parser note -->| hidden | fake | fake | fake |$($lineEndingCase.NewLine)" `
+    'comment-prefixed table marker'
+  Assert-DesignAccepted "HTML comment removal cannot move table markers to column zero ($($lineEndingCase.Name))" $commentPrefixedTableExample
+  $commentContinuationTableExample = Replace-TestFixtureText $designWithLineEndings $plannedTreeHeadingPrefix `
+    "$plannedTreeHeadingPrefix<!--$($lineEndingCase.NewLine)| hidden -->| Planned Path | Planned Symbol | Responsibility | Exemplar or Deviation Reference |$($lineEndingCase.NewLine)<!--$($lineEndingCase.NewLine)| hidden -->|---|---|---|---|$($lineEndingCase.NewLine)<!--$($lineEndingCase.NewLine)| hidden -->| hidden | fake | fake | fake |$($lineEndingCase.NewLine)" `
+    'multiline-comment continuation table marker'
+  Assert-DesignAccepted "multiline HTML comment removal cannot move table markers to column zero ($($lineEndingCase.Name))" $commentContinuationTableExample
+  $commentOnlyTree = Convert-TestH2SectionToCommentOnly -Text $designWithLineEndings -Heading 'Planned File Tree'
+  Assert-TestExactDiagnostics "comment-only Planned File Tree emits only its exact missing diagnostic ($($lineEndingCase.Name))" `
+    @(Test-ResponsibilityDesign -DiscoveryText (New-DiscoveryClassificationFixture) -DesignText $commentOnlyTree -Mode incremental -ContractText $contract) `
+    @('ARC-CONTRACT-MISSING-TABLE: Planned File Tree')
+  $splitHeadingAcrossCommentLines = Replace-TestFixtureText $designWithLineEndings '## Planned File Tree' "## Planned<!--$($lineEndingCase.NewLine)parser note$($lineEndingCase.NewLine)--> File Tree" 'multiline split heading'
+  Assert-DesignRejected "HTML comment removal preserves heading line boundaries ($($lineEndingCase.Name))" $splitHeadingAcrossCommentLines 'ARC-CONTRACT-MISSING-TABLE: Planned File Tree'
+
+  foreach ($fenceCase in @(
+    [pscustomobject]@{ Name = 'three-backtick'; Character = [char]'`'; Open = 3; Close = 3; Info = 'markdown' }
+    [pscustomobject]@{ Name = 'four-backtick-longer-closer'; Character = [char]'`'; Open = 4; Close = 5; Info = 'markdown' }
+    [pscustomobject]@{ Name = 'five-backtick'; Character = [char]'`'; Open = 5; Close = 5; Info = '' }
+    [pscustomobject]@{ Name = 'three-tilde-with-backtick-info'; Character = [char]'~'; Open = 3; Close = 3; Info = 'markdown`example' }
+    [pscustomobject]@{ Name = 'four-tilde-longer-closer'; Character = [char]'~'; Open = 4; Close = 6; Info = 'markdown' }
+    [pscustomobject]@{ Name = 'five-tilde'; Character = [char]'~'; Open = 5; Close = 5; Info = '' }
+  )) {
+    $fencedTree = Add-TestFencedH2SectionExample -Text $designWithLineEndings -Heading 'Planned File Tree' -FenceCharacter $fenceCase.Character -OpeningLength $fenceCase.Open -ClosingLength $fenceCase.Close -InfoString $fenceCase.Info
+    Assert-DesignAccepted "Planned File Tree ignores a valid $($fenceCase.Name) example ($($lineEndingCase.Name))" $fencedTree
+  }
+
+  $treeSection = Get-TestH2SectionMatch -Text $designWithLineEndings -Heading 'Planned File Tree'
+  $shortCloserExample = ([string]::new([char]'`', 4) + "markdown$($lineEndingCase.NewLine)" + [string]::new([char]'`', 3) + $lineEndingCase.NewLine + $treeSection.Value + [string]::new([char]'`', 4) + $lineEndingCase.NewLine)
+  Assert-DesignAccepted "a shorter backtick closer cannot expose a fenced canonical example ($($lineEndingCase.Name))" $designWithLineEndings.Insert($treeSection.Index, $shortCloserExample)
+  $malformedCloserExample = ("~~~markdown$($lineEndingCase.NewLine)~~~ not-a-closer$($lineEndingCase.NewLine)" + $treeSection.Value + "~~~$($lineEndingCase.NewLine)")
+  Assert-DesignAccepted "a closer with trailing content cannot expose a fenced canonical example ($($lineEndingCase.Name))" $designWithLineEndings.Insert($treeSection.Index, $malformedCloserExample)
+  $wrongCharacterCloserExample = ([string]::new([char]'`', 4) + "markdown$($lineEndingCase.NewLine)" + [string]::new([char]'~', 4) + $lineEndingCase.NewLine + $treeSection.Value + [string]::new([char]'`', 4) + $lineEndingCase.NewLine)
+  Assert-DesignAccepted "a wrong-character closer cannot expose a fenced canonical example ($($lineEndingCase.Name))" $designWithLineEndings.Insert($treeSection.Index, $wrongCharacterCloserExample)
+
+  $invalidBacktickOpener = '```bad``info' + $lineEndingCase.NewLine
+  Assert-DesignAccepted "a backtick info string containing backticks cannot hide the later canonical heading ($($lineEndingCase.Name))" $designWithLineEndings.Insert($treeSection.Index, $invalidBacktickOpener)
+  $invalidCommentedBacktickInfo = '```markdown<!-- ` remains part of info -->' + $lineEndingCase.NewLine
+  Assert-DesignAccepted "an HTML comment cannot erase a backtick from an invalid fence info string ($($lineEndingCase.Name))" $designWithLineEndings.Insert($treeSection.Index, $invalidCommentedBacktickInfo)
+  $commentSplicedFenceMarker = '``<!-- parser note -->`markdown' + $lineEndingCase.NewLine
+  Assert-DesignAccepted "HTML comment removal cannot assemble a backtick fence marker ($($lineEndingCase.Name))" $designWithLineEndings.Insert($treeSection.Index, $commentSplicedFenceMarker)
+  $commentSplicedH2Marker = '#<!-- parser note --># Planned File Tree' + $lineEndingCase.NewLine
+  Assert-DesignAccepted "HTML comment removal cannot assemble an H2 marker ($($lineEndingCase.Name))" $designWithLineEndings.Insert($treeSection.Index, $commentSplicedH2Marker)
+  $commentPrefixedTreeCopy = Replace-TestFixtureText $treeSection.Value '## Planned File Tree' '<!-- parser note -->## Planned File Tree' 'comment-prefixed H2 marker'
+  Assert-DesignAccepted "HTML comment removal cannot move an H2 marker to column zero ($($lineEndingCase.Name))" $designWithLineEndings.Insert($treeSection.Index, $commentPrefixedTreeCopy)
+  $commentContinuationTreeCopy = "<!--$($lineEndingCase.NewLine)## hidden -->## Planned File Tree$($lineEndingCase.NewLine)"
+  Assert-DesignAccepted "multiline HTML comment removal cannot move an H2 marker to column zero ($($lineEndingCase.Name))" $designWithLineEndings.Insert($treeSection.Index, $commentContinuationTreeCopy)
+  $realDuplicateTrees = Add-TestH2SectionDuplicate -Text $designWithLineEndings -Heading 'Planned File Tree' -Position after
+  $firstTree = Get-TestH2SectionMatch -Text $designWithLineEndings -Heading 'Planned File Tree'
+  Assert-DesignRejected "an invalid backtick opener cannot hide later real duplicate headings ($($lineEndingCase.Name))" $realDuplicateTrees.Insert($firstTree.Index, $invalidBacktickOpener) 'ARC-CONTRACT-HEADING-CARDINALITY: Planned File Tree'
 }
 
 $selfLabeledTestOwner = $featureLocalDesign.Replace('| ui/admin_panel.dart | AdminPanel | presentation |', '| ui/admin_panel.dart | AdminPanel | test |')
 Assert-DesignRejected 'production owner cannot self-label as test to evade verification' $selfLabeledTestOwner 'verification-owner-missing'
 
 $invalidVerificationVerdict = $featureLocalDesign.Replace('| PASS | not-applicable |', '| UNKNOWN | not-applicable |')
 Assert-DesignRejected 'verification verdict must be canonical' $invalidVerificationVerdict 'verification-disposition-invalid'
 
 foreach ($eligibleCase in @(
   [pscustomobject]@{ Name = 'config'; Path = 'config/admin_lock.yaml'; Primary = 'declare admin lock configuration'; Kind = 'static-structure' }
@@ -703,20 +877,34 @@ function Assert-PlanRejected([string]$Name, [string]$PlanText, [string]$Expected
 function Assert-PlanAccepted([string]$Name, [string]$PlanText, [string]$DesignText = (New-ResponsibilityPlanDesignFixture)) {
   $diagnostics = @(Test-ResponsibilityPlan -DesignText $DesignText -PlanText $PlanText -WorkItemId 'WORK-ADMIN-LOCK' -ContractText $contract)
   if ($diagnostics.Count -ne 0) {
     throw "$Name should pass but got: $($diagnostics -join '; ')"
   }
   Write-Output "PASS: $Name"
 }
 
 $validPlan = New-ResponsibilityPlanFixture
 Assert-PlanAccepted 'plan preserves the exact ordered responsibility owner set' $validPlan
+foreach ($lineEndingCase in @(
+  [pscustomobject]@{ Name = 'LF'; NewLine = "`n" }
+  [pscustomobject]@{ Name = 'CRLF'; NewLine = "`r`n" }
+)) {
+  $planWithLineEndings = Convert-TestLineEndings $validPlan $lineEndingCase.NewLine
+  $duplicateAdapterTrace = Add-TestH2SectionDuplicate -Text $planWithLineEndings -Heading 'Work Item Adapter Trace' -Position after
+  Assert-TestExactDiagnostics "plan emits only the exact Work Item Adapter Trace duplicate diagnostic ($($lineEndingCase.Name))" `
+    @(Test-ResponsibilityPlan -DesignText (New-ResponsibilityPlanDesignFixture) -PlanText $duplicateAdapterTrace -WorkItemId 'WORK-ADMIN-LOCK' -ContractText $contract) `
+    @('ARC-CONTRACT-HEADING-CARDINALITY: Work Item Adapter Trace')
+  $missingAdapterTrace = Remove-TestH2Section -Text $planWithLineEndings -Heading 'Work Item Adapter Trace'
+  Assert-TestExactDiagnostics "plan emits only the exact Work Item Adapter Trace missing diagnostic ($($lineEndingCase.Name))" `
+    @(Test-ResponsibilityPlan -DesignText (New-ResponsibilityPlanDesignFixture) -PlanText $missingAdapterTrace -WorkItemId 'WORK-ADMIN-LOCK' -ContractText $contract) `
+    @('ARC-CONTRACT-MISSING-TABLE: Work Item Adapter Trace')
+}
 Assert-PlanAccepted 'generic adapter keeps owner binding without migration unit taxonomy' (New-ResponsibilityPlanFixture -MigrationUnitId 'not-applicable')
 $approvedPlan = $validPlan.Replace('status: draft', "status: approved`napproval_source: human`nrevision: 2")
 Assert-PlanAccepted 'approved plan binds every adapter to its immutable front-matter revision' $approvedPlan
 $mutableNotApplicableMasterReference = $approvedPlan.Replace(
   '| UNIT-ADMIN-LOCK | WORK-ADMIN-LOCK | not-applicable | master-plan.md | 2 | not-applicable | DESIGN-ADMIN@2 |',
   '| UNIT-ADMIN-LOCK | WORK-ADMIN-LOCK | not-applicable | master-plan.md@latest | 2 | not-applicable | DESIGN-ADMIN@2 |'
 )
 $orphanNotApplicableParent = $approvedPlan.Replace(
   '| UNIT-ADMIN-LOCK | WORK-ADMIN-LOCK | not-applicable | master-plan.md | 2 | not-applicable | DESIGN-ADMIN@2 |',
   '| UNIT-ADMIN-LOCK | WORK-ADMIN-LOCK | WORK-ORPHAN | master-plan.md | 2 | not-applicable | DESIGN-ADMIN@2 |'
@@ -754,21 +942,23 @@ if ($unboundAdapter -ceq $validPlan) { throw 'Unbound adapter fixture replacemen
 Assert-PlanRejected 'plan rejects adapter work item without responsibility owner reference' $unboundAdapter 'responsibility-owner-extra'
 
 $duplicateAdapterHeading = $validPlan + @"
 
 ## Work Item Adapter Trace
 
 | Migration Unit ID | Work Item ID | Parent Work Item ID | Master Plan Reference | Master Plan Revision | Decomposition Decision Reference | Design Revision |
 |---|---|---|---|---|---|---|
 | UNIT-HIDDEN | WORK-HIDDEN | not-applicable | master-plan.md | 2 | not-applicable | DESIGN-ADMIN@2 |
 "@
-Assert-PlanRejected 'plan rejects duplicate adapter trace heading' $duplicateAdapterHeading 'responsibility-owner-extra'
+Assert-TestExactDiagnostics 'plan rejects duplicate adapter trace heading with only its exact cardinality diagnostic' `
+  @(Test-ResponsibilityPlan -DesignText (New-ResponsibilityPlanDesignFixture) -PlanText $duplicateAdapterHeading -WorkItemId 'WORK-ADMIN-LOCK' -ContractText $contract) `
+  @('ARC-CONTRACT-HEADING-CARDINALITY: Work Item Adapter Trace')
 
 $crossWorkItemReuse = $validPlan + @"
 
 | WORK-OTHER | DESIGN-ADMIN@2 | RESP-WIFI, RESP-WIRED | RESP-LOCK-GUARD | RESP-LOCK-COMPOSITION | architecture-rules.md#RULE-007: independently implementable, reviewable, verifiable, and revertible |
 "@
 Assert-PlanRejected 'plan rejects unapproved cross-work-item responsibility reuse' $crossWorkItemReuse 'responsibility-owner-extra'
 
 $approvedReuseDesign = (New-ResponsibilityPlanDesignFixture).Replace('; WORK-ADMIN-LOCK |', '; WORK-ADMIN-LOCK; WORK-ADMIN-LOCK-CHILD |') + @"
 
 ## Approved Decomposition Decisions
@@ -1102,32 +1292,51 @@ function Assert-ReviewRejected([string]$Name, [string]$ReviewText, [string]$Expe
 }
 
 function Assert-ReviewAccepted([string]$Name, [string]$ReviewText, [string]$DesignText = $validReviewDesign, [string]$ImplementationText = $validImplementation, [object]$PinnedSource = $validReviewSource, [string]$ApprovedPlanText = $script:validReviewPlan) {
   $diagnostics = @(Test-ResponsibilityReview -DesignText $DesignText -ImplementationText $ImplementationText -ReviewText $ReviewText -ContractText $contract -SourceRoot $PinnedSource.Root -TaskBaseSha $PinnedSource.TaskBaseSha -FinalTreeSha $PinnedSource.FinalTreeSha -ApprovedPlanText $ApprovedPlanText)
   if ($diagnostics.Count -ne 0) {
     throw "$Name should pass but got: $($diagnostics -join '; ')"
   }
   Write-Output "PASS: $Name"
 }
 
+function Assert-ReviewDiagnosticsExactly([string]$Name, [string]$ReviewText, [string[]]$ExpectedDiagnostics, [string]$DesignText = $validReviewDesign, [string]$ImplementationText = $validImplementation, [object]$PinnedSource = $validReviewSource, [string]$ApprovedPlanText = $script:validReviewPlan) {
+  $diagnostics = @(Test-ResponsibilityReview -DesignText $DesignText -ImplementationText $ImplementationText -ReviewText $ReviewText -ContractText $contract -SourceRoot $PinnedSource.Root -TaskBaseSha $PinnedSource.TaskBaseSha -FinalTreeSha $PinnedSource.FinalTreeSha -ApprovedPlanText $ApprovedPlanText)
+  Assert-TestExactDiagnostics -Name $Name -Actual $diagnostics -Expected $ExpectedDiagnostics
+}
+
 function Convert-ReviewFixtureLineEndings([string]$Text, [string]$NewLine) {
   return [regex]::Replace($Text, '\r?\n', $NewLine)
 }
 
 function Replace-ReviewFixtureText([string]$Text, [string]$OldValue, [string]$NewValue, [string]$Context) {
   $updated = $Text.Replace($OldValue, $NewValue)
   if ($updated -ceq $Text) { throw "$Context fixture replacement failed" }
   return $updated
 }
 
 $validImplementation = New-ResponsibilityImplementationFixture
 Assert-ImplementationAccepted 'actual matrices exactly preserve planned owners and verification' $validImplementation
+foreach ($lineEndingCase in @(
+  [pscustomobject]@{ Name = 'LF'; NewLine = "`n" }
+  [pscustomobject]@{ Name = 'CRLF'; NewLine = "`r`n" }
+)) {
+  $implementationWithLineEndings = Convert-TestLineEndings $validImplementation $lineEndingCase.NewLine
+  $duplicateActualMatrix = Add-TestH2SectionDuplicate -Text $implementationWithLineEndings -Heading 'Actual File Responsibility Matrix' -Position after
+  Assert-TestExactDiagnostics "implementation emits only the exact Actual File Responsibility Matrix duplicate diagnostic ($($lineEndingCase.Name))" `
+    @(Test-ResponsibilityImplementation -DesignText (New-ResponsibilityPlanDesignFixture) -ImplementationText $duplicateActualMatrix -ContractText $contract) `
+    @('ARC-CONTRACT-HEADING-CARDINALITY: Actual File Responsibility Matrix')
+  $missingActualMatrix = Remove-TestH2Section -Text $implementationWithLineEndings -Heading 'Actual File Responsibility Matrix'
+  Assert-TestExactDiagnostics "implementation emits only the exact Actual File Responsibility Matrix missing diagnostic ($($lineEndingCase.Name))" `
+    @(Test-ResponsibilityImplementation -DesignText (New-ResponsibilityPlanDesignFixture) -ImplementationText $missingActualMatrix -ContractText $contract) `
+    @('ARC-CONTRACT-MISSING-TABLE: Actual File Responsibility Matrix')
+}
 $multiWorkItemDesign = (New-ResponsibilityPlanDesignFixture).Replace(
   '| RESP-LOCK-COMPOSITION | lib/admin_lock_composition.dart | AdminLockComposition | integration | compose admin lock owners | CAP-LOCK-COMPOSITION | REQ-104; WORK-ADMIN-LOCK | not-applicable | AdminLockComposition | route registration | lib/target_shell.dart#TargetShell | preferred | factual-discovery-evidence | inspection:lib/target_shell.dart:10-80 | target-exemplar | feature-local | production composition lifecycle and revert boundary | VERIFY-OWNER-LOCK-COMPOSITION | yes | not-applicable |',
   "| RESP-LOCK-COMPOSITION | lib/admin_lock_composition.dart | AdminLockComposition | integration | compose admin lock owners | CAP-LOCK-COMPOSITION | REQ-104; WORK-ADMIN-LOCK | not-applicable | AdminLockComposition | route registration | lib/target_shell.dart#TargetShell | preferred | factual-discovery-evidence | inspection:lib/target_shell.dart:10-80 | target-exemplar | feature-local | production composition lifecycle and revert boundary | VERIFY-OWNER-LOCK-COMPOSITION | yes | not-applicable |`n| RESP-OTHER-WORK | lib/other_work.dart | OtherWork | application | implement unrelated work | CAP-OTHER-WORK | REQ-999; WORK-OTHER | not-applicable | OtherWork | none | lib/target_shell.dart#TargetShell | preferred | factual-discovery-evidence | inspection:lib/target_shell.dart:10-80 | target-exemplar | feature-local | same capability lifecycle verification and revert boundary | VERIFY-OWNER-OTHER-WORK | yes | not-applicable |"
 ).Replace(
   '| VERIFY-OWNER-LOCK-COMPOSITION | RESP-LOCK-COMPOSITION | CAP-LOCK-COMPOSITION | test/admin_lock_composition_test.ps1 | AdminLockCompositionContract | production-composition | required | invokes lib/admin_lock_composition.dart#AdminLockComposition | not-applicable | PASS | not-applicable |',
   "| VERIFY-OWNER-LOCK-COMPOSITION | RESP-LOCK-COMPOSITION | CAP-LOCK-COMPOSITION | test/admin_lock_composition_test.ps1 | AdminLockCompositionContract | production-composition | required | invokes lib/admin_lock_composition.dart#AdminLockComposition | not-applicable | PASS | not-applicable |`n| VERIFY-OWNER-OTHER-WORK | RESP-OTHER-WORK | CAP-OTHER-WORK | test/other_work_test.ps1 | OtherWorkContract | contract | required | invokes lib/other_work.dart#OtherWork | not-applicable | PASS | not-applicable |"
 )
 $multiWorkItemDiagnostics = @(Test-ResponsibilityImplementation -DesignText $multiWorkItemDesign -ImplementationText $validImplementation -ContractText $contract)
 if ($multiWorkItemDiagnostics.Count -ne 0) { throw "selected owner set should exclude unrelated design work but got: $($multiWorkItemDiagnostics -join '; ')" }
 Write-Output 'PASS: actual comparison is scoped to selected plan owners'
@@ -1179,37 +1388,73 @@ Assert-ReviewRejected 'review envelope rejects an unapproved substituted plan au
 Assert-ReviewAccepted 'review resolves unchanged verification evidence from the pinned final tree' $canonicalEnvelopeReview
 foreach ($lineEndingCase in @(
   [pscustomobject]@{ Name = 'LF'; NewLine = "`n" }
   [pscustomobject]@{ Name = 'CRLF'; NewLine = "`r`n" }
 )) {
   $reviewWithLineEndings = Convert-TestLineEndings $canonicalEnvelopeReview $lineEndingCase.NewLine
   Assert-ReviewAccepted "canonical single review envelope headings are accepted ($($lineEndingCase.Name))" $reviewWithLineEndings
   foreach ($heading in @('Master Scope Context', 'Task Provenance', 'Architecture Responsibility Handoff', 'Responsibility Review Evidence')) {
     foreach ($position in @('before', 'after')) {
       $duplicateReviewSection = Add-TestH2SectionDuplicate -Text $reviewWithLineEndings -Heading $heading -Position $position
-      Assert-ReviewRejected "$heading rejects a duplicate $position the canonical section ($($lineEndingCase.Name))" $duplicateReviewSection "ARC-CONTRACT-HEADING-CARDINALITY: $heading"
+      Assert-ReviewDiagnosticsExactly -Name "$heading emits only its exact duplicate diagnostic $position the canonical section ($($lineEndingCase.Name))" `
+        -ReviewText $duplicateReviewSection -ExpectedDiagnostics @("ARC-CONTRACT-HEADING-CARDINALITY: $heading")
+      $malformedSecondSection = Add-TestH2SectionDuplicate -Text $reviewWithLineEndings -Heading $heading -Position $position -CopyKind malformed
+      Assert-ReviewDiagnosticsExactly -Name "$heading emits only its exact malformed-copy diagnostic $position the canonical section ($($lineEndingCase.Name))" `
+        -ReviewText $malformedSecondSection -ExpectedDiagnostics @("ARC-CONTRACT-HEADING-CARDINALITY: $heading")
     }
-    $malformedSecondSection = Add-TestH2SectionDuplicate -Text $reviewWithLineEndings -Heading $heading -Position after -CopyKind malformed
-    Assert-ReviewRejected "$heading rejects a malformed second copy ($($lineEndingCase.Name))" $malformedSecondSection "ARC-CONTRACT-HEADING-CARDINALITY: $heading"
+    $missingReviewSection = Remove-TestH2Section -Text $reviewWithLineEndings -Heading $heading
+    Assert-ReviewDiagnosticsExactly -Name "$heading emits only its exact missing diagnostic ($($lineEndingCase.Name))" `
+      -ReviewText $missingReviewSection -ExpectedDiagnostics @("ARC-CONTRACT-MISSING-TABLE: $heading")
     Assert-ReviewAccepted "$heading ignores prose, H3, blockquote, and fenced-code mentions ($($lineEndingCase.Name))" `
       (Add-TestHeadingCodeExample -Text $reviewWithLineEndings -Heading $heading)
   }
-  $conflictingReviewEvidence = Add-TestH2SectionDuplicate -Text $reviewWithLineEndings -Heading 'Responsibility Review Evidence' -Position after -CopyKind conflicting -ConflictFrom '| AdminWifi | AdminWifi | none | none | PASS |' -ConflictTo '| AdminWifi | AdminWifiConflict | none | none | BLOCKED |'
-  Assert-ReviewRejected "Responsibility Review Evidence rejects a conflicting second copy ($($lineEndingCase.Name))" $conflictingReviewEvidence 'ARC-CONTRACT-HEADING-CARDINALITY: Responsibility Review Evidence'
+  foreach ($position in @('before', 'after')) {
+    $conflictingReviewEvidence = Add-TestH2SectionDuplicate -Text $reviewWithLineEndings -Heading 'Responsibility Review Evidence' -Position $position -CopyKind conflicting -ConflictFrom '| AdminWifi | AdminWifi | none | none | PASS |' -ConflictTo '| AdminWifi | AdminWifiConflict | none | none | BLOCKED |'
+    Assert-ReviewDiagnosticsExactly -Name "Responsibility Review Evidence emits only its exact conflicting-copy diagnostic $position the canonical section ($($lineEndingCase.Name))" `
+      -ReviewText $conflictingReviewEvidence -ExpectedDiagnostics @('ARC-CONTRACT-HEADING-CARDINALITY: Responsibility Review Evidence')
+  }
+
+  $twoDuplicateSections = Add-TestH2SectionDuplicate -Text $reviewWithLineEndings -Heading 'Task Provenance' -Position after
+  $twoDuplicateSections = Add-TestH2SectionDuplicate -Text $twoDuplicateSections -Heading 'Master Scope Context' -Position before
+  Assert-ReviewDiagnosticsExactly -Name "review preserves exact canonical diagnostic order without generic cascade ($($lineEndingCase.Name))" `
+    -ReviewText $twoDuplicateSections -ExpectedDiagnostics @(
+      'ARC-CONTRACT-HEADING-CARDINALITY: Master Scope Context'
+      'ARC-CONTRACT-HEADING-CARDINALITY: Task Provenance'
+    )
 
   $adapterLine = '- Delivery Adapter Kind: none'
+  $visiblyDistinctDuplicateAdapterLine = ' - Delivery Adapter Kind: none'
   foreach ($position in @('before', 'after')) {
-    $duplicateAdapter = $reviewWithLineEndings.Replace($adapterLine, "$adapterLine$($lineEndingCase.NewLine)$adapterLine")
+    $duplicateAdapterLines = if ($position -ceq 'before') {
+      "$visiblyDistinctDuplicateAdapterLine$($lineEndingCase.NewLine)$adapterLine"
+    } else {
+      "$adapterLine$($lineEndingCase.NewLine)$visiblyDistinctDuplicateAdapterLine"
+    }
+    $duplicateAdapter = $reviewWithLineEndings.Replace($adapterLine, $duplicateAdapterLines)
     Assert-ReviewRejected "Delivery Adapter Kind rejects a duplicate $position the canonical line ($($lineEndingCase.Name))" $duplicateAdapter 'responsibility-evidence-missing'
+    $malformedAdapterLines = if ($position -ceq 'before') {
+      "- Delivery Adapter Kind: unsupported$($lineEndingCase.NewLine)$adapterLine"
+    } else {
+      "$adapterLine$($lineEndingCase.NewLine)- Delivery Adapter Kind: unsupported"
+    }
+    $malformedSecondAdapter = $reviewWithLineEndings.Replace($adapterLine, $malformedAdapterLines)
+    Assert-ReviewRejected "Delivery Adapter Kind rejects a malformed line $position the canonical line ($($lineEndingCase.Name))" $malformedSecondAdapter 'responsibility-evidence-missing'
   }
-  $malformedSecondAdapter = $reviewWithLineEndings.Replace($adapterLine, "$adapterLine$($lineEndingCase.NewLine)- Delivery Adapter Kind: unsupported")
-  Assert-ReviewRejected "Delivery Adapter Kind rejects a malformed second line ($($lineEndingCase.Name))" $malformedSecondAdapter 'responsibility-evidence-missing'
+  $implementationWithLineEndings = Convert-TestLineEndings $validImplementation $lineEndingCase.NewLine
+  $duplicateChangeHygiene = Add-TestH2SectionDuplicate -Text $implementationWithLineEndings -Heading 'Change Hygiene' -Position after
+  Assert-ReviewDiagnosticsExactly -Name "review emits only the exact implementation Change Hygiene duplicate diagnostic ($($lineEndingCase.Name))" `
+    -ReviewText $reviewWithLineEndings -ExpectedDiagnostics @('ARC-CONTRACT-HEADING-CARDINALITY: Change Hygiene') `
+    -ImplementationText $duplicateChangeHygiene
+  $missingChangeHygiene = Remove-TestH2Section -Text $implementationWithLineEndings -Heading 'Change Hygiene'
+  Assert-ReviewDiagnosticsExactly -Name "review emits only the exact implementation Change Hygiene missing diagnostic ($($lineEndingCase.Name))" `
+    -ReviewText $reviewWithLineEndings -ExpectedDiagnostics @('ARC-CONTRACT-MISSING-TABLE: Change Hygiene') `
+    -ImplementationText $missingChangeHygiene
 }
 foreach ($verificationCase in @(
   [pscustomobject]@{ Variant = 'missing-path'; Name = 'missing verification evidence path' }
   [pscustomobject]@{ Variant = 'missing-scenario'; Name = 'missing verification scenario' }
   [pscustomobject]@{ Variant = 'foreign-owner'; Name = 'foreign verification owner binding' }
   [pscustomobject]@{ Variant = 'stale-scenario'; Name = 'stale verification scenario in the final tree' }
   [pscustomobject]@{ Variant = 'self-attested'; Name = 'self-attested verification binding' }
   [pscustomobject]@{ Variant = 'fake-registry'; Name = 'test-only fake production registry' }
   [pscustomobject]@{ Variant = 'fake-provider'; Name = 'fake provider instead of real production composition' }
 )) {
@@ -1241,26 +1486,72 @@ if ($migrationImplementationDiagnostics.Count -ne 0) { throw "migration implemen
 Write-Output 'PASS: migration implementation preserves canonical Authority@Revision selected row'
 Assert-ReviewAccepted 'migration review preserves the exact implementation selected row and approved selector authority' $migrationReview $validReviewDesign $migrationImplementation $validReviewSource $migrationPlan
 foreach ($lineEndingCase in @(
   [pscustomobject]@{ Name = 'LF'; NewLine = "`n" }
   [pscustomobject]@{ Name = 'CRLF'; NewLine = "`r`n" }
 )) {
   $migrationReviewWithLineEndings = Convert-TestLineEndings $migrationReview $lineEndingCase.NewLine
   $migrationImplementationWithLineEndings = Convert-TestLineEndings $migrationImplementation $lineEndingCase.NewLine
   $migrationPlanWithLineEndings = Convert-TestLineEndings $migrationPlan $lineEndingCase.NewLine
   Assert-ReviewAccepted "canonical conditional Selected Migration Unit is accepted ($($lineEndingCase.Name))" $migrationReviewWithLineEndings $validReviewDesign $migrationImplementationWithLineEndings $validReviewSource $migrationPlanWithLineEndings
+  $fencedImplementationSelected = Add-TestFencedH2SectionExample -Text $migrationImplementationWithLineEndings -Heading 'Selected Migration Unit' -FenceCharacter ([char]'`') -OpeningLength 4 -ClosingLength 4 -InfoString 'markdown'
+  $fencedImplementationDiagnostics = @(Test-ResponsibilityImplementation -DesignText $validReviewDesign -ImplementationText $fencedImplementationSelected -ContractText $contract)
+  if ($fencedImplementationDiagnostics.Count -ne 0) { throw "implementation must ignore a fenced Selected Migration Unit example ($($lineEndingCase.Name)) but got: $($fencedImplementationDiagnostics -join '; ')" }
+  Write-Output "PASS: implementation ignores a fenced Selected Migration Unit example ($($lineEndingCase.Name))"
+  $commentedImplementationSelected = Add-TestCommentedH2SectionDuplicate -Text $migrationImplementationWithLineEndings -Heading 'Selected Migration Unit' -Position before
+  $commentedImplementationDiagnostics = @(Test-ResponsibilityImplementation -DesignText $validReviewDesign -ImplementationText $commentedImplementationSelected -ContractText $contract)
+  if ($commentedImplementationDiagnostics.Count -ne 0) { throw "implementation must ignore a commented Selected Migration Unit example ($($lineEndingCase.Name)) but got: $($commentedImplementationDiagnostics -join '; ')" }
+  Write-Output "PASS: implementation ignores a commented Selected Migration Unit example ($($lineEndingCase.Name))"
+  $duplicateImplementationSelected = Add-TestH2SectionDuplicate -Text $migrationImplementationWithLineEndings -Heading 'Selected Migration Unit' -Position after
+  Assert-TestExactDiagnostics "implementation emits only the exact Selected Migration Unit duplicate diagnostic ($($lineEndingCase.Name))" `
+    @(Test-ResponsibilityImplementation -DesignText $validReviewDesign -ImplementationText $duplicateImplementationSelected -ContractText $contract) `
+    @('ARC-CONTRACT-HEADING-CARDINALITY: Selected Migration Unit')
+  $missingImplementationSelected = Remove-TestH2Section -Text $migrationImplementationWithLineEndings -Heading 'Selected Migration Unit'
+  Assert-TestExactDiagnostics "implementation emits only the exact Selected Migration Unit missing diagnostic ($($lineEndingCase.Name))" `
+    @(Test-ResponsibilityImplementation -DesignText $validReviewDesign -ImplementationText $missingImplementationSelected -ContractText $contract) `
+    @('ARC-CONTRACT-MISSING-TABLE: Selected Migration Unit')
+  Assert-ReviewAccepted "review ignores a fenced Selected Migration Unit example ($($lineEndingCase.Name))" `
+    (Add-TestFencedH2SectionExample -Text $migrationReviewWithLineEndings -Heading 'Selected Migration Unit' -FenceCharacter ([char]'~') -OpeningLength 3 -ClosingLength 4 -InfoString 'markdown`example') `
+    $validReviewDesign $migrationImplementationWithLineEndings $validReviewSource $migrationPlanWithLineEndings
+  Assert-ReviewAccepted "review ignores a commented Selected Migration Unit example ($($lineEndingCase.Name))" `
+    (Add-TestCommentedH2SectionDuplicate -Text $migrationReviewWithLineEndings -Heading 'Selected Migration Unit' -Position before) `
+    $validReviewDesign $migrationImplementationWithLineEndings $validReviewSource $migrationPlanWithLineEndings
+
+  $selectedBlockWithLineEndings = Convert-TestLineEndings $migrationSelectedUnitBlock $lineEndingCase.NewLine
+  $noneImplementationWithLineEndings = Convert-TestLineEndings $validImplementation $lineEndingCase.NewLine
+  $implementationInsertionHeading = '## Actual File Responsibility Matrix'
+  $fourBackticks = [string]::new([char]'`', 4)
+  $fencedSelectedExample = "${fourBackticks}markdown$($lineEndingCase.NewLine)$selectedBlockWithLineEndings$fourBackticks$($lineEndingCase.NewLine)"
+  Assert-ImplementationAccepted "non-migration implementation ignores a fenced Selected Migration Unit example ($($lineEndingCase.Name))" `
+    $noneImplementationWithLineEndings.Replace($implementationInsertionHeading, "$fencedSelectedExample$implementationInsertionHeading")
+  $commentedSelectedExample = "<!--$($lineEndingCase.NewLine)$selectedBlockWithLineEndings-->$($lineEndingCase.NewLine)"
+  Assert-ImplementationAccepted "non-migration implementation ignores a commented Selected Migration Unit example ($($lineEndingCase.Name))" `
+    $noneImplementationWithLineEndings.Replace($implementationInsertionHeading, "$commentedSelectedExample$implementationInsertionHeading")
+  Assert-ImplementationRejected "non-migration implementation rejects a real Selected Migration Unit ($($lineEndingCase.Name))" `
+    $noneImplementationWithLineEndings.Replace($implementationInsertionHeading, "$selectedBlockWithLineEndings$implementationInsertionHeading") `
+    'responsibility-evidence-missing'
   foreach ($position in @('before', 'after')) {
     $duplicateSelectedUnit = Add-TestH2SectionDuplicate -Text $migrationReviewWithLineEndings -Heading 'Selected Migration Unit' -Position $position
-    Assert-ReviewRejected "Selected Migration Unit rejects a duplicate $position the canonical section ($($lineEndingCase.Name))" $duplicateSelectedUnit 'responsibility-evidence-missing' -ImplementationText $migrationImplementationWithLineEndings -ApprovedPlanText $migrationPlanWithLineEndings
+    Assert-ReviewDiagnosticsExactly -Name "review emits only the exact Selected Migration Unit duplicate diagnostic $position the canonical section ($($lineEndingCase.Name))" `
+      -ReviewText $duplicateSelectedUnit -ExpectedDiagnostics @('ARC-CONTRACT-HEADING-CARDINALITY: Selected Migration Unit') `
+      -ImplementationText $migrationImplementationWithLineEndings -ApprovedPlanText $migrationPlanWithLineEndings
+  }
+  $missingReviewSelectedUnit = Remove-TestH2Section -Text $migrationReviewWithLineEndings -Heading 'Selected Migration Unit'
+  Assert-ReviewDiagnosticsExactly -Name "review emits only the exact Selected Migration Unit missing diagnostic ($($lineEndingCase.Name))" `
+    -ReviewText $missingReviewSelectedUnit -ExpectedDiagnostics @('ARC-CONTRACT-MISSING-TABLE: Selected Migration Unit') `
+    -ImplementationText $migrationImplementationWithLineEndings -ApprovedPlanText $migrationPlanWithLineEndings
+  foreach ($position in @('before', 'after')) {
+    $malformedSecondSelectedUnit = Add-TestH2SectionDuplicate -Text $migrationReviewWithLineEndings -Heading 'Selected Migration Unit' -Position $position -CopyKind malformed
+    Assert-ReviewDiagnosticsExactly -Name "review emits only the exact Selected Migration Unit malformed-copy diagnostic $position the canonical section ($($lineEndingCase.Name))" `
+      -ReviewText $malformedSecondSelectedUnit -ExpectedDiagnostics @('ARC-CONTRACT-HEADING-CARDINALITY: Selected Migration Unit') `
+      -ImplementationText $migrationImplementationWithLineEndings -ApprovedPlanText $migrationPlanWithLineEndings
   }
-  $malformedSecondSelectedUnit = Add-TestH2SectionDuplicate -Text $migrationReviewWithLineEndings -Heading 'Selected Migration Unit' -Position after -CopyKind malformed
-  Assert-ReviewRejected "Selected Migration Unit rejects a malformed second copy ($($lineEndingCase.Name))" $malformedSecondSelectedUnit 'responsibility-evidence-missing' -ImplementationText $migrationImplementationWithLineEndings -ApprovedPlanText $migrationPlanWithLineEndings
 }
 $staleMigrationImplementationDiagnostics = @(Test-ResponsibilityImplementation -DesignText $validReviewDesign -ImplementationText ($migrationImplementation.Replace('08-migration-plan.md@2', '08-migration-plan.md@1')) -ContractText $contract)
 if ($staleMigrationImplementationDiagnostics -notcontains 'responsibility-evidence-missing') { throw "stale implementation selected plan reference should be rejected but got: $($staleMigrationImplementationDiagnostics -join '; ')" }
 Write-Output 'PASS: migration implementation rejects stale selected Plan Reference'
 Assert-ReviewRejected 'migration review rejects a selected Plan Reference mismatch' ($migrationReview.Replace('08-migration-plan.md@2', '08-migration-plan.md@1')) 'responsibility-evidence-missing' -ImplementationText $migrationImplementation -ApprovedPlanText $migrationPlan
 
 $approvedMigrationReview = $migrationReview.Replace('status: draft', "status: approved`napproval_source: human")
 $migrationVerification = @"
 ---
 step_id: 12-verification-testing
@@ -1290,20 +1581,46 @@ responsibility_contract:
 
 | Responsibility Contract Version | Tree Conformance | Responsibility Conformance | Verification Ownership | Architecture Conformance State | Evidence References |
 |---|---|---|---|---|---|
 | 1 | PASS | PASS | PASS | PASS | source-diff:$($validReviewSource.TaskBaseSha)..$($validReviewSource.FinalTreeSha)#WORK-ADMIN-LOCK |
 
 $migrationSelectedUnitBlock
 "@
 $migrationHandoffDiagnostics = @(Test-ResponsibilityHandoff -SourceText $approvedMigrationReview -TargetText $migrationVerification -ContractText $contract -ApprovedPlanText $migrationPlan)
 if ($migrationHandoffDiagnostics.Count -ne 0) { throw "composed migration review-to-verification handoff should pass but got: $($migrationHandoffDiagnostics -join '; ')" }
 Write-Output 'PASS: composed implementation to review to verification reuses the exact selected migration row'
+foreach ($lineEndingCase in @(
+  [pscustomobject]@{ Name = 'LF'; NewLine = "`n" }
+  [pscustomobject]@{ Name = 'CRLF'; NewLine = "`r`n" }
+)) {
+  $handoffSource = Convert-TestLineEndings $approvedMigrationReview $lineEndingCase.NewLine
+  $handoffTarget = Convert-TestLineEndings $migrationVerification $lineEndingCase.NewLine
+  $handoffPlan = Convert-TestLineEndings $migrationPlan $lineEndingCase.NewLine
+  $fencedSource = Add-TestFencedH2SectionExample -Text $handoffSource -Heading 'Selected Migration Unit' -FenceCharacter ([char]'`') -OpeningLength 5 -ClosingLength 6 -InfoString 'markdown'
+  $fencedTarget = Add-TestFencedH2SectionExample -Text $handoffTarget -Heading 'Selected Migration Unit' -FenceCharacter ([char]'~') -OpeningLength 4 -ClosingLength 4 -InfoString 'markdown`example'
+  $fencedHandoffDiagnostics = @(Test-ResponsibilityHandoff -SourceText $fencedSource -TargetText $fencedTarget -ContractText $contract -ApprovedPlanText $handoffPlan)
+  if ($fencedHandoffDiagnostics.Count -ne 0) { throw "handoff must ignore fenced Selected Migration Unit examples ($($lineEndingCase.Name)) but got: $($fencedHandoffDiagnostics -join '; ')" }
+  Write-Output "PASS: handoff ignores fenced Selected Migration Unit examples ($($lineEndingCase.Name))"
+  $commentedSource = Add-TestCommentedH2SectionDuplicate -Text $handoffSource -Heading 'Selected Migration Unit' -Position before
+  $commentedTarget = Add-TestCommentedH2SectionDuplicate -Text $handoffTarget -Heading 'Selected Migration Unit' -Position after
+  $commentedHandoffDiagnostics = @(Test-ResponsibilityHandoff -SourceText $commentedSource -TargetText $commentedTarget -ContractText $contract -ApprovedPlanText $handoffPlan)
+  if ($commentedHandoffDiagnostics.Count -ne 0) { throw "handoff must ignore commented Selected Migration Unit examples ($($lineEndingCase.Name)) but got: $($commentedHandoffDiagnostics -join '; ')" }
+  Write-Output "PASS: handoff ignores commented Selected Migration Unit examples ($($lineEndingCase.Name))"
+  $duplicateHandoffSource = Add-TestH2SectionDuplicate -Text $handoffSource -Heading 'Selected Migration Unit' -Position after
+  Assert-TestExactDiagnostics "handoff emits only the exact Selected Migration Unit duplicate diagnostic ($($lineEndingCase.Name))" `
+    @(Test-ResponsibilityHandoff -SourceText $duplicateHandoffSource -TargetText $handoffTarget -ContractText $contract -ApprovedPlanText $handoffPlan) `
+    @('ARC-CONTRACT-HEADING-CARDINALITY: Selected Migration Unit')
+  $missingHandoffTarget = Remove-TestH2Section -Text $handoffTarget -Heading 'Selected Migration Unit'
+  Assert-TestExactDiagnostics "handoff emits only the exact Selected Migration Unit missing diagnostic ($($lineEndingCase.Name))" `
+    @(Test-ResponsibilityHandoff -SourceText $handoffSource -TargetText $missingHandoffTarget -ContractText $contract -ApprovedPlanText $handoffPlan) `
+    @('ARC-CONTRACT-MISSING-TABLE: Selected Migration Unit')
+}
 $staleMigrationHandoffDiagnostics = @(Test-ResponsibilityHandoff -SourceText $approvedMigrationReview -TargetText ($migrationVerification.Replace('08-migration-plan.md@2', '08-migration-plan.md@1')) -ContractText $contract -ApprovedPlanText $migrationPlan)
 if ($staleMigrationHandoffDiagnostics -notcontains 'responsibility-evidence-missing') { throw "stale verification selected plan reference should be rejected but got: $($staleMigrationHandoffDiagnostics -join '; ')" }
 Write-Output 'PASS: composed verification handoff rejects a stale selected Plan Reference'
 foreach ($lineEndingCase in @(
   [pscustomobject]@{ Name = 'LF'; NewLine = "`n" }
   [pscustomobject]@{ Name = 'CRLF'; NewLine = "`r`n" }
 )) {
   $reviewFixture = Convert-ReviewFixtureLineEndings (New-ResponsibilityReviewFixture -PinnedSource $validReviewSource) $lineEndingCase.NewLine
   Assert-ReviewAccepted "independent review covers the final inventory with source and diff evidence ($($lineEndingCase.Name))" $reviewFixture
   $extraSourceSymbol = Replace-ReviewFixtureText -Text $reviewFixture -OldValue '| AdminLockComposition | AdminLockComposition | route registration | route registration | PASS |' -NewValue '| AdminLockComposition | AdminRoute.factoryReset | route registration | route registration | BLOCKED |' -Context "review detects extra source symbol ($($lineEndingCase.Name))"
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-handoff.Tests.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-handoff.Tests.ps1
index 9ceabce..738fc01 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-handoff.Tests.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-handoff.Tests.ps1
@@ -317,20 +317,34 @@ function Assert-HandoffAccepted {
 
 function Assert-HandoffRejected {
   param([string]$Name, [string]$SourceText, [string]$TargetText, [string]$ExpectedDiagnostic, [string]$ApprovedPlanText = $script:migrationPlan)
   $diagnostics = @(Test-ResponsibilityHandoff -SourceText $SourceText -TargetText $TargetText -ContractText $contract -ApprovedPlanText $ApprovedPlanText)
   if ($diagnostics -notcontains $ExpectedDiagnostic) {
     throw "$Name expected $ExpectedDiagnostic but got: $($diagnostics -join '; ')"
   }
   Write-Output "PASS: $Name"
 }
 
+function Assert-HandoffDiagnosticsExactly {
+  param([string]$Name, [string]$SourceText, [string]$TargetText, [string[]]$ExpectedDiagnostics, [string]$ApprovedPlanText = $script:migrationPlan)
+  $diagnostics = @(Test-ResponsibilityHandoff -SourceText $SourceText -TargetText $TargetText -ContractText $contract -ApprovedPlanText $ApprovedPlanText)
+  if ($diagnostics.Count -ne $ExpectedDiagnostics.Count) {
+    throw "$Name expected exactly $($ExpectedDiagnostics.Count) diagnostic(s) [$($ExpectedDiagnostics -join '; ')] but got $($diagnostics.Count) [$($diagnostics -join '; ')]"
+  }
+  for ($index = 0; $index -lt $ExpectedDiagnostics.Count; $index++) {
+    if ($diagnostics[$index] -cne $ExpectedDiagnostics[$index]) {
+      throw "$Name diagnostic $index expected exact <$($ExpectedDiagnostics[$index])> but got <$($diagnostics[$index])>; full list: $($diagnostics -join '; ')"
+    }
+  }
+  Write-Output "PASS: $Name"
+}
+
 $script:migrationPlan = New-ApprovedAdapterPlan
 $genericPlan = New-ApprovedAdapterPlan -AdapterKind task -SelectorApproval 'approval:TASK-ADMIN-LOCK'
 $noneSelectorGenericPlan = $genericPlan.Replace(
   '| WORK-ADMIN-LOCK | task | TASK-ADMIN-LOCK | jira:ADMIN-LOCK | 1 | approval:TASK-ADMIN-LOCK | not-applicable | REQ-001; SC-001; completes within 2 seconds | REQ-001 | incremental/preserve-existing | DESIGN-ADMIN@2 | not-applicable | not-applicable |',
   '| WORK-ADMIN-LOCK | none | not-applicable | not-applicable | not-applicable | not-applicable | not-applicable | REQ-001; SC-001; completes within 2 seconds | REQ-001 | incremental/preserve-existing | DESIGN-ADMIN@2 | not-applicable | not-applicable |'
 ).Replace('task:TASK-ADMIN-LOCK', 'generic:module-foundation')
 if ($noneSelectorGenericPlan -ceq $genericPlan) { throw 'none-selector generic adapter fixture mutation was a silent no-op' }
 $review = New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md'
 $producerReview = New-ProducerReviewArtifact
 $verification = New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md'
@@ -384,20 +398,23 @@ $producerHandoffHeadingIndex = [Array]::IndexOf($producerH2Headings, 'Architectu
 if ($producerHandoffHeadingIndex -lt 0 -or ($producerHandoffHeadingIndex + 2) -ge $producerH2Headings.Count) {
   throw 'Knowledge Base producer template is missing the real surrounding H2 sections'
 }
 $knowledgeBaseSummaryHeading = $producerH2Headings[$producerHandoffHeadingIndex + 1]
 $knowledgeBaseOtherHeading = $producerH2Headings[$producerHandoffHeadingIndex + 2]
 $knowledgeBaseEnvelopeFailures = [Collections.Generic.List[string]]::new()
 foreach ($lineEnding in @('LF', 'CRLF')) {
   foreach ($case in $knowledgeBaseEnvelopeCases) {
     $rendered = Convert-ArtifactLineEndings -Text $case.Target -Style $lineEnding
     Assert-HandoffAccepted "producer-rendered $($case.Name) Knowledge Base accepts the canonical envelope under $lineEnding" $case.Source $rendered $case.Plan
+    $inlineCommentHeading = $rendered.Replace('## Master Scope Context', '## Master <!-- parser note --> Scope Context')
+    if ($inlineCommentHeading -ceq $rendered) { throw "Knowledge Base inline-comment heading mutation was a silent no-op: $($case.Name) $lineEnding" }
+    Assert-HandoffAccepted "producer-rendered $($case.Name) Knowledge Base ignores an inline heading comment under $lineEnding" $case.Source $inlineCommentHeading $case.Plan
 
     $surrounded = Move-ArtifactSectionBeforeHeading -Text $rendered -SectionHeading $knowledgeBaseSummaryHeading -BeforeHeading 'Master Scope Context'
     $adapterLine = "- Delivery Adapter Kind: $($case.AdapterKind)"
     $lineBreak = if ($lineEnding -ceq 'CRLF') { "`r`n" } else { "`n" }
     $withBodyDetail = $surrounded.Replace(
       $adapterLine,
       "$adapterLine$lineBreak$lineBreak### Producer detail$lineBreak$lineBreak" + 'Body text may mention ## marker without creating an H2.'
     )
     if ($withBodyDetail -ceq $surrounded) { throw "Knowledge Base body-detail mutation was a silent no-op: $($case.Name) $lineEnding" }
     Assert-HandoffAccepted "producer-rendered $($case.Name) Knowledge Base allows real surrounding sections and subheadings under $lineEnding" $case.Source $withBodyDetail $case.Plan
@@ -411,61 +428,60 @@ foreach ($lineEnding in @('LF', 'CRLF')) {
         $diagnostics = @(Test-ResponsibilityHandoff -SourceText $case.Source -TargetText $interleaved -ContractText $contract -ApprovedPlanText $case.Plan)
         if ($diagnostics -notcontains 'responsibility-evidence-missing') {
           $knowledgeBaseEnvelopeFailures.Add("$name expected responsibility-evidence-missing but got: $($diagnostics -join '; ')")
         }
         else { Write-Output "PASS: $name" }
       }
     }
 
     foreach ($heading in $case.CanonicalHeadings) {
       $headingLine = "## $heading$lineBreak"
-      $expectedDiagnostic = if ($heading -ceq 'Architecture Responsibility Handoff') { 'responsibility-owner-missing' } else { 'responsibility-evidence-missing' }
       foreach ($mutation in @(
-        [pscustomobject]@{ Name = 'duplicate'; Text = $rendered.Replace($headingLine, "$headingLine$headingLine") }
-        [pscustomobject]@{ Name = 'missing'; Text = $rendered.Replace($headingLine, '') }
+        [pscustomobject]@{ Name = 'duplicate'; Text = $rendered.Replace($headingLine, "$headingLine$headingLine"); Diagnostic = "ARC-CONTRACT-HEADING-CARDINALITY: $heading" }
+        [pscustomobject]@{ Name = 'missing'; Text = $rendered.Replace($headingLine, ''); Diagnostic = "ARC-CONTRACT-MISSING-TABLE: $heading" }
       )) {
         if ($mutation.Text -ceq $rendered) { throw "Knowledge Base $($mutation.Name) heading mutation was a silent no-op: $heading" }
         $name = "producer-rendered $($case.Name) Knowledge Base rejects $($mutation.Name) $heading under $lineEnding"
         $diagnostics = @(Test-ResponsibilityHandoff -SourceText $case.Source -TargetText $mutation.Text -ContractText $contract -ApprovedPlanText $case.Plan)
-        if ($diagnostics -notcontains $expectedDiagnostic) {
-          $knowledgeBaseEnvelopeFailures.Add("$name expected $expectedDiagnostic but got: $($diagnostics -join '; ')")
+        if ($diagnostics.Count -ne 1 -or $diagnostics[0] -cne $mutation.Diagnostic) {
+          $knowledgeBaseEnvelopeFailures.Add("$name expected exactly [$($mutation.Diagnostic)] but got: [$($diagnostics -join '; ')]")
         }
         else { Write-Output "PASS: $name" }
       }
     }
   }
 }
 if ($knowledgeBaseEnvelopeFailures.Count -ne 0) { throw ($knowledgeBaseEnvelopeFailures -join [Environment]::NewLine) }
 $producerSelectedUnitBlock = Get-ArtifactSectionBlock -Text $producerKnowledgeBase -Heading 'Selected Migration Unit'
-Assert-HandoffRejected 'producer-rendered migration terminal Knowledge Base cannot omit the selected migration unit' $regression ($producerKnowledgeBase.Replace($producerSelectedUnitBlock, '')) 'responsibility-evidence-missing'
+Assert-HandoffDiagnosticsExactly 'producer-rendered migration terminal Knowledge Base cannot omit the selected migration unit' $regression ($producerKnowledgeBase.Replace($producerSelectedUnitBlock, '')) @('ARC-CONTRACT-MISSING-TABLE: Selected Migration Unit')
 Assert-HandoffRejected 'producer-rendered generic terminal Knowledge Base cannot retain the selected migration unit' $producerGenericParity ($producerGenericKnowledgeBase.Replace('## Architecture Responsibility Handoff', "$producerSelectedUnitBlock## Architecture Responsibility Handoff")) 'responsibility-evidence-missing' $genericPlan
 Assert-HandoffRejected 'producer-rendered none terminal Knowledge Base cannot retain the selected migration unit' $producerNoneParity ($producerNoneKnowledgeBase.Replace('## Architecture Responsibility Handoff', "$producerSelectedUnitBlock## Architecture Responsibility Handoff")) 'responsibility-evidence-missing' $noneSelectorGenericPlan
 $producerScopeBlock = Get-ArtifactSectionBlock -Text $producerKnowledgeBase -Heading 'Master Scope Context'
 $producerProvenanceBlock = Get-ArtifactSectionBlock -Text $producerKnowledgeBase -Heading 'Task Provenance'
 $reorderedProducerKnowledgeBase = $producerKnowledgeBase.Replace("$producerScopeBlock$producerProvenanceBlock", "$producerProvenanceBlock$producerScopeBlock")
 if ($reorderedProducerKnowledgeBase -ceq $producerKnowledgeBase) { throw 'Knowledge Base envelope reorder mutation was a silent no-op' }
 Assert-HandoffRejected 'producer-rendered terminal Knowledge Base rejects reordered canonical envelope sections' $regression $reorderedProducerKnowledgeBase 'responsibility-evidence-missing'
-Assert-HandoffRejected 'producer-rendered terminal Knowledge Base rejects duplicate canonical envelope sections' $regression ($producerKnowledgeBase.Replace($producerProvenanceBlock, "$producerProvenanceBlock$producerProvenanceBlock")) 'responsibility-evidence-missing'
-Assert-HandoffRejected 'producer-rendered terminal Knowledge Base cannot lose Master Scope Context' $regression ($producerKnowledgeBase -replace '(?ms)^## Master Scope Context.*?(?=^## )', '') 'responsibility-evidence-missing'
+Assert-HandoffDiagnosticsExactly 'producer-rendered terminal Knowledge Base rejects duplicate canonical envelope sections' $regression ($producerKnowledgeBase.Replace($producerProvenanceBlock, "$producerProvenanceBlock$producerProvenanceBlock")) @('ARC-CONTRACT-HEADING-CARDINALITY: Task Provenance')
+Assert-HandoffDiagnosticsExactly 'producer-rendered terminal Knowledge Base cannot lose Master Scope Context' $regression ($producerKnowledgeBase -replace '(?ms)^## Master Scope Context.*?(?=^## )', '') @('ARC-CONTRACT-MISSING-TABLE: Master Scope Context')
 Assert-HandoffRejected 'producer-rendered terminal Knowledge Base cannot mutate delivery adapter kind' $regression ($producerKnowledgeBase.Replace('- Delivery Adapter Kind: migration-unit', '- Delivery Adapter Kind: task')) 'responsibility-evidence-missing'
 Assert-HandoffRejected 'producer-rendered terminal Knowledge Base cannot bind foreign scope' $regression ($producerKnowledgeBase.Replace('| RUN-HANDOFF-001 | master-spec.md | SPEC-HANDOFF-001 | 1 | master-plan.md | PLAN-HANDOFF-001 | 1 | WORK-ADMIN-LOCK |', '| RUN-HANDOFF-OTHER | master-spec.md | SPEC-HANDOFF-001 | 1 | master-plan.md | PLAN-HANDOFF-001 | 1 | WORK-ADMIN-LOCK |')) 'responsibility-evidence-missing'
-Assert-HandoffRejected 'producer-rendered terminal Knowledge Base cannot lose task provenance' $regression ($producerKnowledgeBase -replace '(?ms)^## Task Provenance.*?(?=^## )', '') 'responsibility-evidence-missing'
+Assert-HandoffDiagnosticsExactly 'producer-rendered terminal Knowledge Base cannot lose task provenance' $regression ($producerKnowledgeBase -replace '(?ms)^## Task Provenance.*?(?=^## )', '') @('ARC-CONTRACT-MISSING-TABLE: Task Provenance')
 Assert-HandoffRejected 'producer-rendered terminal Knowledge Base cannot mutate task provenance' $regression ($producerKnowledgeBase.Replace('| UNIT-ADMIN-LOCK | 1111111111111111111111111111111111111111 | 2222222222222222222222222222222222222222 | 14-regression-report.md |', '| UNIT-ADMIN-LOCK | 1111111111111111111111111111111111111111 | 3333333333333333333333333333333333333333 | 14-regression-report.md |')) 'responsibility-evidence-missing'
 Assert-HandoffRejected 'draft review cannot seed verification' (New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -Status 'draft') $verification 'responsibility-evidence-missing'
 Assert-HandoffRejected 'blocked review cannot seed verification' (New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -Result 'blocked') $verification 'responsibility-evidence-missing'
 Assert-HandoffRejected 'review without approval source cannot seed verification' (New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -ApprovalSource '') $verification 'responsibility-evidence-missing'
 Assert-HandoffRejected 'non-human review cannot seed verification' (New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -ApprovalSource 'auto') $verification 'responsibility-evidence-missing'
 Assert-HandoffRejected 'conflicting review lifecycle fields cannot seed verification' ($review.Replace('status: approved', "status: approved`nstatus: draft")) $verification 'responsibility-evidence-missing'
 Assert-HandoffRejected 'seven-character provenance cannot seed verification' (New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -TaskBaseSha '1111111' -FinalTreeSha '2222222') (New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md' -TaskBaseSha '1111111' -FinalTreeSha '2222222') 'responsibility-evidence-missing'
 Assert-HandoffRejected 'legacy filename evidence cannot seed verification' (New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -Evidence 'review-report.md#responsibility-evidence') $verification 'responsibility-evidence-missing'
 Assert-HandoffRejected 'same work item and SHAs from another run cannot seed verification' $review (New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md' -RunId 'RUN-HANDOFF-OTHER') 'responsibility-evidence-missing'
-Assert-HandoffRejected 'migration-unit handoff cannot omit selected unit' $review (New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md' -OmitSelectedMigrationUnit) 'responsibility-evidence-missing'
+Assert-HandoffDiagnosticsExactly 'migration-unit handoff cannot omit selected unit' $review (New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md' -OmitSelectedMigrationUnit) @('ARC-CONTRACT-MISSING-TABLE: Selected Migration Unit')
 Assert-HandoffRejected 'generic handoff cannot invent selected unit' (New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -AdapterKind 'task') ((New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md' -AdapterKind 'task') + "`n## Selected Migration Unit`n") 'responsibility-evidence-missing'
 $genericReview = New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -AdapterKind 'task'
 $genericVerification = New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md' -AdapterKind 'task'
 $genericParity = New-HandoffArtifact -StepId '13-verify-parity' -SourceArtifact 'verification-report.md' -AdapterKind 'task'
 $genericKnowledgeBase = New-HandoffArtifact -StepId '15-knowledge-base' -SourceArtifact '13-parity-report.md' -AdapterKind 'task'
 Assert-HandoffAccepted 'generic adapter review reaches verification without a selected migration unit' $genericReview $genericVerification $genericPlan
 Assert-HandoffAccepted 'generic adapter verification reaches parity without a selected migration unit' $genericVerification $genericParity $genericPlan
 Assert-HandoffAccepted 'generic adapter parity reaches terminal KB without a selected migration unit' $genericParity $genericKnowledgeBase $genericPlan
 $packagePlan = New-ApprovedAdapterPlan -AdapterKind package -SelectorApproval 'approval:PACKAGE-ADMIN-LOCK'
 $packageReview = New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -AdapterKind package
@@ -493,21 +509,21 @@ Assert-HandoffRejected 'generic child handoff rejects a concrete parent with an
 Assert-HandoffRejected 'generic child handoff rejects missing parent authority' $parentChildReview $parentChildVerification 'responsibility-evidence-missing' ($parentChildPlan.Replace('| jira:ADMIN-PARENT | 1 |', '| not-applicable | 1 |'))
 Assert-HandoffRejected 'generic child handoff rejects stale parent authority revision' $parentChildReview $parentChildVerification 'responsibility-evidence-missing' ($parentChildPlan.Replace('| jira:ADMIN-PARENT | 1 |', '| jira:ADMIN-PARENT | 0 |'))
 Assert-HandoffRejected 'generic child handoff rejects unresolved parent approval authority' $parentChildReview $parentChildVerification 'responsibility-evidence-missing' ($parentChildPlan.Replace('| approval:TASK-ADMIN-PARENT | not-applicable |', '| approval:TASK-ADMIN-PARENT-PENDING | not-applicable |'))
 $parentSelectorRow = '| WORK-ADMIN-PARENT | task | TASK-ADMIN-PARENT | jira:ADMIN-PARENT | 1 | approval:TASK-ADMIN-PARENT | not-applicable | REQ-001; SC-001; completes within 2 seconds | REQ-001 | incremental/preserve-existing | DESIGN-ADMIN@2 | not-applicable | not-applicable |'
 $childSelectorRow = '| WORK-ADMIN-CHILD | story | STORY-ADMIN-CHILD | ado:ADMIN-CHILD | 1 | approval:STORY-ADMIN-CHILD | TASK-ADMIN-PARENT | REQ-001; SC-001; completes within 2 seconds | REQ-001 | incremental/preserve-existing | DESIGN-ADMIN@2 | WORK-ADMIN-PARENT | DEC-ADMIN-CHILD |'
 $parentWorkRow = '| WORK-ADMIN-PARENT | Parent | yes | none | 1 | REQ-001; SC-001; completes within 2 seconds | REQ-001 | task:TASK-ADMIN-PARENT | complete | ATTEMPT-PARENT-01 | terminal-parent.md | approval:WORK-ADMIN-PARENT |'
 $childWorkRow = '| WORK-ADMIN-CHILD | Child | yes | WORK-ADMIN-PARENT | 2 | REQ-001; SC-001; completes within 2 seconds | REQ-001 | story:STORY-ADMIN-CHILD | in-progress | ATTEMPT-CHILD-01 | none | approval:WORK-ADMIN-CHILD |'
 $reorderedParentSelectorPlan = $parentChildPlan.Replace("$parentSelectorRow`n$childSelectorRow", "$childSelectorRow`n$parentSelectorRow").Replace("$parentWorkRow`n$childWorkRow", "$childWorkRow`n$parentWorkRow")
 Assert-HandoffRejected 'generic child handoff rejects reordered parent selector authority' $parentChildReview $parentChildVerification 'responsibility-evidence-missing' $reorderedParentSelectorPlan
 Assert-HandoffRejected 'caller adapter self-attestation cannot override approved plan authority' $genericReview $genericVerification 'responsibility-evidence-missing' $script:migrationPlan
-Assert-HandoffRejected 'Work Items shorthand alone cannot self-authorize a migration selector' $review $verification 'responsibility-evidence-missing' (New-ApprovedAdapterPlan -OmitSelectorTable)
+Assert-HandoffDiagnosticsExactly 'Work Items shorthand alone cannot self-authorize a migration selector' $review $verification @('ARC-CONTRACT-MISSING-TABLE: Delivery Adapter Selection') (New-ApprovedAdapterPlan -OmitSelectorTable)
 $pendingSelectorPlan = New-ApprovedAdapterPlan -SelectorApproval 'approval:UNIT-ADMIN-LOCK-PENDING'
 $pendingReview = $review.Replace('approval:UNIT-ADMIN-LOCK | incremental', 'approval:UNIT-ADMIN-LOCK-PENDING | incremental')
 $pendingVerification = $verification.Replace('approval:UNIT-ADMIN-LOCK | incremental', 'approval:UNIT-ADMIN-LOCK-PENDING | incremental')
 Assert-HandoffRejected 'pending selector cannot authorize handoff even when both artifacts repeat it' $pendingReview $pendingVerification 'responsibility-evidence-missing' $pendingSelectorPlan
 Assert-HandoffRejected 'stale selector authority revision cannot authorize handoff' $review $verification 'responsibility-evidence-missing' (New-ApprovedAdapterPlan -AuthorityRevision '2')
 $foreignTracePlan = New-ApprovedAdapterPlan -SelectorTraceIds 'REQ-FOREIGN'
 $foreignTraceReview = $review.Replace('| REQ-001 |', '| REQ-FOREIGN |')
 $foreignTraceVerification = $verification.Replace('| REQ-001 |', '| REQ-FOREIGN |')
 Assert-HandoffRejected 'selector trace mismatch against current Work Item cannot authorize handoff even when artifacts repeat it' $foreignTraceReview $foreignTraceVerification 'responsibility-evidence-missing' $foreignTracePlan
 Assert-HandoffRejected 'migration-unit selected row is preserved ordinally across the chain' $review ($verification.Replace('baseline.md#BASE-ADMIN', 'baseline.md#BASE-MUTATED')) 'responsibility-evidence-missing'
@@ -523,24 +539,24 @@ if ($reorderedSelectorPlan -ceq $script:migrationPlan) { throw 'reordered comple
 Assert-HandoffRejected 'approved plan selector order is immutable and matches Work Items' $review $verification 'responsibility-evidence-missing' $reorderedSelectorPlan
 $duplicateOtherSelectorPlan = $script:migrationPlan.Replace(
   '| WORK-ADMIN-LOCK | Admin lock | yes | none | 1 | REQ-001; SC-001; completes within 2 seconds | REQ-001 | migration-unit:UNIT-ADMIN-LOCK | complete | ATTEMPT-ADMIN-01 | terminal-admin.md | approval:WORK-ADMIN-LOCK |',
   "| WORK-ADMIN-LOCK | Admin lock | yes | none | 1 | REQ-001; SC-001; completes within 2 seconds | REQ-001 | migration-unit:UNIT-ADMIN-LOCK | complete | ATTEMPT-ADMIN-01 | terminal-admin.md | approval:WORK-ADMIN-LOCK |`n| WORK-ADMIN-OTHER | Other | no | none | 2 | REQ-001; SC-001; completes within 2 seconds | REQ-001 | none | ready | none | none | pending |`n| WORK-ADMIN-MISSING | Missing | no | none | 3 | REQ-001; SC-001; completes within 2 seconds | REQ-001 | none | ready | none | none | pending |"
 ).Replace(
   '| WORK-ADMIN-LOCK | migration-unit | UNIT-ADMIN-LOCK | 08-migration-plan.md | 1 | approval:UNIT-ADMIN-LOCK | not-applicable | REQ-001; SC-001; completes within 2 seconds | REQ-001 | incremental/preserve-existing | DESIGN-ADMIN@2 | not-applicable | not-applicable |',
   "| WORK-ADMIN-LOCK | migration-unit | UNIT-ADMIN-LOCK | 08-migration-plan.md | 1 | approval:UNIT-ADMIN-LOCK | not-applicable | REQ-001; SC-001; completes within 2 seconds | REQ-001 | incremental/preserve-existing | DESIGN-ADMIN@2 | not-applicable | not-applicable |`n| WORK-ADMIN-OTHER | none | not-applicable | not-applicable | not-applicable | not-applicable | not-applicable | REQ-001; SC-001; completes within 2 seconds | REQ-001 | incremental/preserve-existing | DESIGN-ADMIN@2 | not-applicable | not-applicable |`n| WORK-ADMIN-OTHER | none | not-applicable | not-applicable | not-applicable | not-applicable | not-applicable | REQ-001; SC-001; completes within 2 seconds | REQ-001 | incremental/preserve-existing | DESIGN-ADMIN@2 | not-applicable | not-applicable |"
 )
 if ($duplicateOtherSelectorPlan -ceq $script:migrationPlan) { throw 'duplicate-one/missing-another handoff selector fixture mutation was a silent no-op' }
 Assert-HandoffRejected 'approved plan selector set rejects duplicate-one and missing-another outside current Work Item' $review $verification 'responsibility-evidence-missing' $duplicateOtherSelectorPlan
-Assert-HandoffRejected 'producer-rendered migration review cannot omit task provenance' ($producerReview -replace '(?ms)^## Task Provenance.*?(?=^## )', '') $producerVerification 'responsibility-evidence-missing'
+Assert-HandoffDiagnosticsExactly 'producer-rendered migration review cannot omit task provenance' ($producerReview -replace '(?ms)^## Task Provenance.*?(?=^## )', '') $producerVerification @('ARC-CONTRACT-MISSING-TABLE: Task Provenance')
 Assert-HandoffRejected 'producer-rendered migration review cannot bind a stale final-tree SHA' ($producerReview.Replace('2222222222222222222222222222222222222222 | implementation-report.md', '3333333333333333333333333333333333333333 | implementation-report.md')) $producerVerification 'responsibility-evidence-missing'
 
-Assert-HandoffRejected 'rejects a downstream artifact with no responsibility handoff table' $verification ($parity -replace '(?ms)^## Architecture Responsibility Handoff.*?(?=\z)', '') 'responsibility-owner-missing'
+Assert-HandoffDiagnosticsExactly 'rejects a downstream artifact with no responsibility handoff table' $verification ($parity -replace '(?ms)^## Architecture Responsibility Handoff.*?(?=\z)', '') @('ARC-CONTRACT-MISSING-TABLE: Architecture Responsibility Handoff')
 Assert-HandoffRejected 'rejects a downstream aggregate PASS that hides responsibility BLOCKED' $verification (New-HandoffArtifact -StepId '13-verify-parity' -SourceArtifact 'verification-report.md' -Responsibility 'BLOCKED' -Architecture 'PASS') 'responsibility-waiver-forbidden'
 Assert-HandoffRejected 'rejects an altered responsibility evidence reference' $verification (New-HandoffArtifact -StepId '13-verify-parity' -SourceArtifact 'verification-report.md' -Evidence 'review-report.md#other-evidence') 'responsibility-evidence-missing'
 Assert-HandoffRejected 'rejects unsupported responsibility contract version' $verification (($parity -replace '(?m)^\| 1 \|', '| 2 |') -replace '(?m)^  version: 1$', '  version: 2') 'responsibility-contract-version-invalid'
 Assert-HandoffRejected 'rejects a cross-run or other-work-item provenance handoff' $verification (New-HandoffArtifact -StepId '13-verify-parity' -SourceArtifact 'verification-report.md' -TaskUnit 'WORK-OTHER') 'responsibility-evidence-missing'
 Assert-HandoffRejected 'rejects a handoff that skips an immediate predecessor stage' $verification (New-HandoffArtifact -StepId '15-knowledge-base' -SourceArtifact 'verification-report.md') 'responsibility-evidence-missing'
 
 $blockedReview = New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -Responsibility 'BLOCKED' -Architecture 'BLOCKED'
 $waivedVerification = New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md' -Architecture 'PASS' -Waiver 'approval_source: auto-waive'
 Assert-HandoffRejected 'runtime waiver cannot overwrite a blocked responsibility handoff' $blockedReview $waivedVerification 'responsibility-waiver-forbidden'
 
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/validate-migration-framework.Tests.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/validate-migration-framework.Tests.ps1
index 7271c77..a3dc74d 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/validate-migration-framework.Tests.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/validate-migration-framework.Tests.ps1
@@ -474,21 +474,21 @@ if ($ResponsibilityConformanceOnly) {
     [pscustomobject]@{ Name = 'trace IDs are not owned capabilities'; Path = 'tests/validation/responsibility-conformance.validation.ps1'; Scenario = 'tests/scenarios/responsibility-conformance.Tests.ps1'; From = "`$capabilities = @(& `$splitList `$row['Owned Capability IDs'])"; To = "`$capabilities = @(& `$splitList (`$row['Owned Capability IDs'] + '; ' + `$row['Trace IDs']))"; ExpectedDiagnostics = @('responsibility-capability-mismatch') }
     [pscustomobject]@{ Name = 'classification authority loss'; Path = 'tests/scenarios/responsibility-conformance.Tests.ps1'; Scenario = 'tests/scenarios/responsibility-conformance.Tests.ps1'; From = "[string]`$ClassificationAuthority = 'factual-discovery-evidence',"; To = "[string]`$ClassificationAuthority = 'agent-opinion',"; ExpectedDiagnostics = @('exemplar-classification-authority-missing') }
     [pscustomobject]@{ Name = 'greenfield approved authority rejection'; Path = 'tests/validation/responsibility-conformance.validation.ps1'; Scenario = 'tests/scenarios/responsibility-conformance.Tests.ps1'; From = "`$row['Architecture Authority'] -cne 'approved-greenfield-design'"; To = "`$row['Architecture Authority'] -cne 'target-exemplar'"; ExpectedDiagnostics = @('greenfield-authority-invalid') }
     [pscustomobject]@{ Name = 'greenfield fake deviation'; Path = 'tests/validation/responsibility-conformance.validation.ps1'; Scenario = 'tests/scenarios/responsibility-conformance.Tests.ps1'; From = "`$row['Architecture Authority'] -cne 'approved-greenfield-design'"; To = "`$row['Architecture Authority'] -cnotin @('approved-greenfield-design', 'approved-structural-deviation')"; ExpectedDiagnostics = @('greenfield-authority-invalid') }
     [pscustomobject]@{ Name = 'multi-capability approval removal'; Path = 'tests/scenarios/responsibility-conformance.Tests.ps1'; Scenario = 'tests/scenarios/responsibility-conformance.Tests.ps1'; From = '$featureLocalDesign = New-ResponsibilityDesignFixture'; To = "`$featureLocalDesign = New-ResponsibilityDesignFixture -OwnedCapabilities 'CAP-ADMIN-LOCK; CAP-ADMIN-AUDIT'"; ExpectedDiagnostics = @('co-location-approval-missing') }
     [pscustomobject]@{ Name = 'extra public symbol while tree matches'; Path = 'tests/scenarios/responsibility-conformance.Tests.ps1'; Scenario = 'tests/scenarios/responsibility-conformance.Tests.ps1'; From = "[string]`$OwnerSymbol = 'AdminWifi',"; To = "[string]`$OwnerSymbol = 'WifiResetProvider',"; ExpectedDiagnostics = @('responsibility-public-symbol-mismatch') }
     [pscustomobject]@{ Name = 'extra effect while tree matches'; Path = 'tests/scenarios/responsibility-conformance.Tests.ps1'; Scenario = 'tests/scenarios/responsibility-conformance.Tests.ps1'; From = "[string]`$Effect = 'none',"; To = "[string]`$Effect = 'settings.write:wifi-reset',"; ExpectedDiagnostics = @('responsibility-external-effect-mismatch') }
     [pscustomobject]@{ Name = 'invalid verification not-applicable'; Path = 'tests/scenarios/responsibility-conformance.Tests.ps1'; Scenario = 'tests/scenarios/responsibility-conformance.Tests.ps1'; From = '| VERIFY-OWNER-WIFI | RESP-WIFI | CAP-ADMIN-WIFI | test/admin_lock_test.ps1 | AdminWifiContract | contract | required | invokes ui/admin_wifi.dart#AdminWifi | not-applicable | PASS | not-applicable | diff:test/admin_lock_test.ps1#AdminWifiContract |'; To = '| VERIFY-OWNER-WIFI | RESP-WIFI | CAP-ADMIN-WIFI | test/admin_lock_test.ps1 | AdminWifiContract | contract | not-applicable-approved | invokes ui/admin_wifi.dart#AdminWifi | approval:OWNER-WIFI | PASS | not-applicable | diff:test/admin_lock_test.ps1#AdminWifiContract |'; ExpectedDiagnostics = @('verification-disposition-invalid') }
     [pscustomobject]@{ Name = 'fake production composition'; Path = 'tests/scenarios/responsibility-conformance.Tests.ps1'; Scenario = 'tests/scenarios/responsibility-conformance.Tests.ps1'; From = '$compositionEvidence = "source:$($PinnedSource.FinalTreeSha):lib/admin_lock_composition.dart#AdminLockComposition'; To = '$compositionEvidence = "source:$($PinnedSource.FinalTreeSha):test/fake_registry.ps1#AdminLockComposition'; ExpectedDiagnostics = @('verification-production-binding-missing') }
     [pscustomobject]@{ Name = 'implementation self-attestation bypass'; Path = 'tests/scenarios/architecture-review.Tests.ps1'; Scenario = 'tests/scenarios/architecture-review.Tests.ps1'; From = "Assert-Pass 'independent review accepts implementation-bound provenance' `$null `$true"; To = "Assert-Pass 'independent review accepts implementation-bound provenance' {`n  param(`$root)`n  Add-SourceSymbolEvidence `$root 'AdminRoute.factoryReset' 'RESP-UNPLANNED'`n  Keep-ImplementationSelfAttestationPass `$root`n} `$true"; ExpectedDiagnostics = @('responsibility-owner-extra', 'responsibility-public-symbol-mismatch') }
-    [pscustomobject]@{ Name = 'downstream sub-verdict loss'; Path = 'tests/scenarios/responsibility-handoff.Tests.ps1'; Scenario = 'tests/scenarios/responsibility-handoff.Tests.ps1'; From = "`$parity = New-HandoffArtifact -StepId '13-verify-parity' -SourceArtifact 'verification-report.md'"; To = "`$parity = (New-HandoffArtifact -StepId '13-verify-parity' -SourceArtifact 'verification-report.md') -replace '(?ms)^## Architecture Responsibility Handoff.*?(?=\z)', ''"; ExpectedDiagnostics = @('responsibility-owner-missing') }
+    [pscustomobject]@{ Name = 'downstream sub-verdict loss'; Path = 'tests/scenarios/responsibility-handoff.Tests.ps1'; Scenario = 'tests/scenarios/responsibility-handoff.Tests.ps1'; From = "`$parity = New-HandoffArtifact -StepId '13-verify-parity' -SourceArtifact 'verification-report.md'"; To = "`$parity = (New-HandoffArtifact -StepId '13-verify-parity' -SourceArtifact 'verification-report.md') -replace '(?ms)^## Architecture Responsibility Handoff.*?(?=\z)', ''"; ExpectedDiagnostics = @('ARC-CONTRACT-MISSING-TABLE: Architecture Responsibility Handoff') }
     [pscustomobject]@{ Name = 'downstream sub-verdict mutation'; Path = 'tests/scenarios/responsibility-handoff.Tests.ps1'; Scenario = 'tests/scenarios/responsibility-handoff.Tests.ps1'; From = "`$parity = New-HandoffArtifact -StepId '13-verify-parity' -SourceArtifact 'verification-report.md'"; To = "`$parity = New-HandoffArtifact -StepId '13-verify-parity' -SourceArtifact 'verification-report.md' -Responsibility 'BLOCKED' -Architecture 'PASS'"; ExpectedDiagnostics = @('responsibility-waiver-forbidden') }
     [pscustomobject]@{ Name = 'runtime waiver override'; Path = 'tests/scenarios/responsibility-handoff.Tests.ps1'; Scenario = 'tests/scenarios/responsibility-handoff.Tests.ps1'; From = "`$verification = New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md'"; To = "`$verification = New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md' -Responsibility 'BLOCKED' -Architecture 'PASS' -Waiver 'approval_source: auto-waive'"; ExpectedDiagnostics = @('responsibility-waiver-forbidden') }
     [pscustomobject]@{ Name = 'post-implementation queue advance'; Path = 'tests/validation/scope-engine.validation.ps1'; Scenario = 'tests/scenarios/scope-engine.Tests.ps1'; From = "`$planWideResponsibilityBlock = & `$resolvePlanWideResponsibilityBlock `$items`n      if (`$null -ne `$planWideResponsibilityBlock) { return `$planWideResponsibilityBlock }"; To = '$planWideResponsibilityBlock = $null'; ExpectedOutput = 'Tree BLOCKED must stop the entire queue' }
   )
 
   for ($caseIndex = 0; $caseIndex -lt $responsibilityMutations.Count; $caseIndex++) {
     $case = $responsibilityMutations[$caseIndex]
     $caseFailureCountBefore = $testFailures.Count
     $sourceDigestBeforeMutation = Get-TreeDigest -Root $testRoot
     $mutationResult = Invoke-IsolatedMutation -SourceRoot $testRoot -Mutation {
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/validate-migration-framework.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/validate-migration-framework.ps1
index 1b952ff..c1a6837 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/validate-migration-framework.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/validate-migration-framework.ps1
@@ -9675,21 +9675,21 @@ function Test-ResponsibilitySourceIntegrity {
     [pscustomobject]@{ Name = 'contract version mixed'; Path = 'tests/scenarios/responsibility-conformance.Tests.ps1'; Token = "Assert-Rejected 'discovery rejects mixed responsibility contract versions'" }
     [pscustomobject]@{ Name = 'capability and trace separation'; Path = 'tests/scenarios/responsibility-conformance.Tests.ps1'; Token = "Assert-DesignAccepted 'multiple trace IDs for one capability do not create multi-capability ownership'" }
     [pscustomobject]@{ Name = 'classification authority loss'; Path = 'tests/scenarios/responsibility-conformance.Tests.ps1'; Token = "Assert-Rejected 'agent cannot self-declare legacy debt'" }
     [pscustomobject]@{ Name = 'greenfield fake deviation'; Path = 'tests/scenarios/responsibility-conformance.Tests.ps1'; Token = "Assert-DesignRejected 'greenfield cannot be converted to fake deviation'" }
     [pscustomobject]@{ Name = 'multi-capability approval removal'; Path = 'tests/scenarios/responsibility-conformance.Tests.ps1'; Token = "Assert-DesignRejected 'aggregate capabilities require approval'" }
     [pscustomobject]@{ Name = 'extra public symbol while tree matches'; Path = 'tests/scenarios/responsibility-conformance.Tests.ps1'; Token = "Assert-ImplementationRejected 'actual matrix rejects public symbol drift even when tree path matches'" }
     [pscustomobject]@{ Name = 'extra effect while tree matches'; Path = 'tests/scenarios/responsibility-conformance.Tests.ps1'; Token = "Assert-ImplementationRejected 'actual matrix rejects external-effect drift'" }
     [pscustomobject]@{ Name = 'invalid verification not-applicable'; Path = 'tests/scenarios/responsibility-conformance.Tests.ps1'; Token = "Assert-ImplementationRejected 'behavior owner cannot use not-applicable-approved verification'" }
     [pscustomobject]@{ Name = 'fake production composition'; Path = 'tests/scenarios/responsibility-conformance.Tests.ps1'; Token = 'Assert-ReviewRejected "review rejects test-only fake production composition evidence' }
     [pscustomobject]@{ Name = 'implementation self-attestation bypass'; Path = 'tests/scenarios/architecture-review.Tests.ps1'; Token = 'Assert-FailsLike "review independently rejects omitted actual owner' }
-    [pscustomobject]@{ Name = 'downstream sub-verdict loss'; Path = 'tests/scenarios/responsibility-handoff.Tests.ps1'; Token = "Assert-HandoffRejected 'rejects a downstream artifact with no responsibility handoff table'" }
+    [pscustomobject]@{ Name = 'downstream sub-verdict loss'; Path = 'tests/scenarios/responsibility-handoff.Tests.ps1'; Token = "Assert-HandoffDiagnosticsExactly 'rejects a downstream artifact with no responsibility handoff table'" }
     [pscustomobject]@{ Name = 'downstream sub-verdict mutation'; Path = 'tests/scenarios/responsibility-handoff.Tests.ps1'; Token = "Assert-HandoffRejected 'rejects a downstream aggregate PASS that hides responsibility BLOCKED'" }
     [pscustomobject]@{ Name = 'runtime waiver override'; Path = 'tests/scenarios/responsibility-handoff.Tests.ps1'; Token = "Assert-HandoffRejected 'runtime waiver cannot overwrite a blocked responsibility handoff'" }
     [pscustomobject]@{ Name = 'post-implementation queue advance'; Path = 'tests/scenarios/scope-engine.Tests.ps1'; Token = "Assert-Equal `$responsibilityChainSelection.work_item_id '' 'No dependent item may be selected after a responsibility mismatch'" }
   )
   foreach ($requirement in $coverage) {
     $path = Join-Path $root $requirement.Path
     if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
     $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
     if ($text.IndexOf($requirement.Token, [StringComparison]::Ordinal) -lt 0) {
       $errors.Add("Responsibility source-integrity coverage missing: $($requirement.Name)")
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1
index a637515..80ad0e1 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1
@@ -23,91 +23,153 @@ function Test-ArcExactSet {
     [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Expected
   )
 
   if ($Actual.Count -ne $Expected.Count) { return $false }
   for ($index = 0; $index -lt $Expected.Count; $index++) {
     if ($Actual[$index] -cne $Expected[$index]) { return $false }
   }
   return $true
 }
 
-function Get-ArcMarkdownH2HeadingMatches {
+function Get-ArcMarkdownFenceOpening {
   [CmdletBinding()]
-  param(
-    [Parameter(Mandatory)][string]$Text,
-    [Parameter(Mandatory)][string]$Heading
-  )
+  param([Parameter(Mandatory)][AllowEmptyString()][string]$Line)
+
+  $openingFence = [regex]::Match($Line, '^[ ]{0,3}(?<fence>`{3,}|~{3,})(?<info>.*)$')
+  if (-not $openingFence.Success) { return $null }
+  $fence = $openingFence.Groups['fence'].Value
+  if ($fence[0] -ceq [char]'`' -and $openingFence.Groups['info'].Value.Contains('`')) { return $null }
+  return $openingFence
+}
+
+function Get-ArcVisibleMarkdownText {
+  [CmdletBinding()]
+  param([Parameter(Mandatory)][string]$Text)
 
-  $headingMatches = [Collections.Generic.List[object]]::new()
+  $visibleText = [Text.StringBuilder]::new()
   $insideFence = $false
   $fenceCharacter = ''
   $fenceLength = 0
+  $insideHtmlComment = $false
   foreach ($lineMatch in @([regex]::Matches($Text, '(?m)^[^\r\n]*(?:\r\n|\n|$)'))) {
     if ($lineMatch.Length -eq 0) { continue }
-    $line = $lineMatch.Value
-    if ($line.EndsWith("`r`n", [StringComparison]::Ordinal)) {
-      $line = $line.Substring(0, $line.Length - 2)
+    $lineWithEnding = $lineMatch.Value
+    $lineEnding = ''
+    if ($lineWithEnding.EndsWith("`r`n", [StringComparison]::Ordinal)) {
+      $lineEnding = "`r`n"
     }
-    elseif ($line.EndsWith("`n", [StringComparison]::Ordinal)) {
-      $line = $line.Substring(0, $line.Length - 1)
+    elseif ($lineWithEnding.EndsWith("`n", [StringComparison]::Ordinal)) {
+      $lineEnding = "`n"
     }
+    $line = $lineWithEnding.Substring(0, $lineWithEnding.Length - $lineEnding.Length)
+    $rawHasH2Marker = -not $insideHtmlComment -and $line -cmatch '^##[ \t]+'
+    $rawHasTableMarker = -not $insideHtmlComment -and $line.StartsWith('|', [StringComparison]::Ordinal)
 
     if ($insideFence) {
       $closingPattern = '^[ ]{0,3}' + [regex]::Escape($fenceCharacter) + '{' + $fenceLength + ',}[ \t]*$'
       if ($line -cmatch $closingPattern) {
         $insideFence = $false
         $fenceCharacter = ''
         $fenceLength = 0
       }
+      if ($line.Length -gt 0) { [void]$visibleText.Append([string]::new([char]' ', $line.Length)) }
+      [void]$visibleText.Append($lineEnding)
       continue
     }
 
-    $openingFence = [regex]::Match($line, '^[ ]{0,3}(?<fence>`{3,}|~{3,}).*$')
-    if ($openingFence.Success) {
+    $openingFence = if ($insideHtmlComment) { $null } else { Get-ArcMarkdownFenceOpening -Line $line }
+    if ($null -ne $openingFence -and $openingFence.Success) {
       $insideFence = $true
       $fenceCharacter = [string]$openingFence.Groups['fence'].Value[0]
       $fenceLength = $openingFence.Groups['fence'].Value.Length
+      if ($line.Length -gt 0) { [void]$visibleText.Append([string]::new([char]' ', $line.Length)) }
+      [void]$visibleText.Append($lineEnding)
       continue
     }
 
-    $headingMatch = [regex]::Match($line, '^##[ \t]+' + [regex]::Escape($Heading) + '[ \t]*$')
-    if ($headingMatch.Success) {
-      $headingMatches.Add([pscustomobject]@{
-        Index = $lineMatch.Index + $headingMatch.Index
-        Length = $headingMatch.Length
-        Value = $headingMatch.Value
-      })
+    $visibleLineBuilder = [Text.StringBuilder]::new()
+    $cursor = 0
+    while ($cursor -lt $line.Length) {
+      if ($insideHtmlComment) {
+        $commentEnd = $line.IndexOf('-->', $cursor, [StringComparison]::Ordinal)
+        if ($commentEnd -lt 0) { $cursor = $line.Length }
+        else { $insideHtmlComment = $false; $cursor = $commentEnd + 3 }
+        continue
+      }
+
+      $commentStart = $line.IndexOf('<!--', $cursor, [StringComparison]::Ordinal)
+      if ($commentStart -lt 0) {
+        [void]$visibleLineBuilder.Append($line.Substring($cursor))
+        $cursor = $line.Length
+        continue
+      }
+      if ($commentStart -gt $cursor) { [void]$visibleLineBuilder.Append($line.Substring($cursor, $commentStart - $cursor)) }
+      $commentEnd = $line.IndexOf('-->', $commentStart + 4, [StringComparison]::Ordinal)
+      if ($commentEnd -lt 0) { $insideHtmlComment = $true; $cursor = $line.Length }
+      else { $cursor = $commentEnd + 3 }
+    }
+
+    $visibleLine = $visibleLineBuilder.ToString()
+    if (-not $rawHasH2Marker -and $visibleLine -cmatch '^##[ \t]+') {
+      $visibleLine = ' ' + $visibleLine.Substring(1)
     }
+    if (-not $rawHasTableMarker -and $visibleLine.StartsWith('|', [StringComparison]::Ordinal)) {
+      $visibleLine = ' ' + $visibleLine.Substring(1)
+    }
+    [void]$visibleText.Append($visibleLine)
+    [void]$visibleText.Append($lineEnding)
   }
-  return $headingMatches.ToArray()
+  return $visibleText.ToString()
+}
+
+function Get-ArcMarkdownH2HeadingPattern {
+  [CmdletBinding()]
+  param([Parameter(Mandatory)][string]$Heading)
+
+  $headingTokens = @([regex]::Split($Heading.Trim(), '[ \t]+') | Where-Object { $_ -ne '' } | ForEach-Object { [regex]::Escape($_) })
+  return '(?m)^##[ \t]+' + ($headingTokens -join '[ \t]+') + '[ \t]*(?=\r?$)'
+}
+
+function Get-ArcMarkdownH2HeadingMatches {
+  [CmdletBinding()]
+  param(
+    [Parameter(Mandatory)][string]$Text,
+    [Parameter(Mandatory)][string]$Heading
+  )
+
+  $visibleText = Get-ArcVisibleMarkdownText -Text $Text
+  $headingPattern = Get-ArcMarkdownH2HeadingPattern -Heading $Heading
+  return @([regex]::Matches($visibleText, $headingPattern))
 }
 
 function Get-ArcStrictMarkdownTable {
   [CmdletBinding()]
   param(
     [Parameter(Mandatory)][string]$Text,
     [Parameter(Mandatory)][string]$Heading,
     [Parameter(Mandatory)][string[]]$Columns,
     [Parameter(Mandatory)][AllowEmptyCollection()][Collections.Generic.List[string]]$Errors
   )
 
-  $headingMatches = @(Get-ArcMarkdownH2HeadingMatches -Text $Text -Heading $Heading)
+  $visibleText = Get-ArcVisibleMarkdownText -Text $Text
+  $headingPattern = Get-ArcMarkdownH2HeadingPattern -Heading $Heading
+  $headingMatches = @([regex]::Matches($visibleText, $headingPattern))
   if ($headingMatches.Count -eq 0) {
     $Errors.Add("ARC-CONTRACT-MISSING-TABLE: $Heading")
     return @()
   }
   if ($headingMatches.Count -ne 1) {
     $Errors.Add("ARC-CONTRACT-HEADING-CARDINALITY: $Heading")
     return @()
   }
   $headingMatch = $headingMatches[0]
-  $remaining = $Text.Substring($headingMatch.Index + $headingMatch.Length)
+  $remaining = $visibleText.Substring($headingMatch.Index + $headingMatch.Length)
   $lines = @($remaining -split '\r?\n')
   $tableLines = [Collections.Generic.List[string]]::new()
   foreach ($line in $lines) {
     if ([string]::IsNullOrWhiteSpace($line) -and $tableLines.Count -eq 0) { continue }
     if ($line -match '^##\s+') { break }
     if ($line -match '^\|') { $tableLines.Add($line); continue }
     if ($tableLines.Count -gt 0) { break }
   }
   if ($tableLines.Count -lt 3) {
     $Errors.Add("ARC-CONTRACT-MALFORMED-TABLE: $Heading")
@@ -155,61 +217,61 @@ function Test-ResponsibilityContractSchema {
   else {
     foreach ($field in @('version: 1', 'applicability: required')) {
       if (@([regex]::Matches($frontMatter, '(?m)^' + [regex]::Escape($field) + '\s*$')).Count -ne 1) {
         $errors.Add("ARC-CONTRACT-FRONT-MATTER: required field is invalid: $field")
       }
     }
   }
 
   $headings = @(
     'Contract Version', 'Exemplar Classification', 'Architecture Authority',
-    'File Responsibility Matrix', 'Co-location Semantics',
-    'Verification Ownership Matrix', 'Actual Responsibility Evidence',
+    'Co-location Semantics', 'Actual Responsibility Evidence',
     'Review Verdicts', 'Downstream Handoff', 'Compatibility and Rollout',
     'Stable Diagnostics'
   )
   foreach ($heading in $headings) {
-    $count = @([regex]::Matches($ContractText, '(?m)^##\s+' + [regex]::Escape($heading) + '\s*$')).Count
+    $count = @(Get-ArcMarkdownH2HeadingMatches -Text $ContractText -Heading $heading).Count
     if ($count -ne 1) { $errors.Add("ARC-CONTRACT-HEADING: $heading") }
   }
 
+  $responsibilityRows = @(Get-ArcStrictMarkdownTable -Text $ContractText -Heading 'File Responsibility Matrix' -Columns @(
+    'Responsibility ID', 'Owner Path', 'Owner Symbol', 'Boundary Kind',
+    'Primary Responsibility', 'Owned Capability IDs', 'Trace IDs', 'Atomic Boundary ID',
+    'Public Symbols', 'External Effects', 'Target Exemplar', 'Exemplar Classification',
+    'Classification Authority', 'Classification Evidence', 'Architecture Authority',
+    'Co-location Policy', 'Co-location Evidence', 'Verification Owner References',
+    'Conformance', 'Deviation Reference'
+  ) -Errors $errors)
+  $verificationRows = @(Get-ArcStrictMarkdownTable -Text $ContractText -Heading 'Verification Ownership Matrix' -Columns @(
+    'Verification Owner ID', 'Production Responsibility ID', 'Capability ID',
+    'Evidence Path', 'Evidence Symbol or Scenario', 'Evidence Kind',
+    'Verification Disposition', 'Production Binding Evidence', 'Decision Reference',
+    'Verdict', 'Deviation Reference'
+  ) -Errors $errors)
+  if ($errors.Count -ne 0) { return $errors.ToArray() }
+
   foreach ($required in @(
     'version = 1', 'applicability = required',
     'Inspection Status = verified | no-equivalent | unknown',
     'Classification = preferred | compatibility-only | legacy-debt | no-equivalent',
     'Architecture Authority = target-exemplar | approved-greenfield-design | approved-structural-deviation',
     'Boundary Kind = domain | data | application | presentation | adapter | integration | config | test | project-defined',
     'Conformance = yes | no | blocked',
     'Co-location Policy = feature-local | shared-foundation | atomic-owner | approved-deviation | not-applicable',
     'Evidence Kind = unit | integration | contract | production-composition | static-structure | generator-verification',
     'Verification Disposition = required | not-applicable-approved',
     'Verdict = PASS | BLOCKED'
   )) {
     if ($ContractText.IndexOf($required, [StringComparison]::Ordinal) -lt 0) {
       $errors.Add("ARC-CONTRACT-ENUM: $required")
     }
   }
-
-  $responsibilityRows = @(Get-ArcStrictMarkdownTable -Text $ContractText -Heading 'File Responsibility Matrix' -Columns @(
-    'Responsibility ID', 'Owner Path', 'Owner Symbol', 'Boundary Kind',
-    'Primary Responsibility', 'Owned Capability IDs', 'Trace IDs', 'Atomic Boundary ID',
-    'Public Symbols', 'External Effects', 'Target Exemplar', 'Exemplar Classification',
-    'Classification Authority', 'Classification Evidence', 'Architecture Authority',
-    'Co-location Policy', 'Co-location Evidence', 'Verification Owner References',
-    'Conformance', 'Deviation Reference'
-  ) -Errors $errors)
-  $verificationRows = @(Get-ArcStrictMarkdownTable -Text $ContractText -Heading 'Verification Ownership Matrix' -Columns @(
-    'Verification Owner ID', 'Production Responsibility ID', 'Capability ID',
-    'Evidence Path', 'Evidence Symbol or Scenario', 'Evidence Kind',
-    'Verification Disposition', 'Production Binding Evidence', 'Decision Reference',
-    'Verdict', 'Deviation Reference'
-  ) -Errors $errors)
   $evidenceKinds = @('unit', 'integration', 'contract', 'production-composition', 'static-structure', 'generator-verification')
   $verificationDispositions = @('required', 'not-applicable-approved')
   for ($rowIndex = 2; $rowIndex -lt $verificationRows.Count; $rowIndex++) {
     if ($verificationRows[$rowIndex][0] -cnotmatch '^(?:VERIFY-OWNER-###|VERIFY-OWNER-[A-Z0-9]+(?:-[A-Z0-9]+)*)$') {
       $errors.Add('ARC-CONTRACT-VERIFICATION-ID-FAMILY: Verification Owner ID must use VERIFY-OWNER-*')
     }
     if ($evidenceKinds -cnotcontains $verificationRows[$rowIndex][5]) {
       $errors.Add('ARC-CONTRACT-VERIFICATION-EVIDENCE-KIND: Evidence Kind must be canonical')
     }
     if ($verificationDispositions -cnotcontains $verificationRows[$rowIndex][6]) {
@@ -473,22 +535,21 @@ function Test-ResponsibilityDesign {
   )
   $verificationColumns = @(
     'Verification Owner ID', 'Production Responsibility ID', 'Capability ID',
     'Evidence Path', 'Evidence Symbol or Scenario', 'Evidence Kind',
     'Verification Disposition', 'Production Binding Evidence', 'Decision Reference',
     'Verdict', 'Deviation Reference'
   )
   $plannedTable = @(Get-ArcStrictMarkdownTable -Text $DesignText -Heading 'Planned File Tree' -Columns $plannedColumns -Errors $errors)
   $responsibilityTable = @(Get-ArcStrictMarkdownTable -Text $DesignText -Heading 'File Responsibility Matrix' -Columns $responsibilityColumns -Errors $errors)
   $verificationTable = @(Get-ArcStrictMarkdownTable -Text $DesignText -Heading 'Verification Ownership Matrix' -Columns $verificationColumns -Errors $errors)
-  if (@([regex]::Matches($DesignText, '(?m)^##\s+File Responsibility Matrix\s*$')).Count -ne 1) { $errors.Add('responsibility-owner-extra') }
-  if (@([regex]::Matches($DesignText, '(?m)^##\s+Verification Ownership Matrix\s*$')).Count -ne 1) { $errors.Add('verification-owner-extra') }
+  if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }
   if ($plannedTable.Count -lt 3 -or $responsibilityTable.Count -lt 3 -or $verificationTable.Count -lt 3) {
     return @($errors | Select-Object -Unique)
   }
 
   $plannedRows = @($plannedTable | Select-Object -Skip 2)
   $responsibilityRows = @($responsibilityTable | Select-Object -Skip 2)
   $verificationRows = @($verificationTable | Select-Object -Skip 2)
   $normalizePath = { param([string]$Value) ($Value -replace '\\', '/') }
   $toRow = {
     param([string[]]$Cells, [string[]]$Columns)
@@ -708,20 +769,21 @@ function Test-ResponsibilityPlan {
     @([regex]::Matches($planFrontMatter, '(?m)^result:\s*complete\s*$')).Count -ne 1 -or
     $planRunMatches.Count -ne 1 -or
     (
       ($planIsApproved -and -not $approvedPlanKeyShape) -or
       (-not $planIsApproved -and -not $draftPlanKeyShape) -or
       -not $planRevisionShapeValid
     )
   ) {
     $errors.Add('responsibility-owner-extra')
   }
+  if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }
 
   $responsibilityColumns = @(
     'Responsibility ID', 'Owner Path', 'Owner Symbol', 'Boundary Kind',
     'Primary Responsibility', 'Owned Capability IDs', 'Trace IDs', 'Atomic Boundary ID',
     'Public Symbols', 'External Effects', 'Target Exemplar', 'Exemplar Classification',
     'Classification Authority', 'Classification Evidence', 'Architecture Authority',
     'Co-location Policy', 'Co-location Evidence', 'Verification Owner References',
     'Conformance', 'Deviation Reference'
   )
   $verificationColumns = @(
@@ -737,29 +799,25 @@ function Test-ResponsibilityPlan {
   $planColumns = @(
     'Work Item ID', 'Design Revision', 'Responsibility IDs', 'Shared Foundation IDs',
     'Integration Responsibility IDs', 'Independent Boundary Evidence'
   )
 
   $designResponsibilityTable = @(Get-ArcStrictMarkdownTable -Text $DesignText -Heading 'File Responsibility Matrix' -Columns $responsibilityColumns -Errors $errors)
   $designVerificationTable = @(Get-ArcStrictMarkdownTable -Text $DesignText -Heading 'Verification Ownership Matrix' -Columns $verificationColumns -Errors $errors)
   $adapterTable = @(Get-ArcStrictMarkdownTable -Text $PlanText -Heading 'Work Item Adapter Trace' -Columns $adapterColumns -Errors $errors)
   $planTable = @(Get-ArcStrictMarkdownTable -Text $PlanText -Heading 'Responsibility Owner References' -Columns $planColumns -Errors $errors)
   $decisionColumns = @('Decision Reference', 'Parent Work Item ID', 'Child Work Item ID', 'Master Plan Reference', 'Master Plan Revision', 'Design Revision', 'Approval Reference', 'Immutable Evidence Reference')
-  $decisionHeadingCount = @([regex]::Matches($DesignText, '(?m)^##\s+Approved Decomposition Decisions\s*$')).Count
-  $decisionTable = @(if ($decisionHeadingCount -eq 1) {
+  $decisionHeadingCount = @(Get-ArcMarkdownH2HeadingMatches -Text $DesignText -Heading 'Approved Decomposition Decisions').Count
+  $decisionTable = @(if ($decisionHeadingCount -ne 0) {
     Get-ArcStrictMarkdownTable -Text $DesignText -Heading 'Approved Decomposition Decisions' -Columns $decisionColumns -Errors $errors
   })
-  if (@([regex]::Matches($DesignText, '(?m)^##\s+File Responsibility Matrix\s*$')).Count -ne 1) { $errors.Add('responsibility-owner-extra') }
-  if (@([regex]::Matches($DesignText, '(?m)^##\s+Verification Ownership Matrix\s*$')).Count -ne 1) { $errors.Add('verification-owner-extra') }
-  if (@([regex]::Matches($PlanText, '(?m)^##\s+Work Item Adapter Trace\s*$')).Count -ne 1) { $errors.Add('responsibility-owner-extra') }
-  if (@([regex]::Matches($PlanText, '(?m)^##\s+Responsibility Owner References\s*$')).Count -ne 1) { $errors.Add('responsibility-owner-extra') }
-  if ($decisionHeadingCount -gt 1) { $errors.Add('responsibility-owner-extra') }
+  if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }
   if ($designResponsibilityTable.Count -lt 3 -or $designVerificationTable.Count -lt 3 -or $adapterTable.Count -lt 3 -or $planTable.Count -lt 3) {
     return @($errors | Select-Object -Unique)
   }
 
   $toRow = {
     param([string[]]$Cells, [string[]]$Columns)
     $row = [ordered]@{}
     for ($index = 0; $index -lt $Columns.Count; $index++) { $row[$Columns[$index]] = $Cells[$index] }
     return $row
   }
@@ -1023,29 +1081,32 @@ function Test-ResponsibilityImplementation {
     return @($errors | Select-Object -Unique)
   }
   if (@(Test-ArcDiscoveryResponsibilityContractVersion -DiscoveryText $ImplementationText).Count -ne 0) {
     $errors.Add('responsibility-contract-version-invalid')
     return @($errors | Select-Object -Unique)
   }
 
   $implementationSelectorColumns = @('Work Item ID', 'Adapter Kind', 'External ID', 'Authority', 'Authority Revision', 'Approval Reference', 'Parent Selector', 'Acceptance', 'Trace IDs', 'Mode Constraint', 'Design Revision', 'Parent Work Item ID', 'Decomposition Decision Reference', 'Canonical Match')
   $implementationSelectedUnitColumns = @('Migration Unit ID', 'Plan Reference', 'Approval Reference', 'Mode Constraint', 'Bootstrap Scope', 'Foundation Baseline ID', 'Foundation Baseline Reference', 'Foundation Baseline Approval Reference', 'Baseline Reference', 'Trace IDs')
   $implementationSelectorTable = @(Get-ArcStrictMarkdownTable -Text $ImplementationText -Heading 'Canonical Adapter Evidence' -Columns $implementationSelectorColumns -Errors $errors)
+  if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }
   if ($implementationSelectorTable.Count -ne 3) { $errors.Add('responsibility-evidence-missing'); return @($errors | Select-Object -Unique) }
   $implementationSelector = [ordered]@{}
   for ($index = 0; $index -lt $implementationSelectorColumns.Count; $index++) { $implementationSelector[$implementationSelectorColumns[$index]] = [string]$implementationSelectorTable[2][$index] }
-  $selectedHeadingCount = @([regex]::Matches($ImplementationText, '(?m)^##\s+Selected Migration Unit\s*$')).Count
+  $selectedHeadingCount = @(Get-ArcMarkdownH2HeadingMatches -Text $ImplementationText -Heading 'Selected Migration Unit').Count
   if ($implementationSelector['Canonical Match'] -cne 'PASS' -or $implementationSelector['Work Item ID'] -cnotmatch '^WORK-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -or $implementationSelector['Adapter Kind'] -cnotin @('migration-unit', 'task', 'story', 'package', 'phase', 'milestone', 'none')) {
     $errors.Add('responsibility-evidence-missing')
   }
+  if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }
   if ($implementationSelector['Adapter Kind'] -ceq 'migration-unit') {
     $selectedTable = @(Get-ArcStrictMarkdownTable -Text $ImplementationText -Heading 'Selected Migration Unit' -Columns $implementationSelectedUnitColumns -Errors $errors)
+    if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }
     if ($selectedHeadingCount -ne 1 -or $selectedTable.Count -ne 3 -or $implementationSelector['Authority'] -cmatch '@' -or $implementationSelector['Authority Revision'] -cnotmatch '^[1-9][0-9]*$') { $errors.Add('responsibility-evidence-missing') }
     else {
       $selected = [ordered]@{}
       for ($index = 0; $index -lt $implementationSelectedUnitColumns.Count; $index++) { $selected[$implementationSelectedUnitColumns[$index]] = [string]$selectedTable[2][$index] }
       if ($selected['Migration Unit ID'] -cne $implementationSelector['External ID'] -or $selected['Plan Reference'] -cne "$($implementationSelector['Authority'])@$($implementationSelector['Authority Revision'])" -or $selected['Approval Reference'] -cne $implementationSelector['Approval Reference'] -or $selected['Mode Constraint'] -cne $implementationSelector['Mode Constraint'] -or $selected['Trace IDs'] -cne $implementationSelector['Trace IDs']) { $errors.Add('responsibility-evidence-missing') }
     }
   }
   elseif ($selectedHeadingCount -ne 0) { $errors.Add('responsibility-evidence-missing') }
   if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }
 
@@ -1066,24 +1127,22 @@ function Test-ResponsibilityImplementation {
   $actualResponsibilityColumns = @($responsibilityColumns + 'Actual Evidence')
   $actualVerificationColumns = @($verificationColumns + 'Actual Evidence')
   $ownerReferenceColumns = @('Work Item ID', 'Design Revision', 'Responsibility IDs', 'Shared Foundation IDs', 'Integration Responsibility IDs', 'Independent Boundary Evidence')
   $verdictColumns = @('Responsibility Contract Version', 'Tree Conformance', 'Responsibility Conformance', 'Verification Ownership', 'Architecture Conformance State', 'Evidence References')
   $designResponsibilityTable = @(Get-ArcStrictMarkdownTable -Text $DesignText -Heading 'File Responsibility Matrix' -Columns $responsibilityColumns -Errors $errors)
   $designVerificationTable = @(Get-ArcStrictMarkdownTable -Text $DesignText -Heading 'Verification Ownership Matrix' -Columns $verificationColumns -Errors $errors)
   $actualResponsibilityTable = @(Get-ArcStrictMarkdownTable -Text $ImplementationText -Heading 'Actual File Responsibility Matrix' -Columns $actualResponsibilityColumns -Errors $errors)
   $actualVerificationTable = @(Get-ArcStrictMarkdownTable -Text $ImplementationText -Heading 'Actual Verification Ownership Matrix' -Columns $actualVerificationColumns -Errors $errors)
   $ownerReferenceTable = @(Get-ArcStrictMarkdownTable -Text $ImplementationText -Heading 'Responsibility Owner References' -Columns $ownerReferenceColumns -Errors $errors)
   $verdictTable = @(Get-ArcStrictMarkdownTable -Text $ImplementationText -Heading 'Architecture Responsibility Verdicts' -Columns $verdictColumns -Errors $errors)
-  foreach ($heading in @('Actual File Responsibility Matrix', 'Actual Verification Ownership Matrix', 'Responsibility Owner References', 'Architecture Responsibility Verdicts')) {
-    if (@([regex]::Matches($ImplementationText, '(?m)^##\s+' + [regex]::Escape($heading) + '\s*$')).Count -ne 1) { $errors.Add('responsibility-owner-extra') }
-  }
-  if ($errors.Count -ne 0 -or $designResponsibilityTable.Count -lt 3 -or $designVerificationTable.Count -lt 3 -or $actualResponsibilityTable.Count -lt 3 -or $actualVerificationTable.Count -lt 3 -or $ownerReferenceTable.Count -lt 3 -or $verdictTable.Count -lt 3) {
+  if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }
+  if ($designResponsibilityTable.Count -lt 3 -or $designVerificationTable.Count -lt 3 -or $actualResponsibilityTable.Count -lt 3 -or $actualVerificationTable.Count -lt 3 -or $ownerReferenceTable.Count -lt 3 -or $verdictTable.Count -lt 3) {
     return @($errors | Select-Object -Unique)
   }
 
   $toRow = {
     param([object]$Cells, [string[]]$Columns)
     $row = @{}
     for ($index = 0; $index -lt $Columns.Count; $index++) { $row[$Columns[$index]] = [string]$Cells[$index] }
     return $row
   }
   $allDesignResponsibilities = @($designResponsibilityTable | Select-Object -Skip 2 | ForEach-Object { & $toRow $_ $responsibilityColumns })
@@ -1192,22 +1251,27 @@ function Get-ArcApprovedReviewDesignRevision {
     return ''
   }
   return $revisionMatches[0].Groups['value'].Value
 }
 
 function Get-ArcImplementationReviewProvenance {
   [CmdletBinding()]
   param([Parameter(Mandatory)][string]$ImplementationText, [Parameter(Mandatory)][AllowEmptyCollection()][Collections.Generic.List[string]]$Errors)
 
   $columns = @('Task / Unit', 'File', 'File Kind', 'Edited Region / Symbol', 'Formatter Command', 'Unrelated Diff', 'Checkpoint History', 'Task-base SHA', 'Final-tree SHA')
-  $table = @(Get-ArcStrictMarkdownTable -Text $ImplementationText -Heading 'Change Hygiene' -Columns $columns -Errors $Errors)
-  if (@([regex]::Matches($ImplementationText, '(?m)^##\s+Change Hygiene\s*$')).Count -ne 1 -or $table.Count -lt 3) {
+  $tableErrors = [Collections.Generic.List[string]]::new()
+  $table = @(Get-ArcStrictMarkdownTable -Text $ImplementationText -Heading 'Change Hygiene' -Columns $columns -Errors $tableErrors)
+  if ($tableErrors.Count -ne 0) {
+    foreach ($tableError in $tableErrors) { $Errors.Add($tableError) }
+    return $null
+  }
+  if ($table.Count -lt 3) {
     $Errors.Add('responsibility-evidence-missing')
     return $null
   }
   $rows = @($table | Select-Object -Skip 2)
   $taskUnits = @($rows | ForEach-Object { $_[0].Trim() } | Sort-Object -Unique)
   $taskBases = @($rows | ForEach-Object { $_[7].Trim() } | Sort-Object -Unique)
   $finalTrees = @($rows | ForEach-Object { $_[8].Trim() } | Sort-Object -Unique)
   if ($taskUnits.Count -ne 1 -or $taskUnits[0] -cnotmatch '^(?:WORK|UNIT)-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -or $taskBases.Count -ne 1 -or $finalTrees.Count -ne 1 -or $taskBases[0] -cnotmatch '^[0-9a-f]{40}$' -or $finalTrees[0] -cnotmatch '^[0-9a-f]{40}$') {
     $Errors.Add('responsibility-evidence-missing')
     return $null
@@ -1516,21 +1580,22 @@ function Test-ResponsibilityReview {
   $selectedUnitColumns = @('Migration Unit ID', 'Plan Reference', 'Approval Reference', 'Mode Constraint', 'Bootstrap Scope', 'Foundation Baseline ID', 'Foundation Baseline Reference', 'Foundation Baseline Approval Reference', 'Baseline Reference', 'Trace IDs')
   $workItemColumns = @('Work Item ID', 'Title', 'Required', 'Dependencies', 'Plan Order', 'Acceptance', 'Trace IDs', 'Delivery Adapter', 'Status', 'Latest Attempt', 'Terminal Evidence', 'Approval Reference')
   $implementationScopeTable = @(Get-ArcStrictMarkdownTable -Text $ImplementationText -Heading 'Master Scope Context' -Columns $scopeColumns -Errors $errors)
   $reviewScopeTable = @(Get-ArcStrictMarkdownTable -Text $ReviewText -Heading 'Master Scope Context' -Columns $scopeColumns -Errors $errors)
   $implementationSelectorTable = @(Get-ArcStrictMarkdownTable -Text $ImplementationText -Heading 'Canonical Adapter Evidence' -Columns $implementationSelectorColumns -Errors $errors)
   $reviewProvenanceTable = @(Get-ArcStrictMarkdownTable -Text $ReviewText -Heading 'Task Provenance' -Columns $provenanceColumns -Errors $errors)
   $reviewHandoffTable = @(Get-ArcStrictMarkdownTable -Text $ReviewText -Heading 'Architecture Responsibility Handoff' -Columns $handoffColumns -Errors $errors)
   $planFrontMatter = if ([string]::IsNullOrWhiteSpace($ApprovedPlanText)) { $null } else { Get-ArcBoundedFrontMatter -Text $ApprovedPlanText }
   $planSelectorTable = if ([string]::IsNullOrWhiteSpace($ApprovedPlanText)) { @() } else { @(Get-ArcStrictMarkdownTable -Text $ApprovedPlanText -Heading 'Delivery Adapter Selection' -Columns $selectorColumns -Errors $errors) }
   $planWorkItemTable = if ([string]::IsNullOrWhiteSpace($ApprovedPlanText)) { @() } else { @(Get-ArcStrictMarkdownTable -Text $ApprovedPlanText -Heading 'Work Items' -Columns $workItemColumns -Errors $errors) }
-  if ($errors.Count -ne 0 -or $implementationScopeTable.Count -ne 3 -or $reviewScopeTable.Count -ne 3 -or $implementationSelectorTable.Count -ne 3 -or $reviewProvenanceTable.Count -ne 3 -or $reviewHandoffTable.Count -ne 3 -or $planSelectorTable.Count -lt 3 -or $planWorkItemTable.Count -lt 3 -or $null -eq $planFrontMatter) {
+  if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }
+  if ($implementationScopeTable.Count -ne 3 -or $reviewScopeTable.Count -ne 3 -or $implementationSelectorTable.Count -ne 3 -or $reviewProvenanceTable.Count -ne 3 -or $reviewHandoffTable.Count -ne 3 -or $planSelectorTable.Count -lt 3 -or $planWorkItemTable.Count -lt 3 -or $null -eq $planFrontMatter) {
     $errors.Add('responsibility-evidence-missing')
     return @($errors | Select-Object -Unique)
   }
   $rowFromTable = {
     param([object[]]$Table, [string[]]$Columns)
     $row = [ordered]@{}
     for ($index = 0; $index -lt $Columns.Count; $index++) { $row[$Columns[$index]] = [string]$Table[2][$index] }
     return $row
   }
   $implementationScope = & $rowFromTable $implementationScopeTable $scopeColumns
@@ -1575,36 +1640,40 @@ function Test-ResponsibilityReview {
   if ($planWorkItem['Acceptance'] -cne $planSelector['Acceptance'] -or $planWorkItem['Trace IDs'] -cne $planSelector['Trace IDs'] -or ($planWorkItem['Delivery Adapter'] -cne $expectedDeliveryAdapter -and -not ($planSelector['Adapter Kind'] -ceq 'none' -and $planWorkItem['Delivery Adapter'] -cmatch '^generic:[A-Za-z0-9][A-Za-z0-9._-]*$'))) {
     $errors.Add('responsibility-evidence-missing')
   }
   $reviewAdapterMatches = @([regex]::Matches($ReviewText, '(?im)^[ \t]*-[ \t]*Delivery Adapter Kind:[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$'))
   if ($reviewAdapterMatches.Count -ne 1 -or $reviewAdapterMatches[0].Groups['value'].Value.Trim() -cne $planSelector['Adapter Kind']) { $errors.Add('responsibility-evidence-missing') }
   $reviewProvenance = & $rowFromTable $reviewProvenanceTable $provenanceColumns
   $expectedTaskUnit = if ($planSelector['Adapter Kind'] -ceq 'migration-unit') { $planSelector['External ID'] } else { $reviewScope['Work Item ID'] }
   if ($reviewProvenance['Task / Unit'] -cne $expectedTaskUnit -or $reviewProvenance['Task-base SHA'] -cne $TaskBaseSha -or $reviewProvenance['Final-tree SHA'] -cne $FinalTreeSha -or $reviewProvenance['Task-base SHA'] -cnotmatch '^[0-9a-f]{40}$' -or $reviewProvenance['Final-tree SHA'] -cnotmatch '^[0-9a-f]{40}$' -or $reviewProvenance['Source Artifact'] -cne 'implementation-report.md') {
     $errors.Add('responsibility-evidence-missing')
   }
+  if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }
   $implementationProvenanceEnvelope = Get-ArcImplementationReviewProvenance -ImplementationText $ImplementationText -Errors $errors
+  if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }
   if ($null -eq $implementationProvenanceEnvelope -or $implementationProvenanceEnvelope.TaskUnit -cne $expectedTaskUnit -or $implementationProvenanceEnvelope.TaskBaseSha -cne $TaskBaseSha -or $implementationProvenanceEnvelope.FinalTreeSha -cne $FinalTreeSha) {
     $errors.Add('responsibility-evidence-missing')
   }
   $reviewHandoff = & $rowFromTable $reviewHandoffTable $handoffColumns
   $expectedSourceDiff = "source-diff:$TaskBaseSha..$FinalTreeSha#$($reviewScope['Work Item ID'])"
   $derivedHandoff = if ($reviewHandoff['Tree Conformance'] -ceq 'PASS' -and $reviewHandoff['Responsibility Conformance'] -ceq 'PASS' -and $reviewHandoff['Verification Ownership'] -ceq 'PASS') { 'PASS' } else { 'BLOCKED' }
   if ($reviewHandoff['Responsibility Contract Version'] -cne '1') { $errors.Add('responsibility-contract-version-invalid') }
   if (@('Tree Conformance', 'Responsibility Conformance', 'Verification Ownership') | Where-Object { $reviewHandoff[$_] -cnotin @('PASS', 'BLOCKED') }) { $errors.Add('responsibility-evidence-missing') }
   if ($reviewHandoff['Architecture Conformance State'] -cne $derivedHandoff) { $errors.Add('responsibility-waiver-forbidden') }
   if ($reviewHandoff['Evidence References'] -cne $expectedSourceDiff) { $errors.Add('responsibility-evidence-missing') }
-  $implementationSelectedHeadingCount = @([regex]::Matches($ImplementationText, '(?m)^##\s+Selected Migration Unit\s*$')).Count
-  $reviewSelectedHeadingCount = @([regex]::Matches($ReviewText, '(?m)^##\s+Selected Migration Unit\s*$')).Count
+  if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }
+  $implementationSelectedHeadingCount = @(Get-ArcMarkdownH2HeadingMatches -Text $ImplementationText -Heading 'Selected Migration Unit').Count
+  $reviewSelectedHeadingCount = @(Get-ArcMarkdownH2HeadingMatches -Text $ReviewText -Heading 'Selected Migration Unit').Count
   if ($planSelector['Adapter Kind'] -ceq 'migration-unit') {
     $implementationSelectedTable = @(Get-ArcStrictMarkdownTable -Text $ImplementationText -Heading 'Selected Migration Unit' -Columns $selectedUnitColumns -Errors $errors)
     $reviewSelectedTable = @(Get-ArcStrictMarkdownTable -Text $ReviewText -Heading 'Selected Migration Unit' -Columns $selectedUnitColumns -Errors $errors)
+    if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }
     if ($implementationSelectedHeadingCount -ne 1 -or $reviewSelectedHeadingCount -ne 1 -or $implementationSelectedTable.Count -ne 3 -or $reviewSelectedTable.Count -ne 3) { $errors.Add('responsibility-evidence-missing') }
     else {
       $implementationSelected = & $rowFromTable $implementationSelectedTable $selectedUnitColumns
       $reviewSelected = & $rowFromTable $reviewSelectedTable $selectedUnitColumns
       foreach ($field in $selectedUnitColumns) { if ($implementationSelected[$field] -cne $reviewSelected[$field]) { $errors.Add('responsibility-evidence-missing') } }
       if ($reviewSelected['Migration Unit ID'] -cne $planSelector['External ID'] -or $reviewSelected['Plan Reference'] -cne "$($planSelector['Authority'])@$($planSelector['Authority Revision'])" -or $reviewSelected['Approval Reference'] -cne $planSelector['Approval Reference'] -or $reviewSelected['Mode Constraint'] -cne $planSelector['Mode Constraint'] -or $reviewSelected['Trace IDs'] -cne $planSelector['Trace IDs']) { $errors.Add('responsibility-evidence-missing') }
     }
   }
   elseif ($implementationSelectedHeadingCount -ne 0 -or $reviewSelectedHeadingCount -ne 0) { $errors.Add('responsibility-evidence-missing') }
   if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }
@@ -1838,42 +1907,34 @@ function Test-ResponsibilityHandoff {
   $selectedUnitColumns = @('Migration Unit ID', 'Plan Reference', 'Approval Reference', 'Mode Constraint', 'Bootstrap Scope', 'Foundation Baseline ID', 'Foundation Baseline Reference', 'Foundation Baseline Approval Reference', 'Baseline Reference', 'Trace IDs')
 
   $readArtifact = {
     param([string]$Text, [string]$Role)
 
     $artifact = [ordered]@{ Row = $null; Provenance = $null; Scope = $null; StepId = ''; AdapterKind = ''; SelectedUnit = $null }
     if ([string]::IsNullOrWhiteSpace($Text)) {
       $errors.Add('responsibility-owner-missing')
       return $artifact
     }
-    if (@([regex]::Matches($Text, '(?m)^##\s+Architecture Responsibility Handoff\s*$')).Count -ne 1) {
-      $errors.Add('responsibility-owner-missing')
-      return $artifact
-    }
-    if (@([regex]::Matches($Text, '(?m)^##\s+Task Provenance\s*$')).Count -ne 1) {
-      $errors.Add('responsibility-evidence-missing')
-      return $artifact
-    }
-    if (@([regex]::Matches($Text, '(?m)^##\s+Master Scope Context\s*$')).Count -ne 1) {
-      $errors.Add('responsibility-evidence-missing')
-      return $artifact
-    }
     if (@(Test-ArcDiscoveryResponsibilityContractVersion -DiscoveryText $Text).Count -ne 0) {
       $errors.Add('responsibility-contract-version-invalid')
       return $artifact
     }
 
     $tableErrors = [Collections.Generic.List[string]]::new()
     $handoffTable = @(Get-ArcStrictMarkdownTable -Text $Text -Heading 'Architecture Responsibility Handoff' -Columns $columns -Errors $tableErrors)
     $provenanceTable = @(Get-ArcStrictMarkdownTable -Text $Text -Heading 'Task Provenance' -Columns $provenanceColumns -Errors $tableErrors)
     $scopeTable = @(Get-ArcStrictMarkdownTable -Text $Text -Heading 'Master Scope Context' -Columns $scopeColumns -Errors $tableErrors)
-    if ($tableErrors.Count -ne 0 -or $handoffTable.Count -ne 3) {
+    if ($tableErrors.Count -ne 0) {
+      foreach ($tableError in $tableErrors) { $errors.Add($tableError) }
+      return $artifact
+    }
+    if ($handoffTable.Count -ne 3) {
       $tableDiagnostic = if ($handoffTable.Count -gt 3) { 'responsibility-owner-extra' } else { 'responsibility-owner-missing' }
       $errors.Add($tableDiagnostic)
       return $artifact
     }
     if ($provenanceTable.Count -ne 3 -or $scopeTable.Count -ne 3) {
       $errors.Add('responsibility-evidence-missing')
       return $artifact
     }
 
     $row = @{}
@@ -1893,60 +1954,63 @@ function Test-ResponsibilityHandoff {
     }
     $artifact.StepId = $stepIds[0].Groups['value'].Value.Trim()
     $topLevelKeys = @([regex]::Matches($frontMatter, '(?m)^(?<key>[a-z_][a-z0-9_]*):') | ForEach-Object { $_.Groups['key'].Value } | Sort-Object)
     if ($artifact.StepId -ceq '11-ai-review' -and (
       ($topLevelKeys -join '|') -cne 'approval_source|produced_at|responsibility_contract|result|status|step_id' -or
       @([regex]::Matches($frontMatter, '(?m)^status:\s*approved\s*$')).Count -ne 1 -or
       @([regex]::Matches($frontMatter, '(?m)^result:\s*complete\s*$')).Count -ne 1 -or
       @([regex]::Matches($frontMatter, '(?m)^approval_source:\s*human\s*$')).Count -ne 1
     )) { $errors.Add('responsibility-evidence-missing') }
 
-    $adapterMatches = @([regex]::Matches($Text, '(?im)^[ \t]*-[ \t]*Delivery Adapter Kind:[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$'))
+    $visibleText = Get-ArcVisibleMarkdownText -Text $Text
+    $adapterMatches = @([regex]::Matches($visibleText, '(?im)^[ \t]*-[ \t]*Delivery Adapter Kind:[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$'))
     if ($adapterMatches.Count -ne 1 -or $adapterMatches[0].Groups['value'].Value.Trim() -cnotin @('migration-unit', 'task', 'story', 'package', 'phase', 'milestone', 'none')) {
       $errors.Add('responsibility-evidence-missing')
     }
     else { $artifact.AdapterKind = $adapterMatches[0].Groups['value'].Value.Trim() }
-    $selectedHeadingCount = @([regex]::Matches($Text, '(?m)^##\s+Selected Migration Unit\s*$')).Count
-    if (($artifact.AdapterKind -ceq 'migration-unit' -and $selectedHeadingCount -ne 1) -or ($artifact.AdapterKind -ne '' -and $artifact.AdapterKind -cne 'migration-unit' -and $selectedHeadingCount -ne 0)) {
-      $errors.Add('responsibility-evidence-missing')
-    }
-    elseif ($artifact.AdapterKind -ceq 'migration-unit') {
+    if ($errors.Count -ne 0) { $artifact.Row = $null; return $artifact }
+    $selectedHeadingCount = @(Get-ArcMarkdownH2HeadingMatches -Text $Text -Heading 'Selected Migration Unit').Count
+    if ($artifact.AdapterKind -ceq 'migration-unit') {
       $selectedTable = @(Get-ArcStrictMarkdownTable -Text $Text -Heading 'Selected Migration Unit' -Columns $selectedUnitColumns -Errors $errors)
-      if ($selectedTable.Count -ne 3) { $errors.Add('responsibility-evidence-missing') }
+      if ($errors.Count -ne 0) { $artifact.Row = $null; return $artifact }
+      if ($selectedTable.Count -ne 3) { $errors.Add('responsibility-evidence-missing'); $artifact.Row = $null; return $artifact }
       else {
         $selectedUnit = [ordered]@{}
         for ($index = 0; $index -lt $selectedUnitColumns.Count; $index++) { $selectedUnit[$selectedUnitColumns[$index]] = [string]$selectedTable[2][$index] }
         $artifact.SelectedUnit = $selectedUnit
       }
     }
+    elseif ($artifact.AdapterKind -ne '' -and $selectedHeadingCount -ne 0) {
+      $errors.Add('responsibility-evidence-missing')
+    }
 
     if ($artifact.StepId -ceq '15-knowledge-base') {
       $envelopeHeadings = @('Master Scope Context', 'Task Provenance')
       if ($artifact.AdapterKind -ceq 'migration-unit') { $envelopeHeadings += 'Selected Migration Unit' }
       $envelopeHeadings += 'Architecture Responsibility Handoff'
       $h2Headings = @(
-        [regex]::Matches($Text, '(?m)^##[ \t]+(?<heading>[^\r\n]+?)[ \t]*\r?$') |
-          ForEach-Object { $_.Groups['heading'].Value }
+        [regex]::Matches($visibleText, '(?m)^##[ \t]+(?<heading>[^\r\n]+?)[ \t]*\r?$') |
+          ForEach-Object { ($_.Groups['heading'].Value -replace '[ \t]+', ' ').Trim() }
       )
       $envelopeStart = [Array]::IndexOf($h2Headings, $envelopeHeadings[0])
       $envelopeBlockValid = $envelopeStart -ge 0 -and ($envelopeStart + $envelopeHeadings.Count) -le $h2Headings.Count
       if ($envelopeBlockValid) {
         for ($headingIndex = 0; $headingIndex -lt $envelopeHeadings.Count; $headingIndex++) {
           if ($h2Headings[$envelopeStart + $headingIndex] -cne $envelopeHeadings[$headingIndex]) {
             $envelopeBlockValid = $false
             break
           }
         }
       }
       if (-not $envelopeBlockValid) { $errors.Add('responsibility-evidence-missing') }
-      $scopeHeading = [regex]::Match($Text, '(?m)^##\s+Master Scope Context\s*$')
-      $provenanceHeading = [regex]::Match($Text, '(?m)^##\s+Task Provenance\s*$')
+      $scopeHeading = [regex]::Match($visibleText, (Get-ArcMarkdownH2HeadingPattern -Heading 'Master Scope Context'))
+      $provenanceHeading = [regex]::Match($visibleText, (Get-ArcMarkdownH2HeadingPattern -Heading 'Task Provenance'))
       if ($adapterMatches.Count -ne 1 -or -not $scopeHeading.Success -or -not $provenanceHeading.Success -or
         $adapterMatches[0].Index -le $scopeHeading.Index -or $adapterMatches[0].Index -ge $provenanceHeading.Index) {
         $errors.Add('responsibility-evidence-missing')
       }
     }
 
     if ($row['Responsibility Contract Version'] -cne '1') { $errors.Add('responsibility-contract-version-invalid') }
     foreach ($field in @('Tree Conformance', 'Responsibility Conformance', 'Verification Ownership')) {
       if ($row[$field] -cnotin @('PASS', 'BLOCKED')) { $errors.Add('responsibility-waiver-forbidden') }
     }
@@ -1988,32 +2052,34 @@ function Test-ResponsibilityHandoff {
     }
     if ($artifact.StepId -ceq '15-knowledge-base' -and $provenance['Source Artifact'] -cnotin @('13-parity-report.md', '14-regression-report.md')) {
       $errors.Add('responsibility-evidence-missing')
     }
     return $artifact
   }
 
   $source = & $readArtifact $SourceText 'source'
   $target = & $readArtifact $TargetText 'target'
   if ($null -eq $source.Row -or $null -eq $target.Row) { return @($errors | Select-Object -Unique) }
+  if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }
 
   $planSelectionColumns = @('Work Item ID', 'Adapter Kind', 'External ID', 'Authority', 'Authority Revision', 'Approval Reference', 'Parent Selector', 'Acceptance', 'Trace IDs', 'Mode Constraint', 'Design Revision', 'Parent Work Item ID', 'Decomposition Decision Reference')
   $planFrontMatter = if ([string]::IsNullOrWhiteSpace($ApprovedPlanText)) { '' } else { Get-ArcBoundedFrontMatter -Text $ApprovedPlanText }
   [object[]]$planSelections = @()
-  if (-not [string]::IsNullOrWhiteSpace($ApprovedPlanText) -and @([regex]::Matches($ApprovedPlanText, '(?m)^##\s+Delivery Adapter Selection\s*$')).Count -eq 1) {
+  if (-not [string]::IsNullOrWhiteSpace($ApprovedPlanText)) {
     $planSelections = @(Get-ArcStrictMarkdownTable -Text $ApprovedPlanText -Heading 'Delivery Adapter Selection' -Columns $planSelectionColumns -Errors $errors)
   }
   $workItemColumns = @('Work Item ID', 'Title', 'Required', 'Dependencies', 'Plan Order', 'Acceptance', 'Trace IDs', 'Delivery Adapter', 'Status', 'Latest Attempt', 'Terminal Evidence', 'Approval Reference')
   [object[]]$workItemTable = @()
-  if (-not [string]::IsNullOrWhiteSpace($ApprovedPlanText) -and @([regex]::Matches($ApprovedPlanText, '(?m)^##\s+Work Items\s*$')).Count -eq 1) {
+  if (-not [string]::IsNullOrWhiteSpace($ApprovedPlanText)) {
     $workItemTable = @(Get-ArcStrictMarkdownTable -Text $ApprovedPlanText -Heading 'Work Items' -Columns $workItemColumns -Errors $errors)
   }
+  if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }
   $planIdMatches = @([regex]::Matches($planFrontMatter, '(?m)^master_plan_id:\s*(?<value>PLAN-[A-Z0-9]+(?:-[A-Z0-9]+)*)\s*$'))
   $planRevisionMatches = @([regex]::Matches($planFrontMatter, '(?m)^revision:\s*(?<value>[1-9][0-9]*)\s*$'))
   if (
     @([regex]::Matches($planFrontMatter, '(?m)^artifact_type:\s*migration-master-plan\s*$')).Count -ne 1 -or
     @([regex]::Matches($planFrontMatter, '(?m)^status:\s*approved\s*$')).Count -ne 1 -or
     $planIdMatches.Count -ne 1 -or $planRevisionMatches.Count -ne 1 -or $planSelections.Count -lt 3 -or $workItemTable.Count -lt 3 -or
     $planIdMatches[0].Groups['value'].Value -cne $source.Scope['Master Plan ID'] -or
     $planRevisionMatches[0].Groups['value'].Value -cne $source.Scope['Master Plan Revision']
   ) {
     $errors.Add('responsibility-evidence-missing')

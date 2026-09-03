# Review package: 0a703bcc9812510643076ae3143713478ef4b873..1001e2ce525d84bec710d93232498583a6d82b67

## Commits
1001e2c test: cover responsibility conformance workflow

## Files changed
 .../scenarios/responsibility-conformance.Tests.ps1 | 119 +++++++++++++++++++
 .../responsibility-conformance.validation.ps1      | 129 +++++++++++++++++++--
 2 files changed, 237 insertions(+), 11 deletions(-)

## Diff
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1
index 01f6659..5612120 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1
@@ -646,20 +646,139 @@ $duplicateMatrix = $featureLocalDesign + "`n`n" + [regex]::Match($featureLocalDe
 Assert-TestExactDiagnostics 'duplicate responsibility matrix emits only its exact cardinality diagnostic' `
   @(Test-ResponsibilityDesign -DiscoveryText (New-DiscoveryClassificationFixture) -DesignText $duplicateMatrix -Mode incremental -ContractText $contract) `
   @('ARC-CONTRACT-HEADING-CARDINALITY: File Responsibility Matrix')
 
 foreach ($lineEndingCase in @(
   [pscustomobject]@{ Name = 'LF'; NewLine = "`n" }
   [pscustomobject]@{ Name = 'CRLF'; NewLine = "`r`n" }
 )) {
   $designWithLineEndings = Convert-TestLineEndings $featureLocalDesign $lineEndingCase.NewLine
   Assert-DesignAccepted "canonical single Planned File Tree is accepted ($($lineEndingCase.Name))" $designWithLineEndings
+
+  $backtick = [string][char]96
+  $inlineCommentDelimiterProbe = @(
+    ($backtick + '<!--' + $backtick)
+    '## Probe'
+    '| A |'
+    '|---|'
+    '| first |'
+    ($backtick + '-->' + $backtick)
+    '## Probe'
+    '| A |'
+    '|---|'
+    '| second |'
+  ) -join $lineEndingCase.NewLine
+  $inlineProbeHeadingCount = @(Get-ArcMarkdownH2HeadingMatches -Text $inlineCommentDelimiterProbe -Heading 'Probe').Count
+  if ($inlineProbeHeadingCount -ne 2) {
+    throw "inline-code HTML comment delimiters must leave both Probe headings visible ($($lineEndingCase.Name)); got $inlineProbeHeadingCount"
+  }
+  $inlineProbeErrors = [Collections.Generic.List[string]]::new()
+  $inlineProbeRows = @(Get-ArcStrictMarkdownTable -Text $inlineCommentDelimiterProbe -Heading 'Probe' -Columns @('A') -Errors $inlineProbeErrors)
+  if ($inlineProbeRows.Count -ne 0) {
+    throw "duplicate Probe headings must prevent table extraction ($($lineEndingCase.Name)); got $($inlineProbeRows.Count) row(s)"
+  }
+  Assert-TestExactDiagnostics "inline-code HTML comment delimiters emit exact heading/table cardinality ($($lineEndingCase.Name))" `
+    @($inlineProbeErrors.ToArray()) `
+    @('ARC-CONTRACT-HEADING-CARDINALITY: Probe')
+
+  $twoLineBackticks = [string]::new([char]96, 2)
+  $multilineInlineCodeProbe = @(
+    ($twoLineBackticks + ' open inline code')
+    ('continued <!-- literal ' + $twoLineBackticks)
+    '## Probe'
+    '| A |'
+    '|---|'
+    '| first |'
+    ($twoLineBackticks + ' open inline code')
+    ('continued --> literal ' + $twoLineBackticks)
+    '## Probe'
+    '| A |'
+    '|---|'
+    '| second |'
+  ) -join $lineEndingCase.NewLine
+  $multilineProbeErrors = [Collections.Generic.List[string]]::new()
+  $multilineProbeRows = @(Get-ArcStrictMarkdownTable -Text $multilineInlineCodeProbe -Heading 'Probe' -Columns @('A') -Errors $multilineProbeErrors)
+  if ($multilineProbeRows.Count -ne 0) {
+    throw "multiline inline-code delimiters must leave duplicate Probe tables unparsed ($($lineEndingCase.Name)); got $($multilineProbeRows.Count) row(s)"
+  }
+  Assert-TestExactDiagnostics "multiline inline-code spans preserve line boundaries and exact heading/table cardinality ($($lineEndingCase.Name))" `
+    @($multilineProbeErrors.ToArray()) `
+    @('ARC-CONTRACT-HEADING-CARDINALITY: Probe')
+
+  $invalidFenceInsideMultilineSpanProbe = @(
+    '## Probe'
+    '| A |'
+    '|---|'
+    '| first |'
+    ($twoLineBackticks + ' open inline code')
+    ('```bad`info <!-- literal')
+    ('continued literal ' + $twoLineBackticks)
+    '## Probe'
+    '| A |'
+    '|---|'
+    '| second |'
+    '-->'
+  ) -join $lineEndingCase.NewLine
+  $invalidFenceProbeErrors = [Collections.Generic.List[string]]::new()
+  $invalidFenceProbeRows = @(Get-ArcStrictMarkdownTable -Text $invalidFenceInsideMultilineSpanProbe -Heading 'Probe' -Columns @('A') -Errors $invalidFenceProbeErrors)
+  if ($invalidFenceProbeRows.Count -ne 0) {
+    throw "an invalid backtick fence inside multiline inline code must not hide the duplicate Probe table ($($lineEndingCase.Name)); got $($invalidFenceProbeRows.Count) row(s)"
+  }
+  Assert-TestExactDiagnostics "multiline inline-code matching ignores invalid backtick fence openers ($($lineEndingCase.Name))" `
+    @($invalidFenceProbeErrors.ToArray()) `
+    @('ARC-CONTRACT-HEADING-CARDINALITY: Probe')
+
+  $treeForInlineCode = Get-TestH2SectionMatch -Text $designWithLineEndings -Heading 'Planned File Tree'
+  $treeSectionSeparator = if ($treeForInlineCode.Value.EndsWith($lineEndingCase.NewLine, [StringComparison]::Ordinal)) { '' } else { $lineEndingCase.NewLine }
+  $twoBackticks = [string]::new([char]96, 2)
+  $threeBackticks = [string]::new([char]96, 3)
+  $fourBackticks = [string]::new([char]96, 4)
+  $sixBackticks = [string]::new([char]96, 6)
+  $sevenBackticks = [string]::new([char]96, 7)
+  $multiBacktickOpenLiteral = $threeBackticks + ' ' + $fourBackticks + '<!--' + $twoBackticks + ' ' + $threeBackticks
+  $multiBacktickCloseLiteral = $sevenBackticks + ' ' + $sixBackticks + '-->' + $sixBackticks + ' ' + $sevenBackticks
+  $multiBacktickDuplicate = $designWithLineEndings.Insert(
+    $treeForInlineCode.Index,
+    $multiBacktickOpenLiteral + $lineEndingCase.NewLine + $treeForInlineCode.Value + $treeSectionSeparator + $multiBacktickCloseLiteral + $lineEndingCase.NewLine
+  )
+  Assert-TestExactDiagnostics "matching multi-backtick spans keep shorter and longer backtick runs plus HTML delimiters literal ($($lineEndingCase.Name))" `
+    @(Test-ResponsibilityDesign -DiscoveryText (New-DiscoveryClassificationFixture) -DesignText $multiBacktickDuplicate -Mode incremental -ContractText $contract) `
+    @('ARC-CONTRACT-HEADING-CARDINALITY: Planned File Tree')
+
+  $unmatchedSpanCommentedCopy = $twoBackticks + ' unmatched inline opener <!--' + $lineEndingCase.NewLine + $treeForInlineCode.Value + $treeSectionSeparator + '-->' + $lineEndingCase.NewLine + 'later block delimiter ' + $twoBackticks + $lineEndingCase.NewLine
+  Assert-DesignAccepted "an unmatched backtick run cannot shield a later real HTML comment ($($lineEndingCase.Name))" `
+    $designWithLineEndings.Insert($treeForInlineCode.Index, $unmatchedSpanCommentedCopy)
+
+  $codeThenAdjacentComment = $backtick + '<!--' + $backtick + '<!--' + $lineEndingCase.NewLine + $treeForInlineCode.Value + $treeSectionSeparator + '-->' + $lineEndingCase.NewLine
+  Assert-DesignAccepted "a real HTML comment immediately after inline code still hides its duplicate section ($($lineEndingCase.Name))" `
+    $designWithLineEndings.Insert($treeForInlineCode.Index, $codeThenAdjacentComment)
+
+  $commentThenInlineDelimiters = '<!-- real parser comment -->' + $backtick + '<!--' + $backtick + $lineEndingCase.NewLine + $treeForInlineCode.Value + $treeSectionSeparator + $backtick + '-->' + $backtick + $lineEndingCase.NewLine
+  Assert-TestExactDiagnostics "inline-code delimiters immediately after a real HTML comment cannot hide a duplicate section ($($lineEndingCase.Name))" `
+    @(Test-ResponsibilityDesign -DiscoveryText (New-DiscoveryClassificationFixture) -DesignText $designWithLineEndings.Insert($treeForInlineCode.Index, $commentThenInlineDelimiters) -Mode incremental -ContractText $contract) `
+    @('ARC-CONTRACT-HEADING-CARDINALITY: Planned File Tree')
+
+  $compactInlineHeadingCopy = Replace-TestFixtureText $treeForInlineCode.Value '## Planned File Tree' '## Planned <!--> File Tree' 'compact inline heading comment'
+  Assert-TestExactDiagnostics "compact <!--> in a duplicate canonical heading is removed without swallowing the later section ($($lineEndingCase.Name))" `
+    @(Test-ResponsibilityDesign -DiscoveryText (New-DiscoveryClassificationFixture) -DesignText $designWithLineEndings.Insert($treeForInlineCode.Index, $compactInlineHeadingCopy + $treeSectionSeparator) -Mode incremental -ContractText $contract) `
+    @('ARC-CONTRACT-HEADING-CARDINALITY: Planned File Tree')
+
+  $compactBeforeDuplicate = '<!-->' + $lineEndingCase.NewLine + $treeForInlineCode.Value + $treeSectionSeparator
+  Assert-TestExactDiagnostics "compact <!--> before duplicate canonical sections preserves exact cardinality ($($lineEndingCase.Name))" `
+    @(Test-ResponsibilityDesign -DiscoveryText (New-DiscoveryClassificationFixture) -DesignText $designWithLineEndings.Insert($treeForInlineCode.Index, $compactBeforeDuplicate) -Mode incremental -ContractText $contract) `
+    @('ARC-CONTRACT-HEADING-CARDINALITY: Planned File Tree')
+
+  $compactBetweenDuplicates = $treeForInlineCode.Value + $treeSectionSeparator + '<!--->' + $lineEndingCase.NewLine
+  Assert-TestExactDiagnostics "compact <!---> between duplicate canonical sections preserves exact cardinality ($($lineEndingCase.Name))" `
+    @(Test-ResponsibilityDesign -DiscoveryText (New-DiscoveryClassificationFixture) -DesignText $designWithLineEndings.Insert($treeForInlineCode.Index, $compactBetweenDuplicates) -Mode incremental -ContractText $contract) `
+    @('ARC-CONTRACT-HEADING-CARDINALITY: Planned File Tree')
+
   $duplicateResponsibilityMatrix = Add-TestH2SectionDuplicate -Text $designWithLineEndings -Heading 'File Responsibility Matrix' -Position after
   Assert-TestExactDiagnostics "design emits only the exact File Responsibility Matrix duplicate diagnostic ($($lineEndingCase.Name))" `
     @(Test-ResponsibilityDesign -DiscoveryText (New-DiscoveryClassificationFixture) -DesignText $duplicateResponsibilityMatrix -Mode incremental -ContractText $contract) `
     @('ARC-CONTRACT-HEADING-CARDINALITY: File Responsibility Matrix')
   $missingResponsibilityMatrix = Remove-TestH2Section -Text $designWithLineEndings -Heading 'File Responsibility Matrix'
   Assert-TestExactDiagnostics "design emits only the exact File Responsibility Matrix missing diagnostic ($($lineEndingCase.Name))" `
     @(Test-ResponsibilityDesign -DiscoveryText (New-DiscoveryClassificationFixture) -DesignText $missingResponsibilityMatrix -Mode incremental -ContractText $contract) `
     @('ARC-CONTRACT-MISSING-TABLE: File Responsibility Matrix')
   foreach ($position in @('before', 'after')) {
     $duplicateTree = Add-TestH2SectionDuplicate -Text $designWithLineEndings -Heading 'Planned File Tree' -Position $position
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1
index 80ad0e1..7375066 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1
@@ -34,85 +34,192 @@ function Get-ArcMarkdownFenceOpening {
   [CmdletBinding()]
   param([Parameter(Mandatory)][AllowEmptyString()][string]$Line)
 
   $openingFence = [regex]::Match($Line, '^[ ]{0,3}(?<fence>`{3,}|~{3,})(?<info>.*)$')
   if (-not $openingFence.Success) { return $null }
   $fence = $openingFence.Groups['fence'].Value
   if ($fence[0] -ceq [char]'`' -and $openingFence.Groups['info'].Value.Contains('`')) { return $null }
   return $openingFence
 }
 
+function Get-ArcMarkdownBacktickRunLength {
+  [CmdletBinding()]
+  param(
+    [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
+    [Parameter(Mandatory)][int]$StartIndex
+  )
+
+  if ($StartIndex -lt 0 -or $StartIndex -ge $Text.Length -or $Text[$StartIndex] -cne [char]96) { return 0 }
+  $cursor = $StartIndex
+  while ($cursor -lt $Text.Length -and $Text[$cursor] -ceq [char]96) { $cursor++ }
+  return $cursor - $StartIndex
+}
+
+function Get-ArcMarkdownInlineSearchEnd {
+  [CmdletBinding()]
+  param(
+    [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
+    [Parameter(Mandatory)][int]$StartIndex,
+    [Parameter(Mandatory)][int]$SearchEnd
+  )
+
+  $boundedSearchEnd = [Math]::Min($SearchEnd, $Text.Length)
+  $remainingText = $Text.Substring($StartIndex, $boundedSearchEnd - $StartIndex)
+  foreach ($lineBoundary in @([regex]::Matches($remainingText, '\r?\n(?<line>[^\r\n]*)'))) {
+    $nextLine = $lineBoundary.Groups['line'].Value
+    $isBlockBoundary =
+      $nextLine -cmatch '^[ \t]*$' -or
+      $nextLine -cmatch '^##[ \t]+' -or
+      $nextLine.StartsWith('|', [StringComparison]::Ordinal) -or
+      $nextLine -cmatch '^[ ]{0,3}<!--' -or
+      $null -ne (Get-ArcMarkdownFenceOpening -Line $nextLine)
+    if ($isBlockBoundary) { return $StartIndex + $lineBoundary.Index }
+  }
+  return $boundedSearchEnd
+}
+
+function Get-ArcMarkdownInlineCodeSpanEnd {
+  [CmdletBinding()]
+  param(
+    [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
+    [Parameter(Mandatory)][int]$OpeningIndex,
+    [Parameter(Mandatory)][int]$SearchEnd
+  )
+
+  $openingLength = Get-ArcMarkdownBacktickRunLength -Text $Text -StartIndex $OpeningIndex
+  if ($openingLength -eq 0) { return -1 }
+  $cursor = $OpeningIndex + $openingLength
+  $boundedSearchEnd = [Math]::Min($SearchEnd, $Text.Length)
+  if ($cursor -ge $boundedSearchEnd) { return -1 }
+
+  $boundedSearchEnd = Get-ArcMarkdownInlineSearchEnd -Text $Text -StartIndex $cursor -SearchEnd $boundedSearchEnd
+
+  while ($cursor -lt $boundedSearchEnd) {
+    $candidateIndex = $Text.IndexOf([char]96, $cursor)
+    if ($candidateIndex -lt 0 -or $candidateIndex -ge $boundedSearchEnd) { return -1 }
+    $candidateLength = Get-ArcMarkdownBacktickRunLength -Text $Text -StartIndex $candidateIndex
+    if ($candidateIndex + $candidateLength -gt $boundedSearchEnd) { return -1 }
+    if ($candidateLength -eq $openingLength) { return $candidateIndex + $candidateLength }
+    $cursor = $candidateIndex + $candidateLength
+  }
+  return -1
+}
+
+function Get-ArcHtmlCommentEnd {
+  [CmdletBinding()]
+  param(
+    [Parameter(Mandatory)][AllowEmptyString()][string]$Line,
+    [Parameter(Mandatory)][int]$CommentStart
+  )
+
+  if ($Line.IndexOf('<!-->', $CommentStart, [StringComparison]::Ordinal) -eq $CommentStart) {
+    return $CommentStart + 5
+  }
+  if ($Line.IndexOf('<!--->', $CommentStart, [StringComparison]::Ordinal) -eq $CommentStart) {
+    return $CommentStart + 6
+  }
+  $commentEnd = $Line.IndexOf('-->', $CommentStart + 4, [StringComparison]::Ordinal)
+  if ($commentEnd -lt 0) { return -1 }
+  return $commentEnd + 3
+}
+
 function Get-ArcVisibleMarkdownText {
   [CmdletBinding()]
   param([Parameter(Mandatory)][string]$Text)
 
   $visibleText = [Text.StringBuilder]::new()
   $insideFence = $false
   $fenceCharacter = ''
   $fenceLength = 0
   $insideHtmlComment = $false
+  $inlineCodeEnd = -1
   foreach ($lineMatch in @([regex]::Matches($Text, '(?m)^[^\r\n]*(?:\r\n|\n|$)'))) {
     if ($lineMatch.Length -eq 0) { continue }
     $lineWithEnding = $lineMatch.Value
     $lineEnding = ''
     if ($lineWithEnding.EndsWith("`r`n", [StringComparison]::Ordinal)) {
       $lineEnding = "`r`n"
     }
     elseif ($lineWithEnding.EndsWith("`n", [StringComparison]::Ordinal)) {
       $lineEnding = "`n"
     }
     $line = $lineWithEnding.Substring(0, $lineWithEnding.Length - $lineEnding.Length)
-    $rawHasH2Marker = -not $insideHtmlComment -and $line -cmatch '^##[ \t]+'
-    $rawHasTableMarker = -not $insideHtmlComment -and $line.StartsWith('|', [StringComparison]::Ordinal)
+    $lineStart = $lineMatch.Index
+    $lineContentEnd = $lineStart + $line.Length
+    $lineStartsInsideInlineCode = $inlineCodeEnd -gt $lineStart
+    $rawHasH2Marker = -not $insideHtmlComment -and -not $lineStartsInsideInlineCode -and $line -cmatch '^##[ \t]+'
+    $rawHasTableMarker = -not $insideHtmlComment -and -not $lineStartsInsideInlineCode -and $line.StartsWith('|', [StringComparison]::Ordinal)
 
     if ($insideFence) {
       $closingPattern = '^[ ]{0,3}' + [regex]::Escape($fenceCharacter) + '{' + $fenceLength + ',}[ \t]*$'
       if ($line -cmatch $closingPattern) {
         $insideFence = $false
         $fenceCharacter = ''
         $fenceLength = 0
       }
       if ($line.Length -gt 0) { [void]$visibleText.Append([string]::new([char]' ', $line.Length)) }
       [void]$visibleText.Append($lineEnding)
       continue
     }
 
-    $openingFence = if ($insideHtmlComment) { $null } else { Get-ArcMarkdownFenceOpening -Line $line }
+    $openingFence = if ($insideHtmlComment -or $lineStartsInsideInlineCode) { $null } else { Get-ArcMarkdownFenceOpening -Line $line }
     if ($null -ne $openingFence -and $openingFence.Success) {
       $insideFence = $true
       $fenceCharacter = [string]$openingFence.Groups['fence'].Value[0]
       $fenceLength = $openingFence.Groups['fence'].Value.Length
       if ($line.Length -gt 0) { [void]$visibleText.Append([string]::new([char]' ', $line.Length)) }
       [void]$visibleText.Append($lineEnding)
       continue
     }
 
     $visibleLineBuilder = [Text.StringBuilder]::new()
     $cursor = 0
+    if ($lineStartsInsideInlineCode) {
+      $protectedLength = [Math]::Min($line.Length, $inlineCodeEnd - $lineStart)
+      if ($protectedLength -gt 0) { [void]$visibleLineBuilder.Append($line.Substring(0, $protectedLength)) }
+      $cursor = $protectedLength
+      if ($lineStart + $cursor -ge $inlineCodeEnd) { $inlineCodeEnd = -1 }
+    }
     while ($cursor -lt $line.Length) {
       if ($insideHtmlComment) {
         $commentEnd = $line.IndexOf('-->', $cursor, [StringComparison]::Ordinal)
         if ($commentEnd -lt 0) { $cursor = $line.Length }
         else { $insideHtmlComment = $false; $cursor = $commentEnd + 3 }
         continue
       }
 
-      $commentStart = $line.IndexOf('<!--', $cursor, [StringComparison]::Ordinal)
-      if ($commentStart -lt 0) {
-        [void]$visibleLineBuilder.Append($line.Substring($cursor))
-        $cursor = $line.Length
+      if ($line[$cursor] -ceq [char]96) {
+        $absoluteOpeningIndex = $lineStart + $cursor
+        $inlineSearchEnd = if ($rawHasH2Marker -or $rawHasTableMarker) { $lineContentEnd } else { $Text.Length }
+        $matchedInlineCodeEnd = Get-ArcMarkdownInlineCodeSpanEnd -Text $Text -OpeningIndex $absoluteOpeningIndex -SearchEnd $inlineSearchEnd
+        if ($matchedInlineCodeEnd -gt $absoluteOpeningIndex) {
+          $protectedLength = [Math]::Min($line.Length - $cursor, $matchedInlineCodeEnd - $absoluteOpeningIndex)
+          [void]$visibleLineBuilder.Append($line.Substring($cursor, $protectedLength))
+          $cursor += $protectedLength
+          if ($matchedInlineCodeEnd -gt $lineContentEnd) { $inlineCodeEnd = $matchedInlineCodeEnd }
+          continue
+        }
+        $unmatchedRunLength = Get-ArcMarkdownBacktickRunLength -Text $line -StartIndex $cursor
+        [void]$visibleLineBuilder.Append($line.Substring($cursor, $unmatchedRunLength))
+        $cursor += $unmatchedRunLength
+        continue
+      }
+
+      if ($line.IndexOf('<!--', $cursor, [StringComparison]::Ordinal) -eq $cursor) {
+        $commentEnd = Get-ArcHtmlCommentEnd -Line $line -CommentStart $cursor
+        if ($commentEnd -lt 0) { $insideHtmlComment = $true; $cursor = $line.Length }
+        else { $cursor = $commentEnd }
         continue
       }
-      if ($commentStart -gt $cursor) { [void]$visibleLineBuilder.Append($line.Substring($cursor, $commentStart - $cursor)) }
-      $commentEnd = $line.IndexOf('-->', $commentStart + 4, [StringComparison]::Ordinal)
-      if ($commentEnd -lt 0) { $insideHtmlComment = $true; $cursor = $line.Length }
-      else { $cursor = $commentEnd + 3 }
+
+      [void]$visibleLineBuilder.Append($line[$cursor])
+      $cursor++
     }
 
     $visibleLine = $visibleLineBuilder.ToString()
     if (-not $rawHasH2Marker -and $visibleLine -cmatch '^##[ \t]+') {
       $visibleLine = ' ' + $visibleLine.Substring(1)
     }
     if (-not $rawHasTableMarker -and $visibleLine.StartsWith('|', [StringComparison]::Ordinal)) {
       $visibleLine = ' ' + $visibleLine.Substring(1)
     }
     [void]$visibleText.Append($visibleLine)

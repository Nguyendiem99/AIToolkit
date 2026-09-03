Set-StrictMode -Version Latest

function Get-ArcBoundedFrontMatter {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Text)

  $match = [regex]::Match($Text, '\A---\r?\n(?<body>.*?)\r?\n---(?=\r?\n|\z)', [Text.RegularExpressions.RegexOptions]::Singleline)
  if (-not $match.Success) { return $null }
  return $match.Groups['body'].Value
}

function Split-ArcCanonicalList {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Value)

  return @($Value -split '\|' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
}

function Test-ArcExactSet {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Actual,
    [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Expected
  )

  if ($Actual.Count -ne $Expected.Count) { return $false }
  for ($index = 0; $index -lt $Expected.Count; $index++) {
    if ($Actual[$index] -cne $Expected[$index]) { return $false }
  }
  return $true
}

function Test-ArcIndependentBoundaryEvidence {
  [CmdletBinding()]
  param([Parameter(Mandatory)][AllowEmptyString()][string]$Value)

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

function Get-ArcMarkdownFenceOpening {
  [CmdletBinding()]
  param([Parameter(Mandatory)][AllowEmptyString()][string]$Line)

  $openingFence = [regex]::Match($Line, '^[ ]{0,3}(?<fence>`{3,}|~{3,})(?<info>.*)$')
  if (-not $openingFence.Success) { return $null }
  $fence = $openingFence.Groups['fence'].Value
  if ($fence[0] -ceq [char]'`' -and $openingFence.Groups['info'].Value.Contains('`')) { return $null }
  return $openingFence
}

function Get-ArcMarkdownBacktickRunLength {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
    [Parameter(Mandatory)][int]$StartIndex
  )

  if ($StartIndex -lt 0 -or $StartIndex -ge $Text.Length -or $Text[$StartIndex] -cne [char]96) { return 0 }
  $cursor = $StartIndex
  while ($cursor -lt $Text.Length -and $Text[$cursor] -ceq [char]96) { $cursor++ }
  return $cursor - $StartIndex
}

function Get-ArcMarkdownInlineSearchEnd {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
    [Parameter(Mandatory)][int]$StartIndex,
    [Parameter(Mandatory)][int]$SearchEnd
  )

  $boundedSearchEnd = [Math]::Min($SearchEnd, $Text.Length)
  $remainingText = $Text.Substring($StartIndex, $boundedSearchEnd - $StartIndex)
  foreach ($lineBoundary in @([regex]::Matches($remainingText, '\r?\n(?<line>[^\r\n]*)'))) {
    $nextLine = $lineBoundary.Groups['line'].Value
    $isBlockBoundary =
      $nextLine -cmatch '^[ \t]*$' -or
      $nextLine -cmatch '^##[ \t]+' -or
      $nextLine.StartsWith('|', [StringComparison]::Ordinal) -or
      $nextLine -cmatch '^[ ]{0,3}<!--' -or
      $null -ne (Get-ArcMarkdownFenceOpening -Line $nextLine)
    if ($isBlockBoundary) { return $StartIndex + $lineBoundary.Index }
  }
  return $boundedSearchEnd
}

function Get-ArcMarkdownInlineCodeSpanEnd {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
    [Parameter(Mandatory)][int]$OpeningIndex,
    [Parameter(Mandatory)][int]$SearchEnd
  )

  $openingLength = Get-ArcMarkdownBacktickRunLength -Text $Text -StartIndex $OpeningIndex
  if ($openingLength -eq 0) { return -1 }
  $cursor = $OpeningIndex + $openingLength
  $boundedSearchEnd = [Math]::Min($SearchEnd, $Text.Length)
  if ($cursor -ge $boundedSearchEnd) { return -1 }

  $boundedSearchEnd = Get-ArcMarkdownInlineSearchEnd -Text $Text -StartIndex $cursor -SearchEnd $boundedSearchEnd

  while ($cursor -lt $boundedSearchEnd) {
    $candidateIndex = $Text.IndexOf([char]96, $cursor)
    if ($candidateIndex -lt 0 -or $candidateIndex -ge $boundedSearchEnd) { return -1 }
    $candidateLength = Get-ArcMarkdownBacktickRunLength -Text $Text -StartIndex $candidateIndex
    if ($candidateIndex + $candidateLength -gt $boundedSearchEnd) { return -1 }
    if ($candidateLength -eq $openingLength) { return $candidateIndex + $candidateLength }
    $cursor = $candidateIndex + $candidateLength
  }
  return -1
}

function Get-ArcHtmlCommentEnd {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][AllowEmptyString()][string]$Line,
    [Parameter(Mandatory)][int]$CommentStart
  )

  if ($Line.IndexOf('<!-->', $CommentStart, [StringComparison]::Ordinal) -eq $CommentStart) {
    return $CommentStart + 5
  }
  if ($Line.IndexOf('<!--->', $CommentStart, [StringComparison]::Ordinal) -eq $CommentStart) {
    return $CommentStart + 6
  }
  $commentEnd = $Line.IndexOf('-->', $CommentStart + 4, [StringComparison]::Ordinal)
  if ($commentEnd -lt 0) { return -1 }
  return $commentEnd + 3
}

function Get-ArcVisibleMarkdownText {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Text)

  $visibleText = [Text.StringBuilder]::new()
  $insideFence = $false
  $fenceCharacter = ''
  $fenceLength = 0
  $insideHtmlComment = $false
  $inlineCodeEnd = -1
  $frontMatterMatch = [regex]::Match($Text, '\A---\r?\n.*?\r?\n---(?=\r?\n|\z)', [Text.RegularExpressions.RegexOptions]::Singleline)
  $frontMatterEnd = if ($frontMatterMatch.Success) { $frontMatterMatch.Index + $frontMatterMatch.Length } else { 0 }
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
    $lineStart = $lineMatch.Index
    $lineContentEnd = $lineStart + $line.Length
    if ($frontMatterEnd -gt 0 -and $lineStart -lt $frontMatterEnd) {
      if ($line.Length -gt 0) { [void]$visibleText.Append([string]::new([char]' ', $line.Length)) }
      [void]$visibleText.Append($lineEnding)
      continue
    }
    $lineStartsInsideInlineCode = $inlineCodeEnd -gt $lineStart
    $rawHasH2Marker = -not $insideHtmlComment -and -not $lineStartsInsideInlineCode -and $line -cmatch '^##[ \t]+'
    $rawHasTableMarker = -not $insideHtmlComment -and -not $lineStartsInsideInlineCode -and $line.StartsWith('|', [StringComparison]::Ordinal)

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

    $indentColumns = 0
    for ($indentIndex = 0; $indentIndex -lt $line.Length; $indentIndex++) {
      if ($line[$indentIndex] -ceq ' ') { $indentColumns++; continue }
      if ($line[$indentIndex] -ceq "`t") {
        $indentColumns += 4 - ($indentColumns % 4)
        continue
      }
      break
    }
    if (-not $insideHtmlComment -and -not $lineStartsInsideInlineCode -and $indentColumns -ge 4) {
      if ($line.Length -gt 0) { [void]$visibleText.Append([string]::new([char]' ', $line.Length)) }
      [void]$visibleText.Append($lineEnding)
      continue
    }

    $openingFence = if ($insideHtmlComment -or $lineStartsInsideInlineCode) { $null } else { Get-ArcMarkdownFenceOpening -Line $line }
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
    if ($lineStartsInsideInlineCode) {
      $protectedLength = [Math]::Min($line.Length, $inlineCodeEnd - $lineStart)
      if ($protectedLength -gt 0) { [void]$visibleLineBuilder.Append($line.Substring(0, $protectedLength)) }
      $cursor = $protectedLength
      if ($lineStart + $cursor -ge $inlineCodeEnd) { $inlineCodeEnd = -1 }
    }
    while ($cursor -lt $line.Length) {
      if ($insideHtmlComment) {
        $commentEnd = $line.IndexOf('-->', $cursor, [StringComparison]::Ordinal)
        if ($commentEnd -lt 0) { $cursor = $line.Length }
        else { $insideHtmlComment = $false; $cursor = $commentEnd + 3 }
        continue
      }

      if ($line[$cursor] -ceq [char]96) {
        $absoluteOpeningIndex = $lineStart + $cursor
        $inlineSearchEnd = if ($rawHasH2Marker -or $rawHasTableMarker) { $lineContentEnd } else { $Text.Length }
        $matchedInlineCodeEnd = Get-ArcMarkdownInlineCodeSpanEnd -Text $Text -OpeningIndex $absoluteOpeningIndex -SearchEnd $inlineSearchEnd
        if ($matchedInlineCodeEnd -gt $absoluteOpeningIndex) {
          $protectedLength = [Math]::Min($line.Length - $cursor, $matchedInlineCodeEnd - $absoluteOpeningIndex)
          [void]$visibleLineBuilder.Append($line.Substring($cursor, $protectedLength))
          $cursor += $protectedLength
          if ($matchedInlineCodeEnd -gt $lineContentEnd) { $inlineCodeEnd = $matchedInlineCodeEnd }
          continue
        }
        $unmatchedRunLength = Get-ArcMarkdownBacktickRunLength -Text $line -StartIndex $cursor
        [void]$visibleLineBuilder.Append($line.Substring($cursor, $unmatchedRunLength))
        $cursor += $unmatchedRunLength
        continue
      }

      if ($line.IndexOf('<!--', $cursor, [StringComparison]::Ordinal) -eq $cursor) {
        $commentEnd = Get-ArcHtmlCommentEnd -Line $line -CommentStart $cursor
        if ($commentEnd -lt 0) { $insideHtmlComment = $true; $cursor = $line.Length }
        else { $cursor = $commentEnd }
        continue
      }

      [void]$visibleLineBuilder.Append($line[$cursor])
      $cursor++
    }

    $visibleLine = $visibleLineBuilder.ToString()
    if (-not $rawHasH2Marker -and $visibleLine -cmatch '^##[ \t]+') {
      $visibleLine = ' ' + $visibleLine.Substring(1)
    }
    if (-not $rawHasTableMarker -and $visibleLine.StartsWith('|', [StringComparison]::Ordinal)) {
      $visibleLine = ' ' + $visibleLine.Substring(1)
    }
    [void]$visibleText.Append($visibleLine)
    [void]$visibleText.Append($lineEnding)
  }
  return $visibleText.ToString()
}

function Get-ArcStrictVisibleBulletMatches {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Text,
    [Parameter(Mandatory)][string]$Label
  )

  $visibleText = Get-ArcVisibleMarkdownText -Text $Text
  $pattern = '(?m)^[ ]{0,3}-[ \t]+' + [regex]::Escape($Label) + ':[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$'
  $rawPrefixPattern = '^[ ]{0,3}-[ \t]+' + [regex]::Escape($Label) + ':'
  $rawLines = @([regex]::Split($Text, '\r?\n'))
  $accepted = [Collections.Generic.List[object]]::new()
  foreach ($match in @([regex]::Matches($visibleText, $pattern))) {
    $lineNumber = @([regex]::Matches($visibleText.Substring(0, $match.Index), '\n')).Count
    if ($lineNumber -lt $rawLines.Count -and $rawLines[$lineNumber] -cmatch $rawPrefixPattern) {
      $accepted.Add($match)
    }
  }
  return @($accepted)
}

function Get-ArcMarkdownH2HeadingPattern {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Heading)

  $headingTokens = @([regex]::Split($Heading.Trim(), '[ \t]+') | Where-Object { $_ -ne '' } | ForEach-Object { [regex]::Escape($_) })
  return '(?m)^##[ \t]+' + ($headingTokens -join '[ \t]+') + '[ \t]*(?=\r?$)'
}

function Get-ArcMarkdownH2HeadingMatches {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Text,
    [Parameter(Mandatory)][string]$Heading
  )

  $visibleText = Get-ArcVisibleMarkdownText -Text $Text
  $headingPattern = Get-ArcMarkdownH2HeadingPattern -Heading $Heading
  return @([regex]::Matches($visibleText, $headingPattern))
}

function Get-ArcStrictMarkdownTable {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Text,
    [Parameter(Mandatory)][string]$Heading,
    [Parameter(Mandatory)][string[]]$Columns,
    [Parameter(Mandatory)][AllowEmptyCollection()][Collections.Generic.List[string]]$Errors,
    [switch]$AllowEmptyBody
  )

  $visibleText = Get-ArcVisibleMarkdownText -Text $Text
  $headingPattern = Get-ArcMarkdownH2HeadingPattern -Heading $Heading
  $headingMatches = @([regex]::Matches($visibleText, $headingPattern))
  if ($headingMatches.Count -eq 0) {
    $Errors.Add("ARC-CONTRACT-MISSING-TABLE: $Heading")
    return @()
  }
  if ($headingMatches.Count -ne 1) {
    $Errors.Add("ARC-CONTRACT-HEADING-CARDINALITY: $Heading")
    return @()
  }
  $headingMatch = $headingMatches[0]
  $remaining = $visibleText.Substring($headingMatch.Index + $headingMatch.Length)
  $lines = @($remaining -split '\r?\n')
  $tableLines = [Collections.Generic.List[string]]::new()
  foreach ($line in $lines) {
    if ([string]::IsNullOrWhiteSpace($line) -and $tableLines.Count -eq 0) { continue }
    if ($line -match '^##\s+') { break }
    if ($line -match '^\|') { $tableLines.Add($line); continue }
    if ($tableLines.Count -gt 0) { break }
  }
  $minimumTableLines = if ($AllowEmptyBody) { 2 } else { 3 }
  if ($tableLines.Count -lt $minimumTableLines) {
    $Errors.Add("ARC-CONTRACT-MALFORMED-TABLE: $Heading")
    return @()
  }

  $rows = [Collections.Generic.List[string[]]]::new()
  foreach ($line in $tableLines) {
    if ($line -notmatch '^\|[^|].*[^|]\|\s*$' -or $line -match '\|\|') {
      $Errors.Add("ARC-CONTRACT-MALFORMED-TABLE: $Heading")
      return @()
    }
    $body = $line.Trim()
    $cells = @($body.Substring(1, $body.Length - 2).Split('|') | ForEach-Object { $_.Trim() })
    if ($cells.Count -ne $Columns.Count) {
      $Errors.Add("ARC-CONTRACT-TABLE-COLUMNS: $Heading")
      return @()
    }
    $rows.Add([string[]]$cells)
  }
  if (-not (Test-ArcExactSet -Actual $rows[0] -Expected $Columns)) {
    $Errors.Add("ARC-CONTRACT-TABLE-COLUMNS: $Heading")
  }
  foreach ($separatorCell in $rows[1]) {
    if ($separatorCell -cnotmatch '^:?-{3,}:?$') {
      $Errors.Add("ARC-CONTRACT-MISSING-SEPARATOR: $Heading")
      break
    }
  }
  return $rows.ToArray()
}

function Test-ResponsibilityContractSchema {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$ContractText)

  $errors = [Collections.Generic.List[string]]::new()
  if ($ContractText -match '\r\n' -and $ContractText -match '(?<!\r)\n') {
    $errors.Add('ARC-CONTRACT-LINE-ENDINGS: mixed CRLF and LF line endings')
  }
  $frontMatter = Get-ArcBoundedFrontMatter -Text $ContractText
  if ($null -eq $frontMatter) {
    $errors.Add('ARC-CONTRACT-FRONT-MATTER: required bounded front matter is missing')
  }
  else {
    foreach ($field in @('version: 1', 'applicability: required')) {
      if (@([regex]::Matches($frontMatter, '(?m)^' + [regex]::Escape($field) + '\s*$')).Count -ne 1) {
        $errors.Add("ARC-CONTRACT-FRONT-MATTER: required field is invalid: $field")
      }
    }
  }

  $headings = @(
    'Contract Version', 'Exemplar Classification', 'Architecture Authority',
    'Co-location Semantics', 'Actual Responsibility Evidence',
    'Review Verdicts', 'Downstream Handoff', 'Compatibility and Rollout',
    'Stable Diagnostics'
  )
  foreach ($heading in $headings) {
    $count = @(Get-ArcMarkdownH2HeadingMatches -Text $ContractText -Heading $heading).Count
    if ($count -ne 1) { $errors.Add("ARC-CONTRACT-HEADING: $heading") }
  }

  $responsibilityRows = @(Get-ArcStrictMarkdownTable -Text $ContractText -Heading 'File Responsibility Matrix' -Columns @(
    'Responsibility ID', 'Owner Path', 'Owner Symbol', 'Boundary Kind',
    'Primary Responsibility', 'Owned Capability IDs', 'Trace IDs', 'Atomic Boundary ID',
    'Public Symbols', 'External Effects', 'Target Exemplar', 'Exemplar Classification',
    'Classification Authority', 'Classification Evidence', 'Architecture Authority',
    'Co-location Policy', 'Co-location Evidence', 'Verification Owner References',
    'Conformance', 'Deviation Reference'
  ) -Errors $errors)
  $verificationRows = @(Get-ArcStrictMarkdownTable -Text $ContractText -Heading 'Verification Ownership Matrix' -Columns @(
    'Verification Owner ID', 'Production Responsibility ID', 'Capability ID',
    'Evidence Path', 'Evidence Symbol or Scenario', 'Evidence Kind',
    'Verification Disposition', 'Production Binding Evidence', 'Decision Reference',
    'Verdict', 'Deviation Reference'
  ) -Errors $errors)
  if ($errors.Count -ne 0) { return $errors.ToArray() }

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
      $errors.Add('ARC-CONTRACT-VERIFICATION-DISPOSITION: Verification Disposition must be canonical')
    }
  }
  for ($rowIndex = 2; $rowIndex -lt $responsibilityRows.Count; $rowIndex++) {
    if ($responsibilityRows[$rowIndex][17] -cnotmatch '^(?:(?:VERIFY-OWNER-###|VERIFY-OWNER-[A-Z0-9]+(?:-[A-Z0-9]+)*))(?:\s*,\s*(?:VERIFY-OWNER-###|VERIFY-OWNER-[A-Z0-9]+(?:-[A-Z0-9]+)*))*$') {
      $errors.Add('ARC-CONTRACT-VERIFICATION-ID-FAMILY: Verification Owner ID must use VERIFY-OWNER-*')
    }
    if ($responsibilityRows[$rowIndex][3] -cnotin @('domain', 'data', 'application', 'presentation', 'adapter', 'integration', 'config', 'test', 'project-defined')) {
      $errors.Add('ARC-CONTRACT-BOUNDARY-KIND: Boundary Kind must be canonical')
    }
    if ($responsibilityRows[$rowIndex][18] -cnotin @('yes', 'no', 'blocked')) {
      $errors.Add('ARC-CONTRACT-CONFORMANCE: Conformance must be canonical')
    }
    $contractPublicSymbols = @($responsibilityRows[$rowIndex][8] -split '[,;]' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
    $contractPublicSymbolsValid = ($contractPublicSymbols.Count -eq 1 -and $contractPublicSymbols[0] -ceq 'none') -or (
      $contractPublicSymbols.Count -gt 0 -and
      $contractPublicSymbols -cnotcontains 'none' -and
      $contractPublicSymbols -ccontains $responsibilityRows[$rowIndex][2] -and
      @($contractPublicSymbols | Where-Object { $_ -cnotmatch '^[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*$' }).Count -eq 0
    )
    if (-not $contractPublicSymbolsValid) { $errors.Add('ARC-CONTRACT-PUBLIC-SYMBOLS: Public Symbols must be canonical') }
    if (($responsibilityRows[$rowIndex][18] -ceq 'yes' -and $responsibilityRows[$rowIndex][19] -cne 'not-applicable') -or ($responsibilityRows[$rowIndex][18] -ceq 'no' -and $responsibilityRows[$rowIndex][19] -cnotmatch '^DEV-[A-Z0-9]+(?:-[A-Z0-9]+)*$')) {
      $errors.Add('ARC-CONTRACT-CONFORMANCE: Conformance and Deviation Reference must agree')
    }
  }
  return $errors.ToArray()
}

function Test-ArcResponsibilityStageVersion {
  param([string]$ContractText, [string]$Stage)
  $errors = [Collections.Generic.List[string]]::new()
  $frontMatter = Get-ArcBoundedFrontMatter -Text $ContractText
  if (
    $null -eq $frontMatter -or
    @([regex]::Matches($frontMatter, '(?m)^version:\s*1\s*$')).Count -ne 1 -or
    @([regex]::Matches($frontMatter, '(?m)^applicability:\s*required\s*$')).Count -ne 1
  ) {
    $errors.Add("ARC-$Stage-CONTRACT-VERSION: responsibility contract requires version 1 and applicability required")
  }
  return $errors.ToArray()
}

function Get-ArcContractEnumValues {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$ContractText,
    [Parameter(Mandatory)][string]$Name
  )

  $match = [regex]::Match($ContractText, '(?m)^' + [regex]::Escape($Name) + '\s*=\s*(?<values>[^\r\n]+)\s*$')
  if (-not $match.Success) { return @() }
  return @($match.Groups['values'].Value.Split('|') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
}

function Test-ArcNotApplicableApprovedEligibility {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][hashtable]$ProductionRow,
    [Parameter(Mandatory)][hashtable]$VerificationRow,
    [Parameter(Mandatory)][string]$ContractText
  )

  $boundaryKinds = @(Get-ArcContractEnumValues -ContractText $ContractText -Name 'Boundary Kind')
  $evidenceKinds = @(Get-ArcContractEnumValues -ContractText $ContractText -Name 'Evidence Kind')
  $dispositions = @(Get-ArcContractEnumValues -ContractText $ContractText -Name 'Verification Disposition')
  $responsibilityMatch = [regex]::Match($ProductionRow['Responsibility ID'], '^RESP-(?<suffix>[A-Z0-9]+(?:-[A-Z0-9]+)*)$')
  if (-not $responsibilityMatch.Success) { return $false }
  $approvalSuffix = $responsibilityMatch.Groups['suffix'].Value
  $validApprovals = @("approval:TECH-LEAD-$approvalSuffix", "approval:OWNER-$approvalSuffix")
  return (
    $boundaryKinds -ccontains $ProductionRow['Boundary Kind'] -and
    $ProductionRow['Boundary Kind'] -ceq 'config' -and
    $evidenceKinds -ccontains $VerificationRow['Evidence Kind'] -and
    $VerificationRow['Evidence Kind'] -cin @('static-structure', 'generator-verification') -and
    $dispositions -ccontains $VerificationRow['Verification Disposition'] -and
    $VerificationRow['Verification Disposition'] -ceq 'not-applicable-approved' -and
    $ProductionRow['External Effects'] -ceq 'none' -and
    $validApprovals -ccontains $VerificationRow['Decision Reference']
  )
}

function Test-ArcDiscoveryResponsibilityContractVersion {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$DiscoveryText)

  $frontMatter = Get-ArcBoundedFrontMatter -Text $DiscoveryText
  if ($null -eq $frontMatter) { return @('responsibility-contract-version-invalid') }
  $lines = @($frontMatter -split '\r?\n')
  $blockStarts = @($lines | ForEach-Object -Begin { $index = 0 } -Process {
    $current = [pscustomobject]@{ Index = $index; Value = $_ }
    $index++
    $current
  } | Where-Object { $_.Value -cmatch '^responsibility_contract:\s*$' })
  if ($blockStarts.Count -ne 1) { return @('responsibility-contract-version-invalid') }

  $children = [Collections.Generic.List[string]]::new()
  for ($lineIndex = $blockStarts[0].Index + 1; $lineIndex -lt $lines.Count; $lineIndex++) {
    $line = $lines[$lineIndex]
    if ($line -match '^\S') { break }
    if ($line -notmatch '^  [A-Za-z][A-Za-z0-9_-]*:\s*\S.*$') {
      return @('responsibility-contract-version-invalid')
    }
    $children.Add($line)
  }
  $versionChildren = @($children | Where-Object { $_ -cmatch '^  version:\s*1\s*$' })
  $applicabilityChildren = @($children | Where-Object { $_ -cmatch '^  applicability:\s*required\s*$' })
  if (
    $children.Count -ne 2 -or
    $versionChildren.Count -ne 1 -or
    $applicabilityChildren.Count -ne 1
  ) {
    return @('responsibility-contract-version-invalid')
  }
  return @()
}

function Test-ArcCanonicalDiscoverySourceEvidence {
  [CmdletBinding()]
  param([string]$Evidence, [string[]]$AllowedKinds)

  $kindPattern = '(?:' + (@($AllowedKinds | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')'
  $envelope = [regex]::Match($Evidence, '^(?<kind>' + $kindPattern + '):(?<reference>.+)$')
  if (-not $envelope.Success) { return $false }
  $reference = $envelope.Groups['reference'].Value
  $path = ''
  if ($reference.Contains('#')) {
    $anchorMatch = [regex]::Match($reference, '^(?<path>[^#]+)#(?<anchor>[A-Za-z][A-Za-z0-9_.:-]*)$')
    if (-not $anchorMatch.Success) { return $false }
    $path = $anchorMatch.Groups['path'].Value
  }
  else {
    $lineMatch = [regex]::Match($reference, '^(?<path>.+):(?<start>[1-9][0-9]*)(?:-(?<end>[1-9][0-9]*))?$')
    if (-not $lineMatch.Success) { return $false }
    if ($lineMatch.Groups['end'].Success -and [int64]$lineMatch.Groups['end'].Value -lt [int64]$lineMatch.Groups['start'].Value) { return $false }
    $path = $lineMatch.Groups['path'].Value
  }
  $canonicalPath = ConvertTo-ArcCanonicalRepositoryPath -Path $path
  return $canonicalPath -cne '' -and $path -ceq $canonicalPath
}

function Test-ArcCanonicalDiscoverySearchEvidence {
  [CmdletBinding()]
  param([string]$Evidence)

  $match = [regex]::Match($Evidence, '^search:(?<path>[^#]+)#(?:query|search)=[A-Za-z0-9_.:-]+,(?:result|matches)=(?:0|none)$')
  if (-not $match.Success) { return $false }
  $path = $match.Groups['path'].Value
  $canonicalPath = ConvertTo-ArcCanonicalRepositoryPath -Path $path
  return $canonicalPath -cne '' -and $path -ceq $canonicalPath
}

function Test-ResponsibilityDiscovery {
  [CmdletBinding()]
  param([AllowEmptyString()][string]$DiscoveryText, [ValidateSet('incremental','greenfield')][string]$Mode, [string]$ContractText)

  $errors = [Collections.Generic.List[string]]::new()
  foreach ($error in @(Test-ArcResponsibilityStageVersion $ContractText 'DISCOVERY')) { $errors.Add($error) }
  if ([string]::IsNullOrWhiteSpace($DiscoveryText)) {
    $errors.Add('responsibility-discovery-missing')
    return $errors.ToArray()
  }
  foreach ($error in @(Test-ArcDiscoveryResponsibilityContractVersion -DiscoveryText $DiscoveryText)) { $errors.Add($error) }

  $columns = @(
    'Concern', 'Path', 'Inspected Symbols', 'Observed Pattern', 'Primary Responsibility',
    'Owned Capabilities', 'Verification Owner', 'Comparable Reason', 'Evidence',
    'Inspection Status', 'Classification', 'Classification Authority', 'Classification Evidence'
  )
  $table = @(Get-ArcStrictMarkdownTable -Text $DiscoveryText -Heading 'Comparable Target Exemplars' -Columns $columns -Errors $errors)
  if ($table.Count -lt 3) { return $errors.ToArray() }
  $rows = @($table | Select-Object -Skip 2)
  if ($Mode -ceq 'incremental' -and $rows.Count -ne 8) {
    $errors.Add('exemplar-classification-cardinality-invalid')
  }

  foreach ($concern in @($rows | ForEach-Object { $_[0] } | Sort-Object -Unique)) {
    if (@($rows | Where-Object { $_[0] -ceq $concern }).Count -gt 1) {
      $errors.Add('exemplar-classification-row-duplicate')
    }
  }

  $inspectionStatuses = @(Get-ArcContractEnumValues -ContractText $ContractText -Name 'Inspection Status')
  $classifications = @(Get-ArcContractEnumValues -ContractText $ContractText -Name 'Classification')
  foreach ($cells in $rows) {
    $row = [ordered]@{}
    for ($index = 0; $index -lt $columns.Count; $index++) { $row[$columns[$index]] = $cells[$index] }
    $status = $row['Inspection Status']
    $classification = $row['Classification']
    $authority = $row['Classification Authority']
    $classificationEvidence = $row['Classification Evidence']
    $primaryResponsibility = $row['Primary Responsibility']
    $ownedCapabilities = @($row['Owned Capabilities'].Split([char[]]@(',', ';')) | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
    $verificationOwner = $row['Verification Owner']
    $placeholderPattern = '^(?i:<[^>]+>|unknown|none|n/?a|not-applicable|pending|tbd)$'
    if (
      [string]::IsNullOrWhiteSpace($primaryResponsibility) -or
      $primaryResponsibility -match $placeholderPattern -or
      $ownedCapabilities.Count -eq 0 -or
      @($ownedCapabilities | Where-Object { $_ -cnotmatch '^CAP-[A-Z0-9]+(?:-[A-Z0-9]+)*$' }).Count -gt 0 -or
      @($ownedCapabilities | Sort-Object -Unique).Count -ne $ownedCapabilities.Count -or
      [string]::IsNullOrWhiteSpace($verificationOwner) -or
      $verificationOwner -match $placeholderPattern -or
      $verificationOwner -cnotmatch '^VERIFY-OWNER-[A-Z0-9]+(?:-[A-Z0-9]+)*$'
    ) { $errors.Add('responsibility-discovery-field-invalid') }
    $invalidAuthority = (
      [string]::IsNullOrWhiteSpace($authority) -or
      [string]::IsNullOrWhiteSpace($classificationEvidence) -or
      $inspectionStatuses -cnotcontains $status -or
      $classifications -cnotcontains $classification -or
      $status -ceq 'unknown' -or
      ($classification -ceq 'no-equivalent' -and $status -cne 'no-equivalent') -or
      ($classification -cne 'no-equivalent' -and $status -cne 'verified')
    )
    switch ($classification) {
      'preferred' {
        $evidenceItems = @($classificationEvidence.Split(';') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
        if (
          $authority -cne 'factual-discovery-evidence' -or
          $evidenceItems.Count -lt 2 -or
          @($evidenceItems | Sort-Object -Unique).Count -ne $evidenceItems.Count -or
          @($evidenceItems | Where-Object { -not (Test-ArcCanonicalDiscoverySourceEvidence -Evidence $_ -AllowedKinds @('inspection', 'working-evidence')) }).Count -gt 0 -or
          $classificationEvidence -match '(?i)(?:^|;)\s*(?:authoritative-)?conflict:' -or
          @($evidenceItems | Where-Object { $_ -cmatch '\.md#(?:CONFLICT|DEBT)-[A-Z0-9]+(?:-[A-Z0-9]+)*$' }).Count -gt 0
        ) { $invalidAuthority = $true }
      }
      'compatibility-only' {
        if ($authority -ceq 'project-pack-rule') {
          if ($classificationEvidence -cnotmatch '^[A-Za-z0-9_./-]+\.md#RULE-[A-Z0-9-]+$') { $invalidAuthority = $true }
        }
        elseif ($authority -ceq 'approved-owner-decision') {
          if ($classificationEvidence -cnotmatch '^approval:OWNER-[A-Z0-9-]+$') { $invalidAuthority = $true }
        }
        else { $invalidAuthority = $true }
      }
      'legacy-debt' {
        if ($authority -ceq 'project-documentation') {
          if ($classificationEvidence -cnotmatch '^[A-Za-z0-9_./-]+\.md#(?:DEBT|CONFLICT)-[A-Z0-9-]+$') { $invalidAuthority = $true }
        }
        elseif ($authority -ceq 'debt-record') {
          if ($classificationEvidence -cnotmatch '^debt-record:[A-Z0-9-]+$') { $invalidAuthority = $true }
        }
        elseif ($authority -ceq 'tech-lead-approved-conflict') {
          if ($classificationEvidence -cnotmatch '^approval:TECH-LEAD-[A-Z0-9-]+$') { $invalidAuthority = $true }
        }
        else { $invalidAuthority = $true }
      }
      'no-equivalent' {
        if (
          $authority -cne 'factual-discovery-evidence' -or
          -not (
            (Test-ArcCanonicalDiscoverySearchEvidence -Evidence $classificationEvidence) -or
            (Test-ArcCanonicalDiscoverySourceEvidence -Evidence $classificationEvidence -AllowedKinds @('inspection'))
          )
        ) { $invalidAuthority = $true }
      }
      default { $invalidAuthority = $true }
    }
    if ($invalidAuthority) { $errors.Add('exemplar-classification-authority-missing') }
  }
  return @($errors | Select-Object -Unique)
}

function Test-ArcCanonicalDesignAuthorityRows {
  [CmdletBinding()]
  param(
    [object[]]$ResponsibilityRows,
    [object[]]$VerificationRows,
    [object[]]$ApprovedDeviationRows = @(),
    [ValidateSet('incremental/preserve-existing','greenfield/design-new')][string]$ModeConstraint
  )

  $errors = [Collections.Generic.List[string]]::new()
  $responsibilityColumns = @(
    'Responsibility ID', 'Owner Path', 'Owner Symbol', 'Boundary Kind',
    'Primary Responsibility', 'Owned Capability IDs', 'Trace IDs', 'Atomic Boundary ID',
    'Public Symbols', 'External Effects', 'Target Exemplar', 'Exemplar Classification',
    'Classification Authority', 'Classification Evidence', 'Architecture Authority',
    'Co-location Policy', 'Co-location Evidence', 'Verification Owner References',
    'Conformance', 'Deviation Reference'
  )
  $verificationColumns = @(
    'Verification Owner ID', 'Production Responsibility ID', 'Capability ID',
    'Evidence Path', 'Evidence Symbol or Scenario', 'Evidence Kind',
    'Verification Disposition', 'Production Binding Evidence', 'Decision Reference',
    'Verdict', 'Deviation Reference'
  )
  $deviationColumns = @('Deviation Reference', 'Concern', 'Conflict Reference', 'Resolved Decision', 'Tech Lead Approval')
  $boundaryKinds = @('domain', 'data', 'application', 'presentation', 'adapter', 'integration', 'config', 'test', 'project-defined')
  $coLocationPolicies = @('feature-local', 'shared-foundation', 'atomic-owner', 'approved-deviation', 'not-applicable')
  $classifications = @('preferred', 'compatibility-only', 'legacy-debt', 'no-equivalent')
  $architectureAuthorities = @('target-exemplar', 'approved-greenfield-design', 'approved-structural-deviation')
  $evidenceKinds = @('unit', 'integration', 'contract', 'production-composition', 'static-structure', 'generator-verification')
  $verificationDispositions = @('required', 'not-applicable-approved')
  $placeholderPattern = '^(?i:<[^>]+>|unknown|none|n/?a|pending|tbd|placeholder)$'

  $getNames = {
    param([object]$Row)
    if ($Row -is [Collections.IDictionary]) { return @($Row.Keys | ForEach-Object { [string]$_ }) }
    return @($Row.PSObject.Properties.Name)
  }
  $getCell = {
    param([object]$Row, [string]$Name)
    if ($Row -is [Collections.IDictionary]) { return $Row[$Name] }
    $property = $Row.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
  }
  $testExactSchema = {
    param([object]$Row, [string[]]$Expected)
    $actual = @(& $getNames $Row)
    if ($actual.Count -ne $Expected.Count) { return $false }
    foreach ($name in $Expected) {
      if (@($actual | Where-Object { [string]$_ -ceq $name }).Count -ne 1) { return $false }
    }
    return $true
  }
  $readList = {
    param([object]$Row, [string]$Name)
    $raw = @(& $getCell $Row $Name)
    if ($raw.Count -eq 1 -and $raw[0] -is [string]) {
      return @([string]$raw[0] -split '[,;]' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
    }
    return @($raw | ForEach-Object { [string]$_ } | Where-Object { $_ -ne '' })
  }
  $testUnique = {
    param([string[]]$Values)
    $set = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($value in $Values) { if (-not $set.Add([string]$value)) { return $false } }
    return $true
  }
  $testCanonicalPath = {
    param([string]$Value)
    $canonicalPath = ConvertTo-ArcCanonicalRepositoryPath -Path $Value
    return $canonicalPath -cne '' -and $canonicalPath -ceq $Value
  }
  $testNonPlaceholder = {
    param([string]$Value)
    return -not [string]::IsNullOrWhiteSpace($Value) -and $Value -cnotmatch $placeholderPattern
  }
  $testClassificationAuthority = {
    param([string]$Classification, [string]$Authority, [string]$Evidence)
    switch ($Classification) {
      'preferred' {
        $items = @($Evidence.Split(';') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
        return (
          $Authority -ceq 'factual-discovery-evidence' -and
          $items.Count -ge 2 -and
          @($items | Sort-Object -Unique).Count -eq $items.Count -and
          @($items | Where-Object { -not (Test-ArcCanonicalDiscoverySourceEvidence -Evidence $_ -AllowedKinds @('inspection', 'working-evidence')) }).Count -eq 0 -and
          $Evidence -notmatch '(?i)(?:^|;)\s*(?:authoritative-)?conflict:' -and
          @($items | Where-Object { $_ -cmatch '\.md#(?:CONFLICT|DEBT)-[A-Z0-9]+(?:-[A-Z0-9]+)*$' }).Count -eq 0
        )
      }
      'compatibility-only' {
        return (
          ($Authority -ceq 'project-pack-rule' -and $Evidence -cmatch '^[A-Za-z0-9_./-]+\.md#RULE-[A-Z0-9-]+$') -or
          ($Authority -ceq 'approved-owner-decision' -and $Evidence -cmatch '^approval:OWNER-[A-Z0-9-]+$')
        )
      }
      'no-equivalent' {
        return (
          $Authority -ceq 'factual-discovery-evidence' -and
          ((Test-ArcCanonicalDiscoverySearchEvidence -Evidence $Evidence) -or (Test-ArcCanonicalDiscoverySourceEvidence -Evidence $Evidence -AllowedKinds @('inspection')))
        )
      }
      default { return $false }
    }
  }

  $responsibilities = @($ResponsibilityRows)
  $verifications = @($VerificationRows)
  $deviations = @($ApprovedDeviationRows)
  if ($responsibilities.Count -eq 0) { $errors.Add('responsibility-owner-missing'); return $errors.ToArray() }
  foreach ($row in $responsibilities) {
    if (-not (& $testExactSchema $row $responsibilityColumns)) { $errors.Add('responsibility-capability-mismatch') }
  }
  foreach ($row in $verifications) {
    if (-not (& $testExactSchema $row $verificationColumns)) { $errors.Add('verification-disposition-invalid') }
  }
  foreach ($row in $deviations) {
    if (-not (& $testExactSchema $row $deviationColumns)) { $errors.Add('responsibility-capability-mismatch') }
  }
  if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }

  $deviationById = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
  foreach ($row in $deviations) {
    $deviationId = [string](& $getCell $row 'Deviation Reference')
    $decisionMatch = [regex]::Match([string](& $getCell $row 'Resolved Decision'), '^resolved:DECISION-[A-Z0-9]+(?:-[A-Z0-9]+)*:\s*(?<body>\S.*)$')
    if (
      $deviationId -cnotmatch '^DEV-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -or
      $deviationById.ContainsKey($deviationId) -or
      -not (& $testNonPlaceholder ([string](& $getCell $row 'Concern'))) -or
      [string](& $getCell $row 'Conflict Reference') -cnotmatch '^CONFLICT-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -or
      -not $decisionMatch.Success -or
      -not (& $testNonPlaceholder $decisionMatch.Groups['body'].Value) -or
      [string](& $getCell $row 'Tech Lead Approval') -cnotmatch '^approval:TECH-LEAD-[A-Z0-9]+(?:-[A-Z0-9]+)*$'
    ) { $errors.Add('responsibility-capability-mismatch'); continue }
    $deviationById.Add($deviationId, $row)
  }

  $responsibilityById = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
  $ownerTuples = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  $referencedVerificationIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  foreach ($row in $responsibilities) {
    $responsibilityId = [string](& $getCell $row 'Responsibility ID')
    $ownerPath = [string](& $getCell $row 'Owner Path')
    $ownerSymbol = [string](& $getCell $row 'Owner Symbol')
    $boundaryKind = [string](& $getCell $row 'Boundary Kind')
    $primaryResponsibility = [string](& $getCell $row 'Primary Responsibility')
    $capabilities = @(& $readList $row 'Owned Capability IDs')
    $traceIds = @(& $readList $row 'Trace IDs')
    $atomicBoundaryId = [string](& $getCell $row 'Atomic Boundary ID')
    $publicSymbols = @(& $readList $row 'Public Symbols')
    $externalEffects = @(& $readList $row 'External Effects')
    $targetExemplar = [string](& $getCell $row 'Target Exemplar')
    $classification = [string](& $getCell $row 'Exemplar Classification')
    $classificationAuthority = [string](& $getCell $row 'Classification Authority')
    $classificationEvidence = [string](& $getCell $row 'Classification Evidence')
    $architectureAuthority = [string](& $getCell $row 'Architecture Authority')
    $coLocationPolicy = [string](& $getCell $row 'Co-location Policy')
    $coLocationEvidence = [string](& $getCell $row 'Co-location Evidence')
    $verificationReferences = @(& $readList $row 'Verification Owner References')
    $conformance = [string](& $getCell $row 'Conformance')
    $deviationReference = [string](& $getCell $row 'Deviation Reference')
    $targetMatch = [regex]::Match($targetExemplar, '^(?<path>.+)#(?<symbol>[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*)$')
    $publicSymbolsValid = (
      $publicSymbols.Count -eq 1 -and $publicSymbols[0] -ceq 'none'
    ) -or (
      $publicSymbols.Count -gt 0 -and $publicSymbols -cnotcontains 'none' -and
      $publicSymbols -ccontains $ownerSymbol -and
      @($publicSymbols | Where-Object { $_ -cnotmatch '^[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*$' }).Count -eq 0 -and
      (& $testUnique $publicSymbols)
    )
    if (
      $responsibilityId -cnotmatch '^RESP-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -or
      $responsibilityById.ContainsKey($responsibilityId) -or
      -not (& $testCanonicalPath $ownerPath) -or
      $ownerSymbol -cnotmatch '^[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*$' -or
      -not $ownerTuples.Add("$ownerPath#$ownerSymbol") -or
      $boundaryKind -cnotin $boundaryKinds -or
      -not (& $testNonPlaceholder $primaryResponsibility) -or
      $capabilities.Count -eq 0 -or
      @($capabilities | Where-Object { $_ -cnotmatch '^CAP-[A-Z0-9]+(?:-[A-Z0-9]+)*$' }).Count -ne 0 -or
      -not (& $testUnique $capabilities) -or
      $traceIds.Count -eq 0 -or
      @($traceIds | Where-Object { $_ -cnotmatch '^[A-Z][A-Z0-9]*(?:-[A-Z0-9]+)+$' }).Count -ne 0 -or
      -not (& $testUnique $traceIds) -or
      -not $publicSymbolsValid -or
      $externalEffects.Count -eq 0 -or
      @($externalEffects | Where-Object { [string]::IsNullOrWhiteSpace($_) -or $_ -match '<[^>]+>' }).Count -ne 0 -or
      $classification -cnotin $classifications -or
      $classification -ceq 'legacy-debt' -or
      -not (& $testClassificationAuthority $classification $classificationAuthority $classificationEvidence) -or
      $architectureAuthority -cnotin $architectureAuthorities -or
      $coLocationPolicy -cnotin $coLocationPolicies -or
      -not (& $testNonPlaceholder $coLocationEvidence) -or
      $conformance -cnotin @('yes', 'no', 'blocked')
    ) { $errors.Add('responsibility-capability-mismatch') }
    if ($classification -ceq 'preferred' -and (-not $targetMatch.Success -or -not (& $testCanonicalPath $targetMatch.Groups['path'].Value))) { $errors.Add('exemplar-classification-authority-missing') }
    if ($classification -ceq 'no-equivalent' -and $targetExemplar -cne 'no-equivalent') { $errors.Add('exemplar-classification-authority-missing') }
    if ($classification -ceq 'compatibility-only' -and $targetExemplar -cne 'no-equivalent' -and (-not $targetMatch.Success -or -not (& $testCanonicalPath $targetMatch.Groups['path'].Value))) { $errors.Add('exemplar-classification-authority-missing') }
    if ($ModeConstraint -ceq 'greenfield/design-new') {
      if ($architectureAuthority -cne 'approved-greenfield-design' -or $deviationReference -cne 'not-applicable') { $errors.Add('greenfield-authority-invalid') }
    }
    elseif ($classification -ceq 'preferred') {
      if ($architectureAuthority -cne 'target-exemplar') { $errors.Add('exemplar-classification-authority-missing') }
    }
    elseif ($classification -cin @('compatibility-only', 'no-equivalent')) {
      if ($architectureAuthority -cne 'approved-structural-deviation') { $errors.Add('co-location-approval-missing') }
    }
    if ($coLocationPolicy -ceq 'atomic-owner') {
      if ($atomicBoundaryId -cnotmatch '^ATOM-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -or $coLocationEvidence -cnotmatch 'approval:TECH-LEAD-[A-Z0-9-]+') { $errors.Add('co-location-approval-missing') }
    }
    elseif ($atomicBoundaryId -cne 'not-applicable') { $errors.Add('co-location-policy-invalid') }
    if ($coLocationPolicy -ceq 'shared-foundation' -and (($externalEffects -join ';') -cne 'none' -or "$primaryResponsibility;$($publicSymbols -join ';')" -match '(?i)registration|register|route|handler')) { $errors.Add('co-location-policy-invalid') }
    if ($capabilities.Count -gt 1 -and ($deviationReference -cnotmatch '^DEV-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -or $coLocationEvidence -cnotmatch 'approval:TECH-LEAD-[A-Z0-9-]+')) { $errors.Add('co-location-approval-missing') }
    if ($conformance -ceq 'yes' -and $deviationReference -cne 'not-applicable') { $errors.Add('responsibility-capability-mismatch') }
    if ($conformance -ceq 'no' -and ($architectureAuthority -cne 'approved-structural-deviation' -or -not $deviationById.ContainsKey($deviationReference))) { $errors.Add('responsibility-capability-mismatch') }
    if ($conformance -ceq 'blocked') { $errors.Add('responsibility-capability-mismatch') }
    if ($boundaryKind -ceq 'test') {
      if ($ownerPath -notmatch '(?i)(?:^|/)tests?(?:/|$)' -or $primaryResponsibility -notmatch '(?i)verify|test' -or $verificationReferences.Count -ne 1 -or $verificationReferences[0] -cne 'not-applicable') { $errors.Add('verification-owner-extra') }
    }
    else {
      if ($verificationReferences.Count -eq 0 -or $verificationReferences -ccontains 'not-applicable' -or @($verificationReferences | Where-Object { $_ -cnotmatch '^VERIFY-OWNER-[A-Z0-9]+(?:-[A-Z0-9]+)*$' }).Count -ne 0 -or -not (& $testUnique $verificationReferences)) { $errors.Add('verification-owner-missing') }
      foreach ($verificationReference in $verificationReferences) { if (-not $referencedVerificationIds.Add($verificationReference)) { $errors.Add('verification-owner-extra') } }
    }
    if (-not $responsibilityById.ContainsKey($responsibilityId)) { $responsibilityById.Add($responsibilityId, $row) }
  }

  $verificationById = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
  foreach ($row in $verifications) {
    $verificationId = [string](& $getCell $row 'Verification Owner ID')
    $productionId = [string](& $getCell $row 'Production Responsibility ID')
    $capabilityId = [string](& $getCell $row 'Capability ID')
    $evidencePath = [string](& $getCell $row 'Evidence Path')
    $evidenceScenario = [string](& $getCell $row 'Evidence Symbol or Scenario')
    $evidenceKind = [string](& $getCell $row 'Evidence Kind')
    $disposition = [string](& $getCell $row 'Verification Disposition')
    $bindingEvidence = [string](& $getCell $row 'Production Binding Evidence')
    $decisionReference = [string](& $getCell $row 'Decision Reference')
    $verdict = [string](& $getCell $row 'Verdict')
    $deviationReference = [string](& $getCell $row 'Deviation Reference')
    $production = if ($responsibilityById.ContainsKey($productionId)) { $responsibilityById[$productionId] } else { $null }
    $productionCapabilities = if ($null -eq $production) { @() } else { @(& $readList $production 'Owned Capability IDs') }
    $productionBinding = if ($null -eq $production) { '' } else { "$([string](& $getCell $production 'Owner Path'))#$([string](& $getCell $production 'Owner Symbol'))" }
    if (
      $verificationId -cnotmatch '^VERIFY-OWNER-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -or
      $verificationById.ContainsKey($verificationId) -or
      -not $referencedVerificationIds.Contains($verificationId) -or
      $null -eq $production -or
      [string](& $getCell $production 'Boundary Kind') -ceq 'test' -or
      $productionCapabilities -cnotcontains $capabilityId -or
      -not (& $testCanonicalPath $evidencePath) -or
      -not (& $testNonPlaceholder $evidenceScenario) -or
      $evidenceKind -cnotin $evidenceKinds -or
      $disposition -cnotin $verificationDispositions -or
      [string]::IsNullOrWhiteSpace($bindingEvidence) -or
      $bindingEvidence.IndexOf($productionBinding, [StringComparison]::Ordinal) -lt 0 -or
      $verdict -cne 'PASS' -or
      ($deviationReference -cne 'not-applicable' -and -not $deviationById.ContainsKey($deviationReference))
    ) { $errors.Add('verification-disposition-invalid') }
    if ($disposition -ceq 'required' -and $decisionReference -cne 'not-applicable') { $errors.Add('verification-disposition-invalid') }
    if ($disposition -ceq 'not-applicable-approved' -and $decisionReference -cnotmatch '^(?:approval:[A-Z0-9]+(?:-[A-Z0-9]+)*|DECISION-[A-Z0-9]+(?:-[A-Z0-9]+)*)$') { $errors.Add('verification-disposition-invalid') }
    if (-not $verificationById.ContainsKey($verificationId)) { $verificationById.Add($verificationId, $row) }
  }
  if ($verificationById.Count -ne $referencedVerificationIds.Count) { $errors.Add('verification-owner-missing') }
  foreach ($responsibility in $responsibilityById.Values | Where-Object { [string](& $getCell $_ 'Boundary Kind') -cne 'test' }) {
    $productionId = [string](& $getCell $responsibility 'Responsibility ID')
    $capabilities = @(& $readList $responsibility 'Owned Capability IDs')
    foreach ($capabilityId in $capabilities) {
      if (@($verifications | Where-Object { [string](& $getCell $_ 'Production Responsibility ID') -ceq $productionId -and [string](& $getCell $_ 'Capability ID') -ceq $capabilityId }).Count -eq 0) { $errors.Add('verification-owner-missing') }
    }
    $effects = @(& $readList $responsibility 'External Effects')
    $primary = [string](& $getCell $responsibility 'Primary Responsibility')
    if ((($effects -join ';') -cne 'none' -or $primary -match '(?i)routing|lifecycle|composition|registration') -and @($verifications | Where-Object { [string](& $getCell $_ 'Production Responsibility ID') -ceq $productionId -and [string](& $getCell $_ 'Evidence Kind') -ceq 'production-composition' }).Count -eq 0) { $errors.Add('production-composition-test-missing') }
  }
  return @($errors | Select-Object -Unique)
}

function Test-ResponsibilityDesign {
  [CmdletBinding()]
  param([string]$DiscoveryText, [string]$DesignText, [ValidateSet('incremental','greenfield')][string]$Mode, [string]$ContractText)

  $errors = [Collections.Generic.List[string]]::new()
  foreach ($error in @(Test-ArcResponsibilityStageVersion $ContractText 'DESIGN')) { $errors.Add($error) }
  if ([string]::IsNullOrWhiteSpace($DesignText)) {
    $errors.Add('responsibility-owner-missing')
    return $errors.ToArray()
  }

  $designVersion = @(Test-ArcDiscoveryResponsibilityContractVersion -DiscoveryText $DesignText)
  if ($designVersion.Count -ne 0) {
    $errors.Add('responsibility-contract-version-invalid')
    return @($errors | Select-Object -Unique)
  }
  if (@([regex]::Matches((Get-ArcBoundedFrontMatter -Text $DesignText), '(?m)^revision:\s*DESIGN-[A-Z0-9]+(?:-[A-Z0-9]+)*@[1-9][0-9]*\s*$')).Count -ne 1) {
    $errors.Add('responsibility-owner-extra')
    return @($errors | Select-Object -Unique)
  }
  foreach ($error in @(Test-ResponsibilityDiscovery -DiscoveryText $DiscoveryText -Mode $Mode -ContractText $ContractText)) {
    $errors.Add($error)
  }
  if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }

  $plannedColumns = @('Planned Path', 'Planned Symbol', 'Responsibility', 'Exemplar or Deviation Reference')
  $responsibilityColumns = @(
    'Responsibility ID', 'Owner Path', 'Owner Symbol', 'Boundary Kind',
    'Primary Responsibility', 'Owned Capability IDs', 'Trace IDs', 'Atomic Boundary ID',
    'Public Symbols', 'External Effects', 'Target Exemplar', 'Exemplar Classification',
    'Classification Authority', 'Classification Evidence', 'Architecture Authority',
    'Co-location Policy', 'Co-location Evidence', 'Verification Owner References',
    'Conformance', 'Deviation Reference'
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
  if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }
  if ($plannedTable.Count -lt 3 -or $responsibilityTable.Count -lt 3 -or $verificationTable.Count -lt 3) {
    return @($errors | Select-Object -Unique)
  }

  $plannedRows = @($plannedTable | Select-Object -Skip 2)
  $responsibilityRows = @($responsibilityTable | Select-Object -Skip 2)
  $verificationRows = @($verificationTable | Select-Object -Skip 2)
  $normalizePath = { param([string]$Value) ($Value -replace '\\', '/') }
  $toRow = {
    param([string[]]$Cells, [string[]]$Columns)
    $row = [ordered]@{}
    for ($index = 0; $index -lt $Columns.Count; $index++) { $row[$Columns[$index]] = $Cells[$index] }
    return $row
  }
  $splitList = {
    param([string]$Value)
    @($Value -split '[,;]' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
  }
  $isPlaceholder = { param([string]$Value) [string]::IsNullOrWhiteSpace($Value) -or $Value -match '^(?i:<[^>]+>|unknown|none|n/?a|pending|tbd)$' }
  $responsibilities = @($responsibilityRows | ForEach-Object { & $toRow $_ $responsibilityColumns })
  $plannedTuples = @($plannedRows | ForEach-Object { "$( & $normalizePath $_[0])#$($_[1])" })
  $responsibilityTuples = @($responsibilities | ForEach-Object { "$( & $normalizePath $_['Owner Path'])#$($_['Owner Symbol'])" })
  if (
    @($plannedTuples | Sort-Object -Unique).Count -ne $plannedTuples.Count -or
    @($responsibilityTuples | Sort-Object -Unique).Count -ne $responsibilityTuples.Count -or
    (($plannedTuples | Sort-Object -Unique) -join '|') -cne (($responsibilityTuples | Sort-Object -Unique) -join '|')
  ) { $errors.Add('responsibility-owner-missing') }

  $responsibilityIds = @($responsibilities | ForEach-Object { $_['Responsibility ID'] })
  if (
    @($responsibilityIds | Where-Object { $_ -cnotmatch '^RESP-[A-Z0-9]+(?:-[A-Z0-9]+)*$' }).Count -gt 0 -or
    @($responsibilityIds | Sort-Object -Unique).Count -ne $responsibilityIds.Count
  ) { $errors.Add('responsibility-owner-extra') }

  $discoveryColumns = @(
    'Concern', 'Path', 'Inspected Symbols', 'Observed Pattern', 'Primary Responsibility',
    'Owned Capabilities', 'Verification Owner', 'Comparable Reason', 'Evidence',
    'Inspection Status', 'Classification', 'Classification Authority', 'Classification Evidence'
  )
  $discoveryErrors = [Collections.Generic.List[string]]::new()
  $discoveryTable = @(Get-ArcStrictMarkdownTable -Text $DiscoveryText -Heading 'Comparable Target Exemplars' -Columns $discoveryColumns -Errors $discoveryErrors)
  $discoveryRows = @($discoveryTable | Select-Object -Skip 2 | ForEach-Object { & $toRow $_ $discoveryColumns })
  $validPolicies = @(Get-ArcContractEnumValues -ContractText $ContractText -Name 'Co-location Policy')
  $validAuthorities = @(Get-ArcContractEnumValues -ContractText $ContractText -Name 'Architecture Authority')
  $validClassifications = @(Get-ArcContractEnumValues -ContractText $ContractText -Name 'Classification')
  $validEvidenceKinds = @(Get-ArcContractEnumValues -ContractText $ContractText -Name 'Evidence Kind')
  $validDispositions = @(Get-ArcContractEnumValues -ContractText $ContractText -Name 'Verification Disposition')
  $validBoundaryKinds = @(Get-ArcContractEnumValues -ContractText $ContractText -Name 'Boundary Kind')
  $validConformance = @(Get-ArcContractEnumValues -ContractText $ContractText -Name 'Conformance')

  foreach ($row in $responsibilities) {
    $capabilities = @(& $splitList $row['Owned Capability IDs'])
    $publicSymbols = @(& $splitList $row['Public Symbols'])
    $noPublicSymbols = $publicSymbols.Count -eq 1 -and $publicSymbols[0] -ceq 'none'
    $validPublicSymbols = $noPublicSymbols -or (
      $publicSymbols.Count -gt 0 -and
      $publicSymbols -cnotcontains 'none' -and
      $publicSymbols -ccontains $row['Owner Symbol'] -and
      @($publicSymbols | Where-Object { $_ -cnotmatch '^[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*$' }).Count -eq 0
    )
    $policy = $row['Co-location Policy']
    $isTestOwner = $row['Boundary Kind'] -ceq 'test' -and $row['Owner Path'] -match '(?i)(?:^|[\\/])tests?(?:[\\/]|$)' -and $row['Primary Responsibility'] -match '(?i)verify|test'
    if (
      (& $isPlaceholder $row['Primary Responsibility']) -or
      $capabilities.Count -eq 0 -or
      @($capabilities | Where-Object { $_ -cnotmatch '^CAP-[A-Z0-9]+(?:-[A-Z0-9]+)*$' }).Count -gt 0 -or
      @($capabilities | Sort-Object -Unique).Count -ne $capabilities.Count -or
      -not $validPublicSymbols -or
      ((& $isPlaceholder $row['External Effects']) -and $row['External Effects'] -cne 'none')
    ) { $errors.Add('responsibility-capability-mismatch') }
    if ($validBoundaryKinds -cnotcontains $row['Boundary Kind'] -or $validConformance -cnotcontains $row['Conformance']) { $errors.Add('responsibility-capability-mismatch') }
    if ($row['Conformance'] -ceq 'yes' -and $row['Deviation Reference'] -cne 'not-applicable') { $errors.Add('responsibility-capability-mismatch') }
    if ($row['Conformance'] -ceq 'no' -and ($row['Deviation Reference'] -cnotmatch '^DEV-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -or $row['Architecture Authority'] -cne 'approved-structural-deviation')) { $errors.Add('responsibility-capability-mismatch') }
    if ($row['Conformance'] -ceq 'no') {
      $conformanceDeviationColumns = @('Deviation Reference', 'Concern', 'Conflict Reference', 'Resolved Decision', 'Tech Lead Approval')
      $conformanceDeviationErrors = [Collections.Generic.List[string]]::new()
      $conformanceDeviationTable = @(Get-ArcStrictMarkdownTable -Text $DesignText -Heading 'Approved Structural Deviations' -Columns $conformanceDeviationColumns -Errors $conformanceDeviationErrors)
      $conformanceDeviationMatches = @($conformanceDeviationTable | Select-Object -Skip 2 | Where-Object { $_[0] -ceq $row['Deviation Reference'] -and $_[2] -cmatch '^CONFLICT-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -and $_[3] -cmatch '^resolved:DECISION-[A-Z0-9]+(?:-[A-Z0-9]+)*:\s*\S' -and $_[4] -cmatch '^approval:TECH-LEAD-[A-Z0-9]+(?:-[A-Z0-9]+)*$' })
      if ($conformanceDeviationErrors.Count -ne 0 -or $conformanceDeviationMatches.Count -ne 1) { $errors.Add('responsibility-capability-mismatch') }
    }
    if ($row['Conformance'] -ceq 'blocked') { $errors.Add('responsibility-capability-mismatch') }
    if ($validPolicies -cnotcontains $policy) { $errors.Add('co-location-policy-invalid') }
    if (($policy -ceq 'atomic-owner') -and $row['Atomic Boundary ID'] -cnotmatch '^ATOM-[A-Z0-9]+(?:-[A-Z0-9]+)*$') { $errors.Add('co-location-policy-invalid') }
    if (($policy -cne 'atomic-owner') -and $row['Atomic Boundary ID'] -cne 'not-applicable') { $errors.Add('co-location-policy-invalid') }
    if ($policy -ceq 'atomic-owner' -and ($row['Exemplar Classification'] -cne 'preferred' -or $row['Co-location Evidence'] -notmatch '(?i)transaction.*lifecycle.*revert|lifecycle.*transaction.*revert|revert.*transaction.*lifecycle' -or $row['Co-location Evidence'] -cnotmatch 'approval:TECH-LEAD-[A-Z0-9-]+')) { $errors.Add('co-location-approval-missing') }
    if ($policy -ceq 'shared-foundation' -and ($row['External Effects'] -cne 'none' -or "$($row['Primary Responsibility']);$($row['Public Symbols'])" -match '(?i)registration|register|route|handler')) { $errors.Add('co-location-policy-invalid') }
    if ($capabilities.Count -gt 1 -and ($row['Deviation Reference'] -cnotmatch '^DEV-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -or $row['Co-location Evidence'] -cnotmatch 'approval:TECH-LEAD-[A-Z0-9-]+')) { $errors.Add('co-location-approval-missing') }
    if ($row['Exemplar Classification'] -ceq 'legacy-debt') { $errors.Add('debt-exemplar-propagation') }
    if ($validClassifications -cnotcontains $row['Exemplar Classification']) { $errors.Add('exemplar-classification-authority-missing') }
    $approvedDiscovery = @($discoveryRows | Where-Object {
      $_['Classification'] -ceq $row['Exemplar Classification'] -and
      $_['Classification Authority'] -ceq $row['Classification Authority'] -and
      $_['Classification Evidence'] -ceq $row['Classification Evidence']
    })
    if ($approvedDiscovery.Count -eq 0) { $errors.Add('exemplar-classification-authority-missing') }
    if ($row['Target Exemplar'] -cne 'no-equivalent') {
      $exemplarMatch = [regex]::Match($row['Target Exemplar'], '^(?<path>.+)#(?<symbol>[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*)$')
      $matchingExemplar = @($approvedDiscovery | Where-Object {
        $exemplarMatch.Success -and
        (& $normalizePath $_['Path']) -ceq (& $normalizePath $exemplarMatch.Groups['path'].Value) -and
        @(& $splitList $_['Inspected Symbols']) -contains $exemplarMatch.Groups['symbol'].Value
      })
      if ($matchingExemplar.Count -eq 0) { $errors.Add('exemplar-classification-authority-missing') }
    }
    if ($validAuthorities -cnotcontains $row['Architecture Authority']) { $errors.Add('greenfield-authority-invalid') }
    if ($Mode -ceq 'greenfield') {
      if ($row['Architecture Authority'] -cne 'approved-greenfield-design' -or $row['Deviation Reference'] -cne 'not-applicable') { $errors.Add('greenfield-authority-invalid') }
    }
    elseif ($row['Exemplar Classification'] -ceq 'preferred') {
      if ($row['Architecture Authority'] -cne 'target-exemplar') { $errors.Add('exemplar-classification-authority-missing') }
    }
    elseif ($row['Exemplar Classification'] -in @('compatibility-only', 'no-equivalent')) {
      if ($row['Architecture Authority'] -cne 'approved-structural-deviation' -or $row['Deviation Reference'] -cnotmatch '^DEV-[A-Z0-9]+(?:-[A-Z0-9]+)*$') { $errors.Add('co-location-approval-missing') }
    }
    if ($isTestOwner -and $row['Verification Owner References'] -cne 'not-applicable') { $errors.Add('verification-owner-extra') }
    if ($row['Boundary Kind'] -ceq 'test' -and -not $isTestOwner) { $errors.Add('verification-owner-missing') }
  }

  foreach ($aggregate in $responsibilities | Where-Object { @(& $splitList $_['Owned Capability IDs']).Count -gt 1 }) {
    $deviationColumns = @('Deviation Reference', 'Concern', 'Conflict Reference', 'Resolved Decision', 'Tech Lead Approval')
    $deviationErrors = [Collections.Generic.List[string]]::new()
    $deviationTable = @(Get-ArcStrictMarkdownTable -Text $DesignText -Heading 'Approved Structural Deviations' -Columns $deviationColumns -Errors $deviationErrors)
    $approval = [regex]::Match($aggregate['Co-location Evidence'], 'approval:TECH-LEAD-[A-Z0-9-]+').Value
    $matchingDeviation = @($deviationTable | Select-Object -Skip 2 | Where-Object { $_[0] -ceq $aggregate['Deviation Reference'] -and $_[4] -ceq $approval })
    if ($matchingDeviation.Count -ne 1) { $errors.Add('co-location-approval-missing') }
  }

  $verificationOwners = @($verificationRows | ForEach-Object { & $toRow $_ $verificationColumns })
  $verificationIds = @($verificationOwners | ForEach-Object { $_['Verification Owner ID'] })
  if (
    @($verificationIds | Where-Object { $_ -cnotmatch '^VERIFY-OWNER-[A-Z0-9]+(?:-[A-Z0-9]+)*$' }).Count -gt 0 -or
    @($verificationIds | Sort-Object -Unique).Count -ne $verificationIds.Count
  ) { $errors.Add('verification-owner-extra') }
  $responsibilityById = @{}
  foreach ($row in $responsibilities) { $responsibilityById[$row['Responsibility ID']] = $row }
  $referencedVerificationIds = [Collections.Generic.List[string]]::new()
  foreach ($row in $responsibilities | Where-Object { $_['Boundary Kind'] -cne 'test' }) {
    $references = @(& $splitList $row['Verification Owner References'])
    if ($references.Count -eq 0 -or $references -contains 'not-applicable') { $errors.Add('verification-owner-missing') }
    foreach ($reference in $references) { [void]$referencedVerificationIds.Add($reference) }
  }
  foreach ($verification in $verificationOwners) {
    $productionId = $verification['Production Responsibility ID']
    if (-not $responsibilityById.ContainsKey($productionId) -or $responsibilityById[$productionId]['Boundary Kind'] -ceq 'test') { $errors.Add('verification-owner-extra'); continue }
    $production = $responsibilityById[$productionId]
    if ($verification['Verification Owner ID'] -notin $referencedVerificationIds) { $errors.Add('verification-owner-extra') }
    if ($verification['Capability ID'] -notin @(& $splitList $production['Owned Capability IDs'])) { $errors.Add('verification-owner-extra') }
    if ($validEvidenceKinds -cnotcontains $verification['Evidence Kind']) { $errors.Add('verification-disposition-invalid') }
    if ($validDispositions -cnotcontains $verification['Verification Disposition']) { $errors.Add('verification-disposition-invalid') }
    if ($verification['Verdict'] -cnotin @('PASS', 'BLOCKED')) { $errors.Add('verification-disposition-invalid') }
    $bindingTarget = "$($production['Owner Path'])#$($production['Owner Symbol'])"
    if ((& $isPlaceholder $verification['Production Binding Evidence']) -or $verification['Production Binding Evidence'].IndexOf($bindingTarget, [StringComparison]::Ordinal) -lt 0) { $errors.Add('verification-production-binding-missing') }
    if ($verification['Verification Disposition'] -ceq 'required' -and $verification['Decision Reference'] -cne 'not-applicable') { $errors.Add('verification-disposition-invalid') }
    if ($verification['Verification Disposition'] -ceq 'not-applicable-approved') {
      if (-not (Test-ArcNotApplicableApprovedEligibility -ProductionRow $production -VerificationRow $verification -ContractText $ContractText)) { $errors.Add('verification-disposition-invalid') }
    }
  }
  foreach ($production in $responsibilities | Where-Object { $_['Boundary Kind'] -cne 'test' }) {
    foreach ($capability in @(& $splitList $production['Owned Capability IDs'])) {
      $coverage = @($verificationOwners | Where-Object { $_['Production Responsibility ID'] -ceq $production['Responsibility ID'] -and $_['Capability ID'] -ceq $capability })
      if ($coverage.Count -eq 0) { $errors.Add('verification-owner-missing') }
    }
    if (
      ($production['External Effects'] -cne 'none' -or $production['Primary Responsibility'] -match '(?i)routing|lifecycle|composition|registration') -and
      @($verificationOwners | Where-Object { $_['Production Responsibility ID'] -ceq $production['Responsibility ID'] -and $_['Evidence Kind'] -ceq 'production-composition' }).Count -eq 0
    ) { $errors.Add('production-composition-test-missing') }
  }
  return @($errors | Select-Object -Unique)
}

function Test-ResponsibilityPlan {
  [CmdletBinding()]
  param([string]$DesignText, [string]$PlanText, [string]$WorkItemId, [string]$ContractText)

  $errors = [Collections.Generic.List[string]]::new()
  foreach ($error in @(Test-ArcResponsibilityStageVersion $ContractText 'PLAN')) { $errors.Add($error) }
  if ([string]::IsNullOrWhiteSpace($DesignText) -or [string]::IsNullOrWhiteSpace($PlanText) -or [string]::IsNullOrWhiteSpace($WorkItemId)) {
    $errors.Add('responsibility-owner-missing')
    return @($errors | Select-Object -Unique)
  }
  if (@(Test-ArcDiscoveryResponsibilityContractVersion -DiscoveryText $DesignText).Count -ne 0 -or @(Test-ArcDiscoveryResponsibilityContractVersion -DiscoveryText $PlanText).Count -ne 0) {
    $errors.Add('responsibility-contract-version-invalid')
    return @($errors | Select-Object -Unique)
  }
  $designFrontMatter = Get-ArcBoundedFrontMatter -Text $DesignText
  $designRevisionMatches = @([regex]::Matches($designFrontMatter, '(?m)^revision:\s*(?<revision>DESIGN-[A-Z0-9]+(?:-[A-Z0-9]+)*@[1-9][0-9]*)\s*$'))
  $designRunMatches = @([regex]::Matches($designFrontMatter, '(?m)^run_id:\s*(?<run>RUN-[A-Z0-9]+(?:-[A-Z0-9]+)*)\s*$'))
  $designTopLevelKeys = @([regex]::Matches($designFrontMatter, '(?m)^(?<key>[a-z_][a-z0-9_]*):') | ForEach-Object { $_.Groups['key'].Value } | Sort-Object)
  $designHasHumanApprovalEnvelope = (
    @([regex]::Matches($designFrontMatter, '(?m)^status:\s*approved\s*$')).Count -eq 1 -and
    @([regex]::Matches($designFrontMatter, '(?m)^result:\s*complete\s*$')).Count -eq 1 -and
    @([regex]::Matches($designFrontMatter, '(?m)^approval_source:\s*human\s*$')).Count -eq 1 -and
    $designRunMatches.Count -eq 1 -and
    ($designTopLevelKeys -join '|') -ceq 'approval_source|produced_at|responsibility_contract|result|revision|run_id|status|step_id'
  )
  if (
    @([regex]::Matches($designFrontMatter, '(?m)^step_id:\s*07-technical-design\s*$')).Count -ne 1 -or
    -not $designHasHumanApprovalEnvelope -or $designRevisionMatches.Count -ne 1
  ) {
    $errors.Add('responsibility-owner-extra')
  }
  $designRevision = if ($designRevisionMatches.Count -eq 1) { $designRevisionMatches[0].Groups['revision'].Value } else { '' }
  $planFrontMatter = Get-ArcBoundedFrontMatter -Text $PlanText
  $planIsApproved = @([regex]::Matches($planFrontMatter, '(?m)^status:\s*approved\s*$')).Count -eq 1
  $planRunMatches = @([regex]::Matches($planFrontMatter, '(?m)^run_id:\s*(?<run>RUN-[A-Z0-9]+(?:-[A-Z0-9]+)*)\s*$'))
  $planRevisionMatches = @([regex]::Matches($planFrontMatter, '(?m)^revision:\s*(?<revision>[1-9][0-9]*)\s*$'))
  $planTopLevelKeys = @([regex]::Matches($planFrontMatter, '(?m)^(?<key>[a-z_][a-z0-9_]*):') | ForEach-Object { $_.Groups['key'].Value } | Sort-Object)
  $approvedPlanKeyShape = ($planTopLevelKeys -join '|') -ceq 'approval_source|produced_at|responsibility_contract|result|revision|run_id|status|step_id'
  $draftPlanKeyShape = ($planTopLevelKeys -join '|') -cin @(
    'produced_at|responsibility_contract|result|run_id|status|step_id',
    'produced_at|responsibility_contract|result|revision|run_id|status|step_id'
  )
  $planRevisionShapeValid = @([regex]::Matches($planFrontMatter, '(?m)^revision:')).Count -eq $planRevisionMatches.Count -and $planRevisionMatches.Count -le 1
  $planRevision = if ($planRevisionMatches.Count -eq 1) { $planRevisionMatches[0].Groups['revision'].Value } else { '' }
  $planHasHumanApprovalEnvelope = $planIsApproved -and
    @([regex]::Matches($planFrontMatter, '(?m)^result:\s*complete\s*$')).Count -eq 1 -and
    @([regex]::Matches($planFrontMatter, '(?m)^approval_source:\s*human\s*$')).Count -eq 1 -and
    $planRunMatches.Count -eq 1 -and $designRunMatches.Count -eq 1 -and $planRevisionMatches.Count -eq 1 -and
    $planRunMatches[0].Groups['run'].Value -ceq $designRunMatches[0].Groups['run'].Value -and
    $approvedPlanKeyShape -and $planRevisionShapeValid
  if (
    @([regex]::Matches($planFrontMatter, '(?m)^step_id:\s*08-plan-waves\s*$')).Count -ne 1 -or
    @([regex]::Matches($planFrontMatter, '(?m)^status:\s*(?:draft|approved)\s*$')).Count -ne 1 -or
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
  if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }

  $responsibilityColumns = @(
    'Responsibility ID', 'Owner Path', 'Owner Symbol', 'Boundary Kind',
    'Primary Responsibility', 'Owned Capability IDs', 'Trace IDs', 'Atomic Boundary ID',
    'Public Symbols', 'External Effects', 'Target Exemplar', 'Exemplar Classification',
    'Classification Authority', 'Classification Evidence', 'Architecture Authority',
    'Co-location Policy', 'Co-location Evidence', 'Verification Owner References',
    'Conformance', 'Deviation Reference'
  )
  $verificationColumns = @(
    'Verification Owner ID', 'Production Responsibility ID', 'Capability ID',
    'Evidence Path', 'Evidence Symbol or Scenario', 'Evidence Kind',
    'Verification Disposition', 'Production Binding Evidence', 'Decision Reference',
    'Verdict', 'Deviation Reference'
  )
  $adapterColumns = @(
    'Migration Unit ID', 'Work Item ID', 'Parent Work Item ID', 'Master Plan Reference',
    'Master Plan Revision', 'Decomposition Decision Reference', 'Design Revision'
  )
  $planColumns = @(
    'Work Item ID', 'Design Revision', 'Responsibility IDs', 'Shared Foundation IDs',
    'Integration Responsibility IDs', 'Independent Boundary Evidence'
  )

  $designResponsibilityTable = @(Get-ArcStrictMarkdownTable -Text $DesignText -Heading 'File Responsibility Matrix' -Columns $responsibilityColumns -Errors $errors)
  $designVerificationTable = @(Get-ArcStrictMarkdownTable -Text $DesignText -Heading 'Verification Ownership Matrix' -Columns $verificationColumns -Errors $errors)
  $adapterTable = @(Get-ArcStrictMarkdownTable -Text $PlanText -Heading 'Work Item Adapter Trace' -Columns $adapterColumns -Errors $errors)
  $planTable = @(Get-ArcStrictMarkdownTable -Text $PlanText -Heading 'Responsibility Owner References' -Columns $planColumns -Errors $errors)
  $decisionColumns = @('Decision Reference', 'Parent Work Item ID', 'Child Work Item ID', 'Master Plan Reference', 'Master Plan Revision', 'Design Revision', 'Approval Reference', 'Immutable Evidence Reference')
  $decisionHeadingCount = @(Get-ArcMarkdownH2HeadingMatches -Text $DesignText -Heading 'Approved Decomposition Decisions').Count
  $decisionTable = @(if ($decisionHeadingCount -ne 0) {
    Get-ArcStrictMarkdownTable -Text $DesignText -Heading 'Approved Decomposition Decisions' -Columns $decisionColumns -Errors $errors
  })
  if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }
  if ($designResponsibilityTable.Count -lt 3 -or $designVerificationTable.Count -lt 3 -or $adapterTable.Count -lt 3 -or $planTable.Count -lt 3) {
    return @($errors | Select-Object -Unique)
  }

  $toRow = {
    param([string[]]$Cells, [string[]]$Columns)
    $row = [ordered]@{}
    for ($index = 0; $index -lt $Columns.Count; $index++) { $row[$Columns[$index]] = $Cells[$index] }
    return $row
  }
  $splitTrace = {
    param([string]$Value)
    @($Value -split '[,;]' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
  }
  $splitReferences = {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value) -or $Value -ceq 'not-applicable') { return @() }
    @($Value -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
  }

  $designResponsibilities = @($designResponsibilityTable | Select-Object -Skip 2 | ForEach-Object { & $toRow $_ $responsibilityColumns })
  $designVerifications = @($designVerificationTable | Select-Object -Skip 2 | ForEach-Object { & $toRow $_ $verificationColumns })
  $adapterRows = @($adapterTable | Select-Object -Skip 2 | ForEach-Object { & $toRow $_ $adapterColumns })
  $planRows = @($planTable | Select-Object -Skip 2 | ForEach-Object { & $toRow $_ $planColumns })
  [object[]]$decisionRows = @(if ($decisionTable.Count -ge 3) { $decisionTable | Select-Object -Skip 2 | ForEach-Object { & $toRow $_ $decisionColumns } })
  $resolvedDecompositionApprovalPattern = '^approval:TECH-LEAD-(?![^\r\n]*(?:PENDING|TBD|UNKNOWN|PLACEHOLDER))[A-Z0-9]+(?:-[A-Z0-9]+)*$'
  $decisionById = @{}
  if ($decisionRows.Count -gt 0 -and (-not $planHasHumanApprovalEnvelope -or -not $designHasHumanApprovalEnvelope)) {
    $errors.Add('responsibility-owner-extra')
  }
  foreach ($decision in $decisionRows) {
    $decisionId = $decision['Decision Reference']
    $parentWorkItemId = $decision['Parent Work Item ID']
    $childWorkItemId = $decision['Child Work Item ID']
    $decisionAuthorityText = @($decisionColumns | ForEach-Object { [string]$decision[$_] }) -join '|'
    $decisionShapeValid = (
      $decisionId -cmatch '^DEC-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -and
      -not $decisionById.ContainsKey($decisionId) -and
      $parentWorkItemId -cmatch '^WORK-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -and
      $childWorkItemId -cmatch '^WORK-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -and
      $parentWorkItemId -cne $childWorkItemId -and
      $decision['Master Plan Reference'] -cmatch '^(?:[A-Za-z0-9_.-]+/)*[A-Za-z0-9_.-]+\.md$' -and
      $decision['Master Plan Revision'] -ceq $planRevision -and
      $decision['Design Revision'] -ceq $designRevision -and
      $decision['Approval Reference'] -cmatch $resolvedDecompositionApprovalPattern -and
      $decision['Immutable Evidence Reference'] -ceq "$($decision['Master Plan Reference'])@revision=$planRevision`:$decisionId" -and
      $decisionAuthorityText -cnotmatch '(?i)(?:^|[^A-Za-z0-9])(?:PENDING|TBD|UNKNOWN|PLACEHOLDER)(?:$|[^A-Za-z0-9])'
    )
    if (-not $decisionShapeValid) {
      $errors.Add('responsibility-owner-extra')
      continue
    }
    $decisionById[$decisionId] = $decision
    $matchingParentAdapters = @($adapterRows | Where-Object {
      $_['Work Item ID'] -ceq $parentWorkItemId -and
      $_['Parent Work Item ID'] -ceq 'not-applicable' -and
      $_['Decomposition Decision Reference'] -ceq $decisionId -and
      $_['Master Plan Reference'] -ceq $decision['Master Plan Reference'] -and
      $_['Master Plan Revision'] -ceq $planRevision -and
      $_['Design Revision'] -ceq $designRevision
    })
    $matchingChildAdapters = @($adapterRows | Where-Object {
      $_['Work Item ID'] -ceq $childWorkItemId -and
      $_['Parent Work Item ID'] -ceq $parentWorkItemId -and
      $_['Decomposition Decision Reference'] -ceq $decisionId -and
      $_['Master Plan Reference'] -ceq $decision['Master Plan Reference'] -and
      $_['Master Plan Revision'] -ceq $planRevision -and
      $_['Design Revision'] -ceq $designRevision
    })
    if ($matchingParentAdapters.Count -ne 1 -or $matchingChildAdapters.Count -ne 1) {
      $errors.Add('responsibility-owner-extra')
    }
  }
  foreach ($adapterRow in $adapterRows) {
    $adapterDecisionId = $adapterRow['Decomposition Decision Reference']
    $adapterMasterAuthorityValid = (
      $adapterRow['Master Plan Reference'] -ceq 'master-plan.md' -and
      $adapterRow['Master Plan Revision'] -cmatch '^[1-9][0-9]*$' -and
      (-not $planIsApproved -or $adapterRow['Master Plan Revision'] -ceq $planRevision)
    )
    if (-not $adapterMasterAuthorityValid) {
      $errors.Add('responsibility-owner-extra')
    }
    if ($adapterDecisionId -ceq 'not-applicable') {
      if ($adapterRow['Parent Work Item ID'] -cne 'not-applicable') {
        $errors.Add('responsibility-owner-extra')
      }
      continue
    }
    if ($adapterDecisionId -cnotmatch '^DEC-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -or -not $decisionById.ContainsKey($adapterDecisionId)) {
      $errors.Add('responsibility-owner-extra')
      continue
    }
    $adapterDecision = $decisionById[$adapterDecisionId]
    $adapterBindsDecision = (
      ($adapterRow['Work Item ID'] -ceq $adapterDecision['Parent Work Item ID'] -and $adapterRow['Parent Work Item ID'] -ceq 'not-applicable') -or
      ($adapterRow['Work Item ID'] -ceq $adapterDecision['Child Work Item ID'] -and $adapterRow['Parent Work Item ID'] -ceq $adapterDecision['Parent Work Item ID'])
    )
    if (-not $adapterBindsDecision) { $errors.Add('responsibility-owner-extra') }
  }
  if (
    $planIsApproved -and
    (
      -not $planHasHumanApprovalEnvelope -or
      @($adapterRows | Where-Object { $_['Master Plan Revision'] -cne $planRevision }).Count -ne 0 -or
      @($decisionRows | Where-Object { $_['Master Plan Revision'] -cne $planRevision }).Count -ne 0
    )
  ) { $errors.Add('responsibility-owner-extra') }
  $adapterWorkItems = @($adapterRows | ForEach-Object { $_['Work Item ID'] } | Sort-Object)
  $referenceWorkItems = @($planRows | ForEach-Object { $_['Work Item ID'] } | Sort-Object)
  $migrationUnitIds = @($adapterRows | ForEach-Object { $_['Migration Unit ID'] })
  $concreteMigrationUnitIds = @($migrationUnitIds | Where-Object { $_ -cne 'not-applicable' })
  if (
    @($planRows | ForEach-Object { $_['Work Item ID'] } | Sort-Object -Unique).Count -ne $planRows.Count -or
    @($adapterRows | ForEach-Object { $_['Work Item ID'] } | Sort-Object -Unique).Count -ne $adapterRows.Count -or
    @($concreteMigrationUnitIds | Where-Object { $_ -cnotmatch '^UNIT-[A-Z0-9]+(?:-[A-Z0-9]+)*$' }).Count -ne 0 -or
    @($concreteMigrationUnitIds | Sort-Object -Unique).Count -ne $concreteMigrationUnitIds.Count -or
    -not (Test-ArcExactSet -Actual $referenceWorkItems -Expected $adapterWorkItems)
  ) { $errors.Add('responsibility-owner-extra') }
  $responsibilityById = @{}
  foreach ($responsibility in $designResponsibilities) {
    $id = $responsibility['Responsibility ID']
    if ($id -cnotmatch '^RESP-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -or $responsibilityById.ContainsKey($id)) {
      $errors.Add('responsibility-owner-extra')
      continue
    }
    $responsibilityById[$id] = $responsibility
  }
  $verificationById = @{}
  foreach ($verification in $designVerifications) {
    $id = $verification['Verification Owner ID']
    if ($id -cnotmatch '^VERIFY-OWNER-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -or $verificationById.ContainsKey($id)) {
      $errors.Add('verification-owner-extra')
      continue
    }
    $verificationById[$id] = $verification
  }

  $selectedRows = @($planRows | Where-Object { $_['Work Item ID'] -ceq $WorkItemId })
  if ($selectedRows.Count -ne 1) {
    $errors.Add('responsibility-owner-missing')
  }

  $referencedByWorkItem = @{}
  foreach ($planRow in $planRows) {
    $workItem = $planRow['Work Item ID']
    $adapterMatches = @($adapterRows | Where-Object { $_['Work Item ID'] -ceq $workItem })
    if ($adapterMatches.Count -ne 1 -or $adapterMatches[0]['Design Revision'] -cne $planRow['Design Revision'] -or $planRow['Design Revision'] -cne $designRevision) {
      $errors.Add('responsibility-owner-extra')
    }
    if (-not (Test-ArcIndependentBoundaryEvidence $planRow['Independent Boundary Evidence'])) {
      $errors.Add('responsibility-owner-missing')
    }

    $groups = [ordered]@{
      'Responsibility IDs' = @(& $splitReferences $planRow['Responsibility IDs'])
      'Shared Foundation IDs' = @(& $splitReferences $planRow['Shared Foundation IDs'])
      'Integration Responsibility IDs' = @(& $splitReferences $planRow['Integration Responsibility IDs'])
    }
    $allReferences = @($groups['Responsibility IDs'] + $groups['Shared Foundation IDs'] + $groups['Integration Responsibility IDs'])
    if ($allReferences.Count -eq 0 -or @($allReferences | Sort-Object -Unique).Count -ne $allReferences.Count) {
      $errors.Add('responsibility-owner-extra')
    }
    foreach ($reference in $allReferences) {
      if (-not $responsibilityById.ContainsKey($reference)) {
        $errors.Add('responsibility-owner-extra')
        continue
      }
      $owner = $responsibilityById[$reference]
      if (@(& $splitTrace $owner['Trace IDs']) -cnotcontains $workItem) {
        $errors.Add('responsibility-owner-extra')
      }
      if ($referencedByWorkItem.ContainsKey($reference) -and $referencedByWorkItem[$reference] -cne $workItem) {
        $previousWorkItem = $referencedByWorkItem[$reference]
        $previousAdapter = @($adapterRows | Where-Object { $_['Work Item ID'] -ceq $previousWorkItem })
        $currentAdapter = @($adapterRows | Where-Object { $_['Work Item ID'] -ceq $workItem })
        $approvedParentChildReuse = $planHasHumanApprovalEnvelope -and $designHasHumanApprovalEnvelope -and $previousAdapter.Count -eq 1 -and $currentAdapter.Count -eq 1 -and
          $currentAdapter[0]['Decomposition Decision Reference'] -cmatch '^DEC-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -and
          $currentAdapter[0]['Decomposition Decision Reference'] -ceq $previousAdapter[0]['Decomposition Decision Reference'] -and
          $currentAdapter[0]['Master Plan Reference'] -ceq $previousAdapter[0]['Master Plan Reference'] -and
          $currentAdapter[0]['Master Plan Revision'] -ceq $previousAdapter[0]['Master Plan Revision'] -and
          $currentAdapter[0]['Design Revision'] -ceq $previousAdapter[0]['Design Revision'] -and
          (
            ($currentAdapter[0]['Parent Work Item ID'] -ceq $previousWorkItem -and $previousAdapter[0]['Parent Work Item ID'] -ceq 'not-applicable') -or
            ($previousAdapter[0]['Parent Work Item ID'] -ceq $workItem -and $currentAdapter[0]['Parent Work Item ID'] -ceq 'not-applicable')
        )
        if ($approvedParentChildReuse) {
          $parentWorkItem = if ($currentAdapter[0]['Parent Work Item ID'] -ceq $previousWorkItem) { $previousWorkItem } else { $workItem }
          $childWorkItem = if ($parentWorkItem -ceq $previousWorkItem) { $workItem } else { $previousWorkItem }
          $decisionReference = $currentAdapter[0]['Decomposition Decision Reference']
          $matchingDecisions = @($decisionRows | Where-Object {
            $_['Decision Reference'] -ceq $decisionReference -and
            $_['Parent Work Item ID'] -ceq $parentWorkItem -and
            $_['Child Work Item ID'] -ceq $childWorkItem -and
            $_['Master Plan Reference'] -ceq $currentAdapter[0]['Master Plan Reference'] -and
            $_['Master Plan Revision'] -ceq $currentAdapter[0]['Master Plan Revision'] -and
            $_['Master Plan Revision'] -ceq $planRevision -and
            $_['Design Revision'] -ceq $designRevision -and
            $_['Approval Reference'] -cmatch '^approval:TECH-LEAD-(?![^\r\n]*(?:PENDING|TBD|UNKNOWN|PLACEHOLDER))[A-Z0-9]+(?:-[A-Z0-9]+)*$' -and
            $_['Immutable Evidence Reference'] -ceq "$($_['Master Plan Reference'])@revision=$planRevision`:$decisionReference"
          })
          $approvedParentChildReuse = $matchingDecisions.Count -eq 1
        }
        if (-not $approvedParentChildReuse) { $errors.Add('responsibility-owner-extra') }
      }
      else { $referencedByWorkItem[$reference] = $workItem }
    }
    foreach ($reference in $groups['Responsibility IDs']) {
      if ($responsibilityById.ContainsKey($reference) -and ($responsibilityById[$reference]['Co-location Policy'] -ceq 'shared-foundation' -or $responsibilityById[$reference]['Boundary Kind'] -ceq 'integration')) {
        $errors.Add('responsibility-owner-extra')
      }
    }
    foreach ($reference in $groups['Shared Foundation IDs']) {
      if ($responsibilityById.ContainsKey($reference) -and $responsibilityById[$reference]['Co-location Policy'] -cne 'shared-foundation') {
        $errors.Add('responsibility-owner-extra')
      }
    }
    foreach ($reference in $groups['Integration Responsibility IDs']) {
      if ($responsibilityById.ContainsKey($reference) -and $responsibilityById[$reference]['Boundary Kind'] -cne 'integration') {
        $errors.Add('responsibility-owner-extra')
      }
    }

    $expected = @($designResponsibilities | Where-Object {
      $_['Boundary Kind'] -cne 'test' -and @(& $splitTrace $_['Trace IDs']) -ccontains $workItem
    })
    $expectedConcrete = @($expected | Where-Object {
      $_['Co-location Policy'] -cne 'shared-foundation' -and $_['Boundary Kind'] -cne 'integration'
    } | ForEach-Object { $_['Responsibility ID'] })
    $expectedShared = @($expected | Where-Object { $_['Co-location Policy'] -ceq 'shared-foundation' } | ForEach-Object { $_['Responsibility ID'] })
    $expectedIntegration = @($expected | Where-Object { $_['Boundary Kind'] -ceq 'integration' } | ForEach-Object { $_['Responsibility ID'] })
    if (
      -not (Test-ArcExactSet -Actual $groups['Responsibility IDs'] -Expected $expectedConcrete) -or
      -not (Test-ArcExactSet -Actual $groups['Shared Foundation IDs'] -Expected $expectedShared) -or
      -not (Test-ArcExactSet -Actual $groups['Integration Responsibility IDs'] -Expected $expectedIntegration)
    ) { $errors.Add('responsibility-owner-missing') }

    foreach ($reference in $allReferences) {
      if (-not $responsibilityById.ContainsKey($reference)) { continue }
      $owner = $responsibilityById[$reference]
      foreach ($verificationReference in @(& $splitTrace $owner['Verification Owner References'])) {
        if (-not $verificationById.ContainsKey($verificationReference) -or $verificationById[$verificationReference]['Production Responsibility ID'] -cne $reference) {
          $errors.Add('verification-owner-missing')
        }
      }
    }
  }
  return @($errors | Select-Object -Unique)
}

function Test-ResponsibilityImplementation {
  [CmdletBinding()]
  param([string]$DesignText, [string]$ImplementationText, [string]$ContractText)
  $errors = [Collections.Generic.List[string]]::new()
  foreach ($error in @(Test-ArcResponsibilityStageVersion $ContractText 'IMPLEMENTATION')) { $errors.Add($error) }
  if ([string]::IsNullOrWhiteSpace($DesignText) -or [string]::IsNullOrWhiteSpace($ImplementationText)) {
    $errors.Add('responsibility-owner-missing')
    return @($errors | Select-Object -Unique)
  }
  if (@(Test-ArcDiscoveryResponsibilityContractVersion -DiscoveryText $ImplementationText).Count -ne 0) {
    $errors.Add('responsibility-contract-version-invalid')
    return @($errors | Select-Object -Unique)
  }

  $implementationSelectorColumns = @('Work Item ID', 'Adapter Kind', 'External ID', 'Authority', 'Authority Revision', 'Approval Reference', 'Parent Selector', 'Acceptance', 'Trace IDs', 'Mode Constraint', 'Design Revision', 'Parent Work Item ID', 'Decomposition Decision Reference', 'Canonical Match')
  $implementationSelectedUnitColumns = @('Migration Unit ID', 'Plan Reference', 'Approval Reference', 'Mode Constraint', 'Bootstrap Scope', 'Foundation Baseline ID', 'Foundation Baseline Reference', 'Foundation Baseline Approval Reference', 'Baseline Reference', 'Trace IDs')
  $implementationSelectorTable = @(Get-ArcStrictMarkdownTable -Text $ImplementationText -Heading 'Canonical Adapter Evidence' -Columns $implementationSelectorColumns -Errors $errors)
  if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }
  if ($implementationSelectorTable.Count -ne 3) { $errors.Add('responsibility-evidence-missing'); return @($errors | Select-Object -Unique) }
  $implementationSelector = [ordered]@{}
  for ($index = 0; $index -lt $implementationSelectorColumns.Count; $index++) { $implementationSelector[$implementationSelectorColumns[$index]] = [string]$implementationSelectorTable[2][$index] }
  $selectedHeadingCount = @(Get-ArcMarkdownH2HeadingMatches -Text $ImplementationText -Heading 'Selected Migration Unit').Count
  if (
    $implementationSelector['Canonical Match'] -cne 'PASS' -or
    $implementationSelector['Work Item ID'] -cnotmatch '^WORK-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -or
    $implementationSelector['Adapter Kind'] -cnotin @('migration-unit', 'task', 'story', 'package', 'phase', 'milestone', 'none') -or
    $implementationSelector['Mode Constraint'] -cnotin @('incremental/preserve-existing', 'greenfield/design-new')
  ) {
    $errors.Add('responsibility-evidence-missing')
  }
  if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }
  if ($implementationSelector['Adapter Kind'] -ceq 'migration-unit') {
    $selectedTable = @(Get-ArcStrictMarkdownTable -Text $ImplementationText -Heading 'Selected Migration Unit' -Columns $implementationSelectedUnitColumns -Errors $errors)
    if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }
    if ($selectedHeadingCount -ne 1 -or $selectedTable.Count -ne 3 -or $implementationSelector['Authority'] -cmatch '@' -or $implementationSelector['Authority Revision'] -cnotmatch '^[1-9][0-9]*$') { $errors.Add('responsibility-evidence-missing') }
    else {
      $selected = [ordered]@{}
      for ($index = 0; $index -lt $implementationSelectedUnitColumns.Count; $index++) { $selected[$implementationSelectedUnitColumns[$index]] = [string]$selectedTable[2][$index] }
      if ($selected['Migration Unit ID'] -cne $implementationSelector['External ID'] -or $selected['Plan Reference'] -cne "$($implementationSelector['Authority'])@$($implementationSelector['Authority Revision'])" -or $selected['Approval Reference'] -cne $implementationSelector['Approval Reference'] -or $selected['Mode Constraint'] -cne $implementationSelector['Mode Constraint'] -or $selected['Trace IDs'] -cne $implementationSelector['Trace IDs']) { $errors.Add('responsibility-evidence-missing') }
    }
  }
  elseif ($selectedHeadingCount -ne 0) { $errors.Add('responsibility-evidence-missing') }
  if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }

  $responsibilityColumns = @(
    'Responsibility ID', 'Owner Path', 'Owner Symbol', 'Boundary Kind',
    'Primary Responsibility', 'Owned Capability IDs', 'Trace IDs', 'Atomic Boundary ID',
    'Public Symbols', 'External Effects', 'Target Exemplar', 'Exemplar Classification',
    'Classification Authority', 'Classification Evidence', 'Architecture Authority',
    'Co-location Policy', 'Co-location Evidence', 'Verification Owner References',
    'Conformance', 'Deviation Reference'
  )
  $verificationColumns = @(
    'Verification Owner ID', 'Production Responsibility ID', 'Capability ID',
    'Evidence Path', 'Evidence Symbol or Scenario', 'Evidence Kind',
    'Verification Disposition', 'Production Binding Evidence', 'Decision Reference',
    'Verdict', 'Deviation Reference'
  )
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
  if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }
  if ($designResponsibilityTable.Count -lt 3 -or $designVerificationTable.Count -lt 3 -or $actualResponsibilityTable.Count -lt 3 -or $actualVerificationTable.Count -lt 3 -or $ownerReferenceTable.Count -lt 3 -or $verdictTable.Count -lt 3) {
    return @($errors | Select-Object -Unique)
  }

  $toRow = {
    param([object]$Cells, [string[]]$Columns)
    $row = @{}
    for ($index = 0; $index -lt $Columns.Count; $index++) { $row[$Columns[$index]] = [string]$Cells[$index] }
    return $row
  }
  $allDesignResponsibilities = @($designResponsibilityTable | Select-Object -Skip 2 | ForEach-Object { & $toRow $_ $responsibilityColumns })
  $actualResponsibilities = @($actualResponsibilityTable | Select-Object -Skip 2 | ForEach-Object { & $toRow $_ $actualResponsibilityColumns })
  $allDesignVerifications = @($designVerificationTable | Select-Object -Skip 2 | ForEach-Object { & $toRow $_ $verificationColumns })
  $actualVerifications = @($actualVerificationTable | Select-Object -Skip 2 | ForEach-Object { & $toRow $_ $actualVerificationColumns })
  $missing = { param([string]$Value) [string]::IsNullOrWhiteSpace($Value) -or $Value -match '^\s*<[^>]+>\s*$' -or $Value -match '^(?i:pending|unknown|none|tbd)$' }
  $missingVerificationEvidence = {
    param([string]$Value)
    (& $missing $Value) -or $Value -match '^(?i:not[- ]?applicable|n/?a|placeholder|todo)$'
  }
  $hasActualEvidence = { param([string]$Value) -not (& $missing $Value) -and $Value -cmatch '^(?:diff|source):\S' }
  $splitList = { param([string]$Value) @($Value -split '[,;]' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }) }
  $validEvidenceKinds = @(Get-ArcContractEnumValues -ContractText $ContractText -Name 'Evidence Kind')
  $validDispositions = @(Get-ArcContractEnumValues -ContractText $ContractText -Name 'Verification Disposition')
  $requiredVerificationRowsPass = $true

  $ownerReferenceRows = @($ownerReferenceTable | Select-Object -Skip 2 | ForEach-Object { & $toRow $_ $ownerReferenceColumns })
  $selectedResponsibilityIds = @()
  if ($ownerReferenceRows.Count -ne 1) { $errors.Add('responsibility-owner-missing') }
  else {
    $ownerReference = $ownerReferenceRows[0]
    foreach ($field in @('Responsibility IDs', 'Shared Foundation IDs', 'Integration Responsibility IDs')) {
      if ($ownerReference[$field] -cne 'not-applicable') { $selectedResponsibilityIds += @(& $splitList $ownerReference[$field]) }
    }
    if ($ownerReference['Work Item ID'] -cnotmatch '^WORK-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -or $ownerReference['Design Revision'] -cnotmatch '^DESIGN-[A-Z0-9]+(?:-[A-Z0-9]+)*@[1-9][0-9]*$' -or (& $missing $ownerReference['Independent Boundary Evidence']) -or $selectedResponsibilityIds.Count -eq 0) { $errors.Add('responsibility-owner-missing') }
    if (@($selectedResponsibilityIds | Sort-Object -Unique).Count -ne $selectedResponsibilityIds.Count) { $errors.Add('responsibility-owner-extra') }
  }
  $allDesignResponsibilityIds = @($allDesignResponsibilities | ForEach-Object { $_['Responsibility ID'] })
  if (@($selectedResponsibilityIds | Where-Object { $allDesignResponsibilityIds -cnotcontains $_ }).Count -gt 0) { $errors.Add('responsibility-owner-extra') }
  $designResponsibilities = @($allDesignResponsibilities | Where-Object { $selectedResponsibilityIds -ccontains $_['Responsibility ID'] })
  $designVerifications = @($allDesignVerifications | Where-Object { $selectedResponsibilityIds -ccontains $_['Production Responsibility ID'] })

  $designById = @{}; foreach ($row in $designResponsibilities) { if ($designById.ContainsKey($row['Responsibility ID'])) { $errors.Add('responsibility-owner-extra') } else { $designById[$row['Responsibility ID']] = $row } }
  $actualById = @{}; foreach ($row in $actualResponsibilities) {
    if ($actualById.ContainsKey($row['Responsibility ID'])) { $errors.Add('responsibility-owner-extra') } else { $actualById[$row['Responsibility ID']] = $row }
    if (-not (& $hasActualEvidence $row['Actual Evidence'])) { $errors.Add('responsibility-owner-missing') }
  }
  foreach ($id in $designById.Keys) { if (-not $actualById.ContainsKey($id)) { $errors.Add('responsibility-owner-missing') } }
  foreach ($id in $actualById.Keys) { if (-not $designById.ContainsKey($id)) { $errors.Add('responsibility-owner-extra') } }
  foreach ($id in $designById.Keys | Where-Object { $actualById.ContainsKey($_) }) {
    $planned = $designById[$id]; $actual = $actualById[$id]
    if ($planned['Owner Path'] -cne $actual['Owner Path'] -or $planned['Owner Symbol'] -cne $actual['Owner Symbol'] -or $planned['Public Symbols'] -cne $actual['Public Symbols']) { $errors.Add('responsibility-public-symbol-mismatch') }
    if ($planned['Owned Capability IDs'] -cne $actual['Owned Capability IDs'] -or $planned['Trace IDs'] -cne $actual['Trace IDs']) { $errors.Add('responsibility-capability-mismatch') }
    if ($planned['External Effects'] -cne $actual['External Effects']) { $errors.Add('responsibility-external-effect-mismatch') }
    foreach ($field in @('Boundary Kind', 'Primary Responsibility', 'Atomic Boundary ID', 'Target Exemplar', 'Exemplar Classification', 'Classification Authority', 'Classification Evidence', 'Architecture Authority', 'Co-location Policy', 'Co-location Evidence', 'Conformance', 'Deviation Reference', 'Verification Owner References')) {
      if ($planned[$field] -cne $actual[$field]) { $errors.Add('co-location-policy-invalid') }
    }
  }

  $designVerificationByKey = @{}; foreach ($row in $designVerifications) { $key = "$($row['Verification Owner ID'])|$($row['Production Responsibility ID'])|$($row['Capability ID'])"; if ($designVerificationByKey.ContainsKey($key)) { $errors.Add('verification-owner-extra') } else { $designVerificationByKey[$key] = $row } }
  $actualVerificationByKey = @{}; foreach ($row in $actualVerifications) {
    $key = "$($row['Verification Owner ID'])|$($row['Production Responsibility ID'])|$($row['Capability ID'])"
    if ($actualVerificationByKey.ContainsKey($key)) { $errors.Add('verification-owner-extra') } else { $actualVerificationByKey[$key] = $row }
    if (-not (& $hasActualEvidence $row['Actual Evidence'])) { $errors.Add('verification-production-binding-missing') }
    if ($validEvidenceKinds -cnotcontains $row['Evidence Kind'] -or $validDispositions -cnotcontains $row['Verification Disposition'] -or $row['Verdict'] -cnotin @('PASS', 'BLOCKED')) {
      $errors.Add('verification-disposition-invalid')
    }
    if ($row['Verification Disposition'] -ceq 'required') {
      $canonicalEvidencePath = ConvertTo-ArcCanonicalRepositoryPath -Path $row['Evidence Path']
      $canonicalEvidenceScenario = $row['Evidence Symbol or Scenario']
      $evidencePathInvalid =
        $canonicalEvidencePath -ceq '' -or
        $canonicalEvidencePath -cne $row['Evidence Path'] -or
        (& $missingVerificationEvidence $row['Evidence Path'])
      $evidenceScenarioInvalid = & $missingVerificationEvidence $canonicalEvidenceScenario
      if (
        $row['Verdict'] -cne 'PASS' -or
        $evidencePathInvalid -or
        $evidenceScenarioInvalid
      ) {
        $requiredVerificationRowsPass = $false
        if ($evidencePathInvalid -or $evidenceScenarioInvalid) {
          $errors.Add('verification-production-binding-missing')
        }
      }
    }
    if ($actualById.ContainsKey($row['Production Responsibility ID'])) {
      $production = $actualById[$row['Production Responsibility ID']]
      $bindingTarget = "$($production['Owner Path'])#$($production['Owner Symbol'])"
      if ((& $missing $row['Production Binding Evidence']) -or $row['Production Binding Evidence'].IndexOf($bindingTarget, [StringComparison]::Ordinal) -lt 0) { $errors.Add('verification-production-binding-missing') }
      if ($row['Verification Disposition'] -ceq 'not-applicable-approved') {
        if (-not (Test-ArcNotApplicableApprovedEligibility -ProductionRow $production -VerificationRow $row -ContractText $ContractText)) { $errors.Add('verification-disposition-invalid') }
      }
      elseif ($row['Decision Reference'] -cne 'not-applicable') { $errors.Add('verification-disposition-invalid') }
      if (@(& $splitList $production['Owned Capability IDs']) -cnotcontains $row['Capability ID']) { $errors.Add('verification-owner-extra') }
    }
  }
  foreach ($key in $designVerificationByKey.Keys) {
    if (-not $actualVerificationByKey.ContainsKey($key)) {
      $errors.Add('verification-owner-missing')
      if ($designVerificationByKey[$key]['Verification Disposition'] -ceq 'required') { $requiredVerificationRowsPass = $false }
    }
  }
  foreach ($key in $actualVerificationByKey.Keys) { if (-not $designVerificationByKey.ContainsKey($key)) { $errors.Add('verification-owner-extra') } }
  foreach ($key in $designVerificationByKey.Keys | Where-Object { $actualVerificationByKey.ContainsKey($_) }) {
    $planned = $designVerificationByKey[$key]; $actual = $actualVerificationByKey[$key]
    foreach ($field in $verificationColumns) { if ($planned[$field] -cne $actual[$field]) { $errors.Add('verification-production-binding-missing'); break } }
  }

  $verdictRows = @($verdictTable | Select-Object -Skip 2)
  if ($verdictRows.Count -ne 1) { $errors.Add('responsibility-owner-extra') }
  else {
    $verdict = & $toRow $verdictRows[0] $verdictColumns
    if ($verdict['Responsibility Contract Version'] -cne '1' -or (& $missing $verdict['Evidence References'])) { $errors.Add('responsibility-contract-version-invalid') }
    foreach ($field in @('Tree Conformance', 'Responsibility Conformance', 'Verification Ownership', 'Architecture Conformance State')) { if ($verdict[$field] -cnotin @('PASS', 'BLOCKED')) { $errors.Add('responsibility-owner-extra') } }
    $derived = if ($verdict['Tree Conformance'] -ceq 'PASS' -and $verdict['Responsibility Conformance'] -ceq 'PASS' -and $verdict['Verification Ownership'] -ceq 'PASS') { 'PASS' } else { 'BLOCKED' }
    $derivedVerificationOwnership = if ($requiredVerificationRowsPass) { 'PASS' } else { 'BLOCKED' }
    if ($verdict['Verification Ownership'] -cne $derivedVerificationOwnership) { $errors.Add('responsibility-waiver-forbidden') }
    if ($verdict['Architecture Conformance State'] -cne $derived) { $errors.Add('responsibility-waiver-forbidden') }
  }
  return @($errors | Select-Object -Unique)
}

function Invoke-ArcPinnedGit {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$SourceRoot, [Parameter(Mandatory)][string[]]$Arguments)

  $output = @(& git -C $SourceRoot @Arguments 2>$null)
  if ($LASTEXITCODE -ne 0) { throw "Pinned source git command failed: git -C $SourceRoot $($Arguments -join ' ')" }
  return ($output -join [Environment]::NewLine).Trim()
}

function ConvertTo-ArcCanonicalRepositoryPath {
  [CmdletBinding()]
  param([Parameter(Mandatory)][AllowEmptyString()][string]$Path)

  if ([string]::IsNullOrWhiteSpace($Path) -or $Path -cne $Path.Trim()) { return '' }
  foreach ($character in $Path.ToCharArray()) {
    if ([char]::IsControl($character)) { return '' }
  }
  $canonicalPath = $Path.Replace('\', '/')
  if ($canonicalPath.StartsWith('/', [StringComparison]::Ordinal) -or $canonicalPath -cmatch '^[A-Za-z]:' -or $canonicalPath -match '[<>:"|?*#;]') { return '' }
  $segments = @($canonicalPath.Split('/'))
  if ($segments.Count -eq 0) { return '' }
  $canonicalSegments = [Collections.Generic.List[string]]::new()
  foreach ($segment in $segments) {
    if ([string]::IsNullOrWhiteSpace($segment) -or $segment -cne $segment.Trim() -or $segment -cin @('.', '..')) { return '' }
    $canonicalSegments.Add($segment.Normalize([Text.NormalizationForm]::FormC))
  }
  return ($canonicalSegments -join '/')
}

function ConvertTo-ArcComparableRootPath {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Path)

  $fullPath = [IO.Path]::GetFullPath($Path)
  $pathRoot = [IO.Path]::GetPathRoot($fullPath)
  if ($fullPath.Length -gt $pathRoot.Length) {
    return $fullPath.TrimEnd([char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar))
  }
  return $fullPath
}

function ConvertTo-ArcCanonicalReviewEvidenceItem {
  [CmdletBinding()]
  param([Parameter(Mandatory)][AllowEmptyString()][string]$EvidenceItem)

  $match = [regex]::Match(
    $EvidenceItem,
    '^(?<kind>source|diff):(?<task>[0-9a-f]{40})(?<range>\.\.(?<final>[0-9a-f]{40}))?:(?<paths>[^#;\r\n]+)#(?<anchor>[A-Za-z][A-Za-z0-9_.:-]*)$'
  )
  if (-not $match.Success) { return '' }
  $kind = $match.Groups['kind'].Value
  $hasRange = $match.Groups['range'].Success
  if (($kind -ceq 'source' -and $hasRange) -or ($kind -ceq 'diff' -and -not $hasRange)) { return '' }

  $rawPaths = $match.Groups['paths'].Value
  $delimiterCount = [regex]::Matches($rawPaths, '->').Count
  if (($kind -ceq 'source' -and $delimiterCount -ne 0) -or ($kind -ceq 'diff' -and $delimiterCount -gt 1)) { return '' }
  $pathParts = @([regex]::Split($rawPaths, '->'))
  if (($kind -ceq 'source' -and $pathParts.Count -ne 1) -or ($kind -ceq 'diff' -and $pathParts.Count -notin @(1, 2))) { return '' }

  $canonicalPaths = [Collections.Generic.List[string]]::new()
  foreach ($pathPart in $pathParts) {
    $canonicalPath = ConvertTo-ArcCanonicalRepositoryPath -Path $pathPart
    if ($canonicalPath -ceq '') { return '' }
    $canonicalPaths.Add($canonicalPath)
  }
  $shaRange = if ($kind -ceq 'source') {
    $match.Groups['task'].Value
  }
  else {
    "$($match.Groups['task'].Value)..$($match.Groups['final'].Value)"
  }
  return "${kind}:${shaRange}:$($canonicalPaths -join '->')#$($match.Groups['anchor'].Value)"
}

function Test-ArcCanonicalProductionPath {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Path)

  # Phase 1 uses repository-relative roots as the language-neutral production
  # classifier. Tests, docs, tooling, generated output, and repository metadata
  # remain non-production unless an approved responsibility selects them.
  $canonicalPath = ConvertTo-ArcCanonicalRepositoryPath -Path $Path
  if ($canonicalPath -ceq '') { return $false }
  return $canonicalPath -cmatch '^(?:(?:src|lib|app|apps/[^/]+/(?:src|lib|app)|packages/[^/]+/(?:src|lib|app)|server|client|frontend|backend)/)' -and
    $canonicalPath -cnotmatch '(?:^|/)(?:test|tests|spec|specs|docs?|scripts?|tools?|generated|build|dist)(?:/|$)'
}

function Get-ArcApprovedReviewDesignRevision {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$DesignText, [Parameter(Mandatory)][AllowEmptyCollection()][Collections.Generic.List[string]]$Errors)

  $frontMatter = Get-ArcBoundedFrontMatter -Text $DesignText
  $revisionMatches = @([regex]::Matches($frontMatter, '(?m)^revision:\s*(?<value>DESIGN-[A-Z0-9]+(?:-[A-Z0-9]+)*@[1-9][0-9]*)\s*$'))
  if (
    @([regex]::Matches($frontMatter, '(?m)^step_id:\s*07-technical-design\s*$')).Count -ne 1 -or
    @([regex]::Matches($frontMatter, '(?m)^status:\s*approved\s*$')).Count -ne 1 -or
    @([regex]::Matches($frontMatter, '(?m)^result:\s*complete\s*$')).Count -ne 1 -or
    $revisionMatches.Count -ne 1
  ) {
    $Errors.Add('responsibility-owner-extra')
    return ''
  }
  return $revisionMatches[0].Groups['value'].Value
}

function Test-ArcPathScopedFormatterCommand {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Command,
    [Parameter(Mandatory)][string]$CanonicalPath
  )

  if ($Command -match '[\x00-\x1F\x7F;&|<>]') { return $false }
  $tokenPattern = '(?<!\S)(?:"(?<double>[^"]*)"|''(?<single>[^'']*)''|(?<bare>[^\s"'']+))(?!\S)'
  $tokenMatches = @([regex]::Matches($Command, $tokenPattern))
  if (-not [string]::IsNullOrWhiteSpace([regex]::Replace($Command, $tokenPattern, ''))) { return $false }
  $tokens = @($tokenMatches | ForEach-Object {
    if ($_.Groups['double'].Success) { $_.Groups['double'].Value }
    elseif ($_.Groups['single'].Success) { $_.Groups['single'].Value }
    else { $_.Groups['bare'].Value }
  })
  if ($tokens.Count -lt 2) { return $false }

  $executableLeaf = @($tokens[0].Replace('\', '/') -split '/')[-1]
  $executableSuffix = [IO.Path]::GetExtension($executableLeaf)
  if ($executableSuffix -cnotin @('', '.exe', '.cmd', '.bat', '.com', '.ps1')) { return $false }
  $executableName = if ($executableSuffix -ceq '') {
    $executableLeaf
  }
  else {
    [IO.Path]::GetFileNameWithoutExtension($executableLeaf)
  }
  if (
    [string]::IsNullOrWhiteSpace($executableName) -or
    $tokens[0].StartsWith('-', [StringComparison]::Ordinal) -or
    $tokens[0] -match '[*?\[\]]' -or
    (ConvertTo-ArcCanonicalRepositoryPath -Path $CanonicalPath) -cne $CanonicalPath
  ) { return $false }

  $formatterId = ''
  $argumentIndex = -1
  $word = {
    param([int]$Index)
    if ($Index -ge $tokens.Count) { return '' }
    return $tokens[$Index]
  }
  $firstWord = & $word 1
  $secondWord = & $word 2
  $thirdWord = & $word 3

  $directFormatters = @('prettier', 'black', 'gofmt', 'rustfmt', 'clang-format', 'csharpier', 'stylua', 'shfmt')
  if ($directFormatters -ccontains $executableName) {
    $formatterId = $executableName
    $argumentIndex = 1
  }
  elseif (@('ruff', 'biome', 'dart') -ccontains $executableName -and $firstWord -ceq 'format') {
    $formatterId = $executableName
    $argumentIndex = 2
  }
  elseif (@('go', 'cargo', 'deno') -ccontains $executableName -and $firstWord -ceq 'fmt') {
    $formatterId = $executableName
    $argumentIndex = 2
  }
  elseif ($executableName -ceq 'dotnet' -and $firstWord -ceq 'csharpier') {
    $formatterId = 'csharpier'
    $argumentIndex = 2
  }
  elseif (@('python', 'python3', 'py') -ccontains $executableName -and $firstWord -ceq '-m') {
    if ($secondWord -ceq 'ruff' -and $thirdWord -ceq 'format') {
      $formatterId = 'ruff'
      $argumentIndex = 4
    }
    elseif ($secondWord -ceq 'black') {
      $formatterId = 'black'
      $argumentIndex = 3
    }
  }
  elseif (@('npx', 'bunx') -ccontains $executableName) {
    if ($firstWord -ceq 'biome' -and $secondWord -ceq 'format') {
      $formatterId = 'biome'
      $argumentIndex = 3
    }
    elseif ($firstWord -ceq 'prettier') {
      $formatterId = 'prettier'
      $argumentIndex = 2
    }
  }
  elseif (@('npm', 'pnpm', 'yarn', 'bun') -ccontains $executableName -and $firstWord -ceq 'exec') {
    if ($secondWord -ceq 'biome' -and $thirdWord -ceq 'format') {
      $formatterId = 'biome'
      $argumentIndex = 4
    }
    elseif ($secondWord -ceq 'prettier') {
      $formatterId = 'prettier'
      $argumentIndex = 3
    }
  }
  elseif (@('uv', 'pipx') -ccontains $executableName -and $firstWord -ceq 'run') {
    if ($secondWord -ceq 'ruff' -and $thirdWord -ceq 'format') {
      $formatterId = 'ruff'
      $argumentIndex = 4
    }
    elseif ($secondWord -ceq 'black') {
      $formatterId = 'black'
      $argumentIndex = 3
    }
  }
  if ($formatterId -ceq '' -or $argumentIndex -lt 0 -or $argumentIndex -ge $tokens.Count) { return $false }

  $positiveInteger = '^[1-9][0-9]*$'
  $nonnegativeInteger = '^[0-9]+$'
  $formatterOptionGrammar = @{
    'dart' = @{
      Switches = @('--set-exit-if-changed', '--follow-links')
      Values = @{
        '--line-length' = $positiveInteger
        '--output' = '^(?:show|json|none|write)$'
        '-o' = '^(?:show|json|none|write)$'
      }
    }
    'ruff' = @{
      Switches = @('--check', '--diff', '--quiet', '--verbose', '--no-cache', '--respect-gitignore', '--no-respect-gitignore', '--preview', '--no-preview')
      Values = @{
        '--line-length' = $positiveInteger
        '--target-version' = '^py[0-9]{2,3}$'
      }
    }
    'biome' = @{
      Switches = @('--write', '--fix', '--unsafe', '--verbose', '--colors', '--no-colors')
      Values = @{
        '--line-width' = $positiveInteger
        '--indent-width' = $positiveInteger
        '--indent-style' = '^(?:tab|space)$'
        '--line-ending' = '^(?:lf|crlf|cr)$'
        '--quote-style' = '^(?:double|single)$'
      }
    }
    'prettier' = @{
      Switches = @(
        '--write', '--check', '--list-different', '--debug-check', '--use-tabs', '--single-quote',
        '--jsx-single-quote', '--semi', '--no-semi', '--bracket-spacing', '--no-bracket-spacing',
        '--bracket-same-line', '--no-bracket-same-line', '--vue-indent-script-and-style',
        '--no-vue-indent-script-and-style'
      )
      Values = @{
        '--print-width' = $positiveInteger
        '--tab-width' = $positiveInteger
        '--range-start' = $nonnegativeInteger
        '--range-end' = $nonnegativeInteger
        '--parser' = '^(?:angular|babel|babel-flow|babel-ts|css|espree|flow|glimmer|graphql|html|json|json5|json-stringify|less|lwc|markdown|mdx|meriyah|scss|typescript|vue|yaml)$'
        '--end-of-line' = '^(?:lf|crlf|cr|auto)$'
        '--trailing-comma' = '^(?:all|es5|none)$'
        '--quote-props' = '^(?:as-needed|consistent|preserve)$'
        '--prose-wrap' = '^(?:always|never|preserve)$'
        '--embedded-language-formatting' = '^(?:auto|off)$'
        '--html-whitespace-sensitivity' = '^(?:css|strict|ignore)$'
        '--arrow-parens' = '^(?:always|avoid)$'
      }
    }
    'black' = @{
      Switches = @(
        '--check', '--diff', '--color', '--fast', '--safe', '--preview', '--quiet', '--verbose',
        '--skip-string-normalization', '--skip-magic-trailing-comma'
      )
      Values = @{
        '--line-length' = $positiveInteger
        '--target-version' = '^py[0-9]{2,3}$'
        '--workers' = $positiveInteger
      }
    }
    'gofmt' = @{
      Switches = @('-w', '-d', '-e', '-s')
      Values = @{}
    }
    'rustfmt' = @{
      Switches = @('--check', '--quiet', '--verbose')
      Values = @{
        '--edition' = '^(?:2015|2018|2021|2024)$'
        '--emit' = '^(?:files|stdout|coverage|modified-lines|checkstyle|json)$'
        '--color' = '^(?:auto|always|never)$'
      }
    }
    'clang-format' = @{
      Switches = @('-i', '--dry-run', '--werror', '--verbose', '--sort-includes', '--no-sort-includes')
      Values = @{
        '--style' = '^(?i:llvm|google|chromium|mozilla|webkit|microsoft|gnu|file)$'
      }
    }
    'csharpier' = @{
      Switches = @('--check', '--fast', '--write-stdout')
      Values = @{
        '--log-level' = '^(?:trace|debug|information|warning|error|critical|none)$'
      }
    }
    'stylua' = @{
      Switches = @('--check', '--verify', '--verbose')
      Values = @{
        '--column-width' = $positiveInteger
        '--indent-width' = $positiveInteger
        '--indent-type' = '^(?:Tabs|Spaces)$'
        '--line-endings' = '^(?:Unix|Windows)$'
        '--quote-style' = '^(?:AutoPreferDouble|AutoPreferSingle|ForceDouble|ForceSingle)$'
        '--call-parentheses' = '^(?:Always|NoSingleString|NoSingleTable|None|Input)$'
      }
    }
    'shfmt' = @{
      Switches = @('-w', '-d', '-s', '-mn', '-ci', '-sr', '-kp', '-fn')
      Values = @{
        '-i' = $nonnegativeInteger
        '-ln' = '^(?:bash|posix|mksh|bats)$'
      }
    }
    'go' = @{
      Switches = @('-n', '-x')
      Values = @{
        '-mod' = '^(?:readonly|vendor|mod)$'
      }
    }
    'cargo' = @{
      Switches = @('--check', '--quiet', '--verbose')
      Values = @{
        '--package' = '^[A-Za-z0-9][A-Za-z0-9_.-]*$'
      }
    }
    'deno' = @{
      Switches = @('--check', '--use-tabs', '--single-quote', '--no-semicolons', '--unstable-component')
      Values = @{
        '--line-width' = $positiveInteger
        '--indent-width' = $positiveInteger
        '--prose-wrap' = '^(?:always|never|preserve)$'
        '--ext' = '^(?:ts|tsx|js|jsx|md|json|jsonc|css|scss|sass|less|html|vue|svelte|astro|yml|yaml|ipynb)$'
      }
    }
  }

  $optionGrammar = $formatterOptionGrammar[$formatterId]
  if ($null -eq $optionGrammar) { return $false }
  $targetCount = 0
  for ($tokenIndex = $argumentIndex; $tokenIndex -lt $tokens.Count; $tokenIndex++) {
    $token = $tokens[$tokenIndex]
    if ([string]::IsNullOrWhiteSpace($token)) { return $false }
    if ($token.StartsWith('-', [StringComparison]::Ordinal)) {
      $optionParts = @($token -split '=', 2)
      $optionName = $optionParts[0]
      $hasInlineValue = $token.IndexOf('=', [StringComparison]::Ordinal) -ge 0
      if (@($optionGrammar.Switches) -ccontains $optionName) {
        if ($hasInlineValue) { return $false }
        continue
      }
      if (@($optionGrammar.Values.Keys) -cnotcontains $optionName) { return $false }
      $optionValue = if ($hasInlineValue) {
        $optionParts[1]
      }
      else {
        $tokenIndex++
        if ($tokenIndex -ge $tokens.Count) { return $false }
        $tokens[$tokenIndex]
      }
      if ([string]::IsNullOrWhiteSpace($optionValue) -or $optionValue -cnotmatch $optionGrammar.Values[$optionName]) { return $false }
      continue
    }
    if ($token -cne $CanonicalPath) { return $false }
    $targetCount++
  }
  return $targetCount -eq 1
}

function Get-ArcImplementationReviewProvenance {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$ImplementationText, [Parameter(Mandatory)][AllowEmptyCollection()][Collections.Generic.List[string]]$Errors)

  $columns = @('Task / Unit', 'File', 'File Kind', 'Edited Region / Symbol', 'Formatter Command', 'Unrelated Diff', 'Checkpoint History', 'Task-base SHA', 'Final-tree SHA')
  $tableErrors = [Collections.Generic.List[string]]::new()
  $table = @(Get-ArcStrictMarkdownTable -Text $ImplementationText -Heading 'Change Hygiene' -Columns $columns -Errors $tableErrors)
  if ($tableErrors.Count -ne 0) {
    foreach ($tableError in $tableErrors) { $Errors.Add($tableError) }
    return $null
  }
  if ($table.Count -lt 3) {
    $Errors.Add('responsibility-evidence-missing')
    return $null
  }
  $rows = @($table | Select-Object -Skip 2)
  foreach ($row in $rows) {
    $canonicalPath = ConvertTo-ArcCanonicalRepositoryPath -Path ([string]$row[1]).Trim()
    if ($canonicalPath -ceq '') { $Errors.Add('responsibility-evidence-missing') }
    else { $row[1] = $canonicalPath }
    $editedRegion = ([string]$row[3]).Trim()
    $formatterCommand = ([string]$row[4]).Trim()
    $unrelatedDiff = ([string]$row[5]).Trim()
    if (
      $editedRegion -cnotmatch '^[A-Za-z_][A-Za-z0-9_.:-]*(?:, [A-Za-z_][A-Za-z0-9_.:-]*)*$' -or
      $editedRegion -match '(?i)^(?:none|all|entire|whole|repository|repo|root|file)$'
    ) { $Errors.Add('change-hygiene-invalid') }
    if ($formatterCommand -cne 'none') {
      if (-not (Test-ArcPathScopedFormatterCommand -Command $formatterCommand -CanonicalPath $canonicalPath)) { $Errors.Add('change-hygiene-invalid') }
    }
    if ($unrelatedDiff -cne 'none' -and $unrelatedDiff -cnotmatch '^confirmed:MAJOR-[A-Z0-9]+(?:-[A-Z0-9]+)*$') {
      $Errors.Add('change-hygiene-invalid')
    }
  }
  if ($Errors.Count -ne 0) { return $null }
  $taskUnits = @($rows | ForEach-Object { $_[0].Trim() } | Sort-Object -Unique)
  $taskBases = @($rows | ForEach-Object { $_[7].Trim() } | Sort-Object -Unique)
  $finalTrees = @($rows | ForEach-Object { $_[8].Trim() } | Sort-Object -Unique)
  if ($taskUnits.Count -ne 1 -or $taskUnits[0] -cnotmatch '^(?:WORK|UNIT)-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -or $taskBases.Count -ne 1 -or $finalTrees.Count -ne 1 -or $taskBases[0] -cnotmatch '^[0-9a-f]{40}$' -or $finalTrees[0] -cnotmatch '^[0-9a-f]{40}$') {
    $Errors.Add('responsibility-evidence-missing')
    return $null
  }
  return [pscustomobject]@{ TaskUnit = $taskUnits[0]; TaskBaseSha = $taskBases[0]; FinalTreeSha = $finalTrees[0]; Rows = $rows }
}

function Test-ArcDeletedSourceEvidence {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][string]$SourceText,
    [Parameter(Mandatory)][string]$DiffText,
    [string[]]$OwnerIds = @(),
    [Parameter(Mandatory)][AllowEmptyCollection()][Collections.Generic.List[string]]$Errors
  )

  $removedDiff = @($DiffText -split '\r?\n' | Where-Object { $_ -cmatch '^-' -and $_ -cnotmatch '^---' }) -join "`n"
  $deletedOwners = [Collections.Generic.List[object]]::new()
  $sourceLexicalLines = @(Get-ArcSourceLexicalLines -SourceText $SourceText -SourcePath $Path)
  if (@($sourceLexicalLines | Where-Object { $_.Ambiguous }).Count -gt 0) {
    $Errors.Add('responsibility-evidence-missing')
    return @()
  }
  $ownerBlocks = @(Get-ArcResponsibilitySourceBlocks -SourceText $SourceText -LexicalLines $sourceLexicalLines -SourcePath $Path -Errors $Errors)
  foreach ($ownerBlock in $ownerBlocks) {
    if ($OwnerIds.Count -gt 0 -and $OwnerIds -cnotcontains $ownerBlock.Id) { continue }
    $block = $ownerBlock.Text
    $owner = [pscustomobject]@{
      Id = $ownerBlock.Id
      Path = $Path
      BasePath = $Path
      FinalPath = ''
      RenameMapping = ''
      OwnerSymbols = [Collections.Generic.List[string]]::new()
      Symbols = [Collections.Generic.List[string]]::new()
      Capabilities = [Collections.Generic.List[string]]::new()
      Effects = [Collections.Generic.List[string]]::new()
      ArchitectureAuthorities = [Collections.Generic.List[string]]::new()
      CoLocationPolicies = [Collections.Generic.List[string]]::new()
      VerificationOwners = [Collections.Generic.List[string]]::new()
      RouteSymbols = [Collections.Generic.List[string]]::new()
      Providers = [Collections.Generic.List[string]]::new()
    }
    $anchors = [Collections.Generic.List[string]]::new()
    $anchors.Add($ownerBlock.Id)
    foreach ($definition in @(
      [pscustomobject]@{ Property = 'OwnerSymbols'; Pattern = '^\s*@owner-symbol\s+(?<value>[A-Za-z][A-Za-z0-9_.:-]*)\s*$' },
      [pscustomobject]@{ Property = 'Symbols'; Pattern = '^\s*@public-symbol\s+(?<value>[A-Za-z][A-Za-z0-9_.:-]*)\s*$' },
      [pscustomobject]@{ Property = 'Capabilities'; Pattern = '^\s*@owned-capability\s+(?<value>CAP-[A-Z0-9]+(?:-[A-Z0-9]+)*)\s*$' },
      [pscustomobject]@{ Property = 'Effects'; Pattern = '^\s*@effect\s+(?<value>[^\r\n]+?)\s*$' },
      [pscustomobject]@{ Property = 'ArchitectureAuthorities'; Pattern = '^\s*@architecture-authority\s+(?<value>[a-z][a-z-]*)\s*$' },
      [pscustomobject]@{ Property = 'CoLocationPolicies'; Pattern = '^\s*@co-location-policy\s+(?<value>[a-z][a-z-]*)\s*$' },
      [pscustomobject]@{ Property = 'VerificationOwners'; Pattern = '^\s*@verification-owner\s+(?<value>VERIFY-OWNER-[A-Z0-9]+(?:-[A-Z0-9]+)*)\s*$' }
    )) {
      $matches = @([regex]::Matches($block, "(?m)$($definition.Pattern)"))
      if ($matches.Count -eq 0) { $Errors.Add('responsibility-evidence-missing'); continue }
      foreach ($match in $matches) {
        $value = $match.Groups['value'].Value.Trim()
        $owner.($definition.Property).Add($value)
        $anchors.Add($value)
      }
    }
    foreach ($routeMatch in @([regex]::Matches($block, '(?m)^\s*route\s+(?<symbol>[A-Za-z][A-Za-z0-9_.:-]*)\s*->\s*(?<provider>[A-Za-z][A-Za-z0-9_.:-]*)\s*$'))) {
      $owner.RouteSymbols.Add($routeMatch.Groups['symbol'].Value)
      $owner.Providers.Add($routeMatch.Groups['provider'].Value)
      $anchors.Add($routeMatch.Groups['symbol'].Value)
      $anchors.Add($routeMatch.Groups['provider'].Value)
    }
    if ($removedDiff.IndexOf("@responsibility $($ownerBlock.Id)", [StringComparison]::Ordinal) -lt 0 -or @($anchors | Select-Object -Unique | Where-Object { $removedDiff.IndexOf($_, [StringComparison]::Ordinal) -lt 0 }).Count -gt 0) {
      $Errors.Add('responsibility-evidence-missing')
    }
    $deletedOwners.Add($owner)
  }
  return $deletedOwners.ToArray()
}

function Get-ArcSourceLexicalLines {
  [CmdletBinding()]
  param(
    [AllowEmptyString()][string]$SourceText,
    [AllowEmptyString()][string]$SourcePath = ''
  )

  $lines = @($SourceText -split '\r\n|\n|\r')
  $result = [Collections.Generic.List[object]]::new()
  $extension = [IO.Path]::GetExtension($SourcePath).ToLowerInvariant()
  $unknownLanguage = $extension -eq '' -or $extension -ceq '.source'
  $cFamilyExtensions = @('.c', '.h', '.cc', '.cpp', '.cxx', '.hpp', '.java', '.js', '.jsx', '.mjs', '.cjs', '.ts', '.tsx', '.dart', '.cs', '.rs', '.go', '.swift', '.kt', '.kts', '.scala')
  $slashLineComment = $unknownLanguage -or $extension -in $cFamilyExtensions
  $dashLineComment = $unknownLanguage -or $extension -in @('.sql', '.hs', '.lhs', '.lua')
  $semicolonLineComment = $unknownLanguage -or $extension -in @('.lisp', '.cl', '.clj', '.cljs', '.scm', '.ss', '.rkt', '.asm', '.s', '.ini', '.cfg')
  $hashLineComment = $unknownLanguage -or $extension -in @('.py', '.pyw', '.sh', '.bash', '.zsh', '.rb', '.pl', '.pm', '.yaml', '.yml', '.toml', '.ps1', '.psm1', '.psd1')
  $cPreprocessor = $extension -in @('.c', '.h', '.cc', '.cpp', '.cxx', '.hpp')
  $hashDirectiveLanguage = $extension -in @('.cs', '.rs')
  $javascriptLanguage = $extension -in @('.js', '.jsx', '.mjs', '.cjs', '.ts', '.tsx')
  $cStyleBlockComment = $unknownLanguage -or $extension -in ($cFamilyExtensions + @('.css', '.sql'))
  $markupBlockComment = $unknownLanguage -or $extension -in @('.html', '.htm', '.xml', '.md', '.markdown')
  $powerShellBlockComment = $unknownLanguage -or $extension -in @('.ps1', '.psm1', '.psd1')
  $typescriptLanguage = $extension -in @('.ts', '.tsx')
  $blockCommentEnd = ''
  $blockCommentStart = -1
  $multilineStringDelimiter = ''
  $multilineStringStart = -1
  $javascriptTemplateStack = [Collections.Generic.List[object]]::new()
  $javascriptQuotedString = $null
  $newJavascriptCodeState = {
    [pscustomobject]@{
      RegexCanStart = $true
      StatementStart = $true
      PendingControlHeader = ''
      PendingDeclarationPosition = $false
      PendingArrowBody = $false
      PendingCaseLabel = $false
      CaseLabelBraceDepth = -1
      CaseLabelParenthesisDepth = -1
      PendingLabelCandidate = $false
      ConditionalDepth = 0
      RestrictedProduction = ''
      RestrictedLabelSeen = $false
      LastTokenKind = 'start'
      ParenthesisContexts = [Collections.Generic.List[string]]::new()
      BraceContexts = [Collections.Generic.List[string]]::new()
      DeclarationContexts = [Collections.Generic.List[object]]::new()
    }
  }
  $javascriptRootCodeState = & $newJavascriptCodeState
  $getJavascriptCodeState = {
    if (
      $javascriptTemplateStack.Count -gt 0 -and
      $javascriptTemplateStack[$javascriptTemplateStack.Count - 1].InExpression
    ) {
      return $javascriptTemplateStack[$javascriptTemplateStack.Count - 1].CodeState
    }
    return $javascriptRootCodeState
  }
  $setJavascriptStatementStart = {
    param([Parameter(Mandatory)][object]$State)

    $State.RegexCanStart = $true
    $State.StatementStart = $true
    $State.PendingControlHeader = ''
    $State.PendingDeclarationPosition = $false
    $State.PendingArrowBody = $false
    $State.PendingCaseLabel = $false
    $State.CaseLabelBraceDepth = -1
    $State.CaseLabelParenthesisDepth = -1
    $State.PendingLabelCandidate = $false
    $State.ConditionalDepth = 0
    $State.RestrictedProduction = ''
    $State.RestrictedLabelSeen = $false
    $State.LastTokenKind = 'statement-start'
  }
  $getJavascriptOpenBraceContext = {
    param([Parameter(Mandatory)][object]$State)

    if ($State.PendingArrowBody) {
      $State.PendingArrowBody = $false
      return 'value-block'
    }
    if ($State.DeclarationContexts.Count -gt 0) {
      $declarationContext = $State.DeclarationContexts[$State.DeclarationContexts.Count - 1]
      if (
        $declarationContext.ReadyForBody -and
        $declarationContext.BaseParenthesisDepth -eq $State.ParenthesisContexts.Count -and
        $declarationContext.BaseBraceDepth -eq $State.BraceContexts.Count
      ) {
        $State.DeclarationContexts.RemoveAt($State.DeclarationContexts.Count - 1)
        return [string]$declarationContext.BraceContext
      }
    }
    if ([string]$State.PendingControlHeader -ceq 'catch') {
      $State.PendingControlHeader = ''
      return 'block'
    }
    if (
      $State.StatementStart -or
      @('start', 'statement-start', 'statement-prefix', 'block-close', 'control-header-close', 'parenthesis-close') -ccontains $State.LastTokenKind
    ) {
      return 'block'
    }
    return 'object'
  }
  $setJavascriptTokenState = {
    param(
      [Parameter(Mandatory)][object]$State,
      [Parameter(Mandatory)][string]$Kind,
      [AllowEmptyString()][string]$Token = ''
    )

    $restrictedProduction = [string]$State.RestrictedProduction
    if ($restrictedProduction -cne '') {
      if ($Kind -ceq 'semicolon') {
        [void](& $setJavascriptStatementStart $State)
        return
      }
      if (
        $Kind -ceq 'identifier' -and
        @('break', 'continue') -ccontains $restrictedProduction -and
        -not $State.RestrictedLabelSeen
      ) {
        $State.RestrictedLabelSeen = $true
        $State.RegexCanStart = $true
        $State.StatementStart = $false
        $State.LastTokenKind = 'restricted-label'
        return
      }
      if (@('break', 'continue', 'debugger') -ccontains $restrictedProduction) {
        [void](& $setJavascriptStatementStart $State)
      }
      else {
        $State.RestrictedProduction = ''
        $State.RestrictedLabelSeen = $false
      }
    }

    $pendingControlHeader = [string]$State.PendingControlHeader
    $statementStartBeforeToken = [bool]$State.StatementStart
    if ($State.PendingArrowBody -and $Kind -cne 'open-brace') { $State.PendingArrowBody = $false }
    if ($State.PendingLabelCandidate -and $Kind -cne 'colon') { $State.PendingLabelCandidate = $false }
    if ($State.PendingDeclarationPosition -and $Kind -cne 'identifier') { $State.PendingDeclarationPosition = $false }
    switch ($Kind) {
      'identifier' {
        if ($State.LastTokenKind -ceq 'member-access') {
          $State.PendingControlHeader = ''
          $State.PendingDeclarationPosition = $false
          $State.RegexCanStart = $false
          $State.StatementStart = $false
          $State.LastTokenKind = 'operand'
        }
        elseif ($pendingControlHeader -ceq 'for' -and $Token -ceq 'await') {
          $State.PendingControlHeader = 'for-await'
          $State.RegexCanStart = $true
          $State.StatementStart = $false
          $State.LastTokenKind = 'control-keyword-modifier'
        }
        elseif (
          @('if', 'while', 'for', 'with', 'switch') -ccontains $Token -or
          ($Token -ceq 'catch' -and $statementStartBeforeToken)
        ) {
          $State.PendingControlHeader = $Token
          $State.RegexCanStart = $true
          $State.StatementStart = $false
          $State.LastTokenKind = 'control-keyword'
        }
        elseif (@('else', 'do', 'try', 'finally') -ccontains $Token) {
          $State.PendingControlHeader = ''
          $State.RegexCanStart = $true
          $State.StatementStart = $true
          $State.LastTokenKind = 'statement-prefix'
        }
        elseif (@('break', 'continue', 'return', 'throw', 'debugger') -ccontains $Token) {
          $State.PendingControlHeader = ''
          $State.RestrictedProduction = $Token
          $State.RestrictedLabelSeen = $false
          $State.RegexCanStart = $true
          $State.StatementStart = $false
          $State.LastTokenKind = 'restricted-keyword'
        }
        elseif (
          (
            @('export', 'async', 'declare', 'abstract') -ccontains $Token -and
            ($statementStartBeforeToken -or $State.PendingDeclarationPosition)
          ) -or
          ($Token -ceq 'default' -and $State.PendingDeclarationPosition)
        ) {
          $State.PendingControlHeader = ''
          $State.PendingDeclarationPosition = $true
          $State.PendingLabelCandidate = $Token -ceq 'async' -and $statementStartBeforeToken
          $State.RegexCanStart = $Token -ceq 'default'
          $State.StatementStart = $false
          $State.LastTokenKind = 'declaration-modifier'
        }
        elseif (@('class', 'function') -ccontains $Token) {
          $State.PendingControlHeader = ''
          $declarationAtStatementStart = $statementStartBeforeToken -or $State.PendingDeclarationPosition
          $State.DeclarationContexts.Add([pscustomobject]@{
            Kind = $Token
            BraceContext = $(if ($declarationAtStatementStart) { 'block' } else { 'value-block' })
            BaseParenthesisDepth = $State.ParenthesisContexts.Count
            BaseBraceDepth = $State.BraceContexts.Count
            ParameterDepth = -1
            ReadyForBody = $Token -ceq 'class'
          })
          $State.PendingDeclarationPosition = $false
          $State.RegexCanStart = $true
          $State.StatementStart = $false
          $State.LastTokenKind = 'declaration-keyword'
        }
        elseif (@('case', 'default') -ccontains $Token -and $statementStartBeforeToken) {
          $State.PendingControlHeader = ''
          $State.PendingDeclarationPosition = $false
          $State.PendingCaseLabel = $true
          $State.CaseLabelBraceDepth = $State.BraceContexts.Count
          $State.CaseLabelParenthesisDepth = $State.ParenthesisContexts.Count
          $State.RegexCanStart = $true
          $State.StatementStart = $false
          $State.LastTokenKind = 'case-keyword'
        }
        elseif (@('yield', 'await', 'typeof', 'instanceof', 'in', 'of', 'delete', 'void', 'new') -ccontains $Token) {
          $State.PendingControlHeader = ''
          $State.PendingDeclarationPosition = $false
          $State.RegexCanStart = $true
          $State.StatementStart = $false
          $State.LastTokenKind = 'operator-keyword'
        }
        else {
          $State.PendingControlHeader = ''
          $State.PendingDeclarationPosition = $false
          $State.PendingLabelCandidate = $statementStartBeforeToken
          $State.RegexCanStart = $false
          $State.StatementStart = $false
          $State.LastTokenKind = 'operand'
        }
      }
      'open-parenthesis' {
        if ($State.DeclarationContexts.Count -gt 0) {
          $declarationContext = $State.DeclarationContexts[$State.DeclarationContexts.Count - 1]
          if (
            $declarationContext.Kind -ceq 'function' -and
            $declarationContext.ParameterDepth -lt 0 -and
            $declarationContext.BaseParenthesisDepth -eq $State.ParenthesisContexts.Count -and
            $declarationContext.BaseBraceDepth -eq $State.BraceContexts.Count
          ) {
            $declarationContext.ParameterDepth = $State.ParenthesisContexts.Count + 1
          }
        }
        $parenthesisContext = if (@('for', 'for-await') -ccontains $pendingControlHeader) {
          'for-header'
        }
        elseif ($pendingControlHeader -cne '') {
          'control-header'
        }
        else {
          'expression'
        }
        [void]$State.ParenthesisContexts.Add($parenthesisContext)
        $State.PendingControlHeader = ''
        $State.RegexCanStart = $true
        $State.StatementStart = $false
        $State.LastTokenKind = 'open-parenthesis'
      }
      'close-parenthesis' {
        $State.PendingControlHeader = ''
        $parenthesisContext = ''
        if ($State.ParenthesisContexts.Count -gt 0) {
          $parenthesisContext = $State.ParenthesisContexts[$State.ParenthesisContexts.Count - 1]
          $State.ParenthesisContexts.RemoveAt($State.ParenthesisContexts.Count - 1)
        }
        if ($State.DeclarationContexts.Count -gt 0) {
          $declarationContext = $State.DeclarationContexts[$State.DeclarationContexts.Count - 1]
          if (
            $declarationContext.Kind -ceq 'function' -and
            $declarationContext.ParameterDepth -eq ($State.ParenthesisContexts.Count + 1) -and
            $declarationContext.BaseParenthesisDepth -eq $State.ParenthesisContexts.Count -and
            $declarationContext.BaseBraceDepth -eq $State.BraceContexts.Count
          ) {
            $declarationContext.ReadyForBody = $true
          }
        }
        $State.RegexCanStart = @('control-header', 'for-header') -ccontains $parenthesisContext
        $State.StatementStart = $State.RegexCanStart
        $State.LastTokenKind = $(if ($State.RegexCanStart) { 'control-header-close' } else { 'parenthesis-close' })
      }
      'open-brace' {
        $braceContext = & $getJavascriptOpenBraceContext $State
        $State.PendingControlHeader = ''
        [void]$State.BraceContexts.Add($braceContext)
        $State.RegexCanStart = $true
        $State.StatementStart = $braceContext -cne 'object'
        $State.LastTokenKind = "$braceContext-open"
      }
      'close-brace' {
        $State.PendingControlHeader = ''
        $braceContext = ''
        if ($State.BraceContexts.Count -gt 0) {
          $braceContext = $State.BraceContexts[$State.BraceContexts.Count - 1]
          $State.BraceContexts.RemoveAt($State.BraceContexts.Count - 1)
        }
        $blockClose = $braceContext -ceq 'block'
        $State.RegexCanStart = $blockClose
        $State.StatementStart = $blockClose
        $State.LastTokenKind = $(if ($blockClose) { 'block-close' } else { 'object-close' })
      }
      'spread' {
        $State.PendingControlHeader = ''
        $State.RegexCanStart = $true
        $State.StatementStart = $false
        $State.LastTokenKind = 'spread'
      }
      'member-access' {
        $State.PendingControlHeader = ''
        $State.RegexCanStart = $false
        $State.StatementStart = $false
        $State.LastTokenKind = 'member-access'
      }
      'update-run' {
        $State.PendingControlHeader = ''
        # JavaScript greedily consumes ++/-- pairs plus a possible trailing
        # binary operator. Odd runs therefore expect another operand.
        $State.RegexCanStart = ($Token.Length % 2) -eq 1
        $State.StatementStart = $false
        $State.LastTokenKind = $(if ($State.RegexCanStart) { 'operator' } else { 'operand' })
      }
      'postfix-non-null' {
        $State.PendingControlHeader = ''
        $State.RegexCanStart = $false
        $State.StatementStart = $false
        $State.LastTokenKind = 'operand'
      }
      'literal-start' {
        $State.PendingControlHeader = ''
        $State.RegexCanStart = $false
        $State.StatementStart = $false
        $State.LastTokenKind = 'literal-open'
      }
      'operand' {
        $State.PendingControlHeader = ''
        $State.RegexCanStart = $false
        $State.StatementStart = $false
        $State.LastTokenKind = 'operand'
      }
      'operator' {
        $State.PendingControlHeader = ''
        $State.RegexCanStart = $true
        $State.StatementStart = $false
        $State.LastTokenKind = 'operator'
      }
      'arrow' {
        $State.PendingControlHeader = ''
        $State.PendingArrowBody = $true
        $State.RegexCanStart = $true
        $State.StatementStart = $false
        $State.LastTokenKind = 'arrow'
      }
      'question' {
        $State.PendingControlHeader = ''
        $State.ConditionalDepth++
        $State.RegexCanStart = $true
        $State.StatementStart = $false
        $State.LastTokenKind = 'conditional-question'
      }
      'colon' {
        $caseLabelBoundary =
          $State.PendingCaseLabel -and
          $State.ConditionalDepth -eq 0 -and
          $State.CaseLabelBraceDepth -eq $State.BraceContexts.Count -and
          $State.CaseLabelParenthesisDepth -eq $State.ParenthesisContexts.Count
        if ($State.ConditionalDepth -gt 0) {
          $State.ConditionalDepth--
          $State.PendingLabelCandidate = $false
          $State.RegexCanStart = $true
          $State.StatementStart = $false
          $State.LastTokenKind = 'conditional-colon'
        }
        elseif ($caseLabelBoundary -or $State.PendingLabelCandidate) {
          [void](& $setJavascriptStatementStart $State)
        }
        else {
          $State.PendingControlHeader = ''
          $State.PendingLabelCandidate = $false
          $State.RegexCanStart = $true
          $State.StatementStart = $false
          $State.LastTokenKind = 'operator'
        }
      }
      'semicolon' {
        $insideForHeader =
          $State.ParenthesisContexts.Count -gt 0 -and
          $State.ParenthesisContexts[$State.ParenthesisContexts.Count - 1] -ceq 'for-header'
        if ($insideForHeader) {
          $State.PendingControlHeader = ''
          $State.RegexCanStart = $true
          $State.StatementStart = $false
          $State.LastTokenKind = 'for-header-separator'
        }
        else {
          for ($declarationIndex = $State.DeclarationContexts.Count - 1; $declarationIndex -ge 0; $declarationIndex--) {
            $declarationContext = $State.DeclarationContexts[$declarationIndex]
            if (
              $declarationContext.BaseParenthesisDepth -eq $State.ParenthesisContexts.Count -and
              $declarationContext.BaseBraceDepth -eq $State.BraceContexts.Count
            ) {
              $State.DeclarationContexts.RemoveAt($declarationIndex)
            }
          }
          [void](& $setJavascriptStatementStart $State)
        }
      }
      'close-delimiter' {
        $State.PendingControlHeader = ''
        $State.RegexCanStart = $false
        $State.StatementStart = $false
        $State.LastTokenKind = 'operand'
      }
      default {
        $State.PendingControlHeader = ''
        $State.RegexCanStart = $true
        $State.StatementStart = $false
        $State.LastTokenKind = $Kind
      }
    }
  }
  $finishJavascriptLine = {
    param([Parameter(Mandatory)][object]$State)

    $restrictedProduction = [string]$State.RestrictedProduction
    if ($restrictedProduction -ceq 'throw') { return $false }
    if ($restrictedProduction -cne '') { [void](& $setJavascriptStatementStart $State) }
    return $true
  }
  $scanJavascriptQuotedString = {
    param(
      [Parameter(Mandatory)][string]$Text,
      [Parameter(Mandatory)][int]$StartIndex,
      [Parameter(Mandatory)][string]$Quote,
      [Parameter(Mandatory)][Text.StringBuilder]$Structural
    )

    $scanIndex = $StartIndex
    while ($scanIndex -lt $Text.Length) {
      $quotedCharacter = $Text[$scanIndex]
      [void]$Structural.Append(' ')
      if ($quotedCharacter -eq '\') {
        if ($scanIndex + 1 -lt $Text.Length) {
          [void]$Structural.Append(' ')
          $scanIndex += 2
          continue
        }
        return [pscustomobject]@{ Index = $Text.Length; Closed = $false; Continued = $true }
      }
      $scanIndex++
      if ($quotedCharacter -eq $Quote) {
        return [pscustomobject]@{ Index = $scanIndex; Closed = $true; Continued = $false }
      }
    }
    return [pscustomobject]@{ Index = $scanIndex; Closed = $false; Continued = $false }
  }
  for ($lineIndex = 0; $lineIndex -lt $lines.Count; $lineIndex++) {
    $line = $lines[$lineIndex]
    $semanticMarkerText = ''
    if (
      $blockCommentEnd -ceq '' -and
      $multilineStringDelimiter -ceq '' -and
      $javascriptTemplateStack.Count -eq 0 -and
      $null -eq $javascriptQuotedString
    ) {
      $semanticMarkerMatch = if ($slashLineComment) {
        [regex]::Match($line, '^\s*//\s*arc:(?<payload>@ownership-\S*(?:[ \t]+\S(?:.*\S)?)?|(?:@[a-z][a-z-]*|route|scenario)[ \t]+\S(?:.*\S)?)\s*$')
      }
      else { $null }
      if (($null -eq $semanticMarkerMatch -or -not $semanticMarkerMatch.Success) -and ($hashLineComment -or $powerShellBlockComment)) {
        $semanticMarkerMatch = [regex]::Match($line, '^\s*#\s*arc:(?<payload>@ownership-\S*(?:[ \t]+\S(?:.*\S)?)?|(?:@[a-z][a-z-]*|route|scenario)[ \t]+\S(?:.*\S)?)\s*$')
      }
      if ($null -ne $semanticMarkerMatch -and $semanticMarkerMatch.Success) {
        $semanticMarkerText = $semanticMarkerMatch.Groups['payload'].Value.Trim()
      }
    }
    $structural = [Text.StringBuilder]::new()
    $hasCode = $false
    $lineAmbiguous = $false
    $index = 0
    if ($javascriptLanguage -and $null -ne $javascriptQuotedString -and $line.Length -eq 0) {
      $hasCode = $true
      $lineAmbiguous = $true
      $javascriptQuotedString = $null
    }
    while ($index -lt $line.Length) {
      if ($javascriptLanguage -and $null -ne $javascriptQuotedString) {
        $hasCode = $true
        $quotedScan = & $scanJavascriptQuotedString $line $index $javascriptQuotedString.Quote $structural
        $index = $quotedScan.Index
        if ($quotedScan.Closed) {
          $quotedCodeState = $javascriptQuotedString.CodeState
          $javascriptQuotedString = $null
          [void](& $setJavascriptTokenState $quotedCodeState 'operand')
          continue
        }
        if (-not $quotedScan.Continued) {
          $lineAmbiguous = $true
          $javascriptQuotedString = $null
        }
        continue
      }
      if ($multilineStringDelimiter -ne '') {
        $hasCode = $true
        $literalEnd = $line.IndexOf($multilineStringDelimiter, $index, [StringComparison]::Ordinal)
        if ($literalEnd -lt 0) { $index = $line.Length; continue }
        $index = $literalEnd + $multilineStringDelimiter.Length
        $multilineStringDelimiter = ''
        $multilineStringStart = -1
        continue
      }
      if ($blockCommentEnd -ne '') {
        $commentEnd = $line.IndexOf($blockCommentEnd, $index, [StringComparison]::Ordinal)
        if ($commentEnd -lt 0) { $index = $line.Length; continue }
        $index = $commentEnd + $blockCommentEnd.Length
        $blockCommentEnd = ''
        $blockCommentStart = -1
        continue
      }
      if ($javascriptTemplateStack.Count -gt 0 -and -not $javascriptTemplateStack[$javascriptTemplateStack.Count - 1].InExpression) {
        $hasCode = $true
        $templateContext = $javascriptTemplateStack[$javascriptTemplateStack.Count - 1]
        $templateCharacter = $line[$index]
        if ($templateCharacter -eq '\') {
          [void]$structural.Append(' ')
          $index++
          if ($index -lt $line.Length) {
            [void]$structural.Append(' ')
            $index++
          }
          continue
        }
        if ($templateCharacter -eq '`') {
          [void]$structural.Append('x')
          $javascriptTemplateStack.RemoveAt($javascriptTemplateStack.Count - 1)
          $parentJavascriptCodeState = & $getJavascriptCodeState
          [void](& $setJavascriptTokenState $parentJavascriptCodeState 'operand')
          $index++
          continue
        }
        if ($templateCharacter -eq '$' -and $index + 1 -lt $line.Length -and $line[$index + 1] -eq '{') {
          [void]$structural.Append('${')
          $templateContext.InExpression = $true
          $templateContext.InterpolationDepth = 1
          $templateContext.CodeState = & $newJavascriptCodeState
          $index += 2
          continue
        }
        [void]$structural.Append(' ')
        $index++
        continue
      }

      $remaining = $line.Substring($index)
      $multilineOpening = [regex]::Match($remaining, '^(?<delimiter>"{3,}|''{3,})')
      if ($multilineOpening.Success) {
        $hasCode = $true
        $multilineStringDelimiter = $multilineOpening.Groups['delimiter'].Value
        $multilineStringStart = $lineIndex
        $index += $multilineStringDelimiter.Length
        continue
      }
      if ($markupBlockComment -and $remaining.StartsWith('<!--', [StringComparison]::Ordinal)) { $blockCommentEnd = '-->'; $blockCommentStart = $lineIndex; $index += 4; continue }
      if ($cStyleBlockComment -and $remaining.StartsWith('/*', [StringComparison]::Ordinal)) { $blockCommentEnd = '*/'; $blockCommentStart = $lineIndex; $index += 2; continue }
      if ($powerShellBlockComment -and $remaining.StartsWith('<#', [StringComparison]::Ordinal)) { $blockCommentEnd = '#>'; $blockCommentStart = $lineIndex; $index += 2; continue }

      $character = $line[$index]
      if ($slashLineComment -and $remaining.StartsWith('//', [StringComparison]::Ordinal)) { break }
      if ($dashLineComment -and $remaining.StartsWith('--', [StringComparison]::Ordinal) -and ($remaining.Length -eq 2 -or [char]::IsWhiteSpace($remaining[2]))) { break }
      if ($semicolonLineComment -and -not $hasCode -and $character -eq ';' -and ($remaining.Length -eq 1 -or [char]::IsWhiteSpace($remaining[1]))) { break }
      if ($character -eq '#') {
        $preprocessor = $cPreprocessor -and [regex]::IsMatch($remaining, '^#\s*(?:define|elif|else|endif|error|if|ifdef|ifndef|include|line|pragma|undef|warning)\b')
        if (-not $preprocessor -and -not $hashDirectiveLanguage) {
          if ($hashLineComment) { break }
        }
      }
      if ($javascriptLanguage -and $character -eq '/') {
        $javascriptCodeState = & $getJavascriptCodeState
        if ($javascriptCodeState.RegexCanStart) {
          $regexIndex = $index + 1
          $insideCharacterClass = $false
          $regexClosed = $false
          while ($regexIndex -lt $line.Length) {
            $regexCharacter = $line[$regexIndex]
            if ($regexCharacter -eq '\' -and $regexIndex + 1 -lt $line.Length) { $regexIndex += 2; continue }
            if ($regexCharacter -eq '[') { $insideCharacterClass = $true; $regexIndex++; continue }
            if ($regexCharacter -eq ']' -and $insideCharacterClass) { $insideCharacterClass = $false; $regexIndex++; continue }
            if ($regexCharacter -eq '/' -and -not $insideCharacterClass) { $regexClosed = $true; $regexIndex++; break }
            $regexIndex++
          }
          if ($regexClosed) {
            while ($regexIndex -lt $line.Length -and $line[$regexIndex] -cmatch '[A-Za-z]') { $regexIndex++ }
          }
          else {
            $lineAmbiguous = $true
            $regexIndex = $line.Length
          }
          $hasCode = $true
          $regexWidth = $regexIndex - $index
          [void]$structural.Append('x')
          if ($regexWidth -gt 1) { [void]$structural.Append([string]::new([char]' ', $regexWidth - 1)) }
          if ($regexClosed) { [void](& $setJavascriptTokenState $javascriptCodeState 'operand') }
          $index = $regexIndex
          continue
        }
        [void]$structural.Append('/')
        $hasCode = $true
        [void](& $setJavascriptTokenState $javascriptCodeState 'operator' '/')
        $index++
        continue
      }
      if ($javascriptLanguage -and $character -eq '`') {
        $hasCode = $true
        [void]$structural.Append(' ')
        $javascriptCodeState = & $getJavascriptCodeState
        [void](& $setJavascriptTokenState $javascriptCodeState 'literal-start')
        $javascriptTemplateStack.Add([pscustomobject]@{
          StartLine = $lineIndex
          InExpression = $false
          InterpolationDepth = 0
          CodeState = & $newJavascriptCodeState
        })
        $index++
        continue
      }
      if ($character -in @("'", '"', '`')) {
        $hasCode = $true
        $quote = $character
        [void]$structural.Append($(if ($javascriptLanguage) { 'x' } else { ' ' }))
        if ($javascriptLanguage) {
          $javascriptCodeState = & $getJavascriptCodeState
          [void](& $setJavascriptTokenState $javascriptCodeState 'literal-start')
          $quotedScan = & $scanJavascriptQuotedString $line ($index + 1) ([string]$quote) $structural
          $index = $quotedScan.Index
          if ($quotedScan.Closed) {
            [void](& $setJavascriptTokenState $javascriptCodeState 'operand')
          }
          elseif ($quotedScan.Continued) {
            $javascriptQuotedString = [pscustomobject]@{
              Quote = [string]$quote
              StartLine = $lineIndex
              CodeState = $javascriptCodeState
            }
          }
          else {
            $lineAmbiguous = $true
          }
          continue
        }
        $quotedStringClosed = $false
        $index++
        while ($index -lt $line.Length) {
          $quotedCharacter = $line[$index]
          [void]$structural.Append(' ')
          $quotedCharacterEscapesNext =
            $quotedCharacter -eq '\' -or
            (-not $javascriptLanguage -and $quotedCharacter -eq [char]96)
          if ($quotedCharacterEscapesNext -and $index + 1 -lt $line.Length) {
            [void]$structural.Append(' ')
            $index += 2
            continue
          }
          if ($quotedCharacter -eq $quote) {
            if (-not $javascriptLanguage -and $index + 1 -lt $line.Length -and $line[$index + 1] -eq $quote) {
              [void]$structural.Append(' ')
              $index += 2
              continue
            }
            $quotedStringClosed = $true
            $index++
            break
          }
          $index++
        }
        continue
      }

      if ($javascriptTemplateStack.Count -gt 0 -and $javascriptTemplateStack[$javascriptTemplateStack.Count - 1].InExpression) {
        $templateContext = $javascriptTemplateStack[$javascriptTemplateStack.Count - 1]
        if ($character -eq '{') {
          $templateContext.InterpolationDepth++
        }
        elseif ($character -eq '}') {
          $templateContext.InterpolationDepth--
          if ($templateContext.InterpolationDepth -eq 0) {
            $templateContext.InExpression = $false
            [void]$structural.Append('}')
            $hasCode = $true
            $index++
            continue
          }
        }
      }

      if ($javascriptLanguage) {
        $javascriptCodeState = & $getJavascriptCodeState
        $identifierToken = [regex]::Match($remaining, '^[A-Za-z_$][A-Za-z0-9_$]*')
        if ($identifierToken.Success) {
          $token = $identifierToken.Value
          [void]$structural.Append($token)
          $hasCode = $true
          [void](& $setJavascriptTokenState $javascriptCodeState 'identifier' $token)
          $index += $token.Length
          continue
        }

        $numberToken = [regex]::Match($remaining, '^(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?')
        if ($numberToken.Success) {
          $token = $numberToken.Value
          [void]$structural.Append($token)
          $hasCode = $true
          [void](& $setJavascriptTokenState $javascriptCodeState 'operand' $token)
          $index += $token.Length
          continue
        }

        if ($remaining.StartsWith('...', [StringComparison]::Ordinal)) {
          [void]$structural.Append('...')
          $hasCode = $true
          [void](& $setJavascriptTokenState $javascriptCodeState 'spread' '...')
          $index += 3
          continue
        }
        if ($remaining.StartsWith('?.', [StringComparison]::Ordinal)) {
          [void]$structural.Append('?.')
          $hasCode = $true
          [void](& $setJavascriptTokenState $javascriptCodeState 'member-access' '?.')
          $index += 2
          continue
        }
        if ($remaining.StartsWith('=>', [StringComparison]::Ordinal)) {
          [void]$structural.Append('=>')
          $hasCode = $true
          [void](& $setJavascriptTokenState $javascriptCodeState 'arrow' '=>')
          $index += 2
          continue
        }
        if (
          $remaining.StartsWith('!==', [StringComparison]::Ordinal) -or
          $remaining.StartsWith('!=', [StringComparison]::Ordinal)
        ) {
          $operatorWidth = $(if ($remaining.StartsWith('!==', [StringComparison]::Ordinal)) { 3 } else { 2 })
          $operatorToken = $remaining.Substring(0, $operatorWidth)
          [void]$structural.Append($operatorToken)
          $hasCode = $true
          [void](& $setJavascriptTokenState $javascriptCodeState 'operator' $operatorToken)
          $index += $operatorWidth
          continue
        }
        if ($character -eq '!') {
          [void]$structural.Append('!')
          $hasCode = $true
          $bangTokenKind = $(if ($typescriptLanguage -and -not $javascriptCodeState.RegexCanStart) { 'postfix-non-null' } else { 'operator' })
          [void](& $setJavascriptTokenState $javascriptCodeState $bangTokenKind '!')
          $index++
          continue
        }
        if ($character -eq '.') {
          [void]$structural.Append('.')
          $hasCode = $true
          [void](& $setJavascriptTokenState $javascriptCodeState 'member-access' '.')
          $index++
          continue
        }
        if ($character -in @('+', '-')) {
          $operatorIndex = $index + 1
          while ($operatorIndex -lt $line.Length -and $line[$operatorIndex] -eq $character) { $operatorIndex++ }
          $operatorRun = $line.Substring($index, $operatorIndex - $index)
          [void]$structural.Append($operatorRun)
          $hasCode = $true
          [void](& $setJavascriptTokenState $javascriptCodeState 'update-run' $operatorRun)
          $index = $operatorIndex
          continue
        }

        $javascriptTokenKind = switch ($character) {
          '(' { 'open-parenthesis'; break }
          ')' { 'close-parenthesis'; break }
          ']' { 'close-delimiter'; break }
          '}' { 'close-brace'; break }
          '[' { 'operator'; break }
          '{' { 'open-brace'; break }
          ';' { 'semicolon'; break }
          ',' { 'operator'; break }
          ':' { 'colon'; break }
          '?' { 'question'; break }
          '=' { 'operator'; break }
          '&' { 'operator'; break }
          '|' { 'operator'; break }
          '*' { 'operator'; break }
          '%' { 'operator'; break }
          '^' { 'operator'; break }
          '~' { 'operator'; break }
          '<' { 'operator'; break }
          '>' { 'operator'; break }
          default { '' }
        }
        if ($javascriptTokenKind -cne '') {
          [void]$structural.Append($character)
          $hasCode = $true
          [void](& $setJavascriptTokenState $javascriptCodeState $javascriptTokenKind ([string]$character))
          $index++
          continue
        }
      }

      [void]$structural.Append($character)
      if (-not [char]::IsWhiteSpace($character)) { $hasCode = $true }
      $index++
    }
    if ($javascriptLanguage) {
      $javascriptCodeState = & $getJavascriptCodeState
      if (-not (& $finishJavascriptLine $javascriptCodeState)) { $lineAmbiguous = $true }
    }
    $result.Add([pscustomobject]@{
      Raw = $line
      HasCode = $hasCode
      HasSemanticMetadata = $semanticMarkerText -cne ''
      SemanticText = if ($semanticMarkerText -cne '') { $semanticMarkerText } else { $line }
      StructuralText = $structural.ToString()
      Ambiguous = $lineAmbiguous
    })
  }
  $ambiguousStarts = @($blockCommentStart, $multilineStringStart)
  if ($javascriptTemplateStack.Count -gt 0) {
    $ambiguousStarts += @($javascriptTemplateStack | ForEach-Object { $_.StartLine } | Sort-Object | Select-Object -First 1)
  }
  if ($null -ne $javascriptQuotedString) { $ambiguousStarts += $javascriptQuotedString.StartLine }
  foreach ($ambiguousStart in $ambiguousStarts | Where-Object { $_ -ge 0 }) {
    for ($lineIndex = $ambiguousStart; $lineIndex -lt $result.Count; $lineIndex++) { $result[$lineIndex].Ambiguous = $true }
  }
  return $result.ToArray()
}

function Test-ArcCommentOnlySourceLine {
  [CmdletBinding()]
  param([AllowEmptyString()][string]$Line)

  $lexicalLine = @(Get-ArcSourceLexicalLines -SourceText $Line) | Select-Object -First 1
  return $null -eq $lexicalLine -or (-not $lexicalLine.HasCode -and -not $lexicalLine.HasSemanticMetadata)
}

function Get-ArcResponsibilitySourceBlocks {
  [CmdletBinding()]
  param(
    [AllowEmptyString()][string]$SourceText,
    [object[]]$LexicalLines = @(),
    [AllowEmptyString()][string]$SourcePath = '',
    [AllowNull()][Collections.Generic.List[string]]$Errors = $null
  )

  $lines = @($SourceText -split '\r\n|\n|\r')
  if ($LexicalLines.Count -ne $lines.Count) { $LexicalLines = @(Get-ArcSourceLexicalLines -SourceText $SourceText -SourcePath $SourcePath) }
  $semanticLines = @($LexicalLines | ForEach-Object { $_.SemanticText })
  $blocks = [Collections.Generic.List[object]]::new()
  $seenResponsibilityIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  $pendingOwner = $null
  $activeOwner = $null
  $malformed = $false
  $metadataPattern = '^\s*@(owner-symbol|public-symbol|owned-capability|effect|architecture-authority|co-location-policy|verification-owner)\s+\S.*$'

  for ($index = 0; $index -lt $lines.Count; $index++) {
    if (-not ($LexicalLines[$index].HasCode -or $LexicalLines[$index].HasSemanticMetadata)) { continue }
    $semanticLine = $semanticLines[$index]
    $ownerMatch = [regex]::Match($semanticLine, '^\s*@responsibility\s+(?<id>RESP-[A-Z0-9]+(?:-[A-Z0-9]+)*)\s*$')
    $beginMatch = [regex]::Match($semanticLine, '^\s*@ownership-begin\s+(?<id>RESP-[A-Z0-9]+(?:-[A-Z0-9]+)*)\s*$')
    $endMatch = [regex]::Match($semanticLine, '^\s*@ownership-end\s+(?<id>RESP-[A-Z0-9]+(?:-[A-Z0-9]+)*)\s*$')
    $reservedOwnershipMarker = $semanticLine -cmatch '^\s*@ownership-\S*(?:\s|$)'

    if ($null -eq $pendingOwner -and $null -eq $activeOwner) {
      if ($ownerMatch.Success) {
        $responsibilityId = $ownerMatch.Groups['id'].Value
        if ($seenResponsibilityIds.Contains($responsibilityId)) { $malformed = $true; continue }
        $pendingOwner = [pscustomobject]@{ Id = $responsibilityId; Start = $index }
        continue
      }
      if ($beginMatch.Success -or $endMatch.Success -or $reservedOwnershipMarker) { $malformed = $true }
      continue
    }

    if ($null -ne $pendingOwner) {
      if ($beginMatch.Success) {
        if ($beginMatch.Groups['id'].Value -cne $pendingOwner.Id) { $malformed = $true; continue }
        $activeOwner = [pscustomobject]@{ Id = $pendingOwner.Id; Start = $pendingOwner.Start; Begin = $index }
        $pendingOwner = $null
        continue
      }
      if ($ownerMatch.Success -or $endMatch.Success -or $reservedOwnershipMarker -or $semanticLine -cnotmatch $metadataPattern) {
        $malformed = $true
      }
      continue
    }

    if ($endMatch.Success) {
      if ($endMatch.Groups['id'].Value -cne $activeOwner.Id) { $malformed = $true; continue }
      $blocks.Add([pscustomobject]@{
        Id = $activeOwner.Id
        Start = $activeOwner.Start
        Begin = $activeOwner.Begin
        End = $index
        Text = @($semanticLines[$activeOwner.Start..$index]) -join "`n"
        Lines = @($semanticLines[$activeOwner.Start..$index])
        RawText = @($lines[$activeOwner.Start..$index]) -join "`n"
      })
      [void]$seenResponsibilityIds.Add($activeOwner.Id)
      $activeOwner = $null
      continue
    }
    if ($ownerMatch.Success -or $beginMatch.Success -or $reservedOwnershipMarker -or $semanticLine -cmatch $metadataPattern) {
      $malformed = $true
    }
  }

  if ($null -ne $pendingOwner -or $null -ne $activeOwner) { $malformed = $true }
  if ($malformed) {
    if ($null -ne $Errors) { $Errors.Add('responsibility-evidence-missing') }
    return @()
  }
  return $blocks.ToArray()
}

function Get-ArcPinnedSourceInventory {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$SourceRoot,
    [Parameter(Mandatory)][string]$TaskBaseSha,
    [Parameter(Mandatory)][string]$FinalTreeSha,
    [string[]]$SelectedPaths = @(),
    [Parameter(Mandatory)][AllowEmptyCollection()][Collections.Generic.List[string]]$Errors
  )

  if (-not (Test-Path -LiteralPath $SourceRoot -PathType Container) -or $TaskBaseSha -cnotmatch '^[0-9a-f]{40}$' -or $FinalTreeSha -cnotmatch '^[0-9a-f]{40}$') {
    $Errors.Add('responsibility-evidence-missing')
    return @()
  }
  $canonicalSelectedPaths = [Collections.Generic.List[string]]::new()
  foreach ($selectedPath in $SelectedPaths) {
    $canonicalSelectedPath = ConvertTo-ArcCanonicalRepositoryPath -Path ([string]$selectedPath).Trim()
    if ($canonicalSelectedPath -ceq '') { $Errors.Add('responsibility-evidence-missing') }
    else { $canonicalSelectedPaths.Add($canonicalSelectedPath) }
  }
  if ($Errors.Count -ne 0) { return @() }
  $SelectedPaths = @($canonicalSelectedPaths)
  try {
    $resolvedSourceRoot = ConvertTo-ArcComparableRootPath -Path $SourceRoot
    $resolvedGitRoot = ConvertTo-ArcComparableRootPath -Path (Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('rev-parse', '--show-toplevel'))
    $currentHead = Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('rev-parse', 'HEAD')
    $checkoutStatus = Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('status', '--porcelain=v1', '--untracked-files=all')
    if (
      -not [string]::Equals($resolvedSourceRoot, $resolvedGitRoot, [StringComparison]::OrdinalIgnoreCase) -or
      $currentHead -cne $FinalTreeSha -or
      -not [string]::IsNullOrWhiteSpace($checkoutStatus) -or
      (Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('rev-parse', "$TaskBaseSha^{commit}")) -cne $TaskBaseSha -or
      (Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('rev-parse', "$FinalTreeSha^{commit}")) -cne $FinalTreeSha
    ) {
      $Errors.Add('responsibility-evidence-missing')
      return @()
    }
    [void](Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('merge-base', '--is-ancestor', $TaskBaseSha, $FinalTreeSha))
    $nameStatusRaw = Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('diff', '--name-status', '-z', '--find-renames', '--find-copies-harder', '--diff-filter=ACMRD', $TaskBaseSha, $FinalTreeSha, '--')
    $finalTreeRaw = Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('ls-tree', '-r', '-z', '--name-only', $FinalTreeSha)
    if (-not $nameStatusRaw.EndsWith([string][char]0, [StringComparison]::Ordinal) -or -not $finalTreeRaw.EndsWith([string][char]0, [StringComparison]::Ordinal)) { throw 'Pinned Git NUL envelope is malformed' }
    $nameStatusTokens = @($nameStatusRaw.Split([char]0))
    $nameStatusTokens = @($nameStatusTokens[0..($nameStatusTokens.Count - 2)])
    $finalTreeTokens = @($finalTreeRaw.Split([char]0))
    $finalTreeTokens = @($finalTreeTokens[0..($finalTreeTokens.Count - 2)])
  }
  catch {
    $Errors.Add('responsibility-evidence-missing')
    return @()
  }
  $nameStatusEntries = [Collections.Generic.List[object]]::new()
  $tokenIndex = 0
  while ($tokenIndex -lt $nameStatusTokens.Count) {
    $status = $nameStatusTokens[$tokenIndex]
    $tokenIndex++
    if ($status -cnotmatch '^(?:[AMDC]|R[0-9]{1,3}|C[0-9]{1,3})$') {
      $Errors.Add('responsibility-evidence-missing')
      return @()
    }
    $kind = $status.Substring(0, 1)
    $pathCount = if ($kind -cin @('R', 'C')) { 2 } else { 1 }
    if (($tokenIndex + $pathCount) -gt $nameStatusTokens.Count) {
      $Errors.Add('responsibility-evidence-missing')
      return @()
    }
    $paths = @($nameStatusTokens[$tokenIndex..($tokenIndex + $pathCount - 1)])
    $tokenIndex += $pathCount
    $nameStatusEntries.Add([pscustomobject]@{ Status = $status; Kind = $kind; Paths = $paths })
  }
  $finalTreePaths = @($finalTreeTokens | ForEach-Object { ConvertTo-ArcCanonicalRepositoryPath -Path $_ })
  if (@($finalTreePaths | Where-Object { $_ -ceq '' }).Count -gt 0) {
    $Errors.Add('responsibility-evidence-missing')
    return @()
  }
  $changedPathRecords = [Collections.Generic.List[object]]::new()
  foreach ($entry in $nameStatusEntries) {
    $status = $entry.Status
    $kind = $entry.Kind
    $fields = @($status) + @($entry.Paths)
    $rawBasePath = if ($kind -cin @('R', 'C')) { $fields[1] } elseif ($kind -ceq 'A') { '' } else { $fields[1] }
    $rawFinalPath = if ($kind -cin @('R', 'C')) { $fields[2] } elseif ($kind -ceq 'D') { '' } else { $fields[1] }
    $basePath = if ($rawBasePath -ceq '') { '' } else { ConvertTo-ArcCanonicalRepositoryPath -Path $rawBasePath }
    $finalPath = if ($rawFinalPath -ceq '') { '' } else { ConvertTo-ArcCanonicalRepositoryPath -Path $rawFinalPath }
    if (($rawBasePath -ne '' -and $basePath -ceq '') -or ($rawFinalPath -ne '' -and $finalPath -ceq '')) {
      $Errors.Add('responsibility-evidence-missing')
      continue
    }
    $path = if ($kind -ceq 'D') { $basePath } else { $finalPath }
    $isBaseProduction = -not [string]::IsNullOrWhiteSpace($basePath) -and (Test-ArcCanonicalProductionPath -Path $basePath)
    $isFinalProduction = -not [string]::IsNullOrWhiteSpace($finalPath) -and (Test-ArcCanonicalProductionPath -Path $finalPath)
    $isProduction = if ($kind -ceq 'R') {
      $isBaseProduction -or $isFinalProduction
    }
    elseif ($kind -ceq 'D') { $isBaseProduction }
    else { $isFinalProduction }
    $changedPathRecords.Add([pscustomobject]@{
      Status = $kind
      RawStatus = $status
      BasePath = $basePath
      FinalPath = $finalPath
      Path = $path
      RenameMapping = if ($kind -ceq 'R') { "$basePath->$finalPath" } else { '' }
      FileKind = if ($kind -ceq 'A' -or $kind -ceq 'C') { 'new' } elseif ($kind -ceq 'D') { 'deleted' } else { 'existing' }
      IsBaseProduction = $isBaseProduction
      IsFinalProduction = $isFinalProduction
      IsProduction = $isProduction
    })
  }
  $changedFinalPaths = @($changedPathRecords | Where-Object { $_.Status -cne 'D' -and $_.IsProduction } | ForEach-Object { $_.FinalPath })
  $deletedPaths = @($changedPathRecords | Where-Object { $_.Status -ceq 'D' -and ($_.IsProduction -or $SelectedPaths -ccontains $_.BasePath) } | ForEach-Object { $_.BasePath })
  $allChangedPaths = @($changedPathRecords | ForEach-Object { $_.Path })
  $allRequestedPaths = @($allChangedPaths + $SelectedPaths)
  if ($allChangedPaths.Count -eq 0 -or @($allRequestedPaths | Where-Object { (ConvertTo-ArcCanonicalRepositoryPath -Path $_) -ceq '' }).Count -gt 0) {
    $Errors.Add('responsibility-evidence-missing')
    return @()
  }
  $selectedFinalPaths = @($SelectedPaths | Where-Object { $finalTreePaths -ccontains $_ })
  $finalPaths = @($changedFinalPaths + $selectedFinalPaths | Select-Object -Unique)

  $deletedInventory = [Collections.Generic.List[object]]::new()
  foreach ($path in $deletedPaths) {
    try {
      $deletedSourceText = Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('show', "${TaskBaseSha}:$path")
      $deletedDiffText = Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('diff', '--unified=0', $TaskBaseSha, $FinalTreeSha, '--', $path)
    }
    catch {
      $Errors.Add('responsibility-evidence-missing')
      continue
    }
    foreach ($owner in @(Test-ArcDeletedSourceEvidence -Path $path -SourceText $deletedSourceText -DiffText $deletedDiffText -Errors $Errors)) {
      $deletedInventory.Add($owner)
    }
  }

  $inventory = [Collections.Generic.List[object]]::new()
  foreach ($path in $finalPaths) {
    $pathRecord = @($changedPathRecords | Where-Object { $_.FinalPath -ceq $path }) | Select-Object -First 1
    $baseSourceText = ''
    try {
      $sourceText = Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('show', "${FinalTreeSha}:$path")
      $diffText = Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('diff', '--unified=0', $TaskBaseSha, $FinalTreeSha, '--', $path)
      if ($null -ne $pathRecord -and $pathRecord.BasePath -ne '') {
        $baseSourceText = Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('show', "${TaskBaseSha}:$($pathRecord.BasePath)")
      }
    }
    catch {
      $Errors.Add('responsibility-evidence-missing')
      continue
    }
    $sourceLines = @($sourceText -split '\r\n|\n|\r')
    $sourceLexicalLines = @(Get-ArcSourceLexicalLines -SourceText $sourceText -SourcePath $path)
    $sourceSemanticLines = @($sourceLexicalLines | ForEach-Object { $_.SemanticText })
    if (@($sourceLexicalLines | Where-Object { $_.Ambiguous }).Count -gt 0) { $Errors.Add('responsibility-evidence-missing') }
    $responsibilityBlocks = @(Get-ArcResponsibilitySourceBlocks -SourceText $sourceText -LexicalLines $sourceLexicalLines -SourcePath $path -Errors $Errors)
    $coveredLineIndexes = [Collections.Generic.HashSet[int]]::new()
    foreach ($block in $responsibilityBlocks) {
      for ($coveredIndex = $block.Start; $coveredIndex -le $block.End; $coveredIndex++) { [void]$coveredLineIndexes.Add($coveredIndex) }
    }
    for ($lineIndex = 0; $lineIndex -lt $sourceLines.Count; $lineIndex++) {
      if (-not $coveredLineIndexes.Contains($lineIndex) -and ($sourceLexicalLines[$lineIndex].HasCode -or $sourceLexicalLines[$lineIndex].HasSemanticMetadata)) {
        $Errors.Add('responsibility-evidence-missing')
      }
    }

    foreach ($responsibilityBlock in $responsibilityBlocks) {
      $current = [pscustomobject]@{
        Id = $responsibilityBlock.Id
        Path = $path
        BasePath = if ($null -ne $pathRecord) { [string]$pathRecord.BasePath } else { $path }
        FinalPath = $path
        RenameMapping = if ($null -ne $pathRecord) { [string]$pathRecord.RenameMapping } else { '' }
        IsChanged = ($null -ne $pathRecord)
        OwnerSymbols = [Collections.Generic.List[string]]::new()
        Symbols = [Collections.Generic.List[string]]::new()
        Capabilities = [Collections.Generic.List[string]]::new()
        Effects = [Collections.Generic.List[string]]::new()
        ArchitectureAuthorities = [Collections.Generic.List[string]]::new()
        CoLocationPolicies = [Collections.Generic.List[string]]::new()
        VerificationOwners = [Collections.Generic.List[string]]::new()
        RouteSymbols = [Collections.Generic.List[string]]::new()
        Providers = [Collections.Generic.List[string]]::new()
      }
      foreach ($line in $responsibilityBlock.Lines) {
        $ownerSymbolMatch = [regex]::Match($line, '^\s*@owner-symbol\s+(?<value>[A-Za-z][A-Za-z0-9_.:-]*)\s*$')
        if ($ownerSymbolMatch.Success) { $current.OwnerSymbols.Add($ownerSymbolMatch.Groups['value'].Value); continue }
        $symbolMatch = [regex]::Match($line, '^\s*@public-symbol\s+(?<value>[A-Za-z][A-Za-z0-9_.:-]*)\s*$')
        if ($symbolMatch.Success) { $current.Symbols.Add($symbolMatch.Groups['value'].Value); continue }
        $capabilityMatch = [regex]::Match($line, '^\s*@owned-capability\s+(?<value>CAP-[A-Z0-9]+(?:-[A-Z0-9]+)*)\s*$')
        if ($capabilityMatch.Success) { $current.Capabilities.Add($capabilityMatch.Groups['value'].Value); continue }
        $effectMatch = [regex]::Match($line, '^\s*@effect\s+(?<value>[^\r\n]+?)\s*$')
        if ($effectMatch.Success) { $current.Effects.Add($effectMatch.Groups['value'].Value.Trim()); continue }
        $authorityMatch = [regex]::Match($line, '^\s*@architecture-authority\s+(?<value>[a-z][a-z-]*)\s*$')
        if ($authorityMatch.Success) { $current.ArchitectureAuthorities.Add($authorityMatch.Groups['value'].Value); continue }
        $coLocationMatch = [regex]::Match($line, '^\s*@co-location-policy\s+(?<value>[a-z][a-z-]*)\s*$')
        if ($coLocationMatch.Success) { $current.CoLocationPolicies.Add($coLocationMatch.Groups['value'].Value); continue }
        $verificationMatch = [regex]::Match($line, '^\s*@verification-owner\s+(?<id>VERIFY-OWNER-[A-Z0-9]+(?:-[A-Z0-9]+)*)\s*$')
        if ($verificationMatch.Success) { $current.VerificationOwners.Add($verificationMatch.Groups['id'].Value); continue }
        $routeMatch = [regex]::Match($line, '^\s*route\s+(?<symbol>[A-Za-z][A-Za-z0-9_.:-]*)\s*->\s*(?<provider>[A-Za-z][A-Za-z0-9_.:-]*)\s*$')
        if ($routeMatch.Success) {
          $current.RouteSymbols.Add($routeMatch.Groups['symbol'].Value)
          $current.Providers.Add($routeMatch.Groups['provider'].Value)
          if (-not $current.Effects.Contains('route registration')) { $current.Effects.Add('route registration') }
        }
      }
      $inventory.Add($current)
    }
    $allRouteCount = @(for ($lineIndex = 0; $lineIndex -lt $sourceLines.Count; $lineIndex++) {
      if (($sourceLexicalLines[$lineIndex].HasCode -or $sourceLexicalLines[$lineIndex].HasSemanticMetadata) -and $sourceSemanticLines[$lineIndex] -cmatch '^\s*route\s+[A-Za-z][A-Za-z0-9_.:-]*\s*->\s*[A-Za-z][A-Za-z0-9_.:-]*\s*$') { $sourceSemanticLines[$lineIndex] }
    }).Count
    $ownedRouteCount = @($inventory | Where-Object { $_.Path -ceq $path } | ForEach-Object { $_.RouteSymbols.Count } | Measure-Object -Sum).Sum
    if ($null -eq $ownedRouteCount) { $ownedRouteCount = 0 }
    if ($allRouteCount -ne $ownedRouteCount) { $Errors.Add('responsibility-evidence-missing') }
    foreach ($owner in @($inventory | Where-Object { $_.Path -ceq $path })) {
      if ($null -ne $pathRecord -and $pathRecord.Status -cin @('M', 'R') -and $baseSourceText -ne '') {
        $baseOwnerBlocks = @(Get-ArcResponsibilitySourceBlocks -SourceText $baseSourceText -SourcePath $pathRecord.BasePath -Errors $Errors | Where-Object { $_.Id -ceq $owner.Id })
        $finalOwnerBlocks = @($responsibilityBlocks | Where-Object { $_.Id -ceq $owner.Id })
        $owner.IsChanged = -not (
          $baseOwnerBlocks.Count -eq 1 -and
          $finalOwnerBlocks.Count -eq 1 -and
          $baseOwnerBlocks[0].Text.Trim() -ceq $finalOwnerBlocks[0].Text.Trim()
        )
      }
      $requiresRouteEvidence = $owner.Effects -ccontains 'route registration'
      if ($owner.OwnerSymbols.Count -eq 0 -or $owner.Symbols.Count -eq 0 -or $owner.Capabilities.Count -eq 0 -or $owner.ArchitectureAuthorities.Count -eq 0 -or $owner.CoLocationPolicies.Count -eq 0 -or $owner.VerificationOwners.Count -eq 0 -or ($requiresRouteEvidence -and ($owner.RouteSymbols.Count -eq 0 -or $owner.Providers.Count -eq 0 -or @($owner.Symbols | Where-Object { $owner.RouteSymbols -cnotcontains $_ }).Count -gt 0))) {
        $Errors.Add('responsibility-evidence-missing')
      }
    }
  }

  # A responsibility block removed from an M/R production file is deletion,
  # even though the file itself survives. Compare immutable pinned contents and
  # feed only the removed owners through the same deletion reconciliation used
  # for a whole-file D change.
  foreach ($record in @($changedPathRecords | Where-Object { $_.Status -cin @('M', 'R') -and ($_.IsProduction -or $SelectedPaths -ccontains $_.FinalPath) -and $_.BasePath -ne '' -and $_.FinalPath -ne '' })) {
    try {
      $baseText = Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('show', "${TaskBaseSha}:$($record.BasePath)")
      $finalText = Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('show', "${FinalTreeSha}:$($record.FinalPath)")
      $baseOwnerIds = @(Get-ArcResponsibilitySourceBlocks -SourceText $baseText -SourcePath $record.BasePath -Errors $Errors | ForEach-Object { $_.Id })
      $finalOwnerIds = @(Get-ArcResponsibilitySourceBlocks -SourceText $finalText -SourcePath $record.FinalPath -Errors $Errors | ForEach-Object { $_.Id })
      $removedOwnerIds = @($baseOwnerIds | Where-Object {
        $ownerId = $_
        $finalOwnerIds -cnotcontains $ownerId
      })
      if ($removedOwnerIds.Count -gt 0) {
        $removalDiff = Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('diff', '--unified=0', $TaskBaseSha, $FinalTreeSha, '--', $record.BasePath, $record.FinalPath)
        foreach ($owner in @(Test-ArcDeletedSourceEvidence -Path $record.BasePath -SourceText $baseText -DiffText $removalDiff -OwnerIds $removedOwnerIds -Errors $Errors)) {
          $owner.BasePath = $record.BasePath
          $owner.FinalPath = $record.FinalPath
          $owner.RenameMapping = $record.RenameMapping
          $deletedInventory.Add($owner)
        }
      }
    }
    catch {
      $Errors.Add('responsibility-evidence-missing')
    }
  }

  # Marker presence never defines the inventory boundary. Canonically
  # production-classified changed paths must expose at least one active or
  # deleted responsibility after the pinned base/final comparison.
  foreach ($record in @($changedPathRecords | Where-Object { $_.IsProduction })) {
    $hasOwner = if ($record.Status -ceq 'D') {
      @($deletedInventory | Where-Object { $_.Path -ceq $record.Path }).Count -gt 0
    }
    else {
      @($inventory | Where-Object { $_.Path -ceq $record.FinalPath }).Count -gt 0 -or
        @($deletedInventory | Where-Object { $_.Path -ceq $record.BasePath }).Count -gt 0
    }
    if (-not $hasOwner) { $Errors.Add('responsibility-evidence-missing') }
  }
  return [pscustomobject]@{
    ActiveOwners = $inventory.ToArray()
    DeletedOwners = $deletedInventory.ToArray()
    ChangedPaths = $changedPathRecords.ToArray()
  }
}

function Test-ArcPinnedVerificationOwnershipEvidence {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][hashtable]$VerificationRow,
    [Parameter(Mandatory)][string]$SourceRoot,
    [Parameter(Mandatory)][string]$FinalTreeSha,
    [Parameter(Mandatory)][hashtable]$ProductionOwnersById,
    [Parameter(Mandatory)][AllowEmptyCollection()][Collections.Generic.List[string]]$Errors
  )

  $path = ConvertTo-ArcCanonicalRepositoryPath -Path $VerificationRow['Evidence Path']
  $scenario = $VerificationRow['Evidence Symbol or Scenario']
  if (
    $path -ceq '' -or
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
  $evidenceLines = @($evidenceText -split '\r\n|\n|\r')
  $evidenceLexicalLines = @(Get-ArcSourceLexicalLines -SourceText $evidenceText -SourcePath $path)
  if (@($evidenceLexicalLines | Where-Object { $_.Ambiguous }).Count -gt 0) {
    $Errors.Add('verification-production-binding-missing')
    return $false
  }
  $evidenceText = @(for ($lineIndex = 0; $lineIndex -lt $evidenceLines.Count; $lineIndex++) {
    if ($evidenceLexicalLines[$lineIndex].HasCode -or $evidenceLexicalLines[$lineIndex].HasSemanticMetadata) { $evidenceLexicalLines[$lineIndex].SemanticText }
  }) -join "`n"

  $scenarioBlocks = @([regex]::Matches($evidenceText, '(?ms)^\s*@verification-scenario\s+(?<scenario>[A-Za-z][A-Za-z0-9_.:-]*)\s*$.*?(?=^\s*@verification-scenario\s+|\z)'))
  $matchingBlocks = @($scenarioBlocks | Where-Object { $_.Groups['scenario'].Value -ceq $scenario })
  if ($matchingBlocks.Count -ne 1) {
    $Errors.Add('verification-production-binding-missing')
    return $false
  }
  $block = $matchingBlocks[0].Value
  $requiredMarkers = [ordered]@{
    'verification-owner' = $VerificationRow['Verification Owner ID']
    'production-responsibility' = $VerificationRow['Production Responsibility ID']
    'owned-capability' = $VerificationRow['Capability ID']
    'evidence-kind' = $VerificationRow['Evidence Kind']
    'verification-disposition' = $VerificationRow['Verification Disposition']
  }
  foreach ($marker in $requiredMarkers.Keys) {
    $matches = @([regex]::Matches($block, '(?m)^\s*@' + [regex]::Escape($marker) + '\s+(?<value>[^\r\n]+?)\s*$'))
    if ($matches.Count -ne 1 -or $matches[0].Groups['value'].Value -cne $requiredMarkers[$marker]) {
      $Errors.Add('verification-production-binding-missing')
      return $false
    }
  }
  if (@([regex]::Matches($block, '(?m)^\s*scenario\s+' + [regex]::Escape($scenario) + '\s*$')).Count -ne 1) {
    $Errors.Add('verification-production-binding-missing')
    return $false
  }

  $plannedBinding = [regex]::Match($VerificationRow['Production Binding Evidence'], '^invokes\s+(?<path>[^#\r\n]+)#(?<symbol>[A-Za-z][A-Za-z0-9_.:-]*)$')
  $plannedBindingPath = if ($plannedBinding.Success) { ConvertTo-ArcCanonicalRepositoryPath -Path $plannedBinding.Groups['path'].Value } else { '' }
  $sourceBindings = @([regex]::Matches($block, '(?m)^\s*@production-binding\s+(?<path>[^#\r\n]+)#(?<symbol>[A-Za-z][A-Za-z0-9_.:-]*)\s*$'))
  $sourceBindingPath = if ($sourceBindings.Count -eq 1) { ConvertTo-ArcCanonicalRepositoryPath -Path $sourceBindings[0].Groups['path'].Value } else { '' }
  if (
    -not $plannedBinding.Success -or
    $plannedBindingPath -ceq '' -or
    $sourceBindings.Count -ne 1 -or
    $sourceBindingPath -ceq '' -or
    $sourceBindingPath -cne $plannedBindingPath -or
    $sourceBindings[0].Groups['symbol'].Value -cne $plannedBinding.Groups['symbol'].Value
  ) {
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
    $productionOwner.Path -cne $plannedBindingPath -or
    ($productionOwner.OwnerSymbols -cnotcontains $plannedBinding.Groups['symbol'].Value -and $productionOwner.Symbols -cnotcontains $plannedBinding.Groups['symbol'].Value) -or
    $productionOwner.Capabilities -cnotcontains $VerificationRow['Capability ID'] -or
    $productionOwner.VerificationOwners -cnotcontains $VerificationRow['Verification Owner ID']
  ) {
    $Errors.Add('verification-production-binding-missing')
    return $false
  }

  if ($VerificationRow['Evidence Kind'] -ceq 'production-composition') {
    $routeMatches = @([regex]::Matches($block, '(?m)^\s*@production-route\s+(?<symbol>[A-Za-z][A-Za-z0-9_.:-]*)\s*->\s*(?<provider>[A-Za-z][A-Za-z0-9_.:-]*)\s*$'))
    try {
      $rawProductionText = Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('show', "${FinalTreeSha}:$($productionOwner.Path)")
      $productionLexicalLines = @(Get-ArcSourceLexicalLines -SourceText $rawProductionText -SourcePath $productionOwner.Path)
      if (@($productionLexicalLines | Where-Object { $_.Ambiguous }).Count -gt 0) { $productionText = '' }
      else {
        $productionText = @($productionLexicalLines | Where-Object { $_.HasCode -or $_.HasSemanticMetadata } | ForEach-Object { $_.SemanticText }) -join "`n"
      }
    }
    catch { $productionText = '' }
    $exactProductionRouteCount = if ($routeMatches.Count -eq 1) {
      @([regex]::Matches($productionText, '(?m)^\s*route\s+' + [regex]::Escape($routeMatches[0].Groups['symbol'].Value) + '\s*->\s*' + [regex]::Escape($routeMatches[0].Groups['provider'].Value) + '\s*$')).Count
    } else { 0 }
    if ($routeMatches.Count -ne 1 -or $exactProductionRouteCount -ne 1 -or $productionOwner.RouteSymbols -cnotcontains $routeMatches[0].Groups['symbol'].Value -or $productionOwner.Providers -cnotcontains $routeMatches[0].Groups['provider'].Value) {
      $Errors.Add('verification-production-binding-missing')
      return $false
    }
  }
  return $true
}

function Get-ArcExecutableReviewState {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$ReviewText,
    [Parameter(Mandatory)][AllowEmptyCollection()][Collections.Generic.List[string]]$Errors
  )

  $visibleText = Get-ArcVisibleMarkdownText -Text $ReviewText
  $state = [ordered]@{
    RuleResolution = ''
    CanonicalSelector = ''
    Architecture = ''
    Tree = ''
    Responsibility = ''
    Verification = ''
    ProductionActivation = ''
    Behavior = ''
    ChangeHygiene = ''
    CriticalCount = -1
    MajorCount = -1
    Overall = ''
  }
  $readControl = {
    param([string]$Label, [string[]]$Allowed, [string]$MissingDiagnostic = 'responsibility-evidence-missing')
    $matches = @([regex]::Matches($visibleText, '(?im)^[ \t]*-[ \t]*(?:\*\*)?' + [regex]::Escape($Label) + '(?:\*\*)?:[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$'))
    if ($matches.Count -ne 1) {
      $Errors.Add($MissingDiagnostic)
      return ''
    }
    $value = $matches[0].Groups['value'].Value.Trim().Trim([char[]]@('<', '>', '`'))
    if ($Allowed -cnotcontains $value) {
      $Errors.Add('responsibility-evidence-missing')
      return ''
    }
    return $value
  }
  $readCount = {
    param([string]$Label)
    $matches = @([regex]::Matches($visibleText, '(?im)^[ \t]*-[ \t]*(?:\*\*)?' + [regex]::Escape($Label) + ':(?:\*\*)?[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$'))
    [UInt64]$parsed = 0
    if ($matches.Count -ne 1 -or -not [UInt64]::TryParse($matches[0].Groups['value'].Value.Trim(), [ref]$parsed)) {
      $Errors.Add('responsibility-evidence-missing')
      return [Int64]-1
    }
    if ($parsed -gt [Int64]::MaxValue) {
      $Errors.Add('responsibility-evidence-missing')
      return [Int64]-1
    }
    return [Int64]$parsed
  }

  $state.RuleResolution = & $readControl 'Rule Resolution Verdict' @('RESOLVED', 'BLOCKED')
  $state.CanonicalSelector = & $readControl 'Canonical Selector Verdict' @('PASS', 'BLOCKED')
  $state.Architecture = & $readControl 'Architecture Conformance Verdict' @('PASS', 'BLOCKED') 'responsibility-owner-missing'
  $state.Tree = & $readControl 'Tree Conformance Verdict' @('PASS', 'BLOCKED') 'responsibility-owner-missing'
  $state.Responsibility = & $readControl 'Responsibility Conformance Verdict' @('PASS', 'BLOCKED') 'responsibility-owner-missing'
  $state.Verification = & $readControl 'Verification Ownership Verdict' @('PASS', 'BLOCKED') 'responsibility-owner-missing'
  $state.ProductionActivation = & $readControl 'Production Activation-path Verdict' @('PASS', 'BLOCKED', 'NOT_APPLICABLE')
  $state.Behavior = & $readControl 'Behavior Analysis State' @('NOT_RUN', 'COMPLETE')
  $state.ChangeHygiene = & $readControl 'Change Hygiene Verdict' @('PASS', 'BLOCKED')
  $state.CriticalCount = & $readCount 'Critical count'
  $state.MajorCount = & $readCount 'Major count'
  $state.Overall = & $readControl 'Verdict' @('Approve', 'Approve-with-fixes', 'Reject')

  $localizedIssueColumn = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('VuG6pW4gxJHhu4E='))
  $localizedFixColumn = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('Rml4IMSR4buBIHh14bqldA=='))
  $findingColumnSets = @(
    @('File:line', 'Issue', 'Proposed fix'),
    @('File:line', $localizedIssueColumn, $localizedFixColumn)
  )
  $getFindingTable = {
    param([string]$Heading)
    $firstDiagnostics = @()
    foreach ($findingColumns in $findingColumnSets) {
      $tableErrors = [Collections.Generic.List[string]]::new()
      $candidate = @(Get-ArcStrictMarkdownTable -Text $ReviewText -Heading $Heading -Columns $findingColumns -Errors $tableErrors -AllowEmptyBody)
      if ($tableErrors.Count -eq 0) { return $candidate }
      if ($firstDiagnostics.Count -eq 0) { $firstDiagnostics = @($tableErrors) }
    }
    foreach ($diagnostic in $firstDiagnostics) { $Errors.Add($diagnostic) }
    return @()
  }
  $criticalTable = @(& $getFindingTable 'Critical')
  $majorTable = @(& $getFindingTable 'Major')
  $countFindings = {
    param([object[]]$Table)
    if ($Table.Count -lt 2) { return [Int64]-1 }
    $rows = @($Table | Select-Object -Skip 2)
    if ($rows.Count -eq 0) { return [Int64]0 }
    if ($rows.Count -eq 1 -and @($rows[0] | Where-Object { [string]$_ -ceq 'none' }).Count -eq 3) { return [Int64]0 }
    if (@($rows | Where-Object { @($_ | Where-Object { [string]::IsNullOrWhiteSpace([string]$_) -or [string]$_ -ceq 'none' }).Count -gt 0 }).Count -gt 0) {
      $Errors.Add('responsibility-evidence-missing')
      return [Int64]-1
    }
    return [Int64]$rows.Count
  }
  $criticalFindingCount = & $countFindings $criticalTable
  $majorFindingCount = & $countFindings $majorTable
  if ($state.CriticalCount -ge 0 -and $criticalFindingCount -ge 0 -and $state.CriticalCount -ne $criticalFindingCount) { $Errors.Add('responsibility-waiver-forbidden') }
  if ($state.MajorCount -ge 0 -and $majorFindingCount -ge 0 -and $state.MajorCount -ne $majorFindingCount) { $Errors.Add('responsibility-waiver-forbidden') }

  if (@($state.Values | Where-Object { [string]::IsNullOrWhiteSpace([string]$_) }).Count -eq 0 -and $state.CriticalCount -ge 0 -and $state.MajorCount -ge 0) {
    $derivedArchitecture = if ($state.Tree -ceq 'PASS' -and $state.Responsibility -ceq 'PASS' -and $state.Verification -ceq 'PASS') { 'PASS' } else { 'BLOCKED' }
    if ($state.Architecture -cne $derivedArchitecture) { $Errors.Add('responsibility-waiver-forbidden') }
    $preBehaviorBlocked =
      $state.RuleResolution -ceq 'BLOCKED' -or
      $state.CanonicalSelector -ceq 'BLOCKED' -or
      $state.Architecture -ceq 'BLOCKED' -or
      $state.Tree -ceq 'BLOCKED' -or
      $state.Responsibility -ceq 'BLOCKED' -or
      $state.Verification -ceq 'BLOCKED' -or
      $state.ProductionActivation -ceq 'BLOCKED'
    $expectedBehavior = if ($preBehaviorBlocked) { 'NOT_RUN' } else { 'COMPLETE' }
    if ($state.Behavior -cne $expectedBehavior) { $Errors.Add('responsibility-waiver-forbidden') }
    $allExecutableGatesPass = -not $preBehaviorBlocked -and $state.Behavior -ceq 'COMPLETE' -and $state.ChangeHygiene -ceq 'PASS'
    $derivedOverall = if (-not $allExecutableGatesPass -or $state.CriticalCount -gt 0) {
      'Reject'
    }
    elseif ($state.MajorCount -gt 0) {
      'Approve-with-fixes'
    }
    else {
      'Approve'
    }
    if ($state.Overall -cne $derivedOverall) { $Errors.Add('responsibility-waiver-forbidden') }
  }
  return [pscustomobject]$state
}

function Test-ResponsibilityReview {
  [CmdletBinding()]
  param(
    [string]$DesignText,
    [string]$ImplementationText,
    [string]$ReviewText,
    [string]$ContractText,
    [string]$SourceRoot,
    [string]$TaskBaseSha,
    [string]$FinalTreeSha,
    [string]$ApprovedPlanText
  )
  $errors = [Collections.Generic.List[string]]::new()
  foreach ($error in @(Test-ArcResponsibilityStageVersion $ContractText 'REVIEW')) { $errors.Add($error) }
  if ([string]::IsNullOrWhiteSpace($DesignText) -or [string]::IsNullOrWhiteSpace($ImplementationText) -or [string]::IsNullOrWhiteSpace($ReviewText)) {
    $errors.Add('responsibility-owner-missing')
    return @($errors | Select-Object -Unique)
  }
  if (@(Test-ArcDiscoveryResponsibilityContractVersion -DiscoveryText $DesignText).Count -ne 0 -or @(Test-ArcDiscoveryResponsibilityContractVersion -DiscoveryText $ImplementationText).Count -ne 0 -or @(Test-ArcDiscoveryResponsibilityContractVersion -DiscoveryText $ReviewText).Count -ne 0) {
    $errors.Add('responsibility-contract-version-invalid')
    return @($errors | Select-Object -Unique)
  }
  $visibleReviewText = Get-ArcVisibleMarkdownText -Text $ReviewText
  $executableReviewState = $null
  $scopeColumns = @('Run ID', 'Master Spec Reference', 'Master Spec ID', 'Master Spec Revision', 'Master Plan Reference', 'Master Plan ID', 'Master Plan Revision', 'Work Item ID')
  $selectorColumns = @('Work Item ID', 'Adapter Kind', 'External ID', 'Authority', 'Authority Revision', 'Approval Reference', 'Parent Selector', 'Acceptance', 'Trace IDs', 'Mode Constraint', 'Design Revision', 'Parent Work Item ID', 'Decomposition Decision Reference')
  $implementationSelectorColumns = @($selectorColumns + 'Canonical Match')
  $provenanceColumns = @('Task / Unit', 'Task-base SHA', 'Final-tree SHA', 'Source Artifact')
  $handoffColumns = @('Responsibility Contract Version', 'Tree Conformance', 'Responsibility Conformance', 'Verification Ownership', 'Architecture Conformance State', 'Evidence References')
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
  if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }
  if ($implementationScopeTable.Count -ne 3 -or $reviewScopeTable.Count -ne 3 -or $implementationSelectorTable.Count -ne 3 -or $reviewProvenanceTable.Count -ne 3 -or $reviewHandoffTable.Count -ne 3 -or $planSelectorTable.Count -lt 3 -or $planWorkItemTable.Count -lt 3 -or $null -eq $planFrontMatter) {
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
  $reviewScope = & $rowFromTable $reviewScopeTable $scopeColumns
  foreach ($field in $scopeColumns) {
    if ($implementationScope[$field] -cne $reviewScope[$field]) { $errors.Add('responsibility-evidence-missing') }
  }
  if (
    $reviewScope['Run ID'] -cnotmatch '^RUN-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -or
    $reviewScope['Master Spec Reference'] -cnotmatch '^(?:[A-Za-z0-9_.-]+/)*master-spec\.md$' -or
    $reviewScope['Master Spec ID'] -cnotmatch '^SPEC-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -or
    $reviewScope['Master Spec Revision'] -cnotmatch '^[1-9][0-9]*$' -or
    $reviewScope['Master Plan Reference'] -cnotmatch '^(?:[A-Za-z0-9_.-]+/)*master-plan\.md$' -or
    $reviewScope['Master Plan ID'] -cnotmatch '^PLAN-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -or
    $reviewScope['Master Plan Revision'] -cnotmatch '^[1-9][0-9]*$' -or
    $reviewScope['Work Item ID'] -cnotmatch '^WORK-[A-Z0-9]+(?:-[A-Z0-9]+)*$'
  ) { $errors.Add('responsibility-evidence-missing') }
  $planFields = @{}
  foreach ($field in @('artifact_type', 'master_plan_id', 'master_spec_id', 'master_spec_revision', 'revision', 'status')) {
    $matches = @([regex]::Matches($planFrontMatter, '(?m)^' + [regex]::Escape($field) + ':\s*(?<value>[^\r\n]+?)\s*$'))
    if ($matches.Count -ne 1) { $errors.Add('responsibility-evidence-missing') } else { $planFields[$field] = $matches[0].Groups['value'].Value.Trim() }
  }
  if ($planFields['artifact_type'] -cne 'migration-master-plan' -or $planFields['status'] -cne 'approved' -or $planFields['master_plan_id'] -cne $reviewScope['Master Plan ID'] -or $planFields['revision'] -cne $reviewScope['Master Plan Revision'] -or $planFields['master_spec_id'] -cne $reviewScope['Master Spec ID'] -or $planFields['master_spec_revision'] -cne $reviewScope['Master Spec Revision']) {
    $errors.Add('responsibility-evidence-missing')
  }
  $implementationSelector = & $rowFromTable $implementationSelectorTable $implementationSelectorColumns
  if ($implementationSelector['Canonical Match'] -cne 'PASS' -or $implementationSelector['Work Item ID'] -cne $reviewScope['Work Item ID']) { $errors.Add('responsibility-evidence-missing') }
  $planSelectorRows = @($planSelectorTable | Select-Object -Skip 2 | Where-Object { [string]$_[0] -ceq $reviewScope['Work Item ID'] })
  $planWorkItemRows = @($planWorkItemTable | Select-Object -Skip 2 | Where-Object { [string]$_[0] -ceq $reviewScope['Work Item ID'] })
  if ($planSelectorRows.Count -ne 1 -or $planWorkItemRows.Count -ne 1) {
    $errors.Add('responsibility-evidence-missing')
    return @($errors | Select-Object -Unique)
  }
  $planSelector = [ordered]@{}
  for ($index = 0; $index -lt $selectorColumns.Count; $index++) { $planSelector[$selectorColumns[$index]] = [string]$planSelectorRows[0][$index] }
  foreach ($field in $selectorColumns) {
    if ($implementationSelector[$field] -cne $planSelector[$field]) { $errors.Add('responsibility-evidence-missing') }
  }
  $planWorkItem = [ordered]@{}
  for ($index = 0; $index -lt $workItemColumns.Count; $index++) { $planWorkItem[$workItemColumns[$index]] = [string]$planWorkItemRows[0][$index] }
  $expectedDeliveryAdapter = if ($planSelector['Adapter Kind'] -ceq 'none') { 'none' } else { "$($planSelector['Adapter Kind']):$($planSelector['External ID'])" }
  if ($planWorkItem['Acceptance'] -cne $planSelector['Acceptance'] -or $planWorkItem['Trace IDs'] -cne $planSelector['Trace IDs'] -or ($planWorkItem['Delivery Adapter'] -cne $expectedDeliveryAdapter -and -not ($planSelector['Adapter Kind'] -ceq 'none' -and $planWorkItem['Delivery Adapter'] -cmatch '^generic:[A-Za-z0-9][A-Za-z0-9._-]*$'))) {
    $errors.Add('responsibility-evidence-missing')
  }
  $reviewAdapterMatches = @(Get-ArcStrictVisibleBulletMatches -Text $ReviewText -Label 'Delivery Adapter Kind')
  $reviewModeMatches = @(Get-ArcStrictVisibleBulletMatches -Text $ReviewText -Label 'Delivery Adapter Mode Constraint')
  if (
    $reviewAdapterMatches.Count -ne 1 -or
    $reviewAdapterMatches[0].Groups['value'].Value.Trim() -cne $planSelector['Adapter Kind'] -or
    $reviewModeMatches.Count -ne 1 -or
    $reviewModeMatches[0].Groups['value'].Value.Trim() -cne $planSelector['Mode Constraint'] -or
    $reviewModeMatches[0].Groups['value'].Value.Trim() -cnotin @('incremental/preserve-existing', 'greenfield/design-new')
  ) { $errors.Add('responsibility-evidence-missing') }
  $reviewProvenance = & $rowFromTable $reviewProvenanceTable $provenanceColumns
  $expectedTaskUnit = if ($planSelector['Adapter Kind'] -ceq 'migration-unit') { $planSelector['External ID'] } else { $reviewScope['Work Item ID'] }
  if ($reviewProvenance['Task / Unit'] -cne $expectedTaskUnit -or $reviewProvenance['Task-base SHA'] -cne $TaskBaseSha -or $reviewProvenance['Final-tree SHA'] -cne $FinalTreeSha -or $reviewProvenance['Task-base SHA'] -cnotmatch '^[0-9a-f]{40}$' -or $reviewProvenance['Final-tree SHA'] -cnotmatch '^[0-9a-f]{40}$' -or $reviewProvenance['Source Artifact'] -cne 'implementation-report.md') {
    $errors.Add('responsibility-evidence-missing')
  }
  if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }
  $implementationProvenanceEnvelope = Get-ArcImplementationReviewProvenance -ImplementationText $ImplementationText -Errors $errors
  if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }
  if ($null -eq $implementationProvenanceEnvelope -or $implementationProvenanceEnvelope.TaskUnit -cne $expectedTaskUnit -or $implementationProvenanceEnvelope.TaskBaseSha -cne $TaskBaseSha -or $implementationProvenanceEnvelope.FinalTreeSha -cne $FinalTreeSha) {
    $errors.Add('responsibility-evidence-missing')
  }
  $reviewHygieneColumns = @('Task / Unit', 'Scope Evidence', 'Formatter Evidence', 'Unrelated Diff', 'Severity', 'Task-base SHA', 'Final-tree SHA')
  $reviewHygieneTable = @(Get-ArcStrictMarkdownTable -Text $ReviewText -Heading 'Change Hygiene' -Columns $reviewHygieneColumns -Errors $errors)
  $majorFindingColumns = @('File:line', 'Issue', 'Proposed fix')
  $majorFindingTable = @(Get-ArcStrictMarkdownTable -Text $ReviewText -Heading 'Major' -Columns $majorFindingColumns -Errors $errors)
  if ($errors.Count -ne 0 -or $reviewHygieneTable.Count -lt 3 -or $majorFindingTable.Count -lt 2) {
    if ($reviewHygieneTable.Count -lt 3 -or $majorFindingTable.Count -lt 2) { $errors.Add('change-hygiene-review-mismatch') }
    return @($errors | Select-Object -Unique)
  }
  $reviewHygieneRows = @($reviewHygieneTable | Select-Object -Skip 2)
  $majorFindingRows = @($majorFindingTable | Select-Object -Skip 2)
  if ($majorFindingRows.Count -eq 1 -and ([string]$majorFindingRows[0][0]) -ceq 'none' -and ([string]$majorFindingRows[0][1]) -ceq 'none' -and ([string]$majorFindingRows[0][2]) -ceq 'none') {
    $majorFindingRows = @()
  }
  elseif (@($majorFindingRows | Where-Object { @($_ | Where-Object { [string]$_ -ceq 'none' }).Count -gt 0 }).Count -gt 0) {
    $errors.Add('change-hygiene-review-mismatch')
  }
  foreach ($reviewHygieneRow in $reviewHygieneRows) {
    $scopeMatch = [regex]::Match(([string]$reviewHygieneRow[1]).Trim(), '^(?<path>.+)#(?<region>[A-Za-z_][A-Za-z0-9_.:-]*(?:, [A-Za-z_][A-Za-z0-9_.:-]*)*)$')
    $canonicalScopePath = if ($scopeMatch.Success) { ConvertTo-ArcCanonicalRepositoryPath -Path $scopeMatch.Groups['path'].Value } else { '' }
    if ($canonicalScopePath -ceq '') { $errors.Add('change-hygiene-review-mismatch') }
    else { $reviewHygieneRow[1] = "$canonicalScopePath#$($scopeMatch.Groups['region'].Value)" }
  }
  $confirmedHygieneRows = [Collections.Generic.List[object]]::new()
  foreach ($implementationHygieneRow in $implementationProvenanceEnvelope.Rows) {
    $scopeEvidence = "$([string]$implementationHygieneRow[1])#$([string]$implementationHygieneRow[3])"
    $unrelatedDiff = ([string]$implementationHygieneRow[5]).Trim()
    $expectedSeverity = if ($unrelatedDiff -ceq 'none') { 'none' } else { 'Major' }
    $matchingReviewHygieneRows = @($reviewHygieneRows | Where-Object {
      [string]$_[0] -ceq $implementationProvenanceEnvelope.TaskUnit -and
      [string]$_[1] -ceq $scopeEvidence -and
      [string]$_[2] -ceq ([string]$implementationHygieneRow[4]).Trim() -and
      [string]$_[3] -ceq $unrelatedDiff -and
      [string]$_[4] -ceq $expectedSeverity -and
      [string]$_[5] -ceq $TaskBaseSha -and
      [string]$_[6] -ceq $FinalTreeSha
    })
    if ($matchingReviewHygieneRows.Count -ne 1) {
      $errors.Add('change-hygiene-review-mismatch')
      continue
    }
    if ($unrelatedDiff -cne 'none') {
      $confirmedHygieneRows.Add([pscustomobject]@{
        ScopeEvidence = $scopeEvidence
        FindingId = $unrelatedDiff.Substring('confirmed:'.Length)
      })
    }
  }
  foreach ($reviewHygieneRow in $reviewHygieneRows) {
    $matchingImplementationHygieneRows = @($implementationProvenanceEnvelope.Rows | Where-Object {
      $candidateScopeEvidence = "$([string]$_[1])#$([string]$_[3])"
      $candidateUnrelatedDiff = ([string]$_[5]).Trim()
      $candidateSeverity = if ($candidateUnrelatedDiff -ceq 'none') { 'none' } else { 'Major' }
      [string]$reviewHygieneRow[0] -ceq $implementationProvenanceEnvelope.TaskUnit -and
      [string]$reviewHygieneRow[1] -ceq $candidateScopeEvidence -and
      [string]$reviewHygieneRow[2] -ceq ([string]$_[4]).Trim() -and
      [string]$reviewHygieneRow[3] -ceq $candidateUnrelatedDiff -and
      [string]$reviewHygieneRow[4] -ceq $candidateSeverity -and
      [string]$reviewHygieneRow[5] -ceq $TaskBaseSha -and
      [string]$reviewHygieneRow[6] -ceq $FinalTreeSha
    })
    if ($matchingImplementationHygieneRows.Count -ne 1) { $errors.Add('change-hygiene-review-mismatch') }
  }
  foreach ($confirmedHygieneRow in $confirmedHygieneRows) {
    $matchingMajorFindings = @($majorFindingRows | Where-Object {
      [string]$_[0] -ceq $confirmedHygieneRow.ScopeEvidence -and
      [string]$_[1] -ceq "$($confirmedHygieneRow.FindingId): confirmed unrelated diff" -and
      -not [string]::IsNullOrWhiteSpace([string]$_[2]) -and
      [string]$_[2] -cne 'none'
    })
    if ($matchingMajorFindings.Count -ne 1) { $errors.Add('change-hygiene-review-mismatch') }
  }
  foreach ($majorFindingRow in $majorFindingRows) {
    $matchingConfirmedRows = @($confirmedHygieneRows | Where-Object {
      $_.ScopeEvidence -ceq [string]$majorFindingRow[0] -and
      "$($_.FindingId): confirmed unrelated diff" -ceq [string]$majorFindingRow[1]
    })
    if ($matchingConfirmedRows.Count -ne 1) { $errors.Add('change-hygiene-review-mismatch') }
  }
  $changeHygieneVerdictMatches = @([regex]::Matches($visibleReviewText, '(?im)^[ \t]*-[ \t]*Change Hygiene Verdict:[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$'))
  $majorCountMatches = @([regex]::Matches($visibleReviewText, '(?im)^[ \t]*-[ \t]*(?:\*\*)?Major count:(?:\*\*)?[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$'))
  $expectedHygieneVerdict = if ($confirmedHygieneRows.Count -eq 0) { 'PASS' } else { 'BLOCKED' }
  if (
    $changeHygieneVerdictMatches.Count -ne 1 -or
    $changeHygieneVerdictMatches[0].Groups['value'].Value.Trim() -cne $expectedHygieneVerdict -or
    $majorCountMatches.Count -ne 1 -or
    $majorCountMatches[0].Groups['value'].Value.Trim() -cne [string]$confirmedHygieneRows.Count -or
    $majorFindingRows.Count -ne $confirmedHygieneRows.Count
  ) { $errors.Add('change-hygiene-review-mismatch') }
  if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }
  $reviewHandoff = & $rowFromTable $reviewHandoffTable $handoffColumns
  $expectedSourceDiff = "source-diff:$TaskBaseSha..$FinalTreeSha#$($reviewScope['Work Item ID'])"
  $derivedHandoff = if ($reviewHandoff['Tree Conformance'] -ceq 'PASS' -and $reviewHandoff['Responsibility Conformance'] -ceq 'PASS' -and $reviewHandoff['Verification Ownership'] -ceq 'PASS') { 'PASS' } else { 'BLOCKED' }
  if ($reviewHandoff['Responsibility Contract Version'] -cne '1') { $errors.Add('responsibility-contract-version-invalid') }
  if (@('Tree Conformance', 'Responsibility Conformance', 'Verification Ownership') | Where-Object { $reviewHandoff[$_] -cnotin @('PASS', 'BLOCKED') }) { $errors.Add('responsibility-evidence-missing') }
  if ($reviewHandoff['Architecture Conformance State'] -cne $derivedHandoff) { $errors.Add('responsibility-waiver-forbidden') }
  if ($reviewHandoff['Evidence References'] -cne $expectedSourceDiff) { $errors.Add('responsibility-evidence-missing') }
  if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }
  $implementationSelectedHeadingCount = @(Get-ArcMarkdownH2HeadingMatches -Text $ImplementationText -Heading 'Selected Migration Unit').Count
  $reviewSelectedHeadingCount = @(Get-ArcMarkdownH2HeadingMatches -Text $ReviewText -Heading 'Selected Migration Unit').Count
  if ($planSelector['Adapter Kind'] -ceq 'migration-unit') {
    $implementationSelectedTable = @(Get-ArcStrictMarkdownTable -Text $ImplementationText -Heading 'Selected Migration Unit' -Columns $selectedUnitColumns -Errors $errors)
    $reviewSelectedTable = @(Get-ArcStrictMarkdownTable -Text $ReviewText -Heading 'Selected Migration Unit' -Columns $selectedUnitColumns -Errors $errors)
    if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }
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
  $designRevision = Get-ArcApprovedReviewDesignRevision -DesignText $DesignText -Errors $errors
  if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }

  $responsibilityColumns = @('Responsibility ID', 'Owner Path', 'Owner Symbol', 'Boundary Kind', 'Primary Responsibility', 'Owned Capability IDs', 'Trace IDs', 'Atomic Boundary ID', 'Public Symbols', 'External Effects', 'Target Exemplar', 'Exemplar Classification', 'Classification Authority', 'Classification Evidence', 'Architecture Authority', 'Co-location Policy', 'Co-location Evidence', 'Verification Owner References', 'Conformance', 'Deviation Reference')
  $verificationColumns = @('Verification Owner ID', 'Production Responsibility ID', 'Capability ID', 'Evidence Path', 'Evidence Symbol or Scenario', 'Evidence Kind', 'Verification Disposition', 'Production Binding Evidence', 'Decision Reference', 'Verdict', 'Deviation Reference')
  $actualResponsibilityColumns = @($responsibilityColumns + 'Actual Evidence')
  $actualVerificationColumns = @($verificationColumns + 'Actual Evidence')
  $ownerReferenceColumns = @('Work Item ID', 'Design Revision', 'Responsibility IDs', 'Shared Foundation IDs', 'Integration Responsibility IDs', 'Independent Boundary Evidence')
  $reviewColumns = @('Responsibility ID', 'Source/Diff Evidence', 'Planned Public Symbols', 'Actual Public Symbols', 'Planned Effects', 'Actual Effects', 'Verdict')
  $plannedResponsibilityTable = @(Get-ArcStrictMarkdownTable -Text $DesignText -Heading 'File Responsibility Matrix' -Columns $responsibilityColumns -Errors $errors)
  $plannedVerificationTable = @(Get-ArcStrictMarkdownTable -Text $DesignText -Heading 'Verification Ownership Matrix' -Columns $verificationColumns -Errors $errors)
  $implementationResponsibilityTable = @(Get-ArcStrictMarkdownTable -Text $ImplementationText -Heading 'Actual File Responsibility Matrix' -Columns $actualResponsibilityColumns -Errors $errors)
  $implementationVerificationTable = @(Get-ArcStrictMarkdownTable -Text $ImplementationText -Heading 'Actual Verification Ownership Matrix' -Columns $actualVerificationColumns -Errors $errors)
  $ownerReferenceTable = @(Get-ArcStrictMarkdownTable -Text $ImplementationText -Heading 'Responsibility Owner References' -Columns $ownerReferenceColumns -Errors $errors)
  $reviewEvidenceTable = @(Get-ArcStrictMarkdownTable -Text $ReviewText -Heading 'Responsibility Review Evidence' -Columns $reviewColumns -Errors $errors)
  if ($errors.Count -ne 0 -or $plannedResponsibilityTable.Count -lt 3 -or $plannedVerificationTable.Count -lt 3 -or $implementationResponsibilityTable.Count -lt 3 -or $implementationVerificationTable.Count -lt 3 -or $ownerReferenceTable.Count -lt 3 -or $reviewEvidenceTable.Count -lt 3) { return @($errors | Select-Object -Unique) }
  $executableReviewState = Get-ArcExecutableReviewState -ReviewText $ReviewText -Errors $errors
  if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }

  $toRow = { param([object]$Cells, [string[]]$Columns) $row = @{}; for ($index = 0; $index -lt $Columns.Count; $index++) { $row[$Columns[$index]] = [string]$Cells[$index] }; return $row }
  $splitList = { param([string]$Value) @($Value -split '[,;]' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }) }
  $validVerdicts = @(Get-ArcContractEnumValues -ContractText $ContractText -Name 'Verdict')
  $allPlannedResponsibilities = @($plannedResponsibilityTable | Select-Object -Skip 2 | ForEach-Object { & $toRow $_ $responsibilityColumns })
  $allPlannedVerifications = @($plannedVerificationTable | Select-Object -Skip 2 | ForEach-Object { & $toRow $_ $verificationColumns })
  $implementationResponsibilities = @($implementationResponsibilityTable | Select-Object -Skip 2 | ForEach-Object { & $toRow $_ $actualResponsibilityColumns })
  $implementationVerifications = @($implementationVerificationTable | Select-Object -Skip 2 | ForEach-Object { & $toRow $_ $actualVerificationColumns })
  $ownerReferenceRows = @($ownerReferenceTable | Select-Object -Skip 2 | ForEach-Object { & $toRow $_ $ownerReferenceColumns })
  $reviewRows = @($reviewEvidenceTable | Select-Object -Skip 2 | ForEach-Object { & $toRow $_ $reviewColumns })
  foreach ($ownerRow in @($allPlannedResponsibilities + $implementationResponsibilities)) {
    $canonicalOwnerPath = ConvertTo-ArcCanonicalRepositoryPath -Path $ownerRow['Owner Path']
    if ($canonicalOwnerPath -ceq '') { $errors.Add('responsibility-evidence-missing') }
    else { $ownerRow['Owner Path'] = $canonicalOwnerPath }
  }
  foreach ($verificationRow in @($allPlannedVerifications + $implementationVerifications)) {
    $canonicalEvidencePath = ConvertTo-ArcCanonicalRepositoryPath -Path $verificationRow['Evidence Path']
    $bindingMatch = [regex]::Match($verificationRow['Production Binding Evidence'], '^invokes\s+(?<path>[^#]+)#(?<symbol>[A-Za-z][A-Za-z0-9_.:-]*)$')
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
      $canonicalEvidenceItem = ConvertTo-ArcCanonicalReviewEvidenceItem -EvidenceItem $evidenceItem
      if ($canonicalEvidenceItem -ceq '') { $errors.Add('responsibility-evidence-missing'); continue }
      $canonicalEvidenceItems.Add($canonicalEvidenceItem)
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
  else {
    foreach ($field in @('Responsibility IDs', 'Shared Foundation IDs', 'Integration Responsibility IDs')) {
      if ($ownerReferenceRows[0][$field] -cne 'not-applicable') { $referencedOwnerIds += @(& $splitList $ownerReferenceRows[0][$field]) }
    }
    if ($referencedOwnerIds.Count -eq 0 -or @($referencedOwnerIds | Sort-Object -Unique).Count -ne $referencedOwnerIds.Count) { $errors.Add('responsibility-owner-extra') }
    foreach ($id in $referencedOwnerIds) { if (-not $allPlannedById.ContainsKey($id)) { $errors.Add('responsibility-owner-extra') } }
  }
  if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }
  $plannedResponsibilities = @($referencedOwnerIds | ForEach-Object { $allPlannedById[$_] })
  $plannedVerifications = @($allPlannedVerifications | Where-Object { $referencedOwnerIds -ccontains $_['Production Responsibility ID'] })

  $implementationProvenance = Get-ArcImplementationReviewProvenance -ImplementationText $ImplementationText -Errors $errors
  if ($null -eq $implementationProvenance -or $implementationProvenance.TaskBaseSha -cne $TaskBaseSha -or $implementationProvenance.FinalTreeSha -cne $FinalTreeSha) {
    $errors.Add('responsibility-evidence-missing')
    return @($errors | Select-Object -Unique)
  }
  if ($ownerReferenceRows[0]['Work Item ID'] -cne $reviewScope['Work Item ID']) {
    $errors.Add('responsibility-evidence-missing')
    return @($errors | Select-Object -Unique)
  }
  $selectedPaths = @($plannedResponsibilities | ForEach-Object { $_['Owner Path'] } | Select-Object -Unique)
  $sourceInventory = Get-ArcPinnedSourceInventory -SourceRoot $SourceRoot -TaskBaseSha $implementationProvenance.TaskBaseSha -FinalTreeSha $implementationProvenance.FinalTreeSha -SelectedPaths $selectedPaths -Errors $errors
  if ($errors.Count -ne 0 -or $null -eq $sourceInventory) { return @($errors | Select-Object -Unique) }
  $inventory = @($sourceInventory.ActiveOwners)
  $deletedInventory = @($sourceInventory.DeletedOwners)
  $changedPathRecords = @($sourceInventory.ChangedPaths)
  foreach ($record in $changedPathRecords) {
    $matchingHygieneRows = @($implementationProvenance.Rows | Where-Object { $_[1] -ceq $record.Path -and $_[2] -ceq $record.FileKind })
    if ($matchingHygieneRows.Count -ne 1) {
      $errors.Add('responsibility-evidence-missing')
      continue
    }
    $expectedCheckpoint = if ($record.Status -ceq 'D') {
      "source:${TaskBaseSha}:$($record.BasePath); diff:${TaskBaseSha}..${FinalTreeSha}:$($record.BasePath)"
    }
    elseif ($record.Status -ceq 'R') {
      "source:${TaskBaseSha}:$($record.BasePath); diff:${TaskBaseSha}..${FinalTreeSha}:$($record.RenameMapping)"
    }
    else { '' }
    if ($expectedCheckpoint -ne '' -and [string]$matchingHygieneRows[0][6] -cne $expectedCheckpoint) {
      $errors.Add('responsibility-evidence-missing')
    }
  }
  foreach ($row in $implementationProvenance.Rows) {
    $path = $row[1].Trim()
    $fileKind = $row[2].Trim()
    $matchingChanges = @($changedPathRecords | Where-Object { $_.Path -ceq $path -and $_.FileKind -ceq $fileKind })
    if (
      (ConvertTo-ArcCanonicalRepositoryPath -Path $path) -cne $path -or
      $fileKind -cnotin @('new', 'existing', 'deleted') -or
      $matchingChanges.Count -ne 1
    ) {
      $errors.Add('responsibility-evidence-missing')
    }
  }
  if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }
  if (($inventory.Count + $deletedInventory.Count) -eq 0) { $errors.Add('responsibility-evidence-missing'); return @($errors | Select-Object -Unique) }

  $plannedById = & $toMap $plannedResponsibilities 'Responsibility ID' 'responsibility-owner-extra'
  $implementationById = & $toMap $implementationResponsibilities 'Responsibility ID' 'responsibility-owner-extra'
  $reviewById = & $toMap $reviewRows 'Responsibility ID' 'responsibility-owner-extra'
  $inventoryById = @{}
  foreach ($owner in $inventory) { if ($inventoryById.ContainsKey($owner.Id)) { $errors.Add('responsibility-owner-extra') } else { $inventoryById[$owner.Id] = $owner } }
  $deletedById = @{}
  foreach ($owner in $deletedInventory) {
    if ($deletedById.ContainsKey($owner.Id) -or $inventoryById.ContainsKey($owner.Id)) { $errors.Add('responsibility-owner-extra') } else { $deletedById[$owner.Id] = $owner }
  }
  $treePass = $true; $responsibilityPass = $true; $verificationPass = $true
  foreach ($authority in @($implementationById, $inventoryById)) {
    foreach ($id in $plannedById.Keys) { if (-not $authority.ContainsKey($id)) { $errors.Add('responsibility-owner-missing'); $treePass = $false; $responsibilityPass = $false } }
    foreach ($id in $authority.Keys) { if (-not $plannedById.ContainsKey($id)) { $errors.Add('responsibility-owner-extra'); $treePass = $false; $responsibilityPass = $false } }
  }
  foreach ($id in $plannedById.Keys) { if (-not $reviewById.ContainsKey($id)) { $errors.Add('responsibility-owner-missing'); $treePass = $false; $responsibilityPass = $false } }
  foreach ($id in $reviewById.Keys) { if (-not $plannedById.ContainsKey($id) -and -not $deletedById.ContainsKey($id)) { $errors.Add('responsibility-owner-extra'); $treePass = $false; $responsibilityPass = $false } }
  foreach ($id in $plannedById.Keys | Where-Object { $implementationById.ContainsKey($_) -and $inventoryById.ContainsKey($_) -and $reviewById.ContainsKey($_) }) {
    $planned = $plannedById[$id]; $implementation = $implementationById[$id]; $actualSource = $inventoryById[$id]; $review = $reviewById[$id]
    foreach ($field in @('Owner Path', 'Owner Symbol', 'Public Symbols')) {
      if ($planned[$field] -cne $implementation[$field]) { $errors.Add('responsibility-public-symbol-mismatch'); $responsibilityPass = $false }
    }
    foreach ($field in @('Owned Capability IDs', 'Trace IDs')) { if ($planned[$field] -cne $implementation[$field]) { $errors.Add('responsibility-capability-mismatch'); $responsibilityPass = $false } }
    if ($planned['External Effects'] -cne $implementation['External Effects']) { $errors.Add('responsibility-external-effect-mismatch'); $responsibilityPass = $false }
    if ($planned['Verification Owner References'] -cne $implementation['Verification Owner References']) { $errors.Add('verification-owner-missing'); $verificationPass = $false }
    foreach ($field in @('Boundary Kind', 'Primary Responsibility', 'Atomic Boundary ID', 'Target Exemplar', 'Exemplar Classification', 'Classification Authority', 'Classification Evidence', 'Architecture Authority', 'Co-location Policy', 'Co-location Evidence', 'Conformance', 'Deviation Reference')) {
      if ($planned[$field] -cne $implementation[$field]) { $errors.Add('co-location-policy-invalid'); $responsibilityPass = $false }
    }
    $plannedOwnerSymbols = @(& $splitList $planned['Owner Symbol']); $plannedSymbols = @(& $splitList $planned['Public Symbols']); $plannedCapabilities = @(& $splitList $planned['Owned Capability IDs']); $plannedEffects = @(& $splitList $planned['External Effects']); $plannedAuthorities = @(& $splitList $planned['Architecture Authority']); $plannedCoLocationPolicies = @(& $splitList $planned['Co-location Policy']); $plannedVerificationOwners = @(& $splitList $planned['Verification Owner References'])
    $sourceOwnerSymbols = @($actualSource.OwnerSymbols | Select-Object -Unique); $sourceSymbols = @($actualSource.Symbols | Select-Object -Unique); $sourceCapabilities = @($actualSource.Capabilities | Select-Object -Unique); $sourceEffects = @($actualSource.Effects | Select-Object -Unique); $sourceAuthorities = @($actualSource.ArchitectureAuthorities | Select-Object -Unique); $sourceCoLocationPolicies = @($actualSource.CoLocationPolicies | Select-Object -Unique); $sourceVerificationOwners = @($actualSource.VerificationOwners | Select-Object -Unique)
    if ($planned['Owner Path'] -cne $actualSource.Path) { $errors.Add('responsibility-public-symbol-mismatch'); $treePass = $false; $responsibilityPass = $false }
    if (-not (Test-ArcExactSet -Actual $sourceOwnerSymbols -Expected $plannedOwnerSymbols)) { $errors.Add('responsibility-public-symbol-mismatch'); $responsibilityPass = $false }
    if (-not (Test-ArcExactSet -Actual $sourceSymbols -Expected $plannedSymbols)) { $errors.Add('responsibility-public-symbol-mismatch'); $responsibilityPass = $false }
    if (-not (Test-ArcExactSet -Actual $sourceCapabilities -Expected $plannedCapabilities)) { $errors.Add('responsibility-capability-mismatch'); $responsibilityPass = $false }
    if (-not (Test-ArcExactSet -Actual $sourceEffects -Expected $plannedEffects)) { $errors.Add('responsibility-external-effect-mismatch'); $responsibilityPass = $false }
    if (-not (Test-ArcExactSet -Actual $sourceAuthorities -Expected $plannedAuthorities) -or -not (Test-ArcExactSet -Actual $sourceCoLocationPolicies -Expected $plannedCoLocationPolicies)) { $errors.Add('co-location-policy-invalid'); $responsibilityPass = $false }
    if (-not (Test-ArcExactSet -Actual $sourceVerificationOwners -Expected $plannedVerificationOwners)) { $errors.Add('verification-owner-missing'); $verificationPass = $false }
    if (-not (Test-ArcExactSet -Actual @(& $splitList $review['Planned Public Symbols']) -Expected $plannedSymbols) -or -not (Test-ArcExactSet -Actual @(& $splitList $review['Actual Public Symbols']) -Expected $sourceSymbols)) { $errors.Add('responsibility-public-symbol-mismatch'); $responsibilityPass = $false }
    if ($review['Planned Effects'] -cne $planned['External Effects'] -or $review['Actual Effects'] -cne ($sourceEffects -join '; ')) { $errors.Add('responsibility-external-effect-mismatch'); $responsibilityPass = $false }
    $evidenceItems = @($review['Source/Diff Evidence'] -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
    $expectedAnchors = @($sourceSymbols + $sourceVerificationOwners)
    foreach ($anchor in $expectedAnchors) {
      $expectedSource = "source:${FinalTreeSha}:$($actualSource.Path)#$anchor"
      $diffPath = if (-not [string]::IsNullOrWhiteSpace([string]$actualSource.RenameMapping)) { [string]$actualSource.RenameMapping } else { [string]$actualSource.Path }
      $expectedDiff = "diff:${TaskBaseSha}..${FinalTreeSha}:$diffPath#$anchor"
      $requiresDiff = [bool]$actualSource.IsChanged -or -not [string]::IsNullOrWhiteSpace([string]$actualSource.RenameMapping)
      $hasAnyDiffForUnchangedAnchor = -not $requiresDiff -and @($evidenceItems | Where-Object {
        $_ -cmatch ('^diff:[0-9a-f]{40}\.\.[0-9a-f]{40}:' + [regex]::Escape($diffPath) + '#' + [regex]::Escape($anchor) + '$')
      }).Count -gt 0
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
      $canonicalEvidence = ConvertTo-ArcCanonicalReviewEvidenceItem -EvidenceItem $evidence
      if ($canonicalEvidence -ceq '' -or $canonicalEvidence -cne $evidence) { $errors.Add('responsibility-evidence-missing'); $treePass = $false; $verificationPass = $false }
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
    foreach ($id in $deletedById.Keys) {
      $deleted = $deletedById[$id]
      $ownerSymbols = & $joinDeletionValues $deleted.OwnerSymbols
      $symbols = & $joinDeletionValues $deleted.Symbols
      $capabilities = & $joinDeletionValues $deleted.Capabilities
      $effects = & $joinDeletionValues $deleted.Effects
      $architectureAuthorities = & $joinDeletionValues $deleted.ArchitectureAuthorities
      $coLocationPolicies = & $joinDeletionValues $deleted.CoLocationPolicies
      $verificationOwners = & $joinDeletionValues $deleted.VerificationOwners
      $routeSymbols = & $joinDeletionValues $deleted.RouteSymbols
      $providers = & $joinDeletionValues $deleted.Providers
      $expectedDecisionPayload = "remove responsibility=$id; owner=$($deleted.Path)#$ownerSymbols; public-symbols=$symbols; capabilities=$capabilities; effects=$effects; architecture-authority=$architectureAuthorities; co-location-policy=$coLocationPolicies; verification-owners=$verificationOwners; routes=$routeSymbols; providers=$providers"
      $approvedRows = @($deviationRows | Where-Object {
        $decisionMatch = [regex]::Match($_['Resolved Decision'], '^resolved:DECISION-[A-Z0-9]+(?:-[A-Z0-9]+)*:\s(?<payload>.+)$')
        $_['Deviation Reference'] -cmatch '^DEV-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -and
        $_['Conflict Reference'] -cmatch '^CONFLICT-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -and
        $_['Tech Lead Approval'] -cmatch '^approval:TECH-LEAD-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -and
        -not [string]::IsNullOrWhiteSpace($_['Concern']) -and
        $decisionMatch.Success -and
        $decisionMatch.Groups['payload'].Value -ceq $expectedDecisionPayload
      })
      if ($approvedRows.Count -ne 1) {
        $errors.Add('responsibility-owner-extra')
        $treePass = $false; $responsibilityPass = $false
      }

      $changedRecord = @($changedPathRecords | Where-Object { $_.BasePath -ceq $deleted.Path }) | Select-Object -First 1
      $expectedFileKind = if ($null -eq $changedRecord) { '' } else { $changedRecord.FileKind }
      $hygienePath = if ($null -eq $changedRecord) { $deleted.Path } else { $changedRecord.Path }
      $expectedDeletionCheckpoint = if ($null -ne $changedRecord -and $changedRecord.Status -ceq 'R') {
        "source:${TaskBaseSha}:$($deleted.Path); diff:${TaskBaseSha}..${FinalTreeSha}:$($changedRecord.RenameMapping)"
      }
      else { "source:${TaskBaseSha}:$($deleted.Path); diff:${TaskBaseSha}..${FinalTreeSha}:$($deleted.Path)" }
      $hygieneRows = @($implementationProvenance.Rows | Where-Object {
        $editedSymbols = @($_[3] -split '[;,]' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
        $_[1] -ceq $hygienePath -and
        $_[2] -ceq $expectedFileKind -and
        $editedSymbols -ccontains $ownerSymbols -and
        $_[6] -ceq $expectedDeletionCheckpoint -and
        $_[7] -ceq $TaskBaseSha -and
        $_[8] -ceq $FinalTreeSha
      })
      if ($hygieneRows.Count -ne 1) {
        $errors.Add('responsibility-evidence-missing')
        $treePass = $false; $responsibilityPass = $false
      }

      if (-not $reviewById.ContainsKey($id)) {
        $errors.Add('responsibility-evidence-missing')
        $treePass = $false; $responsibilityPass = $false; $verificationPass = $false
        continue
      }
      $review = $reviewById[$id]
      if ($review['Planned Public Symbols'] -cne (@($deleted.Symbols | Select-Object -Unique) -join '; ') -or $review['Actual Public Symbols'] -cne 'removed') {
        $errors.Add('responsibility-public-symbol-mismatch')
        $responsibilityPass = $false
      }
      if ($review['Planned Effects'] -cne (@($deleted.Effects | Select-Object -Unique) -join '; ') -or $review['Actual Effects'] -cne 'removed') {
        $errors.Add('responsibility-external-effect-mismatch')
        $responsibilityPass = $false
      }
      $evidenceItems = @($review['Source/Diff Evidence'] -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
      $expectedEvidence = [Collections.Generic.List[string]]::new()
      $deletedDiffPath = if (-not [string]::IsNullOrWhiteSpace([string]$deleted.RenameMapping)) { [string]$deleted.RenameMapping } else { [string]$deleted.Path }
      foreach ($anchor in @($deleted.Symbols + $deleted.VerificationOwners | Select-Object -Unique)) {
        $expectedEvidence.Add("source:${TaskBaseSha}:$($deleted.Path)#$anchor")
        $expectedEvidence.Add("diff:${TaskBaseSha}..${FinalTreeSha}:$deletedDiffPath#$anchor")
      }
      if (-not (Test-ArcExactSet -Actual $evidenceItems -Expected $expectedEvidence.ToArray())) {
        $errors.Add('responsibility-evidence-missing')
        $treePass = $false; $verificationPass = $false
      }
      if ($review['Verdict'] -cne 'PASS') {
        $errors.Add('responsibility-waiver-forbidden')
        $responsibilityPass = $false
      }
    }
  }
  $plannedVerificationById = & $toMap $plannedVerifications 'Verification Owner ID' 'verification-owner-extra'
  $implementationVerificationById = & $toMap $implementationVerifications 'Verification Owner ID' 'verification-owner-extra'
  foreach ($id in $plannedVerificationById.Keys) {
    if (-not $implementationVerificationById.ContainsKey($id)) { $errors.Add('verification-owner-missing'); $verificationPass = $false; continue }
    $planned = $plannedVerificationById[$id]; $implementation = $implementationVerificationById[$id]
    foreach ($field in $verificationColumns) { if ($planned[$field] -cne $implementation[$field]) { $errors.Add('verification-production-binding-missing'); $verificationPass = $false; break } }
    if ($validVerdicts -cnotcontains $implementation['Verdict'] -or $implementation['Verdict'] -cne 'PASS') { $errors.Add('verification-disposition-invalid'); $verificationPass = $false }
    if (-not (Test-ArcPinnedVerificationOwnershipEvidence -VerificationRow $planned -SourceRoot $SourceRoot -FinalTreeSha $FinalTreeSha -ProductionOwnersById $inventoryById -Errors $errors)) { $verificationPass = $false }
  }
  foreach ($id in $implementationVerificationById.Keys) { if (-not $plannedVerificationById.ContainsKey($id)) { $errors.Add('verification-owner-extra'); $verificationPass = $false } }

  $architectureVerdict = $executableReviewState.Architecture
  $treeVerdict = $executableReviewState.Tree
  $responsibilityVerdict = $executableReviewState.Responsibility
  $verificationVerdict = $executableReviewState.Verification
  $derivedTree = if ($treePass) { 'PASS' } else { 'BLOCKED' }; $derivedResponsibility = if ($responsibilityPass) { 'PASS' } else { 'BLOCKED' }; $derivedVerification = if ($verificationPass) { 'PASS' } else { 'BLOCKED' }
  if ($treeVerdict -ne '' -and $treeVerdict -cne $derivedTree) { $errors.Add('responsibility-waiver-forbidden') }
  if ($responsibilityVerdict -ne '' -and $responsibilityVerdict -cne $derivedResponsibility) { $errors.Add('responsibility-waiver-forbidden') }
  if ($verificationVerdict -ne '' -and $verificationVerdict -cne $derivedVerification) { $errors.Add('responsibility-waiver-forbidden') }
  $derivedArchitecture = if ($treeVerdict -ceq 'PASS' -and $responsibilityVerdict -ceq 'PASS' -and $verificationVerdict -ceq 'PASS') { 'PASS' } else { 'BLOCKED' }
  if ($architectureVerdict -ne '' -and $architectureVerdict -cne $derivedArchitecture) { $errors.Add('responsibility-waiver-forbidden') }
  if (
    $reviewHandoff['Tree Conformance'] -cne $treeVerdict -or
    $reviewHandoff['Responsibility Conformance'] -cne $responsibilityVerdict -or
    $reviewHandoff['Verification Ownership'] -cne $verificationVerdict -or
    $reviewHandoff['Architecture Conformance State'] -cne $architectureVerdict
  ) { $errors.Add('responsibility-waiver-forbidden') }
  if ($derivedArchitecture -ceq 'BLOCKED' -or $executableReviewState.Overall -cne 'Approve' -or $executableReviewState.CriticalCount -ne 0 -or $executableReviewState.MajorCount -ne 0) { $errors.Add('responsibility-waiver-forbidden') }
  return @($errors | Select-Object -Unique)
}

function Test-ArcSelectedMigrationUnitAuthority {
  [CmdletBinding()]
  param([object]$SelectedUnit, [object]$PlanSelection)

  if ($null -eq $SelectedUnit -or $null -eq $PlanSelection) { return $false }
  $resolvedApprovalPattern = '^approval:(?![^\r\n]*(?:PENDING|TBD|UNKNOWN|PLACEHOLDER))[A-Z0-9]+(?:-[A-Z0-9]+)*$'
  $authority = [string]$PlanSelection['Authority']
  $authorityRevision = [string]$PlanSelection['Authority Revision']
  $traceIds = [string]$PlanSelection['Trace IDs']
  if (
    [string]$PlanSelection['Adapter Kind'] -cne 'migration-unit' -or
    [string]$PlanSelection['External ID'] -cnotmatch '^UNIT-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -or
    $authority -cnotmatch '^[A-Za-z0-9][A-Za-z0-9:._/-]*$' -or
    $authority -match '@' -or
    $authorityRevision -cnotmatch '^[1-9][0-9]*$' -or
    [string]$PlanSelection['Approval Reference'] -cnotmatch $resolvedApprovalPattern -or
    [string]::IsNullOrWhiteSpace($traceIds) -or
    $traceIds -match '<[^>]+>' -or
    [string]$SelectedUnit['Migration Unit ID'] -cne [string]$PlanSelection['External ID'] -or
    [string]$SelectedUnit['Plan Reference'] -cne "$authority@$authorityRevision" -or
    [string]$SelectedUnit['Approval Reference'] -cne [string]$PlanSelection['Approval Reference'] -or
    [string]$SelectedUnit['Mode Constraint'] -cne [string]$PlanSelection['Mode Constraint'] -or
    [string]$SelectedUnit['Trace IDs'] -cne $traceIds
  ) { return $false }

  $modeConstraint = [string]$SelectedUnit['Mode Constraint']
  if ($modeConstraint -ceq 'incremental/preserve-existing') {
    return (
      [string]$SelectedUnit['Bootstrap Scope'] -ceq 'not-required' -and
      [string]$SelectedUnit['Foundation Baseline ID'] -ceq 'not-applicable' -and
      [string]$SelectedUnit['Foundation Baseline Reference'] -ceq 'not-applicable' -and
      [string]$SelectedUnit['Foundation Baseline Approval Reference'] -ceq 'not-applicable' -and
      -not [string]::IsNullOrWhiteSpace([string]$SelectedUnit['Baseline Reference']) -and
      [string]$SelectedUnit['Baseline Reference'] -cne 'not-applicable' -and
      [string]$SelectedUnit['Baseline Reference'] -cnotmatch '<[^>]+>'
    )
  }
  if ($modeConstraint -ceq 'greenfield/design-new') {
    return (
      [string]$SelectedUnit['Bootstrap Scope'] -cin @('required', 'not-required') -and
      [string]$SelectedUnit['Foundation Baseline ID'] -cmatch '^FOUNDATION-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -and
      -not [string]::IsNullOrWhiteSpace([string]$SelectedUnit['Foundation Baseline Reference']) -and
      [string]$SelectedUnit['Foundation Baseline Reference'] -cne 'not-applicable' -and
      [string]$SelectedUnit['Foundation Baseline Reference'] -cnotmatch '<[^>]+>' -and
      [string]$SelectedUnit['Foundation Baseline Approval Reference'] -cmatch $resolvedApprovalPattern -and
      [string]$SelectedUnit['Baseline Reference'] -ceq 'not-applicable'
    )
  }
  return $false
}

function Test-ResponsibilityHandoff {
  [CmdletBinding()]
  param([string]$SourceText, [string]$TargetText, [string]$ContractText, [string]$ApprovedPlanText)

  $errors = [Collections.Generic.List[string]]::new()
  foreach ($error in @(Test-ArcResponsibilityStageVersion $ContractText 'HANDOFF')) { $errors.Add($error) }
  $columns = @(
    'Responsibility Contract Version', 'Tree Conformance', 'Responsibility Conformance',
    'Verification Ownership', 'Architecture Conformance State', 'Evidence References'
  )
  $provenanceColumns = @('Task / Unit', 'Task-base SHA', 'Final-tree SHA', 'Source Artifact')
  $scopeColumns = @('Run ID', 'Master Spec Reference', 'Master Spec ID', 'Master Spec Revision', 'Master Plan Reference', 'Master Plan ID', 'Master Plan Revision', 'Work Item ID')
  $selectedUnitColumns = @('Migration Unit ID', 'Plan Reference', 'Approval Reference', 'Mode Constraint', 'Bootstrap Scope', 'Foundation Baseline ID', 'Foundation Baseline Reference', 'Foundation Baseline Approval Reference', 'Baseline Reference', 'Trace IDs')

  $readArtifact = {
    param([string]$Text, [string]$Role)

    $artifact = [ordered]@{ Row = $null; Provenance = $null; Scope = $null; StepId = ''; AdapterKind = ''; ModeConstraint = ''; SelectedUnit = $null; ReviewState = $null }
    if ([string]::IsNullOrWhiteSpace($Text)) {
      $errors.Add('responsibility-owner-missing')
      return $artifact
    }
    if (@(Test-ArcDiscoveryResponsibilityContractVersion -DiscoveryText $Text).Count -ne 0) {
      $errors.Add('responsibility-contract-version-invalid')
      return $artifact
    }

    $tableErrors = [Collections.Generic.List[string]]::new()
    $handoffTable = @(Get-ArcStrictMarkdownTable -Text $Text -Heading 'Architecture Responsibility Handoff' -Columns $columns -Errors $tableErrors)
    $provenanceTable = @(Get-ArcStrictMarkdownTable -Text $Text -Heading 'Task Provenance' -Columns $provenanceColumns -Errors $tableErrors)
    $scopeTable = @(Get-ArcStrictMarkdownTable -Text $Text -Heading 'Master Scope Context' -Columns $scopeColumns -Errors $tableErrors)
    if ($tableErrors.Count -ne 0) {
      foreach ($tableError in $tableErrors) { $errors.Add($tableError) }
      return $artifact
    }
    if ($handoffTable.Count -ne 3) {
      $tableDiagnostic = if ($handoffTable.Count -gt 3) { 'responsibility-owner-extra' } else { 'responsibility-owner-missing' }
      $errors.Add($tableDiagnostic)
      return $artifact
    }
    if ($provenanceTable.Count -ne 3 -or $scopeTable.Count -ne 3) {
      $errors.Add('responsibility-evidence-missing')
      return $artifact
    }

    $row = @{}
    for ($index = 0; $index -lt $columns.Count; $index++) { $row[$columns[$index]] = [string]$handoffTable[2][$index] }
    $provenance = @{}
    for ($index = 0; $index -lt $provenanceColumns.Count; $index++) { $provenance[$provenanceColumns[$index]] = [string]$provenanceTable[2][$index] }
    $scope = @{}
    for ($index = 0; $index -lt $scopeColumns.Count; $index++) { $scope[$scopeColumns[$index]] = [string]$scopeTable[2][$index] }
    $artifact.Row = $row
    $artifact.Provenance = $provenance
    $artifact.Scope = $scope
    $frontMatter = Get-ArcBoundedFrontMatter -Text $Text
    $stepIds = @([regex]::Matches($frontMatter, '(?m)^step_id:\s*(?<value>[^\r\n]+)\s*$'))
    if ($stepIds.Count -ne 1) {
      $errors.Add('responsibility-evidence-missing')
      return $artifact
    }
    $artifact.StepId = $stepIds[0].Groups['value'].Value.Trim()
    $canonicalStepIds = @('11-ai-review', '12-verification-testing', '13-verify-parity', '14-verify-regression', '15-knowledge-base')
    if ($artifact.StepId -cnotin $canonicalStepIds) {
      $errors.Add('responsibility-evidence-missing')
      return $artifact
    }
    $topLevelKeys = @([regex]::Matches($frontMatter, '(?m)^(?!#)(?<key>[^ \t:\r\n][^:\r\n]*):') | ForEach-Object { $_.Groups['key'].Value })
    $producedAtMatches = @([regex]::Matches($frontMatter, '(?m)^produced_at:\s*(?<value>[^\r\n]+?)\s*$'))
    $parsedProducedAt = [datetime]::MinValue
    $producedAtValid = $producedAtMatches.Count -eq 1 -and [datetime]::TryParseExact(
      $producedAtMatches[0].Groups['value'].Value.Trim(),
      'yyyy-MM-dd',
      [Globalization.CultureInfo]::InvariantCulture,
      [Globalization.DateTimeStyles]::None,
      [ref]$parsedProducedAt
    )
    if (
      ($topLevelKeys -join '|') -cne 'step_id|status|result|approval_source|produced_at|responsibility_contract' -or
      @([regex]::Matches($frontMatter, '(?m)^status:\s*approved\s*$')).Count -ne 1 -or
      @([regex]::Matches($frontMatter, '(?m)^result:\s*complete\s*$')).Count -ne 1 -or
      @([regex]::Matches($frontMatter, '(?m)^approval_source:\s*human\s*$')).Count -ne 1 -or
      -not $producedAtValid
    ) { $errors.Add('responsibility-evidence-missing') }

    $visibleText = Get-ArcVisibleMarkdownText -Text $Text
    if ($artifact.StepId -ceq '11-ai-review') {
      $artifact.ReviewState = Get-ArcExecutableReviewState -ReviewText $Text -Errors $errors
      if (
        $artifact.ReviewState.Overall -cne 'Approve' -or
        $artifact.ReviewState.CriticalCount -ne 0 -or
        $artifact.ReviewState.MajorCount -ne 0
      ) { $errors.Add('responsibility-waiver-forbidden') }
    }
    $adapterMatches = @(Get-ArcStrictVisibleBulletMatches -Text $Text -Label 'Delivery Adapter Kind')
    $modeMatches = @(Get-ArcStrictVisibleBulletMatches -Text $Text -Label 'Delivery Adapter Mode Constraint')
    if ($adapterMatches.Count -ne 1 -or $adapterMatches[0].Groups['value'].Value.Trim() -cnotin @('migration-unit', 'task', 'story', 'package', 'phase', 'milestone', 'none')) {
      $errors.Add('responsibility-evidence-missing')
    }
    else { $artifact.AdapterKind = $adapterMatches[0].Groups['value'].Value.Trim() }
    if ($modeMatches.Count -ne 1 -or $modeMatches[0].Groups['value'].Value.Trim() -cnotin @('incremental/preserve-existing', 'greenfield/design-new')) {
      $errors.Add('responsibility-evidence-missing')
    }
    else { $artifact.ModeConstraint = $modeMatches[0].Groups['value'].Value.Trim() }
    if ($errors.Count -ne 0) { $artifact.Row = $null; return $artifact }
    $selectedHeadingCount = @(Get-ArcMarkdownH2HeadingMatches -Text $Text -Heading 'Selected Migration Unit').Count
    if ($artifact.AdapterKind -ceq 'migration-unit') {
      $selectedTable = @(Get-ArcStrictMarkdownTable -Text $Text -Heading 'Selected Migration Unit' -Columns $selectedUnitColumns -Errors $errors)
      if ($errors.Count -ne 0) { $artifact.Row = $null; return $artifact }
      if ($selectedTable.Count -ne 3) { $errors.Add('responsibility-evidence-missing'); $artifact.Row = $null; return $artifact }
      else {
        $selectedUnit = [ordered]@{}
        for ($index = 0; $index -lt $selectedUnitColumns.Count; $index++) { $selectedUnit[$selectedUnitColumns[$index]] = [string]$selectedTable[2][$index] }
        $artifact.SelectedUnit = $selectedUnit
      }
    }
    elseif ($artifact.AdapterKind -ne '' -and $selectedHeadingCount -ne 0) {
      $errors.Add('responsibility-evidence-missing')
    }

    if ($artifact.StepId -ceq '15-knowledge-base') {
      $envelopeHeadings = @('Master Scope Context', 'Task Provenance')
      if ($artifact.AdapterKind -ceq 'migration-unit') { $envelopeHeadings += 'Selected Migration Unit' }
      $envelopeHeadings += 'Architecture Responsibility Handoff'
      $h2Headings = @(
        [regex]::Matches($visibleText, '(?m)^##[ \t]+(?<heading>[^\r\n]+?)[ \t]*\r?$') |
          ForEach-Object { ($_.Groups['heading'].Value -replace '[ \t]+', ' ').Trim() }
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
      $scopeHeading = [regex]::Match($visibleText, (Get-ArcMarkdownH2HeadingPattern -Heading 'Master Scope Context'))
      $provenanceHeading = [regex]::Match($visibleText, (Get-ArcMarkdownH2HeadingPattern -Heading 'Task Provenance'))
      if ($adapterMatches.Count -ne 1 -or $modeMatches.Count -ne 1 -or -not $scopeHeading.Success -or -not $provenanceHeading.Success -or
        $adapterMatches[0].Index -le $scopeHeading.Index -or $adapterMatches[0].Index -ge $provenanceHeading.Index -or
        $adapterMatches[0].Index -ge $modeMatches[0].Index) {
        $errors.Add('responsibility-evidence-missing')
      }
      if ($modeMatches.Count -eq 1 -and ($modeMatches[0].Index -le $scopeHeading.Index -or $modeMatches[0].Index -ge $provenanceHeading.Index)) {
        $errors.Add('responsibility-evidence-missing')
      }
    }

    if ($row['Responsibility Contract Version'] -cne '1') { $errors.Add('responsibility-contract-version-invalid') }
    foreach ($field in @('Tree Conformance', 'Responsibility Conformance', 'Verification Ownership')) {
      if ($row[$field] -cnotin @('PASS', 'BLOCKED')) { $errors.Add('responsibility-waiver-forbidden') }
    }
    $derived = if (
      $row['Tree Conformance'] -ceq 'PASS' -and
      $row['Responsibility Conformance'] -ceq 'PASS' -and
      $row['Verification Ownership'] -ceq 'PASS'
    ) { 'PASS' } else { 'BLOCKED' }
    if ($row['Architecture Conformance State'] -cne $derived) { $errors.Add('responsibility-waiver-forbidden') }
    if ($artifact.StepId -ceq '11-ai-review') {
      if (
        $null -eq $artifact.ReviewState -or
        $artifact.ReviewState.Tree -cne $row['Tree Conformance'] -or
        $artifact.ReviewState.Responsibility -cne $row['Responsibility Conformance'] -or
        $artifact.ReviewState.Verification -cne $row['Verification Ownership'] -or
        $artifact.ReviewState.Architecture -cne $row['Architecture Conformance State'] -or
        $derived -cne 'PASS'
      ) { $errors.Add('responsibility-waiver-forbidden') }
    }
    if ($provenance['Task-base SHA'] -cnotmatch '^[0-9a-f]{40}$' -or $provenance['Final-tree SHA'] -cnotmatch '^[0-9a-f]{40}$') {
      $errors.Add('responsibility-evidence-missing')
    }
    foreach ($field in $provenanceColumns) {
      if ([string]::IsNullOrWhiteSpace($provenance[$field]) -or $provenance[$field] -match '<[^>]+>') {
        $errors.Add('responsibility-evidence-missing')
      }
    }
    if (
      $scope['Run ID'] -cnotmatch '^RUN-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -or
      $scope['Master Spec Reference'] -cnotmatch '^(?:[A-Za-z0-9_.-]+/)*master-spec\.md$' -or
      $scope['Master Spec ID'] -cnotmatch '^SPEC-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -or
      $scope['Master Spec Revision'] -cnotmatch '^[1-9][0-9]*$' -or
      $scope['Master Plan Reference'] -cnotmatch '^(?:[A-Za-z0-9_.-]+/)*master-plan\.md$' -or
      $scope['Master Plan ID'] -cnotmatch '^PLAN-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -or
      $scope['Master Plan Revision'] -cnotmatch '^[1-9][0-9]*$' -or
      $scope['Work Item ID'] -cnotmatch '^WORK-[A-Z0-9]+(?:-[A-Z0-9]+)*$'
    ) { $errors.Add('responsibility-evidence-missing') }
    $expectedEvidence = "source-diff:$($provenance['Task-base SHA'])..$($provenance['Final-tree SHA'])#$($scope['Work Item ID'])"
    if ($row['Evidence References'] -cne $expectedEvidence) { $errors.Add('responsibility-evidence-missing') }

    $expectedOwnSourceArtifact = @{
      '11-ai-review' = 'implementation-report.md'
      '12-verification-testing' = 'review-report.md'
      '13-verify-parity' = 'verification-report.md'
      '14-verify-regression' = '13-parity-report.md'
    }[$artifact.StepId]
    if ($artifact.StepId -cne '15-knowledge-base' -and ([string]::IsNullOrWhiteSpace($expectedOwnSourceArtifact) -or $provenance['Source Artifact'] -cne $expectedOwnSourceArtifact)) {
      $errors.Add('responsibility-evidence-missing')
    }
    if ($artifact.StepId -ceq '15-knowledge-base' -and $provenance['Source Artifact'] -cnotin @('13-parity-report.md', '14-regression-report.md')) {
      $errors.Add('responsibility-evidence-missing')
    }
    return $artifact
  }

  $source = & $readArtifact $SourceText 'source'
  $target = & $readArtifact $TargetText 'target'
  if ($null -eq $source.Row -or $null -eq $target.Row) { return @($errors | Select-Object -Unique) }
  if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }

  $planSelectionColumns = @('Work Item ID', 'Adapter Kind', 'External ID', 'Authority', 'Authority Revision', 'Approval Reference', 'Parent Selector', 'Acceptance', 'Trace IDs', 'Mode Constraint', 'Design Revision', 'Parent Work Item ID', 'Decomposition Decision Reference')
  $planFrontMatter = if ([string]::IsNullOrWhiteSpace($ApprovedPlanText)) { '' } else { Get-ArcBoundedFrontMatter -Text $ApprovedPlanText }
  [object[]]$planSelections = @()
  if (-not [string]::IsNullOrWhiteSpace($ApprovedPlanText)) {
    $planSelections = @(Get-ArcStrictMarkdownTable -Text $ApprovedPlanText -Heading 'Delivery Adapter Selection' -Columns $planSelectionColumns -Errors $errors)
  }
  $workItemColumns = @('Work Item ID', 'Title', 'Required', 'Dependencies', 'Plan Order', 'Acceptance', 'Trace IDs', 'Delivery Adapter', 'Status', 'Latest Attempt', 'Terminal Evidence', 'Approval Reference')
  [object[]]$workItemTable = @()
  if (-not [string]::IsNullOrWhiteSpace($ApprovedPlanText)) {
    $workItemTable = @(Get-ArcStrictMarkdownTable -Text $ApprovedPlanText -Heading 'Work Items' -Columns $workItemColumns -Errors $errors)
  }
  if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }
  $planIdMatches = @([regex]::Matches($planFrontMatter, '(?m)^master_plan_id:\s*(?<value>PLAN-[A-Z0-9]+(?:-[A-Z0-9]+)*)\s*$'))
  $planSpecIdMatches = @([regex]::Matches($planFrontMatter, '(?m)^master_spec_id:\s*(?<value>SPEC-[A-Z0-9]+(?:-[A-Z0-9]+)*)\s*$'))
  $planSpecRevisionMatches = @([regex]::Matches($planFrontMatter, '(?m)^master_spec_revision:\s*(?<value>[1-9][0-9]*)\s*$'))
  $planRevisionMatches = @([regex]::Matches($planFrontMatter, '(?m)^revision:\s*(?<value>[1-9][0-9]*)\s*$'))
  $approvedModeConstraint = ''
  if (
    @([regex]::Matches($planFrontMatter, '(?m)^artifact_type:\s*migration-master-plan\s*$')).Count -ne 1 -or
    @([regex]::Matches($planFrontMatter, '(?m)^status:\s*approved\s*$')).Count -ne 1 -or
    $planIdMatches.Count -ne 1 -or $planSpecIdMatches.Count -ne 1 -or $planSpecRevisionMatches.Count -ne 1 -or $planRevisionMatches.Count -ne 1 -or
    $planSelections.Count -lt 3 -or $workItemTable.Count -lt 3 -or
    $planIdMatches[0].Groups['value'].Value -cne $source.Scope['Master Plan ID'] -or
    $planSpecIdMatches[0].Groups['value'].Value -cne $source.Scope['Master Spec ID'] -or
    $planSpecRevisionMatches[0].Groups['value'].Value -cne $source.Scope['Master Spec Revision'] -or
    $planRevisionMatches[0].Groups['value'].Value -cne $source.Scope['Master Plan Revision']
  ) {
    $errors.Add('responsibility-evidence-missing')
  }
  else {
    $allSelectionRows = @($planSelections | Select-Object -Skip 2)
    $allWorkItemRows = @($workItemTable | Select-Object -Skip 2)
    $selectionWorkItemIds = @($allSelectionRows | ForEach-Object { [string]$_[0] })
    $planWorkItemIds = @($allWorkItemRows | ForEach-Object { [string]$_[0] })
    $selectionWorkItemSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $planWorkItemSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($workItemId in $selectionWorkItemIds) { [void]$selectionWorkItemSet.Add($workItemId) }
    foreach ($workItemId in $planWorkItemIds) { [void]$planWorkItemSet.Add($workItemId) }
    if (
      $selectionWorkItemSet.Count -ne $selectionWorkItemIds.Count -or
      $planWorkItemSet.Count -ne $planWorkItemIds.Count -or
      -not $selectionWorkItemSet.SetEquals($planWorkItemSet)
    ) { $errors.Add('responsibility-evidence-missing') }
    if (($selectionWorkItemIds -join '|') -cne ($planWorkItemIds -join '|')) { $errors.Add('responsibility-evidence-missing') }
    $wholePlanMode = ''
    $wholePlanDesignRevision = ''
    $workItemsById = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
    foreach ($candidateWorkItem in $allWorkItemRows) {
      if (-not $workItemsById.ContainsKey([string]$candidateWorkItem[0])) { $workItemsById.Add([string]$candidateWorkItem[0], $candidateWorkItem) }
    }
    $selectionsByWorkItem = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
    $selectionIndexByWorkItem = [Collections.Generic.Dictionary[string, int]]::new([StringComparer]::Ordinal)
    $selectorIdentityOwners = [Collections.Generic.Dictionary[string, string]]::new([StringComparer]::Ordinal)
    $resolvedApprovalPattern = '^approval:(?![^\r\n]*(?:PENDING|TBD|UNKNOWN|PLACEHOLDER))[A-Z0-9]+(?:-[A-Z0-9]+)*$'
    for ($selectionIndex = 0; $selectionIndex -lt $allSelectionRows.Count; $selectionIndex++) {
      $candidateSelection = $allSelectionRows[$selectionIndex]
      $candidateWorkItemId = [string]$candidateSelection[0]
      if (-not $selectionsByWorkItem.ContainsKey($candidateWorkItemId)) {
        $selectionsByWorkItem.Add($candidateWorkItemId, $candidateSelection)
        $selectionIndexByWorkItem.Add($candidateWorkItemId, $selectionIndex)
      }
      if ([string]$candidateSelection[1] -cne 'none') {
        $selectorIdentity = [string]$candidateSelection[2]
        if ($selectorIdentityOwners.ContainsKey($selectorIdentity)) { $errors.Add('responsibility-evidence-missing') }
        else { $selectorIdentityOwners.Add($selectorIdentity, $candidateWorkItemId) }
      }
    }
    foreach ($candidateSelection in $allSelectionRows) {
      $candidateWorkItemId = [string]$candidateSelection[0]
      $candidateMode = [string]$candidateSelection[9]
      $candidateDesignRevision = [string]$candidateSelection[10]
      $candidateParent = [string]$candidateSelection[11]
      $candidateDecision = [string]$candidateSelection[12]
      $candidateAdapterKind = [string]$candidateSelection[1]
      $candidateSelectorAuthorityValid = if ($candidateAdapterKind -ceq 'none') {
        @($candidateSelection[2..6] | Where-Object { [string]$_ -cne 'not-applicable' }).Count -eq 0
      }
      else {
        $candidateAdapterKind -cin @('migration-unit', 'task', 'story', 'package', 'phase', 'milestone') -and
        [string]$candidateSelection[2] -cmatch '^[A-Za-z0-9][A-Za-z0-9:._/-]*$' -and
        [string]$candidateSelection[2] -notmatch '^(?:not-applicable|pending|unknown|placeholder|<[^>]+>)$' -and
        [string]$candidateSelection[3] -cmatch '^[A-Za-z0-9][A-Za-z0-9:._/-]*$' -and
        [string]$candidateSelection[3] -notmatch '^(?:not-applicable|pending|unknown|placeholder|<[^>]+>)$' -and
        [string]$candidateSelection[4] -cmatch '^[1-9][0-9]*$' -and
        [string]$candidateSelection[5] -cmatch $resolvedApprovalPattern -and
        [string]$candidateSelection[6] -cmatch '^(?:not-applicable|[A-Za-z0-9][A-Za-z0-9:._/-]*)$'
      }
      $candidateImmutableValid = $candidateSelectorAuthorityValid -and
        $candidateMode -cin @('incremental/preserve-existing', 'greenfield/design-new') -and
        ($candidateDesignRevision -ceq 'pending-step07' -or $candidateDesignRevision -cmatch '^DESIGN-[A-Z0-9]+(?:-[A-Z0-9]+)*@[1-9][0-9]*$') -and
        (
          ($candidateParent -ceq 'not-applicable' -and $candidateDecision -ceq 'not-applicable') -or
          ($candidateParent -cmatch '^WORK-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -and $candidateParent -cne $candidateWorkItemId -and $planWorkItemSet.Contains($candidateParent) -and $candidateDecision -cmatch '^DEC-[A-Z0-9]+(?:-[A-Z0-9]+)*$')
        )
      if ($wholePlanMode -ceq '') { $wholePlanMode = $candidateMode } elseif ($candidateMode -cne $wholePlanMode) { $candidateImmutableValid = $false }
      if ($wholePlanDesignRevision -ceq '') { $wholePlanDesignRevision = $candidateDesignRevision } elseif ($candidateDesignRevision -cne $wholePlanDesignRevision) { $candidateImmutableValid = $false }
      $candidateParentSelector = [string]$candidateSelection[6]
      if ($candidateParent -ceq 'not-applicable' -and $candidateDecision -ceq 'not-applicable') {
        if ($candidateParentSelector -cne 'not-applicable') { $candidateImmutableValid = $false }
      }
      elseif (-not $selectionsByWorkItem.ContainsKey($candidateParent)) { $candidateImmutableValid = $false }
      else {
        $parentSelection = $selectionsByWorkItem[$candidateParent]
        $expectedParentSelector = if ([string]$candidateSelection[1] -ceq 'none' -or [string]$parentSelection[1] -ceq 'none') { 'not-applicable' } else { [string]$parentSelection[2] }
        if ($candidateParentSelector -cne $expectedParentSelector -or [int]$selectionIndexByWorkItem[$candidateParent] -ge [int]$selectionIndexByWorkItem[$candidateWorkItemId]) { $candidateImmutableValid = $false }
      }
      if (-not $workItemsById.ContainsKey($candidateWorkItemId)) { $candidateImmutableValid = $false }
      else {
        $candidateWorkItem = $workItemsById[$candidateWorkItemId]
        $candidateExpectedAdapter = if ([string]$candidateSelection[1] -ceq 'none') { 'none' } else { "$([string]$candidateSelection[1]):$([string]$candidateSelection[2])" }
        if ([string]$candidateWorkItem[5] -cne [string]$candidateSelection[7] -or [string]$candidateWorkItem[6] -cne [string]$candidateSelection[8] -or ([string]$candidateWorkItem[7] -cne $candidateExpectedAdapter -and -not ([string]$candidateSelection[1] -ceq 'none' -and [string]$candidateWorkItem[7] -cmatch '^generic:[A-Za-z0-9][A-Za-z0-9._-]*$'))) {
          $candidateImmutableValid = $false
        }
      }
      if (-not $candidateImmutableValid) { $errors.Add('responsibility-evidence-missing') }
    }
    $selectionRows = @($allSelectionRows | Where-Object { $_[0] -ceq $source.Scope['Work Item ID'] })
    $workItemRows = @($allWorkItemRows | Where-Object { $_[0] -ceq $source.Scope['Work Item ID'] })
    if ($selectionRows.Count -ne 1 -or $workItemRows.Count -ne 1) { $errors.Add('responsibility-evidence-missing') }
    else {
      $selection = [ordered]@{}
      for ($index = 0; $index -lt $planSelectionColumns.Count; $index++) { $selection[$planSelectionColumns[$index]] = [string]$selectionRows[0][$index] }
      $approvedModeConstraint = $selection['Mode Constraint']
      $workItem = [ordered]@{}
      for ($index = 0; $index -lt $workItemColumns.Count; $index++) { $workItem[$workItemColumns[$index]] = [string]$workItemRows[0][$index] }
      $selectorAuthorityValid = if ($selection['Adapter Kind'] -ceq 'none') {
        @(@('External ID', 'Authority', 'Authority Revision', 'Approval Reference', 'Parent Selector') | Where-Object { $selection[$_] -cne 'not-applicable' }).Count -eq 0
      }
      else {
        $selection['Adapter Kind'] -cin @('migration-unit', 'task', 'story', 'package', 'phase', 'milestone') -and
        $selection['External ID'] -cmatch '^[A-Za-z0-9][A-Za-z0-9:._/-]*$' -and
        $selection['External ID'] -notmatch '^(?:not-applicable|pending|unknown|placeholder|<[^>]+>)$' -and
        $selection['Authority'] -cmatch '^[A-Za-z0-9][A-Za-z0-9:._/-]*$' -and
        $selection['Authority'] -notmatch '^(?:not-applicable|pending|unknown|placeholder|<[^>]+>)$' -and
        $selection['Authority Revision'] -cmatch '^[1-9][0-9]*$' -and
        $selection['Approval Reference'] -cmatch $resolvedApprovalPattern
      }
      $workItemAdapterValid = if ($selection['Adapter Kind'] -ceq 'none') {
        $workItem['Delivery Adapter'] -ceq 'none' -or $workItem['Delivery Adapter'] -cmatch '^generic:[A-Za-z0-9][A-Za-z0-9._-]*$'
      }
      else {
        $workItem['Delivery Adapter'] -ceq "$($selection['Adapter Kind']):$($selection['External ID'])"
      }
      if (
        $selection['Adapter Kind'] -cne $source.AdapterKind -or $selection['Adapter Kind'] -cne $target.AdapterKind -or
        $selection['Mode Constraint'] -cne $source.ModeConstraint -or $selection['Mode Constraint'] -cne $target.ModeConstraint -or
        $selection['Adapter Kind'] -cnotin @('migration-unit', 'task', 'story', 'package', 'phase', 'milestone', 'none') -or
        -not $selectorAuthorityValid -or
        $selection['Design Revision'] -cnotmatch '^DESIGN-[A-Z0-9]+(?:-[A-Z0-9]+)*@[1-9][0-9]*$' -or
        -not $workItemAdapterValid -or
        $workItem['Acceptance'] -cne $selection['Acceptance'] -or
        $workItem['Trace IDs'] -cne $selection['Trace IDs'] -or
        $workItem['Approval Reference'] -cnotmatch $resolvedApprovalPattern
      ) { $errors.Add('responsibility-evidence-missing') }
      if ($selection['Adapter Kind'] -ceq 'migration-unit') {
        foreach ($artifact in @($source, $target)) {
          if ($null -eq $artifact.SelectedUnit -or
            -not (Test-ArcSelectedMigrationUnitAuthority -SelectedUnit $artifact.SelectedUnit -PlanSelection $selection) -or
            $artifact.SelectedUnit['Migration Unit ID'] -cne $selection['External ID'] -or
            $artifact.SelectedUnit['Plan Reference'] -cne "$($selection['Authority'])@$($selection['Authority Revision'])" -or
            $artifact.SelectedUnit['Approval Reference'] -cne $selection['Approval Reference'] -or
            $artifact.SelectedUnit['Mode Constraint'] -cne $selection['Mode Constraint'] -or
            $artifact.SelectedUnit['Trace IDs'] -cne $selection['Trace IDs']) {
            $errors.Add('responsibility-evidence-missing')
          }
        }
      }
      $expectedAssuranceIdentity = if ($selection['Adapter Kind'] -ceq 'migration-unit') { $selection['External ID'] } else { $source.Scope['Work Item ID'] }
      if ($source.Provenance['Task / Unit'] -cne $expectedAssuranceIdentity -or $target.Provenance['Task / Unit'] -cne $expectedAssuranceIdentity) {
        $errors.Add('responsibility-evidence-missing')
      }
    }
  }

  $allowedNextSteps = @{
    '11-ai-review' = @('12-verification-testing')
    '12-verification-testing' = @('13-verify-parity')
    '13-verify-parity' = if ($approvedModeConstraint -ceq 'greenfield/design-new') { @('15-knowledge-base') } elseif ($approvedModeConstraint -ceq 'incremental/preserve-existing') { @('14-verify-regression') } else { @() }
    '14-verify-regression' = if ($approvedModeConstraint -ceq 'incremental/preserve-existing') { @('15-knowledge-base') } else { @() }
  }
  if ($null -eq $allowedNextSteps[$source.StepId] -or $target.StepId -cnotin $allowedNextSteps[$source.StepId]) {
    $errors.Add('responsibility-evidence-missing')
  }
  foreach ($field in @('Task / Unit', 'Task-base SHA', 'Final-tree SHA')) {
    if ($source.Provenance[$field] -cne $target.Provenance[$field]) { $errors.Add('responsibility-evidence-missing') }
  }
  foreach ($field in $scopeColumns) {
    if ($source.Scope[$field] -cne $target.Scope[$field]) { $errors.Add('responsibility-evidence-missing') }
  }
  if ($source.AdapterKind -cne $target.AdapterKind -or $source.ModeConstraint -cne $target.ModeConstraint) { $errors.Add('responsibility-evidence-missing') }
  if ($source.AdapterKind -ceq 'migration-unit' -and $null -ne $source.SelectedUnit -and $null -ne $target.SelectedUnit) {
    foreach ($field in $selectedUnitColumns) {
      if ($source.SelectedUnit[$field] -cne $target.SelectedUnit[$field]) { $errors.Add('responsibility-evidence-missing'); break }
    }
  }
  $expectedSourceArtifact = @{
    '11-ai-review' = 'review-report.md'
    '12-verification-testing' = 'verification-report.md'
    '13-verify-parity' = '13-parity-report.md'
    '14-verify-regression' = '14-regression-report.md'
  }[$source.StepId]
  if ([string]::IsNullOrWhiteSpace($expectedSourceArtifact) -or $target.Provenance['Source Artifact'] -cne $expectedSourceArtifact) {
    $errors.Add('responsibility-evidence-missing')
  }

  $handoffFields = @(
    'Responsibility Contract Version', 'Tree Conformance', 'Responsibility Conformance',
    'Verification Ownership', 'Architecture Conformance State', 'Evidence References'
  )
  $preserved = $true
  foreach ($field in $handoffFields) {
    if ($source.Row[$field] -cne $target.Row[$field]) { $preserved = $false; break }
  }
  if (-not $preserved) {
    if ($TargetText -match '(?m)^approval_source:\s*auto-waive\s*$') {
      $errors.Add('responsibility-waiver-forbidden')
    }
    else {
      $errors.Add('responsibility-evidence-missing')
    }
  }
  return @($errors | Select-Object -Unique)
}

function Get-ArcMigrationStageVerdict {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][ValidateSet('verification', 'parity', 'regression', 'knowledge-base', 'gerrit')][string]$Role,
    [string]$Text,
    [ValidateSet('', 'incremental', 'greenfield')][string]$ExpectedMode = '',
    [string]$ExpectedMigrationUnitId = ''
  )

  $state = [ordered]@{
    Valid = $false
    Verdict = ''
    ParityVerdict = ''
    RegressionApplicability = ''
    RegressionVerdict = ''
    DerivedVerdict = ''
    Evidence = ''
    WorkflowType = ''
    Mode = ''
    MigrationUnitId = ''
    TerminalArtifact = ''
    CompletionVerdict = ''
    SummaryWorkflowType = ''
    SummaryTerminalArtifact = ''
    SummaryCompletionVerdict = ''
  }
  if ([string]::IsNullOrWhiteSpace($Text)) { return [pscustomobject]$state }

  $isConcreteEvidence = {
    param([string]$Value)
    return (
      -not [string]::IsNullOrWhiteSpace($Value) -and
      $Value -notmatch '<[^>]+>' -and
      $Value -notmatch '(?i)^(?:none|not-applicable|pending|unknown|placeholder|tbd|n/?a)$' -and
      $Value -match '[A-Za-z0-9]'
    )
  }

  if ($Role -ceq 'verification') {
    $heading = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('S+G6v3QgbHXhuq1u'))
    if (@(Get-ArcMarkdownH2HeadingMatches -Text $Text -Heading $heading).Count -ne 1) { return [pscustomobject]$state }
    $visibleText = Get-ArcVisibleMarkdownText -Text $Text
    $sectionPattern = '(?ms)^##[ \t]+' + [regex]::Escape($heading) + '[ \t]*\r?\n(?<body>.*?)(?=^##[ \t]+|\z)'
    $sectionMatches = @([regex]::Matches($visibleText, $sectionPattern))
    if ($sectionMatches.Count -ne 1) { return [pscustomobject]$state }
    $bodyLines = @(
      $sectionMatches[0].Groups['body'].Value -split '\r?\n' |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne '' }
    )
    if ($bodyLines.Count -ne 1) { return [pscustomobject]$state }
    $verdictMatch = [regex]::Match($bodyLines[0], '^(?<verdict>PASS|FAIL|BLOCKED|WAIVED)[ \t]+\u2014[ \t]+(?<evidence>.+?)\s*$')
    if (-not $verdictMatch.Success) { return [pscustomobject]$state }
    $state.Verdict = $verdictMatch.Groups['verdict'].Value
    $state.Evidence = $verdictMatch.Groups['evidence'].Value.Trim()
    $state.Valid = $state.Verdict -ceq 'PASS' -and (& $isConcreteEvidence $state.Evidence)
    return [pscustomobject]$state
  }

  $tableErrors = [Collections.Generic.List[string]]::new()
  if ($Role -ceq 'parity') {
    $table = @(Get-ArcStrictMarkdownTable -Text $Text -Heading 'Parity Verdict' -Columns @('Parity Verdict', 'Evidence Reference') -Errors $tableErrors)
    $scenarioHeading = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('S+G7i2NoIGLhuqNu'))
    $scenarioColumns = @('Scenario', 'Baseline', 'Actual', 'Verdict')
    $scenarioTable = @(Get-ArcStrictMarkdownTable -Text $Text -Heading $scenarioHeading -Columns $scenarioColumns -Errors $tableErrors)
    if ($tableErrors.Count -ne 0 -or $table.Count -ne 3 -or $scenarioTable.Count -lt 3) { return [pscustomobject]$state }
    $state.ParityVerdict = [string]$table[2][0]
    $state.Verdict = $state.ParityVerdict
    $state.Evidence = [string]$table[2][1]
    $scenarioVerdicts = [Collections.Generic.List[string]]::new()
    foreach ($scenarioRow in @($scenarioTable | Select-Object -Skip 2)) {
      if (
        -not (& $isConcreteEvidence ([string]$scenarioRow[0])) -or
        -not (& $isConcreteEvidence ([string]$scenarioRow[1])) -or
        -not (& $isConcreteEvidence ([string]$scenarioRow[2])) -or
        [string]$scenarioRow[3] -cnotin @('pass', 'fail', 'blocked')
      ) { return [pscustomobject]$state }
      $scenarioVerdicts.Add([string]$scenarioRow[3])
    }
    $state.DerivedVerdict = if ($scenarioVerdicts -ccontains 'blocked') { 'blocked' } elseif ($scenarioVerdicts -ccontains 'fail') { 'fail' } else { 'pass' }
    $state.Valid = (
      $state.ParityVerdict -ceq $state.DerivedVerdict -and
      $state.DerivedVerdict -ceq 'pass' -and
      (& $isConcreteEvidence $state.Evidence)
    )
    return [pscustomobject]$state
  }

  if ($Role -ceq 'regression') {
    $heading = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('S+G6v3QgbHXhuq1uIHjDoWMgbWluaCBtaWdyYXRpb24='))
    $columns = @('Parity Verdict', 'Regression Applicability', 'Regression Verdict', 'Evidence Reference')
    $table = @(Get-ArcStrictMarkdownTable -Text $Text -Heading $heading -Columns $columns -Errors $tableErrors)
    $scenarioHeading = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('S+G7i2NoIGLhuqNu'))
    $scenarioColumns = @('Scenario', 'Baseline', 'Actual', 'Delta Class', 'Waiver Reference', 'Trace IDs', 'Verdict')
    $scenarioTable = @(Get-ArcStrictMarkdownTable -Text $Text -Heading $scenarioHeading -Columns $scenarioColumns -Errors $tableErrors)
    if ($tableErrors.Count -ne 0 -or $table.Count -ne 3 -or $scenarioTable.Count -lt 3) { return [pscustomobject]$state }
    $state.ParityVerdict = [string]$table[2][0]
    $state.RegressionApplicability = [string]$table[2][1]
    $state.RegressionVerdict = [string]$table[2][2]
    $state.Verdict = $state.RegressionVerdict
    $state.Evidence = [string]$table[2][3]
    $scenarioVerdicts = [Collections.Generic.List[string]]::new()
    foreach ($scenarioRow in @($scenarioTable | Select-Object -Skip 2)) {
      $waiverReference = [string]$scenarioRow[4]
      if (
        -not (& $isConcreteEvidence ([string]$scenarioRow[0])) -or
        -not (& $isConcreteEvidence ([string]$scenarioRow[1])) -or
        -not (& $isConcreteEvidence ([string]$scenarioRow[2])) -or
        -not (& $isConcreteEvidence ([string]$scenarioRow[3])) -or
        ($waiverReference -cne 'not-applicable' -and -not (& $isConcreteEvidence $waiverReference)) -or
        -not (& $isConcreteEvidence ([string]$scenarioRow[5])) -or
        [string]$scenarioRow[6] -cnotin @('pass', 'fail', 'blocked')
      ) { return [pscustomobject]$state }
      $scenarioVerdicts.Add([string]$scenarioRow[6])
    }
    $state.DerivedVerdict = if ($scenarioVerdicts -ccontains 'blocked') { 'blocked' } elseif ($scenarioVerdicts -ccontains 'fail') { 'fail' } else { 'pass' }
    $state.Valid = (
      $state.ParityVerdict -ceq 'pass' -and
      $state.RegressionApplicability -ceq 'required' -and
      $state.RegressionVerdict -ceq $state.DerivedVerdict -and
      $state.DerivedVerdict -ceq 'pass' -and
      (& $isConcreteEvidence $state.Evidence)
    )
    return [pscustomobject]$state
  }

  if ($Role -ceq 'knowledge-base') {
    $summaryHeading = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('VMOzbSB04bqvdCBydW4='))
    $terminalHeading = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('WMOhYyBtaW5oIMSR4bqndSBjdeG7kWk='))
    if (@(Get-ArcMarkdownH2HeadingMatches -Text $Text -Heading $summaryHeading).Count -ne 1) { return [pscustomobject]$state }
    $visibleText = Get-ArcVisibleMarkdownText -Text $Text
    $summaryWorkflowMatches = @([regex]::Matches($visibleText, '(?m)^[ \t]*-[ \t]*Workflow Type:[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$'))
    $summaryArtifactMatches = @([regex]::Matches($visibleText, '(?m)^[ \t]*-[ \t]*Terminal Input Artifact:[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$'))
    $summaryCompletionMatches = @([regex]::Matches($visibleText, '(?m)^[ \t]*-[ \t]*Completion Verdict:[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$'))
    $columns = @('Workflow Type', 'Mode', 'Migration Unit ID', 'Terminal Verification Artifact', 'Verification Verdict', 'Completion Verdict')
    $table = @(Get-ArcStrictMarkdownTable -Text $Text -Heading $terminalHeading -Columns $columns -Errors $tableErrors)
    if (
      $tableErrors.Count -ne 0 -or $table.Count -ne 3 -or
      $summaryWorkflowMatches.Count -ne 1 -or $summaryArtifactMatches.Count -ne 1 -or $summaryCompletionMatches.Count -ne 1
    ) { return [pscustomobject]$state }
    $state.WorkflowType = [string]$table[2][0]
    $state.Mode = [string]$table[2][1]
    $state.MigrationUnitId = [string]$table[2][2]
    $state.TerminalArtifact = [string]$table[2][3]
    $state.Verdict = [string]$table[2][4]
    $state.CompletionVerdict = [string]$table[2][5]
    $state.SummaryWorkflowType = $summaryWorkflowMatches[0].Groups['value'].Value.Trim()
    $state.SummaryTerminalArtifact = $summaryArtifactMatches[0].Groups['value'].Value.Trim()
    $state.SummaryCompletionVerdict = $summaryCompletionMatches[0].Groups['value'].Value.Trim()
    $expectedTerminalArtifact = if ($ExpectedMode -ceq 'greenfield') { '13-parity-report.md' } elseif ($ExpectedMode -ceq 'incremental') { '14-regression-report.md' } else { '' }
    $state.Valid = (
      $state.WorkflowType -ceq 'migration' -and
      $state.Mode -ceq $ExpectedMode -and
      $state.MigrationUnitId -ceq $ExpectedMigrationUnitId -and
      $state.TerminalArtifact -ceq $expectedTerminalArtifact -and
      (& $isConcreteEvidence $state.TerminalArtifact) -and
      $state.Verdict -ceq 'PASS' -and
      $state.CompletionVerdict -ceq 'complete' -and
      $state.SummaryWorkflowType -ceq $state.WorkflowType -and
      $state.SummaryTerminalArtifact -ceq $state.TerminalArtifact -and
      $state.SummaryCompletionVerdict -ceq $state.CompletionVerdict
    )
    return [pscustomobject]$state
  }

  $columns = @('Parity Verdict', 'Regression Applicability', 'Regression Verdict', 'Evidence Reference')
  $table = @(Get-ArcStrictMarkdownTable -Text $Text -Heading 'Migration Verification Verdicts' -Columns $columns -Errors $tableErrors)
  if ($tableErrors.Count -ne 0 -or $table.Count -ne 3) { return [pscustomobject]$state }
  $state.ParityVerdict = [string]$table[2][0]
  $state.RegressionApplicability = [string]$table[2][1]
  $state.RegressionVerdict = [string]$table[2][2]
  $state.Evidence = [string]$table[2][3]
  $modePairValid = if ($ExpectedMode -ceq 'greenfield') {
    $state.RegressionApplicability -ceq 'not-applicable' -and $state.RegressionVerdict -ceq 'not-applicable'
  }
  elseif ($ExpectedMode -ceq 'incremental') {
    $state.RegressionApplicability -ceq 'required' -and $state.RegressionVerdict -ceq 'pass'
  }
  else { $false }
  $state.Verdict = if ($ExpectedMode -ceq 'incremental') { $state.RegressionVerdict } else { $state.ParityVerdict }
  $state.Valid = $state.ParityVerdict -ceq 'pass' -and $modePairValid -and (& $isConcreteEvidence $state.Evidence)
  return [pscustomobject]$state
}

function Test-ResponsibilityGerrit {
  [CmdletBinding()]
  param(
    [string]$KnowledgeBaseText,
    [string]$GerritText,
    [string]$ContractText,
    [string]$ApprovedPlanText,
    [string]$ImplementationText,
    [string]$ReviewText,
    [string]$VerificationText,
    [string]$ParityText,
    [string]$RegressionText
  )

  $errors = [Collections.Generic.List[string]]::new()
  foreach ($error in @(Test-ArcResponsibilityStageVersion $ContractText 'HANDOFF')) { $errors.Add($error) }
  $assuranceEdges = [Collections.Generic.List[object]]::new()
  $assuranceEdges.Add([pscustomobject]@{ Source = $ReviewText; Target = $VerificationText })
  $assuranceEdges.Add([pscustomobject]@{ Source = $VerificationText; Target = $ParityText })
  if ([string]::IsNullOrWhiteSpace($RegressionText)) {
    $assuranceEdges.Add([pscustomobject]@{ Source = $ParityText; Target = $KnowledgeBaseText })
  }
  else {
    $assuranceEdges.Add([pscustomobject]@{ Source = $ParityText; Target = $RegressionText })
    $assuranceEdges.Add([pscustomobject]@{ Source = $RegressionText; Target = $KnowledgeBaseText })
  }
  foreach ($assuranceEdge in $assuranceEdges) {
    $edgeDiagnostics = @(Test-ResponsibilityHandoff -SourceText $assuranceEdge.Source -TargetText $assuranceEdge.Target -ContractText $ContractText -ApprovedPlanText $ApprovedPlanText)
    foreach ($edgeDiagnostic in $edgeDiagnostics) {
      if ($edgeDiagnostic -ceq 'responsibility-contract-version-invalid') { $errors.Add($edgeDiagnostic) }
      else { $errors.Add('responsibility-evidence-missing') }
    }
  }
  if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }
  $scopeColumns = @('Run ID', 'Master Spec Reference', 'Master Spec ID', 'Master Spec Revision', 'Master Plan Reference', 'Master Plan ID', 'Master Plan Revision', 'Work Item ID')
  $provenanceColumns = @('Task / Unit', 'Task-base SHA', 'Final-tree SHA', 'Source Artifact')
  $handoffColumns = @('Responsibility Contract Version', 'Tree Conformance', 'Responsibility Conformance', 'Verification Ownership', 'Architecture Conformance State', 'Evidence References')
  $selectedUnitColumns = @('Migration Unit ID', 'Plan Reference', 'Approval Reference', 'Mode Constraint', 'Bootstrap Scope', 'Foundation Baseline ID', 'Foundation Baseline Reference', 'Foundation Baseline Approval Reference', 'Baseline Reference', 'Trace IDs')

  if ([string]::IsNullOrWhiteSpace($ImplementationText)) {
    $errors.Add('responsibility-evidence-missing')
    return @($errors | Select-Object -Unique)
  }
  $implementationVersionDiagnostics = @(Test-ArcDiscoveryResponsibilityContractVersion -DiscoveryText $ImplementationText)
  if ($implementationVersionDiagnostics.Count -ne 0) {
    foreach ($implementationVersionDiagnostic in $implementationVersionDiagnostics) {
      if ($implementationVersionDiagnostic -ceq 'responsibility-contract-version-invalid') { $errors.Add($implementationVersionDiagnostic) }
      else { $errors.Add('responsibility-evidence-missing') }
    }
    return @($errors | Select-Object -Unique)
  }

  $implementationFrontMatter = Get-ArcBoundedFrontMatter -Text $ImplementationText
  $implementationTopLevelKeys = @(
    [regex]::Matches($implementationFrontMatter, '(?m)^(?!#)(?<key>[^ \t:\r\n][^:\r\n]*):') |
      ForEach-Object { $_.Groups['key'].Value }
  )
  $implementationProducedAtMatches = @([regex]::Matches($implementationFrontMatter, '(?m)^produced_at:\s*(?<value>[^\r\n]+?)\s*$'))
  $parsedImplementationProducedAt = [datetime]::MinValue
  $implementationProducedAtValid = $implementationProducedAtMatches.Count -eq 1 -and [datetime]::TryParseExact(
    $implementationProducedAtMatches[0].Groups['value'].Value.Trim(),
    'yyyy-MM-dd',
    [Globalization.CultureInfo]::InvariantCulture,
    [Globalization.DateTimeStyles]::None,
    [ref]$parsedImplementationProducedAt
  )
  if (
    ($implementationTopLevelKeys -join '|') -cne 'step_id|status|result|approval_source|produced_at|responsibility_contract' -or
    @([regex]::Matches($implementationFrontMatter, '(?m)^step_id:\s*10-code-migration\s*$')).Count -ne 1 -or
    @([regex]::Matches($implementationFrontMatter, '(?m)^status:\s*approved\s*$')).Count -ne 1 -or
    @([regex]::Matches($implementationFrontMatter, '(?m)^result:\s*complete\s*$')).Count -ne 1 -or
    @([regex]::Matches($implementationFrontMatter, '(?m)^approval_source:\s*human\s*$')).Count -ne 1 -or
    @([regex]::Matches($implementationFrontMatter, '(?m)^responsibility_contract:\s*$')).Count -ne 1 -or
    @([regex]::Matches($implementationFrontMatter, '(?m)^  version:\s*1\s*$')).Count -ne 1 -or
    @([regex]::Matches($implementationFrontMatter, '(?m)^  applicability:\s*required\s*$')).Count -ne 1 -or
    -not $implementationProducedAtValid
  ) {
    $errors.Add('responsibility-evidence-missing')
    return @($errors | Select-Object -Unique)
  }

  $reviewVisibleText = Get-ArcVisibleMarkdownText -Text $ReviewText
  $reviewAdapterMatches = @(Get-ArcStrictVisibleBulletMatches -Text $ReviewText -Label 'Delivery Adapter Kind')
  $reviewModeMatches = @(Get-ArcStrictVisibleBulletMatches -Text $ReviewText -Label 'Delivery Adapter Mode Constraint')
  if ($reviewAdapterMatches.Count -ne 1 -or $reviewModeMatches.Count -ne 1) {
    $errors.Add('responsibility-evidence-missing')
    return @($errors | Select-Object -Unique)
  }
  $reviewAdapterKind = $reviewAdapterMatches[0].Groups['value'].Value.Trim()
  $reviewModeConstraint = $reviewModeMatches[0].Groups['value'].Value.Trim()
  $approvedModeConstraint = ''
  $expectedTerminalUnitId = ''
  $planSelectionColumns = @('Work Item ID', 'Adapter Kind', 'External ID', 'Authority', 'Authority Revision', 'Approval Reference', 'Parent Selector', 'Acceptance', 'Trace IDs', 'Mode Constraint', 'Design Revision', 'Parent Work Item ID', 'Decomposition Decision Reference')
  $workItemColumns = @('Work Item ID', 'Title', 'Required', 'Dependencies', 'Plan Order', 'Acceptance', 'Trace IDs', 'Delivery Adapter', 'Status', 'Latest Attempt', 'Terminal Evidence', 'Approval Reference')
  $implementationScopeColumns = @('Master Spec Reference', 'Master Spec ID', 'Master Spec Revision', 'Master Plan Reference', 'Master Plan ID', 'Master Plan Revision', 'Work Item ID', 'Work Item Approval Reference')
  $implementationSelectorColumns = @($planSelectionColumns + 'Canonical Match')
  $originTableErrors = [Collections.Generic.List[string]]::new()
  $reviewScopeTable = @(Get-ArcStrictMarkdownTable -Text $ReviewText -Heading 'Master Scope Context' -Columns $scopeColumns -Errors $originTableErrors)
  $reviewProvenanceTable = @(Get-ArcStrictMarkdownTable -Text $ReviewText -Heading 'Task Provenance' -Columns $provenanceColumns -Errors $originTableErrors)
  $implementationScopeTable = @(Get-ArcStrictMarkdownTable -Text $ImplementationText -Heading 'Master Scope Context' -Columns $implementationScopeColumns -Errors $originTableErrors)
  $implementationSelectorTable = @(Get-ArcStrictMarkdownTable -Text $ImplementationText -Heading 'Canonical Adapter Evidence' -Columns $implementationSelectorColumns -Errors $originTableErrors)
  $planSelectionTable = @(Get-ArcStrictMarkdownTable -Text $ApprovedPlanText -Heading 'Delivery Adapter Selection' -Columns $planSelectionColumns -Errors $originTableErrors)
  $planWorkItemTable = @(Get-ArcStrictMarkdownTable -Text $ApprovedPlanText -Heading 'Work Items' -Columns $workItemColumns -Errors $originTableErrors)
  if (
    $originTableErrors.Count -ne 0 -or
    $reviewScopeTable.Count -ne 3 -or
    $reviewProvenanceTable.Count -ne 3 -or
    $implementationScopeTable.Count -ne 3 -or
    $implementationSelectorTable.Count -ne 3 -or
    $planSelectionTable.Count -lt 3 -or
    $planWorkItemTable.Count -lt 3
  ) {
    $errors.Add('responsibility-evidence-missing')
    return @($errors | Select-Object -Unique)
  }
  $rowFromCells = {
    param([object]$Cells, [string[]]$Columns)
    $row = [ordered]@{}
    for ($index = 0; $index -lt $Columns.Count; $index++) { $row[$Columns[$index]] = [string]$Cells[$index] }
    return $row
  }
  $reviewScope = & $rowFromCells $reviewScopeTable[2] $scopeColumns
  $reviewProvenance = & $rowFromCells $reviewProvenanceTable[2] $provenanceColumns
  $implementationScope = & $rowFromCells $implementationScopeTable[2] $implementationScopeColumns
  $implementationSelector = & $rowFromCells $implementationSelectorTable[2] $implementationSelectorColumns
  $planSelectionRows = @($planSelectionTable | Select-Object -Skip 2 | Where-Object { [string]$_[0] -ceq $reviewScope['Work Item ID'] })
  $planWorkItemRows = @($planWorkItemTable | Select-Object -Skip 2 | Where-Object { [string]$_[0] -ceq $reviewScope['Work Item ID'] })
  if ($planSelectionRows.Count -ne 1 -or $planWorkItemRows.Count -ne 1) {
    $errors.Add('responsibility-evidence-missing')
    return @($errors | Select-Object -Unique)
  }
  $planSelection = & $rowFromCells $planSelectionRows[0] $planSelectionColumns
  $planWorkItem = & $rowFromCells $planWorkItemRows[0] $workItemColumns
  foreach ($field in $planSelectionColumns) {
    if ($implementationSelector[$field] -cne $planSelection[$field]) { $errors.Add('responsibility-evidence-missing') }
  }
  foreach ($field in @('Master Spec Reference', 'Master Spec ID', 'Master Spec Revision', 'Master Plan Reference', 'Master Plan ID', 'Master Plan Revision', 'Work Item ID')) {
    if ($implementationScope[$field] -cne $reviewScope[$field]) { $errors.Add('responsibility-evidence-missing') }
  }
  if (
    $implementationSelector['Canonical Match'] -cne 'PASS' -or
    $implementationSelector['Adapter Kind'] -cne $reviewAdapterKind -or
    $implementationSelector['Mode Constraint'] -cne $reviewModeConstraint -or
    $reviewModeConstraint -cne $planSelection['Mode Constraint'] -or
    $reviewModeConstraint -cnotin @('incremental/preserve-existing', 'greenfield/design-new') -or
    $implementationScope['Work Item Approval Reference'] -cne $planWorkItem['Approval Reference'] -or
    $reviewProvenance['Source Artifact'] -cne 'implementation-report.md'
  ) { $errors.Add('responsibility-evidence-missing') }

  $implementationProvenanceErrors = [Collections.Generic.List[string]]::new()
  $implementationProvenance = Get-ArcImplementationReviewProvenance -ImplementationText $ImplementationText -Errors $implementationProvenanceErrors
  $expectedImplementationTaskUnit = if ($reviewAdapterKind -ceq 'migration-unit') { [string]$planSelection['External ID'] } else { [string]$reviewScope['Work Item ID'] }
  if (
    $implementationProvenanceErrors.Count -ne 0 -or
    $null -eq $implementationProvenance -or
    $implementationProvenance.TaskUnit -cne $expectedImplementationTaskUnit -or
    $implementationProvenance.TaskBaseSha -cne $reviewProvenance['Task-base SHA'] -or
    $implementationProvenance.FinalTreeSha -cne $reviewProvenance['Final-tree SHA']
  ) { $errors.Add('responsibility-evidence-missing') }

  $approvedModeConstraint = [string]$planSelection['Mode Constraint']
  if ($reviewAdapterKind -ceq 'migration-unit') {
    $implementationSelectedErrors = [Collections.Generic.List[string]]::new()
    $implementationSelectedTable = @(Get-ArcStrictMarkdownTable -Text $ImplementationText -Heading 'Selected Migration Unit' -Columns $selectedUnitColumns -Errors $implementationSelectedErrors)
    if ($implementationSelectedErrors.Count -ne 0 -or $implementationSelectedTable.Count -ne 3) {
      $errors.Add('responsibility-evidence-missing')
    }
    else {
      $implementationSelectedUnit = & $rowFromCells $implementationSelectedTable[2] $selectedUnitColumns
      $expectedTerminalUnitId = [string]$implementationSelectedUnit['Migration Unit ID']
      if (-not (Test-ArcSelectedMigrationUnitAuthority -SelectedUnit $implementationSelectedUnit -PlanSelection $planSelection)) {
        $errors.Add('responsibility-evidence-missing')
      }
      foreach ($chainArtifactText in @($ReviewText, $VerificationText, $ParityText, $RegressionText, $KnowledgeBaseText, $GerritText)) {
        if ([string]::IsNullOrWhiteSpace($chainArtifactText)) { continue }
        $chainSelectedErrors = [Collections.Generic.List[string]]::new()
        $chainSelectedTable = @(Get-ArcStrictMarkdownTable -Text $chainArtifactText -Heading 'Selected Migration Unit' -Columns $selectedUnitColumns -Errors $chainSelectedErrors)
        if ($chainSelectedErrors.Count -ne 0 -or $chainSelectedTable.Count -ne 3) {
          $errors.Add('responsibility-evidence-missing')
          continue
        }
        $chainSelectedUnit = & $rowFromCells $chainSelectedTable[2] $selectedUnitColumns
        foreach ($field in $selectedUnitColumns) {
          if ($chainSelectedUnit[$field] -cne $implementationSelectedUnit[$field]) { $errors.Add('responsibility-evidence-missing') }
        }
      }
    }
  }
  elseif ($reviewAdapterKind -cin @('task', 'story', 'package', 'phase', 'milestone', 'none')) {
    $expectedTerminalUnitId = 'not-applicable'
    foreach ($chainArtifactText in @($ImplementationText, $ReviewText, $VerificationText, $ParityText, $RegressionText, $KnowledgeBaseText, $GerritText)) {
      if ([string]::IsNullOrWhiteSpace($chainArtifactText)) { continue }
      if (@(Get-ArcMarkdownH2HeadingMatches -Text $chainArtifactText -Heading 'Selected Migration Unit').Count -ne 0) {
        $errors.Add('responsibility-evidence-missing')
      }
    }
  }
  else { $errors.Add('responsibility-evidence-missing') }
  if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }

  $approvedMode = if ($approvedModeConstraint -ceq 'incremental/preserve-existing') {
    'incremental'
  }
  elseif ($approvedModeConstraint -ceq 'greenfield/design-new') {
    'greenfield'
  }
  else { '' }
  if ($approvedMode -ceq '') {
    $errors.Add('responsibility-evidence-missing')
    return @($errors | Select-Object -Unique)
  }
  $verificationVerdict = Get-ArcMigrationStageVerdict -Role verification -Text $VerificationText -ExpectedMode $approvedMode -ExpectedMigrationUnitId $expectedTerminalUnitId
  $parityVerdict = Get-ArcMigrationStageVerdict -Role parity -Text $ParityText -ExpectedMode $approvedMode -ExpectedMigrationUnitId $expectedTerminalUnitId
  $regressionVerdict = if ([string]::IsNullOrWhiteSpace($RegressionText)) {
    $null
  }
  else {
    Get-ArcMigrationStageVerdict -Role regression -Text $RegressionText -ExpectedMode $approvedMode -ExpectedMigrationUnitId $expectedTerminalUnitId
  }
  $knowledgeBaseVerdict = Get-ArcMigrationStageVerdict -Role knowledge-base -Text $KnowledgeBaseText -ExpectedMode $approvedMode -ExpectedMigrationUnitId $expectedTerminalUnitId
  $gerritVerdict = Get-ArcMigrationStageVerdict -Role gerrit -Text $GerritText -ExpectedMode $approvedMode -ExpectedMigrationUnitId $expectedTerminalUnitId
  $regressionPreservesParityEvidence = $true
  if ($approvedMode -ceq 'incremental' -and $null -ne $regressionVerdict) {
    $parityEvidencePrefix = "$($parityVerdict.Evidence); "
    $regressionEvidence = [string]$regressionVerdict.Evidence
    $hasEnrichedRegressionEvidence = (
      $regressionEvidence.StartsWith($parityEvidencePrefix, [StringComparison]::Ordinal) -and
      -not [string]::IsNullOrWhiteSpace($regressionEvidence.Substring($parityEvidencePrefix.Length))
    )
    $regressionPreservesParityEvidence = (
      $regressionVerdict.ParityVerdict -ceq $parityVerdict.ParityVerdict -and
      ($regressionEvidence -ceq $parityVerdict.Evidence -or $hasEnrichedRegressionEvidence)
    )
  }
  $expectedGerritEvidence = if ($approvedMode -ceq 'incremental' -and $null -ne $regressionVerdict) {
    [string]$regressionVerdict.Evidence
  }
  elseif ($approvedMode -ceq 'greenfield') { [string]$parityVerdict.Evidence }
  else { '' }
  if (
    -not $verificationVerdict.Valid -or
    -not $parityVerdict.Valid -or
    ($approvedMode -ceq 'incremental' -and ($null -eq $regressionVerdict -or -not $regressionVerdict.Valid)) -or
    ($approvedMode -ceq 'incremental' -and -not $regressionPreservesParityEvidence) -or
    ($approvedMode -ceq 'greenfield' -and $null -ne $regressionVerdict) -or
    -not $knowledgeBaseVerdict.Valid -or
    -not $gerritVerdict.Valid -or
    $gerritVerdict.Evidence -cne $expectedGerritEvidence
  ) { $errors.Add('responsibility-evidence-missing') }
  if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }

  $testLifecycle = {
    param([string]$Text, [string]$Role)
    $frontMatter = Get-ArcBoundedFrontMatter -Text $Text
    $topLevelKeys = @(
      [regex]::Matches($frontMatter, '(?m)^(?!#)(?<key>[^ \t:\r\n][^:\r\n]*):') |
        ForEach-Object { $_.Groups['key'].Value }
    )
    $expectedTopLevelKeys = if ($Role -ceq 'knowledge-base') {
      'step_id|status|result|approval_source|produced_at|responsibility_contract'
    }
    else {
      'step_id|status|result|produced_at|responsibility_contract'
    }
    $expectedStepId = if ($Role -ceq 'knowledge-base') { '15-knowledge-base' } else { '07-gerrit-automation' }
    $expectedStatus = if ($Role -ceq 'knowledge-base') { 'approved' } else { 'draft' }
    $producedAtMatches = @([regex]::Matches($frontMatter, '(?m)^produced_at:\s*(?<value>[^\r\n]+?)\s*$'))
    $parsedProducedAt = [datetime]::MinValue
    $producedAtValid = $producedAtMatches.Count -eq 1 -and [datetime]::TryParseExact(
      $producedAtMatches[0].Groups['value'].Value.Trim(),
      'yyyy-MM-dd',
      [Globalization.CultureInfo]::InvariantCulture,
      [Globalization.DateTimeStyles]::None,
      [ref]$parsedProducedAt
    )
    $valid = (
      ($topLevelKeys -join '|') -ceq $expectedTopLevelKeys -and
      @([regex]::Matches($frontMatter, "(?m)^step_id:\s*$([regex]::Escape($expectedStepId))\s*$")).Count -eq 1 -and
      @([regex]::Matches($frontMatter, "(?m)^status:\s*$([regex]::Escape($expectedStatus))\s*$")).Count -eq 1 -and
      @([regex]::Matches($frontMatter, '(?m)^result:\s*complete\s*$')).Count -eq 1 -and
      @([regex]::Matches($frontMatter, '(?m)^responsibility_contract:\s*$')).Count -eq 1 -and
      @([regex]::Matches($frontMatter, '(?m)^  version:\s*1\s*$')).Count -eq 1 -and
      @([regex]::Matches($frontMatter, '(?m)^  applicability:\s*required\s*$')).Count -eq 1 -and
      $producedAtValid
    )
    if ($Role -ceq 'knowledge-base') {
      $valid = $valid -and @([regex]::Matches($frontMatter, '(?m)^approval_source:\s*human\s*$')).Count -eq 1
    }
    if (-not $valid) { $errors.Add('responsibility-evidence-missing') }
    return $valid
  }

  $testEnvelopeOrder = {
    param([string]$Text, [string]$AdapterKind)
    $visibleText = Get-ArcVisibleMarkdownText -Text $Text
    $expectedHeadings = @('Master Scope Context', 'Task Provenance')
    if ($AdapterKind -ceq 'migration-unit') { $expectedHeadings += 'Selected Migration Unit' }
    $expectedHeadings += 'Architecture Responsibility Handoff'
    $h2Headings = @(
      [regex]::Matches($visibleText, '(?m)^##[ \t]+(?<heading>[^\r\n]+?)[ \t]*\r?$') |
        ForEach-Object { ($_.Groups['heading'].Value -replace '[ \t]+', ' ').Trim() }
    )
    $envelopeStart = [Array]::IndexOf($h2Headings, $expectedHeadings[0])
    $valid = $envelopeStart -ge 0 -and ($envelopeStart + $expectedHeadings.Count) -le $h2Headings.Count
    if ($valid) {
      for ($headingIndex = 0; $headingIndex -lt $expectedHeadings.Count; $headingIndex++) {
        if ($h2Headings[$envelopeStart + $headingIndex] -cne $expectedHeadings[$headingIndex]) {
          $valid = $false
          break
        }
      }
    }
    $adapterMatches = @(Get-ArcStrictVisibleBulletMatches -Text $Text -Label 'Delivery Adapter Kind')
    $modeMatches = @(Get-ArcStrictVisibleBulletMatches -Text $Text -Label 'Delivery Adapter Mode Constraint')
    $scopeHeading = [regex]::Match($visibleText, (Get-ArcMarkdownH2HeadingPattern -Heading 'Master Scope Context'))
    $provenanceHeading = [regex]::Match($visibleText, (Get-ArcMarkdownH2HeadingPattern -Heading 'Task Provenance'))
    if (
      $adapterMatches.Count -ne 1 -or
      $modeMatches.Count -ne 1 -or
      -not $scopeHeading.Success -or
      -not $provenanceHeading.Success -or
      $adapterMatches[0].Index -le $scopeHeading.Index -or
      $adapterMatches[0].Index -ge $provenanceHeading.Index -or
      $adapterMatches[0].Index -ge $modeMatches[0].Index -or
      $modeMatches[0].Index -le $scopeHeading.Index -or
      $modeMatches[0].Index -ge $provenanceHeading.Index
    ) { $valid = $false }
    if (-not $valid) { $errors.Add('responsibility-evidence-missing') }
    return $valid
  }

  $readEnvelope = {
    param([string]$Text, [string]$Role)
    $envelope = [ordered]@{ Scope = $null; Provenance = $null; Handoff = $null; SelectedUnit = $null; AdapterKind = ''; ModeConstraint = '' }
    if ([string]::IsNullOrWhiteSpace($Text)) { $errors.Add('responsibility-evidence-missing'); return $envelope }
    $artifactVersionErrors = @(Test-ArcDiscoveryResponsibilityContractVersion -DiscoveryText $Text)
    if ($artifactVersionErrors.Count -ne 0) {
      foreach ($artifactVersionError in $artifactVersionErrors) { $errors.Add($artifactVersionError) }
      return $envelope
    }
    if (-not (& $testLifecycle $Text $Role)) { return $envelope }
    $tableErrors = [Collections.Generic.List[string]]::new()
    $scopeTable = @(Get-ArcStrictMarkdownTable -Text $Text -Heading 'Master Scope Context' -Columns $scopeColumns -Errors $tableErrors)
    $provenanceTable = @(Get-ArcStrictMarkdownTable -Text $Text -Heading 'Task Provenance' -Columns $provenanceColumns -Errors $tableErrors)
    $handoffTable = @(Get-ArcStrictMarkdownTable -Text $Text -Heading 'Architecture Responsibility Handoff' -Columns $handoffColumns -Errors $tableErrors)
    foreach ($tableError in $tableErrors) { $errors.Add($tableError) }
    if ($scopeTable.Count -ne 3 -or $provenanceTable.Count -ne 3 -or $handoffTable.Count -ne 3) { return $envelope }
    $scope = [ordered]@{}; $provenance = [ordered]@{}; $handoff = [ordered]@{}
    for ($index = 0; $index -lt $scopeColumns.Count; $index++) { $scope[$scopeColumns[$index]] = [string]$scopeTable[2][$index] }
    for ($index = 0; $index -lt $provenanceColumns.Count; $index++) { $provenance[$provenanceColumns[$index]] = [string]$provenanceTable[2][$index] }
    for ($index = 0; $index -lt $handoffColumns.Count; $index++) { $handoff[$handoffColumns[$index]] = [string]$handoffTable[2][$index] }
    $envelope.Scope = $scope; $envelope.Provenance = $provenance; $envelope.Handoff = $handoff
    if ($handoff['Responsibility Contract Version'] -cne '1') {
      $errors.Add('responsibility-contract-version-invalid')
    }
    $structuralVerdicts = @(
      [string]$handoff['Tree Conformance'],
      [string]$handoff['Responsibility Conformance'],
      [string]$handoff['Verification Ownership']
    )
    $derivedArchitecture = if (@($structuralVerdicts | Where-Object { $_ -cne 'PASS' }).Count -eq 0) { 'PASS' } else { 'BLOCKED' }
    if (
      @($structuralVerdicts | Where-Object { $_ -cnotin @('PASS', 'BLOCKED') }).Count -ne 0 -or
      [string]$handoff['Architecture Conformance State'] -cne $derivedArchitecture -or
      $derivedArchitecture -cne 'PASS'
    ) { $errors.Add('responsibility-evidence-missing') }
    if (
      $provenance['Task-base SHA'] -cnotmatch '^[0-9a-f]{40}$' -or
      $provenance['Final-tree SHA'] -cnotmatch '^[0-9a-f]{40}$' -or
      @($provenanceColumns | Where-Object {
        [string]::IsNullOrWhiteSpace([string]$provenance[$_]) -or [string]$provenance[$_] -match '<[^>]+>'
      }).Count -ne 0
    ) { $errors.Add('responsibility-evidence-missing') }
    if (
      $scope['Run ID'] -cnotmatch '^RUN-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -or
      $scope['Master Spec Reference'] -cnotmatch '^(?:[A-Za-z0-9_.-]+/)*master-spec\.md$' -or
      $scope['Master Spec ID'] -cnotmatch '^SPEC-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -or
      $scope['Master Spec Revision'] -cnotmatch '^[1-9][0-9]*$' -or
      $scope['Master Plan Reference'] -cnotmatch '^(?:[A-Za-z0-9_.-]+/)*master-plan\.md$' -or
      $scope['Master Plan ID'] -cnotmatch '^PLAN-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -or
      $scope['Master Plan Revision'] -cnotmatch '^[1-9][0-9]*$' -or
      $scope['Work Item ID'] -cnotmatch '^WORK-[A-Z0-9]+(?:-[A-Z0-9]+)*$'
    ) { $errors.Add('responsibility-evidence-missing') }
    $expectedEvidence = "source-diff:$($provenance['Task-base SHA'])..$($provenance['Final-tree SHA'])#$($scope['Work Item ID'])"
    if ($handoff['Evidence References'] -cne $expectedEvidence) { $errors.Add('responsibility-evidence-missing') }
    if ($provenance['Source Artifact'] -cnotin @('13-parity-report.md', '14-regression-report.md')) {
      $errors.Add('responsibility-evidence-missing')
    }
    $visibleText = Get-ArcVisibleMarkdownText -Text $Text
    $adapterMatches = @(Get-ArcStrictVisibleBulletMatches -Text $Text -Label 'Delivery Adapter Kind')
    $modeMatches = @(Get-ArcStrictVisibleBulletMatches -Text $Text -Label 'Delivery Adapter Mode Constraint')
    if ($adapterMatches.Count -ne 1 -or $modeMatches.Count -ne 1) { $errors.Add('responsibility-evidence-missing'); return $envelope }
    $envelope.AdapterKind = $adapterMatches[0].Groups['value'].Value.Trim()
    $envelope.ModeConstraint = $modeMatches[0].Groups['value'].Value.Trim()
    if ($envelope.AdapterKind -cnotin @('migration-unit', 'task', 'story', 'package', 'phase', 'milestone', 'none')) {
      $errors.Add('responsibility-evidence-missing'); return $envelope
    }
    if ($envelope.ModeConstraint -cnotin @('incremental/preserve-existing', 'greenfield/design-new')) {
      $errors.Add('responsibility-evidence-missing'); return $envelope
    }
    $selectedHeadingCount = @(Get-ArcMarkdownH2HeadingMatches -Text $Text -Heading 'Selected Migration Unit').Count
    if ($envelope.AdapterKind -ceq 'migration-unit') {
      $selectedTable = @(Get-ArcStrictMarkdownTable -Text $Text -Heading 'Selected Migration Unit' -Columns $selectedUnitColumns -Errors $errors)
      if ($selectedTable.Count -eq 3) {
        $selectedUnit = [ordered]@{}
        for ($index = 0; $index -lt $selectedUnitColumns.Count; $index++) { $selectedUnit[$selectedUnitColumns[$index]] = [string]$selectedTable[2][$index] }
        $envelope.SelectedUnit = $selectedUnit
      }
    }
    elseif ($selectedHeadingCount -ne 0) { $errors.Add('responsibility-evidence-missing') }
    if (-not (& $testEnvelopeOrder $Text $envelope.AdapterKind)) { return $envelope }
    return $envelope
  }

  $knowledge = & $readEnvelope $KnowledgeBaseText 'knowledge-base'
  $gerrit = & $readEnvelope $GerritText 'gerrit'
  if ($null -eq $knowledge.Scope -or $null -eq $gerrit.Scope) { return @($errors | Select-Object -Unique) }
  if ($knowledge.AdapterKind -cne $gerrit.AdapterKind -or $knowledge.ModeConstraint -cne $gerrit.ModeConstraint) { $errors.Add('responsibility-evidence-missing') }
  foreach ($field in $scopeColumns) { if ($knowledge.Scope[$field] -cne $gerrit.Scope[$field]) { $errors.Add('responsibility-evidence-missing') } }
  foreach ($field in $provenanceColumns) { if ($knowledge.Provenance[$field] -cne $gerrit.Provenance[$field]) { $errors.Add('responsibility-evidence-missing') } }
  foreach ($field in $handoffColumns) { if ($knowledge.Handoff[$field] -cne $gerrit.Handoff[$field]) { $errors.Add('responsibility-evidence-missing') } }
  if ($knowledge.AdapterKind -ceq 'migration-unit') {
    if ($null -eq $knowledge.SelectedUnit -or $null -eq $gerrit.SelectedUnit) { $errors.Add('responsibility-evidence-missing') }
    else { foreach ($field in $selectedUnitColumns) { if ($knowledge.SelectedUnit[$field] -cne $gerrit.SelectedUnit[$field]) { $errors.Add('responsibility-evidence-missing') } } }
  }
  $expectedIdentity = if ($knowledge.AdapterKind -ceq 'migration-unit' -and $null -ne $knowledge.SelectedUnit) {
    [string]$knowledge.SelectedUnit['Migration Unit ID']
  }
  else { [string]$knowledge.Scope['Work Item ID'] }
  if ($knowledge.Provenance['Task / Unit'] -cne $expectedIdentity) { $errors.Add('responsibility-evidence-missing') }
  $expectedEvidence = "source-diff:$($knowledge.Provenance['Task-base SHA'])..$($knowledge.Provenance['Final-tree SHA'])#$($knowledge.Scope['Work Item ID'])"
  if ($knowledge.Handoff['Evidence References'] -cne $expectedEvidence) { $errors.Add('responsibility-evidence-missing') }

  $branchColumns = @('Task-base SHA', 'Upstream Ref', 'Upstream SHA', 'Merge-base SHA', 'Final Commit SHA', 'Actual Task Commit Count', 'Task / Unit ID', 'Diff-scope Verdict', 'Formatter Evidence', 'Post-integration Verification')
  $branchTable = @(Get-ArcStrictMarkdownTable -Text $GerritText -Heading 'Branch and Commit Integrity' -Columns $branchColumns -Errors $errors)
  if ($branchTable.Count -eq 3) {
    $branchRow = $branchTable[2]
    if (
      [string]$branchRow[0] -cne [string]$knowledge.Provenance['Task-base SHA'] -or
      [string]$branchRow[4] -cne [string]$knowledge.Provenance['Final-tree SHA'] -or
      [string]$branchRow[5] -cnotmatch '^[1-9][0-9]*$' -or
      [string]$branchRow[6] -cne $expectedIdentity -or
      [string]$branchRow[7] -cne 'PASS'
    ) { $errors.Add('responsibility-evidence-missing') }
  }
  return @($errors | Select-Object -Unique)
}

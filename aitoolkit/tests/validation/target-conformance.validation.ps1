function Test-TargetConformance([string]$Root, [string]$ContractText) {
  $contractPath = Join-Path $Root 'contracts/target-structure-conformance.md'
  if (-not (Test-Path -LiteralPath $contractPath -PathType Leaf)) {
    $errors.Add('Missing target structure conformance contract resource')
    return
  }
  if ([string]::IsNullOrWhiteSpace($ContractText)) {
    $errors.Add('Target structure conformance contract must not be empty')
    return
  }

  Test-MarkdownTableExactColumns $ContractText 'Comparable Target Exemplars' `
    @(
      'Concern', 'Path', 'Inspected Symbols', 'Observed Pattern', 'Primary Responsibility',
      'Owned Capabilities', 'Verification Owner', 'Comparable Reason', 'Evidence',
      'Inspection Status', 'Classification', 'Classification Authority', 'Classification Evidence'
    ) `
    'Target structure conformance contract'
  Test-MarkdownTableExactColumns $ContractText 'Target Structure Conformance Matrix' `
    @('Concern', 'Working Exemplar', 'Observed Target Pattern', 'Proposed Path/Symbol', 'Conforms', 'Deviation Reference') `
    'Target structure conformance contract'
  Test-MarkdownTableExactColumns $ContractText 'Assurance State' `
    @('Runtime Evidence State', 'Architecture Conformance State', 'Selector Schema State') `
    'Target structure conformance contract'

  @(
    'service/config subscription and normalization',
    '`Inspection Status` and `Classification` are independent.',
    'no seven-column discovery adapter is executable in responsibility contract v1.',
    'A `Conforms = no` row requires a resolved conflict and Tech Lead approval in `Deviation Reference`.',
    'The structural pre-edit gate blocks before target edit and is not waiver-eligible.',
    'runtime_evidence_state: PASS | FAIL | NOT_RUN | WAIVED',
    'architecture_conformance_state: PASS | BLOCKED',
    'selector_schema_state: PASS | BLOCKED',
    'Architecture-first review order: master-scope/work-item alignment -> project rule resolution -> canonical selector -> architecture conformance with matrix/exemplars -> production activation path -> behavior, failure modes, security, performance, and tests -> change hygiene.'
  ) | ForEach-Object {
    Require-Token $ContractText $_ 'Target structure conformance contract'
  }

  $getSection = {
    param([string]$Text, [string]$Heading)
    $headingPattern = '(?m)^##\s+' + [regex]::Escape($Heading) + '[ \t]*\r?$'
    $headingMatch = [regex]::Match($Text, $headingPattern)
    if (-not $headingMatch.Success) { return $null }
    $bodyStart = $headingMatch.Index + $headingMatch.Length
    $following = [regex]::Match($Text.Substring($bodyStart), '(?m)^#{1,2}\s+[^\r\n]+\r?$')
    $bodyLength = if ($following.Success) { $following.Index } else { $Text.Length - $bodyStart }
    return $Text.Substring($bodyStart, $bodyLength)
  }

  $getTable = {
    param([string]$Text, [string]$Heading)
    $body = & $getSection $Text $Heading
    if ($null -eq $body) { return $null }
    $tableLines = @($body -split '\r?\n' | Where-Object { $_ -match '^\s*\|.*\|\s*$' })
    if ($tableLines.Count -lt 2) { return $null }
    $columns = @($tableLines[0].Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
    $rows = [Collections.Generic.List[object]]::new()
    foreach ($line in @($tableLines | Select-Object -Skip 2)) {
      $cells = @($line.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
      if ($cells.Count -ne $columns.Count) { continue }
      $row = [ordered]@{}
      for ($index = 0; $index -lt $columns.Count; $index++) {
        $row[$columns[$index]] = $cells[$index]
      }
      $rows.Add([pscustomobject]$row)
    }
    return [pscustomobject]@{ Columns = $columns; Rows = @($rows) }
  }

  $getStrictTable = {
    param([string]$Text, [string]$Heading)
    $body = & $getSection $Text $Heading
    if ($null -eq $body) { return $null }
    $lines = @($body -split '\n' | ForEach-Object { $_.TrimEnd("`r") })
    $parseStrictTableLine = {
      param([string]$Line)
      $frameMatch = [regex]::Match($Line, '^\|(?<body>.*)\|[ \t]*$')
      if (-not $frameMatch.Success) { return $null }
      $cells = @($frameMatch.Groups['body'].Value.Split('|') | ForEach-Object { $_.Trim() })
      if ($cells.Count -eq 0 -or @($cells | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -gt 0) {
        return $null
      }
      return [pscustomobject]@{ Cells = $cells }
    }
    $headerIndex = -1
    for ($lineIndex = 0; $lineIndex -lt $lines.Count; $lineIndex++) {
      if ($lines[$lineIndex] -match '^\|.*\|[ \t]*$') {
        $headerIndex = $lineIndex
        break
      }
    }
    if ($headerIndex -lt 0 -or $headerIndex + 1 -ge $lines.Count) {
      return $null
    }
    $header = & $parseStrictTableLine $lines[$headerIndex]
    $delimiter = & $parseStrictTableLine $lines[$headerIndex + 1]
    if ($null -eq $header -or $null -eq $delimiter) {
      return $null
    }
    $columns = @($header.Cells)
    $delimiterCells = @($delimiter.Cells)
    if (
      $delimiterCells.Count -ne $columns.Count -or
      @($delimiterCells | Where-Object { $_ -cnotmatch '^:?-{3,}:?$' }).Count -gt 0
    ) {
      return $null
    }
    $rows = [Collections.Generic.List[object]]::new()
    $nextLineIndex = $headerIndex + 2
    while ($nextLineIndex -lt $lines.Count -and -not [string]::IsNullOrWhiteSpace($lines[$nextLineIndex])) {
      $dataRow = & $parseStrictTableLine $lines[$nextLineIndex]
      if ($null -eq $dataRow -or $dataRow.Cells.Count -ne $columns.Count) {
        return $null
      }
      $cells = @($dataRow.Cells)
      $row = [ordered]@{}
      for ($cellIndex = 0; $cellIndex -lt $columns.Count; $cellIndex++) {
        $row[$columns[$cellIndex]] = $cells[$cellIndex]
      }
      $rows.Add([pscustomobject]$row)
      $nextLineIndex++
    }
    if ($rows.Count -eq 0 -or @($lines | Select-Object -Skip $nextLineIndex | Where-Object { $_ -match '^\|.*\|[ \t]*$' }).Count -gt 0) {
      return $null
    }
    return [pscustomobject]@{ Columns = $columns; Rows = @($rows) }
  }

  $isMissingValue = {
    param([string]$Value)
    return (
      [string]::IsNullOrWhiteSpace($Value) -or
      $Value -match '^\s*<[^>]+>\s*$' -or
      $Value -match '^(?i:unknown|none|n/?a|not-applicable)$'
    )
  }
  $explicitSymbolPattern = '^[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*$'
  $genericSymbolTokenPattern = '^(?i:all|any|generic|symbols?|controllers?|providers?|categor(?:y|ies)|genericcontrollers?|genericproviders?|genericcategor(?:y|ies))$'
  $pathSymbolPattern = '^(?<path>(?:[A-Za-z]:)?[\\/]?(?:[A-Za-z0-9_.-]+[\\/])*[A-Za-z0-9_.-]+)#(?<symbol>[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*)$'
  $decisionPattern = '^resolved:DECISION-[A-Z0-9]+(?:-[A-Z0-9]+)*:\s+[A-Za-z0-9][^<>]*$'
  $techLeadApprovalPattern = '^approval:TECH-LEAD-[A-Z0-9]+(?:-[A-Z0-9]+)*$'
  $semanticPlaceholderPattern = '(?i)(?:^|[^A-Za-z0-9])(?:pending|unknown|none|tbd|review|not-applicable|placeholder)(?:$|[^A-Za-z0-9])'
  $canonicalAcceptanceTracePattern = '^(?:REQ|SC|AC)-[0-9]{3}$'
  $idLikeAcceptancePrefixPattern = '^(?i:(?:REQ|SC|AC)(?=$|\s*[\p{P}\p{S}\p{N}_]))'
  $measurableQuantifierPattern = '(?i)(?:^|[^\p{L}\p{N}_])(?:at\s+least|at\s+most|within|under|over|exactly|all|no|zero)(?=$|[^\p{L}\p{N}_])'
  $numericMeasurePattern = '(?i)(?<![\p{L}\p{N}_])[0-9]+(?:[.,][0-9]+)?\s*(?:%|percent(?:age)?|milliseconds?|ms|seconds?|secs?|minutes?|mins?|hours?|days?|weeks?|months?|years?|items?|records?|requests?|responses?|errors?|failures?|cases?|tests?|users?|routes?|endpoints?|files?|rows?|events?|attempts?|occurrences?|times?|counts?|bytes?|kb|mb|gb|kib|mib|gib)(?=$|[^\p{L}\p{N}_])'
  $normalizePath = {
    param([string]$Value)
    return ($Value -replace '\\', '/')
  }
  $parseCanonicalAcceptance = {
    param([string]$Value)
    $references = [Collections.Generic.List[string]]::new()
    $outcomeSegments = [Collections.Generic.List[string]]::new()
    $valid = -not [string]::IsNullOrWhiteSpace($Value)
    $inOutcome = $false
    $usesSemicolonSegments = $valid -and $Value.Contains(';')
    $segments = if ($valid -and $usesSemicolonSegments) {
      @($Value -split ';' | ForEach-Object { $_.Trim() })
    }
    elseif ($valid) {
      @($Value -split ',' | ForEach-Object { $_.Trim() })
    }
    else {
      @()
    }
    if ($segments.Count -eq 0 -or @($segments | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -gt 0) {
      $valid = $false
    }
    foreach ($segment in $segments) {
      if ($segment -cmatch $canonicalAcceptanceTracePattern) {
        if ($inOutcome) {
          $valid = $false
        }
        [void]$references.Add($segment)
      }
      else {
        if ($segment -match $idLikeAcceptancePrefixPattern) {
          $valid = $false
        }
        $inOutcome = $true
        [void]$outcomeSegments.Add($segment)
      }
    }
    $outcomeSeparator = if ($usesSemicolonSegments) { '; ' } else { ', ' }
    $outcome = ($outcomeSegments -join $outcomeSeparator).Trim()
    $placeholderComparableOutcome = $outcome -replace '\p{Pd}', '-'
    $placeholderComparableOutcome = $placeholderComparableOutcome -replace '\s*/\s*', '/'
    $placeholderComparableOutcome = (($placeholderComparableOutcome -replace '(?:\s|-)+', ' ').Trim()).ToLowerInvariant()
    $isPlaceholderOutcome = $placeholderComparableOutcome -in @(
      'tbd', 'to be determined', 'pending', 'unknown', 'none', 'n/a', 'not applicable'
    )
    $outcomeTokens = @([regex]::Matches($outcome, '[\p{L}\p{N}]+'))
    $hasMeasurableCue = (
      $outcome -match '(?:<=|>=|<|>|=)' -or
      $outcome -match $measurableQuantifierPattern -or
      $outcome -match $numericMeasurePattern
    )
    if (
      @($references | Where-Object { $_ -cmatch '^REQ-[0-9]{3}$' }).Count -eq 0 -or
      @($references | Where-Object { $_ -cmatch '^SC-[0-9]{3}$' }).Count -eq 0 -or
      @($references | Sort-Object -Unique).Count -ne $references.Count -or
      [string]::IsNullOrWhiteSpace($outcome) -or
      $outcome -match '^\s*<[^>]+>\s*$' -or
      $isPlaceholderOutcome -or
      $outcomeTokens.Count -lt 2 -or
      $outcome -notmatch '\p{L}' -or
      -not $hasMeasurableCue
    ) {
      $valid = $false
    }
    return [pscustomobject]@{
      Valid = $valid
      References = @($references)
      Outcome = $outcome
    }
  }

  $contractExemplarTable = & $getTable $ContractText 'Comparable Target Exemplars'
  $contractMatrixTable = & $getTable $ContractText 'Target Structure Conformance Matrix'
  $exemplarSection = & $getSection $ContractText 'Comparable Target Exemplars'
  if ($null -eq $contractExemplarTable -or $null -eq $contractMatrixTable -or $null -eq $exemplarSection) {
    $errors.Add('Target structure conformance contract cannot derive exemplar concerns and columns')
    return
  }
  $canonicalConcerns = @(
    [regex]::Matches($exemplarSection, '(?m)^\s*\d+\.\s+`(?<concern>[^`]+)`\s*\r?$') |
      ForEach-Object { $_.Groups['concern'].Value }
  )
  if ($canonicalConcerns.Count -ne 8) {
    $errors.Add("Target structure conformance contract must define exactly eight concerns; found $($canonicalConcerns.Count)")
    return
  }

  $discoveryPath = Join-Path $Root '02-discovery.md'
  $designPath = Join-Path $Root '07-technical-design.md'
  $profilePath = Join-Path $Root 'docs/aitoolkit/project.yaml'
  $approvedResponsibilityMode = ''
  $hasTargetResponsibilityArtifacts = (Test-Path -LiteralPath $discoveryPath -PathType Leaf) -or (Test-Path -LiteralPath $designPath -PathType Leaf)
  if ($hasTargetResponsibilityArtifacts -and -not (Test-Path -LiteralPath $profilePath -PathType Leaf)) {
    $errors.Add('Missing approved migration mode authority')
  }
  elseif ($hasTargetResponsibilityArtifacts) {
    $profileText = Get-Content -Raw -Encoding utf8 -LiteralPath $profilePath
    $getYamlSection = {
      param([string]$Text, [string]$Name)
      $matches = @([regex]::Matches($Text, '(?ms)^' + [regex]::Escape($Name) + ':\s*\r?\n(?<body>.*?)(?=^[a-z_][a-z0-9_]*:|\z)'))
      if ($matches.Count -ne 1) { return $null }
      return $matches[0].Groups['body'].Value
    }
    $getTextRevision = {
      param([string]$Text)
      $bytes = ([Text.UTF8Encoding]::new($false)).GetBytes($Text.Replace("`r`n", "`n"))
      $sha = [Security.Cryptography.SHA256]::Create()
      try { return 'sha256:' + ([BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '')) }
      finally { $sha.Dispose() }
    }
    $getTreeRevision = {
      param([string]$Path)
      $manifest = @(
        Get-ChildItem -LiteralPath $Path -File -Recurse | Sort-Object { $_.FullName.Substring($Path.Length).Replace('\', '/') } | ForEach-Object {
          $relative = $_.FullName.Substring($Path.Length).TrimStart('\', '/').Replace('\', '/')
          $content = Get-Content -Raw -Encoding utf8 -LiteralPath $_.FullName
          "$relative`n$($content.Replace("`r`n", "`n"))"
        }
      ) -join "`n"
      return & $getTextRevision $manifest
    }

    $expectedTopLevelKeys = @(
      'automation', 'base_branch', 'build_cmd', 'coverage_cmd', 'documents', 'legacy', 'lint_cmd',
      'migration', 'output', 'project', 'project_pack', 'review_focus', 'schema_version', 'target',
      'test_cmd', 'verification'
    )
    $legacyRequiredTopLevelKeys = @($expectedTopLevelKeys | Where-Object { $_ -cnotin @('automation', 'output') })
    $topLevelKeys = @([regex]::Matches($profileText, '(?m)^(?<key>[a-z_][a-z0-9_]*):') | ForEach-Object { $_.Groups['key'].Value } | Sort-Object)
    $profileSectionNames = @('project', 'migration', 'automation', 'output', 'legacy', 'target', 'documents', 'verification', 'project_pack')
    $profileSections = @{}
    foreach ($sectionName in $profileSectionNames) {
      $sectionBody = & $getYamlSection $profileText $sectionName
      $profileSections[$sectionName] = if ($null -eq $sectionBody) { '' } else { $sectionBody }
    }
    if ($topLevelKeys -cnotcontains 'automation') { $profileSections['automation'] = '  mode: interactive' }
    if ($topLevelKeys -cnotcontains 'output') { $profileSections['output'] = '  artifact_language: vi' }
    $migrationBody = $profileSections['migration']
    $projectPackBody = $profileSections['project_pack']
    $getSectionKeys = {
      param([string]$Body)
      if ($null -eq $Body) { return @() }
      return @([regex]::Matches($Body, '(?m)^  (?<key>[a-z_][a-z0-9_]*):') | ForEach-Object { $_.Groups['key'].Value } | Sort-Object)
    }
    $sectionKeyShapes = [ordered]@{
      project = 'id'
      migration = 'architecture_policy|mode|unit'
      automation = 'mode'
      output = 'artifact_language'
      legacy = 'framework|language|path'
      target = 'framework|language|path'
      documents = 'architecture|migration|requirements|uiux'
      verification = 'behavior_parity|regression|visual_fidelity'
      project_pack = 'path|review_evidence|reviewed_at'
    }
    $scalarTopLevelKeys = @('schema_version', 'base_branch', 'test_cmd', 'lint_cmd', 'build_cmd', 'coverage_cmd')
    $canonicalProfileShapeValid = $true
    $seenTopLevelKeys = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $currentProfileSection = ''
    $reviewFocusUsesBlockList = $false
    $reviewFocusItemCount = 0
    foreach ($profileLine in @($profileText -split "`n" | ForEach-Object { $_.TrimEnd("`r") })) {
      if ([string]::IsNullOrWhiteSpace($profileLine)) { continue }
      if ($profileLine -cnotmatch '^[ \t]') {
        $topLevelLine = [regex]::Match($profileLine, '^(?<key>[a-z_][a-z0-9_]*):(?<value>[^\r\n]*)$')
        if (-not $topLevelLine.Success) {
          $canonicalProfileShapeValid = $false
          $currentProfileSection = ''
          continue
        }
        $topLevelKey = $topLevelLine.Groups['key'].Value
        $topLevelValue = $topLevelLine.Groups['value'].Value.Trim()
        if ($expectedTopLevelKeys -cnotcontains $topLevelKey -or -not $seenTopLevelKeys.Add($topLevelKey)) {
          $canonicalProfileShapeValid = $false
        }
        if ($profileSectionNames -ccontains $topLevelKey) {
          if ($topLevelValue -cne '') { $canonicalProfileShapeValid = $false }
          $currentProfileSection = $topLevelKey
        }
        elseif ($topLevelKey -ceq 'review_focus') {
          if ($topLevelValue -ceq '') {
            $reviewFocusUsesBlockList = $true
            $currentProfileSection = 'review_focus'
          }
          elseif ($topLevelValue -ceq '[]') {
            $currentProfileSection = ''
          }
          else {
            $canonicalProfileShapeValid = $false
            $currentProfileSection = ''
          }
        }
        elseif ($scalarTopLevelKeys -ccontains $topLevelKey) {
          if ($topLevelValue -ceq '' -or ($topLevelKey -ceq 'schema_version' -and $topLevelValue -cne '1')) {
            $canonicalProfileShapeValid = $false
          }
          $currentProfileSection = ''
        }
        else {
          $canonicalProfileShapeValid = $false
          $currentProfileSection = ''
        }
        continue
      }

      if ($currentProfileSection -ceq '') {
        $canonicalProfileShapeValid = $false
        continue
      }
      if ($currentProfileSection -ceq 'review_focus') {
        if ($profileLine -cmatch '^  - (?:(?:"[^"\r\n]+")|(?:''[^''\r\n]+'')|(?:[A-Za-z0-9][A-Za-z0-9 ._/-]*))$') {
          $reviewFocusItemCount++
        }
        else {
          $canonicalProfileShapeValid = $false
        }
        continue
      }
      if ($currentProfileSection -ceq 'documents') {
        if (
          $profileLine -cnotmatch '^  (?:requirements|uiux|migration|architecture):(?: \[\])?$' -and
          $profileLine -cnotmatch '^    - path: [^\r\n]+$' -and
          $profileLine -cnotmatch '^      (?:input_source|format|readability|evidence_id): [^\r\n]+$'
        ) { $canonicalProfileShapeValid = $false }
        continue
      }
      $allowedNestedKeys = @($sectionKeyShapes[$currentProfileSection] -split '\|')
      $nestedLine = [regex]::Match($profileLine, '^  (?<key>[a-z_][a-z0-9_]*):[ \t]*(?<value>[^\r\n]+)[ \t]*$')
      if (-not $nestedLine.Success -or $allowedNestedKeys -cnotcontains $nestedLine.Groups['key'].Value) {
        $canonicalProfileShapeValid = $false
      }
    }
    if ($reviewFocusUsesBlockList -and $reviewFocusItemCount -eq 0) { $canonicalProfileShapeValid = $false }
    foreach ($requiredTopLevelKey in $legacyRequiredTopLevelKeys) {
      if (-not $seenTopLevelKeys.Contains($requiredTopLevelKey)) { $canonicalProfileShapeValid = $false }
    }
    $authorityInvalid = (
      -not $canonicalProfileShapeValid -or
      @([regex]::Matches($profileText, '(?m)^schema_version:[ \t]*1[ \t]*\r?$')).Count -ne 1 -or
      @($topLevelKeys | Where-Object { $expectedTopLevelKeys -cnotcontains $_ }).Count -ne 0 -or
      @($legacyRequiredTopLevelKeys | Where-Object { $topLevelKeys -cnotcontains $_ }).Count -ne 0 -or
      @([regex]::Matches($profileText, '(?m)^(?:mode|migration_mode|architecture_policy):')).Count -ne 0 -or
      @([regex]::Matches($profileText, '(?m)^base_branch:[ \t]*[^\r\n]+[ \t]*\r?$')).Count -ne 1 -or
      @([regex]::Matches($profileText, '(?m)^test_cmd:[ \t]*[^\r\n]+[ \t]*\r?$')).Count -ne 1 -or
      @([regex]::Matches($profileText, '(?m)^lint_cmd:[ \t]*[^\r\n]+[ \t]*\r?$')).Count -ne 1 -or
      @([regex]::Matches($profileText, '(?m)^build_cmd:[ \t]*[^\r\n]+[ \t]*\r?$')).Count -ne 1 -or
      @([regex]::Matches($profileText, '(?m)^coverage_cmd:[ \t]*[^\r\n]+[ \t]*\r?$')).Count -ne 1 -or
      @([regex]::Matches($profileText, '(?m)^review_focus:[ \t]*(?:\[\])?[ \t]*\r?$')).Count -ne 1
    )
    foreach ($sectionName in $sectionKeyShapes.Keys) {
      $sectionKeys = @(& $getSectionKeys $profileSections[$sectionName])
      $sectionLines = @($profileSections[$sectionName] -split '\r?\n' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
      if (
        $null -eq $profileSections[$sectionName] -or
        ($sectionKeys -join '|') -cne $sectionKeyShapes[$sectionName] -or
        (
          $sectionName -cne 'documents' -and
          (
            $sectionLines.Count -ne $sectionKeys.Count -or
            @($sectionLines | Where-Object { $_ -cnotmatch '^  [a-z_][a-z0-9_]*:\s*[^\r\n]*$' }).Count -ne 0
          )
        )
      ) {
        $authorityInvalid = $true
      }
    }

    $projectIdMatches = @([regex]::Matches($profileSections['project'], '(?m)^  id:\s*(?<value>[A-Za-z0-9][A-Za-z0-9._-]*)\s*$'))
    $automationMatches = @([regex]::Matches($profileSections['automation'], '(?m)^  mode:\s*(?:interactive|auto|auto-waive)\s*$'))
    $outputMatches = @([regex]::Matches($profileSections['output'], '(?m)^  artifact_language:\s*vi\s*$'))
    $legacyPathMatches = @([regex]::Matches($profileSections['legacy'], '(?m)^  path:\s*(?<value>null|[A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.-]+)*)\s*$'))
    $targetPathMatches = @([regex]::Matches($profileSections['target'], '(?m)^  path:\s*(?<value>null|[A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.-]+)*)\s*$'))
    $legacyLanguageMatches = @([regex]::Matches($profileSections['legacy'], '(?m)^  language:\s*[A-Za-z0-9][A-Za-z0-9+._-]*\s*$'))
    $legacyFrameworkMatches = @([regex]::Matches($profileSections['legacy'], '(?m)^  framework:\s*[A-Za-z0-9][A-Za-z0-9+._-]*\s*$'))
    $targetLanguageMatches = @([regex]::Matches($profileSections['target'], '(?m)^  language:\s*[A-Za-z0-9][A-Za-z0-9+._-]*\s*$'))
    $targetFrameworkMatches = @([regex]::Matches($profileSections['target'], '(?m)^  framework:\s*[A-Za-z0-9][A-Za-z0-9+._-]*\s*$'))
    $isCanonicalRelativePath = {
      param([string]$Value)
      return $Value -cmatch '^[A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.-]+)*$' -and
        @($Value.Split('/') | Where-Object { $_ -cin @('.', '..') }).Count -eq 0
    }
    $legacyPathValid = $legacyPathMatches.Count -eq 1 -and (
      $legacyPathMatches[0].Groups['value'].Value -ceq 'null' -or
      (& $isCanonicalRelativePath $legacyPathMatches[0].Groups['value'].Value)
    )
    $targetPathValid = $targetPathMatches.Count -eq 1 -and (
      $targetPathMatches[0].Groups['value'].Value -ceq 'null' -or
      (& $isCanonicalRelativePath $targetPathMatches[0].Groups['value'].Value)
    )
    $verificationValid = (
      @([regex]::Matches($profileSections['verification'], '(?m)^  behavior_parity:\s*(?:required|optional)\s*$')).Count -eq 1 -and
      @([regex]::Matches($profileSections['verification'], '(?m)^  regression:\s*(?:required|optional)\s*$')).Count -eq 1 -and
      @([regex]::Matches($profileSections['verification'], '(?m)^  visual_fidelity:\s*(?:required|optional)\s*$')).Count -eq 1
    )
    if (
      $projectIdMatches.Count -ne 1 -or $automationMatches.Count -ne 1 -or $outputMatches.Count -ne 1 -or
      -not $legacyPathValid -or -not $targetPathValid -or
      $legacyLanguageMatches.Count -ne 1 -or $legacyFrameworkMatches.Count -ne 1 -or
      $targetLanguageMatches.Count -ne 1 -or $targetFrameworkMatches.Count -ne 1 -or -not $verificationValid
    ) { $authorityInvalid = $true }

    $documentEntries = [Collections.Generic.List[object]]::new()
    $documentEvidenceIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $documentCategoryNames = @('requirements', 'uiux', 'migration', 'architecture')
    foreach ($categoryName in $documentCategoryNames) {
      $categoryMatch = [regex]::Match(
        $profileSections['documents'],
        '(?ms)^  ' + [regex]::Escape($categoryName) + ':(?<value>[^\r\n]*)\r?\n(?<body>.*?)(?=^  (?:requirements|uiux|migration|architecture):|\z)'
      )
      if (-not $categoryMatch.Success) { $authorityInvalid = $true; continue }
      $categoryValue = $categoryMatch.Groups['value'].Value.Trim()
      $categoryBody = $categoryMatch.Groups['body'].Value
      if ($categoryValue -ceq '[]') {
        if (-not [string]::IsNullOrWhiteSpace($categoryBody)) { $authorityInvalid = $true }
        continue
      }
      if ($categoryValue -cne '') { $authorityInvalid = $true; continue }
      $entryMatches = @([regex]::Matches(
        $categoryBody,
        '(?ms)^    - path:\s*(?<path>[^\r\n]+)\r?\n      input_source:\s*(?<input>explicit|inbox)\s*\r?\n      format:\s*(?<format>[A-Za-z0-9][A-Za-z0-9._+-]*)\s*\r?\n      readability:\s*(?<readability>readable)\s*\r?\n      evidence_id:\s*(?<evidence>[A-Z][A-Z0-9]*(?:-[A-Z0-9]+)+)\s*(?:\r?\n|\z)'
      ))
      $consumed = ($entryMatches | ForEach-Object { $_.Value }) -join ''
      if ($entryMatches.Count -eq 0 -or $consumed.Trim() -cne $categoryBody.Trim()) { $authorityInvalid = $true; continue }
      foreach ($entryMatch in $entryMatches) {
        $entryPath = $entryMatch.Groups['path'].Value.Trim()
        $evidenceId = $entryMatch.Groups['evidence'].Value
        if (-not (& $isCanonicalRelativePath $entryPath) -or -not $documentEvidenceIds.Add($evidenceId)) {
          $authorityInvalid = $true
        }
        $documentEntries.Add([pscustomobject]@{
          Category = $categoryName
          Path = $entryPath
          InputSource = $entryMatch.Groups['input'].Value
          Format = $entryMatch.Groups['format'].Value
          Readability = $entryMatch.Groups['readability'].Value
          EvidenceId = $evidenceId
        })
      }
    }
    $modeMatches = @()
    $policyMatches = @()
    if (-not $authorityInvalid) {
      $modeMatches = @([regex]::Matches($migrationBody, '(?m)^  mode:\s*(?<value>greenfield|incremental)\s*$'))
      $unitMatches = @([regex]::Matches($migrationBody, '(?m)^  unit:\s*feature\s*$'))
      $policyMatches = @([regex]::Matches($migrationBody, '(?m)^  architecture_policy:\s*(?<value>design-new|preserve-existing)\s*$'))
      $reviewedAtMatches = @([regex]::Matches($projectPackBody, '(?m)^  reviewed_at:\s*(?<value>[^\r\n]+?)\s*$'))
      $reviewEvidenceMatches = @([regex]::Matches($projectPackBody, '(?m)^  review_evidence:\s*(?<value>[^\r\n]+?)\s*$'))
      $packPathMatches = @([regex]::Matches($projectPackBody, '(?m)^  path:\s*(?<value>docs/aitoolkit/[A-Za-z0-9_.\-/]+)\s*$'))
      $authorityInvalid = (
        $modeMatches.Count -ne 1 -or $unitMatches.Count -ne 1 -or $policyMatches.Count -ne 1 -or
        $reviewedAtMatches.Count -ne 1 -or $reviewEvidenceMatches.Count -ne 1 -or $packPathMatches.Count -ne 1
      )
    }
    if ($authorityInvalid) {
      $errors.Add('Invalid approved migration mode authority')
    }
    else {
      $approvedResponsibilityMode = $modeMatches[0].Groups['value'].Value
      $expectedPolicy = if ($approvedResponsibilityMode -ceq 'greenfield') { 'design-new' } else { 'preserve-existing' }
      if ($policyMatches[0].Groups['value'].Value -cne $expectedPolicy) {
        $errors.Add('Approved migration mode authority is internally inconsistent')
        $approvedResponsibilityMode = ''
      }

      $reviewedAt = $reviewedAtMatches[0].Groups['value'].Value.Trim()
      $reviewEvidence = $reviewEvidenceMatches[0].Groups['value'].Value.Trim().Replace('/', [IO.Path]::DirectorySeparatorChar)
      $packRelativePath = $packPathMatches[0].Groups['value'].Value.Trim().Replace('/', [IO.Path]::DirectorySeparatorChar)
      $reviewTimestamp = [DateTimeOffset]::MinValue
      $reviewTimestampValid = $reviewedAt -cmatch '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$' -and [DateTimeOffset]::TryParse($reviewedAt, [ref]$reviewTimestamp)
      $reviewPath = [IO.Path]::GetFullPath((Join-Path $Root $reviewEvidence))
      $packPath = [IO.Path]::GetFullPath((Join-Path $Root $packRelativePath))
      $rootPrefix = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
      if (
        -not $reviewTimestampValid -or -not $reviewPath.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase) -or
        -not $packPath.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase) -or
        -not (Test-Path -LiteralPath $reviewPath -PathType Leaf) -or -not (Test-Path -LiteralPath $packPath -PathType Container)
      ) {
        $errors.Add('Missing approved migration mode authority')
        $approvedResponsibilityMode = ''
      }
      else {
        $reviewText = Get-Content -Raw -Encoding utf8 -LiteralPath $reviewPath
        $frontMatterMatch = [regex]::Match($reviewText, '\A---\s*\r?\n(?<body>.*?)\r?\n---(?:\r?\n|\z)', [Text.RegularExpressions.RegexOptions]::Singleline)
        $reviewFrontMatter = if ($frontMatterMatch.Success) { $frontMatterMatch.Groups['body'].Value } else { '' }
        $reviewKeys = @([regex]::Matches($reviewFrontMatter, '(?m)^(?<key>[a-z_][a-z0-9_]*):') | ForEach-Object { $_.Groups['key'].Value } | Sort-Object)
        $freshnessTable = & $getStrictTable $reviewText 'Độ mới của review'
        $reviewApproved = (
          ($reviewKeys -join '|') -ceq 'approval_source|produced_at|result|status|step_id' -and
          @([regex]::Matches($reviewFrontMatter, '(?m)^step_id:\s*04-project-pack-review\s*$')).Count -eq 1 -and
          @([regex]::Matches($reviewFrontMatter, '(?m)^status:\s*approved\s*$')).Count -eq 1 -and
          @([regex]::Matches($reviewFrontMatter, '(?m)^result:\s*complete\s*$')).Count -eq 1 -and
          @([regex]::Matches($reviewFrontMatter, '(?m)^approval_source:\s*human\s*$')).Count -eq 1 -and
          $null -ne $freshnessTable -and
          ($freshnessTable.Columns -join '|') -ceq 'Reviewed At|Profile Revision|Pack Revision|Source/Target/Document Revisions|Approval Evidence' -and
          $freshnessTable.Rows.Count -eq 1
        )
        if (-not $reviewApproved) {
          $errors.Add('Missing approved migration mode authority')
          $approvedResponsibilityMode = ''
        }
        else {
          $freshness = $freshnessTable.Rows[0]
          $profileForRevision = [regex]::Replace($profileText, '(?m)^  reviewed_at:\s*[^\r\n]+\s*$', '  reviewed_at: <review-metadata>')
          $profileForRevision = [regex]::Replace($profileForRevision, '(?m)^  review_evidence:\s*[^\r\n]+\s*$', '  review_evidence: <review-metadata>')
          $expectedProfileRevision = & $getTextRevision $profileForRevision
          $expectedPackRevision = & $getTreeRevision $packPath
          $citationSpecs = [Collections.Generic.List[object]]::new()
          $legacyPathValue = $legacyPathMatches[0].Groups['value'].Value
          $targetPathValue = $targetPathMatches[0].Groups['value'].Value
          if ($legacyPathValue -cne 'null') { $citationSpecs.Add([pscustomobject]@{ Kind = 'legacy'; Path = $legacyPathValue; EvidenceId = '' }) }
          if ($targetPathValue -cne 'null') { $citationSpecs.Add([pscustomobject]@{ Kind = 'target'; Path = $targetPathValue; EvidenceId = '' }) }
          foreach ($entry in $documentEntries) { $citationSpecs.Add([pscustomobject]@{ Kind = 'document'; Path = $entry.Path; EvidenceId = $entry.EvidenceId }) }

          $citationRevisionParts = [Collections.Generic.List[string]]::new()
          $citationRevisionsValid = $true
          foreach ($citation in $citationSpecs) {
            $citationFullPath = [IO.Path]::GetFullPath((Join-Path $Root $citation.Path.Replace('/', [IO.Path]::DirectorySeparatorChar)))
            if (-not $citationFullPath.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $citationFullPath)) {
              $citationRevisionsValid = $false
              continue
            }
            $citationRevision = if (Test-Path -LiteralPath $citationFullPath -PathType Container) {
              & $getTreeRevision $citationFullPath
            }
            elseif (Test-Path -LiteralPath $citationFullPath -PathType Leaf) {
              & $getTextRevision (Get-Content -Raw -Encoding utf8 -LiteralPath $citationFullPath)
            }
            else {
              $citationRevisionsValid = $false
              ''
            }
            if ([string]::IsNullOrWhiteSpace($citationRevision)) { continue }
            $citationLabel = if ($citation.Kind -ceq 'document') {
              "document:$($citation.EvidenceId):$($citation.Path)@$citationRevision"
            }
            else {
              "$($citation.Kind):$($citation.Path)@$citationRevision"
            }
            $citationRevisionParts.Add($citationLabel)
          }
          $expectedCitationRevisions = if ($citationRevisionParts.Count -eq 0) { 'not-applicable' } else { $citationRevisionParts -join '; ' }

          $documentEvidenceValid = $true
          if ($documentEntries.Count -gt 0) {
            $documentEvidenceTable = & $getStrictTable $reviewText 'Bằng chứng tài liệu profile'
            $documentEvidenceValid = (
              $null -ne $documentEvidenceTable -and
              ($documentEvidenceTable.Columns -join '|') -ceq 'Category|Canonical Path|Input Source|Format|Readability|Evidence ID' -and
              $documentEvidenceTable.Rows.Count -eq $documentEntries.Count
            )
            if ($documentEvidenceValid) {
              foreach ($entry in $documentEntries) {
                $matches = @($documentEvidenceTable.Rows | Where-Object {
                  $_.Category -ceq $entry.Category -and $_.'Canonical Path' -ceq $entry.Path -and
                  $_.'Input Source' -ceq $entry.InputSource -and $_.Format -ceq $entry.Format -and
                  $_.Readability -ceq $entry.Readability -and $_.'Evidence ID' -ceq $entry.EvidenceId
                })
                if ($matches.Count -ne 1) { $documentEvidenceValid = $false; break }
              }
            }
          }
          if (
            $freshness.'Reviewed At' -cne $reviewedAt -or
            $freshness.'Profile Revision' -cne $expectedProfileRevision -or
            $freshness.'Pack Revision' -cne $expectedPackRevision -or
            -not $citationRevisionsValid -or -not $documentEvidenceValid -or
            $freshness.'Source/Target/Document Revisions' -cne $expectedCitationRevisions -or
            $freshness.'Approval Evidence' -cnotmatch '^approval:TECH-LEAD-(?![^\r\n]*(?:PENDING|TBD|UNKNOWN|PLACEHOLDER))[A-Z0-9]+(?:-[A-Z0-9]+)*$'
          ) {
            $errors.Add('Stale approved migration mode authority')
            $approvedResponsibilityMode = ''
          }
        }
      }
    }
  }
  if (Test-Path -LiteralPath $designPath -PathType Leaf) {
    $modeAuthorityText = Get-Content -Raw -Encoding utf8 -LiteralPath $designPath
    $modeAuthorityTable = & $getTable $modeAuthorityText 'Architecture'
    if ($null -ne $modeAuthorityTable -and ($modeAuthorityTable.Columns -join '|') -ceq 'Mode / Policy|Target Conformance / New Architecture|Trace IDs|Decision') {
      $modeRows = @($modeAuthorityTable.Rows | Where-Object { $_.'Mode / Policy' -cmatch '^(?:greenfield|greenfield\s*/\s*design-new|incremental|incremental\s*/\s*preserve-existing)$' })
      if ($modeRows.Count -ne 1) {
        $errors.Add('Technical design Architecture mode policy must resolve exactly one canonical mode')
      }
      else {
        $designMode = if ($modeRows[0].'Mode / Policy' -cmatch '^(?:greenfield|greenfield\s*/\s*design-new)$') { 'greenfield' } else { 'incremental' }
        if ($approvedResponsibilityMode -ne '' -and $designMode -cne $approvedResponsibilityMode) {
          $errors.Add('Technical design Architecture mode policy must match approved project mode')
        }
      }
    }
  }
  if (Test-Path -LiteralPath $discoveryPath -PathType Leaf) {
    $discoveryText = Get-Content -Raw -Encoding utf8 -LiteralPath $discoveryPath
    $responsibilityContractPath = Join-Path $PSScriptRoot '../../contracts/file-responsibility-conformance.md'
    if (-not (Test-Path -LiteralPath $responsibilityContractPath -PathType Leaf)) {
      $errors.Add('Missing responsibility conformance contract resource')
    }
    else {
      $responsibilityContractText = Get-Content -Raw -Encoding utf8 -LiteralPath $responsibilityContractPath
      $responsibilityDiagnostics = @(& {
        . (Join-Path $PSScriptRoot 'responsibility-conformance.validation.ps1')
        if ($approvedResponsibilityMode -ne '') {
          Test-ResponsibilityDiscovery -DiscoveryText $discoveryText -Mode $approvedResponsibilityMode -ContractText $responsibilityContractText
        }
      })
      $responsibilityDiagnostics | ForEach-Object {
        $errors.Add($_)
      }
    }
    $discoveryTable = & $getTable $discoveryText 'Comparable Target Exemplars'
    if ($null -eq $discoveryTable) {
      $errors.Add('Discovery missing Comparable Target Exemplars')
    }
    else {
      $discoveryExemplarColumns = @(
        'Concern', 'Path', 'Inspected Symbols', 'Observed Pattern', 'Primary Responsibility',
        'Owned Capabilities', 'Verification Owner', 'Comparable Reason', 'Evidence',
        'Inspection Status', 'Classification', 'Classification Authority', 'Classification Evidence'
      )
      if (($discoveryTable.Columns -join '|') -cne ($discoveryExemplarColumns -join '|')) {
        $errors.Add("Discovery Comparable Target Exemplars table columns must be exactly: $($discoveryExemplarColumns -join ' | ')")
      }
      if ($discoveryTable.Rows.Count -ne $canonicalConcerns.Count) {
        $errors.Add("Discovery concern cardinality must equal canonical eight; found $($discoveryTable.Rows.Count)")
      }
      @($discoveryTable.Rows | Where-Object { $_.Concern -cnotin $canonicalConcerns }) | ForEach-Object {
        $errors.Add("Discovery unexpected concern: $($_.Concern)")
      }
      foreach ($concern in $canonicalConcerns) {
        $matchingRows = @($discoveryTable.Rows | Where-Object { $_.Concern -ceq $concern })
        if ($matchingRows.Count -eq 0) {
          $errors.Add("Discovery missing applicable concern: $concern")
          continue
        }
        if ($matchingRows.Count -gt 1) {
          $errors.Add("Discovery concern must appear exactly once: $concern")
          continue
        }
        $row = $matchingRows[0]
        foreach ($requiredColumn in @('Path', 'Observed Pattern', 'Comparable Reason', 'Evidence')) {
          if (& $isMissingValue $row.$requiredColumn) {
            $errors.Add("Discovery $concern $requiredColumn must not be blank")
          }
        }
        $capabilityTokens = @(
          $row.'Owned Capabilities'.Split([char[]]@(',', ';')) |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ -ne '' }
        )
        if (
          (& $isMissingValue $row.'Primary Responsibility') -or
          $capabilityTokens.Count -eq 0 -or
          @($capabilityTokens | Where-Object { $_ -cnotmatch '^CAP-[A-Z0-9]+(?:-[A-Z0-9]+)*$' }).Count -gt 0 -or
          @($capabilityTokens | Sort-Object -Unique).Count -ne $capabilityTokens.Count -or
          (& $isMissingValue $row.'Verification Owner') -or
          $row.'Verification Owner' -cnotmatch '^VERIFY-OWNER-[A-Z0-9]+(?:-[A-Z0-9]+)*$'
        ) {
          $errors.Add("Discovery $concern responsibility fields must include primary responsibility, canonical CAP-* list, and VERIFY-OWNER-*")
        }
        if (& $isMissingValue $row.'Inspected Symbols') {
          $errors.Add("Discovery $concern Inspected Symbols must not be blank")
        }
        else {
          $symbolTokens = @(
            $row.'Inspected Symbols'.Split([char[]]@(',', ';')) |
              ForEach-Object { $_.Trim() }
          )
          $invalidSymbolTokens = @($symbolTokens | Where-Object {
            [string]::IsNullOrWhiteSpace($_) -or
            $_ -cnotmatch $explicitSymbolPattern -or
            $_ -match $genericSymbolTokenPattern
          })
          if ($invalidSymbolTokens.Count -gt 0) {
            $errors.Add("Discovery $concern Inspected Symbols must contain only explicit symbol tokens")
          }
        }
        if ($row.'Comparable Reason' -match '^(?i:not comparable|non-comparable|generic|same technology|uses?\s+\S+)$') {
          $errors.Add("Discovery $concern Comparable Reason must explain comparability")
        }
        if ($row.'Inspection Status' -ceq 'unknown') {
          $errors.Add("Discovery $concern unknown status blocks discovery")
        }
        elseif ($row.'Inspection Status' -cnotin @('verified', 'no-equivalent')) {
          $errors.Add("Discovery $concern has invalid exemplar status: $($row.'Inspection Status')")
        }
      }

      $noEquivalentRows = @($discoveryTable.Rows | Where-Object { $_.'Inspection Status' -ceq 'no-equivalent' })
      if ($noEquivalentRows.Count -gt 0) {
        $gapTable = & $getTable $discoveryText 'No-equivalent Gaps'
        $gapColumns = @('Concern', 'Gap Reference', 'Conflict Reference', 'Resolved Decision', 'Approval Reference')
        if ($null -eq $gapTable -or ($gapTable.Columns -join '|') -cne ($gapColumns -join '|')) {
          $errors.Add("Discovery No-equivalent Gaps table columns must be exactly: $($gapColumns -join ' | ')")
        }
        else {
          foreach ($noEquivalentRow in $noEquivalentRows) {
            $gapRows = @($gapTable.Rows | Where-Object { $_.Concern -ceq $noEquivalentRow.Concern })
            $resolvedGap = if ($gapRows.Count -eq 1) { $gapRows[0] } else { $null }
            if (
              $null -eq $resolvedGap -or
              $resolvedGap.'Gap Reference' -cnotmatch '^GAP-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -or
              $resolvedGap.'Conflict Reference' -cnotmatch '^CONFLICT-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -or
              $resolvedGap.'Resolved Decision' -cnotmatch $decisionPattern -or
              $resolvedGap.'Resolved Decision' -match $semanticPlaceholderPattern -or
              $resolvedGap.'Approval Reference' -cnotmatch $techLeadApprovalPattern -or
              $resolvedGap.'Approval Reference' -match $semanticPlaceholderPattern
            ) {
              $errors.Add("Discovery no-equivalent concern requires a resolved gap/conflict decision: $($noEquivalentRow.Concern)")
            }
          }
        }
      }
    }

    $inspectedTable = & $getTable $discoveryText 'Inspected Symbols'
    $inspectedColumns = @('Concern', 'Path', 'Symbol', 'Inspection Scope', 'Evidence')
    if ($null -eq $inspectedTable) {
      $errors.Add('Discovery missing Inspected Symbols')
    }
    elseif (($inspectedTable.Columns -join '|') -cne ($inspectedColumns -join '|')) {
      $errors.Add("Discovery Inspected Symbols table columns must be exactly: $($inspectedColumns -join ' | ')")
    }
    elseif ($inspectedTable.Rows.Count -eq 0) {
      $errors.Add('Discovery Inspected Symbols requires at least one evidence row')
    }
    else {
      foreach ($inspectedRow in $inspectedTable.Rows) {
        $invalidInspectedValue = $false
        foreach ($column in $inspectedColumns) {
          if (& $isMissingValue $inspectedRow.$column) { $invalidInspectedValue = $true }
        }
        if (
          $invalidInspectedValue -or
          $inspectedRow.Symbol -cnotmatch $explicitSymbolPattern -or
          $inspectedRow.Symbol -match $genericSymbolTokenPattern
        ) {
          $errors.Add('Discovery Inspected Symbols rows require explicit path, symbol, scope, and evidence')
        }
      }
    }

    $dataFlowTable = & $getTable $discoveryText 'Target Data-flow Trace'
    $dataFlowColumns = @('Stage', 'Path/Symbol', 'Input', 'Transformation', 'Output/Consumer', 'Evidence')
    if ($null -eq $dataFlowTable) {
      $errors.Add('Discovery missing Target Data-flow Trace')
    }
    elseif (($dataFlowTable.Columns -join '|') -cne ($dataFlowColumns -join '|')) {
      $errors.Add("Discovery Target Data-flow Trace table columns must be exactly: $($dataFlowColumns -join ' | ')")
    }
    elseif ($dataFlowTable.Rows.Count -eq 0) {
      $errors.Add('Discovery Target Data-flow Trace requires at least one evidence row')
    }
    else {
      $requiredFlowStages = @('source', 'subscription', 'normalization', 'state', 'selection', 'render', 'test')
      $actualFlowStages = @($dataFlowTable.Rows | ForEach-Object { $_.Stage })
      if (($actualFlowStages -join '|') -cne ($requiredFlowStages -join '|')) {
        $errors.Add('Discovery Target Data-flow Trace must cover ordered end-to-end stages: source -> subscription -> normalization -> state -> selection -> render -> test')
      }
      for ($flowIndex = 1; $flowIndex -lt $dataFlowTable.Rows.Count; $flowIndex++) {
        if ($dataFlowTable.Rows[$flowIndex - 1].'Output/Consumer' -cne $dataFlowTable.Rows[$flowIndex].Input) {
          $errors.Add('Discovery Target Data-flow Trace must connect each stage output to the next stage input')
        }
      }
      foreach ($flowRow in $dataFlowTable.Rows) {
        $pathSymbolMatch = [regex]::Match($flowRow.'Path/Symbol', $pathSymbolPattern)
        $transformationMatch = [regex]::Match(
          $flowRow.Transformation,
          '^operation=(?<operation>[A-Za-z_][A-Za-z0-9_]*);\s*owner=(?<owner>.+)$'
        )
        $ownerMatch = if ($transformationMatch.Success) {
          [regex]::Match($transformationMatch.Groups['owner'].Value, $pathSymbolPattern)
        }
        else {
          $null
        }
        if (
          (& $isMissingValue $flowRow.Stage) -or
          (& $isMissingValue $flowRow.'Path/Symbol') -or
          -not $pathSymbolMatch.Success -or
          $pathSymbolMatch.Groups['path'].Value -match '(?:^|[\\/])\.\.(?:[\\/]|$)' -or
          (& $isMissingValue $flowRow.Input) -or
          (& $isMissingValue $flowRow.Transformation) -or
          (& $isMissingValue $flowRow.'Output/Consumer') -or
          (& $isMissingValue $flowRow.Evidence) -or
          $flowRow.Evidence -cnotmatch '[:#][A-Za-z0-9-]+'
        ) {
          $errors.Add('Discovery Target Data-flow Trace requires meaningful endpoints and evidence')
        }
        if (
          -not $transformationMatch.Success -or
          $null -eq $ownerMatch -or
          -not $ownerMatch.Success -or
          $ownerMatch.Groups['path'].Value -match '(?:^|[\\/])\.\.(?:[\\/]|$)'
        ) {
          $errors.Add('Discovery Target Data-flow Trace requires structured operation and owner evidence')
        }
      }
    }

    $gapTable = & $getTable $discoveryText 'No-equivalent Gaps'
    $gapColumns = @('Concern', 'Gap Reference', 'Conflict Reference', 'Resolved Decision', 'Approval Reference')
    if ($null -eq $gapTable) {
      $errors.Add('Discovery missing No-equivalent Gaps')
    }
    elseif (($gapTable.Columns -join '|') -cne ($gapColumns -join '|')) {
      $errors.Add("Discovery No-equivalent Gaps table columns must be exactly: $($gapColumns -join ' | ')")
    }
    else {
      $noEquivalentConcerns = @($discoveryTable.Rows | Where-Object { $_.'Inspection Status' -ceq 'no-equivalent' } | ForEach-Object { $_.Concern })
      $realGapRows = @($gapTable.Rows | Where-Object { $_.Concern -cne 'none' })
      $sentinelRows = @($gapTable.Rows | Where-Object { $_.Concern -ceq 'none' })
      $gapConcernSet = @($realGapRows | ForEach-Object { $_.Concern } | Sort-Object)
      $statusConcernSet = @($noEquivalentConcerns | Sort-Object)
      $gapSetsMatch = (($gapConcernSet -join '|') -ceq ($statusConcernSet -join '|'))
      if (
        $realGapRows.Count -ne $noEquivalentConcerns.Count -or
        -not $gapSetsMatch -or
        ($noEquivalentConcerns.Count -eq 0 -and $sentinelRows.Count -ne 1) -or
        ($noEquivalentConcerns.Count -gt 0 -and $sentinelRows.Count -ne 0)
      ) {
        $errors.Add('Discovery No-equivalent Gaps must match no-equivalent statuses exactly')
      }
      elseif ($noEquivalentConcerns.Count -eq 0) {
        $sentinel = $sentinelRows[0]
        if (
          $sentinel.'Gap Reference' -cne 'not-applicable' -or
          $sentinel.'Conflict Reference' -cne 'not-applicable' -or
          $sentinel.'Resolved Decision' -cne 'not-applicable' -or
          $sentinel.'Approval Reference' -cne 'not-applicable'
        ) {
          $errors.Add('Discovery No-equivalent Gaps sentinel must be canonical')
        }
      }
    }
  }

  $designPath = Join-Path $Root '07-technical-design.md'
  if (Test-Path -LiteralPath $designPath -PathType Leaf) {
    $designText = Get-Content -Raw -Encoding utf8 -LiteralPath $designPath
    $approvedPlanTable = & $getTable $designText 'Approved Master Plan Evidence'
    $approvedPlanColumns = @(
      'Master Plan Reference', 'Master Plan ID', 'Revision', 'Status', 'Work Item ID',
      'Acceptance', 'Trace IDs', 'Delivery Adapter', 'Decomposition Decision Reference',
      'Approval Reference', 'Evidence Reference'
    )
    $approvedPlanRow = $null
    if ($null -eq $approvedPlanTable) {
      $errors.Add('Technical design missing Approved Master Plan Evidence')
    }
    elseif (
      ($approvedPlanTable.Columns -join '|') -cne ($approvedPlanColumns -join '|') -or
      $approvedPlanTable.Rows.Count -ne 1
    ) {
      $errors.Add("Technical design Approved Master Plan Evidence table columns must be exactly: $($approvedPlanColumns -join ' | ') and contain exactly one approved plan row")
    }
    else {
      $approvedPlanRow = $approvedPlanTable.Rows[0]
      $approvedPlanMatch = [regex]::Match(
        $approvedPlanRow.'Master Plan Reference',
        '^master-plan\.md#(?<id>PLAN-(?<scope>[A-Z0-9]+)(?:-[A-Z0-9]+)+)$'
      )
      $approvedWorkMatch = [regex]::Match(
        $approvedPlanRow.'Work Item ID',
        '^WORK-(?<scope>[A-Z0-9]+)(?:-[A-Z0-9]+)+$'
      )
      $approvedAcceptance = & $parseCanonicalAcceptance $approvedPlanRow.Acceptance
      $approvedDecomposition = $approvedPlanRow.'Decomposition Decision Reference'
      $approvedTraceIds = @(
        $approvedPlanRow.'Trace IDs'.Split(',') |
          ForEach-Object { $_.Trim() } |
          Where-Object { $_ -ne '' }
      )
      $expectedPlanEvidenceReference = "$($approvedPlanRow.'Master Plan Reference')@revision=$($approvedPlanRow.Revision):$($approvedPlanRow.'Work Item ID')"
      if (
        -not $approvedPlanMatch.Success -or
        $approvedPlanRow.'Master Plan ID' -cne $approvedPlanMatch.Groups['id'].Value -or
        $approvedPlanRow.Revision -cnotmatch '^[1-9][0-9]*$' -or
        $approvedPlanRow.Status -cne 'approved' -or
        -not $approvedWorkMatch.Success -or
        $approvedWorkMatch.Groups['scope'].Value -cne $approvedPlanMatch.Groups['scope'].Value -or
        -not $approvedAcceptance.Valid -or
        $approvedTraceIds.Count -eq 0 -or
        @($approvedTraceIds | Where-Object { $_ -cnotmatch '^[A-Z][A-Z0-9]*(?:-[A-Z0-9]+)+$' }).Count -gt 0 -or
        @($approvedTraceIds | Sort-Object -Unique).Count -ne $approvedTraceIds.Count -or
        [string]::IsNullOrWhiteSpace($approvedPlanRow.'Delivery Adapter') -or
        $approvedPlanRow.'Delivery Adapter' -match '^\s*<[^>]+>\s*$' -or
        ($approvedPlanRow.'Delivery Adapter' -match $semanticPlaceholderPattern -and $approvedPlanRow.'Delivery Adapter' -cne 'none') -or
        $approvedDecomposition -cnotmatch '^(?:not-applicable|DEC-[A-Z0-9]+(?:-[A-Z0-9]+)*)$' -or
        ($approvedDecomposition -match $semanticPlaceholderPattern -and $approvedDecomposition -cne 'not-applicable') -or
        $approvedPlanRow.'Approval Reference' -cnotmatch $techLeadApprovalPattern -or
        $approvedPlanRow.'Approval Reference' -match $semanticPlaceholderPattern -or
        $approvedPlanRow.'Evidence Reference' -cne $expectedPlanEvidenceReference
      ) {
        $errors.Add('Technical design Approved Master Plan Evidence must resolve one canonical approved plan/work-item row')
      }
    }
    $workItemTrace = & $getTable $designText 'Work Item Trace'
    $workItemTraceColumns = @(
      'Work Item ID', 'Master Plan Reference', 'Master Plan Revision',
      'Acceptance Traces', 'Decomposition Decision Reference'
    )
    $workItemRow = $null
    if ($null -eq $workItemTrace) {
      $errors.Add('Technical design missing Work Item Trace')
    }
    elseif (
      ($workItemTrace.Columns -join '|') -cne ($workItemTraceColumns -join '|') -or
      $workItemTrace.Rows.Count -ne 1
    ) {
      $errors.Add("Technical design Work Item Trace table columns must be exactly: $($workItemTraceColumns -join ' | ') and contain exactly one work item")
    }
    else {
      $workItemRow = $workItemTrace.Rows[0]
      $workItemMatch = [regex]::Match($workItemRow.'Work Item ID', '^WORK-(?<scope>[A-Z0-9]+)(?:-[A-Z0-9]+)+$')
      if (-not $workItemMatch.Success) {
        $errors.Add('Technical design Work Item Trace requires a canonical Work Item ID')
      }
      $masterPlanMatch = [regex]::Match(
        $workItemRow.'Master Plan Reference',
        '^master-plan\.md#PLAN-(?<scope>[A-Z0-9]+)(?:-[A-Z0-9]+)+$'
      )
      if (-not $masterPlanMatch.Success) {
        $errors.Add('Technical design Work Item Trace requires a canonical master-plan reference')
      }
      elseif ($workItemMatch.Success -and $workItemMatch.Groups['scope'].Value -cne $masterPlanMatch.Groups['scope'].Value) {
        $errors.Add('Technical design Work Item Trace work item and master plan must bind the same scope')
      }
      if ($workItemRow.'Master Plan Revision' -cnotmatch '^[1-9][0-9]*$') {
        $errors.Add('Technical design Work Item Trace requires a positive master-plan revision')
      }
      $acceptanceTraceIds = @(
        $workItemRow.'Acceptance Traces'.Split(',') |
          ForEach-Object { $_.Trim() } |
          Where-Object { $_ -ne '' }
      )
      $invalidAcceptanceIds = @($acceptanceTraceIds | Where-Object { $_ -cnotmatch $canonicalAcceptanceTracePattern })
      if (
        $acceptanceTraceIds.Count -eq 0 -or
        $invalidAcceptanceIds.Count -gt 0 -or
        @($acceptanceTraceIds | Sort-Object -Unique).Count -ne $acceptanceTraceIds.Count
      ) {
        $errors.Add('Technical design Work Item Trace requires only canonical acceptance trace IDs')
      }
      if (
        $workItemRow.'Decomposition Decision Reference' -cnotmatch '^(?:not-applicable|DEC-[A-Z0-9]+(?:-[A-Z0-9]+)*)$' -or
        $workItemRow.'Decomposition Decision Reference' -match '^DEC-(?:NONE|UNKNOWN|PENDING|NOT-APPLICABLE)$'
      ) {
        $errors.Add('Technical design Work Item Trace requires a decomposition decision reference or not-applicable')
      }
      if (
        $null -ne $approvedPlanRow -and (
          $workItemRow.'Work Item ID' -cne $approvedPlanRow.'Work Item ID' -or
          $workItemRow.'Master Plan Reference' -cne $approvedPlanRow.'Master Plan Reference' -or
          $workItemRow.'Master Plan Revision' -cne $approvedPlanRow.Revision -or
          ($acceptanceTraceIds -join '|') -cne (@($approvedAcceptance.References) -join '|') -or
          $workItemRow.'Decomposition Decision Reference' -cne $approvedPlanRow.'Decomposition Decision Reference'
        )
      ) {
        $errors.Add('Technical design Work Item Trace must match approved master-plan evidence exactly')
      }
    }
    if ($null -ne $workItemRow) {
      $externalReferenceMatch = [regex]::Match(
        $workItemRow.'Master Plan Reference',
        '^(?<path>master-plan\.md)#(?<id>PLAN-[A-Z0-9]+(?:-[A-Z0-9]+)+)$'
      )
      $externalPlanValid = $externalReferenceMatch.Success
      if ($externalPlanValid) {
        $externalPlanPath = Join-Path $Root $externalReferenceMatch.Groups['path'].Value
        if (-not (Test-Path -LiteralPath $externalPlanPath -PathType Leaf)) {
          $externalPlanValid = $false
        }
        else {
          $externalPlanText = (Get-Content -Raw -Encoding utf8 -LiteralPath $externalPlanPath).Replace("`r`n", "`n").Replace("`r", "`n")
          $externalPlanId = $externalReferenceMatch.Groups['id'].Value
          $externalFrontMatter = [ordered]@{}
          $externalFrontMatterFields = @(
            'artifact_type', 'master_plan_id', 'master_spec_id', 'master_spec_revision',
            'revision', 'status', 'scope_status', 'execution_policy', 'max_concurrency',
            'produced_at', 'supersedes'
          )
          $externalFrontMatterMatch = [regex]::Match(
            $externalPlanText,
            '(?s)\A---\n(?<body>.*?)\n---(?:\n|\z)'
          )
          if (-not $externalFrontMatterMatch.Success) {
            $externalPlanValid = $false
          }
          else {
            foreach ($frontMatterLine in @($externalFrontMatterMatch.Groups['body'].Value -split '\n')) {
              if ($frontMatterLine -notmatch '^(?<key>[a-z_]+):[ \t]*(?<value>.*)$') {
                $externalPlanValid = $false
                continue
              }
              $frontMatterKey = $Matches['key']
              $frontMatterValue = $Matches['value'].Trim()
              if ($externalFrontMatter.Contains($frontMatterKey) -or [string]::IsNullOrWhiteSpace($frontMatterValue)) {
                $externalPlanValid = $false
                continue
              }
              $externalFrontMatter[$frontMatterKey] = $frontMatterValue
            }
            if ((@($externalFrontMatter.Keys) -join '|') -cne ($externalFrontMatterFields -join '|')) {
              $externalPlanValid = $false
            }
          }

          $externalPlanIdMatch = if ($externalFrontMatter.Contains('master_plan_id')) {
            [regex]::Match($externalFrontMatter['master_plan_id'], '^PLAN-(?<scope>[A-Z0-9]+)(?:-[A-Z0-9]+)+$')
          }
          else {
            $null
          }
          $externalSpecIdMatch = if ($externalFrontMatter.Contains('master_spec_id')) {
            [regex]::Match($externalFrontMatter['master_spec_id'], '^SPEC-(?<scope>[A-Z0-9]+)(?:-[A-Z0-9]+)+$')
          }
          else {
            $null
          }
          $externalPlanScope = if ($null -ne $externalPlanIdMatch -and $externalPlanIdMatch.Success) {
            $externalPlanIdMatch.Groups['scope'].Value
          }
          else {
            ''
          }
          $externalSpecScope = if ($null -ne $externalSpecIdMatch -and $externalSpecIdMatch.Success) {
            $externalSpecIdMatch.Groups['scope'].Value
          }
          else {
            ''
          }
          $externalRevision = if ($externalFrontMatter.Contains('revision')) { $externalFrontMatter['revision'] } else { '' }
          $expectedSupersedes = if ($externalRevision -ceq '1') {
            'not-applicable'
          }
          elseif ($externalRevision -match '^[2-9][0-9]*$') {
            "$externalPlanId@$([int]$externalRevision - 1)"
          }
          else {
            ''
          }
          if (
            $null -eq $externalPlanIdMatch -or -not $externalPlanIdMatch.Success -or
            $null -eq $externalSpecIdMatch -or -not $externalSpecIdMatch.Success -or
            $externalFrontMatter['artifact_type'] -cne 'migration-master-plan' -or
            $externalFrontMatter['master_plan_id'] -cne $externalPlanId -or
            $externalSpecScope -cne $externalPlanScope -or
            $externalFrontMatter['master_spec_revision'] -cnotmatch '^[1-9][0-9]*$' -or
            $externalRevision -cnotmatch '^[1-9][0-9]*$' -or
            $externalRevision -cne $workItemRow.'Master Plan Revision' -or
            $externalFrontMatter['status'] -cne 'approved' -or
            $externalFrontMatter['scope_status'] -cnotin @('planned', 'scope-in-progress', 'scope-blocked', 'scope-complete', 'scope-cancelled-approved') -or
            $externalFrontMatter['execution_policy'] -cne 'dependency-ready' -or
            $externalFrontMatter['max_concurrency'] -cne '1' -or
            $externalFrontMatter['produced_at'] -cnotmatch '^\d{4}-\d{2}-\d{2}$' -or
            $externalFrontMatter['supersedes'] -cne $expectedSupersedes -or
            ($null -ne $approvedPlanRow -and (
              $approvedPlanRow.'Master Plan ID' -cne $externalPlanId -or
              $approvedPlanRow.Revision -cne $externalRevision -or
              $approvedPlanRow.Status -cne $externalFrontMatter['status']
            ))
          ) {
            $externalPlanValid = $false
          }

          $scopeContractPath = Join-Path $Root 'contracts/migration-scope-orchestration.md'
          $scopeContractTable = $null
          if (Test-Path -LiteralPath $scopeContractPath -PathType Leaf) {
            $scopeContractText = Get-Content -Raw -Encoding utf8 -LiteralPath $scopeContractPath
            $scopeContractTable = & $getTable $scopeContractText 'Work Item'
          }
          $externalWorkItemsHeadingCount = @([regex]::Matches($externalPlanText, '(?m)^## Work Items[ \t]*$')).Count
          $externalApprovalHeadingCount = @([regex]::Matches($externalPlanText, '(?m)^## Approval Record[ \t]*$')).Count
          $externalRevisionHeadingCount = @([regex]::Matches($externalPlanText, '(?m)^## Revision History[ \t]*$')).Count
          $externalWorkItemsTable = & $getStrictTable $externalPlanText 'Work Items'
          $externalApprovalTable = & $getStrictTable $externalPlanText 'Approval Record'
          $externalRevisionTable = & $getStrictTable $externalPlanText 'Revision History'
          $externalRevisionMatches = @()
          if (
            $null -eq $scopeContractTable -or
            $externalWorkItemsHeadingCount -ne 1 -or
            $externalApprovalHeadingCount -ne 1 -or
            $externalRevisionHeadingCount -ne 1 -or
            $null -eq $externalWorkItemsTable -or
            ($externalWorkItemsTable.Columns -join '|') -cne ($scopeContractTable.Columns -join '|') -or
            $null -eq $externalApprovalTable -or
            ($externalApprovalTable.Columns -join '|') -cne ('Approval Reference|Status|Approved At') -or
            $null -eq $externalRevisionTable -or
            ($externalRevisionTable.Columns -join '|') -cne ('Artifact ID|Revision|Supersedes|Change Summary|Affected Work Items|Approval Reference')
          ) {
            $externalPlanValid = $false
          }
          else {
            $externalWorkItemMatches = @($externalWorkItemsTable.Rows | Where-Object {
              $_.'Work Item ID' -ceq $workItemRow.'Work Item ID'
            })
            if ($externalWorkItemMatches.Count -ne 1) {
              $externalPlanValid = $false
            }
            else {
              $externalWorkItem = $externalWorkItemMatches[0]
              $externalWorkItemIdMatch = [regex]::Match(
                $externalWorkItem.'Work Item ID',
                '^WORK-(?<scope>[A-Z0-9]+)(?:-[A-Z0-9]+)+$'
              )
              $externalTraceIds = @(
                $externalWorkItem.'Trace IDs'.Split(',') |
                  ForEach-Object { $_.Trim() } |
                  Where-Object { $_ -ne '' }
              )
              $externalAcceptance = & $parseCanonicalAcceptance $externalWorkItem.Acceptance
              $externalApprovalMatches = @($externalApprovalTable.Rows | Where-Object {
                $_.'Approval Reference' -ceq $externalWorkItem.'Approval Reference' -and
                $_.Status -ceq 'approved'
              })
              $externalRevisionMatches = @($externalRevisionTable.Rows | Where-Object {
                $_.'Artifact ID' -ceq $externalPlanId -and
                $_.Revision -ceq $externalRevision
              })
              if (
                -not $externalWorkItemIdMatch.Success -or
                $externalWorkItemIdMatch.Groups['scope'].Value -cne $externalPlanScope -or
                [string]::IsNullOrWhiteSpace($externalWorkItem.Title) -or
                $externalWorkItem.Required -cnotin @('yes', 'no') -or
                [string]::IsNullOrWhiteSpace($externalWorkItem.Dependencies) -or
                $externalWorkItem.'Plan Order' -cnotmatch '^[1-9][0-9]*$' -or
                -not $externalAcceptance.Valid -or
                (@($externalAcceptance.References) -join '|') -cne ($acceptanceTraceIds -join '|') -or
                $externalTraceIds.Count -eq 0 -or
                @($externalTraceIds | Where-Object { $_ -cnotmatch '^[A-Z][A-Z0-9]*(?:-[A-Z0-9]+)+$' }).Count -gt 0 -or
                @($externalTraceIds | Sort-Object -Unique).Count -ne $externalTraceIds.Count -or
                $externalWorkItem.Status -cnotin @('pending', 'ready', 'in-progress', 'blocked', 'complete') -or
                [string]::IsNullOrWhiteSpace($externalWorkItem.'Latest Attempt') -or
                [string]::IsNullOrWhiteSpace($externalWorkItem.'Terminal Evidence') -or
                $externalWorkItem.'Approval Reference' -cnotmatch $techLeadApprovalPattern -or
                $externalWorkItem.'Approval Reference' -match $semanticPlaceholderPattern -or
                $externalApprovalMatches.Count -ne 1 -or
                $externalApprovalMatches[0].'Approved At' -cnotmatch '^\d{4}-\d{2}-\d{2}$' -or
                $externalRevisionMatches.Count -ne 1 -or
                $externalRevisionMatches[0].Supersedes -cne $expectedSupersedes -or
                $externalRevisionMatches[0].'Approval Reference' -cne $externalWorkItem.'Approval Reference' -or
                ($null -ne $approvedPlanRow -and (
                  $approvedPlanRow.'Work Item ID' -cne $externalWorkItem.'Work Item ID' -or
                  $approvedPlanRow.Acceptance -cne $externalWorkItem.Acceptance -or
                  $approvedPlanRow.'Trace IDs' -cne $externalWorkItem.'Trace IDs' -or
                  $approvedPlanRow.'Delivery Adapter' -cne $externalWorkItem.'Delivery Adapter' -or
                  $approvedPlanRow.'Approval Reference' -cne $externalWorkItem.'Approval Reference'
                ))
              ) {
                $externalPlanValid = $false
              }
            }
          }

          if ($null -ne $externalWorkItemsTable) {
            $externalWorkItemsSection = & $getSection $externalPlanText 'Work Items'
            $decompositionMarkers = @([regex]::Matches($externalWorkItemsSection, '(?m)^decomposition:[ \t]*$'))
            $decompositionPattern = '(?m)^decomposition:[ \t]*\n  parent_work_item_id:[ \t]*(?<parent>WORK-[A-Z0-9]+(?:-[A-Z0-9]+)+)[ \t]*\n  child_work_item_ids:[ \t]*\n(?<children>(?:    -[ \t]*WORK-[A-Z0-9]+(?:-[A-Z0-9]+)+[ \t]*\n)+)  decision_reference:[ \t]*(?<decision>DEC-[A-Z0-9]+(?:-[A-Z0-9]+)*)[ \t]*(?:\n|\z)'
            $decompositionMatches = @([regex]::Matches($externalWorkItemsSection, $decompositionPattern))
            $decompositionRecords = [Collections.Generic.List[object]]::new()
            foreach ($decompositionMatch in $decompositionMatches) {
              $decompositionChildren = @(
                [regex]::Matches($decompositionMatch.Groups['children'].Value, '(?m)^    -[ \t]*(?<child>WORK-[A-Z0-9]+(?:-[A-Z0-9]+)+)[ \t]*$') |
                  ForEach-Object { $_.Groups['child'].Value }
              )
              $decompositionRecords.Add([pscustomobject]@{
                Parent = $decompositionMatch.Groups['parent'].Value
                Children = $decompositionChildren
                Decision = $decompositionMatch.Groups['decision'].Value
              })
            }
            if ($decompositionMarkers.Count -ne $decompositionRecords.Count) {
              $externalPlanValid = $false
            }
            foreach ($decompositionRecord in $decompositionRecords) {
              $decompositionParentRows = @($externalWorkItemsTable.Rows | Where-Object {
                $_.'Work Item ID' -ceq $decompositionRecord.Parent
              })
              $uniqueDecompositionChildren = @($decompositionRecord.Children | Sort-Object -Unique)
              if (
                $decompositionParentRows.Count -ne 1 -or
                $decompositionRecord.Children.Count -eq 0 -or
                $uniqueDecompositionChildren.Count -ne $decompositionRecord.Children.Count -or
                $decompositionRecord.Parent -cin $decompositionRecord.Children -or
                $externalRevision -notmatch '^[2-9][0-9]*$'
              ) {
                $externalPlanValid = $false
              }
              foreach ($decompositionChild in $decompositionRecord.Children) {
                if (@($externalWorkItemsTable.Rows | Where-Object { $_.'Work Item ID' -ceq $decompositionChild }).Count -ne 1) {
                  $externalPlanValid = $false
                }
              }
            }
            $relatedDecompositions = @($decompositionRecords | Where-Object {
              $_.Children -ccontains $workItemRow.'Work Item ID'
            })
            if ($workItemRow.'Decomposition Decision Reference' -ceq 'not-applicable') {
              if ($relatedDecompositions.Count -ne 0) {
                $externalPlanValid = $false
              }
            }
            elseif (
              $relatedDecompositions.Count -ne 1 -or
              $relatedDecompositions[0].Decision -cne $workItemRow.'Decomposition Decision Reference' -or
              ($null -ne $approvedPlanRow -and $relatedDecompositions[0].Decision -cne $approvedPlanRow.'Decomposition Decision Reference')
            ) {
              $externalPlanValid = $false
            }
            else {
              if ($externalRevisionMatches.Count -ne 1) {
                $externalPlanValid = $false
              }
              else {
                $affectedWorkItems = @(
                  $externalRevisionMatches[0].'Affected Work Items'.Split([char[]]@(',', ';')) |
                    ForEach-Object { $_.Trim() }
                )
                if (
                  $affectedWorkItems -cnotcontains $workItemRow.'Work Item ID' -or
                  $affectedWorkItems -cnotcontains $relatedDecompositions[0].Parent
                ) {
                  $externalPlanValid = $false
                }
              }
            }
          }
        }
      }
      if (-not $externalPlanValid) {
        $errors.Add('Technical design Work Item Trace must resolve the cited external approved master plan exactly')
      }
    }
    $matrix = & $getTable $designText 'Target Structure Conformance Matrix'
    if ($null -eq $matrix) {
      $errors.Add('Technical design missing Target Structure Conformance Matrix')
    }
    else {
      if (($matrix.Columns -join '|') -cne ($contractMatrixTable.Columns -join '|')) {
        $errors.Add("Technical design Target Structure Conformance Matrix table columns must be exactly: $($contractMatrixTable.Columns -join ' | ')")
      }
      if ($matrix.Rows.Count -ne $canonicalConcerns.Count) {
        $errors.Add("Technical design concern cardinality must equal canonical eight; found $($matrix.Rows.Count)")
      }
      @($matrix.Rows | Where-Object { $_.Concern -cnotin $canonicalConcerns }) | ForEach-Object {
        $errors.Add("Technical design unexpected concern: $($_.Concern)")
      }
      $deviationTable = & $getTable $designText 'Approved Structural Deviations'
      foreach ($concern in $canonicalConcerns) {
        $matchingRows = @($matrix.Rows | Where-Object { $_.Concern -ceq $concern })
        if ($matchingRows.Count -eq 0) {
          $errors.Add("Technical design missing applicable concern: $concern")
          continue
        }
        if ($matchingRows.Count -gt 1) {
          $errors.Add("Technical design concern must appear exactly once: $concern")
          continue
        }
        $row = $matchingRows[0]
        foreach ($requiredColumn in @('Working Exemplar', 'Observed Target Pattern', 'Proposed Path/Symbol')) {
          if (& $isMissingValue $row.$requiredColumn) {
            $errors.Add("Technical design $concern $requiredColumn must not be blank")
          }
        }
        $workingExemplarMatch = [regex]::Match($row.'Working Exemplar', $pathSymbolPattern)
        $patternEvidenceMatch = [regex]::Match(
          $row.'Observed Target Pattern',
          '^path=(?<pathSymbol>[^;]+);\s*symbols=(?<symbols>[^;]+);\s*boundary=(?<boundary>[A-Za-z_][A-Za-z0-9_.]*);\s*mechanism=(?<mechanism>[A-Za-z_][A-Za-z0-9_.]*)(?:;\s*wrapper=(?<wrapper>[A-Za-z_][A-Za-z0-9_.]*))?$'
        )
        $patternPathMatch = if ($patternEvidenceMatch.Success) {
          [regex]::Match($patternEvidenceMatch.Groups['pathSymbol'].Value, $pathSymbolPattern)
        }
        else {
          $null
        }
        $patternSymbolTokens = if ($patternEvidenceMatch.Success) {
          @($patternEvidenceMatch.Groups['symbols'].Value.Split([char[]]@(',', ';')) | ForEach-Object { $_.Trim() })
        }
        else {
          @()
        }
        $invalidPatternSymbols = @($patternSymbolTokens | Where-Object {
          $_ -cnotmatch $explicitSymbolPattern -or
          $_ -match $genericSymbolTokenPattern
        })
        if (
          -not $workingExemplarMatch.Success -or
          $workingExemplarMatch.Groups['path'].Value -match '(?:^|[\\/])\.\.(?:[\\/]|$)' -or
          -not $patternEvidenceMatch.Success -or
          $null -eq $patternPathMatch -or
          -not $patternPathMatch.Success -or
          $patternEvidenceMatch.Groups['pathSymbol'].Value -cne $row.'Working Exemplar' -or
          $patternSymbolTokens.Count -eq 0 -or
          $invalidPatternSymbols.Count -gt 0 -or
          $workingExemplarMatch.Groups['symbol'].Value -cnotin $patternSymbolTokens
        ) {
          $errors.Add("Technical design $concern requires structured concrete pattern evidence")
        }
        if ($row.Conforms -cnotin @('yes', 'no')) {
          $errors.Add("Technical design $concern Conforms must be yes or no")
        }
        elseif ($row.Conforms -ceq 'yes' -and $row.'Deviation Reference' -cne 'not-applicable') {
          $errors.Add("Technical design conforming row must use not-applicable deviation: $concern")
        }
        elseif ($row.Conforms -ceq 'no') {
          $requiredDeviationReference = $row.'Deviation Reference'
          $requiredDeviationConcern = $concern
          if ($null -eq $deviationTable) {
            $deviationRows = @()
          }
          else {
            $deviationRows = @($deviationTable.Rows | Where-Object {
              ($_.'Deviation Reference' -ceq $requiredDeviationReference) -and
              ($_.Concern -ceq $requiredDeviationConcern)
            })
          }
          $resolvedDeviation = if ($deviationRows.Count -eq 1) { $deviationRows[0] } else { $null }
          if (
            (& $isMissingValue $row.'Deviation Reference') -or
            $row.'Deviation Reference' -cnotmatch '^DEV-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -or
            $null -eq $resolvedDeviation -or
            $resolvedDeviation.'Deviation Reference' -cnotmatch '^DEV-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -or
            $resolvedDeviation.'Conflict Reference' -cnotmatch '^CONFLICT-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -or
            $resolvedDeviation.'Resolved Decision' -cnotmatch $decisionPattern -or
            $resolvedDeviation.'Resolved Decision' -match $semanticPlaceholderPattern -or
            $resolvedDeviation.'Tech Lead Approval' -cnotmatch $techLeadApprovalPattern -or
            $resolvedDeviation.'Tech Lead Approval' -match $semanticPlaceholderPattern
          ) {
            $errors.Add("Technical design Conforms = no requires a resolved decision and Tech Lead approval: $concern")
          }
        }

        if ($concern -ceq 'main/child presentation boundaries') {
          $observedWrapper = [regex]::Match($row.'Observed Target Pattern', '(?i)(?:^|[;\s])wrapper=(?<name>[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*)(?:;|$)')
          $proposedWrapper = [regex]::Match($row.'Proposed Path/Symbol', '(?i)(?:^|[;\s])wrapper=(?<name>[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*)(?:;|$)')
          if (-not $observedWrapper.Success) {
            $errors.Add('Technical design observed panel wrapper is required for the presentation row')
          }
          if (-not $proposedWrapper.Success) {
            $errors.Add('Technical design proposed panel wrapper is required for the presentation row')
          }
          if (
            $row.Conforms -ceq 'yes' -and
            $observedWrapper.Success -and
            $proposedWrapper.Success -and
            $observedWrapper.Groups['name'].Value -cne $proposedWrapper.Groups['name'].Value
          ) {
            $errors.Add("Technical design panel wrapper does not conform: observed $($observedWrapper.Groups['name'].Value), proposed $($proposedWrapper.Groups['name'].Value)")
          }
        }
      }
    }

    $plannedTree = & $getTable $designText 'Planned File Tree'
    $plannedTreeColumns = @('Planned Path', 'Planned Symbol', 'Responsibility', 'Exemplar or Deviation Reference')
    if ($null -eq $plannedTree) {
      $errors.Add('Technical design missing Planned File Tree')
    }
    elseif (($plannedTree.Columns -join '|') -cne ($plannedTreeColumns -join '|') -or $plannedTree.Rows.Count -eq 0) {
      $errors.Add("Technical design Planned File Tree table columns must be exactly: $($plannedTreeColumns -join ' | ') and include at least one planned file")
    }
    else {
      foreach ($row in $plannedTree.Rows) {
        foreach ($column in $plannedTreeColumns) {
          if (& $isMissingValue $row.$column) {
            $errors.Add("Technical design Planned File Tree $column must not be blank")
          }
        }
        $plannedPathSymbol = "$($row.'Planned Path')#$($row.'Planned Symbol')"
        $plannedPathMatch = [regex]::Match($plannedPathSymbol, $pathSymbolPattern)
        if (
          -not $plannedPathMatch.Success -or
          $plannedPathMatch.Groups['path'].Value -match '(?:^|[\\/])\.\.(?:[\\/]|$)'
        ) {
          $errors.Add('Technical design Planned File Tree rejects traversal or malformed path/symbol')
        }
      }
      if ($null -ne $matrix) {
        $matrixPaths = [Collections.Generic.List[string]]::new()
        foreach ($matrixRow in $matrix.Rows) {
          $proposedPathSymbol = @($matrixRow.'Proposed Path/Symbol'.Split(';'))[0].Trim()
          $proposedPathMatch = [regex]::Match($proposedPathSymbol, $pathSymbolPattern)
          if (
            -not $proposedPathMatch.Success -or
            $proposedPathMatch.Groups['path'].Value -match '(?:^|[\\/])\.\.(?:[\\/]|$)'
          ) {
            $errors.Add("Technical design matrix rejects traversal or malformed path/symbol: $($matrixRow.Concern)")
          }
          else {
            $matrixPaths.Add((& $normalizePath $proposedPathMatch.Groups['path'].Value))
          }
        }
        $expectedPathSet = @($matrixPaths | Sort-Object -Unique)
        $plannedPathSet = @(
          $plannedTree.Rows |
            ForEach-Object { & $normalizePath $_.'Planned Path' } |
            Sort-Object -Unique
        )
        if (
          ($expectedPathSet -join '|') -cne ($plannedPathSet -join '|') -or
          $plannedTree.Rows.Count -ne $plannedPathSet.Count
        ) {
          $errors.Add('Technical design Planned File Tree path set must exactly match matrix proposed paths')
        }
      }
    }

    $boundaryTable = & $getTable $designText 'Provider/Router/Localization/Subscription Boundaries'
    $boundaryColumns = @('Boundary', 'Owner Path/Symbol', 'Input', 'Output', 'Lifecycle/Failure Policy', 'Evidence')
    if ($null -eq $boundaryTable -or ($boundaryTable.Columns -join '|') -cne ($boundaryColumns -join '|')) {
      $errors.Add("Technical design Provider/Router/Localization/Subscription Boundaries table columns must be exactly: $($boundaryColumns -join ' | ')")
    }
    else {
      foreach ($requiredBoundary in @('provider', 'router', 'localization', 'subscription', 'lifecycle')) {
        $boundaryRows = @($boundaryTable.Rows | Where-Object { $_.Boundary -ceq $requiredBoundary })
        if ($boundaryRows.Count -ne 1) {
          $errors.Add("Technical design missing required boundary: $requiredBoundary")
          continue
        }
        foreach ($column in @('Owner Path/Symbol', 'Input', 'Output', 'Lifecycle/Failure Policy', 'Evidence')) {
          if (& $isMissingValue $boundaryRows[0].$column) {
            $errors.Add("Technical design $requiredBoundary boundary $column must not be blank")
          }
        }
      }
    }

    if ($errors.Count -eq 0) {
      $responsibilityContractPath = Join-Path $PSScriptRoot '../../contracts/file-responsibility-conformance.md'
      if (-not (Test-Path -LiteralPath $responsibilityContractPath -PathType Leaf)) {
        $errors.Add('Missing responsibility conformance contract resource')
      }
      else {
        $responsibilityContractText = Get-Content -Raw -Encoding utf8 -LiteralPath $responsibilityContractPath
        $designDiscoveryText = if (Test-Path -LiteralPath $discoveryPath -PathType Leaf) {
          Get-Content -Raw -Encoding utf8 -LiteralPath $discoveryPath
        }
        else { '' }
        $responsibilityDiagnostics = @(& {
          . (Join-Path $PSScriptRoot 'responsibility-conformance.validation.ps1')
          if ($approvedResponsibilityMode -ne '') {
            Test-ResponsibilityDesign -DiscoveryText $designDiscoveryText -DesignText $designText -Mode $approvedResponsibilityMode -ContractText $responsibilityContractText
          }
        })
        $responsibilityDiagnostics | ForEach-Object {
          $errors.Add($_)
        }
      }
    }
  }
}

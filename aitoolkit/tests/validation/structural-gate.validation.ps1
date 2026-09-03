function Test-StructuralGate([string]$Root, [string]$ContractText) {
  $contractPath = Join-Path $Root 'contracts/target-structure-conformance.md'
  if (-not (Test-Path -LiteralPath $contractPath -PathType Leaf)) {
    $errors.Add('Missing target structure conformance contract resource')
    return
  }
  @(
    '## Structural pre-edit gate',
    'The structural pre-edit gate blocks before target edit and is not waiver-eligible.',
    'architecture conformance and selector/schema states are both `PASS`',
    'runtime_evidence_state: PASS | FAIL | NOT_RUN | WAIVED',
    'architecture_conformance_state: PASS | BLOCKED',
    'selector_schema_state: PASS | BLOCKED'
  ) | ForEach-Object {
    Require-Token $ContractText $_ 'Structural pre-edit gate contract'
  }
  $activationContractPath = Join-Path $Root 'contracts/activation-slice.md'
  if (-not (Test-Path -LiteralPath $activationContractPath -PathType Leaf)) {
    $errors.Add('Missing activation-slice contract resource')
    return
  }
  $activationContractText = ((Get-Content -Raw -Encoding utf8 -LiteralPath $activationContractPath) -replace "`r`n", "`n") -replace "`r", "`n"
  $responsibilityContractPath = Join-Path $Root 'contracts/file-responsibility-conformance.md'
  if (-not (Test-Path -LiteralPath $responsibilityContractPath -PathType Leaf)) {
    $errors.Add('Missing responsibility conformance contract resource')
    return
  }
  $responsibilityContractText = Get-Content -Raw -Encoding utf8 -LiteralPath $responsibilityContractPath
  . (Join-Path $PSScriptRoot 'responsibility-conformance.validation.ps1')

  $fixtureRoot = Join-Path $Root 'structural-gate-fixture'
  if (-not (Test-Path -LiteralPath $fixtureRoot -PathType Container)) { return }
  $reportPath = Join-Path $fixtureRoot '10-implementation-report.md'
  if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) {
    $errors.Add('Structural gate missing implementation report fixture')
    return
  }
  $report = ((Get-Content -Raw -Encoding utf8 -LiteralPath $reportPath) -replace "`r`n", "`n") -replace "`r", "`n"
  $normalizedContractText = ($ContractText -replace "`r`n", "`n") -replace "`r", "`n"

  $getSection = {
    param([string]$Text, [string]$Heading)
    $visibleText = Get-ArcVisibleMarkdownText -Text $Text
    $matches = @([regex]::Matches($visibleText, '(?m)^##\s+' + [regex]::Escape($Heading) + '[ \t]*$'))
    if ($matches.Count -ne 1) {
      $errors.Add("Structural gate section must appear exactly once: $Heading")
      return $null
    }
    $match = $matches[0]
    $start = $match.Index + $match.Length
    $next = [regex]::Match($visibleText.Substring($start), '(?m)^#{1,2}\s+[^\n]+$')
    $length = if ($next.Success) { $next.Index } else { $visibleText.Length - $start }
    return $visibleText.Substring($start, $length)
  }
  $getTable = {
    param([string]$Text, [string]$Heading, [string[]]$Columns)
    $section = & $getSection $Text $Heading
    if ($null -eq $section) { return $null }
    $sectionLines = @($section -split "`n")
    $tableStart = -1
    for ($index = 0; $index -lt $sectionLines.Count; $index++) {
      if ($sectionLines[$index] -match '^\|') { $tableStart = $index; break }
    }
    if ($tableStart -lt 0) { return $null }
    $lines = [Collections.Generic.List[string]]::new()
    for ($index = $tableStart; $index -lt $sectionLines.Count; $index++) {
      if ([string]::IsNullOrWhiteSpace($sectionLines[$index])) { break }
      if ($sectionLines[$index] -notmatch '^\|[^|].*[^|]\|[ \t]*$' -or $sectionLines[$index] -match '^\|\|' -or $sectionLines[$index] -match '\|\|[ \t]*$') {
        $errors.Add("Structural gate malformed Markdown table framing: $Heading")
        return $null
      }
      $lines.Add($sectionLines[$index])
    }
    if ($lines.Count -lt 3 -or @($sectionLines | Select-Object -Skip ($tableStart + $lines.Count) | Where-Object { $_ -match '^\s*\|' }).Count -gt 0) {
      $errors.Add("Structural gate table must be one contiguous exact block: $Heading")
      return $null
    }
    $parse = {
      param([string]$Line)
      $cells = @($Line.Trim().Substring(1, $Line.Trim().Length - 2).Split('|') | ForEach-Object { $_.Trim() })
      if ($cells.Count -eq 0 -or @($cells | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -gt 0) { return $null }
      return $cells
    }
    $header = @(& $parse $lines[0])
    $delimiter = @(& $parse $lines[1])
    if ($header.Count -ne $Columns.Count -or ($header -join '|') -cne ($Columns -join '|') -or $delimiter.Count -ne $Columns.Count -or @($delimiter | Where-Object { $_ -cnotmatch '^:?-{3,}:?$' }).Count -gt 0) { return $null }
    $rows = [Collections.Generic.List[object]]::new()
    foreach ($line in @($lines | Select-Object -Skip 2)) {
      $cells = @(& $parse $line)
      if ($cells.Count -ne $Columns.Count) { return $null }
      $row = [ordered]@{}
      for ($index = 0; $index -lt $Columns.Count; $index++) { $row[$Columns[$index]] = $cells[$index] }
      $rows.Add([pscustomobject]$row)
    }
    return [pscustomobject]@{ Rows = @($rows) }
  }
  $missing = {
    param([string]$Value)
    return [string]::IsNullOrWhiteSpace($Value) -or $Value -match '^\s*<[^>]+>\s*$' -or $Value -match '^(?i:pending|unknown|none|tbd)$'
  }
  $pathSymbolPattern = '^(?<path>(?:[A-Za-z]:)?[\\/]?(?:[A-Za-z0-9_.-]+[\\/])*[A-Za-z0-9_.-]+)#(?<symbol>[A-Za-z_][A-Za-z0-9_.]*)$'
  $getDigest = {
    param([string]$Text)
    $normalized = (($Text -replace "`r`n", "`n") -replace "`r", "`n")
    $hash = [Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($normalized))
    return 'sha256:' + (($hash | ForEach-Object { $_.ToString('x2') }) -join '')
  }
  $parseFrontMatter = {
    param([string]$Text)
    $normalized = (($Text -replace "`r`n", "`n") -replace "`r", "`n")
    $match = [regex]::Match($normalized, '\A---\n(?<body>.*?)\n---(?:\n|\z)', [Text.RegularExpressions.RegexOptions]::Singleline)
    if (-not $match.Success) { return $null }
    $values = [ordered]@{}
    $frontMatterLines = @($match.Groups['body'].Value -split "`n")
    for ($lineIndex = 0; $lineIndex -lt $frontMatterLines.Count; $lineIndex++) {
      $line = $frontMatterLines[$lineIndex]
      if ($line -ceq 'responsibility_contract:') {
        if ($values.Contains('responsibility_contract') -or ($lineIndex + 2) -ge $frontMatterLines.Count -or $frontMatterLines[$lineIndex + 1] -cne '  version: 1' -or $frontMatterLines[$lineIndex + 2] -cne '  applicability: required') { return $null }
        $values['responsibility_contract'] = 'version=1;applicability=required'
        $lineIndex += 2
        continue
      }
      $field = [regex]::Match($line, '^(?<key>[a-z_][a-z0-9_]*):[ \t]*(?<value>[^\n]+?)[ \t]*$')
      if (-not $field.Success -or $values.Contains($field.Groups['key'].Value)) { return $null }
      $values[$field.Groups['key'].Value] = $field.Groups['value'].Value.Trim()
    }
    $remainder = $normalized.Substring($match.Index + $match.Length)
    if ($remainder -match '(?m)^---[ \t]*$' -or $remainder -match '(?m)^[a-z_][a-z0-9_]*:[ \t]*[^\n]+[ \t]*$') { return $null }
    return [pscustomobject]@{ Values = $values; Keys = @($values.Keys) }
  }
  $getFrontMatter = {
    param([object]$FrontMatter, [string]$Field)
    if ($null -eq $FrontMatter -or -not $FrontMatter.Values.Contains($Field)) { return '' }
    return $FrontMatter.Values[$Field]
  }
  $reportFrontMatter = & $parseFrontMatter $report
  if ($null -eq $reportFrontMatter) {
    $errors.Add('Structural gate implementation report frontmatter is invalid or spoofed')
    return
  }
  $reportStatus = & $getFrontMatter $reportFrontMatter 'status'
  $reportResult = & $getFrontMatter $reportFrontMatter 'result'
  if ($reportStatus -ceq 'draft' -and $reportResult -ceq 'blocked') {
    $errors.Add('Structural gate draft/blocked state stops before edit')
    return
  }
  $reportApprovalSource = & $getFrontMatter $reportFrontMatter 'approval_source'
  $reportLifecycleValid = (
    ($reportStatus -ceq 'draft' -and $reportResult -ceq 'complete' -and $reportApprovalSource -ceq '') -or
    ($reportStatus -ceq 'approved' -and $reportResult -ceq 'complete' -and $reportApprovalSource -cin @('human', 'auto'))
  )
  if (-not $reportLifecycleValid) {
    $errors.Add('Structural gate implementation report lifecycle must be canonical draft/complete or approved/complete')
    return
  }
  $readAuthority = {
    param([string]$Reference, [string]$Label)
    if ([string]::IsNullOrWhiteSpace($Reference) -or [IO.Path]::IsPathRooted($Reference) -or $Reference -match '(^|[\\/])\.\.([\\/]|$)') {
      $errors.Add("Structural gate $Label reference must be an explicit safe relative path")
      return $null
    }
    $path = [IO.Path]::GetFullPath((Join-Path $fixtureRoot $Reference))
    $fixturePrefix = [IO.Path]::GetFullPath($fixtureRoot).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $path.StartsWith($fixturePrefix, [StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $path -PathType Leaf)) {
      $errors.Add("Structural gate $Label authority is unreadable: $Reference")
      return $null
    }
    return (((Get-Content -Raw -Encoding utf8 -LiteralPath $path) -replace "`r`n", "`n") -replace "`r", "`n")
  }
  $templatePath = Join-Path $Root 'templates/migration/implementation-report.md'
  if (Test-Path -LiteralPath $templatePath -PathType Leaf) {
    $templateText = ((Get-Content -Raw -Encoding utf8 -LiteralPath $templatePath) -replace "`r`n", "`n") -replace "`r", "`n"
    $templateFrontMatter = Get-ArcBoundedFrontMatter -Text $templateText
    $changedFileColumns = @('Work Item ID', 'Activation Slice ID', 'Seam', 'File', 'Change', 'Trace IDs')
    $testEvidenceColumns = @('Work Item ID', 'Activation Slice ID', 'Seam', 'Test', 'Command', 'Result', 'Trace IDs')
    $actualResponsibilityColumns = @('Responsibility ID', 'Owner Path', 'Owner Symbol', 'Boundary Kind', 'Primary Responsibility', 'Owned Capability IDs', 'Trace IDs', 'Atomic Boundary ID', 'Public Symbols', 'External Effects', 'Target Exemplar', 'Exemplar Classification', 'Classification Authority', 'Classification Evidence', 'Architecture Authority', 'Co-location Policy', 'Co-location Evidence', 'Verification Owner References', 'Conformance', 'Deviation Reference', 'Actual Evidence')
    $actualVerificationColumns = @('Verification Owner ID', 'Production Responsibility ID', 'Capability ID', 'Evidence Path', 'Evidence Symbol or Scenario', 'Evidence Kind', 'Verification Disposition', 'Production Binding Evidence', 'Decision Reference', 'Verdict', 'Deviation Reference', 'Actual Evidence')
    $responsibilityPlanColumns = @('Work Item ID', 'Plan Reference', 'Plan Revision', 'Design Revision')
    $ownerReferenceColumns = @('Work Item ID', 'Design Revision', 'Responsibility IDs', 'Shared Foundation IDs', 'Integration Responsibility IDs', 'Independent Boundary Evidence')
    $responsibilityVerdictColumns = @('Responsibility Contract Version', 'Tree Conformance', 'Responsibility Conformance', 'Verification Ownership', 'Architecture Conformance State', 'Evidence References')
    if (@([regex]::Matches($templateFrontMatter, '(?m)^responsibility_contract:\s*$')).Count -ne 1 -or @([regex]::Matches($templateFrontMatter, '(?m)^  version:\s*1\s*$')).Count -ne 1 -or @([regex]::Matches($templateFrontMatter, '(?m)^  applicability:\s*required\s*$')).Count -ne 1) {
      $errors.Add('Structural gate implementation report template requires responsibility contract v1')
    }
    if ($null -eq (& $getTable $templateText 'Work Item Changed Files' $changedFileColumns)) {
      $errors.Add('Structural gate implementation report changed-file evidence must be keyed by Work Item ID')
    }
    if ($null -eq (& $getTable $templateText 'Work Item Test Evidence' $testEvidenceColumns)) {
      $errors.Add('Structural gate implementation report test evidence must be keyed by Work Item ID')
    }
    if ($null -eq (& $getTable $templateText 'Responsibility Plan Reference' $responsibilityPlanColumns) -or $null -eq (& $getTable $templateText 'Responsibility Owner References' $ownerReferenceColumns) -or $null -eq (& $getTable $templateText 'Actual File Responsibility Matrix' $actualResponsibilityColumns) -or $null -eq (& $getTable $templateText 'Actual Verification Ownership Matrix' $actualVerificationColumns) -or $null -eq (& $getTable $templateText 'Architecture Responsibility Verdicts' $responsibilityVerdictColumns)) {
      $errors.Add('Structural gate implementation report template requires exact responsibility evidence tables')
    }
    $conditionalUnitToken = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('Q2jhu4kgZ2nhu68gc2VjdGlvbiBuw6B5IGtoaSBgQWRhcHRlciBLaW5kID0gbWlncmF0aW9uLXVuaXRg'))
    $noInventedUnitToken = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('a2jDtG5nIHBow6F0IG1pbmggYG1pZ3JhdGlvbl91bml0X2lkYA=='))
    Require-Token $templateText $conditionalUnitToken 'Structural gate implementation report generic adapter contract'
    Require-Token $templateText $noInventedUnitToken 'Structural gate implementation report generic adapter contract'
  }

  $masterColumns = @('Master Spec Reference', 'Master Spec ID', 'Master Spec Revision', 'Master Plan Reference', 'Master Plan ID', 'Master Plan Revision', 'Work Item ID', 'Work Item Approval Reference')
  $master = & $getTable $report 'Master Scope Context' $masterColumns
  if ($null -eq $master) { $errors.Add('Structural gate missing Master Scope Context'); return }
  if ($master.Rows.Count -ne 1) { $errors.Add('Structural gate Master Scope Context must contain exactly one work item'); return }
  $masterRow = $master.Rows[0]
  if ($masterRow.'Master Spec ID' -cnotmatch '^SPEC-[A-Z0-9]+(?:-[A-Z0-9]+)+$' -or $masterRow.'Master Spec Revision' -cnotmatch '^[1-9][0-9]*$' -or $masterRow.'Master Plan ID' -cnotmatch '^PLAN-[A-Z0-9]+(?:-[A-Z0-9]+)+$' -or $masterRow.'Master Plan Revision' -cnotmatch '^[1-9][0-9]*$' -or $masterRow.'Work Item ID' -cnotmatch '^WORK-[A-Z0-9]+(?:-[A-Z0-9]+)+$' -or $masterRow.'Work Item Approval Reference' -cnotmatch '^approval:TECH-LEAD-[A-Z0-9]+(?:-[A-Z0-9]+)*$') {
    $errors.Add('Structural gate Master Scope Context requires exact approved IDs and revisions'); return
  }
  $specScope = [regex]::Match($masterRow.'Master Spec ID', '^SPEC-(?<scope>[A-Z0-9]+)-').Groups['scope'].Value
  $planScope = [regex]::Match($masterRow.'Master Plan ID', '^PLAN-(?<scope>[A-Z0-9]+)-').Groups['scope'].Value
  $workItemScope = [regex]::Match($masterRow.'Work Item ID', '^WORK-(?<scope>[A-Z0-9]+)-').Groups['scope'].Value
  if ($specScope -cne $planScope -or $specScope -cne $workItemScope) {
    $errors.Add('Structural gate Master Scope Context IDs must share the same scope'); return
  }
  $masterSpecText = & $readAuthority $masterRow.'Master Spec Reference' 'master spec'
  $masterPlanText = & $readAuthority $masterRow.'Master Plan Reference' 'master plan'
  if ($null -eq $masterSpecText -or $null -eq $masterPlanText) { return }
  $masterSpecFrontMatter = & $parseFrontMatter $masterSpecText
  if ($null -eq $masterSpecFrontMatter) { $errors.Add('Structural gate master spec frontmatter is invalid or spoofed'); return }
  $masterPlanFrontMatter = & $parseFrontMatter $masterPlanText
  if ($null -eq $masterPlanFrontMatter) { $errors.Add('Structural gate master plan frontmatter is invalid or spoofed'); return }
  if (
    (& $getFrontMatter $masterSpecFrontMatter 'master_spec_id') -cne $masterRow.'Master Spec ID' -or
    (& $getFrontMatter $masterSpecFrontMatter 'revision') -cne $masterRow.'Master Spec Revision' -or
    (& $getFrontMatter $masterSpecFrontMatter 'status') -cne 'approved' -or
    (& $getFrontMatter $masterSpecFrontMatter 'result') -cne 'complete'
  ) { $errors.Add('Structural gate report must match the external approved master spec exactly'); return }
  if (
    (& $getFrontMatter $masterPlanFrontMatter 'master_plan_id') -cne $masterRow.'Master Plan ID' -or
    (& $getFrontMatter $masterPlanFrontMatter 'master_spec_id') -cne $masterRow.'Master Spec ID' -or
    (& $getFrontMatter $masterPlanFrontMatter 'master_spec_revision') -cne $masterRow.'Master Spec Revision' -or
    (& $getFrontMatter $masterPlanFrontMatter 'revision') -cne $masterRow.'Master Plan Revision' -or
    (& $getFrontMatter $masterPlanFrontMatter 'status') -cne 'approved'
  ) { $errors.Add('Structural gate report must match the external approved master plan revision exactly'); return }
  $workItemColumns = @('Work Item ID', 'Title', 'Required', 'Dependencies', 'Plan Order', 'Acceptance', 'Trace IDs', 'Delivery Adapter', 'Status', 'Latest Attempt', 'Terminal Evidence', 'Approval Reference')
  $externalWorkItems = & $getTable $masterPlanText 'Work Items' $workItemColumns
  if ($null -eq $externalWorkItems) { $errors.Add('Structural gate external master plan Work Items table is malformed'); return }
  $externalWorkItemMatches = @($externalWorkItems.Rows | Where-Object { $_.'Work Item ID' -ceq $masterRow.'Work Item ID' })
  if ($externalWorkItemMatches.Count -ne 1 -or $externalWorkItemMatches[0].'Approval Reference' -cne $masterRow.'Work Item Approval Reference' -or $externalWorkItemMatches[0].Status -cnotin @('pending', 'ready', 'in-progress')) {
    $errors.Add('Structural gate work item must be an exact approved member of the external current master plan'); return
  }

  $selectorEvidenceColumns = @('Work Item ID', 'Adapter Kind', 'External ID', 'Authority', 'Authority Revision', 'Approval Reference', 'Parent Selector', 'Acceptance', 'Trace IDs', 'Mode Constraint', 'Design Revision', 'Parent Work Item ID', 'Decomposition Decision Reference')
  $selectorColumns = @($selectorEvidenceColumns) + 'Canonical Match'
  $selector = & $getTable $report 'Canonical Adapter Evidence' $selectorColumns
  if ($null -eq $selector -or $selector.Rows.Count -ne 1) { $errors.Add('Structural gate missing exactly one Canonical Adapter Evidence row'); return }
  $selectorRow = $selector.Rows[0]
  $selectorShapeValid = $selectorRow.'Work Item ID' -ceq $masterRow.'Work Item ID' -and $selectorRow.'Adapter Kind' -cin @('migration-unit', 'task', 'story', 'package', 'phase', 'milestone', 'none')
  if ($selectorRow.'Adapter Kind' -ceq 'none') {
    $selectorShapeValid = $selectorShapeValid -and $selectorRow.'External ID' -ceq 'not-applicable' -and $selectorRow.Authority -ceq 'not-applicable' -and $selectorRow.'Authority Revision' -ceq 'not-applicable' -and $selectorRow.'Approval Reference' -ceq 'not-applicable' -and $selectorRow.'Parent Selector' -ceq 'not-applicable'
  }
  elseif ($selectorRow.'Adapter Kind' -ceq 'migration-unit') {
    $selectorShapeValid = $selectorShapeValid -and $selectorRow.'External ID' -cmatch '^UNIT-[A-Z0-9]+(?:-[A-Z0-9]+)+$' -and -not (& $missing $selectorRow.Authority) -and $selectorRow.Authority -cnotmatch '@' -and $selectorRow.'Authority Revision' -cmatch '^[1-9][0-9]*$' -and -not (& $missing $selectorRow.'Approval Reference')
  }
  else {
    $selectorShapeValid = $selectorShapeValid -and -not (& $missing $selectorRow.'External ID') -and -not (& $missing $selectorRow.Authority) -and $selectorRow.'Authority Revision' -cmatch '^[1-9][0-9]*$' -and -not (& $missing $selectorRow.'Approval Reference')
  }
  if (-not $selectorShapeValid -or $selectorRow.'Canonical Match' -cne 'PASS') { $errors.Add('Structural gate canonical adapter must resolve with PASS'); return }
  $externalSelectors = & $getTable $masterPlanText 'Delivery Adapter Selection' $selectorEvidenceColumns
  if ($null -eq $externalSelectors) { $errors.Add('Structural gate external master plan selector table is malformed'); return }
  $externalSelectorMatches = @($externalSelectors.Rows | Where-Object { $_.'Work Item ID' -ceq $masterRow.'Work Item ID' })
  if ($externalSelectorMatches.Count -ne 1) {
    $errors.Add('Structural gate adapter must resolve exactly one external canonical selector'); return
  }
  $externalSelector = $externalSelectorMatches[0]
  foreach ($selectorField in $selectorEvidenceColumns) {
    if ($selectorRow.$selectorField -cne $externalSelector.$selectorField) {
      $errors.Add("Structural gate report selector does not match external canonical selector: $selectorField"); return
    }
  }
  $workItemAdapterMatchesSelector = if ($selectorRow.'Adapter Kind' -ceq 'none') {
    $externalWorkItemMatches[0].'Delivery Adapter' -ceq 'none' -or $externalWorkItemMatches[0].'Delivery Adapter' -cmatch '^generic:[A-Za-z0-9][A-Za-z0-9._-]*$'
  }
  else {
    $externalWorkItemMatches[0].'Delivery Adapter' -ceq "$($selectorRow.'Adapter Kind'):$($selectorRow.'External ID')"
  }
  if (-not $workItemAdapterMatchesSelector -or $externalSelector.Acceptance -cne $externalWorkItemMatches[0].Acceptance -or $externalSelector.'Trace IDs' -cne $externalWorkItemMatches[0].'Trace IDs') {
    $errors.Add('Structural gate external Work Item and all canonical selector fields must agree exactly'); return
  }
  $visibleReport = Get-ArcVisibleMarkdownText -Text $report
  $selectedUnitHeadingCount = @(Get-ArcMarkdownH2HeadingMatches -Text $report -Heading 'Selected Migration Unit').Count
  $canonicalPlanText = $null
  if ($selectorRow.'Adapter Kind' -ceq 'migration-unit') {
    $canonicalPlanText = & $readAuthority $selectorRow.Authority 'canonical migration plan'
    if ($null -eq $canonicalPlanText) { return }
    $canonicalPlanFrontMatter = & $parseFrontMatter $canonicalPlanText
    if ($null -eq $canonicalPlanFrontMatter) { $errors.Add('Structural gate canonical migration plan frontmatter is invalid or spoofed'); return }
    if ((& $getFrontMatter $canonicalPlanFrontMatter 'status') -cne 'approved' -or (& $getFrontMatter $canonicalPlanFrontMatter 'result') -cne 'complete' -or (& $getFrontMatter $canonicalPlanFrontMatter 'revision') -cne $selectorRow.'Authority Revision') {
      $errors.Add('Structural gate migration-unit authority must be the exact external approved canonical plan revision'); return
    }
    $orderedUnitsHeading = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('Q8OhYyDEkcahbiB24buLIG1pZ3JhdGlvbiB0aGVvIHRo4bupIHThu7E='))
    $unitColumns = @('Order', 'Migration Unit ID', 'Bootstrap Scope', 'Foundation Baseline ID', 'Foundation Approval Reference', 'Dependencies', 'Acceptance', 'Mode Constraint', 'Trace IDs', 'Delivery Change Boundary', 'Approval Reference', 'Approval Status')
    $traceColumns = @('Migration Unit ID', 'Work Item ID', 'Parent Work Item ID', 'Master Plan Reference', 'Master Plan Revision', 'Decomposition Decision Reference', 'Design Revision')
    $units = & $getTable $canonicalPlanText $orderedUnitsHeading $unitColumns
    $unitTraces = & $getTable $canonicalPlanText 'Work Item Adapter Trace' $traceColumns
    if ($null -eq $units -or $null -eq $unitTraces) { $errors.Add('Structural gate external canonical migration plan tables are malformed'); return }
    $unitMatches = @($units.Rows | Where-Object { $_.'Migration Unit ID' -ceq $selectorRow.'External ID' })
    $unitTraceMatches = @($unitTraces.Rows | Where-Object { $_.'Migration Unit ID' -ceq $selectorRow.'External ID' -and $_.'Work Item ID' -ceq $masterRow.'Work Item ID' })
    if ($unitMatches.Count -ne 1 -or $unitTraceMatches.Count -ne 1 -or $unitMatches[0].'Approval Reference' -cne $selectorRow.'Approval Reference' -or $unitMatches[0].'Approval Status' -cne 'approved' -or $unitMatches[0].Acceptance -cne $externalSelector.Acceptance -or $unitMatches[0].'Trace IDs' -cne $externalSelector.'Trace IDs' -or $unitMatches[0].'Mode Constraint' -cne $externalSelector.'Mode Constraint' -or $unitTraceMatches[0].'Master Plan Reference' -cne $masterRow.'Master Plan Reference' -or $unitTraceMatches[0].'Master Plan Revision' -cne $masterRow.'Master Plan Revision' -or $unitTraceMatches[0].'Design Revision' -cne $externalSelector.'Design Revision') {
      $errors.Add('Structural gate migration-unit selector must match the external canonical unit and work-item trace exactly'); return
    }
    $selectedUnitColumns = @('Migration Unit ID', 'Plan Reference', 'Approval Reference', 'Mode Constraint', 'Bootstrap Scope', 'Foundation Baseline ID', 'Foundation Baseline Reference', 'Foundation Baseline Approval Reference', 'Baseline Reference', 'Trace IDs')
    $selectedUnit = & $getTable $report 'Selected Migration Unit' $selectedUnitColumns
    $selectedUnitRow = if ($null -ne $selectedUnit -and $selectedUnit.Rows.Count -eq 1) { $selectedUnit.Rows[0] } else { $null }
    $canonicalPlanReference = "$($selectorRow.Authority)@$($selectorRow.'Authority Revision')"
    if ($selectedUnitHeadingCount -ne 1 -or $null -eq $selectedUnitRow -or $selectedUnitRow.'Migration Unit ID' -cne $selectorRow.'External ID' -or $selectedUnitRow.'Plan Reference' -cne $canonicalPlanReference -or $selectedUnitRow.'Approval Reference' -cne $selectorRow.'Approval Reference' -or $selectedUnitRow.'Mode Constraint' -cne $externalSelector.'Mode Constraint' -or $selectedUnitRow.'Bootstrap Scope' -cne $unitMatches[0].'Bootstrap Scope' -or $selectedUnitRow.'Foundation Baseline ID' -cne $unitMatches[0].'Foundation Baseline ID' -or $selectedUnitRow.'Foundation Baseline Approval Reference' -cne $unitMatches[0].'Foundation Approval Reference' -or $selectedUnitRow.'Trace IDs' -cne $externalSelector.'Trace IDs' -or (& $missing $selectedUnitRow.'Baseline Reference')) {
      $errors.Add('Structural gate migration-unit adapter requires exact Selected Migration Unit evidence'); return
    }
    if ($externalSelector.'Mode Constraint' -ceq 'incremental/preserve-existing' -and $selectedUnitRow.'Foundation Baseline Reference' -cne 'not-applicable') {
      $errors.Add('Structural gate incremental Selected Migration Unit requires not-applicable foundation baseline reference'); return
    }
  }
  elseif ($selectedUnitHeadingCount -ne 0 -or $visibleReport -match '(?m)^\|[^\n]*\bUNIT-[A-Z0-9-]+\b[^\n]*\|[ \t]*\r?$') {
    $errors.Add('Structural gate generic adapter must omit Selected Migration Unit and all unit-specific IDs'); return
  }

  $matrixColumns = @('Work Item ID', 'Discovery Reference', 'Design Reference', 'Design Revision', 'Design Approval Evidence Reference', 'Matrix Approval Reference', 'Matrix Status')
  $matrix = & $getTable $report 'Conformance Matrix Reference' $matrixColumns
  if ($null -eq $matrix -or $matrix.Rows.Count -ne 1) { $errors.Add('Structural gate missing Conformance Matrix Reference'); return }
  $matrixRow = $matrix.Rows[0]
  if ($matrixRow.'Work Item ID' -cne $masterRow.'Work Item ID' -or (& $missing $matrixRow.'Design Reference') -or (& $missing $matrixRow.'Design Approval Evidence Reference') -or $matrixRow.'Design Revision' -cnotmatch '^[1-9][0-9]*$' -or $matrixRow.'Matrix Approval Reference' -cnotmatch '^approval:TECH-LEAD-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -or $matrixRow.'Matrix Status' -cne 'approved') {
    $errors.Add('Structural gate conformance matrix must be approved for the selected work item'); return
  }
  $discoveryText = & $readAuthority $matrixRow.'Discovery Reference' 'discovery'
  $designText = & $readAuthority $matrixRow.'Design Reference' 'technical design'
  $designApprovalText = & $readAuthority $matrixRow.'Design Approval Evidence Reference' 'technical design approval'
  if ($null -eq $discoveryText -or $null -eq $designText -or $null -eq $designApprovalText) { return }
  $designFrontMatter = & $parseFrontMatter $designText
  $designFrontMatterKeys = if ($null -ne $designFrontMatter) { @($designFrontMatter.Keys) } else { @() }
  $canonicalDesignFrontMatterKeys = @('step_id', 'status', 'result', 'produced_at', 'revision', 'responsibility_contract')
  if (
    $null -eq $designFrontMatter -or
    $designFrontMatterKeys.Count -ne $canonicalDesignFrontMatterKeys.Count -or
    @($designFrontMatterKeys | Sort-Object -Unique).Count -ne $designFrontMatterKeys.Count -or
    ($designFrontMatterKeys -join '|') -cne ($canonicalDesignFrontMatterKeys -join '|')
  ) {
    $errors.Add('Structural gate technical design frontmatter must contain only the canonical Task 6 fields'); return
  }
  $designStatus = & $getFrontMatter $designFrontMatter 'status'
  if ((& $getFrontMatter $designFrontMatter 'step_id') -cne '07-technical-design' -or $designStatus -cne 'draft' -or (& $getFrontMatter $designFrontMatter 'result') -cne 'complete' -or (& $getFrontMatter $designFrontMatter 'revision') -cne $externalSelector.'Design Revision' -or (& $getFrontMatter $designFrontMatter 'responsibility_contract') -cne 'version=1;applicability=required') {
    $errors.Add('Structural gate external technical design must remain canonical Task 6 draft/complete'); return
  }
  $selectorDesignRevision = [regex]::Match($externalSelector.'Design Revision', '^(?<identity>DESIGN-[A-Z0-9]+(?:-[A-Z0-9]+)*)@(?<revision>[1-9][0-9]*)$')
  $designApprovalFrontMatter = & $parseFrontMatter $designApprovalText
  $canonicalApprovalKeys = @('step_id', 'status', 'result', 'approval_source', 'produced_at')
  $designApprovalColumns = @('Design ID', 'Design Revision', 'Design Digest', 'Approval Reference', 'Tech Lead Decision', 'Approval Status')
  $designApproval = & $getTable $designApprovalText 'Technical Design Approval' $designApprovalColumns
  if ($null -eq $designApprovalFrontMatter -or ($designApprovalFrontMatter.Keys -join '|') -cne ($canonicalApprovalKeys -join '|') -or (& $getFrontMatter $designApprovalFrontMatter 'step_id') -cne 'technical-design-approval' -or (& $getFrontMatter $designApprovalFrontMatter 'status') -cne 'approved' -or (& $getFrontMatter $designApprovalFrontMatter 'result') -cne 'complete' -or (& $getFrontMatter $designApprovalFrontMatter 'approval_source') -cne 'human') {
    $errors.Add('Structural gate external technical-design approval lifecycle must be approved/complete/human'); return
  }
  if ($null -eq $designApproval -or $designApproval.Rows.Count -ne 1) {
    $errors.Add('Structural gate requires one canonical external technical-design approval artifact'); return
  }
  $designApprovalRow = $designApproval.Rows[0]
  if (-not $selectorDesignRevision.Success -or $designApprovalRow.'Design ID' -cne $selectorDesignRevision.Groups['identity'].Value -or $designApprovalRow.'Design Revision' -cne $matrixRow.'Design Revision' -or $designApprovalRow.'Design Revision' -cne $selectorDesignRevision.Groups['revision'].Value -or $designApprovalRow.'Approval Reference' -cne $matrixRow.'Matrix Approval Reference' -or $designApprovalRow.'Approval Reference' -ceq $masterRow.'Work Item Approval Reference' -or $designApprovalRow.'Approval Reference' -cnotmatch '^approval:TECH-LEAD-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -or (& $missing $designApprovalRow.'Tech Lead Decision') -or $designApprovalRow.'Approval Status' -cne 'approved' -or $designApprovalRow.'Design Digest' -cnotmatch '^sha256:[0-9a-f]{64}$') {
    $errors.Add('Structural gate matrix approval must bind one external approved exact design revision'); return
  }
  $approvedPlanColumns = @('Master Plan Reference', 'Master Plan ID', 'Revision', 'Status', 'Work Item ID', 'Acceptance', 'Trace IDs', 'Delivery Adapter', 'Decomposition Decision Reference', 'Approval Reference', 'Evidence Reference')
  $workTraceColumns = @('Work Item ID', 'Master Plan Reference', 'Master Plan Revision', 'Acceptance Traces', 'Decomposition Decision Reference')
  $approvedPlanEvidence = & $getTable $designText 'Approved Master Plan Evidence' $approvedPlanColumns
  $designWorkTrace = & $getTable $designText 'Work Item Trace' $workTraceColumns
  if ($null -eq $approvedPlanEvidence -or $approvedPlanEvidence.Rows.Count -ne 1 -or $null -eq $designWorkTrace -or $designWorkTrace.Rows.Count -ne 1) {
    $errors.Add('Structural gate technical design requires exact Approved Master Plan Evidence and Work Item Trace'); return
  }
  $approvedPlanRow = $approvedPlanEvidence.Rows[0]
  $designTraceRow = $designWorkTrace.Rows[0]
  $masterReferenceWithId = "$($masterRow.'Master Plan Reference')#$($masterRow.'Master Plan ID')"
  $expectedPlanEvidenceReference = "$masterReferenceWithId@revision=$($masterRow.'Master Plan Revision'):$($masterRow.'Work Item ID')"
  $expectedAcceptanceTraces = @([regex]::Matches($approvedPlanRow.Acceptance, '(?:^|;\s*)(?<id>[A-Z][A-Z0-9]*(?:-[A-Z0-9]+)+)(?=\s*(?::|;|$))') | ForEach-Object { $_.Groups['id'].Value }) -join ', '
  if (
    -not $selectorDesignRevision.Success -or $selectorDesignRevision.Groups['revision'].Value -cne $matrixRow.'Design Revision' -or
    $approvedPlanRow.'Master Plan Reference' -cne $masterReferenceWithId -or $approvedPlanRow.'Master Plan ID' -cne $masterRow.'Master Plan ID' -or
    $approvedPlanRow.Revision -cne $masterRow.'Master Plan Revision' -or $approvedPlanRow.Status -cne 'approved' -or
    $approvedPlanRow.'Work Item ID' -cne $masterRow.'Work Item ID' -or $approvedPlanRow.Acceptance -cne $externalWorkItemMatches[0].Acceptance -or
    $approvedPlanRow.'Trace IDs' -cne $externalWorkItemMatches[0].'Trace IDs' -or $approvedPlanRow.'Delivery Adapter' -cne $externalWorkItemMatches[0].'Delivery Adapter' -or
    $approvedPlanRow.'Decomposition Decision Reference' -cne $externalSelector.'Decomposition Decision Reference' -or
    $approvedPlanRow.'Approval Reference' -cne $externalWorkItemMatches[0].'Approval Reference' -or $approvedPlanRow.'Evidence Reference' -cne $expectedPlanEvidenceReference -or
    $designTraceRow.'Work Item ID' -cne $masterRow.'Work Item ID' -or $designTraceRow.'Master Plan Reference' -cne $masterReferenceWithId -or
    $designTraceRow.'Master Plan Revision' -cne $masterRow.'Master Plan Revision' -or $designTraceRow.'Acceptance Traces' -cne $expectedAcceptanceTraces -or
    $designTraceRow.'Decomposition Decision Reference' -cne $approvedPlanRow.'Decomposition Decision Reference'
  ) { $errors.Add('Structural gate report must bind through exact Task 6 approved-plan and work-item trace tables'); return }

  $responsibilityPlanReferenceColumns = @('Work Item ID', 'Plan Reference', 'Plan Revision', 'Design Revision')
  $responsibilityPlanReference = & $getTable $report 'Responsibility Plan Reference' $responsibilityPlanReferenceColumns
  if ($null -eq $responsibilityPlanReference -or $responsibilityPlanReference.Rows.Count -ne 1 -or $responsibilityPlanReference.Rows[0].'Work Item ID' -cne $masterRow.'Work Item ID' -or $responsibilityPlanReference.Rows[0].'Design Revision' -cne $externalSelector.'Design Revision') {
    $errors.Add('responsibility-owner-missing')
    return
  }
  $responsibilityPlanText = & $readAuthority $responsibilityPlanReference.Rows[0].'Plan Reference' 'responsibility plan'
  if ($null -eq $responsibilityPlanText) { return }
  $responsibilityPlanFrontMatter = & $parseFrontMatter $responsibilityPlanText
  $responsibilityPlanRunId = if ($null -ne $responsibilityPlanFrontMatter) { & $getFrontMatter $responsibilityPlanFrontMatter 'run_id' } else { '' }
  if ($null -eq $responsibilityPlanFrontMatter -or (& $getFrontMatter $responsibilityPlanFrontMatter 'step_id') -cne '08-plan-waves' -or (& $getFrontMatter $responsibilityPlanFrontMatter 'status') -cne 'approved' -or (& $getFrontMatter $responsibilityPlanFrontMatter 'result') -cne 'complete' -or (& $getFrontMatter $responsibilityPlanFrontMatter 'approval_source') -cne 'human' -or $responsibilityPlanRunId -cnotmatch '^RUN-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -or (& $getFrontMatter $responsibilityPlanFrontMatter 'responsibility_contract') -cne 'version=1;applicability=required') {
    $errors.Add('responsibility-owner-missing')
    return
  }
  if ((& $getFrontMatter $responsibilityPlanFrontMatter 'revision') -cne $responsibilityPlanReference.Rows[0].'Plan Revision' -or $responsibilityPlanReference.Rows[0].'Plan Revision' -cnotmatch '^[1-9][0-9]*$') {
    $errors.Add('responsibility-owner-extra')
    return
  }
  if ($selectorRow.'Adapter Kind' -ceq 'migration-unit' -and $responsibilityPlanReference.Rows[0].'Plan Reference' -cne $selectorRow.Authority) {
    $errors.Add('responsibility-owner-extra')
    return
  }
  $ownerReferenceColumns = @('Work Item ID', 'Design Revision', 'Responsibility IDs', 'Shared Foundation IDs', 'Integration Responsibility IDs', 'Independent Boundary Evidence')
  $responsibilityAdapterColumns = @('Migration Unit ID', 'Work Item ID', 'Parent Work Item ID', 'Master Plan Reference', 'Master Plan Revision', 'Decomposition Decision Reference', 'Design Revision')
  $reportOwnerReferences = & $getTable $report 'Responsibility Owner References' $ownerReferenceColumns
  $planOwnerReferences = & $getTable $responsibilityPlanText 'Responsibility Owner References' $ownerReferenceColumns
  $responsibilityAdapters = & $getTable $responsibilityPlanText 'Work Item Adapter Trace' $responsibilityAdapterColumns
  $reportOwnerMatches = @(if ($null -ne $reportOwnerReferences) { $reportOwnerReferences.Rows | Where-Object { $_.'Work Item ID' -ceq $masterRow.'Work Item ID' } })
  $planOwnerMatches = @(if ($null -ne $planOwnerReferences) { $planOwnerReferences.Rows | Where-Object { $_.'Work Item ID' -ceq $masterRow.'Work Item ID' } })
  $responsibilityAdapterMatches = @(if ($null -ne $responsibilityAdapters) { $responsibilityAdapters.Rows | Where-Object { $_.'Work Item ID' -ceq $masterRow.'Work Item ID' } })
  if ($null -eq $reportOwnerReferences -or $reportOwnerReferences.Rows.Count -ne 1 -or $reportOwnerMatches.Count -ne 1 -or $planOwnerMatches.Count -ne 1 -or $responsibilityAdapterMatches.Count -ne 1) {
    $errors.Add('responsibility-owner-missing')
    return
  }
  $responsibilityAdapterRow = $responsibilityAdapterMatches[0]
  if ($responsibilityAdapterRow.'Master Plan Reference' -cne $masterRow.'Master Plan Reference' -or $responsibilityAdapterRow.'Master Plan Revision' -cne $masterRow.'Master Plan Revision' -or $responsibilityAdapterRow.'Design Revision' -cne $externalSelector.'Design Revision') {
    $errors.Add('responsibility-owner-extra')
    return
  }
  if (($selectorRow.'Adapter Kind' -ceq 'migration-unit' -and $responsibilityAdapterRow.'Migration Unit ID' -cne $selectorRow.'External ID') -or ($selectorRow.'Adapter Kind' -cne 'migration-unit' -and $responsibilityAdapterRow.'Migration Unit ID' -cne 'not-applicable')) {
    $errors.Add('responsibility-owner-extra')
    return
  }
  foreach ($field in $ownerReferenceColumns) {
    if ($reportOwnerMatches[0].$field -cne $planOwnerMatches[0].$field) { $errors.Add('responsibility-owner-extra') }
  }

  $responsibilityDiagnostics = [Collections.Generic.List[string]]::new()
  $approvedResponsibilityMode = switch -Regex ($externalSelector.'Mode Constraint') {
    '^incremental/preserve-existing$' { 'incremental'; break }
    '^greenfield/design-new$' { 'greenfield'; break }
    default { $errors.Add('Structural gate approved selector has no canonical responsibility mode'); return }
  }
  foreach ($diagnostic in @(Test-ResponsibilityDiscovery -DiscoveryText $discoveryText -Mode $approvedResponsibilityMode -ContractText $responsibilityContractText)) { $responsibilityDiagnostics.Add($diagnostic) }
  foreach ($diagnostic in @(Test-ResponsibilityDesign -DiscoveryText $discoveryText -DesignText $designText -Mode $approvedResponsibilityMode -ContractText $responsibilityContractText)) { $responsibilityDiagnostics.Add($diagnostic) }
  $approvedDesignText = [regex]::Replace($designText, '(?m)^status:\s+draft\s*$', 'status: approved', 1)
  $approvedDesignText = [regex]::Replace($approvedDesignText, '(?m)^(result:\s+complete\s*)$', "`$1`napproval_source: human`nrun_id: $responsibilityPlanRunId", 1)
  foreach ($diagnostic in @(Test-ResponsibilityPlan -DesignText $approvedDesignText -PlanText $responsibilityPlanText -WorkItemId $masterRow.'Work Item ID' -ContractText $responsibilityContractText)) { $responsibilityDiagnostics.Add($diagnostic) }
  foreach ($diagnostic in @(Test-ResponsibilityImplementation -DesignText $designText -ImplementationText $report -ContractText $responsibilityContractText)) { $responsibilityDiagnostics.Add($diagnostic) }
  foreach ($diagnostic in @($responsibilityDiagnostics | Select-Object -Unique)) { $errors.Add($diagnostic) }
  if ($responsibilityDiagnostics.Count -gt 0) {
    $responsibilityAssurance = & $getTable $report 'Assurance State' @('Runtime Evidence State', 'Architecture Conformance State', 'Selector Schema State')
    if ($null -ne $responsibilityAssurance -and $responsibilityAssurance.Rows.Count -eq 1 -and $responsibilityAssurance.Rows[0].'Runtime Evidence State' -ceq 'WAIVED') {
      $errors.Add('responsibility-waiver-forbidden')
    }
  }
  $responsibilityVerdictColumns = @('Responsibility Contract Version', 'Tree Conformance', 'Responsibility Conformance', 'Verification Ownership', 'Architecture Conformance State', 'Evidence References')
  $responsibilityVerdicts = & $getTable $report 'Architecture Responsibility Verdicts' $responsibilityVerdictColumns
  if ($null -eq $responsibilityVerdicts -or $responsibilityVerdicts.Rows.Count -ne 1 -or $responsibilityVerdicts.Rows[0].'Tree Conformance' -cne 'PASS' -or $responsibilityVerdicts.Rows[0].'Responsibility Conformance' -cne 'PASS' -or $responsibilityVerdicts.Rows[0].'Verification Ownership' -cne 'PASS' -or $responsibilityVerdicts.Rows[0].'Architecture Conformance State' -cne 'PASS') {
    $errors.Add('Structural gate tree, responsibility, and verification ownership verdicts must all PASS')
  }

  $activationSliceColumns = @('Activation Slice ID', 'Applicability', 'Seam', 'Input', 'Output', 'Source Reference', 'Trace IDs', 'Disposition', 'Status', 'Decision Reference', 'Deferred Unit ID')
  $externalActivationSlices = & $getTable $designText 'Activation Slice' $activationSliceColumns
  $reportActivationSlices = & $getTable $report 'Activation Slice' $activationSliceColumns
  $canonicalSeamSection = [regex]::Match($activationContractText, '(?s)## Canonical seams\n(?<body>.*?)(?=\n## )').Groups['body'].Value
  $canonicalSeams = @([regex]::Matches($canonicalSeamSection, '(?m)^\d+\.\s+`(?<value>[^`]+)`\s*$') | ForEach-Object { $_.Groups['value'].Value })
  $legalActivationTable = & $getTable $activationContractText 'Legal row combinations' @('Applicability', 'Disposition', 'Status', 'Decision Reference', 'Deferred Unit ID')
  $canonicalTracePattern = '^[A-Z][A-Z0-9]*(?:-[A-Z0-9]+)+$'
  $traceValues = {
    param([string]$Value)
    return @($Value.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
  }
  $isTraceSubset = {
    param([string]$Candidate, [string]$Authority)
    $candidateValues = @(& $traceValues $Candidate)
    $authorityValues = @(& $traceValues $Authority)
    return (
      $candidateValues.Count -gt 0 -and
      @($candidateValues | Where-Object { $_ -cnotmatch $canonicalTracePattern }).Count -eq 0 -and
      @($candidateValues | Sort-Object -Unique).Count -eq $candidateValues.Count -and
      @($candidateValues | Where-Object { $authorityValues -cnotcontains $_ }).Count -eq 0
    )
  }
  $validateActivationEnvelope = {
    param([object]$Table)
    if ($null -eq $Table -or $canonicalSeams.Count -ne 9 -or $null -eq $legalActivationTable -or $Table.Rows.Count -eq 0 -or ($Table.Rows.Count % 9) -ne 0) { return $false }
    $sliceIds = @($Table.Rows | ForEach-Object { $_.'Activation Slice ID' } | Sort-Object -Unique)
    if ($sliceIds.Count -ne ($Table.Rows.Count / 9) -or @($sliceIds | Where-Object { $_ -cnotmatch '^ACT-[0-9]{3}$' }).Count -gt 0) { return $false }
    for ($offset = 0; $offset -lt $Table.Rows.Count; $offset += 9) {
      $expectedSliceId = $Table.Rows[$offset].'Activation Slice ID'
      for ($index = 0; $index -lt $canonicalSeams.Count; $index++) {
        $row = $Table.Rows[$offset + $index]
        if ($row.'Activation Slice ID' -cne $expectedSliceId -or $row.Seam -cne $canonicalSeams[$index] -or (& $missing $row.Input) -or (& $missing $row.Output) -or (& $missing $row.'Source Reference') -or -not (& $isTraceSubset $row.'Trace IDs' $externalWorkItemMatches[0].'Trace IDs')) { return $false }
        $compatibilityDecisionOverride = $row.Seam -ceq 'construct' -and $row.Output -cmatch '(?:^|;\s*)policy=compatibility-dual-path(?:;|$)' -and $row.'Decision Reference' -cne 'not-applicable' -and -not (& $missing $row.'Decision Reference')
        $legalMatches = @($legalActivationTable.Rows | Where-Object {
          $_.Applicability.Trim('`') -ceq $row.Applicability -and $_.Disposition.Trim('`') -ceq $row.Disposition -and $_.Status.Trim('`') -ceq $row.Status -and
          (($_.'Decision Reference'.Trim('`') -ceq '<approval-reference>' -and $row.'Decision Reference' -cne 'not-applicable' -and -not (& $missing $row.'Decision Reference')) -or $_.'Decision Reference'.Trim('`') -ceq $row.'Decision Reference' -or ($compatibilityDecisionOverride -and $_.'Decision Reference'.Trim('`') -ceq 'not-applicable')) -and
          (($_.'Deferred Unit ID'.Trim('`') -ceq 'UNIT-[0-9]{3}' -and $row.'Deferred Unit ID' -cmatch '^UNIT-[0-9]{3}$') -or $_.'Deferred Unit ID'.Trim('`') -ceq $row.'Deferred Unit ID')
        })
        if ($legalMatches.Count -ne 1 -or $row.Applicability -cnotin @('applicable', 'not-applicable-approved') -or $row.Status -cne 'verified') { return $false }
      }
      if (@($Table.Rows | Select-Object -Skip $offset -First 9 | ForEach-Object { $_.Applicability } | Sort-Object -Unique).Count -ne 1) { return $false }
    }
    foreach ($sliceId in $sliceIds) {
      $sliceRows = @($Table.Rows | Where-Object { $_.'Activation Slice ID' -ceq $sliceId })
      $construct = @($sliceRows | Where-Object { $_.Seam -ceq 'construct' })[0]
      $selector = @($sliceRows | Where-Object { $_.Seam -ceq 'selector' })[0]
      $testSeam = @($sliceRows | Where-Object { $_.Seam -ceq 'test' })[0]
      if ($sliceRows[0].Applicability -ceq 'not-applicable-approved') { continue }
      $routerPolicyMatch = [regex]::Match($construct.Output, '(?:^|;\s*)policy=(?<value>base-owned|specialized-owned|injected-strategy|compatibility-dual-path)(?:;|$)')
      $compatibilityValid = $true
      if ($routerPolicyMatch.Success -and $routerPolicyMatch.Groups['value'].Value -ceq 'compatibility-dual-path') {
        $constructTraceIds = @(& $traceValues $construct.'Trace IDs')
        $compatibilityValid = (
          $construct.'Source Reference' -cmatch '(?:^|;\s*)compatibility-reason=\S[^;]*(?:;|$)' -and
          $construct.'Source Reference' -cmatch '(?:^|;\s*)router-owner=\S[^;]*(?:;|$)' -and
          $construct.'Decision Reference' -cne 'not-applicable' -and -not (& $missing $construct.'Decision Reference') -and
          @($constructTraceIds | Where-Object { $_ -cmatch '^PARITY-[0-9]{3}$' }).Count -gt 0
        )
      }
      if (-not (
        $routerPolicyMatch.Success -and $compatibilityValid -and
        (($selector.Input -cmatch '(?:^|;\s*)async-classification=immutable(?:;|$)' -and $selector.'Source Reference' -cmatch '(?:^|;\s*)immutability-evidence=\S.*(?:;|$)') -or
         ($selector.Input -cmatch '(?:^|;\s*)async-classification=async(?:;|$)' -and $selector.Output -match 'initial-loading=' -and $selector.Output -match 'update-watch=' -and $selector.Output -match 'reselection=' -and $selector.Output -match 'state-preservation-reset=' -and $selector.Output -match 'failure-behavior=')) -and
        $testSeam.Output -cmatch '(?:^|;\s*)lifecycle-test-trace=[A-Z][A-Z0-9]*(?:-[A-Z0-9]+)+(?:;|$)'
      )) { return $false }
    }
    return $true
  }
  $externalSliceIds = if ($null -ne $externalActivationSlices) { @($externalActivationSlices.Rows | ForEach-Object { $_.'Activation Slice ID' } | Sort-Object -Unique) } else { @() }
  $reportSliceIds = if ($null -ne $reportActivationSlices) { @($reportActivationSlices.Rows | ForEach-Object { $_.'Activation Slice ID' } | Sort-Object -Unique) } else { @() }
  if ($null -eq $externalActivationSlices -or $null -eq $reportActivationSlices -or $externalActivationSlices.Rows.Count -ne $reportActivationSlices.Rows.Count -or ($externalSliceIds -join '|') -cne ($reportSliceIds -join '|')) {
    $errors.Add('Structural gate report Activation Slice set must equal external authority in both directions'); return
  }
  if (-not (& $validateActivationEnvelope $externalActivationSlices)) {
    $errors.Add('Structural gate external Activation Slice violates canonical activation-slice contract'); return
  }
  if (-not (& $validateActivationEnvelope $reportActivationSlices)) {
    $errors.Add('Structural gate report Activation Slice violates canonical activation-slice contract'); return
  }
  foreach ($reportSlice in $reportActivationSlices.Rows) {
    $externalSlice = @($externalActivationSlices.Rows | Where-Object { $_.'Activation Slice ID' -ceq $reportSlice.'Activation Slice ID' -and $_.Seam -ceq $reportSlice.Seam })
    if ($externalSlice.Count -ne 1) { $errors.Add('Structural gate report Activation Slice must preserve external Task 6 authority'); return }
    foreach ($field in @('Activation Slice ID', 'Applicability', 'Seam', 'Input', 'Output', 'Disposition', 'Status', 'Decision Reference', 'Deferred Unit ID')) {
      if ($reportSlice.$field -cne $externalSlice[0].$field) { $errors.Add('Structural gate report Activation Slice must preserve external Task 6 authority'); return }
    }
    if (-not (& $isTraceSubset $externalSlice[0].'Trace IDs' $reportSlice.'Trace IDs')) {
      $errors.Add('Structural gate report Activation Slice Trace IDs must preserve predecessor traces with append-only enrichment'); return
    }
    $sourcePrefix = $externalSlice[0].'Source Reference'
    if ($reportSlice.'Source Reference' -cne $sourcePrefix -and $reportSlice.'Source Reference' -cnotmatch ('^' + [regex]::Escape($sourcePrefix) + ';\s+\S.*$')) {
      $errors.Add('Structural gate report Activation Slice Source Reference must preserve or canonically enrich external authority'); return
    }
  }

  $contractConcernSection = & $getSection $normalizedContractText 'Comparable Target Exemplars'
  $concerns = @([regex]::Matches($contractConcernSection, '(?m)^\s*\d+\.\s+`(?<name>[^`]+)`\s*$') | ForEach-Object { $_.Groups['name'].Value })
  $exemplarColumns = @('Concern', 'Path', 'Inspected Symbols', 'Evidence', 'Read Status')
  $exemplars = & $getTable $report 'Exemplar Read Evidence' $exemplarColumns
  if ($null -eq $exemplars -or $concerns.Count -ne 8) { $errors.Add('Structural gate missing contract-derived Exemplar Read Evidence'); return }
  $externalExemplarColumns = @('Concern', 'Path', 'Inspected Symbols', 'Observed Pattern', 'Primary Responsibility', 'Owned Capabilities', 'Verification Owner', 'Comparable Reason', 'Evidence', 'Inspection Status', 'Classification', 'Classification Authority', 'Classification Evidence')
  $externalExemplars = & $getTable $discoveryText 'Comparable Target Exemplars' $externalExemplarColumns
  if ($null -eq $externalExemplars -or $externalExemplars.Rows.Count -ne $concerns.Count -or $exemplars.Rows.Count -ne $concerns.Count) {
    $errors.Add('Structural gate exemplar cardinality must exactly match the external approved discovery'); return
  }
  foreach ($concern in $concerns) {
    $rows = @($exemplars.Rows | Where-Object { $_.Concern -ceq $concern })
    $externalRows = @($externalExemplars.Rows | Where-Object { $_.Concern -ceq $concern })
    if ($rows.Count -ne 1 -or $rows[0].'Read Status' -cne 'read-complete') { $errors.Add("Structural gate exemplar must be read-complete: $concern"); continue }
    if ($externalRows.Count -ne 1 -or $externalRows[0].'Inspection Status' -cnotin @('verified', 'no-equivalent') -or $rows[0].Path -cne $externalRows[0].Path -or $rows[0].'Inspected Symbols' -cne $externalRows[0].'Inspected Symbols' -or $rows[0].Evidence -cne $externalRows[0].Evidence) {
      $errors.Add("Structural gate exemplar must match external approved discovery evidence: $concern")
    }
  }

  $externalMatrixColumns = @('Concern', 'Working Exemplar', 'Observed Target Pattern', 'Proposed Path/Symbol', 'Conforms', 'Deviation Reference')
  $externalMatrix = & $getTable $designText 'Target Structure Conformance Matrix' $externalMatrixColumns
  if ($null -eq $externalMatrix -or $externalMatrix.Rows.Count -ne $concerns.Count) {
    $errors.Add('Structural gate external design matrix must cover exactly the canonical concerns'); return
  }
  foreach ($concern in $concerns) {
    if (@($externalMatrix.Rows | Where-Object { $_.Concern -ceq $concern }).Count -ne 1) {
      $errors.Add("Structural gate external design matrix concern must appear exactly once: $concern")
    }
  }

  $treeColumns = @('Planned Path', 'Planned Symbol', 'Actual Path', 'Actual Symbol', 'Match', 'Evidence')
  $tree = & $getTable $report 'Actual File Tree vs Planned File Tree' $treeColumns
  $externalTreeColumns = @('Planned Path', 'Planned Symbol', 'Responsibility', 'Exemplar or Deviation Reference')
  $externalTree = & $getTable $designText 'Planned File Tree' $externalTreeColumns
  if ($null -eq $tree -or $tree.Rows.Count -eq 0) { $errors.Add('Structural gate missing Actual File Tree vs Planned File Tree') }
  elseif ($null -eq $externalTree -or $tree.Rows.Count -ne $externalTree.Rows.Count) { $errors.Add('Structural gate actual/planned mapping must cover the complete external approved planned tree') }
  else {
    foreach ($row in $tree.Rows) {
      $externalRows = @($externalTree.Rows | Where-Object { $_.'Planned Path' -ceq $row.'Planned Path' -and $_.'Planned Symbol' -ceq $row.'Planned Symbol' })
      if ($externalRows.Count -ne 1 -or $row.'Planned Path' -cne $row.'Actual Path' -or $row.'Planned Symbol' -cne $row.'Actual Symbol' -or $row.Match -cne 'yes' -or (& $missing $row.Evidence)) { $errors.Add('Structural gate actual file tree must match the complete external approved planned path and symbol') }
    }
    foreach ($externalRow in $externalTree.Rows) {
      if (@($tree.Rows | Where-Object { $_.'Planned Path' -ceq $externalRow.'Planned Path' -and $_.'Planned Symbol' -ceq $externalRow.'Planned Symbol' }).Count -ne 1) {
        $errors.Add('Structural gate actual/planned mapping must be one-to-one with the external approved planned tree')
      }
    }
  }

  $boundaryColumns = @('Boundary', 'Planned Owner Path/Symbol', 'Actual Owner Path/Symbol', 'Invocation Path', 'Mechanism', 'Lifecycle/Failure Evidence', 'Verdict')
  $hasDirectWidgetEdge = {
    param([string]$InvocationPath)
    $segments = @($InvocationPath -split '\s*->\s*' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
    for ($index = 0; $index -lt ($segments.Count - 1); $index++) {
      $widgetSegment = $segments[$index]
      $targetSegment = $segments[$index + 1]
      $isWidget = $widgetSegment -cmatch '(?i)^(?:[A-Za-z_][A-Za-z0-9_]*\.)*[A-Za-z_][A-Za-z0-9_]*Widget(?:\s*\([^)]*\))?(?:\.[A-Za-z_][A-Za-z0-9_]*(?:\s*\([^)]*\))?)*$|^(?i:widget)(?:\.[A-Za-z_][A-Za-z0-9_]*(?:\s*\([^)]*\))?)*$'
      $isServiceOrRouter = $targetSegment -cmatch '(?i)^(?:[A-Za-z_][A-Za-z0-9_]*\.)*(?:[A-Za-z_][A-Za-z0-9_]*(?:Service|Router)|service|router)(?:\s*\([^)]*\))?(?:\.[A-Za-z_][A-Za-z0-9_]*(?:\s*\([^)]*\))?)*$'
      if ($isWidget -and $isServiceOrRouter) { return $true }
    }
    return $false
  }
  $boundaries = & $getTable $report 'Target Boundary Conformance' $boundaryColumns
  $externalBoundaryColumns = @('Boundary', 'Owner Path/Symbol', 'Input', 'Output', 'Lifecycle/Failure Policy', 'Evidence')
  $externalBoundaries = & $getTable $designText 'Provider/Router/Localization/Subscription Boundaries' $externalBoundaryColumns
  if ($null -eq $boundaries) { $errors.Add('Structural gate missing Target Boundary Conformance') }
  elseif ($null -eq $externalBoundaries) { $errors.Add('Structural gate external approved design boundaries are malformed') }
  else {
    if ($boundaries.Rows.Count -ne 5 -or $externalBoundaries.Rows.Count -ne 5) { $errors.Add('Structural gate boundaries must exactly match the five external approved design boundaries') }
    foreach ($requiredBoundary in @('provider', 'router', 'localization', 'subscription', 'lifecycle')) {
      $rows = @($boundaries.Rows | Where-Object { $_.Boundary -ceq $requiredBoundary })
      if ($rows.Count -ne 1) { $errors.Add("Structural gate missing required boundary: $requiredBoundary"); continue }
      $row = $rows[0]
      $externalRows = @($externalBoundaries.Rows | Where-Object { $_.Boundary -ceq $requiredBoundary })
      $approvedMechanism = if ($externalRows.Count -eq 1) { [regex]::Match($externalRows[0].'Lifecycle/Failure Policy', '^mechanism=(?<value>[A-Za-z_][A-Za-z0-9_.-]*);').Groups['value'].Value } else { '' }
      if ($externalRows.Count -ne 1 -or $row.'Planned Owner Path/Symbol' -cne $externalRows[0].'Owner Path/Symbol' -or $row.'Actual Owner Path/Symbol' -cne $row.'Planned Owner Path/Symbol' -or $row.Mechanism -cne $approvedMechanism -or (& $missing $row.'Invocation Path') -or (& $missing $row.'Lifecycle/Failure Evidence') -or $row.Verdict -cne 'PASS') { $errors.Add("Structural gate boundary must match external approved owner and mechanism: $requiredBoundary") }
      if ($requiredBoundary -cin @('provider', 'router') -and (& $hasDirectWidgetEdge $row.'Invocation Path')) { $errors.Add('Structural gate provider boundary forbids direct widget service or router calls') }
      if ($requiredBoundary -ceq 'localization' -and $row.Mechanism -cne $approvedMechanism) { $errors.Add('Structural gate localization must use the external approved target localization boundary') }
    }
  }

  $deviationColumns = @('Deviation Reference', 'Concern', 'Conflict Reference', 'Actual Abstraction', 'Resolved Decision', 'Tech Lead Approval', 'Status')
  $deviations = & $getTable $report 'Exemplar Deviations' $deviationColumns
  $externalDeviationColumns = @('Deviation Reference', 'Concern', 'Conflict Reference', 'Resolved Decision', 'Tech Lead Approval')
  $externalDeviations = & $getTable $designText 'Approved Structural Deviations' $externalDeviationColumns
  if ($null -eq $deviations -or $deviations.Rows.Count -eq 0) { $errors.Add('Structural gate missing Exemplar Deviations disposition') }
  elseif ($null -eq $externalDeviations -or $externalDeviations.Rows.Count -eq 0) { $errors.Add('Structural gate external Approved Structural Deviations is malformed') }
  else {
    $requiredDeviationRows = @($externalMatrix.Rows | Where-Object { $_.Conforms -ceq 'no' })
    $externalSentinelRows = @($externalDeviations.Rows | Where-Object { $_.'Deviation Reference' -ceq 'none' })
    $sentinelRows = @($deviations.Rows | Where-Object { $_.'Deviation Reference' -ceq 'not-applicable' })
    if ($sentinelRows.Count -gt 0 -and ($deviations.Rows.Count -ne 1 -or @($sentinelRows[0].PSObject.Properties.Value | Where-Object { $_ -cne 'not-applicable' }).Count -gt 0)) {
      $errors.Add('Structural gate deviation sentinel must be one exact all-not-applicable row')
    }
    if (($requiredDeviationRows.Count -eq 0 -and $sentinelRows.Count -ne 1) -or ($requiredDeviationRows.Count -gt 0 -and ($sentinelRows.Count -ne 0 -or $deviations.Rows.Count -ne $requiredDeviationRows.Count))) {
      $errors.Add('Structural gate deviations must exactly match external approved matrix dispositions')
    }
    if (($requiredDeviationRows.Count -eq 0 -and ($externalSentinelRows.Count -ne 1 -or @($externalSentinelRows[0].PSObject.Properties.Value | Select-Object -Skip 1 | Where-Object { $_ -cne 'not-applicable' }).Count -gt 0)) -or ($requiredDeviationRows.Count -gt 0 -and ($externalSentinelRows.Count -ne 0 -or $externalDeviations.Rows.Count -ne $requiredDeviationRows.Count))) {
      $errors.Add('Structural gate Task 6 Approved Structural Deviations must exactly cover matrix deviations')
    }
    foreach ($row in @($deviations.Rows | Where-Object { $_.'Deviation Reference' -cne 'not-applicable' })) {
      $externalRows = @($requiredDeviationRows | Where-Object { $_.Concern -ceq $row.Concern -and $_.'Deviation Reference' -ceq $row.'Deviation Reference' })
      $externalApprovalRows = @($externalDeviations.Rows | Where-Object { $_.'Deviation Reference' -ceq $row.'Deviation Reference' -and $_.Concern -ceq $row.Concern })
      if ($externalRows.Count -ne 1 -or $externalApprovalRows.Count -ne 1 -or $row.'Conflict Reference' -cne $externalApprovalRows[0].'Conflict Reference' -or $row.'Resolved Decision' -cne $externalApprovalRows[0].'Resolved Decision' -or $row.'Tech Lead Approval' -cne $externalApprovalRows[0].'Tech Lead Approval' -or $row.'Deviation Reference' -cnotmatch '^DEV-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -or $row.'Conflict Reference' -cnotmatch '^CONFLICT-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -or (& $missing $row.'Actual Abstraction') -or $row.'Resolved Decision' -cnotmatch '^resolved:DECISION-[A-Z0-9]+(?:-[A-Z0-9]+)*:\s+\S.*$' -or $row.'Tech Lead Approval' -cnotmatch '^approval:TECH-LEAD-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -or $row.Status -cne 'approved') { $errors.Add('Structural gate deviation must exactly bind Task 6 approved conflict, decision and Tech Lead approval') }
    }
  }

  $activationColumns = @('Applicability', 'Decision Reference', 'Entry Point', 'Registration', 'Runtime Path', 'Production Evidence', 'Verdict')
  $activation = & $getTable $report 'Production Activation Path Evidence' $activationColumns
  if ($null -eq $activation -or $activation.Rows.Count -ne 1) { $errors.Add('Structural gate missing Production Activation Path Evidence') }
  else {
    $row = $activation.Rows[0]
    if ($row.Applicability -ceq 'applicable') {
      if (@($externalActivationSlices.Rows | Where-Object { $_.Applicability -cne 'applicable' }).Count -gt 0) { $errors.Add('Structural gate production activation applicability must match external Activation Slice authority'); return }
      $approvedEntryPoint = @($externalBoundaries.Rows | Where-Object { $_.Boundary -ceq 'router' })[0].'Owner Path/Symbol'
      $constructRows = @($externalActivationSlices.Rows | Where-Object { $_.Seam -ceq 'construct' })
      $testRows = @($externalActivationSlices.Rows | Where-Object { $_.Seam -ceq 'test' })
      $approvedRegistration = if ($constructRows.Count -eq 1) { "$approvedEntryPoint @ $($constructRows[0].Output)" } else { '' }
      $approvedProductionEvidence = if ($testRows.Count -eq 1) { "$($testRows[0].Output) @ $($testRows[0].'Source Reference')" } else { '' }
      if ($row.'Decision Reference' -cne 'not-applicable' -or $row.'Entry Point' -cne $approvedEntryPoint -or $row.Registration -cne $approvedRegistration -or $approvedEntryPoint -cnotmatch $pathSymbolPattern -or $row.'Production Evidence' -cne $approvedProductionEvidence -or (& $missing $approvedProductionEvidence) -or $row.'Runtime Path' -cnotmatch '(?i)(?:^|\s*->\s*)subscription(?:\s*->\s*|$)' -or $row.'Runtime Path' -cnotmatch '(?i)(?:^|\s*->\s*)lifecycle(?:\s*->\s*|$)' -or $row.Verdict -cne 'PASS') { $errors.Add('Structural gate applicable production activation path must match external registration/production authority, prove subscription and lifecycle, and PASS') }
    }
    else {
      $externalActivationDecisions = @($externalActivationSlices.Rows | ForEach-Object { $_.'Decision Reference' } | Sort-Object -Unique)
      if ($row.Applicability -cne 'not-applicable-approved' -or @($externalActivationSlices.Rows | Where-Object { $_.Applicability -cne 'not-applicable-approved' }).Count -gt 0 -or $externalActivationDecisions.Count -ne 1 -or $row.'Decision Reference' -cne $externalActivationDecisions[0] -or $row.'Decision Reference' -cnotmatch '^approval:TECH-LEAD-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -or $row.'Entry Point' -cne 'not-applicable' -or $row.Registration -cne 'not-applicable' -or $row.'Runtime Path' -cne 'not-applicable' -or $row.'Production Evidence' -cne 'not-applicable' -or $row.Verdict -cne 'NOT_APPLICABLE') { $errors.Add('Structural gate non-applicable activation requires an explicit external approved decision and exact sentinel fields') }
    }
  }

  $assuranceColumns = @('Runtime Evidence State', 'Architecture Conformance State', 'Selector Schema State')
  $assurance = & $getTable $report 'Assurance State' $assuranceColumns
  if ($null -eq $assurance -or $assurance.Rows.Count -ne 1) { $errors.Add('Structural gate missing independent Assurance State') }
  else {
    $row = $assurance.Rows[0]
    if ($row.'Runtime Evidence State' -cnotin @('PASS', 'FAIL', 'NOT_RUN', 'WAIVED')) { $errors.Add('Structural gate runtime evidence state is invalid') }
    if ($row.'Architecture Conformance State' -cne 'PASS' -or $row.'Selector Schema State' -cne 'PASS') { $errors.Add('Structural gate architecture and selector/schema states must both be PASS and are not waiver-eligible') }
  }

  $changedFileColumns = @('Work Item ID', 'Activation Slice ID', 'Seam', 'File', 'Change', 'Trace IDs')
  $testEvidenceColumns = @('Work Item ID', 'Activation Slice ID', 'Seam', 'Test', 'Command', 'Result', 'Trace IDs')
  $changedFiles = & $getTable $report 'Work Item Changed Files' $changedFileColumns
  $testEvidence = & $getTable $report 'Work Item Test Evidence' $testEvidenceColumns
  if ($null -eq $changedFiles -or $changedFiles.Rows.Count -eq 0) { $errors.Add('Structural gate report requires Work Item Changed Files evidence') }
  if ($null -eq $testEvidence -or $testEvidence.Rows.Count -eq 0) { $errors.Add('Structural gate report requires Work Item Test Evidence') }
  if ($null -ne $changedFiles -and $null -ne $testEvidence -and $null -ne $externalActivationSlices) {
    $changedKeys = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($changedRow in $changedFiles.Rows) {
      $key = "$($changedRow.'Activation Slice ID')|$($changedRow.Seam)|$($changedRow.File)"
      $sliceMatches = @($externalActivationSlices.Rows | Where-Object { $_.'Activation Slice ID' -ceq $changedRow.'Activation Slice ID' -and $_.Seam -ceq $changedRow.Seam })
      $actualFileMatches = @($tree.Rows | Where-Object { $_.'Actual Path' -ceq $changedRow.File })
      if (-not $changedKeys.Add($key) -or $changedRow.'Work Item ID' -cne $masterRow.'Work Item ID' -or $sliceMatches.Count -ne 1 -or $actualFileMatches.Count -ne 1 -or (& $missing $changedRow.Change)) {
        $errors.Add('Structural gate changed-file evidence must uniquely bind Work Item ID, Activation Slice, file and Trace IDs')
      }
      elseif (-not (& $isTraceSubset $changedRow.'Trace IDs' $sliceMatches[0].'Trace IDs') -or -not (& $isTraceSubset $changedRow.'Trace IDs' $externalWorkItemMatches[0].'Trace IDs')) {
        $errors.Add('Structural gate changed-file evidence Trace IDs must be a non-empty canonical subset')
      }
    }
    $testKeys = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($testRow in $testEvidence.Rows) {
      $key = "$($testRow.'Activation Slice ID')|$($testRow.Seam)|$($testRow.Test)"
      $sliceMatches = @($externalActivationSlices.Rows | Where-Object { $_.'Activation Slice ID' -ceq $testRow.'Activation Slice ID' -and $_.Seam -ceq $testRow.Seam })
      if (-not $testKeys.Add($key) -or $testRow.'Work Item ID' -cne $masterRow.'Work Item ID' -or $sliceMatches.Count -ne 1 -or (& $missing $testRow.Command) -or $testRow.Result -cnotin @('PASS', 'FAIL', 'BLOCKED')) {
        $errors.Add('Structural gate test evidence must uniquely bind Work Item ID, Activation Slice and Trace IDs')
      }
      elseif (-not (& $isTraceSubset $testRow.'Trace IDs' $sliceMatches[0].'Trace IDs') -or -not (& $isTraceSubset $testRow.'Trace IDs' $externalWorkItemMatches[0].'Trace IDs')) {
        $errors.Add('Structural gate test evidence Trace IDs must be a non-empty canonical subset')
      }
    }
  }
  if ($designApprovalRow.'Design Digest' -cne (& $getDigest $designText)) {
    $errors.Add('Structural gate technical design content digest must match the external approval artifact')
  }
}

$script:MigrationResponsibilityRolloutValidator = {
  param([AllowEmptyString()][string]$MigrateText)

  $diagnostics = [Collections.Generic.List[string]]::new()
  $invalid = $false
  $normalized = (($MigrateText -replace "`r`n", "`n") -replace "`r", "`n")
  $heading = 'Responsibility v1 rollout and safe post-implementation stop'
  $headingMatches = @([regex]::Matches($normalized, '(?m)^## ' + [regex]::Escape($heading) + '$'))
  if ($headingMatches.Count -ne 1) {
    $invalid = $true
  }
  else {
    $tail = $normalized.Substring($headingMatches[0].Index + $headingMatches[0].Length)
    $nextHeading = [regex]::Match($tail, '(?m)^## ')
    $section = if ($nextHeading.Success) { $tail.Substring(0, $nextHeading.Index) } else { $tail }
    $requiredStatements = @(
      'After implementation review creates the handoff, resolve exactly one immediate-predecessor `Architecture Responsibility Handoff` with responsibility contract version `1` and immutable source-diff `Evidence References` before verification, parity, regression, delivery, Knowledge Base completion, or terminal completion.',
      'Queue selection, resume, and dependency unlock use pre-edit planned authority:',
      'A separate `Terminal Chain Reference` equals the final artifact of the mode-aware ordered chain',
      'The terminal chain uses the approved `Delivery Adapter Mode Constraint` preserved from its step-8 selector through step-10 canonical authority, never a terminal or chain self-label; the initial review is approved/complete/human, every chain artifact stays in the current run and binds the current master spec/plan/work item, and each source-diff SHA pair exactly equals immutable Task Provenance.',
      '`architecture_conformance_state` is derived: it is `PASS` only when Tree Conformance, Responsibility Conformance, and Verification Ownership are all `PASS`; otherwise it is `BLOCKED`.',
      'Runtime `auto-waive` never changes Tree, Responsibility, or Verification Ownership sub-verdicts.',
      'Do not create a Phase 2 remediation artifact or work item automatically.',
      'implementation `draft/blocked` -> AI review `Reject` -> work item `blocked` -> dependent item non-eligible -> parity/regression/delivery/KB/terminal completion blocked -> approved design/master-plan revision required'
    )
    foreach ($statement in $requiredStatements) {
      if (-not $section.Contains($statement)) { $invalid = $true }
    }

    $lines = @($section -split "`n")
    $tables = [Collections.Generic.List[object]]::new()
    for ($index = 0; $index -lt $lines.Count; $index++) {
      if ($lines[$index] -cnotmatch '^\|.*\|$') { continue }
      $start = $index
      while ($index -lt $lines.Count -and $lines[$index] -cmatch '^\|.*\|$') { $index++ }
      $tables.Add(@($lines[$start..($index - 1)]))
    }
    if ($tables.Count -ne 1) {
      $invalid = $true
    }
    else {
      $tableLines = @($tables[0])
      $splitRow = {
        param([string]$Line)
        if ($Line -cne $Line.Trim() -or $Line -cnotmatch '^\|[^|]+(?:\|[^|]+)*\|$') { return @() }
        return @($Line.Substring(1, $Line.Length - 2).Split('|') | ForEach-Object { $_.Trim() })
      }
      $columns = @(
        'Input / condition', 'Compatibility disposition', 'Derived architecture state',
        'Queue and selection', 'Downstream boundary', 'Required resume authority'
      )
      $expectedRows = @(
        @('v1 exact handoff; Tree PASS; Responsibility PASS; Verification PASS; immutable evidence resolves', 'executable', 'PASS', 'current approved work item only', 'normal gates', 'current approved design/master-plan'),
        @('any structural sub-verdict BLOCKED or missing or mismatched immutable evidence link', 'blocked', 'BLOCKED', 'scope-blocked; next eligible item: none; no dependent selection', 'stop before parity, regression, delivery, KB, and terminal completion', 'approved design/master-plan revision required'),
        @('completed pre-v1 artifact', 'historical-only', 'not executable', 'no selection or resume from artifact', 'no downstream completion authority', 'approved v1 backfill before future executable work'),
        @('in-progress pre-v1 artifact', 'blocked', 'BLOCKED', 'no resume; no production mutation; no dependent selection', 'stop before parity, regression, delivery, KB, and terminal completion', 'approved design/master-plan revision with v1 backfill required'),
        @('mixed v1/v2 or cross-run evidence', 'blocked', 'BLOCKED', 'scope-blocked; next eligible item: none; no dependent selection', 'stop before parity, regression, delivery, KB, and terminal completion', 'approved design/master-plan revision required')
      )
      if ($tableLines.Count -ne ($expectedRows.Count + 2)) {
        $invalid = $true
      }
      else {
        $actualColumns = @(& $splitRow $tableLines[0])
        $delimiter = @(& $splitRow $tableLines[1])
        if (
          ($actualColumns -join '|') -cne ($columns -join '|') -or
          $delimiter.Count -ne $columns.Count -or
          @($delimiter | Where-Object { $_ -cnotmatch '^:?-{3,}:?$' }).Count -gt 0
        ) {
          $invalid = $true
        }
        for ($rowIndex = 0; $rowIndex -lt $expectedRows.Count; $rowIndex++) {
          $actualRow = @(& $splitRow $tableLines[$rowIndex + 2])
          if (($actualRow -join '|') -cne ($expectedRows[$rowIndex] -join '|')) { $invalid = $true }
        }
      }
    }
  }
  if ($invalid) { $diagnostics.Add('migration-responsibility-rollout-invalid') }
  return $diagnostics.ToArray()
}

function Test-ArchitectureReview([string]$Root, [string]$ContractText) {
  $contractPath = Join-Path $Root 'contracts/target-structure-conformance.md'
  if (-not (Test-Path -LiteralPath $contractPath -PathType Leaf)) {
    $errors.Add('Missing target structure conformance contract resource')
    return
  }
  @(
    '## Architecture-first review order',
    'Architecture-first review order: master-scope/work-item alignment -> project rule resolution -> canonical selector -> architecture conformance with matrix/exemplars -> production activation path -> behavior, failure modes, security, performance, and tests -> change hygiene.',
    'Architecture Conformance Verdict: PASS | BLOCKED',
    'Canonical Selector Verdict: PASS | BLOCKED',
    'Production Activation-path Verdict: PASS | BLOCKED | NOT_APPLICABLE',
    'Any `BLOCKED` verdict makes the overall verdict `Reject`.'
  ) | ForEach-Object {
    Require-Token $ContractText $_ 'Architecture review contract'
  }

  $responsibilityValidatorPath = Join-Path $PSScriptRoot 'responsibility-conformance.validation.ps1'
  if (-not (Test-Path -LiteralPath $responsibilityValidatorPath -PathType Leaf)) {
    $errors.Add("Architecture review validation missing responsibility review helper: $responsibilityValidatorPath")
    return
  }
  . $responsibilityValidatorPath

  $paths = [ordered]@{
    ReviewSkill = Join-Path $Root 'skills/shared/ai-review/SKILL.md'
    KnowledgeSkill = Join-Path $Root 'skills/shared/knowledge-base/SKILL.md'
    ReviewTemplate = Join-Path $Root 'templates/migration/review-report.md'
    KnowledgeTemplate = Join-Path $Root 'templates/kb-entry.md'
  }
  foreach ($entry in $paths.GetEnumerator()) {
    if (-not (Test-Path -LiteralPath $entry.Value -PathType Leaf)) {
      $errors.Add("Architecture review validation missing $($entry.Key): $($entry.Value)")
    }
  }
  if (@($paths.Values | Where-Object { -not (Test-Path -LiteralPath $_ -PathType Leaf) }).Count -gt 0) {
    return
  }

  $reviewSkill = Get-Content -Raw -Encoding utf8 -LiteralPath $paths.ReviewSkill
  $knowledgeSkill = Get-Content -Raw -Encoding utf8 -LiteralPath $paths.KnowledgeSkill
  $reviewTemplate = Get-Content -Raw -Encoding utf8 -LiteralPath $paths.ReviewTemplate
  $knowledgeTemplate = Get-Content -Raw -Encoding utf8 -LiteralPath $paths.KnowledgeTemplate
  $visibleReviewTemplate = Get-ArcVisibleMarkdownText -Text $reviewTemplate

  $getHeadings = {
    param([string]$Text)
    $records = [Collections.Generic.List[object]]::new()
    $inFence = $false
    $fenceMarker = ''
    $inComment = $false
    $lines = @($Text -split '\r?\n')
    for ($index = 0; $index -lt $lines.Count; $index++) {
      $line = $lines[$index]
      if ($inComment) {
        if ($line -cmatch '-->') { $inComment = $false }
        continue
      }
      if ($line -cmatch '<!--') {
        if ($line -cnotmatch '-->') { $inComment = $true }
        continue
      }
      $fence = [regex]::Match($line, '^[ ]{0,3}(?<marker>`{3,}|~{3,})')
      if ($fence.Success) {
        $marker = $fence.Groups['marker'].Value
        if (-not $inFence) {
          $inFence = $true
          $fenceMarker = $marker.Substring(0, 1)
        }
        elseif ($marker.Substring(0, 1) -ceq $fenceMarker) {
          $inFence = $false
          $fenceMarker = ''
        }
        continue
      }
      if ($inFence) { continue }
      $match = [regex]::Match($line, '^[ ]{0,3}(?<marker>#{1,6})[ \t]+(?<name>.*?)[ \t]*#*[ \t]*$')
      if ($match.Success) {
        $records.Add([pscustomobject]@{
          Index = $index
          Level = $match.Groups['marker'].Value.Length
          Name = $match.Groups['name'].Value.Trim()
        })
      }
    }
    return @($records)
  }

  $getSection = {
    param([string]$Text, [string]$Name, [string]$Context)
    $headings = @(& $getHeadings $Text)
    $matches = @($headings | Where-Object { $_.Level -eq 2 -and $_.Name -ceq $Name })
    if ($matches.Count -ne 1) {
      $errors.Add("$Context section must appear exactly once: $Name; found $($matches.Count)")
      return ''
    }
    $lines = @($Text -split '\r?\n')
    $start = $matches[0].Index + 1
    $next = @($headings | Where-Object { $_.Index -ge $start -and $_.Level -le 2 } | Sort-Object Index | Select-Object -First 1)
    $end = if ($next.Count -eq 1) { $next[0].Index } else { $lines.Count }
    if ($start -ge $end) { return '' }
    return ($lines[$start..($end - 1)] -join [Environment]::NewLine)
  }

  $assertHeadingOrder = {
    param([string]$Text, [string[]]$Names, [string]$Context)
    $headings = @(& $getHeadings $Text | Where-Object { $_.Level -eq 2 })
    $last = -1
    foreach ($name in $Names) {
      $matches = @($headings | Where-Object { $_.Name -ceq $name })
      if ($matches.Count -ne 1) {
        $errors.Add("$Context section must appear exactly once: $name; found $($matches.Count)")
        continue
      }
      if ($matches[0].Index -le $last) {
        $errors.Add("$Context requires architecture-first section order; $name is out of order")
      }
      $last = $matches[0].Index
    }
  }

  $parseStrictTableRow = {
    param([string]$Line, [string]$Context)
    if ($Line -cne $Line.Trim() -or $Line -cnotmatch '^\|[^|]+(?:\|[^|]+)*\|$') {
      $errors.Add("$Context has invalid table framing")
      return @()
    }
    $cells = @($Line.Substring(1, $Line.Length - 2).Split('|') | ForEach-Object { $_.Trim() })
    if ($cells.Count -eq 0 -or @($cells | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -gt 0) {
      $errors.Add("$Context contains an empty table cell")
      return @()
    }
    return $cells
  }

  $getStrictContractTable = {
    param([string]$Text, [string]$SectionName, [string[]]$Columns, [string]$Context)
    $body = & $getSection $Text $SectionName $Context
    if ([string]::IsNullOrWhiteSpace($body)) {
      $errors.Add("$Context $SectionName must contain exactly one contractual table; found 0")
      return $null
    }
    $lines = @($body -split '\r?\n')
    $tables = [Collections.Generic.List[object]]::new()
    $index = 0
    while ($index -lt ($lines.Count - 1)) {
      if ($lines[$index] -cmatch '^\|.*\|$' -and $lines[$index + 1] -cmatch '^\|.*\|$') {
        $start = $index
        while ($index -lt $lines.Count -and $lines[$index] -cmatch '^\|.*\|$') { $index++ }
        $tables.Add([pscustomobject]@{ Lines = @($lines[$start..($index - 1)]) })
        continue
      }
      $index++
    }
    if ($tables.Count -ne 1) {
      $errors.Add("$Context $SectionName must contain exactly one contractual table; found $($tables.Count)")
      return $null
    }
    $tableLines = @($tables[0].Lines)
    if ($tableLines.Count -ne 3) {
      $errors.Add("$Context $SectionName contractual table must contain one header, one delimiter, and exactly one data row; found $($tableLines.Count) rows")
      return $null
    }
    $actual = @(& $parseStrictTableRow $tableLines[0] "$Context $SectionName header")
    $delimiter = @(& $parseStrictTableRow $tableLines[1] "$Context $SectionName delimiter")
    $data = @(& $parseStrictTableRow $tableLines[2] "$Context $SectionName data row")
    if ($actual.Count -gt 0 -and ($actual -join '|') -cne ($Columns -join '|')) {
      $errors.Add("$Context $SectionName table columns must be exactly: $($Columns -join ' | ')")
    }
    if (
      $delimiter.Count -ne $Columns.Count -or
      @($delimiter | Where-Object { $_ -cnotmatch '^:?-{3,}:?$' }).Count -gt 0
    ) {
      $errors.Add("$Context $SectionName table delimiter must use one valid Markdown separator per column")
    }
    if ($data.Count -ne $Columns.Count) {
      $errors.Add("$Context $SectionName data row cardinality must equal $($Columns.Count); found $($data.Count)")
    }
    return [pscustomobject]@{ Header = $actual; Row = $data }
  }

  $gateSection = & $getSection $reviewSkill 'Architecture-first migration review gates' 'AI Review architecture gates'
  $orderedGatePatterns = @(
    '(?im)^1\.\s+Master scope and work-item alignment\.',
    '(?im)^2\.\s+Project rule resolution\.',
    '(?im)^3\.\s+Canonical selector validation\.',
    '(?im)^4\.\s+Tree conformance from final inventory and source/diff evidence\.',
    '(?im)^5\.\s+Responsibility conformance against planned responsibility evidence\.',
    '(?im)^6\.\s+Verification ownership from final inventory and source/diff evidence\.',
    '(?im)^7\.\s+Production activation-path validation\.',
    '(?im)^8\.\s+Behavior, failure modes, security, performance, and tests\.',
    '(?im)^9\.\s+Change hygiene\.'
  )
  $lastGate = -1
  foreach ($pattern in $orderedGatePatterns) {
    $match = [regex]::Match($gateSection, $pattern)
    if (-not $match.Success -or $match.Index -le $lastGate) {
      $errors.Add('AI Review architecture gates require exact architecture-first review gate order')
      break
    }
    $lastGate = $match.Index
  }
  @(
    'The reviewer independently inspects the final inventory and task-base/final-tree source diff.',
    'Implementation self-attestation is not semantic PASS evidence.',
    'Missing master context, canonical selector, conformance matrix, exemplar, actual/planned tree evidence, responsibility review evidence, verification ownership evidence, or applicable production activation evidence',
    'sets the overall verdict to `Reject`',
    'stops before reviewer dispatch and before behavior analysis',
    'Rule Resolution remains an independent first severity gate',
    'Any `BLOCKED` verdict makes the overall verdict `Reject`, independently of severity counts.'
  ) | ForEach-Object { Require-Token $gateSection $_ 'AI Review architecture gates' }

  @(
    'Procedure ordering: load rule resources without evaluating Rule Resolution.',
    'Procedure ordering: validate Master Scope Context/work-item alignment before evaluating Rule Resolution.'
  ) | ForEach-Object { Require-Token $reviewSkill $_ 'AI Review procedure' }
  $masterProcedureIndex = $reviewSkill.IndexOf('Procedure ordering: validate Master Scope Context/work-item alignment', [StringComparison]::Ordinal)
  $ruleProcedureIndex = if ($masterProcedureIndex -ge 0) {
    $reviewSkill.IndexOf('before evaluating Rule Resolution.', $masterProcedureIndex, [StringComparison]::Ordinal)
  }
  else { -1 }
  if ($masterProcedureIndex -lt 0 -or $ruleProcedureIndex -le $masterProcedureIndex) {
    $errors.Add('AI Review procedure must evaluate master alignment before project Rule Resolution')
  }

  $findingsSection = & $getSection $reviewSkill 'Mandatory architecture findings' 'AI Review mandatory architecture findings'
  @(
    'invented aggregate state',
    'direct widget service/router calls',
    'raw layout replacing the target wrapper',
    'missing unit boundary',
    'wrong localization mechanism',
    'missing lifecycle gate',
    'tests bypassing the production provider',
    'missing production subscription key',
    'planned/actual tree drift',
    'unapproved structural deviation',
    'Classify a missing production subscription key as `Critical`.',
    'at least `Major`',
    '`Critical` when activation, routing, or rendering fails'
  ) | ForEach-Object { Require-Token $findingsSection $_ 'AI Review mandatory architecture findings' }

  & $assertHeadingOrder $visibleReviewTemplate @(
    'Master Scope Context',
    'Rule Resolution',
    'Canonical Selector',
    'Architecture Conformance',
    'Responsibility Review Evidence',
    'Production Activation Path',
    'Behavior, Failure Modes, Security, Performance, and Tests',
    'Critical',
    'Change Hygiene'
  ) 'Migration review report'

  $masterContextTable = & $getStrictContractTable $visibleReviewTemplate 'Master Scope Context' @(
    'Run ID', 'Master Spec Reference', 'Master Spec ID', 'Master Spec Revision',
    'Master Plan Reference', 'Master Plan ID', 'Master Plan Revision', 'Work Item ID'
  ) 'Migration review report'
  $taskProvenanceTable = & $getStrictContractTable $visibleReviewTemplate 'Task Provenance' @(
    'Task / Unit', 'Task-base SHA', 'Final-tree SHA', 'Source Artifact'
  ) 'Migration review report'
  $responsibilityHandoffTable = & $getStrictContractTable $visibleReviewTemplate 'Architecture Responsibility Handoff' @(
    'Responsibility Contract Version', 'Tree Conformance', 'Responsibility Conformance',
    'Verification Ownership', 'Architecture Conformance State', 'Evidence References'
  ) 'Migration review report'

  $verdictValues = [ordered]@{}
  $verdictModes = [Collections.Generic.List[string]]::new()
  $ruleResolution = ''
  $ruleResolutionSection = & $getSection $visibleReviewTemplate 'Rule Resolution' 'Migration review report'
  $ruleResolutionMatches = [regex]::Matches($ruleResolutionSection, '(?im)^[ \t]*-[ \t]*Rule Resolution Verdict:[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$')
  if ($ruleResolutionMatches.Count -ne 1) {
    $errors.Add("Migration review report Rule Resolution Verdict must appear exactly once; found $($ruleResolutionMatches.Count)")
  }
  else {
    $ruleResolution = $ruleResolutionMatches[0].Groups['value'].Value.Trim().Trim([char[]]@('<', '>', '`'))
    if ($ruleResolution -ceq 'RESOLVED | BLOCKED') { $verdictModes.Add('schema') }
    elseif ($ruleResolution -in @('RESOLVED', 'BLOCKED')) { $verdictModes.Add('rendered') }
    else { $errors.Add("Migration review report Rule Resolution Verdict has invalid value: $ruleResolution") }
  }
  @(
    [pscustomobject]@{ Label = 'Architecture Conformance Verdict'; Schema = 'PASS | BLOCKED'; Allowed = @('PASS', 'BLOCKED') }
    [pscustomobject]@{ Label = 'Canonical Selector Verdict'; Schema = 'PASS | BLOCKED'; Allowed = @('PASS', 'BLOCKED') }
    [pscustomobject]@{ Label = 'Tree Conformance Verdict'; Schema = 'PASS | BLOCKED'; Allowed = @('PASS', 'BLOCKED') }
    [pscustomobject]@{ Label = 'Responsibility Conformance Verdict'; Schema = 'PASS | BLOCKED'; Allowed = @('PASS', 'BLOCKED') }
    [pscustomobject]@{ Label = 'Verification Ownership Verdict'; Schema = 'PASS | BLOCKED'; Allowed = @('PASS', 'BLOCKED') }
    [pscustomobject]@{ Label = 'Production Activation-path Verdict'; Schema = 'PASS | BLOCKED | NOT_APPLICABLE'; Allowed = @('PASS', 'BLOCKED', 'NOT_APPLICABLE') }
    [pscustomobject]@{ Label = 'Change Hygiene Verdict'; Schema = 'PASS | BLOCKED'; Allowed = @('PASS', 'BLOCKED') }
  ) | ForEach-Object {
    $matches = [regex]::Matches($visibleReviewTemplate, '(?im)^[ \t]*-[ \t]*(?:\*\*)?' + [regex]::Escape($_.Label) + '(?:\*\*)?:[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$')
    if ($matches.Count -ne 1) {
      $errors.Add("Migration review report $($_.Label) must appear exactly once with the exact enum; found $($matches.Count)")
      return
    }
    $value = $matches[0].Groups['value'].Value.Trim().Trim([char[]]@('<', '>', '`'))
    if ($value -ceq $_.Schema) {
      $verdictModes.Add('schema')
    }
    elseif ($value -in $_.Allowed) {
      $verdictModes.Add('rendered')
    }
    else {
      $errors.Add("Migration review report $($_.Label) has invalid verdict: $value")
    }
    $verdictValues[$_.Label] = $value
  }

  $selectorSection = & $getSection $visibleReviewTemplate 'Canonical Selector' 'Migration review report'
  Require-Token $selectorSection 'Evidence:' 'Migration review canonical selector'
  $architectureSection = & $getSection $visibleReviewTemplate 'Architecture Conformance' 'Migration review report'
  @('Conformance Matrix Reference:', 'Exemplars:', 'Actual File Tree vs Planned File Tree:') |
    ForEach-Object { Require-Token $architectureSection $_ 'Migration review architecture conformance' }
  $responsibilityReviewSection = & $getSection $visibleReviewTemplate 'Responsibility Review Evidence' 'Migration review report'
  $responsibilityReviewLines = @($responsibilityReviewSection -split '\r?\n' | Where-Object { $_ -cmatch '^\|.*\|$' })
  $responsibilityReviewColumns = @('Responsibility ID', 'Source/Diff Evidence', 'Planned Public Symbols', 'Actual Public Symbols', 'Planned Effects', 'Actual Effects', 'Verdict')
  if ($responsibilityReviewLines.Count -ne 2) {
    $errors.Add("Migration review Responsibility Review Evidence requires exactly one header and one delimiter row; found $($responsibilityReviewLines.Count)")
  }
  else {
    $actualReviewColumns = @(& $parseStrictTableRow $responsibilityReviewLines[0] 'Migration review Responsibility Review Evidence header')
    $reviewDelimiter = @(& $parseStrictTableRow $responsibilityReviewLines[1] 'Migration review Responsibility Review Evidence delimiter')
    if (($actualReviewColumns -join '|') -cne ($responsibilityReviewColumns -join '|')) {
      $errors.Add("Migration review Responsibility Review Evidence table columns must be exactly: $($responsibilityReviewColumns -join ' | ')")
    }
    if ($reviewDelimiter.Count -ne $responsibilityReviewColumns.Count -or @($reviewDelimiter | Where-Object { $_ -cnotmatch '^:?-{3,}:?$' }).Count -gt 0) {
      $errors.Add('Migration review Responsibility Review Evidence table delimiter must use one valid Markdown separator per column')
    }
  }

  $reviewArtifactPath = Join-Path $Root 'artifacts/review-report.md'
  $implementationArtifactPath = Join-Path $Root 'artifacts/implementation-report.md'
  $designArtifactPath = Join-Path $Root 'artifacts/design-report.md'
  $approvedPlanArtifactPath = Join-Path $Root 'artifacts/master-plan.md'
  $provenanceArtifactPath = Join-Path $Root 'artifacts/review-provenance.md'
  $reviewArtifacts = @($reviewArtifactPath, $implementationArtifactPath, $designArtifactPath, $approvedPlanArtifactPath, $provenanceArtifactPath)
  $presentReviewArtifacts = @($reviewArtifacts | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
  if ($presentReviewArtifacts.Count -gt 0 -and $presentReviewArtifacts.Count -ne $reviewArtifacts.Count) {
    $errors.Add('Architecture review requires planned, implementation, review, and pinned source provenance artifacts together')
  }
  elseif ($presentReviewArtifacts.Count -eq $reviewArtifacts.Count) {
    $responsibilityContractPath = Join-Path $Root 'contracts/file-responsibility-conformance.md'
    if (-not (Test-Path -LiteralPath $responsibilityContractPath -PathType Leaf)) {
      $errors.Add('Architecture review is missing the responsibility contract for independent review evidence')
    }
    else {
      $designArtifact = Get-Content -Raw -Encoding utf8 -LiteralPath $designArtifactPath
      $implementationArtifact = Get-Content -Raw -Encoding utf8 -LiteralPath $implementationArtifactPath
      $reviewArtifact = Get-Content -Raw -Encoding utf8 -LiteralPath $reviewArtifactPath
      $approvedPlanArtifact = Get-Content -Raw -Encoding utf8 -LiteralPath $approvedPlanArtifactPath
      $responsibilityContract = Get-Content -Raw -Encoding utf8 -LiteralPath $responsibilityContractPath
      $provenance = Get-Content -Raw -Encoding utf8 -LiteralPath $provenanceArtifactPath
      $sourceRootMatches = [regex]::Matches($provenance, '(?im)^Source Root:\s*(?<value>[^\r\n]+?)\s*$')
      $taskBaseMatches = [regex]::Matches($provenance, '(?im)^Task-base SHA:\s*(?<value>[0-9a-f]{40})\s*$')
      $finalTreeMatches = [regex]::Matches($provenance, '(?im)^Final-tree SHA:\s*(?<value>[0-9a-f]{40})\s*$')
      if ($sourceRootMatches.Count -ne 1 -or $taskBaseMatches.Count -ne 1 -or $finalTreeMatches.Count -ne 1) {
        $errors.Add('Architecture review requires one pinned source root, task-base SHA, and final-tree SHA')
      }
      else {
        $sourceRoot = $sourceRootMatches[0].Groups['value'].Value.Trim()
        $taskBaseSha = $taskBaseMatches[0].Groups['value'].Value
        $finalTreeSha = $finalTreeMatches[0].Groups['value'].Value
        foreach ($error in @(Test-ResponsibilityReview -DesignText $designArtifact -ImplementationText $implementationArtifact -ReviewText $reviewArtifact -ContractText $responsibilityContract -SourceRoot $sourceRoot -TaskBaseSha $taskBaseSha -FinalTreeSha $finalTreeSha -ApprovedPlanText $approvedPlanArtifact)) {
          $errors.Add($error)
        }
      }
    }
  }
  $activationSection = & $getSection $visibleReviewTemplate 'Production Activation Path' 'Migration review report'
  @('Production Activation Path Evidence:', 'Production Subscription Key:', 'Lifecycle Gate:') |
    ForEach-Object { Require-Token $activationSection $_ 'Migration review production activation path' }
  $behaviorSection = & $getSection $visibleReviewTemplate 'Behavior, Failure Modes, Security, Performance, and Tests' 'Migration review report'
  Require-Token $behaviorSection 'Behavior Analysis State:' 'Migration review behavior analysis'
  $behaviorMatches = [regex]::Matches($behaviorSection, '(?im)^[ \t]*-[ \t]*Behavior Analysis State:[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$')
  $behaviorState = ''
  if ($behaviorMatches.Count -ne 1) {
    $errors.Add("Migration review report Behavior Analysis State must appear exactly once; found $($behaviorMatches.Count)")
  }
  else {
    $behaviorState = $behaviorMatches[0].Groups['value'].Value.Trim().Trim([char[]]@('<', '>', '`'))
    if ($behaviorState -ceq 'NOT_RUN | COMPLETE') { $verdictModes.Add('schema') }
    elseif ($behaviorState -in @('NOT_RUN', 'COMPLETE')) { $verdictModes.Add('rendered') }
    else { $errors.Add("Migration review report Behavior Analysis State has invalid value: $behaviorState") }
  }

  $overallMatches = [regex]::Matches($visibleReviewTemplate, '(?im)^[ \t]*-[ \t]*(?:\*\*)?Verdict(?:\*\*)?:[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$')
  if ($overallMatches.Count -ne 1) {
    $errors.Add("Migration review report overall Verdict must appear exactly once; found $($overallMatches.Count)")
  }
  else {
    $overallVerdict = $overallMatches[0].Groups['value'].Value.Trim().Trim([char[]]@('<', '>', '`'))
    if ($overallVerdict -ceq 'Approve | Approve-with-fixes | Reject') {
      $verdictModes.Add('schema')
    }
    elseif ($overallVerdict -in @('Approve', 'Approve-with-fixes', 'Reject')) {
      $verdictModes.Add('rendered')
    }
    else {
      $errors.Add("Migration review report overall Verdict has invalid value: $overallVerdict")
    }
  }

  $criticalCount = -1
  $majorCount = -1
  foreach ($countDefinition in @(
    [pscustomobject]@{ Label = 'Critical count'; Target = 'critical' }
    [pscustomobject]@{ Label = 'Major count'; Target = 'major' }
  )) {
    $countMatches = [regex]::Matches($visibleReviewTemplate, '(?im)^[ \t]*-[ \t]*(?:\*\*)?' + [regex]::Escape($countDefinition.Label) + ':(?:\*\*)?[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$')
    if ($countMatches.Count -ne 1) {
      $errors.Add("Migration review report $($countDefinition.Label) must appear exactly once; found $($countMatches.Count)")
      continue
    }
    $countValue = $countMatches[0].Groups['value'].Value.Trim().Trim([char[]]@('<', '>', '`'))
    if ($countValue -ceq 'non-negative integer') {
      $verdictModes.Add('schema')
      continue
    }
    if ($countValue -cnotmatch '^[0-9]+$') {
      $errors.Add("Migration review report $($countDefinition.Label) must be a non-negative integer; got $countValue")
      continue
    }
    $verdictModes.Add('rendered')
    if ($countDefinition.Target -ceq 'critical') { $criticalCount = [int]$countValue }
    else { $majorCount = [int]$countValue }
  }

  $distinctVerdictModes = @($verdictModes | Select-Object -Unique)
  if ($verdictModes.Count -ne 12 -or $distinctVerdictModes.Count -ne 1) {
    $errors.Add('Migration review report must use either all-schema or all-rendered verdict mode; mixed mode is invalid')
  }
  elseif ($distinctVerdictModes[0] -ceq 'rendered') {
    $derivedArchitecture = if (
      $verdictValues['Tree Conformance Verdict'] -ceq 'PASS' -and
      $verdictValues['Responsibility Conformance Verdict'] -ceq 'PASS' -and
      $verdictValues['Verification Ownership Verdict'] -ceq 'PASS'
    ) { 'PASS' } else { 'BLOCKED' }
    if ($verdictValues['Architecture Conformance Verdict'] -cne $derivedArchitecture) {
      $errors.Add('Migration review report Architecture Conformance Verdict must equal the verdict derived from Tree, Responsibility, and Verification Ownership')
    }
    if (
      $null -ne $responsibilityHandoffTable -and
      (
        $responsibilityHandoffTable.Row[1] -cne $verdictValues['Tree Conformance Verdict'] -or
        $responsibilityHandoffTable.Row[2] -cne $verdictValues['Responsibility Conformance Verdict'] -or
        $responsibilityHandoffTable.Row[3] -cne $verdictValues['Verification Ownership Verdict'] -or
        $responsibilityHandoffTable.Row[4] -cne $verdictValues['Architecture Conformance Verdict']
      )
    ) {
      $errors.Add('Migration review report handoff cells must equal the visible Tree, Responsibility, Verification Ownership, and derived Architecture verdicts')
    }
    $blockedPreBehaviorVerdicts = @(
      @(
        'Canonical Selector Verdict', 'Architecture Conformance Verdict',
        'Tree Conformance Verdict', 'Responsibility Conformance Verdict',
        'Verification Ownership Verdict', 'Production Activation-path Verdict'
      ) | Where-Object { $verdictValues[$_] -ceq 'BLOCKED' }
    )
    $preBehaviorBlocked =
      $ruleResolution -ceq 'BLOCKED' -or
      $blockedPreBehaviorVerdicts.Count -gt 0
    if ($preBehaviorBlocked -and $behaviorState -cne 'NOT_RUN') {
      $errors.Add('Migration review report must stop before behavior analysis when an architecture-first verdict is BLOCKED')
    }
    $allGatesExecutable =
      -not $preBehaviorBlocked -and
      $behaviorState -ceq 'COMPLETE' -and
      $verdictValues['Change Hygiene Verdict'] -ceq 'PASS'
    $derivedOverall = if (-not $allGatesExecutable -or $criticalCount -gt 0) {
      'Reject'
    }
    elseif ($majorCount -gt 0) { 'Approve-with-fixes' }
    else { 'Approve' }
    if ($overallVerdict -cne $derivedOverall) {
      $errors.Add("Migration review report overall Verdict must equal derived verdict $derivedOverall")
    }
  }

  if (
    $visibleReviewTemplate -cnotmatch '(?s)Keep `Selected Migration Unit` only when `Delivery Adapter Kind` is `migration-unit`.*otherwise omit it\.' -and
    $visibleReviewTemplate -cnotmatch '(?s)Chỉ giữ `Selected Migration Unit` khi `Delivery Adapter Kind` là `migration-unit`.*otherwise omit it\.'
  ) {
    $errors.Add('Migration review report must keep Selected Migration Unit only for the migration-unit adapter and otherwise omit it')
  }

  $selectedHeadings = @(& $getHeadings $visibleReviewTemplate | Where-Object { $_.Level -eq 2 -and $_.Name -ceq 'Selected Migration Unit' })
  $adapterMatches = [regex]::Matches($visibleReviewTemplate, '(?im)^[ \t]*-[ \t]*Delivery Adapter Kind:[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$')
  $adapterKind = if ($adapterMatches.Count -eq 1) {
    $adapterMatches[0].Groups['value'].Value.Trim().Trim([char[]]@('<', '>', '`'))
  }
  else {
    $errors.Add("Migration review report Delivery Adapter Kind must appear exactly once; found $($adapterMatches.Count)")
    ''
  }
  $adapterKinds = @('migration-unit', 'task', 'story', 'package', 'phase', 'milestone', 'none')
  $adapterSchemaMode = $adapterKind -in @('kind', 'migration-unit | task | story | package | phase | milestone | none')
  if (
    -not $adapterSchemaMode -and
    $null -ne $masterContextTable -and
    @($masterContextTable.Row | Where-Object { $_ -match '^<.*>$' }).Count -gt 0
  ) {
    $errors.Add('Rendered migration review report requires concrete Master Scope Context values')
  }
  if ($adapterSchemaMode -or $adapterKind -ceq 'migration-unit') {
    if ($selectedHeadings.Count -ne 1) {
      $errors.Add("Migration review report requires exactly one Selected Migration Unit section for migration-unit/schema adapter; found $($selectedHeadings.Count)")
    }
    else {
      $selectedTable = & $getStrictContractTable $visibleReviewTemplate 'Selected Migration Unit' @(
        'Migration Unit ID', 'Plan Reference', 'Approval Reference', 'Mode Constraint', 'Bootstrap Scope',
        'Foundation Baseline ID', 'Foundation Baseline Reference', 'Foundation Baseline Approval Reference',
        'Baseline Reference', 'Trace IDs'
      ) 'Migration review report'
      if ($adapterKind -ceq 'migration-unit' -and $null -ne $selectedTable -and @($selectedTable.Row | Where-Object { $_ -match '^<.*>$' }).Count -gt 0) {
        $errors.Add('Rendered migration-unit review report requires concrete canonical Selected Migration Unit values')
      }
    }
  }
  elseif ($adapterKind -in $adapterKinds) {
    if ($selectedHeadings.Count -ne 0) {
      $errors.Add("Migration review report generic adapter $adapterKind requires zero Selected Migration Unit sections; found $($selectedHeadings.Count)")
    }
  }
  else {
    $errors.Add("Migration review report Delivery Adapter Kind has invalid value: $adapterKind")
  }

  $scopeCapture = & $getSection $knowledgeSkill 'Scope-aware migration capture' 'Knowledge Capture scope semantics'
  @(
    'work-item verdict',
    'exact master-plan transition',
    'required items remaining',
    'next eligible item or blocker',
    'calculated scope status',
    'Scope-completion formula',
    'Never infer `scope-complete` from one execution artifact, one completed work item, or a successful attempt.',
    'scope-in-progress'
  ) | ForEach-Object { Require-Token $scopeCapture $_ 'Knowledge Capture scope semantics' }

  & $assertHeadingOrder $knowledgeTemplate @(
    'Work Item and Master Plan Transition',
    'Scope Status Calculation'
  ) 'Knowledge Base entry'
  $workTransitionTable = & $getStrictContractTable $knowledgeTemplate 'Work Item and Master Plan Transition' @(
    'Work Item ID', 'Work Item Verdict', 'Master Plan Reference', 'Master Plan Revision', 'Transition', 'Terminal Evidence'
  ) 'Knowledge Base entry'
  $scopeStatusTable = & $getStrictContractTable $knowledgeTemplate 'Scope Status Calculation' @(
    'Required Items Remaining', 'Next Eligible Item', 'Blocker', 'Dependency Graph State',
    'Required Items Terminal-success', 'Architecture Conformance State', 'Selector Schema State',
    'Terminal Scope Report', 'Calculated Scope Status', 'Calculation Evidence'
  ) 'Knowledge Base entry'

  if ($null -ne $workTransitionTable -and $null -ne $scopeStatusTable -and $scopeStatusTable.Row.Count -eq 10) {
    $workSchemaCells = @($workTransitionTable.Row | Where-Object { $_ -cmatch '^<.*>$' }).Count
    $scopeSchemaCells = @($scopeStatusTable.Row | Where-Object { $_ -cmatch '^<.*>$' }).Count
    $kbAllSchema = $workSchemaCells -eq $workTransitionTable.Row.Count -and $scopeSchemaCells -eq $scopeStatusTable.Row.Count
    $kbAllRendered = $workSchemaCells -eq 0 -and $scopeSchemaCells -eq 0
    if (-not $kbAllSchema -and -not $kbAllRendered) {
      $errors.Add('Knowledge Base scope tables must use either all-schema or all-rendered mode; mixed placeholder/concrete rows are invalid')
    }
    $workVerdict = $workTransitionTable.Row[1].Trim().Trim([char[]]@('<', '>', '`'))
    $scopeStatus = $scopeStatusTable.Row[8].Trim().Trim([char[]]@('<', '>', '`'))
    if ($kbAllRendered) {
      $remaining = $scopeStatusTable.Row[0]
      $nextEligible = $scopeStatusTable.Row[1]
      $blocker = $scopeStatusTable.Row[2]
      $graphState = $scopeStatusTable.Row[3]
      $requiredTerminal = $scopeStatusTable.Row[4]
      $architectureState = $scopeStatusTable.Row[5]
      $selectorState = $scopeStatusTable.Row[6]
      $terminalReport = $scopeStatusTable.Row[7]
      $calculationEvidence = $scopeStatusTable.Row[9]
      $calculationEvidenceTokens = @($calculationEvidence.Split(';') | ForEach-Object { $_.Trim() })
      if ($scopeStatus -notin @('planned', 'scope-in-progress', 'scope-blocked', 'scope-complete', 'scope-cancelled-approved')) {
        $errors.Add("Knowledge Base Calculated Scope Status has invalid value: $scopeStatus")
      }
      if ($workVerdict -notin @('complete', 'blocked', 'cancelled-approved', 'not-applicable-approved')) {
        $errors.Add("Knowledge Base Work Item Verdict has invalid rendered value: $workVerdict")
      }
      if ($graphState -notin @('valid', 'invalid')) {
        $errors.Add("Knowledge Base Dependency Graph State has invalid rendered value: $graphState")
      }
      if ($requiredTerminal -notin @('all-terminal-success', 'remaining')) {
        $errors.Add("Knowledge Base Required Items Terminal-success has invalid rendered value: $requiredTerminal")
      }
      if ($architectureState -notin @('PASS', 'BLOCKED') -or $selectorState -notin @('PASS', 'BLOCKED')) {
        $errors.Add('Knowledge Base rendered architecture and selector states must use PASS or BLOCKED')
      }
      if ($scopeStatus -ceq 'scope-complete') {
        $completeFormulaSatisfied =
          $remaining -ceq 'none' -and
          $nextEligible -ceq 'none' -and
          $blocker -ceq 'none' -and
          $graphState -ceq 'valid' -and
          $requiredTerminal -ceq 'all-terminal-success' -and
          $architectureState -ceq 'PASS' -and
          $selectorState -ceq 'PASS' -and
          $terminalReport -cmatch '^scope-terminal-report\.md#[A-Za-z0-9._/-]+$' -and
          $calculationEvidenceTokens -ccontains 'all-required-terminal-evidence'
        if (-not $completeFormulaSatisfied) {
          $errors.Add('Knowledge Base scope-complete requires remaining=none, next=none, blocker=none, valid graph, all required terminal-success, architecture/selector PASS, and terminal scope report with all evidence')
        }
      }
      if (
        $workVerdict -ceq 'complete' -and
        $remaining -cne 'none' -and
        $blocker -ceq 'none' -and
        $scopeStatus -cne 'scope-in-progress'
      ) {
        $errors.Add('Knowledge Base completed work item with a required item remaining must calculate scope-in-progress')
      }
    }
  }
}

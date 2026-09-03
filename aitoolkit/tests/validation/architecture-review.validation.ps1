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
    if ([string]::IsNullOrWhiteSpace($body)) { return $null }
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
    '(?im)^4\.\s+Architecture conformance against the approved matrix and exemplars\.',
    '(?im)^5\.\s+Production activation-path validation\.',
    '(?im)^6\.\s+Behavior, failure modes, security, performance, and tests\.',
    '(?im)^7\.\s+Change hygiene\.'
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
    'Missing master context, canonical selector, conformance matrix, exemplar, actual/planned tree evidence, or applicable production activation evidence',
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

  & $assertHeadingOrder $reviewTemplate @(
    'Master Scope Context',
    'Rule Resolution',
    'Canonical Selector',
    'Architecture Conformance',
    'Production Activation Path',
    'Behavior, Failure Modes, Security, Performance, and Tests',
    'Critical',
    'Change Hygiene'
  ) 'Migration review report'

  $masterContextTable = & $getStrictContractTable $reviewTemplate 'Master Scope Context' @(
    'Master Spec Reference', 'Master Plan Reference', 'Master Plan Revision', 'Work Item ID', 'Delivery Adapter Kind'
  ) 'Migration review report'

  $verdictValues = [ordered]@{}
  $verdictModes = [Collections.Generic.List[string]]::new()
  @(
    [pscustomobject]@{ Label = 'Architecture Conformance Verdict'; Schema = 'PASS | BLOCKED'; Allowed = @('PASS', 'BLOCKED') }
    [pscustomobject]@{ Label = 'Canonical Selector Verdict'; Schema = 'PASS | BLOCKED'; Allowed = @('PASS', 'BLOCKED') }
    [pscustomobject]@{ Label = 'Production Activation-path Verdict'; Schema = 'PASS | BLOCKED | NOT_APPLICABLE'; Allowed = @('PASS', 'BLOCKED', 'NOT_APPLICABLE') }
  ) | ForEach-Object {
    $matches = [regex]::Matches($reviewTemplate, '(?im)^[ \t]*-[ \t]*(?:\*\*)?' + [regex]::Escape($_.Label) + '(?:\*\*)?:[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$')
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

  $selectorSection = & $getSection $reviewTemplate 'Canonical Selector' 'Migration review report'
  Require-Token $selectorSection 'Evidence:' 'Migration review canonical selector'
  $architectureSection = & $getSection $reviewTemplate 'Architecture Conformance' 'Migration review report'
  @('Conformance Matrix Reference:', 'Exemplars:', 'Actual File Tree vs Planned File Tree:') |
    ForEach-Object { Require-Token $architectureSection $_ 'Migration review architecture conformance' }
  $activationSection = & $getSection $reviewTemplate 'Production Activation Path' 'Migration review report'
  @('Production Activation Path Evidence:', 'Production Subscription Key:', 'Lifecycle Gate:') |
    ForEach-Object { Require-Token $activationSection $_ 'Migration review production activation path' }
  $behaviorSection = & $getSection $reviewTemplate 'Behavior, Failure Modes, Security, Performance, and Tests' 'Migration review report'
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

  $overallMatches = [regex]::Matches($reviewTemplate, '(?im)^[ \t]*-[ \t]*(?:\*\*)?Verdict(?:\*\*)?:[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$')
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

  $distinctVerdictModes = @($verdictModes | Select-Object -Unique)
  if ($verdictModes.Count -ne 5 -or $distinctVerdictModes.Count -ne 1) {
    $errors.Add('Migration review report must use either all-schema or all-rendered verdict mode; mixed mode is invalid')
  }
  elseif ($distinctVerdictModes[0] -ceq 'rendered') {
    $concreteVerdicts = @($verdictValues.Values)
    if ($concreteVerdicts -contains 'BLOCKED') {
      if ($overallVerdict -cne 'Reject') {
        $errors.Add('Migration review report requires overall Reject when any architecture-first verdict is BLOCKED, independently of severity counts')
      }
      if ($behaviorState -cne 'NOT_RUN') {
        $errors.Add('Migration review report must stop before behavior analysis when an architecture-first verdict is BLOCKED')
      }
    }
  }

  if (
    $reviewTemplate -cnotmatch '(?s)Keep `Selected Migration Unit` only when `Delivery Adapter Kind` is `migration-unit`.*otherwise omit it\.' -and
    $reviewTemplate -cnotmatch '(?s)Chỉ giữ `Selected Migration Unit` khi `Delivery Adapter Kind` là `migration-unit`.*otherwise omit it\.'
  ) {
    $errors.Add('Migration review report must keep Selected Migration Unit only for the migration-unit adapter and otherwise omit it')
  }

  $selectedHeadings = @(& $getHeadings $reviewTemplate | Where-Object { $_.Level -eq 2 -and $_.Name -ceq 'Selected Migration Unit' })
  $adapterKind = if ($null -ne $masterContextTable -and $masterContextTable.Row.Count -eq 5) {
    $masterContextTable.Row[4].Trim().Trim([char[]]@('<', '>', '`'))
  }
  else { '' }
  $adapterKinds = @('migration-unit', 'task', 'story', 'package', 'phase', 'milestone', 'none')
  $adapterSchemaMode = $adapterKind -in @('kind', 'migration-unit / task / story / package / phase / milestone / none')
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
      $selectedTable = & $getStrictContractTable $reviewTemplate 'Selected Migration Unit' @(
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

function Test-DeliveryAdapters([string]$Root, [string]$ContractText) {
  $contractPath = Join-Path $Root 'contracts/migration-scope-orchestration.md'
  if (-not (Test-Path -LiteralPath $contractPath -PathType Leaf)) {
    $errors.Add('Missing migration scope orchestration contract resource')
    return
  }
  @(
    '## Delivery adapter kinds',
    'Delivery adapter kinds: `migration-unit | task | story | package | phase | milestone | none`.',
    'external_id: UNIT-ADM-002',
    'parent_selector: not-applicable',
    '## Decomposition',
    'Decomposition creates a new master-plan revision and canonical child selectors must be approved before adapter assignment.'
  ) | ForEach-Object {
    Require-Token $ContractText $_ 'Migration delivery adapter contract'
  }

  $staticRequirements = @(
    @('skills/migration/build-inventory/SKILL.md', '## Work item and decomposition trace'),
    @('skills/migration/feature-mapping/SKILL.md', '## Work item and decomposition trace'),
    @('skills/migration/analyze-gaps-conflicts/SKILL.md', '## Work item and decomposition trace'),
    @('skills/migration/plan-waves/SKILL.md', 'UNIT-* is the canonical migration-unit adapter ID, not a generic work-item taxonomy'),
    @('skills/migration/plan-waves/SKILL.md', 'Parent Work Item ID'),
    @('skills/migration/plan-waves/SKILL.md', 'Decomposition Decision Reference'),
    @('skills/migration/plan-waves/SKILL.md', 'exact Dependencies equivalence'),
    @('skills/migration/plan-waves/SKILL.md', 'Generic adapters preserve Work Item Trace through steps 04-08'),
    @('skills/migration/plan-waves/SKILL.md', 'zero-selection'),
    @('skills/migration/plan-waves/SKILL.md', 'canonical parent-selector semantics'),
    @('skills/migration/plan-waves/SKILL.md', 'status: approved'),
    @('skills/migration/plan-waves/SKILL.md', 'result: complete'),
    @('templates/migration/migration-plan.md', 'Master Plan Reference'),
    @('templates/migration/migration-plan.md', 'Master Plan Revision'),
    @('templates/migration/migration-plan.md', 'Parent Work Item ID'),
    @('templates/migration/migration-plan.md', 'Decomposition Decision Reference'),
    @('templates/migration/migration-plan.md', 'Design Revision')
  )
  foreach ($requirement in $staticRequirements) {
    $path = Join-Path $Root $requirement[0]
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
      $errors.Add("Missing migration delivery adapter resource: $($requirement[0])")
      continue
    }
    $text = Get-Content -Raw -Encoding utf8 $path
    Require-Token $text $requirement[1] "Migration delivery adapter resource $($requirement[0])"
  }

  $fixtureRoot = Join-Path $Root 'delivery-adapter-fixture'
  $masterPlanPath = Join-Path $fixtureRoot 'master-plan.md'
  if (-not (Test-Path -LiteralPath $masterPlanPath -PathType Leaf)) { return }

  $getFrontMatter = {
    param([string]$Text, [string]$Field)
    $match = [regex]::Match($Text, '(?m)^' + [regex]::Escape($Field) + ':[ \t]*(?<value>[^\r\n]+)[ \t]*$')
    if (-not $match.Success) { return '' }
    return $match.Groups['value'].Value.Trim()
  }
  $getTableRows = {
    param([string]$Text, [string]$Heading, [string]$Context)
    $headingPattern = '(?m)^##[ \t]+' + [regex]::Escape($Heading) + '[ \t]*\r?$'
    $headingMatch = [regex]::Match($Text, $headingPattern)
    if (-not $headingMatch.Success) {
      $errors.Add("$Context missing section: $Heading")
      return @()
    }
    $tail = $Text.Substring($headingMatch.Index + $headingMatch.Length)
    $nextHeading = [regex]::Match($tail, '(?m)^#{1,2}[ \t]+')
    $section = if ($nextHeading.Success) { $tail.Substring(0, $nextHeading.Index) } else { $tail }
    $lines = @($section -split '\r?\n' | Where-Object { $_ -match '^[ \t]*\|.*\|[ \t]*$' })
    if ($lines.Count -lt 2) {
      $errors.Add("$Context section $Heading missing Markdown table")
      return @()
    }
    $splitLine = {
      param([string]$Line)
      $body = $Line.Trim().Substring(1)
      $body = $body.Substring(0, $body.Length - 1)
      return @([regex]::Split($body, '(?<!\\)\|') | ForEach-Object { $_.Trim().Replace('\|', '|') })
    }
    $headers = @(& $splitLine $lines[0])
    $rows = [Collections.Generic.List[object]]::new()
    for ($lineIndex = 2; $lineIndex -lt $lines.Count; $lineIndex++) {
      $cells = @(& $splitLine $lines[$lineIndex])
      if ($cells.Count -ne $headers.Count) {
        $errors.Add("$Context section $Heading row has $($cells.Count) cells; expected $($headers.Count)")
        continue
      }
      $record = [ordered]@{}
      for ($cellIndex = 0; $cellIndex -lt $headers.Count; $cellIndex++) {
        $record[$headers[$cellIndex]] = $cells[$cellIndex]
      }
      $rows.Add([pscustomobject]$record)
    }
    return @($rows)
  }
  $requireColumns = {
    param([object[]]$Rows, [string[]]$Columns, [string]$Context)
    if ($Rows.Count -eq 0) { return $false }
    $properties = @($Rows[0].PSObject.Properties.Name)
    $valid = $true
    foreach ($column in $Columns) {
      if ($properties -cnotcontains $column) {
        $errors.Add("$Context missing column: $column")
        $valid = $false
      }
    }
    return $valid
  }
  $normalizeTrace = {
    param([string]$Value)
    return @($Value -split '[,;]' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' } | Sort-Object -Unique)
  }
  $sameTrace = {
    param([string]$Left, [string]$Right)
    $leftValues = @(& $normalizeTrace $Left)
    $rightValues = @(& $normalizeTrace $Right)
    return (($leftValues -join [char]0x001F) -ceq ($rightValues -join [char]0x001F))
  }
  $traceSubset = {
    param([string]$Earlier, [string]$Later)
    $laterValues = @(& $normalizeTrace $Later)
    foreach ($value in @(& $normalizeTrace $Earlier)) {
      if ($laterValues -cnotcontains $value) { return $false }
    }
    return $true
  }

  $masterText = Get-Content -Raw -Encoding utf8 $masterPlanPath
  $masterRevision = & $getFrontMatter $masterText 'revision'
  $masterStatus = & $getFrontMatter $masterText 'status'
  if ($masterStatus -cne 'approved') {
    $errors.Add('Current master plan must be approved')
  }
  $workItemRows = @(& $getTableRows $masterText 'Work Items' 'Master plan work items')
  [void](& $requireColumns $workItemRows @(
    'Work Item ID', 'Dependencies', 'Acceptance', 'Trace IDs', 'Delivery Adapter', 'Status'
  ) 'Master plan work items')
  $decompositionRows = @(& $getTableRows $masterText 'Decomposition Records' 'Master plan decompositions')
  $selectionRows = @(& $getTableRows $masterText 'Delivery Adapter Selection' 'Master plan delivery adapters')
  $selectionColumns = @(
    'Work Item ID', 'Adapter Kind', 'External ID', 'Authority', 'Authority Revision',
    'Approval Reference', 'Parent Selector', 'Acceptance', 'Trace IDs', 'Mode Constraint',
    'Design Revision', 'Parent Work Item ID', 'Decomposition Decision Reference'
  )
  if ($selectionRows.Count -gt 0 -and -not (& $requireColumns $selectionRows $selectionColumns 'Master plan delivery adapters')) { return }
  foreach ($canonicalWorkItemId in @($workItemRows | ForEach-Object { [string]($_.'Work Item ID') } | Sort-Object -Unique)) {
    $canonicalSelectionRows = @($selectionRows | Where-Object { [string]($_.'Work Item ID') -ceq $canonicalWorkItemId })
    if ($canonicalSelectionRows.Count -ne 1) {
      $errors.Add("Delivery adapter work item $canonicalWorkItemId must have exactly one Delivery Adapter Selection row; found $($canonicalSelectionRows.Count)")
    }
  }
  if ($selectionRows.Count -eq 0) { return }
  $externalSelectionGroups = @($selectionRows | Where-Object { [string]($_.'Adapter Kind') -cne 'none' } | Group-Object {
    ([string]($_.'Adapter Kind')) + ':' + ([string]($_.'External ID'))
  })
  foreach ($externalSelectionGroup in $externalSelectionGroups) {
    $selectedWorkIds = @($externalSelectionGroup.Group | ForEach-Object { [string]($_.'Work Item ID') } | Sort-Object -Unique)
    if ($selectedWorkIds.Count -gt 1) {
      $errors.Add("Delivery adapter external selector $($externalSelectionGroup.Name) is assigned to more than one Work Item ID")
    }
  }

  $allowedKinds = @('migration-unit', 'task', 'story', 'package', 'phase', 'milestone', 'none')
  $migrationPlanPath = Join-Path $fixtureRoot '08-migration-plan.md'
  $migrationRows = @()
  $migrationTraceRows = @()
  $migrationRevision = ''
  $migrationStatus = ''
  $migrationResult = ''
  if (Test-Path -LiteralPath $migrationPlanPath -PathType Leaf) {
    $migrationText = Get-Content -Raw -Encoding utf8 $migrationPlanPath
    $migrationRevision = & $getFrontMatter $migrationText 'revision'
    $migrationStatus = & $getFrontMatter $migrationText 'status'
    $migrationResult = & $getFrontMatter $migrationText 'result'
    $orderedUnitsHeading = [Text.Encoding]::UTF8.GetString(
      [Convert]::FromBase64String('Q8OhYyDEkcahbiB24buLIG1pZ3JhdGlvbiB0aGVvIHRo4bupIHThu7E=')
    )
    $migrationRows = @(& $getTableRows $migrationText $orderedUnitsHeading 'Canonical migration plan')
    [void](& $requireColumns $migrationRows @(
      'Migration Unit ID', 'Dependencies', 'Acceptance', 'Mode Constraint', 'Trace IDs',
      'Approval Reference', 'Approval Status'
    ) 'Canonical migration plan')
    $migrationTraceRows = @(& $getTableRows $migrationText 'Work Item Adapter Trace' 'Canonical migration plan adapter trace')
    [void](& $requireColumns $migrationTraceRows @(
      'Migration Unit ID', 'Work Item ID', 'Parent Work Item ID', 'Master Plan Reference',
      'Master Plan Revision', 'Decomposition Decision Reference', 'Design Revision'
    ) 'Canonical migration plan adapter trace')
  }

  $validateGenericTraceChain = {
    param([object]$Selection, [object]$WorkItem, [string]$PlanRevision)
    $genericKind = [string]($Selection.'Adapter Kind')
    $genericExternalId = [string]($Selection.'External ID')
    $genericWorkItemId = [string]($Selection.'Work Item ID')
    $stepRecords = @(
      @{ Number = '04'; File = '04-inventory.md'; StepId = '04-build-inventory' },
      @{ Number = '05'; File = '05-mapping.md'; StepId = '05-feature-mapping' },
      @{ Number = '06'; File = '06-gaps-conflicts.md'; StepId = '06-analyze-gaps-conflicts' },
      @{ Number = '07'; File = '07-technical-design.md'; StepId = '07-technical-design' },
      @{ Number = '08'; File = '08-work-item-plan.md'; StepId = '08-plan-waves' }
    )
    $previousTrace = ''
    foreach ($step in $stepRecords) {
      $stepPath = Join-Path $fixtureRoot $step.File
      if (-not (Test-Path -LiteralPath $stepPath -PathType Leaf)) {
        $errors.Add("Delivery adapter $genericKind`:$genericExternalId missing canonical work-item trace at step $($step.Number)")
        continue
      }
      $stepText = Get-Content -Raw -Encoding utf8 $stepPath
      if ((& $getFrontMatter $stepText 'step_id') -cne $step.StepId) {
        $errors.Add("Delivery adapter $genericKind`:$genericExternalId step $($step.Number) identity mismatch")
      }
      if (
        (& $getFrontMatter $stepText 'status') -cne 'approved' -or
        (& $getFrontMatter $stepText 'result') -cne 'complete'
      ) {
        $errors.Add("Delivery adapter $genericKind`:$genericExternalId step $($step.Number) must be approved and complete")
      }
      $traceRows = @(& $getTableRows $stepText 'Work Item Trace' "Delivery adapter step $($step.Number) work-item trace")
      $traceMatches = @($traceRows | Where-Object { [string]($_.'Work Item ID') -ceq $genericWorkItemId })
      if ($traceMatches.Count -ne 1) {
        $errors.Add("Delivery adapter $genericKind`:$genericExternalId missing canonical work-item trace at step $($step.Number)")
        continue
      }
      $trace = $traceMatches[0]
      foreach ($field in @('Parent Work Item ID', 'Acceptance', 'Mode Constraint', 'Decomposition Decision Reference')) {
        if ([string]($trace.$field) -cne [string]($Selection.$field)) {
          $errors.Add("Delivery adapter $genericKind`:$genericExternalId step $($step.Number) $field mismatch")
        }
      }
      if ([string]($trace.'Master Plan Reference') -cne 'master-plan.md') {
        $errors.Add("Delivery adapter $genericKind`:$genericExternalId step $($step.Number) Master Plan Reference mismatch")
      }
      if ([string]($trace.'Master Plan Revision') -cne $PlanRevision) {
        $errors.Add("Delivery adapter $genericKind`:$genericExternalId step $($step.Number) Master Plan Revision mismatch")
      }
      if ($previousTrace -ne '' -and -not (& $traceSubset $previousTrace ([string]($trace.'Trace IDs')))) {
        $errors.Add("Delivery adapter $genericKind`:$genericExternalId step $($step.Number) narrows Trace IDs")
      }
      $previousTrace = [string]($trace.'Trace IDs')
      if ($step.Number -cin @('07', '08') -and [string]($trace.'Design Revision') -cne [string]($Selection.'Design Revision')) {
        $errors.Add("Delivery adapter $genericKind`:$genericExternalId step $($step.Number) Design Revision mismatch")
      }
    }
    if ($previousTrace -ne '' -and -not (& $sameTrace $previousTrace ([string]($WorkItem.'Trace IDs')))) {
      $errors.Add("Delivery adapter $genericKind`:$genericExternalId final Trace IDs mismatch with canonical Work Item")
    }
  }

  $selectedMigrationIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  foreach ($selection in $selectionRows) {
    $workItemId = [string]$selection.'Work Item ID'
    $kind = [string]$selection.'Adapter Kind'
    $externalId = [string]$selection.'External ID'
    if ($workItemId -cnotmatch '^WORK-[A-Z0-9][A-Z0-9-]*$') {
      $errors.Add("Delivery adapter work item uses non-generic Work Item ID: $workItemId")
    }
    $workItemMatches = @($workItemRows | Where-Object { [string]($_.'Work Item ID') -ceq $workItemId })
    if ($workItemMatches.Count -ne 1) {
      $errors.Add("Delivery adapter $workItemId must resolve exactly one current master Work Item row; found $($workItemMatches.Count)")
      continue
    }
    $workItem = $workItemMatches[0]
    $expectedWorkItemAdapter = if ($kind -ceq 'none') { 'none' } else { "$kind`:$externalId" }
    if ([string]($workItem.'Delivery Adapter') -cne $expectedWorkItemAdapter) {
      $errors.Add("Delivery adapter $kind`:$externalId does not match canonical Work Item Delivery Adapter")
    }
    if ([string]($workItem.Acceptance) -cne [string]($selection.Acceptance)) {
      $errors.Add("Delivery adapter $kind`:$externalId Acceptance mismatch with canonical Work Item")
    }
    if (-not (& $sameTrace ([string]($workItem.'Trace IDs')) ([string]($selection.'Trace IDs')))) {
      $errors.Add("Delivery adapter $kind`:$externalId Trace IDs mismatch with canonical Work Item")
    }
    if ($kind -cnotin $allowedKinds) {
      $errors.Add("Delivery adapter kind is invalid for ${workItemId}: $kind")
      continue
    }
    if ($kind -ceq 'none') {
      foreach ($field in @('External ID', 'Authority', 'Authority Revision', 'Approval Reference', 'Parent Selector')) {
        if ([string]$selection.$field -cne 'not-applicable') {
          $errors.Add("Delivery adapter none requires $field = not-applicable for $workItemId")
        }
      }
      $noneParentWorkItemId = [string]($selection.'Parent Work Item ID')
      $noneDecisionReference = [string]($selection.'Decomposition Decision Reference')
      $noneIsChild = $noneParentWorkItemId -cne 'not-applicable' -or $noneDecisionReference -cne 'not-applicable'
      if ($noneIsChild) {
        if ($noneParentWorkItemId -ceq 'not-applicable' -or $noneDecisionReference -ceq 'not-applicable') {
          $errors.Add('Delivery adapter none:not-applicable has incomplete parent/decomposition identity')
        }
        $noneDecompositionMatches = @($decompositionRows | Where-Object {
          $childIds = @([string]($_.'Child Work Item IDs') -split '[,;]' | ForEach-Object { $_.Trim() })
          [string]($_.'Parent Work Item ID') -ceq $noneParentWorkItemId -and
          $childIds -ccontains $workItemId -and
          [string]($_.'Decision Reference') -ceq $noneDecisionReference -and
          [string]($_.'Master Plan Revision') -ceq $masterRevision -and
          [string]($_.'Approval Status') -ceq 'approved' -and
          -not [string]::IsNullOrWhiteSpace([string]($_.'Approval Reference')) -and
          [string]($_.'Approval Reference') -cne 'pending'
        })
        if ($noneDecompositionMatches.Count -ne 1) {
          $errors.Add("Delivery adapter none:not-applicable must resolve exactly one approved decomposition record; found $($noneDecompositionMatches.Count)")
        }
        $noneParentWorkItems = @($workItemRows | Where-Object { [string]($_.'Work Item ID') -ceq $noneParentWorkItemId })
        if ($noneParentWorkItems.Count -ne 1) {
          $errors.Add("Delivery adapter none:not-applicable must resolve exactly one canonical parent Work Item row; found $($noneParentWorkItems.Count)")
        }
        $noneParentSelections = @($selectionRows | Where-Object { [string]($_.'Work Item ID') -ceq $noneParentWorkItemId })
        if ($noneParentSelections.Count -ne 1) {
          $errors.Add("Delivery adapter none:not-applicable must resolve exactly one canonical parent adapter selection; found $($noneParentSelections.Count)")
        }
      }
      & $validateGenericTraceChain $selection $workItem $masterRevision
      continue
    }
    foreach ($field in @('External ID', 'Authority', 'Authority Revision', 'Approval Reference')) {
      $value = [string]$selection.$field
      if ([string]::IsNullOrWhiteSpace($value) -or $value -ceq 'not-applicable') {
        $errors.Add("Delivery adapter $kind requires $field for $workItemId")
      }
    }
    if ($kind -cne 'migration-unit') {
      $genericParentWorkItemId = [string]($selection.'Parent Work Item ID')
      $genericDecisionReference = [string]($selection.'Decomposition Decision Reference')
      $genericIsChild = $genericParentWorkItemId -cne 'not-applicable' -or $genericDecisionReference -cne 'not-applicable'
      if ($genericIsChild) {
        if (
          $genericParentWorkItemId -ceq 'not-applicable' -or
          $genericDecisionReference -ceq 'not-applicable'
        ) {
          $errors.Add("Delivery adapter $kind`:$externalId has incomplete parent/decomposition identity")
        }
        $genericDecompositionMatches = @($decompositionRows | Where-Object {
          $childIds = @([string]($_.'Child Work Item IDs') -split '[,;]' | ForEach-Object { $_.Trim() })
          [string]($_.'Parent Work Item ID') -ceq $genericParentWorkItemId -and
          $childIds -ccontains $workItemId -and
          [string]($_.'Decision Reference') -ceq $genericDecisionReference -and
          [string]($_.'Master Plan Revision') -ceq $masterRevision -and
          [string]($_.'Approval Status') -ceq 'approved' -and
          -not [string]::IsNullOrWhiteSpace([string]($_.'Approval Reference')) -and
          [string]($_.'Approval Reference') -cne 'pending'
        })
        if ($genericDecompositionMatches.Count -ne 1) {
          $errors.Add("Delivery adapter $kind`:$externalId must resolve exactly one approved decomposition record; found $($genericDecompositionMatches.Count)")
        }
        $genericParentWorkItems = @($workItemRows | Where-Object { [string]($_.'Work Item ID') -ceq $genericParentWorkItemId })
        if ($genericParentWorkItems.Count -ne 1) {
          $errors.Add("Delivery adapter $kind`:$externalId must resolve exactly one canonical parent Work Item row; found $($genericParentWorkItems.Count)")
        }
        $genericParentSelections = @($selectionRows | Where-Object { [string]($_.'Work Item ID') -ceq $genericParentWorkItemId })
        if ($genericParentSelections.Count -ne 1) {
          $errors.Add("Delivery adapter $kind`:$externalId must resolve exactly one canonical parent adapter selection; found $($genericParentSelections.Count)")
        }
        else {
          $genericParentSelection = $genericParentSelections[0]
          $expectedParentSelector = if ([string]($genericParentSelection.'Adapter Kind') -ceq 'none') {
            'not-applicable'
          }
          else {
            [string]($genericParentSelection.'External ID')
          }
          if ([string]($selection.'Parent Selector') -cne $expectedParentSelector) {
            $errors.Add("Delivery adapter $kind`:$externalId Parent Selector $($selection.'Parent Selector') does not match canonical parent selector $expectedParentSelector")
          }
        }
      }
      elseif ([string]($selection.'Parent Selector') -cne 'not-applicable') {
        $errors.Add("Delivery adapter $kind`:$externalId top-level selector must use Parent Selector = not-applicable")
      }
      & $validateGenericTraceChain $selection $workItem $masterRevision
      continue
    }

    if ($externalId -cnotmatch '^UNIT-[A-Z0-9][A-Z0-9-]*$') {
      $errors.Add("Migration-unit selector $externalId external ID must match canonical UNIT-* format")
    }
    if (-not $selectedMigrationIds.Add($externalId)) {
      $errors.Add("Migration-unit selector is assigned to more than one work item: $externalId")
    }
    if (-not (Test-Path -LiteralPath $migrationPlanPath -PathType Leaf)) {
      $errors.Add("Migration-unit selector $externalId has no canonical 08-migration-plan.md")
      continue
    }
    if ([string]$selection.Authority -cne '08-migration-plan.md') {
      $errors.Add("Migration-unit selector $externalId authority must be 08-migration-plan.md")
    }
    if ([string]$selection.'Authority Revision' -cne $migrationRevision) {
      $errors.Add("Migration-unit selector $externalId authority revision is stale")
    }
    if ($migrationStatus -cne 'approved' -or $migrationResult -cne 'complete') {
      $errors.Add("Migration-unit selector $externalId canonical plan is not approved and complete")
    }
    $matches = @($migrationRows | Where-Object { [string]$_.'Migration Unit ID' -ceq $externalId })
    if ($matches.Count -ne 1) {
      $errors.Add("Migration-unit selector $externalId must resolve exactly one canonical migration unit; found $($matches.Count)")
      continue
    }
    $unit = $matches[0]
    $unitTraceMatches = @($migrationTraceRows | Where-Object { [string]($_.'Migration Unit ID') -ceq $externalId })
    if ($unitTraceMatches.Count -ne 1) {
      $errors.Add("Migration-unit selector $externalId must resolve exactly one Work Item Adapter Trace row; found $($unitTraceMatches.Count)")
      continue
    }
    $unitTrace = $unitTraceMatches[0]
    foreach ($comparison in @(
      @('Work Item ID', 'Work Item ID'),
      @('Acceptance', 'Acceptance'),
      @('Mode Constraint', 'Mode Constraint'),
      @('Design Revision', 'Design Revision'),
      @('Parent Work Item ID', 'Parent Work Item ID'),
      @('Decomposition Decision Reference', 'Decomposition Decision Reference'),
      @('Approval Reference', 'Approval Reference')
    )) {
      $masterValue = if ($comparison[0] -ceq 'Acceptance') {
        [string]($workItem.Acceptance)
      }
      else {
        [string]$selection.($comparison[0])
      }
      $unitValue = if ($comparison[1] -cin @(
        'Work Item ID', 'Design Revision', 'Parent Work Item ID', 'Decomposition Decision Reference'
      )) {
        [string]$unitTrace.($comparison[1])
      }
      else {
        [string]$unit.($comparison[1])
      }
      if ($masterValue -cne $unitValue) {
        $errors.Add("Migration-unit selector $externalId $($comparison[0]) mismatch")
      }
    }
    if (-not (& $sameTrace ([string]($selection.'Trace IDs')) ([string]($unit.'Trace IDs')))) {
      $errors.Add("Migration-unit selector $externalId Trace IDs mismatch")
    }
    if (-not (& $sameTrace ([string]($workItem.'Trace IDs')) ([string]($unit.'Trace IDs')))) {
      $errors.Add("Migration-unit selector $externalId canonical Work Item Trace IDs mismatch")
    }
    if ([string]($unitTrace.'Master Plan Reference') -cne 'master-plan.md') {
      $errors.Add("Migration-unit selector $externalId Master Plan Reference mismatch")
    }
    if ([string]($unitTrace.'Master Plan Revision') -cne $masterRevision) {
      $errors.Add("Migration-unit selector $externalId Master Plan Revision mismatch")
    }
    if ([string]($unit.'Approval Status') -cne 'approved') {
      $errors.Add("Migration-unit selector $externalId canonical row is not approved")
    }
    if ([string]($unit.Dependencies) -cne [string]($workItem.Dependencies)) {
      $errors.Add("Migration-unit selector $externalId Dependencies mismatch")
    }

    $parentWorkItemId = [string]($selection.'Parent Work Item ID')
    $decisionReference = [string]($selection.'Decomposition Decision Reference')
    $isChild = $parentWorkItemId -cne 'not-applicable' -or $decisionReference -cne 'not-applicable'
    if ($isChild -and (
      $parentWorkItemId -ceq 'not-applicable' -or
      $decisionReference -ceq 'not-applicable' -or
      [string]($selection.'Parent Selector') -ceq 'not-applicable'
    )) {
      $errors.Add("Migration-unit child selector $externalId has incomplete parent/decomposition identity")
    }
    if (-not $isChild -and [string]($selection.'Parent Selector') -cne 'not-applicable') {
      $errors.Add("Migration-unit top-level selector $externalId must use Parent Selector = not-applicable")
    }
    if ($isChild -and [string]($selection.'Parent Selector') -cne 'not-applicable') {
      $approvedDecompositionMatches = @($decompositionRows | Where-Object {
        $childIds = @([string]($_.'Child Work Item IDs') -split '[,;]' | ForEach-Object { $_.Trim() })
        [string]($_.'Parent Work Item ID') -ceq $parentWorkItemId -and
        $childIds -ccontains $workItemId -and
        [string]($_.'Decision Reference') -ceq $decisionReference -and
        [string]($_.'Master Plan Revision') -ceq $masterRevision -and
        [string]($_.'Approval Status') -ceq 'approved' -and
        -not [string]::IsNullOrWhiteSpace([string]($_.'Approval Reference')) -and
        [string]($_.'Approval Reference') -cne 'pending'
      })
      if ($approvedDecompositionMatches.Count -ne 1) {
        $errors.Add("Migration-unit selector $externalId must resolve exactly one approved decomposition record; found $($approvedDecompositionMatches.Count)")
      }
      $parentWorkItemMatches = @($workItemRows | Where-Object { [string]($_.'Work Item ID') -ceq $parentWorkItemId })
      if ($parentWorkItemMatches.Count -ne 1) {
        $errors.Add("Migration-unit selector $externalId must resolve exactly one canonical parent Work Item row; found $($parentWorkItemMatches.Count)")
      }
      $parentSelector = [string]($selection.'Parent Selector')
      $parentMatches = @($migrationRows | Where-Object { [string]($_.'Migration Unit ID') -ceq $parentSelector })
      if ($parentMatches.Count -ne 1) {
        $errors.Add("Migration-unit selector $externalId parent selector must resolve exactly one canonical parent migration unit; found $($parentMatches.Count)")
      }
      else {
        $parentTraceMatches = @($migrationTraceRows | Where-Object { [string]($_.'Migration Unit ID') -ceq $parentSelector })
        if ($parentTraceMatches.Count -ne 1) {
          $errors.Add("Migration-unit selector $externalId parent selector must resolve exactly one parent Work Item Adapter Trace row; found $($parentTraceMatches.Count)")
        }
        elseif ([string]($parentTraceMatches[0].'Work Item ID') -cne $parentWorkItemId) {
          $errors.Add("Migration-unit selector $externalId Parent Work Item ID mismatch with canonical parent selector")
        }
        if ([string]($parentMatches[0].'Approval Status') -cne 'approved') {
          $errors.Add("Migration-unit selector $externalId canonical parent row is not approved")
        }
      }
    }

    $stepRecords = @(
      @{ Number = '04'; File = '04-inventory.md'; StepId = '04-build-inventory' },
      @{ Number = '05'; File = '05-mapping.md'; StepId = '05-feature-mapping' },
      @{ Number = '06'; File = '06-gaps-conflicts.md'; StepId = '06-analyze-gaps-conflicts' },
      @{ Number = '07'; File = '07-technical-design.md'; StepId = '07-technical-design' }
    )
    $previousTrace = ''
    foreach ($step in $stepRecords) {
      $stepPath = Join-Path $fixtureRoot $step.File
      if (-not (Test-Path -LiteralPath $stepPath -PathType Leaf)) {
        $label = if ($isChild) { 'canonical child trace' } else { 'canonical work-item trace' }
        $errors.Add("Migration-unit selector $externalId missing $label at step $($step.Number)")
        continue
      }
      $stepText = Get-Content -Raw -Encoding utf8 $stepPath
      if ((& $getFrontMatter $stepText 'step_id') -cne $step.StepId) {
        $errors.Add("Migration-unit selector $externalId step $($step.Number) identity mismatch")
      }
      if (
        (& $getFrontMatter $stepText 'status') -cne 'approved' -or
        (& $getFrontMatter $stepText 'result') -cne 'complete'
      ) {
        $errors.Add("Migration-unit selector $externalId step $($step.Number) must be approved and complete")
      }
      $traceRows = @(& $getTableRows $stepText 'Work Item Trace' "Migration step $($step.Number) work-item trace")
      $traceMatches = @($traceRows | Where-Object { [string]($_.'Work Item ID') -ceq $workItemId })
      if ($traceMatches.Count -ne 1) {
        $label = if ($isChild) { 'canonical child trace' } else { 'canonical work-item trace' }
        $errors.Add("Migration-unit selector $externalId missing $label at step $($step.Number)")
        continue
      }
      $trace = $traceMatches[0]
      foreach ($field in @(
        'Parent Work Item ID', 'Acceptance', 'Mode Constraint',
        'Decomposition Decision Reference'
      )) {
        if ([string]$trace.$field -cne [string]$selection.$field) {
          $errors.Add("Migration-unit selector $externalId step $($step.Number) $field mismatch")
        }
      }
      if ([string]($trace.'Master Plan Reference') -cne 'master-plan.md') {
        $errors.Add("Migration-unit selector $externalId step $($step.Number) Master Plan Reference mismatch")
      }
      if ([string]($trace.'Master Plan Revision') -cne $masterRevision) {
        $errors.Add("Migration-unit selector $externalId step $($step.Number) Master Plan Revision mismatch")
      }
      if ($previousTrace -ne '' -and -not (& $traceSubset $previousTrace ([string]($trace.'Trace IDs')))) {
        $errors.Add("Migration-unit selector $externalId step $($step.Number) narrows Trace IDs")
      }
      $previousTrace = [string]($trace.'Trace IDs')
      if ($step.Number -ceq '07' -and [string]($trace.'Design Revision') -cne [string]($selection.'Design Revision')) {
        $errors.Add("Migration-unit selector $externalId step 07 Design Revision mismatch")
      }
    }
    if ($previousTrace -ne '' -and -not (& $traceSubset $previousTrace ([string]($unit.'Trace IDs')))) {
      $errors.Add("Migration-unit selector $externalId step 08 narrows Trace IDs")
    }
  }
}

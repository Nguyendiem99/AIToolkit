function Test-ScopeArtifacts([string]$Root, [string]$ContractText) {
  $contractPath = Join-Path $Root 'contracts/migration-scope-orchestration.md'
  if (-not (Test-Path -LiteralPath $contractPath -PathType Leaf)) {
    $errors.Add('Missing migration scope orchestration contract resource')
    return
  }
  if ([string]::IsNullOrWhiteSpace($ContractText)) {
    $errors.Add('Migration scope orchestration contract must not be empty')
    return
  }

  Test-MarkdownTableExactColumns $ContractText 'Requested Scope' @('Kind', 'ID', 'Statement', 'Source', 'Resolution Evidence') 'Migration scope orchestration contract'
  Test-MarkdownTableExactColumns $ContractText 'Work Item' @('Work Item ID', 'Title', 'Required', 'Dependencies', 'Plan Order', 'Acceptance', 'Trace IDs', 'Delivery Adapter', 'Status', 'Latest Attempt', 'Terminal Evidence', 'Approval Reference') 'Migration scope orchestration contract'
  Test-MarkdownTableExactColumns $ContractText 'Attempt' @('Attempt ID', 'Work Item ID', 'Plan Revision', 'Status', 'Artifact Reference') 'Migration scope orchestration contract'
  Test-MarkdownTableExactColumns $ContractText 'Revision' @('Artifact ID', 'Revision', 'Supersedes', 'Change Summary', 'Affected Work Items', 'Approval Reference') 'Migration scope orchestration contract'
  @('Requested scope kinds: `project | module | feature | task | explicit-item | unresolved`.', 'Scope states: `planned | scope-in-progress | scope-blocked | scope-complete | scope-cancelled-approved`.', 'Work-item states: `proposed | pending | ready | in-progress | blocked | complete | cancelled-approved | not-applicable-approved`.', 'Delivery adapter kinds: `migration-unit | task | story | package | phase | milestone | none`.', 'Selection order: dependency depth ascending -> Plan Order ascending -> ordinal Work Item ID ascending.', 'Terminal-success states: `complete | cancelled-approved | not-applicable-approved`.', 'Resume reconciliation applies a missing terminal transition from valid evidence before selecting another work item.', 'Approved revisions are immutable and form one linear, non-forked, non-cyclic chain.', 'Decomposition creates a new master-plan revision and canonical child selectors must be approved before adapter assignment.', 'Scope-completion formula: every required work item is terminal-success AND no blocker remains AND the dependency graph is valid AND completed-item architecture conformance is PASS AND completed-item selector/schema is PASS AND the terminal scope report enumerates all evidence.') | ForEach-Object { Require-Token $ContractText $_ 'Migration scope orchestration contract' }

  $addError = { param([string]$Message) $errors.Add($Message) }
  $getFrontMatter = {
    param([string]$Text, [string]$Label)
    $result = [ordered]@{}
    if ($Text -notmatch '(?s)\A---\r?\n(?<body>.*?)\r?\n---(?:\r?\n|\z)') { & $addError "$Label missing front matter"; return $null }
    foreach ($line in @($Matches['body'] -split '\r?\n')) {
      if ($line -notmatch '^(?<key>[a-z_]+):[ \t]*(?<value>.*)$') { & $addError "$Label has invalid front matter line: $line"; continue }
      $key = $Matches['key']; $value = $Matches['value'].Trim()
      if ($result.Contains($key)) { & $addError "$Label duplicate front matter field: $key"; continue }
      if ([string]::IsNullOrWhiteSpace($value)) { & $addError "$Label has blank front matter field: $key"; continue }
      $result[$key] = $value
    }
    return $result
  }
  $getSection = {
    param([string]$Text, [string]$Section)
    $escaped = [regex]::Escape($Section)
    $matches = [regex]::Matches($Text, "(?m)^## $escaped[ \t]*$")
    if ($matches.Count -eq 0) { return $null }
    if ($matches.Count -ne 1) { & $addError "$script:scopeArtifactLabel duplicate required section: $Section"; return $null }
    $start = $matches[0].Index + $matches[0].Length
    $next = [regex]::Match($Text.Substring($start), '(?m)^## ')
    $length = if ($next.Success) { $next.Index } else { $Text.Length - $start }
    return $Text.Substring($start, $length)
  }
  $getRows = {
    param([string]$Text, [string]$Section, [string[]]$Columns)
    $sectionText = & $getSection $Text $Section
    if ($null -eq $sectionText) { & $addError "$script:scopeArtifactLabel missing required section: $Section"; return @() }
    $lines = @($sectionText -split '\r?\n'); $headerIndex = -1
    for ($index = 0; $index -lt $lines.Count; $index++) { if ($lines[$index] -match '^\|.*\|[ \t]*$') { $headerIndex = $index; break } }
    if ($headerIndex -lt 0 -or $headerIndex + 1 -ge $lines.Count) { & $addError "$script:scopeArtifactLabel missing table: $Section"; return @() }
    $header = @($lines[$headerIndex].Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
    if (($header -join '|') -cne ($Columns -join '|')) { & $addError "$script:scopeArtifactLabel $Section table columns must be exactly: $($Columns -join ' | ')"; return @() }
    if ($lines[$headerIndex + 1] -notmatch '^\|(?:[ \t]*:?-{3,}:?[ \t]*\|)+[ \t]*$') { & $addError "$script:scopeArtifactLabel missing table delimiter: $Section"; return @() }
    $rows = [Collections.Generic.List[object]]::new()
    for ($index = $headerIndex + 2; $index -lt $lines.Count; $index++) {
      if ($lines[$index] -notmatch '^\|.*\|[ \t]*$') { break }
      $cells = @($lines[$index].Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
      if ($cells.Count -ne $Columns.Count) { & $addError "$script:scopeArtifactLabel $Section row $($rows.Count + 1) has wrong cell count"; continue }
      for ($cellIndex = 0; $cellIndex -lt $cells.Count; $cellIndex++) { if ([string]::IsNullOrWhiteSpace($cells[$cellIndex])) { & $addError "$script:scopeArtifactLabel $Section row $($rows.Count + 1) has blank cell: $($Columns[$cellIndex])" } }
      $rows.Add([pscustomobject]@{ Cells = $cells })
    }
    if ($rows.Count -eq 0) { & $addError "$script:scopeArtifactLabel $Section must contain at least one row" }
    return @($rows)
  }
  $validateArtifact = {
    param([string]$Text, [string]$Label, [string]$ArtifactType, [string[]]$Fields, [string[]]$Sections)
    $script:scopeArtifactLabel = $Label; $frontMatter = & $getFrontMatter $Text $Label
    if ($null -eq $frontMatter) { return $null }
    foreach ($field in $Fields) { if (-not $frontMatter.Contains($field)) { & $addError "$Label missing front matter field: $field" } }
    if ((@($frontMatter.Keys) -join '|') -cne ($Fields -join '|')) { & $addError "$Label front matter fields must be exact" }
    if ($frontMatter.Contains('artifact_type') -and $frontMatter['artifact_type'] -cne $ArtifactType) { & $addError "$Label artifact_type must be $ArtifactType" }
    foreach ($section in $Sections) {
      [void](& $getSection $Text $section)
      if (@([regex]::Matches($Text, "(?m)^## $([regex]::Escape($section))[ \t]*$")).Count -eq 0) { & $addError "$Label missing required section: $section" }
    }
    $actualSections = @([regex]::Matches($Text, '(?m)^## (?<name>.+?)[ \t]*$') | ForEach-Object { $_.Groups['name'].Value.Trim() })
    if (($actualSections -join '|') -cne ($Sections -join '|')) { & $addError "$Label sections must be exact" }
    return $frontMatter
  }

  $specPath = Join-Path $Root 'templates/migration/master-spec.md'; $planPath = Join-Path $Root 'templates/migration/master-plan.md'
  if (-not (Test-Path -LiteralPath $specPath -PathType Leaf)) { & $addError 'Missing master spec template' }
  if (-not (Test-Path -LiteralPath $planPath -PathType Leaf)) { & $addError 'Missing master plan template' }
  if (-not (Test-Path -LiteralPath $specPath -PathType Leaf) -or -not (Test-Path -LiteralPath $planPath -PathType Leaf)) { return }
  $specText = Get-Content -Raw -Encoding utf8 $specPath; $planText = Get-Content -Raw -Encoding utf8 $planPath
  $specFields = @('artifact_type', 'master_spec_id', 'revision', 'status', 'result', 'approval_source', 'requested_scope_kind', 'requested_scope_id', 'produced_at', 'supersedes')
  $planFields = @('artifact_type', 'master_plan_id', 'master_spec_id', 'master_spec_revision', 'revision', 'status', 'scope_status', 'execution_policy', 'max_concurrency', 'produced_at', 'supersedes')
  $specSections = @('Problem and Intended Outcome', 'Requested Scope Boundary', 'Actors and Journeys', 'Behaviors, States and Failure Paths', 'Constraints and Project Rules', 'Architecture and Conformance Applicability', 'Measurable Success Criteria', 'Explicitly Out-of-Scope Items', 'Assumptions and Unknowns', 'Trace/Evidence Index', 'Approval Record', 'Revision History')
  $planSections = @('Requested Scope', 'Work Items', 'Dependency Graph', 'Attempt History', 'State Transition Log', 'Scope Completion Calculation', 'Evidence', 'Unknowns', 'Approval Record', 'Revision History')
  $spec = & $validateArtifact $specText 'master spec' 'migration-master-spec' $specFields $specSections
  $plan = & $validateArtifact $planText 'master plan' 'migration-master-plan' $planFields $planSections
  if ($null -eq $spec -or $null -eq $plan) { return }

  $placeholder = { param([string]$Value) $Value -match '<[^>]+>' -or $Value -match '^(REQ|SC|TRACE|UNK)-###$' }
  if (-not (& $placeholder $spec['master_spec_id']) -and $spec['master_spec_id'] -notmatch '^SPEC-[A-Z0-9]+-[0-9]{3}$') { & $addError "master spec invalid master_spec_id: $($spec['master_spec_id'])" }
  if (-not (& $placeholder $plan['master_plan_id']) -and $plan['master_plan_id'] -notmatch '^PLAN-[A-Z0-9]+-[0-9]{3}$') { & $addError "master plan invalid master_plan_id: $($plan['master_plan_id'])" }
  if ($spec['requested_scope_kind'] -cnotin @('project', 'module', 'feature', 'task', 'explicit-item', 'unresolved') -and -not (& $placeholder $spec['requested_scope_kind'])) { & $addError 'master spec requested_scope_kind is invalid' }
  foreach ($artifact in @([pscustomobject]@{ Value = $spec; Label = 'master spec'; HasResult = $true; HasApproval = $true }, [pscustomobject]@{ Value = $plan; Label = 'master plan'; HasResult = $false; HasApproval = $false })) {
    if ($artifact.Value['status'] -cnotin @('draft', 'approved') -and -not (& $placeholder $artifact.Value['status'])) { & $addError "$($artifact.Label) status is invalid" }
    if ($artifact.Value['produced_at'] -notmatch '^\d{4}-\d{2}-\d{2}$' -and -not (& $placeholder $artifact.Value['produced_at'])) { & $addError "$($artifact.Label) produced_at must be yyyy-mm-dd" }
    if ($artifact.HasResult -and $artifact.Value['result'] -cnotin @('complete', 'partial', 'blocked') -and -not (& $placeholder $artifact.Value['result'])) { & $addError 'master spec result is invalid' }
    if ($artifact.HasApproval -and $artifact.Value['approval_source'] -cnotin @('human', 'auto', 'auto-waive') -and -not (& $placeholder $artifact.Value['approval_source'])) { & $addError 'master spec approval_source is invalid' }
  }
  if ($spec['result'] -ceq 'partial') { & $addError 'master spec result partial is not valid for master artifacts' }
  if ($spec['status'] -ceq 'approved' -and $spec['result'] -cne 'complete') { & $addError 'master spec approved status must use result complete' }
  if ($spec['approval_source'] -ceq 'auto-waive') { & $addError 'master spec approval_source auto-waive is not valid for master artifacts' }
  $validateRevision = {
    param($FrontMatter, [string]$IdField, [string]$Label)
    $revision = $FrontMatter['revision']
    if (-not (& $placeholder $revision) -and $revision -notmatch '^[1-9][0-9]*$') { & $addError "$Label revision must be a positive integer"; return }
    if ($revision -eq '1' -and $FrontMatter['supersedes'] -cne 'not-applicable') { & $addError "$Label revision 1 must supersede not-applicable" }
    if ($revision -match '^[2-9][0-9]*$') { $expected = "$($FrontMatter[$IdField])@$([int]$revision - 1)"; if ($FrontMatter['supersedes'] -cne $expected) { & $addError "$Label supersedes must be $expected" } }
  }
  & $validateRevision $spec 'master_spec_id' 'master spec'; & $validateRevision $plan 'master_plan_id' 'master plan'
  if ($plan['master_spec_id'] -cne $spec['master_spec_id']) { & $addError 'master plan master_spec_id must match master spec' }
  if ($plan['master_spec_revision'] -cne $spec['revision']) { & $addError 'master plan master_spec_revision must match master spec revision' }
  if ($plan['execution_policy'] -cne 'dependency-ready') { & $addError 'master plan execution_policy must be dependency-ready' }
  if ($plan['max_concurrency'] -notmatch '^[1-9][0-9]*$' -or [int]$plan['max_concurrency'] -ne 1) { & $addError 'master plan max_concurrency must be 1' }
  if ($plan['scope_status'] -cnotin @('planned', 'scope-in-progress', 'scope-blocked', 'scope-complete', 'scope-cancelled-approved')) { & $addError 'master plan scope_status is invalid' }

  $script:scopeArtifactLabel = 'master spec'
  $specScopeRows = @(& $getRows $specText 'Requested Scope Boundary' @('Kind', 'ID', 'Statement', 'Source', 'Resolution Evidence'))
  $successRows = @(& $getRows $specText 'Measurable Success Criteria' @('Success Criterion ID', 'Requirement IDs', 'Measurable Outcome'))
  $requirementRows = @(& $getRows $specText 'Problem and Intended Outcome' @('Requirement ID', 'Statement', 'Source', 'Acceptance'))
  [void](& $getRows $specText 'Trace/Evidence Index' @('Trace ID', 'Type', 'Reference', 'Notes'))
  [void](& $getRows $specText 'Approval Record' @('Approval Source', 'Approval Reference', 'Status', 'Approved At'))
  $specRevisionRows = @(& $getRows $specText 'Revision History' @('Artifact ID', 'Revision', 'Supersedes', 'Change Summary', 'Affected Work Items', 'Approval Reference'))
  $script:scopeArtifactLabel = 'master plan'
  $planScopeRows = @(& $getRows $planText 'Requested Scope' @('Kind', 'ID', 'Statement', 'Source', 'Resolution Evidence'))
  $workRows = @(& $getRows $planText 'Work Items' @('Work Item ID', 'Title', 'Required', 'Dependencies', 'Plan Order', 'Acceptance', 'Trace IDs', 'Delivery Adapter', 'Status', 'Latest Attempt', 'Terminal Evidence', 'Approval Reference'))
  $dependencyRows = @(& $getRows $planText 'Dependency Graph' @('Work Item ID', 'Dependency Work Item ID', 'Relationship', 'Evidence'))
  $attemptRows = @(& $getRows $planText 'Attempt History' @('Attempt ID', 'Work Item ID', 'Plan Revision', 'Status', 'Artifact Reference'))
  $transitionRows = @(& $getRows $planText 'State Transition Log' @('Work Item ID', 'From State', 'To State', 'Evidence or Decision', 'Plan Revision'))
  [void](& $getRows $planText 'Scope Completion Calculation' @('Required Work Items', 'Terminal-Success Items', 'Blockers', 'Dependency Graph', 'Architecture Conformance', 'Selector/Schema', 'Scope Status'))
  [void](& $getRows $planText 'Evidence' @('Evidence', 'Location', 'Notes'))
  $planUnknownRows = @(& $getRows $planText 'Unknowns' @('ID', 'Unknown', 'Impact', 'Disposition'))
  [void](& $getRows $planText 'Approval Record' @('Approval Reference', 'Status', 'Approved At'))
  $planRevisionRows = @(& $getRows $planText 'Revision History' @('Artifact ID', 'Revision', 'Supersedes', 'Change Summary', 'Affected Work Items', 'Approval Reference'))
  $workIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal); $planOrders = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  $workById = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
  foreach ($row in $workRows) {
    $cells = $row.Cells; $workItemId = $cells[0]; $planOrder = $cells[4]
    if (-not (& $placeholder $workItemId) -and $workItemId -notmatch '^WORK-[A-Z0-9]+-[A-Z0-9-]+$') { & $addError "master plan invalid Work Item ID: $workItemId" }
    if (-not $workIds.Add($workItemId)) { & $addError "master plan duplicate Work Item ID: $workItemId" } else { $workById.Add($workItemId, $row) }
    if ($cells[2] -cnotin @('yes', 'no') -and -not (& $placeholder $cells[2])) { & $addError "master plan invalid Required value: $($cells[2])" }
    if ($cells[8] -cnotin @('proposed', 'pending', 'ready', 'in-progress', 'blocked', 'complete', 'cancelled-approved', 'not-applicable-approved') -and -not (& $placeholder $cells[8])) { & $addError "master plan invalid Work Item Status: $($cells[8])" }
    if (-not (& $placeholder $planOrder) -and $planOrder -notmatch '^[1-9][0-9]*$') { & $addError "master plan Plan Order must be a positive integer: $planOrder" }
    if (-not $planOrders.Add($planOrder)) { & $addError "master plan duplicate Plan Order: $planOrder" }
    foreach ($dependency in @($cells[3].Split(',') | ForEach-Object { $_.Trim() })) { if ($dependency -ne 'none' -and $dependency -notmatch '^WORK-[A-Z0-9]+-[A-Z0-9-]+$') { & $addError "master plan invalid dependency reference: $dependency" } }
  }
  foreach ($row in $workRows) {
    foreach ($dependency in @($row.Cells[3].Split(',') | ForEach-Object { $_.Trim() })) {
      if ($dependency -ne 'none' -and -not $workIds.Contains($dependency)) { & $addError "master plan dependency does not reference a Work Item ID: $dependency" }
    }
  }
  $requirementIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  foreach ($row in $requirementRows) {
    $requirementId = $row.Cells[0]
    if ($requirementId -notmatch '^REQ-[0-9]{3}$' -and -not (& $placeholder $requirementId)) { & $addError "master spec invalid Requirement ID: $requirementId" }
    if (-not $requirementIds.Add($requirementId)) { & $addError "master spec duplicate Requirement ID: $requirementId" }
  }
  $successIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  foreach ($row in $successRows) {
    $successId = $row.Cells[0]
    if ($successId -notmatch '^SC-[0-9]{3}$' -and -not (& $placeholder $successId)) { & $addError "master spec invalid Success Criterion ID: $successId" }
    if (-not $successIds.Add($successId)) { & $addError "master spec duplicate Success Criterion ID: $successId" }
    foreach ($requirementId in @($row.Cells[1].Split('[,;]') | ForEach-Object { $_.Trim() })) {
      if (-not $requirementIds.Contains($requirementId)) { & $addError "master spec success criterion $successId references unknown Requirement ID: $requirementId" }
    }
  }
  if ($specScopeRows.Count -ne 1) { & $addError 'master spec Requested Scope Boundary must contain exactly one row' }
  if ($planScopeRows.Count -ne 1) { & $addError 'master plan Requested Scope must contain exactly one row' }
  if ($specScopeRows.Count -eq 1) {
    $scopeRow = $specScopeRows[0]
    if (-not (& $placeholder $scopeRow.Cells[0]) -and -not (& $placeholder $spec['requested_scope_kind']) -and $scopeRow.Cells[0] -cne $spec['requested_scope_kind']) { & $addError 'master spec Requested Scope Boundary Kind must match requested_scope_kind' }
    if (-not (& $placeholder $scopeRow.Cells[1]) -and -not (& $placeholder $spec['requested_scope_id']) -and $scopeRow.Cells[1] -cne $spec['requested_scope_id']) { & $addError 'master spec Requested Scope Boundary ID must match requested_scope_id' }
  }
  if ($specScopeRows.Count -eq 1 -and $planScopeRows.Count -eq 1) {
    $scopeRow = $planScopeRows[0]
    $scopeFields = @(@(0, 'Kind'), @(1, 'ID'), @(2, 'Statement'), @(3, 'Source'), @(4, 'Resolution Evidence'))
    foreach ($field in $scopeFields) {
      $specValue = $specScopeRows[0].Cells[$field[0]]
      if (-not (& $placeholder $scopeRow.Cells[$field[0]]) -and -not (& $placeholder $specValue) -and $scopeRow.Cells[$field[0]] -cne $specValue) { & $addError "master plan Requested Scope $($field[1]) must match master spec" }
    }
  }
  foreach ($row in $dependencyRows) {
    if (-not $workIds.Contains($row.Cells[0])) { & $addError "master plan Dependency Graph references unknown Work Item ID: $($row.Cells[0])" }
    if ($row.Cells[1] -ne 'none' -and -not $workIds.Contains($row.Cells[1])) { & $addError "master plan Dependency Graph references unknown dependency Work Item ID: $($row.Cells[1])" }
  }
  foreach ($workRow in $workRows) {
    $workItemId = $workRow.Cells[0]
    $expectedDependencies = @($workRow.Cells[3].Split(',') | ForEach-Object { $_.Trim() } | Sort-Object)
    $graphDependencies = @($dependencyRows | Where-Object { $_.Cells[0] -ceq $workItemId } | ForEach-Object { $_.Cells[1] } | Sort-Object)
    if (($expectedDependencies -join '|') -cne ($graphDependencies -join '|')) { & $addError "master plan Dependency Graph must match Work Items dependencies for $workItemId" }
  }
  $attemptIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  $attemptArtifactReferences = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  $attemptsByWork = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
  $attemptIndex = 0
  foreach ($row in $attemptRows) {
    $attemptIndex++
    $attemptId = $row.Cells[0]; $workItemId = $row.Cells[1]; $attemptStatus = $row.Cells[3]; $artifactReference = $row.Cells[4]
    if (-not $attemptIds.Add($attemptId)) { & $addError "master plan duplicate Attempt ID: $attemptId" }
    $genericAttemptPattern = '^ATTEMPT-WORK-[A-Z0-9]+-[A-Z0-9-]+-(?:0[1-9]|[1-9][0-9])$'
    $canonicalAttemptPattern = '^ATTEMPT-' + [regex]::Escape($workItemId) + '-(?<sequence>0[1-9]|[1-9][0-9])$'
    $canonicalAttempt = [regex]::Match($attemptId, $canonicalAttemptPattern)
    if (-not (& $placeholder $attemptId) -and $attemptId -notmatch $genericAttemptPattern) {
      & $addError "master plan invalid Attempt ID: $attemptId"
    } elseif (-not (& $placeholder $attemptId) -and -not $canonicalAttempt.Success) {
      & $addError "master plan Attempt ID $attemptId must correlate to Work Item ID $workItemId"
    }
    if (-not $workIds.Contains($workItemId)) { & $addError "master plan Attempt History references unknown Work Item ID: $workItemId" }
    if ($row.Cells[2] -cne $plan['revision']) { & $addError 'master plan Attempt History Plan Revision must match master plan revision' }
    if ($attemptStatus -cnotin @('in-progress', 'complete', 'blocked')) { & $addError "master plan Attempt History status is invalid: $attemptStatus" }
    if (-not (& $placeholder $artifactReference) -and $artifactReference -cin @('none', 'pending', 'not-applicable')) { & $addError "master plan Attempt History Artifact Reference must be exact: $artifactReference" }
    if (-not (& $placeholder $artifactReference) -and $artifactReference -cnotin @('none', 'pending', 'not-applicable') -and -not $attemptArtifactReferences.Add($artifactReference)) { & $addError "master plan duplicate Attempt History Artifact Reference: $artifactReference" }
    if ($canonicalAttempt.Success -and $workIds.Contains($workItemId)) {
      if (-not $attemptsByWork.ContainsKey($workItemId)) { $attemptsByWork.Add($workItemId, [Collections.Generic.List[object]]::new()) }
      $attemptsByWork[$workItemId].Add([pscustomobject]@{ Row = $row; Sequence = [int]$canonicalAttempt.Groups['sequence'].Value; Index = $attemptIndex })
    }
  }
  foreach ($workItemId in $workIds) {
    $workRow = $workById[$workItemId]; $workStatus = $workRow.Cells[8]; $latestAttemptId = $workRow.Cells[9]; $terminalEvidence = $workRow.Cells[10]
    if (& $placeholder $workItemId) { continue }
    if (-not $attemptsByWork.ContainsKey($workItemId)) {
      if ($latestAttemptId -cne 'none' -and -not (& $placeholder $latestAttemptId)) { & $addError "master plan Work Item $workItemId Latest Attempt must be none when no attempt exists" }
      if ($workStatus -cin @('in-progress', 'blocked', 'complete')) { & $addError "master plan Work Item $workItemId Status $workStatus requires an attempt" }
      continue
    }
    $latestAttempt = @($attemptsByWork[$workItemId] | Sort-Object -Property Sequence, Index)[-1].Row
    if ($latestAttemptId -cne $latestAttempt.Cells[0]) { & $addError "master plan Work Item $workItemId Latest Attempt must be $($latestAttempt.Cells[0])" }
    $latestAttemptStatus = $latestAttempt.Cells[3]
    $allowedWorkStatuses = if ($latestAttemptStatus -eq 'blocked') { @('blocked', 'cancelled-approved') } else { @($latestAttemptStatus) }
    if ($workStatus -cnotin $allowedWorkStatuses) { & $addError "master plan Work Item $workItemId Status must match latest attempt status $latestAttemptStatus" }
    if ($latestAttemptStatus -eq 'in-progress') {
      if ($terminalEvidence -cne 'none') { & $addError "master plan Work Item $workItemId Terminal Evidence must be none for in-progress attempt" }
    } elseif ($terminalEvidence -cne $latestAttempt.Cells[4]) {
      & $addError "master plan Work Item $workItemId Terminal Evidence must match latest attempt Artifact Reference: $($latestAttempt.Cells[4])"
    }
  }
  $workItemStates = @('proposed', 'pending', 'ready', 'in-progress', 'blocked', 'complete', 'cancelled-approved', 'not-applicable-approved')
  $legalTransitions = @('ready->in-progress', 'in-progress->complete', 'in-progress->blocked', 'pending->cancelled-approved', 'ready->cancelled-approved', 'blocked->cancelled-approved', 'pending->not-applicable-approved', 'ready->not-applicable-approved')
  $latestTransitionState = [Collections.Generic.Dictionary[string, string]]::new([StringComparer]::Ordinal)
  $transitionsByWork = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
  $transitionIndex = 0
  foreach ($row in $transitionRows) {
    $transitionIndex++
    $workItemId = $row.Cells[0]; $fromState = $row.Cells[1]; $toState = $row.Cells[2]
    if (-not $workIds.Contains($workItemId)) { & $addError "master plan State Transition Log references unknown Work Item ID: $workItemId" }
    if ($fromState -cnotin $workItemStates) { & $addError "master plan State Transition Log From State is invalid: $fromState" }
    if ($toState -cnotin $workItemStates) { & $addError "master plan State Transition Log To State is invalid: $toState" }
    if ($fromState -cin $workItemStates -and $toState -cin $workItemStates -and "$fromState->$toState" -cnotin $legalTransitions) { & $addError "master plan illegal State Transition: $fromState -> $toState" }
    if ($latestTransitionState.ContainsKey($workItemId) -and $fromState -cne $latestTransitionState[$workItemId]) { & $addError "master plan State Transition Log is not ordered for $workItemId`: expected From State $($latestTransitionState[$workItemId]), got $fromState" }
    $latestTransitionState[$workItemId] = $toState
    if ($row.Cells[4] -cne $plan['revision']) { & $addError 'master plan State Transition Log Plan Revision must match master plan revision' }
    if (-not $transitionsByWork.ContainsKey($workItemId)) { $transitionsByWork.Add($workItemId, [Collections.Generic.List[object]]::new()) }
    $transitionsByWork[$workItemId].Add([pscustomobject]@{ Row = $row; Index = $transitionIndex })
  }
  foreach ($workItemId in $latestTransitionState.Keys) {
    if ($workById.ContainsKey($workItemId) -and $workById[$workItemId].Cells[8] -cne $latestTransitionState[$workItemId]) { & $addError "master plan Work Item $workItemId Status must match latest transition To State: $($latestTransitionState[$workItemId])" }
  }
  foreach ($workItemId in $attemptsByWork.Keys) {
    $workTransitions = if ($transitionsByWork.ContainsKey($workItemId)) { @($transitionsByWork[$workItemId]) } else { @() }
    foreach ($attempt in @($attemptsByWork[$workItemId] | Sort-Object -Property Sequence, Index)) {
      $attemptRow = $attempt.Row
      $attemptId = $attemptRow.Cells[0]; $attemptRevision = $attemptRow.Cells[2]; $attemptStatus = $attemptRow.Cells[3]; $artifactReference = $attemptRow.Cells[4]
      $initialTransitions = @($workTransitions | Where-Object {
        $_.Row.Cells[1] -ceq 'ready' -and $_.Row.Cells[2] -ceq 'in-progress' -and
        $_.Row.Cells[3] -ceq $attemptId -and $_.Row.Cells[4] -ceq $attemptRevision
      })
      if ($initialTransitions.Count -ne 1) {
        & $addError "master plan Attempt $attemptId must start with ready -> in-progress"
        continue
      }
      if ($attemptStatus -cin @('complete', 'blocked')) {
        $initialIndex = $initialTransitions[0].Index
        $terminalTransitions = @($workTransitions | Where-Object {
          $_.Index -gt $initialIndex -and $_.Row.Cells[1] -ceq 'in-progress' -and
          $_.Row.Cells[2] -ceq $attemptStatus -and $_.Row.Cells[4] -ceq $attemptRevision
        })
        if ($terminalTransitions.Count -ne 1) {
          & $addError "master plan Attempt $attemptId must finish with in-progress -> $attemptStatus"
        } elseif ($terminalTransitions[0].Row.Cells[3] -cne $artifactReference) {
          & $addError "master plan Attempt $attemptId terminal transition evidence must match Artifact Reference: $artifactReference"
        }
      }
    }
  }
  $validateAffectedWorkItems = {
    param($Row, [string]$Label)
    $affectedWorkItems = @($Row.Cells[4].Split('[,;]') | ForEach-Object { $_.Trim() })
    if ($affectedWorkItems -ccontains 'not-applicable') { & $addError "$Label Revision History Affected Work Items must use none instead of not-applicable" }
    if ($affectedWorkItems -ccontains 'none') {
      if ($affectedWorkItems.Count -ne 1) { & $addError "$Label Revision History Affected Work Items must use none alone" }
      return
    }
    foreach ($workItemId in $affectedWorkItems) {
      if ($workItemId -cne 'not-applicable' -and -not $workIds.Contains($workItemId)) { & $addError "$Label Revision History references unknown Work Item ID: $workItemId" }
    }
  }
  foreach ($row in $specRevisionRows) {
    if ($row.Cells[0] -cne $spec['master_spec_id']) { & $addError 'master spec Revision History Artifact ID must match master_spec_id' }
    if ($row.Cells[1] -cne $spec['revision']) { & $addError 'master spec Revision History Revision must match revision' }
    if ($row.Cells[2] -cne $spec['supersedes']) { & $addError 'master spec Revision History Supersedes must match supersedes' }
    & $validateAffectedWorkItems $row 'master spec'
  }
  foreach ($row in $planRevisionRows) {
    if ($row.Cells[0] -cne $plan['master_plan_id']) { & $addError 'master plan Revision History Artifact ID must match master_plan_id' }
    if ($row.Cells[1] -cne $plan['revision']) { & $addError 'master plan Revision History Revision must match revision' }
    if ($row.Cells[2] -cne $plan['supersedes']) { & $addError 'master plan Revision History Supersedes must match supersedes' }
    & $validateAffectedWorkItems $row 'master plan'
  }
  $unknownRows = @(& $getRows $specText 'Assumptions and Unknowns' @('ID', 'Assumption or Unknown', 'Impact', 'Disposition'))
  foreach ($row in $unknownRows) {
    if (-not (& $placeholder $row.Cells[2]) -and $row.Cells[2] -match '(?i)(scope|architecture|acceptance)' -and $spec['status'] -cne 'draft') { & $addError 'master spec scope/architecture/acceptance unknown requires status draft' }
  }
  foreach ($row in $planUnknownRows) {
    if (-not (& $placeholder $row.Cells[2]) -and $row.Cells[2] -match '(?i)(scope|architecture|acceptance)' -and $plan['status'] -cne 'draft') { & $addError 'master plan scope/architecture/acceptance unknown requires status draft' }
  }
}

$ErrorActionPreference = 'Stop'

$toolkitRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$contractText = Get-Content -Raw -Encoding utf8 (Join-Path $toolkitRoot 'contracts/migration-scope-orchestration.md')
$validatorPath = Join-Path $toolkitRoot 'tests/validation/scope-artifacts.validation.ps1'
$testFailures = [Collections.Generic.List[string]]::new()

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { $testFailures.Add($Message) }
}

function Require-Token([string]$Text, [string]$Token, [string]$Context) {
  if ($Text -notmatch [regex]::Escape($Token)) { $errors.Add("$Context missing: $Token") }
}

function Test-MarkdownTableExactColumns(
  [string]$Text,
  [string]$Section,
  [string[]]$ExpectedColumns,
  [string]$Context
) {
  $escapedSection = [regex]::Escape($Section)
  $sectionMatch = [regex]::Match($Text, "(?ms)^## $escapedSection\s*$.*?(?=^## |\z)")
  if (-not $sectionMatch.Success) {
    $errors.Add("$Context missing section: $Section")
    return
  }
  $headerMatch = [regex]::Match($sectionMatch.Value, '(?m)^\|(?<cells>[^\r\n]+)\|\s*$')
  if (-not $headerMatch.Success) {
    $errors.Add("$Context missing table: $Section")
    return
  }
  $actual = @($headerMatch.Groups['cells'].Value.Split('|') | ForEach-Object { $_.Trim() })
  if (($actual -join '|') -cne ($ExpectedColumns -join '|')) {
    $errors.Add("$Context table $Section columns must be exactly: $($ExpectedColumns -join ' | ')")
  }
}

. $validatorPath

function Invoke-ScopeArtifactsValidation([string]$Root) {
  $script:errors = [Collections.Generic.List[string]]::new()
  Test-ScopeArtifacts $Root $contractText
  return @($script:errors)
}

function New-RenderedArtifactFixture {
  $fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ("aitoolkit-scope-artifacts-" + [guid]::NewGuid().ToString('N'))
  $templateRoot = Join-Path $fixtureRoot 'templates/migration'
  New-Item -ItemType Directory -Path $templateRoot -Force | Out-Null
  Copy-Item -LiteralPath (Join-Path $toolkitRoot 'contracts') -Destination (Join-Path $fixtureRoot 'contracts') -Recurse
  foreach ($name in @('master-spec.md', 'master-plan.md')) {
    $text = Get-Content -Raw -Encoding utf8 (Join-Path $toolkitRoot "templates/migration/$name")
    $text = [regex]::Replace($text, '<[^>\r\n]+>', 'sample-value')
    $text = $text.Replace('SPEC-sample-value-sample-value', 'SPEC-ADMIN-001')
    $text = $text.Replace('PLAN-sample-value-sample-value', 'PLAN-ADMIN-001')
    $text = $text.Replace('WORK-sample-value-sample-value', 'WORK-ADMIN-LOCKS')
    $text = $text.Replace('REQ-###', 'REQ-001')
    $text = $text.Replace('SC-###', 'SC-001')
    $text = $text.Replace('TRACE-###', 'TRACE-001')
    $text = $text.Replace('UNK-###', 'UNK-001')
    $text = $text.Replace('ATTEMPT-sample-value-sample-value', 'ATTEMPT-WORK-ADMIN-LOCKS-01')
    $text = $text.Replace('revision: sample-value', 'revision: 1')
    $text = $text.Replace('master_spec_revision: sample-value', 'master_spec_revision: 1')
    $text = $text.Replace('requested_scope_kind: sample-value', 'requested_scope_kind: module')
    $text = $text.Replace('requested_scope_id: sample-value', 'requested_scope_id: ADMIN')
    $text = $text.Replace('status: sample-value', 'status: approved')
    $text = $text.Replace('result: sample-value', 'result: complete')
    $text = $text.Replace('approval_source: sample-value', 'approval_source: human')
    $text = $text.Replace('produced_at: sample-value', 'produced_at: 2026-08-19')
    $text = $text.Replace('max_concurrency: sample-value', 'max_concurrency: 1')
    $text = $text.Replace('plan_order: sample-value', 'plan_order: 1')
    $text = $text.Replace('| WORK-ADMIN-LOCKS | sample-value | sample-value | none | sample-value | sample-value | sample-value | none | in-progress | ATTEMPT-WORK-ADMIN-LOCKS-01 | none | pending |', '| WORK-ADMIN-LOCKS | Complete Lock Mode | yes | none | 1 | REQ-001; SC-001; measurable outcome | TRACE-001 | none | in-progress | ATTEMPT-WORK-ADMIN-LOCKS-01 | none | pending |')
    $text = $text.Replace('| sample-value | sample-value | pending | sample-value |', '| human | approval:scope-admin | approved | 2026-08-19 |')
    $text = $text.Replace('| sample-value | pending | sample-value |', '| approval:plan-admin | approved | 2026-08-19 |')
    $text = $text.Replace('| REQ-001 | sample-value | sample-value | sample-value |', '| REQ-001 | Stable requirement | source:ticket | measurable acceptance |')
    $text = $text.Replace('| SC-001 | REQ-001 | sample-value |', '| SC-001 | REQ-001 | measurable outcome |')
    $text = $text.Replace('| UNK-001 | sample-value | sample-value | sample-value |', '| UNK-001 | none identified | none | resolved |')
    $text = $text.Replace('| TRACE-001 | sample-value | sample-value | sample-value |', '| TRACE-001 | requirement | source:ticket | trace note |')
    $text = $text.Replace('| sample-value | sample-value | sample-value | user | sample-value |', '| module | ADMIN | Complete Admin module | user | conversation:scope-admin |')
    $text = $text.Replace('| WORK-ADMIN-LOCKS | none | no-dependency | sample-value |', '| WORK-ADMIN-LOCKS | none | no-dependency | decision:graph-admin |')
    $text = $text.Replace('| ATTEMPT-WORK-ADMIN-LOCKS-01 | WORK-ADMIN-LOCKS | sample-value | in-progress | sample-value |', '| ATTEMPT-WORK-ADMIN-LOCKS-01 | WORK-ADMIN-LOCKS | 1 | in-progress | artifact:attempt-01 |')
    $text = $text.Replace('| WORK-ADMIN-LOCKS | ready | in-progress | ATTEMPT-WORK-ADMIN-LOCKS-01 | sample-value |', '| WORK-ADMIN-LOCKS | ready | in-progress | ATTEMPT-WORK-ADMIN-LOCKS-01 | 1 |')
    $text = $text.Replace('| SPEC-ADMIN-001 | sample-value | not-applicable | sample-value | none | pending |', '| SPEC-ADMIN-001 | 1 | not-applicable | initial approved scope | none | approval:scope-admin |')
    $text = $text.Replace('| PLAN-ADMIN-001 | sample-value | not-applicable | sample-value | none | pending |', '| PLAN-ADMIN-001 | 1 | not-applicable | initial approved plan | none | approval:plan-admin |')
    [IO.File]::WriteAllText((Join-Path $templateRoot $name), $text, [Text.UTF8Encoding]::new($false))
  }
  return $fixtureRoot
}

try {
  if (-not (Test-Path -LiteralPath (Join-Path $toolkitRoot 'templates/migration/master-spec.md'))) {
    $redErrors = Invoke-ScopeArtifactsValidation $toolkitRoot
    Assert-True ($redErrors -contains 'Missing master spec template') 'RED: missing master spec template must be rejected'
    if ($testFailures.Count -eq 0) { throw 'RED: master artifact templates are not implemented' }
  }

  $fixtureRoot = New-RenderedArtifactFixture
  try {
    $validErrors = Invoke-ScopeArtifactsValidation $fixtureRoot
    Assert-True ($validErrors.Count -eq 0) ("Rendered master artifacts must validate: " + ($validErrors -join '; '))

    $specPath = Join-Path $fixtureRoot 'templates/migration/master-spec.md'
    $originalSpec = Get-Content -Raw -Encoding utf8 $specPath
    try {
      $lifecycleCases = @(
        [pscustomobject]@{ Name = 'approved complete human'; Status = 'approved'; Result = 'complete'; ApprovalSource = 'human'; Valid = $true; Expected = $null },
        [pscustomobject]@{ Name = 'approved complete auto'; Status = 'approved'; Result = 'complete'; ApprovalSource = 'auto'; Valid = $true; Expected = $null },
        [pscustomobject]@{ Name = 'draft blocked human'; Status = 'draft'; Result = 'blocked'; ApprovalSource = 'human'; Valid = $true; Expected = $null },
        [pscustomobject]@{ Name = 'draft blocked auto'; Status = 'draft'; Result = 'blocked'; ApprovalSource = 'auto'; Valid = $true; Expected = $null },
        [pscustomobject]@{ Name = 'draft complete human'; Status = 'draft'; Result = 'complete'; ApprovalSource = 'human'; Valid = $true; Expected = $null },
        [pscustomobject]@{ Name = 'draft complete auto'; Status = 'draft'; Result = 'complete'; ApprovalSource = 'auto'; Valid = $true; Expected = $null },
        [pscustomobject]@{ Name = 'draft partial human'; Status = 'draft'; Result = 'partial'; ApprovalSource = 'human'; Valid = $false; Expected = 'master spec result partial is not valid for master artifacts' },
        [pscustomobject]@{ Name = 'approved partial human'; Status = 'approved'; Result = 'partial'; ApprovalSource = 'human'; Valid = $false; Expected = 'master spec result partial is not valid for master artifacts' },
        [pscustomobject]@{ Name = 'approved blocked human'; Status = 'approved'; Result = 'blocked'; ApprovalSource = 'human'; Valid = $false; Expected = 'master spec approved status must use result complete' },
        [pscustomobject]@{ Name = 'approved partial auto-waive'; Status = 'approved'; Result = 'partial'; ApprovalSource = 'auto-waive'; Valid = $false; Expected = 'master spec approval_source auto-waive is not valid for master artifacts' },
        [pscustomobject]@{ Name = 'draft blocked auto-waive'; Status = 'draft'; Result = 'blocked'; ApprovalSource = 'auto-waive'; Valid = $false; Expected = 'master spec approval_source auto-waive is not valid for master artifacts' },
        [pscustomobject]@{ Name = 'unknown approval source'; Status = 'approved'; Result = 'complete'; ApprovalSource = 'external'; Valid = $false; Expected = 'master spec approval_source is invalid' },
        [pscustomobject]@{ Name = 'noncanonical approval source casing'; Status = 'approved'; Result = 'complete'; ApprovalSource = 'Human'; Valid = $false; Expected = 'master spec approval_source is invalid' },
        [pscustomobject]@{ Name = 'noncanonical status casing'; Status = 'Approved'; Result = 'complete'; ApprovalSource = 'human'; Valid = $false; Expected = 'master spec status is invalid' },
        [pscustomobject]@{ Name = 'noncanonical result casing'; Status = 'draft'; Result = 'Partial'; ApprovalSource = 'human'; Valid = $false; Expected = 'master spec result is invalid' }
      )
      foreach ($case in $lifecycleCases) {
        $approvalRow = if ($case.Status -eq 'approved') { "| $($case.ApprovalSource) | approval:scope-admin | approved | 2026-08-19 |" } else { "| $($case.ApprovalSource) | pending | pending | not-applicable |" }
        $mutatedSpec = $originalSpec.Replace('status: approved', "status: $($case.Status)")
        $mutatedSpec = $mutatedSpec.Replace('result: complete', "result: $($case.Result)")
        $mutatedSpec = $mutatedSpec.Replace('approval_source: human', "approval_source: $($case.ApprovalSource)")
        $mutatedSpec = $mutatedSpec.Replace('| human | approval:scope-admin | approved | 2026-08-19 |', $approvalRow)
        [IO.File]::WriteAllText($specPath, $mutatedSpec, [Text.UTF8Encoding]::new($false))
        $lifecycleErrors = Invoke-ScopeArtifactsValidation $fixtureRoot
        if ($case.Valid) {
          Assert-True ($lifecycleErrors.Count -eq 0) ("$($case.Name) lifecycle must validate: " + ($lifecycleErrors -join '; '))
        } else {
          Assert-True ($lifecycleErrors -contains $case.Expected) ("$($case.Name) lifecycle must be rejected; got: " + ($lifecycleErrors -join '; '))
        }
      }
    }
    finally { [IO.File]::WriteAllText($specPath, $originalSpec, [Text.UTF8Encoding]::new($false)) }

    $affectedWorkItemPositiveCases = @(
      [pscustomobject]@{ Name = 'master spec'; File = 'master-spec.md'; From = '| SPEC-ADMIN-001 | 1 | not-applicable | initial approved scope | none | approval:scope-admin |'; To = '| SPEC-ADMIN-001 | 1 | not-applicable | approved scope update | WORK-ADMIN-LOCKS | approval:scope-admin |' },
      [pscustomobject]@{ Name = 'master plan'; File = 'master-plan.md'; From = '| PLAN-ADMIN-001 | 1 | not-applicable | initial approved plan | none | approval:plan-admin |'; To = '| PLAN-ADMIN-001 | 1 | not-applicable | approved plan update | WORK-ADMIN-LOCKS | approval:plan-admin |' }
    )
    foreach ($case in $affectedWorkItemPositiveCases) {
      $path = Join-Path $fixtureRoot "templates/migration/$($case.File)"
      $original = Get-Content -Raw -Encoding utf8 $path
      try {
        [IO.File]::WriteAllText($path, $original.Replace($case.From, $case.To), [Text.UTF8Encoding]::new($false))
        $affectedErrors = Invoke-ScopeArtifactsValidation $fixtureRoot
        Assert-True ($affectedErrors.Count -eq 0) ("$($case.Name) Revision History must accept an existing affected Work Item ID: " + ($affectedErrors -join '; '))
      }
      finally { [IO.File]::WriteAllText($path, $original, [Text.UTF8Encoding]::new($false)) }
    }

    $cases = @(
      [pscustomobject]@{ Name = 'missing front matter'; File = 'master-spec.md'; From = 'artifact_type: migration-master-spec'; To = 'artifact_type_removed: migration-master-spec'; Expected = 'master spec missing front matter field: artifact_type' },
      [pscustomobject]@{ Name = 'duplicate front matter'; File = 'master-plan.md'; From = 'revision: 1'; To = "revision: 1`nrevision: 1"; Expected = 'master plan duplicate front matter field: revision' },
      [pscustomobject]@{ Name = 'extra front matter'; File = 'master-spec.md'; From = 'supersedes: not-applicable'; To = "supersedes: not-applicable`nunexpected: value"; Expected = 'master spec front matter fields must be exact' },
      [pscustomobject]@{ Name = 'invalid stable master spec id'; File = 'master-spec.md'; From = 'master_spec_id: SPEC-ADMIN-001'; To = 'master_spec_id: SPEC-ADMIN'; Expected = 'master spec invalid master_spec_id: SPEC-ADMIN' },
      [pscustomobject]@{ Name = 'invalid requested scope enum'; File = 'master-spec.md'; From = 'requested_scope_kind: module'; To = 'requested_scope_kind: invalid-scope'; Expected = 'master spec requested_scope_kind is invalid' },
      [pscustomobject]@{ Name = 'invalid lifecycle status'; File = 'master-spec.md'; From = 'status: approved'; To = 'status: blocked'; Expected = 'master spec status is invalid' },
      [pscustomobject]@{ Name = 'approved spec blocked result'; File = 'master-spec.md'; From = 'result: complete'; To = 'result: blocked'; Expected = 'master spec approved status must use result complete' },
      [pscustomobject]@{ Name = 'missing section'; File = 'master-spec.md'; From = '## Approval Record'; To = '## Approval Record Removed'; Expected = 'master spec missing required section: Approval Record' },
      [pscustomobject]@{ Name = 'extra section'; File = 'master-spec.md'; From = '## Revision History'; To = "## Extra Section`n`nKhông thuộc canonical shape.`n`n## Revision History"; Expected = 'master spec sections must be exact' },
      [pscustomobject]@{ Name = 'revision chain'; File = 'master-spec.md'; From = 'supersedes: not-applicable'; To = 'supersedes: SPEC-ADMIN-001@1'; Expected = 'master spec revision 1 must supersede not-applicable' },
      [pscustomobject]@{ Name = 'spec reference mismatch'; File = 'master-plan.md'; From = 'master_spec_id: SPEC-ADMIN-001'; To = 'master_spec_id: SPEC-OTHER-001'; Expected = 'master plan master_spec_id must match master spec' },
      [pscustomobject]@{ Name = 'duplicate work item id'; File = 'master-plan.md'; From = '| WORK-ADMIN-LOCKS | Complete Lock Mode | yes | none | 1 | REQ-001; SC-001; measurable outcome | TRACE-001 | none | in-progress | ATTEMPT-WORK-ADMIN-LOCKS-01 | none | pending |'; To = "| WORK-ADMIN-LOCKS | Complete Lock Mode | yes | none | 1 | REQ-001; SC-001; measurable outcome | TRACE-001 | none | in-progress | ATTEMPT-WORK-ADMIN-LOCKS-01 | none | pending |`n| WORK-ADMIN-LOCKS | Complete other | no | none | 2 | REQ-001; SC-001; measurable outcome | TRACE-001 | none | pending | none | none | pending |"; Expected = 'master plan duplicate Work Item ID: WORK-ADMIN-LOCKS' },
      [pscustomobject]@{ Name = 'duplicate plan order'; File = 'master-plan.md'; From = '| WORK-ADMIN-LOCKS | Complete Lock Mode | yes | none | 1 | REQ-001; SC-001; measurable outcome | TRACE-001 | none | in-progress | ATTEMPT-WORK-ADMIN-LOCKS-01 | none | pending |'; To = "| WORK-ADMIN-LOCKS | Complete Lock Mode | yes | none | 1 | REQ-001; SC-001; measurable outcome | TRACE-001 | none | in-progress | ATTEMPT-WORK-ADMIN-LOCKS-01 | none | pending |`n| WORK-ADMIN-OTHER | Complete other | no | none | 1 | REQ-001; SC-001; measurable outcome | TRACE-001 | none | pending | none | none | pending |"; Expected = 'master plan duplicate Plan Order: 1' },
      [pscustomobject]@{ Name = 'missing dependency reference'; File = 'master-plan.md'; From = '| WORK-ADMIN-LOCKS | Complete Lock Mode | yes | none | 1 | REQ-001; SC-001; measurable outcome | TRACE-001 | none | in-progress | ATTEMPT-WORK-ADMIN-LOCKS-01 | none | pending |'; To = '| WORK-ADMIN-LOCKS | Complete Lock Mode | yes | WORK-ADMIN-MISSING | 1 | REQ-001; SC-001; measurable outcome | TRACE-001 | none | in-progress | ATTEMPT-WORK-ADMIN-LOCKS-01 | none | pending |'; Expected = 'master plan dependency does not reference a Work Item ID: WORK-ADMIN-MISSING' },
      [pscustomobject]@{ Name = 'duplicate requirement id'; File = 'master-spec.md'; From = '| REQ-001 | Stable requirement | source:ticket | measurable acceptance |'; To = "| REQ-001 | Stable requirement | source:ticket | measurable acceptance |`n| REQ-001 | Duplicate requirement | source:ticket | measurable acceptance |"; Expected = 'master spec duplicate Requirement ID: REQ-001' },
      [pscustomobject]@{ Name = 'duplicate success criterion id'; File = 'master-spec.md'; From = '| SC-001 | REQ-001 | measurable outcome |'; To = "| SC-001 | REQ-001 | measurable outcome |`n| SC-001 | REQ-001 | another measurable outcome |"; Expected = 'master spec duplicate Success Criterion ID: SC-001' },
      [pscustomobject]@{ Name = 'unresolved success criterion requirement'; File = 'master-spec.md'; From = '| SC-001 | REQ-001 | measurable outcome |'; To = '| SC-001 | REQ-404 | measurable outcome |'; Expected = 'master spec success criterion SC-001 references unknown Requirement ID: REQ-404' },
      [pscustomobject]@{ Name = 'scope affecting unknown approved'; File = 'master-spec.md'; From = '| UNK-001 | none identified | none | resolved |'; To = '| UNK-001 | unresolved boundary | scope | blocked |'; Expected = 'master spec scope/architecture/acceptance unknown requires status draft' },
      [pscustomobject]@{ Name = 'plan unknown blocks approved plan'; File = 'master-plan.md'; From = '| UNK-001 | none identified | none | resolved |'; To = '| UNK-001 | unresolved target pattern | architecture | blocked |'; Expected = 'master plan scope/architecture/acceptance unknown requires status draft' },
      [pscustomobject]@{ Name = 'master spec requested scope has zero rows'; File = 'master-spec.md'; From = '| module | ADMIN | Complete Admin module | user | conversation:scope-admin |'; To = 'no requested scope row'; Expected = 'master spec Requested Scope Boundary must contain exactly one row' },
      [pscustomobject]@{ Name = 'master spec requested scope has duplicate rows'; File = 'master-spec.md'; From = '| module | ADMIN | Complete Admin module | user | conversation:scope-admin |'; To = "| module | ADMIN | Complete Admin module | user | conversation:scope-admin |`n| module | ADMIN | Duplicate scope | user | conversation:scope-admin |"; Expected = 'master spec Requested Scope Boundary must contain exactly one row' },
      [pscustomobject]@{ Name = 'master plan requested scope has zero rows'; File = 'master-plan.md'; From = '| module | ADMIN | Complete Admin module | user | conversation:scope-admin |'; To = 'no requested scope row'; Expected = 'master plan Requested Scope must contain exactly one row' },
      [pscustomobject]@{ Name = 'master plan requested scope has duplicate rows'; File = 'master-plan.md'; From = '| module | ADMIN | Complete Admin module | user | conversation:scope-admin |'; To = "| module | ADMIN | Complete Admin module | user | conversation:scope-admin |`n| module | ADMIN | Duplicate scope | user | conversation:scope-admin |"; Expected = 'master plan Requested Scope must contain exactly one row' },
      [pscustomobject]@{ Name = 'requested scope kind mismatch'; File = 'master-plan.md'; From = '| module | ADMIN | Complete Admin module | user | conversation:scope-admin |'; To = '| feature | ADMIN | Complete Admin module | user | conversation:scope-admin |'; Expected = 'master plan Requested Scope Kind must match master spec' },
      [pscustomobject]@{ Name = 'requested scope plan mismatch'; File = 'master-plan.md'; From = '| module | ADMIN | Complete Admin module | user | conversation:scope-admin |'; To = '| module | OTHER | Complete Admin module | user | conversation:scope-admin |'; Expected = 'master plan Requested Scope ID must match master spec' },
      [pscustomobject]@{ Name = 'requested scope statement mismatch'; File = 'master-plan.md'; From = '| module | ADMIN | Complete Admin module | user | conversation:scope-admin |'; To = '| module | ADMIN | Other statement | user | conversation:scope-admin |'; Expected = 'master plan Requested Scope Statement must match master spec' },
      [pscustomobject]@{ Name = 'requested scope source mismatch'; File = 'master-plan.md'; From = '| module | ADMIN | Complete Admin module | user | conversation:scope-admin |'; To = '| module | ADMIN | Complete Admin module | approved-source | conversation:scope-admin |'; Expected = 'master plan Requested Scope Source must match master spec' },
      [pscustomobject]@{ Name = 'requested scope evidence mismatch'; File = 'master-plan.md'; From = '| module | ADMIN | Complete Admin module | user | conversation:scope-admin |'; To = '| module | ADMIN | Complete Admin module | user | conversation:other |'; Expected = 'master plan Requested Scope Resolution Evidence must match master spec' },
      [pscustomobject]@{ Name = 'dependency graph unknown work item'; File = 'master-plan.md'; From = '| WORK-ADMIN-LOCKS | none | no-dependency | decision:graph-admin |'; To = '| WORK-ADMIN-MISSING | none | no-dependency | decision:graph-admin |'; Expected = 'master plan Dependency Graph references unknown Work Item ID: WORK-ADMIN-MISSING' },
      [pscustomobject]@{ Name = 'dependency graph inconsistent with work item'; File = 'master-plan.md'; From = '| WORK-ADMIN-LOCKS | none | no-dependency | decision:graph-admin |'; To = '| WORK-ADMIN-LOCKS | WORK-ADMIN-LOCKS | dependency | decision:graph-admin |'; Expected = 'master plan Dependency Graph must match Work Items dependencies for WORK-ADMIN-LOCKS' },
      [pscustomobject]@{ Name = 'duplicate attempt id'; File = 'master-plan.md'; From = '| ATTEMPT-WORK-ADMIN-LOCKS-01 | WORK-ADMIN-LOCKS | 1 | in-progress | artifact:attempt-01 |'; To = "| ATTEMPT-WORK-ADMIN-LOCKS-01 | WORK-ADMIN-LOCKS | 1 | in-progress | artifact:attempt-01 |`n| ATTEMPT-WORK-ADMIN-LOCKS-01 | WORK-ADMIN-LOCKS | 1 | in-progress | artifact:attempt-duplicate |"; Expected = 'master plan duplicate Attempt ID: ATTEMPT-WORK-ADMIN-LOCKS-01' },
      [pscustomobject]@{ Name = 'attempt id work item correlation'; File = 'master-plan.md'; From = 'ATTEMPT-WORK-ADMIN-LOCKS-01 | WORK-ADMIN-LOCKS'; To = 'ATTEMPT-WORK-ADMIN-OTHER-01 | WORK-ADMIN-LOCKS'; Expected = 'master plan Attempt ID ATTEMPT-WORK-ADMIN-OTHER-01 must correlate to Work Item ID WORK-ADMIN-LOCKS' },
      [pscustomobject]@{ Name = 'attempt status enum'; File = 'master-plan.md'; From = '| 1 | in-progress | artifact:attempt-01 |'; To = '| 1 | pending | artifact:attempt-01 |'; Expected = 'master plan Attempt History status is invalid: pending' },
      [pscustomobject]@{ Name = 'attempt artifact reference sentinel'; File = 'master-plan.md'; From = 'in-progress | artifact:attempt-01 |'; To = 'in-progress | none |'; Expected = 'master plan Attempt History Artifact Reference must be exact: none' },
      [pscustomobject]@{ Name = 'attempt artifact reference reused'; File = 'master-plan.md'; From = '| ATTEMPT-WORK-ADMIN-LOCKS-01 | WORK-ADMIN-LOCKS | 1 | in-progress | artifact:attempt-01 |'; To = "| ATTEMPT-WORK-ADMIN-LOCKS-01 | WORK-ADMIN-LOCKS | 1 | blocked | artifact:attempt-01 |`n| ATTEMPT-WORK-ADMIN-LOCKS-02 | WORK-ADMIN-LOCKS | 1 | in-progress | artifact:attempt-01 |"; Expected = 'master plan duplicate Attempt History Artifact Reference: artifact:attempt-01' },
      [pscustomobject]@{ Name = 'latest attempt missing'; File = 'master-plan.md'; From = '| in-progress | ATTEMPT-WORK-ADMIN-LOCKS-01 | none | pending |'; To = '| in-progress | none | none | pending |'; Expected = 'master plan Work Item WORK-ADMIN-LOCKS Latest Attempt must be ATTEMPT-WORK-ADMIN-LOCKS-01' },
      [pscustomobject]@{ Name = 'latest attempt is not highest sequence'; File = 'master-plan.md'; From = '| ATTEMPT-WORK-ADMIN-LOCKS-01 | WORK-ADMIN-LOCKS | 1 | in-progress | artifact:attempt-01 |'; To = "| ATTEMPT-WORK-ADMIN-LOCKS-01 | WORK-ADMIN-LOCKS | 1 | blocked | artifact:attempt-01 |`n| ATTEMPT-WORK-ADMIN-LOCKS-02 | WORK-ADMIN-LOCKS | 1 | in-progress | artifact:attempt-02 |"; Expected = 'master plan Work Item WORK-ADMIN-LOCKS Latest Attempt must be ATTEMPT-WORK-ADMIN-LOCKS-02' },
      [pscustomobject]@{ Name = 'work item state contradicts active attempt'; File = 'master-plan.md'; From = '| in-progress | ATTEMPT-WORK-ADMIN-LOCKS-01 | none | pending |'; To = '| pending | ATTEMPT-WORK-ADMIN-LOCKS-01 | none | pending |'; Expected = 'master plan Work Item WORK-ADMIN-LOCKS Status must match latest attempt status in-progress' },
      [pscustomobject]@{ Name = 'active attempt has terminal evidence'; File = 'master-plan.md'; From = '| in-progress | ATTEMPT-WORK-ADMIN-LOCKS-01 | none | pending |'; To = '| in-progress | ATTEMPT-WORK-ADMIN-LOCKS-01 | artifact:attempt-01 | pending |'; Expected = 'master plan Work Item WORK-ADMIN-LOCKS Terminal Evidence must be none for in-progress attempt' },
      [pscustomobject]@{ Name = 'attempt history revision mismatch'; File = 'master-plan.md'; From = '| ATTEMPT-WORK-ADMIN-LOCKS-01 | WORK-ADMIN-LOCKS | 1 | in-progress | artifact:attempt-01 |'; To = '| ATTEMPT-WORK-ADMIN-LOCKS-01 | WORK-ADMIN-LOCKS | 2 | in-progress | artifact:attempt-01 |'; Expected = 'master plan Attempt History Plan Revision must match master plan revision' },
      [pscustomobject]@{ Name = 'transition from state enum'; File = 'master-plan.md'; From = '| WORK-ADMIN-LOCKS | ready | in-progress | ATTEMPT-WORK-ADMIN-LOCKS-01 | 1 |'; To = '| WORK-ADMIN-LOCKS | unknown | in-progress | ATTEMPT-WORK-ADMIN-LOCKS-01 | 1 |'; Expected = 'master plan State Transition Log From State is invalid: unknown' },
      [pscustomobject]@{ Name = 'transition to state enum'; File = 'master-plan.md'; From = '| WORK-ADMIN-LOCKS | ready | in-progress | ATTEMPT-WORK-ADMIN-LOCKS-01 | 1 |'; To = '| WORK-ADMIN-LOCKS | ready | unknown | ATTEMPT-WORK-ADMIN-LOCKS-01 | 1 |'; Expected = 'master plan State Transition Log To State is invalid: unknown' },
      [pscustomobject]@{ Name = 'illegal transition edge'; File = 'master-plan.md'; From = '| WORK-ADMIN-LOCKS | ready | in-progress | ATTEMPT-WORK-ADMIN-LOCKS-01 | 1 |'; To = '| WORK-ADMIN-LOCKS | ready | complete | ATTEMPT-WORK-ADMIN-LOCKS-01 | 1 |'; Expected = 'master plan illegal State Transition: ready -> complete' },
      [pscustomobject]@{ Name = 'unordered transition edges'; File = 'master-plan.md'; From = '| WORK-ADMIN-LOCKS | ready | in-progress | ATTEMPT-WORK-ADMIN-LOCKS-01 | 1 |'; To = "| WORK-ADMIN-LOCKS | ready | in-progress | ATTEMPT-WORK-ADMIN-LOCKS-01 | 1 |`n| WORK-ADMIN-LOCKS | pending | cancelled-approved | approval:cancel-work-admin | 1 |"; Expected = 'master plan State Transition Log is not ordered for WORK-ADMIN-LOCKS: expected From State in-progress, got pending' },
      [pscustomobject]@{ Name = 'latest transition state mismatch'; File = 'master-plan.md'; From = '| in-progress | ATTEMPT-WORK-ADMIN-LOCKS-01 | none | pending |'; To = '| ready | ATTEMPT-WORK-ADMIN-LOCKS-01 | none | pending |'; Expected = 'master plan Work Item WORK-ADMIN-LOCKS Status must match latest transition To State: in-progress' },
      [pscustomobject]@{ Name = 'transition history unknown work item'; File = 'master-plan.md'; From = '| WORK-ADMIN-LOCKS | ready | in-progress | ATTEMPT-WORK-ADMIN-LOCKS-01 | 1 |'; To = '| WORK-ADMIN-MISSING | ready | in-progress | ATTEMPT-WORK-ADMIN-LOCKS-01 | 1 |'; Expected = 'master plan State Transition Log references unknown Work Item ID: WORK-ADMIN-MISSING' },
      [pscustomobject]@{ Name = 'revision history artifact mismatch'; File = 'master-plan.md'; From = '| PLAN-ADMIN-001 | 1 | not-applicable | initial approved plan | none | approval:plan-admin |'; To = '| PLAN-OTHER-001 | 1 | not-applicable | initial approved plan | none | approval:plan-admin |'; Expected = 'master plan Revision History Artifact ID must match master_plan_id' },
      [pscustomobject]@{ Name = 'spec affected work items mixes none'; File = 'master-spec.md'; From = '| SPEC-ADMIN-001 | 1 | not-applicable | initial approved scope | none | approval:scope-admin |'; To = '| SPEC-ADMIN-001 | 1 | not-applicable | changed scope | none; WORK-ADMIN-LOCKS | approval:scope-admin |'; Expected = 'master spec Revision History Affected Work Items must use none alone' },
      [pscustomobject]@{ Name = 'spec affected work items unknown id'; File = 'master-spec.md'; From = '| SPEC-ADMIN-001 | 1 | not-applicable | initial approved scope | none | approval:scope-admin |'; To = '| SPEC-ADMIN-001 | 1 | not-applicable | changed scope | WORK-ADMIN-MISSING | approval:scope-admin |'; Expected = 'master spec Revision History references unknown Work Item ID: WORK-ADMIN-MISSING' },
      [pscustomobject]@{ Name = 'spec affected work items noncanonical sentinel'; File = 'master-spec.md'; From = '| SPEC-ADMIN-001 | 1 | not-applicable | initial approved scope | none | approval:scope-admin |'; To = '| SPEC-ADMIN-001 | 1 | not-applicable | changed scope | not-applicable | approval:scope-admin |'; Expected = 'master spec Revision History Affected Work Items must use none instead of not-applicable' },
      [pscustomobject]@{ Name = 'plan affected work items mixes none'; File = 'master-plan.md'; From = '| PLAN-ADMIN-001 | 1 | not-applicable | initial approved plan | none | approval:plan-admin |'; To = '| PLAN-ADMIN-001 | 1 | not-applicable | changed plan | none; WORK-ADMIN-LOCKS | approval:plan-admin |'; Expected = 'master plan Revision History Affected Work Items must use none alone' },
      [pscustomobject]@{ Name = 'plan affected work items unknown id'; File = 'master-plan.md'; From = '| PLAN-ADMIN-001 | 1 | not-applicable | initial approved plan | none | approval:plan-admin |'; To = '| PLAN-ADMIN-001 | 1 | not-applicable | changed plan | WORK-ADMIN-MISSING | approval:plan-admin |'; Expected = 'master plan Revision History references unknown Work Item ID: WORK-ADMIN-MISSING' },
      [pscustomobject]@{ Name = 'plan affected work items noncanonical sentinel'; File = 'master-plan.md'; From = '| PLAN-ADMIN-001 | 1 | not-applicable | initial approved plan | none | approval:plan-admin |'; To = '| PLAN-ADMIN-001 | 1 | not-applicable | changed plan | not-applicable | approval:plan-admin |'; Expected = 'master plan Revision History Affected Work Items must use none instead of not-applicable' },
      [pscustomobject]@{ Name = 'blank acceptance'; File = 'master-plan.md'; From = 'REQ-001; SC-001; measurable outcome'; To = ''; Expected = 'master plan Work Items row 1 has blank cell: Acceptance' },
      [pscustomobject]@{ Name = 'blank approval reference'; File = 'master-plan.md'; From = '| approval:plan-admin | approved | 2026-08-19 |'; To = '|  | approved | 2026-08-19 |'; Expected = 'master plan Approval Record row 1 has blank cell: Approval Reference' }
    )
    foreach ($case in $cases) {
      $path = Join-Path $fixtureRoot "templates/migration/$($case.File)"
      $original = Get-Content -Raw -Encoding utf8 $path
      try {
        [IO.File]::WriteAllText($path, $original.Replace($case.From, $case.To), [Text.UTF8Encoding]::new($false))
        $caseErrors = Invoke-ScopeArtifactsValidation $fixtureRoot
        Assert-True ($caseErrors -contains $case.Expected) ("$($case.Name) must be rejected; got: " + ($caseErrors -join '; '))
      }
      finally {
        [IO.File]::WriteAllText($path, $original, [Text.UTF8Encoding]::new($false))
      }
    }

    $planPath = Join-Path $fixtureRoot 'templates/migration/master-plan.md'
    $originalPlan = Get-Content -Raw -Encoding utf8 $planPath
    try {
      $completedPlan = $originalPlan.Replace('| in-progress | ATTEMPT-WORK-ADMIN-LOCKS-01 | none | pending |', '| complete | ATTEMPT-WORK-ADMIN-LOCKS-01 | artifact:attempt-01 | pending |')
      $completedPlan = $completedPlan.Replace('| 1 | in-progress | artifact:attempt-01 |', '| 1 | complete | artifact:attempt-01 |')
      $completedPlan = $completedPlan.Replace('| WORK-ADMIN-LOCKS | ready | in-progress | ATTEMPT-WORK-ADMIN-LOCKS-01 | 1 |', "| WORK-ADMIN-LOCKS | ready | in-progress | ATTEMPT-WORK-ADMIN-LOCKS-01 | 1 |`n| WORK-ADMIN-LOCKS | in-progress | complete | artifact:attempt-01 | 1 |")
      [IO.File]::WriteAllText($planPath, $completedPlan, [Text.UTF8Encoding]::new($false))
      Assert-True ((Invoke-ScopeArtifactsValidation $fixtureRoot).Count -eq 0) 'completed attempt with matching work item, transition, and terminal evidence must validate'

      $missingInitialTransition = $completedPlan.Replace("| WORK-ADMIN-LOCKS | ready | in-progress | ATTEMPT-WORK-ADMIN-LOCKS-01 | 1 |`n", '')
      [IO.File]::WriteAllText($planPath, $missingInitialTransition, [Text.UTF8Encoding]::new($false))
      $missingInitialErrors = Invoke-ScopeArtifactsValidation $fixtureRoot
      Assert-True ($missingInitialErrors -contains 'master plan Attempt ATTEMPT-WORK-ADMIN-LOCKS-01 must start with ready -> in-progress') ("completed attempt without its initial transition must be rejected; got: " + ($missingInitialErrors -join '; '))

      $mismatchedTransitionEvidence = $completedPlan.Replace('| WORK-ADMIN-LOCKS | in-progress | complete | artifact:attempt-01 | 1 |', '| WORK-ADMIN-LOCKS | in-progress | complete | artifact:other-attempt | 1 |')
      [IO.File]::WriteAllText($planPath, $mismatchedTransitionEvidence, [Text.UTF8Encoding]::new($false))
      $transitionEvidenceErrors = Invoke-ScopeArtifactsValidation $fixtureRoot
      Assert-True ($transitionEvidenceErrors -contains 'master plan Attempt ATTEMPT-WORK-ADMIN-LOCKS-01 terminal transition evidence must match Artifact Reference: artifact:attempt-01') ("completed attempt terminal transition evidence mismatch must be rejected; got: " + ($transitionEvidenceErrors -join '; '))

      $missingTerminalEvidence = $completedPlan.Replace('| complete | ATTEMPT-WORK-ADMIN-LOCKS-01 | artifact:attempt-01 | pending |', '| complete | ATTEMPT-WORK-ADMIN-LOCKS-01 | none | pending |')
      [IO.File]::WriteAllText($planPath, $missingTerminalEvidence, [Text.UTF8Encoding]::new($false))
      $terminalErrors = Invoke-ScopeArtifactsValidation $fixtureRoot
      Assert-True ($terminalErrors -contains 'master plan Work Item WORK-ADMIN-LOCKS Terminal Evidence must match latest attempt Artifact Reference: artifact:attempt-01') ("completed attempt terminal evidence mismatch must be rejected; got: " + ($terminalErrors -join '; '))
    }
    finally { [IO.File]::WriteAllText($planPath, $originalPlan, [Text.UTF8Encoding]::new($false)) }
  }
  finally {
    if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
  }
}
finally {
  if ($testFailures.Count -gt 0) {
    $testFailures | ForEach-Object { Write-Output "FAIL: $_" }
    exit 1
  }
}

Write-Output 'PASS: scope artifact scenarios'

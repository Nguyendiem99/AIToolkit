$ErrorActionPreference = 'Stop'

$toolkitRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$validatorPath = Join-Path $toolkitRoot 'tests/validation/architecture-review.validation.ps1'
$contractText = Get-Content -Raw -Encoding utf8 -LiteralPath (Join-Path $toolkitRoot 'contracts/target-structure-conformance.md')

function Require-Token([string]$Text, [string]$Token, [string]$Context) {
  if ($Text -notmatch [regex]::Escape($Token)) {
    $script:errors.Add("$Context missing: $Token")
  }
}

. $validatorPath

$canonicalReviewSkill = @'
# AI Review

## Architecture-first migration review gates

For migration, perform these gates in order:

1. Master scope and work-item alignment.
2. Project rule resolution.
3. Canonical selector validation.
4. Architecture conformance against the approved matrix and exemplars.
5. Production activation-path validation.
6. Behavior, failure modes, security, performance, and tests.
7. Change hygiene.

Missing master context, canonical selector, conformance matrix, exemplar, actual/planned tree evidence, or applicable production activation evidence records the matching verdict as `BLOCKED`, sets the overall verdict to `Reject`, and stops before reviewer dispatch and before behavior analysis. Rule Resolution remains an independent first severity gate and cannot be weakened by architecture ordering.

Require exactly one Architecture Conformance Verdict, exactly one Canonical Selector Verdict, and exactly one Production Activation-path Verdict. Any `BLOCKED` verdict makes the overall verdict `Reject`, independently of severity counts.

## Mandatory architecture findings

Review invented aggregate state; direct widget service/router calls; raw layout replacing the target wrapper; missing unit boundary; wrong localization mechanism; missing lifecycle gate; tests bypassing the production provider; missing production subscription key; planned/actual tree drift; and unapproved structural deviation. Classify a missing production subscription key as `Critical`. An unapproved structural deviation is at least `Major` and is `Critical` when activation, routing, or rendering fails.

## Procedure

Procedure ordering: load rule resources without evaluating Rule Resolution.
Procedure ordering: validate Master Scope Context/work-item alignment before evaluating Rule Resolution.
'@

$canonicalKnowledgeSkill = @'
# Knowledge Base

## Scope-aware migration capture

For migration, record the work-item verdict, exact master-plan transition, required items remaining, next eligible item or blocker, and calculated scope status from the approved master plan. Calculate scope status with the canonical Scope-completion formula. Never infer `scope-complete` from one execution artifact, one completed work item, or a successful attempt. A completed work item with any required item remaining is `scope-in-progress`.
'@

$canonicalReviewTemplate = @'
# Review

## Master Scope Context
| Master Spec Reference | Master Plan Reference | Master Plan Revision | Work Item ID | Delivery Adapter Kind |
|---|---|---|---|---|
| <spec> | <plan> | <revision> | <work item> | <kind> |

Keep `Selected Migration Unit` only when `Delivery Adapter Kind` is `migration-unit`; otherwise omit it.

## Selected Migration Unit
| Migration Unit ID | Plan Reference | Approval Reference | Mode Constraint | Bootstrap Scope | Foundation Baseline ID | Foundation Baseline Reference | Foundation Baseline Approval Reference | Baseline Reference | Trace IDs |
|---|---|---|---|---|---|---|---|---|---|
| <UNIT-001> | <plan> | <approval> | <mode> | <scope> | <foundation ID> | <foundation reference> | <foundation approval> | <baseline> | <trace IDs> |

## Rule Resolution
- State: <RESOLVED | BLOCKED>

## Canonical Selector
- Canonical Selector Verdict: <PASS | BLOCKED>
- Evidence: <selector evidence>

## Architecture Conformance
- Architecture Conformance Verdict: <PASS | BLOCKED>
- Conformance Matrix Reference: <matrix>
- Exemplars: <exemplars>
- Actual File Tree vs Planned File Tree: <comparison>

## Production Activation Path
- Production Activation-path Verdict: <PASS | BLOCKED | NOT_APPLICABLE>
- Production Activation Path Evidence: <path>
- Production Subscription Key: <key or not-applicable>
- Lifecycle Gate: <gate or not-applicable>

## Behavior, Failure Modes, Security, Performance, and Tests
- Behavior Analysis State: <NOT_RUN | COMPLETE>
- Analysis: <analysis performed only after all preceding gates pass>

## Critical
| File:line | Issue | Proposed fix |
|---|---|---|

## Change Hygiene
| Evidence |
|---|

## Conclusion
- Verdict: <Approve | Approve-with-fixes | Reject>
'@

$canonicalKbTemplate = @'
# Knowledge Base

## Work Item and Master Plan Transition
| Work Item ID | Work Item Verdict | Master Plan Reference | Master Plan Revision | Transition | Terminal Evidence |
|---|---|---|---|---|---|
| <work item> | <complete or blocked> | <plan> | <revision> | <from -> to> | <artifact> |

## Scope Status Calculation
| Required Items Remaining | Next Eligible Item | Blocker | Dependency Graph State | Required Items Terminal-success | Architecture Conformance State | Selector Schema State | Terminal Scope Report | Calculated Scope Status | Calculation Evidence |
|---|---|---|---|---|---|---|---|---|---|
| <count and IDs> | <work item or none> | <blocker or none> | <valid / invalid> | <all-terminal-success / remaining> | <PASS / BLOCKED> | <PASS / BLOCKED> | <scope-terminal-report.md#evidence-index or not-applicable> | <planned / scope-in-progress / scope-blocked / scope-complete / scope-cancelled-approved> | <master-plan evidence; scope-complete requires all-required-terminal-evidence> |
'@

function New-ArchitectureReviewFixture {
  param([scriptblock]$Mutation)

  $root = Join-Path ([IO.Path]::GetTempPath()) ('aitoolkit-architecture-review-' + [guid]::NewGuid().ToString('N'))
  foreach ($relativeDirectory in @('contracts', 'skills/shared/ai-review', 'skills/shared/knowledge-base', 'templates/migration', 'templates')) {
    [void](New-Item -ItemType Directory -Force -Path (Join-Path $root $relativeDirectory))
  }
  Set-Content -Encoding utf8 -LiteralPath (Join-Path $root 'contracts/target-structure-conformance.md') -Value $contractText
  Set-Content -Encoding utf8 -LiteralPath (Join-Path $root 'skills/shared/ai-review/SKILL.md') -Value $canonicalReviewSkill
  Set-Content -Encoding utf8 -LiteralPath (Join-Path $root 'skills/shared/knowledge-base/SKILL.md') -Value $canonicalKnowledgeSkill
  Set-Content -Encoding utf8 -LiteralPath (Join-Path $root 'templates/migration/review-report.md') -Value $canonicalReviewTemplate
  Set-Content -Encoding utf8 -LiteralPath (Join-Path $root 'templates/kb-entry.md') -Value $canonicalKbTemplate
  if ($null -ne $Mutation) { & $Mutation $root }
  return $root
}

function Invoke-ArchitectureReviewCase {
  param([scriptblock]$Mutation)

  $root = New-ArchitectureReviewFixture $Mutation
  try {
    $script:errors = [Collections.Generic.List[string]]::new()
    Test-ArchitectureReview $root $contractText
    return @($script:errors)
  }
  finally {
    Remove-Item -LiteralPath $root -Recurse -Force
  }
}

function Assert-Pass([string]$Name, [scriptblock]$Mutation) {
  $caseErrors = @(Invoke-ArchitectureReviewCase $Mutation)
  if ($caseErrors.Count -gt 0) {
    throw "$Name expected PASS but failed: $($caseErrors -join '; ')"
  }
  Write-Output "PASS: $Name"
}

function Assert-FailsLike([string]$Name, [scriptblock]$Mutation, [string]$Pattern) {
  $caseErrors = @(Invoke-ArchitectureReviewCase $Mutation)
  if ($caseErrors.Count -eq 0) { throw "$Name expected failure but passed" }
  if (($caseErrors -join [Environment]::NewLine) -notmatch $Pattern) {
    throw "$Name failed for the wrong reason: $($caseErrors -join '; ')"
  }
  Write-Output "PASS: $Name"
}

function Set-RenderedReviewFixture([string]$Root, [string]$AdapterKind, [bool]$KeepSelectedUnit) {
  $path = Join-Path $Root 'templates/migration/review-report.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $text = $text.Replace('| <spec> | <plan> | <revision> | <work item> | <kind> |', "| master-spec.md | master-plan.md | 1 | WORK-ADMIN-A | $AdapterKind |")
  $first = $text.IndexOf('<PASS | BLOCKED>', [StringComparison]::Ordinal)
  $text = $text.Remove($first, '<PASS | BLOCKED>'.Length).Insert($first, 'PASS')
  $second = $text.IndexOf('<PASS | BLOCKED>', [StringComparison]::Ordinal)
  $text = $text.Remove($second, '<PASS | BLOCKED>'.Length).Insert($second, 'PASS')
  $activation = if ($AdapterKind -ceq 'none') { 'NOT_APPLICABLE' } else { 'PASS' }
  $text = $text.Replace('<PASS | BLOCKED | NOT_APPLICABLE>', $activation)
  $text = $text.Replace('<NOT_RUN | COMPLETE>', 'COMPLETE')
  $text = $text.Replace('<Approve | Approve-with-fixes | Reject>', 'Approve')
  if ($KeepSelectedUnit) {
    $text = $text.Replace('| <UNIT-001> | <plan> | <approval> | <mode> | <scope> | <foundation ID> | <foundation reference> | <foundation approval> | <baseline> | <trace IDs> |', '| UNIT-001 | migration-plan.md | approval:UNIT-001 | incremental | required | not-applicable | not-applicable | not-applicable | baseline.md | REQ-001 |')
  }
  else {
    $text = [regex]::Replace($text, '(?ms)^## Selected Migration Unit\r?\n.*?(?=^## Rule Resolution)', '')
  }
  Set-Content -Encoding utf8 -LiteralPath $path -Value $text
}

function Set-RenderedKbFixture([string]$Root, [string]$ScopeRow) {
  $path = Join-Path $Root 'templates/kb-entry.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $text = $text.Replace('| <work item> | <complete or blocked> | <plan> | <revision> | <from -> to> | <artifact> |', '| WORK-A | complete | master-plan.md | 1 | in-progress -> complete | implementation-report.md |')
  $schemaRow = '| <count and IDs> | <work item or none> | <blocker or none> | <valid / invalid> | <all-terminal-success / remaining> | <PASS / BLOCKED> | <PASS / BLOCKED> | <scope-terminal-report.md#evidence-index or not-applicable> | <planned / scope-in-progress / scope-blocked / scope-complete / scope-cancelled-approved> | <master-plan evidence; scope-complete requires all-required-terminal-evidence> |'
  $text = $text.Replace($schemaRow, $ScopeRow)
  Set-Content -Encoding utf8 -LiteralPath $path -Value $text
}

Assert-Pass 'complete architecture-first review and scope-aware KB contract' $null

Assert-Pass 'rendered migration-unit report has one canonical selected unit' {
  param($root)
  Set-RenderedReviewFixture $root 'migration-unit' $true
}

Assert-Pass 'rendered generic adapter omits selected migration unit' {
  param($root)
  Set-RenderedReviewFixture $root 'task' $false
}

Assert-Pass 'rendered KB keeps scope in progress while required work remains' {
  param($root)
  Set-RenderedKbFixture $root '| 1: WORK-B | WORK-B | none | valid | remaining | PASS | PASS | not-applicable | scope-in-progress | master-plan.md#WORK-B |'
}

Assert-Pass 'rendered KB permits scope complete only with full formula evidence' {
  param($root)
  Set-RenderedKbFixture $root '| none | none | none | valid | all-terminal-success | PASS | PASS | scope-terminal-report.md#evidence-index | scope-complete | master-plan.md;all-required-terminal-evidence;scope-terminal-report.md#evidence-index |'
}

Assert-FailsLike 'selector and matrix gates precede behavior review' {
  param($root)
  $path = Join-Path $root 'skills/shared/ai-review/SKILL.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $text = $text.Replace('3. Canonical selector validation.', '6. Canonical selector validation.')
  $text = $text.Replace('6. Behavior, failure modes, security, performance, and tests.', '3. Behavior, failure modes, security, performance, and tests.')
  $text = $text.Replace('stops before reviewer dispatch and before behavior analysis', 'continues through behavior analysis')
  Set-Content -Encoding utf8 -LiteralPath $path -Value $text
} 'order|before behavior'

Assert-FailsLike 'actual procedure evaluates master alignment before project rules' {
  param($root)
  $path = Join-Path $root 'skills/shared/ai-review/SKILL.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $text = $text.Replace('Procedure ordering: load rule resources without evaluating Rule Resolution.', 'Procedure ordering: evaluate Rule Resolution immediately.')
  $text = $text.Replace('Procedure ordering: validate Master Scope Context/work-item alignment before evaluating Rule Resolution.', 'Procedure ordering: evaluate Rule Resolution before Master Scope Context/work-item alignment.')
  Set-Content -Encoding utf8 -LiteralPath $path -Value $text
} 'procedure|master alignment|Rule Resolution'

Assert-FailsLike 'all three verdict fields occur exactly once' {
  param($root)
  $path = Join-Path $root 'templates/migration/review-report.md'
  Add-Content -Encoding utf8 -LiteralPath $path -Value '- Canonical Selector Verdict: <PASS | BLOCKED>'
} 'exactly once|Canonical Selector Verdict'

Assert-FailsLike 'a missing mandatory verdict is rejected' {
  param($root)
  $path = Join-Path $root 'templates/migration/review-report.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $text = $text.Replace('- Architecture Conformance Verdict: <PASS | BLOCKED>', '- Architecture verdict omitted: <PASS | BLOCKED>')
  Set-Content -Encoding utf8 -LiteralPath $path -Value $text
} 'exactly once|Architecture Conformance Verdict'

Assert-FailsLike 'verdict values use the exact enum' {
  param($root)
  $path = Join-Path $root 'templates/migration/review-report.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $text = $text.Replace('<PASS | BLOCKED | NOT_APPLICABLE>', '<PASS | BLOCKED | N/A>')
  Set-Content -Encoding utf8 -LiteralPath $path -Value $text
} 'invalid verdict|Production Activation-path Verdict'

Assert-FailsLike 'a blocked architecture verdict forces Reject independent of counts' {
  param($root)
  $path = Join-Path $root 'templates/migration/review-report.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $selectorIndex = $text.IndexOf('<PASS | BLOCKED>', [StringComparison]::Ordinal)
  $text = $text.Remove($selectorIndex, '<PASS | BLOCKED>'.Length).Insert($selectorIndex, 'BLOCKED')
  $architectureIndex = $text.IndexOf('<PASS | BLOCKED>', [StringComparison]::Ordinal)
  $text = $text.Remove($architectureIndex, '<PASS | BLOCKED>'.Length).Insert($architectureIndex, 'PASS')
  $text = $text.Replace('<PASS | BLOCKED | NOT_APPLICABLE>', 'NOT_APPLICABLE')
  $text = $text.Replace('<NOT_RUN | COMPLETE>', 'NOT_RUN')
  $text = $text.Replace('<Approve | Approve-with-fixes | Reject>', 'Approve')
  Set-Content -Encoding utf8 -LiteralPath $path -Value $text
} 'BLOCKED|Reject|severity'

Assert-FailsLike 'blocked structural verdict stops before behavior analysis' {
  param($root)
  $path = Join-Path $root 'templates/migration/review-report.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $selectorIndex = $text.IndexOf('<PASS | BLOCKED>', [StringComparison]::Ordinal)
  $text = $text.Remove($selectorIndex, '<PASS | BLOCKED>'.Length).Insert($selectorIndex, 'BLOCKED')
  $architectureIndex = $text.IndexOf('<PASS | BLOCKED>', [StringComparison]::Ordinal)
  $text = $text.Remove($architectureIndex, '<PASS | BLOCKED>'.Length).Insert($architectureIndex, 'PASS')
  $text = $text.Replace('<PASS | BLOCKED | NOT_APPLICABLE>', 'NOT_APPLICABLE')
  $text = $text.Replace('<NOT_RUN | COMPLETE>', 'COMPLETE')
  $text = $text.Replace('<Approve | Approve-with-fixes | Reject>', 'Reject')
  Set-Content -Encoding utf8 -LiteralPath $path -Value $text
} 'before behavior analysis'

foreach ($lineEndingCase in @(
  [pscustomobject]@{ Name = 'LF'; NewLine = "`n" }
  [pscustomobject]@{ Name = 'CRLF'; NewLine = "`r`n" }
)) {
  Assert-FailsLike "mixed schema/rendered verdict mode is rejected ($($lineEndingCase.Name))" {
    param($root)
    $path = Join-Path $root 'templates/migration/review-report.md'
    $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
    $selectorIndex = $text.IndexOf('<PASS | BLOCKED>', [StringComparison]::Ordinal)
    $text = $text.Remove($selectorIndex, '<PASS | BLOCKED>'.Length).Insert($selectorIndex, 'BLOCKED')
    $text = $text.Replace('<NOT_RUN | COMPLETE>', 'COMPLETE')
    $text = $text.Replace('<Approve | Approve-with-fixes | Reject>', 'Approve')
    $text = ($text -replace '\r?\n', $lineEndingCase.NewLine)
    [IO.File]::WriteAllText($path, $text, [Text.UTF8Encoding]::new($false))
  } 'mixed|schema|rendered'
}

foreach ($blockedVerdictLabel in @(
  'Canonical Selector Verdict',
  'Architecture Conformance Verdict',
  'Production Activation-path Verdict'
)) {
  foreach ($lineEndingCase in @(
    [pscustomobject]@{ Name = 'LF'; NewLine = "`n" }
    [pscustomobject]@{ Name = 'CRLF'; NewLine = "`r`n" }
  )) {
    Assert-FailsLike "$blockedVerdictLabel BLOCKED forces Reject and NOT_RUN ($($lineEndingCase.Name))" {
      param($root)
      Set-RenderedReviewFixture $root 'migration-unit' $true
      $path = Join-Path $root 'templates/migration/review-report.md'
      $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
      $text = $text.Replace("- $blockedVerdictLabel`: PASS", "- $blockedVerdictLabel`: BLOCKED")
      $text = [regex]::Replace($text, '\r?\n', $lineEndingCase.NewLine)
      [IO.File]::WriteAllText($path, $text, [Text.UTF8Encoding]::new($false))
    } 'overall Reject|before behavior analysis'
  }
}

Assert-FailsLike 'missing production subscription key is Critical' {
  param($root)
  $path = Join-Path $root 'skills/shared/ai-review/SKILL.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $text = $text.Replace('Classify a missing production subscription key as `Critical`.', 'Classify a missing production subscription key as `Major`.')
  Set-Content -Encoding utf8 -LiteralPath $path -Value $text
} 'subscription key|Critical'

Assert-FailsLike 'review report contains architecture evidence before findings' {
  param($root)
  $path = Join-Path $root 'templates/migration/review-report.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $text = $text.Replace('## Architecture Conformance', '## Architecture Evidence Removed')
  Set-Content -Encoding utf8 -LiteralPath $path -Value $text
} 'Architecture Conformance'

Assert-FailsLike 'selected migration unit is conditional on migration-unit adapter' {
  param($root)
  $path = Join-Path $root 'templates/migration/review-report.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $text = $text.Replace('Keep `Selected Migration Unit` only when `Delivery Adapter Kind` is `migration-unit`; otherwise omit it.', 'Always keep `Selected Migration Unit`.')
  Set-Content -Encoding utf8 -LiteralPath $path -Value $text
} 'Selected Migration Unit|migration-unit'

Assert-FailsLike 'generic adapter renders no Selected Migration Unit section' {
  param($root)
  $path = Join-Path $root 'templates/migration/review-report.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $text = $text.Replace('<kind>', 'task')
  $first = $text.IndexOf('<PASS | BLOCKED>', [StringComparison]::Ordinal)
  $text = $text.Remove($first, '<PASS | BLOCKED>'.Length).Insert($first, 'PASS')
  $second = $text.IndexOf('<PASS | BLOCKED>', [StringComparison]::Ordinal)
  $text = $text.Remove($second, '<PASS | BLOCKED>'.Length).Insert($second, 'PASS')
  $text = $text.Replace('<PASS | BLOCKED | NOT_APPLICABLE>', 'NOT_APPLICABLE')
  $text = $text.Replace('<NOT_RUN | COMPLETE>', 'COMPLETE')
  $text = $text.Replace('<Approve | Approve-with-fixes | Reject>', 'Approve')
  Set-Content -Encoding utf8 -LiteralPath $path -Value $text
} 'Selected Migration Unit|generic|task'

Assert-FailsLike 'migration-unit adapter rejects missing selected unit section' {
  param($root)
  Set-RenderedReviewFixture $root 'migration-unit' $false
} 'exactly one Selected Migration Unit|migration-unit'

Assert-FailsLike 'migration-unit adapter rejects duplicate selected unit sections' {
  param($root)
  Set-RenderedReviewFixture $root 'migration-unit' $true
  $path = Join-Path $root 'templates/migration/review-report.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $match = [regex]::Match($text, '(?ms)^## Selected Migration Unit\r?\n.*?(?=^## Rule Resolution)')
  $text = $text.Insert($match.Index + $match.Length, $match.Value)
  Set-Content -Encoding utf8 -LiteralPath $path -Value $text
} 'exactly one Selected Migration Unit|found 2'

Assert-FailsLike 'duplicate Master Scope Context table is rejected' {
  param($root)
  $path = Join-Path $root 'templates/migration/review-report.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $table = "| Master Spec Reference | Master Plan Reference | Master Plan Revision | Work Item ID | Delivery Adapter Kind |`n|---|---|---|---|---|`n| <spec> | <plan> | <revision> | <work item> | <kind> |"
  $text = $text.Replace($table, "$table`n`n$table")
  [IO.File]::WriteAllText($path, $text, [Text.UTF8Encoding]::new($false))
} 'exactly one|duplicate|table'

Assert-FailsLike 'malformed Master Scope Context separator is rejected' {
  param($root)
  $path = Join-Path $root 'templates/migration/review-report.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $text = $text.Replace('|---|---|---|---|---|', '|===|===|===|===|===|')
  Set-Content -Encoding utf8 -LiteralPath $path -Value $text
} 'delimiter|separator|table'

$strictTableCases = @(
  [pscustomobject]@{
    Name = 'Master Scope Context'
    RelativePath = 'templates/migration/review-report.md'
    Lines = @(
      '| Master Spec Reference | Master Plan Reference | Master Plan Revision | Work Item ID | Delivery Adapter Kind |',
      '|---|---|---|---|---|',
      '| <spec> | <plan> | <revision> | <work item> | <kind> |'
    )
  }
  [pscustomobject]@{
    Name = 'Work Item and Master Plan Transition'
    RelativePath = 'templates/kb-entry.md'
    Lines = @(
      '| Work Item ID | Work Item Verdict | Master Plan Reference | Master Plan Revision | Transition | Terminal Evidence |',
      '|---|---|---|---|---|---|',
      '| <work item> | <complete or blocked> | <plan> | <revision> | <from -> to> | <artifact> |'
    )
  }
  [pscustomobject]@{
    Name = 'Scope Status Calculation'
    RelativePath = 'templates/kb-entry.md'
    Lines = @(
      '| Required Items Remaining | Next Eligible Item | Blocker | Dependency Graph State | Required Items Terminal-success | Architecture Conformance State | Selector Schema State | Terminal Scope Report | Calculated Scope Status | Calculation Evidence |',
      '|---|---|---|---|---|---|---|---|---|---|',
      '| <count and IDs> | <work item or none> | <blocker or none> | <valid / invalid> | <all-terminal-success / remaining> | <PASS / BLOCKED> | <PASS / BLOCKED> | <scope-terminal-report.md#evidence-index or not-applicable> | <planned / scope-in-progress / scope-blocked / scope-complete / scope-cancelled-approved> | <master-plan evidence; scope-complete requires all-required-terminal-evidence> |'
    )
  }
)
$strictLineEndings = @(
  [pscustomobject]@{ Name = 'LF'; Value = "`n" }
  [pscustomobject]@{ Name = 'CRLF'; Value = "`r`n" }
)
foreach ($tableCase in $strictTableCases) {
  foreach ($lineEnding in $strictLineEndings) {
    foreach ($mutationKind in @('duplicate', 'decoy', 'malformed')) {
      Assert-FailsLike "$($tableCase.Name) rejects $mutationKind table ($($lineEnding.Name))" {
        param($root)
        $path = Join-Path $root $tableCase.RelativePath
        $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
        $text = [regex]::Replace($text, '\r?\n', $lineEnding.Value)
        $table = $tableCase.Lines -join $lineEnding.Value
        $malformedLines = @($tableCase.Lines)
        $malformedLines[1] = $malformedLines[1].Replace('-', '=')
        $malformed = $malformedLines -join $lineEnding.Value
        $replacement = if ($mutationKind -ceq 'malformed') {
          $malformed
        }
        elseif ($mutationKind -ceq 'decoy') {
          $table + $lineEnding.Value + $lineEnding.Value + $malformed
        }
        else {
          $table + $lineEnding.Value + $lineEnding.Value + $table
        }
        if (-not $text.Contains($table)) { throw "Scenario setup could not find $($tableCase.Name) table" }
        $text = $text.Replace($table, $replacement)
        [IO.File]::WriteAllText($path, $text, [Text.UTF8Encoding]::new($false))
      } 'exactly one|delimiter|table'
    }
  }
}

Assert-FailsLike 'KB records work-item transition and scope queue evidence' {
  param($root)
  $path = Join-Path $root 'templates/kb-entry.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $text = $text.Replace('## Scope Status Calculation', '## Scope Summary')
  Set-Content -Encoding utf8 -LiteralPath $path -Value $text
} 'Scope Status Calculation|scope'

Assert-FailsLike 'KB never infers scope completion from one execution artifact' {
  param($root)
  $path = Join-Path $root 'skills/shared/knowledge-base/SKILL.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $text = $text.Replace('Never infer `scope-complete` from one execution artifact, one completed work item, or a successful attempt.', 'Infer `scope-complete` from one successful execution artifact.')
  Set-Content -Encoding utf8 -LiteralPath $path -Value $text
} 'scope-complete|execution artifact'

Assert-FailsLike 'KB rejects scope-complete while a required item remains' {
  param($root)
  Set-RenderedKbFixture $root '| 1: WORK-B | WORK-B | none | valid | remaining | PASS | PASS | not-applicable | scope-complete | implementation-report.md |'
} 'scope-complete|required item|remaining'

Assert-FailsLike 'KB rejects mixed schema and rendered scope rows' {
  param($root)
  $path = Join-Path $root 'templates/kb-entry.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $text = $text.Replace('<work item>', 'WORK-A')
  Set-Content -Encoding utf8 -LiteralPath $path -Value $text
} 'all-schema|all-rendered|mixed'

$invalidScopeCompleteRows = @(
  [pscustomobject]@{ Name = 'next item remains'; Row = '| none | WORK-B | none | valid | all-terminal-success | PASS | PASS | scope-terminal-report.md#evidence-index | scope-complete | master-plan.md;all-required-terminal-evidence |' }
  [pscustomobject]@{ Name = 'blocker remains'; Row = '| none | none | BLOCK-001 | valid | all-terminal-success | PASS | PASS | scope-terminal-report.md#evidence-index | scope-complete | master-plan.md;all-required-terminal-evidence |' }
  [pscustomobject]@{ Name = 'dependency graph invalid'; Row = '| none | none | none | invalid | all-terminal-success | PASS | PASS | scope-terminal-report.md#evidence-index | scope-complete | master-plan.md;all-required-terminal-evidence |' }
  [pscustomobject]@{ Name = 'required terminal state incomplete'; Row = '| none | none | none | valid | remaining | PASS | PASS | scope-terminal-report.md#evidence-index | scope-complete | master-plan.md;all-required-terminal-evidence |' }
  [pscustomobject]@{ Name = 'architecture blocked'; Row = '| none | none | none | valid | all-terminal-success | BLOCKED | PASS | scope-terminal-report.md#evidence-index | scope-complete | master-plan.md;all-required-terminal-evidence |' }
  [pscustomobject]@{ Name = 'selector blocked'; Row = '| none | none | none | valid | all-terminal-success | PASS | BLOCKED | scope-terminal-report.md#evidence-index | scope-complete | master-plan.md;all-required-terminal-evidence |' }
  [pscustomobject]@{ Name = 'terminal scope report missing'; Row = '| none | none | none | valid | all-terminal-success | PASS | PASS | implementation-report.md | scope-complete | master-plan.md;all-required-terminal-evidence |' }
  [pscustomobject]@{ Name = 'full evidence marker missing'; Row = '| none | none | none | valid | all-terminal-success | PASS | PASS | scope-terminal-report.md#evidence-index | scope-complete | implementation-report.md |' }
)
foreach ($invalidScopeComplete in $invalidScopeCompleteRows) {
  Assert-FailsLike "KB rejects scope-complete when $($invalidScopeComplete.Name)" {
    param($root)
    Set-RenderedKbFixture $root $invalidScopeComplete.Row
  } 'scope-complete requires'
}

Write-Output 'PASS: architecture review scenarios'

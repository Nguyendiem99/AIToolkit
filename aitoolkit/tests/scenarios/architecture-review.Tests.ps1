$ErrorActionPreference = 'Stop'

$toolkitRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$validatorPath = Join-Path $toolkitRoot 'tests/validation/architecture-review.validation.ps1'
$contractText = Get-Content -Raw -Encoding utf8 -LiteralPath (Join-Path $toolkitRoot 'contracts/target-structure-conformance.md')
$responsibilityContractText = Get-Content -Raw -Encoding utf8 -LiteralPath (Join-Path $toolkitRoot 'contracts/file-responsibility-conformance.md')
$codeMigrationSkillText = Get-Content -Raw -Encoding utf8 -LiteralPath (Join-Path $toolkitRoot 'skills/migration/code-migration/SKILL.md')
$aiReviewSkillText = Get-Content -Raw -Encoding utf8 -LiteralPath (Join-Path $toolkitRoot 'skills/shared/ai-review/SKILL.md')
$implementationTemplateText = Get-Content -Raw -Encoding utf8 -LiteralPath (Join-Path $toolkitRoot 'templates/migration/implementation-report.md')

function Require-Token([string]$Text, [string]$Token, [string]$Context) {
  if ($Text -notmatch [regex]::Escape($Token)) {
    $script:errors.Add("$Context missing: $Token")
  }
}

. $validatorPath
. (Join-Path $toolkitRoot 'tests/validation/responsibility-conformance.validation.ps1')

foreach ($languageMarkerContract in @(
  [pscustomobject]@{ Text = $responsibilityContractText; Token = '// arc:@responsibility RESP-*'; Context = 'responsibility contract slash-comment marker' },
  [pscustomobject]@{ Text = $responsibilityContractText; Token = '# arc:@responsibility RESP-*'; Context = 'responsibility contract hash-comment marker' },
  [pscustomobject]@{ Text = $responsibilityContractText; Token = '// arc:@ownership-begin RESP-*'; Context = 'responsibility contract slash ownership-range opener' },
  [pscustomobject]@{ Text = $responsibilityContractText; Token = '# arc:@ownership-end RESP-*'; Context = 'responsibility contract hash ownership-range closer' },
  [pscustomobject]@{ Text = $responsibilityContractText; Token = '// arc:route'; Context = 'responsibility contract production route marker' },
  [pscustomobject]@{ Text = $responsibilityContractText; Token = '# arc:scenario'; Context = 'responsibility contract verification scenario marker' },
  [pscustomobject]@{ Text = $codeMigrationSkillText; Token = 'language-valid semantic marker'; Context = 'code-migration producer guidance' },
  [pscustomobject]@{ Text = $aiReviewSkillText; Token = 'language-valid semantic marker'; Context = 'AI-review consumer guidance' },
  [pscustomobject]@{ Text = $implementationTemplateText; Token = 'language-valid semantic marker'; Context = 'implementation template producer guidance' },
  [pscustomobject]@{ Text = $codeMigrationSkillText; Token = '@ownership-begin RESP-*'; Context = 'code-migration ownership-range producer guidance' },
  [pscustomobject]@{ Text = $aiReviewSkillText; Token = '@ownership-begin'; Context = 'AI-review ownership-range consumer guidance' },
  [pscustomobject]@{ Text = $implementationTemplateText; Token = '@ownership-end RESP-*'; Context = 'implementation template ownership-range producer guidance' }
)) {
  if ($languageMarkerContract.Text.IndexOf($languageMarkerContract.Token, [StringComparison]::Ordinal) -lt 0) {
    throw "$($languageMarkerContract.Context) missing: $($languageMarkerContract.Token)"
  }
}
Write-Output 'PASS: producer, consumer, contract, and template define language-valid semantic marker encoding'

$canonicalReviewSkill = @'
# AI Review

## Architecture-first migration review gates

For migration, perform these gates in order:

1. Master scope and work-item alignment.
2. Project rule resolution.
3. Canonical selector validation.
4. Tree conformance from final inventory and source/diff evidence.
5. Responsibility conformance against planned responsibility evidence.
6. Verification ownership from final inventory and source/diff evidence.
7. Production activation-path validation.
8. Behavior, failure modes, security, performance, and tests.
9. Change hygiene.

The reviewer independently inspects the final inventory and task-base/final-tree source diff. Implementation self-attestation is not semantic PASS evidence. Missing master context, canonical selector, conformance matrix, exemplar, actual/planned tree evidence, responsibility review evidence, verification ownership evidence, or applicable production activation evidence records the matching verdict as `BLOCKED`, sets the overall verdict to `Reject`, and stops before reviewer dispatch and before behavior analysis. Rule Resolution remains an independent first severity gate and cannot be weakened by architecture ordering.

Require exactly one Architecture Conformance Verdict, exactly one Canonical Selector Verdict, exactly one Tree Conformance Verdict, exactly one Responsibility Conformance Verdict, exactly one Verification Ownership Verdict, and exactly one Production Activation-path Verdict. Any `BLOCKED` verdict makes the overall verdict `Reject`, independently of severity counts.

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
| Run ID | Master Spec Reference | Master Spec ID | Master Spec Revision | Master Plan Reference | Master Plan ID | Master Plan Revision | Work Item ID |
|---|---|---|---|---|---|---|---|
| <RUN-*> | <master spec reference> | <SPEC-*> | <revision> | <master plan reference> | <PLAN-*> | <revision> | <WORK-*> |

- Delivery Adapter Kind: <migration-unit | task | story | package | phase | milestone | none>
- Delivery Adapter Mode Constraint: <incremental/preserve-existing | greenfield/design-new>

## Task Provenance
| Task / Unit | Task-base SHA | Final-tree SHA | Source Artifact |
|---|---|---|---|
| <WORK-*> | <task-base SHA> | <final-tree SHA> | <immediate predecessor artifact path> |

Keep `Selected Migration Unit` only when `Delivery Adapter Kind` is `migration-unit`; otherwise omit it.

## Selected Migration Unit
| Migration Unit ID | Plan Reference | Approval Reference | Mode Constraint | Bootstrap Scope | Foundation Baseline ID | Foundation Baseline Reference | Foundation Baseline Approval Reference | Baseline Reference | Trace IDs |
|---|---|---|---|---|---|---|---|---|---|
| <UNIT-001> | <plan> | <approval> | <mode> | <scope> | <foundation ID> | <foundation reference> | <foundation approval> | <baseline> | <trace IDs> |

## Rule Resolution
- Rule Resolution Verdict: <RESOLVED | BLOCKED>

## Canonical Selector
- Canonical Selector Verdict: <PASS | BLOCKED>
- Evidence: <selector evidence>

## Architecture Conformance
- Architecture Conformance Verdict: <PASS | BLOCKED>
- Conformance Matrix Reference: <matrix>
- Exemplars: <exemplars>
- Actual File Tree vs Planned File Tree: <comparison>

## Responsibility Review Evidence
- Tree Conformance Verdict: <PASS | BLOCKED>
- Responsibility Conformance Verdict: <PASS | BLOCKED>
- Verification Ownership Verdict: <PASS | BLOCKED>
| Responsibility ID | Source/Diff Evidence | Planned Public Symbols | Actual Public Symbols | Planned Effects | Actual Effects | Verdict |
|---|---|---|---|---|---|---|

## Architecture Responsibility Handoff
| Responsibility Contract Version | Tree Conformance | Responsibility Conformance | Verification Ownership | Architecture Conformance State | Evidence References |
|---|---|---|---|---|---|
| 1 | <tree verdict> | <responsibility verdict> | <verification verdict> | <derived architecture state> | source-diff:<task-base SHA>..<final-tree SHA>#<WORK-*> |

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
- Change Hygiene Verdict: <PASS | BLOCKED>
| Evidence |
|---|

## Conclusion
- Critical count: <non-negative integer>
- Major count: <non-negative integer>
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

$canonicalImplementationReviewArtifact = @'
---
step_id: 10-code-migration
status: draft
result: complete
produced_at: 2026-08-21
responsibility_contract:
  version: 1
  applicability: required
---

## Master Scope Context
| Run ID | Master Spec Reference | Master Spec ID | Master Spec Revision | Master Plan Reference | Master Plan ID | Master Plan Revision | Work Item ID |
|---|---|---|---|---|---|---|---|
| RUN-ADMIN-001 | master-spec.md | SPEC-ADMIN-001 | 1 | master-plan.md | PLAN-ADMIN-001 | 1 | WORK-ADMIN |

## Canonical Adapter Evidence
| Work Item ID | Adapter Kind | External ID | Authority | Authority Revision | Approval Reference | Parent Selector | Acceptance | Trace IDs | Mode Constraint | Design Revision | Parent Work Item ID | Decomposition Decision Reference | Canonical Match |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| WORK-ADMIN | none | not-applicable | not-applicable | not-applicable | not-applicable | not-applicable | REQ-001; SC-001; completes within 2 seconds | REQ-001 | incremental/preserve-existing | DESIGN-ADMIN@1 | not-applicable | not-applicable | PASS |

## Actual File Responsibility Matrix
| Responsibility ID | Owner Path | Owner Symbol | Boundary Kind | Primary Responsibility | Owned Capability IDs | Trace IDs | Atomic Boundary ID | Public Symbols | External Effects | Target Exemplar | Exemplar Classification | Classification Authority | Classification Evidence | Architecture Authority | Co-location Policy | Co-location Evidence | Verification Owner References | Conformance | Deviation Reference | Actual Evidence |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| RESP-ADMIN | src/admin_route.source | AdminRoute | integration | compose admin route | CAP-ADMIN-ROUTE | REQ-001 | not-applicable | AdminRoute | route registration | lib/target_shell.dart#TargetShell | preferred | factual-discovery-evidence | inspection:lib/target_shell.dart:10-80 | target-exemplar | feature-local | production composition | VERIFY-OWNER-ADMIN | yes | not-applicable | diff:src/admin_route.source#AdminRoute |

## Actual Verification Ownership Matrix
| Verification Owner ID | Production Responsibility ID | Capability ID | Evidence Path | Evidence Symbol or Scenario | Evidence Kind | Verification Disposition | Production Binding Evidence | Decision Reference | Verdict | Deviation Reference | Actual Evidence |
|---|---|---|---|---|---|---|---|---|---|---|---|
| VERIFY-OWNER-ADMIN | RESP-ADMIN | CAP-ADMIN-ROUTE | test/admin_route_test.ps1 | AdminRouteContract | production-composition | required | invokes src/admin_route.source#AdminRoute | not-applicable | PASS | not-applicable | diff:test/admin_route_test.ps1#AdminRouteContract |

## Responsibility Owner References
| Work Item ID | Design Revision | Responsibility IDs | Shared Foundation IDs | Integration Responsibility IDs | Independent Boundary Evidence |
|---|---|---|---|---|---|
| WORK-ADMIN | DESIGN-ADMIN@1 | RESP-ADMIN | not-applicable | not-applicable | architecture-rules.md#RULE-001: independently implementable, reviewable, verifiable, and revertible |

## Architecture Responsibility Verdicts
| Responsibility Contract Version | Tree Conformance | Responsibility Conformance | Verification Ownership | Architecture Conformance State | Evidence References |
|---|---|---|---|---|---|
| 1 | PASS | PASS | PASS | PASS | design:DESIGN-ADMIN@1; diff:HEAD |

## Change Hygiene
| Task / Unit | File | File Kind | Edited Region / Symbol | Formatter Command | Unrelated Diff | Checkpoint History | Task-base SHA | Final-tree SHA |
|---|---|---|---|---|---|---|---|---|
| WORK-ADMIN | src/admin_route.source | new | AdminRoute | none | none | none | <TASK-BASE-SHA> | <FINAL-TREE-SHA> |

## Implementation Self-Attestation
- Architecture Conformance State: NOT_REVIEWED
'@

$canonicalIndependentReviewArtifact = @'
---
step_id: 11-ai-review
status: draft
result: complete
produced_at: 2026-08-21
responsibility_contract:
  version: 1
  applicability: required
---

## Master Scope Context
| Run ID | Master Spec Reference | Master Spec ID | Master Spec Revision | Master Plan Reference | Master Plan ID | Master Plan Revision | Work Item ID |
|---|---|---|---|---|---|---|---|
| RUN-ADMIN-001 | master-spec.md | SPEC-ADMIN-001 | 1 | master-plan.md | PLAN-ADMIN-001 | 1 | WORK-ADMIN |

- Delivery Adapter Kind: none
- Delivery Adapter Mode Constraint: incremental/preserve-existing

## Task Provenance
| Task / Unit | Task-base SHA | Final-tree SHA | Source Artifact |
|---|---|---|---|
| WORK-ADMIN | <TASK-BASE-SHA> | <FINAL-TREE-SHA> | implementation-report.md |

## Architecture Responsibility Handoff
| Responsibility Contract Version | Tree Conformance | Responsibility Conformance | Verification Ownership | Architecture Conformance State | Evidence References |
|---|---|---|---|---|---|
| 1 | PASS | PASS | PASS | PASS | source-diff:<TASK-BASE-SHA>..<FINAL-TREE-SHA>#WORK-ADMIN |

## Rule Resolution
- Rule Resolution Verdict: RESOLVED

## Canonical Selector
- Canonical Selector Verdict: PASS

## Architecture Conformance
- Architecture Conformance Verdict: PASS

## Responsibility Review Evidence
- Tree Conformance Verdict: PASS
- Responsibility Conformance Verdict: PASS
- Verification Ownership Verdict: PASS
| Responsibility ID | Source/Diff Evidence | Planned Public Symbols | Actual Public Symbols | Planned Effects | Actual Effects | Verdict |
|---|---|---|---|---|---|---|
| RESP-ADMIN | source:<FINAL-TREE-SHA>:src/admin_route.source#AdminRoute; diff:<TASK-BASE-SHA>..<FINAL-TREE-SHA>:src/admin_route.source#AdminRoute; source:<FINAL-TREE-SHA>:src/admin_route.source#VERIFY-OWNER-ADMIN; diff:<TASK-BASE-SHA>..<FINAL-TREE-SHA>:src/admin_route.source#VERIFY-OWNER-ADMIN | AdminRoute | AdminRoute | route registration | route registration | PASS |

## Production Activation Path
- Production Activation-path Verdict: NOT_APPLICABLE

## Behavior, Failure Modes, Security, Performance, and Tests
- Behavior Analysis State: COMPLETE

## Critical
| File:line | Issue | Proposed fix |
|---|---|---|
| none | none | none |

## Major
| File:line | Issue | Proposed fix |
|---|---|---|
| none | none | none |

## Change Hygiene
- Change Hygiene Verdict: PASS
| Task / Unit | Scope Evidence | Formatter Evidence | Unrelated Diff | Severity | Task-base SHA | Final-tree SHA |
|---|---|---|---|---|---|---|
| WORK-ADMIN | src/admin_route.source#AdminRoute | none | none | none | <TASK-BASE-SHA> | <FINAL-TREE-SHA> |

## Conclusion
- Critical count: 0
- Major count: 0
- Verdict: Approve
'@

$canonicalApprovedPlanArtifact = @'
---
artifact_type: migration-master-plan
master_plan_id: PLAN-ADMIN-001
master_spec_id: SPEC-ADMIN-001
master_spec_revision: 1
revision: 1
status: approved
produced_at: 2026-08-21
---

## Delivery Adapter Selection
| Work Item ID | Adapter Kind | External ID | Authority | Authority Revision | Approval Reference | Parent Selector | Acceptance | Trace IDs | Mode Constraint | Design Revision | Parent Work Item ID | Decomposition Decision Reference |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| WORK-ADMIN | none | not-applicable | not-applicable | not-applicable | not-applicable | not-applicable | REQ-001; SC-001; completes within 2 seconds | REQ-001 | incremental/preserve-existing | DESIGN-ADMIN@1 | not-applicable | not-applicable |

## Work Items
| Work Item ID | Title | Required | Dependencies | Plan Order | Acceptance | Trace IDs | Delivery Adapter | Status | Latest Attempt | Terminal Evidence | Approval Reference |
|---|---|---|---|---|---|---|---|---|---|---|---|
| WORK-ADMIN | Admin route | yes | none | 1 | REQ-001; SC-001; completes within 2 seconds | REQ-001 | none | in-progress | ATTEMPT-ADMIN-01 | none | approval:WORK-ADMIN |
'@

$canonicalDesignReviewArtifact = @'
---
step_id: 07-technical-design
status: approved
result: complete
produced_at: 2026-08-21
revision: DESIGN-ADMIN@1
responsibility_contract:
  version: 1
  applicability: required
---

## File Responsibility Matrix
| Responsibility ID | Owner Path | Owner Symbol | Boundary Kind | Primary Responsibility | Owned Capability IDs | Trace IDs | Atomic Boundary ID | Public Symbols | External Effects | Target Exemplar | Exemplar Classification | Classification Authority | Classification Evidence | Architecture Authority | Co-location Policy | Co-location Evidence | Verification Owner References | Conformance | Deviation Reference |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| RESP-ADMIN | src/admin_route.source | AdminRoute | integration | compose admin route | CAP-ADMIN-ROUTE | REQ-001 | not-applicable | AdminRoute | route registration | lib/target_shell.dart#TargetShell | preferred | factual-discovery-evidence | inspection:lib/target_shell.dart:10-80 | target-exemplar | feature-local | production composition | VERIFY-OWNER-ADMIN | yes | not-applicable |

## Verification Ownership Matrix
| Verification Owner ID | Production Responsibility ID | Capability ID | Evidence Path | Evidence Symbol or Scenario | Evidence Kind | Verification Disposition | Production Binding Evidence | Decision Reference | Verdict | Deviation Reference |
|---|---|---|---|---|---|---|---|---|---|---|
| VERIFY-OWNER-ADMIN | RESP-ADMIN | CAP-ADMIN-ROUTE | test/admin_route_test.ps1 | AdminRouteContract | production-composition | required | invokes src/admin_route.source#AdminRoute | not-applicable | PASS | not-applicable |
'@

function Invoke-PinnedSourceGit([string]$Root, [string[]]$Arguments) {
  $output = @(& git -C $Root @Arguments 2>&1)
  if ($LASTEXITCODE -ne 0) { throw "Pinned source git command failed: git -C $Root $($Arguments -join ' '): $($output -join [Environment]::NewLine)" }
  return ($output -join [Environment]::NewLine).Trim()
}

function New-PinnedSourceFixture([string]$Root, [bool]$IncrementalOwnerEdit = $false, [bool]$DeleteLegacyOwner = $false) {
  $sourceRoot = Join-Path $Root 'source'
  [void](New-Item -ItemType Directory -Force -Path (Join-Path $sourceRoot 'src'))
  [void](New-Item -ItemType Directory -Force -Path (Join-Path $sourceRoot 'test'))
  Invoke-PinnedSourceGit $sourceRoot @('init') | Out-Null
  Invoke-PinnedSourceGit $sourceRoot @('config', 'core.autocrlf', 'false') | Out-Null
  Invoke-PinnedSourceGit $sourceRoot @('config', 'user.email', 'fixtures@example.test') | Out-Null
  Invoke-PinnedSourceGit $sourceRoot @('config', 'user.name', 'AIToolkit fixture') | Out-Null
  Set-Content -Encoding utf8 -LiteralPath (Join-Path $sourceRoot 'README') -Value 'pinned source fixture'
  $verificationPath = Join-Path $sourceRoot 'test/admin_route_test.ps1'
  Set-Content -Encoding utf8 -LiteralPath $verificationPath -Value @'
@verification-scenario AdminRouteContract
@verification-owner VERIFY-OWNER-ADMIN
@production-responsibility RESP-ADMIN
@owned-capability CAP-ADMIN-ROUTE
@evidence-kind production-composition
@verification-disposition required
@production-binding src/admin_route.source#AdminRoute
@production-route AdminRoute -> AdminRouteProvider
scenario AdminRouteContract
'@
  Invoke-PinnedSourceGit $sourceRoot @('add', '--', 'README', 'test/admin_route_test.ps1') | Out-Null
  Invoke-PinnedSourceGit $sourceRoot @('commit', '-m', 'base source') | Out-Null
  $sourcePath = Join-Path $sourceRoot 'src/admin_route.source'
  $legacyPath = Join-Path $sourceRoot 'src/obsolete_route.source'
  if ($DeleteLegacyOwner) {
    Set-Content -Encoding utf8 -LiteralPath $legacyPath -Value @'
@responsibility RESP-OBSOLETE
@owner-symbol ObsoleteRoute
@public-symbol ObsoleteRoute
@owned-capability CAP-OBSOLETE-ROUTE
@effect route registration
@architecture-authority target-exemplar
@co-location-policy feature-local
@verification-owner VERIFY-OWNER-OBSOLETE
@ownership-begin RESP-OBSOLETE
route ObsoleteRoute -> ObsoleteRouteProvider
@ownership-end RESP-OBSOLETE
'@
    Invoke-PinnedSourceGit $sourceRoot @('add', '--', 'src/obsolete_route.source') | Out-Null
    Invoke-PinnedSourceGit $sourceRoot @('commit', '-m', 'legacy obsolete route') | Out-Null
  }
  $sourceText = @'
@responsibility RESP-ADMIN
@owner-symbol AdminRoute
@public-symbol AdminRoute
@owned-capability CAP-ADMIN-ROUTE
@effect route registration
@architecture-authority target-exemplar
@co-location-policy feature-local
@verification-owner VERIFY-OWNER-ADMIN
@ownership-begin RESP-ADMIN
route AdminRoute -> AdminRouteProvider
@ownership-end RESP-ADMIN
'@
  if ($IncrementalOwnerEdit) {
    Set-Content -Encoding utf8 -LiteralPath $sourcePath -Value $sourceText
    Invoke-PinnedSourceGit $sourceRoot @('add', '--', 'src/admin_route.source') | Out-Null
    Invoke-PinnedSourceGit $sourceRoot @('commit', '-m', 'existing admin route') | Out-Null
    $taskBaseSha = Invoke-PinnedSourceGit $sourceRoot @('rev-parse', 'HEAD')
    $sourceText = $sourceText.Replace('AdminRouteProvider', 'UpdatedAdminRouteProvider')
    $verificationText = (Get-Content -Raw -Encoding utf8 -LiteralPath $verificationPath).Replace('@production-route AdminRoute -> AdminRouteProvider', '@production-route AdminRoute -> UpdatedAdminRouteProvider')
    Set-Content -Encoding utf8 -LiteralPath $verificationPath -Value $verificationText
    if ($sourceText -notmatch 'UpdatedAdminRouteProvider') { throw 'Incremental source fixture update failed' }
  }
  else {
    $taskBaseSha = Invoke-PinnedSourceGit $sourceRoot @('rev-parse', 'HEAD')
  }
  Set-Content -Encoding utf8 -LiteralPath $sourcePath -Value $sourceText
  if ($DeleteLegacyOwner) {
    if (-not (Test-Path -LiteralPath $legacyPath -PathType Leaf)) { throw 'Deleted owner source fixture is missing its legacy path' }
    Remove-Item -LiteralPath $legacyPath -Force
    if (Test-Path -LiteralPath $legacyPath) { throw 'Deleted owner source fixture removal failed' }
    Invoke-PinnedSourceGit $sourceRoot @('add', '--all', '--', 'src', 'test') | Out-Null
  }
  else {
    Invoke-PinnedSourceGit $sourceRoot @('add', '--', 'src/admin_route.source', 'test/admin_route_test.ps1') | Out-Null
  }
  Invoke-PinnedSourceGit $sourceRoot @('commit', '-m', $(if ($IncrementalOwnerEdit) { 'incremental admin route provider' } else { 'planned admin route' })) | Out-Null
  $finalTreeSha = Invoke-PinnedSourceGit $sourceRoot @('rev-parse', 'HEAD')
  return [pscustomobject]@{ Root = $sourceRoot; TaskBaseSha = $taskBaseSha; FinalTreeSha = $finalTreeSha }
}

function Write-PinnedReviewProvenance([string]$Root, [object]$PinnedSource) {
  Set-Content -Encoding utf8 -LiteralPath (Join-Path $Root 'artifacts/review-provenance.md') -Value @"
Source Root: $($PinnedSource.Root)
Task-base SHA: $($PinnedSource.TaskBaseSha)
Final-tree SHA: $($PinnedSource.FinalTreeSha)
"@
  $reviewPath = Join-Path $Root 'artifacts/review-report.md'
  $reviewText = Get-Content -Raw -Encoding utf8 -LiteralPath $reviewPath
  $reviewText = $reviewText.Replace('<TASK-BASE-SHA>', $PinnedSource.TaskBaseSha).Replace('<FINAL-TREE-SHA>', $PinnedSource.FinalTreeSha)
  if ($reviewText -match '<(?:TASK-BASE|FINAL-TREE)-SHA>') { throw 'Pinned review evidence fixture replacement failed' }
  Set-Content -Encoding utf8 -LiteralPath $reviewPath -Value $reviewText
  $implementationPath = Join-Path $Root 'artifacts/implementation-report.md'
  $implementationText = Get-Content -Raw -Encoding utf8 -LiteralPath $implementationPath
  $implementationText = $implementationText.Replace('<TASK-BASE-SHA>', $PinnedSource.TaskBaseSha).Replace('<FINAL-TREE-SHA>', $PinnedSource.FinalTreeSha)
  if ($implementationText -match '<(?:TASK-BASE|FINAL-TREE)-SHA>') { throw 'Pinned implementation provenance fixture replacement failed' }
  Set-Content -Encoding utf8 -LiteralPath $implementationPath -Value $implementationText
}

function Sync-ReviewChangeHygieneRows([string]$Root) {
  $implementationPath = Join-Path $Root 'artifacts/implementation-report.md'
  $implementation = Get-Content -Raw -Encoding utf8 -LiteralPath $implementationPath
  $implementationSection = [regex]::Match($implementation, '(?ms)^## Change Hygiene\s*\r?\n(?<body>.*?)(?=^## )')
  if (-not $implementationSection.Success) { throw 'Implementation Change Hygiene section is missing for review synchronization' }
  $implementationRows = @($implementationSection.Groups['body'].Value -split '\r?\n' | Where-Object { $_ -cmatch '^\| (?:WORK|UNIT)-' })
  if ($implementationRows.Count -eq 0) { throw 'Implementation Change Hygiene data rows are missing for review synchronization' }
  $reviewRows = [Collections.Generic.List[string]]::new()
  foreach ($implementationRow in $implementationRows) {
    $cells = @($implementationRow.Trim().Substring(1, $implementationRow.Trim().Length - 2).Split('|') | ForEach-Object { $_.Trim() })
    if ($cells.Count -ne 9) { throw "Implementation Change Hygiene row is malformed: $implementationRow" }
    $severity = if ($cells[5] -ceq 'none') { 'none' } else { 'Major' }
    $reviewRows.Add("| $($cells[0]) | $($cells[1])#$($cells[3]) | $($cells[4]) | $($cells[5]) | $severity | $($cells[7]) | $($cells[8]) |")
  }
  $reviewPath = Join-Path $Root 'artifacts/review-report.md'
  $review = Get-Content -Raw -Encoding utf8 -LiteralPath $reviewPath
  $rowEnvelopePattern = '(?ms)(^## Change Hygiene\s*\r?\n.*?^\|---\|---\|---\|---\|---\|---\|---\|\s*\r?\n)(?:^\|[^\r\n]+\|\s*\r?\n)*'
  if (-not [regex]::IsMatch($review, $rowEnvelopePattern)) { throw 'Review Change Hygiene row envelope is missing for synchronization' }
  $updatedReview = [regex]::Replace($review, $rowEnvelopePattern, { param($match) $match.Groups[1].Value + (($reviewRows.ToArray() -join "`n") + "`n") }, 1)
  Set-Content -Encoding utf8 -LiteralPath $reviewPath -Value $updatedReview
}

function New-ArchitectureReviewFixture {
  param([scriptblock]$Mutation, [bool]$IncludeIndependentReviewEvidence = $false, [bool]$IncrementalOwnerEdit = $false, [bool]$DeleteLegacyOwner = $false)

  $root = Join-Path ([IO.Path]::GetTempPath()) ('aitoolkit-architecture-review-' + [guid]::NewGuid().ToString('N'))
  foreach ($relativeDirectory in @('artifacts', 'contracts', 'skills/shared/ai-review', 'skills/shared/knowledge-base', 'templates/migration', 'templates')) {
    [void](New-Item -ItemType Directory -Force -Path (Join-Path $root $relativeDirectory))
  }
  Set-Content -Encoding utf8 -LiteralPath (Join-Path $root 'contracts/target-structure-conformance.md') -Value $contractText
  Set-Content -Encoding utf8 -LiteralPath (Join-Path $root 'contracts/file-responsibility-conformance.md') -Value $responsibilityContractText
  Set-Content -Encoding utf8 -LiteralPath (Join-Path $root 'skills/shared/ai-review/SKILL.md') -Value $canonicalReviewSkill
  Set-Content -Encoding utf8 -LiteralPath (Join-Path $root 'skills/shared/knowledge-base/SKILL.md') -Value $canonicalKnowledgeSkill
  Set-Content -Encoding utf8 -LiteralPath (Join-Path $root 'templates/migration/review-report.md') -Value $canonicalReviewTemplate
  Set-Content -Encoding utf8 -LiteralPath (Join-Path $root 'templates/kb-entry.md') -Value $canonicalKbTemplate
  if ($IncludeIndependentReviewEvidence) {
    Set-Content -Encoding utf8 -LiteralPath (Join-Path $root 'artifacts/implementation-report.md') -Value $canonicalImplementationReviewArtifact
    Set-Content -Encoding utf8 -LiteralPath (Join-Path $root 'artifacts/review-report.md') -Value $canonicalIndependentReviewArtifact
    Set-Content -Encoding utf8 -LiteralPath (Join-Path $root 'artifacts/design-report.md') -Value $canonicalDesignReviewArtifact
    Set-Content -Encoding utf8 -LiteralPath (Join-Path $root 'artifacts/master-plan.md') -Value $canonicalApprovedPlanArtifact
    $pinnedSource = New-PinnedSourceFixture $root $IncrementalOwnerEdit $DeleteLegacyOwner
    Write-PinnedReviewProvenance $root $pinnedSource
    if ($IncrementalOwnerEdit) {
      $implementationPath = Join-Path $root 'artifacts/implementation-report.md'
      $implementation = Get-Content -Raw -Encoding utf8 -LiteralPath $implementationPath
      $sourceRows = @($implementation -split '\r?\n' | Where-Object { $_ -cmatch '^\| WORK-ADMIN \| src/admin_route\.source \|' })
      if ($sourceRows.Count -ne 1) { throw 'Incremental Change Hygiene source row is missing or duplicated' }
      $updatedSourceRow = $sourceRows[0].Replace('| new |', '| existing |')
      $verificationRow = "| WORK-ADMIN | test/admin_route_test.ps1 | existing | AdminRouteContract | none | none | none | $($pinnedSource.TaskBaseSha) | $($pinnedSource.FinalTreeSha) |"
      $implementation = $implementation.Replace($sourceRows[0], "$updatedSourceRow`n$verificationRow")
      Set-Content -Encoding utf8 -LiteralPath $implementationPath -Value $implementation
      Sync-ReviewChangeHygieneRows $root
    }
  }
  if ($null -ne $Mutation) {
    $mutationPaths = [Collections.Generic.List[string]]::new()
    @(
      'skills/shared/ai-review/SKILL.md',
      'skills/shared/knowledge-base/SKILL.md',
      'templates/migration/review-report.md',
      'templates/kb-entry.md'
    ) | ForEach-Object { $mutationPaths.Add($_) }
    if ($IncludeIndependentReviewEvidence) {
      @('artifacts/design-report.md', 'artifacts/implementation-report.md', 'artifacts/review-report.md', 'artifacts/master-plan.md', 'artifacts/review-provenance.md') | ForEach-Object { $mutationPaths.Add($_) }
    }
    $beforeMutation = [ordered]@{}
    foreach ($relativePath in $mutationPaths) {
      $sourceText = Get-Content -Raw -Encoding utf8 -LiteralPath (Join-Path $root $relativePath)
      $beforeMutation[$relativePath] = [regex]::Replace($sourceText, '\r\n?|\n', "`n")
    }
    & $Mutation $root
    $changedPaths = @($mutationPaths | Where-Object {
      $mutatedText = Get-Content -Raw -Encoding utf8 -LiteralPath (Join-Path $root $_)
      ([regex]::Replace($mutatedText, '\r\n?|\n', "`n")) -cne $beforeMutation[$_]
    })
    if ($changedPaths.Count -eq 0) {
      throw 'Scenario mutation was a silent no-op; fixture text must actually change'
    }
  }
  return $root
}

function Invoke-ArchitectureReviewCase {
  param([scriptblock]$Mutation, [bool]$IncludeIndependentReviewEvidence = $false, [bool]$IncrementalOwnerEdit = $false, [bool]$DeleteLegacyOwner = $false)

  $root = New-ArchitectureReviewFixture -Mutation $Mutation -IncludeIndependentReviewEvidence $IncludeIndependentReviewEvidence -IncrementalOwnerEdit $IncrementalOwnerEdit -DeleteLegacyOwner $DeleteLegacyOwner
  try {
    $script:errors = [Collections.Generic.List[string]]::new()
    Test-ArchitectureReview $root $contractText
    return @($script:errors)
  }
  finally {
    Remove-Item -LiteralPath $root -Recurse -Force
  }
}

function Assert-Pass([string]$Name, [scriptblock]$Mutation, [bool]$IncludeIndependentReviewEvidence = $false, [bool]$IncrementalOwnerEdit = $false, [bool]$DeleteLegacyOwner = $false) {
  $caseErrors = @(Invoke-ArchitectureReviewCase -Mutation $Mutation -IncludeIndependentReviewEvidence $IncludeIndependentReviewEvidence -IncrementalOwnerEdit $IncrementalOwnerEdit -DeleteLegacyOwner $DeleteLegacyOwner)
  if ($caseErrors.Count -gt 0) {
    throw "$Name expected PASS but failed: $($caseErrors -join '; ')"
  }
  Write-Output "PASS: $Name"
}

function Assert-FailsLike([string]$Name, [scriptblock]$Mutation, [string]$Pattern, [bool]$IncludeIndependentReviewEvidence = $false, [bool]$IncrementalOwnerEdit = $false, [bool]$DeleteLegacyOwner = $false) {
  $caseErrors = @(Invoke-ArchitectureReviewCase -Mutation $Mutation -IncludeIndependentReviewEvidence $IncludeIndependentReviewEvidence -IncrementalOwnerEdit $IncrementalOwnerEdit -DeleteLegacyOwner $DeleteLegacyOwner)
  if ($caseErrors.Count -eq 0) { throw "$Name expected failure but passed" }
  if (($caseErrors -join [Environment]::NewLine) -notmatch $Pattern) {
    throw "$Name failed for the wrong reason: $($caseErrors -join '; ')"
  }
  Write-Output "PASS: $Name"
}

function Set-RenderedReviewFixture([string]$Root, [string]$AdapterKind, [bool]$KeepSelectedUnit) {
  $path = Join-Path $Root 'templates/migration/review-report.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $text = $text.Replace('| <RUN-*> | <master spec reference> | <SPEC-*> | <revision> | <master plan reference> | <PLAN-*> | <revision> | <WORK-*> |', '| RUN-ADMIN-001 | master-spec.md | SPEC-ADMIN-001 | 1 | master-plan.md | PLAN-ADMIN-001 | 1 | WORK-ADMIN-A |')
  $text = $text.Replace('<migration-unit | task | story | package | phase | milestone | none>', $AdapterKind)
  $text = $text.Replace('<RESOLVED | BLOCKED>', 'RESOLVED')
  foreach ($index in 1..6) {
    $verdictIndex = $text.IndexOf('<PASS | BLOCKED>', [StringComparison]::Ordinal)
    if ($verdictIndex -lt 0) { throw "Rendered review fixture cannot find PASS/BLOCKED schema value $index" }
    $text = $text.Remove($verdictIndex, '<PASS | BLOCKED>'.Length).Insert($verdictIndex, 'PASS')
  }
  $activation = if ($AdapterKind -ceq 'none') { 'NOT_APPLICABLE' } else { 'PASS' }
  $text = $text.Replace('<PASS | BLOCKED | NOT_APPLICABLE>', $activation)
  $text = $text.Replace('<NOT_RUN | COMPLETE>', 'COMPLETE')
  $text = $text.Replace('<non-negative integer>', '0')
  $text = $text.Replace('<Approve | Approve-with-fixes | Reject>', 'Approve')
  $text = $text.Replace('| 1 | <tree verdict> | <responsibility verdict> | <verification verdict> | <derived architecture state> | source-diff:<task-base SHA>..<final-tree SHA>#<WORK-*> |', '| 1 | PASS | PASS | PASS | PASS | source-diff:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa..bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb#WORK-ADMIN-A |')
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

function Set-ArtifactLineEndings([string]$Root, [string]$RelativePath, [string]$NewLine, [string]$CaseName) {
  $path = Join-Path $Root $RelativePath
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $updated = [regex]::Replace($text, '\r\n|\n|\r', $NewLine)
  [IO.File]::WriteAllText($path, $updated, [Text.UTF8Encoding]::new($false))
  $written = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  if ($NewLine -ceq "`n" -and $written -match '\r\n') { throw "$CaseName fixture did not write LF line endings" }
  if ($NewLine -ceq "`r`n" -and $written -match '(?<!\r)\n') { throw "$CaseName fixture did not write CRLF line endings" }
}

function Add-LineEndingProbe([string]$Root, [string]$NewLine, [string]$CaseName) {
  $path = Join-Path $Root 'artifacts/review-provenance.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $updated = $text.TrimEnd([char[]]@("`r", "`n")) + $NewLine + "Line-ending fixture: $CaseName" + $NewLine
  if ($updated -ceq $text) { throw "$CaseName line-ending probe was a silent no-op" }
  [IO.File]::WriteAllText($path, $updated, [Text.UTF8Encoding]::new($false))
}

function Approve-DeletedOwner([string]$Root) {
  $provenance = Get-Content -Raw -Encoding utf8 -LiteralPath (Join-Path $Root 'artifacts/review-provenance.md')
  $taskBaseSha = [regex]::Match($provenance, '(?im)^Task-base SHA:[ \t]*(?<value>[0-9a-f]{40})[ \t]*\r?$').Groups['value'].Value
  $finalTreeSha = [regex]::Match($provenance, '(?im)^Final-tree SHA:[ \t]*(?<value>[0-9a-f]{40})[ \t]*\r?$').Groups['value'].Value

  $designPath = Join-Path $Root 'artifacts/design-report.md'
  $design = Get-Content -Raw -Encoding utf8 -LiteralPath $designPath
  $designAddition = @'

## Approved Structural Deviations

| Deviation Reference | Concern | Conflict Reference | Resolved Decision | Tech Lead Approval |
|---|---|---|---|---|
| DEV-OBSOLETE-REMOVAL | routing and lifecycle | CONFLICT-OBSOLETE-REMOVAL | resolved:DECISION-OBSOLETE-REMOVAL: remove responsibility=RESP-OBSOLETE; owner=src/obsolete_route.source#ObsoleteRoute; public-symbols=ObsoleteRoute; capabilities=CAP-OBSOLETE-ROUTE; effects=route registration; architecture-authority=target-exemplar; co-location-policy=feature-local; verification-owners=VERIFY-OWNER-OBSOLETE; routes=ObsoleteRoute; providers=ObsoleteRouteProvider | approval:TECH-LEAD-OBSOLETE-REMOVAL |
'@
  $updatedDesign = $design.TrimEnd() + $designAddition
  if ($updatedDesign -ceq $design) { throw 'Approved deleted owner design fixture replacement failed' }
  Set-Content -Encoding utf8 -LiteralPath $designPath -Value $updatedDesign

  $implementationPath = Join-Path $Root 'artifacts/implementation-report.md'
  $implementation = Get-Content -Raw -Encoding utf8 -LiteralPath $implementationPath
  $deletionCheckpoint = "source:${taskBaseSha}:src/obsolete_route.source; diff:${taskBaseSha}..${finalTreeSha}:src/obsolete_route.source"
  $implementationRow = "| WORK-ADMIN | src/obsolete_route.source | deleted | ObsoleteRoute | none | none | $deletionCheckpoint | $taskBaseSha | $finalTreeSha |"
  $implementationAnchorRows = @($implementation -split '\r?\n' | Where-Object { $_ -cmatch '^\| WORK-ADMIN \| src/admin_route\.source \|' })
  if ($implementationAnchorRows.Count -ne 1) { throw 'Approved deleted owner implementation fixture anchor is missing or duplicated' }
  $updatedImplementation = $implementation.Replace($implementationAnchorRows[0], "$($implementationAnchorRows[0])`n$implementationRow")
  if ($updatedImplementation -ceq $implementation) { throw 'Approved deleted owner implementation fixture replacement failed' }
  Set-Content -Encoding utf8 -LiteralPath $implementationPath -Value $updatedImplementation

  $reviewPath = Join-Path $Root 'artifacts/review-report.md'
  $review = Get-Content -Raw -Encoding utf8 -LiteralPath $reviewPath
  $deletedEvidence = "source:${taskBaseSha}:src/obsolete_route.source#ObsoleteRoute; diff:${taskBaseSha}..${finalTreeSha}:src/obsolete_route.source#ObsoleteRoute; source:${taskBaseSha}:src/obsolete_route.source#VERIFY-OWNER-OBSOLETE; diff:${taskBaseSha}..${finalTreeSha}:src/obsolete_route.source#VERIFY-OWNER-OBSOLETE"
  $reviewRow = "| RESP-OBSOLETE | $deletedEvidence | ObsoleteRoute | removed | route registration | removed | PASS |"
  $reviewAnchorRows = @($review -split '\r?\n' | Where-Object { $_ -cmatch '^\| RESP-ADMIN \|' })
  if ($reviewAnchorRows.Count -ne 1) { throw 'Approved deleted owner review fixture anchor is missing or duplicated' }
  $updatedReview = $review.Replace($reviewAnchorRows[0], "$($reviewAnchorRows[0])`n$reviewRow")
  if ($updatedReview -ceq $review) { throw 'Approved deleted owner review fixture replacement failed' }
  Set-Content -Encoding utf8 -LiteralPath $reviewPath -Value $updatedReview
  Sync-ReviewChangeHygieneRows $Root
}

function Add-SourceSymbolEvidence([string]$Root, [string]$Symbol, [string]$ResponsibilityId) {
  $provenancePath = Join-Path $Root 'artifacts/review-provenance.md'
  $provenance = Get-Content -Raw -Encoding utf8 -LiteralPath $provenancePath
  $sourceRoot = [regex]::Match($provenance, '(?m)^Source Root:\s*(?<value>.+)$').Groups['value'].Value.Trim()
  $taskBaseSha = [regex]::Match($provenance, '(?im)^Task-base SHA:[ \t]*(?<value>[0-9a-f]{40})[ \t]*\r?$').Groups['value'].Value
  $previousFinalTreeSha = [regex]::Match($provenance, '(?im)^Final-tree SHA:[ \t]*(?<value>[0-9a-f]{40})[ \t]*\r?$').Groups['value'].Value
  $sourcePath = Join-Path $sourceRoot 'src/admin_route.source'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $sourcePath
  $updated = $text.TrimEnd() + "`n@responsibility $ResponsibilityId`n@owner-symbol $Symbol`n@public-symbol $Symbol`n@owned-capability CAP-UNPLANNED`n@effect route registration`n@architecture-authority target-exemplar`n@co-location-policy feature-local`n@verification-owner VERIFY-OWNER-UNPLANNED`n@ownership-begin $ResponsibilityId`nroute $Symbol -> FactoryResetProvider`n@ownership-end $ResponsibilityId`n"
  if ($updated -ceq $text) { throw 'Source symbol evidence fixture replacement failed' }
  Set-Content -Encoding utf8 -LiteralPath $sourcePath -Value $updated
  Invoke-PinnedSourceGit $sourceRoot @('add', '--', 'src/admin_route.source') | Out-Null
  Invoke-PinnedSourceGit $sourceRoot @('commit', '-m', 'unplanned factory reset route') | Out-Null
  $finalTreeSha = Invoke-PinnedSourceGit $sourceRoot @('rev-parse', 'HEAD')
  $reviewPath = Join-Path $Root 'artifacts/review-report.md'
  $reviewText = Get-Content -Raw -Encoding utf8 -LiteralPath $reviewPath
  $reviewUpdated = $reviewText.Replace($previousFinalTreeSha, $finalTreeSha)
  if ($reviewUpdated -ceq $reviewText) { throw 'Pinned final-tree evidence update failed' }
  Set-Content -Encoding utf8 -LiteralPath $reviewPath -Value $reviewUpdated
  $implementationPath = Join-Path $Root 'artifacts/implementation-report.md'
  $implementationText = Get-Content -Raw -Encoding utf8 -LiteralPath $implementationPath
  $updatedImplementation = $implementationText.Replace($previousFinalTreeSha, $finalTreeSha)
  if ($updatedImplementation -ceq $implementationText) { throw 'Pinned implementation final-tree update failed' }
  Set-Content -Encoding utf8 -LiteralPath $implementationPath -Value $updatedImplementation
  Set-Content -Encoding utf8 -LiteralPath $provenancePath -Value @"
Source Root: $sourceRoot
Task-base SHA: $taskBaseSha
Final-tree SHA: $finalTreeSha
"@
}

function Add-MarkerlessProductionPath([string]$Root) {
  $provenancePath = Join-Path $Root 'artifacts/review-provenance.md'
  $provenance = Get-Content -Raw -Encoding utf8 -LiteralPath $provenancePath
  $sourceRoot = [regex]::Match($provenance, '(?m)^Source Root:\s*(?<value>.+)$').Groups['value'].Value.Trim()
  $taskBaseSha = [regex]::Match($provenance, '(?im)^Task-base SHA:[ \t]*(?<value>[0-9a-f]{40})[ \t]*\r?$').Groups['value'].Value
  $previousFinalTreeSha = [regex]::Match($provenance, '(?im)^Final-tree SHA:[ \t]*(?<value>[0-9a-f]{40})[ \t]*\r?$').Groups['value'].Value
  Set-Content -Encoding utf8 -LiteralPath (Join-Path $sourceRoot 'src/markerless_route.source') -Value "route MarkerlessRoute -> MarkerlessProvider`n"
  Invoke-PinnedSourceGit $sourceRoot @('add', '--', 'src/markerless_route.source') | Out-Null
  Invoke-PinnedSourceGit $sourceRoot @('commit', '-m', 'markerless production route') | Out-Null
  $finalTreeSha = Invoke-PinnedSourceGit $sourceRoot @('rev-parse', 'HEAD')

  $implementationPath = Join-Path $Root 'artifacts/implementation-report.md'
  $implementation = (Get-Content -Raw -Encoding utf8 -LiteralPath $implementationPath).Replace($previousFinalTreeSha, $finalTreeSha)
  $anchorRows = @($implementation -split '\r?\n' | Where-Object { $_ -cmatch '^\| WORK-ADMIN \| src/admin_route\.source \|' })
  if ($anchorRows.Count -ne 1) { throw 'Markerless production Change Hygiene anchor is missing or duplicated' }
  $markerlessRow = "| WORK-ADMIN | src/markerless_route.source | new | MarkerlessRoute | none | none | none | $taskBaseSha | $finalTreeSha |"
  $implementation = $implementation.Replace($anchorRows[0], "$($anchorRows[0])`n$markerlessRow")
  Set-Content -Encoding utf8 -LiteralPath $implementationPath -Value $implementation

  $reviewPath = Join-Path $Root 'artifacts/review-report.md'
  $review = (Get-Content -Raw -Encoding utf8 -LiteralPath $reviewPath).Replace($previousFinalTreeSha, $finalTreeSha)
  Set-Content -Encoding utf8 -LiteralPath $reviewPath -Value $review
  Sync-ReviewChangeHygieneRows $Root
  Set-Content -Encoding utf8 -LiteralPath $provenancePath -Value "Source Root: $sourceRoot`nTask-base SHA: $taskBaseSha`nFinal-tree SHA: $finalTreeSha`n"
}

function Add-DeletedNonOwnerPath([string]$Root, [bool]$ValidCheckpoint) {
  $provenancePath = Join-Path $Root 'artifacts/review-provenance.md'
  $provenance = Get-Content -Raw -Encoding utf8 -LiteralPath $provenancePath
  $sourceRoot = [regex]::Match($provenance, '(?m)^Source Root:\s*(?<value>.+)$').Groups['value'].Value.Trim()
  $taskBaseSha = [regex]::Match($provenance, '(?im)^Task-base SHA:[ \t]*(?<value>[0-9a-f]{40})[ \t]*\r?$').Groups['value'].Value
  $previousFinalTreeSha = [regex]::Match($provenance, '(?im)^Final-tree SHA:[ \t]*(?<value>[0-9a-f]{40})[ \t]*\r?$').Groups['value'].Value
  Remove-Item -LiteralPath (Join-Path $sourceRoot 'README') -Force
  Invoke-PinnedSourceGit $sourceRoot @('add', '--all', '--', 'README') | Out-Null
  Invoke-PinnedSourceGit $sourceRoot @('commit', '-m', 'delete non-owner readme') | Out-Null
  $finalTreeSha = Invoke-PinnedSourceGit $sourceRoot @('rev-parse', 'HEAD')
  $checkpoint = if ($ValidCheckpoint) { "source:${taskBaseSha}:README; diff:${taskBaseSha}..${finalTreeSha}:README" } else { 'none' }
  $implementationPath = Join-Path $Root 'artifacts/implementation-report.md'
  $implementation = (Get-Content -Raw -Encoding utf8 -LiteralPath $implementationPath).Replace($previousFinalTreeSha, $finalTreeSha)
  $anchorRows = @($implementation -split '\r?\n' | Where-Object { $_ -cmatch '^\| WORK-ADMIN \| src/admin_route\.source \|' })
  if ($anchorRows.Count -ne 1) { throw 'Deleted non-owner Change Hygiene anchor is missing or duplicated' }
  $deletedRow = "| WORK-ADMIN | README | deleted | README | none | none | $checkpoint | $taskBaseSha | $finalTreeSha |"
  Set-Content -Encoding utf8 -LiteralPath $implementationPath -Value $implementation.Replace($anchorRows[0], "$($anchorRows[0])`n$deletedRow")
  $reviewPath = Join-Path $Root 'artifacts/review-report.md'
  $review = (Get-Content -Raw -Encoding utf8 -LiteralPath $reviewPath).Replace($previousFinalTreeSha, $finalTreeSha)
  Set-Content -Encoding utf8 -LiteralPath $reviewPath -Value $review
  Sync-ReviewChangeHygieneRows $Root
  Set-Content -Encoding utf8 -LiteralPath $provenancePath -Value "Source Root: $sourceRoot`nTask-base SHA: $taskBaseSha`nFinal-tree SHA: $finalTreeSha`n"
}

function Rename-ProductionOwner(
  [string]$Root,
  [bool]$ExplicitMapping,
  [string]$DestinationPath = 'docs/admin_route.source'
) {
  $provenancePath = Join-Path $Root 'artifacts/review-provenance.md'
  $provenance = Get-Content -Raw -Encoding utf8 -LiteralPath $provenancePath
  $sourceRoot = [regex]::Match($provenance, '(?m)^Source Root:\s*(?<value>.+)$').Groups['value'].Value.Trim()
  $taskBaseSha = [regex]::Match($provenance, '(?im)^Task-base SHA:[ \t]*(?<value>[0-9a-f]{40})[ \t]*\r?$').Groups['value'].Value
  $previousFinalTreeSha = [regex]::Match($provenance, '(?im)^Final-tree SHA:[ \t]*(?<value>[0-9a-f]{40})[ \t]*\r?$').Groups['value'].Value
  $destinationFullPath = Join-Path $sourceRoot $DestinationPath
  [void](New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destinationFullPath))
  Move-Item -LiteralPath (Join-Path $sourceRoot 'src/admin_route.source') -Destination $destinationFullPath
  $verificationPath = Join-Path $sourceRoot 'test/admin_route_test.ps1'
  $verificationText = (Get-Content -Raw -Encoding utf8 -LiteralPath $verificationPath).Replace('@production-binding src/admin_route.source#AdminRoute', "@production-binding ${DestinationPath}#AdminRoute")
  Set-Content -Encoding utf8 -LiteralPath $verificationPath -Value $verificationText
  Invoke-PinnedSourceGit $sourceRoot @('add', '--all', '--', 'src/admin_route.source', $DestinationPath, 'test/admin_route_test.ps1') | Out-Null
  Invoke-PinnedSourceGit $sourceRoot @('commit', '-m', 'rename production owner to docs') | Out-Null
  $finalTreeSha = Invoke-PinnedSourceGit $sourceRoot @('rev-parse', 'HEAD')
  foreach ($relativePath in @('artifacts/design-report.md', 'artifacts/implementation-report.md', 'artifacts/review-report.md')) {
    $path = Join-Path $Root $relativePath
    $text = (Get-Content -Raw -Encoding utf8 -LiteralPath $path).Replace($previousFinalTreeSha, $finalTreeSha).Replace('src/admin_route.source', $DestinationPath)
    Set-Content -Encoding utf8 -LiteralPath $path -Value $text
  }
  $implementationPath = Join-Path $Root 'artifacts/implementation-report.md'
  $implementation = Get-Content -Raw -Encoding utf8 -LiteralPath $implementationPath
  $sourceRows = @($implementation -split '\r?\n' | Where-Object { $_ -cmatch ('^\| WORK-ADMIN \| ' + [regex]::Escape($DestinationPath) + ' \|') })
  if ($sourceRows.Count -ne 1) { throw 'Renamed production Change Hygiene row is missing or duplicated' }
  $checkpoint = if ($ExplicitMapping) { "source:${taskBaseSha}:src/admin_route.source; diff:${taskBaseSha}..${finalTreeSha}:src/admin_route.source->${DestinationPath}" } else { "source:${taskBaseSha}:src/admin_route.source; diff:${taskBaseSha}..${finalTreeSha}:${DestinationPath}" }
  $updatedSourceRow = [regex]::Replace($sourceRows[0], '\| none \| (?=[0-9a-f]{40} \| [0-9a-f]{40} \|$)', "| $checkpoint | ")
  if ($updatedSourceRow -ceq $sourceRows[0]) { throw 'Renamed production checkpoint replacement failed' }
  Set-Content -Encoding utf8 -LiteralPath $implementationPath -Value $implementation.Replace($sourceRows[0], $updatedSourceRow)
  $reviewPath = Join-Path $Root 'artifacts/review-report.md'
  $review = Get-Content -Raw -Encoding utf8 -LiteralPath $reviewPath
  if ($ExplicitMapping) {
    $review = $review.Replace("diff:${taskBaseSha}..${finalTreeSha}:${DestinationPath}#", "diff:${taskBaseSha}..${finalTreeSha}:src/admin_route.source->${DestinationPath}#")
  }
  Set-Content -Encoding utf8 -LiteralPath $reviewPath -Value $review
  Sync-ReviewChangeHygieneRows $Root
  Set-Content -Encoding utf8 -LiteralPath $provenancePath -Value "Source Root: $sourceRoot`nTask-base SHA: $taskBaseSha`nFinal-tree SHA: $finalTreeSha`n"
}

function Set-PinnedProductionBindings(
  [string]$Root,
  [string[]]$BindingPaths,
  [bool]$UseWindowsArtifactPaths = $false
) {
  $provenancePath = Join-Path $Root 'artifacts/review-provenance.md'
  $provenance = Get-Content -Raw -Encoding utf8 -LiteralPath $provenancePath
  $sourceRoot = [regex]::Match($provenance, '(?m)^Source Root:\s*(?<value>.+)$').Groups['value'].Value.Trim()
  $taskBaseSha = [regex]::Match($provenance, '(?im)^Task-base SHA:[ \t]*(?<value>[0-9a-f]{40})[ \t]*\r?$').Groups['value'].Value
  $previousFinalTreeSha = [regex]::Match($provenance, '(?im)^Final-tree SHA:[ \t]*(?<value>[0-9a-f]{40})[ \t]*\r?$').Groups['value'].Value
  $verificationPath = Join-Path $sourceRoot 'test/admin_route_test.ps1'
  $verificationText = Get-Content -Raw -Encoding utf8 -LiteralPath $verificationPath
  $replacement = @($BindingPaths | ForEach-Object { "@production-binding ${_}#AdminRoute" }) -join "`n"
  $updatedVerification = [regex]::Replace($verificationText, '(?m)^@production-binding[^\r\n]+$', $replacement)
  if ($updatedVerification -ceq $verificationText) { throw 'Pinned production-binding fixture replacement failed' }
  Set-Content -Encoding utf8 -LiteralPath $verificationPath -Value $updatedVerification
  Invoke-PinnedSourceGit $sourceRoot @('add', '--', 'test/admin_route_test.ps1') | Out-Null
  Invoke-PinnedSourceGit $sourceRoot @('commit', '-m', 'change pinned production binding') | Out-Null
  $finalTreeSha = Invoke-PinnedSourceGit $sourceRoot @('rev-parse', 'HEAD')

  foreach ($relativePath in @('artifacts/design-report.md', 'artifacts/implementation-report.md', 'artifacts/review-report.md')) {
    $path = Join-Path $Root $relativePath
    $text = (Get-Content -Raw -Encoding utf8 -LiteralPath $path).Replace($previousFinalTreeSha, $finalTreeSha)
    $updated = if ($UseWindowsArtifactPaths) { $text.Replace('src/admin_route.source', 'src\admin_route.source') } else { $text }
    Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
  }
  Set-Content -Encoding utf8 -LiteralPath $provenancePath -Value "Source Root: $sourceRoot`nTask-base SHA: $taskBaseSha`nFinal-tree SHA: $finalTreeSha`n"
}

function Comment-OutPinnedVerificationEvidence([string]$Root) {
  $provenancePath = Join-Path $Root 'artifacts/review-provenance.md'
  $provenance = Get-Content -Raw -Encoding utf8 -LiteralPath $provenancePath
  $sourceRoot = [regex]::Match($provenance, '(?m)^Source Root:\s*(?<value>.+)$').Groups['value'].Value.Trim()
  $taskBaseSha = [regex]::Match($provenance, '(?im)^Task-base SHA:[ \t]*(?<value>[0-9a-f]{40})[ \t]*\r?$').Groups['value'].Value
  $previousFinalTreeSha = [regex]::Match($provenance, '(?im)^Final-tree SHA:[ \t]*(?<value>[0-9a-f]{40})[ \t]*\r?$').Groups['value'].Value
  $verificationPath = Join-Path $sourceRoot 'test/admin_route_test.ps1'
  $verificationText = Get-Content -Raw -Encoding utf8 -LiteralPath $verificationPath
  Set-Content -Encoding utf8 -LiteralPath $verificationPath -Value "<#`n$verificationText`n#>"
  Invoke-PinnedSourceGit $sourceRoot @('add', '--', 'test/admin_route_test.ps1') | Out-Null
  Invoke-PinnedSourceGit $sourceRoot @('commit', '-m', 'comment out verification evidence') | Out-Null
  $finalTreeSha = Invoke-PinnedSourceGit $sourceRoot @('rev-parse', 'HEAD')
  foreach ($relativePath in @('artifacts/design-report.md', 'artifacts/implementation-report.md', 'artifacts/review-report.md')) {
    $path = Join-Path $Root $relativePath
    $text = (Get-Content -Raw -Encoding utf8 -LiteralPath $path).Replace($previousFinalTreeSha, $finalTreeSha)
    Set-Content -Encoding utf8 -LiteralPath $path -Value $text
  }
  Set-Content -Encoding utf8 -LiteralPath $provenancePath -Value "Source Root: $sourceRoot`nTask-base SHA: $taskBaseSha`nFinal-tree SHA: $finalTreeSha`n"
}

function Use-LanguageValidPinnedVerificationMarkers([string]$Root, [bool]$WrapInBlockComment = $false) {
  $provenancePath = Join-Path $Root 'artifacts/review-provenance.md'
  $provenance = Get-Content -Raw -Encoding utf8 -LiteralPath $provenancePath
  $sourceRoot = [regex]::Match($provenance, '(?m)^Source Root:\s*(?<value>.+)$').Groups['value'].Value.Trim()
  $taskBaseSha = [regex]::Match($provenance, '(?im)^Task-base SHA:[ \t]*(?<value>[0-9a-f]{40})[ \t]*\r?$').Groups['value'].Value
  $previousFinalTreeSha = [regex]::Match($provenance, '(?im)^Final-tree SHA:[ \t]*(?<value>[0-9a-f]{40})[ \t]*\r?$').Groups['value'].Value
  $verificationPath = Join-Path $sourceRoot 'test/admin_route_test.ps1'
  $verificationLines = @(Get-Content -Encoding utf8 -LiteralPath $verificationPath)
  $encodedVerification = @($verificationLines | ForEach-Object {
    if ($_ -cmatch '^(?:@[a-z]|scenario\s)') { "# arc:$_" } else { $_ }
  }) -join "`n"
  if ($WrapInBlockComment) { $encodedVerification = "<#`n$encodedVerification`n#>" }
  Set-Content -Encoding utf8 -LiteralPath $verificationPath -Value $encodedVerification
  Invoke-PinnedSourceGit $sourceRoot @('add', '--', 'test/admin_route_test.ps1') | Out-Null
  Invoke-PinnedSourceGit $sourceRoot @('commit', '-m', $(if ($WrapInBlockComment) { 'disable language-valid verification markers' } else { 'use language-valid verification markers' })) | Out-Null
  $finalTreeSha = Invoke-PinnedSourceGit $sourceRoot @('rev-parse', 'HEAD')

  foreach ($relativePath in @('artifacts/design-report.md', 'artifacts/implementation-report.md', 'artifacts/review-report.md')) {
    $path = Join-Path $Root $relativePath
    $text = (Get-Content -Raw -Encoding utf8 -LiteralPath $path).Replace($previousFinalTreeSha, $finalTreeSha)
    Set-Content -Encoding utf8 -LiteralPath $path -Value $text
  }
  $implementationPath = Join-Path $Root 'artifacts/implementation-report.md'
  $implementation = Get-Content -Raw -Encoding utf8 -LiteralPath $implementationPath
  $sourceRows = @($implementation -split '\r?\n' | Where-Object { $_ -cmatch '^\| WORK-ADMIN \| src/admin_route\.source \|' })
  if ($sourceRows.Count -ne 1) { throw 'Language-valid marker Change Hygiene anchor is missing or duplicated' }
  $verificationRow = "| WORK-ADMIN | test/admin_route_test.ps1 | existing | AdminRouteContract | none | none | none | $taskBaseSha | $finalTreeSha |"
  Set-Content -Encoding utf8 -LiteralPath $implementationPath -Value $implementation.Replace($sourceRows[0], "$($sourceRows[0])`n$verificationRow")
  Sync-ReviewChangeHygieneRows $Root
  Set-Content -Encoding utf8 -LiteralPath $provenancePath -Value "Source Root: $sourceRoot`nTask-base SHA: $taskBaseSha`nFinal-tree SHA: $finalTreeSha`n"
}

function Set-UnrelatedReachableTaskBase([string]$Root) {
  $provenancePath = Join-Path $Root 'artifacts/review-provenance.md'
  $provenance = Get-Content -Raw -Encoding utf8 -LiteralPath $provenancePath
  $sourceRoot = [regex]::Match($provenance, '(?m)^Source Root:\s*(?<value>.+)$').Groups['value'].Value.Trim()
  $taskBaseSha = [regex]::Match($provenance, '(?im)^Task-base SHA:[ \t]*(?<value>[0-9a-f]{40})[ \t]*\r?$').Groups['value'].Value
  $baseTreeSha = Invoke-PinnedSourceGit $sourceRoot @('rev-parse', "$taskBaseSha^{tree}")
  $unrelatedTaskBaseSha = Invoke-PinnedSourceGit $sourceRoot @('commit-tree', $baseTreeSha, '-m', 'unrelated reachable task base')
  Invoke-PinnedSourceGit $sourceRoot @('branch', 'unrelated-task-base', $unrelatedTaskBaseSha) | Out-Null
  foreach ($relativePath in @('artifacts/design-report.md', 'artifacts/implementation-report.md', 'artifacts/review-report.md', 'artifacts/review-provenance.md')) {
    $path = Join-Path $Root $relativePath
    $text = (Get-Content -Raw -Encoding utf8 -LiteralPath $path).Replace($taskBaseSha, $unrelatedTaskBaseSha)
    Set-Content -Encoding utf8 -LiteralPath $path -Value $text
  }
}

function Convert-ReviewPathsToWindows([string]$Root) {
  Set-PinnedProductionBindings $Root @('src\admin_route.source') $true
}

function Keep-ImplementationSelfAttestationPass([string]$Root) {
  $path = Join-Path $Root 'artifacts/implementation-report.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $updated = $text.Replace('Architecture Conformance State: NOT_REVIEWED', 'Architecture Conformance State: PASS')
  if ($updated -ceq $text) { throw 'Implementation self-attestation fixture replacement failed' }
  Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
}

function SubstituteReviewProvenanceFinalTree([string]$Root) {
  $provenancePath = Join-Path $Root 'artifacts/review-provenance.md'
  $provenance = Get-Content -Raw -Encoding utf8 -LiteralPath $provenancePath
  $sourceRoot = [regex]::Match($provenance, '(?m)^Source Root:\s*(?<value>.+)$').Groups['value'].Value.Trim()
  Set-Content -Encoding utf8 -LiteralPath (Join-Path $sourceRoot 'audit') -Value 'substituted review provenance'
  Invoke-PinnedSourceGit $sourceRoot @('add', '--', 'audit') | Out-Null
  Invoke-PinnedSourceGit $sourceRoot @('commit', '-m', 'alternate review provenance') | Out-Null
  $alternateFinal = Invoke-PinnedSourceGit $sourceRoot @('rev-parse', 'HEAD')
  $reviewPath = Join-Path $Root 'artifacts/review-report.md'
  $review = Get-Content -Raw -Encoding utf8 -LiteralPath $reviewPath
  $updatedReview = [regex]::Replace($review, '(?<=source:)[0-9a-f]{40}(?=:src/admin_route\.source#)|(?<=\.\.)[0-9a-f]{40}(?=:src/admin_route\.source#)', $alternateFinal)
  if ($updatedReview -ceq $review) { throw 'Substituted review evidence fixture replacement failed' }
  Set-Content -Encoding utf8 -LiteralPath $reviewPath -Value $updatedReview
  $existingFinal = [regex]::Match($provenance, '(?im)^Final-tree SHA:[ \t]*(?<value>[0-9a-f]{40})[ \t]*\r?$').Groups['value'].Value
  $updatedProvenance = $provenance.Replace($existingFinal, $alternateFinal)
  if ($updatedProvenance -ceq $provenance) { throw 'Substituted review provenance fixture replacement failed' }
  Set-Content -Encoding utf8 -LiteralPath $provenancePath -Value $updatedProvenance
}

function Remove-ImplementationChangeHygiene([string]$Root) {
  $path = Join-Path $Root 'artifacts/implementation-report.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $updated = [regex]::Replace($text, '(?ms)^## Change Hygiene\r?\n.*?(?=^## Implementation Self-Attestation)', '')
  if ($updated -ceq $text) { throw 'Implementation Change Hygiene fixture removal failed' }
  Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
}

Assert-Pass 'complete architecture-first review and scope-aware KB contract' $null
Assert-Pass 'independent review accepts implementation-bound provenance' $null $true

foreach ($requiredExecutableGate in @(
  [pscustomobject]@{ Name = 'Rule Resolution'; Line = '- Rule Resolution Verdict: RESOLVED' },
  [pscustomobject]@{ Name = 'Canonical Selector'; Line = '- Canonical Selector Verdict: PASS' },
  [pscustomobject]@{ Name = 'Production Activation'; Line = '- Production Activation-path Verdict: NOT_APPLICABLE' },
  [pscustomobject]@{ Name = 'Behavior'; Line = '- Behavior Analysis State: COMPLETE' }
)) {
  Assert-FailsLike "independent executable review requires $($requiredExecutableGate.Name)" {
    param($root)
    $path = Join-Path $root 'artifacts/review-report.md'
    $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
    $updated = $text.Replace("$($requiredExecutableGate.Line)`r`n", '').Replace("$($requiredExecutableGate.Line)`n", '')
    if ($updated -ceq $text) { throw "Missing $($requiredExecutableGate.Name) fixture mutation was a silent no-op" }
    Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
  } 'responsibility-evidence-missing' $true
}

foreach ($contradictoryExecutableGate in @(
  [pscustomobject]@{ Name = 'Rule Resolution'; From = '- Rule Resolution Verdict: RESOLVED'; To = '- Rule Resolution Verdict: BLOCKED' },
  [pscustomobject]@{ Name = 'Canonical Selector'; From = '- Canonical Selector Verdict: PASS'; To = '- Canonical Selector Verdict: BLOCKED' },
  [pscustomobject]@{ Name = 'Production Activation'; From = '- Production Activation-path Verdict: NOT_APPLICABLE'; To = '- Production Activation-path Verdict: BLOCKED' },
  [pscustomobject]@{ Name = 'Behavior'; From = '- Behavior Analysis State: COMPLETE'; To = '- Behavior Analysis State: NOT_RUN' }
)) {
  Assert-FailsLike "independent executable review derives conclusion from $($contradictoryExecutableGate.Name)" {
    param($root)
    $path = Join-Path $root 'artifacts/review-report.md'
    $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
    $updated = $text.Replace($contradictoryExecutableGate.From, $contradictoryExecutableGate.To)
    if ($updated -ceq $text) { throw "Contradictory $($contradictoryExecutableGate.Name) fixture mutation was a silent no-op" }
    Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
  } 'responsibility-waiver-forbidden' $true
}

Assert-FailsLike 'non-PASS overall review conclusion is not executable despite PASS architecture verdicts' {
  param($root)
  $path = Join-Path $root 'artifacts/review-report.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $updated = $text.Replace('- Verdict: Approve', '- Verdict: Reject')
  if ($updated -ceq $text) { throw 'Reject conclusion fixture replacement failed' }
  Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
} 'responsibility-waiver-forbidden' $true

Assert-FailsLike 'Critical-bearing review is not executable despite PASS architecture verdicts' {
  param($root)
  $path = Join-Path $root 'artifacts/review-report.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $updated = $text.Replace('- Critical count: 0', '- Critical count: 1')
  if ($updated -ceq $text) { throw 'Critical-bearing review fixture replacement failed' }
  Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
} 'responsibility-waiver-forbidden' $true

Assert-FailsLike 'independent review handoff cells must equal the visible derived verdicts' {
  param($root)
  $path = Join-Path $root 'artifacts/review-report.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $updated = $text.Replace('| 1 | PASS | PASS | PASS | PASS | source-diff:', '| 1 | BLOCKED | PASS | PASS | BLOCKED | source-diff:')
  if ($updated -ceq $text) { throw 'Contradictory independent handoff fixture replacement failed' }
  Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
} 'responsibility-waiver-forbidden' $true

Assert-FailsLike 'review rejects a canonically production-classified markerless route even when Change Hygiene lists the path' {
  param($root)
  Add-MarkerlessProductionPath $root
} 'responsibility-evidence-missing|responsibility-owner-extra' $true

foreach ($gitStatusCase in @('A', 'M', 'R', 'C')) {
  $sourceRoot = Join-Path ([IO.Path]::GetTempPath()) ('aitoolkit-markerless-status-' + [guid]::NewGuid().ToString('N'))
  try {
    [void](New-Item -ItemType Directory -Force -Path (Join-Path $sourceRoot 'src'))
    Invoke-PinnedSourceGit $sourceRoot @('init') | Out-Null
    Invoke-PinnedSourceGit $sourceRoot @('config', 'core.autocrlf', 'false') | Out-Null
    Invoke-PinnedSourceGit $sourceRoot @('config', 'user.email', 'fixtures@example.test') | Out-Null
    Invoke-PinnedSourceGit $sourceRoot @('config', 'user.name', 'AIToolkit fixture') | Out-Null
    Set-Content -Encoding utf8 -LiteralPath (Join-Path $sourceRoot 'README') -Value 'markerless status fixture'
    if ($gitStatusCase -cin @('M', 'R', 'C')) {
      Set-Content -Encoding utf8 -LiteralPath (Join-Path $sourceRoot 'src/markerless_old.source') -Value 'route MarkerlessRoute -> MarkerlessProvider'
    }
    Invoke-PinnedSourceGit $sourceRoot @('add', '--all') | Out-Null
    Invoke-PinnedSourceGit $sourceRoot @('commit', '-m', 'markerless base') | Out-Null
    $taskBaseSha = Invoke-PinnedSourceGit $sourceRoot @('rev-parse', 'HEAD')
    switch ($gitStatusCase) {
      'A' { Set-Content -Encoding utf8 -LiteralPath (Join-Path $sourceRoot 'src/markerless_route.source') -Value 'route MarkerlessRoute -> MarkerlessProvider' }
      'M' { Set-Content -Encoding utf8 -LiteralPath (Join-Path $sourceRoot 'src/markerless_old.source') -Value 'route MarkerlessRoute -> UpdatedMarkerlessProvider' }
      'R' { Move-Item -LiteralPath (Join-Path $sourceRoot 'src/markerless_old.source') -Destination (Join-Path $sourceRoot 'src/markerless_route.source') }
      'C' { Copy-Item -LiteralPath (Join-Path $sourceRoot 'src/markerless_old.source') -Destination (Join-Path $sourceRoot 'src/markerless_route.source') }
    }
    Invoke-PinnedSourceGit $sourceRoot @('add', '--all') | Out-Null
    Invoke-PinnedSourceGit $sourceRoot @('commit', '-m', "markerless $gitStatusCase change") | Out-Null
    $finalTreeSha = Invoke-PinnedSourceGit $sourceRoot @('rev-parse', 'HEAD')
    $inventoryErrors = [Collections.Generic.List[string]]::new()
    $sourceInventory = Get-ArcPinnedSourceInventory -SourceRoot $sourceRoot -TaskBaseSha $taskBaseSha -FinalTreeSha $finalTreeSha -Errors $inventoryErrors
    $statusRows = @($sourceInventory.ChangedPaths | Where-Object { $_.RawStatus.Substring(0, 1) -ceq $gitStatusCase })
    if ($statusRows.Count -ne 1 -or $inventoryErrors -cnotcontains 'responsibility-evidence-missing') {
      throw "markerless $gitStatusCase inventory was not independently classified and rejected: $($inventoryErrors -join '; ')"
    }
    Write-Output "PASS: markerless $gitStatusCase production path enters the pinned changed-path inventory and is rejected"
  }
  finally {
    if (Test-Path -LiteralPath $sourceRoot) { Remove-Item -LiteralPath $sourceRoot -Recurse -Force }
  }
}

$mixedOwnershipRoot = Join-Path ([IO.Path]::GetTempPath()) ('aitoolkit-mixed-ownership-' + [guid]::NewGuid().ToString('N'))
try {
  [void](New-Item -ItemType Directory -Force -Path (Join-Path $mixedOwnershipRoot 'src'))
  Invoke-PinnedSourceGit $mixedOwnershipRoot @('init') | Out-Null
  Invoke-PinnedSourceGit $mixedOwnershipRoot @('config', 'core.autocrlf', 'false') | Out-Null
  Invoke-PinnedSourceGit $mixedOwnershipRoot @('config', 'user.email', 'fixtures@example.test') | Out-Null
  Invoke-PinnedSourceGit $mixedOwnershipRoot @('config', 'user.name', 'AIToolkit fixture') | Out-Null
  $ownedRoute = "@responsibility RESP-OWNED`n@owner-symbol OwnedRoute`n@public-symbol OwnedRoute`n@owned-capability CAP-OWNED`n@effect route registration`n@architecture-authority target-exemplar`n@co-location-policy feature-local`n@verification-owner VERIFY-OWNER-OWNED`n@ownership-begin RESP-OWNED`nroute OwnedRoute -> OwnedProvider`n@ownership-end RESP-OWNED"
  $sourcePath = Join-Path $mixedOwnershipRoot 'src/routes.source'
  Set-Content -Encoding utf8 -LiteralPath $sourcePath -Value $ownedRoute
  Invoke-PinnedSourceGit $mixedOwnershipRoot @('add', '--all') | Out-Null
  Invoke-PinnedSourceGit $mixedOwnershipRoot @('commit', '-m', 'owned route base') | Out-Null
  $taskBaseSha = Invoke-PinnedSourceGit $mixedOwnershipRoot @('rev-parse', 'HEAD')
  Set-Content -Encoding utf8 -LiteralPath $sourcePath -Value "route RogueRoute -> RogueProvider`n$ownedRoute"
  Invoke-PinnedSourceGit $mixedOwnershipRoot @('add', '--all') | Out-Null
  Invoke-PinnedSourceGit $mixedOwnershipRoot @('commit', '-m', 'add unowned route and provider') | Out-Null
  $finalTreeSha = Invoke-PinnedSourceGit $mixedOwnershipRoot @('rev-parse', 'HEAD')
  $inventoryErrors = [Collections.Generic.List[string]]::new()
  [void](Get-ArcPinnedSourceInventory -SourceRoot $mixedOwnershipRoot -TaskBaseSha $taskBaseSha -FinalTreeSha $finalTreeSha -Errors $inventoryErrors)
  if ($inventoryErrors -cnotcontains 'responsibility-evidence-missing') {
    throw 'markerless route/provider before an unchanged responsibility block was not rejected'
  }
  Write-Output 'PASS: mixed owned and unowned production route/provider content is rejected'
}
finally {
  if (Test-Path -LiteralPath $mixedOwnershipRoot) { Remove-Item -LiteralPath $mixedOwnershipRoot -Recurse -Force }
}

foreach ($markerlessPlacement in @('before', 'between', 'after')) {
  $markerlessBodyRoot = Join-Path ([IO.Path]::GetTempPath()) ('aitoolkit-markerless-body-' + [guid]::NewGuid().ToString('N'))
  try {
    [void](New-Item -ItemType Directory -Force -Path (Join-Path $markerlessBodyRoot 'src'))
    Invoke-PinnedSourceGit $markerlessBodyRoot @('init') | Out-Null
    Invoke-PinnedSourceGit $markerlessBodyRoot @('config', 'core.autocrlf', 'false') | Out-Null
    Invoke-PinnedSourceGit $markerlessBodyRoot @('config', 'user.email', 'fixtures@example.test') | Out-Null
    Invoke-PinnedSourceGit $markerlessBodyRoot @('config', 'user.name', 'AIToolkit fixture') | Out-Null
    Set-Content -Encoding utf8 -LiteralPath (Join-Path $markerlessBodyRoot 'README') -Value 'markerless body base'
    Invoke-PinnedSourceGit $markerlessBodyRoot @('add', '--all') | Out-Null
    Invoke-PinnedSourceGit $markerlessBodyRoot @('commit', '-m', 'markerless body base') | Out-Null
    $taskBaseSha = Invoke-PinnedSourceGit $markerlessBodyRoot @('rev-parse', 'HEAD')
    $firstOwner = "@responsibility RESP-FIRST`n@owner-symbol FirstRoute`n@public-symbol FirstRoute`n@owned-capability CAP-FIRST`n@effect route registration`n@architecture-authority target-exemplar`n@co-location-policy feature-local`n@verification-owner VERIFY-OWNER-FIRST`n@ownership-begin RESP-FIRST`nroute FirstRoute -> FirstProvider`n@ownership-end RESP-FIRST"
    $secondOwner = "@responsibility RESP-SECOND`n@owner-symbol SecondRoute`n@public-symbol SecondRoute`n@owned-capability CAP-SECOND`n@effect route registration`n@architecture-authority target-exemplar`n@co-location-policy feature-local`n@verification-owner VERIFY-OWNER-SECOND`n@ownership-begin RESP-SECOND`nroute SecondRoute -> SecondProvider`n@ownership-end RESP-SECOND"
    $rogueExecutable = 'if (featureEnabled) { invokeRogue(); }'
    $sourceText = switch ($markerlessPlacement) {
      'before' { "$rogueExecutable`n$firstOwner" }
      'between' { "$firstOwner`n$rogueExecutable`n$secondOwner" }
      'after' { "$firstOwner`n$rogueExecutable" }
    }
    Set-Content -Encoding utf8 -LiteralPath (Join-Path $markerlessBodyRoot 'src/routes.source') -Value $sourceText
    Invoke-PinnedSourceGit $markerlessBodyRoot @('add', '--all') | Out-Null
    Invoke-PinnedSourceGit $markerlessBodyRoot @('commit', '-m', "markerless executable $markerlessPlacement owners") | Out-Null
    $finalTreeSha = Invoke-PinnedSourceGit $markerlessBodyRoot @('rev-parse', 'HEAD')
    $inventoryErrors = [Collections.Generic.List[string]]::new()
    [void](Get-ArcPinnedSourceInventory -SourceRoot $markerlessBodyRoot -TaskBaseSha $taskBaseSha -FinalTreeSha $finalTreeSha -Errors $inventoryErrors)
    if ($inventoryErrors -cnotcontains 'responsibility-evidence-missing') {
      throw "framework-neutral markerless executable $markerlessPlacement responsibility blocks was not rejected"
    }
    Write-Output "PASS: framework-neutral markerless executable $markerlessPlacement responsibility blocks is rejected"
  }
  finally {
    if (Test-Path -LiteralPath $markerlessBodyRoot) { Remove-Item -LiteralPath $markerlessBodyRoot -Recurse -Force }
  }
}

$commentOnlyRoot = Join-Path ([IO.Path]::GetTempPath()) ('aitoolkit-comment-only-boundaries-' + [guid]::NewGuid().ToString('N'))
try {
  [void](New-Item -ItemType Directory -Force -Path (Join-Path $commentOnlyRoot 'src'))
  Invoke-PinnedSourceGit $commentOnlyRoot @('init') | Out-Null
  Invoke-PinnedSourceGit $commentOnlyRoot @('config', 'core.autocrlf', 'false') | Out-Null
  Invoke-PinnedSourceGit $commentOnlyRoot @('config', 'user.email', 'fixtures@example.test') | Out-Null
  Invoke-PinnedSourceGit $commentOnlyRoot @('config', 'user.name', 'AIToolkit fixture') | Out-Null
  Set-Content -Encoding utf8 -LiteralPath (Join-Path $commentOnlyRoot 'README') -Value 'comment boundary base'
  Invoke-PinnedSourceGit $commentOnlyRoot @('add', '--all') | Out-Null
  Invoke-PinnedSourceGit $commentOnlyRoot @('commit', '-m', 'comment boundary base') | Out-Null
  $taskBaseSha = Invoke-PinnedSourceGit $commentOnlyRoot @('rev-parse', 'HEAD')
  $ownedRoute = "@responsibility RESP-COMMENTED`n@owner-symbol CommentedRoute`n@public-symbol CommentedRoute`n@owned-capability CAP-COMMENTED`n@effect route registration`n@architecture-authority target-exemplar`n@co-location-policy feature-local`n@verification-owner VERIFY-OWNER-COMMENTED`n@ownership-begin RESP-COMMENTED`nroute CommentedRoute -> CommentedProvider`n@ownership-end RESP-COMMENTED"
  Set-Content -Encoding utf8 -LiteralPath (Join-Path $commentOnlyRoot 'src/routes.source') -Value "# header comment`n`n$ownedRoute`n`n// trailing comment"
  Invoke-PinnedSourceGit $commentOnlyRoot @('add', '--all') | Out-Null
  Invoke-PinnedSourceGit $commentOnlyRoot @('commit', '-m', 'comment-only owner surroundings') | Out-Null
  $finalTreeSha = Invoke-PinnedSourceGit $commentOnlyRoot @('rev-parse', 'HEAD')
  $inventoryErrors = [Collections.Generic.List[string]]::new()
  $sourceInventory = Get-ArcPinnedSourceInventory -SourceRoot $commentOnlyRoot -TaskBaseSha $taskBaseSha -FinalTreeSha $finalTreeSha -Errors $inventoryErrors
  if ($inventoryErrors.Count -ne 0 -or @($sourceInventory.ActiveOwners | Where-Object { $_.Id -ceq 'RESP-COMMENTED' }).Count -ne 1) {
    throw "blank/comment-only content beside a responsibility block should pass: $($inventoryErrors -join '; ')"
  }
  Write-Output 'PASS: blank/comment-only content beside a responsibility block remains valid'
}
finally {
  if (Test-Path -LiteralPath $commentOnlyRoot) { Remove-Item -LiteralPath $commentOnlyRoot -Recurse -Force }
}

function Invoke-LexicalSourceInventoryProbe(
  [string]$Name,
  [string]$NewLine,
  [string]$SourceText,
  [string]$RelativePath = 'src/lexical.source'
) {
  $probeRoot = Join-Path ([IO.Path]::GetTempPath()) ("aitoolkit-lexical-$Name-" + [guid]::NewGuid().ToString('N'))
  try {
    [void](New-Item -ItemType Directory -Force -Path (Join-Path $probeRoot 'src'))
    Invoke-PinnedSourceGit $probeRoot @('init') | Out-Null
    Invoke-PinnedSourceGit $probeRoot @('config', 'core.autocrlf', 'false') | Out-Null
    Invoke-PinnedSourceGit $probeRoot @('config', 'user.email', 'fixtures@example.test') | Out-Null
    Invoke-PinnedSourceGit $probeRoot @('config', 'user.name', 'AIToolkit fixture') | Out-Null
    [IO.File]::WriteAllText((Join-Path $probeRoot 'README'), 'lexical base', [Text.UTF8Encoding]::new($false))
    Invoke-PinnedSourceGit $probeRoot @('add', '--all') | Out-Null
    Invoke-PinnedSourceGit $probeRoot @('commit', '-m', 'lexical base') | Out-Null
    $taskBaseSha = Invoke-PinnedSourceGit $probeRoot @('rev-parse', 'HEAD')
    $renderedSource = [regex]::Replace($SourceText, '\r\n|\r|\n', $NewLine)
    $sourcePath = Join-Path $probeRoot $RelativePath
    [void](New-Item -ItemType Directory -Force -Path (Split-Path -Parent $sourcePath))
    [IO.File]::WriteAllText($sourcePath, $renderedSource, [Text.UTF8Encoding]::new($false))
    Invoke-PinnedSourceGit $probeRoot @('add', '--all') | Out-Null
    Invoke-PinnedSourceGit $probeRoot @('commit', '-m', "lexical $Name") | Out-Null
    $finalTreeSha = Invoke-PinnedSourceGit $probeRoot @('rev-parse', 'HEAD')
    $inventoryErrors = [Collections.Generic.List[string]]::new()
    $sourceInventory = Get-ArcPinnedSourceInventory -SourceRoot $probeRoot -TaskBaseSha $taskBaseSha -FinalTreeSha $finalTreeSha -Errors $inventoryErrors
    $activeOwners = @($sourceInventory.ActiveOwners | Where-Object { $_.Path -ceq $RelativePath })
    return [pscustomobject]@{
      Errors = @($inventoryErrors)
      OwnerCount = @($sourceInventory.ActiveOwners | Where-Object { $_.Id -ceq 'RESP-LEXICAL' }).Count
      Owners = $activeOwners
    }
  }
  finally {
    if (Test-Path -LiteralPath $probeRoot) { Remove-Item -LiteralPath $probeRoot -Recurse -Force }
  }
}

$lexicalOwnerMetadata = @'
@responsibility RESP-LEXICAL
@owner-symbol LexicalOwner
@public-symbol LexicalOwner
@owned-capability CAP-LEXICAL
@effect none
@architecture-authority target-exemplar
@co-location-policy feature-local
@verification-owner VERIFY-OWNER-LEXICAL
@ownership-begin RESP-LEXICAL
'@
$lexicalOwnerEnd = '@ownership-end RESP-LEXICAL'

$validJavascriptOwnerMetadata = @'
// arc:@responsibility RESP-LEXICAL
// arc:@owner-symbol LexicalOwner
// arc:@public-symbol LexicalOwner
// arc:@owned-capability CAP-LEXICAL
// arc:@effect none
// arc:@architecture-authority target-exemplar
// arc:@co-location-policy feature-local
// arc:@verification-owner VERIFY-OWNER-LEXICAL
// arc:@ownership-begin RESP-LEXICAL
'@
$validJavascriptOwnerEnd = '// arc:@ownership-end RESP-LEXICAL'

$freshLexerFormatterResidualFailures = [Collections.Generic.List[string]]::new()
foreach ($lexicalLineEnding in @(
  [pscustomobject]@{ Name = 'LF'; NewLine = "`n" },
  [pscustomobject]@{ Name = 'CRLF'; NewLine = "`r`n" }
)) {
  $javascriptOwnershipRange = @'
// arc:@responsibility RESP-LEXICAL
// arc:@owner-symbol LexicalOwner
// arc:@public-symbol LexicalOwner
// arc:@public-symbol createLexicalOwner
// arc:@owned-capability CAP-LEXICAL
// arc:@effect none
// arc:@architecture-authority target-exemplar
// arc:@co-location-policy feature-local
// arc:@verification-owner VERIFY-OWNER-LEXICAL
// arc:@ownership-begin RESP-LEXICAL
import path from 'node:path';
export class LexicalOwner { resolve(value) { return path.basename(value); } }
export function createLexicalOwner() { return new LexicalOwner(); }
// arc:@ownership-end RESP-LEXICAL
'@
  $javascriptOwnershipRangeResult = Invoke-LexicalSourceInventoryProbe "javascript-ownership-range-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $javascriptOwnershipRange 'src/owned-module.js'
  $javascriptOwnershipOwner = @($javascriptOwnershipRangeResult.Owners | Where-Object { $_.Id -ceq 'RESP-LEXICAL' })
  if (
    $javascriptOwnershipRangeResult.Errors.Count -ne 0 -or
    $javascriptOwnershipRangeResult.OwnerCount -ne 1 -or
    $javascriptOwnershipOwner.Count -ne 1 -or
    -not (Test-ArcExactSet -Actual @($javascriptOwnershipOwner[0].Symbols) -Expected @('LexicalOwner', 'createLexicalOwner'))
  ) {
    throw "explicit JavaScript ownership range must cover module imports and multiple symbols ($($lexicalLineEnding.Name)): $($javascriptOwnershipRangeResult.Errors -join '; ')"
  }
  Write-Output "PASS: explicit JavaScript ownership range covers imports and multiple symbols ($($lexicalLineEnding.Name))"

  $pythonOwnershipRange = @'
# arc:@responsibility RESP-LEXICAL
# arc:@owner-symbol LexicalOwner
# arc:@public-symbol LexicalOwner
# arc:@public-symbol create_lexical_owner
# arc:@owned-capability CAP-LEXICAL
# arc:@effect none
# arc:@architecture-authority target-exemplar
# arc:@co-location-policy feature-local
# arc:@verification-owner VERIFY-OWNER-LEXICAL
# arc:@ownership-begin RESP-LEXICAL
"""Owned lexical module."""
from __future__ import annotations
import pathlib
class LexicalOwner:
    def resolve(self, value: str) -> pathlib.Path:
        return pathlib.Path(value)
def create_lexical_owner() -> LexicalOwner:
    return LexicalOwner()
# arc:@ownership-end RESP-LEXICAL
'@
  $pythonOwnershipRangeResult = Invoke-LexicalSourceInventoryProbe "python-ownership-range-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $pythonOwnershipRange 'src/owned_module.py'
  $pythonOwnershipOwner = @($pythonOwnershipRangeResult.Owners | Where-Object { $_.Id -ceq 'RESP-LEXICAL' })
  if (
    $pythonOwnershipRangeResult.Errors.Count -ne 0 -or
    $pythonOwnershipRangeResult.OwnerCount -ne 1 -or
    $pythonOwnershipOwner.Count -ne 1 -or
    -not (Test-ArcExactSet -Actual @($pythonOwnershipOwner[0].Symbols) -Expected @('LexicalOwner', 'create_lexical_owner'))
  ) {
    throw "explicit Python ownership range must cover module imports and multiple symbols ($($lexicalLineEnding.Name)): $($pythonOwnershipRangeResult.Errors -join '; ')"
  }
  Write-Output "PASS: explicit Python ownership range covers imports and multiple symbols ($($lexicalLineEnding.Name))"

  $adjacentOwnershipRanges = @'
@responsibility RESP-LEXICAL
@owner-symbol LexicalOwner
@public-symbol LexicalOwner
@owned-capability CAP-LEXICAL
@effect none
@architecture-authority target-exemplar
@co-location-policy feature-local
@verification-owner VERIFY-OWNER-LEXICAL
@ownership-begin RESP-LEXICAL
class LexicalOwner {}
@ownership-end RESP-LEXICAL

// comment-only separator
@responsibility RESP-SECOND
@owner-symbol SecondOwner
@public-symbol SecondOwner
@owned-capability CAP-SECOND
@effect none
@architecture-authority target-exemplar
@co-location-policy feature-local
@verification-owner VERIFY-OWNER-SECOND
@ownership-begin RESP-SECOND
class SecondOwner {}
@ownership-end RESP-SECOND
'@
  $adjacentOwnershipRangeResult = Invoke-LexicalSourceInventoryProbe "adjacent-ownership-ranges-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $adjacentOwnershipRanges
  if ($adjacentOwnershipRangeResult.Errors.Count -ne 0 -or $adjacentOwnershipRangeResult.Owners.Count -ne 2) {
    throw "adjacent non-overlapping ownership ranges must remain valid ($($lexicalLineEnding.Name)): $($adjacentOwnershipRangeResult.Errors -join '; ')"
  }
  Write-Output "PASS: adjacent non-overlapping ownership ranges remain valid ($($lexicalLineEnding.Name))"

  $startOnlyOwner = @'
@responsibility RESP-LEXICAL
@owner-symbol LexicalOwner
@public-symbol LexicalOwner
@owned-capability CAP-LEXICAL
@effect none
@architecture-authority target-exemplar
@co-location-policy feature-local
@verification-owner VERIFY-OWNER-LEXICAL
class LexicalOwner {}
'@
  foreach ($rangeFailureCase in @(
    @{ Name = 'start-only'; Path = 'src/start-only.source'; Source = $startOnlyOwner },
    @{ Name = 'rogue-outside'; Path = 'src/owned-module.js'; Source = $javascriptOwnershipRange + "`nexport function rogueOutsideRange() { return 0; }" },
    @{ Name = 'javascript-import-outside'; Path = 'src/owned-module.js'; Source = "import fs from 'node:fs';`n$javascriptOwnershipRange" },
    @{ Name = 'javascript-directive-outside'; Path = 'src/owned-module.js'; Source = "'use strict';`n$javascriptOwnershipRange" },
    @{ Name = 'python-future-outside'; Path = 'src/owned_module.py'; Source = "from __future__ import annotations`n$pythonOwnershipRange" },
    @{ Name = 'python-import-outside'; Path = 'src/owned_module.py'; Source = "import os`n$pythonOwnershipRange" },
    @{ Name = 'missing-end'; Path = 'src/owned-module.js'; Source = $javascriptOwnershipRange.Replace('// arc:@ownership-end RESP-LEXICAL', '') },
    @{ Name = 'orphan-end'; Path = 'src/owned-module.js'; Source = "// arc:@ownership-end RESP-ORPHAN`n$javascriptOwnershipRange" },
    @{ Name = 'duplicate-end'; Path = 'src/owned-module.js'; Source = $javascriptOwnershipRange + "`n// arc:@ownership-end RESP-LEXICAL" },
    @{ Name = 'malformed-end'; Path = 'src/owned-module.js'; Source = $javascriptOwnershipRange.Replace('// arc:@ownership-end RESP-LEXICAL', '// arc:@ownership-end') },
    @{ Name = 'unknown-javascript-ownership-marker'; Path = 'src/owned-module.js'; Source = $javascriptOwnershipRange.Replace("import path from 'node:path';", "// arc:@ownership-start RESP-LEXICAL`nimport path from 'node:path';") },
    @{ Name = 'unknown-python-ownership-marker'; Path = 'src/owned_module.py'; Source = $pythonOwnershipRange.Replace('import pathlib', "# arc:@ownership-start RESP-LEXICAL`nimport pathlib") },
    @{ Name = 'argless-unknown-javascript-ownership-marker'; Path = 'src/owned-module.js'; Source = $javascriptOwnershipRange.Replace("import path from 'node:path';", "// arc:@ownership-start`nimport path from 'node:path';") },
    @{ Name = 'argless-unknown-python-ownership-marker'; Path = 'src/owned_module.py'; Source = $pythonOwnershipRange.Replace('import pathlib', "# arc:@ownership-start`nimport pathlib") },
    @{ Name = 'mismatched-end'; Path = 'src/owned-module.js'; Source = $javascriptOwnershipRange.Replace('// arc:@ownership-end RESP-LEXICAL', '// arc:@ownership-end RESP-FOREIGN') },
    @{ Name = 'nested-range'; Path = 'src/owned-module.js'; Source = $javascriptOwnershipRange.Replace("import path from 'node:path';", "// arc:@ownership-begin RESP-FOREIGN`nimport path from 'node:path';") },
    @{ Name = 'crossed-range'; Path = 'src/owned-module.js'; Source = $javascriptOwnershipRange.Replace("import path from 'node:path';", "// arc:@ownership-begin RESP-FOREIGN`nimport path from 'node:path';").Replace('// arc:@ownership-end RESP-LEXICAL', "// arc:@ownership-end RESP-LEXICAL`n// arc:@ownership-end RESP-FOREIGN") }
  )) {
    $rangeFailureResult = Invoke-LexicalSourceInventoryProbe "ownership-range-$($rangeFailureCase.Name)-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $rangeFailureCase.Source $rangeFailureCase.Path
    if ($rangeFailureResult.Errors -cnotcontains 'responsibility-evidence-missing') {
      throw "$($rangeFailureCase.Name) explicit ownership range must fail closed ($($lexicalLineEnding.Name))"
    }
    Write-Output "PASS: $($rangeFailureCase.Name) explicit ownership range fails closed ($($lexicalLineEnding.Name))"
  }

  $inertUnknownOwnershipMarkers = $javascriptOwnershipRange.Replace(
    "import path from 'node:path';",
    "const ownershipMarkerText = '// arc:@ownership-start RESP-LEXICAL';`n// // arc:@ownership-start RESP-LEXICAL`nimport path from 'node:path';"
  )
  $inertUnknownOwnershipResult = Invoke-LexicalSourceInventoryProbe "inert-unknown-ownership-marker-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $inertUnknownOwnershipMarkers 'src/owned-module.js'
  if ($inertUnknownOwnershipResult.Errors.Count -ne 0 -or $inertUnknownOwnershipResult.OwnerCount -ne 1) {
    throw "ownership-prefixed text in strings and disabled comments must remain inert ($($lexicalLineEnding.Name)): $($inertUnknownOwnershipResult.Errors -join '; ')"
  }
  Write-Output "PASS: ownership-prefixed text in strings and disabled comments remains inert ($($lexicalLineEnding.Name))"

  $commentMatrixSource = @"
# shell/python comment
// C-family comment
-- SQL comment
; Lisp comment
/* C-family block comment
 * braces inside the comment are inert: { }
 */
<!-- markup block comment
 braces inside the comment are inert: { }
-->
<# PowerShell block comment
 braces inside the comment are inert: { }
#>

$lexicalOwnerMetadata
class LexicalOwner { int run() { return 1; } }
$lexicalOwnerEnd

// trailing C-family comment
"@
  $commentMatrix = Invoke-LexicalSourceInventoryProbe "comments-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $commentMatrixSource
  if ($commentMatrix.Errors.Count -ne 0 -or $commentMatrix.OwnerCount -ne 1) {
    throw "legitimate language comment matrix ($($lexicalLineEnding.Name)) should remain valid: $($commentMatrix.Errors -join '; ')"
  }
  Write-Output "PASS: legitimate language comment matrix remains valid ($($lexicalLineEnding.Name))"

  foreach ($languageAwareRogueCase in @(
    [pscustomobject]@{ Name = 'spaced-c-decrement'; Path = 'src/lexical.c'; Code = '-- counter;' },
    [pscustomobject]@{ Name = 'spaced-js-decrement'; Path = 'src/lexical.js'; Code = '-- counter;' },
    [pscustomobject]@{ Name = 'spaced-c-empty-statement'; Path = 'src/lexical.c'; Code = '; danger();' },
    [pscustomobject]@{ Name = 'rust-spaced-attribute'; Path = 'src/lexical.rs'; Code = '# [cfg(test)]' },
    [pscustomobject]@{ Name = 'csharp-region-directive'; Path = 'src/lexical.cs'; Code = '# region outside_owner' }
  )) {
    $rogueSource = "$lexicalOwnerMetadata`nclass LexicalOwner { int run() { return 1; } }`n$lexicalOwnerEnd`n$($languageAwareRogueCase.Code)"
    $rogueResult = Invoke-LexicalSourceInventoryProbe "$($languageAwareRogueCase.Name)-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $rogueSource $languageAwareRogueCase.Path
    if ($rogueResult.Errors -cnotcontains 'responsibility-evidence-missing') {
      throw "$($languageAwareRogueCase.Name) outside responsibility coverage was incorrectly classified as a comment ($($lexicalLineEnding.Name))"
    }
    Write-Output "PASS: $($languageAwareRogueCase.Name) remains executable or fail-closed ($($lexicalLineEnding.Name))"
  }

  foreach ($languageCommentCase in @(
    [pscustomobject]@{ Name = 'sql-dash-comment'; Path = 'src/lexical.sql'; Comment = '-- true SQL comment' },
    [pscustomobject]@{ Name = 'lisp-semicolon-comment'; Path = 'src/lexical.lisp'; Comment = '; true Lisp comment' },
    [pscustomobject]@{ Name = 'python-hash-comment'; Path = 'src/lexical.py'; Comment = '# true Python comment' },
    [pscustomobject]@{ Name = 'powershell-hash-comment'; Path = 'src/lexical.ps1'; Comment = '# true PowerShell comment' },
    [pscustomobject]@{ Name = 'c-slash-comment'; Path = 'src/lexical.c'; Comment = '// true C comment' }
  )) {
    $commentSource = "$($languageCommentCase.Comment)`n$lexicalOwnerMetadata`nclass LexicalOwner { int run() { return 1; } }`n$lexicalOwnerEnd"
    $commentResult = Invoke-LexicalSourceInventoryProbe "$($languageCommentCase.Name)-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $commentSource $languageCommentCase.Path
    if ($commentResult.Errors.Count -ne 0 -or $commentResult.OwnerCount -ne 1) {
      throw "$($languageCommentCase.Name) was not preserved as a true language comment ($($lexicalLineEnding.Name)): $($commentResult.Errors -join '; ')"
    }
    Write-Output "PASS: $($languageCommentCase.Name) remains comment-only ($($lexicalLineEnding.Name))"
  }

  $semanticMarkerPayloads = @($lexicalOwnerMetadata -split '\r?\n' | Where-Object { $_ -ne '' })
  foreach ($languageMarkerCase in @(
    [pscustomobject]@{ Name = 'dart'; Path = 'lib/lexical_owner.dart'; Prefix = '// arc:'; DisabledPrefix = '// disabled arc:'; Body = 'class LexicalOwner {}' },
    [pscustomobject]@{ Name = 'java'; Path = 'src/LexicalOwner.java'; Prefix = '// arc:'; DisabledPrefix = '// disabled arc:'; Body = 'class LexicalOwner {}' },
    [pscustomobject]@{ Name = 'javascript-module'; Path = 'src/lexical_owner.mjs'; Prefix = '// arc:'; DisabledPrefix = '// disabled arc:'; Body = 'export class LexicalOwner {}' },
    [pscustomobject]@{ Name = 'python'; Path = 'src/lexical_owner.py'; Prefix = '# arc:'; DisabledPrefix = '# disabled arc:'; Body = "class LexicalOwner:`n    pass" },
    [pscustomobject]@{ Name = 'csharp'; Path = 'src/LexicalOwner.cs'; Prefix = '// arc:'; DisabledPrefix = '// disabled arc:'; Body = 'class LexicalOwner {}' },
    [pscustomobject]@{ Name = 'rust'; Path = 'src/lexical_owner.rs'; Prefix = '// arc:'; DisabledPrefix = '// disabled arc:'; Body = 'struct LexicalOwner { value: i32 }' }
  )) {
    $encodedMarkers = @($semanticMarkerPayloads | ForEach-Object { "$($languageMarkerCase.Prefix)$_" }) -join "`n"
    $languageValidSource = "$encodedMarkers`n$($languageMarkerCase.Body)`n$($languageMarkerCase.Prefix)@ownership-end RESP-LEXICAL"
    $languageValidResult = Invoke-LexicalSourceInventoryProbe "semantic-$($languageMarkerCase.Name)-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $languageValidSource $languageMarkerCase.Path
    if ($languageValidResult.Errors.Count -ne 0 -or $languageValidResult.OwnerCount -ne 1) {
      throw "language-valid $($languageMarkerCase.Name) semantic markers were not consumed ($($lexicalLineEnding.Name)): $($languageValidResult.Errors -join '; ')"
    }
    Write-Output "PASS: language-valid $($languageMarkerCase.Name) semantic markers compose an active owner ($($lexicalLineEnding.Name))"

    $disabledMarkers = (@($semanticMarkerPayloads | ForEach-Object { "$($languageMarkerCase.DisabledPrefix)$_" }) + "$($languageMarkerCase.DisabledPrefix)@ownership-end RESP-LEXICAL") -join "`n"
    $disabledResult = Invoke-LexicalSourceInventoryProbe "semantic-disabled-$($languageMarkerCase.Name)-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $disabledMarkers $languageMarkerCase.Path
    if ($disabledResult.OwnerCount -ne 0 -or $disabledResult.Errors -cnotcontains 'responsibility-evidence-missing') {
      throw "ordinary commented-out $($languageMarkerCase.Name) markers became active ($($lexicalLineEnding.Name))"
    }
    Write-Output "PASS: ordinary commented-out $($languageMarkerCase.Name) markers remain inert ($($lexicalLineEnding.Name))"
  }

  $commentedOwnerSource = @"
/*
@responsibility RESP-LEXICAL
@owner-symbol LexicalOwner
@public-symbol LexicalOwner
@owned-capability CAP-LEXICAL
@effect route registration
@architecture-authority target-exemplar
@co-location-policy feature-local
@verification-owner VERIFY-OWNER-LEXICAL
@ownership-begin RESP-LEXICAL
route LexicalOwner -> LexicalProvider
@ownership-end RESP-LEXICAL
*/
"@
  $commentedOwner = Invoke-LexicalSourceInventoryProbe "commented-owner-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $commentedOwnerSource 'lib/commented_owner.dart'
  if ($commentedOwner.OwnerCount -ne 0 -or $commentedOwner.Errors -cnotcontains 'responsibility-evidence-missing') {
    throw "wholly commented production owner/route became active ($($lexicalLineEnding.Name))"
  }
  Write-Output "PASS: wholly commented production owner/route remains inactive ($($lexicalLineEnding.Name))"

  foreach ($roguePrefixCase in @(
    [pscustomobject]@{ Name = 'semicolon-call'; Code = ';danger()' },
    [pscustomobject]@{ Name = 'decrement'; Code = '--counter' },
    [pscustomobject]@{ Name = 'pointer-assignment'; Code = '*ptr = value' },
    [pscustomobject]@{ Name = 'inline-block-comment-then-call'; Code = '/* note */ danger()' }
  )) {
    $rogueSource = "$lexicalOwnerMetadata`nclass LexicalOwner { int run() { return 1; } }`n$lexicalOwnerEnd`n$($roguePrefixCase.Code)"
    $rogueResult = Invoke-LexicalSourceInventoryProbe "$($roguePrefixCase.Name)-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $rogueSource
    if ($rogueResult.Errors -cnotcontains 'responsibility-evidence-missing') {
      throw "$($roguePrefixCase.Name) markerless executable content was incorrectly classified as comment-only ($($lexicalLineEnding.Name))"
    }
    Write-Output "PASS: $($roguePrefixCase.Name) remains unowned executable content ($($lexicalLineEnding.Name))"
  }

  $bracePositiveSource = @"
$lexicalOwnerMetadata
class LexicalOwner {
  string closeBrace = "}";
  string openBrace = '{';
  // comment braces are inert: } {
  /* block comment braces are inert: } { */
  int run() {
    return 1;
  }
  }
$lexicalOwnerEnd
"@
  $bracePositive = Invoke-LexicalSourceInventoryProbe "brace-positive-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $bracePositiveSource
  if ($bracePositive.Errors.Count -ne 0 -or $bracePositive.OwnerCount -ne 1) {
    throw "braces in strings/comments must not truncate a valid owner block ($($lexicalLineEnding.Name)): $($bracePositive.Errors -join '; ')"
  }
  Write-Output "PASS: braces in strings/comments preserve the valid owner block ($($lexicalLineEnding.Name))"

  $braceRogueSource = @"
$lexicalOwnerMetadata
class LexicalOwner {
  string openingBrace = "{";
  /* an inert opening brace: { */
  int run() { return 1; }
}
$lexicalOwnerEnd
danger()
"@
  $braceRogue = Invoke-LexicalSourceInventoryProbe "brace-rogue-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $braceRogueSource
  if ($braceRogue.Errors -cnotcontains 'responsibility-evidence-missing') {
    throw "braces in strings/comments swallowed later rogue code ($($lexicalLineEnding.Name))"
  }
  Write-Output "PASS: braces in strings/comments cannot swallow later rogue code ($($lexicalLineEnding.Name))"

  $javascriptOwnerMetadata = @($lexicalOwnerMetadata -split '\r?\n' | Where-Object { $_ -ne '' } | ForEach-Object { "// arc:$_" }) -join "`n"
  $javascriptOwnerEnd = '// arc:@ownership-end RESP-LEXICAL'
  $javascriptRegexRogueSource = @"
$javascriptOwnerMetadata
class LexicalOwner {
  run(value) {
    const openingBrace = /{/g;
    return openingBrace.test(value);
  }
}
$javascriptOwnerEnd
danger()
"@
  $javascriptRegexRogue = Invoke-LexicalSourceInventoryProbe "javascript-regex-rogue-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $javascriptRegexRogueSource 'src/lexical.js'
  if ($javascriptRegexRogue.Errors -cnotcontains 'responsibility-evidence-missing') {
    throw "JavaScript regex-literal braces swallowed later rogue code ($($lexicalLineEnding.Name))"
  }
  Write-Output "PASS: JavaScript regex-literal braces are inert and later rogue code remains unowned ($($lexicalLineEnding.Name))"

  $javascriptTemplateRogueSource = $javascriptOwnerMetadata + "`n" + @'
class LexicalOwner {
  run(value) {
    const payload = `
literal braces are inert: { }
${value ? "{" : "}"}
${value ? { nested: "}" }.nested : "{"}
${`nested template interpolation: ${value}`}
`;
    return payload;
  }
}
danger()
'@
  $javascriptTemplateRogueSource = $javascriptTemplateRogueSource.Replace("`ndanger()", "`n$javascriptOwnerEnd`ndanger()")
  $javascriptTemplateRogue = Invoke-LexicalSourceInventoryProbe "javascript-template-rogue-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $javascriptTemplateRogueSource 'src/lexical.ts'
  if ($javascriptTemplateRogue.Errors -cnotcontains 'responsibility-evidence-missing') {
    throw "JavaScript multiline template-literal braces swallowed later rogue code ($($lexicalLineEnding.Name))"
  }
  Write-Output "PASS: JavaScript multiline template-literal braces are inert and later rogue code remains unowned ($($lexicalLineEnding.Name))"

  $javascriptTemplateDivisionSource = $javascriptOwnerMetadata + "`n" + @'
class LexicalOwner {
  run() {
    const ratio = `
template operand
` / 2;
    return ratio;
  }
}
'@
  $javascriptTemplateDivisionSource += "`n$javascriptOwnerEnd"
  $javascriptTemplateDivision = Invoke-LexicalSourceInventoryProbe "javascript-template-division-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $javascriptTemplateDivisionSource 'src/lexical.ts'
  if ($javascriptTemplateDivision.Errors.Count -ne 0 -or $javascriptTemplateDivision.OwnerCount -ne 1) {
    throw "JavaScript division after a closed multiline template must remain valid ($($lexicalLineEnding.Name)): $($javascriptTemplateDivision.Errors -join '; ')"
  }
  Write-Output "PASS: JavaScript division after a closed multiline template remains valid ($($lexicalLineEnding.Name))"

  foreach ($javascriptTemplateDivisionCase in @(
    [pscustomobject]@{
      Name = 'postfix increment and decrement before division'
      Source = $javascriptOwnerMetadata + "`n" + @'
class LexicalOwner {
  run(value) {
    const incrementRatio = `${value++ / 2}`;
    const decrementRatio = `${value-- / 2}`;
    return [incrementRatio, decrementRatio];
  }
}
'@
    },
    [pscustomobject]@{
      Name = 'multiline operand before division'
      Source = $javascriptOwnerMetadata + "`n" + @'
class LexicalOwner {
  run(value) {
    const ratio = `${value
      / 2}`;
    return ratio;
  }
}
'@
    }
  )) {
    $javascriptTemplateDivisionCase.Source += "`n$javascriptOwnerEnd"
    $templateDivisionResult = Invoke-LexicalSourceInventoryProbe "template-expression-division-$($javascriptTemplateDivisionCase.Name.Replace(' ', '-'))-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $javascriptTemplateDivisionCase.Source 'src/lexical.ts'
    if ($templateDivisionResult.Errors.Count -ne 0 -or $templateDivisionResult.OwnerCount -ne 1) {
      $freshLexerFormatterResidualFailures.Add("C2a $($javascriptTemplateDivisionCase.Name) must remain division in template interpolation ($($lexicalLineEnding.Name)): $($templateDivisionResult.Errors -join '; ')")
    }
  }

  $javascriptTemplateOperatorRegexSource = $javascriptOwnerMetadata + "`n" + @'
class LexicalOwner {
  run(value, text) {
    const incrementThenAdd = `${value+++ /\{/.test(text)}`;
    const decrementThenSubtract = `${value--- /\{/.test(text)}`;
    return [incrementThenAdd, decrementThenSubtract];
  }
}
'@
  $javascriptTemplateOperatorRegexSource += "`n$javascriptOwnerEnd"
  $javascriptTemplateOperatorRegex = Invoke-LexicalSourceInventoryProbe "template-operator-regex-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $javascriptTemplateOperatorRegexSource 'src/lexical.ts'
  if ($javascriptTemplateOperatorRegex.Errors.Count -ne 0 -or $javascriptTemplateOperatorRegex.OwnerCount -ne 1) {
    $freshLexerFormatterResidualFailures.Add("C2a a third plus/minus must remain a binary operator before an interpolation regex ($($lexicalLineEnding.Name)): $($javascriptTemplateOperatorRegex.Errors -join '; ')")
  }

  $javascriptTemplateKeywordRegexSource = $javascriptOwnerMetadata + "`n" + @'
class LexicalOwner {
  run(value) {
    const kind = `${typeof
      /\{/.test(value)}`;
    return kind;
  }
}
'@
  $javascriptTemplateKeywordRegexSource += "`n$javascriptOwnerEnd"
  $javascriptTemplateKeywordRegex = Invoke-LexicalSourceInventoryProbe "template-keyword-regex-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $javascriptTemplateKeywordRegexSource 'src/lexical.ts'
  if ($javascriptTemplateKeywordRegex.Errors.Count -ne 0 -or $javascriptTemplateKeywordRegex.OwnerCount -ne 1) {
    $freshLexerFormatterResidualFailures.Add("C2a a carried unary keyword must permit a real regex operand on the next interpolation line ($($lexicalLineEnding.Name)): $($javascriptTemplateKeywordRegex.Errors -join '; ')")
  }

  $javascriptTemplateRegexSource = $javascriptOwnerMetadata + "`n" + @'
class LexicalOwner {
  run(value) {
    const matches = `${value ? /}/g.test(value) : false}`;
    return matches;
  }
}
'@
  $javascriptTemplateRegexSource += "`n$javascriptOwnerEnd"
  $javascriptTemplateRegex = Invoke-LexicalSourceInventoryProbe "template-regex-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $javascriptTemplateRegexSource 'src/lexical.ts'
  if ($javascriptTemplateRegex.Errors.Count -ne 0 -or $javascriptTemplateRegex.OwnerCount -ne 1) {
    $freshLexerFormatterResidualFailures.Add("C2a a real regex literal in template interpolation must remain inert ($($lexicalLineEnding.Name)): $($javascriptTemplateRegex.Errors -join '; ')")
  }

  $javascriptTemplateRegexRogueSource = $javascriptOwnerMetadata + "`n" + @'
class LexicalOwner {
  run(value) {
    const matches = `${value ? /{/g.test(value) : false}`;
    return matches;
  }
}
danger()
'@
  $javascriptTemplateRegexRogueSource = $javascriptTemplateRegexRogueSource.Replace("`ndanger()", "`n$javascriptOwnerEnd`ndanger()")
  $javascriptTemplateRegexRogue = Invoke-LexicalSourceInventoryProbe "template-regex-rogue-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $javascriptTemplateRegexRogueSource 'src/lexical.ts'
  if ($javascriptTemplateRegexRogue.Errors -cnotcontains 'responsibility-evidence-missing') {
    $freshLexerFormatterResidualFailures.Add("C2a an opening brace in a real interpolation regex must not swallow later rogue code ($($lexicalLineEnding.Name))")
  }

  $unterminatedJavascriptTemplateRegexSource = $javascriptOwnerMetadata + "`n" + @'
class LexicalOwner {
  run(value) {
    const matches = `${value ? /unterminated
      : false}`;
    return matches;
  }
}
'@
  $unterminatedJavascriptTemplateRegexSource += "`n$javascriptOwnerEnd"
  $unterminatedJavascriptTemplateRegex = Invoke-LexicalSourceInventoryProbe "unterminated-template-regex-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $unterminatedJavascriptTemplateRegexSource 'src/lexical.ts'
  if ($unterminatedJavascriptTemplateRegex.Errors -cnotcontains 'responsibility-evidence-missing') {
    $freshLexerFormatterResidualFailures.Add("C2a an unclosed real regex literal in template interpolation must fail closed ($($lexicalLineEnding.Name))")
  }

  foreach ($javascriptNestedStatementRegexCase in @(
    [pscustomobject]@{
      Name = 'if control header'
      Statement = 'if (value) /}/.test(value);'
      RegexBrace = '}'
    },
    [pscustomobject]@{
      Name = 'else statement'
      Statement = "if (!value) value = 'fallback'; else /{/.test(value);"
      RegexBrace = '{'
    },
    [pscustomobject]@{
      Name = 'do statement'
      Statement = 'do /}/.test(value); while (false);'
      RegexBrace = '}'
    }
  )) {
    $javascriptNestedStatementRegexSource = $javascriptOwnerMetadata + "`n" + @'
class LexicalOwner {
  run(value) {
    const nested = `${`${(() => {
'@ + "`n      $($javascriptNestedStatementRegexCase.Statement)`n" + @'
      return value;
    })()}`}`;
    return nested;
  }
}
'@
    $javascriptNestedStatementRegexSource += "`n$javascriptOwnerEnd"
    $javascriptNestedStatementRegex = Invoke-LexicalSourceInventoryProbe "nested-statement-regex-$($javascriptNestedStatementRegexCase.Name.Replace(' ', '-'))-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $javascriptNestedStatementRegexSource 'src/lexical.ts'
    if ($javascriptNestedStatementRegex.Errors.Count -ne 0 -or $javascriptNestedStatementRegex.OwnerCount -ne 1) {
      $freshLexerFormatterResidualFailures.Add("C2a a regex literal after $($javascriptNestedStatementRegexCase.Name) must remain inert inside nested template interpolation ($($lexicalLineEnding.Name)): $($javascriptNestedStatementRegex.Errors -join '; ')")
    }
    $renderedStatementRegexSource = [regex]::Replace($javascriptNestedStatementRegexSource, '\r\n|\r|\n', $lexicalLineEnding.NewLine)
    $statementRegexLexicalLines = @(Get-ArcSourceLexicalLines -SourceText $renderedStatementRegexSource -SourcePath 'src/lexical.ts')
    $statementRegexLexicalLine = @($statementRegexLexicalLines | Where-Object { $_.Raw.IndexOf($javascriptNestedStatementRegexCase.Statement, [StringComparison]::Ordinal) -ge 0 })
    if (
      $statementRegexLexicalLine.Count -ne 1 -or
      $statementRegexLexicalLine[0].StructuralText.IndexOf($javascriptNestedStatementRegexCase.RegexBrace, [StringComparison]::Ordinal) -ge 0
    ) {
      $freshLexerFormatterResidualFailures.Add("C2a $($javascriptNestedStatementRegexCase.Name) regex braces must be absent from structural token output ($($lexicalLineEnding.Name))")
    }
  }

  $javascriptNestedSpreadRegexSource = $javascriptOwnerMetadata + "`n" + @'
class LexicalOwner {
  run() {
    const nested = `${`${(() => {
      const spread = [... /}/g];
      return spread.length;
    })()}`}`;
    return nested;
  }
}
'@
  $javascriptNestedSpreadRegexSource += "`n$javascriptOwnerEnd"
  $javascriptNestedSpreadRegex = Invoke-LexicalSourceInventoryProbe "nested-spread-regex-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $javascriptNestedSpreadRegexSource 'src/lexical.ts'
  if ($javascriptNestedSpreadRegex.Errors.Count -ne 0 -or $javascriptNestedSpreadRegex.OwnerCount -ne 1) {
    $freshLexerFormatterResidualFailures.Add("C2a a regex literal after spread must remain inert inside nested template interpolation ($($lexicalLineEnding.Name)): $($javascriptNestedSpreadRegex.Errors -join '; ')")
  }
  $renderedSpreadRegexSource = [regex]::Replace($javascriptNestedSpreadRegexSource, '\r\n|\r|\n', $lexicalLineEnding.NewLine)
  $spreadRegexLexicalLines = @(Get-ArcSourceLexicalLines -SourceText $renderedSpreadRegexSource -SourcePath 'src/lexical.ts')
  $spreadRegexLexicalLine = @($spreadRegexLexicalLines | Where-Object { $_.Raw.IndexOf('[... /}/g]', [StringComparison]::Ordinal) -ge 0 })
  if (
    $spreadRegexLexicalLine.Count -ne 1 -or
    $spreadRegexLexicalLine[0].StructuralText.IndexOf('}', [StringComparison]::Ordinal) -ge 0
  ) {
    $freshLexerFormatterResidualFailures.Add("C2a a spread-context regex brace must be absent from structural token output ($($lexicalLineEnding.Name))")
  }

  $javascriptNestedStatementDivisionSource = $javascriptOwnerMetadata + "`n" + @'
class LexicalOwner {
  run(ready, value, object, member, values) {
    const nested = `${`${(() => {
      if (ready) (value) / 2;
      else object.value / 2;
      do value++ / 2; while (false);
      return [...values, member.value / 2, (value) / 2].length;
    })()}`}`;
    return nested;
  }
}
'@
  $javascriptNestedStatementDivisionSource += "`n$javascriptOwnerEnd"
  $javascriptNestedStatementDivision = Invoke-LexicalSourceInventoryProbe "nested-statement-division-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $javascriptNestedStatementDivisionSource 'src/lexical.ts'
  if ($javascriptNestedStatementDivision.Errors.Count -ne 0 -or $javascriptNestedStatementDivision.OwnerCount -ne 1) {
    $freshLexerFormatterResidualFailures.Add("C2a value-ending parens, member access, and postfix updates must keep slash as division in nested statement contexts ($($lexicalLineEnding.Name)): $($javascriptNestedStatementDivision.Errors -join '; ')")
  }

  $javascriptNestedStatementRegexRogueSource = $javascriptOwnerMetadata + "`n" + @'
class LexicalOwner {
  run(value) {
    const nested = `${`${(() => {
      if (value) /{/.test(value);
      return value;
    })()}`}`;
    return nested;
  }
}
danger()
'@
  $javascriptNestedStatementRegexRogueSource = $javascriptNestedStatementRegexRogueSource.Replace("`ndanger()", "`n$javascriptOwnerEnd`ndanger()")
  $javascriptNestedStatementRegexRogue = Invoke-LexicalSourceInventoryProbe "nested-statement-regex-rogue-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $javascriptNestedStatementRegexRogueSource 'src/lexical.ts'
  if ($javascriptNestedStatementRegexRogue.Errors -cnotcontains 'responsibility-evidence-missing') {
    $freshLexerFormatterResidualFailures.Add("C2a an opening brace in a statement-position regex must not swallow later rogue code ($($lexicalLineEnding.Name))")
  }

  $unterminatedJavascriptStatementRegexSource = $javascriptOwnerMetadata + "`n" + @'
class LexicalOwner {
  run(value) {
    if (value) /unterminated
    return value;
  }
}
'@
  $unterminatedJavascriptStatementRegexSource += "`n$javascriptOwnerEnd"
  $unterminatedJavascriptStatementRegex = Invoke-LexicalSourceInventoryProbe "unterminated-statement-regex-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $unterminatedJavascriptStatementRegexSource 'src/lexical.ts'
  if ($unterminatedJavascriptStatementRegex.Errors -cnotcontains 'responsibility-evidence-missing') {
    $freshLexerFormatterResidualFailures.Add("C2a an unclosed statement-position regex literal must fail closed ($($lexicalLineEnding.Name))")
  }

  $javascriptOrdinaryBacktickStringSource = $javascriptOwnerMetadata + "`n" + @'
class LexicalOwner {
  run(value) {
    const doubleQuoted = `${value ? "a`" : "b"}`;
    const singleQuoted = `${value ? 'a`' : 'b'}`;
    const escapedQuotes = `${value ? "a\"b" : 'a\'b'}`;
    return [doubleQuoted, singleQuoted, escapedQuotes];
  }
}
'@
  $javascriptOrdinaryBacktickStringSource += "`n$javascriptOwnerEnd"
  $javascriptOrdinaryBacktickString = Invoke-LexicalSourceInventoryProbe "ordinary-backtick-string-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $javascriptOrdinaryBacktickStringSource 'src/lexical.ts'
  if ($javascriptOrdinaryBacktickString.Errors.Count -ne 0 -or $javascriptOrdinaryBacktickString.OwnerCount -ne 1) {
    $freshLexerFormatterResidualFailures.Add("C2b backticks must be ordinary characters and backslashes the escape in JavaScript quoted strings ($($lexicalLineEnding.Name)): $($javascriptOrdinaryBacktickString.Errors -join '; ')")
  }

  foreach ($unterminatedOrdinaryStringCase in @(
    [pscustomobject]@{
      Name = 'ordinary double-quoted string at EOL'
      Source = $javascriptOwnerMetadata + "`n" + @'
class LexicalOwner {
  run() {
    const payload = "unterminated
    return payload;
  }
}
'@
    },
    [pscustomobject]@{
      Name = 'ordinary single-quoted string in interpolation at EOL'
      Source = $javascriptOwnerMetadata + "`n" + @'
class LexicalOwner {
  run(value) {
    const payload = `${value ? 'unterminated
      : 'fallback'}`;
    return payload;
  }
}
'@
    }
  )) {
    $unterminatedOrdinaryStringCase.Source += "`n$javascriptOwnerEnd"
    $unterminatedOrdinaryString = Invoke-LexicalSourceInventoryProbe "unterminated-ordinary-string-$($unterminatedOrdinaryStringCase.Name.Replace(' ', '-'))-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $unterminatedOrdinaryStringCase.Source 'src/lexical.ts'
    if ($unterminatedOrdinaryString.Errors -cnotcontains 'responsibility-evidence-missing') {
      $freshLexerFormatterResidualFailures.Add("C2b $($unterminatedOrdinaryStringCase.Name) must fail closed ($($lexicalLineEnding.Name))")
    }
  }

  $typedBraceSource = $validJavascriptOwnerMetadata + "`n" + @'
class LexicalOwner {
  run(value) {
    if (value) { value++; } /}/.test(String(value));
    const ratio = { value: 4 }.value / 2;
    return ratio;
  }
}
'@
  $typedBraceSource += "`n$validJavascriptOwnerEnd"
  $typedBraceResult = Invoke-LexicalSourceInventoryProbe "typed-brace-positive-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $typedBraceSource 'src/lexical.js'
  $renderedTypedBraceSource = [regex]::Replace($typedBraceSource, '\r\n|\r|\n', $lexicalLineEnding.NewLine)
  $typedBraceLines = @(Get-ArcSourceLexicalLines -SourceText $renderedTypedBraceSource -SourcePath 'src/lexical.js')
  $blockRegexLine = @($typedBraceLines | Where-Object { $_.Raw.IndexOf('if (value) { value++; } /}/', [StringComparison]::Ordinal) -ge 0 })
  $objectDivisionLine = @($typedBraceLines | Where-Object { $_.Raw.IndexOf('const ratio = { value: 4 }.value / 2;', [StringComparison]::Ordinal) -ge 0 })
  if (
    $typedBraceResult.Errors.Count -ne 0 -or
    $typedBraceResult.OwnerCount -ne 1 -or
    $blockRegexLine.Count -ne 1 -or
    @([regex]::Matches($blockRegexLine[0].StructuralText, '\}')).Count -ne 1 -or
    $objectDivisionLine.Count -ne 1 -or
    $objectDivisionLine[0].Ambiguous -or
    $objectDivisionLine[0].StructuralText.IndexOf('/ 2', [StringComparison]::Ordinal) -lt 0
  ) {
    $freshLexerFormatterResidualFailures.Add("C2a typed brace contexts must allow regex after a block close and division after an object close ($($lexicalLineEnding.Name)): $($typedBraceResult.Errors -join '; ')")
  }

  $typedBraceRogueSource = $validJavascriptOwnerMetadata + "`n" + @'
class LexicalOwner {
  run(value) {
    if (value) { value++; } /{/.test(String(value));
    return value;
  }
}
danger();
'@
  $typedBraceRogueSource = $typedBraceRogueSource.Replace("`ndanger();", "`n$validJavascriptOwnerEnd`ndanger();")
  $typedBraceRogue = Invoke-LexicalSourceInventoryProbe "typed-brace-rogue-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $typedBraceRogueSource 'src/lexical.js'
  $typedBraceRogueLines = @(Get-ArcSourceLexicalLines -SourceText ([regex]::Replace($typedBraceRogueSource, '\r\n|\r|\n', $lexicalLineEnding.NewLine)) -SourcePath 'src/lexical.js')
  $typedBraceRogueRegexLine = @($typedBraceRogueLines | Where-Object { $_.Raw.IndexOf('/{/.test', [StringComparison]::Ordinal) -ge 0 })
  if (
    $typedBraceRogue.Errors -cnotcontains 'responsibility-evidence-missing' -or
    $typedBraceRogueRegexLine.Count -ne 1 -or
    $typedBraceRogueRegexLine[0].Ambiguous -or
    @([regex]::Matches($typedBraceRogueRegexLine[0].StructuralText, '\{')).Count -ne 1
  ) {
    $freshLexerFormatterResidualFailures.Add("C2a a block-following regex brace must stay inert so later rogue code remains unowned ($($lexicalLineEnding.Name))")
  }

  $forAwaitSource = $validJavascriptOwnerMetadata + "`n" + @'
class LexicalOwner {
  async run(values) {
    for await (const value of values) /}/.test(String(value));
    for await (const value of values) (value) / 2;
  }
}
'@
  $forAwaitSource += "`n$validJavascriptOwnerEnd"
  $forAwaitResult = Invoke-LexicalSourceInventoryProbe "for-await-positive-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $forAwaitSource 'src/lexical.js'
  $forAwaitLines = @(Get-ArcSourceLexicalLines -SourceText ([regex]::Replace($forAwaitSource, '\r\n|\r|\n', $lexicalLineEnding.NewLine)) -SourcePath 'src/lexical.js')
  $forAwaitRegexLine = @($forAwaitLines | Where-Object { $_.Raw.IndexOf('for await (const value of values) /}/', [StringComparison]::Ordinal) -ge 0 })
  $forAwaitDivisionLine = @($forAwaitLines | Where-Object { $_.Raw.IndexOf('for await (const value of values) (value) / 2;', [StringComparison]::Ordinal) -ge 0 })
  if (
    $forAwaitResult.Errors.Count -ne 0 -or
    $forAwaitResult.OwnerCount -ne 1 -or
    $forAwaitRegexLine.Count -ne 1 -or
    $forAwaitRegexLine[0].StructuralText.IndexOf('}', [StringComparison]::Ordinal) -ge 0 -or
    $forAwaitDivisionLine.Count -ne 1 -or
    $forAwaitDivisionLine[0].Ambiguous -or
    $forAwaitDivisionLine[0].StructuralText.IndexOf('/ 2', [StringComparison]::Ordinal) -lt 0
  ) {
    $freshLexerFormatterResidualFailures.Add("C2a for-await must preserve its pending control-header context for regex and division bodies ($($lexicalLineEnding.Name)): $($forAwaitResult.Errors -join '; ')")
  }

  $forAwaitRogueSource = $validJavascriptOwnerMetadata + "`n" + @'
class LexicalOwner {
  async run(values) {
    for await (const value of values) /{/.test(String(value));
  }
}
danger();
'@
  $forAwaitRogueSource = $forAwaitRogueSource.Replace("`ndanger();", "`n$validJavascriptOwnerEnd`ndanger();")
  $forAwaitRogue = Invoke-LexicalSourceInventoryProbe "for-await-rogue-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $forAwaitRogueSource 'src/lexical.js'
  $forAwaitRogueLines = @(Get-ArcSourceLexicalLines -SourceText ([regex]::Replace($forAwaitRogueSource, '\r\n|\r|\n', $lexicalLineEnding.NewLine)) -SourcePath 'src/lexical.js')
  $forAwaitRogueRegexLine = @($forAwaitRogueLines | Where-Object { $_.Raw.IndexOf('/{/.test', [StringComparison]::Ordinal) -ge 0 })
  if (
    $forAwaitRogue.Errors -cnotcontains 'responsibility-evidence-missing' -or
    $forAwaitRogueRegexLine.Count -ne 1 -or
    $forAwaitRogueRegexLine[0].Ambiguous -or
    $forAwaitRogueRegexLine[0].StructuralText.IndexOf('{', [StringComparison]::Ordinal) -ge 0
  ) {
    $freshLexerFormatterResidualFailures.Add("C2a a for-await body regex brace must stay inert so later rogue code remains unowned ($($lexicalLineEnding.Name))")
  }

  $restrictedStatementSource = $validJavascriptOwnerMetadata + "`n" + @'
class LexicalOwner {
  run(value) {
    outer: while (value) {
      break outer
      /}/.test(String(value));
    }
    outer2: do {
      continue outer2
      /{/.test(String(value));
    } while (value);
    debugger
    /}/.test(String(value));
    const ratio = value
      / 2;
    return ratio;
  }
}
'@
  $restrictedStatementSource += "`n$validJavascriptOwnerEnd"
  $restrictedStatementResult = Invoke-LexicalSourceInventoryProbe "restricted-statement-positive-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $restrictedStatementSource 'src/lexical.js'
  $restrictedStatementLines = @(Get-ArcSourceLexicalLines -SourceText ([regex]::Replace($restrictedStatementSource, '\r\n|\r|\n', $lexicalLineEnding.NewLine)) -SourcePath 'src/lexical.js')
  $restrictedRegexLines = @($restrictedStatementLines | Where-Object { $_.Raw.IndexOf('/}/.test', [StringComparison]::Ordinal) -ge 0 -or $_.Raw.IndexOf('/{/.test', [StringComparison]::Ordinal) -ge 0 })
  $restrictedDivisionLine = @($restrictedStatementLines | Where-Object { $_.Raw.IndexOf('/ 2;', [StringComparison]::Ordinal) -ge 0 })
  if (
    $restrictedStatementResult.Errors.Count -ne 0 -or
    $restrictedStatementResult.OwnerCount -ne 1 -or
    $restrictedRegexLines.Count -ne 3 -or
    @($restrictedRegexLines | Where-Object { $_.Ambiguous -or $_.StructuralText.IndexOf('{', [StringComparison]::Ordinal) -ge 0 -or $_.StructuralText.IndexOf('}', [StringComparison]::Ordinal) -ge 0 }).Count -ne 0 -or
    $restrictedDivisionLine.Count -ne 1 -or
    $restrictedDivisionLine[0].Ambiguous -or
    $restrictedDivisionLine[0].StructuralText.IndexOf('/ 2', [StringComparison]::Ordinal) -lt 0
  ) {
    $freshLexerFormatterResidualFailures.Add("C2a break/continue labels and debugger must enter statement-start at EOL without reclassifying operand continuation as ASI ($($lexicalLineEnding.Name)): $($restrictedStatementResult.Errors -join '; ')")
  }

  $restrictedRogueSource = $validJavascriptOwnerMetadata + "`n" + @'
class LexicalOwner {
  run(value) {
    debugger
    /{/.test(String(value));
    return value;
  }
}
danger();
'@
  $restrictedRogueSource = $restrictedRogueSource.Replace("`ndanger();", "`n$validJavascriptOwnerEnd`ndanger();")
  $restrictedRogue = Invoke-LexicalSourceInventoryProbe "restricted-statement-rogue-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $restrictedRogueSource 'src/lexical.js'
  $restrictedRogueLines = @(Get-ArcSourceLexicalLines -SourceText ([regex]::Replace($restrictedRogueSource, '\r\n|\r|\n', $lexicalLineEnding.NewLine)) -SourcePath 'src/lexical.js')
  $restrictedRogueRegexLine = @($restrictedRogueLines | Where-Object { $_.Raw.IndexOf('/{/.test', [StringComparison]::Ordinal) -ge 0 })
  if (
    $restrictedRogue.Errors -cnotcontains 'responsibility-evidence-missing' -or
    $restrictedRogueRegexLine.Count -ne 1 -or
    $restrictedRogueRegexLine[0].Ambiguous -or
    $restrictedRogueRegexLine[0].StructuralText.IndexOf('{', [StringComparison]::Ordinal) -ge 0
  ) {
    $freshLexerFormatterResidualFailures.Add("C2a a restricted-statement EOL regex brace must stay inert so later rogue code remains unowned ($($lexicalLineEnding.Name))")
  }

  $typescriptNonNullSource = $validJavascriptOwnerMetadata + "`n" + @'
class LexicalOwner {
  run(value: number, text: string) {
    const ratio = value! / 2;
    const prefix = ! /}/.test(text);
    const binary = value != /{/.test(text);
    return [ratio, prefix, binary];
  }
}
'@
  $typescriptNonNullSource += "`n$validJavascriptOwnerEnd"
  $typescriptNonNullResult = Invoke-LexicalSourceInventoryProbe "typescript-non-null-positive-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $typescriptNonNullSource 'src/lexical.ts'
  $typescriptNonNullLines = @(Get-ArcSourceLexicalLines -SourceText ([regex]::Replace($typescriptNonNullSource, '\r\n|\r|\n', $lexicalLineEnding.NewLine)) -SourcePath 'src/lexical.ts')
  $typescriptPostfixLine = @($typescriptNonNullLines | Where-Object { $_.Raw.IndexOf('value! / 2;', [StringComparison]::Ordinal) -ge 0 })
  $typescriptPrefixBinaryLines = @($typescriptNonNullLines | Where-Object { $_.Raw.IndexOf('const prefix =', [StringComparison]::Ordinal) -ge 0 -or $_.Raw.IndexOf('const binary =', [StringComparison]::Ordinal) -ge 0 })
  if (
    $typescriptNonNullResult.Errors.Count -ne 0 -or
    $typescriptNonNullResult.OwnerCount -ne 1 -or
    $typescriptPostfixLine.Count -ne 1 -or
    $typescriptPostfixLine[0].Ambiguous -or
    $typescriptPostfixLine[0].StructuralText.IndexOf('/ 2', [StringComparison]::Ordinal) -lt 0 -or
    $typescriptPrefixBinaryLines.Count -ne 2 -or
    @($typescriptPrefixBinaryLines | Where-Object { $_.Ambiguous -or $_.StructuralText.IndexOf('{', [StringComparison]::Ordinal) -ge 0 -or $_.StructuralText.IndexOf('}', [StringComparison]::Ordinal) -ge 0 }).Count -ne 0
  ) {
    $freshLexerFormatterResidualFailures.Add("C2a TypeScript postfix non-null must preserve an operand while prefix/binary bang remains an operator ($($lexicalLineEnding.Name)): $($typescriptNonNullResult.Errors -join '; ')")
  }

  $typescriptBangRogueSource = $validJavascriptOwnerMetadata + "`n" + @'
class LexicalOwner {
  run(text: string) {
    const prefix = ! /{/.test(text);
    return prefix;
  }
}
danger();
'@
  $typescriptBangRogueSource = $typescriptBangRogueSource.Replace("`ndanger();", "`n$validJavascriptOwnerEnd`ndanger();")
  $typescriptBangRogue = Invoke-LexicalSourceInventoryProbe "typescript-bang-rogue-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $typescriptBangRogueSource 'src/lexical.ts'
  $typescriptBangRogueLines = @(Get-ArcSourceLexicalLines -SourceText ([regex]::Replace($typescriptBangRogueSource, '\r\n|\r|\n', $lexicalLineEnding.NewLine)) -SourcePath 'src/lexical.ts')
  $typescriptBangRogueRegexLine = @($typescriptBangRogueLines | Where-Object { $_.Raw.IndexOf('/{/.test', [StringComparison]::Ordinal) -ge 0 })
  if (
    $typescriptBangRogue.Errors -cnotcontains 'responsibility-evidence-missing' -or
    $typescriptBangRogueRegexLine.Count -ne 1 -or
    $typescriptBangRogueRegexLine[0].Ambiguous -or
    $typescriptBangRogueRegexLine[0].StructuralText.IndexOf('{', [StringComparison]::Ordinal) -ge 0
  ) {
    $freshLexerFormatterResidualFailures.Add("C2a a prefix-bang regex brace must stay inert so later rogue code remains unowned ($($lexicalLineEnding.Name))")
  }

  $continuedStringSource = $validJavascriptOwnerMetadata + "`n" + @'
class LexicalOwner {
  run() {
    const doubleQuoted = "open \
brace { and close }";
    const singleQuoted = 'open \
brace { and close }';
    const ratio = "four\
".length / 2;
    return [doubleQuoted, singleQuoted, ratio];
  }
}
'@
  $continuedStringSource += "`n$validJavascriptOwnerEnd"
  $continuedStringResult = Invoke-LexicalSourceInventoryProbe "continued-string-positive-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $continuedStringSource 'src/lexical.js'
  $continuedStringLines = @(Get-ArcSourceLexicalLines -SourceText ([regex]::Replace($continuedStringSource, '\r\n|\r|\n', $lexicalLineEnding.NewLine)) -SourcePath 'src/lexical.js')
  $continuedStringBraceLines = @($continuedStringLines | Where-Object { $_.Raw.IndexOf('brace { and close }', [StringComparison]::Ordinal) -ge 0 })
  $continuedStringDivisionLine = @($continuedStringLines | Where-Object { $_.Raw.IndexOf('".length / 2;', [StringComparison]::Ordinal) -ge 0 })
  if (
    $continuedStringResult.Errors.Count -ne 0 -or
    $continuedStringResult.OwnerCount -ne 1 -or
    $continuedStringBraceLines.Count -ne 2 -or
    @($continuedStringBraceLines | Where-Object { $_.Ambiguous -or $_.StructuralText.IndexOf('{', [StringComparison]::Ordinal) -ge 0 -or $_.StructuralText.IndexOf('}', [StringComparison]::Ordinal) -ge 0 }).Count -ne 0 -or
    $continuedStringDivisionLine.Count -ne 1 -or
    $continuedStringDivisionLine[0].Ambiguous -or
    $continuedStringDivisionLine[0].StructuralText.IndexOf('/ 2', [StringComparison]::Ordinal) -lt 0
  ) {
    $freshLexerFormatterResidualFailures.Add("C2b escaped ordinary-string line continuations must preserve inert braces and resume division ($($lexicalLineEnding.Name)): $($continuedStringResult.Errors -join '; ')")
  }

  $continuedStringRogueSource = $validJavascriptOwnerMetadata + "`n" + @'
class LexicalOwner {
  run() {
    const payload = "open \
brace { and close }";
    return payload;
  }
}
danger();
'@
  $continuedStringRogueSource = $continuedStringRogueSource.Replace("`ndanger();", "`n$validJavascriptOwnerEnd`ndanger();")
  $continuedStringRogue = Invoke-LexicalSourceInventoryProbe "continued-string-rogue-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $continuedStringRogueSource 'src/lexical.js'
  $continuedStringRogueLines = @(Get-ArcSourceLexicalLines -SourceText ([regex]::Replace($continuedStringRogueSource, '\r\n|\r|\n', $lexicalLineEnding.NewLine)) -SourcePath 'src/lexical.js')
  $continuedStringRogueBraceLine = @($continuedStringRogueLines | Where-Object { $_.Raw.IndexOf('brace { and close }', [StringComparison]::Ordinal) -ge 0 })
  if (
    $continuedStringRogue.Errors -cnotcontains 'responsibility-evidence-missing' -or
    $continuedStringRogueBraceLine.Count -ne 1 -or
    $continuedStringRogueBraceLine[0].Ambiguous -or
    $continuedStringRogueBraceLine[0].StructuralText.IndexOf('{', [StringComparison]::Ordinal) -ge 0 -or
    $continuedStringRogueBraceLine[0].StructuralText.IndexOf('}', [StringComparison]::Ordinal) -ge 0
  ) {
    $freshLexerFormatterResidualFailures.Add("C2b continued-string braces must stay inert so later rogue code remains unowned ($($lexicalLineEnding.Name))")
  }

  $unescapedStringEolSource = $validJavascriptOwnerMetadata + "`n" + @'
class LexicalOwner {
  run() {
    const payload = "unterminated
brace { and close }";
    return payload;
  }
}
'@
  $unescapedStringEolSource += "`n$validJavascriptOwnerEnd"
  $unescapedStringEol = Invoke-LexicalSourceInventoryProbe "unescaped-string-eol-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $unescapedStringEolSource 'src/lexical.js'
  if ($unescapedStringEol.Errors -cnotcontains 'responsibility-evidence-missing') {
    $freshLexerFormatterResidualFailures.Add("C2b an ordinary quoted string without an escaped EOL must continue to fail closed ($($lexicalLineEnding.Name))")
  }

  $declarationBraceContextSource = $validJavascriptOwnerMetadata + "`n" + @'
class LexicalOwner {
  run() {
    function owned(value = {} / 2) { return value; }
    async function helper() {} /}/.test('async');
    return owned(4);
  }
}
'@
  $declarationBraceContextSource += "`n$validJavascriptOwnerEnd"
  $declarationBraceContext = Invoke-LexicalSourceInventoryProbe "declaration-brace-context-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $declarationBraceContextSource 'src/lexical.js'
  $declarationBraceLines = @(Get-ArcSourceLexicalLines -SourceText ([regex]::Replace($declarationBraceContextSource, '\r\n|\r|\n', $lexicalLineEnding.NewLine)) -SourcePath 'src/lexical.js')
  $declarationDefaultDivisionLine = @($declarationBraceLines | Where-Object { $_.Raw.IndexOf('value = {} / 2', [StringComparison]::Ordinal) -ge 0 })
  $asyncDeclarationRegexLine = @($declarationBraceLines | Where-Object { $_.Raw.IndexOf('async function helper() {} /}/', [StringComparison]::Ordinal) -ge 0 })
  if (
    $declarationBraceContext.Errors.Count -ne 0 -or
    $declarationBraceContext.OwnerCount -ne 1 -or
    $declarationDefaultDivisionLine.Count -ne 1 -or
    $declarationDefaultDivisionLine[0].Ambiguous -or
    $declarationDefaultDivisionLine[0].StructuralText.IndexOf('/ 2', [StringComparison]::Ordinal) -lt 0 -or
    $asyncDeclarationRegexLine.Count -ne 1 -or
    $asyncDeclarationRegexLine[0].Ambiguous -or
    @([regex]::Matches($asyncDeclarationRegexLine[0].StructuralText, '\}')).Count -ne 1
  ) {
    $freshLexerFormatterResidualFailures.Add("C2a declaration bodies must use depth-scoped brace contexts and preserve statement-position modifiers ($($lexicalLineEnding.Name)): $($declarationBraceContext.Errors -join '; ')")
  }

  $asyncDeclarationRogueSource = $validJavascriptOwnerMetadata + "`n" + @'
class LexicalOwner {
  run() {
    async function helper() {} /{/.test('async');
  }
}
danger();
'@
  $asyncDeclarationRogueSource = $asyncDeclarationRogueSource.Replace("`ndanger();", "`n$validJavascriptOwnerEnd`ndanger();")
  $asyncDeclarationRogue = Invoke-LexicalSourceInventoryProbe "async-declaration-rogue-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $asyncDeclarationRogueSource 'src/lexical.js'
  $asyncDeclarationRogueLines = @(Get-ArcSourceLexicalLines -SourceText ([regex]::Replace($asyncDeclarationRogueSource, '\r\n|\r|\n', $lexicalLineEnding.NewLine)) -SourcePath 'src/lexical.js')
  $asyncDeclarationRogueRegexLine = @($asyncDeclarationRogueLines | Where-Object { $_.Raw.IndexOf('async function helper() {} /{/', [StringComparison]::Ordinal) -ge 0 })
  if (
    $asyncDeclarationRogue.Errors -cnotcontains 'responsibility-evidence-missing' -or
    $asyncDeclarationRogueRegexLine.Count -ne 1 -or
    $asyncDeclarationRogueRegexLine[0].Ambiguous -or
    @([regex]::Matches($asyncDeclarationRogueRegexLine[0].StructuralText, '\{')).Count -ne 1
  ) {
    $freshLexerFormatterResidualFailures.Add("C2a a statement-position async declaration must not turn its following regex brace into structure or swallow rogue code ($($lexicalLineEnding.Name))")
  }

  $statementBlockContextSource = $validJavascriptOwnerMetadata + "`n" + @'
class LexicalOwner {
  run(value) {
    try {} catch {} /}/.test('catch');
    switch (value) { case 1: {} /{/.test('case'); break; }
    ownedLabel: {} /}/.test('label');
    return value;
  }
}
'@
  $statementBlockContextSource += "`n$validJavascriptOwnerEnd"
  $statementBlockContext = Invoke-LexicalSourceInventoryProbe "statement-block-context-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $statementBlockContextSource 'src/lexical.js'
  $statementBlockLines = @(Get-ArcSourceLexicalLines -SourceText ([regex]::Replace($statementBlockContextSource, '\r\n|\r|\n', $lexicalLineEnding.NewLine)) -SourcePath 'src/lexical.js')
  $catchBlockRegexLine = @($statementBlockLines | Where-Object { $_.Raw.IndexOf('try {} catch {} /}/', [StringComparison]::Ordinal) -ge 0 })
  $caseBlockRegexLine = @($statementBlockLines | Where-Object { $_.Raw.IndexOf('case 1: {} /{/', [StringComparison]::Ordinal) -ge 0 })
  $labelBlockRegexLine = @($statementBlockLines | Where-Object { $_.Raw.IndexOf('ownedLabel: {} /}/', [StringComparison]::Ordinal) -ge 0 })
  if (
    $statementBlockContext.Errors.Count -ne 0 -or
    $statementBlockContext.OwnerCount -ne 1 -or
    $catchBlockRegexLine.Count -ne 1 -or
    $catchBlockRegexLine[0].Ambiguous -or
    @([regex]::Matches($catchBlockRegexLine[0].StructuralText, '[{}]')).Count -ne 4 -or
    $caseBlockRegexLine.Count -ne 1 -or
    $caseBlockRegexLine[0].Ambiguous -or
    @([regex]::Matches($caseBlockRegexLine[0].StructuralText, '[{}]')).Count -ne 4 -or
    $labelBlockRegexLine.Count -ne 1 -or
    $labelBlockRegexLine[0].Ambiguous -or
    @([regex]::Matches($labelBlockRegexLine[0].StructuralText, '[{}]')).Count -ne 2
  ) {
    $freshLexerFormatterResidualFailures.Add("C2a binding-less catch, case clauses, and labelled statements must open statement blocks whose close permits regex ($($lexicalLineEnding.Name)): $($statementBlockContext.Errors -join '; ')")
  }

  foreach ($statementBlockRogueCase in @(
    [pscustomobject]@{ Name = 'binding-less-catch'; Statement = "try {} catch {} /{/.test('catch');"; ExpectedOpenBraces = 2 },
    [pscustomobject]@{ Name = 'case-clause'; Statement = "switch (value) { case 1: {} /{/.test('case'); break; }"; ExpectedOpenBraces = 2 },
    [pscustomobject]@{ Name = 'labelled-statement'; Statement = "ownedLabel: {} /{/.test('label');"; ExpectedOpenBraces = 1 }
  )) {
    $statementBlockRogueSource = $validJavascriptOwnerMetadata + "`n" + @'
class LexicalOwner {
  run(value) {
'@ + "`n    $($statementBlockRogueCase.Statement)`n" + @'
    return value;
  }
}
danger();
'@
    $statementBlockRogueSource = $statementBlockRogueSource.Replace("`ndanger();", "`n$validJavascriptOwnerEnd`ndanger();")
    $statementBlockRogue = Invoke-LexicalSourceInventoryProbe "statement-block-$($statementBlockRogueCase.Name)-rogue-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $statementBlockRogueSource 'src/lexical.js'
    $statementBlockRogueLines = @(Get-ArcSourceLexicalLines -SourceText ([regex]::Replace($statementBlockRogueSource, '\r\n|\r|\n', $lexicalLineEnding.NewLine)) -SourcePath 'src/lexical.js')
    $statementBlockRogueRegexLine = @($statementBlockRogueLines | Where-Object { $_.Raw.IndexOf($statementBlockRogueCase.Statement, [StringComparison]::Ordinal) -ge 0 })
    if (
      $statementBlockRogue.Errors -cnotcontains 'responsibility-evidence-missing' -or
      $statementBlockRogueRegexLine.Count -ne 1 -or
      $statementBlockRogueRegexLine[0].Ambiguous -or
      @([regex]::Matches($statementBlockRogueRegexLine[0].StructuralText, '\{')).Count -ne $statementBlockRogueCase.ExpectedOpenBraces
    ) {
      $freshLexerFormatterResidualFailures.Add("C2a $($statementBlockRogueCase.Name) regex braces must stay inert so later rogue code remains unowned ($($lexicalLineEnding.Name))")
    }
  }

  $forHeaderSemicolonSource = $validJavascriptOwnerMetadata + "`n" + @'
class LexicalOwner {
  run() {
    for (;; {} / 2) break;
  }
}
'@
  $forHeaderSemicolonSource += "`n$validJavascriptOwnerEnd"
  $forHeaderSemicolon = Invoke-LexicalSourceInventoryProbe "for-header-semicolon-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $forHeaderSemicolonSource 'src/lexical.js'
  $forHeaderSemicolonLines = @(Get-ArcSourceLexicalLines -SourceText ([regex]::Replace($forHeaderSemicolonSource, '\r\n|\r|\n', $lexicalLineEnding.NewLine)) -SourcePath 'src/lexical.js')
  $forHeaderDivisionLine = @($forHeaderSemicolonLines | Where-Object { $_.Raw.IndexOf('for (;; {} / 2)', [StringComparison]::Ordinal) -ge 0 })
  if (
    $forHeaderSemicolon.Errors.Count -ne 0 -or
    $forHeaderSemicolon.OwnerCount -ne 1 -or
    $forHeaderDivisionLine.Count -ne 1 -or
    $forHeaderDivisionLine[0].Ambiguous -or
    $forHeaderDivisionLine[0].StructuralText.IndexOf('/ 2', [StringComparison]::Ordinal) -lt 0
  ) {
    $freshLexerFormatterResidualFailures.Add("C2a semicolons inside a for header must preserve expression context so object-literal division remains division ($($lexicalLineEnding.Name)): $($forHeaderSemicolon.Errors -join '; ')")
  }

  $emptyLineAfterStringContinuationSource = $validJavascriptOwnerMetadata + "`n" + @'
class LexicalOwner {
  run() {
    const payload = "open \

brace { and close }";
    return payload;
  }
}
danger();
'@
  $emptyLineAfterStringContinuationSource = $emptyLineAfterStringContinuationSource.Replace("`ndanger();", "`n$validJavascriptOwnerEnd`ndanger();")
  $emptyLineAfterStringContinuation = Invoke-LexicalSourceInventoryProbe "empty-line-after-string-continuation-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $emptyLineAfterStringContinuationSource 'src/lexical.js'
  $emptyLineAfterStringContinuationLines = @(Get-ArcSourceLexicalLines -SourceText ([regex]::Replace($emptyLineAfterStringContinuationSource, '\r\n|\r|\n', $lexicalLineEnding.NewLine)) -SourcePath 'src/lexical.js')
  $emptyContinuedStringLines = @($emptyLineAfterStringContinuationLines | Where-Object { $_.Raw.Length -eq 0 })
  if (
    $emptyLineAfterStringContinuation.Errors -cnotcontains 'responsibility-evidence-missing' -or
    $emptyContinuedStringLines.Count -ne 1 -or
    -not $emptyContinuedStringLines[0].Ambiguous
  ) {
    $freshLexerFormatterResidualFailures.Add("C2b an empty physical line after one escaped string EOL must be an unescaped-EOL fail-closed boundary ($($lexicalLineEnding.Name))")
  }

  $contextualKeywordObjectSource = $validJavascriptOwnerMetadata + "`n" + @'
class LexicalOwner {
  run() {
    const catchValue = { catch: {} / 2 };
    const caseValue = { case: {} / 2 };
    const defaultValue = { default: {} / 2 };
    return [catchValue, caseValue, defaultValue];
  }
}
'@
  $contextualKeywordObjectSource += "`n$validJavascriptOwnerEnd"
  $contextualKeywordObject = Invoke-LexicalSourceInventoryProbe "contextual-keyword-object-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $contextualKeywordObjectSource 'src/lexical.js'
  $contextualKeywordObjectLines = @(Get-ArcSourceLexicalLines -SourceText ([regex]::Replace($contextualKeywordObjectSource, '\r\n|\r|\n', $lexicalLineEnding.NewLine)) -SourcePath 'src/lexical.js')
  $contextualKeywordDivisionLines = @($contextualKeywordObjectLines | Where-Object { $_.Raw.IndexOf('{} / 2', [StringComparison]::Ordinal) -ge 0 })
  if (
    $contextualKeywordObject.Errors.Count -ne 0 -or
    $contextualKeywordObject.OwnerCount -ne 1 -or
    $contextualKeywordDivisionLines.Count -ne 3 -or
    @($contextualKeywordDivisionLines | Where-Object { $_.Ambiguous -or $_.StructuralText.IndexOf('/ 2', [StringComparison]::Ordinal) -lt 0 }).Count -ne 0
  ) {
    $freshLexerFormatterResidualFailures.Add("C2a catch/case/default property keys must remain expression tokens and preserve object-value division ($($lexicalLineEnding.Name)): $($contextualKeywordObject.Errors -join '; ')")
  }

  $asyncLabelSource = $validJavascriptOwnerMetadata + "`n" + @'
class LexicalOwner {
  run(value) {
    async: {} /}/.test(String(value));
    return value;
  }
}
'@
  $asyncLabelSource += "`n$validJavascriptOwnerEnd"
  $asyncLabel = Invoke-LexicalSourceInventoryProbe "async-label-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $asyncLabelSource 'src/lexical.js'
  $asyncLabelLines = @(Get-ArcSourceLexicalLines -SourceText ([regex]::Replace($asyncLabelSource, '\r\n|\r|\n', $lexicalLineEnding.NewLine)) -SourcePath 'src/lexical.js')
  $asyncLabelRegexLine = @($asyncLabelLines | Where-Object { $_.Raw.IndexOf('async: {} /}/', [StringComparison]::Ordinal) -ge 0 })
  if (
    $asyncLabel.Errors.Count -ne 0 -or
    $asyncLabel.OwnerCount -ne 1 -or
    $asyncLabelRegexLine.Count -ne 1 -or
    $asyncLabelRegexLine[0].Ambiguous -or
    @([regex]::Matches($asyncLabelRegexLine[0].StructuralText, '\}')).Count -ne 1
  ) {
    $freshLexerFormatterResidualFailures.Add("C2a a contextual async label must resolve at colon and permit a following inert regex ($($lexicalLineEnding.Name)): $($asyncLabel.Errors -join '; ')")
  }

  $asyncLabelRogueSource = $validJavascriptOwnerMetadata + "`n" + @'
class LexicalOwner {
  run(value) {
    async: {} /{/.test(String(value));
    return value;
  }
}
danger();
'@
  $asyncLabelRogueSource = $asyncLabelRogueSource.Replace("`ndanger();", "`n$validJavascriptOwnerEnd`ndanger();")
  $asyncLabelRogue = Invoke-LexicalSourceInventoryProbe "async-label-rogue-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $asyncLabelRogueSource 'src/lexical.js'
  $asyncLabelRogueLines = @(Get-ArcSourceLexicalLines -SourceText ([regex]::Replace($asyncLabelRogueSource, '\r\n|\r|\n', $lexicalLineEnding.NewLine)) -SourcePath 'src/lexical.js')
  $asyncLabelRogueRegexLine = @($asyncLabelRogueLines | Where-Object { $_.Raw.IndexOf('async: {} /{/', [StringComparison]::Ordinal) -ge 0 })
  if (
    $asyncLabelRogue.Errors -cnotcontains 'responsibility-evidence-missing' -or
    $asyncLabelRogueRegexLine.Count -ne 1 -or
    $asyncLabelRogueRegexLine[0].Ambiguous -or
    @([regex]::Matches($asyncLabelRogueRegexLine[0].StructuralText, '\{')).Count -ne 1
  ) {
    $freshLexerFormatterResidualFailures.Add("C2a an async-label regex brace must stay inert so later rogue code remains unowned ($($lexicalLineEnding.Name))")
  }

  $unterminatedJavascriptTemplateSource = $javascriptOwnerMetadata + "`n" + @'
class LexicalOwner {
  run() {
    const payload = `unterminated template
literal opening brace is inert: {
  }
}
'@
  $unterminatedJavascriptTemplateSource += "`n$javascriptOwnerEnd"
  $unterminatedJavascriptTemplate = Invoke-LexicalSourceInventoryProbe "unterminated-javascript-template-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $unterminatedJavascriptTemplateSource 'src/lexical.ts'
  if ($unterminatedJavascriptTemplate.Errors -cnotcontains 'responsibility-evidence-missing') {
    throw "unterminated JavaScript template-literal ambiguity must fail closed ($($lexicalLineEnding.Name))"
  }
  Write-Output "PASS: unterminated JavaScript template-literal ambiguity fails closed ($($lexicalLineEnding.Name))"

  $unterminatedJavascriptInterpolationSource = $javascriptOwnerMetadata + "`n" + @'
class LexicalOwner {
  run(value) {
    const payload = `unterminated interpolation: ${value
  }
}
'@
  $unterminatedJavascriptInterpolationSource += "`n$javascriptOwnerEnd"
  $unterminatedJavascriptInterpolation = Invoke-LexicalSourceInventoryProbe "unterminated-javascript-interpolation-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $unterminatedJavascriptInterpolationSource 'src/lexical.ts'
  if ($unterminatedJavascriptInterpolation.Errors -cnotcontains 'responsibility-evidence-missing') {
    throw "unterminated JavaScript template interpolation must fail closed ($($lexicalLineEnding.Name))"
  }
  Write-Output "PASS: unterminated JavaScript template interpolation fails closed ($($lexicalLineEnding.Name))"

  foreach ($multilineLiteralCase in @(
    [pscustomobject]@{ Name = 'java-text-block'; Declaration = 'String payload = """'; Method = 'int run() { return 1; }' },
    [pscustomobject]@{ Name = 'csharp-raw-string'; Declaration = 'string Payload = """'; Method = 'int Run() { return 1; }' }
  )) {
    $multilinePositiveSource = @"
$lexicalOwnerMetadata
class LexicalOwner {
  $($multilineLiteralCase.Declaration)
}
""";
  $($multilineLiteralCase.Method)
}
"@
    $multilinePositiveSource += "`n$lexicalOwnerEnd"
    $multilinePositive = Invoke-LexicalSourceInventoryProbe "$($multilineLiteralCase.Name)-positive-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $multilinePositiveSource
    if ($multilinePositive.Errors.Count -ne 0 -or $multilinePositive.OwnerCount -ne 1) {
      throw "$($multilineLiteralCase.Name) braces must remain inert inside a closed multiline literal ($($lexicalLineEnding.Name)): $($multilinePositive.Errors -join '; ')"
    }
    Write-Output "PASS: $($multilineLiteralCase.Name) braces remain inert inside a closed multiline literal ($($lexicalLineEnding.Name))"

    $multilineRogueSource = @"
$lexicalOwnerMetadata
class LexicalOwner {
  $($multilineLiteralCase.Declaration)
{
""";
  $($multilineLiteralCase.Method)
}
danger()
"@
    $multilineRogueSource = $multilineRogueSource.Replace("`ndanger()", "`n$lexicalOwnerEnd`ndanger()")
    $multilineRogue = Invoke-LexicalSourceInventoryProbe "$($multilineLiteralCase.Name)-rogue-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $multilineRogueSource
    if ($multilineRogue.Errors -cnotcontains 'responsibility-evidence-missing') {
      throw "$($multilineLiteralCase.Name) multiline literal swallowed later rogue code ($($lexicalLineEnding.Name))"
    }
    Write-Output "PASS: $($multilineLiteralCase.Name) cannot swallow later rogue code ($($lexicalLineEnding.Name))"
  }

  $unterminatedMultilineSource = @"
$lexicalOwnerMetadata
class LexicalOwner {
  String payload = """
{
danger()
"@
  $unterminatedMultilineSource += "`n$lexicalOwnerEnd"
  $unterminatedMultiline = Invoke-LexicalSourceInventoryProbe "unterminated-multiline-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $unterminatedMultilineSource
  if ($unterminatedMultiline.Errors -cnotcontains 'responsibility-evidence-missing') {
    throw "unterminated multiline literal ambiguity must fail closed ($($lexicalLineEnding.Name))"
  }
  Write-Output "PASS: unterminated multiline literal ambiguity fails closed ($($lexicalLineEnding.Name))"
}

$formatterGrammarCases = @(
  [pscustomobject]@{ Expected = $true; Name = 'Prettier boolean and scalar options'; Command = 'prettier --write --print-width 100 src/admin_route.source' },
  [pscustomobject]@{ Expected = $true; Name = 'Windows command suffix for Prettier'; Command = 'prettier.cmd --write src/admin_route.source' },
  [pscustomobject]@{ Expected = $true; Name = 'Black module wrapper and scalar option'; Command = 'python -m black --check --line-length=100 src/admin_route.source' },
  [pscustomobject]@{ Expected = $true; Name = 'npx Prettier wrapper'; Command = 'npx prettier --write src/admin_route.source' },
  [pscustomobject]@{ Expected = $true; Name = 'Windows command suffix for npx wrapper'; Command = 'npx.cmd prettier --write src/admin_route.source' },
  [pscustomobject]@{ Expected = $true; Name = 'gofmt switch'; Command = 'gofmt -w src/admin_route.source' },
  [pscustomobject]@{ Expected = $true; Name = 'rustfmt scalar option'; Command = 'rustfmt --edition 2021 src/admin_route.source' },
  [pscustomobject]@{ Expected = $true; Name = 'clang-format switch and inline scalar'; Command = 'clang-format -i --style=LLVM src/admin_route.source' },
  [pscustomobject]@{ Expected = $true; Name = 'direct CSharpier switch'; Command = 'csharpier --check src/admin_route.source' },
  [pscustomobject]@{ Expected = $true; Name = 'StyLua switch and scalar'; Command = 'stylua --check --column-width 100 src/admin_route.source' },
  [pscustomobject]@{ Expected = $true; Name = 'shfmt short switch and scalar'; Command = 'shfmt -w -i 2 src/admin_route.source' },
  [pscustomobject]@{ Expected = $true; Name = 'Go fmt subcommand'; Command = 'go fmt -n src/admin_route.source' },
  [pscustomobject]@{ Expected = $true; Name = 'Cargo fmt subcommand'; Command = 'cargo fmt --check --package admin src/admin_route.source' },
  [pscustomobject]@{ Expected = $true; Name = 'Deno fmt subcommand'; Command = 'deno fmt --check --line-width 100 src/admin_route.source' },
  [pscustomobject]@{ Expected = $true; Name = 'dotnet CSharpier wrapper'; Command = 'dotnet csharpier --check src/admin_route.source' },
  [pscustomobject]@{ Expected = $true; Name = 'bunx Biome wrapper'; Command = 'bunx biome format --write src/admin_route.source' },
  [pscustomobject]@{ Expected = $true; Name = 'npm exec Prettier wrapper'; Command = 'npm exec prettier --write src/admin_route.source' },
  [pscustomobject]@{ Expected = $true; Name = 'pnpm exec Biome wrapper'; Command = 'pnpm exec biome format --write src/admin_route.source' },
  [pscustomobject]@{ Expected = $true; Name = 'yarn exec Prettier wrapper'; Command = 'yarn exec prettier --write src/admin_route.source' },
  [pscustomobject]@{ Expected = $true; Name = 'bun exec Biome wrapper'; Command = 'bun exec biome format --write src/admin_route.source' },
  [pscustomobject]@{ Expected = $true; Name = 'uv run Ruff wrapper'; Command = 'uv run ruff format --check src/admin_route.source' },
  [pscustomobject]@{ Expected = $true; Name = 'pipx run Black wrapper'; Command = 'pipx run black --check src/admin_route.source' },
  [pscustomobject]@{ Expected = $true; Name = 'Python3 Ruff module wrapper'; Command = 'python3 -m ruff format --check src/admin_route.source' },
  [pscustomobject]@{ Expected = $true; Name = 'py Black module wrapper'; Command = 'py -m black --check src/admin_route.source' },
  [pscustomobject]@{ Expected = $false; Name = 'direct generic format executable'; Command = 'format src/admin_route.source' },
  [pscustomobject]@{ Expected = $false; Name = 'direct generic fmt executable'; Command = 'fmt src/admin_route.source' },
  [pscustomobject]@{ Expected = $false; Name = 'unknown executable'; Command = 'formatter-proxy src/admin_route.source' },
  [pscustomobject]@{ Expected = $false; Name = 'whitelisted-looking executable with an unknown suffix'; Command = 'prettier.evil --write src/admin_route.source' },
  [pscustomobject]@{ Expected = $false; Name = 'whitelisted-looking wrapper with an unknown suffix'; Command = 'npx.evil prettier --write src/admin_route.source' },
  [pscustomobject]@{ Expected = $false; Name = 'unknown Dart option'; Command = 'dart format --write src/admin_route.source' },
  [pscustomobject]@{ Expected = $false; Name = 'cross-tool Prettier option'; Command = 'prettier --line-length 100 src/admin_route.source' },
  [pscustomobject]@{ Expected = $false; Name = 'case-variant Prettier scalar option'; Command = 'prettier --PRINT-WIDTH 100 src/admin_route.source' },
  [pscustomobject]@{ Expected = $false; Name = 'unknown Ruff option'; Command = 'ruff format --write src/admin_route.source' },
  [pscustomobject]@{ Expected = $false; Name = 'unknown option after the target'; Command = 'prettier --write src/admin_route.source --mystery' },
  [pscustomobject]@{ Expected = $false; Name = 'inline value attached to a switch'; Command = 'prettier --write=true src/admin_route.source' },
  [pscustomobject]@{ Expected = $false; Name = 'missing Prettier scalar value'; Command = 'prettier src/admin_route.source --print-width' },
  [pscustomobject]@{ Expected = $false; Name = 'missing Dart enum value'; Command = 'dart format src/admin_route.source --output' },
  [pscustomobject]@{ Expected = $false; Name = 'invalid rustfmt scalar value'; Command = 'rustfmt --edition latest src/admin_route.source' },
  [pscustomobject]@{ Expected = $false; Name = 'target consumed as a separated scalar value'; Command = 'prettier --print-width src/admin_route.source' },
  [pscustomobject]@{ Expected = $false; Name = 'target consumed as an inline scalar value'; Command = 'prettier --print-width=src/admin_route.source' },
  [pscustomobject]@{ Expected = $false; Name = 'unsupported Python module wrapper'; Command = 'python -m prettier src/admin_route.source' },
  [pscustomobject]@{ Expected = $false; Name = 'generic package script wrapper'; Command = 'npm run format src/admin_route.source' },
  [pscustomobject]@{ Expected = $false; Name = 'unknown npx wrapped executable'; Command = 'npx formatter-proxy src/admin_route.source' },
  [pscustomobject]@{ Expected = $false; Name = 'uppercase direct formatter executable'; Command = 'PRETTIER --write src/admin_route.source' },
  [pscustomobject]@{ Expected = $false; Name = 'mixed-case direct formatter executable'; Command = 'Prettier --write src/admin_route.source' },
  [pscustomobject]@{ Expected = $false; Name = 'uppercase npx wrapper'; Command = 'NPX prettier --write src/admin_route.source' },
  [pscustomobject]@{ Expected = $false; Name = 'uppercase format subcommand'; Command = 'ruff FORMAT --check src/admin_route.source' },
  [pscustomobject]@{ Expected = $false; Name = 'uppercase Python module switch'; Command = 'python -M black --check src/admin_route.source' },
  [pscustomobject]@{ Expected = $false; Name = 'uppercase package exec subcommand'; Command = 'npm EXEC prettier --write src/admin_route.source' },
  [pscustomobject]@{ Expected = $false; Name = 'uppercase CSharpier wrapper target'; Command = 'dotnet CSHARPIER --check src/admin_route.source' },
  [pscustomobject]@{ Expected = $false; Name = 'uppercase Go executable and fmt subcommand'; Command = 'GO FMT -n src/admin_route.source' }
)
foreach ($formatterGrammarCase in $formatterGrammarCases) {
  $actual = Test-ArcPathScopedFormatterCommand -Command $formatterGrammarCase.Command -CanonicalPath 'src/admin_route.source'
  if ($actual -ne $formatterGrammarCase.Expected) {
    $freshLexerFormatterResidualFailures.Add("I10 $($formatterGrammarCase.Name) expected $($formatterGrammarCase.Expected) but got $($actual): $($formatterGrammarCase.Command)")
  }
}
if ($freshLexerFormatterResidualFailures.Count -ne 0) {
  throw "Fresh C2a/C2b/I10 regression matrix failed:`n - $($freshLexerFormatterResidualFailures -join "`n - ")"
}
Write-Output 'PASS: fresh C2a/C2b LF/CRLF and I10 exact-grammar regression matrix'

foreach ($bodyOnlyEdit in @(
  [pscustomobject]@{ Name = 'literal'; Old = 'return 1;'; New = 'return 2;' },
  [pscustomobject]@{ Name = 'control-flow'; Old = 'if (enabled) {'; New = 'if (enabled && allowed) {' },
  [pscustomobject]@{ Name = 'ordinary body'; Old = 'return cachedValue;'; New = 'return liveValue;' }
)) {
  $bodyEditRoot = Join-Path ([IO.Path]::GetTempPath()) ('aitoolkit-owner-body-edit-' + [guid]::NewGuid().ToString('N'))
  try {
    [void](New-Item -ItemType Directory -Force -Path (Join-Path $bodyEditRoot 'src'))
    Invoke-PinnedSourceGit $bodyEditRoot @('init') | Out-Null
    Invoke-PinnedSourceGit $bodyEditRoot @('config', 'core.autocrlf', 'false') | Out-Null
    Invoke-PinnedSourceGit $bodyEditRoot @('config', 'user.email', 'fixtures@example.test') | Out-Null
    Invoke-PinnedSourceGit $bodyEditRoot @('config', 'user.name', 'AIToolkit fixture') | Out-Null
    $baseBody = "@responsibility RESP-BODY`n@owner-symbol BodyOwner`n@public-symbol BodyOwner`n@owned-capability CAP-BODY`n@effect none`n@architecture-authority target-exemplar`n@co-location-policy feature-local`n@verification-owner VERIFY-OWNER-BODY`n@ownership-begin RESP-BODY`nclass BodyOwner {`n  int resolve(bool enabled, bool allowed) {`n    if (enabled) {`n      return 1;`n    }`n    return cachedValue;`n  }`n}`n@ownership-end RESP-BODY"
    $sourcePath = Join-Path $bodyEditRoot 'src/body.source'
    Set-Content -Encoding utf8 -LiteralPath $sourcePath -Value $baseBody
    Invoke-PinnedSourceGit $bodyEditRoot @('add', '--all') | Out-Null
    Invoke-PinnedSourceGit $bodyEditRoot @('commit', '-m', 'body owner base') | Out-Null
    $taskBaseSha = Invoke-PinnedSourceGit $bodyEditRoot @('rev-parse', 'HEAD')
    $updatedBody = $baseBody.Replace($bodyOnlyEdit.Old, $bodyOnlyEdit.New)
    if ($updatedBody -ceq $baseBody) { throw "$($bodyOnlyEdit.Name) fixture replacement failed" }
    Set-Content -Encoding utf8 -LiteralPath $sourcePath -Value $updatedBody
    Invoke-PinnedSourceGit $bodyEditRoot @('add', '--all') | Out-Null
    Invoke-PinnedSourceGit $bodyEditRoot @('commit', '-m', "$($bodyOnlyEdit.Name) body-only edit") | Out-Null
    $finalTreeSha = Invoke-PinnedSourceGit $bodyEditRoot @('rev-parse', 'HEAD')
    $inventoryErrors = [Collections.Generic.List[string]]::new()
    $sourceInventory = Get-ArcPinnedSourceInventory -SourceRoot $bodyEditRoot -TaskBaseSha $taskBaseSha -FinalTreeSha $finalTreeSha -Errors $inventoryErrors
    $bodyOwners = @($sourceInventory.ActiveOwners | Where-Object { $_.Id -ceq 'RESP-BODY' -and $_.Path -ceq 'src/body.source' -and $_.IsChanged })
    if ($inventoryErrors.Count -ne 0 -or $bodyOwners.Count -ne 1) {
      throw "$($bodyOnlyEdit.Name) body-only edit did not bind to its responsibility owner/path: $($inventoryErrors -join '; ')"
    }
    Write-Output "PASS: $($bodyOnlyEdit.Name) body-only edit binds to its responsibility owner/path"
  }
  finally {
    if (Test-Path -LiteralPath $bodyEditRoot) { Remove-Item -LiteralPath $bodyEditRoot -Recurse -Force }
  }
}

$outOfBlockEditRoot = Join-Path ([IO.Path]::GetTempPath()) ('aitoolkit-out-of-block-edit-' + [guid]::NewGuid().ToString('N'))
try {
  [void](New-Item -ItemType Directory -Force -Path (Join-Path $outOfBlockEditRoot 'src'))
  Invoke-PinnedSourceGit $outOfBlockEditRoot @('init') | Out-Null
  Invoke-PinnedSourceGit $outOfBlockEditRoot @('config', 'core.autocrlf', 'false') | Out-Null
  Invoke-PinnedSourceGit $outOfBlockEditRoot @('config', 'user.email', 'fixtures@example.test') | Out-Null
  Invoke-PinnedSourceGit $outOfBlockEditRoot @('config', 'user.name', 'AIToolkit fixture') | Out-Null
  $baseBody = "@responsibility RESP-BOUNDARY`n@owner-symbol BoundaryOwner`n@public-symbol BoundaryOwner`n@owned-capability CAP-BOUNDARY`n@effect none`n@architecture-authority target-exemplar`n@co-location-policy feature-local`n@verification-owner VERIFY-OWNER-BOUNDARY`n@ownership-begin RESP-BOUNDARY`nclass BoundaryOwner {`n  int resolve() { return 1; }`n}`n@ownership-end RESP-BOUNDARY"
  $sourcePath = Join-Path $outOfBlockEditRoot 'src/boundary.source'
  Set-Content -Encoding utf8 -LiteralPath $sourcePath -Value $baseBody
  Invoke-PinnedSourceGit $outOfBlockEditRoot @('add', '--all') | Out-Null
  Invoke-PinnedSourceGit $outOfBlockEditRoot @('commit', '-m', 'bounded owner base') | Out-Null
  $taskBaseSha = Invoke-PinnedSourceGit $outOfBlockEditRoot @('rev-parse', 'HEAD')
  Set-Content -Encoding utf8 -LiteralPath $sourcePath -Value "$baseBody`ninvokeRogue();"
  Invoke-PinnedSourceGit $outOfBlockEditRoot @('add', '--all') | Out-Null
  Invoke-PinnedSourceGit $outOfBlockEditRoot @('commit', '-m', 'out-of-block body edit') | Out-Null
  $finalTreeSha = Invoke-PinnedSourceGit $outOfBlockEditRoot @('rev-parse', 'HEAD')
  $inventoryErrors = [Collections.Generic.List[string]]::new()
  [void](Get-ArcPinnedSourceInventory -SourceRoot $outOfBlockEditRoot -TaskBaseSha $taskBaseSha -FinalTreeSha $finalTreeSha -Errors $inventoryErrors)
  if ($inventoryErrors -cnotcontains 'responsibility-evidence-missing') { throw 'true out-of-block executable edit was incorrectly bound to the preceding owner' }
  Write-Output 'PASS: true out-of-block executable edit remains unowned and rejected'
}
finally {
  if (Test-Path -LiteralPath $outOfBlockEditRoot) { Remove-Item -LiteralPath $outOfBlockEditRoot -Recurse -Force }
}

$incidentalMarkerRoot = Join-Path ([IO.Path]::GetTempPath()) ('aitoolkit-incidental-marker-' + [guid]::NewGuid().ToString('N'))
try {
  [void](New-Item -ItemType Directory -Force -Path (Join-Path $incidentalMarkerRoot 'docs'))
  Invoke-PinnedSourceGit $incidentalMarkerRoot @('init') | Out-Null
  Invoke-PinnedSourceGit $incidentalMarkerRoot @('config', 'core.autocrlf', 'false') | Out-Null
  Invoke-PinnedSourceGit $incidentalMarkerRoot @('config', 'user.email', 'fixtures@example.test') | Out-Null
  Invoke-PinnedSourceGit $incidentalMarkerRoot @('config', 'user.name', 'AIToolkit fixture') | Out-Null
  Set-Content -Encoding utf8 -LiteralPath (Join-Path $incidentalMarkerRoot 'README') -Value 'incidental marker base'
  Invoke-PinnedSourceGit $incidentalMarkerRoot @('add', '--all') | Out-Null
  Invoke-PinnedSourceGit $incidentalMarkerRoot @('commit', '-m', 'incidental marker base') | Out-Null
  $taskBaseSha = Invoke-PinnedSourceGit $incidentalMarkerRoot @('rev-parse', 'HEAD')
  $incidentalPath = 'docs/responsibility-example.source'
  $incidentalText = "@responsibility RESP-DOCS-EXAMPLE`n@owner-symbol ExampleRoute`n@public-symbol ExampleRoute`n@owned-capability CAP-DOCS-EXAMPLE`n@effect route registration`n@architecture-authority target-exemplar`n@co-location-policy feature-local`n@verification-owner VERIFY-OWNER-DOCS-EXAMPLE`n@ownership-begin RESP-DOCS-EXAMPLE`nroute ExampleRoute -> ExampleProvider`n@ownership-end RESP-DOCS-EXAMPLE"
  Set-Content -Encoding utf8 -LiteralPath (Join-Path $incidentalMarkerRoot $incidentalPath) -Value $incidentalText
  Invoke-PinnedSourceGit $incidentalMarkerRoot @('add', '--all') | Out-Null
  Invoke-PinnedSourceGit $incidentalMarkerRoot @('commit', '-m', 'add docs example') | Out-Null
  $finalTreeSha = Invoke-PinnedSourceGit $incidentalMarkerRoot @('rev-parse', 'HEAD')
  $inventoryErrors = [Collections.Generic.List[string]]::new()
  $sourceInventory = Get-ArcPinnedSourceInventory -SourceRoot $incidentalMarkerRoot -TaskBaseSha $taskBaseSha -FinalTreeSha $finalTreeSha -Errors $inventoryErrors
  if ($inventoryErrors.Count -ne 0 -or $sourceInventory.ActiveOwners.Count -ne 0 -or $sourceInventory.ChangedPaths.Count -ne 1) {
    throw "incidental non-production marker became owner authority: $($inventoryErrors -join '; ')"
  }
  $selectedErrors = [Collections.Generic.List[string]]::new()
  $selectedInventory = Get-ArcPinnedSourceInventory -SourceRoot $incidentalMarkerRoot -TaskBaseSha $taskBaseSha -FinalTreeSha $finalTreeSha -SelectedPaths @($incidentalPath) -Errors $selectedErrors
  if ($selectedErrors.Count -ne 0 -or @($selectedInventory.ActiveOwners | Where-Object { $_.Id -ceq 'RESP-DOCS-EXAMPLE' }).Count -ne 1) {
    throw "explicitly selected non-production owner authority was not parsed: $($selectedErrors -join '; ')"
  }
  Write-Output 'PASS: non-production markers are ignored unless explicitly selected as owner authority'
}
finally {
  if (Test-Path -LiteralPath $incidentalMarkerRoot) { Remove-Item -LiteralPath $incidentalMarkerRoot -Recurse -Force }
}

$copyDestinationRoot = Join-Path ([IO.Path]::GetTempPath()) ('aitoolkit-copy-destination-' + [guid]::NewGuid().ToString('N'))
try {
  $unicodeDirectory = -join @([char]0x0111, [char]0x01B0, [char]0x1EDD, 'n', 'g', ' ', 'd', [char]0x1EAB, 'n')
  [void](New-Item -ItemType Directory -Force -Path (Join-Path $copyDestinationRoot 'src'))
  [void](New-Item -ItemType Directory -Force -Path (Join-Path $copyDestinationRoot "docs/$unicodeDirectory"))
  Invoke-PinnedSourceGit $copyDestinationRoot @('init') | Out-Null
  Invoke-PinnedSourceGit $copyDestinationRoot @('config', 'core.autocrlf', 'false') | Out-Null
  Invoke-PinnedSourceGit $copyDestinationRoot @('config', 'user.email', 'fixtures@example.test') | Out-Null
  Invoke-PinnedSourceGit $copyDestinationRoot @('config', 'user.name', 'AIToolkit fixture') | Out-Null
  $copyOwner = "@responsibility RESP-COPY`n@owner-symbol CopyRoute`n@public-symbol CopyRoute`n@owned-capability CAP-COPY`n@effect none`n@architecture-authority target-exemplar`n@co-location-policy feature-local`n@verification-owner VERIFY-OWNER-COPY`n@ownership-begin RESP-COPY`nclass CopyRoute {}`n@ownership-end RESP-COPY"
  $copyBasePath = 'src/copy_route.source'
  $copyFinalPath = "docs/$unicodeDirectory/copy route.source"
  if ((ConvertTo-ArcCanonicalRepositoryPath -Path $copyFinalPath) -cne $copyFinalPath) {
    throw 'Canonical repository paths must preserve Unicode and embedded spaces'
  }
  foreach ($unsafePath in @('/src/absolute.source', 'C:/src/drive.source', 'src//alias.source', 'src/../traversal.source', "src/control$([char]1).source")) {
    if ((ConvertTo-ArcCanonicalRepositoryPath -Path $unsafePath) -cne '') { throw "Unsafe repository path must be rejected: $unsafePath" }
  }
  Set-Content -Encoding utf8 -LiteralPath (Join-Path $copyDestinationRoot $copyBasePath) -Value $copyOwner
  Invoke-PinnedSourceGit $copyDestinationRoot @('add', '--all') | Out-Null
  Invoke-PinnedSourceGit $copyDestinationRoot @('commit', '-m', 'production copy source') | Out-Null
  $copyTaskBaseSha = Invoke-PinnedSourceGit $copyDestinationRoot @('rev-parse', 'HEAD')
  Copy-Item -LiteralPath (Join-Path $copyDestinationRoot $copyBasePath) -Destination (Join-Path $copyDestinationRoot $copyFinalPath)
  Invoke-PinnedSourceGit $copyDestinationRoot @('add', '--all') | Out-Null
  Invoke-PinnedSourceGit $copyDestinationRoot @('commit', '-m', 'copy production source into excluded docs') | Out-Null
  $copyFinalTreeSha = Invoke-PinnedSourceGit $copyDestinationRoot @('rev-parse', 'HEAD')
  $copyErrors = [Collections.Generic.List[string]]::new()
  $copyInventory = Get-ArcPinnedSourceInventory -SourceRoot $copyDestinationRoot -TaskBaseSha $copyTaskBaseSha -FinalTreeSha $copyFinalTreeSha -Errors $copyErrors
  $trailingRootErrors = [Collections.Generic.List[string]]::new()
  $trailingRootInventory = Get-ArcPinnedSourceInventory -SourceRoot ($copyDestinationRoot + [IO.Path]::DirectorySeparatorChar) -TaskBaseSha $copyTaskBaseSha -FinalTreeSha $copyFinalTreeSha -Errors $trailingRootErrors
  $copyRecord = @($copyInventory.ChangedPaths | Where-Object { $_.Status -ceq 'C' -and $_.BasePath -ceq $copyBasePath -and $_.FinalPath -ceq $copyFinalPath })
  $trailingRootRecord = @($trailingRootInventory.ChangedPaths | Where-Object { $_.Status -ceq 'C' -and $_.BasePath -ceq $copyBasePath -and $_.FinalPath -ceq $copyFinalPath })
  if (
    $copyErrors.Count -ne 0 -or
    $trailingRootErrors.Count -ne 0 -or
    $copyRecord.Count -ne 1 -or
    $trailingRootRecord.Count -ne 1 -or
    $copyRecord[0].IsProduction -or
    @($copyInventory.ActiveOwners).Count -ne 0 -or
    @($copyInventory.DeletedOwners).Count -ne 0
  ) {
    throw "production-to-excluded copy must use destination-only classification: $($copyErrors -join '; ')"
  }
  Write-Output 'PASS: NUL-safe Unicode/space copy path and trailing source root preserve destination classification'
}
finally {
  if (Test-Path -LiteralPath $copyDestinationRoot) { Remove-Item -LiteralPath $copyDestinationRoot -Recurse -Force }
}

$renameAuthorityRoot = Join-Path ([IO.Path]::GetTempPath()) ('aitoolkit-rename-authority-' + [guid]::NewGuid().ToString('N'))
try {
  [void](New-Item -ItemType Directory -Force -Path (Join-Path $renameAuthorityRoot 'src'))
  [void](New-Item -ItemType Directory -Force -Path (Join-Path $renameAuthorityRoot 'docs'))
  Invoke-PinnedSourceGit $renameAuthorityRoot @('init') | Out-Null
  Invoke-PinnedSourceGit $renameAuthorityRoot @('config', 'core.autocrlf', 'false') | Out-Null
  Invoke-PinnedSourceGit $renameAuthorityRoot @('config', 'user.email', 'fixtures@example.test') | Out-Null
  Invoke-PinnedSourceGit $renameAuthorityRoot @('config', 'user.name', 'AIToolkit fixture') | Out-Null
  $keptOwner = "@responsibility RESP-RENAME-KEEP`n@owner-symbol RenameKeepRoute`n@public-symbol RenameKeepRoute`n@owned-capability CAP-RENAME-KEEP`n@effect route registration`n@architecture-authority target-exemplar`n@co-location-policy feature-local`n@verification-owner VERIFY-OWNER-RENAME-KEEP`n@ownership-begin RESP-RENAME-KEEP`nroute RenameKeepRoute -> RenameKeepProvider`n@ownership-end RESP-RENAME-KEEP"
  $keptOwner += "`n" + ((1..30 | ForEach-Object { "# preserved rename context $_" }) -join "`n")
  $removedOwner = "@responsibility RESP-RENAME-REMOVE`n@owner-symbol RenameRemoveRoute`n@public-symbol RenameRemoveRoute`n@owned-capability CAP-RENAME-REMOVE`n@effect route registration`n@architecture-authority target-exemplar`n@co-location-policy feature-local`n@verification-owner VERIFY-OWNER-RENAME-REMOVE`n@ownership-begin RESP-RENAME-REMOVE`nroute RenameRemoveRoute -> RenameRemoveProvider`n@ownership-end RESP-RENAME-REMOVE"
  $basePath = 'src/renamed.source'
  $finalPath = 'docs/renamed.source'
  Set-Content -Encoding utf8 -LiteralPath (Join-Path $renameAuthorityRoot $basePath) -Value "$keptOwner`n$removedOwner"
  Invoke-PinnedSourceGit $renameAuthorityRoot @('add', '--all') | Out-Null
  Invoke-PinnedSourceGit $renameAuthorityRoot @('commit', '-m', 'rename authority base') | Out-Null
  $taskBaseSha = Invoke-PinnedSourceGit $renameAuthorityRoot @('rev-parse', 'HEAD')
  Move-Item -LiteralPath (Join-Path $renameAuthorityRoot $basePath) -Destination (Join-Path $renameAuthorityRoot $finalPath)
  Set-Content -Encoding utf8 -LiteralPath (Join-Path $renameAuthorityRoot $finalPath) -Value $keptOwner
  Invoke-PinnedSourceGit $renameAuthorityRoot @('add', '--all') | Out-Null
  Invoke-PinnedSourceGit $renameAuthorityRoot @('commit', '-m', 'rename production authority to docs and remove owner') | Out-Null
  $finalTreeSha = Invoke-PinnedSourceGit $renameAuthorityRoot @('rev-parse', 'HEAD')
  $inventoryErrors = [Collections.Generic.List[string]]::new()
  $sourceInventory = Get-ArcPinnedSourceInventory -SourceRoot $renameAuthorityRoot -TaskBaseSha $taskBaseSha -FinalTreeSha $finalTreeSha -Errors $inventoryErrors
  $renameRecord = @($sourceInventory.ChangedPaths | Where-Object { $_.BasePath -ceq $basePath -and $_.FinalPath -ceq $finalPath })
  $removed = @($sourceInventory.DeletedOwners | Where-Object { $_.Id -ceq 'RESP-RENAME-REMOVE' })
  if ($inventoryErrors.Count -ne 0 -or $renameRecord.Count -ne 1 -or -not $renameRecord[0].IsProduction -or $renameRecord[0].RenameMapping -cne "$basePath->$finalPath" -or @($sourceInventory.ActiveOwners | Where-Object { $_.Id -ceq 'RESP-RENAME-KEEP' -and $_.Path -ceq $finalPath }).Count -ne 1 -or $removed.Count -ne 1 -or $removed[0].Path -cne $basePath) {
    throw "rename authority did not preserve old/new production and deletion evidence: $($inventoryErrors -join '; ')"
  }
  Write-Output 'PASS: rename preserves old/new production authority and base-path deletion evidence'
}
finally {
  if (Test-Path -LiteralPath $renameAuthorityRoot) { Remove-Item -LiteralPath $renameAuthorityRoot -Recurse -Force }
}

$removedBlockRoot = Join-Path ([IO.Path]::GetTempPath()) ('aitoolkit-removed-owner-block-' + [guid]::NewGuid().ToString('N'))
try {
  [void](New-Item -ItemType Directory -Force -Path (Join-Path $removedBlockRoot 'src'))
  Invoke-PinnedSourceGit $removedBlockRoot @('init') | Out-Null
  Invoke-PinnedSourceGit $removedBlockRoot @('config', 'core.autocrlf', 'false') | Out-Null
  Invoke-PinnedSourceGit $removedBlockRoot @('config', 'user.email', 'fixtures@example.test') | Out-Null
  Invoke-PinnedSourceGit $removedBlockRoot @('config', 'user.name', 'AIToolkit fixture') | Out-Null
  $keptBlock = "@responsibility RESP-KEEP`n@owner-symbol KeepRoute`n@public-symbol KeepRoute`n@owned-capability CAP-KEEP`n@effect route registration`n@architecture-authority target-exemplar`n@co-location-policy feature-local`n@verification-owner VERIFY-OWNER-KEEP`n@ownership-begin RESP-KEEP`nroute KeepRoute -> KeepProvider`n@ownership-end RESP-KEEP"
  $removedBlock = "@responsibility RESP-REMOVED`n@owner-symbol RemovedRoute`n@public-symbol RemovedRoute`n@owned-capability CAP-REMOVED`n@effect route registration`n@architecture-authority target-exemplar`n@co-location-policy feature-local`n@verification-owner VERIFY-OWNER-REMOVED`n@ownership-begin RESP-REMOVED`nroute RemovedRoute -> RemovedProvider`n@ownership-end RESP-REMOVED"
  $sourcePath = Join-Path $removedBlockRoot 'src/routes.source'
  Set-Content -Encoding utf8 -LiteralPath $sourcePath -Value "$keptBlock`n$removedBlock"
  Invoke-PinnedSourceGit $removedBlockRoot @('add', '--all') | Out-Null
  Invoke-PinnedSourceGit $removedBlockRoot @('commit', '-m', 'two responsibility owners') | Out-Null
  $taskBaseSha = Invoke-PinnedSourceGit $removedBlockRoot @('rev-parse', 'HEAD')
  Set-Content -Encoding utf8 -LiteralPath $sourcePath -Value $keptBlock
  Invoke-PinnedSourceGit $removedBlockRoot @('add', '--all') | Out-Null
  Invoke-PinnedSourceGit $removedBlockRoot @('commit', '-m', 'remove one responsibility owner') | Out-Null
  $finalTreeSha = Invoke-PinnedSourceGit $removedBlockRoot @('rev-parse', 'HEAD')
  $inventoryErrors = [Collections.Generic.List[string]]::new()
  $sourceInventory = Get-ArcPinnedSourceInventory -SourceRoot $removedBlockRoot -TaskBaseSha $taskBaseSha -FinalTreeSha $finalTreeSha -Errors $inventoryErrors
  if ($inventoryErrors.Count -ne 0 -or @($sourceInventory.ActiveOwners | Where-Object { $_.Id -ceq 'RESP-KEEP' }).Count -ne 1 -or @($sourceInventory.DeletedOwners | Where-Object { $_.Id -ceq 'RESP-REMOVED' }).Count -ne 1) {
    throw "surviving-file owner removal did not enter deletion reconciliation: $($inventoryErrors -join '; ')"
  }
  Write-Output 'PASS: responsibility block removed from a surviving M path enters deletion reconciliation'
}
finally {
  if (Test-Path -LiteralPath $removedBlockRoot) { Remove-Item -LiteralPath $removedBlockRoot -Recurse -Force }
}

Assert-FailsLike 'Change Hygiene rejects a noncanonical edited region' {
  param($root)
  $path = Join-Path $root 'artifacts/implementation-report.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $updated = $text.Replace('| WORK-ADMIN | src/admin_route.source | new | AdminRoute | none | none |', '| WORK-ADMIN | src/admin_route.source | new | * | none | none |')
  if ($updated -ceq $text) { throw 'Noncanonical edited-region fixture replacement failed' }
  Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
} 'change-hygiene-invalid' $true

Assert-FailsLike 'Change Hygiene rejects a repository-wide formatter command' {
  param($root)
  foreach ($relativePath in @('artifacts/implementation-report.md', 'artifacts/review-report.md')) {
    $path = Join-Path $root $relativePath
    $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
    $updated = if ($relativePath -ceq 'artifacts/implementation-report.md') {
      $text.Replace('| AdminRoute | none | none |', '| AdminRoute | dart format . | none |')
    }
    else {
      $text.Replace('| src/admin_route.source#AdminRoute | none | none | none |', '| src/admin_route.source#AdminRoute | dart format . | none | none |')
    }
    if ($updated -ceq $text) { throw "Repository-wide formatter fixture replacement failed: $relativePath" }
    Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
  }
} 'change-hygiene-invalid' $true

Assert-Pass 'Change Hygiene accepts a formatter command scoped to the exact changed path' {
  param($root)
  foreach ($relativePath in @('artifacts/implementation-report.md', 'artifacts/review-report.md')) {
    $path = Join-Path $root $relativePath
    $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
    $updated = if ($relativePath -ceq 'artifacts/implementation-report.md') {
      $text.Replace('| AdminRoute | none | none |', '| AdminRoute | dart format src/admin_route.source | none |')
    }
    else {
      $text.Replace('| src/admin_route.source#AdminRoute | none | none | none |', '| src/admin_route.source#AdminRoute | dart format src/admin_route.source | none | none |')
    }
    if ($updated -ceq $text) { throw "Scoped formatter fixture replacement failed: $relativePath" }
    Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
  }
} $true

Assert-Pass 'Change Hygiene accepts legitimate formatter switches with the exact changed path' {
  param($root)
  foreach ($relativePath in @('artifacts/implementation-report.md', 'artifacts/review-report.md')) {
    $path = Join-Path $root $relativePath
    $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
    $updated = if ($relativePath -ceq 'artifacts/implementation-report.md') {
      $text.Replace('| AdminRoute | none | none |', '| AdminRoute | dart format --line-length 100 --output=none src/admin_route.source | none |')
    }
    else {
      $text.Replace('| src/admin_route.source#AdminRoute | none | none | none |', '| src/admin_route.source#AdminRoute | dart format --line-length 100 --output=none src/admin_route.source | none | none |')
    }
    if ($updated -ceq $text) { throw "Switched formatter fixture replacement failed: $relativePath" }
    Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
  }
} $true

foreach ($subcommandFormatterCase in @(
  [pscustomobject]@{ Name = 'direct ruff format'; Command = 'ruff format --line-length 100 src/admin_route.source' },
  [pscustomobject]@{ Name = 'direct biome format'; Command = 'biome format --write src/admin_route.source' },
  [pscustomobject]@{ Name = 'npx biome format'; Command = 'npx biome format --write src/admin_route.source' },
  [pscustomobject]@{ Name = 'Python module ruff format'; Command = 'python -m ruff format --line-length 100 src/admin_route.source' }
)) {
  Assert-Pass "Change Hygiene accepts $($subcommandFormatterCase.Name) scoped to the exact changed path" {
    param($root)
    foreach ($relativePath in @('artifacts/implementation-report.md', 'artifacts/review-report.md')) {
      $path = Join-Path $root $relativePath
      $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
      $updated = if ($relativePath -ceq 'artifacts/implementation-report.md') {
        $text.Replace('| AdminRoute | none | none |', "| AdminRoute | $($subcommandFormatterCase.Command) | none |")
      }
      else {
        $text.Replace('| src/admin_route.source#AdminRoute | none | none | none |', "| src/admin_route.source#AdminRoute | $($subcommandFormatterCase.Command) | none | none |")
      }
      if ($updated -ceq $text) { throw "Subcommand formatter fixture replacement failed: $relativePath" }
      Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
    }
  } $true
}

foreach ($unsafeFormatterCase in @(
  [pscustomobject]@{ Name = 'an unrelated file operand'; Command = 'dart format src/admin_route.source src/unrelated.source' },
  [pscustomobject]@{ Name = 'a slash-dot alias operand'; Command = 'dart format src/admin_route.source src/./admin_route.source' },
  [pscustomobject]@{ Name = 'a traversal alias operand'; Command = 'dart format src/admin_route.source src/../src/admin_route.source' },
  [pscustomobject]@{ Name = 'a backslash alias operand'; Command = 'dart format src/admin_route.source src\admin_route.source' },
  [pscustomobject]@{ Name = 'a repository subtree operand'; Command = 'dart format src/admin_route.source src' },
  [pscustomobject]@{ Name = 'an extensionless unrelated operand after a boolean switch'; Command = 'prettier --write README src/admin_route.source' },
  [pscustomobject]@{ Name = 'an extensionless operand named like a formatter subcommand'; Command = 'prettier format src/admin_route.source' },
  [pscustomobject]@{ Name = 'an arbitrary non-formatter executable'; Command = 'echo src/admin_route.source' },
  [pscustomobject]@{ Name = 'an unrelated path hidden in a switch value'; Command = 'dart format --files=src/unrelated.source src/admin_route.source' },
  [pscustomobject]@{ Name = 'an extensionless path hidden in a switch value'; Command = 'dart format --files=README src/admin_route.source' },
  [pscustomobject]@{ Name = 'an extensionless path hidden in a compound filepath switch'; Command = 'prettier --stdin-filepath=README src/admin_route.source' },
  [pscustomobject]@{ Name = 'the exact target consumed by a separated filepath switch'; Command = 'prettier --stdin-filepath src/admin_route.source' },
  [pscustomobject]@{ Name = 'the exact target consumed by a separated ignore-path switch'; Command = 'prettier --ignore-path src/admin_route.source' },
  [pscustomobject]@{ Name = 'bare ruff without its format subcommand'; Command = 'ruff src/admin_route.source' },
  [pscustomobject]@{ Name = 'bare biome without its format subcommand'; Command = 'biome src/admin_route.source' },
  [pscustomobject]@{ Name = 'npx biome without its format subcommand'; Command = 'npx biome src/admin_route.source' },
  [pscustomobject]@{ Name = 'Python module ruff without its format subcommand'; Command = 'python -m ruff src/admin_route.source' },
  [pscustomobject]@{ Name = 'an invalid extensionless output operand'; Command = 'dart format --output README src/admin_route.source' },
  [pscustomobject]@{ Name = 'a malformed unmatched quoted operand'; Command = 'dart format src/admin_route.source "' }
)) {
  Assert-FailsLike "Change Hygiene rejects $($unsafeFormatterCase.Name) beside the exact path" {
    param($root)
    foreach ($relativePath in @('artifacts/implementation-report.md', 'artifacts/review-report.md')) {
      $path = Join-Path $root $relativePath
      $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
      $updated = if ($relativePath -ceq 'artifacts/implementation-report.md') {
        $text.Replace('| AdminRoute | none | none |', "| AdminRoute | $($unsafeFormatterCase.Command) | none |")
      }
      else {
        $text.Replace('| src/admin_route.source#AdminRoute | none | none | none |', "| src/admin_route.source#AdminRoute | $($unsafeFormatterCase.Command) | none | none |")
      }
      if ($updated -ceq $text) { throw "Unsafe formatter fixture replacement failed: $relativePath" }
      Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
    }
  } 'change-hygiene-invalid' $true
}

Assert-FailsLike 'Change Hygiene rejects a formatter operand that only contains the changed path' {
  param($root)
  foreach ($relativePath in @('artifacts/implementation-report.md', 'artifacts/review-report.md')) {
    $path = Join-Path $root $relativePath
    $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
    $updated = if ($relativePath -ceq 'artifacts/implementation-report.md') {
      $text.Replace('| AdminRoute | none | none |', '| AdminRoute | dart format src/admin_route.source.bak | none |')
    }
    else {
      $text.Replace('| src/admin_route.source#AdminRoute | none | none | none |', '| src/admin_route.source#AdminRoute | dart format src/admin_route.source.bak | none | none |')
    }
    if ($updated -ceq $text) { throw "Substring formatter fixture replacement failed: $relativePath" }
    Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
  }
} 'change-hygiene-invalid' $true

Assert-FailsLike 'Change Hygiene rejects a noncanonical unrelated-diff disposition' {
  param($root)
  $path = Join-Path $root 'artifacts/implementation-report.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $updated = $text.Replace('| AdminRoute | none | none |', '| AdminRoute | none | confirmed |')
  if ($updated -ceq $text) { throw 'Noncanonical unrelated-diff fixture replacement failed' }
  Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
} 'change-hygiene-invalid' $true

Assert-FailsLike 'Change Hygiene rejects a changed path omitted from the independent review table' {
  param($root)
  $path = Join-Path $root 'artifacts/review-report.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $updated = [regex]::Replace($text, '(?m)^\| WORK-ADMIN \| src/admin_route\.source#AdminRoute \|[^\r\n]+\r?\n?', '')
  if ($updated -ceq $text) { throw 'Omitted review Change Hygiene row fixture replacement failed' }
  Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
} 'change-hygiene-review-mismatch' $true

Assert-FailsLike 'Change Hygiene rejects duplicate independent review rows' {
  param($root)
  $path = Join-Path $root 'artifacts/review-report.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $rows = @($text -split '\r?\n' | Where-Object { $_ -cmatch '^\| WORK-ADMIN \| src/admin_route\.source#AdminRoute \|' })
  if ($rows.Count -ne 1) { throw 'Duplicate review Change Hygiene row fixture anchor is missing or duplicated' }
  Set-Content -Encoding utf8 -LiteralPath $path -Value $text.Replace($rows[0], "$($rows[0])`n$($rows[0])")
} 'change-hygiene-review-mismatch' $true

Assert-FailsLike 'confirmed unrelated diff requires one matching independent Major finding' {
  param($root)
  $implementationPath = Join-Path $root 'artifacts/implementation-report.md'
  $implementation = Get-Content -Raw -Encoding utf8 -LiteralPath $implementationPath
  $updatedImplementation = $implementation.Replace('| AdminRoute | none | none |', '| AdminRoute | none | confirmed:MAJOR-UNRELATED-001 |')
  if ($updatedImplementation -ceq $implementation) { throw 'Confirmed implementation unrelated-diff fixture replacement failed' }
  Set-Content -Encoding utf8 -LiteralPath $implementationPath -Value $updatedImplementation

  $reviewPath = Join-Path $root 'artifacts/review-report.md'
  $review = Get-Content -Raw -Encoding utf8 -LiteralPath $reviewPath
  $updatedReview = $review.Replace('| src/admin_route.source#AdminRoute | none | none | none |', '| src/admin_route.source#AdminRoute | none | confirmed:MAJOR-UNRELATED-001 | Major |')
  if ($updatedReview -ceq $review) { throw 'Confirmed review unrelated-diff fixture replacement failed' }
  Set-Content -Encoding utf8 -LiteralPath $reviewPath -Value $updatedReview
} 'change-hygiene-review-mismatch' $true

Assert-FailsLike 'review rejects a changed production path omitted from Change Hygiene' {
  param($root)
  $path = Join-Path $root 'artifacts/implementation-report.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $updated = [regex]::Replace($text, '(?m)^\| WORK-ADMIN \| src/admin_route\.source \|[^\r\n]+\r?\n?', '')
  if ($updated -ceq $text) { throw 'Omitted changed production path fixture replacement failed' }
  Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
} 'ARC-CONTRACT-MALFORMED-TABLE: Change Hygiene|responsibility-evidence-missing' $true

Assert-FailsLike 'review rejects duplicate Change Hygiene rows for one changed path' {
  param($root)
  $path = Join-Path $root 'artifacts/implementation-report.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $rows = @($text -split '\r?\n' | Where-Object { $_ -cmatch '^\| WORK-ADMIN \| src/admin_route\.source \|' })
  if ($rows.Count -ne 1) { throw 'Duplicate Change Hygiene fixture anchor is missing or duplicated' }
  Set-Content -Encoding utf8 -LiteralPath $path -Value $text.Replace($rows[0], "$($rows[0])`n$($rows[0])")
} 'responsibility-evidence-missing|change-hygiene-review-mismatch' $true

Assert-FailsLike 'every deleted Git path requires immutable checkpoint evidence even without an owner' {
  param($root)
  Add-DeletedNonOwnerPath $root $false
} 'responsibility-evidence-missing' $true

Assert-Pass 'deleted non-owner Git path accepts exact base-source and removal-diff checkpoint evidence' {
  param($root)
  Add-DeletedNonOwnerPath $root $true
} $true

Assert-FailsLike 'renamed owner rejects destination-only checkpoint and review evidence' {
  param($root)
  Rename-ProductionOwner $root $false
} 'responsibility-evidence-missing' $true $true

Assert-Pass 'renamed owner accepts explicit old-to-new checkpoint and review reconciliation' {
  param($root)
  Rename-ProductionOwner $root $true
} $true $true

Assert-Pass 'review evidence accepts canonical hyphenated repository paths' {
  param($root)
  Rename-ProductionOwner $root $true 'src/admin-route.source'
} $true $true

Assert-FailsLike 'review evidence rejects a source item with a rename delimiter' {
  param($root)
  $path = Join-Path $root 'artifacts/review-report.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $updated = [regex]::Replace($text, '(source:[0-9a-f]{40}:)src/admin_route\.source#', '$1src/admin_route.source->src/admin-route.source#')
  if ($updated -ceq $text) { throw 'Source delimiter fixture replacement failed' }
  Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
} 'responsibility-evidence-missing' $true

Assert-FailsLike 'review evidence rejects parent traversal in a repository path' {
  param($root)
  $path = Join-Path $root 'artifacts/review-report.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $updated = $text.Replace('src/admin_route.source', 'src/../src/admin_route.source')
  if ($updated -ceq $text) { throw 'Review parent traversal fixture replacement failed' }
  Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
} 'responsibility-evidence-missing|change-hygiene-review-mismatch' $true

Assert-Pass 'composed review normalizes Windows repository paths before every authority comparison' {
  param($root)
  Convert-ReviewPathsToWindows $root
} $true $true

Assert-FailsLike 'pinned verification rejects slash-backslash alias duplicate production bindings' {
  param($root)
  Set-PinnedProductionBindings $root @('src/admin_route.source', 'src\admin_route.source')
} 'verification-production-binding-missing' $true $true

Assert-FailsLike 'pinned verification rejects parent traversal in a production binding' {
  param($root)
  Set-PinnedProductionBindings $root @('src\..\src\admin_route.source')
} 'verification-production-binding-missing' $true $true

Assert-FailsLike 'pinned verification rejects a canonical production-binding mismatch' {
  param($root)
  Set-PinnedProductionBindings $root @('src/other_route.source')
} 'verification-production-binding-missing' $true $true

Assert-FailsLike 'wholly commented verification scenario and bindings remain inactive' {
  param($root)
  Comment-OutPinnedVerificationEvidence $root
} 'verification-production-binding-missing' $true $true

Assert-Pass 'review consumes language-valid comment-wrapped verification markers' {
  param($root)
  Use-LanguageValidPinnedVerificationMarkers $root
} $true

Assert-FailsLike 'block-commented language-valid verification markers remain inactive' {
  param($root)
  Use-LanguageValidPinnedVerificationMarkers $root $true
} 'verification-production-binding-missing' $true

Assert-FailsLike 'canonical normalization rejects slash-backslash alias duplication in Change Hygiene' {
  param($root)
  $path = Join-Path $root 'artifacts/implementation-report.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $rows = @($text -split '\r?\n' | Where-Object { $_ -cmatch '^\| WORK-ADMIN \| src/admin_route\.source \|' })
  if ($rows.Count -ne 1) { throw 'Path alias Change Hygiene anchor is missing or duplicated' }
  $aliasRow = $rows[0].Replace('src/admin_route.source', 'src\admin_route.source')
  Set-Content -Encoding utf8 -LiteralPath $path -Value $text.Replace($rows[0], "$($rows[0])`n$aliasRow")
} 'responsibility-evidence-missing|change-hygiene-review-mismatch' $true

Assert-FailsLike 'canonical normalization rejects parent-segment path ambiguity' {
  param($root)
  foreach ($relativePath in @('artifacts/design-report.md', 'artifacts/implementation-report.md', 'artifacts/review-report.md')) {
    $path = Join-Path $root $relativePath
    $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
    Set-Content -Encoding utf8 -LiteralPath $path -Value $text.Replace('src/admin_route.source', 'src\..\src\admin_route.source')
  }
} 'responsibility-evidence-missing|change-hygiene-review-mismatch' $true

Assert-FailsLike 'review rejects a stale existing final-tree SHA after the authorized checkout advances' {
  param($root)
  $provenancePath = Join-Path $root 'artifacts/review-provenance.md'
  $provenance = Get-Content -Raw -Encoding utf8 -LiteralPath $provenancePath
  $sourceRoot = [regex]::Match($provenance, '(?m)^Source Root:\s*(?<value>.+)$').Groups['value'].Value.Trim()
  Set-Content -Encoding utf8 -LiteralPath (Join-Path $sourceRoot 'checkout-advance') -Value 'later authorized checkout'
  Invoke-PinnedSourceGit $sourceRoot @('add', '--', 'checkout-advance') | Out-Null
  Invoke-PinnedSourceGit $sourceRoot @('commit', '-m', 'advance authorized checkout') | Out-Null
  Set-Content -Encoding utf8 -LiteralPath $provenancePath -Value ($provenance.TrimEnd() + "`nCheckout state: advanced`n")
} 'responsibility-evidence-missing' $true

Assert-FailsLike 'review rejects a dirty authorized checkout even when pinned commits remain valid' {
  param($root)
  $provenancePath = Join-Path $root 'artifacts/review-provenance.md'
  $provenance = Get-Content -Raw -Encoding utf8 -LiteralPath $provenancePath
  $sourceRoot = [regex]::Match($provenance, '(?m)^Source Root:\s*(?<value>.+)$').Groups['value'].Value.Trim()
  Set-Content -Encoding utf8 -LiteralPath (Join-Path $sourceRoot 'uncommitted-review-input') -Value 'dirty checkout'
  Set-Content -Encoding utf8 -LiteralPath $provenancePath -Value ($provenance.TrimEnd() + "`nCheckout state: dirty`n")
} 'responsibility-evidence-missing' $true

Assert-FailsLike 'review rejects a reachable task-base that is not an ancestor of final HEAD' {
  param($root)
  Set-UnrelatedReachableTaskBase $root
} 'responsibility-evidence-missing' $true $true

Assert-FailsLike 'review provenance source root must be the actual authorized Git checkout root' {
  param($root)
  $provenancePath = Join-Path $root 'artifacts/review-provenance.md'
  $provenance = Get-Content -Raw -Encoding utf8 -LiteralPath $provenancePath
  $sourceRoot = [regex]::Match($provenance, '(?m)^Source Root:\s*(?<value>.+)$').Groups['value'].Value.Trim()
  $nestedRoot = Join-Path $sourceRoot 'src'
  $updated = $provenance.Replace("Source Root: $sourceRoot", "Source Root: $nestedRoot")
  if ($updated -ceq $provenance) { throw 'Nested checkout-root provenance mutation was a silent no-op' }
  Set-Content -Encoding utf8 -LiteralPath $provenancePath -Value $updated
} 'responsibility-evidence-missing' $true

foreach ($lineEndingCase in @(
  [pscustomobject]@{ Name = 'LF'; NewLine = "`n" }
  [pscustomobject]@{ Name = 'CRLF'; NewLine = "`r`n" }
)) {
  Assert-FailsLike "review independently rejects omitted actual owner ($($lineEndingCase.Name))" {
    param($root)
    $path = Join-Path $root 'artifacts/review-report.md'
    $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
    [IO.File]::WriteAllText($path, [regex]::Replace($text, '\r?\n', $lineEndingCase.NewLine), [Text.UTF8Encoding]::new($false))
    Add-SourceSymbolEvidence $root 'AdminRoute.factoryReset' 'RESP-UNPLANNED'
    Keep-ImplementationSelfAttestationPass $root
  } 'responsibility-owner-extra|responsibility-public-symbol-mismatch' $true

  Assert-FailsLike "review rejects caller-substituted provenance ($($lineEndingCase.Name))" {
    param($root)
    $path = Join-Path $root 'artifacts/review-provenance.md'
    $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
    [IO.File]::WriteAllText($path, [regex]::Replace($text, '\r?\n', $lineEndingCase.NewLine), [Text.UTF8Encoding]::new($false))
    SubstituteReviewProvenanceFinalTree $root
  } 'responsibility-evidence-missing' $true

  Assert-FailsLike "review rejects missing implementation Change Hygiene provenance ($($lineEndingCase.Name))" {
    param($root)
    Set-ArtifactLineEndings $root 'artifacts/implementation-report.md' $lineEndingCase.NewLine "missing Change Hygiene ($($lineEndingCase.Name))"
    Remove-ImplementationChangeHygiene $root
  } '^ARC-CONTRACT-MISSING-TABLE: Change Hygiene$' $true

  Assert-Pass "review accepts incremental owner edit whose declaration predates task base ($($lineEndingCase.Name))" {
    param($root)
    Set-ArtifactLineEndings $root 'artifacts/design-report.md' $lineEndingCase.NewLine "incremental owner edit ($($lineEndingCase.Name))"
    Set-ArtifactLineEndings $root 'artifacts/implementation-report.md' $lineEndingCase.NewLine "incremental owner edit ($($lineEndingCase.Name))"
    Set-ArtifactLineEndings $root 'artifacts/review-report.md' $lineEndingCase.NewLine "incremental owner edit ($($lineEndingCase.Name))"
    Set-ArtifactLineEndings $root 'artifacts/review-provenance.md' $lineEndingCase.NewLine "incremental owner edit ($($lineEndingCase.Name))"
    Add-LineEndingProbe $root $lineEndingCase.NewLine "incremental owner edit ($($lineEndingCase.Name))"
  } $true $true

  Assert-FailsLike "review rejects unplanned full deleted owner ($($lineEndingCase.Name))" {
    param($root)
    Set-ArtifactLineEndings $root 'artifacts/design-report.md' $lineEndingCase.NewLine "unplanned deleted owner ($($lineEndingCase.Name))"
    Set-ArtifactLineEndings $root 'artifacts/implementation-report.md' $lineEndingCase.NewLine "unplanned deleted owner ($($lineEndingCase.Name))"
    Set-ArtifactLineEndings $root 'artifacts/review-report.md' $lineEndingCase.NewLine "unplanned deleted owner ($($lineEndingCase.Name))"
    Set-ArtifactLineEndings $root 'artifacts/review-provenance.md' $lineEndingCase.NewLine "unplanned deleted owner ($($lineEndingCase.Name))"
    Add-LineEndingProbe $root $lineEndingCase.NewLine "unplanned deleted owner ($($lineEndingCase.Name))"
  } 'responsibility-owner-extra|responsibility-evidence-missing' $true $false $true

  Assert-Pass "review accepts approved obsolete deleted owner ($($lineEndingCase.Name))" {
    param($root)
    Approve-DeletedOwner $root
    Set-ArtifactLineEndings $root 'artifacts/design-report.md' $lineEndingCase.NewLine "approved deleted owner ($($lineEndingCase.Name))"
    Set-ArtifactLineEndings $root 'artifacts/implementation-report.md' $lineEndingCase.NewLine "approved deleted owner ($($lineEndingCase.Name))"
    Set-ArtifactLineEndings $root 'artifacts/review-report.md' $lineEndingCase.NewLine "approved deleted owner ($($lineEndingCase.Name))"
    Set-ArtifactLineEndings $root 'artifacts/review-provenance.md' $lineEndingCase.NewLine "approved deleted owner ($($lineEndingCase.Name))"
    Add-LineEndingProbe $root $lineEndingCase.NewLine "approved deleted owner ($($lineEndingCase.Name))"
  } $true $false $true

  Assert-FailsLike "review rejects approved deletion missing base-source/removal-diff Change Hygiene evidence ($($lineEndingCase.Name))" {
    param($root)
    Approve-DeletedOwner $root
    $path = Join-Path $root 'artifacts/implementation-report.md'
    $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
    $updated = [regex]::Replace($text, '(?m)^(\| WORK-ADMIN \| src/obsolete_route\.source \| deleted \| ObsoleteRoute \| none \| none \| )[^|]+( \| [0-9a-f]{40} \| [0-9a-f]{40} \|\r?)$', '$1none$2')
    if ($updated -ceq $text) { throw 'Missing deletion checkpoint evidence fixture replacement failed' }
    Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
  } 'responsibility-evidence-missing' $true $false $true

  Assert-FailsLike "review rejects approved deletion with stale final-tree source evidence ($($lineEndingCase.Name))" {
    param($root)
    Approve-DeletedOwner $root
    $path = Join-Path $root 'artifacts/implementation-report.md'
    $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
    $provenance = Get-Content -Raw -Encoding utf8 -LiteralPath (Join-Path $root 'artifacts/review-provenance.md')
    $taskBaseSha = [regex]::Match($provenance, '(?im)^Task-base SHA:[ \t]*(?<value>[0-9a-f]{40})[ \t]*\r?$').Groups['value'].Value
    $finalTreeSha = [regex]::Match($provenance, '(?im)^Final-tree SHA:[ \t]*(?<value>[0-9a-f]{40})[ \t]*\r?$').Groups['value'].Value
    $expected = "source:${taskBaseSha}:src/obsolete_route.source; diff:${taskBaseSha}..${finalTreeSha}:src/obsolete_route.source"
    $stale = "source:${finalTreeSha}:src/obsolete_route.source; diff:${taskBaseSha}..${finalTreeSha}:src/obsolete_route.source"
    $updated = $text.Replace($expected, $stale)
    if ($updated -ceq $text) { throw 'Stale deletion source evidence fixture replacement failed' }
    Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
  } 'responsibility-evidence-missing' $true $false $true

  Assert-FailsLike "review rejects approved deletion with foreign removal-diff evidence ($($lineEndingCase.Name))" {
    param($root)
    Approve-DeletedOwner $root
    $path = Join-Path $root 'artifacts/implementation-report.md'
    $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
    $updated = $text.Replace(':src/obsolete_route.source; diff:', ':src/obsolete_route.source; diff:').Replace(':src/obsolete_route.source |', ':src/foreign_route.source |')
    if ($updated -ceq $text) { throw 'Foreign deletion diff evidence fixture replacement failed' }
    Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
  } 'responsibility-evidence-missing' $true $false $true
}

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

Assert-FailsLike 'all required architecture and responsibility verdict fields occur exactly once' {
  param($root)
  $path = Join-Path $root 'templates/migration/review-report.md'
  Add-Content -Encoding utf8 -LiteralPath $path -Value '- Verification Ownership Verdict: <PASS | BLOCKED>'
} 'exactly once|Verification Ownership Verdict'

Assert-FailsLike 'a missing mandatory verdict is rejected' {
  param($root)
  $path = Join-Path $root 'templates/migration/review-report.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $text = $text.Replace('- Architecture Conformance Verdict: <PASS | BLOCKED>', '- Architecture verdict omitted: <PASS | BLOCKED>')
  Set-Content -Encoding utf8 -LiteralPath $path -Value $text
} 'exactly once|Architecture Conformance Verdict'

Assert-FailsLike 'a missing Rule Resolution state is rejected' {
  param($root)
  $path = Join-Path $root 'templates/migration/review-report.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $updated = $text.Replace('- Rule Resolution Verdict: <RESOLVED | BLOCKED>', '- Rule resolution omitted: <RESOLVED | BLOCKED>')
  if ($updated -ceq $text) { throw 'Rule Resolution state mutation was a silent no-op' }
  Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
} 'Rule Resolution|State|exactly once'

Assert-FailsLike 'a missing Change Hygiene verdict is rejected' {
  param($root)
  $path = Join-Path $root 'templates/migration/review-report.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $updated = $text.Replace('- Change Hygiene Verdict: <PASS | BLOCKED>', '- Change Hygiene state omitted: <PASS | BLOCKED>')
  if ($updated -ceq $text) { throw 'Change Hygiene verdict mutation was a silent no-op' }
  Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
} 'Change Hygiene Verdict|exactly once'

Assert-FailsLike 'missing Critical and Major counts are rejected' {
  param($root)
  $path = Join-Path $root 'templates/migration/review-report.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $updated = $text.Replace("- Critical count: <non-negative integer>`r`n- Major count: <non-negative integer>`r`n", '')
  if ($updated -ceq $text) {
    $updated = $text.Replace("- Critical count: <non-negative integer>`n- Major count: <non-negative integer>`n", '')
  }
  if ($updated -ceq $text) { throw 'Review count mutation was a silent no-op' }
  Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
} 'Critical count|Major count|exactly once'

Assert-FailsLike 'rendered review verdict is derived from all canonical gates and counts' {
  param($root)
  Set-RenderedReviewFixture $root 'migration-unit' $true
  $path = Join-Path $root 'templates/migration/review-report.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $updated = $text.Replace('- Change Hygiene Verdict: PASS', '- Change Hygiene Verdict: BLOCKED')
  if ($updated -ceq $text) { throw 'Rendered Change Hygiene contradiction mutation was a silent no-op' }
  Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
} 'Change Hygiene|Reject|derived'

Assert-FailsLike 'rendered review handoff cells must equal all visible derived verdicts' {
  param($root)
  Set-RenderedReviewFixture $root 'migration-unit' $true
  $path = Join-Path $root 'templates/migration/review-report.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $updated = $text.Replace('| 1 | PASS | PASS | PASS | PASS | source-diff:', '| 1 | BLOCKED | PASS | PASS | BLOCKED | source-diff:')
  if ($updated -ceq $text) { throw 'Contradictory rendered handoff fixture replacement failed' }
  Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
} 'handoff|Tree Conformance|visible verdict|derived'

Assert-FailsLike 'a fenced verdict example cannot replace the visible template verdict' {
  param($root)
  $path = Join-Path $root 'templates/migration/review-report.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $hiddenVerdict = @'
```text
- Architecture Conformance Verdict: <PASS | BLOCKED>
```
'@
  Set-Content -Encoding utf8 -LiteralPath $path -Value $text.Replace('- Architecture Conformance Verdict: <PASS | BLOCKED>', $hiddenVerdict)
} 'exactly once|Architecture Conformance Verdict'

Assert-FailsLike 'a commented overall verdict cannot replace the visible template control' {
  param($root)
  $path = Join-Path $root 'templates/migration/review-report.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $hiddenVerdict = "<!--`n- Verdict: <Approve | Approve-with-fixes | Reject>`n-->"
  Set-Content -Encoding utf8 -LiteralPath $path -Value $text.Replace('- Verdict: <Approve | Approve-with-fixes | Reject>', $hiddenVerdict)
} 'overall Verdict|exactly once'

Assert-FailsLike 'a fenced behavior-state example cannot replace the visible template control' {
  param($root)
  $path = Join-Path $root 'templates/migration/review-report.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $hiddenState = @'
~~~text
- Behavior Analysis State: <NOT_RUN | COMPLETE>
~~~
'@
  Set-Content -Encoding utf8 -LiteralPath $path -Value $text.Replace('- Behavior Analysis State: <NOT_RUN | COMPLETE>', $hiddenState)
} 'Behavior Analysis State|exactly once'

Assert-FailsLike 'a commented delivery-adapter example cannot replace the visible template control' {
  param($root)
  $path = Join-Path $root 'templates/migration/review-report.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $hiddenAdapter = "<!--`n- Delivery Adapter Kind: <migration-unit | task | story | package | phase | milestone | none>`n-->"
  Set-Content -Encoding utf8 -LiteralPath $path -Value $text.Replace('- Delivery Adapter Kind: <migration-unit | task | story | package | phase | milestone | none>', $hiddenAdapter)
} 'Delivery Adapter Kind|exactly once'

Assert-FailsLike 'a commented selected-unit policy cannot replace the visible template control' {
  param($root)
  $path = Join-Path $root 'templates/migration/review-report.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $policy = 'Keep `Selected Migration Unit` only when `Delivery Adapter Kind` is `migration-unit`; otherwise omit it.'
  Set-Content -Encoding utf8 -LiteralPath $path -Value $text.Replace($policy, "<!-- $policy -->")
} 'Selected Migration Unit|migration-unit'

Assert-FailsLike 'a fenced Master Scope Context table cannot satisfy the visible template contract' {
  param($root)
  $path = Join-Path $root 'templates/migration/review-report.md'
  $text = [regex]::Replace((Get-Content -Raw -Encoding utf8 -LiteralPath $path), '\r?\n', "`n")
  $table = "| Run ID | Master Spec Reference | Master Spec ID | Master Spec Revision | Master Plan Reference | Master Plan ID | Master Plan Revision | Work Item ID |`n|---|---|---|---|---|---|---|---|`n| <RUN-*> | <master spec reference> | <SPEC-*> | <revision> | <master plan reference> | <PLAN-*> | <revision> | <WORK-*> |"
  if (-not $text.Contains($table)) { throw 'Scenario setup could not find Master Scope Context table' }
  $hiddenTable = '```markdown' + "`n" + $table + "`n" + '```'
  [IO.File]::WriteAllText($path, $text.Replace($table, $hiddenTable), [Text.UTF8Encoding]::new($false))
} 'Master Scope Context|table'

Assert-FailsLike 'a commented Task Provenance table cannot satisfy the visible template contract' {
  param($root)
  $path = Join-Path $root 'templates/migration/review-report.md'
  $text = [regex]::Replace((Get-Content -Raw -Encoding utf8 -LiteralPath $path), '\r?\n', "`n")
  $table = [regex]::Match($text, '(?m)^\| Task / Unit \| Task-base SHA \| Final-tree SHA \| Source Artifact \|\n\|---\|---\|---\|---\|\n\| .+ \|$').Value
  if ($table -eq '') { throw 'Scenario setup could not find Task Provenance table' }
  [IO.File]::WriteAllText($path, $text.Replace($table, "<!--`n$table`n-->"), [Text.UTF8Encoding]::new($false))
} 'Task Provenance|table'

Assert-FailsLike 'a fenced Architecture Responsibility Handoff table cannot satisfy the visible template contract' {
  param($root)
  $path = Join-Path $root 'templates/migration/review-report.md'
  $text = [regex]::Replace((Get-Content -Raw -Encoding utf8 -LiteralPath $path), '\r?\n', "`n")
  $table = "| Responsibility Contract Version | Tree Conformance | Responsibility Conformance | Verification Ownership | Architecture Conformance State | Evidence References |`n|---|---|---|---|---|---|`n| 1 | <tree verdict> | <responsibility verdict> | <verification verdict> | <derived architecture state> | source-diff:<task-base SHA>..<final-tree SHA>#<WORK-*> |"
  if (-not $text.Contains($table)) { throw 'Scenario setup could not find Architecture Responsibility Handoff table' }
  [IO.File]::WriteAllText($path, $text.Replace($table, "~~~markdown`n$table`n~~~"), [Text.UTF8Encoding]::new($false))
} 'Architecture Responsibility Handoff|table'

Assert-FailsLike 'a commented Responsibility Review Evidence table cannot satisfy the visible template contract' {
  param($root)
  $path = Join-Path $root 'templates/migration/review-report.md'
  $text = [regex]::Replace((Get-Content -Raw -Encoding utf8 -LiteralPath $path), '\r?\n', "`n")
  $table = "| Responsibility ID | Source/Diff Evidence | Planned Public Symbols | Actual Public Symbols | Planned Effects | Actual Effects | Verdict |`n|---|---|---|---|---|---|---|"
  if (-not $text.Contains($table)) { throw 'Scenario setup could not find Responsibility Review Evidence table' }
  [IO.File]::WriteAllText($path, $text.Replace($table, "<!--`n$table`n-->"), [Text.UTF8Encoding]::new($false))
} 'Responsibility Review Evidence|header|table'

Assert-FailsLike 'a fenced selector evidence control cannot satisfy the visible template contract' {
  param($root)
  $path = Join-Path $root 'templates/migration/review-report.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $control = [regex]::Match($text, '(?m)^- Evidence: [^\r\n]+').Value
  if ($control -eq '') { throw 'Scenario setup could not find selector evidence control' }
  $hiddenControl = '```text' + "`n" + $control + "`n" + '```'
  Set-Content -Encoding utf8 -LiteralPath $path -Value $text.Replace($control, $hiddenControl)
} 'canonical selector|Evidence'

Assert-FailsLike 'commented architecture controls cannot satisfy the visible template contract' {
  param($root)
  $path = Join-Path $root 'templates/migration/review-report.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  foreach ($label in @('Conformance Matrix Reference', 'Exemplars', 'Actual File Tree vs Planned File Tree')) {
    $control = [regex]::Match($text, '(?m)^- ' + [regex]::Escape($label) + ': .+$').Value
    if ($control -eq '') { throw "Scenario setup could not find architecture control: $label" }
    $text = $text.Replace($control, "<!-- $control -->")
  }
  Set-Content -Encoding utf8 -LiteralPath $path -Value $text
} 'architecture conformance|Conformance Matrix|Exemplars|Actual File Tree'

Assert-FailsLike 'fenced activation controls cannot satisfy the visible template contract' {
  param($root)
  $path = Join-Path $root 'templates/migration/review-report.md'
  $text = [regex]::Replace((Get-Content -Raw -Encoding utf8 -LiteralPath $path), '\r?\n', "`n")
  $controls = [regex]::Match($text, '(?m)^- Production Activation Path Evidence: .+\n- Production Subscription Key: .+\n- Lifecycle Gate: .+$').Value
  if ($controls -eq '') { throw 'Scenario setup could not find activation controls' }
  [IO.File]::WriteAllText($path, $text.Replace($controls, "~~~text`n$controls`n~~~"), [Text.UTF8Encoding]::new($false))
} 'production activation path|Evidence|Subscription|Lifecycle'

Assert-FailsLike 'a four-space-indented overall verdict cannot satisfy the visible template control' {
  param($root)
  $path = Join-Path $root 'templates/migration/review-report.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  Set-Content -Encoding utf8 -LiteralPath $path -Value $text.Replace('- Verdict: <Approve | Approve-with-fixes | Reject>', '    - Verdict: <Approve | Approve-with-fixes | Reject>')
} 'overall Verdict|exactly once'

Assert-FailsLike 'a tab-indented delivery adapter cannot satisfy the visible template control' {
  param($root)
  $path = Join-Path $root 'templates/migration/review-report.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $control = '- Delivery Adapter Kind: <migration-unit | task | story | package | phase | milestone | none>'
  Set-Content -Encoding utf8 -LiteralPath $path -Value $text.Replace($control, "`t$control")
} 'Delivery Adapter Kind|exactly once'

Assert-FailsLike 'a four-space-indented selector control cannot satisfy the visible template contract' {
  param($root)
  $path = Join-Path $root 'templates/migration/review-report.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  Set-Content -Encoding utf8 -LiteralPath $path -Value $text.Replace('- Evidence: <selector evidence>', '    - Evidence: <selector evidence>')
} 'canonical selector|Evidence'

Assert-FailsLike 'a four-space-indented required table cannot satisfy the visible template contract' {
  param($root)
  $path = Join-Path $root 'templates/migration/review-report.md'
  $text = [regex]::Replace((Get-Content -Raw -Encoding utf8 -LiteralPath $path), '\r?\n', "`n")
  $table = "| Run ID | Master Spec Reference | Master Spec ID | Master Spec Revision | Master Plan Reference | Master Plan ID | Master Plan Revision | Work Item ID |`n|---|---|---|---|---|---|---|---|`n| <RUN-*> | <master spec reference> | <SPEC-*> | <revision> | <master plan reference> | <PLAN-*> | <revision> | <WORK-*> |"
  if (-not $text.Contains($table)) { throw 'Scenario setup could not find Master Scope Context table' }
  $indentedTable = @($table -split "`n" | ForEach-Object { "    $_" }) -join "`n"
  [IO.File]::WriteAllText($path, $text.Replace($table, $indentedTable), [Text.UTF8Encoding]::new($false))
} 'Master Scope Context|table'

Assert-FailsLike 'a tab-indented canonical heading cannot satisfy the visible template contract' {
  param($root)
  $path = Join-Path $root 'templates/migration/review-report.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  Set-Content -Encoding utf8 -LiteralPath $path -Value $text.Replace('## Canonical Selector', "`t## Canonical Selector")
} 'Canonical Selector|section|exactly once'

Assert-Pass 'one-to-three-space Markdown indentation remains visible to template controls' {
  param($root)
  $path = Join-Path $root 'templates/migration/review-report.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $text = $text.Replace('## Canonical Selector', '   ## Canonical Selector')
  $text = $text.Replace('- Evidence: <selector evidence>', '   - Evidence: <selector evidence>')
  $text = $text.Replace('- Delivery Adapter Kind: <migration-unit | task | story | package | phase | milestone | none>', '   - Delivery Adapter Kind: <migration-unit | task | story | package | phase | milestone | none>')
  $text = $text.Replace('- Verdict: <Approve | Approve-with-fixes | Reject>', '   - Verdict: <Approve | Approve-with-fixes | Reject>')
  Set-Content -Encoding utf8 -LiteralPath $path -Value $text
}

Assert-FailsLike 'verdict values use the exact enum' {
  param($root)
  $path = Join-Path $root 'templates/migration/review-report.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $text = $text.Replace('<PASS | BLOCKED | NOT_APPLICABLE>', '<PASS | BLOCKED | N/A>')
  Set-Content -Encoding utf8 -LiteralPath $path -Value $text
} 'invalid verdict|Production Activation-path Verdict'

Assert-FailsLike 'a blocked architecture verdict forces Reject independent of counts' {
  param($root)
  Set-RenderedReviewFixture $root 'migration-unit' $true
  $path = Join-Path $root 'templates/migration/review-report.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $text = $text.Replace('- Canonical Selector Verdict: PASS', '- Canonical Selector Verdict: BLOCKED')
  $text = $text.Replace('- Behavior Analysis State: COMPLETE', '- Behavior Analysis State: NOT_RUN')
  Set-Content -Encoding utf8 -LiteralPath $path -Value $text
} 'BLOCKED|Reject|severity'

Assert-FailsLike 'blocked structural verdict stops before behavior analysis' {
  param($root)
  Set-RenderedReviewFixture $root 'migration-unit' $true
  $path = Join-Path $root 'templates/migration/review-report.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $text = $text.Replace('- Canonical Selector Verdict: PASS', '- Canonical Selector Verdict: BLOCKED')
  $text = $text.Replace('- Verdict: Approve', '- Verdict: Reject')
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
  'Tree Conformance Verdict',
  'Responsibility Conformance Verdict',
  'Verification Ownership Verdict',
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
  $text = $text.Replace('<migration-unit | task | story | package | phase | milestone | none>', 'task')
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
  $text = [regex]::Replace($text, '\r?\n', "`n")
  $table = "| Run ID | Master Spec Reference | Master Spec ID | Master Spec Revision | Master Plan Reference | Master Plan ID | Master Plan Revision | Work Item ID |`n|---|---|---|---|---|---|---|---|`n| <RUN-*> | <master spec reference> | <SPEC-*> | <revision> | <master plan reference> | <PLAN-*> | <revision> | <WORK-*> |"
  if (-not $text.Contains($table)) { throw 'Scenario setup could not find Master Scope Context table' }
  $text = $text.Replace($table, "$table`n`n$table")
  [IO.File]::WriteAllText($path, $text, [Text.UTF8Encoding]::new($false))
} 'exactly one|duplicate|table'

Assert-FailsLike 'malformed Master Scope Context separator is rejected' {
  param($root)
  $path = Join-Path $root 'templates/migration/review-report.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $text = $text.Replace('|---|---|---|---|---|---|---|---|', '|===|===|===|===|===|===|===|===|')
  Set-Content -Encoding utf8 -LiteralPath $path -Value $text
} 'delimiter|separator|table'

$strictTableCases = @(
  [pscustomobject]@{
    Name = 'Master Scope Context'
    RelativePath = 'templates/migration/review-report.md'
    Lines = @(
      '| Run ID | Master Spec Reference | Master Spec ID | Master Spec Revision | Master Plan Reference | Master Plan ID | Master Plan Revision | Work Item ID |',
      '|---|---|---|---|---|---|---|---|',
      '| <RUN-*> | <master spec reference> | <SPEC-*> | <revision> | <master plan reference> | <PLAN-*> | <revision> | <WORK-*> |'
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

$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$contractPath = Join-Path $root 'contracts/file-responsibility-conformance.md'
$validatorPath = Join-Path $root 'tests/validation/responsibility-conformance.validation.ps1'
$rolloutValidatorPath = Join-Path $root 'tests/validation/architecture-review.validation.ps1'
$migrateSkillPath = Join-Path $root 'skills/aitoolkit/migrate/SKILL.md'
$implementationTemplatePath = Join-Path $root 'templates/migration/implementation-report.md'
$reviewTemplatePath = Join-Path $root 'templates/migration/review-report.md'
$knowledgeBaseTemplatePath = Join-Path $root 'templates/kb-entry.md'
$gerritTemplatePath = Join-Path $root 'templates/gerrit-report.md'
$knowledgeBaseSkillPath = Join-Path $root 'skills/shared/knowledge-base/SKILL.md'
$gerritSkillPath = Join-Path $root 'skills/shared/gerrit-automation/SKILL.md'
$activationContractPath = Join-Path $root 'contracts/activation-slice.md'

if (-not (Test-Path -LiteralPath $contractPath)) { throw 'Responsibility contract file is missing' }
if (-not (Test-Path -LiteralPath $validatorPath)) { throw 'Responsibility handoff validator is missing' }
if (-not (Test-Path -LiteralPath $rolloutValidatorPath)) { throw 'Responsibility rollout validator is missing' }
if (-not (Test-Path -LiteralPath $migrateSkillPath)) { throw 'Migration orchestrator skill is missing' }
if (-not (Test-Path -LiteralPath $implementationTemplatePath)) { throw 'Migration implementation producer template is missing' }
if (-not (Test-Path -LiteralPath $reviewTemplatePath)) { throw 'Migration review producer template is missing' }
if (-not (Test-Path -LiteralPath $knowledgeBaseTemplatePath)) { throw 'Knowledge Base producer template is missing' }
if (-not (Test-Path -LiteralPath $knowledgeBaseSkillPath)) { throw 'Knowledge Base producer skill is missing' }
if (-not (Test-Path -LiteralPath $gerritSkillPath)) { throw 'Gerrit producer skill is missing' }
if (-not (Test-Path -LiteralPath $gerritTemplatePath)) { throw 'Gerrit producer template is missing' }
if (-not (Test-Path -LiteralPath $activationContractPath)) { throw 'Activation contract is missing' }

. $validatorPath
. $rolloutValidatorPath
$contract = Get-Content -Raw -Encoding utf8 -LiteralPath $contractPath
$migrateSkill = Get-Content -Raw -Encoding utf8 -LiteralPath $migrateSkillPath
$activationContract = Get-Content -Raw -Encoding utf8 -LiteralPath $activationContractPath
$knowledgeBaseSkill = Get-Content -Raw -Encoding utf8 -LiteralPath $knowledgeBaseSkillPath
$gerritSkill = Get-Content -Raw -Encoding utf8 -LiteralPath $gerritSkillPath
$gerritTemplate = Get-Content -Raw -Encoding utf8 -LiteralPath $gerritTemplatePath
$knowledgeBaseTemplate = Get-Content -Raw -Encoding utf8 -LiteralPath $knowledgeBaseTemplatePath
$canonicalSourceDiffTemplate = 'source-diff:<task-base SHA>..<final-tree SHA>#<WORK-*>'
$legacyResponsibilityEvidence = 'review-report.md#responsibility-evidence'
$conclusionHeading = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('S+G6v3QgbHXhuq1u'))
$migrationConclusionHeading = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('S+G6v3QgbHXhuq1uIHjDoWMgbWluaCBtaWdyYXRpb24='))
$runSummaryHeading = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('VMOzbSB04bqvdCBydW4='))
$terminalVerificationHeading = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('WMOhYyBtaW5oIMSR4bqndSBjdeG7kWk='))
$scenarioHeading = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('S+G7i2NoIGLhuqNu'))
$verdictSeparator = [char]0x2014
if ($knowledgeBaseTemplate.IndexOf($canonicalSourceDiffTemplate, [StringComparison]::Ordinal) -lt 0) {
  throw "Knowledge Base producer template must emit the canonical source-diff handoff placeholder: $canonicalSourceDiffTemplate"
}
if ($knowledgeBaseTemplate.IndexOf($legacyResponsibilityEvidence, [StringComparison]::Ordinal) -ge 0) {
  throw "Knowledge Base producer template retains obsolete handoff evidence: $legacyResponsibilityEvidence"
}
if (
  $knowledgeBaseTemplate.IndexOf('review-originated source-diff', [StringComparison]::Ordinal) -lt 0 -or
  $knowledgeBaseTemplate.IndexOf('never replaces this handoff cell', [StringComparison]::Ordinal) -lt 0
) {
  throw 'Knowledge Base producer template must distinguish immutable source-diff handoff evidence from terminal-chain authority'
}
if (
  $knowledgeBaseSkill.IndexOf('preserve exact review-originated source-diff', [StringComparison]::Ordinal) -lt 0 -or
  $knowledgeBaseSkill.IndexOf('Resolve terminal-chain authority separately', [StringComparison]::Ordinal) -lt 0
) {
  throw 'Knowledge Base producer skill must fail closed on mutated source-diff evidence without treating the handoff cell as terminal-chain authority'
}
foreach ($deliveryContract in @(
  [pscustomobject]@{ Text = $gerritSkill; Token = 'For `Delivery Adapter Kind = migration-unit`, require exactly one `Selected Migration Unit`'; Context = 'Gerrit migration-unit cardinality' },
  [pscustomobject]@{ Text = $gerritSkill; Token = 'require zero `Selected Migration Unit` sections'; Context = 'Gerrit generic cardinality' },
  [pscustomobject]@{ Text = $gerritSkill; Token = 'review -> verification -> parity -> regression -> Knowledge Base'; Context = 'Gerrit incremental assurance lineage' },
  [pscustomobject]@{ Text = $gerritSkill; Token = 'KB/Gerrit equality comparison is never sufficient authority'; Context = 'Gerrit paired-equality prohibition' },
  [pscustomobject]@{ Text = $gerritTemplate; Token = '## Master Scope Context'; Context = 'Gerrit master scope envelope' },
  [pscustomobject]@{ Text = $gerritTemplate; Token = '- Delivery Adapter Mode Constraint:'; Context = 'Gerrit mode envelope' },
  [pscustomobject]@{ Text = $gerritTemplate; Token = 'paired KB/Gerrit equality alone is not authority'; Context = 'Gerrit template lineage prerequisite' },
  [pscustomobject]@{ Text = $gerritTemplate; Token = 'otherwise exact WORK-*'; Context = 'Gerrit generic identity template' }
)) {
  if ($deliveryContract.Text.IndexOf($deliveryContract.Token, [StringComparison]::Ordinal) -lt 0) { throw "$($deliveryContract.Context) missing: $($deliveryContract.Token)" }
}
if ($gerritTemplate.IndexOf('<terminal kb-entry.md>', [StringComparison]::Ordinal) -ge 0) {
  throw 'Gerrit producer template must not rewrite immutable Task Provenance to the terminal KB filename'
}
if ($gerritTemplate.IndexOf('<immediate predecessor artifact path copied unchanged from terminal Knowledge Base Task Provenance>', [StringComparison]::Ordinal) -lt 0) {
  throw 'Gerrit producer template must preserve the exact Knowledge Base Task Provenance Source Artifact cell'
}
foreach ($token in @(
  'Adapter Kind Applicability',
  '`migration-unit` | `Selected Migration Unit`',
  '`task, story, package, phase, milestone, none` | `<absent>`',
  'Adapter Kind=migration-unit => Task / Unit=Selected Migration Unit.Migration Unit ID; Adapter Kind=generic => Task / Unit=Master Scope Context.Work Item ID'
)) {
  if ($activationContract.IndexOf($token, [StringComparison]::Ordinal) -lt 0) { throw "Activation contract missing canonical adapter-aware selected-unit rule: $token" }
}

foreach ($relativePath in @(
  'skills/shared/verification-testing/SKILL.md',
  'skills/migration/verify-parity/SKILL.md',
  'skills/migration/verify-regression/SKILL.md'
)) {
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath (Join-Path $root $relativePath)
  foreach ($token in @('Delivery Adapter Kind', 'Delivery Adapter Mode Constraint', 'only when `Delivery Adapter Kind` is `migration-unit`', 'omit `Selected Migration Unit`')) {
    if ($text.IndexOf($token, [StringComparison]::Ordinal) -lt 0) { throw "$relativePath missing adapter-aware downstream rule: $token" }
  }
}
foreach ($relativePath in @(
  'templates/migration/verification-report.md',
  'templates/migration/parity-report.md',
  'templates/migration/regression-report.md'
)) {
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath (Join-Path $root $relativePath)
  foreach ($token in @('## Master Scope Context', '- Delivery Adapter Kind:', '- Delivery Adapter Mode Constraint:', 'Keep `Selected Migration Unit` only when `Delivery Adapter Kind` is `migration-unit`; otherwise omit it.', $canonicalSourceDiffTemplate)) {
    if ($text.IndexOf($token, [StringComparison]::Ordinal) -lt 0) { throw "$relativePath missing adapter-aware downstream template seam: $token" }
  }
  if ($text.IndexOf($legacyResponsibilityEvidence, [StringComparison]::Ordinal) -ge 0) { throw "$relativePath retains obsolete handoff evidence: $legacyResponsibilityEvidence" }
}

function New-HandoffArtifact {
  param(
    [Parameter(Mandatory)][string]$StepId,
    [Parameter(Mandatory)][string]$SourceArtifact,
    [string]$TaskUnit = '',
    [string]$WorkItemId = 'WORK-ADMIN-LOCK',
    [string]$Tree = 'PASS',
    [string]$Responsibility = 'PASS',
    [string]$Verification = 'PASS',
    [string]$Architecture = 'PASS',
    [string]$Evidence = '',
    [string]$TaskBaseSha = '1111111111111111111111111111111111111111',
    [string]$FinalTreeSha = '2222222222222222222222222222222222222222',
    [string]$Status = 'approved',
    [string]$Result = 'complete',
    [string]$ApprovalSource = 'human',
    [string]$RunId = 'RUN-HANDOFF-001',
    [string]$MasterSpecReference = 'master-spec.md',
    [string]$MasterSpecId = 'SPEC-HANDOFF-001',
    [string]$MasterPlanReference = 'master-plan.md',
    [string]$MasterPlanId = 'PLAN-HANDOFF-001',
    [string]$AdapterKind = 'migration-unit',
    [switch]$OmitSelectedMigrationUnit,
    [string]$ReviewVerdict = 'Approve',
    [int]$CriticalCount = 0,
    [int]$MajorCount = 0,
    [string]$RuleResolution = 'RESOLVED',
    [string]$CanonicalSelector = 'PASS',
    [string]$ProductionActivation = 'NOT_APPLICABLE',
    [string]$BehaviorState = 'COMPLETE',
    [string]$ChangeHygiene = 'PASS',
    [string]$ModeConstraint = 'incremental/preserve-existing',
    [string]$BootstrapScope = 'not-required',
    [string]$FoundationBaselineId = 'not-applicable',
    [string]$FoundationBaselineReference = 'not-applicable',
    [string]$FoundationBaselineApprovalReference = 'not-applicable',
    [string]$BaselineReference = 'baseline.md#BASE-ADMIN',
    [string]$SelectedTraceIds = 'REQ-001',
    [string]$VerificationStageVerdict = 'PASS',
    [string]$ParityStageVerdict = 'pass',
    [string]$ParityScenarioVerdict = 'pass',
    [string]$RegressionApplicability = 'required',
    [string]$RegressionStageVerdict = 'pass',
    [string]$RegressionScenarioVerdict = 'pass',
    [string]$StageEvidence = 'evidence:command-output-pass',
    [string]$Waiver = ''
  )

  if ($TaskUnit -eq '') { $TaskUnit = if ($AdapterKind -ceq 'migration-unit') { 'UNIT-ADMIN-LOCK' } else { $WorkItemId } }
  if ($Evidence -eq '') { $Evidence = "source-diff:$TaskBaseSha..$FinalTreeSha#$WorkItemId" }
  $waiverText = if ($Waiver -eq '') { '' } else { "`n$Waiver" }
  $approvalText = if ($ApprovalSource -eq '') { '' } else { "approval_source: $ApprovalSource`n" }
  $reviewConclusionText = if ($StepId -ceq '11-ai-review') {
@"
## Rule Resolution
- Rule Resolution Verdict: $RuleResolution

## Canonical Selector
- Canonical Selector Verdict: $CanonicalSelector

## Architecture Conformance
- Architecture Conformance Verdict: $Architecture

## Responsibility Review Evidence
- Tree Conformance Verdict: $Tree
- Responsibility Conformance Verdict: $Responsibility
- Verification Ownership Verdict: $Verification

## Production Activation Path
- Production Activation-path Verdict: $ProductionActivation

## Behavior, Failure Modes, Security, Performance, and Tests
- Behavior Analysis State: $BehaviorState

## Critical
| File:line | Issue | Proposed fix |
|---|---|---|
| none | none | none |

## Major
| File:line | Issue | Proposed fix |
|---|---|---|
| none | none | none |

## Change Hygiene
- Change Hygiene Verdict: $ChangeHygiene

## Conclusion
- Critical count: $CriticalCount
- Major count: $MajorCount
- Verdict: $ReviewVerdict

"@
  } else { '' }
  $selectedUnitText = if ($AdapterKind -eq 'migration-unit' -and -not $OmitSelectedMigrationUnit) {
@"
## Selected Migration Unit

| Migration Unit ID | Plan Reference | Approval Reference | Mode Constraint | Bootstrap Scope | Foundation Baseline ID | Foundation Baseline Reference | Foundation Baseline Approval Reference | Baseline Reference | Trace IDs |
|---|---|---|---|---|---|---|---|---|---|
| UNIT-ADMIN-LOCK | 08-migration-plan.md@1 | approval:UNIT-ADMIN-LOCK | $ModeConstraint | $BootstrapScope | $FoundationBaselineId | $FoundationBaselineReference | $FoundationBaselineApprovalReference | $BaselineReference | $SelectedTraceIds |

"@
  } else { '' }
  $terminalMode = if ($ModeConstraint -ceq 'greenfield/design-new') { 'greenfield' } else { 'incremental' }
  $terminalUnit = if ($AdapterKind -ceq 'migration-unit') { 'UNIT-ADMIN-LOCK' } else { 'not-applicable' }
  $stageVerdictText = switch ($StepId) {
    '12-verification-testing' {
@"
## $conclusionHeading

$VerificationStageVerdict $verdictSeparator $StageEvidence

"@
    }
    '13-verify-parity' {
@"
## Parity Verdict

| Parity Verdict | Evidence Reference |
|---|---|
| $ParityStageVerdict | $StageEvidence |

## $scenarioHeading

| Scenario | Baseline | Actual | Verdict |
|---|---|---|---|
| admin lock parity | legacy:locked | target:locked | $ParityScenarioVerdict |

"@
    }
    '14-verify-regression' {
@"
## $migrationConclusionHeading

| Parity Verdict | Regression Applicability | Regression Verdict | Evidence Reference |
|---|---|---|---|
| $ParityStageVerdict | $RegressionApplicability | $RegressionStageVerdict | $StageEvidence |

## $scenarioHeading

| Scenario | Baseline | Actual | Delta Class | Waiver Reference | Trace IDs | Verdict |
|---|---|---|---|---|---|---|
| admin lock regression | baseline:locked | target:locked | expected | not-applicable | REQ-001 | $RegressionScenarioVerdict |

"@
    }
    '15-knowledge-base' {
@"
## $runSummaryHeading
- Workflow Type: migration
- Terminal Input Artifact: $SourceArtifact
- Completion Verdict: complete
- Release Verdict: not-run

## $terminalVerificationHeading

| Workflow Type | Mode | Migration Unit ID | Terminal Verification Artifact | Verification Verdict | Completion Verdict |
|---|---|---|---|---|---|
| migration | $terminalMode | $terminalUnit | $SourceArtifact | $VerificationStageVerdict | complete |

"@
    }
    default { '' }
  }
  return @"
---
step_id: $StepId
status: $Status
result: $Result
$approvalText
produced_at: 2026-08-20
responsibility_contract:
  version: 1
  applicability: required
---

## Master Scope Context

| Run ID | Master Spec Reference | Master Spec ID | Master Spec Revision | Master Plan Reference | Master Plan ID | Master Plan Revision | Work Item ID |
|---|---|---|---|---|---|---|---|
| $RunId | $MasterSpecReference | $MasterSpecId | 1 | $MasterPlanReference | $MasterPlanId | 1 | $WorkItemId |

- Delivery Adapter Kind: $AdapterKind
- Delivery Adapter Mode Constraint: $ModeConstraint

## Task Provenance

| Task / Unit | Task-base SHA | Final-tree SHA | Source Artifact |
|---|---|---|---|
| $TaskUnit | $TaskBaseSha | $FinalTreeSha | $SourceArtifact |

$selectedUnitText
## Architecture Responsibility Handoff

| Responsibility Contract Version | Tree Conformance | Responsibility Conformance | Verification Ownership | Architecture Conformance State | Evidence References |
|---|---|---|---|---|---|
| 1 | $Tree | $Responsibility | $Verification | $Architecture | $Evidence |
$reviewConclusionText
$stageVerdictText
$waiverText
"@
}

function New-ApprovedAdapterPlan {
  param(
    [ValidateSet('migration-unit','task','story','package','phase','milestone')][string]$AdapterKind = 'migration-unit',
    [string]$WorkItemId = 'WORK-ADMIN-LOCK',
    [string]$SelectorApproval = 'approval:UNIT-ADMIN-LOCK',
    [string]$SelectorTraceIds = 'REQ-001',
    [string]$SelectorMode = 'incremental/preserve-existing',
    [string]$AuthorityRevision = '1',
    [string]$WorkItemApproval = 'approval:WORK-ADMIN-LOCK',
    [string]$BootstrapScope = 'not-required',
    [string]$FoundationBaselineId = 'not-applicable',
    [string]$FoundationBaselineReference = 'not-applicable',
    [string]$FoundationBaselineApprovalReference = 'not-applicable',
    [string]$BaselineReference = 'baseline.md#BASE-ADMIN',
    [switch]$OmitSelectorTable
  )
  $externalId = @{
    'migration-unit' = 'UNIT-ADMIN-LOCK'; task = 'TASK-ADMIN-LOCK'; story = 'STORY-ADMIN-LOCK'
    package = 'pkg:admin-locks'; phase = 'PHASE-ADMIN-LOCK'; milestone = 'MILESTONE-ADMIN-LOCK'
  }[$AdapterKind]
  $authority = @{
    'migration-unit' = '08-migration-plan.md'; task = 'jira:ADMIN-LOCK'; story = 'ado:ADMIN-LOCK'
    package = 'repo:packages'; phase = 'plan:ADMIN'; milestone = 'roadmap:ADMIN'
  }[$AdapterKind]
  $selectorTable = if ($OmitSelectorTable) { '' } else { @"
## Delivery Adapter Selection

| Work Item ID | Adapter Kind | External ID | Authority | Authority Revision | Approval Reference | Parent Selector | Acceptance | Trace IDs | Mode Constraint | Design Revision | Parent Work Item ID | Decomposition Decision Reference |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| $WorkItemId | $AdapterKind | $externalId | $authority | $AuthorityRevision | $SelectorApproval | not-applicable | REQ-001; SC-001; completes within 2 seconds | $SelectorTraceIds | $SelectorMode | DESIGN-ADMIN@2 | not-applicable | not-applicable |
"@ }
  return @"
---
artifact_type: migration-master-plan
master_plan_id: PLAN-HANDOFF-001
master_spec_id: SPEC-HANDOFF-001
master_spec_revision: 1
revision: 1
status: approved
produced_at: 2026-08-20
---

$selectorTable

## Work Items

| Work Item ID | Title | Required | Dependencies | Plan Order | Acceptance | Trace IDs | Delivery Adapter | Status | Latest Attempt | Terminal Evidence | Approval Reference |
|---|---|---|---|---|---|---|---|---|---|---|---|
| $WorkItemId | Admin lock | yes | none | 1 | REQ-001; SC-001; completes within 2 seconds | REQ-001 | $AdapterKind`:$externalId | complete | ATTEMPT-ADMIN-01 | terminal-admin.md | $WorkItemApproval |
"@
}

function New-ParentChildAdapterPlan {
  return @"
---
artifact_type: migration-master-plan
master_plan_id: PLAN-HANDOFF-001
master_spec_id: SPEC-HANDOFF-001
master_spec_revision: 1
revision: 1
status: approved
produced_at: 2026-08-20
---

## Delivery Adapter Selection

| Work Item ID | Adapter Kind | External ID | Authority | Authority Revision | Approval Reference | Parent Selector | Acceptance | Trace IDs | Mode Constraint | Design Revision | Parent Work Item ID | Decomposition Decision Reference |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| WORK-ADMIN-PARENT | task | TASK-ADMIN-PARENT | jira:ADMIN-PARENT | 1 | approval:TASK-ADMIN-PARENT | not-applicable | REQ-001; SC-001; completes within 2 seconds | REQ-001 | incremental/preserve-existing | DESIGN-ADMIN@2 | not-applicable | not-applicable |
| WORK-ADMIN-CHILD | story | STORY-ADMIN-CHILD | ado:ADMIN-CHILD | 1 | approval:STORY-ADMIN-CHILD | TASK-ADMIN-PARENT | REQ-001; SC-001; completes within 2 seconds | REQ-001 | incremental/preserve-existing | DESIGN-ADMIN@2 | WORK-ADMIN-PARENT | DEC-ADMIN-CHILD |

## Work Items

| Work Item ID | Title | Required | Dependencies | Plan Order | Acceptance | Trace IDs | Delivery Adapter | Status | Latest Attempt | Terminal Evidence | Approval Reference |
|---|---|---|---|---|---|---|---|---|---|---|---|
| WORK-ADMIN-PARENT | Parent | yes | none | 1 | REQ-001; SC-001; completes within 2 seconds | REQ-001 | task:TASK-ADMIN-PARENT | complete | ATTEMPT-PARENT-01 | terminal-parent.md | approval:WORK-ADMIN-PARENT |
| WORK-ADMIN-CHILD | Child | yes | WORK-ADMIN-PARENT | 2 | REQ-001; SC-001; completes within 2 seconds | REQ-001 | story:STORY-ADMIN-CHILD | in-progress | ATTEMPT-CHILD-01 | none | approval:WORK-ADMIN-CHILD |
"@
}

function New-ProducerImplementationArtifact {
  param(
    [ValidateSet('migration-unit','task','none')][string]$AdapterKind = 'migration-unit',
    [string]$WorkItemId = 'WORK-ADMIN-LOCK',
    [string]$ModeConstraint = 'incremental/preserve-existing',
    [string]$BootstrapScope = 'not-required',
    [string]$FoundationBaselineId = 'not-applicable',
    [string]$FoundationBaselineReference = 'not-applicable',
    [string]$FoundationBaselineApprovalReference = 'not-applicable',
    [string]$BaselineReference = 'baseline.md#BASE-ADMIN',
    [string]$SelectedTraceIds = 'REQ-001',
    [string]$TaskBaseSha = '1111111111111111111111111111111111111111',
    [string]$FinalTreeSha = '2222222222222222222222222222222222222222'
  )

  $taskUnit = if ($AdapterKind -ceq 'migration-unit') { 'UNIT-ADMIN-LOCK' } else { $WorkItemId }
  $externalId = if ($AdapterKind -ceq 'migration-unit') { 'UNIT-ADMIN-LOCK' } elseif ($AdapterKind -ceq 'task') { 'TASK-ADMIN-LOCK' } else { 'not-applicable' }
  $authority = if ($AdapterKind -ceq 'migration-unit') { '08-migration-plan.md' } elseif ($AdapterKind -ceq 'task') { 'jira:ADMIN-LOCK' } else { 'not-applicable' }
  $authorityRevision = if ($AdapterKind -ceq 'none') { 'not-applicable' } else { '1' }
  $selectorApproval = if ($AdapterKind -ceq 'migration-unit') { 'approval:UNIT-ADMIN-LOCK' } elseif ($AdapterKind -ceq 'task') { 'approval:TASK-ADMIN-LOCK' } else { 'not-applicable' }
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $implementationTemplatePath
  $replacements = [ordered]@{
    'step_id: <orchestrator-provided>' = 'step_id: 10-code-migration'
    'status: draft' = 'status: approved'
    'result: complete' = "result: complete`napproval_source: human"
    'produced_at: <yyyy-mm-dd>' = 'produced_at: 2026-08-20'
    '| <master-spec.md> | <SPEC-*> | <revision> | <master-plan.md> | <PLAN-*> | <revision> | <WORK-*> | <approval:TECH-LEAD-*> |' = "| master-spec.md | SPEC-HANDOFF-001 | 1 | master-plan.md | PLAN-HANDOFF-001 | 1 | $WorkItemId | approval:WORK-ADMIN-LOCK |"
    '| <WORK-*> | <path> | <new, existing, or deleted> | <canonical region or symbol identifiers> | <path-scoped command or none> | <none or confirmed:MAJOR-*> | <checkpoint SHAs, deletion evidence, or none> | <sha> | <sha> |' = "| $taskUnit | src/admin_lock.source | existing | lockAdmin | none | none | source:$TaskBaseSha`:src/admin_lock.source; diff:$TaskBaseSha..$FinalTreeSha`:src/admin_lock.source | $TaskBaseSha | $FinalTreeSha |"
  }
  foreach ($token in $replacements.Keys) {
    $updated = $text.Replace($token, $replacements[$token])
    if ($updated -ceq $text) { throw "Migration implementation producer template is missing seam token: $token" }
    $text = $updated
  }
  $selectorSection = Get-ArtifactSectionBlock -Text $text -Heading 'Canonical Adapter Evidence'
  $selectorRow = "| $WorkItemId | $AdapterKind | $externalId | $authority | $authorityRevision | $selectorApproval | not-applicable | REQ-001; SC-001; completes within 2 seconds | REQ-001 | $ModeConstraint | DESIGN-ADMIN@2 | not-applicable | not-applicable | PASS |"
  $renderedSelectorSection = [regex]::Replace($selectorSection, '(?m)^\| <WORK-\*> \| <migration-unit, task.*$', $selectorRow, 1)
  if ($renderedSelectorSection -ceq $selectorSection) { throw 'Migration implementation producer template is missing canonical-selector row seam' }
  $text = $text.Replace($selectorSection, $renderedSelectorSection)
  if ($AdapterKind -ceq 'migration-unit') {
    $selectedRow = "| UNIT-ADMIN-LOCK | 08-migration-plan.md@1 | approval:UNIT-ADMIN-LOCK | $ModeConstraint | $BootstrapScope | $FoundationBaselineId | $FoundationBaselineReference | $FoundationBaselineApprovalReference | $BaselineReference | $SelectedTraceIds |"
    $selectedSection = Get-ArtifactSectionBlock -Text $text -Heading 'Selected Migration Unit'
    $renderedSelectedSection = [regex]::Replace($selectedSection, '(?m)^\| <UNIT-001> \|.*$', $selectedRow, 1)
    if ($renderedSelectedSection -ceq $selectedSection) { throw 'Migration implementation producer template is missing selected-unit row seam' }
    $text = $text.Replace($selectedSection, $renderedSelectedSection)
  }
  else {
    $withoutSelectedUnit = [regex]::Replace(
      $text,
      '(?ms)^## Selected Migration Unit\s*.*?(?=^## File .*$)',
      ''
    )
    if ($withoutSelectedUnit -ceq $text) { throw 'Migration implementation producer template is missing the conditional selected-unit section' }
    $text = $withoutSelectedUnit
  }
  return $text
}

function New-ProducerReviewArtifact {
  param([string]$WorkItemId = 'WORK-ADMIN-LOCK', [string]$TaskUnit = 'UNIT-ADMIN-LOCK')

  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $reviewTemplatePath
  $replacements = [ordered]@{
    'status: <draft | approved>' = 'status: approved'
    'result: <complete | blocked>' = 'result: complete'
    'approval_source: <human | auto | auto-waive>' = 'approval_source: human'
    'produced_at: <yyyy-mm-dd>' = 'produced_at: 2026-08-20'
    '| <RUN-*> | <master spec reference> | <SPEC-*> | <revision> | <master plan reference> | <PLAN-*> | <revision> | <WORK-*> |' = "| RUN-HANDOFF-001 | master-spec.md | SPEC-HANDOFF-001 | 1 | master-plan.md | PLAN-HANDOFF-001 | 1 | $WorkItemId |"
    '- Delivery Adapter Kind: <migration-unit | task | story | package | phase | milestone | none>' = '- Delivery Adapter Kind: migration-unit'
    '- Delivery Adapter Mode Constraint: <incremental/preserve-existing | greenfield/design-new>' = '- Delivery Adapter Mode Constraint: incremental/preserve-existing'
    '| <UNIT-* for migration-unit; WORK-* otherwise> | <task-base SHA> | <final-tree SHA> | <immediate predecessor artifact path> |' = "| $TaskUnit | 1111111111111111111111111111111111111111 | 2222222222222222222222222222222222222222 | implementation-report.md |"
    '| 1 | <tree verdict> | <responsibility verdict> | <verification verdict> | <derived architecture state> | source-diff:<task-base SHA>..<final-tree SHA>#<WORK-*> |' = "| 1 | PASS | PASS | PASS | PASS | source-diff:1111111111111111111111111111111111111111..2222222222222222222222222222222222222222#$WorkItemId |"
    '- Rule Resolution Verdict: <RESOLVED | BLOCKED>' = '- Rule Resolution Verdict: RESOLVED'
    '- Canonical Selector Verdict: <PASS | BLOCKED>' = '- Canonical Selector Verdict: PASS'
    '- Architecture Conformance Verdict: <PASS | BLOCKED>' = '- Architecture Conformance Verdict: PASS'
    '- Tree Conformance Verdict: <PASS | BLOCKED>' = '- Tree Conformance Verdict: PASS'
    '- Responsibility Conformance Verdict: <PASS | BLOCKED>' = '- Responsibility Conformance Verdict: PASS'
    '- Verification Ownership Verdict: <PASS | BLOCKED>' = '- Verification Ownership Verdict: PASS'
    '- Production Activation-path Verdict: <PASS | BLOCKED | NOT_APPLICABLE>' = '- Production Activation-path Verdict: NOT_APPLICABLE'
    '- Behavior Analysis State: <NOT_RUN | COMPLETE>' = '- Behavior Analysis State: COMPLETE'
    '- Change Hygiene Verdict: <PASS | BLOCKED>' = '- Change Hygiene Verdict: PASS'
    '- Verdict: <Approve | Approve-with-fixes | Reject>' = '- Verdict: Approve'
  }
  foreach ($token in $replacements.Keys) {
    $updated = $text.Replace($token, $replacements[$token])
    if ($updated -ceq $text) { throw "Migration review producer template is missing seam token: $token" }
    $text = $updated
  }
  $renderedCriticalCount = [regex]::Replace($text, '(?m)^- \*\*Critical count:\*\*[^\r\n]*\r?$', '- **Critical count:** 0', 1)
  if ($renderedCriticalCount -ceq $text) { throw 'Migration review producer template is missing Critical count seam' }
  $text = $renderedCriticalCount
  $renderedMajorCount = [regex]::Replace($text, '(?m)^- \*\*Major count:\*\*[^\r\n]*\r?$', '- **Major count:** 0', 1)
  if ($renderedMajorCount -ceq $text) { throw 'Migration review producer template is missing Major count seam' }
  $text = $renderedMajorCount
  $renderedSelectedUnit = [regex]::Replace($text, '(?m)^\| <UNIT-001> \|.*$', '| UNIT-ADMIN-LOCK | 08-migration-plan.md@1 | approval:UNIT-ADMIN-LOCK | incremental/preserve-existing | not-required | not-applicable | not-applicable | not-applicable | baseline.md#BASE-ADMIN | REQ-001 |', 1)
  if ($renderedSelectedUnit -ceq $text) { throw 'Migration review producer template is missing selected-unit row seam' }
  $text = $renderedSelectedUnit
  return $text
}

function New-ProducerKnowledgeBaseArtifact {
  param(
    [ValidateSet('migration-unit','task','none')][string]$AdapterKind = 'migration-unit',
    [string]$WorkItemId = 'WORK-ADMIN-LOCK',
    [string]$SourceArtifact = '14-regression-report.md',
    [string]$TaskBaseSha = '1111111111111111111111111111111111111111',
    [string]$FinalTreeSha = '2222222222222222222222222222222222222222',
    [string]$ModeConstraint = 'incremental/preserve-existing',
    [string]$BootstrapScope = 'not-required',
    [string]$FoundationBaselineId = 'not-applicable',
    [string]$FoundationBaselineReference = 'not-applicable',
    [string]$FoundationBaselineApprovalReference = 'not-applicable',
    [string]$BaselineReference = 'baseline.md#BASE-ADMIN',
    [string]$SelectedTraceIds = 'REQ-001'
  )

  $taskUnit = if ($AdapterKind -ceq 'migration-unit') { 'UNIT-ADMIN-LOCK' } else { $WorkItemId }
  $terminalMode = if ($SourceArtifact -ceq '13-parity-report.md') { 'greenfield' } else { 'incremental' }
  $terminalUnit = if ($AdapterKind -ceq 'migration-unit') { 'UNIT-ADMIN-LOCK' } else { 'not-applicable' }
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $knowledgeBaseTemplatePath
  $replacements = [ordered]@{
    'step_id: <orchestrator-provided-step-id>' = 'step_id: 15-knowledge-base'
    'status: draft' = 'status: approved'
    'result: <complete | partial | blocked>' = 'result: complete'
    'produced_at: <yyyy-mm-dd>' = 'produced_at: 2026-08-20'
    'approval_source: <human | auto | auto-waive>' = 'approval_source: human'
    '| <RUN-*> | <master spec reference> | <SPEC-*> | <revision> | <master plan reference> | <PLAN-*> | <revision> | <WORK-*> |' = "| RUN-HANDOFF-001 | master-spec.md | SPEC-HANDOFF-001 | 1 | master-plan.md | PLAN-HANDOFF-001 | 1 | $WorkItemId |"
    '- Delivery Adapter Kind: <migration-unit | task | story | package | phase | milestone | none>' = "- Delivery Adapter Kind: $AdapterKind"
    '- Delivery Adapter Mode Constraint: <incremental/preserve-existing | greenfield/design-new>' = "- Delivery Adapter Mode Constraint: $ModeConstraint"
    '| <task or UNIT-###> | <sha> | <sha> | <terminal verification artifact> |' = "| $taskUnit | $TaskBaseSha | $FinalTreeSha | $SourceArtifact |"
    '| 1 | PASS | PASS | PASS | PASS | source-diff:<task-base SHA>..<final-tree SHA>#<WORK-*> |' = "| 1 | PASS | PASS | PASS | PASS | source-diff:$TaskBaseSha..$FinalTreeSha#$WorkItemId |"
    '- Workflow Type: <orchestrator-provided-workflow-type>' = '- Workflow Type: migration'
  }
  foreach ($token in $replacements.Keys) {
    $updated = $text.Replace($token, $replacements[$token])
    if ($updated -cne $text) { $text = $updated }
  }
  $text = [regex]::Replace($text, '(?m)^- Terminal Input Artifact: <[^\r\n]+>\r?$', "- Terminal Input Artifact: $SourceArtifact")
  $text = [regex]::Replace($text, '(?m)^- Completion Verdict: <complete / partial / blocked,[^\r\n]+>\r?$', '- Completion Verdict: complete')
  $text = [regex]::Replace($text, '(?m)^\| <orchestrator-provided-workflow-type> \| <greenfield / incremental / not-applicable> \|.*$', "| migration | $terminalMode | $terminalUnit | $SourceArtifact | PASS | complete |")
  if ($AdapterKind -ceq 'migration-unit') {
    $selectedRow = "| UNIT-ADMIN-LOCK | 08-migration-plan.md@1 | approval:UNIT-ADMIN-LOCK | $ModeConstraint | $BootstrapScope | $FoundationBaselineId | $FoundationBaselineReference | $FoundationBaselineApprovalReference | $BaselineReference | $SelectedTraceIds |"
    $selected = [regex]::Replace($text, '(?m)^\| <UNIT-001> \|.*$', $selectedRow, 1)
    if ($selected -cne $text) { $text = $selected }
  }
  else {
    $withoutSelectedUnit = [regex]::Replace(
      $text,
      '(?ms)^## Selected Migration Unit\s*.*?(?=^## Architecture Responsibility Handoff\s*$)',
      ''
    )
    if ($withoutSelectedUnit -ceq $text) { throw 'Knowledge Base producer template is missing the conditional selected-unit section' }
    $text = $withoutSelectedUnit
  }
  return $text
}

function New-GerritArtifact {
  param(
    [Parameter(Mandatory)][string]$KnowledgeBaseText,
    [ValidateSet('migration-unit','task','none')][string]$AdapterKind = 'migration-unit',
    [string]$WorkItemId = 'WORK-ADMIN-LOCK',
    [string]$TerminalEvidence = 'evidence:command-output-pass'
  )

  $scopeSection = Get-ArtifactSectionBlock -Text $KnowledgeBaseText -Heading 'Master Scope Context'
  $provenanceSection = Get-ArtifactSectionBlock -Text $KnowledgeBaseText -Heading 'Task Provenance'
  $handoffSection = Get-ArtifactSectionBlock -Text $KnowledgeBaseText -Heading 'Architecture Responsibility Handoff'
  $selectedSection = if ($AdapterKind -ceq 'migration-unit') { Get-ArtifactSectionBlock -Text $KnowledgeBaseText -Heading 'Selected Migration Unit' } else { '' }
  $renderErrors = [Collections.Generic.List[string]]::new()
  $provenanceTable = @(Get-ArcStrictMarkdownTable -Text $KnowledgeBaseText -Heading 'Task Provenance' -Columns @('Task / Unit', 'Task-base SHA', 'Final-tree SHA', 'Source Artifact') -Errors $renderErrors)
  if ($renderErrors.Count -ne 0 -or $provenanceTable.Count -ne 3) { throw "Gerrit producer cannot resolve exact Knowledge Base Task Provenance: $($renderErrors -join '; ')" }
  $taskUnit = [string]$provenanceTable[2][0]
  $taskBaseSha = [string]$provenanceTable[2][1]
  $finalTreeSha = [string]$provenanceTable[2][2]
  $terminalErrors = [Collections.Generic.List[string]]::new()
  $terminalColumns = @('Workflow Type', 'Mode', 'Migration Unit ID', 'Terminal Verification Artifact', 'Verification Verdict', 'Completion Verdict')
  $terminalTable = @(Get-ArcStrictMarkdownTable -Text $KnowledgeBaseText -Heading $terminalVerificationHeading -Columns $terminalColumns -Errors $terminalErrors)
  if ($terminalErrors.Count -ne 0 -or $terminalTable.Count -ne 3) { throw "Gerrit producer cannot resolve exact Knowledge Base terminal verdict: $($terminalErrors -join '; ')" }
  $terminalMode = [string]$terminalTable[2][1]
  $migrationVerdictRow = if ($terminalMode -ceq 'greenfield') {
    "| pass | not-applicable | not-applicable | $TerminalEvidence |"
  }
  else {
    "| pass | required | pass | $TerminalEvidence |"
  }
  $text = $gerritTemplate
  foreach ($replacement in @(
    [pscustomobject]@{ From = 'result: <complete | partial | blocked>'; To = 'result: complete' },
    [pscustomobject]@{ From = 'produced_at: <yyyy-mm-dd>'; To = 'produced_at: 2026-08-20' },
    [pscustomobject]@{ From = (Get-ArtifactSectionBlock -Text $gerritTemplate -Heading 'Master Scope Context'); To = $scopeSection },
    [pscustomobject]@{ From = (Get-ArtifactSectionBlock -Text $gerritTemplate -Heading 'Task Provenance'); To = $provenanceSection },
    [pscustomobject]@{ From = (Get-ArtifactSectionBlock -Text $gerritTemplate -Heading 'Architecture Responsibility Handoff'); To = $handoffSection },
    [pscustomobject]@{ From = '| <pass, fail, or blocked> | <required or not-applicable> | <pass, fail, blocked, or not-applicable> | <immediate predecessor evidence> |'; To = $migrationVerdictRow },
    [pscustomobject]@{ From = '| <sha> | <resolved ref or not-applicable> | <sha or not-applicable> | <sha or not-applicable> | <sha> | <observed integer> | <task or UNIT-###> | <PASS or BLOCKED> | <commands or none> | <commands, output, exits, upstream SHA, evidence> |'; To = "| $taskBaseSha | not-applicable | not-applicable | not-applicable | $finalTreeSha | 1 | $taskUnit | PASS | none | tests:PASS |" }
  )) {
    $updated = $text.Replace([string]$replacement.From, [string]$replacement.To)
    if ($updated -ceq $text) { throw "Gerrit producer template is missing a required render seam: $($replacement.From)" }
    $text = $updated
  }
  $templateSelectedSection = Get-ArtifactSectionBlock -Text $gerritTemplate -Heading 'Selected Migration Unit'
  $text = if ($AdapterKind -ceq 'migration-unit') {
    $text.Replace($templateSelectedSection, $selectedSection)
  }
  else {
    $text.Replace($templateSelectedSection, '')
  }
  return $text
}

function Get-ArtifactSectionBlock {
  param([Parameter(Mandatory)][string]$Text, [Parameter(Mandatory)][string]$Heading)

  $match = [regex]::Match($Text, '(?ms)^## ' + [regex]::Escape($Heading) + '\s*$.*?(?=^## |\z)')
  if (-not $match.Success) { throw "Artifact section is missing: $Heading" }
  return $match.Value
}

function Convert-ArtifactLineEndings {
  param(
    [Parameter(Mandatory)][string]$Text,
    [Parameter(Mandatory)][ValidateSet('LF', 'CRLF')][string]$Style
  )

  $normalized = $Text.Replace("`r`n", "`n").Replace("`r", "`n")
  if ($Style -ceq 'LF') { return $normalized }
  return $normalized.Replace("`n", "`r`n")
}

function Move-ArtifactSectionBeforeHeading {
  param(
    [Parameter(Mandatory)][string]$Text,
    [Parameter(Mandatory)][string]$SectionHeading,
    [Parameter(Mandatory)][string]$BeforeHeading
  )

  $section = Get-ArtifactSectionBlock -Text $Text -Heading $SectionHeading
  $withoutSection = $Text.Replace($section, '')
  if ($withoutSection -ceq $Text) { throw "Artifact section move was a silent no-op: $SectionHeading" }
  $target = [regex]::Match($withoutSection, '(?m)^## ' + [regex]::Escape($BeforeHeading) + '\s*$')
  if (-not $target.Success) { throw "Artifact section move target is missing: $BeforeHeading" }
  return $withoutSection.Insert($target.Index, $section)
}

function Assert-HandoffAccepted {
  param([string]$Name, [string]$SourceText, [string]$TargetText, [string]$ApprovedPlanText = $script:migrationPlan)
  $diagnostics = @(Test-ResponsibilityHandoff -SourceText $SourceText -TargetText $TargetText -ContractText $contract -ApprovedPlanText $ApprovedPlanText)
  if ($diagnostics.Count -ne 0) {
    throw "$Name should pass but got: $($diagnostics -join '; ')"
  }
  Write-Output "PASS: $Name"
}

function Assert-HandoffRejected {
  param([string]$Name, [string]$SourceText, [string]$TargetText, [string]$ExpectedDiagnostic, [string]$ApprovedPlanText = $script:migrationPlan)
  $diagnostics = @(Test-ResponsibilityHandoff -SourceText $SourceText -TargetText $TargetText -ContractText $contract -ApprovedPlanText $ApprovedPlanText)
  if ($diagnostics -notcontains $ExpectedDiagnostic) {
    throw "$Name expected $ExpectedDiagnostic but got: $($diagnostics -join '; ')"
  }
  Write-Output "PASS: $Name"
}

function Assert-GerritAccepted {
  param(
    [string]$Name, [string]$KnowledgeBaseText, [string]$GerritText,
    [string]$ImplementationText = $script:gerritImplementation,
    [string]$ReviewText = $script:gerritReview,
    [string]$VerificationText = $script:gerritVerification,
    [string]$ParityText = $script:gerritParity,
    [string]$RegressionText = $script:gerritRegression,
    [string]$ApprovedPlanText = $script:migrationPlan
  )
  $diagnostics = @(Test-ResponsibilityGerrit -KnowledgeBaseText $KnowledgeBaseText -GerritText $GerritText -ContractText $contract -ApprovedPlanText $ApprovedPlanText -ImplementationText $ImplementationText -ReviewText $ReviewText -VerificationText $VerificationText -ParityText $ParityText -RegressionText $RegressionText)
  if ($diagnostics.Count -ne 0) { throw "$Name should pass but got: $($diagnostics -join '; ')" }
  Write-Output "PASS: $Name"
}

function Assert-GerritRejected {
  param(
    [string]$Name, [string]$KnowledgeBaseText, [string]$GerritText,
    [string]$ExpectedDiagnostic = 'responsibility-evidence-missing',
    [string]$ImplementationText = $script:gerritImplementation,
    [string]$ReviewText = $script:gerritReview,
    [string]$VerificationText = $script:gerritVerification,
    [string]$ParityText = $script:gerritParity,
    [string]$RegressionText = $script:gerritRegression,
    [string]$ApprovedPlanText = $script:migrationPlan
  )
  $diagnostics = @(Test-ResponsibilityGerrit -KnowledgeBaseText $KnowledgeBaseText -GerritText $GerritText -ContractText $contract -ApprovedPlanText $ApprovedPlanText -ImplementationText $ImplementationText -ReviewText $ReviewText -VerificationText $VerificationText -ParityText $ParityText -RegressionText $RegressionText)
  if ($diagnostics -notcontains $ExpectedDiagnostic) { throw "$Name expected $ExpectedDiagnostic but got: $($diagnostics -join '; ')" }
  Write-Output "PASS: $Name"
}

function Assert-GerritDiagnosticsExactly {
  param(
    [string]$Name, [string]$KnowledgeBaseText, [string]$GerritText, [string[]]$ExpectedDiagnostics,
    [string]$ImplementationText = $script:gerritImplementation,
    [string]$ReviewText = $script:gerritReview,
    [string]$VerificationText = $script:gerritVerification,
    [string]$ParityText = $script:gerritParity,
    [string]$RegressionText = $script:gerritRegression,
    [string]$ApprovedPlanText = $script:migrationPlan
  )
  $actual = @(Test-ResponsibilityGerrit -KnowledgeBaseText $KnowledgeBaseText -GerritText $GerritText -ContractText $contract -ApprovedPlanText $ApprovedPlanText -ImplementationText $ImplementationText -ReviewText $ReviewText -VerificationText $VerificationText -ParityText $ParityText -RegressionText $RegressionText | Sort-Object -Unique)
  $expected = @($ExpectedDiagnostics | Sort-Object -Unique)
  if (($actual -join '|') -cne ($expected -join '|')) {
    throw "$Name expected exactly [$($expected -join '; ')] but got: [$($actual -join '; ')]"
  }
  Write-Output "PASS: $Name"
}

function Assert-HandoffDiagnosticsExactly {
  param([string]$Name, [string]$SourceText, [string]$TargetText, [string[]]$ExpectedDiagnostics, [string]$ApprovedPlanText = $script:migrationPlan)
  $diagnostics = @(Test-ResponsibilityHandoff -SourceText $SourceText -TargetText $TargetText -ContractText $contract -ApprovedPlanText $ApprovedPlanText)
  if ($diagnostics.Count -ne $ExpectedDiagnostics.Count) {
    throw "$Name expected exactly $($ExpectedDiagnostics.Count) diagnostic(s) [$($ExpectedDiagnostics -join '; ')] but got $($diagnostics.Count) [$($diagnostics -join '; ')]"
  }
  for ($index = 0; $index -lt $ExpectedDiagnostics.Count; $index++) {
    if ($diagnostics[$index] -cne $ExpectedDiagnostics[$index]) {
      throw "$Name diagnostic $index expected exact <$($ExpectedDiagnostics[$index])> but got <$($diagnostics[$index])>; full list: $($diagnostics -join '; ')"
    }
  }
  Write-Output "PASS: $Name"
}

$script:migrationPlan = New-ApprovedAdapterPlan
$genericPlan = New-ApprovedAdapterPlan -AdapterKind task -SelectorApproval 'approval:TASK-ADMIN-LOCK'
$noneSelectorGenericPlan = $genericPlan.Replace(
  '| WORK-ADMIN-LOCK | task | TASK-ADMIN-LOCK | jira:ADMIN-LOCK | 1 | approval:TASK-ADMIN-LOCK | not-applicable | REQ-001; SC-001; completes within 2 seconds | REQ-001 | incremental/preserve-existing | DESIGN-ADMIN@2 | not-applicable | not-applicable |',
  '| WORK-ADMIN-LOCK | none | not-applicable | not-applicable | not-applicable | not-applicable | not-applicable | REQ-001; SC-001; completes within 2 seconds | REQ-001 | incremental/preserve-existing | DESIGN-ADMIN@2 | not-applicable | not-applicable |'
).Replace('task:TASK-ADMIN-LOCK', 'generic:module-foundation')
if ($noneSelectorGenericPlan -ceq $genericPlan) { throw 'none-selector generic adapter fixture mutation was a silent no-op' }
$producerImplementation = New-ProducerImplementationArtifact
$producerGenericImplementation = New-ProducerImplementationArtifact -AdapterKind task
$producerNoneImplementation = New-ProducerImplementationArtifact -AdapterKind none
$review = New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md'
$producerReview = New-ProducerReviewArtifact
$verification = New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md'
$producerVerification = New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md' -Evidence 'source-diff:1111111111111111111111111111111111111111..2222222222222222222222222222222222222222#WORK-ADMIN-LOCK' -TaskBaseSha '1111111111111111111111111111111111111111' -FinalTreeSha '2222222222222222222222222222222222222222'
$parity = New-HandoffArtifact -StepId '13-verify-parity' -SourceArtifact 'verification-report.md'
$regression = New-HandoffArtifact -StepId '14-verify-regression' -SourceArtifact '13-parity-report.md'
$knowledgeBase = New-HandoffArtifact -StepId '15-knowledge-base' -SourceArtifact '14-regression-report.md'
$producerKnowledgeBase = New-ProducerKnowledgeBaseArtifact
$producerGenericKnowledgeBase = New-ProducerKnowledgeBaseArtifact -AdapterKind task -SourceArtifact '14-regression-report.md'
$producerNoneKnowledgeBase = New-ProducerKnowledgeBaseArtifact -AdapterKind none -SourceArtifact '14-regression-report.md'
$script:gerritImplementation = $producerImplementation
$script:gerritReview = $producerReview
$script:gerritVerification = $producerVerification
$script:gerritParity = $parity
$script:gerritRegression = $regression

Assert-HandoffRejected 'migration-unit assurance provenance cannot use Work Item identity' (New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -TaskUnit 'WORK-ADMIN-LOCK') (New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md' -TaskUnit 'WORK-ADMIN-LOCK') 'responsibility-evidence-missing'
$unitReview = New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -TaskUnit 'UNIT-ADMIN-LOCK'
$unitVerification = New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md' -TaskUnit 'UNIT-ADMIN-LOCK'
Assert-HandoffAccepted 'migration-unit assurance provenance binds the approved selected unit identity' $unitReview $unitVerification

foreach ($handoff in @(
  [pscustomobject]@{ Name = 'review to verification'; Source = $review; Target = $verification }
  [pscustomobject]@{ Name = 'verification to parity'; Source = $verification; Target = $parity }
  [pscustomobject]@{ Name = 'parity to regression'; Source = $parity; Target = $regression }
  [pscustomobject]@{ Name = 'regression to knowledge base'; Source = $regression; Target = $knowledgeBase }
)) {
  Assert-HandoffAccepted "preserves exact responsibility handoff from $($handoff.Name)" $handoff.Source $handoff.Target
}

Assert-HandoffAccepted 'producer-rendered migration review starts the responsibility handoff chain' $producerReview $producerVerification
Assert-HandoffAccepted 'producer-rendered terminal Knowledge Base preserves the regression handoff envelope' $regression $producerKnowledgeBase
foreach ($frontMatterDecoy in @(
  [pscustomobject]@{ Label = 'Delivery Adapter Kind'; Value = 'migration-unit'; Indent = 2 },
  [pscustomobject]@{ Label = 'Delivery Adapter Kind'; Value = 'migration-unit'; Indent = 3 },
  [pscustomobject]@{ Label = 'Delivery Adapter Mode Constraint'; Value = 'incremental/preserve-existing'; Indent = 2 },
  [pscustomobject]@{ Label = 'Delivery Adapter Mode Constraint'; Value = 'incremental/preserve-existing'; Indent = 3 }
)) {
  $bodyLine = "- $($frontMatterDecoy.Label): $($frontMatterDecoy.Value)"
  $reviewWithoutBodyControl = $review.Replace($bodyLine, '')
  if ($reviewWithoutBodyControl -ceq $review) { throw "Front-matter decoy body removal was a silent no-op: $($frontMatterDecoy.Label)" }
  $indent = [string]::new([char]' ', $frontMatterDecoy.Indent)
  $reviewWithFrontMatterDecoy = $reviewWithoutBodyControl.Replace('responsibility_contract:', "$indent- $($frontMatterDecoy.Label): $($frontMatterDecoy.Value)`nresponsibility_contract:")
  if ($reviewWithFrontMatterDecoy -ceq $reviewWithoutBodyControl) { throw "Front-matter decoy insertion was a silent no-op: $($frontMatterDecoy.Label)" }
  Assert-HandoffRejected "review-to-verification rejects a $($frontMatterDecoy.Indent)-space front-matter $($frontMatterDecoy.Label) decoy" $reviewWithFrontMatterDecoy $verification 'responsibility-evidence-missing'
}
$producerGenericParity = New-HandoffArtifact -StepId '13-verify-parity' -SourceArtifact 'verification-report.md' -AdapterKind task
$producerNoneParity = New-HandoffArtifact -StepId '13-verify-parity' -SourceArtifact 'verification-report.md' -AdapterKind none
$producerGenericRegression = New-HandoffArtifact -StepId '14-verify-regression' -SourceArtifact '13-parity-report.md' -AdapterKind task
$producerNoneRegression = New-HandoffArtifact -StepId '14-verify-regression' -SourceArtifact '13-parity-report.md' -AdapterKind none
Assert-HandoffAccepted 'producer-rendered incremental generic terminal Knowledge Base follows regression and omits the selected migration unit' $producerGenericRegression $producerGenericKnowledgeBase $genericPlan
Assert-HandoffAccepted 'producer-rendered incremental none terminal Knowledge Base follows regression and omits the selected migration unit' $producerNoneRegression $producerNoneKnowledgeBase $noneSelectorGenericPlan

$migrationUnitGerrit = New-GerritArtifact -KnowledgeBaseText $producerKnowledgeBase -AdapterKind migration-unit
$genericGerrit = New-GerritArtifact -KnowledgeBaseText $producerGenericKnowledgeBase -AdapterKind task
$noneGerrit = New-GerritArtifact -KnowledgeBaseText $producerNoneKnowledgeBase -AdapterKind none
Assert-GerritAccepted 'review-to-KB-to-Gerrit preserves one selected unit for migration-unit' $producerKnowledgeBase $migrationUnitGerrit
$genericReview = New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -AdapterKind task
$genericVerification = New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md' -AdapterKind task
$genericParity = New-HandoffArtifact -StepId '13-verify-parity' -SourceArtifact 'verification-report.md' -AdapterKind task
$genericRegression = New-HandoffArtifact -StepId '14-verify-regression' -SourceArtifact '13-parity-report.md' -AdapterKind task
$noneReview = New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -AdapterKind none
$noneVerification = New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md' -AdapterKind none
$noneParity = New-HandoffArtifact -StepId '13-verify-parity' -SourceArtifact 'verification-report.md' -AdapterKind none
$noneRegression = New-HandoffArtifact -StepId '14-verify-regression' -SourceArtifact '13-parity-report.md' -AdapterKind none
Assert-GerritAccepted -Name 'review-to-KB-to-Gerrit omits Selected Migration Unit for generic task' -KnowledgeBaseText $producerGenericKnowledgeBase -GerritText $genericGerrit -ImplementationText $producerGenericImplementation -ReviewText $genericReview -VerificationText $genericVerification -ParityText $genericParity -RegressionText $genericRegression -ApprovedPlanText $genericPlan
Assert-GerritAccepted -Name 'review-to-KB-to-Gerrit omits Selected Migration Unit for none adapter' -KnowledgeBaseText $producerNoneKnowledgeBase -GerritText $noneGerrit -ImplementationText $producerNoneImplementation -ReviewText $noneReview -VerificationText $noneVerification -ParityText $noneParity -RegressionText $noneRegression -ApprovedPlanText $noneSelectorGenericPlan

$greenfieldGenericPlan = New-ApprovedAdapterPlan -AdapterKind task -SelectorApproval 'approval:TASK-ADMIN-LOCK' -SelectorMode 'greenfield/design-new'
$greenfieldReview = New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -AdapterKind task -ModeConstraint 'greenfield/design-new'
$greenfieldVerification = New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md' -AdapterKind task -ModeConstraint 'greenfield/design-new'
$greenfieldParity = New-HandoffArtifact -StepId '13-verify-parity' -SourceArtifact 'verification-report.md' -AdapterKind task -ModeConstraint 'greenfield/design-new'
$greenfieldKnowledgeBase = New-ProducerKnowledgeBaseArtifact -AdapterKind task -SourceArtifact '13-parity-report.md' -ModeConstraint 'greenfield/design-new'
$greenfieldGerrit = New-GerritArtifact -KnowledgeBaseText $greenfieldKnowledgeBase -AdapterKind task
$greenfieldGenericImplementation = New-ProducerImplementationArtifact -AdapterKind task -ModeConstraint 'greenfield/design-new'
Assert-GerritAccepted -Name 'greenfield implementation-to-review-to-parity-to-KB-to-Gerrit omits regression and Selected Migration Unit for generic task' -KnowledgeBaseText $greenfieldKnowledgeBase -GerritText $greenfieldGerrit -ImplementationText $greenfieldGenericImplementation -ReviewText $greenfieldReview -VerificationText $greenfieldVerification -ParityText $greenfieldParity -RegressionText '' -ApprovedPlanText $greenfieldGenericPlan

$greenfieldMigrationPlan = New-ApprovedAdapterPlan `
  -SelectorMode 'greenfield/design-new' `
  -BootstrapScope 'required' `
  -FoundationBaselineId 'FOUNDATION-ADMIN' `
  -FoundationBaselineReference 'foundation-admin.md#BASE-ADMIN' `
  -FoundationBaselineApprovalReference 'approval:FOUNDATION-ADMIN' `
  -BaselineReference 'not-applicable'
$greenfieldUnitArguments = @{
  ModeConstraint = 'greenfield/design-new'
  BootstrapScope = 'required'
  FoundationBaselineId = 'FOUNDATION-ADMIN'
  FoundationBaselineReference = 'foundation-admin.md#BASE-ADMIN'
  FoundationBaselineApprovalReference = 'approval:FOUNDATION-ADMIN'
  BaselineReference = 'not-applicable'
}
$greenfieldUnitReview = New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' @greenfieldUnitArguments
$greenfieldUnitVerification = New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md' @greenfieldUnitArguments
$greenfieldUnitParity = New-HandoffArtifact -StepId '13-verify-parity' -SourceArtifact 'verification-report.md' @greenfieldUnitArguments
$greenfieldUnitKnowledgeBase = New-ProducerKnowledgeBaseArtifact -SourceArtifact '13-parity-report.md' @greenfieldUnitArguments
$greenfieldUnitGerrit = New-GerritArtifact -KnowledgeBaseText $greenfieldUnitKnowledgeBase -AdapterKind migration-unit
$greenfieldUnitImplementation = New-ProducerImplementationArtifact @greenfieldUnitArguments
Assert-GerritAccepted -Name 'greenfield migration-unit implementation-to-review-to-parity-to-KB-to-Gerrit preserves approved unit authority' -KnowledgeBaseText $greenfieldUnitKnowledgeBase -GerritText $greenfieldUnitGerrit -ImplementationText $greenfieldUnitImplementation -ReviewText $greenfieldUnitReview -VerificationText $greenfieldUnitVerification -ParityText $greenfieldUnitParity -RegressionText '' -ApprovedPlanText $greenfieldMigrationPlan

$implementationSelectedBlock = Get-ArtifactSectionBlock -Text $producerImplementation -Heading 'Selected Migration Unit'
foreach ($implementationOriginMutation in @(
  [pscustomobject]@{ Name = 'missing implementation origin'; Text = '' },
  [pscustomobject]@{ Name = 'omitted selected-unit origin'; Text = $producerImplementation.Replace($implementationSelectedBlock, '') },
  [pscustomobject]@{ Name = 'duplicate selected-unit origin'; Text = $producerImplementation.Replace($implementationSelectedBlock, "$implementationSelectedBlock$implementationSelectedBlock") },
  [pscustomobject]@{ Name = 'wrong implementation step'; Text = $producerImplementation.Replace('step_id: 10-code-migration', 'step_id: 09-bootstrap-target') },
  [pscustomobject]@{ Name = 'draft implementation lifecycle'; Text = $producerImplementation.Replace('status: approved', 'status: draft') },
  [pscustomobject]@{ Name = 'blocked implementation lifecycle'; Text = $producerImplementation.Replace('result: complete', 'result: blocked') },
  [pscustomobject]@{ Name = 'non-human implementation approval'; Text = $producerImplementation.Replace('approval_source: human', 'approval_source: auto') },
  [pscustomobject]@{ Name = 'malformed implementation date'; Text = $producerImplementation.Replace('produced_at: 2026-08-20', 'produced_at: yesterday') },
  [pscustomobject]@{ Name = 'extra implementation lifecycle key'; Text = $producerImplementation.Replace('produced_at: 2026-08-20', "producer_claim: trusted`nproduced_at: 2026-08-20") },
  [pscustomobject]@{ Name = 'foreign implementation plan scope'; Text = $producerImplementation.Replace('| master-plan.md | PLAN-HANDOFF-001 | 1 | WORK-ADMIN-LOCK |', '| master-plan.md | PLAN-FOREIGN-001 | 1 | WORK-ADMIN-LOCK |') },
  [pscustomobject]@{ Name = 'foreign work-item approval origin'; Text = $producerImplementation.Replace('| WORK-ADMIN-LOCK | approval:WORK-ADMIN-LOCK |', '| WORK-ADMIN-LOCK | approval:WORK-FOREIGN-LOCK |') },
  [pscustomobject]@{ Name = 'stale canonical adapter revision'; Text = $producerImplementation.Replace('| 08-migration-plan.md | 1 | approval:UNIT-ADMIN-LOCK |', '| 08-migration-plan.md | 2 | approval:UNIT-ADMIN-LOCK |') },
  [pscustomobject]@{ Name = 'blocked canonical adapter match'; Text = $producerImplementation.Replace('| not-applicable | not-applicable | PASS |', '| not-applicable | not-applicable | BLOCKED |') },
  [pscustomobject]@{ Name = 'stale implementation selected-unit baseline'; Text = $producerImplementation.Replace('baseline.md#BASE-ADMIN', 'baseline-stale.md#BASE-STALE') },
  [pscustomobject]@{ Name = 'foreign implementation task identity'; Text = $producerImplementation.Replace('| UNIT-ADMIN-LOCK | src/admin_lock.source |', '| UNIT-FOREIGN-LOCK | src/admin_lock.source |') },
  [pscustomobject]@{ Name = 'stale implementation final-tree provenance'; Text = $producerImplementation.Replace('2222222222222222222222222222222222222222', '3333333333333333333333333333333333333333') }
)) {
  if ($implementationOriginMutation.Name -cne 'missing implementation origin' -and $implementationOriginMutation.Text -ceq $producerImplementation) {
    throw "Implementation-origin mutation was a silent no-op: $($implementationOriginMutation.Name)"
  }
  Assert-GerritDiagnosticsExactly -Name "public Gerrit gate rejects $($implementationOriginMutation.Name)" -KnowledgeBaseText $producerKnowledgeBase -GerritText $migrationUnitGerrit -ExpectedDiagnostics @('responsibility-evidence-missing') -ImplementationText $implementationOriginMutation.Text
}

$inventedGenericImplementationSelection = "$producerGenericImplementation`n$implementationSelectedBlock"
Assert-GerritDiagnosticsExactly -Name 'public Gerrit gate rejects a generic implementation origin that invents Selected Migration Unit' -KnowledgeBaseText $producerGenericKnowledgeBase -GerritText $genericGerrit -ExpectedDiagnostics @('responsibility-evidence-missing') -ImplementationText $inventedGenericImplementationSelection -ReviewText $genericReview -VerificationText $genericVerification -ParityText $genericParity -RegressionText $genericRegression -ApprovedPlanText $genericPlan
$inventedNoneImplementationSelection = "$producerNoneImplementation`n$implementationSelectedBlock"
Assert-GerritDiagnosticsExactly -Name 'public Gerrit gate rejects a none-adapter implementation origin that invents Selected Migration Unit' -KnowledgeBaseText $producerNoneKnowledgeBase -GerritText $noneGerrit -ExpectedDiagnostics @('responsibility-evidence-missing') -ImplementationText $inventedNoneImplementationSelection -ReviewText $noneReview -VerificationText $noneVerification -ParityText $noneParity -RegressionText $noneRegression -ApprovedPlanText $noneSelectorGenericPlan

$verificationVerdictBlock = Get-ArtifactSectionBlock -Text $producerVerification -Heading $conclusionHeading
foreach ($verificationVerdictMutation in @(
  [pscustomobject]@{ Name = 'missing'; Text = $producerVerification.Replace($verificationVerdictBlock, '') },
  [pscustomobject]@{ Name = 'duplicate'; Text = $producerVerification.Replace($verificationVerdictBlock, "$verificationVerdictBlock$verificationVerdictBlock") },
  [pscustomobject]@{ Name = 'malformed'; Text = $producerVerification.Replace("PASS $verdictSeparator evidence:command-output-pass", 'pass: evidence:command-output-pass') },
  [pscustomobject]@{ Name = 'FAIL'; Text = $producerVerification.Replace("PASS $verdictSeparator evidence:command-output-pass", "FAIL $verdictSeparator evidence:command-output-fail") },
  [pscustomobject]@{ Name = 'BLOCKED'; Text = $producerVerification.Replace("PASS $verdictSeparator evidence:command-output-pass", "BLOCKED $verdictSeparator evidence:native-blocker") },
  [pscustomobject]@{ Name = 'placeholder evidence'; Text = $producerVerification.Replace('evidence:command-output-pass', '<verification evidence>') }
)) {
  if ($verificationVerdictMutation.Text -ceq $producerVerification) { throw "Verification verdict mutation was a silent no-op: $($verificationVerdictMutation.Name)" }
  Assert-GerritDiagnosticsExactly -Name "public Gerrit gate rejects $($verificationVerdictMutation.Name) verification verdict" -KnowledgeBaseText $producerKnowledgeBase -GerritText $migrationUnitGerrit -ExpectedDiagnostics @('responsibility-evidence-missing') -VerificationText $verificationVerdictMutation.Text
}

$parityVerdictBlock = Get-ArtifactSectionBlock -Text $parity -Heading 'Parity Verdict'
foreach ($parityVerdictMutation in @(
  [pscustomobject]@{ Name = 'missing'; Text = $parity.Replace($parityVerdictBlock, '') },
  [pscustomobject]@{ Name = 'duplicate'; Text = $parity.Replace($parityVerdictBlock, "$parityVerdictBlock$parityVerdictBlock") },
  [pscustomobject]@{ Name = 'malformed'; Text = $parity.Replace('| pass | evidence:command-output-pass |', '| PASS | evidence:command-output-pass |') },
  [pscustomobject]@{ Name = 'fail'; Text = $parity.Replace('| pass | evidence:command-output-pass |', '| fail | evidence:command-output-fail |') },
  [pscustomobject]@{ Name = 'blocked'; Text = $parity.Replace('| pass | evidence:command-output-pass |', '| blocked | evidence:native-blocker |') },
  [pscustomobject]@{ Name = 'placeholder evidence'; Text = $parity.Replace('evidence:command-output-pass', '<parity evidence>') }
)) {
  if ($parityVerdictMutation.Text -ceq $parity) { throw "Parity verdict mutation was a silent no-op: $($parityVerdictMutation.Name)" }
  Assert-GerritDiagnosticsExactly -Name "public Gerrit gate rejects $($parityVerdictMutation.Name) parity verdict" -KnowledgeBaseText $producerKnowledgeBase -GerritText $migrationUnitGerrit -ExpectedDiagnostics @('responsibility-evidence-missing') -ParityText $parityVerdictMutation.Text
}

$parityScenarioBlock = Get-ArtifactSectionBlock -Text $parity -Heading $scenarioHeading
$parityScenarioRow = '| admin lock parity | legacy:locked | target:locked | pass |'
$parityFailRows = "$parityScenarioRow`n| admin unlock parity | legacy:unlocked | target:locked | fail |"
$parityBlockedRows = "$parityScenarioRow`n| admin unlock parity | legacy:unlocked | target:unknown | blocked |"
foreach ($parityScenarioMutation in @(
  [pscustomobject]@{ Name = 'missing scenario table'; Text = $parity.Replace($parityScenarioBlock, '') },
  [pscustomobject]@{ Name = 'duplicate scenario table'; Text = $parity.Replace($parityScenarioBlock, "$parityScenarioBlock$parityScenarioBlock") },
  [pscustomobject]@{ Name = 'malformed scenario columns'; Text = $parity.Replace('| Scenario | Baseline | Actual | Verdict |', '| Scenario | Actual | Baseline | Verdict |') },
  [pscustomobject]@{ Name = 'placeholder scenario evidence'; Text = $parity.Replace($parityScenarioRow, '| admin lock parity | <baseline> | target:locked | pass |') },
  [pscustomobject]@{ Name = 'derived fail from pass plus fail'; Text = $parity.Replace($parityScenarioRow, $parityFailRows).Replace('| pass | evidence:command-output-pass |', '| fail | evidence:command-output-fail |') },
  [pscustomobject]@{ Name = 'derived blocked from pass plus blocked'; Text = $parity.Replace($parityScenarioRow, $parityBlockedRows).Replace('| pass | evidence:command-output-pass |', '| blocked | evidence:native-blocker |') },
  [pscustomobject]@{ Name = 'aggregate mismatch for pass plus fail'; Text = $parity.Replace($parityScenarioRow, $parityFailRows) }
)) {
  if ($parityScenarioMutation.Text -ceq $parity) { throw "Parity scenario mutation was a silent no-op: $($parityScenarioMutation.Name)" }
  Assert-GerritDiagnosticsExactly -Name "public Gerrit gate rejects parity $($parityScenarioMutation.Name)" -KnowledgeBaseText $producerKnowledgeBase -GerritText $migrationUnitGerrit -ExpectedDiagnostics @('responsibility-evidence-missing') -ParityText $parityScenarioMutation.Text
}

$regressionVerdictBlock = Get-ArtifactSectionBlock -Text $regression -Heading $migrationConclusionHeading
foreach ($regressionVerdictMutation in @(
  [pscustomobject]@{ Name = 'missing'; Text = $regression.Replace($regressionVerdictBlock, '') },
  [pscustomobject]@{ Name = 'duplicate'; Text = $regression.Replace($regressionVerdictBlock, "$regressionVerdictBlock$regressionVerdictBlock") },
  [pscustomobject]@{ Name = 'malformed'; Text = $regression.Replace('| pass | required | pass | evidence:command-output-pass |', '| PASS | required | pass | evidence:command-output-pass |') },
  [pscustomobject]@{ Name = 'failed parity'; Text = $regression.Replace('| pass | required | pass | evidence:command-output-pass |', '| fail | required | pass | evidence:parity-fail |') },
  [pscustomobject]@{ Name = 'failed regression'; Text = $regression.Replace('| pass | required | pass | evidence:command-output-pass |', '| pass | required | fail | evidence:regression-fail |') },
  [pscustomobject]@{ Name = 'blocked regression'; Text = $regression.Replace('| pass | required | pass | evidence:command-output-pass |', '| pass | required | blocked | evidence:native-blocker |') },
  [pscustomobject]@{ Name = 'placeholder evidence'; Text = $regression.Replace('evidence:command-output-pass', '<regression evidence>') }
)) {
  if ($regressionVerdictMutation.Text -ceq $regression) { throw "Regression verdict mutation was a silent no-op: $($regressionVerdictMutation.Name)" }
  Assert-GerritDiagnosticsExactly -Name "public Gerrit gate rejects $($regressionVerdictMutation.Name) regression verdict" -KnowledgeBaseText $producerKnowledgeBase -GerritText $migrationUnitGerrit -ExpectedDiagnostics @('responsibility-evidence-missing') -RegressionText $regressionVerdictMutation.Text
}

$regressionScenarioBlock = Get-ArtifactSectionBlock -Text $regression -Heading $scenarioHeading
$regressionScenarioRow = '| admin lock regression | baseline:locked | target:locked | expected | not-applicable | REQ-001 | pass |'
$regressionFailRows = "$regressionScenarioRow`n| admin unlock regression | baseline:unlocked | target:locked | unexpected | not-applicable | REQ-001 | fail |"
$regressionBlockedRows = "$regressionScenarioRow`n| admin unlock regression | baseline:unlocked | target:unknown | unknown | not-applicable | REQ-001 | blocked |"
foreach ($regressionScenarioMutation in @(
  [pscustomobject]@{ Name = 'missing scenario table'; Text = $regression.Replace($regressionScenarioBlock, '') },
  [pscustomobject]@{ Name = 'duplicate scenario table'; Text = $regression.Replace($regressionScenarioBlock, "$regressionScenarioBlock$regressionScenarioBlock") },
  [pscustomobject]@{ Name = 'malformed scenario columns'; Text = $regression.Replace('| Scenario | Baseline | Actual | Delta Class | Waiver Reference | Trace IDs | Verdict |', '| Scenario | Actual | Baseline | Delta Class | Waiver Reference | Trace IDs | Verdict |') },
  [pscustomobject]@{ Name = 'placeholder scenario evidence'; Text = $regression.Replace($regressionScenarioRow, '| admin lock regression | baseline:locked | <actual> | expected | not-applicable | REQ-001 | pass |') },
  [pscustomobject]@{ Name = 'derived fail from pass plus fail'; Text = $regression.Replace($regressionScenarioRow, $regressionFailRows).Replace('| pass | required | pass | evidence:command-output-pass |', '| pass | required | fail | evidence:command-output-fail |') },
  [pscustomobject]@{ Name = 'derived blocked from pass plus blocked'; Text = $regression.Replace($regressionScenarioRow, $regressionBlockedRows).Replace('| pass | required | pass | evidence:command-output-pass |', '| pass | required | blocked | evidence:native-blocker |') },
  [pscustomobject]@{ Name = 'aggregate mismatch for pass plus fail'; Text = $regression.Replace($regressionScenarioRow, $regressionFailRows) }
)) {
  if ($regressionScenarioMutation.Text -ceq $regression) { throw "Regression scenario mutation was a silent no-op: $($regressionScenarioMutation.Name)" }
  Assert-GerritDiagnosticsExactly -Name "public Gerrit gate rejects regression $($regressionScenarioMutation.Name)" -KnowledgeBaseText $producerKnowledgeBase -GerritText $migrationUnitGerrit -ExpectedDiagnostics @('responsibility-evidence-missing') -RegressionText $regressionScenarioMutation.Text
}

$regressionWithForeignParityEvidence = $regression.Replace('| pass | required | pass | evidence:command-output-pass |', '| pass | required | pass | evidence:foreign-parity-pass |')
if ($regressionWithForeignParityEvidence -ceq $regression) { throw 'Regression parity evidence preservation mutation was a silent no-op' }
Assert-GerritDiagnosticsExactly -Name 'public Gerrit gate requires regression to preserve preceding parity overall and evidence' -KnowledgeBaseText $producerKnowledgeBase -GerritText $migrationUnitGerrit -ExpectedDiagnostics @('responsibility-evidence-missing') -RegressionText $regressionWithForeignParityEvidence

$enrichedRegressionEvidence = 'evidence:command-output-pass; evidence:regression-command-pass'
$enrichedRegression = $regression.Replace('| pass | required | pass | evidence:command-output-pass |', "| pass | required | pass | $enrichedRegressionEvidence |")
if ($enrichedRegression -ceq $regression) { throw 'Canonical enriched regression evidence mutation was a silent no-op' }
$enrichedRegressionGerrit = New-GerritArtifact -KnowledgeBaseText $producerKnowledgeBase -AdapterKind migration-unit -TerminalEvidence $enrichedRegressionEvidence
Assert-GerritAccepted -Name 'public Gerrit gate accepts canonical regression evidence enriched from exact parity evidence' -KnowledgeBaseText $producerKnowledgeBase -GerritText $enrichedRegressionGerrit -RegressionText $enrichedRegression

$knowledgeTerminalBlock = Get-ArtifactSectionBlock -Text $producerKnowledgeBase -Heading $terminalVerificationHeading
$knowledgeSummaryBlock = Get-ArtifactSectionBlock -Text $producerKnowledgeBase -Heading $runSummaryHeading
$canonicalKnowledgeTerminalRow = '| migration | incremental | UNIT-ADMIN-LOCK | 14-regression-report.md | PASS | complete |'
foreach ($knowledgeVerdictMutation in @(
  [pscustomobject]@{ Name = 'missing Terminal Verification'; Text = $producerKnowledgeBase.Replace($knowledgeTerminalBlock, '') },
  [pscustomobject]@{ Name = 'duplicate Terminal Verification'; Text = $producerKnowledgeBase.Replace($knowledgeTerminalBlock, "$knowledgeTerminalBlock$knowledgeTerminalBlock") },
  [pscustomobject]@{ Name = 'malformed workflow'; Text = $producerKnowledgeBase.Replace($canonicalKnowledgeTerminalRow, '| Migration | incremental | UNIT-ADMIN-LOCK | 14-regression-report.md | PASS | complete |') },
  [pscustomobject]@{ Name = 'FAIL Terminal Verification'; Text = $producerKnowledgeBase.Replace($canonicalKnowledgeTerminalRow, '| migration | incremental | UNIT-ADMIN-LOCK | 14-regression-report.md | FAIL | complete |') },
  [pscustomobject]@{ Name = 'BLOCKED Terminal Verification'; Text = $producerKnowledgeBase.Replace($canonicalKnowledgeTerminalRow, '| migration | incremental | UNIT-ADMIN-LOCK | 14-regression-report.md | BLOCKED | complete |') },
  [pscustomobject]@{ Name = 'placeholder Terminal Verification evidence'; Text = $producerKnowledgeBase.Replace($canonicalKnowledgeTerminalRow, '| migration | incremental | UNIT-ADMIN-LOCK | <terminal artifact> | PASS | complete |') },
  [pscustomobject]@{ Name = 'mismatched terminal mode'; Text = $producerKnowledgeBase.Replace($canonicalKnowledgeTerminalRow, '| migration | greenfield | UNIT-ADMIN-LOCK | 14-regression-report.md | PASS | complete |') },
  [pscustomobject]@{ Name = 'mismatched terminal unit'; Text = $producerKnowledgeBase.Replace($canonicalKnowledgeTerminalRow, '| migration | incremental | UNIT-FOREIGN-LOCK | 14-regression-report.md | PASS | complete |') },
  [pscustomobject]@{ Name = 'mismatched terminal artifact'; Text = $producerKnowledgeBase.Replace($canonicalKnowledgeTerminalRow, '| migration | incremental | UNIT-ADMIN-LOCK | 13-parity-report.md | PASS | complete |') },
  [pscustomobject]@{ Name = 'blocked terminal completion'; Text = $producerKnowledgeBase.Replace($canonicalKnowledgeTerminalRow, '| migration | incremental | UNIT-ADMIN-LOCK | 14-regression-report.md | PASS | blocked |') },
  [pscustomobject]@{ Name = 'mismatched summary workflow'; Text = $producerKnowledgeBase.Replace('- Workflow Type: migration', '- Workflow Type: feature') },
  [pscustomobject]@{ Name = 'mismatched summary terminal artifact'; Text = $producerKnowledgeBase.Replace('- Terminal Input Artifact: 14-regression-report.md', '- Terminal Input Artifact: 13-parity-report.md') },
  [pscustomobject]@{ Name = 'partial summary completion'; Text = $producerKnowledgeBase.Replace('- Completion Verdict: complete', '- Completion Verdict: partial') },
  [pscustomobject]@{ Name = 'duplicate terminal summary'; Text = $producerKnowledgeBase.Replace($knowledgeSummaryBlock, "$knowledgeSummaryBlock$knowledgeSummaryBlock") }
)) {
  if ($knowledgeVerdictMutation.Text -ceq $producerKnowledgeBase) { throw "Knowledge Base verdict mutation was a silent no-op: $($knowledgeVerdictMutation.Name)" }
  Assert-GerritDiagnosticsExactly -Name "public Gerrit gate rejects $($knowledgeVerdictMutation.Name)" -KnowledgeBaseText $knowledgeVerdictMutation.Text -GerritText $migrationUnitGerrit -ExpectedDiagnostics @('responsibility-evidence-missing')
}

$gerritVerdictBlock = Get-ArtifactSectionBlock -Text $migrationUnitGerrit -Heading 'Migration Verification Verdicts'
$canonicalGerritVerdictRow = '| pass | required | pass | evidence:command-output-pass |'
foreach ($gerritVerdictMutation in @(
  [pscustomobject]@{ Name = 'missing'; Text = $migrationUnitGerrit.Replace($gerritVerdictBlock, '') },
  [pscustomobject]@{ Name = 'duplicate'; Text = $migrationUnitGerrit.Replace($gerritVerdictBlock, "$gerritVerdictBlock$gerritVerdictBlock") },
  [pscustomobject]@{ Name = 'malformed'; Text = $migrationUnitGerrit.Replace($canonicalGerritVerdictRow, '| PASS | required | pass | evidence:command-output-pass |') },
  [pscustomobject]@{ Name = 'failed parity'; Text = $migrationUnitGerrit.Replace($canonicalGerritVerdictRow, '| fail | required | pass | evidence:regression-command-fail |') },
  [pscustomobject]@{ Name = 'failed regression'; Text = $migrationUnitGerrit.Replace($canonicalGerritVerdictRow, '| pass | required | fail | evidence:regression-command-fail |') },
  [pscustomobject]@{ Name = 'blocked regression'; Text = $migrationUnitGerrit.Replace($canonicalGerritVerdictRow, '| pass | required | blocked | evidence:native-blocker |') },
  [pscustomobject]@{ Name = 'placeholder evidence'; Text = $migrationUnitGerrit.Replace('evidence:command-output-pass', '<migration verification evidence>') },
  [pscustomobject]@{ Name = 'mismatched applicability'; Text = $migrationUnitGerrit.Replace($canonicalGerritVerdictRow, '| pass | not-applicable | not-applicable | evidence:command-output-pass |') }
)) {
  if ($gerritVerdictMutation.Text -ceq $migrationUnitGerrit) { throw "Gerrit verdict mutation was a silent no-op: $($gerritVerdictMutation.Name)" }
  Assert-GerritDiagnosticsExactly -Name "public Gerrit gate rejects $($gerritVerdictMutation.Name) Gerrit migration verdict" -KnowledgeBaseText $producerKnowledgeBase -GerritText $gerritVerdictMutation.Text -ExpectedDiagnostics @('responsibility-evidence-missing')
}

$foreignIncrementalGerritEvidence = $migrationUnitGerrit.Replace($canonicalGerritVerdictRow, '| pass | required | pass | evidence:foreign-terminal-pass |')
if ($foreignIncrementalGerritEvidence -ceq $migrationUnitGerrit) { throw 'Incremental foreign Gerrit evidence mutation was a silent no-op' }
Assert-GerritDiagnosticsExactly -Name 'public Gerrit gate rejects foreign incremental Gerrit evidence' -KnowledgeBaseText $producerKnowledgeBase -GerritText $foreignIncrementalGerritEvidence -ExpectedDiagnostics @('responsibility-evidence-missing')

Assert-GerritDiagnosticsExactly -Name 'public Gerrit gate rejects incremental Gerrit evidence that does not match enriched regression evidence' -KnowledgeBaseText $producerKnowledgeBase -GerritText $migrationUnitGerrit -ExpectedDiagnostics @('responsibility-evidence-missing') -RegressionText $enrichedRegression

$canonicalGreenfieldGerritVerdictRow = '| pass | not-applicable | not-applicable | evidence:command-output-pass |'
$foreignGreenfieldGerritEvidence = $greenfieldGerrit.Replace($canonicalGreenfieldGerritVerdictRow, '| pass | not-applicable | not-applicable | evidence:foreign-terminal-pass |')
if ($foreignGreenfieldGerritEvidence -ceq $greenfieldGerrit) { throw 'Greenfield foreign Gerrit evidence mutation was a silent no-op' }
Assert-GerritDiagnosticsExactly -Name 'public Gerrit gate rejects foreign greenfield Gerrit evidence' -KnowledgeBaseText $greenfieldKnowledgeBase -GerritText $foreignGreenfieldGerritEvidence -ExpectedDiagnostics @('responsibility-evidence-missing') -ImplementationText $greenfieldGenericImplementation -ReviewText $greenfieldReview -VerificationText $greenfieldVerification -ParityText $greenfieldParity -RegressionText '' -ApprovedPlanText $greenfieldGenericPlan

$mismatchedGreenfieldGerritEvidence = $greenfieldGerrit.Replace($canonicalGreenfieldGerritVerdictRow, '| pass | not-applicable | not-applicable | evidence:command-output-pass; evidence:foreign-terminal-pass |')
if ($mismatchedGreenfieldGerritEvidence -ceq $greenfieldGerrit) { throw 'Greenfield mismatched Gerrit evidence mutation was a silent no-op' }
Assert-GerritDiagnosticsExactly -Name 'public Gerrit gate rejects greenfield Gerrit evidence that does not exactly match parity evidence' -KnowledgeBaseText $greenfieldKnowledgeBase -GerritText $mismatchedGreenfieldGerritEvidence -ExpectedDiagnostics @('responsibility-evidence-missing') -ImplementationText $greenfieldGenericImplementation -ReviewText $greenfieldReview -VerificationText $greenfieldVerification -ParityText $greenfieldParity -RegressionText '' -ApprovedPlanText $greenfieldGenericPlan

foreach ($allChainAuthorityForgery in @(
  [pscustomobject]@{
    Name = 'Bootstrap Scope'; From = '| greenfield/design-new | required | FOUNDATION-ADMIN |'; To = '| greenfield/design-new | not-required | FOUNDATION-ADMIN |'
    Implementation = $greenfieldUnitImplementation; Review = $greenfieldUnitReview; Verification = $greenfieldUnitVerification; Parity = $greenfieldUnitParity; Regression = ''; KnowledgeBase = $greenfieldUnitKnowledgeBase; Plan = $greenfieldMigrationPlan
  },
  [pscustomobject]@{
    Name = 'Foundation Baseline ID'; From = '| FOUNDATION-ADMIN | foundation-admin.md#BASE-ADMIN |'; To = '| FOUNDATION-FOREIGN | foundation-admin.md#BASE-ADMIN |'
    Implementation = $greenfieldUnitImplementation; Review = $greenfieldUnitReview; Verification = $greenfieldUnitVerification; Parity = $greenfieldUnitParity; Regression = ''; KnowledgeBase = $greenfieldUnitKnowledgeBase; Plan = $greenfieldMigrationPlan
  },
  [pscustomobject]@{
    Name = 'Foundation Baseline Reference'; From = '| foundation-admin.md#BASE-ADMIN | approval:FOUNDATION-ADMIN |'; To = '| foundation-foreign.md#BASE-FOREIGN | approval:FOUNDATION-ADMIN |'
    Implementation = $greenfieldUnitImplementation; Review = $greenfieldUnitReview; Verification = $greenfieldUnitVerification; Parity = $greenfieldUnitParity; Regression = ''; KnowledgeBase = $greenfieldUnitKnowledgeBase; Plan = $greenfieldMigrationPlan
  },
  [pscustomobject]@{
    Name = 'Foundation Baseline Approval Reference'; From = '| approval:FOUNDATION-ADMIN | not-applicable | REQ-001 |'; To = '| approval:FOUNDATION-FOREIGN | not-applicable | REQ-001 |'
    Implementation = $greenfieldUnitImplementation; Review = $greenfieldUnitReview; Verification = $greenfieldUnitVerification; Parity = $greenfieldUnitParity; Regression = ''; KnowledgeBase = $greenfieldUnitKnowledgeBase; Plan = $greenfieldMigrationPlan
  },
  [pscustomobject]@{
    Name = 'Baseline Reference'; From = '| not-applicable | baseline.md#BASE-ADMIN | REQ-001 |'; To = '| not-applicable | baseline-foreign.md#BASE-FOREIGN | REQ-001 |'
    Implementation = $producerImplementation; Review = $producerReview; Verification = $producerVerification; Parity = $parity; Regression = $regression; KnowledgeBase = $producerKnowledgeBase; Plan = $script:migrationPlan
  }
)) {
  $forgedReview = $allChainAuthorityForgery.Review.Replace($allChainAuthorityForgery.From, $allChainAuthorityForgery.To)
  $forgedVerification = $allChainAuthorityForgery.Verification.Replace($allChainAuthorityForgery.From, $allChainAuthorityForgery.To)
  $forgedParity = $allChainAuthorityForgery.Parity.Replace($allChainAuthorityForgery.From, $allChainAuthorityForgery.To)
  $forgedRegression = if ([string]::IsNullOrWhiteSpace([string]$allChainAuthorityForgery.Regression)) { '' } else { $allChainAuthorityForgery.Regression.Replace($allChainAuthorityForgery.From, $allChainAuthorityForgery.To) }
  $forgedKnowledgeBase = $allChainAuthorityForgery.KnowledgeBase.Replace($allChainAuthorityForgery.From, $allChainAuthorityForgery.To)
  if (
    $forgedReview -ceq $allChainAuthorityForgery.Review -or
    $forgedVerification -ceq $allChainAuthorityForgery.Verification -or
    $forgedParity -ceq $allChainAuthorityForgery.Parity -or
    (-not [string]::IsNullOrWhiteSpace([string]$allChainAuthorityForgery.Regression) -and $forgedRegression -ceq $allChainAuthorityForgery.Regression) -or
    $forgedKnowledgeBase -ceq $allChainAuthorityForgery.KnowledgeBase
  ) { throw "All-chain selected-unit authority forgery was a silent no-op: $($allChainAuthorityForgery.Name)" }
  $forgedGerrit = New-GerritArtifact -KnowledgeBaseText $forgedKnowledgeBase -AdapterKind migration-unit
  Assert-GerritDiagnosticsExactly -Name "implementation-origin gate rejects an all-downstream-chain valid-looking forged $($allChainAuthorityForgery.Name)" -KnowledgeBaseText $forgedKnowledgeBase -GerritText $forgedGerrit -ExpectedDiagnostics @('responsibility-evidence-missing') -ImplementationText $allChainAuthorityForgery.Implementation -ReviewText $forgedReview -VerificationText $forgedVerification -ParityText $forgedParity -RegressionText $forgedRegression -ApprovedPlanText $allChainAuthorityForgery.Plan
}

# Equality between two terminal artifacts is not authority. Keep the upstream
# review/plan tuple canonical and prove that coherent KB+Gerrit forgeries are
# rejected even when every duplicated terminal cell agrees.
foreach ($pairedSelectedUnitForgery in @(
  [pscustomobject]@{ Name = 'migration unit identity'; From = 'UNIT-ADMIN-LOCK'; To = 'not-a-unit' },
  [pscustomobject]@{ Name = 'plan reference'; From = '08-migration-plan.md@1'; To = 'garbage@@' },
  [pscustomobject]@{ Name = 'valid-looking foreign plan reference'; From = '08-migration-plan.md@1'; To = 'foreign-plan.md@9' },
  [pscustomobject]@{ Name = 'approval reference'; From = 'approval:UNIT-ADMIN-LOCK'; To = 'approval:UNIT-FOREIGN-LOCK' },
  [pscustomobject]@{ Name = 'mode constraint'; From = 'incremental/preserve-existing'; To = 'banana' },
  [pscustomobject]@{ Name = 'bootstrap scope'; From = 'not-required'; To = 'required' },
  [pscustomobject]@{ Name = 'foundation baseline ID'; From = '| not-applicable | not-applicable | not-applicable | baseline.md#BASE-ADMIN |'; To = '| FOUNDATION-FOREIGN | not-applicable | not-applicable | baseline.md#BASE-ADMIN |' },
  [pscustomobject]@{ Name = 'foundation baseline reference'; From = '| not-applicable | not-applicable | not-applicable | baseline.md#BASE-ADMIN |'; To = '| not-applicable | foundation-foreign.md | not-applicable | baseline.md#BASE-ADMIN |' },
  [pscustomobject]@{ Name = 'foundation baseline approval'; From = '| not-applicable | not-applicable | not-applicable | baseline.md#BASE-ADMIN |'; To = '| not-applicable | not-applicable | approval:FOUNDATION-FOREIGN | baseline.md#BASE-ADMIN |' },
  [pscustomobject]@{ Name = 'baseline reference'; From = 'baseline.md#BASE-ADMIN'; To = 'not-applicable' },
  [pscustomobject]@{ Name = 'trace IDs'; From = '| REQ-001 |'; To = '| TRACE-FOREIGN |' }
)) {
  $forgedKnowledgeBase = $producerKnowledgeBase.Replace($pairedSelectedUnitForgery.From, $pairedSelectedUnitForgery.To)
  if ($forgedKnowledgeBase -ceq $producerKnowledgeBase) { throw "Paired selected-unit forgery was a silent no-op: $($pairedSelectedUnitForgery.Name)" }
  $forgedGerrit = New-GerritArtifact -KnowledgeBaseText $forgedKnowledgeBase -AdapterKind migration-unit
  Assert-GerritDiagnosticsExactly "review-to-KB-to-Gerrit rejects a paired forged $($pairedSelectedUnitForgery.Name)" $forgedKnowledgeBase $forgedGerrit @('responsibility-evidence-missing')
}

$allChainForeignUnit = 'UNIT-FOREIGN-LOCK'
$forgedChainReview = $producerReview.Replace('UNIT-ADMIN-LOCK', $allChainForeignUnit)
$forgedChainVerification = $producerVerification.Replace('UNIT-ADMIN-LOCK', $allChainForeignUnit)
$forgedChainParity = $parity.Replace('UNIT-ADMIN-LOCK', $allChainForeignUnit)
$forgedChainRegression = $regression.Replace('UNIT-ADMIN-LOCK', $allChainForeignUnit)
$forgedChainKnowledgeBase = $producerKnowledgeBase.Replace('UNIT-ADMIN-LOCK', $allChainForeignUnit)
if (@(@($forgedChainReview, $forgedChainVerification, $forgedChainParity, $forgedChainRegression, $forgedChainKnowledgeBase) | Where-Object { $_ -notmatch $allChainForeignUnit }).Count -ne 0) {
  throw 'All-chain selected-unit equality attack contained a silent no-op'
}
$forgedChainGerrit = New-GerritArtifact -KnowledgeBaseText $forgedChainKnowledgeBase -AdapterKind migration-unit
Assert-GerritDiagnosticsExactly -Name 'review-to-KB-to-Gerrit rejects an all-chain selected-unit equality attack against the approved plan' -KnowledgeBaseText $forgedChainKnowledgeBase -GerritText $forgedChainGerrit -ExpectedDiagnostics @('responsibility-evidence-missing') -ReviewText $forgedChainReview -VerificationText $forgedChainVerification -ParityText $forgedChainParity -RegressionText $forgedChainRegression -ApprovedPlanText $script:migrationPlan

$foreignTaskBaseSha = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
$foreignFinalTreeSha = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
$forgedLineageKnowledgeBase = $producerKnowledgeBase.Replace('1111111111111111111111111111111111111111', $foreignTaskBaseSha).Replace('2222222222222222222222222222222222222222', $foreignFinalTreeSha)
if ($forgedLineageKnowledgeBase -ceq $producerKnowledgeBase) { throw 'Review-origin provenance equality attack was a silent no-op' }
$forgedLineageGerrit = New-GerritArtifact -KnowledgeBaseText $forgedLineageKnowledgeBase -AdapterKind migration-unit
Assert-GerritDiagnosticsExactly 'review-to-KB-to-Gerrit rejects paired terminal SHAs and source-diff that diverge from review lineage' $forgedLineageKnowledgeBase $forgedLineageGerrit @('responsibility-evidence-missing')

$terminalOnlyGerritDiagnostics = @(Test-ResponsibilityGerrit -KnowledgeBaseText $producerKnowledgeBase -GerritText $migrationUnitGerrit -ContractText $contract | Sort-Object -Unique)
if (($terminalOnlyGerritDiagnostics -join '|') -cne 'responsibility-evidence-missing') {
  throw "The public Gerrit gate must reject terminal-only KB/Gerrit equality; got: $($terminalOnlyGerritDiagnostics -join '; ')"
}
Write-Output 'PASS: public Gerrit gate rejects the obsolete terminal-only KB/Gerrit invocation'

Assert-GerritDiagnosticsExactly -Name 'incremental Gerrit chain cannot omit the required regression predecessor' -KnowledgeBaseText $producerKnowledgeBase -GerritText $migrationUnitGerrit -ExpectedDiagnostics @('responsibility-evidence-missing') -ReviewText $producerReview -VerificationText $producerVerification -ParityText $parity -RegressionText '' -ApprovedPlanText $script:migrationPlan
Assert-GerritDiagnosticsExactly -Name 'greenfield Gerrit chain cannot insert a regression predecessor' -KnowledgeBaseText $greenfieldKnowledgeBase -GerritText $greenfieldGerrit -ExpectedDiagnostics @('responsibility-evidence-missing') -ReviewText $greenfieldReview -VerificationText $greenfieldVerification -ParityText $greenfieldParity -RegressionText $genericRegression -ApprovedPlanText $greenfieldGenericPlan

$selfLabeledKnowledgeBase = $producerKnowledgeBase.Replace('| 14-regression-report.md |', '| kb-entry.md |')
if ($selfLabeledKnowledgeBase -ceq $producerKnowledgeBase) { throw 'Knowledge Base provenance self-label mutation was a silent no-op' }
$selfLabeledGerrit = New-GerritArtifact -KnowledgeBaseText $selfLabeledKnowledgeBase -AdapterKind migration-unit
Assert-GerritDiagnosticsExactly 'KB-to-Gerrit rejects paired artifacts that self-label preserved Task Provenance as kb-entry.md' $selfLabeledKnowledgeBase $selfLabeledGerrit @('responsibility-evidence-missing')

$malformedShaKnowledgeBase = $producerKnowledgeBase.Replace('1111111111111111111111111111111111111111', 'not-a-sha')
if ($malformedShaKnowledgeBase -ceq $producerKnowledgeBase) { throw 'Knowledge Base malformed SHA mutation was a silent no-op' }
$malformedShaGerrit = New-GerritArtifact -KnowledgeBaseText $malformedShaKnowledgeBase -AdapterKind migration-unit
Assert-GerritDiagnosticsExactly 'KB-to-Gerrit rejects paired artifacts with a malformed provenance SHA and matching source-diff' $malformedShaKnowledgeBase $malformedShaGerrit @('responsibility-evidence-missing')

$malformedScopeKnowledgeBase = $producerKnowledgeBase.Replace('WORK-ADMIN-LOCK', 'WORK-admin-lock')
if ($malformedScopeKnowledgeBase -ceq $producerKnowledgeBase) { throw 'Knowledge Base malformed scope mutation was a silent no-op' }
$malformedScopeGerrit = New-GerritArtifact -KnowledgeBaseText $malformedScopeKnowledgeBase -AdapterKind migration-unit
Assert-GerritDiagnosticsExactly 'KB-to-Gerrit rejects paired artifacts with malformed scope identity and matching source-diff' $malformedScopeKnowledgeBase $malformedScopeGerrit @('responsibility-evidence-missing')

$invalidHandoffKnowledgeBase = $producerKnowledgeBase.Replace('| 1 | PASS | PASS | PASS | PASS | source-diff:', '| 1 | UNKNOWN | PASS | PASS | BLOCKED | source-diff:')
if ($invalidHandoffKnowledgeBase -ceq $producerKnowledgeBase) { throw 'Knowledge Base invalid handoff verdict mutation was a silent no-op' }
$invalidHandoffGerrit = New-GerritArtifact -KnowledgeBaseText $invalidHandoffKnowledgeBase -AdapterKind migration-unit
Assert-GerritDiagnosticsExactly 'KB-to-Gerrit rejects paired artifacts with a noncanonical handoff verdict' $invalidHandoffKnowledgeBase $invalidHandoffGerrit @('responsibility-evidence-missing')

$invalidHandoffVersionKnowledgeBase = $producerKnowledgeBase.Replace('| 1 | PASS | PASS | PASS | PASS | source-diff:', '| 2 | PASS | PASS | PASS | PASS | source-diff:')
if ($invalidHandoffVersionKnowledgeBase -ceq $producerKnowledgeBase) { throw 'Knowledge Base handoff-version mutation was a silent no-op' }
$invalidHandoffVersionGerrit = New-GerritArtifact -KnowledgeBaseText $invalidHandoffVersionKnowledgeBase -AdapterKind migration-unit
Assert-GerritDiagnosticsExactly 'KB-to-Gerrit rejects paired artifacts with an unsupported handoff contract version' $invalidHandoffVersionKnowledgeBase $invalidHandoffVersionGerrit @('responsibility-contract-version-invalid')

$extraContractChildKnowledgeBase = $producerKnowledgeBase.Replace('  applicability: required', "  applicability: required`n  forged_child: value")
if ($extraContractChildKnowledgeBase -ceq $producerKnowledgeBase) { throw 'Knowledge Base responsibility-contract child mutation was a silent no-op' }
$extraContractChildGerrit = New-GerritArtifact -KnowledgeBaseText $extraContractChildKnowledgeBase -AdapterKind migration-unit
Assert-GerritDiagnosticsExactly 'KB-to-Gerrit rejects a terminal Knowledge Base with an extra responsibility-contract child' $extraContractChildKnowledgeBase $extraContractChildGerrit @('responsibility-contract-version-invalid')

foreach ($mutation in @(
  [pscustomobject]@{ Name = 'forged step'; From = 'step_id: 15-knowledge-base'; To = 'step_id: 99-forged' },
  [pscustomobject]@{ Name = 'draft status'; From = 'status: approved'; To = 'status: draft' },
  [pscustomobject]@{ Name = 'blocked result'; From = 'result: complete'; To = 'result: blocked' },
  [pscustomobject]@{ Name = 'automatic approval'; From = 'approval_source: human'; To = 'approval_source: auto' },
  [pscustomobject]@{ Name = 'malformed production date'; From = 'produced_at: 2026-08-20'; To = 'produced_at: 2026-02-30' }
)) {
  $mutatedKnowledgeBase = $producerKnowledgeBase.Replace($mutation.From, $mutation.To)
  if ($mutatedKnowledgeBase -ceq $producerKnowledgeBase) { throw "Knowledge Base lifecycle mutation was a silent no-op: $($mutation.Name)" }
  Assert-GerritRejected "KB-to-Gerrit rejects terminal Knowledge Base with $($mutation.Name)" $mutatedKnowledgeBase $migrationUnitGerrit
}
$extraKnowledgeBaseKey = $producerKnowledgeBase.Replace("status: approved`n", "status: approved`nforged_key: value`n")
if ($extraKnowledgeBaseKey -ceq $producerKnowledgeBase) { throw 'Knowledge Base extra-key mutation was a silent no-op' }
Assert-GerritRejected 'KB-to-Gerrit rejects terminal Knowledge Base with an extra lifecycle key' $extraKnowledgeBaseKey $migrationUnitGerrit

$kbProvenanceSection = Get-ArtifactSectionBlock -Text $producerKnowledgeBase -Heading 'Task Provenance'
$kbSelectedSection = Get-ArtifactSectionBlock -Text $producerKnowledgeBase -Heading 'Selected Migration Unit'
$kbHandoffSection = Get-ArtifactSectionBlock -Text $producerKnowledgeBase -Heading 'Architecture Responsibility Handoff'
$reorderedKnowledgeBase = $producerKnowledgeBase.Replace("$kbProvenanceSection$kbSelectedSection$kbHandoffSection", "$kbHandoffSection$kbProvenanceSection$kbSelectedSection")
if ($reorderedKnowledgeBase -ceq $producerKnowledgeBase) { throw 'Knowledge Base-to-Gerrit envelope reorder mutation was a silent no-op' }
Assert-GerritRejected 'KB-to-Gerrit rejects a reordered terminal Knowledge Base envelope' $reorderedKnowledgeBase $migrationUnitGerrit

$gerritProvenanceSection = Get-ArtifactSectionBlock -Text $migrationUnitGerrit -Heading 'Task Provenance'
$gerritSelectedSection = Get-ArtifactSectionBlock -Text $migrationUnitGerrit -Heading 'Selected Migration Unit'
$gerritHandoffSection = Get-ArtifactSectionBlock -Text $migrationUnitGerrit -Heading 'Architecture Responsibility Handoff'
$reorderedGerrit = $migrationUnitGerrit.Replace("$gerritProvenanceSection$gerritSelectedSection$gerritHandoffSection", "$gerritHandoffSection$gerritProvenanceSection$gerritSelectedSection")
if ($reorderedGerrit -ceq $migrationUnitGerrit) { throw 'Gerrit envelope reorder mutation was a silent no-op' }
Assert-GerritRejected 'KB-to-Gerrit rejects a reordered Gerrit envelope' $producerKnowledgeBase $reorderedGerrit
$reorderedGerritAdapterMode = $migrationUnitGerrit.Replace("- Delivery Adapter Kind: migration-unit`n- Delivery Adapter Mode Constraint: incremental/preserve-existing", "- Delivery Adapter Mode Constraint: incremental/preserve-existing`n- Delivery Adapter Kind: migration-unit")
if ($reorderedGerritAdapterMode -ceq $migrationUnitGerrit) { throw 'Gerrit adapter/mode order mutation was a silent no-op' }
Assert-GerritRejected 'KB-to-Gerrit rejects Gerrit adapter mode before adapter kind' $producerKnowledgeBase $reorderedGerritAdapterMode

$migrationSelectedSection = Get-ArtifactSectionBlock -Text $migrationUnitGerrit -Heading 'Selected Migration Unit'
$migrationWithoutSelected = $migrationUnitGerrit.Replace($migrationSelectedSection, '')
Assert-GerritRejected 'migration-unit Gerrit cannot omit Selected Migration Unit' $producerKnowledgeBase $migrationWithoutSelected
$migrationDuplicateSelected = $migrationUnitGerrit.Replace($migrationSelectedSection, "$migrationSelectedSection$migrationSelectedSection")
Assert-GerritRejected 'migration-unit Gerrit cannot duplicate Selected Migration Unit' $producerKnowledgeBase $migrationDuplicateSelected 'responsibility-evidence-missing'
$genericInventedSelected = $genericGerrit.Replace('## Architecture Responsibility Handoff', "$migrationSelectedSection`n## Architecture Responsibility Handoff")
Assert-GerritRejected -Name 'generic Gerrit cannot invent Selected Migration Unit' -KnowledgeBaseText $producerGenericKnowledgeBase -GerritText $genericInventedSelected -ReviewText $genericReview -VerificationText $genericVerification -ParityText $genericParity -RegressionText $genericRegression -ApprovedPlanText $genericPlan
$noneInventedSelected = $noneGerrit.Replace('## Architecture Responsibility Handoff', "$migrationSelectedSection`n## Architecture Responsibility Handoff")
Assert-GerritRejected -Name 'none Gerrit cannot invent Selected Migration Unit' -KnowledgeBaseText $producerNoneKnowledgeBase -GerritText $noneInventedSelected -ReviewText $noneReview -VerificationText $noneVerification -ParityText $noneParity -RegressionText $noneRegression -ApprovedPlanText $noneSelectorGenericPlan
$genericWrongIdentity = $genericGerrit.Replace('| 1 | WORK-ADMIN-LOCK | PASS |', '| 1 | TASK-ADMIN-LOCK | PASS |')
if ($genericWrongIdentity -ceq $genericGerrit) { throw 'generic Gerrit identity mutation was a silent no-op' }
Assert-GerritRejected -Name 'generic Gerrit Branch and Commit Integrity uses Work Item ID, not external selector' -KnowledgeBaseText $producerGenericKnowledgeBase -GerritText $genericWrongIdentity -ReviewText $genericReview -VerificationText $genericVerification -ParityText $genericParity -RegressionText $genericRegression -ApprovedPlanText $genericPlan
$gerritMutatedHandoff = $migrationUnitGerrit.Replace('source-diff:1111111111111111111111111111111111111111..2222222222222222222222222222222222222222#WORK-ADMIN-LOCK', 'source-diff:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa..bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb#WORK-ADMIN-LOCK')
Assert-GerritRejected 'Gerrit cannot mutate immutable review-to-KB responsibility evidence' $producerKnowledgeBase $gerritMutatedHandoff

$knowledgeBaseEnvelopeCases = @(
  [pscustomobject]@{
    Name = 'migration-unit'; Source = $regression; Target = $producerKnowledgeBase; Plan = $script:migrationPlan; AdapterKind = 'migration-unit'
    CanonicalHeadings = @('Master Scope Context', 'Task Provenance', 'Selected Migration Unit', 'Architecture Responsibility Handoff')
  }
  [pscustomobject]@{
    Name = 'generic'; Source = $producerGenericRegression; Target = $producerGenericKnowledgeBase; Plan = $genericPlan; AdapterKind = 'task'
    CanonicalHeadings = @('Master Scope Context', 'Task Provenance', 'Architecture Responsibility Handoff')
  }
  [pscustomobject]@{
    Name = 'none'; Source = $producerNoneRegression; Target = $producerNoneKnowledgeBase; Plan = $noneSelectorGenericPlan; AdapterKind = 'none'
    CanonicalHeadings = @('Master Scope Context', 'Task Provenance', 'Architecture Responsibility Handoff')
  }
)
$producerH2Headings = @(
  [regex]::Matches($producerKnowledgeBase, '(?m)^## (?<heading>[^\r\n]+?)\r?$') |
    ForEach-Object { $_.Groups['heading'].Value }
)
$producerHandoffHeadingIndex = [Array]::IndexOf($producerH2Headings, 'Architecture Responsibility Handoff')
if ($producerHandoffHeadingIndex -lt 0 -or ($producerHandoffHeadingIndex + 2) -ge $producerH2Headings.Count) {
  throw 'Knowledge Base producer template is missing the real surrounding H2 sections'
}
$knowledgeBaseSummaryHeading = $producerH2Headings[$producerHandoffHeadingIndex + 1]
$knowledgeBaseOtherHeading = $producerH2Headings[$producerHandoffHeadingIndex + 2]
$knowledgeBaseEnvelopeFailures = [Collections.Generic.List[string]]::new()
foreach ($lineEnding in @('LF', 'CRLF')) {
  foreach ($case in $knowledgeBaseEnvelopeCases) {
    $rendered = Convert-ArtifactLineEndings -Text $case.Target -Style $lineEnding
    Assert-HandoffAccepted "producer-rendered $($case.Name) Knowledge Base accepts the canonical envelope under $lineEnding" $case.Source $rendered $case.Plan
    $inlineCommentHeading = $rendered.Replace('## Master Scope Context', '## Master <!-- parser note --> Scope Context')
    if ($inlineCommentHeading -ceq $rendered) { throw "Knowledge Base inline-comment heading mutation was a silent no-op: $($case.Name) $lineEnding" }
    Assert-HandoffAccepted "producer-rendered $($case.Name) Knowledge Base ignores an inline heading comment under $lineEnding" $case.Source $inlineCommentHeading $case.Plan

    $surrounded = Move-ArtifactSectionBeforeHeading -Text $rendered -SectionHeading $knowledgeBaseSummaryHeading -BeforeHeading 'Master Scope Context'
    $adapterLine = "- Delivery Adapter Kind: $($case.AdapterKind)"
    $lineBreak = if ($lineEnding -ceq 'CRLF') { "`r`n" } else { "`n" }
    $withBodyDetail = $surrounded.Replace(
      $adapterLine,
      "$adapterLine$lineBreak$lineBreak### Producer detail$lineBreak$lineBreak" + 'Body text may mention ## marker without creating an H2.'
    )
    if ($withBodyDetail -ceq $surrounded) { throw "Knowledge Base body-detail mutation was a silent no-op: $($case.Name) $lineEnding" }
    Assert-HandoffAccepted "producer-rendered $($case.Name) Knowledge Base allows real surrounding sections and subheadings under $lineEnding" $case.Source $withBodyDetail $case.Plan

    for ($index = 0; $index -lt ($case.CanonicalHeadings.Count - 1); $index++) {
      $leftHeading = $case.CanonicalHeadings[$index]
      $rightHeading = $case.CanonicalHeadings[$index + 1]
      foreach ($interloperHeading in @($knowledgeBaseSummaryHeading, $knowledgeBaseOtherHeading)) {
        $interleaved = Move-ArtifactSectionBeforeHeading -Text $rendered -SectionHeading $interloperHeading -BeforeHeading $rightHeading
        $name = "producer-rendered $($case.Name) Knowledge Base rejects $interloperHeading between $leftHeading and $rightHeading under $lineEnding"
        $diagnostics = @(Test-ResponsibilityHandoff -SourceText $case.Source -TargetText $interleaved -ContractText $contract -ApprovedPlanText $case.Plan)
        if ($diagnostics -notcontains 'responsibility-evidence-missing') {
          $knowledgeBaseEnvelopeFailures.Add("$name expected responsibility-evidence-missing but got: $($diagnostics -join '; ')")
        }
        else { Write-Output "PASS: $name" }
      }
    }

    foreach ($heading in $case.CanonicalHeadings) {
      $headingLine = "## $heading$lineBreak"
      foreach ($mutation in @(
        [pscustomobject]@{ Name = 'duplicate'; Text = $rendered.Replace($headingLine, "$headingLine$headingLine"); Diagnostic = "ARC-CONTRACT-HEADING-CARDINALITY: $heading" }
        [pscustomobject]@{ Name = 'missing'; Text = $rendered.Replace($headingLine, ''); Diagnostic = "ARC-CONTRACT-MISSING-TABLE: $heading" }
      )) {
        if ($mutation.Text -ceq $rendered) { throw "Knowledge Base $($mutation.Name) heading mutation was a silent no-op: $heading" }
        $name = "producer-rendered $($case.Name) Knowledge Base rejects $($mutation.Name) $heading under $lineEnding"
        $diagnostics = @(Test-ResponsibilityHandoff -SourceText $case.Source -TargetText $mutation.Text -ContractText $contract -ApprovedPlanText $case.Plan)
        if ($diagnostics.Count -ne 1 -or $diagnostics[0] -cne $mutation.Diagnostic) {
          $knowledgeBaseEnvelopeFailures.Add("$name expected exactly [$($mutation.Diagnostic)] but got: [$($diagnostics -join '; ')]")
        }
        else { Write-Output "PASS: $name" }
      }
    }
  }
}
if ($knowledgeBaseEnvelopeFailures.Count -ne 0) { throw ($knowledgeBaseEnvelopeFailures -join [Environment]::NewLine) }
$producerSelectedUnitBlock = Get-ArtifactSectionBlock -Text $producerKnowledgeBase -Heading 'Selected Migration Unit'
Assert-HandoffDiagnosticsExactly 'producer-rendered migration terminal Knowledge Base cannot omit the selected migration unit' $regression ($producerKnowledgeBase.Replace($producerSelectedUnitBlock, '')) @('ARC-CONTRACT-MISSING-TABLE: Selected Migration Unit')
Assert-HandoffRejected 'producer-rendered generic terminal Knowledge Base cannot retain the selected migration unit' $producerGenericRegression ($producerGenericKnowledgeBase.Replace('## Architecture Responsibility Handoff', "$producerSelectedUnitBlock## Architecture Responsibility Handoff")) 'responsibility-evidence-missing' $genericPlan
Assert-HandoffRejected 'producer-rendered none terminal Knowledge Base cannot retain the selected migration unit' $producerNoneRegression ($producerNoneKnowledgeBase.Replace('## Architecture Responsibility Handoff', "$producerSelectedUnitBlock## Architecture Responsibility Handoff")) 'responsibility-evidence-missing' $noneSelectorGenericPlan
$producerScopeBlock = Get-ArtifactSectionBlock -Text $producerKnowledgeBase -Heading 'Master Scope Context'
$producerProvenanceBlock = Get-ArtifactSectionBlock -Text $producerKnowledgeBase -Heading 'Task Provenance'
$reorderedProducerKnowledgeBase = $producerKnowledgeBase.Replace("$producerScopeBlock$producerProvenanceBlock", "$producerProvenanceBlock$producerScopeBlock")
if ($reorderedProducerKnowledgeBase -ceq $producerKnowledgeBase) { throw 'Knowledge Base envelope reorder mutation was a silent no-op' }
Assert-HandoffRejected 'producer-rendered terminal Knowledge Base rejects reordered canonical envelope sections' $regression $reorderedProducerKnowledgeBase 'responsibility-evidence-missing'
Assert-HandoffDiagnosticsExactly 'producer-rendered terminal Knowledge Base rejects duplicate canonical envelope sections' $regression ($producerKnowledgeBase.Replace($producerProvenanceBlock, "$producerProvenanceBlock$producerProvenanceBlock")) @('ARC-CONTRACT-HEADING-CARDINALITY: Task Provenance')
Assert-HandoffDiagnosticsExactly 'producer-rendered terminal Knowledge Base cannot lose Master Scope Context' $regression ($producerKnowledgeBase -replace '(?ms)^## Master Scope Context.*?(?=^## )', '') @('ARC-CONTRACT-MISSING-TABLE: Master Scope Context')
Assert-HandoffRejected 'producer-rendered terminal Knowledge Base cannot mutate delivery adapter kind' $regression ($producerKnowledgeBase.Replace('- Delivery Adapter Kind: migration-unit', '- Delivery Adapter Kind: task')) 'responsibility-evidence-missing'
Assert-HandoffRejected 'producer-rendered terminal Knowledge Base cannot mutate delivery adapter mode' $regression ($producerKnowledgeBase.Replace('- Delivery Adapter Mode Constraint: incremental/preserve-existing', '- Delivery Adapter Mode Constraint: greenfield/design-new')) 'responsibility-evidence-missing'
Assert-HandoffRejected 'producer-rendered terminal Knowledge Base cannot omit delivery adapter mode' $regression ($producerKnowledgeBase.Replace('- Delivery Adapter Mode Constraint: incremental/preserve-existing', '')) 'responsibility-evidence-missing'
$reorderedKnowledgeAdapterMode = $producerKnowledgeBase.Replace("- Delivery Adapter Kind: migration-unit`n- Delivery Adapter Mode Constraint: incremental/preserve-existing", "- Delivery Adapter Mode Constraint: incremental/preserve-existing`n- Delivery Adapter Kind: migration-unit")
if ($reorderedKnowledgeAdapterMode -ceq $producerKnowledgeBase) { throw 'Knowledge Base adapter/mode order mutation was a silent no-op' }
Assert-HandoffRejected 'producer-rendered terminal Knowledge Base keeps adapter kind before adapter mode' $regression $reorderedKnowledgeAdapterMode 'responsibility-evidence-missing'
Assert-HandoffRejected 'producer-rendered terminal Knowledge Base cannot bind foreign scope' $regression ($producerKnowledgeBase.Replace('| RUN-HANDOFF-001 | master-spec.md | SPEC-HANDOFF-001 | 1 | master-plan.md | PLAN-HANDOFF-001 | 1 | WORK-ADMIN-LOCK |', '| RUN-HANDOFF-OTHER | master-spec.md | SPEC-HANDOFF-001 | 1 | master-plan.md | PLAN-HANDOFF-001 | 1 | WORK-ADMIN-LOCK |')) 'responsibility-evidence-missing'
Assert-HandoffDiagnosticsExactly 'producer-rendered terminal Knowledge Base cannot lose task provenance' $regression ($producerKnowledgeBase -replace '(?ms)^## Task Provenance.*?(?=^## )', '') @('ARC-CONTRACT-MISSING-TABLE: Task Provenance')
Assert-HandoffRejected 'producer-rendered terminal Knowledge Base cannot mutate task provenance' $regression ($producerKnowledgeBase.Replace('| UNIT-ADMIN-LOCK | 1111111111111111111111111111111111111111 | 2222222222222222222222222222222222222222 | 14-regression-report.md |', '| UNIT-ADMIN-LOCK | 1111111111111111111111111111111111111111 | 3333333333333333333333333333333333333333 | 14-regression-report.md |')) 'responsibility-evidence-missing'
Assert-HandoffRejected 'draft review cannot seed verification' (New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -Status 'draft') $verification 'responsibility-evidence-missing'
Assert-HandoffRejected 'blocked review cannot seed verification' (New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -Result 'blocked') $verification 'responsibility-evidence-missing'
Assert-HandoffRejected 'review without approval source cannot seed verification' (New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -ApprovalSource '') $verification 'responsibility-evidence-missing'
Assert-HandoffRejected 'non-human review cannot seed verification' (New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -ApprovalSource 'auto') $verification 'responsibility-evidence-missing'
Assert-HandoffRejected 'Reject review conclusion cannot seed verification despite PASS architecture handoff' (New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -ReviewVerdict 'Reject') $verification 'responsibility-waiver-forbidden'
foreach ($requiredReviewControl in @(
  '- Rule Resolution Verdict: RESOLVED',
  '- Canonical Selector Verdict: PASS',
  '- Production Activation-path Verdict: NOT_APPLICABLE',
  '- Behavior Analysis State: COMPLETE',
  '- Change Hygiene Verdict: PASS',
  '- Major count: 0'
)) {
  $missingReviewControl = $review.Replace("$requiredReviewControl`r`n", '').Replace("$requiredReviewControl`n", '')
  if ($missingReviewControl -ceq $review) { throw "Missing executable-review control mutation was a silent no-op: $requiredReviewControl" }
  Assert-HandoffRejected "review missing executable control cannot seed verification: $requiredReviewControl" $missingReviewControl $verification 'responsibility-evidence-missing'
}
Assert-HandoffRejected 'review with BLOCKED selector and Approve conclusion cannot seed verification' (New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -CanonicalSelector 'BLOCKED') $verification 'responsibility-waiver-forbidden'
Assert-HandoffRejected 'review with NOT_RUN behavior after passing prebehavior gates cannot seed verification' (New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -BehaviorState 'NOT_RUN') $verification 'responsibility-waiver-forbidden'
Assert-HandoffRejected 'review with a positive Major count and Approve conclusion cannot seed verification' (New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -MajorCount 1) $verification 'responsibility-waiver-forbidden'
$majorFindingReview = New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -MajorCount 1
$majorFindingBlock = Get-ArtifactSectionBlock -Text $majorFindingReview -Heading 'Major'
$renderedMajorFindingBlock = $majorFindingBlock.Replace('| none | none | none |', '| src/admin_route.source:1 | MAJOR-REVIEW-001: review issue | Resolve before approval |')
if ($renderedMajorFindingBlock -ceq $majorFindingBlock) { throw 'Rendered Major finding mutation was a silent no-op' }
$majorFindingReview = $majorFindingReview.Replace($majorFindingBlock, $renderedMajorFindingBlock)
Assert-HandoffRejected 'review with an exactly counted Major finding derives Approve-with-fixes instead of claimed Approve' $majorFindingReview $verification 'responsibility-waiver-forbidden'
$contradictoryVisibleReview = $review.Replace('- Architecture Conformance Verdict: PASS', '- Architecture Conformance Verdict: BLOCKED')
if ($contradictoryVisibleReview -ceq $review) { throw 'Contradictory visible review verdict mutation was a silent no-op' }
Assert-HandoffRejected 'review handoff cannot contradict its visible architecture verdict' $contradictoryVisibleReview $verification 'responsibility-waiver-forbidden'
Assert-HandoffRejected 'case-variant review step cannot bypass a Reject conclusion' ((New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -ReviewVerdict 'Reject').Replace('step_id: 11-ai-review', 'step_id: 11-AI-REVIEW')) $verification 'responsibility-evidence-missing'
Assert-HandoffRejected 'case-variant review step cannot bypass a Critical finding' ((New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -CriticalCount 1).Replace('step_id: 11-ai-review', 'step_id: 11-AI-REVIEW')) $verification 'responsibility-evidence-missing'
Assert-HandoffRejected 'conflicting review lifecycle fields cannot seed verification' ($review.Replace('status: approved', "status: approved`nstatus: draft")) $verification 'responsibility-evidence-missing'
Assert-HandoffRejected 'draft verification cannot seed parity' (New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md' -Status 'draft') $parity 'responsibility-evidence-missing'
Assert-HandoffRejected 'blocked parity cannot seed incremental regression' (New-HandoffArtifact -StepId '13-verify-parity' -SourceArtifact 'verification-report.md' -Result 'blocked') $regression 'responsibility-evidence-missing'
Assert-HandoffRejected 'auto-approved regression cannot seed Knowledge Base' (New-HandoffArtifact -StepId '14-verify-regression' -SourceArtifact '13-parity-report.md' -ApprovalSource 'auto') $knowledgeBase 'responsibility-evidence-missing'
Assert-HandoffRejected 'draft Knowledge Base is not terminal executable assurance' $regression (New-HandoffArtifact -StepId '15-knowledge-base' -SourceArtifact '14-regression-report.md' -Status 'draft') 'responsibility-evidence-missing'
Assert-HandoffRejected 'downstream assurance front matter rejects an extra top-level key' ((New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md').Replace('produced_at: 2026-08-20', "foreign_run: RUN-OTHER`nproduced_at: 2026-08-20")) $parity 'responsibility-evidence-missing'
foreach ($extraKeyCase in @(
  @{ Name = 'quoted'; Line = '"foreign_run": RUN-OTHER' },
  @{ Name = 'hyphenated'; Line = 'foreign-run: RUN-OTHER' },
  @{ Name = 'case-variant'; Line = 'Status: approved' }
)) {
  $mutatedFrontMatter = (New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md').Replace('produced_at: 2026-08-20', "$($extraKeyCase.Line)`nproduced_at: 2026-08-20")
  Assert-HandoffRejected "$($extraKeyCase.Name) extra front-matter key fails closed" $mutatedFrontMatter $parity 'responsibility-evidence-missing'
}
Assert-HandoffRejected 'blank produced_at cannot seed parity' ((New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md').Replace('produced_at: 2026-08-20', 'produced_at:')) $parity 'responsibility-evidence-missing'
Assert-HandoffRejected 'malformed produced_at cannot seed parity' ((New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md').Replace('produced_at: 2026-08-20', 'produced_at: 2026-02-30')) $parity 'responsibility-evidence-missing'
Assert-HandoffRejected 'front-matter key order is canonical' ((New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md').Replace("status: approved`nresult: complete", "result: complete`nstatus: approved")) $parity 'responsibility-evidence-missing'
Assert-HandoffRejected 'seven-character provenance cannot seed verification' (New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -TaskBaseSha '1111111' -FinalTreeSha '2222222') (New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md' -TaskBaseSha '1111111' -FinalTreeSha '2222222') 'responsibility-evidence-missing'
Assert-HandoffRejected 'legacy filename evidence cannot seed verification' (New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -Evidence 'review-report.md#responsibility-evidence') $verification 'responsibility-evidence-missing'
Assert-HandoffRejected 'same work item and SHAs from another run cannot seed verification' $review (New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md' -RunId 'RUN-HANDOFF-OTHER') 'responsibility-evidence-missing'
Assert-HandoffDiagnosticsExactly 'migration-unit handoff cannot omit selected unit' $review (New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md' -OmitSelectedMigrationUnit) @('ARC-CONTRACT-MISSING-TABLE: Selected Migration Unit')
Assert-HandoffRejected 'generic handoff cannot invent selected unit' (New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -AdapterKind 'task') ((New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md' -AdapterKind 'task') + "`n## Selected Migration Unit`n") 'responsibility-evidence-missing'
$genericReview = New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -AdapterKind 'task'
$genericVerification = New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md' -AdapterKind 'task'
$genericParity = New-HandoffArtifact -StepId '13-verify-parity' -SourceArtifact 'verification-report.md' -AdapterKind 'task'
$genericRegression = New-HandoffArtifact -StepId '14-verify-regression' -SourceArtifact '13-parity-report.md' -AdapterKind 'task'
$genericKnowledgeBase = New-HandoffArtifact -StepId '15-knowledge-base' -SourceArtifact '14-regression-report.md' -AdapterKind 'task'
Assert-HandoffAccepted 'generic adapter review reaches verification without a selected migration unit' $genericReview $genericVerification $genericPlan
Assert-HandoffAccepted 'generic adapter verification reaches parity without a selected migration unit' $genericVerification $genericParity $genericPlan
Assert-HandoffRejected 'incremental generic adapter cannot skip regression before terminal KB' $genericParity (New-HandoffArtifact -StepId '15-knowledge-base' -SourceArtifact '13-parity-report.md' -AdapterKind 'task') 'responsibility-evidence-missing' $genericPlan
Assert-HandoffAccepted 'incremental generic adapter parity reaches regression without a selected migration unit' $genericParity $genericRegression $genericPlan
Assert-HandoffAccepted 'incremental generic adapter regression reaches terminal KB without a selected migration unit' $genericRegression $genericKnowledgeBase $genericPlan
$genericGreenfieldPlan = New-ApprovedAdapterPlan -AdapterKind task -SelectorApproval 'approval:TASK-ADMIN-LOCK' -SelectorMode 'greenfield/design-new'
$genericGreenfieldParity = New-HandoffArtifact -StepId '13-verify-parity' -SourceArtifact 'verification-report.md' -AdapterKind 'task' -ModeConstraint 'greenfield/design-new'
$genericGreenfieldKnowledgeBase = New-HandoffArtifact -StepId '15-knowledge-base' -SourceArtifact '13-parity-report.md' -AdapterKind 'task' -ModeConstraint 'greenfield/design-new'
Assert-HandoffAccepted 'greenfield generic adapter may omit regression before terminal KB' $genericGreenfieldParity $genericGreenfieldKnowledgeBase $genericGreenfieldPlan
Assert-HandoffRejected 'greenfield generic adapter cannot enter regression' $genericGreenfieldParity (New-HandoffArtifact -StepId '14-verify-regression' -SourceArtifact '13-parity-report.md' -AdapterKind 'task' -ModeConstraint 'greenfield/design-new') 'responsibility-evidence-missing' $genericGreenfieldPlan
Assert-HandoffRejected 'cross-spec plan ID cannot control greenfield regression ordering' $genericGreenfieldParity $genericGreenfieldKnowledgeBase 'responsibility-evidence-missing' ($genericGreenfieldPlan.Replace('master_spec_id: SPEC-HANDOFF-001', 'master_spec_id: SPEC-FOREIGN-001'))
Assert-HandoffRejected 'cross-spec plan revision cannot control greenfield regression ordering' $genericGreenfieldParity $genericGreenfieldKnowledgeBase 'responsibility-evidence-missing' ($genericGreenfieldPlan.Replace('master_spec_revision: 1', 'master_spec_revision: 2'))
Assert-HandoffRejected 'foreign master plan ID cannot control greenfield regression ordering' $genericGreenfieldParity $genericGreenfieldKnowledgeBase 'responsibility-evidence-missing' ($genericGreenfieldPlan.Replace('master_plan_id: PLAN-HANDOFF-001', 'master_plan_id: PLAN-FOREIGN-001'))
Assert-HandoffRejected 'stale master plan revision cannot control greenfield regression ordering' $genericGreenfieldParity $genericGreenfieldKnowledgeBase 'responsibility-evidence-missing' ($genericGreenfieldPlan.Replace('revision: 1', 'revision: 2'))
Assert-HandoffRejected 'unapproved master plan cannot control greenfield regression ordering' $genericGreenfieldParity $genericGreenfieldKnowledgeBase 'responsibility-evidence-missing' ($genericGreenfieldPlan.Replace('status: approved', 'status: draft'))
$packagePlan = New-ApprovedAdapterPlan -AdapterKind package -SelectorApproval 'approval:PACKAGE-ADMIN-LOCK'
$packageReview = New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -AdapterKind package
$packageVerification = New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md' -AdapterKind package
Assert-HandoffAccepted 'package selector preserves its concrete external authority and Work Item assurance identity' $packageReview $packageVerification $packagePlan
$noneSelectorReview = New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -AdapterKind 'none'
$noneSelectorVerification = New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md' -AdapterKind 'none'
Assert-HandoffAccepted 'none selector retains approved generic delivery adapter with Work Item assurance identity' $noneSelectorReview $noneSelectorVerification $noneSelectorGenericPlan
$noneSelectorParity = New-HandoffArtifact -StepId '13-verify-parity' -SourceArtifact 'verification-report.md' -AdapterKind 'none'
$noneSelectorRegression = New-HandoffArtifact -StepId '14-verify-regression' -SourceArtifact '13-parity-report.md' -AdapterKind 'none'
$noneSelectorKnowledgeBase = New-HandoffArtifact -StepId '15-knowledge-base' -SourceArtifact '14-regression-report.md' -AdapterKind 'none'
Assert-HandoffRejected 'incremental none adapter cannot skip regression before terminal KB' $noneSelectorParity (New-HandoffArtifact -StepId '15-knowledge-base' -SourceArtifact '13-parity-report.md' -AdapterKind 'none') 'responsibility-evidence-missing' $noneSelectorGenericPlan
Assert-HandoffAccepted 'incremental none adapter parity reaches regression' $noneSelectorParity $noneSelectorRegression $noneSelectorGenericPlan
Assert-HandoffAccepted 'incremental none adapter regression reaches terminal KB' $noneSelectorRegression $noneSelectorKnowledgeBase $noneSelectorGenericPlan
$parentChildPlan = New-ParentChildAdapterPlan
$parentChildReview = New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -AdapterKind story -WorkItemId 'WORK-ADMIN-CHILD'
$parentChildVerification = New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md' -AdapterKind story -WorkItemId 'WORK-ADMIN-CHILD'
Assert-HandoffAccepted 'generic child handoff resolves exact parent selector from the whole approved plan' $parentChildReview $parentChildVerification $parentChildPlan
$caseDistinctSelectorPlan = $parentChildPlan.Replace('| story | STORY-ADMIN-CHILD |', '| story | task-admin-parent |').Replace('story:STORY-ADMIN-CHILD', 'story:task-admin-parent')
if ($caseDistinctSelectorPlan -ceq $parentChildPlan) { throw 'case-distinct downstream selector fixture mutation was a silent no-op' }
Assert-HandoffAccepted 'generic child handoff preserves case-only distinct canonical selector identities' $parentChildReview $parentChildVerification $caseDistinctSelectorPlan
Assert-HandoffRejected 'generic child handoff rejects a missing parent selector' $parentChildReview $parentChildVerification 'responsibility-evidence-missing' ($parentChildPlan.Replace('| approval:STORY-ADMIN-CHILD | TASK-ADMIN-PARENT |', '| approval:STORY-ADMIN-CHILD | not-applicable |'))
Assert-HandoffRejected 'generic child handoff rejects a foreign parent selector' $parentChildReview $parentChildVerification 'responsibility-evidence-missing' ($parentChildPlan.Replace('| approval:STORY-ADMIN-CHILD | TASK-ADMIN-PARENT |', '| approval:STORY-ADMIN-CHILD | STORY-ADMIN-CHILD |'))
Assert-HandoffRejected 'generic child handoff rejects a case-only parent selector mismatch' $parentChildReview $parentChildVerification 'responsibility-evidence-missing' ($parentChildPlan.Replace('| approval:STORY-ADMIN-CHILD | TASK-ADMIN-PARENT |', '| approval:STORY-ADMIN-CHILD | task-admin-parent |'))
Assert-HandoffRejected 'generic child handoff rejects a missing parent Work Item' $parentChildReview $parentChildVerification 'responsibility-evidence-missing' ($parentChildPlan.Replace('| WORK-ADMIN-PARENT | DEC-ADMIN-CHILD |', '| WORK-ADMIN-MISSING | DEC-ADMIN-CHILD |'))
$duplicateParentSelectorPlan = $parentChildPlan.Replace('| story | STORY-ADMIN-CHILD |', '| story | TASK-ADMIN-PARENT |').Replace('story:STORY-ADMIN-CHILD', 'story:TASK-ADMIN-PARENT')
Assert-HandoffRejected 'generic child handoff rejects duplicate selector identity' $parentChildReview $parentChildVerification 'responsibility-evidence-missing' $duplicateParentSelectorPlan
Assert-HandoffRejected 'generic child handoff rejects an unsupported parent adapter kind' $parentChildReview $parentChildVerification 'responsibility-evidence-missing' ($parentChildPlan.Replace('| task | TASK-ADMIN-PARENT |', '| generic | TASK-ADMIN-PARENT |').Replace('task:TASK-ADMIN-PARENT', 'generic:TASK-ADMIN-PARENT'))
$missingParentExternalIdPlan = $parentChildPlan.Replace('| task | TASK-ADMIN-PARENT |', '| task | not-applicable |').Replace('task:TASK-ADMIN-PARENT', 'task:not-applicable').Replace('| approval:STORY-ADMIN-CHILD | TASK-ADMIN-PARENT |', '| approval:STORY-ADMIN-CHILD | not-applicable |')
Assert-HandoffRejected 'generic child handoff rejects a concrete parent with an external-ID sentinel' $parentChildReview $parentChildVerification 'responsibility-evidence-missing' $missingParentExternalIdPlan
Assert-HandoffRejected 'generic child handoff rejects missing parent authority' $parentChildReview $parentChildVerification 'responsibility-evidence-missing' ($parentChildPlan.Replace('| jira:ADMIN-PARENT | 1 |', '| not-applicable | 1 |'))
Assert-HandoffRejected 'generic child handoff rejects stale parent authority revision' $parentChildReview $parentChildVerification 'responsibility-evidence-missing' ($parentChildPlan.Replace('| jira:ADMIN-PARENT | 1 |', '| jira:ADMIN-PARENT | 0 |'))
Assert-HandoffRejected 'generic child handoff rejects unresolved parent approval authority' $parentChildReview $parentChildVerification 'responsibility-evidence-missing' ($parentChildPlan.Replace('| approval:TASK-ADMIN-PARENT | not-applicable |', '| approval:TASK-ADMIN-PARENT-PENDING | not-applicable |'))
$parentSelectorRow = '| WORK-ADMIN-PARENT | task | TASK-ADMIN-PARENT | jira:ADMIN-PARENT | 1 | approval:TASK-ADMIN-PARENT | not-applicable | REQ-001; SC-001; completes within 2 seconds | REQ-001 | incremental/preserve-existing | DESIGN-ADMIN@2 | not-applicable | not-applicable |'
$childSelectorRow = '| WORK-ADMIN-CHILD | story | STORY-ADMIN-CHILD | ado:ADMIN-CHILD | 1 | approval:STORY-ADMIN-CHILD | TASK-ADMIN-PARENT | REQ-001; SC-001; completes within 2 seconds | REQ-001 | incremental/preserve-existing | DESIGN-ADMIN@2 | WORK-ADMIN-PARENT | DEC-ADMIN-CHILD |'
$parentWorkRow = '| WORK-ADMIN-PARENT | Parent | yes | none | 1 | REQ-001; SC-001; completes within 2 seconds | REQ-001 | task:TASK-ADMIN-PARENT | complete | ATTEMPT-PARENT-01 | terminal-parent.md | approval:WORK-ADMIN-PARENT |'
$childWorkRow = '| WORK-ADMIN-CHILD | Child | yes | WORK-ADMIN-PARENT | 2 | REQ-001; SC-001; completes within 2 seconds | REQ-001 | story:STORY-ADMIN-CHILD | in-progress | ATTEMPT-CHILD-01 | none | approval:WORK-ADMIN-CHILD |'
$reorderedParentSelectorPlan = $parentChildPlan.Replace("$parentSelectorRow`n$childSelectorRow", "$childSelectorRow`n$parentSelectorRow").Replace("$parentWorkRow`n$childWorkRow", "$childWorkRow`n$parentWorkRow")
Assert-HandoffRejected 'generic child handoff rejects reordered parent selector authority' $parentChildReview $parentChildVerification 'responsibility-evidence-missing' $reorderedParentSelectorPlan
Assert-HandoffRejected 'caller adapter self-attestation cannot override approved plan authority' $genericReview $genericVerification 'responsibility-evidence-missing' $script:migrationPlan
Assert-HandoffDiagnosticsExactly 'Work Items shorthand alone cannot self-authorize a migration selector' $review $verification @('ARC-CONTRACT-MISSING-TABLE: Delivery Adapter Selection') (New-ApprovedAdapterPlan -OmitSelectorTable)
$pendingSelectorPlan = New-ApprovedAdapterPlan -SelectorApproval 'approval:UNIT-ADMIN-LOCK-PENDING'
$pendingReview = $review.Replace('approval:UNIT-ADMIN-LOCK | incremental', 'approval:UNIT-ADMIN-LOCK-PENDING | incremental')
$pendingVerification = $verification.Replace('approval:UNIT-ADMIN-LOCK | incremental', 'approval:UNIT-ADMIN-LOCK-PENDING | incremental')
Assert-HandoffRejected 'pending selector cannot authorize handoff even when both artifacts repeat it' $pendingReview $pendingVerification 'responsibility-evidence-missing' $pendingSelectorPlan
Assert-HandoffRejected 'stale selector authority revision cannot authorize handoff' $review $verification 'responsibility-evidence-missing' (New-ApprovedAdapterPlan -AuthorityRevision '2')
$foreignTracePlan = New-ApprovedAdapterPlan -SelectorTraceIds 'REQ-FOREIGN'
$foreignTraceReview = $review.Replace('| REQ-001 |', '| REQ-FOREIGN |')
$foreignTraceVerification = $verification.Replace('| REQ-001 |', '| REQ-FOREIGN |')
Assert-HandoffRejected 'selector trace mismatch against current Work Item cannot authorize handoff even when artifacts repeat it' $foreignTraceReview $foreignTraceVerification 'responsibility-evidence-missing' $foreignTracePlan
Assert-HandoffRejected 'migration-unit selected row is preserved ordinally across the chain' $review ($verification.Replace('baseline.md#BASE-ADMIN', 'baseline.md#BASE-MUTATED')) 'responsibility-evidence-missing'
Assert-HandoffRejected 'handoff fails closed without approved adapter plan authority' $review $verification 'responsibility-evidence-missing' ''
$reorderedSelectorPlan = $script:migrationPlan.Replace(
  '| WORK-ADMIN-LOCK | Admin lock | yes | none | 1 | REQ-001; SC-001; completes within 2 seconds | REQ-001 | migration-unit:UNIT-ADMIN-LOCK | complete | ATTEMPT-ADMIN-01 | terminal-admin.md | approval:WORK-ADMIN-LOCK |',
  "| WORK-ADMIN-LOCK | Admin lock | yes | none | 1 | REQ-001; SC-001; completes within 2 seconds | REQ-001 | migration-unit:UNIT-ADMIN-LOCK | complete | ATTEMPT-ADMIN-01 | terminal-admin.md | approval:WORK-ADMIN-LOCK |`n| WORK-ADMIN-OTHER | Other | no | none | 2 | REQ-001; SC-001; completes within 2 seconds | REQ-001 | none | ready | none | none | pending |"
).Replace(
  '| WORK-ADMIN-LOCK | migration-unit | UNIT-ADMIN-LOCK | 08-migration-plan.md | 1 | approval:UNIT-ADMIN-LOCK | not-applicable | REQ-001; SC-001; completes within 2 seconds | REQ-001 | incremental/preserve-existing | DESIGN-ADMIN@2 | not-applicable | not-applicable |',
  "| WORK-ADMIN-OTHER | none | not-applicable | not-applicable | not-applicable | not-applicable | not-applicable | REQ-001; SC-001; completes within 2 seconds | REQ-001 | incremental/preserve-existing | DESIGN-ADMIN@2 | not-applicable | not-applicable |`n| WORK-ADMIN-LOCK | migration-unit | UNIT-ADMIN-LOCK | 08-migration-plan.md | 1 | approval:UNIT-ADMIN-LOCK | not-applicable | REQ-001; SC-001; completes within 2 seconds | REQ-001 | incremental/preserve-existing | DESIGN-ADMIN@2 | not-applicable | not-applicable |"
)
if ($reorderedSelectorPlan -ceq $script:migrationPlan) { throw 'reordered complete selector set fixture mutation was a silent no-op' }
Assert-HandoffRejected 'approved plan selector order is immutable and matches Work Items' $review $verification 'responsibility-evidence-missing' $reorderedSelectorPlan
$duplicateOtherSelectorPlan = $script:migrationPlan.Replace(
  '| WORK-ADMIN-LOCK | Admin lock | yes | none | 1 | REQ-001; SC-001; completes within 2 seconds | REQ-001 | migration-unit:UNIT-ADMIN-LOCK | complete | ATTEMPT-ADMIN-01 | terminal-admin.md | approval:WORK-ADMIN-LOCK |',
  "| WORK-ADMIN-LOCK | Admin lock | yes | none | 1 | REQ-001; SC-001; completes within 2 seconds | REQ-001 | migration-unit:UNIT-ADMIN-LOCK | complete | ATTEMPT-ADMIN-01 | terminal-admin.md | approval:WORK-ADMIN-LOCK |`n| WORK-ADMIN-OTHER | Other | no | none | 2 | REQ-001; SC-001; completes within 2 seconds | REQ-001 | none | ready | none | none | pending |`n| WORK-ADMIN-MISSING | Missing | no | none | 3 | REQ-001; SC-001; completes within 2 seconds | REQ-001 | none | ready | none | none | pending |"
).Replace(
  '| WORK-ADMIN-LOCK | migration-unit | UNIT-ADMIN-LOCK | 08-migration-plan.md | 1 | approval:UNIT-ADMIN-LOCK | not-applicable | REQ-001; SC-001; completes within 2 seconds | REQ-001 | incremental/preserve-existing | DESIGN-ADMIN@2 | not-applicable | not-applicable |',
  "| WORK-ADMIN-LOCK | migration-unit | UNIT-ADMIN-LOCK | 08-migration-plan.md | 1 | approval:UNIT-ADMIN-LOCK | not-applicable | REQ-001; SC-001; completes within 2 seconds | REQ-001 | incremental/preserve-existing | DESIGN-ADMIN@2 | not-applicable | not-applicable |`n| WORK-ADMIN-OTHER | none | not-applicable | not-applicable | not-applicable | not-applicable | not-applicable | REQ-001; SC-001; completes within 2 seconds | REQ-001 | incremental/preserve-existing | DESIGN-ADMIN@2 | not-applicable | not-applicable |`n| WORK-ADMIN-OTHER | none | not-applicable | not-applicable | not-applicable | not-applicable | not-applicable | REQ-001; SC-001; completes within 2 seconds | REQ-001 | incremental/preserve-existing | DESIGN-ADMIN@2 | not-applicable | not-applicable |"
)
if ($duplicateOtherSelectorPlan -ceq $script:migrationPlan) { throw 'duplicate-one/missing-another handoff selector fixture mutation was a silent no-op' }
Assert-HandoffRejected 'approved plan selector set rejects duplicate-one and missing-another outside current Work Item' $review $verification 'responsibility-evidence-missing' $duplicateOtherSelectorPlan
Assert-HandoffDiagnosticsExactly 'producer-rendered migration review cannot omit task provenance' ($producerReview -replace '(?ms)^## Task Provenance.*?(?=^## )', '') $producerVerification @('ARC-CONTRACT-MISSING-TABLE: Task Provenance')
Assert-HandoffRejected 'producer-rendered migration review cannot bind a stale final-tree SHA' ($producerReview.Replace('2222222222222222222222222222222222222222 | implementation-report.md', '3333333333333333333333333333333333333333 | implementation-report.md')) $producerVerification 'responsibility-evidence-missing'

Assert-HandoffDiagnosticsExactly 'rejects a downstream artifact with no responsibility handoff table' $verification ($parity -replace '(?ms)^## Architecture Responsibility Handoff.*?(?=\z)', '') @('ARC-CONTRACT-MISSING-TABLE: Architecture Responsibility Handoff')
Assert-HandoffRejected 'rejects a downstream aggregate PASS that hides responsibility BLOCKED' $verification (New-HandoffArtifact -StepId '13-verify-parity' -SourceArtifact 'verification-report.md' -Responsibility 'BLOCKED' -Architecture 'PASS') 'responsibility-waiver-forbidden'
Assert-HandoffRejected 'rejects an altered responsibility evidence reference' $verification (New-HandoffArtifact -StepId '13-verify-parity' -SourceArtifact 'verification-report.md' -Evidence 'review-report.md#other-evidence') 'responsibility-evidence-missing'
Assert-HandoffRejected 'rejects unsupported responsibility contract version' $verification (($parity -replace '(?m)^\| 1 \|', '| 2 |') -replace '(?m)^  version: 1$', '  version: 2') 'responsibility-contract-version-invalid'
Assert-HandoffRejected 'rejects a cross-run or other-work-item provenance handoff' $verification (New-HandoffArtifact -StepId '13-verify-parity' -SourceArtifact 'verification-report.md' -TaskUnit 'WORK-OTHER') 'responsibility-evidence-missing'
Assert-HandoffRejected 'rejects a handoff that skips an immediate predecessor stage' $verification (New-HandoffArtifact -StepId '15-knowledge-base' -SourceArtifact 'verification-report.md') 'responsibility-evidence-missing'

$blockedReview = New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -Responsibility 'BLOCKED' -Architecture 'BLOCKED'
$waivedVerification = New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md' -Architecture 'PASS' -Waiver 'approval_source: auto-waive'
Assert-HandoffRejected 'runtime waiver cannot overwrite a blocked responsibility handoff' $blockedReview $waivedVerification 'responsibility-waiver-forbidden'

function Assert-RolloutAccepted {
  param([string]$Name, [string]$Text)
  $diagnostics = @(& $script:MigrationResponsibilityRolloutValidator $Text)
  if ($diagnostics.Count -ne 0) {
    throw "$Name should pass but got: $($diagnostics -join '; ')"
  }
  Write-Output "PASS: $Name"
}

function Assert-RolloutRejected {
  param([string]$Name, [string]$From, [string]$To)
  $mutated = $migrateSkill.Replace($From, $To)
  if ($mutated -ceq $migrateSkill) { throw "$Name mutation was a silent no-op" }
  $diagnostics = @(& $script:MigrationResponsibilityRolloutValidator $mutated)
  if ($diagnostics -notcontains 'migration-responsibility-rollout-invalid') {
    throw "$Name expected migration-responsibility-rollout-invalid but got: $($diagnostics -join '; ')"
  }
  Write-Output "PASS: $Name"
}

Assert-RolloutAccepted 'migration orchestrator has a complete v1 responsibility rollout contract' $migrateSkill
Assert-RolloutRejected 'rollout derives architecture from all three structural sub-verdicts' `
  'v1 exact handoff; Tree PASS; Responsibility PASS; Verification PASS; immutable evidence resolves' `
  'v1 aggregate caller PASS'
Assert-RolloutRejected 'rollout rejects a missing immutable evidence link' `
  'missing or mismatched immutable evidence link' `
  'missing evidence is accepted'
Assert-RolloutRejected 'queue and resume resolve current immutable responsibility authority before production' `
  'Queue selection, resume, and dependency unlock use pre-edit planned authority: exactly one current approved master-plan `Delivery Adapter Selection` row and one `Responsibility Owner References` row for the Work Item, plus the exact approved immutable technical-design revision whose responsibility and verification-owner rows resolve bidirectionally with PASS conformance.' `
  'Queue selection may trust caller-attested responsibility fields.'
Assert-RolloutRejected 'terminal responsibility authority binds approved mode and current-run SHA provenance' `
  'The terminal chain uses the approved `Delivery Adapter Mode Constraint` preserved from its step-8 selector through step-10 canonical authority, never a terminal or chain self-label; the initial review is approved/complete/human, every chain artifact stays in the current run and binds the current master spec/plan/work item, and each source-diff SHA pair exactly equals immutable Task Provenance.' `
  'The terminal chain may self-label its mode and provenance.'
Assert-RolloutRejected 'rollout rejects mixed responsibility versions' `
  'mixed v1/v2 or cross-run evidence' `
  'mixed versions are compatible'
Assert-RolloutRejected 'completed pre-v1 artifacts remain historical-only' `
  '| completed pre-v1 artifact | historical-only | not executable |' `
  '| completed pre-v1 artifact | executable | PASS |'
Assert-RolloutRejected 'in-progress pre-v1 artifacts cannot resume' `
  '| in-progress pre-v1 artifact | blocked | BLOCKED | no resume; no production mutation; no dependent selection |' `
  '| in-progress pre-v1 artifact | compatible | PASS | resume |'
Assert-RolloutRejected 'responsibility blockers prevent dependent selection' `
  'scope-blocked; next eligible item: none; no dependent selection' `
  'scope-in-progress; select dependent item'
Assert-RolloutRejected 'responsibility blockers stop all downstream completion' `
  'stop before parity, regression, delivery, KB, and terminal completion' `
  'continue to parity, regression, delivery, KB, and terminal completion'
Assert-RolloutRejected 'terminal evidence binds the work-item artifact and mode-aware final chain artifact without conflating them' `
  'Its exact v1 handoff `Evidence References` remains the immutable `source-diff:<task-base>..<final-tree>#<WORK-*>` copied ordinally from review through Knowledge Base. A separate `Terminal Chain Reference` equals the final artifact of the mode-aware ordered chain, and the terminal report Evidence Index binds that final chain/KB artifact for each terminal-success item only; aggregation never mutates or overloads the handoff evidence cell.' `
  'Work Item Terminal Evidence may reference any artifact in a caller-provided chain.'
Assert-RolloutRejected 'responsibility blockers require an approved design and master-plan revision' `
  'approved design/master-plan revision required' `
  'automatic resume allowed'
Assert-RolloutRejected 'auto-waive cannot override a structural sub-verdict' `
  'Runtime `auto-waive` never changes Tree, Responsibility, or Verification Ownership sub-verdicts.' `
  'Runtime `auto-waive` may change a structural sub-verdict.'
Assert-RolloutRejected 'Phase 1 does not create Phase 2 remediation automatically' `
  'Do not create a Phase 2 remediation artifact or work item automatically.' `
  'Create a Phase 2 remediation work item automatically.'
Assert-RolloutRejected 'post-implementation responsibility mismatch preserves the full safe-stop chain' `
  'implementation `draft/blocked` -> AI review `Reject` -> work item `blocked` -> dependent item non-eligible -> parity/regression/delivery/KB/terminal completion blocked -> approved design/master-plan revision required' `
  'implementation mismatch -> continue downstream'

foreach ($relativePath in @(
  'skills/shared/ai-review/SKILL.md',
  'skills/shared/verification-testing/SKILL.md',
  'skills/migration/verify-parity/SKILL.md',
  'skills/migration/verify-regression/SKILL.md'
)) {
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath (Join-Path $root $relativePath)
  if ($text -cnotmatch '(?m)^(?:\d+\.|-)[^\r\n]*`Delivery Adapter Kind`[^\r\n]*`Delivery Adapter Mode Constraint`[^\r\n]*$') {
    throw "$relativePath output contract must preserve Delivery Adapter Kind and Delivery Adapter Mode Constraint together"
  }
}

Write-Output 'PASS: responsibility handoff scenarios'

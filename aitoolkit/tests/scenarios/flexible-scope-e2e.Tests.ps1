param([string[]]$OnlyScenario = @())

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$OutputEncoding = [Console]::OutputEncoding

$toolkitRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$validatorPath = Join-Path $toolkitRoot 'tests/validate-migration-framework.ps1'
$helperPath = Join-Path $toolkitRoot 'tests/helpers/IsolatedFixture.ps1'
$failures = [Collections.Generic.List[string]]::new()
. $helperPath
$FileChangesHeading=[regex]::Unescape('File \u0111\u00e3 thay \u0111\u1ed5i')
$TraceHeading=[regex]::Unescape('Trace ID tri\u1ec3n khai')
$CommandsHeading=[regex]::Unescape('L\u1ec7nh v\u00e0 k\u1ebft qu\u1ea3')
$BlockerHeading=[regex]::Unescape('Blocker g\u1ed1c')
$EvidenceHeading=[regex]::Unescape('B\u1eb1ng ch\u1ee9ng')
$UnknownHeading=[regex]::Unescape('\u0110i\u1ec3m ch\u01b0a r\u00f5')
$ConclusionHeading=[regex]::Unescape('K\u1ebft lu\u1eadn')

function Write-Utf8([string]$Path, [string]$Text) {
  $parent = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $parent -PathType Container)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
  [IO.File]::WriteAllText($Path, $Text, [Text.UTF8Encoding]::new($false))
}

function Get-AuthorityTextRevision([string]$Text) {
  $sha=[Security.Cryptography.SHA256]::Create()
  try{$bytes=([Text.UTF8Encoding]::new($false)).GetBytes($Text.Replace("`r`n","`n"));'sha256:'+([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','')}
  finally{$sha.Dispose()}
}
function Get-AuthorityTreeRevision([string]$Root) {
  $manifest=@(Get-ChildItem -LiteralPath $Root -File -Recurse|Sort-Object{$_.FullName.Substring($Root.Length).Replace('\','/')}|ForEach-Object{$relative=$_.FullName.Substring($Root.Length).TrimStart('\','/').Replace('\','/');$content=Get-Content -Raw -Encoding utf8 -LiteralPath $_.FullName;"$relative`n$($content.Replace("`r`n","`n"))"})-join"`n"
  Get-AuthorityTextRevision $manifest
}
function Write-ApprovedProjectProfile([string]$Root,[ValidateSet('incremental','greenfield')][string]$Mode) {
  $docs=Join-Path $Root 'docs/aitoolkit';$pack=Join-Path $docs 'migration-project';[void](New-Item -ItemType Directory -Path $pack -Force)
  Write-Utf8 (Join-Path $pack 'SKILL.md') "# Approved flexible-scope fixture pack`n"
  $reviewedAt='2026-08-20T12:00:00Z';$reviewEvidence='docs/aitoolkit/project-pack-review.md';$policy=if($Mode-ceq'greenfield'){'design-new'}else{'preserve-existing'}
  $profile=@"
schema_version: 1
project:
  id: flexible-scope-fixture
migration:
  mode: $Mode
  unit: feature
  architecture_policy: $policy
automation:
  mode: interactive
output:
  artifact_language: vi
legacy:
  path: null
  language: unknown
  framework: unknown
target:
  path: null
  language: unknown
  framework: unknown
documents:
  requirements: []
  uiux: []
  migration: []
  architecture: []
base_branch: null
test_cmd: null
lint_cmd: null
build_cmd: null
coverage_cmd: null
review_focus: []
verification:
  behavior_parity: required
  regression: optional
  visual_fidelity: optional
project_pack:
  path: docs/aitoolkit/migration-project
  reviewed_at: $reviewedAt
  review_evidence: $reviewEvidence
"@
  $profileRevision=Get-AuthorityTextRevision ($profile.Replace("reviewed_at: $reviewedAt",'reviewed_at: <review-metadata>').Replace("review_evidence: $reviewEvidence",'review_evidence: <review-metadata>'))
  $packRevision=Get-AuthorityTreeRevision $pack
  Write-Utf8 (Join-Path $docs 'project.yaml') $profile
  Write-Utf8 (Join-Path $docs 'project-pack-review.md') "---`nstep_id: 04-project-pack-review`nstatus: approved`nresult: complete`napproval_source: human`nproduced_at: 2026-08-20`n---`n`n## Độ mới của review`n`n| Reviewed At | Profile Revision | Pack Revision | Source/Target/Document Revisions | Approval Evidence |`n|---|---|---|---|---|`n| $reviewedAt | $profileRevision | $packRevision | not-applicable | approval:TECH-LEAD-PROJECT-PACK-001 |`n"
}

function Replace-Exact([string]$Path, [string]$Old, [string]$New, [string]$ScenarioId) {
  $before = Get-Content -Raw -Encoding utf8 -LiteralPath $Path
  $after = $before.Replace($Old, $New)
  if ($before -ceq $after -and $Old -match '\r|\n') {
    $fixtureEol = if ($before.Contains("`r`n")) { "`r`n" } else { "`n" }
    $fixtureOld = [regex]::Replace($Old, '\r\n?|\n', $fixtureEol)
    $fixtureNew = [regex]::Replace($New, '\r\n?|\n', $fixtureEol)
    $after = $before.Replace($fixtureOld, $fixtureNew)
  }
  if ($before -ceq $after) { throw "$ScenarioId mutation was a silent no-op in $Path : $Old" }
  Write-Utf8 $Path $after
}
function Get-ImmutableReference([string]$Run,[string]$Name){
  $path=Join-Path $Run $Name;$sha=[Security.Cryptography.SHA256]::Create();try{$digest=([BitConverter]::ToString($sha.ComputeHash([IO.File]::ReadAllBytes($path)))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()};"rendered-scope-run/$Name#sha256:$digest"
}
function Rebind-ImmutableReference([string]$Run,[string]$Old,[string]$New,[string]$ScenarioId){
  $changed=0;Get-ChildItem -LiteralPath $Run -File|Where-Object{$_.Extension-in@('.md','.json')}|ForEach-Object{$before=Get-Content -Raw -Encoding utf8 -LiteralPath $_.FullName;$after=$before.Replace($Old,$New);if($after-cne$before){Write-Utf8 $_.FullName $after;$changed++}};if($changed-eq0){throw "$ScenarioId immutable reference rebind was a silent no-op"}
}
function New-ResponsibilityReviewEvidence(
  [string]$Run,
  [string]$Name,
  [string]$WorkItem,
  [string]$ModeConstraint='incremental/preserve-existing',
  [string]$AdapterKind='migration-unit'
){
  $path=Join-Path $Run $Name
  $unit=if($WorkItem-ceq'WORK-E2E-A'){'UNIT-A'}else{'UNIT-B'}
  $assuranceIdentity=if($AdapterKind-ceq'migration-unit'){$unit}else{$WorkItem}
  if($ModeConstraint-ceq'greenfield/design-new'){
    $bootstrap='required'
    $foundationId=if($unit-ceq'UNIT-A'){'FOUNDATION-A'}else{'FOUNDATION-B'}
    $foundationReference=if($unit-ceq'UNIT-A'){'foundation:a'}else{'foundation:b'}
    $foundationApproval=if($unit-ceq'UNIT-A'){'approval:HUMAN-FOUNDATION-A'}else{'approval:HUMAN-FOUNDATION-B'}
    $baseline='not-applicable'
  }else{
    $bootstrap='not-required';$foundationId='not-applicable';$foundationReference='not-applicable';$foundationApproval='not-applicable'
    $baseline=if($unit-ceq'UNIT-A'){'baseline:a'}else{'baseline:b'}
  }
  $templatePath=Join-Path $toolkitRoot 'templates/migration/review-report.md'
  $text=Get-Content -Raw -Encoding utf8 -LiteralPath $templatePath
  $replacements=[ordered]@{
    'status: <draft | approved>'='status: approved'
    'result: <complete | blocked>'='result: complete'
    'approval_source: <human | auto | auto-waive>'='approval_source: human'
    'produced_at: <yyyy-mm-dd>'='produced_at: 2026-08-20'
    '| <RUN-*> | <master spec reference> | <SPEC-*> | <revision> | <master plan reference> | <PLAN-*> | <revision> | <WORK-*> |'="| RUN-E2E-001 | rendered-scope-run/master-spec.md | SPEC-E2E-001 | 1 | rendered-scope-run/master-plan.md | PLAN-E2E-001 | 1 | $WorkItem |"
    '- Delivery Adapter Kind: <migration-unit | task | story | package | phase | milestone | none>'="- Delivery Adapter Kind: $AdapterKind"
    '- Delivery Adapter Mode Constraint: <incremental/preserve-existing | greenfield/design-new>'="- Delivery Adapter Mode Constraint: $ModeConstraint"
    '- Rule Resolution Verdict: <RESOLVED | BLOCKED>'='- Rule Resolution Verdict: RESOLVED'
    '- Canonical Selector Verdict: <PASS | BLOCKED>'='- Canonical Selector Verdict: PASS'
    '- Architecture Conformance Verdict: <PASS | BLOCKED>'='- Architecture Conformance Verdict: PASS'
    '- Tree Conformance Verdict: <PASS | BLOCKED>'='- Tree Conformance Verdict: PASS'
    '- Responsibility Conformance Verdict: <PASS | BLOCKED>'='- Responsibility Conformance Verdict: PASS'
    '- Verification Ownership Verdict: <PASS | BLOCKED>'='- Verification Ownership Verdict: PASS'
    '- Production Activation-path Verdict: <PASS | BLOCKED | NOT_APPLICABLE>'='- Production Activation-path Verdict: NOT_APPLICABLE'
    '- Behavior Analysis State: <NOT_RUN | COMPLETE>'='- Behavior Analysis State: COMPLETE'
    '- Change Hygiene Verdict: <PASS | BLOCKED>'='- Change Hygiene Verdict: PASS'
    '| <UNIT-* for migration-unit; WORK-* otherwise> | <task-base SHA> | <final-tree SHA> | <immediate predecessor artifact path> |'="| $assuranceIdentity | 1111111111111111111111111111111111111111 | 2222222222222222222222222222222222222222 | implementation-report.md |"
    '| 1 | <tree verdict> | <responsibility verdict> | <verification verdict> | <derived architecture state> | source-diff:<task-base SHA>..<final-tree SHA>#<WORK-*> |'="| 1 | PASS | PASS | PASS | PASS | source-diff:1111111111111111111111111111111111111111..2222222222222222222222222222222222222222#$WorkItem |"
  }
  foreach($token in $replacements.Keys){$updated=$text.Replace($token,$replacements[$token]);if($updated-ceq$text){throw "Migration review producer template is missing seam token: $token"};$text=$updated}
  $renderedConclusion=[regex]::Replace($text,'(?m)^- \*\*Critical count:\*\*[^\r\n]*\r?$','- **Critical count:** 0',1)
  $renderedConclusion=[regex]::Replace($renderedConclusion,'(?m)^- \*\*Major count:\*\*[^\r\n]*\r?$','- **Major count:** 0',1)
  $renderedConclusion=[regex]::Replace($renderedConclusion,'(?m)^- Verdict: <Approve \| Approve-with-fixes \| Reject>[ \t]*\r?$','- Verdict: Approve',1)
  if($renderedConclusion-ceq$text-or@([regex]::Matches($renderedConclusion,'(?m)^- \*\*Critical count:\*\* 0\r?$')).Count-ne1-or@([regex]::Matches($renderedConclusion,'(?m)^- \*\*Major count:\*\* 0\r?$')).Count-ne1-or@([regex]::Matches($renderedConclusion,'(?m)^- Verdict: Approve\r?$')).Count-ne1){throw 'Migration review producer template is missing executable conclusion seams'}
  $text=$renderedConclusion
  if($AdapterKind-ceq'migration-unit'){
    $renderedSelectedUnit=[regex]::Replace($text,'(?m)^\| <UNIT-001> \|.*$',"| $unit | legacy-plan.md@7 | approval:HUMAN-$unit | $ModeConstraint | $bootstrap | $foundationId | $foundationReference | $foundationApproval | $baseline | TRACE-001 |",1)
    if($renderedSelectedUnit-ceq$text){throw 'Migration review producer template is missing selected-unit row seam'}
    $text=$renderedSelectedUnit
  }else{
    $withoutSelectedUnit=[regex]::Replace($text,'(?ms)^## Selected Migration Unit[ \t]*\r?\n.*?(?=^## |\z)','',1)
    if($withoutSelectedUnit-ceq$text-or$withoutSelectedUnit-match'(?m)^## Selected Migration Unit[ \t]*$'){throw 'Generic migration review renderer did not remove Selected Migration Unit'}
    $text=$withoutSelectedUnit
  }
  $renderedWithoutDomainBlocker=[regex]::Replace($text,'(?ms)^## Domain Blocker[ \t]*\r?\n.*?(?=^## |\z)','',1)
  if($renderedWithoutDomainBlocker-ceq$text-or$renderedWithoutDomainBlocker-match'(?m)^## Domain Blocker[ \t]*$'){throw 'Executable migration review renderer did not remove the conditional Domain Blocker section'}
  $text=$renderedWithoutDomainBlocker
  Write-Utf8 $path $text
  Get-ImmutableReference $Run $Name
}
function New-ResponsibilityDownstreamArtifact(
  [string]$Run,
  [string]$Name,
  [string]$WorkItem,
  [string]$StepId,
  [string]$SourceArtifact,
  [string]$ModeConstraint='incremental/preserve-existing',
  [string]$AdapterKind='migration-unit'
){
  $path=Join-Path $Run $Name
  $unit=if($WorkItem-ceq'WORK-E2E-A'){'UNIT-A'}else{'UNIT-B'}
  $assuranceIdentity=if($AdapterKind-ceq'migration-unit'){$unit}else{$WorkItem}
  if($ModeConstraint-ceq'greenfield/design-new'){
    $bootstrap='required'
    $foundationId=if($unit-ceq'UNIT-A'){'FOUNDATION-A'}else{'FOUNDATION-B'}
    $foundationReference=if($unit-ceq'UNIT-A'){'foundation:a'}else{'foundation:b'}
    $foundationApproval=if($unit-ceq'UNIT-A'){'approval:HUMAN-FOUNDATION-A'}else{'approval:HUMAN-FOUNDATION-B'}
    $baseline='not-applicable'
  }else{
    $bootstrap='not-required';$foundationId='not-applicable';$foundationReference='not-applicable';$foundationApproval='not-applicable'
    $baseline=if($unit-ceq'UNIT-A'){'baseline:a'}else{'baseline:b'}
  }
  $selectedUnitEnvelope=if($AdapterKind-ceq'migration-unit'){"`n`n## Selected Migration Unit`n`n| Migration Unit ID | Plan Reference | Approval Reference | Mode Constraint | Bootstrap Scope | Foundation Baseline ID | Foundation Baseline Reference | Foundation Baseline Approval Reference | Baseline Reference | Trace IDs |`n|---|---|---|---|---|---|---|---|---|---|`n| $unit | legacy-plan.md@7 | approval:HUMAN-$unit | $ModeConstraint | $bootstrap | $foundationId | $foundationReference | $foundationApproval | $baseline | TRACE-001 |"}else{''}
  Write-Utf8 $path "---`nstep_id: $StepId`nstatus: approved`nresult: complete`napproval_source: human`nproduced_at: 2026-08-20`nresponsibility_contract:`n  version: 1`n  applicability: required`n---`n# Responsibility Handoff Stage`n`n## Master Scope Context`n`n| Run ID | Master Spec Reference | Master Spec ID | Master Spec Revision | Master Plan Reference | Master Plan ID | Master Plan Revision | Work Item ID |`n|---|---|---|---|---|---|---|---|`n| RUN-E2E-001 | rendered-scope-run/master-spec.md | SPEC-E2E-001 | 1 | rendered-scope-run/master-plan.md | PLAN-E2E-001 | 1 | $WorkItem |`n`n- Delivery Adapter Kind: $AdapterKind`n- Delivery Adapter Mode Constraint: $ModeConstraint`n`n## Task Provenance`n`n| Task / Unit | Task-base SHA | Final-tree SHA | Source Artifact |`n|---|---|---|---|`n| $assuranceIdentity | 1111111111111111111111111111111111111111 | 2222222222222222222222222222222222222222 | $SourceArtifact |$selectedUnitEnvelope`n`n## Architecture Responsibility Handoff`n`n| Responsibility Contract Version | Tree Conformance | Responsibility Conformance | Verification Ownership | Architecture Conformance State | Evidence References |`n|---|---|---|---|---|---|`n| 1 | PASS | PASS | PASS | PASS | source-diff:1111111111111111111111111111111111111111..2222222222222222222222222222222222222222#$WorkItem |`n"
  Get-ImmutableReference $Run $Name
}
function Add-ResponsibilityHandoff([string]$Run,[string]$Name,[string]$WorkItem,[string]$TerminalChainReference){
  $path=Join-Path $Run $Name
  $before=Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $sourceDiff="source-diff:1111111111111111111111111111111111111111..2222222222222222222222222222222222222222#$WorkItem"
  $handoff="## Architecture Responsibility Handoff`n`n| Responsibility Contract Version | Tree Conformance | Responsibility Conformance | Verification Ownership | Architecture Conformance State | Evidence References |`n|---|---|---|---|---|---|`n| 1 | PASS | PASS | PASS | PASS | $sourceDiff |`n`n"
  $terminalChain="## Terminal Chain Reference`n`n| Work Item ID | Artifact Reference |`n|---|---|`n| $WorkItem | $TerminalChainReference |`n`n"
  $after=$before.Replace('## Work Item Test Evidence',"$handoff$terminalChain## Work Item Test Evidence")
  if($after-ceq$before){throw "Terminal responsibility handoff fixture insertion was a silent no-op: $Name"}
  Write-Utf8 $path $after
  Get-ImmutableReference $Run $Name
}
function New-Evidence([string]$Run,[string]$Name,[string]$WorkItem,[string]$AdapterKind='migration-unit'){
  $path=Join-Path $Run $Name
  $unit=if($WorkItem-ceq'WORK-E2E-A'){'UNIT-A'}else{'UNIT-B'}
  $workApproval=if($WorkItem-ceq'WORK-E2E-A'){'approval:HUMAN-WORK-A'}else{'approval:HUMAN-WORK-B'}
  $externalId=if($AdapterKind-ceq'migration-unit'){$unit}else{'not-applicable'}
  $authority=if($AdapterKind-ceq'migration-unit'){'legacy-plan.md'}else{'not-applicable'}
  $authorityRevision=if($AdapterKind-ceq'migration-unit'){'7'}else{'not-applicable'}
  $adapterApproval=if($AdapterKind-ceq'migration-unit'){"approval:HUMAN-$unit"}else{'not-applicable'}
  Write-Utf8 $path "---`nstep_id: 10-code-migration`nstatus: approved`nresult: complete`napproval_source: human`nproduced_at: 2026-08-20`n---`n# Implementation Report`n`n## Master Scope Context`n`n| Master Spec Reference | Master Spec ID | Master Spec Revision | Master Plan Reference | Master Plan ID | Master Plan Revision | Work Item ID | Work Item Approval Reference |`n|---|---|---|---|---|---|---|---|`n| rendered-scope-run/master-spec.md | SPEC-E2E-001 | 1 | rendered-scope-run/master-plan.md | PLAN-E2E-001 | 1 | $WorkItem | $workApproval |`n`n## Canonical Adapter Evidence`n`n| Work Item ID | Adapter Kind | External ID | Authority | Authority Revision | Approval Reference | Parent Selector | Acceptance | Trace IDs | Mode Constraint | Design Revision | Parent Work Item ID | Decomposition Decision Reference | Canonical Match |`n|---|---|---|---|---|---|---|---|---|---|---|---|---|---|`n| $WorkItem | $AdapterKind | $externalId | $authority | $authorityRevision | $adapterApproval | not-applicable | REQ-001; SC-001; measurable outcome | TRACE-001 | incremental/preserve-existing | DESIGN-E2E@1 | not-applicable | not-applicable | PASS |`n`n## Assurance State`n`n| Runtime Evidence State | Architecture Conformance State | Selector Schema State |`n|---|---|---|`n| PASS | PASS | PASS |`n`n## Work Item Test Evidence`n`n| Work Item ID | Activation Slice ID | Seam | Test | Command | Result | Trace IDs |`n|---|---|---|---|---|---|---|`n| $WorkItem | ACT-E2E-001 | runtime | behavioral verification | test:e2e | PASS | TRACE-001 |`n| $WorkItem | ACT-E2E-001 | persistence | integration verification | test:integration | PASS | TRACE-001 |`n"
  Get-ImmutableReference $Run $Name
}
function New-HistoricalEvidence([string]$Run,[string]$Name,[string]$Unit){$path=Join-Path $Run $Name;$baseline=if($Unit-ceq'UNIT-A'){'baseline:a'}else{'baseline:b'};Write-Utf8 $path "---`nstep_id: 10-code-migration`nstatus: approved`nresult: complete`napproval_source: human`nproduced_at: 2025-01-01`n---`n# Historical Code Migration Report`n`n## Selected Migration Unit`n`n| Migration Unit ID | Plan Reference | Approval Reference | Mode Constraint | Bootstrap Scope | Foundation Baseline ID | Foundation Baseline Reference | Foundation Baseline Approval Reference | Baseline Reference | Trace IDs |`n|---|---|---|---|---|---|---|---|---|---|`n| $Unit | legacy-plan.md@7 | approval:HUMAN-$Unit | incremental/preserve-existing | not-required | not-applicable | not-applicable | not-applicable | $baseline | TRACE-LEGACY-$Unit |`n`n## $FileChangesHeading`n`n| Migration Unit ID | File | Change | Trace IDs |`n|---|---|---|---|`n| $Unit | legacy/source.dart | historical migration | TRACE-LEGACY-$Unit |`n`n## $TraceHeading`n`n| Trace ID | Implementation Reference |`n|---|---|`n| TRACE-LEGACY-$Unit | legacy/source.dart |`n`n## $CommandsHeading`n`n| Command | Result | Evidence |`n|---|---|---|`n| test:legacy | PASS | evidence:legacy-$Unit |`n`n## $BlockerHeading`n`n| Stage / Check | Native Verdict | Command Role | Required Command Lifecycle | Command / Capability | Observed Error | Evidence Reference |`n|---|---|---|---|---|---|---|`n| not-applicable | not-applicable | not-applicable | not-applicable | not-applicable | not-applicable | not-applicable |`n`n## $EvidenceHeading`n`n| Evidence | Location | Notes |`n|---|---|---|`n| historical implementation | legacy/source.dart | approved |`n`n## $UnknownHeading`n`n- none`n`n## $ConclusionHeading`n`nready`n";Get-ImmutableReference $Run $Name}
function New-LegacyPlan([string]$Run){Write-Utf8 (Join-Path $Run 'legacy-plan.md') "---`nstep_id: 08-plan-waves`nstatus: approved`nresult: complete`napproval_source: human`nproduced_at: 2025-01-01`nrevision: 7`n---`n# Approved Legacy Plan`n`n## Migration Units`n`n| Migration Unit ID | Plan Reference | Approval Reference | Mode Constraint | Bootstrap Scope | Foundation Baseline ID | Foundation Baseline Reference | Foundation Baseline Approval Reference | Baseline Reference | Trace IDs |`n|---|---|---|---|---|---|---|---|---|---|`n| UNIT-A | legacy-plan.md@7 | approval:HUMAN-UNIT-A | incremental/preserve-existing | not-required | not-applicable | not-applicable | not-applicable | baseline:a | TRACE-LEGACY-UNIT-A |`n| UNIT-B | legacy-plan.md@7 | approval:HUMAN-UNIT-B | incremental/preserve-existing | not-required | not-applicable | not-applicable | not-applicable | baseline:b | TRACE-LEGACY-UNIT-B |`n"}
function New-PlannedTechnicalDesign([string]$Run, [string]$WorkItem) {
  $name = "technical-design-$($WorkItem.ToLowerInvariant()).md"
  $path = Join-Path $Run $name
  $responsibilityId = "RESP-$WorkItem"
  $verificationOwnerId = "VERIFY-OWNER-$WorkItem"
  $ownerSymbol = "$($WorkItem -replace '[^A-Za-z0-9_]', '')Owner"
  $text = @"
---
step_id: 07-technical-design
status: approved
result: complete
approval_source: human
produced_at: 2026-08-20
revision: DESIGN-E2E@1
work_item_id: $WorkItem
run_id: RUN-E2E-001
master_spec_ref: rendered-scope-run/master-spec.md
master_spec_id: SPEC-E2E-001
master_spec_revision: 1
master_plan_ref: rendered-scope-run/master-plan.md
master_plan_id: PLAN-E2E-001
master_plan_revision: 1
mode_constraint: incremental/preserve-existing
responsibility_contract:
  version: 1
  applicability: required
---
# Approved Technical Design

## Master Scope Context

| Run ID | Master Spec Reference | Master Spec ID | Master Spec Revision | Master Plan Reference | Master Plan ID | Master Plan Revision | Work Item ID |
|---|---|---|---|---|---|---|---|
| RUN-E2E-001 | rendered-scope-run/master-spec.md | SPEC-E2E-001 | 1 | rendered-scope-run/master-plan.md | PLAN-E2E-001 | 1 | $WorkItem |

## File Responsibility Matrix

| Responsibility ID | Owner Path | Owner Symbol | Boundary Kind | Primary Responsibility | Owned Capability IDs | Trace IDs | Atomic Boundary ID | Public Symbols | External Effects | Target Exemplar | Exemplar Classification | Classification Authority | Classification Evidence | Architecture Authority | Co-location Policy | Co-location Evidence | Verification Owner References | Conformance | Deviation Reference |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| $responsibilityId | src/$($WorkItem.ToLowerInvariant()).source | $ownerSymbol | application | implement $WorkItem | CAP-$WorkItem | TRACE-001; $WorkItem | not-applicable | $ownerSymbol | none | src/target.source#Target | preferred | factual-discovery-evidence | inspection:src/target.source#Target; working-evidence:test/$($WorkItem.ToLowerInvariant())_test.source#${ownerSymbol}Scenario | target-exemplar | feature-local | independently owned feature boundary | $verificationOwnerId | yes | not-applicable |

## Verification Ownership Matrix

| Verification Owner ID | Production Responsibility ID | Capability ID | Evidence Path | Evidence Symbol or Scenario | Evidence Kind | Verification Disposition | Production Binding Evidence | Decision Reference | Verdict | Deviation Reference |
|---|---|---|---|---|---|---|---|---|---|---|
| $verificationOwnerId | $responsibilityId | CAP-$WorkItem | test/$($WorkItem.ToLowerInvariant())_test.source | ${ownerSymbol}Scenario | production-composition | required | src/$($WorkItem.ToLowerInvariant()).source#$ownerSymbol | not-applicable | PASS | not-applicable |
"@
  Write-Utf8 $path $text
  Get-ImmutableReference $Run $name
}
function Render-CanonicalMaster([string]$FixtureRoot,[string]$Name,[string]$TerminalA){
  $text=Get-Content -Raw -Encoding utf8 (Join-Path $FixtureRoot "templates/migration/$Name")
  $text=[regex]::Replace($text,'<[^>\r\n]+>','sample-value')
  $replacements=[ordered]@{
    'SPEC-sample-value-sample-value'='SPEC-E2E-001';'PLAN-sample-value-sample-value'='PLAN-E2E-001';'WORK-sample-value-sample-value'='WORK-E2E-A';'REQ-###'='REQ-001';'SC-###'='SC-001';'TRACE-###'='TRACE-001';'UNK-###'='UNK-001';'ATTEMPT-sample-value-sample-value'='ATTEMPT-WORK-E2E-A-01';'revision: sample-value'='revision: 1';'master_spec_revision: sample-value'='master_spec_revision: 1';'requested_scope_kind: sample-value'='requested_scope_kind: module';'requested_scope_id: sample-value'='requested_scope_id: E2E';'status: sample-value'='status: approved';'result: sample-value'='result: complete';'approval_source: sample-value'='approval_source: human';'produced_at: sample-value'='produced_at: 2026-08-20';'max_concurrency: sample-value'='max_concurrency: 1';'plan_order: sample-value'='plan_order: 1';'| WORK-E2E-A | sample-value | sample-value | none | sample-value | sample-value | sample-value | none | in-progress | ATTEMPT-WORK-E2E-A-01 | none | pending |'="| WORK-E2E-A | Item A | yes | none | 1 | REQ-001; SC-001; measurable outcome | TRACE-001 | migration-unit:UNIT-A | complete | ATTEMPT-WORK-E2E-A-01 | $TerminalA | approval:HUMAN-WORK-A |";'| sample-value | sample-value | pending | sample-value |'='| human | approval:HUMAN-SCOPE-E2E | approved | 2026-08-20 |';'| sample-value | pending | sample-value |'='| approval:HUMAN-PLAN-E2E | approved | 2026-08-20 |';'| REQ-001 | sample-value | sample-value | sample-value |'='| REQ-001 | Stable requirement | source:ticket | measurable acceptance |';'| SC-001 | REQ-001 | sample-value |'='| SC-001 | REQ-001 | measurable outcome |';'| UNK-001 | sample-value | sample-value | sample-value |'='| UNK-001 | none identified | none | resolved |';'| TRACE-001 | sample-value | sample-value | sample-value |'='| TRACE-001 | requirement | source:ticket | trace note |';'| sample-value | sample-value | sample-value | user | sample-value |'='| module | E2E | Complete E2E module | user | conversation:scope-e2e |';'| WORK-E2E-A | none | no-dependency | sample-value |'='| WORK-E2E-A | none | no-dependency | decision:graph-e2e |';'| ATTEMPT-WORK-E2E-A-01 | WORK-E2E-A | sample-value | in-progress | sample-value |'="| ATTEMPT-WORK-E2E-A-01 | WORK-E2E-A | 1 | complete | $TerminalA |";'| WORK-E2E-A | ready | in-progress | ATTEMPT-WORK-E2E-A-01 | sample-value |'='| WORK-E2E-A | in-progress | complete | ATTEMPT-WORK-E2E-A-01 | 1 |';'| SPEC-E2E-001 | sample-value | not-applicable | sample-value | none | pending |'='| SPEC-E2E-001 | 1 | not-applicable | initial approved scope | none | approval:HUMAN-SCOPE-E2E |';'| PLAN-E2E-001 | sample-value | not-applicable | sample-value | none | pending |'='| PLAN-E2E-001 | 1 | not-applicable | initial approved plan | none | approval:HUMAN-PLAN-E2E |'
  }
  foreach($key in $replacements.Keys){$text=$text.Replace($key,$replacements[$key])}
  $text
}

function Invoke-FlexibleScope([string]$FixtureRoot, [string]$ManifestPath) {
  $prior = $ErrorActionPreference
  try {
    $ErrorActionPreference = 'Continue'
    $args=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$validatorPath,'-Target','FlexibleScope','-Root',$FixtureRoot);if(-not[string]::IsNullOrWhiteSpace($ManifestPath)){$args+=@('-FlexibleScopeFixturePath',$ManifestPath)}
    $output = & powershell.exe @args 2>&1
    [pscustomobject]@{ ExitCode=$LASTEXITCODE; Output=($output -join "`n") }
  }
  finally { $ErrorActionPreference = $prior }
}

function Assert-Outcome([object]$Result, [string]$Diagnostic, [string]$State, [string]$ScenarioId) {
  if ($Result.ExitCode -ne 0) { $failures.Add("$ScenarioId expected validator success but exited $($Result.ExitCode): $($Result.Output)"); return }
  if ($Result.Output -notmatch ('(?m)^DIAGNOSTIC: '+[regex]::Escape($Diagnostic)+'$')) { $failures.Add("$ScenarioId missing exact diagnostic $Diagnostic : $($Result.Output)") }
  if ($Result.Output -notmatch ('(?m)^SCOPE_STATE: '+[regex]::Escape($State)+'$')) { $failures.Add("$ScenarioId missing calculated state $State : $($Result.Output)") }
}

function Assert-Rejected([object]$Result, [string]$Diagnostic, [string]$ScenarioId) {
  if($Result.ExitCode -eq 0 -or $Result.Output -notmatch ('(?m)^DIAGNOSTIC: '+[regex]::Escape($Diagnostic)+'$') -or $Result.Output -notmatch '(?m)^SCOPE_STATE: scope-blocked$'){
    $failures.Add("$ScenarioId exact negative control $Diagnostic was not rejected: $($Result.Output)")
  }
}
function Assert-CanonicalRejected([object]$Result,[string]$ScenarioId){
  if($Result.ExitCode-eq0-or$Result.Output-notmatch'(?m)^FAIL: (master spec|master plan)'){$failures.Add("$ScenarioId canonical Task3 validation did not reject: $($Result.Output)")}
}
function Assert-CanonicalAccepted([object]$Result,[string]$ScenarioId){
  if($Result.Output-match'(?m)^FAIL: (master spec|master plan)'){$failures.Add("$ScenarioId canonical Task3 validation rejected: $($Result.Output)")}
}
function Assert-PredecessorReferenceRejected([object]$Result,[string]$ScenarioId){
  if($Result.ExitCode-eq0-or$Result.Output-notmatch'predecessor immutable reference (?:digest is stale|is malformed)'){$failures.Add("$ScenarioId invalid immutable predecessor reference was not rejected: $($Result.Output)")}
}
function Assert-Observed([object]$Result,[string]$Diagnostic,[string]$State,[string]$ScenarioId){
  if($Result.Output-notmatch('(?m)^DIAGNOSTIC: '+[regex]::Escape($Diagnostic)+'$')-or$Result.Output-notmatch('(?m)^SCOPE_STATE: '+[regex]::Escape($State)+'$')){$failures.Add("$ScenarioId did not calculate $Diagnostic/$State : $($Result.Output)")}
}

function New-RenderedFixture([string]$FixtureRoot, [object]$Scenario) {
  $run = Join-Path $FixtureRoot 'rendered-scope-run'
  New-Item -ItemType Directory -Path $run -Force | Out-Null
  New-LegacyPlan $run
  $technicalDesignRefs = @(
    New-PlannedTechnicalDesign $run 'WORK-E2E-A'
    New-PlannedTechnicalDesign $run 'WORK-E2E-B'
  )
  $adapterKindA=if($Scenario.Id-ceq'S05'){'none'}else{'migration-unit'}
  $reviewA=New-ResponsibilityReviewEvidence $run 'review-a.md' 'WORK-E2E-A' 'incremental/preserve-existing' $adapterKindA
  $reviewB=New-ResponsibilityReviewEvidence $run 'review-b.md' 'WORK-E2E-B'
  $verificationA=New-ResponsibilityDownstreamArtifact $run 'verification-a.md' 'WORK-E2E-A' '12-verification-testing' 'review-report.md' 'incremental/preserve-existing' $adapterKindA
  $parityA=New-ResponsibilityDownstreamArtifact $run 'parity-a.md' 'WORK-E2E-A' '13-verify-parity' 'verification-report.md' 'incremental/preserve-existing' $adapterKindA
  $regressionA=New-ResponsibilityDownstreamArtifact $run 'regression-a.md' 'WORK-E2E-A' '14-verify-regression' '13-parity-report.md' 'incremental/preserve-existing' $adapterKindA
  $knowledgeA=New-ResponsibilityDownstreamArtifact $run 'knowledge-a.md' 'WORK-E2E-A' '15-knowledge-base' '14-regression-report.md' 'incremental/preserve-existing' $adapterKindA
  $greenfieldReviewA=New-ResponsibilityReviewEvidence $run 'review-greenfield-a.md' 'WORK-E2E-A' 'greenfield/design-new' $adapterKindA
  $greenfieldVerificationA=New-ResponsibilityDownstreamArtifact $run 'verification-greenfield-a.md' 'WORK-E2E-A' '12-verification-testing' 'review-report.md' 'greenfield/design-new' $adapterKindA
  $greenfieldParityA=New-ResponsibilityDownstreamArtifact $run 'parity-greenfield-a.md' 'WORK-E2E-A' '13-verify-parity' 'verification-report.md' 'greenfield/design-new' $adapterKindA
  $greenfieldKnowledgeA=New-ResponsibilityDownstreamArtifact $run 'knowledge-greenfield-a.md' 'WORK-E2E-A' '15-knowledge-base' '13-parity-report.md' 'greenfield/design-new' $adapterKindA
  $verificationB=New-ResponsibilityDownstreamArtifact $run 'verification-b.md' 'WORK-E2E-B' '12-verification-testing' 'review-report.md'
  $parityB=New-ResponsibilityDownstreamArtifact $run 'parity-b.md' 'WORK-E2E-B' '13-verify-parity' 'verification-report.md'
  $regressionB=New-ResponsibilityDownstreamArtifact $run 'regression-b.md' 'WORK-E2E-B' '14-verify-regression' '13-parity-report.md'
  $knowledgeB=New-ResponsibilityDownstreamArtifact $run 'knowledge-b.md' 'WORK-E2E-B' '15-knowledge-base' '14-regression-report.md'
  $greenfieldReviewB=New-ResponsibilityReviewEvidence $run 'review-greenfield-b.md' 'WORK-E2E-B' 'greenfield/design-new'
  $greenfieldVerificationB=New-ResponsibilityDownstreamArtifact $run 'verification-greenfield-b.md' 'WORK-E2E-B' '12-verification-testing' 'review-report.md' 'greenfield/design-new'
  $greenfieldParityB=New-ResponsibilityDownstreamArtifact $run 'parity-greenfield-b.md' 'WORK-E2E-B' '13-verify-parity' 'verification-report.md' 'greenfield/design-new'
  $greenfieldKnowledgeB=New-ResponsibilityDownstreamArtifact $run 'knowledge-greenfield-b.md' 'WORK-E2E-B' '15-knowledge-base' '13-parity-report.md' 'greenfield/design-new'
  $responsibilityChains=@(
    [ordered]@{work_item_id='WORK-E2E-A';artifact_refs=@($reviewA,$verificationA,$parityA,$regressionA,$knowledgeA)},
    [ordered]@{work_item_id='WORK-E2E-B';artifact_refs=@($reviewB,$verificationB,$parityB,$regressionB,$knowledgeB)}
  )
  $greenfieldResponsibilityChains=@(
    [ordered]@{work_item_id='WORK-E2E-A';artifact_refs=@($greenfieldReviewA,$greenfieldVerificationA,$greenfieldParityA,$greenfieldKnowledgeA)},
    [ordered]@{work_item_id='WORK-E2E-B';artifact_refs=@($greenfieldReviewB,$greenfieldVerificationB,$greenfieldParityB,$greenfieldKnowledgeB)}
  )
  if($Scenario.Id-ceq'S05'){$responsibilityChains=@($responsibilityChains[0])}
  $sourceDiffA='source-diff:1111111111111111111111111111111111111111..2222222222222222222222222222222222222222#WORK-E2E-A'
  $sourceDiffB='source-diff:1111111111111111111111111111111111111111..2222222222222222222222222222222222222222#WORK-E2E-B'
  $terminalA=New-Evidence $run 'terminal-a.md' 'WORK-E2E-A' $adapterKindA
  $terminalB=New-Evidence $run 'terminal-b.md' 'WORK-E2E-B'
  $terminalA=Add-ResponsibilityHandoff $run 'terminal-a.md' 'WORK-E2E-A' $knowledgeA
  $terminalB=Add-ResponsibilityHandoff $run 'terminal-b.md' 'WORK-E2E-B' $knowledgeB
  $historicalA=New-HistoricalEvidence $run 'historical-a.md' 'UNIT-A'
  $historicalB=New-HistoricalEvidence $run 'historical-b.md' 'UNIT-B'
  $spec = @'
---
artifact_type: migration-master-spec
master_spec_id: SPEC-E2E-001
revision: 1
status: approved
result: complete
approval_source: human
requested_scope_kind: module
requested_scope_id: E2E
produced_at: 2026-08-20
supersedes: not-applicable
---
# Master Specification

Approved scope for the isolated rendered scenario.
'@
  $plan = (@'
---
artifact_type: migration-master-plan
master_plan_id: PLAN-E2E-001
master_spec_id: SPEC-E2E-001
master_spec_revision: 1
revision: 1
status: approved
scope_status: planned
execution_policy: dependency-ready
max_concurrency: 1
produced_at: 2026-08-20
supersedes: not-applicable
---
# Master Plan

## Work Items

| Work Item ID | Title | Required | Dependencies | Plan Order | Acceptance | Trace IDs | Delivery Adapter | Status | Latest Attempt | Terminal Evidence | Approval Reference |
|---|---|---|---|---|---|---|---|---|---|---|---|
| WORK-E2E-A | Item A | yes | none | 1 | REQ-001; SC-001 | TRACE-001 | migration-unit:UNIT-A | complete | ATTEMPT-A-01 | __TERMINAL_A__ | approval:HUMAN-WORK-A |
| WORK-E2E-B | Item B | no | WORK-E2E-A | 2 | REQ-001; SC-001 | TRACE-001 | migration-unit:UNIT-B | complete | ATTEMPT-B-01 | __TERMINAL_B__ | approval:HUMAN-WORK-B |

## Delivery Adapter Selection

| Work Item ID | Adapter Kind | External ID | Authority | Authority Revision | Approval Reference | Parent Selector | Acceptance | Trace IDs | Mode Constraint | Design Revision | Parent Work Item ID | Decomposition Decision Reference |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| WORK-E2E-A | migration-unit | UNIT-A | legacy-plan.md | 7 | approval:HUMAN-UNIT-A | not-applicable | REQ-001; SC-001 | TRACE-001 | incremental/preserve-existing | DESIGN-E2E@1 | not-applicable | not-applicable |
| WORK-E2E-B | migration-unit | UNIT-B | legacy-plan.md | 7 | approval:HUMAN-UNIT-B | not-applicable | REQ-001; SC-001 | TRACE-001 | incremental/preserve-existing | DESIGN-E2E@1 | not-applicable | not-applicable |
'@).Replace('__TERMINAL_A__',$terminalA).Replace('__TERMINAL_B__',$terminalB)
  $predecessor = @"
---
step_id: 08-plan-waves
status: draft
result: complete
approval_source: human
produced_at: 2026-08-20
revision: 1
---
# Immediate Predecessor

## Master Scope Context

| Run ID | Master Spec Reference | Master Spec ID | Master Spec Revision | Master Plan Reference | Master Plan ID | Master Plan Revision |
|---|---|---|---|---|---|---|
| RUN-E2E-001 | rendered-scope-run/master-spec.md | SPEC-E2E-001 | 1 | rendered-scope-run/master-plan.md | PLAN-E2E-001 | 1 |

## Activation Slice

| Activation Slice ID | Applicability | Seam | Input | Output | Source Reference | Trace IDs | Disposition | Status | Decision Reference | Deferred Unit ID |
|---|---|---|---|---|---|---|---|---|---|---|
| ACT-001 | applicable | upstream-response | upstream input | upstream output | evidence:upstream | TRACE-001 | implement | verified | not-applicable | not-applicable |
| ACT-001 | applicable | requested-key | key input | key output | evidence:key | TRACE-002 | implement | verified | not-applicable | not-applicable |
| ACT-001 | applicable | parse-model | model input | model output | evidence:model | TRACE-001 | implement | verified | not-applicable | not-applicable |
| ACT-001 | applicable | state-holder | state input | state output | evidence:state | TRACE-002 | deferred-approved | verified | approval:DEFER-ACT-001 | UNIT-003 |
| ACT-001 | applicable | selector | selector input | selector output | evidence:selector | TRACE-001 | reuse | verified | not-applicable | not-applicable |
| ACT-001 | applicable | construct | construct input | policy=compatibility-dual-path | evidence:construct; compatibility-reason=legacy-route; router-owner=router-team | TRACE-001; PARITY-001 | implement | verified | approval:ROUTER-ACT-001 | not-applicable |
| ACT-001 | applicable | render | render input | render output | evidence:render | TRACE-002 | implement | verified | not-applicable | not-applicable |
| ACT-001 | applicable | downstream-consumer | consumer input | consumer output | evidence:consumer | TRACE-001 | implement | verified | not-applicable | not-applicable |
| ACT-001 | applicable | test | test input | test output | evidence:test | PARITY-001 | implement | verified | not-applicable | not-applicable |
| ACT-002 | not-applicable-approved | upstream-response | no-selector input | no-selector output | evidence:na-upstream | TRACE-002 | not-applicable-approved | verified | approval:NA-ACT-002 | not-applicable |
| ACT-002 | not-applicable-approved | requested-key | no-selector input | no-selector output | evidence:na-key | TRACE-002 | not-applicable-approved | verified | approval:NA-ACT-002 | not-applicable |
| ACT-002 | not-applicable-approved | parse-model | no-selector input | no-selector output | evidence:na-model | TRACE-002 | not-applicable-approved | verified | approval:NA-ACT-002 | not-applicable |
| ACT-002 | not-applicable-approved | state-holder | no-selector input | no-selector output | evidence:na-state | TRACE-002 | not-applicable-approved | verified | approval:NA-ACT-002 | not-applicable |
| ACT-002 | not-applicable-approved | selector | no-selector input | no-selector output | evidence:na-selector | TRACE-002 | not-applicable-approved | verified | approval:NA-ACT-002 | not-applicable |
| ACT-002 | not-applicable-approved | construct | no-selector input | no-selector output | evidence:na-construct | TRACE-002 | not-applicable-approved | verified | approval:NA-ACT-002 | not-applicable |
| ACT-002 | not-applicable-approved | render | no-selector input | no-selector output | evidence:na-render | TRACE-002 | not-applicable-approved | verified | approval:NA-ACT-002 | not-applicable |
| ACT-002 | not-applicable-approved | downstream-consumer | no-selector input | no-selector output | evidence:na-consumer | TRACE-002 | not-applicable-approved | verified | approval:NA-ACT-002 | not-applicable |
| ACT-002 | not-applicable-approved | test | no-selector input | no-selector output | evidence:na-test | TRACE-002 | not-applicable-approved | verified | approval:NA-ACT-002 | not-applicable |
"@
  $target = @'
---
artifact_type: migration-target-evidence
selector_state: internal
decomposition_trace: complete
exemplar_state: complete
design_state: precise
wrapper_state: matched
tree_state: matched
matrix_state: present
subscription_key_state: present
runtime_evidence_state: PASS
architecture_conformance_state: PASS
selector_schema_state: PASS
selection_test: no
note: baseline
---
# Target and Design Evidence
'@
  $spec=Render-CanonicalMaster $FixtureRoot 'master-spec.md' $terminalA
  $plan=Render-CanonicalMaster $FixtureRoot 'master-plan.md' $terminalA
  $selectorRowPattern='(?m)^\| WORK-E2E-A \| none \| not-applicable \| not-applicable \| not-applicable \| not-applicable \| not-applicable \| sample-value \| sample-value \| sample-value \| sample-value \| not-applicable \| not-applicable \|(?=(?<selectorEol>\r?\n))'
  $selectorRowA=if($adapterKindA-ceq'migration-unit'){'| WORK-E2E-A | migration-unit | UNIT-A | legacy-plan.md | 7 | approval:HUMAN-UNIT-A | not-applicable | REQ-001; SC-001; measurable outcome | TRACE-001 | incremental/preserve-existing | DESIGN-E2E@1 | not-applicable | not-applicable |'}else{'| WORK-E2E-A | none | not-applicable | not-applicable | not-applicable | not-applicable | not-applicable | REQ-001; SC-001; measurable outcome | TRACE-001 | incremental/preserve-existing | DESIGN-E2E@1 | not-applicable | not-applicable |'}
  $selectorRows=$selectorRowA+'${selectorEol}'+'| WORK-E2E-B | migration-unit | UNIT-B | legacy-plan.md | 7 | approval:HUMAN-UNIT-B | not-applicable | REQ-001; SC-001; measurable outcome | TRACE-001 | incremental/preserve-existing | DESIGN-E2E@1 | not-applicable | not-applicable |'
  $selectorRowRegex=[regex]::new($selectorRowPattern)
  $selectorRowMatchCount=$selectorRowRegex.Matches($plan).Count
  if($selectorRowMatchCount-ne1){throw "Canonical master plan selector row seam expected exactly one match; found $selectorRowMatchCount"}
  $renderedSelectorPlan=$selectorRowRegex.Replace($plan,$selectorRows,1)
  if($renderedSelectorPlan-ceq$plan){throw 'Canonical master plan selector row seam was not rendered'}
  $plan=$renderedSelectorPlan
  $ownerRowPattern='| WORK-E2E-A | sample-value | sample-value | sample-value | sample-value | sample-value |'
  $ownerRows="| WORK-E2E-A | DESIGN-E2E@1 | RESP-WORK-E2E-A | not-applicable | not-applicable | approval:OWNER-WORK-E2E-A: independently implementable, reviewable, verifiable, and revertible |`n| WORK-E2E-B | DESIGN-E2E@1 | RESP-WORK-E2E-B | not-applicable | not-applicable | docs/architecture.md#DECISION-WORK-E2E-B: independently implementable, reviewable, testable, and revertible |"
  $renderedOwnerPlan=$plan.Replace($ownerRowPattern,$ownerRows)
  if($renderedOwnerPlan-ceq$plan){throw 'Canonical master plan responsibility-owner row seam was not rendered'}
  $plan=$renderedOwnerPlan
  $canonicalBaseA="| WORK-E2E-A | Item A | yes | none | 1 | REQ-001; SC-001; measurable outcome | TRACE-001 | migration-unit:UNIT-A | complete | ATTEMPT-WORK-E2E-A-01 | $terminalA | approval:HUMAN-WORK-A |"
  $baseA=if($adapterKindA-ceq'migration-unit'){$canonicalBaseA}else{"| WORK-E2E-A | Item A | yes | none | 1 | REQ-001; SC-001; measurable outcome | TRACE-001 | none | complete | ATTEMPT-WORK-E2E-A-01 | $terminalA | approval:HUMAN-WORK-A |"}
  if($baseA-cne$canonicalBaseA){$plan=$plan.Replace($canonicalBaseA,$baseA);if(-not$plan.Contains($baseA)){throw 'Generic Work Item A adapter seam was not rendered'}}
  $baseB="| WORK-E2E-B | Item B | no | WORK-E2E-A | 2 | REQ-001; SC-001; measurable outcome | TRACE-001 | migration-unit:UNIT-B | complete | ATTEMPT-WORK-E2E-B-01 | $terminalB | approval:HUMAN-WORK-B |"
  $plan=$plan.Replace($baseA,"$baseA`n$baseB").Replace('| WORK-E2E-A | none | no-dependency | decision:graph-e2e |',"| WORK-E2E-A | none | no-dependency | decision:graph-e2e |`n| WORK-E2E-B | WORK-E2E-A | depends-on | decision:graph-e2e |").Replace("| ATTEMPT-WORK-E2E-A-01 | WORK-E2E-A | 1 | complete | $terminalA |","| ATTEMPT-WORK-E2E-A-01 | WORK-E2E-A | 1 | complete | $terminalA |`n| ATTEMPT-WORK-E2E-B-01 | WORK-E2E-B | 1 | complete | $terminalB |").Replace('| WORK-E2E-A | in-progress | complete | ATTEMPT-WORK-E2E-A-01 | 1 |',"| WORK-E2E-A | ready | in-progress | ATTEMPT-WORK-E2E-A-01 | 1 |`n| WORK-E2E-A | in-progress | complete | $terminalA | 1 |`n| WORK-E2E-B | ready | in-progress | ATTEMPT-WORK-E2E-B-01 | 1 |`n| WORK-E2E-B | in-progress | complete | $terminalB | 1 |")
  Write-Utf8 (Join-Path $run 'master-spec.md') $spec
  Write-Utf8 (Join-Path $run 'master-plan.md') $plan
  Write-Utf8 (Join-Path $run 'predecessor.md') $predecessor
  $predecessorRef=Get-ImmutableReference $run 'predecessor.md'
  Write-Utf8 (Join-Path $run 'target-evidence.md') $target

  $legacyRef='not-applicable'; $terminalRef='not-applicable'
  if ($Scenario.Id -ceq 'S19') {
    $legacyRef='rendered-scope-run/legacy-conversion.md'
    $legacy=(@'
---
artifact_type: migration-legacy-conversion
status: approved
master_spec_revision: 1
master_plan_revision: 1
scope_status: planned
---
# Legacy Conversion

## Approved Historical Units

| Legacy Unit ID | Legacy Schema Version | Approval | Historical Evidence | Evidence Valid |
|---|---|---|---|---|
| UNIT-A | implementation-report@9bfed5b148eb07a284f567bcd7486c9a00318a50#gitblob:15299bfe69780430508cf9527fcfe14d1d216748 | approval:HIST-UNIT-A | __HISTORICAL_A__ | yes |
| UNIT-B | implementation-report@9bfed5b148eb07a284f567bcd7486c9a00318a50#gitblob:15299bfe69780430508cf9527fcfe14d1d216748 | approval:HIST-UNIT-B | __HISTORICAL_B__ | yes |

## Legacy Unit Conversion

| Legacy Unit ID | Work Item ID | Delivery Adapter | Historical Evidence | Evidence Valid | Fresh Approval |
|---|---|---|---|---|---|
| UNIT-A | WORK-E2E-A | migration-unit:UNIT-A | __HISTORICAL_A__ | yes | approval:AUTO-LEGACY-1 |
| UNIT-B | WORK-E2E-B | migration-unit:UNIT-B | __HISTORICAL_B__ | yes | approval:HUMAN-LEGACY-2 |
'@).Replace('__HISTORICAL_A__',$historicalA).Replace('__HISTORICAL_B__',$historicalB)
    Write-Utf8 (Join-Path $run 'legacy-conversion.md') $legacy
  }
  if ($Scenario.Id -in @('S05','S20')) {
    $terminalRef='rendered-scope-run/scope-terminal-report.md'
    $terminalReport=(@'
---
artifact_type: migration-scope-terminal-report
master_spec_id: SPEC-E2E-001
master_spec_revision: 1
master_plan_id: PLAN-E2E-001
master_plan_revision: 1
status: approved
result: complete
approval_source: human
scope_status: scope-in-progress
produced_at: 2026-08-20
---
# Terminal Scope Report

## Master Revision Context

| Master Spec Reference | Master Spec Revision | Master Plan Reference | Master Plan Revision | Terminal Report Reference |
|---|---|---|---|---|
| master-spec.md | 1 | master-plan.md | 1 | scope-terminal-report.md |

## Work Item Terminal Evidence

| Work Item ID | Required | Status | Terminal Evidence | Runtime Evidence State | Architecture Conformance State | Selector Schema State | Blocker | Plan Revision |
|---|---|---|---|---|---|---|---|---|
| WORK-E2E-A | yes | complete | __TERMINAL_A__ | PASS | PASS | PASS | none | 1 |
| WORK-E2E-B | no | complete | __TERMINAL_B__ | PASS | PASS | PASS | none | 1 |

## Scope Completion Calculation

| Graph State | Required Items | Required Terminal Evidence | Tree Conformance | Responsibility Conformance | Verification Ownership | Architecture State | Selector Schema State | Remaining Blockers | Calculated Terminal Verdict |
|---|---|---|---|---|---|---|---|---|---|
| valid | all-terminal-success | all-required-terminal-evidence | PASS | PASS | PASS | PASS | PASS | none | scope-complete |

## Architecture Responsibility Handoff

| Responsibility Contract Version | Tree Conformance | Responsibility Conformance | Verification Ownership | Architecture Conformance State | Evidence References |
|---|---|---|---|---|---|
| 1 | PASS | PASS | PASS | PASS | __RESPONSIBILITY_SOURCE_DIFFS__ |

## Evidence Index

| Evidence ID | Artifact Reference | Work Item ID | Purpose |
|---|---|---|---|
| EVIDENCE-A | __RESPONSIBILITY_A__ | WORK-E2E-A | architecture-responsibility-sub-verdicts |
| EVIDENCE-B | __RESPONSIBILITY_B__ | WORK-E2E-B | architecture-responsibility-sub-verdicts |

## Blockers and Dispositions

| Work Item ID | Blocker | Disposition | Decision Reference |
|---|---|---|---|
| WORK-E2E-A | none | not-applicable | not-applicable |
| WORK-E2E-B | none | not-applicable | not-applicable |

## Approval Record

| Decision | Approver | Evidence | Decided At |
|---|---|---|---|
| approved | human | approval:HUMAN-SCOPE-1 | 2026-08-20 |

## Revision History

| Artifact ID | Revision | Supersedes | Change Summary | Affected Work Items | Approval Reference |
|---|---|---|---|---|---|
| REPORT-E2E-001 | 1 | not-applicable | initial terminal calculation | all | approval:HUMAN-SCOPE-1 |
'@).Replace('__TERMINAL_A__',$terminalA).Replace('__TERMINAL_B__',$terminalB).Replace('__RESPONSIBILITY_A__',$knowledgeA).Replace('__RESPONSIBILITY_B__',$knowledgeB).Replace('__RESPONSIBILITY_SOURCE_DIFFS__',"$sourceDiffA; $sourceDiffB")
    if($Scenario.Id-ceq'S05'){
      $terminalReport=$terminalReport.Replace('| WORK-E2E-B | no | complete | '+$terminalB+' | PASS | PASS | PASS | none | 1 |','| WORK-E2E-B | yes | pending | none | PASS | PASS | PASS | none | 1 |').Replace("| EVIDENCE-B | $knowledgeB | WORK-E2E-B | architecture-responsibility-sub-verdicts |",'').Replace("$sourceDiffA; $sourceDiffB",$sourceDiffA).Replace('| valid | all-terminal-success | all-required-terminal-evidence | PASS | PASS | PASS | PASS | PASS | none | scope-complete |','| valid | required-work-remains | partial | PASS | PASS | PASS | PASS | PASS | none | scope-in-progress |')
    }
    if($Scenario.Id-ceq'S07'){
      $terminalReport=$terminalReport.Replace('scope_status: scope-in-progress','scope_status: scope-blocked').Replace('| WORK-E2E-A | yes | complete | '+$terminalA+' | PASS | PASS | PASS | none | 1 |','| WORK-E2E-A | yes | blocked | none | PASS | PASS | PASS | hard-blocker | 1 |').Replace('| EVIDENCE-A | '+$knowledgeA+' | WORK-E2E-A |','| EVIDENCE-A | none | WORK-E2E-A |').Replace('| WORK-E2E-A | none | not-applicable | not-applicable |','| WORK-E2E-A | hard-blocker | pending | not-applicable |').Replace('| valid | all-terminal-success | all-required-terminal-evidence | PASS | PASS | none | scope-complete |','| valid | required-work-blocked | partial | PASS | PASS | hard-blocker | scope-blocked |')
    }
    Write-Utf8 (Join-Path $run 'scope-terminal-report.md') $terminalReport
  }
  $manifest = [ordered]@{
    expected_diagnostic=$Scenario.Diagnostic
    expected_scope_state=$Scenario.State
    legacy_conversion_ref=$legacyRef
    master_plan_ref='rendered-scope-run/master-plan.md'
    master_spec_ref='rendered-scope-run/master-spec.md'
    predecessor_ref=$predecessorRef
    responsibility_chain_refs=$responsibilityChains
    scenario_id=$Scenario.Id
    target_evidence_ref='rendered-scope-run/target-evidence.md'
    technical_design_refs=$technicalDesignRefs
    terminal_report_ref=$terminalRef
  }
  $manifestPath=Join-Path $run 'scenario.json'
  Write-Utf8 $manifestPath ($manifest | ConvertTo-Json -Depth 4)
  [pscustomobject]@{ Run=$run; Manifest=$manifestPath; Predecessor=$predecessorRef; TechnicalDesignRefs=$technicalDesignRefs; ReviewA=$reviewA; ReviewB=$reviewB; TerminalA=$terminalA; TerminalB=$terminalB; HistoricalA=$historicalA; HistoricalB=$historicalB; ResponsibilityChains=$responsibilityChains; GreenfieldResponsibilityChains=$greenfieldResponsibilityChains; GreenfieldKnowledgeA=$greenfieldKnowledgeA; GreenfieldKnowledgeB=$greenfieldKnowledgeB; SourceDiffA=$sourceDiffA; SourceDiffB=$sourceDiffB }
}

function Assert-CanonicalSelectorRowRenderingPreservesEol([string]$SourceRoot) {
  $scenario=[pscustomobject]@{Id='S01';Name='selector row EOL regression';Diagnostic='scope-ready';State='planned'}
  $selectorPlaceholder='| WORK-E2E-A | none | not-applicable | not-applicable | not-applicable | not-applicable | not-applicable | sample-value | sample-value | sample-value | sample-value | not-applicable | not-applicable |'
  $selectorRowA='| WORK-E2E-A | migration-unit | UNIT-A | legacy-plan.md | 7 | approval:HUMAN-UNIT-A | not-applicable | REQ-001; SC-001; measurable outcome | TRACE-001 | incremental/preserve-existing | DESIGN-E2E@1 | not-applicable | not-applicable |'
  $selectorRowB='| WORK-E2E-B | migration-unit | UNIT-B | legacy-plan.md | 7 | approval:HUMAN-UNIT-B | not-applicable | REQ-001; SC-001; measurable outcome | TRACE-001 | incremental/preserve-existing | DESIGN-E2E@1 | not-applicable | not-applicable |'
  $eolCases=@(
    [pscustomobject]@{Name='LF';Value="`n"},
    [pscustomobject]@{Name='CRLF';Value="`r`n"}
  )
  foreach($eolCase in $eolCases){
    $fixtureRoot=New-IsolatedAitoolkitFixture -SourceRoot $SourceRoot
    try {
      $templatePath=Join-Path $fixtureRoot 'templates/migration/master-plan.md'
      $template=Get-Content -Raw -Encoding utf8 -LiteralPath $templatePath
      Write-Utf8 $templatePath ([regex]::Replace($template,'\r\n?|\n',$eolCase.Value))
      try {$rendered=New-RenderedFixture $fixtureRoot $scenario}
      catch {throw "Canonical selector row transform did not render $($eolCase.Name) input: $($_.Exception.Message)"}
      $plan=Get-Content -Raw -Encoding utf8 -LiteralPath (Join-Path $rendered.Run 'master-plan.md')
      if($plan.Contains($selectorPlaceholder)){throw "Canonical selector row transform did not alter $($eolCase.Name) input"}
      $expected="$selectorRowA$($eolCase.Value)$selectorRowB$($eolCase.Value)"
      if(-not$plan.Contains($expected)){throw "Canonical selector row transform did not preserve $($eolCase.Name) bytes"}
    }
    finally {Remove-IsolatedAitoolkitFixture -FixtureRoot $fixtureRoot}
  }
  $acceptedInvalidCases=[Collections.Generic.List[string]]::new()
  foreach($invalidCase in @('duplicate','wrong-case')){
    $fixtureRoot=New-IsolatedAitoolkitFixture -SourceRoot $SourceRoot
    try {
      $templatePath=Join-Path $fixtureRoot 'templates/migration/master-plan.md'
      $template=[regex]::Replace((Get-Content -Raw -Encoding utf8 -LiteralPath $templatePath),'\r\n?|\n',"`n")
      $rawSelectorRows=@([regex]::Split($template,"`n")|Where-Object{$_.StartsWith('| WORK-<SCOPE>-<NAME> | none | not-applicable | not-applicable |',[StringComparison]::Ordinal)})
      if($rawSelectorRows.Count-ne1){throw "Selector row regression fixture expected one source row; found $($rawSelectorRows.Count)"}
      $rawSelectorRow=$rawSelectorRows[0]
      $invalidSelectorRow=if($invalidCase-ceq'duplicate'){"$rawSelectorRow`n$rawSelectorRow"}else{$rawSelectorRow.Replace(' | none |',' | NONE |')}
      $mutatedTemplate=$template.Replace($rawSelectorRow,$invalidSelectorRow)
      if($mutatedTemplate-ceq$template){throw "Selector row regression fixture did not apply $invalidCase mutation"}
      Write-Utf8 $templatePath $mutatedTemplate
      $rejected=$false
      try {[void](New-RenderedFixture $fixtureRoot $scenario)}
      catch {
        if($_.Exception.Message-notmatch'^Canonical master plan selector row seam') {throw}
        $rejected=$true
      }
      if(-not$rejected){$acceptedInvalidCases.Add($invalidCase)}
    }
    finally {Remove-IsolatedAitoolkitFixture -FixtureRoot $fixtureRoot}
  }
  if($acceptedInvalidCases.Count-gt0){throw "Canonical selector row transform accepted invalid input: $($acceptedInvalidCases -join ', ')"}
}

function Apply-ScenarioMutation([object]$Rendered, [object]$Scenario) {
  $pre=Join-Path $Rendered.Run 'predecessor.md'; $spec=Join-Path $Rendered.Run 'master-spec.md'; $plan=Join-Path $Rendered.Run 'master-plan.md'; $target=Join-Path $Rendered.Run 'target-evidence.md'
  $rowA="| WORK-E2E-A | Item A | yes | none | 1 | REQ-001; SC-001; measurable outcome | TRACE-001 | migration-unit:UNIT-A | complete | ATTEMPT-WORK-E2E-A-01 | $($Rendered.TerminalA) | approval:HUMAN-WORK-A |"
  $rowB="| WORK-E2E-B | Item B | no | WORK-E2E-A | 2 | REQ-001; SC-001; measurable outcome | TRACE-001 | migration-unit:UNIT-B | complete | ATTEMPT-WORK-E2E-B-01 | $($Rendered.TerminalB) | approval:HUMAN-WORK-B |"
  switch ($Scenario.Id) {
    'S02' { Replace-Exact $spec 'requested_scope_kind: module' 'requested_scope_kind: explicit-item' $Scenario.Id;Replace-Exact $spec '| module | E2E | Complete E2E module | user | conversation:scope-e2e |' '| explicit-item | E2E | Complete E2E module | user | conversation:scope-e2e |' $Scenario.Id;Replace-Exact $plan '| module | E2E | Complete E2E module | user | conversation:scope-e2e |' '| explicit-item | E2E | Complete E2E module | user | conversation:scope-e2e |' $Scenario.Id }
    'S03' { Replace-Exact $spec 'requested_scope_kind: module' 'requested_scope_kind: unresolved' $Scenario.Id;Replace-Exact $spec '| module | E2E | Complete E2E module | user | conversation:scope-e2e |' '| unresolved | E2E | Complete E2E module | user | conversation:scope-e2e |' $Scenario.Id;Replace-Exact $plan '| module | E2E | Complete E2E module | user | conversation:scope-e2e |' '| unresolved | E2E | Complete E2E module | user | conversation:scope-e2e |' $Scenario.Id }
    'S04' {
      Replace-Exact $plan 'migration-unit:UNIT-A' 'generic:module-foundation' $Scenario.Id
      Replace-Exact $plan '| WORK-E2E-A | migration-unit | UNIT-A | legacy-plan.md | 7 | approval:HUMAN-UNIT-A | not-applicable | REQ-001; SC-001; measurable outcome | TRACE-001 | incremental/preserve-existing | DESIGN-E2E@1 | not-applicable | not-applicable |' '| WORK-E2E-A | none | not-applicable | not-applicable | not-applicable | not-applicable | not-applicable | REQ-001; SC-001; measurable outcome | TRACE-001 | incremental/preserve-existing | DESIGN-E2E@1 | not-applicable | not-applicable |' "$($Scenario.Id)-selector"
    }
    'S05' { Replace-Exact $plan $rowB '| WORK-E2E-B | Item B | yes | WORK-E2E-A | 2 | REQ-001; SC-001; measurable outcome | TRACE-001 | migration-unit:UNIT-B | pending | none | none | approval:HUMAN-WORK-B |' $Scenario.Id;Replace-Exact $plan "| ATTEMPT-WORK-E2E-B-01 | WORK-E2E-B | 1 | complete | $($Rendered.TerminalB) |" '' $Scenario.Id;Replace-Exact $plan "| WORK-E2E-B | ready | in-progress | ATTEMPT-WORK-E2E-B-01 | 1 |`n| WORK-E2E-B | in-progress | complete | $($Rendered.TerminalB) | 1 |" '' $Scenario.Id }
    'S06' {
      $new="| WORK-E2E-B | Item B | yes | WORK-E2E-A | 2 | REQ-001; SC-001; measurable outcome | TRACE-001 | migration-unit:UNIT-B | ready | none | none | approval:HUMAN-WORK-B |`n| WORK-E2E-E | Item E | yes | none | 3 | REQ-001; SC-001; measurable outcome | TRACE-001 | none | ready | none | none | pending |`n| WORK-E2E-D | Item D | no | none | 11 | REQ-001; SC-001; measurable outcome | TRACE-001 | none | ready | none | none | approval:HUMAN-WORK-D |`n| WORK-E2E-C | Item C | no | none | 10 | REQ-001; SC-001; measurable outcome | TRACE-001 | none | ready | none | none | approval:HUMAN-WORK-C |"
      Replace-Exact $plan $rowB $new $Scenario.Id
      Replace-Exact $plan '| WORK-E2E-B | migration-unit | UNIT-B | legacy-plan.md | 7 | approval:HUMAN-UNIT-B | not-applicable | REQ-001; SC-001; measurable outcome | TRACE-001 | incremental/preserve-existing | DESIGN-E2E@1 | not-applicable | not-applicable |' "| WORK-E2E-B | migration-unit | UNIT-B | legacy-plan.md | 7 | approval:HUMAN-UNIT-B | not-applicable | REQ-001; SC-001; measurable outcome | TRACE-001 | incremental/preserve-existing | DESIGN-E2E@1 | not-applicable | not-applicable |`n| WORK-E2E-E | none | not-applicable | not-applicable | not-applicable | not-applicable | not-applicable | REQ-001; SC-001; measurable outcome | TRACE-001 | incremental/preserve-existing | DESIGN-E2E@1 | not-applicable | not-applicable |`n| WORK-E2E-D | none | not-applicable | not-applicable | not-applicable | not-applicable | not-applicable | REQ-001; SC-001; measurable outcome | TRACE-001 | incremental/preserve-existing | DESIGN-E2E@1 | not-applicable | not-applicable |`n| WORK-E2E-C | none | not-applicable | not-applicable | not-applicable | not-applicable | not-applicable | REQ-001; SC-001; measurable outcome | TRACE-001 | incremental/preserve-existing | DESIGN-E2E@1 | not-applicable | not-applicable |" "$($Scenario.Id)-selectors"
      $ownerB='| WORK-E2E-B | DESIGN-E2E@1 | RESP-WORK-E2E-B | not-applicable | not-applicable | docs/architecture.md#DECISION-WORK-E2E-B: independently implementable, reviewable, testable, and revertible |'
      $additionalOwners="| WORK-E2E-E | DESIGN-E2E@1 | RESP-WORK-E2E-E | not-applicable | not-applicable | approval:OWNER-WORK-E2E-E: independently implementable, reviewable, verifiable, and revertible |`n| WORK-E2E-D | DESIGN-E2E@1 | RESP-WORK-E2E-D | not-applicable | not-applicable | docs/architecture.md#RULE-WORK-E2E-D: independently implementable, reviewable, testable, and revertible |`n| WORK-E2E-C | DESIGN-E2E@1 | RESP-WORK-E2E-C | not-applicable | not-applicable | docs/architecture.md#APPROVAL-WORK-E2E-C: independently implementable, reviewable, verifiable, and revertible |"
      Replace-Exact $plan $ownerB "$ownerB`n$additionalOwners" "$($Scenario.Id)-owners"
      Replace-Exact $plan "| WORK-E2E-B | WORK-E2E-A | depends-on | decision:graph-e2e |" "| WORK-E2E-B | WORK-E2E-A | depends-on | decision:graph-e2e |`n| WORK-E2E-E | none | no-dependency | decision:graph-e2e |`n| WORK-E2E-D | none | no-dependency | decision:graph-e2e |`n| WORK-E2E-C | none | no-dependency | decision:graph-e2e |" $Scenario.Id
      Replace-Exact $plan "| ATTEMPT-WORK-E2E-B-01 | WORK-E2E-B | 1 | complete | $($Rendered.TerminalB) |" '' $Scenario.Id
      Replace-Exact $plan "| WORK-E2E-B | ready | in-progress | ATTEMPT-WORK-E2E-B-01 | 1 |`n| WORK-E2E-B | in-progress | complete | $($Rendered.TerminalB) | 1 |" '' $Scenario.Id
      Replace-Exact $target 'selection_test: no' 'selection_test: yes' $Scenario.Id
      $additionalDesignRefs = @(
        New-PlannedTechnicalDesign $Rendered.Run 'WORK-E2E-E'
        New-PlannedTechnicalDesign $Rendered.Run 'WORK-E2E-D'
        New-PlannedTechnicalDesign $Rendered.Run 'WORK-E2E-C'
      )
      $scenarioManifest = Get-Content -Raw -Encoding utf8 -LiteralPath $Rendered.Manifest | ConvertFrom-Json
      $scenarioManifest.technical_design_refs = @($scenarioManifest.technical_design_refs) + $additionalDesignRefs
      Write-Utf8 $Rendered.Manifest ($scenarioManifest | ConvertTo-Json -Depth 8)
    }
    'S07' { Replace-Exact $plan $rowA "| WORK-E2E-A | Item A | yes | none | 1 | REQ-001; SC-001; measurable outcome | TRACE-001 | migration-unit:UNIT-A | blocked | ATTEMPT-WORK-E2E-A-01 | $($Rendered.TerminalA) | approval:HUMAN-WORK-A |" $Scenario.Id;Replace-Exact $plan "| ATTEMPT-WORK-E2E-A-01 | WORK-E2E-A | 1 | complete | $($Rendered.TerminalA) |" "| ATTEMPT-WORK-E2E-A-01 | WORK-E2E-A | 1 | blocked | $($Rendered.TerminalA) |" $Scenario.Id;Replace-Exact $plan "| WORK-E2E-A | in-progress | complete | $($Rendered.TerminalA) | 1 |" "| WORK-E2E-A | in-progress | blocked | $($Rendered.TerminalA) | 1 |" $Scenario.Id }
    'S08' { Replace-Exact $plan 'initial approved plan | none | approval:HUMAN-PLAN-E2E |' 'initial approved plan | none | approval:STALE-PLAN-E2E |' $Scenario.Id }
    'S09' { Replace-Exact $plan '| WORK-E2E-A | Item A | yes | none |' '| WORK-E2E-A | Item A | yes | WORK-E2E-B |' $Scenario.Id;Replace-Exact $plan '| WORK-E2E-A | none | no-dependency | decision:graph-e2e |' '| WORK-E2E-A | WORK-E2E-B | depends-on | decision:graph-e2e |' $Scenario.Id }
    'S10' { Replace-Exact $target 'selector_state: internal' 'selector_state: external-only' $Scenario.Id }
    'S11' { Replace-Exact $target 'decomposition_trace: complete' 'decomposition_trace: missing' $Scenario.Id }
    'S12' { Replace-Exact $target 'exemplar_state: complete' 'exemplar_state: generic-only' $Scenario.Id }
    'S13' { Replace-Exact $target 'design_state: precise' 'design_state: vague' $Scenario.Id }
    'S14' { Replace-Exact $target 'wrapper_state: matched' 'wrapper_state: mismatch-unapproved' $Scenario.Id }
    'S15' { Replace-Exact $target 'tree_state: matched' 'tree_state: drift' $Scenario.Id }
    'S16' { Replace-Exact $target 'matrix_state: present' 'matrix_state: missing' $Scenario.Id }
    'S17' { Replace-Exact $target 'subscription_key_state: present' 'subscription_key_state: missing' $Scenario.Id }
    'S18' { Replace-Exact $target 'runtime_evidence_state: PASS' 'runtime_evidence_state: WAIVED' $Scenario.Id; Replace-Exact $target 'architecture_conformance_state: PASS' 'architecture_conformance_state: BLOCKED' $Scenario.Id }
    'S19' { Replace-Exact (Join-Path $Rendered.Run 'legacy-conversion.md') 'approval:AUTO-LEGACY-1' 'approval:HUMAN-LEGACY-1' $Scenario.Id }
    'S20' { Replace-Exact (Join-Path $Rendered.Run 'scope-terminal-report.md') 'scope_status: scope-in-progress' 'scope_status: scope-complete' $Scenario.Id }
    'S21' { Replace-Exact $target 'note: baseline' 'note: source-integrity-fixture-mutated' $Scenario.Id }
  }
}

$scenarios=@(
  [pscustomobject]@{Id='S01';Name='module scope creates masters before code';Diagnostic='scope-ready';State='planned'},
  [pscustomobject]@{Id='S02';Name='explicit item remains minimum scope';Diagnostic='explicit-item-minimum-scope';State='planned'},
  [pscustomobject]@{Id='S03';Name='ambiguous scope asks once';Diagnostic='scope-question-required';State='scope-blocked'},
  [pscustomobject]@{Id='S04';Name='unit-free project uses generic items';Diagnostic='generic-work-items-ready';State='planned'},
  [pscustomobject]@{Id='S05';Name='remaining required work';Diagnostic='required-work-remains';State='scope-in-progress'},
  [pscustomobject]@{Id='S06';Name='deterministic resume selection';Diagnostic='next-eligible:WORK-E2E-C';State='scope-in-progress'},
  [pscustomobject]@{Id='S07';Name='hard blocker';Diagnostic='dependency-blocked';State='scope-blocked'},
  [pscustomobject]@{Id='S08';Name='immutable revision chain and current approval';Diagnostic='master-artifact-current-approval-invalid';State='scope-blocked'},
  [pscustomobject]@{Id='S09';Name='dependency cycle';Diagnostic='dependency-cycle';State='scope-blocked'},
  [pscustomobject]@{Id='S10';Name='external-only selector';Diagnostic='external-only-selector';State='scope-blocked'},
  [pscustomobject]@{Id='S11';Name='canonical decomposition front half';Diagnostic='decomposition-front-half-missing';State='scope-blocked'},
  [pscustomobject]@{Id='S12';Name='complete exemplar';Diagnostic='complete-exemplar-missing';State='scope-blocked'},
  [pscustomobject]@{Id='S13';Name='precise structural design';Diagnostic='structural-design-evidence-missing';State='scope-blocked'},
  [pscustomobject]@{Id='S14';Name='wrapper deviation approval';Diagnostic='wrapper-deviation-unapproved';State='scope-blocked'},
  [pscustomobject]@{Id='S15';Name='actual planned tree';Diagnostic='actual-planned-tree-drift';State='scope-blocked'},
  [pscustomobject]@{Id='S16';Name='matrix before review';Diagnostic='conformance-matrix-missing-before-review';State='scope-blocked'},
  [pscustomobject]@{Id='S17';Name='production subscription key';Diagnostic='production-subscription-key-missing-critical';State='scope-blocked'},
  [pscustomobject]@{Id='S18';Name='waiver separation';Diagnostic='structural-assurance-blocked';State='scope-blocked'},
  [pscustomobject]@{Id='S19';Name='legacy conversion no inferred completion';Diagnostic='legacy-conversion-approved-no-scope-inference';State='planned'},
  [pscustomobject]@{Id='S20';Name='terminal report formula';Diagnostic='scope-completion-calculated';State='scope-complete'},
  [pscustomobject]@{Id='S21';Name='source checkout integrity';Diagnostic='scope-ready';State='planned'}
)
if ($scenarios.Count -ne 21 -or @($scenarios|Group-Object Id|Where-Object Count -ne 1).Count -gt 0) { throw 'E2E scenario manifest must contain exactly 21 unique scenarios' }
if ($OnlyScenario.Count -gt 0) {
  $unknownScenarios = @($OnlyScenario | Where-Object { $_ -cnotin @($scenarios.Id) })
  if ($unknownScenarios.Count -gt 0) { throw "Unknown flexible-scope scenario selector: $($unknownScenarios -join ', ')" }
  $scenarios = @($scenarios | Where-Object { $_.Id -cin $OnlyScenario })
}

Assert-CanonicalSelectorRowRenderingPreservesEol -SourceRoot $toolkitRoot
$sourceDigestBefore=Get-TreeDigest -Root $toolkitRoot
foreach($scenario in $scenarios){
  $fixtureRoot=New-IsolatedAitoolkitFixture -SourceRoot $toolkitRoot
  try {
    [void](New-Item -ItemType Directory -Path (Join-Path $fixtureRoot 'docs/aitoolkit') -Force)
    Write-ApprovedProjectProfile $fixtureRoot 'incremental'
    $canonicalGate=Invoke-FlexibleScope $fixtureRoot ''
    if($canonicalGate.ExitCode-ne0-or$canonicalGate.Output-notmatch'PASS: migration framework \(FlexibleScope\)'){$failures.Add("$($scenario.Id) fixture failed public Task3 scope-artifact gate before mutation: $($canonicalGate.Output)")}
    $rendered=New-RenderedFixture $fixtureRoot $scenario
    $task3Marker=Join-Path $rendered.Run '.task3-scope-artifacts-validated'
    if($scenario.Id-ceq'S01'){
      Write-Utf8 $task3Marker 'attacker-controlled'
      $specPath=Join-Path $rendered.Run 'master-spec.md'
      Replace-Exact $specPath 'master_spec_id: SPEC-E2E-001' 'master_spec_id: SPEC-OTHER-001' 'S01-precreated-marker'
      Assert-CanonicalRejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'S01-precreated-marker'
      Replace-Exact $specPath 'master_spec_id: SPEC-OTHER-001' 'master_spec_id: SPEC-E2E-001' 'S01-precreated-marker-restore'
      Remove-Item -LiteralPath $task3Marker -Force
    }
    $renderedGate=Invoke-FlexibleScope $fixtureRoot $rendered.Manifest
    if($renderedGate.Output-notmatch'(?m)^DIAGNOSTIC: predecessor-not-approved$'-or$renderedGate.Output-match'(?m)^FAIL: (master spec|master plan)'){$failures.Add("$($scenario.Id) rendered masters did not pass the reused Task3 parser before mutation: $($renderedGate.Output)")}
    if($scenario.Id-ceq'S01'){
      $canonicalNegatives=@(
        @('master-spec.md','master_spec_id: SPEC-E2E-001','master_spec_id: SPEC-OTHER-001','SPEC-OTHER'),
        @('master-plan.md','max_concurrency: 1','max_concurrency: 99','max99'),
        @('master-plan.md','initial approved plan | none | approval:HUMAN-PLAN-E2E |','initial approved plan | none | approval:STALE-PLAN-E2E |','stale-approval')
      )
      foreach($negative in $canonicalNegatives){$path=Join-Path $rendered.Run $negative[0];Replace-Exact $path $negative[1] $negative[2] "S01-$($negative[3])";$negativeResult=Invoke-FlexibleScope $fixtureRoot $rendered.Manifest;if($negative[3]-ceq'stale-approval'){if($negativeResult.Output-notmatch'(?m)^DIAGNOSTIC: master-artifact-current-approval-invalid$'){$failures.Add('S01-stale-approval semantic current-revision gate did not reject')}}else{Assert-CanonicalRejected $negativeResult "S01-$($negative[3])"};Replace-Exact $path $negative[2] $negative[1] "S01-$($negative[3])-restore";Assert-CanonicalAccepted (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) "S01-$($negative[3])-restore"}
      $planPath=Join-Path $rendered.Run 'master-plan.md'
      Replace-Exact $planPath '| WORK-E2E-A | Item A | yes | none | 1 | REQ-001; SC-001; measurable outcome | TRACE-001 | migration-unit:UNIT-A | complete |' '| WORK-E2E-A | Item A | yes | none | 1 | REQ-001; SC-001; measurable outcome | TRACE-001 | migration-unit:UNIT-A | blocked |' 'S01-cross-table-state'
      Assert-CanonicalRejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'S01-cross-table-state'
      Replace-Exact $planPath '| WORK-E2E-A | Item A | yes | none | 1 | REQ-001; SC-001; measurable outcome | TRACE-001 | migration-unit:UNIT-A | blocked |' '| WORK-E2E-A | Item A | yes | none | 1 | REQ-001; SC-001; measurable outcome | TRACE-001 | migration-unit:UNIT-A | complete |' 'S01-cross-table-state-restore'
    }
    $fixtureDigestBefore=Get-TreeDigest -Root $rendered.Run
    Replace-Exact (Join-Path $rendered.Run 'predecessor.md') 'status: draft' 'status: approved' $scenario.Id
    $approvedPredecessorRef=Get-ImmutableReference $rendered.Run 'predecessor.md'
    Rebind-ImmutableReference $rendered.Run $rendered.Predecessor $approvedPredecessorRef "$($scenario.Id)-approve-predecessor"
    $rendered.Predecessor=$approvedPredecessorRef
    if($scenario.Id-ceq'S07'){
      $p=Join-Path $rendered.Run 'master-plan.md';$old="| WORK-E2E-B | Item B | no | WORK-E2E-A | 2 | REQ-001; SC-001; measurable outcome | TRACE-001 | migration-unit:UNIT-B | complete | ATTEMPT-WORK-E2E-B-01 | $($rendered.TerminalB) | approval:HUMAN-WORK-B |";$blocked="| WORK-E2E-B | Item B | no | WORK-E2E-A | 2 | REQ-001; SC-001; measurable outcome | TRACE-001 | migration-unit:UNIT-B | blocked | ATTEMPT-WORK-E2E-B-01 | $($rendered.TerminalB) | approval:HUMAN-WORK-B |";Replace-Exact $p $old $blocked $scenario.Id;Replace-Exact $p "| ATTEMPT-WORK-E2E-B-01 | WORK-E2E-B | 1 | complete | $($rendered.TerminalB) |" "| ATTEMPT-WORK-E2E-B-01 | WORK-E2E-B | 1 | blocked | $($rendered.TerminalB) |" $scenario.Id;Replace-Exact $p "| WORK-E2E-B | in-progress | complete | $($rendered.TerminalB) | 1 |" "| WORK-E2E-B | in-progress | blocked | $($rendered.TerminalB) | 1 |" $scenario.Id;Assert-Observed (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'scope-ready' 'planned' 'S07-optional-blocker';Replace-Exact $p $blocked $old $scenario.Id;Replace-Exact $p "| ATTEMPT-WORK-E2E-B-01 | WORK-E2E-B | 1 | blocked | $($rendered.TerminalB) |" "| ATTEMPT-WORK-E2E-B-01 | WORK-E2E-B | 1 | complete | $($rendered.TerminalB) |" $scenario.Id;Replace-Exact $p "| WORK-E2E-B | in-progress | blocked | $($rendered.TerminalB) | 1 |" "| WORK-E2E-B | in-progress | complete | $($rendered.TerminalB) | 1 |" $scenario.Id
    }
    if($scenario.Id-ceq'S09'){
      $p=Join-Path $rendered.Run 'master-plan.md';Replace-Exact $p '| WORK-E2E-B | Item B | no | WORK-E2E-A |' '| WORK-E2E-B | Item B | no | WORK-MISSING |' $scenario.Id;Replace-Exact $p '| WORK-E2E-B | WORK-E2E-A | depends-on | decision:graph-e2e |' '| WORK-E2E-B | WORK-MISSING | depends-on | decision:graph-e2e |' $scenario.Id;Assert-CanonicalRejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'S09-missing';Replace-Exact $p '| WORK-E2E-B | Item B | no | WORK-MISSING |' '| WORK-E2E-B | Item B | no | WORK-E2E-A |' $scenario.Id;Replace-Exact $p '| WORK-E2E-B | WORK-MISSING | depends-on | decision:graph-e2e |' '| WORK-E2E-B | WORK-E2E-A | depends-on | decision:graph-e2e |' $scenario.Id
    }
    if($scenario.Id -in @('S19','S20')){
      $negative=Invoke-FlexibleScope $fixtureRoot $rendered.Manifest
      $negativeDiagnostic=if($scenario.Id -ceq 'S19'){'legacy-conversion-invalid'}else{'terminal-scope-report-invalid'}
      Assert-Rejected $negative $negativeDiagnostic $scenario.Id
    }
    Apply-ScenarioMutation $rendered $scenario
    $fixtureDigestAfter=Get-TreeDigest -Root $rendered.Run
    if($fixtureDigestBefore -ceq $fixtureDigestAfter){$failures.Add("$($scenario.Id) rendered evidence mutation did not alter fixture digest")}
    Assert-Outcome (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) $scenario.Diagnostic $scenario.State $scenario.Id
    if($scenario.Id -ceq 'S06'){
      $planPath=Join-Path $rendered.Run 'master-plan.md'
      $assertPlannedAuthorityRejected={param([string]$Old,[string]$New,[string]$Name)
        Replace-Exact $planPath $Old $New $Name
        Assert-Observed (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'structural-assurance-blocked' 'scope-blocked' $Name
        Replace-Exact $planPath $New $Old "$Name-restore"
      }
      $ownerB='| WORK-E2E-B | DESIGN-E2E@1 | RESP-WORK-E2E-B | not-applicable | not-applicable | docs/architecture.md#DECISION-WORK-E2E-B: independently implementable, reviewable, testable, and revertible |'
      $ownerBStale='| WORK-E2E-B | DESIGN-E2E@2 | RESP-WORK-E2E-B | not-applicable | not-applicable | docs/architecture.md#DECISION-WORK-E2E-B: independently implementable, reviewable, testable, and revertible |'
      & $assertPlannedAuthorityRejected $ownerB '<!-- missing planned owner authority -->' 'S06-missing-planned-owner-authority'
      & $assertPlannedAuthorityRejected $ownerB $ownerBStale 'S06-stale-planned-owner-authority'
      & $assertPlannedAuthorityRejected $ownerB ($ownerB.Replace('WORK-E2E-B','WORK-FOREIGN-999')) 'S06-foreign-planned-owner-authority'
      $ownerE='| WORK-E2E-E | DESIGN-E2E@1 | RESP-WORK-E2E-E | not-applicable | not-applicable | approval:OWNER-WORK-E2E-E: independently implementable, reviewable, verifiable, and revertible |'
      & $assertPlannedAuthorityRejected $ownerE ($ownerE.Replace('RESP-WORK-E2E-E','RESP-WORK-E2E-B')) 'S06-duplicate-planned-owner-authority'
      $selectorB='| WORK-E2E-B | migration-unit | UNIT-B | legacy-plan.md | 7 | approval:HUMAN-UNIT-B | not-applicable | REQ-001; SC-001; measurable outcome | TRACE-001 | incremental/preserve-existing | DESIGN-E2E@1 | not-applicable | not-applicable |'
      $selectorE='| WORK-E2E-E | none | not-applicable | not-applicable | not-applicable | not-applicable | not-applicable | REQ-001; SC-001; measurable outcome | TRACE-001 | incremental/preserve-existing | DESIGN-E2E@1 | not-applicable | not-applicable |'
      & $assertPlannedAuthorityRejected "$selectorB`n$selectorE" "$selectorE`n$selectorB" 'S06-reordered-planned-selector-authority'

      $designPath=Join-Path $rendered.Run 'technical-design-work-e2e-b.md'
      $designReference=[string]$rendered.TechnicalDesignRefs[1]
      $assertDesignAuthorityRejected={param([string]$Old,[string]$New,[string]$Name)
        Replace-Exact $designPath $Old $New $Name
        $mutatedReference=Get-ImmutableReference $rendered.Run 'technical-design-work-e2e-b.md'
        Rebind-ImmutableReference $rendered.Run $designReference $mutatedReference "$Name-ref"
        Assert-Observed (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'structural-assurance-blocked' 'scope-blocked' $Name
        Replace-Exact $designPath $New $Old "$Name-restore"
        Rebind-ImmutableReference $rendered.Run $mutatedReference $designReference "$Name-ref-restore"
      }
      & $assertDesignAuthorityRejected '  version: 1' '  version: 0' 'S06-pre-v1-planned-design-authority'
      & $assertDesignAuthorityRejected 'run_id: RUN-E2E-001' 'run_id: RUN-FOREIGN-999' 'S06-cross-run-planned-design-authority'
      & $assertDesignAuthorityRejected '| RESP-WORK-E2E-B | src/work-e2e-b.source | WORKE2EBOwner | application |' '| RESP-WORK-E2E-B | src/work-e2e-b.source | WORKE2EBOwner | integration |' 'S06-design-category-mismatch'
      & $assertDesignAuthorityRejected 'src/work-e2e-b.source' '../outside/work-e2e-b.source' 'S06-traversal-design-owner-path'
      & $assertDesignAuthorityRejected 'WORKE2EBOwner' '<owner-symbol>' 'S06-placeholder-design-owner-symbol'
      & $assertDesignAuthorityRejected '| target-exemplar | feature-local |' '| forged-authority | feature-local |' 'S06-forged-design-architecture-authority'
      & $assertDesignAuthorityRejected '| preferred | factual-discovery-evidence |' '| preferred | forged-authority |' 'S06-forged-design-classification-authority'
      & $assertDesignAuthorityRejected "inspection:src/target.source#Target; working-evidence:test/work-e2e-b_test.source#WORKE2EBOwnerScenario" 'forged:evidence' 'S06-forged-design-classification-evidence'
      & $assertDesignAuthorityRejected 'CAP-WORK-E2E-B' 'not-a-capability' 'S06-invalid-design-capability'
      & $assertDesignAuthorityRejected '| production-composition | required |' '| banana | required |' 'S06-invalid-design-evidence-kind'
      & $assertDesignAuthorityRejected '| production-composition | required |' '| production-composition | self-approved |' 'S06-invalid-design-verification-disposition'
      & $assertDesignAuthorityRejected 'src/work-e2e-b.source#WORKE2EBOwner' 'src/foreign.source#ForeignOwner' 'S06-foreign-design-production-binding'

      Replace-Exact $designPath 'src/work-e2e-b.source' 'work-e2e-b.source' 'S06-root-owner-path'
      Replace-Exact $designPath 'src/target.source' 'target.source' 'S06-root-target-path'
      $rootPathDesignReference=Get-ImmutableReference $rendered.Run 'technical-design-work-e2e-b.md'
      Rebind-ImmutableReference $rendered.Run $designReference $rootPathDesignReference 'S06-root-path-design-ref'
      Assert-Outcome (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) $scenario.Diagnostic $scenario.State 'S06-root-level-canonical-design-authority'
      Replace-Exact $designPath 'target.source' 'src/target.source' 'S06-root-target-path-restore'
      Replace-Exact $designPath 'work-e2e-b.source' 'src/work-e2e-b.source' 'S06-root-owner-path-restore'
      Rebind-ImmutableReference $rendered.Run $rootPathDesignReference $designReference 'S06-root-path-design-ref-restore'

      $canonicalTestResponsibilityRow='| RESP-WORK-E2E-B-TEST | test/work-e2e-b_test.source | WORKE2EBContract | test | verify WORK-E2E-B behavior | CAP-WORK-E2E-B | TRACE-001; WORK-E2E-B | not-applicable | WORKE2EBContract | none | src/target.source#Target | preferred | factual-discovery-evidence | inspection:src/target.source#Target; working-evidence:test/work-e2e-b_test.source#WORKE2EBContract | target-exemplar | not-applicable | not-applicable | not-applicable | yes | not-applicable |'
      Replace-Exact $designPath "`n`n## Verification Ownership Matrix" "`n$canonicalTestResponsibilityRow`n`n## Verification Ownership Matrix" 'S06-canonical-test-owner-row'
      $ownerBWithTest=$ownerB.Replace('| RESP-WORK-E2E-B |','| RESP-WORK-E2E-B, RESP-WORK-E2E-B-TEST |')
      Replace-Exact $planPath $ownerB $ownerBWithTest 'S06-canonical-test-owner-plan-ref'
      $testOwnerDesignReference=Get-ImmutableReference $rendered.Run 'technical-design-work-e2e-b.md'
      Rebind-ImmutableReference $rendered.Run $designReference $testOwnerDesignReference 'S06-canonical-test-owner-design-ref'
      Assert-Outcome (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) $scenario.Diagnostic $scenario.State 'S06-canonical-test-owner-authority'
      Replace-Exact $designPath "`n$canonicalTestResponsibilityRow`n`n## Verification Ownership Matrix" "`n`n## Verification Ownership Matrix" 'S06-canonical-test-owner-row-restore'
      Replace-Exact $planPath $ownerBWithTest $ownerB 'S06-canonical-test-owner-plan-ref-restore'
      Rebind-ImmutableReference $rendered.Run $testOwnerDesignReference $designReference 'S06-canonical-test-owner-design-ref-restore'

      $canonicalDesignRow='| RESP-WORK-E2E-B | src/work-e2e-b.source | WORKE2EBOwner | application | implement WORK-E2E-B | CAP-WORK-E2E-B | TRACE-001; WORK-E2E-B | not-applicable | WORKE2EBOwner | none | src/target.source#Target | preferred | factual-discovery-evidence | inspection:src/target.source#Target; working-evidence:test/work-e2e-b_test.source#WORKE2EBOwnerScenario | target-exemplar | feature-local | independently owned feature boundary | VERIFY-OWNER-WORK-E2E-B | yes | not-applicable |'
      $approvedDeviationDesignRow=$canonicalDesignRow.Replace('| preferred | factual-discovery-evidence | inspection:src/target.source#Target; working-evidence:test/work-e2e-b_test.source#WORKE2EBOwnerScenario | target-exemplar |','| compatibility-only | project-pack-rule | architecture-rules.md#RULE-WORK-E2E-B | approved-structural-deviation |').Replace('| yes | not-applicable |','| no | DEV-WORK-E2E-B |')
      $approvedDeviationRow='| DEV-WORK-E2E-B | responsibility ownership | CONFLICT-WORK-E2E-B | resolved:DECISION-WORK-E2E-B: preserve the approved compatibility owner | approval:TECH-LEAD-WORK-E2E-B |'
      $approvedDeviationSection=@"
## Approved Structural Deviations

| Deviation Reference | Concern | Conflict Reference | Resolved Decision | Tech Lead Approval |
|---|---|---|---|---|
$approvedDeviationRow

"@
      Replace-Exact $designPath $canonicalDesignRow $approvedDeviationDesignRow 'S06-approved-no-planned-design-row'
      Replace-Exact $designPath '## File Responsibility Matrix' "$approvedDeviationSection## File Responsibility Matrix" 'S06-approved-no-planned-design-table'
      $approvedDeviationReference=Get-ImmutableReference $rendered.Run 'technical-design-work-e2e-b.md'
      Rebind-ImmutableReference $rendered.Run $designReference $approvedDeviationReference 'S06-approved-no-planned-design-ref'
      Assert-Outcome (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) $scenario.Diagnostic $scenario.State 'S06-approved-no-planned-design-authority'

      $assertApprovedDeviationRejected={param([string]$Old,[string]$New,[string]$Name)
        Replace-Exact $designPath $Old $New $Name
        $mutatedReference=Get-ImmutableReference $rendered.Run 'technical-design-work-e2e-b.md'
        Rebind-ImmutableReference $rendered.Run $approvedDeviationReference $mutatedReference "$Name-ref"
        Assert-Observed (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'structural-assurance-blocked' 'scope-blocked' $Name
        Replace-Exact $designPath $New $Old "$Name-restore"
        Rebind-ImmutableReference $rendered.Run $mutatedReference $approvedDeviationReference "$Name-ref-restore"
      }
      & $assertApprovedDeviationRejected $approvedDeviationRow '<!-- missing approved deviation authority -->' 'S06-missing-approved-deviation-row'
      & $assertApprovedDeviationRejected $approvedDeviationRow "$approvedDeviationRow`n$approvedDeviationRow" 'S06-duplicate-approved-deviation-row'
      & $assertApprovedDeviationRejected $approvedDeviationRow "$approvedDeviationRow`n$($approvedDeviationRow.Replace('approval:TECH-LEAD-WORK-E2E-B','approval:OWNER-FORGED'))" 'S06-mixed-valid-malformed-deviation-row'
      & $assertApprovedDeviationRejected 'approval:TECH-LEAD-WORK-E2E-B' 'approval:OWNER-WORK-E2E-B' 'S06-malformed-approved-deviation-approval'
      & $assertApprovedDeviationRejected '| DEV-WORK-E2E-B | responsibility ownership |' '| DEV-WORK-E2E-B | pending |' 'S06-placeholder-approved-deviation-concern'
      & $assertApprovedDeviationRejected 'preserve the approved compatibility owner' 'pending' 'S06-placeholder-approved-deviation-decision'
      & $assertApprovedDeviationRejected '| no | DEV-WORK-E2E-B |' '| blocked | DEV-WORK-E2E-B |' 'S06-blocked-planned-design-conformance'

      Replace-Exact $designPath $approvedDeviationDesignRow $canonicalDesignRow 'S06-approved-no-planned-design-row-restore'
      Replace-Exact $designPath $approvedDeviationSection '' 'S06-approved-no-planned-design-table-restore'
      Rebind-ImmutableReference $rendered.Run $approvedDeviationReference $designReference 'S06-approved-no-planned-design-ref-restore'
      & $assertDesignAuthorityRejected '| RESP-WORK-E2E-B | src/work-e2e-b.source | WORKE2EBOwner | application |' '| RESP-WORK-E2E-B | src/work-e2e-b.source | WORKE2EBOwner | PASS |' 'S06-noncanonical-design-boundary'
      & $assertDesignAuthorityRejected '| RESP-WORK-E2E-B | src/work-e2e-b.source | WORKE2EBOwner | application |' '| RESP-WORK-E2E-B | src/work-e2e-b.source | WORKE2EBOwner | test |' 'S06-test-boundary-with-production-owner-semantics'
    }
    if($scenario.Id -ceq 'S19'){
      $legacy=Join-Path $rendered.Run 'legacy-conversion.md'
      Replace-Exact $legacy "migration-unit:UNIT-A | $($rendered.HistoricalA)" "migration-unit:WRONG | $($rendered.HistoricalA)" $scenario.Id
      Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'legacy-conversion-invalid' "$($scenario.Id)-adapter"
      Replace-Exact $legacy "migration-unit:WRONG | $($rendered.HistoricalA)" "migration-unit:UNIT-A | $($rendered.HistoricalA)" $scenario.Id
      Replace-Exact $legacy "| UNIT-A | WORK-E2E-A | migration-unit:UNIT-A | $($rendered.HistoricalA) | yes |" "| UNIT-A | WORK-E2E-A | migration-unit:UNIT-A | $($rendered.HistoricalA) | no |" $scenario.Id
      Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'legacy-conversion-invalid' "$($scenario.Id)-invalid-evidence"
      Replace-Exact $legacy "| UNIT-A | WORK-E2E-A | migration-unit:UNIT-A | $($rendered.HistoricalA) | no |" "| UNIT-A | WORK-E2E-A | migration-unit:UNIT-A | $($rendered.HistoricalA) | yes |" $scenario.Id
      Replace-Exact $legacy 'implementation-report@9bfed5b148eb07a284f567bcd7486c9a00318a50#gitblob:15299bfe69780430508cf9527fcfe14d1d216748 | approval:HIST-UNIT-A' 'implementation-report@fabricated#gitblob:wrong | approval:HIST-UNIT-A' 'S19-schema-version';Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'legacy-conversion-invalid' 'S19-schema-version';Replace-Exact $legacy 'implementation-report@fabricated#gitblob:wrong | approval:HIST-UNIT-A' 'implementation-report@9bfed5b148eb07a284f567bcd7486c9a00318a50#gitblob:15299bfe69780430508cf9527fcfe14d1d216748 | approval:HIST-UNIT-A' 'S19-schema-version-restore'
      $historicalPath=Join-Path $rendered.Run 'historical-a.md'
      $legacyEnvelopeNegatives=@(
        @('UNIT-A | legacy-plan.md@7','UNIT-WRONG | legacy-plan.md@7','unit-id'),
        @('legacy-plan.md@7 | approval:HUMAN-UNIT-A','legacy-plan.md@8 | approval:HUMAN-UNIT-A','plan-revision'),
        @('approval:HUMAN-UNIT-A | incremental/preserve-existing','approval:HUMAN-WRONG | incremental/preserve-existing','approval'),
        @('incremental/preserve-existing | not-required','greenfield/design-new | not-required','mode'),
        @('not-required | not-applicable | not-applicable','required | not-applicable | not-applicable','bootstrap'),
        @('not-applicable | not-applicable | not-applicable | baseline:a','FOUNDATION-WRONG | not-applicable | not-applicable | baseline:a','foundation-id'),
        @('not-applicable | not-applicable | baseline:a','foundation:wrong | not-applicable | baseline:a','foundation-reference'),
        @('not-applicable | baseline:a','approval:HUMAN-WRONG | baseline:a','foundation-approval'),
        @('baseline:a | TRACE-LEGACY-UNIT-A','baseline:wrong | TRACE-LEGACY-UNIT-A','baseline'),
        @('TRACE-LEGACY-UNIT-A |','TRACE-LEGACY-WRONG |','trace')
      )
      foreach($negative in $legacyEnvelopeNegatives){Replace-Exact $historicalPath $negative[0] $negative[1] "S19-$($negative[2])";$newRef=Get-ImmutableReference $rendered.Run 'historical-a.md';Rebind-ImmutableReference $rendered.Run $rendered.HistoricalA $newRef "S19-$($negative[2])";Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'legacy-conversion-invalid' "S19-$($negative[2])";Replace-Exact $historicalPath $negative[1] $negative[0] "S19-$($negative[2])-restore";Rebind-ImmutableReference $rendered.Run $newRef $rendered.HistoricalA "S19-$($negative[2])-restore"}
      Replace-Exact $historicalPath 'status: approved' 'status: draft' 'S19-lifecycle';$newRef=Get-ImmutableReference $rendered.Run 'historical-a.md';Rebind-ImmutableReference $rendered.Run $rendered.HistoricalA $newRef 'S19-lifecycle';Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'legacy-conversion-invalid' 'S19-lifecycle';Replace-Exact $historicalPath 'status: draft' 'status: approved' 'S19-lifecycle-restore';Rebind-ImmutableReference $rendered.Run $newRef $rendered.HistoricalA 'S19-lifecycle-restore'
      Replace-Exact $historicalPath 'result: complete' 'result: partial' 'S19-in-progress-pre-v1-resume';$newRef=Get-ImmutableReference $rendered.Run 'historical-a.md';Rebind-ImmutableReference $rendered.Run $rendered.HistoricalA $newRef 'S19-in-progress-pre-v1-resume';Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'legacy-conversion-invalid' 'S19-in-progress-pre-v1-resume';Replace-Exact $historicalPath 'result: partial' 'result: complete' 'S19-in-progress-pre-v1-resume-restore';Rebind-ImmutableReference $rendered.Run $newRef $rendered.HistoricalA 'S19-in-progress-pre-v1-resume-restore'
      Replace-Exact $historicalPath "## $CommandsHeading" '## Reduced Commands' 'S19-required-section';$newRef=Get-ImmutableReference $rendered.Run 'historical-a.md';Rebind-ImmutableReference $rendered.Run $rendered.HistoricalA $newRef 'S19-required-section';Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'legacy-conversion-invalid' 'S19-required-section';Replace-Exact $historicalPath '## Reduced Commands' "## $CommandsHeading" 'S19-required-section-restore';Rebind-ImmutableReference $rendered.Run $newRef $rendered.HistoricalA 'S19-required-section-restore'
      $target=Join-Path $rendered.Run 'target-evidence.md';Replace-Exact $target 'architecture_conformance_state: PASS' 'architecture_conformance_state: BLOCKED' $scenario.Id;Assert-Observed (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'structural-assurance-blocked' 'scope-blocked' 'S19-monotonic';Replace-Exact $target 'architecture_conformance_state: BLOCKED' 'architecture_conformance_state: PASS' $scenario.Id
    }
    if($scenario.Id -ceq 'S20'){
      $originalManifest=Get-Content -Raw -Encoding utf8 -LiteralPath $rendered.Manifest
      $skippedChainManifest=$originalManifest|ConvertFrom-Json
      $chainA=@($skippedChainManifest.responsibility_chain_refs|Where-Object{$_.work_item_id-ceq'WORK-E2E-A'})[0]
      $chainA.artifact_refs=@($chainA.artifact_refs[0],$chainA.artifact_refs[1],$chainA.artifact_refs[3],$chainA.artifact_refs[4])
      Write-Utf8 $rendered.Manifest ($skippedChainManifest|ConvertTo-Json -Depth 8)
      Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'terminal-scope-report-invalid' 'S20-skipped-responsibility-chain-stage'
      Write-Utf8 $rendered.Manifest $originalManifest
      $report=Join-Path $rendered.Run 'scope-terminal-report.md'
      Replace-Exact $report '## Approval Record' "## Approval Record`n`n## Approval Record" $scenario.Id
      Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'terminal-scope-report-invalid' "$($scenario.Id)-duplicate-section"
      Replace-Exact $report "## Approval Record`n`n## Approval Record" '## Approval Record' $scenario.Id
      $terminalRow="| WORK-E2E-B | no | complete | $($rendered.TerminalB) | PASS | PASS | PASS | none | 1 |"
      Replace-Exact $report $terminalRow '' $scenario.Id
      Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'terminal-scope-report-invalid' "$($scenario.Id)-cardinality"
      $terminalARow="| WORK-E2E-A | yes | complete | $($rendered.TerminalA) | PASS | PASS | PASS | none | 1 |"
      $reportText=Get-Content -Raw -Encoding utf8 $report
      $reportEol=if($reportText.Contains("`r`n")){"`r`n"}else{"`n"}
      Replace-Exact $report $terminalARow "$terminalARow$reportEol$terminalRow" $scenario.Id
      $target=Join-Path $rendered.Run 'target-evidence.md';Replace-Exact $target 'selector_schema_state: PASS' 'selector_schema_state: BLOCKED' $scenario.Id;Assert-Observed (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'structural-assurance-blocked' 'scope-blocked' 'S20-monotonic';Replace-Exact $target 'selector_schema_state: BLOCKED' 'selector_schema_state: PASS' $scenario.Id
      $terminalPath=Join-Path $rendered.Run 'terminal-a.md';$originalTerminal=Get-Content -Raw -Encoding utf8 $terminalPath
      $terminalBPath=Join-Path $rendered.Run 'terminal-b.md';$originalTerminalB=Get-Content -Raw -Encoding utf8 $terminalBPath
      $responsibilityTerminalPath=Join-Path $rendered.Run 'knowledge-a.md';$originalResponsibilityTerminal=Get-Content -Raw -Encoding utf8 $responsibilityTerminalPath
      $responsibilityEvidence='source-diff:1111111111111111111111111111111111111111..2222222222222222222222222222222222222222#WORK-E2E-A'
      $assertTerminalArtifactRejected={param([string]$MutatedText,[string]$Name)
        if($MutatedText-ceq$originalTerminal){throw "$Name mutation was a silent no-op"}
        Write-Utf8 $terminalPath $MutatedText
        $mutatedTerminalRef=Get-ImmutableReference $rendered.Run 'terminal-a.md'
        Rebind-ImmutableReference $rendered.Run $rendered.TerminalA $mutatedTerminalRef "$Name-ref"
        Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'terminal-scope-report-invalid' $Name
        Write-Utf8 $terminalPath $originalTerminal
        Rebind-ImmutableReference $rendered.Run $mutatedTerminalRef $rendered.TerminalA "$Name-ref-restore"
      }
      & $assertTerminalArtifactRejected ($originalTerminal.Replace($rendered.SourceDiffA,$rendered.ResponsibilityChains[0].artifact_refs[-1])) 'S20-terminal-handoff-cannot-be-final-kb'
      & $assertTerminalArtifactRejected ($originalTerminal -replace '(?ms)^## Terminal Chain Reference.*?(?=^## Work Item Test Evidence)', '') 'S20-terminal-chain-reference-required'
      & $assertTerminalArtifactRejected ($originalTerminal.Replace("## Terminal Chain Reference`n","## Terminal Chain Reference`n`n## Terminal Chain Reference`n")) 'S20-terminal-chain-reference-duplicate'
      & $assertTerminalArtifactRejected ($originalTerminal.Replace($rendered.ResponsibilityChains[0].artifact_refs[-1],$rendered.SourceDiffA)) 'S20-terminal-chain-cannot-be-source-diff'
      & $assertTerminalArtifactRejected ($originalTerminal.Replace($rendered.ResponsibilityChains[0].artifact_refs[-1],$rendered.ReviewA)) 'S20-terminal-chain-must-be-final'
      & $assertTerminalArtifactRejected ($originalTerminal.Replace($rendered.ResponsibilityChains[0].artifact_refs[-1],$rendered.ResponsibilityChains[1].artifact_refs[-1])) 'S20-terminal-chain-cannot-cross-work-item'
      $staleTerminalChainReference=([string]$rendered.ResponsibilityChains[0].artifact_refs[-1]) -replace '[0-9a-f]$', '0'
      if($staleTerminalChainReference-ceq$rendered.ResponsibilityChains[0].artifact_refs[-1]){$staleTerminalChainReference=([string]$rendered.ResponsibilityChains[0].artifact_refs[-1]) -replace '[0-9a-f]$', '1'}
      & $assertTerminalArtifactRejected ($originalTerminal.Replace($rendered.ResponsibilityChains[0].artifact_refs[-1],$staleTerminalChainReference)) 'S20-terminal-chain-stale'

      $assertScopeReportRejected={param([string]$Old,[string]$New,[string]$Name)
        Replace-Exact $report $Old $New $Name
        Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'terminal-scope-report-invalid' $Name
        Replace-Exact $report $New $Old "$Name-restore"
      }
      $sourceDiffList="$($rendered.SourceDiffA); $($rendered.SourceDiffB)"
      $finalChainList="$($rendered.ResponsibilityChains[0].artifact_refs[-1]); $($rendered.ResponsibilityChains[1].artifact_refs[-1])"
      & $assertScopeReportRejected $sourceDiffList $finalChainList 'S20-scope-handoff-cannot-be-final-kb'
      & $assertScopeReportRejected $sourceDiffList "$($rendered.SourceDiffB); $($rendered.SourceDiffA)" 'S20-scope-handoff-order'
      $evidenceRowA="| EVIDENCE-A | $($rendered.ResponsibilityChains[0].artifact_refs[-1]) | WORK-E2E-A | architecture-responsibility-sub-verdicts |"
      $evidenceRowB="| EVIDENCE-B | $($rendered.ResponsibilityChains[1].artifact_refs[-1]) | WORK-E2E-B | architecture-responsibility-sub-verdicts |"
      & $assertScopeReportRejected $evidenceRowA ($evidenceRowA.Replace($rendered.ResponsibilityChains[0].artifact_refs[-1],$rendered.SourceDiffA)) 'S20-evidence-index-cannot-be-source-diff'
      & $assertScopeReportRejected "$evidenceRowA`n$evidenceRowB" "$evidenceRowB`n$evidenceRowA" 'S20-evidence-index-order'
      $orderedTerminalRows="$terminalARow`n$terminalRow"
      & $assertScopeReportRejected $orderedTerminalRows "$terminalRow`n$terminalARow" 'S20-terminal-row-order'
      $terminalWithoutHandoff=$originalTerminal -replace '(?ms)^## Architecture Responsibility Handoff.*?(?=^## Work Item Test Evidence)', ''
      if($terminalWithoutHandoff-ceq$originalTerminal){throw 'S20 terminal responsibility handoff removal was a silent no-op'}
      Write-Utf8 $terminalPath $terminalWithoutHandoff;$terminalWithoutHandoffRef=Get-ImmutableReference $rendered.Run 'terminal-a.md';Rebind-ImmutableReference $rendered.Run $rendered.TerminalA $terminalWithoutHandoffRef 'S20-terminal-handoff-required';Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'terminal-scope-report-invalid' 'S20-terminal-handoff-required';Write-Utf8 $terminalPath $originalTerminal;Rebind-ImmutableReference $rendered.Run $terminalWithoutHandoffRef $rendered.TerminalA 'S20-terminal-handoff-required-restore'
      $reviewPath=Join-Path $rendered.Run 'review-a.md';$originalReview=Get-Content -Raw -Encoding utf8 $reviewPath
      Replace-Exact $reviewPath 'status: approved' 'status: draft' 'S20-review-lifecycle';$draftReviewRef=Get-ImmutableReference $rendered.Run 'review-a.md';Rebind-ImmutableReference $rendered.Run $rendered.ReviewA $draftReviewRef 'S20-review-lifecycle';Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'terminal-scope-report-invalid' 'S20-review-lifecycle';Write-Utf8 $reviewPath $originalReview;Rebind-ImmutableReference $rendered.Run $draftReviewRef $rendered.ReviewA 'S20-review-lifecycle-restore'
      Replace-Exact $reviewPath 'result: complete' 'result: partial' 'S20-review-result-lifecycle';$partialReviewRef=Get-ImmutableReference $rendered.Run 'review-a.md';Rebind-ImmutableReference $rendered.Run $rendered.ReviewA $partialReviewRef 'S20-review-result-lifecycle';Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'terminal-scope-report-invalid' 'S20-review-result-lifecycle';Write-Utf8 $reviewPath $originalReview;Rebind-ImmutableReference $rendered.Run $partialReviewRef $rendered.ReviewA 'S20-review-result-lifecycle-restore'
      Replace-Exact $reviewPath 'approval_source: human' 'approval_source: automation' 'S20-review-approval-source';$automatedReviewRef=Get-ImmutableReference $rendered.Run 'review-a.md';Rebind-ImmutableReference $rendered.Run $rendered.ReviewA $automatedReviewRef 'S20-review-approval-source';Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'terminal-scope-report-invalid' 'S20-review-approval-source';Write-Utf8 $reviewPath $originalReview;Rebind-ImmutableReference $rendered.Run $automatedReviewRef $rendered.ReviewA 'S20-review-approval-source-restore'
      Replace-Exact $reviewPath '| implementation-report.md |' '| foreign-implementation-report.md |' 'S20-review-immediate-predecessor';$foreignPredecessorReviewRef=Get-ImmutableReference $rendered.Run 'review-a.md';Rebind-ImmutableReference $rendered.Run $rendered.ReviewA $foreignPredecessorReviewRef 'S20-review-immediate-predecessor';Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'terminal-scope-report-invalid' 'S20-review-immediate-predecessor';Write-Utf8 $reviewPath $originalReview;Rebind-ImmutableReference $rendered.Run $foreignPredecessorReviewRef $rendered.ReviewA 'S20-review-immediate-predecessor-restore'
      $greenfieldTerminalA=$originalTerminal.Replace('incremental/preserve-existing','greenfield/design-new').Replace($rendered.ResponsibilityChains[0].artifact_refs[-1],$rendered.GreenfieldKnowledgeA)
      $greenfieldTerminalB=$originalTerminalB.Replace('incremental/preserve-existing','greenfield/design-new').Replace($rendered.ResponsibilityChains[1].artifact_refs[-1],$rendered.GreenfieldKnowledgeB)
      Write-Utf8 $terminalPath $greenfieldTerminalA;Write-Utf8 $terminalBPath $greenfieldTerminalB
      $greenfieldTerminalARef=Get-ImmutableReference $rendered.Run 'terminal-a.md';$greenfieldTerminalBRef=Get-ImmutableReference $rendered.Run 'terminal-b.md'
      Rebind-ImmutableReference $rendered.Run $rendered.TerminalA $greenfieldTerminalARef 'S20-greenfield-terminal-a';Rebind-ImmutableReference $rendered.Run $rendered.TerminalB $greenfieldTerminalBRef 'S20-greenfield-terminal-b'
      Rebind-ImmutableReference $rendered.Run $rendered.ResponsibilityChains[0].artifact_refs[-1] $rendered.GreenfieldKnowledgeA 'S20-greenfield-knowledge-a';Rebind-ImmutableReference $rendered.Run $rendered.ResponsibilityChains[1].artifact_refs[-1] $rendered.GreenfieldKnowledgeB 'S20-greenfield-knowledge-b'
      $greenfieldManifest=Get-Content -Raw -Encoding utf8 -LiteralPath $rendered.Manifest|ConvertFrom-Json
      foreach($chain in @($greenfieldManifest.responsibility_chain_refs)){
        $greenfieldChain=@($rendered.GreenfieldResponsibilityChains|Where-Object{$_.work_item_id-ceq$chain.work_item_id})[0]
        $chain.artifact_refs=@($greenfieldChain.artifact_refs)
      }
      Write-Utf8 $rendered.Manifest ($greenfieldManifest|ConvertTo-Json -Depth 8)
      Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'terminal-scope-report-invalid' 'S20-incremental-cannot-self-label-greenfield'
      $masterPlanPath=Join-Path $rendered.Run 'master-plan.md'
      $legacyPlanPath=Join-Path $rendered.Run 'legacy-plan.md'
      Replace-Exact $masterPlanPath 'incremental/preserve-existing' 'greenfield/design-new' 'S20-approved-greenfield-master-plan'
      Replace-Exact $legacyPlanPath 'incremental/preserve-existing' 'greenfield/design-new' 'S20-approved-greenfield-authority'
      $greenfieldDesignReferences=[Collections.Generic.List[string]]::new()
      for($designIndex=0;$designIndex-lt$rendered.TechnicalDesignRefs.Count;$designIndex++){
        $designWorkItem=if($designIndex-eq0){'work-e2e-a'}else{'work-e2e-b'}
        $designPath=Join-Path $rendered.Run "technical-design-$designWorkItem.md"
        Replace-Exact $designPath 'mode_constraint: incremental/preserve-existing' 'mode_constraint: greenfield/design-new' "S20-approved-greenfield-design-$designIndex"
        Replace-Exact $designPath ' | target-exemplar | feature-local |' ' | approved-greenfield-design | feature-local |' "S20-approved-greenfield-design-authority-$designIndex"
        $greenfieldDesignReference=Get-ImmutableReference $rendered.Run "technical-design-$designWorkItem.md"
        $greenfieldDesignReferences.Add($greenfieldDesignReference)
        Rebind-ImmutableReference $rendered.Run $rendered.TechnicalDesignRefs[$designIndex] $greenfieldDesignReference "S20-approved-greenfield-design-$designIndex-ref"
      }
      Write-ApprovedProjectProfile $fixtureRoot 'greenfield'
      $persistedGreenfieldProfile=Get-Content -Raw -Encoding utf8 -LiteralPath (Join-Path $fixtureRoot 'docs/aitoolkit/project.yaml')
      if($persistedGreenfieldProfile-notmatch'(?m)^  mode: greenfield$'-or$persistedGreenfieldProfile-notmatch'(?m)^  architecture_policy: design-new$'){$failures.Add('S20 persisted external profile did not carry the approved greenfield authority')}
      Assert-Outcome (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'scope-completion-calculated' 'scope-complete' 'S20-greenfield-four-stage-chain'
      Replace-Exact $masterPlanPath 'greenfield/design-new' 'incremental/preserve-existing' 'S20-approved-greenfield-master-plan-restore'
      Replace-Exact $legacyPlanPath 'greenfield/design-new' 'incremental/preserve-existing' 'S20-approved-greenfield-authority-restore'
      for($designIndex=0;$designIndex-lt$rendered.TechnicalDesignRefs.Count;$designIndex++){
        $designWorkItem=if($designIndex-eq0){'work-e2e-a'}else{'work-e2e-b'}
        $designPath=Join-Path $rendered.Run "technical-design-$designWorkItem.md"
        Replace-Exact $designPath 'mode_constraint: greenfield/design-new' 'mode_constraint: incremental/preserve-existing' "S20-approved-greenfield-design-$designIndex-restore"
        Replace-Exact $designPath ' | approved-greenfield-design | feature-local |' ' | target-exemplar | feature-local |' "S20-approved-greenfield-design-authority-$designIndex-restore"
        Rebind-ImmutableReference $rendered.Run $greenfieldDesignReferences[$designIndex] $rendered.TechnicalDesignRefs[$designIndex] "S20-approved-greenfield-design-$designIndex-ref-restore"
      }
      Write-ApprovedProjectProfile $fixtureRoot 'incremental'
      Write-Utf8 $terminalPath $originalTerminal;Write-Utf8 $terminalBPath $originalTerminalB;Rebind-ImmutableReference $rendered.Run $greenfieldTerminalARef $rendered.TerminalA 'S20-greenfield-terminal-a-restore';Rebind-ImmutableReference $rendered.Run $greenfieldTerminalBRef $rendered.TerminalB 'S20-greenfield-terminal-b-restore';Rebind-ImmutableReference $rendered.Run $rendered.GreenfieldKnowledgeA $rendered.ResponsibilityChains[0].artifact_refs[-1] 'S20-greenfield-knowledge-a-restore';Rebind-ImmutableReference $rendered.Run $rendered.GreenfieldKnowledgeB $rendered.ResponsibilityChains[1].artifact_refs[-1] 'S20-greenfield-knowledge-b-restore';Write-Utf8 $rendered.Manifest $originalManifest

      $foreignReviewPath=Join-Path $rendered.Run 'foreign/review-a.md'
      Write-Utf8 $foreignReviewPath $originalReview
      $foreignReviewRef=Get-ImmutableReference $rendered.Run 'foreign/review-a.md'
      Rebind-ImmutableReference $rendered.Run $rendered.ReviewA $foreignReviewRef 'S20-same-work-item-cross-run-chain'
      Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'terminal-scope-report-invalid' 'S20-same-work-item-cross-run-chain'
      Rebind-ImmutableReference $rendered.Run $foreignReviewRef $rendered.ReviewA 'S20-same-work-item-cross-run-chain-restore'

      Replace-Exact $reviewPath 'RUN-E2E-001 | rendered-scope-run/master-spec.md' 'RUN-E2E-001 | rendered-scope-run/foreign-spec.md' 'S20-review-master-binding'
      $foreignMasterReviewRef=Get-ImmutableReference $rendered.Run 'review-a.md';Rebind-ImmutableReference $rendered.Run $rendered.ReviewA $foreignMasterReviewRef 'S20-review-master-binding'
      Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'terminal-scope-report-invalid' 'S20-review-master-binding'
      Write-Utf8 $reviewPath $originalReview;Rebind-ImmutableReference $rendered.Run $foreignMasterReviewRef $rendered.ReviewA 'S20-review-master-binding-restore'

      $downstreamContextCases=@(
        @{ Name='missing-downstream-context'; Index=1; File='verification-a.md'; Mutate={param($text) $text -replace '(?ms)^## Master Scope Context.*?(?=^## Task Provenance)', ''} },
        @{ Name='foreign-downstream-run'; Index=2; File='parity-a.md'; Mutate={param($text) $text.Replace('RUN-E2E-001 | rendered-scope-run/master-spec.md','RUN-FOREIGN-999 | rendered-scope-run/master-spec.md')} },
        @{ Name='foreign-downstream-spec'; Index=3; File='regression-a.md'; Mutate={param($text) $text.Replace('rendered-scope-run/master-spec.md | SPEC-E2E-001','rendered-scope-run/foreign-spec.md | SPEC-E2E-001')} },
        @{ Name='foreign-downstream-plan'; Index=4; File='knowledge-a.md'; Mutate={param($text) $text.Replace('rendered-scope-run/master-plan.md | PLAN-E2E-001','rendered-scope-run/foreign-plan.md | PLAN-E2E-001')} }
      )
      foreach($contextCase in $downstreamContextCases){
        $contextPath=Join-Path $rendered.Run $contextCase.File
        $originalContextArtifact=Get-Content -Raw -Encoding utf8 -LiteralPath $contextPath
        $mutatedContextArtifact=& $contextCase.Mutate $originalContextArtifact
        if($mutatedContextArtifact-ceq$originalContextArtifact){throw "S20-$($contextCase.Name) mutation was a silent no-op"}
        Write-Utf8 $contextPath $mutatedContextArtifact
        $mutatedContextRef=Get-ImmutableReference $rendered.Run $contextCase.File
        $originalContextRef=$rendered.ResponsibilityChains[0].artifact_refs[$contextCase.Index]
        Rebind-ImmutableReference $rendered.Run $originalContextRef $mutatedContextRef "S20-$($contextCase.Name)-ref"
        Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'terminal-scope-report-invalid' "S20-$($contextCase.Name)"
        Write-Utf8 $contextPath $originalContextArtifact
        Rebind-ImmutableReference $rendered.Run $mutatedContextRef $originalContextRef "S20-$($contextCase.Name)-restore"
      }

      $originalSourceDiff='source-diff:1111111111111111111111111111111111111111..2222222222222222222222222222222222222222#WORK-E2E-A'
      $mismatchedSourceDiff='source-diff:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa..bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb#WORK-E2E-A'
      $chainNames=@('review-a.md','verification-a.md','parity-a.md','regression-a.md','knowledge-a.md')
      $mutatedChainRefs=[Collections.Generic.List[string]]::new()
      for($chainIndex=0;$chainIndex-lt$chainNames.Count;$chainIndex++){
        Replace-Exact (Join-Path $rendered.Run $chainNames[$chainIndex]) $originalSourceDiff $mismatchedSourceDiff "S20-source-diff-provenance-$chainIndex"
        $mutatedRef=Get-ImmutableReference $rendered.Run $chainNames[$chainIndex]
        $mutatedChainRefs.Add($mutatedRef)
        Rebind-ImmutableReference $rendered.Run $rendered.ResponsibilityChains[0].artifact_refs[$chainIndex] $mutatedRef "S20-source-diff-provenance-$chainIndex-ref"
      }
      Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'terminal-scope-report-invalid' 'S20-source-diff-provenance'
      for($chainIndex=0;$chainIndex-lt$chainNames.Count;$chainIndex++){
        Replace-Exact (Join-Path $rendered.Run $chainNames[$chainIndex]) $mismatchedSourceDiff $originalSourceDiff "S20-source-diff-provenance-$chainIndex-restore"
        Rebind-ImmutableReference $rendered.Run $mutatedChainRefs[$chainIndex] $rendered.ResponsibilityChains[0].artifact_refs[$chainIndex] "S20-source-diff-provenance-$chainIndex-ref-restore"
      }
      # A terminal artifact without the v1 responsibility handoff cannot be
      # executable authority for scope completion.
      $missingHandoff=$originalResponsibilityTerminal -replace '(?ms)^## Architecture Responsibility Handoff.*', ''
      Write-Utf8 $responsibilityTerminalPath $missingHandoff;$missingHandoffRef=Get-ImmutableReference $rendered.Run 'knowledge-a.md';Rebind-ImmutableReference $rendered.Run $rendered.ResponsibilityChains[0].artifact_refs[4] $missingHandoffRef 'S20-missing-responsibility-handoff';Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'terminal-scope-report-invalid' 'S20-missing-responsibility-handoff';Write-Utf8 $responsibilityTerminalPath $originalResponsibilityTerminal;Rebind-ImmutableReference $rendered.Run $missingHandoffRef $rendered.ResponsibilityChains[0].artifact_refs[4] 'S20-missing-responsibility-handoff-restore'
      $blockedResponsibility=$originalResponsibilityTerminal.Replace("| 1 | PASS | PASS | PASS | PASS | $responsibilityEvidence |","| 1 | PASS | BLOCKED | PASS | PASS | $responsibilityEvidence |")
      if($blockedResponsibility-ceq$originalResponsibilityTerminal){throw 'S20 responsibility BLOCKED mutation was a silent no-op'}
      Write-Utf8 $responsibilityTerminalPath $blockedResponsibility;$blockedResponsibilityRef=Get-ImmutableReference $rendered.Run 'knowledge-a.md';Rebind-ImmutableReference $rendered.Run $rendered.ResponsibilityChains[0].artifact_refs[4] $blockedResponsibilityRef 'S20-aggregate-pass-responsibility-blocked';Assert-Observed (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'structural-assurance-blocked' 'scope-blocked' 'S20-aggregate-pass-responsibility-blocked';Write-Utf8 $responsibilityTerminalPath $originalResponsibilityTerminal;Rebind-ImmutableReference $rendered.Run $blockedResponsibilityRef $rendered.ResponsibilityChains[0].artifact_refs[4] 'S20-aggregate-pass-responsibility-blocked-restore'
      $missingEvidence=$originalResponsibilityTerminal.Replace($responsibilityEvidence,'none')
      if($missingEvidence-ceq$originalResponsibilityTerminal){throw 'S20 missing responsibility evidence mutation was a silent no-op'}
      Write-Utf8 $responsibilityTerminalPath $missingEvidence;$missingEvidenceRef=Get-ImmutableReference $rendered.Run 'knowledge-a.md';Rebind-ImmutableReference $rendered.Run $rendered.ResponsibilityChains[0].artifact_refs[4] $missingEvidenceRef 'S20-missing-responsibility-evidence';Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'terminal-scope-report-invalid' 'S20-missing-responsibility-evidence';Write-Utf8 $responsibilityTerminalPath $originalResponsibilityTerminal;Rebind-ImmutableReference $rendered.Run $missingEvidenceRef $rendered.ResponsibilityChains[0].artifact_refs[4] 'S20-missing-responsibility-evidence-restore'
      $mixedVersion=$originalResponsibilityTerminal.Replace("| 1 | PASS | PASS | PASS | PASS | $responsibilityEvidence |","| 2 | PASS | PASS | PASS | PASS | $responsibilityEvidence |")
      if($mixedVersion-ceq$originalResponsibilityTerminal){throw 'S20 mixed v1/v2 mutation was a silent no-op'}
      Write-Utf8 $responsibilityTerminalPath $mixedVersion;$mixedVersionRef=Get-ImmutableReference $rendered.Run 'knowledge-a.md';Rebind-ImmutableReference $rendered.Run $rendered.ResponsibilityChains[0].artifact_refs[4] $mixedVersionRef 'S20-mixed-v1-v2';Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'terminal-scope-report-invalid' 'S20-mixed-v1-v2';Write-Utf8 $responsibilityTerminalPath $originalResponsibilityTerminal;Rebind-ImmutableReference $rendered.Run $mixedVersionRef $rendered.ResponsibilityChains[0].artifact_refs[4] 'S20-mixed-v1-v2-restore'
      # A syntactically valid immutable reference with the wrong digest is not
      # evidence. Rebinding the terminal digest must not make it executable.
      $forgedEvidenceRef=($rendered.ResponsibilityChains[0].artifact_refs[4] -replace '[0-9a-f]{64}$',('0'*64))
      Replace-Exact $rendered.Manifest $rendered.ResponsibilityChains[0].artifact_refs[4] $forgedEvidenceRef 'S20-forged-responsibility-evidence';Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'terminal-scope-report-invalid' 'S20-forged-responsibility-evidence';Replace-Exact $rendered.Manifest $forgedEvidenceRef $rendered.ResponsibilityChains[0].artifact_refs[4] 'S20-forged-responsibility-evidence-restore'
      Rebind-ImmutableReference $rendered.Run $rendered.TerminalA $rendered.HistoricalA 'S20-historical-only-executable-authority';Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'terminal-scope-report-invalid' 'S20-historical-only-executable-authority';Rebind-ImmutableReference $rendered.Run $rendered.HistoricalA $rendered.TerminalA 'S20-historical-only-executable-authority-restore'
      foreach($runtimeState in @('FAIL','NOT_RUN','WAIVED')){$stateTerminal=$originalTerminal.Replace('| PASS | PASS | PASS |',"| $runtimeState | PASS | PASS |");Write-Utf8 $terminalPath $stateTerminal;$stateRef=Get-ImmutableReference $rendered.Run 'terminal-a.md';Rebind-ImmutableReference $rendered.Run $rendered.TerminalA $stateRef "S20-$runtimeState";Replace-Exact $report "| $stateRef | PASS | PASS | PASS | none | 1 |" "| $stateRef | $runtimeState | PASS | PASS | none | 1 |" "S20-$runtimeState-report";Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'terminal-scope-report-invalid' "S20-$runtimeState";Replace-Exact $report "| $stateRef | $runtimeState | PASS | PASS | none | 1 |" "| $stateRef | PASS | PASS | PASS | none | 1 |" "S20-$runtimeState-report-restore";Write-Utf8 $terminalPath $originalTerminal;Rebind-ImmutableReference $rendered.Run $stateRef $rendered.TerminalA "S20-$runtimeState-restore"}
      foreach($referenceNegative in @(@('rendered-scope-run/master-spec.md','rendered-scope-run/other-spec.md','other-spec'),@('rendered-scope-run/master-plan.md','rendered-scope-run/forked-plan.md','forked-plan'),@('approval:HUMAN-WORK-A','approval:HUMAN-WRONG','source-approval'),@('REQ-001; SC-001; measurable outcome | TRACE-001 | incremental/preserve-existing','REQ-001; measurable outcome | TRACE-001 | incremental/preserve-existing','incomplete-acceptance'),@('| WORK-E2E-A | ACT-E2E-001 | persistence | integration verification | test:integration | PASS | TRACE-001 |','| WORK-E2E-A | ACT-E2E-001 | persistence | integration verification | test:integration | PASS | TRACE-OTHER |','incomplete-trace-aggregate'))){Replace-Exact $terminalPath $referenceNegative[0] $referenceNegative[1] "S20-$($referenceNegative[2])";$newRef=Get-ImmutableReference $rendered.Run 'terminal-a.md';Rebind-ImmutableReference $rendered.Run $rendered.TerminalA $newRef "S20-$($referenceNegative[2])";Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'terminal-scope-report-invalid' "S20-$($referenceNegative[2])";Write-Utf8 $terminalPath $originalTerminal;Rebind-ImmutableReference $rendered.Run $newRef $rendered.TerminalA "S20-$($referenceNegative[2])-restore"}
      $predecessorAuthority=Get-Content -Raw -Encoding utf8 (Join-Path $rendered.Run 'predecessor.md')
      $activationAuthorityMatch=[regex]::Match($predecessorAuthority,'(?m)^## Activation Slice\r?\n\r?\n(?<table>(?:^\|.*\|\r?\n?)+)')
      if(-not $activationAuthorityMatch.Success){$failures.Add('S20 fixture predecessor activation authority missing')}
      $activationAuthorityTable=$activationAuthorityMatch.Groups['table'].Value.TrimEnd("`r","`n")
      $priorActivationTable=$activationAuthorityTable.Replace('| ACT-001 | applicable | upstream-response | upstream input | upstream output | evidence:upstream | TRACE-001 | implement | verified | not-applicable | not-applicable |','| ACT-001 | applicable | upstream-response | upstream input | upstream output | evidence:upstream; implementation:prior-step10 | TRACE-001; TRACE-002 | implement | verified | not-applicable | not-applicable |')
      if($priorActivationTable-ceq$activationAuthorityTable){throw 'S20 prior-step10 enrichment fixture was a silent no-op'}
      $upstreamAuthorityRef=Get-ImmutableReference $rendered.Run 'predecessor.md'
      $priorWaiverPath=Join-Path $rendered.Run 'prior-step10-waiver.md'
      $priorWaiver=@"
---
step_id: 10-code-migration
status: approved
result: partial
approval_source: auto-waive
produced_at: 2026-08-20
---
# Prior Step 10 Waiver

## Master Scope Context

| Run ID | Master Spec Reference | Master Spec ID | Master Spec Revision | Master Plan Reference | Master Plan ID | Master Plan Revision | Work Item ID |
|---|---|---|---|---|---|---|---|
| RUN-E2E-001 | rendered-scope-run/master-spec.md | SPEC-E2E-001 | 1 | rendered-scope-run/master-plan.md | PLAN-E2E-001 | 1 | WORK-E2E-A |

## Task Provenance

| Task / Unit | Task-base SHA | Final-tree SHA | Source Artifact |
|---|---|---|---|
| WORK-E2E-A | 1111111111111111111111111111111111111111 | 2222222222222222222222222222222222222222 | implementation-report.md |

## Architecture Responsibility Handoff

| Responsibility Contract Version | Tree Conformance | Responsibility Conformance | Verification Ownership | Architecture Conformance State | Evidence References |
|---|---|---|---|---|---|
| 1 | PASS | PASS | PASS | PASS | source-diff:1111111111111111111111111111111111111111..2222222222222222222222222222222222222222#WORK-E2E-A |

## Selected Migration Unit

| Migration Unit ID | Plan Reference | Approval Reference | Mode Constraint | Bootstrap Scope | Foundation Baseline ID | Foundation Baseline Reference | Foundation Baseline Approval Reference | Baseline Reference | Trace IDs |
|---|---|---|---|---|---|---|---|---|---|
| UNIT-A | legacy-plan.md@7 | approval:HUMAN-UNIT-A | incremental/preserve-existing | not-required | not-applicable | not-applicable | not-applicable | evidence:capability-unavailable | TRACE-001; TRACE-002; PARITY-001 |

## $BlockerHeading

| Stage / Check | Native Verdict | Command Role | Required Command Lifecycle | Command / Capability | Observed Error | Evidence Reference |
|---|---|---|---|---|---|---|
| pre-mutation baseline | BLOCKED | availability probe | not-started | device capability | capability unavailable | evidence:capability-unavailable |

## Approved Baseline Waiver

``````yaml
status: approved
result: partial
approval_source: auto-waive
waiver:
  policy: auto-waive
  category: environment-unavailable
  original_verdict: blocked
  effective_action: continue
  evidence: evidence:capability-unavailable
``````

## Step 10 Waiver Resume State

| Resume Phase | Baseline Action | Implementation Status | Target Mutation Evidence | Waiver Evidence |
|---|---|---|---|---|
| resume-required | skip-pre-mutation-baseline-only | blocked | none | evidence:capability-unavailable |

## Activation Slice

$priorActivationTable

## $EvidenceHeading

| Evidence | Location | Notes |
|---|---|---|
| activation-authority-provenance | $upstreamAuthorityRef#ACT-001 | approval:DEFER-ACT-001; approval:ROUTER-ACT-001 |
| activation-authority-provenance | $upstreamAuthorityRef#ACT-002 | approval:NA-ACT-002 |

## $UnknownHeading

- none

## $ConclusionHeading

partial
"@
      Write-Utf8 $priorWaiverPath $priorWaiver
      $priorWaiverRef=Get-ImmutableReference $rendered.Run 'prior-step10-waiver.md'
      Replace-Exact $rendered.Manifest ('"predecessor_ref":  "'+$rendered.Predecessor+'"') ('"predecessor_ref":  "'+$priorWaiverRef+'"') 'S20-waiver-immediate-predecessor'
      $waivedTail=@"

## Selected Migration Unit

| Migration Unit ID | Plan Reference | Approval Reference | Mode Constraint | Bootstrap Scope | Foundation Baseline ID | Foundation Baseline Reference | Foundation Baseline Approval Reference | Baseline Reference | Trace IDs |
|---|---|---|---|---|---|---|---|---|---|
| UNIT-A | legacy-plan.md@7 | approval:HUMAN-UNIT-A | incremental/preserve-existing | not-required | not-applicable | not-applicable | not-applicable | evidence:capability-unavailable | TRACE-001; TRACE-002; PARITY-001 |

## $BlockerHeading

| Stage / Check | Native Verdict | Command Role | Required Command Lifecycle | Command / Capability | Observed Error | Evidence Reference |
|---|---|---|---|---|---|---|
| pre-mutation baseline | BLOCKED | availability probe | not-started | device capability | capability unavailable | evidence:capability-unavailable |

## Approved Baseline Waiver

``````yaml
status: approved
result: partial
approval_source: auto-waive
waiver:
  policy: auto-waive
  category: environment-unavailable
  original_verdict: blocked
  effective_action: continue
  evidence: evidence:capability-unavailable
``````

## Step 10 Waiver Resume State

| Resume Phase | Baseline Action | Implementation Status | Target Mutation Evidence | Waiver Evidence |
|---|---|---|---|---|
| resume-consumed | skip-pre-mutation-baseline-only | partial | UNIT-A TRACE-001 target/source.dart | evidence:capability-unavailable |

## Activation Slice

$priorActivationTable

## $EvidenceHeading

| Evidence | Location | Notes |
|---|---|---|
| waiver implementation | target/source.dart | UNIT-A TRACE-001 |
| activation-waiver-provenance | $priorWaiverRef#ACT-001 | evidence:capability-unavailable |
| activation-waiver-provenance | $priorWaiverRef#ACT-002 | evidence:capability-unavailable |

## $UnknownHeading

- none

## $ConclusionHeading

partial
"@
      $specPath=Join-Path $rendered.Run 'master-spec.md';$planPath=Join-Path $rendered.Run 'master-plan.md'
      Replace-Exact $specPath '| TRACE-001 | requirement | source:ticket | trace note |' "| TRACE-001 | requirement | source:ticket | trace note |`n| TRACE-002 | requirement | source:ticket-2 | trace note 2 |`n| PARITY-001 | requirement | source:parity | parity trace |" 'S20-waiver-spec-traces'
      Replace-Exact $planPath 'REQ-001; SC-001; measurable outcome | TRACE-001 | migration-unit:UNIT-A' 'REQ-001; SC-001; measurable outcome | TRACE-001; TRACE-002; PARITY-001 | migration-unit:UNIT-A' 'S20-waiver-plan-traces'
      Replace-Exact $planPath 'approval:HUMAN-UNIT-A | not-applicable | REQ-001; SC-001; measurable outcome | TRACE-001 | incremental/preserve-existing' 'approval:HUMAN-UNIT-A | not-applicable | REQ-001; SC-001; measurable outcome | TRACE-001; TRACE-002; PARITY-001 | incremental/preserve-existing' 'S20-waiver-selector-traces'
      $chainAFiles=@('review-a.md','verification-a.md','parity-a.md','regression-a.md','knowledge-a.md')
      for($chainIndex=0;$chainIndex-lt$chainAFiles.Count;$chainIndex++){
        $chainPath=Join-Path $rendered.Run $chainAFiles[$chainIndex]
        $oldChainRef=[string]$rendered.ResponsibilityChains[0].artifact_refs[$chainIndex]
        Replace-Exact $chainPath 'baseline:a | TRACE-001 |' 'baseline:a | TRACE-001; TRACE-002; PARITY-001 |' "S20-waiver-chain-traces-$chainIndex"
        $newChainRef=Get-ImmutableReference $rendered.Run $chainAFiles[$chainIndex]
        Rebind-ImmutableReference $rendered.Run $oldChainRef $newChainRef "S20-waiver-chain-ref-$chainIndex"
        $rendered.ResponsibilityChains[0].artifact_refs[$chainIndex]=$newChainRef
      }
      $originalResponsibilityTerminal=Get-Content -Raw -Encoding utf8 -LiteralPath $responsibilityTerminalPath
      $waiverTerminalBase=Get-Content -Raw -Encoding utf8 -LiteralPath $terminalPath
      $waivedTerminal=$waiverTerminalBase.Replace('result: complete','result: partial').Replace('approval_source: human','approval_source: auto-waive').Replace("| PASS | PASS | PASS |`n`n## Architecture Responsibility Handoff","| WAIVED | PASS | PASS |`n`n## Architecture Responsibility Handoff").Replace('REQ-001; SC-001; measurable outcome | TRACE-001 | incremental/preserve-existing','REQ-001; SC-001; measurable outcome | TRACE-001; TRACE-002; PARITY-001 | incremental/preserve-existing').Replace("| WORK-E2E-A | ACT-E2E-001 | runtime | behavioral verification | test:e2e | PASS | TRACE-001 |`n| WORK-E2E-A | ACT-E2E-001 | persistence | integration verification | test:integration | PASS | TRACE-001 |","| WORK-E2E-A | ACT-E2E-001 | runtime | behavioral verification | test:e2e | PASS | TRACE-001 |`n| WORK-E2E-A | ACT-E2E-001 | persistence | integration verification | test:integration | PASS | TRACE-002 |`n| WORK-E2E-A | ACT-E2E-001 | parity | compatibility verification | test:parity | PASS | PARITY-001 |")+$waivedTail
      Write-Utf8 $terminalPath $waivedTerminal;$waivedRef=Get-ImmutableReference $rendered.Run 'terminal-a.md';Rebind-ImmutableReference $rendered.Run $rendered.TerminalA $waivedRef 'S20-valid-waiver';Replace-Exact $report "| $waivedRef | PASS | PASS | PASS | none | 1 |" "| $waivedRef | WAIVED | PASS | PASS | none | 1 |" 'S20-valid-waiver'
      $waivedStructuralOverride=$originalResponsibilityTerminal.Replace("| 1 | PASS | PASS | PASS | PASS | $responsibilityEvidence |","| 1 | PASS | BLOCKED | PASS | PASS | $responsibilityEvidence |")
      if($waivedStructuralOverride-ceq$originalResponsibilityTerminal){throw 'S20 auto-waive structural override mutation was a silent no-op'}
      Write-Utf8 $responsibilityTerminalPath $waivedStructuralOverride;$waivedStructuralOverrideRef=Get-ImmutableReference $rendered.Run 'knowledge-a.md';Rebind-ImmutableReference $rendered.Run $rendered.ResponsibilityChains[0].artifact_refs[4] $waivedStructuralOverrideRef 'S20-auto-waive-responsibility-override';Assert-Observed (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'structural-assurance-blocked' 'scope-blocked' 'S20-auto-waive-responsibility-override';Write-Utf8 $responsibilityTerminalPath $originalResponsibilityTerminal;Rebind-ImmutableReference $rendered.Run $waivedStructuralOverrideRef $rendered.ResponsibilityChains[0].artifact_refs[4] 'S20-auto-waive-responsibility-override-restore'
      $waiverNegatives=@(
        @('availability probe','required test/build/baseline command','role'),
        @('not-started','started-without-correctness/regression-result','lifecycle'),
        @('resume-consumed','resume-required','resume'),
        @('effective_action: continue','effective_action: stop','waiver-body'),
        @('| ACT-001 | applicable | requested-key | key input | key output | evidence:key | TRACE-002 | implement | verified | not-applicable | not-applicable |','<!-- omitted requested-key seam -->', 'omitted-seam'),
        @('| ACT-002 | not-applicable-approved | test | no-selector input | no-selector output | evidence:na-test | TRACE-002 | not-applicable-approved | verified | approval:NA-ACT-002 | not-applicable |',"| ACT-002 | not-applicable-approved | test | no-selector input | no-selector output | evidence:na-test | TRACE-002 | not-applicable-approved | verified | approval:NA-ACT-002 | not-applicable |`n| ACT-003 | not-applicable-approved | test | extra input | extra output | evidence:extra | TRACE-002 | not-applicable-approved | verified | approval:NA-ACT-003 | not-applicable |",'extra-group'),
        @('| ACT-002 | not-applicable-approved | upstream-response | no-selector input | no-selector output | evidence:na-upstream | TRACE-002 | not-applicable-approved | verified | approval:NA-ACT-002 | not-applicable |','| ACT-003 | not-applicable-approved | upstream-response | no-selector input | no-selector output | evidence:na-upstream | TRACE-002 | not-applicable-approved | verified | approval:NA-ACT-002 | not-applicable |','group-id'),
        @('policy=compatibility-dual-path','policy=compatibility-dual-path-missing','router-dual-path'),
        @('| ACT-002 | not-applicable-approved | render | no-selector input | no-selector output | evidence:na-render | TRACE-002 | not-applicable-approved | verified | approval:NA-ACT-002 | not-applicable |','| ACT-002 | not-applicable-approved | render | no-selector input | no-selector output | evidence:na-render | TRACE-002 | not-applicable-approved | missing | approval:NA-ACT-002 | not-applicable |','na-state'),
        @('| ACT-001 | applicable | render | render input | render output | evidence:render | TRACE-002 | implement | verified | not-applicable | not-applicable |','| ACT-001 | applicable | render | render input | render output | evidence:render | TRACE-FOREIGN | implement | verified | not-applicable | not-applicable |','foreign-trace'),
        @("$priorWaiverRef#ACT-002 | evidence:capability-unavailable","$priorWaiverRef#ACT-OTHER | evidence:capability-unavailable",'slice-provenance'),
        @('Waiver Evidence |`n|---|---|---|---|---|`n| resume-consumed | skip-pre-mutation-baseline-only | partial | UNIT-A TRACE-001 target/source.dart | evidence:capability-unavailable |','Waiver Evidence |`n|---|---|---|---|---|`n| resume-consumed | skip-pre-mutation-baseline-only | partial | UNIT-A TRACE-001 target/source.dart | evidence:wrong |','provenance')
      )
      foreach($negative in $waiverNegatives){$old=$negative[0].Replace('`n',"`n");$new=$negative[1].Replace('`n',"`n");Replace-Exact $terminalPath $old $new "S20-waiver-$($negative[2])";$negativeRef=Get-ImmutableReference $rendered.Run 'terminal-a.md';Rebind-ImmutableReference $rendered.Run $waivedRef $negativeRef "S20-waiver-$($negative[2])";Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'terminal-scope-report-invalid' "S20-waiver-$($negative[2])";Replace-Exact $terminalPath $new $old "S20-waiver-$($negative[2])-restore";Rebind-ImmutableReference $rendered.Run $negativeRef $waivedRef "S20-waiver-$($negative[2])-restore"}
      $assertUpstreamHandoffRejected={param([string]$OldRow,[string]$NewRow,[string]$Name)
        Replace-Exact $priorWaiverPath $OldRow $NewRow "$Name-prior";Replace-Exact $terminalPath $OldRow $NewRow "$Name-current"
        $mutatedPriorRef=Get-ImmutableReference $rendered.Run 'prior-step10-waiver.md';Rebind-ImmutableReference $rendered.Run $priorWaiverRef $mutatedPriorRef "$Name-prior-ref"
        $mutatedTerminalRef=Get-ImmutableReference $rendered.Run 'terminal-a.md';Rebind-ImmutableReference $rendered.Run $waivedRef $mutatedTerminalRef "$Name-terminal-ref"
        Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'terminal-scope-report-invalid' $Name
        Replace-Exact $priorWaiverPath $NewRow $OldRow "$Name-prior-restore";Replace-Exact $terminalPath $NewRow $OldRow "$Name-current-restore"
        Rebind-ImmutableReference $rendered.Run $mutatedPriorRef $priorWaiverRef "$Name-prior-ref-restore";Rebind-ImmutableReference $rendered.Run $mutatedTerminalRef $waivedRef "$Name-terminal-ref-restore"
      }
      $enrichedUpstreamRow='| ACT-001 | applicable | upstream-response | upstream input | upstream output | evidence:upstream; implementation:prior-step10 | TRACE-001; TRACE-002 | implement | verified | not-applicable | not-applicable |'
      & $assertUpstreamHandoffRejected $enrichedUpstreamRow '| ACT-001 | applicable | upstream-response | upstream input | upstream output | implementation:prior-step10 | TRACE-001; TRACE-002 | implement | verified | not-applicable | not-applicable |' 'S20-waiver-upstream-source-loss'
      & $assertUpstreamHandoffRejected $enrichedUpstreamRow '| ACT-001 | applicable | upstream-response | upstream input | upstream output | evidence:upstream; implementation:prior-step10 | TRACE-002 | implement | verified | not-applicable | not-applicable |' 'S20-waiver-upstream-trace-loss'
      & $assertUpstreamHandoffRejected $enrichedUpstreamRow '| ACT-001 | applicable | upstream-response | upstream input | upstream output | evidence:upstream; implementation:prior-step10 | TRACE-001; TRACE-002; TRACE-FOREIGN | implement | verified | not-applicable | not-applicable |' 'S20-waiver-upstream-foreign-trace'
      Replace-Exact $rendered.Manifest $priorWaiverRef $upstreamAuthorityRef 'S20-waiver-unrelated-08'
      Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'terminal-scope-report-invalid' 'S20-waiver-unrelated-08'
      Replace-Exact $rendered.Manifest $upstreamAuthorityRef $priorWaiverRef 'S20-waiver-unrelated-08-restore'
      $replacementDigestChar=if($priorWaiverRef.EndsWith('0')){'1'}else{'0'};$badDigestRef=$priorWaiverRef.Substring(0,$priorWaiverRef.Length-1)+$replacementDigestChar
      Replace-Exact $rendered.Manifest $priorWaiverRef $badDigestRef 'S20-waiver-predecessor-digest'
      Assert-PredecessorReferenceRejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'S20-waiver-predecessor-digest'
      Replace-Exact $rendered.Manifest $badDigestRef $priorWaiverRef 'S20-waiver-predecessor-digest-restore'
      Replace-Exact $priorWaiverPath 'capability unavailable | evidence:capability-unavailable |' 'different capability error | evidence:capability-unavailable |' 'S20-waiver-predecessor-blocker'
      $changedPriorRef=Get-ImmutableReference $rendered.Run 'prior-step10-waiver.md';Rebind-ImmutableReference $rendered.Run $priorWaiverRef $changedPriorRef 'S20-waiver-predecessor-blocker'
      $changedTerminalRef=Get-ImmutableReference $rendered.Run 'terminal-a.md';Rebind-ImmutableReference $rendered.Run $waivedRef $changedTerminalRef 'S20-waiver-predecessor-blocker-terminal'
      Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'terminal-scope-report-invalid' 'S20-waiver-predecessor-blocker'
      Replace-Exact $priorWaiverPath 'different capability error | evidence:capability-unavailable |' 'capability unavailable | evidence:capability-unavailable |' 'S20-waiver-predecessor-blocker-restore'
      Rebind-ImmutableReference $rendered.Run $changedPriorRef $priorWaiverRef 'S20-waiver-predecessor-blocker-restore'
      Rebind-ImmutableReference $rendered.Run $changedTerminalRef $waivedRef 'S20-waiver-predecessor-blocker-terminal-restore'
      $predecessorPath=Join-Path $rendered.Run 'predecessor.md'
      Replace-Exact $terminalPath 'evidence:construct; compatibility-reason=legacy-route; router-owner=router-team' 'evidence:construct; router-owner=router-team' 'S20-waiver-router-authority-current'
      Replace-Exact $predecessorPath 'evidence:construct; compatibility-reason=legacy-route; router-owner=router-team' 'evidence:construct; router-owner=router-team' 'S20-waiver-router-authority-predecessor'
      $negativeRef=Get-ImmutableReference $rendered.Run 'terminal-a.md';Rebind-ImmutableReference $rendered.Run $waivedRef $negativeRef 'S20-waiver-router-authority'
      Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'terminal-scope-report-invalid' 'S20-waiver-router-authority'
      Replace-Exact $terminalPath 'evidence:construct; router-owner=router-team' 'evidence:construct; compatibility-reason=legacy-route; router-owner=router-team' 'S20-waiver-router-authority-current-restore'
      Replace-Exact $predecessorPath 'evidence:construct; router-owner=router-team' 'evidence:construct; compatibility-reason=legacy-route; router-owner=router-team' 'S20-waiver-router-authority-predecessor-restore'
      Rebind-ImmutableReference $rendered.Run $negativeRef $waivedRef 'S20-waiver-router-authority-restore'
      Assert-Outcome (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'scope-completion-calculated' 'scope-complete' 'S20-valid-waiver';Replace-Exact $report "| $waivedRef | WAIVED | PASS | PASS | none | 1 |" "| $waivedRef | PASS | PASS | PASS | none | 1 |" 'S20-valid-waiver-report-restore';Write-Utf8 $terminalPath $originalTerminal;Rebind-ImmutableReference $rendered.Run $waivedRef $rendered.TerminalA 'S20-valid-waiver-restore'
    }
  }
  finally { Remove-IsolatedAitoolkitFixture -FixtureRoot $fixtureRoot }
}
$sourceDigestAfter=Get-TreeDigest -Root $toolkitRoot
if($sourceDigestBefore -cne $sourceDigestAfter){$failures.Add('Flexible-scope E2E changed source checkout bytes')}
if($failures.Count -gt 0){$failures|ForEach-Object{Write-Output "FAIL: $_"};exit 1}
$scenarioLabel = if ($OnlyScenario.Count -eq 0) { '21 isolated E2E scenarios' } else { "$($scenarios.Count) selected isolated E2E scenario(s)" }
Write-Output "PASS: flexible migration scope orchestration ($scenarioLabel)"

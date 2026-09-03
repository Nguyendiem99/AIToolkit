param(
  [ValidateSet('Yaml','Resume','Downstream','Lifecycle','Orchestrator','Markdown','Duplicates','Pipes','All')]
  [string]$Cluster = 'All'
)

$ErrorActionPreference = 'Stop'
$validator = Join-Path $PSScriptRoot 'validate-migration-framework.ps1'
$powershell = (Get-Process -Id $PID).Path
$testFailures = [Collections.Generic.List[string]]::new()

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { $testFailures.Add($Message) }
}

function Assert-Contains([string]$Text, [string]$Expected, [string]$Context) {
  Assert-True ($Text.Contains($Expected)) "$Context missing <$Expected>. Output: $Text"
}

function Assert-NotContains([string]$Text, [string]$Unexpected, [string]$Context) {
  Assert-True (-not $Text.Contains($Unexpected)) "$Context unexpectedly contained <$Unexpected>. Output: $Text"
}

function Invoke-ActivationSliceArtifactValidator(
  [string]$Text,
  [string]$PredecessorText = ''
) {
  $fixtureSuffix = "$PID-$([guid]::NewGuid().ToString('N'))"
  $fixtureRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
  $fixturePath = Join-Path $fixtureRoot "aitoolkit-activation-slice-final-$fixtureSuffix.md"
  $predecessorPath = Join-Path $fixtureRoot "aitoolkit-activation-slice-final-predecessor-$fixtureSuffix.md"
  try {
    $currentText = $Text
    $arguments = @(
      '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $validator,
      '-ActivationSliceArtifactPath', $fixturePath
    )
    if (-not [string]::IsNullOrWhiteSpace($PredecessorText)) {
      [IO.File]::WriteAllText($predecessorPath, $PredecessorText, [Text.UTF8Encoding]::new($false))
      $currentText = $currentText.Replace('<IMMEDIATE_PREDECESSOR_PATH>', $predecessorPath)
      $arguments += @('-PredecessorActivationSliceArtifactPath', $predecessorPath)
    }
    [IO.File]::WriteAllText($fixturePath, $currentText, [Text.UTF8Encoding]::new($false))
    $output = & $powershell @arguments 2>&1
    return [pscustomobject]@{
      ExitCode = $LASTEXITCODE
      Output = ($output -join [Environment]::NewLine)
    }
  }
  finally {
    Remove-Item -LiteralPath $fixturePath, $predecessorPath -Force -ErrorAction SilentlyContinue
  }
}

function Invoke-ActivationSliceContractValidator([string]$Text) {
  $fixturePath = Join-Path ([IO.Path]::GetFullPath([IO.Path]::GetTempPath())) "aitoolkit-activation-slice-contract-final-$PID-$([guid]::NewGuid().ToString('N')).md"
  try {
    [IO.File]::WriteAllText($fixturePath, $Text, [Text.UTF8Encoding]::new($false))
    $output = & $powershell `
      -NoProfile `
      -ExecutionPolicy Bypass `
      -File $validator `
      -Target Contracts `
      -ActivationSliceContractFixturePath $fixturePath 2>&1
    return [pscustomobject]@{
      ExitCode = $LASTEXITCODE
      Output = ($output -join [Environment]::NewLine)
    }
  }
  finally {
    Remove-Item -LiteralPath $fixturePath -Force -ErrorAction SilentlyContinue
  }
}

function Remove-MarkdownSection([string]$Text, [string]$SectionName) {
  $heading = "## $SectionName"
  $start = $Text.IndexOf($heading, [StringComparison]::Ordinal)
  if ($start -lt 0) { return $Text }
  $next = $Text.IndexOf("`n## ", $start + $heading.Length, [StringComparison]::Ordinal)
  if ($next -lt 0) { $next = $Text.Length }
  return ($Text.Substring(0, $start) + $Text.Substring($next)).TrimEnd()
}

$completeActivationSlice = @'
---
step_id: 01-validate-inputs
status: approved
result: complete
approval_source: human
produced_at: 2026-08-18
---

## Activation Slice

| Activation Slice ID | Applicability | Seam | Input | Output | Source Reference | Trace IDs | Disposition | Status | Decision Reference | Deferred Unit ID |
|---|---|---|---|---|---|---|---|---|---|---|
| ACT-001 | applicable | upstream-response | profile response | activation key | src/service:10 | TR-REQ-001, TR-UP-001 | reuse | verified | not-applicable | not-applicable |
| ACT-001 | applicable | requested-key | profile request | requested activation key | src/request:20 | TR-REQ-001, TR-KEY-001 | implement | verified | not-applicable | not-applicable |
| ACT-001 | applicable | parse-model | activation key | parsed model field | src/parser:30 | TR-REQ-001, TR-PARSE-001 | implement | verified | not-applicable | not-applicable |
| ACT-001 | applicable | state-holder | parsed model field | activation state | src/state:40 | TR-REQ-001, TR-STATE-001 | implement | verified | not-applicable | not-applicable |
| ACT-001 | applicable | selector | async-classification=async; activation state | initial-loading=spinner; update-watch=subscription; reselection=rerun; state-preservation-reset=preserve; failure-behavior=error | src/selector:50 | TR-REQ-001, TR-SELECT-001 | implement | verified | not-applicable | not-applicable |
| ACT-001 | applicable | construct | selected module | base-owned | src/router:60 | TR-REQ-001, TR-ROUTER-001 | reuse | verified | not-applicable | not-applicable |
| ACT-001 | applicable | render | constructed module | visible module | src/render:70 | TR-REQ-001, TR-RENDER-001 | reuse | verified | not-applicable | not-applicable |
| ACT-001 | applicable | downstream-consumer | selected module | deeplink and action flow | src/consumer:80 | TR-REQ-001, TR-CONSUME-001 | implement | verified | not-applicable | not-applicable |
| ACT-001 | applicable | test | complete activation flow | lifecycle-test-trace=TR-LIFECYCLE-001 | tests/activation:90 | TR-REQ-001, TR-LIFECYCLE-001 | implement | verified | not-applicable | not-applicable |
'@

if ($Cluster -in @('Yaml', 'All')) {
  $canonicalYamlControls = @(
    [pscustomobject]@{
      Name = 'single-quoted key and scalar'
      Text = $completeActivationSlice.Replace('status: approved', "'status': 'approved'")
    }
    [pscustomobject]@{
      Name = 'double-quoted key and scalar'
      Text = $completeActivationSlice.Replace('result: complete', '"result": "complete"')
    }
    [pscustomobject]@{
      Name = 'ordinary restricted plain scalar'
      Text = $completeActivationSlice.Replace('produced_at: 2026-08-18', 'produced_at: release-evidence-001')
    }
    [pscustomobject]@{
      Name = 'full-line YAML comment'
      Text = $completeActivationSlice.Replace('result: complete', "result: complete`n## Activation Slice")
    }
  )
  foreach ($control in $canonicalYamlControls) {
    $result = Invoke-ActivationSliceArtifactValidator $control.Text
    Assert-True ($result.ExitCode -eq 0) "Restricted YAML canonical control should pass: $($control.Name). Output: $($result.Output)"
  }

  $invalidYamlCases = @(
    [pscustomobject]@{
      Name = 'plain scalar continuation'
      Text = $completeActivationSlice.Replace('status: approved', "status: approved`n  continuation-changes-the-value")
    }
    [pscustomobject]@{
      Name = 'malformed opening single quote'
      Text = $completeActivationSlice.Replace('produced_at: 2026-08-18', "produced_at: 'unterminated")
    }
    [pscustomobject]@{
      Name = 'malformed closing single quote'
      Text = $completeActivationSlice.Replace('produced_at: 2026-08-18', "produced_at: unterminated'")
    }
    [pscustomobject]@{
      Name = 'malformed opening double quote'
      Text = $completeActivationSlice.Replace('produced_at: 2026-08-18', 'produced_at: "unterminated')
    }
    [pscustomobject]@{
      Name = 'malformed closing double quote'
      Text = $completeActivationSlice.Replace('produced_at: 2026-08-18', 'produced_at: unterminated"')
    }
    [pscustomobject]@{
      Name = 'reserved at indicator'
      Text = $completeActivationSlice.Replace('produced_at: 2026-08-18', 'produced_at: @reserved')
    }
    [pscustomobject]@{
      Name = 'reserved backtick indicator'
      Text = $completeActivationSlice.Replace('produced_at: 2026-08-18', 'produced_at: `reserved')
    }
    [pscustomobject]@{
      Name = 'block list'
      Text = $completeActivationSlice.Replace('produced_at: 2026-08-18', "metadata:`n  - release-evidence-001")
    }
    [pscustomobject]@{
      Name = 'unexpected block map'
      Text = $completeActivationSlice.Replace('produced_at: 2026-08-18', "metadata:`n  evidence: release-evidence-001")
    }
    [pscustomobject]@{
      Name = 'flow list'
      Text = $completeActivationSlice.Replace('produced_at: 2026-08-18', 'metadata: [release-evidence-001]')
    }
    [pscustomobject]@{
      Name = 'flow map'
      Text = $completeActivationSlice.Replace('produced_at: 2026-08-18', 'metadata: { evidence: release-evidence-001 }')
    }
    [pscustomobject]@{
      Name = 'tag'
      Text = $completeActivationSlice.Replace('produced_at: 2026-08-18', 'metadata: !release release-evidence-001')
    }
    [pscustomobject]@{
      Name = 'anchor'
      Text = $completeActivationSlice.Replace('produced_at: 2026-08-18', 'metadata: &release release-evidence-001')
    }
    [pscustomobject]@{
      Name = 'alias'
      Text = $completeActivationSlice.Replace('produced_at: 2026-08-18', 'metadata: *release')
    }
    [pscustomobject]@{
      Name = 'merge syntax'
      Text = $completeActivationSlice.Replace('produced_at: 2026-08-18', "produced_at: 2026-08-18`n<<: *defaults")
    }
    [pscustomobject]@{
      Name = 'tab-indented waiver key'
      Text = $completeActivationSlice.Replace(
        'produced_at: 2026-08-18',
        "produced_at: 2026-08-18`nwaiver:`n  `tpolicy: auto-waive"
      )
    }
    [pscustomobject]@{
      Name = 'top-level key without YAML separation after colon'
      Text = $completeActivationSlice.Replace('status: approved', 'status:approved')
    }
    [pscustomobject]@{
      Name = 'plain scalar ending in mapping indicator colon'
      Text = $completeActivationSlice.Replace('produced_at: 2026-08-18', 'produced_at: invalid:')
    }
    [pscustomobject]@{
      Name = 'Unicode whitespace around canonical scalar'
      Text = $completeActivationSlice.Replace('status: approved', "status: $([char]0x00A0)approved$([char]0x00A0)")
    }
    [pscustomobject]@{
      Name = 'missing required step_id'
      Text = $completeActivationSlice.Replace("step_id: 01-validate-inputs`n", '')
      Expected = 'front matter must contain exactly one step_id'
    }
    [pscustomobject]@{
      Name = 'missing required produced_at'
      Text = $completeActivationSlice.Replace("produced_at: 2026-08-18`n", '')
      Expected = 'front matter must contain exactly one produced_at'
    }
    [pscustomobject]@{
      Name = 'empty required step_id'
      Text = $completeActivationSlice.Replace('step_id: 01-validate-inputs', 'step_id:')
      Expected = 'invalid or ambiguous YAML front matter'
    }
  )
  foreach ($case in $invalidYamlCases) {
    $result = Invoke-ActivationSliceArtifactValidator $case.Text
    Assert-True ($result.ExitCode -eq 1) "Restricted YAML must reject $($case.Name). Output: $($result.Output)"
    $expected = if ([string]::IsNullOrWhiteSpace($case.Expected)) {
      'invalid or ambiguous YAML front matter'
    }
    else {
      $case.Expected
    }
    Assert-Contains $result.Output $expected "Restricted YAML $($case.Name)"
  }
}

if ($Cluster -in @('Resume', 'All')) {
  $contractText = Get-Content -Raw -Encoding utf8 (Join-Path $PSScriptRoot '../contracts/activation-slice.md')
  Assert-True ($contractText.Contains('## Step 10 resume evidence')) 'Activation Slice contract must canonically declare Step 10 resume evidence'
  Assert-True ($contractText.Contains('## Step 10 resume state')) 'Activation Slice contract must canonically declare Step 10 resume state'
  $nativeBlockerSectionName = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('QmxvY2tlciBn4buRYw=='))
  $changedFilesSectionName = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('RmlsZSDEkcOjIHRoYXkgxJHhu5Vp'))

  $waiverFrontMatter = @'
step_id: 10-code-migration
status: approved
result: partial
approval_source: auto-waive
waiver:
  policy: auto-waive
  category: environment-unavailable
  original_verdict: blocked
  effective_action: continue
  evidence: capability-evidence-001
'@
  $approvedWaiverYamlRecord = @'
```yaml
status: approved
result: partial
approval_source: auto-waive
waiver:
  policy: auto-waive
  category: environment-unavailable
  original_verdict: blocked
  effective_action: continue
  evidence: capability-evidence-001
```
'@
  $approvedWaiverBody = "## Approved Baseline Waiver`n`n$approvedWaiverYamlRecord"
  $nativeBlockerSection = @"
## $nativeBlockerSectionName

| Stage / Check | Native Verdict | Command Role | Required Command Lifecycle | Command / Capability | Observed Error | Evidence Reference |
|---|---|---|---|---|---|---|
| pre-mutation baseline | BLOCKED | availability probe | not-started | target-test capability | capability unavailable | capability-evidence-001 |
"@
  $selectedUnitSection = @'
## Selected Migration Unit

| Migration Unit ID | Plan Reference | Approval Reference | Mode Constraint | Bootstrap Scope | Foundation Baseline ID | Foundation Baseline Reference | Foundation Baseline Approval Reference | Baseline Reference | Trace IDs |
|---|---|---|---|---|---|---|---|---|---|
| UNIT-001 | plan-001 | approval-001 | incremental/preserve-existing | not-required | not-applicable | not-applicable | not-applicable | capability-evidence-001 | TR-REQ-001, TR-RENDER-001 |
'@
  $implementationLinks = @"
## $changedFilesSectionName

| Migration Unit ID | Activation Slice ID | Seam | File | Change | Trace IDs |
|---|---|---|---|---|---|
| UNIT-001 | ACT-001 | render | target/render.dart | render the selected module | TR-REQ-001, TR-RENDER-001 |

## Activation Slice Test Evidence

| Migration Unit ID | Activation Slice ID | Seam | Test | Command | Result | Trace IDs |
|---|---|---|---|---|---|---|
| UNIT-001 | ACT-001 | test | activation lifecycle | test activation | PASS | TR-REQ-001, TR-LIFECYCLE-001 |
"@
  $resumePredecessorState = @'
## Step 10 Waiver Resume State

| Resume Phase | Baseline Action | Implementation Status | Target Mutation Evidence | Waiver Evidence |
|---|---|---|---|---|
| resume-required | skip-pre-mutation-baseline-only | blocked | none | capability-evidence-001 |
'@
  $resumeCurrentState = @'
## Step 10 Waiver Resume State

| Resume Phase | Baseline Action | Implementation Status | Target Mutation Evidence | Waiver Evidence |
|---|---|---|---|---|
| resume-consumed | skip-pre-mutation-baseline-only | implementation-complete | target/render.dart; UNIT-001; TR-REQ-001 | capability-evidence-001 |
'@
  $step10ResumeEnvelope = $completeActivationSlice.Replace(
    "step_id: 01-validate-inputs`nstatus: approved`nresult: complete`napproval_source: human`nproduced_at: 2026-08-18",
    "$waiverFrontMatter`nproduced_at: 2026-08-18"
  ).TrimEnd() + "`n`n$selectedUnitSection`n`n$nativeBlockerSection`n`n$approvedWaiverBody"
  $waiverResumePredecessor = "$step10ResumeEnvelope`n`n$resumePredecessorState"
  $waiverResumeCurrent = "$step10ResumeEnvelope`n`n$implementationLinks`n`n$resumeCurrentState"

  $validResumeResult = Invoke-ActivationSliceArtifactValidator $waiverResumeCurrent $waiverResumePredecessor
  Assert-True ($validResumeResult.ExitCode -eq 0) "A complete canonical step-10 resume evidence chain should pass. Output: $($validResumeResult.Output)"

  $editedResumePredecessor = "$waiverResumePredecessor`n`n$implementationLinks"
  $editedResumePredecessorResult = Invoke-ActivationSliceArtifactValidator $waiverResumeCurrent $editedResumePredecessor
  Assert-True ($editedResumePredecessorResult.ExitCode -eq 1) "A resume-required predecessor must not already carry target implementation evidence. Output: $($editedResumePredecessorResult.Output)"
  Assert-Contains $editedResumePredecessorResult.Output 'resume predecessor must not contain implementation evidence before re-entry' 'Pre-resume target mutation absence'

  $invalidResumeFoundationRow = '| UNIT-001 | plan-001 | approval-001 | incremental/preserve-existing | not-required | FOUNDATION-FAKE | fake-foundation-reference | fake-foundation-approval | capability-evidence-001 | TR-REQ-001, TR-RENDER-001 |'
  $invalidResumeFoundationCurrent = $waiverResumeCurrent.Replace(
    '| UNIT-001 | plan-001 | approval-001 | incremental/preserve-existing | not-required | not-applicable | not-applicable | not-applicable | capability-evidence-001 | TR-REQ-001, TR-RENDER-001 |',
    $invalidResumeFoundationRow
  )
  $invalidResumeFoundationPredecessor = $waiverResumePredecessor.Replace(
    '| UNIT-001 | plan-001 | approval-001 | incremental/preserve-existing | not-required | not-applicable | not-applicable | not-applicable | capability-evidence-001 | TR-REQ-001, TR-RENDER-001 |',
    $invalidResumeFoundationRow
  )
  $invalidResumeFoundationResult = Invoke-ActivationSliceArtifactValidator $invalidResumeFoundationCurrent $invalidResumeFoundationPredecessor
  Assert-True ($invalidResumeFoundationResult.ExitCode -eq 1) "A resume pair must not launder an incremental selected unit carrying a foundation tuple. Output: $($invalidResumeFoundationResult.Output)"
  Assert-Contains $invalidResumeFoundationResult.Output 'selected unit violates canonical incremental foundation predicates' 'Resume intrinsic incremental foundation state'

  $underscoreTraceCurrent = $waiverResumeCurrent.Replace('TR-REQ-001', 'TR_REQ_001')
  $underscoreTracePredecessor = $waiverResumePredecessor.Replace('TR-REQ-001', 'TR_REQ_001')
  $underscoreTraceResult = Invoke-ActivationSliceArtifactValidator $underscoreTraceCurrent $underscoreTracePredecessor
  Assert-True ($underscoreTraceResult.ExitCode -eq 0) "A non-empty selected Trace ID containing underscore must remain valid resume evidence. Output: $($underscoreTraceResult.Output)"

  $commentOnlyWaiverCurrent = $waiverResumeCurrent.Replace(
    $approvedWaiverYamlRecord,
    "<!--`n$approvedWaiverYamlRecord`n-->"
  )
  $commentOnlyWaiverResult = Invoke-ActivationSliceArtifactValidator $commentOnlyWaiverCurrent $waiverResumePredecessor
  Assert-True ($commentOnlyWaiverResult.ExitCode -eq 1) "A resume waiver YAML fence hidden in an HTML comment must not satisfy the body record. Output: $($commentOnlyWaiverResult.Output)"
  Assert-Contains $commentOnlyWaiverResult.Output 'resume current approved-waiver YAML record must appear exactly once; found 0' 'Comment-only resume waiver body'

  $nestedWaiverYamlRecord = @'
````text
```yaml
status: approved
result: partial
approval_source: auto-waive
waiver:
  policy: auto-waive
  category: environment-unavailable
  original_verdict: blocked
  effective_action: continue
  evidence: capability-evidence-001
```
````
'@
  $nestedWaiverBody = "## Approved Baseline Waiver`n`n$nestedWaiverYamlRecord"
  $nestedWaiverCurrent = $waiverResumeCurrent.Replace($approvedWaiverBody, $nestedWaiverBody)
  $nestedWaiverPredecessor = $waiverResumePredecessor.Replace($approvedWaiverBody, $nestedWaiverBody)
  $nestedWaiverResult = Invoke-ActivationSliceArtifactValidator $nestedWaiverCurrent $nestedWaiverPredecessor
  Assert-True ($nestedWaiverResult.ExitCode -eq 1) "A YAML-looking fence nested inside a longer outer fence must not satisfy the waiver record. Output: $($nestedWaiverResult.Output)"
  Assert-Contains $nestedWaiverResult.Output 'resume current approved-waiver YAML record must appear exactly once; found 0' 'Nested resume waiver fence'

  $unseparatedWaiverCurrent = $waiverResumeCurrent.Replace('  policy: auto-waive', '  policy:auto-waive')
  $unseparatedWaiverResult = Invoke-ActivationSliceArtifactValidator $unseparatedWaiverCurrent $waiverResumePredecessor
  Assert-True ($unseparatedWaiverResult.ExitCode -eq 1) "A waiver mapping key requires YAML separation after its colon. Output: $($unseparatedWaiverResult.Output)"
  Assert-Contains $unseparatedWaiverResult.Output 'invalid or ambiguous YAML' 'Waiver key without YAML separation'

  $fourBacktickWaiverRecord = $approvedWaiverYamlRecord.Replace('```yaml', '````yaml')
  $fourBacktickWaiverRecord = [regex]::Replace($fourBacktickWaiverRecord, '(?m)^```$', '````')
  $fourBacktickCurrent = $waiverResumeCurrent.Replace($approvedWaiverYamlRecord, $fourBacktickWaiverRecord)
  $fourBacktickPredecessor = $waiverResumePredecessor.Replace($approvedWaiverYamlRecord, $fourBacktickWaiverRecord)
  $fourBacktickResult = Invoke-ActivationSliceArtifactValidator $fourBacktickCurrent $fourBacktickPredecessor
  Assert-True ($fourBacktickResult.ExitCode -eq 0) "A genuine four-backtick yaml waiver record must be accepted. Output: $($fourBacktickResult.Output)"

  foreach ($targetEvidence in @(
    'target/render.dart, UNIT-001, TR-REQ-001',
    'changed target/render.dart for UNIT-001 under trace TR-REQ-001'
  )) {
    $flexibleEvidenceCurrent = $waiverResumeCurrent.Replace(
      'target/render.dart; UNIT-001; TR-REQ-001',
      $targetEvidence
    )
    $flexibleEvidenceResult = Invoke-ActivationSliceArtifactValidator $flexibleEvidenceCurrent $waiverResumePredecessor
    Assert-True ($flexibleEvidenceResult.ExitCode -eq 0) "Target mutation evidence may use ordinary exact-name prose, <$targetEvidence>. Output: $($flexibleEvidenceResult.Output)"
  }
  $embeddedNameEvidenceCurrent = $waiverResumeCurrent.Replace(
    'target/render.dart; UNIT-001; TR-REQ-001',
    'changed target for XUNIT-001Y under XTR-REQ-001Y'
  )
  $embeddedNameEvidenceResult = Invoke-ActivationSliceArtifactValidator $embeddedNameEvidenceCurrent $waiverResumePredecessor
  Assert-True ($embeddedNameEvidenceResult.ExitCode -eq 1) "Target mutation evidence must name exact selected IDs, not merely embed them in larger tokens. Output: $($embeddedNameEvidenceResult.Output)"
  Assert-Contains $embeddedNameEvidenceResult.Output 'resume target mutation evidence must name selected Migration Unit ID and Trace ID' 'Exact target mutation evidence names'

  $greenfieldResumeCurrent = $waiverResumeCurrent.Replace('incremental/preserve-existing', 'greenfield/design-new')
  $greenfieldResumePredecessor = $waiverResumePredecessor.Replace('incremental/preserve-existing', 'greenfield/design-new')
  $greenfieldResumeResult = Invoke-ActivationSliceArtifactValidator $greenfieldResumeCurrent $greenfieldResumePredecessor
  Assert-True ($greenfieldResumeResult.ExitCode -eq 1) "The baseline-waiver resume route must remain incremental/not-required. Output: $($greenfieldResumeResult.Output)"
  Assert-Contains $greenfieldResumeResult.Output 'resume selected-unit Mode Constraint must be incremental/preserve-existing' 'Greenfield waiver resume rejection'

  $wrongBaselineCurrent = $waiverResumeCurrent.Replace('| capability-evidence-001 | TR-REQ-001, TR-RENDER-001 |', '| unrelated-baseline-002 | TR-REQ-001, TR-RENDER-001 |')
  $wrongBaselinePredecessor = $waiverResumePredecessor.Replace('| capability-evidence-001 | TR-REQ-001, TR-RENDER-001 |', '| unrelated-baseline-002 | TR-REQ-001, TR-RENDER-001 |')
  $wrongBaselineResult = Invoke-ActivationSliceArtifactValidator $wrongBaselineCurrent $wrongBaselinePredecessor
  Assert-True ($wrongBaselineResult.ExitCode -eq 1) "Resume Baseline Reference must equal the approved waiver evidence. Output: $($wrongBaselineResult.Output)"
  Assert-Contains $wrongBaselineResult.Output 'resume selected-unit Baseline Reference must equal waiver.evidence ordinally' 'Resume baseline/waiver evidence consistency'

  $ineligibleNativeRow = '| pre-mutation baseline | PASS | required test/build/baseline command | started-and-produced-correctness/regression-result | target-test capability | required command failed | capability-evidence-001 |'
  $ineligibleNativeCurrent = $waiverResumeCurrent.Replace('| pre-mutation baseline | BLOCKED | availability probe | not-started | target-test capability | capability unavailable | capability-evidence-001 |', $ineligibleNativeRow)
  $ineligibleNativePredecessor = $waiverResumePredecessor.Replace('| pre-mutation baseline | BLOCKED | availability probe | not-started | target-test capability | capability unavailable | capability-evidence-001 |', $ineligibleNativeRow)
  $ineligibleNativeResult = Invoke-ActivationSliceArtifactValidator $ineligibleNativeCurrent $ineligibleNativePredecessor
  Assert-True ($ineligibleNativeResult.ExitCode -eq 1) "A resume native-blocker row must retain the existing eligible command role/lifecycle. Output: $($ineligibleNativeResult.Output)"
  Assert-Contains $ineligibleNativeResult.Output 'resume native-blocker record violates canonical baseline-resume eligibility' 'Resume native blocker semantics'

  $literalEvidence = "evidence: |-`n    capability-evidence-001`n`n    second paragraph"
  $literalWaiverCurrent = $waiverResumeCurrent.Replace('evidence: capability-evidence-001', $literalEvidence)
  $literalWaiverPredecessor = $waiverResumePredecessor.Replace('evidence: capability-evidence-001', $literalEvidence)
  $literalWaiverResult = Invoke-ActivationSliceArtifactValidator $literalWaiverCurrent $literalWaiverPredecessor
  Assert-NotContains $literalWaiverResult.Output 'invalid or ambiguous YAML front matter' 'Unindented blank line in supported waiver literal block scalar'

  $requiredResumeSections = @($nativeBlockerSectionName, 'Approved Baseline Waiver', 'Step 10 Waiver Resume State')
  foreach ($section in $requiredResumeSections) {
    foreach ($role in @('current', 'predecessor')) {
      $current = $waiverResumeCurrent
      $predecessor = $waiverResumePredecessor
      if ($role -ceq 'current') { $current = Remove-MarkdownSection $current $section }
      else { $predecessor = Remove-MarkdownSection $predecessor $section }
      $result = Invoke-ActivationSliceArtifactValidator $current $predecessor
      Assert-True ($result.ExitCode -eq 1) "Step-10 resume must reject missing $role $section. Output: $($result.Output)"
      Assert-Contains $result.Output "resume $role $section section must appear exactly once; found 0" "Step-10 resume missing $role $section"
    }
  }

  $duplicateResumeCases = @(
    [pscustomobject]@{
      Name = 'duplicate native blocker section'
      Text = "$waiverResumeCurrent`n`n$nativeBlockerSection"
      Expected = "resume current $nativeBlockerSectionName section must appear exactly once; found 2"
    }
    [pscustomobject]@{
      Name = 'duplicate native blocker table'
      Text = $waiverResumeCurrent.Replace(
        '| pre-mutation baseline | BLOCKED | availability probe | not-started | target-test capability | capability unavailable | capability-evidence-001 |',
        "| pre-mutation baseline | BLOCKED | availability probe | not-started | target-test capability | capability unavailable | capability-evidence-001 |`n`n| Stage / Check | Native Verdict | Command Role | Required Command Lifecycle | Command / Capability | Observed Error | Evidence Reference |`n|---|---|---|---|---|---|---|`n| pre-mutation baseline | BLOCKED | availability probe | not-started | target-test capability | capability unavailable | capability-evidence-001 |"
      )
      Expected = 'resume current native-blocker table must appear exactly once; found 2'
    }
    [pscustomobject]@{
      Name = 'duplicate approved waiver section'
      Text = "$waiverResumeCurrent`n`n$approvedWaiverBody"
      Expected = 'resume current Approved Baseline Waiver section must appear exactly once; found 2'
    }
    [pscustomobject]@{
      Name = 'duplicate approved waiver body'
      Text = $waiverResumeCurrent.Replace($approvedWaiverBody, "$approvedWaiverBody`n`n$approvedWaiverYamlRecord")
      Expected = 'resume current approved-waiver YAML record must appear exactly once; found 2'
    }
    [pscustomobject]@{
      Name = 'duplicate resume-state section'
      Text = "$waiverResumeCurrent`n`n$resumeCurrentState"
      Expected = 'resume current Step 10 Waiver Resume State section must appear exactly once; found 2'
    }
    [pscustomobject]@{
      Name = 'duplicate resume-state table'
      Text = $waiverResumeCurrent.Replace(
        '| resume-consumed | skip-pre-mutation-baseline-only | implementation-complete | target/render.dart; UNIT-001; TR-REQ-001 | capability-evidence-001 |',
        "| resume-consumed | skip-pre-mutation-baseline-only | implementation-complete | target/render.dart; UNIT-001; TR-REQ-001 | capability-evidence-001 |`n`n| Resume Phase | Baseline Action | Implementation Status | Target Mutation Evidence | Waiver Evidence |`n|---|---|---|---|---|`n| resume-consumed | skip-pre-mutation-baseline-only | implementation-complete | target/render.dart; UNIT-001; TR-REQ-001 | capability-evidence-001 |"
      )
      Expected = 'resume current resume-state table must appear exactly once; found 2'
    }
  )
  foreach ($case in $duplicateResumeCases) {
    $result = Invoke-ActivationSliceArtifactValidator $case.Text $waiverResumePredecessor
    Assert-True ($result.ExitCode -eq 1) "Step-10 resume must reject $($case.Name). Output: $($result.Output)"
    Assert-Contains $result.Output $case.Expected "Step-10 resume $($case.Name)"
  }

  $preservationCases = @(
    [pscustomobject]@{
      Name = 'native blocker evidence mutation'
      Text = $waiverResumeCurrent.Replace('capability unavailable | capability-evidence-001 |', 'different capability error | capability-evidence-001 |')
      Expected = 'resume native-blocker record must match predecessor ordinally'
    }
    [pscustomobject]@{
      Name = 'approved waiver body mutation'
      Text = $waiverResumeCurrent.Replace(
        $approvedWaiverBody,
        $approvedWaiverBody.Replace('evidence: capability-evidence-001', 'evidence: body-evidence-002')
      )
      Expected = 'resume approved-waiver body must match front matter and predecessor ordinally'
    }
    [pscustomobject]@{
      Name = 'resume phase mutation'
      Text = $waiverResumeCurrent.Replace('| resume-consumed |', '| resume-required |')
      Expected = 'resume current state must match the canonical current row'
    }
    [pscustomobject]@{
      Name = 'baseline action mutation'
      Text = $waiverResumeCurrent.Replace('| resume-consumed | skip-pre-mutation-baseline-only |', '| resume-consumed | rerun-baseline |')
      Expected = 'resume current state must match the canonical current row'
    }
    [pscustomobject]@{
      Name = 'blocked implementation status'
      Text = $waiverResumeCurrent.Replace('| implementation-complete |', '| blocked |')
      Expected = 'resume current state must match the canonical current row'
    }
    [pscustomobject]@{
      Name = 'waiver evidence mutation'
      Text = $waiverResumeCurrent.Replace('| capability-evidence-001 |', '| waiver-evidence-002 |')
      Expected = 'resume state Waiver Evidence must equal waiver.evidence ordinally'
    }
    [pscustomobject]@{
      Name = 'no target mutation'
      Text = $waiverResumeCurrent.Replace('| target/render.dart; UNIT-001; TR-REQ-001 |', '| none |')
      Expected = 'resume target mutation evidence must name selected Migration Unit ID and Trace ID'
    }
    [pscustomobject]@{
      Name = 'target mutation omits unit'
      Text = $waiverResumeCurrent.Replace('| target/render.dart; UNIT-001; TR-REQ-001 |', '| target/render.dart; TR-REQ-001 |')
      Expected = 'resume target mutation evidence must name selected Migration Unit ID and Trace ID'
    }
    [pscustomobject]@{
      Name = 'target mutation omits selected trace'
      Text = $waiverResumeCurrent.Replace('| target/render.dart; UNIT-001; TR-REQ-001 |', '| target/render.dart; UNIT-001; TR-OTHER-001 |')
      Expected = 'resume target mutation evidence must name selected Migration Unit ID and Trace ID'
    }
  )
  foreach ($case in $preservationCases) {
    $result = Invoke-ActivationSliceArtifactValidator $case.Text $waiverResumePredecessor
    Assert-True ($result.ExitCode -eq 1) "Step-10 resume must reject $($case.Name). Output: $($result.Output)"
    Assert-Contains $result.Output $case.Expected "Step-10 resume $($case.Name)"
  }

  $selectedUnitCells = @(
    'UNIT-001', 'plan-001', 'approval-001', 'incremental/preserve-existing', 'not-required',
    'not-applicable', 'not-applicable', 'not-applicable', 'capability-evidence-001',
    'TR-REQ-001, TR-RENDER-001'
  )
  $selectedUnitRow = '| ' + ($selectedUnitCells -join ' | ') + ' |'
  $selectedUnitMutations = @()
  $selectedUnitMutationValues = @(
    'UNIT-002', 'plan-002', 'approval-002', 'greenfield/design-new', 'required',
    'FOUNDATION-002', 'baseline-002', 'foundation-approval-002', 'capability-evidence-002',
    'TR-REQ-001, TR-OTHER-001'
  )
  $selectedUnitColumns = @(
    'Migration Unit ID', 'Plan Reference', 'Approval Reference', 'Mode Constraint', 'Bootstrap Scope',
    'Foundation Baseline ID', 'Foundation Baseline Reference', 'Foundation Baseline Approval Reference',
    'Baseline Reference', 'Trace IDs'
  )
  for ($fieldIndex = 0; $fieldIndex -lt $selectedUnitColumns.Count; $fieldIndex++) {
    $mutatedCells = @($selectedUnitCells)
    $mutatedCells[$fieldIndex] = $selectedUnitMutationValues[$fieldIndex]
    $selectedUnitMutations += [pscustomobject]@{
      Field = $selectedUnitColumns[$fieldIndex]
      Row = '| ' + ($mutatedCells -join ' | ') + ' |'
    }
  }
  foreach ($mutation in $selectedUnitMutations) {
    $mutatedCurrent = $waiverResumeCurrent.Replace($selectedUnitRow, $mutation.Row)
    $result = Invoke-ActivationSliceArtifactValidator $mutatedCurrent $waiverResumePredecessor
    Assert-True ($result.ExitCode -eq 1) "Step-10 resume must reject selected-unit $($mutation.Field) mutation. Output: $($result.Output)"
    Assert-Contains $result.Output "resume selected-unit field changed: $($mutation.Field)" "Step-10 resume selected-unit $($mutation.Field)"
  }

  $step11AfterResume = $completeActivationSlice.Replace(
    'step_id: 01-validate-inputs',
    'step_id: 11-ai-review'
  ).TrimEnd() + "`n`n$selectedUnitSection"
  $postWaiverResult = Invoke-ActivationSliceArtifactValidator $step11AfterResume $waiverResumeCurrent
  Assert-True ($postWaiverResult.ExitCode -eq 0) "Step 11 must accept a self-consistent completed step-10 waiver resume. Output: $($postWaiverResult.Output)"

  foreach ($section in @($nativeBlockerSectionName, 'Approved Baseline Waiver', 'Step 10 Waiver Resume State', $changedFilesSectionName, 'Activation Slice Test Evidence')) {
    $incompleteResumePredecessor = Remove-MarkdownSection $waiverResumeCurrent $section
    $result = Invoke-ActivationSliceArtifactValidator $step11AfterResume $incompleteResumePredecessor
    Assert-True ($result.ExitCode -eq 1) "Step 11 must reject a partial step-10 predecessor missing $section. Output: $($result.Output)"
    $expectedDiagnostic = switch -CaseSensitive ($section) {
      $changedFilesSectionName { 'changed-file structured section' }
      'Activation Slice Test Evidence' { 'test-evidence structured section' }
      default { $section }
    }
    Assert-Contains $result.Output $expectedDiagnostic "Post-waiver predecessor missing $section"
  }
}

if ($Cluster -in @('Orchestrator', 'All')) {
  $migrationOrchestratorText = Get-Content -Raw -Encoding utf8 (
    Join-Path $PSScriptRoot '../skills/aitoolkit/migrate/SKILL.md'
  )
  Assert-True (
    $migrationOrchestratorText.Contains('| `complete` | soft |')
  ) 'Migration orchestrator generic soft-gate approval must be complete-only'
  Assert-True (
    $migrationOrchestratorText.Contains('result: complete | blocked')
  ) 'Migration orchestrator shared-step envelope lifecycle must be complete-or-blocked'
  Assert-True (
    $migrationOrchestratorText.Contains(
      'Partial is route-specific: only an approved step-01 input-qualification artifact or the exact resumed step-10 approved/partial/auto-waive tuple may continue; every other partial artifact stops as invalid.'
    )
  ) 'Migration orchestrator must declare the two exact route-authorized partial states'
  Assert-True (
    $migrationOrchestratorText.Contains(
      'An environment waiver never advances a non-step-10 artifact as partial.'
    )
  ) 'Migration orchestrator must forbid generic environment-waiver downstream continuation'
  foreach ($forbiddenGenericPartial in @(
    '| `complete` or `partial` | soft |'
    'result: complete | partial | blocked'
    'Artifact có `status: approved` và `result: complete` hoặc `partial`'
    'với `result: complete` hoặc `partial`, không hỏi người dùng'
  )) {
    Assert-True (
      -not $migrationOrchestratorText.Contains($forbiddenGenericPartial)
    ) "Migration orchestrator must not retain generic partial authorization: $forbiddenGenericPartial"
  }
}

if ($Cluster -in @('Downstream', 'All')) {
  $contractText = Get-Content -Raw -Encoding utf8 (Join-Path $PSScriptRoot '../contracts/activation-slice.md')
  Assert-True ($contractText.Contains('## Downstream selected-unit handoff')) 'Activation Slice contract must canonically declare downstream selected-unit handoff'
  Assert-True ($contractText.Contains('## Regression parity handoff')) 'Activation Slice contract must canonically declare regression parity handoff'
  $parityTemplateText = Get-Content -Raw -Encoding utf8 (Join-Path $PSScriptRoot '../templates/migration/parity-report.md')
  Assert-True ($parityTemplateText.Contains('## Parity Verdict')) 'Parity report template must render the canonical structured overall parity verdict section'
  $legacyParityConclusion = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('IyMgS+G6v3QgbHXhuq1u'))
  Assert-True (-not $parityTemplateText.Contains($legacyParityConclusion)) 'Parity report template must use the structured Parity Verdict row as its sole overall verdict surface'
  Assert-True ($parityTemplateText.Contains('| Parity Verdict | Evidence Reference |')) 'Parity report template must render the canonical parity verdict/evidence columns'
  Assert-True ($parityTemplateText.Contains('<pass / fail / blocked>')) 'Parity scenario placeholder must not contain raw structural table pipes'
  $regressionTemplateText = Get-Content -Raw -Encoding utf8 (Join-Path $PSScriptRoot '../templates/migration/regression-report.md')
  $legacyRegressionHeadingCount = [regex]::Matches(
    $regressionTemplateText,
    '(?m)^' + [regex]::Escape($legacyParityConclusion) + '[ \t]*$'
  ).Count
  Assert-True ($legacyRegressionHeadingCount -eq 0) 'Regression report template must use its structured conclusion row as the sole overall verdict surface'
  Assert-True (
    $regressionTemplateText.Contains('| Scenario | Baseline | Actual | Delta Class | Waiver Reference | Trace IDs | Verdict |')
  ) 'Regression scenario template must expose the complete skill-required evidence schema'
  Assert-True ($regressionTemplateText.Contains('<pass / fail / blocked>')) 'Regression scenario placeholder must not contain raw structural table pipes'
  $completeParityPlaceholder = [Text.Encoding]::UTF8.GetString(
    [Convert]::FromBase64String('fCA8cGFzcyBob+G6t2MgZmFpbD4gfCA8cmVxdWlyZWQ+IHw=')
  )
  Assert-True ($regressionTemplateText.Contains($completeParityPlaceholder)) 'Regression report template must preserve only a lifecycle-valid complete parity predecessor verdict'
  foreach ($lifecycleFile in @(
    [pscustomobject]@{ Name = 'discovery'; Path = '../skills/migration/discovery/SKILL.md' }
    [pscustomobject]@{ Name = 'analyze-requirements-uiux'; Path = '../skills/migration/analyze-requirements-uiux/SKILL.md' }
    [pscustomobject]@{ Name = 'build-inventory'; Path = '../skills/migration/build-inventory/SKILL.md' }
    [pscustomobject]@{ Name = 'feature-mapping'; Path = '../skills/migration/feature-mapping/SKILL.md' }
    [pscustomobject]@{ Name = 'analyze-gaps-conflicts'; Path = '../skills/migration/analyze-gaps-conflicts/SKILL.md' }
    [pscustomobject]@{ Name = 'technical-design'; Path = '../skills/migration/technical-design/SKILL.md' }
    [pscustomobject]@{ Name = 'plan-waves'; Path = '../skills/migration/plan-waves/SKILL.md' }
    [pscustomobject]@{ Name = 'bootstrap-target'; Path = '../skills/migration/bootstrap-target/SKILL.md' }
    [pscustomobject]@{ Name = 'verify-parity'; Path = '../skills/migration/verify-parity/SKILL.md' }
    [pscustomobject]@{ Name = 'verify-regression'; Path = '../skills/migration/verify-regression/SKILL.md' }
    [pscustomobject]@{ Name = 'ai-review migration extension'; Path = '../skills/shared/ai-review/SKILL.md' }
    [pscustomobject]@{ Name = 'verification-testing migration extension'; Path = '../skills/shared/verification-testing/SKILL.md' }
    [pscustomobject]@{ Name = 'review migration template'; Path = '../templates/migration/review-report.md' }
    [pscustomobject]@{ Name = 'verification migration template'; Path = '../templates/migration/verification-report.md' }
  )) {
    $lifecycleText = Get-Content -Raw -Encoding utf8 (Join-Path $PSScriptRoot $lifecycleFile.Path)
    Assert-True (-not $lifecycleText.Contains('result: complete | partial | blocked')) "$($lifecycleFile.Name) must not authorize partial outside the exact step-10 waiver lifecycle"
    Assert-True ($lifecycleText.Contains('result: complete | blocked')) "$($lifecycleFile.Name) must declare the canonical complete-or-blocked result set"
  }
  $verificationSkillText = Get-Content -Raw -Encoding utf8 (Join-Path $PSScriptRoot '../skills/shared/verification-testing/SKILL.md')
  Assert-True (
    -not ($verificationSkillText.Contains('`status: approved`, `result: partial`'))
  ) 'Migration verification must not authorize a step-12 approved/partial rewrite'
  $regressionConclusionSection = [Text.Encoding]::UTF8.GetString(
    [Convert]::FromBase64String('S+G6v3QgbHXhuq1uIHjDoWMgbWluaCBtaWdyYXRpb24=')
  )
  $downstreamSelectedUnitSection = @'
## Selected Migration Unit

| Migration Unit ID | Plan Reference | Approval Reference | Mode Constraint | Bootstrap Scope | Foundation Baseline ID | Foundation Baseline Reference | Foundation Baseline Approval Reference | Baseline Reference | Trace IDs |
|---|---|---|---|---|---|---|---|---|---|
| UNIT-001 | plan-001 | approval-001 | incremental/preserve-existing | not-required | not-applicable | not-applicable | not-applicable | regression-baseline-001 | TR-REQ-001, TR-RENDER-001 |
'@
  $parityVerdictSection = @'
## Parity Verdict

| Parity Verdict | Evidence Reference |
|---|---|
| pass | parity-evidence-001 |
'@
  $regressionConclusion = @"
## $regressionConclusionSection

| Parity Verdict | Regression Applicability | Regression Verdict | Evidence Reference |
|---|---|---|---|
| pass | required | pass | parity-evidence-001; regression-evidence-001 |
"@
  $assuranceScenarioSection = [Text.Encoding]::UTF8.GetString(
    [Convert]::FromBase64String('IyMgS+G7i2NoIGLhuqNuCgp8IFNjZW5hcmlvIHwgQmFzZWxpbmUgfCBBY3R1YWwgfCBWZXJkaWN0IHwKfC0tLXwtLS18LS0tfC0tLXwKfCBhY3RpdmF0aW9uIHBhcml0eSB8IHNvdXJjZSB8IHRhcmdldCB8IHBhc3MgfA==')
  )
  $assuranceScenarioSectionName = [Text.Encoding]::UTF8.GetString(
    [Convert]::FromBase64String('S+G7i2NoIGLhuqNu')
  )
  $regressionScenarioSection = @"
## $assuranceScenarioSectionName

| Scenario | Baseline | Actual | Delta Class | Waiver Reference | Trace IDs | Verdict |
|---|---|---|---|---|---|---|
| activation parity | source | target | expected | not-applicable | TR-REQ-001 | pass |
"@
  $verificationProvenanceSection = @'
## Task Provenance

| Task / Unit | Task-base SHA | Final-tree SHA | Source Artifact |
|---|---|---|---|
| UNIT-001 | base-sha-001 | final-sha-001 | <IMMEDIATE_PREDECESSOR_PATH> |
'@
  $parityProvenanceSection = $verificationProvenanceSection
  $regressionProvenanceSection = $verificationProvenanceSection
  $reviewChangeHygieneSection = @'
## Change Hygiene

| Task / Unit | Scope Evidence | Formatter Evidence | Unrelated Diff | Severity | Task-base SHA | Final-tree SHA |
|---|---|---|---|---|---|---|
| UNIT-001 | target/render.dart | formatter-not-required | none | none | base-sha-001 | final-sha-001 |
'@
  $domainBlockerSection = @'
## Domain Blocker

| Blocker | Evidence Reference |
|---|---|
| required assurance command unavailable | command-resolution-evidence-001 |
'@
  $downstreamChangedFilesSection = [Text.Encoding]::UTF8.GetString(
    [Convert]::FromBase64String('RmlsZSDEkcOjIHRoYXkgxJHhu5Vp')
  )
  $downstreamImplementationEvidence = @"
## $downstreamChangedFilesSection

| Migration Unit ID | Activation Slice ID | Seam | File | Change | Trace IDs |
|---|---|---|---|---|---|
| UNIT-001 | ACT-001 | render | target/render.dart | render selected unit | TR-REQ-001, TR-RENDER-001 |

## Activation Slice Test Evidence

| Migration Unit ID | Activation Slice ID | Seam | Test | Command | Result | Trace IDs |
|---|---|---|---|---|---|---|
| UNIT-001 | ACT-001 | test | activation lifecycle | test activation | PASS | TR-REQ-001, TR-LIFECYCLE-001 |
"@

  function New-DownstreamArtifact([string]$StepId, [string]$Extra = '') {
    $artifact = $completeActivationSlice.Replace(
      'step_id: 01-validate-inputs',
      "step_id: $StepId"
    ).TrimEnd() + "`n`n$downstreamSelectedUnitSection"
    if (-not [string]::IsNullOrWhiteSpace($Extra)) { $artifact += "`n`n$Extra" }
    return $artifact
  }

  $downstreamArtifacts = [ordered]@{
    implementation = New-DownstreamArtifact '10-code-migration' $downstreamImplementationEvidence
    review = New-DownstreamArtifact '11-ai-review' $reviewChangeHygieneSection
    verification = New-DownstreamArtifact '12-verification-testing' $verificationProvenanceSection
    parity = New-DownstreamArtifact '13-verify-parity' "$parityVerdictSection`n`n$assuranceScenarioSection`n`n$parityProvenanceSection"
    regression = New-DownstreamArtifact '14-verify-regression' "$regressionConclusion`n`n$regressionScenarioSection`n`n$regressionProvenanceSection"
  }
  $downstreamLinks = @(
    [pscustomobject]@{ Name = 'implementation to review'; Predecessor = 'implementation'; Current = 'review' }
    [pscustomobject]@{ Name = 'review to verification'; Predecessor = 'review'; Current = 'verification' }
    [pscustomobject]@{ Name = 'verification to parity'; Predecessor = 'verification'; Current = 'parity' }
    [pscustomobject]@{ Name = 'parity to regression'; Predecessor = 'parity'; Current = 'regression' }
  )
  foreach ($link in $downstreamLinks) {
    $result = Invoke-ActivationSliceArtifactValidator $downstreamArtifacts[$link.Current] $downstreamArtifacts[$link.Predecessor]
    Assert-True ($result.ExitCode -eq 0) "Canonical downstream selected-unit handoff should pass: $($link.Name). Output: $($result.Output)"

    $missingSelectedUnit = Remove-MarkdownSection $downstreamArtifacts[$link.Current] 'Selected Migration Unit'
    $missingResult = Invoke-ActivationSliceArtifactValidator $missingSelectedUnit $downstreamArtifacts[$link.Predecessor]
    Assert-True ($missingResult.ExitCode -eq 1) "Downstream selected-unit removal should block: $($link.Name). Output: $($missingResult.Output)"
    Assert-Contains $missingResult.Output 'route current Selected Migration Unit section must appear exactly once; found 0' "Downstream selected-unit removal: $($link.Name)"

    $mutatedSelectedUnit = $downstreamArtifacts[$link.Current].Replace('| UNIT-001 | plan-001 |', '| UNIT-001 | plan-mutated |')
    $mutatedResult = Invoke-ActivationSliceArtifactValidator $mutatedSelectedUnit $downstreamArtifacts[$link.Predecessor]
    Assert-True ($mutatedResult.ExitCode -eq 1) "Downstream selected-unit mutation should block: $($link.Name). Output: $($mutatedResult.Output)"
    Assert-Contains $mutatedResult.Output 'downstream selected-unit field changed: Plan Reference' "Downstream selected-unit mutation: $($link.Name)"
  }

  foreach ($correlatedMutation in @(
    [pscustomobject]@{
      Name = 'invalid Migration Unit ID'
      Predecessor = $downstreamArtifacts.review.Replace('UNIT-001', 'BOGUS')
      Current = $downstreamArtifacts.verification.Replace('UNIT-001', 'BOGUS')
      Expected = 'Migration Unit ID must match UNIT-[0-9]{3}: BOGUS'
    }
    [pscustomobject]@{
      Name = 'blank Plan Reference'
      Predecessor = $downstreamArtifacts.review.Replace('| UNIT-001 | plan-001 |', '| UNIT-001 |  |')
      Current = $downstreamArtifacts.verification.Replace('| UNIT-001 | plan-001 |', '| UNIT-001 |  |')
      Expected = 'requires non-empty Plan Reference'
    }
    [pscustomobject]@{
      Name = 'incremental foundation tuple'
      Predecessor = $downstreamArtifacts.review.Replace(
        '| not-required | not-applicable | not-applicable | not-applicable | regression-baseline-001 |',
        '| not-required | FOUNDATION-FAKE | fake-foundation-reference | fake-foundation-approval | regression-baseline-001 |'
      )
      Current = $downstreamArtifacts.verification.Replace(
        '| not-required | not-applicable | not-applicable | not-applicable | regression-baseline-001 |',
        '| not-required | FOUNDATION-FAKE | fake-foundation-reference | fake-foundation-approval | regression-baseline-001 |'
      )
      Expected = 'selected unit violates canonical incremental foundation predicates'
    }
  )) {
    $result = Invoke-ActivationSliceArtifactValidator $correlatedMutation.Current $correlatedMutation.Predecessor
    Assert-True ($result.ExitCode -eq 1) "Downstream handoff must reject correlated $($correlatedMutation.Name). Output: $($result.Output)"
    Assert-Contains $result.Output $correlatedMutation.Expected "Downstream correlated $($correlatedMutation.Name)"
  }

  $missingParityProvenance = Remove-MarkdownSection $downstreamArtifacts.parity 'Task Provenance'
  $missingParityProvenanceResult = Invoke-ActivationSliceArtifactValidator $missingParityProvenance $downstreamArtifacts.verification
  Assert-True ($missingParityProvenanceResult.ExitCode -eq 1) "Parity must retain canonical task provenance. Output: $($missingParityProvenanceResult.Output)"
  Assert-Contains $missingParityProvenanceResult.Output 'assurance current Task Provenance section must appear exactly once; found 0' 'Missing assurance provenance'

  $missingVerificationProvenance = Remove-MarkdownSection $downstreamArtifacts.verification 'Task Provenance'
  $missingVerificationProvenanceResult = Invoke-ActivationSliceArtifactValidator $missingVerificationProvenance $downstreamArtifacts.review
  Assert-True ($missingVerificationProvenanceResult.ExitCode -eq 1) "Verification must anchor canonical task provenance to review Change Hygiene. Output: $($missingVerificationProvenanceResult.Output)"
  Assert-Contains $missingVerificationProvenanceResult.Output 'assurance current Task Provenance section must appear exactly once; found 0' 'Missing verification provenance anchor'

  $mutatedVerificationProvenance = $downstreamArtifacts.verification.Replace('base-sha-001', 'base-sha-002')
  $mutatedVerificationProvenanceResult = Invoke-ActivationSliceArtifactValidator $mutatedVerificationProvenance $downstreamArtifacts.review
  Assert-True ($mutatedVerificationProvenanceResult.ExitCode -eq 1) "Verification must preserve review task-base lineage. Output: $($mutatedVerificationProvenanceResult.Output)"
  Assert-Contains $mutatedVerificationProvenanceResult.Output 'assurance provenance field changed: Task-base SHA' 'Mutated verification provenance anchor'

  $mutatedParityProvenance = $downstreamArtifacts.parity.Replace('base-sha-001', 'base-sha-002')
  $mutatedParityProvenanceResult = Invoke-ActivationSliceArtifactValidator $mutatedParityProvenance $downstreamArtifacts.verification
  Assert-True ($mutatedParityProvenanceResult.ExitCode -eq 1) "Parity must preserve predecessor task-base lineage. Output: $($mutatedParityProvenanceResult.Output)"
  Assert-Contains $mutatedParityProvenanceResult.Output 'assurance provenance field changed: Task-base SHA' 'Mutated assurance provenance'

  $placeholderReviewProvenance = $downstreamArtifacts.review.Replace('base-sha-001', 'pending').Replace('final-sha-001', 'unknown')
  $placeholderVerificationProvenance = $downstreamArtifacts.verification.Replace('base-sha-001', 'pending').Replace('final-sha-001', 'unknown')
  $placeholderVerificationProvenanceResult = Invoke-ActivationSliceArtifactValidator $placeholderVerificationProvenance $placeholderReviewProvenance
  Assert-True ($placeholderVerificationProvenanceResult.ExitCode -eq 1) "Correlated placeholder SHA lineage must not satisfy assurance provenance. Output: $($placeholderVerificationProvenanceResult.Output)"
  Assert-Contains $placeholderVerificationProvenanceResult.Output 'assurance provenance current requires non-placeholder Task-base SHA' 'Placeholder assurance SHA lineage'

  $wrongUnitReviewProvenance = $downstreamArtifacts.review.Replace(
    '| UNIT-001 | target/render.dart | formatter-not-required | none | none | base-sha-001 | final-sha-001 |',
    '| UNIT-999 | target/render.dart | formatter-not-required | none | none | base-sha-001 | final-sha-001 |'
  )
  $wrongUnitVerificationProvenance = $downstreamArtifacts.verification.Replace(
    '| UNIT-001 | base-sha-001 | final-sha-001 | <IMMEDIATE_PREDECESSOR_PATH> |',
    '| UNIT-999 | base-sha-001 | final-sha-001 | <IMMEDIATE_PREDECESSOR_PATH> |'
  )
  $wrongUnitVerificationProvenanceResult = Invoke-ActivationSliceArtifactValidator $wrongUnitVerificationProvenance $wrongUnitReviewProvenance
  Assert-True ($wrongUnitVerificationProvenanceResult.ExitCode -eq 1) "Task provenance must identify the artifact's selected migration unit. Output: $($wrongUnitVerificationProvenanceResult.Output)"
  Assert-Contains $wrongUnitVerificationProvenanceResult.Output 'assurance provenance current Task / Unit must equal Selected Migration Unit.Migration Unit ID' 'Wrong assurance task unit'

  $staleParitySource = $downstreamArtifacts.parity.Replace('<IMMEDIATE_PREDECESSOR_PATH>', 'unrelated-artifact.md')
  $staleParitySourceResult = Invoke-ActivationSliceArtifactValidator $staleParitySource $downstreamArtifacts.verification
  Assert-True ($staleParitySourceResult.ExitCode -eq 1) "Parity Source Artifact must resolve to its actual immediate predecessor. Output: $($staleParitySourceResult.Output)"
  Assert-Contains $staleParitySourceResult.Output 'assurance provenance Source Artifact must resolve to the immediate predecessor path' 'Stale assurance source provenance'

  $blockedParity = $downstreamArtifacts.parity.Replace(
    "status: approved`nresult: complete`napproval_source: human",
    "status: draft`nresult: blocked"
  ).Replace('| pass | parity-evidence-001 |', '| blocked | parity-evidence-001 |').Replace(
    '| activation parity | source | target | pass |',
    '| activation parity | source | target | blocked |'
  )
  $blockedParityResult = Invoke-ActivationSliceArtifactValidator $blockedParity $downstreamArtifacts.verification
  Assert-True ($blockedParityResult.ExitCode -eq 0) "A structured blocked parity verdict must support the canonical draft/blocked lifecycle. Output: $($blockedParityResult.Output)"

  $blockedRegression = $downstreamArtifacts.regression.Replace(
    "status: approved`nresult: complete`napproval_source: human",
    "status: draft`nresult: blocked"
  ).Replace('| pass | required | pass |', '| pass | required | blocked |').Replace(
    '| activation parity | source | target | expected | not-applicable | TR-REQ-001 | pass |',
    '| activation parity | source | target | expected | not-applicable | TR-REQ-001 | blocked |'
  )
  $blockedRegressionResult = Invoke-ActivationSliceArtifactValidator $blockedRegression $downstreamArtifacts.parity
  Assert-True ($blockedRegressionResult.ExitCode -eq 0) "A structured blocked regression verdict must support the canonical draft/blocked lifecycle. Output: $($blockedRegressionResult.Output)"

  $blockedReview = $downstreamArtifacts.review.Replace(
    "status: approved`nresult: complete`napproval_source: human",
    "status: draft`nresult: blocked"
  ).TrimEnd() + "`n`n$domainBlockerSection"
  $blockedReviewResult = Invoke-ActivationSliceArtifactValidator $blockedReview $downstreamArtifacts.implementation
  Assert-True ($blockedReviewResult.ExitCode -eq 0) "A truthful domain-blocked AI review must support the canonical draft/blocked lifecycle. Output: $($blockedReviewResult.Output)"

  $blockedVerification = $downstreamArtifacts.verification.Replace(
    "status: approved`nresult: complete`napproval_source: human",
    "status: draft`nresult: blocked"
  ).TrimEnd() + "`n`n$domainBlockerSection"
  $blockedVerificationResult = Invoke-ActivationSliceArtifactValidator $blockedVerification $downstreamArtifacts.review
  Assert-True ($blockedVerificationResult.ExitCode -eq 0) "A truthful domain-blocked verification must support the canonical draft/blocked lifecycle. Output: $($blockedVerificationResult.Output)"

  $unsubstantiatedBlockedReview = $downstreamArtifacts.review.Replace(
    "status: approved`nresult: complete`napproval_source: human",
    "status: draft`nresult: blocked"
  )
  $unsubstantiatedBlockedReviewResult = Invoke-ActivationSliceArtifactValidator $unsubstantiatedBlockedReview $downstreamArtifacts.implementation
  Assert-True ($unsubstantiatedBlockedReviewResult.ExitCode -eq 1) "A domain-blocked lifecycle without blocker evidence must fail closed. Output: $($unsubstantiatedBlockedReviewResult.Output)"
  Assert-Contains $unsubstantiatedBlockedReviewResult.Output 'domain-blocking lifecycle requires canonical blocker evidence' 'Unsubstantiated domain blocker'

  $placeholderDomainBlocker = @'
## Domain Blocker

| Blocker | Evidence Reference |
|---|---|
| <blocker cụ thể> | <tham chiếu bằng chứng cụ thể> |
'@
  $placeholderBlockedReview = $unsubstantiatedBlockedReview.TrimEnd() + "`n`n$placeholderDomainBlocker"
  $placeholderBlockedReviewResult = Invoke-ActivationSliceArtifactValidator $placeholderBlockedReview $downstreamArtifacts.implementation
  Assert-True ($placeholderBlockedReviewResult.ExitCode -eq 1) "Template placeholders must not satisfy truthful domain-blocker evidence. Output: $($placeholderBlockedReviewResult.Output)"
  Assert-Contains $placeholderBlockedReviewResult.Output 'domain blocker requires non-placeholder Blocker' 'Placeholder domain blocker'

  $lowercasePlaceholderBlockedReview = $unsubstantiatedBlockedReview.TrimEnd() + "`n`n" + $domainBlockerSection.Replace(
    'required assurance command unavailable',
    'todo'
  )
  $lowercasePlaceholderBlockedReviewResult = Invoke-ActivationSliceArtifactValidator $lowercasePlaceholderBlockedReview $downstreamArtifacts.implementation
  Assert-True ($lowercasePlaceholderBlockedReviewResult.ExitCode -eq 1) "Lowercase machine placeholders must not satisfy truthful domain-blocker evidence. Output: $($lowercasePlaceholderBlockedReviewResult.Output)"
  Assert-Contains $lowercasePlaceholderBlockedReviewResult.Output 'domain blocker requires non-placeholder Blocker' 'Lowercase domain blocker placeholder'

  $decoratedPlaceholderBlockedReview = $unsubstantiatedBlockedReview.TrimEnd() + "`n`n" + $domainBlockerSection.Replace(
    'required assurance command unavailable',
    '**<blocker>**'
  )
  $decoratedPlaceholderBlockedReviewResult = Invoke-ActivationSliceArtifactValidator $decoratedPlaceholderBlockedReview $downstreamArtifacts.implementation
  Assert-True ($decoratedPlaceholderBlockedReviewResult.ExitCode -eq 1) "Markdown decoration must not disguise a domain-blocker placeholder. Output: $($decoratedPlaceholderBlockedReviewResult.Output)"
  Assert-Contains $decoratedPlaceholderBlockedReviewResult.Output 'domain blocker requires non-placeholder Blocker' 'Decorated domain blocker placeholder'

  foreach ($genericPlaceholder in @('pending', 'unknown', 'N/A')) {
    $genericPlaceholderBlockedReview = $unsubstantiatedBlockedReview.TrimEnd() + "`n`n" + $domainBlockerSection.Replace(
      'required assurance command unavailable',
      $genericPlaceholder
    )
    $genericPlaceholderBlockedReviewResult = Invoke-ActivationSliceArtifactValidator $genericPlaceholderBlockedReview $downstreamArtifacts.implementation
    Assert-True ($genericPlaceholderBlockedReviewResult.ExitCode -eq 1) "Generic placeholder '$genericPlaceholder' must not satisfy truthful domain-blocker evidence. Output: $($genericPlaceholderBlockedReviewResult.Output)"
    Assert-Contains $genericPlaceholderBlockedReviewResult.Output 'domain blocker requires non-placeholder Blocker' 'Generic domain blocker placeholder'
  }

  $concreteNoneSegmentBlocker = $blockedReview.Replace(
    'command-resolution-evidence-001',
    'artifacts/none/command-error.log'
  )
  $concreteNoneSegmentBlockerResult = Invoke-ActivationSliceArtifactValidator $concreteNoneSegmentBlocker $downstreamArtifacts.implementation
  Assert-True ($concreteNoneSegmentBlockerResult.ExitCode -eq 0) "A concrete evidence path is not a placeholder merely because one path segment is named none. Output: $($concreteNoneSegmentBlockerResult.Output)"

  foreach ($scenarioContradiction in @(
    [pscustomobject]@{
      Name = 'parity'
      Current = $downstreamArtifacts.parity.Replace('| activation parity | source | target | pass |', '| activation parity | source | target | fail |')
      Predecessor = $downstreamArtifacts.verification
    }
    [pscustomobject]@{
      Name = 'regression'
      Current = $downstreamArtifacts.regression.Replace('| activation parity | source | target | expected | not-applicable | TR-REQ-001 | pass |', '| activation parity | source | target | expected | not-applicable | TR-REQ-001 | fail |')
      Predecessor = $downstreamArtifacts.parity
    }
  )) {
    $result = Invoke-ActivationSliceArtifactValidator $scenarioContradiction.Current $scenarioContradiction.Predecessor
    Assert-True ($result.ExitCode -eq 1) "$($scenarioContradiction.Name) must reject a structured verdict that contradicts its scenario aggregate. Output: $($result.Output)"
    Assert-Contains $result.Output 'overall verdict does not match scenario aggregate: fail' "$($scenarioContradiction.Name) scenario/overall consistency"
  }

  $parityPredecessorWithoutScenarios = Remove-MarkdownSection $downstreamArtifacts.parity ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('S+G7i2NoIGLhuqNu')))
  $missingPredecessorScenariosResult = Invoke-ActivationSliceArtifactValidator $downstreamArtifacts.regression $parityPredecessorWithoutScenarios
  Assert-True ($missingPredecessorScenariosResult.ExitCode -eq 1) "Regression must revalidate the parity predecessor's scenario evidence. Output: $($missingPredecessorScenariosResult.Output)"
  Assert-Contains $missingPredecessorScenariosResult.Output 'predecessor assurance scenario section must appear exactly once; found 0' 'Missing predecessor assurance scenarios'

  $contradictoryParityPredecessor = $downstreamArtifacts.parity.Replace(
    '| activation parity | source | target | pass |',
    '| activation parity | source | target | fail |'
  )
  $contradictoryPredecessorResult = Invoke-ActivationSliceArtifactValidator $downstreamArtifacts.regression $contradictoryParityPredecessor
  Assert-True ($contradictoryPredecessorResult.ExitCode -eq 1) "Regression must reject a parity predecessor whose summary contradicts its scenarios. Output: $($contradictoryPredecessorResult.Output)"
  Assert-Contains $contradictoryPredecessorResult.Output 'predecessor overall verdict does not match scenario aggregate: fail' 'Contradictory predecessor assurance aggregate'

  foreach ($legacyVerdictArtifact in @(
    [pscustomobject]@{
      Name = 'parity'
      Current = "$($downstreamArtifacts.parity)`n`n$legacyParityConclusion`n`nfail"
      Predecessor = $downstreamArtifacts.verification
    }
    [pscustomobject]@{
      Name = 'regression'
      Current = "$($downstreamArtifacts.regression)`n`n$legacyParityConclusion`n`nfail"
      Predecessor = $downstreamArtifacts.parity
    }
  )) {
    $result = Invoke-ActivationSliceArtifactValidator $legacyVerdictArtifact.Current $legacyVerdictArtifact.Predecessor
    Assert-True ($result.ExitCode -eq 1) "$($legacyVerdictArtifact.Name) must reject a second legacy overall verdict surface. Output: $($result.Output)"
    Assert-Contains $result.Output 'overall verdict must use only the canonical structured row; legacy Kết luận section found 1' "$($legacyVerdictArtifact.Name) sole overall verdict"
  }

  $legacyConclusionName = $legacyParityConclusion.Substring(3)
  foreach ($legacyHeadingVariant in @(
    "### $legacyConclusionName",
    "$legacyConclusionName`n---------"
  )) {
    foreach ($artifactKind in @(
      [pscustomobject]@{ Name = 'parity'; Current = $downstreamArtifacts.parity; Predecessor = $downstreamArtifacts.verification }
      [pscustomobject]@{ Name = 'regression'; Current = $downstreamArtifacts.regression; Predecessor = $downstreamArtifacts.parity }
    )) {
      $result = Invoke-ActivationSliceArtifactValidator "$($artifactKind.Current)`n`n$legacyHeadingVariant`n`nfail" $artifactKind.Predecessor
      Assert-True ($result.ExitCode -eq 1) "$($artifactKind.Name) must reject alternate Markdown forms of the legacy verdict heading. Output: $($result.Output)"
      Assert-Contains $result.Output 'overall verdict must use only the canonical structured row; legacy Kết luận section found 1' "$($artifactKind.Name) alternate legacy heading"
    }
  }

  $unmatchedBacktickCurrent = $downstreamArtifacts.verification.Replace('| UNIT-001 | plan-001 |', '| `UNIT-001 | plan-001 |')
  $unmatchedBacktickResult = Invoke-ActivationSliceArtifactValidator $unmatchedBacktickCurrent $downstreamArtifacts.review
  Assert-True ($unmatchedBacktickResult.ExitCode -eq 1) "An unmatched leading backtick in an artifact table cell must not normalize to the predecessor value. Output: $($unmatchedBacktickResult.Output)"
  Assert-Contains $unmatchedBacktickResult.Output 'Migration Unit ID must match UNIT-[0-9]{3}: `UNIT-001' 'Artifact unmatched inline-code delimiter'

  $parityHandoffCases = @(
    [pscustomobject]@{
      Name = 'missing predecessor parity verdict section'
      Current = $downstreamArtifacts.regression
      Predecessor = Remove-MarkdownSection $downstreamArtifacts.parity 'Parity Verdict'
      Expected = 'regression predecessor Parity Verdict section must appear exactly once; found 0'
    }
    [pscustomobject]@{
      Name = 'blank predecessor parity evidence reference'
      Current = $downstreamArtifacts.regression
      Predecessor = $downstreamArtifacts.parity.Replace('| pass | parity-evidence-001 |', '| pass |  |')
      Expected = 'regression predecessor parity verdict requires non-empty Evidence Reference'
    }
    [pscustomobject]@{
      Name = 'unsupported predecessor parity verdict'
      Current = $downstreamArtifacts.regression
      Predecessor = $downstreamArtifacts.parity.Replace('| pass | parity-evidence-001 |', '| success | parity-evidence-001 |')
      Expected = 'regression predecessor Parity Verdict must be pass or fail'
    }
    [pscustomobject]@{
      Name = 'mutated current parity verdict'
      Current = $downstreamArtifacts.regression.Replace('| pass | required | pass |', '| fail | required | pass |')
      Predecessor = $downstreamArtifacts.parity
      Expected = 'regression must preserve predecessor Parity Verdict ordinally'
    }
    [pscustomobject]@{
      Name = 'lost current parity evidence reference'
      Current = $downstreamArtifacts.regression.Replace('parity-evidence-001; regression-evidence-001', 'regression-evidence-001')
      Predecessor = $downstreamArtifacts.parity
      Expected = 'regression must preserve predecessor parity Evidence Reference'
    }
  )
  foreach ($case in $parityHandoffCases) {
    $result = Invoke-ActivationSliceArtifactValidator $case.Current $case.Predecessor
    Assert-True ($result.ExitCode -eq 1) "Regression parity handoff should reject $($case.Name). Output: $($result.Output)"
    Assert-Contains $result.Output $case.Expected "Regression parity handoff $($case.Name)"
  }
}

if ($Cluster -in @('Lifecycle', 'All')) {
  $contractText = Get-Content -Raw -Encoding utf8 (Join-Path $PSScriptRoot '../contracts/activation-slice.md')
  $expandedApprovalEnumContract = $contractText.Replace(
    '`human | auto | auto-waive`',
    '`human | auto | auto-waive | garbage`'
  )
  Assert-True ($expandedApprovalEnumContract -cne $contractText) 'Approval source contract mutation must alter the canonical enum'
  $expandedApprovalEnumResult = Invoke-ActivationSliceContractValidator $expandedApprovalEnumContract
  Assert-True ($expandedApprovalEnumResult.ExitCode -eq 1) "The contract must reject an expanded approval_source enum. Output: $($expandedApprovalEnumResult.Output)"
  Assert-Contains $expandedApprovalEnumResult.Output 'Approval source values must be exactly: human, auto, auto-waive' 'Canonical approval source enum ownership'
  Assert-True ($contractText.Contains('## Immediate predecessor roles and lifecycle')) 'Activation Slice contract must canonically declare the full immediate-predecessor role/lifecycle chain'
  Assert-True ($contractText.Contains('## Bootstrap selected-unit handoff')) 'Activation Slice contract must canonically declare the bootstrap selected-unit/foundation handoff'
  $orderedUnitsSection = [Text.Encoding]::UTF8.GetString(
    [Convert]::FromBase64String('Q8OhYyDEkcahbiB24buLIG1pZ3JhdGlvbiB0aGVvIHRo4bupIHThu7E=')
  )
  $changedFilesSection = [Text.Encoding]::UTF8.GetString(
    [Convert]::FromBase64String('RmlsZSDEkcOjIHRoYXkgxJHhu5Vp')
  )
  $foundationRecordSection = [Text.Encoding]::UTF8.GetString(
    [Convert]::FromBase64String('QuG6o24gZ2hpIGJhc2VsaW5lIG7hu4FuIHThuqNuZw==')
  )
  $approvedFoundationSection = [Text.Encoding]::UTF8.GetString(
    [Convert]::FromBase64String('QmFzZWxpbmUgbuG7gW4gdOG6o25nIMSRw6MgZHV54buHdA==')
  )
  $regressionConclusionSection = [Text.Encoding]::UTF8.GetString(
    [Convert]::FromBase64String('S+G6v3QgbHXhuq1uIHjDoWMgbWluaCBtaWdyYXRpb24=')
  )
  $incrementalSelectedRow = '| UNIT-001 | plan-001 | approval-001 | incremental/preserve-existing | not-required | not-applicable | not-applicable | not-applicable | regression-baseline-001 | TR-REQ-001, TR-RENDER-001 |'
  $incrementalSelectedSection = @"
## Selected Migration Unit

| Migration Unit ID | Plan Reference | Approval Reference | Mode Constraint | Bootstrap Scope | Foundation Baseline ID | Foundation Baseline Reference | Foundation Baseline Approval Reference | Baseline Reference | Trace IDs |
|---|---|---|---|---|---|---|---|---|---|
$incrementalSelectedRow
"@
  $incrementalOrderedRow = '| 1 | UNIT-001 | not-required | not-applicable | not-applicable | none | activation accepted | incremental/preserve-existing | TR-REQ-001, TR-RENDER-001 | one-unit-one-change | approval-001 | approved |'
  $incrementalOrderedSection = @"
## $orderedUnitsSection

| Order | Migration Unit ID | Bootstrap Scope | Foundation Baseline ID | Foundation Approval Reference | Dependencies | Acceptance | Mode Constraint | Trace IDs | Delivery Change Boundary | Approval Reference | Approval Status |
|---|---|---|---|---|---|---|---|---|---|---|---|
$incrementalOrderedRow
"@
  $greenfieldSelectedRow = '| UNIT-001 | plan-001 | approval-001 | greenfield/design-new | required | FOUNDATION-001 | target-baseline-001 | bootstrap-approved-001 | not-applicable | TR-REQ-001, TR-RENDER-001 |'
  $greenfieldSelectedSection = @"
## Selected Migration Unit

| Migration Unit ID | Plan Reference | Approval Reference | Mode Constraint | Bootstrap Scope | Foundation Baseline ID | Foundation Baseline Reference | Foundation Baseline Approval Reference | Baseline Reference | Trace IDs |
|---|---|---|---|---|---|---|---|---|---|
$greenfieldSelectedRow
"@
  $greenfieldOrderedRow = '| 1 | UNIT-001 | required | pending-bootstrap | pending-step09-approval | none | activation accepted | greenfield/design-new | TR-REQ-001, TR-RENDER-001 | one-unit-one-change | approval-001 | approved |'
  $greenfieldOrderedSection = @"
## $orderedUnitsSection

| Order | Migration Unit ID | Bootstrap Scope | Foundation Baseline ID | Foundation Approval Reference | Dependencies | Acceptance | Mode Constraint | Trace IDs | Delivery Change Boundary | Approval Reference | Approval Status |
|---|---|---|---|---|---|---|---|---|---|---|---|
$greenfieldOrderedRow
"@
  $foundationRecord = @"
## $foundationRecordSection

| Foundation Baseline ID | Source Migration Unit ID | Target Baseline Reference | Approval Reference | Approval Status | Evidence |
|---|---|---|---|---|---|
| FOUNDATION-001 | UNIT-001 | target-baseline-001 | bootstrap-approved-001 | approved | bootstrap-evidence-001 |
"@
  $approvedFoundationRecord = @"
## $approvedFoundationSection

| Foundation Baseline ID | Target Baseline Reference | Approval Reference | Approval Status | Evidence |
|---|---|---|---|---|
| FOUNDATION-001 | target-baseline-001 | foundation-approval-001 | approved | design-revision-001; freshness-current |
"@
  $implementationRecords = @"
## $changedFilesSection

| Migration Unit ID | Activation Slice ID | Seam | File | Change | Trace IDs |
|---|---|---|---|---|---|
| UNIT-001 | ACT-001 | render | target/render.dart | render selected unit | TR-REQ-001, TR-RENDER-001 |

## Activation Slice Test Evidence

| Migration Unit ID | Activation Slice ID | Seam | Test | Command | Result | Trace IDs |
|---|---|---|---|---|---|---|
| UNIT-001 | ACT-001 | test | activation lifecycle | test activation | PASS | TR-REQ-001, TR-LIFECYCLE-001 |
"@
  $parityVerdict = @'
## Parity Verdict

| Parity Verdict | Evidence Reference |
|---|---|
| pass | parity-evidence-001 |
'@
  $regressionConclusion = @"
## $regressionConclusionSection

| Parity Verdict | Regression Applicability | Regression Verdict | Evidence Reference |
|---|---|---|---|
| pass | required | pass | parity-evidence-001; regression-evidence-001 |
"@
  $assuranceScenarioSection = [Text.Encoding]::UTF8.GetString(
    [Convert]::FromBase64String('IyMgS+G7i2NoIGLhuqNuCgp8IFNjZW5hcmlvIHwgQmFzZWxpbmUgfCBBY3R1YWwgfCBWZXJkaWN0IHwKfC0tLXwtLS18LS0tfC0tLXwKfCBhY3RpdmF0aW9uIHBhcml0eSB8IHNvdXJjZSB8IHRhcmdldCB8IHBhc3MgfA==')
  )
  $assuranceScenarioSectionName = [Text.Encoding]::UTF8.GetString(
    [Convert]::FromBase64String('S+G7i2NoIGLhuqNu')
  )
  $regressionScenarioSection = @"
## $assuranceScenarioSectionName

| Scenario | Baseline | Actual | Delta Class | Waiver Reference | Trace IDs | Verdict |
|---|---|---|---|---|---|---|
| activation parity | source | target | expected | not-applicable | TR-REQ-001 | pass |
"@

  $verificationProvenanceSection = @'
## Task Provenance

| Task / Unit | Task-base SHA | Final-tree SHA | Source Artifact |
|---|---|---|---|
| UNIT-001 | base-sha-001 | final-sha-001 | <IMMEDIATE_PREDECESSOR_PATH> |
'@
  $parityProvenanceSection = $verificationProvenanceSection
  $regressionProvenanceSection = $verificationProvenanceSection
  $reviewChangeHygieneSection = @'
## Change Hygiene

| Task / Unit | Scope Evidence | Formatter Evidence | Unrelated Diff | Severity | Task-base SHA | Final-tree SHA |
|---|---|---|---|---|---|---|
| UNIT-001 | target/render.dart | formatter-not-required | none | none | base-sha-001 | final-sha-001 |
'@

  $domainBlockerSection = @'
## Domain Blocker

| Blocker | Evidence Reference |
|---|---|
| pre-mutation command unavailable | command-resolution-evidence-001 |
'@

  function New-LifecycleArtifact([string]$StepId, [string[]]$Sections = @()) {
    $artifact = $completeActivationSlice.Replace('step_id: 01-validate-inputs', "step_id: $StepId").TrimEnd()
    foreach ($section in $Sections) { $artifact += "`n`n$section" }
    return $artifact
  }

  $originPredecessor = @'
---
step_id: 01-validate-inputs
status: approved
result: complete
approval_source: human
produced_at: 2026-08-18
---

## Verdict

ready
'@
  $originPartialPredecessor = $originPredecessor.Replace('result: complete', 'result: partial')
  $roleArtifacts = [ordered]@{
    discovery = New-LifecycleArtifact '02-discovery'
    requirements = New-LifecycleArtifact '03-analyze-requirements-uiux'
    inventory = New-LifecycleArtifact '04-build-inventory'
    mapping = New-LifecycleArtifact '05-feature-mapping'
    gaps = New-LifecycleArtifact '06-analyze-gaps-conflicts'
    design = New-LifecycleArtifact '07-technical-design'
    incrementalPlan = New-LifecycleArtifact '08-plan-waves' @($incrementalOrderedSection)
    greenfieldPlan = New-LifecycleArtifact '08-plan-waves' @($greenfieldOrderedSection)
    bootstrap = New-LifecycleArtifact '09-bootstrap-target' @($greenfieldSelectedSection, $foundationRecord)
    incrementalImplementation = New-LifecycleArtifact '10-code-migration' @($incrementalSelectedSection, $implementationRecords)
    greenfieldImplementation = New-LifecycleArtifact '10-code-migration' @($greenfieldSelectedSection, $implementationRecords)
    review = New-LifecycleArtifact '11-ai-review' @($incrementalSelectedSection, $reviewChangeHygieneSection)
    verification = New-LifecycleArtifact '12-verification-testing' @($incrementalSelectedSection, $verificationProvenanceSection)
    parity = New-LifecycleArtifact '13-verify-parity' @($incrementalSelectedSection, $parityVerdict, $assuranceScenarioSection, $parityProvenanceSection)
    regression = New-LifecycleArtifact '14-verify-regression' @($incrementalSelectedSection, $regressionConclusion, $regressionScenarioSection, $regressionProvenanceSection)
  }
  $roleLinks = @(
    [pscustomobject]@{ Name = '01 to 02 origin'; PredecessorText = $originPredecessor; CurrentText = $roleArtifacts.discovery }
    [pscustomobject]@{ Name = '02 to 03'; Predecessor = 'discovery'; Current = 'requirements' }
    [pscustomobject]@{ Name = '03 to 04'; Predecessor = 'requirements'; Current = 'inventory' }
    [pscustomobject]@{ Name = '04 to 05'; Predecessor = 'inventory'; Current = 'mapping' }
    [pscustomobject]@{ Name = '05 to 06'; Predecessor = 'mapping'; Current = 'gaps' }
    [pscustomobject]@{ Name = '06 to 07'; Predecessor = 'gaps'; Current = 'design' }
    [pscustomobject]@{ Name = '07 to 08'; Predecessor = 'design'; Current = 'incrementalPlan' }
    [pscustomobject]@{ Name = '08 to 09 bootstrap'; Predecessor = 'greenfieldPlan'; Current = 'bootstrap' }
    [pscustomobject]@{ Name = '08 to 10 no-bootstrap'; Predecessor = 'incrementalPlan'; Current = 'incrementalImplementation' }
    [pscustomobject]@{ Name = '09 to 10 bootstrap'; Predecessor = 'bootstrap'; Current = 'greenfieldImplementation' }
    [pscustomobject]@{ Name = '10 to 11'; Predecessor = 'incrementalImplementation'; Current = 'review' }
    [pscustomobject]@{ Name = '11 to 12'; Predecessor = 'review'; Current = 'verification' }
    [pscustomobject]@{ Name = '12 to 13'; Predecessor = 'verification'; Current = 'parity' }
    [pscustomobject]@{ Name = '13 to 14'; Predecessor = 'parity'; Current = 'regression' }
  )
  foreach ($link in $roleLinks) {
    $current = if ($null -ne $link.CurrentText) { $link.CurrentText } else { $roleArtifacts[$link.Current] }
    $predecessor = if ($null -ne $link.PredecessorText) { $link.PredecessorText } else { $roleArtifacts[$link.Predecessor] }
    $result = Invoke-ActivationSliceArtifactValidator $current $predecessor
    Assert-True ($result.ExitCode -eq 0) "Canonical immediate-predecessor role/lifecycle should pass: $($link.Name). Output: $($result.Output)"

    $wrongCurrent = [regex]::Replace($current, '(?m)^step_id: .+$', 'step_id: 99-wrong-current', 1)
    $wrongCurrentResult = Invoke-ActivationSliceArtifactValidator $wrongCurrent $predecessor
    Assert-True ($wrongCurrentResult.ExitCode -eq 1) "Wrong current role should block: $($link.Name). Output: $($wrongCurrentResult.Output)"
    Assert-Contains $wrongCurrentResult.Output 'immediate-predecessor role/lifecycle invalid' "Wrong current role: $($link.Name)"

    $unapprovedPredecessor = $predecessor.Replace('status: approved', 'status: draft')
    $unapprovedResult = Invoke-ActivationSliceArtifactValidator $current $unapprovedPredecessor
    Assert-True ($unapprovedResult.ExitCode -eq 1) "Unapproved predecessor should block: $($link.Name). Output: $($unapprovedResult.Output)"
    Assert-Contains $unapprovedResult.Output 'immediate-predecessor role/lifecycle invalid' "Unapproved predecessor: $($link.Name)"

    $stalePredecessor = [regex]::Replace($predecessor, '(?m)^step_id: .+$', 'step_id: 99-stale-predecessor', 1)
    $staleResult = Invoke-ActivationSliceArtifactValidator $current $stalePredecessor
    Assert-True ($staleResult.ExitCode -eq 1) "Stale predecessor role should block: $($link.Name). Output: $($staleResult.Output)"
    Assert-Contains $staleResult.Output 'immediate-predecessor role/lifecycle invalid' "Stale predecessor: $($link.Name)"
  }

  $originPartialResult = Invoke-ActivationSliceArtifactValidator $roleArtifacts.discovery $originPartialPredecessor
  Assert-True ($originPartialResult.ExitCode -eq 0) "Discovery origin must accept the approved complete-or-partial step-01 predecessor without an Activation Slice. Output: $($originPartialResult.Output)"

  $originWithEnvelope = $completeActivationSlice.Replace(
    'step_id: 01-validate-inputs',
    'step_id: 01-validate-inputs'
  )
  $originPartialWithEnvelope = $originWithEnvelope.Replace('result: complete', 'result: partial')
  $originPartialEnvelopeResult = Invoke-ActivationSliceArtifactValidator $roleArtifacts.discovery $originPartialWithEnvelope
  Assert-True ($originPartialEnvelopeResult.ExitCode -eq 0) "Discovery origin must treat the contract-authorized approved/partial step-01 predecessor consistently whether or not it already has an Activation Slice. Output: $($originPartialEnvelopeResult.Output)"

  $renumberedDiscovery = $roleArtifacts.discovery.Replace('ACT-001', 'ACT-002')
  $originEnvelopeDriftResult = Invoke-ActivationSliceArtifactValidator $renumberedDiscovery $originWithEnvelope
  Assert-True ($originEnvelopeDriftResult.ExitCode -eq 1) "Discovery must preserve a step-01 Activation Slice envelope when one already exists. Output: $($originEnvelopeDriftResult.Output)"
  Assert-Contains $originEnvelopeDriftResult.Output 'Activation Slice handoff changed Activation Slice ID from ACT-001 to ACT-002' 'Discovery predecessor envelope preservation'

  $preselectionLeak = "$($roleArtifacts.requirements)`n`n$incrementalSelectedSection"
  $preselectionLeakResult = Invoke-ActivationSliceArtifactValidator $preselectionLeak $roleArtifacts.discovery
  Assert-True ($preselectionLeakResult.ExitCode -eq 1) "A pre-selection route must reject a Selected Migration Unit section. Output: $($preselectionLeakResult.Output)"
  Assert-Contains $preselectionLeakResult.Output 'pre-selection route forbids Selected Migration Unit section; found 1' 'Pre-selection selected-unit absence'

  $preselectionPredecessorLeak = "$($roleArtifacts.discovery)`n`n$incrementalSelectedSection"
  $preselectionPredecessorLeakResult = Invoke-ActivationSliceArtifactValidator $roleArtifacts.requirements $preselectionPredecessorLeak
  Assert-True ($preselectionPredecessorLeakResult.ExitCode -eq 1) "A pre-selection artifact must not launder a Selected Migration Unit into its successor. Output: $($preselectionPredecessorLeakResult.Output)"
  Assert-Contains $preselectionPredecessorLeakResult.Output 'predecessor pre-selection artifact forbids Selected Migration Unit section; found 1' 'Pre-selection predecessor intrinsic state'

  foreach ($badApprovalSource in @('garbage', '')) {
    $badPredecessor = if ($badApprovalSource -eq '') {
      [regex]::Replace($roleArtifacts.discovery, '(?m)^approval_source: human\r?\n', '', 1)
    }
    else {
      $roleArtifacts.discovery.Replace('approval_source: human', "approval_source: $badApprovalSource")
    }
    $badApprovalResult = Invoke-ActivationSliceArtifactValidator $roleArtifacts.requirements $badPredecessor
    Assert-True ($badApprovalResult.ExitCode -eq 1) "An approved predecessor must have exactly one canonical approval_source; value <$badApprovalSource>. Output: $($badApprovalResult.Output)"
    Assert-Contains $badApprovalResult.Output 'approved front matter requires exactly one approval_source: human, auto, or auto-waive' "Predecessor approval_source <$badApprovalSource>"
  }

  $incrementalBootstrap = New-LifecycleArtifact '09-bootstrap-target' @($incrementalSelectedSection)
  $incrementalBootstrapResult = Invoke-ActivationSliceArtifactValidator $incrementalBootstrap $roleArtifacts.incrementalPlan
  Assert-True ($incrementalBootstrapResult.ExitCode -eq 1) "Step 09 must reject the incremental/not-required route. Output: $($incrementalBootstrapResult.Output)"
  Assert-Contains $incrementalBootstrapResult.Output 'bootstrap route requires selected-unit Mode Constraint greenfield/design-new and Bootstrap Scope required' 'Incremental bootstrap rejection'

  $directRequiredImplementation = New-LifecycleArtifact '10-code-migration' @($greenfieldSelectedSection, $implementationRecords)
  $directRequiredResult = Invoke-ActivationSliceArtifactValidator $directRequiredImplementation $roleArtifacts.greenfieldPlan
  Assert-True ($directRequiredResult.ExitCode -eq 1) "Step 10 cannot bypass step 09 for a bootstrap-required unit. Output: $($directRequiredResult.Output)"
  Assert-Contains $directRequiredResult.Output 'initial plan route requires selected-unit Bootstrap Scope not-required' 'Required bootstrap bypass rejection'

  $fakeIncrementalPlanRow = $incrementalOrderedRow.Replace(
    '| not-required | not-applicable | not-applicable |',
    '| not-required | FOUNDATION-FAKE | foundation-approval-fake |'
  )
  $fakeIncrementalSelectedRow = $incrementalSelectedRow.Replace(
    '| not-required | not-applicable | not-applicable | not-applicable |',
    '| not-required | FOUNDATION-FAKE | not-applicable | foundation-approval-fake |'
  )
  $fakeIncrementalPlan = $roleArtifacts.incrementalPlan.Replace($incrementalOrderedRow, $fakeIncrementalPlanRow)
  $fakeIncrementalImplementation = $roleArtifacts.incrementalImplementation.Replace($incrementalSelectedRow, $fakeIncrementalSelectedRow)
  $fakeIncrementalResult = Invoke-ActivationSliceArtifactValidator $fakeIncrementalImplementation $fakeIncrementalPlan
  Assert-True ($fakeIncrementalResult.ExitCode -eq 1) "An incremental direct-plan route must keep its complete foundation tuple not-applicable. Output: $($fakeIncrementalResult.Output)"
  Assert-Contains $fakeIncrementalResult.Output 'direct-plan foundation state violates the incremental canonical tuple' 'Incremental direct-plan foundation state'

  $missingIncrementalBaseline = $roleArtifacts.incrementalImplementation.Replace('regression-baseline-001', 'not-applicable')
  $missingIncrementalBaselineResult = Invoke-ActivationSliceArtifactValidator $missingIncrementalBaseline $roleArtifacts.incrementalPlan
  Assert-True ($missingIncrementalBaselineResult.ExitCode -eq 1) "An incremental selected unit requires a real pre-mutation Baseline Reference. Output: $($missingIncrementalBaselineResult.Output)"
  Assert-Contains $missingIncrementalBaselineResult.Output 'selected unit violates canonical incremental foundation predicates' 'Incremental pre-mutation baseline reference'

  $pendingIncrementalBaseline = $roleArtifacts.incrementalImplementation.Replace('regression-baseline-001', 'pending-before-edit')
  $pendingIncrementalBaselineResult = Invoke-ActivationSliceArtifactValidator $pendingIncrementalBaseline $roleArtifacts.incrementalPlan
  Assert-True ($pendingIncrementalBaselineResult.ExitCode -eq 1) "Step 10 must replace the plan's pending-before-edit sentinel with captured baseline evidence. Output: $($pendingIncrementalBaselineResult.Output)"
  Assert-Contains $pendingIncrementalBaselineResult.Output 'selected unit violates canonical incremental foundation predicates' 'Pending incremental baseline reference'

  $placeholderIncrementalBaseline = $roleArtifacts.incrementalImplementation.Replace('regression-baseline-001', '<baseline-evidence>')
  $placeholderIncrementalBaselineResult = Invoke-ActivationSliceArtifactValidator $placeholderIncrementalBaseline $roleArtifacts.incrementalPlan
  Assert-True ($placeholderIncrementalBaselineResult.ExitCode -eq 1) "Step 10 must reject a template placeholder in place of captured baseline evidence. Output: $($placeholderIncrementalBaselineResult.Output)"
  Assert-Contains $placeholderIncrementalBaselineResult.Output 'selected unit violates canonical incremental foundation predicates' 'Placeholder incremental baseline reference'

  $decoratedPlaceholderIncrementalBaseline = $roleArtifacts.incrementalImplementation.Replace('regression-baseline-001', '**<baseline-evidence>**')
  $decoratedPlaceholderIncrementalBaselineResult = Invoke-ActivationSliceArtifactValidator $decoratedPlaceholderIncrementalBaseline $roleArtifacts.incrementalPlan
  Assert-True ($decoratedPlaceholderIncrementalBaselineResult.ExitCode -eq 1) "Markdown decoration must not disguise a baseline-evidence placeholder. Output: $($decoratedPlaceholderIncrementalBaselineResult.Output)"
  Assert-Contains $decoratedPlaceholderIncrementalBaselineResult.Output 'selected unit violates canonical incremental foundation predicates' 'Decorated baseline reference placeholder'

  foreach ($genericBaselinePlaceholder in @('pending', 'unknown', 'N/A')) {
    $genericPlaceholderIncrementalBaseline = $roleArtifacts.incrementalImplementation.Replace('regression-baseline-001', $genericBaselinePlaceholder)
    $genericPlaceholderIncrementalBaselineResult = Invoke-ActivationSliceArtifactValidator $genericPlaceholderIncrementalBaseline $roleArtifacts.incrementalPlan
    Assert-True ($genericPlaceholderIncrementalBaselineResult.ExitCode -eq 1) "Step 10 must reject generic baseline placeholder '$genericBaselinePlaceholder'. Output: $($genericPlaceholderIncrementalBaselineResult.Output)"
    Assert-Contains $genericPlaceholderIncrementalBaselineResult.Output 'selected unit violates canonical incremental foundation predicates' 'Generic incremental baseline placeholder'
  }

  $concreteNoneSegmentBaseline = $roleArtifacts.incrementalImplementation.Replace(
    'regression-baseline-001',
    'artifacts/none/pre-mutation-baseline.log'
  )
  $concreteNoneSegmentBaselineResult = Invoke-ActivationSliceArtifactValidator $concreteNoneSegmentBaseline $roleArtifacts.incrementalPlan
  Assert-True ($concreteNoneSegmentBaselineResult.ExitCode -eq 0) "A concrete baseline path is not a placeholder merely because one path segment is named none. Output: $($concreteNoneSegmentBaselineResult.Output)"

  $pendingGreenfieldPlanRow = $greenfieldOrderedRow.Replace('| required |', '| not-required |')
  $pendingGreenfieldSelectedRow = '| UNIT-001 | plan-001 | approval-001 | greenfield/design-new | not-required | pending-bootstrap | target-baseline-001 | pending-step09-approval | not-applicable | TR-REQ-001, TR-RENDER-001 |'
  $pendingGreenfieldPlan = $roleArtifacts.greenfieldPlan.Replace($greenfieldOrderedRow, $pendingGreenfieldPlanRow)
  $pendingGreenfieldImplementation = New-LifecycleArtifact '10-code-migration' @(
    $greenfieldSelectedSection.Replace($greenfieldSelectedRow, $pendingGreenfieldSelectedRow),
    $implementationRecords
  )
  $pendingGreenfieldResult = Invoke-ActivationSliceArtifactValidator $pendingGreenfieldImplementation $pendingGreenfieldPlan
  Assert-True ($pendingGreenfieldResult.ExitCode -eq 1) "A later-greenfield direct-plan route must not carry pending bootstrap foundation sentinels. Output: $($pendingGreenfieldResult.Output)"
  Assert-Contains $pendingGreenfieldResult.Output 'direct-plan foundation state violates the greenfield canonical tuple' 'Greenfield direct-plan foundation state'

  $laterGreenfieldPlanRow = '| 1 | UNIT-001 | not-required | FOUNDATION-001 | foundation-approval-001 | none | activation accepted | greenfield/design-new | TR-REQ-001, TR-RENDER-001 | one-unit-one-change | approval-001 | approved |'
  $laterGreenfieldSelectedRow = '| UNIT-001 | plan-001 | approval-001 | greenfield/design-new | not-required | FOUNDATION-001 | target-baseline-001 | foundation-approval-001 | not-applicable | TR-REQ-001, TR-RENDER-001 |'
  $laterGreenfieldPlan = New-LifecycleArtifact '08-plan-waves' @(
    $greenfieldOrderedSection.Replace($greenfieldOrderedRow, $laterGreenfieldPlanRow),
    $approvedFoundationRecord
  )
  $laterGreenfieldImplementation = New-LifecycleArtifact '10-code-migration' @(
    $greenfieldSelectedSection.Replace($greenfieldSelectedRow, $laterGreenfieldSelectedRow),
    $implementationRecords
  )
  $laterGreenfieldResult = Invoke-ActivationSliceArtifactValidator $laterGreenfieldImplementation $laterGreenfieldPlan
  Assert-True ($laterGreenfieldResult.ExitCode -eq 0) "A later-greenfield direct-plan route with one correlated approved foundation record should pass. Output: $($laterGreenfieldResult.Output)"

  $missingApprovedFoundationPlan = Remove-MarkdownSection $laterGreenfieldPlan $approvedFoundationSection
  $missingApprovedFoundationResult = Invoke-ActivationSliceArtifactValidator $laterGreenfieldImplementation $missingApprovedFoundationPlan
  Assert-True ($missingApprovedFoundationResult.ExitCode -eq 1) "A later-greenfield direct-plan route must reject an invented resolved tuple without its approved foundation record. Output: $($missingApprovedFoundationResult.Output)"
  Assert-Contains $missingApprovedFoundationResult.Output "direct-plan predecessor $approvedFoundationSection section must appear exactly once; found 0" 'Later-greenfield approved foundation record'

  $draftBootstrap = $roleArtifacts.bootstrap.Replace(
    "status: approved`nresult: complete`napproval_source: human",
    "status: draft`nresult: complete"
  ).Replace('bootstrap-approved-001', 'pending-step09-approval').Replace(
    '| pending-step09-approval | approved | bootstrap-evidence-001 |',
    '| pending-step09-approval | pending-approval | bootstrap-evidence-001 |'
  )
  $draftBootstrapResult = Invoke-ActivationSliceArtifactValidator $draftBootstrap $roleArtifacts.greenfieldPlan
  Assert-True ($draftBootstrapResult.ExitCode -eq 0) "A template-shaped pre-gate step-09 draft must preserve its pending approval state and remain valid. Output: $($draftBootstrapResult.Output)"

  $placeholderDraftBootstrap = $draftBootstrap.Replace('target-baseline-001', '<placeholder>')
  $placeholderDraftBootstrapResult = Invoke-ActivationSliceArtifactValidator $placeholderDraftBootstrap $roleArtifacts.greenfieldPlan
  Assert-True ($placeholderDraftBootstrapResult.ExitCode -eq 1) "A pre-gate step-09 draft must reject a placeholder foundation reference even when its records correlate. Output: $($placeholderDraftBootstrapResult.Output)"
  Assert-Contains $placeholderDraftBootstrapResult.Output 'bootstrap draft current selected unit violates canonical pending-approval predicates' 'Draft bootstrap placeholder foundation reference'

  $staleDomainBlocker = $roleArtifacts.discovery.TrimEnd() + "`n`n$domainBlockerSection"
  $staleDomainBlockerResult = Invoke-ActivationSliceArtifactValidator $staleDomainBlocker $originPredecessor
  Assert-True ($staleDomainBlockerResult.ExitCode -eq 1) "A completed routed artifact must omit stale Domain Blocker evidence. Output: $($staleDomainBlockerResult.Output)"
  Assert-Contains $staleDomainBlockerResult.Output 'non-blocking lifecycle must not contain Domain Blocker' 'Stale Domain Blocker section'

  $blockedBootstrapSelectedRow = '| UNIT-001 | plan-001 | approval-001 | greenfield/design-new | required | pending-bootstrap | not-applicable | pending-step09-approval | not-applicable | TR-REQ-001, TR-RENDER-001 |'
  $blockedBootstrap = $roleArtifacts.bootstrap.Replace(
    "status: approved`nresult: complete`napproval_source: human",
    "status: draft`nresult: blocked"
  ).Replace($greenfieldSelectedRow, $blockedBootstrapSelectedRow)
  $blockedBootstrap = (Remove-MarkdownSection $blockedBootstrap $foundationRecordSection).TrimEnd() + "`n`n$domainBlockerSection"
  $blockedBootstrapResult = Invoke-ActivationSliceArtifactValidator $blockedBootstrap $roleArtifacts.greenfieldPlan
  Assert-True ($blockedBootstrapResult.ExitCode -eq 0) "A truthful pre-mutation step-09 blocker must retain the pending selector without a foundation record. Output: $($blockedBootstrapResult.Output)"

  $blockedBootstrapWithFoundation = "$blockedBootstrap`n`n$foundationRecord"
  $blockedBootstrapWithFoundationResult = Invoke-ActivationSliceArtifactValidator $blockedBootstrapWithFoundation $roleArtifacts.greenfieldPlan
  Assert-True ($blockedBootstrapWithFoundationResult.ExitCode -eq 1) "A pre-mutation step-09 blocker must not carry a fabricated/resolved foundation record. Output: $($blockedBootstrapWithFoundationResult.Output)"
  Assert-Contains $blockedBootstrapWithFoundationResult.Output 'bootstrap blocked current must not contain a foundation record' 'Blocked bootstrap foundation absence'

  $missingBootstrapSelection = New-LifecycleArtifact '09-bootstrap-target'
  $missingBootstrapPlan = New-LifecycleArtifact '08-plan-waves'
  $missingBootstrapSelectionResult = Invoke-ActivationSliceArtifactValidator $missingBootstrapSelection $missingBootstrapPlan
  Assert-True ($missingBootstrapSelectionResult.ExitCode -eq 1) "The 08-to-09 route must require both plan and selected-unit records. Output: $($missingBootstrapSelectionResult.Output)"
  Assert-Contains $missingBootstrapSelectionResult.Output 'bootstrap current Selected Migration Unit section must appear exactly once; found 0' 'Missing bootstrap selected unit'
  Assert-Contains $missingBootstrapSelectionResult.Output "bootstrap predecessor $orderedUnitsSection section must appear exactly once; found 0" 'Missing bootstrap ordered unit'

  $bootstrapRequiredFieldMutations = @(
    [pscustomobject]@{
      Name = 'blank correlated Approval Reference'
      PlanRow = $greenfieldOrderedRow.Replace('| approval-001 | approved |', '|  | approved |')
      CurrentRow = $greenfieldSelectedRow.Replace('| plan-001 | approval-001 |', '| plan-001 |  |')
      Expected = 'requires non-empty Approval Reference'
    }
    [pscustomobject]@{
      Name = 'blank correlated Trace IDs'
      PlanRow = $greenfieldOrderedRow.Replace('| TR-REQ-001, TR-RENDER-001 |', '|  |')
      CurrentRow = $greenfieldSelectedRow.Replace('| TR-REQ-001, TR-RENDER-001 |', '|  |')
      Expected = 'requires non-empty Trace IDs'
    }
    [pscustomobject]@{
      Name = 'blank current Plan Reference'
      PlanRow = $greenfieldOrderedRow
      CurrentRow = $greenfieldSelectedRow.Replace('| UNIT-001 | plan-001 |', '| UNIT-001 |  |')
      Expected = 'requires non-empty Plan Reference'
    }
    [pscustomobject]@{
      Name = 'correlated invalid Migration Unit ID'
      PlanRow = $greenfieldOrderedRow.Replace('UNIT-001', 'BOGUS')
      CurrentRow = $greenfieldSelectedRow.Replace('UNIT-001', 'BOGUS')
      Expected = 'Migration Unit ID must match UNIT-[0-9]{3}: BOGUS'
      FoundationUnitId = 'BOGUS'
    }
    [pscustomobject]@{
      Name = 'blank predecessor Acceptance'
      PlanRow = $greenfieldOrderedRow.Replace('| activation accepted |', '|  |')
      CurrentRow = $greenfieldSelectedRow
      Expected = 'requires non-empty Acceptance'
    }
  )
  foreach ($mutation in $bootstrapRequiredFieldMutations) {
    $mutatedPlan = $roleArtifacts.greenfieldPlan.Replace($greenfieldOrderedRow, $mutation.PlanRow)
    $mutatedBootstrap = $roleArtifacts.bootstrap.Replace($greenfieldSelectedRow, $mutation.CurrentRow)
    if ($mutation.FoundationUnitId) {
      $mutatedBootstrap = $mutatedBootstrap.Replace('| FOUNDATION-001 | UNIT-001 |', "| FOUNDATION-001 | $($mutation.FoundationUnitId) |")
    }
    $result = Invoke-ActivationSliceArtifactValidator $mutatedBootstrap $mutatedPlan
    Assert-True ($result.ExitCode -eq 1) "Step 08-to-09 must reject $($mutation.Name). Output: $($result.Output)"
    Assert-Contains $result.Output $mutation.Expected "Bootstrap $($mutation.Name)"
  }

  foreach ($resolvedFoundationMutation in @(
    [pscustomobject]@{
      Name = 'not-applicable Foundation Baseline Reference'
      Text = $roleArtifacts.bootstrap.Replace('target-baseline-001', 'not-applicable')
    }
    [pscustomobject]@{
      Name = 'pending Foundation Baseline Approval Reference'
      Text = $roleArtifacts.bootstrap.Replace('bootstrap-approved-001', 'pending-step09-approval')
    }
  )) {
    $result = Invoke-ActivationSliceArtifactValidator $resolvedFoundationMutation.Text $roleArtifacts.greenfieldPlan
    Assert-True ($result.ExitCode -eq 1) "An approved resolved foundation must reject $($resolvedFoundationMutation.Name). Output: $($result.Output)"
    Assert-Contains $result.Output 'bootstrap current selected unit violates canonical resolved-foundation predicates' "Resolved foundation $($resolvedFoundationMutation.Name)"
  }

  $missingFoundationBootstrap = New-LifecycleArtifact '09-bootstrap-target' @($greenfieldSelectedSection)
  $missingFoundationResult = Invoke-ActivationSliceArtifactValidator $roleArtifacts.greenfieldImplementation $missingFoundationBootstrap
  Assert-True ($missingFoundationResult.ExitCode -eq 1) "Step 10 must reject a bootstrap predecessor without its approved foundation record. Output: $($missingFoundationResult.Output)"
  Assert-Contains $missingFoundationResult.Output "bootstrap predecessor $foundationRecordSection section must appear exactly once; found 0" 'Missing approved foundation record'

  $normalImplementationWithoutEvidence = New-LifecycleArtifact '10-code-migration' @($incrementalSelectedSection)
  $normalImplementationWithoutEvidenceResult = Invoke-ActivationSliceArtifactValidator $roleArtifacts.review $normalImplementationWithoutEvidence
  Assert-True ($normalImplementationWithoutEvidenceResult.ExitCode -eq 1) "Step 11 must reject a normal completed step-10 predecessor without implementation linkage evidence. Output: $($normalImplementationWithoutEvidenceResult.Output)"
  Assert-Contains $normalImplementationWithoutEvidenceResult.Output 'changed-file structured section must appear exactly once; found 0' 'Normal step-10 predecessor implementation evidence'

  $blockedPreMutationImplementation = $normalImplementationWithoutEvidence.Replace(
    "status: approved`nresult: complete`napproval_source: human",
    "status: draft`nresult: blocked"
  ).TrimEnd() + "`n`n$domainBlockerSection"
  $blockedPreMutationResult = Invoke-ActivationSliceArtifactValidator $blockedPreMutationImplementation $roleArtifacts.incrementalPlan
  Assert-True ($blockedPreMutationResult.ExitCode -eq 0) "A structurally valid pre-mutation step-10 domain blocker must not require changed-file/test evidence. Output: $($blockedPreMutationResult.Output)"

  $unsubstantiatedBlockedRequirements = $roleArtifacts.requirements.Replace(
    "status: approved`nresult: complete`napproval_source: human",
    "status: draft`nresult: blocked"
  )
  $unsubstantiatedBlockedRequirementsResult = Invoke-ActivationSliceArtifactValidator $unsubstantiatedBlockedRequirements $roleArtifacts.discovery
  Assert-True ($unsubstantiatedBlockedRequirementsResult.ExitCode -eq 1) "A routed draft/blocked producer requires blocker evidence. Output: $($unsubstantiatedBlockedRequirementsResult.Output)"
  Assert-Contains $unsubstantiatedBlockedRequirementsResult.Output 'domain-blocking lifecycle requires canonical blocker evidence' 'Unsubstantiated producer domain blocker'

  foreach ($bootstrapPredicateMutation in @(
    [pscustomobject]@{
      Name = 'invalid resolved Foundation Baseline ID'
      Current = $roleArtifacts.greenfieldImplementation.Replace('FOUNDATION-001', 'garbage')
      Predecessor = $roleArtifacts.bootstrap.Replace('FOUNDATION-001', 'garbage')
    }
    [pscustomobject]@{
      Name = 'noncanonical greenfield Baseline Reference'
      Current = $roleArtifacts.greenfieldImplementation.Replace('| bootstrap-approved-001 | not-applicable | TR-REQ-001', '| bootstrap-approved-001 | unexpected-baseline | TR-REQ-001')
      Predecessor = $roleArtifacts.bootstrap.Replace('| bootstrap-approved-001 | not-applicable | TR-REQ-001', '| bootstrap-approved-001 | unexpected-baseline | TR-REQ-001')
    }
  )) {
    $result = Invoke-ActivationSliceArtifactValidator $bootstrapPredicateMutation.Current $bootstrapPredicateMutation.Predecessor
    Assert-True ($result.ExitCode -eq 1) "Step 09-to-10 must reject $($bootstrapPredicateMutation.Name). Output: $($result.Output)"
    Assert-Contains $result.Output 'bootstrap predecessor selected unit violates canonical resolved-foundation predicates' "Bootstrap predecessor $($bootstrapPredicateMutation.Name)"
  }

  $bootstrapSelectedMutations = @(
    [pscustomobject]@{ Field = 'Migration Unit ID'; Row = $greenfieldSelectedRow.Replace('UNIT-001', 'UNIT-002') }
    [pscustomobject]@{ Field = 'Plan Reference'; Row = $greenfieldSelectedRow.Replace('plan-001', 'plan-002') }
    [pscustomobject]@{ Field = 'Approval Reference'; Row = $greenfieldSelectedRow.Replace('approval-001', 'approval-002') }
    [pscustomobject]@{ Field = 'Mode Constraint'; Row = $greenfieldSelectedRow.Replace('greenfield/design-new', 'incremental/preserve-existing') }
    [pscustomobject]@{ Field = 'Bootstrap Scope'; Row = $greenfieldSelectedRow.Replace('required', 'not-required') }
    [pscustomobject]@{ Field = 'Foundation Baseline ID'; Row = $greenfieldSelectedRow.Replace('FOUNDATION-001', 'FOUNDATION-002') }
    [pscustomobject]@{ Field = 'Foundation Baseline Reference'; Row = $greenfieldSelectedRow.Replace('target-baseline-001', 'target-baseline-002') }
    [pscustomobject]@{ Field = 'Foundation Baseline Approval Reference'; Row = $greenfieldSelectedRow.Replace('bootstrap-approved-001', 'bootstrap-approved-002') }
    [pscustomobject]@{ Field = 'Baseline Reference'; Row = $greenfieldSelectedRow.Replace('| bootstrap-approved-001 | not-applicable | TR-REQ-001', '| bootstrap-approved-001 | unexpected-baseline | TR-REQ-001') }
    [pscustomobject]@{ Field = 'Trace IDs'; Row = $greenfieldSelectedRow.Replace('TR-REQ-001, TR-RENDER-001', 'TR-OTHER-001') }
  )
  foreach ($mutation in $bootstrapSelectedMutations) {
    $mutatedImplementation = $roleArtifacts.greenfieldImplementation.Replace($greenfieldSelectedRow, $mutation.Row)
    $result = Invoke-ActivationSliceArtifactValidator $mutatedImplementation $roleArtifacts.bootstrap
    Assert-True ($result.ExitCode -eq 1) "Step 09-to-10 must reject selected-unit $($mutation.Field) drift. Output: $($result.Output)"
    Assert-Contains $result.Output "bootstrap selected-unit field changed: $($mutation.Field)" "Bootstrap selected-unit $($mutation.Field) preservation"
  }

  $greenfieldParity = $roleArtifacts.parity.Replace('incremental/preserve-existing', 'greenfield/design-new')
  $greenfieldRegression = $roleArtifacts.regression.Replace('incremental/preserve-existing', 'greenfield/design-new')
  $greenfieldRegressionResult = Invoke-ActivationSliceArtifactValidator $greenfieldRegression $greenfieldParity
  Assert-True ($greenfieldRegressionResult.ExitCode -eq 1) "Step 14 must reject the greenfield route. Output: $($greenfieldRegressionResult.Output)"
  Assert-Contains $greenfieldRegressionResult.Output 'regression route requires selected-unit Mode Constraint incremental/preserve-existing and Bootstrap Scope not-required' 'Greenfield regression rejection'

  foreach ($parityMutation in @(
    [pscustomobject]@{ Name = 'missing Parity Verdict'; Text = Remove-MarkdownSection $roleArtifacts.parity 'Parity Verdict'; Expected = 'current Parity Verdict section must appear exactly once; found 0' }
    [pscustomobject]@{ Name = 'invalid Parity Verdict'; Text = $roleArtifacts.parity.Replace('| pass | parity-evidence-001 |', '| success | parity-evidence-001 |'); Expected = 'current Parity Verdict must be pass, fail, or blocked' }
    [pscustomobject]@{ Name = 'empty parity evidence'; Text = $roleArtifacts.parity.Replace('| pass | parity-evidence-001 |', '| pass |  |'); Expected = 'current Parity Verdict requires non-empty Evidence Reference' }
  )) {
    $result = Invoke-ActivationSliceArtifactValidator $parityMutation.Text $roleArtifacts.verification
    Assert-True ($result.ExitCode -eq 1) "Step 13 must reject $($parityMutation.Name). Output: $($result.Output)"
    Assert-Contains $result.Output $parityMutation.Expected "Step 13 $($parityMutation.Name)"
  }

  foreach ($regressionMutation in @(
    [pscustomobject]@{ Name = 'invalid applicability'; Text = $roleArtifacts.regression.Replace('| pass | required | pass |', '| pass | optional | pass |'); Expected = 'Regression Applicability must be required' }
    [pscustomobject]@{ Name = 'invalid verdict'; Text = $roleArtifacts.regression.Replace('| pass | required | pass |', '| pass | required | success |'); Expected = 'Regression Verdict must be pass, fail, or blocked' }
  )) {
    $result = Invoke-ActivationSliceArtifactValidator $regressionMutation.Text $roleArtifacts.parity
    Assert-True ($result.ExitCode -eq 1) "Step 14 must reject $($regressionMutation.Name). Output: $($result.Output)"
    Assert-Contains $result.Output $regressionMutation.Expected "Step 14 $($regressionMutation.Name)"
  }

  foreach ($artifactWithoutPredecessor in @(
    $roleArtifacts.discovery, $roleArtifacts.requirements, $roleArtifacts.incrementalPlan,
    $roleArtifacts.bootstrap, $roleArtifacts.incrementalImplementation, $roleArtifacts.review,
    $roleArtifacts.verification, $roleArtifacts.parity, $roleArtifacts.regression
  )) {
    $missingPredecessorResult = Invoke-ActivationSliceArtifactValidator $artifactWithoutPredecessor
    Assert-True ($missingPredecessorResult.ExitCode -eq 1) "A canonical role-table step must not pass without its immediate predecessor path. Output: $($missingPredecessorResult.Output)"
    Assert-Contains $missingPredecessorResult.Output 'requires immediate predecessor artifact' 'Mandatory immediate predecessor path'
  }
}

if ($Cluster -in @('Markdown', 'All')) {
  $artifactTableMatch = [regex]::Match(
    $completeActivationSlice,
    '(?m)^## Activation Slice[ \t]*\r?\n\r?\n(?<table>(?:^\|[^\r\n]*\|[ \t]*\r?\n?)+)'
  )
  Assert-True $artifactTableMatch.Success 'Markdown structural fixtures require the canonical Activation Slice table'
  $artifactTable = $artifactTableMatch.Groups['table'].Value.TrimEnd()
  $artifactPrefix = $completeActivationSlice.Substring(
    0,
    $completeActivationSlice.IndexOf('## Activation Slice', [StringComparison]::Ordinal)
  ).TrimEnd()

  $frontMatterHeadingComment = $completeActivationSlice.Replace(
    'result: complete',
    "result: complete`n## Activation Slice"
  )
  $frontMatterHeadingCommentResult = Invoke-ActivationSliceArtifactValidator $frontMatterHeadingComment
  Assert-True ($frontMatterHeadingCommentResult.ExitCode -eq 0) "A YAML comment that resembles a heading must remain outside Markdown structure. Output: $($frontMatterHeadingCommentResult.Output)"

  $frontMatterOnlyHeading = $artifactPrefix.Replace(
    'result: complete',
    "result: complete`n## Activation Slice"
  ) + "`n`n$artifactTable`n"
  $frontMatterOnlyHeadingResult = Invoke-ActivationSliceArtifactValidator $frontMatterOnlyHeading
  Assert-True ($frontMatterOnlyHeadingResult.ExitCode -eq 1) "A front-matter comment must not substitute for the visible canonical heading. Output: $($frontMatterOnlyHeadingResult.Output)"
  Assert-Contains $frontMatterOnlyHeadingResult.Output 'canonical Activation Slice section must appear exactly once; found 0' 'Front-matter heading comment isolation'

  foreach ($htmlStart in @('<div></div>', '</div>', '<hr>', '<div/>', '<x-custom>')) {
    $htmlOnlyArtifact = "$artifactPrefix`n`n$htmlStart`n## Activation Slice`n`n$artifactTable`n"
    $htmlOnlyResult = Invoke-ActivationSliceArtifactValidator $htmlOnlyArtifact
    Assert-True ($htmlOnlyResult.ExitCode -eq 1) "A canonical section before the raw-HTML terminating blank must remain excluded for $htmlStart. Output: $($htmlOnlyResult.Output)"
    Assert-Contains $htmlOnlyResult.Output 'canonical Activation Slice section must appear exactly once; found 0' "CommonMark HTML start $htmlStart"
  }

  $blankTerminatedHtmlArtifact = "$artifactPrefix`n`n<div>`nraw HTML`n`n## Activation Slice`n`n$artifactTable`n"
  $blankTerminatedHtmlResult = Invoke-ActivationSliceArtifactValidator $blankTerminatedHtmlArtifact
  Assert-True ($blankTerminatedHtmlResult.ExitCode -eq 0) "A blank line must terminate a CommonMark type-6 HTML block before the canonical heading. Output: $($blankTerminatedHtmlResult.Output)"

  $paragraphInterruptedGenericTag = "$artifactPrefix`n`nordinary paragraph`n<x-custom>`n## Activation Slice`n`n$artifactTable`n"
  $paragraphInterruptedGenericResult = Invoke-ActivationSliceArtifactValidator $paragraphInterruptedGenericTag
  Assert-True ($paragraphInterruptedGenericResult.ExitCode -eq 0) "A CommonMark type-7 generic tag cannot interrupt a paragraph and must not hide the following heading. Output: $($paragraphInterruptedGenericResult.Output)"

  $pipeParagraphGenericTag = "$completeActivationSlice`n| ordinary paragraph`n<x-custom>`n## Activation Slice`n$artifactTable`n"
  $pipeParagraphGenericResult = Invoke-ActivationSliceArtifactValidator $pipeParagraphGenericTag
  Assert-True ($pipeParagraphGenericResult.ExitCode -eq 1) "A pipe-prefixed ordinary paragraph must keep a following type-7 tag from hiding a duplicate heading. Output: $($pipeParagraphGenericResult.Output)"
  Assert-Contains $pipeParagraphGenericResult.Output 'canonical Activation Slice section must appear exactly once; found 2' 'Pipe-prefixed paragraph before generic tag'

  $invalidGenericTag = "$completeActivationSlice`n`n<x ?>`n## Activation Slice`n$artifactTable`n"
  $invalidGenericTagResult = Invoke-ActivationSliceArtifactValidator $invalidGenericTag
  Assert-True ($invalidGenericTagResult.ExitCode -eq 1) "An invalid CommonMark open tag must not hide a duplicate heading. Output: $($invalidGenericTagResult.Output)"
  Assert-Contains $invalidGenericTagResult.Output 'canonical Activation Slice section must appear exactly once; found 2' 'Invalid generic open tag'

  $tabInUnquotedAttribute = "$completeActivationSlice`n`n<x a=foo`t?>`n## Activation Slice`n$artifactTable`n"
  $tabInUnquotedAttributeResult = Invoke-ActivationSliceArtifactValidator $tabInUnquotedAttribute
  Assert-True ($tabInUnquotedAttributeResult.ExitCode -eq 1) "A tab cannot occur inside an unquoted CommonMark HTML attribute value or hide a duplicate heading. Output: $($tabInUnquotedAttributeResult.Output)"
  Assert-Contains $tabInUnquotedAttributeResult.Output 'canonical Activation Slice section must appear exactly once; found 2' 'Tab in unquoted type-7 attribute'

  $indentedParagraphContinuation = "$completeActivationSlice`n`nordinary paragraph`n    continued`n<x-custom>`n## Activation Slice`n$artifactTable`n"
  $indentedParagraphContinuationResult = Invoke-ActivationSliceArtifactValidator $indentedParagraphContinuation
  Assert-True ($indentedParagraphContinuationResult.ExitCode -eq 1) "Indented continuation text cannot interrupt an open paragraph and enable a type-7 HTML decoy. Output: $($indentedParagraphContinuationResult.Output)"
  Assert-Contains $indentedParagraphContinuationResult.Output 'canonical Activation Slice section must appear exactly once; found 2' 'Indented paragraph continuation before type-7 tag'

  $thematicBreakGenericTag = "$artifactPrefix`n`n---`n<x-custom>`n## Activation Slice`n$artifactTable`n"
  $thematicBreakGenericResult = Invoke-ActivationSliceArtifactValidator $thematicBreakGenericTag
  Assert-True ($thematicBreakGenericResult.ExitCode -eq 1) "A thematic break must close paragraph context so a following type-7 HTML block hides the canonical heading. Output: $($thematicBreakGenericResult.Output)"
  Assert-Contains $thematicBreakGenericResult.Output 'canonical Activation Slice section must appear exactly once; found 0' 'Thematic break before generic tag'

  $underscoreAsyncTrace = $completeActivationSlice.Replace('TR-LIFECYCLE-001', 'TR_LIFECYCLE_001')
  $underscoreAsyncTraceResult = Invoke-ActivationSliceArtifactValidator $underscoreAsyncTrace
  Assert-True ($underscoreAsyncTraceResult.ExitCode -eq 0) "A non-empty async lifecycle Trace ID containing underscore must remain valid. Output: $($underscoreAsyncTraceResult.Output)"

  $closingHashHeading = $completeActivationSlice.Replace('## Activation Slice', '## Activation Slice ##')
  $closingHashHeadingResult = Invoke-ActivationSliceArtifactValidator $closingHashHeading
  Assert-True ($closingHashHeadingResult.ExitCode -eq 0) "A canonical ATX heading may use a closing hash sequence. Output: $($closingHashHeadingResult.Output)"

  $setextBoundaryArtifact = "$artifactPrefix`n`n## Activation Slice`n`nNo canonical table here.`n`nOther Section`n-------------`n`n$artifactTable`n"
  $setextBoundaryResult = Invoke-ActivationSliceArtifactValidator $setextBoundaryArtifact
  Assert-True ($setextBoundaryResult.ExitCode -eq 1) "A subsequent setext H2 must end the Activation Slice section before a later table. Output: $($setextBoundaryResult.Output)"
  Assert-Contains $setextBoundaryResult.Output 'canonical Activation Slice table must appear exactly once; found 0' 'Setext H2 section boundary'

  $multilineSetextDuplicate = "$completeActivationSlice`n`nActivation`nSlice`n---`n"
  $multilineSetextDuplicateResult = Invoke-ActivationSliceArtifactValidator $multilineSetextDuplicate
  Assert-True ($multilineSetextDuplicateResult.ExitCode -eq 1) "A soft-wrapped multiline setext H2 must be recognized as a duplicate canonical section. Output: $($multilineSetextDuplicateResult.Output)"
  Assert-Contains $multilineSetextDuplicateResult.Output 'canonical Activation Slice section must appear exactly once; found 2' 'Multiline setext duplicate heading'

  foreach ($decoratedHeading in @(
    '## Activation *Slice*',
    '## Activation `Slice`',
    '## [Activation Slice](https://example.invalid)',
    '## Activation <em>Slice</em>',
    '## Activation S&#108;ice'
  )) {
    $decoratedHeadingDuplicate = "$completeActivationSlice`n`n$decoratedHeading`n"
    $decoratedHeadingDuplicateResult = Invoke-ActivationSliceArtifactValidator $decoratedHeadingDuplicate
    Assert-True ($decoratedHeadingDuplicateResult.ExitCode -eq 1) "Inline Markdown must not disguise a duplicate canonical heading: $decoratedHeading. Output: $($decoratedHeadingDuplicateResult.Output)"
    Assert-Contains $decoratedHeadingDuplicateResult.Output 'canonical Activation Slice section must appear exactly once; found 2' 'Decorated duplicate heading'
  }

  $shortcutReferenceDuplicate = "$completeActivationSlice`n`n## [Activation Slice]`n`n[Activation Slice]: https://example.invalid`n"
  $shortcutReferenceDuplicateResult = Invoke-ActivationSliceArtifactValidator $shortcutReferenceDuplicate
  Assert-True ($shortcutReferenceDuplicateResult.ExitCode -eq 1) "A shortcut reference link must not disguise a duplicate canonical heading. Output: $($shortcutReferenceDuplicateResult.Output)"
  Assert-Contains $shortcutReferenceDuplicateResult.Output 'canonical Activation Slice section must appear exactly once; found 2' 'Shortcut-reference duplicate heading'

  foreach ($literalHeading in @('## Activation \*Slice\*', '## Activation `*Slice*`')) {
    $literalHeadingArtifact = "$completeActivationSlice`n`n$literalHeading`n"
    $literalHeadingResult = Invoke-ActivationSliceArtifactValidator $literalHeadingArtifact
    Assert-True ($literalHeadingResult.ExitCode -eq 0) "Escaped/code-span punctuation renders a distinct heading and must not create a false duplicate: $literalHeading. Output: $($literalHeadingResult.Output)"
  }

  $atxThenThematicBreak = $completeActivationSlice.Replace(
    "## Activation Slice`n`n",
    "## Activation Slice`n`n### Notes`n---`n`n"
  )
  $atxThenThematicBreakResult = Invoke-ActivationSliceArtifactValidator $atxThenThematicBreak
  Assert-True ($atxThenThematicBreakResult.ExitCode -eq 0) "A thematic break after an ATX H3 must not be fabricated into a setext H2 section boundary. Output: $($atxThenThematicBreakResult.Output)"

  $nbspHeading = $completeActivationSlice.Replace('## Activation Slice', "## Activation Slice$([char]0x00A0)")
  $nbspHeadingResult = Invoke-ActivationSliceArtifactValidator $nbspHeading
  Assert-True ($nbspHeadingResult.ExitCode -eq 1) "Unicode whitespace is part of an ATX heading name and must not normalize to the canonical section. Output: $($nbspHeadingResult.Output)"
  Assert-Contains $nbspHeadingResult.Output 'canonical Activation Slice section must appear exactly once; found 0' 'Unicode heading whitespace'

  $nbspCells = $completeActivationSlice.Replace(
    '| ACT-001 | applicable |',
    "| $([char]0x00A0)ACT-001$([char]0x00A0) | $([char]0x00A0)applicable$([char]0x00A0) |"
  )
  $nbspCellsResult = Invoke-ActivationSliceArtifactValidator $nbspCells
  Assert-True ($nbspCellsResult.ExitCode -eq 1) "Unicode whitespace must remain part of machine-valued Markdown cells. Output: $($nbspCellsResult.Output)"

  $paddedCodeSpanCells = $completeActivationSlice.Replace(
    '| ACT-001 | applicable |',
    '| `  ACT-001  ` | `  applicable  ` |'
  )
  $paddedCodeSpanResult = Invoke-ActivationSliceArtifactValidator $paddedCodeSpanCells
  Assert-True ($paddedCodeSpanResult.ExitCode -eq 1) "CommonMark code-span normalization must retain one of two edge spaces and reject padded machine values. Output: $($paddedCodeSpanResult.Output)"

  $invalidBacktickFenceDecoy = @'
```text`invalid
## Activation Slice

__ARTIFACT_TABLE__
```
'@
  $invalidBacktickFenceArtifact = "$completeActivationSlice`n" + $invalidBacktickFenceDecoy.Replace('__ARTIFACT_TABLE__', $artifactTable)
  $invalidBacktickFenceResult = Invoke-ActivationSliceArtifactValidator $invalidBacktickFenceArtifact
  Assert-True ($invalidBacktickFenceResult.ExitCode -eq 1) "A backtick in a backtick-fence info string makes the opener invalid and must not hide a duplicate section. Output: $($invalidBacktickFenceResult.Output)"
  Assert-Contains $invalidBacktickFenceResult.Output 'canonical Activation Slice section must appear exactly once; found 2' 'Invalid backtick fence info string'

  $artifactDecoyControls = @(
    [pscustomobject]@{
      Name = 'HTML comment decoy'
      Text = "$completeActivationSlice`n<!--`n## Activation Slice`n`n$artifactTable`n-->"
    }
    [pscustomobject]@{
      Name = 'HTML div block decoy'
      Text = "$completeActivationSlice`n<div>`n## Activation Slice`n$artifactTable`n</div>`n"
    }
    [pscustomobject]@{
      Name = 'uppercase HTML DIV block decoy'
      Text = "$completeActivationSlice`n<DIV>`n## Activation Slice`n$artifactTable`n</DIV>`n"
    }
    [pscustomobject]@{
      Name = 'non-void HTML iframe block decoy'
      Text = "$completeActivationSlice`n<iframe>`n## Activation Slice`n$artifactTable`n</iframe>`n"
    }
    [pscustomobject]@{
      Name = 'indented-code table decoy'
      Text = "$completeActivationSlice`n" + (($artifactTable -split "`r?`n" | ForEach-Object { "    $_" }) -join "`n")
    }
    [pscustomobject]@{
      Name = 'H1-terminated section decoy'
      Text = "$completeActivationSlice`n# Appendix`n`n$artifactTable"
    }
  )
  foreach ($control in $artifactDecoyControls) {
    $result = Invoke-ActivationSliceArtifactValidator $control.Text
    Assert-True ($result.ExitCode -eq 0) "Markdown scanner must exclude $($control.Name). Output: $($result.Output)"
  }

  $threeSpaceArtifact = [regex]::Replace($completeActivationSlice, '(?m)^## Activation Slice[ \t]*$', '   ## Activation Slice')
  $threeSpaceArtifact = [regex]::Replace($threeSpaceArtifact, '(?m)^\|', '   |')
  $threeSpaceResult = Invoke-ActivationSliceArtifactValidator $threeSpaceArtifact
  Assert-True ($threeSpaceResult.ExitCode -eq 0) "Markdown headings and tables may have three leading spaces. Output: $($threeSpaceResult.Output)"

  $fourSpaceArtifact = [regex]::Replace($completeActivationSlice, '(?m)^## Activation Slice[ \t]*$', '    ## Activation Slice')
  $fourSpaceArtifact = [regex]::Replace($fourSpaceArtifact, '(?m)^\|', '    |')
  $fourSpaceResult = Invoke-ActivationSliceArtifactValidator $fourSpaceArtifact
  Assert-True ($fourSpaceResult.ExitCode -eq 1) "Markdown headings and tables with four leading spaces must be excluded. Output: $($fourSpaceResult.Output)"
  Assert-Contains $fourSpaceResult.Output 'canonical Activation Slice section must appear exactly once; found 0' 'Markdown four-space heading exclusion'

  $contractText = (Get-Content -Raw -Encoding utf8 (Join-Path $PSScriptRoot '../contracts/activation-slice.md')).Replace("`r`n", "`n")
  $unmatchedContractBacktick = $contractText.Replace(
    '| Migration Unit ID | `UNIT-[0-9]{3}` |',
    '| Migration Unit ID | `UNIT-[0-9]{3} |'
  )
  Assert-True ($unmatchedContractBacktick -cne $contractText) 'Unmatched contract backtick mutation must alter the identifier rule'
  $unmatchedContractBacktickResult = Invoke-ActivationSliceContractValidator $unmatchedContractBacktick
  Assert-True ($unmatchedContractBacktickResult.ExitCode -eq 1) "An unmatched contract inline-code delimiter must not normalize to a canonical rule value. Output: $($unmatchedContractBacktickResult.Output)"
  Assert-Contains $unmatchedContractBacktickResult.Output 'Identifier formats rules must match the canonical definition' 'Contract unmatched inline-code delimiter'

  $driftedSchemaRowContract = $contractText.Replace(
    '| `ACT-###` | applicability enum |',
    '| `BOGUS` | applicability enum |'
  )
  Assert-True ($driftedSchemaRowContract -cne $contractText) 'Artifact row schema value mutation must alter the canonical row'
  $driftedSchemaRowResult = Invoke-ActivationSliceContractValidator $driftedSchemaRowContract
  Assert-True ($driftedSchemaRowResult.ExitCode -eq 1) "The contract must pin every Artifact row-schema cell value. Output: $($driftedSchemaRowResult.Output)"
  Assert-Contains $driftedSchemaRowResult.Output 'Artifact row schema row must match the canonical definition' 'Canonical Artifact row schema values'
  $schemaTableMatch = [regex]::Match(
    $contractText,
    '(?m)^## Artifact row schema[ \t]*\n\n(?<table>(?:^[ ]{0,3}\|[^\r\n]*\|[ \t]*\n){3})'
  )
  Assert-True $schemaTableMatch.Success 'Markdown structural fixtures require the canonical contract Artifact row schema table'
  $schemaTable = $schemaTableMatch.Groups['table'].Value.TrimEnd()
  $schemaMarker = "## Artifact row schema`n`n"
  $commentDecoy = "<!--`n| Wrong | Columns |`n|---|---|`n| decoy | decoy |`n-->`n`n"
  $htmlDecoy = "<div>`n| Wrong | Columns |`n|---|---|`n| decoy | decoy |`n</div>`n`n"
  foreach ($control in @(
    [pscustomobject]@{ Name = 'contract HTML comment decoy'; Text = $contractText.Replace($schemaMarker, "$schemaMarker$commentDecoy") }
    [pscustomobject]@{ Name = 'contract HTML block decoy'; Text = $contractText.Replace($schemaMarker, "$schemaMarker$htmlDecoy") }
  )) {
    $result = Invoke-ActivationSliceContractValidator $control.Text
    Assert-True ($result.ExitCode -eq 0) "Contract scanner must exclude $($control.Name). Output: $($result.Output)"
  }

  $schemaLines = @($schemaTable -split "`n")
  $malformedSchemaTable = @($schemaLines)
  $malformedSchemaTable[1] = $malformedSchemaTable[1].Replace('---', '--')
  $malformedDelimiterContract = $contractText.Replace($schemaTable, ($malformedSchemaTable -join "`n"))
  $malformedDelimiterResult = Invoke-ActivationSliceContractValidator $malformedDelimiterContract
  Assert-True ($malformedDelimiterResult.ExitCode -eq 1) "Contract Artifact row schema must reject malformed delimiter syntax. Output: $($malformedDelimiterResult.Output)"
  Assert-Contains $malformedDelimiterResult.Output 'canonical Activation Slice table delimiter' 'Contract malformed Artifact row schema delimiter'

  $duplicateSchemaResult = Invoke-ActivationSliceContractValidator $contractText.Replace($schemaTable, "$schemaTable`n`n$schemaTable")
  Assert-True ($duplicateSchemaResult.ExitCode -eq 1) "Contract Artifact row schema must reject duplicate tables. Output: $($duplicateSchemaResult.Output)"
  Assert-Contains $duplicateSchemaResult.Output 'Artifact row schema table must appear exactly once; found 2' 'Contract duplicate Artifact row schema table'

  $extraSchemaRowContract = $contractText.Replace($schemaTable, "$schemaTable`n$($schemaLines[2])")
  $extraSchemaRowResult = Invoke-ActivationSliceContractValidator $extraSchemaRowContract
  Assert-True ($extraSchemaRowResult.ExitCode -eq 1) "Contract Artifact row schema must reject extra schema rows. Output: $($extraSchemaRowResult.Output)"
  Assert-Contains $extraSchemaRowResult.Output 'Artifact row schema must contain exactly one schema row; found 2' 'Contract Artifact row schema cardinality'
}

if ($Cluster -in @('Duplicates', 'All')) {
  $duplicateCases = @(
    [pscustomobject]@{
      Name = 'unrelated exact duplicate key'
      Text = $completeActivationSlice.Replace(
        'produced_at: 2026-08-18',
        "metadata: first`nmetadata: second`nproduced_at: 2026-08-18"
      )
      Key = 'metadata'
    }
    [pscustomobject]@{
      Name = 'decoded quoted duplicate key'
      Text = $completeActivationSlice.Replace(
        'produced_at: 2026-08-18',
        "metadata: first`n'metadata': second`nproduced_at: 2026-08-18"
      )
      Key = 'metadata'
    }
  )
  foreach ($case in $duplicateCases) {
    $result = Invoke-ActivationSliceArtifactValidator $case.Text
    Assert-True ($result.ExitCode -eq 1) "Restricted YAML must reject $($case.Name). Output: $($result.Output)"
    Assert-Contains $result.Output "duplicate top-level YAML key: $($case.Key)" "Restricted YAML $($case.Name)"
  }

  $canonicalWithCaseVariant = $completeActivationSlice.Replace('status: approved', "status: approved`nStatus: shadow-value")
  $caseVariantResult = Invoke-ActivationSliceArtifactValidator $canonicalWithCaseVariant
  Assert-True ($caseVariantResult.ExitCode -eq 0) "YAML-distinct status/Status keys must coexist when canonical status exists. Output: $($caseVariantResult.Output)"

  $missingCanonicalStatus = $completeActivationSlice.Replace('status: approved', 'Status: approved')
  $missingCanonicalResult = Invoke-ActivationSliceArtifactValidator $missingCanonicalStatus
  Assert-True ($missingCanonicalResult.ExitCode -eq 1) "A case variant must not satisfy the exact lowercase canonical status key. Output: $($missingCanonicalResult.Output)"
  Assert-Contains $missingCanonicalResult.Output 'front matter must contain exactly one status' 'Restricted YAML canonical lowercase status'

  $unrelatedCaseVariants = $completeActivationSlice.Replace(
    'produced_at: 2026-08-18',
    "Foo: first`nfoo: second`nproduced_at: 2026-08-18"
  )
  $unrelatedCaseVariantResult = Invoke-ActivationSliceArtifactValidator $unrelatedCaseVariants
  Assert-True ($unrelatedCaseVariantResult.ExitCode -eq 0) "YAML-distinct unrelated Foo/foo keys must remain valid. Output: $($unrelatedCaseVariantResult.Output)"
}

if ($Cluster -in @('Pipes', 'All')) {
  foreach ($oddRunLength in @(1, 3)) {
    $backslashRun = '\' * $oddRunLength
    $artifact = $completeActivationSlice.Replace('src/service:10', "src/service:10${backslashRun}|detail")
    $result = Invoke-ActivationSliceArtifactValidator $artifact
    Assert-True ($result.ExitCode -eq 0) "An odd $oddRunLength-backslash run must escape the Markdown table pipe. Output: $($result.Output)"
  }

  foreach ($evenRunLength in @(2, 4)) {
    $backslashRun = '\' * $evenRunLength
    $artifact = $completeActivationSlice.Replace('src/service:10', "src/service:10${backslashRun}|detail")
    $result = Invoke-ActivationSliceArtifactValidator $artifact
    Assert-True ($result.ExitCode -eq 1) "An even $evenRunLength-backslash run must leave the Markdown table pipe as a delimiter. Output: $($result.Output)"
    Assert-Contains $result.Output 'row has 12 cells; expected 11' "Even $evenRunLength-backslash Markdown pipe parity"
  }

  $escapedOuterDelimiter = $completeActivationSlice.Replace(
    '| ACT-001 | applicable | upstream-response | profile response | activation key | src/service:10 | TR-REQ-001, TR-UP-001 | reuse | verified | not-applicable | not-applicable |',
    '| ACT-001 | applicable | upstream-response | profile response | activation key | src/service:10 | TR-REQ-001, TR-UP-001 | reuse | verified | not-applicable | not-applicable \|'
  )
  $escapedOuterDelimiterResult = Invoke-ActivationSliceArtifactValidator $escapedOuterDelimiter
  Assert-True ($escapedOuterDelimiterResult.ExitCode -eq 1) "An odd-escaped trailing pipe is data, not the structural table delimiter. Output: $($escapedOuterDelimiterResult.Output)"

  $trailingSelectedSection = @'
## Selected Migration Unit

| Migration Unit ID | Plan Reference | Approval Reference | Mode Constraint | Bootstrap Scope | Foundation Baseline ID | Foundation Baseline Reference | Foundation Baseline Approval Reference | Baseline Reference | Trace IDs |
|---|---|---|---|---|---|---|---|---|---|
| UNIT-001 | plan-001 | approval-001 | incremental/preserve-existing | not-required | not-applicable | not-applicable | not-applicable | regression-baseline-001 | TR-REQ-001 \|
'@
  $pipeChangedFilesSection = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('RmlsZSDEkcOjIHRoYXkgxJHhu5Vp'))
  $pipeImplementationRecords = @"
## $pipeChangedFilesSection

| Migration Unit ID | Activation Slice ID | Seam | File | Change | Trace IDs |
|---|---|---|---|---|---|
| UNIT-001 | ACT-001 | render | target/render.dart | render selected unit | TR-REQ-001, TR-RENDER-001 |

## Activation Slice Test Evidence

| Migration Unit ID | Activation Slice ID | Seam | Test | Command | Result | Trace IDs |
|---|---|---|---|---|---|---|
| UNIT-001 | ACT-001 | test | activation lifecycle | test activation | PASS | TR-REQ-001, TR-LIFECYCLE-001 |
"@
  $pipePredecessor = $completeActivationSlice.Replace('step_id: 01-validate-inputs', 'step_id: 10-code-migration').TrimEnd() + "`n`n$trailingSelectedSection`n`n$pipeImplementationRecords"
  $pipeCurrent = $completeActivationSlice.Replace('step_id: 01-validate-inputs', 'step_id: 11-ai-review').TrimEnd() + "`n`n$trailingSelectedSection"
  $trailingSelectedResult = Invoke-ActivationSliceArtifactValidator $pipeCurrent $pipePredecessor
  Assert-True ($trailingSelectedResult.ExitCode -eq 1) "An odd-escaped outer delimiter in exactly preserved selected-unit rows must not pass. Output: $($trailingSelectedResult.Output)"
}

if ($testFailures.Count -gt 0) {
  $testFailures | ForEach-Object { Write-Output "FAIL: $_" }
  exit 1
}

Write-Output "PASS: Activation Slice final-fix scenarios ($Cluster)"

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$contractPath = Join-Path $root 'contracts/file-responsibility-conformance.md'
$validatorPath = Join-Path $root 'tests/validation/responsibility-conformance.validation.ps1'

if (-not (Test-Path -LiteralPath $contractPath)) {
  throw 'Responsibility contract file is missing'
}
. $validatorPath
$contract = Get-Content -Raw -Encoding utf8 -LiteralPath $contractPath
$errors = @(Test-ResponsibilityContractSchema -ContractText $contract)
if ($errors.Count -ne 0) { throw ($errors -join "`n") }

$responsibilityContractRow = '| RESP-### | canonical path | publicSymbol | presentation | one responsibility | CAP-### | TRACE-### | not-applicable | publicSymbol | none | target/reference#Symbol | preferred | factual-discovery-evidence | inspection:path:1-20 | target-exemplar | feature-local | evidence reference | VERIFY-OWNER-### | yes | not-applicable |'
$invalidResponsibilityContractRows = @(
  [pscustomobject]@{ Name = 'invalid Boundary Kind'; Row = $responsibilityContractRow.Replace('| presentation |', '| atomic-owner |'); Diagnostic = 'ARC-CONTRACT-BOUNDARY-KIND: Boundary Kind must be canonical' },
  [pscustomobject]@{ Name = 'invalid Conformance'; Row = $responsibilityContractRow.Replace('| yes | not-applicable |', '| PASS | not-applicable |'); Diagnostic = 'ARC-CONTRACT-CONFORMANCE: Conformance must be canonical' },
  [pscustomobject]@{ Name = 'mixed none Public Symbols'; Row = $responsibilityContractRow.Replace('| publicSymbol | none | target/reference', '| none; publicSymbol | none | target/reference'); Diagnostic = 'ARC-CONTRACT-PUBLIC-SYMBOLS: Public Symbols must be canonical' }
)
foreach ($case in $invalidResponsibilityContractRows) {
  $mutatedContract = $contract.Replace($responsibilityContractRow, $case.Row)
  if ($mutatedContract -ceq $contract) { throw "$($case.Name) contract mutation was a silent no-op" }
  $mutatedErrors = @(Test-ResponsibilityContractSchema -ContractText $mutatedContract)
  if ($mutatedErrors -notcontains $case.Diagnostic) { throw "$($case.Name) expected $($case.Diagnostic) but got: $($mutatedErrors -join '; ')" }
}

foreach ($entry in @(
  'Test-ResponsibilityDiscovery',
  'Test-ResponsibilityDesign',
  'Test-ResponsibilityPlan',
  'Test-ResponsibilityImplementation',
  'Test-ResponsibilityReview',
  'Test-ResponsibilityHandoff'
)) {
  if (-not (Get-Command $entry -ErrorAction SilentlyContinue)) {
    throw "Missing responsibility validator entry point: $entry"
  }
}

$verificationRow = '| VERIFY-OWNER-### | RESP-### | CAP-### | evidence path | scenario | unit | required | binding evidence | decision reference | PASS | not-applicable |'
$legacyVerificationContract = $contract.Replace($verificationRow, '| VER-### | RESP-### | CAP-### | evidence path | scenario | unit | required | binding evidence | decision reference | PASS | not-applicable |')
if ($legacyVerificationContract -ceq $contract) { throw 'Verification owner family drift fixture replacement failed' }
$legacyVerificationErrors = @(Test-ResponsibilityContractSchema -ContractText $legacyVerificationContract)
if ($legacyVerificationErrors -notcontains 'ARC-CONTRACT-VERIFICATION-ID-FAMILY: Verification Owner ID must use VERIFY-OWNER-*') {
  throw "Contract must reject VER-* family drift: $($legacyVerificationErrors -join '; ')"
}
$invalidVerificationRows = @(
  [pscustomobject]@{
    Name = 'verification evidence kind cannot use required before not-applicable-approved disposition'
    Row = '| VERIFY-OWNER-### | RESP-### | CAP-### | evidence path | scenario | required | not-applicable-approved | binding evidence | decision reference | PASS | not-applicable |'
  }
  [pscustomobject]@{
    Name = 'verification evidence kind cannot use not-applicable-approved before required disposition'
    Row = '| VERIFY-OWNER-### | RESP-### | CAP-### | evidence path | scenario | not-applicable-approved | required | binding evidence | decision reference | PASS | not-applicable |'
  }
)
foreach ($invalidVerificationRow in $invalidVerificationRows) {
  $invalidContract = $contract.Replace($verificationRow, $invalidVerificationRow.Row)
  if ($invalidContract -ceq $contract) { throw "Fixture replacement failed: $($invalidVerificationRow.Name)" }
  $invalidErrors = @(Test-ResponsibilityContractSchema -ContractText $invalidContract)
  if ($invalidErrors -notcontains 'ARC-CONTRACT-VERIFICATION-EVIDENCE-KIND: Evidence Kind must be canonical') {
    throw "Expected evidence-kind diagnostic for $($invalidVerificationRow.Name): $($invalidErrors -join '; ')"
  }
}

$rawVersionBody = "version: 1`napplicability: required"
$stageCases = @(
  [pscustomobject]@{ Name = 'DISCOVERY'; Invoke = { param($text) Test-ResponsibilityDiscovery -DiscoveryText '' -Mode incremental -ContractText $text } }
  [pscustomobject]@{ Name = 'DESIGN'; Invoke = { param($text) Test-ResponsibilityDesign -DiscoveryText '' -DesignText '' -Mode greenfield -ContractText $text } }
  [pscustomobject]@{ Name = 'PLAN'; Invoke = { param($text) Test-ResponsibilityPlan -DesignText '' -PlanText '' -WorkItemId 'WORK-001' -ContractText $text } }
  [pscustomobject]@{ Name = 'IMPLEMENTATION'; Invoke = { param($text) Test-ResponsibilityImplementation -DesignText '' -ImplementationText '' -ContractText $text } }
  [pscustomobject]@{ Name = 'REVIEW'; Invoke = { param($text) Test-ResponsibilityReview -ImplementationText '' -ReviewText '' -ContractText $text } }
  [pscustomobject]@{ Name = 'HANDOFF'; Invoke = { param($text) Test-ResponsibilityHandoff -SourceText '' -TargetText '' -ContractText $text } }
)
foreach ($stageCase in $stageCases) {
  $stageErrors = @(& $stageCase.Invoke $rawVersionBody)
  $expected = "ARC-$($stageCase.Name)-CONTRACT-VERSION: responsibility contract requires version 1 and applicability required"
  if ($stageErrors -notcontains $expected) {
    throw "Expected bounded-front-matter diagnostic for $($stageCase.Name): $($stageErrors -join '; ')"
  }
}

function Get-TestH2SectionMatch {
  param([string]$Text, [string]$Heading)

  $pattern = '(?ms)^##[ \t]+' + [regex]::Escape($Heading) + '[ \t]*\r?\n.*?(?=^##[ \t]+|\z)'
  $matches = @([regex]::Matches($Text, $pattern))
  if ($matches.Count -ne 1) { throw "Expected one test section for $Heading, found $($matches.Count)" }
  return $matches[0]
}

function Add-TestH2SectionDuplicate {
  param(
    [string]$Text,
    [string]$Heading,
    [ValidateSet('before','after')][string]$Position,
    [ValidateSet('exact','malformed','conflicting')][string]$CopyKind = 'exact',
    [string]$ConflictFrom = '',
    [string]$ConflictTo = ''
  )

  $section = Get-TestH2SectionMatch -Text $Text -Heading $Heading
  $copy = $section.Value
  $lineEnding = if ($copy.Contains("`r`n")) { "`r`n" } else { "`n" }
  $headingLine = [regex]::Match($copy, '\A[^\r\n]+\r?\n')
  if (-not $headingLine.Success) { throw "Cannot locate heading line for $Heading" }
  $copy = $copy.Insert($headingLine.Length, "### duplicate-$Position test scope$lineEnding$lineEnding")
  if ($CopyKind -ceq 'malformed') {
    $separator = [regex]::Match($copy, '(?m)^\|(?:[ \t]*:?-{3,}:?[ \t]*\|)+\r?$')
    if (-not $separator.Success) { throw "Cannot locate table separator for $Heading" }
    $malformedSeparator = $separator.Value.Replace('-', '=')
    $copy = $copy.Remove($separator.Index, $separator.Length).Insert($separator.Index, $malformedSeparator)
  }
  elseif ($CopyKind -ceq 'conflicting') {
    if ([string]::IsNullOrEmpty($ConflictFrom)) { throw "Conflicting copy for $Heading requires a source value" }
    $updatedCopy = $copy.Replace($ConflictFrom, $ConflictTo)
    if ($updatedCopy -ceq $copy) { throw "Conflicting copy mutation was a silent no-op for $Heading" }
    $copy = $updatedCopy
  }
  $sectionSeparator = if ($section.Value.EndsWith($lineEnding, [StringComparison]::Ordinal)) { '' } else { $lineEnding }
  $replacement = if ($Position -ceq 'before') { $copy + $sectionSeparator + $section.Value } else { $section.Value + $sectionSeparator + $copy }
  return $Text.Remove($section.Index, $section.Length).Insert($section.Index, $replacement)
}

function Add-TestHeadingCodeExample {
  param([string]$Text, [string]$Heading)

  $section = Get-TestH2SectionMatch -Text $Text -Heading $Heading
  $lineEnding = if ($Text.Contains("`r`n")) { "`r`n" } else { "`n" }
  $example = @(
    "Prose mention of $Heading is not a heading.",
    "### $Heading",
    "> ## $Heading",
    '```markdown',
    "## $Heading",
    '| code | example |',
    '```',
    ''
  ) -join $lineEnding
  return $Text.Insert($section.Index, $example + $lineEnding)
}

function Add-TestCommentedH2SectionDuplicate {
  param(
    [string]$Text,
    [string]$Heading,
    [ValidateSet('before','after')][string]$Position
  )

  $section = Get-TestH2SectionMatch -Text $Text -Heading $Heading
  $lineEnding = if ($Text.Contains("`r`n")) { "`r`n" } else { "`n" }
  $commentedCopy = "<!--$lineEnding$($section.Value)-->$lineEnding"
  $insertionIndex = if ($Position -ceq 'before') { $section.Index } else { $section.Index + $section.Length }
  return $Text.Insert($insertionIndex, $commentedCopy)
}

function Convert-TestH2SectionToCommentOnly {
  param([string]$Text, [string]$Heading)

  $section = Get-TestH2SectionMatch -Text $Text -Heading $Heading
  $lineEnding = if ($Text.Contains("`r`n")) { "`r`n" } else { "`n" }
  $commentedSection = "<!--$lineEnding$($section.Value)-->$lineEnding"
  return $Text.Remove($section.Index, $section.Length).Insert($section.Index, $commentedSection)
}

function Remove-TestH2Section {
  param([string]$Text, [string]$Heading)

  $section = Get-TestH2SectionMatch -Text $Text -Heading $Heading
  return $Text.Remove($section.Index, $section.Length)
}

function Add-TestFencedH2SectionExample {
  param(
    [string]$Text,
    [string]$Heading,
    [ValidateSet('`','~')][char]$FenceCharacter,
    [int]$OpeningLength,
    [int]$ClosingLength,
    [string]$InfoString = '',
    [string]$ClosingSuffix = ''
  )

  $section = Get-TestH2SectionMatch -Text $Text -Heading $Heading
  $lineEnding = if ($Text.Contains("`r`n")) { "`r`n" } else { "`n" }
  $openingFence = [string]::new($FenceCharacter, $OpeningLength) + $InfoString
  $closingFence = [string]::new($FenceCharacter, $ClosingLength) + $ClosingSuffix
  $example = "$openingFence$lineEnding$($section.Value)$closingFence$lineEnding"
  return $Text.Insert($section.Index, $example)
}

function Convert-TestLineEndings([string]$Text, [string]$NewLine) {
  return [regex]::Replace($Text, '\r?\n', $NewLine)
}

function Replace-TestFixtureText([string]$Text, [string]$OldValue, [string]$NewValue, [string]$Context) {
  $updated = $Text.Replace($OldValue, $NewValue)
  if ($updated -ceq $Text) { throw "$Context fixture replacement failed" }
  return $updated
}

function Assert-TestExactDiagnostics {
  param(
    [string]$Name,
    [AllowEmptyCollection()][string[]]$Actual,
    [AllowEmptyCollection()][string[]]$Expected
  )

  if ($Actual.Count -ne $Expected.Count) {
    throw "$Name expected exactly $($Expected.Count) diagnostic(s) [$($Expected -join '; ')] but got $($Actual.Count) [$($Actual -join '; ')]"
  }
  for ($index = 0; $index -lt $Expected.Count; $index++) {
    if ($Actual[$index] -cne $Expected[$index]) {
      throw "$Name diagnostic $index expected exact <$($Expected[$index])> but got <$($Actual[$index])>; full list: $($Actual -join '; ')"
    }
  }
  Write-Output "PASS: $Name"
}

foreach ($lineEndingCase in @(
  [pscustomobject]@{ Name = 'LF'; NewLine = "`n" }
  [pscustomobject]@{ Name = 'CRLF'; NewLine = "`r`n" }
)) {
  $contractWithLineEndings = Convert-TestLineEndings $contract $lineEndingCase.NewLine
  $duplicateContractMatrix = Add-TestH2SectionDuplicate -Text $contractWithLineEndings -Heading 'File Responsibility Matrix' -Position after
  Assert-TestExactDiagnostics "contract schema emits only the exact File Responsibility Matrix duplicate diagnostic ($($lineEndingCase.Name))" `
    @(Test-ResponsibilityContractSchema -ContractText $duplicateContractMatrix) `
    @('ARC-CONTRACT-HEADING-CARDINALITY: File Responsibility Matrix')
  $missingContractMatrix = Remove-TestH2Section -Text $contractWithLineEndings -Heading 'File Responsibility Matrix'
  Assert-TestExactDiagnostics "contract schema emits only the exact File Responsibility Matrix missing diagnostic ($($lineEndingCase.Name))" `
    @(Test-ResponsibilityContractSchema -ContractText $missingContractMatrix) `
    @('ARC-CONTRACT-MISSING-TABLE: File Responsibility Matrix')
}

$missingDiscoveryErrors = @(Test-ResponsibilityDiscovery -DiscoveryText '' -Mode incremental -ContractText $contract)
if ($missingDiscoveryErrors -notcontains 'responsibility-discovery-missing') {
  throw "Empty discovery evidence must be rejected: $($missingDiscoveryErrors -join '; ')"
}

$discoveryConcerns = @(
  'module/container composition',
  'main/child presentation boundaries',
  'unit/component organization',
  'controller/provider/state pattern',
  'routing and lifecycle',
  'localization',
  'service/config subscription and normalization',
  'test harness and production-boundary tests'
)

function New-DiscoveryClassificationFixture {
  param(
    [string]$Classification = 'preferred',
    [string]$Authority = 'factual-discovery-evidence',
    [string]$ClassificationEvidence = 'inspection:lib/target_shell.dart:10-80; inspection:test/target_shell_test.dart:10-60'
  )

  $rows = foreach ($concern in $discoveryConcerns) {
    "| $concern | lib/target_shell.dart | TargetShell, TargetController | working target pattern | one focused $concern responsibility | CAP-001 | VERIFY-OWNER-001 | same production responsibility and activation path | lib/target_shell.dart:10-80 | verified | $Classification | $Authority | $ClassificationEvidence |"
  }
  return @"
---
step_id: 02-discovery
status: draft
result: complete
produced_at: 2026-08-21
responsibility_contract:
  version: 1
  applicability: required
---

## Comparable Target Exemplars

| Concern | Path | Inspected Symbols | Observed Pattern | Primary Responsibility | Owned Capabilities | Verification Owner | Comparable Reason | Evidence | Inspection Status | Classification | Classification Authority | Classification Evidence |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
$($rows -join "`n")
"@
}

function Set-DiscoveryClassification([string]$Root, [string]$Classification, [string]$Authority, [string]$Evidence) {
  $path = Join-Path $Root '02-discovery.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $updated = [regex]::Replace(
    $text,
    '(?m)^(\| module/container composition \|[^\r\n]*?\|)\s*(?:preferred|compatibility-only|legacy-debt|no-equivalent)\s*\|\s*[^|]+\|\s*[^|]+\|\s*$',
    "`$1 $Classification | $Authority | $Evidence |",
    1
  )
  if ($updated -ceq $text) { throw 'Discovery classification fixture replacement failed' }
  Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
}

function Set-DiscoveryNoEquivalent([string]$Root, [string]$Authority, [string]$Evidence) {
  Set-DiscoveryClassification $Root 'no-equivalent' $Authority $Evidence
  $path = Join-Path $Root '02-discovery.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $updated = $text.Replace('| verified | no-equivalent |', '| no-equivalent | no-equivalent |')
  if ($updated -ceq $text) { throw 'Discovery inspection-status fixture replacement failed' }
  Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
}

function Invoke-DiscoveryClassificationCase([string]$Root) {
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath (Join-Path $Root '02-discovery.md')
  return @(Test-ResponsibilityDiscovery -DiscoveryText $text -Mode incremental -ContractText $contract)
}

function Assert-Rejected([string]$Name, [scriptblock]$Mutation, [string]$ExpectedDiagnostic) {
  $fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('aitoolkit-responsibility-discovery-' + [guid]::NewGuid().ToString('N'))
  try {
    [void](New-Item -ItemType Directory -Path $fixtureRoot -Force)
    Set-Content -Encoding utf8 -LiteralPath (Join-Path $fixtureRoot '02-discovery.md') -Value (New-DiscoveryClassificationFixture)
    & $Mutation $fixtureRoot
    $diagnostics = @(Invoke-DiscoveryClassificationCase $fixtureRoot)
    if ($diagnostics -notcontains $ExpectedDiagnostic) {
      throw "$Name expected $ExpectedDiagnostic but got: $($diagnostics -join '; ')"
    }
    Write-Output "PASS: $Name"
  }
  finally {
    if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
  }
}

function Assert-Accepted([string]$Name, [scriptblock]$Mutation) {
  $fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('aitoolkit-responsibility-discovery-' + [guid]::NewGuid().ToString('N'))
  try {
    [void](New-Item -ItemType Directory -Path $fixtureRoot -Force)
    Set-Content -Encoding utf8 -LiteralPath (Join-Path $fixtureRoot '02-discovery.md') -Value (New-DiscoveryClassificationFixture)
    & $Mutation $fixtureRoot
    $diagnostics = @(Invoke-DiscoveryClassificationCase $fixtureRoot)
    if ($diagnostics.Count -ne 0) { throw "$Name should pass but got: $($diagnostics -join '; ')" }
    Write-Output "PASS: $Name"
  }
  finally {
    if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
  }
}

Assert-Rejected 'agent cannot self-declare legacy debt' {
  param($root)
  Set-DiscoveryClassification $root 'legacy-debt' 'agent-opinion' 'looks aggregate'
} 'exemplar-classification-authority-missing'

Assert-Accepted 'project pack may classify compatibility-only' {
  param($root)
  Set-DiscoveryClassification $root 'compatibility-only' 'project-pack-rule' 'architecture-rules.md#RULE-007'
}

Assert-Rejected 'project-pack authority rejects owner-decision evidence' {
  param($root)
  Set-DiscoveryClassification $root 'compatibility-only' 'project-pack-rule' 'approval:OWNER-007'
} 'exemplar-classification-authority-missing'

Assert-Rejected 'owner-decision authority rejects project-pack evidence' {
  param($root)
  Set-DiscoveryClassification $root 'compatibility-only' 'approved-owner-decision' 'architecture-rules.md#RULE-007'
} 'exemplar-classification-authority-missing'

Assert-Rejected 'project-documentation authority rejects debt-record evidence' {
  param($root)
  Set-DiscoveryClassification $root 'legacy-debt' 'project-documentation' 'debt-record:DEBT-007'
} 'exemplar-classification-authority-missing'

Assert-Rejected 'project-documentation authority rejects Tech Lead conflict evidence' {
  param($root)
  Set-DiscoveryClassification $root 'legacy-debt' 'project-documentation' 'approval:TECH-LEAD-007'
} 'exemplar-classification-authority-missing'

Assert-Rejected 'debt-record authority rejects project documentation evidence' {
  param($root)
  Set-DiscoveryClassification $root 'legacy-debt' 'debt-record' 'architecture.md#DEBT-007'
} 'exemplar-classification-authority-missing'

Assert-Rejected 'debt-record authority rejects Tech Lead conflict evidence' {
  param($root)
  Set-DiscoveryClassification $root 'legacy-debt' 'debt-record' 'approval:TECH-LEAD-007'
} 'exemplar-classification-authority-missing'

Assert-Rejected 'Tech Lead conflict authority rejects project documentation evidence' {
  param($root)
  Set-DiscoveryClassification $root 'legacy-debt' 'tech-lead-approved-conflict' 'architecture.md#CONFLICT-007'
} 'exemplar-classification-authority-missing'

Assert-Rejected 'Tech Lead conflict authority rejects debt-record evidence' {
  param($root)
  Set-DiscoveryClassification $root 'legacy-debt' 'tech-lead-approved-conflict' 'debt-record:DEBT-007'
} 'exemplar-classification-authority-missing'

Assert-Rejected 'preferred requires repeated working evidence' {
  param($root)
  Set-DiscoveryClassification $root 'preferred' 'factual-discovery-evidence' 'inspection:lib/generic.dart:1'
} 'exemplar-classification-authority-missing'

Assert-Rejected 'preferred rejects duplicate working references' {
  param($root)
  Set-DiscoveryClassification $root 'preferred' 'factual-discovery-evidence' 'inspection:lib/target_shell.dart:10-80; inspection:lib/target_shell.dart:10-80'
} 'exemplar-classification-authority-missing'

Assert-Rejected 'preferred rejects weak shaped references' {
  param($root)
  Set-DiscoveryClassification $root 'preferred' 'factual-discovery-evidence' 'inspection:looks:good; inspection:seems:fine'
} 'exemplar-classification-authority-missing'

Assert-Rejected 'preferred rejects authoritative conflict evidence' {
  param($root)
  Set-DiscoveryClassification $root 'preferred' 'factual-discovery-evidence' 'inspection:lib/target_shell.dart:10-80; conflict:architecture-rules.md#RULE-007'
} 'exemplar-classification-authority-missing'

Assert-Rejected 'preferred rejects immutable conflict decision references' {
  param($root)
  Set-DiscoveryClassification $root 'preferred' 'factual-discovery-evidence' 'inspection:lib/target_shell.dart:10-80; inspection:architecture-rules.md#CONFLICT-007'
} 'exemplar-classification-authority-missing'

Assert-Rejected 'preferred rejects immutable debt decision references' {
  param($root)
  Set-DiscoveryClassification $root 'preferred' 'factual-discovery-evidence' 'inspection:lib/target_shell.dart:10-80; inspection:debt-register.md#DEBT-007'
} 'exemplar-classification-authority-missing'

Assert-Accepted 'preferred permits ordinary conflict-named source references' {
  param($root)
  Set-DiscoveryClassification $root 'preferred' 'factual-discovery-evidence' 'inspection:lib/conflict_resolver.dart:10-80; inspection:test/conflict_resolver_test.dart:10-60'
}

Assert-Accepted 'preferred discovery evidence is language-agnostic for Java and Python sources' {
  param($root)
  Set-DiscoveryClassification $root 'preferred' 'factual-discovery-evidence' 'inspection:backend/AdminCommandService.java#AdminCommandService; working-evidence:adapter/admin_pipeline.py:12-48'
}

Assert-Accepted 'preferred discovery evidence accepts another canonical source kind without an extension allowlist' {
  param($root)
  Set-DiscoveryClassification $root 'preferred' 'factual-discovery-evidence' 'inspection:core/admin_lock.rs#AdminLock; working-evidence:core/admin_lock_spec.kt:9-31'
}

foreach ($unsafePreferredEvidence in @(
  'inspection:../backend/AdminCommandService.java#AdminCommandService; working-evidence:adapter/admin_pipeline.py:12-48',
  'inspection:backend//AdminCommandService.java#AdminCommandService; working-evidence:adapter/admin_pipeline.py:12-48',
  'inspection:backend/AdminCommandService.java:10-20#AdminCommandService; working-evidence:adapter/admin_pipeline.py:12-48'
)) {
  Assert-Rejected "preferred rejects unsafe or ambiguous language-agnostic evidence: $unsafePreferredEvidence" {
    param($root)
    Set-DiscoveryClassification $root 'preferred' 'factual-discovery-evidence' $unsafePreferredEvidence
  } 'exemplar-classification-authority-missing'
}

Assert-Rejected 'no-equivalent requires factual search evidence' {
  param($root)
  Set-DiscoveryClassification $root 'no-equivalent' 'factual-discovery-evidence' 'looks unavailable'
} 'exemplar-classification-authority-missing'

Assert-Accepted 'no-equivalent accepts immutable search result evidence' {
  param($root)
  Set-DiscoveryNoEquivalent $root 'factual-discovery-evidence' 'search:discovery-search.md#query=target-shell,result=0'
}

Assert-Accepted 'no-equivalent accepts immutable inspection path evidence' {
  param($root)
  Set-DiscoveryNoEquivalent $root 'factual-discovery-evidence' 'inspection:lib/target_shell.dart:10-80'
}

Assert-Accepted 'no-equivalent accepts canonical Java inspection evidence' {
  param($root)
  Set-DiscoveryNoEquivalent $root 'factual-discovery-evidence' 'inspection:backend/MissingTarget.java#MissingTarget'
}

Assert-Accepted 'no-equivalent search evidence is not restricted to Markdown files' {
  param($root)
  Set-DiscoveryNoEquivalent $root 'factual-discovery-evidence' 'search:evidence/target-search.json#query=target-shell,result=0'
}

Assert-Rejected 'no-equivalent rejects traversing language-agnostic evidence paths' {
  param($root)
  Set-DiscoveryNoEquivalent $root 'factual-discovery-evidence' 'inspection:../backend/MissingTarget.java#MissingTarget'
} 'exemplar-classification-authority-missing'

Assert-Rejected 'duplicate classification row is rejected' {
  param($root)
  $path = Join-Path $root '02-discovery.md'
  Add-Content -Encoding utf8 -LiteralPath $path -Value '| module/container composition | lib/duplicate.dart | DuplicateShell | duplicate target pattern | duplicate responsibility | CAP-002 | VERIFY-OWNER-002 | duplicate | lib/duplicate.dart:1-2 | verified | preferred | factual-discovery-evidence | inspection:lib/duplicate.dart:1; inspection:test/duplicate_test.dart:1 |'
} 'exemplar-classification-row-duplicate'

Assert-Rejected 'discovery requires responsibility contract version' {
  param($root)
  $path = Join-Path $root '02-discovery.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $updated = $text.Replace("responsibility_contract:`n  version: 1`n  applicability: required`n", '')
  if ($updated -ceq $text) { throw 'Discovery version fixture replacement failed' }
  Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
} 'responsibility-contract-version-invalid'

Assert-Rejected 'discovery rejects wrong-scoped version values' {
  param($root)
  $path = Join-Path $root '02-discovery.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $updated = $text.Replace("responsibility_contract:`n  version: 1`n  applicability: required", "responsibility_contract:`n  version: 2`n  applicability: required`nother:`n  version: 1")
  if ($updated -ceq $text) { throw 'Discovery wrong-scoped version fixture replacement failed' }
  Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
} 'responsibility-contract-version-invalid'

Assert-Rejected 'discovery rejects mixed responsibility contract versions' {
  param($root)
  $path = Join-Path $root '02-discovery.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $updated = $text.Replace("  version: 1`n  applicability: required", "  version: 1`n  version: 2`n  applicability: required")
  if ($updated -ceq $text) { throw 'Discovery mixed-version fixture replacement failed' }
  Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
} 'responsibility-contract-version-invalid'

Assert-Rejected 'discovery rejects unknown responsibility contract children' {
  param($root)
  $path = Join-Path $root '02-discovery.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $updated = $text.Replace("  version: 1`n  applicability: required", "  version: 1`n  applicability: required`n  owner: discovery")
  if ($updated -ceq $text) { throw 'Discovery unknown-child fixture replacement failed' }
  Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
} 'responsibility-contract-version-invalid'

Assert-Rejected 'discovery rejects blank primary responsibility' {
  param($root)
  $path = Join-Path $root '02-discovery.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $updated = $text.Replace('| one focused module/container composition responsibility |', '|  |')
  if ($updated -ceq $text) { throw 'Discovery primary-responsibility fixture replacement failed' }
  Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
} 'responsibility-discovery-field-invalid'

Assert-Rejected 'discovery rejects malformed owned capability list' {
  param($root)
  $path = Join-Path $root '02-discovery.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $updated = $text.Replace('| CAP-001 |', '| capability-one |')
  if ($updated -ceq $text) { throw 'Discovery capability fixture replacement failed' }
  Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
} 'responsibility-discovery-field-invalid'

Assert-Rejected 'discovery rejects placeholder verification owner' {
  param($root)
  $path = Join-Path $root '02-discovery.md'
  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
  $updated = $text.Replace('| VERIFY-OWNER-001 |', '| <VERIFY-OWNER-###> |')
  if ($updated -ceq $text) { throw 'Discovery verification-owner fixture replacement failed' }
  Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
} 'responsibility-discovery-field-invalid'

$emptyDiscoveryDiagnostics = @(Test-ResponsibilityDiscovery -DiscoveryText '' -Mode incremental -ContractText $contract)
if ($emptyDiscoveryDiagnostics -notcontains 'responsibility-discovery-missing') {
  throw "Empty discovery input must be rejected: $($emptyDiscoveryDiagnostics -join '; ')"
}

function New-ResponsibilityDesignFixture {
  param(
    [string]$OwnerPath = 'ui/admin_panel.dart',
    [string]$OwnerSymbol = 'AdminPanel',
    [string]$CoLocationPolicy = 'feature-local',
    [string]$AtomicBoundaryId = 'not-applicable',
    [string]$CoLocationEvidence = 'same capability lifecycle verification and revert boundary',
    [string]$OwnedCapabilities = 'CAP-ADMIN-LOCK',
    [string]$TraceIds = 'REQ-101; AC-202; WORK-ADMIN-LOCK',
    [string]$ExemplarClassification = 'preferred',
    [string]$ClassificationAuthority = 'factual-discovery-evidence',
    [string]$ClassificationEvidence = 'inspection:lib/target_shell.dart:10-80; inspection:test/target_shell_test.dart:10-60',
    [string]$ArchitectureAuthority = 'target-exemplar',
    [string]$DeviationReference = 'not-applicable',
    [string]$ExternalEffects = 'none',
    [string]$BoundaryKind = 'presentation',
    [string]$PrimaryResponsibility = 'administer one locked capability',
    [string]$Conformance = 'yes',
    [string]$PublicSymbols = '__default__',
    [string]$EvidenceKind = 'contract',
    [string]$VerificationDisposition = 'required',
    [string]$DecisionReference = 'not-applicable'
  )

  $publicSymbols = if ($PublicSymbols -ceq '__default__') { "$OwnerSymbol; ${OwnerSymbol}Controller" } else { $PublicSymbols }
  $verificationOwnerId = 'VERIFY-OWNER-ADMIN-LOCK'
  return @"
---
step_id: 07-technical-design
status: draft
result: complete
produced_at: 2026-08-21
revision: DESIGN-ADMIN@2
responsibility_contract:
  version: 1
  applicability: required
---

## Planned File Tree

| Planned Path | Planned Symbol | Responsibility | Exemplar or Deviation Reference |
|---|---|---|---|
| $OwnerPath | $OwnerSymbol | $PrimaryResponsibility | lib/target_shell.dart#TargetShell |
| test/admin_lock_test.ps1 | AdminLockContract | verify the production owner | lib/target_shell.dart#TargetShell |

## File Responsibility Matrix

| Responsibility ID | Owner Path | Owner Symbol | Boundary Kind | Primary Responsibility | Owned Capability IDs | Trace IDs | Atomic Boundary ID | Public Symbols | External Effects | Target Exemplar | Exemplar Classification | Classification Authority | Classification Evidence | Architecture Authority | Co-location Policy | Co-location Evidence | Verification Owner References | Conformance | Deviation Reference |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| RESP-ADMIN-LOCK | $OwnerPath | $OwnerSymbol | $BoundaryKind | $PrimaryResponsibility | $OwnedCapabilities | $TraceIds | $AtomicBoundaryId | $publicSymbols | $ExternalEffects | lib/target_shell.dart#TargetShell | $ExemplarClassification | $ClassificationAuthority | $ClassificationEvidence | $ArchitectureAuthority | $CoLocationPolicy | $CoLocationEvidence | $verificationOwnerId | $Conformance | $DeviationReference |
| RESP-ADMIN-LOCK-TEST | test/admin_lock_test.ps1 | AdminLockContract | test | verify the production owner | CAP-ADMIN-LOCK | REQ-101; AC-202; WORK-ADMIN-LOCK | not-applicable | AdminLockContract | none | lib/target_shell.dart#TargetShell | preferred | factual-discovery-evidence | inspection:lib/target_shell.dart:10-80; inspection:test/target_shell_test.dart:10-60 | target-exemplar | not-applicable | not-applicable | not-applicable | yes | not-applicable |

## Verification Ownership Matrix

| Verification Owner ID | Production Responsibility ID | Capability ID | Evidence Path | Evidence Symbol or Scenario | Evidence Kind | Verification Disposition | Production Binding Evidence | Decision Reference | Verdict | Deviation Reference |
|---|---|---|---|---|---|---|---|---|---|---|
| $verificationOwnerId | RESP-ADMIN-LOCK | CAP-ADMIN-LOCK | test/admin_lock_test.ps1 | AdminLockContract | $EvidenceKind | $VerificationDisposition | invokes $OwnerPath#$OwnerSymbol | $DecisionReference | PASS | not-applicable |
"@
}

function Assert-DesignRejected(
  [string]$Name,
  [string]$DesignText,
  [string]$ExpectedDiagnostic,
  [ValidateSet('incremental','greenfield')][string]$Mode = 'incremental',
  [string]$DiscoveryText = (New-DiscoveryClassificationFixture)
) {
  $diagnostics = @(Test-ResponsibilityDesign -DiscoveryText $DiscoveryText -DesignText $DesignText -Mode $Mode -ContractText $contract)
  if ($diagnostics -notcontains $ExpectedDiagnostic) {
    throw "$Name expected $ExpectedDiagnostic but got: $($diagnostics -join '; ')"
  }
  Write-Output "PASS: $Name"
}

function Assert-DesignAccepted([string]$Name, [string]$DesignText) {
  $diagnostics = @(Test-ResponsibilityDesign -DiscoveryText (New-DiscoveryClassificationFixture) -DesignText $DesignText -Mode incremental -ContractText $contract)
  if ($diagnostics.Count -ne 0) {
    throw "$Name should pass but got: $($diagnostics -join '; ')"
  }
  Write-Output "PASS: $Name"
}

$aggregateDesign = New-ResponsibilityDesignFixture -OwnedCapabilities 'CAP-ADMIN-LOCK; CAP-ADMIN-AUDIT'
Assert-DesignRejected 'aggregate capabilities require approval' $aggregateDesign 'co-location-approval-missing'

Assert-DesignAccepted 'multiple trace IDs for one capability do not create multi-capability ownership' `
  (New-ResponsibilityDesignFixture -OwnedCapabilities 'CAP-ADMIN-LOCK' -TraceIds 'REQ-101; AC-202; WORK-ADMIN-LOCK')
$featureLocalDesign = New-ResponsibilityDesignFixture
Assert-DesignAccepted 'feature-local symbols share one capability' $featureLocalDesign
Assert-DesignAccepted 'truthful owner with no public symbols uses the lone canonical none sentinel' (New-ResponsibilityDesignFixture -PublicSymbols 'none')
Assert-DesignRejected 'mixed public symbols cannot include the none sentinel' (New-ResponsibilityDesignFixture -PublicSymbols 'none; AdminPanel') 'responsibility-capability-mismatch'
Assert-DesignRejected 'public symbol sentinel is case-sensitive' (New-ResponsibilityDesignFixture -PublicSymbols 'NONE') 'responsibility-capability-mismatch'
Assert-DesignRejected 'boundary kind must use the approved enum' (New-ResponsibilityDesignFixture -BoundaryKind 'atomic-owner') 'responsibility-capability-mismatch'
Assert-DesignRejected 'conformance must use the approved enum' (New-ResponsibilityDesignFixture -Conformance 'PASS') 'responsibility-capability-mismatch'
Assert-DesignRejected 'conforming owner cannot cite a deviation' (New-ResponsibilityDesignFixture -Conformance 'yes' -DeviationReference 'DEV-ADMIN-001') 'responsibility-capability-mismatch'
Assert-DesignRejected 'nonconforming owner requires an approved deviation reference' (New-ResponsibilityDesignFixture -Conformance 'no') 'responsibility-capability-mismatch'
Assert-DesignRejected 'blocked conformance remains a blocking design diagnostic' (New-ResponsibilityDesignFixture -Conformance 'blocked') 'responsibility-capability-mismatch'
$approvedNonconformingDesign = (New-ResponsibilityDesignFixture -ExemplarClassification 'compatibility-only' -ClassificationAuthority 'project-pack-rule' -ClassificationEvidence 'architecture-rules.md#RULE-007' -ArchitectureAuthority 'approved-structural-deviation' -DeviationReference 'DEV-ADMIN-001' -Conformance 'no').TrimEnd() + @"

## Approved Structural Deviations

| Deviation Reference | Concern | Conflict Reference | Resolved Decision | Tech Lead Approval |
|---|---|---|---|---|
| DEV-ADMIN-001 | responsibility ownership | CONFLICT-ADMIN-001 | resolved:DECISION-ADMIN-001: preserve approved compatibility owner | approval:TECH-LEAD-ADMIN-001 |
"@
$approvedNonconformingDiscovery = [regex]::Replace((New-DiscoveryClassificationFixture), '(?m)(^\| module/container composition \|[^\r\n]*\| verified \|) preferred \| factual-discovery-evidence \| inspection:lib/target_shell\.dart:10-80; inspection:test/target_shell_test\.dart:10-60 \|$', '$1 compatibility-only | project-pack-rule | architecture-rules.md#RULE-007 |', 1)
$approvedNonconformingDiagnostics = @(Test-ResponsibilityDesign -DiscoveryText $approvedNonconformingDiscovery -DesignText $approvedNonconformingDesign -Mode incremental -ContractText $contract)
if ($approvedNonconformingDiagnostics.Count -ne 0) { throw "approved Conformance=no design should pass but got: $($approvedNonconformingDiagnostics -join '; ')" }
Write-Output 'PASS: approved deviation permits gate PASS while preserving Conformance=no'

$greenfieldDiscovery = New-DiscoveryClassificationFixture
$greenfieldDesign = (New-ResponsibilityDesignFixture).Replace('target-exemplar', 'approved-greenfield-design')
$greenfieldDiagnostics = @(Test-ResponsibilityDesign -DiscoveryText $greenfieldDiscovery -DesignText $greenfieldDesign -Mode greenfield -ContractText $contract)
if ($greenfieldDiagnostics.Count -ne 0) {
  throw "approved greenfield design authority should pass without a deviation but got: $($greenfieldDiagnostics -join '; ')"
}
Write-Output 'PASS: approved greenfield design authority does not require a deviation'
$fakeGreenfieldDeviation = $greenfieldDesign.Replace('approved-greenfield-design', 'approved-structural-deviation')
Assert-DesignRejected 'greenfield cannot be converted to fake deviation' $fakeGreenfieldDeviation 'greenfield-authority-invalid' -Mode greenfield -DiscoveryText $greenfieldDiscovery

$designWithoutRevision = $featureLocalDesign.Replace("revision: DESIGN-ADMIN@2`n", '')
Assert-DesignRejected 'design requires canonical approved revision' $designWithoutRevision 'responsibility-owner-extra'

$sharedFoundationDesign = New-ResponsibilityDesignFixture -CoLocationPolicy 'shared-foundation' -CoLocationEvidence 'shared engine capability with no concrete registration or feature effect'
Assert-DesignAccepted 'shared engine owns shared capability only' $sharedFoundationDesign

$debtExemplarDesign = New-ResponsibilityDesignFixture -ExemplarClassification 'legacy-debt' -ClassificationAuthority 'debt-record' -ClassificationEvidence 'debt-record:DEBT-ADMIN-001'
Assert-DesignRejected 'legacy debt cannot be propagated' $debtExemplarDesign 'debt-exemplar-propagation'

$atomicDesign = New-ResponsibilityDesignFixture -CoLocationPolicy 'atomic-owner' -AtomicBoundaryId 'ATOM-ADMIN-LOCK' -CoLocationEvidence 'shared transaction lifecycle test and revert boundary; approval:TECH-LEAD-ADMIN-LOCK'
Assert-DesignAccepted 'approved atomic owner' $atomicDesign

$duplicateMatrix = $featureLocalDesign + "`n`n" + [regex]::Match($featureLocalDesign, '(?s)## File Responsibility Matrix.*?(?=## Verification Ownership Matrix)').Value
Assert-TestExactDiagnostics 'duplicate responsibility matrix emits only its exact cardinality diagnostic' `
  @(Test-ResponsibilityDesign -DiscoveryText (New-DiscoveryClassificationFixture) -DesignText $duplicateMatrix -Mode incremental -ContractText $contract) `
  @('ARC-CONTRACT-HEADING-CARDINALITY: File Responsibility Matrix')

foreach ($lineEndingCase in @(
  [pscustomobject]@{ Name = 'LF'; NewLine = "`n" }
  [pscustomobject]@{ Name = 'CRLF'; NewLine = "`r`n" }
)) {
  $designWithLineEndings = Convert-TestLineEndings $featureLocalDesign $lineEndingCase.NewLine
  Assert-DesignAccepted "canonical single Planned File Tree is accepted ($($lineEndingCase.Name))" $designWithLineEndings

  $backtick = [string][char]96
  $inlineCommentDelimiterProbe = @(
    ($backtick + '<!--' + $backtick)
    '## Probe'
    '| A |'
    '|---|'
    '| first |'
    ($backtick + '-->' + $backtick)
    '## Probe'
    '| A |'
    '|---|'
    '| second |'
  ) -join $lineEndingCase.NewLine
  $inlineProbeHeadingCount = @(Get-ArcMarkdownH2HeadingMatches -Text $inlineCommentDelimiterProbe -Heading 'Probe').Count
  if ($inlineProbeHeadingCount -ne 2) {
    throw "inline-code HTML comment delimiters must leave both Probe headings visible ($($lineEndingCase.Name)); got $inlineProbeHeadingCount"
  }
  $inlineProbeErrors = [Collections.Generic.List[string]]::new()
  $inlineProbeRows = @(Get-ArcStrictMarkdownTable -Text $inlineCommentDelimiterProbe -Heading 'Probe' -Columns @('A') -Errors $inlineProbeErrors)
  if ($inlineProbeRows.Count -ne 0) {
    throw "duplicate Probe headings must prevent table extraction ($($lineEndingCase.Name)); got $($inlineProbeRows.Count) row(s)"
  }
  Assert-TestExactDiagnostics "inline-code HTML comment delimiters emit exact heading/table cardinality ($($lineEndingCase.Name))" `
    @($inlineProbeErrors.ToArray()) `
    @('ARC-CONTRACT-HEADING-CARDINALITY: Probe')

  $twoLineBackticks = [string]::new([char]96, 2)
  $multilineInlineCodeProbe = @(
    ($twoLineBackticks + ' open inline code')
    ('continued <!-- literal ' + $twoLineBackticks)
    '## Probe'
    '| A |'
    '|---|'
    '| first |'
    ($twoLineBackticks + ' open inline code')
    ('continued --> literal ' + $twoLineBackticks)
    '## Probe'
    '| A |'
    '|---|'
    '| second |'
  ) -join $lineEndingCase.NewLine
  $multilineProbeErrors = [Collections.Generic.List[string]]::new()
  $multilineProbeRows = @(Get-ArcStrictMarkdownTable -Text $multilineInlineCodeProbe -Heading 'Probe' -Columns @('A') -Errors $multilineProbeErrors)
  if ($multilineProbeRows.Count -ne 0) {
    throw "multiline inline-code delimiters must leave duplicate Probe tables unparsed ($($lineEndingCase.Name)); got $($multilineProbeRows.Count) row(s)"
  }
  Assert-TestExactDiagnostics "multiline inline-code spans preserve line boundaries and exact heading/table cardinality ($($lineEndingCase.Name))" `
    @($multilineProbeErrors.ToArray()) `
    @('ARC-CONTRACT-HEADING-CARDINALITY: Probe')

  $invalidFenceInsideMultilineSpanProbe = @(
    '## Probe'
    '| A |'
    '|---|'
    '| first |'
    ($twoLineBackticks + ' open inline code')
    ('```bad`info <!-- literal')
    ('continued literal ' + $twoLineBackticks)
    '## Probe'
    '| A |'
    '|---|'
    '| second |'
    '-->'
  ) -join $lineEndingCase.NewLine
  $invalidFenceProbeErrors = [Collections.Generic.List[string]]::new()
  $invalidFenceProbeRows = @(Get-ArcStrictMarkdownTable -Text $invalidFenceInsideMultilineSpanProbe -Heading 'Probe' -Columns @('A') -Errors $invalidFenceProbeErrors)
  if ($invalidFenceProbeRows.Count -ne 0) {
    throw "an invalid backtick fence inside multiline inline code must not hide the duplicate Probe table ($($lineEndingCase.Name)); got $($invalidFenceProbeRows.Count) row(s)"
  }
  Assert-TestExactDiagnostics "multiline inline-code matching ignores invalid backtick fence openers ($($lineEndingCase.Name))" `
    @($invalidFenceProbeErrors.ToArray()) `
    @('ARC-CONTRACT-HEADING-CARDINALITY: Probe')

  $treeForInlineCode = Get-TestH2SectionMatch -Text $designWithLineEndings -Heading 'Planned File Tree'
  $treeSectionSeparator = if ($treeForInlineCode.Value.EndsWith($lineEndingCase.NewLine, [StringComparison]::Ordinal)) { '' } else { $lineEndingCase.NewLine }
  $twoBackticks = [string]::new([char]96, 2)
  $threeBackticks = [string]::new([char]96, 3)
  $fourBackticks = [string]::new([char]96, 4)
  $sixBackticks = [string]::new([char]96, 6)
  $sevenBackticks = [string]::new([char]96, 7)
  $multiBacktickOpenLiteral = $threeBackticks + ' ' + $fourBackticks + '<!--' + $twoBackticks + ' ' + $threeBackticks
  $multiBacktickCloseLiteral = $sevenBackticks + ' ' + $sixBackticks + '-->' + $sixBackticks + ' ' + $sevenBackticks
  $multiBacktickDuplicate = $designWithLineEndings.Insert(
    $treeForInlineCode.Index,
    $multiBacktickOpenLiteral + $lineEndingCase.NewLine + $treeForInlineCode.Value + $treeSectionSeparator + $multiBacktickCloseLiteral + $lineEndingCase.NewLine
  )
  Assert-TestExactDiagnostics "matching multi-backtick spans keep shorter and longer backtick runs plus HTML delimiters literal ($($lineEndingCase.Name))" `
    @(Test-ResponsibilityDesign -DiscoveryText (New-DiscoveryClassificationFixture) -DesignText $multiBacktickDuplicate -Mode incremental -ContractText $contract) `
    @('ARC-CONTRACT-HEADING-CARDINALITY: Planned File Tree')

  $unmatchedSpanCommentedCopy = $twoBackticks + ' unmatched inline opener <!--' + $lineEndingCase.NewLine + $treeForInlineCode.Value + $treeSectionSeparator + '-->' + $lineEndingCase.NewLine + 'later block delimiter ' + $twoBackticks + $lineEndingCase.NewLine
  Assert-DesignAccepted "an unmatched backtick run cannot shield a later real HTML comment ($($lineEndingCase.Name))" `
    $designWithLineEndings.Insert($treeForInlineCode.Index, $unmatchedSpanCommentedCopy)

  $codeThenAdjacentComment = $backtick + '<!--' + $backtick + '<!--' + $lineEndingCase.NewLine + $treeForInlineCode.Value + $treeSectionSeparator + '-->' + $lineEndingCase.NewLine
  Assert-DesignAccepted "a real HTML comment immediately after inline code still hides its duplicate section ($($lineEndingCase.Name))" `
    $designWithLineEndings.Insert($treeForInlineCode.Index, $codeThenAdjacentComment)

  $commentThenInlineDelimiters = '<!-- real parser comment -->' + $backtick + '<!--' + $backtick + $lineEndingCase.NewLine + $treeForInlineCode.Value + $treeSectionSeparator + $backtick + '-->' + $backtick + $lineEndingCase.NewLine
  Assert-TestExactDiagnostics "inline-code delimiters immediately after a real HTML comment cannot hide a duplicate section ($($lineEndingCase.Name))" `
    @(Test-ResponsibilityDesign -DiscoveryText (New-DiscoveryClassificationFixture) -DesignText $designWithLineEndings.Insert($treeForInlineCode.Index, $commentThenInlineDelimiters) -Mode incremental -ContractText $contract) `
    @('ARC-CONTRACT-HEADING-CARDINALITY: Planned File Tree')

  $compactInlineHeadingCopy = Replace-TestFixtureText $treeForInlineCode.Value '## Planned File Tree' '## Planned <!--> File Tree' 'compact inline heading comment'
  Assert-TestExactDiagnostics "compact <!--> in a duplicate canonical heading is removed without swallowing the later section ($($lineEndingCase.Name))" `
    @(Test-ResponsibilityDesign -DiscoveryText (New-DiscoveryClassificationFixture) -DesignText $designWithLineEndings.Insert($treeForInlineCode.Index, $compactInlineHeadingCopy + $treeSectionSeparator) -Mode incremental -ContractText $contract) `
    @('ARC-CONTRACT-HEADING-CARDINALITY: Planned File Tree')

  $compactBeforeDuplicate = '<!-->' + $lineEndingCase.NewLine + $treeForInlineCode.Value + $treeSectionSeparator
  Assert-TestExactDiagnostics "compact <!--> before duplicate canonical sections preserves exact cardinality ($($lineEndingCase.Name))" `
    @(Test-ResponsibilityDesign -DiscoveryText (New-DiscoveryClassificationFixture) -DesignText $designWithLineEndings.Insert($treeForInlineCode.Index, $compactBeforeDuplicate) -Mode incremental -ContractText $contract) `
    @('ARC-CONTRACT-HEADING-CARDINALITY: Planned File Tree')

  $compactBetweenDuplicates = $treeForInlineCode.Value + $treeSectionSeparator + '<!--->' + $lineEndingCase.NewLine
  Assert-TestExactDiagnostics "compact <!---> between duplicate canonical sections preserves exact cardinality ($($lineEndingCase.Name))" `
    @(Test-ResponsibilityDesign -DiscoveryText (New-DiscoveryClassificationFixture) -DesignText $designWithLineEndings.Insert($treeForInlineCode.Index, $compactBetweenDuplicates) -Mode incremental -ContractText $contract) `
    @('ARC-CONTRACT-HEADING-CARDINALITY: Planned File Tree')

  $duplicateResponsibilityMatrix = Add-TestH2SectionDuplicate -Text $designWithLineEndings -Heading 'File Responsibility Matrix' -Position after
  Assert-TestExactDiagnostics "design emits only the exact File Responsibility Matrix duplicate diagnostic ($($lineEndingCase.Name))" `
    @(Test-ResponsibilityDesign -DiscoveryText (New-DiscoveryClassificationFixture) -DesignText $duplicateResponsibilityMatrix -Mode incremental -ContractText $contract) `
    @('ARC-CONTRACT-HEADING-CARDINALITY: File Responsibility Matrix')
  $missingResponsibilityMatrix = Remove-TestH2Section -Text $designWithLineEndings -Heading 'File Responsibility Matrix'
  Assert-TestExactDiagnostics "design emits only the exact File Responsibility Matrix missing diagnostic ($($lineEndingCase.Name))" `
    @(Test-ResponsibilityDesign -DiscoveryText (New-DiscoveryClassificationFixture) -DesignText $missingResponsibilityMatrix -Mode incremental -ContractText $contract) `
    @('ARC-CONTRACT-MISSING-TABLE: File Responsibility Matrix')
  foreach ($position in @('before', 'after')) {
    $duplicateTree = Add-TestH2SectionDuplicate -Text $designWithLineEndings -Heading 'Planned File Tree' -Position $position
    Assert-TestExactDiagnostics "Planned File Tree emits only its exact duplicate diagnostic $position the canonical section ($($lineEndingCase.Name))" `
      @(Test-ResponsibilityDesign -DiscoveryText (New-DiscoveryClassificationFixture) -DesignText $duplicateTree -Mode incremental -ContractText $contract) `
      @('ARC-CONTRACT-HEADING-CARDINALITY: Planned File Tree')
  }
  foreach ($position in @('before', 'after')) {
    $malformedSecondTree = Add-TestH2SectionDuplicate -Text $designWithLineEndings -Heading 'Planned File Tree' -Position $position -CopyKind malformed
    Assert-TestExactDiagnostics "Planned File Tree emits only its exact malformed-copy diagnostic $position the canonical section ($($lineEndingCase.Name))" `
      @(Test-ResponsibilityDesign -DiscoveryText (New-DiscoveryClassificationFixture) -DesignText $malformedSecondTree -Mode incremental -ContractText $contract) `
      @('ARC-CONTRACT-HEADING-CARDINALITY: Planned File Tree')
  }
  Assert-DesignAccepted "Planned File Tree ignores prose, H3, blockquote, and fenced-code mentions ($($lineEndingCase.Name))" `
    (Add-TestHeadingCodeExample -Text $designWithLineEndings -Heading 'Planned File Tree')
  foreach ($position in @('before', 'after')) {
    $commentedTree = Add-TestCommentedH2SectionDuplicate -Text $designWithLineEndings -Heading 'Planned File Tree' -Position $position
    Assert-DesignAccepted "Planned File Tree ignores a multiline HTML-comment duplicate $position the canonical section ($($lineEndingCase.Name))" $commentedTree
  }
  $inlineHeadingComment = Replace-TestFixtureText $designWithLineEndings '## Planned File Tree' '## Planned<!-- parser note --> File Tree' 'inline heading comment'
  Assert-DesignAccepted "Planned File Tree ignores a single-line inline HTML comment in the canonical heading ($($lineEndingCase.Name))" $inlineHeadingComment
  $spacedInlineHeadingComment = Replace-TestFixtureText $designWithLineEndings '## Planned File Tree' '## Planned <!-- parser note --> File Tree' 'spaced inline heading comment'
  Assert-DesignAccepted "Planned File Tree normalizes whitespace around an ignored inline HTML comment ($($lineEndingCase.Name))" $spacedInlineHeadingComment
  $inlineTableComment = Replace-TestFixtureText $designWithLineEndings '| ui/admin_panel.dart | AdminPanel |' '| ui/admin_panel.dart | <!-- parser note --> AdminPanel |' 'inline table comment'
  Assert-DesignAccepted "Planned File Tree ignores a single-line HTML comment in canonical table content ($($lineEndingCase.Name))" $inlineTableComment
  $plannedTreeHeadingPrefix = "## Planned File Tree$($lineEndingCase.NewLine)$($lineEndingCase.NewLine)"
  $commentedTableExample = Replace-TestFixtureText $designWithLineEndings $plannedTreeHeadingPrefix `
    "$plannedTreeHeadingPrefix<!--$($lineEndingCase.NewLine)| hidden | table | example | only |$($lineEndingCase.NewLine)|---|---|---|---|$($lineEndingCase.NewLine)| fake | fake | fake | fake |$($lineEndingCase.NewLine)-->$($lineEndingCase.NewLine)" `
    'multiline commented table'
  Assert-DesignAccepted "Planned File Tree ignores a multiline HTML-comment table before canonical content ($($lineEndingCase.Name))" $commentedTableExample
  $fencedTableExample = Replace-TestFixtureText $designWithLineEndings $plannedTreeHeadingPrefix `
    "$plannedTreeHeadingPrefix~~~markdown$($lineEndingCase.NewLine)| hidden | table | example | only |$($lineEndingCase.NewLine)|---|---|---|---|$($lineEndingCase.NewLine)| fake | fake | fake | fake |$($lineEndingCase.NewLine)~~~~$($lineEndingCase.NewLine)" `
    'fenced table'
  Assert-DesignAccepted "Planned File Tree ignores a fenced table before canonical content ($($lineEndingCase.Name))" $fencedTableExample
  $commentPrefixedTableExample = Replace-TestFixtureText $designWithLineEndings $plannedTreeHeadingPrefix `
    "$plannedTreeHeadingPrefix<!-- parser note -->| Planned Path | Planned Symbol | Responsibility | Exemplar or Deviation Reference |$($lineEndingCase.NewLine)<!-- parser note -->|---|---|---|---|$($lineEndingCase.NewLine)<!-- parser note -->| hidden | fake | fake | fake |$($lineEndingCase.NewLine)" `
    'comment-prefixed table marker'
  Assert-DesignAccepted "HTML comment removal cannot move table markers to column zero ($($lineEndingCase.Name))" $commentPrefixedTableExample
  $commentContinuationTableExample = Replace-TestFixtureText $designWithLineEndings $plannedTreeHeadingPrefix `
    "$plannedTreeHeadingPrefix<!--$($lineEndingCase.NewLine)| hidden -->| Planned Path | Planned Symbol | Responsibility | Exemplar or Deviation Reference |$($lineEndingCase.NewLine)<!--$($lineEndingCase.NewLine)| hidden -->|---|---|---|---|$($lineEndingCase.NewLine)<!--$($lineEndingCase.NewLine)| hidden -->| hidden | fake | fake | fake |$($lineEndingCase.NewLine)" `
    'multiline-comment continuation table marker'
  Assert-DesignAccepted "multiline HTML comment removal cannot move table markers to column zero ($($lineEndingCase.Name))" $commentContinuationTableExample
  $commentOnlyTree = Convert-TestH2SectionToCommentOnly -Text $designWithLineEndings -Heading 'Planned File Tree'
  Assert-TestExactDiagnostics "comment-only Planned File Tree emits only its exact missing diagnostic ($($lineEndingCase.Name))" `
    @(Test-ResponsibilityDesign -DiscoveryText (New-DiscoveryClassificationFixture) -DesignText $commentOnlyTree -Mode incremental -ContractText $contract) `
    @('ARC-CONTRACT-MISSING-TABLE: Planned File Tree')
  $splitHeadingAcrossCommentLines = Replace-TestFixtureText $designWithLineEndings '## Planned File Tree' "## Planned<!--$($lineEndingCase.NewLine)parser note$($lineEndingCase.NewLine)--> File Tree" 'multiline split heading'
  Assert-DesignRejected "HTML comment removal preserves heading line boundaries ($($lineEndingCase.Name))" $splitHeadingAcrossCommentLines 'ARC-CONTRACT-MISSING-TABLE: Planned File Tree'

  foreach ($fenceCase in @(
    [pscustomobject]@{ Name = 'three-backtick'; Character = [char]'`'; Open = 3; Close = 3; Info = 'markdown' }
    [pscustomobject]@{ Name = 'four-backtick-longer-closer'; Character = [char]'`'; Open = 4; Close = 5; Info = 'markdown' }
    [pscustomobject]@{ Name = 'five-backtick'; Character = [char]'`'; Open = 5; Close = 5; Info = '' }
    [pscustomobject]@{ Name = 'three-tilde-with-backtick-info'; Character = [char]'~'; Open = 3; Close = 3; Info = 'markdown`example' }
    [pscustomobject]@{ Name = 'four-tilde-longer-closer'; Character = [char]'~'; Open = 4; Close = 6; Info = 'markdown' }
    [pscustomobject]@{ Name = 'five-tilde'; Character = [char]'~'; Open = 5; Close = 5; Info = '' }
  )) {
    $fencedTree = Add-TestFencedH2SectionExample -Text $designWithLineEndings -Heading 'Planned File Tree' -FenceCharacter $fenceCase.Character -OpeningLength $fenceCase.Open -ClosingLength $fenceCase.Close -InfoString $fenceCase.Info
    Assert-DesignAccepted "Planned File Tree ignores a valid $($fenceCase.Name) example ($($lineEndingCase.Name))" $fencedTree
  }

  $treeSection = Get-TestH2SectionMatch -Text $designWithLineEndings -Heading 'Planned File Tree'
  $shortCloserExample = ([string]::new([char]'`', 4) + "markdown$($lineEndingCase.NewLine)" + [string]::new([char]'`', 3) + $lineEndingCase.NewLine + $treeSection.Value + [string]::new([char]'`', 4) + $lineEndingCase.NewLine)
  Assert-DesignAccepted "a shorter backtick closer cannot expose a fenced canonical example ($($lineEndingCase.Name))" $designWithLineEndings.Insert($treeSection.Index, $shortCloserExample)
  $malformedCloserExample = ("~~~markdown$($lineEndingCase.NewLine)~~~ not-a-closer$($lineEndingCase.NewLine)" + $treeSection.Value + "~~~$($lineEndingCase.NewLine)")
  Assert-DesignAccepted "a closer with trailing content cannot expose a fenced canonical example ($($lineEndingCase.Name))" $designWithLineEndings.Insert($treeSection.Index, $malformedCloserExample)
  $wrongCharacterCloserExample = ([string]::new([char]'`', 4) + "markdown$($lineEndingCase.NewLine)" + [string]::new([char]'~', 4) + $lineEndingCase.NewLine + $treeSection.Value + [string]::new([char]'`', 4) + $lineEndingCase.NewLine)
  Assert-DesignAccepted "a wrong-character closer cannot expose a fenced canonical example ($($lineEndingCase.Name))" $designWithLineEndings.Insert($treeSection.Index, $wrongCharacterCloserExample)

  $invalidBacktickOpener = '```bad``info' + $lineEndingCase.NewLine
  Assert-DesignAccepted "a backtick info string containing backticks cannot hide the later canonical heading ($($lineEndingCase.Name))" $designWithLineEndings.Insert($treeSection.Index, $invalidBacktickOpener)
  $invalidCommentedBacktickInfo = '```markdown<!-- ` remains part of info -->' + $lineEndingCase.NewLine
  Assert-DesignAccepted "an HTML comment cannot erase a backtick from an invalid fence info string ($($lineEndingCase.Name))" $designWithLineEndings.Insert($treeSection.Index, $invalidCommentedBacktickInfo)
  $commentSplicedFenceMarker = '``<!-- parser note -->`markdown' + $lineEndingCase.NewLine
  Assert-DesignAccepted "HTML comment removal cannot assemble a backtick fence marker ($($lineEndingCase.Name))" $designWithLineEndings.Insert($treeSection.Index, $commentSplicedFenceMarker)
  $commentSplicedH2Marker = '#<!-- parser note --># Planned File Tree' + $lineEndingCase.NewLine
  Assert-DesignAccepted "HTML comment removal cannot assemble an H2 marker ($($lineEndingCase.Name))" $designWithLineEndings.Insert($treeSection.Index, $commentSplicedH2Marker)
  $commentPrefixedTreeCopy = Replace-TestFixtureText $treeSection.Value '## Planned File Tree' '<!-- parser note -->## Planned File Tree' 'comment-prefixed H2 marker'
  Assert-DesignAccepted "HTML comment removal cannot move an H2 marker to column zero ($($lineEndingCase.Name))" $designWithLineEndings.Insert($treeSection.Index, $commentPrefixedTreeCopy)
  $commentContinuationTreeCopy = "<!--$($lineEndingCase.NewLine)## hidden -->## Planned File Tree$($lineEndingCase.NewLine)"
  Assert-DesignAccepted "multiline HTML comment removal cannot move an H2 marker to column zero ($($lineEndingCase.Name))" $designWithLineEndings.Insert($treeSection.Index, $commentContinuationTreeCopy)
  $realDuplicateTrees = Add-TestH2SectionDuplicate -Text $designWithLineEndings -Heading 'Planned File Tree' -Position after
  $firstTree = Get-TestH2SectionMatch -Text $designWithLineEndings -Heading 'Planned File Tree'
  Assert-DesignRejected "an invalid backtick opener cannot hide later real duplicate headings ($($lineEndingCase.Name))" $realDuplicateTrees.Insert($firstTree.Index, $invalidBacktickOpener) 'ARC-CONTRACT-HEADING-CARDINALITY: Planned File Tree'
}

$selfLabeledTestOwner = $featureLocalDesign.Replace('| ui/admin_panel.dart | AdminPanel | presentation |', '| ui/admin_panel.dart | AdminPanel | test |')
Assert-DesignRejected 'production owner cannot self-label as test to evade verification' $selfLabeledTestOwner 'verification-owner-missing'

$invalidVerificationVerdict = $featureLocalDesign.Replace('| PASS | not-applicable |', '| UNKNOWN | not-applicable |')
Assert-DesignRejected 'verification verdict must be canonical' $invalidVerificationVerdict 'verification-disposition-invalid'

foreach ($eligibleCase in @(
  [pscustomobject]@{ Name = 'config'; Path = 'config/admin_lock.yaml'; Primary = 'declare admin lock configuration'; Kind = 'static-structure' }
  [pscustomobject]@{ Name = 'manifest'; Path = 'manifests/admin_lock.yaml'; Primary = 'declare deployment manifest'; Kind = 'static-structure' }
  [pscustomobject]@{ Name = 'generated'; Path = 'generated/admin_lock.g.dart'; Primary = 'emit generated configuration'; Kind = 'generator-verification' }
  [pscustomobject]@{ Name = 'schema'; Path = 'schema/admin_lock.json'; Primary = 'declare settings schema'; Kind = 'static-structure' }
  [pscustomobject]@{ Name = 'build wiring'; Path = 'build/admin_lock.targets'; Primary = 'declare build wiring'; Kind = 'static-structure' }
)) {
  $eligibleDesign = New-ResponsibilityDesignFixture -OwnerPath $eligibleCase.Path -OwnerSymbol 'AdminLockConfig' -BoundaryKind config -PrimaryResponsibility $eligibleCase.Primary -PublicSymbols 'AdminLockConfig' -EvidenceKind $eligibleCase.Kind -VerificationDisposition 'not-applicable-approved' -DecisionReference 'approval:TECH-LEAD-ADMIN-LOCK'
  Assert-DesignAccepted "canonical not-applicable-approved permits $($eligibleCase.Name) structural ownership" $eligibleDesign
}
foreach ($ineligibleCase in @(
  [pscustomobject]@{ Name = 'behavior'; Boundary = 'application'; Primary = 'own runtime behavior' }
  [pscustomobject]@{ Name = 'routing'; Boundary = 'integration'; Primary = 'own routing' }
  [pscustomobject]@{ Name = 'lifecycle'; Boundary = 'application'; Primary = 'own lifecycle' }
  [pscustomobject]@{ Name = 'effect'; Boundary = 'application'; Primary = 'own effect' }
  [pscustomobject]@{ Name = 'destructive operation'; Boundary = 'application'; Primary = 'own destructive operation' }
  [pscustomobject]@{ Name = 'composition'; Boundary = 'integration'; Primary = 'own composition' }
)) {
  $ineligibleDesign = New-ResponsibilityDesignFixture -BoundaryKind $ineligibleCase.Boundary -PrimaryResponsibility $ineligibleCase.Primary -EvidenceKind 'static-structure' -VerificationDisposition 'not-applicable-approved' -DecisionReference 'approval:OWNER-ADMIN-LOCK'
  Assert-DesignRejected "not-applicable-approved rejects $($ineligibleCase.Name) ownership" $ineligibleDesign 'verification-disposition-invalid'
}
$pathHeuristicDesign = New-ResponsibilityDesignFixture -OwnerPath 'config/admin_panel.dart' -BoundaryKind presentation -PrimaryResponsibility 'display settings' -EvidenceKind 'static-structure' -VerificationDisposition 'not-applicable-approved' -DecisionReference 'approval:OWNER-ADMIN-LOCK'
Assert-DesignRejected 'config-looking path cannot authorize not-applicable-approved' $pathHeuristicDesign 'verification-disposition-invalid'
$wrongEvidenceKindDesign = New-ResponsibilityDesignFixture -BoundaryKind config -PrimaryResponsibility 'declare settings' -EvidenceKind contract -VerificationDisposition 'not-applicable-approved' -DecisionReference 'approval:OWNER-ADMIN-LOCK'
Assert-DesignRejected 'behavioral evidence kind cannot authorize not-applicable-approved' $wrongEvidenceKindDesign 'verification-disposition-invalid'
$effectfulConfigDesign = New-ResponsibilityDesignFixture -BoundaryKind config -PrimaryResponsibility 'synchronize settings' -ExternalEffects 'settings.write' -EvidenceKind production-composition -VerificationDisposition 'not-applicable-approved' -DecisionReference 'approval:OWNER-ADMIN-LOCK'
Assert-DesignRejected 'effectful config cannot authorize not-applicable-approved' $effectfulConfigDesign 'verification-disposition-invalid'
$foreignApprovalDesign = New-ResponsibilityDesignFixture -BoundaryKind config -PrimaryResponsibility 'declare settings' -EvidenceKind static-structure -VerificationDisposition 'not-applicable-approved' -DecisionReference 'approval:OWNER-FOREIGN'
Assert-DesignRejected 'foreign approval cannot authorize not-applicable-approved' $foreignApprovalDesign 'verification-disposition-invalid'
$freeFormApprovalDesign = New-ResponsibilityDesignFixture -BoundaryKind config -PrimaryResponsibility 'declare settings' -EvidenceKind static-structure -VerificationDisposition 'not-applicable-approved' -DecisionReference 'approval:OWNER-ADMIN-LOCK-NOTE'
Assert-DesignRejected 'free-form approval suffix cannot authorize not-applicable-approved' $freeFormApprovalDesign 'verification-disposition-invalid'
$malformedApprovalDesign = New-ResponsibilityDesignFixture -BoundaryKind config -PrimaryResponsibility 'declare settings' -EvidenceKind static-structure -VerificationDisposition 'not-applicable-approved' -DecisionReference 'approved by owner'
Assert-DesignRejected 'malformed approval cannot authorize not-applicable-approved' $malformedApprovalDesign 'verification-disposition-invalid'

foreach ($crossLanguageOwner in @(
  [pscustomobject]@{ Path = 'ui/admin_panel.dart'; Symbol = 'AdminPanel' },
  [pscustomobject]@{ Path = 'backend/AdminCommandService.java'; Symbol = 'AdminCommandService' },
  [pscustomobject]@{ Path = 'adapter/admin_pipeline.py'; Symbol = 'AdminPipeline' }
)) {
  Assert-DesignAccepted "cross-language owner $($crossLanguageOwner.Path)#$($crossLanguageOwner.Symbol) follows the same responsibility contract" (New-ResponsibilityDesignFixture -OwnerPath $crossLanguageOwner.Path -OwnerSymbol $crossLanguageOwner.Symbol)
}

function New-ResponsibilityPlanDesignFixture {
  return @"
---
step_id: 07-technical-design
status: approved
result: complete
approval_source: human
run_id: RUN-ADMIN-001
produced_at: 2026-08-21
revision: DESIGN-ADMIN@2
responsibility_contract:
  version: 1
  applicability: required
---

## File Responsibility Matrix

| Responsibility ID | Owner Path | Owner Symbol | Boundary Kind | Primary Responsibility | Owned Capability IDs | Trace IDs | Atomic Boundary ID | Public Symbols | External Effects | Target Exemplar | Exemplar Classification | Classification Authority | Classification Evidence | Architecture Authority | Co-location Policy | Co-location Evidence | Verification Owner References | Conformance | Deviation Reference |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| RESP-WIFI | ui/admin_wifi.dart | AdminWifi | presentation | administer wireless lock | CAP-ADMIN-WIFI | REQ-101; WORK-ADMIN-LOCK | not-applicable | AdminWifi | none | lib/target_shell.dart#TargetShell | preferred | factual-discovery-evidence | inspection:lib/target_shell.dart:10-80 | target-exemplar | feature-local | same capability lifecycle verification and revert boundary | VERIFY-OWNER-WIFI | yes | not-applicable |
| RESP-WIRED | ui/admin_wired.dart | AdminWired | presentation | administer wired lock | CAP-ADMIN-WIRED | REQ-102; WORK-ADMIN-LOCK | not-applicable | AdminWired | none | lib/target_shell.dart#TargetShell | preferred | factual-discovery-evidence | inspection:lib/target_shell.dart:10-80 | target-exemplar | feature-local | same capability lifecycle verification and revert boundary | VERIFY-OWNER-WIRED | yes | not-applicable |
| RESP-LOCK-GUARD | lib/lock_guard.dart | LockGuard | adapter | provide shared lock guard | CAP-LOCK-GUARD | REQ-103; WORK-ADMIN-LOCK | not-applicable | LockGuard | none | lib/target_shell.dart#TargetShell | preferred | factual-discovery-evidence | inspection:lib/target_shell.dart:10-80 | target-exemplar | shared-foundation | shared capability with no concrete registration or feature effect | VERIFY-OWNER-LOCK-GUARD | yes | not-applicable |
| RESP-LOCK-COMPOSITION | lib/admin_lock_composition.dart | AdminLockComposition | integration | compose admin lock owners | CAP-LOCK-COMPOSITION | REQ-104; WORK-ADMIN-LOCK | not-applicable | AdminLockComposition | route registration | lib/target_shell.dart#TargetShell | preferred | factual-discovery-evidence | inspection:lib/target_shell.dart:10-80 | target-exemplar | feature-local | production composition lifecycle and revert boundary | VERIFY-OWNER-LOCK-COMPOSITION | yes | not-applicable |

## Verification Ownership Matrix

| Verification Owner ID | Production Responsibility ID | Capability ID | Evidence Path | Evidence Symbol or Scenario | Evidence Kind | Verification Disposition | Production Binding Evidence | Decision Reference | Verdict | Deviation Reference |
|---|---|---|---|---|---|---|---|---|---|---|
| VERIFY-OWNER-WIFI | RESP-WIFI | CAP-ADMIN-WIFI | test/admin_lock_test.ps1 | AdminWifiContract | contract | required | invokes ui/admin_wifi.dart#AdminWifi | not-applicable | PASS | not-applicable |
| VERIFY-OWNER-WIRED | RESP-WIRED | CAP-ADMIN-WIRED | test/admin_lock_test.ps1 | AdminWiredContract | contract | required | invokes ui/admin_wired.dart#AdminWired | not-applicable | PASS | not-applicable |
| VERIFY-OWNER-LOCK-GUARD | RESP-LOCK-GUARD | CAP-LOCK-GUARD | test/lock_guard_test.ps1 | LockGuardContract | contract | required | invokes lib/lock_guard.dart#LockGuard | not-applicable | PASS | not-applicable |
| VERIFY-OWNER-LOCK-COMPOSITION | RESP-LOCK-COMPOSITION | CAP-LOCK-COMPOSITION | test/admin_lock_composition_test.ps1 | AdminLockCompositionContract | production-composition | required | invokes lib/admin_lock_composition.dart#AdminLockComposition | not-applicable | PASS | not-applicable |
"@
}

function New-ResponsibilityPlanFixture {
  param(
    [string]$ResponsibilityIds = 'RESP-WIFI, RESP-WIRED',
    [string]$SharedFoundationIds = 'RESP-LOCK-GUARD',
    [string]$IntegrationResponsibilityIds = 'RESP-LOCK-COMPOSITION',
    [string]$DesignRevision = 'DESIGN-ADMIN@2',
    [string]$AdapterDesignRevision = 'DESIGN-ADMIN@2',
    [string]$MigrationUnitId = 'UNIT-ADMIN-LOCK',
    [string]$IndependentBoundaryEvidence = 'architecture-rules.md#RULE-007: independently implementable, reviewable, verifiable, and revertible'
  )

  return @"
---
step_id: 08-plan-waves
status: draft
result: complete
run_id: RUN-ADMIN-001
produced_at: 2026-08-21
responsibility_contract:
  version: 1
  applicability: required
---

## Work Item Adapter Trace

| Migration Unit ID | Work Item ID | Parent Work Item ID | Master Plan Reference | Master Plan Revision | Decomposition Decision Reference | Design Revision |
|---|---|---|---|---|---|---|
| $MigrationUnitId | WORK-ADMIN-LOCK | not-applicable | master-plan.md | 2 | not-applicable | $AdapterDesignRevision |

## Responsibility Owner References

| Work Item ID | Design Revision | Responsibility IDs | Shared Foundation IDs | Integration Responsibility IDs | Independent Boundary Evidence |
|---|---|---|---|---|---|
| WORK-ADMIN-LOCK | $DesignRevision | $ResponsibilityIds | $SharedFoundationIds | $IntegrationResponsibilityIds | $IndependentBoundaryEvidence |
"@
}

function Assert-PlanRejected([string]$Name, [string]$PlanText, [string]$ExpectedDiagnostic, [string]$DesignText = (New-ResponsibilityPlanDesignFixture)) {
  $diagnostics = @(Test-ResponsibilityPlan -DesignText $DesignText -PlanText $PlanText -WorkItemId 'WORK-ADMIN-LOCK' -ContractText $contract)
  if ($diagnostics -notcontains $ExpectedDiagnostic) {
    throw "$Name expected $ExpectedDiagnostic but got: $($diagnostics -join '; ')"
  }
  Write-Output "PASS: $Name"
}

function Assert-PlanAccepted([string]$Name, [string]$PlanText, [string]$DesignText = (New-ResponsibilityPlanDesignFixture)) {
  $diagnostics = @(Test-ResponsibilityPlan -DesignText $DesignText -PlanText $PlanText -WorkItemId 'WORK-ADMIN-LOCK' -ContractText $contract)
  if ($diagnostics.Count -ne 0) {
    throw "$Name should pass but got: $($diagnostics -join '; ')"
  }
  Write-Output "PASS: $Name"
}

$validPlan = New-ResponsibilityPlanFixture
Assert-PlanAccepted 'plan preserves the exact ordered responsibility owner set' $validPlan
foreach ($lineEndingCase in @(
  [pscustomobject]@{ Name = 'LF'; NewLine = "`n" }
  [pscustomobject]@{ Name = 'CRLF'; NewLine = "`r`n" }
)) {
  $planWithLineEndings = Convert-TestLineEndings $validPlan $lineEndingCase.NewLine
  $duplicateAdapterTrace = Add-TestH2SectionDuplicate -Text $planWithLineEndings -Heading 'Work Item Adapter Trace' -Position after
  Assert-TestExactDiagnostics "plan emits only the exact Work Item Adapter Trace duplicate diagnostic ($($lineEndingCase.Name))" `
    @(Test-ResponsibilityPlan -DesignText (New-ResponsibilityPlanDesignFixture) -PlanText $duplicateAdapterTrace -WorkItemId 'WORK-ADMIN-LOCK' -ContractText $contract) `
    @('ARC-CONTRACT-HEADING-CARDINALITY: Work Item Adapter Trace')
  $missingAdapterTrace = Remove-TestH2Section -Text $planWithLineEndings -Heading 'Work Item Adapter Trace'
  Assert-TestExactDiagnostics "plan emits only the exact Work Item Adapter Trace missing diagnostic ($($lineEndingCase.Name))" `
    @(Test-ResponsibilityPlan -DesignText (New-ResponsibilityPlanDesignFixture) -PlanText $missingAdapterTrace -WorkItemId 'WORK-ADMIN-LOCK' -ContractText $contract) `
    @('ARC-CONTRACT-MISSING-TABLE: Work Item Adapter Trace')
}
Assert-PlanAccepted 'generic adapter keeps owner binding without migration unit taxonomy' (New-ResponsibilityPlanFixture -MigrationUnitId 'not-applicable')
$approvedPlan = $validPlan.Replace('status: draft', "status: approved`napproval_source: human`nrevision: 2")
Assert-PlanAccepted 'approved plan binds every adapter to its immutable front-matter revision' $approvedPlan
$mutableNotApplicableMasterReference = $approvedPlan.Replace(
  '| UNIT-ADMIN-LOCK | WORK-ADMIN-LOCK | not-applicable | master-plan.md | 2 | not-applicable | DESIGN-ADMIN@2 |',
  '| UNIT-ADMIN-LOCK | WORK-ADMIN-LOCK | not-applicable | master-plan.md@latest | 2 | not-applicable | DESIGN-ADMIN@2 |'
)
$orphanNotApplicableParent = $approvedPlan.Replace(
  '| UNIT-ADMIN-LOCK | WORK-ADMIN-LOCK | not-applicable | master-plan.md | 2 | not-applicable | DESIGN-ADMIN@2 |',
  '| UNIT-ADMIN-LOCK | WORK-ADMIN-LOCK | WORK-ORPHAN | master-plan.md | 2 | not-applicable | DESIGN-ADMIN@2 |'
)
$invalidNotApplicableParent = $approvedPlan.Replace(
  '| UNIT-ADMIN-LOCK | WORK-ADMIN-LOCK | not-applicable | master-plan.md | 2 | not-applicable | DESIGN-ADMIN@2 |',
  '| UNIT-ADMIN-LOCK | WORK-ADMIN-LOCK | not_applicable | master-plan.md | 2 | not-applicable | DESIGN-ADMIN@2 |'
)
Assert-PlanRejected 'approved plan rejects a non-decomposition adapter revision mismatch' ($approvedPlan.Replace('master-plan.md | 2 | not-applicable', 'master-plan.md | 3 | not-applicable')) 'responsibility-owner-extra'
$wrongStagePlan = $validPlan.Replace('step_id: 08-plan-waves', 'step_id: 07-technical-design')
Assert-PlanRejected 'plan rejects wrong artifact stage' $wrongStagePlan 'responsibility-owner-extra'
$unapprovedPlanDesign = (New-ResponsibilityPlanDesignFixture).Replace('status: approved', 'status: draft')
$unapprovedPlanDiagnostics = @(Test-ResponsibilityPlan -DesignText $unapprovedPlanDesign -PlanText $validPlan -WorkItemId 'WORK-ADMIN-LOCK' -ContractText $contract)
if ($unapprovedPlanDiagnostics -notcontains 'responsibility-owner-extra') {
  throw "plan rejects unapproved design evidence expected responsibility-owner-extra but got: $($unapprovedPlanDiagnostics -join '; ')"
}
Write-Output 'PASS: plan rejects unapproved design evidence'
Assert-PlanRejected 'plan rejects missing selected responsibility owner' (New-ResponsibilityPlanFixture -ResponsibilityIds 'RESP-WIFI') 'responsibility-owner-missing'
Assert-PlanRejected 'plan rejects foreign responsibility owner' (New-ResponsibilityPlanFixture -ResponsibilityIds 'RESP-WIFI, RESP-FOREIGN') 'responsibility-owner-extra'
Assert-PlanRejected 'plan rejects duplicate responsibility owner' (New-ResponsibilityPlanFixture -ResponsibilityIds 'RESP-WIFI, RESP-WIFI, RESP-WIRED') 'responsibility-owner-extra'
Assert-PlanRejected 'plan rejects stale design revision' (New-ResponsibilityPlanFixture -DesignRevision 'DESIGN-ADMIN@1') 'responsibility-owner-extra'
Assert-PlanRejected 'plan rejects revision stale in both owner and adapter rows' (New-ResponsibilityPlanFixture -DesignRevision 'DESIGN-ADMIN@1' -AdapterDesignRevision 'DESIGN-ADMIN@1') 'responsibility-owner-extra'
Assert-PlanRejected 'plan rejects noncanonical migration unit identifier' (New-ResponsibilityPlanFixture -MigrationUnitId 'WORK-ADMIN-LOCK') 'responsibility-owner-extra'
Assert-PlanRejected 'plan rejects shared foundation claimed as concrete owner' (New-ResponsibilityPlanFixture -ResponsibilityIds 'RESP-WIFI, RESP-WIRED, RESP-LOCK-GUARD' -SharedFoundationIds 'not-applicable') 'responsibility-owner-extra'
Assert-PlanRejected 'plan rejects forged independent boundary prose' (New-ResponsibilityPlanFixture -IndependentBoundaryEvidence 'I believe this is independently implementable, reviewable, verifiable, and revertible') 'responsibility-owner-missing'

$duplicateWorkItemReference = $validPlan + @"

| WORK-ADMIN-LOCK | DESIGN-ADMIN@2 | RESP-WIFI, RESP-WIRED | RESP-LOCK-GUARD | RESP-LOCK-COMPOSITION | architecture-rules.md#RULE-007: independently implementable, reviewable, verifiable, and revertible |
"@
Assert-PlanRejected 'plan rejects duplicate work-item owner reference' $duplicateWorkItemReference 'responsibility-owner-extra'

$unboundAdapter = $validPlan.Replace('| UNIT-ADMIN-LOCK | WORK-ADMIN-LOCK | not-applicable | master-plan.md | 2 | not-applicable | DESIGN-ADMIN@2 |', "| UNIT-ADMIN-LOCK | WORK-ADMIN-LOCK | not-applicable | master-plan.md | 2 | not-applicable | DESIGN-ADMIN@2 |`n| UNIT-OTHER | WORK-OTHER | not-applicable | master-plan.md | 2 | not-applicable | DESIGN-ADMIN@2 |")
if ($unboundAdapter -ceq $validPlan) { throw 'Unbound adapter fixture replacement failed' }
Assert-PlanRejected 'plan rejects adapter work item without responsibility owner reference' $unboundAdapter 'responsibility-owner-extra'

$duplicateAdapterHeading = $validPlan + @"

## Work Item Adapter Trace

| Migration Unit ID | Work Item ID | Parent Work Item ID | Master Plan Reference | Master Plan Revision | Decomposition Decision Reference | Design Revision |
|---|---|---|---|---|---|---|
| UNIT-HIDDEN | WORK-HIDDEN | not-applicable | master-plan.md | 2 | not-applicable | DESIGN-ADMIN@2 |
"@
Assert-TestExactDiagnostics 'plan rejects duplicate adapter trace heading with only its exact cardinality diagnostic' `
  @(Test-ResponsibilityPlan -DesignText (New-ResponsibilityPlanDesignFixture) -PlanText $duplicateAdapterHeading -WorkItemId 'WORK-ADMIN-LOCK' -ContractText $contract) `
  @('ARC-CONTRACT-HEADING-CARDINALITY: Work Item Adapter Trace')

$crossWorkItemReuse = $validPlan + @"

| WORK-OTHER | DESIGN-ADMIN@2 | RESP-WIFI, RESP-WIRED | RESP-LOCK-GUARD | RESP-LOCK-COMPOSITION | architecture-rules.md#RULE-007: independently implementable, reviewable, verifiable, and revertible |
"@
Assert-PlanRejected 'plan rejects unapproved cross-work-item responsibility reuse' $crossWorkItemReuse 'responsibility-owner-extra'

$approvedReuseDesign = (New-ResponsibilityPlanDesignFixture).Replace('; WORK-ADMIN-LOCK |', '; WORK-ADMIN-LOCK; WORK-ADMIN-LOCK-CHILD |') + @"

## Approved Decomposition Decisions

| Decision Reference | Parent Work Item ID | Child Work Item ID | Master Plan Reference | Master Plan Revision | Design Revision | Approval Reference | Immutable Evidence Reference |
|---|---|---|---|---|---|---|---|
| DEC-ADMIN-LOCK-DECOMPOSITION | WORK-ADMIN-LOCK | WORK-ADMIN-LOCK-CHILD | master-plan.md | 2 | DESIGN-ADMIN@2 | approval:TECH-LEAD-ADMIN-DECOMPOSITION | master-plan.md@revision=2:DEC-ADMIN-LOCK-DECOMPOSITION |
"@
$approvedReusePlan = (New-ResponsibilityPlanFixture).Replace('status: draft', "status: approved`napproval_source: human`nrevision: 2").Replace(
  '| UNIT-ADMIN-LOCK | WORK-ADMIN-LOCK | not-applicable | master-plan.md | 2 | not-applicable | DESIGN-ADMIN@2 |',
  "| UNIT-ADMIN-LOCK | WORK-ADMIN-LOCK | not-applicable | master-plan.md | 2 | DEC-ADMIN-LOCK-DECOMPOSITION | DESIGN-ADMIN@2 |`n| UNIT-ADMIN-LOCK-CHILD | WORK-ADMIN-LOCK-CHILD | WORK-ADMIN-LOCK | master-plan.md | 2 | DEC-ADMIN-LOCK-DECOMPOSITION | DESIGN-ADMIN@2 |"
).Replace(
  '| WORK-ADMIN-LOCK | DESIGN-ADMIN@2 | RESP-WIFI, RESP-WIRED | RESP-LOCK-GUARD | RESP-LOCK-COMPOSITION | architecture-rules.md#RULE-007: independently implementable, reviewable, verifiable, and revertible |',
  "| WORK-ADMIN-LOCK | DESIGN-ADMIN@2 | RESP-WIFI, RESP-WIRED | RESP-LOCK-GUARD | RESP-LOCK-COMPOSITION | architecture-rules.md#RULE-007: independently implementable, reviewable, verifiable, and revertible |`n| WORK-ADMIN-LOCK-CHILD | DESIGN-ADMIN@2 | RESP-WIFI, RESP-WIRED | RESP-LOCK-GUARD | RESP-LOCK-COMPOSITION | approval:TECH-LEAD-ADMIN-DECOMPOSITION: independently implementable, reviewable, verifiable, and revertible |"
)
Assert-PlanAccepted 'approved parent-child decomposition may reuse an exactly traced responsibility' $approvedReusePlan $approvedReuseDesign
Assert-PlanRejected 'approved decomposition plan without immutable front-matter revision cannot authorize reuse' ($approvedReusePlan.Replace("revision: 2`n", '')) 'responsibility-owner-extra' $approvedReuseDesign
Assert-PlanRejected 'approved decomposition plan revision must match every adapter revision' ($approvedReusePlan.Replace('revision: 2', 'revision: 3')) 'responsibility-owner-extra' $approvedReuseDesign
Assert-PlanRejected 'decomposition design without approval source cannot authorize reuse' $approvedReusePlan 'responsibility-owner-extra' ($approvedReuseDesign.Replace("approval_source: human`n", ''))
Assert-PlanRejected 'non-human decomposition design approval cannot authorize reuse' $approvedReusePlan 'responsibility-owner-extra' ($approvedReuseDesign.Replace('approval_source: human', 'approval_source: auto'))
Assert-PlanRejected 'cross-run decomposition design cannot authorize reuse' $approvedReusePlan 'responsibility-owner-extra' ($approvedReuseDesign.Replace('run_id: RUN-ADMIN-001', 'run_id: RUN-FOREIGN-001'))
Assert-PlanRejected 'draft parent-child decomposition cannot authorize reuse' ($approvedReusePlan.Replace('status: approved', 'status: draft')) 'responsibility-owner-extra' $approvedReuseDesign
Assert-PlanRejected 'decomposition without approval source cannot authorize reuse' ($approvedReusePlan.Replace("approval_source: human`n", '')) 'responsibility-owner-extra' $approvedReuseDesign
Assert-PlanRejected 'non-human decomposition approval cannot authorize reuse' ($approvedReusePlan.Replace('approval_source: human', 'approval_source: auto')) 'responsibility-owner-extra' $approvedReuseDesign
Assert-PlanRejected 'mutable decomposition evidence cannot authorize reuse' $approvedReusePlan 'responsibility-owner-extra' ($approvedReuseDesign.Replace('master-plan.md@revision=2:DEC-ADMIN-LOCK-DECOMPOSITION', 'master-plan.md@latest:DEC-ADMIN-LOCK-DECOMPOSITION'))
Assert-PlanRejected 'foreign decomposition decision cannot authorize reuse' ($approvedReusePlan.Replace('DEC-ADMIN-LOCK-DECOMPOSITION', 'DEC-FOREIGN-DECOMPOSITION')) 'responsibility-owner-extra' $approvedReuseDesign
Assert-PlanRejected 'pending decomposition approval evidence cannot authorize reuse' $approvedReusePlan 'responsibility-owner-extra' ($approvedReuseDesign.Replace('approval:TECH-LEAD-ADMIN-DECOMPOSITION', 'approval:TECH-LEAD-PENDING'))
Assert-PlanRejected 'suffix placeholder decomposition approval evidence cannot authorize reuse' $approvedReusePlan 'responsibility-owner-extra' ($approvedReuseDesign.Replace('approval:TECH-LEAD-ADMIN-DECOMPOSITION', 'approval:TECH-LEAD-ADMIN-PENDING'))

$unusedDecisionDesign = (New-ResponsibilityPlanDesignFixture).
  Replace('REQ-102; WORK-ADMIN-LOCK', 'REQ-102; WORK-SIBLING-CHILD').
  Replace('REQ-103; WORK-ADMIN-LOCK', 'REQ-103; WORK-SIBLING-PARENT') + @"

## Approved Decomposition Decisions

| Decision Reference | Parent Work Item ID | Child Work Item ID | Master Plan Reference | Master Plan Revision | Design Revision | Approval Reference | Immutable Evidence Reference |
|---|---|---|---|---|---|---|---|
| DEC-SIBLING-DECOMPOSITION | WORK-SIBLING-PARENT | WORK-SIBLING-CHILD | master-plan.md | 2 | DESIGN-ADMIN@2 | approval:TECH-LEAD-SIBLING-DECOMPOSITION | master-plan.md@revision=2:DEC-SIBLING-DECOMPOSITION |
"@
$unusedDecisionPlan = $approvedPlan.Replace(
  '| UNIT-ADMIN-LOCK | WORK-ADMIN-LOCK | not-applicable | master-plan.md | 2 | not-applicable | DESIGN-ADMIN@2 |',
  "| UNIT-ADMIN-LOCK | WORK-ADMIN-LOCK | not-applicable | master-plan.md | 2 | not-applicable | DESIGN-ADMIN@2 |`n| UNIT-SIBLING-PARENT | WORK-SIBLING-PARENT | not-applicable | master-plan.md | 2 | DEC-SIBLING-DECOMPOSITION | DESIGN-ADMIN@2 |`n| UNIT-SIBLING-CHILD | WORK-SIBLING-CHILD | WORK-SIBLING-PARENT | master-plan.md | 2 | DEC-SIBLING-DECOMPOSITION | DESIGN-ADMIN@2 |"
).Replace(
  '| WORK-ADMIN-LOCK | DESIGN-ADMIN@2 | RESP-WIFI, RESP-WIRED | RESP-LOCK-GUARD | RESP-LOCK-COMPOSITION | architecture-rules.md#RULE-007: independently implementable, reviewable, verifiable, and revertible |',
  "| WORK-ADMIN-LOCK | DESIGN-ADMIN@2 | RESP-WIFI | not-applicable | RESP-LOCK-COMPOSITION | architecture-rules.md#RULE-007: independently implementable, reviewable, verifiable, and revertible |`n| WORK-SIBLING-PARENT | DESIGN-ADMIN@2 | not-applicable | RESP-LOCK-GUARD | not-applicable | architecture-rules.md#RULE-SIBLING-PARENT: independently implementable, reviewable, verifiable, and revertible |`n| WORK-SIBLING-CHILD | DESIGN-ADMIN@2 | RESP-WIRED | not-applicable | not-applicable | architecture-rules.md#RULE-SIBLING-CHILD: independently implementable, reviewable, verifiable, and revertible |"
)
Assert-PlanAccepted 'approved full plan validates a traced decomposition decision even when no responsibility is reused' $unusedDecisionPlan $unusedDecisionDesign
Assert-PlanRejected 'unused pending decomposition decision cannot remain in an approved plan' $unusedDecisionPlan 'responsibility-owner-extra' ($unusedDecisionDesign.Replace('approval:TECH-LEAD-SIBLING-DECOMPOSITION', 'approval:TECH-LEAD-SIBLING-PENDING'))
Assert-PlanRejected 'unused mutable decomposition evidence cannot remain in an approved plan' $unusedDecisionPlan 'responsibility-owner-extra' ($unusedDecisionDesign.Replace('master-plan.md@revision=2:DEC-SIBLING-DECOMPOSITION', 'master-plan.md@latest:DEC-SIBLING-DECOMPOSITION'))
$orphanDecisionDesign = $unusedDecisionDesign.Replace(
  '| DEC-SIBLING-DECOMPOSITION | WORK-SIBLING-PARENT |',
  "| DEC-ORPHAN-DECOMPOSITION | WORK-ORPHAN-PARENT | WORK-ORPHAN-CHILD | master-plan.md | 2 | DESIGN-ADMIN@2 | approval:TECH-LEAD-ORPHAN-DECOMPOSITION | master-plan.md@revision=2:DEC-ORPHAN-DECOMPOSITION |`n| DEC-SIBLING-DECOMPOSITION | WORK-SIBLING-PARENT |"
)
Assert-PlanRejected 'orphan decomposition decision cannot remain in an approved plan' $unusedDecisionPlan 'responsibility-owner-extra' $orphanDecisionDesign
$duplicateDecisionDesign = $unusedDecisionDesign.Replace(
  '| DEC-SIBLING-DECOMPOSITION | WORK-SIBLING-PARENT |',
  "| DEC-SIBLING-DECOMPOSITION | WORK-ORPHAN-PARENT | WORK-ORPHAN-CHILD | master-plan.md | 2 | DESIGN-ADMIN@2 | approval:TECH-LEAD-ORPHAN-DECOMPOSITION | master-plan.md@revision=2:DEC-SIBLING-DECOMPOSITION |`n| DEC-SIBLING-DECOMPOSITION | WORK-SIBLING-PARENT |"
)
Assert-PlanRejected 'duplicate decomposition decision IDs cannot remain in an approved plan' $unusedDecisionPlan 'responsibility-owner-extra' $duplicateDecisionDesign
Assert-PlanRejected 'foreign adapter decision cannot remain in an approved plan' ($unusedDecisionPlan.Replace('DEC-SIBLING-DECOMPOSITION', 'DEC-FOREIGN-DECOMPOSITION')) 'responsibility-owner-extra' $unusedDecisionDesign

$foreignNotApplicableParent = $unusedDecisionPlan.Replace(
  '| UNIT-ADMIN-LOCK | WORK-ADMIN-LOCK | not-applicable | master-plan.md | 2 | not-applicable | DESIGN-ADMIN@2 |',
  '| UNIT-ADMIN-LOCK | WORK-ADMIN-LOCK | WORK-SIBLING-PARENT | master-plan.md | 2 | not-applicable | DESIGN-ADMIN@2 |'
)
$notApplicableAdapterAuthorityFailures = [Collections.Generic.List[string]]::new()
$canonicalNotApplicableDiagnostics = @(Test-ResponsibilityPlan -DesignText (New-ResponsibilityPlanDesignFixture) -PlanText $approvedPlan -WorkItemId 'WORK-ADMIN-LOCK' -ContractText $contract)
if ($canonicalNotApplicableDiagnostics.Count -ne 0) {
  $notApplicableAdapterAuthorityFailures.Add("canonical not-applicable adapter should pass but got: $($canonicalNotApplicableDiagnostics -join '; ')")
}
else {
  Write-Output 'PASS: canonical not-applicable adapter keeps exact current master and parent authority'
}
$notApplicableAdapterAuthorityCases = @(
  [pscustomobject]@{ Name = 'not-applicable adapter rejects mutable master-plan.md@latest reference'; Plan = $mutableNotApplicableMasterReference; Design = (New-ResponsibilityPlanDesignFixture) },
  [pscustomobject]@{ Name = 'not-applicable adapter rejects an existing foreign parent'; Plan = $foreignNotApplicableParent; Design = $unusedDecisionDesign },
  [pscustomobject]@{ Name = 'not-applicable adapter rejects an orphan parent'; Plan = $orphanNotApplicableParent; Design = (New-ResponsibilityPlanDesignFixture) },
  [pscustomobject]@{ Name = 'not-applicable adapter rejects an invalid parent sentinel'; Plan = $invalidNotApplicableParent; Design = (New-ResponsibilityPlanDesignFixture) }
)
foreach ($authorityCase in $notApplicableAdapterAuthorityCases) {
  $diagnostics = @(Test-ResponsibilityPlan -DesignText $authorityCase.Design -PlanText $authorityCase.Plan -WorkItemId 'WORK-ADMIN-LOCK' -ContractText $contract)
  if ($diagnostics -notcontains 'responsibility-owner-extra') {
    $notApplicableAdapterAuthorityFailures.Add("$($authorityCase.Name) expected responsibility-owner-extra but got: $($diagnostics -join '; ')")
  }
  else {
    Write-Output "PASS: $($authorityCase.Name)"
  }
}
if ($notApplicableAdapterAuthorityFailures.Count -gt 0) {
  throw ($notApplicableAdapterAuthorityFailures -join "`n")
}

function New-ResponsibilityImplementationFixture {
  param(
    [string]$OwnerSymbol = 'AdminWifi',
    [string]$CapabilityId = 'CAP-ADMIN-WIFI',
    [string]$Effect = 'none',
    [string]$ArchitectureState = 'PASS',
    [string]$TaskBaseSha = '0000000000000000000000000000000000000000',
    [string]$FinalTreeSha = '0000000000000000000000000000000000000000'
  )

  return @"
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
| RUN-ADMIN-001 | master-spec.md | SPEC-ADMIN-001 | 1 | master-plan.md | PLAN-ADMIN-001 | 2 | WORK-ADMIN-LOCK |

## Canonical Adapter Evidence

| Work Item ID | Adapter Kind | External ID | Authority | Authority Revision | Approval Reference | Parent Selector | Acceptance | Trace IDs | Mode Constraint | Design Revision | Parent Work Item ID | Decomposition Decision Reference | Canonical Match |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| WORK-ADMIN-LOCK | none | not-applicable | not-applicable | not-applicable | not-applicable | not-applicable | REQ-101; SC-101; completes within 2 seconds | REQ-101 | incremental/preserve-existing | DESIGN-ADMIN@2 | not-applicable | not-applicable | PASS |

## Actual File Responsibility Matrix

| Responsibility ID | Owner Path | Owner Symbol | Boundary Kind | Primary Responsibility | Owned Capability IDs | Trace IDs | Atomic Boundary ID | Public Symbols | External Effects | Target Exemplar | Exemplar Classification | Classification Authority | Classification Evidence | Architecture Authority | Co-location Policy | Co-location Evidence | Verification Owner References | Conformance | Deviation Reference | Actual Evidence |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| RESP-WIFI | ui/admin_wifi.dart | $OwnerSymbol | presentation | administer wireless lock | $CapabilityId | REQ-101; WORK-ADMIN-LOCK | not-applicable | $OwnerSymbol | $Effect | lib/target_shell.dart#TargetShell | preferred | factual-discovery-evidence | inspection:lib/target_shell.dart:10-80 | target-exemplar | feature-local | same capability lifecycle verification and revert boundary | VERIFY-OWNER-WIFI | yes | not-applicable | diff:ui/admin_wifi.dart#$OwnerSymbol |
| RESP-WIRED | ui/admin_wired.dart | AdminWired | presentation | administer wired lock | CAP-ADMIN-WIRED | REQ-102; WORK-ADMIN-LOCK | not-applicable | AdminWired | none | lib/target_shell.dart#TargetShell | preferred | factual-discovery-evidence | inspection:lib/target_shell.dart:10-80 | target-exemplar | feature-local | same capability lifecycle verification and revert boundary | VERIFY-OWNER-WIRED | yes | not-applicable | diff:ui/admin_wired.dart#AdminWired |
| RESP-LOCK-GUARD | lib/lock_guard.dart | LockGuard | adapter | provide shared lock guard | CAP-LOCK-GUARD | REQ-103; WORK-ADMIN-LOCK | not-applicable | LockGuard | none | lib/target_shell.dart#TargetShell | preferred | factual-discovery-evidence | inspection:lib/target_shell.dart:10-80 | target-exemplar | shared-foundation | shared capability with no concrete registration or feature effect | VERIFY-OWNER-LOCK-GUARD | yes | not-applicable | diff:lib/lock_guard.dart#LockGuard |
| RESP-LOCK-COMPOSITION | lib/admin_lock_composition.dart | AdminLockComposition | integration | compose admin lock owners | CAP-LOCK-COMPOSITION | REQ-104; WORK-ADMIN-LOCK | not-applicable | AdminLockComposition | route registration | lib/target_shell.dart#TargetShell | preferred | factual-discovery-evidence | inspection:lib/target_shell.dart:10-80 | target-exemplar | feature-local | production composition lifecycle and revert boundary | VERIFY-OWNER-LOCK-COMPOSITION | yes | not-applicable | diff:lib/admin_lock_composition.dart#AdminLockComposition |

## Responsibility Owner References

| Work Item ID | Design Revision | Responsibility IDs | Shared Foundation IDs | Integration Responsibility IDs | Independent Boundary Evidence |
|---|---|---|---|---|---|
| WORK-ADMIN-LOCK | DESIGN-ADMIN@2 | RESP-WIFI, RESP-WIRED | RESP-LOCK-GUARD | RESP-LOCK-COMPOSITION | architecture-rules.md#RULE-007: independently implementable, reviewable, verifiable, and revertible |

## Actual Verification Ownership Matrix

| Verification Owner ID | Production Responsibility ID | Capability ID | Evidence Path | Evidence Symbol or Scenario | Evidence Kind | Verification Disposition | Production Binding Evidence | Decision Reference | Verdict | Deviation Reference | Actual Evidence |
|---|---|---|---|---|---|---|---|---|---|---|---|
| VERIFY-OWNER-WIFI | RESP-WIFI | CAP-ADMIN-WIFI | test/admin_lock_test.ps1 | AdminWifiContract | contract | required | invokes ui/admin_wifi.dart#AdminWifi | not-applicable | PASS | not-applicable | diff:test/admin_lock_test.ps1#AdminWifiContract |
| VERIFY-OWNER-WIRED | RESP-WIRED | CAP-ADMIN-WIRED | test/admin_lock_test.ps1 | AdminWiredContract | contract | required | invokes ui/admin_wired.dart#AdminWired | not-applicable | PASS | not-applicable | diff:test/admin_lock_test.ps1#AdminWiredContract |
| VERIFY-OWNER-LOCK-GUARD | RESP-LOCK-GUARD | CAP-LOCK-GUARD | test/lock_guard_test.ps1 | LockGuardContract | contract | required | invokes lib/lock_guard.dart#LockGuard | not-applicable | PASS | not-applicable | diff:test/lock_guard_test.ps1#LockGuardContract |
| VERIFY-OWNER-LOCK-COMPOSITION | RESP-LOCK-COMPOSITION | CAP-LOCK-COMPOSITION | test/admin_lock_composition_test.ps1 | AdminLockCompositionContract | production-composition | required | invokes lib/admin_lock_composition.dart#AdminLockComposition | not-applicable | PASS | not-applicable | diff:test/admin_lock_composition_test.ps1#AdminLockCompositionContract |

## Architecture Responsibility Verdicts

| Responsibility Contract Version | Tree Conformance | Responsibility Conformance | Verification Ownership | Architecture Conformance State | Evidence References |
|---|---|---|---|---|---|
| 1 | PASS | PASS | PASS | $ArchitectureState | design:DESIGN-ADMIN@2; diff:HEAD |

## Change Hygiene

| Task / Unit | File | File Kind | Edited Region / Symbol | Formatter Command | Unrelated Diff | Checkpoint History | Task-base SHA | Final-tree SHA |
|---|---|---|---|---|---|---|---|---|
| WORK-ADMIN-LOCK | ui/admin_wifi.dart | new | AdminWifi | none | none | none | $TaskBaseSha | $FinalTreeSha |
| WORK-ADMIN-LOCK | ui/admin_wired.dart | new | AdminWired | none | none | none | $TaskBaseSha | $FinalTreeSha |
| WORK-ADMIN-LOCK | lib/lock_guard.dart | new | LockGuard | none | none | none | $TaskBaseSha | $FinalTreeSha |
| WORK-ADMIN-LOCK | lib/admin_lock_composition.dart | new | AdminLockComposition | none | none | none | $TaskBaseSha | $FinalTreeSha |
"@
}

function Assert-ImplementationRejected([string]$Name, [string]$ImplementationText, [string]$ExpectedDiagnostic) {
  $diagnostics = @(Test-ResponsibilityImplementation -DesignText (New-ResponsibilityPlanDesignFixture) -ImplementationText $ImplementationText -ContractText $contract)
  if ($diagnostics -notcontains $ExpectedDiagnostic) {
    throw "$Name expected $ExpectedDiagnostic but got: $($diagnostics -join '; ')"
  }
  Write-Output "PASS: $Name"
}

function Assert-ImplementationAccepted([string]$Name, [string]$ImplementationText) {
  $diagnostics = @(Test-ResponsibilityImplementation -DesignText (New-ResponsibilityPlanDesignFixture) -ImplementationText $ImplementationText -ContractText $contract)
  if ($diagnostics.Count -ne 0) {
    throw "$Name should pass but got: $($diagnostics -join '; ')"
  }
  Write-Output "PASS: $Name"
}

function Invoke-ReviewSourceGit([string]$Root, [string[]]$Arguments) {
  $output = @(& git -C $Root @Arguments 2>$null)
  if ($LASTEXITCODE -ne 0) { throw "Review source git command failed: git -C $Root $($Arguments -join ' ')" }
  return ($output -join [Environment]::NewLine).Trim()
}

function New-ResponsibilityReviewSourceFixture {
  param(
    [ValidateSet('canonical','missing-path','missing-scenario','foreign-owner','stale-scenario','self-attested','fake-registry','fake-provider')]
    [string]$VerificationVariant = 'canonical'
  )
  $sourceRoot = Join-Path ([IO.Path]::GetTempPath()) ('aitoolkit-responsibility-review-' + [guid]::NewGuid().ToString('N'))
  foreach ($path in @('ui', 'lib', 'test')) { [void](New-Item -ItemType Directory -Force -Path (Join-Path $sourceRoot $path)) }
  Invoke-ReviewSourceGit $sourceRoot @('init') | Out-Null
  Invoke-ReviewSourceGit $sourceRoot @('config', 'core.autocrlf', 'false') | Out-Null
  Invoke-ReviewSourceGit $sourceRoot @('config', 'user.email', 'fixtures@example.test') | Out-Null
  Invoke-ReviewSourceGit $sourceRoot @('config', 'user.name', 'AIToolkit fixture') | Out-Null
  Set-Content -Encoding utf8 -LiteralPath (Join-Path $sourceRoot 'README') -Value 'responsibility review fixture'
  $verificationSources = [ordered]@{
    'test/admin_lock_test.ps1' = "@verification-scenario AdminWifiContract`n@verification-owner VERIFY-OWNER-WIFI`n@production-responsibility RESP-WIFI`n@owned-capability CAP-ADMIN-WIFI`n@evidence-kind contract`n@verification-disposition required`n@production-binding ui/admin_wifi.dart#AdminWifi`nscenario AdminWifiContract`n`n@verification-scenario AdminWiredContract`n@verification-owner VERIFY-OWNER-WIRED`n@production-responsibility RESP-WIRED`n@owned-capability CAP-ADMIN-WIRED`n@evidence-kind contract`n@verification-disposition required`n@production-binding ui/admin_wired.dart#AdminWired`nscenario AdminWiredContract"
    'test/lock_guard_test.ps1' = "@verification-scenario LockGuardContract`n@verification-owner VERIFY-OWNER-LOCK-GUARD`n@production-responsibility RESP-LOCK-GUARD`n@owned-capability CAP-LOCK-GUARD`n@evidence-kind contract`n@verification-disposition required`n@production-binding lib/lock_guard.dart#LockGuard`nscenario LockGuardContract"
    'test/admin_lock_composition_test.ps1' = "@verification-scenario AdminLockCompositionContract`n@verification-owner VERIFY-OWNER-LOCK-COMPOSITION`n@production-responsibility RESP-LOCK-COMPOSITION`n@owned-capability CAP-LOCK-COMPOSITION`n@evidence-kind production-composition`n@verification-disposition required`n@production-binding lib/admin_lock_composition.dart#AdminLockComposition`n@production-route AdminLockComposition -> AdminLockProvider`nscenario AdminLockCompositionContract"
  }
  if ($VerificationVariant -ceq 'missing-path') { $verificationSources.Remove('test/lock_guard_test.ps1') }
  if ($VerificationVariant -ceq 'missing-scenario') { $verificationSources['test/admin_lock_test.ps1'] = $verificationSources['test/admin_lock_test.ps1'].Replace('scenario AdminWifiContract', 'scenario MissingAdminWifiContract') }
  if ($VerificationVariant -ceq 'foreign-owner') { $verificationSources['test/lock_guard_test.ps1'] = $verificationSources['test/lock_guard_test.ps1'].Replace('@verification-owner VERIFY-OWNER-LOCK-GUARD', '@verification-owner VERIFY-OWNER-FOREIGN') }
  if ($VerificationVariant -ceq 'self-attested') { $verificationSources['test/lock_guard_test.ps1'] = $verificationSources['test/lock_guard_test.ps1'].Replace('@production-binding lib/lock_guard.dart#LockGuard', '@production-binding test/lock_guard_test.ps1#LockGuardContract') }
  if ($VerificationVariant -ceq 'fake-registry') { $verificationSources['test/admin_lock_composition_test.ps1'] = $verificationSources['test/admin_lock_composition_test.ps1'].Replace('@production-binding lib/admin_lock_composition.dart#AdminLockComposition', '@production-binding test/fake_registry.ps1#AdminLockComposition') }
  if ($VerificationVariant -ceq 'fake-provider') { $verificationSources['test/admin_lock_composition_test.ps1'] = $verificationSources['test/admin_lock_composition_test.ps1'].Replace('@production-route AdminLockComposition -> AdminLockProvider', '@production-route AdminLockComposition -> FakeAdminLockProvider') }
  foreach ($entry in $verificationSources.GetEnumerator()) { Set-Content -Encoding utf8 -LiteralPath (Join-Path $sourceRoot $entry.Key) -Value $entry.Value }
  Invoke-ReviewSourceGit $sourceRoot @('add', '--', 'README', 'test') | Out-Null
  Invoke-ReviewSourceGit $sourceRoot @('commit', '-m', 'base source') | Out-Null
  $taskBaseSha = Invoke-ReviewSourceGit $sourceRoot @('rev-parse', 'HEAD')
  if ($VerificationVariant -ceq 'stale-scenario') {
    $stalePath = Join-Path $sourceRoot 'test/admin_lock_test.ps1'
    $stale = (Get-Content -Raw -Encoding utf8 -LiteralPath $stalePath).Replace('scenario AdminWifiContract', 'scenario RetiredAdminWifiContract')
    Set-Content -Encoding utf8 -LiteralPath $stalePath -Value $stale
  }
  $sources = [ordered]@{
    'ui/admin_wifi.dart' = "@responsibility RESP-WIFI`n@owner-symbol AdminWifi`n@public-symbol AdminWifi`n@owned-capability CAP-ADMIN-WIFI`n@effect none`n@architecture-authority target-exemplar`n@co-location-policy feature-local`n@verification-owner VERIFY-OWNER-WIFI`n@ownership-begin RESP-WIFI`ncomponent AdminWifi`n@ownership-end RESP-WIFI"
    'ui/admin_wired.dart' = "@responsibility RESP-WIRED`n@owner-symbol AdminWired`n@public-symbol AdminWired`n@owned-capability CAP-ADMIN-WIRED`n@effect none`n@architecture-authority target-exemplar`n@co-location-policy feature-local`n@verification-owner VERIFY-OWNER-WIRED`n@ownership-begin RESP-WIRED`ncomponent AdminWired`n@ownership-end RESP-WIRED"
    'lib/lock_guard.dart' = "@responsibility RESP-LOCK-GUARD`n@owner-symbol LockGuard`n@public-symbol LockGuard`n@owned-capability CAP-LOCK-GUARD`n@effect none`n@architecture-authority target-exemplar`n@co-location-policy shared-foundation`n@verification-owner VERIFY-OWNER-LOCK-GUARD`n@ownership-begin RESP-LOCK-GUARD`ncomponent LockGuard`n@ownership-end RESP-LOCK-GUARD"
    'lib/admin_lock_composition.dart' = "@responsibility RESP-LOCK-COMPOSITION`n@owner-symbol AdminLockComposition`n@public-symbol AdminLockComposition`n@owned-capability CAP-LOCK-COMPOSITION`n@effect route registration`n@architecture-authority target-exemplar`n@co-location-policy feature-local`n@verification-owner VERIFY-OWNER-LOCK-COMPOSITION`n@ownership-begin RESP-LOCK-COMPOSITION`nroute AdminLockComposition -> AdminLockProvider`n@ownership-end RESP-LOCK-COMPOSITION"
  }
  foreach ($entry in $sources.GetEnumerator()) { Set-Content -Encoding utf8 -LiteralPath (Join-Path $sourceRoot $entry.Key) -Value $entry.Value }
  Invoke-ReviewSourceGit $sourceRoot @('add', '--', '.') | Out-Null
  Invoke-ReviewSourceGit $sourceRoot @('commit', '-m', 'planned responsibility owners') | Out-Null
  return [pscustomobject]@{ Root = $sourceRoot; TaskBaseSha = $taskBaseSha; FinalTreeSha = (Invoke-ReviewSourceGit $sourceRoot @('rev-parse', 'HEAD')) }
}

function New-ResponsibilityReviewFixture {
  param(
    [Parameter(Mandatory)][object]$PinnedSource,
    [string]$ArchitectureState = 'PASS',
    [string]$TreeState = 'PASS',
    [string]$ResponsibilityState = 'PASS',
    [string]$VerificationState = 'PASS',
    [string]$OverallVerdict = 'Approve'
  )

  $wifiEvidence = "source:$($PinnedSource.FinalTreeSha):ui/admin_wifi.dart#AdminWifi; diff:$($PinnedSource.TaskBaseSha)..$($PinnedSource.FinalTreeSha):ui/admin_wifi.dart#AdminWifi; source:$($PinnedSource.FinalTreeSha):ui/admin_wifi.dart#VERIFY-OWNER-WIFI; diff:$($PinnedSource.TaskBaseSha)..$($PinnedSource.FinalTreeSha):ui/admin_wifi.dart#VERIFY-OWNER-WIFI"
  $wiredEvidence = "source:$($PinnedSource.FinalTreeSha):ui/admin_wired.dart#AdminWired; diff:$($PinnedSource.TaskBaseSha)..$($PinnedSource.FinalTreeSha):ui/admin_wired.dart#AdminWired; source:$($PinnedSource.FinalTreeSha):ui/admin_wired.dart#VERIFY-OWNER-WIRED; diff:$($PinnedSource.TaskBaseSha)..$($PinnedSource.FinalTreeSha):ui/admin_wired.dart#VERIFY-OWNER-WIRED"
  $guardEvidence = "source:$($PinnedSource.FinalTreeSha):lib/lock_guard.dart#LockGuard; diff:$($PinnedSource.TaskBaseSha)..$($PinnedSource.FinalTreeSha):lib/lock_guard.dart#LockGuard; source:$($PinnedSource.FinalTreeSha):lib/lock_guard.dart#VERIFY-OWNER-LOCK-GUARD; diff:$($PinnedSource.TaskBaseSha)..$($PinnedSource.FinalTreeSha):lib/lock_guard.dart#VERIFY-OWNER-LOCK-GUARD"
  $compositionEvidence = "source:$($PinnedSource.FinalTreeSha):lib/admin_lock_composition.dart#AdminLockComposition; diff:$($PinnedSource.TaskBaseSha)..$($PinnedSource.FinalTreeSha):lib/admin_lock_composition.dart#AdminLockComposition; source:$($PinnedSource.FinalTreeSha):lib/admin_lock_composition.dart#VERIFY-OWNER-LOCK-COMPOSITION; diff:$($PinnedSource.TaskBaseSha)..$($PinnedSource.FinalTreeSha):lib/admin_lock_composition.dart#VERIFY-OWNER-LOCK-COMPOSITION"

  return @"
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
| RUN-ADMIN-001 | master-spec.md | SPEC-ADMIN-001 | 1 | master-plan.md | PLAN-ADMIN-001 | 2 | WORK-ADMIN-LOCK |

- Delivery Adapter Kind: none
- Delivery Adapter Mode Constraint: incremental/preserve-existing

## Task Provenance

| Task / Unit | Task-base SHA | Final-tree SHA | Source Artifact |
|---|---|---|---|
| WORK-ADMIN-LOCK | $($PinnedSource.TaskBaseSha) | $($PinnedSource.FinalTreeSha) | implementation-report.md |

## Architecture Responsibility Handoff

| Responsibility Contract Version | Tree Conformance | Responsibility Conformance | Verification Ownership | Architecture Conformance State | Evidence References |
|---|---|---|---|---|---|
| 1 | $TreeState | $ResponsibilityState | $VerificationState | $ArchitectureState | source-diff:$($PinnedSource.TaskBaseSha)..$($PinnedSource.FinalTreeSha)#WORK-ADMIN-LOCK |

## Rule Resolution

- Rule Resolution Verdict: RESOLVED

## Canonical Selector

- Canonical Selector Verdict: PASS

## Architecture Conformance

- Architecture Conformance Verdict: $ArchitectureState

## Responsibility Review Evidence

- Tree Conformance Verdict: $TreeState
- Responsibility Conformance Verdict: $ResponsibilityState
- Verification Ownership Verdict: $VerificationState

| Responsibility ID | Source/Diff Evidence | Planned Public Symbols | Actual Public Symbols | Planned Effects | Actual Effects | Verdict |
|---|---|---|---|---|---|---|
| RESP-WIFI | $wifiEvidence | AdminWifi | AdminWifi | none | none | PASS |
| RESP-WIRED | $wiredEvidence | AdminWired | AdminWired | none | none | PASS |
| RESP-LOCK-GUARD | $guardEvidence | LockGuard | LockGuard | none | none | PASS |
| RESP-LOCK-COMPOSITION | $compositionEvidence | AdminLockComposition | AdminLockComposition | route registration | route registration | PASS |

## Production Activation Path

- Production Activation-path Verdict: NOT_APPLICABLE

## Behavior, Failure Modes, Security, Performance, and Tests

- Behavior Analysis State: COMPLETE

## Change Hygiene

- Change Hygiene Verdict: PASS

| Task / Unit | Scope Evidence | Formatter Evidence | Unrelated Diff | Severity | Task-base SHA | Final-tree SHA |
|---|---|---|---|---|---|---|
| WORK-ADMIN-LOCK | ui/admin_wifi.dart#AdminWifi | none | none | none | $($PinnedSource.TaskBaseSha) | $($PinnedSource.FinalTreeSha) |
| WORK-ADMIN-LOCK | ui/admin_wired.dart#AdminWired | none | none | none | $($PinnedSource.TaskBaseSha) | $($PinnedSource.FinalTreeSha) |
| WORK-ADMIN-LOCK | lib/lock_guard.dart#LockGuard | none | none | none | $($PinnedSource.TaskBaseSha) | $($PinnedSource.FinalTreeSha) |
| WORK-ADMIN-LOCK | lib/admin_lock_composition.dart#AdminLockComposition | none | none | none | $($PinnedSource.TaskBaseSha) | $($PinnedSource.FinalTreeSha) |

## Critical

| File:line | Issue | Proposed fix |
|---|---|---|
| none | none | none |

## Major

| File:line | Issue | Proposed fix |
|---|---|---|
| none | none | none |

## Conclusion

- Critical count: 0
- Major count: 0
- Verdict: $OverallVerdict
"@
}

function New-ResponsibilityReviewPlanFixture {
  return @"
---
artifact_type: migration-master-plan
master_plan_id: PLAN-ADMIN-001
master_spec_id: SPEC-ADMIN-001
master_spec_revision: 1
revision: 2
status: approved
produced_at: 2026-08-21
---

## Delivery Adapter Selection

| Work Item ID | Adapter Kind | External ID | Authority | Authority Revision | Approval Reference | Parent Selector | Acceptance | Trace IDs | Mode Constraint | Design Revision | Parent Work Item ID | Decomposition Decision Reference |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| WORK-ADMIN-LOCK | none | not-applicable | not-applicable | not-applicable | not-applicable | not-applicable | REQ-101; SC-101; completes within 2 seconds | REQ-101 | incremental/preserve-existing | DESIGN-ADMIN@2 | not-applicable | not-applicable |

## Work Items

| Work Item ID | Title | Required | Dependencies | Plan Order | Acceptance | Trace IDs | Delivery Adapter | Status | Latest Attempt | Terminal Evidence | Approval Reference |
|---|---|---|---|---|---|---|---|---|---|---|---|
| WORK-ADMIN-LOCK | Admin lock | yes | none | 1 | REQ-101; SC-101; completes within 2 seconds | REQ-101 | none | in-progress | ATTEMPT-ADMIN-01 | none | approval:WORK-ADMIN-LOCK |
"@
}

function Assert-ReviewRejected([string]$Name, [string]$ReviewText, [string]$ExpectedDiagnostic, [string]$DesignText = $validReviewDesign, [string]$ImplementationText = $validImplementation, [object]$PinnedSource = $validReviewSource, [string]$ApprovedPlanText = $script:validReviewPlan) {
  $diagnostics = @(Test-ResponsibilityReview -DesignText $DesignText -ImplementationText $ImplementationText -ReviewText $ReviewText -ContractText $contract -SourceRoot $PinnedSource.Root -TaskBaseSha $PinnedSource.TaskBaseSha -FinalTreeSha $PinnedSource.FinalTreeSha -ApprovedPlanText $ApprovedPlanText)
  if ($diagnostics -notcontains $ExpectedDiagnostic) {
    throw "$Name expected $ExpectedDiagnostic but got: $($diagnostics -join '; ')"
  }
  Write-Output "PASS: $Name"
}

function Assert-ReviewAccepted([string]$Name, [string]$ReviewText, [string]$DesignText = $validReviewDesign, [string]$ImplementationText = $validImplementation, [object]$PinnedSource = $validReviewSource, [string]$ApprovedPlanText = $script:validReviewPlan) {
  $diagnostics = @(Test-ResponsibilityReview -DesignText $DesignText -ImplementationText $ImplementationText -ReviewText $ReviewText -ContractText $contract -SourceRoot $PinnedSource.Root -TaskBaseSha $PinnedSource.TaskBaseSha -FinalTreeSha $PinnedSource.FinalTreeSha -ApprovedPlanText $ApprovedPlanText)
  if ($diagnostics.Count -ne 0) {
    throw "$Name should pass but got: $($diagnostics -join '; ')"
  }
  Write-Output "PASS: $Name"
}

function Assert-ReviewDiagnosticsExactly([string]$Name, [string]$ReviewText, [string[]]$ExpectedDiagnostics, [string]$DesignText = $validReviewDesign, [string]$ImplementationText = $validImplementation, [object]$PinnedSource = $validReviewSource, [string]$ApprovedPlanText = $script:validReviewPlan) {
  $diagnostics = @(Test-ResponsibilityReview -DesignText $DesignText -ImplementationText $ImplementationText -ReviewText $ReviewText -ContractText $contract -SourceRoot $PinnedSource.Root -TaskBaseSha $PinnedSource.TaskBaseSha -FinalTreeSha $PinnedSource.FinalTreeSha -ApprovedPlanText $ApprovedPlanText)
  Assert-TestExactDiagnostics -Name $Name -Actual $diagnostics -Expected $ExpectedDiagnostics
}

function Convert-ReviewFixtureLineEndings([string]$Text, [string]$NewLine) {
  return [regex]::Replace($Text, '\r?\n', $NewLine)
}

function Replace-ReviewFixtureText([string]$Text, [string]$OldValue, [string]$NewValue, [string]$Context) {
  $updated = $Text.Replace($OldValue, $NewValue)
  if ($updated -ceq $Text) { throw "$Context fixture replacement failed" }
  return $updated
}

$validImplementation = New-ResponsibilityImplementationFixture
Assert-ImplementationAccepted 'actual matrices exactly preserve planned owners and verification' $validImplementation
Assert-ImplementationRejected 'implementation rejects a noncanonical adapter mode constraint' ($validImplementation.Replace('| REQ-101 | incremental/preserve-existing | DESIGN-ADMIN@2 |', '| REQ-101 | banana | DESIGN-ADMIN@2 |')) 'responsibility-evidence-missing'
foreach ($lineEndingCase in @(
  [pscustomobject]@{ Name = 'LF'; NewLine = "`n" }
  [pscustomobject]@{ Name = 'CRLF'; NewLine = "`r`n" }
)) {
  $implementationWithLineEndings = Convert-TestLineEndings $validImplementation $lineEndingCase.NewLine
  $duplicateActualMatrix = Add-TestH2SectionDuplicate -Text $implementationWithLineEndings -Heading 'Actual File Responsibility Matrix' -Position after
  Assert-TestExactDiagnostics "implementation emits only the exact Actual File Responsibility Matrix duplicate diagnostic ($($lineEndingCase.Name))" `
    @(Test-ResponsibilityImplementation -DesignText (New-ResponsibilityPlanDesignFixture) -ImplementationText $duplicateActualMatrix -ContractText $contract) `
    @('ARC-CONTRACT-HEADING-CARDINALITY: Actual File Responsibility Matrix')
  $missingActualMatrix = Remove-TestH2Section -Text $implementationWithLineEndings -Heading 'Actual File Responsibility Matrix'
  Assert-TestExactDiagnostics "implementation emits only the exact Actual File Responsibility Matrix missing diagnostic ($($lineEndingCase.Name))" `
    @(Test-ResponsibilityImplementation -DesignText (New-ResponsibilityPlanDesignFixture) -ImplementationText $missingActualMatrix -ContractText $contract) `
    @('ARC-CONTRACT-MISSING-TABLE: Actual File Responsibility Matrix')
}
$multiWorkItemDesign = (New-ResponsibilityPlanDesignFixture).Replace(
  '| RESP-LOCK-COMPOSITION | lib/admin_lock_composition.dart | AdminLockComposition | integration | compose admin lock owners | CAP-LOCK-COMPOSITION | REQ-104; WORK-ADMIN-LOCK | not-applicable | AdminLockComposition | route registration | lib/target_shell.dart#TargetShell | preferred | factual-discovery-evidence | inspection:lib/target_shell.dart:10-80 | target-exemplar | feature-local | production composition lifecycle and revert boundary | VERIFY-OWNER-LOCK-COMPOSITION | yes | not-applicable |',
  "| RESP-LOCK-COMPOSITION | lib/admin_lock_composition.dart | AdminLockComposition | integration | compose admin lock owners | CAP-LOCK-COMPOSITION | REQ-104; WORK-ADMIN-LOCK | not-applicable | AdminLockComposition | route registration | lib/target_shell.dart#TargetShell | preferred | factual-discovery-evidence | inspection:lib/target_shell.dart:10-80 | target-exemplar | feature-local | production composition lifecycle and revert boundary | VERIFY-OWNER-LOCK-COMPOSITION | yes | not-applicable |`n| RESP-OTHER-WORK | lib/other_work.dart | OtherWork | application | implement unrelated work | CAP-OTHER-WORK | REQ-999; WORK-OTHER | not-applicable | OtherWork | none | lib/target_shell.dart#TargetShell | preferred | factual-discovery-evidence | inspection:lib/target_shell.dart:10-80 | target-exemplar | feature-local | same capability lifecycle verification and revert boundary | VERIFY-OWNER-OTHER-WORK | yes | not-applicable |"
).Replace(
  '| VERIFY-OWNER-LOCK-COMPOSITION | RESP-LOCK-COMPOSITION | CAP-LOCK-COMPOSITION | test/admin_lock_composition_test.ps1 | AdminLockCompositionContract | production-composition | required | invokes lib/admin_lock_composition.dart#AdminLockComposition | not-applicable | PASS | not-applicable |',
  "| VERIFY-OWNER-LOCK-COMPOSITION | RESP-LOCK-COMPOSITION | CAP-LOCK-COMPOSITION | test/admin_lock_composition_test.ps1 | AdminLockCompositionContract | production-composition | required | invokes lib/admin_lock_composition.dart#AdminLockComposition | not-applicable | PASS | not-applicable |`n| VERIFY-OWNER-OTHER-WORK | RESP-OTHER-WORK | CAP-OTHER-WORK | test/other_work_test.ps1 | OtherWorkContract | contract | required | invokes lib/other_work.dart#OtherWork | not-applicable | PASS | not-applicable |"
)
$multiWorkItemDiagnostics = @(Test-ResponsibilityImplementation -DesignText $multiWorkItemDesign -ImplementationText $validImplementation -ContractText $contract)
if ($multiWorkItemDiagnostics.Count -ne 0) { throw "selected owner set should exclude unrelated design work but got: $($multiWorkItemDiagnostics -join '; ')" }
Write-Output 'PASS: actual comparison is scoped to selected plan owners'
Assert-ImplementationRejected 'actual matrix rejects missing planned owner' ($validImplementation -replace '(?m)^\| RESP-WIRED \|.*\r?\n', '') 'responsibility-owner-missing'
Assert-ImplementationRejected 'actual matrix rejects extra owner' ($validImplementation -replace '(?m)^(\| RESP-WIRED \|.*)$', "`$1`n`$1") 'responsibility-owner-extra'
Assert-ImplementationRejected 'actual matrix rejects public symbol drift even when tree path matches' (New-ResponsibilityImplementationFixture -OwnerSymbol 'WifiResetProvider') 'responsibility-public-symbol-mismatch'
Assert-ImplementationRejected 'actual matrix rejects capability drift' (New-ResponsibilityImplementationFixture -CapabilityId 'CAP-WIFI-RESET') 'responsibility-capability-mismatch'
Assert-ImplementationRejected 'actual matrix rejects external-effect drift' (New-ResponsibilityImplementationFixture -Effect 'settings.write:wifi-reset') 'responsibility-external-effect-mismatch'
Assert-ImplementationRejected 'actual matrix rejects broader co-location than approved' ($validImplementation.Replace('| target-exemplar | feature-local | same capability lifecycle verification and revert boundary | VERIFY-OWNER-WIFI |', '| target-exemplar | shared-foundation | shared owner widened after approval | VERIFY-OWNER-WIFI |')) 'co-location-policy-invalid'
Assert-ImplementationRejected 'actual verification rejects fake production binding' ($validImplementation.Replace('invokes ui/admin_wifi.dart#AdminWifi | not-applicable | PASS | not-applicable | diff:test/admin_lock_test.ps1#AdminWifiContract', 'invokes test/fake_registry.ps1#AdminWifi | not-applicable | PASS | not-applicable | diff:test/admin_lock_test.ps1#AdminWifiContract')) 'verification-production-binding-missing'
$invalidNotApplicable = $validImplementation.Replace('| contract | required | invokes ui/admin_wifi.dart#AdminWifi | not-applicable | PASS | not-applicable |', '| contract | not-applicable-approved | invokes ui/admin_wifi.dart#AdminWifi | approval:OWNER-WIFI | PASS | not-applicable |')
Assert-ImplementationRejected 'behavior owner cannot use not-applicable-approved verification' $invalidNotApplicable 'verification-disposition-invalid'
$notApplicablePlanDesign = (New-ResponsibilityPlanDesignFixture).Replace(
  '| RESP-WIFI | ui/admin_wifi.dart | AdminWifi | presentation | administer wireless lock |',
  '| RESP-WIFI | config/admin_wifi.yaml | AdminWifi | config | administer build wiring |'
).Replace(
  '| VERIFY-OWNER-WIFI | RESP-WIFI | CAP-ADMIN-WIFI | test/admin_lock_test.ps1 | AdminWifiContract | contract | required | invokes ui/admin_wifi.dart#AdminWifi | not-applicable | PASS | not-applicable |',
  '| VERIFY-OWNER-WIFI | RESP-WIFI | CAP-ADMIN-WIFI | test/admin_lock_test.ps1 | AdminWifiContract | static-structure | not-applicable-approved | invokes config/admin_wifi.yaml#AdminWifi | approval:OWNER-WIFI | PASS | not-applicable |'
)
$notApplicableImplementation = (New-ResponsibilityImplementationFixture).Replace(
  '| RESP-WIFI | ui/admin_wifi.dart | AdminWifi | presentation | administer wireless lock |',
  '| RESP-WIFI | config/admin_wifi.yaml | AdminWifi | config | administer build wiring |'
).Replace(
  '| VERIFY-OWNER-WIFI | RESP-WIFI | CAP-ADMIN-WIFI | test/admin_lock_test.ps1 | AdminWifiContract | contract | required | invokes ui/admin_wifi.dart#AdminWifi | not-applicable | PASS | not-applicable |',
  '| VERIFY-OWNER-WIFI | RESP-WIFI | CAP-ADMIN-WIFI | test/admin_lock_test.ps1 | AdminWifiContract | static-structure | not-applicable-approved | invokes config/admin_wifi.yaml#AdminWifi | approval:OWNER-WIFI | PASS | not-applicable |'
)
$notApplicableImplementationDiagnostics = @(Test-ResponsibilityImplementation -DesignText $notApplicablePlanDesign -ImplementationText $notApplicableImplementation -ContractText $contract)
if ($notApplicableImplementationDiagnostics.Count -ne 0) { throw "implementation must reuse canonical structured not-applicable eligibility but got: $($notApplicableImplementationDiagnostics -join '; ')" }
Write-Output 'PASS: design and implementation reuse canonical structured not-applicable eligibility'
$foreignNotApplicableImplementationDiagnostics = @(Test-ResponsibilityImplementation -DesignText ($notApplicablePlanDesign.Replace('approval:OWNER-WIFI', 'approval:OWNER-FOREIGN')) -ImplementationText ($notApplicableImplementation.Replace('approval:OWNER-WIFI', 'approval:OWNER-FOREIGN')) -ContractText $contract)
if ($foreignNotApplicableImplementationDiagnostics -notcontains 'verification-disposition-invalid') { throw "implementation must reject foreign not-applicable approval but got: $($foreignNotApplicableImplementationDiagnostics -join '; ')" }
Write-Output 'PASS: implementation rejects foreign not-applicable approval with the shared predicate'
Assert-ImplementationRejected 'caller cannot claim aggregate PASS when a sub-verdict blocks' (New-ResponsibilityImplementationFixture -ArchitectureState 'BLOCKED').Replace('| 1 | PASS | PASS | PASS | BLOCKED |', '| 1 | PASS | PASS | BLOCKED | PASS |') 'responsibility-waiver-forbidden'

$blockedVerificationDesign = (New-ResponsibilityPlanDesignFixture).Replace(
  '| VERIFY-OWNER-WIFI | RESP-WIFI | CAP-ADMIN-WIFI | test/admin_lock_test.ps1 | AdminWifiContract | contract | required | invokes ui/admin_wifi.dart#AdminWifi | not-applicable | PASS | not-applicable |',
  '| VERIFY-OWNER-WIFI | RESP-WIFI | CAP-ADMIN-WIFI | test/admin_lock_test.ps1 | AdminWifiContract | contract | required | invokes ui/admin_wifi.dart#AdminWifi | not-applicable | BLOCKED | not-applicable |'
)
$blockedVerificationImplementation = (New-ResponsibilityImplementationFixture).Replace(
  '| VERIFY-OWNER-WIFI | RESP-WIFI | CAP-ADMIN-WIFI | test/admin_lock_test.ps1 | AdminWifiContract | contract | required | invokes ui/admin_wifi.dart#AdminWifi | not-applicable | PASS | not-applicable | diff:test/admin_lock_test.ps1#AdminWifiContract |',
  '| VERIFY-OWNER-WIFI | RESP-WIFI | CAP-ADMIN-WIFI | test/admin_lock_test.ps1 | AdminWifiContract | contract | required | invokes ui/admin_wifi.dart#AdminWifi | not-applicable | BLOCKED | not-applicable | diff:test/admin_lock_test.ps1#AdminWifiContract |'
)
$blockedVerificationDiagnostics = @(Test-ResponsibilityImplementation -DesignText $blockedVerificationDesign -ImplementationText $blockedVerificationImplementation -ContractText $contract)
if ($blockedVerificationDiagnostics -notcontains 'responsibility-waiver-forbidden') {
  throw "required verification row BLOCKED cannot support aggregate PASS but got: $($blockedVerificationDiagnostics -join '; ')"
}
Write-Output 'PASS: required verification row BLOCKED cannot support aggregate PASS'

$descriptiveVerificationDesign = (New-ResponsibilityPlanDesignFixture).Replace(
  'test/admin_lock_test.ps1 | AdminWifiContract',
  'test/admin_lock_test.ps1 | admin wifi contract scenario'
)
$descriptiveVerificationImplementation = (New-ResponsibilityImplementationFixture).Replace(
  'test/admin_lock_test.ps1 | AdminWifiContract',
  'test/admin_lock_test.ps1 | admin wifi contract scenario'
)
$descriptiveVerificationDiagnostics = @(Test-ResponsibilityImplementation -DesignText $descriptiveVerificationDesign -ImplementationText $descriptiveVerificationImplementation -ContractText $contract)
if ($descriptiveVerificationDiagnostics.Count -ne 0) {
  throw "non-placeholder descriptive verification scenario must remain valid but got: $($descriptiveVerificationDiagnostics -join '; ')"
}
Write-Output 'PASS: non-placeholder descriptive verification scenario supports aggregate PASS'

foreach ($invalidEvidence in @(
  [pscustomobject]@{ Name = 'placeholder evidence path'; Old = 'test/admin_lock_test.ps1 | AdminWifiContract'; New = 'pending | AdminWifiContract' },
  [pscustomobject]@{ Name = 'placeholder evidence scenario'; Old = 'test/admin_lock_test.ps1 | AdminWifiContract'; New = 'test/admin_lock_test.ps1 | pending' },
  [pscustomobject]@{ Name = 'traversing evidence path'; Old = 'test/admin_lock_test.ps1 | AdminWifiContract'; New = '../test/admin_lock_test.ps1 | AdminWifiContract' },
  [pscustomobject]@{ Name = 'noncanonical evidence path'; Old = 'test/admin_lock_test.ps1 | AdminWifiContract'; New = 'test\admin_lock_test.ps1 | AdminWifiContract' }
)) {
  $invalidDesign = (New-ResponsibilityPlanDesignFixture).Replace($invalidEvidence.Old, $invalidEvidence.New)
  $invalidImplementation = (New-ResponsibilityImplementationFixture).Replace($invalidEvidence.Old, $invalidEvidence.New)
  $invalidDiagnostics = @(Test-ResponsibilityImplementation -DesignText $invalidDesign -ImplementationText $invalidImplementation -ContractText $contract)
  if ($invalidDiagnostics -notcontains 'verification-production-binding-missing') {
    throw "$($invalidEvidence.Name) cannot support aggregate verification PASS but got: $($invalidDiagnostics -join '; ')"
  }
  Write-Output "PASS: $($invalidEvidence.Name) cannot support aggregate verification PASS"
}

$validReviewDesign = New-ResponsibilityPlanDesignFixture
$validReviewSource = New-ResponsibilityReviewSourceFixture
$script:validReviewPlan = New-ResponsibilityReviewPlanFixture
$validImplementation = New-ResponsibilityImplementationFixture -TaskBaseSha $validReviewSource.TaskBaseSha -FinalTreeSha $validReviewSource.FinalTreeSha
$canonicalEnvelopeReview = New-ResponsibilityReviewFixture -PinnedSource $validReviewSource
Assert-ReviewRejected 'review envelope rejects a substituted run' ($canonicalEnvelopeReview.Replace('RUN-ADMIN-001', 'RUN-FOREIGN-001')) 'responsibility-evidence-missing'
Assert-ReviewRejected 'review envelope rejects a substituted work item' ($canonicalEnvelopeReview.Replace('WORK-ADMIN-LOCK', 'WORK-FOREIGN')) 'responsibility-evidence-missing'
Assert-ReviewRejected 'review envelope rejects a substituted delivery adapter' ($canonicalEnvelopeReview.Replace('- Delivery Adapter Kind: none', '- Delivery Adapter Kind: task')) 'responsibility-evidence-missing'
Assert-ReviewRejected 'review envelope rejects a substituted delivery adapter mode' ($canonicalEnvelopeReview.Replace('- Delivery Adapter Mode Constraint: incremental/preserve-existing', '- Delivery Adapter Mode Constraint: greenfield/design-new')) 'responsibility-evidence-missing'
Assert-ReviewRejected 'review envelope rejects a missing delivery adapter mode' ($canonicalEnvelopeReview.Replace('- Delivery Adapter Mode Constraint: incremental/preserve-existing', '')) 'responsibility-evidence-missing'
Assert-ReviewRejected 'review envelope rejects a delivery adapter without marker whitespace' ($canonicalEnvelopeReview.Replace('- Delivery Adapter Kind: none', '-Delivery Adapter Kind: none')) 'responsibility-evidence-missing'
Assert-ReviewRejected 'review envelope rejects a wrong-case delivery adapter label' ($canonicalEnvelopeReview.Replace('- Delivery Adapter Kind: none', '- delivery adapter kind: none')) 'responsibility-evidence-missing'
Assert-ReviewRejected 'review envelope rejects hanging-paragraph delivery adapter text' ($canonicalEnvelopeReview.Replace('- Delivery Adapter Kind: none', '').TrimEnd() + "`n`nvisible prose`n    - Delivery Adapter Kind: none") 'responsibility-evidence-missing'
Assert-ReviewRejected 'review envelope rejects a substituted final-tree SHA' ($canonicalEnvelopeReview.Replace($validReviewSource.FinalTreeSha, '4444444444444444444444444444444444444444')) 'responsibility-evidence-missing'
Assert-ReviewRejected 'review envelope rejects a substituted source artifact' ($canonicalEnvelopeReview.Replace('implementation-report.md', 'other-implementation.md')) 'responsibility-evidence-missing'
Assert-ReviewRejected 'review envelope rejects stale source-diff evidence' ($canonicalEnvelopeReview.Replace("source-diff:$($validReviewSource.TaskBaseSha)..$($validReviewSource.FinalTreeSha)#WORK-ADMIN-LOCK", "source-diff:$($validReviewSource.TaskBaseSha)..3333333333333333333333333333333333333333#WORK-ADMIN-LOCK")) 'responsibility-evidence-missing'
Assert-ReviewRejected 'review envelope rejects a non-v1 responsibility handoff' ($canonicalEnvelopeReview.Replace('| 1 | PASS | PASS | PASS | PASS | source-diff:', '| 2 | PASS | PASS | PASS | PASS | source-diff:')) 'responsibility-contract-version-invalid'
Assert-ReviewRejected 'review envelope rejects a cross-plan implementation context' $canonicalEnvelopeReview 'responsibility-evidence-missing' -ImplementationText ($validImplementation.Replace('PLAN-ADMIN-001', 'PLAN-FOREIGN-001'))
Assert-ReviewRejected 'review envelope rejects an unapproved substituted plan authority' $canonicalEnvelopeReview 'responsibility-evidence-missing' -ApprovedPlanText ($script:validReviewPlan.Replace('status: approved', 'status: draft'))
Assert-ReviewAccepted 'review resolves unchanged verification evidence from the pinned final tree' $canonicalEnvelopeReview
$fencedArchitectureVerdict = @'
```text
- Architecture Conformance Verdict: PASS
```
'@
Assert-ReviewRejected 'fenced review verdict cannot replace the required visible architecture verdict' `
  ($canonicalEnvelopeReview.Replace('- Architecture Conformance Verdict: PASS', $fencedArchitectureVerdict)) `
  'responsibility-owner-missing'
$commentedAdapterControl = @'
<!--
- Delivery Adapter Kind: none
-->
'@
Assert-ReviewRejected 'commented delivery-adapter control cannot replace the required visible review control' `
  ($canonicalEnvelopeReview.Replace('- Delivery Adapter Kind: none', $commentedAdapterControl)) `
  'responsibility-evidence-missing'
$commentedModeControl = @'
<!--
- Delivery Adapter Mode Constraint: incremental/preserve-existing
-->
'@
Assert-ReviewRejected 'commented adapter-mode control cannot replace the required visible review control' `
  ($canonicalEnvelopeReview.Replace('- Delivery Adapter Mode Constraint: incremental/preserve-existing', $commentedModeControl)) `
  'responsibility-evidence-missing'
$inlineCommentSynthesizedAdapter = '<!-- parser decoy -->- Delivery Adapter Kind: none'
Assert-ReviewRejected 'inline comment removal cannot synthesize an adapter bullet' `
  ($canonicalEnvelopeReview.Replace('- Delivery Adapter Kind: none', $inlineCommentSynthesizedAdapter)) `
  'responsibility-evidence-missing'
$multilineCommentSynthesizedAdapter = "<!--`nparser decoy -->- Delivery Adapter Kind: none"
Assert-ReviewRejected 'multiline comment removal cannot synthesize an adapter bullet' `
  ($canonicalEnvelopeReview.Replace('- Delivery Adapter Kind: none', $multilineCommentSynthesizedAdapter)) `
  'responsibility-evidence-missing'
$inlineCommentSynthesizedMode = '<!-- parser decoy -->- Delivery Adapter Mode Constraint: incremental/preserve-existing'
Assert-ReviewRejected 'inline comment removal cannot synthesize an adapter-mode bullet' `
  ($canonicalEnvelopeReview.Replace('- Delivery Adapter Mode Constraint: incremental/preserve-existing', $inlineCommentSynthesizedMode)) `
  'responsibility-evidence-missing'
$multilineCommentSynthesizedMode = "<!--`nparser decoy -->- Delivery Adapter Mode Constraint: incremental/preserve-existing"
Assert-ReviewRejected 'multiline comment removal cannot synthesize an adapter-mode bullet' `
  ($canonicalEnvelopeReview.Replace('- Delivery Adapter Mode Constraint: incremental/preserve-existing', $multilineCommentSynthesizedMode)) `
  'responsibility-evidence-missing'
foreach ($frontMatterDecoy in @(
  [pscustomobject]@{ Label = 'Delivery Adapter Kind'; Value = 'none'; Indent = 2 },
  [pscustomobject]@{ Label = 'Delivery Adapter Kind'; Value = 'none'; Indent = 3 },
  [pscustomobject]@{ Label = 'Delivery Adapter Mode Constraint'; Value = 'incremental/preserve-existing'; Indent = 2 },
  [pscustomobject]@{ Label = 'Delivery Adapter Mode Constraint'; Value = 'incremental/preserve-existing'; Indent = 3 }
)) {
  $bodyLine = "- $($frontMatterDecoy.Label): $($frontMatterDecoy.Value)"
  $reviewWithoutBodyControl = $canonicalEnvelopeReview.Replace($bodyLine, '')
  if ($reviewWithoutBodyControl -ceq $canonicalEnvelopeReview) { throw "Front-matter decoy body removal was a silent no-op: $($frontMatterDecoy.Label)" }
  $indent = [string]::new([char]' ', $frontMatterDecoy.Indent)
  $reviewWithFrontMatterDecoy = $reviewWithoutBodyControl.Replace('responsibility_contract:', "$indent- $($frontMatterDecoy.Label): $($frontMatterDecoy.Value)`nresponsibility_contract:")
  if ($reviewWithFrontMatterDecoy -ceq $reviewWithoutBodyControl) { throw "Front-matter decoy insertion was a silent no-op: $($frontMatterDecoy.Label)" }
  Assert-ReviewRejected "review envelope rejects a $($frontMatterDecoy.Indent)-space front-matter $($frontMatterDecoy.Label) decoy" $reviewWithFrontMatterDecoy 'responsibility-evidence-missing'
}
foreach ($lineEndingCase in @(
  [pscustomobject]@{ Name = 'LF'; NewLine = "`n" }
  [pscustomobject]@{ Name = 'CRLF'; NewLine = "`r`n" }
)) {
  $reviewWithLineEndings = Convert-TestLineEndings $canonicalEnvelopeReview $lineEndingCase.NewLine
  Assert-ReviewAccepted "canonical single review envelope headings are accepted ($($lineEndingCase.Name))" $reviewWithLineEndings
  foreach ($heading in @('Master Scope Context', 'Task Provenance', 'Architecture Responsibility Handoff', 'Responsibility Review Evidence')) {
    foreach ($position in @('before', 'after')) {
      $duplicateReviewSection = Add-TestH2SectionDuplicate -Text $reviewWithLineEndings -Heading $heading -Position $position
      Assert-ReviewDiagnosticsExactly -Name "$heading emits only its exact duplicate diagnostic $position the canonical section ($($lineEndingCase.Name))" `
        -ReviewText $duplicateReviewSection -ExpectedDiagnostics @("ARC-CONTRACT-HEADING-CARDINALITY: $heading")
      $malformedSecondSection = Add-TestH2SectionDuplicate -Text $reviewWithLineEndings -Heading $heading -Position $position -CopyKind malformed
      Assert-ReviewDiagnosticsExactly -Name "$heading emits only its exact malformed-copy diagnostic $position the canonical section ($($lineEndingCase.Name))" `
        -ReviewText $malformedSecondSection -ExpectedDiagnostics @("ARC-CONTRACT-HEADING-CARDINALITY: $heading")
    }
    $missingReviewSection = Remove-TestH2Section -Text $reviewWithLineEndings -Heading $heading
    Assert-ReviewDiagnosticsExactly -Name "$heading emits only its exact missing diagnostic ($($lineEndingCase.Name))" `
      -ReviewText $missingReviewSection -ExpectedDiagnostics @("ARC-CONTRACT-MISSING-TABLE: $heading")
    Assert-ReviewAccepted "$heading ignores prose, H3, blockquote, and fenced-code mentions ($($lineEndingCase.Name))" `
      (Add-TestHeadingCodeExample -Text $reviewWithLineEndings -Heading $heading)
  }
  foreach ($position in @('before', 'after')) {
    $conflictingReviewEvidence = Add-TestH2SectionDuplicate -Text $reviewWithLineEndings -Heading 'Responsibility Review Evidence' -Position $position -CopyKind conflicting -ConflictFrom '| AdminWifi | AdminWifi | none | none | PASS |' -ConflictTo '| AdminWifi | AdminWifiConflict | none | none | BLOCKED |'
    Assert-ReviewDiagnosticsExactly -Name "Responsibility Review Evidence emits only its exact conflicting-copy diagnostic $position the canonical section ($($lineEndingCase.Name))" `
      -ReviewText $conflictingReviewEvidence -ExpectedDiagnostics @('ARC-CONTRACT-HEADING-CARDINALITY: Responsibility Review Evidence')
  }

  $twoDuplicateSections = Add-TestH2SectionDuplicate -Text $reviewWithLineEndings -Heading 'Task Provenance' -Position after
  $twoDuplicateSections = Add-TestH2SectionDuplicate -Text $twoDuplicateSections -Heading 'Master Scope Context' -Position before
  Assert-ReviewDiagnosticsExactly -Name "review preserves exact canonical diagnostic order without generic cascade ($($lineEndingCase.Name))" `
    -ReviewText $twoDuplicateSections -ExpectedDiagnostics @(
      'ARC-CONTRACT-HEADING-CARDINALITY: Master Scope Context'
      'ARC-CONTRACT-HEADING-CARDINALITY: Task Provenance'
    )

  $adapterLine = '- Delivery Adapter Kind: none'
  $visiblyDistinctDuplicateAdapterLine = ' - Delivery Adapter Kind: none'
  foreach ($position in @('before', 'after')) {
    $duplicateAdapterLines = if ($position -ceq 'before') {
      "$visiblyDistinctDuplicateAdapterLine$($lineEndingCase.NewLine)$adapterLine"
    } else {
      "$adapterLine$($lineEndingCase.NewLine)$visiblyDistinctDuplicateAdapterLine"
    }
    $duplicateAdapter = $reviewWithLineEndings.Replace($adapterLine, $duplicateAdapterLines)
    Assert-ReviewRejected "Delivery Adapter Kind rejects a duplicate $position the canonical line ($($lineEndingCase.Name))" $duplicateAdapter 'responsibility-evidence-missing'
    $malformedAdapterLines = if ($position -ceq 'before') {
      "- Delivery Adapter Kind: unsupported$($lineEndingCase.NewLine)$adapterLine"
    } else {
      "$adapterLine$($lineEndingCase.NewLine)- Delivery Adapter Kind: unsupported"
    }
    $malformedSecondAdapter = $reviewWithLineEndings.Replace($adapterLine, $malformedAdapterLines)
    Assert-ReviewRejected "Delivery Adapter Kind rejects a malformed line $position the canonical line ($($lineEndingCase.Name))" $malformedSecondAdapter 'responsibility-evidence-missing'
  }
  $implementationWithLineEndings = Convert-TestLineEndings $validImplementation $lineEndingCase.NewLine
  $duplicateChangeHygiene = Add-TestH2SectionDuplicate -Text $implementationWithLineEndings -Heading 'Change Hygiene' -Position after
  Assert-ReviewDiagnosticsExactly -Name "review emits only the exact implementation Change Hygiene duplicate diagnostic ($($lineEndingCase.Name))" `
    -ReviewText $reviewWithLineEndings -ExpectedDiagnostics @('ARC-CONTRACT-HEADING-CARDINALITY: Change Hygiene') `
    -ImplementationText $duplicateChangeHygiene
  $missingChangeHygiene = Remove-TestH2Section -Text $implementationWithLineEndings -Heading 'Change Hygiene'
  Assert-ReviewDiagnosticsExactly -Name "review emits only the exact implementation Change Hygiene missing diagnostic ($($lineEndingCase.Name))" `
    -ReviewText $reviewWithLineEndings -ExpectedDiagnostics @('ARC-CONTRACT-MISSING-TABLE: Change Hygiene') `
    -ImplementationText $missingChangeHygiene
}
foreach ($verificationCase in @(
  [pscustomobject]@{ Variant = 'missing-path'; Name = 'missing verification evidence path' }
  [pscustomobject]@{ Variant = 'missing-scenario'; Name = 'missing verification scenario' }
  [pscustomobject]@{ Variant = 'foreign-owner'; Name = 'foreign verification owner binding' }
  [pscustomobject]@{ Variant = 'stale-scenario'; Name = 'stale verification scenario in the final tree' }
  [pscustomobject]@{ Variant = 'self-attested'; Name = 'self-attested verification binding' }
  [pscustomobject]@{ Variant = 'fake-registry'; Name = 'test-only fake production registry' }
  [pscustomobject]@{ Variant = 'fake-provider'; Name = 'fake provider instead of real production composition' }
)) {
  $variantSource = New-ResponsibilityReviewSourceFixture -VerificationVariant $verificationCase.Variant
  $variantImplementation = New-ResponsibilityImplementationFixture -TaskBaseSha $variantSource.TaskBaseSha -FinalTreeSha $variantSource.FinalTreeSha
  if ($verificationCase.Variant -ceq 'stale-scenario') {
    $variantImplementation = $variantImplementation.TrimEnd() + "`n| WORK-ADMIN-LOCK | test/admin_lock_test.ps1 | existing | AdminWifiContract | none | none | none | $($variantSource.TaskBaseSha) | $($variantSource.FinalTreeSha) |`n"
  }
  $variantReview = New-ResponsibilityReviewFixture -PinnedSource $variantSource
  if ($verificationCase.Variant -ceq 'stale-scenario') {
    $reviewHygieneRow = "| WORK-ADMIN-LOCK | test/admin_lock_test.ps1#AdminWifiContract | none | none | none | $($variantSource.TaskBaseSha) | $($variantSource.FinalTreeSha) |"
    $variantReview = $variantReview.Replace("`n`n## Critical", "`n$reviewHygieneRow`n`n## Critical")
  }
  Assert-ReviewRejected "review rejects $($verificationCase.Name)" $variantReview 'verification-production-binding-missing' -ImplementationText $variantImplementation -PinnedSource $variantSource
  Remove-Item -LiteralPath $variantSource.Root -Recurse -Force
}

$migrationSelectorRow = '| WORK-ADMIN-LOCK | migration-unit | UNIT-ADMIN-LOCK | 08-migration-plan.md | 2 | approval:UNIT-ADMIN-LOCK | not-applicable | REQ-101; SC-101; completes within 2 seconds | REQ-101 | incremental/preserve-existing | DESIGN-ADMIN@2 | not-applicable | not-applicable |'
$migrationImplementationSelectorRow = "$migrationSelectorRow".TrimEnd('|').TrimEnd() + ' | PASS |'
$migrationSelectedUnitBlock = @"
## Selected Migration Unit

| Migration Unit ID | Plan Reference | Approval Reference | Mode Constraint | Bootstrap Scope | Foundation Baseline ID | Foundation Baseline Reference | Foundation Baseline Approval Reference | Baseline Reference | Trace IDs |
|---|---|---|---|---|---|---|---|---|---|
| UNIT-ADMIN-LOCK | 08-migration-plan.md@2 | approval:UNIT-ADMIN-LOCK | incremental/preserve-existing | not-required | not-applicable | not-applicable | not-applicable | baseline.md#BASE-ADMIN | REQ-101 |

"@
$noneImplementationSelectorRow = '| WORK-ADMIN-LOCK | none | not-applicable | not-applicable | not-applicable | not-applicable | not-applicable | REQ-101; SC-101; completes within 2 seconds | REQ-101 | incremental/preserve-existing | DESIGN-ADMIN@2 | not-applicable | not-applicable | PASS |'
$migrationImplementation = $validImplementation.Replace($noneImplementationSelectorRow, $migrationImplementationSelectorRow).Replace('## Actual File Responsibility Matrix', "$migrationSelectedUnitBlock## Actual File Responsibility Matrix")
$migrationImplementation = [regex]::Replace($migrationImplementation, '(?m)^\| WORK-ADMIN-LOCK \| (?=(?:ui|lib)/)', '| UNIT-ADMIN-LOCK | ')
$migrationPlan = $script:validReviewPlan.Replace('| WORK-ADMIN-LOCK | none | not-applicable | not-applicable | not-applicable | not-applicable | not-applicable | REQ-101; SC-101; completes within 2 seconds | REQ-101 | incremental/preserve-existing | DESIGN-ADMIN@2 | not-applicable | not-applicable |', $migrationSelectorRow).Replace('| REQ-101 | none | in-progress |', '| REQ-101 | migration-unit:UNIT-ADMIN-LOCK | in-progress |')
$migrationReview = $canonicalEnvelopeReview.Replace('- Delivery Adapter Kind: none', '- Delivery Adapter Kind: migration-unit').Replace('| WORK-ADMIN-LOCK | ' + $validReviewSource.TaskBaseSha + ' |', '| UNIT-ADMIN-LOCK | ' + $validReviewSource.TaskBaseSha + ' |').Replace('## Architecture Conformance', "$migrationSelectedUnitBlock## Architecture Conformance")
$migrationReview = [regex]::Replace($migrationReview, '(?m)^\| WORK-ADMIN-LOCK \| (?=(?:ui|lib)/)', '| UNIT-ADMIN-LOCK | ')
$migrationImplementationDiagnostics = @(Test-ResponsibilityImplementation -DesignText $validReviewDesign -ImplementationText $migrationImplementation -ContractText $contract)
if ($migrationImplementationDiagnostics.Count -ne 0) { throw "migration implementation envelope should pass but got: $($migrationImplementationDiagnostics -join '; ')" }
Write-Output 'PASS: migration implementation preserves canonical Authority@Revision selected row'
Assert-ReviewAccepted 'migration review preserves the exact implementation selected row and approved selector authority' $migrationReview $validReviewDesign $migrationImplementation $validReviewSource $migrationPlan
foreach ($lineEndingCase in @(
  [pscustomobject]@{ Name = 'LF'; NewLine = "`n" }
  [pscustomobject]@{ Name = 'CRLF'; NewLine = "`r`n" }
)) {
  $migrationReviewWithLineEndings = Convert-TestLineEndings $migrationReview $lineEndingCase.NewLine
  $migrationImplementationWithLineEndings = Convert-TestLineEndings $migrationImplementation $lineEndingCase.NewLine
  $migrationPlanWithLineEndings = Convert-TestLineEndings $migrationPlan $lineEndingCase.NewLine
  Assert-ReviewAccepted "canonical conditional Selected Migration Unit is accepted ($($lineEndingCase.Name))" $migrationReviewWithLineEndings $validReviewDesign $migrationImplementationWithLineEndings $validReviewSource $migrationPlanWithLineEndings
  $fencedImplementationSelected = Add-TestFencedH2SectionExample -Text $migrationImplementationWithLineEndings -Heading 'Selected Migration Unit' -FenceCharacter ([char]'`') -OpeningLength 4 -ClosingLength 4 -InfoString 'markdown'
  $fencedImplementationDiagnostics = @(Test-ResponsibilityImplementation -DesignText $validReviewDesign -ImplementationText $fencedImplementationSelected -ContractText $contract)
  if ($fencedImplementationDiagnostics.Count -ne 0) { throw "implementation must ignore a fenced Selected Migration Unit example ($($lineEndingCase.Name)) but got: $($fencedImplementationDiagnostics -join '; ')" }
  Write-Output "PASS: implementation ignores a fenced Selected Migration Unit example ($($lineEndingCase.Name))"
  $commentedImplementationSelected = Add-TestCommentedH2SectionDuplicate -Text $migrationImplementationWithLineEndings -Heading 'Selected Migration Unit' -Position before
  $commentedImplementationDiagnostics = @(Test-ResponsibilityImplementation -DesignText $validReviewDesign -ImplementationText $commentedImplementationSelected -ContractText $contract)
  if ($commentedImplementationDiagnostics.Count -ne 0) { throw "implementation must ignore a commented Selected Migration Unit example ($($lineEndingCase.Name)) but got: $($commentedImplementationDiagnostics -join '; ')" }
  Write-Output "PASS: implementation ignores a commented Selected Migration Unit example ($($lineEndingCase.Name))"
  $duplicateImplementationSelected = Add-TestH2SectionDuplicate -Text $migrationImplementationWithLineEndings -Heading 'Selected Migration Unit' -Position after
  Assert-TestExactDiagnostics "implementation emits only the exact Selected Migration Unit duplicate diagnostic ($($lineEndingCase.Name))" `
    @(Test-ResponsibilityImplementation -DesignText $validReviewDesign -ImplementationText $duplicateImplementationSelected -ContractText $contract) `
    @('ARC-CONTRACT-HEADING-CARDINALITY: Selected Migration Unit')
  $missingImplementationSelected = Remove-TestH2Section -Text $migrationImplementationWithLineEndings -Heading 'Selected Migration Unit'
  Assert-TestExactDiagnostics "implementation emits only the exact Selected Migration Unit missing diagnostic ($($lineEndingCase.Name))" `
    @(Test-ResponsibilityImplementation -DesignText $validReviewDesign -ImplementationText $missingImplementationSelected -ContractText $contract) `
    @('ARC-CONTRACT-MISSING-TABLE: Selected Migration Unit')
  Assert-ReviewAccepted "review ignores a fenced Selected Migration Unit example ($($lineEndingCase.Name))" `
    (Add-TestFencedH2SectionExample -Text $migrationReviewWithLineEndings -Heading 'Selected Migration Unit' -FenceCharacter ([char]'~') -OpeningLength 3 -ClosingLength 4 -InfoString 'markdown`example') `
    $validReviewDesign $migrationImplementationWithLineEndings $validReviewSource $migrationPlanWithLineEndings
  Assert-ReviewAccepted "review ignores a commented Selected Migration Unit example ($($lineEndingCase.Name))" `
    (Add-TestCommentedH2SectionDuplicate -Text $migrationReviewWithLineEndings -Heading 'Selected Migration Unit' -Position before) `
    $validReviewDesign $migrationImplementationWithLineEndings $validReviewSource $migrationPlanWithLineEndings

  $selectedBlockWithLineEndings = Convert-TestLineEndings $migrationSelectedUnitBlock $lineEndingCase.NewLine
  $noneImplementationWithLineEndings = Convert-TestLineEndings $validImplementation $lineEndingCase.NewLine
  $implementationInsertionHeading = '## Actual File Responsibility Matrix'
  $fourBackticks = [string]::new([char]'`', 4)
  $fencedSelectedExample = "${fourBackticks}markdown$($lineEndingCase.NewLine)$selectedBlockWithLineEndings$fourBackticks$($lineEndingCase.NewLine)"
  Assert-ImplementationAccepted "non-migration implementation ignores a fenced Selected Migration Unit example ($($lineEndingCase.Name))" `
    $noneImplementationWithLineEndings.Replace($implementationInsertionHeading, "$fencedSelectedExample$implementationInsertionHeading")
  $commentedSelectedExample = "<!--$($lineEndingCase.NewLine)$selectedBlockWithLineEndings-->$($lineEndingCase.NewLine)"
  Assert-ImplementationAccepted "non-migration implementation ignores a commented Selected Migration Unit example ($($lineEndingCase.Name))" `
    $noneImplementationWithLineEndings.Replace($implementationInsertionHeading, "$commentedSelectedExample$implementationInsertionHeading")
  Assert-ImplementationRejected "non-migration implementation rejects a real Selected Migration Unit ($($lineEndingCase.Name))" `
    $noneImplementationWithLineEndings.Replace($implementationInsertionHeading, "$selectedBlockWithLineEndings$implementationInsertionHeading") `
    'responsibility-evidence-missing'
  foreach ($position in @('before', 'after')) {
    $duplicateSelectedUnit = Add-TestH2SectionDuplicate -Text $migrationReviewWithLineEndings -Heading 'Selected Migration Unit' -Position $position
    Assert-ReviewDiagnosticsExactly -Name "review emits only the exact Selected Migration Unit duplicate diagnostic $position the canonical section ($($lineEndingCase.Name))" `
      -ReviewText $duplicateSelectedUnit -ExpectedDiagnostics @('ARC-CONTRACT-HEADING-CARDINALITY: Selected Migration Unit') `
      -ImplementationText $migrationImplementationWithLineEndings -ApprovedPlanText $migrationPlanWithLineEndings
  }
  $missingReviewSelectedUnit = Remove-TestH2Section -Text $migrationReviewWithLineEndings -Heading 'Selected Migration Unit'
  Assert-ReviewDiagnosticsExactly -Name "review emits only the exact Selected Migration Unit missing diagnostic ($($lineEndingCase.Name))" `
    -ReviewText $missingReviewSelectedUnit -ExpectedDiagnostics @('ARC-CONTRACT-MISSING-TABLE: Selected Migration Unit') `
    -ImplementationText $migrationImplementationWithLineEndings -ApprovedPlanText $migrationPlanWithLineEndings
  foreach ($position in @('before', 'after')) {
    $malformedSecondSelectedUnit = Add-TestH2SectionDuplicate -Text $migrationReviewWithLineEndings -Heading 'Selected Migration Unit' -Position $position -CopyKind malformed
    Assert-ReviewDiagnosticsExactly -Name "review emits only the exact Selected Migration Unit malformed-copy diagnostic $position the canonical section ($($lineEndingCase.Name))" `
      -ReviewText $malformedSecondSelectedUnit -ExpectedDiagnostics @('ARC-CONTRACT-HEADING-CARDINALITY: Selected Migration Unit') `
      -ImplementationText $migrationImplementationWithLineEndings -ApprovedPlanText $migrationPlanWithLineEndings
  }
}
$staleMigrationImplementationDiagnostics = @(Test-ResponsibilityImplementation -DesignText $validReviewDesign -ImplementationText ($migrationImplementation.Replace('08-migration-plan.md@2', '08-migration-plan.md@1')) -ContractText $contract)
if ($staleMigrationImplementationDiagnostics -notcontains 'responsibility-evidence-missing') { throw "stale implementation selected plan reference should be rejected but got: $($staleMigrationImplementationDiagnostics -join '; ')" }
Write-Output 'PASS: migration implementation rejects stale selected Plan Reference'
Assert-ReviewRejected 'migration review rejects a selected Plan Reference mismatch' ($migrationReview.Replace('08-migration-plan.md@2', '08-migration-plan.md@1')) 'responsibility-evidence-missing' -ImplementationText $migrationImplementation -ApprovedPlanText $migrationPlan

$approvedMigrationReview = $migrationReview.Replace('status: draft', 'status: approved').Replace('result: complete', "result: complete`napproval_source: human")
$migrationVerification = @"
---
step_id: 12-verification-testing
status: approved
result: complete
approval_source: human
produced_at: 2026-08-21
responsibility_contract:
  version: 1
  applicability: required
---

## Master Scope Context

| Run ID | Master Spec Reference | Master Spec ID | Master Spec Revision | Master Plan Reference | Master Plan ID | Master Plan Revision | Work Item ID |
|---|---|---|---|---|---|---|---|
| RUN-ADMIN-001 | master-spec.md | SPEC-ADMIN-001 | 1 | master-plan.md | PLAN-ADMIN-001 | 2 | WORK-ADMIN-LOCK |

- Delivery Adapter Kind: migration-unit
- Delivery Adapter Mode Constraint: incremental/preserve-existing

## Task Provenance

| Task / Unit | Task-base SHA | Final-tree SHA | Source Artifact |
|---|---|---|---|
| UNIT-ADMIN-LOCK | $($validReviewSource.TaskBaseSha) | $($validReviewSource.FinalTreeSha) | review-report.md |

## Architecture Responsibility Handoff

| Responsibility Contract Version | Tree Conformance | Responsibility Conformance | Verification Ownership | Architecture Conformance State | Evidence References |
|---|---|---|---|---|---|
| 1 | PASS | PASS | PASS | PASS | source-diff:$($validReviewSource.TaskBaseSha)..$($validReviewSource.FinalTreeSha)#WORK-ADMIN-LOCK |

$migrationSelectedUnitBlock
"@
$migrationHandoffDiagnostics = @(Test-ResponsibilityHandoff -SourceText $approvedMigrationReview -TargetText $migrationVerification -ContractText $contract -ApprovedPlanText $migrationPlan)
if ($migrationHandoffDiagnostics.Count -ne 0) { throw "composed migration review-to-verification handoff should pass but got: $($migrationHandoffDiagnostics -join '; ')" }
Write-Output 'PASS: composed implementation to review to verification reuses the exact selected migration row'
foreach ($lineEndingCase in @(
  [pscustomobject]@{ Name = 'LF'; NewLine = "`n" }
  [pscustomobject]@{ Name = 'CRLF'; NewLine = "`r`n" }
)) {
  $handoffSource = Convert-TestLineEndings $approvedMigrationReview $lineEndingCase.NewLine
  $handoffTarget = Convert-TestLineEndings $migrationVerification $lineEndingCase.NewLine
  $handoffPlan = Convert-TestLineEndings $migrationPlan $lineEndingCase.NewLine
  $fencedSource = Add-TestFencedH2SectionExample -Text $handoffSource -Heading 'Selected Migration Unit' -FenceCharacter ([char]'`') -OpeningLength 5 -ClosingLength 6 -InfoString 'markdown'
  $fencedTarget = Add-TestFencedH2SectionExample -Text $handoffTarget -Heading 'Selected Migration Unit' -FenceCharacter ([char]'~') -OpeningLength 4 -ClosingLength 4 -InfoString 'markdown`example'
  $fencedHandoffDiagnostics = @(Test-ResponsibilityHandoff -SourceText $fencedSource -TargetText $fencedTarget -ContractText $contract -ApprovedPlanText $handoffPlan)
  if ($fencedHandoffDiagnostics.Count -ne 0) { throw "handoff must ignore fenced Selected Migration Unit examples ($($lineEndingCase.Name)) but got: $($fencedHandoffDiagnostics -join '; ')" }
  Write-Output "PASS: handoff ignores fenced Selected Migration Unit examples ($($lineEndingCase.Name))"
  $commentedSource = Add-TestCommentedH2SectionDuplicate -Text $handoffSource -Heading 'Selected Migration Unit' -Position before
  $commentedTarget = Add-TestCommentedH2SectionDuplicate -Text $handoffTarget -Heading 'Selected Migration Unit' -Position after
  $commentedHandoffDiagnostics = @(Test-ResponsibilityHandoff -SourceText $commentedSource -TargetText $commentedTarget -ContractText $contract -ApprovedPlanText $handoffPlan)
  if ($commentedHandoffDiagnostics.Count -ne 0) { throw "handoff must ignore commented Selected Migration Unit examples ($($lineEndingCase.Name)) but got: $($commentedHandoffDiagnostics -join '; ')" }
  Write-Output "PASS: handoff ignores commented Selected Migration Unit examples ($($lineEndingCase.Name))"
  $duplicateHandoffSource = Add-TestH2SectionDuplicate -Text $handoffSource -Heading 'Selected Migration Unit' -Position after
  Assert-TestExactDiagnostics "handoff emits only the exact Selected Migration Unit duplicate diagnostic ($($lineEndingCase.Name))" `
    @(Test-ResponsibilityHandoff -SourceText $duplicateHandoffSource -TargetText $handoffTarget -ContractText $contract -ApprovedPlanText $handoffPlan) `
    @('ARC-CONTRACT-HEADING-CARDINALITY: Selected Migration Unit')
  $missingHandoffTarget = Remove-TestH2Section -Text $handoffTarget -Heading 'Selected Migration Unit'
  Assert-TestExactDiagnostics "handoff emits only the exact Selected Migration Unit missing diagnostic ($($lineEndingCase.Name))" `
    @(Test-ResponsibilityHandoff -SourceText $handoffSource -TargetText $missingHandoffTarget -ContractText $contract -ApprovedPlanText $handoffPlan) `
    @('ARC-CONTRACT-MISSING-TABLE: Selected Migration Unit')
}
$staleMigrationHandoffDiagnostics = @(Test-ResponsibilityHandoff -SourceText $approvedMigrationReview -TargetText ($migrationVerification.Replace('08-migration-plan.md@2', '08-migration-plan.md@1')) -ContractText $contract -ApprovedPlanText $migrationPlan)
if ($staleMigrationHandoffDiagnostics -notcontains 'responsibility-evidence-missing') { throw "stale verification selected plan reference should be rejected but got: $($staleMigrationHandoffDiagnostics -join '; ')" }
Write-Output 'PASS: composed verification handoff rejects a stale selected Plan Reference'
foreach ($lineEndingCase in @(
  [pscustomobject]@{ Name = 'LF'; NewLine = "`n" }
  [pscustomobject]@{ Name = 'CRLF'; NewLine = "`r`n" }
)) {
  $reviewFixture = Convert-ReviewFixtureLineEndings (New-ResponsibilityReviewFixture -PinnedSource $validReviewSource) $lineEndingCase.NewLine
  Assert-ReviewAccepted "independent review covers the final inventory with source and diff evidence ($($lineEndingCase.Name))" $reviewFixture
  $extraSourceSymbol = Replace-ReviewFixtureText -Text $reviewFixture -OldValue '| AdminLockComposition | AdminLockComposition | route registration | route registration | PASS |' -NewValue '| AdminLockComposition | AdminRoute.factoryReset | route registration | route registration | BLOCKED |' -Context "review detects extra source symbol ($($lineEndingCase.Name))"
  Assert-ReviewRejected "review rejects an owner present in final source evidence but absent from implementation attestation ($($lineEndingCase.Name))" $extraSourceSymbol 'responsibility-public-symbol-mismatch'
  foreach ($verdictLabel in @('Tree Conformance Verdict', 'Responsibility Conformance Verdict', 'Verification Ownership Verdict')) {
    $missingVerdict = Replace-ReviewFixtureText $reviewFixture "- $verdictLabel`: PASS" "- $verdictLabel omitted: PASS" "review removes $verdictLabel ($($lineEndingCase.Name))"
    Assert-ReviewRejected "review rejects missing $verdictLabel ($($lineEndingCase.Name))" $missingVerdict 'responsibility-owner-missing'
  }
  $wifiEvidence = "source:$($validReviewSource.FinalTreeSha):ui/admin_wifi.dart#AdminWifi; diff:$($validReviewSource.TaskBaseSha)..$($validReviewSource.FinalTreeSha):ui/admin_wifi.dart#AdminWifi; source:$($validReviewSource.FinalTreeSha):ui/admin_wifi.dart#VERIFY-OWNER-WIFI; diff:$($validReviewSource.TaskBaseSha)..$($validReviewSource.FinalTreeSha):ui/admin_wifi.dart#VERIFY-OWNER-WIFI"
  $missingEvidence = Replace-ReviewFixtureText $reviewFixture $wifiEvidence "source:$($validReviewSource.FinalTreeSha):ui/admin_wifi.dart#AdminWifi" "review removes source or diff evidence ($($lineEndingCase.Name))"
  Assert-ReviewRejected "review rejects missing immutable source or diff evidence reference ($($lineEndingCase.Name))" $missingEvidence 'responsibility-evidence-missing'
  $compositionSource = "source:$($validReviewSource.FinalTreeSha):lib/admin_lock_composition.dart#AdminLockComposition"
  $fakeComposition = Replace-ReviewFixtureText $reviewFixture $compositionSource "source:$($validReviewSource.FinalTreeSha):test/fake_registry.ps1#AdminLockComposition" "review injects fake production composition ($($lineEndingCase.Name))"
  Assert-ReviewRejected "review rejects test-only fake production composition evidence ($($lineEndingCase.Name))" $fakeComposition 'verification-production-binding-missing'
  $verificationBlocked = Convert-ReviewFixtureLineEndings (New-ResponsibilityReviewFixture -PinnedSource $validReviewSource -ArchitectureState 'PASS' -ResponsibilityState 'PASS' -VerificationState 'BLOCKED' -OverallVerdict 'Approve') $lineEndingCase.NewLine
  Assert-ReviewRejected "review rejects responsibility PASS when verification ownership is BLOCKED but overall approval remains claimed ($($lineEndingCase.Name))" $verificationBlocked 'responsibility-waiver-forbidden'
  $unapprovedDesign = Replace-ReviewFixtureText (Convert-ReviewFixtureLineEndings $validReviewDesign $lineEndingCase.NewLine) 'status: approved' 'status: draft' "review uses an unapproved design ($($lineEndingCase.Name))"
  Assert-ReviewRejected "review rejects an unapproved planned design ($($lineEndingCase.Name))" $reviewFixture 'responsibility-owner-extra' -DesignText $unapprovedDesign
  $staleRevision = Replace-ReviewFixtureText (Convert-ReviewFixtureLineEndings $validImplementation $lineEndingCase.NewLine) 'DESIGN-ADMIN@2' 'DESIGN-ADMIN@1' "review uses stale implementation design revision ($($lineEndingCase.Name))"
  Assert-ReviewRejected "review rejects a stale implementation design revision ($($lineEndingCase.Name))" $reviewFixture 'responsibility-evidence-missing' -ImplementationText $staleRevision
  $coordinatedDesign = Replace-ReviewFixtureText (Convert-ReviewFixtureLineEndings $validReviewDesign $lineEndingCase.NewLine) '| target-exemplar | feature-local | same capability lifecycle verification and revert boundary | VERIFY-OWNER-WIFI |' '| approved-greenfield-design | shared-foundation | coordinated self-attestation | VERIFY-OWNER-WIFI |' "review coordinates planned authority and co-location drift ($($lineEndingCase.Name))"
  $coordinatedImplementation = Replace-ReviewFixtureText (Convert-ReviewFixtureLineEndings $validImplementation $lineEndingCase.NewLine) '| target-exemplar | feature-local | same capability lifecycle verification and revert boundary | VERIFY-OWNER-WIFI |' '| approved-greenfield-design | shared-foundation | coordinated self-attestation | VERIFY-OWNER-WIFI |' "review coordinates actual authority and co-location drift ($($lineEndingCase.Name))"
  Assert-ReviewRejected "review rejects coordinated authority and co-location self-attestation ($($lineEndingCase.Name))" $reviewFixture 'co-location-policy-invalid' -DesignText $coordinatedDesign -ImplementationText $coordinatedImplementation
}

$multiWorkItemReview = New-ResponsibilityReviewFixture -PinnedSource $validReviewSource
Assert-ReviewAccepted 'review scopes planned owners and verification to the selected work item' $multiWorkItemReview $multiWorkItemDesign $validImplementation $validReviewSource
$foreignOwnerReference = $validImplementation.Replace('| WORK-ADMIN-LOCK | DESIGN-ADMIN@2 | RESP-WIFI, RESP-WIRED | RESP-LOCK-GUARD | RESP-LOCK-COMPOSITION |', '| WORK-OTHER | DESIGN-ADMIN@2 | RESP-WIFI, RESP-WIRED | RESP-LOCK-GUARD | RESP-LOCK-COMPOSITION |')
Assert-ReviewRejected 'review owner references bind the exact current work item provenance' $multiWorkItemReview 'responsibility-evidence-missing' -DesignText $multiWorkItemDesign -ImplementationText $foreignOwnerReference

$unchangedSelectedSource = New-ResponsibilityReviewSourceFixture
$unchangedTaskBaseSha = $unchangedSelectedSource.FinalTreeSha
Set-Content -Encoding utf8 -LiteralPath (Join-Path $unchangedSelectedSource.Root 'notes.txt') -Value 'unrelated final-tree change'
Invoke-ReviewSourceGit $unchangedSelectedSource.Root @('add', '--', 'notes.txt') | Out-Null
Invoke-ReviewSourceGit $unchangedSelectedSource.Root @('commit', '-m', 'unrelated final-tree change') | Out-Null
$unchangedSelectedSource = [pscustomobject]@{ Root = $unchangedSelectedSource.Root; TaskBaseSha = $unchangedTaskBaseSha; FinalTreeSha = (Invoke-ReviewSourceGit $unchangedSelectedSource.Root @('rev-parse', 'HEAD')) }
$unchangedImplementation = New-ResponsibilityImplementationFixture -TaskBaseSha $unchangedSelectedSource.TaskBaseSha -FinalTreeSha $unchangedSelectedSource.FinalTreeSha
$unchangedHygieneRow = "| WORK-ADMIN-LOCK | notes.txt | new | DocumentationNote | none | none | none | $($unchangedSelectedSource.TaskBaseSha) | $($unchangedSelectedSource.FinalTreeSha) |"
$updatedUnchangedImplementation = [regex]::Replace($unchangedImplementation, '(?ms)(^## Change Hygiene\r?\n\r?\n\| Task / Unit \| File \| File Kind \| Edited Region / Symbol \| Formatter Command \| Unrelated Diff \| Checkpoint History \| Task-base SHA \| Final-tree SHA \|\r?\n\|---\|---\|---\|---\|---\|---\|---\|---\|---\|\r?\n)(?:\| WORK-ADMIN-LOCK \| (?:ui|lib)/[^\r\n]+\r?\n?)+', "`$1$unchangedHygieneRow`n")
if ($updatedUnchangedImplementation -ceq $unchangedImplementation) { throw 'Unchanged selected-owner Change Hygiene fixture replacement failed' }
$unchangedImplementation = $updatedUnchangedImplementation
$unchangedReview = New-ResponsibilityReviewFixture -PinnedSource $unchangedSelectedSource
$unchangedReviewHygieneRow = "| WORK-ADMIN-LOCK | notes.txt#DocumentationNote | none | none | none | $($unchangedSelectedSource.TaskBaseSha) | $($unchangedSelectedSource.FinalTreeSha) |"
$updatedUnchangedReview = [regex]::Replace($unchangedReview, '(?ms)(^## Change Hygiene\r?\n\r?\n- Change Hygiene Verdict: PASS\r?\n\r?\n\| Task / Unit \| Scope Evidence \| Formatter Evidence \| Unrelated Diff \| Severity \| Task-base SHA \| Final-tree SHA \|\r?\n\|---\|---\|---\|---\|---\|---\|---\|\r?\n)(?:\| WORK-ADMIN-LOCK \| (?:ui|lib)/[^\r\n]+\r?\n?)+', "`$1$unchangedReviewHygieneRow`n")
if ($updatedUnchangedReview -ceq $unchangedReview) { throw 'Unchanged selected-owner review Change Hygiene fixture replacement failed' }
$unchangedReview = $updatedUnchangedReview
$unchangedSourceOnlyReview = [regex]::Replace($unchangedReview, '; diff:[0-9a-f]{40}\.\.[0-9a-f]{40}:[^#;\r\n]+#[A-Za-z][A-Za-z0-9_.:-]*', '')
Assert-ReviewAccepted 'review loads unchanged selected owners from pinned final-tree source evidence without fabricated diff anchors' $unchangedSourceOnlyReview $validReviewDesign $unchangedImplementation $unchangedSelectedSource
Assert-ReviewRejected 'review rejects fabricated diff anchors for unchanged selected owner paths' $unchangedReview 'responsibility-evidence-missing' -DesignText $validReviewDesign -ImplementationText $unchangedImplementation -PinnedSource $unchangedSelectedSource
$foreignShaDiffReview = $unchangedSourceOnlyReview.Replace("source:$($unchangedSelectedSource.FinalTreeSha):ui/admin_wifi.dart#AdminWifi", "source:$($unchangedSelectedSource.FinalTreeSha):ui/admin_wifi.dart#AdminWifi; diff:3333333333333333333333333333333333333333..4444444444444444444444444444444444444444:ui/admin_wifi.dart#AdminWifi")
Assert-ReviewRejected 'review rejects foreign-SHA diff anchors for unchanged selected owner paths' $foreignShaDiffReview 'responsibility-evidence-missing' -DesignText $validReviewDesign -ImplementationText $unchangedImplementation -PinnedSource $unchangedSelectedSource
Remove-Item -LiteralPath $unchangedSelectedSource.Root -Recurse -Force

Remove-Item -LiteralPath $validReviewSource.Root -Recurse -Force

Write-Output 'PASS: responsibility conformance contract'

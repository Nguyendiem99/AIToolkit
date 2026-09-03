param(
  [switch]$ActivationSliceScenariosOnly,
  [switch]$ActivationSliceContractOnly,
  [switch]$ScopeContractsOnly,
  [switch]$IsolationSmokeOnly,
  [switch]$SourceIntegrityOnly,
  [switch]$FinalFixPerformanceOnly,
  [switch]$FinalFixUnicodeOnly,
  [switch]$ValidatorReusePerformanceOnly,
  [string]$IsolationToken = ''
)

$helper = Join-Path $PSScriptRoot 'helpers/IsolatedFixture.ps1'
. $helper
$expectedIsolationToken = $env:AITOOLKIT_FRAMEWORK_TEST_ISOLATION_TOKEN
$expectedIsolationRoot = if ([string]::IsNullOrWhiteSpace($env:AITOOLKIT_FRAMEWORK_TEST_ISOLATION_ROOT)) {
  ''
}
else {
  [IO.Path]::GetFullPath($env:AITOOLKIT_FRAMEWORK_TEST_ISOLATION_ROOT)
}
$pathSeparators = [char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
$systemTempBoundary = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd($pathSeparators)
$expectedIsolationRoot = $expectedIsolationRoot.TrimEnd($pathSeparators)
$scriptRootPath = [IO.Path]::GetFullPath($PSScriptRoot)
$isIsolatedChild =
  -not [string]::IsNullOrWhiteSpace($IsolationToken) -and
  -not [string]::IsNullOrWhiteSpace($expectedIsolationToken) -and
  $IsolationToken -ceq $expectedIsolationToken -and
  -not [string]::IsNullOrWhiteSpace($expectedIsolationRoot) -and
  $expectedIsolationRoot.StartsWith($systemTempBoundary + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -and
  $scriptRootPath.StartsWith($expectedIsolationRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
if (-not $isIsolatedChild) {
  $sourceToolkit = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
  $sourceDigestBefore = Get-TreeDigest -Root $sourceToolkit
  $isolatedToolkit = New-IsolatedAitoolkitFixture -SourceRoot $sourceToolkit
  $isolationRoot = [IO.Path]::GetDirectoryName($isolatedToolkit)
  $childToken = [guid]::NewGuid().ToString('N')
  $childArguments = @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass',
    '-File', (Join-Path $isolatedToolkit 'tests/validate-migration-framework.Tests.ps1'),
    '-IsolationToken', $childToken
  )
  if ($ActivationSliceScenariosOnly) { $childArguments += '-ActivationSliceScenariosOnly' }
  if ($ActivationSliceContractOnly) { $childArguments += '-ActivationSliceContractOnly' }
  if ($ScopeContractsOnly) { $childArguments += '-ScopeContractsOnly' }
  if ($IsolationSmokeOnly) { $childArguments += '-IsolationSmokeOnly' }
  if ($SourceIntegrityOnly) { $childArguments += '-SourceIntegrityOnly' }
  if ($FinalFixPerformanceOnly) { $childArguments += '-FinalFixPerformanceOnly' }
  if ($FinalFixUnicodeOnly) { $childArguments += '-FinalFixUnicodeOnly' }
  if ($ValidatorReusePerformanceOnly) { $childArguments += '-ValidatorReusePerformanceOnly' }
  $previousIsolationToken = $env:AITOOLKIT_FRAMEWORK_TEST_ISOLATION_TOKEN
  $previousIsolationRoot = $env:AITOOLKIT_FRAMEWORK_TEST_ISOLATION_ROOT
  $env:AITOOLKIT_FRAMEWORK_TEST_ISOLATION_TOKEN = $childToken
  $env:AITOOLKIT_FRAMEWORK_TEST_ISOLATION_ROOT = $isolationRoot
  try {
    $childOutput = & (Get-Process -Id $PID).Path @childArguments 2>&1
    $childExitCode = $LASTEXITCODE
    $childOutput | Write-Output
  }
  finally {
    if ($null -eq $previousIsolationToken) {
      Remove-Item Env:AITOOLKIT_FRAMEWORK_TEST_ISOLATION_TOKEN -ErrorAction SilentlyContinue
    }
    else {
      $env:AITOOLKIT_FRAMEWORK_TEST_ISOLATION_TOKEN = $previousIsolationToken
    }
    if ($null -eq $previousIsolationRoot) {
      Remove-Item Env:AITOOLKIT_FRAMEWORK_TEST_ISOLATION_ROOT -ErrorAction SilentlyContinue
    }
    else {
      $env:AITOOLKIT_FRAMEWORK_TEST_ISOLATION_ROOT = $previousIsolationRoot
    }
    Remove-IsolatedAitoolkitFixture -FixtureRoot $isolatedToolkit
  }
  $sourceDigestAfter = Get-TreeDigest -Root $sourceToolkit
  if ($sourceDigestAfter -cne $sourceDigestBefore) {
    Write-Output 'FAIL: Mutation suite changed source checkout bytes'
    exit 1
  }
  exit $childExitCode
}

if ($IsolationSmokeOnly) {
  Write-Output "PASS: migration framework tests isolated under $expectedIsolationRoot"
  exit 0
}

$ErrorActionPreference = 'Stop'

$validator = Join-Path $PSScriptRoot 'validate-migration-framework.ps1'
$testRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$schemaPath = Join-Path $PSScriptRoot '../skills/aitoolkit-schemas/SKILL.md'
$verificationSkillPath = Join-Path $PSScriptRoot '../skills/shared/verification-testing/SKILL.md'
$powershell = (Get-Process -Id $PID).Path
$testFailures = [Collections.Generic.List[string]]::new()

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { $testFailures.Add($Message) }
}

function Invoke-FinalFixClusters(
  [string[]]$Clusters,
  [int]$MaxConcurrency = 4
) {
  if ($Clusters.Count -eq 0) { throw 'At least one final-fix cluster is required' }
  if ($MaxConcurrency -lt 1) { throw 'Final-fix max concurrency must be positive' }

  $ownedJobs = [Collections.Generic.List[object]]::new()
  $ownedFixtures = [Collections.Generic.List[string]]::new()
  $clusterRuns = [Collections.Generic.List[object]]::new()
  try {
    foreach ($cluster in $Clusters) {
      $activeJobs = @($ownedJobs | Where-Object { $_.State -in @('Running', 'NotStarted') })
      while ($activeJobs.Count -ge $MaxConcurrency) {
        Wait-Job -Job $activeJobs -Any | Out-Null
        $activeJobs = @($ownedJobs | Where-Object { $_.State -in @('Running', 'NotStarted') })
      }

      $fixtureRoot = New-IsolatedAitoolkitFixture -SourceRoot $testRoot
      $ownedFixtures.Add($fixtureRoot)
      $clusterScript = Join-Path $fixtureRoot 'tests/validate-activation-slice-final-fixes.Tests.ps1'
      $job = Start-Job -ArgumentList $powershell, $clusterScript, $cluster -ScriptBlock {
        param($PowerShellPath, $ClusterScript, $ClusterName)
        [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
        $OutputEncoding = [Console]::OutputEncoding
        $startedUtc = [DateTime]::UtcNow
        $stopwatch = [Diagnostics.Stopwatch]::StartNew()
        try {
          $output = & $PowerShellPath `
            -NoProfile `
            -ExecutionPolicy Bypass `
            -File $ClusterScript `
            -Cluster $ClusterName 2>&1
          $exitCode = $LASTEXITCODE
          [pscustomobject]@{
            Cluster = $ClusterName
            ExitCode = $exitCode
            Output = ($output -join [Environment]::NewLine)
            StartedUtc = $startedUtc.ToString('o')
            FinishedUtc = [DateTime]::UtcNow.ToString('o')
            DurationMilliseconds = $stopwatch.ElapsedMilliseconds
          }
        }
        catch {
          [pscustomobject]@{
            Cluster = $ClusterName
            ExitCode = 1
            Output = "Final-fix worker failed: $($_.Exception.Message)"
            StartedUtc = $startedUtc.ToString('o')
            FinishedUtc = [DateTime]::UtcNow.ToString('o')
            DurationMilliseconds = $stopwatch.ElapsedMilliseconds
          }
        }
      }
      $ownedJobs.Add($job)
      $clusterRuns.Add([pscustomobject]@{
        Cluster = $cluster
        Job = $job
      })
    }

    Wait-Job -Job @($ownedJobs) | Out-Null
    $results = [Collections.Generic.List[object]]::new()
    foreach ($clusterRun in $clusterRuns) {
      $received = @(Receive-Job -Job $clusterRun.Job -ErrorAction SilentlyContinue)
      if ($received.Count -eq 1) {
        $results.Add($received[0])
      }
      else {
        $jobReason = if ($null -ne $clusterRun.Job.JobStateInfo.Reason) {
          $clusterRun.Job.JobStateInfo.Reason.Message
        }
        else {
          'worker returned no result'
        }
        $results.Add([pscustomobject]@{
          Cluster = $clusterRun.Cluster
          ExitCode = 1
          Output = "Final-fix worker failed: $jobReason"
          StartedUtc = ''
          FinishedUtc = ''
          DurationMilliseconds = 0
        })
      }
    }
    return @($results)
  }
  finally {
    @($ownedJobs | Where-Object { $_.State -in @('Running', 'NotStarted') }) |
      Stop-Job -ErrorAction SilentlyContinue
    if ($ownedJobs.Count -gt 0) {
      Remove-Job -Job @($ownedJobs) -Force -ErrorAction SilentlyContinue
    }
    foreach ($fixtureRoot in $ownedFixtures) {
      Remove-IsolatedAitoolkitFixture -FixtureRoot $fixtureRoot
    }
  }
}

if ($FinalFixPerformanceOnly) {
  $benchmarkStopwatch = [Diagnostics.Stopwatch]::StartNew()
  $benchmarkResults = @(Invoke-FinalFixClusters -Clusters @('Duplicates', 'Pipes') -MaxConcurrency 2)
  $benchmarkStopwatch.Stop()
  foreach ($benchmarkResult in $benchmarkResults) {
    Assert-True `
      ($benchmarkResult.ExitCode -eq 0) `
      "Final-fix benchmark cluster $($benchmarkResult.Cluster) should pass. Output: $($benchmarkResult.Output)"
  }
  $benchmarkIntervalsOverlap = $false
  if (
    $benchmarkResults.Count -eq 2 -and
    -not [string]::IsNullOrWhiteSpace($benchmarkResults[0].StartedUtc) -and
    -not [string]::IsNullOrWhiteSpace($benchmarkResults[0].FinishedUtc) -and
    -not [string]::IsNullOrWhiteSpace($benchmarkResults[1].StartedUtc) -and
    -not [string]::IsNullOrWhiteSpace($benchmarkResults[1].FinishedUtc)
  ) {
    $benchmarkIntervalsOverlap =
      [DateTime]::Parse($benchmarkResults[0].StartedUtc) -lt [DateTime]::Parse($benchmarkResults[1].FinishedUtc) -and
      [DateTime]::Parse($benchmarkResults[1].StartedUtc) -lt [DateTime]::Parse($benchmarkResults[0].FinishedUtc)
  }
  Assert-True $benchmarkIntervalsOverlap 'Final-fix benchmark clusters must overlap'
  Assert-True `
    ($benchmarkStopwatch.ElapsedMilliseconds -le 100000) `
    "Final-fix Duplicates+Pipes exceeded 100000ms performance guard; actual=$($benchmarkStopwatch.ElapsedMilliseconds)ms"
  if ($testFailures.Count -gt 0) {
    $testFailures | ForEach-Object { Write-Output "FAIL: $_" }
    exit 1
  }
  Write-Output "PASS: final-fix parallel benchmark ($($benchmarkStopwatch.ElapsedMilliseconds)ms)"
  exit 0
}

if ($FinalFixUnicodeOnly) {
  $unicodeClusters = @('Resume', 'Downstream', 'Lifecycle')
  $unicodeResults = @(Invoke-FinalFixClusters -Clusters $unicodeClusters -MaxConcurrency 3)
  foreach ($unicodeResult in $unicodeResults) {
    Assert-True `
      ($unicodeResult.ExitCode -eq 0) `
      "Final-fix Unicode cluster $($unicodeResult.Cluster) should pass. Output: $($unicodeResult.Output)"
  }
  if ($testFailures.Count -gt 0) {
    $testFailures | ForEach-Object { Write-Output "FAIL: $_" }
    exit 1
  }
  Write-Output 'PASS: final-fix Unicode clusters'
  exit 0
}

if ($SourceIntegrityOnly) {
  $sourceRoot = $testRoot
  $before = Get-TreeDigest -Root $sourceRoot
  Invoke-IsolatedMutation -SourceRoot $sourceRoot -Mutation {
    param($fixtureRoot)
    $sourceIntegrityFixture = Join-Path $fixtureRoot 'contracts/activation-slice.md'
    [IO.File]::WriteAllText($sourceIntegrityFixture, 'mutation', [Text.UTF8Encoding]::new($false))
    & $powershell -NoProfile -ExecutionPolicy Bypass -File $validator -Check Contracts -Root $fixtureRoot 2>&1 | Out-Null
  }
  $after = Get-TreeDigest -Root $sourceRoot
  Assert-True ($after -ceq $before) 'Mutation suite changed source checkout bytes'
  if ($testFailures.Count -gt 0) {
    $testFailures | ForEach-Object { Write-Output "FAIL: $_" }
    exit 1
  }
  Write-Output 'PASS: source-integrity mutation scenario'
  exit 0
}

function Invoke-Validator([string]$Check) {
  $output = & $powershell -NoProfile -ExecutionPolicy Bypass -File $validator -Check $Check -Root $testRoot 2>&1
  [pscustomobject]@{
    ExitCode = $LASTEXITCODE
    Output = ($output -join [Environment]::NewLine)
  }
}

if ($ValidatorReusePerformanceOnly) {
  $benchmarkStopwatch = [Diagnostics.Stopwatch]::StartNew()
  $benchmarkResults = @(
    Invoke-Validator 'Contracts'
    Invoke-Validator 'Contracts'
  )
  $benchmarkStopwatch.Stop()
  foreach ($benchmarkResult in $benchmarkResults) {
    Assert-True `
      ($benchmarkResult.ExitCode -eq 0) `
      "Validator reuse benchmark Contracts check should pass. Output: $($benchmarkResult.Output)"
  }
  Assert-True `
    ($benchmarkStopwatch.ElapsedMilliseconds -le 35000) `
    "Two Contracts checks exceeded 35000ms validator reuse guard; actual=$($benchmarkStopwatch.ElapsedMilliseconds)ms"
  if ($testFailures.Count -gt 0) {
    $testFailures | ForEach-Object { Write-Output "FAIL: $_" }
    exit 1
  }
  Write-Output "PASS: validator reuse benchmark ($($benchmarkStopwatch.ElapsedMilliseconds)ms)"
  exit 0
}

function Assert-Contains([string]$Text, [string]$Expected, [string]$Context) {
  Assert-True ($Text.Contains($Expected)) "$Context missing <$Expected>. Output: $Text"
}

function Assert-NotContains([string]$Text, [string]$Unexpected, [string]$Context) {
  Assert-True (-not $Text.Contains($Unexpected)) "$Context unexpectedly contained <$Unexpected>. Output: $Text"
}

function Replace-InMarkdownSection(
  [string]$Text,
  [string]$SectionName,
  [string]$From,
  [string]$To
) {
  $header = "## $SectionName"
  $start = $Text.IndexOf($header, [StringComparison]::Ordinal)
  if ($start -lt 0) { return $Text }
  $next = $Text.IndexOf("`n## ", $start + $header.Length, [StringComparison]::Ordinal)
  if ($next -lt 0) { $next = $Text.Length }
  $body = $Text.Substring($start, $next - $start)
  $mutatedBody = $body.Replace($From, $To)
  return $Text.Substring(0, $start) + $mutatedBody + $Text.Substring($next)
}

function Set-OnlyFunctionBody([string]$Text, [string]$Body) {
  $tokens = $null
  $parseErrors = $null
  $ast = [Management.Automation.Language.Parser]::ParseInput(
    $Text,
    [ref]$tokens,
    [ref]$parseErrors
  )
  if (@($parseErrors).Count -gt 0) { return $Text }
  $functions = @($ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.FunctionDefinitionAst]
  }, $true))
  if ($functions.Count -ne 1) { return $Text }
  $bodyExtent = $functions[0].Body.Extent
  return $Text.Substring(0, $bodyExtent.StartOffset) + $Body +
    $Text.Substring($bodyExtent.EndOffset)
}

function Invoke-ActivationSliceArtifactValidator(
  [string]$Text,
  [string]$PredecessorText = ''
) {
  $fixtureSuffix = "$PID-$([guid]::NewGuid().ToString('N'))"
  $fixturePath = Join-Path $PSScriptRoot ".activation-slice-$fixtureSuffix.md"
  $predecessorPath = Join-Path $PSScriptRoot ".activation-slice-predecessor-$fixtureSuffix.md"
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

function Remove-MarkdownTablesInSection(
  [string]$Text,
  [string]$SectionName
) {
  $header = "## $SectionName"
  $start = $Text.IndexOf($header, [StringComparison]::Ordinal)
  if ($start -lt 0) { return $Text }
  $next = $Text.IndexOf("`n## ", $start + $header.Length, [StringComparison]::Ordinal)
  if ($next -lt 0) { $next = $Text.Length }
  $body = $Text.Substring($start, $next - $start)
  $mutatedBody = [regex]::Replace($body, '(?m)^\|.*\|\s*\r?\n?', '')
  return $Text.Substring(0, $start) + $mutatedBody + $Text.Substring($next)
}

function Set-MarkdownRecordCellBlank([string]$Row, [int]$CellIndex) {
  $cells = $Row.Split('|')
  $cells[$CellIndex] = ' '
  return ($cells -join '|')
}

$selectedMigrationUnitSection = 'Selected Migration Unit'
$translatedSelectedMigrationUnitSection = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('xJDGoW4gduG7iyBtaWdyYXRpb24gxJHGsOG7o2MgY2jhu41u'))
$nativeBlockersSection = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('QmxvY2tlciBn4buRYw=='))
$legalPairsSection = 'Check Outcome Legal Pairs'
$checkOutcomesSection = 'Check Outcomes'
$automationWaiversSection = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('QXV0b21hdGlvbiB3YWl2ZXI='))
$foundationRecordSection = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('QuG6o24gZ2hpIGJhc2VsaW5lIG7hu4FuIHThuqNuZw=='))
$pendingApprovalPhrase = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('cGVuZGluZy1hcHByb3ZhbDsgxJHhurd0IG5ndXnDqm4gdOG7rSB0aMOgbmggYXBwcm92ZWQgdOG6oWkgZ2F0ZQ=='))
$orderedUnitsSection = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('Q8OhYyDEkcahbiB24buLIG1pZ3JhdGlvbiB0aGVvIHRo4bupIHThu7E='))
$approvedBaselinesSection = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('QmFzZWxpbmUgbuG7gW4gdOG6o25nIMSRw6MgZHV54buHdA=='))
$mappingsSection = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('w4FuaCB44bqh'))
$gapsSection = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('S2hv4bqjbmcgdHLhu5FuZyB2w6AgeHVuZyDEkeG7mXQ='))
$documentRecordsSection = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('QuG6o24gZ2hpIGLhurFuZyBjaOG7qW5nIHTDoGkgbGnhu4d1'))
$commandResolutionSection = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('UGjDom4gZ2nhuqNpIGzhu4duaA=='))
$inspectionHandoffSection = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('QsOgbiBnaWFvIGLhurFuZyBjaOG7qW5nIGto4bqjbyBzw6F0'))
$documentHandoffSection = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('QsOgbiBnaWFvIGLhurFuZyBjaOG7qW5nIHTDoGkgbGnhu4d1'))
$profileDocumentSection = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('QuG6sW5nIGNo4bupbmcgdMOgaSBsaeG7h3UgcHJvZmlsZQ=='))
$terminalVerificationSection = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('WMOhYyBtaW5oIMSR4bqndSBjdeG7kWk='))

$schemaText = Get-Content -Raw -Encoding utf8 $schemaPath
$resolutionOrder = 'explicit profile -> existing project scripts/config -> marker detection -> human gate'
Assert-Contains $schemaText $resolutionOrder 'Command resolution contract'
$verificationText = Get-Content -Raw -Encoding utf8 $verificationSkillPath
Assert-Contains $verificationText $resolutionOrder 'Verification command resolution'

$contracts = Invoke-Validator 'Contracts'
Assert-True ($contracts.ExitCode -eq 0) "Contracts should pass. Output: $($contracts.Output)"

$targetContractsOutput = & $powershell -NoProfile -ExecutionPolicy Bypass -File $validator -Target Contracts 2>&1
$targetContracts = [pscustomobject]@{
  ExitCode = $LASTEXITCODE
  Output = ($targetContractsOutput -join [Environment]::NewLine)
}
Assert-True ($targetContracts.ExitCode -eq 0) "Target alias should select Contracts. Output: $($targetContracts.Output)"
Assert-Contains $targetContracts.Output 'PASS: migration framework (Contracts)' 'Target alias Contracts selector'

$activationContractFixture = Join-Path $PSScriptRoot '../contracts/activation-slice.md'
$activationContractOriginalBytes = [IO.File]::ReadAllBytes($activationContractFixture)
$activationContractOriginal = [Text.Encoding]::UTF8.GetString($activationContractOriginalBytes)
try {
  Remove-Item -LiteralPath $activationContractFixture -Force
  $contracts = Invoke-Validator 'Contracts'
  Assert-True ($contracts.ExitCode -eq 1) "Missing Activation Slice contract should fail. Output: $($contracts.Output)"
  Assert-Contains $contracts.Output 'FAIL: Missing Activation Slice contract resource' 'Activation Slice resource'
}
finally {
  [IO.File]::WriteAllBytes($activationContractFixture, $activationContractOriginalBytes)
}

$scopeContractFixture = Join-Path $PSScriptRoot '../contracts/migration-scope-orchestration.md'
$conformanceContractFixture = Join-Path $PSScriptRoot '../contracts/target-structure-conformance.md'
$scopeContractOriginalBytes = [IO.File]::ReadAllBytes($scopeContractFixture)
$scopeContractOriginal = [Text.Encoding]::UTF8.GetString($scopeContractOriginalBytes)
$conformanceContractOriginalBytes = [IO.File]::ReadAllBytes($conformanceContractFixture)
$conformanceContractOriginal = [Text.Encoding]::UTF8.GetString($conformanceContractOriginalBytes)

$contractResourceCases = @(
  [pscustomobject]@{
    Path = $scopeContractFixture
    Bytes = $scopeContractOriginalBytes
    Expected = 'FAIL: Missing migration scope orchestration contract resource'
    Label = 'migration scope orchestration contract resource'
  }
  [pscustomobject]@{
    Path = $conformanceContractFixture
    Bytes = $conformanceContractOriginalBytes
    Expected = 'FAIL: Missing target structure conformance contract resource'
    Label = 'target structure conformance contract resource'
  }
)
foreach ($contractResourceCase in $contractResourceCases) {
  try {
    Remove-Item -LiteralPath $contractResourceCase.Path -Force
    $contracts = Invoke-Validator 'Contracts'
    Assert-True ($contracts.ExitCode -eq 1) "Missing $($contractResourceCase.Label) should fail. Output: $($contracts.Output)"
    Assert-Contains $contracts.Output $contractResourceCase.Expected $contractResourceCase.Label
  }
  finally {
    [IO.File]::WriteAllBytes($contractResourceCase.Path, $contractResourceCase.Bytes)
  }
}

$contractTableCases = @(
  [pscustomobject]@{
    Path = $scopeContractFixture
    Bytes = $scopeContractOriginalBytes
    Original = $scopeContractOriginal
    From = '| Kind | ID | Statement | Source | Resolution Evidence |'
    To = '| ID | Kind | Statement | Source | Resolution Evidence |'
    Expected = 'FAIL: Migration scope orchestration contract Requested Scope table columns must be exactly: Kind | ID | Statement | Source | Resolution Evidence'
    Label = 'Requested Scope exact columns'
  }
  [pscustomobject]@{
    Path = $scopeContractFixture
    Bytes = $scopeContractOriginalBytes
    Original = $scopeContractOriginal
    From = '| Work Item ID | Title | Required | Dependencies | Plan Order | Acceptance | Trace IDs | Delivery Adapter | Status | Latest Attempt | Terminal Evidence | Approval Reference |'
    To = '| Work Item ID | Title | Required | Plan Order | Dependencies | Acceptance | Trace IDs | Delivery Adapter | Status | Latest Attempt | Terminal Evidence | Approval Reference |'
    Expected = 'FAIL: Migration scope orchestration contract Work Item table columns must be exactly: Work Item ID | Title | Required | Dependencies | Plan Order | Acceptance | Trace IDs | Delivery Adapter | Status | Latest Attempt | Terminal Evidence | Approval Reference'
    Label = 'Work Item exact columns'
  }
  [pscustomobject]@{
    Path = $scopeContractFixture
    Bytes = $scopeContractOriginalBytes
    Original = $scopeContractOriginal
    From = '| Attempt ID | Work Item ID | Plan Revision | Status | Artifact Reference |'
    To = '| Attempt ID | Work Item ID | Status | Plan Revision | Artifact Reference |'
    Expected = 'FAIL: Migration scope orchestration contract Attempt table columns must be exactly: Attempt ID | Work Item ID | Plan Revision | Status | Artifact Reference'
    Label = 'Attempt exact columns'
  }
  [pscustomobject]@{
    Path = $scopeContractFixture
    Bytes = $scopeContractOriginalBytes
    Original = $scopeContractOriginal
    From = '| Artifact ID | Revision | Supersedes | Change Summary | Affected Work Items | Approval Reference |'
    To = '| Artifact ID | Supersedes | Revision | Change Summary | Affected Work Items | Approval Reference |'
    Expected = 'FAIL: Migration scope orchestration contract Revision table columns must be exactly: Artifact ID | Revision | Supersedes | Change Summary | Affected Work Items | Approval Reference'
    Label = 'Revision exact columns'
  }
  [pscustomobject]@{
    Path = $conformanceContractFixture
    Bytes = $conformanceContractOriginalBytes
    Original = $conformanceContractOriginal
    From = '| Concern | Path | Inspected Symbols | Observed Pattern | Comparable Reason | Evidence | Status |'
    To = '| Concern | Path | Observed Pattern | Inspected Symbols | Comparable Reason | Evidence | Status |'
    Expected = 'FAIL: Target structure conformance contract Comparable Target Exemplars table columns must be exactly: Concern | Path | Inspected Symbols | Observed Pattern | Comparable Reason | Evidence | Status'
    Label = 'Comparable Target Exemplars exact columns'
  }
  [pscustomobject]@{
    Path = $conformanceContractFixture
    Bytes = $conformanceContractOriginalBytes
    Original = $conformanceContractOriginal
    From = '| Concern | Working Exemplar | Observed Target Pattern | Proposed Path/Symbol | Conforms | Deviation Reference |'
    To = '| Concern | Working Exemplar | Proposed Path/Symbol | Observed Target Pattern | Conforms | Deviation Reference |'
    Expected = 'FAIL: Target structure conformance contract Target Structure Conformance Matrix table columns must be exactly: Concern | Working Exemplar | Observed Target Pattern | Proposed Path/Symbol | Conforms | Deviation Reference'
    Label = 'Target Structure Conformance Matrix exact columns'
  }
  [pscustomobject]@{
    Path = $conformanceContractFixture
    Bytes = $conformanceContractOriginalBytes
    Original = $conformanceContractOriginal
    From = '| Runtime Evidence State | Architecture Conformance State | Selector Schema State |'
    To = '| Architecture Conformance State | Runtime Evidence State | Selector Schema State |'
    Expected = 'FAIL: Target structure conformance contract Assurance State table columns must be exactly: Runtime Evidence State | Architecture Conformance State | Selector Schema State'
    Label = 'Assurance State exact columns'
  }
)
foreach ($contractTableCase in $contractTableCases) {
  try {
    $mutatedContract = $contractTableCase.Original.Replace($contractTableCase.From, $contractTableCase.To)
    Assert-True ($mutatedContract -cne $contractTableCase.Original) "Contract table mutation must alter $($contractTableCase.Label)"
    [IO.File]::WriteAllText($contractTableCase.Path, $mutatedContract, [Text.UTF8Encoding]::new($false))
    $contracts = Invoke-Validator 'Contracts'
    Assert-True ($contracts.ExitCode -eq 1) "$($contractTableCase.Label) drift should fail. Output: $($contracts.Output)"
    Assert-Contains $contracts.Output $contractTableCase.Expected $contractTableCase.Label
  }
  finally {
    [IO.File]::WriteAllBytes($contractTableCase.Path, $contractTableCase.Bytes)
  }
}

$contractTokenCases = @(
  [pscustomobject]@{ Path = $scopeContractFixture; Bytes = $scopeContractOriginalBytes; Original = $scopeContractOriginal; Token = 'Requested scope kinds: `project | module | feature | task | explicit-item | unresolved`.'; Context = 'Migration scope orchestration contract' }
  [pscustomobject]@{ Path = $scopeContractFixture; Bytes = $scopeContractOriginalBytes; Original = $scopeContractOriginal; Token = 'Scope states: `planned | scope-in-progress | scope-blocked | scope-complete | scope-cancelled-approved`.'; Context = 'Migration scope orchestration contract' }
  [pscustomobject]@{ Path = $scopeContractFixture; Bytes = $scopeContractOriginalBytes; Original = $scopeContractOriginal; Token = 'Work-item states: `proposed | pending | ready | in-progress | blocked | complete | cancelled-approved | not-applicable-approved`.'; Context = 'Migration scope orchestration contract' }
  [pscustomobject]@{ Path = $scopeContractFixture; Bytes = $scopeContractOriginalBytes; Original = $scopeContractOriginal; Token = 'Delivery adapter kinds: `migration-unit | task | story | package | phase | milestone | none`.'; Context = 'Migration scope orchestration contract' }
  [pscustomobject]@{ Path = $scopeContractFixture; Bytes = $scopeContractOriginalBytes; Original = $scopeContractOriginal; Token = 'Selection order: dependency depth ascending -> Plan Order ascending -> ordinal Work Item ID ascending.'; Context = 'Migration scope orchestration contract' }
  [pscustomobject]@{ Path = $scopeContractFixture; Bytes = $scopeContractOriginalBytes; Original = $scopeContractOriginal; Token = 'Terminal-success states: `complete | cancelled-approved | not-applicable-approved`.'; Context = 'Migration scope orchestration contract' }
  [pscustomobject]@{ Path = $scopeContractFixture; Bytes = $scopeContractOriginalBytes; Original = $scopeContractOriginal; Token = 'Resume reconciliation applies a missing terminal transition from valid evidence before selecting another work item.'; Context = 'Migration scope orchestration contract' }
  [pscustomobject]@{ Path = $scopeContractFixture; Bytes = $scopeContractOriginalBytes; Original = $scopeContractOriginal; Token = 'Approved revisions are immutable and form one linear, non-forked, non-cyclic chain.'; Context = 'Migration scope orchestration contract' }
  [pscustomobject]@{ Path = $scopeContractFixture; Bytes = $scopeContractOriginalBytes; Original = $scopeContractOriginal; Token = 'Decomposition creates a new master-plan revision and canonical child selectors must be approved before adapter assignment.'; Context = 'Migration scope orchestration contract' }
  [pscustomobject]@{ Path = $scopeContractFixture; Bytes = $scopeContractOriginalBytes; Original = $scopeContractOriginal; Token = 'Scope-completion formula: every required work item is terminal-success AND no blocker remains AND the dependency graph is valid AND completed-item architecture conformance is PASS AND completed-item selector/schema is PASS AND the terminal scope report enumerates all evidence.'; Context = 'Migration scope orchestration contract' }
  [pscustomobject]@{ Path = $conformanceContractFixture; Bytes = $conformanceContractOriginalBytes; Original = $conformanceContractOriginal; Token = 'service/config subscription and normalization'; Context = 'Target structure conformance contract' }
  [pscustomobject]@{ Path = $conformanceContractFixture; Bytes = $conformanceContractOriginalBytes; Original = $conformanceContractOriginal; Token = 'Exemplar status: `verified | no-equivalent | unknown`.'; Context = 'Target structure conformance contract' }
  [pscustomobject]@{ Path = $conformanceContractFixture; Bytes = $conformanceContractOriginalBytes; Original = $conformanceContractOriginal; Token = 'A `Conforms = no` row requires a resolved conflict and Tech Lead approval in `Deviation Reference`.'; Context = 'Target structure conformance contract' }
  [pscustomobject]@{ Path = $conformanceContractFixture; Bytes = $conformanceContractOriginalBytes; Original = $conformanceContractOriginal; Token = 'The structural pre-edit gate blocks before target edit and is not waiver-eligible.'; Context = 'Target structure conformance contract' }
  [pscustomobject]@{ Path = $conformanceContractFixture; Bytes = $conformanceContractOriginalBytes; Original = $conformanceContractOriginal; Token = 'runtime_evidence_state: PASS | FAIL | NOT_RUN | WAIVED'; Context = 'Target structure conformance contract' }
  [pscustomobject]@{ Path = $conformanceContractFixture; Bytes = $conformanceContractOriginalBytes; Original = $conformanceContractOriginal; Token = 'Architecture-first review order: master-scope/work-item alignment -> project rule resolution -> canonical selector -> architecture conformance with matrix/exemplars -> production activation path -> behavior, failure modes, security, performance, and tests -> change hygiene.'; Context = 'Target structure conformance contract' }
)
foreach ($contractTokenCase in $contractTokenCases) {
  try {
    $mutatedContract = $contractTokenCase.Original.Replace($contractTokenCase.Token, '__removed__')
    Assert-True ($mutatedContract -cne $contractTokenCase.Original) "Contract token mutation must alter: $($contractTokenCase.Token)"
    [IO.File]::WriteAllText($contractTokenCase.Path, $mutatedContract, [Text.UTF8Encoding]::new($false))
    $contracts = Invoke-Validator 'Contracts'
    Assert-True ($contracts.ExitCode -eq 1) "Contract without token should fail: $($contractTokenCase.Token). Output: $($contracts.Output)"
    Assert-Contains $contracts.Output "FAIL: $($contractTokenCase.Context) missing: $($contractTokenCase.Token)" "Contract token: $($contractTokenCase.Token)"
  }
  finally {
    [IO.File]::WriteAllBytes($contractTokenCase.Path, $contractTokenCase.Bytes)
  }
}

$scopeSchemaOriginalBytes = [IO.File]::ReadAllBytes($schemaPath)
$scopeSchemaOriginal = [Text.Encoding]::UTF8.GetString($scopeSchemaOriginalBytes)
$scopeSchemaTokens = @(
  'artifact_type: migration-master-spec',
  'artifact_type: migration-master-plan',
  'work_item_id: WORK-<SCOPE>-<NAME>',
  'delivery_adapter:',
  'attempt_id: ATTEMPT-<WORK-ITEM>-<NN>',
  'supersedes: <artifact-id>@<revision> | not-applicable',
  'runtime_evidence_state: <value from target-structure-conformance.md>',
  'Historical unit-only artifacts remain readable, but they must not resume to production mutation before compatibility conversion.'
)
foreach ($scopeSchemaToken in $scopeSchemaTokens) {
  try {
    $mutatedSchema = $scopeSchemaOriginal.Replace($scopeSchemaToken, '__removed__')
    Assert-True ($mutatedSchema -cne $scopeSchemaOriginal) "Scope schema mutation must alter: $scopeSchemaToken"
    [IO.File]::WriteAllText($schemaPath, $mutatedSchema, [Text.UTF8Encoding]::new($false))
    $contracts = Invoke-Validator 'Contracts'
    Assert-True ($contracts.ExitCode -eq 1) "Schema without scope token should fail: $scopeSchemaToken. Output: $($contracts.Output)"
    Assert-Contains $contracts.Output "FAIL: Migration scope artifact schema missing: $scopeSchemaToken" "Scope schema token: $scopeSchemaToken"
  }
  finally {
    [IO.File]::WriteAllBytes($schemaPath, $scopeSchemaOriginalBytes)
  }
}

$validationModuleCases = @(
  [pscustomobject]@{ File = 'scope-artifacts.validation.ps1'; Entry = 'Test-ScopeArtifacts'; Target = 'Contracts'; RuleToken = 'Requested Scope' }
  [pscustomobject]@{ File = 'scope-engine.validation.ps1'; Entry = 'Test-ScopeEngine'; Target = 'Orchestrators'; RuleToken = 'Deterministic selection order' }
  [pscustomobject]@{ File = 'delivery-adapters.validation.ps1'; Entry = 'Test-DeliveryAdapters'; Target = 'Skills'; RuleToken = 'Delivery adapter kinds' }
  [pscustomobject]@{ File = 'target-conformance.validation.ps1'; Entry = 'Test-TargetConformance'; Target = 'Contracts'; RuleToken = 'Comparable Target Exemplars' }
  [pscustomobject]@{ File = 'structural-gate.validation.ps1'; Entry = 'Test-StructuralGate'; Target = 'Skills'; RuleToken = 'Structural pre-edit gate' }
  [pscustomobject]@{ File = 'architecture-review.validation.ps1'; Entry = 'Test-ArchitectureReview'; Target = 'Skills'; RuleToken = 'Architecture-first review order' }
)
foreach ($validationModuleCase in $validationModuleCases) {
  $modulePath = Join-Path $PSScriptRoot "validation/$($validationModuleCase.File)"
  $moduleOriginalBytes = [IO.File]::ReadAllBytes($modulePath)
  $moduleOriginal = [Text.Encoding]::UTF8.GetString($moduleOriginalBytes)
  try {
    $renamedModule = $moduleOriginal.Replace(
      "function $($validationModuleCase.Entry)(",
      "function $($validationModuleCase.Entry)Renamed("
    )
    Assert-True ($renamedModule -cne $moduleOriginal) "Entry rename mutation must alter $($validationModuleCase.File)"
    [IO.File]::WriteAllText($modulePath, $renamedModule, [Text.UTF8Encoding]::new($false))
    $moduleResult = Invoke-Validator $validationModuleCase.Target
    Assert-True ($moduleResult.ExitCode -eq 1) "Renamed module entry should fail: $($validationModuleCase.File). Output: $($moduleResult.Output)"
    Assert-Contains $moduleResult.Output "FAIL: Validation module $($validationModuleCase.File) must export exactly one function: $($validationModuleCase.Entry)" "Module entry: $($validationModuleCase.File)"
  }
  finally {
    [IO.File]::WriteAllBytes($modulePath, $moduleOriginalBytes)
  }

  try {
    $emptyBodyModule = Set-OnlyFunctionBody $moduleOriginal '{ }'
    Assert-True ($emptyBodyModule -cne $moduleOriginal) "Empty-body mutation must alter $($validationModuleCase.File)"
    [IO.File]::WriteAllText($modulePath, $emptyBodyModule, [Text.UTF8Encoding]::new($false))
    $moduleResult = Invoke-Validator $validationModuleCase.Target
    Assert-True ($moduleResult.ExitCode -eq 1) "Empty module entry should fail: $($validationModuleCase.File). Output: $($moduleResult.Output)"
    Assert-Contains $moduleResult.Output "FAIL: Validation module $($validationModuleCase.File) entry function body must not be empty" "Module body: $($validationModuleCase.File)"
  }
  finally {
    [IO.File]::WriteAllBytes($modulePath, $moduleOriginalBytes)
  }

  try {
    $rulelessModule = $moduleOriginal.Replace($validationModuleCase.RuleToken, '__removed__')
    Assert-True ($rulelessModule -cne $moduleOriginal) "Contract-rule mutation must alter $($validationModuleCase.File)"
    [IO.File]::WriteAllText($modulePath, $rulelessModule, [Text.UTF8Encoding]::new($false))
    $moduleResult = Invoke-Validator $validationModuleCase.Target
    Assert-True ($moduleResult.ExitCode -eq 1) "Ruleless module entry should fail: $($validationModuleCase.File). Output: $($moduleResult.Output)"
    Assert-Contains $moduleResult.Output "FAIL: Validation module $($validationModuleCase.File) missing contract-derived rule: $($validationModuleCase.RuleToken)" "Module contract rule: $($validationModuleCase.File)"
  }
  finally {
    [IO.File]::WriteAllBytes($modulePath, $moduleOriginalBytes)
  }
}

if ($ScopeContractsOnly) {
  if ($testFailures.Count -gt 0) {
    $testFailures | ForEach-Object { Write-Output "FAIL: $_" }
    exit 1
  }
  Write-Output 'PASS: migration scope contract scenarios'
  exit 0
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

$completeScenario = Invoke-ActivationSliceArtifactValidator $completeActivationSlice
Assert-True ($completeScenario.ExitCode -eq 0) "Complete Activation Slice scenario should pass. Output: $($completeScenario.Output)"
Assert-Contains $completeScenario.Output 'PASS: Activation Slice artifact' 'Complete Activation Slice scenario'

$activationSeamScenarios = @(
  [pscustomobject]@{
    Name = 'parse-model missing while later seams exist'
    Text = [regex]::Replace($completeActivationSlice, '(?m)^\| ACT-001 \| applicable \| parse-model \|.*\r?\n?', '')
    Expected = 'missing or duplicated canonical seam: parse-model'
  }
  [pscustomobject]@{
    Name = 'requested-key missing while model field exists'
    Text = [regex]::Replace($completeActivationSlice, '(?m)^\| ACT-001 \| applicable \| requested-key \|.*\r?\n?', '')
    Expected = 'missing or duplicated canonical seam: requested-key'
  }
  [pscustomobject]@{
    Name = 'downstream-consumer missing'
    Text = [regex]::Replace($completeActivationSlice, '(?m)^\| ACT-001 \| applicable \| downstream-consumer \|.*\r?\n?', '')
    Expected = 'missing or duplicated canonical seam: downstream-consumer'
  }
)
foreach ($activationSeamScenario in $activationSeamScenarios) {
  $scenarioResult = Invoke-ActivationSliceArtifactValidator $activationSeamScenario.Text
  Assert-True ($scenarioResult.ExitCode -eq 1) "Activation Slice scenario should block: $($activationSeamScenario.Name). Output: $($scenarioResult.Output)"
  Assert-Contains $scenarioResult.Output $activationSeamScenario.Expected "Activation Slice scenario: $($activationSeamScenario.Name)"
}

$oneShotAsyncSlice = $completeActivationSlice.Replace(
  'initial-loading=spinner; update-watch=subscription; reselection=rerun; state-preservation-reset=preserve; failure-behavior=error',
  'one-shot-read=true'
).Replace('lifecycle-test-trace=TR-LIFECYCLE-001', 'activation-smoke-test=TR-TEST-001').Replace('TR-LIFECYCLE-001', 'TR-TEST-001')
$oneShotAsyncResult = Invoke-ActivationSliceArtifactValidator $oneShotAsyncSlice
Assert-True ($oneShotAsyncResult.ExitCode -eq 1) "One-shot asynchronous selector scenario should block. Output: $($oneShotAsyncResult.Output)"
Assert-Contains $oneShotAsyncResult.Output 'async classification missing lifecycle evidence' 'One-shot asynchronous selector scenario'

$ambiguousAsyncSlice = $completeActivationSlice.Replace('async-classification=async; ', '')
$ambiguousAsyncResult = Invoke-ActivationSliceArtifactValidator $ambiguousAsyncSlice
Assert-True ($ambiguousAsyncResult.ExitCode -eq 1) "Activation Slice without async classification should block. Output: $($ambiguousAsyncResult.Output)"
Assert-Contains $ambiguousAsyncResult.Output 'selector Input requires exactly one async classification' 'Activation Slice async classification ambiguity'

$localizedAsyncSlice = $completeActivationSlice.Replace(
  'initial-loading=spinner; update-watch=subscription; reselection=rerun; state-preservation-reset=preserve; failure-behavior=error',
  'initial-loading=cargando; update-watch=seguimiento; reselection=nueva-seleccion; state-preservation-reset=conservar; failure-behavior=fallo'
)
$localizedAsyncResult = Invoke-ActivationSliceArtifactValidator $localizedAsyncSlice
Assert-True ($localizedAsyncResult.ExitCode -eq 0) "Machine-readable async lifecycle with non-English values should pass. Output: $($localizedAsyncResult.Output)"

$immutableActivationSlice = $completeActivationSlice.Replace(
  'async-classification=async; activation state',
  'async-classification=immutable; activation state'
).Replace(
  'initial-loading=spinner; update-watch=subscription; reselection=rerun; state-preservation-reset=preserve; failure-behavior=error',
  'one-shot-read=true'
).Replace(
  'src/selector:50',
  'src/selector:50; immutability-evidence=config-load-once'
).Replace(
  'lifecycle-test-trace=TR-LIFECYCLE-001',
  'activation-smoke-test=TR-TEST-001'
).Replace('TR-LIFECYCLE-001', 'TR-TEST-001')
$immutableActivationResult = Invoke-ActivationSliceArtifactValidator $immutableActivationSlice
Assert-True ($immutableActivationResult.ExitCode -eq 0) "Immutable activation selector with evidence should pass. Output: $($immutableActivationResult.Output)"

$missingImmutabilityEvidenceSlice = $immutableActivationSlice.Replace('; immutability-evidence=config-load-once', '')
$missingImmutabilityEvidenceResult = Invoke-ActivationSliceArtifactValidator $missingImmutabilityEvidenceSlice
Assert-True ($missingImmutabilityEvidenceResult.ExitCode -eq 1) "Immutable activation selector without evidence should block. Output: $($missingImmutabilityEvidenceResult.Output)"
Assert-Contains $missingImmutabilityEvidenceResult.Output 'immutable classification requires immutability-evidence in selector Source Reference' 'Immutable activation evidence'

$dualRouterSlice = $completeActivationSlice.Replace(
  'base-owned',
  'base-owned and specialized-owned router ownership is unresolved'
)
$dualRouterResult = Invoke-ActivationSliceArtifactValidator $dualRouterSlice
Assert-True ($dualRouterResult.ExitCode -eq 1) "Dual router ownership scenario should block. Output: $($dualRouterResult.Output)"
Assert-Contains $dualRouterResult.Output 'construct Output must record exactly one approved router policy; found 2' 'Dual router ownership scenario'

$constructRow = '| ACT-001 | applicable | construct | selected module | base-owned | src/router:60 | TR-REQ-001, TR-ROUTER-001 | reuse | verified | not-applicable | not-applicable |'
$dualPathConstructRow = '| ACT-001 | applicable | construct | selected module | compatibility-dual-path | src/router:60; compatibility-reason=legacy-route; router-owner=platform | TR-REQ-001, TR-ROUTER-001, PARITY-001 | reuse | verified | ADR-060 | not-applicable |'
$completeDualPathSlice = $completeActivationSlice.Replace($constructRow, $dualPathConstructRow)
$completeDualPathResult = Invoke-ActivationSliceArtifactValidator $completeDualPathSlice
Assert-True ($completeDualPathResult.ExitCode -eq 0) "Complete compatibility-dual-path evidence should pass. Output: $($completeDualPathResult.Output)"

$misplacedRouterPolicySlice = $completeActivationSlice.Replace(
  $constructRow,
  '| ACT-001 | applicable | construct | base-owned | unresolved | src/router:60 | TR-REQ-001, TR-ROUTER-001 | reuse | verified | not-applicable | not-applicable |'
)
$misplacedRouterPolicyResult = Invoke-ActivationSliceArtifactValidator $misplacedRouterPolicySlice
Assert-True ($misplacedRouterPolicyResult.ExitCode -eq 1) "Router policy outside construct Output should block. Output: $($misplacedRouterPolicyResult.Output)"
Assert-Contains $misplacedRouterPolicyResult.Output 'construct Output must record exactly one approved router policy; found 0' 'Router policy field placement'

$routerPolicyProseSlice = $completeActivationSlice.Replace(
  $constructRow,
  '| ACT-001 | applicable | construct | selected module | selected base-owned router policy | src/router:60 | TR-REQ-001, TR-ROUTER-001 | reuse | verified | not-applicable | not-applicable |'
)
$routerPolicyProseResult = Invoke-ActivationSliceArtifactValidator $routerPolicyProseSlice
Assert-True ($routerPolicyProseResult.ExitCode -eq 1) "Construct Output with policy embedded in prose should block. Output: $($routerPolicyProseResult.Output)"
Assert-Contains $routerPolicyProseResult.Output 'construct Output router policy must be the exact canonical value: base-owned' 'Router policy exact value'

$dualPathDependencyScenarios = @(
  [pscustomobject]@{
    Name = 'compatibility reason'
    Text = $completeDualPathSlice.Replace('; compatibility-reason=legacy-route', '')
    Expected = 'compatibility-dual-path requires compatibility-reason in construct Source Reference'
  }
  [pscustomobject]@{
    Name = 'router owner'
    Text = $completeDualPathSlice.Replace('; router-owner=platform', '')
    Expected = 'compatibility-dual-path requires router-owner in construct Source Reference'
  }
  [pscustomobject]@{
    Name = 'approval reference'
    Text = $completeDualPathSlice.Replace('| ADR-060 | not-applicable |', '| not-applicable | not-applicable |')
    Expected = 'compatibility-dual-path requires construct Decision Reference'
  }
  [pscustomobject]@{
    Name = 'parity-test trace'
    Text = $completeDualPathSlice.Replace(', PARITY-001', '')
    Expected = 'compatibility-dual-path requires parity-test Trace ID'
  }
)
foreach ($dualPathDependencyScenario in $dualPathDependencyScenarios) {
  $dualPathDependencyResult = Invoke-ActivationSliceArtifactValidator $dualPathDependencyScenario.Text
  Assert-True ($dualPathDependencyResult.ExitCode -eq 1) "Compatibility dual-path without $($dualPathDependencyScenario.Name) should block. Output: $($dualPathDependencyResult.Output)"
  Assert-Contains $dualPathDependencyResult.Output $dualPathDependencyScenario.Expected "Compatibility dual-path $($dualPathDependencyScenario.Name)"
}

$fullWidthParityId = "PARITY-$([char]0xFF10)$([char]0xFF10)$([char]0xFF11)"
$unicodeParityTraceSlice = $completeDualPathSlice.Replace('PARITY-001', $fullWidthParityId)
$unicodeParityTraceResult = Invoke-ActivationSliceArtifactValidator $unicodeParityTraceSlice
Assert-True ($unicodeParityTraceResult.ExitCode -eq 1) "Parity trace IDs with non-ASCII digits should block. Output: $($unicodeParityTraceResult.Output)"
Assert-Contains $unicodeParityTraceResult.Output 'compatibility-dual-path requires parity-test Trace ID' 'ASCII parity trace ID'

$deferredDecisionSlice = $completeActivationSlice.Replace(
  '| ACT-001 | applicable | render | constructed module | visible module | src/render:70 | TR-REQ-001, TR-RENDER-001 | reuse | verified | not-applicable | not-applicable |',
  '| ACT-001 | applicable | render | constructed module | visible module | src/render:70 | TR-REQ-001, TR-RENDER-001 | deferred-approved | missing |  | UNIT-007 |'
)
$deferredDecisionResult = Invoke-ActivationSliceArtifactValidator $deferredDecisionSlice
Assert-True ($deferredDecisionResult.ExitCode -eq 1) "Deferred seam without Decision Reference should block. Output: $($deferredDecisionResult.Output)"
Assert-Contains $deferredDecisionResult.Output 'deferred-approved seam render requires Decision Reference' 'Deferred seam Decision Reference dependency'

$deferredUnitSlice = $completeActivationSlice.Replace(
  '| ACT-001 | applicable | render | constructed module | visible module | src/render:70 | TR-REQ-001, TR-RENDER-001 | reuse | verified | not-applicable | not-applicable |',
  '| ACT-001 | applicable | render | constructed module | visible module | src/render:70 | TR-REQ-001, TR-RENDER-001 | deferred-approved | missing | ADR-007 |  |'
)
$deferredUnitResult = Invoke-ActivationSliceArtifactValidator $deferredUnitSlice
Assert-True ($deferredUnitResult.ExitCode -eq 1) "Deferred seam without Deferred Unit ID should block. Output: $($deferredUnitResult.Output)"
Assert-Contains $deferredUnitResult.Output 'deferred-approved seam render requires Deferred Unit ID' 'Deferred seam unit dependency'

function Add-ActivationHandoffFixtureRole([string]$Text, [string]$StepId) {
  return $Text.Replace('step_id: 01-validate-inputs', "step_id: $StepId")
}
$handoffPredecessorActivationSlice = Add-ActivationHandoffFixtureRole $completeActivationSlice '02-discovery'

$changedIdSlice = Add-ActivationHandoffFixtureRole $completeActivationSlice.Replace('ACT-001', 'ACT-002') '03-analyze-requirements-uiux'
$changedIdResult = Invoke-ActivationSliceArtifactValidator $changedIdSlice $handoffPredecessorActivationSlice
Assert-True ($changedIdResult.ExitCode -eq 1) "Successor with changed Activation Slice ID should block. Output: $($changedIdResult.Output)"
Assert-Contains $changedIdResult.Output 'handoff changed Activation Slice ID from ACT-001 to ACT-002' 'Activation Slice handoff identity'

$narrowedSuccessorSlice = Add-ActivationHandoffFixtureRole ([regex]::Replace(
  $completeActivationSlice,
  '(?m)^\| ACT-001 \| applicable \| render \|.*\r?\n?',
  ''
)) '03-analyze-requirements-uiux'
$narrowedSuccessorResult = Invoke-ActivationSliceArtifactValidator $narrowedSuccessorSlice $handoffPredecessorActivationSlice
Assert-True ($narrowedSuccessorResult.ExitCode -eq 1) "Successor that drops a seam should block. Output: $($narrowedSuccessorResult.Output)"
Assert-Contains $narrowedSuccessorResult.Output 'handoff changed canonical seam set' 'Activation Slice handoff seam identity'

$duplicateSectionSlice = $completeActivationSlice + [Environment]::NewLine + '## Activation Slice' + [Environment]::NewLine
$duplicateSectionResult = Invoke-ActivationSliceArtifactValidator $duplicateSectionSlice
Assert-True ($duplicateSectionResult.ExitCode -eq 1) "Duplicate Activation Slice section should block. Output: $($duplicateSectionResult.Output)"
Assert-Contains $duplicateSectionResult.Output 'canonical Activation Slice section must appear exactly once; found 2' 'Activation Slice section identity'

$invalidPairSlice = $completeActivationSlice.Replace(
  '| reuse | verified | not-applicable | not-applicable |',
  '| skip | complete | not-applicable | not-applicable |'
)
$invalidPairResult = Invoke-ActivationSliceArtifactValidator $invalidPairSlice
Assert-True ($invalidPairResult.ExitCode -eq 1) "Invalid disposition/status pair should block. Output: $($invalidPairResult.Output)"
Assert-Contains $invalidPairResult.Output 'invalid disposition/status pair: skip/complete' 'Activation Slice disposition/status pair'

$mixedCaseActivationScenarios = @(
  [pscustomobject]@{
    Name = 'mixed-case Activation Slice ID'
    Text = $completeActivationSlice.Replace(
      '| ACT-001 | applicable | requested-key |',
      '| act-001 | applicable | requested-key |'
    )
    Expected = 'invalid Activation Slice ID: act-001; expected ACT-[0-9]{3}'
  }
  [pscustomobject]@{
    Name = 'mixed-case applicability'
    Text = $completeActivationSlice.Replace(
      '| ACT-001 | applicable | requested-key |',
      '| ACT-001 | Applicable | requested-key |'
    )
    Expected = 'must use one canonical applicability value; found applicable, Applicable'
  }
  [pscustomobject]@{
    Name = 'mixed-case disposition'
    Text = $completeActivationSlice.Replace('| implement | verified |', '| Implement | verified |')
    Expected = 'invalid disposition/status pair: Implement/verified'
  }
  [pscustomobject]@{
    Name = 'mixed-case status'
    Text = $completeActivationSlice.Replace('| implement | verified |', '| implement | Verified |')
    Expected = 'invalid disposition/status pair: implement/Verified'
  }
)
foreach ($mixedCaseActivationScenario in $mixedCaseActivationScenarios) {
  $mixedCaseResult = Invoke-ActivationSliceArtifactValidator $mixedCaseActivationScenario.Text
  Assert-True ($mixedCaseResult.ExitCode -eq 1) "Activation Slice scenario should reject $($mixedCaseActivationScenario.Name). Output: $($mixedCaseResult.Output)"
  Assert-Contains $mixedCaseResult.Output $mixedCaseActivationScenario.Expected "Activation Slice $($mixedCaseActivationScenario.Name)"
}

$traceLossSuccessorSlice = Add-ActivationHandoffFixtureRole $completeActivationSlice.Replace(
  'TR-REQ-001, TR-RENDER-001',
  'TR-REQ-001'
) '03-analyze-requirements-uiux'
$traceLossResult = Invoke-ActivationSliceArtifactValidator $traceLossSuccessorSlice $handoffPredecessorActivationSlice
Assert-True ($traceLossResult.ExitCode -eq 1) "Successor that loses a predecessor trace ID should block. Output: $($traceLossResult.Output)"
Assert-Contains $traceLossResult.Output 'handoff seam render lost predecessor Trace IDs: TR-RENDER-001' 'Activation Slice handoff trace preservation'

$sourceEnrichedSuccessorSlice = Add-ActivationHandoffFixtureRole $completeActivationSlice.Replace(
  'src/render:70',
  'src/render:70; review-evidence=render-proof'
) '03-analyze-requirements-uiux'
$sourceEnrichedResult = Invoke-ActivationSliceArtifactValidator $sourceEnrichedSuccessorSlice $handoffPredecessorActivationSlice
Assert-True ($sourceEnrichedResult.ExitCode -eq 0) "Append-only Source Reference enrichment should pass. Output: $($sourceEnrichedResult.Output)"

$invalidSourceEnrichmentScenarios = @(
  [pscustomobject]@{
    Name = 'empty suffix'
    Text = Add-ActivationHandoffFixtureRole $completeActivationSlice.Replace('src/render:70', 'src/render:70;') '03-analyze-requirements-uiux'
  }
  [pscustomobject]@{
    Name = 'whitespace-only suffix'
    Text = Add-ActivationHandoffFixtureRole $completeActivationSlice.Replace('src/render:70', 'src/render:70;   ') '03-analyze-requirements-uiux'
  }
  [pscustomobject]@{
    Name = 'missing separator space'
    Text = Add-ActivationHandoffFixtureRole $completeActivationSlice.Replace('src/render:70', 'src/render:70;new evidence') '03-analyze-requirements-uiux'
  }
)
foreach ($invalidSourceEnrichmentScenario in $invalidSourceEnrichmentScenarios) {
  $invalidSourceEnrichmentResult = Invoke-ActivationSliceArtifactValidator $invalidSourceEnrichmentScenario.Text $handoffPredecessorActivationSlice
  Assert-True ($invalidSourceEnrichmentResult.ExitCode -eq 1) "Source Reference enrichment with $($invalidSourceEnrichmentScenario.Name) should block. Output: $($invalidSourceEnrichmentResult.Output)"
  Assert-Contains $invalidSourceEnrichmentResult.Output 'handoff seam render has invalid Source Reference enrichment after: src/render:70' "Source Reference enrichment: $($invalidSourceEnrichmentScenario.Name)"
}

$sourceReplacedSuccessorSlice = Add-ActivationHandoffFixtureRole $completeActivationSlice.Replace(
  'src/render:70',
  'review-evidence=render-proof'
) '03-analyze-requirements-uiux'
$sourceReplacedResult = Invoke-ActivationSliceArtifactValidator $sourceReplacedSuccessorSlice $handoffPredecessorActivationSlice
Assert-True ($sourceReplacedResult.ExitCode -eq 1) "Successor that replaces predecessor Source Reference evidence should block. Output: $($sourceReplacedResult.Output)"
Assert-Contains $sourceReplacedResult.Output 'handoff seam render lost predecessor Source Reference evidence: src/render:70' 'Activation Slice handoff Source Reference preservation'

$firstSliceRows = @(
  [regex]::Matches($completeActivationSlice, '(?m)^\| ACT-001 \|.*\|\s*$') |
    ForEach-Object { $_.Value }
)
$secondSliceRows = @(
  $firstSliceRows |
    ForEach-Object {
      $_.Replace('ACT-001', 'ACT-002').Replace('TR-REQ-001', 'TR-REQ-002').Replace('-001', '-002')
    }
)
$twoSliceActivationArtifact = $completeActivationSlice.TrimEnd() + [Environment]::NewLine + ($secondSliceRows -join [Environment]::NewLine) + [Environment]::NewLine
$twoSliceResult = Invoke-ActivationSliceArtifactValidator $twoSliceActivationArtifact
Assert-True ($twoSliceResult.ExitCode -eq 0) "Two independently complete Activation Slices should pass. Output: $($twoSliceResult.Output)"

$interleavedRows = [Collections.Generic.List[string]]::new()
for ($rowIndex = 0; $rowIndex -lt $firstSliceRows.Count; $rowIndex++) {
  $interleavedRows.Add($firstSliceRows[$rowIndex])
  $interleavedRows.Add($secondSliceRows[$rowIndex])
}
$firstSliceRowsText = $firstSliceRows -join "`n"
$interleavedTwoSliceArtifact = $completeActivationSlice.Replace(
  $firstSliceRowsText,
  ($interleavedRows -join [Environment]::NewLine)
)
Assert-True ($interleavedTwoSliceArtifact -ne $completeActivationSlice) 'Interleaved multi-slice fixture must replace the original table rows'
$interleavedTwoSliceResult = Invoke-ActivationSliceArtifactValidator $interleavedTwoSliceArtifact
Assert-True ($interleavedTwoSliceResult.ExitCode -eq 0) "Non-contiguous rows for two complete slices should pass. Output: $($interleavedTwoSliceResult.Output)"
$interleavedHandoffResult = Invoke-ActivationSliceArtifactValidator `
  (Add-ActivationHandoffFixtureRole $interleavedTwoSliceArtifact '03-analyze-requirements-uiux') `
  (Add-ActivationHandoffFixtureRole $twoSliceActivationArtifact '02-discovery')
Assert-True ($interleavedHandoffResult.ExitCode -eq 0) "A handoff may interleave rows without changing either slice. Output: $($interleavedHandoffResult.Output)"

$invalidSecondSlice = $twoSliceActivationArtifact.Replace(
  '| ACT-002 | applicable | render | constructed module | visible module | src/render:70 | TR-REQ-002, TR-RENDER-002 | reuse | verified | not-applicable | not-applicable |',
  '| ACT-002 | applicable | render | constructed module | visible module | src/render:70 | TR-REQ-002, TR-RENDER-002 | reuse | missing | not-applicable | not-applicable |'
)
$invalidSecondSliceResult = Invoke-ActivationSliceArtifactValidator $invalidSecondSlice
Assert-True ($invalidSecondSliceResult.ExitCode -eq 1) "One invalid slice among two parsed slices should block. Output: $($invalidSecondSliceResult.Output)"
Assert-Contains $invalidSecondSliceResult.Output 'slice ACT-002 applicable seam render is not verified: missing' 'Independent per-slice status validation'

$lostSecondSliceResult = Invoke-ActivationSliceArtifactValidator `
  (Add-ActivationHandoffFixtureRole $completeActivationSlice '03-analyze-requirements-uiux') `
  (Add-ActivationHandoffFixtureRole $twoSliceActivationArtifact '02-discovery')
Assert-True ($lostSecondSliceResult.ExitCode -eq 1) "A successor that loses one of two slices should block. Output: $($lostSecondSliceResult.Output)"
Assert-Contains $lostSecondSliceResult.Output 'handoff lost Activation Slice ID: ACT-002' 'Multi-slice handoff loss'

$changedSecondSliceId = $twoSliceActivationArtifact.Replace('ACT-002', 'ACT-003')
$changedSecondSliceIdResult = Invoke-ActivationSliceArtifactValidator `
  (Add-ActivationHandoffFixtureRole $changedSecondSliceId '03-analyze-requirements-uiux') `
  (Add-ActivationHandoffFixtureRole $twoSliceActivationArtifact '02-discovery')
Assert-True ($changedSecondSliceIdResult.ExitCode -eq 1) "A successor that changes one of two slice IDs should block. Output: $($changedSecondSliceIdResult.Output)"
Assert-Contains $changedSecondSliceIdResult.Output 'handoff lost Activation Slice ID: ACT-002' 'Multi-slice handoff changed ID removal'
Assert-Contains $changedSecondSliceIdResult.Output 'handoff added Activation Slice ID: ACT-003' 'Multi-slice handoff changed ID addition'

$secondSliceSeamLoss = [regex]::Replace(
  $twoSliceActivationArtifact,
  '(?m)^\| ACT-002 \| applicable \| render \|.*\r?\n?',
  ''
)
$secondSliceSeamLossResult = Invoke-ActivationSliceArtifactValidator `
  (Add-ActivationHandoffFixtureRole $secondSliceSeamLoss '03-analyze-requirements-uiux') `
  (Add-ActivationHandoffFixtureRole $twoSliceActivationArtifact '02-discovery')
Assert-True ($secondSliceSeamLossResult.ExitCode -eq 1) "A per-slice seam loss should block. Output: $($secondSliceSeamLossResult.Output)"
Assert-Contains $secondSliceSeamLossResult.Output 'handoff slice ACT-002 changed canonical seam set' 'Per-slice handoff seam loss'

$secondSliceTraceLoss = $twoSliceActivationArtifact.Replace(
  'TR-REQ-002, TR-RENDER-002',
  'TR-REQ-002'
)
$secondSliceTraceLossResult = Invoke-ActivationSliceArtifactValidator `
  (Add-ActivationHandoffFixtureRole $secondSliceTraceLoss '03-analyze-requirements-uiux') `
  (Add-ActivationHandoffFixtureRole $twoSliceActivationArtifact '02-discovery')
Assert-True ($secondSliceTraceLossResult.ExitCode -eq 1) "A per-slice trace loss should block. Output: $($secondSliceTraceLossResult.Output)"
Assert-Contains $secondSliceTraceLossResult.Output 'handoff slice ACT-002 seam render lost predecessor Trace IDs: TR-RENDER-002' 'Per-slice handoff trace loss'

$fullWidthActivationId = "ACT-$([char]0xFF11)$([char]0xFF12)$([char]0xFF13)"
$unicodeActivationIdSlice = $completeActivationSlice.Replace('ACT-001', $fullWidthActivationId)
$unicodeActivationIdResult = Invoke-ActivationSliceArtifactValidator $unicodeActivationIdSlice
Assert-True ($unicodeActivationIdResult.ExitCode -eq 1) "Activation Slice IDs with non-ASCII digits should block. Output: $($unicodeActivationIdResult.Output)"
Assert-Contains $unicodeActivationIdResult.Output "invalid Activation Slice ID: $fullWidthActivationId; expected ACT-[0-9]{3}" 'ASCII Activation Slice ID'

$notApplicableActivationSlice = @'
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
| ACT-001 | not-applicable-approved | upstream-response | not-applicable | not-applicable | decision/no-selector:1 | TR-REQ-001, TR-UP-001 | not-applicable-approved | verified | ADR-NA-001 | not-applicable |
| ACT-001 | not-applicable-approved | requested-key | not-applicable | not-applicable | decision/no-selector:1 | TR-REQ-001, TR-KEY-001 | not-applicable-approved | verified | ADR-NA-001 | not-applicable |
| ACT-001 | not-applicable-approved | parse-model | not-applicable | not-applicable | decision/no-selector:1 | TR-REQ-001, TR-PARSE-001 | not-applicable-approved | verified | ADR-NA-001 | not-applicable |
| ACT-001 | not-applicable-approved | state-holder | not-applicable | not-applicable | decision/no-selector:1 | TR-REQ-001, TR-STATE-001 | not-applicable-approved | verified | ADR-NA-001 | not-applicable |
| ACT-001 | not-applicable-approved | selector | not-applicable | not-applicable | decision/no-selector:1 | TR-REQ-001, TR-SELECT-001 | not-applicable-approved | verified | ADR-NA-001 | not-applicable |
| ACT-001 | not-applicable-approved | construct | not-applicable | not-applicable | decision/no-selector:1 | TR-REQ-001, TR-ROUTER-001 | not-applicable-approved | verified | ADR-NA-001 | not-applicable |
| ACT-001 | not-applicable-approved | render | not-applicable | not-applicable | decision/no-selector:1 | TR-REQ-001, TR-RENDER-001 | not-applicable-approved | verified | ADR-NA-001 | not-applicable |
| ACT-001 | not-applicable-approved | downstream-consumer | not-applicable | not-applicable | decision/no-selector:1 | TR-REQ-001, TR-CONSUME-001 | not-applicable-approved | verified | ADR-NA-001 | not-applicable |
| ACT-001 | not-applicable-approved | test | not-applicable | not-applicable | decision/no-selector:1 | TR-REQ-001, TR-LIFECYCLE-001 | not-applicable-approved | verified | ADR-NA-001 | not-applicable |
'@
$notApplicableResult = Invoke-ActivationSliceArtifactValidator $notApplicableActivationSlice
Assert-True ($notApplicableResult.ExitCode -eq 0) "A fully approved not-applicable Activation Slice should pass. Output: $($notApplicableResult.Output)"

$deferredActivationSlice = $completeActivationSlice.Replace(
  '| ACT-001 | applicable | render | constructed module | visible module | src/render:70 | TR-REQ-001, TR-RENDER-001 | reuse | verified | not-applicable | not-applicable |',
  '| ACT-001 | applicable | render | constructed module | visible module | src/render:70 | TR-REQ-001, TR-RENDER-001 | deferred-approved | verified | ADR-007 | UNIT-007 |'
)
$deferredActivationResult = Invoke-ActivationSliceArtifactValidator $deferredActivationSlice
Assert-True ($deferredActivationResult.ExitCode -eq 0) "A deferred-approved seam with complete evidence should pass. Output: $($deferredActivationResult.Output)"

$unknownActivationSlice = $notApplicableActivationSlice.Replace('status: approved', 'status: draft').Replace('result: complete', 'result: blocked').Replace('| ACT-001 | not-applicable-approved |', '| ACT-001 | unknown |').Replace('| not-applicable-approved | verified | ADR-NA-001 |', '| implement | unknown | not-applicable |')
$unknownActivationResult = Invoke-ActivationSliceArtifactValidator $unknownActivationSlice
Assert-True ($unknownActivationResult.ExitCode -eq 1) "Unknown applicability should remain activation-blocking. Output: $($unknownActivationResult.Output)"
Assert-Contains $unknownActivationResult.Output 'unknown applicability blocks the Activation Slice' 'Unknown applicability blocking behavior'
Assert-NotContains $unknownActivationResult.Output 'invalid applicability/disposition/status combination' 'Unknown applicability legal row shape'
Assert-NotContains $unknownActivationResult.Output 'activation-blocking errors require front matter' 'Unknown applicability truthful front matter'

$applicabilityReclassificationResult = Invoke-ActivationSliceArtifactValidator `
  (Add-ActivationHandoffFixtureRole $notApplicableActivationSlice '03-analyze-requirements-uiux') `
  $handoffPredecessorActivationSlice
Assert-True ($applicabilityReclassificationResult.ExitCode -eq 1) "A successor that reclassifies applicability should block. Output: $($applicabilityReclassificationResult.Output)"
Assert-Contains $applicabilityReclassificationResult.Output 'handoff slice ACT-001 changed Applicability from applicable to not-applicable-approved' 'Activation Slice applicability preservation'

$rowShapeScenarios = @(
  [pscustomobject]@{
    Name = 'blank Input'
    Text = $completeActivationSlice.Replace('| profile request | requested activation key |', '|  | requested activation key |')
    Expected = 'seam requested-key requires non-empty Input'
  }
  [pscustomobject]@{
    Name = 'blank Output'
    Text = $completeActivationSlice.Replace('| activation key | parsed model field |', '| activation key |  |')
    Expected = 'seam parse-model requires non-empty Output'
  }
  [pscustomobject]@{
    Name = 'blank Source Reference'
    Text = $completeActivationSlice.Replace('| parsed model field | activation state | src/state:40 |', '| parsed model field | activation state |  |')
    Expected = 'seam state-holder requires Source Reference'
  }
  [pscustomobject]@{
    Name = 'blank Trace IDs'
    Text = $completeActivationSlice.Replace('| src/consumer:80 | TR-REQ-001, TR-CONSUME-001 |', '| src/consumer:80 |  |')
    Expected = 'seam downstream-consumer requires Trace IDs'
  }
  [pscustomobject]@{
    Name = 'blank ordinary Decision Reference'
    Text = $completeActivationSlice.Replace('| implement | verified | not-applicable | not-applicable |', '| implement | verified |  | not-applicable |')
    Expected = 'ordinary seam requested-key requires Decision Reference sentinel not-applicable'
  }
  [pscustomobject]@{
    Name = 'non-sentinel ordinary Decision Reference'
    Text = $completeActivationSlice.Replace('| implement | verified | not-applicable | not-applicable |', '| implement | verified | ADR-UNEXPECTED | not-applicable |')
    Expected = 'ordinary seam requested-key requires Decision Reference sentinel not-applicable'
  }
  [pscustomobject]@{
    Name = 'blank ordinary Deferred Unit ID'
    Text = $completeActivationSlice.Replace('| implement | verified | not-applicable | not-applicable |', '| implement | verified | not-applicable |  |')
    Expected = 'ordinary seam requested-key requires Deferred Unit ID sentinel not-applicable'
  }
  [pscustomobject]@{
    Name = 'non-sentinel ordinary Deferred Unit ID'
    Text = $completeActivationSlice.Replace('| implement | verified | not-applicable | not-applicable |', '| implement | verified | not-applicable | UNIT-999 |')
    Expected = 'ordinary seam requested-key requires Deferred Unit ID sentinel not-applicable'
  }
  [pscustomobject]@{
    Name = 'invalid deferred unit format'
    Text = $deferredActivationSlice.Replace('UNIT-007', 'UNIT-SEVEN')
    Expected = 'deferred-approved seam render requires Deferred Unit ID format UNIT-[0-9]{3}'
  }
  [pscustomobject]@{
    Name = 'non-ASCII deferred unit digits'
    Text = $deferredActivationSlice.Replace('UNIT-007', "UNIT-$([char]0xFF10)$([char]0xFF10)$([char]0xFF17)")
    Expected = 'deferred-approved seam render requires Deferred Unit ID format UNIT-[0-9]{3}'
  }
  [pscustomobject]@{
    Name = 'non-canonical not-applicable seam'
    Text = $notApplicableActivationSlice.Replace('| parse-model |', '| parse_model |')
    Expected = 'contains non-canonical seam: parse_model'
  }
  [pscustomobject]@{
    Name = 'not-applicable disposition mismatch'
    Text = $notApplicableActivationSlice.Replace('| not-applicable-approved | verified | ADR-NA-001 |', '| reuse | verified | ADR-NA-001 |')
    Expected = 'invalid applicability/disposition/status combination: not-applicable-approved/reuse/verified'
  }
  [pscustomobject]@{
    Name = 'not-applicable status mismatch'
    Text = $notApplicableActivationSlice.Replace('| not-applicable-approved | verified | ADR-NA-001 |', '| not-applicable-approved | unknown | ADR-NA-001 |')
    Expected = 'invalid applicability/disposition/status combination: not-applicable-approved/not-applicable-approved/unknown'
  }
  [pscustomobject]@{
    Name = 'not-applicable approval sentinel'
    Text = $notApplicableActivationSlice.Replace('| ADR-NA-001 | not-applicable |', '| not-applicable | not-applicable |')
    Expected = 'not-applicable-approved seam upstream-response requires Decision Reference'
  }
  [pscustomobject]@{
    Name = 'not-applicable deferred-unit mismatch'
    Text = $notApplicableActivationSlice.Replace('| ADR-NA-001 | not-applicable |', '| ADR-NA-001 | UNIT-001 |')
    Expected = 'not-applicable-approved seam upstream-response requires Deferred Unit ID sentinel not-applicable'
  }
  [pscustomobject]@{
    Name = 'applicable disposition mismatch'
    Text = $completeActivationSlice.Replace('| reuse | verified | not-applicable | not-applicable |', '| not-applicable-approved | verified | ADR-001 | not-applicable |')
    Expected = 'invalid applicability/disposition/status combination: applicable/not-applicable-approved/verified'
  }
  [pscustomobject]@{
    Name = 'unknown disposition mismatch'
    Text = $unknownActivationSlice.Replace('| implement | unknown | not-applicable | not-applicable |', '| deferred-approved | unknown | ADR-001 | UNIT-001 |')
    Expected = 'invalid applicability/disposition/status combination: unknown/deferred-approved/unknown'
  }
  [pscustomobject]@{
    Name = 'unknown status mismatch'
    Text = $unknownActivationSlice.Replace('| implement | unknown | not-applicable | not-applicable |', '| implement | verified | not-applicable | not-applicable |')
    Expected = 'invalid applicability/disposition/status combination: unknown/implement/verified'
  }
)
foreach ($rowShapeScenario in $rowShapeScenarios) {
  $rowShapeResult = Invoke-ActivationSliceArtifactValidator $rowShapeScenario.Text
  Assert-True ($rowShapeResult.ExitCode -eq 1) "Activation Slice row shape should block: $($rowShapeScenario.Name). Output: $($rowShapeResult.Output)"
  Assert-Contains $rowShapeResult.Output $rowShapeScenario.Expected "Activation Slice row shape: $($rowShapeScenario.Name)"
}

$draftCompleteActivationSlice = $completeActivationSlice.Replace('status: approved', 'status: draft')
$draftCompleteResult = Invoke-ActivationSliceArtifactValidator $draftCompleteActivationSlice
Assert-True ($draftCompleteResult.ExitCode -eq 0) "A complete Activation Slice may remain draft before approval. Output: $($draftCompleteResult.Output)"

$falseBlockedCompleteSlice = $completeActivationSlice.Replace('status: approved', 'status: draft').Replace('result: complete', 'result: blocked')
$falseBlockedCompleteResult = Invoke-ActivationSliceArtifactValidator $falseBlockedCompleteSlice
Assert-True ($falseBlockedCompleteResult.ExitCode -eq 1) "A complete Activation Slice must not claim blocked lifecycle metadata. Output: $($falseBlockedCompleteResult.Output)"
Assert-Contains $falseBlockedCompleteResult.Output 'complete Activation Slice requires front matter draft/complete or approved/complete' 'Complete Activation Slice front matter'

$blockingSliceBody = [regex]::Replace($completeActivationSlice, '(?m)^\| ACT-001 \| applicable \| parse-model \|.*\r?\n?', '')
$truthfulBlockedSlice = $blockingSliceBody.Replace('status: approved', 'status: draft').Replace('result: complete', 'result: blocked')
$truthfulBlockedResult = Invoke-ActivationSliceArtifactValidator $truthfulBlockedSlice
Assert-True ($truthfulBlockedResult.ExitCode -eq 1) "A truthfully blocked Activation Slice still blocks the gate. Output: $($truthfulBlockedResult.Output)"
Assert-NotContains $truthfulBlockedResult.Output 'activation-blocking errors require front matter' 'Truthful blocked Activation Slice front matter'

$blockingFrontMatterScenarios = @(
  [pscustomobject]@{ Name = 'approved status'; Text = $truthfulBlockedSlice.Replace('status: draft', 'status: approved'); Found = 'status: approved, result: blocked' }
  [pscustomobject]@{ Name = 'complete result'; Text = $truthfulBlockedSlice.Replace('result: blocked', 'result: complete'); Found = 'status: draft, result: complete' }
  [pscustomobject]@{ Name = 'partial result'; Text = $truthfulBlockedSlice.Replace('result: blocked', 'result: partial'); Found = 'status: draft, result: partial' }
)
foreach ($blockingFrontMatterScenario in $blockingFrontMatterScenarios) {
  $blockingFrontMatterResult = Invoke-ActivationSliceArtifactValidator $blockingFrontMatterScenario.Text
  Assert-True ($blockingFrontMatterResult.ExitCode -eq 1) "Activation-blocking errors with $($blockingFrontMatterScenario.Name) should fail lifecycle validation. Output: $($blockingFrontMatterResult.Output)"
  Assert-Contains $blockingFrontMatterResult.Output "activation-blocking errors require front matter status: draft and result: blocked; found $($blockingFrontMatterScenario.Found)" "Activation-blocking front matter: $($blockingFrontMatterScenario.Name)"
}

$selectedMigrationUnitTable = @'
## Selected Migration Unit

| Migration Unit ID | Plan Reference | Approval Reference | Mode Constraint | Bootstrap Scope | Foundation Baseline ID | Foundation Baseline Reference | Foundation Baseline Approval Reference | Baseline Reference | Trace IDs |
|---|---|---|---|---|---|---|---|---|---|
| UNIT-001 | plan-001 | approval-001 | incremental/preserve-existing | not-required | not-applicable | not-applicable | not-applicable | regression-baseline-001 | TR-REQ-001 |
'@

$orderedMigrationUnitTable = @"
## $orderedUnitsSection

| Order | Migration Unit ID | Bootstrap Scope | Foundation Baseline ID | Foundation Approval Reference | Dependencies | Acceptance | Mode Constraint | Trace IDs | Delivery Change Boundary | Approval Reference | Approval Status |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | UNIT-001 | not-required | not-applicable | not-applicable | none | activation accepted | incremental/preserve-existing | TR-REQ-001 | one-unit-one-change | approval-001 | approved |
| 2 | UNIT-002 | not-required | not-applicable | not-applicable | UNIT-001 | follow-up accepted | incremental/preserve-existing | TR-REQ-002 | one-unit-one-change | approval-002 | approved |
"@

$greenfieldSelectedMigrationUnitTable = @'
## Selected Migration Unit

| Migration Unit ID | Plan Reference | Approval Reference | Mode Constraint | Bootstrap Scope | Foundation Baseline ID | Foundation Baseline Reference | Foundation Baseline Approval Reference | Baseline Reference | Trace IDs |
|---|---|---|---|---|---|---|---|---|---|
| UNIT-001 | plan-001 | approval-001 | greenfield/design-new | required | FOUNDATION-001 | target-baseline-001 | bootstrap-approved-001 | not-applicable | TR-REQ-001 |
'@

$greenfieldOrderedMigrationUnitTable = @"
## $orderedUnitsSection

| Order | Migration Unit ID | Bootstrap Scope | Foundation Baseline ID | Foundation Approval Reference | Dependencies | Acceptance | Mode Constraint | Trace IDs | Delivery Change Boundary | Approval Reference | Approval Status |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | UNIT-001 | required | pending-bootstrap | pending-step09-approval | none | activation accepted | greenfield/design-new | TR-REQ-001 | one-unit-one-change | approval-001 | approved |
"@

$foundationRecordSection = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('QuG6o24gZ2hpIGJhc2VsaW5lIG7hu4FuIHThuqNuZw=='))
$approvedFoundationRecord = @"
## $foundationRecordSection

| Foundation Baseline ID | Source Migration Unit ID | Target Baseline Reference | Approval Reference | Approval Status | Evidence |
|---|---|---|---|---|---|
| FOUNDATION-001 | UNIT-001 | target-baseline-001 | bootstrap-approved-001 | approved | bootstrap-evidence-001 |
"@

$changedFilesHeading = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('IyMgRmlsZSDEkcOjIHRoYXkgxJHhu5Vp'))
$implementationActivationArtifact = $completeActivationSlice.Replace(
  'step_id: 01-validate-inputs',
  'step_id: 10-code-migration'
).TrimEnd() + @"


$selectedMigrationUnitTable

$changedFilesHeading

| Migration Unit ID | Activation Slice ID | Seam | File | Change | Trace IDs |
|---|---|---|---|---|---|
| UNIT-001 | ACT-001 | render | target/render.dart | render the selected module | TR-REQ-001, TR-RENDER-001 |

## Activation Slice Test Evidence

| Migration Unit ID | Activation Slice ID | Seam | Test | Command | Result | Trace IDs |
|---|---|---|---|---|---|---|
| UNIT-001 | ACT-001 | test | activation lifecycle | test activation | PASS | TR-REQ-001, TR-LIFECYCLE-001 |
"@
$approvedPlanActivationSlice = $completeActivationSlice.Replace(
  'step_id: 01-validate-inputs',
  'step_id: 08-plan-waves'
).TrimEnd() + "`n`n$orderedMigrationUnitTable"
$approvedGreenfieldPlanActivationSlice = $completeActivationSlice.Replace(
  'step_id: 01-validate-inputs',
  'step_id: 08-plan-waves'
).TrimEnd() + "`n`n$greenfieldOrderedMigrationUnitTable"
$approvedBootstrapActivationSlice = $completeActivationSlice.Replace(
  'step_id: 01-validate-inputs',
  'step_id: 09-bootstrap-target'
).TrimEnd() + "`n`n$greenfieldSelectedMigrationUnitTable`n`n$approvedFoundationRecord"
$greenfieldImplementationActivationArtifact = $implementationActivationArtifact.Replace(
  $selectedMigrationUnitTable,
  $greenfieldSelectedMigrationUnitTable
)
$implementationActivationResult = Invoke-ActivationSliceArtifactValidator $implementationActivationArtifact $approvedPlanActivationSlice
Assert-True ($implementationActivationResult.ExitCode -eq 0) "Structured implementation links should resolve against the approved predecessor. Output: $($implementationActivationResult.Output)"
$bootstrapImplementationActivationResult = Invoke-ActivationSliceArtifactValidator $greenfieldImplementationActivationArtifact $approvedBootstrapActivationSlice
Assert-True ($bootstrapImplementationActivationResult.ExitCode -eq 0) "Structured implementation links should accept an approved bootstrap predecessor. Output: $($bootstrapImplementationActivationResult.Output)"

$waivedLifecycleFrontMatter = "step_id: 10-code-migration`nstatus: approved`nresult: partial`napproval_source: auto-waive`nwaiver:`n  policy: auto-waive`n  category: environment-unavailable`n  original_verdict: blocked`n  effective_action: continue`n  evidence: capability-evidence-001"
$waiverEvidenceSections = "## $nativeBlockersSection`n`n" + @'
| Stage / Check | Native Verdict | Command Role | Required Command Lifecycle | Command / Capability | Observed Error | Evidence Reference |
|---|---|---|---|---|---|---|
| pre-mutation baseline | BLOCKED | availability probe | not-started | target-test capability | capability unavailable | capability-evidence-001 |

## Approved Baseline Waiver

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
$waivedStep10ActivationBase = $implementationActivationArtifact.Replace(
  "step_id: 10-code-migration`nstatus: approved`nresult: complete`napproval_source: human",
  $waivedLifecycleFrontMatter
).Replace(
  '| regression-baseline-001 | TR-REQ-001 |',
  '| capability-evidence-001 | TR-REQ-001 |'
).TrimEnd() + "`n`n$waiverEvidenceSections"
$waivedStep10ActivationPredecessorBase = ($completeActivationSlice.Replace(
  "step_id: 01-validate-inputs`nstatus: approved`nresult: complete`napproval_source: human",
  $waivedLifecycleFrontMatter
).TrimEnd() + "`n`n$selectedMigrationUnitTable").Replace(
  '| regression-baseline-001 | TR-REQ-001 |',
  '| capability-evidence-001 | TR-REQ-001 |'
).TrimEnd() + "`n`n$waiverEvidenceSections"
$waivedStep10ActivationArtifact = $waivedStep10ActivationBase.TrimEnd() + @'


## Step 10 Waiver Resume State

| Resume Phase | Baseline Action | Implementation Status | Target Mutation Evidence | Waiver Evidence |
|---|---|---|---|---|
| resume-consumed | skip-pre-mutation-baseline-only | implementation-complete | target/render.dart; UNIT-001; TR-REQ-001 | capability-evidence-001 |
'@
$waivedStep10ActivationPredecessorArtifact = $waivedStep10ActivationPredecessorBase.TrimEnd() + @'


## Step 10 Waiver Resume State

| Resume Phase | Baseline Action | Implementation Status | Target Mutation Evidence | Waiver Evidence |
|---|---|---|---|---|
| resume-required | skip-pre-mutation-baseline-only | blocked | none | capability-evidence-001 |
'@
Assert-True ($waivedStep10ActivationArtifact -ne $implementationActivationArtifact) 'Waiver-resume fixture must replace the ordinary step-10 lifecycle'

$validWaiverResumeResult = Invoke-ActivationSliceArtifactValidator $waivedStep10ActivationArtifact $waivedStep10ActivationPredecessorArtifact
Assert-True ($validWaiverResumeResult.ExitCode -eq 0) "A structurally valid step-10 approved/partial/auto-waive resume should pass. Output: $($validWaiverResumeResult.Output)"

$quotedLifecycleWaiverResume = $waivedStep10ActivationArtifact.Replace(
  "step_id: 10-code-migration`nstatus: approved`nresult: partial`napproval_source: auto-waive`nwaiver:",
  @'
'step_id' : '10-code-migration'
"status" : "approved"
'result': 'partial'
"approval_source": "auto-waive"
"waiver" :
'@
)
$quotedLifecycleWaiverPredecessor = $waivedStep10ActivationPredecessorArtifact.Replace(
  "step_id: 10-code-migration`nstatus: approved`nresult: partial`napproval_source: auto-waive`nwaiver:",
  @'
'step_id' : '10-code-migration'
"status" : "approved"
'result': 'partial'
"approval_source": "auto-waive"
"waiver" :
'@
)
$quotedLifecycleWaiverResult = Invoke-ActivationSliceArtifactValidator $quotedLifecycleWaiverResume $quotedLifecycleWaiverPredecessor
Assert-True ($quotedLifecycleWaiverResult.ExitCode -eq 0) "Canonical quoted lifecycle and waiver keys/scalars should pass. Output: $($quotedLifecycleWaiverResult.Output)"

$semanticTopLevelDuplicateScenarios = @(
  [pscustomobject]@{ Name = 'quoted status duplicate'; Addition = '"status": draft'; Expected = 'front matter must contain exactly one status' }
  [pscustomobject]@{ Name = 'quoted result duplicate'; Addition = "'result': blocked"; Expected = 'front matter must contain exactly one result' }
  [pscustomobject]@{ Name = 'Unicode-escaped status duplicate'; Addition = '"st\u0061tus": draft'; Expected = 'front matter must contain exactly one status' }
  [pscustomobject]@{ Name = 'Unicode-escaped result duplicate'; Addition = '"res\u0075lt": blocked'; Expected = 'front matter must contain exactly one result' }
  [pscustomobject]@{ Name = 'Unicode-escaped waiver duplicate'; Addition = '"wai\u0076er": {}'; Expected = 'baseline-waiver resume requires exactly one waiver mapping; found 2' }
)
foreach ($semanticTopLevelDuplicateScenario in $semanticTopLevelDuplicateScenarios) {
  $semanticTopLevelDuplicate = $waivedStep10ActivationArtifact.Replace(
    'status: approved',
    "status: approved`n$($semanticTopLevelDuplicateScenario.Addition)"
  )
  $semanticTopLevelDuplicateResult = Invoke-ActivationSliceArtifactValidator $semanticTopLevelDuplicate $waivedStep10ActivationPredecessorArtifact
  Assert-True ($semanticTopLevelDuplicateResult.ExitCode -eq 1) "Semantic top-level duplicate should block: $($semanticTopLevelDuplicateScenario.Name). Output: $($semanticTopLevelDuplicateResult.Output)"
  Assert-Contains $semanticTopLevelDuplicateResult.Output $semanticTopLevelDuplicateScenario.Expected "Semantic top-level duplicate: $($semanticTopLevelDuplicateScenario.Name)"
}

$ambiguousTopLevelFrontMatterScenarios = @(
  [pscustomobject]@{ Name = 'lifecycle comment'; From = 'status: approved'; To = 'status: approved # ambiguous comment' }
  [pscustomobject]@{ Name = 'lifecycle alias'; From = 'status: approved'; To = 'status: *approved' }
  [pscustomobject]@{ Name = 'lifecycle anchor'; From = 'status: approved'; To = 'status: &approved approved' }
  [pscustomobject]@{ Name = 'merge key'; From = 'status: approved'; To = "status: approved`n<<: *defaults" }
  [pscustomobject]@{ Name = 'flow lifecycle'; From = 'status: approved'; To = 'status: { value: approved }' }
  [pscustomobject]@{ Name = 'nested lifecycle'; From = 'status: approved'; To = "status:`n  value: approved" }
)
foreach ($ambiguousTopLevelFrontMatterScenario in $ambiguousTopLevelFrontMatterScenarios) {
  $ambiguousTopLevelFrontMatter = $waivedStep10ActivationArtifact.Replace(
    $ambiguousTopLevelFrontMatterScenario.From,
    $ambiguousTopLevelFrontMatterScenario.To
  )
  $ambiguousTopLevelFrontMatterResult = Invoke-ActivationSliceArtifactValidator $ambiguousTopLevelFrontMatter $waivedStep10ActivationPredecessorArtifact
  Assert-True ($ambiguousTopLevelFrontMatterResult.ExitCode -eq 1) "Ambiguous top-level front matter should block: $($ambiguousTopLevelFrontMatterScenario.Name). Output: $($ambiguousTopLevelFrontMatterResult.Output)"
  Assert-Contains $ambiguousTopLevelFrontMatterResult.Output 'invalid or ambiguous YAML front matter' "Ambiguous top-level front matter: $($ambiguousTopLevelFrontMatterScenario.Name)"
}

$activationInvalidWaiverResume = [regex]::Replace(
  $waivedStep10ActivationArtifact,
  '(?m)^\| ACT-001 \| applicable \| parse-model \|.*\r?\n?',
  ''
)
$activationInvalidWaiverResumeResult = Invoke-ActivationSliceArtifactValidator $activationInvalidWaiverResume $waivedStep10ActivationPredecessorArtifact
Assert-True ($activationInvalidWaiverResumeResult.ExitCode -eq 1) "Activation-invalid waiver resume should block. Output: $($activationInvalidWaiverResumeResult.Output)"
Assert-Contains $activationInvalidWaiverResumeResult.Output 'activation-blocking errors require front matter status: draft and result: blocked' 'Activation errors override waiver-resume lifecycle'

$inexactCurrentWaiverResume = $waivedStep10ActivationArtifact.Replace(
  '  category: environment-unavailable',
  '  category: correctness-failure'
)
$inexactCurrentWaiverResumeResult = Invoke-ActivationSliceArtifactValidator $inexactCurrentWaiverResume $waivedStep10ActivationPredecessorArtifact
Assert-True ($inexactCurrentWaiverResumeResult.ExitCode -eq 1) "A partial step-10 artifact without the exact baseline waiver should block. Output: $($inexactCurrentWaiverResumeResult.Output)"
Assert-Contains $inexactCurrentWaiverResumeResult.Output 'step-10 baseline-waiver resume requires exact approved/partial/auto-waive waiver tuple' 'Current waiver-resume tuple'

$ordinaryStep10PredecessorResult = Invoke-ActivationSliceArtifactValidator $waivedStep10ActivationArtifact $implementationActivationArtifact
Assert-True ($ordinaryStep10PredecessorResult.ExitCode -eq 1) "A waiver resume whose prior step 10 lacks the exact tuple should block. Output: $($ordinaryStep10PredecessorResult.Output)"
Assert-Contains $ordinaryStep10PredecessorResult.Output 'baseline-waiver resume predecessor requires exact approved/partial/auto-waive waiver tuple' 'Predecessor waiver-resume tuple'

$changedEnvelopeWaiverResume = $waivedStep10ActivationArtifact.Replace(
  'src/render:70',
  'resumed/render:70'
)
$changedEnvelopeWaiverResumeResult = Invoke-ActivationSliceArtifactValidator $changedEnvelopeWaiverResume $waivedStep10ActivationPredecessorArtifact
Assert-True ($changedEnvelopeWaiverResumeResult.ExitCode -eq 1) "A waiver resume that changes its prior Activation Slice envelope should block. Output: $($changedEnvelopeWaiverResumeResult.Output)"
Assert-Contains $changedEnvelopeWaiverResumeResult.Output 'handoff seam render lost predecessor Source Reference evidence: src/render:70' 'Waiver-resume envelope preservation'
Assert-Contains $changedEnvelopeWaiverResumeResult.Output 'activation-blocking errors require front matter status: draft and result: blocked' 'Waiver-resume handoff error lifecycle'

$nonStep10WaiverResumeResult = Invoke-ActivationSliceArtifactValidator $waivedStep10ActivationArtifact $approvedPlanActivationSlice
Assert-True ($nonStep10WaiverResumeResult.ExitCode -eq 1) "A non-step-10 predecessor must not enter the waiver-resume path. Output: $($nonStep10WaiverResumeResult.Output)"
Assert-Contains $nonStep10WaiverResumeResult.Output 'baseline-waiver resume requires predecessor step_id: 10-code-migration' 'Waiver-resume predecessor role'

$changedWaiverEvidenceResume = $waivedStep10ActivationArtifact.Replace(
  'evidence: capability-evidence-001',
  'evidence: capability-evidence-002'
)
$changedWaiverEvidenceResumeResult = Invoke-ActivationSliceArtifactValidator $changedWaiverEvidenceResume $waivedStep10ActivationPredecessorArtifact
Assert-True ($changedWaiverEvidenceResumeResult.ExitCode -eq 1) "A resumed step 10 that changes approved waiver evidence should block. Output: $($changedWaiverEvidenceResumeResult.Output)"
Assert-Contains $changedWaiverEvidenceResumeResult.Output 'baseline-waiver resume must preserve predecessor waiver fields verbatim' 'Waiver-resume verbatim preservation'

$exactWaiverBlock = "waiver:`n  policy: auto-waive`n  category: environment-unavailable`n  original_verdict: blocked`n  effective_action: continue`n  evidence: capability-evidence-001"
$duplicateWaiverResume = $waivedStep10ActivationArtifact.Replace(
  $exactWaiverBlock,
  "$exactWaiverBlock`n$exactWaiverBlock"
)
Assert-True ($duplicateWaiverResume -ne $waivedStep10ActivationArtifact) 'Duplicate-waiver fixture must add a second waiver mapping'
$duplicateWaiverResumeResult = Invoke-ActivationSliceArtifactValidator $duplicateWaiverResume $waivedStep10ActivationPredecessorArtifact
Assert-True ($duplicateWaiverResumeResult.ExitCode -eq 1) "A resumed step 10 with duplicate waiver mappings should block. Output: $($duplicateWaiverResumeResult.Output)"
Assert-Contains $duplicateWaiverResumeResult.Output 'step-10 baseline-waiver resume requires exactly one waiver mapping; found 2' 'Duplicate waiver mapping'

$mixedDuplicateWaiverResume = $waivedStep10ActivationArtifact.Replace(
  $exactWaiverBlock,
  "$exactWaiverBlock`nwaiver: {}"
)
$mixedDuplicateWaiverResumeResult = Invoke-ActivationSliceArtifactValidator $mixedDuplicateWaiverResume $waivedStep10ActivationPredecessorArtifact
Assert-True ($mixedDuplicateWaiverResumeResult.ExitCode -eq 1) "A resumed step 10 with canonical and inline waiver keys should block. Output: $($mixedDuplicateWaiverResumeResult.Output)"
Assert-Contains $mixedDuplicateWaiverResumeResult.Output 'step-10 baseline-waiver resume requires exactly one waiver mapping; found 2' 'Mixed duplicate waiver mapping'

$inlineWaiverResume = $waivedStep10ActivationArtifact.Replace($exactWaiverBlock, 'waiver: {}')
$inlineWaiverResumeResult = Invoke-ActivationSliceArtifactValidator $inlineWaiverResume $waivedStep10ActivationPredecessorArtifact
Assert-True ($inlineWaiverResumeResult.ExitCode -eq 1) "A resumed step 10 with a sole inline waiver value should block. Output: $($inlineWaiverResumeResult.Output)"
Assert-Contains $inlineWaiverResumeResult.Output 'step-10 baseline-waiver resume requires exact approved/partial/auto-waive waiver tuple' 'Inline waiver resume mapping'

$completeStep10WithWaiver = $implementationActivationArtifact.Replace(
  "step_id: 10-code-migration`nstatus: approved`nresult: complete`napproval_source: human",
  "step_id: 10-code-migration`nstatus: approved`nresult: complete`napproval_source: auto-waive`n$exactWaiverBlock"
)
$completeStep10WithWaiverResult = Invoke-ActivationSliceArtifactValidator $completeStep10WithWaiver $approvedPlanActivationSlice
Assert-True ($completeStep10WithWaiverResult.ExitCode -eq 1) "An ordinary complete step-10 artifact carrying a waiver should block. Output: $($completeStep10WithWaiverResult.Output)"
Assert-Contains $completeStep10WithWaiverResult.Output 'waiver mapping is valid only for the exact step-10 approved/partial/auto-waive resume lifecycle' 'Complete artifact carrying waiver'

$completeStep10WithInlineWaiver = $implementationActivationArtifact.Replace(
  'result: complete',
  "result: complete`nwaiver: {}"
)
$completeStep10WithInlineWaiverResult = Invoke-ActivationSliceArtifactValidator $completeStep10WithInlineWaiver $approvedPlanActivationSlice
Assert-True ($completeStep10WithInlineWaiverResult.ExitCode -eq 1) "An ordinary complete step-10 artifact carrying an inline waiver key should block. Output: $($completeStep10WithInlineWaiverResult.Output)"
Assert-Contains $completeStep10WithInlineWaiverResult.Output 'waiver mapping is valid only for the exact step-10 approved/partial/auto-waive resume lifecycle' 'Complete artifact carrying inline waiver'

$blockWaiverEvidence = $waivedStep10ActivationArtifact.Replace(
  '  evidence: capability-evidence-001',
  "  evidence: |-`n    capability-evidence-001"
)
$blockWaiverEvidencePredecessor = $waivedStep10ActivationPredecessorArtifact.Replace(
  '  evidence: capability-evidence-001',
  "  evidence: |-`n    capability-evidence-001"
)
$blockWaiverEvidenceResult = Invoke-ActivationSliceArtifactValidator $blockWaiverEvidence $blockWaiverEvidencePredecessor
Assert-True ($blockWaiverEvidenceResult.ExitCode -eq 0) "A literal block scalar with the same decoded waiver evidence should pass. Output: $($blockWaiverEvidenceResult.Output)"

$changedBlockWaiverEvidence = $blockWaiverEvidence.Replace('capability-evidence-001', 'capability-evidence-002')
$changedBlockWaiverEvidenceResult = Invoke-ActivationSliceArtifactValidator $changedBlockWaiverEvidence $blockWaiverEvidencePredecessor
Assert-True ($changedBlockWaiverEvidenceResult.ExitCode -eq 1) "Different literal block scalar bodies must not compare as the same waiver evidence. Output: $($changedBlockWaiverEvidenceResult.Output)"
Assert-Contains $changedBlockWaiverEvidenceResult.Output 'baseline-waiver resume must preserve predecessor waiver fields verbatim' 'Decoded block waiver evidence preservation'

$emptySemanticWaiverEvidenceCases = @(
  [pscustomobject]@{ Name = 'plain null'; Scalar = 'null' }
  [pscustomobject]@{ Name = 'tilde null'; Scalar = '~' }
  [pscustomobject]@{ Name = 'single-quoted empty'; Scalar = "''" }
  [pscustomobject]@{ Name = 'double-quoted empty'; Scalar = '""' }
)
foreach ($emptySemanticWaiverEvidenceCase in $emptySemanticWaiverEvidenceCases) {
  $emptySemanticWaiverEvidence = $waivedStep10ActivationArtifact.Replace(
    'evidence: capability-evidence-001',
    "evidence: $($emptySemanticWaiverEvidenceCase.Scalar)"
  )
  $emptySemanticWaiverEvidenceResult = Invoke-ActivationSliceArtifactValidator $emptySemanticWaiverEvidence $emptySemanticWaiverEvidence
  Assert-True ($emptySemanticWaiverEvidenceResult.ExitCode -eq 1) "Semantically empty waiver evidence should block: $($emptySemanticWaiverEvidenceCase.Name). Output: $($emptySemanticWaiverEvidenceResult.Output)"
  Assert-Contains $emptySemanticWaiverEvidenceResult.Output 'step-10 baseline-waiver resume requires exact approved/partial/auto-waive waiver tuple' "Semantically empty waiver evidence: $($emptySemanticWaiverEvidenceCase.Name)"
}

$unsupportedWaiverYamlCases = @(
  [pscustomobject]@{
    Name = 'flow mapping'
    Text = $waivedStep10ActivationArtifact.Replace(
      $exactWaiverBlock,
      'waiver: { policy: auto-waive, category: environment-unavailable, original_verdict: blocked, effective_action: continue, evidence: capability-evidence-001 }'
    )
  }
  [pscustomobject]@{
    Name = 'nested evidence mapping'
    Text = $waivedStep10ActivationArtifact.Replace(
      '  evidence: capability-evidence-001',
      "  evidence:`n    reference: capability-evidence-001"
    )
  }
  [pscustomobject]@{
    Name = 'quoted duplicate key'
    Text = $waivedStep10ActivationArtifact.Replace(
      '  evidence: capability-evidence-001',
      "  evidence: capability-evidence-001`n  'evidence': capability-evidence-002"
    )
  }
  [pscustomobject]@{
    Name = 'spaced duplicate key'
    Text = $waivedStep10ActivationArtifact.Replace(
      '  evidence: capability-evidence-001',
      "  evidence: capability-evidence-001`n  evidence : capability-evidence-002"
    )
  }
  [pscustomobject]@{
    Name = 'alias evidence'
    Text = $waivedStep10ActivationArtifact.Replace(
      '  evidence: capability-evidence-001',
      '  evidence: *waiverEvidence'
    )
  }
  [pscustomobject]@{
    Name = 'merge key'
    Text = $waivedStep10ActivationArtifact.Replace(
      '  evidence: capability-evidence-001',
      "  evidence: capability-evidence-001`n  <<: *waiverDefaults"
    )
  }
)
foreach ($unsupportedWaiverYamlCase in $unsupportedWaiverYamlCases) {
  $unsupportedWaiverYamlResult = Invoke-ActivationSliceArtifactValidator $unsupportedWaiverYamlCase.Text $unsupportedWaiverYamlCase.Text
  Assert-True ($unsupportedWaiverYamlResult.ExitCode -eq 1) "Unsupported or ambiguous waiver YAML should fail closed: $($unsupportedWaiverYamlCase.Name). Output: $($unsupportedWaiverYamlResult.Output)"
  Assert-Contains $unsupportedWaiverYamlResult.Output 'step-10 baseline-waiver resume requires exact approved/partial/auto-waive waiver tuple' "Unsupported waiver YAML: $($unsupportedWaiverYamlCase.Name)"
}

$implementationLinkScenarios = @(
  [pscustomobject]@{
    Name = 'changed file unknown slice'
    Text = $implementationActivationArtifact.Replace('| UNIT-001 | ACT-001 | render | target/render.dart |', '| UNIT-001 | ACT-999 | render | target/render.dart |')
    Expected = 'changed-file link references unknown approved Activation Slice ID: ACT-999'
  }
  [pscustomobject]@{
    Name = 'changed file unknown seam'
    Text = $implementationActivationArtifact.Replace('| UNIT-001 | ACT-001 | render | target/render.dart |', '| UNIT-001 | ACT-001 | rendering | target/render.dart |')
    Expected = 'changed-file link ACT-001 references unknown approved seam: rendering'
  }
  [pscustomobject]@{
    Name = 'changed file unrelated trace'
    Text = $implementationActivationArtifact.Replace(
      '| UNIT-001 | ACT-001 | render | target/render.dart | render the selected module | TR-REQ-001, TR-RENDER-001 |',
      '| UNIT-001 | ACT-001 | render | target/render.dart | render the selected module | TR-REQ-001, TR-OTHER-001 |'
    )
    Expected = 'changed-file link ACT-001/render has unapproved Trace IDs: TR-OTHER-001'
  }
  [pscustomobject]@{
    Name = 'test evidence unknown slice'
    Text = $implementationActivationArtifact.Replace('| UNIT-001 | ACT-001 | test | activation lifecycle |', '| UNIT-001 | ACT-999 | test | activation lifecycle |')
    Expected = 'test-evidence link references unknown approved Activation Slice ID: ACT-999'
  }
  [pscustomobject]@{
    Name = 'test evidence unknown seam'
    Text = $implementationActivationArtifact.Replace('| UNIT-001 | ACT-001 | test | activation lifecycle |', '| UNIT-001 | ACT-001 | tests | activation lifecycle |')
    Expected = 'test-evidence link ACT-001 references unknown approved seam: tests'
  }
  [pscustomobject]@{
    Name = 'test evidence unrelated trace'
    Text = $implementationActivationArtifact.Replace(
      '| UNIT-001 | ACT-001 | test | activation lifecycle | test activation | PASS | TR-REQ-001, TR-LIFECYCLE-001 |',
      '| UNIT-001 | ACT-001 | test | activation lifecycle | test activation | PASS | TR-REQ-001, TR-OTHER-001 |'
    )
    Expected = 'test-evidence link ACT-001/test has unapproved Trace IDs: TR-OTHER-001'
  }
)
foreach ($implementationLinkScenario in $implementationLinkScenarios) {
  $implementationLinkResult = Invoke-ActivationSliceArtifactValidator $implementationLinkScenario.Text $approvedPlanActivationSlice
  Assert-True ($implementationLinkResult.ExitCode -eq 1) "Implementation linkage should block: $($implementationLinkScenario.Name). Output: $($implementationLinkResult.Output)"
  Assert-Contains $implementationLinkResult.Output $implementationLinkScenario.Expected "Implementation linkage: $($implementationLinkScenario.Name)"
}

$truthfulBlockedHandoff = $implementationActivationArtifact.Replace(
  'status: approved`nresult: complete'.Replace('`n', "`n"),
  'status: draft`nresult: blocked'.Replace('`n', "`n")
).Replace('src/render:70', 'replacement/render:70')
$truthfulBlockedHandoffResult = Invoke-ActivationSliceArtifactValidator $truthfulBlockedHandoff $approvedPlanActivationSlice
Assert-True ($truthfulBlockedHandoffResult.ExitCode -eq 1) "A truthful draft/blocked implementation artifact should retain the handoff failure without a lifecycle contradiction. Output: $($truthfulBlockedHandoffResult.Output)"
Assert-Contains $truthfulBlockedHandoffResult.Output 'handoff seam render lost predecessor Source Reference evidence: src/render:70' 'Truthful blocked handoff error'
Assert-NotContains $truthfulBlockedHandoffResult.Output 'complete Activation Slice requires front matter' 'Truthful blocked handoff lifecycle'

$truthfulBlockedInitialLink = $implementationActivationArtifact.Replace(
  'status: approved`nresult: complete'.Replace('`n', "`n"),
  'status: draft`nresult: blocked'.Replace('`n', "`n")
).Replace('| UNIT-001 | ACT-001 | render | target/render.dart |', '| UNIT-001 | ACT-001 | rendering | target/render.dart |')
$truthfulBlockedInitialLinkResult = Invoke-ActivationSliceArtifactValidator $truthfulBlockedInitialLink $approvedPlanActivationSlice
Assert-True ($truthfulBlockedInitialLinkResult.ExitCode -eq 1) "A truthful draft/blocked initial step-10 link failure should not contradict its lifecycle. Output: $($truthfulBlockedInitialLinkResult.Output)"
Assert-Contains $truthfulBlockedInitialLinkResult.Output 'changed-file link ACT-001 references unknown approved seam: rendering' 'Truthful blocked initial link error'
Assert-NotContains $truthfulBlockedInitialLinkResult.Output 'complete Activation Slice requires front matter' 'Truthful blocked initial link lifecycle'

$truthfulBlockedResumeLink = $implementationActivationArtifact.Replace(
  'status: approved`nresult: complete'.Replace('`n', "`n"),
  'status: draft`nresult: blocked'.Replace('`n', "`n")
).Replace('| UNIT-001 | ACT-001 | render | target/render.dart |', '| UNIT-001 | ACT-001 | rendering | target/render.dart |')
$truthfulBlockedResumeLinkResult = Invoke-ActivationSliceArtifactValidator $truthfulBlockedResumeLink $waivedStep10ActivationPredecessorArtifact
Assert-True ($truthfulBlockedResumeLinkResult.ExitCode -eq 1) "A truthful blocked resume must select its predecessor role independently of the current result. Output: $($truthfulBlockedResumeLinkResult.Output)"
Assert-Contains $truthfulBlockedResumeLinkResult.Output 'changed-file link ACT-001 references unknown approved seam: rendering' 'Truthful blocked resume link error'
Assert-NotContains $truthfulBlockedResumeLinkResult.Output 'approved immediate predecessor step_id: 08-plan-waves or 09-bootstrap-target' 'Truthful blocked resume predecessor role'
Assert-NotContains $truthfulBlockedResumeLinkResult.Output 'complete Activation Slice requires front matter' 'Truthful blocked resume lifecycle'

$invalidApprovedPartialLink = $waivedStep10ActivationArtifact.Replace(
  '| UNIT-001 | ACT-001 | render | target/render.dart |',
  '| UNIT-001 | ACT-001 | rendering | target/render.dart |'
)
$invalidApprovedPartialLinkResult = Invoke-ActivationSliceArtifactValidator $invalidApprovedPartialLink $waivedStep10ActivationPredecessorArtifact
Assert-True ($invalidApprovedPartialLinkResult.ExitCode -eq 1) "An approved/partial resume with invalid structured linkage should block. Output: $($invalidApprovedPartialLinkResult.Output)"
Assert-Contains $invalidApprovedPartialLinkResult.Output 'changed-file link ACT-001 references unknown approved seam: rendering' 'Approved partial invalid link'
Assert-Contains $invalidApprovedPartialLinkResult.Output 'activation-blocking errors require front matter status: draft and result: blocked' 'Approved partial invalid link lifecycle'

$changedFileRecord = '| UNIT-001 | ACT-001 | render | target/render.dart | render the selected module | TR-REQ-001, TR-RENDER-001 |'
$testEvidenceRecord = '| UNIT-001 | ACT-001 | test | activation lifecycle | test activation | PASS | TR-REQ-001, TR-LIFECYCLE-001 |'
$blankStructuredRecordScenarios = @(
  [pscustomobject]@{
    Name = 'changed-file blank Migration Unit ID'
    Text = $implementationActivationArtifact.Replace($changedFileRecord, '|  | ACT-001 | render | target/render.dart | render the selected module | TR-REQ-001, TR-RENDER-001 |')
    Expected = 'changed-file record requires non-empty Migration Unit ID'
  }
  [pscustomobject]@{
    Name = 'changed-file blank Activation Slice ID'
    Text = $implementationActivationArtifact.Replace($changedFileRecord, '| UNIT-001 |  | render | target/render.dart | render the selected module | TR-REQ-001, TR-RENDER-001 |')
    Expected = 'changed-file record requires non-empty Activation Slice ID'
  }
  [pscustomobject]@{
    Name = 'changed-file blank Seam'
    Text = $implementationActivationArtifact.Replace($changedFileRecord, '| UNIT-001 | ACT-001 |  | target/render.dart | render the selected module | TR-REQ-001, TR-RENDER-001 |')
    Expected = 'changed-file record requires non-empty Seam'
  }
  [pscustomobject]@{
    Name = 'changed-file blank File'
    Text = $implementationActivationArtifact.Replace($changedFileRecord, '| UNIT-001 | ACT-001 | render |  | render the selected module | TR-REQ-001, TR-RENDER-001 |')
    Expected = 'changed-file record requires non-empty File'
  }
  [pscustomobject]@{
    Name = 'changed-file blank Change'
    Text = $implementationActivationArtifact.Replace($changedFileRecord, '| UNIT-001 | ACT-001 | render | target/render.dart |  | TR-REQ-001, TR-RENDER-001 |')
    Expected = 'changed-file record requires non-empty Change'
  }
  [pscustomobject]@{
    Name = 'changed-file blank Trace IDs'
    Text = $implementationActivationArtifact.Replace($changedFileRecord, '| UNIT-001 | ACT-001 | render | target/render.dart | render the selected module |  |')
    Expected = 'changed-file record requires non-empty Trace IDs'
  }
  [pscustomobject]@{
    Name = 'test-evidence blank Migration Unit ID'
    Text = $implementationActivationArtifact.Replace($testEvidenceRecord, '|  | ACT-001 | test | activation lifecycle | test activation | PASS | TR-REQ-001, TR-LIFECYCLE-001 |')
    Expected = 'test-evidence record requires non-empty Migration Unit ID'
  }
  [pscustomobject]@{
    Name = 'test-evidence blank Activation Slice ID'
    Text = $implementationActivationArtifact.Replace($testEvidenceRecord, '| UNIT-001 |  | test | activation lifecycle | test activation | PASS | TR-REQ-001, TR-LIFECYCLE-001 |')
    Expected = 'test-evidence record requires non-empty Activation Slice ID'
  }
  [pscustomobject]@{
    Name = 'test-evidence blank Seam'
    Text = $implementationActivationArtifact.Replace($testEvidenceRecord, '| UNIT-001 | ACT-001 |  | activation lifecycle | test activation | PASS | TR-REQ-001, TR-LIFECYCLE-001 |')
    Expected = 'test-evidence record requires non-empty Seam'
  }
  [pscustomobject]@{
    Name = 'test-evidence blank Test'
    Text = $implementationActivationArtifact.Replace($testEvidenceRecord, '| UNIT-001 | ACT-001 | test |  | test activation | PASS | TR-REQ-001, TR-LIFECYCLE-001 |')
    Expected = 'test-evidence record requires non-empty Test'
  }
  [pscustomobject]@{
    Name = 'test-evidence blank Command'
    Text = $implementationActivationArtifact.Replace($testEvidenceRecord, '| UNIT-001 | ACT-001 | test | activation lifecycle |  | PASS | TR-REQ-001, TR-LIFECYCLE-001 |')
    Expected = 'test-evidence record requires non-empty Command'
  }
  [pscustomobject]@{
    Name = 'test-evidence blank Result'
    Text = $implementationActivationArtifact.Replace($testEvidenceRecord, '| UNIT-001 | ACT-001 | test | activation lifecycle | test activation |  | TR-REQ-001, TR-LIFECYCLE-001 |')
    Expected = 'test-evidence record requires non-empty Result'
  }
  [pscustomobject]@{
    Name = 'test-evidence blank Trace IDs'
    Text = $implementationActivationArtifact.Replace($testEvidenceRecord, '| UNIT-001 | ACT-001 | test | activation lifecycle | test activation | PASS |  |')
    Expected = 'test-evidence record requires non-empty Trace IDs'
  }
)
foreach ($blankStructuredRecordScenario in $blankStructuredRecordScenarios) {
  Assert-True ($blankStructuredRecordScenario.Text -ne $implementationActivationArtifact) "Structured-record blank-field fixture must alter production: $($blankStructuredRecordScenario.Name)"
  $blankStructuredRecordResult = Invoke-ActivationSliceArtifactValidator $blankStructuredRecordScenario.Text $approvedPlanActivationSlice
  Assert-True ($blankStructuredRecordResult.ExitCode -eq 1) "Structured record with a blank field should block: $($blankStructuredRecordScenario.Name). Output: $($blankStructuredRecordResult.Output)"
  Assert-Contains $blankStructuredRecordResult.Output $blankStructuredRecordScenario.Expected "Structured record blank field: $($blankStructuredRecordScenario.Name)"
}

$fullWidthMigrationUnitId = "UNIT-$([char]0xFF10)$([char]0xFF10)$([char]0xFF11)"
$unitIdFormatScenarios = @(
  [pscustomobject]@{
    Name = 'selected-unit invalid unit ID'
    Text = $implementationActivationArtifact.Replace('| UNIT-001 | plan-001 |', '| UNIT-ABC | plan-001 |')
    Expected = 'selected-unit Migration Unit ID must match UNIT-[0-9]{3}: UNIT-ABC'
  }
  [pscustomobject]@{
    Name = 'selected-unit non-ASCII unit ID'
    Text = $implementationActivationArtifact.Replace('| UNIT-001 | plan-001 |', "| $fullWidthMigrationUnitId | plan-001 |")
    Expected = "selected-unit Migration Unit ID must match UNIT-[0-9]{3}: $fullWidthMigrationUnitId"
  }
  [pscustomobject]@{
    Name = 'changed-file invalid unit ID'
    Text = $implementationActivationArtifact.Replace($changedFileRecord, '| UNIT-ABC | ACT-001 | render | target/render.dart | render the selected module | TR-REQ-001, TR-RENDER-001 |')
    Expected = 'changed-file Migration Unit ID must match UNIT-[0-9]{3}: UNIT-ABC'
  }
  [pscustomobject]@{
    Name = 'changed-file non-ASCII unit ID'
    Text = $implementationActivationArtifact.Replace($changedFileRecord, "| $fullWidthMigrationUnitId | ACT-001 | render | target/render.dart | render the selected module | TR-REQ-001, TR-RENDER-001 |")
    Expected = "changed-file Migration Unit ID must match UNIT-[0-9]{3}: $fullWidthMigrationUnitId"
  }
  [pscustomobject]@{
    Name = 'test-evidence invalid unit ID'
    Text = $implementationActivationArtifact.Replace($testEvidenceRecord, '| UNIT-ABC | ACT-001 | test | activation lifecycle | test activation | PASS | TR-REQ-001, TR-LIFECYCLE-001 |')
    Expected = 'test-evidence Migration Unit ID must match UNIT-[0-9]{3}: UNIT-ABC'
  }
  [pscustomobject]@{
    Name = 'test-evidence non-ASCII unit ID'
    Text = $implementationActivationArtifact.Replace($testEvidenceRecord, "| $fullWidthMigrationUnitId | ACT-001 | test | activation lifecycle | test activation | PASS | TR-REQ-001, TR-LIFECYCLE-001 |")
    Expected = "test-evidence Migration Unit ID must match UNIT-[0-9]{3}: $fullWidthMigrationUnitId"
  }
)
foreach ($unitIdFormatScenario in $unitIdFormatScenarios) {
  Assert-True ($unitIdFormatScenario.Text -ne $implementationActivationArtifact) "Migration-unit format fixture must alter production: $($unitIdFormatScenario.Name)"
  $unitIdFormatResult = Invoke-ActivationSliceArtifactValidator $unitIdFormatScenario.Text $approvedPlanActivationSlice
  Assert-True ($unitIdFormatResult.ExitCode -eq 1) "Invalid Migration Unit ID should block: $($unitIdFormatScenario.Name). Output: $($unitIdFormatResult.Output)"
  Assert-Contains $unitIdFormatResult.Output $unitIdFormatScenario.Expected "Migration Unit ID format: $($unitIdFormatScenario.Name)"
}

$missingCurrentSelectedUnit = Remove-MarkdownTablesInSection $implementationActivationArtifact $selectedMigrationUnitSection
$missingCurrentSelectedUnitResult = Invoke-ActivationSliceArtifactValidator $missingCurrentSelectedUnit $approvedPlanActivationSlice
Assert-True ($missingCurrentSelectedUnitResult.ExitCode -eq 1) "Step 10 without a selected-unit record should block. Output: $($missingCurrentSelectedUnitResult.Output)"
Assert-Contains $missingCurrentSelectedUnitResult.Output 'requires exactly one current Selected Migration Unit record; found 0' 'Missing current selected-unit record'

$selectedMigrationUnitRecord = '| UNIT-001 | plan-001 | approval-001 | incremental/preserve-existing | not-required | not-applicable | not-applicable | not-applicable | regression-baseline-001 | TR-REQ-001 |'
$greenfieldSelectedMigrationUnitRecord = '| UNIT-001 | plan-001 | approval-001 | greenfield/design-new | required | FOUNDATION-001 | target-baseline-001 | bootstrap-approved-001 | not-applicable | TR-REQ-001 |'
$resumeSelectedMigrationUnitRecord = $selectedMigrationUnitRecord.Replace('regression-baseline-001', 'capability-evidence-001')
$selectedMigrationUnitFields = @(
  [pscustomobject]@{ Column = 'Migration Unit ID'; Index = 1 }
  [pscustomobject]@{ Column = 'Plan Reference'; Index = 2 }
  [pscustomobject]@{ Column = 'Approval Reference'; Index = 3 }
  [pscustomobject]@{ Column = 'Mode Constraint'; Index = 4 }
  [pscustomobject]@{ Column = 'Bootstrap Scope'; Index = 5 }
  [pscustomobject]@{ Column = 'Foundation Baseline ID'; Index = 6 }
  [pscustomobject]@{ Column = 'Foundation Baseline Reference'; Index = 7 }
  [pscustomobject]@{ Column = 'Foundation Baseline Approval Reference'; Index = 8 }
  [pscustomobject]@{ Column = 'Baseline Reference'; Index = 9 }
  [pscustomobject]@{ Column = 'Trace IDs'; Index = 10 }
)
foreach ($selectedMigrationUnitField in $selectedMigrationUnitFields) {
  $blankSelectedMigrationUnitRecord = Set-MarkdownRecordCellBlank $selectedMigrationUnitRecord $selectedMigrationUnitField.Index
  $blankCurrentSelectedUnit = $implementationActivationArtifact.Replace($selectedMigrationUnitRecord, $blankSelectedMigrationUnitRecord)
  $blankCurrentSelectedUnitResult = Invoke-ActivationSliceArtifactValidator $blankCurrentSelectedUnit $approvedPlanActivationSlice
  Assert-True ($blankCurrentSelectedUnitResult.ExitCode -eq 1) "Current selected-unit field must be non-empty: $($selectedMigrationUnitField.Column). Output: $($blankCurrentSelectedUnitResult.Output)"
  Assert-Contains $blankCurrentSelectedUnitResult.Output "selected-unit record requires non-empty $($selectedMigrationUnitField.Column)" "Blank current selected-unit field: $($selectedMigrationUnitField.Column)"

  $blankGreenfieldSelectedMigrationUnitRecord = Set-MarkdownRecordCellBlank $greenfieldSelectedMigrationUnitRecord $selectedMigrationUnitField.Index
  $blankStep09SelectedUnit = $approvedBootstrapActivationSlice.Replace($greenfieldSelectedMigrationUnitRecord, $blankGreenfieldSelectedMigrationUnitRecord)
  $blankStep09SelectedUnitResult = Invoke-ActivationSliceArtifactValidator $greenfieldImplementationActivationArtifact $blankStep09SelectedUnit
  Assert-True ($blankStep09SelectedUnitResult.ExitCode -eq 1) "Step-09 predecessor selected-unit field must be non-empty: $($selectedMigrationUnitField.Column). Output: $($blankStep09SelectedUnitResult.Output)"
  Assert-Contains $blankStep09SelectedUnitResult.Output "predecessor selected-unit record requires non-empty $($selectedMigrationUnitField.Column)" "Blank step-09 predecessor selected-unit field: $($selectedMigrationUnitField.Column)"

  $blankResumeSelectedMigrationUnitRecord = Set-MarkdownRecordCellBlank $resumeSelectedMigrationUnitRecord $selectedMigrationUnitField.Index
  $blankResumedSelectedUnit = $waivedStep10ActivationPredecessorArtifact.Replace($resumeSelectedMigrationUnitRecord, $blankResumeSelectedMigrationUnitRecord)
  $blankResumedSelectedUnitResult = Invoke-ActivationSliceArtifactValidator $waivedStep10ActivationArtifact $blankResumedSelectedUnit
  Assert-True ($blankResumedSelectedUnitResult.ExitCode -eq 1) "Resumed predecessor selected-unit field must be non-empty: $($selectedMigrationUnitField.Column). Output: $($blankResumedSelectedUnitResult.Output)"
  Assert-Contains $blankResumedSelectedUnitResult.Output "predecessor selected-unit record requires non-empty $($selectedMigrationUnitField.Column)" "Blank resumed predecessor selected-unit field: $($selectedMigrationUnitField.Column)"
}

$duplicateCurrentSelectedUnit = $implementationActivationArtifact.Replace(
  $selectedMigrationUnitRecord,
  "$selectedMigrationUnitRecord`n$selectedMigrationUnitRecord"
)
$duplicateCurrentSelectedUnitResult = Invoke-ActivationSliceArtifactValidator $duplicateCurrentSelectedUnit $approvedPlanActivationSlice
Assert-True ($duplicateCurrentSelectedUnitResult.ExitCode -eq 1) "Step 10 with two selected-unit records should block. Output: $($duplicateCurrentSelectedUnitResult.Output)"
Assert-Contains $duplicateCurrentSelectedUnitResult.Output 'requires exactly one current Selected Migration Unit record; found 2' 'Duplicate current selected-unit record'

$missingPredecessorSelectedUnit = Remove-MarkdownTablesInSection $approvedBootstrapActivationSlice $selectedMigrationUnitSection
$missingPredecessorSelectedUnitResult = Invoke-ActivationSliceArtifactValidator $greenfieldImplementationActivationArtifact $missingPredecessorSelectedUnit
Assert-True ($missingPredecessorSelectedUnitResult.ExitCode -eq 1) "Step 10 whose predecessor lacks a selected-unit record should block. Output: $($missingPredecessorSelectedUnitResult.Output)"
Assert-Contains $missingPredecessorSelectedUnitResult.Output 'requires exactly one predecessor Selected Migration Unit record; found 0' 'Missing predecessor selected-unit record'

$currentSelectedUnitMismatchArtifact = $greenfieldImplementationActivationArtifact.Replace('UNIT-001', 'UNIT-002')
$currentSelectedUnitMismatchResult = Invoke-ActivationSliceArtifactValidator $currentSelectedUnitMismatchArtifact $approvedBootstrapActivationSlice
Assert-True ($currentSelectedUnitMismatchResult.ExitCode -eq 1) "A current step-10 unit that differs from its predecessor should block. Output: $($currentSelectedUnitMismatchResult.Output)"
Assert-Contains $currentSelectedUnitMismatchResult.Output 'current Selected Migration Unit ID UNIT-002 does not match predecessor UNIT-001' 'Current/predecessor selected-unit consistency'

$invalidPredecessorSelectedUnit = $approvedBootstrapActivationSlice.Replace('| UNIT-001 | plan-001 |', '| UNIT-ABC | plan-001 |')
$invalidPredecessorSelectedUnitResult = Invoke-ActivationSliceArtifactValidator $greenfieldImplementationActivationArtifact $invalidPredecessorSelectedUnit
Assert-True ($invalidPredecessorSelectedUnitResult.ExitCode -eq 1) "An invalid predecessor selected-unit ID should block. Output: $($invalidPredecessorSelectedUnitResult.Output)"
Assert-Contains $invalidPredecessorSelectedUnitResult.Output 'predecessor selected-unit Migration Unit ID must match UNIT-[0-9]{3}: UNIT-ABC' 'Predecessor selected-unit format'

$missingPlanUnitMatchArtifact = $implementationActivationArtifact.Replace('UNIT-001', 'UNIT-003')
$missingPlanUnitMatchResult = Invoke-ActivationSliceArtifactValidator $missingPlanUnitMatchArtifact $approvedPlanActivationSlice
Assert-True ($missingPlanUnitMatchResult.ExitCode -eq 1) "Step 10 must resolve its selected unit to one approved plan row. Output: $($missingPlanUnitMatchResult.Output)"
Assert-Contains $missingPlanUnitMatchResult.Output 'requires exactly one approved predecessor ordered-unit record matching current Migration Unit ID UNIT-003; found 0' 'Missing plan unit match'

$orderedMigrationUnitRecord = '| 1 | UNIT-001 | not-required | not-applicable | not-applicable | none | activation accepted | incremental/preserve-existing | TR-REQ-001 | one-unit-one-change | approval-001 | approved |'
$orderedMigrationUnitFields = @(
  [pscustomobject]@{ Column = 'Order'; Index = 1 }
  [pscustomobject]@{ Column = 'Migration Unit ID'; Index = 2 }
  [pscustomobject]@{ Column = 'Bootstrap Scope'; Index = 3 }
  [pscustomobject]@{ Column = 'Foundation Baseline ID'; Index = 4 }
  [pscustomobject]@{ Column = 'Foundation Approval Reference'; Index = 5 }
  [pscustomobject]@{ Column = 'Dependencies'; Index = 6 }
  [pscustomobject]@{ Column = 'Acceptance'; Index = 7 }
  [pscustomobject]@{ Column = 'Mode Constraint'; Index = 8 }
  [pscustomobject]@{ Column = 'Trace IDs'; Index = 9 }
  [pscustomobject]@{ Column = 'Delivery Change Boundary'; Index = 10 }
  [pscustomobject]@{ Column = 'Approval Reference'; Index = 11 }
  [pscustomobject]@{ Column = 'Approval Status'; Index = 12 }
)
foreach ($orderedMigrationUnitField in $orderedMigrationUnitFields) {
  $blankOrderedMigrationUnitRecord = Set-MarkdownRecordCellBlank $orderedMigrationUnitRecord $orderedMigrationUnitField.Index
  $blankOrderedMigrationUnit = $approvedPlanActivationSlice.Replace($orderedMigrationUnitRecord, $blankOrderedMigrationUnitRecord)
  $blankOrderedMigrationUnitResult = Invoke-ActivationSliceArtifactValidator $implementationActivationArtifact $blankOrderedMigrationUnit
  Assert-True ($blankOrderedMigrationUnitResult.ExitCode -eq 1) "Step-08 matching ordered-unit field must be non-empty: $($orderedMigrationUnitField.Column). Output: $($blankOrderedMigrationUnitResult.Output)"
  Assert-Contains $blankOrderedMigrationUnitResult.Output "predecessor ordered-unit record requires non-empty $($orderedMigrationUnitField.Column)" "Blank step-08 matching ordered-unit field: $($orderedMigrationUnitField.Column)"
}

$duplicatePlanUnitMatch = $approvedPlanActivationSlice.Replace(
  $orderedMigrationUnitRecord,
  "$orderedMigrationUnitRecord`n$orderedMigrationUnitRecord"
)
$duplicatePlanUnitMatchResult = Invoke-ActivationSliceArtifactValidator $implementationActivationArtifact $duplicatePlanUnitMatch
Assert-True ($duplicatePlanUnitMatchResult.ExitCode -eq 1) "Step 10 must reject two approved plan rows for its selected unit. Output: $($duplicatePlanUnitMatchResult.Output)"
Assert-Contains $duplicatePlanUnitMatchResult.Output 'requires exactly one approved predecessor ordered-unit record matching current Migration Unit ID UNIT-001; found 2' 'Duplicate plan unit match'

$pendingPlanUnitMatch = $approvedPlanActivationSlice.Replace(
  $orderedMigrationUnitRecord,
  $orderedMigrationUnitRecord.Replace('| approved |', '| pending |')
)
$pendingPlanUnitMatchResult = Invoke-ActivationSliceArtifactValidator $implementationActivationArtifact $pendingPlanUnitMatch
Assert-True ($pendingPlanUnitMatchResult.ExitCode -eq 1) "Step 10 must reject a plan row whose selected unit is not approved. Output: $($pendingPlanUnitMatchResult.Output)"
Assert-Contains $pendingPlanUnitMatchResult.Output 'requires exactly one approved predecessor ordered-unit record matching current Migration Unit ID UNIT-001; found 0' 'Unapproved plan unit match'

$duplicateCurrentSelectedSection = $implementationActivationArtifact.TrimEnd() + "`n`n$selectedMigrationUnitTable"
$duplicateCurrentSelectedSectionResult = Invoke-ActivationSliceArtifactValidator $duplicateCurrentSelectedSection $approvedPlanActivationSlice
Assert-True ($duplicateCurrentSelectedSectionResult.ExitCode -eq 1) "Duplicate current selected-unit sections should block. Output: $($duplicateCurrentSelectedSectionResult.Output)"
Assert-Contains $duplicateCurrentSelectedSectionResult.Output 'current selected-unit section must appear exactly once; found 2' 'Duplicate current selected-unit section'

$duplicatePredecessorSelectedSection = $approvedBootstrapActivationSlice.TrimEnd() + "`n`n$greenfieldSelectedMigrationUnitTable"
$duplicatePredecessorSelectedSectionResult = Invoke-ActivationSliceArtifactValidator $greenfieldImplementationActivationArtifact $duplicatePredecessorSelectedSection
Assert-True ($duplicatePredecessorSelectedSectionResult.ExitCode -eq 1) "Duplicate predecessor selected-unit sections should block. Output: $($duplicatePredecessorSelectedSectionResult.Output)"
Assert-Contains $duplicatePredecessorSelectedSectionResult.Output 'predecessor unit section must appear exactly once; found 2' 'Duplicate predecessor selected-unit section'

$duplicateChangedFileSection = $implementationActivationArtifact.TrimEnd() + @"


$changedFilesHeading

| Migration Unit ID | Activation Slice ID | Seam | File | Change | Trace IDs |
|---|---|---|---|---|---|
$changedFileRecord
"@
$duplicateChangedFileSectionResult = Invoke-ActivationSliceArtifactValidator $duplicateChangedFileSection $approvedPlanActivationSlice
Assert-True ($duplicateChangedFileSectionResult.ExitCode -eq 1) "Duplicate changed-file structured sections should block. Output: $($duplicateChangedFileSectionResult.Output)"
Assert-Contains $duplicateChangedFileSectionResult.Output 'changed-file structured section must appear exactly once; found 2' 'Duplicate changed-file section'

$duplicateTestEvidenceSection = $implementationActivationArtifact.TrimEnd() + @"


## Activation Slice Test Evidence

| Migration Unit ID | Activation Slice ID | Seam | Test | Command | Result | Trace IDs |
|---|---|---|---|---|---|---|
$testEvidenceRecord
"@
$duplicateTestEvidenceSectionResult = Invoke-ActivationSliceArtifactValidator $duplicateTestEvidenceSection $approvedPlanActivationSlice
Assert-True ($duplicateTestEvidenceSectionResult.ExitCode -eq 1) "Duplicate test-evidence structured sections should block. Output: $($duplicateTestEvidenceSectionResult.Output)"
Assert-Contains $duplicateTestEvidenceSectionResult.Output 'test-evidence structured section must appear exactly once; found 2' 'Duplicate test-evidence section'

$selectedUnitExtraColumnTable = @'
| Migration Unit ID | Plan Reference | Approval Reference | Mode Constraint | Bootstrap Scope | Foundation Baseline ID | Foundation Baseline Reference | Foundation Baseline Approval Reference | Baseline Reference | Trace IDs | Extra |
|---|---|---|---|---|---|---|---|---|---|---|
| UNIT-001 | plan-001 | approval-001 | incremental/preserve-existing | not-required | not-applicable | not-applicable | not-applicable | regression-baseline-001 | TR-REQ-001 | hidden |
'@
$overlappingSelectedUnitTable = $implementationActivationArtifact.Replace(
  $selectedMigrationUnitTable,
  "$selectedMigrationUnitTable`n`n$selectedUnitExtraColumnTable"
)
$overlappingSelectedUnitTableResult = Invoke-ActivationSliceArtifactValidator $overlappingSelectedUnitTable $approvedPlanActivationSlice
Assert-True ($overlappingSelectedUnitTableResult.ExitCode -eq 1) "A selected-unit section must reject an extra-column overlapping table. Output: $($overlappingSelectedUnitTableResult.Output)"
Assert-Contains $overlappingSelectedUnitTableResult.Output 'current selected-unit linkage structured section contains additional overlapping record table' 'Overlapping selected-unit table'

$changedFileMissingColumnTable = @'
| Migration Unit ID | Activation Slice ID | Seam | File | Trace IDs |
|---|---|---|---|---|
| UNIT-001 | ACT-001 | render | hidden/render.dart | TR-REQ-001, TR-RENDER-001 |
'@
$overlappingChangedFileTable = $implementationActivationArtifact.Replace(
  '## Activation Slice Test Evidence',
  "$changedFileMissingColumnTable`n`n## Activation Slice Test Evidence"
)
$overlappingChangedFileTableResult = Invoke-ActivationSliceArtifactValidator $overlappingChangedFileTable $approvedPlanActivationSlice
Assert-True ($overlappingChangedFileTableResult.ExitCode -eq 1) "A changed-file section must reject a missing-column overlapping table. Output: $($overlappingChangedFileTableResult.Output)"
Assert-Contains $overlappingChangedFileTableResult.Output 'changed-file linkage structured section contains additional overlapping record table' 'Overlapping changed-file table'

$testEvidenceReorderedTable = @'
| Migration Unit ID | Activation Slice ID | Seam | Command | Test | Result | Trace IDs |
|---|---|---|---|---|---|---|
| UNIT-001 | ACT-001 | test | hidden command | hidden test | PASS | TR-REQ-001, TR-LIFECYCLE-001 |
'@
$overlappingTestEvidenceTable = $implementationActivationArtifact.TrimEnd() + "`n`n$testEvidenceReorderedTable"
$overlappingTestEvidenceTableResult = Invoke-ActivationSliceArtifactValidator $overlappingTestEvidenceTable $approvedPlanActivationSlice
Assert-True ($overlappingTestEvidenceTableResult.ExitCode -eq 1) "A test-evidence section must reject a reordered-column overlapping table. Output: $($overlappingTestEvidenceTableResult.Output)"
Assert-Contains $overlappingTestEvidenceTableResult.Output 'test-evidence linkage structured section contains additional overlapping record table' 'Overlapping test-evidence table'

$selectedUnitSupportingTable = @'
| Note | Value |
|---|---|
| owner | platform |
'@
$nonOverlappingSelectedUnitTable = $implementationActivationArtifact.Replace(
  $selectedMigrationUnitTable,
  "$selectedMigrationUnitTable`n`n$selectedUnitSupportingTable"
)
$nonOverlappingSelectedUnitTableResult = Invoke-ActivationSliceArtifactValidator $nonOverlappingSelectedUnitTable $approvedPlanActivationSlice
Assert-True ($nonOverlappingSelectedUnitTableResult.ExitCode -eq 0) "A non-overlapping supporting table in a structured section should remain allowed. Output: $($nonOverlappingSelectedUnitTableResult.Output)"

$changedFileUnitMismatch = $implementationActivationArtifact.Replace($changedFileRecord, '| UNIT-002 | ACT-001 | render | target/render.dart | render the selected module | TR-REQ-001, TR-RENDER-001 |')
$changedFileUnitMismatchResult = Invoke-ActivationSliceArtifactValidator $changedFileUnitMismatch $approvedPlanActivationSlice
Assert-True ($changedFileUnitMismatchResult.ExitCode -eq 1) "A changed-file row for a real slice/seam but a different unit should block. Output: $($changedFileUnitMismatchResult.Output)"
Assert-Contains $changedFileUnitMismatchResult.Output 'changed-file Migration Unit ID UNIT-002 does not match selected Migration Unit ID UNIT-001' 'Changed-file selected-unit consistency'

$testEvidenceUnitMismatch = $implementationActivationArtifact.Replace($testEvidenceRecord, '| UNIT-002 | ACT-001 | test | activation lifecycle | test activation | PASS | TR-REQ-001, TR-LIFECYCLE-001 |')
$testEvidenceUnitMismatchResult = Invoke-ActivationSliceArtifactValidator $testEvidenceUnitMismatch $approvedPlanActivationSlice
Assert-True ($testEvidenceUnitMismatchResult.ExitCode -eq 1) "A test-evidence row for a real slice/seam but a different unit should block. Output: $($testEvidenceUnitMismatchResult.Output)"
Assert-Contains $testEvidenceUnitMismatchResult.Output 'test-evidence Migration Unit ID UNIT-002 does not match selected Migration Unit ID UNIT-001' 'Test-evidence selected-unit consistency'

$missingImplementationStepId = $implementationActivationArtifact.Replace("step_id: 10-code-migration`n", '')
$missingImplementationStepResult = Invoke-ActivationSliceArtifactValidator $missingImplementationStepId $approvedPlanActivationSlice
Assert-True ($missingImplementationStepResult.ExitCode -eq 1) "Structured implementation linkage without the step-10 role should block. Output: $($missingImplementationStepResult.Output)"
Assert-Contains $missingImplementationStepResult.Output 'implementation linkage sections require front matter step_id: 10-code-migration' 'Implementation current-step role'

$wrongImplementationStepId = $implementationActivationArtifact.Replace('step_id: 10-code-migration', 'step_id: 10-code-migraton')
$wrongImplementationStepResult = Invoke-ActivationSliceArtifactValidator $wrongImplementationStepId $approvedPlanActivationSlice
Assert-True ($wrongImplementationStepResult.ExitCode -eq 1) "Structured implementation linkage with a mistyped step-10 role should block. Output: $($wrongImplementationStepResult.Output)"
Assert-Contains $wrongImplementationStepResult.Output 'implementation linkage sections require front matter step_id: 10-code-migration' 'Implementation mistyped current-step role'

$missingPredecessorStepResult = Invoke-ActivationSliceArtifactValidator $implementationActivationArtifact $completeActivationSlice
Assert-True ($missingPredecessorStepResult.ExitCode -eq 1) "Implementation linkage with an untyped predecessor should block. Output: $($missingPredecessorStepResult.Output)"
Assert-Contains $missingPredecessorStepResult.Output 'implementation links require approved immediate predecessor step_id: 08-plan-waves or 09-bootstrap-target' 'Implementation predecessor role'

$wrongPredecessorStep = $completeActivationSlice.Replace('step_id: 01-validate-inputs', 'step_id: 07-technical-design')
$wrongPredecessorStepResult = Invoke-ActivationSliceArtifactValidator $implementationActivationArtifact $wrongPredecessorStep
Assert-True ($wrongPredecessorStepResult.ExitCode -eq 1) "Implementation linkage with a non-immediate predecessor should block. Output: $($wrongPredecessorStepResult.Output)"
Assert-Contains $wrongPredecessorStepResult.Output 'implementation links require approved immediate predecessor step_id: 08-plan-waves or 09-bootstrap-target' 'Implementation non-immediate predecessor role'

$draftApprovedEnvelope = $approvedPlanActivationSlice.Replace('status: approved', 'status: draft')
$unapprovedImplementationPredecessorResult = Invoke-ActivationSliceArtifactValidator $implementationActivationArtifact $draftApprovedEnvelope
Assert-True ($unapprovedImplementationPredecessorResult.ExitCode -eq 1) "Implementation links require an approved predecessor envelope. Output: $($unapprovedImplementationPredecessorResult.Output)"
Assert-Contains $unapprovedImplementationPredecessorResult.Output 'implementation links require predecessor front matter status: approved and result: complete' 'Implementation approved predecessor gate'

$activationEnvelopeRequirement = 'Preserve the immediate predecessor Activation Slice envelope without loss: keep the complete case-sensitive slice ID set, Applicability, all nine canonical seam rows, and every predecessor Source Reference and Trace ID. Source Reference enrichment is append-only, and predecessor Trace IDs remain a subset of successor Trace IDs. Never reconstruct it from cumulative artifacts.'
$discoveryOriginRequirement = "Discovery is the Activation Slice origin when step 01 has no envelope: create the complete canonical envelope from validated evidence. If an immediate predecessor already carries an envelope, preserve it under the contract's no-loss and append-only rules; never reconstruct from cumulative artifacts."
$activationChainTemplateNames = @(
  'discovery.md',
  'requirements-uiux.md',
  'inventory.md',
  'mapping.md',
  'gaps-conflicts.md',
  'technical-design.md',
  'migration-plan.md',
  'bootstrap-report.md',
  'implementation-report.md',
  'review-report.md',
  'verification-report.md',
  'parity-report.md',
  'regression-report.md'
)
foreach ($activationChainTemplateName in $activationChainTemplateNames) {
  $activationChainTemplateText = Get-Content -Raw -Encoding utf8 (Join-Path $PSScriptRoot "../templates/migration/$activationChainTemplateName")
  Assert-Contains $activationChainTemplateText '## Activation Slice' "Activation chain template $activationChainTemplateName"
  Assert-Contains $activationChainTemplateText '| Activation Slice ID | Applicability | Seam | Input | Output | Source Reference | Trace IDs | Disposition | Status | Decision Reference | Deferred Unit ID |' "Activation chain template schema $activationChainTemplateName"
}

$activationChainSkillPaths = @(
  '../skills/migration/analyze-requirements-uiux/SKILL.md',
  '../skills/migration/build-inventory/SKILL.md',
  '../skills/migration/feature-mapping/SKILL.md',
  '../skills/migration/analyze-gaps-conflicts/SKILL.md',
  '../skills/migration/technical-design/SKILL.md',
  '../skills/migration/plan-waves/SKILL.md',
  '../skills/migration/bootstrap-target/SKILL.md',
  '../skills/migration/code-migration/SKILL.md',
  '../skills/shared/ai-review/SKILL.md',
  '../skills/shared/verification-testing/SKILL.md',
  '../skills/migration/verify-parity/SKILL.md',
  '../skills/migration/verify-regression/SKILL.md'
)
$discoveryActivationSkillText = Get-Content -Raw -Encoding utf8 (Join-Path $PSScriptRoot '../skills/migration/discovery/SKILL.md')
Assert-Contains $discoveryActivationSkillText $discoveryOriginRequirement 'Activation discovery origin and continuation responsibility'
foreach ($activationChainSkillPath in $activationChainSkillPaths) {
  $activationChainSkillText = Get-Content -Raw -Encoding utf8 (Join-Path $PSScriptRoot $activationChainSkillPath)
  Assert-Contains $activationChainSkillText 'aitoolkit/contracts/activation-slice.md' "Activation chain skill contract $activationChainSkillPath"
  Assert-Contains $activationChainSkillText $activationEnvelopeRequirement "Activation chain immediate-predecessor preservation $activationChainSkillPath"
}

$implementationTemplateTextForLinks = Get-Content -Raw -Encoding utf8 (Join-Path $PSScriptRoot '../templates/migration/implementation-report.md')
Assert-Contains $implementationTemplateTextForLinks '| Migration Unit ID | Activation Slice ID | Seam | File | Change | Trace IDs |' 'Implementation changed-file structured Activation Slice linkage'
Assert-Contains $implementationTemplateTextForLinks '## Activation Slice Test Evidence' 'Implementation structured test-evidence section'
Assert-Contains $implementationTemplateTextForLinks '| Migration Unit ID | Activation Slice ID | Seam | Test | Command | Result | Trace IDs |' 'Implementation test-evidence structured Activation Slice linkage'

function Add-ActivationStepId([string]$Text, [string]$StepId, [string[]]$Sections = @()) {
  $artifact = $Text.Replace('step_id: 01-validate-inputs', "step_id: $StepId").TrimEnd()
  foreach ($section in $Sections) { $artifact += "`n`n$section" }
  return $artifact
}
$parityVerdictTable = @'
## Parity Verdict

| Parity Verdict | Evidence Reference |
|---|---|
| pass | parity-evidence-001 |
'@
$regressionConclusionSection = [Text.Encoding]::UTF8.GetString(
  [Convert]::FromBase64String('S+G6v3QgbHXhuq1uIHjDoWMgbWluaCBtaWdyYXRpb24=')
)
$regressionConclusionTable = @"
## $regressionConclusionSection

| Parity Verdict | Regression Applicability | Regression Verdict | Evidence Reference |
|---|---|---|---|
| pass | required | pass | parity-evidence-001; regression-evidence-001 |
"@
$assuranceScenarioTable = [Text.Encoding]::UTF8.GetString(
  [Convert]::FromBase64String('IyMgS+G7i2NoIGLhuqNuCgp8IFNjZW5hcmlvIHwgQmFzZWxpbmUgfCBBY3R1YWwgfCBWZXJkaWN0IHwKfC0tLXwtLS18LS0tfC0tLXwKfCBhY3RpdmF0aW9uIHBhcml0eSB8IHNvdXJjZSB8IHRhcmdldCB8IHBhc3MgfA==')
)
$assuranceScenarioSectionName = [Text.Encoding]::UTF8.GetString(
  [Convert]::FromBase64String('S+G7i2NoIGLhuqNu')
)
$regressionScenarioTable = @"
## $assuranceScenarioSectionName

| Scenario | Baseline | Actual | Delta Class | Waiver Reference | Trace IDs | Verdict |
|---|---|---|---|---|---|---|
| activation parity | source | target | expected | not-applicable | TR-REQ-001 | pass |
"@
$verificationTaskProvenance = @'
## Task Provenance

| Task / Unit | Task-base SHA | Final-tree SHA | Source Artifact |
|---|---|---|---|
| UNIT-001 | base-sha-001 | final-sha-001 | <IMMEDIATE_PREDECESSOR_PATH> |
'@
$parityTaskProvenance = $verificationTaskProvenance
$regressionTaskProvenance = $verificationTaskProvenance
$reviewChangeHygiene = @'
## Change Hygiene

| Task / Unit | Scope Evidence | Formatter Evidence | Unrelated Diff | Severity | Task-base SHA | Final-tree SHA |
|---|---|---|---|---|---|---|
| UNIT-001 | target/render.dart | formatter-not-required | none | none | base-sha-001 | final-sha-001 |
'@
$activationStepArtifacts = @{
  discovery = Add-ActivationStepId $completeActivationSlice '02-discovery'
  requirements = Add-ActivationStepId $completeActivationSlice '03-analyze-requirements-uiux'
  inventory = Add-ActivationStepId $completeActivationSlice '04-build-inventory'
  mapping = Add-ActivationStepId $completeActivationSlice '05-feature-mapping'
  gaps = Add-ActivationStepId $completeActivationSlice '06-analyze-gaps-conflicts'
  design = Add-ActivationStepId $completeActivationSlice '07-technical-design'
  plan = $approvedPlanActivationSlice
  greenfieldPlan = $approvedGreenfieldPlanActivationSlice
  bootstrap = $approvedBootstrapActivationSlice
  implementation = $implementationActivationArtifact
  greenfieldImplementation = $greenfieldImplementationActivationArtifact
  review = Add-ActivationStepId $completeActivationSlice '11-ai-review' @($selectedMigrationUnitTable, $reviewChangeHygiene)
  verification = Add-ActivationStepId $completeActivationSlice '12-verification-testing' @($selectedMigrationUnitTable, $verificationTaskProvenance)
  parity = Add-ActivationStepId $completeActivationSlice '13-verify-parity' @($selectedMigrationUnitTable, $parityVerdictTable, $assuranceScenarioTable, $parityTaskProvenance)
  regression = Add-ActivationStepId $completeActivationSlice '14-verify-regression' @($selectedMigrationUnitTable, $regressionConclusionTable, $regressionScenarioTable, $regressionTaskProvenance)
}
$activationHandoffChains = @(
  [pscustomobject]@{ Name = 'discovery to requirements'; Predecessor = 'discovery'; Successor = 'requirements' }
  [pscustomobject]@{ Name = 'requirements to inventory'; Predecessor = 'requirements'; Successor = 'inventory' }
  [pscustomobject]@{ Name = 'inventory to mapping'; Predecessor = 'inventory'; Successor = 'mapping' }
  [pscustomobject]@{ Name = 'mapping to gaps'; Predecessor = 'mapping'; Successor = 'gaps' }
  [pscustomobject]@{ Name = 'gaps to design'; Predecessor = 'gaps'; Successor = 'design' }
  [pscustomobject]@{ Name = 'design to plan'; Predecessor = 'design'; Successor = 'plan' }
  [pscustomobject]@{ Name = 'plan to bootstrap'; Predecessor = 'greenfieldPlan'; Successor = 'bootstrap' }
  [pscustomobject]@{ Name = 'plan to implementation'; Predecessor = 'plan'; Successor = 'implementation' }
  [pscustomobject]@{ Name = 'bootstrap to implementation'; Predecessor = 'bootstrap'; Successor = 'greenfieldImplementation' }
  [pscustomobject]@{ Name = 'implementation to review'; Predecessor = 'implementation'; Successor = 'review' }
  [pscustomobject]@{ Name = 'review to verification'; Predecessor = 'review'; Successor = 'verification' }
  [pscustomobject]@{ Name = 'verification to parity'; Predecessor = 'verification'; Successor = 'parity' }
  [pscustomobject]@{ Name = 'parity to regression'; Predecessor = 'parity'; Successor = 'regression' }
)
foreach ($activationHandoffChain in $activationHandoffChains) {
  $activationHandoffChainResult = Invoke-ActivationSliceArtifactValidator `
    $activationStepArtifacts[$activationHandoffChain.Successor] `
    $activationStepArtifacts[$activationHandoffChain.Predecessor]
  Assert-True ($activationHandoffChainResult.ExitCode -eq 0) "Activation handoff chain should preserve the immediate predecessor: $($activationHandoffChain.Name). Output: $($activationHandoffChainResult.Output)"
}

$escapedPipeEvidenceSlice = $completeActivationSlice.Replace(
  'src/service:10',
  'src/service:10 \| profile contract'
)
$escapedPipeEvidenceResult = Invoke-ActivationSliceArtifactValidator $escapedPipeEvidenceSlice
Assert-True ($escapedPipeEvidenceResult.ExitCode -eq 0) "Escaped pipe in Activation Slice evidence should pass. Output: $($escapedPipeEvidenceResult.Output)"

$supportingTable = @'
| Note | Value |
|---|---|
| owner | platform |
'@
$supportingTableBeforeSlice = $completeActivationSlice.Replace(
  '## Activation Slice',
  "## Activation Slice`n`n$supportingTable"
)
$supportingTableBeforeResult = Invoke-ActivationSliceArtifactValidator $supportingTableBeforeSlice
Assert-True ($supportingTableBeforeResult.ExitCode -eq 0) "Supporting table before the canonical Activation Slice table should be ignored. Output: $($supportingTableBeforeResult.Output)"

$supportingTableAfterSlice = $completeActivationSlice + @'

### Supporting notes

| Note | Value |
|---|---|
| owner | platform |
'@
$supportingTableAfterResult = Invoke-ActivationSliceArtifactValidator $supportingTableAfterSlice
Assert-True ($supportingTableAfterResult.ExitCode -eq 0) "Supporting table after the canonical Activation Slice table should be ignored. Output: $($supportingTableAfterResult.Output)"

$canonicalTableMatch = [regex]::Match($completeActivationSlice, '(?ms)^\| Activation Slice ID \|.*\z')
Assert-True $canonicalTableMatch.Success 'Activation Slice table-selection fixture precondition'
$canonicalTable = $canonicalTableMatch.Value
$canonicalHeaderLines = (($canonicalTable -split '\r?\n') | Select-Object -First 2) -join "`n"
$fencedTableBeforeSlice = $completeActivationSlice.Replace(
  '## Activation Slice',
  "## Activation Slice`n`n``````markdown`n$canonicalHeaderLines`n``````"
)
$fencedTableBeforeResult = Invoke-ActivationSliceArtifactValidator $fencedTableBeforeSlice
Assert-True ($fencedTableBeforeResult.ExitCode -eq 0) "Fenced Markdown table before the canonical Activation Slice table should be ignored. Output: $($fencedTableBeforeResult.Output)"

$duplicateCanonicalTableSlice = $completeActivationSlice + "`n`n### Duplicate canonical table`n`n$canonicalTable"
$duplicateCanonicalTableResult = Invoke-ActivationSliceArtifactValidator $duplicateCanonicalTableSlice
Assert-True ($duplicateCanonicalTableResult.ExitCode -eq 1) "Duplicate canonical Activation Slice tables should block. Output: $($duplicateCanonicalTableResult.Output)"
Assert-Contains $duplicateCanonicalTableResult.Output 'canonical Activation Slice table must appear exactly once; found 2' 'Duplicate canonical Activation Slice tables'

$activationDelimiter = '|---|---|---|---|---|---|---|---|---|---|---|'
$missingDelimiterSlice = $completeActivationSlice.Replace("$activationDelimiter`n", '')
$missingDelimiterResult = Invoke-ActivationSliceArtifactValidator $missingDelimiterSlice
Assert-True ($missingDelimiterResult.ExitCode -eq 1) "Activation Slice without a delimiter row should block. Output: $($missingDelimiterResult.Output)"
Assert-Contains $missingDelimiterResult.Output 'canonical Activation Slice table delimiter must immediately follow its header' 'Missing Activation Slice delimiter'

$firstActivationRow = '| ACT-001 | applicable | upstream-response | profile response | activation key | src/service:10 | TR-REQ-001, TR-UP-001 | reuse | verified | not-applicable | not-applicable |'
$movedDelimiterSlice = $completeActivationSlice.Replace(
  "$activationDelimiter`n$firstActivationRow",
  "$firstActivationRow`n$activationDelimiter"
)
$movedDelimiterResult = Invoke-ActivationSliceArtifactValidator $movedDelimiterSlice
Assert-True ($movedDelimiterResult.ExitCode -eq 1) "Activation Slice with a moved delimiter row should block. Output: $($movedDelimiterResult.Output)"
Assert-Contains $movedDelimiterResult.Output 'canonical Activation Slice table delimiter must immediately follow its header' 'Moved Activation Slice delimiter'

$malformedDelimiterSlice = $completeActivationSlice.Replace($activationDelimiter, '|---|---|---|---|---|---|---|---|---|---|value|')
$malformedDelimiterResult = Invoke-ActivationSliceArtifactValidator $malformedDelimiterSlice
Assert-True ($malformedDelimiterResult.ExitCode -eq 1) "Activation Slice with malformed delimiter syntax should block. Output: $($malformedDelimiterResult.Output)"
Assert-Contains $malformedDelimiterResult.Output 'canonical Activation Slice table delimiter has invalid Markdown syntax' 'Malformed Activation Slice delimiter'

$shortDelimiterSlice = $completeActivationSlice.Replace($activationDelimiter, '|---|---|---|---|---|---|---|---|---|---|')
$shortDelimiterResult = Invoke-ActivationSliceArtifactValidator $shortDelimiterSlice
Assert-True ($shortDelimiterResult.ExitCode -eq 1) "Activation Slice with a short delimiter row should block. Output: $($shortDelimiterResult.Output)"
Assert-Contains $shortDelimiterResult.Output 'canonical Activation Slice table delimiter has 10 cells; expected 11' 'Activation Slice delimiter cell count'

$fourCharacterFence = '````'
$fiveCharacterFence = '`````'
$sixCharacterFence = '``````'
$fencedHeadingSlice = $completeActivationSlice.Replace(
  '## Activation Slice',
  "$fourCharacterFence markdown`n## Activation Slice`n$fourCharacterFence`n`n## Activation Slice"
)
$fencedHeadingResult = Invoke-ActivationSliceArtifactValidator $fencedHeadingSlice
Assert-True ($fencedHeadingResult.ExitCode -eq 0) "Fenced Activation Slice heading should be ignored. Output: $($fencedHeadingResult.Output)"

$longFencePrefix = "$sixCharacterFence markdown`n## Activation Slice`n$canonicalHeaderLines`n$fiveCharacterFence`nstill-fenced`n$sixCharacterFence`n`n"
$varyingFenceLengthSlice = $completeActivationSlice.Replace('## Activation Slice', "$longFencePrefix## Activation Slice")
$varyingFenceLengthResult = Invoke-ActivationSliceArtifactValidator $varyingFenceLengthSlice
Assert-True ($varyingFenceLengthResult.ExitCode -eq 0) "A shorter matching-character fence must not close a longer opening fence. Output: $($varyingFenceLengthResult.Output)"

$supportingTemplateFixture = Join-Path $PSScriptRoot '../templates/migration/requirements-uiux.md'
$supportingTemplateOriginalBytes = [IO.File]::ReadAllBytes($supportingTemplateFixture)
$supportingTemplateOriginal = [Text.Encoding]::UTF8.GetString($supportingTemplateOriginalBytes)
try {
  $supportingTemplateTable = "| Note | Value |`n|---|---|`n| context | retained |"
  $templateWithSupportingTable = $supportingTemplateOriginal.Replace(
    '## Activation Slice',
    "## Activation Slice`n`n$supportingTemplateTable"
  )
  Assert-True ($templateWithSupportingTable -ne $supportingTemplateOriginal) 'Supporting-table template fixture must alter requirements-uiux.md'
  [IO.File]::WriteAllText($supportingTemplateFixture, $templateWithSupportingTable, [Text.UTF8Encoding]::new($false))
  $supportingTemplateResult = Invoke-Validator 'Templates'
  Assert-True ($supportingTemplateResult.ExitCode -eq 0) "A supporting table before a template Activation Slice table should be ignored. Output: $($supportingTemplateResult.Output)"
}
finally {
  [IO.File]::WriteAllBytes($supportingTemplateFixture, $supportingTemplateOriginalBytes)
}

$migrationUnitIdentifierRule = '| Migration Unit ID | `UNIT-[0-9]{3}` |'
$artifactContractRuleMutations = @(
  [pscustomobject]@{
    Name = 'missing Migration Unit ID rule'
    Text = [regex]::Replace(
      $activationContractOriginal,
      "(?m)^$([regex]::Escape($migrationUnitIdentifierRule))\r?\n?",
      ''
    )
  }
  [pscustomobject]@{
    Name = 'duplicate Migration Unit ID rule'
    Text = $activationContractOriginal.Replace(
      $migrationUnitIdentifierRule,
      "$migrationUnitIdentifierRule`n$migrationUnitIdentifierRule"
    )
  }
)
foreach ($artifactContractRuleMutation in $artifactContractRuleMutations) {
  try {
    Assert-True ($artifactContractRuleMutation.Text -ne $activationContractOriginal) "Artifact contract-rule fixture must alter production: $($artifactContractRuleMutation.Name)"
    [IO.File]::WriteAllText($activationContractFixture, $artifactContractRuleMutation.Text, [Text.UTF8Encoding]::new($false))
    $artifactContractRuleResult = Invoke-ActivationSliceArtifactValidator $implementationActivationArtifact $approvedPlanActivationSlice
    Assert-True ($artifactContractRuleResult.ExitCode -eq 1) "Artifact validation must fail closed for $($artifactContractRuleMutation.Name). Output: $($artifactContractRuleResult.Output)"
    Assert-Contains $artifactContractRuleResult.Output 'implementation linkage contract must declare exactly one Migration Unit ID format' "Artifact contract rule: $($artifactContractRuleMutation.Name)"
  }
  finally {
    [IO.File]::WriteAllBytes($activationContractFixture, $activationContractOriginalBytes)
  }
}

$implementationLinkContractSection = [regex]::Match(
  $activationContractOriginal,
  '(?ms)^## Implementation linkage\s*\r?\n.*?(?=^## |\z)'
).Value.TrimEnd()
Assert-True (-not [string]::IsNullOrWhiteSpace($implementationLinkContractSection)) 'Implementation linkage contract fixture must locate its canonical section'
$implementationLinkContractRows = @{}
foreach ($recordName in @('selected-unit', 'changed-file', 'test-evidence')) {
  $implementationLinkContractRows[$recordName] = [regex]::Match(
    $implementationLinkContractSection,
    "(?m)^\| ``$([regex]::Escape($recordName))`` \|.*\|\s*$"
  ).Value.TrimEnd([char[]]"`r`n")
  Assert-True (-not [string]::IsNullOrWhiteSpace($implementationLinkContractRows[$recordName])) "Implementation linkage contract fixture must locate $recordName row"
}
$implementationLinkContractHeader = @'
| Record | Current step ID | Allowed predecessor step IDs | Section | Required columns |
|---|---|---|---|---|
'@.TrimEnd()

$implementationLinkContractMutations = [Collections.Generic.List[object]]::new()
$implementationLinkContractMutations.Add([pscustomobject]@{
  Name = 'missing section'
  Text = [regex]::Replace($activationContractOriginal, '(?ms)^## Implementation linkage\s*\r?\n.*?(?=^## |\z)', '')
  Expected = 'implementation linkage contract section must appear exactly once; found 0'
})
$implementationLinkContractMutations.Add([pscustomobject]@{
  Name = 'duplicate section'
  Text = $activationContractOriginal.TrimEnd() + "`n`n$implementationLinkContractSection`n"
  Expected = 'implementation linkage contract section must appear exactly once; found 2'
})
$emptyImplementationLinkContract = $activationContractOriginal
foreach ($recordName in @('selected-unit', 'changed-file', 'test-evidence')) {
  $emptyImplementationLinkContract = [regex]::Replace(
    $emptyImplementationLinkContract,
    "(?m)^$([regex]::Escape($implementationLinkContractRows[$recordName]))\r?\n?",
    ''
  )
}
$implementationLinkContractMutations.Add([pscustomobject]@{
  Name = 'empty rule table'
  Text = $emptyImplementationLinkContract
  Expected = 'implementation linkage contract must declare exactly one selected-unit rule; found 0'
})
foreach ($recordName in @('selected-unit', 'changed-file', 'test-evidence')) {
  $missingRecordContract = [regex]::Replace(
    $activationContractOriginal,
    "(?m)^$([regex]::Escape($implementationLinkContractRows[$recordName]))\r?\n?",
    ''
  )
  $implementationLinkContractMutations.Add([pscustomobject]@{
    Name = "missing $recordName rule"
    Text = $missingRecordContract
    Expected = "implementation linkage contract must declare exactly one $recordName rule; found 0"
  })
  $duplicateRecordContract = $activationContractOriginal.Replace(
    $implementationLinkContractRows[$recordName],
    "$($implementationLinkContractRows[$recordName])`n$($implementationLinkContractRows[$recordName])"
  )
  $implementationLinkContractMutations.Add([pscustomobject]@{
    Name = "duplicate $recordName rule"
    Text = $duplicateRecordContract
    Expected = "implementation linkage contract must declare exactly one $recordName rule; found 2"
  })
}
$separatedImplementationRuleTables = $activationContractOriginal.Replace(
  $implementationLinkContractRows['changed-file'],
  "`n$implementationLinkContractHeader`n$($implementationLinkContractRows['changed-file'])"
)
$implementationLinkContractMutations.Add([pscustomobject]@{
  Name = 'separated rule tables'
  Text = $separatedImplementationRuleTables
  Expected = 'implementation linkage contract rule table must appear exactly once; found 2'
})

foreach ($implementationLinkContractMutation in $implementationLinkContractMutations) {
  try {
    Assert-True ($implementationLinkContractMutation.Text -ne $activationContractOriginal) "Implementation linkage contract mutation must alter production: $($implementationLinkContractMutation.Name)"
    [IO.File]::WriteAllText($activationContractFixture, $implementationLinkContractMutation.Text, [Text.UTF8Encoding]::new($false))
    $implementationLinkContractMutationResult = Invoke-ActivationSliceArtifactValidator $implementationActivationArtifact $approvedPlanActivationSlice
    Assert-True ($implementationLinkContractMutationResult.ExitCode -eq 1) "Artifact validation must fail closed for implementation linkage contract mutation: $($implementationLinkContractMutation.Name). Output: $($implementationLinkContractMutationResult.Output)"
    Assert-Contains $implementationLinkContractMutationResult.Output $implementationLinkContractMutation.Expected "Implementation linkage contract mutation: $($implementationLinkContractMutation.Name)"
  }
  finally {
    [IO.File]::WriteAllBytes($activationContractFixture, $activationContractOriginalBytes)
  }
}

if (-not $ActivationSliceContractOnly -and -not $ActivationSliceScenariosOnly) {
  $finalFixClusters = @(
    'Yaml',
    'Resume',
    'Downstream',
    'Lifecycle',
    'Orchestrator',
    'Markdown',
    'Duplicates',
    'Pipes'
  )
  $finalFixResults = @(Invoke-FinalFixClusters -Clusters $finalFixClusters -MaxConcurrency 4)
  foreach ($finalFixResult in $finalFixResults) {
    Assert-True `
      ($finalFixResult.ExitCode -eq 0) `
      "Activation Slice final-fix cluster $($finalFixResult.Cluster) should pass. Output: $($finalFixResult.Output)"
  }
}

if ($ActivationSliceScenariosOnly) {
  if ($testFailures.Count -gt 0) {
    $testFailures | ForEach-Object { Write-Output "FAIL: $_" }
    exit 1
  }
  Write-Output 'PASS: Activation Slice artifact scenarios'
  exit 0
}

$activationContractTokens = @(
  'ACT-###',
  'applicable | not-applicable-approved | unknown',
  'upstream-response',
  'requested-key',
  'parse-model',
  'state-holder',
  'selector',
  'construct',
  'render',
  'downstream-consumer',
  'test',
  'implement | reuse | deferred-approved | not-applicable-approved',
  'verified | missing | conflict | unknown',
  'base-owned',
  'specialized-owned',
  'injected-strategy',
  'compatibility-dual-path',
  'Router Policy | Artifact location | Required key | Required value',
  'compatibility-reason=<non-empty>',
  'router-owner=<non-empty>',
  'PARITY-###',
  'Classification | Artifact location | Required key | Required value',
  'async-classification=async',
  'async-classification=immutable',
  'initial-loading=<non-empty>',
  'update-watch=<non-empty>',
  'reselection=<non-empty>',
  'state-preservation-reset=<non-empty>',
  'failure-behavior=<non-empty>',
  'lifecycle-test-trace=<trace-id>',
  'immutability-evidence=<non-empty>',
  'status: draft',
  'result: blocked',
  'It must not be reported as `partial`.'
)
foreach ($activationContractToken in $activationContractTokens) {
  try {
    $mutatedActivationContract = $activationContractOriginal.Replace($activationContractToken, '__removed__')
    Assert-True ($mutatedActivationContract -ne $activationContractOriginal) "Activation Slice mutation must alter the canonical token: $activationContractToken"
    [IO.File]::WriteAllText($activationContractFixture, $mutatedActivationContract, [Text.UTF8Encoding]::new($false))
    $contracts = Invoke-Validator 'Contracts'
    Assert-True ($contracts.ExitCode -eq 1) "Activation Slice contract without $activationContractToken should fail. Output: $($contracts.Output)"
    Assert-Contains $contracts.Output "FAIL: Activation Slice contract missing: $activationContractToken" "Activation Slice contract token: $activationContractToken"
  }
  finally {
    [IO.File]::WriteAllBytes($activationContractFixture, $activationContractOriginalBytes)
  }
}

$activationContractSchema = 'Activation Slice ID | Applicability | Seam | Input | Output | Source Reference | Trace IDs | Disposition | Status | Decision Reference | Deferred Unit ID'
try {
  $missingActivationContractHeading = $activationContractOriginal.Replace('## Async lifecycle', '## Asynchronous lifecycle')
  Assert-True ($missingActivationContractHeading -ne $activationContractOriginal) 'Activation Slice heading mutation must alter the contract'
  [IO.File]::WriteAllText($activationContractFixture, $missingActivationContractHeading, [Text.UTF8Encoding]::new($false))
  $contracts = Invoke-Validator 'Contracts'
  Assert-True ($contracts.ExitCode -eq 1) "Activation Slice contract without Async lifecycle heading should fail. Output: $($contracts.Output)"
  Assert-Contains $contracts.Output 'FAIL: Activation Slice contract missing section: Async lifecycle' 'Activation Slice required heading'
}
finally {
  [IO.File]::WriteAllBytes($activationContractFixture, $activationContractOriginalBytes)
}

try {
  $missingActivationContractColumn = Replace-InMarkdownSection $activationContractOriginal 'Artifact row schema' ' | Deferred Unit ID |' ' | Deferred Unit |'
  Assert-True ($missingActivationContractColumn -ne $activationContractOriginal) 'Activation Slice schema-column mutation must alter the contract'
  [IO.File]::WriteAllText($activationContractFixture, $missingActivationContractColumn, [Text.UTF8Encoding]::new($false))
  $contracts = Invoke-Validator 'Contracts'
  Assert-True ($contracts.ExitCode -eq 1) "Activation Slice contract without the Deferred Unit ID schema column should fail. Output: $($contracts.Output)"
  Assert-Contains $contracts.Output "FAIL: Activation Slice contract artifact row schema must be exactly: $activationContractSchema" 'Activation Slice row schema'
}
finally {
  [IO.File]::WriteAllBytes($activationContractFixture, $activationContractOriginalBytes)
}

try {
  $reorderedActivationContractSeams = Replace-InMarkdownSection $activationContractOriginal 'Canonical seams' '1. `upstream-response`' '1. `requested-key`'
  Assert-True ($reorderedActivationContractSeams -ne $activationContractOriginal) 'Activation Slice seam-order mutation must alter the contract'
  [IO.File]::WriteAllText($activationContractFixture, $reorderedActivationContractSeams, [Text.UTF8Encoding]::new($false))
  $contracts = Invoke-Validator 'Contracts'
  Assert-True ($contracts.ExitCode -eq 1) "Activation Slice contract with reordered seams should fail. Output: $($contracts.Output)"
  Assert-Contains $contracts.Output 'FAIL: Activation Slice contract canonical seams must be exactly: upstream-response, requested-key, parse-model, state-holder, selector, construct, render, downstream-consumer, test' 'Activation Slice seam order'
}
finally {
  [IO.File]::WriteAllBytes($activationContractFixture, $activationContractOriginalBytes)
}

try {
  $extraActivationContractSeam = Replace-InMarkdownSection $activationContractOriginal 'Canonical seams' '9. `test`' ('9. `test`' + [Environment]::NewLine + '10. `unexpected-seam`')
  Assert-True ($extraActivationContractSeam -ne $activationContractOriginal) 'Activation Slice seam-count mutation must alter the contract'
  [IO.File]::WriteAllText($activationContractFixture, $extraActivationContractSeam, [Text.UTF8Encoding]::new($false))
  $contracts = Invoke-Validator 'Contracts'
  Assert-True ($contracts.ExitCode -eq 1) "Activation Slice contract with ten seams should fail. Output: $($contracts.Output)"
  Assert-Contains $contracts.Output 'FAIL: Activation Slice contract canonical seams must be exactly: upstream-response, requested-key, parse-model, state-holder, selector, construct, render, downstream-consumer, test' 'Activation Slice exactly-nine seams'
}
finally {
  [IO.File]::WriteAllBytes($activationContractFixture, $activationContractOriginalBytes)
}

$technicalDesignExecutionGate = 'Technical design is not executable until router ownership and asynchronous reselection/lifecycle decisions are resolved.'
try {
  $missingTechnicalDesignExecutionGate = $activationContractOriginal.Replace($technicalDesignExecutionGate, '__removed__')
  if ($missingTechnicalDesignExecutionGate -ceq $activationContractOriginal) {
    throw 'Technical-design execution-gate mutation did not alter the Activation Slice contract'
  }
  [IO.File]::WriteAllText($activationContractFixture, $missingTechnicalDesignExecutionGate, [Text.UTF8Encoding]::new($false))
  $contracts = Invoke-Validator 'Contracts'
  Assert-True ($contracts.ExitCode -eq 1) "Activation Slice contract without the technical-design execution gate should fail. Output: $($contracts.Output)"
  Assert-Contains $contracts.Output "FAIL: Activation Slice contract missing: $technicalDesignExecutionGate" 'Activation Slice technical-design execution gate'
}
finally {
  [IO.File]::WriteAllBytes($activationContractFixture, $activationContractOriginalBytes)
}

try {
  $wrongRouterEvidenceLocation = Replace-InMarkdownSection `
    $activationContractOriginal `
    'Router evidence schema' `
    '`construct.Output`' `
    '`construct.Input`'
  Assert-True ($wrongRouterEvidenceLocation -ne $activationContractOriginal) 'Router evidence location mutation must alter the contract'
  [IO.File]::WriteAllText($activationContractFixture, $wrongRouterEvidenceLocation, [Text.UTF8Encoding]::new($false))
  $contracts = Invoke-Validator 'Contracts'
  Assert-True ($contracts.ExitCode -eq 1) "Router policy declared in construct.Input should fail. Output: $($contracts.Output)"
  Assert-Contains $contracts.Output 'FAIL: Activation Slice contract Router evidence schema rules must match the canonical definition' 'Router evidence schema location'
}
finally {
  [IO.File]::WriteAllBytes($activationContractFixture, $activationContractOriginalBytes)
}

try {
  $wrongAsyncClassificationLocation = Replace-InMarkdownSection `
    $activationContractOriginal `
    'Async evidence schema' `
    '`selector.Input`' `
    '`selector.Output`'
  Assert-True ($wrongAsyncClassificationLocation -ne $activationContractOriginal) 'Async classification location mutation must alter the contract'
  [IO.File]::WriteAllText($activationContractFixture, $wrongAsyncClassificationLocation, [Text.UTF8Encoding]::new($false))
  $contracts = Invoke-Validator 'Contracts'
  Assert-True ($contracts.ExitCode -eq 1) "Async classification declared outside selector.Input should fail. Output: $($contracts.Output)"
  Assert-Contains $contracts.Output 'FAIL: Activation Slice contract Async evidence schema rules must match the canonical definition' 'Async evidence schema location'
}
finally {
  [IO.File]::WriteAllBytes($activationContractFixture, $activationContractOriginalBytes)
}

$activationContractRuleMutations = @(
  [pscustomobject]@{
    Name = 'Unicode-capable Activation Slice ID format'
    Section = 'Identifier formats'
    From = '`ACT-[0-9]{3}`'
    To = '`ACT-\d{3}`'
    Expected = 'FAIL: Activation Slice contract Identifier formats rules must match the canonical definition'
  }
  [pscustomobject]@{
    Name = 'Unicode-capable Migration Unit ID format'
    Section = 'Identifier formats'
    From = '| Migration Unit ID | `UNIT-[0-9]{3}` |'
    To = '| Migration Unit ID | `UNIT-\d{3}` |'
    Expected = 'FAIL: Activation Slice contract Identifier formats rules must match the canonical definition'
  }
  [pscustomobject]@{
    Name = 'missing Input requirement'
    Section = 'Field requirements'
    From = '| Input | `<non-empty>` |'
    To = '| Input | `<optional>` |'
    Expected = 'FAIL: Activation Slice contract Field requirements rules must match the canonical definition'
  }
  [pscustomobject]@{
    Name = 'not-applicable unknown status'
    Section = 'Legal row combinations'
    From = '| `not-applicable-approved` | `not-applicable-approved` | `verified` | `<approval-reference>` | `not-applicable` |'
    To = '| `not-applicable-approved` | `not-applicable-approved` | `unknown` | `<approval-reference>` | `not-applicable` |'
    Expected = 'FAIL: Activation Slice contract Legal row combinations rules must match the canonical definition'
  }
  [pscustomobject]@{
    Name = 'blocking partial front matter'
    Section = 'Completion and blocking rules'
    From = '| `activation-blocking` | `draft` | `blocked` |'
    To = '| `activation-blocking` | `draft` | `partial` |'
    Expected = 'FAIL: Activation Slice contract Completion and blocking rules lifecycle rules must match the canonical definition'
  }
  [pscustomobject]@{
    Name = 'baseline-waiver resume approval source'
    Section = 'Step 10 baseline-waiver resume'
    From = '| `approval_source` | `auto-waive` |'
    To = '| `approval_source` | `auto` |'
    Expected = 'FAIL: Activation Slice contract Step 10 baseline-waiver resume rules must match the canonical definition'
  }
  [pscustomobject]@{
    Name = 'baseline-waiver resume predecessor lifecycle'
    Section = 'Immediate predecessor roles and lifecycle'
    From = '| `baseline-waiver-resume` | `10-code-migration` | `approved/partial, draft/blocked` | `10-code-migration` | `approved` | `partial` | `auto-waive` | `exact-baseline-waiver` | `incremental/preserve-existing` | `not-required` |'
    To = '| `baseline-waiver-resume` | `10-code-migration` | `approved/partial, draft/blocked` | `10-code-migration` | `approved` | `complete` | `auto-waive` | `exact-baseline-waiver` | `incremental/preserve-existing` | `not-required` |'
    Expected = 'FAIL: Activation Slice contract Immediate predecessor roles and lifecycle rules must match the canonical definition'
  }
  [pscustomobject]@{
    Name = 'Source Reference append-only shape'
    Section = 'Source Reference enrichment'
    From = '| `Source Reference` | `exact or <predecessor>; <non-whitespace evidence>` |'
    To = '| `Source Reference` | `arbitrary prefix` |'
    Expected = 'FAIL: Activation Slice contract Source Reference enrichment rules must match the canonical definition'
  }
  [pscustomobject]@{
    Name = 'selected-unit linkage section'
    Section = 'Implementation linkage'
    From = '| `selected-unit` | `10-code-migration` | `08-plan-waves, 09-bootstrap-target, 10-code-migration` | `Selected Migration Unit` |'
    To = '| `selected-unit` | `10-code-migration` | `08-plan-waves, 09-bootstrap-target, 10-code-migration` | `Selected Unit` |'
    Expected = 'FAIL: Activation Slice contract Implementation linkage rules must match the canonical definition'
  }
)
foreach ($activationContractRuleMutation in $activationContractRuleMutations) {
  try {
    $mutatedActivationContractRule = Replace-InMarkdownSection `
      $activationContractOriginal `
      $activationContractRuleMutation.Section `
      $activationContractRuleMutation.From `
      $activationContractRuleMutation.To
    Assert-True ($mutatedActivationContractRule -ne $activationContractOriginal) "Activation Slice contract rule mutation must alter production: $($activationContractRuleMutation.Name)"
    [IO.File]::WriteAllText($activationContractFixture, $mutatedActivationContractRule, [Text.UTF8Encoding]::new($false))
    $contracts = Invoke-Validator 'Contracts'
    Assert-True ($contracts.ExitCode -eq 1) "Activation Slice contract rule drift should fail: $($activationContractRuleMutation.Name). Output: $($contracts.Output)"
    Assert-Contains $contracts.Output $activationContractRuleMutation.Expected "Activation Slice contract rule drift: $($activationContractRuleMutation.Name)"
  }
  finally {
    [IO.File]::WriteAllBytes($activationContractFixture, $activationContractOriginalBytes)
  }
}

$contractOwnedRuleSections = @(
  'Identifier formats',
  'Field requirements',
  'Legal row combinations',
  'Completion and blocking rules',
  'Domain-blocker evidence',
  'Step 10 baseline-waiver resume',
  'Step 10 resume evidence',
  'Step 10 resume state',
  'Step 10 native blocker eligibility',
  'Immediate predecessor roles and lifecycle',
  'Bootstrap selected-unit handoff',
  'Step 10 predecessor unit selection',
  'Direct-plan foundation state',
  'Downstream selected-unit handoff',
  'Regression parity handoff',
  'Assurance task provenance handoff',
  'Assurance verdict consistency',
  'Source Reference enrichment',
  'Router evidence schema',
  'Async evidence schema'
)
foreach ($contractOwnedRuleSection in $contractOwnedRuleSections) {
  $ownedSectionMatch = [regex]::Match(
    $activationContractOriginal,
    "(?ms)^## $([regex]::Escape($contractOwnedRuleSection))\s*\r?\n.*?(?=^## |\z)"
  )
  Assert-True $ownedSectionMatch.Success "Contract-owned rule fixture must locate section: ${contractOwnedRuleSection}"
  $ownedSection = $ownedSectionMatch.Value.TrimEnd()
  $ownedTableMatch = [regex]::Match($ownedSection, '(?ms)^\|.*?\|\s*\r?\n\|(?:\s*:?-{3,}:?\s*\|)+\s*\r?\n(?<rows>(?:^\|.*\|\s*\r?\n?)+)')
  Assert-True $ownedTableMatch.Success "Contract-owned rule fixture must locate table: ${contractOwnedRuleSection}"
  $ownedTable = $ownedTableMatch.Value.TrimEnd()
  $ownedRows = @($ownedTableMatch.Groups['rows'].Value -split '\r?\n' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  Assert-True ($ownedRows.Count -gt 0) "Contract-owned rule fixture must locate rows: ${contractOwnedRuleSection}"
  $ownedHeader = $ownedTable.Substring(0, $ownedTable.IndexOf($ownedRows[0], [StringComparison]::Ordinal)).TrimEnd()

  $ownedRuleMutations = @(
    [pscustomobject]@{
      Name = 'duplicate section'
      Text = $activationContractOriginal.TrimEnd() + "`n`n$ownedSection`n"
    }
    [pscustomobject]@{
      Name = 'separated duplicate table'
      Text = Replace-InMarkdownSection $activationContractOriginal $contractOwnedRuleSection $ownedTable "$ownedTable`n`nseparated duplicate`n`n$ownedTable"
    }
    [pscustomobject]@{
      Name = 'duplicate rule row'
      Text = Replace-InMarkdownSection $activationContractOriginal $contractOwnedRuleSection $ownedRows[0] "$($ownedRows[0])`n$($ownedRows[0])"
    }
    [pscustomobject]@{
      Name = 'missing rule row'
      Text = ([regex]::new("(?m)^$([regex]::Escape($ownedRows[0]))\r?\n?")).Replace(
        $activationContractOriginal,
        '',
        1
      )
    }
    [pscustomobject]@{
      Name = 'empty rule rows'
      Text = Replace-InMarkdownSection $activationContractOriginal $contractOwnedRuleSection $ownedTable $ownedHeader
    }
  )
  foreach ($ownedRuleMutation in $ownedRuleMutations) {
    try {
      if ($ownedRuleMutation.Text -ceq $activationContractOriginal) {
        throw "Contract-owned rule mutation did not alter ${contractOwnedRuleSection}: $($ownedRuleMutation.Name)"
      }
      [IO.File]::WriteAllText($activationContractFixture, $ownedRuleMutation.Text, [Text.UTF8Encoding]::new($false))
      $ownedRuleResult = Invoke-Validator 'Contracts'
      Assert-True ($ownedRuleResult.ExitCode -eq 1) "Contract-owned $contractOwnedRuleSection must reject $($ownedRuleMutation.Name). Output: $($ownedRuleResult.Output)"
    }
    finally {
      [IO.File]::WriteAllBytes($activationContractFixture, $activationContractOriginalBytes)
    }
  }
}

if ($ActivationSliceContractOnly) {
  if ($testFailures.Count -gt 0) {
    $testFailures | ForEach-Object { Write-Output "FAIL: $_" }
    exit 1
  }
  Write-Output 'PASS: Activation Slice contract scenarios'
  exit 0
}

$templates = Invoke-Validator 'Templates'
Assert-True ($templates.ExitCode -eq 0) "Templates should pass. Output: $($templates.Output)"

$assuranceTemplateFixture = Join-Path $PSScriptRoot '../templates/migration/parity-report.md'
$assuranceTemplateOriginalBytes = [IO.File]::ReadAllBytes($assuranceTemplateFixture)
$assuranceTemplateOriginal = [Text.Encoding]::UTF8.GetString($assuranceTemplateOriginalBytes)
try {
  $malformedAssurancePlaceholder = $assuranceTemplateOriginal.Replace(
    '<pass / fail / blocked>',
    '<pass | fail | blocked>'
  )
  Assert-True `
    ($malformedAssurancePlaceholder -cne $assuranceTemplateOriginal) `
    'Assurance template structural-pipe mutation must alter parity-report.md'
  [IO.File]::WriteAllText(
    $assuranceTemplateFixture,
    $malformedAssurancePlaceholder,
    [Text.UTF8Encoding]::new($false)
  )
  $malformedAssuranceTemplateResult = Invoke-Validator 'Templates'
  Assert-True `
    ($malformedAssuranceTemplateResult.ExitCode -eq 1) `
    "Assurance scenario placeholders with raw table pipes must fail. Output: $($malformedAssuranceTemplateResult.Output)"
  Assert-Contains `
    $malformedAssuranceTemplateResult.Output `
    'Template parity-report.md assurance scenarios' `
    'Assurance template structural-pipe mutation'
}
finally {
  [IO.File]::WriteAllBytes($assuranceTemplateFixture, $assuranceTemplateOriginalBytes)
}

$skills = Invoke-Validator 'Skills'
Assert-True ($skills.ExitCode -eq 0) "Skills should pass. Output: $($skills.Output)"

$activationSkillMutations = @(
  [pscustomobject]@{
    Path = '../skills/migration/discovery/SKILL.md'
    From = 'contracts/activation-slice.md'
    To = 'contracts/removed-activation-slice.md'
    Label = 'discovery contract read'
    Expected = 'FAIL: Skill migration/discovery/SKILL.md Activation Slice responsibility missing: contracts/activation-slice.md'
  }
  [pscustomobject]@{
    Path = '../skills/migration/discovery/SKILL.md'
    From = 'never `result: partial`'
    To = 'may remain `result: partial`'
    Label = 'discovery activation blocker'
    Expected = 'FAIL: Skill migration/discovery/SKILL.md Activation Slice responsibility missing: never `result: partial`'
  }
  [pscustomobject]@{
    Path = '../skills/migration/build-inventory/SKILL.md'
    From = 'Preserve the same `ACT-###` Activation Slice ID and every seam row with its trace IDs'
    To = 'Create a new Activation Slice ID and collapse seam rows by component'
    Label = 'inventory Activation Slice handoff'
    Expected = 'FAIL: Skill migration/build-inventory/SKILL.md Activation Slice responsibility missing: Preserve the same `ACT-###` Activation Slice ID and every seam row with its trace IDs'
  }
  [pscustomobject]@{
    Path = '../skills/migration/feature-mapping/SKILL.md'
    From = '`deferred-approved` requires both `Decision Reference` and `Deferred Unit ID`'
    To = '`deferred-approved` may omit its approval and destination'
    Label = 'mapping deferred seam gate'
    Expected = 'FAIL: Skill migration/feature-mapping/SKILL.md Activation Slice responsibility missing: `deferred-approved` requires both `Decision Reference` and `Deferred Unit ID`'
  }
  [pscustomobject]@{
    Path = '../skills/migration/analyze-gaps-conflicts/SKILL.md'
    From = 'Unresolved router ownership is a blocking conflict and requires `result: blocked`.'
    To = 'Unresolved router ownership is informational and permits a partial result.'
    Label = 'gaps router ownership gate'
    Expected = 'FAIL: Skill migration/analyze-gaps-conflicts/SKILL.md Activation Slice responsibility missing: Unresolved router ownership is a blocking conflict and requires `result: blocked`.'
  }
  [pscustomobject]@{
    Path = '../skills/migration/technical-design/SKILL.md'
    From = 'initial loading, update/watch, reselection, failure behavior, and lifecycle test'
    To = 'initial loading and one-shot selection'
    Label = 'technical-design async lifecycle'
    Expected = 'FAIL: Skill migration/technical-design/SKILL.md Activation Slice responsibility missing: initial loading, update/watch, reselection, failure behavior, and lifecycle test'
  }
  [pscustomobject]@{
    Path = '../skills/migration/plan-waves/SKILL.md'
    From = 'Acceptance must not declare the module `activatable` while any required seam is `deferred-approved`.'
    To = 'Acceptance may declare the module `activatable` while required seams are deferred.'
    Label = 'plan activatable acceptance gate'
    Expected = 'FAIL: Skill migration/plan-waves/SKILL.md Activation Slice responsibility missing: Acceptance must not declare the module `activatable` while any required seam is `deferred-approved`.'
  }
  [pscustomobject]@{
    Path = '../skills/migration/code-migration/SKILL.md'
    From = 'Validate the approved `Activation Slice` at the `Entry gate`'
    To = 'Infer activation scope after implementation starts'
    Label = 'code-migration Activation Slice entry gate'
    Expected = 'FAIL: Skill migration/code-migration/SKILL.md Activation Slice responsibility missing: Validate the approved `Activation Slice` at the `Entry gate`'
  }
  [pscustomobject]@{
    Path = '../skills/migration/code-migration/SKILL.md'
    From = 'Every changed-file row and every test evidence record must link to the approved Activation Slice seam and its trace IDs.'
    To = 'Changed-file rows and test evidence need not link to an Activation Slice seam or trace IDs.'
    Label = 'code-migration seam trace linkage'
    Expected = 'FAIL: Skill migration/code-migration/SKILL.md Activation Slice output contract missing: Every changed-file row and every test evidence record must link to the approved Activation Slice seam and its trace IDs.'
  }
  [pscustomobject]@{
    Path = '../skills/shared/ai-review/SKILL.md'
    From = 'A missing seam that prevents activation is `Critical`.'
    To = 'A missing seam that prevents activation is Minor.'
    Label = 'AI review activation severity'
    Expected = 'FAIL: Skill shared/ai-review/SKILL.md Activation Slice responsibility missing: A missing seam that prevents activation is `Critical`.'
  }
  [pscustomobject]@{
    Path = '../skills/shared/ai-review/SKILL.md'
    From = 'Untraced duplicate ownership or missing lifecycle coverage is at least `Major`, and becomes `Critical` when it causes a correctness failure.'
    To = 'Untraced duplicate ownership or missing lifecycle coverage is Minor.'
    Label = 'AI review ownership lifecycle severity'
    Expected = 'FAIL: Skill shared/ai-review/SKILL.md Activation Slice responsibility missing: Untraced duplicate ownership or missing lifecycle coverage is at least `Major`, and becomes `Critical` when it causes a correctness failure.'
  }
  [pscustomobject]@{
    Path = '../skills/migration/analyze-requirements-uiux/SKILL.md'
    From = $activationEnvelopeRequirement
    To = 'Reconstruct the Activation Slice from cumulative requirements artifacts.'
    Label = 'requirements immediate-predecessor Activation Slice handoff'
    Expected = "FAIL: Skill migration/analyze-requirements-uiux/SKILL.md Activation Slice chain missing: $activationEnvelopeRequirement"
  }
  [pscustomobject]@{
    Path = '../skills/migration/bootstrap-target/SKILL.md'
    From = $activationEnvelopeRequirement
    To = 'Reconstruct the Activation Slice from cumulative plan artifacts.'
    Label = 'bootstrap immediate-predecessor Activation Slice handoff'
    Expected = "FAIL: Skill migration/bootstrap-target/SKILL.md Activation Slice chain missing: $activationEnvelopeRequirement"
  }
  [pscustomobject]@{
    Path = '../skills/shared/verification-testing/SKILL.md'
    From = $activationEnvelopeRequirement
    To = 'Reconstruct the Activation Slice from the implementation diff.'
    Label = 'verification immediate-predecessor Activation Slice handoff'
    Expected = "FAIL: Skill shared/verification-testing/SKILL.md Activation Slice chain missing: $activationEnvelopeRequirement"
  }
  [pscustomobject]@{
    Path = '../skills/migration/verify-parity/SKILL.md'
    From = $activationEnvelopeRequirement
    To = 'Reconstruct the Activation Slice from cumulative verification artifacts.'
    Label = 'parity immediate-predecessor Activation Slice handoff'
    Expected = "FAIL: Skill migration/verify-parity/SKILL.md Activation Slice chain missing: $activationEnvelopeRequirement"
  }
  [pscustomobject]@{
    Path = '../skills/migration/verify-regression/SKILL.md'
    From = $activationEnvelopeRequirement
    To = 'Reconstruct the Activation Slice from cumulative parity artifacts.'
    Label = 'regression immediate-predecessor Activation Slice handoff'
    Expected = "FAIL: Skill migration/verify-regression/SKILL.md Activation Slice chain missing: $activationEnvelopeRequirement"
  }
)
foreach ($activationSkillMutation in $activationSkillMutations) {
  $activationSkillFixture = Join-Path $PSScriptRoot $activationSkillMutation.Path
  $activationSkillOriginalBytes = [IO.File]::ReadAllBytes($activationSkillFixture)
  $activationSkillOriginal = [Text.Encoding]::UTF8.GetString($activationSkillOriginalBytes)
  try {
    $mutatedActivationSkill = $activationSkillOriginal.Replace(
      $activationSkillMutation.From,
      $activationSkillMutation.To
    )
    Assert-True `
      ($mutatedActivationSkill -ne $activationSkillOriginal) `
      "Activation Slice skill mutation must alter the production fixture: $($activationSkillMutation.Label)"
    [IO.File]::WriteAllText($activationSkillFixture, $mutatedActivationSkill, [Text.UTF8Encoding]::new($false))
    $skills = Invoke-Validator 'Skills'
    Assert-True `
      ($skills.ExitCode -eq 1) `
      "Activation Slice skill mutation should fail: $($activationSkillMutation.Label). Output: $($skills.Output)"
    Assert-Contains $skills.Output $activationSkillMutation.Expected $activationSkillMutation.Label
  }
  finally {
    [IO.File]::WriteAllBytes($activationSkillFixture, $activationSkillOriginalBytes)
  }
}

$orchestrators = Invoke-Validator 'Orchestrators'
Assert-True ($orchestrators.ExitCode -eq 0) "Orchestrators should pass. Output: $($orchestrators.Output)"

$onboarding = Invoke-Validator 'Onboarding'
Assert-True ($onboarding.ExitCode -eq 0) "Onboarding should pass. Output: $($onboarding.Output)"

$compatibility = Invoke-Validator 'Compatibility'
Assert-True ($compatibility.ExitCode -eq 0) "Compatibility should pass. Output: $($compatibility.Output)"

$docs = Invoke-Validator 'Docs'
Assert-True ($docs.ExitCode -eq 0) "Docs should pass. Output: $($docs.Output)"

$changeHygieneFixtures = @(
  [pscustomobject]@{
    Path = '../skills/shared/change-hygiene.md'
    From = 'An existing file may contain formatting changes only in the edited region or minimum adjacent syntax required for validity.'
    To = 'An existing file may format the complete file.'
    Check = 'Skills'
    Failure = 'Shared change-hygiene contract missing'
  }
  [pscustomobject]@{
    Path = '../skills/shared/change-hygiene.md'
    From = 'A new file may be formatted completely.'
    To = 'A new file must not be formatted completely.'
    Check = 'Skills'
    Failure = 'Shared change-hygiene contract missing: A new file may be formatted completely.'
  }
  [pscustomobject]@{
    Path = '../skills/shared/change-hygiene.md'
    From = 'Inspect the final diff and remove every untraced or formatting-only change.'
    To = 'Skip final diff inspection and keep every untraced or formatting-only change.'
    Check = 'Skills'
    Failure = 'Shared change-hygiene contract missing: Inspect the final diff and remove every untraced or formatting-only change.'
  }
  [pscustomobject]@{
    Path = '../skills/shared/change-hygiene.md'
    From = 'Never run a repository-wide formatter for a scoped functional task.'
    To = "Never run a repository-wide formatter for a scoped functional task.`n`nRepository-wide formatting is allowed when mandatory."
    Check = 'Skills'
    Failure = 'Shared change-hygiene contract permits repository-wide formatting'
  }
  [pscustomobject]@{
    Path = '../skills/shared/change-hygiene.md'
    From = "Squash only the current task's own commits; never use squash to incorporate an upstream branch."
    To = "Squash the current task's commits and may incorporate an upstream branch."
    Check = 'Skills'
    Failure = "Shared change-hygiene contract missing: Squash only the current task's own commits; never use squash to incorporate an upstream branch."
  }
  [pscustomobject]@{
    Path = '../skills/shared/change-hygiene.md'
    From = 'Never run a repository-wide formatter for a scoped functional task.'
    To = 'Run a repository-wide formatter for a scoped functional task.'
    Check = 'Skills'
    Failure = 'Shared change-hygiene contract missing'
  }
  [pscustomobject]@{
    Path = '../skills/shared/change-hygiene.md'
    From = 'one task has exactly one final delivery commit'
    To = 'one task may have multiple final delivery commits'
    Check = 'Skills'
    Failure = 'Shared change-hygiene contract missing'
  }
  [pscustomobject]@{
    Path = '../skills/shared/change-hygiene.md'
    From = 'Ancestry, commit-integrity, correctness, and diff-scope failures are not waiver-eligible.'
    To = 'Ancestry, commit-integrity, correctness, and diff-scope failures may be auto-waived.'
    Check = 'Skills'
    Failure = 'Shared change-hygiene contract missing'
  }
  [pscustomobject]@{
    Path = '../examples/project-packs/webos-qml-flutter/references/architecture-rules.md'
    From = 'git rebase origin/develop'
    To = 'git merge --squash origin/develop'
    Check = 'Compatibility'
    Failure = 'LGE ancestry rules missing: git rebase origin/develop'
  }
  [pscustomobject]@{
    Path = '../examples/project-packs/webos-qml-flutter/references/architecture-rules.md'
    From = 'The command `git merge --squash origin/develop` is forbidden.'
    To = 'The command `git merge --squash origin/develop` is allowed.'
    Check = 'Compatibility'
    Failure = 'LGE ancestry rules permit squash-copy synchronization'
  }
  [pscustomobject]@{
    Path = '../examples/project-packs/webos-qml-flutter/references/architecture-rules.md'
    From = 'The merge-base must equal the upstream tip.'
    To = 'The merge-base may remain stale.'
    Check = 'Compatibility'
    Failure = 'LGE ancestry rules missing: The merge-base must equal the upstream tip.'
  }
  [pscustomobject]@{
    Path = '../examples/project-packs/webos-qml-flutter/references/definition-of-done.md'
    From = 'git rebase origin/develop'
    To = 'git merge --squash origin/develop'
    Check = 'Compatibility'
    Failure = 'LGE task delivery rules missing: git rebase origin/develop'
  }
  [pscustomobject]@{
    Path = '../skills/migration/plan-waves/SKILL.md'
    From = 'one independently reviewable Gerrit change'
    To = 'one migration batch'
    Check = 'Skills'
    Failure = 'Plan-waves delivery boundary missing: one independently reviewable Gerrit change'
  }
  [pscustomobject]@{
    Path = '../templates/migration/migration-plan.md'
    From = 'Delivery Change Boundary'
    To = 'Delivery Batch'
    Check = 'Templates'
    Failure = 'Change-hygiene template templates/migration/migration-plan.md missing: Delivery Change Boundary'
  }
  [pscustomobject]@{
    Path = '../templates/gerrit-report.md'
    From = '## Branch and Commit Integrity'
    To = '## Delivery Notes'
    Check = 'Templates'
    Failure = 'Change-hygiene template templates/gerrit-report.md missing: ## Branch and Commit Integrity'
  }
  [pscustomobject]@{
    Path = '../templates/gerrit-report.md'
    From = ' | Actual Task Commit Count |'
    To = ' |'
    Check = 'Templates'
    Failure = 'Gerrit branch and commit integrity Branch and Commit Integrity table columns must be exactly'
  }
  [pscustomobject]@{
    Path = '../templates/implement-report.md'
    From = ' | Formatter Command |'
    To = ' |'
    Check = 'Templates'
    Failure = 'Feature implementation change hygiene Change Hygiene table columns must be exactly'
  }
  [pscustomobject]@{
    Path = '../templates/migration/review-report.md'
    From = ' | Final-tree SHA |'
    To = ' |'
    Check = 'Templates'
    Failure = 'Migration review provenance Change Hygiene table columns must be exactly'
  }
  [pscustomobject]@{
    Path = '../templates/migration/verification-report.md'
    From = ' | Final-tree SHA |'
    To = ' |'
    Check = 'Templates'
    Failure = 'Migration verification provenance Task Provenance table columns must be exactly'
  }
  [pscustomobject]@{
    Path = '../templates/kb-entry.md'
    From = ' | Task-base SHA |'
    To = ' |'
    Check = 'Templates'
    Failure = 'Knowledge Base task provenance Task Provenance table columns must be exactly'
  }
  [pscustomobject]@{
    Path = '../templates/migration/parity-report.md'
    From = ' | Source Artifact |'
    To = ' |'
    Check = 'Templates'
    Failure = 'Migration parity task provenance Task Provenance table columns must be exactly'
  }
  [pscustomobject]@{
    Path = '../skills/shared/gerrit-automation/SKILL.md'
    From = 'blocked and not waiver-eligible'
    To = 'blocked but may be auto-waived'
    Check = 'Skills'
    Failure = 'Gerrit branch and commit integrity permits waiver'
  }
  [pscustomobject]@{
    Path = '../examples/project-packs/webos-qml-flutter/references/testing-rules.md'
    From = 'After the rebase, run `flutter-webos analyze`'
    To = 'After the rebase, skip `flutter-webos analyze`'
    Check = 'Compatibility'
    Failure = 'LGE post-rebase verification permits required commands to be skipped'
  }
)

foreach ($fixture in $changeHygieneFixtures) {
  $fixturePath = Join-Path $PSScriptRoot $fixture.Path
  if (-not (Test-Path $fixturePath)) {
    Assert-True $false "Change-hygiene mutation fixture must exist: $($fixture.Path)"
    continue
  }
  $originalBytes = [IO.File]::ReadAllBytes($fixturePath)
  $originalText = [Text.Encoding]::UTF8.GetString($originalBytes)
  try {
    $mutatedText = $originalText.Replace($fixture.From, $fixture.To)
    Assert-True ($mutatedText -ne $originalText) "Change-hygiene mutation must alter $($fixture.Path): $($fixture.From)"
    [IO.File]::WriteAllText($fixturePath, $mutatedText, [Text.UTF8Encoding]::new($false))
    $result = Invoke-Validator $fixture.Check
    Assert-True ($result.ExitCode -eq 1) "Change-hygiene mutation should fail for $($fixture.Path). Output: $($result.Output)"
    Assert-Contains $result.Output "FAIL: $($fixture.Failure)" "Change-hygiene mutation $($fixture.Path)"
  }
  finally {
    [IO.File]::WriteAllBytes($fixturePath, $originalBytes)
  }
}

foreach ($consumerRelativePath in @(
  '../skills/migration/code-migration/SKILL.md',
  '../skills/feature/implement/SKILL.md',
  '../skills/bugfix/fix/SKILL.md',
  '../skills/shared/ai-review/SKILL.md',
  '../skills/shared/gerrit-automation/SKILL.md'
)) {
  $consumerPath = Join-Path $PSScriptRoot $consumerRelativePath
  $originalBytes = [IO.File]::ReadAllBytes($consumerPath)
  $originalText = [Text.Encoding]::UTF8.GetString($originalBytes)
  try {
    $mutatedText = $originalText.Replace('shared/change-hygiene.md', 'shared/missing-hygiene.md')
    Assert-True ($mutatedText -ne $originalText) "Consumer reference mutation must alter $consumerRelativePath"
    [IO.File]::WriteAllText($consumerPath, $mutatedText, [Text.UTF8Encoding]::new($false))
    $skills = Invoke-Validator 'Skills'
    Assert-True ($skills.ExitCode -eq 1) "Missing consumer hygiene reference should fail: $consumerRelativePath. Output: $($skills.Output)"
    Assert-Contains $skills.Output 'FAIL: Change-hygiene consumer' "Consumer hygiene reference $consumerRelativePath"
  }
  finally {
    [IO.File]::WriteAllBytes($consumerPath, $originalBytes)
  }
}

$selectedUnitHeadingFixtures = @(
  [pscustomobject]@{ Name = 'bootstrap-report.md'; Path = '../templates/migration/bootstrap-report.md' }
  [pscustomobject]@{ Name = 'implementation-report.md'; Path = '../templates/migration/implementation-report.md' }
  [pscustomobject]@{ Name = 'parity-report.md'; Path = '../templates/migration/parity-report.md' }
  [pscustomobject]@{ Name = 'regression-report.md'; Path = '../templates/migration/regression-report.md' }
  [pscustomobject]@{ Name = 'review-report.md'; Path = '../templates/migration/review-report.md' }
  [pscustomobject]@{ Name = 'verification-report.md'; Path = '../templates/migration/verification-report.md' }
)
foreach ($headingFixture in $selectedUnitHeadingFixtures) {
  $headingFixturePath = Join-Path $PSScriptRoot $headingFixture.Path
  $headingFixtureOriginalBytes = [IO.File]::ReadAllBytes($headingFixturePath)
  $headingFixtureOriginal = [Text.Encoding]::UTF8.GetString($headingFixtureOriginalBytes)
  try {
    $translatedHeadingMutation = $headingFixtureOriginal.Replace(
      "## $selectedMigrationUnitSection",
      "## $translatedSelectedMigrationUnitSection"
    )
    Assert-True `
      ($translatedHeadingMutation -ne $headingFixtureOriginal) `
      "Canonical selected-unit heading mutation must alter $($headingFixture.Name)"
    [IO.File]::WriteAllText(
      $headingFixturePath,
      $translatedHeadingMutation,
      [Text.UTF8Encoding]::new($false)
    )
    $templates = Invoke-Validator 'Templates'
    Assert-True `
      ($templates.ExitCode -eq 1) `
      "Translated selected-unit heading should fail for $($headingFixture.Name). Output: $($templates.Output)"
    Assert-Contains `
      $templates.Output `
      "FAIL: Template $($headingFixture.Name) canonical selected-unit heading must appear exactly once; found 0" `
      "Canonical selected-unit heading $($headingFixture.Name)"
    Assert-Contains `
      $templates.Output `
      "FAIL: Template $($headingFixture.Name) contains translated machine-contract heading: ## $translatedSelectedMigrationUnitSection" `
      "Translated selected-unit heading $($headingFixture.Name)"
  }
  finally {
    [IO.File]::WriteAllBytes($headingFixturePath, $headingFixtureOriginalBytes)
  }
}

$migrationGuideFixture = Join-Path $PSScriptRoot '../docs/MIGRATION-FRAMEWORK.md'
$migrationGuideOriginalBytes = [IO.File]::ReadAllBytes($migrationGuideFixture)
$migrationGuideOriginal = [Text.Encoding]::UTF8.GetString($migrationGuideOriginalBytes)
try {
  $onboardingStep = '2. Run `/aitoolkit:migration-onboarding` with `--legacy`, `--target`, the repeatable `--requirements`, `--uiux`, `--migration-docs`, and `--architecture-docs` flags, or let it read the optional inbox.'
  $migrateStep = '5. Run `/aitoolkit:migrate <feature-slug>`.'
  $reorderedWorkflow = $migrationGuideOriginal.Replace($onboardingStep, '__ONBOARDING_STEP__').Replace(
    $migrateStep,
    '5. Run `/aitoolkit:migration-onboarding` with `--legacy`, `--target`, the repeatable `--requirements`, `--uiux`, `--migration-docs`, and `--architecture-docs` flags, or let it read the optional inbox.'
  ).Replace(
    '__ONBOARDING_STEP__',
    '2. Run `/aitoolkit:migrate <feature-slug>`.'
  )
  Assert-True ($reorderedWorkflow -ne $migrationGuideOriginal) 'Workflow order mutation must alter the real guide fixture'
  [IO.File]::WriteAllText($migrationGuideFixture, $reorderedWorkflow, [Text.UTF8Encoding]::new($false))
  $docs = Invoke-Validator 'Docs'
  Assert-True ($docs.ExitCode -eq 1) "Reordered migration user workflow should fail. Output: $($docs.Output)"
  Assert-Contains $docs.Output 'FAIL: Migration framework guide Migration user workflow step 2 missing: /aitoolkit:migration-onboarding' 'Migration user workflow order'
}
finally {
  [IO.File]::WriteAllBytes($migrationGuideFixture, $migrationGuideOriginalBytes)
}

try {
  $stagedReviewStep = '3. Review the generated profile at `<RUN_DIR>/project-draft/project.yaml`, generated pack at `<RUN_DIR>/project-draft/migration-project`, and review artifact at `<RUN_DIR>/04-project-pack-review.md`.'
  $canonicalReviewStep = '3. Review the generated profile at `docs/aitoolkit/project.yaml` and generated pack at `docs/aitoolkit/migration-project`.'
  $canonicalBeforeApproval = $migrationGuideOriginal.Replace($stagedReviewStep, $canonicalReviewStep)
  Assert-True ($canonicalBeforeApproval -ne $migrationGuideOriginal) 'Canonical-before-approval mutation must alter the real guide fixture'
  [IO.File]::WriteAllText($migrationGuideFixture, $canonicalBeforeApproval, [Text.UTF8Encoding]::new($false))
  $docs = Invoke-Validator 'Docs'
  Assert-True ($docs.ExitCode -eq 1) "Canonical review paths before Tech Lead approval should fail. Output: $($docs.Output)"
  Assert-Contains $docs.Output 'FAIL: Migration framework guide Migration user workflow step 3 missing: <RUN_DIR>/project-draft/project.yaml' 'Staged review path contract'
}
finally {
  [IO.File]::WriteAllBytes($migrationGuideFixture, $migrationGuideOriginalBytes)
}

try {
  $modifiedPublication = $migrationGuideOriginal.Replace(
    'the HARD gate publishes those exact staged bytes',
    'the HARD gate publishes regenerated content'
  )
  Assert-True ($modifiedPublication -ne $migrationGuideOriginal) 'Exact staged-byte publication mutation must alter the real guide fixture'
  [IO.File]::WriteAllText($migrationGuideFixture, $modifiedPublication, [Text.UTF8Encoding]::new($false))
  $docs = Invoke-Validator 'Docs'
  Assert-True ($docs.ExitCode -eq 1) "Publication that does not preserve exact staged bytes should fail. Output: $($docs.Output)"
  Assert-Contains $docs.Output 'FAIL: Migration framework guide Migration user workflow step 4 missing: exact staged bytes' 'Exact staged-byte publication contract'
}
finally {
  [IO.File]::WriteAllBytes($migrationGuideFixture, $migrationGuideOriginalBytes)
}

$greenfieldProfileFixture = Join-Path $PSScriptRoot '../examples/migration/greenfield/docs/aitoolkit/project.yaml'
$greenfieldProfileOriginalBytes = [IO.File]::ReadAllBytes($greenfieldProfileFixture)
$greenfieldProfileOriginal = [Text.Encoding]::UTF8.GetString($greenfieldProfileOriginalBytes).Replace("`r`n", "`n")
try {
  $misplacedFixtureFields = $greenfieldProfileOriginal.Replace("  mode: greenfield`n", '').Replace(
    "  architecture_policy: design-new`n",
    ''
  ).Replace(
    "  regression: optional`n",
    ''
  ).Replace(
    "migration:`n",
    "migration:`n  regression: optional`n"
  ).Replace(
    "verification:`n",
    "verification:`n  mode: greenfield`n  architecture_policy: design-new`n"
  )
  [IO.File]::WriteAllText($greenfieldProfileFixture, $misplacedFixtureFields, [Text.UTF8Encoding]::new($false))
  $docs = Invoke-Validator 'Docs'
  Assert-True ($docs.ExitCode -eq 1) "Misplaced fixture fields should fail. Output: $($docs.Output)"
  Assert-Contains $docs.Output 'FAIL: Migration example fixture examples/migration/greenfield/docs/aitoolkit/project.yaml migration section must declare exactly one mode: greenfield' 'Fixture mode hierarchy'
  Assert-Contains $docs.Output 'FAIL: Migration example fixture examples/migration/greenfield/docs/aitoolkit/project.yaml verification section must declare exactly one regression: optional' 'Fixture verification hierarchy'
}
finally {
  [IO.File]::WriteAllBytes($greenfieldProfileFixture, $greenfieldProfileOriginalBytes)
}

$greenfieldTargetBaselineFixture = Join-Path $PSScriptRoot '../examples/migration/greenfield/docs/aitoolkit/migration-project/references/target-baseline.md'
$greenfieldTargetBaselineOriginalBytes = [IO.File]::ReadAllBytes($greenfieldTargetBaselineFixture)
$greenfieldTargetBaselineOriginal = [Text.Encoding]::UTF8.GetString($greenfieldTargetBaselineOriginalBytes)
try {
  $unapprovedFoundationRecord = $greenfieldTargetBaselineOriginal.Replace('| approved |', '| pending |')
  Assert-True ($unapprovedFoundationRecord -ne $greenfieldTargetBaselineOriginal) 'Foundation approval-status mutation must alter the target-baseline fixture'
  [IO.File]::WriteAllText($greenfieldTargetBaselineFixture, $unapprovedFoundationRecord, [Text.UTF8Encoding]::new($false))
  $docs = Invoke-Validator 'Docs'
  Assert-True ($docs.ExitCode -eq 1) "Later greenfield fixture with an unapproved foundation record should fail. Output: $($docs.Output)"
  Assert-Contains $docs.Output 'FAIL: Migration example fixture examples/migration/greenfield/docs/aitoolkit/project.yaml approved target baseline missing: | approved |' 'Greenfield approved foundation record'
}
finally {
  [IO.File]::WriteAllBytes($greenfieldTargetBaselineFixture, $greenfieldTargetBaselineOriginalBytes)
}

$greenfieldLaterPlanFixture = Join-Path $PSScriptRoot '../examples/migration/greenfield/docs/aitoolkit/fixture-artifacts/08-later-migration-plan.md'
$greenfieldLaterPlanOriginalBytes = [IO.File]::ReadAllBytes($greenfieldLaterPlanFixture)
$greenfieldLaterPlanOriginal = [Text.Encoding]::UTF8.GetString($greenfieldLaterPlanOriginalBytes)
try {
  $laterWithoutApprovedBaseline = $greenfieldLaterPlanOriginal.Replace('FOUNDATION-EXAMPLE-001', 'BASELINE-PENDING')
  Assert-True ($laterWithoutApprovedBaseline -ne $greenfieldLaterPlanOriginal) 'Later-unit baseline mutation must alter the greenfield fixture'
  [IO.File]::WriteAllText($greenfieldLaterPlanFixture, $laterWithoutApprovedBaseline, [Text.UTF8Encoding]::new($false))
  $docs = Invoke-Validator 'Docs'
  Assert-True ($docs.ExitCode -eq 1) "Later greenfield unit without an approved baseline should fail. Output: $($docs.Output)"
  Assert-Contains $docs.Output 'FAIL: Migration example fixture examples/migration/greenfield/docs/aitoolkit/project.yaml later migration plan Foundation Baseline ID must be FOUNDATION-EXAMPLE-001' 'Greenfield later-unit baseline fixture'
}
finally {
  [IO.File]::WriteAllBytes($greenfieldLaterPlanFixture, $greenfieldLaterPlanOriginalBytes)
}

$greenfieldFoundationPlanFixture = Join-Path $PSScriptRoot '../examples/migration/greenfield/docs/aitoolkit/fixture-artifacts/08-foundation-migration-plan.md'
$greenfieldFoundationPlanOriginalBytes = [IO.File]::ReadAllBytes($greenfieldFoundationPlanFixture)
$greenfieldFoundationPlanOriginal = [Text.Encoding]::UTF8.GetString($greenfieldFoundationPlanOriginalBytes)
try {
  $invalidFoundationFrontMatter = $greenfieldFoundationPlanOriginal.Replace('produced_at: 2026-08-11', 'updated_at: 2026-08-11')
  Assert-True ($invalidFoundationFrontMatter -ne $greenfieldFoundationPlanOriginal) 'Foundation front-matter mutation must alter the greenfield fixture'
  [IO.File]::WriteAllText($greenfieldFoundationPlanFixture, $invalidFoundationFrontMatter, [Text.UTF8Encoding]::new($false))
  $docs = Invoke-Validator 'Docs'
  Assert-True ($docs.ExitCode -eq 1) "Greenfield fixture with noncanonical plan front matter should fail. Output: $($docs.Output)"
  Assert-Contains $docs.Output 'FAIL: Migration example fixture examples/migration/greenfield/docs/aitoolkit/project.yaml foundation migration plan front matter must exactly declare step_id, approved status, complete result, human approval source, and produced_at' 'Greenfield plan front matter'
}
finally {
  [IO.File]::WriteAllBytes($greenfieldFoundationPlanFixture, $greenfieldFoundationPlanOriginalBytes)
}

try {
  $invalidLaterPlanColumns = $greenfieldLaterPlanOriginal.Replace('Dependencies | Acceptance', 'Prerequisites | Acceptance')
  Assert-True ($invalidLaterPlanColumns -ne $greenfieldLaterPlanOriginal) 'Later-plan exact-table mutation must alter the greenfield fixture'
  [IO.File]::WriteAllText($greenfieldLaterPlanFixture, $invalidLaterPlanColumns, [Text.UTF8Encoding]::new($false))
  $docs = Invoke-Validator 'Docs'
  Assert-True ($docs.ExitCode -eq 1) "Greenfield fixture with noncanonical plan columns should fail. Output: $($docs.Output)"
  Assert-Contains $docs.Output "FAIL: Migration example fixture examples/migration/greenfield/docs/aitoolkit/project.yaml later migration plan $orderedUnitsSection table columns must be exactly:" 'Greenfield plan exact table schema'
}
finally {
  [IO.File]::WriteAllBytes($greenfieldLaterPlanFixture, $greenfieldLaterPlanOriginalBytes)
}

$greenfieldBootstrapFixture = Join-Path $PSScriptRoot '../examples/migration/greenfield/docs/aitoolkit/fixture-artifacts/09-bootstrap-report.md'
$greenfieldBootstrapOriginalBytes = [IO.File]::ReadAllBytes($greenfieldBootstrapFixture)
$greenfieldBootstrapOriginal = [Text.Encoding]::UTF8.GetString($greenfieldBootstrapOriginalBytes)
try {
  $invalidBootstrapSection = $greenfieldBootstrapOriginal.Replace('## Selected Migration Unit', '## Selected Unit')
  Assert-True ($invalidBootstrapSection -ne $greenfieldBootstrapOriginal) 'Bootstrap selected-unit mutation must alter the greenfield fixture'
  [IO.File]::WriteAllText($greenfieldBootstrapFixture, $invalidBootstrapSection, [Text.UTF8Encoding]::new($false))
  $docs = Invoke-Validator 'Docs'
  Assert-True ($docs.ExitCode -eq 1) "Greenfield fixture without canonical selected-unit section should fail. Output: $($docs.Output)"
  Assert-Contains $docs.Output 'FAIL: Migration example fixture examples/migration/greenfield/docs/aitoolkit/project.yaml approved bootstrap artifact missing section: Selected Migration Unit' 'Greenfield bootstrap artifact schema'
}
finally {
  [IO.File]::WriteAllBytes($greenfieldBootstrapFixture, $greenfieldBootstrapOriginalBytes)
}

try {
  $bootstrapWithoutActivationSlice = [regex]::Replace(
    $greenfieldBootstrapOriginal,
    '(?ms)^## Activation Slice\r?\n.*?(?=^## Selected Migration Unit)',
    ''
  )
  Assert-True ($bootstrapWithoutActivationSlice -ne $greenfieldBootstrapOriginal) 'Bootstrap Activation Slice removal must alter the greenfield fixture'
  [IO.File]::WriteAllText($greenfieldBootstrapFixture, $bootstrapWithoutActivationSlice, [Text.UTF8Encoding]::new($false))
  $docs = Invoke-Validator 'Docs'
  Assert-True ($docs.ExitCode -eq 1) "A shipped 08-to-09 fixture route without its canonical Activation Slice should fail. Output: $($docs.Output)"
  Assert-Contains $docs.Output 'canonical Activation Slice section must appear exactly once; found 0' 'Greenfield fixture actual route validation'
}
finally {
  [IO.File]::WriteAllBytes($greenfieldBootstrapFixture, $greenfieldBootstrapOriginalBytes)
}

$greenfieldPackFixture = Join-Path $PSScriptRoot '../examples/migration/greenfield/docs/aitoolkit/migration-project/SKILL.md'
$greenfieldPackOriginalBytes = [IO.File]::ReadAllBytes($greenfieldPackFixture)
$greenfieldPackOriginal = [Text.Encoding]::UTF8.GetString($greenfieldPackOriginalBytes)
try {
  $invalidPackFrontMatter = $greenfieldPackOriginal.Replace('name: greenfield-migration-project-fixture', 'fixture_name: greenfield-migration-project-fixture')
  Assert-True ($invalidPackFrontMatter -ne $greenfieldPackOriginal) 'Project-pack front-matter mutation must alter the greenfield fixture'
  [IO.File]::WriteAllText($greenfieldPackFixture, $invalidPackFrontMatter, [Text.UTF8Encoding]::new($false))
  $docs = Invoke-Validator 'Docs'
  Assert-True ($docs.ExitCode -eq 1) "Greenfield project pack without canonical skill front matter should fail. Output: $($docs.Output)"
  Assert-Contains $docs.Output 'FAIL: Migration example fixture examples/migration/greenfield/docs/aitoolkit/project.yaml project pack route must declare canonical skill front matter' 'Greenfield project-pack contract'
}
finally {
  [IO.File]::WriteAllBytes($greenfieldPackFixture, $greenfieldPackOriginalBytes)
}

$incrementalProfileFixture = Join-Path $PSScriptRoot '../examples/migration/incremental/docs/aitoolkit/project.yaml'
$incrementalProfileOriginalBytes = [IO.File]::ReadAllBytes($incrementalProfileFixture)
$incrementalProfileOriginal = [Text.Encoding]::UTF8.GetString($incrementalProfileOriginalBytes)
try {
  $incrementalBootstrapRequired = $incrementalProfileOriginal.Replace(
    '      bootstrap_scope: not-required',
    '      bootstrap_scope: required'
  )
  Assert-True ($incrementalBootstrapRequired -ne $incrementalProfileOriginal) 'Incremental bootstrap mutation must alter the incremental fixture'
  [IO.File]::WriteAllText($incrementalProfileFixture, $incrementalBootstrapRequired, [Text.UTF8Encoding]::new($false))
  $docs = Invoke-Validator 'Docs'
  Assert-True ($docs.ExitCode -eq 1) "Incremental fixture requiring bootstrap should fail. Output: $($docs.Output)"
  Assert-Contains $docs.Output 'FAIL: Migration example fixture examples/migration/incremental/docs/aitoolkit/project.yaml incremental unit must declare exactly one bootstrap_scope: not-required' 'Incremental no-bootstrap fixture'
}
finally {
  [IO.File]::WriteAllBytes($incrementalProfileFixture, $incrementalProfileOriginalBytes)
}

$acceptancePolicyMutations = @(
  [pscustomobject]@{
    Number = 1
    Original = 'Migration has exactly 15 steps and ends at Knowledge Capture'
    Contradiction = 'Migration has 18 steps and does not end at Knowledge Capture'
  }
  [pscustomobject]@{
    Number = 2
    Original = 'Migration has no Gerrit, CCC, or Release route'
    Contradiction = 'Migration runs Gerrit, CCC, and Release routes'
  }
  [pscustomobject]@{
    Number = 3
    Original = 'Gerrit, CCC, and Release remain separate delivery skills invoked only by explicit calls'
    Contradiction = 'Gerrit, CCC, and Release are automatic migration-owned delivery stages'
  }
  [pscustomobject]@{
    Number = 4
    Original = 'The first greenfield foundation unit uses required bootstrap with foundation_baseline_id pending-bootstrap'
    Contradiction = 'The first greenfield foundation unit requires an approved foundation baseline before bootstrap'
  }
  [pscustomobject]@{
    Number = 5
    Original = 'Later greenfield unit uses an approved foundation baseline and does not bootstrap'
    Contradiction = 'Later greenfield unit uses no approved foundation baseline and reruns bootstrap'
  }
  [pscustomobject]@{
    Number = 6
    Original = 'Incremental preserve-existing does not bootstrap and regression remains required'
    Contradiction = 'Incremental preserve-existing may bootstrap and regression is optional'
  }
  [pscustomobject]@{
    Number = 7
    Original = 'Onboarding generates profile and project pack drafts and publishes only after Tech Lead approval'
    Contradiction = 'Onboarding requires users to author the project pack and publishes before Tech Lead approval'
  }
  [pscustomobject]@{
    Number = 8
    Original = 'Onboarding accepts explicit document flags and an optional inbox'
    Contradiction = 'Onboarding does not accept explicit document flags and makes the inbox mandatory'
  }
  [pscustomobject]@{
    Number = 9
    Original = 'Onboarding never moves or modifies source documents or production source'
    Contradiction = 'Onboarding may move source documents and modify production source'
  }
  [pscustomobject]@{
    Number = 10
    Original = 'Claude and Codex docs describe the ordered user workflow'
    Contradiction = 'Claude and Codex docs omit and reorder the user workflow'
  }
  [pscustomobject]@{
    Number = 11
    Original = 'Static validator has positive and negative coverage for pipeline boundaries and both greenfield paths'
    Contradiction = 'Static validator lacks negative coverage for pipeline boundaries and both greenfield paths'
  }
  [pscustomobject]@{
    Number = 12
    Original = 'Manual runtime and plugin evidence records only truthful PASS or BLOCKED status'
    Contradiction = 'Manual runtime and plugin evidence records an unverified PASS'
  }
)

foreach ($mutation in $acceptancePolicyMutations) {
  try {
    $contradictoryGuide = $migrationGuideOriginal.Replace($mutation.Original, $mutation.Contradiction)
    Assert-True ($contradictoryGuide -ne $migrationGuideOriginal) "Acceptance criterion $($mutation.Number) mutation must alter the real guide fixture"
    [IO.File]::WriteAllText($migrationGuideFixture, $contradictoryGuide, [Text.UTF8Encoding]::new($false))
    $docs = Invoke-Validator 'Docs'
    Assert-True ($docs.ExitCode -eq 1) "Opposite acceptance criterion $($mutation.Number) should fail. Output: $($docs.Output)"
    Assert-Contains $docs.Output "FAIL: Migration framework acceptance criterion $($mutation.Number) policy semantics invalid" "Acceptance criterion $($mutation.Number) polarity"
  }
  finally {
    [IO.File]::WriteAllBytes($migrationGuideFixture, $migrationGuideOriginalBytes)
  }
}

$documentationBoundaryMutations = @(
  [pscustomobject]@{
    Label = '18-step pipeline'
    Text = 'Migration has an 18-step pipeline.'
    Expected = 'FAIL: Migration framework guide must not claim an 18-step migration pipeline'
  }
  [pscustomobject]@{
    Label = 'implicit delivery stage'
    Text = 'Migration Gerrit consumes the terminal verification artifact.'
    Expected = 'FAIL: Migration framework guide must not claim migration runs Gerrit, CCC, or Release'
  }
  [pscustomobject]@{
    Label = 'user-authored pack'
    Text = 'Users must author the project pack before onboarding.'
    Expected = 'FAIL: Migration framework guide must not require a user-authored project pack'
  }
  [pscustomobject]@{
    Label = 'positional onboarding paths'
    Text = '$aitoolkit migration-onboarding <legacy-path> <target-path> <docs-path...>'
    Expected = 'FAIL: Migration framework guide must not document positional migration-onboarding paths'
  }
)

foreach ($mutation in $documentationBoundaryMutations) {
  try {
    $mutatedGuide = $migrationGuideOriginal + [Environment]::NewLine + $mutation.Text + [Environment]::NewLine
    [IO.File]::WriteAllText($migrationGuideFixture, $mutatedGuide, [Text.UTF8Encoding]::new($false))
    $docs = Invoke-Validator 'Docs'
    Assert-True ($docs.ExitCode -eq 1) "$($mutation.Label) documentation claim should fail. Output: $($docs.Output)"
    Assert-Contains $docs.Output $mutation.Expected "Documentation boundary $($mutation.Label)"
  }
  finally {
    [IO.File]::WriteAllBytes($migrationGuideFixture, $migrationGuideOriginalBytes)
  }
}

try {
  $truthfulNegativeBoundary = $migrationGuideOriginal + [Environment]::NewLine +
    'The old 18-step workflow was removed. Migration does not run Gerrit, CCC, or Release. Users do not author the project pack.' +
    [Environment]::NewLine
  [IO.File]::WriteAllText($migrationGuideFixture, $truthfulNegativeBoundary, [Text.UTF8Encoding]::new($false))
  $docs = Invoke-Validator 'Docs'
  Assert-True ($docs.ExitCode -eq 0) "Truthful negative boundary wording should pass. Output: $($docs.Output)"
  Assert-Contains $docs.Output 'PASS: migration framework (Docs)' 'Truthful negative documentation boundary'
}
finally {
  [IO.File]::WriteAllBytes($migrationGuideFixture, $migrationGuideOriginalBytes)
}

$passingOnboardingEvidence = '| 2026-08-11 | Codex CLI 0.146.0 | onboarding | PASS | Paused at the expected Step 02 PM/Tech Lead soft approval gate; produced readable docs/aitoolkit/2026-08-11-migration-onboarding-target/02-project-inspection.md | Codex stopped at the gate with status draft and result partial; no approval was inferred. |'
$blockedGreenfieldEvidence = '| 2026-08-11 | Codex CLI 0.146.0 | greenfield | BLOCKED | Step 01 produced docs/aitoolkit/2026-08-11-migration-foundation-example/01-input-report.md; no approval gate opened | Missing approved project-pack review metadata: reviewed_at and review_evidence were null, so the artifact returned result blocked. |'

try {
  $fakeManualPass = $migrationGuideOriginal.Replace(
    $passingOnboardingEvidence,
    '| 2026-08-11 | Codex CLI 0.146.0 | onboarding | PASS | unavailable | runtime unavailable |'
  )
  [IO.File]::WriteAllText($migrationGuideFixture, $fakeManualPass, [Text.UTF8Encoding]::new($false))
  $docs = Invoke-Validator 'Docs'
  Assert-True ($docs.ExitCode -eq 1) "Unavailable manual evidence cannot claim PASS. Output: $($docs.Output)"
  Assert-Contains $docs.Output 'FAIL: Migration framework manual evidence onboarding PASS requires an approved or expected paused gate and a produced readable artifact' 'Manual PASS evidence contract'
}
finally {
  [IO.File]::WriteAllBytes($migrationGuideFixture, $migrationGuideOriginalBytes)
}

try {
  $rejectedGatePass = $migrationGuideOriginal.Replace(
    $passingOnboardingEvidence,
    '| 2026-08-11 | Codex CLI 0.146.0 | onboarding | PASS | The expected approval gate was rejected; produced artifact docs/aitoolkit/2026-08-11-migration-example/01-input-report.md | Artifact is readable but approval was denied. |'
  )
  [IO.File]::WriteAllText($migrationGuideFixture, $rejectedGatePass, [Text.UTF8Encoding]::new($false))
  $docs = Invoke-Validator 'Docs'
  Assert-True ($docs.ExitCode -eq 1) "Rejected gate and readable artifact cannot claim manual PASS. Output: $($docs.Output)"
  Assert-Contains $docs.Output 'FAIL: Migration framework manual evidence onboarding PASS requires an approved or expected paused gate and a produced readable artifact' 'Manual PASS polarity'
}
finally {
  [IO.File]::WriteAllBytes($migrationGuideFixture, $migrationGuideOriginalBytes)
}

try {
  $invalidArtifactPass = $migrationGuideOriginal.Replace(
    $passingOnboardingEvidence,
    '| 2026-08-11 | Codex CLI 0.146.0 | onboarding | PASS | Paused at the expected approval gate; produced artifact docs/aitoolkit/2026-08-11-migration-example/01-input-report.md | Artifact is readable but not valid. |'
  )
  [IO.File]::WriteAllText($migrationGuideFixture, $invalidArtifactPass, [Text.UTF8Encoding]::new($false))
  $docs = Invoke-Validator 'Docs'
  Assert-True ($docs.ExitCode -eq 1) "Invalid manual artifact cannot claim PASS. Output: $($docs.Output)"
  Assert-Contains $docs.Output 'FAIL: Migration framework manual evidence onboarding PASS requires an approved or expected paused gate and a produced readable artifact' 'Manual artifact validity polarity'
}
finally {
  [IO.File]::WriteAllBytes($migrationGuideFixture, $migrationGuideOriginalBytes)
}

$invalidManualPassEvidence = @(
  [pscustomobject]@{ Label = 'invalid'; Evidence = 'The produced artifact is invalid.' }
  [pscustomobject]@{ Label = 'corrupt'; Evidence = 'The produced artifact is corrupt.' }
  [pscustomobject]@{ Label = 'unreadable'; Evidence = 'The produced artifact is unreadable.' }
)
foreach ($mutation in $invalidManualPassEvidence) {
  try {
    $manualPass = "| 2026-08-11 | Codex CLI 0.146.0 | onboarding | PASS | Approved migration gate observed; produced artifact docs/aitoolkit/2026-08-11-migration-example/01-input-report.md | $($mutation.Evidence) |"
    $mutatedGuide = $migrationGuideOriginal.Replace($passingOnboardingEvidence, $manualPass)
    Assert-True ($mutatedGuide -ne $migrationGuideOriginal) "Manual $($mutation.Label) mutation must alter the real guide fixture"
    [IO.File]::WriteAllText($migrationGuideFixture, $mutatedGuide, [Text.UTF8Encoding]::new($false))
    $docs = Invoke-Validator 'Docs'
    Assert-True ($docs.ExitCode -eq 1) "Manual PASS with an otherwise valid gate/path and a $($mutation.Label) artifact should fail. Output: $($docs.Output)"
    Assert-Contains $docs.Output 'FAIL: Migration framework manual evidence onboarding PASS requires an approved or expected paused gate and a produced readable artifact' "Manual $($mutation.Label) artifact polarity"
  }
  finally {
    [IO.File]::WriteAllBytes($migrationGuideFixture, $migrationGuideOriginalBytes)
  }
}

try {
  $vagueManualBlocker = $migrationGuideOriginal.Replace(
    $blockedGreenfieldEvidence,
    '| 2026-08-11 | Codex CLI 0.146.0 | greenfield | BLOCKED | No gate observed | unavailable |'
  )
  [IO.File]::WriteAllText($migrationGuideFixture, $vagueManualBlocker, [Text.UTF8Encoding]::new($false))
  $docs = Invoke-Validator 'Docs'
  Assert-True ($docs.ExitCode -eq 1) "Vague manual blocker should fail. Output: $($docs.Output)"
  Assert-Contains $docs.Output 'FAIL: Migration framework manual evidence greenfield BLOCKED requires a concrete blocker' 'Manual BLOCKED evidence contract'
}
finally {
  [IO.File]::WriteAllBytes($migrationGuideFixture, $migrationGuideOriginalBytes)
}

try {
  $fakePluginPass = $migrationGuideOriginal.Replace(
    '| 2026-08-11 | `claude plugin validate .\aitoolkit` | BLOCKED | The `claude` CLI is unavailable in this verification environment; plugin validation was not run. |',
    '| 2026-08-11 | `claude plugin validate .\aitoolkit` | PASS | The `claude` CLI is unavailable; plugin validation was not run. |'
  )
  [IO.File]::WriteAllText($migrationGuideFixture, $fakePluginPass, [Text.UTF8Encoding]::new($false))
  $docs = Invoke-Validator 'Docs'
  Assert-True ($docs.ExitCode -eq 1) "Unavailable plugin validation cannot claim PASS. Output: $($docs.Output)"
  Assert-Contains $docs.Output 'FAIL: Migration framework plugin validation PASS requires explicit successful validation evidence without contradiction' 'Plugin PASS evidence contract'
}
finally {
  [IO.File]::WriteAllBytes($migrationGuideFixture, $migrationGuideOriginalBytes)
}

try {
  $failedStaticPass = $migrationGuideOriginal.Replace(
    '| 2026-08-11 | `validate-migration-framework.ps1 -Check All` | PASS | `PASS: migration framework (All)` |',
    '| 2026-08-11 | `validate-migration-framework.ps1 -Check All` | PASS | Validation failed; output is not valid. |'
  )
  [IO.File]::WriteAllText($migrationGuideFixture, $failedStaticPass, [Text.UTF8Encoding]::new($false))
  $docs = Invoke-Validator 'Docs'
  Assert-True ($docs.ExitCode -eq 1) "Failed static validation cannot claim PASS. Output: $($docs.Output)"
  Assert-Contains $docs.Output 'FAIL: Migration framework static verification validate-migration-framework.ps1 -Check All must record positive PASS evidence without contradiction' 'Static PASS polarity'
}
finally {
  [IO.File]::WriteAllBytes($migrationGuideFixture, $migrationGuideOriginalBytes)
}

try {
  $failedPluginPass = $migrationGuideOriginal.Replace(
    '| 2026-08-11 | `claude plugin validate .\aitoolkit` | BLOCKED | The `claude` CLI is unavailable in this verification environment; plugin validation was not run. |',
    '| 2026-08-11 | `claude plugin validate .\aitoolkit` | PASS | Plugin validation failed; plugin metadata is not valid. |'
  )
  [IO.File]::WriteAllText($migrationGuideFixture, $failedPluginPass, [Text.UTF8Encoding]::new($false))
  $docs = Invoke-Validator 'Docs'
  Assert-True ($docs.ExitCode -eq 1) "Failed plugin validation cannot claim PASS. Output: $($docs.Output)"
  Assert-Contains $docs.Output 'FAIL: Migration framework plugin validation PASS requires explicit successful validation evidence without contradiction' 'Plugin PASS polarity'
}
finally {
  [IO.File]::WriteAllBytes($migrationGuideFixture, $migrationGuideOriginalBytes)
}

try {
  $vaguePluginBlocker = $migrationGuideOriginal.Replace(
    'The `claude` CLI is unavailable in this verification environment; plugin validation was not run.',
    'unavailable'
  )
  [IO.File]::WriteAllText($migrationGuideFixture, $vaguePluginBlocker, [Text.UTF8Encoding]::new($false))
  $docs = Invoke-Validator 'Docs'
  Assert-True ($docs.ExitCode -eq 1) "Vague plugin blocker should fail. Output: $($docs.Output)"
  Assert-Contains $docs.Output 'FAIL: Migration framework plugin validation BLOCKED requires a concrete unavailable-CLI reason' 'Plugin BLOCKED evidence contract'
}
finally {
  [IO.File]::WriteAllBytes($migrationGuideFixture, $migrationGuideOriginalBytes)
}

try {
  $wrongPluginCommand = $migrationGuideOriginal.Replace(
    '`claude plugin validate .\aitoolkit`',
    '`claude validate plugin .\aitoolkit`'
  )
  [IO.File]::WriteAllText($migrationGuideFixture, $wrongPluginCommand, [Text.UTF8Encoding]::new($false))
  $docs = Invoke-Validator 'Docs'
  Assert-True ($docs.ExitCode -eq 1) "Wrong plugin validation command should fail. Output: $($docs.Output)"
  Assert-Contains $docs.Output 'FAIL: Migration framework static verification must contain exactly one claude plugin validate .\aitoolkit row' 'Plugin command contract'
}
finally {
  [IO.File]::WriteAllBytes($migrationGuideFixture, $migrationGuideOriginalBytes)
}

$templateRoot = Join-Path $PSScriptRoot '../templates/migration'
$activationSliceTemplateNames = @(
  'discovery.md',
  'requirements-uiux.md',
  'inventory.md',
  'mapping.md',
  'gaps-conflicts.md',
  'technical-design.md',
  'migration-plan.md',
  'bootstrap-report.md',
  'implementation-report.md',
  'review-report.md',
  'verification-report.md',
  'parity-report.md',
  'regression-report.md'
)
$activationSliceTemplateMutations = @(
  [pscustomobject]@{ Name = 'missing canonical heading'; From = '## Activation Slice'; To = '## Activation Path' }
  [pscustomobject]@{ Name = 'renamed Activation Slice ID'; From = 'Activation Slice ID'; To = 'Activation Path ID' }
  [pscustomobject]@{ Name = 'missing Applicability'; From = 'Applicability'; To = 'Applicability Removed' }
  [pscustomobject]@{ Name = 'missing Seam'; From = 'Seam'; To = 'Seam Removed' }
  [pscustomobject]@{ Name = 'missing Source Reference'; From = 'Source Reference'; To = 'Source Evidence' }
  [pscustomobject]@{ Name = 'missing Trace IDs'; From = 'Trace IDs'; To = 'Trace References' }
  [pscustomobject]@{ Name = 'missing Disposition'; From = 'Disposition'; To = 'Disposition Removed' }
  [pscustomobject]@{ Name = 'missing Status'; From = 'Status'; To = 'Status Removed' }
  [pscustomobject]@{ Name = 'missing Decision Reference'; From = 'Decision Reference'; To = 'Decision Record' }
  [pscustomobject]@{ Name = 'missing Deferred Unit ID'; From = 'Deferred Unit ID'; To = 'Deferred Unit' }
)
foreach ($activationSliceTemplateName in $activationSliceTemplateNames) {
  $activationSliceTemplateFixture = Join-Path $templateRoot $activationSliceTemplateName
  $activationSliceTemplateOriginalBytes = [IO.File]::ReadAllBytes($activationSliceTemplateFixture)
  $activationSliceTemplateOriginal = [Text.Encoding]::UTF8.GetString($activationSliceTemplateOriginalBytes)
  Assert-True `
    ($activationSliceTemplateOriginal.Contains('## Activation Slice')) `
    "Activation Slice envelope must exist before drift mutation: $activationSliceTemplateName"

  if (-not $activationSliceTemplateOriginal.Contains('## Activation Slice')) { continue }
  foreach ($activationSliceTemplateMutation in $activationSliceTemplateMutations) {
    try {
      $mutatedActivationSliceTemplate = $activationSliceTemplateOriginal.Replace(
        $activationSliceTemplateMutation.From,
        $activationSliceTemplateMutation.To
      )
      Assert-True `
        ($mutatedActivationSliceTemplate -ne $activationSliceTemplateOriginal) `
        "Activation Slice mutation must alter $($activationSliceTemplateName): $($activationSliceTemplateMutation.Name)"
      [IO.File]::WriteAllText(
        $activationSliceTemplateFixture,
        $mutatedActivationSliceTemplate,
        [Text.UTF8Encoding]::new($false)
      )
      $templates = Invoke-Validator 'Templates'
      Assert-True `
        ($templates.ExitCode -eq 1) `
        "Activation Slice drift should fail for $($activationSliceTemplateName): $($activationSliceTemplateMutation.Name). Output: $($templates.Output)"
    }
    finally {
      [IO.File]::WriteAllBytes($activationSliceTemplateFixture, $activationSliceTemplateOriginalBytes)
    }
  }
}

$activationSliceTemplateFixture = Join-Path $templateRoot 'discovery.md'
$activationSliceTemplateOriginalBytes = [IO.File]::ReadAllBytes($activationSliceTemplateFixture)
$activationSliceTemplateOriginal = [Text.Encoding]::UTF8.GetString($activationSliceTemplateOriginalBytes)
try {
  $activationSliceWithoutTable = Remove-MarkdownTablesInSection `
    $activationSliceTemplateOriginal `
    'Activation Slice'
  Assert-True `
    ($activationSliceWithoutTable -ne $activationSliceTemplateOriginal) `
    'Activation Slice whole-table removal mutation must alter discovery template'
  [IO.File]::WriteAllText(
    $activationSliceTemplateFixture,
    $activationSliceWithoutTable,
    [Text.UTF8Encoding]::new($false)
  )
  $templates = Invoke-Validator 'Templates'
  Assert-True `
    ($templates.ExitCode -eq 1) `
    "Activation Slice prose without a Markdown table should fail. Output: $($templates.Output)"
  Assert-Contains `
    $templates.Output `
    'canonical Activation Slice table must appear exactly once; found 0' `
    'Activation Slice whole-table rejection'
}
finally {
  [IO.File]::WriteAllBytes($activationSliceTemplateFixture, $activationSliceTemplateOriginalBytes)
}

try {
  $duplicateActivationSliceHeading = $activationSliceTemplateOriginal.Replace(
    '## Activation Slice',
    "## Activation Slice`n`n## Activation Slice"
  )
  Assert-True `
    ($duplicateActivationSliceHeading -ne $activationSliceTemplateOriginal) `
    'Activation Slice duplicate-heading mutation must alter discovery template'
  [IO.File]::WriteAllText(
    $activationSliceTemplateFixture,
    $duplicateActivationSliceHeading,
    [Text.UTF8Encoding]::new($false)
  )
  $templates = Invoke-Validator 'Templates'
  Assert-True `
    ($templates.ExitCode -eq 1) `
    "Duplicate Activation Slice heading should fail. Output: $($templates.Output)"
  Assert-Contains `
    $templates.Output `
    'canonical Activation Slice heading must appear exactly once; found 2' `
    'Activation Slice duplicate-heading rejection'
}
finally {
  [IO.File]::WriteAllBytes($activationSliceTemplateFixture, $activationSliceTemplateOriginalBytes)
}

try {
  $duplicateActivationSliceColumn = Replace-InMarkdownSection `
    $activationSliceTemplateOriginal `
    'Activation Slice' `
    '| Activation Slice ID |' `
    '| Activation Slice ID | Activation Slice ID |'
  Assert-True `
    ($duplicateActivationSliceColumn -ne $activationSliceTemplateOriginal) `
    'Activation Slice duplicate-column mutation must alter discovery template'
  [IO.File]::WriteAllText(
    $activationSliceTemplateFixture,
    $duplicateActivationSliceColumn,
    [Text.UTF8Encoding]::new($false)
  )
  $templates = Invoke-Validator 'Templates'
  Assert-True `
    ($templates.ExitCode -eq 1) `
    "Duplicate Activation Slice column should fail. Output: $($templates.Output)"
  Assert-Contains `
    $templates.Output `
    'canonical Activation Slice table must appear exactly once; found 0' `
    'Activation Slice duplicate-column rejection'
}
finally {
  [IO.File]::WriteAllBytes($activationSliceTemplateFixture, $activationSliceTemplateOriginalBytes)
}

try {
  $activationContractSchemaDrift = Replace-InMarkdownSection `
    $activationContractOriginal `
    'Artifact row schema' `
    ' | Deferred Unit ID |' `
    ' | Deferred Unit |'
  Assert-True `
    ($activationContractSchemaDrift -ne $activationContractOriginal) `
    'Activation Slice contract schema mutation must alter the canonical contract'
  [IO.File]::WriteAllText(
    $activationContractFixture,
    $activationContractSchemaDrift,
    [Text.UTF8Encoding]::new($false)
  )
  $templates = Invoke-Validator 'Templates'
  Assert-True `
    ($templates.ExitCode -eq 1) `
    "Activation Slice contract schema drift should fail template validation. Output: $($templates.Output)"
  Assert-Contains `
    $templates.Output `
    'canonical Activation Slice table must appear exactly once; found 0' `
    'Activation Slice canonical-contract schema consumption'
}
finally {
  [IO.File]::WriteAllBytes($activationContractFixture, $activationContractOriginalBytes)
}

$templateFixture = Join-Path $templateRoot 'input-report.md'
$unexpectedTemplateFixture = Join-Path $templateRoot '__unexpected-template.md'
$templateOriginalBytes = [IO.File]::ReadAllBytes($templateFixture)
$templateOriginal = [Text.Encoding]::UTF8.GetString($templateOriginalBytes)
try {
  [IO.File]::WriteAllText($unexpectedTemplateFixture, '# Unexpected template', [Text.UTF8Encoding]::new($false))
  $templates = Invoke-Validator 'Templates'
  Assert-True ($templates.ExitCode -eq 1) "Unexpected migration template should fail. Output: $($templates.Output)"
  Assert-Contains $templates.Output 'FAIL: Unexpected migration template: __unexpected-template.md' 'Unexpected template selector'
  Remove-Item -LiteralPath $unexpectedTemplateFixture -Force

  [IO.File]::WriteAllText($templateFixture, $templateOriginal.Replace('status: draft', 'status: active'), [Text.UTF8Encoding]::new($false))
  $templates = Invoke-Validator 'Templates'
  Assert-True ($templates.ExitCode -eq 1) "Invalid status enum should fail. Output: $($templates.Output)"
  Assert-Contains $templates.Output 'FAIL: Template input-report.md invalid status: active' 'Template status enum'

  $statusOutsideFrontMatter = [regex]::Replace($templateOriginal, '(?m)^status: draft\r?\n', '') + [Environment]::NewLine + 'status: draft' + [Environment]::NewLine
  [IO.File]::WriteAllText($templateFixture, $statusOutsideFrontMatter, [Text.UTF8Encoding]::new($false))
  $templates = Invoke-Validator 'Templates'
  Assert-True ($templates.ExitCode -eq 1) "Status outside YAML front matter should fail. Output: $($templates.Output)"
  Assert-Contains $templates.Output 'FAIL: Template input-report.md status must appear exactly once in YAML front matter' 'Template status location'

  [IO.File]::WriteAllText($templateFixture, $templateOriginal + [Environment]::NewLine + 'Flutter' + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
  $templates = Invoke-Validator 'Templates'
  Assert-True ($templates.ExitCode -eq 1) "Technology token should fail. Output: $($templates.Output)"
  Assert-Contains $templates.Output 'FAIL: Template input-report.md contains prohibited technology token: Flutter' 'Template technology selector'
}
finally {
  [IO.File]::WriteAllBytes($templateFixture, $templateOriginalBytes)
  Remove-Item -LiteralPath $unexpectedTemplateFixture -Force -ErrorAction SilentlyContinue
}

$skillRoot = Join-Path $PSScriptRoot '../skills/migration'
$mappingSkillFixture = Join-Path $skillRoot 'feature-mapping/SKILL.md'
$mappingSkillOriginalBytes = [IO.File]::ReadAllBytes($mappingSkillFixture)
$mappingSkillOriginal = [Text.Encoding]::UTF8.GetString($mappingSkillOriginalBytes)
try {
  $hardcodedInputs = $mappingSkillOriginal.Replace(
    '## Inputs',
    "## Inputs`r`n`r`nArtifacts hardcoded for test: ``01-input-report.md`` through ``04-inventory.md``."
  )
  [IO.File]::WriteAllText($mappingSkillFixture, $hardcodedInputs, [Text.UTF8Encoding]::new($false))
  $skills = Invoke-Validator 'Skills'
  Assert-True ($skills.ExitCode -eq 1) "Hardcoded cumulative input paths should fail. Output: $($skills.Output)"
  Assert-Contains $skills.Output 'FAIL: Skill feature-mapping/SKILL.md Inputs hardcodes numbered artifact path' 'Immediate predecessor input contract'

  $immediatePredecessorToken = 'Immediate predecessor artifact = exactly one orchestrator-provided path'
  $markerOutsideInputs = $mappingSkillOriginal.Replace($immediatePredecessorToken, '') +
    [Environment]::NewLine + $immediatePredecessorToken + [Environment]::NewLine
  [IO.File]::WriteAllText($mappingSkillFixture, $markerOutsideInputs, [Text.UTF8Encoding]::new($false))
  $skills = Invoke-Validator 'Skills'
  Assert-True ($skills.ExitCode -eq 1) "Immediate predecessor marker outside Inputs should fail. Output: $($skills.Output)"
  Assert-Contains $skills.Output "FAIL: Skill feature-mapping/SKILL.md Inputs missing: $immediatePredecessorToken" 'Inputs-local predecessor contract'
}
finally {
  [IO.File]::WriteAllBytes($mappingSkillFixture, $mappingSkillOriginalBytes)
}

$planWavesFixture = Join-Path $skillRoot 'plan-waves/SKILL.md'
$planWavesOriginalBytes = [IO.File]::ReadAllBytes($planWavesFixture)
$planWavesOriginal = [Text.Encoding]::UTF8.GetString($planWavesOriginalBytes)
try {
  $blanketDesignGate = $planWavesOriginal.Replace(
    'For `incremental` / `preserve-existing`, proceed through target conformance without a Tech Lead gate; only a documented architecture conflict requires approval from its owner.',
    'Require explicit Tech Lead approval for every technical design before planning any migration unit.'
  )
  [IO.File]::WriteAllText($planWavesFixture, $blanketDesignGate, [Text.UTF8Encoding]::new($false))
  $skills = Invoke-Validator 'Skills'
  Assert-True ($skills.ExitCode -eq 1) "Blanket incremental Tech Lead gate should fail. Output: $($skills.Output)"
  Assert-Contains $skills.Output 'FAIL: Skill plan-waves/SKILL.md Procedure missing mode-scoped design approval policy' 'Plan-waves design approval scope'
}
finally {
  [IO.File]::WriteAllBytes($planWavesFixture, $planWavesOriginalBytes)
}

try {
  $uniqueInitialProcedureGuard = 'For `greenfield` / `design-new`, use `required` only for the unique initial foundation unit when no approved foundation baseline exists; other units use `not-required` and must satisfy the Foundation baseline contract below. A second or later `required` unit yields `result: blocked`.'
  $uniqueInitialContractGuard = 'Exactly one initial greenfield foundation unit may use `Bootstrap Scope = required`, only when no approved foundation baseline exists.'
  $subsequentUnitGuard = 'If a current approved foundation baseline already exists, all subsequent greenfield units use `Bootstrap Scope = not-required`; `required` is a lifecycle mismatch and yields `result: blocked` rather than rerunning bootstrap.'
  $neverRerunGuard = 'A later greenfield unit never reruns bootstrap merely because it is greenfield.'
  $laterUnitRerunsBootstrap = $planWavesOriginal.Replace(
    $uniqueInitialProcedureGuard,
    'For `greenfield` / `design-new`, any foundation unit may use `required`, including a later unit after a baseline is approved.'
  ).Replace(
    $uniqueInitialContractGuard,
    'A later greenfield unit may use `Bootstrap Scope = required` even when an approved foundation baseline exists.'
  ).Replace(
    $subsequentUnitGuard,
    'If a current approved foundation baseline already exists, a later greenfield unit may use `Bootstrap Scope = required` and rerun bootstrap.'
  ).Replace(
    $neverRerunGuard,
    'A later greenfield unit may rerun bootstrap when declared required.'
  )
  Assert-True ($laterUnitRerunsBootstrap -ne $planWavesOriginal) 'Later-greenfield required-scope mutation must alter plan-waves'
  foreach ($removedGuard in @($uniqueInitialProcedureGuard, $uniqueInitialContractGuard, $subsequentUnitGuard, $neverRerunGuard)) {
    Assert-True (-not $laterUnitRerunsBootstrap.Contains($removedGuard)) "Later-greenfield required-scope mutation must remove guard: $removedGuard"
  }
  Assert-Contains $laterUnitRerunsBootstrap 'A later greenfield unit may use `Bootstrap Scope = required`' 'Later-greenfield required-scope mutation semantics'
  [IO.File]::WriteAllText($planWavesFixture, $laterUnitRerunsBootstrap, [Text.UTF8Encoding]::new($false))
  $skills = Invoke-Validator 'Skills'
  Assert-True ($skills.ExitCode -eq 1) "Later greenfield unit declaring required bootstrap should fail. Output: $($skills.Output)"
  Assert-Contains $skills.Output 'FAIL: Skill plan-waves/SKILL.md foundation baseline contract allows later greenfield required bootstrap' 'Later-greenfield cannot rerun bootstrap'
}
finally {
  [IO.File]::WriteAllBytes($planWavesFixture, $planWavesOriginalBytes)
}

$regressionSkillFixture = Join-Path $skillRoot 'verify-regression/SKILL.md'
$regressionSkillOriginalBytes = [IO.File]::ReadAllBytes($regressionSkillFixture)
$regressionSkillOriginal = [Text.Encoding]::UTF8.GetString($regressionSkillOriginalBytes)
try {
  $waivableRegressionStep = $regressionSkillOriginal.Replace(
    'Regression verification is mandatory for incremental / `preserve-existing` and cannot be waived or skipped.',
    'Regression verification may be omitted with an approved regression-step waiver.'
  )
  [IO.File]::WriteAllText($regressionSkillFixture, $waivableRegressionStep, [Text.UTF8Encoding]::new($false))
  $skills = Invoke-Validator 'Skills'
  Assert-True ($skills.ExitCode -eq 1) "Waivable incremental regression step should fail. Output: $($skills.Output)"
  Assert-Contains $skills.Output 'FAIL: Skill verify-regression/SKILL.md section Applicability and baseline gate missing: cannot be waived or skipped' 'Mandatory regression gate'
}
finally {
  [IO.File]::WriteAllBytes($regressionSkillFixture, $regressionSkillOriginalBytes)
}

$codeMigrationFixture = Join-Path $skillRoot 'code-migration/SKILL.md'
$codeMigrationOriginalBytes = [IO.File]::ReadAllBytes($codeMigrationFixture)
$codeMigrationOriginal = [Text.Encoding]::UTF8.GetString($codeMigrationOriginalBytes)
try {
  $selectorOutsideInputs = $codeMigrationOriginal.Replace(
    ', `migration_unit_id`, `foundation_baseline_id` for a greenfield `not-required` unit, and the resolved per-run `automation_mode`, alongside that path.',
    ', `foundation_baseline_id` for a greenfield `not-required` unit, and the resolved per-run `automation_mode`, alongside that path.'
  ) + [Environment]::NewLine + 'The orchestrator also provides `migration_unit_id`.' + [Environment]::NewLine
  [IO.File]::WriteAllText($codeMigrationFixture, $selectorOutsideInputs, [Text.UTF8Encoding]::new($false))
  $skills = Invoke-Validator 'Skills'
  Assert-True ($skills.ExitCode -eq 1) "Migration-unit selector outside Inputs should fail. Output: $($skills.Output)"
  Assert-Contains $skills.Output 'FAIL: Skill code-migration/SKILL.md Inputs missing: `migration_unit_id`' 'Unit selector location'

  $baselineStep = '4. In incremental mode, capture a comparable pre-change regression baseline against the unchanged target and preserve its evidence reference. On a valid Approved baseline-waiver resume, skip only that collection and cite the exact approved waiver evidence as `Baseline Reference`. Greenfield records `not-applicable`.'
  $tddStep = '7. Within `superpowers:executing-plans`, apply `superpowers:test-driven-development`: write an acceptance test, observe RED, implement the minimum, observe GREEN, then refactor while staying green.'
  $baselineAfterEdit = [regex]::Replace(
    $codeMigrationOriginal,
    '(?m)^' + [regex]::Escape($baselineStep) + '\r?\n',
    ''
  ).Replace($tddStep, $tddStep + [Environment]::NewLine + $baselineStep)
  [IO.File]::WriteAllText($codeMigrationFixture, $baselineAfterEdit, [Text.UTF8Encoding]::new($false))
  $skills = Invoke-Validator 'Skills'
  Assert-True ($skills.ExitCode -eq 1) "Baseline capture after editing should fail. Output: $($skills.Output)"
  Assert-Contains $skills.Output 'FAIL: Skill code-migration/SKILL.md Procedure requires order: capture a comparable pre-change regression baseline before evaluate the pre-mutation gate' 'Baseline-before-edit ordering'
  Assert-NotContains $skills.Output 'section Pre-mutation gate missing' 'Baseline mutation must preserve pre-mutation contract tokens'
}
finally {
  [IO.File]::WriteAllBytes($codeMigrationFixture, $codeMigrationOriginalBytes)
}

$orchestratorFixture = Join-Path $PSScriptRoot '../skills/aitoolkit/migrate/SKILL.md'
$orchestratorOriginalBytes = [IO.File]::ReadAllBytes($orchestratorFixture)
$orchestratorOriginal = [Text.Encoding]::UTF8.GetString($orchestratorOriginalBytes)
try {
  $withoutKnowledgeTerminal = [regex]::Replace(
    $orchestratorOriginal,
    '(?m)^\|\s*15\s*\|\s*shared/knowledge-base\s*\|.*\r?\n',
    ''
  )
  Assert-True ($withoutKnowledgeTerminal -ne $orchestratorOriginal) 'Step-count mutation must remove the Knowledge Capture row'
  [IO.File]::WriteAllText($orchestratorFixture, $withoutKnowledgeTerminal, [Text.UTF8Encoding]::new($false))
  $orchestrators = Invoke-Validator 'Orchestrators'
  Assert-True ($orchestrators.ExitCode -eq 1) "Migration pipeline without exactly 15 steps should fail. Output: $($orchestrators.Output)"
  Assert-Contains $orchestrators.Output 'FAIL: Migration orchestrator step table must contain exactly 15 rows; found 14' 'Migration 15-step boundary'

  $knowledgeTerminalRowMatch = [regex]::Match(
    $orchestratorOriginal,
    '(?m)^\|\s*15\s*\|\s*shared/knowledge-base\s*\|[^\r\n]*'
  )
  Assert-True $knowledgeTerminalRowMatch.Success 'Delivery-route fixture must locate the Knowledge Capture row'
  $orchestratorLineEnding = if ($orchestratorOriginal.Contains("`r`n")) { "`r`n" } else { "`n" }
  foreach ($removedRoute in @('shared/gerrit-automation', 'shared/ccc-automation', 'shared/release')) {
    $removedRouteRow = '| 16 | {0} | `removed-delivery.md` | none | none | obsolete |' -f $removedRoute
    $withRemovedDeliveryRoute = $orchestratorOriginal.Replace(
      $knowledgeTerminalRowMatch.Value,
      $knowledgeTerminalRowMatch.Value + $orchestratorLineEnding + $removedRouteRow
    )
    Assert-True ($withRemovedDeliveryRoute -ne $orchestratorOriginal) "Delivery-route mutation must add $removedRoute"
    [IO.File]::WriteAllText($orchestratorFixture, $withRemovedDeliveryRoute, [Text.UTF8Encoding]::new($false))
    $orchestrators = Invoke-Validator 'Orchestrators'
    Assert-True ($orchestrators.ExitCode -eq 1) "Removed migration route $removedRoute should fail. Output: $($orchestrators.Output)"
    Assert-Contains $orchestrators.Output 'FAIL: Migration orchestrator step table must contain exactly 15 rows; found 16' "Removed migration route cardinality $removedRoute"
    Assert-Contains $orchestrators.Output "FAIL: Migration orchestrator step table contains removed delivery route: $removedRoute" "Removed migration route $removedRoute"
    Assert-Contains $orchestrators.Output 'FAIL: Migration orchestrator Knowledge Capture must be step 15 and the last row' "Knowledge Capture must remain last before $removedRoute"
  }

  $knowledgeAtWrongStep = [regex]::Replace(
    $orchestratorOriginal,
    '(?m)^\|\s*15\s*\|\s*shared/knowledge-base\s*\|',
    '| 16 | shared/knowledge-base |'
  )
  Assert-True ($knowledgeAtWrongStep -ne $orchestratorOriginal) 'Knowledge Capture step mutation must alter step 15'
  [IO.File]::WriteAllText($orchestratorFixture, $knowledgeAtWrongStep, [Text.UTF8Encoding]::new($false))
  $orchestrators = Invoke-Validator 'Orchestrators'
  Assert-True ($orchestrators.ExitCode -eq 1) "Knowledge Capture outside step 15 should fail. Output: $($orchestrators.Output)"
  Assert-Contains $orchestrators.Output 'FAIL: Migration orchestrator Knowledge Capture must be step 15 and the last row' 'Knowledge Capture terminal position'

  $terminalArrow = ([char]0x2192).ToString()
  $greenfieldTerminalPolicy = "greenfield $terminalArrow ``13-parity-report.md`` $terminalArrow knowledge-base"
  $wrongGreenfieldTerminalPolicy = "greenfield $terminalArrow ``14-regression-report.md`` $terminalArrow knowledge-base"
  $wrongGreenfieldKnowledgePredecessor = $orchestratorOriginal.Replace(
    $greenfieldTerminalPolicy,
    $wrongGreenfieldTerminalPolicy
  )
  Assert-True ($wrongGreenfieldKnowledgePredecessor -ne $orchestratorOriginal) 'Greenfield terminal-predecessor mutation must alter the orchestrator'
  [IO.File]::WriteAllText($orchestratorFixture, $wrongGreenfieldKnowledgePredecessor, [Text.UTF8Encoding]::new($false))
  $orchestrators = Invoke-Validator 'Orchestrators'
  Assert-True ($orchestrators.ExitCode -eq 1) "Greenfield Knowledge Capture without parity predecessor should fail. Output: $($orchestrators.Output)"
  Assert-Contains $orchestrators.Output "FAIL: Migration orchestrator terminal predecessor policy missing: $greenfieldTerminalPolicy" 'Greenfield terminal predecessor'

  $incrementalTerminalPolicy = "incremental $terminalArrow ``14-regression-report.md`` $terminalArrow knowledge-base"
  $wrongIncrementalTerminalPolicy = "incremental $terminalArrow ``13-parity-report.md`` $terminalArrow knowledge-base"
  $wrongIncrementalKnowledgePredecessor = $orchestratorOriginal.Replace(
    $incrementalTerminalPolicy,
    $wrongIncrementalTerminalPolicy
  )
  Assert-True ($wrongIncrementalKnowledgePredecessor -ne $orchestratorOriginal) 'Incremental terminal-predecessor mutation must alter the orchestrator'
  [IO.File]::WriteAllText($orchestratorFixture, $wrongIncrementalKnowledgePredecessor, [Text.UTF8Encoding]::new($false))
  $orchestrators = Invoke-Validator 'Orchestrators'
  Assert-True ($orchestrators.ExitCode -eq 1) "Incremental Knowledge Capture without regression predecessor should fail. Output: $($orchestrators.Output)"
  Assert-Contains $orchestrators.Output "FAIL: Migration orchestrator terminal predecessor policy missing: $incrementalTerminalPolicy" 'Incremental terminal predecessor'

  $approvedContinuationOutsideProtocol = $orchestratorOriginal.Replace(
    'validate approved artifact',
    'inspect approved artifact'
  ) + [Environment]::NewLine + 'validate approved artifact' + [Environment]::NewLine
  [IO.File]::WriteAllText($orchestratorFixture, $approvedContinuationOutsideProtocol, [Text.UTF8Encoding]::new($false))
  $orchestrators = Invoke-Validator 'Orchestrators'
  Assert-True ($orchestrators.ExitCode -eq 1) "Approved continuation outside protocol should fail. Output: $($orchestrators.Output)"
  Assert-Contains $orchestrators.Output 'FAIL: Migration orchestrator execution policy missing: validate approved artifact' 'Approved continuation section locality'

  $blockedAfterGate = $orchestratorOriginal.Replace(
    'When an artifact has `result: blocked`, stop before approval gate and downstream execution.',
    'Open approval gate and downstream execution before handling `result: blocked`.'
  )
  [IO.File]::WriteAllText($orchestratorFixture, $blockedAfterGate, [Text.UTF8Encoding]::new($false))
  $orchestrators = Invoke-Validator 'Orchestrators'
  Assert-True ($orchestrators.ExitCode -eq 1) "Blocked handling after approval/downstream should fail. Output: $($orchestrators.Output)"
  Assert-Contains $orchestrators.Output 'FAIL: Migration orchestrator blocked handling requires order: result: blocked before approval gate' 'Blocked-before-gate ordering'
  Assert-Contains $orchestrators.Output 'FAIL: Migration orchestrator blocked handling requires order: result: blocked before downstream execution' 'Blocked-before-downstream ordering'

  $selectorOutsideModeGate = $orchestratorOriginal.Replace(
    'exactly one approved migration unit',
    'one migration unit'
  ) + [Environment]::NewLine + 'exactly one approved migration unit' + [Environment]::NewLine
  [IO.File]::WriteAllText($orchestratorFixture, $selectorOutsideModeGate, [Text.UTF8Encoding]::new($false))
  $orchestrators = Invoke-Validator 'Orchestrators'
  Assert-True ($orchestrators.ExitCode -eq 1) "Selector validation outside mode gate should fail. Output: $($orchestrators.Output)"
  Assert-Contains $orchestrators.Output 'FAIL: Migration orchestrator selector validation missing: exactly one approved migration unit' 'Selector validation section locality'

  $skipLosesPredecessor = $orchestratorOriginal.Replace(
    'skip preserves latest executed artifact',
    'skip clears the predecessor'
  )
  [IO.File]::WriteAllText($orchestratorFixture, $skipLosesPredecessor, [Text.UTF8Encoding]::new($false))
  $orchestrators = Invoke-Validator 'Orchestrators'
  Assert-True ($orchestrators.ExitCode -eq 1) "Skip that loses the latest predecessor should fail. Output: $($orchestrators.Output)"
  Assert-Contains $orchestrators.Output 'FAIL: Migration orchestrator execution policy missing: skip preserves latest executed artifact' 'Skip predecessor preservation'

  $handoffStartsBeforeSelection = $orchestratorOriginal.Replace(
    'after step 08 approval and selector choice',
    'from step 08 onward before selector choice'
  )
  [IO.File]::WriteAllText($orchestratorFixture, $handoffStartsBeforeSelection, [Text.UTF8Encoding]::new($false))
  $orchestrators = Invoke-Validator 'Orchestrators'
  Assert-True ($orchestrators.ExitCode -eq 1) "Full handoff before unit selection should fail. Output: $($orchestrators.Output)"
  Assert-Contains $orchestrators.Output 'FAIL: Migration orchestrator handoff missing: after step 08 approval and selector choice' 'Selected-unit handoff lifecycle'

  $automationResolutionMutations = @(
    [pscustomobject]@{
      Name = 'legacy default'; From = '| none | missing | `automation_mode: interactive` |'; To = '| none | missing | `automation_mode: auto` |'
      Expected = 'FAIL: Migration automation resolution scenario invalid: legacy default'
    }
    [pscustomobject]@{
      Name = 'profile interactive'; From = '| none | `interactive` | `automation_mode: interactive` |'; To = '| none | `interactive` | `automation_mode: auto` |'
      Expected = 'FAIL: Migration automation resolution scenario invalid: profile interactive'
    }
    [pscustomobject]@{
      Name = 'profile auto'; From = '| none | `auto` | `automation_mode: auto` |'; To = '| none | `auto` | `automation_mode: interactive` |'
      Expected = 'FAIL: Migration automation resolution scenario invalid: profile auto'
    }
    [pscustomobject]@{
      Name = 'profile auto-waive'; From = '| none | `auto-waive` | `automation_mode: auto-waive` |'; To = '| none | `auto-waive` | `automation_mode: interactive` |'
      Expected = 'FAIL: Migration automation resolution scenario invalid: profile auto-waive'
    }
    [pscustomobject]@{
      Name = 'CLI auto override'; From = '| `--auto` | missing or any supported value | `automation_mode: auto` |'; To = '| `--auto` | missing or any supported value | `automation_mode: interactive` |'
      Expected = 'FAIL: Migration automation resolution scenario invalid: CLI auto override'
    }
    [pscustomobject]@{
      Name = 'CLI auto-waive override'; From = '| `--auto-waive` | missing or any supported value | `automation_mode: auto-waive` |'; To = '| `--auto-waive` | missing or any supported value | `automation_mode: interactive` |'
      Expected = 'FAIL: Migration automation resolution scenario invalid: CLI auto-waive override'
    }
    [pscustomobject]@{
      Name = 'conflicting CLI flags'; From = '| `--auto --auto-waive` | any | `result: blocked` before step 01 |'; To = '| `--auto --auto-waive` | any | `automation_mode: auto-waive` |'
      Expected = 'FAIL: Migration automation resolution scenario invalid: conflicting CLI flags'
    }
    [pscustomobject]@{
      Name = 'unknown profile enum'; From = '| any | outside the supported enum | `result: blocked` before step 01 |'; To = '| any | outside the supported enum | `automation_mode: interactive` |'
      Expected = 'FAIL: Migration automation resolution scenario invalid: unknown profile enum'
    }
  )
  foreach ($mutation in $automationResolutionMutations) {
    $mutatedOrchestrator = $orchestratorOriginal.Replace($mutation.From, $mutation.To)
    Assert-True ($mutatedOrchestrator -ne $orchestratorOriginal) "Automation-resolution mutation must alter orchestrator: $($mutation.Name)"
    [IO.File]::WriteAllText($orchestratorFixture, $mutatedOrchestrator, [Text.UTF8Encoding]::new($false))
    $orchestrators = Invoke-Validator 'Orchestrators'
    Assert-True ($orchestrators.ExitCode -eq 1) "Wrong automation resolution should fail: $($mutation.Name). Output: $($orchestrators.Output)"
    Assert-Contains $orchestrators.Output $mutation.Expected "Automation resolution: $($mutation.Name)"
  }

  $automationGateMutations = @(
    [pscustomobject]@{
      Name = 'auto non-blocked soft';
      From = '| `complete` | soft | ask the user | `status: approved`; `approval_source: auto`; without question | `status: approved`; `approval_source: auto-waive`; without question |'
      To = '| `complete` | soft | ask the user | ask the user | `status: approved`; `approval_source: auto-waive`; without question |'
      Expected = 'FAIL: Migration automation non-blocked soft-gate policy invalid'
    }
    [pscustomobject]@{
      Name = 'auto-waive non-blocked soft';
      From = '| `complete` | soft | ask the user | `status: approved`; `approval_source: auto`; without question | `status: approved`; `approval_source: auto-waive`; without question |'
      To = '| `complete` | soft | ask the user | `status: approved`; `approval_source: auto`; without question | ask the user |'
      Expected = 'FAIL: Migration automation non-blocked soft-gate policy invalid'
    }
    [pscustomobject]@{
      Name = 'blocked artifact';
      From = '| `blocked` | any | stop before approval | stop before approval | stop before approval |'
      To = '| `blocked` | any | stop before approval | auto-approve | stop before approval |'
      Expected = 'FAIL: Migration automation blocked-artifact policy invalid'
    }
    [pscustomobject]@{
      Name = 'HARD gate';
      From = '| any | HARD | stop for explicit confirmation | stop for explicit confirmation | stop for explicit confirmation |'
      To = '| any | HARD | stop for explicit confirmation | auto-approve | stop for explicit confirmation |'
      Expected = 'FAIL: Migration automation HARD-gate policy invalid'
    }
  )
  foreach ($mutation in $automationGateMutations) {
    $mutatedOrchestrator = $orchestratorOriginal.Replace($mutation.From, $mutation.To)
    if ($mutatedOrchestrator -ceq $orchestratorOriginal) {
      throw "Automation-gate mutation did not alter orchestrator: $($mutation.Name)"
    }
    [IO.File]::WriteAllText($orchestratorFixture, $mutatedOrchestrator, [Text.UTF8Encoding]::new($false))
    $orchestrators = Invoke-Validator 'Orchestrators'
    Assert-True ($orchestrators.ExitCode -eq 1) "Wrong automation gate policy should fail: $($mutation.Name). Output: $($orchestrators.Output)"
    Assert-Contains $orchestrators.Output $mutation.Expected "Automation gate policy: $($mutation.Name)"
  }

  $automationModeNotForwarded = $orchestratorOriginal.Replace(
    'every migration step invocation',
    'only the first migration step invocation'
  )
  Assert-True ($automationModeNotForwarded -ne $orchestratorOriginal) 'Automation-mode handoff mutation must alter orchestrator'
  [IO.File]::WriteAllText($orchestratorFixture, $automationModeNotForwarded, [Text.UTF8Encoding]::new($false))
  $orchestrators = Invoke-Validator 'Orchestrators'
  Assert-True ($orchestrators.ExitCode -eq 1) "Missing per-step automation mode should fail. Output: $($orchestrators.Output)"
  Assert-Contains $orchestrators.Output 'FAIL: Migration automation resolution missing: every migration step invocation' 'Automation mode per-step handoff'
}
finally {
  [IO.File]::WriteAllBytes($orchestratorFixture, $orchestratorOriginalBytes)
}

try {
  $eligibleWaiverRows = @(
    '| dependency/tool executable absent | verbatim executable lookup or start error | `environment-unavailable` | stop with native blocker | stop with native blocker | continue with exact partial waiver |'
    '| device/emulator/service unavailable | verbatim device/emulator/service probe or start error | `environment-unavailable` | stop with native blocker | stop with native blocker | continue with exact partial waiver |'
    '| network dependency unavailable | verbatim network resolution or connection error | `environment-unavailable` | stop with native blocker | stop with native blocker | continue with exact partial waiver |'
    '| command cannot start because environment capability is absent | verbatim command-start error naming the absent capability | `environment-unavailable` | stop with native blocker | stop with native blocker | continue with exact partial waiver |'
    '| pre-mutation baseline cannot be collected solely for one of those reasons | verbatim pre-mutation command/capability error recorded before target edit | `environment-unavailable` | stop with native blocker | stop with native blocker | continue with exact partial waiver |'
  )
  foreach ($eligibleRow in $eligibleWaiverRows) {
    $blocker = ($eligibleRow.Trim('|').Split('|')[0]).Trim()
    $wrongAutoWaiveAction = $eligibleRow.Replace(
      'continue with exact partial waiver |',
      'stop with native blocker |'
    )
    $mutatedOrchestrator = $orchestratorOriginal.Replace($eligibleRow, $wrongAutoWaiveAction)
    Assert-True ($mutatedOrchestrator -ne $orchestratorOriginal) "Eligible waiver mutation must alter orchestrator: $blocker"
    [IO.File]::WriteAllText($orchestratorFixture, $mutatedOrchestrator, [Text.UTF8Encoding]::new($false))
    $skills = Invoke-Validator 'Skills'
    Assert-True ($skills.ExitCode -eq 1) "Eligible blocker that does not continue only in auto-waive should fail: $blocker. Output: $($skills.Output)"
    Assert-Contains $skills.Output "FAIL: Migration environment-waiver eligible scenario has invalid mode action: $blocker" "Eligible waiver scenario: $blocker"
  }

  foreach ($modeMutation in @(
    [pscustomobject]@{
      Name = 'interactive continuation'
      Row = $eligibleWaiverRows[0]
      Mutated = $eligibleWaiverRows[0].Replace(
        '| stop with native blocker | stop with native blocker | continue with exact partial waiver |',
        '| continue with exact partial waiver | stop with native blocker | continue with exact partial waiver |'
      )
      Blocker = 'dependency/tool executable absent'
    }
    [pscustomobject]@{
      Name = 'auto continuation'
      Row = $eligibleWaiverRows[1]
      Mutated = $eligibleWaiverRows[1].Replace(
        '| stop with native blocker | stop with native blocker | continue with exact partial waiver |',
        '| stop with native blocker | continue with exact partial waiver | continue with exact partial waiver |'
      )
      Blocker = 'device/emulator/service unavailable'
    }
  )) {
    $mutatedOrchestrator = $orchestratorOriginal.Replace($modeMutation.Row, $modeMutation.Mutated)
    Assert-True ($mutatedOrchestrator -ne $orchestratorOriginal) "Eligible mode-boundary mutation must alter orchestrator: $($modeMutation.Name)"
    [IO.File]::WriteAllText($orchestratorFixture, $mutatedOrchestrator, [Text.UTF8Encoding]::new($false))
    $skills = Invoke-Validator 'Skills'
    Assert-True ($skills.ExitCode -eq 1) "Eligible blocker continuing outside auto-waive should fail: $($modeMutation.Name). Output: $($skills.Output)"
    Assert-Contains $skills.Output "FAIL: Migration environment-waiver eligible scenario has invalid mode action: $($modeMutation.Blocker)" "Eligible mode boundary: $($modeMutation.Name)"
  }

  $probeUnavailableScenario = 'required command never starts because a failed availability probe establishes an absent dependency'
  $probeUnavailableRow = '| 3 | required command never starts because a failed availability probe establishes an absent dependency | `availability probe` | `not-started` | `environment-unavailable` | stop with native blocker | stop with native blocker | continue with exact partial waiver |'
  $probeWithRequiredCommandRole = $probeUnavailableRow.Replace(
    '`availability probe`',
    '`required test/build/baseline command`'
  )
  $mutatedOrchestrator = $orchestratorOriginal.Replace($probeUnavailableRow, $probeWithRequiredCommandRole)
  Assert-True ($mutatedOrchestrator -ne $orchestratorOriginal) 'Availability-probe role mutation must alter orchestrator'
  [IO.File]::WriteAllText($orchestratorFixture, $mutatedOrchestrator, [Text.UTF8Encoding]::new($false))
  $skills = Invoke-Validator 'Skills'
  Assert-True ($skills.ExitCode -eq 1) "Availability evidence mislabeled as a required command should fail. Output: $($skills.Output)"
  Assert-Contains $skills.Output "FAIL: Migration environment-waiver decision scenario invalid: $probeUnavailableScenario" 'Availability-probe role precedence'

  $startedWithoutResultScenario = 'required command starts but produces no correctness/regression result while environment symptom also exists'
  $startedWithoutResultRow = '| 2 | required command starts but produces no correctness/regression result while environment symptom also exists | `required test/build/baseline command` | `started-without-correctness/regression-result` | `waiver-ineligible` | stop with native blocker | stop with native blocker | stop with native blocker |'
  $startedWithoutResultWaived = $startedWithoutResultRow.Replace(
    '`waiver-ineligible` | stop with native blocker | stop with native blocker | stop with native blocker |',
    '`environment-unavailable` | stop with native blocker | stop with native blocker | continue with exact partial waiver |'
  )
  $mutatedOrchestrator = $orchestratorOriginal.Replace($startedWithoutResultRow, $startedWithoutResultWaived)
  Assert-True ($mutatedOrchestrator -ne $orchestratorOriginal) 'Started-without-result continuation mutation must alter orchestrator'
  [IO.File]::WriteAllText($orchestratorFixture, $mutatedOrchestrator, [Text.UTF8Encoding]::new($false))
  $skills = Invoke-Validator 'Skills'
  Assert-True ($skills.ExitCode -eq 1) "Started required command without a correctness result must stop in every mode. Output: $($skills.Output)"
  Assert-Contains $skills.Output "FAIL: Migration environment-waiver decision scenario invalid: $startedWithoutResultScenario" 'Started-without-result waiver exclusion'

  $requiredFailureScenario = 'required command starts and returns real failure while environment symptom also exists'
  $requiredFailureRow = '| 1 | required command starts and returns real failure while environment symptom also exists | `required test/build/baseline command` | `started-and-produced-correctness/regression-result` | `waiver-ineligible` | stop with native blocker | stop with native blocker | stop with native blocker |'
  $requiredFailureWrongPrecedence = '| 2 | required command starts and returns real failure while environment symptom also exists | `required test/build/baseline command` | `started-and-produced-correctness/regression-result` | `environment-unavailable` | stop with native blocker | stop with native blocker | continue with exact partial waiver |'
  $mutatedOrchestrator = $orchestratorOriginal.Replace($requiredFailureRow, $requiredFailureWrongPrecedence)
  Assert-True ($mutatedOrchestrator -ne $orchestratorOriginal) 'Required-command failure precedence mutation must alter orchestrator'
  [IO.File]::WriteAllText($orchestratorFixture, $mutatedOrchestrator, [Text.UTF8Encoding]::new($false))
  $skills = Invoke-Validator 'Skills'
  Assert-True ($skills.ExitCode -eq 1) "Required-command failure losing to an environment symptom should fail. Output: $($skills.Output)"
  Assert-Contains $skills.Output "FAIL: Migration environment-waiver decision scenario invalid: $requiredFailureScenario" 'Required-command failure precedence'

  $ineligibleWaiverRows = @(
    '| required test/build/baseline command started and returned failure, with or without a correctness/regression result | stop with native blocker | stop with native blocker | stop with native blocker |'
    '| schema/frontmatter/handoff invalid | stop with native blocker | stop with native blocker | stop with native blocker |'
    '| source/target path invalid or outside scope | stop with native blocker | stop with native blocker | stop with native blocker |'
    '| mode/policy/unit/foundation selector invalid, stale or ambiguous | stop with native blocker | stop with native blocker | stop with native blocker |'
    '| parity/regression detects a new failure | stop with native blocker | stop with native blocker | stop with native blocker |'
    '| destructive target is outside scope | stop with native blocker | stop with native blocker | stop with native blocker |'
    '| HARD gate | stop with native blocker | stop with native blocker | stop with native blocker |'
  )
  foreach ($ineligibleRow in $ineligibleWaiverRows) {
    $blocker = ($ineligibleRow.Trim('|').Split('|')[0]).Trim()
    $wrongAutoWaiveAction = $ineligibleRow.Substring(0, $ineligibleRow.LastIndexOf('stop with native blocker')) +
      'continue with exact partial waiver |'
    $mutatedOrchestrator = $orchestratorOriginal.Replace($ineligibleRow, $wrongAutoWaiveAction)
    Assert-True ($mutatedOrchestrator -ne $orchestratorOriginal) "Ineligible waiver mutation must alter orchestrator: $blocker"
    [IO.File]::WriteAllText($orchestratorFixture, $mutatedOrchestrator, [Text.UTF8Encoding]::new($false))
    $skills = Invoke-Validator 'Skills'
    Assert-True ($skills.ExitCode -eq 1) "Ineligible blocker continuation should fail: $blocker. Output: $($skills.Output)"
    Assert-Contains $skills.Output "FAIL: Migration waiver-ineligible scenario must stop in every mode: $blocker" "Ineligible waiver scenario: $blocker"
  }

  foreach ($truthMutation in @(
    [pscustomobject]@{
      Name = 'WAIVED with PASS'
      From = '`NOT_RUN + WAIVED`'
      To = '`PASS + WAIVED`'
      Expected = 'FAIL: Migration environment waiver must not combine PASS with WAIVED'
    }
    [pscustomobject]@{
      Name = 'waiver with complete result'
      From = 'result: partial'
      To = 'result: complete'
      Expected = 'FAIL: Migration environment-waiver continuation requires result: partial'
    }
    [pscustomobject]@{
      Name = 'waiver with auto approval source'
      From = 'approval_source: auto-waive'
      To = 'approval_source: auto'
      Expected = 'FAIL: Migration environment-waiver continuation requires approval_source: auto-waive'
    }
    [pscustomobject]@{
      Name = 'waiver without evidence'
      From = '  evidence: <verbatim capability/command error reference>'
      To = ''
      Expected = 'FAIL: Migration environment-waiver continuation requires waiver.evidence: <verbatim capability/command error reference>'
    }
  )) {
    $mutatedOrchestrator = Replace-InMarkdownSection `
      $orchestratorOriginal `
      'Environment waiver transition' `
      $truthMutation.From `
      $truthMutation.To
    Assert-True ($mutatedOrchestrator -ne $orchestratorOriginal) "Truthful waiver mutation must alter orchestrator: $($truthMutation.Name)"
    [IO.File]::WriteAllText($orchestratorFixture, $mutatedOrchestrator, [Text.UTF8Encoding]::new($false))
    $skills = Invoke-Validator 'Skills'
    Assert-True ($skills.ExitCode -eq 1) "Invalid truthful waiver pairing should fail: $($truthMutation.Name). Output: $($skills.Output)"
    Assert-Contains $skills.Output $truthMutation.Expected "Truthful waiver pairing: $($truthMutation.Name)"
  }

  $singleEligibleCauseOnly = Replace-InMarkdownSection `
    $orchestratorOriginal `
    'Environment waiver transition' `
    'one or more eligible causes all classified `environment-unavailable`' `
    'exactly one eligible cause classified `environment-unavailable`'
  Assert-True ($singleEligibleCauseOnly -ne $orchestratorOriginal) 'Multiple eligible environment causes mutation must alter orchestrator'
  [IO.File]::WriteAllText($orchestratorFixture, $singleEligibleCauseOnly, [Text.UTF8Encoding]::new($false))
  $skills = Invoke-Validator 'Skills'
  Assert-True ($skills.ExitCode -eq 1) "Classifier rejecting multiple eligible environment causes should fail. Output: $($skills.Output)"
  Assert-Contains $skills.Output 'FAIL: Migration environment-waiver transition missing: one or more eligible causes all classified `environment-unavailable`' 'Multiple eligible environment causes'

  $environmentErrorStopsBeforeClassifier = Replace-InMarkdownSection `
    $orchestratorOriginal `
    'Step execution protocol' `
    'A native command/capability error recorded in a contract-valid blocked artifact proceeds to the classifier in step 5.' `
    'A native command/capability error stops before the classifier in step 5.'
  Assert-True ($environmentErrorStopsBeforeClassifier -ne $orchestratorOriginal) 'Environment-error execution-seam mutation must alter orchestrator'
  [IO.File]::WriteAllText($orchestratorFixture, $environmentErrorStopsBeforeClassifier, [Text.UTF8Encoding]::new($false))
  $skills = Invoke-Validator 'Skills'
  Assert-True ($skills.ExitCode -eq 1) "Contract-valid environment blocker stopping before classifier should fail. Output: $($skills.Output)"
  Assert-Contains $skills.Output 'FAIL: Migration environment-waiver execution seam missing: A native command/capability error recorded in a contract-valid blocked artifact proceeds to the classifier in step 5.' 'Environment-error execution seam'

  $resumeIneligibleCandidate = 'waiver-ineligible blocker, started required command, schema/frontmatter/handoff error, or HARD gate'
  $resumeIneligibleRow = '| 1 | waiver-ineligible blocker, started required command, schema/frontmatter/handoff error, or HARD gate | forbidden | `in_progress` | forbidden |'
  $resumeIneligibleBypassed = $resumeIneligibleRow.Replace(
    '| forbidden | `in_progress` | forbidden |',
    '| re-invoke `migration/code-migration` with approved waiver artifact | `in_progress` | forbidden |'
  )
  $mutatedOrchestrator = $orchestratorOriginal.Replace($resumeIneligibleRow, $resumeIneligibleBypassed)
  Assert-True ($mutatedOrchestrator -ne $orchestratorOriginal) 'Step 10 ineligible-bypass mutation must alter orchestrator'
  [IO.File]::WriteAllText($orchestratorFixture, $mutatedOrchestrator, [Text.UTF8Encoding]::new($false))
  $orchestrators = Invoke-Validator 'Orchestrators'
  Assert-True ($orchestrators.ExitCode -eq 1) "Step 10 ineligible blocker re-entry should fail. Output: $($orchestrators.Output)"
  Assert-Contains $orchestrators.Output "FAIL: Migration step 10 baseline-waiver resume candidate invalid: $resumeIneligibleCandidate" 'Step 10 ineligible resume exclusion'

  $resumeEligibleCandidate = 'incremental step 10 pre-mutation baseline unavailable; separate availability probe; required command not-started; target unedited; exact waiver approved'
  $resumeEligibleRow = '| 2 | incremental step 10 pre-mutation baseline unavailable; separate availability probe; required command not-started; target unedited; exact waiver approved | re-invoke `migration/code-migration` with approved waiver artifact | `in_progress` | forbidden until resumed implementation receives normal approval |'
  $resumeWithoutReentry = $resumeEligibleRow.Replace(
    're-invoke `migration/code-migration` with approved waiver artifact',
    'continue to step 11 from approved partial artifact'
  )
  $mutatedOrchestrator = $orchestratorOriginal.Replace($resumeEligibleRow, $resumeWithoutReentry)
  Assert-True ($mutatedOrchestrator -ne $orchestratorOriginal) 'Step 10 no-re-entry mutation must alter orchestrator'
  [IO.File]::WriteAllText($orchestratorFixture, $mutatedOrchestrator, [Text.UTF8Encoding]::new($false))
  $orchestrators = Invoke-Validator 'Orchestrators'
  Assert-True ($orchestrators.ExitCode -eq 1) "Step 10 waiver continuation without re-entry should fail. Output: $($orchestrators.Output)"
  Assert-Contains $orchestrators.Output "FAIL: Migration step 10 baseline-waiver resume candidate invalid: $resumeEligibleCandidate" 'Step 10 required re-entry'

  $resumeCompletedEarly = $resumeEligibleRow.Replace('| `in_progress` |', '| `completed` |')
  $mutatedOrchestrator = $orchestratorOriginal.Replace($resumeEligibleRow, $resumeCompletedEarly)
  Assert-True ($mutatedOrchestrator -ne $orchestratorOriginal) 'Step 10 early-completion mutation must alter orchestrator'
  [IO.File]::WriteAllText($orchestratorFixture, $mutatedOrchestrator, [Text.UTF8Encoding]::new($false))
  $orchestrators = Invoke-Validator 'Orchestrators'
  Assert-True ($orchestrators.ExitCode -eq 1) "Step 10 todo completed before resumed implementation should fail. Output: $($orchestrators.Output)"
  Assert-Contains $orchestrators.Output "FAIL: Migration step 10 baseline-waiver resume candidate invalid: $resumeEligibleCandidate" 'Step 10 early completion exclusion'

  [IO.File]::WriteAllBytes($orchestratorFixture, $orchestratorOriginalBytes)
  $exactTupleOverride = 'For resumed step 10, this exact approved/partial/auto-waive tuple overrides generic steps 1 and 6.'
  $genericApprovalOverride = $orchestratorOriginal.Replace(
    $exactTupleOverride,
    'For resumed step 10, generic non-blocked approval in steps 1 and 6 is sufficient.'
  )
  Assert-True ($genericApprovalOverride -ne $orchestratorOriginal) 'Step 10 exact-tuple execution override mutation must alter orchestrator'
  [IO.File]::WriteAllText($orchestratorFixture, $genericApprovalOverride, [Text.UTF8Encoding]::new($false))
  $orchestrators = Invoke-Validator 'Orchestrators'
  Assert-True ($orchestrators.ExitCode -eq 1) "Generic approval overriding resumed exact tuple should fail. Output: $($orchestrators.Output)"
  Assert-Contains $orchestrators.Output "FAIL: Migration step 10 baseline-waiver resume missing: $exactTupleOverride" 'Step 10 exact tuple overrides generic approval'
}
finally {
  [IO.File]::WriteAllBytes($orchestratorFixture, $orchestratorOriginalBytes)
}

foreach ($launcherMutation in @(
  [pscustomobject]@{ Path = '../commands/migrate.md'; Context = 'Migrate command automation flags' }
  [pscustomobject]@{ Path = '../codex/skills/aitoolkit/SKILL.md'; Context = 'Codex launcher automation flags' }
)) {
  $launcherFixture = Join-Path $PSScriptRoot $launcherMutation.Path
  $launcherOriginalBytes = [IO.File]::ReadAllBytes($launcherFixture)
  $launcherOriginal = [Text.Encoding]::UTF8.GetString($launcherOriginalBytes)
  try {
    $parsedAutomationFlag = $launcherOriginal.Replace(
      'forward the selected flag unchanged',
      'translate the selected flag before forwarding'
    )
    Assert-True ($parsedAutomationFlag -ne $launcherOriginal) "Launcher unchanged-flag mutation must alter real file: $($launcherMutation.Context)"
    [IO.File]::WriteAllText($launcherFixture, $parsedAutomationFlag, [Text.UTF8Encoding]::new($false))
    $orchestrators = Invoke-Validator 'Orchestrators'
    Assert-True ($orchestrators.ExitCode -eq 1) "Launcher that rewrites automation flags should fail: $($launcherMutation.Context). Output: $($orchestrators.Output)"
    Assert-Contains $orchestrators.Output "FAIL: $($launcherMutation.Context) missing: forward the selected flag unchanged" $launcherMutation.Context

    $bothAutomationFlagsDropped = $launcherOriginal.Replace(
      'forward both unchanged',
      'reject both before forwarding'
    )
    Assert-True ($bothAutomationFlagsDropped -ne $launcherOriginal) "Launcher both-flags mutation must alter real file: $($launcherMutation.Context)"
    [IO.File]::WriteAllText($launcherFixture, $bothAutomationFlagsDropped, [Text.UTF8Encoding]::new($false))
    $orchestrators = Invoke-Validator 'Orchestrators'
    Assert-True ($orchestrators.ExitCode -eq 1) "Launcher that drops conflicting automation flags should fail: $($launcherMutation.Context). Output: $($orchestrators.Output)"
    Assert-Contains $orchestrators.Output "FAIL: $($launcherMutation.Context) missing: forward both unchanged" $launcherMutation.Context
  }
  finally {
    [IO.File]::WriteAllBytes($launcherFixture, $launcherOriginalBytes)
  }
}

$reviewTemplateFixture = Join-Path $PSScriptRoot '../templates/migration/review-report.md'
$reviewTemplateOriginalBytes = [IO.File]::ReadAllBytes($reviewTemplateFixture)
$reviewTemplateOriginal = [Text.Encoding]::UTF8.GetString($reviewTemplateOriginalBytes)
try {
  $reviewWithoutBaselineHandoff = $reviewTemplateOriginal.Replace(
    ' | Baseline Reference |',
    ' |'
  )
  [IO.File]::WriteAllText($reviewTemplateFixture, $reviewWithoutBaselineHandoff, [Text.UTF8Encoding]::new($false))
  $orchestrators = Invoke-Validator 'Orchestrators'
  Assert-True ($orchestrators.ExitCode -eq 1) "Shared review without baseline handoff should fail. Output: $($orchestrators.Output)"
  Assert-Contains $orchestrators.Output "FAIL: Migration review handoff template $selectedMigrationUnitSection table missing column: Baseline Reference" 'Review baseline handoff column'

  $reviewWithoutModeConstraint = $reviewTemplateOriginal.Replace(
    ' | Mode Constraint |',
    ' |'
  )
  [IO.File]::WriteAllText($reviewTemplateFixture, $reviewWithoutModeConstraint, [Text.UTF8Encoding]::new($false))
  $orchestrators = Invoke-Validator 'Orchestrators'
  Assert-True ($orchestrators.ExitCode -eq 1) "Shared review without mode constraint should fail. Output: $($orchestrators.Output)"
  Assert-Contains $orchestrators.Output "FAIL: Migration review handoff template $selectedMigrationUnitSection table missing column: Mode Constraint" 'Review mode-constraint handoff column'
}
finally {
  [IO.File]::WriteAllBytes($reviewTemplateFixture, $reviewTemplateOriginalBytes)
}

$verificationTemplateFixture = Join-Path $PSScriptRoot '../templates/migration/verification-report.md'
$verificationTemplateOriginalBytes = [IO.File]::ReadAllBytes($verificationTemplateFixture)
$verificationTemplateOriginal = [Text.Encoding]::UTF8.GetString($verificationTemplateOriginalBytes)
try {
  $verificationWithoutTraceHandoff = $verificationTemplateOriginal.Replace(
    ' | Trace IDs |',
    ' |'
  )
  [IO.File]::WriteAllText($verificationTemplateFixture, $verificationWithoutTraceHandoff, [Text.UTF8Encoding]::new($false))
  $orchestrators = Invoke-Validator 'Orchestrators'
  Assert-True ($orchestrators.ExitCode -eq 1) "Shared verification without trace handoff should fail. Output: $($orchestrators.Output)"
  Assert-Contains $orchestrators.Output "FAIL: Migration verification handoff template $selectedMigrationUnitSection table missing column: Trace IDs" 'Verification trace handoff column'
}
finally {
  [IO.File]::WriteAllBytes($verificationTemplateFixture, $verificationTemplateOriginalBytes)
}

$implementationWaiverTemplateFixture = Join-Path $PSScriptRoot '../templates/migration/implementation-report.md'
$implementationWaiverTemplateOriginalBytes = [IO.File]::ReadAllBytes($implementationWaiverTemplateFixture)
$implementationWaiverTemplateOriginal = [Text.Encoding]::UTF8.GetString($implementationWaiverTemplateOriginalBytes)
try {
  $implementationWithoutNativeEvidence = Replace-InMarkdownSection `
    $implementationWaiverTemplateOriginal `
    $nativeBlockersSection `
    ' | Evidence Reference |' `
    ' |'
  Assert-True ($implementationWithoutNativeEvidence -ne $implementationWaiverTemplateOriginal) 'Implementation native-evidence mutation must alter implementation-report template'
  [IO.File]::WriteAllText($implementationWaiverTemplateFixture, $implementationWithoutNativeEvidence, [Text.UTF8Encoding]::new($false))
  $templates = Invoke-Validator 'Templates'
  Assert-True ($templates.ExitCode -eq 1) "Implementation blocker without evidence reference should fail. Output: $($templates.Output)"
  Assert-Contains $templates.Output "FAIL: Template implementation-report.md native blocker evidence $nativeBlockersSection table columns must be exactly:" 'Implementation native blocker evidence'

  $implementationWithoutCommandRole = Replace-InMarkdownSection `
    $implementationWaiverTemplateOriginal `
    $nativeBlockersSection `
    ' | Command Role |' `
    ' |'
  Assert-True ($implementationWithoutCommandRole -ne $implementationWaiverTemplateOriginal) 'Implementation command-role mutation must alter implementation-report template'
  [IO.File]::WriteAllText($implementationWaiverTemplateFixture, $implementationWithoutCommandRole, [Text.UTF8Encoding]::new($false))
  $templates = Invoke-Validator 'Templates'
  Assert-True ($templates.ExitCode -eq 1) "Implementation blocker without command role should fail. Output: $($templates.Output)"
  Assert-Contains $templates.Output "FAIL: Template implementation-report.md native blocker evidence $nativeBlockersSection table columns must be exactly:" 'Implementation blocker command role'
}
finally {
  [IO.File]::WriteAllBytes($implementationWaiverTemplateFixture, $implementationWaiverTemplateOriginalBytes)
}

try {
  $verificationWithPassWaiver = Replace-InMarkdownSection `
    $verificationTemplateOriginal `
    $legalPairsSection `
    '| `NOT_RUN` | `WAIVED` | eligible environment blocker; orchestrator-only |' `
    '| `PASS` | `WAIVED` | eligible environment blocker; orchestrator-only |'
  Assert-True ($verificationWithPassWaiver -ne $verificationTemplateOriginal) 'Verification legal-pair PASS+WAIVED mutation must alter verification-report template'
  [IO.File]::WriteAllText($verificationTemplateFixture, $verificationWithPassWaiver, [Text.UTF8Encoding]::new($false))
  $templates = Invoke-Validator 'Templates'
  Assert-True ($templates.ExitCode -eq 1) "Verification template combining PASS with WAIVED should fail. Output: $($templates.Output)"
  Assert-Contains $templates.Output 'FAIL: Template verification-report.md legal check outcomes requires Execution Status = NOT_RUN whenever Verification Disposition = WAIVED' 'Verification PASS+WAIVED legal-pair exclusion'

  $verificationWithoutRequiredLifecycle = Replace-InMarkdownSection `
    $verificationTemplateOriginal `
    $checkOutcomesSection `
    ' | Required Command Lifecycle |' `
    ' |'
  Assert-True ($verificationWithoutRequiredLifecycle -ne $verificationTemplateOriginal) 'Verification required-command lifecycle mutation must alter verification-report template'
  [IO.File]::WriteAllText($verificationTemplateFixture, $verificationWithoutRequiredLifecycle, [Text.UTF8Encoding]::new($false))
  $templates = Invoke-Validator 'Templates'
  Assert-True ($templates.ExitCode -eq 1) "Verification outcome without required-command lifecycle should fail. Output: $($templates.Output)"
  Assert-Contains $templates.Output "FAIL: Template verification-report.md truthful check outcomes $checkOutcomesSection table columns must be exactly:" 'Verification required-command lifecycle'
}
finally {
  [IO.File]::WriteAllBytes($verificationTemplateFixture, $verificationTemplateOriginalBytes)
}

$waiverKnowledgeTemplateFixture = Join-Path $PSScriptRoot '../templates/kb-entry.md'
$waiverKnowledgeTemplateOriginalBytes = [IO.File]::ReadAllBytes($waiverKnowledgeTemplateFixture)
$waiverKnowledgeTemplateOriginal = [Text.Encoding]::UTF8.GetString($waiverKnowledgeTemplateOriginalBytes)
try {
  $knowledgeTemplateWithPassWaiver = Replace-InMarkdownSection `
    $waiverKnowledgeTemplateOriginal `
    $automationWaiversSection `
    '`NOT_RUN + WAIVED`' `
    '`PASS + WAIVED`'
  Assert-True ($knowledgeTemplateWithPassWaiver -ne $waiverKnowledgeTemplateOriginal) 'Knowledge PASS+WAIVED mutation must alter kb-entry template'
  [IO.File]::WriteAllText($waiverKnowledgeTemplateFixture, $knowledgeTemplateWithPassWaiver, [Text.UTF8Encoding]::new($false))
  $templates = Invoke-Validator 'Templates'
  Assert-True ($templates.ExitCode -eq 1) "Knowledge template combining PASS with WAIVED should fail. Output: $($templates.Output)"
  Assert-Contains $templates.Output 'FAIL: Template kb-entry.md must not combine PASS with WAIVED' 'Knowledge PASS+WAIVED exclusion'

  $knowledgeTemplateWithoutEvidence = Replace-InMarkdownSection `
    $waiverKnowledgeTemplateOriginal `
    $automationWaiversSection `
    ' | Evidence |' `
    ' |'
  Assert-True ($knowledgeTemplateWithoutEvidence -ne $waiverKnowledgeTemplateOriginal) 'Knowledge waiver-evidence mutation must alter kb-entry template'
  [IO.File]::WriteAllText($waiverKnowledgeTemplateFixture, $knowledgeTemplateWithoutEvidence, [Text.UTF8Encoding]::new($false))
  $templates = Invoke-Validator 'Templates'
  Assert-True ($templates.ExitCode -eq 1) "Knowledge waiver without evidence column should fail. Output: $($templates.Output)"
  Assert-Contains $templates.Output "FAIL: Template kb-entry.md automation waivers $automationWaiversSection table columns must be exactly:" 'Knowledge waiver evidence'
}
finally {
  [IO.File]::WriteAllBytes($waiverKnowledgeTemplateFixture, $waiverKnowledgeTemplateOriginalBytes)
}

$waiverCodeSkillFixture = Join-Path $PSScriptRoot '../skills/migration/code-migration/SKILL.md'
$waiverCodeSkillOriginalBytes = [IO.File]::ReadAllBytes($waiverCodeSkillFixture)
$waiverCodeSkillOriginal = [Text.Encoding]::UTF8.GetString($waiverCodeSkillOriginalBytes)
try {
  $codeSkillSelfWaives = Replace-InMarkdownSection `
    $waiverCodeSkillOriginal `
    'Native blocker evidence' `
    'does not add a `waiver`' `
    'adds a `waiver` before returning'
  Assert-True ($codeSkillSelfWaives -ne $waiverCodeSkillOriginal) 'Code Migration self-waiver mutation must alter code-migration skill'
  [IO.File]::WriteAllText($waiverCodeSkillFixture, $codeSkillSelfWaives, [Text.UTF8Encoding]::new($false))
  $skills = Invoke-Validator 'Skills'
  Assert-True ($skills.ExitCode -eq 1) "Code Migration approving its own environment waiver should fail. Output: $($skills.Output)"
  Assert-Contains $skills.Output 'FAIL: Code Migration native blocker evidence missing: does not add a `waiver`' 'Orchestrator-only Code Migration waiver'

  [IO.File]::WriteAllBytes($waiverCodeSkillFixture, $waiverCodeSkillOriginalBytes)
  $successfulResume = '| target source mutation recorded with selected unit and trace evidence; normal implementation outcome | `status: approved`; `result: partial`; `approval_source: auto-waive` | retain exact approved waiver and native evidence verbatim | allowed only on this exact valid partial outcome |'
  $resumeWithoutWaiver = $waiverCodeSkillOriginal.Replace(
    $successfulResume,
    '| target source mutation recorded with selected unit and trace evidence; normal implementation outcome | `status: approved`; `result: partial`; `approval_source: auto-waive` | drop approved waiver after resume | allowed only on this exact valid partial outcome |'
  )
  Assert-True ($resumeWithoutWaiver -ne $waiverCodeSkillOriginal) 'Code Migration waiver-loss mutation must alter code-migration skill'
  [IO.File]::WriteAllText($waiverCodeSkillFixture, $resumeWithoutWaiver, [Text.UTF8Encoding]::new($false))
  $skills = Invoke-Validator 'Skills'
  Assert-True ($skills.ExitCode -eq 1) "Code Migration dropping its approved waiver after resume should fail. Output: $($skills.Output)"
  Assert-Contains $skills.Output 'FAIL: Code Migration approved baseline-waiver resume outcome invalid: target source mutation recorded with selected unit and trace evidence; normal implementation outcome' 'Code Migration resume waiver retention'

  [IO.File]::WriteAllBytes($waiverCodeSkillFixture, $waiverCodeSkillOriginalBytes)
  $resumeAsComplete = $waiverCodeSkillOriginal.Replace(
    $successfulResume,
    '| target source mutation recorded with selected unit and trace evidence; normal implementation outcome | `status: approved`; `result: complete`; `approval_source: auto-waive` | retain exact approved waiver and native evidence verbatim | allowed |'
  )
  Assert-True ($resumeAsComplete -ne $waiverCodeSkillOriginal) 'Code Migration resumed-complete mutation must alter code-migration skill'
  [IO.File]::WriteAllText($waiverCodeSkillFixture, $resumeAsComplete, [Text.UTF8Encoding]::new($false))
  $skills = Invoke-Validator 'Skills'
  Assert-True ($skills.ExitCode -eq 1) "Code Migration marking a retained-waiver resume complete should fail. Output: $($skills.Output)"
  Assert-Contains $skills.Output 'FAIL: Code Migration approved baseline-waiver resume outcome invalid: target source mutation recorded with selected unit and trace evidence; normal implementation outcome' 'Code Migration resumed waiver remains partial'

  [IO.File]::WriteAllBytes($waiverCodeSkillFixture, $waiverCodeSkillOriginalBytes)
  $blockedWithoutMutation = '| no target source mutation | `blocked` | retain exact approved waiver and native evidence verbatim | forbidden |'
  $continuedWithoutMutation = $waiverCodeSkillOriginal.Replace(
    $blockedWithoutMutation,
    '| no target source mutation | `complete` | retain exact approved waiver and native evidence verbatim | allowed |'
  )
  Assert-True ($continuedWithoutMutation -ne $waiverCodeSkillOriginal) 'Code Migration source-not-mutated continuation mutation must alter code-migration skill'
  [IO.File]::WriteAllText($waiverCodeSkillFixture, $continuedWithoutMutation, [Text.UTF8Encoding]::new($false))
  $skills = Invoke-Validator 'Skills'
  Assert-True ($skills.ExitCode -eq 1) "Code Migration continuing without target source mutation should fail. Output: $($skills.Output)"
  Assert-Contains $skills.Output 'FAIL: Code Migration approved baseline-waiver resume outcome invalid: no target source mutation' 'Code Migration requires resumed source mutation'
}
finally {
  [IO.File]::WriteAllBytes($waiverCodeSkillFixture, $waiverCodeSkillOriginalBytes)
}

$waiverVerificationSkillFixture = Join-Path $PSScriptRoot '../skills/shared/verification-testing/SKILL.md'
$waiverVerificationSkillOriginalBytes = [IO.File]::ReadAllBytes($waiverVerificationSkillFixture)
$waiverVerificationSkillOriginal = [Text.Encoding]::UTF8.GetString($waiverVerificationSkillOriginalBytes)
try {
  $verificationSkillPromotesWaiver = Replace-InMarkdownSection `
    $waiverVerificationSkillOriginal `
    'Environment-unavailable checks' `
    'never `PASS`' `
    'may become `PASS`'
  Assert-True ($verificationSkillPromotesWaiver -ne $waiverVerificationSkillOriginal) 'Verification waiver-promotion mutation must alter verification-testing skill'
  [IO.File]::WriteAllText($waiverVerificationSkillFixture, $verificationSkillPromotesWaiver, [Text.UTF8Encoding]::new($false))
  $skills = Invoke-Validator 'Skills'
  Assert-True ($skills.ExitCode -eq 1) "Verification promoting a waived check to PASS should fail. Output: $($skills.Output)"
  Assert-Contains $skills.Output 'FAIL: Shared verification environment-unavailable checks missing: never `PASS`' 'Verification waiver truthfulness'
}
finally {
  [IO.File]::WriteAllBytes($waiverVerificationSkillFixture, $waiverVerificationSkillOriginalBytes)
}

$waiverKnowledgeSkillFixture = Join-Path $PSScriptRoot '../skills/shared/knowledge-base/SKILL.md'
$waiverKnowledgeSkillOriginalBytes = [IO.File]::ReadAllBytes($waiverKnowledgeSkillFixture)
$waiverKnowledgeSkillOriginal = [Text.Encoding]::UTF8.GetString($waiverKnowledgeSkillOriginalBytes)
try {
  $knowledgeSkillPromotesPartial = Replace-InMarkdownSection `
    $waiverKnowledgeSkillOriginal `
    'Migration automation waivers' `
    '`Completion Verdict: partial`' `
    '`Completion Verdict: complete`'
  Assert-True ($knowledgeSkillPromotesPartial -ne $waiverKnowledgeSkillOriginal) 'Knowledge waiver-promotion mutation must alter knowledge-base skill'
  [IO.File]::WriteAllText($waiverKnowledgeSkillFixture, $knowledgeSkillPromotesPartial, [Text.UTF8Encoding]::new($false))
  $skills = Invoke-Validator 'Skills'
  Assert-True ($skills.ExitCode -eq 1) "Knowledge Capture promoting a waived migration to complete should fail. Output: $($skills.Output)"
  Assert-Contains $skills.Output 'FAIL: Knowledge Capture migration automation waivers missing: `Completion Verdict: partial`' 'Knowledge waiver completion truthfulness'
}
finally {
  [IO.File]::WriteAllBytes($waiverKnowledgeSkillFixture, $waiverKnowledgeSkillOriginalBytes)
}

$regressionTemplateFixture = Join-Path $templateRoot 'regression-report.md'
$regressionTemplateOriginalBytes = [IO.File]::ReadAllBytes($regressionTemplateFixture)
$regressionTemplateOriginal = [Text.Encoding]::UTF8.GetString($regressionTemplateOriginalBytes)
try {
  if ($regressionTemplateOriginal.Contains("## $selectedMigrationUnitSection")) {
    $regressionWithoutEnvelope = $regressionTemplateOriginal.Replace(
      "## $selectedMigrationUnitSection",
      '## Lost Migration Unit'
    )
  }
  else {
    $regressionWithoutEnvelope = $regressionTemplateOriginal + [Environment]::NewLine +
      'Migration Unit ID, Plan Reference, Approval Reference, Mode Constraint, Bootstrap Scope, Baseline Reference, and Trace IDs are notes outside a handoff section.' + [Environment]::NewLine
  }
  Assert-True ($regressionWithoutEnvelope -ne $regressionTemplateOriginal) 'Regression envelope mutation must alter regression-report template'
  [IO.File]::WriteAllText($regressionTemplateFixture, $regressionWithoutEnvelope, [Text.UTF8Encoding]::new($false))
  $orchestrators = Invoke-Validator 'Orchestrators'
  Assert-True ($orchestrators.ExitCode -eq 1) "Regression report without selected-unit envelope should fail. Output: $($orchestrators.Output)"
  Assert-Contains $orchestrators.Output "FAIL: Migration regression handoff template missing section: $selectedMigrationUnitSection" 'Regression selected-unit envelope'
}
finally {
  [IO.File]::WriteAllBytes($regressionTemplateFixture, $regressionTemplateOriginalBytes)
}

try {
  if ($regressionSkillOriginal.Contains('## Migration-only handoff extension')) {
    $regressionWithoutHandoffGate = $regressionSkillOriginal.Replace(
      '## Migration-only handoff extension',
      '## Optional migration notes'
    )
  }
  else {
    $regressionWithoutHandoffGate = $regressionSkillOriginal + [Environment]::NewLine +
      "## Optional migration notes`r`n`r`nThe selected unit may be reconstructed from earlier artifacts.`r`n"
  }
  Assert-True ($regressionWithoutHandoffGate -ne $regressionSkillOriginal) 'Regression skill handoff mutation must alter verify-regression'
  [IO.File]::WriteAllText($regressionSkillFixture, $regressionWithoutHandoffGate, [Text.UTF8Encoding]::new($false))
  $orchestrators = Invoke-Validator 'Orchestrators'
  Assert-True ($orchestrators.ExitCode -eq 1) "Regression skill without migration handoff gate should fail. Output: $($orchestrators.Output)"
  Assert-Contains $orchestrators.Output 'FAIL: Migration regression handoff missing section: Migration-only handoff extension' 'Regression skill handoff extension'
}
finally {
  [IO.File]::WriteAllBytes($regressionSkillFixture, $regressionSkillOriginalBytes)
}

$gerritTemplateFixture = Join-Path $PSScriptRoot '../templates/gerrit-report.md'
$gerritTemplateOriginalBytes = [IO.File]::ReadAllBytes($gerritTemplateFixture)
$gerritTemplateOriginal = [Text.Encoding]::UTF8.GetString($gerritTemplateOriginalBytes)
try {
  if ($gerritTemplateOriginal.Contains('## Migration Verification Verdicts')) {
    $gerritWithoutMigrationVerdicts = $gerritTemplateOriginal.Replace(
      '## Migration Verification Verdicts',
      '## Migration Verification Notes'
    )
  }
  else {
    $gerritWithoutMigrationVerdicts = $gerritTemplateOriginal + [Environment]::NewLine +
      "## Migration Verification Notes`r`n`r`nParity and regression are summarized without preserving the selected unit or verdict fields.`r`n"
  }
  Assert-True ($gerritWithoutMigrationVerdicts -ne $gerritTemplateOriginal) 'Gerrit migration verdict mutation must alter gerrit template'
  [IO.File]::WriteAllText($gerritTemplateFixture, $gerritWithoutMigrationVerdicts, [Text.UTF8Encoding]::new($false))
  $orchestrators = Invoke-Validator 'Orchestrators'
  Assert-True ($orchestrators.ExitCode -eq 0) "Migration orchestrator must not require a post-regression Gerrit verdict envelope. Output: $($orchestrators.Output)"
}
finally {
  [IO.File]::WriteAllBytes($gerritTemplateFixture, $gerritTemplateOriginalBytes)
}

$gerritSkillFixture = Join-Path $PSScriptRoot '../skills/shared/gerrit-automation/SKILL.md'
$gerritSkillOriginalBytes = [IO.File]::ReadAllBytes($gerritSkillFixture)
$gerritSkillOriginal = [Text.Encoding]::UTF8.GetString($gerritSkillOriginalBytes)
try {
  if ($gerritSkillOriginal.Contains('## Migration-only predecessor gate')) {
    $gerritWithoutImmediateMigrationPredecessor = $gerritSkillOriginal.Replace(
      '## Migration-only predecessor gate',
      '## Migration predecessor notes'
    )
  }
  else {
    $gerritWithoutImmediateMigrationPredecessor = $gerritSkillOriginal + [Environment]::NewLine +
      "## Migration predecessor notes`r`n`r`nRead the fixed verification report and ignore the immediate parity/regression predecessor.`r`n"
  }
  Assert-True ($gerritWithoutImmediateMigrationPredecessor -ne $gerritSkillOriginal) 'Gerrit immediate-predecessor mutation must alter Gerrit skill'
  [IO.File]::WriteAllText($gerritSkillFixture, $gerritWithoutImmediateMigrationPredecessor, [Text.UTF8Encoding]::new($false))
  $orchestrators = Invoke-Validator 'Orchestrators'
  Assert-True ($orchestrators.ExitCode -eq 0) "Migration orchestrator must not require the removed Gerrit predecessor gate. Output: $($orchestrators.Output)"

  [IO.File]::WriteAllBytes($gerritSkillFixture, $gerritSkillOriginalBytes)
  $gerritAcceptsParityForIncremental = $gerritSkillOriginal.Replace(
    '`14-regression-report.md`',
    '`13-parity-report.md`'
  )
  Assert-True ($gerritAcceptsParityForIncremental -ne $gerritSkillOriginal) 'Gerrit predecessor-identity mutation must alter Gerrit skill'
  [IO.File]::WriteAllText($gerritSkillFixture, $gerritAcceptsParityForIncremental, [Text.UTF8Encoding]::new($false))
  $orchestrators = Invoke-Validator 'Orchestrators'
  Assert-True ($orchestrators.ExitCode -eq 0) "Migration orchestrator must not validate delivery-envelope predecessor identities after regression. Output: $($orchestrators.Output)"
}
finally {
  [IO.File]::WriteAllBytes($gerritSkillFixture, $gerritSkillOriginalBytes)
}

$independentSharedSkillContracts = @(
  [pscustomobject]@{ Name = 'gerrit-automation'; Tokens = @('HARD gate', 'upload Gerrit') }
  [pscustomobject]@{ Name = 'ccc-automation'; Tokens = @('OPTIONAL', 'optional') }
  [pscustomobject]@{ Name = 'release'; Tokens = @('OPTIONAL', 'HARD gate') }
)
foreach ($sharedContract in $independentSharedSkillContracts) {
  $sharedSkillPath = Join-Path $PSScriptRoot "../skills/shared/$($sharedContract.Name)/SKILL.md"
  Assert-True (Test-Path $sharedSkillPath) "Independent shared skill must remain available: $($sharedContract.Name)"
  if (Test-Path $sharedSkillPath) {
    $sharedSkillText = Get-Content -Raw -Encoding utf8 $sharedSkillPath
    foreach ($token in $sharedContract.Tokens) {
      Assert-Contains $sharedSkillText $token "Independent shared skill behavior $($sharedContract.Name)"
    }
  }
}

$bootstrapSkillFixture = Join-Path $skillRoot 'bootstrap-target/SKILL.md'
$bootstrapSkillOriginalBytes = [IO.File]::ReadAllBytes($bootstrapSkillFixture)
$bootstrapSkillOriginal = [Text.Encoding]::UTF8.GetString($bootstrapSkillOriginalBytes)
try {
  $bootstrapSelectorOutsideInputs = $bootstrapSkillOriginal.Replace(
    ', and `migration_unit_id` alongside that path.',
    '.'
  ) + [Environment]::NewLine + 'The orchestrator also provides `migration_unit_id`.' + [Environment]::NewLine
  [IO.File]::WriteAllText($bootstrapSkillFixture, $bootstrapSelectorOutsideInputs, [Text.UTF8Encoding]::new($false))
  $skills = Invoke-Validator 'Skills'
  Assert-True ($skills.ExitCode -eq 1) "Bootstrap selector outside Inputs should fail. Output: $($skills.Output)"
  Assert-Contains $skills.Output 'FAIL: Skill bootstrap-target/SKILL.md Inputs missing: `migration_unit_id`' 'Bootstrap selector location'

  $bootstrapWithoutPreservation = $bootstrapSkillOriginal.Replace(
    "- Preserve ``$selectedMigrationUnitSection`` with ``migration_unit_id``, plan reference, approval reference, mode constraint, ``Bootstrap Scope``, ``Foundation Baseline ID``, foundation baseline reference, foundation baseline approval reference, baseline reference ``not-applicable``, and trace IDs.",
    '- Record the bootstrap scope.'
  ) + [Environment]::NewLine + 'migration_unit_id, plan reference, approval reference, mode constraint, Bootstrap Scope, baseline reference, and trace IDs.' + [Environment]::NewLine
  [IO.File]::WriteAllText($bootstrapSkillFixture, $bootstrapWithoutPreservation, [Text.UTF8Encoding]::new($false))
  $skills = Invoke-Validator 'Skills'
  Assert-True ($skills.ExitCode -eq 1) "Bootstrap handoff fields outside output contract should fail. Output: $($skills.Output)"
  Assert-Contains $skills.Output 'FAIL: Skill bootstrap-target/SKILL.md output missing selected-unit handoff contract' 'Bootstrap handoff preservation'
}
finally {
  [IO.File]::WriteAllBytes($bootstrapSkillFixture, $bootstrapSkillOriginalBytes)
}

$bootstrapTemplateFixture = Join-Path $templateRoot 'bootstrap-report.md'
$bootstrapTemplateOriginalBytes = [IO.File]::ReadAllBytes($bootstrapTemplateFixture)
$bootstrapTemplateOriginal = [Text.Encoding]::UTF8.GetString($bootstrapTemplateOriginalBytes)
try {
  $bootstrapTemplateWithoutReferences = $bootstrapTemplateOriginal.Replace(
    '| Migration Unit ID | Plan Reference | Approval Reference | Mode Constraint | Bootstrap Scope | Foundation Baseline ID | Foundation Baseline Reference | Foundation Baseline Approval Reference | Baseline Reference | Trace IDs |',
    '| Unit | Scope |'
  ) + [Environment]::NewLine + 'Migration Unit ID, Plan Reference, and Approval Reference.' + [Environment]::NewLine
  [IO.File]::WriteAllText($bootstrapTemplateFixture, $bootstrapTemplateWithoutReferences, [Text.UTF8Encoding]::new($false))
  $skills = Invoke-Validator 'Skills'
  Assert-True ($skills.ExitCode -eq 1) "Bootstrap handoff table without identity references should fail. Output: $($skills.Output)"
  Assert-Contains $skills.Output "FAIL: Bootstrap handoff template $selectedMigrationUnitSection table missing column: Migration Unit ID" 'Bootstrap handoff identity column'
  Assert-Contains $skills.Output "FAIL: Bootstrap handoff template $selectedMigrationUnitSection table missing column: Plan Reference" 'Bootstrap plan reference column'
  Assert-Contains $skills.Output "FAIL: Bootstrap handoff template $selectedMigrationUnitSection table missing column: Approval Reference" 'Bootstrap approval reference column'

  $bootstrapWithoutModeConstraint = $bootstrapTemplateOriginal.Replace(
    ' | Mode Constraint |',
    ' |'
  )
  [IO.File]::WriteAllText($bootstrapTemplateFixture, $bootstrapWithoutModeConstraint, [Text.UTF8Encoding]::new($false))
  $orchestrators = Invoke-Validator 'Orchestrators'
  Assert-True ($orchestrators.ExitCode -eq 1) "Bootstrap handoff without mode constraint should fail. Output: $($orchestrators.Output)"
  Assert-Contains $orchestrators.Output "FAIL: Migration bootstrap handoff template $selectedMigrationUnitSection table missing column: Mode Constraint" 'Bootstrap mode-constraint handoff column'
}
finally {
  [IO.File]::WriteAllBytes($bootstrapTemplateFixture, $bootstrapTemplateOriginalBytes)
}

try {
  $bootstrapPreclaimsApproval = $bootstrapTemplateOriginal.Replace(
    $pendingApprovalPhrase,
    'approved before the gate'
  )
  Assert-True ($bootstrapPreclaimsApproval -ne $bootstrapTemplateOriginal) 'Bootstrap pre-approval mutation must alter bootstrap template'
  [IO.File]::WriteAllText($bootstrapTemplateFixture, $bootstrapPreclaimsApproval, [Text.UTF8Encoding]::new($false))
  $templates = Invoke-Validator 'Templates'
  Assert-True ($templates.ExitCode -eq 1) "Draft bootstrap record that preclaims approval should fail. Output: $($templates.Output)"
  Assert-Contains $templates.Output 'FAIL: Template bootstrap-report.md foundation lifecycle missing: pending-approval' 'Bootstrap draft approval status'
}
finally {
  [IO.File]::WriteAllBytes($bootstrapTemplateFixture, $bootstrapTemplateOriginalBytes)
}

try {
  $selectedUnitPreclaimsApproval = $bootstrapTemplateOriginal.Replace(
    '<pending-step09-approval>',
    '<approved step-09 gate reference>'
  )
  Assert-True ($selectedUnitPreclaimsApproval -ne $bootstrapTemplateOriginal) 'Selected-unit pre-approval mutation must alter bootstrap template'
  [IO.File]::WriteAllText($bootstrapTemplateFixture, $selectedUnitPreclaimsApproval, [Text.UTF8Encoding]::new($false))
  $templates = Invoke-Validator 'Templates'
  Assert-True ($templates.ExitCode -eq 1) "Draft Selected Migration Unit that preclaims approval should fail. Output: $($templates.Output)"
  Assert-Contains $templates.Output 'FAIL: Template bootstrap-report.md draft Selected Migration Unit preclaims approved foundation reference' 'Selected-unit draft approval reference'
}
finally {
  [IO.File]::WriteAllBytes($bootstrapTemplateFixture, $bootstrapTemplateOriginalBytes)
}

$migrationPlanTemplateFixture = Join-Path $templateRoot 'migration-plan.md'
$migrationPlanTemplateOriginalBytes = [IO.File]::ReadAllBytes($migrationPlanTemplateFixture)
$migrationPlanTemplateOriginal = [Text.Encoding]::UTF8.GetString($migrationPlanTemplateOriginalBytes)
try {
  $migrationPlanWithoutApprovedRecord = $migrationPlanTemplateOriginal.Replace(
    '| Order | Migration Unit ID | Bootstrap Scope | Foundation Baseline ID | Foundation Approval Reference | Dependencies | Acceptance | Mode Constraint | Trace IDs | Delivery Change Boundary | Approval Reference | Approval Status |',
    '| Order | Unit | Dependencies | Acceptance |'
  ) + [Environment]::NewLine + 'Migration Unit ID, Mode Constraint, Trace IDs, Approval Reference, and Approval Status.' + [Environment]::NewLine
  [IO.File]::WriteAllText($migrationPlanTemplateFixture, $migrationPlanWithoutApprovedRecord, [Text.UTF8Encoding]::new($false))
  $templates = Invoke-Validator 'Templates'
  Assert-True ($templates.ExitCode -eq 1) "Migration plan without an approved unit record should fail. Output: $($templates.Output)"
  Assert-Contains $templates.Output "FAIL: Template migration-plan.md $orderedUnitsSection table missing column: Migration Unit ID" 'Migration plan stable unit selector'
  Assert-Contains $templates.Output "FAIL: Template migration-plan.md $orderedUnitsSection table missing column: Approval Reference" 'Migration plan unit approval reference'
  Assert-Contains $templates.Output "FAIL: Template migration-plan.md $orderedUnitsSection table missing column: Approval Status" 'Migration plan unit approval status'

  $migrationPlanWithoutBootstrapScope = $migrationPlanTemplateOriginal.Replace(
    ' | Bootstrap Scope |',
    ' |'
  )
  [IO.File]::WriteAllText($migrationPlanTemplateFixture, $migrationPlanWithoutBootstrapScope, [Text.UTF8Encoding]::new($false))
  $templates = Invoke-Validator 'Templates'
  Assert-True ($templates.ExitCode -eq 1) "Migration plan without Bootstrap Scope should fail. Output: $($templates.Output)"
  Assert-Contains $templates.Output "FAIL: Template migration-plan.md $orderedUnitsSection table missing column: Bootstrap Scope" 'Missing bootstrap-scope field'

  $migrationPlanScopeOutsideTable = $migrationPlanWithoutBootstrapScope +
    [Environment]::NewLine + 'Bootstrap Scope: required | not-required' + [Environment]::NewLine
  [IO.File]::WriteAllText($migrationPlanTemplateFixture, $migrationPlanScopeOutsideTable, [Text.UTF8Encoding]::new($false))
  $templates = Invoke-Validator 'Templates'
  Assert-True ($templates.ExitCode -eq 1) "Bootstrap Scope outside the unit table should fail. Output: $($templates.Output)"
  Assert-Contains $templates.Output "FAIL: Template migration-plan.md $orderedUnitsSection table missing column: Bootstrap Scope" 'Table-local bootstrap-scope field'
}
finally {
  [IO.File]::WriteAllBytes($migrationPlanTemplateFixture, $migrationPlanTemplateOriginalBytes)
}

try {
  $invalidBootstrapScopeValues = $planWavesOriginal.Replace(
    '`required | not-required`',
    '`required | optional`'
  )
  [IO.File]::WriteAllText($planWavesFixture, $invalidBootstrapScopeValues, [Text.UTF8Encoding]::new($false))
  $skills = Invoke-Validator 'Skills'
  Assert-True ($skills.ExitCode -eq 1) "Invalid Bootstrap Scope values should fail. Output: $($skills.Output)"
  Assert-Contains $skills.Output 'FAIL: Skill plan-waves/SKILL.md section Procedure missing: `required | not-required`' 'Bootstrap-scope value enum'

  $wrongModeBootstrapScope = $planWavesOriginal.Replace(
    'every unit uses `not-required` and Foundation Baseline ID is `not-applicable`; wrong-mode scope yields `result: blocked`',
    'units may use `required` when convenient'
  )
  [IO.File]::WriteAllText($planWavesFixture, $wrongModeBootstrapScope, [Text.UTF8Encoding]::new($false))
  $skills = Invoke-Validator 'Skills'
  Assert-True ($skills.ExitCode -eq 1) "Incremental Bootstrap Scope required should fail. Output: $($skills.Output)"
  Assert-Contains $skills.Output 'FAIL: Skill plan-waves/SKILL.md section Procedure missing: wrong-mode scope yields `result: blocked`' 'Bootstrap-scope mode invariant'

  $bootstrapScopeOutsideOutput = $planWavesOriginal.Replace(
    ', `Bootstrap Scope`',
    ''
  ) + [Environment]::NewLine + 'Bootstrap Scope is described outside the output contract.' + [Environment]::NewLine
  [IO.File]::WriteAllText($planWavesFixture, $bootstrapScopeOutsideOutput, [Text.UTF8Encoding]::new($false))
  $skills = Invoke-Validator 'Skills'
  Assert-True ($skills.ExitCode -eq 1) "Bootstrap Scope outside plan-waves output should fail. Output: $($skills.Output)"
  Assert-Contains $skills.Output 'FAIL: Skill plan-waves/SKILL.md output missing: `Bootstrap Scope`' 'Plan output bootstrap-scope field'
}
finally {
  [IO.File]::WriteAllBytes($planWavesFixture, $planWavesOriginalBytes)
}

try {
  $bootstrapAcceptsNotRequired = $bootstrapSkillOriginal.Replace(
    '`Bootstrap Scope = required`',
    '`Bootstrap Scope = not-required`'
  )
  [IO.File]::WriteAllText($bootstrapSkillFixture, $bootstrapAcceptsNotRequired, [Text.UTF8Encoding]::new($false))
  $skills = Invoke-Validator 'Skills'
  Assert-True ($skills.ExitCode -eq 1) "Bootstrap selected unit with not-required scope should fail. Output: $($skills.Output)"
  Assert-Contains $skills.Output 'FAIL: Skill bootstrap-target/SKILL.md section Mode gate missing: `Bootstrap Scope = required`' 'Bootstrap required-scope gate'
}
finally {
  [IO.File]::WriteAllBytes($bootstrapSkillFixture, $bootstrapSkillOriginalBytes)
}

try {
  $codeMigrationLosesScopeLineage = $codeMigrationOriginal.Replace(
    'preserved `Bootstrap Scope = required`',
    'unclassified bootstrap scope'
  )
  [IO.File]::WriteAllText($codeMigrationFixture, $codeMigrationLosesScopeLineage, [Text.UTF8Encoding]::new($false))
  $skills = Invoke-Validator 'Skills'
  Assert-True ($skills.ExitCode -eq 1) "Code migration without preserved bootstrap scope should fail. Output: $($skills.Output)"
  Assert-Contains $skills.Output 'FAIL: Skill code-migration/SKILL.md section Entry gate missing: preserved `Bootstrap Scope = required`' 'Bootstrap-scope lineage'
}
finally {
  [IO.File]::WriteAllBytes($codeMigrationFixture, $codeMigrationOriginalBytes)
}

try {
  $greenfieldMismatchAllowed = $codeMigrationOriginal.Replace(
    'selector mismatch yields `result: blocked`',
    'prefer the bootstrap record when selectors differ'
  )
  [IO.File]::WriteAllText($codeMigrationFixture, $greenfieldMismatchAllowed, [Text.UTF8Encoding]::new($false))
  $skills = Invoke-Validator 'Skills'
  Assert-True ($skills.ExitCode -eq 1) "Greenfield selector mismatch should fail. Output: $($skills.Output)"
  Assert-Contains $skills.Output 'FAIL: Skill code-migration/SKILL.md section Entry gate missing: selector mismatch yields `result: blocked`' 'Greenfield selector match contract'
}
finally {
  [IO.File]::WriteAllBytes($codeMigrationFixture, $codeMigrationOriginalBytes)
}

$validateInputsFixture = Join-Path $skillRoot 'validate-inputs/SKILL.md'
$validateInputsOriginalBytes = [IO.File]::ReadAllBytes($validateInputsFixture)
$validateInputsOriginal = [Text.Encoding]::UTF8.GetString($validateInputsOriginalBytes)
try {
  $reviewFreshnessContract = 'A missing, null, invalid, or stale `project_pack.reviewed_at` yields `result: blocked`.'
  if ($validateInputsOriginal.Contains($reviewFreshnessContract)) {
    $staleReviewedPackAccepted = $validateInputsOriginal.Replace(
      '`project_pack.reviewed_at`',
      '`project_pack.review_timestamp`'
    )
  }
  else {
    $staleReviewedPackAccepted = $validateInputsOriginal.Replace(
      '1. Read `aitoolkit-schemas`, project profile, project pack and artifact path provided by the orchestrator.',
      '1. Read `aitoolkit-schemas`, project profile, project pack and artifact path provided by the orchestrator. A null or stale `project_pack.reviewed_at` may proceed.'
    )
    if ($staleReviewedPackAccepted -eq $validateInputsOriginal) {
      $staleReviewedPackAccepted = $validateInputsOriginal + [Environment]::NewLine + 'A null or stale `project_pack.reviewed_at` may proceed.' + [Environment]::NewLine
    }
  }
  Assert-True ($staleReviewedPackAccepted -ne $validateInputsOriginal) 'Stale reviewed-pack mutation must alter validate-inputs'
  [IO.File]::WriteAllText($validateInputsFixture, $staleReviewedPackAccepted, [Text.UTF8Encoding]::new($false))
  $skills = Invoke-Validator 'Skills'
  Assert-True ($skills.ExitCode -eq 1) "Missing/stale reviewed_at should fail migration input validation. Output: $($skills.Output)"
  Assert-Contains $skills.Output 'FAIL: Skill validate-inputs/SKILL.md project-pack review gate missing: `project_pack.reviewed_at`' 'Reviewed pack timestamp gate'

  [IO.File]::WriteAllBytes($validateInputsFixture, $validateInputsOriginalBytes)
  $staleReviewMayProceed = $validateInputsOriginal.Replace(
    $reviewFreshnessContract,
    'A missing, null, invalid, or stale `project_pack.reviewed_at` is noted but may proceed; an unrelated error still yields `result: blocked`.'
  )
  Assert-True ($staleReviewMayProceed -ne $validateInputsOriginal) 'Stale reviewed-pack policy mutation must alter validate-inputs'
  [IO.File]::WriteAllText($validateInputsFixture, $staleReviewMayProceed, [Text.UTF8Encoding]::new($false))
  $skills = Invoke-Validator 'Skills'
  Assert-True ($skills.ExitCode -eq 1) "Stale reviewed_at that may proceed should fail migration input validation. Output: $($skills.Output)"
  Assert-Contains $skills.Output "FAIL: Skill validate-inputs/SKILL.md project-pack review gate missing: $reviewFreshnessContract" 'Stale reviewed pack blocked policy'
}
finally {
  [IO.File]::WriteAllBytes($validateInputsFixture, $validateInputsOriginalBytes)
}

try {
  $foundationContract = 'A greenfield / `design-new` unit with `Bootstrap Scope = not-required` must select exactly one approved `Foundation Baseline ID`.'
  if ($planWavesOriginal.Contains($foundationContract)) {
    $laterUnitWithoutFoundation = $planWavesOriginal.Replace(
      $foundationContract,
      'A later greenfield unit may proceed without selecting an approved foundation baseline.'
    )
  }
  else {
    $laterUnitWithoutFoundation = $planWavesOriginal + [Environment]::NewLine +
      "## Foundation baseline contract`r`n`r`nA later greenfield unit may proceed without selecting an approved foundation baseline.`r`n"
  }
  Assert-True ($laterUnitWithoutFoundation -ne $planWavesOriginal) 'Later-greenfield foundation mutation must alter plan-waves'
  [IO.File]::WriteAllText($planWavesFixture, $laterUnitWithoutFoundation, [Text.UTF8Encoding]::new($false))
  $skills = Invoke-Validator 'Skills'
  Assert-True ($skills.ExitCode -eq 1) "Later greenfield unit without approved foundation baseline should fail. Output: $($skills.Output)"
  Assert-Contains $skills.Output 'FAIL: Skill plan-waves/SKILL.md foundation baseline contract missing: exactly one approved `Foundation Baseline ID`' 'Later greenfield foundation baseline gate'
}
finally {
  [IO.File]::WriteAllBytes($planWavesFixture, $planWavesOriginalBytes)
}

try {
  $pendingBootstrapMayProceed = 'must not resolve or require an existing foundation baseline before step 09'
  $foundationRequiresExistingBaseline = $planWavesOriginal.Replace(
    $pendingBootstrapMayProceed,
    'must resolve and require an existing approved foundation baseline before step 09'
  )
  Assert-True ($foundationRequiresExistingBaseline -ne $planWavesOriginal) 'Pending-bootstrap deadlock mutation must alter plan-waves'
  [IO.File]::WriteAllText($planWavesFixture, $foundationRequiresExistingBaseline, [Text.UTF8Encoding]::new($false))
  $skills = Invoke-Validator 'Skills'
  Assert-True ($skills.ExitCode -eq 1) "Foundation unit requiring an existing baseline before bootstrap should fail. Output: $($skills.Output)"
  Assert-Contains $skills.Output "FAIL: Skill plan-waves/SKILL.md foundation baseline contract missing: $pendingBootstrapMayProceed" 'First-foundation pending-bootstrap route'
}
finally {
  [IO.File]::WriteAllBytes($planWavesFixture, $planWavesOriginalBytes)
}

try {
  $laterMissingApprovalPolicy = 'missing ID or approval reference'
  $laterUnitWithoutApprovalReference = $planWavesOriginal.Replace(
    $laterMissingApprovalPolicy,
    'missing ID may proceed when a likely baseline is visible'
  )
  Assert-True ($laterUnitWithoutApprovalReference -ne $planWavesOriginal) 'Later-greenfield approval-reference mutation must alter plan-waves'
  [IO.File]::WriteAllText($planWavesFixture, $laterUnitWithoutApprovalReference, [Text.UTF8Encoding]::new($false))
  $skills = Invoke-Validator 'Skills'
  Assert-True ($skills.ExitCode -eq 1) "Later greenfield unit without a baseline approval reference should fail. Output: $($skills.Output)"
  Assert-Contains $skills.Output "FAIL: Skill plan-waves/SKILL.md foundation baseline contract missing: $laterMissingApprovalPolicy" 'Later-greenfield baseline approval reference gate'
}
finally {
  [IO.File]::WriteAllBytes($planWavesFixture, $planWavesOriginalBytes)
}

try {
  $migrationPlanWithoutFoundationSelector = $migrationPlanTemplateOriginal.Replace(
    '| Foundation Baseline ID |',
    '| Baseline Record |'
  ) + [Environment]::NewLine + 'Foundation Baseline ID is documented outside the unit and baseline tables.' + [Environment]::NewLine
  Assert-True ($migrationPlanWithoutFoundationSelector -ne $migrationPlanTemplateOriginal) 'Foundation baseline selector mutation must alter migration-plan template'
  [IO.File]::WriteAllText($migrationPlanTemplateFixture, $migrationPlanWithoutFoundationSelector, [Text.UTF8Encoding]::new($false))
  $templates = Invoke-Validator 'Templates'
  Assert-True ($templates.ExitCode -eq 1) "Foundation baseline selector outside migration-plan tables should fail. Output: $($templates.Output)"
  Assert-Contains $templates.Output "FAIL: Template migration-plan.md $orderedUnitsSection table missing column: Foundation Baseline ID" 'Unit foundation baseline selector field'
  Assert-Contains $templates.Output "FAIL: Template migration-plan.md $approvedBaselinesSection table missing column: Foundation Baseline ID" 'Approved foundation baseline record field'
}
finally {
  [IO.File]::WriteAllBytes($migrationPlanTemplateFixture, $migrationPlanTemplateOriginalBytes)
}

try {
  $migrationPlanWithoutFoundationApprovalReference = $migrationPlanTemplateOriginal.Replace(
    ' | Foundation Approval Reference |',
    ' |'
  )
  Assert-True ($migrationPlanWithoutFoundationApprovalReference -ne $migrationPlanTemplateOriginal) 'Foundation approval reference column mutation must alter migration-plan template'
  [IO.File]::WriteAllText($migrationPlanTemplateFixture, $migrationPlanWithoutFoundationApprovalReference, [Text.UTF8Encoding]::new($false))
  $templates = Invoke-Validator 'Templates'
  Assert-True ($templates.ExitCode -eq 1) "Migration plan without Foundation Approval Reference should fail. Output: $($templates.Output)"
  Assert-Contains $templates.Output "FAIL: Template migration-plan.md $orderedUnitsSection table missing column: Foundation Approval Reference" 'Later-greenfield foundation approval field'
}
finally {
  [IO.File]::WriteAllBytes($migrationPlanTemplateFixture, $migrationPlanTemplateOriginalBytes)
}

try {
  $foundationSelectorPhrase = ', `foundation_baseline_id` for a greenfield `not-required` unit'
  if ($codeMigrationOriginal.Contains($foundationSelectorPhrase)) {
    $foundationSelectorOutsideInputs = $codeMigrationOriginal.Replace($foundationSelectorPhrase, '')
  }
  else {
    $foundationSelectorOutsideInputs = $codeMigrationOriginal
  }
  $foundationSelectorOutsideInputs += [Environment]::NewLine + 'The orchestrator may provide `foundation_baseline_id` outside Inputs.' + [Environment]::NewLine
  Assert-True ($foundationSelectorOutsideInputs -ne $codeMigrationOriginal) 'Foundation selector locality mutation must alter code-migration'
  [IO.File]::WriteAllText($codeMigrationFixture, $foundationSelectorOutsideInputs, [Text.UTF8Encoding]::new($false))
  $skills = Invoke-Validator 'Skills'
  Assert-True ($skills.ExitCode -eq 1) "Greenfield foundation selector outside Inputs should fail. Output: $($skills.Output)"
  Assert-Contains $skills.Output 'FAIL: Skill code-migration/SKILL.md Inputs missing: `foundation_baseline_id`' 'Foundation selector input locality'
}
finally {
  [IO.File]::WriteAllBytes($codeMigrationFixture, $codeMigrationOriginalBytes)
}

try {
  $implementationFoundationSelector = 'Preserve the exact resolved selector as `foundation_baseline_id`'
  $implementationLosesFoundationSelector = $codeMigrationOriginal.Replace(
    $implementationFoundationSelector,
    'Preserve the selected migration unit only'
  )
  Assert-True ($implementationLosesFoundationSelector -ne $codeMigrationOriginal) 'Implementation foundation selector mutation must alter code-migration'
  [IO.File]::WriteAllText($codeMigrationFixture, $implementationLosesFoundationSelector, [Text.UTF8Encoding]::new($false))
  $skills = Invoke-Validator 'Skills'
  Assert-True ($skills.ExitCode -eq 1) "Implementation output that loses foundation_baseline_id should fail. Output: $($skills.Output)"
  Assert-Contains $skills.Output 'FAIL: Skill code-migration/SKILL.md output missing: `foundation_baseline_id`' 'Implementation foundation selector preservation'
}
finally {
  [IO.File]::WriteAllBytes($codeMigrationFixture, $codeMigrationOriginalBytes)
}

$knowledgeSkillFixture = Join-Path $PSScriptRoot '../skills/shared/knowledge-base/SKILL.md'
$knowledgeSkillOriginalBytes = [IO.File]::ReadAllBytes($knowledgeSkillFixture)
$knowledgeSkillOriginal = [Text.Encoding]::UTF8.GetString($knowledgeSkillOriginalBytes)
try {
  $knowledgeProposalSelector = '`foundation_baseline_id`'
  $knowledgeProposalLosesFoundationSelector = $knowledgeSkillOriginal.Replace(
    $knowledgeProposalSelector,
    '`foundation_record`'
  )
  Assert-True ($knowledgeProposalLosesFoundationSelector -ne $knowledgeSkillOriginal) 'Knowledge proposal foundation selector mutation must alter knowledge-base'
  [IO.File]::WriteAllText($knowledgeSkillFixture, $knowledgeProposalLosesFoundationSelector, [Text.UTF8Encoding]::new($false))
  $orchestrators = Invoke-Validator 'Orchestrators'
  Assert-True ($orchestrators.ExitCode -eq 1) "Knowledge proposal that loses foundation_baseline_id should fail. Output: $($orchestrators.Output)"
  Assert-Contains $orchestrators.Output 'FAIL: Knowledge Capture migration foundation contract missing: `foundation_baseline_id`' 'Knowledge foundation selector preservation'
}
finally {
  [IO.File]::WriteAllBytes($knowledgeSkillFixture, $knowledgeSkillOriginalBytes)
}

try {
  $knowledgeCompleteSource = if ($knowledgeSkillOriginal.Contains('`Completion Verdict: complete`')) {
    '`Completion Verdict: complete`'
  }
  else {
    'makes Completion Verdict `blocked`'
  }
  $knowledgeAcceptsPartialMigration = $knowledgeSkillOriginal.Replace(
    $knowledgeCompleteSource,
    '`Completion Verdict: partial`'
  )
  Assert-True ($knowledgeAcceptsPartialMigration -ne $knowledgeSkillOriginal) 'Partial migration completion mutation must alter knowledge-base'
  [IO.File]::WriteAllText($knowledgeSkillFixture, $knowledgeAcceptsPartialMigration, [Text.UTF8Encoding]::new($false))
  $orchestrators = Invoke-Validator 'Orchestrators'
  Assert-True ($orchestrators.ExitCode -eq 1) "Knowledge Capture accepting a partial migration run as complete should fail. Output: $($orchestrators.Output)"
  Assert-Contains $orchestrators.Output 'FAIL: Knowledge Capture workflow-aware terminal verdict missing: `Completion Verdict: complete`' 'Knowledge Capture migration complete-only verdict'
}
finally {
  [IO.File]::WriteAllBytes($knowledgeSkillFixture, $knowledgeSkillOriginalBytes)
}

try {
  $notRequiredBranch = 'For selected greenfield `Bootstrap Scope = not-required`, skip step 09 and pass the approved migration plan plus `foundation_baseline_id` to step 10.'
  if ($orchestratorOriginal.Contains($notRequiredBranch)) {
    $alwaysBootstrapGreenfield = $orchestratorOriginal.Replace(
      $notRequiredBranch,
      'For every selected greenfield unit, run step 09 before step 10 regardless of Bootstrap Scope.'
    )
  }
  else {
    $alwaysBootstrapGreenfield = $orchestratorOriginal.Replace(
      'Cap hop le `greenfield` / `design-new`',
      'Cap hop le `greenfield` / `design-new` regardless of Bootstrap Scope'
    )
    if ($alwaysBootstrapGreenfield -eq $orchestratorOriginal) {
      $alwaysBootstrapGreenfield = $orchestratorOriginal + [Environment]::NewLine + 'For every selected greenfield unit, run step 09 before step 10 regardless of Bootstrap Scope.' + [Environment]::NewLine
    }
  }
  Assert-True ($alwaysBootstrapGreenfield -ne $orchestratorOriginal) 'Always-bootstrap greenfield mutation must alter orchestrator'
  [IO.File]::WriteAllText($orchestratorFixture, $alwaysBootstrapGreenfield, [Text.UTF8Encoding]::new($false))
  $orchestrators = Invoke-Validator 'Orchestrators'
  Assert-True ($orchestrators.ExitCode -eq 1) "Greenfield not-required unit routed through bootstrap should fail. Output: $($orchestrators.Output)"
  Assert-Contains $orchestrators.Output 'FAIL: Migration orchestrator mode policy missing: pass the approved migration plan plus `foundation_baseline_id` to step 10' 'Greenfield later-unit route'
}
finally {
  [IO.File]::WriteAllBytes($orchestratorFixture, $orchestratorOriginalBytes)
}

try {
  $atomicBothRowsContract = '`Selected Migration Unit`' +
    [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('IHbDoCBgQuG6o24gZ2hpIGJhc2VsaW5lIG7hu4FuIHThuqNuZ2A='))
  $atomicRecordOnly = $orchestratorOriginal.Replace(
    $atomicBothRowsContract,
    "``$foundationRecordSection``"
  )
  Assert-True ($atomicRecordOnly -ne $orchestratorOriginal) 'Step-09 atomic handoff mutation must alter orchestrator'
  [IO.File]::WriteAllText($orchestratorFixture, $atomicRecordOnly, [Text.UTF8Encoding]::new($false))
  $orchestrators = Invoke-Validator 'Orchestrators'
  Assert-True ($orchestrators.ExitCode -eq 1) "Step-09 approval updating only the baseline record should fail. Output: $($orchestrators.Output)"
  Assert-Contains $orchestrators.Output "FAIL: Migration orchestrator bootstrap approval transition missing: $atomicBothRowsContract" 'Step-09 atomic handoff updates both rows'
}
finally {
  [IO.File]::WriteAllBytes($orchestratorFixture, $orchestratorOriginalBytes)
}

$mappingTemplateFixture = Join-Path $templateRoot 'mapping.md'
$mappingTemplateOriginalBytes = [IO.File]::ReadAllBytes($mappingTemplateFixture)
$mappingTemplateOriginal = [Text.Encoding]::UTF8.GetString($mappingTemplateOriginalBytes)
try {
  $mappingWithoutIds = $mappingTemplateOriginal.Replace(
    '| Mapping ID | Requirement IDs | Inventory IDs | Discovery IDs | Source References | Target References | Strategy | Rationale | Approval |',
    '| Requirement IDs | Discovery IDs | Source References | Target References | Strategy | Rationale | Approval |'
  ).Replace(
    '|---|---|---|---|---|---|---|---|---|',
    '|---|---|---|---|---|---|---|'
  ).Replace(
    '| <MAP-001> | <REQ-001> | <ITEM-001> | <DISC-001> | <source refs> | <target refs> | <strategy> | <rationale> | <owner/status> |',
    '| <REQ-001> | <DISC-001> | <source refs> | <target refs> | <strategy> | <rationale> | <owner/status> |'
  ) + [Environment]::NewLine + 'Mapping ID and Inventory IDs are described here, outside the table.' + [Environment]::NewLine
  [IO.File]::WriteAllText($mappingTemplateFixture, $mappingWithoutIds, [Text.UTF8Encoding]::new($false))
  $skills = Invoke-Validator 'Skills'
  Assert-True ($skills.ExitCode -eq 1) "Mapping template without stable mapping/inventory IDs should fail. Output: $($skills.Output)"
  Assert-Contains $skills.Output "FAIL: Front-half template mapping.md $mappingsSection table missing column: Mapping ID" 'Mapping stable ID contract'
  Assert-Contains $skills.Output "FAIL: Front-half template mapping.md $mappingsSection table missing column: Inventory IDs" 'Inventory trace contract'

  $mappingWithoutDiscoveryIds = $mappingTemplateOriginal.Replace(
    '| Mapping ID | Requirement IDs | Inventory IDs | Discovery IDs | Source References | Target References | Strategy | Rationale | Approval |',
    '| Mapping ID | Requirement IDs | Inventory IDs | Source References | Target References | Strategy | Rationale | Approval |'
  ).Replace(
    '|---|---|---|---|---|---|---|---|---|',
    '|---|---|---|---|---|---|---|---|'
  ).Replace(
    '| <MAP-001> | <REQ-001> | <ITEM-001> | <DISC-001> | <source refs> | <target refs> | <strategy> | <rationale> | <owner/status> |',
    '| <MAP-001> | <REQ-001> | <ITEM-001> | <source refs> | <target refs> | <strategy> | <rationale> | <owner/status> |'
  ) + [Environment]::NewLine + 'Discovery IDs are described here, outside the Mappings table.' + [Environment]::NewLine
  [IO.File]::WriteAllText($mappingTemplateFixture, $mappingWithoutDiscoveryIds, [Text.UTF8Encoding]::new($false))
  $skills = Invoke-Validator 'Skills'
  Assert-True ($skills.ExitCode -eq 1) "Mapping Discovery IDs outside the table should fail. Output: $($skills.Output)"
  Assert-Contains $skills.Output "FAIL: Front-half template mapping.md $mappingsSection table missing column: Discovery IDs" 'Mapping discovery trace contract'
}
finally {
  [IO.File]::WriteAllBytes($mappingTemplateFixture, $mappingTemplateOriginalBytes)
}

$gapsTemplateFixture = Join-Path $templateRoot 'gaps-conflicts.md'
$gapsTemplateOriginalBytes = [IO.File]::ReadAllBytes($gapsTemplateFixture)
$gapsTemplateOriginal = [Text.Encoding]::UTF8.GetString($gapsTemplateOriginalBytes)
try {
  $gapsWithoutDiscoveryIds = $gapsTemplateOriginal.Replace(
    '| ID | Requirement IDs | Inventory IDs | Mapping IDs | Discovery IDs | Evidence | Impact | Options | Owner | Decision |',
    '| ID | Requirement IDs | Inventory IDs | Mapping IDs | Evidence | Impact | Options | Owner | Decision |'
  ).Replace(
    '|---|---|---|---|---|---|---|---|---|---|',
    '|---|---|---|---|---|---|---|---|---|'
  ).Replace(
    '| <GAP-001> | <requirement IDs> | <inventory IDs> | <mapping IDs> | <discovery IDs> | <evidence> | <impact> | <options> | <owner> | <decision> |',
    '| <GAP-001> | <requirement IDs> | <inventory IDs> | <mapping IDs> | <evidence> | <impact> | <options> | <owner> | <decision> |'
  ) + [Environment]::NewLine + 'Discovery IDs are described here, outside the Gaps and Conflicts table.' + [Environment]::NewLine
  [IO.File]::WriteAllText($gapsTemplateFixture, $gapsWithoutDiscoveryIds, [Text.UTF8Encoding]::new($false))
  $skills = Invoke-Validator 'Skills'
  Assert-True ($skills.ExitCode -eq 1) "Gap/conflict Discovery IDs outside the table should fail. Output: $($skills.Output)"
  Assert-Contains $skills.Output "FAIL: Front-half template gaps-conflicts.md $gapsSection table missing column: Discovery IDs" 'Gap/conflict discovery trace contract'
}
finally {
  [IO.File]::WriteAllBytes($gapsTemplateFixture, $gapsTemplateOriginalBytes)
}

$exactSchemaMutationCoverage = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$requiredExactSchemaMutationStages = @('onboarding-input', 'mode-proposal', 'project-pack-review')

$onboardingCommandFixture = Join-Path $PSScriptRoot '../commands/migration-onboarding.md'
$onboardingCommandOriginalBytes = [IO.File]::ReadAllBytes($onboardingCommandFixture)
$onboardingCommandOriginal = [Text.Encoding]::UTF8.GetString($onboardingCommandOriginalBytes)
try {
  $projectRootArgument = $onboardingCommandOriginal.Replace(
    'argument-hint: "--legacy <path> --target <path> [--requirements <path> ...] [--uiux <path> ...] [--migration-docs <path> ...] [--architecture-docs <path> ...]"',
    'argument-hint: "[project-root] [legacy-path] [target-path] [docs-path...]"'
  )
  Assert-True ($projectRootArgument -ne $onboardingCommandOriginal) 'Project-root launcher mutation must alter onboarding command'
  [IO.File]::WriteAllText($onboardingCommandFixture, $projectRootArgument, [Text.UTF8Encoding]::new($false))
  $onboarding = Invoke-Validator 'Onboarding'
  Assert-True ($onboarding.ExitCode -eq 1) "Project root exposed as launcher argument should fail. Output: $($onboarding.Output)"
  Assert-Contains $onboarding.Output 'FAIL: Migration onboarding command argument-hint must expose the named legacy, target, and repeatable categorized document flags' 'Onboarding launcher argument contract'
}
finally {
  [IO.File]::WriteAllBytes($onboardingCommandFixture, $onboardingCommandOriginalBytes)
}

$onboardingOrchestratorFixture = Join-Path $PSScriptRoot '../skills/aitoolkit/migration-onboarding/SKILL.md'
$onboardingOrchestratorOriginalBytes = [IO.File]::ReadAllBytes($onboardingOrchestratorFixture)
$onboardingOrchestratorOriginal = [Text.Encoding]::UTF8.GetString($onboardingOrchestratorOriginalBytes)
try {
  $rootParsedFromArguments = $onboardingOrchestratorOriginal.Replace(
    'Derive `<project>` from the current target-project context; never parse project root from positional arguments.',
    'Parse project root as the first positional value in `$ARGUMENTS`.'
  )
  Assert-True ($rootParsedFromArguments -ne $onboardingOrchestratorOriginal) 'Project-root parser mutation must alter onboarding orchestrator'
  [IO.File]::WriteAllText($onboardingOrchestratorFixture, $rootParsedFromArguments, [Text.UTF8Encoding]::new($false))
  $onboarding = Invoke-Validator 'Onboarding'
  Assert-True ($onboarding.ExitCode -eq 1) "Orchestrator parsing project root from arguments should fail. Output: $($onboarding.Output)"
  Assert-Contains $onboarding.Output 'FAIL: Migration onboarding orchestrator arguments missing: never parse project root' 'Onboarding argument section locality'

  $nonRepeatableDocuments = $onboardingOrchestratorOriginal.Replace(
    'All four document flags are repeatable and accept a file or directory.',
    'Each document flag accepts one file only.'
  )
  Assert-True ($nonRepeatableDocuments -ne $onboardingOrchestratorOriginal) 'Repeatable document flag mutation must alter onboarding orchestrator'
  [IO.File]::WriteAllText($onboardingOrchestratorFixture, $nonRepeatableDocuments, [Text.UTF8Encoding]::new($false))
  $onboarding = Invoke-Validator 'Onboarding'
  Assert-True ($onboarding.ExitCode -eq 1) "Non-repeatable document flags should fail. Output: $($onboarding.Output)"
  Assert-Contains $onboarding.Output 'FAIL: Migration onboarding orchestrator arguments missing: repeatable' 'Onboarding repeatable document flags'

  $inboxBeforeExplicit = $onboardingOrchestratorOriginal.Replace('explicit flag paths', '__EXPLICIT_PATHS__').Replace(
    'matching inbox directory if present',
    'explicit flag paths'
  ).Replace('__EXPLICIT_PATHS__', 'matching inbox directory if present')
  Assert-True ($inboxBeforeExplicit -ne $onboardingOrchestratorOriginal) 'Inbox-priority mutation must alter onboarding orchestrator'
  [IO.File]::WriteAllText($onboardingOrchestratorFixture, $inboxBeforeExplicit, [Text.UTF8Encoding]::new($false))
  $onboarding = Invoke-Validator 'Onboarding'
  Assert-True ($onboarding.ExitCode -eq 1) "Inbox before explicit document paths should fail. Output: $($onboarding.Output)"
  Assert-Contains $onboarding.Output 'FAIL: Migration onboarding document resolver priority requires order: explicit flag paths before matching inbox directory if present' 'Onboarding explicit-before-inbox priority'

  $filteredInboxBeforeValidation = $onboardingOrchestratorOriginal.Replace(
    '2. **matching inbox directory if present** - append every regular file, without filtering by readability or format, from the optional category inbox under `<project>`:',
    "2. **matching inbox directory if present** - append only readable regular files before validation from the optional category inbox under ``<project>``:`r`n`r`nResolver vocabulary only: append every regular file; without filtering by readability or format."
  )
  Assert-True ($filteredInboxBeforeValidation -ne $onboardingOrchestratorOriginal) 'Inbox filter-before-validation mutation must alter onboarding orchestrator'
  [IO.File]::WriteAllText($onboardingOrchestratorFixture, $filteredInboxBeforeValidation, [Text.UTF8Encoding]::new($false))
  $onboarding = Invoke-Validator 'Onboarding'
  Assert-True ($onboarding.ExitCode -eq 1) "Filtering unreadable inbox children before validation should fail. Output: $($onboarding.Output)"
  Assert-Contains $onboarding.Output 'FAIL: Migration onboarding inbox collection must collect every regular file before readability/format validation' 'Onboarding collect-before-validate semantics'

  $reversedCanonicalDedupe = $onboardingOrchestratorOriginal.Replace(
    '3. **canonical-path merge/dedupe** - resolve stable absolute filesystem identity and keep the first occurrence. Because explicit records are first, a duplicate discovered in an inbox keeps `Input Source = explicit`.',
    "3. **canonical-path merge/dedupe** - resolve stable absolute filesystem identity and keep the last occurrence. An inbox duplicate replaces explicit authority with ``Input Source = inbox``.`r`n`r`nResolver vocabulary only: keep the first occurrence; explicit records are first; ``Input Source = explicit``."
  )
  Assert-True ($reversedCanonicalDedupe -ne $onboardingOrchestratorOriginal) 'Canonical-dedupe semantic mutation must alter onboarding orchestrator'
  [IO.File]::WriteAllText($onboardingOrchestratorFixture, $reversedCanonicalDedupe, [Text.UTF8Encoding]::new($false))
  $onboarding = Invoke-Validator 'Onboarding'
  Assert-True ($onboarding.ExitCode -eq 1) "Last-wins inbox-authority canonical dedupe should fail. Output: $($onboarding.Output)"
  Assert-Contains $onboarding.Output 'FAIL: Migration onboarding canonical dedupe must use stable absolute identity, first-wins, and explicit source authority' 'Onboarding canonical dedupe semantics'

  $missingPathSkipped = $onboardingOrchestratorOriginal.Replace(
    '| explicit path is missing or unreadable | block |',
    '| explicit path is missing or unreadable | continue |'
  )
  Assert-True ($missingPathSkipped -ne $onboardingOrchestratorOriginal) 'Missing-path failure mutation must alter onboarding orchestrator'
  [IO.File]::WriteAllText($onboardingOrchestratorFixture, $missingPathSkipped, [Text.UTF8Encoding]::new($false))
  $onboarding = Invoke-Validator 'Onboarding'
  Assert-True ($onboarding.ExitCode -eq 1) "Missing explicit document path silently skipped should fail. Output: $($onboarding.Output)"
  Assert-Contains $onboarding.Output 'FAIL: Migration onboarding document failure must block: explicit path is missing or unreadable' 'Onboarding missing path blocker'

  $unreadableInboxChildSkipped = $onboardingOrchestratorOriginal.Replace(
    '| discovered regular file is unreadable | block; never silently omit |',
    '| discovered regular file is unreadable | continue |'
  )
  Assert-True ($unreadableInboxChildSkipped -ne $onboardingOrchestratorOriginal) 'Unreadable inbox child mutation must alter onboarding orchestrator'
  [IO.File]::WriteAllText($onboardingOrchestratorFixture, $unreadableInboxChildSkipped, [Text.UTF8Encoding]::new($false))
  $onboarding = Invoke-Validator 'Onboarding'
  Assert-True ($onboarding.ExitCode -eq 1) "Unreadable discovered inbox child silently omitted should fail. Output: $($onboarding.Output)"
  Assert-Contains $onboarding.Output 'FAIL: Migration onboarding document failure must block; never silently omit: discovered regular file is unreadable' 'Onboarding unreadable inbox child blocker'

  $unreadableFormatSkipped = $onboardingOrchestratorOriginal.Replace(
    '| document format cannot be opened or decoded | block; never silently skip |',
    '| document format cannot be opened or decoded | continue |'
  )
  Assert-True ($unreadableFormatSkipped -ne $onboardingOrchestratorOriginal) 'Unreadable-format failure mutation must alter onboarding orchestrator'
  [IO.File]::WriteAllText($onboardingOrchestratorFixture, $unreadableFormatSkipped, [Text.UTF8Encoding]::new($false))
  $onboarding = Invoke-Validator 'Onboarding'
  Assert-True ($onboarding.ExitCode -eq 1) "Unreadable document format silently skipped should fail. Output: $($onboarding.Output)"
  Assert-Contains $onboarding.Output 'FAIL: Migration onboarding document failure must block; never silently skip: document format cannot be opened or decoded' 'Onboarding unreadable format blocker'

  $blockedAfterDownstream = [regex]::Replace(
    $onboardingOrchestratorOriginal,
    '(?m)^5\. Artifact .*?`result: blocked`.*$',
    '5. Open normal approval gate and downstream execution before handling `result: blocked`.'
  ) + [Environment]::NewLine + '`result: blocked` stops before normal approval gate and downstream execution.' + [Environment]::NewLine
  [IO.File]::WriteAllText($onboardingOrchestratorFixture, $blockedAfterDownstream, [Text.UTF8Encoding]::new($false))
  $onboarding = Invoke-Validator 'Onboarding'
  Assert-True ($onboarding.ExitCode -eq 1) "Blocked handling after gate/downstream should fail. Output: $($onboarding.Output)"
  Assert-Contains $onboarding.Output 'FAIL: Migration onboarding blocked handling requires order: result: blocked before normal approval gate' 'Onboarding blocked-before-gate order'
  Assert-Contains $onboarding.Output 'FAIL: Migration onboarding blocked handling requires order: result: blocked before downstream execution' 'Onboarding blocked-before-downstream order'

  $publishBeforeApproval = $onboardingOrchestratorOriginal.Replace(
    'explicit approval',
    'review decision'
  ).Replace(
    'Before approval, step 04',
    'Before approval, publish the canonical marker is forbidden; only later explicit approval allows step 04'
  )
  [IO.File]::WriteAllText($onboardingOrchestratorFixture, $publishBeforeApproval, [Text.UTF8Encoding]::new($false))
  $onboarding = Invoke-Validator 'Onboarding'
  Assert-True ($onboarding.ExitCode -eq 1) "Canonical publication before HARD approval should fail. Output: $($onboarding.Output)"
  Assert-Contains $onboarding.Output 'FAIL: Migration onboarding staged publication requires order: explicit approval before publish the canonical' 'Onboarding publish-after-HARD order'
}
finally {
  [IO.File]::WriteAllBytes($onboardingOrchestratorFixture, $onboardingOrchestratorOriginalBytes)
}

$onboardingInputFixture = Join-Path $templateRoot 'onboarding-input.md'
$onboardingInputOriginalBytes = [IO.File]::ReadAllBytes($onboardingInputFixture)
$onboardingInputOriginal = [Text.Encoding]::UTF8.GetString($onboardingInputOriginalBytes)
try {
  $step01WithoutSource = $onboardingInputOriginal.Replace(
    '| Category | Canonical Path | Input Source | Format | Readability | Evidence ID |',
    '| Category | Canonical Path | Format | Readability | Evidence ID |'
  )
  Assert-True ($step01WithoutSource -ne $onboardingInputOriginal) 'Step-01 document-record mutation must alter onboarding input template'
  [IO.File]::WriteAllText($onboardingInputFixture, $step01WithoutSource, [Text.UTF8Encoding]::new($false))
  $onboarding = Invoke-Validator 'Onboarding'
  Assert-True ($onboarding.ExitCode -eq 1) "Step-01 document records without source authority should fail. Output: $($onboarding.Output)"
  Assert-Contains $onboarding.Output "FAIL: Onboarding input template $documentRecordsSection table missing column: Input Source" 'Onboarding source-to-sink step01 schema'

  $step01ReorderedSchema = $onboardingInputOriginal.Replace(
    '| Category | Canonical Path | Input Source | Format | Readability | Evidence ID |',
    '| Canonical Path | Category | Input Source | Format | Readability | Evidence ID |'
  ).Replace(
    '| <requirements / uiux / migration / architecture> | <stable absolute path> | <explicit / inbox> | <detected format> | <readable> | <DOC-...> |',
    '| <stable absolute path> | <requirements / uiux / migration / architecture> | <explicit / inbox> | <detected format> | <readable> | <DOC-...> |'
  )
  Assert-True ($step01ReorderedSchema -ne $onboardingInputOriginal) 'Step-01 exact-schema reorder mutation must alter onboarding input template'
  [IO.File]::WriteAllText($onboardingInputFixture, $step01ReorderedSchema, [Text.UTF8Encoding]::new($false))
  $onboarding = Invoke-Validator 'Onboarding'
  Assert-True ($onboarding.ExitCode -eq 1) "Step-01 document records with all names reordered should fail. Output: $($onboarding.Output)"
  Assert-Contains $onboarding.Output "FAIL: Onboarding input template $documentRecordsSection table columns must be exactly: Category | Canonical Path | Input Source | Format | Readability | Evidence ID" 'Onboarding step01 exact schema order'
  $null = $exactSchemaMutationCoverage.Add('onboarding-input')
}
finally {
  [IO.File]::WriteAllBytes($onboardingInputFixture, $onboardingInputOriginalBytes)
}

$inspectionTemplateFixture = Join-Path $templateRoot 'project-inspection.md'
$inspectionTemplateOriginalBytes = [IO.File]::ReadAllBytes($inspectionTemplateFixture)
$inspectionTemplateOriginal = [Text.Encoding]::UTF8.GetString($inspectionTemplateOriginalBytes)
try {
  $inspectionWithoutFormat = $inspectionTemplateOriginal.Replace(
    '| Category | Canonical Path | Input Source | Format | Readability | Evidence ID |',
    '| Category | Canonical Path | Input Source | Readability | Evidence ID |'
  )
  Assert-True ($inspectionWithoutFormat -ne $inspectionTemplateOriginal) 'Step-02 document-record mutation must alter project inspection template'
  [IO.File]::WriteAllText($inspectionTemplateFixture, $inspectionWithoutFormat, [Text.UTF8Encoding]::new($false))
  $onboarding = Invoke-Validator 'Onboarding'
  Assert-True ($onboarding.ExitCode -eq 1) "Step-02 document records without format should fail. Output: $($onboarding.Output)"
  Assert-Contains $onboarding.Output "FAIL: Onboarding project inspection template $documentRecordsSection table missing column: Format" 'Onboarding source-to-sink step02 schema'
}
finally {
  [IO.File]::WriteAllBytes($inspectionTemplateFixture, $inspectionTemplateOriginalBytes)
}

$inspectProjectFixture = Join-Path $PSScriptRoot '../skills/migration-onboarding/inspect-project/SKILL.md'
$inspectProjectOriginalBytes = [IO.File]::ReadAllBytes($inspectProjectFixture)
$inspectProjectOriginal = [Text.Encoding]::UTF8.GetString($inspectProjectOriginalBytes)
try {
  $sourceMutationAllowed = $inspectProjectOriginal.Replace(
    'must not move, rename, rewrite, or modify any source document or any file under legacy/target roots',
    'may normalize source documents in place when convenient'
  )
  Assert-True ($sourceMutationAllowed -ne $inspectProjectOriginal) 'Read-only source mutation must alter inspect-project skill'
  [IO.File]::WriteAllText($inspectProjectFixture, $sourceMutationAllowed, [Text.UTF8Encoding]::new($false))
  $onboarding = Invoke-Validator 'Onboarding'
  Assert-True ($onboarding.ExitCode -eq 1) "Allowing source document mutation should fail. Output: $($onboarding.Output)"
  Assert-Contains $onboarding.Output 'FAIL: Onboarding skill inspect-project output missing: must not move, rename, rewrite, or modify' 'Onboarding source immutability'
}
finally {
  [IO.File]::WriteAllBytes($inspectProjectFixture, $inspectProjectOriginalBytes)
}

$createPackFixture = Join-Path $PSScriptRoot '../skills/migration-onboarding/create-project-pack/SKILL.md'
$createPackOriginalBytes = [IO.File]::ReadAllBytes($createPackFixture)
$createPackOriginal = [Text.Encoding]::UTF8.GetString($createPackOriginalBytes)
try {
  $staleInspectionRead = $createPackOriginal.Replace(
    '## Inputs',
    "## Inputs`r`n`r`n- Also read ``<RUN_DIR>/02-project-inspection.md`` directly."
  ) + [Environment]::NewLine + 'Immediate predecessor artifact = exactly one orchestrator-provided path' + [Environment]::NewLine
  [IO.File]::WriteAllText($createPackFixture, $staleInspectionRead, [Text.UTF8Encoding]::new($false))
  $onboarding = Invoke-Validator 'Onboarding'
  Assert-True ($onboarding.ExitCode -eq 1) "Create-pack direct step02 read should fail. Output: $($onboarding.Output)"
  Assert-Contains $onboarding.Output 'FAIL: Onboarding skill create-project-pack Inputs reads a non-predecessor numbered artifact' 'Onboarding immediate predecessor contract'
}
finally {
  [IO.File]::WriteAllBytes($createPackFixture, $createPackOriginalBytes)
}

$createPackDefaultMutations = @(
  [pscustomobject]@{
    Name = 'automation default'; From = '`automation.mode: interactive`'; To = '`automation.mode: auto`'
    Expected = 'FAIL: Onboarding skill create-project-pack output missing: `automation.mode: interactive`'
  }
  [pscustomobject]@{
    Name = 'artifact language default'; From = '`output.artifact_language: vi`'; To = '`output.artifact_language: en`'
    Expected = 'FAIL: Onboarding skill create-project-pack output missing: `output.artifact_language: vi`'
  }
  [pscustomobject]@{
    Name = 'source-document immutability'; From = 'must not modify source documents'; To = 'may rewrite source documents'
    Expected = 'FAIL: Onboarding skill create-project-pack output missing: must not modify source documents'
  }
)
foreach ($mutation in $createPackDefaultMutations) {
  try {
    $mutatedCreatePack = $createPackOriginal.Replace($mutation.From, $mutation.To)
    Assert-True ($mutatedCreatePack -ne $createPackOriginal) "Create-pack mutation must alter real skill: $($mutation.Name)"
    [IO.File]::WriteAllText($createPackFixture, $mutatedCreatePack, [Text.UTF8Encoding]::new($false))
    $onboarding = Invoke-Validator 'Onboarding'
    Assert-True ($onboarding.ExitCode -eq 1) "Create-pack with wrong $($mutation.Name) should fail. Output: $($onboarding.Output)"
    Assert-Contains $onboarding.Output $mutation.Expected "Create-pack contract: $($mutation.Name)"
  }
  finally {
    [IO.File]::WriteAllBytes($createPackFixture, $createPackOriginalBytes)
  }
}

$classifyModeFixture = Join-Path $PSScriptRoot '../skills/migration-onboarding/classify-mode/SKILL.md'
$classifyModeOriginalBytes = [IO.File]::ReadAllBytes($classifyModeFixture)
$classifyModeOriginal = [Text.Encoding]::UTF8.GetString($classifyModeOriginalBytes)
try {
  $placeholderGuessed = $classifyModeOriginal.Replace('`mode: unknown`', '`greenfield`').Replace('`result: blocked`', '`result: complete`')
  [IO.File]::WriteAllText($classifyModeFixture, $placeholderGuessed, [Text.UTF8Encoding]::new($false))
  $onboarding = Invoke-Validator 'Onboarding'
  Assert-True ($onboarding.ExitCode -eq 1) "Placeholder target guessed greenfield should fail. Output: $($onboarding.Output)"
  Assert-Contains $onboarding.Output 'FAIL: Onboarding classification table must keep placeholder-only target unknown/blocked' 'Placeholder pressure policy'

  $stableNotIncremental = $classifyModeOriginal.Replace('`incremental`', '`greenfield`').Replace('`preserve-existing`', '`design-new`')
  [IO.File]::WriteAllText($classifyModeFixture, $stableNotIncremental, [Text.UTF8Encoding]::new($false))
  $onboarding = Invoke-Validator 'Onboarding'
  Assert-True ($onboarding.ExitCode -eq 1) "Stable target not incremental should fail. Output: $($onboarding.Output)"
  Assert-Contains $onboarding.Output 'FAIL: Onboarding classification table must propose incremental/preserve-existing for stable target' 'Stable-target pressure policy'

  $ambiguousCommandsGuessed = $classifyModeOriginal.Replace('| `null` | `unknown` |', '| guessed | self-selected |')
  [IO.File]::WriteAllText($classifyModeFixture, $ambiguousCommandsGuessed, [Text.UTF8Encoding]::new($false))
  $onboarding = Invoke-Validator 'Onboarding'
  Assert-True ($onboarding.ExitCode -eq 1) "Ambiguous commands guessed should fail. Output: $($onboarding.Output)"
  Assert-Contains $onboarding.Output 'FAIL: Onboarding classification table must keep ambiguous toolchain commands null/blocked' 'Ambiguous-toolchain pressure policy'
}
finally {
  [IO.File]::WriteAllBytes($classifyModeFixture, $classifyModeOriginalBytes)
}

$modeProposalFixture = Join-Path $templateRoot 'mode-proposal.md'
$modeProposalOriginalBytes = [IO.File]::ReadAllBytes($modeProposalFixture)
$modeProposalOriginal = [Text.Encoding]::UTF8.GetString($modeProposalOriginalBytes)
try {
  $modeWithoutUnknown = $modeProposalOriginal.Replace('greenfield / incremental / unknown', 'greenfield / incremental')
  [IO.File]::WriteAllText($modeProposalFixture, $modeWithoutUnknown, [Text.UTF8Encoding]::new($false))
  $onboarding = Invoke-Validator 'Onboarding'
  Assert-True ($onboarding.ExitCode -eq 1) "Mode proposal without unknown should fail. Output: $($onboarding.Output)"
  Assert-Contains $onboarding.Output 'FAIL: Onboarding mode proposal template must express greenfield, incremental, and unknown' 'Mode proposal unknown enum'

  $commandsWithoutAuthority = $modeProposalOriginal.Replace(' | Authority |', ' |')
  [IO.File]::WriteAllText($modeProposalFixture, $commandsWithoutAuthority, [Text.UTF8Encoding]::new($false))
  $onboarding = Invoke-Validator 'Onboarding'
  Assert-True ($onboarding.ExitCode -eq 1) "Command resolution without authority should fail. Output: $($onboarding.Output)"
  Assert-Contains $onboarding.Output "FAIL: Onboarding mode proposal template $commandResolutionSection table missing column: Authority" 'Command authority field'

  $handoffWithoutReferences = $modeProposalOriginal.Replace(' | Evidence References |', ' |')
  [IO.File]::WriteAllText($modeProposalFixture, $handoffWithoutReferences, [Text.UTF8Encoding]::new($false))
  $onboarding = Invoke-Validator 'Onboarding'
  Assert-True ($onboarding.ExitCode -eq 1) "Inspection handoff without references should fail. Output: $($onboarding.Output)"
  Assert-Contains $onboarding.Output "FAIL: Onboarding mode proposal template $inspectionHandoffSection table missing column: Evidence References" 'Inspection evidence handoff field'

  $documentHandoffWithoutSource = $modeProposalOriginal.Replace(' | Input Source |', ' |')
  Assert-True ($documentHandoffWithoutSource -ne $modeProposalOriginal) 'Document handoff source mutation must alter mode proposal template'
  [IO.File]::WriteAllText($modeProposalFixture, $documentHandoffWithoutSource, [Text.UTF8Encoding]::new($false))
  $onboarding = Invoke-Validator 'Onboarding'
  Assert-True ($onboarding.ExitCode -eq 1) "Step03 document handoff without source authority should fail. Output: $($onboarding.Output)"
  Assert-Contains $onboarding.Output "FAIL: Onboarding mode proposal template $documentHandoffSection table missing column: Input Source" 'Step03 document source authority handoff'

  $modeHandoffWithExtraField = $modeProposalOriginal.Replace(
    '| Category | Canonical Path | Input Source | Format | Readability | Evidence ID |',
    '| Category | Canonical Path | Input Source | Format | Readability | Evidence ID | Review Hint |'
  ).Replace(
    '| <requirements / uiux / migration / architecture> | <approved stable absolute path> | <explicit / inbox> | <detected format> | <readable> | <DOC-...> |',
    '| <requirements / uiux / migration / architecture> | <approved stable absolute path> | <explicit / inbox> | <detected format> | <readable> | <DOC-...> | <none> |'
  )
  Assert-True ($modeHandoffWithExtraField -ne $modeProposalOriginal) 'Step-03 exact-schema extra-field mutation must alter mode proposal template'
  [IO.File]::WriteAllText($modeProposalFixture, $modeHandoffWithExtraField, [Text.UTF8Encoding]::new($false))
  $onboarding = Invoke-Validator 'Onboarding'
  Assert-True ($onboarding.ExitCode -eq 1) "Step03 document handoff with all names plus an extra field should fail. Output: $($onboarding.Output)"
  Assert-Contains $onboarding.Output "FAIL: Onboarding mode proposal template $documentHandoffSection table columns must be exactly: Category | Canonical Path | Input Source | Format | Readability | Evidence ID" 'Onboarding step03 exact schema no-extra rule'
  $null = $exactSchemaMutationCoverage.Add('mode-proposal')
}
finally {
  [IO.File]::WriteAllBytes($modeProposalFixture, $modeProposalOriginalBytes)
}

$packReviewFixture = Join-Path $templateRoot 'project-pack-review.md'
$packReviewOriginalBytes = [IO.File]::ReadAllBytes($packReviewFixture)
$packReviewOriginal = [Text.Encoding]::UTF8.GetString($packReviewOriginalBytes)
try {
  $profileDocumentsWithoutSource = $packReviewOriginal.Replace(' | Input Source |', ' |')
  Assert-True ($profileDocumentsWithoutSource -ne $packReviewOriginal) 'Profile document source mutation must alter pack review template'
  [IO.File]::WriteAllText($packReviewFixture, $profileDocumentsWithoutSource, [Text.UTF8Encoding]::new($false))
  $onboarding = Invoke-Validator 'Onboarding'
  Assert-True ($onboarding.ExitCode -eq 1) "Generated profile review without source authority should fail. Output: $($onboarding.Output)"
  Assert-Contains $onboarding.Output "FAIL: Onboarding project pack review template $profileDocumentSection table missing column: Input Source" 'Generated profile document source authority'

  $reviewReorderedSchema = $packReviewOriginal.Replace(
    '| Category | Canonical Path | Input Source | Format | Readability | Evidence ID |',
    '| Evidence ID | Category | Canonical Path | Input Source | Format | Readability |'
  ).Replace(
    '| <requirements / uiux / migration / architecture> | <profile document path> | <explicit / inbox> | <detected format> | <readable> | <DOC-...> |',
    '| <DOC-...> | <requirements / uiux / migration / architecture> | <profile document path> | <explicit / inbox> | <detected format> | <readable> |'
  )
  Assert-True ($reviewReorderedSchema -ne $packReviewOriginal) 'Step-04 exact-schema reorder mutation must alter pack review template'
  [IO.File]::WriteAllText($packReviewFixture, $reviewReorderedSchema, [Text.UTF8Encoding]::new($false))
  $onboarding = Invoke-Validator 'Onboarding'
  Assert-True ($onboarding.ExitCode -eq 1) "Profile document evidence with all names reordered should fail. Output: $($onboarding.Output)"
  Assert-Contains $onboarding.Output "FAIL: Onboarding project pack review template $profileDocumentSection table columns must be exactly: Category | Canonical Path | Input Source | Format | Readability | Evidence ID" 'Onboarding step04 exact schema order'
  $null = $exactSchemaMutationCoverage.Add('project-pack-review')
}
finally {
  [IO.File]::WriteAllBytes($packReviewFixture, $packReviewOriginalBytes)
}

foreach ($requiredExactSchemaMutationStage in $requiredExactSchemaMutationStages) {
  Assert-True `
    ($exactSchemaMutationCoverage.Contains($requiredExactSchemaMutationStage)) `
    "Exact-schema mutation coverage missing stage: $requiredExactSchemaMutationStage"
}

$compatibilityIndexFixture = Join-Path $PSScriptRoot '../examples/project-packs/webos-qml-flutter/SKILL.md'
$compatibilityIndexOriginalBytes = [IO.File]::ReadAllBytes($compatibilityIndexFixture)
$compatibilityIndexOriginal = [Text.Encoding]::UTF8.GetString($compatibilityIndexOriginalBytes)
try {
  $legacyRoute = '| Legacy taxonomy, runtime behavior, platform integration | [legacy-system.md](references/legacy-system.md) |'
  $dummyRoute = '| Legacy taxonomy, runtime behavior, platform integration | [dummy.md](references/dummy.md) |'
  $movedRoute = $compatibilityIndexOriginal.Replace($legacyRoute, $dummyRoute) +
    [Environment]::NewLine + '- Moved link: references/legacy-system.md' + [Environment]::NewLine
  [IO.File]::WriteAllText($compatibilityIndexFixture, $movedRoute, [Text.UTF8Encoding]::new($false))
  $compatibility = Invoke-Validator 'Compatibility'
  Assert-True ($compatibility.ExitCode -eq 1) "Moved route plus dummy table row should fail. Output: $($compatibility.Output)"
  Assert-Contains $compatibility.Output 'FAIL: Compatibility pack index Reference routing must contain references/legacy-system.md exactly once; found 0' 'Compatibility parsed route target'
  Assert-Contains $compatibility.Output 'FAIL: Compatibility pack index Reference routing contains unexpected path: references/dummy.md' 'Compatibility unexpected route target'
}
finally {
  [IO.File]::WriteAllBytes($compatibilityIndexFixture, $compatibilityIndexOriginalBytes)
}

try {
  $requiredRoute = '[legacy-system.md](references/legacy-system.md)'
  $requiredWithExternal = $compatibilityIndexOriginal.Replace(
    $requiredRoute,
    "$requiredRoute [external](https://example.invalid/rules.md)"
  )
  [IO.File]::WriteAllText($compatibilityIndexFixture, $requiredWithExternal, [Text.UTF8Encoding]::new($false))
  $compatibility = Invoke-Validator 'Compatibility'
  Assert-True ($compatibility.ExitCode -eq 1) "Required route plus external target in one cell should fail. Output: $($compatibility.Output)"
  Assert-Contains $compatibility.Output 'FAIL: Compatibility pack index Reference routing row must contain exactly one Markdown link target; found 2' 'Compatibility external extra route target'
}
finally {
  [IO.File]::WriteAllBytes($compatibilityIndexFixture, $compatibilityIndexOriginalBytes)
}

try {
  $requiredRoute = '[legacy-system.md](references/legacy-system.md)'
  $requiredWithAutolink = $compatibilityIndexOriginal.Replace(
    $requiredRoute,
    "$requiredRoute <https://example.invalid/rules.md>"
  )
  [IO.File]::WriteAllText($compatibilityIndexFixture, $requiredWithAutolink, [Text.UTF8Encoding]::new($false))
  $compatibility = Invoke-Validator 'Compatibility'
  Assert-True ($compatibility.ExitCode -eq 1) "Required route plus external autolink in one cell should fail. Output: $($compatibility.Output)"
  Assert-Contains $compatibility.Output 'FAIL: Compatibility pack index Reference routing row must contain exactly one Markdown link target; found 2' 'Compatibility external autolink target'
}
finally {
  [IO.File]::WriteAllBytes($compatibilityIndexFixture, $compatibilityIndexOriginalBytes)
}

try {
  $requiredRoute = '[legacy-system.md](references/legacy-system.md)'
  $requiredWithShortcut = $compatibilityIndexOriginal.Replace(
    $requiredRoute,
    "$requiredRoute [external]"
  ) + [Environment]::NewLine + '[external]: https://example.invalid/rules.md' + [Environment]::NewLine
  [IO.File]::WriteAllText($compatibilityIndexFixture, $requiredWithShortcut, [Text.UTF8Encoding]::new($false))
  $compatibility = Invoke-Validator 'Compatibility'
  Assert-True ($compatibility.ExitCode -eq 1) "Required route plus shortcut reference link should fail. Output: $($compatibility.Output)"
  Assert-Contains $compatibility.Output 'FAIL: Compatibility pack index Reference routing does not allow shortcut reference links' 'Compatibility shortcut reference target'
}
finally {
  [IO.File]::WriteAllBytes($compatibilityIndexFixture, $compatibilityIndexOriginalBytes)
}

try {
  $nonmatchingLocal = $compatibilityIndexOriginal.Replace(
    '[legacy-system.md](references/legacy-system.md)',
    '[legacy-system.md](../legacy-system.md)'
  )
  [IO.File]::WriteAllText($compatibilityIndexFixture, $nonmatchingLocal, [Text.UTF8Encoding]::new($false))
  $compatibility = Invoke-Validator 'Compatibility'
  Assert-True ($compatibility.ExitCode -eq 1) "Nonmatching local route target should fail. Output: $($compatibility.Output)"
  Assert-Contains $compatibility.Output 'FAIL: Compatibility pack index Reference routing must contain references/legacy-system.md exactly once; found 0' 'Compatibility missing route after local path substitution'
  Assert-Contains $compatibility.Output 'FAIL: Compatibility pack index Reference routing contains unexpected path: ../legacy-system.md' 'Compatibility nonmatching local route target'
}
finally {
  [IO.File]::WriteAllBytes($compatibilityIndexFixture, $compatibilityIndexOriginalBytes)
}

$sharedCompatibilityMutations = @(
  [pscustomobject]@{
    Name = 'ai-review'
    RequiredPhrase = 'For feature/bugfix without an explicit mandatory rule declaration'
    Expected = 'FAIL: Shared skill ai-review feature/bugfix compatibility missing: For feature/bugfix without an explicit mandatory rule declaration'
  }
  [pscustomobject]@{
    Name = 'gerrit-automation'
    RequiredPhrase = 'For feature/bugfix without an explicit mandatory rule declaration'
    Expected = 'FAIL: Shared skill gerrit-automation feature/bugfix compatibility missing: For feature/bugfix without an explicit mandatory rule declaration'
  }
  [pscustomobject]@{
    Name = 'ccc-automation'
    RequiredPhrase = 'For feature/bugfix without an explicit mandatory rule declaration'
    Expected = 'FAIL: Shared skill ccc-automation feature/bugfix compatibility missing: For feature/bugfix without an explicit mandatory rule declaration'
  }
)
foreach ($mutation in $sharedCompatibilityMutations) {
  $sharedFixture = Join-Path $PSScriptRoot "../skills/shared/$($mutation.Name)/SKILL.md"
  $sharedOriginalBytes = [IO.File]::ReadAllBytes($sharedFixture)
  $sharedOriginal = [Text.Encoding]::UTF8.GetString($sharedOriginalBytes)
  try {
    if ($sharedOriginal.Contains($mutation.RequiredPhrase)) {
      $nonMigrationPackRequired = $sharedOriginal.Replace(
        $mutation.RequiredPhrase,
        'For every workflow, including feature/bugfix, profile and project pack are mandatory and missing inputs BLOCK'
      )
    }
    else {
      $badCompatibilityRule = '5. For feature/bugfix, profile and project pack are mandatory; missing inputs set `Rule Resolution: BLOCKED`.'
      $nonMigrationPackRequired = [regex]::Replace(
        $sharedOriginal,
        '(?m)^## ',
        $badCompatibilityRule + [Environment]::NewLine + [Environment]::NewLine + '## ',
        1,
        [TimeSpan]::FromSeconds(1)
      )
      if ($nonMigrationPackRequired -eq $sharedOriginal) {
        $nonMigrationPackRequired = $sharedOriginal + [Environment]::NewLine + $badCompatibilityRule + [Environment]::NewLine
      }
    }
    Assert-True ($nonMigrationPackRequired -ne $sharedOriginal) "Feature/bugfix compatibility mutation must alter $($mutation.Name)"
    [IO.File]::WriteAllText($sharedFixture, $nonMigrationPackRequired, [Text.UTF8Encoding]::new($false))
    $compatibility = Invoke-Validator 'Compatibility'
    Assert-True ($compatibility.ExitCode -eq 1) "Unconditional profile/pack requirement in $($mutation.Name) should fail. Output: $($compatibility.Output)"
    Assert-Contains $compatibility.Output $mutation.Expected "Feature/bugfix pressure policy $($mutation.Name)"
  }
  finally {
    [IO.File]::WriteAllBytes($sharedFixture, $sharedOriginalBytes)
  }
}

# Final whole-branch boundary pressure: these cases deliberately use the real
# onboarding profile/template and real prompt-native consumers. Each mutation
# names a production regression that must be rejected by the validator.
$projectProfileTemplateFixture = Join-Path $PSScriptRoot '../templates/migration/project-profile.yaml'
$projectProfileTemplateOriginalBytes = [IO.File]::ReadAllBytes($projectProfileTemplateFixture)
$projectProfileTemplateOriginal = [Text.Encoding]::UTF8.GetString($projectProfileTemplateOriginalBytes).Replace("`r`n", "`n")
Assert-True `
  ($projectProfileTemplateOriginal -notmatch '(?m)^change_type\s*:') `
  'Onboarding-generated project profile must not persist a top-level change_type'

$generatedProfileMutations = @(
  [pscustomobject]@{
    Name = 'missing automation mode'
    Apply = { param($text) $text.Replace("automation:`n  mode: interactive`n", '') }
    Expected = 'FAIL: Migration project profile template must declare generated default automation.mode: interactive'
  }
  [pscustomobject]@{
    Name = 'invalid automation mode'
    Apply = { param($text) $text.Replace('  mode: interactive', '  mode: fully-automatic') }
    Expected = 'FAIL: Migration project profile template invalid automation.mode: fully-automatic'
  }
  [pscustomobject]@{
    Name = 'missing artifact language'
    Apply = { param($text) $text.Replace("output:`n  artifact_language: vi`n", '') }
    Expected = 'FAIL: Migration project profile template must declare generated default output.artifact_language: vi'
  }
  [pscustomobject]@{
    Name = 'invalid artifact language'
    Apply = { param($text) $text.Replace('  artifact_language: vi', '  artifact_language: en') }
    Expected = 'FAIL: Migration project profile template invalid output.artifact_language: en'
  }
)
foreach ($mutation in $generatedProfileMutations) {
  try {
    $mutatedProfile = & $mutation.Apply $projectProfileTemplateOriginal
    Assert-True ($mutatedProfile -ne $projectProfileTemplateOriginal) "Generated-profile mutation must alter real template: $($mutation.Name)"
    [IO.File]::WriteAllText($projectProfileTemplateFixture, $mutatedProfile, [Text.UTF8Encoding]::new($false))
    $contracts = Invoke-Validator 'Contracts'
    Assert-True ($contracts.ExitCode -eq 1) "Generated profile with $($mutation.Name) should fail. Output: $($contracts.Output)"
    Assert-Contains $contracts.Output $mutation.Expected "Generated-profile contract: $($mutation.Name)"
  }
  finally {
    [IO.File]::WriteAllBytes($projectProfileTemplateFixture, $projectProfileTemplateOriginalBytes)
  }
}

$schemaAutomationOriginalBytes = [IO.File]::ReadAllBytes($schemaPath)
$schemaAutomationOriginal = [Text.Encoding]::UTF8.GetString($schemaAutomationOriginalBytes).Replace("`r`n", "`n")
$automationArtifactMutations = @(
  [pscustomobject]@{
    Name = 'missing waiver status'
    Apply = { param($text) $text.Replace("status: approved`n", '') }
    Expected = 'FAIL: Migration automation artifact schema waiver requires exactly one status: approved'
  }
  [pscustomobject]@{
    Name = 'duplicate waiver status'
    Apply = { param($text) $text.Replace('status: approved', "status: approved`nstatus: approved") }
    Expected = 'FAIL: Migration automation artifact schema waiver requires exactly one status: approved'
  }
  [pscustomobject]@{
    Name = 'draft waiver status'
    Apply = { param($text) $text.Replace('status: approved', 'status: draft') }
    Expected = 'FAIL: Migration automation artifact schema waiver requires exactly one status: approved'
  }
  [pscustomobject]@{
    Name = 'invalid waiver status'
    Apply = { param($text) $text.Replace('status: approved', 'status: rejected') }
    Expected = 'FAIL: Migration automation artifact schema waiver requires exactly one status: approved'
  }
  [pscustomobject]@{
    Name = 'invalid approval source'
    Apply = { param($text) $text.Replace('approval_source: auto-waive', 'approval_source: fully-automatic') }
    Expected = 'FAIL: Migration automation artifact schema invalid approval_source: fully-automatic'
  }
  [pscustomobject]@{
    Name = 'extra waiver field'
    Apply = { param($text) $text.Replace('  evidence: <command/error/capability evidence>', "  evidence: <command/error/capability evidence>`n  owner: migration-team") }
    Expected = 'FAIL: Migration automation artifact schema waiver fields must be exactly: policy, category, original_verdict, effective_action, evidence'
  }
  [pscustomobject]@{
    Name = 'complete result with waiver'
    Apply = { param($text) $text.Replace('result: partial', 'result: complete') }
    Expected = 'FAIL: Migration automation artifact schema waiver requires result: partial'
  }
  [pscustomobject]@{
    Name = 'auto approval with waiver'
    Apply = { param($text) $text.Replace('approval_source: auto-waive', 'approval_source: auto') }
    Expected = 'FAIL: Migration automation artifact schema waiver requires approval_source: auto-waive'
  }
)
foreach ($waiverField in @('policy', 'category', 'original_verdict', 'effective_action', 'evidence')) {
  $automationArtifactMutations += [pscustomobject]@{
    Name = "missing waiver field $waiverField"
    Apply = {
      param($text)
      [regex]::Replace($text, "(?m)^  $([regex]::Escape($waiverField)):[^\r\n]*(?:\r?\n|\z)", '', 1)
    }.GetNewClosure()
    Expected = 'FAIL: Migration automation artifact schema waiver fields must be exactly: policy, category, original_verdict, effective_action, evidence'
  }
}
foreach ($mutation in $automationArtifactMutations) {
  try {
    $mutatedSchema = & $mutation.Apply $schemaAutomationOriginal
    Assert-True ($mutatedSchema -ne $schemaAutomationOriginal) "Automation-artifact mutation must alter real schema: $($mutation.Name)"
    [IO.File]::WriteAllText($schemaPath, $mutatedSchema, [Text.UTF8Encoding]::new($false))
    $contracts = Invoke-Validator 'Contracts'
    Assert-True ($contracts.ExitCode -eq 1) "Automation artifact with $($mutation.Name) should fail. Output: $($contracts.Output)"
    Assert-Contains $contracts.Output $mutation.Expected "Automation-artifact contract: $($mutation.Name)"
  }
  finally {
    [IO.File]::WriteAllBytes($schemaPath, $schemaAutomationOriginalBytes)
  }
}

$legacyFallbackSentence = 'A legacy profile that omits `automation` and `output` resolves to `automation.mode: interactive` and `output.artifact_language: vi`; it remains valid and is not rewritten merely to apply these fallbacks.'
try {
  $schemaWithoutLegacyFallback = $schemaAutomationOriginal.Replace($legacyFallbackSentence, '')
  Assert-True ($schemaWithoutLegacyFallback -ne $schemaAutomationOriginal) 'Legacy profile fallback mutation must alter real schema'
  [IO.File]::WriteAllText($schemaPath, $schemaWithoutLegacyFallback, [Text.UTF8Encoding]::new($false))
  $contracts = Invoke-Validator 'Contracts'
  Assert-True ($contracts.ExitCode -eq 1) "Schema without legacy automation/language fallback should fail. Output: $($contracts.Output)"
  Assert-Contains $contracts.Output 'FAIL: Migration profile compatibility missing:' 'Legacy profile fallback contract'
}
finally {
  [IO.File]::WriteAllBytes($schemaPath, $schemaAutomationOriginalBytes)
}
try {
  $profileWithPersistentWorkflow = $projectProfileTemplateOriginal.Replace(
    'project: { id: unknown }',
    "project: { id: unknown }`nchange_type: migration"
  )
  Assert-True ($profileWithPersistentWorkflow -ne $projectProfileTemplateOriginal) 'Persistent workflow mutation must alter project profile template'
  [IO.File]::WriteAllText($projectProfileTemplateFixture, $profileWithPersistentWorkflow, [Text.UTF8Encoding]::new($false))
  $contracts = Invoke-Validator 'Contracts'
  Assert-True ($contracts.ExitCode -eq 1) "Persistent project-profile workflow type should fail. Output: $($contracts.Output)"
  Assert-Contains $contracts.Output 'FAIL: Migration project profile template must not declare top-level change_type' 'Per-run workflow authority profile boundary'
}
finally {
  [IO.File]::WriteAllBytes($projectProfileTemplateFixture, $projectProfileTemplateOriginalBytes)
}

$workflowOrchestratorMutations = @(
  [pscustomobject]@{
    Name = 'feature'; Workflow = 'feature'; KnowledgeStep = '09-knowledge-base'
    Expected = 'FAIL: Feature orchestrator must provide authoritative workflow_type: feature even when the onboarding profile contains migration settings'
  }
  [pscustomobject]@{
    Name = 'bugfix'; Workflow = 'bugfix'; KnowledgeStep = '09-knowledge-base'
    Expected = 'FAIL: Bugfix orchestrator must provide authoritative workflow_type: bugfix even when the onboarding profile contains migration settings'
  }
  [pscustomobject]@{
    Name = 'migrate'; Workflow = 'migration'; KnowledgeStep = '15-knowledge-base'
    Expected = 'FAIL: Migration orchestrator must provide authoritative workflow_type: migration'
  }
)
foreach ($mutation in $workflowOrchestratorMutations) {
  $workflowOrchestratorFixture = Join-Path $PSScriptRoot "../skills/aitoolkit/$($mutation.Name)/SKILL.md"
  $workflowOrchestratorOriginalBytes = [IO.File]::ReadAllBytes($workflowOrchestratorFixture)
  $workflowOrchestratorOriginal = [Text.Encoding]::UTF8.GetString($workflowOrchestratorOriginalBytes)
  try {
    $workflowToken = "``workflow_type: $($mutation.Workflow)``"
    $wrongWorkflowToken = if ($mutation.Workflow -eq 'migration') { '``workflow_type: feature``' } else { '``workflow_type: migration``' }
    $wrongWorkflow = $workflowOrchestratorOriginal.Replace($workflowToken, $wrongWorkflowToken)
    Assert-True ($wrongWorkflow -ne $workflowOrchestratorOriginal) "Workflow authority mutation must alter $($mutation.Name) orchestrator"
    [IO.File]::WriteAllText($workflowOrchestratorFixture, $wrongWorkflow, [Text.UTF8Encoding]::new($false))
    $orchestrators = Invoke-Validator 'Orchestrators'
    Assert-True ($orchestrators.ExitCode -eq 1) "Wrong per-run workflow type in $($mutation.Name) should fail. Output: $($orchestrators.Output)"
    Assert-Contains $orchestrators.Output $mutation.Expected "Per-run workflow type $($mutation.Name)"

    [IO.File]::WriteAllBytes($workflowOrchestratorFixture, $workflowOrchestratorOriginalBytes)
    $knowledgeToken = "``knowledge_step_id: $($mutation.KnowledgeStep)``"
    $wrongKnowledge = $workflowOrchestratorOriginal.Replace($knowledgeToken, '``knowledge_step_id: 10-knowledge-base``')
    Assert-True ($wrongKnowledge -ne $workflowOrchestratorOriginal) "Knowledge step-id mutation must alter $($mutation.Name) orchestrator"
    [IO.File]::WriteAllText($workflowOrchestratorFixture, $wrongKnowledge, [Text.UTF8Encoding]::new($false))
    $orchestrators = Invoke-Validator 'Orchestrators'
    Assert-True ($orchestrators.ExitCode -eq 1) "Wrong Knowledge step id in $($mutation.Name) should fail. Output: $($orchestrators.Output)"
    Assert-Contains $orchestrators.Output "FAIL: $([Globalization.CultureInfo]::InvariantCulture.TextInfo.ToTitleCase($mutation.Name)) orchestrator must provide $($mutation.KnowledgeStep) to Knowledge Capture" "Workflow-specific Knowledge step id $($mutation.Name)"
  }
  finally {
    [IO.File]::WriteAllBytes($workflowOrchestratorFixture, $workflowOrchestratorOriginalBytes)
  }
}

$workflowAuthorityPhrase = 'caller-provided `workflow_type` is authoritative'
foreach ($consumerName in @('ai-review', 'verification-testing', 'gerrit-automation', 'ccc-automation')) {
  $consumerFixture = Join-Path $PSScriptRoot "../skills/shared/$consumerName/SKILL.md"
  $consumerOriginalBytes = [IO.File]::ReadAllBytes($consumerFixture)
  $consumerOriginal = [Text.Encoding]::UTF8.GetString($consumerOriginalBytes)
  try {
    $profileFirstConsumer = $consumerOriginal.Replace(
      $workflowAuthorityPhrase,
      'persistent project profile change_type is authoritative'
    )
    Assert-True ($profileFirstConsumer -ne $consumerOriginal) "Workflow-authority mutation must alter shared consumer $consumerName"
    [IO.File]::WriteAllText($consumerFixture, $profileFirstConsumer, [Text.UTF8Encoding]::new($false))
    $compatibility = Invoke-Validator 'Compatibility'
    Assert-True ($compatibility.ExitCode -eq 1) "Profile-first workflow classification in $consumerName should fail. Output: $($compatibility.Output)"
    Assert-Contains $compatibility.Output "FAIL: Shared skill $consumerName workflow authority missing: $workflowAuthorityPhrase" "Shared workflow authority $consumerName"
  }
  finally {
    [IO.File]::WriteAllBytes($consumerFixture, $consumerOriginalBytes)
  }
}

$kbTemplateFixture = Join-Path $PSScriptRoot '../templates/kb-entry.md'
$kbTemplateOriginalBytes = [IO.File]::ReadAllBytes($kbTemplateFixture)
$kbTemplateOriginal = [Text.Encoding]::UTF8.GetString($kbTemplateOriginalBytes)
try {
  $legacyKbTemplate = $kbTemplateOriginal.Replace(
    'step_id: <orchestrator-provided-step-id>',
    'step_id: 10-knowledge-base'
  ).Replace(
    '<orchestrator-provided-workflow-type>',
    'migration'
  ).Replace(
    "## $terminalVerificationSection",
    '## Go/No-Go'
  )
  Assert-True ($legacyKbTemplate -ne $kbTemplateOriginal) 'Legacy Knowledge Base template mutation must alter the terminal template'
  [IO.File]::WriteAllText($kbTemplateFixture, $legacyKbTemplate, [Text.UTF8Encoding]::new($false))
  $templates = Invoke-Validator 'Templates'
  Assert-True ($templates.ExitCode -eq 1) "Legacy hard-coded Knowledge Base template should fail. Output: $($templates.Output)"
  Assert-Contains $templates.Output 'FAIL: Template kb-entry.md step_id must be orchestrator-provided' 'Knowledge Base dynamic step id'
  Assert-Contains $templates.Output 'FAIL: Template kb-entry.md workflow type must be orchestrator-provided' 'Knowledge Base dynamic workflow type'
  Assert-Contains $templates.Output "FAIL: Template kb-entry.md missing section: $terminalVerificationSection" 'Knowledge Base workflow-appropriate verdict'
}
finally {
  [IO.File]::WriteAllBytes($kbTemplateFixture, $kbTemplateOriginalBytes)
}

try {
  $profileWithoutArchitecture = $projectProfileTemplateOriginal.Replace("  architecture: []`n", '')
  Assert-True ($profileWithoutArchitecture -ne $projectProfileTemplateOriginal) 'Architecture-category removal mutation must alter project profile template'
  [IO.File]::WriteAllText($projectProfileTemplateFixture, $profileWithoutArchitecture, [Text.UTF8Encoding]::new($false))
  $contracts = Invoke-Validator 'Contracts'
  Assert-True ($contracts.ExitCode -eq 1) "Project profile without architecture documents should fail. Output: $($contracts.Output)"
  Assert-Contains $contracts.Output 'FAIL: Migration project profile documents must declare exactly one architecture: [] list' 'Canonical architecture document category'

  [IO.File]::WriteAllBytes($projectProfileTemplateFixture, $projectProfileTemplateOriginalBytes)
  $profileWithoutEntryField = $projectProfileTemplateOriginal.Replace('evidence_id', 'source_id')
  Assert-True ($profileWithoutEntryField -ne $projectProfileTemplateOriginal) 'Structured document-entry mutation must alter project profile template'
  [IO.File]::WriteAllText($projectProfileTemplateFixture, $profileWithoutEntryField, [Text.UTF8Encoding]::new($false))
  $contracts = Invoke-Validator 'Contracts'
  Assert-True ($contracts.ExitCode -eq 1) "Project profile without exact structured document entry should fail. Output: $($contracts.Output)"
  Assert-Contains $contracts.Output 'FAIL: Migration project profile document entry schema missing: evidence_id' 'Canonical structured document entry schema'

  [IO.File]::WriteAllBytes($projectProfileTemplateFixture, $projectProfileTemplateOriginalBytes)
  $documentEntryAnchor = '#   evidence_id: <unique Evidence ID>'
  $profileWithExtraEntryField = $projectProfileTemplateOriginal.Replace(
    $documentEntryAnchor,
    "$documentEntryAnchor`n#   provenance: <uncontracted sixth key>"
  )
  Assert-True ($profileWithExtraEntryField -ne $projectProfileTemplateOriginal) 'Extra document-entry key mutation must alter project profile template'
  [IO.File]::WriteAllText($projectProfileTemplateFixture, $profileWithExtraEntryField, [Text.UTF8Encoding]::new($false))
  $contracts = Invoke-Validator 'Contracts'
  Assert-True ($contracts.ExitCode -eq 1) "Project profile with an extra structured document entry key should fail. Output: $($contracts.Output)"
  Assert-Contains $contracts.Output 'FAIL: Migration project profile document entry keys must be exactly: path, input_source, format, readability, evidence_id' 'Canonical document entry exact key set'
}
finally {
  [IO.File]::WriteAllBytes($projectProfileTemplateFixture, $projectProfileTemplateOriginalBytes)
}

foreach ($mode in @('greenfield', 'incremental')) {
  $profileFixture = Join-Path $PSScriptRoot "../examples/migration/$mode/docs/aitoolkit/project.yaml"
  $profileOriginalBytes = [IO.File]::ReadAllBytes($profileFixture)
  $profileOriginal = [Text.Encoding]::UTF8.GetString($profileOriginalBytes).Replace("`r`n", "`n")
  try {
    $profileWithoutArchitecture = $profileOriginal.Replace("  architecture: []`n", '')
    Assert-True ($profileWithoutArchitecture -ne $profileOriginal) "Architecture-category mutation must alter $mode fixture"
    [IO.File]::WriteAllText($profileFixture, $profileWithoutArchitecture, [Text.UTF8Encoding]::new($false))
    $docs = Invoke-Validator 'Docs'
    Assert-True ($docs.ExitCode -eq 1) "$mode fixture without architecture documents should fail. Output: $($docs.Output)"
    Assert-Contains $docs.Output "FAIL: Migration example fixture examples/migration/$mode/docs/aitoolkit/project.yaml documents section must declare exactly one architecture: []" "Fixture architecture category $mode"
  }
  finally {
    [IO.File]::WriteAllBytes($profileFixture, $profileOriginalBytes)
  }

  $fixtureProfileMutations = @(
    [pscustomobject]@{
      Name = 'missing automation mode'; Apply = { param($text) $text.Replace("automation:`n  mode: interactive`n", '') }
      Expected = "FAIL: Migration example fixture examples/migration/$mode/docs/aitoolkit/project.yaml must declare generated default automation.mode: interactive"
    }
    [pscustomobject]@{
      Name = 'invalid automation mode'; Apply = { param($text) $text.Replace('  mode: interactive', '  mode: fully-automatic') }
      Expected = "FAIL: Migration example fixture examples/migration/$mode/docs/aitoolkit/project.yaml invalid automation.mode: fully-automatic"
    }
    [pscustomobject]@{
      Name = 'missing artifact language'; Apply = { param($text) $text.Replace("output:`n  artifact_language: vi`n", '') }
      Expected = "FAIL: Migration example fixture examples/migration/$mode/docs/aitoolkit/project.yaml must declare generated default output.artifact_language: vi"
    }
    [pscustomobject]@{
      Name = 'invalid artifact language'; Apply = { param($text) $text.Replace('  artifact_language: vi', '  artifact_language: en') }
      Expected = "FAIL: Migration example fixture examples/migration/$mode/docs/aitoolkit/project.yaml invalid output.artifact_language: en"
    }
  )
  foreach ($mutation in $fixtureProfileMutations) {
    try {
      $mutatedFixture = & $mutation.Apply $profileOriginal
      Assert-True ($mutatedFixture -ne $profileOriginal) "$mode profile mutation must alter real fixture: $($mutation.Name)"
      [IO.File]::WriteAllText($profileFixture, $mutatedFixture, [Text.UTF8Encoding]::new($false))
      $docs = Invoke-Validator 'Docs'
      Assert-True ($docs.ExitCode -eq 1) "$mode fixture with $($mutation.Name) should fail. Output: $($docs.Output)"
      Assert-Contains $docs.Output $mutation.Expected "$mode generated-profile contract: $($mutation.Name)"
    }
    finally {
      [IO.File]::WriteAllBytes($profileFixture, $profileOriginalBytes)
    }
  }
}

$greenfieldSkipContract = 'Greenfield always skips step 14; no base or project-specific regression route executes.'
try {
  $greenfieldRegressionRoute = $orchestratorOriginal.Replace(
    $greenfieldSkipContract,
    'Greenfield may execute step 14 through an approved mode-compatible project regression route.'
  )
  Assert-True ($greenfieldRegressionRoute -ne $orchestratorOriginal) 'Greenfield regression-route mutation must alter migration orchestrator'
  [IO.File]::WriteAllText($orchestratorFixture, $greenfieldRegressionRoute, [Text.UTF8Encoding]::new($false))
  $orchestrators = Invoke-Validator 'Orchestrators'
  Assert-True ($orchestrators.ExitCode -eq 1) "Greenfield step-14 execution wording should fail. Output: $($orchestrators.Output)"
  Assert-Contains $orchestrators.Output "FAIL: Migration orchestrator mode policy missing: $greenfieldSkipContract" 'Greenfield parity-to-Knowledge boundary'
  Assert-Contains $orchestrators.Output 'FAIL: Migration orchestrator must not permit a greenfield regression execution route' 'Greenfield step-14 prohibition'
}
finally {
  [IO.File]::WriteAllBytes($orchestratorFixture, $orchestratorOriginalBytes)
}

$standaloneGerritSection = 'Standalone migration invocation'
try {
  $implicitGerritHandoff = $gerritSkillOriginal.Replace(
    "## $standaloneGerritSection",
    '## Migration-only predecessor gate'
  ).Replace(
    'never requires an implicit migration-orchestrator handoff',
    'requires the exact immediate predecessor supplied by the migration orchestrator'
  )
  Assert-True ($implicitGerritHandoff -ne $gerritSkillOriginal) 'Standalone Gerrit invocation mutation must alter Gerrit skill'
  [IO.File]::WriteAllText($gerritSkillFixture, $implicitGerritHandoff, [Text.UTF8Encoding]::new($false))
  $compatibility = Invoke-Validator 'Compatibility'
  Assert-True ($compatibility.ExitCode -eq 1) "Migration Gerrit with an implicit orchestrator handoff should fail. Output: $($compatibility.Output)"
  Assert-Contains $compatibility.Output "FAIL: Shared skill gerrit-automation missing section: $standaloneGerritSection" 'Standalone migration Gerrit section'
  Assert-Contains $compatibility.Output 'FAIL: Shared Gerrit must not require an implicit migration-orchestrator handoff' 'Independent migration Gerrit invocation'

  [IO.File]::WriteAllBytes($gerritSkillFixture, $gerritSkillOriginalBytes)
  $wrongCompletedRun = $gerritSkillOriginal.Replace('`step_id: 15-knowledge-base`', '`step_id: 14-verify-regression`')
  Assert-True ($wrongCompletedRun -ne $gerritSkillOriginal) 'Completed-run identity mutation must alter Gerrit skill'
  [IO.File]::WriteAllText($gerritSkillFixture, $wrongCompletedRun, [Text.UTF8Encoding]::new($false))
  $compatibility = Invoke-Validator 'Compatibility'
  Assert-True ($compatibility.ExitCode -eq 1) "Standalone Gerrit without terminal KB identity should fail. Output: $($compatibility.Output)"
  Assert-Contains $compatibility.Output 'FAIL: Shared Gerrit standalone migration invocation missing: `step_id: 15-knowledge-base`' 'Standalone Gerrit completed run identity'

  [IO.File]::WriteAllBytes($gerritSkillFixture, $gerritSkillOriginalBytes)
  $completeVerdictSource = if ($gerritSkillOriginal.Contains('`Completion Verdict: complete`')) {
    '`Completion Verdict: complete`'
  }
  else {
    'a non-blocked Completion Verdict'
  }
  $partialCompletedRun = $gerritSkillOriginal.Replace($completeVerdictSource, '`Completion Verdict: partial`')
  Assert-True ($partialCompletedRun -ne $gerritSkillOriginal) 'Partial completed-run mutation must alter Gerrit skill'
  [IO.File]::WriteAllText($gerritSkillFixture, $partialCompletedRun, [Text.UTF8Encoding]::new($false))
  $compatibility = Invoke-Validator 'Compatibility'
  Assert-True ($compatibility.ExitCode -eq 1) "Standalone Gerrit accepting partial migration completion should fail. Output: $($compatibility.Output)"
  Assert-Contains $compatibility.Output 'FAIL: Shared Gerrit standalone migration invocation missing: `Completion Verdict: complete`' 'Standalone Gerrit complete-only entry gate'

  [IO.File]::WriteAllBytes($gerritSkillFixture, $gerritSkillOriginalBytes)
  if ($gerritSkillOriginal.Contains('`status: approved`')) {
    $draftTerminalEvidence = $gerritSkillOriginal.Replace('`status: approved`', '`status: draft`')
  }
  else {
    $draftTerminalEvidence = $gerritSkillOriginal.Replace(
      'Missing, failed, blocked, cross-run, or mismatched evidence',
      '`status: draft` evidence'
    )
  }
  Assert-True ($draftTerminalEvidence -ne $gerritSkillOriginal) 'Draft terminal-evidence mutation must alter Gerrit skill'
  [IO.File]::WriteAllText($gerritSkillFixture, $draftTerminalEvidence, [Text.UTF8Encoding]::new($false))
  $compatibility = Invoke-Validator 'Compatibility'
  Assert-True ($compatibility.ExitCode -eq 1) "Standalone Gerrit accepting draft migration evidence should fail. Output: $($compatibility.Output)"
  Assert-Contains $compatibility.Output 'FAIL: Shared Gerrit standalone migration invocation missing: `status: approved`' 'Standalone Gerrit approved terminal evidence gate'

  [IO.File]::WriteAllBytes($gerritSkillFixture, $gerritSkillOriginalBytes)
  $sameRunParitySource = if ($gerritSkillOriginal.Contains('same-run approved parity evidence')) {
    'same-run approved parity evidence'
  }
  else {
    "same run's parity evidence"
  }
  $crossRunParityEvidence = $gerritSkillOriginal.Replace($sameRunParitySource, 'cross-run parity evidence')
  Assert-True ($crossRunParityEvidence -ne $gerritSkillOriginal) 'Cross-run parity-evidence mutation must alter Gerrit skill'
  [IO.File]::WriteAllText($gerritSkillFixture, $crossRunParityEvidence, [Text.UTF8Encoding]::new($false))
  $compatibility = Invoke-Validator 'Compatibility'
  Assert-True ($compatibility.ExitCode -eq 1) "Standalone incremental Gerrit accepting cross-run parity evidence should fail. Output: $($compatibility.Output)"
  Assert-Contains $compatibility.Output 'FAIL: Shared Gerrit standalone migration invocation missing: same-run approved parity evidence' 'Standalone Gerrit incremental same-run parity gate'

  [IO.File]::WriteAllBytes($gerritSkillFixture, $gerritSkillOriginalBytes)
  if ($gerritSkillOriginal.Contains('`result: complete`') -and $gerritSkillOriginal.Contains('`Verification Verdict: PASS`')) {
    $nonPassingTerminalEvidence = $gerritSkillOriginal.Replace(
      '`result: complete`',
      '`result: partial`'
    ).Replace(
      '`Verification Verdict: PASS`',
      '`Verification Verdict: FAIL`'
    )
  }
  else {
    $nonPassingTerminalEvidence = $gerritSkillOriginal.Replace(
      'parity verdict, regression applicability/verdict',
      '`result: partial` and `Verification Verdict: FAIL`'
    )
  }
  Assert-True ($nonPassingTerminalEvidence -ne $gerritSkillOriginal) 'Non-passing terminal-evidence mutation must alter Gerrit skill'
  [IO.File]::WriteAllText($gerritSkillFixture, $nonPassingTerminalEvidence, [Text.UTF8Encoding]::new($false))
  $compatibility = Invoke-Validator 'Compatibility'
  Assert-True ($compatibility.ExitCode -eq 1) "Standalone Gerrit accepting partial or failed terminal evidence should fail. Output: $($compatibility.Output)"
  Assert-Contains $compatibility.Output 'FAIL: Shared Gerrit standalone migration invocation missing: `result: complete`' 'Standalone Gerrit complete terminal evidence result'
  Assert-Contains $compatibility.Output 'FAIL: Shared Gerrit standalone migration invocation missing: `Verification Verdict: PASS`' 'Standalone Gerrit passing terminal verification gate'
}
finally {
  [IO.File]::WriteAllBytes($gerritSkillFixture, $gerritSkillOriginalBytes)
}

$schemaOriginalBytes = [IO.File]::ReadAllBytes($schemaPath)
$schemaOriginal = [Text.Encoding]::UTF8.GetString($schemaOriginalBytes)
try {
  $schemaWithImplicitGerrit = $schemaOriginal + [Environment]::NewLine +
    'Migration Gerrit consumes the exact immediate parity/regression predecessor supplied by the orchestrator.' + [Environment]::NewLine
  [IO.File]::WriteAllText($schemaPath, $schemaWithImplicitGerrit, [Text.UTF8Encoding]::new($false))
  $contracts = Invoke-Validator 'Contracts'
  Assert-True ($contracts.ExitCode -eq 1) "Schema-level implicit Migration Gerrit handoff should fail. Output: $($contracts.Output)"
  Assert-Contains $contracts.Output 'FAIL: Data contracts must not require an implicit Migration Gerrit predecessor' 'Stale Migration Gerrit schema requirement'
}
finally {
  [IO.File]::WriteAllBytes($schemaPath, $schemaOriginalBytes)
}

$reviewRubricFixture = Join-Path $PSScriptRoot '../skills/shared/ai-review/severity-rubric.md'
$reviewRubricOriginalBytes = [IO.File]::ReadAllBytes($reviewRubricFixture)
$reviewRubricOriginal = [Text.Encoding]::UTF8.GetString($reviewRubricOriginalBytes)
try {
  $blockedZeroApproved = $reviewRubricOriginal.Replace(
    '| BLOCKED | 0 | 0 | Reject |',
    '| BLOCKED | 0 | 0 | Approve |'
  )
  [IO.File]::WriteAllText($reviewRubricFixture, $blockedZeroApproved, [Text.UTF8Encoding]::new($false))
  $compatibility = Invoke-Validator 'Compatibility'
  Assert-True ($compatibility.ExitCode -eq 1) "BLOCKED rule resolution with zero findings should still Reject. Output: $($compatibility.Output)"
  Assert-Contains $compatibility.Output 'FAIL: Shared AI review verdict gate must Reject BLOCKED Rule Resolution with 0 Critical and 0 Major' 'Compatibility rule-resolution-first verdict'
}
finally {
  [IO.File]::WriteAllBytes($reviewRubricFixture, $reviewRubricOriginalBytes)
}

# Task 4 language behavior mutates real generated-artifact producers. Every case
# exercises the validator through its public selector and restores exact bytes.
$languageTemplateFixture = Join-Path $PSScriptRoot '../templates/migration/input-report.md'
$languageTemplateOriginalBytes = [IO.File]::ReadAllBytes($languageTemplateFixture)
$languageTemplateOriginal = [Text.Encoding]::UTF8.GetString($languageTemplateOriginalBytes)
try {
  $missingLanguageIntent = $languageTemplateOriginal.Replace('<!-- artifact_language: vi -->', '')
  Assert-True ($missingLanguageIntent -ne $languageTemplateOriginal) 'Vietnamese intent mutation must alter a real migration template'
  [IO.File]::WriteAllText($languageTemplateFixture, $missingLanguageIntent, [Text.UTF8Encoding]::new($false))
  $templates = Invoke-Validator 'Templates'
  Assert-True ($templates.ExitCode -eq 1) "Template without Vietnamese output intent should fail. Output: $($templates.Output)"
  Assert-Contains $templates.Output 'FAIL: Template input-report.md language intent missing: <!-- artifact_language: vi -->' 'Vietnamese template intent'

  [IO.File]::WriteAllBytes($languageTemplateFixture, $languageTemplateOriginalBytes)
  $vietnameseNotesPlaceholder = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('PGdoaSBjaMO6Pg=='))
  $englishPlaceholder = $languageTemplateOriginal.Replace($vietnameseNotesPlaceholder, '<English-only placeholder>')
  Assert-True ($englishPlaceholder -ne $languageTemplateOriginal) 'English-only placeholder mutation must alter a real migration template'
  [IO.File]::WriteAllText($languageTemplateFixture, $englishPlaceholder, [Text.UTF8Encoding]::new($false))
  $templates = Invoke-Validator 'Templates'
  Assert-True ($templates.ExitCode -eq 1) "English-only generated placeholder should fail. Output: $($templates.Output)"
  Assert-Contains $templates.Output 'FAIL: Template input-report.md contains English-only generated placeholder: <English-only placeholder>' 'Vietnamese placeholder enforcement'
}
finally {
  [IO.File]::WriteAllBytes($languageTemplateFixture, $languageTemplateOriginalBytes)
}

$verificationLanguageFixture = Join-Path $PSScriptRoot '../templates/migration/verification-report.md'
$verificationLanguageOriginalBytes = [IO.File]::ReadAllBytes($verificationLanguageFixture)
$verificationLanguageOriginal = [Text.Encoding]::UTF8.GetString($verificationLanguageOriginalBytes)
try {
  $translatedExecutionStatus = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('VHLhuqFuZyB0aMOhaSB0aOG7sWMgdGhp'))
  $translatedMachineField = $verificationLanguageOriginal.Replace('Execution Status', $translatedExecutionStatus)
  Assert-True ($translatedMachineField -ne $verificationLanguageOriginal) 'Machine-field translation mutation must alter the verification template'
  [IO.File]::WriteAllText($verificationLanguageFixture, $translatedMachineField, [Text.UTF8Encoding]::new($false))
  $templates = Invoke-Validator 'Templates'
  Assert-True ($templates.ExitCode -eq 1) "Translated machine-readable table field should fail. Output: $($templates.Output)"
  Assert-Contains $templates.Output 'table columns must be exactly' 'Machine-readable table field preservation'
}
finally {
  [IO.File]::WriteAllBytes($verificationLanguageFixture, $verificationLanguageOriginalBytes)
}

foreach ($sharedLanguageTemplateName in @('review-report.md', 'verification-report.md')) {
  $sharedLanguageFixture = Join-Path $PSScriptRoot "../templates/$sharedLanguageTemplateName"
  $sharedLanguageOriginalBytes = [IO.File]::ReadAllBytes($sharedLanguageFixture)
  $sharedLanguageOriginal = [Text.Encoding]::UTF8.GetString($sharedLanguageOriginalBytes)
  try {
    $regressedWorkflowRoute = $sharedLanguageOriginal + [Environment]::NewLine + '<!-- artifact_language: vi -->' + [Environment]::NewLine
    Assert-True ($regressedWorkflowRoute -ne $sharedLanguageOriginal) "$sharedLanguageTemplateName feature/bugfix language-isolation mutation must alter the template"
    [IO.File]::WriteAllText($sharedLanguageFixture, $regressedWorkflowRoute, [Text.UTF8Encoding]::new($false))
    $templates = Invoke-Validator 'Templates'
    Assert-True ($templates.ExitCode -eq 1) "$sharedLanguageTemplateName routing feature/bugfix through Vietnamese rendering should fail. Output: $($templates.Output)"
    Assert-Contains $templates.Output "FAIL: Template $sharedLanguageTemplateName must remain legacy feature/bugfix language; migration rendering belongs in migration/$sharedLanguageTemplateName" 'Shared-template feature/bugfix language isolation'
  }
  finally {
    [IO.File]::WriteAllBytes($sharedLanguageFixture, $sharedLanguageOriginalBytes)
  }
}

foreach ($migrationSharedTemplateName in @('review-report.md', 'verification-report.md')) {
  $migrationSharedFixture = Join-Path $PSScriptRoot "../templates/migration/$migrationSharedTemplateName"
  if (-not (Test-Path $migrationSharedFixture)) {
    Assert-True $false "Migration-specific shared-step template must exist before mutation: $migrationSharedTemplateName"
    continue
  }
  $migrationSharedOriginalBytes = [IO.File]::ReadAllBytes($migrationSharedFixture)
  $migrationSharedOriginal = [Text.Encoding]::UTF8.GetString($migrationSharedOriginalBytes)
  try {
    $missingMigrationLanguage = $migrationSharedOriginal.Replace('<!-- artifact_language: vi -->', '')
    Assert-True ($missingMigrationLanguage -ne $migrationSharedOriginal) "$migrationSharedTemplateName migration language mutation must alter template"
    [IO.File]::WriteAllText($migrationSharedFixture, $missingMigrationLanguage, [Text.UTF8Encoding]::new($false))
    $templates = Invoke-Validator 'Templates'
    Assert-True ($templates.ExitCode -eq 1) "Migration-specific $migrationSharedTemplateName without vi intent should fail. Output: $($templates.Output)"
    Assert-Contains $templates.Output "FAIL: Template migration/$migrationSharedTemplateName language intent missing: <!-- artifact_language: vi -->" 'Migration-specific shared-step language default'
  }
  finally {
    [IO.File]::WriteAllBytes($migrationSharedFixture, $migrationSharedOriginalBytes)
  }
}

$onboardingLanguageFixture = Join-Path $PSScriptRoot '../skills/aitoolkit/migration-onboarding/SKILL.md'
$onboardingLanguageOriginalBytes = [IO.File]::ReadAllBytes($onboardingLanguageFixture)
$onboardingLanguageOriginal = [Text.Encoding]::UTF8.GetString($onboardingLanguageOriginalBytes)
try {
  $sourceTranslationBoundary = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('S2jDtG5nIGThu4tjaCwgZGkgY2h1eeG7g24gaG/hurdjIHPhu61hIHTDoGkgbGnhu4d1IG5ndeG7k24='))
  $sourceTranslationAuthorization = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('Q8OzIHRo4buDIGThu4tjaCB0w6BpIGxp4buHdSBuZ3Xhu5NuIGtoaSBj4bqnbiBjaG8gYXJ0aWZhY3Q='))
  $translationAuthorization = $onboardingLanguageOriginal.Replace(
    $sourceTranslationBoundary,
    $sourceTranslationAuthorization
  )
  Assert-True ($translationAuthorization -ne $onboardingLanguageOriginal) 'Source-translation authorization mutation must alter the onboarding orchestrator'
  [IO.File]::WriteAllText($onboardingLanguageFixture, $translationAuthorization, [Text.UTF8Encoding]::new($false))
  $orchestrators = Invoke-Validator 'Orchestrators'
  Assert-True ($orchestrators.ExitCode -eq 1) "Source-document translation authorization should fail. Output: $($orchestrators.Output)"
  Assert-Contains $orchestrators.Output 'must not authorize source-document translation' 'Source-document byte-preservation boundary'
}
finally {
  [IO.File]::WriteAllBytes($onboardingLanguageFixture, $onboardingLanguageOriginalBytes)
}

$mojibakeTemplateFixture = Join-Path $PSScriptRoot '../templates/migration/discovery.md'
$mojibakeTemplateOriginalBytes = [IO.File]::ReadAllBytes($mojibakeTemplateFixture)
$mojibakeTemplateOriginal = [Text.Encoding]::UTF8.GetString($mojibakeTemplateOriginalBytes)
try {
  $mojibakeToken = ([char]0x00C3).ToString() + 'X'
  $mojibakeTemplate = $mojibakeTemplateOriginal + [Environment]::NewLine + $mojibakeToken
  [IO.File]::WriteAllText($mojibakeTemplateFixture, $mojibakeTemplate, [Text.UTF8Encoding]::new($false))
  $encoding = Invoke-Validator 'Encoding'
  Assert-True ($encoding.ExitCode -eq 1) "Mojibake in a generated migration template should fail. Output: $($encoding.Output)"
  Assert-Contains $encoding.Output 'templates\migration\discovery.md' 'Generated-template mojibake rejection'
}
finally {
  [IO.File]::WriteAllBytes($mojibakeTemplateFixture, $mojibakeTemplateOriginalBytes)
}

$validFixture = Join-Path $PSScriptRoot '.encoding-valid-fixture.ps1'
$invalidFixture = Join-Path $PSScriptRoot '.encoding-invalid-fixture.ps1'
$embeddedInvalidFixture = Join-Path $PSScriptRoot '.encoding-embedded-invalid-fixture.ps1'
try {
  $circumflexA = ([char]0x00C2).ToString()
  [IO.File]::WriteAllText($validFixture, "# C${circumflexA}Y PH${circumflexA}N", [Text.UTF8Encoding]::new($false))
  $encoding = Invoke-Validator 'Encoding'
  Assert-True ($encoding.ExitCode -eq 0) "Canonical Vietnamese fixture should pass. Output: $($encoding.Output)"

  [IO.File]::WriteAllText($invalidFixture, "# ${circumflexA}X", [Text.UTF8Encoding]::new($false))
  [IO.File]::WriteAllText($embeddedInvalidFixture, "# abc${circumflexA}X", [Text.UTF8Encoding]::new($false))
  $encoding = Invoke-Validator 'Encoding'
  Assert-True ($encoding.ExitCode -eq 1) "Required mojibake pattern should fail. Output: $($encoding.Output)"
  Assert-Contains $encoding.Output '.encoding-invalid-fixture.ps1' 'Encoding selector'
  Assert-Contains $encoding.Output '.encoding-embedded-invalid-fixture.ps1' 'Embedded encoding selector'
}
finally {
  Remove-Item -LiteralPath $validFixture, $invalidFixture, $embeddedInvalidFixture -Force -ErrorAction SilentlyContinue
}

if ($testFailures.Count -gt 0) {
  $testFailures | ForEach-Object { Write-Output "FAIL: $_" }
  exit 1
}

Write-Output 'PASS: focused migration framework tests'

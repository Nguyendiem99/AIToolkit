# Review package: a8f99d4b738d7c6795f389b00e76128692c32787..9f467ad09f5d3cf9a182cce2d6e8dc1edc2ad969

## Commits
9f467ad test: cover responsibility conformance workflow

## Files changed
 .../tests/validate-migration-framework.Tests.ps1   | 46 ++++++++++++++++++++++
 .../tests/validate-migration-framework.ps1         | 30 +++++++++++++-
 2 files changed, 74 insertions(+), 2 deletions(-)

## Diff
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/validate-migration-framework.Tests.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/validate-migration-framework.Tests.ps1
index cecf5d7..26bcb41 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/validate-migration-framework.Tests.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/validate-migration-framework.Tests.ps1
@@ -462,20 +462,25 @@ if ($ResponsibilityConformanceOnly) {
       }
       [pscustomobject]@{ ExitCode = $exitCode; Output = ($output -join [Environment]::NewLine) }
     }
     Assert-True ($unreachableCoverageResult.ExitCode -eq 1) "Unreachable $($unreachableCoverageCase.Name) coverage registration must fail source integrity. Output: $($unreachableCoverageResult.Output)"
     Assert-Contains $unreachableCoverageResult.Output 'Responsibility source-integrity coverage missing: post-implementation queue advance' "Unreachable coverage registration: $($unreachableCoverageCase.Name)"
   }
   foreach ($foreachCoverageCase in @(
     [pscustomobject]@{ Name = 'explicit array expression'; Condition = "@('LF', 'CRLF')"; ExpectedActive = $true },
     [pscustomobject]@{ Name = 'comma literal array'; Condition = "'LF', 'CRLF'"; ExpectedActive = $true },
     [pscustomobject]@{ Name = 'integer literal range'; Condition = '1..2'; ExpectedActive = $true },
+    [pscustomobject]@{ Name = 'nested explicit array expression'; Condition = "@((@('LF', 'CRLF')))"; ExpectedActive = $true },
+    [pscustomobject]@{ Name = 'redirected explicit array expression'; Condition = "@('LF', 'CRLF') > `$null"; ExpectedActive = $false },
+    [pscustomobject]@{ Name = 'redirected comma literal array'; Condition = "'LF', 'CRLF' > `$null"; ExpectedActive = $false },
+    [pscustomobject]@{ Name = 'redirected integer literal range'; Condition = '1..2 > $null'; ExpectedActive = $false },
+    [pscustomobject]@{ Name = 'nested redirected expression'; Condition = "@((@('LF', 'CRLF') > `$null))"; ExpectedActive = $false },
     [pscustomobject]@{ Name = 'empty array expression'; Condition = '@()'; ExpectedActive = $false },
     [pscustomobject]@{ Name = 'dynamic command array'; Condition = '@(Get-Nothing)'; ExpectedActive = $false },
     [pscustomobject]@{ Name = 'dynamic subexpression array'; Condition = '@($(Get-Nothing))'; ExpectedActive = $false },
     [pscustomobject]@{ Name = 'variable collection'; Condition = '$coverageCases'; ExpectedActive = $false }
   )) {
     $foreachCoverageResult = Invoke-IsolatedMutation -SourceRoot $testRoot -Mutation {
       param($fixtureRoot)
       $fixtureScenario = Join-Path $fixtureRoot 'tests/scenarios/scope-engine.Tests.ps1'
       $fixtureText = [IO.File]::ReadAllText($fixtureScenario, [Text.Encoding]::UTF8)
       $replacement = "foreach (`$coverageCase in $($foreachCoverageCase.Condition)) {`n  $coverageRegistration`n}"
@@ -499,20 +504,61 @@ if ($ResponsibilityConformanceOnly) {
     }
     if ($foreachCoverageCase.ExpectedActive) {
       Assert-True ($foreachCoverageResult.ExitCode -eq 0) "Provably nonempty $($foreachCoverageCase.Name) registration must satisfy source integrity. Output: $($foreachCoverageResult.Output)"
       Assert-Contains $foreachCoverageResult.Output 'PASS: migration framework (SourceIntegrityOnly)' "Static foreach coverage registration: $($foreachCoverageCase.Name)"
     }
     else {
       Assert-True ($foreachCoverageResult.ExitCode -eq 1) "Uncertain $($foreachCoverageCase.Name) registration must fail source integrity. Output: $($foreachCoverageResult.Output)"
       Assert-Contains $foreachCoverageResult.Output 'Responsibility source-integrity coverage missing: post-implementation queue advance' "Uncertain foreach coverage registration: $($foreachCoverageCase.Name)"
     }
   }
+  foreach ($controlTransferCase in @(
+    [pscustomobject]@{ Name = 'preceding break'; Body = "break`n  $coverageRegistration"; ExpectedActive = $false },
+    [pscustomobject]@{ Name = 'preceding continue'; Body = "continue`n  $coverageRegistration"; ExpectedActive = $false },
+    [pscustomobject]@{ Name = 'preceding return'; Body = "return`n  $coverageRegistration"; ExpectedActive = $false },
+    [pscustomobject]@{ Name = 'preceding throw'; Body = "throw 'stop'`n  $coverageRegistration"; ExpectedActive = $false },
+    [pscustomobject]@{ Name = 'preceding exit'; Body = "exit 1`n  $coverageRegistration"; ExpectedActive = $false },
+    [pscustomobject]@{ Name = 'conditional preceding break'; Body = "if (`$coverageCase -eq 'never') { break }`n  $coverageRegistration"; ExpectedActive = $true },
+    [pscustomobject]@{ Name = 'trailing break'; Body = "$coverageRegistration`n  break"; ExpectedActive = $true }
+  )) {
+    $controlTransferResult = Invoke-IsolatedMutation -SourceRoot $testRoot -Mutation {
+      param($fixtureRoot)
+      $fixtureScenario = Join-Path $fixtureRoot 'tests/scenarios/scope-engine.Tests.ps1'
+      $fixtureText = [IO.File]::ReadAllText($fixtureScenario, [Text.Encoding]::UTF8)
+      $replacement = "foreach (`$coverageCase in @('LF')) {`n  $($controlTransferCase.Body)`n}"
+      $mutatedText = Replace-ExactOrFail $fixtureText $coverageRegistration $replacement "control-transfer coverage registration: $($controlTransferCase.Name)"
+      $parseTokens = $null
+      $parseErrors = $null
+      [void][Management.Automation.Language.Parser]::ParseInput($mutatedText, [ref]$parseTokens, [ref]$parseErrors)
+      if (@($parseErrors).Count -ne 0) { throw "Control-transfer coverage fixture must remain parse-valid: $($controlTransferCase.Name): $(@($parseErrors).Message -join '; ')" }
+      [IO.File]::WriteAllText($fixtureScenario, $mutatedText, [Text.UTF8Encoding]::new($false))
+      $fixtureValidator = Join-Path $fixtureRoot 'tests/validate-migration-framework.ps1'
+      $previousFixtureErrorActionPreference = $ErrorActionPreference
+      $ErrorActionPreference = 'Continue'
+      try {
+        $output = & $powershell -NoProfile -ExecutionPolicy Bypass -File $fixtureValidator -Check SourceIntegrityOnly -Root $fixtureRoot -AllowReducedResponsibilityFixture 2>&1
+        $exitCode = $LASTEXITCODE
+      }
+      finally {
+        $ErrorActionPreference = $previousFixtureErrorActionPreference
+      }
+      [pscustomobject]@{ ExitCode = $exitCode; Output = ($output -join [Environment]::NewLine) }
+    }
+    if ($controlTransferCase.ExpectedActive) {
+      Assert-True ($controlTransferResult.ExitCode -eq 0) "Non-dominating $($controlTransferCase.Name) registration must satisfy source integrity. Output: $($controlTransferResult.Output)"
+      Assert-Contains $controlTransferResult.Output 'PASS: migration framework (SourceIntegrityOnly)' "Non-dominating control-transfer registration: $($controlTransferCase.Name)"
+    }
+    else {
+      Assert-True ($controlTransferResult.ExitCode -eq 1) "Dominated $($controlTransferCase.Name) registration must fail source integrity. Output: $($controlTransferResult.Output)"
+      Assert-Contains $controlTransferResult.Output 'Responsibility source-integrity coverage missing: post-implementation queue advance' "Dominated control-transfer registration: $($controlTransferCase.Name)"
+    }
+  }
   foreach ($lineEndingProbe in @("`n", "`r`n")) {
     $probe = "before${lineEndingProbe}target${lineEndingProbe}after"
     $probeResult = Replace-ExactOrFail $probe "before`ntarget" "before`nchanged" 'line-ending probe'
     Assert-Contains $probeResult "before${lineEndingProbe}changed" 'LF/CRLF-independent alter-or-fail helper'
   }
   $mixedEndingProbe = "untouched-crlf`r`nbefore`ntarget`r`nuntouched-lf`nend"
   $mixedEndingExpected = "untouched-crlf`r`nbefore`nchanged`r`nuntouched-lf`nend"
   $mixedEndingResult = Replace-ExactOrFail $mixedEndingProbe "before`r`ntarget" "before`nchanged" 'mixed-ending probe'
   $mixedEndingExpectedBytes = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($mixedEndingExpected))
   $mixedEndingActualBytes = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($mixedEndingResult))
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/validate-migration-framework.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/validate-migration-framework.ps1
index 8136725..f7f1f11 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/validate-migration-framework.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/validate-migration-framework.ps1
@@ -9621,24 +9621,26 @@ if (-not [string]::IsNullOrWhiteSpace($ActivationSliceArtifactPath)) {
   }
   Write-Output 'PASS: Activation Slice artifact'
   exit 0
 }
 elseif (-not [string]::IsNullOrWhiteSpace($PredecessorActivationSliceArtifactPath)) {
   $errors.Add('Activation Slice predecessor requires ActivationSliceArtifactPath')
 }
 
 function Test-ArcStaticCoverageLiteralValue([Management.Automation.Language.Ast]$Node) {
   if ($null -eq $Node) { return $false }
+  $redirectionsProperty = $Node.PSObject.Properties['Redirections']
+  if ($null -ne $redirectionsProperty -and @($redirectionsProperty.Value).Count -ne 0) { return $false }
   if ($Node -is [Management.Automation.Language.PipelineAst]) {
     return $Node.PipelineElements.Count -eq 1 -and
       $Node.PipelineElements[0] -is [Management.Automation.Language.CommandExpressionAst] -and
-      (Test-ArcStaticCoverageLiteralValue $Node.PipelineElements[0].Expression)
+      (Test-ArcStaticCoverageLiteralValue $Node.PipelineElements[0])
   }
   if ($Node -is [Management.Automation.Language.CommandExpressionAst]) {
     return Test-ArcStaticCoverageLiteralValue $Node.Expression
   }
   if (
     $Node -is [Management.Automation.Language.StringConstantExpressionAst] -or
     $Node -is [Management.Automation.Language.ConstantExpressionAst]
   ) { return $true }
   if ($Node -is [Management.Automation.Language.ExpandableStringExpressionAst]) {
     return @($Node.NestedExpressions).Count -eq 0
@@ -9673,40 +9675,61 @@ function Test-ArcStaticCoverageLiteralValue([Management.Automation.Language.Ast]
     }
     return $true
   }
   if ($Node -is [Management.Automation.Language.ParenExpressionAst]) {
     return Test-ArcStaticCoverageLiteralValue $Node.Pipeline
   }
   return $false
 }
 
 function Test-ArcStaticNonEmptyCoverageCollection([Management.Automation.Language.Ast]$Condition) {
+  $conditionRedirectionsProperty = $Condition.PSObject.Properties['Redirections']
+  if ($null -ne $conditionRedirectionsProperty -and @($conditionRedirectionsProperty.Value).Count -ne 0) { return $false }
   if (
     $Condition -isnot [Management.Automation.Language.PipelineAst] -or
     $Condition.PipelineElements.Count -ne 1 -or
     $Condition.PipelineElements[0] -isnot [Management.Automation.Language.CommandExpressionAst]
   ) { return $false }
-  $expression = $Condition.PipelineElements[0].Expression
+  $commandExpression = $Condition.PipelineElements[0]
+  if (@($commandExpression.Redirections).Count -ne 0) { return $false }
+  $expression = $commandExpression.Expression
   if ($expression -is [Management.Automation.Language.ArrayExpressionAst] -or $expression -is [Management.Automation.Language.ArrayLiteralAst]) {
     return Test-ArcStaticCoverageLiteralValue $expression
   }
   if ($expression -is [Management.Automation.Language.BinaryExpressionAst] -and $expression.Operator -eq [Management.Automation.Language.TokenKind]::DotDot) {
     return (
       $expression.Left -is [Management.Automation.Language.ConstantExpressionAst] -and
       $expression.Right -is [Management.Automation.Language.ConstantExpressionAst] -and
       $expression.Left.Value -is [int] -and
       $expression.Right.Value -is [int]
     )
   }
   return $false
 }
 
+function Test-ArcCoverageStatementIsReachable(
+  [Management.Automation.Language.StatementBlockAst]$Block,
+  [Management.Automation.Language.StatementAst]$Statement
+) {
+  foreach ($candidate in $Block.Statements) {
+    if ([object]::ReferenceEquals($candidate, $Statement)) { return $true }
+    if (
+      $candidate -is [Management.Automation.Language.BreakStatementAst] -or
+      $candidate -is [Management.Automation.Language.ContinueStatementAst] -or
+      $candidate -is [Management.Automation.Language.ReturnStatementAst] -or
+      $candidate -is [Management.Automation.Language.ThrowStatementAst] -or
+      $candidate -is [Management.Automation.Language.ExitStatementAst]
+    ) { return $false }
+  }
+  return $false
+}
+
 function Test-ResponsibilitySourceIntegrity {
   $reducedFixtureAllowed = $false
   if ($AllowReducedResponsibilityFixture) {
     $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd(
       [IO.Path]::DirectorySeparatorChar,
       [IO.Path]::AltDirectorySeparatorChar
     )
     $fixtureContainer = [IO.Path]::GetDirectoryName($root)
     $reducedFixtureAllowed =
       [IO.Path]::GetFileName($root) -ceq 'aitoolkit' -and
@@ -9766,27 +9789,30 @@ function Test-ResponsibilitySourceIntegrity {
     $path = Join-Path $root $requirement.Path
     if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
     if (-not $activeCoverageCommandsByPath.ContainsKey($requirement.Path)) {
       $parseTokens = $null
       $parseErrors = $null
       $ast = [Management.Automation.Language.Parser]::ParseFile($path, [ref]$parseTokens, [ref]$parseErrors)
       $activeCoverageCommandsByPath[$requirement.Path] = @($ast.FindAll({
         param($node)
         if ($node -isnot [Management.Automation.Language.CommandAst]) { return $false }
         $ancestor = $node.Parent
+        $containingStatement = $null
         while ($null -ne $ancestor) {
           if ($ancestor -is [Management.Automation.Language.PipelineAst]) {
+            $containingStatement = $ancestor
             $ancestor = $ancestor.Parent
             continue
           }
           if ($ancestor -is [Management.Automation.Language.StatementBlockAst]) {
             if ($ancestor.Parent -isnot [Management.Automation.Language.ForEachStatementAst]) { return $false }
+            if (-not (Test-ArcCoverageStatementIsReachable $ancestor $containingStatement)) { return $false }
             $ancestor = $ancestor.Parent
             continue
           }
           if ($ancestor -is [Management.Automation.Language.ForEachStatementAst]) {
             if (-not (Test-ArcStaticNonEmptyCoverageCollection $ancestor.Condition)) { return $false }
             $ancestor = $ancestor.Parent
             continue
           }
           if ($ancestor -is [Management.Automation.Language.NamedBlockAst]) {
             $ancestor = $ancestor.Parent

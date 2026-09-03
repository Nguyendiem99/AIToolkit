# Review package: 75d208469933ce44f711ecf5fe970c7ee328d5bb..a8f99d4b738d7c6795f389b00e76128692c32787

## Commits
a8f99d4 test: cover responsibility conformance workflow

## Files changed
 .../tests/scenarios/architecture-review.Tests.ps1  | 99 ++++++++++++++++++++++
 .../tests/validate-migration-framework.Tests.ps1   | 41 +++++++++
 .../tests/validate-migration-framework.ps1         | 82 ++++++++++++++++--
 .../responsibility-conformance.validation.ps1      | 50 ++++++++++-
 4 files changed, 261 insertions(+), 11 deletions(-)

## Diff
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/architecture-review.Tests.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/architecture-review.Tests.ps1
index c8fc4fa..e64ffbe 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/architecture-review.Tests.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/architecture-review.Tests.ps1
@@ -1017,20 +1017,69 @@ class LexicalOwner {
   /* an inert opening brace: { */
   int run() { return 1; }
 }
 danger()
 "@
   $braceRogue = Invoke-LexicalSourceInventoryProbe "brace-rogue-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $braceRogueSource
   if ($braceRogue.Errors -cnotcontains 'responsibility-evidence-missing') {
     throw "braces in strings/comments swallowed later rogue code ($($lexicalLineEnding.Name))"
   }
   Write-Output "PASS: braces in strings/comments cannot swallow later rogue code ($($lexicalLineEnding.Name))"
+
+  foreach ($multilineLiteralCase in @(
+    [pscustomobject]@{ Name = 'java-text-block'; Declaration = 'String payload = """'; Method = 'int run() { return 1; }' },
+    [pscustomobject]@{ Name = 'csharp-raw-string'; Declaration = 'string Payload = """'; Method = 'int Run() { return 1; }' }
+  )) {
+    $multilinePositiveSource = @"
+$lexicalOwnerMetadata
+class LexicalOwner {
+  $($multilineLiteralCase.Declaration)
+}
+""";
+  $($multilineLiteralCase.Method)
+}
+"@
+    $multilinePositive = Invoke-LexicalSourceInventoryProbe "$($multilineLiteralCase.Name)-positive-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $multilinePositiveSource
+    if ($multilinePositive.Errors.Count -ne 0 -or $multilinePositive.OwnerCount -ne 1) {
+      throw "$($multilineLiteralCase.Name) braces must remain inert inside a closed multiline literal ($($lexicalLineEnding.Name)): $($multilinePositive.Errors -join '; ')"
+    }
+    Write-Output "PASS: $($multilineLiteralCase.Name) braces remain inert inside a closed multiline literal ($($lexicalLineEnding.Name))"
+
+    $multilineRogueSource = @"
+$lexicalOwnerMetadata
+class LexicalOwner {
+  $($multilineLiteralCase.Declaration)
+{
+""";
+  $($multilineLiteralCase.Method)
+}
+danger()
+"@
+    $multilineRogue = Invoke-LexicalSourceInventoryProbe "$($multilineLiteralCase.Name)-rogue-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $multilineRogueSource
+    if ($multilineRogue.Errors -cnotcontains 'responsibility-evidence-missing') {
+      throw "$($multilineLiteralCase.Name) multiline literal swallowed later rogue code ($($lexicalLineEnding.Name))"
+    }
+    Write-Output "PASS: $($multilineLiteralCase.Name) cannot swallow later rogue code ($($lexicalLineEnding.Name))"
+  }
+
+  $unterminatedMultilineSource = @"
+$lexicalOwnerMetadata
+class LexicalOwner {
+  String payload = """
+{
+danger()
+"@
+  $unterminatedMultiline = Invoke-LexicalSourceInventoryProbe "unterminated-multiline-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $unterminatedMultilineSource
+  if ($unterminatedMultiline.Errors -cnotcontains 'responsibility-evidence-missing') {
+    throw "unterminated multiline literal ambiguity must fail closed ($($lexicalLineEnding.Name))"
+  }
+  Write-Output "PASS: unterminated multiline literal ambiguity fails closed ($($lexicalLineEnding.Name))"
 }
 
 foreach ($bodyOnlyEdit in @(
   [pscustomobject]@{ Name = 'literal'; Old = 'return 1;'; New = 'return 2;' },
   [pscustomobject]@{ Name = 'control-flow'; Old = 'if (enabled) {'; New = 'if (enabled && allowed) {' },
   [pscustomobject]@{ Name = 'ordinary body'; Old = 'return cachedValue;'; New = 'return liveValue;' }
 )) {
   $bodyEditRoot = Join-Path ([IO.Path]::GetTempPath()) ('aitoolkit-owner-body-edit-' + [guid]::NewGuid().ToString('N'))
   try {
     [void](New-Item -ItemType Directory -Force -Path (Join-Path $bodyEditRoot 'src'))
@@ -1570,20 +1619,70 @@ Assert-FailsLike 'commented architecture controls cannot satisfy the visible tem
 
 Assert-FailsLike 'fenced activation controls cannot satisfy the visible template contract' {
   param($root)
   $path = Join-Path $root 'templates/migration/review-report.md'
   $text = [regex]::Replace((Get-Content -Raw -Encoding utf8 -LiteralPath $path), '\r?\n', "`n")
   $controls = [regex]::Match($text, '(?m)^- Production Activation Path Evidence: .+\n- Production Subscription Key: .+\n- Lifecycle Gate: .+$').Value
   if ($controls -eq '') { throw 'Scenario setup could not find activation controls' }
   [IO.File]::WriteAllText($path, $text.Replace($controls, "~~~text`n$controls`n~~~"), [Text.UTF8Encoding]::new($false))
 } 'production activation path|Evidence|Subscription|Lifecycle'
 
+Assert-FailsLike 'a four-space-indented overall verdict cannot satisfy the visible template control' {
+  param($root)
+  $path = Join-Path $root 'templates/migration/review-report.md'
+  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
+  Set-Content -Encoding utf8 -LiteralPath $path -Value $text.Replace('- Verdict: <Approve | Approve-with-fixes | Reject>', '    - Verdict: <Approve | Approve-with-fixes | Reject>')
+} 'overall Verdict|exactly once'
+
+Assert-FailsLike 'a tab-indented delivery adapter cannot satisfy the visible template control' {
+  param($root)
+  $path = Join-Path $root 'templates/migration/review-report.md'
+  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
+  $control = '- Delivery Adapter Kind: <migration-unit | task | story | package | phase | milestone | none>'
+  Set-Content -Encoding utf8 -LiteralPath $path -Value $text.Replace($control, "`t$control")
+} 'Delivery Adapter Kind|exactly once'
+
+Assert-FailsLike 'a four-space-indented selector control cannot satisfy the visible template contract' {
+  param($root)
+  $path = Join-Path $root 'templates/migration/review-report.md'
+  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
+  Set-Content -Encoding utf8 -LiteralPath $path -Value $text.Replace('- Evidence: <selector evidence>', '    - Evidence: <selector evidence>')
+} 'canonical selector|Evidence'
+
+Assert-FailsLike 'a four-space-indented required table cannot satisfy the visible template contract' {
+  param($root)
+  $path = Join-Path $root 'templates/migration/review-report.md'
+  $text = [regex]::Replace((Get-Content -Raw -Encoding utf8 -LiteralPath $path), '\r?\n', "`n")
+  $table = "| Run ID | Master Spec Reference | Master Spec ID | Master Spec Revision | Master Plan Reference | Master Plan ID | Master Plan Revision | Work Item ID |`n|---|---|---|---|---|---|---|---|`n| <RUN-*> | <master spec reference> | <SPEC-*> | <revision> | <master plan reference> | <PLAN-*> | <revision> | <WORK-*> |"
+  if (-not $text.Contains($table)) { throw 'Scenario setup could not find Master Scope Context table' }
+  $indentedTable = @($table -split "`n" | ForEach-Object { "    $_" }) -join "`n"
+  [IO.File]::WriteAllText($path, $text.Replace($table, $indentedTable), [Text.UTF8Encoding]::new($false))
+} 'Master Scope Context|table'
+
+Assert-FailsLike 'a tab-indented canonical heading cannot satisfy the visible template contract' {
+  param($root)
+  $path = Join-Path $root 'templates/migration/review-report.md'
+  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
+  Set-Content -Encoding utf8 -LiteralPath $path -Value $text.Replace('## Canonical Selector', "`t## Canonical Selector")
+} 'Canonical Selector|section|exactly once'
+
+Assert-Pass 'one-to-three-space Markdown indentation remains visible to template controls' {
+  param($root)
+  $path = Join-Path $root 'templates/migration/review-report.md'
+  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
+  $text = $text.Replace('## Canonical Selector', '   ## Canonical Selector')
+  $text = $text.Replace('- Evidence: <selector evidence>', '   - Evidence: <selector evidence>')
+  $text = $text.Replace('- Delivery Adapter Kind: <migration-unit | task | story | package | phase | milestone | none>', '   - Delivery Adapter Kind: <migration-unit | task | story | package | phase | milestone | none>')
+  $text = $text.Replace('- Verdict: <Approve | Approve-with-fixes | Reject>', '   - Verdict: <Approve | Approve-with-fixes | Reject>')
+  Set-Content -Encoding utf8 -LiteralPath $path -Value $text
+}
+
 Assert-FailsLike 'verdict values use the exact enum' {
   param($root)
   $path = Join-Path $root 'templates/migration/review-report.md'
   $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
   $text = $text.Replace('<PASS | BLOCKED | NOT_APPLICABLE>', '<PASS | BLOCKED | N/A>')
   Set-Content -Encoding utf8 -LiteralPath $path -Value $text
 } 'invalid verdict|Production Activation-path Verdict'
 
 Assert-FailsLike 'a blocked architecture verdict forces Reject independent of counts' {
   param($root)
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/validate-migration-framework.Tests.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/validate-migration-framework.Tests.ps1
index 4b73f3e..cecf5d7 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/validate-migration-framework.Tests.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/validate-migration-framework.Tests.ps1
@@ -458,20 +458,61 @@ if ($ResponsibilityConformanceOnly) {
         $exitCode = $LASTEXITCODE
       }
       finally {
         $ErrorActionPreference = $previousFixtureErrorActionPreference
       }
       [pscustomobject]@{ ExitCode = $exitCode; Output = ($output -join [Environment]::NewLine) }
     }
     Assert-True ($unreachableCoverageResult.ExitCode -eq 1) "Unreachable $($unreachableCoverageCase.Name) coverage registration must fail source integrity. Output: $($unreachableCoverageResult.Output)"
     Assert-Contains $unreachableCoverageResult.Output 'Responsibility source-integrity coverage missing: post-implementation queue advance' "Unreachable coverage registration: $($unreachableCoverageCase.Name)"
   }
+  foreach ($foreachCoverageCase in @(
+    [pscustomobject]@{ Name = 'explicit array expression'; Condition = "@('LF', 'CRLF')"; ExpectedActive = $true },
+    [pscustomobject]@{ Name = 'comma literal array'; Condition = "'LF', 'CRLF'"; ExpectedActive = $true },
+    [pscustomobject]@{ Name = 'integer literal range'; Condition = '1..2'; ExpectedActive = $true },
+    [pscustomobject]@{ Name = 'empty array expression'; Condition = '@()'; ExpectedActive = $false },
+    [pscustomobject]@{ Name = 'dynamic command array'; Condition = '@(Get-Nothing)'; ExpectedActive = $false },
+    [pscustomobject]@{ Name = 'dynamic subexpression array'; Condition = '@($(Get-Nothing))'; ExpectedActive = $false },
+    [pscustomobject]@{ Name = 'variable collection'; Condition = '$coverageCases'; ExpectedActive = $false }
+  )) {
+    $foreachCoverageResult = Invoke-IsolatedMutation -SourceRoot $testRoot -Mutation {
+      param($fixtureRoot)
+      $fixtureScenario = Join-Path $fixtureRoot 'tests/scenarios/scope-engine.Tests.ps1'
+      $fixtureText = [IO.File]::ReadAllText($fixtureScenario, [Text.Encoding]::UTF8)
+      $replacement = "foreach (`$coverageCase in $($foreachCoverageCase.Condition)) {`n  $coverageRegistration`n}"
+      $mutatedText = Replace-ExactOrFail $fixtureText $coverageRegistration $replacement "foreach coverage registration: $($foreachCoverageCase.Name)"
+      $parseTokens = $null
+      $parseErrors = $null
+      [void][Management.Automation.Language.Parser]::ParseInput($mutatedText, [ref]$parseTokens, [ref]$parseErrors)
+      if (@($parseErrors).Count -ne 0) { throw "Foreach coverage fixture must remain parse-valid: $($foreachCoverageCase.Name): $(@($parseErrors).Message -join '; ')" }
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
+    if ($foreachCoverageCase.ExpectedActive) {
+      Assert-True ($foreachCoverageResult.ExitCode -eq 0) "Provably nonempty $($foreachCoverageCase.Name) registration must satisfy source integrity. Output: $($foreachCoverageResult.Output)"
+      Assert-Contains $foreachCoverageResult.Output 'PASS: migration framework (SourceIntegrityOnly)' "Static foreach coverage registration: $($foreachCoverageCase.Name)"
+    }
+    else {
+      Assert-True ($foreachCoverageResult.ExitCode -eq 1) "Uncertain $($foreachCoverageCase.Name) registration must fail source integrity. Output: $($foreachCoverageResult.Output)"
+      Assert-Contains $foreachCoverageResult.Output 'Responsibility source-integrity coverage missing: post-implementation queue advance' "Uncertain foreach coverage registration: $($foreachCoverageCase.Name)"
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
index 9cea22f..8136725 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/validate-migration-framework.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/validate-migration-framework.ps1
@@ -9619,20 +9619,94 @@ if (-not [string]::IsNullOrWhiteSpace($ActivationSliceArtifactPath)) {
     $errors | ForEach-Object { Write-Output "FAIL: $_" }
     exit 1
   }
   Write-Output 'PASS: Activation Slice artifact'
   exit 0
 }
 elseif (-not [string]::IsNullOrWhiteSpace($PredecessorActivationSliceArtifactPath)) {
   $errors.Add('Activation Slice predecessor requires ActivationSliceArtifactPath')
 }
 
+function Test-ArcStaticCoverageLiteralValue([Management.Automation.Language.Ast]$Node) {
+  if ($null -eq $Node) { return $false }
+  if ($Node -is [Management.Automation.Language.PipelineAst]) {
+    return $Node.PipelineElements.Count -eq 1 -and
+      $Node.PipelineElements[0] -is [Management.Automation.Language.CommandExpressionAst] -and
+      (Test-ArcStaticCoverageLiteralValue $Node.PipelineElements[0].Expression)
+  }
+  if ($Node -is [Management.Automation.Language.CommandExpressionAst]) {
+    return Test-ArcStaticCoverageLiteralValue $Node.Expression
+  }
+  if (
+    $Node -is [Management.Automation.Language.StringConstantExpressionAst] -or
+    $Node -is [Management.Automation.Language.ConstantExpressionAst]
+  ) { return $true }
+  if ($Node -is [Management.Automation.Language.ExpandableStringExpressionAst]) {
+    return @($Node.NestedExpressions).Count -eq 0
+  }
+  if ($Node -is [Management.Automation.Language.ArrayLiteralAst]) {
+    if ($Node.Elements.Count -eq 0) { return $false }
+    foreach ($element in $Node.Elements) {
+      if (-not (Test-ArcStaticCoverageLiteralValue $element)) { return $false }
+    }
+    return $true
+  }
+  if ($Node -is [Management.Automation.Language.ArrayExpressionAst]) {
+    return Test-ArcStaticCoverageLiteralValue $Node.SubExpression
+  }
+  if ($Node -is [Management.Automation.Language.StatementBlockAst]) {
+    if ($Node.Statements.Count -eq 0) { return $false }
+    foreach ($statement in $Node.Statements) {
+      if (-not (Test-ArcStaticCoverageLiteralValue $statement)) { return $false }
+    }
+    return $true
+  }
+  if ($Node -is [Management.Automation.Language.ConvertExpressionAst]) {
+    return $Node.Type.TypeName.FullName -ceq 'pscustomobject' -and
+      (Test-ArcStaticCoverageLiteralValue $Node.Child)
+  }
+  if ($Node -is [Management.Automation.Language.HashtableAst]) {
+    foreach ($pair in $Node.KeyValuePairs) {
+      if (
+        -not (Test-ArcStaticCoverageLiteralValue $pair.Item1) -or
+        -not (Test-ArcStaticCoverageLiteralValue $pair.Item2)
+      ) { return $false }
+    }
+    return $true
+  }
+  if ($Node -is [Management.Automation.Language.ParenExpressionAst]) {
+    return Test-ArcStaticCoverageLiteralValue $Node.Pipeline
+  }
+  return $false
+}
+
+function Test-ArcStaticNonEmptyCoverageCollection([Management.Automation.Language.Ast]$Condition) {
+  if (
+    $Condition -isnot [Management.Automation.Language.PipelineAst] -or
+    $Condition.PipelineElements.Count -ne 1 -or
+    $Condition.PipelineElements[0] -isnot [Management.Automation.Language.CommandExpressionAst]
+  ) { return $false }
+  $expression = $Condition.PipelineElements[0].Expression
+  if ($expression -is [Management.Automation.Language.ArrayExpressionAst] -or $expression -is [Management.Automation.Language.ArrayLiteralAst]) {
+    return Test-ArcStaticCoverageLiteralValue $expression
+  }
+  if ($expression -is [Management.Automation.Language.BinaryExpressionAst] -and $expression.Operator -eq [Management.Automation.Language.TokenKind]::DotDot) {
+    return (
+      $expression.Left -is [Management.Automation.Language.ConstantExpressionAst] -and
+      $expression.Right -is [Management.Automation.Language.ConstantExpressionAst] -and
+      $expression.Left.Value -is [int] -and
+      $expression.Right.Value -is [int]
+    )
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
@@ -9703,27 +9777,21 @@ function Test-ResponsibilitySourceIntegrity {
           if ($ancestor -is [Management.Automation.Language.PipelineAst]) {
             $ancestor = $ancestor.Parent
             continue
           }
           if ($ancestor -is [Management.Automation.Language.StatementBlockAst]) {
             if ($ancestor.Parent -isnot [Management.Automation.Language.ForEachStatementAst]) { return $false }
             $ancestor = $ancestor.Parent
             continue
           }
           if ($ancestor -is [Management.Automation.Language.ForEachStatementAst]) {
-            $condition = $ancestor.Condition
-            $literalArrays = @($condition.FindAll({ param($conditionNode) $conditionNode -is [Management.Automation.Language.ArrayExpressionAst] }, $true))
-            if (
-              $literalArrays.Count -ne 1 -or
-              @($literalArrays[0].SubExpression.Statements).Count -eq 0 -or
-              @($condition.FindAll({ param($conditionNode) $conditionNode -is [Management.Automation.Language.VariableExpressionAst] }, $true)).Count -gt 0
-            ) { return $false }
+            if (-not (Test-ArcStaticNonEmptyCoverageCollection $ancestor.Condition)) { return $false }
             $ancestor = $ancestor.Parent
             continue
           }
           if ($ancestor -is [Management.Automation.Language.NamedBlockAst]) {
             $ancestor = $ancestor.Parent
             continue
           }
           if ($ancestor -is [Management.Automation.Language.ScriptBlockAst]) {
             return $null -eq $ancestor.Parent
           }
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1
index 963d0ed..2b9c330 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1
@@ -154,20 +154,35 @@ function Get-ArcVisibleMarkdownText {
       if ($line -cmatch $closingPattern) {
         $insideFence = $false
         $fenceCharacter = ''
         $fenceLength = 0
       }
       if ($line.Length -gt 0) { [void]$visibleText.Append([string]::new([char]' ', $line.Length)) }
       [void]$visibleText.Append($lineEnding)
       continue
     }
 
+    $indentColumns = 0
+    for ($indentIndex = 0; $indentIndex -lt $line.Length; $indentIndex++) {
+      if ($line[$indentIndex] -ceq ' ') { $indentColumns++; continue }
+      if ($line[$indentIndex] -ceq "`t") {
+        $indentColumns += 4 - ($indentColumns % 4)
+        continue
+      }
+      break
+    }
+    if (-not $insideHtmlComment -and -not $lineStartsInsideInlineCode -and $indentColumns -ge 4) {
+      if ($line.Length -gt 0) { [void]$visibleText.Append([string]::new([char]' ', $line.Length)) }
+      [void]$visibleText.Append($lineEnding)
+      continue
+    }
+
     $openingFence = if ($insideHtmlComment -or $lineStartsInsideInlineCode) { $null } else { Get-ArcMarkdownFenceOpening -Line $line }
     if ($null -ne $openingFence -and $openingFence.Success) {
       $insideFence = $true
       $fenceCharacter = [string]$openingFence.Groups['fence'].Value[0]
       $fenceLength = $openingFence.Groups['fence'].Value.Length
       if ($line.Length -gt 0) { [void]$visibleText.Append([string]::new([char]' ', $line.Length)) }
       [void]$visibleText.Append($lineEnding)
       continue
     }
 
@@ -1587,37 +1602,59 @@ function Test-ArcDeletedSourceEvidence {
   return $deletedOwners.ToArray()
 }
 
 function Get-ArcSourceLexicalLines {
   [CmdletBinding()]
   param([AllowEmptyString()][string]$SourceText)
 
   $lines = @($SourceText -split '\r\n|\n|\r')
   $result = [Collections.Generic.List[object]]::new()
   $blockCommentEnd = ''
-  foreach ($line in $lines) {
+  $blockCommentStart = -1
+  $multilineStringDelimiter = ''
+  $multilineStringStart = -1
+  for ($lineIndex = 0; $lineIndex -lt $lines.Count; $lineIndex++) {
+    $line = $lines[$lineIndex]
     $structural = [Text.StringBuilder]::new()
     $hasCode = $false
     $index = 0
     while ($index -lt $line.Length) {
+      if ($multilineStringDelimiter -ne '') {
+        $hasCode = $true
+        $literalEnd = $line.IndexOf($multilineStringDelimiter, $index, [StringComparison]::Ordinal)
+        if ($literalEnd -lt 0) { $index = $line.Length; continue }
+        $index = $literalEnd + $multilineStringDelimiter.Length
+        $multilineStringDelimiter = ''
+        $multilineStringStart = -1
+        continue
+      }
       if ($blockCommentEnd -ne '') {
         $commentEnd = $line.IndexOf($blockCommentEnd, $index, [StringComparison]::Ordinal)
         if ($commentEnd -lt 0) { $index = $line.Length; continue }
         $index = $commentEnd + $blockCommentEnd.Length
         $blockCommentEnd = ''
+        $blockCommentStart = -1
         continue
       }
 
       $remaining = $line.Substring($index)
-      if ($remaining.StartsWith('<!--', [StringComparison]::Ordinal)) { $blockCommentEnd = '-->'; $index += 4; continue }
-      if ($remaining.StartsWith('/*', [StringComparison]::Ordinal)) { $blockCommentEnd = '*/'; $index += 2; continue }
-      if ($remaining.StartsWith('<#', [StringComparison]::Ordinal)) { $blockCommentEnd = '#>'; $index += 2; continue }
+      $multilineOpening = [regex]::Match($remaining, '^(?<delimiter>"{3,}|''{3,})')
+      if ($multilineOpening.Success) {
+        $hasCode = $true
+        $multilineStringDelimiter = $multilineOpening.Groups['delimiter'].Value
+        $multilineStringStart = $lineIndex
+        $index += $multilineStringDelimiter.Length
+        continue
+      }
+      if ($remaining.StartsWith('<!--', [StringComparison]::Ordinal)) { $blockCommentEnd = '-->'; $blockCommentStart = $lineIndex; $index += 4; continue }
+      if ($remaining.StartsWith('/*', [StringComparison]::Ordinal)) { $blockCommentEnd = '*/'; $blockCommentStart = $lineIndex; $index += 2; continue }
+      if ($remaining.StartsWith('<#', [StringComparison]::Ordinal)) { $blockCommentEnd = '#>'; $blockCommentStart = $lineIndex; $index += 2; continue }
 
       $character = $line[$index]
       if ($remaining.StartsWith('//', [StringComparison]::Ordinal)) { break }
       if ($remaining.StartsWith('--', [StringComparison]::Ordinal) -and ($remaining.Length -eq 2 -or [char]::IsWhiteSpace($remaining[2]))) { break }
       if (-not $hasCode -and $character -eq ';' -and ($remaining.Length -eq 1 -or [char]::IsWhiteSpace($remaining[1]))) { break }
       if ($character -eq '#') {
         $preprocessor = [regex]::Match($remaining, '^#\s*(?:define|elif|else|endif|error|if|ifdef|ifndef|include|line|pragma|undef|warning)\b')
         if (-not $preprocessor.Success) { break }
       }
       if ($character -in @("'", '"', '`')) {
@@ -1648,22 +1685,26 @@ function Get-ArcSourceLexicalLines {
       }
 
       [void]$structural.Append($character)
       if (-not [char]::IsWhiteSpace($character)) { $hasCode = $true }
       $index++
     }
     $result.Add([pscustomobject]@{
       Raw = $line
       HasCode = $hasCode
       StructuralText = $structural.ToString()
+      Ambiguous = $false
     })
   }
+  foreach ($ambiguousStart in @($blockCommentStart, $multilineStringStart) | Where-Object { $_ -ge 0 }) {
+    for ($lineIndex = $ambiguousStart; $lineIndex -lt $result.Count; $lineIndex++) { $result[$lineIndex].Ambiguous = $true }
+  }
   return $result.ToArray()
 }
 
 function Test-ArcCommentOnlySourceLine {
   [CmdletBinding()]
   param([AllowEmptyString()][string]$Line)
 
   $lexicalLine = @(Get-ArcSourceLexicalLines -SourceText $Line) | Select-Object -First 1
   return $null -eq $lexicalLine -or -not $lexicalLine.HasCode
 }
@@ -1851,20 +1892,21 @@ function Get-ArcPinnedSourceInventory {
       if ($null -ne $pathRecord -and $pathRecord.BasePath -ne '') {
         $baseSourceText = Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('show', "${TaskBaseSha}:$($pathRecord.BasePath)")
       }
     }
     catch {
       $Errors.Add('responsibility-evidence-missing')
       continue
     }
     $sourceLines = @($sourceText -split '\r\n|\n|\r')
     $sourceLexicalLines = @(Get-ArcSourceLexicalLines -SourceText $sourceText)
+    if (@($sourceLexicalLines | Where-Object { $_.Ambiguous }).Count -gt 0) { $Errors.Add('responsibility-evidence-missing') }
     $responsibilityBlocks = @(Get-ArcResponsibilitySourceBlocks -SourceText $sourceText -LexicalLines $sourceLexicalLines)
     $coveredLineIndexes = [Collections.Generic.HashSet[int]]::new()
     foreach ($block in $responsibilityBlocks) {
       for ($coveredIndex = $block.Start; $coveredIndex -le $block.End; $coveredIndex++) { [void]$coveredLineIndexes.Add($coveredIndex) }
     }
     for ($lineIndex = 0; $lineIndex -lt $sourceLines.Count; $lineIndex++) {
       if (-not $coveredLineIndexes.Contains($lineIndex) -and $sourceLexicalLines[$lineIndex].HasCode) {
         $Errors.Add('responsibility-evidence-missing')
       }
     }

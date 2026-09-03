# Review package: 79462ad41c20c7529448be4e836fd95ac2ac49ad..75d208469933ce44f711ecf5fe970c7ee328d5bb

## Commits
75d2084 test: cover responsibility conformance workflow

## Files changed
 .../tests/scenarios/architecture-review.Tests.ps1  | 190 +++++++++++++++++++++
 .../tests/validate-migration-framework.Tests.ps1   |  44 +++++
 .../tests/validate-migration-framework.ps1         |  35 +++-
 .../validation/architecture-review.validation.ps1  |  25 +--
 .../responsibility-conformance.validation.ps1      |  99 +++++++++--
 5 files changed, 366 insertions(+), 27 deletions(-)

## Diff
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/architecture-review.Tests.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/architecture-review.Tests.ps1
index bcf366c..c8fc4fa 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/architecture-review.Tests.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/architecture-review.Tests.ps1
@@ -897,20 +897,142 @@ try {
   $sourceInventory = Get-ArcPinnedSourceInventory -SourceRoot $commentOnlyRoot -TaskBaseSha $taskBaseSha -FinalTreeSha $finalTreeSha -Errors $inventoryErrors
   if ($inventoryErrors.Count -ne 0 -or @($sourceInventory.ActiveOwners | Where-Object { $_.Id -ceq 'RESP-COMMENTED' }).Count -ne 1) {
     throw "blank/comment-only content beside a responsibility block should pass: $($inventoryErrors -join '; ')"
   }
   Write-Output 'PASS: blank/comment-only content beside a responsibility block remains valid'
 }
 finally {
   if (Test-Path -LiteralPath $commentOnlyRoot) { Remove-Item -LiteralPath $commentOnlyRoot -Recurse -Force }
 }
 
+function Invoke-LexicalSourceInventoryProbe(
+  [string]$Name,
+  [string]$NewLine,
+  [string]$SourceText
+) {
+  $probeRoot = Join-Path ([IO.Path]::GetTempPath()) ("aitoolkit-lexical-$Name-" + [guid]::NewGuid().ToString('N'))
+  try {
+    [void](New-Item -ItemType Directory -Force -Path (Join-Path $probeRoot 'src'))
+    Invoke-PinnedSourceGit $probeRoot @('init') | Out-Null
+    Invoke-PinnedSourceGit $probeRoot @('config', 'core.autocrlf', 'false') | Out-Null
+    Invoke-PinnedSourceGit $probeRoot @('config', 'user.email', 'fixtures@example.test') | Out-Null
+    Invoke-PinnedSourceGit $probeRoot @('config', 'user.name', 'AIToolkit fixture') | Out-Null
+    [IO.File]::WriteAllText((Join-Path $probeRoot 'README'), 'lexical base', [Text.UTF8Encoding]::new($false))
+    Invoke-PinnedSourceGit $probeRoot @('add', '--all') | Out-Null
+    Invoke-PinnedSourceGit $probeRoot @('commit', '-m', 'lexical base') | Out-Null
+    $taskBaseSha = Invoke-PinnedSourceGit $probeRoot @('rev-parse', 'HEAD')
+    $renderedSource = [regex]::Replace($SourceText, '\r\n|\r|\n', $NewLine)
+    [IO.File]::WriteAllText((Join-Path $probeRoot 'src/lexical.source'), $renderedSource, [Text.UTF8Encoding]::new($false))
+    Invoke-PinnedSourceGit $probeRoot @('add', '--all') | Out-Null
+    Invoke-PinnedSourceGit $probeRoot @('commit', '-m', "lexical $Name") | Out-Null
+    $finalTreeSha = Invoke-PinnedSourceGit $probeRoot @('rev-parse', 'HEAD')
+    $inventoryErrors = [Collections.Generic.List[string]]::new()
+    $sourceInventory = Get-ArcPinnedSourceInventory -SourceRoot $probeRoot -TaskBaseSha $taskBaseSha -FinalTreeSha $finalTreeSha -Errors $inventoryErrors
+    return [pscustomobject]@{
+      Errors = @($inventoryErrors)
+      OwnerCount = @($sourceInventory.ActiveOwners | Where-Object { $_.Id -ceq 'RESP-LEXICAL' }).Count
+    }
+  }
+  finally {
+    if (Test-Path -LiteralPath $probeRoot) { Remove-Item -LiteralPath $probeRoot -Recurse -Force }
+  }
+}
+
+$lexicalOwnerMetadata = @'
+@responsibility RESP-LEXICAL
+@owner-symbol LexicalOwner
+@public-symbol LexicalOwner
+@owned-capability CAP-LEXICAL
+@effect none
+@architecture-authority target-exemplar
+@co-location-policy feature-local
+@verification-owner VERIFY-OWNER-LEXICAL
+'@
+
+foreach ($lexicalLineEnding in @(
+  [pscustomobject]@{ Name = 'LF'; NewLine = "`n" },
+  [pscustomobject]@{ Name = 'CRLF'; NewLine = "`r`n" }
+)) {
+  $commentMatrixSource = @"
+# shell/python comment
+// C-family comment
+-- SQL comment
+; Lisp comment
+/* C-family block comment
+ * braces inside the comment are inert: { }
+ */
+<!-- markup block comment
+ braces inside the comment are inert: { }
+-->
+<# PowerShell block comment
+ braces inside the comment are inert: { }
+#>
+
+$lexicalOwnerMetadata
+class LexicalOwner { int run() { return 1; } }
+
+// trailing C-family comment
+"@
+  $commentMatrix = Invoke-LexicalSourceInventoryProbe "comments-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $commentMatrixSource
+  if ($commentMatrix.Errors.Count -ne 0 -or $commentMatrix.OwnerCount -ne 1) {
+    throw "legitimate language comment matrix ($($lexicalLineEnding.Name)) should remain valid: $($commentMatrix.Errors -join '; ')"
+  }
+  Write-Output "PASS: legitimate language comment matrix remains valid ($($lexicalLineEnding.Name))"
+
+  foreach ($roguePrefixCase in @(
+    [pscustomobject]@{ Name = 'semicolon-call'; Code = ';danger()' },
+    [pscustomobject]@{ Name = 'decrement'; Code = '--counter' },
+    [pscustomobject]@{ Name = 'pointer-assignment'; Code = '*ptr = value' },
+    [pscustomobject]@{ Name = 'inline-block-comment-then-call'; Code = '/* note */ danger()' }
+  )) {
+    $rogueSource = "$lexicalOwnerMetadata`nclass LexicalOwner { int run() { return 1; } }`n$($roguePrefixCase.Code)"
+    $rogueResult = Invoke-LexicalSourceInventoryProbe "$($roguePrefixCase.Name)-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $rogueSource
+    if ($rogueResult.Errors -cnotcontains 'responsibility-evidence-missing') {
+      throw "$($roguePrefixCase.Name) markerless executable content was incorrectly classified as comment-only ($($lexicalLineEnding.Name))"
+    }
+    Write-Output "PASS: $($roguePrefixCase.Name) remains unowned executable content ($($lexicalLineEnding.Name))"
+  }
+
+  $bracePositiveSource = @"
+$lexicalOwnerMetadata
+class LexicalOwner {
+  string closeBrace = "}";
+  string openBrace = '{';
+  // comment braces are inert: } {
+  /* block comment braces are inert: } { */
+  int run() {
+    return 1;
+  }
+}
+"@
+  $bracePositive = Invoke-LexicalSourceInventoryProbe "brace-positive-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $bracePositiveSource
+  if ($bracePositive.Errors.Count -ne 0 -or $bracePositive.OwnerCount -ne 1) {
+    throw "braces in strings/comments must not truncate a valid owner block ($($lexicalLineEnding.Name)): $($bracePositive.Errors -join '; ')"
+  }
+  Write-Output "PASS: braces in strings/comments preserve the valid owner block ($($lexicalLineEnding.Name))"
+
+  $braceRogueSource = @"
+$lexicalOwnerMetadata
+class LexicalOwner {
+  string openingBrace = "{";
+  /* an inert opening brace: { */
+  int run() { return 1; }
+}
+danger()
+"@
+  $braceRogue = Invoke-LexicalSourceInventoryProbe "brace-rogue-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $braceRogueSource
+  if ($braceRogue.Errors -cnotcontains 'responsibility-evidence-missing') {
+    throw "braces in strings/comments swallowed later rogue code ($($lexicalLineEnding.Name))"
+  }
+  Write-Output "PASS: braces in strings/comments cannot swallow later rogue code ($($lexicalLineEnding.Name))"
+}
+
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
@@ -1380,20 +1502,88 @@ Assert-FailsLike 'a commented delivery-adapter example cannot replace the visibl
 } 'Delivery Adapter Kind|exactly once'
 
 Assert-FailsLike 'a commented selected-unit policy cannot replace the visible template control' {
   param($root)
   $path = Join-Path $root 'templates/migration/review-report.md'
   $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
   $policy = 'Keep `Selected Migration Unit` only when `Delivery Adapter Kind` is `migration-unit`; otherwise omit it.'
   Set-Content -Encoding utf8 -LiteralPath $path -Value $text.Replace($policy, "<!-- $policy -->")
 } 'Selected Migration Unit|migration-unit'
 
+Assert-FailsLike 'a fenced Master Scope Context table cannot satisfy the visible template contract' {
+  param($root)
+  $path = Join-Path $root 'templates/migration/review-report.md'
+  $text = [regex]::Replace((Get-Content -Raw -Encoding utf8 -LiteralPath $path), '\r?\n', "`n")
+  $table = "| Run ID | Master Spec Reference | Master Spec ID | Master Spec Revision | Master Plan Reference | Master Plan ID | Master Plan Revision | Work Item ID |`n|---|---|---|---|---|---|---|---|`n| <RUN-*> | <master spec reference> | <SPEC-*> | <revision> | <master plan reference> | <PLAN-*> | <revision> | <WORK-*> |"
+  if (-not $text.Contains($table)) { throw 'Scenario setup could not find Master Scope Context table' }
+  $hiddenTable = '```markdown' + "`n" + $table + "`n" + '```'
+  [IO.File]::WriteAllText($path, $text.Replace($table, $hiddenTable), [Text.UTF8Encoding]::new($false))
+} 'Master Scope Context|table'
+
+Assert-FailsLike 'a commented Task Provenance table cannot satisfy the visible template contract' {
+  param($root)
+  $path = Join-Path $root 'templates/migration/review-report.md'
+  $text = [regex]::Replace((Get-Content -Raw -Encoding utf8 -LiteralPath $path), '\r?\n', "`n")
+  $table = [regex]::Match($text, '(?m)^\| Task / Unit \| Task-base SHA \| Final-tree SHA \| Source Artifact \|\n\|---\|---\|---\|---\|\n\| .+ \|$').Value
+  if ($table -eq '') { throw 'Scenario setup could not find Task Provenance table' }
+  [IO.File]::WriteAllText($path, $text.Replace($table, "<!--`n$table`n-->"), [Text.UTF8Encoding]::new($false))
+} 'Task Provenance|table'
+
+Assert-FailsLike 'a fenced Architecture Responsibility Handoff table cannot satisfy the visible template contract' {
+  param($root)
+  $path = Join-Path $root 'templates/migration/review-report.md'
+  $text = [regex]::Replace((Get-Content -Raw -Encoding utf8 -LiteralPath $path), '\r?\n', "`n")
+  $table = "| Responsibility Contract Version | Tree Conformance | Responsibility Conformance | Verification Ownership | Architecture Conformance State | Evidence References |`n|---|---|---|---|---|---|`n| 1 | <tree verdict> | <responsibility verdict> | <verification verdict> | <derived architecture state> | source-diff:<task-base SHA>..<final-tree SHA>#<WORK-*> |"
+  if (-not $text.Contains($table)) { throw 'Scenario setup could not find Architecture Responsibility Handoff table' }
+  [IO.File]::WriteAllText($path, $text.Replace($table, "~~~markdown`n$table`n~~~"), [Text.UTF8Encoding]::new($false))
+} 'Architecture Responsibility Handoff|table'
+
+Assert-FailsLike 'a commented Responsibility Review Evidence table cannot satisfy the visible template contract' {
+  param($root)
+  $path = Join-Path $root 'templates/migration/review-report.md'
+  $text = [regex]::Replace((Get-Content -Raw -Encoding utf8 -LiteralPath $path), '\r?\n', "`n")
+  $table = "| Responsibility ID | Source/Diff Evidence | Planned Public Symbols | Actual Public Symbols | Planned Effects | Actual Effects | Verdict |`n|---|---|---|---|---|---|---|"
+  if (-not $text.Contains($table)) { throw 'Scenario setup could not find Responsibility Review Evidence table' }
+  [IO.File]::WriteAllText($path, $text.Replace($table, "<!--`n$table`n-->"), [Text.UTF8Encoding]::new($false))
+} 'Responsibility Review Evidence|header|table'
+
+Assert-FailsLike 'a fenced selector evidence control cannot satisfy the visible template contract' {
+  param($root)
+  $path = Join-Path $root 'templates/migration/review-report.md'
+  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
+  $control = [regex]::Match($text, '(?m)^- Evidence: [^\r\n]+').Value
+  if ($control -eq '') { throw 'Scenario setup could not find selector evidence control' }
+  $hiddenControl = '```text' + "`n" + $control + "`n" + '```'
+  Set-Content -Encoding utf8 -LiteralPath $path -Value $text.Replace($control, $hiddenControl)
+} 'canonical selector|Evidence'
+
+Assert-FailsLike 'commented architecture controls cannot satisfy the visible template contract' {
+  param($root)
+  $path = Join-Path $root 'templates/migration/review-report.md'
+  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
+  foreach ($label in @('Conformance Matrix Reference', 'Exemplars', 'Actual File Tree vs Planned File Tree')) {
+    $control = [regex]::Match($text, '(?m)^- ' + [regex]::Escape($label) + ': .+$').Value
+    if ($control -eq '') { throw "Scenario setup could not find architecture control: $label" }
+    $text = $text.Replace($control, "<!-- $control -->")
+  }
+  Set-Content -Encoding utf8 -LiteralPath $path -Value $text
+} 'architecture conformance|Conformance Matrix|Exemplars|Actual File Tree'
+
+Assert-FailsLike 'fenced activation controls cannot satisfy the visible template contract' {
+  param($root)
+  $path = Join-Path $root 'templates/migration/review-report.md'
+  $text = [regex]::Replace((Get-Content -Raw -Encoding utf8 -LiteralPath $path), '\r?\n', "`n")
+  $controls = [regex]::Match($text, '(?m)^- Production Activation Path Evidence: .+\n- Production Subscription Key: .+\n- Lifecycle Gate: .+$').Value
+  if ($controls -eq '') { throw 'Scenario setup could not find activation controls' }
+  [IO.File]::WriteAllText($path, $text.Replace($controls, "~~~text`n$controls`n~~~"), [Text.UTF8Encoding]::new($false))
+} 'production activation path|Evidence|Subscription|Lifecycle'
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
index 15ef650..4b73f3e 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/validate-migration-framework.Tests.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/validate-migration-framework.Tests.ps1
@@ -414,20 +414,64 @@ if ($ResponsibilityConformanceOnly) {
     finally {
       $ErrorActionPreference = $previousFixtureErrorActionPreference
     }
     [pscustomobject]@{
       ExitCode = $exitCode
       Output = ($output -join [Environment]::NewLine)
     }
   }
   Assert-True ($commentedCoverageResult.ExitCode -eq 1) "Commented coverage registration must fail source integrity. Output: $($commentedCoverageResult.Output)"
   Assert-Contains $commentedCoverageResult.Output 'Responsibility source-integrity coverage missing: post-implementation queue advance' 'Commented coverage registration'
+  $coverageRegistration = "Assert-Equal `$responsibilityChainSelection.work_item_id '' 'No dependent item may be selected after a responsibility mismatch'"
+  foreach ($unreachableCoverageCase in @(
+    [pscustomobject]@{
+      Name = 'literal-false branch'
+      Replacement = "if (`$false) {`n  $coverageRegistration`n}"
+    }
+    [pscustomobject]@{
+      Name = 'uninvoked function'
+      Replacement = "function Register-InertCoverage {`n  $coverageRegistration`n}"
+    }
+    [pscustomobject]@{
+      Name = 'uninvoked scriptblock'
+      Replacement = "`$inertCoverageRegistration = {`n  $coverageRegistration`n}"
+    }
+    [pscustomobject]@{
+      Name = 'class method'
+      Replacement = "class InertCoverageRegistration {`n  [void] Register() {`n    `$responsibilityChainSelection = `$null`n    $coverageRegistration`n  }`n}"
+    }
+  )) {
+    $unreachableCoverageResult = Invoke-IsolatedMutation -SourceRoot $testRoot -Mutation {
+      param($fixtureRoot)
+      $fixtureScenario = Join-Path $fixtureRoot 'tests/scenarios/scope-engine.Tests.ps1'
+      $fixtureText = [IO.File]::ReadAllText($fixtureScenario, [Text.Encoding]::UTF8)
+      $mutatedText = Replace-ExactOrFail $fixtureText $coverageRegistration $unreachableCoverageCase.Replacement "unreachable coverage registration: $($unreachableCoverageCase.Name)"
+      $parseTokens = $null
+      $parseErrors = $null
+      [void][Management.Automation.Language.Parser]::ParseInput($mutatedText, [ref]$parseTokens, [ref]$parseErrors)
+      if (@($parseErrors).Count -ne 0) { throw "Unreachable coverage fixture must remain parse-valid: $($unreachableCoverageCase.Name): $(@($parseErrors).Message -join '; ')" }
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
+    Assert-True ($unreachableCoverageResult.ExitCode -eq 1) "Unreachable $($unreachableCoverageCase.Name) coverage registration must fail source integrity. Output: $($unreachableCoverageResult.Output)"
+    Assert-Contains $unreachableCoverageResult.Output 'Responsibility source-integrity coverage missing: post-implementation queue advance' "Unreachable coverage registration: $($unreachableCoverageCase.Name)"
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
index a45f7db..9cea22f 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/validate-migration-framework.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/validate-migration-framework.ps1
@@ -9693,27 +9693,50 @@ function Test-ResponsibilitySourceIntegrity {
     if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
     if (-not $activeCoverageCommandsByPath.ContainsKey($requirement.Path)) {
       $parseTokens = $null
       $parseErrors = $null
       $ast = [Management.Automation.Language.Parser]::ParseFile($path, [ref]$parseTokens, [ref]$parseErrors)
       $activeCoverageCommandsByPath[$requirement.Path] = @($ast.FindAll({
         param($node)
         if ($node -isnot [Management.Automation.Language.CommandAst]) { return $false }
         $ancestor = $node.Parent
         while ($null -ne $ancestor) {
-          if (
-            $ancestor -is [Management.Automation.Language.FunctionDefinitionAst] -or
-            $ancestor -is [Management.Automation.Language.ScriptBlockExpressionAst]
-          ) { return $false }
-          $ancestor = $ancestor.Parent
+          if ($ancestor -is [Management.Automation.Language.PipelineAst]) {
+            $ancestor = $ancestor.Parent
+            continue
+          }
+          if ($ancestor -is [Management.Automation.Language.StatementBlockAst]) {
+            if ($ancestor.Parent -isnot [Management.Automation.Language.ForEachStatementAst]) { return $false }
+            $ancestor = $ancestor.Parent
+            continue
+          }
+          if ($ancestor -is [Management.Automation.Language.ForEachStatementAst]) {
+            $condition = $ancestor.Condition
+            $literalArrays = @($condition.FindAll({ param($conditionNode) $conditionNode -is [Management.Automation.Language.ArrayExpressionAst] }, $true))
+            if (
+              $literalArrays.Count -ne 1 -or
+              @($literalArrays[0].SubExpression.Statements).Count -eq 0 -or
+              @($condition.FindAll({ param($conditionNode) $conditionNode -is [Management.Automation.Language.VariableExpressionAst] }, $true)).Count -gt 0
+            ) { return $false }
+            $ancestor = $ancestor.Parent
+            continue
+          }
+          if ($ancestor -is [Management.Automation.Language.NamedBlockAst]) {
+            $ancestor = $ancestor.Parent
+            continue
+          }
+          if ($ancestor -is [Management.Automation.Language.ScriptBlockAst]) {
+            return $null -eq $ancestor.Parent
+          }
+          return $false
         }
-        return $true
+        return $false
       }, $true))
     }
     $commandNameSeparator = $requirement.Token.IndexOf(' ', [StringComparison]::Ordinal)
     $expectedCommandName = if ($commandNameSeparator -gt 0) {
       $requirement.Token.Substring(0, $commandNameSeparator)
     }
     else { $requirement.Token }
     $hasActiveRegistration = @($activeCoverageCommandsByPath[$requirement.Path] | Where-Object {
       $_.GetCommandName() -ceq $expectedCommandName -and
         $_.Extent.Text.IndexOf($requirement.Token, [StringComparison]::Ordinal) -ge 0
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/architecture-review.validation.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/architecture-review.validation.ps1
index 6784c5b..f9fa8fd 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/architecture-review.validation.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/architecture-review.validation.ps1
@@ -211,21 +211,24 @@ function Test-ArchitectureReview([string]$Root, [string]$ContractText) {
     if ($cells.Count -eq 0 -or @($cells | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -gt 0) {
       $errors.Add("$Context contains an empty table cell")
       return @()
     }
     return $cells
   }
 
   $getStrictContractTable = {
     param([string]$Text, [string]$SectionName, [string[]]$Columns, [string]$Context)
     $body = & $getSection $Text $SectionName $Context
-    if ([string]::IsNullOrWhiteSpace($body)) { return $null }
+    if ([string]::IsNullOrWhiteSpace($body)) {
+      $errors.Add("$Context $SectionName must contain exactly one contractual table; found 0")
+      return $null
+    }
     $lines = @($body -split '\r?\n')
     $tables = [Collections.Generic.List[object]]::new()
     $index = 0
     while ($index -lt ($lines.Count - 1)) {
       if ($lines[$index] -cmatch '^\|.*\|$' -and $lines[$index + 1] -cmatch '^\|.*\|$') {
         $start = $index
         while ($index -lt $lines.Count -and $lines[$index] -cmatch '^\|.*\|$') { $index++ }
         $tables.Add([pscustomobject]@{ Lines = @($lines[$start..($index - 1)]) })
         continue
       }
@@ -312,40 +315,40 @@ function Test-ArchitectureReview([string]$Root, [string]$ContractText) {
     'missing lifecycle gate',
     'tests bypassing the production provider',
     'missing production subscription key',
     'planned/actual tree drift',
     'unapproved structural deviation',
     'Classify a missing production subscription key as `Critical`.',
     'at least `Major`',
     '`Critical` when activation, routing, or rendering fails'
   ) | ForEach-Object { Require-Token $findingsSection $_ 'AI Review mandatory architecture findings' }
 
-  & $assertHeadingOrder $reviewTemplate @(
+  & $assertHeadingOrder $visibleReviewTemplate @(
     'Master Scope Context',
     'Rule Resolution',
     'Canonical Selector',
     'Architecture Conformance',
     'Responsibility Review Evidence',
     'Production Activation Path',
     'Behavior, Failure Modes, Security, Performance, and Tests',
     'Critical',
     'Change Hygiene'
   ) 'Migration review report'
 
-  $masterContextTable = & $getStrictContractTable $reviewTemplate 'Master Scope Context' @(
+  $masterContextTable = & $getStrictContractTable $visibleReviewTemplate 'Master Scope Context' @(
     'Run ID', 'Master Spec Reference', 'Master Spec ID', 'Master Spec Revision',
     'Master Plan Reference', 'Master Plan ID', 'Master Plan Revision', 'Work Item ID'
   ) 'Migration review report'
-  $taskProvenanceTable = & $getStrictContractTable $reviewTemplate 'Task Provenance' @(
+  $taskProvenanceTable = & $getStrictContractTable $visibleReviewTemplate 'Task Provenance' @(
     'Task / Unit', 'Task-base SHA', 'Final-tree SHA', 'Source Artifact'
   ) 'Migration review report'
-  $responsibilityHandoffTable = & $getStrictContractTable $reviewTemplate 'Architecture Responsibility Handoff' @(
+  $responsibilityHandoffTable = & $getStrictContractTable $visibleReviewTemplate 'Architecture Responsibility Handoff' @(
     'Responsibility Contract Version', 'Tree Conformance', 'Responsibility Conformance',
     'Verification Ownership', 'Architecture Conformance State', 'Evidence References'
   ) 'Migration review report'
 
   $verdictValues = [ordered]@{}
   $verdictModes = [Collections.Generic.List[string]]::new()
   @(
     [pscustomobject]@{ Label = 'Architecture Conformance Verdict'; Schema = 'PASS | BLOCKED'; Allowed = @('PASS', 'BLOCKED') }
     [pscustomobject]@{ Label = 'Canonical Selector Verdict'; Schema = 'PASS | BLOCKED'; Allowed = @('PASS', 'BLOCKED') }
     [pscustomobject]@{ Label = 'Tree Conformance Verdict'; Schema = 'PASS | BLOCKED'; Allowed = @('PASS', 'BLOCKED') }
@@ -364,26 +367,26 @@ function Test-ArchitectureReview([string]$Root, [string]$ContractText) {
     }
     elseif ($value -in $_.Allowed) {
       $verdictModes.Add('rendered')
     }
     else {
       $errors.Add("Migration review report $($_.Label) has invalid verdict: $value")
     }
     $verdictValues[$_.Label] = $value
   }
 
-  $selectorSection = & $getSection $reviewTemplate 'Canonical Selector' 'Migration review report'
+  $selectorSection = & $getSection $visibleReviewTemplate 'Canonical Selector' 'Migration review report'
   Require-Token $selectorSection 'Evidence:' 'Migration review canonical selector'
-  $architectureSection = & $getSection $reviewTemplate 'Architecture Conformance' 'Migration review report'
+  $architectureSection = & $getSection $visibleReviewTemplate 'Architecture Conformance' 'Migration review report'
   @('Conformance Matrix Reference:', 'Exemplars:', 'Actual File Tree vs Planned File Tree:') |
     ForEach-Object { Require-Token $architectureSection $_ 'Migration review architecture conformance' }
-  $responsibilityReviewSection = & $getSection $reviewTemplate 'Responsibility Review Evidence' 'Migration review report'
+  $responsibilityReviewSection = & $getSection $visibleReviewTemplate 'Responsibility Review Evidence' 'Migration review report'
   $responsibilityReviewLines = @($responsibilityReviewSection -split '\r?\n' | Where-Object { $_ -cmatch '^\|.*\|$' })
   $responsibilityReviewColumns = @('Responsibility ID', 'Source/Diff Evidence', 'Planned Public Symbols', 'Actual Public Symbols', 'Planned Effects', 'Actual Effects', 'Verdict')
   if ($responsibilityReviewLines.Count -ne 2) {
     $errors.Add("Migration review Responsibility Review Evidence requires exactly one header and one delimiter row; found $($responsibilityReviewLines.Count)")
   }
   else {
     $actualReviewColumns = @(& $parseStrictTableRow $responsibilityReviewLines[0] 'Migration review Responsibility Review Evidence header')
     $reviewDelimiter = @(& $parseStrictTableRow $responsibilityReviewLines[1] 'Migration review Responsibility Review Evidence delimiter')
     if (($actualReviewColumns -join '|') -cne ($responsibilityReviewColumns -join '|')) {
       $errors.Add("Migration review Responsibility Review Evidence table columns must be exactly: $($responsibilityReviewColumns -join ' | ')")
@@ -424,21 +427,21 @@ function Test-ArchitectureReview([string]$Root, [string]$ContractText) {
       else {
         $sourceRoot = $sourceRootMatches[0].Groups['value'].Value.Trim()
         $taskBaseSha = $taskBaseMatches[0].Groups['value'].Value
         $finalTreeSha = $finalTreeMatches[0].Groups['value'].Value
         foreach ($error in @(Test-ResponsibilityReview -DesignText $designArtifact -ImplementationText $implementationArtifact -ReviewText $reviewArtifact -ContractText $responsibilityContract -SourceRoot $sourceRoot -TaskBaseSha $taskBaseSha -FinalTreeSha $finalTreeSha -ApprovedPlanText $approvedPlanArtifact)) {
           $errors.Add($error)
         }
       }
     }
   }
-  $activationSection = & $getSection $reviewTemplate 'Production Activation Path' 'Migration review report'
+  $activationSection = & $getSection $visibleReviewTemplate 'Production Activation Path' 'Migration review report'
   @('Production Activation Path Evidence:', 'Production Subscription Key:', 'Lifecycle Gate:') |
     ForEach-Object { Require-Token $activationSection $_ 'Migration review production activation path' }
   $behaviorSection = & $getSection $visibleReviewTemplate 'Behavior, Failure Modes, Security, Performance, and Tests' 'Migration review report'
   Require-Token $behaviorSection 'Behavior Analysis State:' 'Migration review behavior analysis'
   $behaviorMatches = [regex]::Matches($behaviorSection, '(?im)^[ \t]*-[ \t]*Behavior Analysis State:[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$')
   $behaviorState = ''
   if ($behaviorMatches.Count -ne 1) {
     $errors.Add("Migration review report Behavior Analysis State must appear exactly once; found $($behaviorMatches.Count)")
   }
   else {
@@ -481,21 +484,21 @@ function Test-ArchitectureReview([string]$Root, [string]$ContractText) {
     }
   }
 
   if (
     $visibleReviewTemplate -cnotmatch '(?s)Keep `Selected Migration Unit` only when `Delivery Adapter Kind` is `migration-unit`.*otherwise omit it\.' -and
     $visibleReviewTemplate -cnotmatch '(?s)Chỉ giữ `Selected Migration Unit` khi `Delivery Adapter Kind` là `migration-unit`.*otherwise omit it\.'
   ) {
     $errors.Add('Migration review report must keep Selected Migration Unit only for the migration-unit adapter and otherwise omit it')
   }
 
-  $selectedHeadings = @(& $getHeadings $reviewTemplate | Where-Object { $_.Level -eq 2 -and $_.Name -ceq 'Selected Migration Unit' })
+  $selectedHeadings = @(& $getHeadings $visibleReviewTemplate | Where-Object { $_.Level -eq 2 -and $_.Name -ceq 'Selected Migration Unit' })
   $adapterMatches = [regex]::Matches($visibleReviewTemplate, '(?im)^[ \t]*-[ \t]*Delivery Adapter Kind:[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$')
   $adapterKind = if ($adapterMatches.Count -eq 1) {
     $adapterMatches[0].Groups['value'].Value.Trim().Trim([char[]]@('<', '>', '`'))
   }
   else {
     $errors.Add("Migration review report Delivery Adapter Kind must appear exactly once; found $($adapterMatches.Count)")
     ''
   }
   $adapterKinds = @('migration-unit', 'task', 'story', 'package', 'phase', 'milestone', 'none')
   $adapterSchemaMode = $adapterKind -in @('kind', 'migration-unit | task | story | package | phase | milestone | none')
@@ -504,21 +507,21 @@ function Test-ArchitectureReview([string]$Root, [string]$ContractText) {
     $null -ne $masterContextTable -and
     @($masterContextTable.Row | Where-Object { $_ -match '^<.*>$' }).Count -gt 0
   ) {
     $errors.Add('Rendered migration review report requires concrete Master Scope Context values')
   }
   if ($adapterSchemaMode -or $adapterKind -ceq 'migration-unit') {
     if ($selectedHeadings.Count -ne 1) {
       $errors.Add("Migration review report requires exactly one Selected Migration Unit section for migration-unit/schema adapter; found $($selectedHeadings.Count)")
     }
     else {
-      $selectedTable = & $getStrictContractTable $reviewTemplate 'Selected Migration Unit' @(
+      $selectedTable = & $getStrictContractTable $visibleReviewTemplate 'Selected Migration Unit' @(
         'Migration Unit ID', 'Plan Reference', 'Approval Reference', 'Mode Constraint', 'Bootstrap Scope',
         'Foundation Baseline ID', 'Foundation Baseline Reference', 'Foundation Baseline Approval Reference',
         'Baseline Reference', 'Trace IDs'
       ) 'Migration review report'
       if ($adapterKind -ceq 'migration-unit' -and $null -ne $selectedTable -and @($selectedTable.Row | Where-Object { $_ -match '^<.*>$' }).Count -gt 0) {
         $errors.Add('Rendered migration-unit review report requires concrete canonical Selected Migration Unit values')
       }
     }
   }
   elseif ($adapterKind -in $adapterKinds) {
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1
index 2778efd..963d0ed 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1
@@ -1580,73 +1580,151 @@ function Test-ArcDeletedSourceEvidence {
       $anchors.Add($routeMatch.Groups['provider'].Value)
     }
     if ($removedDiff.IndexOf("@responsibility $($ownerMatch.Groups['id'].Value)", [StringComparison]::Ordinal) -lt 0 -or @($anchors | Select-Object -Unique | Where-Object { $removedDiff.IndexOf($_, [StringComparison]::Ordinal) -lt 0 }).Count -gt 0) {
       $Errors.Add('responsibility-evidence-missing')
     }
     $deletedOwners.Add($owner)
   }
   return $deletedOwners.ToArray()
 }
 
+function Get-ArcSourceLexicalLines {
+  [CmdletBinding()]
+  param([AllowEmptyString()][string]$SourceText)
+
+  $lines = @($SourceText -split '\r\n|\n|\r')
+  $result = [Collections.Generic.List[object]]::new()
+  $blockCommentEnd = ''
+  foreach ($line in $lines) {
+    $structural = [Text.StringBuilder]::new()
+    $hasCode = $false
+    $index = 0
+    while ($index -lt $line.Length) {
+      if ($blockCommentEnd -ne '') {
+        $commentEnd = $line.IndexOf($blockCommentEnd, $index, [StringComparison]::Ordinal)
+        if ($commentEnd -lt 0) { $index = $line.Length; continue }
+        $index = $commentEnd + $blockCommentEnd.Length
+        $blockCommentEnd = ''
+        continue
+      }
+
+      $remaining = $line.Substring($index)
+      if ($remaining.StartsWith('<!--', [StringComparison]::Ordinal)) { $blockCommentEnd = '-->'; $index += 4; continue }
+      if ($remaining.StartsWith('/*', [StringComparison]::Ordinal)) { $blockCommentEnd = '*/'; $index += 2; continue }
+      if ($remaining.StartsWith('<#', [StringComparison]::Ordinal)) { $blockCommentEnd = '#>'; $index += 2; continue }
+
+      $character = $line[$index]
+      if ($remaining.StartsWith('//', [StringComparison]::Ordinal)) { break }
+      if ($remaining.StartsWith('--', [StringComparison]::Ordinal) -and ($remaining.Length -eq 2 -or [char]::IsWhiteSpace($remaining[2]))) { break }
+      if (-not $hasCode -and $character -eq ';' -and ($remaining.Length -eq 1 -or [char]::IsWhiteSpace($remaining[1]))) { break }
+      if ($character -eq '#') {
+        $preprocessor = [regex]::Match($remaining, '^#\s*(?:define|elif|else|endif|error|if|ifdef|ifndef|include|line|pragma|undef|warning)\b')
+        if (-not $preprocessor.Success) { break }
+      }
+      if ($character -in @("'", '"', '`')) {
+        $hasCode = $true
+        $quote = $character
+        [void]$structural.Append(' ')
+        $index++
+        while ($index -lt $line.Length) {
+          $quotedCharacter = $line[$index]
+          [void]$structural.Append(' ')
+          if (($quotedCharacter -eq '\' -or $quotedCharacter -eq '`') -and $index + 1 -lt $line.Length) {
+            [void]$structural.Append(' ')
+            $index += 2
+            continue
+          }
+          if ($quotedCharacter -eq $quote) {
+            if ($index + 1 -lt $line.Length -and $line[$index + 1] -eq $quote) {
+              [void]$structural.Append(' ')
+              $index += 2
+              continue
+            }
+            $index++
+            break
+          }
+          $index++
+        }
+        continue
+      }
+
+      [void]$structural.Append($character)
+      if (-not [char]::IsWhiteSpace($character)) { $hasCode = $true }
+      $index++
+    }
+    $result.Add([pscustomobject]@{
+      Raw = $line
+      HasCode = $hasCode
+      StructuralText = $structural.ToString()
+    })
+  }
+  return $result.ToArray()
+}
+
 function Test-ArcCommentOnlySourceLine {
   [CmdletBinding()]
   param([AllowEmptyString()][string]$Line)
 
-  return [string]::IsNullOrWhiteSpace($Line) -or $Line -cmatch '^\s*(?:#|//|--|;|/\*|\*|\*/|<!--|-->|<#|#>)'
+  $lexicalLine = @(Get-ArcSourceLexicalLines -SourceText $Line) | Select-Object -First 1
+  return $null -eq $lexicalLine -or -not $lexicalLine.HasCode
 }
 
 function Get-ArcResponsibilitySourceBlocks {
   [CmdletBinding()]
-  param([AllowEmptyString()][string]$SourceText)
+  param(
+    [AllowEmptyString()][string]$SourceText,
+    [object[]]$LexicalLines = @()
+  )
 
-  $lines = @($SourceText -split '\r?\n')
+  $lines = @($SourceText -split '\r\n|\n|\r')
+  if ($LexicalLines.Count -ne $lines.Count) { $LexicalLines = @(Get-ArcSourceLexicalLines -SourceText $SourceText) }
   $markerIndexes = [Collections.Generic.List[int]]::new()
   for ($index = 0; $index -lt $lines.Count; $index++) {
     if ($lines[$index] -cmatch '^\s*@responsibility\s+RESP-[A-Z0-9]+(?:-[A-Z0-9]+)*\s*$') { $markerIndexes.Add($index) }
   }
   $blocks = [Collections.Generic.List[object]]::new()
   for ($markerOrdinal = 0; $markerOrdinal -lt $markerIndexes.Count; $markerOrdinal++) {
     $start = $markerIndexes[$markerOrdinal]
     $candidateEnd = if ($markerOrdinal + 1 -lt $markerIndexes.Count) { $markerIndexes[$markerOrdinal + 1] - 1 } else { $lines.Count - 1 }
     $metadataEnd = $start
     for ($index = $start + 1; $index -le $candidateEnd; $index++) {
       if ($lines[$index] -cmatch '^\s*@(owner-symbol|public-symbol|owned-capability|effect|architecture-authority|co-location-policy|verification-owner)\s+\S.*$') {
         $metadataEnd = $index
         continue
       }
       break
     }
 
     $bodyStart = -1
     for ($index = $metadataEnd + 1; $index -le $candidateEnd; $index++) {
-      if (-not (Test-ArcCommentOnlySourceLine -Line $lines[$index])) { $bodyStart = $index; break }
+      if ($LexicalLines[$index].HasCode) { $bodyStart = $index; break }
     }
     $end = $metadataEnd
     if ($bodyStart -ge 0) {
       $end = $bodyStart
       if ($lines[$bodyStart] -cnotmatch '^\s*route\s+[A-Za-z][A-Za-z0-9_.:-]*\s*->\s*[A-Za-z][A-Za-z0-9_.:-]*\s*$') {
         $opened = $false
         $braceDepth = 0
         for ($index = $bodyStart; $index -le $candidateEnd; $index++) {
-          $openCount = @([regex]::Matches($lines[$index], '\{')).Count
-          $closeCount = @([regex]::Matches($lines[$index], '\}')).Count
+          $openCount = @([regex]::Matches($LexicalLines[$index].StructuralText, '\{')).Count
+          $closeCount = @([regex]::Matches($LexicalLines[$index].StructuralText, '\}')).Count
           if ($openCount -gt 0) { $opened = $true }
           $braceDepth += $openCount - $closeCount
           if ($opened) {
             $end = $index
             if ($braceDepth -le 0) { break }
           }
         }
         if (-not $opened -and $lines[$bodyStart].TrimEnd().EndsWith(':')) {
           $baseIndent = $lines[$bodyStart].Length - $lines[$bodyStart].TrimStart().Length
           for ($index = $bodyStart + 1; $index -le $candidateEnd; $index++) {
-            if (Test-ArcCommentOnlySourceLine -Line $lines[$index]) { $end = $index; continue }
+            if (-not $LexicalLines[$index].HasCode) { $end = $index; continue }
             $indent = $lines[$index].Length - $lines[$index].TrimStart().Length
             if ($indent -le $baseIndent) { break }
             $end = $index
           }
         }
       }
     }
     $blocks.Add([pscustomobject]@{
       Id = ([regex]::Match($lines[$start], 'RESP-[A-Z0-9]+(?:-[A-Z0-9]+)*')).Value
       Start = $start
@@ -1771,28 +1849,29 @@ function Get-ArcPinnedSourceInventory {
       $sourceText = Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('show', "${FinalTreeSha}:$path")
       $diffText = Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('diff', '--unified=0', $TaskBaseSha, $FinalTreeSha, '--', $path)
       if ($null -ne $pathRecord -and $pathRecord.BasePath -ne '') {
         $baseSourceText = Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('show', "${TaskBaseSha}:$($pathRecord.BasePath)")
       }
     }
     catch {
       $Errors.Add('responsibility-evidence-missing')
       continue
     }
-    $sourceLines = @($sourceText -split '\r?\n')
-    $responsibilityBlocks = @(Get-ArcResponsibilitySourceBlocks -SourceText $sourceText)
+    $sourceLines = @($sourceText -split '\r\n|\n|\r')
+    $sourceLexicalLines = @(Get-ArcSourceLexicalLines -SourceText $sourceText)
+    $responsibilityBlocks = @(Get-ArcResponsibilitySourceBlocks -SourceText $sourceText -LexicalLines $sourceLexicalLines)
     $coveredLineIndexes = [Collections.Generic.HashSet[int]]::new()
     foreach ($block in $responsibilityBlocks) {
       for ($coveredIndex = $block.Start; $coveredIndex -le $block.End; $coveredIndex++) { [void]$coveredLineIndexes.Add($coveredIndex) }
     }
     for ($lineIndex = 0; $lineIndex -lt $sourceLines.Count; $lineIndex++) {
-      if (-not $coveredLineIndexes.Contains($lineIndex) -and -not (Test-ArcCommentOnlySourceLine -Line $sourceLines[$lineIndex])) {
+      if (-not $coveredLineIndexes.Contains($lineIndex) -and $sourceLexicalLines[$lineIndex].HasCode) {
         $Errors.Add('responsibility-evidence-missing')
       }
     }
 
     $current = $null
     foreach ($line in $sourceLines) {
       $ownerMatch = [regex]::Match($line, '^\s*@responsibility\s+(?<id>RESP-[A-Z0-9]+(?:-[A-Z0-9]+)*)\s*$')
       if ($ownerMatch.Success) {
         if ($null -ne $current) { $inventory.Add($current) }
         $current = [pscustomobject]@{

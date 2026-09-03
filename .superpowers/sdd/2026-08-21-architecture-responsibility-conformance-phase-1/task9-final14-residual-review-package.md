# Review package: 0f1174cce3df056dacbe049bdee575d977ef7ec7..08f172da2d9ba61305c613a07c1a8463b396797b

## Commits
08f172d test: cover responsibility conformance workflow

## Files changed
 .../tests/scenarios/architecture-review.Tests.ps1  | 188 +++++++++-
 .../tests/scenarios/flexible-scope-e2e.Tests.ps1   |  12 +-
 .../scenarios/responsibility-conformance.Tests.ps1 |  17 +
 .../scenarios/responsibility-handoff.Tests.ps1     |  72 ++++
 .../tests/scenarios/structural-gate.Tests.ps1      |  41 +++
 .../responsibility-conformance.validation.ps1      | 403 +++++++++++++++++++--
 .../validation/structural-gate.validation.ps1      |   5 +-
 7 files changed, 704 insertions(+), 34 deletions(-)

## Diff
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/architecture-review.Tests.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/architecture-review.Tests.ps1
index 2130896..69e9e17 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/architecture-review.Tests.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/architecture-review.Tests.ps1
@@ -228,34 +228,47 @@ responsibility_contract:
 ## Task Provenance
 | Task / Unit | Task-base SHA | Final-tree SHA | Source Artifact |
 |---|---|---|---|
 | WORK-ADMIN | <TASK-BASE-SHA> | <FINAL-TREE-SHA> | implementation-report.md |
 
 ## Architecture Responsibility Handoff
 | Responsibility Contract Version | Tree Conformance | Responsibility Conformance | Verification Ownership | Architecture Conformance State | Evidence References |
 |---|---|---|---|---|---|
 | 1 | PASS | PASS | PASS | PASS | source-diff:<TASK-BASE-SHA>..<FINAL-TREE-SHA>#WORK-ADMIN |
 
+## Rule Resolution
+- Rule Resolution Verdict: RESOLVED
+
+## Canonical Selector
+- Canonical Selector Verdict: PASS
+
 ## Architecture Conformance
 - Architecture Conformance Verdict: PASS
 
 ## Responsibility Review Evidence
 - Tree Conformance Verdict: PASS
 - Responsibility Conformance Verdict: PASS
 - Verification Ownership Verdict: PASS
 | Responsibility ID | Source/Diff Evidence | Planned Public Symbols | Actual Public Symbols | Planned Effects | Actual Effects | Verdict |
 |---|---|---|---|---|---|---|
 | RESP-ADMIN | source:<FINAL-TREE-SHA>:src/admin_route.source#AdminRoute; diff:<TASK-BASE-SHA>..<FINAL-TREE-SHA>:src/admin_route.source#AdminRoute; source:<FINAL-TREE-SHA>:src/admin_route.source#VERIFY-OWNER-ADMIN; diff:<TASK-BASE-SHA>..<FINAL-TREE-SHA>:src/admin_route.source#VERIFY-OWNER-ADMIN | AdminRoute | AdminRoute | route registration | route registration | PASS |
 
+## Production Activation Path
+- Production Activation-path Verdict: NOT_APPLICABLE
+
+## Behavior, Failure Modes, Security, Performance, and Tests
+- Behavior Analysis State: COMPLETE
+
 ## Critical
 | File:line | Issue | Proposed fix |
 |---|---|---|
+| none | none | none |
 
 ## Major
 | File:line | Issue | Proposed fix |
 |---|---|---|
 | none | none | none |
 
 ## Change Hygiene
 - Change Hygiene Verdict: PASS
 | Task / Unit | Scope Evidence | Formatter Evidence | Unrelated Diff | Severity | Task-base SHA | Final-tree SHA |
 |---|---|---|---|---|---|---|
@@ -876,20 +889,52 @@ function Remove-ImplementationChangeHygiene([string]$Root) {
   $path = Join-Path $Root 'artifacts/implementation-report.md'
   $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
   $updated = [regex]::Replace($text, '(?ms)^## Change Hygiene\r?\n.*?(?=^## Implementation Self-Attestation)', '')
   if ($updated -ceq $text) { throw 'Implementation Change Hygiene fixture removal failed' }
   Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
 }
 
 Assert-Pass 'complete architecture-first review and scope-aware KB contract' $null
 Assert-Pass 'independent review accepts implementation-bound provenance' $null $true
 
+foreach ($requiredExecutableGate in @(
+  [pscustomobject]@{ Name = 'Rule Resolution'; Line = '- Rule Resolution Verdict: RESOLVED' },
+  [pscustomobject]@{ Name = 'Canonical Selector'; Line = '- Canonical Selector Verdict: PASS' },
+  [pscustomobject]@{ Name = 'Production Activation'; Line = '- Production Activation-path Verdict: NOT_APPLICABLE' },
+  [pscustomobject]@{ Name = 'Behavior'; Line = '- Behavior Analysis State: COMPLETE' }
+)) {
+  Assert-FailsLike "independent executable review requires $($requiredExecutableGate.Name)" {
+    param($root)
+    $path = Join-Path $root 'artifacts/review-report.md'
+    $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
+    $updated = $text.Replace("$($requiredExecutableGate.Line)`r`n", '').Replace("$($requiredExecutableGate.Line)`n", '')
+    if ($updated -ceq $text) { throw "Missing $($requiredExecutableGate.Name) fixture mutation was a silent no-op" }
+    Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
+  } 'responsibility-evidence-missing' $true
+}
+
+foreach ($contradictoryExecutableGate in @(
+  [pscustomobject]@{ Name = 'Rule Resolution'; From = '- Rule Resolution Verdict: RESOLVED'; To = '- Rule Resolution Verdict: BLOCKED' },
+  [pscustomobject]@{ Name = 'Canonical Selector'; From = '- Canonical Selector Verdict: PASS'; To = '- Canonical Selector Verdict: BLOCKED' },
+  [pscustomobject]@{ Name = 'Production Activation'; From = '- Production Activation-path Verdict: NOT_APPLICABLE'; To = '- Production Activation-path Verdict: BLOCKED' },
+  [pscustomobject]@{ Name = 'Behavior'; From = '- Behavior Analysis State: COMPLETE'; To = '- Behavior Analysis State: NOT_RUN' }
+)) {
+  Assert-FailsLike "independent executable review derives conclusion from $($contradictoryExecutableGate.Name)" {
+    param($root)
+    $path = Join-Path $root 'artifacts/review-report.md'
+    $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
+    $updated = $text.Replace($contradictoryExecutableGate.From, $contradictoryExecutableGate.To)
+    if ($updated -ceq $text) { throw "Contradictory $($contradictoryExecutableGate.Name) fixture mutation was a silent no-op" }
+    Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
+  } 'responsibility-waiver-forbidden' $true
+}
+
 Assert-FailsLike 'non-PASS overall review conclusion is not executable despite PASS architecture verdicts' {
   param($root)
   $path = Join-Path $root 'artifacts/review-report.md'
   $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
   $updated = $text.Replace('- Verdict: Approve', '- Verdict: Reject')
   if ($updated -ceq $text) { throw 'Reject conclusion fixture replacement failed' }
   Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
 } 'responsibility-waiver-forbidden' $true
 
 Assert-FailsLike 'Critical-bearing review is not executable despite PASS architecture verdicts' {
@@ -1234,36 +1279,100 @@ class LexicalOwner {
   int run() { return 1; }
 }
 danger()
 "@
   $braceRogue = Invoke-LexicalSourceInventoryProbe "brace-rogue-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $braceRogueSource
   if ($braceRogue.Errors -cnotcontains 'responsibility-evidence-missing') {
     throw "braces in strings/comments swallowed later rogue code ($($lexicalLineEnding.Name))"
   }
   Write-Output "PASS: braces in strings/comments cannot swallow later rogue code ($($lexicalLineEnding.Name))"
 
+  $javascriptOwnerMetadata = @($lexicalOwnerMetadata -split '\r?\n' | Where-Object { $_ -ne '' } | ForEach-Object { "// arc:$_" }) -join "`n"
   $javascriptRegexRogueSource = @"
-$lexicalOwnerMetadata
+$javascriptOwnerMetadata
 class LexicalOwner {
   run(value) {
     const openingBrace = /{/g;
     return openingBrace.test(value);
   }
 }
 danger()
 "@
   $javascriptRegexRogue = Invoke-LexicalSourceInventoryProbe "javascript-regex-rogue-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $javascriptRegexRogueSource 'src/lexical.js'
   if ($javascriptRegexRogue.Errors -cnotcontains 'responsibility-evidence-missing') {
     throw "JavaScript regex-literal braces swallowed later rogue code ($($lexicalLineEnding.Name))"
   }
   Write-Output "PASS: JavaScript regex-literal braces are inert and later rogue code remains unowned ($($lexicalLineEnding.Name))"
 
+  $javascriptTemplateRogueSource = $javascriptOwnerMetadata + "`n" + @'
+class LexicalOwner {
+  run(value) {
+    const payload = `
+literal braces are inert: { }
+${value ? "{" : "}"}
+${value ? { nested: "}" }.nested : "{"}
+${`nested template interpolation: ${value}`}
+`;
+    return payload;
+  }
+}
+danger()
+'@
+  $javascriptTemplateRogue = Invoke-LexicalSourceInventoryProbe "javascript-template-rogue-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $javascriptTemplateRogueSource 'src/lexical.ts'
+  if ($javascriptTemplateRogue.Errors -cnotcontains 'responsibility-evidence-missing') {
+    throw "JavaScript multiline template-literal braces swallowed later rogue code ($($lexicalLineEnding.Name))"
+  }
+  Write-Output "PASS: JavaScript multiline template-literal braces are inert and later rogue code remains unowned ($($lexicalLineEnding.Name))"
+
+  $javascriptTemplateDivisionSource = $javascriptOwnerMetadata + "`n" + @'
+class LexicalOwner {
+  run() {
+    const ratio = `
+template operand
+` / 2;
+    return ratio;
+  }
+}
+'@
+  $javascriptTemplateDivision = Invoke-LexicalSourceInventoryProbe "javascript-template-division-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $javascriptTemplateDivisionSource 'src/lexical.ts'
+  if ($javascriptTemplateDivision.Errors.Count -ne 0 -or $javascriptTemplateDivision.OwnerCount -ne 1) {
+    throw "JavaScript division after a closed multiline template must remain valid ($($lexicalLineEnding.Name)): $($javascriptTemplateDivision.Errors -join '; ')"
+  }
+  Write-Output "PASS: JavaScript division after a closed multiline template remains valid ($($lexicalLineEnding.Name))"
+
+  $unterminatedJavascriptTemplateSource = $javascriptOwnerMetadata + "`n" + @'
+class LexicalOwner {
+  run() {
+    const payload = `unterminated template
+literal opening brace is inert: {
+  }
+}
+'@
+  $unterminatedJavascriptTemplate = Invoke-LexicalSourceInventoryProbe "unterminated-javascript-template-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $unterminatedJavascriptTemplateSource 'src/lexical.ts'
+  if ($unterminatedJavascriptTemplate.Errors -cnotcontains 'responsibility-evidence-missing') {
+    throw "unterminated JavaScript template-literal ambiguity must fail closed ($($lexicalLineEnding.Name))"
+  }
+  Write-Output "PASS: unterminated JavaScript template-literal ambiguity fails closed ($($lexicalLineEnding.Name))"
+
+  $unterminatedJavascriptInterpolationSource = $javascriptOwnerMetadata + "`n" + @'
+class LexicalOwner {
+  run(value) {
+    const payload = `unterminated interpolation: ${value
+  }
+}
+'@
+  $unterminatedJavascriptInterpolation = Invoke-LexicalSourceInventoryProbe "unterminated-javascript-interpolation-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $unterminatedJavascriptInterpolationSource 'src/lexical.ts'
+  if ($unterminatedJavascriptInterpolation.Errors -cnotcontains 'responsibility-evidence-missing') {
+    throw "unterminated JavaScript template interpolation must fail closed ($($lexicalLineEnding.Name))"
+  }
+  Write-Output "PASS: unterminated JavaScript template interpolation fails closed ($($lexicalLineEnding.Name))"
+
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
@@ -1550,20 +1659,97 @@ Assert-Pass 'Change Hygiene accepts a formatter command scoped to the exact chan
       $text.Replace('| AdminRoute | none | none |', '| AdminRoute | dart format src/admin_route.source | none |')
     }
     else {
       $text.Replace('| src/admin_route.source#AdminRoute | none | none | none |', '| src/admin_route.source#AdminRoute | dart format src/admin_route.source | none | none |')
     }
     if ($updated -ceq $text) { throw "Scoped formatter fixture replacement failed: $relativePath" }
     Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
   }
 } $true
 
+Assert-Pass 'Change Hygiene accepts legitimate formatter switches with the exact changed path' {
+  param($root)
+  foreach ($relativePath in @('artifacts/implementation-report.md', 'artifacts/review-report.md')) {
+    $path = Join-Path $root $relativePath
+    $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
+    $updated = if ($relativePath -ceq 'artifacts/implementation-report.md') {
+      $text.Replace('| AdminRoute | none | none |', '| AdminRoute | dart format --line-length 100 --output=none src/admin_route.source | none |')
+    }
+    else {
+      $text.Replace('| src/admin_route.source#AdminRoute | none | none | none |', '| src/admin_route.source#AdminRoute | dart format --line-length 100 --output=none src/admin_route.source | none | none |')
+    }
+    if ($updated -ceq $text) { throw "Switched formatter fixture replacement failed: $relativePath" }
+    Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
+  }
+} $true
+
+foreach ($subcommandFormatterCase in @(
+  [pscustomobject]@{ Name = 'direct ruff format'; Command = 'ruff format --line-length 100 src/admin_route.source' },
+  [pscustomobject]@{ Name = 'direct biome format'; Command = 'biome format --write src/admin_route.source' },
+  [pscustomobject]@{ Name = 'npx biome format'; Command = 'npx biome format --write src/admin_route.source' },
+  [pscustomobject]@{ Name = 'Python module ruff format'; Command = 'python -m ruff format --line-length 100 src/admin_route.source' }
+)) {
+  Assert-Pass "Change Hygiene accepts $($subcommandFormatterCase.Name) scoped to the exact changed path" {
+    param($root)
+    foreach ($relativePath in @('artifacts/implementation-report.md', 'artifacts/review-report.md')) {
+      $path = Join-Path $root $relativePath
+      $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
+      $updated = if ($relativePath -ceq 'artifacts/implementation-report.md') {
+        $text.Replace('| AdminRoute | none | none |', "| AdminRoute | $($subcommandFormatterCase.Command) | none |")
+      }
+      else {
+        $text.Replace('| src/admin_route.source#AdminRoute | none | none | none |', "| src/admin_route.source#AdminRoute | $($subcommandFormatterCase.Command) | none | none |")
+      }
+      if ($updated -ceq $text) { throw "Subcommand formatter fixture replacement failed: $relativePath" }
+      Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
+    }
+  } $true
+}
+
+foreach ($unsafeFormatterCase in @(
+  [pscustomobject]@{ Name = 'an unrelated file operand'; Command = 'dart format src/admin_route.source src/unrelated.source' },
+  [pscustomobject]@{ Name = 'a slash-dot alias operand'; Command = 'dart format src/admin_route.source src/./admin_route.source' },
+  [pscustomobject]@{ Name = 'a traversal alias operand'; Command = 'dart format src/admin_route.source src/../src/admin_route.source' },
+  [pscustomobject]@{ Name = 'a backslash alias operand'; Command = 'dart format src/admin_route.source src\admin_route.source' },
+  [pscustomobject]@{ Name = 'a repository subtree operand'; Command = 'dart format src/admin_route.source src' },
+  [pscustomobject]@{ Name = 'an extensionless unrelated operand after a boolean switch'; Command = 'prettier --write README src/admin_route.source' },
+  [pscustomobject]@{ Name = 'an extensionless operand named like a formatter subcommand'; Command = 'prettier format src/admin_route.source' },
+  [pscustomobject]@{ Name = 'an arbitrary non-formatter executable'; Command = 'echo src/admin_route.source' },
+  [pscustomobject]@{ Name = 'an unrelated path hidden in a switch value'; Command = 'dart format --files=src/unrelated.source src/admin_route.source' },
+  [pscustomobject]@{ Name = 'an extensionless path hidden in a switch value'; Command = 'dart format --files=README src/admin_route.source' },
+  [pscustomobject]@{ Name = 'an extensionless path hidden in a compound filepath switch'; Command = 'prettier --stdin-filepath=README src/admin_route.source' },
+  [pscustomobject]@{ Name = 'the exact target consumed by a separated filepath switch'; Command = 'prettier --stdin-filepath src/admin_route.source' },
+  [pscustomobject]@{ Name = 'the exact target consumed by a separated ignore-path switch'; Command = 'prettier --ignore-path src/admin_route.source' },
+  [pscustomobject]@{ Name = 'bare ruff without its format subcommand'; Command = 'ruff src/admin_route.source' },
+  [pscustomobject]@{ Name = 'bare biome without its format subcommand'; Command = 'biome src/admin_route.source' },
+  [pscustomobject]@{ Name = 'npx biome without its format subcommand'; Command = 'npx biome src/admin_route.source' },
+  [pscustomobject]@{ Name = 'Python module ruff without its format subcommand'; Command = 'python -m ruff src/admin_route.source' },
+  [pscustomobject]@{ Name = 'an invalid extensionless output operand'; Command = 'dart format --output README src/admin_route.source' },
+  [pscustomobject]@{ Name = 'a malformed unmatched quoted operand'; Command = 'dart format src/admin_route.source "' }
+)) {
+  Assert-FailsLike "Change Hygiene rejects $($unsafeFormatterCase.Name) beside the exact path" {
+    param($root)
+    foreach ($relativePath in @('artifacts/implementation-report.md', 'artifacts/review-report.md')) {
+      $path = Join-Path $root $relativePath
+      $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
+      $updated = if ($relativePath -ceq 'artifacts/implementation-report.md') {
+        $text.Replace('| AdminRoute | none | none |', "| AdminRoute | $($unsafeFormatterCase.Command) | none |")
+      }
+      else {
+        $text.Replace('| src/admin_route.source#AdminRoute | none | none | none |', "| src/admin_route.source#AdminRoute | $($unsafeFormatterCase.Command) | none | none |")
+      }
+      if ($updated -ceq $text) { throw "Unsafe formatter fixture replacement failed: $relativePath" }
+      Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
+    }
+  } 'change-hygiene-invalid' $true
+}
+
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
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/flexible-scope-e2e.Tests.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/flexible-scope-e2e.Tests.ps1
index 4539b0a..9ddb7c3 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/flexible-scope-e2e.Tests.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/flexible-scope-e2e.Tests.ps1
@@ -106,27 +106,37 @@ function New-ResponsibilityReviewEvidence([string]$Run,[string]$Name,[string]$Wo
   $baseline=if($unit-ceq'UNIT-A'){'baseline:a'}else{'baseline:b'}
   $templatePath=Join-Path $toolkitRoot 'templates/migration/review-report.md'
   $text=Get-Content -Raw -Encoding utf8 -LiteralPath $templatePath
   $replacements=[ordered]@{
     'status: <draft | approved>'='status: approved'
     'result: <complete | blocked>'='result: complete'
     'approval_source: <human | auto | auto-waive>'='approval_source: human'
     'produced_at: <yyyy-mm-dd>'='produced_at: 2026-08-20'
     '| <RUN-*> | <master spec reference> | <SPEC-*> | <revision> | <master plan reference> | <PLAN-*> | <revision> | <WORK-*> |'="| RUN-E2E-001 | rendered-scope-run/master-spec.md | SPEC-E2E-001 | 1 | rendered-scope-run/master-plan.md | PLAN-E2E-001 | 1 | $WorkItem |"
     '- Delivery Adapter Kind: <migration-unit | task | story | package | phase | milestone | none>'='- Delivery Adapter Kind: migration-unit'
+    '- Rule Resolution Verdict: <RESOLVED | BLOCKED>'='- Rule Resolution Verdict: RESOLVED'
+    '- Canonical Selector Verdict: <PASS | BLOCKED>'='- Canonical Selector Verdict: PASS'
+    '- Architecture Conformance Verdict: <PASS | BLOCKED>'='- Architecture Conformance Verdict: PASS'
+    '- Tree Conformance Verdict: <PASS | BLOCKED>'='- Tree Conformance Verdict: PASS'
+    '- Responsibility Conformance Verdict: <PASS | BLOCKED>'='- Responsibility Conformance Verdict: PASS'
+    '- Verification Ownership Verdict: <PASS | BLOCKED>'='- Verification Ownership Verdict: PASS'
+    '- Production Activation-path Verdict: <PASS | BLOCKED | NOT_APPLICABLE>'='- Production Activation-path Verdict: NOT_APPLICABLE'
+    '- Behavior Analysis State: <NOT_RUN | COMPLETE>'='- Behavior Analysis State: COMPLETE'
+    '- Change Hygiene Verdict: <PASS | BLOCKED>'='- Change Hygiene Verdict: PASS'
     '| <UNIT-* for migration-unit; WORK-* otherwise> | <task-base SHA> | <final-tree SHA> | <immediate predecessor artifact path> |'="| $unit | 1111111111111111111111111111111111111111 | 2222222222222222222222222222222222222222 | implementation-report.md |"
     '| 1 | <tree verdict> | <responsibility verdict> | <verification verdict> | <derived architecture state> | source-diff:<task-base SHA>..<final-tree SHA>#<WORK-*> |'="| 1 | PASS | PASS | PASS | PASS | source-diff:1111111111111111111111111111111111111111..2222222222222222222222222222222222222222#$WorkItem |"
   }
   foreach($token in $replacements.Keys){$updated=$text.Replace($token,$replacements[$token]);if($updated-ceq$text){throw "Migration review producer template is missing seam token: $token"};$text=$updated}
   $renderedConclusion=[regex]::Replace($text,'(?m)^- \*\*Critical count:\*\*[^\r\n]*\r?$','- **Critical count:** 0',1)
+  $renderedConclusion=[regex]::Replace($renderedConclusion,'(?m)^- \*\*Major count:\*\*[^\r\n]*\r?$','- **Major count:** 0',1)
   $renderedConclusion=[regex]::Replace($renderedConclusion,'(?m)^- Verdict: <Approve \| Approve-with-fixes \| Reject>[ \t]*\r?$','- Verdict: Approve',1)
-  if($renderedConclusion-ceq$text-or@([regex]::Matches($renderedConclusion,'(?m)^- \*\*Critical count:\*\* 0\r?$')).Count-ne1-or@([regex]::Matches($renderedConclusion,'(?m)^- Verdict: Approve\r?$')).Count-ne1){throw 'Migration review producer template is missing executable conclusion seams'}
+  if($renderedConclusion-ceq$text-or@([regex]::Matches($renderedConclusion,'(?m)^- \*\*Critical count:\*\* 0\r?$')).Count-ne1-or@([regex]::Matches($renderedConclusion,'(?m)^- \*\*Major count:\*\* 0\r?$')).Count-ne1-or@([regex]::Matches($renderedConclusion,'(?m)^- Verdict: Approve\r?$')).Count-ne1){throw 'Migration review producer template is missing executable conclusion seams'}
   $text=$renderedConclusion
   $renderedSelectedUnit=[regex]::Replace($text,'(?m)^\| <UNIT-001> \|.*$',"| $unit | legacy-plan.md@7 | approval:HUMAN-$unit | $ModeConstraint | not-required | not-applicable | not-applicable | not-applicable | $baseline | TRACE-001 |",1)
   if($renderedSelectedUnit-ceq$text){throw 'Migration review producer template is missing selected-unit row seam'}
   $text=$renderedSelectedUnit
   Write-Utf8 $path $text
   Get-ImmutableReference $Run $Name
 }
 function New-ResponsibilityDownstreamArtifact([string]$Run,[string]$Name,[string]$WorkItem,[string]$StepId,[string]$SourceArtifact,[string]$ModeConstraint='incremental/preserve-existing'){
   $path=Join-Path $Run $Name
   $unit=if($WorkItem-ceq'WORK-E2E-A'){'UNIT-A'}else{'UNIT-B'}
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1
index 6e34769..2ce758b 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1
@@ -1385,52 +1385,69 @@ responsibility_contract:
 | Task / Unit | Task-base SHA | Final-tree SHA | Source Artifact |
 |---|---|---|---|
 | WORK-ADMIN-LOCK | $($PinnedSource.TaskBaseSha) | $($PinnedSource.FinalTreeSha) | implementation-report.md |
 
 ## Architecture Responsibility Handoff
 
 | Responsibility Contract Version | Tree Conformance | Responsibility Conformance | Verification Ownership | Architecture Conformance State | Evidence References |
 |---|---|---|---|---|---|
 | 1 | $TreeState | $ResponsibilityState | $VerificationState | $ArchitectureState | source-diff:$($PinnedSource.TaskBaseSha)..$($PinnedSource.FinalTreeSha)#WORK-ADMIN-LOCK |
 
+## Rule Resolution
+
+- Rule Resolution Verdict: RESOLVED
+
+## Canonical Selector
+
+- Canonical Selector Verdict: PASS
+
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
 
+## Production Activation Path
+
+- Production Activation-path Verdict: NOT_APPLICABLE
+
+## Behavior, Failure Modes, Security, Performance, and Tests
+
+- Behavior Analysis State: COMPLETE
+
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
+| none | none | none |
 
 ## Major
 
 | File:line | Issue | Proposed fix |
 |---|---|---|
 | none | none | none |
 
 ## Conclusion
 
 - Critical count: 0
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-handoff.Tests.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-handoff.Tests.ps1
index 24c0930..697eed3 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-handoff.Tests.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-handoff.Tests.ps1
@@ -73,35 +73,71 @@ function New-HandoffArtifact {
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
+    [int]$MajorCount = 0,
+    [string]$RuleResolution = 'RESOLVED',
+    [string]$CanonicalSelector = 'PASS',
+    [string]$ProductionActivation = 'NOT_APPLICABLE',
+    [string]$BehaviorState = 'COMPLETE',
+    [string]$ChangeHygiene = 'PASS',
     [string]$Waiver = ''
   )
 
   if ($TaskUnit -eq '') { $TaskUnit = if ($AdapterKind -ceq 'migration-unit') { 'UNIT-ADMIN-LOCK' } else { $WorkItemId } }
   if ($Evidence -eq '') { $Evidence = "source-diff:$TaskBaseSha..$FinalTreeSha#$WorkItemId" }
   $waiverText = if ($Waiver -eq '') { '' } else { "`n$Waiver" }
   $approvalText = if ($ApprovalSource -eq '') { '' } else { "approval_source: $ApprovalSource`n" }
   $reviewConclusionText = if ($StepId -ceq '11-ai-review') {
 @"
+## Rule Resolution
+- Rule Resolution Verdict: $RuleResolution
+
+## Canonical Selector
+- Canonical Selector Verdict: $CanonicalSelector
+
+## Architecture Conformance
+- Architecture Conformance Verdict: $Architecture
+
+## Responsibility Review Evidence
+- Tree Conformance Verdict: $Tree
+- Responsibility Conformance Verdict: $Responsibility
+- Verification Ownership Verdict: $Verification
+
+## Production Activation Path
+- Production Activation-path Verdict: $ProductionActivation
+
+## Behavior, Failure Modes, Security, Performance, and Tests
+- Behavior Analysis State: $BehaviorState
+
 ## Critical
 | File:line | Issue | Proposed fix |
 |---|---|---|
+| none | none | none |
+
+## Major
+| File:line | Issue | Proposed fix |
+|---|---|---|
+| none | none | none |
+
+## Change Hygiene
+- Change Hygiene Verdict: $ChangeHygiene
 
 ## Conclusion
 - Critical count: $CriticalCount
+- Major count: $MajorCount
 - Verdict: $ReviewVerdict
 
 "@
   } else { '' }
   $selectedUnitText = if ($AdapterKind -eq 'migration-unit' -and -not $OmitSelectedMigrationUnit) {
 @"
 ## Selected Migration Unit
 
 | Migration Unit ID | Plan Reference | Approval Reference | Mode Constraint | Bootstrap Scope | Foundation Baseline ID | Foundation Baseline Reference | Foundation Baseline Approval Reference | Baseline Reference | Trace IDs |
 |---|---|---|---|---|---|---|---|---|---|
@@ -227,30 +263,42 @@ function New-ProducerReviewArtifact {
   $text = Get-Content -Raw -Encoding utf8 -LiteralPath $reviewTemplatePath
   $replacements = [ordered]@{
     'status: <draft | approved>' = 'status: approved'
     'result: <complete | blocked>' = 'result: complete'
     'approval_source: <human | auto | auto-waive>' = 'approval_source: human'
     'produced_at: <yyyy-mm-dd>' = 'produced_at: 2026-08-20'
     '| <RUN-*> | <master spec reference> | <SPEC-*> | <revision> | <master plan reference> | <PLAN-*> | <revision> | <WORK-*> |' = "| RUN-HANDOFF-001 | master-spec.md | SPEC-HANDOFF-001 | 1 | master-plan.md | PLAN-HANDOFF-001 | 1 | $WorkItemId |"
     '- Delivery Adapter Kind: <migration-unit | task | story | package | phase | milestone | none>' = '- Delivery Adapter Kind: migration-unit'
     '| <UNIT-* for migration-unit; WORK-* otherwise> | <task-base SHA> | <final-tree SHA> | <immediate predecessor artifact path> |' = "| $TaskUnit | 1111111111111111111111111111111111111111 | 2222222222222222222222222222222222222222 | implementation-report.md |"
     '| 1 | <tree verdict> | <responsibility verdict> | <verification verdict> | <derived architecture state> | source-diff:<task-base SHA>..<final-tree SHA>#<WORK-*> |' = "| 1 | PASS | PASS | PASS | PASS | source-diff:1111111111111111111111111111111111111111..2222222222222222222222222222222222222222#$WorkItemId |"
+    '- Rule Resolution Verdict: <RESOLVED | BLOCKED>' = '- Rule Resolution Verdict: RESOLVED'
+    '- Canonical Selector Verdict: <PASS | BLOCKED>' = '- Canonical Selector Verdict: PASS'
+    '- Architecture Conformance Verdict: <PASS | BLOCKED>' = '- Architecture Conformance Verdict: PASS'
+    '- Tree Conformance Verdict: <PASS | BLOCKED>' = '- Tree Conformance Verdict: PASS'
+    '- Responsibility Conformance Verdict: <PASS | BLOCKED>' = '- Responsibility Conformance Verdict: PASS'
+    '- Verification Ownership Verdict: <PASS | BLOCKED>' = '- Verification Ownership Verdict: PASS'
+    '- Production Activation-path Verdict: <PASS | BLOCKED | NOT_APPLICABLE>' = '- Production Activation-path Verdict: NOT_APPLICABLE'
+    '- Behavior Analysis State: <NOT_RUN | COMPLETE>' = '- Behavior Analysis State: COMPLETE'
+    '- Change Hygiene Verdict: <PASS | BLOCKED>' = '- Change Hygiene Verdict: PASS'
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
+  $renderedMajorCount = [regex]::Replace($text, '(?m)^- \*\*Major count:\*\*[^\r\n]*\r?$', '- **Major count:** 0', 1)
+  if ($renderedMajorCount -ceq $text) { throw 'Migration review producer template is missing Major count seam' }
+  $text = $renderedMajorCount
   $renderedSelectedUnit = [regex]::Replace($text, '(?m)^\| <UNIT-001> \|.*$', '| UNIT-ADMIN-LOCK | 08-migration-plan.md@1 | approval:UNIT-ADMIN-LOCK | incremental/preserve-existing | not-required | not-applicable | not-applicable | not-applicable | baseline.md#BASE-ADMIN | REQ-001 |', 1)
   if ($renderedSelectedUnit -ceq $text) { throw 'Migration review producer template is missing selected-unit row seam' }
   $text = $renderedSelectedUnit
   return $text
 }
 
 function New-ProducerKnowledgeBaseArtifact {
   param(
     [ValidateSet('migration-unit','task','none')][string]$AdapterKind = 'migration-unit',
     [string]$WorkItemId = 'WORK-ADMIN-LOCK',
@@ -487,20 +535,44 @@ Assert-HandoffDiagnosticsExactly 'producer-rendered terminal Knowledge Base reje
 Assert-HandoffDiagnosticsExactly 'producer-rendered terminal Knowledge Base cannot lose Master Scope Context' $regression ($producerKnowledgeBase -replace '(?ms)^## Master Scope Context.*?(?=^## )', '') @('ARC-CONTRACT-MISSING-TABLE: Master Scope Context')
 Assert-HandoffRejected 'producer-rendered terminal Knowledge Base cannot mutate delivery adapter kind' $regression ($producerKnowledgeBase.Replace('- Delivery Adapter Kind: migration-unit', '- Delivery Adapter Kind: task')) 'responsibility-evidence-missing'
 Assert-HandoffRejected 'producer-rendered terminal Knowledge Base cannot bind foreign scope' $regression ($producerKnowledgeBase.Replace('| RUN-HANDOFF-001 | master-spec.md | SPEC-HANDOFF-001 | 1 | master-plan.md | PLAN-HANDOFF-001 | 1 | WORK-ADMIN-LOCK |', '| RUN-HANDOFF-OTHER | master-spec.md | SPEC-HANDOFF-001 | 1 | master-plan.md | PLAN-HANDOFF-001 | 1 | WORK-ADMIN-LOCK |')) 'responsibility-evidence-missing'
 Assert-HandoffDiagnosticsExactly 'producer-rendered terminal Knowledge Base cannot lose task provenance' $regression ($producerKnowledgeBase -replace '(?ms)^## Task Provenance.*?(?=^## )', '') @('ARC-CONTRACT-MISSING-TABLE: Task Provenance')
 Assert-HandoffRejected 'producer-rendered terminal Knowledge Base cannot mutate task provenance' $regression ($producerKnowledgeBase.Replace('| UNIT-ADMIN-LOCK | 1111111111111111111111111111111111111111 | 2222222222222222222222222222222222222222 | 14-regression-report.md |', '| UNIT-ADMIN-LOCK | 1111111111111111111111111111111111111111 | 3333333333333333333333333333333333333333 | 14-regression-report.md |')) 'responsibility-evidence-missing'
 Assert-HandoffRejected 'draft review cannot seed verification' (New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -Status 'draft') $verification 'responsibility-evidence-missing'
 Assert-HandoffRejected 'blocked review cannot seed verification' (New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -Result 'blocked') $verification 'responsibility-evidence-missing'
 Assert-HandoffRejected 'review without approval source cannot seed verification' (New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -ApprovalSource '') $verification 'responsibility-evidence-missing'
 Assert-HandoffRejected 'non-human review cannot seed verification' (New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -ApprovalSource 'auto') $verification 'responsibility-evidence-missing'
 Assert-HandoffRejected 'Reject review conclusion cannot seed verification despite PASS architecture handoff' (New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -ReviewVerdict 'Reject') $verification 'responsibility-waiver-forbidden'
+foreach ($requiredReviewControl in @(
+  '- Rule Resolution Verdict: RESOLVED',
+  '- Canonical Selector Verdict: PASS',
+  '- Production Activation-path Verdict: NOT_APPLICABLE',
+  '- Behavior Analysis State: COMPLETE',
+  '- Change Hygiene Verdict: PASS',
+  '- Major count: 0'
+)) {
+  $missingReviewControl = $review.Replace("$requiredReviewControl`r`n", '').Replace("$requiredReviewControl`n", '')
+  if ($missingReviewControl -ceq $review) { throw "Missing executable-review control mutation was a silent no-op: $requiredReviewControl" }
+  Assert-HandoffRejected "review missing executable control cannot seed verification: $requiredReviewControl" $missingReviewControl $verification 'responsibility-evidence-missing'
+}
+Assert-HandoffRejected 'review with BLOCKED selector and Approve conclusion cannot seed verification' (New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -CanonicalSelector 'BLOCKED') $verification 'responsibility-waiver-forbidden'
+Assert-HandoffRejected 'review with NOT_RUN behavior after passing prebehavior gates cannot seed verification' (New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -BehaviorState 'NOT_RUN') $verification 'responsibility-waiver-forbidden'
+Assert-HandoffRejected 'review with a positive Major count and Approve conclusion cannot seed verification' (New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -MajorCount 1) $verification 'responsibility-waiver-forbidden'
+$majorFindingReview = New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -MajorCount 1
+$majorFindingBlock = Get-ArtifactSectionBlock -Text $majorFindingReview -Heading 'Major'
+$renderedMajorFindingBlock = $majorFindingBlock.Replace('| none | none | none |', '| src/admin_route.source:1 | MAJOR-REVIEW-001: review issue | Resolve before approval |')
+if ($renderedMajorFindingBlock -ceq $majorFindingBlock) { throw 'Rendered Major finding mutation was a silent no-op' }
+$majorFindingReview = $majorFindingReview.Replace($majorFindingBlock, $renderedMajorFindingBlock)
+Assert-HandoffRejected 'review with an exactly counted Major finding derives Approve-with-fixes instead of claimed Approve' $majorFindingReview $verification 'responsibility-waiver-forbidden'
+$contradictoryVisibleReview = $review.Replace('- Architecture Conformance Verdict: PASS', '- Architecture Conformance Verdict: BLOCKED')
+if ($contradictoryVisibleReview -ceq $review) { throw 'Contradictory visible review verdict mutation was a silent no-op' }
+Assert-HandoffRejected 'review handoff cannot contradict its visible architecture verdict' $contradictoryVisibleReview $verification 'responsibility-waiver-forbidden'
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
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/structural-gate.Tests.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/structural-gate.Tests.ps1
index 81d3830..0577473 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/structural-gate.Tests.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/structural-gate.Tests.ps1
@@ -1442,20 +1442,61 @@ try {
   foreach ($semanticDecoy in @(
     [pscustomobject]@{ Name = 'fenced'; Text = "~~~markdown`n## Work Item Changed Files`n| decoy |`n|---|`n| ignored |`n~~~" },
     [pscustomobject]@{ Name = 'commented'; Text = "<!--`n## Work Item Changed Files`n| decoy |`n|---|`n| ignored |`n-->" },
     [pscustomobject]@{ Name = 'indented'; Text = "    ## Work Item Changed Files`n    | decoy |`n    |---|`n    | ignored |" }
   )) {
     $root = New-Case "semantic-markdown-$($semanticDecoy.Name)"
     Write-Report $root ((Get-ValidReport) + "`n$($semanticDecoy.Text)`n")
     Assert-Accepted "$($semanticDecoy.Name) Markdown examples do not inflate structural authority" $root
   }
 
+  foreach ($semanticLineEnding in @(
+    [pscustomobject]@{ Name = 'LF'; NewLine = "`n" },
+    [pscustomobject]@{ Name = 'CRLF'; NewLine = "`r`n" }
+  )) {
+    foreach ($selectedUnitDecoy in @(
+      [pscustomobject]@{ Name = 'fenced'; Text = "~~~markdown`n## Selected Migration Unit`n| Migration Unit ID |`n|---|`n| UNIT-DECOY-001 |`n~~~" },
+      [pscustomobject]@{ Name = 'commented'; Text = "<!--`n## Selected Migration Unit`n| Migration Unit ID |`n|---|`n| UNIT-DECOY-001 |`n-->" },
+      [pscustomobject]@{ Name = 'indented'; Text = "    ## Selected Migration Unit`n    | Migration Unit ID |`n    |---|`n    | UNIT-DECOY-001 |" }
+    )) {
+      $renderedDecoy = [regex]::Replace($selectedUnitDecoy.Text, '\r\n|\n|\r', $semanticLineEnding.NewLine)
+
+      $root = New-Case "selected-unit-semantic-$($selectedUnitDecoy.Name)-$($semanticLineEnding.Name)"
+      $migrationReport = [regex]::Replace((Get-ValidReport), '\r\n|\n|\r', $semanticLineEnding.NewLine)
+      Write-Report $root ($migrationReport + $semanticLineEnding.NewLine + $renderedDecoy + $semanticLineEnding.NewLine)
+      Assert-Accepted "$($selectedUnitDecoy.Name) Selected Migration Unit decoy does not inflate migration-unit cardinality ($($semanticLineEnding.Name))" $root
+
+      $root = New-Case "generic-unit-semantic-$($selectedUnitDecoy.Name)-$($semanticLineEnding.Name)"
+      $genericReport = (Get-ValidReport) -replace [regex]::Escape($canonicalSelectorReportRow), $canonicalTaskSelectorReportRow
+      $genericReport = $genericReport -replace '(?s)## Selected Migration Unit.*?(?=## Conformance Matrix Reference)', ''
+      $genericReport = [regex]::Replace($genericReport, '\r\n|\n|\r', $semanticLineEnding.NewLine)
+      Write-Report $root ($genericReport + $semanticLineEnding.NewLine + $renderedDecoy + $semanticLineEnding.NewLine)
+      Write-AuthorityArtifacts $root 'task'
+      Assert-Accepted "$($selectedUnitDecoy.Name) Selected Migration Unit and UNIT-row decoys stay inert for a generic adapter ($($semanticLineEnding.Name))" $root
+    }
+
+    $root = New-Case "generic-visible-unit-row-$($semanticLineEnding.Name)"
+    $genericReport = (Get-ValidReport) -replace [regex]::Escape($canonicalSelectorReportRow), $canonicalTaskSelectorReportRow
+    $genericReport = $genericReport -replace '(?s)## Selected Migration Unit.*?(?=## Conformance Matrix Reference)', ''
+    $genericReport = [regex]::Replace($genericReport, '\r\n|\n|\r', $semanticLineEnding.NewLine)
+    $visibleUnitRow = [regex]::Replace("## Notes`n`n| Kind | ID |`n|---|---|`n| leaked | UNIT-ROGUE-001 |", '\r\n|\n|\r', $semanticLineEnding.NewLine)
+    Write-Report $root ($genericReport + $semanticLineEnding.NewLine + $visibleUnitRow + $semanticLineEnding.NewLine)
+    Write-AuthorityArtifacts $root 'task'
+    if ($semanticLineEnding.Name -ceq 'CRLF') {
+      $writtenReport = [IO.File]::ReadAllText((Join-Path $root 'structural-gate-fixture/10-implementation-report.md'))
+      if ($writtenReport.IndexOf("| leaked | UNIT-ROGUE-001 |`r`n", [StringComparison]::Ordinal) -lt 0) {
+        throw 'CRLF visible UNIT-row fixture was not preserved on disk'
+      }
+    }
+    Assert-Rejected "visible UNIT row remains forbidden for a generic adapter ($($semanticLineEnding.Name))" $root 'Structural gate generic adapter must omit Selected Migration Unit and all unit-specific IDs'
+  }
+
   $root = New-Case 'canonical-crlf-authority-chain'
   Write-Report $root (Get-ValidReport)
   foreach ($relativePath in @('10-implementation-report.md', 'master-spec.md', 'master-plan.md', '08-migration-plan.md', '02-discovery.md', '07-technical-design.md', '07-technical-design.approval.md')) {
     $path = Join-Path $root "structural-gate-fixture/$relativePath"
     $text = ((Get-Content -Raw -Encoding utf8 -LiteralPath $path) -replace "`r`n", "`n") -replace "`r", "`n"
     Write-Utf8 $path ($text -replace "`n", "`r`n")
   }
   Assert-Accepted 'canonical external approval and authority chain accept CRLF' $root
 
   $root = New-Case 'canonical-template-produced-migration-unit-report-for-task6'
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1
index 88d4036..77e28df 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1
@@ -262,21 +262,22 @@ function Get-ArcMarkdownH2HeadingMatches {
   $headingPattern = Get-ArcMarkdownH2HeadingPattern -Heading $Heading
   return @([regex]::Matches($visibleText, $headingPattern))
 }
 
 function Get-ArcStrictMarkdownTable {
   [CmdletBinding()]
   param(
     [Parameter(Mandatory)][string]$Text,
     [Parameter(Mandatory)][string]$Heading,
     [Parameter(Mandatory)][string[]]$Columns,
-    [Parameter(Mandatory)][AllowEmptyCollection()][Collections.Generic.List[string]]$Errors
+    [Parameter(Mandatory)][AllowEmptyCollection()][Collections.Generic.List[string]]$Errors,
+    [switch]$AllowEmptyBody
   )
 
   $visibleText = Get-ArcVisibleMarkdownText -Text $Text
   $headingPattern = Get-ArcMarkdownH2HeadingPattern -Heading $Heading
   $headingMatches = @([regex]::Matches($visibleText, $headingPattern))
   if ($headingMatches.Count -eq 0) {
     $Errors.Add("ARC-CONTRACT-MISSING-TABLE: $Heading")
     return @()
   }
   if ($headingMatches.Count -ne 1) {
@@ -286,21 +287,22 @@ function Get-ArcStrictMarkdownTable {
   $headingMatch = $headingMatches[0]
   $remaining = $visibleText.Substring($headingMatch.Index + $headingMatch.Length)
   $lines = @($remaining -split '\r?\n')
   $tableLines = [Collections.Generic.List[string]]::new()
   foreach ($line in $lines) {
     if ([string]::IsNullOrWhiteSpace($line) -and $tableLines.Count -eq 0) { continue }
     if ($line -match '^##\s+') { break }
     if ($line -match '^\|') { $tableLines.Add($line); continue }
     if ($tableLines.Count -gt 0) { break }
   }
-  if ($tableLines.Count -lt 3) {
+  $minimumTableLines = if ($AllowEmptyBody) { 2 } else { 3 }
+  if ($tableLines.Count -lt $minimumTableLines) {
     $Errors.Add("ARC-CONTRACT-MALFORMED-TABLE: $Heading")
     return @()
   }
 
   $rows = [Collections.Generic.List[string[]]]::new()
   foreach ($line in $tableLines) {
     if ($line -notmatch '^\|[^|].*[^|]\|\s*$' -or $line -match '\|\|') {
       $Errors.Add("ARC-CONTRACT-MALFORMED-TABLE: $Heading")
       return @()
     }
@@ -1516,20 +1518,177 @@ function Get-ArcApprovedReviewDesignRevision {
     @([regex]::Matches($frontMatter, '(?m)^status:\s*approved\s*$')).Count -ne 1 -or
     @([regex]::Matches($frontMatter, '(?m)^result:\s*complete\s*$')).Count -ne 1 -or
     $revisionMatches.Count -ne 1
   ) {
     $Errors.Add('responsibility-owner-extra')
     return ''
   }
   return $revisionMatches[0].Groups['value'].Value
 }
 
+function Test-ArcPathScopedFormatterCommand {
+  [CmdletBinding()]
+  param(
+    [Parameter(Mandatory)][string]$Command,
+    [Parameter(Mandatory)][string]$CanonicalPath
+  )
+
+  if ($Command -match '[\x00-\x1F\x7F;&|<>]') { return $false }
+  $tokenPattern = '(?<!\S)(?:"(?<double>[^"]*)"|''(?<single>[^'']*)''|(?<bare>[^\s"'']+))(?!\S)'
+  $tokenMatches = @([regex]::Matches($Command, $tokenPattern))
+  if (-not [string]::IsNullOrWhiteSpace([regex]::Replace($Command, $tokenPattern, ''))) { return $false }
+  $tokens = @($tokenMatches | ForEach-Object {
+    if ($_.Groups['double'].Success) { $_.Groups['double'].Value }
+    elseif ($_.Groups['single'].Success) { $_.Groups['single'].Value }
+    else { $_.Groups['bare'].Value }
+  })
+  if ($tokens.Count -lt 2) { return $false }
+
+  $directFormatterWords = @('format', 'fmt', 'prettier', 'black', 'gofmt', 'rustfmt', 'clang-format', 'csharpier', 'stylua', 'shfmt')
+  $formatSubcommandFormatterWords = @('ruff', 'biome')
+  $knownFormatterWords = @($directFormatterWords + $formatSubcommandFormatterWords)
+  $commandPrefixIndices = @(0)
+  $executableLeaf = @($tokens[0].Replace('\', '/') -split '/')[-1]
+  $executableName = [IO.Path]::GetFileNameWithoutExtension($executableLeaf).ToLowerInvariant()
+  $recognizedFormatterCommand = $directFormatterWords -ccontains $executableName
+  $pythonLauncher = $executableName -in @('python', 'python3', 'py')
+  $firstWord = if ($tokens.Count -gt 1) { $tokens[1].ToLowerInvariant() } else { '' }
+  $secondWord = if ($tokens.Count -gt 2) { $tokens[2].ToLowerInvariant() } else { '' }
+  $thirdWord = if ($tokens.Count -gt 3) { $tokens[3].ToLowerInvariant() } else { '' }
+  if (
+    ($pythonLauncher -and $firstWord -in @('-m', '--module') -and $formatSubcommandFormatterWords -ccontains $secondWord -and $thirdWord -ceq 'format') -or
+    ($executableName -in @('npm', 'pnpm', 'yarn', 'bun') -and $firstWord -ceq 'exec' -and $formatSubcommandFormatterWords -ccontains $secondWord -and $thirdWord -ceq 'format') -or
+    ($executableName -in @('uv', 'pipx') -and $firstWord -ceq 'run' -and $formatSubcommandFormatterWords -ccontains $secondWord -and $thirdWord -ceq 'format')
+  ) {
+    $commandPrefixIndices += @(1, 2, 3)
+    $recognizedFormatterCommand = $true
+  }
+  elseif (
+    ($pythonLauncher -and $firstWord -cmatch '^(?:-m|--module)=(?:ruff|biome)$' -and $secondWord -ceq 'format') -or
+    ($executableName -in @('npx', 'bunx', 'pnpm', 'yarn', 'bun') -and $formatSubcommandFormatterWords -ccontains $firstWord -and $secondWord -ceq 'format')
+  ) {
+    $commandPrefixIndices += @(1, 2)
+    $recognizedFormatterCommand = $true
+  }
+  elseif (
+    ($formatSubcommandFormatterWords -ccontains $executableName -and $firstWord -ceq 'format') -or
+    ($executableName -ceq 'dart' -and $firstWord -ceq 'format') -or
+    ($executableName -in @('go', 'cargo', 'deno') -and $firstWord -ceq 'fmt') -or
+    ($executableName -ceq 'dotnet' -and $firstWord -ceq 'csharpier') -or
+    ($executableName -in @('npx', 'bunx') -and $directFormatterWords -ccontains $firstWord) -or
+    ($executableName -in @('pnpm', 'yarn', 'bun') -and $directFormatterWords -ccontains $firstWord)
+  ) {
+    $commandPrefixIndices += 1
+    $recognizedFormatterCommand = $true
+  }
+  elseif (
+    ($executableName -ceq 'npm' -and (($firstWord -ceq 'exec' -and $directFormatterWords -ccontains $secondWord) -or ($firstWord -ceq 'run' -and $secondWord -in @('format', 'fmt')))) -or
+    ($executableName -in @('pnpm', 'yarn', 'bun') -and (($firstWord -ceq 'exec' -and $directFormatterWords -ccontains $secondWord) -or ($firstWord -ceq 'run' -and $secondWord -in @('format', 'fmt')))) -or
+    ($executableName -in @('uv', 'pipx') -and $firstWord -ceq 'run' -and $directFormatterWords -ccontains $secondWord)
+  ) {
+    $commandPrefixIndices += @(1, 2)
+    $recognizedFormatterCommand = $true
+  }
+
+  $targetCount = 0
+  $pendingScalarOption = ''
+  $pathScalarOptionPattern = '(?:file|path|config|director|(?:^|[-_])dirs?(?:$|[-_])|include|exclude|glob|input)'
+  $numericScalarOptions = @('--line-length', '--print-width', '--tab-width', '--workers', '--jobs', '--range-start', '--range-end', '--indent-size')
+  $moduleScalarOptions = @('-m', '--module')
+  $enumScalarOptions = [ordered]@{
+    '-o' = @('show', 'json', 'none', 'write')
+    '--output' = @('show', 'json', 'none', 'write')
+    '--style' = @('llvm', 'google', 'chromium', 'mozilla', 'webkit', 'microsoft', 'gnu', 'file')
+    '--parser' = @('angular', 'babel', 'babel-flow', 'babel-ts', 'css', 'espree', 'flow', 'glimmer', 'graphql', 'html', 'json', 'json5', 'json-stringify', 'less', 'lwc', 'markdown', 'mdx', 'meriyah', 'scss', 'typescript', 'vue', 'yaml')
+    '--end-of-line' = @('lf', 'crlf', 'cr', 'auto')
+    '--trailing-comma' = @('all', 'es5', 'none')
+    '--quote-props' = @('as-needed', 'consistent', 'preserve')
+    '--prose-wrap' = @('always', 'never', 'preserve')
+    '--embedded-language-formatting' = @('auto', 'off')
+  }
+  for ($tokenIndex = 0; $tokenIndex -lt $tokens.Count; $tokenIndex++) {
+    $token = $tokens[$tokenIndex]
+    if ([string]::IsNullOrWhiteSpace($token)) { return $false }
+    if ($tokenIndex -eq 0) {
+      if ($token.StartsWith('-', [StringComparison]::Ordinal) -or $token -match '[*?\[\]]') { return $false }
+      continue
+    }
+    if ($commandPrefixIndices -ccontains $tokenIndex) { continue }
+    if ($token -ceq $CanonicalPath) {
+      if ($pendingScalarOption -cne '') { return $false }
+      $targetCount++
+      continue
+    }
+
+    if ($pendingScalarOption -cne '') {
+      $scalarValue = $token.ToLowerInvariant()
+      $validScalar =
+        ($numericScalarOptions -ccontains $pendingScalarOption -and $token -cmatch '^[0-9]+(?:\.[0-9]+)?$') -or
+        ($moduleScalarOptions -ccontains $pendingScalarOption -and $knownFormatterWords -ccontains $scalarValue) -or
+        ($pendingScalarOption -ceq '--target-version' -and $scalarValue -cmatch '^(?:py)?[0-9]{2,3}$') -or
+        ($enumScalarOptions.Contains($pendingScalarOption) -and @($enumScalarOptions[$pendingScalarOption]) -ccontains $scalarValue)
+      if (-not $validScalar) { return $false }
+      if ($pythonLauncher -and $moduleScalarOptions -ccontains $pendingScalarOption -and $directFormatterWords -ccontains $scalarValue) {
+        $recognizedFormatterCommand = $true
+      }
+      $pendingScalarOption = ''
+      continue
+    }
+
+    if ($token.StartsWith('-', [StringComparison]::Ordinal)) {
+      if ($token -cin @('--all', '--recursive') -or $token -match '[*?\[\]]') { return $false }
+      $optionParts = @($token -split '=', 2)
+      $optionName = $optionParts[0].ToLowerInvariant()
+      if ($optionName -match $pathScalarOptionPattern) { return $false }
+      $hasInlineValue = $token.IndexOf('=', [StringComparison]::Ordinal) -ge 0
+      if ($hasInlineValue) {
+        $inlineValue = $optionParts[1]
+        $canonicalInlineValue = ConvertTo-ArcCanonicalRepositoryPath -Path $inlineValue
+        if (
+          [string]::IsNullOrWhiteSpace($inlineValue) -or
+          $inlineValue -match '[\\/]' -or
+          $inlineValue -match '[*?\[\]]' -or
+          $inlineValue -cmatch '^[A-Za-z]:' -or
+          $inlineValue.StartsWith('/', [StringComparison]::Ordinal) -or
+          ($canonicalInlineValue -ne '' -and $inlineValue -cmatch '\.[A-Za-z0-9_-]+$')
+        ) { return $false }
+        $inlineScalarValue = $inlineValue.ToLowerInvariant()
+        $validInlineScalar =
+          ($numericScalarOptions -ccontains $optionName -and $inlineValue -cmatch '^[0-9]+(?:\.[0-9]+)?$') -or
+          ($moduleScalarOptions -ccontains $optionName -and $knownFormatterWords -ccontains $inlineScalarValue) -or
+          ($optionName -ceq '--target-version' -and $inlineScalarValue -cmatch '^(?:py)?[0-9]{2,3}$') -or
+          ($enumScalarOptions.Contains($optionName) -and @($enumScalarOptions[$optionName]) -ccontains $inlineScalarValue)
+        if (-not $validInlineScalar) { return $false }
+        if ($pythonLauncher -and $moduleScalarOptions -ccontains $optionName -and $directFormatterWords -ccontains $inlineScalarValue) {
+          $recognizedFormatterCommand = $true
+        }
+      }
+      elseif ($numericScalarOptions -ccontains $optionName -or $moduleScalarOptions -ccontains $optionName -or $optionName -ceq '--target-version' -or $enumScalarOptions.Contains($optionName)) {
+        $pendingScalarOption = $optionName
+      }
+      continue
+    }
+
+    $canonicalOperand = ConvertTo-ArcCanonicalRepositoryPath -Path $token
+    $looksLikePath =
+      $token -cin @('.', './', '..', '../', '*', '**') -or
+      $token -match '[\\/]' -or
+      $token -match '[*?\[\]]' -or
+      $token -cmatch '^[A-Za-z]:' -or
+      $token.StartsWith('/', [StringComparison]::Ordinal) -or
+      ($canonicalOperand -ne '' -and $token -cmatch '\.[A-Za-z0-9_-]+$')
+    if ($looksLikePath) { return $false }
+    return $false
+  }
+  return $recognizedFormatterCommand -and $targetCount -eq 1 -and $pendingScalarOption -ceq ''
+}
+
 function Get-ArcImplementationReviewProvenance {
   [CmdletBinding()]
   param([Parameter(Mandatory)][string]$ImplementationText, [Parameter(Mandatory)][AllowEmptyCollection()][Collections.Generic.List[string]]$Errors)
 
   $columns = @('Task / Unit', 'File', 'File Kind', 'Edited Region / Symbol', 'Formatter Command', 'Unrelated Diff', 'Checkpoint History', 'Task-base SHA', 'Final-tree SHA')
   $tableErrors = [Collections.Generic.List[string]]::new()
   $table = @(Get-ArcStrictMarkdownTable -Text $ImplementationText -Heading 'Change Hygiene' -Columns $columns -Errors $tableErrors)
   if ($tableErrors.Count -ne 0) {
     foreach ($tableError in $tableErrors) { $Errors.Add($tableError) }
     return $null
@@ -1544,31 +1703,21 @@ function Get-ArcImplementationReviewProvenance {
     if ($canonicalPath -ceq '') { $Errors.Add('responsibility-evidence-missing') }
     else { $row[1] = $canonicalPath }
     $editedRegion = ([string]$row[3]).Trim()
     $formatterCommand = ([string]$row[4]).Trim()
     $unrelatedDiff = ([string]$row[5]).Trim()
     if (
       $editedRegion -cnotmatch '^[A-Za-z_][A-Za-z0-9_.:-]*(?:, [A-Za-z_][A-Za-z0-9_.:-]*)*$' -or
       $editedRegion -match '(?i)^(?:none|all|entire|whole|repository|repo|root|file)$'
     ) { $Errors.Add('change-hygiene-invalid') }
     if ($formatterCommand -cne 'none') {
-      $normalizedFormatterCommand = $formatterCommand.Replace('\', '/')
-      $formatterOperands = @([regex]::Matches($normalizedFormatterCommand, '(?<!\S)(?:"(?<double>[^"]*)"|''(?<single>[^'']*)''|(?<bare>[^\s"'']+))(?!\S)') | ForEach-Object {
-        if ($_.Groups['double'].Success) { $_.Groups['double'].Value }
-        elseif ($_.Groups['single'].Success) { $_.Groups['single'].Value }
-        else { $_.Groups['bare'].Value }
-      })
-      if (
-        $formatterCommand -match '[\x00-\x1F\x7F;&|<>]' -or
-        @($formatterOperands | Where-Object { $_ -cin @('.', './', '*', '--all') }).Count -gt 0 -or
-        $formatterOperands -cnotcontains $canonicalPath
-      ) { $Errors.Add('change-hygiene-invalid') }
+      if (-not (Test-ArcPathScopedFormatterCommand -Command $formatterCommand -CanonicalPath $canonicalPath)) { $Errors.Add('change-hygiene-invalid') }
     }
     if ($unrelatedDiff -cne 'none' -and $unrelatedDiff -cnotmatch '^confirmed:MAJOR-[A-Z0-9]+(?:-[A-Z0-9]+)*$') {
       $Errors.Add('change-hygiene-invalid')
     }
   }
   if ($Errors.Count -ne 0) { return $null }
   $taskUnits = @($rows | ForEach-Object { $_[0].Trim() } | Sort-Object -Unique)
   $taskBases = @($rows | ForEach-Object { $_[7].Trim() } | Sort-Object -Unique)
   $finalTrees = @($rows | ForEach-Object { $_[8].Trim() } | Sort-Object -Unique)
   if ($taskUnits.Count -ne 1 -or $taskUnits[0] -cnotmatch '^(?:WORK|UNIT)-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -or $taskBases.Count -ne 1 -or $finalTrees.Count -ne 1 -or $taskBases[0] -cnotmatch '^[0-9a-f]{40}$' -or $finalTrees[0] -cnotmatch '^[0-9a-f]{40}$') {
@@ -1667,24 +1816,25 @@ function Get-ArcSourceLexicalLines {
   $cPreprocessor = $extension -in @('.c', '.h', '.cc', '.cpp', '.cxx', '.hpp')
   $hashDirectiveLanguage = $extension -in @('.cs', '.rs')
   $javascriptLanguage = $extension -in @('.js', '.jsx', '.mjs', '.cjs', '.ts', '.tsx')
   $cStyleBlockComment = $unknownLanguage -or $extension -in ($cFamilyExtensions + @('.css', '.sql'))
   $markupBlockComment = $unknownLanguage -or $extension -in @('.html', '.htm', '.xml', '.md', '.markdown')
   $powerShellBlockComment = $unknownLanguage -or $extension -in @('.ps1', '.psm1', '.psd1')
   $blockCommentEnd = ''
   $blockCommentStart = -1
   $multilineStringDelimiter = ''
   $multilineStringStart = -1
+  $javascriptTemplateStack = [Collections.Generic.List[object]]::new()
   for ($lineIndex = 0; $lineIndex -lt $lines.Count; $lineIndex++) {
     $line = $lines[$lineIndex]
     $semanticMarkerText = ''
-    if ($blockCommentEnd -ceq '' -and $multilineStringDelimiter -ceq '') {
+    if ($blockCommentEnd -ceq '' -and $multilineStringDelimiter -ceq '' -and $javascriptTemplateStack.Count -eq 0) {
       $semanticMarkerMatch = if ($slashLineComment) {
         [regex]::Match($line, '^\s*//\s*arc:(?<payload>(?:@[a-z][a-z-]*|route|scenario)[ \t]+\S(?:.*\S)?)\s*$')
       }
       else { $null }
       if (($null -eq $semanticMarkerMatch -or -not $semanticMarkerMatch.Success) -and ($hashLineComment -or $powerShellBlockComment)) {
         $semanticMarkerMatch = [regex]::Match($line, '^\s*#\s*arc:(?<payload>(?:@[a-z][a-z-]*|route|scenario)[ \t]+\S(?:.*\S)?)\s*$')
       }
       if ($null -ne $semanticMarkerMatch -and $semanticMarkerMatch.Success) {
         $semanticMarkerText = $semanticMarkerMatch.Groups['payload'].Value.Trim()
       }
@@ -1704,20 +1854,50 @@ function Get-ArcSourceLexicalLines {
         continue
       }
       if ($blockCommentEnd -ne '') {
         $commentEnd = $line.IndexOf($blockCommentEnd, $index, [StringComparison]::Ordinal)
         if ($commentEnd -lt 0) { $index = $line.Length; continue }
         $index = $commentEnd + $blockCommentEnd.Length
         $blockCommentEnd = ''
         $blockCommentStart = -1
         continue
       }
+      if ($javascriptTemplateStack.Count -gt 0 -and -not $javascriptTemplateStack[$javascriptTemplateStack.Count - 1].InExpression) {
+        $hasCode = $true
+        $templateContext = $javascriptTemplateStack[$javascriptTemplateStack.Count - 1]
+        $templateCharacter = $line[$index]
+        if ($templateCharacter -eq '\') {
+          [void]$structural.Append(' ')
+          $index++
+          if ($index -lt $line.Length) {
+            [void]$structural.Append(' ')
+            $index++
+          }
+          continue
+        }
+        if ($templateCharacter -eq '`') {
+          [void]$structural.Append('x')
+          $javascriptTemplateStack.RemoveAt($javascriptTemplateStack.Count - 1)
+          $index++
+          continue
+        }
+        if ($templateCharacter -eq '$' -and $index + 1 -lt $line.Length -and $line[$index + 1] -eq '{') {
+          [void]$structural.Append('${')
+          $templateContext.InExpression = $true
+          $templateContext.InterpolationDepth = 1
+          $index += 2
+          continue
+        }
+        [void]$structural.Append(' ')
+        $index++
+        continue
+      }
 
       $remaining = $line.Substring($index)
       $multilineOpening = [regex]::Match($remaining, '^(?<delimiter>"{3,}|''{3,})')
       if ($multilineOpening.Success) {
         $hasCode = $true
         $multilineStringDelimiter = $multilineOpening.Groups['delimiter'].Value
         $multilineStringStart = $lineIndex
         $index += $multilineStringDelimiter.Length
         continue
       }
@@ -1759,20 +1939,31 @@ function Get-ArcSourceLexicalLines {
           else {
             $lineAmbiguous = $true
             $regexIndex = $line.Length
           }
           $hasCode = $true
           [void]$structural.Append([string]::new([char]' ', $regexIndex - $index))
           $index = $regexIndex
           continue
         }
       }
+      if ($javascriptLanguage -and $character -eq '`') {
+        $hasCode = $true
+        [void]$structural.Append(' ')
+        $javascriptTemplateStack.Add([pscustomobject]@{
+          StartLine = $lineIndex
+          InExpression = $false
+          InterpolationDepth = 0
+        })
+        $index++
+        continue
+      }
       if ($character -in @("'", '"', '`')) {
         $hasCode = $true
         $quote = $character
         [void]$structural.Append(' ')
         $index++
         while ($index -lt $line.Length) {
           $quotedCharacter = $line[$index]
           [void]$structural.Append(' ')
           if (($quotedCharacter -eq '\' -or $quotedCharacter -eq '`') -and $index + 1 -lt $line.Length) {
             [void]$structural.Append(' ')
@@ -1786,34 +1977,49 @@ function Get-ArcSourceLexicalLines {
               continue
             }
             $index++
             break
           }
           $index++
         }
         continue
       }
 
+      if ($javascriptTemplateStack.Count -gt 0 -and $javascriptTemplateStack[$javascriptTemplateStack.Count - 1].InExpression) {
+        $templateContext = $javascriptTemplateStack[$javascriptTemplateStack.Count - 1]
+        if ($character -eq '{') {
+          $templateContext.InterpolationDepth++
+        }
+        elseif ($character -eq '}') {
+          $templateContext.InterpolationDepth--
+          if ($templateContext.InterpolationDepth -eq 0) { $templateContext.InExpression = $false }
+        }
+      }
+
       [void]$structural.Append($character)
       if (-not [char]::IsWhiteSpace($character)) { $hasCode = $true }
       $index++
     }
     $result.Add([pscustomobject]@{
       Raw = $line
       HasCode = $hasCode
       HasSemanticMetadata = $semanticMarkerText -cne ''
       SemanticText = if ($semanticMarkerText -cne '') { $semanticMarkerText } else { $line }
       StructuralText = $structural.ToString()
       Ambiguous = $lineAmbiguous
     })
   }
-  foreach ($ambiguousStart in @($blockCommentStart, $multilineStringStart) | Where-Object { $_ -ge 0 }) {
+  $ambiguousStarts = @($blockCommentStart, $multilineStringStart)
+  if ($javascriptTemplateStack.Count -gt 0) {
+    $ambiguousStarts += @($javascriptTemplateStack | ForEach-Object { $_.StartLine } | Sort-Object | Select-Object -First 1)
+  }
+  foreach ($ambiguousStart in $ambiguousStarts | Where-Object { $_ -ge 0 }) {
     for ($lineIndex = $ambiguousStart; $lineIndex -lt $result.Count; $lineIndex++) { $result[$lineIndex].Ambiguous = $true }
   }
   return $result.ToArray()
 }
 
 function Test-ArcCommentOnlySourceLine {
   [CmdletBinding()]
   param([AllowEmptyString()][string]$Line)
 
   $lexicalLine = @(Get-ArcSourceLexicalLines -SourceText $Line) | Select-Object -First 1
@@ -2289,20 +2495,149 @@ function Test-ArcPinnedVerificationOwnershipEvidence {
       @([regex]::Matches($productionText, '(?m)^\s*route\s+' + [regex]::Escape($routeMatches[0].Groups['symbol'].Value) + '\s*->\s*' + [regex]::Escape($routeMatches[0].Groups['provider'].Value) + '\s*$')).Count
     } else { 0 }
     if ($routeMatches.Count -ne 1 -or $exactProductionRouteCount -ne 1 -or $productionOwner.RouteSymbols -cnotcontains $routeMatches[0].Groups['symbol'].Value -or $productionOwner.Providers -cnotcontains $routeMatches[0].Groups['provider'].Value) {
       $Errors.Add('verification-production-binding-missing')
       return $false
     }
   }
   return $true
 }
 
+function Get-ArcExecutableReviewState {
+  [CmdletBinding()]
+  param(
+    [Parameter(Mandatory)][string]$ReviewText,
+    [Parameter(Mandatory)][AllowEmptyCollection()][Collections.Generic.List[string]]$Errors
+  )
+
+  $visibleText = Get-ArcVisibleMarkdownText -Text $ReviewText
+  $state = [ordered]@{
+    RuleResolution = ''
+    CanonicalSelector = ''
+    Architecture = ''
+    Tree = ''
+    Responsibility = ''
+    Verification = ''
+    ProductionActivation = ''
+    Behavior = ''
+    ChangeHygiene = ''
+    CriticalCount = -1
+    MajorCount = -1
+    Overall = ''
+  }
+  $readControl = {
+    param([string]$Label, [string[]]$Allowed, [string]$MissingDiagnostic = 'responsibility-evidence-missing')
+    $matches = @([regex]::Matches($visibleText, '(?im)^[ \t]*-[ \t]*(?:\*\*)?' + [regex]::Escape($Label) + '(?:\*\*)?:[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$'))
+    if ($matches.Count -ne 1) {
+      $Errors.Add($MissingDiagnostic)
+      return ''
+    }
+    $value = $matches[0].Groups['value'].Value.Trim().Trim([char[]]@('<', '>', '`'))
+    if ($Allowed -cnotcontains $value) {
+      $Errors.Add('responsibility-evidence-missing')
+      return ''
+    }
+    return $value
+  }
+  $readCount = {
+    param([string]$Label)
+    $matches = @([regex]::Matches($visibleText, '(?im)^[ \t]*-[ \t]*(?:\*\*)?' + [regex]::Escape($Label) + ':(?:\*\*)?[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$'))
+    [UInt64]$parsed = 0
+    if ($matches.Count -ne 1 -or -not [UInt64]::TryParse($matches[0].Groups['value'].Value.Trim(), [ref]$parsed)) {
+      $Errors.Add('responsibility-evidence-missing')
+      return [Int64]-1
+    }
+    if ($parsed -gt [Int64]::MaxValue) {
+      $Errors.Add('responsibility-evidence-missing')
+      return [Int64]-1
+    }
+    return [Int64]$parsed
+  }
+
+  $state.RuleResolution = & $readControl 'Rule Resolution Verdict' @('RESOLVED', 'BLOCKED')
+  $state.CanonicalSelector = & $readControl 'Canonical Selector Verdict' @('PASS', 'BLOCKED')
+  $state.Architecture = & $readControl 'Architecture Conformance Verdict' @('PASS', 'BLOCKED') 'responsibility-owner-missing'
+  $state.Tree = & $readControl 'Tree Conformance Verdict' @('PASS', 'BLOCKED') 'responsibility-owner-missing'
+  $state.Responsibility = & $readControl 'Responsibility Conformance Verdict' @('PASS', 'BLOCKED') 'responsibility-owner-missing'
+  $state.Verification = & $readControl 'Verification Ownership Verdict' @('PASS', 'BLOCKED') 'responsibility-owner-missing'
+  $state.ProductionActivation = & $readControl 'Production Activation-path Verdict' @('PASS', 'BLOCKED', 'NOT_APPLICABLE')
+  $state.Behavior = & $readControl 'Behavior Analysis State' @('NOT_RUN', 'COMPLETE')
+  $state.ChangeHygiene = & $readControl 'Change Hygiene Verdict' @('PASS', 'BLOCKED')
+  $state.CriticalCount = & $readCount 'Critical count'
+  $state.MajorCount = & $readCount 'Major count'
+  $state.Overall = & $readControl 'Verdict' @('Approve', 'Approve-with-fixes', 'Reject')
+
+  $localizedIssueColumn = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('VuG6pW4gxJHhu4E='))
+  $localizedFixColumn = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('Rml4IMSR4buBIHh14bqldA=='))
+  $findingColumnSets = @(
+    @('File:line', 'Issue', 'Proposed fix'),
+    @('File:line', $localizedIssueColumn, $localizedFixColumn)
+  )
+  $getFindingTable = {
+    param([string]$Heading)
+    $firstDiagnostics = @()
+    foreach ($findingColumns in $findingColumnSets) {
+      $tableErrors = [Collections.Generic.List[string]]::new()
+      $candidate = @(Get-ArcStrictMarkdownTable -Text $ReviewText -Heading $Heading -Columns $findingColumns -Errors $tableErrors -AllowEmptyBody)
+      if ($tableErrors.Count -eq 0) { return $candidate }
+      if ($firstDiagnostics.Count -eq 0) { $firstDiagnostics = @($tableErrors) }
+    }
+    foreach ($diagnostic in $firstDiagnostics) { $Errors.Add($diagnostic) }
+    return @()
+  }
+  $criticalTable = @(& $getFindingTable 'Critical')
+  $majorTable = @(& $getFindingTable 'Major')
+  $countFindings = {
+    param([object[]]$Table)
+    if ($Table.Count -lt 2) { return [Int64]-1 }
+    $rows = @($Table | Select-Object -Skip 2)
+    if ($rows.Count -eq 0) { return [Int64]0 }
+    if ($rows.Count -eq 1 -and @($rows[0] | Where-Object { [string]$_ -ceq 'none' }).Count -eq 3) { return [Int64]0 }
+    if (@($rows | Where-Object { @($_ | Where-Object { [string]::IsNullOrWhiteSpace([string]$_) -or [string]$_ -ceq 'none' }).Count -gt 0 }).Count -gt 0) {
+      $Errors.Add('responsibility-evidence-missing')
+      return [Int64]-1
+    }
+    return [Int64]$rows.Count
+  }
+  $criticalFindingCount = & $countFindings $criticalTable
+  $majorFindingCount = & $countFindings $majorTable
+  if ($state.CriticalCount -ge 0 -and $criticalFindingCount -ge 0 -and $state.CriticalCount -ne $criticalFindingCount) { $Errors.Add('responsibility-waiver-forbidden') }
+  if ($state.MajorCount -ge 0 -and $majorFindingCount -ge 0 -and $state.MajorCount -ne $majorFindingCount) { $Errors.Add('responsibility-waiver-forbidden') }
+
+  if (@($state.Values | Where-Object { [string]::IsNullOrWhiteSpace([string]$_) }).Count -eq 0 -and $state.CriticalCount -ge 0 -and $state.MajorCount -ge 0) {
+    $derivedArchitecture = if ($state.Tree -ceq 'PASS' -and $state.Responsibility -ceq 'PASS' -and $state.Verification -ceq 'PASS') { 'PASS' } else { 'BLOCKED' }
+    if ($state.Architecture -cne $derivedArchitecture) { $Errors.Add('responsibility-waiver-forbidden') }
+    $preBehaviorBlocked =
+      $state.RuleResolution -ceq 'BLOCKED' -or
+      $state.CanonicalSelector -ceq 'BLOCKED' -or
+      $state.Architecture -ceq 'BLOCKED' -or
+      $state.Tree -ceq 'BLOCKED' -or
+      $state.Responsibility -ceq 'BLOCKED' -or
+      $state.Verification -ceq 'BLOCKED' -or
+      $state.ProductionActivation -ceq 'BLOCKED'
+    $expectedBehavior = if ($preBehaviorBlocked) { 'NOT_RUN' } else { 'COMPLETE' }
+    if ($state.Behavior -cne $expectedBehavior) { $Errors.Add('responsibility-waiver-forbidden') }
+    $allExecutableGatesPass = -not $preBehaviorBlocked -and $state.Behavior -ceq 'COMPLETE' -and $state.ChangeHygiene -ceq 'PASS'
+    $derivedOverall = if (-not $allExecutableGatesPass -or $state.CriticalCount -gt 0) {
+      'Reject'
+    }
+    elseif ($state.MajorCount -gt 0) {
+      'Approve-with-fixes'
+    }
+    else {
+      'Approve'
+    }
+    if ($state.Overall -cne $derivedOverall) { $Errors.Add('responsibility-waiver-forbidden') }
+  }
+  return [pscustomobject]$state
+}
+
 function Test-ResponsibilityReview {
   [CmdletBinding()]
   param(
     [string]$DesignText,
     [string]$ImplementationText,
     [string]$ReviewText,
     [string]$ContractText,
     [string]$SourceRoot,
     [string]$TaskBaseSha,
     [string]$FinalTreeSha,
@@ -2312,20 +2647,21 @@ function Test-ResponsibilityReview {
   foreach ($error in @(Test-ArcResponsibilityStageVersion $ContractText 'REVIEW')) { $errors.Add($error) }
   if ([string]::IsNullOrWhiteSpace($DesignText) -or [string]::IsNullOrWhiteSpace($ImplementationText) -or [string]::IsNullOrWhiteSpace($ReviewText)) {
     $errors.Add('responsibility-owner-missing')
     return @($errors | Select-Object -Unique)
   }
   if (@(Test-ArcDiscoveryResponsibilityContractVersion -DiscoveryText $DesignText).Count -ne 0 -or @(Test-ArcDiscoveryResponsibilityContractVersion -DiscoveryText $ImplementationText).Count -ne 0 -or @(Test-ArcDiscoveryResponsibilityContractVersion -DiscoveryText $ReviewText).Count -ne 0) {
     $errors.Add('responsibility-contract-version-invalid')
     return @($errors | Select-Object -Unique)
   }
   $visibleReviewText = Get-ArcVisibleMarkdownText -Text $ReviewText
+  $executableReviewState = $null
   $scopeColumns = @('Run ID', 'Master Spec Reference', 'Master Spec ID', 'Master Spec Revision', 'Master Plan Reference', 'Master Plan ID', 'Master Plan Revision', 'Work Item ID')
   $selectorColumns = @('Work Item ID', 'Adapter Kind', 'External ID', 'Authority', 'Authority Revision', 'Approval Reference', 'Parent Selector', 'Acceptance', 'Trace IDs', 'Mode Constraint', 'Design Revision', 'Parent Work Item ID', 'Decomposition Decision Reference')
   $implementationSelectorColumns = @($selectorColumns + 'Canonical Match')
   $provenanceColumns = @('Task / Unit', 'Task-base SHA', 'Final-tree SHA', 'Source Artifact')
   $handoffColumns = @('Responsibility Contract Version', 'Tree Conformance', 'Responsibility Conformance', 'Verification Ownership', 'Architecture Conformance State', 'Evidence References')
   $selectedUnitColumns = @('Migration Unit ID', 'Plan Reference', 'Approval Reference', 'Mode Constraint', 'Bootstrap Scope', 'Foundation Baseline ID', 'Foundation Baseline Reference', 'Foundation Baseline Approval Reference', 'Baseline Reference', 'Trace IDs')
   $workItemColumns = @('Work Item ID', 'Title', 'Required', 'Dependencies', 'Plan Order', 'Acceptance', 'Trace IDs', 'Delivery Adapter', 'Status', 'Latest Attempt', 'Terminal Evidence', 'Approval Reference')
   $implementationScopeTable = @(Get-ArcStrictMarkdownTable -Text $ImplementationText -Heading 'Master Scope Context' -Columns $scopeColumns -Errors $errors)
   $reviewScopeTable = @(Get-ArcStrictMarkdownTable -Text $ReviewText -Heading 'Master Scope Context' -Columns $scopeColumns -Errors $errors)
   $implementationSelectorTable = @(Get-ArcStrictMarkdownTable -Text $ImplementationText -Heading 'Canonical Adapter Evidence' -Columns $implementationSelectorColumns -Errors $errors)
@@ -2522,20 +2858,22 @@ function Test-ResponsibilityReview {
   $actualVerificationColumns = @($verificationColumns + 'Actual Evidence')
   $ownerReferenceColumns = @('Work Item ID', 'Design Revision', 'Responsibility IDs', 'Shared Foundation IDs', 'Integration Responsibility IDs', 'Independent Boundary Evidence')
   $reviewColumns = @('Responsibility ID', 'Source/Diff Evidence', 'Planned Public Symbols', 'Actual Public Symbols', 'Planned Effects', 'Actual Effects', 'Verdict')
   $plannedResponsibilityTable = @(Get-ArcStrictMarkdownTable -Text $DesignText -Heading 'File Responsibility Matrix' -Columns $responsibilityColumns -Errors $errors)
   $plannedVerificationTable = @(Get-ArcStrictMarkdownTable -Text $DesignText -Heading 'Verification Ownership Matrix' -Columns $verificationColumns -Errors $errors)
   $implementationResponsibilityTable = @(Get-ArcStrictMarkdownTable -Text $ImplementationText -Heading 'Actual File Responsibility Matrix' -Columns $actualResponsibilityColumns -Errors $errors)
   $implementationVerificationTable = @(Get-ArcStrictMarkdownTable -Text $ImplementationText -Heading 'Actual Verification Ownership Matrix' -Columns $actualVerificationColumns -Errors $errors)
   $ownerReferenceTable = @(Get-ArcStrictMarkdownTable -Text $ImplementationText -Heading 'Responsibility Owner References' -Columns $ownerReferenceColumns -Errors $errors)
   $reviewEvidenceTable = @(Get-ArcStrictMarkdownTable -Text $ReviewText -Heading 'Responsibility Review Evidence' -Columns $reviewColumns -Errors $errors)
   if ($errors.Count -ne 0 -or $plannedResponsibilityTable.Count -lt 3 -or $plannedVerificationTable.Count -lt 3 -or $implementationResponsibilityTable.Count -lt 3 -or $implementationVerificationTable.Count -lt 3 -or $ownerReferenceTable.Count -lt 3 -or $reviewEvidenceTable.Count -lt 3) { return @($errors | Select-Object -Unique) }
+  $executableReviewState = Get-ArcExecutableReviewState -ReviewText $ReviewText -Errors $errors
+  if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }
 
   $toRow = { param([object]$Cells, [string[]]$Columns) $row = @{}; for ($index = 0; $index -lt $Columns.Count; $index++) { $row[$Columns[$index]] = [string]$Cells[$index] }; return $row }
   $splitList = { param([string]$Value) @($Value -split '[,;]' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }) }
   $validVerdicts = @(Get-ArcContractEnumValues -ContractText $ContractText -Name 'Verdict')
   $allPlannedResponsibilities = @($plannedResponsibilityTable | Select-Object -Skip 2 | ForEach-Object { & $toRow $_ $responsibilityColumns })
   $allPlannedVerifications = @($plannedVerificationTable | Select-Object -Skip 2 | ForEach-Object { & $toRow $_ $verificationColumns })
   $implementationResponsibilities = @($implementationResponsibilityTable | Select-Object -Skip 2 | ForEach-Object { & $toRow $_ $actualResponsibilityColumns })
   $implementationVerifications = @($implementationVerificationTable | Select-Object -Skip 2 | ForEach-Object { & $toRow $_ $actualVerificationColumns })
   $ownerReferenceRows = @($ownerReferenceTable | Select-Object -Skip 2 | ForEach-Object { & $toRow $_ $ownerReferenceColumns })
   $reviewRows = @($reviewEvidenceTable | Select-Object -Skip 2 | ForEach-Object { & $toRow $_ $reviewColumns })
@@ -2780,60 +3118,58 @@ function Test-ResponsibilityReview {
   $implementationVerificationById = & $toMap $implementationVerifications 'Verification Owner ID' 'verification-owner-extra'
   foreach ($id in $plannedVerificationById.Keys) {
     if (-not $implementationVerificationById.ContainsKey($id)) { $errors.Add('verification-owner-missing'); $verificationPass = $false; continue }
     $planned = $plannedVerificationById[$id]; $implementation = $implementationVerificationById[$id]
     foreach ($field in $verificationColumns) { if ($planned[$field] -cne $implementation[$field]) { $errors.Add('verification-production-binding-missing'); $verificationPass = $false; break } }
     if ($validVerdicts -cnotcontains $implementation['Verdict'] -or $implementation['Verdict'] -cne 'PASS') { $errors.Add('verification-disposition-invalid'); $verificationPass = $false }
     if (-not (Test-ArcPinnedVerificationOwnershipEvidence -VerificationRow $planned -SourceRoot $SourceRoot -FinalTreeSha $FinalTreeSha -ProductionOwnersById $inventoryById -Errors $errors)) { $verificationPass = $false }
   }
   foreach ($id in $implementationVerificationById.Keys) { if (-not $plannedVerificationById.ContainsKey($id)) { $errors.Add('verification-owner-extra'); $verificationPass = $false } }
 
-  $getVerdict = { param([string]$Label) $matches = [regex]::Matches($visibleReviewText, '(?im)^[ \t]*-[ \t]*(?:\*\*)?' + [regex]::Escape($Label) + '(?:\*\*)?:[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$'); if ($matches.Count -ne 1) { $errors.Add('responsibility-owner-missing'); return '' }; $value = $matches[0].Groups['value'].Value.Trim().Trim([char[]]@('<', '>', '`')); if ($validVerdicts -cnotcontains $value) { $errors.Add('responsibility-owner-extra'); return '' }; return $value }
-  $architectureVerdict = & $getVerdict 'Architecture Conformance Verdict'; $treeVerdict = & $getVerdict 'Tree Conformance Verdict'; $responsibilityVerdict = & $getVerdict 'Responsibility Conformance Verdict'; $verificationVerdict = & $getVerdict 'Verification Ownership Verdict'
-  $overallMatches = [regex]::Matches($visibleReviewText, '(?im)^[ \t]*-[ \t]*(?:\*\*)?Verdict(?:\*\*)?:[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$')
-  $overallVerdict = if ($overallMatches.Count -eq 1) { $overallMatches[0].Groups['value'].Value.Trim().Trim([char[]]@('<', '>', '`')) } else { $errors.Add('responsibility-owner-missing'); '' }
-  $criticalCountMatches = @([regex]::Matches($visibleReviewText, '(?im)^[ \t]*-[ \t]*(?:\*\*)?Critical count:(?:\*\*)?[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$'))
-  $criticalCount = if ($criticalCountMatches.Count -eq 1 -and $criticalCountMatches[0].Groups['value'].Value.Trim() -cmatch '^[0-9]+$') { [int]$criticalCountMatches[0].Groups['value'].Value.Trim() } else { $errors.Add('responsibility-evidence-missing'); -1 }
+  $architectureVerdict = $executableReviewState.Architecture
+  $treeVerdict = $executableReviewState.Tree
+  $responsibilityVerdict = $executableReviewState.Responsibility
+  $verificationVerdict = $executableReviewState.Verification
   $derivedTree = if ($treePass) { 'PASS' } else { 'BLOCKED' }; $derivedResponsibility = if ($responsibilityPass) { 'PASS' } else { 'BLOCKED' }; $derivedVerification = if ($verificationPass) { 'PASS' } else { 'BLOCKED' }
   if ($treeVerdict -ne '' -and $treeVerdict -cne $derivedTree) { $errors.Add('responsibility-waiver-forbidden') }
   if ($responsibilityVerdict -ne '' -and $responsibilityVerdict -cne $derivedResponsibility) { $errors.Add('responsibility-waiver-forbidden') }
   if ($verificationVerdict -ne '' -and $verificationVerdict -cne $derivedVerification) { $errors.Add('responsibility-waiver-forbidden') }
   $derivedArchitecture = if ($treeVerdict -ceq 'PASS' -and $responsibilityVerdict -ceq 'PASS' -and $verificationVerdict -ceq 'PASS') { 'PASS' } else { 'BLOCKED' }
   if ($architectureVerdict -ne '' -and $architectureVerdict -cne $derivedArchitecture) { $errors.Add('responsibility-waiver-forbidden') }
   if (
     $reviewHandoff['Tree Conformance'] -cne $treeVerdict -or
     $reviewHandoff['Responsibility Conformance'] -cne $responsibilityVerdict -or
     $reviewHandoff['Verification Ownership'] -cne $verificationVerdict -or
     $reviewHandoff['Architecture Conformance State'] -cne $architectureVerdict
   ) { $errors.Add('responsibility-waiver-forbidden') }
-  if ($derivedArchitecture -ceq 'BLOCKED' -or $overallVerdict -cne 'Approve' -or $criticalCount -ne 0) { $errors.Add('responsibility-waiver-forbidden') }
+  if ($derivedArchitecture -ceq 'BLOCKED' -or $executableReviewState.Overall -cne 'Approve' -or $executableReviewState.CriticalCount -ne 0 -or $executableReviewState.MajorCount -ne 0) { $errors.Add('responsibility-waiver-forbidden') }
   return @($errors | Select-Object -Unique)
 }
 
 function Test-ResponsibilityHandoff {
   [CmdletBinding()]
   param([string]$SourceText, [string]$TargetText, [string]$ContractText, [string]$ApprovedPlanText)
 
   $errors = [Collections.Generic.List[string]]::new()
   foreach ($error in @(Test-ArcResponsibilityStageVersion $ContractText 'HANDOFF')) { $errors.Add($error) }
   $columns = @(
     'Responsibility Contract Version', 'Tree Conformance', 'Responsibility Conformance',
     'Verification Ownership', 'Architecture Conformance State', 'Evidence References'
   )
   $provenanceColumns = @('Task / Unit', 'Task-base SHA', 'Final-tree SHA', 'Source Artifact')
   $scopeColumns = @('Run ID', 'Master Spec Reference', 'Master Spec ID', 'Master Spec Revision', 'Master Plan Reference', 'Master Plan ID', 'Master Plan Revision', 'Work Item ID')
   $selectedUnitColumns = @('Migration Unit ID', 'Plan Reference', 'Approval Reference', 'Mode Constraint', 'Bootstrap Scope', 'Foundation Baseline ID', 'Foundation Baseline Reference', 'Foundation Baseline Approval Reference', 'Baseline Reference', 'Trace IDs')
 
   $readArtifact = {
     param([string]$Text, [string]$Role)
 
-    $artifact = [ordered]@{ Row = $null; Provenance = $null; Scope = $null; StepId = ''; AdapterKind = ''; SelectedUnit = $null }
+    $artifact = [ordered]@{ Row = $null; Provenance = $null; Scope = $null; StepId = ''; AdapterKind = ''; SelectedUnit = $null; ReviewState = $null }
     if ([string]::IsNullOrWhiteSpace($Text)) {
       $errors.Add('responsibility-owner-missing')
       return $artifact
     }
     if (@(Test-ArcDiscoveryResponsibilityContractVersion -DiscoveryText $Text).Count -ne 0) {
       $errors.Add('responsibility-contract-version-invalid')
       return $artifact
     }
 
     $tableErrors = [Collections.Generic.List[string]]::new()
@@ -2888,27 +3224,25 @@ function Test-ResponsibilityHandoff {
     if (
       ($topLevelKeys -join '|') -cne 'step_id|status|result|approval_source|produced_at|responsibility_contract' -or
       @([regex]::Matches($frontMatter, '(?m)^status:\s*approved\s*$')).Count -ne 1 -or
       @([regex]::Matches($frontMatter, '(?m)^result:\s*complete\s*$')).Count -ne 1 -or
       @([regex]::Matches($frontMatter, '(?m)^approval_source:\s*human\s*$')).Count -ne 1 -or
       -not $producedAtValid
     ) { $errors.Add('responsibility-evidence-missing') }
 
     $visibleText = Get-ArcVisibleMarkdownText -Text $Text
     if ($artifact.StepId -ceq '11-ai-review') {
-      $reviewVerdictMatches = @([regex]::Matches($visibleText, '(?im)^[ \t]*-[ \t]*(?:\*\*)?Verdict(?:\*\*)?:[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$'))
-      $criticalCountMatches = @([regex]::Matches($visibleText, '(?im)^[ \t]*-[ \t]*(?:\*\*)?Critical count:(?:\*\*)?[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$'))
+      $artifact.ReviewState = Get-ArcExecutableReviewState -ReviewText $Text -Errors $errors
       if (
-        $reviewVerdictMatches.Count -ne 1 -or
-        $reviewVerdictMatches[0].Groups['value'].Value.Trim() -cne 'Approve' -or
-        $criticalCountMatches.Count -ne 1 -or
-        $criticalCountMatches[0].Groups['value'].Value.Trim() -cne '0'
+        $artifact.ReviewState.Overall -cne 'Approve' -or
+        $artifact.ReviewState.CriticalCount -ne 0 -or
+        $artifact.ReviewState.MajorCount -ne 0
       ) { $errors.Add('responsibility-waiver-forbidden') }
     }
     $adapterMatches = @([regex]::Matches($visibleText, '(?im)^[ \t]*-[ \t]*Delivery Adapter Kind:[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$'))
     if ($adapterMatches.Count -ne 1 -or $adapterMatches[0].Groups['value'].Value.Trim() -cnotin @('migration-unit', 'task', 'story', 'package', 'phase', 'milestone', 'none')) {
       $errors.Add('responsibility-evidence-missing')
     }
     else { $artifact.AdapterKind = $adapterMatches[0].Groups['value'].Value.Trim() }
     if ($errors.Count -ne 0) { $artifact.Row = $null; return $artifact }
     $selectedHeadingCount = @(Get-ArcMarkdownH2HeadingMatches -Text $Text -Heading 'Selected Migration Unit').Count
     if ($artifact.AdapterKind -ceq 'migration-unit') {
@@ -2955,21 +3289,30 @@ function Test-ResponsibilityHandoff {
     if ($row['Responsibility Contract Version'] -cne '1') { $errors.Add('responsibility-contract-version-invalid') }
     foreach ($field in @('Tree Conformance', 'Responsibility Conformance', 'Verification Ownership')) {
       if ($row[$field] -cnotin @('PASS', 'BLOCKED')) { $errors.Add('responsibility-waiver-forbidden') }
     }
     $derived = if (
       $row['Tree Conformance'] -ceq 'PASS' -and
       $row['Responsibility Conformance'] -ceq 'PASS' -and
       $row['Verification Ownership'] -ceq 'PASS'
     ) { 'PASS' } else { 'BLOCKED' }
     if ($row['Architecture Conformance State'] -cne $derived) { $errors.Add('responsibility-waiver-forbidden') }
-    if ($artifact.StepId -ceq '11-ai-review' -and $derived -cne 'PASS') { $errors.Add('responsibility-waiver-forbidden') }
+    if ($artifact.StepId -ceq '11-ai-review') {
+      if (
+        $null -eq $artifact.ReviewState -or
+        $artifact.ReviewState.Tree -cne $row['Tree Conformance'] -or
+        $artifact.ReviewState.Responsibility -cne $row['Responsibility Conformance'] -or
+        $artifact.ReviewState.Verification -cne $row['Verification Ownership'] -or
+        $artifact.ReviewState.Architecture -cne $row['Architecture Conformance State'] -or
+        $derived -cne 'PASS'
+      ) { $errors.Add('responsibility-waiver-forbidden') }
+    }
     if ($provenance['Task-base SHA'] -cnotmatch '^[0-9a-f]{40}$' -or $provenance['Final-tree SHA'] -cnotmatch '^[0-9a-f]{40}$') {
       $errors.Add('responsibility-evidence-missing')
     }
     foreach ($field in $provenanceColumns) {
       if ([string]::IsNullOrWhiteSpace($provenance[$field]) -or $provenance[$field] -match '<[^>]+>') {
         $errors.Add('responsibility-evidence-missing')
       }
     }
     if (
       $scope['Run ID'] -cnotmatch '^RUN-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -or
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/structural-gate.validation.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/structural-gate.validation.ps1
index de9af46..835b096 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/structural-gate.validation.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/structural-gate.validation.ps1
@@ -268,21 +268,22 @@ function Test-StructuralGate([string]$Root, [string]$ContractText) {
   }
   $workItemAdapterMatchesSelector = if ($selectorRow.'Adapter Kind' -ceq 'none') {
     $externalWorkItemMatches[0].'Delivery Adapter' -ceq 'none' -or $externalWorkItemMatches[0].'Delivery Adapter' -cmatch '^generic:[A-Za-z0-9][A-Za-z0-9._-]*$'
   }
   else {
     $externalWorkItemMatches[0].'Delivery Adapter' -ceq "$($selectorRow.'Adapter Kind'):$($selectorRow.'External ID')"
   }
   if (-not $workItemAdapterMatchesSelector -or $externalSelector.Acceptance -cne $externalWorkItemMatches[0].Acceptance -or $externalSelector.'Trace IDs' -cne $externalWorkItemMatches[0].'Trace IDs') {
     $errors.Add('Structural gate external Work Item and all canonical selector fields must agree exactly'); return
   }
-  $selectedUnitHeadingCount = @([regex]::Matches($report, '(?m)^## Selected Migration Unit[ \t]*$')).Count
+  $visibleReport = Get-ArcVisibleMarkdownText -Text $report
+  $selectedUnitHeadingCount = @(Get-ArcMarkdownH2HeadingMatches -Text $report -Heading 'Selected Migration Unit').Count
   $canonicalPlanText = $null
   if ($selectorRow.'Adapter Kind' -ceq 'migration-unit') {
     $canonicalPlanText = & $readAuthority $selectorRow.Authority 'canonical migration plan'
     if ($null -eq $canonicalPlanText) { return }
     $canonicalPlanFrontMatter = & $parseFrontMatter $canonicalPlanText
     if ($null -eq $canonicalPlanFrontMatter) { $errors.Add('Structural gate canonical migration plan frontmatter is invalid or spoofed'); return }
     if ((& $getFrontMatter $canonicalPlanFrontMatter 'status') -cne 'approved' -or (& $getFrontMatter $canonicalPlanFrontMatter 'result') -cne 'complete' -or (& $getFrontMatter $canonicalPlanFrontMatter 'revision') -cne $selectorRow.'Authority Revision') {
       $errors.Add('Structural gate migration-unit authority must be the exact external approved canonical plan revision'); return
     }
     $orderedUnitsHeading = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('Q8OhYyDEkcahbiB24buLIG1pZ3JhdGlvbiB0aGVvIHRo4bupIHThu7E='))
@@ -300,21 +301,21 @@ function Test-StructuralGate([string]$Root, [string]$ContractText) {
     $selectedUnit = & $getTable $report 'Selected Migration Unit' $selectedUnitColumns
     $selectedUnitRow = if ($null -ne $selectedUnit -and $selectedUnit.Rows.Count -eq 1) { $selectedUnit.Rows[0] } else { $null }
     $canonicalPlanReference = "$($selectorRow.Authority)@$($selectorRow.'Authority Revision')"
     if ($selectedUnitHeadingCount -ne 1 -or $null -eq $selectedUnitRow -or $selectedUnitRow.'Migration Unit ID' -cne $selectorRow.'External ID' -or $selectedUnitRow.'Plan Reference' -cne $canonicalPlanReference -or $selectedUnitRow.'Approval Reference' -cne $selectorRow.'Approval Reference' -or $selectedUnitRow.'Mode Constraint' -cne $externalSelector.'Mode Constraint' -or $selectedUnitRow.'Bootstrap Scope' -cne $unitMatches[0].'Bootstrap Scope' -or $selectedUnitRow.'Foundation Baseline ID' -cne $unitMatches[0].'Foundation Baseline ID' -or $selectedUnitRow.'Foundation Baseline Approval Reference' -cne $unitMatches[0].'Foundation Approval Reference' -or $selectedUnitRow.'Trace IDs' -cne $externalSelector.'Trace IDs' -or (& $missing $selectedUnitRow.'Baseline Reference')) {
       $errors.Add('Structural gate migration-unit adapter requires exact Selected Migration Unit evidence'); return
     }
     if ($externalSelector.'Mode Constraint' -ceq 'incremental/preserve-existing' -and $selectedUnitRow.'Foundation Baseline Reference' -cne 'not-applicable') {
       $errors.Add('Structural gate incremental Selected Migration Unit requires not-applicable foundation baseline reference'); return
     }
   }
-  elseif ($selectedUnitHeadingCount -ne 0 -or $report -match '(?m)^\|[^\n]*\bUNIT-[A-Z0-9-]+\b[^\n]*\|[ \t]*$') {
+  elseif ($selectedUnitHeadingCount -ne 0 -or $visibleReport -match '(?m)^\|[^\n]*\bUNIT-[A-Z0-9-]+\b[^\n]*\|[ \t]*\r?$') {
     $errors.Add('Structural gate generic adapter must omit Selected Migration Unit and all unit-specific IDs'); return
   }
 
   $matrixColumns = @('Work Item ID', 'Discovery Reference', 'Design Reference', 'Design Revision', 'Design Approval Evidence Reference', 'Matrix Approval Reference', 'Matrix Status')
   $matrix = & $getTable $report 'Conformance Matrix Reference' $matrixColumns
   if ($null -eq $matrix -or $matrix.Rows.Count -ne 1) { $errors.Add('Structural gate missing Conformance Matrix Reference'); return }
   $matrixRow = $matrix.Rows[0]
   if ($matrixRow.'Work Item ID' -cne $masterRow.'Work Item ID' -or (& $missing $matrixRow.'Design Reference') -or (& $missing $matrixRow.'Design Approval Evidence Reference') -or $matrixRow.'Design Revision' -cnotmatch '^[1-9][0-9]*$' -or $matrixRow.'Matrix Approval Reference' -cnotmatch '^approval:TECH-LEAD-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -or $matrixRow.'Matrix Status' -cne 'approved') {
     $errors.Add('Structural gate conformance matrix must be approved for the selected work item'); return
   }

# Review package: 08f172da2d9ba61305c613a07c1a8463b396797b..19e044d5576394ec4b68cb02b099b3ddc3453809

## Commits
19e044d test: cover responsibility conformance workflow

## Files changed
 .../tests/scenarios/architecture-review.Tests.ps1  | 204 +++++++++++
 .../responsibility-conformance.validation.ps1      | 407 ++++++++++++++-------
 2 files changed, 483 insertions(+), 128 deletions(-)

## Diff
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/architecture-review.Tests.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/architecture-review.Tests.ps1
index 69e9e17..46b616b 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/architecture-review.Tests.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/architecture-review.Tests.ps1
@@ -1128,20 +1128,21 @@ $lexicalOwnerMetadata = @'
 @responsibility RESP-LEXICAL
 @owner-symbol LexicalOwner
 @public-symbol LexicalOwner
 @owned-capability CAP-LEXICAL
 @effect none
 @architecture-authority target-exemplar
 @co-location-policy feature-local
 @verification-owner VERIFY-OWNER-LEXICAL
 '@
 
+$freshLexerFormatterResidualFailures = [Collections.Generic.List[string]]::new()
 foreach ($lexicalLineEnding in @(
   [pscustomobject]@{ Name = 'LF'; NewLine = "`n" },
   [pscustomobject]@{ Name = 'CRLF'; NewLine = "`r`n" }
 )) {
   $commentMatrixSource = @"
 # shell/python comment
 // C-family comment
 -- SQL comment
 ; Lisp comment
 /* C-family block comment
@@ -1332,20 +1333,167 @@ template operand
     return ratio;
   }
 }
 '@
   $javascriptTemplateDivision = Invoke-LexicalSourceInventoryProbe "javascript-template-division-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $javascriptTemplateDivisionSource 'src/lexical.ts'
   if ($javascriptTemplateDivision.Errors.Count -ne 0 -or $javascriptTemplateDivision.OwnerCount -ne 1) {
     throw "JavaScript division after a closed multiline template must remain valid ($($lexicalLineEnding.Name)): $($javascriptTemplateDivision.Errors -join '; ')"
   }
   Write-Output "PASS: JavaScript division after a closed multiline template remains valid ($($lexicalLineEnding.Name))"
 
+  foreach ($javascriptTemplateDivisionCase in @(
+    [pscustomobject]@{
+      Name = 'postfix increment and decrement before division'
+      Source = $javascriptOwnerMetadata + "`n" + @'
+class LexicalOwner {
+  run(value) {
+    const incrementRatio = `${value++ / 2}`;
+    const decrementRatio = `${value-- / 2}`;
+    return [incrementRatio, decrementRatio];
+  }
+}
+'@
+    },
+    [pscustomobject]@{
+      Name = 'multiline operand before division'
+      Source = $javascriptOwnerMetadata + "`n" + @'
+class LexicalOwner {
+  run(value) {
+    const ratio = `${value
+      / 2}`;
+    return ratio;
+  }
+}
+'@
+    }
+  )) {
+    $templateDivisionResult = Invoke-LexicalSourceInventoryProbe "template-expression-division-$($javascriptTemplateDivisionCase.Name.Replace(' ', '-'))-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $javascriptTemplateDivisionCase.Source 'src/lexical.ts'
+    if ($templateDivisionResult.Errors.Count -ne 0 -or $templateDivisionResult.OwnerCount -ne 1) {
+      $freshLexerFormatterResidualFailures.Add("C2a $($javascriptTemplateDivisionCase.Name) must remain division in template interpolation ($($lexicalLineEnding.Name)): $($templateDivisionResult.Errors -join '; ')")
+    }
+  }
+
+  $javascriptTemplateOperatorRegexSource = $javascriptOwnerMetadata + "`n" + @'
+class LexicalOwner {
+  run(value, text) {
+    const incrementThenAdd = `${value+++ /\{/.test(text)}`;
+    const decrementThenSubtract = `${value--- /\{/.test(text)}`;
+    return [incrementThenAdd, decrementThenSubtract];
+  }
+}
+'@
+  $javascriptTemplateOperatorRegex = Invoke-LexicalSourceInventoryProbe "template-operator-regex-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $javascriptTemplateOperatorRegexSource 'src/lexical.ts'
+  if ($javascriptTemplateOperatorRegex.Errors.Count -ne 0 -or $javascriptTemplateOperatorRegex.OwnerCount -ne 1) {
+    $freshLexerFormatterResidualFailures.Add("C2a a third plus/minus must remain a binary operator before an interpolation regex ($($lexicalLineEnding.Name)): $($javascriptTemplateOperatorRegex.Errors -join '; ')")
+  }
+
+  $javascriptTemplateKeywordRegexSource = $javascriptOwnerMetadata + "`n" + @'
+class LexicalOwner {
+  run(value) {
+    const kind = `${typeof
+      /\{/.test(value)}`;
+    return kind;
+  }
+}
+'@
+  $javascriptTemplateKeywordRegex = Invoke-LexicalSourceInventoryProbe "template-keyword-regex-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $javascriptTemplateKeywordRegexSource 'src/lexical.ts'
+  if ($javascriptTemplateKeywordRegex.Errors.Count -ne 0 -or $javascriptTemplateKeywordRegex.OwnerCount -ne 1) {
+    $freshLexerFormatterResidualFailures.Add("C2a a carried unary keyword must permit a real regex operand on the next interpolation line ($($lexicalLineEnding.Name)): $($javascriptTemplateKeywordRegex.Errors -join '; ')")
+  }
+
+  $javascriptTemplateRegexSource = $javascriptOwnerMetadata + "`n" + @'
+class LexicalOwner {
+  run(value) {
+    const matches = `${value ? /}/g.test(value) : false}`;
+    return matches;
+  }
+}
+'@
+  $javascriptTemplateRegex = Invoke-LexicalSourceInventoryProbe "template-regex-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $javascriptTemplateRegexSource 'src/lexical.ts'
+  if ($javascriptTemplateRegex.Errors.Count -ne 0 -or $javascriptTemplateRegex.OwnerCount -ne 1) {
+    $freshLexerFormatterResidualFailures.Add("C2a a real regex literal in template interpolation must remain inert ($($lexicalLineEnding.Name)): $($javascriptTemplateRegex.Errors -join '; ')")
+  }
+
+  $javascriptTemplateRegexRogueSource = $javascriptOwnerMetadata + "`n" + @'
+class LexicalOwner {
+  run(value) {
+    const matches = `${value ? /{/g.test(value) : false}`;
+    return matches;
+  }
+}
+danger()
+'@
+  $javascriptTemplateRegexRogue = Invoke-LexicalSourceInventoryProbe "template-regex-rogue-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $javascriptTemplateRegexRogueSource 'src/lexical.ts'
+  if ($javascriptTemplateRegexRogue.Errors -cnotcontains 'responsibility-evidence-missing') {
+    $freshLexerFormatterResidualFailures.Add("C2a an opening brace in a real interpolation regex must not swallow later rogue code ($($lexicalLineEnding.Name))")
+  }
+
+  $unterminatedJavascriptTemplateRegexSource = $javascriptOwnerMetadata + "`n" + @'
+class LexicalOwner {
+  run(value) {
+    const matches = `${value ? /unterminated
+      : false}`;
+    return matches;
+  }
+}
+'@
+  $unterminatedJavascriptTemplateRegex = Invoke-LexicalSourceInventoryProbe "unterminated-template-regex-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $unterminatedJavascriptTemplateRegexSource 'src/lexical.ts'
+  if ($unterminatedJavascriptTemplateRegex.Errors -cnotcontains 'responsibility-evidence-missing') {
+    $freshLexerFormatterResidualFailures.Add("C2a an unclosed real regex literal in template interpolation must fail closed ($($lexicalLineEnding.Name))")
+  }
+
+  $javascriptOrdinaryBacktickStringSource = $javascriptOwnerMetadata + "`n" + @'
+class LexicalOwner {
+  run(value) {
+    const doubleQuoted = `${value ? "a`" : "b"}`;
+    const singleQuoted = `${value ? 'a`' : 'b'}`;
+    const escapedQuotes = `${value ? "a\"b" : 'a\'b'}`;
+    return [doubleQuoted, singleQuoted, escapedQuotes];
+  }
+}
+'@
+  $javascriptOrdinaryBacktickString = Invoke-LexicalSourceInventoryProbe "ordinary-backtick-string-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $javascriptOrdinaryBacktickStringSource 'src/lexical.ts'
+  if ($javascriptOrdinaryBacktickString.Errors.Count -ne 0 -or $javascriptOrdinaryBacktickString.OwnerCount -ne 1) {
+    $freshLexerFormatterResidualFailures.Add("C2b backticks must be ordinary characters and backslashes the escape in JavaScript quoted strings ($($lexicalLineEnding.Name)): $($javascriptOrdinaryBacktickString.Errors -join '; ')")
+  }
+
+  foreach ($unterminatedOrdinaryStringCase in @(
+    [pscustomobject]@{
+      Name = 'ordinary double-quoted string at EOL'
+      Source = $javascriptOwnerMetadata + "`n" + @'
+class LexicalOwner {
+  run() {
+    const payload = "unterminated
+    return payload;
+  }
+}
+'@
+    },
+    [pscustomobject]@{
+      Name = 'ordinary single-quoted string in interpolation at EOL'
+      Source = $javascriptOwnerMetadata + "`n" + @'
+class LexicalOwner {
+  run(value) {
+    const payload = `${value ? 'unterminated
+      : 'fallback'}`;
+    return payload;
+  }
+}
+'@
+    }
+  )) {
+    $unterminatedOrdinaryString = Invoke-LexicalSourceInventoryProbe "unterminated-ordinary-string-$($unterminatedOrdinaryStringCase.Name.Replace(' ', '-'))-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $unterminatedOrdinaryStringCase.Source 'src/lexical.ts'
+    if ($unterminatedOrdinaryString.Errors -cnotcontains 'responsibility-evidence-missing') {
+      $freshLexerFormatterResidualFailures.Add("C2b $($unterminatedOrdinaryStringCase.Name) must fail closed ($($lexicalLineEnding.Name))")
+    }
+  }
+
   $unterminatedJavascriptTemplateSource = $javascriptOwnerMetadata + "`n" + @'
 class LexicalOwner {
   run() {
     const payload = `unterminated template
 literal opening brace is inert: {
   }
 }
 '@
   $unterminatedJavascriptTemplate = Invoke-LexicalSourceInventoryProbe "unterminated-javascript-template-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $unterminatedJavascriptTemplateSource 'src/lexical.ts'
   if ($unterminatedJavascriptTemplate.Errors -cnotcontains 'responsibility-evidence-missing') {
@@ -1409,20 +1557,76 @@ class LexicalOwner {
 {
 danger()
 "@
   $unterminatedMultiline = Invoke-LexicalSourceInventoryProbe "unterminated-multiline-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $unterminatedMultilineSource
   if ($unterminatedMultiline.Errors -cnotcontains 'responsibility-evidence-missing') {
     throw "unterminated multiline literal ambiguity must fail closed ($($lexicalLineEnding.Name))"
   }
   Write-Output "PASS: unterminated multiline literal ambiguity fails closed ($($lexicalLineEnding.Name))"
 }
 
+$formatterGrammarCases = @(
+  [pscustomobject]@{ Expected = $true; Name = 'Prettier boolean and scalar options'; Command = 'prettier --write --print-width 100 src/admin_route.source' },
+  [pscustomobject]@{ Expected = $true; Name = 'Windows command suffix for Prettier'; Command = 'prettier.cmd --write src/admin_route.source' },
+  [pscustomobject]@{ Expected = $true; Name = 'Black module wrapper and scalar option'; Command = 'python -m black --check --line-length=100 src/admin_route.source' },
+  [pscustomobject]@{ Expected = $true; Name = 'npx Prettier wrapper'; Command = 'npx prettier --write src/admin_route.source' },
+  [pscustomobject]@{ Expected = $true; Name = 'Windows command suffix for npx wrapper'; Command = 'npx.cmd prettier --write src/admin_route.source' },
+  [pscustomobject]@{ Expected = $true; Name = 'gofmt switch'; Command = 'gofmt -w src/admin_route.source' },
+  [pscustomobject]@{ Expected = $true; Name = 'rustfmt scalar option'; Command = 'rustfmt --edition 2021 src/admin_route.source' },
+  [pscustomobject]@{ Expected = $true; Name = 'clang-format switch and inline scalar'; Command = 'clang-format -i --style=LLVM src/admin_route.source' },
+  [pscustomobject]@{ Expected = $true; Name = 'direct CSharpier switch'; Command = 'csharpier --check src/admin_route.source' },
+  [pscustomobject]@{ Expected = $true; Name = 'StyLua switch and scalar'; Command = 'stylua --check --column-width 100 src/admin_route.source' },
+  [pscustomobject]@{ Expected = $true; Name = 'shfmt short switch and scalar'; Command = 'shfmt -w -i 2 src/admin_route.source' },
+  [pscustomobject]@{ Expected = $true; Name = 'Go fmt subcommand'; Command = 'go fmt -n src/admin_route.source' },
+  [pscustomobject]@{ Expected = $true; Name = 'Cargo fmt subcommand'; Command = 'cargo fmt --check --package admin src/admin_route.source' },
+  [pscustomobject]@{ Expected = $true; Name = 'Deno fmt subcommand'; Command = 'deno fmt --check --line-width 100 src/admin_route.source' },
+  [pscustomobject]@{ Expected = $true; Name = 'dotnet CSharpier wrapper'; Command = 'dotnet csharpier --check src/admin_route.source' },
+  [pscustomobject]@{ Expected = $true; Name = 'bunx Biome wrapper'; Command = 'bunx biome format --write src/admin_route.source' },
+  [pscustomobject]@{ Expected = $true; Name = 'npm exec Prettier wrapper'; Command = 'npm exec prettier --write src/admin_route.source' },
+  [pscustomobject]@{ Expected = $true; Name = 'pnpm exec Biome wrapper'; Command = 'pnpm exec biome format --write src/admin_route.source' },
+  [pscustomobject]@{ Expected = $true; Name = 'yarn exec Prettier wrapper'; Command = 'yarn exec prettier --write src/admin_route.source' },
+  [pscustomobject]@{ Expected = $true; Name = 'bun exec Biome wrapper'; Command = 'bun exec biome format --write src/admin_route.source' },
+  [pscustomobject]@{ Expected = $true; Name = 'uv run Ruff wrapper'; Command = 'uv run ruff format --check src/admin_route.source' },
+  [pscustomobject]@{ Expected = $true; Name = 'pipx run Black wrapper'; Command = 'pipx run black --check src/admin_route.source' },
+  [pscustomobject]@{ Expected = $true; Name = 'Python3 Ruff module wrapper'; Command = 'python3 -m ruff format --check src/admin_route.source' },
+  [pscustomobject]@{ Expected = $true; Name = 'py Black module wrapper'; Command = 'py -m black --check src/admin_route.source' },
+  [pscustomobject]@{ Expected = $false; Name = 'direct generic format executable'; Command = 'format src/admin_route.source' },
+  [pscustomobject]@{ Expected = $false; Name = 'direct generic fmt executable'; Command = 'fmt src/admin_route.source' },
+  [pscustomobject]@{ Expected = $false; Name = 'unknown executable'; Command = 'formatter-proxy src/admin_route.source' },
+  [pscustomobject]@{ Expected = $false; Name = 'whitelisted-looking executable with an unknown suffix'; Command = 'prettier.evil --write src/admin_route.source' },
+  [pscustomobject]@{ Expected = $false; Name = 'whitelisted-looking wrapper with an unknown suffix'; Command = 'npx.evil prettier --write src/admin_route.source' },
+  [pscustomobject]@{ Expected = $false; Name = 'unknown Dart option'; Command = 'dart format --write src/admin_route.source' },
+  [pscustomobject]@{ Expected = $false; Name = 'cross-tool Prettier option'; Command = 'prettier --line-length 100 src/admin_route.source' },
+  [pscustomobject]@{ Expected = $false; Name = 'case-variant Prettier scalar option'; Command = 'prettier --PRINT-WIDTH 100 src/admin_route.source' },
+  [pscustomobject]@{ Expected = $false; Name = 'unknown Ruff option'; Command = 'ruff format --write src/admin_route.source' },
+  [pscustomobject]@{ Expected = $false; Name = 'unknown option after the target'; Command = 'prettier --write src/admin_route.source --mystery' },
+  [pscustomobject]@{ Expected = $false; Name = 'inline value attached to a switch'; Command = 'prettier --write=true src/admin_route.source' },
+  [pscustomobject]@{ Expected = $false; Name = 'missing Prettier scalar value'; Command = 'prettier src/admin_route.source --print-width' },
+  [pscustomobject]@{ Expected = $false; Name = 'missing Dart enum value'; Command = 'dart format src/admin_route.source --output' },
+  [pscustomobject]@{ Expected = $false; Name = 'invalid rustfmt scalar value'; Command = 'rustfmt --edition latest src/admin_route.source' },
+  [pscustomobject]@{ Expected = $false; Name = 'target consumed as a separated scalar value'; Command = 'prettier --print-width src/admin_route.source' },
+  [pscustomobject]@{ Expected = $false; Name = 'target consumed as an inline scalar value'; Command = 'prettier --print-width=src/admin_route.source' },
+  [pscustomobject]@{ Expected = $false; Name = 'unsupported Python module wrapper'; Command = 'python -m prettier src/admin_route.source' },
+  [pscustomobject]@{ Expected = $false; Name = 'generic package script wrapper'; Command = 'npm run format src/admin_route.source' },
+  [pscustomobject]@{ Expected = $false; Name = 'unknown npx wrapped executable'; Command = 'npx formatter-proxy src/admin_route.source' }
+)
+foreach ($formatterGrammarCase in $formatterGrammarCases) {
+  $actual = Test-ArcPathScopedFormatterCommand -Command $formatterGrammarCase.Command -CanonicalPath 'src/admin_route.source'
+  if ($actual -ne $formatterGrammarCase.Expected) {
+    $freshLexerFormatterResidualFailures.Add("I10 $($formatterGrammarCase.Name) expected $($formatterGrammarCase.Expected) but got $($actual): $($formatterGrammarCase.Command)")
+  }
+}
+if ($freshLexerFormatterResidualFailures.Count -ne 0) {
+  throw "Fresh C2a/C2b/I10 regression matrix failed:`n - $($freshLexerFormatterResidualFailures -join "`n - ")"
+}
+Write-Output 'PASS: fresh C2a/C2b LF/CRLF and I10 exact-grammar regression matrix'
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
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1
index 77e28df..fcc59e0 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1
@@ -1536,157 +1536,263 @@ function Test-ArcPathScopedFormatterCommand {
   $tokenPattern = '(?<!\S)(?:"(?<double>[^"]*)"|''(?<single>[^'']*)''|(?<bare>[^\s"'']+))(?!\S)'
   $tokenMatches = @([regex]::Matches($Command, $tokenPattern))
   if (-not [string]::IsNullOrWhiteSpace([regex]::Replace($Command, $tokenPattern, ''))) { return $false }
   $tokens = @($tokenMatches | ForEach-Object {
     if ($_.Groups['double'].Success) { $_.Groups['double'].Value }
     elseif ($_.Groups['single'].Success) { $_.Groups['single'].Value }
     else { $_.Groups['bare'].Value }
   })
   if ($tokens.Count -lt 2) { return $false }
 
-  $directFormatterWords = @('format', 'fmt', 'prettier', 'black', 'gofmt', 'rustfmt', 'clang-format', 'csharpier', 'stylua', 'shfmt')
-  $formatSubcommandFormatterWords = @('ruff', 'biome')
-  $knownFormatterWords = @($directFormatterWords + $formatSubcommandFormatterWords)
-  $commandPrefixIndices = @(0)
   $executableLeaf = @($tokens[0].Replace('\', '/') -split '/')[-1]
-  $executableName = [IO.Path]::GetFileNameWithoutExtension($executableLeaf).ToLowerInvariant()
-  $recognizedFormatterCommand = $directFormatterWords -ccontains $executableName
-  $pythonLauncher = $executableName -in @('python', 'python3', 'py')
-  $firstWord = if ($tokens.Count -gt 1) { $tokens[1].ToLowerInvariant() } else { '' }
-  $secondWord = if ($tokens.Count -gt 2) { $tokens[2].ToLowerInvariant() } else { '' }
-  $thirdWord = if ($tokens.Count -gt 3) { $tokens[3].ToLowerInvariant() } else { '' }
-  if (
-    ($pythonLauncher -and $firstWord -in @('-m', '--module') -and $formatSubcommandFormatterWords -ccontains $secondWord -and $thirdWord -ceq 'format') -or
-    ($executableName -in @('npm', 'pnpm', 'yarn', 'bun') -and $firstWord -ceq 'exec' -and $formatSubcommandFormatterWords -ccontains $secondWord -and $thirdWord -ceq 'format') -or
-    ($executableName -in @('uv', 'pipx') -and $firstWord -ceq 'run' -and $formatSubcommandFormatterWords -ccontains $secondWord -and $thirdWord -ceq 'format')
-  ) {
-    $commandPrefixIndices += @(1, 2, 3)
-    $recognizedFormatterCommand = $true
-  }
-  elseif (
-    ($pythonLauncher -and $firstWord -cmatch '^(?:-m|--module)=(?:ruff|biome)$' -and $secondWord -ceq 'format') -or
-    ($executableName -in @('npx', 'bunx', 'pnpm', 'yarn', 'bun') -and $formatSubcommandFormatterWords -ccontains $firstWord -and $secondWord -ceq 'format')
-  ) {
-    $commandPrefixIndices += @(1, 2)
-    $recognizedFormatterCommand = $true
-  }
-  elseif (
-    ($formatSubcommandFormatterWords -ccontains $executableName -and $firstWord -ceq 'format') -or
-    ($executableName -ceq 'dart' -and $firstWord -ceq 'format') -or
-    ($executableName -in @('go', 'cargo', 'deno') -and $firstWord -ceq 'fmt') -or
-    ($executableName -ceq 'dotnet' -and $firstWord -ceq 'csharpier') -or
-    ($executableName -in @('npx', 'bunx') -and $directFormatterWords -ccontains $firstWord) -or
-    ($executableName -in @('pnpm', 'yarn', 'bun') -and $directFormatterWords -ccontains $firstWord)
-  ) {
-    $commandPrefixIndices += 1
-    $recognizedFormatterCommand = $true
+  $normalizedExecutableLeaf = $executableLeaf.ToLowerInvariant()
+  $executableSuffix = [IO.Path]::GetExtension($normalizedExecutableLeaf)
+  if ($executableSuffix -cnotin @('', '.exe', '.cmd', '.bat', '.com', '.ps1')) { return $false }
+  $executableName = if ($executableSuffix -ceq '') {
+    $normalizedExecutableLeaf
   }
-  elseif (
-    ($executableName -ceq 'npm' -and (($firstWord -ceq 'exec' -and $directFormatterWords -ccontains $secondWord) -or ($firstWord -ceq 'run' -and $secondWord -in @('format', 'fmt')))) -or
-    ($executableName -in @('pnpm', 'yarn', 'bun') -and (($firstWord -ceq 'exec' -and $directFormatterWords -ccontains $secondWord) -or ($firstWord -ceq 'run' -and $secondWord -in @('format', 'fmt')))) -or
-    ($executableName -in @('uv', 'pipx') -and $firstWord -ceq 'run' -and $directFormatterWords -ccontains $secondWord)
-  ) {
-    $commandPrefixIndices += @(1, 2)
-    $recognizedFormatterCommand = $true
+  else {
+    [IO.Path]::GetFileNameWithoutExtension($normalizedExecutableLeaf)
   }
+  if (
+    [string]::IsNullOrWhiteSpace($executableName) -or
+    $tokens[0].StartsWith('-', [StringComparison]::Ordinal) -or
+    $tokens[0] -match '[*?\[\]]' -or
+    (ConvertTo-ArcCanonicalRepositoryPath -Path $CanonicalPath) -cne $CanonicalPath
+  ) { return $false }
 
-  $targetCount = 0
-  $pendingScalarOption = ''
-  $pathScalarOptionPattern = '(?:file|path|config|director|(?:^|[-_])dirs?(?:$|[-_])|include|exclude|glob|input)'
-  $numericScalarOptions = @('--line-length', '--print-width', '--tab-width', '--workers', '--jobs', '--range-start', '--range-end', '--indent-size')
-  $moduleScalarOptions = @('-m', '--module')
-  $enumScalarOptions = [ordered]@{
-    '-o' = @('show', 'json', 'none', 'write')
-    '--output' = @('show', 'json', 'none', 'write')
-    '--style' = @('llvm', 'google', 'chromium', 'mozilla', 'webkit', 'microsoft', 'gnu', 'file')
-    '--parser' = @('angular', 'babel', 'babel-flow', 'babel-ts', 'css', 'espree', 'flow', 'glimmer', 'graphql', 'html', 'json', 'json5', 'json-stringify', 'less', 'lwc', 'markdown', 'mdx', 'meriyah', 'scss', 'typescript', 'vue', 'yaml')
-    '--end-of-line' = @('lf', 'crlf', 'cr', 'auto')
-    '--trailing-comma' = @('all', 'es5', 'none')
-    '--quote-props' = @('as-needed', 'consistent', 'preserve')
-    '--prose-wrap' = @('always', 'never', 'preserve')
-    '--embedded-language-formatting' = @('auto', 'off')
-  }
-  for ($tokenIndex = 0; $tokenIndex -lt $tokens.Count; $tokenIndex++) {
-    $token = $tokens[$tokenIndex]
-    if ([string]::IsNullOrWhiteSpace($token)) { return $false }
-    if ($tokenIndex -eq 0) {
-      if ($token.StartsWith('-', [StringComparison]::Ordinal) -or $token -match '[*?\[\]]') { return $false }
-      continue
+  $formatterId = ''
+  $argumentIndex = -1
+  $word = {
+    param([int]$Index)
+    if ($Index -ge $tokens.Count) { return '' }
+    return $tokens[$Index].ToLowerInvariant()
+  }
+  $firstWord = & $word 1
+  $secondWord = & $word 2
+  $thirdWord = & $word 3
+
+  $directFormatters = @('prettier', 'black', 'gofmt', 'rustfmt', 'clang-format', 'csharpier', 'stylua', 'shfmt')
+  if ($directFormatters -ccontains $executableName) {
+    $formatterId = $executableName
+    $argumentIndex = 1
+  }
+  elseif ($executableName -in @('ruff', 'biome', 'dart') -and $firstWord -ceq 'format') {
+    $formatterId = $executableName
+    $argumentIndex = 2
+  }
+  elseif ($executableName -in @('go', 'cargo', 'deno') -and $firstWord -ceq 'fmt') {
+    $formatterId = $executableName
+    $argumentIndex = 2
+  }
+  elseif ($executableName -ceq 'dotnet' -and $firstWord -ceq 'csharpier') {
+    $formatterId = 'csharpier'
+    $argumentIndex = 2
+  }
+  elseif ($executableName -in @('python', 'python3', 'py') -and $firstWord -ceq '-m') {
+    if ($secondWord -ceq 'ruff' -and $thirdWord -ceq 'format') {
+      $formatterId = 'ruff'
+      $argumentIndex = 4
+    }
+    elseif ($secondWord -ceq 'black') {
+      $formatterId = 'black'
+      $argumentIndex = 3
+    }
+  }
+  elseif ($executableName -in @('npx', 'bunx')) {
+    if ($firstWord -ceq 'biome' -and $secondWord -ceq 'format') {
+      $formatterId = 'biome'
+      $argumentIndex = 3
+    }
+    elseif ($firstWord -ceq 'prettier') {
+      $formatterId = 'prettier'
+      $argumentIndex = 2
+    }
+  }
+  elseif ($executableName -in @('npm', 'pnpm', 'yarn', 'bun') -and $firstWord -ceq 'exec') {
+    if ($secondWord -ceq 'biome' -and $thirdWord -ceq 'format') {
+      $formatterId = 'biome'
+      $argumentIndex = 4
+    }
+    elseif ($secondWord -ceq 'prettier') {
+      $formatterId = 'prettier'
+      $argumentIndex = 3
+    }
+  }
+  elseif ($executableName -in @('uv', 'pipx') -and $firstWord -ceq 'run') {
+    if ($secondWord -ceq 'ruff' -and $thirdWord -ceq 'format') {
+      $formatterId = 'ruff'
+      $argumentIndex = 4
+    }
+    elseif ($secondWord -ceq 'black') {
+      $formatterId = 'black'
+      $argumentIndex = 3
+    }
+  }
+  if ($formatterId -ceq '' -or $argumentIndex -lt 0 -or $argumentIndex -ge $tokens.Count) { return $false }
+
+  $positiveInteger = '^[1-9][0-9]*$'
+  $nonnegativeInteger = '^[0-9]+$'
+  $formatterOptionGrammar = @{
+    'dart' = @{
+      Switches = @('--set-exit-if-changed', '--follow-links')
+      Values = @{
+        '--line-length' = $positiveInteger
+        '--output' = '^(?:show|json|none|write)$'
+        '-o' = '^(?:show|json|none|write)$'
+      }
+    }
+    'ruff' = @{
+      Switches = @('--check', '--diff', '--quiet', '--verbose', '--no-cache', '--respect-gitignore', '--no-respect-gitignore', '--preview', '--no-preview')
+      Values = @{
+        '--line-length' = $positiveInteger
+        '--target-version' = '^py[0-9]{2,3}$'
+      }
+    }
+    'biome' = @{
+      Switches = @('--write', '--fix', '--unsafe', '--verbose', '--colors', '--no-colors')
+      Values = @{
+        '--line-width' = $positiveInteger
+        '--indent-width' = $positiveInteger
+        '--indent-style' = '^(?:tab|space)$'
+        '--line-ending' = '^(?:lf|crlf|cr)$'
+        '--quote-style' = '^(?:double|single)$'
+      }
     }
-    if ($commandPrefixIndices -ccontains $tokenIndex) { continue }
-    if ($token -ceq $CanonicalPath) {
-      if ($pendingScalarOption -cne '') { return $false }
-      $targetCount++
-      continue
+    'prettier' = @{
+      Switches = @(
+        '--write', '--check', '--list-different', '--debug-check', '--use-tabs', '--single-quote',
+        '--jsx-single-quote', '--semi', '--no-semi', '--bracket-spacing', '--no-bracket-spacing',
+        '--bracket-same-line', '--no-bracket-same-line', '--vue-indent-script-and-style',
+        '--no-vue-indent-script-and-style'
+      )
+      Values = @{
+        '--print-width' = $positiveInteger
+        '--tab-width' = $positiveInteger
+        '--range-start' = $nonnegativeInteger
+        '--range-end' = $nonnegativeInteger
+        '--parser' = '^(?:angular|babel|babel-flow|babel-ts|css|espree|flow|glimmer|graphql|html|json|json5|json-stringify|less|lwc|markdown|mdx|meriyah|scss|typescript|vue|yaml)$'
+        '--end-of-line' = '^(?:lf|crlf|cr|auto)$'
+        '--trailing-comma' = '^(?:all|es5|none)$'
+        '--quote-props' = '^(?:as-needed|consistent|preserve)$'
+        '--prose-wrap' = '^(?:always|never|preserve)$'
+        '--embedded-language-formatting' = '^(?:auto|off)$'
+        '--html-whitespace-sensitivity' = '^(?:css|strict|ignore)$'
+        '--arrow-parens' = '^(?:always|avoid)$'
+      }
+    }
+    'black' = @{
+      Switches = @(
+        '--check', '--diff', '--color', '--fast', '--safe', '--preview', '--quiet', '--verbose',
+        '--skip-string-normalization', '--skip-magic-trailing-comma'
+      )
+      Values = @{
+        '--line-length' = $positiveInteger
+        '--target-version' = '^py[0-9]{2,3}$'
+        '--workers' = $positiveInteger
+      }
     }
-
-    if ($pendingScalarOption -cne '') {
-      $scalarValue = $token.ToLowerInvariant()
-      $validScalar =
-        ($numericScalarOptions -ccontains $pendingScalarOption -and $token -cmatch '^[0-9]+(?:\.[0-9]+)?$') -or
-        ($moduleScalarOptions -ccontains $pendingScalarOption -and $knownFormatterWords -ccontains $scalarValue) -or
-        ($pendingScalarOption -ceq '--target-version' -and $scalarValue -cmatch '^(?:py)?[0-9]{2,3}$') -or
-        ($enumScalarOptions.Contains($pendingScalarOption) -and @($enumScalarOptions[$pendingScalarOption]) -ccontains $scalarValue)
-      if (-not $validScalar) { return $false }
-      if ($pythonLauncher -and $moduleScalarOptions -ccontains $pendingScalarOption -and $directFormatterWords -ccontains $scalarValue) {
-        $recognizedFormatterCommand = $true
+    'gofmt' = @{
+      Switches = @('-w', '-d', '-e', '-s')
+      Values = @{}
+    }
+    'rustfmt' = @{
+      Switches = @('--check', '--quiet', '--verbose')
+      Values = @{
+        '--edition' = '^(?:2015|2018|2021|2024)$'
+        '--emit' = '^(?:files|stdout|coverage|modified-lines|checkstyle|json)$'
+        '--color' = '^(?:auto|always|never)$'
+      }
+    }
+    'clang-format' = @{
+      Switches = @('-i', '--dry-run', '--werror', '--verbose', '--sort-includes', '--no-sort-includes')
+      Values = @{
+        '--style' = '^(?i:llvm|google|chromium|mozilla|webkit|microsoft|gnu|file)$'
+      }
+    }
+    'csharpier' = @{
+      Switches = @('--check', '--fast', '--write-stdout')
+      Values = @{
+        '--log-level' = '^(?:trace|debug|information|warning|error|critical|none)$'
+      }
+    }
+    'stylua' = @{
+      Switches = @('--check', '--verify', '--verbose')
+      Values = @{
+        '--column-width' = $positiveInteger
+        '--indent-width' = $positiveInteger
+        '--indent-type' = '^(?:Tabs|Spaces)$'
+        '--line-endings' = '^(?:Unix|Windows)$'
+        '--quote-style' = '^(?:AutoPreferDouble|AutoPreferSingle|ForceDouble|ForceSingle)$'
+        '--call-parentheses' = '^(?:Always|NoSingleString|NoSingleTable|None|Input)$'
+      }
+    }
+    'shfmt' = @{
+      Switches = @('-w', '-d', '-s', '-mn', '-ci', '-sr', '-kp', '-fn')
+      Values = @{
+        '-i' = $nonnegativeInteger
+        '-ln' = '^(?:bash|posix|mksh|bats)$'
+      }
+    }
+    'go' = @{
+      Switches = @('-n', '-x')
+      Values = @{
+        '-mod' = '^(?:readonly|vendor|mod)$'
       }
-      $pendingScalarOption = ''
-      continue
     }
+    'cargo' = @{
+      Switches = @('--check', '--quiet', '--verbose')
+      Values = @{
+        '--package' = '^[A-Za-z0-9][A-Za-z0-9_.-]*$'
+      }
+    }
+    'deno' = @{
+      Switches = @('--check', '--use-tabs', '--single-quote', '--no-semicolons', '--unstable-component')
+      Values = @{
+        '--line-width' = $positiveInteger
+        '--indent-width' = $positiveInteger
+        '--prose-wrap' = '^(?:always|never|preserve)$'
+        '--ext' = '^(?:ts|tsx|js|jsx|md|json|jsonc|css|scss|sass|less|html|vue|svelte|astro|yml|yaml|ipynb)$'
+      }
+    }
+  }
 
+  $optionGrammar = $formatterOptionGrammar[$formatterId]
+  if ($null -eq $optionGrammar) { return $false }
+  $targetCount = 0
+  for ($tokenIndex = $argumentIndex; $tokenIndex -lt $tokens.Count; $tokenIndex++) {
+    $token = $tokens[$tokenIndex]
+    if ([string]::IsNullOrWhiteSpace($token)) { return $false }
     if ($token.StartsWith('-', [StringComparison]::Ordinal)) {
-      if ($token -cin @('--all', '--recursive') -or $token -match '[*?\[\]]') { return $false }
       $optionParts = @($token -split '=', 2)
-      $optionName = $optionParts[0].ToLowerInvariant()
-      if ($optionName -match $pathScalarOptionPattern) { return $false }
+      $optionName = $optionParts[0]
       $hasInlineValue = $token.IndexOf('=', [StringComparison]::Ordinal) -ge 0
-      if ($hasInlineValue) {
-        $inlineValue = $optionParts[1]
-        $canonicalInlineValue = ConvertTo-ArcCanonicalRepositoryPath -Path $inlineValue
-        if (
-          [string]::IsNullOrWhiteSpace($inlineValue) -or
-          $inlineValue -match '[\\/]' -or
-          $inlineValue -match '[*?\[\]]' -or
-          $inlineValue -cmatch '^[A-Za-z]:' -or
-          $inlineValue.StartsWith('/', [StringComparison]::Ordinal) -or
-          ($canonicalInlineValue -ne '' -and $inlineValue -cmatch '\.[A-Za-z0-9_-]+$')
-        ) { return $false }
-        $inlineScalarValue = $inlineValue.ToLowerInvariant()
-        $validInlineScalar =
-          ($numericScalarOptions -ccontains $optionName -and $inlineValue -cmatch '^[0-9]+(?:\.[0-9]+)?$') -or
-          ($moduleScalarOptions -ccontains $optionName -and $knownFormatterWords -ccontains $inlineScalarValue) -or
-          ($optionName -ceq '--target-version' -and $inlineScalarValue -cmatch '^(?:py)?[0-9]{2,3}$') -or
-          ($enumScalarOptions.Contains($optionName) -and @($enumScalarOptions[$optionName]) -ccontains $inlineScalarValue)
-        if (-not $validInlineScalar) { return $false }
-        if ($pythonLauncher -and $moduleScalarOptions -ccontains $optionName -and $directFormatterWords -ccontains $inlineScalarValue) {
-          $recognizedFormatterCommand = $true
-        }
+      if (@($optionGrammar.Switches) -ccontains $optionName) {
+        if ($hasInlineValue) { return $false }
+        continue
       }
-      elseif ($numericScalarOptions -ccontains $optionName -or $moduleScalarOptions -ccontains $optionName -or $optionName -ceq '--target-version' -or $enumScalarOptions.Contains($optionName)) {
-        $pendingScalarOption = $optionName
+      if (@($optionGrammar.Values.Keys) -cnotcontains $optionName) { return $false }
+      $optionValue = if ($hasInlineValue) {
+        $optionParts[1]
       }
+      else {
+        $tokenIndex++
+        if ($tokenIndex -ge $tokens.Count) { return $false }
+        $tokens[$tokenIndex]
+      }
+      if ([string]::IsNullOrWhiteSpace($optionValue) -or $optionValue -cnotmatch $optionGrammar.Values[$optionName]) { return $false }
       continue
     }
-
-    $canonicalOperand = ConvertTo-ArcCanonicalRepositoryPath -Path $token
-    $looksLikePath =
-      $token -cin @('.', './', '..', '../', '*', '**') -or
-      $token -match '[\\/]' -or
-      $token -match '[*?\[\]]' -or
-      $token -cmatch '^[A-Za-z]:' -or
-      $token.StartsWith('/', [StringComparison]::Ordinal) -or
-      ($canonicalOperand -ne '' -and $token -cmatch '\.[A-Za-z0-9_-]+$')
-    if ($looksLikePath) { return $false }
-    return $false
+    if ($token -cne $CanonicalPath) { return $false }
+    $targetCount++
   }
-  return $recognizedFormatterCommand -and $targetCount -eq 1 -and $pendingScalarOption -ceq ''
+  return $targetCount -eq 1
 }
 
 function Get-ArcImplementationReviewProvenance {
   [CmdletBinding()]
   param([Parameter(Mandatory)][string]$ImplementationText, [Parameter(Mandatory)][AllowEmptyCollection()][Collections.Generic.List[string]]$Errors)
 
   $columns = @('Task / Unit', 'File', 'File Kind', 'Edited Region / Symbol', 'Formatter Command', 'Unrelated Diff', 'Checkpoint History', 'Task-base SHA', 'Final-tree SHA')
   $tableErrors = [Collections.Generic.List[string]]::new()
   $table = @(Get-ArcStrictMarkdownTable -Text $ImplementationText -Heading 'Change Hygiene' -Columns $columns -Errors $tableErrors)
   if ($tableErrors.Count -ne 0) {
@@ -1817,20 +1923,43 @@ function Get-ArcSourceLexicalLines {
   $hashDirectiveLanguage = $extension -in @('.cs', '.rs')
   $javascriptLanguage = $extension -in @('.js', '.jsx', '.mjs', '.cjs', '.ts', '.tsx')
   $cStyleBlockComment = $unknownLanguage -or $extension -in ($cFamilyExtensions + @('.css', '.sql'))
   $markupBlockComment = $unknownLanguage -or $extension -in @('.html', '.htm', '.xml', '.md', '.markdown')
   $powerShellBlockComment = $unknownLanguage -or $extension -in @('.ps1', '.psm1', '.psd1')
   $blockCommentEnd = ''
   $blockCommentStart = -1
   $multilineStringDelimiter = ''
   $multilineStringStart = -1
   $javascriptTemplateStack = [Collections.Generic.List[object]]::new()
+  $javascriptRegexCanStartAfter = {
+    param([AllowEmptyString()][string]$Prefix)
+
+    $significantPrefix = $Prefix.TrimEnd()
+    if ($significantPrefix.Length -eq 0) { return $true }
+
+    $trailingUpdateRun = [regex]::Match($significantPrefix, '(?<run>\++|-+)$')
+    if ($trailingUpdateRun.Success) {
+      # JavaScript greedily tokenizes runs as ++/-- pairs plus a possible
+      # trailing binary operator. An even run therefore ends in postfix
+      # update; an odd run ends in + or - and permits a regex operand.
+      return ($trailingUpdateRun.Groups['run'].Length % 2) -eq 1
+    }
+    if ($significantPrefix[-1] -in @('=', '(', ':', ',', '!', '[', '{', ';', '?', '&', '|', '*', '%', '^', '~', '<', '>')) {
+      return $true
+    }
+
+    $identifierMatch = [regex]::Match($significantPrefix, '(?<token>[A-Za-z_$][A-Za-z0-9_$]*)$')
+    if (-not $identifierMatch.Success) { return $false }
+    $beforeIdentifier = $significantPrefix.Substring(0, $identifierMatch.Index).TrimEnd()
+    if ($beforeIdentifier.EndsWith('.', [StringComparison]::Ordinal)) { return $false }
+    return @('return', 'case', 'throw', 'yield', 'await', 'typeof', 'instanceof', 'in', 'of', 'delete', 'void', 'new') -ccontains $identifierMatch.Groups['token'].Value
+  }
   for ($lineIndex = 0; $lineIndex -lt $lines.Count; $lineIndex++) {
     $line = $lines[$lineIndex]
     $semanticMarkerText = ''
     if ($blockCommentEnd -ceq '' -and $multilineStringDelimiter -ceq '' -and $javascriptTemplateStack.Count -eq 0) {
       $semanticMarkerMatch = if ($slashLineComment) {
         [regex]::Match($line, '^\s*//\s*arc:(?<payload>(?:@[a-z][a-z-]*|route|scenario)[ \t]+\S(?:.*\S)?)\s*$')
       }
       else { $null }
       if (($null -eq $semanticMarkerMatch -or -not $semanticMarkerMatch.Success) -and ($hashLineComment -or $powerShellBlockComment)) {
         $semanticMarkerMatch = [regex]::Match($line, '^\s*#\s*arc:(?<payload>(?:@[a-z][a-z-]*|route|scenario)[ \t]+\S(?:.*\S)?)\s*$')
@@ -1877,20 +2006,21 @@ function Get-ArcSourceLexicalLines {
         if ($templateCharacter -eq '`') {
           [void]$structural.Append('x')
           $javascriptTemplateStack.RemoveAt($javascriptTemplateStack.Count - 1)
           $index++
           continue
         }
         if ($templateCharacter -eq '$' -and $index + 1 -lt $line.Length -and $line[$index + 1] -eq '{') {
           [void]$structural.Append('${')
           $templateContext.InExpression = $true
           $templateContext.InterpolationDepth = 1
+          $templateContext.RegexCanStart = $true
           $index += 2
           continue
         }
         [void]$structural.Append(' ')
         $index++
         continue
       }
 
       $remaining = $line.Substring($index)
       $multilineOpening = [regex]::Match($remaining, '^(?<delimiter>"{3,}|''{3,})')
@@ -1910,102 +2040,123 @@ function Get-ArcSourceLexicalLines {
       if ($dashLineComment -and $remaining.StartsWith('--', [StringComparison]::Ordinal) -and ($remaining.Length -eq 2 -or [char]::IsWhiteSpace($remaining[2]))) { break }
       if ($semicolonLineComment -and -not $hasCode -and $character -eq ';' -and ($remaining.Length -eq 1 -or [char]::IsWhiteSpace($remaining[1]))) { break }
       if ($character -eq '#') {
         $preprocessor = $cPreprocessor -and [regex]::IsMatch($remaining, '^#\s*(?:define|elif|else|endif|error|if|ifdef|ifndef|include|line|pragma|undef|warning)\b')
         if (-not $preprocessor -and -not $hashDirectiveLanguage) {
           if ($hashLineComment) { break }
         }
       }
       if ($javascriptLanguage -and $character -eq '/') {
         $structuralPrefix = $structural.ToString().TrimEnd()
-        $regexCanStart =
-          $structuralPrefix.Length -eq 0 -or
-          $structuralPrefix[-1] -in @('=', '(', ':', ',', '!', '[', '{', ';', '?', '&', '|', '+', '-', '*', '%', '^', '~', '<', '>') -or
-          $structuralPrefix -cmatch '(?:^|\s)(?:return|case|throw|yield|await|typeof|instanceof|in|of|delete|void|new)\s*$'
+        if (
+          $structuralPrefix.Length -eq 0 -and
+          $javascriptTemplateStack.Count -gt 0 -and
+          $javascriptTemplateStack[$javascriptTemplateStack.Count - 1].InExpression
+        ) {
+          $regexCanStart = [bool]$javascriptTemplateStack[$javascriptTemplateStack.Count - 1].RegexCanStart
+        }
+        else {
+          $regexCanStart = & $javascriptRegexCanStartAfter $structuralPrefix
+        }
         if ($regexCanStart) {
           $regexIndex = $index + 1
           $insideCharacterClass = $false
           $regexClosed = $false
           while ($regexIndex -lt $line.Length) {
             $regexCharacter = $line[$regexIndex]
             if ($regexCharacter -eq '\' -and $regexIndex + 1 -lt $line.Length) { $regexIndex += 2; continue }
             if ($regexCharacter -eq '[') { $insideCharacterClass = $true; $regexIndex++; continue }
             if ($regexCharacter -eq ']' -and $insideCharacterClass) { $insideCharacterClass = $false; $regexIndex++; continue }
             if ($regexCharacter -eq '/' -and -not $insideCharacterClass) { $regexClosed = $true; $regexIndex++; break }
             $regexIndex++
           }
           if ($regexClosed) {
             while ($regexIndex -lt $line.Length -and $line[$regexIndex] -cmatch '[A-Za-z]') { $regexIndex++ }
           }
           else {
             $lineAmbiguous = $true
             $regexIndex = $line.Length
           }
           $hasCode = $true
-          [void]$structural.Append([string]::new([char]' ', $regexIndex - $index))
+          $regexWidth = $regexIndex - $index
+          [void]$structural.Append('x')
+          if ($regexWidth -gt 1) { [void]$structural.Append([string]::new([char]' ', $regexWidth - 1)) }
           $index = $regexIndex
           continue
         }
       }
       if ($javascriptLanguage -and $character -eq '`') {
         $hasCode = $true
         [void]$structural.Append(' ')
         $javascriptTemplateStack.Add([pscustomobject]@{
           StartLine = $lineIndex
           InExpression = $false
           InterpolationDepth = 0
+          RegexCanStart = $true
         })
         $index++
         continue
       }
       if ($character -in @("'", '"', '`')) {
         $hasCode = $true
         $quote = $character
-        [void]$structural.Append(' ')
+        [void]$structural.Append($(if ($javascriptLanguage) { 'x' } else { ' ' }))
+        $quotedStringClosed = $false
         $index++
         while ($index -lt $line.Length) {
           $quotedCharacter = $line[$index]
           [void]$structural.Append(' ')
-          if (($quotedCharacter -eq '\' -or $quotedCharacter -eq '`') -and $index + 1 -lt $line.Length) {
+          $quotedCharacterEscapesNext =
+            $quotedCharacter -eq '\' -or
+            (-not $javascriptLanguage -and $quotedCharacter -eq [char]96)
+          if ($quotedCharacterEscapesNext -and $index + 1 -lt $line.Length) {
             [void]$structural.Append(' ')
             $index += 2
             continue
           }
           if ($quotedCharacter -eq $quote) {
-            if ($index + 1 -lt $line.Length -and $line[$index + 1] -eq $quote) {
+            if (-not $javascriptLanguage -and $index + 1 -lt $line.Length -and $line[$index + 1] -eq $quote) {
               [void]$structural.Append(' ')
               $index += 2
               continue
             }
+            $quotedStringClosed = $true
             $index++
             break
           }
           $index++
         }
+        if ($javascriptLanguage -and -not $quotedStringClosed) { $lineAmbiguous = $true }
         continue
       }
 
       if ($javascriptTemplateStack.Count -gt 0 -and $javascriptTemplateStack[$javascriptTemplateStack.Count - 1].InExpression) {
         $templateContext = $javascriptTemplateStack[$javascriptTemplateStack.Count - 1]
         if ($character -eq '{') {
           $templateContext.InterpolationDepth++
         }
         elseif ($character -eq '}') {
           $templateContext.InterpolationDepth--
           if ($templateContext.InterpolationDepth -eq 0) { $templateContext.InExpression = $false }
         }
       }
 
       [void]$structural.Append($character)
       if (-not [char]::IsWhiteSpace($character)) { $hasCode = $true }
       $index++
     }
+    if ($javascriptTemplateStack.Count -gt 0 -and $javascriptTemplateStack[$javascriptTemplateStack.Count - 1].InExpression) {
+      $lineSignificantPrefix = $structural.ToString().TrimEnd()
+      if ($lineSignificantPrefix.Length -gt 0) {
+        $javascriptTemplateStack[$javascriptTemplateStack.Count - 1].RegexCanStart = & $javascriptRegexCanStartAfter $lineSignificantPrefix
+      }
+    }
     $result.Add([pscustomobject]@{
       Raw = $line
       HasCode = $hasCode
       HasSemanticMetadata = $semanticMarkerText -cne ''
       SemanticText = if ($semanticMarkerText -cne '') { $semanticMarkerText } else { $line }
       StructuralText = $structural.ToString()
       Ambiguous = $lineAmbiguous
     })
   }
   $ambiguousStarts = @($blockCommentStart, $multilineStringStart)

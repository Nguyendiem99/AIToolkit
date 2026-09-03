# Review package: 19e044d5576394ec4b68cb02b099b3ddc3453809..9ba7a1f81b6f029eadc321ac3b601a40ade22a17

## Commits
9ba7a1f test: cover responsibility conformance workflow

## Files changed
 .../tests/scenarios/architecture-review.Tests.ps1  | 126 +++++++++-
 .../responsibility-conformance.validation.ps1      | 269 +++++++++++++++++----
 2 files changed, 342 insertions(+), 53 deletions(-)

## Diff
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/architecture-review.Tests.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/architecture-review.Tests.ps1
index 46b616b..b1ccc3b 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/architecture-review.Tests.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/architecture-review.Tests.ps1
@@ -1434,20 +1434,136 @@ class LexicalOwner {
       : false}`;
     return matches;
   }
 }
 '@
   $unterminatedJavascriptTemplateRegex = Invoke-LexicalSourceInventoryProbe "unterminated-template-regex-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $unterminatedJavascriptTemplateRegexSource 'src/lexical.ts'
   if ($unterminatedJavascriptTemplateRegex.Errors -cnotcontains 'responsibility-evidence-missing') {
     $freshLexerFormatterResidualFailures.Add("C2a an unclosed real regex literal in template interpolation must fail closed ($($lexicalLineEnding.Name))")
   }
 
+  foreach ($javascriptNestedStatementRegexCase in @(
+    [pscustomobject]@{
+      Name = 'if control header'
+      Statement = 'if (value) /}/.test(value);'
+      RegexBrace = '}'
+    },
+    [pscustomobject]@{
+      Name = 'else statement'
+      Statement = "if (!value) value = 'fallback'; else /{/.test(value);"
+      RegexBrace = '{'
+    },
+    [pscustomobject]@{
+      Name = 'do statement'
+      Statement = 'do /}/.test(value); while (false);'
+      RegexBrace = '}'
+    }
+  )) {
+    $javascriptNestedStatementRegexSource = $javascriptOwnerMetadata + "`n" + @'
+class LexicalOwner {
+  run(value) {
+    const nested = `${`${(() => {
+'@ + "`n      $($javascriptNestedStatementRegexCase.Statement)`n" + @'
+      return value;
+    })()}`}`;
+    return nested;
+  }
+}
+'@
+    $javascriptNestedStatementRegex = Invoke-LexicalSourceInventoryProbe "nested-statement-regex-$($javascriptNestedStatementRegexCase.Name.Replace(' ', '-'))-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $javascriptNestedStatementRegexSource 'src/lexical.ts'
+    if ($javascriptNestedStatementRegex.Errors.Count -ne 0 -or $javascriptNestedStatementRegex.OwnerCount -ne 1) {
+      $freshLexerFormatterResidualFailures.Add("C2a a regex literal after $($javascriptNestedStatementRegexCase.Name) must remain inert inside nested template interpolation ($($lexicalLineEnding.Name)): $($javascriptNestedStatementRegex.Errors -join '; ')")
+    }
+    $renderedStatementRegexSource = [regex]::Replace($javascriptNestedStatementRegexSource, '\r\n|\r|\n', $lexicalLineEnding.NewLine)
+    $statementRegexLexicalLines = @(Get-ArcSourceLexicalLines -SourceText $renderedStatementRegexSource -SourcePath 'src/lexical.ts')
+    $statementRegexLexicalLine = @($statementRegexLexicalLines | Where-Object { $_.Raw.IndexOf($javascriptNestedStatementRegexCase.Statement, [StringComparison]::Ordinal) -ge 0 })
+    if (
+      $statementRegexLexicalLine.Count -ne 1 -or
+      $statementRegexLexicalLine[0].StructuralText.IndexOf($javascriptNestedStatementRegexCase.RegexBrace, [StringComparison]::Ordinal) -ge 0
+    ) {
+      $freshLexerFormatterResidualFailures.Add("C2a $($javascriptNestedStatementRegexCase.Name) regex braces must be absent from structural token output ($($lexicalLineEnding.Name))")
+    }
+  }
+
+  $javascriptNestedSpreadRegexSource = $javascriptOwnerMetadata + "`n" + @'
+class LexicalOwner {
+  run() {
+    const nested = `${`${(() => {
+      const spread = [... /}/g];
+      return spread.length;
+    })()}`}`;
+    return nested;
+  }
+}
+'@
+  $javascriptNestedSpreadRegex = Invoke-LexicalSourceInventoryProbe "nested-spread-regex-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $javascriptNestedSpreadRegexSource 'src/lexical.ts'
+  if ($javascriptNestedSpreadRegex.Errors.Count -ne 0 -or $javascriptNestedSpreadRegex.OwnerCount -ne 1) {
+    $freshLexerFormatterResidualFailures.Add("C2a a regex literal after spread must remain inert inside nested template interpolation ($($lexicalLineEnding.Name)): $($javascriptNestedSpreadRegex.Errors -join '; ')")
+  }
+  $renderedSpreadRegexSource = [regex]::Replace($javascriptNestedSpreadRegexSource, '\r\n|\r|\n', $lexicalLineEnding.NewLine)
+  $spreadRegexLexicalLines = @(Get-ArcSourceLexicalLines -SourceText $renderedSpreadRegexSource -SourcePath 'src/lexical.ts')
+  $spreadRegexLexicalLine = @($spreadRegexLexicalLines | Where-Object { $_.Raw.IndexOf('[... /}/g]', [StringComparison]::Ordinal) -ge 0 })
+  if (
+    $spreadRegexLexicalLine.Count -ne 1 -or
+    $spreadRegexLexicalLine[0].StructuralText.IndexOf('}', [StringComparison]::Ordinal) -ge 0
+  ) {
+    $freshLexerFormatterResidualFailures.Add("C2a a spread-context regex brace must be absent from structural token output ($($lexicalLineEnding.Name))")
+  }
+
+  $javascriptNestedStatementDivisionSource = $javascriptOwnerMetadata + "`n" + @'
+class LexicalOwner {
+  run(ready, value, object, member, values) {
+    const nested = `${`${(() => {
+      if (ready) (value) / 2;
+      else object.value / 2;
+      do value++ / 2; while (false);
+      return [...values, member.value / 2, (value) / 2].length;
+    })()}`}`;
+    return nested;
+  }
+}
+'@
+  $javascriptNestedStatementDivision = Invoke-LexicalSourceInventoryProbe "nested-statement-division-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $javascriptNestedStatementDivisionSource 'src/lexical.ts'
+  if ($javascriptNestedStatementDivision.Errors.Count -ne 0 -or $javascriptNestedStatementDivision.OwnerCount -ne 1) {
+    $freshLexerFormatterResidualFailures.Add("C2a value-ending parens, member access, and postfix updates must keep slash as division in nested statement contexts ($($lexicalLineEnding.Name)): $($javascriptNestedStatementDivision.Errors -join '; ')")
+  }
+
+  $javascriptNestedStatementRegexRogueSource = $javascriptOwnerMetadata + "`n" + @'
+class LexicalOwner {
+  run(value) {
+    const nested = `${`${(() => {
+      if (value) /{/.test(value);
+      return value;
+    })()}`}`;
+    return nested;
+  }
+}
+danger()
+'@
+  $javascriptNestedStatementRegexRogue = Invoke-LexicalSourceInventoryProbe "nested-statement-regex-rogue-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $javascriptNestedStatementRegexRogueSource 'src/lexical.ts'
+  if ($javascriptNestedStatementRegexRogue.Errors -cnotcontains 'responsibility-evidence-missing') {
+    $freshLexerFormatterResidualFailures.Add("C2a an opening brace in a statement-position regex must not swallow later rogue code ($($lexicalLineEnding.Name))")
+  }
+
+  $unterminatedJavascriptStatementRegexSource = $javascriptOwnerMetadata + "`n" + @'
+class LexicalOwner {
+  run(value) {
+    if (value) /unterminated
+    return value;
+  }
+}
+'@
+  $unterminatedJavascriptStatementRegex = Invoke-LexicalSourceInventoryProbe "unterminated-statement-regex-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $unterminatedJavascriptStatementRegexSource 'src/lexical.ts'
+  if ($unterminatedJavascriptStatementRegex.Errors -cnotcontains 'responsibility-evidence-missing') {
+    $freshLexerFormatterResidualFailures.Add("C2a an unclosed statement-position regex literal must fail closed ($($lexicalLineEnding.Name))")
+  }
+
   $javascriptOrdinaryBacktickStringSource = $javascriptOwnerMetadata + "`n" + @'
 class LexicalOwner {
   run(value) {
     const doubleQuoted = `${value ? "a`" : "b"}`;
     const singleQuoted = `${value ? 'a`' : 'b'}`;
     const escapedQuotes = `${value ? "a\"b" : 'a\'b'}`;
     return [doubleQuoted, singleQuoted, escapedQuotes];
   }
 }
 '@
@@ -1600,21 +1716,29 @@ $formatterGrammarCases = @(
   [pscustomobject]@{ Expected = $false; Name = 'unknown Ruff option'; Command = 'ruff format --write src/admin_route.source' },
   [pscustomobject]@{ Expected = $false; Name = 'unknown option after the target'; Command = 'prettier --write src/admin_route.source --mystery' },
   [pscustomobject]@{ Expected = $false; Name = 'inline value attached to a switch'; Command = 'prettier --write=true src/admin_route.source' },
   [pscustomobject]@{ Expected = $false; Name = 'missing Prettier scalar value'; Command = 'prettier src/admin_route.source --print-width' },
   [pscustomobject]@{ Expected = $false; Name = 'missing Dart enum value'; Command = 'dart format src/admin_route.source --output' },
   [pscustomobject]@{ Expected = $false; Name = 'invalid rustfmt scalar value'; Command = 'rustfmt --edition latest src/admin_route.source' },
   [pscustomobject]@{ Expected = $false; Name = 'target consumed as a separated scalar value'; Command = 'prettier --print-width src/admin_route.source' },
   [pscustomobject]@{ Expected = $false; Name = 'target consumed as an inline scalar value'; Command = 'prettier --print-width=src/admin_route.source' },
   [pscustomobject]@{ Expected = $false; Name = 'unsupported Python module wrapper'; Command = 'python -m prettier src/admin_route.source' },
   [pscustomobject]@{ Expected = $false; Name = 'generic package script wrapper'; Command = 'npm run format src/admin_route.source' },
-  [pscustomobject]@{ Expected = $false; Name = 'unknown npx wrapped executable'; Command = 'npx formatter-proxy src/admin_route.source' }
+  [pscustomobject]@{ Expected = $false; Name = 'unknown npx wrapped executable'; Command = 'npx formatter-proxy src/admin_route.source' },
+  [pscustomobject]@{ Expected = $false; Name = 'uppercase direct formatter executable'; Command = 'PRETTIER --write src/admin_route.source' },
+  [pscustomobject]@{ Expected = $false; Name = 'mixed-case direct formatter executable'; Command = 'Prettier --write src/admin_route.source' },
+  [pscustomobject]@{ Expected = $false; Name = 'uppercase npx wrapper'; Command = 'NPX prettier --write src/admin_route.source' },
+  [pscustomobject]@{ Expected = $false; Name = 'uppercase format subcommand'; Command = 'ruff FORMAT --check src/admin_route.source' },
+  [pscustomobject]@{ Expected = $false; Name = 'uppercase Python module switch'; Command = 'python -M black --check src/admin_route.source' },
+  [pscustomobject]@{ Expected = $false; Name = 'uppercase package exec subcommand'; Command = 'npm EXEC prettier --write src/admin_route.source' },
+  [pscustomobject]@{ Expected = $false; Name = 'uppercase CSharpier wrapper target'; Command = 'dotnet CSHARPIER --check src/admin_route.source' },
+  [pscustomobject]@{ Expected = $false; Name = 'uppercase Go executable and fmt subcommand'; Command = 'GO FMT -n src/admin_route.source' }
 )
 foreach ($formatterGrammarCase in $formatterGrammarCases) {
   $actual = Test-ArcPathScopedFormatterCommand -Command $formatterGrammarCase.Command -CanonicalPath 'src/admin_route.source'
   if ($actual -ne $formatterGrammarCase.Expected) {
     $freshLexerFormatterResidualFailures.Add("I10 $($formatterGrammarCase.Name) expected $($formatterGrammarCase.Expected) but got $($actual): $($formatterGrammarCase.Command)")
   }
 }
 if ($freshLexerFormatterResidualFailures.Count -ne 0) {
   throw "Fresh C2a/C2b/I10 regression matrix failed:`n - $($freshLexerFormatterResidualFailures -join "`n - ")"
 }
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1
index fcc59e0..c672300 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1
@@ -1537,95 +1537,94 @@ function Test-ArcPathScopedFormatterCommand {
   $tokenMatches = @([regex]::Matches($Command, $tokenPattern))
   if (-not [string]::IsNullOrWhiteSpace([regex]::Replace($Command, $tokenPattern, ''))) { return $false }
   $tokens = @($tokenMatches | ForEach-Object {
     if ($_.Groups['double'].Success) { $_.Groups['double'].Value }
     elseif ($_.Groups['single'].Success) { $_.Groups['single'].Value }
     else { $_.Groups['bare'].Value }
   })
   if ($tokens.Count -lt 2) { return $false }
 
   $executableLeaf = @($tokens[0].Replace('\', '/') -split '/')[-1]
-  $normalizedExecutableLeaf = $executableLeaf.ToLowerInvariant()
-  $executableSuffix = [IO.Path]::GetExtension($normalizedExecutableLeaf)
+  $executableSuffix = [IO.Path]::GetExtension($executableLeaf)
   if ($executableSuffix -cnotin @('', '.exe', '.cmd', '.bat', '.com', '.ps1')) { return $false }
   $executableName = if ($executableSuffix -ceq '') {
-    $normalizedExecutableLeaf
+    $executableLeaf
   }
   else {
-    [IO.Path]::GetFileNameWithoutExtension($normalizedExecutableLeaf)
+    [IO.Path]::GetFileNameWithoutExtension($executableLeaf)
   }
   if (
     [string]::IsNullOrWhiteSpace($executableName) -or
     $tokens[0].StartsWith('-', [StringComparison]::Ordinal) -or
     $tokens[0] -match '[*?\[\]]' -or
     (ConvertTo-ArcCanonicalRepositoryPath -Path $CanonicalPath) -cne $CanonicalPath
   ) { return $false }
 
   $formatterId = ''
   $argumentIndex = -1
   $word = {
     param([int]$Index)
     if ($Index -ge $tokens.Count) { return '' }
-    return $tokens[$Index].ToLowerInvariant()
+    return $tokens[$Index]
   }
   $firstWord = & $word 1
   $secondWord = & $word 2
   $thirdWord = & $word 3
 
   $directFormatters = @('prettier', 'black', 'gofmt', 'rustfmt', 'clang-format', 'csharpier', 'stylua', 'shfmt')
   if ($directFormatters -ccontains $executableName) {
     $formatterId = $executableName
     $argumentIndex = 1
   }
-  elseif ($executableName -in @('ruff', 'biome', 'dart') -and $firstWord -ceq 'format') {
+  elseif (@('ruff', 'biome', 'dart') -ccontains $executableName -and $firstWord -ceq 'format') {
     $formatterId = $executableName
     $argumentIndex = 2
   }
-  elseif ($executableName -in @('go', 'cargo', 'deno') -and $firstWord -ceq 'fmt') {
+  elseif (@('go', 'cargo', 'deno') -ccontains $executableName -and $firstWord -ceq 'fmt') {
     $formatterId = $executableName
     $argumentIndex = 2
   }
   elseif ($executableName -ceq 'dotnet' -and $firstWord -ceq 'csharpier') {
     $formatterId = 'csharpier'
     $argumentIndex = 2
   }
-  elseif ($executableName -in @('python', 'python3', 'py') -and $firstWord -ceq '-m') {
+  elseif (@('python', 'python3', 'py') -ccontains $executableName -and $firstWord -ceq '-m') {
     if ($secondWord -ceq 'ruff' -and $thirdWord -ceq 'format') {
       $formatterId = 'ruff'
       $argumentIndex = 4
     }
     elseif ($secondWord -ceq 'black') {
       $formatterId = 'black'
       $argumentIndex = 3
     }
   }
-  elseif ($executableName -in @('npx', 'bunx')) {
+  elseif (@('npx', 'bunx') -ccontains $executableName) {
     if ($firstWord -ceq 'biome' -and $secondWord -ceq 'format') {
       $formatterId = 'biome'
       $argumentIndex = 3
     }
     elseif ($firstWord -ceq 'prettier') {
       $formatterId = 'prettier'
       $argumentIndex = 2
     }
   }
-  elseif ($executableName -in @('npm', 'pnpm', 'yarn', 'bun') -and $firstWord -ceq 'exec') {
+  elseif (@('npm', 'pnpm', 'yarn', 'bun') -ccontains $executableName -and $firstWord -ceq 'exec') {
     if ($secondWord -ceq 'biome' -and $thirdWord -ceq 'format') {
       $formatterId = 'biome'
       $argumentIndex = 4
     }
     elseif ($secondWord -ceq 'prettier') {
       $formatterId = 'prettier'
       $argumentIndex = 3
     }
   }
-  elseif ($executableName -in @('uv', 'pipx') -and $firstWord -ceq 'run') {
+  elseif (@('uv', 'pipx') -ccontains $executableName -and $firstWord -ceq 'run') {
     if ($secondWord -ceq 'ruff' -and $thirdWord -ceq 'format') {
       $formatterId = 'ruff'
       $argumentIndex = 4
     }
     elseif ($secondWord -ceq 'black') {
       $formatterId = 'black'
       $argumentIndex = 3
     }
   }
   if ($formatterId -ceq '' -or $argumentIndex -lt 0 -or $argumentIndex -ge $tokens.Count) { return $false }
@@ -1923,42 +1922,116 @@ function Get-ArcSourceLexicalLines {
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
-  $javascriptRegexCanStartAfter = {
-    param([AllowEmptyString()][string]$Prefix)
-
-    $significantPrefix = $Prefix.TrimEnd()
-    if ($significantPrefix.Length -eq 0) { return $true }
-
-    $trailingUpdateRun = [regex]::Match($significantPrefix, '(?<run>\++|-+)$')
-    if ($trailingUpdateRun.Success) {
-      # JavaScript greedily tokenizes runs as ++/-- pairs plus a possible
-      # trailing binary operator. An even run therefore ends in postfix
-      # update; an odd run ends in + or - and permits a regex operand.
-      return ($trailingUpdateRun.Groups['run'].Length % 2) -eq 1
+  $newJavascriptCodeState = {
+    [pscustomobject]@{
+      RegexCanStart = $true
+      PendingControlHeader = $false
+      LastTokenKind = 'start'
+      ParenthesisContexts = [Collections.Generic.List[string]]::new()
     }
-    if ($significantPrefix[-1] -in @('=', '(', ':', ',', '!', '[', '{', ';', '?', '&', '|', '*', '%', '^', '~', '<', '>')) {
-      return $true
+  }
+  $javascriptRootCodeState = & $newJavascriptCodeState
+  $getJavascriptCodeState = {
+    if (
+      $javascriptTemplateStack.Count -gt 0 -and
+      $javascriptTemplateStack[$javascriptTemplateStack.Count - 1].InExpression
+    ) {
+      return $javascriptTemplateStack[$javascriptTemplateStack.Count - 1].CodeState
     }
+    return $javascriptRootCodeState
+  }
+  $setJavascriptTokenState = {
+    param(
+      [Parameter(Mandatory)][object]$State,
+      [Parameter(Mandatory)][string]$Kind,
+      [AllowEmptyString()][string]$Token = ''
+    )
 
-    $identifierMatch = [regex]::Match($significantPrefix, '(?<token>[A-Za-z_$][A-Za-z0-9_$]*)$')
-    if (-not $identifierMatch.Success) { return $false }
-    $beforeIdentifier = $significantPrefix.Substring(0, $identifierMatch.Index).TrimEnd()
-    if ($beforeIdentifier.EndsWith('.', [StringComparison]::Ordinal)) { return $false }
-    return @('return', 'case', 'throw', 'yield', 'await', 'typeof', 'instanceof', 'in', 'of', 'delete', 'void', 'new') -ccontains $identifierMatch.Groups['token'].Value
+    $pendingControlHeader = [bool]$State.PendingControlHeader
+    $State.PendingControlHeader = $false
+    switch ($Kind) {
+      'identifier' {
+        if ($State.LastTokenKind -ceq 'member-access') {
+          $State.RegexCanStart = $false
+          $State.LastTokenKind = 'operand'
+        }
+        elseif (@('if', 'while', 'for', 'with', 'switch', 'catch') -ccontains $Token) {
+          $State.RegexCanStart = $true
+          $State.PendingControlHeader = $true
+          $State.LastTokenKind = 'control-keyword'
+        }
+        elseif (@('else', 'do') -ccontains $Token) {
+          $State.RegexCanStart = $true
+          $State.LastTokenKind = 'statement-prefix'
+        }
+        elseif (@('return', 'case', 'throw', 'yield', 'await', 'typeof', 'instanceof', 'in', 'of', 'delete', 'void', 'new') -ccontains $Token) {
+          $State.RegexCanStart = $true
+          $State.LastTokenKind = 'operator-keyword'
+        }
+        else {
+          $State.RegexCanStart = $false
+          $State.LastTokenKind = 'operand'
+        }
+      }
+      'open-parenthesis' {
+        [void]$State.ParenthesisContexts.Add($(if ($pendingControlHeader) { 'control-header' } else { 'expression' }))
+        $State.RegexCanStart = $true
+        $State.LastTokenKind = 'open-parenthesis'
+      }
+      'close-parenthesis' {
+        $parenthesisContext = ''
+        if ($State.ParenthesisContexts.Count -gt 0) {
+          $parenthesisContext = $State.ParenthesisContexts[$State.ParenthesisContexts.Count - 1]
+          $State.ParenthesisContexts.RemoveAt($State.ParenthesisContexts.Count - 1)
+        }
+        $State.RegexCanStart = $parenthesisContext -ceq 'control-header'
+        $State.LastTokenKind = $(if ($State.RegexCanStart) { 'statement-prefix' } else { 'operand' })
+      }
+      'spread' {
+        $State.RegexCanStart = $true
+        $State.LastTokenKind = 'spread'
+      }
+      'member-access' {
+        $State.RegexCanStart = $false
+        $State.LastTokenKind = 'member-access'
+      }
+      'update-run' {
+        # JavaScript greedily consumes ++/-- pairs plus a possible trailing
+        # binary operator. Odd runs therefore expect another operand.
+        $State.RegexCanStart = ($Token.Length % 2) -eq 1
+        $State.LastTokenKind = $(if ($State.RegexCanStart) { 'operator' } else { 'operand' })
+      }
+      'operand' {
+        $State.RegexCanStart = $false
+        $State.LastTokenKind = 'operand'
+      }
+      'operator' {
+        $State.RegexCanStart = $true
+        $State.LastTokenKind = 'operator'
+      }
+      'close-delimiter' {
+        $State.RegexCanStart = $false
+        $State.LastTokenKind = 'operand'
+      }
+      default {
+        $State.RegexCanStart = $true
+        $State.LastTokenKind = $Kind
+      }
+    }
   }
   for ($lineIndex = 0; $lineIndex -lt $lines.Count; $lineIndex++) {
     $line = $lines[$lineIndex]
     $semanticMarkerText = ''
     if ($blockCommentEnd -ceq '' -and $multilineStringDelimiter -ceq '' -and $javascriptTemplateStack.Count -eq 0) {
       $semanticMarkerMatch = if ($slashLineComment) {
         [regex]::Match($line, '^\s*//\s*arc:(?<payload>(?:@[a-z][a-z-]*|route|scenario)[ \t]+\S(?:.*\S)?)\s*$')
       }
       else { $null }
       if (($null -eq $semanticMarkerMatch -or -not $semanticMarkerMatch.Success) -and ($hashLineComment -or $powerShellBlockComment)) {
@@ -1999,28 +2072,30 @@ function Get-ArcSourceLexicalLines {
           $index++
           if ($index -lt $line.Length) {
             [void]$structural.Append(' ')
             $index++
           }
           continue
         }
         if ($templateCharacter -eq '`') {
           [void]$structural.Append('x')
           $javascriptTemplateStack.RemoveAt($javascriptTemplateStack.Count - 1)
+          $parentJavascriptCodeState = & $getJavascriptCodeState
+          [void](& $setJavascriptTokenState $parentJavascriptCodeState 'operand')
           $index++
           continue
         }
         if ($templateCharacter -eq '$' -and $index + 1 -lt $line.Length -and $line[$index + 1] -eq '{') {
           [void]$structural.Append('${')
           $templateContext.InExpression = $true
           $templateContext.InterpolationDepth = 1
-          $templateContext.RegexCanStart = $true
+          $templateContext.CodeState = & $newJavascriptCodeState
           $index += 2
           continue
         }
         [void]$structural.Append(' ')
         $index++
         continue
       }
 
       $remaining = $line.Substring($index)
       $multilineOpening = [regex]::Match($remaining, '^(?<delimiter>"{3,}|''{3,})')
@@ -2039,32 +2114,22 @@ function Get-ArcSourceLexicalLines {
       if ($slashLineComment -and $remaining.StartsWith('//', [StringComparison]::Ordinal)) { break }
       if ($dashLineComment -and $remaining.StartsWith('--', [StringComparison]::Ordinal) -and ($remaining.Length -eq 2 -or [char]::IsWhiteSpace($remaining[2]))) { break }
       if ($semicolonLineComment -and -not $hasCode -and $character -eq ';' -and ($remaining.Length -eq 1 -or [char]::IsWhiteSpace($remaining[1]))) { break }
       if ($character -eq '#') {
         $preprocessor = $cPreprocessor -and [regex]::IsMatch($remaining, '^#\s*(?:define|elif|else|endif|error|if|ifdef|ifndef|include|line|pragma|undef|warning)\b')
         if (-not $preprocessor -and -not $hashDirectiveLanguage) {
           if ($hashLineComment) { break }
         }
       }
       if ($javascriptLanguage -and $character -eq '/') {
-        $structuralPrefix = $structural.ToString().TrimEnd()
-        if (
-          $structuralPrefix.Length -eq 0 -and
-          $javascriptTemplateStack.Count -gt 0 -and
-          $javascriptTemplateStack[$javascriptTemplateStack.Count - 1].InExpression
-        ) {
-          $regexCanStart = [bool]$javascriptTemplateStack[$javascriptTemplateStack.Count - 1].RegexCanStart
-        }
-        else {
-          $regexCanStart = & $javascriptRegexCanStartAfter $structuralPrefix
-        }
-        if ($regexCanStart) {
+        $javascriptCodeState = & $getJavascriptCodeState
+        if ($javascriptCodeState.RegexCanStart) {
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
@@ -2073,32 +2138,38 @@ function Get-ArcSourceLexicalLines {
             while ($regexIndex -lt $line.Length -and $line[$regexIndex] -cmatch '[A-Za-z]') { $regexIndex++ }
           }
           else {
             $lineAmbiguous = $true
             $regexIndex = $line.Length
           }
           $hasCode = $true
           $regexWidth = $regexIndex - $index
           [void]$structural.Append('x')
           if ($regexWidth -gt 1) { [void]$structural.Append([string]::new([char]' ', $regexWidth - 1)) }
+          if ($regexClosed) { [void](& $setJavascriptTokenState $javascriptCodeState 'operand') }
           $index = $regexIndex
           continue
         }
+        [void]$structural.Append('/')
+        $hasCode = $true
+        [void](& $setJavascriptTokenState $javascriptCodeState 'operator' '/')
+        $index++
+        continue
       }
       if ($javascriptLanguage -and $character -eq '`') {
         $hasCode = $true
         [void]$structural.Append(' ')
         $javascriptTemplateStack.Add([pscustomobject]@{
           StartLine = $lineIndex
           InExpression = $false
           InterpolationDepth = 0
-          RegexCanStart = $true
+          CodeState = & $newJavascriptCodeState
         })
         $index++
         continue
       }
       if ($character -in @("'", '"', '`')) {
         $hasCode = $true
         $quote = $character
         [void]$structural.Append($(if ($javascriptLanguage) { 'x' } else { ' ' }))
         $quotedStringClosed = $false
         $index++
@@ -2118,45 +2189,139 @@ function Get-ArcSourceLexicalLines {
               [void]$structural.Append(' ')
               $index += 2
               continue
             }
             $quotedStringClosed = $true
             $index++
             break
           }
           $index++
         }
-        if ($javascriptLanguage -and -not $quotedStringClosed) { $lineAmbiguous = $true }
+        if ($javascriptLanguage) {
+          if ($quotedStringClosed) {
+            $javascriptCodeState = & $getJavascriptCodeState
+            [void](& $setJavascriptTokenState $javascriptCodeState 'operand')
+          }
+          else {
+            $lineAmbiguous = $true
+          }
+        }
         continue
       }
 
       if ($javascriptTemplateStack.Count -gt 0 -and $javascriptTemplateStack[$javascriptTemplateStack.Count - 1].InExpression) {
         $templateContext = $javascriptTemplateStack[$javascriptTemplateStack.Count - 1]
         if ($character -eq '{') {
           $templateContext.InterpolationDepth++
         }
         elseif ($character -eq '}') {
           $templateContext.InterpolationDepth--
-          if ($templateContext.InterpolationDepth -eq 0) { $templateContext.InExpression = $false }
+          if ($templateContext.InterpolationDepth -eq 0) {
+            $templateContext.InExpression = $false
+            [void]$structural.Append('}')
+            $hasCode = $true
+            $index++
+            continue
+          }
+        }
+      }
+
+      if ($javascriptLanguage) {
+        $javascriptCodeState = & $getJavascriptCodeState
+        $identifierToken = [regex]::Match($remaining, '^[A-Za-z_$][A-Za-z0-9_$]*')
+        if ($identifierToken.Success) {
+          $token = $identifierToken.Value
+          [void]$structural.Append($token)
+          $hasCode = $true
+          [void](& $setJavascriptTokenState $javascriptCodeState 'identifier' $token)
+          $index += $token.Length
+          continue
+        }
+
+        $numberToken = [regex]::Match($remaining, '^(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?')
+        if ($numberToken.Success) {
+          $token = $numberToken.Value
+          [void]$structural.Append($token)
+          $hasCode = $true
+          [void](& $setJavascriptTokenState $javascriptCodeState 'operand' $token)
+          $index += $token.Length
+          continue
+        }
+
+        if ($remaining.StartsWith('...', [StringComparison]::Ordinal)) {
+          [void]$structural.Append('...')
+          $hasCode = $true
+          [void](& $setJavascriptTokenState $javascriptCodeState 'spread' '...')
+          $index += 3
+          continue
+        }
+        if ($remaining.StartsWith('?.', [StringComparison]::Ordinal)) {
+          [void]$structural.Append('?.')
+          $hasCode = $true
+          [void](& $setJavascriptTokenState $javascriptCodeState 'member-access' '?.')
+          $index += 2
+          continue
+        }
+        if ($character -eq '.') {
+          [void]$structural.Append('.')
+          $hasCode = $true
+          [void](& $setJavascriptTokenState $javascriptCodeState 'member-access' '.')
+          $index++
+          continue
+        }
+        if ($character -in @('+', '-')) {
+          $operatorIndex = $index + 1
+          while ($operatorIndex -lt $line.Length -and $line[$operatorIndex] -eq $character) { $operatorIndex++ }
+          $operatorRun = $line.Substring($index, $operatorIndex - $index)
+          [void]$structural.Append($operatorRun)
+          $hasCode = $true
+          [void](& $setJavascriptTokenState $javascriptCodeState 'update-run' $operatorRun)
+          $index = $operatorIndex
+          continue
+        }
+
+        $javascriptTokenKind = switch ($character) {
+          '(' { 'open-parenthesis'; break }
+          ')' { 'close-parenthesis'; break }
+          ']' { 'close-delimiter'; break }
+          '}' { 'close-delimiter'; break }
+          '[' { 'operator'; break }
+          '{' { 'operator'; break }
+          ';' { 'operator'; break }
+          ',' { 'operator'; break }
+          ':' { 'operator'; break }
+          '?' { 'operator'; break }
+          '=' { 'operator'; break }
+          '!' { 'operator'; break }
+          '&' { 'operator'; break }
+          '|' { 'operator'; break }
+          '*' { 'operator'; break }
+          '%' { 'operator'; break }
+          '^' { 'operator'; break }
+          '~' { 'operator'; break }
+          '<' { 'operator'; break }
+          '>' { 'operator'; break }
+          default { '' }
+        }
+        if ($javascriptTokenKind -cne '') {
+          [void]$structural.Append($character)
+          $hasCode = $true
+          [void](& $setJavascriptTokenState $javascriptCodeState $javascriptTokenKind ([string]$character))
+          $index++
+          continue
         }
       }
 
       [void]$structural.Append($character)
       if (-not [char]::IsWhiteSpace($character)) { $hasCode = $true }
       $index++
     }
-    if ($javascriptTemplateStack.Count -gt 0 -and $javascriptTemplateStack[$javascriptTemplateStack.Count - 1].InExpression) {
-      $lineSignificantPrefix = $structural.ToString().TrimEnd()
-      if ($lineSignificantPrefix.Length -gt 0) {
-        $javascriptTemplateStack[$javascriptTemplateStack.Count - 1].RegexCanStart = & $javascriptRegexCanStartAfter $lineSignificantPrefix
-      }
-    }
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

# Review package: c0acc0b823acfa7967400a188c4ba7d32cdc31ab..79462ad41c20c7529448be4e836fd95ac2ac49ad

## Commits
79462ad test: cover responsibility conformance workflow

## Files changed
 .../contracts/file-responsibility-conformance.md   |  10 +-
 .../tests/scenarios/architecture-review.Tests.ps1  | 205 +++++++++++++++++++++
 .../scenarios/responsibility-conformance.Tests.ps1 |  95 ++++++++++
 .../scenarios/responsibility-handoff.Tests.ps1     |   5 +
 .../tests/scenarios/scope-engine.Tests.ps1         | 164 ++++++++++++++++-
 .../tests/validate-migration-framework.Tests.ps1   |  27 +++
 .../tests/validate-migration-framework.ps1         |  31 +++-
 .../validation/architecture-review.validation.ps1  |  13 +-
 .../responsibility-conformance.validation.ps1      | 201 ++++++++++++++++++--
 .../tests/validation/scope-engine.validation.ps1   |  65 +++++--
 10 files changed, 773 insertions(+), 43 deletions(-)

## Diff
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/contracts/file-responsibility-conformance.md b/AIToolkit/AIToolkit-main/aitoolkit/contracts/file-responsibility-conformance.md
index 4c79929..7c320d8 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/contracts/file-responsibility-conformance.md
+++ b/AIToolkit/AIToolkit-main/aitoolkit/contracts/file-responsibility-conformance.md
@@ -90,23 +90,27 @@ Independent review derives the changed-path inventory from the immutable pinned
 Repository-relative paths rooted at `src/`, `lib/`, `app/`, `apps/*/src|lib|app`,
 `packages/*/src|lib|app`, `server/`, `client/`, `frontend/`, or `backend/` are
 canonically production-classified; nested test, spec, doc, script, tool,
 generated, build, and distribution roots are excluded unless an approved
 responsibility explicitly selects them. Marker presence never determines
 whether a changed path enters the inventory. Normalize repository-relative
 backslashes to `/` once before comparing design, review, Git, Change Hygiene,
 verification binding, or source evidence; absolute paths, empty segments, and
 `.`/`..` segments are invalid. Parse owner markers only from canonically
 production-classified paths or paths explicitly selected by approved owner
-authority. Executable route/provider content in a production path must be
-covered by a responsibility block; markerless content beside a valid block is
-still unowned and blocks conformance.
+authority. Framework-neutral executable content in a production path must be
+covered by a responsibility block; markerless content before, between, or
+after valid blocks is still unowned and blocks conformance. Blank lines and
+comment-only content outside a block remain valid. Ordinary literal,
+control-flow, and body-only edits inside a bounded responsibility block inherit
+that block's owner and path; an added diff hunk does not repeat metadata merely
+to prove the binding.
 
 Every changed Git path reconciles one-to-one to exactly one implementation `Change Hygiene` row using
 `A/C = new`, `M/R = existing`, and `D = deleted`. Every production-classified
 changed path additionally reconciles to an active responsibility or an
 approved deletion. For `M/R`, compare pinned base and final contents so a
 removed responsibility block enters the deletion flow even when its file
 survives. Every `D` path, whether or not it contains an owner, and every removed
 block uses exact immutable evidence
 `source:<task-base SHA>:<path>; diff:<task-base SHA>..<final-tree SHA>:<path>`;
 the deleted path is not required in final-tree. Omitted paths, markerless
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/architecture-review.Tests.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/architecture-review.Tests.ps1
index 71f7469..bcf366c 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/architecture-review.Tests.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/architecture-review.Tests.ps1
@@ -834,20 +834,146 @@ try {
   [void](Get-ArcPinnedSourceInventory -SourceRoot $mixedOwnershipRoot -TaskBaseSha $taskBaseSha -FinalTreeSha $finalTreeSha -Errors $inventoryErrors)
   if ($inventoryErrors -cnotcontains 'responsibility-evidence-missing') {
     throw 'markerless route/provider before an unchanged responsibility block was not rejected'
   }
   Write-Output 'PASS: mixed owned and unowned production route/provider content is rejected'
 }
 finally {
   if (Test-Path -LiteralPath $mixedOwnershipRoot) { Remove-Item -LiteralPath $mixedOwnershipRoot -Recurse -Force }
 }
 
+foreach ($markerlessPlacement in @('before', 'between', 'after')) {
+  $markerlessBodyRoot = Join-Path ([IO.Path]::GetTempPath()) ('aitoolkit-markerless-body-' + [guid]::NewGuid().ToString('N'))
+  try {
+    [void](New-Item -ItemType Directory -Force -Path (Join-Path $markerlessBodyRoot 'src'))
+    Invoke-PinnedSourceGit $markerlessBodyRoot @('init') | Out-Null
+    Invoke-PinnedSourceGit $markerlessBodyRoot @('config', 'core.autocrlf', 'false') | Out-Null
+    Invoke-PinnedSourceGit $markerlessBodyRoot @('config', 'user.email', 'fixtures@example.test') | Out-Null
+    Invoke-PinnedSourceGit $markerlessBodyRoot @('config', 'user.name', 'AIToolkit fixture') | Out-Null
+    Set-Content -Encoding utf8 -LiteralPath (Join-Path $markerlessBodyRoot 'README') -Value 'markerless body base'
+    Invoke-PinnedSourceGit $markerlessBodyRoot @('add', '--all') | Out-Null
+    Invoke-PinnedSourceGit $markerlessBodyRoot @('commit', '-m', 'markerless body base') | Out-Null
+    $taskBaseSha = Invoke-PinnedSourceGit $markerlessBodyRoot @('rev-parse', 'HEAD')
+    $firstOwner = "@responsibility RESP-FIRST`n@owner-symbol FirstRoute`n@public-symbol FirstRoute`n@owned-capability CAP-FIRST`n@effect route registration`n@architecture-authority target-exemplar`n@co-location-policy feature-local`n@verification-owner VERIFY-OWNER-FIRST`nroute FirstRoute -> FirstProvider"
+    $secondOwner = "@responsibility RESP-SECOND`n@owner-symbol SecondRoute`n@public-symbol SecondRoute`n@owned-capability CAP-SECOND`n@effect route registration`n@architecture-authority target-exemplar`n@co-location-policy feature-local`n@verification-owner VERIFY-OWNER-SECOND`nroute SecondRoute -> SecondProvider"
+    $rogueExecutable = 'if (featureEnabled) { invokeRogue(); }'
+    $sourceText = switch ($markerlessPlacement) {
+      'before' { "$rogueExecutable`n$firstOwner" }
+      'between' { "$firstOwner`n$rogueExecutable`n$secondOwner" }
+      'after' { "$firstOwner`n$rogueExecutable" }
+    }
+    Set-Content -Encoding utf8 -LiteralPath (Join-Path $markerlessBodyRoot 'src/routes.source') -Value $sourceText
+    Invoke-PinnedSourceGit $markerlessBodyRoot @('add', '--all') | Out-Null
+    Invoke-PinnedSourceGit $markerlessBodyRoot @('commit', '-m', "markerless executable $markerlessPlacement owners") | Out-Null
+    $finalTreeSha = Invoke-PinnedSourceGit $markerlessBodyRoot @('rev-parse', 'HEAD')
+    $inventoryErrors = [Collections.Generic.List[string]]::new()
+    [void](Get-ArcPinnedSourceInventory -SourceRoot $markerlessBodyRoot -TaskBaseSha $taskBaseSha -FinalTreeSha $finalTreeSha -Errors $inventoryErrors)
+    if ($inventoryErrors -cnotcontains 'responsibility-evidence-missing') {
+      throw "framework-neutral markerless executable $markerlessPlacement responsibility blocks was not rejected"
+    }
+    Write-Output "PASS: framework-neutral markerless executable $markerlessPlacement responsibility blocks is rejected"
+  }
+  finally {
+    if (Test-Path -LiteralPath $markerlessBodyRoot) { Remove-Item -LiteralPath $markerlessBodyRoot -Recurse -Force }
+  }
+}
+
+$commentOnlyRoot = Join-Path ([IO.Path]::GetTempPath()) ('aitoolkit-comment-only-boundaries-' + [guid]::NewGuid().ToString('N'))
+try {
+  [void](New-Item -ItemType Directory -Force -Path (Join-Path $commentOnlyRoot 'src'))
+  Invoke-PinnedSourceGit $commentOnlyRoot @('init') | Out-Null
+  Invoke-PinnedSourceGit $commentOnlyRoot @('config', 'core.autocrlf', 'false') | Out-Null
+  Invoke-PinnedSourceGit $commentOnlyRoot @('config', 'user.email', 'fixtures@example.test') | Out-Null
+  Invoke-PinnedSourceGit $commentOnlyRoot @('config', 'user.name', 'AIToolkit fixture') | Out-Null
+  Set-Content -Encoding utf8 -LiteralPath (Join-Path $commentOnlyRoot 'README') -Value 'comment boundary base'
+  Invoke-PinnedSourceGit $commentOnlyRoot @('add', '--all') | Out-Null
+  Invoke-PinnedSourceGit $commentOnlyRoot @('commit', '-m', 'comment boundary base') | Out-Null
+  $taskBaseSha = Invoke-PinnedSourceGit $commentOnlyRoot @('rev-parse', 'HEAD')
+  $ownedRoute = "@responsibility RESP-COMMENTED`n@owner-symbol CommentedRoute`n@public-symbol CommentedRoute`n@owned-capability CAP-COMMENTED`n@effect route registration`n@architecture-authority target-exemplar`n@co-location-policy feature-local`n@verification-owner VERIFY-OWNER-COMMENTED`nroute CommentedRoute -> CommentedProvider"
+  Set-Content -Encoding utf8 -LiteralPath (Join-Path $commentOnlyRoot 'src/routes.source') -Value "# header comment`n`n$ownedRoute`n`n// trailing comment"
+  Invoke-PinnedSourceGit $commentOnlyRoot @('add', '--all') | Out-Null
+  Invoke-PinnedSourceGit $commentOnlyRoot @('commit', '-m', 'comment-only owner surroundings') | Out-Null
+  $finalTreeSha = Invoke-PinnedSourceGit $commentOnlyRoot @('rev-parse', 'HEAD')
+  $inventoryErrors = [Collections.Generic.List[string]]::new()
+  $sourceInventory = Get-ArcPinnedSourceInventory -SourceRoot $commentOnlyRoot -TaskBaseSha $taskBaseSha -FinalTreeSha $finalTreeSha -Errors $inventoryErrors
+  if ($inventoryErrors.Count -ne 0 -or @($sourceInventory.ActiveOwners | Where-Object { $_.Id -ceq 'RESP-COMMENTED' }).Count -ne 1) {
+    throw "blank/comment-only content beside a responsibility block should pass: $($inventoryErrors -join '; ')"
+  }
+  Write-Output 'PASS: blank/comment-only content beside a responsibility block remains valid'
+}
+finally {
+  if (Test-Path -LiteralPath $commentOnlyRoot) { Remove-Item -LiteralPath $commentOnlyRoot -Recurse -Force }
+}
+
+foreach ($bodyOnlyEdit in @(
+  [pscustomobject]@{ Name = 'literal'; Old = 'return 1;'; New = 'return 2;' },
+  [pscustomobject]@{ Name = 'control-flow'; Old = 'if (enabled) {'; New = 'if (enabled && allowed) {' },
+  [pscustomobject]@{ Name = 'ordinary body'; Old = 'return cachedValue;'; New = 'return liveValue;' }
+)) {
+  $bodyEditRoot = Join-Path ([IO.Path]::GetTempPath()) ('aitoolkit-owner-body-edit-' + [guid]::NewGuid().ToString('N'))
+  try {
+    [void](New-Item -ItemType Directory -Force -Path (Join-Path $bodyEditRoot 'src'))
+    Invoke-PinnedSourceGit $bodyEditRoot @('init') | Out-Null
+    Invoke-PinnedSourceGit $bodyEditRoot @('config', 'core.autocrlf', 'false') | Out-Null
+    Invoke-PinnedSourceGit $bodyEditRoot @('config', 'user.email', 'fixtures@example.test') | Out-Null
+    Invoke-PinnedSourceGit $bodyEditRoot @('config', 'user.name', 'AIToolkit fixture') | Out-Null
+    $baseBody = "@responsibility RESP-BODY`n@owner-symbol BodyOwner`n@public-symbol BodyOwner`n@owned-capability CAP-BODY`n@effect none`n@architecture-authority target-exemplar`n@co-location-policy feature-local`n@verification-owner VERIFY-OWNER-BODY`nclass BodyOwner {`n  int resolve(bool enabled, bool allowed) {`n    if (enabled) {`n      return 1;`n    }`n    return cachedValue;`n  }`n}"
+    $sourcePath = Join-Path $bodyEditRoot 'src/body.source'
+    Set-Content -Encoding utf8 -LiteralPath $sourcePath -Value $baseBody
+    Invoke-PinnedSourceGit $bodyEditRoot @('add', '--all') | Out-Null
+    Invoke-PinnedSourceGit $bodyEditRoot @('commit', '-m', 'body owner base') | Out-Null
+    $taskBaseSha = Invoke-PinnedSourceGit $bodyEditRoot @('rev-parse', 'HEAD')
+    $updatedBody = $baseBody.Replace($bodyOnlyEdit.Old, $bodyOnlyEdit.New)
+    if ($updatedBody -ceq $baseBody) { throw "$($bodyOnlyEdit.Name) fixture replacement failed" }
+    Set-Content -Encoding utf8 -LiteralPath $sourcePath -Value $updatedBody
+    Invoke-PinnedSourceGit $bodyEditRoot @('add', '--all') | Out-Null
+    Invoke-PinnedSourceGit $bodyEditRoot @('commit', '-m', "$($bodyOnlyEdit.Name) body-only edit") | Out-Null
+    $finalTreeSha = Invoke-PinnedSourceGit $bodyEditRoot @('rev-parse', 'HEAD')
+    $inventoryErrors = [Collections.Generic.List[string]]::new()
+    $sourceInventory = Get-ArcPinnedSourceInventory -SourceRoot $bodyEditRoot -TaskBaseSha $taskBaseSha -FinalTreeSha $finalTreeSha -Errors $inventoryErrors
+    $bodyOwners = @($sourceInventory.ActiveOwners | Where-Object { $_.Id -ceq 'RESP-BODY' -and $_.Path -ceq 'src/body.source' -and $_.IsChanged })
+    if ($inventoryErrors.Count -ne 0 -or $bodyOwners.Count -ne 1) {
+      throw "$($bodyOnlyEdit.Name) body-only edit did not bind to its responsibility owner/path: $($inventoryErrors -join '; ')"
+    }
+    Write-Output "PASS: $($bodyOnlyEdit.Name) body-only edit binds to its responsibility owner/path"
+  }
+  finally {
+    if (Test-Path -LiteralPath $bodyEditRoot) { Remove-Item -LiteralPath $bodyEditRoot -Recurse -Force }
+  }
+}
+
+$outOfBlockEditRoot = Join-Path ([IO.Path]::GetTempPath()) ('aitoolkit-out-of-block-edit-' + [guid]::NewGuid().ToString('N'))
+try {
+  [void](New-Item -ItemType Directory -Force -Path (Join-Path $outOfBlockEditRoot 'src'))
+  Invoke-PinnedSourceGit $outOfBlockEditRoot @('init') | Out-Null
+  Invoke-PinnedSourceGit $outOfBlockEditRoot @('config', 'core.autocrlf', 'false') | Out-Null
+  Invoke-PinnedSourceGit $outOfBlockEditRoot @('config', 'user.email', 'fixtures@example.test') | Out-Null
+  Invoke-PinnedSourceGit $outOfBlockEditRoot @('config', 'user.name', 'AIToolkit fixture') | Out-Null
+  $baseBody = "@responsibility RESP-BOUNDARY`n@owner-symbol BoundaryOwner`n@public-symbol BoundaryOwner`n@owned-capability CAP-BOUNDARY`n@effect none`n@architecture-authority target-exemplar`n@co-location-policy feature-local`n@verification-owner VERIFY-OWNER-BOUNDARY`nclass BoundaryOwner {`n  int resolve() { return 1; }`n}"
+  $sourcePath = Join-Path $outOfBlockEditRoot 'src/boundary.source'
+  Set-Content -Encoding utf8 -LiteralPath $sourcePath -Value $baseBody
+  Invoke-PinnedSourceGit $outOfBlockEditRoot @('add', '--all') | Out-Null
+  Invoke-PinnedSourceGit $outOfBlockEditRoot @('commit', '-m', 'bounded owner base') | Out-Null
+  $taskBaseSha = Invoke-PinnedSourceGit $outOfBlockEditRoot @('rev-parse', 'HEAD')
+  Set-Content -Encoding utf8 -LiteralPath $sourcePath -Value "$baseBody`ninvokeRogue();"
+  Invoke-PinnedSourceGit $outOfBlockEditRoot @('add', '--all') | Out-Null
+  Invoke-PinnedSourceGit $outOfBlockEditRoot @('commit', '-m', 'out-of-block body edit') | Out-Null
+  $finalTreeSha = Invoke-PinnedSourceGit $outOfBlockEditRoot @('rev-parse', 'HEAD')
+  $inventoryErrors = [Collections.Generic.List[string]]::new()
+  [void](Get-ArcPinnedSourceInventory -SourceRoot $outOfBlockEditRoot -TaskBaseSha $taskBaseSha -FinalTreeSha $finalTreeSha -Errors $inventoryErrors)
+  if ($inventoryErrors -cnotcontains 'responsibility-evidence-missing') { throw 'true out-of-block executable edit was incorrectly bound to the preceding owner' }
+  Write-Output 'PASS: true out-of-block executable edit remains unowned and rejected'
+}
+finally {
+  if (Test-Path -LiteralPath $outOfBlockEditRoot) { Remove-Item -LiteralPath $outOfBlockEditRoot -Recurse -Force }
+}
+
 $incidentalMarkerRoot = Join-Path ([IO.Path]::GetTempPath()) ('aitoolkit-incidental-marker-' + [guid]::NewGuid().ToString('N'))
 try {
   [void](New-Item -ItemType Directory -Force -Path (Join-Path $incidentalMarkerRoot 'docs'))
   Invoke-PinnedSourceGit $incidentalMarkerRoot @('init') | Out-Null
   Invoke-PinnedSourceGit $incidentalMarkerRoot @('config', 'core.autocrlf', 'false') | Out-Null
   Invoke-PinnedSourceGit $incidentalMarkerRoot @('config', 'user.email', 'fixtures@example.test') | Out-Null
   Invoke-PinnedSourceGit $incidentalMarkerRoot @('config', 'user.name', 'AIToolkit fixture') | Out-Null
   Set-Content -Encoding utf8 -LiteralPath (Join-Path $incidentalMarkerRoot 'README') -Value 'incidental marker base'
   Invoke-PinnedSourceGit $incidentalMarkerRoot @('add', '--all') | Out-Null
   Invoke-PinnedSourceGit $incidentalMarkerRoot @('commit', '-m', 'incidental marker base') | Out-Null
@@ -1031,20 +1157,51 @@ Assert-FailsLike 'canonical normalization rejects slash-backslash alias duplicat
 
 Assert-FailsLike 'canonical normalization rejects parent-segment path ambiguity' {
   param($root)
   foreach ($relativePath in @('artifacts/design-report.md', 'artifacts/implementation-report.md', 'artifacts/review-report.md')) {
     $path = Join-Path $root $relativePath
     $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
     Set-Content -Encoding utf8 -LiteralPath $path -Value $text.Replace('src/admin_route.source', 'src\..\src\admin_route.source')
   }
 } 'responsibility-evidence-missing' $true
 
+Assert-FailsLike 'review rejects a stale existing final-tree SHA after the authorized checkout advances' {
+  param($root)
+  $provenancePath = Join-Path $root 'artifacts/review-provenance.md'
+  $provenance = Get-Content -Raw -Encoding utf8 -LiteralPath $provenancePath
+  $sourceRoot = [regex]::Match($provenance, '(?m)^Source Root:\s*(?<value>.+)$').Groups['value'].Value.Trim()
+  Set-Content -Encoding utf8 -LiteralPath (Join-Path $sourceRoot 'checkout-advance') -Value 'later authorized checkout'
+  Invoke-PinnedSourceGit $sourceRoot @('add', '--', 'checkout-advance') | Out-Null
+  Invoke-PinnedSourceGit $sourceRoot @('commit', '-m', 'advance authorized checkout') | Out-Null
+  Set-Content -Encoding utf8 -LiteralPath $provenancePath -Value ($provenance.TrimEnd() + "`nCheckout state: advanced`n")
+} 'responsibility-evidence-missing' $true
+
+Assert-FailsLike 'review rejects a dirty authorized checkout even when pinned commits remain valid' {
+  param($root)
+  $provenancePath = Join-Path $root 'artifacts/review-provenance.md'
+  $provenance = Get-Content -Raw -Encoding utf8 -LiteralPath $provenancePath
+  $sourceRoot = [regex]::Match($provenance, '(?m)^Source Root:\s*(?<value>.+)$').Groups['value'].Value.Trim()
+  Set-Content -Encoding utf8 -LiteralPath (Join-Path $sourceRoot 'uncommitted-review-input') -Value 'dirty checkout'
+  Set-Content -Encoding utf8 -LiteralPath $provenancePath -Value ($provenance.TrimEnd() + "`nCheckout state: dirty`n")
+} 'responsibility-evidence-missing' $true
+
+Assert-FailsLike 'review provenance source root must be the actual authorized Git checkout root' {
+  param($root)
+  $provenancePath = Join-Path $root 'artifacts/review-provenance.md'
+  $provenance = Get-Content -Raw -Encoding utf8 -LiteralPath $provenancePath
+  $sourceRoot = [regex]::Match($provenance, '(?m)^Source Root:\s*(?<value>.+)$').Groups['value'].Value.Trim()
+  $nestedRoot = Join-Path $sourceRoot 'src'
+  $updated = $provenance.Replace("Source Root: $sourceRoot", "Source Root: $nestedRoot")
+  if ($updated -ceq $provenance) { throw 'Nested checkout-root provenance mutation was a silent no-op' }
+  Set-Content -Encoding utf8 -LiteralPath $provenancePath -Value $updated
+} 'responsibility-evidence-missing' $true
+
 foreach ($lineEndingCase in @(
   [pscustomobject]@{ Name = 'LF'; NewLine = "`n" }
   [pscustomobject]@{ Name = 'CRLF'; NewLine = "`r`n" }
 )) {
   Assert-FailsLike "review independently rejects omitted actual owner ($($lineEndingCase.Name))" {
     param($root)
     $path = Join-Path $root 'artifacts/review-report.md'
     $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
     [IO.File]::WriteAllText($path, [regex]::Replace($text, '\r?\n', $lineEndingCase.NewLine), [Text.UTF8Encoding]::new($false))
     Add-SourceSymbolEvidence $root 'AdminRoute.factoryReset' 'RESP-UNPLANNED'
@@ -1175,20 +1332,68 @@ Assert-FailsLike 'all required architecture and responsibility verdict fields oc
 } 'exactly once|Verification Ownership Verdict'
 
 Assert-FailsLike 'a missing mandatory verdict is rejected' {
   param($root)
   $path = Join-Path $root 'templates/migration/review-report.md'
   $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
   $text = $text.Replace('- Architecture Conformance Verdict: <PASS | BLOCKED>', '- Architecture verdict omitted: <PASS | BLOCKED>')
   Set-Content -Encoding utf8 -LiteralPath $path -Value $text
 } 'exactly once|Architecture Conformance Verdict'
 
+Assert-FailsLike 'a fenced verdict example cannot replace the visible template verdict' {
+  param($root)
+  $path = Join-Path $root 'templates/migration/review-report.md'
+  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
+  $hiddenVerdict = @'
+```text
+- Architecture Conformance Verdict: <PASS | BLOCKED>
+```
+'@
+  Set-Content -Encoding utf8 -LiteralPath $path -Value $text.Replace('- Architecture Conformance Verdict: <PASS | BLOCKED>', $hiddenVerdict)
+} 'exactly once|Architecture Conformance Verdict'
+
+Assert-FailsLike 'a commented overall verdict cannot replace the visible template control' {
+  param($root)
+  $path = Join-Path $root 'templates/migration/review-report.md'
+  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
+  $hiddenVerdict = "<!--`n- Verdict: <Approve | Approve-with-fixes | Reject>`n-->"
+  Set-Content -Encoding utf8 -LiteralPath $path -Value $text.Replace('- Verdict: <Approve | Approve-with-fixes | Reject>', $hiddenVerdict)
+} 'overall Verdict|exactly once'
+
+Assert-FailsLike 'a fenced behavior-state example cannot replace the visible template control' {
+  param($root)
+  $path = Join-Path $root 'templates/migration/review-report.md'
+  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
+  $hiddenState = @'
+~~~text
+- Behavior Analysis State: <NOT_RUN | COMPLETE>
+~~~
+'@
+  Set-Content -Encoding utf8 -LiteralPath $path -Value $text.Replace('- Behavior Analysis State: <NOT_RUN | COMPLETE>', $hiddenState)
+} 'Behavior Analysis State|exactly once'
+
+Assert-FailsLike 'a commented delivery-adapter example cannot replace the visible template control' {
+  param($root)
+  $path = Join-Path $root 'templates/migration/review-report.md'
+  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
+  $hiddenAdapter = "<!--`n- Delivery Adapter Kind: <migration-unit | task | story | package | phase | milestone | none>`n-->"
+  Set-Content -Encoding utf8 -LiteralPath $path -Value $text.Replace('- Delivery Adapter Kind: <migration-unit | task | story | package | phase | milestone | none>', $hiddenAdapter)
+} 'Delivery Adapter Kind|exactly once'
+
+Assert-FailsLike 'a commented selected-unit policy cannot replace the visible template control' {
+  param($root)
+  $path = Join-Path $root 'templates/migration/review-report.md'
+  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
+  $policy = 'Keep `Selected Migration Unit` only when `Delivery Adapter Kind` is `migration-unit`; otherwise omit it.'
+  Set-Content -Encoding utf8 -LiteralPath $path -Value $text.Replace($policy, "<!-- $policy -->")
+} 'Selected Migration Unit|migration-unit'
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
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1
index c9e0387..38fad3a 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1
@@ -414,35 +414,71 @@ Assert-Rejected 'preferred rejects immutable conflict decision references' {
 Assert-Rejected 'preferred rejects immutable debt decision references' {
   param($root)
   Set-DiscoveryClassification $root 'preferred' 'factual-discovery-evidence' 'inspection:lib/target_shell.dart:10-80; inspection:debt-register.md#DEBT-007'
 } 'exemplar-classification-authority-missing'
 
 Assert-Accepted 'preferred permits ordinary conflict-named source references' {
   param($root)
   Set-DiscoveryClassification $root 'preferred' 'factual-discovery-evidence' 'inspection:lib/conflict_resolver.dart:10-80; inspection:test/conflict_resolver_test.dart:10-60'
 }
 
+Assert-Accepted 'preferred discovery evidence is language-agnostic for Java and Python sources' {
+  param($root)
+  Set-DiscoveryClassification $root 'preferred' 'factual-discovery-evidence' 'inspection:backend/AdminCommandService.java#AdminCommandService; working-evidence:adapter/admin_pipeline.py:12-48'
+}
+
+Assert-Accepted 'preferred discovery evidence accepts another canonical source kind without an extension allowlist' {
+  param($root)
+  Set-DiscoveryClassification $root 'preferred' 'factual-discovery-evidence' 'inspection:core/admin_lock.rs#AdminLock; working-evidence:core/admin_lock_spec.kt:9-31'
+}
+
+foreach ($unsafePreferredEvidence in @(
+  'inspection:../backend/AdminCommandService.java#AdminCommandService; working-evidence:adapter/admin_pipeline.py:12-48',
+  'inspection:backend//AdminCommandService.java#AdminCommandService; working-evidence:adapter/admin_pipeline.py:12-48',
+  'inspection:backend/AdminCommandService.java:10-20#AdminCommandService; working-evidence:adapter/admin_pipeline.py:12-48'
+)) {
+  Assert-Rejected "preferred rejects unsafe or ambiguous language-agnostic evidence: $unsafePreferredEvidence" {
+    param($root)
+    Set-DiscoveryClassification $root 'preferred' 'factual-discovery-evidence' $unsafePreferredEvidence
+  } 'exemplar-classification-authority-missing'
+}
+
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
 
+Assert-Accepted 'no-equivalent accepts canonical Java inspection evidence' {
+  param($root)
+  Set-DiscoveryNoEquivalent $root 'factual-discovery-evidence' 'inspection:backend/MissingTarget.java#MissingTarget'
+}
+
+Assert-Accepted 'no-equivalent search evidence is not restricted to Markdown files' {
+  param($root)
+  Set-DiscoveryNoEquivalent $root 'factual-discovery-evidence' 'search:evidence/target-search.json#query=target-shell,result=0'
+}
+
+Assert-Rejected 'no-equivalent rejects traversing language-agnostic evidence paths' {
+  param($root)
+  Set-DiscoveryNoEquivalent $root 'factual-discovery-evidence' 'inspection:../backend/MissingTarget.java#MissingTarget'
+} 'exemplar-classification-authority-missing'
+
 Assert-Rejected 'duplicate classification row is rejected' {
   param($root)
   $path = Join-Path $root '02-discovery.md'
   Add-Content -Encoding utf8 -LiteralPath $path -Value '| module/container composition | lib/duplicate.dart | DuplicateShell | duplicate target pattern | duplicate responsibility | CAP-002 | VERIFY-OWNER-002 | duplicate | lib/duplicate.dart:1-2 | verified | preferred | factual-discovery-evidence | inspection:lib/duplicate.dart:1; inspection:test/duplicate_test.dart:1 |'
 } 'exemplar-classification-row-duplicate'
 
 Assert-Rejected 'discovery requires responsibility contract version' {
   param($root)
   $path = Join-Path $root '02-discovery.md'
   $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
@@ -1492,35 +1528,94 @@ $notApplicableImplementation = (New-ResponsibilityImplementationFixture).Replace
   '| VERIFY-OWNER-WIFI | RESP-WIFI | CAP-ADMIN-WIFI | test/admin_lock_test.ps1 | AdminWifiContract | static-structure | not-applicable-approved | invokes config/admin_wifi.yaml#AdminWifi | approval:OWNER-WIFI | PASS | not-applicable |'
 )
 $notApplicableImplementationDiagnostics = @(Test-ResponsibilityImplementation -DesignText $notApplicablePlanDesign -ImplementationText $notApplicableImplementation -ContractText $contract)
 if ($notApplicableImplementationDiagnostics.Count -ne 0) { throw "implementation must reuse canonical structured not-applicable eligibility but got: $($notApplicableImplementationDiagnostics -join '; ')" }
 Write-Output 'PASS: design and implementation reuse canonical structured not-applicable eligibility'
 $foreignNotApplicableImplementationDiagnostics = @(Test-ResponsibilityImplementation -DesignText ($notApplicablePlanDesign.Replace('approval:OWNER-WIFI', 'approval:OWNER-FOREIGN')) -ImplementationText ($notApplicableImplementation.Replace('approval:OWNER-WIFI', 'approval:OWNER-FOREIGN')) -ContractText $contract)
 if ($foreignNotApplicableImplementationDiagnostics -notcontains 'verification-disposition-invalid') { throw "implementation must reject foreign not-applicable approval but got: $($foreignNotApplicableImplementationDiagnostics -join '; ')" }
 Write-Output 'PASS: implementation rejects foreign not-applicable approval with the shared predicate'
 Assert-ImplementationRejected 'caller cannot claim aggregate PASS when a sub-verdict blocks' (New-ResponsibilityImplementationFixture -ArchitectureState 'BLOCKED').Replace('| 1 | PASS | PASS | PASS | BLOCKED |', '| 1 | PASS | PASS | BLOCKED | PASS |') 'responsibility-waiver-forbidden'
 
+$blockedVerificationDesign = (New-ResponsibilityPlanDesignFixture).Replace(
+  '| VERIFY-OWNER-WIFI | RESP-WIFI | CAP-ADMIN-WIFI | test/admin_lock_test.ps1 | AdminWifiContract | contract | required | invokes ui/admin_wifi.dart#AdminWifi | not-applicable | PASS | not-applicable |',
+  '| VERIFY-OWNER-WIFI | RESP-WIFI | CAP-ADMIN-WIFI | test/admin_lock_test.ps1 | AdminWifiContract | contract | required | invokes ui/admin_wifi.dart#AdminWifi | not-applicable | BLOCKED | not-applicable |'
+)
+$blockedVerificationImplementation = (New-ResponsibilityImplementationFixture).Replace(
+  '| VERIFY-OWNER-WIFI | RESP-WIFI | CAP-ADMIN-WIFI | test/admin_lock_test.ps1 | AdminWifiContract | contract | required | invokes ui/admin_wifi.dart#AdminWifi | not-applicable | PASS | not-applicable | diff:test/admin_lock_test.ps1#AdminWifiContract |',
+  '| VERIFY-OWNER-WIFI | RESP-WIFI | CAP-ADMIN-WIFI | test/admin_lock_test.ps1 | AdminWifiContract | contract | required | invokes ui/admin_wifi.dart#AdminWifi | not-applicable | BLOCKED | not-applicable | diff:test/admin_lock_test.ps1#AdminWifiContract |'
+)
+$blockedVerificationDiagnostics = @(Test-ResponsibilityImplementation -DesignText $blockedVerificationDesign -ImplementationText $blockedVerificationImplementation -ContractText $contract)
+if ($blockedVerificationDiagnostics -notcontains 'responsibility-waiver-forbidden') {
+  throw "required verification row BLOCKED cannot support aggregate PASS but got: $($blockedVerificationDiagnostics -join '; ')"
+}
+Write-Output 'PASS: required verification row BLOCKED cannot support aggregate PASS'
+
+$descriptiveVerificationDesign = (New-ResponsibilityPlanDesignFixture).Replace(
+  'test/admin_lock_test.ps1 | AdminWifiContract',
+  'test/admin_lock_test.ps1 | admin wifi contract scenario'
+)
+$descriptiveVerificationImplementation = (New-ResponsibilityImplementationFixture).Replace(
+  'test/admin_lock_test.ps1 | AdminWifiContract',
+  'test/admin_lock_test.ps1 | admin wifi contract scenario'
+)
+$descriptiveVerificationDiagnostics = @(Test-ResponsibilityImplementation -DesignText $descriptiveVerificationDesign -ImplementationText $descriptiveVerificationImplementation -ContractText $contract)
+if ($descriptiveVerificationDiagnostics.Count -ne 0) {
+  throw "non-placeholder descriptive verification scenario must remain valid but got: $($descriptiveVerificationDiagnostics -join '; ')"
+}
+Write-Output 'PASS: non-placeholder descriptive verification scenario supports aggregate PASS'
+
+foreach ($invalidEvidence in @(
+  [pscustomobject]@{ Name = 'placeholder evidence path'; Old = 'test/admin_lock_test.ps1 | AdminWifiContract'; New = 'pending | AdminWifiContract' },
+  [pscustomobject]@{ Name = 'placeholder evidence scenario'; Old = 'test/admin_lock_test.ps1 | AdminWifiContract'; New = 'test/admin_lock_test.ps1 | pending' },
+  [pscustomobject]@{ Name = 'traversing evidence path'; Old = 'test/admin_lock_test.ps1 | AdminWifiContract'; New = '../test/admin_lock_test.ps1 | AdminWifiContract' },
+  [pscustomobject]@{ Name = 'noncanonical evidence path'; Old = 'test/admin_lock_test.ps1 | AdminWifiContract'; New = 'test\admin_lock_test.ps1 | AdminWifiContract' }
+)) {
+  $invalidDesign = (New-ResponsibilityPlanDesignFixture).Replace($invalidEvidence.Old, $invalidEvidence.New)
+  $invalidImplementation = (New-ResponsibilityImplementationFixture).Replace($invalidEvidence.Old, $invalidEvidence.New)
+  $invalidDiagnostics = @(Test-ResponsibilityImplementation -DesignText $invalidDesign -ImplementationText $invalidImplementation -ContractText $contract)
+  if ($invalidDiagnostics -notcontains 'verification-production-binding-missing') {
+    throw "$($invalidEvidence.Name) cannot support aggregate verification PASS but got: $($invalidDiagnostics -join '; ')"
+  }
+  Write-Output "PASS: $($invalidEvidence.Name) cannot support aggregate verification PASS"
+}
+
 $validReviewDesign = New-ResponsibilityPlanDesignFixture
 $validReviewSource = New-ResponsibilityReviewSourceFixture
 $script:validReviewPlan = New-ResponsibilityReviewPlanFixture
 $validImplementation = New-ResponsibilityImplementationFixture -TaskBaseSha $validReviewSource.TaskBaseSha -FinalTreeSha $validReviewSource.FinalTreeSha
 $canonicalEnvelopeReview = New-ResponsibilityReviewFixture -PinnedSource $validReviewSource
 Assert-ReviewRejected 'review envelope rejects a substituted run' ($canonicalEnvelopeReview.Replace('RUN-ADMIN-001', 'RUN-FOREIGN-001')) 'responsibility-evidence-missing'
 Assert-ReviewRejected 'review envelope rejects a substituted work item' ($canonicalEnvelopeReview.Replace('WORK-ADMIN-LOCK', 'WORK-FOREIGN')) 'responsibility-evidence-missing'
 Assert-ReviewRejected 'review envelope rejects a substituted delivery adapter' ($canonicalEnvelopeReview.Replace('- Delivery Adapter Kind: none', '- Delivery Adapter Kind: task')) 'responsibility-evidence-missing'
 Assert-ReviewRejected 'review envelope rejects a substituted final-tree SHA' ($canonicalEnvelopeReview.Replace($validReviewSource.FinalTreeSha, '4444444444444444444444444444444444444444')) 'responsibility-evidence-missing'
 Assert-ReviewRejected 'review envelope rejects a substituted source artifact' ($canonicalEnvelopeReview.Replace('implementation-report.md', 'other-implementation.md')) 'responsibility-evidence-missing'
 Assert-ReviewRejected 'review envelope rejects stale source-diff evidence' ($canonicalEnvelopeReview.Replace("source-diff:$($validReviewSource.TaskBaseSha)..$($validReviewSource.FinalTreeSha)#WORK-ADMIN-LOCK", "source-diff:$($validReviewSource.TaskBaseSha)..3333333333333333333333333333333333333333#WORK-ADMIN-LOCK")) 'responsibility-evidence-missing'
 Assert-ReviewRejected 'review envelope rejects a non-v1 responsibility handoff' ($canonicalEnvelopeReview.Replace('| 1 | PASS | PASS | PASS | PASS | source-diff:', '| 2 | PASS | PASS | PASS | PASS | source-diff:')) 'responsibility-contract-version-invalid'
 Assert-ReviewRejected 'review envelope rejects a cross-plan implementation context' $canonicalEnvelopeReview 'responsibility-evidence-missing' -ImplementationText ($validImplementation.Replace('PLAN-ADMIN-001', 'PLAN-FOREIGN-001'))
 Assert-ReviewRejected 'review envelope rejects an unapproved substituted plan authority' $canonicalEnvelopeReview 'responsibility-evidence-missing' -ApprovedPlanText ($script:validReviewPlan.Replace('status: approved', 'status: draft'))
 Assert-ReviewAccepted 'review resolves unchanged verification evidence from the pinned final tree' $canonicalEnvelopeReview
+$fencedArchitectureVerdict = @'
+```text
+- Architecture Conformance Verdict: PASS
+```
+'@
+Assert-ReviewRejected 'fenced review verdict cannot replace the required visible architecture verdict' `
+  ($canonicalEnvelopeReview.Replace('- Architecture Conformance Verdict: PASS', $fencedArchitectureVerdict)) `
+  'responsibility-owner-missing'
+$commentedAdapterControl = @'
+<!--
+- Delivery Adapter Kind: none
+-->
+'@
+Assert-ReviewRejected 'commented delivery-adapter control cannot replace the required visible review control' `
+  ($canonicalEnvelopeReview.Replace('- Delivery Adapter Kind: none', $commentedAdapterControl)) `
+  'responsibility-evidence-missing'
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
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-handoff.Tests.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-handoff.Tests.ps1
index 9d01c84..24c0930 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-handoff.Tests.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-handoff.Tests.ps1
@@ -525,20 +525,25 @@ $genericRegression = New-HandoffArtifact -StepId '14-verify-regression' -SourceA
 $genericKnowledgeBase = New-HandoffArtifact -StepId '15-knowledge-base' -SourceArtifact '14-regression-report.md' -AdapterKind 'task'
 Assert-HandoffAccepted 'generic adapter review reaches verification without a selected migration unit' $genericReview $genericVerification $genericPlan
 Assert-HandoffAccepted 'generic adapter verification reaches parity without a selected migration unit' $genericVerification $genericParity $genericPlan
 Assert-HandoffRejected 'incremental generic adapter cannot skip regression before terminal KB' $genericParity (New-HandoffArtifact -StepId '15-knowledge-base' -SourceArtifact '13-parity-report.md' -AdapterKind 'task') 'responsibility-evidence-missing' $genericPlan
 Assert-HandoffAccepted 'incremental generic adapter parity reaches regression without a selected migration unit' $genericParity $genericRegression $genericPlan
 Assert-HandoffAccepted 'incremental generic adapter regression reaches terminal KB without a selected migration unit' $genericRegression $genericKnowledgeBase $genericPlan
 $genericGreenfieldPlan = New-ApprovedAdapterPlan -AdapterKind task -SelectorApproval 'approval:TASK-ADMIN-LOCK' -SelectorMode 'greenfield/design-new'
 $genericGreenfieldParity = New-HandoffArtifact -StepId '13-verify-parity' -SourceArtifact 'verification-report.md' -AdapterKind 'task'
 $genericGreenfieldKnowledgeBase = New-HandoffArtifact -StepId '15-knowledge-base' -SourceArtifact '13-parity-report.md' -AdapterKind 'task'
 Assert-HandoffAccepted 'greenfield generic adapter may omit regression before terminal KB' $genericGreenfieldParity $genericGreenfieldKnowledgeBase $genericGreenfieldPlan
+Assert-HandoffRejected 'cross-spec plan ID cannot control greenfield regression ordering' $genericGreenfieldParity $genericGreenfieldKnowledgeBase 'responsibility-evidence-missing' ($genericGreenfieldPlan.Replace('master_spec_id: SPEC-HANDOFF-001', 'master_spec_id: SPEC-FOREIGN-001'))
+Assert-HandoffRejected 'cross-spec plan revision cannot control greenfield regression ordering' $genericGreenfieldParity $genericGreenfieldKnowledgeBase 'responsibility-evidence-missing' ($genericGreenfieldPlan.Replace('master_spec_revision: 1', 'master_spec_revision: 2'))
+Assert-HandoffRejected 'foreign master plan ID cannot control greenfield regression ordering' $genericGreenfieldParity $genericGreenfieldKnowledgeBase 'responsibility-evidence-missing' ($genericGreenfieldPlan.Replace('master_plan_id: PLAN-HANDOFF-001', 'master_plan_id: PLAN-FOREIGN-001'))
+Assert-HandoffRejected 'stale master plan revision cannot control greenfield regression ordering' $genericGreenfieldParity $genericGreenfieldKnowledgeBase 'responsibility-evidence-missing' ($genericGreenfieldPlan.Replace('revision: 1', 'revision: 2'))
+Assert-HandoffRejected 'unapproved master plan cannot control greenfield regression ordering' $genericGreenfieldParity $genericGreenfieldKnowledgeBase 'responsibility-evidence-missing' ($genericGreenfieldPlan.Replace('status: approved', 'status: draft'))
 $packagePlan = New-ApprovedAdapterPlan -AdapterKind package -SelectorApproval 'approval:PACKAGE-ADMIN-LOCK'
 $packageReview = New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -AdapterKind package
 $packageVerification = New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md' -AdapterKind package
 Assert-HandoffAccepted 'package selector preserves its concrete external authority and Work Item assurance identity' $packageReview $packageVerification $packagePlan
 $noneSelectorReview = New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -AdapterKind 'none'
 $noneSelectorVerification = New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md' -AdapterKind 'none'
 Assert-HandoffAccepted 'none selector retains approved generic delivery adapter with Work Item assurance identity' $noneSelectorReview $noneSelectorVerification $noneSelectorGenericPlan
 $noneSelectorParity = New-HandoffArtifact -StepId '13-verify-parity' -SourceArtifact 'verification-report.md' -AdapterKind 'none'
 $noneSelectorRegression = New-HandoffArtifact -StepId '14-verify-regression' -SourceArtifact '13-parity-report.md' -AdapterKind 'none'
 $noneSelectorKnowledgeBase = New-HandoffArtifact -StepId '15-knowledge-base' -SourceArtifact '14-regression-report.md' -AdapterKind 'none'
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/scope-engine.Tests.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/scope-engine.Tests.ps1
index 27bb5c2..92cbf5f 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/scope-engine.Tests.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/scope-engine.Tests.ps1
@@ -268,20 +268,27 @@ function New-TerminalResponsibilityArtifact(
     master_spec_revision = 2
     master_plan_ref = 'runs/master-plan@3.md'
     master_plan_id = 'PLAN-ADMIN-001'
     master_plan_revision = 3
     work_item_id = $WorkItemId
     plan_revision = 3
     status = $Status
     result = 'complete'
     mode_constraint = $ModeConstraint
     responsibility_chain_references = @($ChainReferences)
+    task_provenance = @{
+      task_unit = $WorkItemId
+      task_base_sha = '1111111111111111111111111111111111111111'
+      final_tree_sha = '2222222222222222222222222222222222222222'
+      source_artifact_reference = 'implementation-report.md'
+      evidence_reference = "source-diff:1111111111111111111111111111111111111111..2222222222222222222222222222222222222222#$WorkItemId"
+    }
     responsibility_handoff = @{
       responsibility_contract_version = 1
       tree_conformance = 'PASS'
       responsibility_conformance = 'PASS'
       verification_ownership = 'PASS'
       architecture_state = 'PASS'
       evidence_reference = $EvidenceReference
     }
   }
 }
@@ -521,20 +528,38 @@ $canonicalPlanItem = New-WorkItem 'WORK-ADMIN-CANONICAL' 1
 $forgedQueueItem = New-WorkItem 'WORK-ADMIN-FORGED' 1
 $forgedQueueGate = New-ApprovedOrchestrationContext
 $forgedQueueGate.plan_revisions[2].work_items = @($canonicalPlanItem)
 $forgedQueueResult = Invoke-ScopeScenario @{
   scenario_type = 'scope-engine'; operation = 'select'; current_plan_revision = 3
   orchestration_context = $forgedQueueGate; work_items = @($forgedQueueItem)
 }
 Assert-Equal $forgedQueueResult.result 'orchestration-blocked' 'Queue input must be the exact current approved master-plan rows'
 Assert-Equal $forgedQueueResult.reason 'work-items-not-bound-to-master-plan' 'Arbitrary caller queue must be rejected before selection'
 
+foreach ($stringImmutableCase in @('master-spec', 'master-plan', 'queue-responsibility-authority')) {
+  $stringImmutableItem = New-WorkItem "WORK-ADMIN-STRING-IMMUTABLE-$($stringImmutableCase.ToUpperInvariant())" 1
+  $stringImmutableContext = New-ApprovedOrchestrationContext
+  $stringImmutableContext.plan_revisions[2].work_items = @($stringImmutableItem)
+  $stringImmutableAuthority = New-QueueResponsibilityArtifact $stringImmutableItem.responsibility_evidence $stringImmutableItem
+  switch ($stringImmutableCase) {
+    'master-spec' { $stringImmutableContext.spec_revisions[1].immutable = 'false' }
+    'master-plan' { $stringImmutableContext.plan_revisions[2].immutable = 'false' }
+    'queue-responsibility-authority' { $stringImmutableAuthority.immutable = 'false' }
+  }
+  $stringImmutableContext.resolved_artifacts = @($stringImmutableAuthority)
+  $stringImmutableResult = Invoke-ScopeScenario @{
+    scenario_type = 'scope-engine'; operation = 'select'; current_plan_revision = 3
+    orchestration_context = $stringImmutableContext; work_items = @($stringImmutableItem)
+  }
+  Assert-True ($stringImmutableResult.result -cin @('orchestration-blocked', 'scope-blocked')) "String false immutable must reject at $stringImmutableCase authority"
+}
+
 # Generic projects: a valid `none` adapter must remain generic and selectable.
 $genericItem = New-WorkItem 'WORK-GENERIC-SHELL' 1
 $generic = Invoke-ScopeScenario @{
   scenario_type = 'scope-engine'
   operation = 'select'
   current_plan_revision = 3
   work_items = @($genericItem)
 }
 Assert-Equal $generic.result 'selected' 'Generic work item must be selectable without a migration unit'
 Assert-Equal $generic.work_item_id 'WORK-GENERIC-SHELL' 'Generic selector must return the work item ID'
@@ -793,26 +818,48 @@ foreach ($terminalAuthorityCase in @(
   @{ Name = 'TERMINAL-PRE-V1'; Mutate = { param($terminal, $chain) $terminal.responsibility_handoff.responsibility_contract_version = 0 } },
   @{ Name = 'TERMINAL-CROSS-RUN'; Mutate = { param($terminal, $chain) $terminal.run_id = 'RUN-FOREIGN-999' } },
   @{ Name = 'TERMINAL-EVIDENCE-MISMATCH'; Mutate = { param($terminal, $chain) $terminal.responsibility_handoff.evidence_reference = 'runs/foreign-terminal-chain.md' } }
 )) {
   $invalidTerminalAuthority = Invoke-NoDependentReconciliationCase $terminalAuthorityCase.Name $true $terminalAuthorityCase.Mutate
   Assert-Equal $invalidTerminalAuthority.Result.result 'scope-blocked' "No-dependent reconciliation must reject $($terminalAuthorityCase.Name) authority"
   Assert-Equal $invalidTerminalAuthority.Result.reason 'terminal-responsibility-authority-invalid' "No-dependent $($terminalAuthorityCase.Name) must emit the canonical authority reason"
   Assert-Equal $invalidTerminalAuthority.Result.scope_status 'scope-blocked' "No-dependent $($terminalAuthorityCase.Name) must block scope"
   Assert-Equal $invalidTerminalAuthority.Result.work_item_id '' "No-dependent $($terminalAuthorityCase.Name) must not select unrelated work"
 }
+$stringImmutableTerminalReconciliation = Invoke-NoDependentReconciliationCase 'TERMINAL-STRING-IMMUTABLE' $true { param($terminal, $chain) $terminal.immutable = 'false' }
+Assert-Equal $stringImmutableTerminalReconciliation.Result.result 'plan-invalid' 'String false immutable terminal must reject during reconciliation'
+Assert-Equal $stringImmutableTerminalReconciliation.Result.reason 'attempt-artifact-binding-invalid' 'String false immutable terminal must fail the earliest attempt authority gate'
+
+$forgedInitialPredecessor = Invoke-NoDependentReconciliationCase 'FORGED-INITIAL-PREDECESSOR' $true {
+  param($terminal, $chain)
+  $chain.Artifacts[0].source_artifact_reference = 'forged-predecessor.md'
+}
+Assert-Equal $forgedInitialPredecessor.Result.result 'scope-blocked' 'Terminal chain review must bind index 0 to the implementation predecessor'
+Assert-Equal $forgedInitialPredecessor.Result.reason 'terminal-responsibility-authority-invalid' 'Forged index-0 predecessor must fail terminal responsibility authority'
+
+$allNodeForgedProvenance = Invoke-NoDependentReconciliationCase 'ALL-NODE-FORGED-PROVENANCE' $true {
+  param($terminal, $chain)
+  foreach ($artifact in @($chain.Artifacts)) {
+    $artifact.task_base_sha = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
+    $artifact.final_tree_sha = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
+    $artifact.evidence_reference = "source-diff:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa..bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb#$($terminal.work_item_id)"
+  }
+}
+Assert-Equal $allNodeForgedProvenance.Result.result 'scope-blocked' 'All-node forged SHA/evidence pairs must not replace immutable Task Provenance during reconciliation'
+Assert-Equal $allNodeForgedProvenance.Result.reason 'terminal-responsibility-authority-invalid' 'All-node provenance forgery must fail terminal responsibility authority'
 
 foreach ($chainIndex in 0..4) {
   foreach ($lifecycleCase in @(
     @{ Name = 'STATUS'; Mutate = { param($artifact) $artifact.status = 'draft' } },
     @{ Name = 'RESULT'; Mutate = { param($artifact) $artifact.result = 'blocked' } },
-    @{ Name = 'APPROVAL'; Mutate = { param($artifact) $artifact.approval_source = 'automation' } }
+    @{ Name = 'APPROVAL'; Mutate = { param($artifact) $artifact.approval_source = 'automation' } },
+    @{ Name = 'STRING-IMMUTABLE'; Mutate = { param($artifact) $artifact.immutable = 'false' } }
   )) {
     $caseName = "CHAIN-$chainIndex-$($lifecycleCase.Name)"
     $mutation = {
       param($terminal, $chain)
       & $lifecycleCase.Mutate $chain.Artifacts[$chainIndex]
     }.GetNewClosure()
     $invalidChainAuthority = Invoke-NoDependentReconciliationCase $caseName $true $mutation
     Assert-Equal $invalidChainAuthority.Result.result 'scope-blocked' "No-dependent reconciliation must reject $caseName lifecycle/authority"
     Assert-Equal $invalidChainAuthority.Result.reason 'terminal-responsibility-authority-invalid' "No-dependent $caseName must emit the canonical authority reason"
     Assert-Equal $invalidChainAuthority.Result.scope_status 'scope-blocked' "No-dependent $caseName must block scope"
@@ -912,20 +959,37 @@ $artifactMismatchContext.plan_revisions[2].work_items = @($artifactMismatchItem)
 $artifactMismatchContext.resolved_artifacts = @(
   @{ artifact_reference = 'runs/artifact-mismatch-terminal.md'; attempt_id = 'ATTEMPT-WORK-ADMIN-OTHER-01'; work_item_id = 'WORK-ADMIN-ARTIFACT-MISMATCH'; plan_revision = 3; status = 'complete'; immutable = $true }
 )
 $artifactMismatchResume = Invoke-ScopeScenario @{
   scenario_type = 'scope-engine'; operation = 'select'; current_plan_revision = 3
   orchestration_context = $artifactMismatchContext; work_items = @($artifactMismatchItem)
 }
 Assert-Equal $artifactMismatchResume.result 'plan-invalid' 'Resume must resolve and validate the immutable attempt artifact object'
 Assert-Equal $artifactMismatchResume.reason 'attempt-artifact-binding-invalid' 'Attempt artifact identity mismatch must block reconciliation'
 
+$stringImmutableAttemptItem = New-WorkItem 'WORK-ADMIN-STRING-IMMUTABLE-ATTEMPT' 1 @() 'in-progress'
+$stringImmutableAttemptItem.latest_attempt = 'ATTEMPT-WORK-ADMIN-STRING-IMMUTABLE-ATTEMPT-01'
+$stringImmutableAttemptItem.attempt_history = @(
+  @{ attempt_id = $stringImmutableAttemptItem.latest_attempt; work_item_id = $stringImmutableAttemptItem.work_item_id; plan_revision = 3; status = 'in-progress'; artifact_reference = 'runs/string-immutable-attempt.md' }
+)
+$stringImmutableAttemptContext = New-ApprovedOrchestrationContext
+$stringImmutableAttemptContext.plan_revisions[2].work_items = @($stringImmutableAttemptItem)
+$stringImmutableAttemptContext.resolved_artifacts = @(
+  (New-QueueResponsibilityArtifact $stringImmutableAttemptItem.responsibility_evidence $stringImmutableAttemptItem),
+  @{ artifact_reference = 'runs/string-immutable-attempt.md'; attempt_id = $stringImmutableAttemptItem.latest_attempt; work_item_id = $stringImmutableAttemptItem.work_item_id; plan_revision = 3; status = 'in-progress'; immutable = 'false' }
+)
+$stringImmutableAttemptResult = Invoke-ScopeScenario @{
+  scenario_type = 'scope-engine'; operation = 'select'; current_plan_revision = 3
+  orchestration_context = $stringImmutableAttemptContext; work_items = @($stringImmutableAttemptItem)
+}
+Assert-Equal $stringImmutableAttemptResult.reason 'attempt-artifact-binding-invalid' 'String false immutable must reject at attempt artifact authority'
+
 $activeRecordA = New-WorkItem 'WORK-ADMIN-ACTIVE-RECORD-A' 1 @() 'ready'
 $activeRecordA.latest_attempt = 'ATTEMPT-WORK-ADMIN-ACTIVE-RECORD-A-01'
 $activeRecordA.attempt_history = @(
   @{ attempt_id = 'ATTEMPT-WORK-ADMIN-ACTIVE-RECORD-A-01'; work_item_id = 'WORK-ADMIN-ACTIVE-RECORD-A'; plan_revision = 3; status = 'in-progress'; artifact_reference = 'runs/active-record-a.md' }
 )
 $activeRecordB = New-WorkItem 'WORK-ADMIN-ACTIVE-RECORD-B' 2 @() 'ready'
 $activeRecordB.latest_attempt = 'ATTEMPT-WORK-ADMIN-ACTIVE-RECORD-B-01'
 $activeRecordB.attempt_history = @(
   @{ attempt_id = 'ATTEMPT-WORK-ADMIN-ACTIVE-RECORD-B-01'; work_item_id = 'WORK-ADMIN-ACTIVE-RECORD-B'; plan_revision = 3; status = 'in-progress'; artifact_reference = 'runs/active-record-b.md' }
 )
@@ -1024,20 +1088,64 @@ $allCompleteReport = New-TerminalScopeReport 'runs/scope-terminal.md' @($complet
 $allComplete = Invoke-ScopeScenario @{
   scenario_type = 'scope-engine'
   operation = 'complete-scope'
   work_items = @($completeItem, $cancelled, $notApplicable)
   terminal_artifacts = @($completeTerminal, $cancelledTerminal, $notApplicableTerminal)
   responsibility_chain_artifacts = @($completeChain.Artifacts + $cancelledChain.Artifacts + $notApplicableChain.Artifacts)
   terminal_scope_report = $allCompleteReport
 }
 Assert-Equal $allComplete.scope_status 'scope-complete' 'All required terminal-success items with scope evidence must complete the scope'
 
+$forgedInitialCompletionChain = New-ResponsibilityChain 'runs/forged-initial-completion-chain' $completeItem.work_item_id
+$forgedInitialCompletionChain.Artifacts[0].source_artifact_reference = 'forged-predecessor.md'
+$forgedInitialCompletionTerminal = New-TerminalResponsibilityArtifact $completeItem.terminal_evidence $completeItem.work_item_id $completeItem.status $forgedInitialCompletionChain.FinalReference $forgedInitialCompletionChain.References $forgedInitialCompletionChain.ModeConstraint
+$forgedInitialCompletion = Invoke-ScopeScenario @{
+  scenario_type = 'scope-engine'; operation = 'complete-scope'; work_items = @($completeItem)
+  terminal_artifacts = @($forgedInitialCompletionTerminal)
+  responsibility_chain_artifacts = @($forgedInitialCompletionChain.Artifacts)
+  terminal_scope_report = (New-TerminalScopeReport 'runs/forged-initial-completion-report.md' @($completeItem) @($forgedInitialCompletionChain))
+}
+Assert-Equal $forgedInitialCompletion.scope_status 'scope-blocked' 'Scope completion must reject a forged index-0 implementation predecessor'
+
+$allNodeForgedCompletionChain = New-ResponsibilityChain 'runs/all-node-forged-completion-chain' $completeItem.work_item_id
+foreach ($artifact in @($allNodeForgedCompletionChain.Artifacts)) {
+  $artifact.task_base_sha = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
+  $artifact.final_tree_sha = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
+  $artifact.evidence_reference = "source-diff:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa..bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb#$($completeItem.work_item_id)"
+}
+$allNodeForgedCompletionTerminal = New-TerminalResponsibilityArtifact $completeItem.terminal_evidence $completeItem.work_item_id $completeItem.status $allNodeForgedCompletionChain.FinalReference $allNodeForgedCompletionChain.References $allNodeForgedCompletionChain.ModeConstraint
+$allNodeForgedCompletion = Invoke-ScopeScenario @{
+  scenario_type = 'scope-engine'; operation = 'complete-scope'; work_items = @($completeItem)
+  terminal_artifacts = @($allNodeForgedCompletionTerminal)
+  responsibility_chain_artifacts = @($allNodeForgedCompletionChain.Artifacts)
+  terminal_scope_report = (New-TerminalScopeReport 'runs/all-node-forged-completion-report.md' @($completeItem) @($allNodeForgedCompletionChain))
+}
+Assert-Equal $allNodeForgedCompletion.scope_status 'scope-blocked' 'Scope completion must bind every chain SHA/evidence pair to immutable Task Provenance'
+
+foreach ($terminalStringImmutableCase in @('terminal-report', 'terminal-artifact', 'terminal-chain-node')) {
+  $stringImmutableChain = New-ResponsibilityChain "runs/string-immutable-$terminalStringImmutableCase-chain" $completeItem.work_item_id
+  $stringImmutableTerminal = New-TerminalResponsibilityArtifact $completeItem.terminal_evidence $completeItem.work_item_id $completeItem.status $stringImmutableChain.FinalReference $stringImmutableChain.References $stringImmutableChain.ModeConstraint
+  $stringImmutableReport = New-TerminalScopeReport "runs/string-immutable-$terminalStringImmutableCase-report.md" @($completeItem) @($stringImmutableChain)
+  switch ($terminalStringImmutableCase) {
+    'terminal-report' { $stringImmutableReport.immutable = 'false' }
+    'terminal-artifact' { $stringImmutableTerminal.immutable = 'false' }
+    'terminal-chain-node' { $stringImmutableChain.Artifacts[2].immutable = 'false' }
+  }
+  $stringImmutableCompletion = Invoke-ScopeScenario @{
+    scenario_type = 'scope-engine'; operation = 'complete-scope'; work_items = @($completeItem)
+    terminal_artifacts = @($stringImmutableTerminal)
+    responsibility_chain_artifacts = @($stringImmutableChain.Artifacts)
+    terminal_scope_report = $stringImmutableReport
+  }
+  Assert-Equal $stringImmutableCompletion.scope_status 'scope-blocked' "String false immutable must reject at complete-scope $terminalStringImmutableCase authority"
+}
+
 $missingEvidenceIndexReport = New-TerminalScopeReport 'runs/scope-terminal-missing-index.md' @($completeItem) @($completeChain) $false
 $missingEvidenceIndex = Invoke-ScopeScenario @{
   scenario_type = 'scope-engine'; operation = 'complete-scope'
   work_items = @($completeItem)
   terminal_artifacts = @($completeTerminal)
   responsibility_chain_artifacts = @($completeChain.Artifacts)
   terminal_scope_report = $missingEvidenceIndexReport
 }
 Assert-Equal $missingEvidenceIndex.scope_status 'scope-blocked' 'Scope completion must require the terminal Evidence Index'
 Assert-Equal $missingEvidenceIndex.reason 'structural-assurance-blocked' 'A missing Evidence Index must fail the canonical structural terminal gate'
@@ -1645,20 +1753,38 @@ foreach ($terminalAuthorityCase in @(
     scenario_type = 'scope-engine'; operation = 'transition'; transition = 'successful-terminal-artifact'
     work_item_id = $caseItem.work_item_id; attempt_id = $caseAttempt
     terminal_evidence = $caseTerminalReference; terminal_artifact = $caseTerminal
     responsibility_chain_artifacts = @($caseChain.Artifacts); work_items = @($caseItem)
   }
   Assert-Equal $caseResult.result 'transition-invalid' "Successful transition must reject $($terminalAuthorityCase.Name) terminal responsibility authority"
   Assert-Equal $caseResult.reason 'terminal-responsibility-authority-invalid' "Terminal $($terminalAuthorityCase.Name) responsibility envelope must block completion"
   Assert-Equal $caseResult.scope_status 'scope-blocked' "Terminal $($terminalAuthorityCase.Name) authority must not complete the work item"
 }
 
+$stringImmutableTransitionItem = New-WorkItem 'WORK-ADMIN-TERMINAL-STRING-IMMUTABLE' 1 @() 'in-progress'
+$stringImmutableTransitionAttempt = 'ATTEMPT-WORK-ADMIN-TERMINAL-STRING-IMMUTABLE-01'
+$stringImmutableTransitionItem.latest_attempt = $stringImmutableTransitionAttempt
+$stringImmutableTransitionItem.attempt_history = @(
+  @{ attempt_id = $stringImmutableTransitionAttempt; work_item_id = $stringImmutableTransitionItem.work_item_id; plan_revision = 3; status = 'in-progress'; artifact_reference = 'runs/string-immutable-transition-in-progress.md' }
+)
+$stringImmutableTransitionChain = New-ResponsibilityChain 'runs/string-immutable-transition-chain' $stringImmutableTransitionItem.work_item_id
+$stringImmutableTransitionTerminal = New-TerminalResponsibilityArtifact 'runs/string-immutable-transition-terminal.md' $stringImmutableTransitionItem.work_item_id 'complete' $stringImmutableTransitionChain.FinalReference $stringImmutableTransitionChain.References $stringImmutableTransitionChain.ModeConstraint
+$stringImmutableTransitionTerminal.attempt_id = $stringImmutableTransitionAttempt
+$stringImmutableTransitionTerminal.immutable = 'false'
+$stringImmutableTransitionResult = Invoke-ScopeScenario @{
+  scenario_type = 'scope-engine'; operation = 'transition'; transition = 'successful-terminal-artifact'
+  work_item_id = $stringImmutableTransitionItem.work_item_id; attempt_id = $stringImmutableTransitionAttempt
+  terminal_evidence = $stringImmutableTransitionTerminal.artifact_reference; terminal_artifact = $stringImmutableTransitionTerminal
+  responsibility_chain_artifacts = @($stringImmutableTransitionChain.Artifacts); work_items = @($stringImmutableTransitionItem)
+}
+Assert-Equal $stringImmutableTransitionResult.reason 'terminal-artifact-binding-invalid' 'String false immutable must reject at successful terminal authority'
+
 foreach ($chainIndex in 1..4) {
   $caseItem = New-WorkItem "WORK-ADMIN-DOWNSTREAM-TRANSITION-$chainIndex" 1 @() 'in-progress'
   $caseAttempt = "ATTEMPT-$($caseItem.work_item_id)-01"
   $caseItem.latest_attempt = $caseAttempt
   $caseItem.attempt_history = @(
     @{ attempt_id = $caseAttempt; work_item_id = $caseItem.work_item_id; plan_revision = 3; status = 'in-progress'; artifact_reference = "runs/downstream-transition-$chainIndex-in-progress.md" }
   )
   $caseChain = New-ResponsibilityChain "runs/downstream-transition-$chainIndex-chain" $caseItem.work_item_id $caseItem.mode_constraint
   $caseChain.Artifacts[$chainIndex].status = 'draft'
   $caseTerminalReference = "runs/downstream-transition-$chainIndex-terminal.md"
@@ -1714,20 +1840,32 @@ $blockerWithoutArtifact = Invoke-ScopeScenario @{
   current_plan_revision = 3
   transition = 'native-blocker'
   work_item_id = 'WORK-ADMIN-CURRENT'
   attempt_id = 'ATTEMPT-WORK-ADMIN-CURRENT-01'
   terminal_evidence = 'runs/current-blocked.md'
   work_items = @($transitionCurrent)
 }
 Assert-Equal $blockerWithoutArtifact.result 'transition-invalid' 'Native blocker reference alone must not replace a bound immutable artifact'
 Assert-Equal $blockerWithoutArtifact.reason 'blocker-artifact-binding-invalid' 'Native blocker must report artifact binding failure'
 
+$stringImmutableBlocker = Invoke-ScopeScenario @{
+  scenario_type = 'scope-engine'; operation = 'transition'; current_plan_revision = 3
+  transition = 'native-blocker'; work_item_id = 'WORK-ADMIN-CURRENT'; attempt_id = 'ATTEMPT-WORK-ADMIN-CURRENT-01'
+  terminal_evidence = 'runs/current-string-immutable-blocked.md'
+  blocker_artifact = @{
+    artifact_reference = 'runs/current-string-immutable-blocked.md'; attempt_id = 'ATTEMPT-WORK-ADMIN-CURRENT-01'
+    work_item_id = 'WORK-ADMIN-CURRENT'; plan_revision = 3; result = 'blocked'; immutable = 'false'
+  }
+  work_items = @($transitionCurrent)
+}
+Assert-Equal $stringImmutableBlocker.reason 'blocker-artifact-binding-invalid' 'String false immutable must reject at native-blocker authority'
+
 $nonLatestBlockerItem = New-WorkItem 'WORK-ADMIN-NONLATEST-BLOCKER' 1 @() 'in-progress'
 $nonLatestBlockerItem.latest_attempt = 'ATTEMPT-WORK-ADMIN-NONLATEST-BLOCKER-02'
 $nonLatestBlockerItem.attempt_history = @(
   @{ attempt_id = 'ATTEMPT-WORK-ADMIN-NONLATEST-BLOCKER-01'; work_item_id = 'WORK-ADMIN-NONLATEST-BLOCKER'; plan_revision = 3; status = 'blocked'; artifact_reference = 'runs/nonlatest-01.md' },
   @{ attempt_id = 'ATTEMPT-WORK-ADMIN-NONLATEST-BLOCKER-02'; work_item_id = 'WORK-ADMIN-NONLATEST-BLOCKER'; plan_revision = 3; status = 'in-progress'; artifact_reference = 'runs/nonlatest-02.md' }
 )
 $nonLatestBlocker = Invoke-ScopeScenario @{
   scenario_type = 'scope-engine'; operation = 'transition'; current_plan_revision = 3
   transition = 'native-blocker'; work_item_id = 'WORK-ADMIN-NONLATEST-BLOCKER'
   attempt_id = 'ATTEMPT-WORK-ADMIN-NONLATEST-BLOCKER-01'; terminal_evidence = 'runs/nonlatest-blocker.md'
@@ -1757,20 +1895,32 @@ $cancelWithoutArtifact = Invoke-ScopeScenario @{
   current_plan_revision = 3
   transition = 'approved-cancellation'
   work_item_id = 'WORK-ADMIN-CANCEL'
   terminal_evidence = 'decision:cancel'
   approval_reference = 'approval:cancel'
   work_items = @($cancelItem)
 }
 Assert-Equal $cancelWithoutArtifact.result 'transition-invalid' 'Cancellation must require a structured immutable decision artifact'
 Assert-Equal $cancelWithoutArtifact.reason 'decision-artifact-binding-invalid' 'Cancellation must report decision binding failure'
 
+$stringImmutableCancellation = Invoke-ScopeScenario @{
+  scenario_type = 'scope-engine'; operation = 'transition'; current_plan_revision = 3
+  transition = 'approved-cancellation'; work_item_id = 'WORK-ADMIN-CANCEL'
+  terminal_evidence = 'decision:cancel'; approval_reference = 'approval:cancel'
+  decision_artifact = @{
+    artifact_reference = 'decision:cancel'; work_item_id = 'WORK-ADMIN-CANCEL'; plan_revision = 3
+    decision = 'cancelled-approved'; approval_reference = 'approval:cancel'; immutable = 'false'
+  }
+  work_items = @($cancelItem)
+}
+Assert-Equal $stringImmutableCancellation.reason 'decision-artifact-binding-invalid' 'String false immutable must reject at cancellation authority'
+
 $naItem = New-WorkItem 'WORK-ADMIN-NA-DECISION' 1
 $naWithoutApproval = Invoke-ScopeScenario @{
   scenario_type = 'scope-engine'
   operation = 'transition'
   current_plan_revision = 3
   transition = 'approved-non-applicability'
   work_item_id = 'WORK-ADMIN-NA-DECISION'
   terminal_evidence = 'decision:not-applicable'
   approval_reference = 'pending'
   work_items = @($naItem)
@@ -1784,20 +1934,32 @@ $naWithoutArtifact = Invoke-ScopeScenario @{
   current_plan_revision = 3
   transition = 'approved-non-applicability'
   work_item_id = 'WORK-ADMIN-NA-DECISION'
   terminal_evidence = 'decision:not-applicable'
   approval_reference = 'approval:not-applicable'
   work_items = @($naItem)
 }
 Assert-Equal $naWithoutArtifact.result 'transition-invalid' 'Non-applicability must require a structured immutable decision artifact'
 Assert-Equal $naWithoutArtifact.reason 'decision-artifact-binding-invalid' 'Non-applicability must report decision binding failure'
 
+$stringImmutableNonApplicability = Invoke-ScopeScenario @{
+  scenario_type = 'scope-engine'; operation = 'transition'; current_plan_revision = 3
+  transition = 'approved-non-applicability'; work_item_id = 'WORK-ADMIN-NA-DECISION'
+  terminal_evidence = 'decision:not-applicable'; approval_reference = 'approval:not-applicable'
+  decision_artifact = @{
+    artifact_reference = 'decision:not-applicable'; work_item_id = 'WORK-ADMIN-NA-DECISION'; plan_revision = 3
+    decision = 'not-applicable-approved'; approval_reference = 'approval:not-applicable'; immutable = 'false'
+  }
+  work_items = @($naItem)
+}
+Assert-Equal $stringImmutableNonApplicability.reason 'decision-artifact-binding-invalid' 'String false immutable must reject at non-applicability authority'
+
 # Scope changes create a new immutable revision, invalidate affected approval,
 # and preserve unaffected completed evidence.
 $revision = Invoke-ScopeScenario @{
   scenario_type = 'scope-engine'
   operation = 'revise'
   current = @{
     artifact_id = 'PLAN-ADMIN-001'
     revision = 3
     status = 'approved'
     work_items = @(
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/validate-migration-framework.Tests.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/validate-migration-framework.Tests.ps1
index bacf071..15ef650 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/validate-migration-framework.Tests.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/validate-migration-framework.Tests.ps1
@@ -387,20 +387,47 @@ if ($ResponsibilityConformanceOnly) {
   }
   finally {
     $ErrorActionPreference = $previousErrorActionPreference
   }
   Assert-True ($sourceIntegrity.ExitCode -eq 0) "Responsibility source-integrity baseline should pass. Output: $($sourceIntegrity.Output)"
   Assert-Contains $sourceIntegrity.Output 'PASS: migration framework (SourceIntegrityOnly)' 'Responsibility source-integrity baseline'
   if ($sourceIntegrity.ExitCode -ne 0) {
     $testFailures | ForEach-Object { Write-Output "FAIL: $_" }
     exit 1
   }
+  $commentedCoverageResult = Invoke-IsolatedMutation -SourceRoot $testRoot -Mutation {
+    param($fixtureRoot)
+    $fixtureScenario = Join-Path $fixtureRoot 'tests/scenarios/scope-engine.Tests.ps1'
+    $fixtureText = [IO.File]::ReadAllText($fixtureScenario, [Text.Encoding]::UTF8)
+    $mutatedText = Replace-ExactOrFail `
+      $fixtureText `
+      "Assert-Equal `$responsibilityChainSelection.work_item_id '' 'No dependent item may be selected after a responsibility mismatch'" `
+      "# Assert-Equal `$responsibilityChainSelection.work_item_id '' 'No dependent item may be selected after a responsibility mismatch'" `
+      'commented coverage registration'
+    [IO.File]::WriteAllText($fixtureScenario, $mutatedText, [Text.UTF8Encoding]::new($false))
+    $fixtureValidator = Join-Path $fixtureRoot 'tests/validate-migration-framework.ps1'
+    $previousFixtureErrorActionPreference = $ErrorActionPreference
+    $ErrorActionPreference = 'Continue'
+    try {
+      $output = & $powershell -NoProfile -ExecutionPolicy Bypass -File $fixtureValidator -Check SourceIntegrityOnly -Root $fixtureRoot -AllowReducedResponsibilityFixture 2>&1
+      $exitCode = $LASTEXITCODE
+    }
+    finally {
+      $ErrorActionPreference = $previousFixtureErrorActionPreference
+    }
+    [pscustomobject]@{
+      ExitCode = $exitCode
+      Output = ($output -join [Environment]::NewLine)
+    }
+  }
+  Assert-True ($commentedCoverageResult.ExitCode -eq 1) "Commented coverage registration must fail source integrity. Output: $($commentedCoverageResult.Output)"
+  Assert-Contains $commentedCoverageResult.Output 'Responsibility source-integrity coverage missing: post-implementation queue advance' 'Commented coverage registration'
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
index c1a6837..a45f7db 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/validate-migration-framework.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/validate-migration-framework.ps1
@@ -9680,25 +9680,52 @@ function Test-ResponsibilitySourceIntegrity {
     [pscustomobject]@{ Name = 'extra public symbol while tree matches'; Path = 'tests/scenarios/responsibility-conformance.Tests.ps1'; Token = "Assert-ImplementationRejected 'actual matrix rejects public symbol drift even when tree path matches'" }
     [pscustomobject]@{ Name = 'extra effect while tree matches'; Path = 'tests/scenarios/responsibility-conformance.Tests.ps1'; Token = "Assert-ImplementationRejected 'actual matrix rejects external-effect drift'" }
     [pscustomobject]@{ Name = 'invalid verification not-applicable'; Path = 'tests/scenarios/responsibility-conformance.Tests.ps1'; Token = "Assert-ImplementationRejected 'behavior owner cannot use not-applicable-approved verification'" }
     [pscustomobject]@{ Name = 'fake production composition'; Path = 'tests/scenarios/responsibility-conformance.Tests.ps1'; Token = 'Assert-ReviewRejected "review rejects test-only fake production composition evidence' }
     [pscustomobject]@{ Name = 'implementation self-attestation bypass'; Path = 'tests/scenarios/architecture-review.Tests.ps1'; Token = 'Assert-FailsLike "review independently rejects omitted actual owner' }
     [pscustomobject]@{ Name = 'downstream sub-verdict loss'; Path = 'tests/scenarios/responsibility-handoff.Tests.ps1'; Token = "Assert-HandoffDiagnosticsExactly 'rejects a downstream artifact with no responsibility handoff table'" }
     [pscustomobject]@{ Name = 'downstream sub-verdict mutation'; Path = 'tests/scenarios/responsibility-handoff.Tests.ps1'; Token = "Assert-HandoffRejected 'rejects a downstream aggregate PASS that hides responsibility BLOCKED'" }
     [pscustomobject]@{ Name = 'runtime waiver override'; Path = 'tests/scenarios/responsibility-handoff.Tests.ps1'; Token = "Assert-HandoffRejected 'runtime waiver cannot overwrite a blocked responsibility handoff'" }
     [pscustomobject]@{ Name = 'post-implementation queue advance'; Path = 'tests/scenarios/scope-engine.Tests.ps1'; Token = "Assert-Equal `$responsibilityChainSelection.work_item_id '' 'No dependent item may be selected after a responsibility mismatch'" }
   )
+  $activeCoverageCommandsByPath = @{}
   foreach ($requirement in $coverage) {
     $path = Join-Path $root $requirement.Path
     if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
-    $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
-    if ($text.IndexOf($requirement.Token, [StringComparison]::Ordinal) -lt 0) {
+    if (-not $activeCoverageCommandsByPath.ContainsKey($requirement.Path)) {
+      $parseTokens = $null
+      $parseErrors = $null
+      $ast = [Management.Automation.Language.Parser]::ParseFile($path, [ref]$parseTokens, [ref]$parseErrors)
+      $activeCoverageCommandsByPath[$requirement.Path] = @($ast.FindAll({
+        param($node)
+        if ($node -isnot [Management.Automation.Language.CommandAst]) { return $false }
+        $ancestor = $node.Parent
+        while ($null -ne $ancestor) {
+          if (
+            $ancestor -is [Management.Automation.Language.FunctionDefinitionAst] -or
+            $ancestor -is [Management.Automation.Language.ScriptBlockExpressionAst]
+          ) { return $false }
+          $ancestor = $ancestor.Parent
+        }
+        return $true
+      }, $true))
+    }
+    $commandNameSeparator = $requirement.Token.IndexOf(' ', [StringComparison]::Ordinal)
+    $expectedCommandName = if ($commandNameSeparator -gt 0) {
+      $requirement.Token.Substring(0, $commandNameSeparator)
+    }
+    else { $requirement.Token }
+    $hasActiveRegistration = @($activeCoverageCommandsByPath[$requirement.Path] | Where-Object {
+      $_.GetCommandName() -ceq $expectedCommandName -and
+        $_.Extent.Text.IndexOf($requirement.Token, [StringComparison]::Ordinal) -ge 0
+    }).Count -gt 0
+    if (-not $hasActiveRegistration) {
       $errors.Add("Responsibility source-integrity coverage missing: $($requirement.Name)")
     }
   }
 
   $registrationRequirements = @(
     [pscustomobject]@{ Path = 'contracts/file-responsibility-conformance.md'; Token = 'version = 1'; Context = 'canonical contract' }
     [pscustomobject]@{ Path = 'skills/aitoolkit-schemas/SKILL.md'; Token = 'contracts/file-responsibility-conformance.md'; Context = 'schema route' }
     [pscustomobject]@{ Path = 'skills/migration/code-migration/SKILL.md'; Token = 'Actual File Responsibility Matrix'; Context = 'implementation skill' }
     [pscustomobject]@{ Path = 'skills/shared/ai-review/SKILL.md'; Token = 'Responsibility Conformance Verdict'; Context = 'review skill' }
     [pscustomobject]@{ Path = 'skills/aitoolkit/migrate/SKILL.md'; Token = 'approved design/master-plan revision required'; Context = 'orchestrator safe stop' }
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/architecture-review.validation.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/architecture-review.validation.ps1
index 2ff444c..6784c5b 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/architecture-review.validation.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/architecture-review.validation.ps1
@@ -116,20 +116,21 @@ function Test-ArchitectureReview([string]$Root, [string]$ContractText) {
     }
   }
   if (@($paths.Values | Where-Object { -not (Test-Path -LiteralPath $_ -PathType Leaf) }).Count -gt 0) {
     return
   }
 
   $reviewSkill = Get-Content -Raw -Encoding utf8 -LiteralPath $paths.ReviewSkill
   $knowledgeSkill = Get-Content -Raw -Encoding utf8 -LiteralPath $paths.KnowledgeSkill
   $reviewTemplate = Get-Content -Raw -Encoding utf8 -LiteralPath $paths.ReviewTemplate
   $knowledgeTemplate = Get-Content -Raw -Encoding utf8 -LiteralPath $paths.KnowledgeTemplate
+  $visibleReviewTemplate = Get-ArcVisibleMarkdownText -Text $reviewTemplate
 
   $getHeadings = {
     param([string]$Text)
     $records = [Collections.Generic.List[object]]::new()
     $inFence = $false
     $fenceMarker = ''
     $inComment = $false
     $lines = @($Text -split '\r?\n')
     for ($index = 0; $index -lt $lines.Count; $index++) {
       $line = $lines[$index]
@@ -345,21 +346,21 @@ function Test-ArchitectureReview([string]$Root, [string]$ContractText) {
   $verdictValues = [ordered]@{}
   $verdictModes = [Collections.Generic.List[string]]::new()
   @(
     [pscustomobject]@{ Label = 'Architecture Conformance Verdict'; Schema = 'PASS | BLOCKED'; Allowed = @('PASS', 'BLOCKED') }
     [pscustomobject]@{ Label = 'Canonical Selector Verdict'; Schema = 'PASS | BLOCKED'; Allowed = @('PASS', 'BLOCKED') }
     [pscustomobject]@{ Label = 'Tree Conformance Verdict'; Schema = 'PASS | BLOCKED'; Allowed = @('PASS', 'BLOCKED') }
     [pscustomobject]@{ Label = 'Responsibility Conformance Verdict'; Schema = 'PASS | BLOCKED'; Allowed = @('PASS', 'BLOCKED') }
     [pscustomobject]@{ Label = 'Verification Ownership Verdict'; Schema = 'PASS | BLOCKED'; Allowed = @('PASS', 'BLOCKED') }
     [pscustomobject]@{ Label = 'Production Activation-path Verdict'; Schema = 'PASS | BLOCKED | NOT_APPLICABLE'; Allowed = @('PASS', 'BLOCKED', 'NOT_APPLICABLE') }
   ) | ForEach-Object {
-    $matches = [regex]::Matches($reviewTemplate, '(?im)^[ \t]*-[ \t]*(?:\*\*)?' + [regex]::Escape($_.Label) + '(?:\*\*)?:[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$')
+    $matches = [regex]::Matches($visibleReviewTemplate, '(?im)^[ \t]*-[ \t]*(?:\*\*)?' + [regex]::Escape($_.Label) + '(?:\*\*)?:[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$')
     if ($matches.Count -ne 1) {
       $errors.Add("Migration review report $($_.Label) must appear exactly once with the exact enum; found $($matches.Count)")
       return
     }
     $value = $matches[0].Groups['value'].Value.Trim().Trim([char[]]@('<', '>', '`'))
     if ($value -ceq $_.Schema) {
       $verdictModes.Add('schema')
     }
     elseif ($value -in $_.Allowed) {
       $verdictModes.Add('rendered')
@@ -426,35 +427,35 @@ function Test-ArchitectureReview([string]$Root, [string]$ContractText) {
         $finalTreeSha = $finalTreeMatches[0].Groups['value'].Value
         foreach ($error in @(Test-ResponsibilityReview -DesignText $designArtifact -ImplementationText $implementationArtifact -ReviewText $reviewArtifact -ContractText $responsibilityContract -SourceRoot $sourceRoot -TaskBaseSha $taskBaseSha -FinalTreeSha $finalTreeSha -ApprovedPlanText $approvedPlanArtifact)) {
           $errors.Add($error)
         }
       }
     }
   }
   $activationSection = & $getSection $reviewTemplate 'Production Activation Path' 'Migration review report'
   @('Production Activation Path Evidence:', 'Production Subscription Key:', 'Lifecycle Gate:') |
     ForEach-Object { Require-Token $activationSection $_ 'Migration review production activation path' }
-  $behaviorSection = & $getSection $reviewTemplate 'Behavior, Failure Modes, Security, Performance, and Tests' 'Migration review report'
+  $behaviorSection = & $getSection $visibleReviewTemplate 'Behavior, Failure Modes, Security, Performance, and Tests' 'Migration review report'
   Require-Token $behaviorSection 'Behavior Analysis State:' 'Migration review behavior analysis'
   $behaviorMatches = [regex]::Matches($behaviorSection, '(?im)^[ \t]*-[ \t]*Behavior Analysis State:[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$')
   $behaviorState = ''
   if ($behaviorMatches.Count -ne 1) {
     $errors.Add("Migration review report Behavior Analysis State must appear exactly once; found $($behaviorMatches.Count)")
   }
   else {
     $behaviorState = $behaviorMatches[0].Groups['value'].Value.Trim().Trim([char[]]@('<', '>', '`'))
     if ($behaviorState -ceq 'NOT_RUN | COMPLETE') { $verdictModes.Add('schema') }
     elseif ($behaviorState -in @('NOT_RUN', 'COMPLETE')) { $verdictModes.Add('rendered') }
     else { $errors.Add("Migration review report Behavior Analysis State has invalid value: $behaviorState") }
   }
 
-  $overallMatches = [regex]::Matches($reviewTemplate, '(?im)^[ \t]*-[ \t]*(?:\*\*)?Verdict(?:\*\*)?:[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$')
+  $overallMatches = [regex]::Matches($visibleReviewTemplate, '(?im)^[ \t]*-[ \t]*(?:\*\*)?Verdict(?:\*\*)?:[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$')
   if ($overallMatches.Count -ne 1) {
     $errors.Add("Migration review report overall Verdict must appear exactly once; found $($overallMatches.Count)")
   }
   else {
     $overallVerdict = $overallMatches[0].Groups['value'].Value.Trim().Trim([char[]]@('<', '>', '`'))
     if ($overallVerdict -ceq 'Approve | Approve-with-fixes | Reject') {
       $verdictModes.Add('schema')
     }
     elseif ($overallVerdict -in @('Approve', 'Approve-with-fixes', 'Reject')) {
       $verdictModes.Add('rendered')
@@ -474,28 +475,28 @@ function Test-ArchitectureReview([string]$Root, [string]$ContractText) {
       if ($overallVerdict -cne 'Reject') {
         $errors.Add('Migration review report requires overall Reject when any architecture-first verdict is BLOCKED, independently of severity counts')
       }
       if ($behaviorState -cne 'NOT_RUN') {
         $errors.Add('Migration review report must stop before behavior analysis when an architecture-first verdict is BLOCKED')
       }
     }
   }
 
   if (
-    $reviewTemplate -cnotmatch '(?s)Keep `Selected Migration Unit` only when `Delivery Adapter Kind` is `migration-unit`.*otherwise omit it\.' -and
-    $reviewTemplate -cnotmatch '(?s)Chỉ giữ `Selected Migration Unit` khi `Delivery Adapter Kind` là `migration-unit`.*otherwise omit it\.'
+    $visibleReviewTemplate -cnotmatch '(?s)Keep `Selected Migration Unit` only when `Delivery Adapter Kind` is `migration-unit`.*otherwise omit it\.' -and
+    $visibleReviewTemplate -cnotmatch '(?s)Chỉ giữ `Selected Migration Unit` khi `Delivery Adapter Kind` là `migration-unit`.*otherwise omit it\.'
   ) {
     $errors.Add('Migration review report must keep Selected Migration Unit only for the migration-unit adapter and otherwise omit it')
   }
 
   $selectedHeadings = @(& $getHeadings $reviewTemplate | Where-Object { $_.Level -eq 2 -and $_.Name -ceq 'Selected Migration Unit' })
-  $adapterMatches = [regex]::Matches($reviewTemplate, '(?im)^[ \t]*-[ \t]*Delivery Adapter Kind:[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$')
+  $adapterMatches = [regex]::Matches($visibleReviewTemplate, '(?im)^[ \t]*-[ \t]*Delivery Adapter Kind:[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$')
   $adapterKind = if ($adapterMatches.Count -eq 1) {
     $adapterMatches[0].Groups['value'].Value.Trim().Trim([char[]]@('<', '>', '`'))
   }
   else {
     $errors.Add("Migration review report Delivery Adapter Kind must appear exactly once; found $($adapterMatches.Count)")
     ''
   }
   $adapterKinds = @('migration-unit', 'task', 'story', 'package', 'phase', 'milestone', 'none')
   $adapterSchemaMode = $adapterKind -in @('kind', 'migration-unit | task | story | package | phase | milestone | none')
   if (
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1
index 571dd68..2778efd 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1
@@ -491,20 +491,55 @@ function Test-ArcDiscoveryResponsibilityContractVersion {
   if (
     $children.Count -ne 2 -or
     $versionChildren.Count -ne 1 -or
     $applicabilityChildren.Count -ne 1
   ) {
     return @('responsibility-contract-version-invalid')
   }
   return @()
 }
 
+function Test-ArcCanonicalDiscoverySourceEvidence {
+  [CmdletBinding()]
+  param([string]$Evidence, [string[]]$AllowedKinds)
+
+  $kindPattern = '(?:' + (@($AllowedKinds | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')'
+  $envelope = [regex]::Match($Evidence, '^(?<kind>' + $kindPattern + '):(?<reference>.+)$')
+  if (-not $envelope.Success) { return $false }
+  $reference = $envelope.Groups['reference'].Value
+  $path = ''
+  if ($reference.Contains('#')) {
+    $anchorMatch = [regex]::Match($reference, '^(?<path>[^#]+)#(?<anchor>[A-Za-z][A-Za-z0-9_.:-]*)$')
+    if (-not $anchorMatch.Success) { return $false }
+    $path = $anchorMatch.Groups['path'].Value
+  }
+  else {
+    $lineMatch = [regex]::Match($reference, '^(?<path>.+):(?<start>[1-9][0-9]*)(?:-(?<end>[1-9][0-9]*))?$')
+    if (-not $lineMatch.Success) { return $false }
+    if ($lineMatch.Groups['end'].Success -and [int64]$lineMatch.Groups['end'].Value -lt [int64]$lineMatch.Groups['start'].Value) { return $false }
+    $path = $lineMatch.Groups['path'].Value
+  }
+  $canonicalPath = ConvertTo-ArcCanonicalRepositoryPath -Path $path
+  return $canonicalPath -cne '' -and $path -ceq $canonicalPath
+}
+
+function Test-ArcCanonicalDiscoverySearchEvidence {
+  [CmdletBinding()]
+  param([string]$Evidence)
+
+  $match = [regex]::Match($Evidence, '^search:(?<path>[^#]+)#(?:query|search)=[A-Za-z0-9_.:-]+,(?:result|matches)=(?:0|none)$')
+  if (-not $match.Success) { return $false }
+  $path = $match.Groups['path'].Value
+  $canonicalPath = ConvertTo-ArcCanonicalRepositoryPath -Path $path
+  return $canonicalPath -cne '' -and $path -ceq $canonicalPath
+}
+
 function Test-ResponsibilityDiscovery {
   [CmdletBinding()]
   param([AllowEmptyString()][string]$DiscoveryText, [ValidateSet('incremental','greenfield')][string]$Mode, [string]$ContractText)
 
   $errors = [Collections.Generic.List[string]]::new()
   foreach ($error in @(Test-ArcResponsibilityStageVersion $ContractText 'DISCOVERY')) { $errors.Add($error) }
   if ([string]::IsNullOrWhiteSpace($DiscoveryText)) {
     $errors.Add('responsibility-discovery-missing')
     return $errors.ToArray()
   }
@@ -560,21 +595,21 @@ function Test-ResponsibilityDiscovery {
       ($classification -ceq 'no-equivalent' -and $status -cne 'no-equivalent') -or
       ($classification -cne 'no-equivalent' -and $status -cne 'verified')
     )
     switch ($classification) {
       'preferred' {
         $evidenceItems = @($classificationEvidence.Split(';') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
         if (
           $authority -cne 'factual-discovery-evidence' -or
           $evidenceItems.Count -lt 2 -or
           @($evidenceItems | Sort-Object -Unique).Count -ne $evidenceItems.Count -or
-          @($evidenceItems | Where-Object { $_ -cnotmatch '^(?:inspection|working-evidence):(?:[A-Za-z0-9_-]+/)*[A-Za-z0-9_.-]+\.(?:md|ps1|dart)(?:#[A-Za-z0-9_.:-]+|:[0-9]+(?:-[0-9]+)?)$' }).Count -gt 0 -or
+          @($evidenceItems | Where-Object { -not (Test-ArcCanonicalDiscoverySourceEvidence -Evidence $_ -AllowedKinds @('inspection', 'working-evidence')) }).Count -gt 0 -or
           $classificationEvidence -match '(?i)(?:^|;)\s*(?:authoritative-)?conflict:' -or
           @($evidenceItems | Where-Object { $_ -cmatch '\.md#(?:CONFLICT|DEBT)-[A-Z0-9]+(?:-[A-Z0-9]+)*$' }).Count -gt 0
         ) { $invalidAuthority = $true }
       }
       'compatibility-only' {
         if ($authority -ceq 'project-pack-rule') {
           if ($classificationEvidence -cnotmatch '^[A-Za-z0-9_./-]+\.md#RULE-[A-Z0-9-]+$') { $invalidAuthority = $true }
         }
         elseif ($authority -ceq 'approved-owner-decision') {
           if ($classificationEvidence -cnotmatch '^approval:OWNER-[A-Z0-9-]+$') { $invalidAuthority = $true }
@@ -589,21 +624,24 @@ function Test-ResponsibilityDiscovery {
           if ($classificationEvidence -cnotmatch '^debt-record:[A-Z0-9-]+$') { $invalidAuthority = $true }
         }
         elseif ($authority -ceq 'tech-lead-approved-conflict') {
           if ($classificationEvidence -cnotmatch '^approval:TECH-LEAD-[A-Z0-9-]+$') { $invalidAuthority = $true }
         }
         else { $invalidAuthority = $true }
       }
       'no-equivalent' {
         if (
           $authority -cne 'factual-discovery-evidence' -or
-          $classificationEvidence -cnotmatch '^(?:search:(?:[A-Za-z0-9_-]+/)*[A-Za-z0-9_.-]+\.md#(?:query|search)=[A-Za-z0-9_.:-]+,(?:result|matches)=(?:0|none)|inspection:(?:[A-Za-z0-9_-]+/)*[A-Za-z0-9_.-]+\.(?:md|ps1|dart)(?:#[A-Za-z0-9_.:-]+|:[0-9]+(?:-[0-9]+)?))$'
+          -not (
+            (Test-ArcCanonicalDiscoverySearchEvidence -Evidence $classificationEvidence) -or
+            (Test-ArcCanonicalDiscoverySourceEvidence -Evidence $classificationEvidence -AllowedKinds @('inspection'))
+          )
         ) { $invalidAuthority = $true }
       }
       default { $invalidAuthority = $true }
     }
     if ($invalidAuthority) { $errors.Add('exemplar-classification-authority-missing') }
   }
   return @($errors | Select-Object -Unique)
 }
 
 function Test-ResponsibilityDesign {
@@ -1250,24 +1288,29 @@ function Test-ResponsibilityImplementation {
     param([object]$Cells, [string[]]$Columns)
     $row = @{}
     for ($index = 0; $index -lt $Columns.Count; $index++) { $row[$Columns[$index]] = [string]$Cells[$index] }
     return $row
   }
   $allDesignResponsibilities = @($designResponsibilityTable | Select-Object -Skip 2 | ForEach-Object { & $toRow $_ $responsibilityColumns })
   $actualResponsibilities = @($actualResponsibilityTable | Select-Object -Skip 2 | ForEach-Object { & $toRow $_ $actualResponsibilityColumns })
   $allDesignVerifications = @($designVerificationTable | Select-Object -Skip 2 | ForEach-Object { & $toRow $_ $verificationColumns })
   $actualVerifications = @($actualVerificationTable | Select-Object -Skip 2 | ForEach-Object { & $toRow $_ $actualVerificationColumns })
   $missing = { param([string]$Value) [string]::IsNullOrWhiteSpace($Value) -or $Value -match '^\s*<[^>]+>\s*$' -or $Value -match '^(?i:pending|unknown|none|tbd)$' }
+  $missingVerificationEvidence = {
+    param([string]$Value)
+    (& $missing $Value) -or $Value -match '^(?i:not[- ]?applicable|n/?a|placeholder|todo)$'
+  }
   $hasActualEvidence = { param([string]$Value) -not (& $missing $Value) -and $Value -cmatch '^(?:diff|source):\S' }
   $splitList = { param([string]$Value) @($Value -split '[,;]' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }) }
   $validEvidenceKinds = @(Get-ArcContractEnumValues -ContractText $ContractText -Name 'Evidence Kind')
   $validDispositions = @(Get-ArcContractEnumValues -ContractText $ContractText -Name 'Verification Disposition')
+  $requiredVerificationRowsPass = $true
 
   $ownerReferenceRows = @($ownerReferenceTable | Select-Object -Skip 2 | ForEach-Object { & $toRow $_ $ownerReferenceColumns })
   $selectedResponsibilityIds = @()
   if ($ownerReferenceRows.Count -ne 1) { $errors.Add('responsibility-owner-missing') }
   else {
     $ownerReference = $ownerReferenceRows[0]
     foreach ($field in @('Responsibility IDs', 'Shared Foundation IDs', 'Integration Responsibility IDs')) {
       if ($ownerReference[$field] -cne 'not-applicable') { $selectedResponsibilityIds += @(& $splitList $ownerReference[$field]) }
     }
     if ($ownerReference['Work Item ID'] -cnotmatch '^WORK-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -or $ownerReference['Design Revision'] -cnotmatch '^DESIGN-[A-Z0-9]+(?:-[A-Z0-9]+)*@[1-9][0-9]*$' -or (& $missing $ownerReference['Independent Boundary Evidence']) -or $selectedResponsibilityIds.Count -eq 0) { $errors.Add('responsibility-owner-missing') }
@@ -1296,45 +1339,71 @@ function Test-ResponsibilityImplementation {
   }
 
   $designVerificationByKey = @{}; foreach ($row in $designVerifications) { $key = "$($row['Verification Owner ID'])|$($row['Production Responsibility ID'])|$($row['Capability ID'])"; if ($designVerificationByKey.ContainsKey($key)) { $errors.Add('verification-owner-extra') } else { $designVerificationByKey[$key] = $row } }
   $actualVerificationByKey = @{}; foreach ($row in $actualVerifications) {
     $key = "$($row['Verification Owner ID'])|$($row['Production Responsibility ID'])|$($row['Capability ID'])"
     if ($actualVerificationByKey.ContainsKey($key)) { $errors.Add('verification-owner-extra') } else { $actualVerificationByKey[$key] = $row }
     if (-not (& $hasActualEvidence $row['Actual Evidence'])) { $errors.Add('verification-production-binding-missing') }
     if ($validEvidenceKinds -cnotcontains $row['Evidence Kind'] -or $validDispositions -cnotcontains $row['Verification Disposition'] -or $row['Verdict'] -cnotin @('PASS', 'BLOCKED')) {
       $errors.Add('verification-disposition-invalid')
     }
+    if ($row['Verification Disposition'] -ceq 'required') {
+      $canonicalEvidencePath = ConvertTo-ArcCanonicalRepositoryPath -Path $row['Evidence Path']
+      $canonicalEvidenceScenario = $row['Evidence Symbol or Scenario']
+      $evidencePathInvalid =
+        $canonicalEvidencePath -ceq '' -or
+        $canonicalEvidencePath -cne $row['Evidence Path'] -or
+        (& $missingVerificationEvidence $row['Evidence Path'])
+      $evidenceScenarioInvalid = & $missingVerificationEvidence $canonicalEvidenceScenario
+      if (
+        $row['Verdict'] -cne 'PASS' -or
+        $evidencePathInvalid -or
+        $evidenceScenarioInvalid
+      ) {
+        $requiredVerificationRowsPass = $false
+        if ($evidencePathInvalid -or $evidenceScenarioInvalid) {
+          $errors.Add('verification-production-binding-missing')
+        }
+      }
+    }
     if ($actualById.ContainsKey($row['Production Responsibility ID'])) {
       $production = $actualById[$row['Production Responsibility ID']]
       $bindingTarget = "$($production['Owner Path'])#$($production['Owner Symbol'])"
       if ((& $missing $row['Production Binding Evidence']) -or $row['Production Binding Evidence'].IndexOf($bindingTarget, [StringComparison]::Ordinal) -lt 0) { $errors.Add('verification-production-binding-missing') }
       if ($row['Verification Disposition'] -ceq 'not-applicable-approved') {
         if (-not (Test-ArcNotApplicableApprovedEligibility -ProductionRow $production -VerificationRow $row -ContractText $ContractText)) { $errors.Add('verification-disposition-invalid') }
       }
       elseif ($row['Decision Reference'] -cne 'not-applicable') { $errors.Add('verification-disposition-invalid') }
       if (@(& $splitList $production['Owned Capability IDs']) -cnotcontains $row['Capability ID']) { $errors.Add('verification-owner-extra') }
     }
   }
-  foreach ($key in $designVerificationByKey.Keys) { if (-not $actualVerificationByKey.ContainsKey($key)) { $errors.Add('verification-owner-missing') } }
+  foreach ($key in $designVerificationByKey.Keys) {
+    if (-not $actualVerificationByKey.ContainsKey($key)) {
+      $errors.Add('verification-owner-missing')
+      if ($designVerificationByKey[$key]['Verification Disposition'] -ceq 'required') { $requiredVerificationRowsPass = $false }
+    }
+  }
   foreach ($key in $actualVerificationByKey.Keys) { if (-not $designVerificationByKey.ContainsKey($key)) { $errors.Add('verification-owner-extra') } }
   foreach ($key in $designVerificationByKey.Keys | Where-Object { $actualVerificationByKey.ContainsKey($_) }) {
     $planned = $designVerificationByKey[$key]; $actual = $actualVerificationByKey[$key]
     foreach ($field in $verificationColumns) { if ($planned[$field] -cne $actual[$field]) { $errors.Add('verification-production-binding-missing'); break } }
   }
 
   $verdictRows = @($verdictTable | Select-Object -Skip 2)
   if ($verdictRows.Count -ne 1) { $errors.Add('responsibility-owner-extra') }
   else {
     $verdict = & $toRow $verdictRows[0] $verdictColumns
     if ($verdict['Responsibility Contract Version'] -cne '1' -or (& $missing $verdict['Evidence References'])) { $errors.Add('responsibility-contract-version-invalid') }
     foreach ($field in @('Tree Conformance', 'Responsibility Conformance', 'Verification Ownership', 'Architecture Conformance State')) { if ($verdict[$field] -cnotin @('PASS', 'BLOCKED')) { $errors.Add('responsibility-owner-extra') } }
     $derived = if ($verdict['Tree Conformance'] -ceq 'PASS' -and $verdict['Responsibility Conformance'] -ceq 'PASS' -and $verdict['Verification Ownership'] -ceq 'PASS') { 'PASS' } else { 'BLOCKED' }
+    $derivedVerificationOwnership = if ($requiredVerificationRowsPass) { 'PASS' } else { 'BLOCKED' }
+    if ($verdict['Verification Ownership'] -cne $derivedVerificationOwnership) { $errors.Add('responsibility-waiver-forbidden') }
     if ($verdict['Architecture Conformance State'] -cne $derived) { $errors.Add('responsibility-waiver-forbidden') }
   }
   return @($errors | Select-Object -Unique)
 }
 
 function Invoke-ArcPinnedGit {
   [CmdletBinding()]
   param([Parameter(Mandatory)][string]$SourceRoot, [Parameter(Mandatory)][string[]]$Arguments)
 
   $output = @(& git -C $SourceRoot @Arguments 2>$null)
@@ -1511,20 +1580,91 @@ function Test-ArcDeletedSourceEvidence {
       $anchors.Add($routeMatch.Groups['provider'].Value)
     }
     if ($removedDiff.IndexOf("@responsibility $($ownerMatch.Groups['id'].Value)", [StringComparison]::Ordinal) -lt 0 -or @($anchors | Select-Object -Unique | Where-Object { $removedDiff.IndexOf($_, [StringComparison]::Ordinal) -lt 0 }).Count -gt 0) {
       $Errors.Add('responsibility-evidence-missing')
     }
     $deletedOwners.Add($owner)
   }
   return $deletedOwners.ToArray()
 }
 
+function Test-ArcCommentOnlySourceLine {
+  [CmdletBinding()]
+  param([AllowEmptyString()][string]$Line)
+
+  return [string]::IsNullOrWhiteSpace($Line) -or $Line -cmatch '^\s*(?:#|//|--|;|/\*|\*|\*/|<!--|-->|<#|#>)'
+}
+
+function Get-ArcResponsibilitySourceBlocks {
+  [CmdletBinding()]
+  param([AllowEmptyString()][string]$SourceText)
+
+  $lines = @($SourceText -split '\r?\n')
+  $markerIndexes = [Collections.Generic.List[int]]::new()
+  for ($index = 0; $index -lt $lines.Count; $index++) {
+    if ($lines[$index] -cmatch '^\s*@responsibility\s+RESP-[A-Z0-9]+(?:-[A-Z0-9]+)*\s*$') { $markerIndexes.Add($index) }
+  }
+  $blocks = [Collections.Generic.List[object]]::new()
+  for ($markerOrdinal = 0; $markerOrdinal -lt $markerIndexes.Count; $markerOrdinal++) {
+    $start = $markerIndexes[$markerOrdinal]
+    $candidateEnd = if ($markerOrdinal + 1 -lt $markerIndexes.Count) { $markerIndexes[$markerOrdinal + 1] - 1 } else { $lines.Count - 1 }
+    $metadataEnd = $start
+    for ($index = $start + 1; $index -le $candidateEnd; $index++) {
+      if ($lines[$index] -cmatch '^\s*@(owner-symbol|public-symbol|owned-capability|effect|architecture-authority|co-location-policy|verification-owner)\s+\S.*$') {
+        $metadataEnd = $index
+        continue
+      }
+      break
+    }
+
+    $bodyStart = -1
+    for ($index = $metadataEnd + 1; $index -le $candidateEnd; $index++) {
+      if (-not (Test-ArcCommentOnlySourceLine -Line $lines[$index])) { $bodyStart = $index; break }
+    }
+    $end = $metadataEnd
+    if ($bodyStart -ge 0) {
+      $end = $bodyStart
+      if ($lines[$bodyStart] -cnotmatch '^\s*route\s+[A-Za-z][A-Za-z0-9_.:-]*\s*->\s*[A-Za-z][A-Za-z0-9_.:-]*\s*$') {
+        $opened = $false
+        $braceDepth = 0
+        for ($index = $bodyStart; $index -le $candidateEnd; $index++) {
+          $openCount = @([regex]::Matches($lines[$index], '\{')).Count
+          $closeCount = @([regex]::Matches($lines[$index], '\}')).Count
+          if ($openCount -gt 0) { $opened = $true }
+          $braceDepth += $openCount - $closeCount
+          if ($opened) {
+            $end = $index
+            if ($braceDepth -le 0) { break }
+          }
+        }
+        if (-not $opened -and $lines[$bodyStart].TrimEnd().EndsWith(':')) {
+          $baseIndent = $lines[$bodyStart].Length - $lines[$bodyStart].TrimStart().Length
+          for ($index = $bodyStart + 1; $index -le $candidateEnd; $index++) {
+            if (Test-ArcCommentOnlySourceLine -Line $lines[$index]) { $end = $index; continue }
+            $indent = $lines[$index].Length - $lines[$index].TrimStart().Length
+            if ($indent -le $baseIndent) { break }
+            $end = $index
+          }
+        }
+      }
+    }
+    $blocks.Add([pscustomobject]@{
+      Id = ([regex]::Match($lines[$start], 'RESP-[A-Z0-9]+(?:-[A-Z0-9]+)*')).Value
+      Start = $start
+      End = $end
+      Text = @($lines[$start..$end]) -join "`n"
+      Lines = @($lines[$start..$end])
+    })
+  }
+  return $blocks.ToArray()
+}
+
 function Get-ArcPinnedSourceInventory {
   [CmdletBinding()]
   param(
     [Parameter(Mandatory)][string]$SourceRoot,
     [Parameter(Mandatory)][string]$TaskBaseSha,
     [Parameter(Mandatory)][string]$FinalTreeSha,
     [string[]]$SelectedPaths = @(),
     [Parameter(Mandatory)][AllowEmptyCollection()][Collections.Generic.List[string]]$Errors
   )
 
@@ -1534,21 +1674,31 @@ function Get-ArcPinnedSourceInventory {
   }
   $canonicalSelectedPaths = [Collections.Generic.List[string]]::new()
   foreach ($selectedPath in $SelectedPaths) {
     $canonicalSelectedPath = ConvertTo-ArcCanonicalRepositoryPath -Path ([string]$selectedPath).Trim()
     if ($canonicalSelectedPath -ceq '') { $Errors.Add('responsibility-evidence-missing') }
     else { $canonicalSelectedPaths.Add($canonicalSelectedPath) }
   }
   if ($Errors.Count -ne 0) { return @() }
   $SelectedPaths = @($canonicalSelectedPaths)
   try {
-    if ((Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('rev-parse', "$TaskBaseSha^{commit}")) -cne $TaskBaseSha -or (Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('rev-parse', "$FinalTreeSha^{commit}")) -cne $FinalTreeSha) {
+    $resolvedSourceRoot = [IO.Path]::GetFullPath($SourceRoot)
+    $resolvedGitRoot = [IO.Path]::GetFullPath((Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('rev-parse', '--show-toplevel')))
+    $currentHead = Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('rev-parse', 'HEAD')
+    $checkoutStatus = Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('status', '--porcelain=v1', '--untracked-files=all')
+    if (
+      -not [string]::Equals($resolvedSourceRoot, $resolvedGitRoot, [StringComparison]::OrdinalIgnoreCase) -or
+      $currentHead -cne $FinalTreeSha -or
+      -not [string]::IsNullOrWhiteSpace($checkoutStatus) -or
+      (Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('rev-parse', "$TaskBaseSha^{commit}")) -cne $TaskBaseSha -or
+      (Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('rev-parse', "$FinalTreeSha^{commit}")) -cne $FinalTreeSha
+    ) {
       $Errors.Add('responsibility-evidence-missing')
       return @()
     }
     $nameStatusLines = @((Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('diff', '--name-status', '--find-renames', '--find-copies-harder', '--diff-filter=ACMRD', $TaskBaseSha, $FinalTreeSha, '--')) -split '\r?\n' | Where-Object { $_ -ne '' })
     $finalTreePaths = @((Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('ls-tree', '-r', '--name-only', $FinalTreeSha)) -split '\r?\n' | Where-Object { $_ -ne '' } | ForEach-Object { ConvertTo-ArcCanonicalRepositoryPath -Path $_ })
   }
   catch {
     $Errors.Add('responsibility-evidence-missing')
     return @()
   }
@@ -1621,22 +1771,34 @@ function Get-ArcPinnedSourceInventory {
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
+    $sourceLines = @($sourceText -split '\r?\n')
+    $responsibilityBlocks = @(Get-ArcResponsibilitySourceBlocks -SourceText $sourceText)
+    $coveredLineIndexes = [Collections.Generic.HashSet[int]]::new()
+    foreach ($block in $responsibilityBlocks) {
+      for ($coveredIndex = $block.Start; $coveredIndex -le $block.End; $coveredIndex++) { [void]$coveredLineIndexes.Add($coveredIndex) }
+    }
+    for ($lineIndex = 0; $lineIndex -lt $sourceLines.Count; $lineIndex++) {
+      if (-not $coveredLineIndexes.Contains($lineIndex) -and -not (Test-ArcCommentOnlySourceLine -Line $sourceLines[$lineIndex])) {
+        $Errors.Add('responsibility-evidence-missing')
+      }
+    }
+
     $current = $null
-    foreach ($line in @($sourceText -split '\r?\n')) {
+    foreach ($line in $sourceLines) {
       $ownerMatch = [regex]::Match($line, '^\s*@responsibility\s+(?<id>RESP-[A-Z0-9]+(?:-[A-Z0-9]+)*)\s*$')
       if ($ownerMatch.Success) {
         if ($null -ne $current) { $inventory.Add($current) }
         $current = [pscustomobject]@{
           Id = $ownerMatch.Groups['id'].Value
           Path = $path
           BasePath = if ($null -ne $pathRecord) { [string]$pathRecord.BasePath } else { $path }
           FinalPath = $path
           RenameMapping = if ($null -ne $pathRecord) { [string]$pathRecord.RenameMapping } else { '' }
           IsChanged = ($null -ne $pathRecord)
@@ -1674,30 +1836,30 @@ function Get-ArcPinnedSourceInventory {
         if (-not $current.Effects.Contains('route registration')) { $current.Effects.Add('route registration') }
       }
     }
     if ($null -ne $current) { $inventory.Add($current) }
     $allRouteCount = @([regex]::Matches($sourceText, '(?m)^\s*route\s+[A-Za-z][A-Za-z0-9_.:-]*\s*->\s*[A-Za-z][A-Za-z0-9_.:-]*\s*$')).Count
     $ownedRouteCount = @($inventory | Where-Object { $_.Path -ceq $path } | ForEach-Object { $_.RouteSymbols.Count } | Measure-Object -Sum).Sum
     if ($null -eq $ownedRouteCount) { $ownedRouteCount = 0 }
     if ($allRouteCount -ne $ownedRouteCount) { $Errors.Add('responsibility-evidence-missing') }
     foreach ($owner in @($inventory | Where-Object { $_.Path -ceq $path })) {
       if ($null -ne $pathRecord -and $pathRecord.Status -cin @('M', 'R') -and $baseSourceText -ne '') {
-        $ownerPattern = '(?ms)^\s*@responsibility\s+' + [regex]::Escape($owner.Id) + '\s*$.*?(?=^\s*@responsibility\s+|\z)'
-        $baseOwnerBlock = [regex]::Match($baseSourceText, $ownerPattern)
-        $finalOwnerBlock = [regex]::Match($sourceText, $ownerPattern)
-        $owner.IsChanged = -not ($baseOwnerBlock.Success -and $finalOwnerBlock.Success -and $baseOwnerBlock.Value.Trim() -ceq $finalOwnerBlock.Value.Trim())
+        $baseOwnerBlocks = @(Get-ArcResponsibilitySourceBlocks -SourceText $baseSourceText | Where-Object { $_.Id -ceq $owner.Id })
+        $finalOwnerBlocks = @($responsibilityBlocks | Where-Object { $_.Id -ceq $owner.Id })
+        $owner.IsChanged = -not (
+          $baseOwnerBlocks.Count -eq 1 -and
+          $finalOwnerBlocks.Count -eq 1 -and
+          $baseOwnerBlocks[0].Text.Trim() -ceq $finalOwnerBlocks[0].Text.Trim()
+        )
       }
       $requiresRouteEvidence = $owner.Effects -ccontains 'route registration'
-      $addedDiff = @($diffText -split '\r?\n' | Where-Object { $_ -cmatch '^\+' -and $_ -cnotmatch '^\+\+\+' }) -join "`n"
-      $ownerAnchors = @($owner.OwnerSymbols + $owner.Symbols + $owner.Capabilities + $owner.VerificationOwners + $owner.RouteSymbols + $owner.Providers | Select-Object -Unique)
-      $hasChangedOwnerAnchor = @($ownerAnchors | Where-Object { $addedDiff.IndexOf($_, [StringComparison]::Ordinal) -ge 0 }).Count -gt 0
-      if ($owner.OwnerSymbols.Count -eq 0 -or $owner.Symbols.Count -eq 0 -or $owner.Capabilities.Count -eq 0 -or $owner.ArchitectureAuthorities.Count -eq 0 -or $owner.CoLocationPolicies.Count -eq 0 -or $owner.VerificationOwners.Count -eq 0 -or ($owner.IsChanged -and -not $hasChangedOwnerAnchor) -or ($requiresRouteEvidence -and ($owner.RouteSymbols.Count -eq 0 -or $owner.Providers.Count -eq 0 -or @($owner.Symbols | Where-Object { $owner.RouteSymbols -cnotcontains $_ }).Count -gt 0))) {
+      if ($owner.OwnerSymbols.Count -eq 0 -or $owner.Symbols.Count -eq 0 -or $owner.Capabilities.Count -eq 0 -or $owner.ArchitectureAuthorities.Count -eq 0 -or $owner.CoLocationPolicies.Count -eq 0 -or $owner.VerificationOwners.Count -eq 0 -or ($requiresRouteEvidence -and ($owner.RouteSymbols.Count -eq 0 -or $owner.Providers.Count -eq 0 -or @($owner.Symbols | Where-Object { $owner.RouteSymbols -cnotcontains $_ }).Count -gt 0))) {
         $Errors.Add('responsibility-evidence-missing')
       }
     }
   }
 
   # A responsibility block removed from an M/R production file is deletion,
   # even though the file itself survives. Compare immutable pinned contents and
   # feed only the removed owners through the same deletion reconciliation used
   # for a whole-file D change.
   foreach ($record in @($changedPathRecords | Where-Object { $_.Status -cin @('M', 'R') -and ($_.IsProduction -or $SelectedPaths -ccontains $_.FinalPath) -and $_.BasePath -ne '' -and $_.FinalPath -ne '' })) {
@@ -1856,20 +2018,21 @@ function Test-ResponsibilityReview {
   $errors = [Collections.Generic.List[string]]::new()
   foreach ($error in @(Test-ArcResponsibilityStageVersion $ContractText 'REVIEW')) { $errors.Add($error) }
   if ([string]::IsNullOrWhiteSpace($DesignText) -or [string]::IsNullOrWhiteSpace($ImplementationText) -or [string]::IsNullOrWhiteSpace($ReviewText)) {
     $errors.Add('responsibility-owner-missing')
     return @($errors | Select-Object -Unique)
   }
   if (@(Test-ArcDiscoveryResponsibilityContractVersion -DiscoveryText $DesignText).Count -ne 0 -or @(Test-ArcDiscoveryResponsibilityContractVersion -DiscoveryText $ImplementationText).Count -ne 0 -or @(Test-ArcDiscoveryResponsibilityContractVersion -DiscoveryText $ReviewText).Count -ne 0) {
     $errors.Add('responsibility-contract-version-invalid')
     return @($errors | Select-Object -Unique)
   }
+  $visibleReviewText = Get-ArcVisibleMarkdownText -Text $ReviewText
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
@@ -1924,21 +2087,21 @@ function Test-ResponsibilityReview {
   for ($index = 0; $index -lt $selectorColumns.Count; $index++) { $planSelector[$selectorColumns[$index]] = [string]$planSelectorRows[0][$index] }
   foreach ($field in $selectorColumns) {
     if ($implementationSelector[$field] -cne $planSelector[$field]) { $errors.Add('responsibility-evidence-missing') }
   }
   $planWorkItem = [ordered]@{}
   for ($index = 0; $index -lt $workItemColumns.Count; $index++) { $planWorkItem[$workItemColumns[$index]] = [string]$planWorkItemRows[0][$index] }
   $expectedDeliveryAdapter = if ($planSelector['Adapter Kind'] -ceq 'none') { 'none' } else { "$($planSelector['Adapter Kind']):$($planSelector['External ID'])" }
   if ($planWorkItem['Acceptance'] -cne $planSelector['Acceptance'] -or $planWorkItem['Trace IDs'] -cne $planSelector['Trace IDs'] -or ($planWorkItem['Delivery Adapter'] -cne $expectedDeliveryAdapter -and -not ($planSelector['Adapter Kind'] -ceq 'none' -and $planWorkItem['Delivery Adapter'] -cmatch '^generic:[A-Za-z0-9][A-Za-z0-9._-]*$'))) {
     $errors.Add('responsibility-evidence-missing')
   }
-  $reviewAdapterMatches = @([regex]::Matches($ReviewText, '(?im)^[ \t]*-[ \t]*Delivery Adapter Kind:[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$'))
+  $reviewAdapterMatches = @([regex]::Matches($visibleReviewText, '(?im)^[ \t]*-[ \t]*Delivery Adapter Kind:[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$'))
   if ($reviewAdapterMatches.Count -ne 1 -or $reviewAdapterMatches[0].Groups['value'].Value.Trim() -cne $planSelector['Adapter Kind']) { $errors.Add('responsibility-evidence-missing') }
   $reviewProvenance = & $rowFromTable $reviewProvenanceTable $provenanceColumns
   $expectedTaskUnit = if ($planSelector['Adapter Kind'] -ceq 'migration-unit') { $planSelector['External ID'] } else { $reviewScope['Work Item ID'] }
   if ($reviewProvenance['Task / Unit'] -cne $expectedTaskUnit -or $reviewProvenance['Task-base SHA'] -cne $TaskBaseSha -or $reviewProvenance['Final-tree SHA'] -cne $FinalTreeSha -or $reviewProvenance['Task-base SHA'] -cnotmatch '^[0-9a-f]{40}$' -or $reviewProvenance['Final-tree SHA'] -cnotmatch '^[0-9a-f]{40}$' -or $reviewProvenance['Source Artifact'] -cne 'implementation-report.md') {
     $errors.Add('responsibility-evidence-missing')
   }
   if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }
   $implementationProvenanceEnvelope = Get-ArcImplementationReviewProvenance -ImplementationText $ImplementationText -Errors $errors
   if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }
   if ($null -eq $implementationProvenanceEnvelope -or $implementationProvenanceEnvelope.TaskUnit -cne $expectedTaskUnit -or $implementationProvenanceEnvelope.TaskBaseSha -cne $TaskBaseSha -or $implementationProvenanceEnvelope.FinalTreeSha -cne $FinalTreeSha) {
@@ -2236,23 +2399,22 @@ function Test-ResponsibilityReview {
   $implementationVerificationById = & $toMap $implementationVerifications 'Verification Owner ID' 'verification-owner-extra'
   foreach ($id in $plannedVerificationById.Keys) {
     if (-not $implementationVerificationById.ContainsKey($id)) { $errors.Add('verification-owner-missing'); $verificationPass = $false; continue }
     $planned = $plannedVerificationById[$id]; $implementation = $implementationVerificationById[$id]
     foreach ($field in $verificationColumns) { if ($planned[$field] -cne $implementation[$field]) { $errors.Add('verification-production-binding-missing'); $verificationPass = $false; break } }
     if ($validVerdicts -cnotcontains $implementation['Verdict'] -or $implementation['Verdict'] -cne 'PASS') { $errors.Add('verification-disposition-invalid'); $verificationPass = $false }
     if (-not (Test-ArcPinnedVerificationOwnershipEvidence -VerificationRow $planned -SourceRoot $SourceRoot -FinalTreeSha $FinalTreeSha -ProductionOwnersById $inventoryById -Errors $errors)) { $verificationPass = $false }
   }
   foreach ($id in $implementationVerificationById.Keys) { if (-not $plannedVerificationById.ContainsKey($id)) { $errors.Add('verification-owner-extra'); $verificationPass = $false } }
 
-  $getVerdict = { param([string]$Label) $matches = [regex]::Matches($ReviewText, '(?im)^[ \t]*-[ \t]*(?:\*\*)?' + [regex]::Escape($Label) + '(?:\*\*)?:[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$'); if ($matches.Count -ne 1) { $errors.Add('responsibility-owner-missing'); return '' }; $value = $matches[0].Groups['value'].Value.Trim().Trim([char[]]@('<', '>', '`')); if ($validVerdicts -cnotcontains $value) { $errors.Add('responsibility-owner-extra'); return '' }; return $value }
+  $getVerdict = { param([string]$Label) $matches = [regex]::Matches($visibleReviewText, '(?im)^[ \t]*-[ \t]*(?:\*\*)?' + [regex]::Escape($Label) + '(?:\*\*)?:[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$'); if ($matches.Count -ne 1) { $errors.Add('responsibility-owner-missing'); return '' }; $value = $matches[0].Groups['value'].Value.Trim().Trim([char[]]@('<', '>', '`')); if ($validVerdicts -cnotcontains $value) { $errors.Add('responsibility-owner-extra'); return '' }; return $value }
   $architectureVerdict = & $getVerdict 'Architecture Conformance Verdict'; $treeVerdict = & $getVerdict 'Tree Conformance Verdict'; $responsibilityVerdict = & $getVerdict 'Responsibility Conformance Verdict'; $verificationVerdict = & $getVerdict 'Verification Ownership Verdict'
-  $visibleReviewText = Get-ArcVisibleMarkdownText -Text $ReviewText
   $overallMatches = [regex]::Matches($visibleReviewText, '(?im)^[ \t]*-[ \t]*(?:\*\*)?Verdict(?:\*\*)?:[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$')
   $overallVerdict = if ($overallMatches.Count -eq 1) { $overallMatches[0].Groups['value'].Value.Trim().Trim([char[]]@('<', '>', '`')) } else { $errors.Add('responsibility-owner-missing'); '' }
   $criticalCountMatches = @([regex]::Matches($visibleReviewText, '(?im)^[ \t]*-[ \t]*(?:\*\*)?Critical count:(?:\*\*)?[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$'))
   $criticalCount = if ($criticalCountMatches.Count -eq 1 -and $criticalCountMatches[0].Groups['value'].Value.Trim() -cmatch '^[0-9]+$') { [int]$criticalCountMatches[0].Groups['value'].Value.Trim() } else { $errors.Add('responsibility-evidence-missing'); -1 }
   $derivedTree = if ($treePass) { 'PASS' } else { 'BLOCKED' }; $derivedResponsibility = if ($responsibilityPass) { 'PASS' } else { 'BLOCKED' }; $derivedVerification = if ($verificationPass) { 'PASS' } else { 'BLOCKED' }
   if ($treeVerdict -ne '' -and $treeVerdict -cne $derivedTree) { $errors.Add('responsibility-waiver-forbidden') }
   if ($responsibilityVerdict -ne '' -and $responsibilityVerdict -cne $derivedResponsibility) { $errors.Add('responsibility-waiver-forbidden') }
   if ($verificationVerdict -ne '' -and $verificationVerdict -cne $derivedVerification) { $errors.Add('responsibility-waiver-forbidden') }
   $derivedArchitecture = if ($treeVerdict -ceq 'PASS' -and $responsibilityVerdict -ceq 'PASS' -and $verificationVerdict -ceq 'PASS') { 'PASS' } else { 'BLOCKED' }
   if ($architectureVerdict -ne '' -and $architectureVerdict -cne $derivedArchitecture) { $errors.Add('responsibility-waiver-forbidden') }
@@ -2461,27 +2623,32 @@ function Test-ResponsibilityHandoff {
   if (-not [string]::IsNullOrWhiteSpace($ApprovedPlanText)) {
     $planSelections = @(Get-ArcStrictMarkdownTable -Text $ApprovedPlanText -Heading 'Delivery Adapter Selection' -Columns $planSelectionColumns -Errors $errors)
   }
   $workItemColumns = @('Work Item ID', 'Title', 'Required', 'Dependencies', 'Plan Order', 'Acceptance', 'Trace IDs', 'Delivery Adapter', 'Status', 'Latest Attempt', 'Terminal Evidence', 'Approval Reference')
   [object[]]$workItemTable = @()
   if (-not [string]::IsNullOrWhiteSpace($ApprovedPlanText)) {
     $workItemTable = @(Get-ArcStrictMarkdownTable -Text $ApprovedPlanText -Heading 'Work Items' -Columns $workItemColumns -Errors $errors)
   }
   if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }
   $planIdMatches = @([regex]::Matches($planFrontMatter, '(?m)^master_plan_id:\s*(?<value>PLAN-[A-Z0-9]+(?:-[A-Z0-9]+)*)\s*$'))
+  $planSpecIdMatches = @([regex]::Matches($planFrontMatter, '(?m)^master_spec_id:\s*(?<value>SPEC-[A-Z0-9]+(?:-[A-Z0-9]+)*)\s*$'))
+  $planSpecRevisionMatches = @([regex]::Matches($planFrontMatter, '(?m)^master_spec_revision:\s*(?<value>[1-9][0-9]*)\s*$'))
   $planRevisionMatches = @([regex]::Matches($planFrontMatter, '(?m)^revision:\s*(?<value>[1-9][0-9]*)\s*$'))
   $approvedModeConstraint = ''
   if (
     @([regex]::Matches($planFrontMatter, '(?m)^artifact_type:\s*migration-master-plan\s*$')).Count -ne 1 -or
     @([regex]::Matches($planFrontMatter, '(?m)^status:\s*approved\s*$')).Count -ne 1 -or
-    $planIdMatches.Count -ne 1 -or $planRevisionMatches.Count -ne 1 -or $planSelections.Count -lt 3 -or $workItemTable.Count -lt 3 -or
+    $planIdMatches.Count -ne 1 -or $planSpecIdMatches.Count -ne 1 -or $planSpecRevisionMatches.Count -ne 1 -or $planRevisionMatches.Count -ne 1 -or
+    $planSelections.Count -lt 3 -or $workItemTable.Count -lt 3 -or
     $planIdMatches[0].Groups['value'].Value -cne $source.Scope['Master Plan ID'] -or
+    $planSpecIdMatches[0].Groups['value'].Value -cne $source.Scope['Master Spec ID'] -or
+    $planSpecRevisionMatches[0].Groups['value'].Value -cne $source.Scope['Master Spec Revision'] -or
     $planRevisionMatches[0].Groups['value'].Value -cne $source.Scope['Master Plan Revision']
   ) {
     $errors.Add('responsibility-evidence-missing')
   }
   else {
     $allSelectionRows = @($planSelections | Select-Object -Skip 2)
     $allWorkItemRows = @($workItemTable | Select-Object -Skip 2)
     $selectionWorkItemIds = @($allSelectionRows | ForEach-Object { [string]$_[0] })
     $planWorkItemIds = @($allWorkItemRows | ForEach-Object { [string]$_[0] })
     $selectionWorkItemSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/scope-engine.validation.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/scope-engine.validation.ps1
index 200a1f0..3edc0c8 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/scope-engine.validation.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/scope-engine.validation.ps1
@@ -9,20 +9,21 @@ function Test-ScopeEngine([string]$Root, [string]$ContractText) {
   if ($candidateText.StartsWith('{', [StringComparison]::Ordinal)) {
     try {
       $scenario = $ContractText | ConvertFrom-Json
     }
     catch {
       return [pscustomobject]@{ result = 'scenario-invalid'; reason = 'invalid-json' }
     }
     if ($scenario.scenario_type -cne 'scope-engine') {
       return [pscustomobject]@{ result = 'scenario-invalid'; reason = 'invalid-scenario-type' }
     }
+    $isExactJsonTrue = { param([object]$Value) $Value -is [bool] -and $Value -eq $true }
 
     if ($scenario.operation -ceq 'resolve-scope') {
       $scope = $scenario.requested_scope
       $allowedKinds = @('project', 'module', 'feature', 'task', 'explicit-item', 'unresolved')
       if (
         $null -eq $scope -or
         $allowedKinds -cnotcontains [string]$scope.kind -or
         [string]::IsNullOrWhiteSpace([string]$scope.id) -or
         [string]::IsNullOrWhiteSpace([string]$scope.statement) -or
         [string]::IsNullOrWhiteSpace([string]$scope.source) -or
@@ -95,21 +96,21 @@ function Test-ScopeEngine([string]$Root, [string]$ContractText) {
       }
 
       $currentSpecs = @($context.spec_revisions | Where-Object {
         [string]$_.artifact_reference -ceq [string]$context.master_spec_ref -and
         [string]$_.artifact_id -ceq [string]$context.master_spec_id -and
         [int]$_.revision -eq [int]$context.latest_spec_revision
       })
       if (
         $currentSpecs.Count -ne 1 -or
         $currentSpecs[0].artifact_type -cne 'migration-master-spec' -or
-        -not [bool]$currentSpecs[0].immutable
+        -not (& $isExactJsonTrue $currentSpecs[0].immutable)
       ) {
         return [pscustomobject]@{ result = 'orchestration-blocked'; reason = 'master-spec-artifact-resolution-invalid'; gate = 'master-spec' }
       }
       if (
         $currentSpecs[0].status -cne 'approved' -or
         $currentSpecs[0].result -cne 'complete'
       ) {
         return [pscustomobject]@{ result = 'orchestration-blocked'; reason = 'approved-master-spec-revision-missing'; gate = 'master-spec' }
       }
       if (
@@ -122,21 +123,21 @@ function Test-ScopeEngine([string]$Root, [string]$ContractText) {
       }
 
       $currentPlans = @($context.plan_revisions | Where-Object {
         [string]$_.artifact_reference -ceq [string]$context.master_plan_ref -and
         [string]$_.artifact_id -ceq [string]$context.master_plan_id -and
         [int]$_.revision -eq [int]$context.current_plan_revision
       })
       if (
         $currentPlans.Count -ne 1 -or
         $currentPlans[0].artifact_type -cne 'migration-master-plan' -or
-        -not [bool]$currentPlans[0].immutable
+        -not (& $isExactJsonTrue $currentPlans[0].immutable)
       ) {
         return [pscustomobject]@{ result = 'orchestration-blocked'; reason = 'master-plan-artifact-resolution-invalid'; gate = 'master-plan' }
       }
       if (
         $currentPlans[0].status -cne 'approved' -or
         $currentPlans[0].result -cne 'complete'
       ) {
         return [pscustomobject]@{ result = 'orchestration-blocked'; reason = 'approved-master-plan-revision-missing'; gate = 'master-plan' }
       }
       if (
@@ -189,21 +190,21 @@ function Test-ScopeEngine([string]$Root, [string]$ContractText) {
       $derivedArchitecture = if (
         $null -ne $authorityHandoff -and
         [string]$authorityHandoff.tree_conformance -ceq 'PASS' -and
         [string]$authorityHandoff.responsibility_conformance -ceq 'PASS' -and
         [string]$authorityHandoff.verification_ownership -ceq 'PASS'
       ) { 'PASS' } else { 'BLOCKED' }
       return (
         -not [string]::IsNullOrWhiteSpace($authorityReference) -and
         $authorityReference -cne 'none' -and
         $null -ne $authority -and
-        [bool]$authority.immutable -and
+        (& $isExactJsonTrue $authority.immutable) -and
         [string]$authority.artifact_type -ceq 'migration-work-item-responsibility-authority' -and
         [string]$authority.status -ceq 'approved' -and
         [string]$authority.result -ceq 'complete' -and
         [string]$authority.approval_source -ceq 'human' -and
         [string]$authority.run_id -ceq [string]$context.run_id -and
         [string]$authority.master_spec_ref -ceq [string]$context.master_spec_ref -and
         [string]$authority.master_spec_id -ceq [string]$context.master_spec_id -and
         [int]$authority.master_spec_revision -eq [int]$context.latest_spec_revision -and
         [string]$authority.master_plan_ref -ceq [string]$context.master_plan_ref -and
         [string]$authority.master_plan_id -ceq [string]$context.master_plan_id -and
@@ -273,48 +274,62 @@ function Test-ScopeEngine([string]$Root, [string]$ContractText) {
 
     $testTerminalResponsibilityAuthority = {
       param([object]$Item, [string]$Reference)
       $terminalArtifacts = @($scenario.orchestration_context.resolved_artifacts | Where-Object {
         [string]$_.artifact_reference -ceq $Reference
       })
       if ($terminalArtifacts.Count -ne 1) { return $false }
       $terminalArtifact = $terminalArtifacts[0]
       if ($null -eq $terminalArtifact.PSObject.Properties['responsibility_handoff']) { return $false }
       $handoff = $terminalArtifact.responsibility_handoff
+      $taskProvenance = if ($null -ne $terminalArtifact.PSObject.Properties['task_provenance']) {
+        $terminalArtifact.task_provenance
+      }
+      else { $null }
+      $expectedTaskEvidence = if ($null -ne $taskProvenance) {
+        "source-diff:$([string]$taskProvenance.task_base_sha)..$([string]$taskProvenance.final_tree_sha)#$([string]$Item.work_item_id)"
+      }
+      else { '' }
       $derivedArchitecture = if (
         [string]$handoff.tree_conformance -ceq 'PASS' -and
         [string]$handoff.responsibility_conformance -ceq 'PASS' -and
         [string]$handoff.verification_ownership -ceq 'PASS'
       ) { 'PASS' } else { 'BLOCKED' }
       $expectedSteps = if ([string]$Item.mode_constraint -ceq 'incremental/preserve-existing') {
         @('11-ai-review', '12-verification-testing', '13-verify-parity', '14-verify-regression', '15-knowledge-base')
       }
       elseif ([string]$Item.mode_constraint -ceq 'greenfield/design-new') {
         @('11-ai-review', '12-verification-testing', '13-verify-parity', '15-knowledge-base')
       }
       else { @() }
       $chainReferences = @($terminalArtifact.responsibility_chain_references)
       if (
         [string]$terminalArtifact.artifact_reference -cne $Reference -or
-        -not [bool]$terminalArtifact.immutable -or
+        -not (& $isExactJsonTrue $terminalArtifact.immutable) -or
         [string]$terminalArtifact.artifact_type -cne 'migration-work-item-terminal' -or
         [string]$terminalArtifact.work_item_id -cne [string]$Item.work_item_id -or
         [int]$terminalArtifact.plan_revision -ne [int]$scenario.current_plan_revision -or
         [string]$terminalArtifact.result -cne 'complete' -or
         [string]$terminalArtifact.run_id -cne [string]$context.run_id -or
         [string]$terminalArtifact.master_spec_ref -cne [string]$context.master_spec_ref -or
         [string]$terminalArtifact.master_spec_id -cne [string]$context.master_spec_id -or
         [int]$terminalArtifact.master_spec_revision -ne [int]$context.latest_spec_revision -or
         [string]$terminalArtifact.master_plan_ref -cne [string]$context.master_plan_ref -or
         [string]$terminalArtifact.master_plan_id -cne [string]$context.master_plan_id -or
         [int]$terminalArtifact.master_plan_revision -ne [int]$context.current_plan_revision -or
         [string]$terminalArtifact.mode_constraint -cne [string]$Item.mode_constraint -or
+        $null -eq $taskProvenance -or
+        [string]$taskProvenance.task_unit -cne [string]$Item.work_item_id -or
+        [string]$taskProvenance.task_base_sha -cnotmatch '^[0-9a-f]{40}$' -or
+        [string]$taskProvenance.final_tree_sha -cnotmatch '^[0-9a-f]{40}$' -or
+        [string]$taskProvenance.source_artifact_reference -cne 'implementation-report.md' -or
+        [string]$taskProvenance.evidence_reference -cne $expectedTaskEvidence -or
         [int]$handoff.responsibility_contract_version -ne 1 -or
         [string]$handoff.tree_conformance -cne 'PASS' -or
         [string]$handoff.responsibility_conformance -cne 'PASS' -or
         [string]$handoff.verification_ownership -cne 'PASS' -or
         [string]$handoff.architecture_state -cne $derivedArchitecture -or
         $derivedArchitecture -cne 'PASS' -or
         $expectedSteps.Count -eq 0 -or
         $chainReferences.Count -ne $expectedSteps.Count -or
         @($chainReferences | Group-Object | Where-Object Count -ne 1).Count -gt 0 -or
         [string]$handoff.evidence_reference -cne [string]$chainReferences[-1] -or
@@ -332,41 +347,45 @@ function Test-ScopeEngine([string]$Root, [string]$ContractText) {
           [string]$_.artifact_reference -ceq $chainReference
         })
         if ($chainArtifacts.Count -ne 1) { return $false }
         $chainArtifact = $chainArtifacts[0]
         $chainArchitecture = if (
           [string]$chainArtifact.tree_conformance -ceq 'PASS' -and
           [string]$chainArtifact.responsibility_conformance -ceq 'PASS' -and
           [string]$chainArtifact.verification_ownership -ceq 'PASS'
         ) { 'PASS' } else { 'BLOCKED' }
         if (
-          -not [bool]$chainArtifact.immutable -or
+          -not (& $isExactJsonTrue $chainArtifact.immutable) -or
           [string]$chainArtifact.artifact_type -cne 'migration-responsibility-handoff' -or
           [string]$chainArtifact.run_id -cne [string]$context.run_id -or
           [string]$chainArtifact.master_spec_ref -cne [string]$context.master_spec_ref -or
           [string]$chainArtifact.master_spec_id -cne [string]$context.master_spec_id -or
           [int]$chainArtifact.master_spec_revision -ne [int]$context.latest_spec_revision -or
           [string]$chainArtifact.master_plan_ref -cne [string]$context.master_plan_ref -or
           [string]$chainArtifact.master_plan_id -cne [string]$context.master_plan_id -or
           [int]$chainArtifact.master_plan_revision -ne [int]$context.current_plan_revision -or
           [string]$chainArtifact.work_item_id -cne [string]$Item.work_item_id -or
           [string]$chainArtifact.mode_constraint -cne [string]$Item.mode_constraint -or
           [string]$chainArtifact.step_id -cne [string]$expectedSteps[$chainIndex] -or
           [int]$chainArtifact.responsibility_contract_version -ne 1 -or
           $chainArchitecture -cne 'PASS' -or
           [string]$chainArtifact.architecture_state -cne $chainArchitecture -or
           [string]$chainArtifact.task_base_sha -cnotmatch '^[0-9a-f]{40}$' -or
           [string]$chainArtifact.final_tree_sha -cnotmatch '^[0-9a-f]{40}$' -or
           [string]$chainArtifact.evidence_reference -cne ("source-diff:$([string]$chainArtifact.task_base_sha)..$([string]$chainArtifact.final_tree_sha)#$([string]$Item.work_item_id)") -or
+          [string]$chainArtifact.task_base_sha -cne [string]$taskProvenance.task_base_sha -or
+          [string]$chainArtifact.final_tree_sha -cne [string]$taskProvenance.final_tree_sha -or
+          [string]$chainArtifact.evidence_reference -cne [string]$taskProvenance.evidence_reference -or
           [string]$chainArtifact.status -cne 'approved' -or
           [string]$chainArtifact.result -cne 'complete' -or
           [string]$chainArtifact.approval_source -cne 'human' -or
+          ($chainIndex -eq 0 -and [string]$chainArtifact.source_artifact_reference -cne [string]$taskProvenance.source_artifact_reference) -or
           ($chainIndex -gt 0 -and [string]$chainArtifact.source_artifact_reference -cne $previousReference) -or
           ($chainIndex -gt 0 -and [string]$chainArtifact.evidence_reference -cne $canonicalSourceDiff)
         ) { return $false }
         foreach ($field in @('tree_conformance', 'responsibility_conformance', 'verification_ownership', 'architecture_state')) {
           if ([string]$chainArtifact.$field -cne [string]$handoff.$field) { return $false }
         }
         if ($chainIndex -eq 0) { $canonicalSourceDiff = [string]$chainArtifact.evidence_reference }
         $previousReference = $chainReference
       }
       return $true
@@ -446,21 +465,21 @@ function Test-ScopeEngine([string]$Root, [string]$ContractText) {
             @('in-progress', 'complete', 'blocked') -cnotcontains [string]$attempt.status -or
             [string]::IsNullOrWhiteSpace([string]$attempt.artifact_reference)
           ) {
             return [pscustomobject]@{ result = 'plan-invalid'; reason = 'attempt-record-invalid'; scope_status = 'scope-blocked' }
           }
           $resolvedAttemptArtifacts = @($scenario.orchestration_context.resolved_artifacts | Where-Object {
             [string]$_.artifact_reference -ceq [string]$attempt.artifact_reference
           })
           if (
             $resolvedAttemptArtifacts.Count -ne 1 -or
-            -not [bool]$resolvedAttemptArtifacts[0].immutable -or
+            -not (& $isExactJsonTrue $resolvedAttemptArtifacts[0].immutable) -or
             [string]$resolvedAttemptArtifacts[0].attempt_id -cne [string]$attempt.attempt_id -or
             [string]$resolvedAttemptArtifacts[0].work_item_id -cne [string]$attempt.work_item_id -or
             [int]$resolvedAttemptArtifacts[0].plan_revision -ne [int]$attempt.plan_revision -or
             [string]$resolvedAttemptArtifacts[0].status -cne [string]$attempt.status
           ) {
             return [pscustomobject]@{ result = 'plan-invalid'; reason = 'attempt-artifact-binding-invalid'; scope_status = 'scope-blocked' }
           }
           if ($attempt.status -ceq 'in-progress') {
             $activeAttemptCount++
             $activeAttemptRecord = $attempt
@@ -739,21 +758,21 @@ function Test-ScopeEngine([string]$Root, [string]$ContractText) {
         return [pscustomobject]@{ result = 'scope-not-complete'; reason = 'required-work-remains'; scope_status = 'scope-in-progress' }
       }
       $terminalReportRef = [string]$scenario.terminal_scope_report_ref
       $terminalReports = @($scenario.orchestration_context.resolved_artifacts | Where-Object {
         [string]$_.artifact_reference -ceq $terminalReportRef
       })
       if (
         @('', 'pending', 'none', 'not-applicable') -ccontains $terminalReportRef -or
         $terminalReports.Count -ne 1 -or
         $terminalReports[0].artifact_type -cne 'migration-scope-terminal-report' -or
-        -not [bool]$terminalReports[0].immutable -or
+        -not (& $isExactJsonTrue $terminalReports[0].immutable) -or
         [string]$terminalReports[0].master_plan_ref -cne [string]$scenario.orchestration_context.master_plan_ref -or
         [int]$terminalReports[0].master_plan_revision -ne [int]$scenario.current_plan_revision
       ) {
         return [pscustomobject]@{ result = 'scope-not-complete'; reason = 'terminal-scope-report-resolution-invalid'; scope_status = 'scope-blocked' }
       }
       $terminalReport = $terminalReports[0]
       $reportRows = @($terminalReport.items)
       $planReportIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
       foreach ($item in $items) { [void]$planReportIds.Add([string]$item.work_item_id) }
       $reportedIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
@@ -796,21 +815,21 @@ function Test-ScopeEngine([string]$Root, [string]$ContractText) {
           $diagnostic = [string]$item.responsibility_diagnostic
           $reason = if ($responsibility -cne 'PASS' -and -not [string]::IsNullOrWhiteSpace($diagnostic) -and $diagnostic -cne 'none') { $diagnostic } else { 'structural-assurance-blocked' }
           return [pscustomobject]@{ result = 'scope-not-complete'; reason = $reason; scope_status = 'scope-blocked' }
         }
 
         $terminalArtifacts = @($scenario.orchestration_context.resolved_artifacts | Where-Object {
           [string]$_.artifact_reference -ceq [string]$item.terminal_evidence
         })
         if (
           $terminalArtifacts.Count -ne 1 -or
-          -not [bool]$terminalArtifacts[0].immutable -or
+          -not (& $isExactJsonTrue $terminalArtifacts[0].immutable) -or
           [string]$terminalArtifacts[0].artifact_type -cne 'migration-work-item-terminal' -or
           [string]$terminalArtifacts[0].work_item_id -cne [string]$item.work_item_id -or
           [int]$terminalArtifacts[0].plan_revision -ne [int]$scenario.current_plan_revision -or
           [string]$terminalArtifacts[0].status -cne [string]$item.status -or
           [string]$terminalArtifacts[0].run_id -cne [string]$scenario.orchestration_context.run_id -or
           [string]$terminalArtifacts[0].master_spec_ref -cne [string]$scenario.orchestration_context.master_spec_ref -or
           [string]$terminalArtifacts[0].master_spec_id -cne [string]$scenario.orchestration_context.master_spec_id -or
           [int]$terminalArtifacts[0].master_spec_revision -ne [int]$scenario.orchestration_context.latest_spec_revision -or
           [string]$terminalArtifacts[0].master_plan_ref -cne [string]$scenario.orchestration_context.master_plan_ref -or
           [string]$terminalArtifacts[0].master_plan_id -cne [string]$scenario.orchestration_context.master_plan_id -or
@@ -818,20 +837,28 @@ function Test-ScopeEngine([string]$Root, [string]$ContractText) {
           [string]$terminalArtifacts[0].mode_constraint -cne [string]$item.mode_constraint
         ) {
           return [pscustomobject]@{ result = 'scope-not-complete'; reason = 'structural-assurance-blocked'; scope_status = 'scope-blocked' }
         }
         if (-not (& $testTerminalResponsibilityAuthority $item ([string]$item.terminal_evidence))) {
           return [pscustomobject]@{ result = 'scope-not-complete'; reason = 'structural-assurance-blocked'; scope_status = 'scope-blocked' }
         }
 
         $terminalArtifact = $terminalArtifacts[0]
         $handoff = $terminalArtifact.responsibility_handoff
+        $taskProvenance = if ($null -ne $terminalArtifact.PSObject.Properties['task_provenance']) {
+          $terminalArtifact.task_provenance
+        }
+        else { $null }
+        $expectedTaskEvidence = if ($null -ne $taskProvenance) {
+          "source-diff:$([string]$taskProvenance.task_base_sha)..$([string]$taskProvenance.final_tree_sha)#$([string]$item.work_item_id)"
+        }
+        else { '' }
         $derivedArchitecture = if (
           [string]$handoff.tree_conformance -ceq 'PASS' -and
           [string]$handoff.responsibility_conformance -ceq 'PASS' -and
           [string]$handoff.verification_ownership -ceq 'PASS'
         ) { 'PASS' } else { 'BLOCKED' }
         $modeConstraint = [string]$item.mode_constraint
         $expectedResponsibilitySteps = if ($modeConstraint -ceq 'incremental/preserve-existing') {
           @('11-ai-review', '12-verification-testing', '13-verify-parity', '14-verify-regression', '15-knowledge-base')
         }
         elseif ($modeConstraint -ceq 'greenfield/design-new') {
@@ -840,20 +867,26 @@ function Test-ScopeEngine([string]$Root, [string]$ContractText) {
         else { @() }
         $responsibilityChainReferences = @($terminalArtifact.responsibility_chain_references)
         if (
           $null -eq $handoff -or
           [int]$handoff.responsibility_contract_version -ne 1 -or
           [string]$handoff.tree_conformance -cne 'PASS' -or
           [string]$handoff.responsibility_conformance -cne 'PASS' -or
           [string]$handoff.verification_ownership -cne 'PASS' -or
           [string]$handoff.architecture_state -cne $derivedArchitecture -or
           $derivedArchitecture -cne 'PASS' -or
+          $null -eq $taskProvenance -or
+          [string]$taskProvenance.task_unit -cne [string]$item.work_item_id -or
+          [string]$taskProvenance.task_base_sha -cnotmatch '^[0-9a-f]{40}$' -or
+          [string]$taskProvenance.final_tree_sha -cnotmatch '^[0-9a-f]{40}$' -or
+          [string]$taskProvenance.source_artifact_reference -cne 'implementation-report.md' -or
+          [string]$taskProvenance.evidence_reference -cne $expectedTaskEvidence -or
           $expectedResponsibilitySteps.Count -eq 0 -or
           $responsibilityChainReferences.Count -ne $expectedResponsibilitySteps.Count -or
           @($responsibilityChainReferences | Group-Object | Where-Object Count -ne 1).Count -gt 0 -or
           [string]$handoff.evidence_reference -cne [string]$responsibilityChainReferences[-1] -or
           $tree -cne [string]$handoff.tree_conformance -or
           $responsibility -cne [string]$handoff.responsibility_conformance -or
           $verification -cne [string]$handoff.verification_ownership -or
           $architectureState -cne [string]$handoff.architecture_state
         ) {
           $diagnostic = [string]$item.responsibility_diagnostic
@@ -872,45 +905,49 @@ function Test-ScopeEngine([string]$Root, [string]$ContractText) {
           if ($chainArtifacts.Count -ne 1) {
             return [pscustomobject]@{ result = 'scope-not-complete'; reason = 'structural-assurance-blocked'; scope_status = 'scope-blocked' }
           }
           $chainArtifact = $chainArtifacts[0]
           $chainArchitecture = if (
             [string]$chainArtifact.tree_conformance -ceq 'PASS' -and
             [string]$chainArtifact.responsibility_conformance -ceq 'PASS' -and
             [string]$chainArtifact.verification_ownership -ceq 'PASS'
           ) { 'PASS' } else { 'BLOCKED' }
           if (
-            -not [bool]$chainArtifact.immutable -or
+            -not (& $isExactJsonTrue $chainArtifact.immutable) -or
             [string]$chainArtifact.artifact_type -cne 'migration-responsibility-handoff' -or
             [string]$chainArtifact.run_id -cne [string]$scenario.orchestration_context.run_id -or
             [string]$chainArtifact.master_spec_ref -cne [string]$scenario.orchestration_context.master_spec_ref -or
             [string]$chainArtifact.master_spec_id -cne [string]$scenario.orchestration_context.master_spec_id -or
             [int]$chainArtifact.master_spec_revision -ne [int]$scenario.orchestration_context.latest_spec_revision -or
             [string]$chainArtifact.master_plan_ref -cne [string]$scenario.orchestration_context.master_plan_ref -or
             [string]$chainArtifact.master_plan_id -cne [string]$scenario.orchestration_context.master_plan_id -or
             [int]$chainArtifact.master_plan_revision -ne [int]$scenario.current_plan_revision -or
             [string]$chainArtifact.work_item_id -cne [string]$item.work_item_id -or
             [string]$chainArtifact.mode_constraint -cne $modeConstraint -or
             [string]$chainArtifact.step_id -cne [string]$expectedResponsibilitySteps[$chainIndex] -or
             [int]$chainArtifact.responsibility_contract_version -ne 1 -or
             $chainArchitecture -cne 'PASS' -or
             [string]$chainArtifact.architecture_state -cne $chainArchitecture -or
             [string]::IsNullOrWhiteSpace([string]$chainArtifact.evidence_reference) -or
             [string]$chainArtifact.evidence_reference -ceq 'none' -or
             [string]$chainArtifact.task_base_sha -cnotmatch '^[0-9a-f]{40}$' -or
             [string]$chainArtifact.final_tree_sha -cnotmatch '^[0-9a-f]{40}$' -or
             [string]$chainArtifact.evidence_reference -cne ("source-diff:$([string]$chainArtifact.task_base_sha)..$([string]$chainArtifact.final_tree_sha)#$([string]$item.work_item_id)") -or
+            [string]$chainArtifact.task_base_sha -cne [string]$taskProvenance.task_base_sha -or
+            [string]$chainArtifact.final_tree_sha -cne [string]$taskProvenance.final_tree_sha -or
+            [string]$chainArtifact.evidence_reference -cne [string]$taskProvenance.evidence_reference -or
             (
               [string]$chainArtifact.status -cne 'approved' -or
               [string]$chainArtifact.result -cne 'complete' -or
               [string]$chainArtifact.approval_source -cne 'human'
             ) -or
+            ($chainIndex -eq 0 -and [string]$chainArtifact.source_artifact_reference -cne [string]$taskProvenance.source_artifact_reference) -or
             ($chainIndex -gt 0 -and [string]$chainArtifact.source_artifact_reference -cne $previousResponsibilityReference) -or
             ($chainIndex -gt 0 -and [string]$chainArtifact.evidence_reference -cne $canonicalSourceDiff)
           ) {
             return [pscustomobject]@{ result = 'scope-not-complete'; reason = 'structural-assurance-blocked'; scope_status = 'scope-blocked' }
           }
           foreach ($field in @('tree_conformance', 'responsibility_conformance', 'verification_ownership', 'architecture_state')) {
             if ([string]$chainArtifact.$field -cne [string]$handoff.$field) {
               return [pscustomobject]@{ result = 'scope-not-complete'; reason = 'structural-assurance-blocked'; scope_status = 'scope-blocked' }
             }
           }
@@ -1020,21 +1057,21 @@ function Test-ScopeEngine([string]$Root, [string]$ContractText) {
             @('in-progress', 'complete', 'blocked') -cnotcontains [string]$attempt.status -or
             [string]::IsNullOrWhiteSpace([string]$attempt.artifact_reference)
           ) {
             return [pscustomobject]@{ result = 'transition-invalid'; reason = 'attempt-record-invalid' }
           }
           $resolvedAttemptArtifacts = @($scenario.orchestration_context.resolved_artifacts | Where-Object {
             [string]$_.artifact_reference -ceq [string]$attempt.artifact_reference
           })
           if (
             $resolvedAttemptArtifacts.Count -ne 1 -or
-            -not [bool]$resolvedAttemptArtifacts[0].immutable -or
+            -not (& $isExactJsonTrue $resolvedAttemptArtifacts[0].immutable) -or
             [string]$resolvedAttemptArtifacts[0].attempt_id -cne [string]$attempt.attempt_id -or
             [string]$resolvedAttemptArtifacts[0].work_item_id -cne [string]$attempt.work_item_id -or
             [int]$resolvedAttemptArtifacts[0].plan_revision -ne [int]$attempt.plan_revision -or
             [string]$resolvedAttemptArtifacts[0].status -cne [string]$attempt.status
           ) {
             return [pscustomobject]@{ result = 'transition-invalid'; reason = 'attempt-artifact-binding-invalid' }
           }
           if ($attempt.status -ceq 'in-progress') { $activeAttemptCount++ }
           $attemptById.Add($historyAttemptId, $attempt)
         }
@@ -1097,21 +1134,21 @@ function Test-ScopeEngine([string]$Root, [string]$ContractText) {
         })
         $terminalArtifact = if ($terminalArtifacts.Count -eq 1) { $terminalArtifacts[0] } else { $null }
         if (
           $null -eq $terminalArtifact -or
           [string]$terminalArtifact.artifact_reference -cne [string]$scenario.terminal_evidence -or
           [string]$terminalArtifact.attempt_id -cne [string]$scenario.attempt_id -or
           [string]$terminalArtifact.work_item_id -cne [string]$item.work_item_id -or
           [int]$terminalArtifact.plan_revision -ne [int]$scenario.current_plan_revision -or
           [string]$terminalArtifact.status -cne 'complete' -or
           [string]$terminalArtifact.result -cne 'complete' -or
-          -not [bool]$terminalArtifact.immutable
+          -not (& $isExactJsonTrue $terminalArtifact.immutable)
         ) {
           return [pscustomobject]@{ result = 'transition-invalid'; reason = 'terminal-artifact-binding-invalid' }
         }
         if (-not (& $testTerminalResponsibilityAuthority $item ([string]$scenario.terminal_evidence))) {
           return [pscustomobject]@{ result = 'transition-invalid'; reason = 'terminal-responsibility-authority-invalid'; scope_status = 'scope-blocked' }
         }
         return [pscustomobject]@{
           result = 'transitioned'
           reason = 'valid-successful-terminal-artifact'
           attempt_id = [string]$scenario.attempt_id
@@ -1145,21 +1182,21 @@ function Test-ScopeEngine([string]$Root, [string]$ContractText) {
           $null -eq $attemptRecord -or
           [string]$attemptRecord.work_item_id -cne [string]$item.work_item_id -or
           [int]$attemptRecord.plan_revision -ne [int]$scenario.current_plan_revision -or
           [string]$attemptRecord.status -cne 'in-progress' -or
           $null -eq $blockerArtifact -or
           [string]$blockerArtifact.artifact_reference -cne [string]$scenario.terminal_evidence -or
           [string]$blockerArtifact.attempt_id -cne [string]$scenario.attempt_id -or
           [string]$blockerArtifact.work_item_id -cne [string]$item.work_item_id -or
           [int]$blockerArtifact.plan_revision -ne [int]$scenario.current_plan_revision -or
           [string]$blockerArtifact.result -cne 'blocked' -or
-          -not [bool]$blockerArtifact.immutable
+          -not (& $isExactJsonTrue $blockerArtifact.immutable)
         ) {
           return [pscustomobject]@{ result = 'transition-invalid'; reason = 'blocker-artifact-binding-invalid' }
         }
         return [pscustomobject]@{
           result = 'transitioned'
           reason = 'native-blocker'
           attempt_id = [string]$scenario.attempt_id
           plan_revision = [int]$scenario.current_plan_revision
           attempt_status = 'blocked'
           work_item_status = 'blocked'
@@ -1183,21 +1220,21 @@ function Test-ScopeEngine([string]$Root, [string]$ContractText) {
           [string]$_.artifact_reference -ceq [string]$scenario.terminal_evidence
         })
         $decisionArtifact = if ($decisionArtifacts.Count -eq 1) { $decisionArtifacts[0] } else { $null }
         if (
           $null -eq $decisionArtifact -or
           [string]$decisionArtifact.artifact_reference -cne [string]$scenario.terminal_evidence -or
           [string]$decisionArtifact.work_item_id -cne [string]$item.work_item_id -or
           [int]$decisionArtifact.plan_revision -ne [int]$scenario.current_plan_revision -or
           [string]$decisionArtifact.decision -cne 'cancelled-approved' -or
           [string]$decisionArtifact.approval_reference -cne [string]$scenario.approval_reference -or
-          -not [bool]$decisionArtifact.immutable
+          -not (& $isExactJsonTrue $decisionArtifact.immutable)
         ) {
           return [pscustomobject]@{ result = 'transition-invalid'; reason = 'decision-artifact-binding-invalid' }
         }
         return [pscustomobject]@{ result = 'transitioned'; reason = 'approved-cancellation'; attempt_status = 'not-applicable'; work_item_status = 'cancelled-approved'; scope_status = 'scope-in-progress'; terminal_evidence = [string]$scenario.terminal_evidence }
       }
       if (
         $scenario.transition -ceq 'approved-non-applicability' -and
         @('pending', 'ready') -ccontains [string]$item.status
       ) {
         if (
@@ -1212,21 +1249,21 @@ function Test-ScopeEngine([string]$Root, [string]$ContractText) {
           [string]$_.artifact_reference -ceq [string]$scenario.terminal_evidence
         })
         $decisionArtifact = if ($decisionArtifacts.Count -eq 1) { $decisionArtifacts[0] } else { $null }
         if (
           $null -eq $decisionArtifact -or
           [string]$decisionArtifact.artifact_reference -cne [string]$scenario.terminal_evidence -or
           [string]$decisionArtifact.work_item_id -cne [string]$item.work_item_id -or
           [int]$decisionArtifact.plan_revision -ne [int]$scenario.current_plan_revision -or
           [string]$decisionArtifact.decision -cne 'not-applicable-approved' -or
           [string]$decisionArtifact.approval_reference -cne [string]$scenario.approval_reference -or
-          -not [bool]$decisionArtifact.immutable
+          -not (& $isExactJsonTrue $decisionArtifact.immutable)
         ) {
           return [pscustomobject]@{ result = 'transition-invalid'; reason = 'decision-artifact-binding-invalid' }
         }
         return [pscustomobject]@{ result = 'transitioned'; reason = 'approved-non-applicability'; attempt_status = 'not-applicable'; work_item_status = 'not-applicable-approved'; scope_status = 'scope-in-progress'; terminal_evidence = [string]$scenario.terminal_evidence }
       }
       return [pscustomobject]@{ result = 'transition-invalid'; reason = 'transition-not-allowed' }
     }
 
     if ($scenario.operation -ceq 'revise') {
       $current = $scenario.current

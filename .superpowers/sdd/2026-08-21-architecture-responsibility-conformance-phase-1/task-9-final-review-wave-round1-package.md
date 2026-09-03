# Review package: 686492cbdc09475024c455213c3f4bf7ba7dc76a..e04242560502ea8c9d5e99998c57bff56fe460d3

## Commits
e042425 test: cover responsibility conformance workflow

## Files changed
 .../contracts/file-responsibility-conformance.md   |  23 ++-
 .../aitoolkit/skills/shared/ai-review/SKILL.md     |   4 +-
 .../templates/migration/implementation-report.md   |   2 +-
 .../aitoolkit/templates/migration/review-report.md |   4 +-
 .../tests/scenarios/architecture-review.Tests.ps1  | 218 +++++++++++++++++++++
 .../scenarios/responsibility-conformance.Tests.ps1 |   2 +-
 .../scenarios/responsibility-handoff.Tests.ps1     |  13 ++
 .../tests/scenarios/scope-engine.Tests.ps1         |  54 ++++-
 .../responsibility-conformance.validation.ps1      | 173 +++++++++++++---
 .../tests/validation/scope-engine.validation.ps1   |  36 +++-
 10 files changed, 482 insertions(+), 47 deletions(-)

## Diff
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/contracts/file-responsibility-conformance.md b/AIToolkit/AIToolkit-main/aitoolkit/contracts/file-responsibility-conformance.md
index 4181f5a..4c79929 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/contracts/file-responsibility-conformance.md
+++ b/AIToolkit/AIToolkit-main/aitoolkit/contracts/file-responsibility-conformance.md
@@ -85,31 +85,44 @@ class-name match, a line count, or a file-location guess.
 
 ## Changed Git Path Classification and Reconciliation
 
 Independent review derives the changed-path inventory from the immutable pinned
 `task-base..final-tree` Git comparison, including `M`, `A`, `R`, `C`, and `D`.
 Repository-relative paths rooted at `src/`, `lib/`, `app/`, `apps/*/src|lib|app`,
 `packages/*/src|lib|app`, `server/`, `client/`, `frontend/`, or `backend/` are
 canonically production-classified; nested test, spec, doc, script, tool,
 generated, build, and distribution roots are excluded unless an approved
 responsibility explicitly selects them. Marker presence never determines
-whether a changed path enters the inventory.
-
-Every changed Git path reconciles to implementation `Change Hygiene` using
+whether a changed path enters the inventory. Normalize repository-relative
+backslashes to `/` once before comparing design, review, Git, Change Hygiene,
+verification binding, or source evidence; absolute paths, empty segments, and
+`.`/`..` segments are invalid. Parse owner markers only from canonically
+production-classified paths or paths explicitly selected by approved owner
+authority. Executable route/provider content in a production path must be
+covered by a responsibility block; markerless content beside a valid block is
+still unowned and blocks conformance.
+
+Every changed Git path reconciles one-to-one to exactly one implementation `Change Hygiene` row using
 `A/C = new`, `M/R = existing`, and `D = deleted`. Every production-classified
 changed path additionally reconciles to an active responsibility or an
 approved deletion. For `M/R`, compare pinned base and final contents so a
 removed responsibility block enters the deletion flow even when its file
-survives. A deleted path or removed block uses exact immutable evidence
+survives. Every `D` path, whether or not it contains an owner, and every removed
+block uses exact immutable evidence
 `source:<task-base SHA>:<path>; diff:<task-base SHA>..<final-tree SHA>:<path>`;
 the deleted path is not required in final-tree. Omitted paths, markerless
-production changes, stale or foreign evidence, and unapproved removals block.
+production changes, duplicate/surplus rows, stale or foreign evidence, and
+unapproved removals block. A rename preserves both old and new path authority,
+is production-classified when either side is production, and uses exact
+`source:<task-base SHA>:<old path>; diff:<task-base SHA>..<final-tree SHA>:<old path>-><new path>`
+in Change Hygiene; responsibility diff evidence uses the same explicit
+`<old path>-><new path>` mapping while base-source evidence resolves the old path.
 
 ## Review Verdicts
 
 ```text
 Verdict = PASS | BLOCKED
 ```
 
 Structural responsibility remains `PASS` or `BLOCKED` independently of runtime
 waivers. A runtime waiver changes neither responsibility ownership nor the
 structural verdict.
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/skills/shared/ai-review/SKILL.md b/AIToolkit/AIToolkit-main/aitoolkit/skills/shared/ai-review/SKILL.md
index df0ba69..eb59d29 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/skills/shared/ai-review/SKILL.md
+++ b/AIToolkit/AIToolkit-main/aitoolkit/skills/shared/ai-review/SKILL.md
@@ -33,21 +33,21 @@ Với `workflow_type: migration`, thực hiện đúng thứ tự gate sau; ch
 3. Canonical selector validation.
 4. Tree conformance from final inventory and source/diff evidence.
 5. Responsibility conformance against planned responsibility evidence.
 6. Verification ownership from final inventory and source/diff evidence.
 7. Production activation-path validation.
 8. Behavior, failure modes, security, performance, and tests.
 9. Change hygiene.
 
 Architecture-first review order: master/work-item -> rules -> selector -> tree -> responsibility -> verification ownership -> activation -> behavior/security/performance -> hygiene.
 
-Derive every `M/A/R/C/D` changed Git path from the pinned comparison and reconcile it to implementation `Change Hygiene` with exact status mapping `A/C = new`, `M/R = existing`, and `D = deleted`. Independently classify production paths by the canonical roots in the file-responsibility contract: markerless production changes still require approved responsibility evidence, while irrelevant docs are not promoted to production by guesswork. Compare pinned base and final content for surviving `M/R` paths so removed responsibility blocks enter deletion reconciliation. A removed block in a surviving file uses `File Kind = existing` and exact task-base source/removal-diff evidence; a deleted file uses `File Kind = deleted` and does not require a final-tree path.
+Derive every `M/A/R/C/D` changed Git path from the pinned comparison and reconcile it one-to-one to exactly one implementation `Change Hygiene` row with exact status mapping `A/C = new`, `M/R = existing`, and `D = deleted`. Normalize repository separators to `/` once across design, review, Git, hygiene, verification binding, and source evidence; reject aliases, absolute paths, and traversal. Independently classify production paths by the canonical roots in the file-responsibility contract and parse owner markers only for production-classified or explicitly selected authority paths: markerless executable content remains unowned even beside a valid block, while irrelevant docs are not promoted by incidental markers. Compare pinned base and final content for surviving `M/R` paths so removed responsibility blocks enter deletion reconciliation. Every deleted Git path needs exact task-base source/removal-diff checkpoint evidence even when it has no owner. A removed block in a surviving file uses `File Kind = existing`; a deleted file uses `File Kind = deleted` and does not require a final-tree path. Preserve both sides of a rename, classify it as production when either side is production, resolve base evidence at the old path, and require explicit `<old path>-><new path>` mapping in checkpoint and review diff evidence.
 
 The reviewer independently inspects the final inventory and task-base/final-tree source diff. Implementation self-attestation is not semantic PASS evidence. For every selected Verification Ownership row, resolve `Evidence Path` from the pinned final-tree SHA, locate exactly its named scenario, and bind the scenario's exact verification owner, production responsibility, capability, evidence kind, disposition, and production path/symbol to the independent final production inventory. `production-composition` also binds the exact production route and provider. An unchanged verification file is valid final-tree source evidence without a fabricated diff; missing, foreign, stale, self-attested, or test-only registry/provider evidence is `BLOCKED`. This is framework-neutral source-contract validation and must not infer authority from a language-specific AST. Never discard a base-only deleted responsibility after checking its removal diff: reconcile its owner, path, public symbols, capabilities, effects, architecture/co-location authority, verification owners, routes, and providers to one exact approved design removal decision, one `Change Hygiene` row with `File Kind = deleted`, and one independent Responsibility Review Evidence row using task-base source plus removal-diff references. A missing or partial reconciliation is an unplanned deletion and blocks Tree and Responsibility conformance. Missing master context, canonical selector, conformance matrix, exemplar, actual/planned tree evidence, responsibility review evidence, verification ownership evidence, or applicable production activation evidence records the matching verdict as `BLOCKED`, sets the overall verdict to `Reject`, and stops before reviewer dispatch and before behavior analysis. Rule Resolution remains an independent first severity gate and cannot be weakened by architecture ordering.
 
 Require exactly one Architecture Conformance Verdict, exactly one Canonical Selector Verdict, exactly one Tree Conformance Verdict, exactly one Responsibility Conformance Verdict, exactly one Verification Ownership Verdict, and exactly one Production Activation-path Verdict. Any `BLOCKED` verdict makes the overall verdict `Reject`, independently of severity counts.
 
 ## Mandatory architecture findings
 
 Review invented aggregate state; direct widget service/router calls; raw layout replacing the target wrapper; missing unit boundary; wrong localization mechanism; missing lifecycle gate; tests bypassing the production provider; missing production subscription key; planned/actual tree drift; source/diff inventory that exposes an omitted owner, public symbol, effect, route, or provider; an unplanned full deletion of an owned responsibility; and unapproved structural deviation. Classify a missing production subscription key as `Critical`. An unapproved structural deviation is at least `Major` and is `Critical` when activation, routing, or rendering fails.
 
 ## Việc cần làm (thứ tự)
@@ -87,21 +87,21 @@ Giữ nguyên severity gate dùng chung: Blocking condition: `Rule Resolution: B
 Rule Resolution is evaluated before severity counts. Vì vậy `Rule Resolution: BLOCKED` với 0 Critical và 0 Major vẫn có verdict `Reject`; không được suy `Approve` từ counts.
 
 Only exact `Critical count: 0` with exact overall `Verdict: Approve` is executable and may seed verification. `Approve-with-fixes`, `Reject`, invalid or positive Critical count, and every `BLOCKED` architecture verdict remain non-executable even when an Architecture Responsibility Handoff row says `PASS`.
 
 ## Migration-only handoff extension
 
 Preserve the immediate predecessor Activation Slice envelope without loss: keep the complete case-sensitive slice ID set, Applicability, all nine canonical seam rows, and every predecessor Source Reference and Trace ID. Source Reference enrichment is append-only, and predecessor Trace IDs remain a subset of successor Trace IDs. Never reconstruct it from cumulative artifacts.
 
 Khi orchestrator gọi step này với `workflow_type: migration`, trước hết copy nguyên vẹn `Master Scope Context` của work item. Chỉ khi `Delivery Adapter Kind` là `migration-unit`, immediate predecessor mới phải chứa đúng một section `Selected Migration Unit`; validate và copy nguyên vẹn `migration_unit_id`, plan reference, approval reference, mode constraint, `Bootstrap Scope`, Foundation Baseline ID, foundation baseline reference, foundation baseline approval reference, baseline reference, và trace IDs sang report mới. Với adapter khác, bỏ section `Selected Migration Unit` và không suy ra unit từ diff.
 
-Migration review là producer gốc của responsibility handoff (`responsibility handoff origin producer`), không copy handoff từ implementation. Dùng `templates/migration/review-report.md` và emit đúng một bounded front matter có `step_id: 11-ai-review`, lifecycle `status`/`result`/`produced_at`, và discriminator `responsibility_contract.version: 1`, `applicability: required`. Draft artifacts omit `approval_source`; approved artifacts dùng đúng canonical enum `human | auto | auto-waive`, và review executable cho terminal chain phải là `approved/complete/human`. Copy ordinally exact tám field `Run ID`, master spec reference/ID/revision, master plan reference/ID/revision và `Work Item ID` từ immediate predecessor; không reconstruct từ cumulative artifacts hoặc directory scan.
+Migration review là producer gốc của responsibility handoff (`responsibility handoff origin producer`), không copy handoff từ implementation. Dùng `templates/migration/review-report.md` và emit đúng một bounded front matter với exact top-level key order/cardinality `step_id`, `status`, `result`, `approval_source`, `produced_at`, `responsibility_contract`; keys quoted, case-variant, hyphenated, duplicate, extra, hoặc reordered đều invalid. `produced_at` phải là calendar date hợp lệ theo exact `yyyy-MM-dd`, không blank hay malformed. `step_id` phải exact canonical `11-ai-review`; discriminator là `responsibility_contract.version: 1`, `applicability: required`. Draft artifacts omit `approval_source`; approved executable artifacts dùng exact `approved/complete/human`, và review `Reject`, Critical-bearing, hoặc otherwise non-PASS không được seed downstream execution. Copy ordinally exact tám field `Run ID`, master spec reference/ID/revision, master plan reference/ID/revision và `Work Item ID` từ immediate predecessor; không reconstruct từ cumulative artifacts hoặc directory scan.
 
 Emit đúng một `Task Provenance` row. Resolve assurance identity từ approved current adapter authority: với `migration-unit`, `Task / Unit` phải bằng exact `Selected Migration Unit.Migration Unit ID`; với `task | story | package | phase | milestone | none`, nó phải bằng current `Master Scope Context.Work Item ID`. `Task-base SHA` và `Final-tree SHA` phải là hai SHA đã validate và dùng để review exact diff; `Source Artifact` phải resolve đúng immediate predecessor `implementation-report.md`. Missing, placeholder, stale, cross-run, cross-work-item, hoặc mismatch với implementation `Change Hygiene` là `result: blocked`.
 
 Sau khi independent inventory review hoàn tất, emit đúng một `Architecture Responsibility Handoff` row theo canonical `aitoolkit/contracts/file-responsibility-conformance.md`. Preserve ba semantic verdict do review độc lập tạo ra; derive `Architecture Conformance State = PASS` chỉ khi Tree, Responsibility và Verification Ownership đều `PASS`, ngược lại `BLOCKED`. `Evidence References` phải là exact `source-diff:<task-base SHA>..<final-tree SHA>#<WORK-*>` bind cùng row `Task Provenance`; không dùng implementation self-attestation, review filename, caller aggregate, hoặc evidence từ run khác.
 
 `verification-testing` là immediate consumer: nó chỉ copy ordinally exact `Task Provenance` và `Architecture Responsibility Handoff` từ review artifact đã `approved/complete/human`. Một review còn `draft`, `blocked`, stale, cross-run, sai immediate predecessor hoặc có handoff không khớp provenance không được khởi tạo terminal chain.
 
 Đồng thời đọc `aitoolkit/contracts/activation-slice.md`, validate section `Activation Slice`, và copy nguyên vẹn cùng stable ID, mọi seam row và trace IDs sang report. Thiếu, duplicate, đổi tên hoặc mất trace làm handoff `result: blocked`; không suy lại slice từ diff.
 
 - Ghi front matter migration là `result: complete | blocked` ngoài lifecycle `status: draft`.
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/templates/migration/implementation-report.md b/AIToolkit/AIToolkit-main/aitoolkit/templates/migration/implementation-report.md
index 7faa8eb..8e1539d 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/templates/migration/implementation-report.md
+++ b/AIToolkit/AIToolkit-main/aitoolkit/templates/migration/implementation-report.md
@@ -165,21 +165,21 @@ Required for normal `draft/complete` and `approved/complete` implementation outp
 | <WORK-*> | <ACT-001> | <canonical seam> | <test/scenario> | <lệnh> | <PASS / FAIL / BLOCKED> | <approved slice/seam trace IDs> |
 
 ## Trace ID triển khai
 
 | Trace ID | Implementation Reference |
 |---|---|
 | <REQ-001> | <path hoặc symbol> |
 
 ## Change Hygiene
 
-List every pinned `task-base..final-tree` changed Git path. Use exact `File Kind`: `A/C = new`, `M/R = existing`, `D = deleted`. A deleted path is resolved from task-base and does not need to exist in final-tree; set `Checkpoint History` to exact `source:<task-base SHA>:<deleted path>; diff:<task-base SHA>..<final-tree SHA>:<deleted path>`. For a removed responsibility block in a surviving file, use `existing` and the same base-source/removal-diff evidence for that owner symbol. Omitted, stale, foreign, or status-mismatched rows are blocking.
+List every pinned `task-base..final-tree` changed Git path exactly once; duplicate, surplus, stale, or omitted rows are blocking. Normalize repository path separators to `/` before writing the row. Use exact `File Kind`: `A/C = new`, `M/R = existing`, `D = deleted`. Every deleted path is resolved from task-base whether or not it contains an owner and does not need to exist in final-tree; set `Checkpoint History` to exact `source:<task-base SHA>:<deleted path>; diff:<task-base SHA>..<final-tree SHA>:<deleted path>`. For a removed responsibility block in a surviving file, use `existing` and the same base-source/removal-diff evidence for that owner symbol. A rename keeps the destination in `File`, preserves old/new authority, and requires exact `source:<task-base SHA>:<old path>; diff:<task-base SHA>..<final-tree SHA>:<old path>-><new path>`. Omitted, duplicate, surplus, stale, foreign, or status-mismatched rows are blocking.
 
 | Task / Unit | File | File Kind | Edited Region / Symbol | Formatter Command | Unrelated Diff | Checkpoint History | Task-base SHA | Final-tree SHA |
 |---|---|---|---|---|---|---|---|---|
 | <WORK-*> | <path> | <new, existing, or deleted> | <region or symbol> | <command or none> | none | <checkpoint SHAs, deletion evidence, or none> | <sha> | <sha> |
 
 ## Lệnh và kết quả
 
 | Command | Result | Evidence |
 |---|---|---|
 | <lệnh> | <kết quả> | <tham chiếu> |
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/templates/migration/review-report.md b/AIToolkit/AIToolkit-main/aitoolkit/templates/migration/review-report.md
index 9cadac9..efca228 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/templates/migration/review-report.md
+++ b/AIToolkit/AIToolkit-main/aitoolkit/templates/migration/review-report.md
@@ -62,23 +62,23 @@ Keep `Selected Migration Unit` only when `Delivery Adapter Kind` is `migration-u
 - Exemplars: <path/symbol exemplar đã đọc>
 - Actual File Tree vs Planned File Tree: <đối chiếu path/symbol và drift>
 - Approved Structural Deviations: <decision/approval hoặc not-applicable>
 
 ## Responsibility Review Evidence
 
 - Tree Conformance Verdict: <PASS | BLOCKED>
 - Responsibility Conformance Verdict: <PASS | BLOCKED>
 - Verification Ownership Verdict: <PASS | BLOCKED>
 - Reviewer inspects the task-base/final-tree diff independently; implementation self-attestation is not semantic PASS evidence.
-- Derive every pinned `M/A/R/C/D` changed Git path and reconcile it to implementation `Change Hygiene` (`A/C = new`, `M/R = existing`, `D = deleted`). Apply the canonical production-root classifier independently of responsibility markers; markerless production changes, omitted rows, and stale/foreign/status-mismatched evidence are `BLOCKED`, while irrelevant docs are not guessed to be production.
+- Derive every pinned `M/A/R/C/D` changed Git path and reconcile it one-to-one to exactly one implementation `Change Hygiene` row (`A/C = new`, `M/R = existing`, `D = deleted`). Normalize `\` to `/` once before all design/review/Git/hygiene/source comparisons and reject aliases or traversal segments. Apply the canonical production-root classifier independently of responsibility markers; parse owners only for production-classified or explicitly selected authority paths. Markerless executable content beside a valid owner block, omitted/duplicate/surplus rows, and stale/foreign/status-mismatched evidence are `BLOCKED`, while irrelevant docs are not promoted by incidental markers.
 - Compare pinned base and final contents for every surviving `M/R` path. A responsibility block removed from a surviving file enters the same approved deletion reconciliation as a deleted file, but uses `File Kind = existing` plus exact task-base source/removal-diff evidence.
-- For every base-only deleted responsibility, require one approved design removal decision naming the complete deleted ownership/effect inventory, one implementation `Change Hygiene` row with `File Kind = deleted`, and one row below whose immutable evidence uses the task-base source and removal diff. Use exact `removed` for both Actual columns; an absent or partial approval is `BLOCKED`.
+- Require exact task-base source/removal-diff checkpoint evidence for every deleted Git path, even without an owner. For every base-only deleted responsibility, require one approved design removal decision naming the complete deleted ownership/effect inventory, one implementation `Change Hygiene` row with `File Kind = deleted`, and one row below whose immutable evidence uses the task-base source and removal diff. A rename is production when either old or new path is production and uses explicit `<old path>-><new path>` diff mapping while source evidence resolves the old path. Use exact `removed` for both Actual columns; an absent or partial approval is `BLOCKED`.
 
 | Responsibility ID | Source/Diff Evidence | Planned Public Symbols | Actual Public Symbols | Planned Effects | Actual Effects | Verdict |
 |---|---|---|---|---|---|---|
 
 ## Verification Ownership Source Evidence
 
 Resolve every row independently from the pinned final-tree `Evidence Path` and named scenario. Bind its verification owner, production responsibility, capability, evidence kind, disposition, production path/symbol, and—when `production-composition`—the exact production route/provider. An unchanged evidence file uses final-tree source evidence and must not invent a diff anchor.
 
 | Verification Owner ID | Final-tree Evidence Path | Scenario | Production Responsibility ID | Capability ID | Evidence Kind | Verification Disposition | Production Binding | Production Route / Provider | Verdict |
 |---|---|---|---|---|---|---|---|---|---|
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/architecture-review.Tests.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/architecture-review.Tests.ps1
index 96741ec..1a0ccc5 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/architecture-review.Tests.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/architecture-review.Tests.ps1
@@ -611,20 +611,89 @@ function Add-MarkerlessProductionPath([string]$Root) {
   $markerlessRow = "| WORK-ADMIN | src/markerless_route.source | new | MarkerlessRoute | none | none | none | $taskBaseSha | $finalTreeSha |"
   $implementation = $implementation.Replace($anchorRows[0], "$($anchorRows[0])`n$markerlessRow")
   Set-Content -Encoding utf8 -LiteralPath $implementationPath -Value $implementation
 
   $reviewPath = Join-Path $Root 'artifacts/review-report.md'
   $review = (Get-Content -Raw -Encoding utf8 -LiteralPath $reviewPath).Replace($previousFinalTreeSha, $finalTreeSha)
   Set-Content -Encoding utf8 -LiteralPath $reviewPath -Value $review
   Set-Content -Encoding utf8 -LiteralPath $provenancePath -Value "Source Root: $sourceRoot`nTask-base SHA: $taskBaseSha`nFinal-tree SHA: $finalTreeSha`n"
 }
 
+function Add-DeletedNonOwnerPath([string]$Root, [bool]$ValidCheckpoint) {
+  $provenancePath = Join-Path $Root 'artifacts/review-provenance.md'
+  $provenance = Get-Content -Raw -Encoding utf8 -LiteralPath $provenancePath
+  $sourceRoot = [regex]::Match($provenance, '(?m)^Source Root:\s*(?<value>.+)$').Groups['value'].Value.Trim()
+  $taskBaseSha = [regex]::Match($provenance, '(?im)^Task-base SHA:[ \t]*(?<value>[0-9a-f]{40})[ \t]*\r?$').Groups['value'].Value
+  $previousFinalTreeSha = [regex]::Match($provenance, '(?im)^Final-tree SHA:[ \t]*(?<value>[0-9a-f]{40})[ \t]*\r?$').Groups['value'].Value
+  Remove-Item -LiteralPath (Join-Path $sourceRoot 'README') -Force
+  Invoke-PinnedSourceGit $sourceRoot @('add', '--all', '--', 'README') | Out-Null
+  Invoke-PinnedSourceGit $sourceRoot @('commit', '-m', 'delete non-owner readme') | Out-Null
+  $finalTreeSha = Invoke-PinnedSourceGit $sourceRoot @('rev-parse', 'HEAD')
+  $checkpoint = if ($ValidCheckpoint) { "source:${taskBaseSha}:README; diff:${taskBaseSha}..${finalTreeSha}:README" } else { 'none' }
+  $implementationPath = Join-Path $Root 'artifacts/implementation-report.md'
+  $implementation = (Get-Content -Raw -Encoding utf8 -LiteralPath $implementationPath).Replace($previousFinalTreeSha, $finalTreeSha)
+  $anchorRows = @($implementation -split '\r?\n' | Where-Object { $_ -cmatch '^\| WORK-ADMIN \| src/admin_route\.source \|' })
+  if ($anchorRows.Count -ne 1) { throw 'Deleted non-owner Change Hygiene anchor is missing or duplicated' }
+  $deletedRow = "| WORK-ADMIN | README | deleted | repository readme | none | none | $checkpoint | $taskBaseSha | $finalTreeSha |"
+  Set-Content -Encoding utf8 -LiteralPath $implementationPath -Value $implementation.Replace($anchorRows[0], "$($anchorRows[0])`n$deletedRow")
+  $reviewPath = Join-Path $Root 'artifacts/review-report.md'
+  $review = (Get-Content -Raw -Encoding utf8 -LiteralPath $reviewPath).Replace($previousFinalTreeSha, $finalTreeSha)
+  Set-Content -Encoding utf8 -LiteralPath $reviewPath -Value $review
+  Set-Content -Encoding utf8 -LiteralPath $provenancePath -Value "Source Root: $sourceRoot`nTask-base SHA: $taskBaseSha`nFinal-tree SHA: $finalTreeSha`n"
+}
+
+function Rename-ProductionOwner([string]$Root, [bool]$ExplicitMapping) {
+  $provenancePath = Join-Path $Root 'artifacts/review-provenance.md'
+  $provenance = Get-Content -Raw -Encoding utf8 -LiteralPath $provenancePath
+  $sourceRoot = [regex]::Match($provenance, '(?m)^Source Root:\s*(?<value>.+)$').Groups['value'].Value.Trim()
+  $taskBaseSha = [regex]::Match($provenance, '(?im)^Task-base SHA:[ \t]*(?<value>[0-9a-f]{40})[ \t]*\r?$').Groups['value'].Value
+  $previousFinalTreeSha = [regex]::Match($provenance, '(?im)^Final-tree SHA:[ \t]*(?<value>[0-9a-f]{40})[ \t]*\r?$').Groups['value'].Value
+  [void](New-Item -ItemType Directory -Force -Path (Join-Path $sourceRoot 'docs'))
+  Move-Item -LiteralPath (Join-Path $sourceRoot 'src/admin_route.source') -Destination (Join-Path $sourceRoot 'docs/admin_route.source')
+  $verificationPath = Join-Path $sourceRoot 'test/admin_route_test.ps1'
+  $verificationText = (Get-Content -Raw -Encoding utf8 -LiteralPath $verificationPath).Replace('@production-binding src/admin_route.source#AdminRoute', '@production-binding docs/admin_route.source#AdminRoute')
+  Set-Content -Encoding utf8 -LiteralPath $verificationPath -Value $verificationText
+  Invoke-PinnedSourceGit $sourceRoot @('add', '--all', '--', 'src/admin_route.source', 'docs/admin_route.source', 'test/admin_route_test.ps1') | Out-Null
+  Invoke-PinnedSourceGit $sourceRoot @('commit', '-m', 'rename production owner to docs') | Out-Null
+  $finalTreeSha = Invoke-PinnedSourceGit $sourceRoot @('rev-parse', 'HEAD')
+  foreach ($relativePath in @('artifacts/design-report.md', 'artifacts/implementation-report.md', 'artifacts/review-report.md')) {
+    $path = Join-Path $Root $relativePath
+    $text = (Get-Content -Raw -Encoding utf8 -LiteralPath $path).Replace($previousFinalTreeSha, $finalTreeSha).Replace('src/admin_route.source', 'docs/admin_route.source')
+    Set-Content -Encoding utf8 -LiteralPath $path -Value $text
+  }
+  $implementationPath = Join-Path $Root 'artifacts/implementation-report.md'
+  $implementation = Get-Content -Raw -Encoding utf8 -LiteralPath $implementationPath
+  $sourceRows = @($implementation -split '\r?\n' | Where-Object { $_ -cmatch '^\| WORK-ADMIN \| docs/admin_route\.source \|' })
+  if ($sourceRows.Count -ne 1) { throw 'Renamed production Change Hygiene row is missing or duplicated' }
+  $checkpoint = if ($ExplicitMapping) { "source:${taskBaseSha}:src/admin_route.source; diff:${taskBaseSha}..${finalTreeSha}:src/admin_route.source->docs/admin_route.source" } else { "source:${taskBaseSha}:src/admin_route.source; diff:${taskBaseSha}..${finalTreeSha}:docs/admin_route.source" }
+  $updatedSourceRow = [regex]::Replace($sourceRows[0], '\| none \| (?=[0-9a-f]{40} \| [0-9a-f]{40} \|$)', "| $checkpoint | ")
+  if ($updatedSourceRow -ceq $sourceRows[0]) { throw 'Renamed production checkpoint replacement failed' }
+  Set-Content -Encoding utf8 -LiteralPath $implementationPath -Value $implementation.Replace($sourceRows[0], $updatedSourceRow)
+  $reviewPath = Join-Path $Root 'artifacts/review-report.md'
+  $review = Get-Content -Raw -Encoding utf8 -LiteralPath $reviewPath
+  if ($ExplicitMapping) {
+    $review = $review.Replace("diff:${taskBaseSha}..${finalTreeSha}:docs/admin_route.source#", "diff:${taskBaseSha}..${finalTreeSha}:src/admin_route.source->docs/admin_route.source#")
+  }
+  Set-Content -Encoding utf8 -LiteralPath $reviewPath -Value $review
+  Set-Content -Encoding utf8 -LiteralPath $provenancePath -Value "Source Root: $sourceRoot`nTask-base SHA: $taskBaseSha`nFinal-tree SHA: $finalTreeSha`n"
+}
+
+function Convert-ReviewPathsToWindows([string]$Root) {
+  foreach ($relativePath in @('artifacts/design-report.md', 'artifacts/implementation-report.md', 'artifacts/review-report.md')) {
+    $path = Join-Path $Root $relativePath
+    $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
+    $updated = $text.Replace('src/admin_route.source', 'src\admin_route.source')
+    if ($updated -ceq $text) { throw "Windows path fixture did not change $relativePath" }
+    Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
+  }
+}
+
 function Keep-ImplementationSelfAttestationPass([string]$Root) {
   $path = Join-Path $Root 'artifacts/implementation-report.md'
   $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
   $updated = $text.Replace('Architecture Conformance State: NOT_REVIEWED', 'Architecture Conformance State: PASS')
   if ($updated -ceq $text) { throw 'Implementation self-attestation fixture replacement failed' }
   Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
 }
 
 function SubstituteReviewProvenanceFinalTree([string]$Root) {
   $provenancePath = Join-Path $Root 'artifacts/review-provenance.md'
@@ -709,20 +778,116 @@ foreach ($gitStatusCase in @('A', 'M', 'R', 'C')) {
     if ($statusRows.Count -ne 1 -or $inventoryErrors -cnotcontains 'responsibility-evidence-missing') {
       throw "markerless $gitStatusCase inventory was not independently classified and rejected: $($inventoryErrors -join '; ')"
     }
     Write-Output "PASS: markerless $gitStatusCase production path enters the pinned changed-path inventory and is rejected"
   }
   finally {
     if (Test-Path -LiteralPath $sourceRoot) { Remove-Item -LiteralPath $sourceRoot -Recurse -Force }
   }
 }
 
+$mixedOwnershipRoot = Join-Path ([IO.Path]::GetTempPath()) ('aitoolkit-mixed-ownership-' + [guid]::NewGuid().ToString('N'))
+try {
+  [void](New-Item -ItemType Directory -Force -Path (Join-Path $mixedOwnershipRoot 'src'))
+  Invoke-PinnedSourceGit $mixedOwnershipRoot @('init') | Out-Null
+  Invoke-PinnedSourceGit $mixedOwnershipRoot @('config', 'core.autocrlf', 'false') | Out-Null
+  Invoke-PinnedSourceGit $mixedOwnershipRoot @('config', 'user.email', 'fixtures@example.test') | Out-Null
+  Invoke-PinnedSourceGit $mixedOwnershipRoot @('config', 'user.name', 'AIToolkit fixture') | Out-Null
+  $ownedRoute = "@responsibility RESP-OWNED`n@owner-symbol OwnedRoute`n@public-symbol OwnedRoute`n@owned-capability CAP-OWNED`n@effect route registration`n@architecture-authority target-exemplar`n@co-location-policy feature-local`n@verification-owner VERIFY-OWNER-OWNED`nroute OwnedRoute -> OwnedProvider"
+  $sourcePath = Join-Path $mixedOwnershipRoot 'src/routes.source'
+  Set-Content -Encoding utf8 -LiteralPath $sourcePath -Value $ownedRoute
+  Invoke-PinnedSourceGit $mixedOwnershipRoot @('add', '--all') | Out-Null
+  Invoke-PinnedSourceGit $mixedOwnershipRoot @('commit', '-m', 'owned route base') | Out-Null
+  $taskBaseSha = Invoke-PinnedSourceGit $mixedOwnershipRoot @('rev-parse', 'HEAD')
+  Set-Content -Encoding utf8 -LiteralPath $sourcePath -Value "route RogueRoute -> RogueProvider`n$ownedRoute"
+  Invoke-PinnedSourceGit $mixedOwnershipRoot @('add', '--all') | Out-Null
+  Invoke-PinnedSourceGit $mixedOwnershipRoot @('commit', '-m', 'add unowned route and provider') | Out-Null
+  $finalTreeSha = Invoke-PinnedSourceGit $mixedOwnershipRoot @('rev-parse', 'HEAD')
+  $inventoryErrors = [Collections.Generic.List[string]]::new()
+  [void](Get-ArcPinnedSourceInventory -SourceRoot $mixedOwnershipRoot -TaskBaseSha $taskBaseSha -FinalTreeSha $finalTreeSha -Errors $inventoryErrors)
+  if ($inventoryErrors -cnotcontains 'responsibility-evidence-missing') {
+    throw 'markerless route/provider before an unchanged responsibility block was not rejected'
+  }
+  Write-Output 'PASS: mixed owned and unowned production route/provider content is rejected'
+}
+finally {
+  if (Test-Path -LiteralPath $mixedOwnershipRoot) { Remove-Item -LiteralPath $mixedOwnershipRoot -Recurse -Force }
+}
+
+$incidentalMarkerRoot = Join-Path ([IO.Path]::GetTempPath()) ('aitoolkit-incidental-marker-' + [guid]::NewGuid().ToString('N'))
+try {
+  [void](New-Item -ItemType Directory -Force -Path (Join-Path $incidentalMarkerRoot 'docs'))
+  Invoke-PinnedSourceGit $incidentalMarkerRoot @('init') | Out-Null
+  Invoke-PinnedSourceGit $incidentalMarkerRoot @('config', 'core.autocrlf', 'false') | Out-Null
+  Invoke-PinnedSourceGit $incidentalMarkerRoot @('config', 'user.email', 'fixtures@example.test') | Out-Null
+  Invoke-PinnedSourceGit $incidentalMarkerRoot @('config', 'user.name', 'AIToolkit fixture') | Out-Null
+  Set-Content -Encoding utf8 -LiteralPath (Join-Path $incidentalMarkerRoot 'README') -Value 'incidental marker base'
+  Invoke-PinnedSourceGit $incidentalMarkerRoot @('add', '--all') | Out-Null
+  Invoke-PinnedSourceGit $incidentalMarkerRoot @('commit', '-m', 'incidental marker base') | Out-Null
+  $taskBaseSha = Invoke-PinnedSourceGit $incidentalMarkerRoot @('rev-parse', 'HEAD')
+  $incidentalPath = 'docs/responsibility-example.source'
+  $incidentalText = "@responsibility RESP-DOCS-EXAMPLE`n@owner-symbol ExampleRoute`n@public-symbol ExampleRoute`n@owned-capability CAP-DOCS-EXAMPLE`n@effect route registration`n@architecture-authority target-exemplar`n@co-location-policy feature-local`n@verification-owner VERIFY-OWNER-DOCS-EXAMPLE`nroute ExampleRoute -> ExampleProvider"
+  Set-Content -Encoding utf8 -LiteralPath (Join-Path $incidentalMarkerRoot $incidentalPath) -Value $incidentalText
+  Invoke-PinnedSourceGit $incidentalMarkerRoot @('add', '--all') | Out-Null
+  Invoke-PinnedSourceGit $incidentalMarkerRoot @('commit', '-m', 'add docs example') | Out-Null
+  $finalTreeSha = Invoke-PinnedSourceGit $incidentalMarkerRoot @('rev-parse', 'HEAD')
+  $inventoryErrors = [Collections.Generic.List[string]]::new()
+  $sourceInventory = Get-ArcPinnedSourceInventory -SourceRoot $incidentalMarkerRoot -TaskBaseSha $taskBaseSha -FinalTreeSha $finalTreeSha -Errors $inventoryErrors
+  if ($inventoryErrors.Count -ne 0 -or $sourceInventory.ActiveOwners.Count -ne 0 -or $sourceInventory.ChangedPaths.Count -ne 1) {
+    throw "incidental non-production marker became owner authority: $($inventoryErrors -join '; ')"
+  }
+  $selectedErrors = [Collections.Generic.List[string]]::new()
+  $selectedInventory = Get-ArcPinnedSourceInventory -SourceRoot $incidentalMarkerRoot -TaskBaseSha $taskBaseSha -FinalTreeSha $finalTreeSha -SelectedPaths @($incidentalPath) -Errors $selectedErrors
+  if ($selectedErrors.Count -ne 0 -or @($selectedInventory.ActiveOwners | Where-Object { $_.Id -ceq 'RESP-DOCS-EXAMPLE' }).Count -ne 1) {
+    throw "explicitly selected non-production owner authority was not parsed: $($selectedErrors -join '; ')"
+  }
+  Write-Output 'PASS: non-production markers are ignored unless explicitly selected as owner authority'
+}
+finally {
+  if (Test-Path -LiteralPath $incidentalMarkerRoot) { Remove-Item -LiteralPath $incidentalMarkerRoot -Recurse -Force }
+}
+
+$renameAuthorityRoot = Join-Path ([IO.Path]::GetTempPath()) ('aitoolkit-rename-authority-' + [guid]::NewGuid().ToString('N'))
+try {
+  [void](New-Item -ItemType Directory -Force -Path (Join-Path $renameAuthorityRoot 'src'))
+  [void](New-Item -ItemType Directory -Force -Path (Join-Path $renameAuthorityRoot 'docs'))
+  Invoke-PinnedSourceGit $renameAuthorityRoot @('init') | Out-Null
+  Invoke-PinnedSourceGit $renameAuthorityRoot @('config', 'core.autocrlf', 'false') | Out-Null
+  Invoke-PinnedSourceGit $renameAuthorityRoot @('config', 'user.email', 'fixtures@example.test') | Out-Null
+  Invoke-PinnedSourceGit $renameAuthorityRoot @('config', 'user.name', 'AIToolkit fixture') | Out-Null
+  $keptOwner = "@responsibility RESP-RENAME-KEEP`n@owner-symbol RenameKeepRoute`n@public-symbol RenameKeepRoute`n@owned-capability CAP-RENAME-KEEP`n@effect route registration`n@architecture-authority target-exemplar`n@co-location-policy feature-local`n@verification-owner VERIFY-OWNER-RENAME-KEEP`nroute RenameKeepRoute -> RenameKeepProvider"
+  $keptOwner += "`n" + ((1..30 | ForEach-Object { "# preserved rename context $_" }) -join "`n")
+  $removedOwner = "@responsibility RESP-RENAME-REMOVE`n@owner-symbol RenameRemoveRoute`n@public-symbol RenameRemoveRoute`n@owned-capability CAP-RENAME-REMOVE`n@effect route registration`n@architecture-authority target-exemplar`n@co-location-policy feature-local`n@verification-owner VERIFY-OWNER-RENAME-REMOVE`nroute RenameRemoveRoute -> RenameRemoveProvider"
+  $basePath = 'src/renamed.source'
+  $finalPath = 'docs/renamed.source'
+  Set-Content -Encoding utf8 -LiteralPath (Join-Path $renameAuthorityRoot $basePath) -Value "$keptOwner`n$removedOwner"
+  Invoke-PinnedSourceGit $renameAuthorityRoot @('add', '--all') | Out-Null
+  Invoke-PinnedSourceGit $renameAuthorityRoot @('commit', '-m', 'rename authority base') | Out-Null
+  $taskBaseSha = Invoke-PinnedSourceGit $renameAuthorityRoot @('rev-parse', 'HEAD')
+  Move-Item -LiteralPath (Join-Path $renameAuthorityRoot $basePath) -Destination (Join-Path $renameAuthorityRoot $finalPath)
+  Set-Content -Encoding utf8 -LiteralPath (Join-Path $renameAuthorityRoot $finalPath) -Value $keptOwner
+  Invoke-PinnedSourceGit $renameAuthorityRoot @('add', '--all') | Out-Null
+  Invoke-PinnedSourceGit $renameAuthorityRoot @('commit', '-m', 'rename production authority to docs and remove owner') | Out-Null
+  $finalTreeSha = Invoke-PinnedSourceGit $renameAuthorityRoot @('rev-parse', 'HEAD')
+  $inventoryErrors = [Collections.Generic.List[string]]::new()
+  $sourceInventory = Get-ArcPinnedSourceInventory -SourceRoot $renameAuthorityRoot -TaskBaseSha $taskBaseSha -FinalTreeSha $finalTreeSha -Errors $inventoryErrors
+  $renameRecord = @($sourceInventory.ChangedPaths | Where-Object { $_.BasePath -ceq $basePath -and $_.FinalPath -ceq $finalPath })
+  $removed = @($sourceInventory.DeletedOwners | Where-Object { $_.Id -ceq 'RESP-RENAME-REMOVE' })
+  if ($inventoryErrors.Count -ne 0 -or $renameRecord.Count -ne 1 -or -not $renameRecord[0].IsProduction -or $renameRecord[0].RenameMapping -cne "$basePath->$finalPath" -or @($sourceInventory.ActiveOwners | Where-Object { $_.Id -ceq 'RESP-RENAME-KEEP' -and $_.Path -ceq $finalPath }).Count -ne 1 -or $removed.Count -ne 1 -or $removed[0].Path -cne $basePath) {
+    throw "rename authority did not preserve old/new production and deletion evidence: $($inventoryErrors -join '; ')"
+  }
+  Write-Output 'PASS: rename preserves old/new production authority and base-path deletion evidence'
+}
+finally {
+  if (Test-Path -LiteralPath $renameAuthorityRoot) { Remove-Item -LiteralPath $renameAuthorityRoot -Recurse -Force }
+}
+
 $removedBlockRoot = Join-Path ([IO.Path]::GetTempPath()) ('aitoolkit-removed-owner-block-' + [guid]::NewGuid().ToString('N'))
 try {
   [void](New-Item -ItemType Directory -Force -Path (Join-Path $removedBlockRoot 'src'))
   Invoke-PinnedSourceGit $removedBlockRoot @('init') | Out-Null
   Invoke-PinnedSourceGit $removedBlockRoot @('config', 'core.autocrlf', 'false') | Out-Null
   Invoke-PinnedSourceGit $removedBlockRoot @('config', 'user.email', 'fixtures@example.test') | Out-Null
   Invoke-PinnedSourceGit $removedBlockRoot @('config', 'user.name', 'AIToolkit fixture') | Out-Null
   $keptBlock = "@responsibility RESP-KEEP`n@owner-symbol KeepRoute`n@public-symbol KeepRoute`n@owned-capability CAP-KEEP`n@effect route registration`n@architecture-authority target-exemplar`n@co-location-policy feature-local`n@verification-owner VERIFY-OWNER-KEEP`nroute KeepRoute -> KeepProvider"
   $removedBlock = "@responsibility RESP-REMOVED`n@owner-symbol RemovedRoute`n@public-symbol RemovedRoute`n@owned-capability CAP-REMOVED`n@effect route registration`n@architecture-authority target-exemplar`n@co-location-policy feature-local`n@verification-owner VERIFY-OWNER-REMOVED`nroute RemovedRoute -> RemovedProvider"
   $sourcePath = Join-Path $removedBlockRoot 'src/routes.source'
@@ -747,20 +912,73 @@ finally {
 
 Assert-FailsLike 'review rejects a changed production path omitted from Change Hygiene' {
   param($root)
   $path = Join-Path $root 'artifacts/implementation-report.md'
   $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
   $updated = [regex]::Replace($text, '(?m)^\| WORK-ADMIN \| src/admin_route\.source \|[^\r\n]+\r?\n?', '')
   if ($updated -ceq $text) { throw 'Omitted changed production path fixture replacement failed' }
   Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
 } 'ARC-CONTRACT-MALFORMED-TABLE: Change Hygiene|responsibility-evidence-missing' $true
 
+Assert-FailsLike 'review rejects duplicate Change Hygiene rows for one changed path' {
+  param($root)
+  $path = Join-Path $root 'artifacts/implementation-report.md'
+  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
+  $rows = @($text -split '\r?\n' | Where-Object { $_ -cmatch '^\| WORK-ADMIN \| src/admin_route\.source \|' })
+  if ($rows.Count -ne 1) { throw 'Duplicate Change Hygiene fixture anchor is missing or duplicated' }
+  Set-Content -Encoding utf8 -LiteralPath $path -Value $text.Replace($rows[0], "$($rows[0])`n$($rows[0])")
+} 'responsibility-evidence-missing' $true
+
+Assert-FailsLike 'every deleted Git path requires immutable checkpoint evidence even without an owner' {
+  param($root)
+  Add-DeletedNonOwnerPath $root $false
+} 'responsibility-evidence-missing' $true
+
+Assert-Pass 'deleted non-owner Git path accepts exact base-source and removal-diff checkpoint evidence' {
+  param($root)
+  Add-DeletedNonOwnerPath $root $true
+} $true
+
+Assert-FailsLike 'renamed owner rejects destination-only checkpoint and review evidence' {
+  param($root)
+  Rename-ProductionOwner $root $false
+} 'responsibility-evidence-missing' $true $true
+
+Assert-Pass 'renamed owner accepts explicit old-to-new checkpoint and review reconciliation' {
+  param($root)
+  Rename-ProductionOwner $root $true
+} $true $true
+
+Assert-Pass 'composed review normalizes Windows repository paths before every authority comparison' {
+  param($root)
+  Convert-ReviewPathsToWindows $root
+} $true
+
+Assert-FailsLike 'canonical normalization rejects slash-backslash alias duplication in Change Hygiene' {
+  param($root)
+  $path = Join-Path $root 'artifacts/implementation-report.md'
+  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
+  $rows = @($text -split '\r?\n' | Where-Object { $_ -cmatch '^\| WORK-ADMIN \| src/admin_route\.source \|' })
+  if ($rows.Count -ne 1) { throw 'Path alias Change Hygiene anchor is missing or duplicated' }
+  $aliasRow = $rows[0].Replace('src/admin_route.source', 'src\admin_route.source')
+  Set-Content -Encoding utf8 -LiteralPath $path -Value $text.Replace($rows[0], "$($rows[0])`n$aliasRow")
+} 'responsibility-evidence-missing' $true
+
+Assert-FailsLike 'canonical normalization rejects parent-segment path ambiguity' {
+  param($root)
+  foreach ($relativePath in @('artifacts/design-report.md', 'artifacts/implementation-report.md', 'artifacts/review-report.md')) {
+    $path = Join-Path $root $relativePath
+    $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
+    Set-Content -Encoding utf8 -LiteralPath $path -Value $text.Replace('src/admin_route.source', 'src\..\src\admin_route.source')
+  }
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
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1
index bc2ead2..c9e0387 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1
@@ -1674,21 +1674,21 @@ foreach ($lineEndingCase in @(
     Assert-ReviewDiagnosticsExactly -Name "review emits only the exact Selected Migration Unit malformed-copy diagnostic $position the canonical section ($($lineEndingCase.Name))" `
       -ReviewText $malformedSecondSelectedUnit -ExpectedDiagnostics @('ARC-CONTRACT-HEADING-CARDINALITY: Selected Migration Unit') `
       -ImplementationText $migrationImplementationWithLineEndings -ApprovedPlanText $migrationPlanWithLineEndings
   }
 }
 $staleMigrationImplementationDiagnostics = @(Test-ResponsibilityImplementation -DesignText $validReviewDesign -ImplementationText ($migrationImplementation.Replace('08-migration-plan.md@2', '08-migration-plan.md@1')) -ContractText $contract)
 if ($staleMigrationImplementationDiagnostics -notcontains 'responsibility-evidence-missing') { throw "stale implementation selected plan reference should be rejected but got: $($staleMigrationImplementationDiagnostics -join '; ')" }
 Write-Output 'PASS: migration implementation rejects stale selected Plan Reference'
 Assert-ReviewRejected 'migration review rejects a selected Plan Reference mismatch' ($migrationReview.Replace('08-migration-plan.md@2', '08-migration-plan.md@1')) 'responsibility-evidence-missing' -ImplementationText $migrationImplementation -ApprovedPlanText $migrationPlan
 
-$approvedMigrationReview = $migrationReview.Replace('status: draft', "status: approved`napproval_source: human")
+$approvedMigrationReview = $migrationReview.Replace('status: draft', 'status: approved').Replace('result: complete', "result: complete`napproval_source: human")
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
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-handoff.Tests.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-handoff.Tests.ps1
index 6f9f717..9d01c84 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-handoff.Tests.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-handoff.Tests.ps1
@@ -487,26 +487,39 @@ Assert-HandoffDiagnosticsExactly 'producer-rendered terminal Knowledge Base reje
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
+Assert-HandoffRejected 'case-variant review step cannot bypass a Reject conclusion' ((New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -ReviewVerdict 'Reject').Replace('step_id: 11-ai-review', 'step_id: 11-AI-REVIEW')) $verification 'responsibility-evidence-missing'
+Assert-HandoffRejected 'case-variant review step cannot bypass a Critical finding' ((New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -CriticalCount 1).Replace('step_id: 11-ai-review', 'step_id: 11-AI-REVIEW')) $verification 'responsibility-evidence-missing'
 Assert-HandoffRejected 'conflicting review lifecycle fields cannot seed verification' ($review.Replace('status: approved', "status: approved`nstatus: draft")) $verification 'responsibility-evidence-missing'
 Assert-HandoffRejected 'draft verification cannot seed parity' (New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md' -Status 'draft') $parity 'responsibility-evidence-missing'
 Assert-HandoffRejected 'blocked parity cannot seed incremental regression' (New-HandoffArtifact -StepId '13-verify-parity' -SourceArtifact 'verification-report.md' -Result 'blocked') $regression 'responsibility-evidence-missing'
 Assert-HandoffRejected 'auto-approved regression cannot seed Knowledge Base' (New-HandoffArtifact -StepId '14-verify-regression' -SourceArtifact '13-parity-report.md' -ApprovalSource 'auto') $knowledgeBase 'responsibility-evidence-missing'
 Assert-HandoffRejected 'draft Knowledge Base is not terminal executable assurance' $regression (New-HandoffArtifact -StepId '15-knowledge-base' -SourceArtifact '14-regression-report.md' -Status 'draft') 'responsibility-evidence-missing'
 Assert-HandoffRejected 'downstream assurance front matter rejects an extra top-level key' ((New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md').Replace('produced_at: 2026-08-20', "foreign_run: RUN-OTHER`nproduced_at: 2026-08-20")) $parity 'responsibility-evidence-missing'
+foreach ($extraKeyCase in @(
+  @{ Name = 'quoted'; Line = '"foreign_run": RUN-OTHER' },
+  @{ Name = 'hyphenated'; Line = 'foreign-run: RUN-OTHER' },
+  @{ Name = 'case-variant'; Line = 'Status: approved' }
+)) {
+  $mutatedFrontMatter = (New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md').Replace('produced_at: 2026-08-20', "$($extraKeyCase.Line)`nproduced_at: 2026-08-20")
+  Assert-HandoffRejected "$($extraKeyCase.Name) extra front-matter key fails closed" $mutatedFrontMatter $parity 'responsibility-evidence-missing'
+}
+Assert-HandoffRejected 'blank produced_at cannot seed parity' ((New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md').Replace('produced_at: 2026-08-20', 'produced_at:')) $parity 'responsibility-evidence-missing'
+Assert-HandoffRejected 'malformed produced_at cannot seed parity' ((New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md').Replace('produced_at: 2026-08-20', 'produced_at: 2026-02-30')) $parity 'responsibility-evidence-missing'
+Assert-HandoffRejected 'front-matter key order is canonical' ((New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md').Replace("status: approved`nresult: complete", "result: complete`nstatus: approved")) $parity 'responsibility-evidence-missing'
 Assert-HandoffRejected 'seven-character provenance cannot seed verification' (New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -TaskBaseSha '1111111' -FinalTreeSha '2222222') (New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md' -TaskBaseSha '1111111' -FinalTreeSha '2222222') 'responsibility-evidence-missing'
 Assert-HandoffRejected 'legacy filename evidence cannot seed verification' (New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -Evidence 'review-report.md#responsibility-evidence') $verification 'responsibility-evidence-missing'
 Assert-HandoffRejected 'same work item and SHAs from another run cannot seed verification' $review (New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md' -RunId 'RUN-HANDOFF-OTHER') 'responsibility-evidence-missing'
 Assert-HandoffDiagnosticsExactly 'migration-unit handoff cannot omit selected unit' $review (New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md' -OmitSelectedMigrationUnit) @('ARC-CONTRACT-MISSING-TABLE: Selected Migration Unit')
 Assert-HandoffRejected 'generic handoff cannot invent selected unit' (New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -AdapterKind 'task') ((New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md' -AdapterKind 'task') + "`n## Selected Migration Unit`n") 'responsibility-evidence-missing'
 $genericReview = New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -AdapterKind 'task'
 $genericVerification = New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md' -AdapterKind 'task'
 $genericParity = New-HandoffArtifact -StepId '13-verify-parity' -SourceArtifact 'verification-report.md' -AdapterKind 'task'
 $genericRegression = New-HandoffArtifact -StepId '14-verify-regression' -SourceArtifact '13-parity-report.md' -AdapterKind 'task'
 $genericKnowledgeBase = New-HandoffArtifact -StepId '15-knowledge-base' -SourceArtifact '14-regression-report.md' -AdapterKind 'task'
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/scope-engine.Tests.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/scope-engine.Tests.ps1
index 57fd23b..ec321ee 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/scope-engine.Tests.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/scope-engine.Tests.ps1
@@ -521,20 +521,37 @@ $dependentAfterMismatch = New-WorkItem 'WORK-ADMIN-AFTER-MISMATCH' 2 @('WORK-ADM
 $mismatchedDependencyAuthority = New-QueueResponsibilityArtifact $mismatchedDependency.responsibility_evidence $mismatchedDependency
 $mismatchedDependencyAuthority.work_item_id = 'WORK-ADMIN-FOREIGN'
 $mismatchedDependencyResult = Invoke-ScopeScenario @{
   scenario_type = 'scope-engine'; operation = 'select'
   work_items = @($mismatchedDependency, $dependentAfterMismatch)
   responsibility_authority_artifacts = @($mismatchedDependencyAuthority)
 }
 Assert-Equal $mismatchedDependencyResult.result 'scope-blocked' 'Mismatched terminal dependency authority must not unlock its dependent'
 Assert-Equal $mismatchedDependencyResult.work_item_id '' 'A dependent must remain unselected when predecessor evidence is mismatched'
 
+foreach ($chainIndex in 1..4) {
+  $completeDependency = New-WorkItem "WORK-ADMIN-COMPLETE-DOWNSTREAM-$chainIndex" 1 @() 'complete'
+  $completeDependency.terminal_evidence = "runs/complete-downstream-$chainIndex-terminal.md"
+  $dependentAfterInvalidChain = New-WorkItem "WORK-ADMIN-AFTER-DOWNSTREAM-$chainIndex" 2 @($completeDependency.work_item_id)
+  $dependencyChain = New-ResponsibilityChain "runs/complete-downstream-$chainIndex-chain" $completeDependency.work_item_id
+  $dependencyChain.Artifacts[$chainIndex].approval_source = 'automation'
+  $dependencyTerminal = New-TerminalResponsibilityArtifact $completeDependency.terminal_evidence $completeDependency.work_item_id $completeDependency.status $dependencyChain.FinalReference $dependencyChain.References $dependencyChain.ModeConstraint
+  $dependencyResult = Invoke-ScopeScenario @{
+    scenario_type = 'scope-engine'; operation = 'select'
+    work_items = @($completeDependency, $dependentAfterInvalidChain)
+    terminal_artifacts = @($dependencyTerminal)
+    responsibility_chain_artifacts = @($dependencyChain.Artifacts)
+  }
+  Assert-Equal $dependencyResult.result 'scope-blocked' "A completed dependency with invalid downstream step $chainIndex must not unlock its dependent"
+  Assert-Equal $dependencyResult.work_item_id '' "Invalid downstream dependency step $chainIndex must leave the dependent unselected"
+}
+
 $crossRunAuthorityItem = New-WorkItem 'WORK-ADMIN-CROSS-RUN-AUTHORITY' 1
 $crossRunAuthority = New-QueueResponsibilityArtifact $crossRunAuthorityItem.responsibility_evidence $crossRunAuthorityItem
 $crossRunAuthority.run_id = 'RUN-FOREIGN-999'
 $crossRunAuthorityResult = Invoke-ScopeScenario @{
   scenario_type = 'scope-engine'; operation = 'select'
   work_items = @($crossRunAuthorityItem)
   responsibility_authority_artifacts = @($crossRunAuthority)
 }
 Assert-Equal $crossRunAuthorityResult.result 'scope-blocked' 'Cross-run responsibility authority must not select a work item'
 Assert-Equal $crossRunAuthorityResult.work_item_id '' 'Cross-run queue evidence must leave next eligible item empty'
@@ -1012,31 +1029,37 @@ foreach ($lifecycleMutation in @(
     scenario_type = 'scope-engine'; operation = 'complete-scope'
     work_items = @($completeItem)
     terminal_artifacts = @($lifecycleTerminal)
     responsibility_chain_artifacts = @($lifecycleChain.Artifacts)
     terminal_scope_report = (New-TerminalScopeReport "runs/scope-terminal-lifecycle-$($lifecycleMutation.Name).md" @($completeItem) @($lifecycleChain))
   }
   Assert-Equal $lifecycleCompletion.scope_status 'scope-blocked' "Initial review $($lifecycleMutation.Name) must be approved/complete/human"
 }
 
 foreach ($chainIndex in 1..4) {
-  $downstreamLifecycleChain = New-ResponsibilityChain "runs/downstream-lifecycle-$chainIndex-chain" $completeItem.work_item_id
-  $downstreamLifecycleChain.Artifacts[$chainIndex].status = 'draft'
+ foreach ($lifecycleMutation in @(
+    @{ Name = 'status'; Field = 'status'; Value = 'draft' },
+    @{ Name = 'result'; Field = 'result'; Value = 'partial' },
+    @{ Name = 'approval-source'; Field = 'approval_source'; Value = 'automation' }
+  )) {
+  $downstreamLifecycleChain = New-ResponsibilityChain "runs/downstream-lifecycle-$chainIndex-$($lifecycleMutation.Name)-chain" $completeItem.work_item_id
+  $downstreamLifecycleChain.Artifacts[$chainIndex][$lifecycleMutation.Field] = $lifecycleMutation.Value
   $downstreamLifecycleTerminal = New-TerminalResponsibilityArtifact $completeItem.terminal_evidence $completeItem.work_item_id $completeItem.status $downstreamLifecycleChain.FinalReference $downstreamLifecycleChain.References $downstreamLifecycleChain.ModeConstraint
   $downstreamLifecycleCompletion = Invoke-ScopeScenario @{
     scenario_type = 'scope-engine'; operation = 'complete-scope'
     work_items = @($completeItem)
     terminal_artifacts = @($downstreamLifecycleTerminal)
     responsibility_chain_artifacts = @($downstreamLifecycleChain.Artifacts)
-    terminal_scope_report = (New-TerminalScopeReport "runs/scope-terminal-downstream-lifecycle-$chainIndex.md" @($completeItem) @($downstreamLifecycleChain))
+    terminal_scope_report = (New-TerminalScopeReport "runs/scope-terminal-downstream-lifecycle-$chainIndex-$($lifecycleMutation.Name).md" @($completeItem) @($downstreamLifecycleChain))
   }
-  Assert-Equal $downstreamLifecycleCompletion.scope_status 'scope-blocked' "Every downstream assurance chain node $chainIndex must be approved/complete/human"
+  Assert-Equal $downstreamLifecycleCompletion.scope_status 'scope-blocked' "Every downstream assurance chain node $chainIndex must reject $($lifecycleMutation.Name)"
+ }
 }
 
 $sourceDiffMismatchChain = New-ResponsibilityChain 'runs/source-diff-mismatch-chain' $completeItem.work_item_id
 foreach ($artifact in @($sourceDiffMismatchChain.Artifacts)) {
   $artifact.evidence_reference = "source-diff:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa..bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb#$($completeItem.work_item_id)"
 }
 $sourceDiffMismatchTerminal = New-TerminalResponsibilityArtifact $completeItem.terminal_evidence $completeItem.work_item_id $completeItem.status $sourceDiffMismatchChain.FinalReference $sourceDiffMismatchChain.References $sourceDiffMismatchChain.ModeConstraint
 $sourceDiffMismatchCompletion = Invoke-ScopeScenario @{
   scenario_type = 'scope-engine'; operation = 'complete-scope'
   work_items = @($completeItem)
@@ -1468,20 +1491,43 @@ foreach ($terminalAuthorityCase in @(
     scenario_type = 'scope-engine'; operation = 'transition'; transition = 'successful-terminal-artifact'
     work_item_id = $caseItem.work_item_id; attempt_id = $caseAttempt
     terminal_evidence = $caseTerminalReference; terminal_artifact = $caseTerminal
     responsibility_chain_artifacts = @($caseChain.Artifacts); work_items = @($caseItem)
   }
   Assert-Equal $caseResult.result 'transition-invalid' "Successful transition must reject $($terminalAuthorityCase.Name) terminal responsibility authority"
   Assert-Equal $caseResult.reason 'terminal-responsibility-authority-invalid' "Terminal $($terminalAuthorityCase.Name) responsibility envelope must block completion"
   Assert-Equal $caseResult.scope_status 'scope-blocked' "Terminal $($terminalAuthorityCase.Name) authority must not complete the work item"
 }
 
+foreach ($chainIndex in 1..4) {
+  $caseItem = New-WorkItem "WORK-ADMIN-DOWNSTREAM-TRANSITION-$chainIndex" 1 @() 'in-progress'
+  $caseAttempt = "ATTEMPT-$($caseItem.work_item_id)-01"
+  $caseItem.latest_attempt = $caseAttempt
+  $caseItem.attempt_history = @(
+    @{ attempt_id = $caseAttempt; work_item_id = $caseItem.work_item_id; plan_revision = 3; status = 'in-progress'; artifact_reference = "runs/downstream-transition-$chainIndex-in-progress.md" }
+  )
+  $caseChain = New-ResponsibilityChain "runs/downstream-transition-$chainIndex-chain" $caseItem.work_item_id $caseItem.mode_constraint
+  $caseChain.Artifacts[$chainIndex].status = 'draft'
+  $caseTerminalReference = "runs/downstream-transition-$chainIndex-terminal.md"
+  $caseTerminal = New-TerminalResponsibilityArtifact $caseTerminalReference $caseItem.work_item_id 'complete' $caseChain.FinalReference $caseChain.References $caseChain.ModeConstraint
+  $caseTerminal.attempt_id = $caseAttempt
+  $caseTerminal.result = 'complete'
+  $caseResult = Invoke-ScopeScenario @{
+    scenario_type = 'scope-engine'; operation = 'transition'; transition = 'successful-terminal-artifact'
+    work_item_id = $caseItem.work_item_id; attempt_id = $caseAttempt
+    terminal_evidence = $caseTerminalReference; terminal_artifact = $caseTerminal
+    responsibility_chain_artifacts = @($caseChain.Artifacts); work_items = @($caseItem)
+  }
+  Assert-Equal $caseResult.result 'transition-invalid' "Successful transition must reject non-approved downstream step $chainIndex"
+  Assert-Equal $caseResult.reason 'terminal-responsibility-authority-invalid' "Downstream transition step $chainIndex must fail terminal responsibility authority"
+}
+
 $mismatchedTransitionChain = New-ResponsibilityChain 'runs/mismatched-transition-chain' $transitionCurrent.work_item_id $transitionCurrent.mode_constraint
 $mismatchedTransitionTerminal = New-TerminalResponsibilityArtifact 'runs/current-01.md' $transitionCurrent.work_item_id 'complete' $mismatchedTransitionChain.FinalReference $mismatchedTransitionChain.References $mismatchedTransitionChain.ModeConstraint
 $mismatchedTransitionTerminal.attempt_id = 'ATTEMPT-WORK-ADMIN-OTHER-01'
 $mismatchedTransitionTerminal.result = 'complete'
 $mismatchedTerminalArtifact = Invoke-ScopeScenario @{
   scenario_type = 'scope-engine'
   operation = 'transition'
   current_plan_revision = 3
   transition = 'successful-terminal-artifact'
   work_item_id = 'WORK-ADMIN-CURRENT'
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1
index 5585903..14a8388 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1
@@ -1335,28 +1335,43 @@ function Test-ResponsibilityImplementation {
 
 function Invoke-ArcPinnedGit {
   [CmdletBinding()]
   param([Parameter(Mandatory)][string]$SourceRoot, [Parameter(Mandatory)][string[]]$Arguments)
 
   $output = @(& git -C $SourceRoot @Arguments 2>$null)
   if ($LASTEXITCODE -ne 0) { throw "Pinned source git command failed: git -C $SourceRoot $($Arguments -join ' ')" }
   return ($output -join [Environment]::NewLine).Trim()
 }
 
+function ConvertTo-ArcCanonicalRepositoryPath {
+  [CmdletBinding()]
+  param([Parameter(Mandatory)][AllowEmptyString()][string]$Path)
+
+  if ([string]::IsNullOrWhiteSpace($Path) -or $Path -cne $Path.Trim()) { return '' }
+  $canonicalPath = $Path.Replace('\', '/')
+  if (
+    $canonicalPath -cnotmatch '^(?:[A-Za-z0-9_.-]+/)*[A-Za-z0-9_.-]+$' -or
+    $canonicalPath -match '^(?:/|[A-Za-z]:)' -or
+    @($canonicalPath -split '/' | Where-Object { $_ -cin @('.', '..') }).Count -gt 0
+  ) { return '' }
+  return $canonicalPath
+}
+
 function Test-ArcCanonicalProductionPath {
   [CmdletBinding()]
   param([Parameter(Mandatory)][string]$Path)
 
   # Phase 1 uses repository-relative roots as the language-neutral production
   # classifier. Tests, docs, tooling, generated output, and repository metadata
   # remain non-production unless an approved responsibility selects them.
-  $canonicalPath = $Path.Replace('\', '/')
+  $canonicalPath = ConvertTo-ArcCanonicalRepositoryPath -Path $Path
+  if ($canonicalPath -ceq '') { return $false }
   return $canonicalPath -cmatch '^(?:(?:src|lib|app|apps/[^/]+/(?:src|lib|app)|packages/[^/]+/(?:src|lib|app)|server|client|frontend|backend)/)' -and
     $canonicalPath -cnotmatch '(?:^|/)(?:test|tests|spec|specs|docs?|scripts?|tools?|generated|build|dist)(?:/|$)'
 }
 
 function Get-ArcApprovedReviewDesignRevision {
   [CmdletBinding()]
   param([Parameter(Mandatory)][string]$DesignText, [Parameter(Mandatory)][AllowEmptyCollection()][Collections.Generic.List[string]]$Errors)
 
   $frontMatter = Get-ArcBoundedFrontMatter -Text $DesignText
   $revisionMatches = @([regex]::Matches($frontMatter, '(?m)^revision:\s*(?<value>DESIGN-[A-Z0-9]+(?:-[A-Z0-9]+)*@[1-9][0-9]*)\s*$'))
@@ -1381,20 +1396,26 @@ function Get-ArcImplementationReviewProvenance {
   $table = @(Get-ArcStrictMarkdownTable -Text $ImplementationText -Heading 'Change Hygiene' -Columns $columns -Errors $tableErrors)
   if ($tableErrors.Count -ne 0) {
     foreach ($tableError in $tableErrors) { $Errors.Add($tableError) }
     return $null
   }
   if ($table.Count -lt 3) {
     $Errors.Add('responsibility-evidence-missing')
     return $null
   }
   $rows = @($table | Select-Object -Skip 2)
+  foreach ($row in $rows) {
+    $canonicalPath = ConvertTo-ArcCanonicalRepositoryPath -Path ([string]$row[1]).Trim()
+    if ($canonicalPath -ceq '') { $Errors.Add('responsibility-evidence-missing') }
+    else { $row[1] = $canonicalPath }
+  }
+  if ($Errors.Count -ne 0) { return $null }
   $taskUnits = @($rows | ForEach-Object { $_[0].Trim() } | Sort-Object -Unique)
   $taskBases = @($rows | ForEach-Object { $_[7].Trim() } | Sort-Object -Unique)
   $finalTrees = @($rows | ForEach-Object { $_[8].Trim() } | Sort-Object -Unique)
   if ($taskUnits.Count -ne 1 -or $taskUnits[0] -cnotmatch '^(?:WORK|UNIT)-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -or $taskBases.Count -ne 1 -or $finalTrees.Count -ne 1 -or $taskBases[0] -cnotmatch '^[0-9a-f]{40}$' -or $finalTrees[0] -cnotmatch '^[0-9a-f]{40}$') {
     $Errors.Add('responsibility-evidence-missing')
     return $null
   }
   return [pscustomobject]@{ TaskUnit = $taskUnits[0]; TaskBaseSha = $taskBases[0]; FinalTreeSha = $finalTrees[0]; Rows = $rows }
 }
 
@@ -1410,20 +1431,23 @@ function Test-ArcDeletedSourceEvidence {
 
   $removedDiff = @($DiffText -split '\r?\n' | Where-Object { $_ -cmatch '^-' -and $_ -cnotmatch '^---' }) -join "`n"
   $deletedOwners = [Collections.Generic.List[object]]::new()
   $ownerMatches = @([regex]::Matches($SourceText, '(?ms)^\s*@responsibility\s+(?<id>RESP-[A-Z0-9]+(?:-[A-Z0-9]+)*)\s*$.*?(?=^\s*@responsibility\s+|\z)'))
   foreach ($ownerMatch in $ownerMatches) {
     if ($OwnerIds.Count -gt 0 -and $OwnerIds -cnotcontains $ownerMatch.Groups['id'].Value) { continue }
     $block = $ownerMatch.Value
     $owner = [pscustomobject]@{
       Id = $ownerMatch.Groups['id'].Value
       Path = $Path
+      BasePath = $Path
+      FinalPath = ''
+      RenameMapping = ''
       OwnerSymbols = [Collections.Generic.List[string]]::new()
       Symbols = [Collections.Generic.List[string]]::new()
       Capabilities = [Collections.Generic.List[string]]::new()
       Effects = [Collections.Generic.List[string]]::new()
       ArchitectureAuthorities = [Collections.Generic.List[string]]::new()
       CoLocationPolicies = [Collections.Generic.List[string]]::new()
       VerificationOwners = [Collections.Generic.List[string]]::new()
       RouteSymbols = [Collections.Generic.List[string]]::new()
       Providers = [Collections.Generic.List[string]]::new()
     }
@@ -1467,63 +1491,80 @@ function Get-ArcPinnedSourceInventory {
     [Parameter(Mandatory)][string]$TaskBaseSha,
     [Parameter(Mandatory)][string]$FinalTreeSha,
     [string[]]$SelectedPaths = @(),
     [Parameter(Mandatory)][AllowEmptyCollection()][Collections.Generic.List[string]]$Errors
   )
 
   if (-not (Test-Path -LiteralPath $SourceRoot -PathType Container) -or $TaskBaseSha -cnotmatch '^[0-9a-f]{40}$' -or $FinalTreeSha -cnotmatch '^[0-9a-f]{40}$') {
     $Errors.Add('responsibility-evidence-missing')
     return @()
   }
+  $canonicalSelectedPaths = [Collections.Generic.List[string]]::new()
+  foreach ($selectedPath in $SelectedPaths) {
+    $canonicalSelectedPath = ConvertTo-ArcCanonicalRepositoryPath -Path ([string]$selectedPath).Trim()
+    if ($canonicalSelectedPath -ceq '') { $Errors.Add('responsibility-evidence-missing') }
+    else { $canonicalSelectedPaths.Add($canonicalSelectedPath) }
+  }
+  if ($Errors.Count -ne 0) { return @() }
+  $SelectedPaths = @($canonicalSelectedPaths)
   try {
     if ((Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('rev-parse', "$TaskBaseSha^{commit}")) -cne $TaskBaseSha -or (Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('rev-parse', "$FinalTreeSha^{commit}")) -cne $FinalTreeSha) {
       $Errors.Add('responsibility-evidence-missing')
       return @()
     }
     $nameStatusLines = @((Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('diff', '--name-status', '--find-renames', '--find-copies-harder', '--diff-filter=ACMRD', $TaskBaseSha, $FinalTreeSha, '--')) -split '\r?\n' | Where-Object { $_ -ne '' })
-    $finalTreePaths = @((Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('ls-tree', '-r', '--name-only', $FinalTreeSha)) -split '\r?\n' | Where-Object { $_ -ne '' })
+    $finalTreePaths = @((Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('ls-tree', '-r', '--name-only', $FinalTreeSha)) -split '\r?\n' | Where-Object { $_ -ne '' } | ForEach-Object { ConvertTo-ArcCanonicalRepositoryPath -Path $_ })
   }
   catch {
     $Errors.Add('responsibility-evidence-missing')
     return @()
   }
   $changedPathRecords = [Collections.Generic.List[object]]::new()
   foreach ($line in $nameStatusLines) {
     $fields = @($line -split "`t")
     $status = if ($fields.Count -gt 0) { $fields[0] } else { '' }
     if ($status -cnotmatch '^(?:[AMDC]|R[0-9]{1,3}|C[0-9]{1,3})$') {
       $Errors.Add('responsibility-evidence-missing')
       continue
     }
     $kind = $status.Substring(0, 1)
     if (($kind -cin @('R', 'C') -and $fields.Count -ne 3) -or ($kind -cnotin @('R', 'C') -and $fields.Count -ne 2)) {
       $Errors.Add('responsibility-evidence-missing')
       continue
     }
-    $basePath = if ($kind -cin @('R', 'C')) { $fields[1] } elseif ($kind -ceq 'A') { '' } else { $fields[1] }
-    $finalPath = if ($kind -cin @('R', 'C')) { $fields[2] } elseif ($kind -ceq 'D') { '' } else { $fields[1] }
+    $rawBasePath = if ($kind -cin @('R', 'C')) { $fields[1] } elseif ($kind -ceq 'A') { '' } else { $fields[1] }
+    $rawFinalPath = if ($kind -cin @('R', 'C')) { $fields[2] } elseif ($kind -ceq 'D') { '' } else { $fields[1] }
+    $basePath = if ($rawBasePath -ceq '') { '' } else { ConvertTo-ArcCanonicalRepositoryPath -Path $rawBasePath }
+    $finalPath = if ($rawFinalPath -ceq '') { '' } else { ConvertTo-ArcCanonicalRepositoryPath -Path $rawFinalPath }
+    if (($rawBasePath -ne '' -and $basePath -ceq '') -or ($rawFinalPath -ne '' -and $finalPath -ceq '')) {
+      $Errors.Add('responsibility-evidence-missing')
+      continue
+    }
     $path = if ($kind -ceq 'D') { $basePath } else { $finalPath }
     $changedPathRecords.Add([pscustomobject]@{
       Status = $kind
       RawStatus = $status
       BasePath = $basePath
       FinalPath = $finalPath
       Path = $path
+      RenameMapping = if ($kind -ceq 'R') { "$basePath->$finalPath" } else { '' }
       FileKind = if ($kind -ceq 'A' -or $kind -ceq 'C') { 'new' } elseif ($kind -ceq 'D') { 'deleted' } else { 'existing' }
-      IsProduction = (Test-ArcCanonicalProductionPath -Path $path)
+      IsBaseProduction = (-not [string]::IsNullOrWhiteSpace($basePath) -and (Test-ArcCanonicalProductionPath -Path $basePath))
+      IsFinalProduction = (-not [string]::IsNullOrWhiteSpace($finalPath) -and (Test-ArcCanonicalProductionPath -Path $finalPath))
+      IsProduction = ((-not [string]::IsNullOrWhiteSpace($basePath) -and (Test-ArcCanonicalProductionPath -Path $basePath)) -or (-not [string]::IsNullOrWhiteSpace($finalPath) -and (Test-ArcCanonicalProductionPath -Path $finalPath)))
     })
   }
-  $changedFinalPaths = @($changedPathRecords | Where-Object { $_.Status -cne 'D' } | ForEach-Object { $_.FinalPath })
-  $deletedPaths = @($changedPathRecords | Where-Object { $_.Status -ceq 'D' } | ForEach-Object { $_.BasePath })
+  $changedFinalPaths = @($changedPathRecords | Where-Object { $_.Status -cne 'D' -and $_.IsProduction } | ForEach-Object { $_.FinalPath })
+  $deletedPaths = @($changedPathRecords | Where-Object { $_.Status -ceq 'D' -and ($_.IsProduction -or $SelectedPaths -ccontains $_.BasePath) } | ForEach-Object { $_.BasePath })
   $allChangedPaths = @($changedPathRecords | ForEach-Object { $_.Path })
   $allRequestedPaths = @($allChangedPaths + $SelectedPaths)
-  if ($allChangedPaths.Count -eq 0 -or @($allRequestedPaths | Where-Object { $_ -match '^(?:/|[A-Za-z]:|.*(?:^|/)\.\.(?:/|$))' }).Count -gt 0) {
+  if ($allChangedPaths.Count -eq 0 -or @($allRequestedPaths | Where-Object { (ConvertTo-ArcCanonicalRepositoryPath -Path $_) -ceq '' }).Count -gt 0) {
     $Errors.Add('responsibility-evidence-missing')
     return @()
   }
   $selectedFinalPaths = @($SelectedPaths | Where-Object { $finalTreePaths -ccontains $_ })
   $finalPaths = @($changedFinalPaths + $selectedFinalPaths | Select-Object -Unique)
 
   $deletedInventory = [Collections.Generic.List[object]]::new()
   foreach ($path in $deletedPaths) {
     try {
       $deletedSourceText = Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('show', "${TaskBaseSha}:$path")
@@ -1554,20 +1595,23 @@ function Get-ArcPinnedSourceInventory {
       continue
     }
     $current = $null
     foreach ($line in @($sourceText -split '\r?\n')) {
       $ownerMatch = [regex]::Match($line, '^\s*@responsibility\s+(?<id>RESP-[A-Z0-9]+(?:-[A-Z0-9]+)*)\s*$')
       if ($ownerMatch.Success) {
         if ($null -ne $current) { $inventory.Add($current) }
         $current = [pscustomobject]@{
           Id = $ownerMatch.Groups['id'].Value
           Path = $path
+          BasePath = if ($null -ne $pathRecord) { [string]$pathRecord.BasePath } else { $path }
+          FinalPath = $path
+          RenameMapping = if ($null -ne $pathRecord) { [string]$pathRecord.RenameMapping } else { '' }
           IsChanged = ($null -ne $pathRecord)
           OwnerSymbols = [Collections.Generic.List[string]]::new()
           Symbols = [Collections.Generic.List[string]]::new()
           Capabilities = [Collections.Generic.List[string]]::new()
           Effects = [Collections.Generic.List[string]]::new()
           ArchitectureAuthorities = [Collections.Generic.List[string]]::new()
           CoLocationPolicies = [Collections.Generic.List[string]]::new()
           VerificationOwners = [Collections.Generic.List[string]]::new()
           RouteSymbols = [Collections.Generic.List[string]]::new()
           Providers = [Collections.Generic.List[string]]::new()
@@ -1590,20 +1634,24 @@ function Get-ArcPinnedSourceInventory {
       $verificationMatch = [regex]::Match($line, '^\s*@verification-owner\s+(?<id>VERIFY-OWNER-[A-Z0-9]+(?:-[A-Z0-9]+)*)\s*$')
       if ($verificationMatch.Success) { $current.VerificationOwners.Add($verificationMatch.Groups['id'].Value); continue }
       $routeMatch = [regex]::Match($line, '^\s*route\s+(?<symbol>[A-Za-z][A-Za-z0-9_.:-]*)\s*->\s*(?<provider>[A-Za-z][A-Za-z0-9_.:-]*)\s*$')
       if ($routeMatch.Success) {
         $current.RouteSymbols.Add($routeMatch.Groups['symbol'].Value)
         $current.Providers.Add($routeMatch.Groups['provider'].Value)
         if (-not $current.Effects.Contains('route registration')) { $current.Effects.Add('route registration') }
       }
     }
     if ($null -ne $current) { $inventory.Add($current) }
+    $allRouteCount = @([regex]::Matches($sourceText, '(?m)^\s*route\s+[A-Za-z][A-Za-z0-9_.:-]*\s*->\s*[A-Za-z][A-Za-z0-9_.:-]*\s*$')).Count
+    $ownedRouteCount = @($inventory | Where-Object { $_.Path -ceq $path } | ForEach-Object { $_.RouteSymbols.Count } | Measure-Object -Sum).Sum
+    if ($null -eq $ownedRouteCount) { $ownedRouteCount = 0 }
+    if ($allRouteCount -ne $ownedRouteCount) { $Errors.Add('responsibility-evidence-missing') }
     foreach ($owner in @($inventory | Where-Object { $_.Path -ceq $path })) {
       if ($null -ne $pathRecord -and $pathRecord.Status -cin @('M', 'R') -and $baseSourceText -ne '') {
         $ownerPattern = '(?ms)^\s*@responsibility\s+' + [regex]::Escape($owner.Id) + '\s*$.*?(?=^\s*@responsibility\s+|\z)'
         $baseOwnerBlock = [regex]::Match($baseSourceText, $ownerPattern)
         $finalOwnerBlock = [regex]::Match($sourceText, $ownerPattern)
         $owner.IsChanged = -not ($baseOwnerBlock.Success -and $finalOwnerBlock.Success -and $baseOwnerBlock.Value.Trim() -ceq $finalOwnerBlock.Value.Trim())
       }
       $requiresRouteEvidence = $owner.Effects -ccontains 'route registration'
       $addedDiff = @($diffText -split '\r?\n' | Where-Object { $_ -cmatch '^\+' -and $_ -cnotmatch '^\+\+\+' }) -join "`n"
       $ownerAnchors = @($owner.OwnerSymbols + $owner.Symbols + $owner.Capabilities + $owner.VerificationOwners + $owner.RouteSymbols + $owner.Providers | Select-Object -Unique)
@@ -1611,50 +1659,53 @@ function Get-ArcPinnedSourceInventory {
       if ($owner.OwnerSymbols.Count -eq 0 -or $owner.Symbols.Count -eq 0 -or $owner.Capabilities.Count -eq 0 -or $owner.ArchitectureAuthorities.Count -eq 0 -or $owner.CoLocationPolicies.Count -eq 0 -or $owner.VerificationOwners.Count -eq 0 -or ($owner.IsChanged -and -not $hasChangedOwnerAnchor) -or ($requiresRouteEvidence -and ($owner.RouteSymbols.Count -eq 0 -or $owner.Providers.Count -eq 0 -or @($owner.Symbols | Where-Object { $owner.RouteSymbols -cnotcontains $_ }).Count -gt 0))) {
         $Errors.Add('responsibility-evidence-missing')
       }
     }
   }
 
   # A responsibility block removed from an M/R production file is deletion,
   # even though the file itself survives. Compare immutable pinned contents and
   # feed only the removed owners through the same deletion reconciliation used
   # for a whole-file D change.
-  foreach ($record in @($changedPathRecords | Where-Object { $_.Status -cin @('M', 'R') -and $_.BasePath -ne '' -and $_.FinalPath -ne '' })) {
+  foreach ($record in @($changedPathRecords | Where-Object { $_.Status -cin @('M', 'R') -and ($_.IsProduction -or $SelectedPaths -ccontains $_.FinalPath) -and $_.BasePath -ne '' -and $_.FinalPath -ne '' })) {
     try {
       $baseText = Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('show', "${TaskBaseSha}:$($record.BasePath)")
       $finalText = Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('show', "${FinalTreeSha}:$($record.FinalPath)")
       $removedOwnerIds = @([regex]::Matches($baseText, '(?m)^\s*@responsibility\s+(?<id>RESP-[A-Z0-9]+(?:-[A-Z0-9]+)*)\s*$') | ForEach-Object { $_.Groups['id'].Value } | Where-Object {
         $ownerId = $_
         @([regex]::Matches($finalText, '(?m)^\s*@responsibility\s+(?<id>RESP-[A-Z0-9]+(?:-[A-Z0-9]+)*)\s*$') | ForEach-Object { $_.Groups['id'].Value }) -cnotcontains $ownerId
       })
       if ($removedOwnerIds.Count -gt 0) {
         $removalDiff = Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('diff', '--unified=0', $TaskBaseSha, $FinalTreeSha, '--', $record.BasePath, $record.FinalPath)
-        foreach ($owner in @(Test-ArcDeletedSourceEvidence -Path $record.Path -SourceText $baseText -DiffText $removalDiff -OwnerIds $removedOwnerIds -Errors $Errors)) {
+        foreach ($owner in @(Test-ArcDeletedSourceEvidence -Path $record.BasePath -SourceText $baseText -DiffText $removalDiff -OwnerIds $removedOwnerIds -Errors $Errors)) {
+          $owner.BasePath = $record.BasePath
+          $owner.FinalPath = $record.FinalPath
+          $owner.RenameMapping = $record.RenameMapping
           $deletedInventory.Add($owner)
         }
       }
     }
     catch {
       $Errors.Add('responsibility-evidence-missing')
     }
   }
 
   # Marker presence never defines the inventory boundary. Canonically
   # production-classified changed paths must expose at least one active or
   # deleted responsibility after the pinned base/final comparison.
   foreach ($record in @($changedPathRecords | Where-Object { $_.IsProduction })) {
     $hasOwner = if ($record.Status -ceq 'D') {
       @($deletedInventory | Where-Object { $_.Path -ceq $record.Path }).Count -gt 0
     }
     else {
       @($inventory | Where-Object { $_.Path -ceq $record.FinalPath }).Count -gt 0 -or
-        @($deletedInventory | Where-Object { $_.Path -ceq $record.Path }).Count -gt 0
+        @($deletedInventory | Where-Object { $_.Path -ceq $record.BasePath }).Count -gt 0
     }
     if (-not $hasOwner) { $Errors.Add('responsibility-evidence-missing') }
   }
   return [pscustomobject]@{
     ActiveOwners = $inventory.ToArray()
     DeletedOwners = $deletedInventory.ToArray()
     ChangedPaths = $changedPathRecords.ToArray()
   }
 }
 
@@ -1894,20 +1945,52 @@ function Test-ResponsibilityReview {
 
   $toRow = { param([object]$Cells, [string[]]$Columns) $row = @{}; for ($index = 0; $index -lt $Columns.Count; $index++) { $row[$Columns[$index]] = [string]$Cells[$index] }; return $row }
   $splitList = { param([string]$Value) @($Value -split '[,;]' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }) }
   $validVerdicts = @(Get-ArcContractEnumValues -ContractText $ContractText -Name 'Verdict')
   $allPlannedResponsibilities = @($plannedResponsibilityTable | Select-Object -Skip 2 | ForEach-Object { & $toRow $_ $responsibilityColumns })
   $allPlannedVerifications = @($plannedVerificationTable | Select-Object -Skip 2 | ForEach-Object { & $toRow $_ $verificationColumns })
   $implementationResponsibilities = @($implementationResponsibilityTable | Select-Object -Skip 2 | ForEach-Object { & $toRow $_ $actualResponsibilityColumns })
   $implementationVerifications = @($implementationVerificationTable | Select-Object -Skip 2 | ForEach-Object { & $toRow $_ $actualVerificationColumns })
   $ownerReferenceRows = @($ownerReferenceTable | Select-Object -Skip 2 | ForEach-Object { & $toRow $_ $ownerReferenceColumns })
   $reviewRows = @($reviewEvidenceTable | Select-Object -Skip 2 | ForEach-Object { & $toRow $_ $reviewColumns })
+  foreach ($ownerRow in @($allPlannedResponsibilities + $implementationResponsibilities)) {
+    $canonicalOwnerPath = ConvertTo-ArcCanonicalRepositoryPath -Path $ownerRow['Owner Path']
+    if ($canonicalOwnerPath -ceq '') { $errors.Add('responsibility-evidence-missing') }
+    else { $ownerRow['Owner Path'] = $canonicalOwnerPath }
+  }
+  foreach ($verificationRow in @($allPlannedVerifications + $implementationVerifications)) {
+    $canonicalEvidencePath = ConvertTo-ArcCanonicalRepositoryPath -Path $verificationRow['Evidence Path']
+    $bindingMatch = [regex]::Match($verificationRow['Production Binding Evidence'], '^invokes\s+(?<path>[^#]+)#(?<symbol>[A-Za-z][A-Za-z0-9_.:-]*)$')
+    $canonicalBindingPath = if ($bindingMatch.Success) { ConvertTo-ArcCanonicalRepositoryPath -Path $bindingMatch.Groups['path'].Value } else { '' }
+    if ($canonicalEvidencePath -ceq '' -or $canonicalBindingPath -ceq '') { $errors.Add('responsibility-evidence-missing') }
+    else {
+      $verificationRow['Evidence Path'] = $canonicalEvidencePath
+      $verificationRow['Production Binding Evidence'] = "invokes $canonicalBindingPath#$($bindingMatch.Groups['symbol'].Value)"
+    }
+  }
+  foreach ($reviewRow in $reviewRows) {
+    $canonicalEvidenceItems = [Collections.Generic.List[string]]::new()
+    foreach ($evidenceItem in @($reviewRow['Source/Diff Evidence'] -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })) {
+      $evidenceMatch = [regex]::Match($evidenceItem, '^(?<prefix>source:[0-9a-f]{40}:|diff:[0-9a-f]{40}\.\.[0-9a-f]{40}:)(?<paths>[^#]+)#(?<anchor>[A-Za-z][A-Za-z0-9_.:-]*)$')
+      if (-not $evidenceMatch.Success) { $errors.Add('responsibility-evidence-missing'); continue }
+      $canonicalPaths = [Collections.Generic.List[string]]::new()
+      foreach ($evidencePath in @($evidenceMatch.Groups['paths'].Value -split '->')) {
+        $canonicalEvidencePath = ConvertTo-ArcCanonicalRepositoryPath -Path $evidencePath
+        if ($canonicalEvidencePath -ceq '') { $errors.Add('responsibility-evidence-missing') }
+        else { $canonicalPaths.Add($canonicalEvidencePath) }
+      }
+      if ($canonicalPaths.Count -notin @(1, 2)) { $errors.Add('responsibility-evidence-missing'); continue }
+      $canonicalEvidenceItems.Add("$($evidenceMatch.Groups['prefix'].Value)$($canonicalPaths -join '->')#$($evidenceMatch.Groups['anchor'].Value)")
+    }
+    $reviewRow['Source/Diff Evidence'] = $canonicalEvidenceItems -join '; '
+  }
+  if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }
   $toMap = { param([object[]]$Rows, [string]$IdColumn, [string]$DuplicateDiagnostic) $map = @{}; foreach ($row in $Rows) { $id = $row[$IdColumn]; if ($map.ContainsKey($id)) { $errors.Add($DuplicateDiagnostic) } else { $map[$id] = $row } }; return $map }
   $allPlannedById = & $toMap $allPlannedResponsibilities 'Responsibility ID' 'responsibility-owner-extra'
   $referencedOwnerIds = @()
   if ($ownerReferenceRows.Count -ne 1 -or $ownerReferenceRows[0]['Design Revision'] -cne $designRevision) {
     $errors.Add('responsibility-owner-extra')
   }
   else {
     foreach ($field in @('Responsibility IDs', 'Shared Foundation IDs', 'Integration Responsibility IDs')) {
       if ($ownerReferenceRows[0][$field] -cne 'not-applicable') { $referencedOwnerIds += @(& $splitList $ownerReferenceRows[0][$field]) }
     }
@@ -1928,31 +2011,44 @@ function Test-ResponsibilityReview {
     return @($errors | Select-Object -Unique)
   }
   $selectedPaths = @($plannedResponsibilities | ForEach-Object { $_['Owner Path'] } | Select-Object -Unique)
   $sourceInventory = Get-ArcPinnedSourceInventory -SourceRoot $SourceRoot -TaskBaseSha $implementationProvenance.TaskBaseSha -FinalTreeSha $implementationProvenance.FinalTreeSha -SelectedPaths $selectedPaths -Errors $errors
   if ($errors.Count -ne 0 -or $null -eq $sourceInventory) { return @($errors | Select-Object -Unique) }
   $inventory = @($sourceInventory.ActiveOwners)
   $deletedInventory = @($sourceInventory.DeletedOwners)
   $changedPathRecords = @($sourceInventory.ChangedPaths)
   foreach ($record in $changedPathRecords) {
     $matchingHygieneRows = @($implementationProvenance.Rows | Where-Object { $_[1] -ceq $record.Path -and $_[2] -ceq $record.FileKind })
-    if ($matchingHygieneRows.Count -eq 0) { $errors.Add('responsibility-evidence-missing') }
+    if ($matchingHygieneRows.Count -ne 1) {
+      $errors.Add('responsibility-evidence-missing')
+      continue
+    }
+    $expectedCheckpoint = if ($record.Status -ceq 'D') {
+      "source:${TaskBaseSha}:$($record.BasePath); diff:${TaskBaseSha}..${FinalTreeSha}:$($record.BasePath)"
+    }
+    elseif ($record.Status -ceq 'R') {
+      "source:${TaskBaseSha}:$($record.BasePath); diff:${TaskBaseSha}..${FinalTreeSha}:$($record.RenameMapping)"
+    }
+    else { '' }
+    if ($expectedCheckpoint -ne '' -and [string]$matchingHygieneRows[0][6] -cne $expectedCheckpoint) {
+      $errors.Add('responsibility-evidence-missing')
+    }
   }
   foreach ($row in $implementationProvenance.Rows) {
     $path = $row[1].Trim()
     $fileKind = $row[2].Trim()
     $matchingChanges = @($changedPathRecords | Where-Object { $_.Path -ceq $path -and $_.FileKind -ceq $fileKind })
     if (
       $path -cnotmatch '^(?:[A-Za-z0-9_.-]+/)*[A-Za-z0-9_.-]+$' -or
       $path -match '^(?:/|[A-Za-z]:|.*(?:^|/)\.\.(?:/|$))' -or
       $fileKind -cnotin @('new', 'existing', 'deleted') -or
-      $matchingChanges.Count -eq 0
+      $matchingChanges.Count -ne 1
     ) {
       $errors.Add('responsibility-evidence-missing')
     }
   }
   if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }
   if (($inventory.Count + $deletedInventory.Count) -eq 0) { $errors.Add('responsibility-evidence-missing'); return @($errors | Select-Object -Unique) }
 
   $plannedById = & $toMap $plannedResponsibilities 'Responsibility ID' 'responsibility-owner-extra'
   $implementationById = & $toMap $implementationResponsibilities 'Responsibility ID' 'responsibility-owner-extra'
   $reviewById = & $toMap $reviewRows 'Responsibility ID' 'responsibility-owner-extra'
@@ -1988,35 +2084,37 @@ function Test-ResponsibilityReview {
     if (-not (Test-ArcExactSet -Actual $sourceCapabilities -Expected $plannedCapabilities)) { $errors.Add('responsibility-capability-mismatch'); $responsibilityPass = $false }
     if (-not (Test-ArcExactSet -Actual $sourceEffects -Expected $plannedEffects)) { $errors.Add('responsibility-external-effect-mismatch'); $responsibilityPass = $false }
     if (-not (Test-ArcExactSet -Actual $sourceAuthorities -Expected $plannedAuthorities) -or -not (Test-ArcExactSet -Actual $sourceCoLocationPolicies -Expected $plannedCoLocationPolicies)) { $errors.Add('co-location-policy-invalid'); $responsibilityPass = $false }
     if (-not (Test-ArcExactSet -Actual $sourceVerificationOwners -Expected $plannedVerificationOwners)) { $errors.Add('verification-owner-missing'); $verificationPass = $false }
     if (-not (Test-ArcExactSet -Actual @(& $splitList $review['Planned Public Symbols']) -Expected $plannedSymbols) -or -not (Test-ArcExactSet -Actual @(& $splitList $review['Actual Public Symbols']) -Expected $sourceSymbols)) { $errors.Add('responsibility-public-symbol-mismatch'); $responsibilityPass = $false }
     if ($review['Planned Effects'] -cne $planned['External Effects'] -or $review['Actual Effects'] -cne ($sourceEffects -join '; ')) { $errors.Add('responsibility-external-effect-mismatch'); $responsibilityPass = $false }
     $evidenceItems = @($review['Source/Diff Evidence'] -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
     $expectedAnchors = @($sourceSymbols + $sourceVerificationOwners)
     foreach ($anchor in $expectedAnchors) {
       $expectedSource = "source:${FinalTreeSha}:$($actualSource.Path)#$anchor"
-      $expectedDiff = "diff:${TaskBaseSha}..${FinalTreeSha}:$($actualSource.Path)#$anchor"
-      $hasAnyDiffForUnchangedAnchor = -not $actualSource.IsChanged -and @($evidenceItems | Where-Object {
-        $_ -cmatch ('^diff:[0-9a-f]{40}\.\.[0-9a-f]{40}:' + [regex]::Escape($actualSource.Path) + '#' + [regex]::Escape($anchor) + '$')
+      $diffPath = if (-not [string]::IsNullOrWhiteSpace([string]$actualSource.RenameMapping)) { [string]$actualSource.RenameMapping } else { [string]$actualSource.Path }
+      $expectedDiff = "diff:${TaskBaseSha}..${FinalTreeSha}:$diffPath#$anchor"
+      $requiresDiff = [bool]$actualSource.IsChanged -or -not [string]::IsNullOrWhiteSpace([string]$actualSource.RenameMapping)
+      $hasAnyDiffForUnchangedAnchor = -not $requiresDiff -and @($evidenceItems | Where-Object {
+        $_ -cmatch ('^diff:[0-9a-f]{40}\.\.[0-9a-f]{40}:' + [regex]::Escape($diffPath) + '#' + [regex]::Escape($anchor) + '$')
       }).Count -gt 0
       $evidenceInvalid = $evidenceItems -cnotcontains $expectedSource -or
-        ($actualSource.IsChanged -and $evidenceItems -cnotcontains $expectedDiff) -or
+        ($requiresDiff -and $evidenceItems -cnotcontains $expectedDiff) -or
         $hasAnyDiffForUnchangedAnchor
       if ($evidenceInvalid) {
         $errors.Add('responsibility-evidence-missing')
         if ($evidenceItems -cnotcontains $expectedSource -or $sourceVerificationOwners -ccontains $anchor) { $errors.Add('verification-production-binding-missing') }
         $treePass = $false; $verificationPass = $false
       }
     }
     foreach ($evidence in $evidenceItems) {
-      if ($evidence -cnotmatch '^(?:source:[0-9a-f]{40}:[^#;\r\n]+#[A-Za-z][A-Za-z0-9_.:-]*|diff:[0-9a-f]{40}\.\.[0-9a-f]{40}:[^#;\r\n]+#[A-Za-z][A-Za-z0-9_.:-]*)$') { $errors.Add('responsibility-evidence-missing'); $treePass = $false; $verificationPass = $false }
+      if ($evidence -cnotmatch '^(?:source:[0-9a-f]{40}:[^#;\r\n>-]+#[A-Za-z][A-Za-z0-9_.:-]*|diff:[0-9a-f]{40}\.\.[0-9a-f]{40}:[^#;\r\n>-]+(?:->[^#;\r\n>-]+)?#[A-Za-z][A-Za-z0-9_.:-]*)$') { $errors.Add('responsibility-evidence-missing'); $treePass = $false; $verificationPass = $false }
     }
     $rowPass = (Test-ArcExactSet -Actual @(& $splitList $review['Actual Public Symbols']) -Expected $sourceSymbols) -and $review['Actual Effects'] -ceq ($sourceEffects -join '; ')
     $expectedRowVerdict = if ($rowPass) { 'PASS' } else { 'BLOCKED' }
     if ($review['Verdict'] -cne $expectedRowVerdict) { $errors.Add('responsibility-waiver-forbidden'); $responsibilityPass = $false }
   }
   if ($deletedById.Count -gt 0) {
     $deviationColumns = @('Deviation Reference', 'Concern', 'Conflict Reference', 'Resolved Decision', 'Tech Lead Approval')
     $deviationTable = @(Get-ArcStrictMarkdownTable -Text $DesignText -Heading 'Approved Structural Deviations' -Columns $deviationColumns -Errors $errors)
     $deviationRows = if ($deviationTable.Count -ge 3) { @($deviationTable | Select-Object -Skip 2 | ForEach-Object { & $toRow $_ $deviationColumns }) } else { @() }
     $joinDeletionValues = { param([object]$Values) $items = @($Values | Select-Object -Unique); if ($items.Count -eq 0) { return 'not-applicable' }; return ($items -join ',') }
@@ -2039,28 +2137,33 @@ function Test-ResponsibilityReview {
         $_['Tech Lead Approval'] -cmatch '^approval:TECH-LEAD-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -and
         -not [string]::IsNullOrWhiteSpace($_['Concern']) -and
         $decisionMatch.Success -and
         $decisionMatch.Groups['payload'].Value -ceq $expectedDecisionPayload
       })
       if ($approvedRows.Count -ne 1) {
         $errors.Add('responsibility-owner-extra')
         $treePass = $false; $responsibilityPass = $false
       }
 
-      $changedRecord = @($changedPathRecords | Where-Object { $_.Path -ceq $deleted.Path }) | Select-Object -First 1
+      $changedRecord = @($changedPathRecords | Where-Object { $_.BasePath -ceq $deleted.Path }) | Select-Object -First 1
       $expectedFileKind = if ($null -eq $changedRecord) { '' } else { $changedRecord.FileKind }
+      $hygienePath = if ($null -eq $changedRecord) { $deleted.Path } else { $changedRecord.Path }
+      $expectedDeletionCheckpoint = if ($null -ne $changedRecord -and $changedRecord.Status -ceq 'R') {
+        "source:${TaskBaseSha}:$($deleted.Path); diff:${TaskBaseSha}..${FinalTreeSha}:$($changedRecord.RenameMapping)"
+      }
+      else { "source:${TaskBaseSha}:$($deleted.Path); diff:${TaskBaseSha}..${FinalTreeSha}:$($deleted.Path)" }
       $hygieneRows = @($implementationProvenance.Rows | Where-Object {
         $editedSymbols = @($_[3] -split '[;,]' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
-        $_[1] -ceq $deleted.Path -and
+        $_[1] -ceq $hygienePath -and
         $_[2] -ceq $expectedFileKind -and
         $editedSymbols -ccontains $ownerSymbols -and
-        $_[6] -ceq "source:${TaskBaseSha}:$($deleted.Path); diff:${TaskBaseSha}..${FinalTreeSha}:$($deleted.Path)" -and
+        $_[6] -ceq $expectedDeletionCheckpoint -and
         $_[7] -ceq $TaskBaseSha -and
         $_[8] -ceq $FinalTreeSha
       })
       if ($hygieneRows.Count -ne 1) {
         $errors.Add('responsibility-evidence-missing')
         $treePass = $false; $responsibilityPass = $false
       }
 
       if (-not $reviewById.ContainsKey($id)) {
         $errors.Add('responsibility-evidence-missing')
@@ -2071,23 +2174,24 @@ function Test-ResponsibilityReview {
       if ($review['Planned Public Symbols'] -cne (@($deleted.Symbols | Select-Object -Unique) -join '; ') -or $review['Actual Public Symbols'] -cne 'removed') {
         $errors.Add('responsibility-public-symbol-mismatch')
         $responsibilityPass = $false
       }
       if ($review['Planned Effects'] -cne (@($deleted.Effects | Select-Object -Unique) -join '; ') -or $review['Actual Effects'] -cne 'removed') {
         $errors.Add('responsibility-external-effect-mismatch')
         $responsibilityPass = $false
       }
       $evidenceItems = @($review['Source/Diff Evidence'] -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
       $expectedEvidence = [Collections.Generic.List[string]]::new()
+      $deletedDiffPath = if (-not [string]::IsNullOrWhiteSpace([string]$deleted.RenameMapping)) { [string]$deleted.RenameMapping } else { [string]$deleted.Path }
       foreach ($anchor in @($deleted.Symbols + $deleted.VerificationOwners | Select-Object -Unique)) {
         $expectedEvidence.Add("source:${TaskBaseSha}:$($deleted.Path)#$anchor")
-        $expectedEvidence.Add("diff:${TaskBaseSha}..${FinalTreeSha}:$($deleted.Path)#$anchor")
+        $expectedEvidence.Add("diff:${TaskBaseSha}..${FinalTreeSha}:$deletedDiffPath#$anchor")
       }
       if (-not (Test-ArcExactSet -Actual $evidenceItems -Expected $expectedEvidence.ToArray())) {
         $errors.Add('responsibility-evidence-missing')
         $treePass = $false; $verificationPass = $false
       }
       if ($review['Verdict'] -cne 'PASS') {
         $errors.Add('responsibility-waiver-forbidden')
         $responsibilityPass = $false
       }
     }
@@ -2174,27 +2278,42 @@ function Test-ResponsibilityHandoff {
     $artifact.Row = $row
     $artifact.Provenance = $provenance
     $artifact.Scope = $scope
     $frontMatter = Get-ArcBoundedFrontMatter -Text $Text
     $stepIds = @([regex]::Matches($frontMatter, '(?m)^step_id:\s*(?<value>[^\r\n]+)\s*$'))
     if ($stepIds.Count -ne 1) {
       $errors.Add('responsibility-evidence-missing')
       return $artifact
     }
     $artifact.StepId = $stepIds[0].Groups['value'].Value.Trim()
-    $topLevelKeys = @([regex]::Matches($frontMatter, '(?m)^(?<key>[a-z_][a-z0-9_]*):') | ForEach-Object { $_.Groups['key'].Value } | Sort-Object)
-    if ($artifact.StepId -cin @('11-ai-review', '12-verification-testing', '13-verify-parity', '14-verify-regression', '15-knowledge-base') -and (
-      ($topLevelKeys -join '|') -cne 'approval_source|produced_at|responsibility_contract|result|status|step_id' -or
+    $canonicalStepIds = @('11-ai-review', '12-verification-testing', '13-verify-parity', '14-verify-regression', '15-knowledge-base')
+    if ($artifact.StepId -cnotin $canonicalStepIds) {
+      $errors.Add('responsibility-evidence-missing')
+      return $artifact
+    }
+    $topLevelKeys = @([regex]::Matches($frontMatter, '(?m)^(?!#)(?<key>[^ \t:\r\n][^:\r\n]*):') | ForEach-Object { $_.Groups['key'].Value })
+    $producedAtMatches = @([regex]::Matches($frontMatter, '(?m)^produced_at:\s*(?<value>[^\r\n]+?)\s*$'))
+    $parsedProducedAt = [datetime]::MinValue
+    $producedAtValid = $producedAtMatches.Count -eq 1 -and [datetime]::TryParseExact(
+      $producedAtMatches[0].Groups['value'].Value.Trim(),
+      'yyyy-MM-dd',
+      [Globalization.CultureInfo]::InvariantCulture,
+      [Globalization.DateTimeStyles]::None,
+      [ref]$parsedProducedAt
+    )
+    if (
+      ($topLevelKeys -join '|') -cne 'step_id|status|result|approval_source|produced_at|responsibility_contract' -or
       @([regex]::Matches($frontMatter, '(?m)^status:\s*approved\s*$')).Count -ne 1 -or
       @([regex]::Matches($frontMatter, '(?m)^result:\s*complete\s*$')).Count -ne 1 -or
-      @([regex]::Matches($frontMatter, '(?m)^approval_source:\s*human\s*$')).Count -ne 1
-    )) { $errors.Add('responsibility-evidence-missing') }
+      @([regex]::Matches($frontMatter, '(?m)^approval_source:\s*human\s*$')).Count -ne 1 -or
+      -not $producedAtValid
+    ) { $errors.Add('responsibility-evidence-missing') }
 
     $visibleText = Get-ArcVisibleMarkdownText -Text $Text
     if ($artifact.StepId -ceq '11-ai-review') {
       $reviewVerdictMatches = @([regex]::Matches($visibleText, '(?im)^[ \t]*-[ \t]*(?:\*\*)?Verdict(?:\*\*)?:[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$'))
       $criticalCountMatches = @([regex]::Matches($visibleText, '(?im)^[ \t]*-[ \t]*(?:\*\*)?Critical count:(?:\*\*)?[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$'))
       if (
         $reviewVerdictMatches.Count -ne 1 -or
         $reviewVerdictMatches[0].Groups['value'].Value.Trim() -cne 'Approve' -or
         $criticalCountMatches.Count -ne 1 -or
         $criticalCountMatches[0].Groups['value'].Value.Trim() -cne '0'
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/scope-engine.validation.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/scope-engine.validation.ps1
index fae21c7..c5fc453 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/scope-engine.validation.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/scope-engine.validation.ps1
@@ -349,25 +349,23 @@ function Test-ScopeEngine([string]$Root, [string]$ContractText) {
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
-          ($chainIndex -eq 0 -and (
-            [string]$chainArtifact.status -cne 'approved' -or
-            [string]$chainArtifact.result -cne 'complete' -or
-            [string]$chainArtifact.approval_source -cne 'human'
-          )) -or
+          [string]$chainArtifact.status -cne 'approved' -or
+          [string]$chainArtifact.result -cne 'complete' -or
+          [string]$chainArtifact.approval_source -cne 'human' -or
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
@@ -498,20 +496,48 @@ function Test-ScopeEngine([string]$Root, [string]$ContractText) {
           return [pscustomobject]@{ result = 'plan-invalid'; reason = 'active-attempt-item-mismatch'; scope_status = 'scope-blocked' }
         }
         if ([string]$activeAttemptRecord.attempt_id -cne [string]$inProgressItems[0].latest_attempt) {
           return [pscustomobject]@{ result = 'plan-invalid'; reason = 'active-attempt-latest-mismatch'; scope_status = 'scope-blocked' }
         }
       }
 
       $planWideResponsibilityBlock = & $resolvePlanWideResponsibilityBlock $items
       if ($null -ne $planWideResponsibilityBlock) { return $planWideResponsibilityBlock }
 
+      $dependencyIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
+      foreach ($item in $items) {
+        foreach ($dependency in @($item.dependencies)) {
+          if (-not [string]::IsNullOrWhiteSpace([string]$dependency) -and [string]$dependency -cne 'none') {
+            [void]$dependencyIds.Add([string]$dependency)
+          }
+        }
+      }
+      foreach ($dependencyId in $dependencyIds) {
+        $dependencyItem = $itemById[$dependencyId]
+        if (
+          [string]$dependencyItem.status -ceq 'complete' -and
+          (
+            [string]::IsNullOrWhiteSpace([string]$dependencyItem.terminal_evidence) -or
+            [string]$dependencyItem.terminal_evidence -ceq 'none' -or
+            -not (& $testTerminalResponsibilityAuthority $dependencyItem ([string]$dependencyItem.terminal_evidence))
+          )
+        ) {
+          return [pscustomobject]@{
+            result = 'scope-blocked'
+            reason = 'terminal-responsibility-authority-invalid'
+            scope_status = 'scope-blocked'
+            work_item_id = ''
+            reconciled_work_item_id = ''
+          }
+        }
+      }
+
       $reconciledWorkItemId = ''
       if ($inProgressItems.Count -eq 1) {
         $inProgressItem = $inProgressItems[0]
         $latestAttemptRecord = $attemptById[[string]$inProgressItem.latest_attempt]
         $hasValidTerminalEvidence =
           $null -ne $latestAttemptRecord -and
           @('complete', 'blocked') -ccontains [string]$latestAttemptRecord.status -and
           -not [string]::IsNullOrWhiteSpace([string]$inProgressItem.terminal_evidence) -and
           [string]$inProgressItem.terminal_evidence -cne 'none' -and
           [string]$latestAttemptRecord.artifact_reference -ceq [string]$inProgressItem.terminal_evidence

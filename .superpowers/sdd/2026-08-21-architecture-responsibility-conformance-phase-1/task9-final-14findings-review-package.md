# Review package: 9f467ad09f5d3cf9a182cce2d6e8dc1edc2ad969..0f1174cce3df056dacbe049bdee575d977ef7ec7

## Commits
0f1174c test: cover responsibility conformance workflow

## Files changed
 .../contracts/file-responsibility-conformance.md   |  44 +-
 .../contracts/target-structure-conformance.md      |  17 +-
 .../skills/migration/code-migration/SKILL.md       |   1 +
 .../aitoolkit/skills/shared/ai-review/SKILL.md     |  22 +-
 .../templates/migration/implementation-report.md   |   6 +-
 .../aitoolkit/templates/migration/review-report.md |  16 +-
 .../tests/scenarios/architecture-review.Tests.ps1  | 492 +++++++++++++++++++--
 .../scenarios/responsibility-conformance.Tests.ps1 |  29 +-
 .../tests/scenarios/scope-artifacts.Tests.ps1      |  13 +
 .../tests/scenarios/scope-engine.Tests.ps1         |  50 ++-
 .../tests/scenarios/structural-gate.Tests.ps1      |  10 +
 .../tests/validate-migration-framework.Tests.ps1   |  35 ++
 .../tests/validate-migration-framework.ps1         |   4 +-
 .../validation/architecture-review.validation.ps1  |  91 +++-
 .../responsibility-conformance.validation.ps1      | 382 +++++++++++++---
 .../validation/scope-artifacts.validation.ps1      |   9 +-
 .../tests/validation/scope-engine.validation.ps1   |  14 +-
 .../validation/structural-gate.validation.ps1      |   9 +-
 18 files changed, 1125 insertions(+), 119 deletions(-)

## Diff
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/contracts/file-responsibility-conformance.md b/AIToolkit/AIToolkit-main/aitoolkit/contracts/file-responsibility-conformance.md
index 7c320d8..590b119 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/contracts/file-responsibility-conformance.md
+++ b/AIToolkit/AIToolkit-main/aitoolkit/contracts/file-responsibility-conformance.md
@@ -88,21 +88,48 @@ class-name match, a line count, or a file-location guess.
 Independent review derives the changed-path inventory from the immutable pinned
 `task-base..final-tree` Git comparison, including `M`, `A`, `R`, `C`, and `D`.
 Repository-relative paths rooted at `src/`, `lib/`, `app/`, `apps/*/src|lib|app`,
 `packages/*/src|lib|app`, `server/`, `client/`, `frontend/`, or `backend/` are
 canonically production-classified; nested test, spec, doc, script, tool,
 generated, build, and distribution roots are excluded unless an approved
 responsibility explicitly selects them. Marker presence never determines
 whether a changed path enters the inventory. Normalize repository-relative
 backslashes to `/` once before comparing design, review, Git, Change Hygiene,
 verification binding, or source evidence; absolute paths, empty segments, and
-`.`/`..` segments are invalid. Parse owner markers only from canonically
+`.`/`..` segments are invalid. Canonical Git inventory is NUL-delimited,
+preserves Unicode letters and embedded spaces with NFC normalization, and
+rejects control characters or contract-delimiter ambiguity. Equivalent source
+root spellings with one trailing directory separator resolve to the same Git
+root.
+
+### Language-valid semantic marker encoding
+
+Real source and verification producers emit each responsibility-contract
+payload as an exact whole-line language comment. C-family comment languages
+(`.c`, `.h`, `.cc`, `.cpp`, `.java`, `.js`, `.ts`, `.dart`, `.cs`, `.rs`,
+`.go`, `.swift`, `.kt`, and `.scala`, including their recognized variants) use
+`// arc:@responsibility RESP-*` for owner declarations, `// arc:@...` for the
+remaining owner or verification fields, `// arc:route` for production route
+evidence, and `// arc:scenario` for verification execution evidence. Hash
+comment languages (`.py`, `.sh`, `.rb`, `.pl`, `.yaml`, `.toml`, and
+PowerShell source) use `# arc:@responsibility RESP-*`, `# arc:@...`,
+`# arc:route`, and `# arc:scenario` respectively. The consumer strips exactly
+one recognized `arc:` comment sentinel and evaluates its payload as semantic
+metadata; it does not require a language-invalid bare pseudo-statement.
+
+The sentinel must occupy the whole active lexical line apart from whitespace.
+Ordinary comments such as `// disabled arc:@responsibility ...`, block-commented
+sentinels, and sentinel-like text inside string literals are inert. Legacy bare
+contract payloads remain compatibility input for neutral fixtures, but they are
+not the producer form for real language source.
+
+Parse owner markers only from canonically
 production-classified paths or paths explicitly selected by approved owner
 authority. Framework-neutral executable content in a production path must be
 covered by a responsibility block; markerless content before, between, or
 after valid blocks is still unowned and blocks conformance. Blank lines and
 comment-only content outside a block remain valid. Ordinary literal,
 control-flow, and body-only edits inside a bounded responsibility block inherit
 that block's owner and path; an added diff hunk does not repeat metadata merely
 to prove the binding.
 
 Every changed Git path reconciles one-to-one to exactly one implementation `Change Hygiene` row using
@@ -113,20 +140,35 @@ removed responsibility block enters the deletion flow even when its file
 survives. Every `D` path, whether or not it contains an owner, and every removed
 block uses exact immutable evidence
 `source:<task-base SHA>:<path>; diff:<task-base SHA>..<final-tree SHA>:<path>`;
 the deleted path is not required in final-tree. Omitted paths, markerless
 production changes, duplicate/surplus rows, stale or foreign evidence, and
 unapproved removals block. A rename preserves both old and new path authority,
 is production-classified when either side is production, and uses exact
 `source:<task-base SHA>:<old path>; diff:<task-base SHA>..<final-tree SHA>:<old path>-><new path>`
 in Change Hygiene; responsibility diff evidence uses the same explicit
 `<old path>-><new path>` mapping while base-source evidence resolves the old path.
+A copy is classified only by its destination: a production source copied to an
+excluded destination does not transfer production ownership to that new path.
+Unlike rename, copy does not remove or move the source authority.
+
+Each implementation hygiene row names one canonical edited region: an ordinal
+identifier or an exact comma-and-space-separated identifier list, never a
+placeholder, wildcard, whole-file, or repository-wide claim. `Formatter
+Command` is exact `none` or a safe command scoped to that row's canonical path;
+repository-wide operands such as `.`, `*`, or `--all` are invalid. `Unrelated
+Diff` is exact `none` or `confirmed:MAJOR-*`. Independent review reconciles each
+implementation row one-to-one using exact
+`<canonical path>#<edited region>` Scope Evidence, formatter evidence,
+disposition, severity, and pinned SHAs. Every confirmed unrelated diff maps to
+exactly one `Major` finding and makes Change Hygiene `BLOCKED`; surplus,
+missing, duplicate, or contradictory review/finding rows block review.
 
 ## Review Verdicts
 
 ```text
 Verdict = PASS | BLOCKED
 ```
 
 Structural responsibility remains `PASS` or `BLOCKED` independently of runtime
 waivers. A runtime waiver changes neither responsibility ownership nor the
 structural verdict.
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/contracts/target-structure-conformance.md b/AIToolkit/AIToolkit-main/aitoolkit/contracts/target-structure-conformance.md
index 74bea44..24d4996 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/contracts/target-structure-conformance.md
+++ b/AIToolkit/AIToolkit-main/aitoolkit/contracts/target-structure-conformance.md
@@ -107,16 +107,31 @@ Architecture-first review order: master-scope/work-item alignment -> project rul
 
 Review checks invented aggregate state, direct widget service/router calls, raw
 layout in place of a target wrapper, missing unit boundary, wrong localization,
 missing lifecycle gate, tests that bypass the production provider, missing
 production subscription keys, planned/actual tree drift, and unapproved
 structural deviations before lower-level behavior analysis.
 
 ## Architecture review verdicts
 
 ```text
+Rule Resolution Verdict: RESOLVED | BLOCKED
 Architecture Conformance Verdict: PASS | BLOCKED
 Canonical Selector Verdict: PASS | BLOCKED
+Tree Conformance Verdict: PASS | BLOCKED
+Responsibility Conformance Verdict: PASS | BLOCKED
+Verification Ownership Verdict: PASS | BLOCKED
 Production Activation-path Verdict: PASS | BLOCKED | NOT_APPLICABLE
+Behavior Analysis State: NOT_RUN | COMPLETE
+Change Hygiene Verdict: PASS | BLOCKED
 ```
 
-Any `BLOCKED` verdict makes the overall verdict `Reject`.
+An executable review also contains exact non-negative Critical and Major
+counts. Any `BLOCKED` verdict makes the overall verdict `Reject`.
+Any blocking gate or positive Critical count derives overall `Reject`;
+otherwise a positive Major count derives `Approve-with-fixes`, and only zero
+Critical plus zero Major with all gates resolved/pass and behavior complete
+derives `Approve`.
+The `Architecture Responsibility Handoff` Tree, Responsibility, Verification
+Ownership, and Architecture cells equal their visible verdicts exactly; the
+Architecture cell is the same Tree/Responsibility/Verification-derived state.
+A contradictory handoff is not executable producer authority.
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/skills/migration/code-migration/SKILL.md b/AIToolkit/AIToolkit-main/aitoolkit/skills/migration/code-migration/SKILL.md
index fac11da..9d74e0d 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/skills/migration/code-migration/SKILL.md
+++ b/AIToolkit/AIToolkit-main/aitoolkit/skills/migration/code-migration/SKILL.md
@@ -88,20 +88,21 @@ The resumed invocation still performs selector validation, target source edits,
 ## Procedure
 
 1. Read `aitoolkit-schemas`, both scope/conformance contracts, `aitoolkit/contracts/activation-slice.md`, `shared/change-hygiene.md`, explicit inputs, and `aitoolkit/templates/migration/implementation-report.md`.
 2. Run the Structural pre-edit gate in its exact order. On any failure, write the structured evidence as `status: draft`, `result: blocked`, and stop without runtime-waiver classification or target edit.
 3. Validate the selected adapter's legacy Entry gate and approved Activation Slice. For `migration-unit`, retain `migration_unit_id`; for any other adapter, do not invent one. Treat the shared scope, formatting, final-diff, and commit-boundary rules as mandatory.
 4. Resolve required commands in this command resolution order: `explicit profile -> existing project scripts/config -> marker detection -> human gate`. Use repository commands verbatim; never invent or translate one.
 5. In incremental mode, capture a comparable pre-change regression baseline against the unchanged target and preserve its evidence reference. On a valid Approved baseline-waiver resume, skip only that collection and cite the exact approved waiver evidence as `Baseline Reference`. Greenfield records `not-applicable`.
 6. After baseline capture, evaluate the pre-mutation gate for runtime evidence or validate the exact Approved baseline-waiver resume. An unresolved command or failed/non-comparable baseline capture records `result: blocked` plus its native blocker evidence before any edit; invalid resume evidence also blocks. A runtime waiver cannot change structural assurance states.
 7. Use `superpowers:using-git-worktrees` to create or verify an isolated worktree and branch without editing the target, then use `superpowers:writing-plans` to translate only the approved work item into steps and review checkpoints.
 8. Within `superpowers:executing-plans`, apply `superpowers:test-driven-development`: write an acceptance test, observe RED, implement the minimum, observe GREEN, then refactor while staying green.
+   When a real source or verification file carries responsibility-contract metadata, emit the contract's language-valid semantic marker form: exact whole-line `// arc:<payload>` in the documented slash-comment languages or `# arc:<payload>` in the documented hash-comment/PowerShell languages. Use it for every `@...`, `route ...`, and `scenario ...` payload; never require a language-invalid bare pseudo-statement and never hide active evidence in an ordinary or block comment.
 9. Resolve the external Activation Slice contract before editing: report and external authority must have exact Slice ID set/cardinality equality in both directions, including every `not-applicable-approved` group; every `ACT-[0-9]{3}` slice has exactly the nine canonical seams in order, legal disposition/status state, and router/async evidence. Derive the production handoff only from the canonical router boundary plus construct/test fields; never add private evidence keys to Task 6. Preserve each row exactly except canonical `Source Reference` enrichment (`<predecessor>; <non-whitespace evidence>`); predecessor Trace IDs are a non-empty subset of successor Trace IDs, which may append only Work Item-authorized IDs. Record each changed-file row and each test by `Work Item ID`, plus a structured `Activation Slice ID`, `Seam`, and non-empty canonical `Trace IDs` subset resolved against both the approved work item and the exact predecessor seam; repeat rows for multi-seam files or tests. A truthful `draft/blocked` pre-mutation artifact may omit both implementation-evidence sections and must stop before edit; normal `draft/complete` and `approved/complete` output requires real changed/test evidence. Unit-specific IDs are recorded only inside conditional `Selected Migration Unit` evidence when the adapter is `migration-unit`; generic adapters never invent `UNIT-*`. Also record whether each file is `new` or `existing`, edited regions/symbols, actual/planned tree evidence, boundary/activation evidence, and every formatter command. Inspect the final diff, remove all untraced or formatting-only changes, and block unrelated whole-file churn. Capture commands, sources, exit codes, and Evidence. Local checkpoint commits are non-delivery history; this work item must become one final delivery commit. Do not upload, merge, or mutate unrelated work.
 
 ## Evidence and Unknowns
 
 Evidence includes approval, conformance, RED/GREEN output, commands, changes, and trace IDs. Unknowns identify missing evidence.
 
 ## Hợp đồng đầu ra
 
 - File: `<RUN_DIR>/10-implementation-report.md`.
 - Front matter: `step_id: 10-code-migration`, canonical lifecycle, `produced_at`; normal implementation output may be `draft/complete`, approved output may be `approved/complete` with canonical `approval_source`, and pre-edit failure remains `draft/blocked` with no fabricated changes/tests.
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/skills/shared/ai-review/SKILL.md b/AIToolkit/AIToolkit-main/aitoolkit/skills/shared/ai-review/SKILL.md
index eb59d29..4505e44 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/skills/shared/ai-review/SKILL.md
+++ b/AIToolkit/AIToolkit-main/aitoolkit/skills/shared/ai-review/SKILL.md
@@ -33,21 +33,27 @@ Với `workflow_type: migration`, thực hiện đúng thứ tự gate sau; ch
 3. Canonical selector validation.
 4. Tree conformance from final inventory and source/diff evidence.
 5. Responsibility conformance against planned responsibility evidence.
 6. Verification ownership from final inventory and source/diff evidence.
 7. Production activation-path validation.
 8. Behavior, failure modes, security, performance, and tests.
 9. Change hygiene.
 
 Architecture-first review order: master/work-item -> rules -> selector -> tree -> responsibility -> verification ownership -> activation -> behavior/security/performance -> hygiene.
 
-Derive every `M/A/R/C/D` changed Git path from the pinned comparison and reconcile it one-to-one to exactly one implementation `Change Hygiene` row with exact status mapping `A/C = new`, `M/R = existing`, and `D = deleted`. Normalize repository separators to `/` once across design, review, Git, hygiene, verification binding, and source evidence; reject aliases, absolute paths, and traversal. Independently classify production paths by the canonical roots in the file-responsibility contract and parse owner markers only for production-classified or explicitly selected authority paths: markerless executable content remains unowned even beside a valid block, while irrelevant docs are not promoted by incidental markers. Compare pinned base and final content for surviving `M/R` paths so removed responsibility blocks enter deletion reconciliation. Every deleted Git path needs exact task-base source/removal-diff checkpoint evidence even when it has no owner. A removed block in a surviving file uses `File Kind = existing`; a deleted file uses `File Kind = deleted` and does not require a final-tree path. Preserve both sides of a rename, classify it as production when either side is production, resolve base evidence at the old path, and require explicit `<old path>-><new path>` mapping in checkpoint and review diff evidence.
+Derive every `M/A/R/C/D` changed Git path from the pinned comparison and reconcile it one-to-one to exactly one implementation `Change Hygiene` row with exact status mapping `A/C = new`, `M/R = existing`, and `D = deleted`. Require a canonical identifier/list in `Edited Region / Symbol`, an exact `none` or path-scoped safe formatter command, and exact `none` or `confirmed:MAJOR-*` unrelated-diff disposition. Reject wildcards, whole-repository regions, and repository-wide formatter operands including `.`, `*`, and `--all`. Reconcile every implementation row one-to-one to independent review Scope/Formatter/Unrelated-Diff/Severity/SHA evidence; each confirmed unrelated diff requires exactly one matching `Major` finding and blocks Change Hygiene. Normalize repository separators to `/` once across design, review, Git, hygiene, verification binding, and source evidence; reject aliases, absolute paths, and traversal. Independently classify production paths by the canonical roots in the file-responsibility contract and parse owner markers only for production-classified or explicitly selected authority paths: markerless executable content remains unowned even beside a valid block, while irrelevant docs are not promoted by incidental markers. Compare pinned base and final content for surviving `M/R` paths so removed responsibility blocks enter deletion reconciliation. Every deleted Git path needs exact task-base source/removal-diff checkpoint evidence even when it has no owner. A removed block in a surviving file uses `File Kind = existing`; a deleted file uses `File Kind = deleted` and does not require a final-tree path. Preserve both sides of a rename, classify it as production when either side is production, resolve base evidence at the old path, and require explicit `<old path>-><new path>` mapping in checkpoint and review diff evidence.
+
+Classify `C` by the destination only: copying a production source into an excluded destination does not transfer production ownership. `R` remains movement and preserves old/new authority.
+
+Read Git name-status and tree paths with NUL delimiters. Canonical paths preserve embedded spaces and Unicode under NFC normalization, but reject controls, contract delimiters, absolute paths, empty/dot/traversal segments, and aliases. Normalize a single trailing source-root separator before comparing it with the resolved Git top level.
+
+Consume responsibility and verification metadata through the contract's language-valid semantic marker encoding. Recognize only an exact whole-line `// arc:<payload>` in documented slash-comment languages or `# arc:<payload>` in documented hash-comment/PowerShell languages, then review the projected `@...`, `route ...`, or `scenario ...` payload. Ordinary comments, disabled prefixes, block-commented sentinels, and sentinel-like string content stay inert; never demand language-invalid bare pseudo-statements from a real producer.
 
 The reviewer independently inspects the final inventory and task-base/final-tree source diff. Implementation self-attestation is not semantic PASS evidence. For every selected Verification Ownership row, resolve `Evidence Path` from the pinned final-tree SHA, locate exactly its named scenario, and bind the scenario's exact verification owner, production responsibility, capability, evidence kind, disposition, and production path/symbol to the independent final production inventory. `production-composition` also binds the exact production route and provider. An unchanged verification file is valid final-tree source evidence without a fabricated diff; missing, foreign, stale, self-attested, or test-only registry/provider evidence is `BLOCKED`. This is framework-neutral source-contract validation and must not infer authority from a language-specific AST. Never discard a base-only deleted responsibility after checking its removal diff: reconcile its owner, path, public symbols, capabilities, effects, architecture/co-location authority, verification owners, routes, and providers to one exact approved design removal decision, one `Change Hygiene` row with `File Kind = deleted`, and one independent Responsibility Review Evidence row using task-base source plus removal-diff references. A missing or partial reconciliation is an unplanned deletion and blocks Tree and Responsibility conformance. Missing master context, canonical selector, conformance matrix, exemplar, actual/planned tree evidence, responsibility review evidence, verification ownership evidence, or applicable production activation evidence records the matching verdict as `BLOCKED`, sets the overall verdict to `Reject`, and stops before reviewer dispatch and before behavior analysis. Rule Resolution remains an independent first severity gate and cannot be weakened by architecture ordering.
 
 Require exactly one Architecture Conformance Verdict, exactly one Canonical Selector Verdict, exactly one Tree Conformance Verdict, exactly one Responsibility Conformance Verdict, exactly one Verification Ownership Verdict, and exactly one Production Activation-path Verdict. Any `BLOCKED` verdict makes the overall verdict `Reject`, independently of severity counts.
 
 ## Mandatory architecture findings
 
 Review invented aggregate state; direct widget service/router calls; raw layout replacing the target wrapper; missing unit boundary; wrong localization mechanism; missing lifecycle gate; tests bypassing the production provider; missing production subscription key; planned/actual tree drift; source/diff inventory that exposes an omitted owner, public symbol, effect, route, or provider; an unplanned full deletion of an owned responsibility; and unapproved structural deviation. Classify a missing production subscription key as `Critical`. An unapproved structural deviation is at least `Major` and is `Critical` when activation, routing, or rendering fails.
 
 ## Việc cần làm (thứ tự)
@@ -91,21 +97,21 @@ Only exact `Critical count: 0` with exact overall `Verdict: Approve` is executab
 ## Migration-only handoff extension
 
 Preserve the immediate predecessor Activation Slice envelope without loss: keep the complete case-sensitive slice ID set, Applicability, all nine canonical seam rows, and every predecessor Source Reference and Trace ID. Source Reference enrichment is append-only, and predecessor Trace IDs remain a subset of successor Trace IDs. Never reconstruct it from cumulative artifacts.
 
 Khi orchestrator gọi step này với `workflow_type: migration`, trước hết copy nguyên vẹn `Master Scope Context` của work item. Chỉ khi `Delivery Adapter Kind` là `migration-unit`, immediate predecessor mới phải chứa đúng một section `Selected Migration Unit`; validate và copy nguyên vẹn `migration_unit_id`, plan reference, approval reference, mode constraint, `Bootstrap Scope`, Foundation Baseline ID, foundation baseline reference, foundation baseline approval reference, baseline reference, và trace IDs sang report mới. Với adapter khác, bỏ section `Selected Migration Unit` và không suy ra unit từ diff.
 
 Migration review là producer gốc của responsibility handoff (`responsibility handoff origin producer`), không copy handoff từ implementation. Dùng `templates/migration/review-report.md` và emit đúng một bounded front matter với exact top-level key order/cardinality `step_id`, `status`, `result`, `approval_source`, `produced_at`, `responsibility_contract`; keys quoted, case-variant, hyphenated, duplicate, extra, hoặc reordered đều invalid. `produced_at` phải là calendar date hợp lệ theo exact `yyyy-MM-dd`, không blank hay malformed. `step_id` phải exact canonical `11-ai-review`; discriminator là `responsibility_contract.version: 1`, `applicability: required`. Draft artifacts omit `approval_source`; approved executable artifacts dùng exact `approved/complete/human`, và review `Reject`, Critical-bearing, hoặc otherwise non-PASS không được seed downstream execution. Copy ordinally exact tám field `Run ID`, master spec reference/ID/revision, master plan reference/ID/revision và `Work Item ID` từ immediate predecessor; không reconstruct từ cumulative artifacts hoặc directory scan.
 
 Emit đúng một `Task Provenance` row. Resolve assurance identity từ approved current adapter authority: với `migration-unit`, `Task / Unit` phải bằng exact `Selected Migration Unit.Migration Unit ID`; với `task | story | package | phase | milestone | none`, nó phải bằng current `Master Scope Context.Work Item ID`. `Task-base SHA` và `Final-tree SHA` phải là hai SHA đã validate và dùng để review exact diff; `Source Artifact` phải resolve đúng immediate predecessor `implementation-report.md`. Missing, placeholder, stale, cross-run, cross-work-item, hoặc mismatch với implementation `Change Hygiene` là `result: blocked`.
 
-Sau khi independent inventory review hoàn tất, emit đúng một `Architecture Responsibility Handoff` row theo canonical `aitoolkit/contracts/file-responsibility-conformance.md`. Preserve ba semantic verdict do review độc lập tạo ra; derive `Architecture Conformance State = PASS` chỉ khi Tree, Responsibility và Verification Ownership đều `PASS`, ngược lại `BLOCKED`. `Evidence References` phải là exact `source-diff:<task-base SHA>..<final-tree SHA>#<WORK-*>` bind cùng row `Task Provenance`; không dùng implementation self-attestation, review filename, caller aggregate, hoặc evidence từ run khác.
+Sau khi independent inventory review hoàn tất, emit đúng một `Architecture Responsibility Handoff` row theo canonical `aitoolkit/contracts/file-responsibility-conformance.md`. Preserve ba semantic verdict do review độc lập tạo ra; every handoff Tree, Responsibility, and Verification Ownership cell must equal its visible review verdict exactly, and the handoff Architecture cell must equal the visible Tree/Responsibility/Verification-derived Architecture verdict. Derive `Architecture Conformance State = PASS` chỉ khi Tree, Responsibility và Verification Ownership đều `PASS`, ngược lại `BLOCKED`. `Evidence References` phải là exact `source-diff:<task-base SHA>..<final-tree SHA>#<WORK-*>` bind cùng row `Task Provenance`; không dùng implementation self-attestation, review filename, caller aggregate, hoặc evidence từ run khác.
 
 `verification-testing` là immediate consumer: nó chỉ copy ordinally exact `Task Provenance` và `Architecture Responsibility Handoff` từ review artifact đã `approved/complete/human`. Một review còn `draft`, `blocked`, stale, cross-run, sai immediate predecessor hoặc có handoff không khớp provenance không được khởi tạo terminal chain.
 
 Đồng thời đọc `aitoolkit/contracts/activation-slice.md`, validate section `Activation Slice`, và copy nguyên vẹn cùng stable ID, mọi seam row và trace IDs sang report. Thiếu, duplicate, đổi tên hoặc mất trace làm handoff `result: blocked`; không suy lại slice từ diff.
 
 - Ghi front matter migration là `result: complete | blocked` ngoài lifecycle `status: draft`.
 - Thiếu, mơ hồ, hoặc mismatch bất kỳ field nào thì ghi `result: blocked`; không được suy selector/baseline từ diff hoặc artifact cũ.
 - Với feature and bugfix, không áp dụng extension, không yêu cầu các field này, và giữ nguyên output contract hiện có.
 
 ## Red Flags — DỪNG
@@ -124,21 +130,29 @@ Sau khi independent inventory review hoàn tất, emit đúng một `Architectur
 | "Không có test nhưng hiển nhiên đúng" | Thiếu test cho hành vi mới = Major |
 | "Chỉ đổi 1 dòng" | 1 dòng vẫn có thể là Critical |
 | "Optional project rule thiếu nên khỏi review" | Vẫn review theo 8 dimensions phổ quát và ghi degraded coverage |
 | "Phân vân Major/Critical, cho Major" | Phân vân → chọn mức CAO hơn |
 
 ## Hợp đồng đầu ra (`review-report.md`)
 
 1. **Rule Resolution**: `RESOLVED | BLOCKED`, mandatory rule gaps, optional gaps/degraded coverage. Đây là first gate.
 2. **Tổng quan**: phạm vi (SHA `BASE..HEAD`), profile/pack path và project rules áp dụng.
 3. **Findings** nhóm theo mức; mỗi cái: `file:line` + vấn đề + **fix đề xuất**.
-4. **Critical count** (số nguyên) — chỉ là severity gate sau Rule Resolution.
+4. **Critical count** và **Major count** (hai số nguyên không âm) — severity gates sau Rule Resolution.
 5. **Verdict**: `Approve` (rule resolution resolved, all architecture-first verdicts pass, 0 Critical, 0 Major) | `Approve-with-fixes` (các gate resolved/pass, còn Major) | `Reject` khi rule resolution blocked, Tree, Responsibility, hoặc Verification Ownership `BLOCKED`, bất kỳ architecture-first verdict nào blocked, hoặc còn Critical. Reject when rule resolution is blocked, an architecture-first verdict is blocked, or Critical remains.
    Reject when rule resolution is blocked or Critical remains. Với migration, cũng Reject khi bất kỳ architecture-first verdict nào là `BLOCKED`.
 6. **Migration only**: preserve `Master Scope Context`; emit canonical bounded front matter, exact `Task Provenance`, và exactly one v1 `Architecture Responsibility Handoff` derived from independent review evidence; preserve bảng `Selected Migration Unit` chỉ cho adapter `migration-unit`; preserve `Activation Slice` và migration `result`. Feature/bugfix bỏ qua các field này.
-7. **Change Hygiene**: record task/unit scope, changed-file evidence, formatter commands, unrelated-diff verdict, and severity.
+7. **Change Hygiene**: record task/unit scope, changed-file evidence, formatter commands, unrelated-diff verdict, severity, and derive exact `Change Hygiene Verdict: PASS | BLOCKED`.
 8. **Migration blocked only**: when the routed output is `result: blocked` and Activation Slice/handoff validation is otherwise valid, emit exactly one `Domain Blocker` table with non-placeholder `Blocker` and `Evidence Reference`; omit it from non-blocked migration output. Feature/bugfix behavior is unchanged.
 
+For an executable migration review, render every canonical gate exactly once:
+Rule Resolution, Canonical Selector, Architecture Conformance, Tree
+Conformance, Responsibility Conformance, Verification Ownership, Production
+Activation-path, Behavior Analysis State, and Change Hygiene. Derive the
+overall verdict from those visible gates plus the exact Critical and Major
+counts. Do not emit an approval whose visible gate or count would derive a
+different verdict.
+
 ## Ranh giới
 
 - CHỈ review + báo cáo; KHÔNG tự sửa code (dev sửa, hoặc quay lại bước tạo code nếu Critical).
 - KHÔNG chạy test (đó là bước verification-testing) và KHÔNG upload Gerrit.
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/templates/migration/implementation-report.md b/AIToolkit/AIToolkit-main/aitoolkit/templates/migration/implementation-report.md
index 8e1539d..85f7acc 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/templates/migration/implementation-report.md
+++ b/AIToolkit/AIToolkit-main/aitoolkit/templates/migration/implementation-report.md
@@ -91,20 +91,22 @@ Ba state độc lập; runtime waiver không thay đổi architecture hay select
 Copy the selected work-item row exactly from the approved plan. These IDs scope the actual matrices; do not include unrelated design owners.
 
 | Work Item ID | Design Revision | Responsibility IDs | Shared Foundation IDs | Integration Responsibility IDs | Independent Boundary Evidence |
 |---|---|---|---|---|---|
 | <WORK-*> | <DESIGN-*@revision> | <ordered RESP-* or not-applicable> | <ordered RESP-* or not-applicable> | <ordered RESP-* or not-applicable> | <exact approved immutable evidence> |
 
 ## Actual File Responsibility Matrix
 
 Copy every approved `File Responsibility Matrix` field exactly and add source or final-diff evidence for the observed owner, public symbols and effects. This actual inventory is not a self-attestation that can create semantic PASS.
 
+For real source and verification files, emit every contract payload with the language-valid semantic marker documented by the responsibility contract: exact whole-line `// arc:<payload>` for slash-comment languages or `# arc:<payload>` for hash-comment/PowerShell languages. Apply it to `@...`, `route ...`, and `scenario ...`; bare language-invalid pseudo-statements are not the producer format.
+
 | Responsibility ID | Owner Path | Owner Symbol | Boundary Kind | Primary Responsibility | Owned Capability IDs | Trace IDs | Atomic Boundary ID | Public Symbols | External Effects | Target Exemplar | Exemplar Classification | Classification Authority | Classification Evidence | Architecture Authority | Co-location Policy | Co-location Evidence | Verification Owner References | Conformance | Deviation Reference | Actual Evidence |
 |---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
 | <RESP-*> | <path> | <symbol> | <approved value> | <approved value> | <CAP-*> | <trace IDs> | <approved value> | <symbols> | <effects> | <approved value> | <approved value> | <approved value> | <approved value> | <approved value> | <approved value> | <approved value> | <VERIFY-OWNER-*> | <yes or no> | <DEV-* or not-applicable> | <source/diff evidence> |
 
 ## Actual Verification Ownership Matrix
 
 | Verification Owner ID | Production Responsibility ID | Capability ID | Evidence Path | Evidence Symbol or Scenario | Evidence Kind | Verification Disposition | Production Binding Evidence | Decision Reference | Verdict | Deviation Reference | Actual Evidence |
 |---|---|---|---|---|---|---|---|---|---|---|---|
 | <VERIFY-OWNER-*> | <RESP-*> | <CAP-*> | <path> | <symbol/scenario> | <approved kind> | <required or not-applicable-approved> | <production binding> | <decision or not-applicable> | <PASS or BLOCKED> | <DEV-* or not-applicable> | <source/diff evidence> |
 
@@ -165,25 +167,25 @@ Required for normal `draft/complete` and `approved/complete` implementation outp
 | <WORK-*> | <ACT-001> | <canonical seam> | <test/scenario> | <lệnh> | <PASS / FAIL / BLOCKED> | <approved slice/seam trace IDs> |
 
 ## Trace ID triển khai
 
 | Trace ID | Implementation Reference |
 |---|---|
 | <REQ-001> | <path hoặc symbol> |
 
 ## Change Hygiene
 
-List every pinned `task-base..final-tree` changed Git path exactly once; duplicate, surplus, stale, or omitted rows are blocking. Normalize repository path separators to `/` before writing the row. Use exact `File Kind`: `A/C = new`, `M/R = existing`, `D = deleted`. Every deleted path is resolved from task-base whether or not it contains an owner and does not need to exist in final-tree; set `Checkpoint History` to exact `source:<task-base SHA>:<deleted path>; diff:<task-base SHA>..<final-tree SHA>:<deleted path>`. For a removed responsibility block in a surviving file, use `existing` and the same base-source/removal-diff evidence for that owner symbol. A rename keeps the destination in `File`, preserves old/new authority, and requires exact `source:<task-base SHA>:<old path>; diff:<task-base SHA>..<final-tree SHA>:<old path>-><new path>`. Omitted, duplicate, surplus, stale, foreign, or status-mismatched rows are blocking.
+List every pinned `task-base..final-tree` changed Git path exactly once from the NUL-delimited Git inventory; duplicate, surplus, stale, or omitted rows are blocking. Normalize repository path separators to `/` and Unicode to NFC before writing the row. Embedded spaces and Unicode are valid; absolute paths, empty or dot segments, traversal, control characters, and contract-delimiter ambiguity are invalid. Use exact `File Kind`: `A/C = new`, `M/R = existing`, `D = deleted`. `Edited Region / Symbol` is one exact identifier or an exact comma-and-space-separated identifier list, never a placeholder, wildcard, whole-file, or repository-wide claim. `Formatter Command` is exact `none` or a safe command containing and scoped to the row's canonical path; `.`, `*`, and `--all` repository-wide operands are forbidden. `Unrelated Diff` is exact `none` or `confirmed:MAJOR-*`; a confirmed disposition must be independently reviewed as a blocking Major. Every deleted path is resolved from task-base whether or not it contains an owner and does not need to exist in final-tree; set `Checkpoint History` to exact `source:<task-base SHA>:<deleted path>; diff:<task-base SHA>..<final-tree SHA>:<deleted path>`. For a removed responsibility block in a surviving file, use `existing` and the same base-source/removal-diff evidence for that owner symbol. A rename keeps the destination in `File`, preserves old/new authority, and requires exact `source:<task-base SHA>:<old path>; diff:<task-base SHA>..<final-tree SHA>:<old path>-><new path>`. Omitted, duplicate, surplus, stale, foreign, or status-mismatched rows are blocking.
 
 | Task / Unit | File | File Kind | Edited Region / Symbol | Formatter Command | Unrelated Diff | Checkpoint History | Task-base SHA | Final-tree SHA |
 |---|---|---|---|---|---|---|---|---|
-| <WORK-*> | <path> | <new, existing, or deleted> | <region or symbol> | <command or none> | none | <checkpoint SHAs, deletion evidence, or none> | <sha> | <sha> |
+| <WORK-*> | <path> | <new, existing, or deleted> | <canonical region or symbol identifiers> | <path-scoped command or none> | <none or confirmed:MAJOR-*> | <checkpoint SHAs, deletion evidence, or none> | <sha> | <sha> |
 
 ## Lệnh và kết quả
 
 | Command | Result | Evidence |
 |---|---|---|
 | <lệnh> | <kết quả> | <tham chiếu> |
 
 ## Blocker gốc
 
 Ghi `not-applicable` khi không có blocker. Nếu có, giữ nguyên kết luận `BLOCKED`, vai trò lệnh, vòng đời lệnh bắt buộc và lỗi command/capability verbatim của bước. Mọi lệnh bắt buộc đã khởi chạy đều không đủ điều kiện waiver; chỉ availability probe riêng biệt với vòng đời lệnh bắt buộc `not-started` mới có thể là ứng viên environment waiver. Bước giữ artifact ở draft/blocked; chỉ orchestrator được thêm automation waiver đã duyệt.
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/templates/migration/review-report.md b/AIToolkit/AIToolkit-main/aitoolkit/templates/migration/review-report.md
index efca228..f6c65ef 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/templates/migration/review-report.md
+++ b/AIToolkit/AIToolkit-main/aitoolkit/templates/migration/review-report.md
@@ -39,21 +39,21 @@ Keep `Selected Migration Unit` only when `Delivery Adapter Kind` is `migration-u
 
 | Migration Unit ID | Plan Reference | Approval Reference | Mode Constraint | Bootstrap Scope | Foundation Baseline ID | Foundation Baseline Reference | Foundation Baseline Approval Reference | Baseline Reference | Trace IDs |
 |---|---|---|---|---|---|---|---|---|---|
 | <UNIT-001> | <tham chiếu plan> | <tham chiếu duyệt đơn vị> | <ràng buộc mode/policy> | <required hoặc not-required> | <FOUNDATION-001 hoặc not-applicable> | <tham chiếu target-baseline đã duyệt hoặc not-applicable> | <tham chiếu duyệt hoặc not-applicable> | <tham chiếu bằng chứng hồi quy hoặc not-applicable> | <trace IDs> |
 
 ## Tổng quan
 - Phạm vi review (SHA): `<BASE>..<HEAD>`
 - Project rules áp dụng: <path profile/pack + rule bắt buộc + khoảng trống tùy chọn/độ phủ suy giảm>
 
 ## Rule Resolution
-- **State:** `RESOLVED | BLOCKED`
+- Rule Resolution Verdict: <RESOLVED | BLOCKED>
 - **Mandatory rule gaps:** <không có hoặc khoảng trống blocking chính xác>
 - **Optional gaps/degraded coverage:** <không có hoặc độ phủ suy giảm đã ghi nhận>
 
 ## Canonical Selector
 
 - Canonical Selector Verdict: <PASS | BLOCKED>
 - Evidence: <adapter kind, canonical selector/authority, work-item binding và approval evidence>
 
 ## Architecture Conformance
 
@@ -113,23 +113,32 @@ Chỉ phát hành hàng `PASS` sau khi reviewer đã kiểm tra độc lập fin
 ## Major
 | File:line | Vấn đề | Fix đề xuất |
 |---|---|---|
 
 ## Minor
 | File:line | Vấn đề | Fix đề xuất |
 |---|---|---|
 
 ## Change Hygiene
 
+- Change Hygiene Verdict: <PASS | BLOCKED>
+
+Reconcile every implementation `Change Hygiene` row exactly once. `Scope
+Evidence` is exact `<canonical path>#<edited region>`, formatter evidence and
+pinned SHAs are copied exactly, and severity is `none` only for `Unrelated
+Diff = none`; `confirmed:MAJOR-*` uses `Major`, one matching `Major` finding,
+and a `BLOCKED` hygiene verdict. Missing, duplicate, surplus, or contradictory
+rows are blocking.
+
 | Task / Unit | Scope Evidence | Formatter Evidence | Unrelated Diff | Severity | Task-base SHA | Final-tree SHA |
 |---|---|---|---|---|---|---|
-| <UNIT-001> | <changed files/symbols> | <commands or none> | <none or finding> | <none, Major, or Critical> | <sha> | <sha> |
+| <UNIT-001> | <canonical path>#<edited region> | <exact command or none> | <none or confirmed:MAJOR-*> | <none or Major> | <sha> | <sha> |
 
 ## Activation Slice
 
 Ghi `not-applicable-approved` với evidence và decision reference khi unit không có activation selector; không được bỏ section.
 
 | Activation Slice ID | Applicability | Seam | Input | Output | Source Reference | Trace IDs | Disposition | Status | Decision Reference | Deferred Unit ID |
 |---|---|---|---|---|---|---|---|---|---|---|
 | <ACT-001> | <applicable / not-applicable-approved / unknown> | <canonical seam> | <input> | <output> | <source reference> | <trace IDs> | <implement / reuse / deferred-approved / not-applicable-approved> | <verified / missing / conflict / unknown> | <approval reference hoặc not-applicable> | <UNIT-* hoặc not-applicable> |
 
 ## Bằng chứng
@@ -139,14 +148,15 @@ Ghi `not-applicable-approved` với evidence và decision reference khi unit kh
 
 Chỉ giữ section này khi front matter là `result: blocked` và Activation Slice/handoff vẫn hợp lệ; mọi output khác phải xóa toàn bộ section. Giá trị placeholder không phải evidence hợp lệ.
 
 | Blocker | Evidence Reference |
 |---|---|
 | <blocker cụ thể> | <tham chiếu bằng chứng cụ thể> |
 ## Điểm chưa rõ
 - <không có hoặc điểm chưa rõ>
 
 ## Kết luận
-- **Critical count:** <số nguyên dùng để gate>
+- **Critical count:** <non-negative integer>
+- **Major count:** <non-negative integer>
 - Verdict: <Approve | Approve-with-fixes | Reject>
 
 Only exact `Critical count: 0` with exact `Verdict: Approve` is executable downstream. `Approve-with-fixes`, `Reject`, a positive/invalid Critical count, or any `BLOCKED` architecture verdict must not seed verification.
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/architecture-review.Tests.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/architecture-review.Tests.ps1
index e64ffbe..2130896 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/architecture-review.Tests.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/architecture-review.Tests.ps1
@@ -1,26 +1,44 @@
 $ErrorActionPreference = 'Stop'
 
 $toolkitRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
 $validatorPath = Join-Path $toolkitRoot 'tests/validation/architecture-review.validation.ps1'
 $contractText = Get-Content -Raw -Encoding utf8 -LiteralPath (Join-Path $toolkitRoot 'contracts/target-structure-conformance.md')
 $responsibilityContractText = Get-Content -Raw -Encoding utf8 -LiteralPath (Join-Path $toolkitRoot 'contracts/file-responsibility-conformance.md')
+$codeMigrationSkillText = Get-Content -Raw -Encoding utf8 -LiteralPath (Join-Path $toolkitRoot 'skills/migration/code-migration/SKILL.md')
+$aiReviewSkillText = Get-Content -Raw -Encoding utf8 -LiteralPath (Join-Path $toolkitRoot 'skills/shared/ai-review/SKILL.md')
+$implementationTemplateText = Get-Content -Raw -Encoding utf8 -LiteralPath (Join-Path $toolkitRoot 'templates/migration/implementation-report.md')
 
 function Require-Token([string]$Text, [string]$Token, [string]$Context) {
   if ($Text -notmatch [regex]::Escape($Token)) {
     $script:errors.Add("$Context missing: $Token")
   }
 }
 
 . $validatorPath
 . (Join-Path $toolkitRoot 'tests/validation/responsibility-conformance.validation.ps1')
 
+foreach ($languageMarkerContract in @(
+  [pscustomobject]@{ Text = $responsibilityContractText; Token = '// arc:@responsibility RESP-*'; Context = 'responsibility contract slash-comment marker' },
+  [pscustomobject]@{ Text = $responsibilityContractText; Token = '# arc:@responsibility RESP-*'; Context = 'responsibility contract hash-comment marker' },
+  [pscustomobject]@{ Text = $responsibilityContractText; Token = '// arc:route'; Context = 'responsibility contract production route marker' },
+  [pscustomobject]@{ Text = $responsibilityContractText; Token = '# arc:scenario'; Context = 'responsibility contract verification scenario marker' },
+  [pscustomobject]@{ Text = $codeMigrationSkillText; Token = 'language-valid semantic marker'; Context = 'code-migration producer guidance' },
+  [pscustomobject]@{ Text = $aiReviewSkillText; Token = 'language-valid semantic marker'; Context = 'AI-review consumer guidance' },
+  [pscustomobject]@{ Text = $implementationTemplateText; Token = 'language-valid semantic marker'; Context = 'implementation template producer guidance' }
+)) {
+  if ($languageMarkerContract.Text.IndexOf($languageMarkerContract.Token, [StringComparison]::Ordinal) -lt 0) {
+    throw "$($languageMarkerContract.Context) missing: $($languageMarkerContract.Token)"
+  }
+}
+Write-Output 'PASS: producer, consumer, contract, and template define language-valid semantic marker encoding'
+
 $canonicalReviewSkill = @'
 # AI Review
 
 ## Architecture-first migration review gates
 
 For migration, perform these gates in order:
 
 1. Master scope and work-item alignment.
 2. Project rule resolution.
 3. Canonical selector validation.
@@ -69,21 +87,21 @@ $canonicalReviewTemplate = @'
 | <WORK-*> | <task-base SHA> | <final-tree SHA> | <immediate predecessor artifact path> |
 
 Keep `Selected Migration Unit` only when `Delivery Adapter Kind` is `migration-unit`; otherwise omit it.
 
 ## Selected Migration Unit
 | Migration Unit ID | Plan Reference | Approval Reference | Mode Constraint | Bootstrap Scope | Foundation Baseline ID | Foundation Baseline Reference | Foundation Baseline Approval Reference | Baseline Reference | Trace IDs |
 |---|---|---|---|---|---|---|---|---|---|
 | <UNIT-001> | <plan> | <approval> | <mode> | <scope> | <foundation ID> | <foundation reference> | <foundation approval> | <baseline> | <trace IDs> |
 
 ## Rule Resolution
-- State: <RESOLVED | BLOCKED>
+- Rule Resolution Verdict: <RESOLVED | BLOCKED>
 
 ## Canonical Selector
 - Canonical Selector Verdict: <PASS | BLOCKED>
 - Evidence: <selector evidence>
 
 ## Architecture Conformance
 - Architecture Conformance Verdict: <PASS | BLOCKED>
 - Conformance Matrix Reference: <matrix>
 - Exemplars: <exemplars>
 - Actual File Tree vs Planned File Tree: <comparison>
@@ -108,24 +126,27 @@ Keep `Selected Migration Unit` only when `Delivery Adapter Kind` is `migration-u
 
 ## Behavior, Failure Modes, Security, Performance, and Tests
 - Behavior Analysis State: <NOT_RUN | COMPLETE>
 - Analysis: <analysis performed only after all preceding gates pass>
 
 ## Critical
 | File:line | Issue | Proposed fix |
 |---|---|---|
 
 ## Change Hygiene
+- Change Hygiene Verdict: <PASS | BLOCKED>
 | Evidence |
 |---|
 
 ## Conclusion
+- Critical count: <non-negative integer>
+- Major count: <non-negative integer>
 - Verdict: <Approve | Approve-with-fixes | Reject>
 '@
 
 $canonicalKbTemplate = @'
 # Knowledge Base
 
 ## Work Item and Master Plan Transition
 | Work Item ID | Work Item Verdict | Master Plan Reference | Master Plan Revision | Transition | Terminal Evidence |
 |---|---|---|---|---|---|
 | <work item> | <complete or blocked> | <plan> | <revision> | <from -> to> | <artifact> |
@@ -222,22 +243,34 @@ responsibility_contract:
 - Responsibility Conformance Verdict: PASS
 - Verification Ownership Verdict: PASS
 | Responsibility ID | Source/Diff Evidence | Planned Public Symbols | Actual Public Symbols | Planned Effects | Actual Effects | Verdict |
 |---|---|---|---|---|---|---|
 | RESP-ADMIN | source:<FINAL-TREE-SHA>:src/admin_route.source#AdminRoute; diff:<TASK-BASE-SHA>..<FINAL-TREE-SHA>:src/admin_route.source#AdminRoute; source:<FINAL-TREE-SHA>:src/admin_route.source#VERIFY-OWNER-ADMIN; diff:<TASK-BASE-SHA>..<FINAL-TREE-SHA>:src/admin_route.source#VERIFY-OWNER-ADMIN | AdminRoute | AdminRoute | route registration | route registration | PASS |
 
 ## Critical
 | File:line | Issue | Proposed fix |
 |---|---|---|
 
+## Major
+| File:line | Issue | Proposed fix |
+|---|---|---|
+| none | none | none |
+
+## Change Hygiene
+- Change Hygiene Verdict: PASS
+| Task / Unit | Scope Evidence | Formatter Evidence | Unrelated Diff | Severity | Task-base SHA | Final-tree SHA |
+|---|---|---|---|---|---|---|
+| WORK-ADMIN | src/admin_route.source#AdminRoute | none | none | none | <TASK-BASE-SHA> | <FINAL-TREE-SHA> |
+
 ## Conclusion
 - Critical count: 0
+- Major count: 0
 - Verdict: Approve
 '@
 
 $canonicalApprovedPlanArtifact = @'
 ---
 artifact_type: migration-master-plan
 master_plan_id: PLAN-ADMIN-001
 master_spec_id: SPEC-ADMIN-001
 master_spec_revision: 1
 revision: 1
@@ -375,20 +408,42 @@ Final-tree SHA: $($PinnedSource.FinalTreeSha)
   $reviewText = $reviewText.Replace('<TASK-BASE-SHA>', $PinnedSource.TaskBaseSha).Replace('<FINAL-TREE-SHA>', $PinnedSource.FinalTreeSha)
   if ($reviewText -match '<(?:TASK-BASE|FINAL-TREE)-SHA>') { throw 'Pinned review evidence fixture replacement failed' }
   Set-Content -Encoding utf8 -LiteralPath $reviewPath -Value $reviewText
   $implementationPath = Join-Path $Root 'artifacts/implementation-report.md'
   $implementationText = Get-Content -Raw -Encoding utf8 -LiteralPath $implementationPath
   $implementationText = $implementationText.Replace('<TASK-BASE-SHA>', $PinnedSource.TaskBaseSha).Replace('<FINAL-TREE-SHA>', $PinnedSource.FinalTreeSha)
   if ($implementationText -match '<(?:TASK-BASE|FINAL-TREE)-SHA>') { throw 'Pinned implementation provenance fixture replacement failed' }
   Set-Content -Encoding utf8 -LiteralPath $implementationPath -Value $implementationText
 }
 
+function Sync-ReviewChangeHygieneRows([string]$Root) {
+  $implementationPath = Join-Path $Root 'artifacts/implementation-report.md'
+  $implementation = Get-Content -Raw -Encoding utf8 -LiteralPath $implementationPath
+  $implementationSection = [regex]::Match($implementation, '(?ms)^## Change Hygiene\s*\r?\n(?<body>.*?)(?=^## )')
+  if (-not $implementationSection.Success) { throw 'Implementation Change Hygiene section is missing for review synchronization' }
+  $implementationRows = @($implementationSection.Groups['body'].Value -split '\r?\n' | Where-Object { $_ -cmatch '^\| (?:WORK|UNIT)-' })
+  if ($implementationRows.Count -eq 0) { throw 'Implementation Change Hygiene data rows are missing for review synchronization' }
+  $reviewRows = [Collections.Generic.List[string]]::new()
+  foreach ($implementationRow in $implementationRows) {
+    $cells = @($implementationRow.Trim().Substring(1, $implementationRow.Trim().Length - 2).Split('|') | ForEach-Object { $_.Trim() })
+    if ($cells.Count -ne 9) { throw "Implementation Change Hygiene row is malformed: $implementationRow" }
+    $severity = if ($cells[5] -ceq 'none') { 'none' } else { 'Major' }
+    $reviewRows.Add("| $($cells[0]) | $($cells[1])#$($cells[3]) | $($cells[4]) | $($cells[5]) | $severity | $($cells[7]) | $($cells[8]) |")
+  }
+  $reviewPath = Join-Path $Root 'artifacts/review-report.md'
+  $review = Get-Content -Raw -Encoding utf8 -LiteralPath $reviewPath
+  $rowEnvelopePattern = '(?ms)(^## Change Hygiene\s*\r?\n.*?^\|---\|---\|---\|---\|---\|---\|---\|\s*\r?\n)(?:^\|[^\r\n]+\|\s*\r?\n)*'
+  if (-not [regex]::IsMatch($review, $rowEnvelopePattern)) { throw 'Review Change Hygiene row envelope is missing for synchronization' }
+  $updatedReview = [regex]::Replace($review, $rowEnvelopePattern, { param($match) $match.Groups[1].Value + (($reviewRows.ToArray() -join "`n") + "`n") }, 1)
+  Set-Content -Encoding utf8 -LiteralPath $reviewPath -Value $updatedReview
+}
+
 function New-ArchitectureReviewFixture {
   param([scriptblock]$Mutation, [bool]$IncludeIndependentReviewEvidence = $false, [bool]$IncrementalOwnerEdit = $false, [bool]$DeleteLegacyOwner = $false)
 
   $root = Join-Path ([IO.Path]::GetTempPath()) ('aitoolkit-architecture-review-' + [guid]::NewGuid().ToString('N'))
   foreach ($relativeDirectory in @('artifacts', 'contracts', 'skills/shared/ai-review', 'skills/shared/knowledge-base', 'templates/migration', 'templates')) {
     [void](New-Item -ItemType Directory -Force -Path (Join-Path $root $relativeDirectory))
   }
   Set-Content -Encoding utf8 -LiteralPath (Join-Path $root 'contracts/target-structure-conformance.md') -Value $contractText
   Set-Content -Encoding utf8 -LiteralPath (Join-Path $root 'contracts/file-responsibility-conformance.md') -Value $responsibilityContractText
   Set-Content -Encoding utf8 -LiteralPath (Join-Path $root 'skills/shared/ai-review/SKILL.md') -Value $canonicalReviewSkill
@@ -404,20 +459,21 @@ function New-ArchitectureReviewFixture {
     Write-PinnedReviewProvenance $root $pinnedSource
     if ($IncrementalOwnerEdit) {
       $implementationPath = Join-Path $root 'artifacts/implementation-report.md'
       $implementation = Get-Content -Raw -Encoding utf8 -LiteralPath $implementationPath
       $sourceRows = @($implementation -split '\r?\n' | Where-Object { $_ -cmatch '^\| WORK-ADMIN \| src/admin_route\.source \|' })
       if ($sourceRows.Count -ne 1) { throw 'Incremental Change Hygiene source row is missing or duplicated' }
       $updatedSourceRow = $sourceRows[0].Replace('| new |', '| existing |')
       $verificationRow = "| WORK-ADMIN | test/admin_route_test.ps1 | existing | AdminRouteContract | none | none | none | $($pinnedSource.TaskBaseSha) | $($pinnedSource.FinalTreeSha) |"
       $implementation = $implementation.Replace($sourceRows[0], "$updatedSourceRow`n$verificationRow")
       Set-Content -Encoding utf8 -LiteralPath $implementationPath -Value $implementation
+      Sync-ReviewChangeHygieneRows $root
     }
   }
   if ($null -ne $Mutation) {
     $mutationPaths = [Collections.Generic.List[string]]::new()
     @(
       'skills/shared/ai-review/SKILL.md',
       'skills/shared/knowledge-base/SKILL.md',
       'templates/migration/review-report.md',
       'templates/kb-entry.md'
     ) | ForEach-Object { $mutationPaths.Add($_) }
@@ -470,29 +526,32 @@ function Assert-FailsLike([string]$Name, [scriptblock]$Mutation, [string]$Patter
     throw "$Name failed for the wrong reason: $($caseErrors -join '; ')"
   }
   Write-Output "PASS: $Name"
 }
 
 function Set-RenderedReviewFixture([string]$Root, [string]$AdapterKind, [bool]$KeepSelectedUnit) {
   $path = Join-Path $Root 'templates/migration/review-report.md'
   $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
   $text = $text.Replace('| <RUN-*> | <master spec reference> | <SPEC-*> | <revision> | <master plan reference> | <PLAN-*> | <revision> | <WORK-*> |', '| RUN-ADMIN-001 | master-spec.md | SPEC-ADMIN-001 | 1 | master-plan.md | PLAN-ADMIN-001 | 1 | WORK-ADMIN-A |')
   $text = $text.Replace('<migration-unit | task | story | package | phase | milestone | none>', $AdapterKind)
-  foreach ($index in 1..5) {
+  $text = $text.Replace('<RESOLVED | BLOCKED>', 'RESOLVED')
+  foreach ($index in 1..6) {
     $verdictIndex = $text.IndexOf('<PASS | BLOCKED>', [StringComparison]::Ordinal)
     if ($verdictIndex -lt 0) { throw "Rendered review fixture cannot find PASS/BLOCKED schema value $index" }
     $text = $text.Remove($verdictIndex, '<PASS | BLOCKED>'.Length).Insert($verdictIndex, 'PASS')
   }
   $activation = if ($AdapterKind -ceq 'none') { 'NOT_APPLICABLE' } else { 'PASS' }
   $text = $text.Replace('<PASS | BLOCKED | NOT_APPLICABLE>', $activation)
   $text = $text.Replace('<NOT_RUN | COMPLETE>', 'COMPLETE')
+  $text = $text.Replace('<non-negative integer>', '0')
   $text = $text.Replace('<Approve | Approve-with-fixes | Reject>', 'Approve')
+  $text = $text.Replace('| 1 | <tree verdict> | <responsibility verdict> | <verification verdict> | <derived architecture state> | source-diff:<task-base SHA>..<final-tree SHA>#<WORK-*> |', '| 1 | PASS | PASS | PASS | PASS | source-diff:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa..bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb#WORK-ADMIN-A |')
   if ($KeepSelectedUnit) {
     $text = $text.Replace('| <UNIT-001> | <plan> | <approval> | <mode> | <scope> | <foundation ID> | <foundation reference> | <foundation approval> | <baseline> | <trace IDs> |', '| UNIT-001 | migration-plan.md | approval:UNIT-001 | incremental | required | not-applicable | not-applicable | not-applicable | baseline.md | REQ-001 |')
   }
   else {
     $text = [regex]::Replace($text, '(?ms)^## Selected Migration Unit\r?\n.*?(?=^## Rule Resolution)', '')
   }
   Set-Content -Encoding utf8 -LiteralPath $path -Value $text
 }
 
 function Set-RenderedKbFixture([string]$Root, [string]$ScopeRow) {
@@ -553,20 +612,21 @@ function Approve-DeletedOwner([string]$Root) {
 
   $reviewPath = Join-Path $Root 'artifacts/review-report.md'
   $review = Get-Content -Raw -Encoding utf8 -LiteralPath $reviewPath
   $deletedEvidence = "source:${taskBaseSha}:src/obsolete_route.source#ObsoleteRoute; diff:${taskBaseSha}..${finalTreeSha}:src/obsolete_route.source#ObsoleteRoute; source:${taskBaseSha}:src/obsolete_route.source#VERIFY-OWNER-OBSOLETE; diff:${taskBaseSha}..${finalTreeSha}:src/obsolete_route.source#VERIFY-OWNER-OBSOLETE"
   $reviewRow = "| RESP-OBSOLETE | $deletedEvidence | ObsoleteRoute | removed | route registration | removed | PASS |"
   $reviewAnchorRows = @($review -split '\r?\n' | Where-Object { $_ -cmatch '^\| RESP-ADMIN \|' })
   if ($reviewAnchorRows.Count -ne 1) { throw 'Approved deleted owner review fixture anchor is missing or duplicated' }
   $updatedReview = $review.Replace($reviewAnchorRows[0], "$($reviewAnchorRows[0])`n$reviewRow")
   if ($updatedReview -ceq $review) { throw 'Approved deleted owner review fixture replacement failed' }
   Set-Content -Encoding utf8 -LiteralPath $reviewPath -Value $updatedReview
+  Sync-ReviewChangeHygieneRows $Root
 }
 
 function Add-SourceSymbolEvidence([string]$Root, [string]$Symbol, [string]$ResponsibilityId) {
   $provenancePath = Join-Path $Root 'artifacts/review-provenance.md'
   $provenance = Get-Content -Raw -Encoding utf8 -LiteralPath $provenancePath
   $sourceRoot = [regex]::Match($provenance, '(?m)^Source Root:\s*(?<value>.+)$').Groups['value'].Value.Trim()
   $taskBaseSha = [regex]::Match($provenance, '(?im)^Task-base SHA:[ \t]*(?<value>[0-9a-f]{40})[ \t]*\r?$').Groups['value'].Value
   $previousFinalTreeSha = [regex]::Match($provenance, '(?im)^Final-tree SHA:[ \t]*(?<value>[0-9a-f]{40})[ \t]*\r?$').Groups['value'].Value
   $sourcePath = Join-Path $sourceRoot 'src/admin_route.source'
   $text = Get-Content -Raw -Encoding utf8 -LiteralPath $sourcePath
@@ -608,43 +668,45 @@ function Add-MarkerlessProductionPath([string]$Root) {
   $implementation = (Get-Content -Raw -Encoding utf8 -LiteralPath $implementationPath).Replace($previousFinalTreeSha, $finalTreeSha)
   $anchorRows = @($implementation -split '\r?\n' | Where-Object { $_ -cmatch '^\| WORK-ADMIN \| src/admin_route\.source \|' })
   if ($anchorRows.Count -ne 1) { throw 'Markerless production Change Hygiene anchor is missing or duplicated' }
   $markerlessRow = "| WORK-ADMIN | src/markerless_route.source | new | MarkerlessRoute | none | none | none | $taskBaseSha | $finalTreeSha |"
   $implementation = $implementation.Replace($anchorRows[0], "$($anchorRows[0])`n$markerlessRow")
   Set-Content -Encoding utf8 -LiteralPath $implementationPath -Value $implementation
 
   $reviewPath = Join-Path $Root 'artifacts/review-report.md'
   $review = (Get-Content -Raw -Encoding utf8 -LiteralPath $reviewPath).Replace($previousFinalTreeSha, $finalTreeSha)
   Set-Content -Encoding utf8 -LiteralPath $reviewPath -Value $review
+  Sync-ReviewChangeHygieneRows $Root
   Set-Content -Encoding utf8 -LiteralPath $provenancePath -Value "Source Root: $sourceRoot`nTask-base SHA: $taskBaseSha`nFinal-tree SHA: $finalTreeSha`n"
 }
 
 function Add-DeletedNonOwnerPath([string]$Root, [bool]$ValidCheckpoint) {
   $provenancePath = Join-Path $Root 'artifacts/review-provenance.md'
   $provenance = Get-Content -Raw -Encoding utf8 -LiteralPath $provenancePath
   $sourceRoot = [regex]::Match($provenance, '(?m)^Source Root:\s*(?<value>.+)$').Groups['value'].Value.Trim()
   $taskBaseSha = [regex]::Match($provenance, '(?im)^Task-base SHA:[ \t]*(?<value>[0-9a-f]{40})[ \t]*\r?$').Groups['value'].Value
   $previousFinalTreeSha = [regex]::Match($provenance, '(?im)^Final-tree SHA:[ \t]*(?<value>[0-9a-f]{40})[ \t]*\r?$').Groups['value'].Value
   Remove-Item -LiteralPath (Join-Path $sourceRoot 'README') -Force
   Invoke-PinnedSourceGit $sourceRoot @('add', '--all', '--', 'README') | Out-Null
   Invoke-PinnedSourceGit $sourceRoot @('commit', '-m', 'delete non-owner readme') | Out-Null
   $finalTreeSha = Invoke-PinnedSourceGit $sourceRoot @('rev-parse', 'HEAD')
   $checkpoint = if ($ValidCheckpoint) { "source:${taskBaseSha}:README; diff:${taskBaseSha}..${finalTreeSha}:README" } else { 'none' }
   $implementationPath = Join-Path $Root 'artifacts/implementation-report.md'
   $implementation = (Get-Content -Raw -Encoding utf8 -LiteralPath $implementationPath).Replace($previousFinalTreeSha, $finalTreeSha)
   $anchorRows = @($implementation -split '\r?\n' | Where-Object { $_ -cmatch '^\| WORK-ADMIN \| src/admin_route\.source \|' })
   if ($anchorRows.Count -ne 1) { throw 'Deleted non-owner Change Hygiene anchor is missing or duplicated' }
-  $deletedRow = "| WORK-ADMIN | README | deleted | repository readme | none | none | $checkpoint | $taskBaseSha | $finalTreeSha |"
+  $deletedRow = "| WORK-ADMIN | README | deleted | README | none | none | $checkpoint | $taskBaseSha | $finalTreeSha |"
   Set-Content -Encoding utf8 -LiteralPath $implementationPath -Value $implementation.Replace($anchorRows[0], "$($anchorRows[0])`n$deletedRow")
   $reviewPath = Join-Path $Root 'artifacts/review-report.md'
   $review = (Get-Content -Raw -Encoding utf8 -LiteralPath $reviewPath).Replace($previousFinalTreeSha, $finalTreeSha)
   Set-Content -Encoding utf8 -LiteralPath $reviewPath -Value $review
+  Sync-ReviewChangeHygieneRows $Root
   Set-Content -Encoding utf8 -LiteralPath $provenancePath -Value "Source Root: $sourceRoot`nTask-base SHA: $taskBaseSha`nFinal-tree SHA: $finalTreeSha`n"
 }
 
 function Rename-ProductionOwner(
   [string]$Root,
   [bool]$ExplicitMapping,
   [string]$DestinationPath = 'docs/admin_route.source'
 ) {
   $provenancePath = Join-Path $Root 'artifacts/review-provenance.md'
   $provenance = Get-Content -Raw -Encoding utf8 -LiteralPath $provenancePath
@@ -672,20 +734,21 @@ function Rename-ProductionOwner(
   $checkpoint = if ($ExplicitMapping) { "source:${taskBaseSha}:src/admin_route.source; diff:${taskBaseSha}..${finalTreeSha}:src/admin_route.source->${DestinationPath}" } else { "source:${taskBaseSha}:src/admin_route.source; diff:${taskBaseSha}..${finalTreeSha}:${DestinationPath}" }
   $updatedSourceRow = [regex]::Replace($sourceRows[0], '\| none \| (?=[0-9a-f]{40} \| [0-9a-f]{40} \|$)', "| $checkpoint | ")
   if ($updatedSourceRow -ceq $sourceRows[0]) { throw 'Renamed production checkpoint replacement failed' }
   Set-Content -Encoding utf8 -LiteralPath $implementationPath -Value $implementation.Replace($sourceRows[0], $updatedSourceRow)
   $reviewPath = Join-Path $Root 'artifacts/review-report.md'
   $review = Get-Content -Raw -Encoding utf8 -LiteralPath $reviewPath
   if ($ExplicitMapping) {
     $review = $review.Replace("diff:${taskBaseSha}..${finalTreeSha}:${DestinationPath}#", "diff:${taskBaseSha}..${finalTreeSha}:src/admin_route.source->${DestinationPath}#")
   }
   Set-Content -Encoding utf8 -LiteralPath $reviewPath -Value $review
+  Sync-ReviewChangeHygieneRows $Root
   Set-Content -Encoding utf8 -LiteralPath $provenancePath -Value "Source Root: $sourceRoot`nTask-base SHA: $taskBaseSha`nFinal-tree SHA: $finalTreeSha`n"
 }
 
 function Set-PinnedProductionBindings(
   [string]$Root,
   [string[]]$BindingPaths,
   [bool]$UseWindowsArtifactPaths = $false
 ) {
   $provenancePath = Join-Path $Root 'artifacts/review-provenance.md'
   $provenance = Get-Content -Raw -Encoding utf8 -LiteralPath $provenancePath
@@ -704,20 +767,87 @@ function Set-PinnedProductionBindings(
 
   foreach ($relativePath in @('artifacts/design-report.md', 'artifacts/implementation-report.md', 'artifacts/review-report.md')) {
     $path = Join-Path $Root $relativePath
     $text = (Get-Content -Raw -Encoding utf8 -LiteralPath $path).Replace($previousFinalTreeSha, $finalTreeSha)
     $updated = if ($UseWindowsArtifactPaths) { $text.Replace('src/admin_route.source', 'src\admin_route.source') } else { $text }
     Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
   }
   Set-Content -Encoding utf8 -LiteralPath $provenancePath -Value "Source Root: $sourceRoot`nTask-base SHA: $taskBaseSha`nFinal-tree SHA: $finalTreeSha`n"
 }
 
+function Comment-OutPinnedVerificationEvidence([string]$Root) {
+  $provenancePath = Join-Path $Root 'artifacts/review-provenance.md'
+  $provenance = Get-Content -Raw -Encoding utf8 -LiteralPath $provenancePath
+  $sourceRoot = [regex]::Match($provenance, '(?m)^Source Root:\s*(?<value>.+)$').Groups['value'].Value.Trim()
+  $taskBaseSha = [regex]::Match($provenance, '(?im)^Task-base SHA:[ \t]*(?<value>[0-9a-f]{40})[ \t]*\r?$').Groups['value'].Value
+  $previousFinalTreeSha = [regex]::Match($provenance, '(?im)^Final-tree SHA:[ \t]*(?<value>[0-9a-f]{40})[ \t]*\r?$').Groups['value'].Value
+  $verificationPath = Join-Path $sourceRoot 'test/admin_route_test.ps1'
+  $verificationText = Get-Content -Raw -Encoding utf8 -LiteralPath $verificationPath
+  Set-Content -Encoding utf8 -LiteralPath $verificationPath -Value "<#`n$verificationText`n#>"
+  Invoke-PinnedSourceGit $sourceRoot @('add', '--', 'test/admin_route_test.ps1') | Out-Null
+  Invoke-PinnedSourceGit $sourceRoot @('commit', '-m', 'comment out verification evidence') | Out-Null
+  $finalTreeSha = Invoke-PinnedSourceGit $sourceRoot @('rev-parse', 'HEAD')
+  foreach ($relativePath in @('artifacts/design-report.md', 'artifacts/implementation-report.md', 'artifacts/review-report.md')) {
+    $path = Join-Path $Root $relativePath
+    $text = (Get-Content -Raw -Encoding utf8 -LiteralPath $path).Replace($previousFinalTreeSha, $finalTreeSha)
+    Set-Content -Encoding utf8 -LiteralPath $path -Value $text
+  }
+  Set-Content -Encoding utf8 -LiteralPath $provenancePath -Value "Source Root: $sourceRoot`nTask-base SHA: $taskBaseSha`nFinal-tree SHA: $finalTreeSha`n"
+}
+
+function Use-LanguageValidPinnedVerificationMarkers([string]$Root, [bool]$WrapInBlockComment = $false) {
+  $provenancePath = Join-Path $Root 'artifacts/review-provenance.md'
+  $provenance = Get-Content -Raw -Encoding utf8 -LiteralPath $provenancePath
+  $sourceRoot = [regex]::Match($provenance, '(?m)^Source Root:\s*(?<value>.+)$').Groups['value'].Value.Trim()
+  $taskBaseSha = [regex]::Match($provenance, '(?im)^Task-base SHA:[ \t]*(?<value>[0-9a-f]{40})[ \t]*\r?$').Groups['value'].Value
+  $previousFinalTreeSha = [regex]::Match($provenance, '(?im)^Final-tree SHA:[ \t]*(?<value>[0-9a-f]{40})[ \t]*\r?$').Groups['value'].Value
+  $verificationPath = Join-Path $sourceRoot 'test/admin_route_test.ps1'
+  $verificationLines = @(Get-Content -Encoding utf8 -LiteralPath $verificationPath)
+  $encodedVerification = @($verificationLines | ForEach-Object {
+    if ($_ -cmatch '^(?:@[a-z]|scenario\s)') { "# arc:$_" } else { $_ }
+  }) -join "`n"
+  if ($WrapInBlockComment) { $encodedVerification = "<#`n$encodedVerification`n#>" }
+  Set-Content -Encoding utf8 -LiteralPath $verificationPath -Value $encodedVerification
+  Invoke-PinnedSourceGit $sourceRoot @('add', '--', 'test/admin_route_test.ps1') | Out-Null
+  Invoke-PinnedSourceGit $sourceRoot @('commit', '-m', $(if ($WrapInBlockComment) { 'disable language-valid verification markers' } else { 'use language-valid verification markers' })) | Out-Null
+  $finalTreeSha = Invoke-PinnedSourceGit $sourceRoot @('rev-parse', 'HEAD')
+
+  foreach ($relativePath in @('artifacts/design-report.md', 'artifacts/implementation-report.md', 'artifacts/review-report.md')) {
+    $path = Join-Path $Root $relativePath
+    $text = (Get-Content -Raw -Encoding utf8 -LiteralPath $path).Replace($previousFinalTreeSha, $finalTreeSha)
+    Set-Content -Encoding utf8 -LiteralPath $path -Value $text
+  }
+  $implementationPath = Join-Path $Root 'artifacts/implementation-report.md'
+  $implementation = Get-Content -Raw -Encoding utf8 -LiteralPath $implementationPath
+  $sourceRows = @($implementation -split '\r?\n' | Where-Object { $_ -cmatch '^\| WORK-ADMIN \| src/admin_route\.source \|' })
+  if ($sourceRows.Count -ne 1) { throw 'Language-valid marker Change Hygiene anchor is missing or duplicated' }
+  $verificationRow = "| WORK-ADMIN | test/admin_route_test.ps1 | existing | AdminRouteContract | none | none | none | $taskBaseSha | $finalTreeSha |"
+  Set-Content -Encoding utf8 -LiteralPath $implementationPath -Value $implementation.Replace($sourceRows[0], "$($sourceRows[0])`n$verificationRow")
+  Sync-ReviewChangeHygieneRows $Root
+  Set-Content -Encoding utf8 -LiteralPath $provenancePath -Value "Source Root: $sourceRoot`nTask-base SHA: $taskBaseSha`nFinal-tree SHA: $finalTreeSha`n"
+}
+
+function Set-UnrelatedReachableTaskBase([string]$Root) {
+  $provenancePath = Join-Path $Root 'artifacts/review-provenance.md'
+  $provenance = Get-Content -Raw -Encoding utf8 -LiteralPath $provenancePath
+  $sourceRoot = [regex]::Match($provenance, '(?m)^Source Root:\s*(?<value>.+)$').Groups['value'].Value.Trim()
+  $taskBaseSha = [regex]::Match($provenance, '(?im)^Task-base SHA:[ \t]*(?<value>[0-9a-f]{40})[ \t]*\r?$').Groups['value'].Value
+  $baseTreeSha = Invoke-PinnedSourceGit $sourceRoot @('rev-parse', "$taskBaseSha^{tree}")
+  $unrelatedTaskBaseSha = Invoke-PinnedSourceGit $sourceRoot @('commit-tree', $baseTreeSha, '-m', 'unrelated reachable task base')
+  Invoke-PinnedSourceGit $sourceRoot @('branch', 'unrelated-task-base', $unrelatedTaskBaseSha) | Out-Null
+  foreach ($relativePath in @('artifacts/design-report.md', 'artifacts/implementation-report.md', 'artifacts/review-report.md', 'artifacts/review-provenance.md')) {
+    $path = Join-Path $Root $relativePath
+    $text = (Get-Content -Raw -Encoding utf8 -LiteralPath $path).Replace($taskBaseSha, $unrelatedTaskBaseSha)
+    Set-Content -Encoding utf8 -LiteralPath $path -Value $text
+  }
+}
+
 function Convert-ReviewPathsToWindows([string]$Root) {
   Set-PinnedProductionBindings $Root @('src\admin_route.source') $true
 }
 
 function Keep-ImplementationSelfAttestationPass([string]$Root) {
   $path = Join-Path $Root 'artifacts/implementation-report.md'
   $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
   $updated = $text.Replace('Architecture Conformance State: NOT_REVIEWED', 'Architecture Conformance State: PASS')
   if ($updated -ceq $text) { throw 'Implementation self-attestation fixture replacement failed' }
   Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
@@ -764,20 +894,29 @@ Assert-FailsLike 'non-PASS overall review conclusion is not executable despite P
 
 Assert-FailsLike 'Critical-bearing review is not executable despite PASS architecture verdicts' {
   param($root)
   $path = Join-Path $root 'artifacts/review-report.md'
   $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
   $updated = $text.Replace('- Critical count: 0', '- Critical count: 1')
   if ($updated -ceq $text) { throw 'Critical-bearing review fixture replacement failed' }
   Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
 } 'responsibility-waiver-forbidden' $true
 
+Assert-FailsLike 'independent review handoff cells must equal the visible derived verdicts' {
+  param($root)
+  $path = Join-Path $root 'artifacts/review-report.md'
+  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
+  $updated = $text.Replace('| 1 | PASS | PASS | PASS | PASS | source-diff:', '| 1 | BLOCKED | PASS | PASS | BLOCKED | source-diff:')
+  if ($updated -ceq $text) { throw 'Contradictory independent handoff fixture replacement failed' }
+  Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
+} 'responsibility-waiver-forbidden' $true
+
 Assert-FailsLike 'review rejects a canonically production-classified markerless route even when Change Hygiene lists the path' {
   param($root)
   Add-MarkerlessProductionPath $root
 } 'responsibility-evidence-missing|responsibility-owner-extra' $true
 
 foreach ($gitStatusCase in @('A', 'M', 'R', 'C')) {
   $sourceRoot = Join-Path ([IO.Path]::GetTempPath()) ('aitoolkit-markerless-status-' + [guid]::NewGuid().ToString('N'))
   try {
     [void](New-Item -ItemType Directory -Force -Path (Join-Path $sourceRoot 'src'))
     Invoke-PinnedSourceGit $sourceRoot @('init') | Out-Null
@@ -900,35 +1039,38 @@ try {
   }
   Write-Output 'PASS: blank/comment-only content beside a responsibility block remains valid'
 }
 finally {
   if (Test-Path -LiteralPath $commentOnlyRoot) { Remove-Item -LiteralPath $commentOnlyRoot -Recurse -Force }
 }
 
 function Invoke-LexicalSourceInventoryProbe(
   [string]$Name,
   [string]$NewLine,
-  [string]$SourceText
+  [string]$SourceText,
+  [string]$RelativePath = 'src/lexical.source'
 ) {
   $probeRoot = Join-Path ([IO.Path]::GetTempPath()) ("aitoolkit-lexical-$Name-" + [guid]::NewGuid().ToString('N'))
   try {
     [void](New-Item -ItemType Directory -Force -Path (Join-Path $probeRoot 'src'))
     Invoke-PinnedSourceGit $probeRoot @('init') | Out-Null
     Invoke-PinnedSourceGit $probeRoot @('config', 'core.autocrlf', 'false') | Out-Null
     Invoke-PinnedSourceGit $probeRoot @('config', 'user.email', 'fixtures@example.test') | Out-Null
     Invoke-PinnedSourceGit $probeRoot @('config', 'user.name', 'AIToolkit fixture') | Out-Null
     [IO.File]::WriteAllText((Join-Path $probeRoot 'README'), 'lexical base', [Text.UTF8Encoding]::new($false))
     Invoke-PinnedSourceGit $probeRoot @('add', '--all') | Out-Null
     Invoke-PinnedSourceGit $probeRoot @('commit', '-m', 'lexical base') | Out-Null
     $taskBaseSha = Invoke-PinnedSourceGit $probeRoot @('rev-parse', 'HEAD')
     $renderedSource = [regex]::Replace($SourceText, '\r\n|\r|\n', $NewLine)
-    [IO.File]::WriteAllText((Join-Path $probeRoot 'src/lexical.source'), $renderedSource, [Text.UTF8Encoding]::new($false))
+    $sourcePath = Join-Path $probeRoot $RelativePath
+    [void](New-Item -ItemType Directory -Force -Path (Split-Path -Parent $sourcePath))
+    [IO.File]::WriteAllText($sourcePath, $renderedSource, [Text.UTF8Encoding]::new($false))
     Invoke-PinnedSourceGit $probeRoot @('add', '--all') | Out-Null
     Invoke-PinnedSourceGit $probeRoot @('commit', '-m', "lexical $Name") | Out-Null
     $finalTreeSha = Invoke-PinnedSourceGit $probeRoot @('rev-parse', 'HEAD')
     $inventoryErrors = [Collections.Generic.List[string]]::new()
     $sourceInventory = Get-ArcPinnedSourceInventory -SourceRoot $probeRoot -TaskBaseSha $taskBaseSha -FinalTreeSha $finalTreeSha -Errors $inventoryErrors
     return [pscustomobject]@{
       Errors = @($inventoryErrors)
       OwnerCount = @($sourceInventory.ActiveOwners | Where-Object { $_.Id -ceq 'RESP-LEXICAL' }).Count
     }
   }
@@ -971,20 +1113,94 @@ $lexicalOwnerMetadata
 class LexicalOwner { int run() { return 1; } }
 
 // trailing C-family comment
 "@
   $commentMatrix = Invoke-LexicalSourceInventoryProbe "comments-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $commentMatrixSource
   if ($commentMatrix.Errors.Count -ne 0 -or $commentMatrix.OwnerCount -ne 1) {
     throw "legitimate language comment matrix ($($lexicalLineEnding.Name)) should remain valid: $($commentMatrix.Errors -join '; ')"
   }
   Write-Output "PASS: legitimate language comment matrix remains valid ($($lexicalLineEnding.Name))"
 
+  foreach ($languageAwareRogueCase in @(
+    [pscustomobject]@{ Name = 'spaced-c-decrement'; Path = 'src/lexical.c'; Code = '-- counter;' },
+    [pscustomobject]@{ Name = 'spaced-js-decrement'; Path = 'src/lexical.js'; Code = '-- counter;' },
+    [pscustomobject]@{ Name = 'spaced-c-empty-statement'; Path = 'src/lexical.c'; Code = '; danger();' },
+    [pscustomobject]@{ Name = 'rust-spaced-attribute'; Path = 'src/lexical.rs'; Code = '# [cfg(test)]' },
+    [pscustomobject]@{ Name = 'csharp-region-directive'; Path = 'src/lexical.cs'; Code = '# region outside_owner' }
+  )) {
+    $rogueSource = "$lexicalOwnerMetadata`nclass LexicalOwner { int run() { return 1; } }`n$($languageAwareRogueCase.Code)"
+    $rogueResult = Invoke-LexicalSourceInventoryProbe "$($languageAwareRogueCase.Name)-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $rogueSource $languageAwareRogueCase.Path
+    if ($rogueResult.Errors -cnotcontains 'responsibility-evidence-missing') {
+      throw "$($languageAwareRogueCase.Name) outside responsibility coverage was incorrectly classified as a comment ($($lexicalLineEnding.Name))"
+    }
+    Write-Output "PASS: $($languageAwareRogueCase.Name) remains executable or fail-closed ($($lexicalLineEnding.Name))"
+  }
+
+  foreach ($languageCommentCase in @(
+    [pscustomobject]@{ Name = 'sql-dash-comment'; Path = 'src/lexical.sql'; Comment = '-- true SQL comment' },
+    [pscustomobject]@{ Name = 'lisp-semicolon-comment'; Path = 'src/lexical.lisp'; Comment = '; true Lisp comment' },
+    [pscustomobject]@{ Name = 'python-hash-comment'; Path = 'src/lexical.py'; Comment = '# true Python comment' },
+    [pscustomobject]@{ Name = 'powershell-hash-comment'; Path = 'src/lexical.ps1'; Comment = '# true PowerShell comment' },
+    [pscustomobject]@{ Name = 'c-slash-comment'; Path = 'src/lexical.c'; Comment = '// true C comment' }
+  )) {
+    $commentSource = "$($languageCommentCase.Comment)`n$lexicalOwnerMetadata`nclass LexicalOwner { int run() { return 1; } }"
+    $commentResult = Invoke-LexicalSourceInventoryProbe "$($languageCommentCase.Name)-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $commentSource $languageCommentCase.Path
+    if ($commentResult.Errors.Count -ne 0 -or $commentResult.OwnerCount -ne 1) {
+      throw "$($languageCommentCase.Name) was not preserved as a true language comment ($($lexicalLineEnding.Name)): $($commentResult.Errors -join '; ')"
+    }
+    Write-Output "PASS: $($languageCommentCase.Name) remains comment-only ($($lexicalLineEnding.Name))"
+  }
+
+  $semanticMarkerPayloads = @($lexicalOwnerMetadata -split '\r?\n' | Where-Object { $_ -ne '' })
+  foreach ($languageMarkerCase in @(
+    [pscustomobject]@{ Name = 'dart'; Path = 'lib/lexical_owner.dart'; Prefix = '// arc:'; DisabledPrefix = '// disabled arc:'; Body = 'class LexicalOwner {}' },
+    [pscustomobject]@{ Name = 'java'; Path = 'src/LexicalOwner.java'; Prefix = '// arc:'; DisabledPrefix = '// disabled arc:'; Body = 'class LexicalOwner {}' },
+    [pscustomobject]@{ Name = 'javascript-module'; Path = 'src/lexical_owner.mjs'; Prefix = '// arc:'; DisabledPrefix = '// disabled arc:'; Body = 'export class LexicalOwner {}' },
+    [pscustomobject]@{ Name = 'python'; Path = 'src/lexical_owner.py'; Prefix = '# arc:'; DisabledPrefix = '# disabled arc:'; Body = "class LexicalOwner:`n    pass" },
+    [pscustomobject]@{ Name = 'csharp'; Path = 'src/LexicalOwner.cs'; Prefix = '// arc:'; DisabledPrefix = '// disabled arc:'; Body = 'class LexicalOwner {}' },
+    [pscustomobject]@{ Name = 'rust'; Path = 'src/lexical_owner.rs'; Prefix = '// arc:'; DisabledPrefix = '// disabled arc:'; Body = 'struct LexicalOwner { value: i32 }' }
+  )) {
+    $encodedMarkers = @($semanticMarkerPayloads | ForEach-Object { "$($languageMarkerCase.Prefix)$_" }) -join "`n"
+    $languageValidSource = "$encodedMarkers`n$($languageMarkerCase.Body)"
+    $languageValidResult = Invoke-LexicalSourceInventoryProbe "semantic-$($languageMarkerCase.Name)-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $languageValidSource $languageMarkerCase.Path
+    if ($languageValidResult.Errors.Count -ne 0 -or $languageValidResult.OwnerCount -ne 1) {
+      throw "language-valid $($languageMarkerCase.Name) semantic markers were not consumed ($($lexicalLineEnding.Name)): $($languageValidResult.Errors -join '; ')"
+    }
+    Write-Output "PASS: language-valid $($languageMarkerCase.Name) semantic markers compose an active owner ($($lexicalLineEnding.Name))"
+
+    $disabledMarkers = @($semanticMarkerPayloads | ForEach-Object { "$($languageMarkerCase.DisabledPrefix)$_" }) -join "`n"
+    $disabledResult = Invoke-LexicalSourceInventoryProbe "semantic-disabled-$($languageMarkerCase.Name)-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $disabledMarkers $languageMarkerCase.Path
+    if ($disabledResult.OwnerCount -ne 0 -or $disabledResult.Errors -cnotcontains 'responsibility-evidence-missing') {
+      throw "ordinary commented-out $($languageMarkerCase.Name) markers became active ($($lexicalLineEnding.Name))"
+    }
+    Write-Output "PASS: ordinary commented-out $($languageMarkerCase.Name) markers remain inert ($($lexicalLineEnding.Name))"
+  }
+
+  $commentedOwnerSource = @"
+/*
+@responsibility RESP-LEXICAL
+@owner-symbol LexicalOwner
+@public-symbol LexicalOwner
+@owned-capability CAP-LEXICAL
+@effect route registration
+@architecture-authority target-exemplar
+@co-location-policy feature-local
+@verification-owner VERIFY-OWNER-LEXICAL
+route LexicalOwner -> LexicalProvider
+*/
+"@
+  $commentedOwner = Invoke-LexicalSourceInventoryProbe "commented-owner-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $commentedOwnerSource 'lib/commented_owner.dart'
+  if ($commentedOwner.OwnerCount -ne 0 -or $commentedOwner.Errors -cnotcontains 'responsibility-evidence-missing') {
+    throw "wholly commented production owner/route became active ($($lexicalLineEnding.Name))"
+  }
+  Write-Output "PASS: wholly commented production owner/route remains inactive ($($lexicalLineEnding.Name))"
+
   foreach ($roguePrefixCase in @(
     [pscustomobject]@{ Name = 'semicolon-call'; Code = ';danger()' },
     [pscustomobject]@{ Name = 'decrement'; Code = '--counter' },
     [pscustomobject]@{ Name = 'pointer-assignment'; Code = '*ptr = value' },
     [pscustomobject]@{ Name = 'inline-block-comment-then-call'; Code = '/* note */ danger()' }
   )) {
     $rogueSource = "$lexicalOwnerMetadata`nclass LexicalOwner { int run() { return 1; } }`n$($roguePrefixCase.Code)"
     $rogueResult = Invoke-LexicalSourceInventoryProbe "$($roguePrefixCase.Name)-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $rogueSource
     if ($rogueResult.Errors -cnotcontains 'responsibility-evidence-missing') {
       throw "$($roguePrefixCase.Name) markerless executable content was incorrectly classified as comment-only ($($lexicalLineEnding.Name))"
@@ -1018,20 +1234,36 @@ class LexicalOwner {
   int run() { return 1; }
 }
 danger()
 "@
   $braceRogue = Invoke-LexicalSourceInventoryProbe "brace-rogue-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $braceRogueSource
   if ($braceRogue.Errors -cnotcontains 'responsibility-evidence-missing') {
     throw "braces in strings/comments swallowed later rogue code ($($lexicalLineEnding.Name))"
   }
   Write-Output "PASS: braces in strings/comments cannot swallow later rogue code ($($lexicalLineEnding.Name))"
 
+  $javascriptRegexRogueSource = @"
+$lexicalOwnerMetadata
+class LexicalOwner {
+  run(value) {
+    const openingBrace = /{/g;
+    return openingBrace.test(value);
+  }
+}
+danger()
+"@
+  $javascriptRegexRogue = Invoke-LexicalSourceInventoryProbe "javascript-regex-rogue-$($lexicalLineEnding.Name)" $lexicalLineEnding.NewLine $javascriptRegexRogueSource 'src/lexical.js'
+  if ($javascriptRegexRogue.Errors -cnotcontains 'responsibility-evidence-missing') {
+    throw "JavaScript regex-literal braces swallowed later rogue code ($($lexicalLineEnding.Name))"
+  }
+  Write-Output "PASS: JavaScript regex-literal braces are inert and later rogue code remains unowned ($($lexicalLineEnding.Name))"
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
@@ -1164,20 +1396,69 @@ try {
   $selectedInventory = Get-ArcPinnedSourceInventory -SourceRoot $incidentalMarkerRoot -TaskBaseSha $taskBaseSha -FinalTreeSha $finalTreeSha -SelectedPaths @($incidentalPath) -Errors $selectedErrors
   if ($selectedErrors.Count -ne 0 -or @($selectedInventory.ActiveOwners | Where-Object { $_.Id -ceq 'RESP-DOCS-EXAMPLE' }).Count -ne 1) {
     throw "explicitly selected non-production owner authority was not parsed: $($selectedErrors -join '; ')"
   }
   Write-Output 'PASS: non-production markers are ignored unless explicitly selected as owner authority'
 }
 finally {
   if (Test-Path -LiteralPath $incidentalMarkerRoot) { Remove-Item -LiteralPath $incidentalMarkerRoot -Recurse -Force }
 }
 
+$copyDestinationRoot = Join-Path ([IO.Path]::GetTempPath()) ('aitoolkit-copy-destination-' + [guid]::NewGuid().ToString('N'))
+try {
+  $unicodeDirectory = -join @([char]0x0111, [char]0x01B0, [char]0x1EDD, 'n', 'g', ' ', 'd', [char]0x1EAB, 'n')
+  [void](New-Item -ItemType Directory -Force -Path (Join-Path $copyDestinationRoot 'src'))
+  [void](New-Item -ItemType Directory -Force -Path (Join-Path $copyDestinationRoot "docs/$unicodeDirectory"))
+  Invoke-PinnedSourceGit $copyDestinationRoot @('init') | Out-Null
+  Invoke-PinnedSourceGit $copyDestinationRoot @('config', 'core.autocrlf', 'false') | Out-Null
+  Invoke-PinnedSourceGit $copyDestinationRoot @('config', 'user.email', 'fixtures@example.test') | Out-Null
+  Invoke-PinnedSourceGit $copyDestinationRoot @('config', 'user.name', 'AIToolkit fixture') | Out-Null
+  $copyOwner = "@responsibility RESP-COPY`n@owner-symbol CopyRoute`n@public-symbol CopyRoute`n@owned-capability CAP-COPY`n@effect none`n@architecture-authority target-exemplar`n@co-location-policy feature-local`n@verification-owner VERIFY-OWNER-COPY`nclass CopyRoute {}"
+  $copyBasePath = 'src/copy_route.source'
+  $copyFinalPath = "docs/$unicodeDirectory/copy route.source"
+  if ((ConvertTo-ArcCanonicalRepositoryPath -Path $copyFinalPath) -cne $copyFinalPath) {
+    throw 'Canonical repository paths must preserve Unicode and embedded spaces'
+  }
+  foreach ($unsafePath in @('/src/absolute.source', 'C:/src/drive.source', 'src//alias.source', 'src/../traversal.source', "src/control$([char]1).source")) {
+    if ((ConvertTo-ArcCanonicalRepositoryPath -Path $unsafePath) -cne '') { throw "Unsafe repository path must be rejected: $unsafePath" }
+  }
+  Set-Content -Encoding utf8 -LiteralPath (Join-Path $copyDestinationRoot $copyBasePath) -Value $copyOwner
+  Invoke-PinnedSourceGit $copyDestinationRoot @('add', '--all') | Out-Null
+  Invoke-PinnedSourceGit $copyDestinationRoot @('commit', '-m', 'production copy source') | Out-Null
+  $copyTaskBaseSha = Invoke-PinnedSourceGit $copyDestinationRoot @('rev-parse', 'HEAD')
+  Copy-Item -LiteralPath (Join-Path $copyDestinationRoot $copyBasePath) -Destination (Join-Path $copyDestinationRoot $copyFinalPath)
+  Invoke-PinnedSourceGit $copyDestinationRoot @('add', '--all') | Out-Null
+  Invoke-PinnedSourceGit $copyDestinationRoot @('commit', '-m', 'copy production source into excluded docs') | Out-Null
+  $copyFinalTreeSha = Invoke-PinnedSourceGit $copyDestinationRoot @('rev-parse', 'HEAD')
+  $copyErrors = [Collections.Generic.List[string]]::new()
+  $copyInventory = Get-ArcPinnedSourceInventory -SourceRoot $copyDestinationRoot -TaskBaseSha $copyTaskBaseSha -FinalTreeSha $copyFinalTreeSha -Errors $copyErrors
+  $trailingRootErrors = [Collections.Generic.List[string]]::new()
+  $trailingRootInventory = Get-ArcPinnedSourceInventory -SourceRoot ($copyDestinationRoot + [IO.Path]::DirectorySeparatorChar) -TaskBaseSha $copyTaskBaseSha -FinalTreeSha $copyFinalTreeSha -Errors $trailingRootErrors
+  $copyRecord = @($copyInventory.ChangedPaths | Where-Object { $_.Status -ceq 'C' -and $_.BasePath -ceq $copyBasePath -and $_.FinalPath -ceq $copyFinalPath })
+  $trailingRootRecord = @($trailingRootInventory.ChangedPaths | Where-Object { $_.Status -ceq 'C' -and $_.BasePath -ceq $copyBasePath -and $_.FinalPath -ceq $copyFinalPath })
+  if (
+    $copyErrors.Count -ne 0 -or
+    $trailingRootErrors.Count -ne 0 -or
+    $copyRecord.Count -ne 1 -or
+    $trailingRootRecord.Count -ne 1 -or
+    $copyRecord[0].IsProduction -or
+    @($copyInventory.ActiveOwners).Count -ne 0 -or
+    @($copyInventory.DeletedOwners).Count -ne 0
+  ) {
+    throw "production-to-excluded copy must use destination-only classification: $($copyErrors -join '; ')"
+  }
+  Write-Output 'PASS: NUL-safe Unicode/space copy path and trailing source root preserve destination classification'
+}
+finally {
+  if (Test-Path -LiteralPath $copyDestinationRoot) { Remove-Item -LiteralPath $copyDestinationRoot -Recurse -Force }
+}
+
 $renameAuthorityRoot = Join-Path ([IO.Path]::GetTempPath()) ('aitoolkit-rename-authority-' + [guid]::NewGuid().ToString('N'))
 try {
   [void](New-Item -ItemType Directory -Force -Path (Join-Path $renameAuthorityRoot 'src'))
   [void](New-Item -ItemType Directory -Force -Path (Join-Path $renameAuthorityRoot 'docs'))
   Invoke-PinnedSourceGit $renameAuthorityRoot @('init') | Out-Null
   Invoke-PinnedSourceGit $renameAuthorityRoot @('config', 'core.autocrlf', 'false') | Out-Null
   Invoke-PinnedSourceGit $renameAuthorityRoot @('config', 'user.email', 'fixtures@example.test') | Out-Null
   Invoke-PinnedSourceGit $renameAuthorityRoot @('config', 'user.name', 'AIToolkit fixture') | Out-Null
   $keptOwner = "@responsibility RESP-RENAME-KEEP`n@owner-symbol RenameKeepRoute`n@public-symbol RenameKeepRoute`n@owned-capability CAP-RENAME-KEEP`n@effect route registration`n@architecture-authority target-exemplar`n@co-location-policy feature-local`n@verification-owner VERIFY-OWNER-RENAME-KEEP`nroute RenameKeepRoute -> RenameKeepProvider"
   $keptOwner += "`n" + ((1..30 | ForEach-Object { "# preserved rename context $_" }) -join "`n")
@@ -1228,37 +1509,136 @@ try {
   $sourceInventory = Get-ArcPinnedSourceInventory -SourceRoot $removedBlockRoot -TaskBaseSha $taskBaseSha -FinalTreeSha $finalTreeSha -Errors $inventoryErrors
   if ($inventoryErrors.Count -ne 0 -or @($sourceInventory.ActiveOwners | Where-Object { $_.Id -ceq 'RESP-KEEP' }).Count -ne 1 -or @($sourceInventory.DeletedOwners | Where-Object { $_.Id -ceq 'RESP-REMOVED' }).Count -ne 1) {
     throw "surviving-file owner removal did not enter deletion reconciliation: $($inventoryErrors -join '; ')"
   }
   Write-Output 'PASS: responsibility block removed from a surviving M path enters deletion reconciliation'
 }
 finally {
   if (Test-Path -LiteralPath $removedBlockRoot) { Remove-Item -LiteralPath $removedBlockRoot -Recurse -Force }
 }
 
+Assert-FailsLike 'Change Hygiene rejects a noncanonical edited region' {
+  param($root)
+  $path = Join-Path $root 'artifacts/implementation-report.md'
+  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
+  $updated = $text.Replace('| WORK-ADMIN | src/admin_route.source | new | AdminRoute | none | none |', '| WORK-ADMIN | src/admin_route.source | new | * | none | none |')
+  if ($updated -ceq $text) { throw 'Noncanonical edited-region fixture replacement failed' }
+  Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
+} 'change-hygiene-invalid' $true
+
+Assert-FailsLike 'Change Hygiene rejects a repository-wide formatter command' {
+  param($root)
+  foreach ($relativePath in @('artifacts/implementation-report.md', 'artifacts/review-report.md')) {
+    $path = Join-Path $root $relativePath
+    $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
+    $updated = if ($relativePath -ceq 'artifacts/implementation-report.md') {
+      $text.Replace('| AdminRoute | none | none |', '| AdminRoute | dart format . | none |')
+    }
+    else {
+      $text.Replace('| src/admin_route.source#AdminRoute | none | none | none |', '| src/admin_route.source#AdminRoute | dart format . | none | none |')
+    }
+    if ($updated -ceq $text) { throw "Repository-wide formatter fixture replacement failed: $relativePath" }
+    Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
+  }
+} 'change-hygiene-invalid' $true
+
+Assert-Pass 'Change Hygiene accepts a formatter command scoped to the exact changed path' {
+  param($root)
+  foreach ($relativePath in @('artifacts/implementation-report.md', 'artifacts/review-report.md')) {
+    $path = Join-Path $root $relativePath
+    $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
+    $updated = if ($relativePath -ceq 'artifacts/implementation-report.md') {
+      $text.Replace('| AdminRoute | none | none |', '| AdminRoute | dart format src/admin_route.source | none |')
+    }
+    else {
+      $text.Replace('| src/admin_route.source#AdminRoute | none | none | none |', '| src/admin_route.source#AdminRoute | dart format src/admin_route.source | none | none |')
+    }
+    if ($updated -ceq $text) { throw "Scoped formatter fixture replacement failed: $relativePath" }
+    Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
+  }
+} $true
+
+Assert-FailsLike 'Change Hygiene rejects a formatter operand that only contains the changed path' {
+  param($root)
+  foreach ($relativePath in @('artifacts/implementation-report.md', 'artifacts/review-report.md')) {
+    $path = Join-Path $root $relativePath
+    $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
+    $updated = if ($relativePath -ceq 'artifacts/implementation-report.md') {
+      $text.Replace('| AdminRoute | none | none |', '| AdminRoute | dart format src/admin_route.source.bak | none |')
+    }
+    else {
+      $text.Replace('| src/admin_route.source#AdminRoute | none | none | none |', '| src/admin_route.source#AdminRoute | dart format src/admin_route.source.bak | none | none |')
+    }
+    if ($updated -ceq $text) { throw "Substring formatter fixture replacement failed: $relativePath" }
+    Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
+  }
+} 'change-hygiene-invalid' $true
+
+Assert-FailsLike 'Change Hygiene rejects a noncanonical unrelated-diff disposition' {
+  param($root)
+  $path = Join-Path $root 'artifacts/implementation-report.md'
+  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
+  $updated = $text.Replace('| AdminRoute | none | none |', '| AdminRoute | none | confirmed |')
+  if ($updated -ceq $text) { throw 'Noncanonical unrelated-diff fixture replacement failed' }
+  Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
+} 'change-hygiene-invalid' $true
+
+Assert-FailsLike 'Change Hygiene rejects a changed path omitted from the independent review table' {
+  param($root)
+  $path = Join-Path $root 'artifacts/review-report.md'
+  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
+  $updated = [regex]::Replace($text, '(?m)^\| WORK-ADMIN \| src/admin_route\.source#AdminRoute \|[^\r\n]+\r?\n?', '')
+  if ($updated -ceq $text) { throw 'Omitted review Change Hygiene row fixture replacement failed' }
+  Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
+} 'change-hygiene-review-mismatch' $true
+
+Assert-FailsLike 'Change Hygiene rejects duplicate independent review rows' {
+  param($root)
+  $path = Join-Path $root 'artifacts/review-report.md'
+  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
+  $rows = @($text -split '\r?\n' | Where-Object { $_ -cmatch '^\| WORK-ADMIN \| src/admin_route\.source#AdminRoute \|' })
+  if ($rows.Count -ne 1) { throw 'Duplicate review Change Hygiene row fixture anchor is missing or duplicated' }
+  Set-Content -Encoding utf8 -LiteralPath $path -Value $text.Replace($rows[0], "$($rows[0])`n$($rows[0])")
+} 'change-hygiene-review-mismatch' $true
+
+Assert-FailsLike 'confirmed unrelated diff requires one matching independent Major finding' {
+  param($root)
+  $implementationPath = Join-Path $root 'artifacts/implementation-report.md'
+  $implementation = Get-Content -Raw -Encoding utf8 -LiteralPath $implementationPath
+  $updatedImplementation = $implementation.Replace('| AdminRoute | none | none |', '| AdminRoute | none | confirmed:MAJOR-UNRELATED-001 |')
+  if ($updatedImplementation -ceq $implementation) { throw 'Confirmed implementation unrelated-diff fixture replacement failed' }
+  Set-Content -Encoding utf8 -LiteralPath $implementationPath -Value $updatedImplementation
+
+  $reviewPath = Join-Path $root 'artifacts/review-report.md'
+  $review = Get-Content -Raw -Encoding utf8 -LiteralPath $reviewPath
+  $updatedReview = $review.Replace('| src/admin_route.source#AdminRoute | none | none | none |', '| src/admin_route.source#AdminRoute | none | confirmed:MAJOR-UNRELATED-001 | Major |')
+  if ($updatedReview -ceq $review) { throw 'Confirmed review unrelated-diff fixture replacement failed' }
+  Set-Content -Encoding utf8 -LiteralPath $reviewPath -Value $updatedReview
+} 'change-hygiene-review-mismatch' $true
+
 Assert-FailsLike 'review rejects a changed production path omitted from Change Hygiene' {
   param($root)
   $path = Join-Path $root 'artifacts/implementation-report.md'
   $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
   $updated = [regex]::Replace($text, '(?m)^\| WORK-ADMIN \| src/admin_route\.source \|[^\r\n]+\r?\n?', '')
   if ($updated -ceq $text) { throw 'Omitted changed production path fixture replacement failed' }
   Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
 } 'ARC-CONTRACT-MALFORMED-TABLE: Change Hygiene|responsibility-evidence-missing' $true
 
 Assert-FailsLike 'review rejects duplicate Change Hygiene rows for one changed path' {
   param($root)
   $path = Join-Path $root 'artifacts/implementation-report.md'
   $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
   $rows = @($text -split '\r?\n' | Where-Object { $_ -cmatch '^\| WORK-ADMIN \| src/admin_route\.source \|' })
   if ($rows.Count -ne 1) { throw 'Duplicate Change Hygiene fixture anchor is missing or duplicated' }
   Set-Content -Encoding utf8 -LiteralPath $path -Value $text.Replace($rows[0], "$($rows[0])`n$($rows[0])")
-} 'responsibility-evidence-missing' $true
+} 'responsibility-evidence-missing|change-hygiene-review-mismatch' $true
 
 Assert-FailsLike 'every deleted Git path requires immutable checkpoint evidence even without an owner' {
   param($root)
   Add-DeletedNonOwnerPath $root $false
 } 'responsibility-evidence-missing' $true
 
 Assert-Pass 'deleted non-owner Git path accepts exact base-source and removal-diff checkpoint evidence' {
   param($root)
   Add-DeletedNonOwnerPath $root $true
 } $true
@@ -1287,21 +1667,21 @@ Assert-FailsLike 'review evidence rejects a source item with a rename delimiter'
   Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
 } 'responsibility-evidence-missing' $true
 
 Assert-FailsLike 'review evidence rejects parent traversal in a repository path' {
   param($root)
   $path = Join-Path $root 'artifacts/review-report.md'
   $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
   $updated = $text.Replace('src/admin_route.source', 'src/../src/admin_route.source')
   if ($updated -ceq $text) { throw 'Review parent traversal fixture replacement failed' }
   Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
-} 'responsibility-evidence-missing' $true
+} 'responsibility-evidence-missing|change-hygiene-review-mismatch' $true
 
 Assert-Pass 'composed review normalizes Windows repository paths before every authority comparison' {
   param($root)
   Convert-ReviewPathsToWindows $root
 } $true $true
 
 Assert-FailsLike 'pinned verification rejects slash-backslash alias duplicate production bindings' {
   param($root)
   Set-PinnedProductionBindings $root @('src/admin_route.source', 'src\admin_route.source')
 } 'verification-production-binding-missing' $true $true
@@ -1309,38 +1689,53 @@ Assert-FailsLike 'pinned verification rejects slash-backslash alias duplicate pr
 Assert-FailsLike 'pinned verification rejects parent traversal in a production binding' {
   param($root)
   Set-PinnedProductionBindings $root @('src\..\src\admin_route.source')
 } 'verification-production-binding-missing' $true $true
 
 Assert-FailsLike 'pinned verification rejects a canonical production-binding mismatch' {
   param($root)
   Set-PinnedProductionBindings $root @('src/other_route.source')
 } 'verification-production-binding-missing' $true $true
 
+Assert-FailsLike 'wholly commented verification scenario and bindings remain inactive' {
+  param($root)
+  Comment-OutPinnedVerificationEvidence $root
+} 'verification-production-binding-missing' $true $true
+
+Assert-Pass 'review consumes language-valid comment-wrapped verification markers' {
+  param($root)
+  Use-LanguageValidPinnedVerificationMarkers $root
+} $true
+
+Assert-FailsLike 'block-commented language-valid verification markers remain inactive' {
+  param($root)
+  Use-LanguageValidPinnedVerificationMarkers $root $true
+} 'verification-production-binding-missing' $true
+
 Assert-FailsLike 'canonical normalization rejects slash-backslash alias duplication in Change Hygiene' {
   param($root)
   $path = Join-Path $root 'artifacts/implementation-report.md'
   $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
   $rows = @($text -split '\r?\n' | Where-Object { $_ -cmatch '^\| WORK-ADMIN \| src/admin_route\.source \|' })
   if ($rows.Count -ne 1) { throw 'Path alias Change Hygiene anchor is missing or duplicated' }
   $aliasRow = $rows[0].Replace('src/admin_route.source', 'src\admin_route.source')
   Set-Content -Encoding utf8 -LiteralPath $path -Value $text.Replace($rows[0], "$($rows[0])`n$aliasRow")
-} 'responsibility-evidence-missing' $true
+} 'responsibility-evidence-missing|change-hygiene-review-mismatch' $true
 
 Assert-FailsLike 'canonical normalization rejects parent-segment path ambiguity' {
   param($root)
   foreach ($relativePath in @('artifacts/design-report.md', 'artifacts/implementation-report.md', 'artifacts/review-report.md')) {
     $path = Join-Path $root $relativePath
     $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
     Set-Content -Encoding utf8 -LiteralPath $path -Value $text.Replace('src/admin_route.source', 'src\..\src\admin_route.source')
   }
-} 'responsibility-evidence-missing' $true
+} 'responsibility-evidence-missing|change-hygiene-review-mismatch' $true
 
 Assert-FailsLike 'review rejects a stale existing final-tree SHA after the authorized checkout advances' {
   param($root)
   $provenancePath = Join-Path $root 'artifacts/review-provenance.md'
   $provenance = Get-Content -Raw -Encoding utf8 -LiteralPath $provenancePath
   $sourceRoot = [regex]::Match($provenance, '(?m)^Source Root:\s*(?<value>.+)$').Groups['value'].Value.Trim()
   Set-Content -Encoding utf8 -LiteralPath (Join-Path $sourceRoot 'checkout-advance') -Value 'later authorized checkout'
   Invoke-PinnedSourceGit $sourceRoot @('add', '--', 'checkout-advance') | Out-Null
   Invoke-PinnedSourceGit $sourceRoot @('commit', '-m', 'advance authorized checkout') | Out-Null
   Set-Content -Encoding utf8 -LiteralPath $provenancePath -Value ($provenance.TrimEnd() + "`nCheckout state: advanced`n")
@@ -1348,20 +1743,25 @@ Assert-FailsLike 'review rejects a stale existing final-tree SHA after the autho
 
 Assert-FailsLike 'review rejects a dirty authorized checkout even when pinned commits remain valid' {
   param($root)
   $provenancePath = Join-Path $root 'artifacts/review-provenance.md'
   $provenance = Get-Content -Raw -Encoding utf8 -LiteralPath $provenancePath
   $sourceRoot = [regex]::Match($provenance, '(?m)^Source Root:\s*(?<value>.+)$').Groups['value'].Value.Trim()
   Set-Content -Encoding utf8 -LiteralPath (Join-Path $sourceRoot 'uncommitted-review-input') -Value 'dirty checkout'
   Set-Content -Encoding utf8 -LiteralPath $provenancePath -Value ($provenance.TrimEnd() + "`nCheckout state: dirty`n")
 } 'responsibility-evidence-missing' $true
 
+Assert-FailsLike 'review rejects a reachable task-base that is not an ancestor of final HEAD' {
+  param($root)
+  Set-UnrelatedReachableTaskBase $root
+} 'responsibility-evidence-missing' $true $true
+
 Assert-FailsLike 'review provenance source root must be the actual authorized Git checkout root' {
   param($root)
   $provenancePath = Join-Path $root 'artifacts/review-provenance.md'
   $provenance = Get-Content -Raw -Encoding utf8 -LiteralPath $provenancePath
   $sourceRoot = [regex]::Match($provenance, '(?m)^Source Root:\s*(?<value>.+)$').Groups['value'].Value.Trim()
   $nestedRoot = Join-Path $sourceRoot 'src'
   $updated = $provenance.Replace("Source Root: $sourceRoot", "Source Root: $nestedRoot")
   if ($updated -ceq $provenance) { throw 'Nested checkout-root provenance mutation was a silent no-op' }
   Set-Content -Encoding utf8 -LiteralPath $provenancePath -Value $updated
 } 'responsibility-evidence-missing' $true
@@ -1503,20 +1903,70 @@ Assert-FailsLike 'all required architecture and responsibility verdict fields oc
 } 'exactly once|Verification Ownership Verdict'
 
 Assert-FailsLike 'a missing mandatory verdict is rejected' {
   param($root)
   $path = Join-Path $root 'templates/migration/review-report.md'
   $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
   $text = $text.Replace('- Architecture Conformance Verdict: <PASS | BLOCKED>', '- Architecture verdict omitted: <PASS | BLOCKED>')
   Set-Content -Encoding utf8 -LiteralPath $path -Value $text
 } 'exactly once|Architecture Conformance Verdict'
 
+Assert-FailsLike 'a missing Rule Resolution state is rejected' {
+  param($root)
+  $path = Join-Path $root 'templates/migration/review-report.md'
+  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
+  $updated = $text.Replace('- Rule Resolution Verdict: <RESOLVED | BLOCKED>', '- Rule resolution omitted: <RESOLVED | BLOCKED>')
+  if ($updated -ceq $text) { throw 'Rule Resolution state mutation was a silent no-op' }
+  Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
+} 'Rule Resolution|State|exactly once'
+
+Assert-FailsLike 'a missing Change Hygiene verdict is rejected' {
+  param($root)
+  $path = Join-Path $root 'templates/migration/review-report.md'
+  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
+  $updated = $text.Replace('- Change Hygiene Verdict: <PASS | BLOCKED>', '- Change Hygiene state omitted: <PASS | BLOCKED>')
+  if ($updated -ceq $text) { throw 'Change Hygiene verdict mutation was a silent no-op' }
+  Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
+} 'Change Hygiene Verdict|exactly once'
+
+Assert-FailsLike 'missing Critical and Major counts are rejected' {
+  param($root)
+  $path = Join-Path $root 'templates/migration/review-report.md'
+  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
+  $updated = $text.Replace("- Critical count: <non-negative integer>`r`n- Major count: <non-negative integer>`r`n", '')
+  if ($updated -ceq $text) {
+    $updated = $text.Replace("- Critical count: <non-negative integer>`n- Major count: <non-negative integer>`n", '')
+  }
+  if ($updated -ceq $text) { throw 'Review count mutation was a silent no-op' }
+  Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
+} 'Critical count|Major count|exactly once'
+
+Assert-FailsLike 'rendered review verdict is derived from all canonical gates and counts' {
+  param($root)
+  Set-RenderedReviewFixture $root 'migration-unit' $true
+  $path = Join-Path $root 'templates/migration/review-report.md'
+  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
+  $updated = $text.Replace('- Change Hygiene Verdict: PASS', '- Change Hygiene Verdict: BLOCKED')
+  if ($updated -ceq $text) { throw 'Rendered Change Hygiene contradiction mutation was a silent no-op' }
+  Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
+} 'Change Hygiene|Reject|derived'
+
+Assert-FailsLike 'rendered review handoff cells must equal all visible derived verdicts' {
+  param($root)
+  Set-RenderedReviewFixture $root 'migration-unit' $true
+  $path = Join-Path $root 'templates/migration/review-report.md'
+  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
+  $updated = $text.Replace('| 1 | PASS | PASS | PASS | PASS | source-diff:', '| 1 | BLOCKED | PASS | PASS | BLOCKED | source-diff:')
+  if ($updated -ceq $text) { throw 'Contradictory rendered handoff fixture replacement failed' }
+  Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
+} 'handoff|Tree Conformance|visible verdict|derived'
+
 Assert-FailsLike 'a fenced verdict example cannot replace the visible template verdict' {
   param($root)
   $path = Join-Path $root 'templates/migration/review-report.md'
   $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
   $hiddenVerdict = @'
 ```text
 - Architecture Conformance Verdict: <PASS | BLOCKED>
 ```
 '@
   Set-Content -Encoding utf8 -LiteralPath $path -Value $text.Replace('- Architecture Conformance Verdict: <PASS | BLOCKED>', $hiddenVerdict)
@@ -1679,47 +2129,35 @@ Assert-Pass 'one-to-three-space Markdown indentation remains visible to template
 Assert-FailsLike 'verdict values use the exact enum' {
   param($root)
   $path = Join-Path $root 'templates/migration/review-report.md'
   $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
   $text = $text.Replace('<PASS | BLOCKED | NOT_APPLICABLE>', '<PASS | BLOCKED | N/A>')
   Set-Content -Encoding utf8 -LiteralPath $path -Value $text
 } 'invalid verdict|Production Activation-path Verdict'
 
 Assert-FailsLike 'a blocked architecture verdict forces Reject independent of counts' {
   param($root)
+  Set-RenderedReviewFixture $root 'migration-unit' $true
   $path = Join-Path $root 'templates/migration/review-report.md'
   $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
-  $selectorIndex = $text.IndexOf('<PASS | BLOCKED>', [StringComparison]::Ordinal)
-  $text = $text.Remove($selectorIndex, '<PASS | BLOCKED>'.Length).Insert($selectorIndex, 'BLOCKED')
-  foreach ($index in 1..4) {
-    $architectureIndex = $text.IndexOf('<PASS | BLOCKED>', [StringComparison]::Ordinal)
-    $text = $text.Remove($architectureIndex, '<PASS | BLOCKED>'.Length).Insert($architectureIndex, 'PASS')
-  }
-  $text = $text.Replace('<PASS | BLOCKED | NOT_APPLICABLE>', 'NOT_APPLICABLE')
-  $text = $text.Replace('<NOT_RUN | COMPLETE>', 'NOT_RUN')
-  $text = $text.Replace('<Approve | Approve-with-fixes | Reject>', 'Approve')
+  $text = $text.Replace('- Canonical Selector Verdict: PASS', '- Canonical Selector Verdict: BLOCKED')
+  $text = $text.Replace('- Behavior Analysis State: COMPLETE', '- Behavior Analysis State: NOT_RUN')
   Set-Content -Encoding utf8 -LiteralPath $path -Value $text
 } 'BLOCKED|Reject|severity'
 
 Assert-FailsLike 'blocked structural verdict stops before behavior analysis' {
   param($root)
+  Set-RenderedReviewFixture $root 'migration-unit' $true
   $path = Join-Path $root 'templates/migration/review-report.md'
   $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
-  $selectorIndex = $text.IndexOf('<PASS | BLOCKED>', [StringComparison]::Ordinal)
-  $text = $text.Remove($selectorIndex, '<PASS | BLOCKED>'.Length).Insert($selectorIndex, 'BLOCKED')
-  foreach ($index in 1..4) {
-    $architectureIndex = $text.IndexOf('<PASS | BLOCKED>', [StringComparison]::Ordinal)
-    $text = $text.Remove($architectureIndex, '<PASS | BLOCKED>'.Length).Insert($architectureIndex, 'PASS')
-  }
-  $text = $text.Replace('<PASS | BLOCKED | NOT_APPLICABLE>', 'NOT_APPLICABLE')
-  $text = $text.Replace('<NOT_RUN | COMPLETE>', 'COMPLETE')
-  $text = $text.Replace('<Approve | Approve-with-fixes | Reject>', 'Reject')
+  $text = $text.Replace('- Canonical Selector Verdict: PASS', '- Canonical Selector Verdict: BLOCKED')
+  $text = $text.Replace('- Verdict: Approve', '- Verdict: Reject')
   Set-Content -Encoding utf8 -LiteralPath $path -Value $text
 } 'before behavior analysis'
 
 foreach ($lineEndingCase in @(
   [pscustomobject]@{ Name = 'LF'; NewLine = "`n" }
   [pscustomobject]@{ Name = 'CRLF'; NewLine = "`r`n" }
 )) {
   Assert-FailsLike "mixed schema/rendered verdict mode is rejected ($($lineEndingCase.Name))" {
     param($root)
     $path = Join-Path $root 'templates/migration/review-report.md'
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1
index 38fad3a..6e34769 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1
@@ -1402,28 +1402,46 @@ responsibility_contract:
 - Responsibility Conformance Verdict: $ResponsibilityState
 - Verification Ownership Verdict: $VerificationState
 
 | Responsibility ID | Source/Diff Evidence | Planned Public Symbols | Actual Public Symbols | Planned Effects | Actual Effects | Verdict |
 |---|---|---|---|---|---|---|
 | RESP-WIFI | $wifiEvidence | AdminWifi | AdminWifi | none | none | PASS |
 | RESP-WIRED | $wiredEvidence | AdminWired | AdminWired | none | none | PASS |
 | RESP-LOCK-GUARD | $guardEvidence | LockGuard | LockGuard | none | none | PASS |
 | RESP-LOCK-COMPOSITION | $compositionEvidence | AdminLockComposition | AdminLockComposition | route registration | route registration | PASS |
 
+## Change Hygiene
+
+- Change Hygiene Verdict: PASS
+
+| Task / Unit | Scope Evidence | Formatter Evidence | Unrelated Diff | Severity | Task-base SHA | Final-tree SHA |
+|---|---|---|---|---|---|---|
+| WORK-ADMIN-LOCK | ui/admin_wifi.dart#AdminWifi | none | none | none | $($PinnedSource.TaskBaseSha) | $($PinnedSource.FinalTreeSha) |
+| WORK-ADMIN-LOCK | ui/admin_wired.dart#AdminWired | none | none | none | $($PinnedSource.TaskBaseSha) | $($PinnedSource.FinalTreeSha) |
+| WORK-ADMIN-LOCK | lib/lock_guard.dart#LockGuard | none | none | none | $($PinnedSource.TaskBaseSha) | $($PinnedSource.FinalTreeSha) |
+| WORK-ADMIN-LOCK | lib/admin_lock_composition.dart#AdminLockComposition | none | none | none | $($PinnedSource.TaskBaseSha) | $($PinnedSource.FinalTreeSha) |
+
 ## Critical
 
 | File:line | Issue | Proposed fix |
 |---|---|---|
 
+## Major
+
+| File:line | Issue | Proposed fix |
+|---|---|---|
+| none | none | none |
+
 ## Conclusion
 
 - Critical count: 0
+- Major count: 0
 - Verdict: $OverallVerdict
 "@
 }
 
 function New-ResponsibilityReviewPlanFixture {
   return @"
 ---
 artifact_type: migration-master-plan
 master_plan_id: PLAN-ADMIN-001
 master_spec_id: SPEC-ADMIN-001
@@ -1680,39 +1698,44 @@ foreach ($verificationCase in @(
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
+  if ($verificationCase.Variant -ceq 'stale-scenario') {
+    $reviewHygieneRow = "| WORK-ADMIN-LOCK | test/admin_lock_test.ps1#AdminWifiContract | none | none | none | $($variantSource.TaskBaseSha) | $($variantSource.FinalTreeSha) |"
+    $variantReview = $variantReview.Replace("`n`n## Critical", "`n$reviewHygieneRow`n`n## Critical")
+  }
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
+$migrationReview = [regex]::Replace($migrationReview, '(?m)^\| WORK-ADMIN-LOCK \| (?=(?:ui|lib)/)', '| UNIT-ADMIN-LOCK | ')
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
@@ -1877,25 +1900,29 @@ Assert-ReviewAccepted 'review scopes planned owners and verification to the sele
 $foreignOwnerReference = $validImplementation.Replace('| WORK-ADMIN-LOCK | DESIGN-ADMIN@2 | RESP-WIFI, RESP-WIRED | RESP-LOCK-GUARD | RESP-LOCK-COMPOSITION |', '| WORK-OTHER | DESIGN-ADMIN@2 | RESP-WIFI, RESP-WIRED | RESP-LOCK-GUARD | RESP-LOCK-COMPOSITION |')
 Assert-ReviewRejected 'review owner references bind the exact current work item provenance' $multiWorkItemReview 'responsibility-evidence-missing' -DesignText $multiWorkItemDesign -ImplementationText $foreignOwnerReference
 
 $unchangedSelectedSource = New-ResponsibilityReviewSourceFixture
 $unchangedTaskBaseSha = $unchangedSelectedSource.FinalTreeSha
 Set-Content -Encoding utf8 -LiteralPath (Join-Path $unchangedSelectedSource.Root 'notes.txt') -Value 'unrelated final-tree change'
 Invoke-ReviewSourceGit $unchangedSelectedSource.Root @('add', '--', 'notes.txt') | Out-Null
 Invoke-ReviewSourceGit $unchangedSelectedSource.Root @('commit', '-m', 'unrelated final-tree change') | Out-Null
 $unchangedSelectedSource = [pscustomobject]@{ Root = $unchangedSelectedSource.Root; TaskBaseSha = $unchangedTaskBaseSha; FinalTreeSha = (Invoke-ReviewSourceGit $unchangedSelectedSource.Root @('rev-parse', 'HEAD')) }
 $unchangedImplementation = New-ResponsibilityImplementationFixture -TaskBaseSha $unchangedSelectedSource.TaskBaseSha -FinalTreeSha $unchangedSelectedSource.FinalTreeSha
-$unchangedHygieneRow = "| WORK-ADMIN-LOCK | notes.txt | new | documentation note | none | none | none | $($unchangedSelectedSource.TaskBaseSha) | $($unchangedSelectedSource.FinalTreeSha) |"
+$unchangedHygieneRow = "| WORK-ADMIN-LOCK | notes.txt | new | DocumentationNote | none | none | none | $($unchangedSelectedSource.TaskBaseSha) | $($unchangedSelectedSource.FinalTreeSha) |"
 $updatedUnchangedImplementation = [regex]::Replace($unchangedImplementation, '(?ms)(^## Change Hygiene\r?\n\r?\n\| Task / Unit \| File \| File Kind \| Edited Region / Symbol \| Formatter Command \| Unrelated Diff \| Checkpoint History \| Task-base SHA \| Final-tree SHA \|\r?\n\|---\|---\|---\|---\|---\|---\|---\|---\|---\|\r?\n)(?:\| WORK-ADMIN-LOCK \| (?:ui|lib)/[^\r\n]+\r?\n?)+', "`$1$unchangedHygieneRow`n")
 if ($updatedUnchangedImplementation -ceq $unchangedImplementation) { throw 'Unchanged selected-owner Change Hygiene fixture replacement failed' }
 $unchangedImplementation = $updatedUnchangedImplementation
 $unchangedReview = New-ResponsibilityReviewFixture -PinnedSource $unchangedSelectedSource
+$unchangedReviewHygieneRow = "| WORK-ADMIN-LOCK | notes.txt#DocumentationNote | none | none | none | $($unchangedSelectedSource.TaskBaseSha) | $($unchangedSelectedSource.FinalTreeSha) |"
+$updatedUnchangedReview = [regex]::Replace($unchangedReview, '(?ms)(^## Change Hygiene\r?\n\r?\n- Change Hygiene Verdict: PASS\r?\n\r?\n\| Task / Unit \| Scope Evidence \| Formatter Evidence \| Unrelated Diff \| Severity \| Task-base SHA \| Final-tree SHA \|\r?\n\|---\|---\|---\|---\|---\|---\|---\|\r?\n)(?:\| WORK-ADMIN-LOCK \| (?:ui|lib)/[^\r\n]+\r?\n?)+', "`$1$unchangedReviewHygieneRow`n")
+if ($updatedUnchangedReview -ceq $unchangedReview) { throw 'Unchanged selected-owner review Change Hygiene fixture replacement failed' }
+$unchangedReview = $updatedUnchangedReview
 $unchangedSourceOnlyReview = [regex]::Replace($unchangedReview, '; diff:[0-9a-f]{40}\.\.[0-9a-f]{40}:[^#;\r\n]+#[A-Za-z][A-Za-z0-9_.:-]*', '')
 Assert-ReviewAccepted 'review loads unchanged selected owners from pinned final-tree source evidence without fabricated diff anchors' $unchangedSourceOnlyReview $validReviewDesign $unchangedImplementation $unchangedSelectedSource
 Assert-ReviewRejected 'review rejects fabricated diff anchors for unchanged selected owner paths' $unchangedReview 'responsibility-evidence-missing' -DesignText $validReviewDesign -ImplementationText $unchangedImplementation -PinnedSource $unchangedSelectedSource
 $foreignShaDiffReview = $unchangedSourceOnlyReview.Replace("source:$($unchangedSelectedSource.FinalTreeSha):ui/admin_wifi.dart#AdminWifi", "source:$($unchangedSelectedSource.FinalTreeSha):ui/admin_wifi.dart#AdminWifi; diff:3333333333333333333333333333333333333333..4444444444444444444444444444444444444444:ui/admin_wifi.dart#AdminWifi")
 Assert-ReviewRejected 'review rejects foreign-SHA diff anchors for unchanged selected owner paths' $foreignShaDiffReview 'responsibility-evidence-missing' -DesignText $validReviewDesign -ImplementationText $unchangedImplementation -PinnedSource $unchangedSelectedSource
 Remove-Item -LiteralPath $unchangedSelectedSource.Root -Recurse -Force
 
 Remove-Item -LiteralPath $validReviewSource.Root -Recurse -Force
 
 Write-Output 'PASS: responsibility conformance contract'
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/scope-artifacts.Tests.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/scope-artifacts.Tests.ps1
index 6ca6e29..3d4a0c1 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/scope-artifacts.Tests.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/scope-artifacts.Tests.ps1
@@ -102,20 +102,33 @@ try {
     Assert-True ($validErrors.Count -eq 0) ("Rendered master artifacts must validate: " + ($validErrors -join '; '))
 
     foreach ($name in @('master-spec.md', 'master-plan.md')) {
       $artifactPath = Join-Path $fixtureRoot "templates/migration/$name"
       $lfText = (Get-Content -Raw -Encoding utf8 $artifactPath).Replace("`r`n", "`n").Replace("`r", "`n")
       [IO.File]::WriteAllText($artifactPath, $lfText, [Text.UTF8Encoding]::new($false))
     }
     $lfErrors = Invoke-ScopeArtifactsValidation $fixtureRoot
     Assert-True ($lfErrors.Count -eq 0) ("LF-rendered master artifacts must validate: " + ($lfErrors -join '; '))
 
+    $semanticPlanPath = Join-Path $fixtureRoot 'templates/migration/master-plan.md'
+    $semanticPlanOriginal = Get-Content -Raw -Encoding utf8 -LiteralPath $semanticPlanPath
+    foreach ($semanticDecoy in @(
+      [pscustomobject]@{ Name = 'fenced'; Text = "~~~markdown`n## Work Items`n| decoy |`n|---|`n| ignored |`n~~~" },
+      [pscustomobject]@{ Name = 'commented'; Text = "<!--`n## Work Items`n| decoy |`n|---|`n| ignored |`n-->" },
+      [pscustomobject]@{ Name = 'indented'; Text = "    ## Work Items`n    | decoy |`n    |---|`n    | ignored |" }
+    )) {
+      [IO.File]::WriteAllText($semanticPlanPath, "$semanticPlanOriginal`n$($semanticDecoy.Text)`n", [Text.UTF8Encoding]::new($false))
+      $semanticErrors = Invoke-ScopeArtifactsValidation $fixtureRoot
+      Assert-True ($semanticErrors.Count -eq 0) ("$($semanticDecoy.Name) Markdown examples must not inflate scope authority: " + ($semanticErrors -join '; '))
+    }
+    [IO.File]::WriteAllText($semanticPlanPath, $semanticPlanOriginal, [Text.UTF8Encoding]::new($false))
+
     $selectorPlanPath = Join-Path $fixtureRoot 'templates/migration/master-plan.md'
     $selectorPlanOriginal = Get-Content -Raw -Encoding utf8 -LiteralPath $selectorPlanPath
     try {
       $workRow = '| WORK-ADMIN-LOCKS | Complete Lock Mode | yes | none | 1 | REQ-001; SC-001; measurable outcome | TRACE-001 | none | in-progress | ATTEMPT-WORK-ADMIN-LOCKS-01 | none | pending |'
       $secondWorkRow = '| WORK-ADMIN-OTHER | Complete Other Mode | no | none | 2 | REQ-001; SC-001; measurable outcome | TRACE-001 | none | ready | none | none | pending |'
       $selectorRow = '| WORK-ADMIN-LOCKS | none | not-applicable | not-applicable | not-applicable | not-applicable | not-applicable | REQ-001; SC-001; measurable outcome | TRACE-001 | incremental/preserve-existing | DESIGN-ADMIN@1 | not-applicable | not-applicable |'
       $secondDependencyRow = '| WORK-ADMIN-OTHER | none | no-dependency | decision:graph-admin |'
       $mutatedPlan = $selectorPlanOriginal.Replace($workRow, "$workRow`n$secondWorkRow")
       $mutatedPlan = $mutatedPlan.Replace($selectorRow, "$selectorRow`n$selectorRow")
       $mutatedPlan = $mutatedPlan.Replace('| WORK-ADMIN-LOCKS | none | no-dependency | decision:graph-admin |', "| WORK-ADMIN-LOCKS | none | no-dependency | decision:graph-admin |`n$secondDependencyRow")
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/scope-engine.Tests.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/scope-engine.Tests.ps1
index 92cbf5f..5a91746 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/scope-engine.Tests.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/scope-engine.Tests.ps1
@@ -249,80 +249,88 @@ function New-ResponsibilityChain([string]$Prefix, [string]$WorkItemId, [string]$
     FinalReference = [string]$references[-1]
   }
 }
 
 function New-TerminalResponsibilityArtifact(
   [string]$Reference,
   [string]$WorkItemId,
   [string]$Status,
   [string]$EvidenceReference,
   [string[]]$ChainReferences = @(),
-  [string]$ModeConstraint = 'incremental/preserve-existing'
+  [string]$ModeConstraint = 'incremental/preserve-existing',
+  [string]$TaskUnit = ''
 ) {
+  if ([string]::IsNullOrWhiteSpace($TaskUnit)) { $TaskUnit = $WorkItemId }
   return @{
     artifact_reference = $Reference
     artifact_type = 'migration-work-item-terminal'
     immutable = $true
     run_id = 'RUN-ADMIN-001'
     master_spec_ref = 'runs/master-spec@2.md'
     master_spec_id = 'SPEC-ADMIN-001'
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
     task_provenance = @{
-      task_unit = $WorkItemId
+      task_unit = $TaskUnit
       task_base_sha = '1111111111111111111111111111111111111111'
       final_tree_sha = '2222222222222222222222222222222222222222'
       source_artifact_reference = 'implementation-report.md'
       evidence_reference = "source-diff:1111111111111111111111111111111111111111..2222222222222222222222222222222222222222#$WorkItemId"
     }
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
 
 function Invoke-ReconciliationAuthorityCase(
   [string]$Suffix,
   [bool]$IncludeTerminalAuthority = $true,
   [scriptblock]$MutateAuthority = $null,
-  [bool]$NextItemDependsOnReconciled = $false
+  [bool]$NextItemDependsOnReconciled = $false,
+  [string]$MigrationUnitId = ''
 ) {
   $reconciledItem = New-WorkItem "WORK-ADMIN-RECONCILE-$Suffix" 1 @() 'in-progress'
+  if (-not [string]::IsNullOrWhiteSpace($MigrationUnitId)) {
+    $reconciledItem.adapter_kind = 'migration-unit'
+    $reconciledItem.external_id = $MigrationUnitId
+  }
   $reconciledItem.latest_attempt = "ATTEMPT-WORK-ADMIN-RECONCILE-$Suffix-01"
   $reconciledItem.attempt_status = 'complete'
   $reconciledItem.terminal_evidence = "runs/reconcile-$($Suffix.ToLowerInvariant())-terminal.md"
   $reconciledItem.attempt_history = @(
     @{ attempt_id = $reconciledItem.latest_attempt; work_item_id = $reconciledItem.work_item_id; plan_revision = 3; status = 'complete'; artifact_reference = $reconciledItem.terminal_evidence }
   )
   $nextItemKind = if ($NextItemDependsOnReconciled) { 'DEPENDENT' } else { 'UNRELATED' }
   $nextItemDependencies = if ($NextItemDependsOnReconciled) { @($reconciledItem.work_item_id) } else { @() }
   $nextItem = New-WorkItem "WORK-ADMIN-$nextItemKind-$Suffix" 2 $nextItemDependencies
   $fixture = @{
     scenario_type = 'scope-engine'; operation = 'select'; current_plan_revision = 3
     work_items = @($reconciledItem, $nextItem)
   }
   if ($IncludeTerminalAuthority) {
     $chain = New-ResponsibilityChain "runs/reconcile-$($Suffix.ToLowerInvariant())-chain" $reconciledItem.work_item_id $reconciledItem.mode_constraint
-    $terminal = New-TerminalResponsibilityArtifact $reconciledItem.terminal_evidence $reconciledItem.work_item_id 'complete' $chain.FinalReference $chain.References $chain.ModeConstraint
+    $taskUnit = if ($reconciledItem.adapter_kind -ceq 'migration-unit') { [string]$reconciledItem.external_id } else { [string]$reconciledItem.work_item_id }
+    $terminal = New-TerminalResponsibilityArtifact $reconciledItem.terminal_evidence $reconciledItem.work_item_id 'complete' $chain.FinalReference $chain.References $chain.ModeConstraint $taskUnit
     $terminal.attempt_id = $reconciledItem.latest_attempt
     $terminal.result = 'complete'
     if ($null -ne $MutateAuthority) { & $MutateAuthority $terminal $chain }
     $fixture.terminal_artifacts = @($terminal)
     $fixture.responsibility_chain_artifacts = @($chain.Artifacts)
   }
   return [pscustomobject]@{
     Result = Invoke-ScopeScenario $fixture
     ReconciledItem = $reconciledItem
     NextItem = $nextItem
@@ -801,20 +809,31 @@ $untrustedReconcile = Invoke-ScopeScenario @{
 Assert-Equal $untrustedReconcile.result 'scope-blocked' 'Reconciliation must not unlock a dependent without canonical terminal responsibility authority'
 Assert-Equal $untrustedReconcile.reason 'terminal-responsibility-authority-invalid' 'Missing reconciled terminal chain must fail the dependency authority gate'
 Assert-Equal $untrustedReconcile.work_item_id '' 'A reconciled dependency without terminal authority must leave its dependent unselected'
 
 $canonicalNoDependent = Invoke-NoDependentReconciliationCase 'CANONICAL'
 Assert-Equal $canonicalNoDependent.Result.result 'selected' 'A reconciled item with canonical terminal authority may permit unrelated selection'
 Assert-Equal $canonicalNoDependent.Result.scope_status 'scope-in-progress' 'Canonical no-dependent reconciliation must preserve the in-progress scope state'
 Assert-Equal $canonicalNoDependent.Result.work_item_id $canonicalNoDependent.UnrelatedItem.work_item_id 'Canonical no-dependent reconciliation must select the unrelated eligible item'
 Assert-Equal $canonicalNoDependent.Result.reconciled_work_item_id $canonicalNoDependent.ReconciledItem.work_item_id 'Canonical no-dependent reconciliation must expose the reconciled completion'
 
+$migrationUnitReconciliation = Invoke-ReconciliationAuthorityCase 'MIGRATION-UNIT' $true $null $false 'UNIT-RECONCILE-001'
+Assert-Equal $migrationUnitReconciliation.Result.result 'selected' 'Reconciliation must accept terminal Task Provenance bound to the approved selected migration-unit ID'
+Assert-Equal $migrationUnitReconciliation.Result.reconciled_work_item_id $migrationUnitReconciliation.ReconciledItem.work_item_id 'Migration-unit reconciliation must preserve the enclosing Work Item identity'
+
+$workItemSubstitutedForUnit = Invoke-ReconciliationAuthorityCase 'MIGRATION-UNIT-WRONG-TASK' $true {
+  param($terminal, $chain)
+  $terminal.task_provenance.task_unit = [string]$terminal.work_item_id
+} $false 'UNIT-RECONCILE-002'
+Assert-Equal $workItemSubstitutedForUnit.Result.result 'scope-blocked' 'Migration-unit reconciliation must reject Work Item ID substituted for selected Task / Unit authority'
+Assert-Equal $workItemSubstitutedForUnit.Result.reason 'terminal-responsibility-authority-invalid' 'Wrong migration-unit Task Provenance must fail terminal responsibility authority'
+
 $missingNoDependentAuthority = Invoke-NoDependentReconciliationCase 'MISSING-AUTHORITY' $false
 Assert-Equal $missingNoDependentAuthority.Result.result 'scope-blocked' 'A newly reconciled completion must require terminal authority even when it has no dependent'
 Assert-Equal $missingNoDependentAuthority.Result.reason 'terminal-responsibility-authority-invalid' 'Missing no-dependent terminal authority must emit the canonical reason'
 Assert-Equal $missingNoDependentAuthority.Result.scope_status 'scope-blocked' 'Missing no-dependent terminal authority must block scope'
 Assert-Equal $missingNoDependentAuthority.Result.work_item_id '' 'Missing no-dependent terminal authority must not select unrelated work'
 
 foreach ($terminalAuthorityCase in @(
   @{ Name = 'TERMINAL-PRE-V1'; Mutate = { param($terminal, $chain) $terminal.responsibility_handoff.responsibility_contract_version = 0 } },
   @{ Name = 'TERMINAL-CROSS-RUN'; Mutate = { param($terminal, $chain) $terminal.run_id = 'RUN-FOREIGN-999' } },
   @{ Name = 'TERMINAL-EVIDENCE-MISMATCH'; Mutate = { param($terminal, $chain) $terminal.responsibility_handoff.evidence_reference = 'runs/foreign-terminal-chain.md' } }
@@ -1088,20 +1107,43 @@ $allCompleteReport = New-TerminalScopeReport 'runs/scope-terminal.md' @($complet
 $allComplete = Invoke-ScopeScenario @{
   scenario_type = 'scope-engine'
   operation = 'complete-scope'
   work_items = @($completeItem, $cancelled, $notApplicable)
   terminal_artifacts = @($completeTerminal, $cancelledTerminal, $notApplicableTerminal)
   responsibility_chain_artifacts = @($completeChain.Artifacts + $cancelledChain.Artifacts + $notApplicableChain.Artifacts)
   terminal_scope_report = $allCompleteReport
 }
 Assert-Equal $allComplete.scope_status 'scope-complete' 'All required terminal-success items with scope evidence must complete the scope'
 
+$migrationUnitCompleteItem = New-WorkItem 'WORK-ADMIN-UNIT-COMPLETE' 1 @() 'complete'
+$migrationUnitCompleteItem.adapter_kind = 'migration-unit'
+$migrationUnitCompleteItem.external_id = 'UNIT-COMPLETE-001'
+$migrationUnitCompleteItem.terminal_evidence = 'runs/unit-complete.md'
+$migrationUnitCompleteChain = New-ResponsibilityChain 'runs/unit-complete-chain' $migrationUnitCompleteItem.work_item_id
+$migrationUnitCompleteTerminal = New-TerminalResponsibilityArtifact $migrationUnitCompleteItem.terminal_evidence $migrationUnitCompleteItem.work_item_id $migrationUnitCompleteItem.status $migrationUnitCompleteChain.FinalReference $migrationUnitCompleteChain.References $migrationUnitCompleteChain.ModeConstraint $migrationUnitCompleteItem.external_id
+$migrationUnitScopeComplete = Invoke-ScopeScenario @{
+  scenario_type = 'scope-engine'; operation = 'complete-scope'; work_items = @($migrationUnitCompleteItem)
+  terminal_artifacts = @($migrationUnitCompleteTerminal)
+  responsibility_chain_artifacts = @($migrationUnitCompleteChain.Artifacts)
+  terminal_scope_report = (New-TerminalScopeReport 'runs/unit-complete-scope.md' @($migrationUnitCompleteItem) @($migrationUnitCompleteChain))
+}
+Assert-Equal $migrationUnitScopeComplete.scope_status 'scope-complete' 'Scope completion must accept Task / Unit derived from the approved migration-unit selector'
+
+$migrationUnitWrongCompletionTerminal = New-TerminalResponsibilityArtifact $migrationUnitCompleteItem.terminal_evidence $migrationUnitCompleteItem.work_item_id $migrationUnitCompleteItem.status $migrationUnitCompleteChain.FinalReference $migrationUnitCompleteChain.References $migrationUnitCompleteChain.ModeConstraint $migrationUnitCompleteItem.work_item_id
+$migrationUnitWrongScopeComplete = Invoke-ScopeScenario @{
+  scenario_type = 'scope-engine'; operation = 'complete-scope'; work_items = @($migrationUnitCompleteItem)
+  terminal_artifacts = @($migrationUnitWrongCompletionTerminal)
+  responsibility_chain_artifacts = @($migrationUnitCompleteChain.Artifacts)
+  terminal_scope_report = (New-TerminalScopeReport 'runs/unit-wrong-scope.md' @($migrationUnitCompleteItem) @($migrationUnitCompleteChain))
+}
+Assert-Equal $migrationUnitWrongScopeComplete.scope_status 'scope-blocked' 'Scope completion must reject Work Item ID substituted for migration-unit Task / Unit authority'
+
 $forgedInitialCompletionChain = New-ResponsibilityChain 'runs/forged-initial-completion-chain' $completeItem.work_item_id
 $forgedInitialCompletionChain.Artifacts[0].source_artifact_reference = 'forged-predecessor.md'
 $forgedInitialCompletionTerminal = New-TerminalResponsibilityArtifact $completeItem.terminal_evidence $completeItem.work_item_id $completeItem.status $forgedInitialCompletionChain.FinalReference $forgedInitialCompletionChain.References $forgedInitialCompletionChain.ModeConstraint
 $forgedInitialCompletion = Invoke-ScopeScenario @{
   scenario_type = 'scope-engine'; operation = 'complete-scope'; work_items = @($completeItem)
   terminal_artifacts = @($forgedInitialCompletionTerminal)
   responsibility_chain_artifacts = @($forgedInitialCompletionChain.Artifacts)
   terminal_scope_report = (New-TerminalScopeReport 'runs/forged-initial-completion-report.md' @($completeItem) @($forgedInitialCompletionChain))
 }
 Assert-Equal $forgedInitialCompletion.scope_status 'scope-blocked' 'Scope completion must reject a forged index-0 implementation predecessor'
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/structural-gate.Tests.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/structural-gate.Tests.ps1
index 615cc22..81d3830 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/structural-gate.Tests.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/structural-gate.Tests.ps1
@@ -1432,20 +1432,30 @@ try {
   $root = New-Case 'forged-task6-work-item-trace'
   Write-Report $root (Get-ValidReport)
   $path = Join-Path $root 'structural-gate-fixture/07-technical-design.md'
   Write-Utf8 $path ((Get-Content -Raw -Encoding utf8 -LiteralPath $path) -replace '\| WORK-ADMIN-LOCKS \| master-plan.md#PLAN-ADMIN-001 \| 4 \| REQ-101, SC-101 \| not-applicable \|', '| WORK-ADMIN-LOCKS | master-plan.md#PLAN-ADMIN-001 | 4 | REQ-101 | not-applicable |')
   Assert-Rejected 'well-formed Task 6 trace cannot narrow approved acceptance' $root 'Structural gate report must bind through exact Task 6 approved-plan and work-item trace tables'
 
   $root = New-Case 'canonical-template-produced-migration-unit-report'
   Write-Report $root (Get-ValidReport)
   Assert-Accepted 'canonical template-produced migration-unit report' $root
 
+  foreach ($semanticDecoy in @(
+    [pscustomobject]@{ Name = 'fenced'; Text = "~~~markdown`n## Work Item Changed Files`n| decoy |`n|---|`n| ignored |`n~~~" },
+    [pscustomobject]@{ Name = 'commented'; Text = "<!--`n## Work Item Changed Files`n| decoy |`n|---|`n| ignored |`n-->" },
+    [pscustomobject]@{ Name = 'indented'; Text = "    ## Work Item Changed Files`n    | decoy |`n    |---|`n    | ignored |" }
+  )) {
+    $root = New-Case "semantic-markdown-$($semanticDecoy.Name)"
+    Write-Report $root ((Get-ValidReport) + "`n$($semanticDecoy.Text)`n")
+    Assert-Accepted "$($semanticDecoy.Name) Markdown examples do not inflate structural authority" $root
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
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/validate-migration-framework.Tests.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/validate-migration-framework.Tests.ps1
index 26bcb41..d00c782 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/validate-migration-framework.Tests.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/validate-migration-framework.Tests.ps1
@@ -545,20 +545,55 @@ if ($ResponsibilityConformanceOnly) {
     }
     if ($controlTransferCase.ExpectedActive) {
       Assert-True ($controlTransferResult.ExitCode -eq 0) "Non-dominating $($controlTransferCase.Name) registration must satisfy source integrity. Output: $($controlTransferResult.Output)"
       Assert-Contains $controlTransferResult.Output 'PASS: migration framework (SourceIntegrityOnly)' "Non-dominating control-transfer registration: $($controlTransferCase.Name)"
     }
     else {
       Assert-True ($controlTransferResult.ExitCode -eq 1) "Dominated $($controlTransferCase.Name) registration must fail source integrity. Output: $($controlTransferResult.Output)"
       Assert-Contains $controlTransferResult.Output 'Responsibility source-integrity coverage missing: post-implementation queue advance' "Dominated control-transfer registration: $($controlTransferCase.Name)"
     }
   }
+  foreach ($namedBlockControlTransferCase in @(
+    [pscustomobject]@{ Name = 'top-level return'; Body = "return`n$coverageRegistration"; ExpectedActive = $false },
+    [pscustomobject]@{ Name = 'top-level throw'; Body = "throw 'stop'`n$coverageRegistration"; ExpectedActive = $false },
+    [pscustomobject]@{ Name = 'top-level exit'; Body = "exit 1`n$coverageRegistration"; ExpectedActive = $false },
+    [pscustomobject]@{ Name = 'conditional top-level return'; Body = "if (`$false) { return }`n$coverageRegistration"; ExpectedActive = $true }
+  )) {
+    $namedBlockControlTransferResult = Invoke-IsolatedMutation -SourceRoot $testRoot -Mutation {
+      param($fixtureRoot)
+      $fixtureScenario = Join-Path $fixtureRoot 'tests/scenarios/scope-engine.Tests.ps1'
+      $fixtureText = [IO.File]::ReadAllText($fixtureScenario, [Text.Encoding]::UTF8)
+      $mutatedText = Replace-ExactOrFail $fixtureText $coverageRegistration $namedBlockControlTransferCase.Body "named-block control-transfer coverage registration: $($namedBlockControlTransferCase.Name)"
+      $parseTokens = $null
+      $parseErrors = $null
+      [void][Management.Automation.Language.Parser]::ParseInput($mutatedText, [ref]$parseTokens, [ref]$parseErrors)
+      if (@($parseErrors).Count -ne 0) { throw "Named-block control-transfer fixture must remain parse-valid: $($namedBlockControlTransferCase.Name): $(@($parseErrors).Message -join '; ')" }
+      [IO.File]::WriteAllText($fixtureScenario, $mutatedText, [Text.UTF8Encoding]::new($false))
+      $fixtureValidator = Join-Path $fixtureRoot 'tests/validate-migration-framework.ps1'
+      $previousFixtureErrorActionPreference = $ErrorActionPreference
+      $ErrorActionPreference = 'Continue'
+      try {
+        $output = & $powershell -NoProfile -ExecutionPolicy Bypass -File $fixtureValidator -Check SourceIntegrityOnly -Root $fixtureRoot -AllowReducedResponsibilityFixture 2>&1
+        $exitCode = $LASTEXITCODE
+      }
+      finally { $ErrorActionPreference = $previousFixtureErrorActionPreference }
+      [pscustomobject]@{ ExitCode = $exitCode; Output = ($output -join [Environment]::NewLine) }
+    }
+    if ($namedBlockControlTransferCase.ExpectedActive) {
+      Assert-True ($namedBlockControlTransferResult.ExitCode -eq 0) "Non-dominating $($namedBlockControlTransferCase.Name) registration must satisfy source integrity. Output: $($namedBlockControlTransferResult.Output)"
+      Assert-Contains $namedBlockControlTransferResult.Output 'PASS: migration framework (SourceIntegrityOnly)' "Named-block control-transfer registration: $($namedBlockControlTransferCase.Name)"
+    }
+    else {
+      Assert-True ($namedBlockControlTransferResult.ExitCode -eq 1) "Dominated $($namedBlockControlTransferCase.Name) registration must fail source integrity. Output: $($namedBlockControlTransferResult.Output)"
+      Assert-Contains $namedBlockControlTransferResult.Output 'Responsibility source-integrity coverage missing: post-implementation queue advance' "Named-block control-transfer registration: $($namedBlockControlTransferCase.Name)"
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
index f7f1f11..cd92d10 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/validate-migration-framework.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/validate-migration-framework.ps1
@@ -9700,21 +9700,21 @@ function Test-ArcStaticNonEmptyCoverageCollection([Management.Automation.Languag
       $expression.Left -is [Management.Automation.Language.ConstantExpressionAst] -and
       $expression.Right -is [Management.Automation.Language.ConstantExpressionAst] -and
       $expression.Left.Value -is [int] -and
       $expression.Right.Value -is [int]
     )
   }
   return $false
 }
 
 function Test-ArcCoverageStatementIsReachable(
-  [Management.Automation.Language.StatementBlockAst]$Block,
+  [Management.Automation.Language.Ast]$Block,
   [Management.Automation.Language.StatementAst]$Statement
 ) {
   foreach ($candidate in $Block.Statements) {
     if ([object]::ReferenceEquals($candidate, $Statement)) { return $true }
     if (
       $candidate -is [Management.Automation.Language.BreakStatementAst] -or
       $candidate -is [Management.Automation.Language.ContinueStatementAst] -or
       $candidate -is [Management.Automation.Language.ReturnStatementAst] -or
       $candidate -is [Management.Automation.Language.ThrowStatementAst] -or
       $candidate -is [Management.Automation.Language.ExitStatementAst]
@@ -9804,24 +9804,26 @@ function Test-ResponsibilitySourceIntegrity {
             continue
           }
           if ($ancestor -is [Management.Automation.Language.StatementBlockAst]) {
             if ($ancestor.Parent -isnot [Management.Automation.Language.ForEachStatementAst]) { return $false }
             if (-not (Test-ArcCoverageStatementIsReachable $ancestor $containingStatement)) { return $false }
             $ancestor = $ancestor.Parent
             continue
           }
           if ($ancestor -is [Management.Automation.Language.ForEachStatementAst]) {
             if (-not (Test-ArcStaticNonEmptyCoverageCollection $ancestor.Condition)) { return $false }
+            $containingStatement = $ancestor
             $ancestor = $ancestor.Parent
             continue
           }
           if ($ancestor -is [Management.Automation.Language.NamedBlockAst]) {
+            if (-not (Test-ArcCoverageStatementIsReachable $ancestor $containingStatement)) { return $false }
             $ancestor = $ancestor.Parent
             continue
           }
           if ($ancestor -is [Management.Automation.Language.ScriptBlockAst]) {
             return $null -eq $ancestor.Parent
           }
           return $false
         }
         return $false
       }, $true))
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/architecture-review.validation.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/architecture-review.validation.ps1
index f9fa8fd..39df0a0 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/architecture-review.validation.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/architecture-review.validation.ps1
@@ -341,27 +341,40 @@ function Test-ArchitectureReview([string]$Root, [string]$ContractText) {
   $taskProvenanceTable = & $getStrictContractTable $visibleReviewTemplate 'Task Provenance' @(
     'Task / Unit', 'Task-base SHA', 'Final-tree SHA', 'Source Artifact'
   ) 'Migration review report'
   $responsibilityHandoffTable = & $getStrictContractTable $visibleReviewTemplate 'Architecture Responsibility Handoff' @(
     'Responsibility Contract Version', 'Tree Conformance', 'Responsibility Conformance',
     'Verification Ownership', 'Architecture Conformance State', 'Evidence References'
   ) 'Migration review report'
 
   $verdictValues = [ordered]@{}
   $verdictModes = [Collections.Generic.List[string]]::new()
+  $ruleResolution = ''
+  $ruleResolutionSection = & $getSection $visibleReviewTemplate 'Rule Resolution' 'Migration review report'
+  $ruleResolutionMatches = [regex]::Matches($ruleResolutionSection, '(?im)^[ \t]*-[ \t]*Rule Resolution Verdict:[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$')
+  if ($ruleResolutionMatches.Count -ne 1) {
+    $errors.Add("Migration review report Rule Resolution Verdict must appear exactly once; found $($ruleResolutionMatches.Count)")
+  }
+  else {
+    $ruleResolution = $ruleResolutionMatches[0].Groups['value'].Value.Trim().Trim([char[]]@('<', '>', '`'))
+    if ($ruleResolution -ceq 'RESOLVED | BLOCKED') { $verdictModes.Add('schema') }
+    elseif ($ruleResolution -in @('RESOLVED', 'BLOCKED')) { $verdictModes.Add('rendered') }
+    else { $errors.Add("Migration review report Rule Resolution Verdict has invalid value: $ruleResolution") }
+  }
   @(
     [pscustomobject]@{ Label = 'Architecture Conformance Verdict'; Schema = 'PASS | BLOCKED'; Allowed = @('PASS', 'BLOCKED') }
     [pscustomobject]@{ Label = 'Canonical Selector Verdict'; Schema = 'PASS | BLOCKED'; Allowed = @('PASS', 'BLOCKED') }
     [pscustomobject]@{ Label = 'Tree Conformance Verdict'; Schema = 'PASS | BLOCKED'; Allowed = @('PASS', 'BLOCKED') }
     [pscustomobject]@{ Label = 'Responsibility Conformance Verdict'; Schema = 'PASS | BLOCKED'; Allowed = @('PASS', 'BLOCKED') }
     [pscustomobject]@{ Label = 'Verification Ownership Verdict'; Schema = 'PASS | BLOCKED'; Allowed = @('PASS', 'BLOCKED') }
     [pscustomobject]@{ Label = 'Production Activation-path Verdict'; Schema = 'PASS | BLOCKED | NOT_APPLICABLE'; Allowed = @('PASS', 'BLOCKED', 'NOT_APPLICABLE') }
+    [pscustomobject]@{ Label = 'Change Hygiene Verdict'; Schema = 'PASS | BLOCKED'; Allowed = @('PASS', 'BLOCKED') }
   ) | ForEach-Object {
     $matches = [regex]::Matches($visibleReviewTemplate, '(?im)^[ \t]*-[ \t]*(?:\*\*)?' + [regex]::Escape($_.Label) + '(?:\*\*)?:[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$')
     if ($matches.Count -ne 1) {
       $errors.Add("Migration review report $($_.Label) must appear exactly once with the exact enum; found $($matches.Count)")
       return
     }
     $value = $matches[0].Groups['value'].Value.Trim().Trim([char[]]@('<', '>', '`'))
     if ($value -ceq $_.Schema) {
       $verdictModes.Add('schema')
     }
@@ -461,33 +474,93 @@ function Test-ArchitectureReview([string]$Root, [string]$ContractText) {
       $verdictModes.Add('schema')
     }
     elseif ($overallVerdict -in @('Approve', 'Approve-with-fixes', 'Reject')) {
       $verdictModes.Add('rendered')
     }
     else {
       $errors.Add("Migration review report overall Verdict has invalid value: $overallVerdict")
     }
   }
 
+  $criticalCount = -1
+  $majorCount = -1
+  foreach ($countDefinition in @(
+    [pscustomobject]@{ Label = 'Critical count'; Target = 'critical' }
+    [pscustomobject]@{ Label = 'Major count'; Target = 'major' }
+  )) {
+    $countMatches = [regex]::Matches($visibleReviewTemplate, '(?im)^[ \t]*-[ \t]*(?:\*\*)?' + [regex]::Escape($countDefinition.Label) + ':(?:\*\*)?[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$')
+    if ($countMatches.Count -ne 1) {
+      $errors.Add("Migration review report $($countDefinition.Label) must appear exactly once; found $($countMatches.Count)")
+      continue
+    }
+    $countValue = $countMatches[0].Groups['value'].Value.Trim().Trim([char[]]@('<', '>', '`'))
+    if ($countValue -ceq 'non-negative integer') {
+      $verdictModes.Add('schema')
+      continue
+    }
+    if ($countValue -cnotmatch '^[0-9]+$') {
+      $errors.Add("Migration review report $($countDefinition.Label) must be a non-negative integer; got $countValue")
+      continue
+    }
+    $verdictModes.Add('rendered')
+    if ($countDefinition.Target -ceq 'critical') { $criticalCount = [int]$countValue }
+    else { $majorCount = [int]$countValue }
+  }
+
   $distinctVerdictModes = @($verdictModes | Select-Object -Unique)
-  if ($verdictModes.Count -ne 8 -or $distinctVerdictModes.Count -ne 1) {
+  if ($verdictModes.Count -ne 12 -or $distinctVerdictModes.Count -ne 1) {
     $errors.Add('Migration review report must use either all-schema or all-rendered verdict mode; mixed mode is invalid')
   }
   elseif ($distinctVerdictModes[0] -ceq 'rendered') {
-    $concreteVerdicts = @($verdictValues.Values)
-    if ($concreteVerdicts -contains 'BLOCKED') {
-      if ($overallVerdict -cne 'Reject') {
-        $errors.Add('Migration review report requires overall Reject when any architecture-first verdict is BLOCKED, independently of severity counts')
-      }
-      if ($behaviorState -cne 'NOT_RUN') {
-        $errors.Add('Migration review report must stop before behavior analysis when an architecture-first verdict is BLOCKED')
-      }
+    $derivedArchitecture = if (
+      $verdictValues['Tree Conformance Verdict'] -ceq 'PASS' -and
+      $verdictValues['Responsibility Conformance Verdict'] -ceq 'PASS' -and
+      $verdictValues['Verification Ownership Verdict'] -ceq 'PASS'
+    ) { 'PASS' } else { 'BLOCKED' }
+    if ($verdictValues['Architecture Conformance Verdict'] -cne $derivedArchitecture) {
+      $errors.Add('Migration review report Architecture Conformance Verdict must equal the verdict derived from Tree, Responsibility, and Verification Ownership')
+    }
+    if (
+      $null -ne $responsibilityHandoffTable -and
+      (
+        $responsibilityHandoffTable.Row[1] -cne $verdictValues['Tree Conformance Verdict'] -or
+        $responsibilityHandoffTable.Row[2] -cne $verdictValues['Responsibility Conformance Verdict'] -or
+        $responsibilityHandoffTable.Row[3] -cne $verdictValues['Verification Ownership Verdict'] -or
+        $responsibilityHandoffTable.Row[4] -cne $verdictValues['Architecture Conformance Verdict']
+      )
+    ) {
+      $errors.Add('Migration review report handoff cells must equal the visible Tree, Responsibility, Verification Ownership, and derived Architecture verdicts')
+    }
+    $blockedPreBehaviorVerdicts = @(
+      @(
+        'Canonical Selector Verdict', 'Architecture Conformance Verdict',
+        'Tree Conformance Verdict', 'Responsibility Conformance Verdict',
+        'Verification Ownership Verdict', 'Production Activation-path Verdict'
+      ) | Where-Object { $verdictValues[$_] -ceq 'BLOCKED' }
+    )
+    $preBehaviorBlocked =
+      $ruleResolution -ceq 'BLOCKED' -or
+      $blockedPreBehaviorVerdicts.Count -gt 0
+    if ($preBehaviorBlocked -and $behaviorState -cne 'NOT_RUN') {
+      $errors.Add('Migration review report must stop before behavior analysis when an architecture-first verdict is BLOCKED')
+    }
+    $allGatesExecutable =
+      -not $preBehaviorBlocked -and
+      $behaviorState -ceq 'COMPLETE' -and
+      $verdictValues['Change Hygiene Verdict'] -ceq 'PASS'
+    $derivedOverall = if (-not $allGatesExecutable -or $criticalCount -gt 0) {
+      'Reject'
+    }
+    elseif ($majorCount -gt 0) { 'Approve-with-fixes' }
+    else { 'Approve' }
+    if ($overallVerdict -cne $derivedOverall) {
+      $errors.Add("Migration review report overall Verdict must equal derived verdict $derivedOverall")
     }
   }
 
   if (
     $visibleReviewTemplate -cnotmatch '(?s)Keep `Selected Migration Unit` only when `Delivery Adapter Kind` is `migration-unit`.*otherwise omit it\.' -and
     $visibleReviewTemplate -cnotmatch '(?s)Chỉ giữ `Selected Migration Unit` khi `Delivery Adapter Kind` là `migration-unit`.*otherwise omit it\.'
   ) {
     $errors.Add('Migration review report must keep Selected Migration Unit only for the migration-unit adapter and otherwise omit it')
   }
 
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1
index 2b9c330..88d4036 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1
@@ -1424,27 +1424,45 @@ function Invoke-ArcPinnedGit {
   $output = @(& git -C $SourceRoot @Arguments 2>$null)
   if ($LASTEXITCODE -ne 0) { throw "Pinned source git command failed: git -C $SourceRoot $($Arguments -join ' ')" }
   return ($output -join [Environment]::NewLine).Trim()
 }
 
 function ConvertTo-ArcCanonicalRepositoryPath {
   [CmdletBinding()]
   param([Parameter(Mandatory)][AllowEmptyString()][string]$Path)
 
   if ([string]::IsNullOrWhiteSpace($Path) -or $Path -cne $Path.Trim()) { return '' }
+  foreach ($character in $Path.ToCharArray()) {
+    if ([char]::IsControl($character)) { return '' }
+  }
   $canonicalPath = $Path.Replace('\', '/')
-  if (
-    $canonicalPath -cnotmatch '^(?:[A-Za-z0-9_.-]+/)*[A-Za-z0-9_.-]+$' -or
-    $canonicalPath -match '^(?:/|[A-Za-z]:)' -or
-    @($canonicalPath -split '/' | Where-Object { $_ -cin @('.', '..') }).Count -gt 0
-  ) { return '' }
-  return $canonicalPath
+  if ($canonicalPath.StartsWith('/', [StringComparison]::Ordinal) -or $canonicalPath -cmatch '^[A-Za-z]:' -or $canonicalPath -match '[<>:"|?*#;]') { return '' }
+  $segments = @($canonicalPath.Split('/'))
+  if ($segments.Count -eq 0) { return '' }
+  $canonicalSegments = [Collections.Generic.List[string]]::new()
+  foreach ($segment in $segments) {
+    if ([string]::IsNullOrWhiteSpace($segment) -or $segment -cne $segment.Trim() -or $segment -cin @('.', '..')) { return '' }
+    $canonicalSegments.Add($segment.Normalize([Text.NormalizationForm]::FormC))
+  }
+  return ($canonicalSegments -join '/')
+}
+
+function ConvertTo-ArcComparableRootPath {
+  [CmdletBinding()]
+  param([Parameter(Mandatory)][string]$Path)
+
+  $fullPath = [IO.Path]::GetFullPath($Path)
+  $pathRoot = [IO.Path]::GetPathRoot($fullPath)
+  if ($fullPath.Length -gt $pathRoot.Length) {
+    return $fullPath.TrimEnd([char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar))
+  }
+  return $fullPath
 }
 
 function ConvertTo-ArcCanonicalReviewEvidenceItem {
   [CmdletBinding()]
   param([Parameter(Mandatory)][AllowEmptyString()][string]$EvidenceItem)
 
   $match = [regex]::Match(
     $EvidenceItem,
     '^(?<kind>source|diff):(?<task>[0-9a-f]{40})(?<range>\.\.(?<final>[0-9a-f]{40}))?:(?<paths>[^#;\r\n]+)#(?<anchor>[A-Za-z][A-Za-z0-9_.:-]*)$'
   )
@@ -1518,20 +1536,43 @@ function Get-ArcImplementationReviewProvenance {
   }
   if ($table.Count -lt 3) {
     $Errors.Add('responsibility-evidence-missing')
     return $null
   }
   $rows = @($table | Select-Object -Skip 2)
   foreach ($row in $rows) {
     $canonicalPath = ConvertTo-ArcCanonicalRepositoryPath -Path ([string]$row[1]).Trim()
     if ($canonicalPath -ceq '') { $Errors.Add('responsibility-evidence-missing') }
     else { $row[1] = $canonicalPath }
+    $editedRegion = ([string]$row[3]).Trim()
+    $formatterCommand = ([string]$row[4]).Trim()
+    $unrelatedDiff = ([string]$row[5]).Trim()
+    if (
+      $editedRegion -cnotmatch '^[A-Za-z_][A-Za-z0-9_.:-]*(?:, [A-Za-z_][A-Za-z0-9_.:-]*)*$' -or
+      $editedRegion -match '(?i)^(?:none|all|entire|whole|repository|repo|root|file)$'
+    ) { $Errors.Add('change-hygiene-invalid') }
+    if ($formatterCommand -cne 'none') {
+      $normalizedFormatterCommand = $formatterCommand.Replace('\', '/')
+      $formatterOperands = @([regex]::Matches($normalizedFormatterCommand, '(?<!\S)(?:"(?<double>[^"]*)"|''(?<single>[^'']*)''|(?<bare>[^\s"'']+))(?!\S)') | ForEach-Object {
+        if ($_.Groups['double'].Success) { $_.Groups['double'].Value }
+        elseif ($_.Groups['single'].Success) { $_.Groups['single'].Value }
+        else { $_.Groups['bare'].Value }
+      })
+      if (
+        $formatterCommand -match '[\x00-\x1F\x7F;&|<>]' -or
+        @($formatterOperands | Where-Object { $_ -cin @('.', './', '*', '--all') }).Count -gt 0 -or
+        $formatterOperands -cnotcontains $canonicalPath
+      ) { $Errors.Add('change-hygiene-invalid') }
+    }
+    if ($unrelatedDiff -cne 'none' -and $unrelatedDiff -cnotmatch '^confirmed:MAJOR-[A-Z0-9]+(?:-[A-Z0-9]+)*$') {
+      $Errors.Add('change-hygiene-invalid')
+    }
   }
   if ($Errors.Count -ne 0) { return $null }
   $taskUnits = @($rows | ForEach-Object { $_[0].Trim() } | Sort-Object -Unique)
   $taskBases = @($rows | ForEach-Object { $_[7].Trim() } | Sort-Object -Unique)
   $finalTrees = @($rows | ForEach-Object { $_[8].Trim() } | Sort-Object -Unique)
   if ($taskUnits.Count -ne 1 -or $taskUnits[0] -cnotmatch '^(?:WORK|UNIT)-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -or $taskBases.Count -ne 1 -or $finalTrees.Count -ne 1 -or $taskBases[0] -cnotmatch '^[0-9a-f]{40}$' -or $finalTrees[0] -cnotmatch '^[0-9a-f]{40}$') {
     $Errors.Add('responsibility-evidence-missing')
     return $null
   }
   return [pscustomobject]@{ TaskUnit = $taskUnits[0]; TaskBaseSha = $taskBases[0]; FinalTreeSha = $finalTrees[0]; Rows = $rows }
@@ -1542,42 +1583,47 @@ function Test-ArcDeletedSourceEvidence {
   param(
     [Parameter(Mandatory)][string]$Path,
     [Parameter(Mandatory)][string]$SourceText,
     [Parameter(Mandatory)][string]$DiffText,
     [string[]]$OwnerIds = @(),
     [Parameter(Mandatory)][AllowEmptyCollection()][Collections.Generic.List[string]]$Errors
   )
 
   $removedDiff = @($DiffText -split '\r?\n' | Where-Object { $_ -cmatch '^-' -and $_ -cnotmatch '^---' }) -join "`n"
   $deletedOwners = [Collections.Generic.List[object]]::new()
-  $ownerMatches = @([regex]::Matches($SourceText, '(?ms)^\s*@responsibility\s+(?<id>RESP-[A-Z0-9]+(?:-[A-Z0-9]+)*)\s*$.*?(?=^\s*@responsibility\s+|\z)'))
-  foreach ($ownerMatch in $ownerMatches) {
-    if ($OwnerIds.Count -gt 0 -and $OwnerIds -cnotcontains $ownerMatch.Groups['id'].Value) { continue }
-    $block = $ownerMatch.Value
+  $sourceLexicalLines = @(Get-ArcSourceLexicalLines -SourceText $SourceText -SourcePath $Path)
+  if (@($sourceLexicalLines | Where-Object { $_.Ambiguous }).Count -gt 0) {
+    $Errors.Add('responsibility-evidence-missing')
+    return @()
+  }
+  $ownerBlocks = @(Get-ArcResponsibilitySourceBlocks -SourceText $SourceText -LexicalLines $sourceLexicalLines -SourcePath $Path)
+  foreach ($ownerBlock in $ownerBlocks) {
+    if ($OwnerIds.Count -gt 0 -and $OwnerIds -cnotcontains $ownerBlock.Id) { continue }
+    $block = $ownerBlock.Text
     $owner = [pscustomobject]@{
-      Id = $ownerMatch.Groups['id'].Value
+      Id = $ownerBlock.Id
       Path = $Path
       BasePath = $Path
       FinalPath = ''
       RenameMapping = ''
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
     $anchors = [Collections.Generic.List[string]]::new()
-    $anchors.Add($ownerMatch.Groups['id'].Value)
+    $anchors.Add($ownerBlock.Id)
     foreach ($definition in @(
       [pscustomobject]@{ Property = 'OwnerSymbols'; Pattern = '^\s*@owner-symbol\s+(?<value>[A-Za-z][A-Za-z0-9_.:-]*)\s*$' },
       [pscustomobject]@{ Property = 'Symbols'; Pattern = '^\s*@public-symbol\s+(?<value>[A-Za-z][A-Za-z0-9_.:-]*)\s*$' },
       [pscustomobject]@{ Property = 'Capabilities'; Pattern = '^\s*@owned-capability\s+(?<value>CAP-[A-Z0-9]+(?:-[A-Z0-9]+)*)\s*$' },
       [pscustomobject]@{ Property = 'Effects'; Pattern = '^\s*@effect\s+(?<value>[^\r\n]+?)\s*$' },
       [pscustomobject]@{ Property = 'ArchitectureAuthorities'; Pattern = '^\s*@architecture-authority\s+(?<value>[a-z][a-z-]*)\s*$' },
       [pscustomobject]@{ Property = 'CoLocationPolicies'; Pattern = '^\s*@co-location-policy\s+(?<value>[a-z][a-z-]*)\s*$' },
       [pscustomobject]@{ Property = 'VerificationOwners'; Pattern = '^\s*@verification-owner\s+(?<value>VERIFY-OWNER-[A-Z0-9]+(?:-[A-Z0-9]+)*)\s*$' }
     )) {
       $matches = @([regex]::Matches($block, "(?m)$($definition.Pattern)"))
@@ -1587,42 +1633,72 @@ function Test-ArcDeletedSourceEvidence {
         $owner.($definition.Property).Add($value)
         $anchors.Add($value)
       }
     }
     foreach ($routeMatch in @([regex]::Matches($block, '(?m)^\s*route\s+(?<symbol>[A-Za-z][A-Za-z0-9_.:-]*)\s*->\s*(?<provider>[A-Za-z][A-Za-z0-9_.:-]*)\s*$'))) {
       $owner.RouteSymbols.Add($routeMatch.Groups['symbol'].Value)
       $owner.Providers.Add($routeMatch.Groups['provider'].Value)
       $anchors.Add($routeMatch.Groups['symbol'].Value)
       $anchors.Add($routeMatch.Groups['provider'].Value)
     }
-    if ($removedDiff.IndexOf("@responsibility $($ownerMatch.Groups['id'].Value)", [StringComparison]::Ordinal) -lt 0 -or @($anchors | Select-Object -Unique | Where-Object { $removedDiff.IndexOf($_, [StringComparison]::Ordinal) -lt 0 }).Count -gt 0) {
+    if ($removedDiff.IndexOf("@responsibility $($ownerBlock.Id)", [StringComparison]::Ordinal) -lt 0 -or @($anchors | Select-Object -Unique | Where-Object { $removedDiff.IndexOf($_, [StringComparison]::Ordinal) -lt 0 }).Count -gt 0) {
       $Errors.Add('responsibility-evidence-missing')
     }
     $deletedOwners.Add($owner)
   }
   return $deletedOwners.ToArray()
 }
 
 function Get-ArcSourceLexicalLines {
   [CmdletBinding()]
-  param([AllowEmptyString()][string]$SourceText)
+  param(
+    [AllowEmptyString()][string]$SourceText,
+    [AllowEmptyString()][string]$SourcePath = ''
+  )
 
   $lines = @($SourceText -split '\r\n|\n|\r')
   $result = [Collections.Generic.List[object]]::new()
+  $extension = [IO.Path]::GetExtension($SourcePath).ToLowerInvariant()
+  $unknownLanguage = $extension -eq '' -or $extension -ceq '.source'
+  $cFamilyExtensions = @('.c', '.h', '.cc', '.cpp', '.cxx', '.hpp', '.java', '.js', '.jsx', '.mjs', '.cjs', '.ts', '.tsx', '.dart', '.cs', '.rs', '.go', '.swift', '.kt', '.kts', '.scala')
+  $slashLineComment = $unknownLanguage -or $extension -in $cFamilyExtensions
+  $dashLineComment = $unknownLanguage -or $extension -in @('.sql', '.hs', '.lhs', '.lua')
+  $semicolonLineComment = $unknownLanguage -or $extension -in @('.lisp', '.cl', '.clj', '.cljs', '.scm', '.ss', '.rkt', '.asm', '.s', '.ini', '.cfg')
+  $hashLineComment = $unknownLanguage -or $extension -in @('.py', '.pyw', '.sh', '.bash', '.zsh', '.rb', '.pl', '.pm', '.yaml', '.yml', '.toml', '.ps1', '.psm1', '.psd1')
+  $cPreprocessor = $extension -in @('.c', '.h', '.cc', '.cpp', '.cxx', '.hpp')
+  $hashDirectiveLanguage = $extension -in @('.cs', '.rs')
+  $javascriptLanguage = $extension -in @('.js', '.jsx', '.mjs', '.cjs', '.ts', '.tsx')
+  $cStyleBlockComment = $unknownLanguage -or $extension -in ($cFamilyExtensions + @('.css', '.sql'))
+  $markupBlockComment = $unknownLanguage -or $extension -in @('.html', '.htm', '.xml', '.md', '.markdown')
+  $powerShellBlockComment = $unknownLanguage -or $extension -in @('.ps1', '.psm1', '.psd1')
   $blockCommentEnd = ''
   $blockCommentStart = -1
   $multilineStringDelimiter = ''
   $multilineStringStart = -1
   for ($lineIndex = 0; $lineIndex -lt $lines.Count; $lineIndex++) {
     $line = $lines[$lineIndex]
+    $semanticMarkerText = ''
+    if ($blockCommentEnd -ceq '' -and $multilineStringDelimiter -ceq '') {
+      $semanticMarkerMatch = if ($slashLineComment) {
+        [regex]::Match($line, '^\s*//\s*arc:(?<payload>(?:@[a-z][a-z-]*|route|scenario)[ \t]+\S(?:.*\S)?)\s*$')
+      }
+      else { $null }
+      if (($null -eq $semanticMarkerMatch -or -not $semanticMarkerMatch.Success) -and ($hashLineComment -or $powerShellBlockComment)) {
+        $semanticMarkerMatch = [regex]::Match($line, '^\s*#\s*arc:(?<payload>(?:@[a-z][a-z-]*|route|scenario)[ \t]+\S(?:.*\S)?)\s*$')
+      }
+      if ($null -ne $semanticMarkerMatch -and $semanticMarkerMatch.Success) {
+        $semanticMarkerText = $semanticMarkerMatch.Groups['payload'].Value.Trim()
+      }
+    }
     $structural = [Text.StringBuilder]::new()
     $hasCode = $false
+    $lineAmbiguous = $false
     $index = 0
     while ($index -lt $line.Length) {
       if ($multilineStringDelimiter -ne '') {
         $hasCode = $true
         $literalEnd = $line.IndexOf($multilineStringDelimiter, $index, [StringComparison]::Ordinal)
         if ($literalEnd -lt 0) { $index = $line.Length; continue }
         $index = $literalEnd + $multilineStringDelimiter.Length
         $multilineStringDelimiter = ''
         $multilineStringStart = -1
         continue
@@ -1638,31 +1714,64 @@ function Get-ArcSourceLexicalLines {
 
       $remaining = $line.Substring($index)
       $multilineOpening = [regex]::Match($remaining, '^(?<delimiter>"{3,}|''{3,})')
       if ($multilineOpening.Success) {
         $hasCode = $true
         $multilineStringDelimiter = $multilineOpening.Groups['delimiter'].Value
         $multilineStringStart = $lineIndex
         $index += $multilineStringDelimiter.Length
         continue
       }
-      if ($remaining.StartsWith('<!--', [StringComparison]::Ordinal)) { $blockCommentEnd = '-->'; $blockCommentStart = $lineIndex; $index += 4; continue }
-      if ($remaining.StartsWith('/*', [StringComparison]::Ordinal)) { $blockCommentEnd = '*/'; $blockCommentStart = $lineIndex; $index += 2; continue }
-      if ($remaining.StartsWith('<#', [StringComparison]::Ordinal)) { $blockCommentEnd = '#>'; $blockCommentStart = $lineIndex; $index += 2; continue }
+      if ($markupBlockComment -and $remaining.StartsWith('<!--', [StringComparison]::Ordinal)) { $blockCommentEnd = '-->'; $blockCommentStart = $lineIndex; $index += 4; continue }
+      if ($cStyleBlockComment -and $remaining.StartsWith('/*', [StringComparison]::Ordinal)) { $blockCommentEnd = '*/'; $blockCommentStart = $lineIndex; $index += 2; continue }
+      if ($powerShellBlockComment -and $remaining.StartsWith('<#', [StringComparison]::Ordinal)) { $blockCommentEnd = '#>'; $blockCommentStart = $lineIndex; $index += 2; continue }
 
       $character = $line[$index]
-      if ($remaining.StartsWith('//', [StringComparison]::Ordinal)) { break }
-      if ($remaining.StartsWith('--', [StringComparison]::Ordinal) -and ($remaining.Length -eq 2 -or [char]::IsWhiteSpace($remaining[2]))) { break }
-      if (-not $hasCode -and $character -eq ';' -and ($remaining.Length -eq 1 -or [char]::IsWhiteSpace($remaining[1]))) { break }
+      if ($slashLineComment -and $remaining.StartsWith('//', [StringComparison]::Ordinal)) { break }
+      if ($dashLineComment -and $remaining.StartsWith('--', [StringComparison]::Ordinal) -and ($remaining.Length -eq 2 -or [char]::IsWhiteSpace($remaining[2]))) { break }
+      if ($semicolonLineComment -and -not $hasCode -and $character -eq ';' -and ($remaining.Length -eq 1 -or [char]::IsWhiteSpace($remaining[1]))) { break }
       if ($character -eq '#') {
-        $preprocessor = [regex]::Match($remaining, '^#\s*(?:define|elif|else|endif|error|if|ifdef|ifndef|include|line|pragma|undef|warning)\b')
-        if (-not $preprocessor.Success) { break }
+        $preprocessor = $cPreprocessor -and [regex]::IsMatch($remaining, '^#\s*(?:define|elif|else|endif|error|if|ifdef|ifndef|include|line|pragma|undef|warning)\b')
+        if (-not $preprocessor -and -not $hashDirectiveLanguage) {
+          if ($hashLineComment) { break }
+        }
+      }
+      if ($javascriptLanguage -and $character -eq '/') {
+        $structuralPrefix = $structural.ToString().TrimEnd()
+        $regexCanStart =
+          $structuralPrefix.Length -eq 0 -or
+          $structuralPrefix[-1] -in @('=', '(', ':', ',', '!', '[', '{', ';', '?', '&', '|', '+', '-', '*', '%', '^', '~', '<', '>') -or
+          $structuralPrefix -cmatch '(?:^|\s)(?:return|case|throw|yield|await|typeof|instanceof|in|of|delete|void|new)\s*$'
+        if ($regexCanStart) {
+          $regexIndex = $index + 1
+          $insideCharacterClass = $false
+          $regexClosed = $false
+          while ($regexIndex -lt $line.Length) {
+            $regexCharacter = $line[$regexIndex]
+            if ($regexCharacter -eq '\' -and $regexIndex + 1 -lt $line.Length) { $regexIndex += 2; continue }
+            if ($regexCharacter -eq '[') { $insideCharacterClass = $true; $regexIndex++; continue }
+            if ($regexCharacter -eq ']' -and $insideCharacterClass) { $insideCharacterClass = $false; $regexIndex++; continue }
+            if ($regexCharacter -eq '/' -and -not $insideCharacterClass) { $regexClosed = $true; $regexIndex++; break }
+            $regexIndex++
+          }
+          if ($regexClosed) {
+            while ($regexIndex -lt $line.Length -and $line[$regexIndex] -cmatch '[A-Za-z]') { $regexIndex++ }
+          }
+          else {
+            $lineAmbiguous = $true
+            $regexIndex = $line.Length
+          }
+          $hasCode = $true
+          [void]$structural.Append([string]::new([char]' ', $regexIndex - $index))
+          $index = $regexIndex
+          continue
+        }
       }
       if ($character -in @("'", '"', '`')) {
         $hasCode = $true
         $quote = $character
         [void]$structural.Append(' ')
         $index++
         while ($index -lt $line.Length) {
           $quotedCharacter = $line[$index]
           [void]$structural.Append(' ')
           if (($quotedCharacter -eq '\' -or $quotedCharacter -eq '`') -and $index + 1 -lt $line.Length) {
@@ -1684,72 +1793,82 @@ function Get-ArcSourceLexicalLines {
         continue
       }
 
       [void]$structural.Append($character)
       if (-not [char]::IsWhiteSpace($character)) { $hasCode = $true }
       $index++
     }
     $result.Add([pscustomobject]@{
       Raw = $line
       HasCode = $hasCode
+      HasSemanticMetadata = $semanticMarkerText -cne ''
+      SemanticText = if ($semanticMarkerText -cne '') { $semanticMarkerText } else { $line }
       StructuralText = $structural.ToString()
-      Ambiguous = $false
+      Ambiguous = $lineAmbiguous
     })
   }
   foreach ($ambiguousStart in @($blockCommentStart, $multilineStringStart) | Where-Object { $_ -ge 0 }) {
     for ($lineIndex = $ambiguousStart; $lineIndex -lt $result.Count; $lineIndex++) { $result[$lineIndex].Ambiguous = $true }
   }
   return $result.ToArray()
 }
 
 function Test-ArcCommentOnlySourceLine {
   [CmdletBinding()]
   param([AllowEmptyString()][string]$Line)
 
   $lexicalLine = @(Get-ArcSourceLexicalLines -SourceText $Line) | Select-Object -First 1
-  return $null -eq $lexicalLine -or -not $lexicalLine.HasCode
+  return $null -eq $lexicalLine -or (-not $lexicalLine.HasCode -and -not $lexicalLine.HasSemanticMetadata)
 }
 
 function Get-ArcResponsibilitySourceBlocks {
   [CmdletBinding()]
   param(
     [AllowEmptyString()][string]$SourceText,
-    [object[]]$LexicalLines = @()
+    [object[]]$LexicalLines = @(),
+    [AllowEmptyString()][string]$SourcePath = ''
   )
 
   $lines = @($SourceText -split '\r\n|\n|\r')
-  if ($LexicalLines.Count -ne $lines.Count) { $LexicalLines = @(Get-ArcSourceLexicalLines -SourceText $SourceText) }
+  if ($LexicalLines.Count -ne $lines.Count) { $LexicalLines = @(Get-ArcSourceLexicalLines -SourceText $SourceText -SourcePath $SourcePath) }
+  $semanticLines = @($LexicalLines | ForEach-Object { $_.SemanticText })
   $markerIndexes = [Collections.Generic.List[int]]::new()
   for ($index = 0; $index -lt $lines.Count; $index++) {
-    if ($lines[$index] -cmatch '^\s*@responsibility\s+RESP-[A-Z0-9]+(?:-[A-Z0-9]+)*\s*$') { $markerIndexes.Add($index) }
+    if (($LexicalLines[$index].HasCode -or $LexicalLines[$index].HasSemanticMetadata) -and $semanticLines[$index] -cmatch '^\s*@responsibility\s+RESP-[A-Z0-9]+(?:-[A-Z0-9]+)*\s*$') { $markerIndexes.Add($index) }
   }
   $blocks = [Collections.Generic.List[object]]::new()
   for ($markerOrdinal = 0; $markerOrdinal -lt $markerIndexes.Count; $markerOrdinal++) {
     $start = $markerIndexes[$markerOrdinal]
     $candidateEnd = if ($markerOrdinal + 1 -lt $markerIndexes.Count) { $markerIndexes[$markerOrdinal + 1] - 1 } else { $lines.Count - 1 }
     $metadataEnd = $start
     for ($index = $start + 1; $index -le $candidateEnd; $index++) {
-      if ($lines[$index] -cmatch '^\s*@(owner-symbol|public-symbol|owned-capability|effect|architecture-authority|co-location-policy|verification-owner)\s+\S.*$') {
+      if (
+        ($LexicalLines[$index].HasCode -or $LexicalLines[$index].HasSemanticMetadata) -and
+        (
+          $semanticLines[$index] -cmatch '^\s*@(owner-symbol|public-symbol|owned-capability|effect|architecture-authority|co-location-policy|verification-owner)\s+\S.*$' -or
+          ($LexicalLines[$index].HasSemanticMetadata -and $semanticLines[$index] -cmatch '^\s*route\s+[A-Za-z][A-Za-z0-9_.:-]*\s*->\s*[A-Za-z][A-Za-z0-9_.:-]*\s*$')
+        )
+      ) {
         $metadataEnd = $index
         continue
       }
       break
     }
 
     $bodyStart = -1
     for ($index = $metadataEnd + 1; $index -le $candidateEnd; $index++) {
-      if ($LexicalLines[$index].HasCode) { $bodyStart = $index; break }
+      if ($LexicalLines[$index].HasCode -or $LexicalLines[$index].HasSemanticMetadata) { $bodyStart = $index; break }
     }
     $end = $metadataEnd
     if ($bodyStart -ge 0) {
       $end = $bodyStart
-      if ($lines[$bodyStart] -cnotmatch '^\s*route\s+[A-Za-z][A-Za-z0-9_.:-]*\s*->\s*[A-Za-z][A-Za-z0-9_.:-]*\s*$') {
+      if ($semanticLines[$bodyStart] -cnotmatch '^\s*route\s+[A-Za-z][A-Za-z0-9_.:-]*\s*->\s*[A-Za-z][A-Za-z0-9_.:-]*\s*$') {
         $opened = $false
         $braceDepth = 0
         for ($index = $bodyStart; $index -le $candidateEnd; $index++) {
           $openCount = @([regex]::Matches($LexicalLines[$index].StructuralText, '\{')).Count
           $closeCount = @([regex]::Matches($LexicalLines[$index].StructuralText, '\}')).Count
           if ($openCount -gt 0) { $opened = $true }
           $braceDepth += $openCount - $closeCount
           if ($opened) {
             $end = $index
             if ($braceDepth -le 0) { break }
@@ -1760,25 +1879,26 @@ function Get-ArcResponsibilitySourceBlocks {
           for ($index = $bodyStart + 1; $index -le $candidateEnd; $index++) {
             if (-not $LexicalLines[$index].HasCode) { $end = $index; continue }
             $indent = $lines[$index].Length - $lines[$index].TrimStart().Length
             if ($indent -le $baseIndent) { break }
             $end = $index
           }
         }
       }
     }
     $blocks.Add([pscustomobject]@{
-      Id = ([regex]::Match($lines[$start], 'RESP-[A-Z0-9]+(?:-[A-Z0-9]+)*')).Value
+      Id = ([regex]::Match($semanticLines[$start], 'RESP-[A-Z0-9]+(?:-[A-Z0-9]+)*')).Value
       Start = $start
       End = $end
-      Text = @($lines[$start..$end]) -join "`n"
-      Lines = @($lines[$start..$end])
+      Text = @($semanticLines[$start..$end]) -join "`n"
+      Lines = @($semanticLines[$start..$end])
+      RawText = @($lines[$start..$end]) -join "`n"
     })
   }
   return $blocks.ToArray()
 }
 
 function Get-ArcPinnedSourceInventory {
   [CmdletBinding()]
   param(
     [Parameter(Mandatory)][string]$SourceRoot,
     [Parameter(Mandatory)][string]$TaskBaseSha,
@@ -1793,74 +1913,103 @@ function Get-ArcPinnedSourceInventory {
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
-    $resolvedSourceRoot = [IO.Path]::GetFullPath($SourceRoot)
-    $resolvedGitRoot = [IO.Path]::GetFullPath((Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('rev-parse', '--show-toplevel')))
+    $resolvedSourceRoot = ConvertTo-ArcComparableRootPath -Path $SourceRoot
+    $resolvedGitRoot = ConvertTo-ArcComparableRootPath -Path (Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('rev-parse', '--show-toplevel'))
     $currentHead = Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('rev-parse', 'HEAD')
     $checkoutStatus = Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('status', '--porcelain=v1', '--untracked-files=all')
     if (
       -not [string]::Equals($resolvedSourceRoot, $resolvedGitRoot, [StringComparison]::OrdinalIgnoreCase) -or
       $currentHead -cne $FinalTreeSha -or
       -not [string]::IsNullOrWhiteSpace($checkoutStatus) -or
       (Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('rev-parse', "$TaskBaseSha^{commit}")) -cne $TaskBaseSha -or
       (Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('rev-parse', "$FinalTreeSha^{commit}")) -cne $FinalTreeSha
     ) {
       $Errors.Add('responsibility-evidence-missing')
       return @()
     }
-    $nameStatusLines = @((Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('diff', '--name-status', '--find-renames', '--find-copies-harder', '--diff-filter=ACMRD', $TaskBaseSha, $FinalTreeSha, '--')) -split '\r?\n' | Where-Object { $_ -ne '' })
-    $finalTreePaths = @((Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('ls-tree', '-r', '--name-only', $FinalTreeSha)) -split '\r?\n' | Where-Object { $_ -ne '' } | ForEach-Object { ConvertTo-ArcCanonicalRepositoryPath -Path $_ })
+    [void](Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('merge-base', '--is-ancestor', $TaskBaseSha, $FinalTreeSha))
+    $nameStatusRaw = Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('diff', '--name-status', '-z', '--find-renames', '--find-copies-harder', '--diff-filter=ACMRD', $TaskBaseSha, $FinalTreeSha, '--')
+    $finalTreeRaw = Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('ls-tree', '-r', '-z', '--name-only', $FinalTreeSha)
+    if (-not $nameStatusRaw.EndsWith([string][char]0, [StringComparison]::Ordinal) -or -not $finalTreeRaw.EndsWith([string][char]0, [StringComparison]::Ordinal)) { throw 'Pinned Git NUL envelope is malformed' }
+    $nameStatusTokens = @($nameStatusRaw.Split([char]0))
+    $nameStatusTokens = @($nameStatusTokens[0..($nameStatusTokens.Count - 2)])
+    $finalTreeTokens = @($finalTreeRaw.Split([char]0))
+    $finalTreeTokens = @($finalTreeTokens[0..($finalTreeTokens.Count - 2)])
   }
   catch {
     $Errors.Add('responsibility-evidence-missing')
     return @()
   }
-  $changedPathRecords = [Collections.Generic.List[object]]::new()
-  foreach ($line in $nameStatusLines) {
-    $fields = @($line -split "`t")
-    $status = if ($fields.Count -gt 0) { $fields[0] } else { '' }
+  $nameStatusEntries = [Collections.Generic.List[object]]::new()
+  $tokenIndex = 0
+  while ($tokenIndex -lt $nameStatusTokens.Count) {
+    $status = $nameStatusTokens[$tokenIndex]
+    $tokenIndex++
     if ($status -cnotmatch '^(?:[AMDC]|R[0-9]{1,3}|C[0-9]{1,3})$') {
       $Errors.Add('responsibility-evidence-missing')
-      continue
+      return @()
     }
     $kind = $status.Substring(0, 1)
-    if (($kind -cin @('R', 'C') -and $fields.Count -ne 3) -or ($kind -cnotin @('R', 'C') -and $fields.Count -ne 2)) {
+    $pathCount = if ($kind -cin @('R', 'C')) { 2 } else { 1 }
+    if (($tokenIndex + $pathCount) -gt $nameStatusTokens.Count) {
       $Errors.Add('responsibility-evidence-missing')
-      continue
+      return @()
     }
+    $paths = @($nameStatusTokens[$tokenIndex..($tokenIndex + $pathCount - 1)])
+    $tokenIndex += $pathCount
+    $nameStatusEntries.Add([pscustomobject]@{ Status = $status; Kind = $kind; Paths = $paths })
+  }
+  $finalTreePaths = @($finalTreeTokens | ForEach-Object { ConvertTo-ArcCanonicalRepositoryPath -Path $_ })
+  if (@($finalTreePaths | Where-Object { $_ -ceq '' }).Count -gt 0) {
+    $Errors.Add('responsibility-evidence-missing')
+    return @()
+  }
+  $changedPathRecords = [Collections.Generic.List[object]]::new()
+  foreach ($entry in $nameStatusEntries) {
+    $status = $entry.Status
+    $kind = $entry.Kind
+    $fields = @($status) + @($entry.Paths)
     $rawBasePath = if ($kind -cin @('R', 'C')) { $fields[1] } elseif ($kind -ceq 'A') { '' } else { $fields[1] }
     $rawFinalPath = if ($kind -cin @('R', 'C')) { $fields[2] } elseif ($kind -ceq 'D') { '' } else { $fields[1] }
     $basePath = if ($rawBasePath -ceq '') { '' } else { ConvertTo-ArcCanonicalRepositoryPath -Path $rawBasePath }
     $finalPath = if ($rawFinalPath -ceq '') { '' } else { ConvertTo-ArcCanonicalRepositoryPath -Path $rawFinalPath }
     if (($rawBasePath -ne '' -and $basePath -ceq '') -or ($rawFinalPath -ne '' -and $finalPath -ceq '')) {
       $Errors.Add('responsibility-evidence-missing')
       continue
     }
     $path = if ($kind -ceq 'D') { $basePath } else { $finalPath }
+    $isBaseProduction = -not [string]::IsNullOrWhiteSpace($basePath) -and (Test-ArcCanonicalProductionPath -Path $basePath)
+    $isFinalProduction = -not [string]::IsNullOrWhiteSpace($finalPath) -and (Test-ArcCanonicalProductionPath -Path $finalPath)
+    $isProduction = if ($kind -ceq 'R') {
+      $isBaseProduction -or $isFinalProduction
+    }
+    elseif ($kind -ceq 'D') { $isBaseProduction }
+    else { $isFinalProduction }
     $changedPathRecords.Add([pscustomobject]@{
       Status = $kind
       RawStatus = $status
       BasePath = $basePath
       FinalPath = $finalPath
       Path = $path
       RenameMapping = if ($kind -ceq 'R') { "$basePath->$finalPath" } else { '' }
       FileKind = if ($kind -ceq 'A' -or $kind -ceq 'C') { 'new' } elseif ($kind -ceq 'D') { 'deleted' } else { 'existing' }
-      IsBaseProduction = (-not [string]::IsNullOrWhiteSpace($basePath) -and (Test-ArcCanonicalProductionPath -Path $basePath))
-      IsFinalProduction = (-not [string]::IsNullOrWhiteSpace($finalPath) -and (Test-ArcCanonicalProductionPath -Path $finalPath))
-      IsProduction = ((-not [string]::IsNullOrWhiteSpace($basePath) -and (Test-ArcCanonicalProductionPath -Path $basePath)) -or (-not [string]::IsNullOrWhiteSpace($finalPath) -and (Test-ArcCanonicalProductionPath -Path $finalPath)))
+      IsBaseProduction = $isBaseProduction
+      IsFinalProduction = $isFinalProduction
+      IsProduction = $isProduction
     })
   }
   $changedFinalPaths = @($changedPathRecords | Where-Object { $_.Status -cne 'D' -and $_.IsProduction } | ForEach-Object { $_.FinalPath })
   $deletedPaths = @($changedPathRecords | Where-Object { $_.Status -ceq 'D' -and ($_.IsProduction -or $SelectedPaths -ccontains $_.BasePath) } | ForEach-Object { $_.BasePath })
   $allChangedPaths = @($changedPathRecords | ForEach-Object { $_.Path })
   $allRequestedPaths = @($allChangedPaths + $SelectedPaths)
   if ($allChangedPaths.Count -eq 0 -or @($allRequestedPaths | Where-Object { (ConvertTo-ArcCanonicalRepositoryPath -Path $_) -ceq '' }).Count -gt 0) {
     $Errors.Add('responsibility-evidence-missing')
     return @()
   }
@@ -1891,35 +2040,38 @@ function Get-ArcPinnedSourceInventory {
       $diffText = Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('diff', '--unified=0', $TaskBaseSha, $FinalTreeSha, '--', $path)
       if ($null -ne $pathRecord -and $pathRecord.BasePath -ne '') {
         $baseSourceText = Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('show', "${TaskBaseSha}:$($pathRecord.BasePath)")
       }
     }
     catch {
       $Errors.Add('responsibility-evidence-missing')
       continue
     }
     $sourceLines = @($sourceText -split '\r\n|\n|\r')
-    $sourceLexicalLines = @(Get-ArcSourceLexicalLines -SourceText $sourceText)
+    $sourceLexicalLines = @(Get-ArcSourceLexicalLines -SourceText $sourceText -SourcePath $path)
+    $sourceSemanticLines = @($sourceLexicalLines | ForEach-Object { $_.SemanticText })
     if (@($sourceLexicalLines | Where-Object { $_.Ambiguous }).Count -gt 0) { $Errors.Add('responsibility-evidence-missing') }
-    $responsibilityBlocks = @(Get-ArcResponsibilitySourceBlocks -SourceText $sourceText -LexicalLines $sourceLexicalLines)
+    $responsibilityBlocks = @(Get-ArcResponsibilitySourceBlocks -SourceText $sourceText -LexicalLines $sourceLexicalLines -SourcePath $path)
     $coveredLineIndexes = [Collections.Generic.HashSet[int]]::new()
     foreach ($block in $responsibilityBlocks) {
       for ($coveredIndex = $block.Start; $coveredIndex -le $block.End; $coveredIndex++) { [void]$coveredLineIndexes.Add($coveredIndex) }
     }
     for ($lineIndex = 0; $lineIndex -lt $sourceLines.Count; $lineIndex++) {
-      if (-not $coveredLineIndexes.Contains($lineIndex) -and $sourceLexicalLines[$lineIndex].HasCode) {
+      if (-not $coveredLineIndexes.Contains($lineIndex) -and ($sourceLexicalLines[$lineIndex].HasCode -or $sourceLexicalLines[$lineIndex].HasSemanticMetadata)) {
         $Errors.Add('responsibility-evidence-missing')
       }
     }
 
     $current = $null
-    foreach ($line in $sourceLines) {
+    for ($lineIndex = 0; $lineIndex -lt $sourceLines.Count; $lineIndex++) {
+      $line = $sourceSemanticLines[$lineIndex]
+      if (-not $sourceLexicalLines[$lineIndex].HasCode -and -not $sourceLexicalLines[$lineIndex].HasSemanticMetadata) { continue }
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
@@ -1951,27 +2103,29 @@ function Get-ArcPinnedSourceInventory {
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
-    $allRouteCount = @([regex]::Matches($sourceText, '(?m)^\s*route\s+[A-Za-z][A-Za-z0-9_.:-]*\s*->\s*[A-Za-z][A-Za-z0-9_.:-]*\s*$')).Count
+    $allRouteCount = @(for ($lineIndex = 0; $lineIndex -lt $sourceLines.Count; $lineIndex++) {
+      if (($sourceLexicalLines[$lineIndex].HasCode -or $sourceLexicalLines[$lineIndex].HasSemanticMetadata) -and $sourceSemanticLines[$lineIndex] -cmatch '^\s*route\s+[A-Za-z][A-Za-z0-9_.:-]*\s*->\s*[A-Za-z][A-Za-z0-9_.:-]*\s*$') { $sourceSemanticLines[$lineIndex] }
+    }).Count
     $ownedRouteCount = @($inventory | Where-Object { $_.Path -ceq $path } | ForEach-Object { $_.RouteSymbols.Count } | Measure-Object -Sum).Sum
     if ($null -eq $ownedRouteCount) { $ownedRouteCount = 0 }
     if ($allRouteCount -ne $ownedRouteCount) { $Errors.Add('responsibility-evidence-missing') }
     foreach ($owner in @($inventory | Where-Object { $_.Path -ceq $path })) {
       if ($null -ne $pathRecord -and $pathRecord.Status -cin @('M', 'R') -and $baseSourceText -ne '') {
-        $baseOwnerBlocks = @(Get-ArcResponsibilitySourceBlocks -SourceText $baseSourceText | Where-Object { $_.Id -ceq $owner.Id })
+        $baseOwnerBlocks = @(Get-ArcResponsibilitySourceBlocks -SourceText $baseSourceText -SourcePath $pathRecord.BasePath | Where-Object { $_.Id -ceq $owner.Id })
         $finalOwnerBlocks = @($responsibilityBlocks | Where-Object { $_.Id -ceq $owner.Id })
         $owner.IsChanged = -not (
           $baseOwnerBlocks.Count -eq 1 -and
           $finalOwnerBlocks.Count -eq 1 -and
           $baseOwnerBlocks[0].Text.Trim() -ceq $finalOwnerBlocks[0].Text.Trim()
         )
       }
       $requiresRouteEvidence = $owner.Effects -ccontains 'route registration'
       if ($owner.OwnerSymbols.Count -eq 0 -or $owner.Symbols.Count -eq 0 -or $owner.Capabilities.Count -eq 0 -or $owner.ArchitectureAuthorities.Count -eq 0 -or $owner.CoLocationPolicies.Count -eq 0 -or $owner.VerificationOwners.Count -eq 0 -or ($requiresRouteEvidence -and ($owner.RouteSymbols.Count -eq 0 -or $owner.Providers.Count -eq 0 -or @($owner.Symbols | Where-Object { $owner.RouteSymbols -cnotcontains $_ }).Count -gt 0))) {
         $Errors.Add('responsibility-evidence-missing')
@@ -1980,23 +2134,25 @@ function Get-ArcPinnedSourceInventory {
   }
 
   # A responsibility block removed from an M/R production file is deletion,
   # even though the file itself survives. Compare immutable pinned contents and
   # feed only the removed owners through the same deletion reconciliation used
   # for a whole-file D change.
   foreach ($record in @($changedPathRecords | Where-Object { $_.Status -cin @('M', 'R') -and ($_.IsProduction -or $SelectedPaths -ccontains $_.FinalPath) -and $_.BasePath -ne '' -and $_.FinalPath -ne '' })) {
     try {
       $baseText = Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('show', "${TaskBaseSha}:$($record.BasePath)")
       $finalText = Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('show', "${FinalTreeSha}:$($record.FinalPath)")
-      $removedOwnerIds = @([regex]::Matches($baseText, '(?m)^\s*@responsibility\s+(?<id>RESP-[A-Z0-9]+(?:-[A-Z0-9]+)*)\s*$') | ForEach-Object { $_.Groups['id'].Value } | Where-Object {
+      $baseOwnerIds = @(Get-ArcResponsibilitySourceBlocks -SourceText $baseText -SourcePath $record.BasePath | ForEach-Object { $_.Id })
+      $finalOwnerIds = @(Get-ArcResponsibilitySourceBlocks -SourceText $finalText -SourcePath $record.FinalPath | ForEach-Object { $_.Id })
+      $removedOwnerIds = @($baseOwnerIds | Where-Object {
         $ownerId = $_
-        @([regex]::Matches($finalText, '(?m)^\s*@responsibility\s+(?<id>RESP-[A-Z0-9]+(?:-[A-Z0-9]+)*)\s*$') | ForEach-Object { $_.Groups['id'].Value }) -cnotcontains $ownerId
+        $finalOwnerIds -cnotcontains $ownerId
       })
       if ($removedOwnerIds.Count -gt 0) {
         $removalDiff = Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('diff', '--unified=0', $TaskBaseSha, $FinalTreeSha, '--', $record.BasePath, $record.FinalPath)
         foreach ($owner in @(Test-ArcDeletedSourceEvidence -Path $record.BasePath -SourceText $baseText -DiffText $removalDiff -OwnerIds $removedOwnerIds -Errors $Errors)) {
           $owner.BasePath = $record.BasePath
           $owner.FinalPath = $record.FinalPath
           $owner.RenameMapping = $record.RenameMapping
           $deletedInventory.Add($owner)
         }
       }
@@ -2043,20 +2199,29 @@ function Test-ArcPinnedVerificationOwnershipEvidence {
     $scenario -cnotmatch '^[A-Za-z][A-Za-z0-9_.:-]*$'
   ) {
     $Errors.Add('verification-production-binding-missing')
     return $false
   }
   try { $evidenceText = Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('show', "${FinalTreeSha}:$path") }
   catch {
     $Errors.Add('verification-production-binding-missing')
     return $false
   }
+  $evidenceLines = @($evidenceText -split '\r\n|\n|\r')
+  $evidenceLexicalLines = @(Get-ArcSourceLexicalLines -SourceText $evidenceText -SourcePath $path)
+  if (@($evidenceLexicalLines | Where-Object { $_.Ambiguous }).Count -gt 0) {
+    $Errors.Add('verification-production-binding-missing')
+    return $false
+  }
+  $evidenceText = @(for ($lineIndex = 0; $lineIndex -lt $evidenceLines.Count; $lineIndex++) {
+    if ($evidenceLexicalLines[$lineIndex].HasCode -or $evidenceLexicalLines[$lineIndex].HasSemanticMetadata) { $evidenceLexicalLines[$lineIndex].SemanticText }
+  }) -join "`n"
 
   $scenarioBlocks = @([regex]::Matches($evidenceText, '(?ms)^\s*@verification-scenario\s+(?<scenario>[A-Za-z][A-Za-z0-9_.:-]*)\s*$.*?(?=^\s*@verification-scenario\s+|\z)'))
   $matchingBlocks = @($scenarioBlocks | Where-Object { $_.Groups['scenario'].Value -ceq $scenario })
   if ($matchingBlocks.Count -ne 1) {
     $Errors.Add('verification-production-binding-missing')
     return $false
   }
   $block = $matchingBlocks[0].Value
   $requiredMarkers = [ordered]@{
     'verification-owner' = $VerificationRow['Verification Owner ID']
@@ -2104,21 +2269,28 @@ function Test-ArcPinnedVerificationOwnershipEvidence {
     ($productionOwner.OwnerSymbols -cnotcontains $plannedBinding.Groups['symbol'].Value -and $productionOwner.Symbols -cnotcontains $plannedBinding.Groups['symbol'].Value) -or
     $productionOwner.Capabilities -cnotcontains $VerificationRow['Capability ID'] -or
     $productionOwner.VerificationOwners -cnotcontains $VerificationRow['Verification Owner ID']
   ) {
     $Errors.Add('verification-production-binding-missing')
     return $false
   }
 
   if ($VerificationRow['Evidence Kind'] -ceq 'production-composition') {
     $routeMatches = @([regex]::Matches($block, '(?m)^\s*@production-route\s+(?<symbol>[A-Za-z][A-Za-z0-9_.:-]*)\s*->\s*(?<provider>[A-Za-z][A-Za-z0-9_.:-]*)\s*$'))
-    try { $productionText = Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('show', "${FinalTreeSha}:$($productionOwner.Path)") }
+    try {
+      $rawProductionText = Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('show', "${FinalTreeSha}:$($productionOwner.Path)")
+      $productionLexicalLines = @(Get-ArcSourceLexicalLines -SourceText $rawProductionText -SourcePath $productionOwner.Path)
+      if (@($productionLexicalLines | Where-Object { $_.Ambiguous }).Count -gt 0) { $productionText = '' }
+      else {
+        $productionText = @($productionLexicalLines | Where-Object { $_.HasCode -or $_.HasSemanticMetadata } | ForEach-Object { $_.SemanticText }) -join "`n"
+      }
+    }
     catch { $productionText = '' }
     $exactProductionRouteCount = if ($routeMatches.Count -eq 1) {
       @([regex]::Matches($productionText, '(?m)^\s*route\s+' + [regex]::Escape($routeMatches[0].Groups['symbol'].Value) + '\s*->\s*' + [regex]::Escape($routeMatches[0].Groups['provider'].Value) + '\s*$')).Count
     } else { 0 }
     if ($routeMatches.Count -ne 1 -or $exactProductionRouteCount -ne 1 -or $productionOwner.RouteSymbols -cnotcontains $routeMatches[0].Groups['symbol'].Value -or $productionOwner.Providers -cnotcontains $routeMatches[0].Groups['provider'].Value) {
       $Errors.Add('verification-production-binding-missing')
       return $false
     }
   }
   return $true
@@ -2221,20 +2393,109 @@ function Test-ResponsibilityReview {
   $expectedTaskUnit = if ($planSelector['Adapter Kind'] -ceq 'migration-unit') { $planSelector['External ID'] } else { $reviewScope['Work Item ID'] }
   if ($reviewProvenance['Task / Unit'] -cne $expectedTaskUnit -or $reviewProvenance['Task-base SHA'] -cne $TaskBaseSha -or $reviewProvenance['Final-tree SHA'] -cne $FinalTreeSha -or $reviewProvenance['Task-base SHA'] -cnotmatch '^[0-9a-f]{40}$' -or $reviewProvenance['Final-tree SHA'] -cnotmatch '^[0-9a-f]{40}$' -or $reviewProvenance['Source Artifact'] -cne 'implementation-report.md') {
     $errors.Add('responsibility-evidence-missing')
   }
   if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }
   $implementationProvenanceEnvelope = Get-ArcImplementationReviewProvenance -ImplementationText $ImplementationText -Errors $errors
   if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }
   if ($null -eq $implementationProvenanceEnvelope -or $implementationProvenanceEnvelope.TaskUnit -cne $expectedTaskUnit -or $implementationProvenanceEnvelope.TaskBaseSha -cne $TaskBaseSha -or $implementationProvenanceEnvelope.FinalTreeSha -cne $FinalTreeSha) {
     $errors.Add('responsibility-evidence-missing')
   }
+  $reviewHygieneColumns = @('Task / Unit', 'Scope Evidence', 'Formatter Evidence', 'Unrelated Diff', 'Severity', 'Task-base SHA', 'Final-tree SHA')
+  $reviewHygieneTable = @(Get-ArcStrictMarkdownTable -Text $ReviewText -Heading 'Change Hygiene' -Columns $reviewHygieneColumns -Errors $errors)
+  $majorFindingColumns = @('File:line', 'Issue', 'Proposed fix')
+  $majorFindingTable = @(Get-ArcStrictMarkdownTable -Text $ReviewText -Heading 'Major' -Columns $majorFindingColumns -Errors $errors)
+  if ($errors.Count -ne 0 -or $reviewHygieneTable.Count -lt 3 -or $majorFindingTable.Count -lt 2) {
+    if ($reviewHygieneTable.Count -lt 3 -or $majorFindingTable.Count -lt 2) { $errors.Add('change-hygiene-review-mismatch') }
+    return @($errors | Select-Object -Unique)
+  }
+  $reviewHygieneRows = @($reviewHygieneTable | Select-Object -Skip 2)
+  $majorFindingRows = @($majorFindingTable | Select-Object -Skip 2)
+  if ($majorFindingRows.Count -eq 1 -and ([string]$majorFindingRows[0][0]) -ceq 'none' -and ([string]$majorFindingRows[0][1]) -ceq 'none' -and ([string]$majorFindingRows[0][2]) -ceq 'none') {
+    $majorFindingRows = @()
+  }
+  elseif (@($majorFindingRows | Where-Object { @($_ | Where-Object { [string]$_ -ceq 'none' }).Count -gt 0 }).Count -gt 0) {
+    $errors.Add('change-hygiene-review-mismatch')
+  }
+  foreach ($reviewHygieneRow in $reviewHygieneRows) {
+    $scopeMatch = [regex]::Match(([string]$reviewHygieneRow[1]).Trim(), '^(?<path>.+)#(?<region>[A-Za-z_][A-Za-z0-9_.:-]*(?:, [A-Za-z_][A-Za-z0-9_.:-]*)*)$')
+    $canonicalScopePath = if ($scopeMatch.Success) { ConvertTo-ArcCanonicalRepositoryPath -Path $scopeMatch.Groups['path'].Value } else { '' }
+    if ($canonicalScopePath -ceq '') { $errors.Add('change-hygiene-review-mismatch') }
+    else { $reviewHygieneRow[1] = "$canonicalScopePath#$($scopeMatch.Groups['region'].Value)" }
+  }
+  $confirmedHygieneRows = [Collections.Generic.List[object]]::new()
+  foreach ($implementationHygieneRow in $implementationProvenanceEnvelope.Rows) {
+    $scopeEvidence = "$([string]$implementationHygieneRow[1])#$([string]$implementationHygieneRow[3])"
+    $unrelatedDiff = ([string]$implementationHygieneRow[5]).Trim()
+    $expectedSeverity = if ($unrelatedDiff -ceq 'none') { 'none' } else { 'Major' }
+    $matchingReviewHygieneRows = @($reviewHygieneRows | Where-Object {
+      [string]$_[0] -ceq $implementationProvenanceEnvelope.TaskUnit -and
+      [string]$_[1] -ceq $scopeEvidence -and
+      [string]$_[2] -ceq ([string]$implementationHygieneRow[4]).Trim() -and
+      [string]$_[3] -ceq $unrelatedDiff -and
+      [string]$_[4] -ceq $expectedSeverity -and
+      [string]$_[5] -ceq $TaskBaseSha -and
+      [string]$_[6] -ceq $FinalTreeSha
+    })
+    if ($matchingReviewHygieneRows.Count -ne 1) {
+      $errors.Add('change-hygiene-review-mismatch')
+      continue
+    }
+    if ($unrelatedDiff -cne 'none') {
+      $confirmedHygieneRows.Add([pscustomobject]@{
+        ScopeEvidence = $scopeEvidence
+        FindingId = $unrelatedDiff.Substring('confirmed:'.Length)
+      })
+    }
+  }
+  foreach ($reviewHygieneRow in $reviewHygieneRows) {
+    $matchingImplementationHygieneRows = @($implementationProvenanceEnvelope.Rows | Where-Object {
+      $candidateScopeEvidence = "$([string]$_[1])#$([string]$_[3])"
+      $candidateUnrelatedDiff = ([string]$_[5]).Trim()
+      $candidateSeverity = if ($candidateUnrelatedDiff -ceq 'none') { 'none' } else { 'Major' }
+      [string]$reviewHygieneRow[0] -ceq $implementationProvenanceEnvelope.TaskUnit -and
+      [string]$reviewHygieneRow[1] -ceq $candidateScopeEvidence -and
+      [string]$reviewHygieneRow[2] -ceq ([string]$_[4]).Trim() -and
+      [string]$reviewHygieneRow[3] -ceq $candidateUnrelatedDiff -and
+      [string]$reviewHygieneRow[4] -ceq $candidateSeverity -and
+      [string]$reviewHygieneRow[5] -ceq $TaskBaseSha -and
+      [string]$reviewHygieneRow[6] -ceq $FinalTreeSha
+    })
+    if ($matchingImplementationHygieneRows.Count -ne 1) { $errors.Add('change-hygiene-review-mismatch') }
+  }
+  foreach ($confirmedHygieneRow in $confirmedHygieneRows) {
+    $matchingMajorFindings = @($majorFindingRows | Where-Object {
+      [string]$_[0] -ceq $confirmedHygieneRow.ScopeEvidence -and
+      [string]$_[1] -ceq "$($confirmedHygieneRow.FindingId): confirmed unrelated diff" -and
+      -not [string]::IsNullOrWhiteSpace([string]$_[2]) -and
+      [string]$_[2] -cne 'none'
+    })
+    if ($matchingMajorFindings.Count -ne 1) { $errors.Add('change-hygiene-review-mismatch') }
+  }
+  foreach ($majorFindingRow in $majorFindingRows) {
+    $matchingConfirmedRows = @($confirmedHygieneRows | Where-Object {
+      $_.ScopeEvidence -ceq [string]$majorFindingRow[0] -and
+      "$($_.FindingId): confirmed unrelated diff" -ceq [string]$majorFindingRow[1]
+    })
+    if ($matchingConfirmedRows.Count -ne 1) { $errors.Add('change-hygiene-review-mismatch') }
+  }
+  $changeHygieneVerdictMatches = @([regex]::Matches($visibleReviewText, '(?im)^[ \t]*-[ \t]*Change Hygiene Verdict:[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$'))
+  $majorCountMatches = @([regex]::Matches($visibleReviewText, '(?im)^[ \t]*-[ \t]*(?:\*\*)?Major count:(?:\*\*)?[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$'))
+  $expectedHygieneVerdict = if ($confirmedHygieneRows.Count -eq 0) { 'PASS' } else { 'BLOCKED' }
+  if (
+    $changeHygieneVerdictMatches.Count -ne 1 -or
+    $changeHygieneVerdictMatches[0].Groups['value'].Value.Trim() -cne $expectedHygieneVerdict -or
+    $majorCountMatches.Count -ne 1 -or
+    $majorCountMatches[0].Groups['value'].Value.Trim() -cne [string]$confirmedHygieneRows.Count -or
+    $majorFindingRows.Count -ne $confirmedHygieneRows.Count
+  ) { $errors.Add('change-hygiene-review-mismatch') }
+  if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }
   $reviewHandoff = & $rowFromTable $reviewHandoffTable $handoffColumns
   $expectedSourceDiff = "source-diff:$TaskBaseSha..$FinalTreeSha#$($reviewScope['Work Item ID'])"
   $derivedHandoff = if ($reviewHandoff['Tree Conformance'] -ceq 'PASS' -and $reviewHandoff['Responsibility Conformance'] -ceq 'PASS' -and $reviewHandoff['Verification Ownership'] -ceq 'PASS') { 'PASS' } else { 'BLOCKED' }
   if ($reviewHandoff['Responsibility Contract Version'] -cne '1') { $errors.Add('responsibility-contract-version-invalid') }
   if (@('Tree Conformance', 'Responsibility Conformance', 'Verification Ownership') | Where-Object { $reviewHandoff[$_] -cnotin @('PASS', 'BLOCKED') }) { $errors.Add('responsibility-evidence-missing') }
   if ($reviewHandoff['Architecture Conformance State'] -cne $derivedHandoff) { $errors.Add('responsibility-waiver-forbidden') }
   if ($reviewHandoff['Evidence References'] -cne $expectedSourceDiff) { $errors.Add('responsibility-evidence-missing') }
   if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }
   $implementationSelectedHeadingCount = @(Get-ArcMarkdownH2HeadingMatches -Text $ImplementationText -Heading 'Selected Migration Unit').Count
   $reviewSelectedHeadingCount = @(Get-ArcMarkdownH2HeadingMatches -Text $ReviewText -Heading 'Selected Migration Unit').Count
@@ -2350,22 +2611,21 @@ function Test-ResponsibilityReview {
     else { '' }
     if ($expectedCheckpoint -ne '' -and [string]$matchingHygieneRows[0][6] -cne $expectedCheckpoint) {
       $errors.Add('responsibility-evidence-missing')
     }
   }
   foreach ($row in $implementationProvenance.Rows) {
     $path = $row[1].Trim()
     $fileKind = $row[2].Trim()
     $matchingChanges = @($changedPathRecords | Where-Object { $_.Path -ceq $path -and $_.FileKind -ceq $fileKind })
     if (
-      $path -cnotmatch '^(?:[A-Za-z0-9_.-]+/)*[A-Za-z0-9_.-]+$' -or
-      $path -match '^(?:/|[A-Za-z]:|.*(?:^|/)\.\.(?:/|$))' -or
+      (ConvertTo-ArcCanonicalRepositoryPath -Path $path) -cne $path -or
       $fileKind -cnotin @('new', 'existing', 'deleted') -or
       $matchingChanges.Count -ne 1
     ) {
       $errors.Add('responsibility-evidence-missing')
     }
   }
   if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }
   if (($inventory.Count + $deletedInventory.Count) -eq 0) { $errors.Add('responsibility-evidence-missing'); return @($errors | Select-Object -Unique) }
 
   $plannedById = & $toMap $plannedResponsibilities 'Responsibility ID' 'responsibility-owner-extra'
@@ -2532,20 +2792,26 @@ function Test-ResponsibilityReview {
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
+  if (
+    $reviewHandoff['Tree Conformance'] -cne $treeVerdict -or
+    $reviewHandoff['Responsibility Conformance'] -cne $responsibilityVerdict -or
+    $reviewHandoff['Verification Ownership'] -cne $verificationVerdict -or
+    $reviewHandoff['Architecture Conformance State'] -cne $architectureVerdict
+  ) { $errors.Add('responsibility-waiver-forbidden') }
   if ($derivedArchitecture -ceq 'BLOCKED' -or $overallVerdict -cne 'Approve' -or $criticalCount -ne 0) { $errors.Add('responsibility-waiver-forbidden') }
   return @($errors | Select-Object -Unique)
 }
 
 function Test-ResponsibilityHandoff {
   [CmdletBinding()]
   param([string]$SourceText, [string]$TargetText, [string]$ContractText, [string]$ApprovedPlanText)
 
   $errors = [Collections.Generic.List[string]]::new()
   foreach ($error in @(Test-ArcResponsibilityStageVersion $ContractText 'HANDOFF')) { $errors.Add($error) }
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/scope-artifacts.validation.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/scope-artifacts.validation.ps1
index 0b0af17..0a20905 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/scope-artifacts.validation.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/scope-artifacts.validation.ps1
@@ -1,11 +1,14 @@
 function Test-ScopeArtifacts([string]$Root, [string]$ContractText) {
+  if ($null -eq (Get-Command Get-ArcVisibleMarkdownText -CommandType Function -ErrorAction SilentlyContinue)) {
+    . (Join-Path $PSScriptRoot 'responsibility-conformance.validation.ps1')
+  }
   $contractPath = Join-Path $Root 'contracts/migration-scope-orchestration.md'
   if (-not (Test-Path -LiteralPath $contractPath -PathType Leaf)) {
     $errors.Add('Missing migration scope orchestration contract resource')
     return
   }
   if ([string]::IsNullOrWhiteSpace($ContractText)) {
     $errors.Add('Migration scope orchestration contract must not be empty')
     return
   }
 
@@ -25,20 +28,21 @@ function Test-ScopeArtifacts([string]$Root, [string]$ContractText) {
       if ($line -notmatch '^(?<key>[a-z_]+):[ \t]*(?<value>.*)$') { & $addError "$Label has invalid front matter line: $line"; continue }
       $key = $Matches['key']; $value = $Matches['value'].Trim()
       if ($result.Contains($key)) { & $addError "$Label duplicate front matter field: $key"; continue }
       if ([string]::IsNullOrWhiteSpace($value)) { & $addError "$Label has blank front matter field: $key"; continue }
       $result[$key] = $value
     }
     return $result
   }
   $getSection = {
     param([string]$Text, [string]$Section)
+    $Text = Get-ArcVisibleMarkdownText -Text $Text
     $escaped = [regex]::Escape($Section)
     $matches = [regex]::Matches($Text, "(?m)^## $escaped[ \t]*$")
     if ($matches.Count -eq 0) { return $null }
     if ($matches.Count -ne 1) { & $addError "$script:scopeArtifactLabel duplicate required section: $Section"; return $null }
     $start = $matches[0].Index + $matches[0].Length
     $next = [regex]::Match($Text.Substring($start), '(?m)^## ')
     $length = if ($next.Success) { $next.Index } else { $Text.Length - $start }
     return $Text.Substring($start, $length)
   }
   $getRows = {
@@ -59,28 +63,29 @@ function Test-ScopeArtifacts([string]$Root, [string]$ContractText) {
       for ($cellIndex = 0; $cellIndex -lt $cells.Count; $cellIndex++) { if ([string]::IsNullOrWhiteSpace($cells[$cellIndex])) { & $addError "$script:scopeArtifactLabel $Section row $($rows.Count + 1) has blank cell: $($Columns[$cellIndex])" } }
       $rows.Add([pscustomobject]@{ Cells = $cells })
     }
     if ($rows.Count -eq 0) { & $addError "$script:scopeArtifactLabel $Section must contain at least one row" }
     return @($rows)
   }
   $validateArtifact = {
     param([string]$Text, [string]$Label, [string]$ArtifactType, [string[]]$Fields, [string[]]$Sections)
     $script:scopeArtifactLabel = $Label; $frontMatter = & $getFrontMatter $Text $Label
     if ($null -eq $frontMatter) { return $null }
+    $visibleText = Get-ArcVisibleMarkdownText -Text $Text
     foreach ($field in $Fields) { if (-not $frontMatter.Contains($field)) { & $addError "$Label missing front matter field: $field" } }
     if ((@($frontMatter.Keys) -join '|') -cne ($Fields -join '|')) { & $addError "$Label front matter fields must be exact" }
     if ($frontMatter.Contains('artifact_type') -and $frontMatter['artifact_type'] -cne $ArtifactType) { & $addError "$Label artifact_type must be $ArtifactType" }
     foreach ($section in $Sections) {
       [void](& $getSection $Text $section)
-      if (@([regex]::Matches($Text, "(?m)^## $([regex]::Escape($section))[ \t]*$")).Count -eq 0) { & $addError "$Label missing required section: $section" }
+      if (@([regex]::Matches($visibleText, "(?m)^## $([regex]::Escape($section))[ \t]*$")).Count -eq 0) { & $addError "$Label missing required section: $section" }
     }
-    $actualSections = @([regex]::Matches($Text, '(?m)^## (?<name>.+?)[ \t]*$') | ForEach-Object { $_.Groups['name'].Value.Trim() })
+    $actualSections = @([regex]::Matches($visibleText, '(?m)^## (?<name>.+?)[ \t]*$') | ForEach-Object { $_.Groups['name'].Value.Trim() })
     if (($actualSections -join '|') -cne ($Sections -join '|')) { & $addError "$Label sections must be exact" }
     return $frontMatter
   }
 
   $specPath = Join-Path $Root 'templates/migration/master-spec.md'; $planPath = Join-Path $Root 'templates/migration/master-plan.md'
   if (-not (Test-Path -LiteralPath $specPath -PathType Leaf)) { & $addError 'Missing master spec template' }
   if (-not (Test-Path -LiteralPath $planPath -PathType Leaf)) { & $addError 'Missing master plan template' }
   if (-not (Test-Path -LiteralPath $specPath -PathType Leaf) -or -not (Test-Path -LiteralPath $planPath -PathType Leaf)) { return }
   $specText = (Get-Content -Raw -Encoding utf8 $specPath).Replace("`r`n", "`n").Replace("`r", "`n")
   $planText = (Get-Content -Raw -Encoding utf8 $planPath).Replace("`r`n", "`n").Replace("`r", "`n")
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/scope-engine.validation.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/scope-engine.validation.ps1
index 3edc0c8..fbe9291 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/scope-engine.validation.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/scope-engine.validation.ps1
@@ -278,20 +278,24 @@ function Test-ScopeEngine([string]$Root, [string]$ContractText) {
         [string]$_.artifact_reference -ceq $Reference
       })
       if ($terminalArtifacts.Count -ne 1) { return $false }
       $terminalArtifact = $terminalArtifacts[0]
       if ($null -eq $terminalArtifact.PSObject.Properties['responsibility_handoff']) { return $false }
       $handoff = $terminalArtifact.responsibility_handoff
       $taskProvenance = if ($null -ne $terminalArtifact.PSObject.Properties['task_provenance']) {
         $terminalArtifact.task_provenance
       }
       else { $null }
+      $expectedTaskUnit = if ([string]$Item.adapter_kind -ceq 'migration-unit') {
+        [string]$Item.external_id
+      }
+      else { [string]$Item.work_item_id }
       $expectedTaskEvidence = if ($null -ne $taskProvenance) {
         "source-diff:$([string]$taskProvenance.task_base_sha)..$([string]$taskProvenance.final_tree_sha)#$([string]$Item.work_item_id)"
       }
       else { '' }
       $derivedArchitecture = if (
         [string]$handoff.tree_conformance -ceq 'PASS' -and
         [string]$handoff.responsibility_conformance -ceq 'PASS' -and
         [string]$handoff.verification_ownership -ceq 'PASS'
       ) { 'PASS' } else { 'BLOCKED' }
       $expectedSteps = if ([string]$Item.mode_constraint -ceq 'incremental/preserve-existing') {
@@ -311,21 +315,22 @@ function Test-ScopeEngine([string]$Root, [string]$ContractText) {
         [string]$terminalArtifact.result -cne 'complete' -or
         [string]$terminalArtifact.run_id -cne [string]$context.run_id -or
         [string]$terminalArtifact.master_spec_ref -cne [string]$context.master_spec_ref -or
         [string]$terminalArtifact.master_spec_id -cne [string]$context.master_spec_id -or
         [int]$terminalArtifact.master_spec_revision -ne [int]$context.latest_spec_revision -or
         [string]$terminalArtifact.master_plan_ref -cne [string]$context.master_plan_ref -or
         [string]$terminalArtifact.master_plan_id -cne [string]$context.master_plan_id -or
         [int]$terminalArtifact.master_plan_revision -ne [int]$context.current_plan_revision -or
         [string]$terminalArtifact.mode_constraint -cne [string]$Item.mode_constraint -or
         $null -eq $taskProvenance -or
-        [string]$taskProvenance.task_unit -cne [string]$Item.work_item_id -or
+        [string]::IsNullOrWhiteSpace($expectedTaskUnit) -or
+        [string]$taskProvenance.task_unit -cne $expectedTaskUnit -or
         [string]$taskProvenance.task_base_sha -cnotmatch '^[0-9a-f]{40}$' -or
         [string]$taskProvenance.final_tree_sha -cnotmatch '^[0-9a-f]{40}$' -or
         [string]$taskProvenance.source_artifact_reference -cne 'implementation-report.md' -or
         [string]$taskProvenance.evidence_reference -cne $expectedTaskEvidence -or
         [int]$handoff.responsibility_contract_version -ne 1 -or
         [string]$handoff.tree_conformance -cne 'PASS' -or
         [string]$handoff.responsibility_conformance -cne 'PASS' -or
         [string]$handoff.verification_ownership -cne 'PASS' -or
         [string]$handoff.architecture_state -cne $derivedArchitecture -or
         $derivedArchitecture -cne 'PASS' -or
@@ -841,20 +846,24 @@ function Test-ScopeEngine([string]$Root, [string]$ContractText) {
         if (-not (& $testTerminalResponsibilityAuthority $item ([string]$item.terminal_evidence))) {
           return [pscustomobject]@{ result = 'scope-not-complete'; reason = 'structural-assurance-blocked'; scope_status = 'scope-blocked' }
         }
 
         $terminalArtifact = $terminalArtifacts[0]
         $handoff = $terminalArtifact.responsibility_handoff
         $taskProvenance = if ($null -ne $terminalArtifact.PSObject.Properties['task_provenance']) {
           $terminalArtifact.task_provenance
         }
         else { $null }
+        $expectedTaskUnit = if ([string]$item.adapter_kind -ceq 'migration-unit') {
+          [string]$item.external_id
+        }
+        else { [string]$item.work_item_id }
         $expectedTaskEvidence = if ($null -ne $taskProvenance) {
           "source-diff:$([string]$taskProvenance.task_base_sha)..$([string]$taskProvenance.final_tree_sha)#$([string]$item.work_item_id)"
         }
         else { '' }
         $derivedArchitecture = if (
           [string]$handoff.tree_conformance -ceq 'PASS' -and
           [string]$handoff.responsibility_conformance -ceq 'PASS' -and
           [string]$handoff.verification_ownership -ceq 'PASS'
         ) { 'PASS' } else { 'BLOCKED' }
         $modeConstraint = [string]$item.mode_constraint
@@ -868,21 +877,22 @@ function Test-ScopeEngine([string]$Root, [string]$ContractText) {
         $responsibilityChainReferences = @($terminalArtifact.responsibility_chain_references)
         if (
           $null -eq $handoff -or
           [int]$handoff.responsibility_contract_version -ne 1 -or
           [string]$handoff.tree_conformance -cne 'PASS' -or
           [string]$handoff.responsibility_conformance -cne 'PASS' -or
           [string]$handoff.verification_ownership -cne 'PASS' -or
           [string]$handoff.architecture_state -cne $derivedArchitecture -or
           $derivedArchitecture -cne 'PASS' -or
           $null -eq $taskProvenance -or
-          [string]$taskProvenance.task_unit -cne [string]$item.work_item_id -or
+          [string]::IsNullOrWhiteSpace($expectedTaskUnit) -or
+          [string]$taskProvenance.task_unit -cne $expectedTaskUnit -or
           [string]$taskProvenance.task_base_sha -cnotmatch '^[0-9a-f]{40}$' -or
           [string]$taskProvenance.final_tree_sha -cnotmatch '^[0-9a-f]{40}$' -or
           [string]$taskProvenance.source_artifact_reference -cne 'implementation-report.md' -or
           [string]$taskProvenance.evidence_reference -cne $expectedTaskEvidence -or
           $expectedResponsibilitySteps.Count -eq 0 -or
           $responsibilityChainReferences.Count -ne $expectedResponsibilitySteps.Count -or
           @($responsibilityChainReferences | Group-Object | Where-Object Count -ne 1).Count -gt 0 -or
           [string]$handoff.evidence_reference -cne [string]$responsibilityChainReferences[-1] -or
           $tree -cne [string]$handoff.tree_conformance -or
           $responsibility -cne [string]$handoff.responsibility_conformance -or
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/structural-gate.validation.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/structural-gate.validation.ps1
index 34722be..de9af46 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/structural-gate.validation.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/structural-gate.validation.ps1
@@ -33,30 +33,31 @@ function Test-StructuralGate([string]$Root, [string]$ContractText) {
   $reportPath = Join-Path $fixtureRoot '10-implementation-report.md'
   if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) {
     $errors.Add('Structural gate missing implementation report fixture')
     return
   }
   $report = ((Get-Content -Raw -Encoding utf8 -LiteralPath $reportPath) -replace "`r`n", "`n") -replace "`r", "`n"
   $normalizedContractText = ($ContractText -replace "`r`n", "`n") -replace "`r", "`n"
 
   $getSection = {
     param([string]$Text, [string]$Heading)
-    $matches = @([regex]::Matches($Text, '(?m)^##\s+' + [regex]::Escape($Heading) + '[ \t]*$'))
+    $visibleText = Get-ArcVisibleMarkdownText -Text $Text
+    $matches = @([regex]::Matches($visibleText, '(?m)^##\s+' + [regex]::Escape($Heading) + '[ \t]*$'))
     if ($matches.Count -ne 1) {
       $errors.Add("Structural gate section must appear exactly once: $Heading")
       return $null
     }
     $match = $matches[0]
     $start = $match.Index + $match.Length
-    $next = [regex]::Match($Text.Substring($start), '(?m)^#{1,2}\s+[^\n]+$')
-    $length = if ($next.Success) { $next.Index } else { $Text.Length - $start }
-    return $Text.Substring($start, $length)
+    $next = [regex]::Match($visibleText.Substring($start), '(?m)^#{1,2}\s+[^\n]+$')
+    $length = if ($next.Success) { $next.Index } else { $visibleText.Length - $start }
+    return $visibleText.Substring($start, $length)
   }
   $getTable = {
     param([string]$Text, [string]$Heading, [string[]]$Columns)
     $section = & $getSection $Text $Heading
     if ($null -eq $section) { return $null }
     $sectionLines = @($section -split "`n")
     $tableStart = -1
     for ($index = 0; $index -lt $sectionLines.Count; $index++) {
       if ($sectionLines[$index] -match '^\|') { $tableStart = $index; break }
     }

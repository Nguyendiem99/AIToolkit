# Review package: 1001e2ce525d84bec710d93232498583a6d82b67..686492cbdc09475024c455213c3f4bf7ba7dc76a

## Commits
686492c test: cover responsibility conformance workflow

## Files changed
 .../contracts/file-responsibility-conformance.md   |  21 +++
 .../contracts/target-structure-conformance.md      |  14 +-
 .../skills/migration/code-migration/SKILL.md       |   2 +-
 .../skills/migration/verify-parity/SKILL.md        |   2 +
 .../skills/migration/verify-regression/SKILL.md    |   2 +
 .../aitoolkit/skills/shared/ai-review/SKILL.md     |   4 +
 .../aitoolkit/skills/shared/change-hygiene.md      |   5 +-
 .../skills/shared/knowledge-base/SKILL.md          |   2 +
 .../skills/shared/verification-testing/SKILL.md    |   2 +
 .../AIToolkit-main/aitoolkit/templates/kb-entry.md |   4 +
 .../templates/migration/implementation-report.md   |   4 +-
 .../aitoolkit/templates/migration/parity-report.md |   3 +
 .../templates/migration/regression-report.md       |   3 +
 .../aitoolkit/templates/migration/review-report.md |   4 +
 .../templates/migration/verification-report.md     |   4 +
 .../tests/scenarios/architecture-review.Tests.ps1  | 177 ++++++++++++++++++++-
 .../tests/scenarios/flexible-scope-e2e.Tests.ps1   |  36 ++++-
 .../scenarios/responsibility-conformance.Tests.ps1 |  24 ++-
 .../scenarios/responsibility-handoff.Tests.ps1     |  62 ++++++--
 .../tests/scenarios/scope-engine.Tests.ps1         |  14 ++
 .../tests/scenarios/target-conformance.Tests.ps1   |  40 ++++-
 .../tests/validate-migration-framework.Tests.ps1   |   8 +-
 .../responsibility-conformance.validation.ps1      | 156 ++++++++++++++++--
 .../tests/validation/scope-engine.validation.ps1   |   4 +-
 .../validation/target-conformance.validation.ps1   |   9 +-
 25 files changed, 554 insertions(+), 52 deletions(-)

## Diff
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/contracts/file-responsibility-conformance.md b/AIToolkit/AIToolkit-main/aitoolkit/contracts/file-responsibility-conformance.md
index 4989c18..4181f5a 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/contracts/file-responsibility-conformance.md
+++ b/AIToolkit/AIToolkit-main/aitoolkit/contracts/file-responsibility-conformance.md
@@ -76,20 +76,41 @@ Verification Disposition = required | not-applicable-approved
 Evidence Kind and Verification Disposition are separate fields. A
 `not-applicable-approved` disposition needs its approval reference and does
 not change the structural verdict.
 
 ## Actual Responsibility Evidence
 
 Actual responsibility is recorded against owned capability IDs, atomic
 boundary IDs, and evidence references. It is not established by a heuristic
 class-name match, a line count, or a file-location guess.
 
+## Changed Git Path Classification and Reconciliation
+
+Independent review derives the changed-path inventory from the immutable pinned
+`task-base..final-tree` Git comparison, including `M`, `A`, `R`, `C`, and `D`.
+Repository-relative paths rooted at `src/`, `lib/`, `app/`, `apps/*/src|lib|app`,
+`packages/*/src|lib|app`, `server/`, `client/`, `frontend/`, or `backend/` are
+canonically production-classified; nested test, spec, doc, script, tool,
+generated, build, and distribution roots are excluded unless an approved
+responsibility explicitly selects them. Marker presence never determines
+whether a changed path enters the inventory.
+
+Every changed Git path reconciles to implementation `Change Hygiene` using
+`A/C = new`, `M/R = existing`, and `D = deleted`. Every production-classified
+changed path additionally reconciles to an active responsibility or an
+approved deletion. For `M/R`, compare pinned base and final contents so a
+removed responsibility block enters the deletion flow even when its file
+survives. A deleted path or removed block uses exact immutable evidence
+`source:<task-base SHA>:<path>; diff:<task-base SHA>..<final-tree SHA>:<path>`;
+the deleted path is not required in final-tree. Omitted paths, markerless
+production changes, stale or foreign evidence, and unapproved removals block.
+
 ## Review Verdicts
 
 ```text
 Verdict = PASS | BLOCKED
 ```
 
 Structural responsibility remains `PASS` or `BLOCKED` independently of runtime
 waivers. A runtime waiver changes neither responsibility ownership nor the
 structural verdict.
 
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/contracts/target-structure-conformance.md b/AIToolkit/AIToolkit-main/aitoolkit/contracts/target-structure-conformance.md
index 0fd1d89..74bea44 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/contracts/target-structure-conformance.md
+++ b/AIToolkit/AIToolkit-main/aitoolkit/contracts/target-structure-conformance.md
@@ -5,25 +5,29 @@ conformance, assurance-state, pre-edit gate, and architecture-first review
 semantics. Skills and schemas reference it instead of redefining its tables or
 enums.
 
 File responsibility, capability ownership, co-location, verification ownership,
 and their canonical enums are solely governed by
 `contracts/file-responsibility-conformance.md`. This contract does not redefine
 them.
 
 ## Comparable Target Exemplars
 
-| Concern | Path | Inspected Symbols | Observed Pattern | Comparable Reason | Evidence | Status |
-|---|---|---|---|---|---|---|
-| applicable structural concern | real target path | fully inspected symbols | observed working pattern | why the exemplar is comparable | exact evidence reference | exemplar status |
-
-Exemplar status: `verified | no-equivalent | unknown`.
+| Concern | Path | Inspected Symbols | Observed Pattern | Primary Responsibility | Owned Capabilities | Verification Owner | Comparable Reason | Evidence | Inspection Status | Classification | Classification Authority | Classification Evidence |
+|---|---|---|---|---|---|---|---|---|---|---|---|---|
+| applicable structural concern | real target path | fully inspected symbols | observed working pattern | concrete reason-to-change | CAP-EXAMPLE | VERIFY-OWNER-EXAMPLE | why the exemplar is comparable | exact evidence reference | verified | preferred | factual-discovery-evidence | working-evidence:target/example.dart#Example |
+
+`Inspection Status` and `Classification` are independent. Inspection Status:
+`verified | no-equivalent | unknown`. Classification:
+`preferred | compatibility-only | legacy-debt | no-equivalent`. Classification
+authority and immutable evidence follow
+`contracts/file-responsibility-conformance.md`; no seven-column discovery adapter is executable in responsibility contract v1.
 
 Incremental discovery records exactly these eight concerns:
 
 1. `module/container composition`
 2. `main/child presentation boundaries`
 3. `unit/component organization`
 4. `controller/provider/state pattern`
 5. `routing and lifecycle`
 6. `localization`
 7. `service/config subscription and normalization`
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/skills/migration/code-migration/SKILL.md b/AIToolkit/AIToolkit-main/aitoolkit/skills/migration/code-migration/SKILL.md
index 7754a61..fac11da 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/skills/migration/code-migration/SKILL.md
+++ b/AIToolkit/AIToolkit-main/aitoolkit/skills/migration/code-migration/SKILL.md
@@ -108,21 +108,21 @@ Evidence includes approval, conformance, RED/GREEN output, commands, changes, an
 - Preserve the exact `Master Scope Context`, canonical adapter row, conformance-matrix approval, eight exemplar-read rows, actual/planned file mapping, five target-boundary rows, deviation dispositions, activation evidence, and three independent assurance states.
 - `architecture_conformance_state` and `selector_schema_state` must both be `PASS` for editing; neither can be waived. Runtime `WAIVED` does not alter them.
 - Preserve `Selected Migration Unit` with `migration_unit_id`, plan reference, approval reference, mode constraint, `Bootstrap Scope`, Foundation Baseline ID, foundation baseline reference, foundation baseline approval reference, baseline reference, and trace IDs only when `Adapter Kind = migration-unit`; omit that section for every other canonical adapter.
 - Preserve `Activation Slice` with canonical `ACT-[0-9]{3}`, all nine canonical seam rows in order, legal states, and exact fields except allowed append-only Source Reference enrichment.
 - Every changed-file row and every test evidence record must link to the approved Activation Slice seam and its trace IDs.
 - Each link carries non-empty canonical Trace IDs that are a subset of both seam and Work Item authority; whole-set equality is not required.
 - Those rows use the exact approved `Work Item ID`; generic adapters contain no invented unit ID.
 - Use the structured changed-file and `Activation Slice Test Evidence` tables; prose-only linkage is invalid.
 - Preserve the exact resolved selector as `foundation_baseline_id` in the implementation artifact and every downstream migration handoff; never rename, omit, or regenerate it.
 - Preserve `Changed Files`, `Trace IDs`, `Commands and Results`, `Evidence`, `Unknowns`, and `Verdict`.
-- Preserve `Change Hygiene` with adapter-aware assurance identity for every changed file: `Task / Unit` is the exact selected Migration Unit ID for `migration-unit`, otherwise the approved current Work Item ID; also preserve file kind, edited region/symbol, formatter command, and unrelated-diff verdict.
+- Preserve `Change Hygiene` with adapter-aware assurance identity for every changed Git path: `Task / Unit` is the exact selected Migration Unit ID for `migration-unit`, otherwise the approved current Work Item ID. Reconcile the pinned status exactly as `A/C = new`, `M/R = existing`, or `D = deleted`; also preserve edited region/symbol, formatter command, and unrelated-diff verdict. A `deleted` row has no final-tree path requirement and must carry exact `source:<task-base SHA>:<path>; diff:<task-base SHA>..<final-tree SHA>:<path>` base/removal evidence. A responsibility block removed from a surviving file uses `existing` with that same evidence pair for the removed owner. Omitted, stale, foreign, or status-mismatched evidence blocks output.
 - Preserve `Blocker gốc` with the native verdict, command/capability, observed error, and evidence reference even if the orchestrator later appends an automation waiver.
 - For a routed `result: blocked` artifact whose Activation Slice and immediate-predecessor handoff are otherwise valid, emit exactly one `Domain Blocker` table with non-placeholder `Blocker` and `Evidence Reference` values; omit that section for non-blocked output.
 - Every changed-file row names one approved work item and at least one trace ID.
 - On baseline-waiver resume, preserve `Approved Baseline Waiver` and `Step 10 Waiver Resume State`; without target source mutation evidence the result is `blocked`.
 
 ## Quick reference
 
 | Condition | Action |
 |---|---|
 | Approved work item, structural PASS, and resolved commands | TDD in isolated worktree |
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/skills/migration/verify-parity/SKILL.md b/AIToolkit/AIToolkit-main/aitoolkit/skills/migration/verify-parity/SKILL.md
index aadb3ca..f1a9054 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/skills/migration/verify-parity/SKILL.md
+++ b/AIToolkit/AIToolkit-main/aitoolkit/skills/migration/verify-parity/SKILL.md
@@ -28,20 +28,22 @@ Use forwarded acceptance scenarios and trace IDs; do not load cumulative numbere
 ## Baseline gate
 
 Determine parity policy from `verification.behavior_parity`.
 
 - When parity is required, every scenario needs a `required baseline`: a fresh runnable source result or an approved golden expectation with its source reference.
 - If any required baseline is missing, stale, ambiguous, or cannot be reproduced, record `result: blocked` and a blocked verdict. Never mark that scenario or the report PASS.
 - A changed behavior passes only when an approved decision explicitly replaces the old expectation and the report cites that decision and affected trace IDs.
 
 ## Migration-only handoff extension
 
+An executable step-13 artifact has the exact canonical front matter keys and lifecycle `status: approved`, `result: complete`, `approval_source: human`. Draft, blocked, automatic, duplicate-key, extra-key, or cross-run output is non-executable and cannot seed regression or Knowledge Base.
+
 This skill runs for `workflow_type: migration`; feature and bugfix shared flows do not use this extension. The immediate predecessor must preserve exact `Master Scope Context` and `Delivery Adapter Kind`; require exactly one `Selected Migration Unit` only when `Delivery Adapter Kind` is `migration-unit`, and otherwise omit `Selected Migration Unit` without inventing `UNIT-*`.
 
 - Validate and copy `migration_unit_id`, plan reference, approval reference, mode constraint, `Bootstrap Scope`, Foundation Baseline ID, foundation baseline reference, foundation baseline approval reference, baseline reference, and trace IDs into the parity report.
 - The output keeps `result: complete | blocked`; missing, ambiguous, or mismatched handoff evidence yields `result: blocked` before parity execution.
 - Never reconstruct the selected unit or incremental baseline reference from cumulative artifacts.
 - Before matrix validation or parity execution, validate and copy exactly one `Architecture Responsibility Handoff` table from the immediate `verification-report.md` predecessor. Preserve the ordinally exact contract version, Tree Conformance, Responsibility Conformance, Verification Ownership, Architecture Conformance State, and Evidence References; derive the aggregate state from the three sub-verdicts. Do not reconstruct responsibility provenance from cumulative artifacts or directory scans. Missing, stale/cross-run, unsupported/mixed-version, mismatched evidence, or any `BLOCKED` sub-verdict yields `result: blocked` before parity execution. Runtime/`auto-waive` never changes the responsibility handoff.
 
 ## Procedure
 
 1. Read `aitoolkit-schemas`, the profile, project pack, predecessor artifact, and `aitoolkit/templates/migration/parity-report.md`; validate the migration-only handoff extension.
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/skills/migration/verify-regression/SKILL.md b/AIToolkit/AIToolkit-main/aitoolkit/skills/migration/verify-regression/SKILL.md
index bfc2d32..66781b8 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/skills/migration/verify-regression/SKILL.md
+++ b/AIToolkit/AIToolkit-main/aitoolkit/skills/migration/verify-regression/SKILL.md
@@ -26,20 +26,22 @@ Validate and copy that envelope before regression execution. Regression evidence
 Use forwarded trace IDs and pre-change evidence; do not load cumulative artifacts or create private state.
 
 ## Applicability and baseline gate
 
 Regression verification is mandatory for incremental / `preserve-existing` and cannot be waived or skipped. Other mode/policy pairs yield `result: blocked` without a regression claim.
 
 Require a regression command resolved before comparison and a pre-change target run captured before implementation. Resolve the command through `explicit profile -> existing project scripts/config -> marker detection -> human gate`. A missing command or comparable baseline yields `result: blocked`; do not infer a baseline from the candidate.
 
 ## Migration-only handoff extension
 
+An executable step-14 artifact has the exact canonical front matter keys and lifecycle `status: approved`, `result: complete`, `approval_source: human`. Draft, blocked, automatic, duplicate-key, extra-key, or cross-run output is non-executable and cannot seed Knowledge Base.
+
 This skill runs for `workflow_type: migration`; feature and bugfix shared flows do not use this extension. Preserve exact `Master Scope Context` and `Delivery Adapter Kind`; require exactly one `Selected Migration Unit` only when `Delivery Adapter Kind` is `migration-unit`, and otherwise omit `Selected Migration Unit` without inventing `UNIT-*`. The immediate predecessor must also contain the structured `Parity Verdict` row and evidence reference required by `aitoolkit/contracts/activation-slice.md`.
 
 - Validate and copy `migration_unit_id`, plan reference, approval reference, mode constraint, `Bootstrap Scope`, Foundation Baseline ID, foundation baseline reference, foundation baseline approval reference, baseline reference, and trace IDs from the immediate predecessor.
 - Preserve a lifecycle-valid predecessor parity verdict (`pass | fail`), add the regression verdict, and write `result: complete | blocked`. A blocked parity report stops before step 14. Missing, ambiguous, or mismatched selected-unit, baseline, or verdict evidence yields `result: blocked` before executing regression.
 - Never reconstruct the envelope or parity verdict from cumulative artifacts. For feature and bugfix, this extension is not applicable.
 - Before matrix validation or regression execution, validate and copy exactly one `Architecture Responsibility Handoff` table from the immediate `13-parity-report.md` predecessor. Preserve the ordinally exact contract version, Tree Conformance, Responsibility Conformance, Verification Ownership, Architecture Conformance State, and Evidence References; derive the aggregate state from the three sub-verdicts. Do not reconstruct responsibility provenance from cumulative artifacts or directory scans. Missing, stale/cross-run, unsupported/mixed-version, mismatched evidence, or any `BLOCKED` sub-verdict yields `result: blocked` before regression execution. Runtime/`auto-waive` never changes the responsibility handoff.
 
 ## Procedure
 
 1. Read `aitoolkit-schemas`, the profile, project pack, immediate predecessor artifact, and `aitoolkit/templates/migration/regression-report.md`; validate the migration-only handoff extension.
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/skills/shared/ai-review/SKILL.md b/AIToolkit/AIToolkit-main/aitoolkit/skills/shared/ai-review/SKILL.md
index 857a5d4..df0ba69 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/skills/shared/ai-review/SKILL.md
+++ b/AIToolkit/AIToolkit-main/aitoolkit/skills/shared/ai-review/SKILL.md
@@ -33,20 +33,22 @@ Với `workflow_type: migration`, thực hiện đúng thứ tự gate sau; ch
 3. Canonical selector validation.
 4. Tree conformance from final inventory and source/diff evidence.
 5. Responsibility conformance against planned responsibility evidence.
 6. Verification ownership from final inventory and source/diff evidence.
 7. Production activation-path validation.
 8. Behavior, failure modes, security, performance, and tests.
 9. Change hygiene.
 
 Architecture-first review order: master/work-item -> rules -> selector -> tree -> responsibility -> verification ownership -> activation -> behavior/security/performance -> hygiene.
 
+Derive every `M/A/R/C/D` changed Git path from the pinned comparison and reconcile it to implementation `Change Hygiene` with exact status mapping `A/C = new`, `M/R = existing`, and `D = deleted`. Independently classify production paths by the canonical roots in the file-responsibility contract: markerless production changes still require approved responsibility evidence, while irrelevant docs are not promoted to production by guesswork. Compare pinned base and final content for surviving `M/R` paths so removed responsibility blocks enter deletion reconciliation. A removed block in a surviving file uses `File Kind = existing` and exact task-base source/removal-diff evidence; a deleted file uses `File Kind = deleted` and does not require a final-tree path.
+
 The reviewer independently inspects the final inventory and task-base/final-tree source diff. Implementation self-attestation is not semantic PASS evidence. For every selected Verification Ownership row, resolve `Evidence Path` from the pinned final-tree SHA, locate exactly its named scenario, and bind the scenario's exact verification owner, production responsibility, capability, evidence kind, disposition, and production path/symbol to the independent final production inventory. `production-composition` also binds the exact production route and provider. An unchanged verification file is valid final-tree source evidence without a fabricated diff; missing, foreign, stale, self-attested, or test-only registry/provider evidence is `BLOCKED`. This is framework-neutral source-contract validation and must not infer authority from a language-specific AST. Never discard a base-only deleted responsibility after checking its removal diff: reconcile its owner, path, public symbols, capabilities, effects, architecture/co-location authority, verification owners, routes, and providers to one exact approved design removal decision, one `Change Hygiene` row with `File Kind = deleted`, and one independent Responsibility Review Evidence row using task-base source plus removal-diff references. A missing or partial reconciliation is an unplanned deletion and blocks Tree and Responsibility conformance. Missing master context, canonical selector, conformance matrix, exemplar, actual/planned tree evidence, responsibility review evidence, verification ownership evidence, or applicable production activation evidence records the matching verdict as `BLOCKED`, sets the overall verdict to `Reject`, and stops before reviewer dispatch and before behavior analysis. Rule Resolution remains an independent first severity gate and cannot be weakened by architecture ordering.
 
 Require exactly one Architecture Conformance Verdict, exactly one Canonical Selector Verdict, exactly one Tree Conformance Verdict, exactly one Responsibility Conformance Verdict, exactly one Verification Ownership Verdict, and exactly one Production Activation-path Verdict. Any `BLOCKED` verdict makes the overall verdict `Reject`, independently of severity counts.
 
 ## Mandatory architecture findings
 
 Review invented aggregate state; direct widget service/router calls; raw layout replacing the target wrapper; missing unit boundary; wrong localization mechanism; missing lifecycle gate; tests bypassing the production provider; missing production subscription key; planned/actual tree drift; source/diff inventory that exposes an omitted owner, public symbol, effect, route, or provider; an unplanned full deletion of an owned responsibility; and unapproved structural deviation. Classify a missing production subscription key as `Critical`. An unapproved structural deviation is at least `Major` and is `Critical` when activation, routing, or rendering fails.
 
 ## Việc cần làm (thứ tự)
 
@@ -77,20 +79,22 @@ Review invented aggregate state; direct widget service/router calls; raw layout
 | **Critical** | Sai đúng / mất dữ liệu / lỗ hổng bảo mật / crash / phá vỡ hợp đồng hiện có / không đảo ngược | **Chặn** — phải sửa trước khi đi tiếp |
 | **Major** | Thiếu xử lý lỗi, thiếu test cho hành vi mới, hồi quy hiệu năng, vi phạm project rule cứng | Sửa trước khi merge |
 | **Minor** | Style, naming, micro-opt, doc | Ghi nhận, không chặn |
 
 Blocking condition: `Rule Resolution: BLOCKED`, bất kỳ architecture-first verdict nào là `BLOCKED`, hoặc `Critical count > 0`. Mandatory rule-resolution gap là independent blocking condition, ghi riêng và không bịa một Critical finding. **Major KHÔNG tự lọt êm:** ghi vào report với verdict `Approve-with-fixes` và được **mang tới bước tạo code / gerrit** để xử lý trước merge; đừng coi `Approve-with-fixes` là "xong".
 
 Giữ nguyên severity gate dùng chung: Blocking condition: `Rule Resolution: BLOCKED` or `Critical count > 0`. Migration áp dụng thêm ba architecture-first verdict như các gate độc lập phía trên.
 
 Rule Resolution is evaluated before severity counts. Vì vậy `Rule Resolution: BLOCKED` với 0 Critical và 0 Major vẫn có verdict `Reject`; không được suy `Approve` từ counts.
 
+Only exact `Critical count: 0` with exact overall `Verdict: Approve` is executable and may seed verification. `Approve-with-fixes`, `Reject`, invalid or positive Critical count, and every `BLOCKED` architecture verdict remain non-executable even when an Architecture Responsibility Handoff row says `PASS`.
+
 ## Migration-only handoff extension
 
 Preserve the immediate predecessor Activation Slice envelope without loss: keep the complete case-sensitive slice ID set, Applicability, all nine canonical seam rows, and every predecessor Source Reference and Trace ID. Source Reference enrichment is append-only, and predecessor Trace IDs remain a subset of successor Trace IDs. Never reconstruct it from cumulative artifacts.
 
 Khi orchestrator gọi step này với `workflow_type: migration`, trước hết copy nguyên vẹn `Master Scope Context` của work item. Chỉ khi `Delivery Adapter Kind` là `migration-unit`, immediate predecessor mới phải chứa đúng một section `Selected Migration Unit`; validate và copy nguyên vẹn `migration_unit_id`, plan reference, approval reference, mode constraint, `Bootstrap Scope`, Foundation Baseline ID, foundation baseline reference, foundation baseline approval reference, baseline reference, và trace IDs sang report mới. Với adapter khác, bỏ section `Selected Migration Unit` và không suy ra unit từ diff.
 
 Migration review là producer gốc của responsibility handoff (`responsibility handoff origin producer`), không copy handoff từ implementation. Dùng `templates/migration/review-report.md` và emit đúng một bounded front matter có `step_id: 11-ai-review`, lifecycle `status`/`result`/`produced_at`, và discriminator `responsibility_contract.version: 1`, `applicability: required`. Draft artifacts omit `approval_source`; approved artifacts dùng đúng canonical enum `human | auto | auto-waive`, và review executable cho terminal chain phải là `approved/complete/human`. Copy ordinally exact tám field `Run ID`, master spec reference/ID/revision, master plan reference/ID/revision và `Work Item ID` từ immediate predecessor; không reconstruct từ cumulative artifacts hoặc directory scan.
 
 Emit đúng một `Task Provenance` row. Resolve assurance identity từ approved current adapter authority: với `migration-unit`, `Task / Unit` phải bằng exact `Selected Migration Unit.Migration Unit ID`; với `task | story | package | phase | milestone | none`, nó phải bằng current `Master Scope Context.Work Item ID`. `Task-base SHA` và `Final-tree SHA` phải là hai SHA đã validate và dùng để review exact diff; `Source Artifact` phải resolve đúng immediate predecessor `implementation-report.md`. Missing, placeholder, stale, cross-run, cross-work-item, hoặc mismatch với implementation `Change Hygiene` là `result: blocked`.
 
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/skills/shared/change-hygiene.md b/AIToolkit/AIToolkit-main/aitoolkit/skills/shared/change-hygiene.md
index eba2029..3949dbd 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/skills/shared/change-hygiene.md
+++ b/AIToolkit/AIToolkit-main/aitoolkit/skills/shared/change-hygiene.md
@@ -17,32 +17,35 @@ Inspect the final diff and remove every untraced or formatting-only change. If a
 Local checkpoint commits are private implementation history. They may be consolidated before delivery, but one task has exactly one final delivery commit. A migration `UNIT-###` is one task and one independently reviewable change.
 
 Squash only the current task's own commits; never use squash to incorporate an upstream branch. Resolve and follow the reviewed project-pack integration policy before consolidating the task without changing its verified tree.
 
 ## Review severity
 
 Confirmed unrelated formatting, whole-file churn in an existing file, mixed task scope, or untraced changes are at least Major. Use Critical when the churn hides or causes a correctness, data-loss, security, or contract defect.
 
 ## Delivery evidence
 
-Record the task/unit ID, base and final commit, changed files/symbols, file kind (`new` or `existing`), formatter commands, final diff-scope verdict, and any project-required ancestry and verification evidence.
+Record the task/unit ID, base and final commit, every changed Git path/symbol, file kind (`new`, `existing`, or `deleted`), formatter commands, final diff-scope verdict, and any project-required ancestry and verification evidence. Reconcile the table against the pinned `task-base..final-tree` `A/C`, `M/R`, and `D` path inventory: `A/C = new`, `M/R = existing`, and `D = deleted`. Omitted, stale, foreign, or status-mismatched rows block review.
+
+A deleted path has no final-tree file requirement. Its `Checkpoint History` must instead contain the exact immutable pair `source:<task-base SHA>:<deleted path>; diff:<task-base SHA>..<final-tree SHA>:<deleted path>`, proving base content and the removal diff. If a responsibility block is removed while its file survives, record the surviving path as `existing` and use the same base-source/removal-diff pair for the removed owner symbol.
 
 ## Non-waivable failures
 
 Ancestry, commit-integrity, correctness, and diff-scope failures are not waiver-eligible. They block before irreversible delivery actions and remain subject to the existing Gerrit HARD gate.
 
 ## Quick reference
 
 | Situation | Required action |
 |---|---|
 | Existing source file | Keep formatting within the edited region or minimum adjacent syntax. |
 | New source file | Full-file formatting is allowed. |
+| Deleted source file | Record `deleted` plus exact task-base source and removal-diff evidence; do not require a final-tree path. |
 | Formatter rewrites unrelated code | Stop and separate the formatting work. |
 | Multiple local checkpoints | Consolidate only this task into one final delivery commit. |
 | Upstream synchronization | Follow the reviewed ancestry-preserving project policy; never squash-copy upstream. |
 
 ## Common mistakes
 
 - Treating formatter output as automatically in scope.
 - Mixing opportunistic cleanup with a functional task.
 - Uploading checkpoint commits as separate changes for one task.
 - Using squash to imitate an upstream merge or rebase.
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/skills/shared/knowledge-base/SKILL.md b/AIToolkit/AIToolkit-main/aitoolkit/skills/shared/knowledge-base/SKILL.md
index b4adb16..627a0cf 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/skills/shared/knowledge-base/SKILL.md
+++ b/AIToolkit/AIToolkit-main/aitoolkit/skills/shared/knowledge-base/SKILL.md
@@ -8,20 +8,22 @@ description: Bước Knowledge Base (khung dùng chung, mọi workflow) — lưu
 Orchestrator gọi skill này, truyền: `RUN_DIR` + authoritative `workflow_type` + `knowledge_step_id` + đường dẫn terminal artifact do orchestrator cung cấp. `knowledge_step_id` là `15-knowledge-base` cho migration và `09-knowledge-base` cho feature/bugfix. Chạy inline. KHÔNG gate.
 
 `Terminal input artifact = exactly one orchestrator-provided path`.
 
 ## Ngôn ngữ artifact
 
 Nhận `artifact_language` do orchestrator truyền khi `workflow_type: migration`. Hiện chỉ hỗ trợ `artifact_language: vi`: viết tiêu đề, tóm tắt, blocker, khuyến nghị và nội dung gate bằng tiếng Việt UTF-8; giữ nguyên mọi field machine-readable, enum, ID, path, command, log, trace field và cột bảng contract. Feature/bugfix giữ contract hiện có.
 
 ## Workflow-aware terminal verdict
 
+For migration, an executable step-15 Knowledge Base artifact uses the exact canonical front matter keys and lifecycle `status: approved`, `result: complete`, `approval_source: human`. Draft, blocked, partial, automatic, duplicate-key, extra-key, or cross-run output is not terminal authority.
+
 - Validate `workflow_type: feature | bugfix | migration` and render it verbatim into the template; never infer it from persistent profile configuration.
 - Migration greenfield yêu cầu terminal input `13-parity-report.md`; migration incremental yêu cầu `14-regression-report.md`. Copy identity của đơn vị được chọn và kết luận parity/regression thực tế vào `Xác minh đầu cuối`, chuẩn hóa terminal verdict thực sự đạt thành `Verification Verdict: PASS`. Chỉ đặt `Completion Verdict: complete` khi không có automation waiver, terminal artifact đã resolve nằm trong `RUN_DIR` này, có `status: approved`, `result: complete` và workflow verdict là pass; incremental còn yêu cầu parity evidence cùng run đã duyệt với result complete và verdict pass. Waiver hợp lệ tuân theo partial policy bên dưới. Mọi artifact draft, partial, failed, blocked, mismatched, missing hoặc cross-run khác làm Completion Verdict thành `blocked`.
 - Migration chỉ có thể đặt `Completion Verdict: complete` khi terminal input có đúng một `Architecture Responsibility Handoff` table, table này PASS theo phép hội của ba sub-verdict, giữ nguyên ordinal version/sub-verdict/evidence từ immediate predecessor, và `Evidence References` resolve tới immutable terminal artifact trong cùng `RUN_DIR`. Missing, stale/cross-run, unsupported/mixed version, mismatched evidence, hoặc bất kỳ sub-verdict `BLOCKED` nào đều làm Completion Verdict `blocked`. Runtime/`auto-waive` chỉ thay runtime state, không được thay responsibility table.
 - Feature and bugfix resolve their `verification-report.md` within the same `RUN_DIR` and record its actual verification verdict. Set Completion Verdict `complete` only when every non-skipped required workflow artifact is present/approved and the orchestrator-provided latest executed terminal artifact records success; use `partial` when nonblocking work remains and `blocked` for missing/failed required evidence. They do not require migration envelopes even when the project profile contains a `migration` section.
 - Record Release Verdict `Go` or `No-Go` only when a real `release-report.md` exists in this run. If release was skipped or is outside the workflow, record `not-run`; do not reuse a generic Go/No-Go as the run completion verdict.
 - Mọi `Artifact Path` và `Terminal Verification Artifact` phải được canonicalize và nằm trong `RUN_DIR`. Ghi path tương đối với `RUN_DIR` để delivery skill độc lập về sau resolve đúng bằng chứng mà không cần implicit handoff.
 
 ## Migration automation waivers
 
 For `workflow_type: migration`, scan every artifact in `RUN_DIR` and list every canonical waiver in `Automation waiver`. Validate exactly five waiver fields (`policy`, `category`, `original_verdict`, `effective_action`, `evidence`) plus the required top-level `status: approved`, `result: partial`, and `approval_source: auto-waive`; missing evidence or any other pairing is invalid and blocks completion.
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/skills/shared/verification-testing/SKILL.md b/AIToolkit/AIToolkit-main/aitoolkit/skills/shared/verification-testing/SKILL.md
index 4c71698..f576ebf 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/skills/shared/verification-testing/SKILL.md
+++ b/AIToolkit/AIToolkit-main/aitoolkit/skills/shared/verification-testing/SKILL.md
@@ -44,20 +44,22 @@ The caller-provided `workflow_type` is authoritative for this run, including whe
 | **Feature/tính năng mới** (`workflow_type: feature`) | Behavior test cho mỗi hành vi trong yêu cầu + edge case | Test mô tả *hành vi mong muốn*, xanh; edge case có mặt |
 | **Bugfix** (`workflow_type: bugfix`) | **Regression test có chứng minh red-green** | Revert fix → test PHẢI FAIL → restore fix → test PASS. Chỉ pass 1 lần KHÔNG đủ |
 | **Migration** (`workflow_type: migration`) | Parity/equivalence: cùng input, so hành vi cũ vs mới | Bảng kịch bản cũ==mới; chênh lệch phải được giải thích, không giấu |
 
 **Regression red-green (bugfix) — không thể bỏ:** một test "pass ngay từ đầu" không chứng minh nó bắt được bug. Phải thấy nó ĐỎ khi chưa có fix.
 
 **Baseline cho parity (migration) — "hành vi cũ" lấy ở đâu:** dùng golden output/kỳ vọng đã ghi trong artifact bước trước (discovery/mapping mô tả hành vi Native mong đợi); nếu code cũ còn chạy được thì chạy nó lấy output làm mốc. KHÔNG tự bịa "chắc giống"; kịch bản nào không có mốc → liệt vào Gap, không tính là parity đã chứng minh.
 
 ## Migration-only handoff extension
 
+An executable step-12 migration artifact has the exact canonical front matter keys and lifecycle `status: approved`, `result: complete`, `approval_source: human`. Draft, blocked, automatic, duplicate-key, extra-key, or cross-run output is non-executable and cannot seed parity.
+
 Read `aitoolkit/contracts/activation-slice.md` as the sole canonical definition. Preserve the immediate predecessor Activation Slice envelope without loss: keep the complete case-sensitive slice ID set, Applicability, all nine canonical seam rows, and every predecessor Source Reference and Trace ID. Source Reference enrichment is append-only, and predecessor Trace IDs remain a subset of successor Trace IDs. Never reconstruct it from cumulative artifacts.
 
 Khi orchestrator gọi step này với `workflow_type: migration`, validate và copy nguyên vẹn `Master Scope Context` cùng exact `Delivery Adapter Kind` từ immediate predecessor. Require và copy đúng một section `Selected Migration Unit` only when `Delivery Adapter Kind` is `migration-unit`; với mọi adapter khác, omit `Selected Migration Unit` và không phát minh `UNIT-*`. Khi có section, preserve `migration_unit_id`, plan reference, approval reference, mode constraint, `Bootstrap Scope`, Foundation Baseline ID, foundation baseline reference, foundation baseline approval reference, baseline reference, và trace IDs sang report mới trước khi chạy verification.
 
 Validate and copy the canonical `Activation Slice` section before running verification. Missing, added, reclassified, narrowed, or trace-losing slice evidence yields `status: draft` and `result: blocked`; do not infer it from the diff, source tree, or cumulative artifacts.
 
 Before matrix validation or any verification command, validate and copy exactly one `Architecture Responsibility Handoff` table from the immediate `review-report.md` predecessor. Preserve the ordinally exact contract version, Tree Conformance, Responsibility Conformance, Verification Ownership, Architecture Conformance State, and Evidence References; derive the aggregate state from the three sub-verdicts rather than accepting a caller value. Do not reconstruct this table from cumulative artifacts or directory scans. Missing, unsupported/mixed version, stale/cross-run provenance, altered evidence, or any `BLOCKED` sub-verdict yields `status: draft`, `result: blocked`, and stops the downstream handoff. A runtime/`auto-waive` decision may only describe runtime evidence; it never changes this responsibility table.
 
 - Ghi front matter migration là `result: complete | blocked` ngoài lifecycle `status: draft`.
 - Thiếu, mơ hồ, hoặc mismatch bất kỳ field nào thì ghi `result: blocked`; không chạy tiếp bằng selector/baseline tự suy từ source hoặc artifact cũ.
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/templates/kb-entry.md b/AIToolkit/AIToolkit-main/aitoolkit/templates/kb-entry.md
index 208abb0..e673e43 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/templates/kb-entry.md
+++ b/AIToolkit/AIToolkit-main/aitoolkit/templates/kb-entry.md
@@ -1,20 +1,24 @@
 ---
 step_id: <orchestrator-provided-step-id>
 status: draft
+result: <complete | partial | blocked>
 # Chỉ migration: thêm `result: complete | partial | blocked`
+approval_source: <human | auto | auto-waive>
 produced_at: <yyyy-mm-dd>
 responsibility_contract:
   version: 1
   applicability: required
 ---
 
+Migration terminal authority is executable only with exactly `status: approved`, `result: complete`, and `approval_source: human`; draft, blocked, partial, or automatic output cannot complete the chain.
+
 <!-- artifact_language: vi -->
 
 # Mục Knowledge Base — <tên mô-đun>
 
 ## Master Scope Context
 
 | Run ID | Master Spec Reference | Master Spec ID | Master Spec Revision | Master Plan Reference | Master Plan ID | Master Plan Revision | Work Item ID |
 |---|---|---|---|---|---|---|---|
 | <RUN-*> | <master spec reference> | <SPEC-*> | <revision> | <master plan reference> | <PLAN-*> | <revision> | <WORK-*> |
 
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/templates/migration/implementation-report.md b/AIToolkit/AIToolkit-main/aitoolkit/templates/migration/implementation-report.md
index a07dfee..7faa8eb 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/templates/migration/implementation-report.md
+++ b/AIToolkit/AIToolkit-main/aitoolkit/templates/migration/implementation-report.md
@@ -165,23 +165,25 @@ Required for normal `draft/complete` and `approved/complete` implementation outp
 | <WORK-*> | <ACT-001> | <canonical seam> | <test/scenario> | <lệnh> | <PASS / FAIL / BLOCKED> | <approved slice/seam trace IDs> |
 
 ## Trace ID triển khai
 
 | Trace ID | Implementation Reference |
 |---|---|
 | <REQ-001> | <path hoặc symbol> |
 
 ## Change Hygiene
 
+List every pinned `task-base..final-tree` changed Git path. Use exact `File Kind`: `A/C = new`, `M/R = existing`, `D = deleted`. A deleted path is resolved from task-base and does not need to exist in final-tree; set `Checkpoint History` to exact `source:<task-base SHA>:<deleted path>; diff:<task-base SHA>..<final-tree SHA>:<deleted path>`. For a removed responsibility block in a surviving file, use `existing` and the same base-source/removal-diff evidence for that owner symbol. Omitted, stale, foreign, or status-mismatched rows are blocking.
+
 | Task / Unit | File | File Kind | Edited Region / Symbol | Formatter Command | Unrelated Diff | Checkpoint History | Task-base SHA | Final-tree SHA |
 |---|---|---|---|---|---|---|---|---|
-| <WORK-*> | <path> | <new or existing> | <region or symbol> | <command or none> | none | <checkpoint SHAs or none> | <sha> | <sha> |
+| <WORK-*> | <path> | <new, existing, or deleted> | <region or symbol> | <command or none> | none | <checkpoint SHAs, deletion evidence, or none> | <sha> | <sha> |
 
 ## Lệnh và kết quả
 
 | Command | Result | Evidence |
 |---|---|---|
 | <lệnh> | <kết quả> | <tham chiếu> |
 
 ## Blocker gốc
 
 Ghi `not-applicable` khi không có blocker. Nếu có, giữ nguyên kết luận `BLOCKED`, vai trò lệnh, vòng đời lệnh bắt buộc và lỗi command/capability verbatim của bước. Mọi lệnh bắt buộc đã khởi chạy đều không đủ điều kiện waiver; chỉ availability probe riêng biệt với vòng đời lệnh bắt buộc `not-started` mới có thể là ứng viên environment waiver. Bước giữ artifact ở draft/blocked; chỉ orchestrator được thêm automation waiver đã duyệt.
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/templates/migration/parity-report.md b/AIToolkit/AIToolkit-main/aitoolkit/templates/migration/parity-report.md
index 9038d09..4c6655f 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/templates/migration/parity-report.md
+++ b/AIToolkit/AIToolkit-main/aitoolkit/templates/migration/parity-report.md
@@ -1,20 +1,23 @@
 ---
 step_id: <orchestrator-provided>
 status: draft
 result: complete
+approval_source: <human | auto | auto-waive>
 produced_at: <yyyy-mm-dd>
 responsibility_contract:
   version: 1
   applicability: required
 ---
 
+Executable output renders exactly `status: approved`, `result: complete`, and `approval_source: human`; draft, blocked, or automatic output is non-executable.
+
 <!-- artifact_language: vi -->
 
 # Báo cáo tương đương migration
 
 ## Master Scope Context
 
 | Run ID | Master Spec Reference | Master Spec ID | Master Spec Revision | Master Plan Reference | Master Plan ID | Master Plan Revision | Work Item ID |
 |---|---|---|---|---|---|---|---|
 | <RUN-*> | <master spec reference> | <SPEC-*> | <revision> | <master plan reference> | <PLAN-*> | <revision> | <WORK-*> |
 
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/templates/migration/regression-report.md b/AIToolkit/AIToolkit-main/aitoolkit/templates/migration/regression-report.md
index c140d72..7494322 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/templates/migration/regression-report.md
+++ b/AIToolkit/AIToolkit-main/aitoolkit/templates/migration/regression-report.md
@@ -1,20 +1,23 @@
 ---
 step_id: <orchestrator-provided>
 status: draft
 result: complete
+approval_source: <human | auto | auto-waive>
 produced_at: <yyyy-mm-dd>
 responsibility_contract:
   version: 1
   applicability: required
 ---
 
+Executable output renders exactly `status: approved`, `result: complete`, and `approval_source: human`; draft, blocked, or automatic output is non-executable.
+
 <!-- artifact_language: vi -->
 
 # Báo cáo hồi quy migration
 
 ## Master Scope Context
 
 | Run ID | Master Spec Reference | Master Spec ID | Master Spec Revision | Master Plan Reference | Master Plan ID | Master Plan Revision | Work Item ID |
 |---|---|---|---|---|---|---|---|
 | <RUN-*> | <master spec reference> | <SPEC-*> | <revision> | <master plan reference> | <PLAN-*> | <revision> | <WORK-*> |
 
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/templates/migration/review-report.md b/AIToolkit/AIToolkit-main/aitoolkit/templates/migration/review-report.md
index 5221b46..9cadac9 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/templates/migration/review-report.md
+++ b/AIToolkit/AIToolkit-main/aitoolkit/templates/migration/review-report.md
@@ -62,20 +62,22 @@ Keep `Selected Migration Unit` only when `Delivery Adapter Kind` is `migration-u
 - Exemplars: <path/symbol exemplar đã đọc>
 - Actual File Tree vs Planned File Tree: <đối chiếu path/symbol và drift>
 - Approved Structural Deviations: <decision/approval hoặc not-applicable>
 
 ## Responsibility Review Evidence
 
 - Tree Conformance Verdict: <PASS | BLOCKED>
 - Responsibility Conformance Verdict: <PASS | BLOCKED>
 - Verification Ownership Verdict: <PASS | BLOCKED>
 - Reviewer inspects the task-base/final-tree diff independently; implementation self-attestation is not semantic PASS evidence.
+- Derive every pinned `M/A/R/C/D` changed Git path and reconcile it to implementation `Change Hygiene` (`A/C = new`, `M/R = existing`, `D = deleted`). Apply the canonical production-root classifier independently of responsibility markers; markerless production changes, omitted rows, and stale/foreign/status-mismatched evidence are `BLOCKED`, while irrelevant docs are not guessed to be production.
+- Compare pinned base and final contents for every surviving `M/R` path. A responsibility block removed from a surviving file enters the same approved deletion reconciliation as a deleted file, but uses `File Kind = existing` plus exact task-base source/removal-diff evidence.
 - For every base-only deleted responsibility, require one approved design removal decision naming the complete deleted ownership/effect inventory, one implementation `Change Hygiene` row with `File Kind = deleted`, and one row below whose immutable evidence uses the task-base source and removal diff. Use exact `removed` for both Actual columns; an absent or partial approval is `BLOCKED`.
 
 | Responsibility ID | Source/Diff Evidence | Planned Public Symbols | Actual Public Symbols | Planned Effects | Actual Effects | Verdict |
 |---|---|---|---|---|---|---|
 
 ## Verification Ownership Source Evidence
 
 Resolve every row independently from the pinned final-tree `Evidence Path` and named scenario. Bind its verification owner, production responsibility, capability, evidence kind, disposition, production path/symbol, and—when `production-composition`—the exact production route/provider. An unchanged evidence file uses final-tree source evidence and must not invent a diff anchor.
 
 | Verification Owner ID | Final-tree Evidence Path | Scenario | Production Responsibility ID | Capability ID | Evidence Kind | Verification Disposition | Production Binding | Production Route / Provider | Verdict |
@@ -139,10 +141,12 @@ Chỉ giữ section này khi front matter là `result: blocked` và Activation S
 
 | Blocker | Evidence Reference |
 |---|---|
 | <blocker cụ thể> | <tham chiếu bằng chứng cụ thể> |
 ## Điểm chưa rõ
 - <không có hoặc điểm chưa rõ>
 
 ## Kết luận
 - **Critical count:** <số nguyên dùng để gate>
 - Verdict: <Approve | Approve-with-fixes | Reject>
+
+Only exact `Critical count: 0` with exact `Verdict: Approve` is executable downstream. `Approve-with-fixes`, `Reject`, a positive/invalid Critical count, or any `BLOCKED` architecture verdict must not seed verification.
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/templates/migration/verification-report.md b/AIToolkit/AIToolkit-main/aitoolkit/templates/migration/verification-report.md
index 9d0139d..7dce6b4 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/templates/migration/verification-report.md
+++ b/AIToolkit/AIToolkit-main/aitoolkit/templates/migration/verification-report.md
@@ -1,20 +1,24 @@
 ---
 step_id: <shared: orchestrator truyền>
 status: draft
+result: <complete | blocked>
 # Chỉ migration: thêm `result: complete | blocked`
+approval_source: <human | auto | auto-waive>
 produced_at: <yyyy-mm-dd>
 responsibility_contract:
   version: 1
   applicability: required
 ---
 
+Migration executable output renders exactly `status: approved`, `result: complete`, and `approval_source: human`; draft, blocked, or automatic output is non-executable.
+
 <!-- artifact_language: vi -->
 
 # Báo cáo Verification & Testing — <tên module>
 
 ## Master Scope Context
 
 | Run ID | Master Spec Reference | Master Spec ID | Master Spec Revision | Master Plan Reference | Master Plan ID | Master Plan Revision | Work Item ID |
 |---|---|---|---|---|---|---|---|
 | <RUN-*> | <master spec reference> | <SPEC-*> | <revision> | <master plan reference> | <PLAN-*> | <revision> | <WORK-*> |
 
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/architecture-review.Tests.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/architecture-review.Tests.ps1
index 128f383..96741ec 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/architecture-review.Tests.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/architecture-review.Tests.ps1
@@ -5,20 +5,21 @@ $validatorPath = Join-Path $toolkitRoot 'tests/validation/architecture-review.va
 $contractText = Get-Content -Raw -Encoding utf8 -LiteralPath (Join-Path $toolkitRoot 'contracts/target-structure-conformance.md')
 $responsibilityContractText = Get-Content -Raw -Encoding utf8 -LiteralPath (Join-Path $toolkitRoot 'contracts/file-responsibility-conformance.md')
 
 function Require-Token([string]$Text, [string]$Token, [string]$Context) {
   if ($Text -notmatch [regex]::Escape($Token)) {
     $script:errors.Add("$Context missing: $Token")
   }
 }
 
 . $validatorPath
+. (Join-Path $toolkitRoot 'tests/validation/responsibility-conformance.validation.ps1')
 
 $canonicalReviewSkill = @'
 # AI Review
 
 ## Architecture-first migration review gates
 
 For migration, perform these gates in order:
 
 1. Master scope and work-item alignment.
 2. Project rule resolution.
@@ -217,21 +218,26 @@ responsibility_contract:
 - Architecture Conformance Verdict: PASS
 
 ## Responsibility Review Evidence
 - Tree Conformance Verdict: PASS
 - Responsibility Conformance Verdict: PASS
 - Verification Ownership Verdict: PASS
 | Responsibility ID | Source/Diff Evidence | Planned Public Symbols | Actual Public Symbols | Planned Effects | Actual Effects | Verdict |
 |---|---|---|---|---|---|---|
 | RESP-ADMIN | source:<FINAL-TREE-SHA>:src/admin_route.source#AdminRoute; diff:<TASK-BASE-SHA>..<FINAL-TREE-SHA>:src/admin_route.source#AdminRoute; source:<FINAL-TREE-SHA>:src/admin_route.source#VERIFY-OWNER-ADMIN; diff:<TASK-BASE-SHA>..<FINAL-TREE-SHA>:src/admin_route.source#VERIFY-OWNER-ADMIN | AdminRoute | AdminRoute | route registration | route registration | PASS |
 
+## Critical
+| File:line | Issue | Proposed fix |
+|---|---|---|
+
 ## Conclusion
+- Critical count: 0
 - Verdict: Approve
 '@
 
 $canonicalApprovedPlanArtifact = @'
 ---
 artifact_type: migration-master-plan
 master_plan_id: PLAN-ADMIN-001
 master_spec_id: SPEC-ADMIN-001
 master_spec_revision: 1
 revision: 1
@@ -389,20 +395,30 @@ function New-ArchitectureReviewFixture {
   Set-Content -Encoding utf8 -LiteralPath (Join-Path $root 'skills/shared/knowledge-base/SKILL.md') -Value $canonicalKnowledgeSkill
   Set-Content -Encoding utf8 -LiteralPath (Join-Path $root 'templates/migration/review-report.md') -Value $canonicalReviewTemplate
   Set-Content -Encoding utf8 -LiteralPath (Join-Path $root 'templates/kb-entry.md') -Value $canonicalKbTemplate
   if ($IncludeIndependentReviewEvidence) {
     Set-Content -Encoding utf8 -LiteralPath (Join-Path $root 'artifacts/implementation-report.md') -Value $canonicalImplementationReviewArtifact
     Set-Content -Encoding utf8 -LiteralPath (Join-Path $root 'artifacts/review-report.md') -Value $canonicalIndependentReviewArtifact
     Set-Content -Encoding utf8 -LiteralPath (Join-Path $root 'artifacts/design-report.md') -Value $canonicalDesignReviewArtifact
     Set-Content -Encoding utf8 -LiteralPath (Join-Path $root 'artifacts/master-plan.md') -Value $canonicalApprovedPlanArtifact
     $pinnedSource = New-PinnedSourceFixture $root $IncrementalOwnerEdit $DeleteLegacyOwner
     Write-PinnedReviewProvenance $root $pinnedSource
+    if ($IncrementalOwnerEdit) {
+      $implementationPath = Join-Path $root 'artifacts/implementation-report.md'
+      $implementation = Get-Content -Raw -Encoding utf8 -LiteralPath $implementationPath
+      $sourceRows = @($implementation -split '\r?\n' | Where-Object { $_ -cmatch '^\| WORK-ADMIN \| src/admin_route\.source \|' })
+      if ($sourceRows.Count -ne 1) { throw 'Incremental Change Hygiene source row is missing or duplicated' }
+      $updatedSourceRow = $sourceRows[0].Replace('| new |', '| existing |')
+      $verificationRow = "| WORK-ADMIN | test/admin_route_test.ps1 | existing | AdminRouteContract | none | none | none | $($pinnedSource.TaskBaseSha) | $($pinnedSource.FinalTreeSha) |"
+      $implementation = $implementation.Replace($sourceRows[0], "$updatedSourceRow`n$verificationRow")
+      Set-Content -Encoding utf8 -LiteralPath $implementationPath -Value $implementation
+    }
   }
   if ($null -ne $Mutation) {
     $mutationPaths = [Collections.Generic.List[string]]::new()
     @(
       'skills/shared/ai-review/SKILL.md',
       'skills/shared/knowledge-base/SKILL.md',
       'templates/migration/review-report.md',
       'templates/kb-entry.md'
     ) | ForEach-Object { $mutationPaths.Add($_) }
     if ($IncludeIndependentReviewEvidence) {
@@ -520,21 +536,22 @@ function Approve-DeletedOwner([string]$Root) {
 | Deviation Reference | Concern | Conflict Reference | Resolved Decision | Tech Lead Approval |
 |---|---|---|---|---|
 | DEV-OBSOLETE-REMOVAL | routing and lifecycle | CONFLICT-OBSOLETE-REMOVAL | resolved:DECISION-OBSOLETE-REMOVAL: remove responsibility=RESP-OBSOLETE; owner=src/obsolete_route.source#ObsoleteRoute; public-symbols=ObsoleteRoute; capabilities=CAP-OBSOLETE-ROUTE; effects=route registration; architecture-authority=target-exemplar; co-location-policy=feature-local; verification-owners=VERIFY-OWNER-OBSOLETE; routes=ObsoleteRoute; providers=ObsoleteRouteProvider | approval:TECH-LEAD-OBSOLETE-REMOVAL |
 '@
   $updatedDesign = $design.TrimEnd() + $designAddition
   if ($updatedDesign -ceq $design) { throw 'Approved deleted owner design fixture replacement failed' }
   Set-Content -Encoding utf8 -LiteralPath $designPath -Value $updatedDesign
 
   $implementationPath = Join-Path $Root 'artifacts/implementation-report.md'
   $implementation = Get-Content -Raw -Encoding utf8 -LiteralPath $implementationPath
-  $implementationRow = "| WORK-ADMIN | src/obsolete_route.source | deleted | ObsoleteRoute | none | none | none | $taskBaseSha | $finalTreeSha |"
+  $deletionCheckpoint = "source:${taskBaseSha}:src/obsolete_route.source; diff:${taskBaseSha}..${finalTreeSha}:src/obsolete_route.source"
+  $implementationRow = "| WORK-ADMIN | src/obsolete_route.source | deleted | ObsoleteRoute | none | none | $deletionCheckpoint | $taskBaseSha | $finalTreeSha |"
   $implementationAnchorRows = @($implementation -split '\r?\n' | Where-Object { $_ -cmatch '^\| WORK-ADMIN \| src/admin_route\.source \|' })
   if ($implementationAnchorRows.Count -ne 1) { throw 'Approved deleted owner implementation fixture anchor is missing or duplicated' }
   $updatedImplementation = $implementation.Replace($implementationAnchorRows[0], "$($implementationAnchorRows[0])`n$implementationRow")
   if ($updatedImplementation -ceq $implementation) { throw 'Approved deleted owner implementation fixture replacement failed' }
   Set-Content -Encoding utf8 -LiteralPath $implementationPath -Value $updatedImplementation
 
   $reviewPath = Join-Path $Root 'artifacts/review-report.md'
   $review = Get-Content -Raw -Encoding utf8 -LiteralPath $reviewPath
   $deletedEvidence = "source:${taskBaseSha}:src/obsolete_route.source#ObsoleteRoute; diff:${taskBaseSha}..${finalTreeSha}:src/obsolete_route.source#ObsoleteRoute; source:${taskBaseSha}:src/obsolete_route.source#VERIFY-OWNER-OBSOLETE; diff:${taskBaseSha}..${finalTreeSha}:src/obsolete_route.source#VERIFY-OWNER-OBSOLETE"
   $reviewRow = "| RESP-OBSOLETE | $deletedEvidence | ObsoleteRoute | removed | route registration | removed | PASS |"
@@ -569,20 +586,45 @@ function Add-SourceSymbolEvidence([string]$Root, [string]$Symbol, [string]$Respo
   $updatedImplementation = $implementationText.Replace($previousFinalTreeSha, $finalTreeSha)
   if ($updatedImplementation -ceq $implementationText) { throw 'Pinned implementation final-tree update failed' }
   Set-Content -Encoding utf8 -LiteralPath $implementationPath -Value $updatedImplementation
   Set-Content -Encoding utf8 -LiteralPath $provenancePath -Value @"
 Source Root: $sourceRoot
 Task-base SHA: $taskBaseSha
 Final-tree SHA: $finalTreeSha
 "@
 }
 
+function Add-MarkerlessProductionPath([string]$Root) {
+  $provenancePath = Join-Path $Root 'artifacts/review-provenance.md'
+  $provenance = Get-Content -Raw -Encoding utf8 -LiteralPath $provenancePath
+  $sourceRoot = [regex]::Match($provenance, '(?m)^Source Root:\s*(?<value>.+)$').Groups['value'].Value.Trim()
+  $taskBaseSha = [regex]::Match($provenance, '(?im)^Task-base SHA:[ \t]*(?<value>[0-9a-f]{40})[ \t]*\r?$').Groups['value'].Value
+  $previousFinalTreeSha = [regex]::Match($provenance, '(?im)^Final-tree SHA:[ \t]*(?<value>[0-9a-f]{40})[ \t]*\r?$').Groups['value'].Value
+  Set-Content -Encoding utf8 -LiteralPath (Join-Path $sourceRoot 'src/markerless_route.source') -Value "route MarkerlessRoute -> MarkerlessProvider`n"
+  Invoke-PinnedSourceGit $sourceRoot @('add', '--', 'src/markerless_route.source') | Out-Null
+  Invoke-PinnedSourceGit $sourceRoot @('commit', '-m', 'markerless production route') | Out-Null
+  $finalTreeSha = Invoke-PinnedSourceGit $sourceRoot @('rev-parse', 'HEAD')
+
+  $implementationPath = Join-Path $Root 'artifacts/implementation-report.md'
+  $implementation = (Get-Content -Raw -Encoding utf8 -LiteralPath $implementationPath).Replace($previousFinalTreeSha, $finalTreeSha)
+  $anchorRows = @($implementation -split '\r?\n' | Where-Object { $_ -cmatch '^\| WORK-ADMIN \| src/admin_route\.source \|' })
+  if ($anchorRows.Count -ne 1) { throw 'Markerless production Change Hygiene anchor is missing or duplicated' }
+  $markerlessRow = "| WORK-ADMIN | src/markerless_route.source | new | MarkerlessRoute | none | none | none | $taskBaseSha | $finalTreeSha |"
+  $implementation = $implementation.Replace($anchorRows[0], "$($anchorRows[0])`n$markerlessRow")
+  Set-Content -Encoding utf8 -LiteralPath $implementationPath -Value $implementation
+
+  $reviewPath = Join-Path $Root 'artifacts/review-report.md'
+  $review = (Get-Content -Raw -Encoding utf8 -LiteralPath $reviewPath).Replace($previousFinalTreeSha, $finalTreeSha)
+  Set-Content -Encoding utf8 -LiteralPath $reviewPath -Value $review
+  Set-Content -Encoding utf8 -LiteralPath $provenancePath -Value "Source Root: $sourceRoot`nTask-base SHA: $taskBaseSha`nFinal-tree SHA: $finalTreeSha`n"
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
@@ -607,20 +649,118 @@ function Remove-ImplementationChangeHygiene([string]$Root) {
   $path = Join-Path $Root 'artifacts/implementation-report.md'
   $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
   $updated = [regex]::Replace($text, '(?ms)^## Change Hygiene\r?\n.*?(?=^## Implementation Self-Attestation)', '')
   if ($updated -ceq $text) { throw 'Implementation Change Hygiene fixture removal failed' }
   Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
 }
 
 Assert-Pass 'complete architecture-first review and scope-aware KB contract' $null
 Assert-Pass 'independent review accepts implementation-bound provenance' $null $true
 
+Assert-FailsLike 'non-PASS overall review conclusion is not executable despite PASS architecture verdicts' {
+  param($root)
+  $path = Join-Path $root 'artifacts/review-report.md'
+  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
+  $updated = $text.Replace('- Verdict: Approve', '- Verdict: Reject')
+  if ($updated -ceq $text) { throw 'Reject conclusion fixture replacement failed' }
+  Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
+} 'responsibility-waiver-forbidden' $true
+
+Assert-FailsLike 'Critical-bearing review is not executable despite PASS architecture verdicts' {
+  param($root)
+  $path = Join-Path $root 'artifacts/review-report.md'
+  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
+  $updated = $text.Replace('- Critical count: 0', '- Critical count: 1')
+  if ($updated -ceq $text) { throw 'Critical-bearing review fixture replacement failed' }
+  Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
+} 'responsibility-waiver-forbidden' $true
+
+Assert-FailsLike 'review rejects a canonically production-classified markerless route even when Change Hygiene lists the path' {
+  param($root)
+  Add-MarkerlessProductionPath $root
+} 'responsibility-evidence-missing|responsibility-owner-extra' $true
+
+foreach ($gitStatusCase in @('A', 'M', 'R', 'C')) {
+  $sourceRoot = Join-Path ([IO.Path]::GetTempPath()) ('aitoolkit-markerless-status-' + [guid]::NewGuid().ToString('N'))
+  try {
+    [void](New-Item -ItemType Directory -Force -Path (Join-Path $sourceRoot 'src'))
+    Invoke-PinnedSourceGit $sourceRoot @('init') | Out-Null
+    Invoke-PinnedSourceGit $sourceRoot @('config', 'core.autocrlf', 'false') | Out-Null
+    Invoke-PinnedSourceGit $sourceRoot @('config', 'user.email', 'fixtures@example.test') | Out-Null
+    Invoke-PinnedSourceGit $sourceRoot @('config', 'user.name', 'AIToolkit fixture') | Out-Null
+    Set-Content -Encoding utf8 -LiteralPath (Join-Path $sourceRoot 'README') -Value 'markerless status fixture'
+    if ($gitStatusCase -cin @('M', 'R', 'C')) {
+      Set-Content -Encoding utf8 -LiteralPath (Join-Path $sourceRoot 'src/markerless_old.source') -Value 'route MarkerlessRoute -> MarkerlessProvider'
+    }
+    Invoke-PinnedSourceGit $sourceRoot @('add', '--all') | Out-Null
+    Invoke-PinnedSourceGit $sourceRoot @('commit', '-m', 'markerless base') | Out-Null
+    $taskBaseSha = Invoke-PinnedSourceGit $sourceRoot @('rev-parse', 'HEAD')
+    switch ($gitStatusCase) {
+      'A' { Set-Content -Encoding utf8 -LiteralPath (Join-Path $sourceRoot 'src/markerless_route.source') -Value 'route MarkerlessRoute -> MarkerlessProvider' }
+      'M' { Set-Content -Encoding utf8 -LiteralPath (Join-Path $sourceRoot 'src/markerless_old.source') -Value 'route MarkerlessRoute -> UpdatedMarkerlessProvider' }
+      'R' { Move-Item -LiteralPath (Join-Path $sourceRoot 'src/markerless_old.source') -Destination (Join-Path $sourceRoot 'src/markerless_route.source') }
+      'C' { Copy-Item -LiteralPath (Join-Path $sourceRoot 'src/markerless_old.source') -Destination (Join-Path $sourceRoot 'src/markerless_route.source') }
+    }
+    Invoke-PinnedSourceGit $sourceRoot @('add', '--all') | Out-Null
+    Invoke-PinnedSourceGit $sourceRoot @('commit', '-m', "markerless $gitStatusCase change") | Out-Null
+    $finalTreeSha = Invoke-PinnedSourceGit $sourceRoot @('rev-parse', 'HEAD')
+    $inventoryErrors = [Collections.Generic.List[string]]::new()
+    $sourceInventory = Get-ArcPinnedSourceInventory -SourceRoot $sourceRoot -TaskBaseSha $taskBaseSha -FinalTreeSha $finalTreeSha -Errors $inventoryErrors
+    $statusRows = @($sourceInventory.ChangedPaths | Where-Object { $_.RawStatus.Substring(0, 1) -ceq $gitStatusCase })
+    if ($statusRows.Count -ne 1 -or $inventoryErrors -cnotcontains 'responsibility-evidence-missing') {
+      throw "markerless $gitStatusCase inventory was not independently classified and rejected: $($inventoryErrors -join '; ')"
+    }
+    Write-Output "PASS: markerless $gitStatusCase production path enters the pinned changed-path inventory and is rejected"
+  }
+  finally {
+    if (Test-Path -LiteralPath $sourceRoot) { Remove-Item -LiteralPath $sourceRoot -Recurse -Force }
+  }
+}
+
+$removedBlockRoot = Join-Path ([IO.Path]::GetTempPath()) ('aitoolkit-removed-owner-block-' + [guid]::NewGuid().ToString('N'))
+try {
+  [void](New-Item -ItemType Directory -Force -Path (Join-Path $removedBlockRoot 'src'))
+  Invoke-PinnedSourceGit $removedBlockRoot @('init') | Out-Null
+  Invoke-PinnedSourceGit $removedBlockRoot @('config', 'core.autocrlf', 'false') | Out-Null
+  Invoke-PinnedSourceGit $removedBlockRoot @('config', 'user.email', 'fixtures@example.test') | Out-Null
+  Invoke-PinnedSourceGit $removedBlockRoot @('config', 'user.name', 'AIToolkit fixture') | Out-Null
+  $keptBlock = "@responsibility RESP-KEEP`n@owner-symbol KeepRoute`n@public-symbol KeepRoute`n@owned-capability CAP-KEEP`n@effect route registration`n@architecture-authority target-exemplar`n@co-location-policy feature-local`n@verification-owner VERIFY-OWNER-KEEP`nroute KeepRoute -> KeepProvider"
+  $removedBlock = "@responsibility RESP-REMOVED`n@owner-symbol RemovedRoute`n@public-symbol RemovedRoute`n@owned-capability CAP-REMOVED`n@effect route registration`n@architecture-authority target-exemplar`n@co-location-policy feature-local`n@verification-owner VERIFY-OWNER-REMOVED`nroute RemovedRoute -> RemovedProvider"
+  $sourcePath = Join-Path $removedBlockRoot 'src/routes.source'
+  Set-Content -Encoding utf8 -LiteralPath $sourcePath -Value "$keptBlock`n$removedBlock"
+  Invoke-PinnedSourceGit $removedBlockRoot @('add', '--all') | Out-Null
+  Invoke-PinnedSourceGit $removedBlockRoot @('commit', '-m', 'two responsibility owners') | Out-Null
+  $taskBaseSha = Invoke-PinnedSourceGit $removedBlockRoot @('rev-parse', 'HEAD')
+  Set-Content -Encoding utf8 -LiteralPath $sourcePath -Value $keptBlock
+  Invoke-PinnedSourceGit $removedBlockRoot @('add', '--all') | Out-Null
+  Invoke-PinnedSourceGit $removedBlockRoot @('commit', '-m', 'remove one responsibility owner') | Out-Null
+  $finalTreeSha = Invoke-PinnedSourceGit $removedBlockRoot @('rev-parse', 'HEAD')
+  $inventoryErrors = [Collections.Generic.List[string]]::new()
+  $sourceInventory = Get-ArcPinnedSourceInventory -SourceRoot $removedBlockRoot -TaskBaseSha $taskBaseSha -FinalTreeSha $finalTreeSha -Errors $inventoryErrors
+  if ($inventoryErrors.Count -ne 0 -or @($sourceInventory.ActiveOwners | Where-Object { $_.Id -ceq 'RESP-KEEP' }).Count -ne 1 -or @($sourceInventory.DeletedOwners | Where-Object { $_.Id -ceq 'RESP-REMOVED' }).Count -ne 1) {
+    throw "surviving-file owner removal did not enter deletion reconciliation: $($inventoryErrors -join '; ')"
+  }
+  Write-Output 'PASS: responsibility block removed from a surviving M path enters deletion reconciliation'
+}
+finally {
+  if (Test-Path -LiteralPath $removedBlockRoot) { Remove-Item -LiteralPath $removedBlockRoot -Recurse -Force }
+}
+
+Assert-FailsLike 'review rejects a changed production path omitted from Change Hygiene' {
+  param($root)
+  $path = Join-Path $root 'artifacts/implementation-report.md'
+  $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
+  $updated = [regex]::Replace($text, '(?m)^\| WORK-ADMIN \| src/admin_route\.source \|[^\r\n]+\r?\n?', '')
+  if ($updated -ceq $text) { throw 'Omitted changed production path fixture replacement failed' }
+  Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
+} 'ARC-CONTRACT-MALFORMED-TABLE: Change Hygiene|responsibility-evidence-missing' $true
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
@@ -661,20 +801,55 @@ foreach ($lineEndingCase in @(
 
   Assert-Pass "review accepts approved obsolete deleted owner ($($lineEndingCase.Name))" {
     param($root)
     Approve-DeletedOwner $root
     Set-ArtifactLineEndings $root 'artifacts/design-report.md' $lineEndingCase.NewLine "approved deleted owner ($($lineEndingCase.Name))"
     Set-ArtifactLineEndings $root 'artifacts/implementation-report.md' $lineEndingCase.NewLine "approved deleted owner ($($lineEndingCase.Name))"
     Set-ArtifactLineEndings $root 'artifacts/review-report.md' $lineEndingCase.NewLine "approved deleted owner ($($lineEndingCase.Name))"
     Set-ArtifactLineEndings $root 'artifacts/review-provenance.md' $lineEndingCase.NewLine "approved deleted owner ($($lineEndingCase.Name))"
     Add-LineEndingProbe $root $lineEndingCase.NewLine "approved deleted owner ($($lineEndingCase.Name))"
   } $true $false $true
+
+  Assert-FailsLike "review rejects approved deletion missing base-source/removal-diff Change Hygiene evidence ($($lineEndingCase.Name))" {
+    param($root)
+    Approve-DeletedOwner $root
+    $path = Join-Path $root 'artifacts/implementation-report.md'
+    $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
+    $updated = [regex]::Replace($text, '(?m)^(\| WORK-ADMIN \| src/obsolete_route\.source \| deleted \| ObsoleteRoute \| none \| none \| )[^|]+( \| [0-9a-f]{40} \| [0-9a-f]{40} \|\r?)$', '$1none$2')
+    if ($updated -ceq $text) { throw 'Missing deletion checkpoint evidence fixture replacement failed' }
+    Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
+  } 'responsibility-evidence-missing' $true $false $true
+
+  Assert-FailsLike "review rejects approved deletion with stale final-tree source evidence ($($lineEndingCase.Name))" {
+    param($root)
+    Approve-DeletedOwner $root
+    $path = Join-Path $root 'artifacts/implementation-report.md'
+    $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
+    $provenance = Get-Content -Raw -Encoding utf8 -LiteralPath (Join-Path $root 'artifacts/review-provenance.md')
+    $taskBaseSha = [regex]::Match($provenance, '(?im)^Task-base SHA:[ \t]*(?<value>[0-9a-f]{40})[ \t]*\r?$').Groups['value'].Value
+    $finalTreeSha = [regex]::Match($provenance, '(?im)^Final-tree SHA:[ \t]*(?<value>[0-9a-f]{40})[ \t]*\r?$').Groups['value'].Value
+    $expected = "source:${taskBaseSha}:src/obsolete_route.source; diff:${taskBaseSha}..${finalTreeSha}:src/obsolete_route.source"
+    $stale = "source:${finalTreeSha}:src/obsolete_route.source; diff:${taskBaseSha}..${finalTreeSha}:src/obsolete_route.source"
+    $updated = $text.Replace($expected, $stale)
+    if ($updated -ceq $text) { throw 'Stale deletion source evidence fixture replacement failed' }
+    Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
+  } 'responsibility-evidence-missing' $true $false $true
+
+  Assert-FailsLike "review rejects approved deletion with foreign removal-diff evidence ($($lineEndingCase.Name))" {
+    param($root)
+    Approve-DeletedOwner $root
+    $path = Join-Path $root 'artifacts/implementation-report.md'
+    $text = Get-Content -Raw -Encoding utf8 -LiteralPath $path
+    $updated = $text.Replace(':src/obsolete_route.source; diff:', ':src/obsolete_route.source; diff:').Replace(':src/obsolete_route.source |', ':src/foreign_route.source |')
+    if ($updated -ceq $text) { throw 'Foreign deletion diff evidence fixture replacement failed' }
+    Set-Content -Encoding utf8 -LiteralPath $path -Value $updated
+  } 'responsibility-evidence-missing' $true $false $true
 }
 
 Assert-Pass 'rendered migration-unit report has one canonical selected unit' {
   param($root)
   Set-RenderedReviewFixture $root 'migration-unit' $true
 }
 
 Assert-Pass 'rendered generic adapter omits selected migration unit' {
   param($root)
   Set-RenderedReviewFixture $root 'task' $false
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/flexible-scope-e2e.Tests.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/flexible-scope-e2e.Tests.ps1
index e4b821e..4539b0a 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/flexible-scope-e2e.Tests.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/flexible-scope-e2e.Tests.ps1
@@ -93,48 +93,52 @@ function Replace-Exact([string]$Path, [string]$Old, [string]$New, [string]$Scena
   }
   if ($before -ceq $after) { throw "$ScenarioId mutation was a silent no-op in $Path : $Old" }
   Write-Utf8 $Path $after
 }
 function Get-ImmutableReference([string]$Run,[string]$Name){
   $path=Join-Path $Run $Name;$sha=[Security.Cryptography.SHA256]::Create();try{$digest=([BitConverter]::ToString($sha.ComputeHash([IO.File]::ReadAllBytes($path)))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()};"rendered-scope-run/$Name#sha256:$digest"
 }
 function Rebind-ImmutableReference([string]$Run,[string]$Old,[string]$New,[string]$ScenarioId){
   $changed=0;Get-ChildItem -LiteralPath $Run -File|Where-Object{$_.Extension-in@('.md','.json')}|ForEach-Object{$before=Get-Content -Raw -Encoding utf8 -LiteralPath $_.FullName;$after=$before.Replace($Old,$New);if($after-cne$before){Write-Utf8 $_.FullName $after;$changed++}};if($changed-eq0){throw "$ScenarioId immutable reference rebind was a silent no-op"}
 }
-function New-ResponsibilityReviewEvidence([string]$Run,[string]$Name,[string]$WorkItem){
+function New-ResponsibilityReviewEvidence([string]$Run,[string]$Name,[string]$WorkItem,[string]$ModeConstraint='incremental/preserve-existing'){
   $path=Join-Path $Run $Name
   $unit=if($WorkItem-ceq'WORK-E2E-A'){'UNIT-A'}else{'UNIT-B'}
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
     '| <UNIT-* for migration-unit; WORK-* otherwise> | <task-base SHA> | <final-tree SHA> | <immediate predecessor artifact path> |'="| $unit | 1111111111111111111111111111111111111111 | 2222222222222222222222222222222222222222 | implementation-report.md |"
     '| 1 | <tree verdict> | <responsibility verdict> | <verification verdict> | <derived architecture state> | source-diff:<task-base SHA>..<final-tree SHA>#<WORK-*> |'="| 1 | PASS | PASS | PASS | PASS | source-diff:1111111111111111111111111111111111111111..2222222222222222222222222222222222222222#$WorkItem |"
   }
   foreach($token in $replacements.Keys){$updated=$text.Replace($token,$replacements[$token]);if($updated-ceq$text){throw "Migration review producer template is missing seam token: $token"};$text=$updated}
-  $renderedSelectedUnit=[regex]::Replace($text,'(?m)^\| <UNIT-001> \|.*$',"| $unit | legacy-plan.md@7 | approval:HUMAN-$unit | incremental/preserve-existing | not-required | not-applicable | not-applicable | not-applicable | $baseline | TRACE-001 |",1)
+  $renderedConclusion=[regex]::Replace($text,'(?m)^- \*\*Critical count:\*\*[^\r\n]*\r?$','- **Critical count:** 0',1)
+  $renderedConclusion=[regex]::Replace($renderedConclusion,'(?m)^- Verdict: <Approve \| Approve-with-fixes \| Reject>[ \t]*\r?$','- Verdict: Approve',1)
+  if($renderedConclusion-ceq$text-or@([regex]::Matches($renderedConclusion,'(?m)^- \*\*Critical count:\*\* 0\r?$')).Count-ne1-or@([regex]::Matches($renderedConclusion,'(?m)^- Verdict: Approve\r?$')).Count-ne1){throw 'Migration review producer template is missing executable conclusion seams'}
+  $text=$renderedConclusion
+  $renderedSelectedUnit=[regex]::Replace($text,'(?m)^\| <UNIT-001> \|.*$',"| $unit | legacy-plan.md@7 | approval:HUMAN-$unit | $ModeConstraint | not-required | not-applicable | not-applicable | not-applicable | $baseline | TRACE-001 |",1)
   if($renderedSelectedUnit-ceq$text){throw 'Migration review producer template is missing selected-unit row seam'}
   $text=$renderedSelectedUnit
   Write-Utf8 $path $text
   Get-ImmutableReference $Run $Name
 }
-function New-ResponsibilityDownstreamArtifact([string]$Run,[string]$Name,[string]$WorkItem,[string]$StepId,[string]$SourceArtifact){
+function New-ResponsibilityDownstreamArtifact([string]$Run,[string]$Name,[string]$WorkItem,[string]$StepId,[string]$SourceArtifact,[string]$ModeConstraint='incremental/preserve-existing'){
   $path=Join-Path $Run $Name
   $unit=if($WorkItem-ceq'WORK-E2E-A'){'UNIT-A'}else{'UNIT-B'}
   $baseline=if($unit-ceq'UNIT-A'){'baseline:a'}else{'baseline:b'}
-  Write-Utf8 $path "---`nstep_id: $StepId`nstatus: approved`nresult: complete`napproval_source: human`nproduced_at: 2026-08-20`nresponsibility_contract:`n  version: 1`n  applicability: required`n---`n# Responsibility Handoff Stage`n`n## Master Scope Context`n`n| Run ID | Master Spec Reference | Master Spec ID | Master Spec Revision | Master Plan Reference | Master Plan ID | Master Plan Revision | Work Item ID |`n|---|---|---|---|---|---|---|---|`n| RUN-E2E-001 | rendered-scope-run/master-spec.md | SPEC-E2E-001 | 1 | rendered-scope-run/master-plan.md | PLAN-E2E-001 | 1 | $WorkItem |`n`n- Delivery Adapter Kind: migration-unit`n`n## Task Provenance`n`n| Task / Unit | Task-base SHA | Final-tree SHA | Source Artifact |`n|---|---|---|---|`n| $unit | 1111111111111111111111111111111111111111 | 2222222222222222222222222222222222222222 | $SourceArtifact |`n`n## Selected Migration Unit`n`n| Migration Unit ID | Plan Reference | Approval Reference | Mode Constraint | Bootstrap Scope | Foundation Baseline ID | Foundation Baseline Reference | Foundation Baseline Approval Reference | Baseline Reference | Trace IDs |`n|---|---|---|---|---|---|---|---|---|---|`n| $unit | legacy-plan.md@7 | approval:HUMAN-$unit | incremental/preserve-existing | not-required | not-applicable | not-applicable | not-applicable | $baseline | TRACE-001 |`n`n## Architecture Responsibility Handoff`n`n| Responsibility Contract Version | Tree Conformance | Responsibility Conformance | Verification Ownership | Architecture Conformance State | Evidence References |`n|---|---|---|---|---|---|`n| 1 | PASS | PASS | PASS | PASS | source-diff:1111111111111111111111111111111111111111..2222222222222222222222222222222222222222#$WorkItem |`n"
+  Write-Utf8 $path "---`nstep_id: $StepId`nstatus: approved`nresult: complete`napproval_source: human`nproduced_at: 2026-08-20`nresponsibility_contract:`n  version: 1`n  applicability: required`n---`n# Responsibility Handoff Stage`n`n## Master Scope Context`n`n| Run ID | Master Spec Reference | Master Spec ID | Master Spec Revision | Master Plan Reference | Master Plan ID | Master Plan Revision | Work Item ID |`n|---|---|---|---|---|---|---|---|`n| RUN-E2E-001 | rendered-scope-run/master-spec.md | SPEC-E2E-001 | 1 | rendered-scope-run/master-plan.md | PLAN-E2E-001 | 1 | $WorkItem |`n`n- Delivery Adapter Kind: migration-unit`n`n## Task Provenance`n`n| Task / Unit | Task-base SHA | Final-tree SHA | Source Artifact |`n|---|---|---|---|`n| $unit | 1111111111111111111111111111111111111111 | 2222222222222222222222222222222222222222 | $SourceArtifact |`n`n## Selected Migration Unit`n`n| Migration Unit ID | Plan Reference | Approval Reference | Mode Constraint | Bootstrap Scope | Foundation Baseline ID | Foundation Baseline Reference | Foundation Baseline Approval Reference | Baseline Reference | Trace IDs |`n|---|---|---|---|---|---|---|---|---|---|`n| $unit | legacy-plan.md@7 | approval:HUMAN-$unit | $ModeConstraint | not-required | not-applicable | not-applicable | not-applicable | $baseline | TRACE-001 |`n`n## Architecture Responsibility Handoff`n`n| Responsibility Contract Version | Tree Conformance | Responsibility Conformance | Verification Ownership | Architecture Conformance State | Evidence References |`n|---|---|---|---|---|---|`n| 1 | PASS | PASS | PASS | PASS | source-diff:1111111111111111111111111111111111111111..2222222222222222222222222222222222222222#$WorkItem |`n"
   Get-ImmutableReference $Run $Name
 }
 function Add-ResponsibilityHandoff([string]$Run,[string]$Name,[string]$EvidenceReference){
   $path=Join-Path $Run $Name
   $before=Get-Content -Raw -Encoding utf8 -LiteralPath $path
   $handoff="## Architecture Responsibility Handoff`n`n| Responsibility Contract Version | Tree Conformance | Responsibility Conformance | Verification Ownership | Architecture Conformance State | Evidence References |`n|---|---|---|---|---|---|`n| 1 | PASS | PASS | PASS | PASS | $EvidenceReference |`n`n"
   $after=$before.Replace('## Work Item Test Evidence',"$handoff## Work Item Test Evidence")
   if($after-ceq$before){throw "Terminal responsibility handoff fixture insertion was a silent no-op: $Name"}
   Write-Utf8 $path $after
   Get-ImmutableReference $Run $Name
@@ -202,30 +206,40 @@ function New-RenderedFixture([string]$FixtureRoot, [object]$Scenario) {
   $run = Join-Path $FixtureRoot 'rendered-scope-run'
   New-Item -ItemType Directory -Path $run -Force | Out-Null
   New-LegacyPlan $run
   $queueResponsibilityAuthority=New-QueueResponsibilityEvidence $run
   $reviewA=New-ResponsibilityReviewEvidence $run 'review-a.md' 'WORK-E2E-A'
   $reviewB=New-ResponsibilityReviewEvidence $run 'review-b.md' 'WORK-E2E-B'
   $verificationA=New-ResponsibilityDownstreamArtifact $run 'verification-a.md' 'WORK-E2E-A' '12-verification-testing' 'review-report.md'
   $parityA=New-ResponsibilityDownstreamArtifact $run 'parity-a.md' 'WORK-E2E-A' '13-verify-parity' 'verification-report.md'
   $regressionA=New-ResponsibilityDownstreamArtifact $run 'regression-a.md' 'WORK-E2E-A' '14-verify-regression' '13-parity-report.md'
   $knowledgeA=New-ResponsibilityDownstreamArtifact $run 'knowledge-a.md' 'WORK-E2E-A' '15-knowledge-base' '14-regression-report.md'
-  $greenfieldKnowledgeA=New-ResponsibilityDownstreamArtifact $run 'knowledge-greenfield-a.md' 'WORK-E2E-A' '15-knowledge-base' '13-parity-report.md'
+  $greenfieldReviewA=New-ResponsibilityReviewEvidence $run 'review-greenfield-a.md' 'WORK-E2E-A' 'greenfield/design-new'
+  $greenfieldVerificationA=New-ResponsibilityDownstreamArtifact $run 'verification-greenfield-a.md' 'WORK-E2E-A' '12-verification-testing' 'review-report.md' 'greenfield/design-new'
+  $greenfieldParityA=New-ResponsibilityDownstreamArtifact $run 'parity-greenfield-a.md' 'WORK-E2E-A' '13-verify-parity' 'verification-report.md' 'greenfield/design-new'
+  $greenfieldKnowledgeA=New-ResponsibilityDownstreamArtifact $run 'knowledge-greenfield-a.md' 'WORK-E2E-A' '15-knowledge-base' '13-parity-report.md' 'greenfield/design-new'
   $verificationB=New-ResponsibilityDownstreamArtifact $run 'verification-b.md' 'WORK-E2E-B' '12-verification-testing' 'review-report.md'
   $parityB=New-ResponsibilityDownstreamArtifact $run 'parity-b.md' 'WORK-E2E-B' '13-verify-parity' 'verification-report.md'
   $regressionB=New-ResponsibilityDownstreamArtifact $run 'regression-b.md' 'WORK-E2E-B' '14-verify-regression' '13-parity-report.md'
   $knowledgeB=New-ResponsibilityDownstreamArtifact $run 'knowledge-b.md' 'WORK-E2E-B' '15-knowledge-base' '14-regression-report.md'
-  $greenfieldKnowledgeB=New-ResponsibilityDownstreamArtifact $run 'knowledge-greenfield-b.md' 'WORK-E2E-B' '15-knowledge-base' '13-parity-report.md'
+  $greenfieldReviewB=New-ResponsibilityReviewEvidence $run 'review-greenfield-b.md' 'WORK-E2E-B' 'greenfield/design-new'
+  $greenfieldVerificationB=New-ResponsibilityDownstreamArtifact $run 'verification-greenfield-b.md' 'WORK-E2E-B' '12-verification-testing' 'review-report.md' 'greenfield/design-new'
+  $greenfieldParityB=New-ResponsibilityDownstreamArtifact $run 'parity-greenfield-b.md' 'WORK-E2E-B' '13-verify-parity' 'verification-report.md' 'greenfield/design-new'
+  $greenfieldKnowledgeB=New-ResponsibilityDownstreamArtifact $run 'knowledge-greenfield-b.md' 'WORK-E2E-B' '15-knowledge-base' '13-parity-report.md' 'greenfield/design-new'
   $responsibilityChains=@(
     [ordered]@{work_item_id='WORK-E2E-A';artifact_refs=@($reviewA,$verificationA,$parityA,$regressionA,$knowledgeA)},
     [ordered]@{work_item_id='WORK-E2E-B';artifact_refs=@($reviewB,$verificationB,$parityB,$regressionB,$knowledgeB)}
   )
+  $greenfieldResponsibilityChains=@(
+    [ordered]@{work_item_id='WORK-E2E-A';artifact_refs=@($greenfieldReviewA,$greenfieldVerificationA,$greenfieldParityA,$greenfieldKnowledgeA)},
+    [ordered]@{work_item_id='WORK-E2E-B';artifact_refs=@($greenfieldReviewB,$greenfieldVerificationB,$greenfieldParityB,$greenfieldKnowledgeB)}
+  )
   if($Scenario.Id-ceq'S05'){$responsibilityChains=@($responsibilityChains[0])}
   $terminalA=New-Evidence $run 'terminal-a.md' 'WORK-E2E-A'
   $terminalB=New-Evidence $run 'terminal-b.md' 'WORK-E2E-B'
   $terminalA=Add-ResponsibilityHandoff $run 'terminal-a.md' $knowledgeA
   $terminalB=Add-ResponsibilityHandoff $run 'terminal-b.md' $knowledgeB
   $historicalA=New-HistoricalEvidence $run 'historical-a.md' 'UNIT-A'
   $historicalB=New-HistoricalEvidence $run 'historical-b.md' 'UNIT-B'
   $spec = @'
 ---
 artifact_type: migration-master-spec
@@ -466,21 +480,21 @@ produced_at: 2026-08-20
     master_plan_ref='rendered-scope-run/master-plan.md'
     master_spec_ref='rendered-scope-run/master-spec.md'
     predecessor_ref=$predecessorRef
     responsibility_chain_refs=$responsibilityChains
     scenario_id=$Scenario.Id
     target_evidence_ref='rendered-scope-run/target-evidence.md'
     terminal_report_ref=$terminalRef
   }
   $manifestPath=Join-Path $run 'scenario.json'
   Write-Utf8 $manifestPath ($manifest | ConvertTo-Json -Depth 4)
-  [pscustomobject]@{ Run=$run; Manifest=$manifestPath; Predecessor=$predecessorRef; QueueResponsibilityAuthority=$queueResponsibilityAuthority; ReviewA=$reviewA; ReviewB=$reviewB; TerminalA=$terminalA; TerminalB=$terminalB; HistoricalA=$historicalA; HistoricalB=$historicalB; ResponsibilityChains=$responsibilityChains; GreenfieldKnowledgeA=$greenfieldKnowledgeA; GreenfieldKnowledgeB=$greenfieldKnowledgeB }
+  [pscustomobject]@{ Run=$run; Manifest=$manifestPath; Predecessor=$predecessorRef; QueueResponsibilityAuthority=$queueResponsibilityAuthority; ReviewA=$reviewA; ReviewB=$reviewB; TerminalA=$terminalA; TerminalB=$terminalB; HistoricalA=$historicalA; HistoricalB=$historicalB; ResponsibilityChains=$responsibilityChains; GreenfieldResponsibilityChains=$greenfieldResponsibilityChains; GreenfieldKnowledgeA=$greenfieldKnowledgeA; GreenfieldKnowledgeB=$greenfieldKnowledgeB }
 }
 
 function Apply-ScenarioMutation([object]$Rendered, [object]$Scenario) {
   $pre=Join-Path $Rendered.Run 'predecessor.md'; $spec=Join-Path $Rendered.Run 'master-spec.md'; $plan=Join-Path $Rendered.Run 'master-plan.md'; $target=Join-Path $Rendered.Run 'target-evidence.md'
   $rowA="| WORK-E2E-A | Item A | yes | none | 1 | REQ-001; SC-001; measurable outcome | TRACE-001 | migration-unit:UNIT-A | complete | ATTEMPT-WORK-E2E-A-01 | $($Rendered.TerminalA) | approval:HUMAN-WORK-A |"
   $rowB="| WORK-E2E-B | Item B | no | WORK-E2E-A | 2 | REQ-001; SC-001; measurable outcome | TRACE-001 | migration-unit:UNIT-B | complete | ATTEMPT-WORK-E2E-B-01 | $($Rendered.TerminalB) | approval:HUMAN-WORK-B |"
   switch ($Scenario.Id) {
     'S02' { Replace-Exact $spec 'requested_scope_kind: module' 'requested_scope_kind: explicit-item' $Scenario.Id;Replace-Exact $spec '| module | E2E | Complete E2E module | user | conversation:scope-e2e |' '| explicit-item | E2E | Complete E2E module | user | conversation:scope-e2e |' $Scenario.Id;Replace-Exact $plan '| module | E2E | Complete E2E module | user | conversation:scope-e2e |' '| explicit-item | E2E | Complete E2E module | user | conversation:scope-e2e |' $Scenario.Id }
     'S03' { Replace-Exact $spec 'requested_scope_kind: module' 'requested_scope_kind: unresolved' $Scenario.Id;Replace-Exact $spec '| module | E2E | Complete E2E module | user | conversation:scope-e2e |' '| unresolved | E2E | Complete E2E module | user | conversation:scope-e2e |' $Scenario.Id;Replace-Exact $plan '| module | E2E | Complete E2E module | user | conversation:scope-e2e |' '| unresolved | E2E | Complete E2E module | user | conversation:scope-e2e |' $Scenario.Id }
     'S04' {
@@ -664,29 +678,35 @@ foreach($scenario in $scenarios){
       Replace-Exact $reviewPath 'result: complete' 'result: partial' 'S20-review-result-lifecycle';$partialReviewRef=Get-ImmutableReference $rendered.Run 'review-a.md';Rebind-ImmutableReference $rendered.Run $rendered.ReviewA $partialReviewRef 'S20-review-result-lifecycle';Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'terminal-scope-report-invalid' 'S20-review-result-lifecycle';Write-Utf8 $reviewPath $originalReview;Rebind-ImmutableReference $rendered.Run $partialReviewRef $rendered.ReviewA 'S20-review-result-lifecycle-restore'
       Replace-Exact $reviewPath 'approval_source: human' 'approval_source: automation' 'S20-review-approval-source';$automatedReviewRef=Get-ImmutableReference $rendered.Run 'review-a.md';Rebind-ImmutableReference $rendered.Run $rendered.ReviewA $automatedReviewRef 'S20-review-approval-source';Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'terminal-scope-report-invalid' 'S20-review-approval-source';Write-Utf8 $reviewPath $originalReview;Rebind-ImmutableReference $rendered.Run $automatedReviewRef $rendered.ReviewA 'S20-review-approval-source-restore'
       Replace-Exact $reviewPath '| implementation-report.md |' '| foreign-implementation-report.md |' 'S20-review-immediate-predecessor';$foreignPredecessorReviewRef=Get-ImmutableReference $rendered.Run 'review-a.md';Rebind-ImmutableReference $rendered.Run $rendered.ReviewA $foreignPredecessorReviewRef 'S20-review-immediate-predecessor';Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'terminal-scope-report-invalid' 'S20-review-immediate-predecessor';Write-Utf8 $reviewPath $originalReview;Rebind-ImmutableReference $rendered.Run $foreignPredecessorReviewRef $rendered.ReviewA 'S20-review-immediate-predecessor-restore'
       $greenfieldTerminalA=$originalTerminal.Replace('incremental/preserve-existing','greenfield/design-new').Replace($rendered.ResponsibilityChains[0].artifact_refs[-1],$rendered.GreenfieldKnowledgeA)
       $greenfieldTerminalB=$originalTerminalB.Replace('incremental/preserve-existing','greenfield/design-new').Replace($rendered.ResponsibilityChains[1].artifact_refs[-1],$rendered.GreenfieldKnowledgeB)
       Write-Utf8 $terminalPath $greenfieldTerminalA;Write-Utf8 $terminalBPath $greenfieldTerminalB
       $greenfieldTerminalARef=Get-ImmutableReference $rendered.Run 'terminal-a.md';$greenfieldTerminalBRef=Get-ImmutableReference $rendered.Run 'terminal-b.md'
       Rebind-ImmutableReference $rendered.Run $rendered.TerminalA $greenfieldTerminalARef 'S20-greenfield-terminal-a';Rebind-ImmutableReference $rendered.Run $rendered.TerminalB $greenfieldTerminalBRef 'S20-greenfield-terminal-b'
       Rebind-ImmutableReference $rendered.Run $rendered.ResponsibilityChains[0].artifact_refs[-1] $rendered.GreenfieldKnowledgeA 'S20-greenfield-knowledge-a';Rebind-ImmutableReference $rendered.Run $rendered.ResponsibilityChains[1].artifact_refs[-1] $rendered.GreenfieldKnowledgeB 'S20-greenfield-knowledge-b'
       $greenfieldManifest=Get-Content -Raw -Encoding utf8 -LiteralPath $rendered.Manifest|ConvertFrom-Json
-      foreach($chain in @($greenfieldManifest.responsibility_chain_refs)){$chain.artifact_refs=@($chain.artifact_refs[0],$chain.artifact_refs[1],$chain.artifact_refs[2],$chain.artifact_refs[4])}
+      foreach($chain in @($greenfieldManifest.responsibility_chain_refs)){
+        $greenfieldChain=@($rendered.GreenfieldResponsibilityChains|Where-Object{$_.work_item_id-ceq$chain.work_item_id})[0]
+        $chain.artifact_refs=@($greenfieldChain.artifact_refs)
+      }
       Write-Utf8 $rendered.Manifest ($greenfieldManifest|ConvertTo-Json -Depth 8)
       Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'terminal-scope-report-invalid' 'S20-incremental-cannot-self-label-greenfield'
+      $masterPlanPath=Join-Path $rendered.Run 'master-plan.md'
       $legacyPlanPath=Join-Path $rendered.Run 'legacy-plan.md'
+      Replace-Exact $masterPlanPath 'incremental/preserve-existing' 'greenfield/design-new' 'S20-approved-greenfield-master-plan'
       Replace-Exact $legacyPlanPath 'incremental/preserve-existing' 'greenfield/design-new' 'S20-approved-greenfield-authority'
       Write-ApprovedProjectProfile $fixtureRoot 'greenfield'
       $persistedGreenfieldProfile=Get-Content -Raw -Encoding utf8 -LiteralPath (Join-Path $fixtureRoot 'docs/aitoolkit/project.yaml')
       if($persistedGreenfieldProfile-notmatch'(?m)^  mode: greenfield$'-or$persistedGreenfieldProfile-notmatch'(?m)^  architecture_policy: design-new$'){$failures.Add('S20 persisted external profile did not carry the approved greenfield authority')}
       Assert-Outcome (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'scope-completion-calculated' 'scope-complete' 'S20-greenfield-four-stage-chain'
+      Replace-Exact $masterPlanPath 'greenfield/design-new' 'incremental/preserve-existing' 'S20-approved-greenfield-master-plan-restore'
       Replace-Exact $legacyPlanPath 'greenfield/design-new' 'incremental/preserve-existing' 'S20-approved-greenfield-authority-restore'
       Write-ApprovedProjectProfile $fixtureRoot 'incremental'
       Write-Utf8 $terminalPath $originalTerminal;Write-Utf8 $terminalBPath $originalTerminalB;Rebind-ImmutableReference $rendered.Run $greenfieldTerminalARef $rendered.TerminalA 'S20-greenfield-terminal-a-restore';Rebind-ImmutableReference $rendered.Run $greenfieldTerminalBRef $rendered.TerminalB 'S20-greenfield-terminal-b-restore';Rebind-ImmutableReference $rendered.Run $rendered.GreenfieldKnowledgeA $rendered.ResponsibilityChains[0].artifact_refs[-1] 'S20-greenfield-knowledge-a-restore';Rebind-ImmutableReference $rendered.Run $rendered.GreenfieldKnowledgeB $rendered.ResponsibilityChains[1].artifact_refs[-1] 'S20-greenfield-knowledge-b-restore';Write-Utf8 $rendered.Manifest $originalManifest
 
       $foreignReviewPath=Join-Path $rendered.Run 'foreign/review-a.md'
       Write-Utf8 $foreignReviewPath $originalReview
       $foreignReviewRef=Get-ImmutableReference $rendered.Run 'foreign/review-a.md'
       Rebind-ImmutableReference $rendered.Run $rendered.ReviewA $foreignReviewRef 'S20-same-work-item-cross-run-chain'
       Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'terminal-scope-report-invalid' 'S20-same-work-item-cross-run-chain'
       Rebind-ImmutableReference $rendered.Run $foreignReviewRef $rendered.ReviewA 'S20-same-work-item-cross-run-chain-restore'
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1
index 5612120..bc2ead2 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1
@@ -1230,21 +1230,24 @@ responsibility_contract:
 ## Architecture Responsibility Verdicts
 
 | Responsibility Contract Version | Tree Conformance | Responsibility Conformance | Verification Ownership | Architecture Conformance State | Evidence References |
 |---|---|---|---|---|---|
 | 1 | PASS | PASS | PASS | $ArchitectureState | design:DESIGN-ADMIN@2; diff:HEAD |
 
 ## Change Hygiene
 
 | Task / Unit | File | File Kind | Edited Region / Symbol | Formatter Command | Unrelated Diff | Checkpoint History | Task-base SHA | Final-tree SHA |
 |---|---|---|---|---|---|---|---|---|
-| WORK-ADMIN-LOCK | ui/admin_wifi.dart | existing | AdminWifi | none | none | none | $TaskBaseSha | $FinalTreeSha |
+| WORK-ADMIN-LOCK | ui/admin_wifi.dart | new | AdminWifi | none | none | none | $TaskBaseSha | $FinalTreeSha |
+| WORK-ADMIN-LOCK | ui/admin_wired.dart | new | AdminWired | none | none | none | $TaskBaseSha | $FinalTreeSha |
+| WORK-ADMIN-LOCK | lib/lock_guard.dart | new | LockGuard | none | none | none | $TaskBaseSha | $FinalTreeSha |
+| WORK-ADMIN-LOCK | lib/admin_lock_composition.dart | new | AdminLockComposition | none | none | none | $TaskBaseSha | $FinalTreeSha |
 "@
 }
 
 function Assert-ImplementationRejected([string]$Name, [string]$ImplementationText, [string]$ExpectedDiagnostic) {
   $diagnostics = @(Test-ResponsibilityImplementation -DesignText (New-ResponsibilityPlanDesignFixture) -ImplementationText $ImplementationText -ContractText $contract)
   if ($diagnostics -notcontains $ExpectedDiagnostic) {
     throw "$Name expected $ExpectedDiagnostic but got: $($diagnostics -join '; ')"
   }
   Write-Output "PASS: $Name"
 }
@@ -1363,22 +1366,28 @@ responsibility_contract:
 - Responsibility Conformance Verdict: $ResponsibilityState
 - Verification Ownership Verdict: $VerificationState
 
 | Responsibility ID | Source/Diff Evidence | Planned Public Symbols | Actual Public Symbols | Planned Effects | Actual Effects | Verdict |
 |---|---|---|---|---|---|---|
 | RESP-WIFI | $wifiEvidence | AdminWifi | AdminWifi | none | none | PASS |
 | RESP-WIRED | $wiredEvidence | AdminWired | AdminWired | none | none | PASS |
 | RESP-LOCK-GUARD | $guardEvidence | LockGuard | LockGuard | none | none | PASS |
 | RESP-LOCK-COMPOSITION | $compositionEvidence | AdminLockComposition | AdminLockComposition | route registration | route registration | PASS |
 
+## Critical
+
+| File:line | Issue | Proposed fix |
+|---|---|---|
+
 ## Conclusion
 
+- Critical count: 0
 - Verdict: $OverallVerdict
 "@
 }
 
 function New-ResponsibilityReviewPlanFixture {
   return @"
 ---
 artifact_type: migration-master-plan
 master_plan_id: PLAN-ADMIN-001
 master_spec_id: SPEC-ADMIN-001
@@ -1572,39 +1581,41 @@ foreach ($verificationCase in @(
   [pscustomobject]@{ Variant = 'missing-path'; Name = 'missing verification evidence path' }
   [pscustomobject]@{ Variant = 'missing-scenario'; Name = 'missing verification scenario' }
   [pscustomobject]@{ Variant = 'foreign-owner'; Name = 'foreign verification owner binding' }
   [pscustomobject]@{ Variant = 'stale-scenario'; Name = 'stale verification scenario in the final tree' }
   [pscustomobject]@{ Variant = 'self-attested'; Name = 'self-attested verification binding' }
   [pscustomobject]@{ Variant = 'fake-registry'; Name = 'test-only fake production registry' }
   [pscustomobject]@{ Variant = 'fake-provider'; Name = 'fake provider instead of real production composition' }
 )) {
   $variantSource = New-ResponsibilityReviewSourceFixture -VerificationVariant $verificationCase.Variant
   $variantImplementation = New-ResponsibilityImplementationFixture -TaskBaseSha $variantSource.TaskBaseSha -FinalTreeSha $variantSource.FinalTreeSha
+  if ($verificationCase.Variant -ceq 'stale-scenario') {
+    $variantImplementation = $variantImplementation.TrimEnd() + "`n| WORK-ADMIN-LOCK | test/admin_lock_test.ps1 | existing | AdminWifiContract | none | none | none | $($variantSource.TaskBaseSha) | $($variantSource.FinalTreeSha) |`n"
+  }
   $variantReview = New-ResponsibilityReviewFixture -PinnedSource $variantSource
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
-$changeHygieneRow = "| WORK-ADMIN-LOCK | ui/admin_wifi.dart | existing | AdminWifi | none | none | none | $($validReviewSource.TaskBaseSha) | $($validReviewSource.FinalTreeSha) |"
-$migrationImplementation = $migrationImplementation.Replace($changeHygieneRow, $changeHygieneRow.Replace('WORK-ADMIN-LOCK', 'UNIT-ADMIN-LOCK'))
+$migrationImplementation = [regex]::Replace($migrationImplementation, '(?m)^\| WORK-ADMIN-LOCK \| (?=(?:ui|lib)/)', '| UNIT-ADMIN-LOCK | ')
 $migrationPlan = $script:validReviewPlan.Replace('| WORK-ADMIN-LOCK | none | not-applicable | not-applicable | not-applicable | not-applicable | not-applicable | REQ-101; SC-101; completes within 2 seconds | REQ-101 | incremental/preserve-existing | DESIGN-ADMIN@2 | not-applicable | not-applicable |', $migrationSelectorRow).Replace('| REQ-101 | none | in-progress |', '| REQ-101 | migration-unit:UNIT-ADMIN-LOCK | in-progress |')
 $migrationReview = $canonicalEnvelopeReview.Replace('- Delivery Adapter Kind: none', '- Delivery Adapter Kind: migration-unit').Replace('| WORK-ADMIN-LOCK | ' + $validReviewSource.TaskBaseSha + ' |', '| UNIT-ADMIN-LOCK | ' + $validReviewSource.TaskBaseSha + ' |').Replace('## Architecture Conformance', "$migrationSelectedUnitBlock## Architecture Conformance")
 $migrationImplementationDiagnostics = @(Test-ResponsibilityImplementation -DesignText $validReviewDesign -ImplementationText $migrationImplementation -ContractText $contract)
 if ($migrationImplementationDiagnostics.Count -ne 0) { throw "migration implementation envelope should pass but got: $($migrationImplementationDiagnostics -join '; ')" }
 Write-Output 'PASS: migration implementation preserves canonical Authority@Revision selected row'
 Assert-ReviewAccepted 'migration review preserves the exact implementation selected row and approved selector authority' $migrationReview $validReviewDesign $migrationImplementation $validReviewSource $migrationPlan
 foreach ($lineEndingCase in @(
   [pscustomobject]@{ Name = 'LF'; NewLine = "`n" }
   [pscustomobject]@{ Name = 'CRLF'; NewLine = "`r`n" }
 )) {
@@ -1667,22 +1678,23 @@ foreach ($lineEndingCase in @(
 }
 $staleMigrationImplementationDiagnostics = @(Test-ResponsibilityImplementation -DesignText $validReviewDesign -ImplementationText ($migrationImplementation.Replace('08-migration-plan.md@2', '08-migration-plan.md@1')) -ContractText $contract)
 if ($staleMigrationImplementationDiagnostics -notcontains 'responsibility-evidence-missing') { throw "stale implementation selected plan reference should be rejected but got: $($staleMigrationImplementationDiagnostics -join '; ')" }
 Write-Output 'PASS: migration implementation rejects stale selected Plan Reference'
 Assert-ReviewRejected 'migration review rejects a selected Plan Reference mismatch' ($migrationReview.Replace('08-migration-plan.md@2', '08-migration-plan.md@1')) 'responsibility-evidence-missing' -ImplementationText $migrationImplementation -ApprovedPlanText $migrationPlan
 
 $approvedMigrationReview = $migrationReview.Replace('status: draft', "status: approved`napproval_source: human")
 $migrationVerification = @"
 ---
 step_id: 12-verification-testing
-status: draft
+status: approved
 result: complete
+approval_source: human
 produced_at: 2026-08-21
 responsibility_contract:
   version: 1
   applicability: required
 ---
 
 ## Master Scope Context
 
 | Run ID | Master Spec Reference | Master Spec ID | Master Spec Revision | Master Plan Reference | Master Plan ID | Master Plan Revision | Work Item ID |
 |---|---|---|---|---|---|---|---|
@@ -1770,20 +1782,24 @@ Assert-ReviewAccepted 'review scopes planned owners and verification to the sele
 $foreignOwnerReference = $validImplementation.Replace('| WORK-ADMIN-LOCK | DESIGN-ADMIN@2 | RESP-WIFI, RESP-WIRED | RESP-LOCK-GUARD | RESP-LOCK-COMPOSITION |', '| WORK-OTHER | DESIGN-ADMIN@2 | RESP-WIFI, RESP-WIRED | RESP-LOCK-GUARD | RESP-LOCK-COMPOSITION |')
 Assert-ReviewRejected 'review owner references bind the exact current work item provenance' $multiWorkItemReview 'responsibility-evidence-missing' -DesignText $multiWorkItemDesign -ImplementationText $foreignOwnerReference
 
 $unchangedSelectedSource = New-ResponsibilityReviewSourceFixture
 $unchangedTaskBaseSha = $unchangedSelectedSource.FinalTreeSha
 Set-Content -Encoding utf8 -LiteralPath (Join-Path $unchangedSelectedSource.Root 'notes.txt') -Value 'unrelated final-tree change'
 Invoke-ReviewSourceGit $unchangedSelectedSource.Root @('add', '--', 'notes.txt') | Out-Null
 Invoke-ReviewSourceGit $unchangedSelectedSource.Root @('commit', '-m', 'unrelated final-tree change') | Out-Null
 $unchangedSelectedSource = [pscustomobject]@{ Root = $unchangedSelectedSource.Root; TaskBaseSha = $unchangedTaskBaseSha; FinalTreeSha = (Invoke-ReviewSourceGit $unchangedSelectedSource.Root @('rev-parse', 'HEAD')) }
 $unchangedImplementation = New-ResponsibilityImplementationFixture -TaskBaseSha $unchangedSelectedSource.TaskBaseSha -FinalTreeSha $unchangedSelectedSource.FinalTreeSha
+$unchangedHygieneRow = "| WORK-ADMIN-LOCK | notes.txt | new | documentation note | none | none | none | $($unchangedSelectedSource.TaskBaseSha) | $($unchangedSelectedSource.FinalTreeSha) |"
+$updatedUnchangedImplementation = [regex]::Replace($unchangedImplementation, '(?ms)(^## Change Hygiene\r?\n\r?\n\| Task / Unit \| File \| File Kind \| Edited Region / Symbol \| Formatter Command \| Unrelated Diff \| Checkpoint History \| Task-base SHA \| Final-tree SHA \|\r?\n\|---\|---\|---\|---\|---\|---\|---\|---\|---\|\r?\n)(?:\| WORK-ADMIN-LOCK \| (?:ui|lib)/[^\r\n]+\r?\n?)+', "`$1$unchangedHygieneRow`n")
+if ($updatedUnchangedImplementation -ceq $unchangedImplementation) { throw 'Unchanged selected-owner Change Hygiene fixture replacement failed' }
+$unchangedImplementation = $updatedUnchangedImplementation
 $unchangedReview = New-ResponsibilityReviewFixture -PinnedSource $unchangedSelectedSource
 $unchangedSourceOnlyReview = [regex]::Replace($unchangedReview, '; diff:[0-9a-f]{40}\.\.[0-9a-f]{40}:[^#;\r\n]+#[A-Za-z][A-Za-z0-9_.:-]*', '')
 Assert-ReviewAccepted 'review loads unchanged selected owners from pinned final-tree source evidence without fabricated diff anchors' $unchangedSourceOnlyReview $validReviewDesign $unchangedImplementation $unchangedSelectedSource
 Assert-ReviewRejected 'review rejects fabricated diff anchors for unchanged selected owner paths' $unchangedReview 'responsibility-evidence-missing' -DesignText $validReviewDesign -ImplementationText $unchangedImplementation -PinnedSource $unchangedSelectedSource
 $foreignShaDiffReview = $unchangedSourceOnlyReview.Replace("source:$($unchangedSelectedSource.FinalTreeSha):ui/admin_wifi.dart#AdminWifi", "source:$($unchangedSelectedSource.FinalTreeSha):ui/admin_wifi.dart#AdminWifi; diff:3333333333333333333333333333333333333333..4444444444444444444444444444444444444444:ui/admin_wifi.dart#AdminWifi")
 Assert-ReviewRejected 'review rejects foreign-SHA diff anchors for unchanged selected owner paths' $foreignShaDiffReview 'responsibility-evidence-missing' -DesignText $validReviewDesign -ImplementationText $unchangedImplementation -PinnedSource $unchangedSelectedSource
 Remove-Item -LiteralPath $unchangedSelectedSource.Root -Recurse -Force
 
 Remove-Item -LiteralPath $validReviewSource.Root -Recurse -Force
 
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-handoff.Tests.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-handoff.Tests.ps1
index 738fc01..6f9f717 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-handoff.Tests.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-handoff.Tests.ps1
@@ -71,27 +71,41 @@ function New-HandoffArtifact {
     [string]$Status = 'approved',
     [string]$Result = 'complete',
     [string]$ApprovalSource = 'human',
     [string]$RunId = 'RUN-HANDOFF-001',
     [string]$MasterSpecReference = 'master-spec.md',
     [string]$MasterSpecId = 'SPEC-HANDOFF-001',
     [string]$MasterPlanReference = 'master-plan.md',
     [string]$MasterPlanId = 'PLAN-HANDOFF-001',
     [string]$AdapterKind = 'migration-unit',
     [switch]$OmitSelectedMigrationUnit,
+    [string]$ReviewVerdict = 'Approve',
+    [int]$CriticalCount = 0,
     [string]$Waiver = ''
   )
 
   if ($TaskUnit -eq '') { $TaskUnit = if ($AdapterKind -ceq 'migration-unit') { 'UNIT-ADMIN-LOCK' } else { $WorkItemId } }
   if ($Evidence -eq '') { $Evidence = "source-diff:$TaskBaseSha..$FinalTreeSha#$WorkItemId" }
   $waiverText = if ($Waiver -eq '') { '' } else { "`n$Waiver" }
   $approvalText = if ($ApprovalSource -eq '') { '' } else { "approval_source: $ApprovalSource`n" }
+  $reviewConclusionText = if ($StepId -ceq '11-ai-review') {
+@"
+## Critical
+| File:line | Issue | Proposed fix |
+|---|---|---|
+
+## Conclusion
+- Critical count: $CriticalCount
+- Verdict: $ReviewVerdict
+
+"@
+  } else { '' }
   $selectedUnitText = if ($AdapterKind -eq 'migration-unit' -and -not $OmitSelectedMigrationUnit) {
 @"
 ## Selected Migration Unit
 
 | Migration Unit ID | Plan Reference | Approval Reference | Mode Constraint | Bootstrap Scope | Foundation Baseline ID | Foundation Baseline Reference | Foundation Baseline Approval Reference | Baseline Reference | Trace IDs |
 |---|---|---|---|---|---|---|---|---|---|
 | UNIT-ADMIN-LOCK | 08-migration-plan.md@1 | approval:UNIT-ADMIN-LOCK | incremental/preserve-existing | not-required | not-applicable | not-applicable | not-applicable | baseline.md#BASE-ADMIN | REQ-001 |
 
 "@
   } else { '' }
@@ -120,20 +134,21 @@ responsibility_contract:
 | Task / Unit | Task-base SHA | Final-tree SHA | Source Artifact |
 |---|---|---|---|
 | $TaskUnit | $TaskBaseSha | $FinalTreeSha | $SourceArtifact |
 
 $selectedUnitText
 ## Architecture Responsibility Handoff
 
 | Responsibility Contract Version | Tree Conformance | Responsibility Conformance | Verification Ownership | Architecture Conformance State | Evidence References |
 |---|---|---|---|---|---|
 | 1 | $Tree | $Responsibility | $Verification | $Architecture | $Evidence |
+$reviewConclusionText
 $waiverText
 "@
 }
 
 function New-ApprovedAdapterPlan {
   param(
     [ValidateSet('migration-unit','task','story','package','phase','milestone')][string]$AdapterKind = 'migration-unit',
     [string]$WorkItemId = 'WORK-ADMIN-LOCK',
     [string]$SelectorApproval = 'approval:UNIT-ADMIN-LOCK',
     [string]$SelectorTraceIds = 'REQ-001',
@@ -212,48 +227,54 @@ function New-ProducerReviewArtifact {
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
+    '- Verdict: <Approve | Approve-with-fixes | Reject>' = '- Verdict: Approve'
   }
   foreach ($token in $replacements.Keys) {
     $updated = $text.Replace($token, $replacements[$token])
     if ($updated -ceq $text) { throw "Migration review producer template is missing seam token: $token" }
     $text = $updated
   }
+  $renderedCriticalCount = [regex]::Replace($text, '(?m)^- \*\*Critical count:\*\*[^\r\n]*\r?$', '- **Critical count:** 0', 1)
+  if ($renderedCriticalCount -ceq $text) { throw 'Migration review producer template is missing Critical count seam' }
+  $text = $renderedCriticalCount
   $renderedSelectedUnit = [regex]::Replace($text, '(?m)^\| <UNIT-001> \|.*$', '| UNIT-ADMIN-LOCK | 08-migration-plan.md@1 | approval:UNIT-ADMIN-LOCK | incremental/preserve-existing | not-required | not-applicable | not-applicable | not-applicable | baseline.md#BASE-ADMIN | REQ-001 |', 1)
   if ($renderedSelectedUnit -ceq $text) { throw 'Migration review producer template is missing selected-unit row seam' }
   $text = $renderedSelectedUnit
   return $text
 }
 
 function New-ProducerKnowledgeBaseArtifact {
   param(
     [ValidateSet('migration-unit','task','none')][string]$AdapterKind = 'migration-unit',
     [string]$WorkItemId = 'WORK-ADMIN-LOCK',
     [string]$SourceArtifact = '14-regression-report.md',
     [string]$TaskBaseSha = '1111111111111111111111111111111111111111',
     [string]$FinalTreeSha = '2222222222222222222222222222222222222222'
   )
 
   $taskUnit = if ($AdapterKind -ceq 'migration-unit') { 'UNIT-ADMIN-LOCK' } else { $WorkItemId }
   $text = Get-Content -Raw -Encoding utf8 -LiteralPath $knowledgeBaseTemplatePath
   $replacements = [ordered]@{
     'step_id: <orchestrator-provided-step-id>' = 'step_id: 15-knowledge-base'
     'status: draft' = 'status: approved'
+    'result: <complete | partial | blocked>' = 'result: complete'
     '# Chỉ migration: thêm `result: complete | partial | blocked`' = 'result: complete'
     'produced_at: <yyyy-mm-dd>' = 'produced_at: 2026-08-20'
+    'approval_source: <human | auto | auto-waive>' = 'approval_source: human'
     '| <RUN-*> | <master spec reference> | <SPEC-*> | <revision> | <master plan reference> | <PLAN-*> | <revision> | <WORK-*> |' = "| RUN-HANDOFF-001 | master-spec.md | SPEC-HANDOFF-001 | 1 | master-plan.md | PLAN-HANDOFF-001 | 1 | $WorkItemId |"
     '- Delivery Adapter Kind: <migration-unit | task | story | package | phase | milestone | none>' = "- Delivery Adapter Kind: $AdapterKind"
     '| <task or UNIT-###> | <sha> | <sha> | <terminal verification artifact> |' = "| $taskUnit | $TaskBaseSha | $FinalTreeSha | $SourceArtifact |"
     '| 1 | PASS | PASS | PASS | PASS | review-report.md#responsibility-evidence |' = "| 1 | PASS | PASS | PASS | PASS | source-diff:$TaskBaseSha..$FinalTreeSha#$WorkItemId |"
   }
   foreach ($token in $replacements.Keys) {
     $updated = $text.Replace($token, $replacements[$token])
     if ($updated -cne $text) { $text = $updated }
   }
   if ($AdapterKind -ceq 'migration-unit') {
@@ -346,54 +367,56 @@ $noneSelectorGenericPlan = $genericPlan.Replace(
 ).Replace('task:TASK-ADMIN-LOCK', 'generic:module-foundation')
 if ($noneSelectorGenericPlan -ceq $genericPlan) { throw 'none-selector generic adapter fixture mutation was a silent no-op' }
 $review = New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md'
 $producerReview = New-ProducerReviewArtifact
 $verification = New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md'
 $producerVerification = New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md' -Evidence 'source-diff:1111111111111111111111111111111111111111..2222222222222222222222222222222222222222#WORK-ADMIN-LOCK' -TaskBaseSha '1111111111111111111111111111111111111111' -FinalTreeSha '2222222222222222222222222222222222222222'
 $parity = New-HandoffArtifact -StepId '13-verify-parity' -SourceArtifact 'verification-report.md'
 $regression = New-HandoffArtifact -StepId '14-verify-regression' -SourceArtifact '13-parity-report.md'
 $knowledgeBase = New-HandoffArtifact -StepId '15-knowledge-base' -SourceArtifact '14-regression-report.md'
 $producerKnowledgeBase = New-ProducerKnowledgeBaseArtifact
-$producerGenericKnowledgeBase = New-ProducerKnowledgeBaseArtifact -AdapterKind task -SourceArtifact '13-parity-report.md'
-$producerNoneKnowledgeBase = New-ProducerKnowledgeBaseArtifact -AdapterKind none -SourceArtifact '13-parity-report.md'
+$producerGenericKnowledgeBase = New-ProducerKnowledgeBaseArtifact -AdapterKind task -SourceArtifact '14-regression-report.md'
+$producerNoneKnowledgeBase = New-ProducerKnowledgeBaseArtifact -AdapterKind none -SourceArtifact '14-regression-report.md'
 
 Assert-HandoffRejected 'migration-unit assurance provenance cannot use Work Item identity' (New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -TaskUnit 'WORK-ADMIN-LOCK') (New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md' -TaskUnit 'WORK-ADMIN-LOCK') 'responsibility-evidence-missing'
 $unitReview = New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -TaskUnit 'UNIT-ADMIN-LOCK'
 $unitVerification = New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md' -TaskUnit 'UNIT-ADMIN-LOCK'
 Assert-HandoffAccepted 'migration-unit assurance provenance binds the approved selected unit identity' $unitReview $unitVerification
 
 foreach ($handoff in @(
   [pscustomobject]@{ Name = 'review to verification'; Source = $review; Target = $verification }
   [pscustomobject]@{ Name = 'verification to parity'; Source = $verification; Target = $parity }
   [pscustomobject]@{ Name = 'parity to regression'; Source = $parity; Target = $regression }
   [pscustomobject]@{ Name = 'regression to knowledge base'; Source = $regression; Target = $knowledgeBase }
 )) {
   Assert-HandoffAccepted "preserves exact responsibility handoff from $($handoff.Name)" $handoff.Source $handoff.Target
 }
 
 Assert-HandoffAccepted 'producer-rendered migration review starts the responsibility handoff chain' $producerReview $producerVerification
 Assert-HandoffAccepted 'producer-rendered terminal Knowledge Base preserves the regression handoff envelope' $regression $producerKnowledgeBase
 $producerGenericParity = New-HandoffArtifact -StepId '13-verify-parity' -SourceArtifact 'verification-report.md' -AdapterKind task
 $producerNoneParity = New-HandoffArtifact -StepId '13-verify-parity' -SourceArtifact 'verification-report.md' -AdapterKind none
-Assert-HandoffAccepted 'producer-rendered generic terminal Knowledge Base omits the selected migration unit' $producerGenericParity $producerGenericKnowledgeBase $genericPlan
-Assert-HandoffAccepted 'producer-rendered none terminal Knowledge Base omits the selected migration unit' $producerNoneParity $producerNoneKnowledgeBase $noneSelectorGenericPlan
+$producerGenericRegression = New-HandoffArtifact -StepId '14-verify-regression' -SourceArtifact '13-parity-report.md' -AdapterKind task
+$producerNoneRegression = New-HandoffArtifact -StepId '14-verify-regression' -SourceArtifact '13-parity-report.md' -AdapterKind none
+Assert-HandoffAccepted 'producer-rendered incremental generic terminal Knowledge Base follows regression and omits the selected migration unit' $producerGenericRegression $producerGenericKnowledgeBase $genericPlan
+Assert-HandoffAccepted 'producer-rendered incremental none terminal Knowledge Base follows regression and omits the selected migration unit' $producerNoneRegression $producerNoneKnowledgeBase $noneSelectorGenericPlan
 $knowledgeBaseEnvelopeCases = @(
   [pscustomobject]@{
     Name = 'migration-unit'; Source = $regression; Target = $producerKnowledgeBase; Plan = $script:migrationPlan; AdapterKind = 'migration-unit'
     CanonicalHeadings = @('Master Scope Context', 'Task Provenance', 'Selected Migration Unit', 'Architecture Responsibility Handoff')
   }
   [pscustomobject]@{
-    Name = 'generic'; Source = $producerGenericParity; Target = $producerGenericKnowledgeBase; Plan = $genericPlan; AdapterKind = 'task'
+    Name = 'generic'; Source = $producerGenericRegression; Target = $producerGenericKnowledgeBase; Plan = $genericPlan; AdapterKind = 'task'
     CanonicalHeadings = @('Master Scope Context', 'Task Provenance', 'Architecture Responsibility Handoff')
   }
   [pscustomobject]@{
-    Name = 'none'; Source = $producerNoneParity; Target = $producerNoneKnowledgeBase; Plan = $noneSelectorGenericPlan; AdapterKind = 'none'
+    Name = 'none'; Source = $producerNoneRegression; Target = $producerNoneKnowledgeBase; Plan = $noneSelectorGenericPlan; AdapterKind = 'none'
     CanonicalHeadings = @('Master Scope Context', 'Task Provenance', 'Architecture Responsibility Handoff')
   }
 )
 $producerH2Headings = @(
   [regex]::Matches($producerKnowledgeBase, '(?m)^## (?<heading>[^\r\n]+?)\r?$') |
     ForEach-Object { $_.Groups['heading'].Value }
 )
 $producerHandoffHeadingIndex = [Array]::IndexOf($producerH2Headings, 'Architecture Responsibility Handoff')
 if ($producerHandoffHeadingIndex -lt 0 -or ($producerHandoffHeadingIndex + 2) -ge $producerH2Headings.Count) {
   throw 'Knowledge Base producer template is missing the real surrounding H2 sections'
@@ -446,57 +469,76 @@ foreach ($lineEnding in @('LF', 'CRLF')) {
           $knowledgeBaseEnvelopeFailures.Add("$name expected exactly [$($mutation.Diagnostic)] but got: [$($diagnostics -join '; ')]")
         }
         else { Write-Output "PASS: $name" }
       }
     }
   }
 }
 if ($knowledgeBaseEnvelopeFailures.Count -ne 0) { throw ($knowledgeBaseEnvelopeFailures -join [Environment]::NewLine) }
 $producerSelectedUnitBlock = Get-ArtifactSectionBlock -Text $producerKnowledgeBase -Heading 'Selected Migration Unit'
 Assert-HandoffDiagnosticsExactly 'producer-rendered migration terminal Knowledge Base cannot omit the selected migration unit' $regression ($producerKnowledgeBase.Replace($producerSelectedUnitBlock, '')) @('ARC-CONTRACT-MISSING-TABLE: Selected Migration Unit')
-Assert-HandoffRejected 'producer-rendered generic terminal Knowledge Base cannot retain the selected migration unit' $producerGenericParity ($producerGenericKnowledgeBase.Replace('## Architecture Responsibility Handoff', "$producerSelectedUnitBlock## Architecture Responsibility Handoff")) 'responsibility-evidence-missing' $genericPlan
-Assert-HandoffRejected 'producer-rendered none terminal Knowledge Base cannot retain the selected migration unit' $producerNoneParity ($producerNoneKnowledgeBase.Replace('## Architecture Responsibility Handoff', "$producerSelectedUnitBlock## Architecture Responsibility Handoff")) 'responsibility-evidence-missing' $noneSelectorGenericPlan
+Assert-HandoffRejected 'producer-rendered generic terminal Knowledge Base cannot retain the selected migration unit' $producerGenericRegression ($producerGenericKnowledgeBase.Replace('## Architecture Responsibility Handoff', "$producerSelectedUnitBlock## Architecture Responsibility Handoff")) 'responsibility-evidence-missing' $genericPlan
+Assert-HandoffRejected 'producer-rendered none terminal Knowledge Base cannot retain the selected migration unit' $producerNoneRegression ($producerNoneKnowledgeBase.Replace('## Architecture Responsibility Handoff', "$producerSelectedUnitBlock## Architecture Responsibility Handoff")) 'responsibility-evidence-missing' $noneSelectorGenericPlan
 $producerScopeBlock = Get-ArtifactSectionBlock -Text $producerKnowledgeBase -Heading 'Master Scope Context'
 $producerProvenanceBlock = Get-ArtifactSectionBlock -Text $producerKnowledgeBase -Heading 'Task Provenance'
 $reorderedProducerKnowledgeBase = $producerKnowledgeBase.Replace("$producerScopeBlock$producerProvenanceBlock", "$producerProvenanceBlock$producerScopeBlock")
 if ($reorderedProducerKnowledgeBase -ceq $producerKnowledgeBase) { throw 'Knowledge Base envelope reorder mutation was a silent no-op' }
 Assert-HandoffRejected 'producer-rendered terminal Knowledge Base rejects reordered canonical envelope sections' $regression $reorderedProducerKnowledgeBase 'responsibility-evidence-missing'
 Assert-HandoffDiagnosticsExactly 'producer-rendered terminal Knowledge Base rejects duplicate canonical envelope sections' $regression ($producerKnowledgeBase.Replace($producerProvenanceBlock, "$producerProvenanceBlock$producerProvenanceBlock")) @('ARC-CONTRACT-HEADING-CARDINALITY: Task Provenance')
 Assert-HandoffDiagnosticsExactly 'producer-rendered terminal Knowledge Base cannot lose Master Scope Context' $regression ($producerKnowledgeBase -replace '(?ms)^## Master Scope Context.*?(?=^## )', '') @('ARC-CONTRACT-MISSING-TABLE: Master Scope Context')
 Assert-HandoffRejected 'producer-rendered terminal Knowledge Base cannot mutate delivery adapter kind' $regression ($producerKnowledgeBase.Replace('- Delivery Adapter Kind: migration-unit', '- Delivery Adapter Kind: task')) 'responsibility-evidence-missing'
 Assert-HandoffRejected 'producer-rendered terminal Knowledge Base cannot bind foreign scope' $regression ($producerKnowledgeBase.Replace('| RUN-HANDOFF-001 | master-spec.md | SPEC-HANDOFF-001 | 1 | master-plan.md | PLAN-HANDOFF-001 | 1 | WORK-ADMIN-LOCK |', '| RUN-HANDOFF-OTHER | master-spec.md | SPEC-HANDOFF-001 | 1 | master-plan.md | PLAN-HANDOFF-001 | 1 | WORK-ADMIN-LOCK |')) 'responsibility-evidence-missing'
 Assert-HandoffDiagnosticsExactly 'producer-rendered terminal Knowledge Base cannot lose task provenance' $regression ($producerKnowledgeBase -replace '(?ms)^## Task Provenance.*?(?=^## )', '') @('ARC-CONTRACT-MISSING-TABLE: Task Provenance')
 Assert-HandoffRejected 'producer-rendered terminal Knowledge Base cannot mutate task provenance' $regression ($producerKnowledgeBase.Replace('| UNIT-ADMIN-LOCK | 1111111111111111111111111111111111111111 | 2222222222222222222222222222222222222222 | 14-regression-report.md |', '| UNIT-ADMIN-LOCK | 1111111111111111111111111111111111111111 | 3333333333333333333333333333333333333333 | 14-regression-report.md |')) 'responsibility-evidence-missing'
 Assert-HandoffRejected 'draft review cannot seed verification' (New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -Status 'draft') $verification 'responsibility-evidence-missing'
 Assert-HandoffRejected 'blocked review cannot seed verification' (New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -Result 'blocked') $verification 'responsibility-evidence-missing'
 Assert-HandoffRejected 'review without approval source cannot seed verification' (New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -ApprovalSource '') $verification 'responsibility-evidence-missing'
 Assert-HandoffRejected 'non-human review cannot seed verification' (New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -ApprovalSource 'auto') $verification 'responsibility-evidence-missing'
+Assert-HandoffRejected 'Reject review conclusion cannot seed verification despite PASS architecture handoff' (New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -ReviewVerdict 'Reject') $verification 'responsibility-waiver-forbidden'
 Assert-HandoffRejected 'conflicting review lifecycle fields cannot seed verification' ($review.Replace('status: approved', "status: approved`nstatus: draft")) $verification 'responsibility-evidence-missing'
+Assert-HandoffRejected 'draft verification cannot seed parity' (New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md' -Status 'draft') $parity 'responsibility-evidence-missing'
+Assert-HandoffRejected 'blocked parity cannot seed incremental regression' (New-HandoffArtifact -StepId '13-verify-parity' -SourceArtifact 'verification-report.md' -Result 'blocked') $regression 'responsibility-evidence-missing'
+Assert-HandoffRejected 'auto-approved regression cannot seed Knowledge Base' (New-HandoffArtifact -StepId '14-verify-regression' -SourceArtifact '13-parity-report.md' -ApprovalSource 'auto') $knowledgeBase 'responsibility-evidence-missing'
+Assert-HandoffRejected 'draft Knowledge Base is not terminal executable assurance' $regression (New-HandoffArtifact -StepId '15-knowledge-base' -SourceArtifact '14-regression-report.md' -Status 'draft') 'responsibility-evidence-missing'
+Assert-HandoffRejected 'downstream assurance front matter rejects an extra top-level key' ((New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md').Replace('produced_at: 2026-08-20', "foreign_run: RUN-OTHER`nproduced_at: 2026-08-20")) $parity 'responsibility-evidence-missing'
 Assert-HandoffRejected 'seven-character provenance cannot seed verification' (New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -TaskBaseSha '1111111' -FinalTreeSha '2222222') (New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md' -TaskBaseSha '1111111' -FinalTreeSha '2222222') 'responsibility-evidence-missing'
 Assert-HandoffRejected 'legacy filename evidence cannot seed verification' (New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -Evidence 'review-report.md#responsibility-evidence') $verification 'responsibility-evidence-missing'
 Assert-HandoffRejected 'same work item and SHAs from another run cannot seed verification' $review (New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md' -RunId 'RUN-HANDOFF-OTHER') 'responsibility-evidence-missing'
 Assert-HandoffDiagnosticsExactly 'migration-unit handoff cannot omit selected unit' $review (New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md' -OmitSelectedMigrationUnit) @('ARC-CONTRACT-MISSING-TABLE: Selected Migration Unit')
 Assert-HandoffRejected 'generic handoff cannot invent selected unit' (New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -AdapterKind 'task') ((New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md' -AdapterKind 'task') + "`n## Selected Migration Unit`n") 'responsibility-evidence-missing'
 $genericReview = New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -AdapterKind 'task'
 $genericVerification = New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md' -AdapterKind 'task'
 $genericParity = New-HandoffArtifact -StepId '13-verify-parity' -SourceArtifact 'verification-report.md' -AdapterKind 'task'
-$genericKnowledgeBase = New-HandoffArtifact -StepId '15-knowledge-base' -SourceArtifact '13-parity-report.md' -AdapterKind 'task'
+$genericRegression = New-HandoffArtifact -StepId '14-verify-regression' -SourceArtifact '13-parity-report.md' -AdapterKind 'task'
+$genericKnowledgeBase = New-HandoffArtifact -StepId '15-knowledge-base' -SourceArtifact '14-regression-report.md' -AdapterKind 'task'
 Assert-HandoffAccepted 'generic adapter review reaches verification without a selected migration unit' $genericReview $genericVerification $genericPlan
 Assert-HandoffAccepted 'generic adapter verification reaches parity without a selected migration unit' $genericVerification $genericParity $genericPlan
-Assert-HandoffAccepted 'generic adapter parity reaches terminal KB without a selected migration unit' $genericParity $genericKnowledgeBase $genericPlan
+Assert-HandoffRejected 'incremental generic adapter cannot skip regression before terminal KB' $genericParity (New-HandoffArtifact -StepId '15-knowledge-base' -SourceArtifact '13-parity-report.md' -AdapterKind 'task') 'responsibility-evidence-missing' $genericPlan
+Assert-HandoffAccepted 'incremental generic adapter parity reaches regression without a selected migration unit' $genericParity $genericRegression $genericPlan
+Assert-HandoffAccepted 'incremental generic adapter regression reaches terminal KB without a selected migration unit' $genericRegression $genericKnowledgeBase $genericPlan
+$genericGreenfieldPlan = New-ApprovedAdapterPlan -AdapterKind task -SelectorApproval 'approval:TASK-ADMIN-LOCK' -SelectorMode 'greenfield/design-new'
+$genericGreenfieldParity = New-HandoffArtifact -StepId '13-verify-parity' -SourceArtifact 'verification-report.md' -AdapterKind 'task'
+$genericGreenfieldKnowledgeBase = New-HandoffArtifact -StepId '15-knowledge-base' -SourceArtifact '13-parity-report.md' -AdapterKind 'task'
+Assert-HandoffAccepted 'greenfield generic adapter may omit regression before terminal KB' $genericGreenfieldParity $genericGreenfieldKnowledgeBase $genericGreenfieldPlan
 $packagePlan = New-ApprovedAdapterPlan -AdapterKind package -SelectorApproval 'approval:PACKAGE-ADMIN-LOCK'
 $packageReview = New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -AdapterKind package
 $packageVerification = New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md' -AdapterKind package
 Assert-HandoffAccepted 'package selector preserves its concrete external authority and Work Item assurance identity' $packageReview $packageVerification $packagePlan
 $noneSelectorReview = New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -AdapterKind 'none'
 $noneSelectorVerification = New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md' -AdapterKind 'none'
 Assert-HandoffAccepted 'none selector retains approved generic delivery adapter with Work Item assurance identity' $noneSelectorReview $noneSelectorVerification $noneSelectorGenericPlan
+$noneSelectorParity = New-HandoffArtifact -StepId '13-verify-parity' -SourceArtifact 'verification-report.md' -AdapterKind 'none'
+$noneSelectorRegression = New-HandoffArtifact -StepId '14-verify-regression' -SourceArtifact '13-parity-report.md' -AdapterKind 'none'
+$noneSelectorKnowledgeBase = New-HandoffArtifact -StepId '15-knowledge-base' -SourceArtifact '14-regression-report.md' -AdapterKind 'none'
+Assert-HandoffRejected 'incremental none adapter cannot skip regression before terminal KB' $noneSelectorParity (New-HandoffArtifact -StepId '15-knowledge-base' -SourceArtifact '13-parity-report.md' -AdapterKind 'none') 'responsibility-evidence-missing' $noneSelectorGenericPlan
+Assert-HandoffAccepted 'incremental none adapter parity reaches regression' $noneSelectorParity $noneSelectorRegression $noneSelectorGenericPlan
+Assert-HandoffAccepted 'incremental none adapter regression reaches terminal KB' $noneSelectorRegression $noneSelectorKnowledgeBase $noneSelectorGenericPlan
 $parentChildPlan = New-ParentChildAdapterPlan
 $parentChildReview = New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -AdapterKind story -WorkItemId 'WORK-ADMIN-CHILD'
 $parentChildVerification = New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md' -AdapterKind story -WorkItemId 'WORK-ADMIN-CHILD'
 Assert-HandoffAccepted 'generic child handoff resolves exact parent selector from the whole approved plan' $parentChildReview $parentChildVerification $parentChildPlan
 $caseDistinctSelectorPlan = $parentChildPlan.Replace('| story | STORY-ADMIN-CHILD |', '| story | task-admin-parent |').Replace('story:STORY-ADMIN-CHILD', 'story:task-admin-parent')
 if ($caseDistinctSelectorPlan -ceq $parentChildPlan) { throw 'case-distinct downstream selector fixture mutation was a silent no-op' }
 Assert-HandoffAccepted 'generic child handoff preserves case-only distinct canonical selector identities' $parentChildReview $parentChildVerification $caseDistinctSelectorPlan
 Assert-HandoffRejected 'generic child handoff rejects a missing parent selector' $parentChildReview $parentChildVerification 'responsibility-evidence-missing' ($parentChildPlan.Replace('| approval:STORY-ADMIN-CHILD | TASK-ADMIN-PARENT |', '| approval:STORY-ADMIN-CHILD | not-applicable |'))
 Assert-HandoffRejected 'generic child handoff rejects a foreign parent selector' $parentChildReview $parentChildVerification 'responsibility-evidence-missing' ($parentChildPlan.Replace('| approval:STORY-ADMIN-CHILD | TASK-ADMIN-PARENT |', '| approval:STORY-ADMIN-CHILD | STORY-ADMIN-CHILD |'))
 Assert-HandoffRejected 'generic child handoff rejects a case-only parent selector mismatch' $parentChildReview $parentChildVerification 'responsibility-evidence-missing' ($parentChildPlan.Replace('| approval:STORY-ADMIN-CHILD | TASK-ADMIN-PARENT |', '| approval:STORY-ADMIN-CHILD | task-admin-parent |'))
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/scope-engine.Tests.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/scope-engine.Tests.ps1
index aab6d7b..57fd23b 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/scope-engine.Tests.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/scope-engine.Tests.ps1
@@ -1011,20 +1011,34 @@ foreach ($lifecycleMutation in @(
   $lifecycleCompletion = Invoke-ScopeScenario @{
     scenario_type = 'scope-engine'; operation = 'complete-scope'
     work_items = @($completeItem)
     terminal_artifacts = @($lifecycleTerminal)
     responsibility_chain_artifacts = @($lifecycleChain.Artifacts)
     terminal_scope_report = (New-TerminalScopeReport "runs/scope-terminal-lifecycle-$($lifecycleMutation.Name).md" @($completeItem) @($lifecycleChain))
   }
   Assert-Equal $lifecycleCompletion.scope_status 'scope-blocked' "Initial review $($lifecycleMutation.Name) must be approved/complete/human"
 }
 
+foreach ($chainIndex in 1..4) {
+  $downstreamLifecycleChain = New-ResponsibilityChain "runs/downstream-lifecycle-$chainIndex-chain" $completeItem.work_item_id
+  $downstreamLifecycleChain.Artifacts[$chainIndex].status = 'draft'
+  $downstreamLifecycleTerminal = New-TerminalResponsibilityArtifact $completeItem.terminal_evidence $completeItem.work_item_id $completeItem.status $downstreamLifecycleChain.FinalReference $downstreamLifecycleChain.References $downstreamLifecycleChain.ModeConstraint
+  $downstreamLifecycleCompletion = Invoke-ScopeScenario @{
+    scenario_type = 'scope-engine'; operation = 'complete-scope'
+    work_items = @($completeItem)
+    terminal_artifacts = @($downstreamLifecycleTerminal)
+    responsibility_chain_artifacts = @($downstreamLifecycleChain.Artifacts)
+    terminal_scope_report = (New-TerminalScopeReport "runs/scope-terminal-downstream-lifecycle-$chainIndex.md" @($completeItem) @($downstreamLifecycleChain))
+  }
+  Assert-Equal $downstreamLifecycleCompletion.scope_status 'scope-blocked' "Every downstream assurance chain node $chainIndex must be approved/complete/human"
+}
+
 $sourceDiffMismatchChain = New-ResponsibilityChain 'runs/source-diff-mismatch-chain' $completeItem.work_item_id
 foreach ($artifact in @($sourceDiffMismatchChain.Artifacts)) {
   $artifact.evidence_reference = "source-diff:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa..bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb#$($completeItem.work_item_id)"
 }
 $sourceDiffMismatchTerminal = New-TerminalResponsibilityArtifact $completeItem.terminal_evidence $completeItem.work_item_id $completeItem.status $sourceDiffMismatchChain.FinalReference $sourceDiffMismatchChain.References $sourceDiffMismatchChain.ModeConstraint
 $sourceDiffMismatchCompletion = Invoke-ScopeScenario @{
   scenario_type = 'scope-engine'; operation = 'complete-scope'
   work_items = @($completeItem)
   terminal_artifacts = @($sourceDiffMismatchTerminal)
   responsibility_chain_artifacts = @($sourceDiffMismatchChain.Artifacts)
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/target-conformance.Tests.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/target-conformance.Tests.ps1
index ff5fceb..649e0e4 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/target-conformance.Tests.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/target-conformance.Tests.ps1
@@ -1,17 +1,38 @@
 $ErrorActionPreference = 'Stop'
 
 $toolkitRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
 $contractPath = Join-Path $toolkitRoot 'contracts/target-structure-conformance.md'
 $scopeContractPath = Join-Path $toolkitRoot 'contracts/migration-scope-orchestration.md'
 $validatorPath = Join-Path $toolkitRoot 'tests/validation/target-conformance.validation.ps1'
 $contractText = Get-Content -Raw -Encoding utf8 -LiteralPath $contractPath
+
+function Get-CanonicalDiscoveryContract([string]$Text) {
+  $canonicalHeader = '| Concern | Path | Inspected Symbols | Observed Pattern | Primary Responsibility | Owned Capabilities | Verification Owner | Comparable Reason | Evidence | Inspection Status | Classification | Classification Authority | Classification Evidence |'
+  if ($Text.Contains($canonicalHeader)) { return $Text }
+  $legacyHeader = '| Concern | Path | Inspected Symbols | Observed Pattern | Comparable Reason | Evidence | Status |'
+  $legacyRow = '| applicable structural concern | real target path | fully inspected symbols | observed working pattern | why the exemplar is comparable | exact evidence reference | exemplar status |'
+  $canonicalRow = '| applicable structural concern | real target path | fully inspected symbols | observed working pattern | concrete reason-to-change | CAP-EXAMPLE | VERIFY-OWNER-EXAMPLE | why the exemplar is comparable | exact evidence reference | verified | preferred | factual-discovery-evidence | working-evidence:target/example.dart#Example |'
+  $updated = $Text.Replace($legacyHeader, $canonicalHeader).Replace($legacyRow, $canonicalRow)
+  if ($updated -ceq $Text) { throw 'Canonical discovery contract fixture replacement was a silent no-op' }
+  return $updated.Replace('Exemplar status: `verified | no-equivalent | unknown`.', 'Inspection Status: `verified | no-equivalent | unknown`. Classification: `preferred | compatibility-only | legacy-debt | no-equivalent`.')
+}
+
+function Get-LegacySevenColumnDiscoveryContract([string]$Text) {
+  $canonicalHeader = '| Concern | Path | Inspected Symbols | Observed Pattern | Primary Responsibility | Owned Capabilities | Verification Owner | Comparable Reason | Evidence | Inspection Status | Classification | Classification Authority | Classification Evidence |'
+  $canonicalRow = '| applicable structural concern | real target path | fully inspected symbols | observed working pattern | concrete reason-to-change | CAP-EXAMPLE | VERIFY-OWNER-EXAMPLE | why the exemplar is comparable | exact evidence reference | verified | preferred | factual-discovery-evidence | working-evidence:target/example.dart#Example |'
+  $legacyHeader = '| Concern | Path | Inspected Symbols | Observed Pattern | Comparable Reason | Evidence | Status |'
+  $legacyRow = '| applicable structural concern | real target path | fully inspected symbols | observed working pattern | why the exemplar is comparable | exact evidence reference | exemplar status |'
+  $updated = $Text.Replace($canonicalHeader, $legacyHeader).Replace($canonicalRow, $legacyRow)
+  if ($updated -ceq $Text) { throw 'Legacy discovery contract fixture replacement was a silent no-op' }
+  return $updated
+}
 $scopeContractText = Get-Content -Raw -Encoding utf8 -LiteralPath $scopeContractPath
 
 function Require-Token([string]$Text, [string]$Token, [string]$Context) {
   if ($Text -notmatch [regex]::Escape($Token)) {
     $script:errors.Add("$Context missing: $Token")
   }
 }
 
 function Test-MarkdownTableExactColumns {
   param(
@@ -913,25 +934,27 @@ function Invoke-ConformanceCase {
       'comma-acceptance', 'missing-acceptance-outcome', 'missing-acceptance-trace',
       'malformed-acceptance-reference',
       'stale-adapter', 'stale-approval', 'stale-approval-status', 'stale-revision-approval',
       'decomposition', 'missing-decomposition', 'stale-decomposition',
       'duplicate-decomposition', 'wrong-decomposition-parent', 'unexpected-decomposition'
     )]
     [string]$PlanFixture = 'approved',
     [string]$PlanAcceptanceOverride = '',
     [ValidateSet('incremental','greenfield')][string]$ApprovedMode = 'incremental',
     [switch]$OmitModeAuthority,
-    [scriptblock]$ModeAuthorityMutation
+    [scriptblock]$ModeAuthorityMutation,
+    [string]$ContractOverride = $contractText
   )
 
   $scenarioRoot = New-ScenarioRoot -ApprovedMode $ApprovedMode -OmitModeAuthority:$OmitModeAuthority
   try {
+    Set-Content -Encoding utf8 -LiteralPath (Join-Path $scenarioRoot 'contracts/target-structure-conformance.md') -Value $ContractOverride
     if (-not [string]::IsNullOrWhiteSpace($DiscoveryText)) {
       Set-Content -Encoding utf8 -LiteralPath (Join-Path $scenarioRoot '02-discovery.md') -Value $DiscoveryText
     }
     if (-not [string]::IsNullOrWhiteSpace($DesignText)) {
       if ([string]::IsNullOrWhiteSpace($DiscoveryText)) {
         $DiscoveryText = New-DiscoveryArtifact
         Set-Content -Encoding utf8 -LiteralPath (Join-Path $scenarioRoot '02-discovery.md') -Value $DiscoveryText
       }
       Set-Content -Encoding utf8 -LiteralPath (Join-Path $scenarioRoot '07-technical-design.md') -Value $DesignText
       if ($PlanFixture -cne 'missing') {
@@ -981,21 +1004,21 @@ function Invoke-ConformanceCase {
           default { New-MasterPlanArtifact }
           }
         }
         Set-Content -Encoding utf8 -LiteralPath (Join-Path $scenarioRoot 'master-plan.md') -Value $masterPlanText
       }
     }
 
     if ($null -ne $ModeAuthorityMutation) { & $ModeAuthorityMutation $scenarioRoot }
 
     $script:errors = [Collections.Generic.List[string]]::new()
-    Test-TargetConformance $scenarioRoot $contractText
+    Test-TargetConformance $scenarioRoot $ContractOverride
 
     if ($ShouldPass -and $script:errors.Count -gt 0) {
       throw "$Name should pass but failed: $($script:errors -join '; ')"
     }
     if (-not $ShouldPass -and $script:errors.Count -eq 0) {
       throw "$Name should fail but passed"
     }
     if (-not $ShouldPass -and -not [string]::IsNullOrWhiteSpace($ExpectedError)) {
       $matchingError = @($script:errors | Where-Object { $_ -match [regex]::Escape($ExpectedError) })
       if ($matchingError.Count -eq 0) {
@@ -1004,20 +1027,33 @@ function Invoke-ConformanceCase {
     }
     Write-Output "PASS: $Name"
   }
   finally {
     if (Test-Path -LiteralPath $scenarioRoot) {
       Remove-Item -LiteralPath $scenarioRoot -Recurse -Force
     }
   }
 }
 
+Invoke-ConformanceCase `
+  -Name 'canonical 13-column discovery producer composes with target contract authority' `
+  -DiscoveryText (New-DiscoveryArtifact) `
+  -ShouldPass $true `
+  -ContractOverride (Get-CanonicalDiscoveryContract $contractText)
+
+Invoke-ConformanceCase `
+  -Name 'legacy seven-column contract cannot coexist with the canonical discovery producer' `
+  -DiscoveryText (New-DiscoveryArtifact) `
+  -ShouldPass $false `
+  -ExpectedError 'Comparable Target Exemplars table columns must be exactly' `
+  -ContractOverride (Get-LegacySevenColumnDiscoveryContract $contractText)
+
 Invoke-ConformanceCase `
   'discovery rejects generic controller-only evidence' `
   (New-DiscoveryArtifact -IncludedConcerns @('controller/provider/state pattern')) `
   '' `
   $false `
   'missing applicable concern'
 Invoke-ConformanceCase `
   'discovery rejects one missing concern' `
   (New-DiscoveryArtifact -IncludedConcerns $concerns[0..6]) `
   '' `
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/validate-migration-framework.Tests.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/validate-migration-framework.Tests.ps1
index a3dc74d..bacf071 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/validate-migration-framework.Tests.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/validate-migration-framework.Tests.ps1
@@ -887,23 +887,23 @@ $contractTableCases = @(
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
-    From = '| Concern | Path | Inspected Symbols | Observed Pattern | Comparable Reason | Evidence | Status |'
-    To = '| Concern | Path | Observed Pattern | Inspected Symbols | Comparable Reason | Evidence | Status |'
-    Expected = 'FAIL: Target structure conformance contract Comparable Target Exemplars table columns must be exactly: Concern | Path | Inspected Symbols | Observed Pattern | Comparable Reason | Evidence | Status'
+    From = '| Concern | Path | Inspected Symbols | Observed Pattern | Primary Responsibility | Owned Capabilities | Verification Owner | Comparable Reason | Evidence | Inspection Status | Classification | Classification Authority | Classification Evidence |'
+    To = '| Concern | Inspected Symbols | Path | Observed Pattern | Primary Responsibility | Owned Capabilities | Verification Owner | Comparable Reason | Evidence | Inspection Status | Classification | Classification Authority | Classification Evidence |'
+    Expected = 'FAIL: Target structure conformance contract Comparable Target Exemplars table columns must be exactly: Concern | Path | Inspected Symbols | Observed Pattern | Primary Responsibility | Owned Capabilities | Verification Owner | Comparable Reason | Evidence | Inspection Status | Classification | Classification Authority | Classification Evidence'
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
@@ -937,21 +937,21 @@ $contractTokenCases = @(
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
-  [pscustomobject]@{ Path = $conformanceContractFixture; Bytes = $conformanceContractOriginalBytes; Original = $conformanceContractOriginal; Token = 'Exemplar status: `verified | no-equivalent | unknown`.'; Context = 'Target structure conformance contract' }
+  [pscustomobject]@{ Path = $conformanceContractFixture; Bytes = $conformanceContractOriginalBytes; Original = $conformanceContractOriginal; Token = '`Inspection Status` and `Classification` are independent.'; Context = 'Target structure conformance contract' }
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
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1
index 7375066..5585903 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/responsibility-conformance.validation.ps1
@@ -1335,20 +1335,32 @@ function Test-ResponsibilityImplementation {
 
 function Invoke-ArcPinnedGit {
   [CmdletBinding()]
   param([Parameter(Mandatory)][string]$SourceRoot, [Parameter(Mandatory)][string[]]$Arguments)
 
   $output = @(& git -C $SourceRoot @Arguments 2>$null)
   if ($LASTEXITCODE -ne 0) { throw "Pinned source git command failed: git -C $SourceRoot $($Arguments -join ' ')" }
   return ($output -join [Environment]::NewLine).Trim()
 }
 
+function Test-ArcCanonicalProductionPath {
+  [CmdletBinding()]
+  param([Parameter(Mandatory)][string]$Path)
+
+  # Phase 1 uses repository-relative roots as the language-neutral production
+  # classifier. Tests, docs, tooling, generated output, and repository metadata
+  # remain non-production unless an approved responsibility selects them.
+  $canonicalPath = $Path.Replace('\', '/')
+  return $canonicalPath -cmatch '^(?:(?:src|lib|app|apps/[^/]+/(?:src|lib|app)|packages/[^/]+/(?:src|lib|app)|server|client|frontend|backend)/)' -and
+    $canonicalPath -cnotmatch '(?:^|/)(?:test|tests|spec|specs|docs?|scripts?|tools?|generated|build|dist)(?:/|$)'
+}
+
 function Get-ArcApprovedReviewDesignRevision {
   [CmdletBinding()]
   param([Parameter(Mandatory)][string]$DesignText, [Parameter(Mandatory)][AllowEmptyCollection()][Collections.Generic.List[string]]$Errors)
 
   $frontMatter = Get-ArcBoundedFrontMatter -Text $DesignText
   $revisionMatches = @([regex]::Matches($frontMatter, '(?m)^revision:\s*(?<value>DESIGN-[A-Z0-9]+(?:-[A-Z0-9]+)*@[1-9][0-9]*)\s*$'))
   if (
     @([regex]::Matches($frontMatter, '(?m)^step_id:\s*07-technical-design\s*$')).Count -ne 1 -or
     @([regex]::Matches($frontMatter, '(?m)^status:\s*approved\s*$')).Count -ne 1 -or
     @([regex]::Matches($frontMatter, '(?m)^result:\s*complete\s*$')).Count -ne 1 -or
@@ -1385,27 +1397,29 @@ function Get-ArcImplementationReviewProvenance {
   }
   return [pscustomobject]@{ TaskUnit = $taskUnits[0]; TaskBaseSha = $taskBases[0]; FinalTreeSha = $finalTrees[0]; Rows = $rows }
 }
 
 function Test-ArcDeletedSourceEvidence {
   [CmdletBinding()]
   param(
     [Parameter(Mandatory)][string]$Path,
     [Parameter(Mandatory)][string]$SourceText,
     [Parameter(Mandatory)][string]$DiffText,
+    [string[]]$OwnerIds = @(),
     [Parameter(Mandatory)][AllowEmptyCollection()][Collections.Generic.List[string]]$Errors
   )
 
   $removedDiff = @($DiffText -split '\r?\n' | Where-Object { $_ -cmatch '^-' -and $_ -cnotmatch '^---' }) -join "`n"
   $deletedOwners = [Collections.Generic.List[object]]::new()
   $ownerMatches = @([regex]::Matches($SourceText, '(?ms)^\s*@responsibility\s+(?<id>RESP-[A-Z0-9]+(?:-[A-Z0-9]+)*)\s*$.*?(?=^\s*@responsibility\s+|\z)'))
   foreach ($ownerMatch in $ownerMatches) {
+    if ($OwnerIds.Count -gt 0 -and $OwnerIds -cnotcontains $ownerMatch.Groups['id'].Value) { continue }
     $block = $ownerMatch.Value
     $owner = [pscustomobject]@{
       Id = $ownerMatch.Groups['id'].Value
       Path = $Path
       OwnerSymbols = [Collections.Generic.List[string]]::new()
       Symbols = [Collections.Generic.List[string]]::new()
       Capabilities = [Collections.Generic.List[string]]::new()
       Effects = [Collections.Generic.List[string]]::new()
       ArchitectureAuthorities = [Collections.Generic.List[string]]::new()
       CoLocationPolicies = [Collections.Generic.List[string]]::new()
@@ -1458,29 +1472,56 @@ function Get-ArcPinnedSourceInventory {
 
   if (-not (Test-Path -LiteralPath $SourceRoot -PathType Container) -or $TaskBaseSha -cnotmatch '^[0-9a-f]{40}$' -or $FinalTreeSha -cnotmatch '^[0-9a-f]{40}$') {
     $Errors.Add('responsibility-evidence-missing')
     return @()
   }
   try {
     if ((Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('rev-parse', "$TaskBaseSha^{commit}")) -cne $TaskBaseSha -or (Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('rev-parse', "$FinalTreeSha^{commit}")) -cne $FinalTreeSha) {
       $Errors.Add('responsibility-evidence-missing')
       return @()
     }
-    $changedFinalPaths = @((Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('diff', '--name-only', '--find-renames', '--diff-filter=ACMR', $TaskBaseSha, $FinalTreeSha)) -split '\r?\n' | Where-Object { $_ -ne '' })
-    $deletedPaths = @((Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('diff', '--name-only', '--diff-filter=D', $TaskBaseSha, $FinalTreeSha)) -split '\r?\n' | Where-Object { $_ -ne '' })
+    $nameStatusLines = @((Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('diff', '--name-status', '--find-renames', '--find-copies-harder', '--diff-filter=ACMRD', $TaskBaseSha, $FinalTreeSha, '--')) -split '\r?\n' | Where-Object { $_ -ne '' })
     $finalTreePaths = @((Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('ls-tree', '-r', '--name-only', $FinalTreeSha)) -split '\r?\n' | Where-Object { $_ -ne '' })
   }
   catch {
     $Errors.Add('responsibility-evidence-missing')
     return @()
   }
-  $allChangedPaths = @($changedFinalPaths + $deletedPaths)
+  $changedPathRecords = [Collections.Generic.List[object]]::new()
+  foreach ($line in $nameStatusLines) {
+    $fields = @($line -split "`t")
+    $status = if ($fields.Count -gt 0) { $fields[0] } else { '' }
+    if ($status -cnotmatch '^(?:[AMDC]|R[0-9]{1,3}|C[0-9]{1,3})$') {
+      $Errors.Add('responsibility-evidence-missing')
+      continue
+    }
+    $kind = $status.Substring(0, 1)
+    if (($kind -cin @('R', 'C') -and $fields.Count -ne 3) -or ($kind -cnotin @('R', 'C') -and $fields.Count -ne 2)) {
+      $Errors.Add('responsibility-evidence-missing')
+      continue
+    }
+    $basePath = if ($kind -cin @('R', 'C')) { $fields[1] } elseif ($kind -ceq 'A') { '' } else { $fields[1] }
+    $finalPath = if ($kind -cin @('R', 'C')) { $fields[2] } elseif ($kind -ceq 'D') { '' } else { $fields[1] }
+    $path = if ($kind -ceq 'D') { $basePath } else { $finalPath }
+    $changedPathRecords.Add([pscustomobject]@{
+      Status = $kind
+      RawStatus = $status
+      BasePath = $basePath
+      FinalPath = $finalPath
+      Path = $path
+      FileKind = if ($kind -ceq 'A' -or $kind -ceq 'C') { 'new' } elseif ($kind -ceq 'D') { 'deleted' } else { 'existing' }
+      IsProduction = (Test-ArcCanonicalProductionPath -Path $path)
+    })
+  }
+  $changedFinalPaths = @($changedPathRecords | Where-Object { $_.Status -cne 'D' } | ForEach-Object { $_.FinalPath })
+  $deletedPaths = @($changedPathRecords | Where-Object { $_.Status -ceq 'D' } | ForEach-Object { $_.BasePath })
+  $allChangedPaths = @($changedPathRecords | ForEach-Object { $_.Path })
   $allRequestedPaths = @($allChangedPaths + $SelectedPaths)
   if ($allChangedPaths.Count -eq 0 -or @($allRequestedPaths | Where-Object { $_ -match '^(?:/|[A-Za-z]:|.*(?:^|/)\.\.(?:/|$))' }).Count -gt 0) {
     $Errors.Add('responsibility-evidence-missing')
     return @()
   }
   $selectedFinalPaths = @($SelectedPaths | Where-Object { $finalTreePaths -ccontains $_ })
   $finalPaths = @($changedFinalPaths + $selectedFinalPaths | Select-Object -Unique)
 
   $deletedInventory = [Collections.Generic.List[object]]::new()
   foreach ($path in $deletedPaths) {
@@ -1492,37 +1533,42 @@ function Get-ArcPinnedSourceInventory {
       $Errors.Add('responsibility-evidence-missing')
       continue
     }
     foreach ($owner in @(Test-ArcDeletedSourceEvidence -Path $path -SourceText $deletedSourceText -DiffText $deletedDiffText -Errors $Errors)) {
       $deletedInventory.Add($owner)
     }
   }
 
   $inventory = [Collections.Generic.List[object]]::new()
   foreach ($path in $finalPaths) {
+    $pathRecord = @($changedPathRecords | Where-Object { $_.FinalPath -ceq $path }) | Select-Object -First 1
+    $baseSourceText = ''
     try {
       $sourceText = Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('show', "${FinalTreeSha}:$path")
       $diffText = Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('diff', '--unified=0', $TaskBaseSha, $FinalTreeSha, '--', $path)
+      if ($null -ne $pathRecord -and $pathRecord.BasePath -ne '') {
+        $baseSourceText = Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('show', "${TaskBaseSha}:$($pathRecord.BasePath)")
+      }
     }
     catch {
       $Errors.Add('responsibility-evidence-missing')
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
-          IsChanged = ($changedFinalPaths -ccontains $path)
+          IsChanged = ($null -ne $pathRecord)
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
@@ -1545,32 +1591,77 @@ function Get-ArcPinnedSourceInventory {
       if ($verificationMatch.Success) { $current.VerificationOwners.Add($verificationMatch.Groups['id'].Value); continue }
       $routeMatch = [regex]::Match($line, '^\s*route\s+(?<symbol>[A-Za-z][A-Za-z0-9_.:-]*)\s*->\s*(?<provider>[A-Za-z][A-Za-z0-9_.:-]*)\s*$')
       if ($routeMatch.Success) {
         $current.RouteSymbols.Add($routeMatch.Groups['symbol'].Value)
         $current.Providers.Add($routeMatch.Groups['provider'].Value)
         if (-not $current.Effects.Contains('route registration')) { $current.Effects.Add('route registration') }
       }
     }
     if ($null -ne $current) { $inventory.Add($current) }
     foreach ($owner in @($inventory | Where-Object { $_.Path -ceq $path })) {
+      if ($null -ne $pathRecord -and $pathRecord.Status -cin @('M', 'R') -and $baseSourceText -ne '') {
+        $ownerPattern = '(?ms)^\s*@responsibility\s+' + [regex]::Escape($owner.Id) + '\s*$.*?(?=^\s*@responsibility\s+|\z)'
+        $baseOwnerBlock = [regex]::Match($baseSourceText, $ownerPattern)
+        $finalOwnerBlock = [regex]::Match($sourceText, $ownerPattern)
+        $owner.IsChanged = -not ($baseOwnerBlock.Success -and $finalOwnerBlock.Success -and $baseOwnerBlock.Value.Trim() -ceq $finalOwnerBlock.Value.Trim())
+      }
       $requiresRouteEvidence = $owner.Effects -ccontains 'route registration'
       $addedDiff = @($diffText -split '\r?\n' | Where-Object { $_ -cmatch '^\+' -and $_ -cnotmatch '^\+\+\+' }) -join "`n"
       $ownerAnchors = @($owner.OwnerSymbols + $owner.Symbols + $owner.Capabilities + $owner.VerificationOwners + $owner.RouteSymbols + $owner.Providers | Select-Object -Unique)
       $hasChangedOwnerAnchor = @($ownerAnchors | Where-Object { $addedDiff.IndexOf($_, [StringComparison]::Ordinal) -ge 0 }).Count -gt 0
-      if ($owner.OwnerSymbols.Count -eq 0 -or $owner.Symbols.Count -eq 0 -or $owner.Capabilities.Count -eq 0 -or $owner.ArchitectureAuthorities.Count -eq 0 -or $owner.CoLocationPolicies.Count -eq 0 -or $owner.VerificationOwners.Count -eq 0 -or (($changedFinalPaths -ccontains $path) -and -not $hasChangedOwnerAnchor) -or ($requiresRouteEvidence -and ($owner.RouteSymbols.Count -eq 0 -or $owner.Providers.Count -eq 0 -or @($owner.Symbols | Where-Object { $owner.RouteSymbols -cnotcontains $_ }).Count -gt 0))) {
+      if ($owner.OwnerSymbols.Count -eq 0 -or $owner.Symbols.Count -eq 0 -or $owner.Capabilities.Count -eq 0 -or $owner.ArchitectureAuthorities.Count -eq 0 -or $owner.CoLocationPolicies.Count -eq 0 -or $owner.VerificationOwners.Count -eq 0 -or ($owner.IsChanged -and -not $hasChangedOwnerAnchor) -or ($requiresRouteEvidence -and ($owner.RouteSymbols.Count -eq 0 -or $owner.Providers.Count -eq 0 -or @($owner.Symbols | Where-Object { $owner.RouteSymbols -cnotcontains $_ }).Count -gt 0))) {
         $Errors.Add('responsibility-evidence-missing')
       }
     }
   }
+
+  # A responsibility block removed from an M/R production file is deletion,
+  # even though the file itself survives. Compare immutable pinned contents and
+  # feed only the removed owners through the same deletion reconciliation used
+  # for a whole-file D change.
+  foreach ($record in @($changedPathRecords | Where-Object { $_.Status -cin @('M', 'R') -and $_.BasePath -ne '' -and $_.FinalPath -ne '' })) {
+    try {
+      $baseText = Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('show', "${TaskBaseSha}:$($record.BasePath)")
+      $finalText = Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('show', "${FinalTreeSha}:$($record.FinalPath)")
+      $removedOwnerIds = @([regex]::Matches($baseText, '(?m)^\s*@responsibility\s+(?<id>RESP-[A-Z0-9]+(?:-[A-Z0-9]+)*)\s*$') | ForEach-Object { $_.Groups['id'].Value } | Where-Object {
+        $ownerId = $_
+        @([regex]::Matches($finalText, '(?m)^\s*@responsibility\s+(?<id>RESP-[A-Z0-9]+(?:-[A-Z0-9]+)*)\s*$') | ForEach-Object { $_.Groups['id'].Value }) -cnotcontains $ownerId
+      })
+      if ($removedOwnerIds.Count -gt 0) {
+        $removalDiff = Invoke-ArcPinnedGit -SourceRoot $SourceRoot -Arguments @('diff', '--unified=0', $TaskBaseSha, $FinalTreeSha, '--', $record.BasePath, $record.FinalPath)
+        foreach ($owner in @(Test-ArcDeletedSourceEvidence -Path $record.Path -SourceText $baseText -DiffText $removalDiff -OwnerIds $removedOwnerIds -Errors $Errors)) {
+          $deletedInventory.Add($owner)
+        }
+      }
+    }
+    catch {
+      $Errors.Add('responsibility-evidence-missing')
+    }
+  }
+
+  # Marker presence never defines the inventory boundary. Canonically
+  # production-classified changed paths must expose at least one active or
+  # deleted responsibility after the pinned base/final comparison.
+  foreach ($record in @($changedPathRecords | Where-Object { $_.IsProduction })) {
+    $hasOwner = if ($record.Status -ceq 'D') {
+      @($deletedInventory | Where-Object { $_.Path -ceq $record.Path }).Count -gt 0
+    }
+    else {
+      @($inventory | Where-Object { $_.Path -ceq $record.FinalPath }).Count -gt 0 -or
+        @($deletedInventory | Where-Object { $_.Path -ceq $record.Path }).Count -gt 0
+    }
+    if (-not $hasOwner) { $Errors.Add('responsibility-evidence-missing') }
+  }
   return [pscustomobject]@{
     ActiveOwners = $inventory.ToArray()
     DeletedOwners = $deletedInventory.ToArray()
+    ChangedPaths = $changedPathRecords.ToArray()
   }
 }
 
 function Test-ArcPinnedVerificationOwnershipEvidence {
   [CmdletBinding()]
   param(
     [Parameter(Mandatory)][hashtable]$VerificationRow,
     [Parameter(Mandatory)][string]$SourceRoot,
     [Parameter(Mandatory)][string]$FinalTreeSha,
     [Parameter(Mandatory)][hashtable]$ProductionOwnersById,
@@ -1834,20 +1925,39 @@ function Test-ResponsibilityReview {
   }
   if ($ownerReferenceRows[0]['Work Item ID'] -cne $reviewScope['Work Item ID']) {
     $errors.Add('responsibility-evidence-missing')
     return @($errors | Select-Object -Unique)
   }
   $selectedPaths = @($plannedResponsibilities | ForEach-Object { $_['Owner Path'] } | Select-Object -Unique)
   $sourceInventory = Get-ArcPinnedSourceInventory -SourceRoot $SourceRoot -TaskBaseSha $implementationProvenance.TaskBaseSha -FinalTreeSha $implementationProvenance.FinalTreeSha -SelectedPaths $selectedPaths -Errors $errors
   if ($errors.Count -ne 0 -or $null -eq $sourceInventory) { return @($errors | Select-Object -Unique) }
   $inventory = @($sourceInventory.ActiveOwners)
   $deletedInventory = @($sourceInventory.DeletedOwners)
+  $changedPathRecords = @($sourceInventory.ChangedPaths)
+  foreach ($record in $changedPathRecords) {
+    $matchingHygieneRows = @($implementationProvenance.Rows | Where-Object { $_[1] -ceq $record.Path -and $_[2] -ceq $record.FileKind })
+    if ($matchingHygieneRows.Count -eq 0) { $errors.Add('responsibility-evidence-missing') }
+  }
+  foreach ($row in $implementationProvenance.Rows) {
+    $path = $row[1].Trim()
+    $fileKind = $row[2].Trim()
+    $matchingChanges = @($changedPathRecords | Where-Object { $_.Path -ceq $path -and $_.FileKind -ceq $fileKind })
+    if (
+      $path -cnotmatch '^(?:[A-Za-z0-9_.-]+/)*[A-Za-z0-9_.-]+$' -or
+      $path -match '^(?:/|[A-Za-z]:|.*(?:^|/)\.\.(?:/|$))' -or
+      $fileKind -cnotin @('new', 'existing', 'deleted') -or
+      $matchingChanges.Count -eq 0
+    ) {
+      $errors.Add('responsibility-evidence-missing')
+    }
+  }
+  if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }
   if (($inventory.Count + $deletedInventory.Count) -eq 0) { $errors.Add('responsibility-evidence-missing'); return @($errors | Select-Object -Unique) }
 
   $plannedById = & $toMap $plannedResponsibilities 'Responsibility ID' 'responsibility-owner-extra'
   $implementationById = & $toMap $implementationResponsibilities 'Responsibility ID' 'responsibility-owner-extra'
   $reviewById = & $toMap $reviewRows 'Responsibility ID' 'responsibility-owner-extra'
   $inventoryById = @{}
   foreach ($owner in $inventory) { if ($inventoryById.ContainsKey($owner.Id)) { $errors.Add('responsibility-owner-extra') } else { $inventoryById[$owner.Id] = $owner } }
   $deletedById = @{}
   foreach ($owner in $deletedInventory) {
     if ($deletedById.ContainsKey($owner.Id) -or $inventoryById.ContainsKey($owner.Id)) { $errors.Add('responsibility-owner-extra') } else { $deletedById[$owner.Id] = $owner }
@@ -1929,22 +2039,30 @@ function Test-ResponsibilityReview {
         $_['Tech Lead Approval'] -cmatch '^approval:TECH-LEAD-[A-Z0-9]+(?:-[A-Z0-9]+)*$' -and
         -not [string]::IsNullOrWhiteSpace($_['Concern']) -and
         $decisionMatch.Success -and
         $decisionMatch.Groups['payload'].Value -ceq $expectedDecisionPayload
       })
       if ($approvedRows.Count -ne 1) {
         $errors.Add('responsibility-owner-extra')
         $treePass = $false; $responsibilityPass = $false
       }
 
+      $changedRecord = @($changedPathRecords | Where-Object { $_.Path -ceq $deleted.Path }) | Select-Object -First 1
+      $expectedFileKind = if ($null -eq $changedRecord) { '' } else { $changedRecord.FileKind }
       $hygieneRows = @($implementationProvenance.Rows | Where-Object {
-        $_[1] -ceq $deleted.Path -and $_[2] -ceq 'deleted' -and $_[3] -ceq $ownerSymbols
+        $editedSymbols = @($_[3] -split '[;,]' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
+        $_[1] -ceq $deleted.Path -and
+        $_[2] -ceq $expectedFileKind -and
+        $editedSymbols -ccontains $ownerSymbols -and
+        $_[6] -ceq "source:${TaskBaseSha}:$($deleted.Path); diff:${TaskBaseSha}..${FinalTreeSha}:$($deleted.Path)" -and
+        $_[7] -ceq $TaskBaseSha -and
+        $_[8] -ceq $FinalTreeSha
       })
       if ($hygieneRows.Count -ne 1) {
         $errors.Add('responsibility-evidence-missing')
         $treePass = $false; $responsibilityPass = $false
       }
 
       if (-not $reviewById.ContainsKey($id)) {
         $errors.Add('responsibility-evidence-missing')
         $treePass = $false; $responsibilityPass = $false; $verificationPass = $false
         continue
@@ -1980,29 +2098,32 @@ function Test-ResponsibilityReview {
     if (-not $implementationVerificationById.ContainsKey($id)) { $errors.Add('verification-owner-missing'); $verificationPass = $false; continue }
     $planned = $plannedVerificationById[$id]; $implementation = $implementationVerificationById[$id]
     foreach ($field in $verificationColumns) { if ($planned[$field] -cne $implementation[$field]) { $errors.Add('verification-production-binding-missing'); $verificationPass = $false; break } }
     if ($validVerdicts -cnotcontains $implementation['Verdict'] -or $implementation['Verdict'] -cne 'PASS') { $errors.Add('verification-disposition-invalid'); $verificationPass = $false }
     if (-not (Test-ArcPinnedVerificationOwnershipEvidence -VerificationRow $planned -SourceRoot $SourceRoot -FinalTreeSha $FinalTreeSha -ProductionOwnersById $inventoryById -Errors $errors)) { $verificationPass = $false }
   }
   foreach ($id in $implementationVerificationById.Keys) { if (-not $plannedVerificationById.ContainsKey($id)) { $errors.Add('verification-owner-extra'); $verificationPass = $false } }
 
   $getVerdict = { param([string]$Label) $matches = [regex]::Matches($ReviewText, '(?im)^[ \t]*-[ \t]*(?:\*\*)?' + [regex]::Escape($Label) + '(?:\*\*)?:[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$'); if ($matches.Count -ne 1) { $errors.Add('responsibility-owner-missing'); return '' }; $value = $matches[0].Groups['value'].Value.Trim().Trim([char[]]@('<', '>', '`')); if ($validVerdicts -cnotcontains $value) { $errors.Add('responsibility-owner-extra'); return '' }; return $value }
   $architectureVerdict = & $getVerdict 'Architecture Conformance Verdict'; $treeVerdict = & $getVerdict 'Tree Conformance Verdict'; $responsibilityVerdict = & $getVerdict 'Responsibility Conformance Verdict'; $verificationVerdict = & $getVerdict 'Verification Ownership Verdict'
-  $overallMatches = [regex]::Matches($ReviewText, '(?im)^[ \t]*-[ \t]*(?:\*\*)?Verdict(?:\*\*)?:[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$')
+  $visibleReviewText = Get-ArcVisibleMarkdownText -Text $ReviewText
+  $overallMatches = [regex]::Matches($visibleReviewText, '(?im)^[ \t]*-[ \t]*(?:\*\*)?Verdict(?:\*\*)?:[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$')
   $overallVerdict = if ($overallMatches.Count -eq 1) { $overallMatches[0].Groups['value'].Value.Trim().Trim([char[]]@('<', '>', '`')) } else { $errors.Add('responsibility-owner-missing'); '' }
+  $criticalCountMatches = @([regex]::Matches($visibleReviewText, '(?im)^[ \t]*-[ \t]*(?:\*\*)?Critical count:(?:\*\*)?[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$'))
+  $criticalCount = if ($criticalCountMatches.Count -eq 1 -and $criticalCountMatches[0].Groups['value'].Value.Trim() -cmatch '^[0-9]+$') { [int]$criticalCountMatches[0].Groups['value'].Value.Trim() } else { $errors.Add('responsibility-evidence-missing'); -1 }
   $derivedTree = if ($treePass) { 'PASS' } else { 'BLOCKED' }; $derivedResponsibility = if ($responsibilityPass) { 'PASS' } else { 'BLOCKED' }; $derivedVerification = if ($verificationPass) { 'PASS' } else { 'BLOCKED' }
   if ($treeVerdict -ne '' -and $treeVerdict -cne $derivedTree) { $errors.Add('responsibility-waiver-forbidden') }
   if ($responsibilityVerdict -ne '' -and $responsibilityVerdict -cne $derivedResponsibility) { $errors.Add('responsibility-waiver-forbidden') }
   if ($verificationVerdict -ne '' -and $verificationVerdict -cne $derivedVerification) { $errors.Add('responsibility-waiver-forbidden') }
   $derivedArchitecture = if ($treeVerdict -ceq 'PASS' -and $responsibilityVerdict -ceq 'PASS' -and $verificationVerdict -ceq 'PASS') { 'PASS' } else { 'BLOCKED' }
   if ($architectureVerdict -ne '' -and $architectureVerdict -cne $derivedArchitecture) { $errors.Add('responsibility-waiver-forbidden') }
-  if ($derivedArchitecture -ceq 'BLOCKED' -and $overallVerdict -ne 'Reject') { $errors.Add('responsibility-waiver-forbidden') }
+  if ($derivedArchitecture -ceq 'BLOCKED' -or $overallVerdict -cne 'Approve' -or $criticalCount -ne 0) { $errors.Add('responsibility-waiver-forbidden') }
   return @($errors | Select-Object -Unique)
 }
 
 function Test-ResponsibilityHandoff {
   [CmdletBinding()]
   param([string]$SourceText, [string]$TargetText, [string]$ContractText, [string]$ApprovedPlanText)
 
   $errors = [Collections.Generic.List[string]]::new()
   foreach ($error in @(Test-ArcResponsibilityStageVersion $ContractText 'HANDOFF')) { $errors.Add($error) }
   $columns = @(
@@ -2054,28 +2175,38 @@ function Test-ResponsibilityHandoff {
     $artifact.Provenance = $provenance
     $artifact.Scope = $scope
     $frontMatter = Get-ArcBoundedFrontMatter -Text $Text
     $stepIds = @([regex]::Matches($frontMatter, '(?m)^step_id:\s*(?<value>[^\r\n]+)\s*$'))
     if ($stepIds.Count -ne 1) {
       $errors.Add('responsibility-evidence-missing')
       return $artifact
     }
     $artifact.StepId = $stepIds[0].Groups['value'].Value.Trim()
     $topLevelKeys = @([regex]::Matches($frontMatter, '(?m)^(?<key>[a-z_][a-z0-9_]*):') | ForEach-Object { $_.Groups['key'].Value } | Sort-Object)
-    if ($artifact.StepId -ceq '11-ai-review' -and (
+    if ($artifact.StepId -cin @('11-ai-review', '12-verification-testing', '13-verify-parity', '14-verify-regression', '15-knowledge-base') -and (
       ($topLevelKeys -join '|') -cne 'approval_source|produced_at|responsibility_contract|result|status|step_id' -or
       @([regex]::Matches($frontMatter, '(?m)^status:\s*approved\s*$')).Count -ne 1 -or
       @([regex]::Matches($frontMatter, '(?m)^result:\s*complete\s*$')).Count -ne 1 -or
       @([regex]::Matches($frontMatter, '(?m)^approval_source:\s*human\s*$')).Count -ne 1
     )) { $errors.Add('responsibility-evidence-missing') }
 
     $visibleText = Get-ArcVisibleMarkdownText -Text $Text
+    if ($artifact.StepId -ceq '11-ai-review') {
+      $reviewVerdictMatches = @([regex]::Matches($visibleText, '(?im)^[ \t]*-[ \t]*(?:\*\*)?Verdict(?:\*\*)?:[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$'))
+      $criticalCountMatches = @([regex]::Matches($visibleText, '(?im)^[ \t]*-[ \t]*(?:\*\*)?Critical count:(?:\*\*)?[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$'))
+      if (
+        $reviewVerdictMatches.Count -ne 1 -or
+        $reviewVerdictMatches[0].Groups['value'].Value.Trim() -cne 'Approve' -or
+        $criticalCountMatches.Count -ne 1 -or
+        $criticalCountMatches[0].Groups['value'].Value.Trim() -cne '0'
+      ) { $errors.Add('responsibility-waiver-forbidden') }
+    }
     $adapterMatches = @([regex]::Matches($visibleText, '(?im)^[ \t]*-[ \t]*Delivery Adapter Kind:[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$'))
     if ($adapterMatches.Count -ne 1 -or $adapterMatches[0].Groups['value'].Value.Trim() -cnotin @('migration-unit', 'task', 'story', 'package', 'phase', 'milestone', 'none')) {
       $errors.Add('responsibility-evidence-missing')
     }
     else { $artifact.AdapterKind = $adapterMatches[0].Groups['value'].Value.Trim() }
     if ($errors.Count -ne 0) { $artifact.Row = $null; return $artifact }
     $selectedHeadingCount = @(Get-ArcMarkdownH2HeadingMatches -Text $Text -Heading 'Selected Migration Unit').Count
     if ($artifact.AdapterKind -ceq 'migration-unit') {
       $selectedTable = @(Get-ArcStrictMarkdownTable -Text $Text -Heading 'Selected Migration Unit' -Columns $selectedUnitColumns -Errors $errors)
       if ($errors.Count -ne 0) { $artifact.Row = $null; return $artifact }
@@ -2120,20 +2251,21 @@ function Test-ResponsibilityHandoff {
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
+    if ($artifact.StepId -ceq '11-ai-review' -and $derived -cne 'PASS') { $errors.Add('responsibility-waiver-forbidden') }
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
@@ -2175,20 +2307,21 @@ function Test-ResponsibilityHandoff {
     $planSelections = @(Get-ArcStrictMarkdownTable -Text $ApprovedPlanText -Heading 'Delivery Adapter Selection' -Columns $planSelectionColumns -Errors $errors)
   }
   $workItemColumns = @('Work Item ID', 'Title', 'Required', 'Dependencies', 'Plan Order', 'Acceptance', 'Trace IDs', 'Delivery Adapter', 'Status', 'Latest Attempt', 'Terminal Evidence', 'Approval Reference')
   [object[]]$workItemTable = @()
   if (-not [string]::IsNullOrWhiteSpace($ApprovedPlanText)) {
     $workItemTable = @(Get-ArcStrictMarkdownTable -Text $ApprovedPlanText -Heading 'Work Items' -Columns $workItemColumns -Errors $errors)
   }
   if ($errors.Count -ne 0) { return @($errors | Select-Object -Unique) }
   $planIdMatches = @([regex]::Matches($planFrontMatter, '(?m)^master_plan_id:\s*(?<value>PLAN-[A-Z0-9]+(?:-[A-Z0-9]+)*)\s*$'))
   $planRevisionMatches = @([regex]::Matches($planFrontMatter, '(?m)^revision:\s*(?<value>[1-9][0-9]*)\s*$'))
+  $approvedModeConstraint = ''
   if (
     @([regex]::Matches($planFrontMatter, '(?m)^artifact_type:\s*migration-master-plan\s*$')).Count -ne 1 -or
     @([regex]::Matches($planFrontMatter, '(?m)^status:\s*approved\s*$')).Count -ne 1 -or
     $planIdMatches.Count -ne 1 -or $planRevisionMatches.Count -ne 1 -or $planSelections.Count -lt 3 -or $workItemTable.Count -lt 3 -or
     $planIdMatches[0].Groups['value'].Value -cne $source.Scope['Master Plan ID'] -or
     $planRevisionMatches[0].Groups['value'].Value -cne $source.Scope['Master Plan Revision']
   ) {
     $errors.Add('responsibility-evidence-missing')
   }
   else {
@@ -2277,20 +2410,21 @@ function Test-ResponsibilityHandoff {
         }
       }
       if (-not $candidateImmutableValid) { $errors.Add('responsibility-evidence-missing') }
     }
     $selectionRows = @($allSelectionRows | Where-Object { $_[0] -ceq $source.Scope['Work Item ID'] })
     $workItemRows = @($allWorkItemRows | Where-Object { $_[0] -ceq $source.Scope['Work Item ID'] })
     if ($selectionRows.Count -ne 1 -or $workItemRows.Count -ne 1) { $errors.Add('responsibility-evidence-missing') }
     else {
       $selection = [ordered]@{}
       for ($index = 0; $index -lt $planSelectionColumns.Count; $index++) { $selection[$planSelectionColumns[$index]] = [string]$selectionRows[0][$index] }
+      $approvedModeConstraint = $selection['Mode Constraint']
       $workItem = [ordered]@{}
       for ($index = 0; $index -lt $workItemColumns.Count; $index++) { $workItem[$workItemColumns[$index]] = [string]$workItemRows[0][$index] }
       $selectorAuthorityValid = if ($selection['Adapter Kind'] -ceq 'none') {
         @(@('External ID', 'Authority', 'Authority Revision', 'Approval Reference', 'Parent Selector') | Where-Object { $selection[$_] -cne 'not-applicable' }).Count -eq 0
       }
       else {
         $selection['Adapter Kind'] -cin @('migration-unit', 'task', 'story', 'package', 'phase', 'milestone') -and
         $selection['External ID'] -cmatch '^[A-Za-z0-9][A-Za-z0-9:._/-]*$' -and
         $selection['External ID'] -notmatch '^(?:not-applicable|pending|unknown|placeholder|<[^>]+>)$' -and
         $selection['Authority'] -cmatch '^[A-Za-z0-9][A-Za-z0-9:._/-]*$' -and
@@ -2329,22 +2463,22 @@ function Test-ResponsibilityHandoff {
       $expectedAssuranceIdentity = if ($selection['Adapter Kind'] -ceq 'migration-unit') { $selection['External ID'] } else { $source.Scope['Work Item ID'] }
       if ($source.Provenance['Task / Unit'] -cne $expectedAssuranceIdentity -or $target.Provenance['Task / Unit'] -cne $expectedAssuranceIdentity) {
         $errors.Add('responsibility-evidence-missing')
       }
     }
   }
 
   $allowedNextSteps = @{
     '11-ai-review' = @('12-verification-testing')
     '12-verification-testing' = @('13-verify-parity')
-    '13-verify-parity' = @('14-verify-regression', '15-knowledge-base')
-    '14-verify-regression' = @('15-knowledge-base')
+    '13-verify-parity' = if ($approvedModeConstraint -ceq 'greenfield/design-new') { @('15-knowledge-base') } elseif ($approvedModeConstraint -ceq 'incremental/preserve-existing') { @('14-verify-regression') } else { @() }
+    '14-verify-regression' = if ($approvedModeConstraint -ceq 'incremental/preserve-existing') { @('15-knowledge-base') } else { @() }
   }
   if ($null -eq $allowedNextSteps[$source.StepId] -or $target.StepId -cnotin $allowedNextSteps[$source.StepId]) {
     $errors.Add('responsibility-evidence-missing')
   }
   foreach ($field in @('Task / Unit', 'Task-base SHA', 'Final-tree SHA')) {
     if ($source.Provenance[$field] -cne $target.Provenance[$field]) { $errors.Add('responsibility-evidence-missing') }
   }
   foreach ($field in $scopeColumns) {
     if ($source.Scope[$field] -cne $target.Scope[$field]) { $errors.Add('responsibility-evidence-missing') }
   }
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/scope-engine.validation.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/scope-engine.validation.ps1
index b96c627..fae21c7 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/scope-engine.validation.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/scope-engine.validation.ps1
@@ -847,25 +847,25 @@ function Test-ScopeEngine([string]$Root, [string]$ContractText) {
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
-            ($chainIndex -eq 0 -and (
+            (
               [string]$chainArtifact.status -cne 'approved' -or
               [string]$chainArtifact.result -cne 'complete' -or
               [string]$chainArtifact.approval_source -cne 'human'
-            )) -or
+            ) -or
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
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/target-conformance.validation.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/target-conformance.validation.ps1
index ea06f14..ee6627b 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/target-conformance.validation.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/target-conformance.validation.ps1
@@ -3,32 +3,37 @@ function Test-TargetConformance([string]$Root, [string]$ContractText) {
   if (-not (Test-Path -LiteralPath $contractPath -PathType Leaf)) {
     $errors.Add('Missing target structure conformance contract resource')
     return
   }
   if ([string]::IsNullOrWhiteSpace($ContractText)) {
     $errors.Add('Target structure conformance contract must not be empty')
     return
   }
 
   Test-MarkdownTableExactColumns $ContractText 'Comparable Target Exemplars' `
-    @('Concern', 'Path', 'Inspected Symbols', 'Observed Pattern', 'Comparable Reason', 'Evidence', 'Status') `
+    @(
+      'Concern', 'Path', 'Inspected Symbols', 'Observed Pattern', 'Primary Responsibility',
+      'Owned Capabilities', 'Verification Owner', 'Comparable Reason', 'Evidence',
+      'Inspection Status', 'Classification', 'Classification Authority', 'Classification Evidence'
+    ) `
     'Target structure conformance contract'
   Test-MarkdownTableExactColumns $ContractText 'Target Structure Conformance Matrix' `
     @('Concern', 'Working Exemplar', 'Observed Target Pattern', 'Proposed Path/Symbol', 'Conforms', 'Deviation Reference') `
     'Target structure conformance contract'
   Test-MarkdownTableExactColumns $ContractText 'Assurance State' `
     @('Runtime Evidence State', 'Architecture Conformance State', 'Selector Schema State') `
     'Target structure conformance contract'
 
   @(
     'service/config subscription and normalization',
-    'Exemplar status: `verified | no-equivalent | unknown`.',
+    '`Inspection Status` and `Classification` are independent.',
+    'no seven-column discovery adapter is executable in responsibility contract v1.',
     'A `Conforms = no` row requires a resolved conflict and Tech Lead approval in `Deviation Reference`.',
     'The structural pre-edit gate blocks before target edit and is not waiver-eligible.',
     'runtime_evidence_state: PASS | FAIL | NOT_RUN | WAIVED',
     'architecture_conformance_state: PASS | BLOCKED',
     'selector_schema_state: PASS | BLOCKED',
     'Architecture-first review order: master-scope/work-item alignment -> project rule resolution -> canonical selector -> architecture conformance with matrix/exemplars -> production activation path -> behavior, failure modes, security, performance, and tests -> change hygiene.'
   ) | ForEach-Object {
     Require-Token $ContractText $_ 'Target structure conformance contract'
   }
 

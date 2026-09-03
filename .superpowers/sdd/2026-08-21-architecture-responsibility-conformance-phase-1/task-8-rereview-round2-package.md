# Task 8 fix-round 2 re-review package

BASE: 8c0e78b51e79006867f8f08a4796c44a3242eccf
HEAD: d76a6c11637dcf8e36372c59a547646838356bb7

## Commits
d76a6c1 feat: block terminal scope on responsibility defects

## Stat
 .../aitoolkit/skills/aitoolkit/migrate/SKILL.md    |  36 +-
 .../templates/migration/scope-terminal-report.md   |  16 +-
 .../tests/scenarios/flexible-scope-e2e.Tests.ps1   | 210 +++++++-
 .../scenarios/responsibility-handoff.Tests.ps1     |  70 +++
 .../tests/scenarios/scope-engine.Tests.ps1         | 529 ++++++++++++++++++++-
 .../tests/validate-migration-framework.ps1         | 366 ++++++++++++--
 .../validation/architecture-review.validation.ps1  |  82 ++++
 .../tests/validation/scope-engine.validation.ps1   | 309 +++++++++++-
 8 files changed, 1546 insertions(+), 72 deletions(-)

## Full diff
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/skills/aitoolkit/migrate/SKILL.md b/AIToolkit/AIToolkit-main/aitoolkit/skills/aitoolkit/migrate/SKILL.md
index e0f9eaf..059eead 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/skills/aitoolkit/migrate/SKILL.md
+++ b/AIToolkit/AIToolkit-main/aitoolkit/skills/aitoolkit/migrate/SKILL.md
@@ -42,21 +42,21 @@ Executable input requires explicit `master_spec_ref` and `master_plan_ref` that
 Approved revision là immutable: do not edit an approved master artifact in place. Scope, requirement, success criterion, required disposition, work-item set, dependency, order, acceptance, adapter, selector hoặc structural decision thay đổi phải tạo revision kế tiếp đúng `+1`, giữ stable master ID, trỏ `supersedes` tới immediate predecessor, ghi change summary/affected items, giữ valid completed evidence của item không bị ảnh hưởng và đưa approval của item bị ảnh hưởng về `pending`. Chỉ revision mới đã duyệt được phép tiếp tục mutation.
 
 Every work-item structural change must be declared in `affected_work_items`, including added or removed items, and every affected item in the new revision has `approval_reference: pending`. Structural comparison bao gồm title, required disposition, dependencies, Plan Order, acceptance, trace, adapter và toàn bộ selector fields; revision chain giữ nguyên master-spec/master-plan artifact ID.
 
 Revision comparison includes requested boundary, requirements, success criteria, required disposition and structural decisions, and rejects duplicate current or proposed work-item IDs before map construction. Bất kỳ master-level change nào cũng phải khai affected work items và invalidate approval tương ứng.
 
 Every affected_work_items ID resolves in the current/proposed canonical union; unmappable master-level change conservatively affects every canonical item.
 
 ### Queue, eligibility và deterministic selection
 
-Validate graph trước selection; missing dependency hoặc cycle làm plan invalid và `scope-blocked`. Version đầu giữ `max_concurrency: 1`; nhiều hơn một item `in-progress` là invalid. Công thức eligibility bắt buộc là: required-or-approved-optional AND pending-or-ready AND dependencies-terminal-success AND current approval AND no blocker AND adapter-valid AND assurance-pass. Không có eligible item nhưng còn required blocker thì kết luận `scope-blocked`.
+Validate graph trước selection; missing dependency hoặc cycle làm plan invalid và `scope-blocked`. Version đầu giữ `max_concurrency: 1`; nhiều hơn một item `in-progress` là invalid. Công thức eligibility bắt buộc là: required-or-approved-optional AND pending-or-ready AND dependencies-terminal-success AND current approval AND no blocker AND adapter-valid AND assurance-pass. `assurance-pass` yêu cầu Tree Conformance, Responsibility Conformance, Verification Ownership, derived `architecture_conformance_state`, và `selector_schema_state` đều `PASS`. Không có eligible item nhưng còn required blocker thì kết luận `scope-blocked`, `next eligible item: none`; không chọn dependent item.
 
 Executable operations validate requested scope, then current approved master spec, then current approved linked master plan before queue or transition logic. Gate dùng canonical artifact rows, approval/freshness evidence và executable linear-chain validation; không nhận boolean “approved/current” thay artifact evidence.
 
 Với cùng approved plan revision và evidence state, chọn đúng một item theo dependency depth ascending, then `Plan Order` ascending, then ordinal `Work Item ID` ascending. Không chọn theo folder order, discovery order hoặc lần xuất hiện trong hội thoại.
 
 Queue operations consume exactly the work-item rows bound to the current approved master-plan artifact, never a caller subset or forged queue. Exact bound copy/hash phải gồm toàn bộ required/optional rows và metadata; caller không được thêm, bỏ hoặc thay row cho select, transition hay completion.
 
 Trước selection mới, reconcile an `in-progress` attempt before selecting a new work item. Nếu immutable attempt artifact có terminal evidence hợp lệ, áp dụng missing terminal transition atomically rồi mới select; nếu attempt chưa terminal, resume chính attempt đó. Không brainstorm lại approved scope trừ khi user explicit yêu cầu scope change.
 
 The sole active attempt must belong to the sole in-progress item and equal that item's latest_attempt before resume reconciliation.
@@ -70,45 +70,73 @@ Ngay trước execution, atomically đổi selected item `ready -> in-progress`,
 Selection starts atomically as `pending -> ready -> in-progress` or `ready -> in-progress`. Validate immutable `attempt_history` globally by unique attempt ID, exact `work_item_id`, exact current `plan_revision`, status and artifact reference. Trước start, chặn ID đã xuất hiện ở bất kỳ item history nào và chặn mọi item khác đang `in-progress`; resume/terminal transition phải bind đúng latest attempt record.
 
 Attempt and terminal artifacts resolve from the explicit artifact registry by exact reference and bind immutable status, attempt ID, work-item ID and plan revision. Single-in-progress validation counts both work-item states and every immutable attempt record; native blocker transition targets exactly `latest_attempt`.
 
 Successful completion cần immutable terminal artifact khớp attempt/work item/plan revision. Blocker, cancellation and non-applicability transitions require exact immutable terminal or approval evidence. Không chuyển state chỉ từ boolean, label hoặc caller assertion.
 
 ### Queue continuation và completion
 
 Step 15 completes only the current execution attempt and work item; nó không kết luận module, project hoặc requested scope hoàn tất. Sau atomic work-item transition, tính lại queue trên current approved master-plan revision. Khi còn required item non-terminal, verdict là `scope-in-progress` và tiếp tục deterministic selection mà không hỏi lại soft-scope question.
 
-Only the approved master plan may conclude `scope-complete`, và chỉ sau khi canonical completion formula đạt đủ: mọi required item terminal-success, graph hợp lệ, không blocker, completed-item architecture/selector-schema đều `PASS`, và terminal scope report liệt kê toàn bộ evidence. Attempt completion, work-item completion và requested-scope completion luôn là ba quyết định riêng.
+Only the approved master plan may conclude `scope-complete`, và chỉ sau khi canonical completion formula đạt đủ: mọi required item terminal-success, graph hợp lệ, không blocker, completed-item Tree Conformance, Responsibility Conformance, Verification Ownership, derived architecture và selector-schema đều `PASS`, và terminal scope report liệt kê toàn bộ immutable evidence. Attempt completion, work-item completion và requested-scope completion luôn là ba quyết định riêng.
 
 Scope completion calculates the dependency graph and validates every required terminal-report row; it never trusts caller-provided graph-valid or report-complete booleans. Terminal report phải immutable, có exact work-item status, terminal evidence và assurance fields khớp master-plan rows.
 
 Terminal scope report resolves from the artifact registry, binds the current master-plan reference/revision and enumerates the exact approved plan rows. Caller-provided report object hoặc subset không có exact registry binding không được dùng để kết luận scope.
 
 Terminal scope report Work Item IDs have bidirectional exact set and cardinality equality with current approved plan rows; duplicate, missing or extra IDs block.
 
 ### Assurance-state separation
 
-Đọc `contracts/target-structure-conformance.md` làm authority cho ba state độc lập. Mọi attempt, work-item transition và terminal scope report phải giữ nguyên ba field `runtime_evidence_state`, `architecture_conformance_state` và `selector_schema_state`; không gộp chúng thành một verdict chung và không sao chép enum ra taxonomy riêng của orchestrator.
+Đọc `contracts/target-structure-conformance.md` và `contracts/file-responsibility-conformance.md` làm authority. Mọi attempt, work-item transition và terminal scope report phải giữ nguyên ba field `runtime_evidence_state`, `architecture_conformance_state` và `selector_schema_state`; không gộp chúng thành một verdict chung và không sao chép enum ra taxonomy riêng của orchestrator. `architecture_conformance_state` luôn được derive từ ba structural sub-verdict, không nhận caller assertion.
 
 Chỉ runtime evidence đủ điều kiện mới được `auto-waive`: native runtime check chưa chạy vì blocker môi trường đã được chứng minh có thể chuyển đúng từ `NOT_RUN + BLOCKED` thành `NOT_RUN + WAIVED`. `FAIL` không bao giờ được đổi thành waiver. `architecture_conformance_state: BLOCKED` hoặc `selector_schema_state: BLOCKED` luôn dừng queue trước target mutation, kể cả khi runtime evidence là `WAIVED`; master approval, exemplar inspection, conformance matrix, canonical selector, schema validation và static architecture review không waiver-eligible.
 
 ### Compatibility conversion gate
 
 Historical unit-only artifacts chỉ read-only cho đến khi conversion hoàn tất. Conversion phải dùng approved historical evidence và canonical legacy plan authority để tạo immutable `master-spec` revision 1 cùng `master-plan` revision 1, tạo đúng một generic work item cho mỗi canonical legacy unit, và gắn exact `migration-unit` adapter reference đã được phê duyệt. Không phát minh selector, không nhận external-only unit, không giữ terminal evidence thiếu contract binding, và không suy module/project/requested-scope completion từ một unit đã complete.
 
 Conversion output luôn quay qua một approval gate mới cho toàn bộ master spec, master plan, work-item set, selector và preserved terminal evidence. Trước khi approval này thành công, queue giữ `planned` hoặc `scope-blocked` và tuyệt đối không production mutation/resume execution. Sau approval, selection/resume dùng cùng deterministic queue, conformance và structural gates như migration mới.
 
 ### Terminal scope report
 
 Sau mỗi atomic work-item transition, render `templates/migration/scope-terminal-report.md` thành immutable artifact tham chiếu current approved master spec/plan revisions. Báo cáo phải enumerate bidirectionally exact mọi required và optional work item của plan, với status, terminal evidence, ba assurance states, blocker/disposition và plan revision; không nhận caller subset, duplicate hoặc extra row.
 
-Calculated Terminal Verdict phải được tính từ canonical completion formula, không sao chép caller assertion. `scope-complete` chỉ hợp lệ khi graph valid, mọi required item terminal-success, mọi required terminal evidence resolve bất biến, completed-item architecture/selector-schema đều `PASS`, không còn blocker và Evidence Index đầy đủ. Nếu còn required item non-terminal thì giữ `scope-in-progress`; architecture/selector blocker cho `scope-blocked`.
+Calculated Terminal Verdict phải được tính từ canonical completion formula, không sao chép caller assertion. `scope-complete` chỉ hợp lệ khi graph valid, mọi required item terminal-success, mọi required terminal evidence resolve bất biến, từng immutable terminal artifact có đúng v1 `Architecture Responsibility Handoff`, Tree/Responsibility/Verification/derived architecture và selector-schema đều `PASS`, không còn blocker và Evidence Index bind exact các terminal artifact đã resolve. Nếu còn required item non-terminal thì giữ `scope-in-progress`; bất kỳ structural hoặc selector blocker nào cho `scope-blocked` và `next eligible item: none`.
+
+## Responsibility v1 rollout and safe post-implementation stop
+
+Resolve exactly one immediate-predecessor `Architecture Responsibility Handoff` with responsibility contract version `1` and immutable `Evidence References` before queue selection, resume, parity, regression, delivery, Knowledge Base completion, or terminal completion.
+
+Queue selection, resume, and dependency unlock require the predecessor handoff to resolve exactly one immutable authority artifact with approved/complete/human lifecycle, current run/master-spec/master-plan binding, and exact v1 PASS sub-verdicts; absent, pre-v1, mismatched, stale, cross-run, or caller-attested fields derive BLOCKED before production.
+
+Terminal authority must resolve the explicit immutable ordered responsibility chain for each terminal-success work item. Incremental uses `11-ai-review -> 12-verification-testing -> 13-verify-parity -> 14-verify-regression -> 15-knowledge-base`; greenfield uses `11-ai-review -> 12-verification-testing -> 13-verify-parity -> 15-knowledge-base`. Validate every adjacent pair as an immediate-predecessor handoff, preserve the exact v1 row and independent source/diff evidence, and bind the terminal report Evidence Index to the final chain artifact. A missing, reordered, skipped, duplicate, stale, cross-run, or caller-synthesized chain is not terminal authority.
+
+The terminal chain uses the approved migration-unit mode from its step-8 authority record, never a terminal or chain self-label; the initial review is approved/complete/human, every chain artifact stays in the current run and binds the current master spec/plan/work item, and each source-diff SHA pair exactly equals immutable Task Provenance.
+
+Work Item Terminal Evidence references only the immutable work-item terminal artifact; its exact v1 handoff Evidence References equals the final artifact of the mode-aware ordered chain, and the terminal report Evidence Index uses that same final artifact for each terminal-success item only.
+
+`architecture_conformance_state` is derived: it is `PASS` only when Tree Conformance, Responsibility Conformance, and Verification Ownership are all `PASS`; otherwise it is `BLOCKED`.
+
+| Input / condition | Compatibility disposition | Derived architecture state | Queue and selection | Downstream boundary | Required resume authority |
+|---|---|---|---|---|---|
+| v1 exact handoff; Tree PASS; Responsibility PASS; Verification PASS; immutable evidence resolves | executable | PASS | current approved work item only | normal gates | current approved design/master-plan |
+| any structural sub-verdict BLOCKED or missing or mismatched immutable evidence link | blocked | BLOCKED | scope-blocked; next eligible item: none; no dependent selection | stop before parity, regression, delivery, KB, and terminal completion | approved design/master-plan revision required |
+| completed pre-v1 artifact | historical-only | not executable | no selection or resume from artifact | no downstream completion authority | approved v1 backfill before future executable work |
+| in-progress pre-v1 artifact | blocked | BLOCKED | no resume; no production mutation; no dependent selection | stop before parity, regression, delivery, KB, and terminal completion | approved design/master-plan revision with v1 backfill required |
+| mixed v1/v2 or cross-run evidence | blocked | BLOCKED | scope-blocked; next eligible item: none; no dependent selection | stop before parity, regression, delivery, KB, and terminal completion | approved design/master-plan revision required |
+
+Khi actual responsibility khác approved responsibility sau implementation, giữ isolated task tree làm evidence và áp dụng nguyên chuỗi: implementation `draft/blocked` -> AI review `Reject` -> work item `blocked` -> dependent item non-eligible -> parity/regression/delivery/KB/terminal completion blocked -> approved design/master-plan revision required. Không amend rời rạc rejected tree và không tiếp tục dependent work.
+
+Runtime `auto-waive` never changes Tree, Responsibility, or Verification Ownership sub-verdicts.
+
+Do not create a Phase 2 remediation artifact or work item automatically.
 
 ## Chuẩn bị run
 
 1. Hoàn tất scope resolution và đặt `<slug>` từ resolved requested scope; không hỏi thêm câu scope nếu record đã resolved. Dùng ngày hiện tại theo `YYYY-MM-DD`.
 2. Đặt `RUN_DIR = <project>/docs/aitoolkit/<date>-migration-<slug>/` và tạo thư mục khi cần.
 3. Tạo/resolve master spec và master plan, validate approved revision chain rồi select/resume đúng một work item theo scope plane.
 4. Đặt per-run `workflow_type: migration`. Giá trị orchestrator-provided này là authoritative; không đọc workflow hiện tại từ persistent profile.
 5. Đọc `<project>/docs/aitoolkit/project.yaml`, project pack tại path trong profile, source/target và tài liệu được profile trỏ tới. Không tự suy ra giá trị còn thiếu.
 6. Resolve automation mode, artifact language và optional delivery adapter trước step 01.
 7. Chỉ sau khi selected work item đã atomically `in-progress`, tạo TodoWrite gồm đúng 15 mục execution plane theo Bảng bước. Chỉ một mục `in_progress` tại một thời điểm.
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/templates/migration/scope-terminal-report.md b/AIToolkit/AIToolkit-main/aitoolkit/templates/migration/scope-terminal-report.md
index a5580d5..b598a2f 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/templates/migration/scope-terminal-report.md
+++ b/AIToolkit/AIToolkit-main/aitoolkit/templates/migration/scope-terminal-report.md
@@ -18,31 +18,39 @@ produced_at: <YYYY-MM-DD>
 | Master Spec Reference | Master Spec Revision | Master Plan Reference | Master Plan Revision | Terminal Report Reference |
 |---|---:|---|---:|---|
 | <tham chiếu master spec bất biến> | <revision> | <tham chiếu master plan bất biến> | <revision> | <tham chiếu artifact hiện tại> |
 
 ## Work Item Terminal Evidence
 
 | Work Item ID | Required | Status | Terminal Evidence | Runtime Evidence State | Architecture Conformance State | Selector Schema State | Blocker | Plan Revision |
 |---|---|---|---|---|---|---|---|---:|
 | WORK-<PHẠM-VI>-<TÊN> | yes | complete | <tham chiếu evidence bất biến> | PASS | PASS | PASS | none | <revision> |
 
+For each terminal-success row, `Terminal Evidence` resolves only the immutable work-item terminal artifact. That artifact contains the exact v1 `Architecture Responsibility Handoff`; its `Evidence References` resolves the final artifact of the mode-aware ordered chain. Pending and other non-terminal rows use `none` and do not declare a responsibility chain.
+
 ## Scope Completion Calculation
 
-| Graph State | Required Items | Required Terminal Evidence | Architecture State | Selector Schema State | Remaining Blockers | Calculated Terminal Verdict |
-|---|---|---|---|---|---|---|
-| valid | all-terminal-success | all-required-terminal-evidence | PASS | PASS | none | scope-complete |
+| Graph State | Required Items | Required Terminal Evidence | Tree Conformance | Responsibility Conformance | Verification Ownership | Architecture State | Selector Schema State | Remaining Blockers | Calculated Terminal Verdict |
+|---|---|---|---|---|---|---|---|---|---|
+| valid | all-terminal-success | all-required-terminal-evidence | PASS | PASS | PASS | PASS | PASS | none | scope-complete |
+
+## Architecture Responsibility Handoff
+
+| Responsibility Contract Version | Tree Conformance | Responsibility Conformance | Verification Ownership | Architecture Conformance State | Evidence References |
+|---|---|---|---|---|---|
+| 1 | PASS | PASS | PASS | PASS | <ordered immutable terminal evidence references resolved from Work Item Terminal Evidence> |
 
 ## Evidence Index
 
 | Evidence ID | Artifact Reference | Work Item ID | Purpose |
 |---|---|---|---|
-| EVIDENCE-<NNN> | <tham chiếu artifact bất biến> | WORK-<PHẠM-VI>-<TÊN> | <mục đích bằng chứng> |
+| EVIDENCE-ARCH-WORK-<PHẠM-VI>-<TÊN> | <same final ordered-chain artifact referenced by the work-item terminal handoff> | WORK-<PHẠM-VI>-<TÊN> | architecture-responsibility-sub-verdicts |
 
 ## Blockers and Dispositions
 
 | Work Item ID | Blocker | Disposition | Decision Reference |
 |---|---|---|---|
 | WORK-<PHẠM-VI>-<TÊN> | none | not-applicable | not-applicable |
 
 ## Approval Record
 
 | Decision | Approver | Evidence | Decided At |
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/flexible-scope-e2e.Tests.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/flexible-scope-e2e.Tests.ps1
index df39ba8..4e391fd 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/flexible-scope-e2e.Tests.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/flexible-scope-e2e.Tests.ps1
@@ -34,29 +34,53 @@ function Replace-Exact([string]$Path, [string]$Old, [string]$New, [string]$Scena
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
+function New-ResponsibilityReviewEvidence([string]$Run,[string]$Name,[string]$WorkItem){
+  $path=Join-Path $Run $Name
+  Write-Utf8 $path "---`nstep_id: 11-ai-review`nstatus: approved`nresult: complete`napproval_source: human`nproduced_at: 2026-08-20`nresponsibility_contract:`n  version: 1`n  applicability: required`n---`n# Independent Architecture Review`n`n## Master Scope Context`n`n| Run ID | Master Spec Reference | Master Spec ID | Master Spec Revision | Master Plan Reference | Master Plan ID | Master Plan Revision | Work Item ID |`n|---|---|---|---|---|---|---|---|`n| RUN-E2E-001 | rendered-scope-run/master-spec.md | SPEC-E2E-001 | 1 | rendered-scope-run/master-plan.md | PLAN-E2E-001 | 1 | $WorkItem |`n`n## Task Provenance`n`n| Task / Unit | Task-base SHA | Final-tree SHA | Source Artifact |`n|---|---|---|---|`n| $WorkItem | 1111111111111111111111111111111111111111 | 2222222222222222222222222222222222222222 | implementation-report.md |`n`n## Architecture Responsibility Handoff`n`n| Responsibility Contract Version | Tree Conformance | Responsibility Conformance | Verification Ownership | Architecture Conformance State | Evidence References |`n|---|---|---|---|---|---|`n| 1 | PASS | PASS | PASS | PASS | source-diff:1111111111111111111111111111111111111111..2222222222222222222222222222222222222222#$WorkItem |`n"
+  Get-ImmutableReference $Run $Name
+}
+function New-ResponsibilityDownstreamArtifact([string]$Run,[string]$Name,[string]$WorkItem,[string]$StepId,[string]$SourceArtifact){
+  $path=Join-Path $Run $Name
+  Write-Utf8 $path "---`nstep_id: $StepId`nstatus: approved`nresult: complete`napproval_source: human`nproduced_at: 2026-08-20`nresponsibility_contract:`n  version: 1`n  applicability: required`n---`n# Responsibility Handoff Stage`n`n## Task Provenance`n`n| Task / Unit | Task-base SHA | Final-tree SHA | Source Artifact |`n|---|---|---|---|`n| $WorkItem | 1111111111111111111111111111111111111111 | 2222222222222222222222222222222222222222 | $SourceArtifact |`n`n## Architecture Responsibility Handoff`n`n| Responsibility Contract Version | Tree Conformance | Responsibility Conformance | Verification Ownership | Architecture Conformance State | Evidence References |`n|---|---|---|---|---|---|`n| 1 | PASS | PASS | PASS | PASS | source-diff:1111111111111111111111111111111111111111..2222222222222222222222222222222222222222#$WorkItem |`n"
+  Get-ImmutableReference $Run $Name
+}
+function Add-ResponsibilityHandoff([string]$Run,[string]$Name,[string]$EvidenceReference){
+  $path=Join-Path $Run $Name
+  $before=Get-Content -Raw -Encoding utf8 -LiteralPath $path
+  $handoff="## Architecture Responsibility Handoff`n`n| Responsibility Contract Version | Tree Conformance | Responsibility Conformance | Verification Ownership | Architecture Conformance State | Evidence References |`n|---|---|---|---|---|---|`n| 1 | PASS | PASS | PASS | PASS | $EvidenceReference |`n`n"
+  $after=$before.Replace('## Work Item Test Evidence',"$handoff## Work Item Test Evidence")
+  if($after-ceq$before){throw "Terminal responsibility handoff fixture insertion was a silent no-op: $Name"}
+  Write-Utf8 $path $after
+  Get-ImmutableReference $Run $Name
+}
 function New-Evidence([string]$Run,[string]$Name,[string]$WorkItem){
   $path=Join-Path $Run $Name
   $unit=if($WorkItem-ceq'WORK-E2E-A'){'UNIT-A'}else{'UNIT-B'}
   $workApproval=if($WorkItem-ceq'WORK-E2E-A'){'approval:HUMAN-WORK-A'}else{'approval:HUMAN-WORK-B'}
   Write-Utf8 $path "---`nstep_id: 10-code-migration`nstatus: approved`nresult: complete`napproval_source: human`nproduced_at: 2026-08-20`n---`n# Implementation Report`n`n## Master Scope Context`n`n| Master Spec Reference | Master Spec ID | Master Spec Revision | Master Plan Reference | Master Plan ID | Master Plan Revision | Work Item ID | Work Item Approval Reference |`n|---|---|---|---|---|---|---|---|`n| rendered-scope-run/master-spec.md | SPEC-E2E-001 | 1 | rendered-scope-run/master-plan.md | PLAN-E2E-001 | 1 | $WorkItem | $workApproval |`n`n## Canonical Adapter Evidence`n`n| Work Item ID | Adapter Kind | External ID | Authority | Authority Revision | Approval Reference | Parent Selector | Acceptance | Trace IDs | Mode Constraint | Design Revision | Parent Work Item ID | Decomposition Decision Reference | Canonical Match |`n|---|---|---|---|---|---|---|---|---|---|---|---|---|---|`n| $WorkItem | migration-unit | $unit | legacy-plan.md | 7 | approval:HUMAN-$unit | not-applicable | REQ-001; SC-001; measurable outcome | TRACE-001 | incremental/preserve-existing | DESIGN-E2E@1 | not-applicable | not-applicable | PASS |`n`n## Assurance State`n`n| Runtime Evidence State | Architecture Conformance State | Selector Schema State |`n|---|---|---|`n| PASS | PASS | PASS |`n`n## Work Item Test Evidence`n`n| Work Item ID | Activation Slice ID | Seam | Test | Command | Result | Trace IDs |`n|---|---|---|---|---|---|---|`n| $WorkItem | ACT-E2E-001 | runtime | behavioral verification | test:e2e | PASS | TRACE-001 |`n| $WorkItem | ACT-E2E-001 | persistence | integration verification | test:integration | PASS | TRACE-001 |`n"
   Get-ImmutableReference $Run $Name
 }
 function New-HistoricalEvidence([string]$Run,[string]$Name,[string]$Unit){$path=Join-Path $Run $Name;$baseline=if($Unit-ceq'UNIT-A'){'baseline:a'}else{'baseline:b'};Write-Utf8 $path "---`nstep_id: 10-code-migration`nstatus: approved`nresult: complete`napproval_source: human`nproduced_at: 2025-01-01`n---`n# Historical Code Migration Report`n`n## Selected Migration Unit`n`n| Migration Unit ID | Plan Reference | Approval Reference | Mode Constraint | Bootstrap Scope | Foundation Baseline ID | Foundation Baseline Reference | Foundation Baseline Approval Reference | Baseline Reference | Trace IDs |`n|---|---|---|---|---|---|---|---|---|---|`n| $Unit | legacy-plan.md@7 | approval:HUMAN-$Unit | incremental/preserve-existing | not-required | not-applicable | not-applicable | not-applicable | $baseline | TRACE-LEGACY-$Unit |`n`n## $FileChangesHeading`n`n| Migration Unit ID | File | Change | Trace IDs |`n|---|---|---|---|`n| $Unit | legacy/source.dart | historical migration | TRACE-LEGACY-$Unit |`n`n## $TraceHeading`n`n| Trace ID | Implementation Reference |`n|---|---|`n| TRACE-LEGACY-$Unit | legacy/source.dart |`n`n## $CommandsHeading`n`n| Command | Result | Evidence |`n|---|---|---|`n| test:legacy | PASS | evidence:legacy-$Unit |`n`n## $BlockerHeading`n`n| Stage / Check | Native Verdict | Command Role | Required Command Lifecycle | Command / Capability | Observed Error | Evidence Reference |`n|---|---|---|---|---|---|---|`n| not-applicable | not-applicable | not-applicable | not-applicable | not-applicable | not-applicable | not-applicable |`n`n## $EvidenceHeading`n`n| Evidence | Location | Notes |`n|---|---|---|`n| historical implementation | legacy/source.dart | approved |`n`n## $UnknownHeading`n`n- none`n`n## $ConclusionHeading`n`nready`n";Get-ImmutableReference $Run $Name}
 function New-LegacyPlan([string]$Run){Write-Utf8 (Join-Path $Run 'legacy-plan.md') "---`nstep_id: 08-plan-waves`nstatus: approved`nresult: complete`napproval_source: human`nproduced_at: 2025-01-01`nrevision: 7`n---`n# Approved Legacy Plan`n`n## Migration Units`n`n| Migration Unit ID | Plan Reference | Approval Reference | Mode Constraint | Bootstrap Scope | Foundation Baseline ID | Foundation Baseline Reference | Foundation Baseline Approval Reference | Baseline Reference | Trace IDs |`n|---|---|---|---|---|---|---|---|---|---|`n| UNIT-A | legacy-plan.md@7 | approval:HUMAN-UNIT-A | incremental/preserve-existing | not-required | not-applicable | not-applicable | not-applicable | baseline:a | TRACE-LEGACY-UNIT-A |`n| UNIT-B | legacy-plan.md@7 | approval:HUMAN-UNIT-B | incremental/preserve-existing | not-required | not-applicable | not-applicable | not-applicable | baseline:b | TRACE-LEGACY-UNIT-B |`n"}
+function New-QueueResponsibilityEvidence([string]$Run) {
+  $path = Join-Path $Run 'queue-responsibility-authority.md'
+  Write-Utf8 $path "---`nartifact_type: migration-queue-responsibility-authority`nstatus: approved`nresult: complete`napproval_source: human`nproduced_at: 2026-08-20`nresponsibility_contract:`n  version: 1`n  applicability: required`n---`n# Queue Responsibility Authority`n`n## Master Scope Context`n`n| Run ID | Master Spec Reference | Master Spec ID | Master Spec Revision | Master Plan Reference | Master Plan ID | Master Plan Revision |`n|---|---|---|---|---|---|---|`n| RUN-E2E-001 | rendered-scope-run/master-spec.md | SPEC-E2E-001 | 1 | rendered-scope-run/master-plan.md | PLAN-E2E-001 | 1 |`n`n## Architecture Responsibility Handoff`n`n| Responsibility Contract Version | Tree Conformance | Responsibility Conformance | Verification Ownership | Architecture Conformance State | Evidence References |`n|---|---|---|---|---|---|`n| 1 | PASS | PASS | PASS | PASS | rendered-scope-run/master-plan.md |`n"
+  Get-ImmutableReference $Run 'queue-responsibility-authority.md'
+}
 function Render-CanonicalMaster([string]$FixtureRoot,[string]$Name,[string]$TerminalA){
   $text=Get-Content -Raw -Encoding utf8 (Join-Path $FixtureRoot "templates/migration/$Name")
   $text=[regex]::Replace($text,'<[^>\r\n]+>','sample-value')
   $replacements=[ordered]@{
     'SPEC-sample-value-sample-value'='SPEC-E2E-001';'PLAN-sample-value-sample-value'='PLAN-E2E-001';'WORK-sample-value-sample-value'='WORK-E2E-A';'REQ-###'='REQ-001';'SC-###'='SC-001';'TRACE-###'='TRACE-001';'UNK-###'='UNK-001';'ATTEMPT-sample-value-sample-value'='ATTEMPT-WORK-E2E-A-01';'revision: sample-value'='revision: 1';'master_spec_revision: sample-value'='master_spec_revision: 1';'requested_scope_kind: sample-value'='requested_scope_kind: module';'requested_scope_id: sample-value'='requested_scope_id: E2E';'status: sample-value'='status: approved';'result: sample-value'='result: complete';'approval_source: sample-value'='approval_source: human';'produced_at: sample-value'='produced_at: 2026-08-20';'max_concurrency: sample-value'='max_concurrency: 1';'plan_order: sample-value'='plan_order: 1';'| WORK-E2E-A | sample-value | sample-value | none | sample-value | sample-value | sample-value | none | in-progress | ATTEMPT-WORK-E2E-A-01 | none | pending |'="| WORK-E2E-A | Item A | yes | none | 1 | REQ-001; SC-001; measurable outcome | TRACE-001 | migration-unit:UNIT-A | complete | ATTEMPT-WORK-E2E-A-01 | $TerminalA | approval:HUMAN-WORK-A |";'| sample-value | sample-value | pending | sample-value |'='| human | approval:HUMAN-SCOPE-E2E | approved | 2026-08-20 |';'| sample-value | pending | sample-value |'='| approval:HUMAN-PLAN-E2E | approved | 2026-08-20 |';'| REQ-001 | sample-value | sample-value | sample-value |'='| REQ-001 | Stable requirement | source:ticket | measurable acceptance |';'| SC-001 | REQ-001 | sample-value |'='| SC-001 | REQ-001 | measurable outcome |';'| UNK-001 | sample-value | sample-value | sample-value |'='| UNK-001 | none identified | none | resolved |';'| TRACE-001 | sample-value | sample-value | sample-value |'='| TRACE-001 | requirement | source:ticket | trace note |';'| sample-value | sample-value | sample-value | user | sample-value |'='| module | E2E | Complete E2E module | user | conversation:scope-e2e |';'| WORK-E2E-A | none | no-dependency | sample-value |'='| WORK-E2E-A | none | no-dependency | decision:graph-e2e |';'| ATTEMPT-WORK-E2E-A-01 | WORK-E2E-A | sample-value | in-progress | sample-value |'="| ATTEMPT-WORK-E2E-A-01 | WORK-E2E-A | 1 | complete | $TerminalA |";'| WORK-E2E-A | ready | in-progress | ATTEMPT-WORK-E2E-A-01 | sample-value |'='| WORK-E2E-A | in-progress | complete | ATTEMPT-WORK-E2E-A-01 | 1 |';'| SPEC-E2E-001 | sample-value | not-applicable | sample-value | none | pending |'='| SPEC-E2E-001 | 1 | not-applicable | initial approved scope | none | approval:HUMAN-SCOPE-E2E |';'| PLAN-E2E-001 | sample-value | not-applicable | sample-value | none | pending |'='| PLAN-E2E-001 | 1 | not-applicable | initial approved plan | none | approval:HUMAN-PLAN-E2E |'
   }
   foreach($key in $replacements.Keys){$text=$text.Replace($key,$replacements[$key])}
   $text
 }
 
@@ -92,22 +116,42 @@ function Assert-PredecessorReferenceRejected([object]$Result,[string]$ScenarioId
   if($Result.ExitCode-eq0-or$Result.Output-notmatch'predecessor immutable reference (?:digest is stale|is malformed)'){$failures.Add("$ScenarioId invalid immutable predecessor reference was not rejected: $($Result.Output)")}
 }
 function Assert-Observed([object]$Result,[string]$Diagnostic,[string]$State,[string]$ScenarioId){
   if($Result.Output-notmatch('(?m)^DIAGNOSTIC: '+[regex]::Escape($Diagnostic)+'$')-or$Result.Output-notmatch('(?m)^SCOPE_STATE: '+[regex]::Escape($State)+'$')){$failures.Add("$ScenarioId did not calculate $Diagnostic/$State : $($Result.Output)")}
 }
 
 function New-RenderedFixture([string]$FixtureRoot, [object]$Scenario) {
   $run = Join-Path $FixtureRoot 'rendered-scope-run'
   New-Item -ItemType Directory -Path $run -Force | Out-Null
   New-LegacyPlan $run
+  $queueResponsibilityAuthority=New-QueueResponsibilityEvidence $run
+  $reviewA=New-ResponsibilityReviewEvidence $run 'review-a.md' 'WORK-E2E-A'
+  $reviewB=New-ResponsibilityReviewEvidence $run 'review-b.md' 'WORK-E2E-B'
+  $verificationA=New-ResponsibilityDownstreamArtifact $run 'verification-a.md' 'WORK-E2E-A' '12-verification-testing' 'review-report.md'
+  $parityA=New-ResponsibilityDownstreamArtifact $run 'parity-a.md' 'WORK-E2E-A' '13-verify-parity' 'verification-report.md'
+  $regressionA=New-ResponsibilityDownstreamArtifact $run 'regression-a.md' 'WORK-E2E-A' '14-verify-regression' '13-parity-report.md'
+  $knowledgeA=New-ResponsibilityDownstreamArtifact $run 'knowledge-a.md' 'WORK-E2E-A' '15-knowledge-base' '14-regression-report.md'
+  $greenfieldKnowledgeA=New-ResponsibilityDownstreamArtifact $run 'knowledge-greenfield-a.md' 'WORK-E2E-A' '15-knowledge-base' '13-parity-report.md'
+  $verificationB=New-ResponsibilityDownstreamArtifact $run 'verification-b.md' 'WORK-E2E-B' '12-verification-testing' 'review-report.md'
+  $parityB=New-ResponsibilityDownstreamArtifact $run 'parity-b.md' 'WORK-E2E-B' '13-verify-parity' 'verification-report.md'
+  $regressionB=New-ResponsibilityDownstreamArtifact $run 'regression-b.md' 'WORK-E2E-B' '14-verify-regression' '13-parity-report.md'
+  $knowledgeB=New-ResponsibilityDownstreamArtifact $run 'knowledge-b.md' 'WORK-E2E-B' '15-knowledge-base' '14-regression-report.md'
+  $greenfieldKnowledgeB=New-ResponsibilityDownstreamArtifact $run 'knowledge-greenfield-b.md' 'WORK-E2E-B' '15-knowledge-base' '13-parity-report.md'
+  $responsibilityChains=@(
+    [ordered]@{work_item_id='WORK-E2E-A';artifact_refs=@($reviewA,$verificationA,$parityA,$regressionA,$knowledgeA)},
+    [ordered]@{work_item_id='WORK-E2E-B';artifact_refs=@($reviewB,$verificationB,$parityB,$regressionB,$knowledgeB)}
+  )
+  if($Scenario.Id-ceq'S05'){$responsibilityChains=@($responsibilityChains[0])}
   $terminalA=New-Evidence $run 'terminal-a.md' 'WORK-E2E-A'
   $terminalB=New-Evidence $run 'terminal-b.md' 'WORK-E2E-B'
+  $terminalA=Add-ResponsibilityHandoff $run 'terminal-a.md' $knowledgeA
+  $terminalB=Add-ResponsibilityHandoff $run 'terminal-b.md' $knowledgeB
   $historicalA=New-HistoricalEvidence $run 'historical-a.md' 'UNIT-A'
   $historicalB=New-HistoricalEvidence $run 'historical-b.md' 'UNIT-B'
   $spec = @'
 ---
 artifact_type: migration-master-spec
 master_spec_id: SPEC-E2E-001
 revision: 1
 status: approved
 result: complete
 approval_source: human
@@ -136,31 +180,43 @@ supersedes: not-applicable
 ---
 # Master Plan
 
 ## Work Items
 
 | Work Item ID | Title | Required | Dependencies | Plan Order | Acceptance | Trace IDs | Delivery Adapter | Status | Latest Attempt | Terminal Evidence | Approval Reference |
 |---|---|---|---|---|---|---|---|---|---|---|---|
 | WORK-E2E-A | Item A | yes | none | 1 | REQ-001; SC-001 | TRACE-001 | migration-unit:UNIT-A | complete | ATTEMPT-A-01 | __TERMINAL_A__ | approval:HUMAN-WORK-A |
 | WORK-E2E-B | Item B | no | WORK-E2E-A | 2 | REQ-001; SC-001 | TRACE-001 | migration-unit:UNIT-B | complete | ATTEMPT-B-01 | __TERMINAL_B__ | approval:HUMAN-WORK-B |
 '@).Replace('__TERMINAL_A__',$terminalA).Replace('__TERMINAL_B__',$terminalB)
-  $predecessor = @'
+  $predecessor = @"
 ---
 step_id: 08-plan-waves
 status: draft
 result: complete
 approval_source: human
 produced_at: 2026-08-20
 revision: 1
 ---
 # Immediate Predecessor
 
+## Master Scope Context
+
+| Run ID | Master Spec Reference | Master Spec ID | Master Spec Revision | Master Plan Reference | Master Plan ID | Master Plan Revision |
+|---|---|---|---|---|---|---|
+| RUN-E2E-001 | rendered-scope-run/master-spec.md | SPEC-E2E-001 | 1 | rendered-scope-run/master-plan.md | PLAN-E2E-001 | 1 |
+
+## Architecture Responsibility Handoff
+
+| Responsibility Contract Version | Tree Conformance | Responsibility Conformance | Verification Ownership | Architecture Conformance State | Evidence References |
+|---|---|---|---|---|---|
+| 1 | PASS | PASS | PASS | PASS | $queueResponsibilityAuthority |
+
 ## Activation Slice
 
 | Activation Slice ID | Applicability | Seam | Input | Output | Source Reference | Trace IDs | Disposition | Status | Decision Reference | Deferred Unit ID |
 |---|---|---|---|---|---|---|---|---|---|---|
 | ACT-001 | applicable | upstream-response | upstream input | upstream output | evidence:upstream | TRACE-001 | implement | verified | not-applicable | not-applicable |
 | ACT-001 | applicable | requested-key | key input | key output | evidence:key | TRACE-002 | implement | verified | not-applicable | not-applicable |
 | ACT-001 | applicable | parse-model | model input | model output | evidence:model | TRACE-001 | implement | verified | not-applicable | not-applicable |
 | ACT-001 | applicable | state-holder | state input | state output | evidence:state | TRACE-002 | deferred-approved | verified | approval:DEFER-ACT-001 | UNIT-003 |
 | ACT-001 | applicable | selector | selector input | selector output | evidence:selector | TRACE-001 | reuse | verified | not-applicable | not-applicable |
 | ACT-001 | applicable | construct | construct input | policy=compatibility-dual-path | evidence:construct; compatibility-reason=legacy-route; router-owner=router-team | TRACE-001; PARITY-001 | implement | verified | approval:ROUTER-ACT-001 | not-applicable |
@@ -169,21 +225,21 @@ revision: 1
 | ACT-001 | applicable | test | test input | test output | evidence:test | PARITY-001 | implement | verified | not-applicable | not-applicable |
 | ACT-002 | not-applicable-approved | upstream-response | no-selector input | no-selector output | evidence:na-upstream | TRACE-002 | not-applicable-approved | verified | approval:NA-ACT-002 | not-applicable |
 | ACT-002 | not-applicable-approved | requested-key | no-selector input | no-selector output | evidence:na-key | TRACE-002 | not-applicable-approved | verified | approval:NA-ACT-002 | not-applicable |
 | ACT-002 | not-applicable-approved | parse-model | no-selector input | no-selector output | evidence:na-model | TRACE-002 | not-applicable-approved | verified | approval:NA-ACT-002 | not-applicable |
 | ACT-002 | not-applicable-approved | state-holder | no-selector input | no-selector output | evidence:na-state | TRACE-002 | not-applicable-approved | verified | approval:NA-ACT-002 | not-applicable |
 | ACT-002 | not-applicable-approved | selector | no-selector input | no-selector output | evidence:na-selector | TRACE-002 | not-applicable-approved | verified | approval:NA-ACT-002 | not-applicable |
 | ACT-002 | not-applicable-approved | construct | no-selector input | no-selector output | evidence:na-construct | TRACE-002 | not-applicable-approved | verified | approval:NA-ACT-002 | not-applicable |
 | ACT-002 | not-applicable-approved | render | no-selector input | no-selector output | evidence:na-render | TRACE-002 | not-applicable-approved | verified | approval:NA-ACT-002 | not-applicable |
 | ACT-002 | not-applicable-approved | downstream-consumer | no-selector input | no-selector output | evidence:na-consumer | TRACE-002 | not-applicable-approved | verified | approval:NA-ACT-002 | not-applicable |
 | ACT-002 | not-applicable-approved | test | no-selector input | no-selector output | evidence:na-test | TRACE-002 | not-applicable-approved | verified | approval:NA-ACT-002 | not-applicable |
-'@
+"@
   $target = @'
 ---
 artifact_type: migration-target-evidence
 selector_state: internal
 decomposition_trace: complete
 exemplar_state: complete
 design_state: precise
 wrapper_state: matched
 tree_state: matched
 matrix_state: present
@@ -197,20 +253,21 @@ note: baseline
 # Target and Design Evidence
 '@
   $spec=Render-CanonicalMaster $FixtureRoot 'master-spec.md' $terminalA
   $plan=Render-CanonicalMaster $FixtureRoot 'master-plan.md' $terminalA
   $baseA="| WORK-E2E-A | Item A | yes | none | 1 | REQ-001; SC-001; measurable outcome | TRACE-001 | migration-unit:UNIT-A | complete | ATTEMPT-WORK-E2E-A-01 | $terminalA | approval:HUMAN-WORK-A |"
   $baseB="| WORK-E2E-B | Item B | no | WORK-E2E-A | 2 | REQ-001; SC-001; measurable outcome | TRACE-001 | migration-unit:UNIT-B | complete | ATTEMPT-WORK-E2E-B-01 | $terminalB | approval:HUMAN-WORK-B |"
   $plan=$plan.Replace($baseA,"$baseA`n$baseB").Replace('| WORK-E2E-A | none | no-dependency | decision:graph-e2e |',"| WORK-E2E-A | none | no-dependency | decision:graph-e2e |`n| WORK-E2E-B | WORK-E2E-A | depends-on | decision:graph-e2e |").Replace("| ATTEMPT-WORK-E2E-A-01 | WORK-E2E-A | 1 | complete | $terminalA |","| ATTEMPT-WORK-E2E-A-01 | WORK-E2E-A | 1 | complete | $terminalA |`n| ATTEMPT-WORK-E2E-B-01 | WORK-E2E-B | 1 | complete | $terminalB |").Replace('| WORK-E2E-A | in-progress | complete | ATTEMPT-WORK-E2E-A-01 | 1 |',"| WORK-E2E-A | ready | in-progress | ATTEMPT-WORK-E2E-A-01 | 1 |`n| WORK-E2E-A | in-progress | complete | $terminalA | 1 |`n| WORK-E2E-B | ready | in-progress | ATTEMPT-WORK-E2E-B-01 | 1 |`n| WORK-E2E-B | in-progress | complete | $terminalB | 1 |")
   Write-Utf8 (Join-Path $run 'master-spec.md') $spec
   Write-Utf8 (Join-Path $run 'master-plan.md') $plan
   Write-Utf8 (Join-Path $run 'predecessor.md') $predecessor
+  $predecessorRef=Get-ImmutableReference $run 'predecessor.md'
   Write-Utf8 (Join-Path $run 'target-evidence.md') $target
 
   $legacyRef='not-applicable'; $terminalRef='not-applicable'
   if ($Scenario.Id -ceq 'S19') {
     $legacyRef='rendered-scope-run/legacy-conversion.md'
     $legacy=(@'
 ---
 artifact_type: migration-legacy-conversion
 status: approved
 master_spec_revision: 1
@@ -260,72 +317,79 @@ produced_at: 2026-08-20
 
 ## Work Item Terminal Evidence
 
 | Work Item ID | Required | Status | Terminal Evidence | Runtime Evidence State | Architecture Conformance State | Selector Schema State | Blocker | Plan Revision |
 |---|---|---|---|---|---|---|---|---|
 | WORK-E2E-A | yes | complete | __TERMINAL_A__ | PASS | PASS | PASS | none | 1 |
 | WORK-E2E-B | no | complete | __TERMINAL_B__ | PASS | PASS | PASS | none | 1 |
 
 ## Scope Completion Calculation
 
-| Graph State | Required Items | Required Terminal Evidence | Architecture State | Selector Schema State | Remaining Blockers | Calculated Terminal Verdict |
-|---|---|---|---|---|---|---|
-| valid | all-terminal-success | all-required-terminal-evidence | PASS | PASS | none | scope-complete |
+| Graph State | Required Items | Required Terminal Evidence | Tree Conformance | Responsibility Conformance | Verification Ownership | Architecture State | Selector Schema State | Remaining Blockers | Calculated Terminal Verdict |
+|---|---|---|---|---|---|---|---|---|---|
+| valid | all-terminal-success | all-required-terminal-evidence | PASS | PASS | PASS | PASS | PASS | none | scope-complete |
+
+## Architecture Responsibility Handoff
+
+| Responsibility Contract Version | Tree Conformance | Responsibility Conformance | Verification Ownership | Architecture Conformance State | Evidence References |
+|---|---|---|---|---|---|
+| 1 | PASS | PASS | PASS | PASS | __RESPONSIBILITY_TERMINALS__ |
 
 ## Evidence Index
 
 | Evidence ID | Artifact Reference | Work Item ID | Purpose |
 |---|---|---|---|
-| EVIDENCE-A | __TERMINAL_A__ | WORK-E2E-A | terminal acceptance |
-| EVIDENCE-B | __TERMINAL_B__ | WORK-E2E-B | terminal acceptance |
+| EVIDENCE-A | __RESPONSIBILITY_A__ | WORK-E2E-A | architecture-responsibility-sub-verdicts |
+| EVIDENCE-B | __RESPONSIBILITY_B__ | WORK-E2E-B | architecture-responsibility-sub-verdicts |
 
 ## Blockers and Dispositions
 
 | Work Item ID | Blocker | Disposition | Decision Reference |
 |---|---|---|---|
 | WORK-E2E-A | none | not-applicable | not-applicable |
 | WORK-E2E-B | none | not-applicable | not-applicable |
 
 ## Approval Record
 
 | Decision | Approver | Evidence | Decided At |
 |---|---|---|---|
 | approved | human | approval:HUMAN-SCOPE-1 | 2026-08-20 |
 
 ## Revision History
 
 | Artifact ID | Revision | Supersedes | Change Summary | Affected Work Items | Approval Reference |
 |---|---|---|---|---|---|
 | REPORT-E2E-001 | 1 | not-applicable | initial terminal calculation | all | approval:HUMAN-SCOPE-1 |
-'@).Replace('__TERMINAL_A__',$terminalA).Replace('__TERMINAL_B__',$terminalB)
+'@).Replace('__TERMINAL_A__',$terminalA).Replace('__TERMINAL_B__',$terminalB).Replace('__RESPONSIBILITY_A__',$knowledgeA).Replace('__RESPONSIBILITY_B__',$knowledgeB).Replace('__RESPONSIBILITY_TERMINALS__',"$knowledgeA; $knowledgeB")
     if($Scenario.Id-ceq'S05'){
-      $terminalReport=$terminalReport.Replace('| WORK-E2E-B | no | complete | '+$terminalB+' | PASS | PASS | PASS | none | 1 |','| WORK-E2E-B | yes | pending | none | PASS | PASS | PASS | none | 1 |').Replace('| EVIDENCE-B | '+$terminalB+' | WORK-E2E-B |','| EVIDENCE-B | none | WORK-E2E-B |').Replace('| valid | all-terminal-success | all-required-terminal-evidence | PASS | PASS | none | scope-complete |','| valid | required-work-remains | partial | PASS | PASS | none | scope-in-progress |')
+      $terminalReport=$terminalReport.Replace('| WORK-E2E-B | no | complete | '+$terminalB+' | PASS | PASS | PASS | none | 1 |','| WORK-E2E-B | yes | pending | none | PASS | PASS | PASS | none | 1 |').Replace("| EVIDENCE-B | $knowledgeB | WORK-E2E-B | architecture-responsibility-sub-verdicts |",'').Replace("$knowledgeA; $knowledgeB",$knowledgeA).Replace('| valid | all-terminal-success | all-required-terminal-evidence | PASS | PASS | PASS | PASS | PASS | none | scope-complete |','| valid | required-work-remains | partial | PASS | PASS | PASS | PASS | PASS | none | scope-in-progress |')
     }
     if($Scenario.Id-ceq'S07'){
-      $terminalReport=$terminalReport.Replace('scope_status: scope-in-progress','scope_status: scope-blocked').Replace('| WORK-E2E-A | yes | complete | '+$terminalA+' | PASS | PASS | PASS | none | 1 |','| WORK-E2E-A | yes | blocked | none | PASS | PASS | PASS | hard-blocker | 1 |').Replace('| EVIDENCE-A | '+$terminalA+' | WORK-E2E-A |','| EVIDENCE-A | none | WORK-E2E-A |').Replace('| WORK-E2E-A | none | not-applicable | not-applicable |','| WORK-E2E-A | hard-blocker | pending | not-applicable |').Replace('| valid | all-terminal-success | all-required-terminal-evidence | PASS | PASS | none | scope-complete |','| valid | required-work-blocked | partial | PASS | PASS | hard-blocker | scope-blocked |')
+      $terminalReport=$terminalReport.Replace('scope_status: scope-in-progress','scope_status: scope-blocked').Replace('| WORK-E2E-A | yes | complete | '+$terminalA+' | PASS | PASS | PASS | none | 1 |','| WORK-E2E-A | yes | blocked | none | PASS | PASS | PASS | hard-blocker | 1 |').Replace('| EVIDENCE-A | '+$knowledgeA+' | WORK-E2E-A |','| EVIDENCE-A | none | WORK-E2E-A |').Replace('| WORK-E2E-A | none | not-applicable | not-applicable |','| WORK-E2E-A | hard-blocker | pending | not-applicable |').Replace('| valid | all-terminal-success | all-required-terminal-evidence | PASS | PASS | none | scope-complete |','| valid | required-work-blocked | partial | PASS | PASS | hard-blocker | scope-blocked |')
     }
     Write-Utf8 (Join-Path $run 'scope-terminal-report.md') $terminalReport
   }
   $manifest = [ordered]@{
     expected_diagnostic=$Scenario.Diagnostic
     expected_scope_state=$Scenario.State
     legacy_conversion_ref=$legacyRef
     master_plan_ref='rendered-scope-run/master-plan.md'
     master_spec_ref='rendered-scope-run/master-spec.md'
-    predecessor_ref='rendered-scope-run/predecessor.md'
+    predecessor_ref=$predecessorRef
+    responsibility_chain_refs=$responsibilityChains
     scenario_id=$Scenario.Id
     target_evidence_ref='rendered-scope-run/target-evidence.md'
     terminal_report_ref=$terminalRef
   }
   $manifestPath=Join-Path $run 'scenario.json'
   Write-Utf8 $manifestPath ($manifest | ConvertTo-Json -Depth 4)
-  [pscustomobject]@{ Run=$run; Manifest=$manifestPath; TerminalA=$terminalA; TerminalB=$terminalB; HistoricalA=$historicalA; HistoricalB=$historicalB }
+  [pscustomobject]@{ Run=$run; Manifest=$manifestPath; Predecessor=$predecessorRef; QueueResponsibilityAuthority=$queueResponsibilityAuthority; ReviewA=$reviewA; ReviewB=$reviewB; TerminalA=$terminalA; TerminalB=$terminalB; HistoricalA=$historicalA; HistoricalB=$historicalB; ResponsibilityChains=$responsibilityChains; GreenfieldKnowledgeA=$greenfieldKnowledgeA; GreenfieldKnowledgeB=$greenfieldKnowledgeB }
 }
 
 function Apply-ScenarioMutation([object]$Rendered, [object]$Scenario) {
   $pre=Join-Path $Rendered.Run 'predecessor.md'; $spec=Join-Path $Rendered.Run 'master-spec.md'; $plan=Join-Path $Rendered.Run 'master-plan.md'; $target=Join-Path $Rendered.Run 'target-evidence.md'
   $rowA="| WORK-E2E-A | Item A | yes | none | 1 | REQ-001; SC-001; measurable outcome | TRACE-001 | migration-unit:UNIT-A | complete | ATTEMPT-WORK-E2E-A-01 | $($Rendered.TerminalA) | approval:HUMAN-WORK-A |"
   $rowB="| WORK-E2E-B | Item B | no | WORK-E2E-A | 2 | REQ-001; SC-001; measurable outcome | TRACE-001 | migration-unit:UNIT-B | complete | ATTEMPT-WORK-E2E-B-01 | $($Rendered.TerminalB) | approval:HUMAN-WORK-B |"
   switch ($Scenario.Id) {
     'S02' { Replace-Exact $spec 'requested_scope_kind: module' 'requested_scope_kind: explicit-item' $Scenario.Id;Replace-Exact $spec '| module | E2E | Complete E2E module | user | conversation:scope-e2e |' '| explicit-item | E2E | Complete E2E module | user | conversation:scope-e2e |' $Scenario.Id;Replace-Exact $plan '| module | E2E | Complete E2E module | user | conversation:scope-e2e |' '| explicit-item | E2E | Complete E2E module | user | conversation:scope-e2e |' $Scenario.Id }
     'S03' { Replace-Exact $spec 'requested_scope_kind: module' 'requested_scope_kind: unresolved' $Scenario.Id;Replace-Exact $spec '| module | E2E | Complete E2E module | user | conversation:scope-e2e |' '| unresolved | E2E | Complete E2E module | user | conversation:scope-e2e |' $Scenario.Id;Replace-Exact $plan '| module | E2E | Complete E2E module | user | conversation:scope-e2e |' '| unresolved | E2E | Complete E2E module | user | conversation:scope-e2e |' $Scenario.Id }
     'S04' { Replace-Exact $plan 'migration-unit:UNIT-A' 'generic:module-foundation' $Scenario.Id }
@@ -399,35 +463,53 @@ foreach($scenario in $scenarios){
         @('master-plan.md','initial approved plan | none | approval:HUMAN-PLAN-E2E |','initial approved plan | none | approval:STALE-PLAN-E2E |','stale-approval')
       )
       foreach($negative in $canonicalNegatives){$path=Join-Path $rendered.Run $negative[0];Replace-Exact $path $negative[1] $negative[2] "S01-$($negative[3])";$negativeResult=Invoke-FlexibleScope $fixtureRoot $rendered.Manifest;if($negative[3]-ceq'stale-approval'){if($negativeResult.Output-notmatch'(?m)^DIAGNOSTIC: master-artifact-current-approval-invalid$'){$failures.Add('S01-stale-approval semantic current-revision gate did not reject')}}else{Assert-CanonicalRejected $negativeResult "S01-$($negative[3])"};Replace-Exact $path $negative[2] $negative[1] "S01-$($negative[3])-restore";Assert-CanonicalAccepted (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) "S01-$($negative[3])-restore"}
       $planPath=Join-Path $rendered.Run 'master-plan.md'
       Replace-Exact $planPath '| WORK-E2E-A | Item A | yes | none | 1 | REQ-001; SC-001; measurable outcome | TRACE-001 | migration-unit:UNIT-A | complete |' '| WORK-E2E-A | Item A | yes | none | 1 | REQ-001; SC-001; measurable outcome | TRACE-001 | migration-unit:UNIT-A | blocked |' 'S01-cross-table-state'
       Assert-CanonicalRejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'S01-cross-table-state'
       Replace-Exact $planPath '| WORK-E2E-A | Item A | yes | none | 1 | REQ-001; SC-001; measurable outcome | TRACE-001 | migration-unit:UNIT-A | blocked |' '| WORK-E2E-A | Item A | yes | none | 1 | REQ-001; SC-001; measurable outcome | TRACE-001 | migration-unit:UNIT-A | complete |' 'S01-cross-table-state-restore'
     }
     $fixtureDigestBefore=Get-TreeDigest -Root $rendered.Run
     Replace-Exact (Join-Path $rendered.Run 'predecessor.md') 'status: draft' 'status: approved' $scenario.Id
+    $approvedPredecessorRef=Get-ImmutableReference $rendered.Run 'predecessor.md'
+    Rebind-ImmutableReference $rendered.Run $rendered.Predecessor $approvedPredecessorRef "$($scenario.Id)-approve-predecessor"
+    $rendered.Predecessor=$approvedPredecessorRef
     if($scenario.Id-ceq'S07'){
       $p=Join-Path $rendered.Run 'master-plan.md';$old="| WORK-E2E-B | Item B | no | WORK-E2E-A | 2 | REQ-001; SC-001; measurable outcome | TRACE-001 | migration-unit:UNIT-B | complete | ATTEMPT-WORK-E2E-B-01 | $($rendered.TerminalB) | approval:HUMAN-WORK-B |";$blocked="| WORK-E2E-B | Item B | no | WORK-E2E-A | 2 | REQ-001; SC-001; measurable outcome | TRACE-001 | migration-unit:UNIT-B | blocked | ATTEMPT-WORK-E2E-B-01 | $($rendered.TerminalB) | approval:HUMAN-WORK-B |";Replace-Exact $p $old $blocked $scenario.Id;Replace-Exact $p "| ATTEMPT-WORK-E2E-B-01 | WORK-E2E-B | 1 | complete | $($rendered.TerminalB) |" "| ATTEMPT-WORK-E2E-B-01 | WORK-E2E-B | 1 | blocked | $($rendered.TerminalB) |" $scenario.Id;Replace-Exact $p "| WORK-E2E-B | in-progress | complete | $($rendered.TerminalB) | 1 |" "| WORK-E2E-B | in-progress | blocked | $($rendered.TerminalB) | 1 |" $scenario.Id;Assert-Observed (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'scope-ready' 'planned' 'S07-optional-blocker';Replace-Exact $p $blocked $old $scenario.Id;Replace-Exact $p "| ATTEMPT-WORK-E2E-B-01 | WORK-E2E-B | 1 | blocked | $($rendered.TerminalB) |" "| ATTEMPT-WORK-E2E-B-01 | WORK-E2E-B | 1 | complete | $($rendered.TerminalB) |" $scenario.Id;Replace-Exact $p "| WORK-E2E-B | in-progress | blocked | $($rendered.TerminalB) | 1 |" "| WORK-E2E-B | in-progress | complete | $($rendered.TerminalB) | 1 |" $scenario.Id
     }
     if($scenario.Id-ceq'S09'){
       $p=Join-Path $rendered.Run 'master-plan.md';Replace-Exact $p '| WORK-E2E-B | Item B | no | WORK-E2E-A |' '| WORK-E2E-B | Item B | no | WORK-MISSING |' $scenario.Id;Replace-Exact $p '| WORK-E2E-B | WORK-E2E-A | depends-on | decision:graph-e2e |' '| WORK-E2E-B | WORK-MISSING | depends-on | decision:graph-e2e |' $scenario.Id;Assert-CanonicalRejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'S09-missing';Replace-Exact $p '| WORK-E2E-B | Item B | no | WORK-MISSING |' '| WORK-E2E-B | Item B | no | WORK-E2E-A |' $scenario.Id;Replace-Exact $p '| WORK-E2E-B | WORK-MISSING | depends-on | decision:graph-e2e |' '| WORK-E2E-B | WORK-E2E-A | depends-on | decision:graph-e2e |' $scenario.Id
     }
     if($scenario.Id -in @('S19','S20')){
       $negative=Invoke-FlexibleScope $fixtureRoot $rendered.Manifest
       $negativeDiagnostic=if($scenario.Id -ceq 'S19'){'legacy-conversion-invalid'}else{'terminal-scope-report-invalid'}
       Assert-Rejected $negative $negativeDiagnostic $scenario.Id
     }
     Apply-ScenarioMutation $rendered $scenario
     $fixtureDigestAfter=Get-TreeDigest -Root $rendered.Run
     if($fixtureDigestBefore -ceq $fixtureDigestAfter){$failures.Add("$($scenario.Id) rendered evidence mutation did not alter fixture digest")}
     Assert-Outcome (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) $scenario.Diagnostic $scenario.State $scenario.Id
+    if($scenario.Id -ceq 'S06'){
+      $predecessorPath=Join-Path $rendered.Run 'predecessor.md'
+      $assertQueueAuthorityRejected={param([string]$Old,[string]$New,[string]$Name)
+        Replace-Exact $predecessorPath $Old $New $Name
+        $mutatedRef=Get-ImmutableReference $rendered.Run 'predecessor.md'
+        Rebind-ImmutableReference $rendered.Run $rendered.Predecessor $mutatedRef "$Name-ref"
+        Assert-Observed (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'structural-assurance-blocked' 'scope-blocked' $Name
+        Replace-Exact $predecessorPath $New $Old "$Name-restore"
+        Rebind-ImmutableReference $rendered.Run $mutatedRef $rendered.Predecessor "$Name-ref-restore"
+      }
+      & $assertQueueAuthorityRejected '## Architecture Responsibility Handoff' '## Missing Responsibility Handoff' 'S06-missing-queue-responsibility-authority'
+      & $assertQueueAuthorityRejected '| 1 | PASS | PASS | PASS | PASS |' '| 0 | PASS | PASS | PASS | PASS |' 'S06-pre-v1-resume-authority'
+      & $assertQueueAuthorityRejected $rendered.QueueResponsibilityAuthority $rendered.ReviewA 'S06-mismatched-queue-evidence'
+      & $assertQueueAuthorityRejected 'RUN-E2E-001 | rendered-scope-run/master-spec.md' 'RUN-FOREIGN-999 | rendered-scope-run/master-spec.md' 'S06-cross-run-queue-evidence'
+    }
     if($scenario.Id -ceq 'S19'){
       $legacy=Join-Path $rendered.Run 'legacy-conversion.md'
       Replace-Exact $legacy "migration-unit:UNIT-A | $($rendered.HistoricalA)" "migration-unit:WRONG | $($rendered.HistoricalA)" $scenario.Id
       Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'legacy-conversion-invalid' "$($scenario.Id)-adapter"
       Replace-Exact $legacy "migration-unit:WRONG | $($rendered.HistoricalA)" "migration-unit:UNIT-A | $($rendered.HistoricalA)" $scenario.Id
       Replace-Exact $legacy "| UNIT-A | WORK-E2E-A | migration-unit:UNIT-A | $($rendered.HistoricalA) | yes |" "| UNIT-A | WORK-E2E-A | migration-unit:UNIT-A | $($rendered.HistoricalA) | no |" $scenario.Id
       Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'legacy-conversion-invalid' "$($scenario.Id)-invalid-evidence"
       Replace-Exact $legacy "| UNIT-A | WORK-E2E-A | migration-unit:UNIT-A | $($rendered.HistoricalA) | no |" "| UNIT-A | WORK-E2E-A | migration-unit:UNIT-A | $($rendered.HistoricalA) | yes |" $scenario.Id
       Replace-Exact $legacy 'implementation-report@9bfed5b148eb07a284f567bcd7486c9a00318a50#gitblob:15299bfe69780430508cf9527fcfe14d1d216748 | approval:HIST-UNIT-A' 'implementation-report@fabricated#gitblob:wrong | approval:HIST-UNIT-A' 'S19-schema-version';Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'legacy-conversion-invalid' 'S19-schema-version';Replace-Exact $legacy 'implementation-report@fabricated#gitblob:wrong | approval:HIST-UNIT-A' 'implementation-report@9bfed5b148eb07a284f567bcd7486c9a00318a50#gitblob:15299bfe69780430508cf9527fcfe14d1d216748 | approval:HIST-UNIT-A' 'S19-schema-version-restore'
       $historicalPath=Join-Path $rendered.Run 'historical-a.md'
@@ -438,57 +520,154 @@ foreach($scenario in $scenarios){
         @('incremental/preserve-existing | not-required','greenfield/design-new | not-required','mode'),
         @('not-required | not-applicable | not-applicable','required | not-applicable | not-applicable','bootstrap'),
         @('not-applicable | not-applicable | not-applicable | baseline:a','FOUNDATION-WRONG | not-applicable | not-applicable | baseline:a','foundation-id'),
         @('not-applicable | not-applicable | baseline:a','foundation:wrong | not-applicable | baseline:a','foundation-reference'),
         @('not-applicable | baseline:a','approval:HUMAN-WRONG | baseline:a','foundation-approval'),
         @('baseline:a | TRACE-LEGACY-UNIT-A','baseline:wrong | TRACE-LEGACY-UNIT-A','baseline'),
         @('TRACE-LEGACY-UNIT-A |','TRACE-LEGACY-WRONG |','trace')
       )
       foreach($negative in $legacyEnvelopeNegatives){Replace-Exact $historicalPath $negative[0] $negative[1] "S19-$($negative[2])";$newRef=Get-ImmutableReference $rendered.Run 'historical-a.md';Rebind-ImmutableReference $rendered.Run $rendered.HistoricalA $newRef "S19-$($negative[2])";Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'legacy-conversion-invalid' "S19-$($negative[2])";Replace-Exact $historicalPath $negative[1] $negative[0] "S19-$($negative[2])-restore";Rebind-ImmutableReference $rendered.Run $newRef $rendered.HistoricalA "S19-$($negative[2])-restore"}
       Replace-Exact $historicalPath 'status: approved' 'status: draft' 'S19-lifecycle';$newRef=Get-ImmutableReference $rendered.Run 'historical-a.md';Rebind-ImmutableReference $rendered.Run $rendered.HistoricalA $newRef 'S19-lifecycle';Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'legacy-conversion-invalid' 'S19-lifecycle';Replace-Exact $historicalPath 'status: draft' 'status: approved' 'S19-lifecycle-restore';Rebind-ImmutableReference $rendered.Run $newRef $rendered.HistoricalA 'S19-lifecycle-restore'
+      Replace-Exact $historicalPath 'result: complete' 'result: partial' 'S19-in-progress-pre-v1-resume';$newRef=Get-ImmutableReference $rendered.Run 'historical-a.md';Rebind-ImmutableReference $rendered.Run $rendered.HistoricalA $newRef 'S19-in-progress-pre-v1-resume';Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'legacy-conversion-invalid' 'S19-in-progress-pre-v1-resume';Replace-Exact $historicalPath 'result: partial' 'result: complete' 'S19-in-progress-pre-v1-resume-restore';Rebind-ImmutableReference $rendered.Run $newRef $rendered.HistoricalA 'S19-in-progress-pre-v1-resume-restore'
       Replace-Exact $historicalPath "## $CommandsHeading" '## Reduced Commands' 'S19-required-section';$newRef=Get-ImmutableReference $rendered.Run 'historical-a.md';Rebind-ImmutableReference $rendered.Run $rendered.HistoricalA $newRef 'S19-required-section';Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'legacy-conversion-invalid' 'S19-required-section';Replace-Exact $historicalPath '## Reduced Commands' "## $CommandsHeading" 'S19-required-section-restore';Rebind-ImmutableReference $rendered.Run $newRef $rendered.HistoricalA 'S19-required-section-restore'
       $target=Join-Path $rendered.Run 'target-evidence.md';Replace-Exact $target 'architecture_conformance_state: PASS' 'architecture_conformance_state: BLOCKED' $scenario.Id;Assert-Observed (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'structural-assurance-blocked' 'scope-blocked' 'S19-monotonic';Replace-Exact $target 'architecture_conformance_state: BLOCKED' 'architecture_conformance_state: PASS' $scenario.Id
     }
     if($scenario.Id -ceq 'S20'){
+      $originalManifest=Get-Content -Raw -Encoding utf8 -LiteralPath $rendered.Manifest
+      $skippedChainManifest=$originalManifest|ConvertFrom-Json
+      $chainA=@($skippedChainManifest.responsibility_chain_refs|Where-Object{$_.work_item_id-ceq'WORK-E2E-A'})[0]
+      $chainA.artifact_refs=@($chainA.artifact_refs[0],$chainA.artifact_refs[1],$chainA.artifact_refs[3],$chainA.artifact_refs[4])
+      Write-Utf8 $rendered.Manifest ($skippedChainManifest|ConvertTo-Json -Depth 8)
+      Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'terminal-scope-report-invalid' 'S20-skipped-responsibility-chain-stage'
+      Write-Utf8 $rendered.Manifest $originalManifest
       $report=Join-Path $rendered.Run 'scope-terminal-report.md'
       Replace-Exact $report '## Approval Record' "## Approval Record`n`n## Approval Record" $scenario.Id
       Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'terminal-scope-report-invalid' "$($scenario.Id)-duplicate-section"
       Replace-Exact $report "## Approval Record`n`n## Approval Record" '## Approval Record' $scenario.Id
       $terminalRow="| WORK-E2E-B | no | complete | $($rendered.TerminalB) | PASS | PASS | PASS | none | 1 |"
       Replace-Exact $report $terminalRow '' $scenario.Id
       Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'terminal-scope-report-invalid' "$($scenario.Id)-cardinality"
       $terminalARow="| WORK-E2E-A | yes | complete | $($rendered.TerminalA) | PASS | PASS | PASS | none | 1 |"
       $reportText=Get-Content -Raw -Encoding utf8 $report
       $reportEol=if($reportText.Contains("`r`n")){"`r`n"}else{"`n"}
       Replace-Exact $report $terminalARow "$terminalARow$reportEol$terminalRow" $scenario.Id
       $target=Join-Path $rendered.Run 'target-evidence.md';Replace-Exact $target 'selector_schema_state: PASS' 'selector_schema_state: BLOCKED' $scenario.Id;Assert-Observed (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'structural-assurance-blocked' 'scope-blocked' 'S20-monotonic';Replace-Exact $target 'selector_schema_state: BLOCKED' 'selector_schema_state: PASS' $scenario.Id
       $terminalPath=Join-Path $rendered.Run 'terminal-a.md';$originalTerminal=Get-Content -Raw -Encoding utf8 $terminalPath
+      $terminalBPath=Join-Path $rendered.Run 'terminal-b.md';$originalTerminalB=Get-Content -Raw -Encoding utf8 $terminalBPath
+      $responsibilityTerminalPath=Join-Path $rendered.Run 'knowledge-a.md';$originalResponsibilityTerminal=Get-Content -Raw -Encoding utf8 $responsibilityTerminalPath
+      $responsibilityEvidence='source-diff:1111111111111111111111111111111111111111..2222222222222222222222222222222222222222#WORK-E2E-A'
+      $terminalWithoutHandoff=$originalTerminal -replace '(?ms)^## Architecture Responsibility Handoff.*?(?=^## Work Item Test Evidence)', ''
+      if($terminalWithoutHandoff-ceq$originalTerminal){throw 'S20 terminal responsibility handoff removal was a silent no-op'}
+      Write-Utf8 $terminalPath $terminalWithoutHandoff;$terminalWithoutHandoffRef=Get-ImmutableReference $rendered.Run 'terminal-a.md';Rebind-ImmutableReference $rendered.Run $rendered.TerminalA $terminalWithoutHandoffRef 'S20-terminal-handoff-required';Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'terminal-scope-report-invalid' 'S20-terminal-handoff-required';Write-Utf8 $terminalPath $originalTerminal;Rebind-ImmutableReference $rendered.Run $terminalWithoutHandoffRef $rendered.TerminalA 'S20-terminal-handoff-required-restore'
+      $reviewPath=Join-Path $rendered.Run 'review-a.md';$originalReview=Get-Content -Raw -Encoding utf8 $reviewPath
+      Replace-Exact $reviewPath 'status: approved' 'status: draft' 'S20-review-lifecycle';$draftReviewRef=Get-ImmutableReference $rendered.Run 'review-a.md';Rebind-ImmutableReference $rendered.Run $rendered.ReviewA $draftReviewRef 'S20-review-lifecycle';Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'terminal-scope-report-invalid' 'S20-review-lifecycle';Write-Utf8 $reviewPath $originalReview;Rebind-ImmutableReference $rendered.Run $draftReviewRef $rendered.ReviewA 'S20-review-lifecycle-restore'
+      Replace-Exact $reviewPath 'result: complete' 'result: partial' 'S20-review-result-lifecycle';$partialReviewRef=Get-ImmutableReference $rendered.Run 'review-a.md';Rebind-ImmutableReference $rendered.Run $rendered.ReviewA $partialReviewRef 'S20-review-result-lifecycle';Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'terminal-scope-report-invalid' 'S20-review-result-lifecycle';Write-Utf8 $reviewPath $originalReview;Rebind-ImmutableReference $rendered.Run $partialReviewRef $rendered.ReviewA 'S20-review-result-lifecycle-restore'
+      Replace-Exact $reviewPath 'approval_source: human' 'approval_source: automation' 'S20-review-approval-source';$automatedReviewRef=Get-ImmutableReference $rendered.Run 'review-a.md';Rebind-ImmutableReference $rendered.Run $rendered.ReviewA $automatedReviewRef 'S20-review-approval-source';Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'terminal-scope-report-invalid' 'S20-review-approval-source';Write-Utf8 $reviewPath $originalReview;Rebind-ImmutableReference $rendered.Run $automatedReviewRef $rendered.ReviewA 'S20-review-approval-source-restore'
+      $greenfieldTerminalA=$originalTerminal.Replace('incremental/preserve-existing','greenfield/design-new').Replace($rendered.ResponsibilityChains[0].artifact_refs[-1],$rendered.GreenfieldKnowledgeA)
+      $greenfieldTerminalB=$originalTerminalB.Replace('incremental/preserve-existing','greenfield/design-new').Replace($rendered.ResponsibilityChains[1].artifact_refs[-1],$rendered.GreenfieldKnowledgeB)
+      Write-Utf8 $terminalPath $greenfieldTerminalA;Write-Utf8 $terminalBPath $greenfieldTerminalB
+      $greenfieldTerminalARef=Get-ImmutableReference $rendered.Run 'terminal-a.md';$greenfieldTerminalBRef=Get-ImmutableReference $rendered.Run 'terminal-b.md'
+      Rebind-ImmutableReference $rendered.Run $rendered.TerminalA $greenfieldTerminalARef 'S20-greenfield-terminal-a';Rebind-ImmutableReference $rendered.Run $rendered.TerminalB $greenfieldTerminalBRef 'S20-greenfield-terminal-b'
+      Rebind-ImmutableReference $rendered.Run $rendered.ResponsibilityChains[0].artifact_refs[-1] $rendered.GreenfieldKnowledgeA 'S20-greenfield-knowledge-a';Rebind-ImmutableReference $rendered.Run $rendered.ResponsibilityChains[1].artifact_refs[-1] $rendered.GreenfieldKnowledgeB 'S20-greenfield-knowledge-b'
+      $greenfieldManifest=Get-Content -Raw -Encoding utf8 -LiteralPath $rendered.Manifest|ConvertFrom-Json
+      foreach($chain in @($greenfieldManifest.responsibility_chain_refs)){$chain.artifact_refs=@($chain.artifact_refs[0],$chain.artifact_refs[1],$chain.artifact_refs[2],$chain.artifact_refs[4])}
+      Write-Utf8 $rendered.Manifest ($greenfieldManifest|ConvertTo-Json -Depth 8)
+      Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'terminal-scope-report-invalid' 'S20-incremental-cannot-self-label-greenfield'
+      $legacyPlanPath=Join-Path $rendered.Run 'legacy-plan.md'
+      Replace-Exact $legacyPlanPath 'incremental/preserve-existing' 'greenfield/design-new' 'S20-approved-greenfield-authority'
+      Assert-Outcome (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'scope-completion-calculated' 'scope-complete' 'S20-greenfield-four-stage-chain'
+      Replace-Exact $legacyPlanPath 'greenfield/design-new' 'incremental/preserve-existing' 'S20-approved-greenfield-authority-restore'
+      Write-Utf8 $terminalPath $originalTerminal;Write-Utf8 $terminalBPath $originalTerminalB;Rebind-ImmutableReference $rendered.Run $greenfieldTerminalARef $rendered.TerminalA 'S20-greenfield-terminal-a-restore';Rebind-ImmutableReference $rendered.Run $greenfieldTerminalBRef $rendered.TerminalB 'S20-greenfield-terminal-b-restore';Rebind-ImmutableReference $rendered.Run $rendered.GreenfieldKnowledgeA $rendered.ResponsibilityChains[0].artifact_refs[-1] 'S20-greenfield-knowledge-a-restore';Rebind-ImmutableReference $rendered.Run $rendered.GreenfieldKnowledgeB $rendered.ResponsibilityChains[1].artifact_refs[-1] 'S20-greenfield-knowledge-b-restore';Write-Utf8 $rendered.Manifest $originalManifest
+
+      $foreignReviewPath=Join-Path $rendered.Run 'foreign/review-a.md'
+      Write-Utf8 $foreignReviewPath $originalReview
+      $foreignReviewRef=Get-ImmutableReference $rendered.Run 'foreign/review-a.md'
+      Rebind-ImmutableReference $rendered.Run $rendered.ReviewA $foreignReviewRef 'S20-same-work-item-cross-run-chain'
+      Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'terminal-scope-report-invalid' 'S20-same-work-item-cross-run-chain'
+      Rebind-ImmutableReference $rendered.Run $foreignReviewRef $rendered.ReviewA 'S20-same-work-item-cross-run-chain-restore'
+
+      Replace-Exact $reviewPath 'RUN-E2E-001 | rendered-scope-run/master-spec.md' 'RUN-E2E-001 | rendered-scope-run/foreign-spec.md' 'S20-review-master-binding'
+      $foreignMasterReviewRef=Get-ImmutableReference $rendered.Run 'review-a.md';Rebind-ImmutableReference $rendered.Run $rendered.ReviewA $foreignMasterReviewRef 'S20-review-master-binding'
+      Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'terminal-scope-report-invalid' 'S20-review-master-binding'
+      Write-Utf8 $reviewPath $originalReview;Rebind-ImmutableReference $rendered.Run $foreignMasterReviewRef $rendered.ReviewA 'S20-review-master-binding-restore'
+
+      $originalSourceDiff='source-diff:1111111111111111111111111111111111111111..2222222222222222222222222222222222222222#WORK-E2E-A'
+      $mismatchedSourceDiff='source-diff:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa..bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb#WORK-E2E-A'
+      $chainNames=@('review-a.md','verification-a.md','parity-a.md','regression-a.md','knowledge-a.md')
+      $mutatedChainRefs=[Collections.Generic.List[string]]::new()
+      for($chainIndex=0;$chainIndex-lt$chainNames.Count;$chainIndex++){
+        Replace-Exact (Join-Path $rendered.Run $chainNames[$chainIndex]) $originalSourceDiff $mismatchedSourceDiff "S20-source-diff-provenance-$chainIndex"
+        $mutatedRef=Get-ImmutableReference $rendered.Run $chainNames[$chainIndex]
+        $mutatedChainRefs.Add($mutatedRef)
+        Rebind-ImmutableReference $rendered.Run $rendered.ResponsibilityChains[0].artifact_refs[$chainIndex] $mutatedRef "S20-source-diff-provenance-$chainIndex-ref"
+      }
+      Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'terminal-scope-report-invalid' 'S20-source-diff-provenance'
+      for($chainIndex=0;$chainIndex-lt$chainNames.Count;$chainIndex++){
+        Replace-Exact (Join-Path $rendered.Run $chainNames[$chainIndex]) $mismatchedSourceDiff $originalSourceDiff "S20-source-diff-provenance-$chainIndex-restore"
+        Rebind-ImmutableReference $rendered.Run $mutatedChainRefs[$chainIndex] $rendered.ResponsibilityChains[0].artifact_refs[$chainIndex] "S20-source-diff-provenance-$chainIndex-ref-restore"
+      }
+      # A terminal artifact without the v1 responsibility handoff cannot be
+      # executable authority for scope completion.
+      $missingHandoff=$originalResponsibilityTerminal -replace '(?ms)^## Architecture Responsibility Handoff.*', ''
+      Write-Utf8 $responsibilityTerminalPath $missingHandoff;$missingHandoffRef=Get-ImmutableReference $rendered.Run 'knowledge-a.md';Rebind-ImmutableReference $rendered.Run $rendered.ResponsibilityChains[0].artifact_refs[4] $missingHandoffRef 'S20-missing-responsibility-handoff';Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'terminal-scope-report-invalid' 'S20-missing-responsibility-handoff';Write-Utf8 $responsibilityTerminalPath $originalResponsibilityTerminal;Rebind-ImmutableReference $rendered.Run $missingHandoffRef $rendered.ResponsibilityChains[0].artifact_refs[4] 'S20-missing-responsibility-handoff-restore'
+      $blockedResponsibility=$originalResponsibilityTerminal.Replace("| 1 | PASS | PASS | PASS | PASS | $responsibilityEvidence |","| 1 | PASS | BLOCKED | PASS | PASS | $responsibilityEvidence |")
+      if($blockedResponsibility-ceq$originalResponsibilityTerminal){throw 'S20 responsibility BLOCKED mutation was a silent no-op'}
+      Write-Utf8 $responsibilityTerminalPath $blockedResponsibility;$blockedResponsibilityRef=Get-ImmutableReference $rendered.Run 'knowledge-a.md';Rebind-ImmutableReference $rendered.Run $rendered.ResponsibilityChains[0].artifact_refs[4] $blockedResponsibilityRef 'S20-aggregate-pass-responsibility-blocked';Assert-Observed (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'structural-assurance-blocked' 'scope-blocked' 'S20-aggregate-pass-responsibility-blocked';Write-Utf8 $responsibilityTerminalPath $originalResponsibilityTerminal;Rebind-ImmutableReference $rendered.Run $blockedResponsibilityRef $rendered.ResponsibilityChains[0].artifact_refs[4] 'S20-aggregate-pass-responsibility-blocked-restore'
+      $missingEvidence=$originalResponsibilityTerminal.Replace($responsibilityEvidence,'none')
+      if($missingEvidence-ceq$originalResponsibilityTerminal){throw 'S20 missing responsibility evidence mutation was a silent no-op'}
+      Write-Utf8 $responsibilityTerminalPath $missingEvidence;$missingEvidenceRef=Get-ImmutableReference $rendered.Run 'knowledge-a.md';Rebind-ImmutableReference $rendered.Run $rendered.ResponsibilityChains[0].artifact_refs[4] $missingEvidenceRef 'S20-missing-responsibility-evidence';Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'terminal-scope-report-invalid' 'S20-missing-responsibility-evidence';Write-Utf8 $responsibilityTerminalPath $originalResponsibilityTerminal;Rebind-ImmutableReference $rendered.Run $missingEvidenceRef $rendered.ResponsibilityChains[0].artifact_refs[4] 'S20-missing-responsibility-evidence-restore'
+      $mixedVersion=$originalResponsibilityTerminal.Replace("| 1 | PASS | PASS | PASS | PASS | $responsibilityEvidence |","| 2 | PASS | PASS | PASS | PASS | $responsibilityEvidence |")
+      if($mixedVersion-ceq$originalResponsibilityTerminal){throw 'S20 mixed v1/v2 mutation was a silent no-op'}
+      Write-Utf8 $responsibilityTerminalPath $mixedVersion;$mixedVersionRef=Get-ImmutableReference $rendered.Run 'knowledge-a.md';Rebind-ImmutableReference $rendered.Run $rendered.ResponsibilityChains[0].artifact_refs[4] $mixedVersionRef 'S20-mixed-v1-v2';Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'terminal-scope-report-invalid' 'S20-mixed-v1-v2';Write-Utf8 $responsibilityTerminalPath $originalResponsibilityTerminal;Rebind-ImmutableReference $rendered.Run $mixedVersionRef $rendered.ResponsibilityChains[0].artifact_refs[4] 'S20-mixed-v1-v2-restore'
+      # A syntactically valid immutable reference with the wrong digest is not
+      # evidence. Rebinding the terminal digest must not make it executable.
+      $forgedEvidenceRef=($rendered.ResponsibilityChains[0].artifact_refs[4] -replace '[0-9a-f]{64}$',('0'*64))
+      Replace-Exact $rendered.Manifest $rendered.ResponsibilityChains[0].artifact_refs[4] $forgedEvidenceRef 'S20-forged-responsibility-evidence';Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'terminal-scope-report-invalid' 'S20-forged-responsibility-evidence';Replace-Exact $rendered.Manifest $forgedEvidenceRef $rendered.ResponsibilityChains[0].artifact_refs[4] 'S20-forged-responsibility-evidence-restore'
+      Rebind-ImmutableReference $rendered.Run $rendered.TerminalA $rendered.HistoricalA 'S20-historical-only-executable-authority';Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'terminal-scope-report-invalid' 'S20-historical-only-executable-authority';Rebind-ImmutableReference $rendered.Run $rendered.HistoricalA $rendered.TerminalA 'S20-historical-only-executable-authority-restore'
       foreach($runtimeState in @('FAIL','NOT_RUN','WAIVED')){$stateTerminal=$originalTerminal.Replace('| PASS | PASS | PASS |',"| $runtimeState | PASS | PASS |");Write-Utf8 $terminalPath $stateTerminal;$stateRef=Get-ImmutableReference $rendered.Run 'terminal-a.md';Rebind-ImmutableReference $rendered.Run $rendered.TerminalA $stateRef "S20-$runtimeState";Replace-Exact $report "| $stateRef | PASS | PASS | PASS | none | 1 |" "| $stateRef | $runtimeState | PASS | PASS | none | 1 |" "S20-$runtimeState-report";Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'terminal-scope-report-invalid' "S20-$runtimeState";Replace-Exact $report "| $stateRef | $runtimeState | PASS | PASS | none | 1 |" "| $stateRef | PASS | PASS | PASS | none | 1 |" "S20-$runtimeState-report-restore";Write-Utf8 $terminalPath $originalTerminal;Rebind-ImmutableReference $rendered.Run $stateRef $rendered.TerminalA "S20-$runtimeState-restore"}
       foreach($referenceNegative in @(@('rendered-scope-run/master-spec.md','rendered-scope-run/other-spec.md','other-spec'),@('rendered-scope-run/master-plan.md','rendered-scope-run/forked-plan.md','forked-plan'),@('approval:HUMAN-WORK-A','approval:HUMAN-WRONG','source-approval'),@('REQ-001; SC-001; measurable outcome | TRACE-001 | incremental/preserve-existing','REQ-001; measurable outcome | TRACE-001 | incremental/preserve-existing','incomplete-acceptance'),@('| WORK-E2E-A | ACT-E2E-001 | persistence | integration verification | test:integration | PASS | TRACE-001 |','| WORK-E2E-A | ACT-E2E-001 | persistence | integration verification | test:integration | PASS | TRACE-OTHER |','incomplete-trace-aggregate'))){Replace-Exact $terminalPath $referenceNegative[0] $referenceNegative[1] "S20-$($referenceNegative[2])";$newRef=Get-ImmutableReference $rendered.Run 'terminal-a.md';Rebind-ImmutableReference $rendered.Run $rendered.TerminalA $newRef "S20-$($referenceNegative[2])";Assert-Rejected (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'terminal-scope-report-invalid' "S20-$($referenceNegative[2])";Write-Utf8 $terminalPath $originalTerminal;Rebind-ImmutableReference $rendered.Run $newRef $rendered.TerminalA "S20-$($referenceNegative[2])-restore"}
       $predecessorAuthority=Get-Content -Raw -Encoding utf8 (Join-Path $rendered.Run 'predecessor.md')
       $activationAuthorityMatch=[regex]::Match($predecessorAuthority,'(?m)^## Activation Slice\r?\n\r?\n(?<table>(?:^\|.*\|\r?\n?)+)')
       if(-not $activationAuthorityMatch.Success){$failures.Add('S20 fixture predecessor activation authority missing')}
       $activationAuthorityTable=$activationAuthorityMatch.Groups['table'].Value.TrimEnd("`r","`n")
       $priorActivationTable=$activationAuthorityTable.Replace('| ACT-001 | applicable | upstream-response | upstream input | upstream output | evidence:upstream | TRACE-001 | implement | verified | not-applicable | not-applicable |','| ACT-001 | applicable | upstream-response | upstream input | upstream output | evidence:upstream; implementation:prior-step10 | TRACE-001; TRACE-002 | implement | verified | not-applicable | not-applicable |')
       if($priorActivationTable-ceq$activationAuthorityTable){throw 'S20 prior-step10 enrichment fixture was a silent no-op'}
       $upstreamAuthorityRef=Get-ImmutableReference $rendered.Run 'predecessor.md'
       $priorWaiverPath=Join-Path $rendered.Run 'prior-step10-waiver.md'
       $priorWaiver=@"
 ---
 step_id: 10-code-migration
 status: approved
 result: partial
 approval_source: auto-waive
 produced_at: 2026-08-20
 ---
 # Prior Step 10 Waiver
 
+## Master Scope Context
+
+| Run ID | Master Spec Reference | Master Spec ID | Master Spec Revision | Master Plan Reference | Master Plan ID | Master Plan Revision | Work Item ID |
+|---|---|---|---|---|---|---|---|
+| RUN-E2E-001 | rendered-scope-run/master-spec.md | SPEC-E2E-001 | 1 | rendered-scope-run/master-plan.md | PLAN-E2E-001 | 1 | WORK-E2E-A |
+
+## Task Provenance
+
+| Task / Unit | Task-base SHA | Final-tree SHA | Source Artifact |
+|---|---|---|---|
+| WORK-E2E-A | 1111111111111111111111111111111111111111 | 2222222222222222222222222222222222222222 | implementation-report.md |
+
+## Architecture Responsibility Handoff
+
+| Responsibility Contract Version | Tree Conformance | Responsibility Conformance | Verification Ownership | Architecture Conformance State | Evidence References |
+|---|---|---|---|---|---|
+| 1 | PASS | PASS | PASS | PASS | $($rendered.QueueResponsibilityAuthority) |
+
 ## Selected Migration Unit
 
 | Migration Unit ID | Plan Reference | Approval Reference | Mode Constraint | Bootstrap Scope | Foundation Baseline ID | Foundation Baseline Reference | Foundation Baseline Approval Reference | Baseline Reference | Trace IDs |
 |---|---|---|---|---|---|---|---|---|---|
 | UNIT-A | legacy-plan.md@7 | approval:HUMAN-UNIT-A | incremental/preserve-existing | not-required | not-applicable | not-applicable | not-applicable | evidence:capability-unavailable | TRACE-001; TRACE-002; PARITY-001 |
 
 ## $BlockerHeading
 
 | Stage / Check | Native Verdict | Command Role | Required Command Lifecycle | Command / Capability | Observed Error | Evidence Reference |
 |---|---|---|---|---|---|---|
@@ -528,21 +707,21 @@ $priorActivationTable
 ## $UnknownHeading
 
 - none
 
 ## $ConclusionHeading
 
 partial
 "@
       Write-Utf8 $priorWaiverPath $priorWaiver
       $priorWaiverRef=Get-ImmutableReference $rendered.Run 'prior-step10-waiver.md'
-      Replace-Exact $rendered.Manifest '"predecessor_ref":  "rendered-scope-run/predecessor.md"' ('"predecessor_ref":  "'+$priorWaiverRef+'"') 'S20-waiver-immediate-predecessor'
+      Replace-Exact $rendered.Manifest ('"predecessor_ref":  "'+$rendered.Predecessor+'"') ('"predecessor_ref":  "'+$priorWaiverRef+'"') 'S20-waiver-immediate-predecessor'
       $waivedTail=@"
 
 ## Selected Migration Unit
 
 | Migration Unit ID | Plan Reference | Approval Reference | Mode Constraint | Bootstrap Scope | Foundation Baseline ID | Foundation Baseline Reference | Foundation Baseline Approval Reference | Baseline Reference | Trace IDs |
 |---|---|---|---|---|---|---|---|---|---|
 | UNIT-A | legacy-plan.md@7 | approval:HUMAN-UNIT-A | incremental/preserve-existing | not-required | not-applicable | not-applicable | not-applicable | evidence:capability-unavailable | TRACE-001; TRACE-002; PARITY-001 |
 
 ## $BlockerHeading
 
@@ -586,22 +765,25 @@ $priorActivationTable
 
 - none
 
 ## $ConclusionHeading
 
 partial
 "@
       $specPath=Join-Path $rendered.Run 'master-spec.md';$planPath=Join-Path $rendered.Run 'master-plan.md'
       Replace-Exact $specPath '| TRACE-001 | requirement | source:ticket | trace note |' "| TRACE-001 | requirement | source:ticket | trace note |`n| TRACE-002 | requirement | source:ticket-2 | trace note 2 |`n| PARITY-001 | requirement | source:parity | parity trace |" 'S20-waiver-spec-traces'
       Replace-Exact $planPath 'REQ-001; SC-001; measurable outcome | TRACE-001 | migration-unit:UNIT-A' 'REQ-001; SC-001; measurable outcome | TRACE-001; TRACE-002; PARITY-001 | migration-unit:UNIT-A' 'S20-waiver-plan-traces'
-      $waivedTerminal=$originalTerminal.Replace('result: complete','result: partial').Replace('approval_source: human','approval_source: auto-waive').Replace('| PASS | PASS | PASS |','| WAIVED | PASS | PASS |').Replace('REQ-001; SC-001; measurable outcome | TRACE-001 | incremental/preserve-existing','REQ-001; SC-001; measurable outcome | TRACE-001; TRACE-002; PARITY-001 | incremental/preserve-existing').Replace("| WORK-E2E-A | ACT-E2E-001 | runtime | behavioral verification | test:e2e | PASS | TRACE-001 |`n| WORK-E2E-A | ACT-E2E-001 | persistence | integration verification | test:integration | PASS | TRACE-001 |","| WORK-E2E-A | ACT-E2E-001 | runtime | behavioral verification | test:e2e | PASS | TRACE-001 |`n| WORK-E2E-A | ACT-E2E-001 | persistence | integration verification | test:integration | PASS | TRACE-002 |`n| WORK-E2E-A | ACT-E2E-001 | parity | compatibility verification | test:parity | PASS | PARITY-001 |")+$waivedTail
+      $waivedTerminal=$originalTerminal.Replace('result: complete','result: partial').Replace('approval_source: human','approval_source: auto-waive').Replace("| PASS | PASS | PASS |`n`n## Architecture Responsibility Handoff","| WAIVED | PASS | PASS |`n`n## Architecture Responsibility Handoff").Replace('REQ-001; SC-001; measurable outcome | TRACE-001 | incremental/preserve-existing','REQ-001; SC-001; measurable outcome | TRACE-001; TRACE-002; PARITY-001 | incremental/preserve-existing').Replace("| WORK-E2E-A | ACT-E2E-001 | runtime | behavioral verification | test:e2e | PASS | TRACE-001 |`n| WORK-E2E-A | ACT-E2E-001 | persistence | integration verification | test:integration | PASS | TRACE-001 |","| WORK-E2E-A | ACT-E2E-001 | runtime | behavioral verification | test:e2e | PASS | TRACE-001 |`n| WORK-E2E-A | ACT-E2E-001 | persistence | integration verification | test:integration | PASS | TRACE-002 |`n| WORK-E2E-A | ACT-E2E-001 | parity | compatibility verification | test:parity | PASS | PARITY-001 |")+$waivedTail
       Write-Utf8 $terminalPath $waivedTerminal;$waivedRef=Get-ImmutableReference $rendered.Run 'terminal-a.md';Rebind-ImmutableReference $rendered.Run $rendered.TerminalA $waivedRef 'S20-valid-waiver';Replace-Exact $report "| $waivedRef | PASS | PASS | PASS | none | 1 |" "| $waivedRef | WAIVED | PASS | PASS | none | 1 |" 'S20-valid-waiver'
+      $waivedStructuralOverride=$originalResponsibilityTerminal.Replace("| 1 | PASS | PASS | PASS | PASS | $responsibilityEvidence |","| 1 | PASS | BLOCKED | PASS | PASS | $responsibilityEvidence |")
+      if($waivedStructuralOverride-ceq$originalResponsibilityTerminal){throw 'S20 auto-waive structural override mutation was a silent no-op'}
+      Write-Utf8 $responsibilityTerminalPath $waivedStructuralOverride;$waivedStructuralOverrideRef=Get-ImmutableReference $rendered.Run 'knowledge-a.md';Rebind-ImmutableReference $rendered.Run $rendered.ResponsibilityChains[0].artifact_refs[4] $waivedStructuralOverrideRef 'S20-auto-waive-responsibility-override';Assert-Observed (Invoke-FlexibleScope $fixtureRoot $rendered.Manifest) 'structural-assurance-blocked' 'scope-blocked' 'S20-auto-waive-responsibility-override';Write-Utf8 $responsibilityTerminalPath $originalResponsibilityTerminal;Rebind-ImmutableReference $rendered.Run $waivedStructuralOverrideRef $rendered.ResponsibilityChains[0].artifact_refs[4] 'S20-auto-waive-responsibility-override-restore'
       $waiverNegatives=@(
         @('availability probe','required test/build/baseline command','role'),
         @('not-started','started-without-correctness/regression-result','lifecycle'),
         @('resume-consumed','resume-required','resume'),
         @('effective_action: continue','effective_action: stop','waiver-body'),
         @('| ACT-001 | applicable | requested-key | key input | key output | evidence:key | TRACE-002 | implement | verified | not-applicable | not-applicable |','<!-- omitted requested-key seam -->', 'omitted-seam'),
         @('| ACT-002 | not-applicable-approved | test | no-selector input | no-selector output | evidence:na-test | TRACE-002 | not-applicable-approved | verified | approval:NA-ACT-002 | not-applicable |',"| ACT-002 | not-applicable-approved | test | no-selector input | no-selector output | evidence:na-test | TRACE-002 | not-applicable-approved | verified | approval:NA-ACT-002 | not-applicable |`n| ACT-003 | not-applicable-approved | test | extra input | extra output | evidence:extra | TRACE-002 | not-applicable-approved | verified | approval:NA-ACT-003 | not-applicable |",'extra-group'),
         @('| ACT-002 | not-applicable-approved | upstream-response | no-selector input | no-selector output | evidence:na-upstream | TRACE-002 | not-applicable-approved | verified | approval:NA-ACT-002 | not-applicable |','| ACT-003 | not-applicable-approved | upstream-response | no-selector input | no-selector output | evidence:na-upstream | TRACE-002 | not-applicable-approved | verified | approval:NA-ACT-002 | not-applicable |','group-id'),
         @('policy=compatibility-dual-path','policy=compatibility-dual-path-missing','router-dual-path'),
         @('| ACT-002 | not-applicable-approved | render | no-selector input | no-selector output | evidence:na-render | TRACE-002 | not-applicable-approved | verified | approval:NA-ACT-002 | not-applicable |','| ACT-002 | not-applicable-approved | render | no-selector input | no-selector output | evidence:na-render | TRACE-002 | not-applicable-approved | missing | approval:NA-ACT-002 | not-applicable |','na-state'),
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-handoff.Tests.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-handoff.Tests.ps1
index f225586..62f4305 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-handoff.Tests.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-handoff.Tests.ps1
@@ -1,21 +1,27 @@
 $ErrorActionPreference = 'Stop'
 
 $root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
 $contractPath = Join-Path $root 'contracts/file-responsibility-conformance.md'
 $validatorPath = Join-Path $root 'tests/validation/responsibility-conformance.validation.ps1'
+$rolloutValidatorPath = Join-Path $root 'tests/validation/architecture-review.validation.ps1'
+$migrateSkillPath = Join-Path $root 'skills/aitoolkit/migrate/SKILL.md'
 
 if (-not (Test-Path -LiteralPath $contractPath)) { throw 'Responsibility contract file is missing' }
 if (-not (Test-Path -LiteralPath $validatorPath)) { throw 'Responsibility handoff validator is missing' }
+if (-not (Test-Path -LiteralPath $rolloutValidatorPath)) { throw 'Responsibility rollout validator is missing' }
+if (-not (Test-Path -LiteralPath $migrateSkillPath)) { throw 'Migration orchestrator skill is missing' }
 
 . $validatorPath
+. $rolloutValidatorPath
 $contract = Get-Content -Raw -Encoding utf8 -LiteralPath $contractPath
+$migrateSkill = Get-Content -Raw -Encoding utf8 -LiteralPath $migrateSkillPath
 
 function New-HandoffArtifact {
   param(
     [Parameter(Mandatory)][string]$StepId,
     [Parameter(Mandatory)][string]$SourceArtifact,
     [string]$TaskUnit = 'WORK-ADMIN-LOCK',
     [string]$Tree = 'PASS',
     [string]$Responsibility = 'PASS',
     [string]$Verification = 'PASS',
     [string]$Architecture = 'PASS',
@@ -86,11 +92,75 @@ Assert-HandoffRejected 'rejects a downstream artifact with no responsibility han
 Assert-HandoffRejected 'rejects a downstream aggregate PASS that hides responsibility BLOCKED' $verification (New-HandoffArtifact -StepId '13-verify-parity' -SourceArtifact 'verification-report.md' -Responsibility 'BLOCKED' -Architecture 'PASS') 'responsibility-waiver-forbidden'
 Assert-HandoffRejected 'rejects an altered responsibility evidence reference' $verification (New-HandoffArtifact -StepId '13-verify-parity' -SourceArtifact 'verification-report.md' -Evidence 'review-report.md#other-evidence') 'responsibility-evidence-missing'
 Assert-HandoffRejected 'rejects unsupported responsibility contract version' $verification (($parity -replace '(?m)^\| 1 \|', '| 2 |') -replace '(?m)^  version: 1$', '  version: 2') 'responsibility-contract-version-invalid'
 Assert-HandoffRejected 'rejects a cross-run or other-work-item provenance handoff' $verification (New-HandoffArtifact -StepId '13-verify-parity' -SourceArtifact 'verification-report.md' -TaskUnit 'WORK-OTHER') 'responsibility-evidence-missing'
 Assert-HandoffRejected 'rejects a handoff that skips an immediate predecessor stage' $verification (New-HandoffArtifact -StepId '15-knowledge-base' -SourceArtifact 'verification-report.md') 'responsibility-evidence-missing'
 
 $blockedReview = New-HandoffArtifact -StepId '11-ai-review' -SourceArtifact 'implementation-report.md' -Responsibility 'BLOCKED' -Architecture 'BLOCKED'
 $waivedVerification = New-HandoffArtifact -StepId '12-verification-testing' -SourceArtifact 'review-report.md' -Architecture 'PASS' -Waiver 'approval_source: auto-waive'
 Assert-HandoffRejected 'runtime waiver cannot overwrite a blocked responsibility handoff' $blockedReview $waivedVerification 'responsibility-waiver-forbidden'
 
+function Assert-RolloutAccepted {
+  param([string]$Name, [string]$Text)
+  $diagnostics = @(& $script:MigrationResponsibilityRolloutValidator $Text)
+  if ($diagnostics.Count -ne 0) {
+    throw "$Name should pass but got: $($diagnostics -join '; ')"
+  }
+  Write-Output "PASS: $Name"
+}
+
+function Assert-RolloutRejected {
+  param([string]$Name, [string]$From, [string]$To)
+  $mutated = $migrateSkill.Replace($From, $To)
+  if ($mutated -ceq $migrateSkill) { throw "$Name mutation was a silent no-op" }
+  $diagnostics = @(& $script:MigrationResponsibilityRolloutValidator $mutated)
+  if ($diagnostics -notcontains 'migration-responsibility-rollout-invalid') {
+    throw "$Name expected migration-responsibility-rollout-invalid but got: $($diagnostics -join '; ')"
+  }
+  Write-Output "PASS: $Name"
+}
+
+Assert-RolloutAccepted 'migration orchestrator has a complete v1 responsibility rollout contract' $migrateSkill
+Assert-RolloutRejected 'rollout derives architecture from all three structural sub-verdicts' `
+  'v1 exact handoff; Tree PASS; Responsibility PASS; Verification PASS; immutable evidence resolves' `
+  'v1 aggregate caller PASS'
+Assert-RolloutRejected 'rollout rejects a missing immutable evidence link' `
+  'missing or mismatched immutable evidence link' `
+  'missing evidence is accepted'
+Assert-RolloutRejected 'queue and resume resolve current immutable responsibility authority before production' `
+  'Queue selection, resume, and dependency unlock require the predecessor handoff to resolve exactly one immutable authority artifact with approved/complete/human lifecycle, current run/master-spec/master-plan binding, and exact v1 PASS sub-verdicts; absent, pre-v1, mismatched, stale, cross-run, or caller-attested fields derive BLOCKED before production.' `
+  'Queue selection may trust caller-attested responsibility fields.'
+Assert-RolloutRejected 'terminal responsibility authority binds approved mode and current-run SHA provenance' `
+  'The terminal chain uses the approved migration-unit mode from its step-8 authority record, never a terminal or chain self-label; the initial review is approved/complete/human, every chain artifact stays in the current run and binds the current master spec/plan/work item, and each source-diff SHA pair exactly equals immutable Task Provenance.' `
+  'The terminal chain may self-label its mode and provenance.'
+Assert-RolloutRejected 'rollout rejects mixed responsibility versions' `
+  'mixed v1/v2 or cross-run evidence' `
+  'mixed versions are compatible'
+Assert-RolloutRejected 'completed pre-v1 artifacts remain historical-only' `
+  '| completed pre-v1 artifact | historical-only | not executable |' `
+  '| completed pre-v1 artifact | executable | PASS |'
+Assert-RolloutRejected 'in-progress pre-v1 artifacts cannot resume' `
+  '| in-progress pre-v1 artifact | blocked | BLOCKED | no resume; no production mutation; no dependent selection |' `
+  '| in-progress pre-v1 artifact | compatible | PASS | resume |'
+Assert-RolloutRejected 'responsibility blockers prevent dependent selection' `
+  'scope-blocked; next eligible item: none; no dependent selection' `
+  'scope-in-progress; select dependent item'
+Assert-RolloutRejected 'responsibility blockers stop all downstream completion' `
+  'stop before parity, regression, delivery, KB, and terminal completion' `
+  'continue to parity, regression, delivery, KB, and terminal completion'
+Assert-RolloutRejected 'terminal evidence binds the work-item artifact and mode-aware final chain artifact without conflating them' `
+  'Work Item Terminal Evidence references only the immutable work-item terminal artifact; its exact v1 handoff Evidence References equals the final artifact of the mode-aware ordered chain, and the terminal report Evidence Index uses that same final artifact for each terminal-success item only.' `
+  'Work Item Terminal Evidence may reference any artifact in a caller-provided chain.'
+Assert-RolloutRejected 'responsibility blockers require an approved design and master-plan revision' `
+  'approved design/master-plan revision required' `
+  'automatic resume allowed'
+Assert-RolloutRejected 'auto-waive cannot override a structural sub-verdict' `
+  'Runtime `auto-waive` never changes Tree, Responsibility, or Verification Ownership sub-verdicts.' `
+  'Runtime `auto-waive` may change a structural sub-verdict.'
+Assert-RolloutRejected 'Phase 1 does not create Phase 2 remediation automatically' `
+  'Do not create a Phase 2 remediation artifact or work item automatically.' `
+  'Create a Phase 2 remediation work item automatically.'
+Assert-RolloutRejected 'post-implementation responsibility mismatch preserves the full safe-stop chain' `
+  'implementation `draft/blocked` -> AI review `Reject` -> work item `blocked` -> dependent item non-eligible -> parity/regression/delivery/KB/terminal completion blocked -> approved design/master-plan revision required' `
+  'implementation mismatch -> continue downstream'
+
 Write-Output 'PASS: responsibility handoff scenarios'
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/scope-engine.Tests.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/scope-engine.Tests.ps1
index d59e0d8..458ca13 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/scope-engine.Tests.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/scope-engine.Tests.ps1
@@ -54,41 +54,61 @@ function Invoke-ScopeScenario([hashtable]$Fixture) {
           work_item_id = [string]$attempt.work_item_id
           plan_revision = [int]$attempt.plan_revision
           status = [string]$attempt.status
           immutable = $true
         })
       }
     }
     foreach ($artifactField in @('terminal_artifact', 'blocker_artifact', 'decision_artifact')) {
       if ($Fixture.ContainsKey($artifactField)) { $resolvedArtifacts.Add($Fixture[$artifactField]) }
     }
+    foreach ($artifactListField in @('terminal_artifacts', 'responsibility_evidence_artifacts', 'responsibility_chain_artifacts', 'responsibility_authority_artifacts')) {
+      if ($Fixture.ContainsKey($artifactListField)) {
+        foreach ($artifact in @($Fixture[$artifactListField])) { $resolvedArtifacts.Add($artifact) }
+      }
+    }
     if ($Fixture.ContainsKey('terminal_scope_report')) {
       $Fixture.terminal_scope_report_ref = [string]$Fixture.terminal_scope_report.artifact_reference
       $resolvedArtifacts.Add($Fixture.terminal_scope_report)
     }
     $Fixture.orchestration_context.resolved_artifacts = @($resolvedArtifacts)
   }
+  if (@('select', 'transition', 'complete-scope') -ccontains [string]$Fixture.operation) {
+    $resolvedArtifacts = [Collections.Generic.List[object]]::new()
+    foreach ($artifact in @($Fixture.orchestration_context.resolved_artifacts)) { $resolvedArtifacts.Add($artifact) }
+    foreach ($item in @($Fixture.work_items)) {
+      $authorityReference = [string]$item.responsibility_evidence
+      if (
+        [string]::IsNullOrWhiteSpace($authorityReference) -or
+        $authorityReference -ceq 'none' -or
+        @($resolvedArtifacts | Where-Object { [string]$_.artifact_reference -ceq $authorityReference }).Count -gt 0
+      ) { continue }
+      $resolvedArtifacts.Add((New-QueueResponsibilityArtifact $authorityReference $item))
+    }
+    $Fixture.orchestration_context.resolved_artifacts = @($resolvedArtifacts)
+  }
   $json = $Fixture | ConvertTo-Json -Depth 20 -Compress
   return Test-ScopeEngine $toolkitRoot $json
 }
 
 function New-ApprovedOrchestrationContext {
   return @{
     requested_scope = @{
       kind = 'module'
       id = 'ADMIN'
       statement = 'Migrate the complete Admin module'
       source = 'user'
       resolution_evidence = 'conversation:scope-approved'
     }
     master_spec_id = 'SPEC-ADMIN-001'
     master_plan_id = 'PLAN-ADMIN-001'
+    run_id = 'RUN-ADMIN-001'
     master_spec_ref = 'runs/master-spec@2.md'
     master_plan_ref = 'runs/master-plan@3.md'
     latest_spec_revision = 2
     spec_revisions = @(
       @{ artifact_id = 'SPEC-ADMIN-001'; revision = 1; supersedes = 'not-applicable'; status = 'approved'; result = 'complete'; approval_reference = 'approval:spec@1'; freshness_evidence = 'review:spec@1'; stale = $false },
       @{ artifact_reference = 'runs/master-spec@2.md'; artifact_type = 'migration-master-spec'; artifact_id = 'SPEC-ADMIN-001'; revision = 2; supersedes = 'SPEC-ADMIN-001@1'; immutable = $true; status = 'approved'; result = 'complete'; approval_reference = 'approval:spec@2'; freshness_evidence = 'review:spec@2'; stale = $false }
     )
     current_plan_revision = 3
     plan_revisions = @(
       @{ artifact_id = 'PLAN-ADMIN-001'; revision = 1; supersedes = 'not-applicable'; status = 'approved'; result = 'complete'; approval_reference = 'approval:plan@1'; freshness_evidence = 'review:plan@1'; master_spec_id = 'SPEC-ADMIN-001'; master_spec_revision = 1; stale = $false },
@@ -109,28 +129,220 @@ function New-WorkItem(
     work_item_id = $Id
     required = $Required
     optional_execution_approved = $false
     dependencies = $Dependencies
     plan_order = $PlanOrder
     status = $Status
     approval_revision = 3
     has_blocker = $false
     adapter_kind = 'none'
     adapter_valid = $true
+    tree_conformance = 'PASS'
+    responsibility_conformance = 'PASS'
+    verification_ownership = 'PASS'
     architecture_state = 'PASS'
     selector_schema_state = 'PASS'
+    mode_constraint = 'incremental/preserve-existing'
+    responsibility_evidence = "runs/responsibility-authority-$Id.md"
     terminal_evidence = 'none'
     latest_attempt = 'none'
     attempt_history = @()
   }
 }
 
+function New-QueueResponsibilityArtifact([string]$Reference, [object]$Item) {
+  return @{
+    artifact_reference = $Reference
+    artifact_type = 'migration-work-item-responsibility-authority'
+    immutable = $true
+    status = 'approved'
+    result = 'complete'
+    approval_source = 'human'
+    run_id = 'RUN-ADMIN-001'
+    master_spec_ref = 'runs/master-spec@2.md'
+    master_spec_id = 'SPEC-ADMIN-001'
+    master_spec_revision = 2
+    master_plan_ref = 'runs/master-plan@3.md'
+    master_plan_id = 'PLAN-ADMIN-001'
+    master_plan_revision = 3
+    work_item_id = [string]$Item.work_item_id
+    mode_constraint = [string]$Item.mode_constraint
+    responsibility_handoff = @{
+      responsibility_contract_version = 1
+      tree_conformance = 'PASS'
+      responsibility_conformance = 'PASS'
+      verification_ownership = 'PASS'
+      architecture_state = 'PASS'
+      evidence_reference = 'runs/master-plan@3.md'
+    }
+  }
+}
+
+function New-ResponsibilityEvidenceArtifact([string]$Reference, [string]$WorkItemId) {
+  return @{
+    artifact_reference = $Reference
+    artifact_type = 'architecture-responsibility-review'
+    immutable = $true
+    work_item_id = $WorkItemId
+    responsibility_contract_version = 1
+    tree_conformance = 'PASS'
+    responsibility_conformance = 'PASS'
+    verification_ownership = 'PASS'
+    architecture_state = 'PASS'
+    evidence_reference = "source-diff:$WorkItemId"
+  }
+}
+
+function New-ResponsibilityChain([string]$Prefix, [string]$WorkItemId, [string]$ModeConstraint = 'incremental/preserve-existing') {
+  $steps = if ($ModeConstraint -ceq 'greenfield/design-new') {
+    @('11-ai-review', '12-verification-testing', '13-verify-parity', '15-knowledge-base')
+  }
+  else {
+    @('11-ai-review', '12-verification-testing', '13-verify-parity', '14-verify-regression', '15-knowledge-base')
+  }
+  $artifacts = [Collections.Generic.List[object]]::new()
+  $references = [Collections.Generic.List[string]]::new()
+  $previousReference = 'implementation-report.md'
+  foreach ($step in $steps) {
+    $reference = "$Prefix-$step.md"
+    $artifact = @{
+      artifact_reference = $reference
+      artifact_type = 'migration-responsibility-handoff'
+      immutable = $true
+      run_id = 'RUN-ADMIN-001'
+      master_spec_ref = 'runs/master-spec@2.md'
+      master_spec_id = 'SPEC-ADMIN-001'
+      master_spec_revision = 2
+      master_plan_ref = 'runs/master-plan@3.md'
+      master_plan_id = 'PLAN-ADMIN-001'
+      master_plan_revision = 3
+      work_item_id = $WorkItemId
+      mode_constraint = $ModeConstraint
+      step_id = $step
+      status = 'approved'
+      result = 'complete'
+      approval_source = 'human'
+      source_artifact_reference = $previousReference
+      responsibility_contract_version = 1
+      tree_conformance = 'PASS'
+      responsibility_conformance = 'PASS'
+      verification_ownership = 'PASS'
+      architecture_state = 'PASS'
+      task_base_sha = '1111111111111111111111111111111111111111'
+      final_tree_sha = '2222222222222222222222222222222222222222'
+      evidence_reference = "source-diff:1111111111111111111111111111111111111111..2222222222222222222222222222222222222222#$WorkItemId"
+    }
+    $artifacts.Add($artifact)
+    $references.Add($reference)
+    $previousReference = $reference
+  }
+  return [pscustomobject]@{
+    WorkItemId = $WorkItemId
+    ModeConstraint = $ModeConstraint
+    Artifacts = @($artifacts)
+    References = @($references)
+    FinalReference = [string]$references[-1]
+  }
+}
+
+function New-TerminalResponsibilityArtifact(
+  [string]$Reference,
+  [string]$WorkItemId,
+  [string]$Status,
+  [string]$EvidenceReference,
+  [string[]]$ChainReferences = @(),
+  [string]$ModeConstraint = 'incremental/preserve-existing'
+) {
+  return @{
+    artifact_reference = $Reference
+    artifact_type = 'migration-work-item-terminal'
+    immutable = $true
+    run_id = 'RUN-ADMIN-001'
+    master_spec_ref = 'runs/master-spec@2.md'
+    master_spec_id = 'SPEC-ADMIN-001'
+    master_spec_revision = 2
+    master_plan_ref = 'runs/master-plan@3.md'
+    master_plan_id = 'PLAN-ADMIN-001'
+    master_plan_revision = 3
+    work_item_id = $WorkItemId
+    plan_revision = 3
+    status = $Status
+    mode_constraint = $ModeConstraint
+    responsibility_chain_references = @($ChainReferences)
+    responsibility_handoff = @{
+      responsibility_contract_version = 1
+      tree_conformance = 'PASS'
+      responsibility_conformance = 'PASS'
+      verification_ownership = 'PASS'
+      architecture_state = 'PASS'
+      evidence_reference = $EvidenceReference
+    }
+  }
+}
+
+function New-TerminalScopeReport(
+  [string]$Reference,
+  [object[]]$Items,
+  [object[]]$Chains,
+  [bool]$IncludeEvidenceIndex = $true
+) {
+  $chainByWorkItem = @{}
+  foreach ($chain in @($Chains)) { $chainByWorkItem[[string]$chain.WorkItemId] = $chain }
+  $reportRows = [Collections.Generic.List[object]]::new()
+  $evidenceRows = [Collections.Generic.List[object]]::new()
+  $evidenceReferences = [Collections.Generic.List[string]]::new()
+  foreach ($item in @($Items)) {
+    $reportRows.Add(@{
+      work_item_id = [string]$item.work_item_id
+      status = [string]$item.status
+      terminal_evidence = [string]$item.terminal_evidence
+      architecture_state = [string]$item.architecture_state
+      selector_schema_state = [string]$item.selector_schema_state
+    })
+    if (@('complete', 'cancelled-approved', 'not-applicable-approved') -ccontains [string]$item.status) {
+      $chain = $chainByWorkItem[[string]$item.work_item_id]
+      if ($null -ne $chain) {
+        $evidenceReferences.Add([string]$chain.FinalReference)
+        $evidenceRows.Add(@{
+          evidence_id = "EVIDENCE-$([string]$item.work_item_id)"
+          artifact_reference = [string]$chain.FinalReference
+          work_item_id = [string]$item.work_item_id
+          purpose = 'architecture-responsibility-sub-verdicts'
+        })
+      }
+    }
+  }
+  $report = @{
+    artifact_reference = $Reference
+    artifact_type = 'migration-scope-terminal-report'
+    run_id = 'RUN-ADMIN-001'
+    master_spec_ref = 'runs/master-spec@2.md'
+    master_spec_id = 'SPEC-ADMIN-001'
+    master_spec_revision = 2
+    master_plan_ref = 'runs/master-plan@3.md'
+    master_plan_id = 'PLAN-ADMIN-001'
+    master_plan_revision = 3
+    immutable = $true
+    responsibility_handoff = @{
+      responsibility_contract_version = 1
+      tree_conformance = 'PASS'
+      responsibility_conformance = 'PASS'
+      verification_ownership = 'PASS'
+      architecture_state = 'PASS'
+      evidence_references = @($evidenceReferences)
+    }
+    items = @($reportRows)
+  }
+  if ($IncludeEvidenceIndex) { $report.evidence_index = @($evidenceRows) }
+  return $report
+}
+
 if (-not (Test-Path -LiteralPath $validatorPath -PathType Leaf)) {
   Write-Output 'FAIL: Missing scope-engine validator'
   exit 1
 }
 . $validatorPath
 
 # Scope resolution: the production break caught here is selecting an item before
 # preserving the user-requested boundary, or inventing a migration-unit adapter.
 foreach ($kind in @('module', 'feature', 'project', 'task')) {
   $resolved = Invoke-ScopeScenario @{
@@ -270,20 +482,70 @@ $generic = Invoke-ScopeScenario @{
   scenario_type = 'scope-engine'
   operation = 'select'
   current_plan_revision = 3
   work_items = @($genericItem)
 }
 Assert-Equal $generic.result 'selected' 'Generic work item must be selectable without a migration unit'
 Assert-Equal $generic.work_item_id 'WORK-GENERIC-SHELL' 'Generic selector must return the work item ID'
 Assert-Equal $generic.adapter_kind 'none' 'Generic selector must preserve adapter kind none'
 Assert-Equal $generic.migration_unit_id 'not-applicable' 'Generic selector must not invent a UNIT ID'
 
+# Queue/resume responsibility state is evidence-derived. Scalar PASS fields on
+# a caller row cannot replace the current immutable v1 authority artifact.
+$missingQueueAuthority = New-WorkItem 'WORK-ADMIN-MISSING-QUEUE-AUTHORITY' 1
+$missingQueueAuthority.responsibility_evidence = 'none'
+$missingQueueAuthorityResult = Invoke-ScopeScenario @{
+  scenario_type = 'scope-engine'; operation = 'select'
+  work_items = @($missingQueueAuthority)
+}
+Assert-Equal $missingQueueAuthorityResult.result 'scope-blocked' 'Missing responsibility authority must block before queue selection'
+Assert-Equal $missingQueueAuthorityResult.reason 'structural-assurance-blocked' 'Missing queue authority must derive the structural blocker'
+Assert-Equal $missingQueueAuthorityResult.work_item_id '' 'Missing queue authority must leave next eligible item empty'
+
+$preV1Resume = New-WorkItem 'WORK-ADMIN-PRE-V1-RESUME' 1 @() 'in-progress'
+$preV1Resume.latest_attempt = 'ATTEMPT-WORK-ADMIN-PRE-V1-RESUME-01'
+$preV1Resume.attempt_history = @(
+  @{ attempt_id = 'ATTEMPT-WORK-ADMIN-PRE-V1-RESUME-01'; work_item_id = 'WORK-ADMIN-PRE-V1-RESUME'; plan_revision = 3; status = 'in-progress'; artifact_reference = 'runs/pre-v1-resume-01.md' }
+)
+$preV1Authority = New-QueueResponsibilityArtifact $preV1Resume.responsibility_evidence $preV1Resume
+$preV1Authority.Remove('responsibility_handoff')
+$preV1ResumeResult = Invoke-ScopeScenario @{
+  scenario_type = 'scope-engine'; operation = 'select'
+  work_items = @($preV1Resume)
+  responsibility_authority_artifacts = @($preV1Authority)
+}
+Assert-Equal $preV1ResumeResult.result 'scope-blocked' 'An in-progress pre-v1 item must not resume from scalar PASS fields'
+Assert-Equal $preV1ResumeResult.reason 'structural-assurance-blocked' 'Pre-v1 resume evidence must derive BLOCKED'
+
+$mismatchedDependency = New-WorkItem 'WORK-ADMIN-MISMATCHED-DEPENDENCY' 1 @() 'complete'
+$dependentAfterMismatch = New-WorkItem 'WORK-ADMIN-AFTER-MISMATCH' 2 @('WORK-ADMIN-MISMATCHED-DEPENDENCY')
+$mismatchedDependencyAuthority = New-QueueResponsibilityArtifact $mismatchedDependency.responsibility_evidence $mismatchedDependency
+$mismatchedDependencyAuthority.work_item_id = 'WORK-ADMIN-FOREIGN'
+$mismatchedDependencyResult = Invoke-ScopeScenario @{
+  scenario_type = 'scope-engine'; operation = 'select'
+  work_items = @($mismatchedDependency, $dependentAfterMismatch)
+  responsibility_authority_artifacts = @($mismatchedDependencyAuthority)
+}
+Assert-Equal $mismatchedDependencyResult.result 'scope-blocked' 'Mismatched terminal dependency authority must not unlock its dependent'
+Assert-Equal $mismatchedDependencyResult.work_item_id '' 'A dependent must remain unselected when predecessor evidence is mismatched'
+
+$crossRunAuthorityItem = New-WorkItem 'WORK-ADMIN-CROSS-RUN-AUTHORITY' 1
+$crossRunAuthority = New-QueueResponsibilityArtifact $crossRunAuthorityItem.responsibility_evidence $crossRunAuthorityItem
+$crossRunAuthority.run_id = 'RUN-FOREIGN-999'
+$crossRunAuthorityResult = Invoke-ScopeScenario @{
+  scenario_type = 'scope-engine'; operation = 'select'
+  work_items = @($crossRunAuthorityItem)
+  responsibility_authority_artifacts = @($crossRunAuthority)
+}
+Assert-Equal $crossRunAuthorityResult.result 'scope-blocked' 'Cross-run responsibility authority must not select a work item'
+Assert-Equal $crossRunAuthorityResult.work_item_id '' 'Cross-run queue evidence must leave next eligible item empty'
+
 # Deterministic selection: depth wins before Plan Order, then Plan Order wins.
 $rootLater = New-WorkItem 'WORK-ADMIN-ZETA' 9
 $rootFirst = New-WorkItem 'WORK-ADMIN-ALPHA' 4
 $deepEarly = New-WorkItem 'WORK-ADMIN-DEEP' 1 @('WORK-ADMIN-ZETA')
 $ordered = Invoke-ScopeScenario @{
   scenario_type = 'scope-engine'
   operation = 'select'
   current_plan_revision = 3
   work_items = @($deepEarly, $rootLater, $rootFirst)
 }
@@ -291,36 +553,78 @@ Assert-Equal $ordered.result 'selected' 'Valid graph must select one item'
 Assert-Equal $ordered.work_item_id 'WORK-ADMIN-ALPHA' 'Dependency depth must sort before Plan Order'
 
 # Every eligibility predicate is independently required. The broken lower-order
 # item must be skipped and the valid fallback must be selected.
 $eligibilityMutations = @(
   @{ Name = 'required-or-approved-optional'; Apply = { param($item) $item.required = $false; $item.optional_execution_approved = $false } },
   @{ Name = 'pending-or-ready'; Apply = { param($item) $item.status = 'proposed' } },
   @{ Name = 'current-approval'; Apply = { param($item) $item.approval_revision = 2 } },
   @{ Name = 'no-blocker'; Apply = { param($item) $item.has_blocker = $true } },
   @{ Name = 'adapter-valid'; Apply = { param($item) $item.adapter_kind = 'task'; $item.adapter_valid = $false } },
-  @{ Name = 'architecture-pass'; Apply = { param($item) $item.architecture_state = 'BLOCKED' } },
   @{ Name = 'selector-schema-pass'; Apply = { param($item) $item.selector_schema_state = 'BLOCKED' } }
 )
 foreach ($mutation in $eligibilityMutations) {
   $candidate = New-WorkItem 'WORK-ADMIN-CANDIDATE' 1
   & $mutation.Apply $candidate
   $fallback = New-WorkItem 'WORK-ADMIN-FALLBACK' 2
   $selection = Invoke-ScopeScenario @{
     scenario_type = 'scope-engine'
     operation = 'select'
     current_plan_revision = 3
     work_items = @($candidate, $fallback)
   }
   Assert-Equal $selection.work_item_id 'WORK-ADMIN-FALLBACK' "Eligibility predicate '$($mutation.Name)' must reject the candidate"
 }
 
+# The production break caught here is treating an independent fallback as safe
+# after any structural sub-verdict in the approved queue has blocked. The queue
+# must stop globally so no parity/regression/delivery/KB successor can advance.
+$structuralBlockers = @(
+  @{ Name = 'Tree'; Field = 'tree_conformance' },
+  @{ Name = 'Responsibility'; Field = 'responsibility_conformance' },
+  @{ Name = 'Verification Ownership'; Field = 'verification_ownership' },
+  @{ Name = 'Architecture aggregate'; Field = 'architecture_state' }
+)
+foreach ($blocker in $structuralBlockers) {
+  $blockedCandidate = New-WorkItem "WORK-ADMIN-$($blocker.Name.ToUpperInvariant().Replace(' ', '-'))-BLOCKED" 1
+  $blockedCandidate[$blocker.Field] = 'BLOCKED'
+  $independentFallback = New-WorkItem 'WORK-ADMIN-INDEPENDENT-FALLBACK' 2
+  $blockedSelection = Invoke-ScopeScenario @{
+    scenario_type = 'scope-engine'; operation = 'select'
+    work_items = @($blockedCandidate, $independentFallback)
+  }
+  Assert-Equal $blockedSelection.result 'scope-blocked' "$($blocker.Name) BLOCKED must stop the entire queue"
+  Assert-Equal $blockedSelection.reason 'structural-assurance-blocked' "$($blocker.Name) BLOCKED must emit the stable structural diagnostic"
+  Assert-Equal $blockedSelection.scope_status 'scope-blocked' "$($blocker.Name) BLOCKED must set scope-blocked"
+  Assert-Equal $blockedSelection.work_item_id '' "$($blocker.Name) BLOCKED must leave next eligible item as none"
+}
+
+$allResponsibilityBlocked = New-WorkItem 'WORK-ADMIN-ALL-RESPONSIBILITY-BLOCKED' 1
+$allResponsibilityBlocked.responsibility_conformance = 'BLOCKED'
+$allResponsibilityBlockedSelection = Invoke-ScopeScenario @{
+  scenario_type = 'scope-engine'; operation = 'select'
+  work_items = @($allResponsibilityBlocked)
+}
+Assert-Equal $allResponsibilityBlockedSelection.result 'scope-blocked' 'A required responsibility blocker must stop the queue before dependent work can be selected'
+Assert-Equal $allResponsibilityBlockedSelection.scope_status 'scope-blocked' 'A responsibility blocker must set scope-blocked'
+
+$responsibilityBlockedRoot = New-WorkItem 'WORK-ADMIN-RESPONSIBILITY-ROOT' 1
+$responsibilityBlockedRoot.responsibility_conformance = 'BLOCKED'
+$responsibilityDependent = New-WorkItem 'WORK-ADMIN-RESPONSIBILITY-DEPENDENT' 2 @('WORK-ADMIN-RESPONSIBILITY-ROOT')
+$responsibilityChainSelection = Invoke-ScopeScenario @{
+  scenario_type = 'scope-engine'; operation = 'select'
+  work_items = @($responsibilityBlockedRoot, $responsibilityDependent)
+}
+Assert-Equal $responsibilityChainSelection.result 'scope-blocked' 'A responsibility mismatch must stop the whole dependent chain'
+Assert-Equal $responsibilityChainSelection.reason 'structural-assurance-blocked' 'A responsibility mismatch without a more specific diagnostic must use the stable structural diagnostic'
+Assert-Equal $responsibilityChainSelection.work_item_id '' 'No dependent item may be selected after a responsibility mismatch'
+
 $dependencyBlocked = New-WorkItem 'WORK-ADMIN-DEPENDENCY' 1 @() 'blocked'
 $dependent = New-WorkItem 'WORK-ADMIN-DEPENDENT' 2 @('WORK-ADMIN-DEPENDENCY')
 $blockedSelection = Invoke-ScopeScenario @{
   scenario_type = 'scope-engine'
   operation = 'select'
   current_plan_revision = 3
   work_items = @($dependencyBlocked, $dependent)
 }
 Assert-Equal $blockedSelection.result 'scope-blocked' 'Hard blocker must prevent dependent execution'
 Assert-Equal $blockedSelection.scope_status 'scope-blocked' 'Required blocker must block the scope'
@@ -486,20 +790,36 @@ $latestPointerMismatch.attempt_history = @(
   @{ attempt_id = 'ATTEMPT-WORK-ADMIN-LATEST-POINTER-01'; work_item_id = 'WORK-ADMIN-LATEST-POINTER'; plan_revision = 3; status = 'in-progress'; artifact_reference = 'runs/latest-pointer-01.md' },
   @{ attempt_id = 'ATTEMPT-WORK-ADMIN-LATEST-POINTER-02'; work_item_id = 'WORK-ADMIN-LATEST-POINTER'; plan_revision = 3; status = 'complete'; artifact_reference = 'runs/latest-pointer-02.md' }
 )
 $activeLatestMismatch = Invoke-ScopeScenario @{
   scenario_type = 'scope-engine'; operation = 'select'; current_plan_revision = 3
   work_items = @($latestPointerMismatch)
 }
 Assert-Equal $activeLatestMismatch.result 'plan-invalid' 'Sole active attempt must equal the in-progress item latest_attempt pointer'
 Assert-Equal $activeLatestMismatch.reason 'active-attempt-latest-mismatch' 'Resume must identify stale active-attempt pointer before terminal reconciliation'
 
+$structurallyBlockedResume = New-WorkItem 'WORK-ADMIN-STRUCTURAL-RESUME' 1 @() 'in-progress'
+$structurallyBlockedResume.latest_attempt = 'ATTEMPT-WORK-ADMIN-STRUCTURAL-RESUME-01'
+$structurallyBlockedResume.responsibility_conformance = 'BLOCKED'
+$structurallyBlockedResume.responsibility_diagnostic = 'responsibility-owner-mismatch'
+$structurallyBlockedResume.architecture_state = 'BLOCKED'
+$structurallyBlockedResume.attempt_history = @(
+  @{ attempt_id = 'ATTEMPT-WORK-ADMIN-STRUCTURAL-RESUME-01'; work_item_id = 'WORK-ADMIN-STRUCTURAL-RESUME'; plan_revision = 3; status = 'in-progress'; artifact_reference = 'runs/structural-resume-01.md' }
+)
+$blockedResumeSelection = Invoke-ScopeScenario @{
+  scenario_type = 'scope-engine'; operation = 'select'; current_plan_revision = 3
+  work_items = @($structurallyBlockedResume)
+}
+Assert-Equal $blockedResumeSelection.result 'scope-blocked' 'Structural assurance must stop an in-progress item before resume reconciliation'
+Assert-Equal $blockedResumeSelection.reason 'responsibility-owner-mismatch' 'Blocked resume must preserve the responsibility diagnostic'
+Assert-Equal $blockedResumeSelection.work_item_id '' 'Blocked in-progress work must not resume production'
+
 $forgedReadyResume = New-WorkItem 'WORK-ADMIN-FORGED-READY-RESUME' 1 @() 'ready'
 $forgedReadyResume.latest_attempt = 'ATTEMPT-WORK-ADMIN-FORGED-READY-RESUME-01'
 $forgedReadyResume.attempt_history = @(
   @{ attempt_id = 'ATTEMPT-WORK-ADMIN-FORGED-READY-RESUME-01'; work_item_id = 'WORK-ADMIN-FORGED-READY-RESUME'; plan_revision = 3; status = 'in-progress'; artifact_reference = 'runs/forged-ready-resume-01.md' }
 )
 $forgedReadySelection = Invoke-ScopeScenario @{
   scenario_type = 'scope-engine'; operation = 'select'; current_plan_revision = 3
   work_items = @($forgedReadyResume)
 }
 Assert-Equal $forgedReadySelection.result 'plan-invalid' 'Selection must not choose an item that owns an active attempt under forged ready state'
@@ -513,38 +833,235 @@ $partialCompletion = Invoke-ScopeScenario @{
   scenario_type = 'scope-engine'
   operation = 'complete-scope'
   work_items = @($completeItem, $pendingItem)
 }
 Assert-Equal $partialCompletion.scope_status 'scope-in-progress' 'One complete item cannot complete a scope with required work pending'
 
 $cancelled = New-WorkItem 'WORK-ADMIN-CANCELLED' 2 @() 'cancelled-approved'
 $cancelled.terminal_evidence = 'decisions/cancelled.md'
 $notApplicable = New-WorkItem 'WORK-ADMIN-NA' 3 @() 'not-applicable-approved'
 $notApplicable.terminal_evidence = 'decisions/not-applicable.md'
+$completeReview = New-ResponsibilityEvidenceArtifact 'runs/review-complete.md' $completeItem.work_item_id
+$cancelledReview = New-ResponsibilityEvidenceArtifact 'runs/review-cancelled.md' $cancelled.work_item_id
+$notApplicableReview = New-ResponsibilityEvidenceArtifact 'runs/review-not-applicable.md' $notApplicable.work_item_id
+$completeChain = New-ResponsibilityChain 'runs/complete-chain' $completeItem.work_item_id
+$cancelledChain = New-ResponsibilityChain 'runs/cancelled-chain' $cancelled.work_item_id
+$notApplicableChain = New-ResponsibilityChain 'runs/not-applicable-chain' $notApplicable.work_item_id
+$completeTerminal = New-TerminalResponsibilityArtifact $completeItem.terminal_evidence $completeItem.work_item_id $completeItem.status $completeChain.FinalReference $completeChain.References $completeChain.ModeConstraint
+$cancelledTerminal = New-TerminalResponsibilityArtifact $cancelled.terminal_evidence $cancelled.work_item_id $cancelled.status $cancelledChain.FinalReference $cancelledChain.References $cancelledChain.ModeConstraint
+$notApplicableTerminal = New-TerminalResponsibilityArtifact $notApplicable.terminal_evidence $notApplicable.work_item_id $notApplicable.status $notApplicableChain.FinalReference $notApplicableChain.References $notApplicableChain.ModeConstraint
+$allCompleteReport = New-TerminalScopeReport 'runs/scope-terminal.md' @($completeItem, $cancelled, $notApplicable) @($completeChain, $cancelledChain, $notApplicableChain)
 $allComplete = Invoke-ScopeScenario @{
   scenario_type = 'scope-engine'
   operation = 'complete-scope'
   work_items = @($completeItem, $cancelled, $notApplicable)
+  terminal_artifacts = @($completeTerminal, $cancelledTerminal, $notApplicableTerminal)
+  responsibility_chain_artifacts = @($completeChain.Artifacts + $cancelledChain.Artifacts + $notApplicableChain.Artifacts)
+  terminal_scope_report = $allCompleteReport
+}
+Assert-Equal $allComplete.scope_status 'scope-complete' 'All required terminal-success items with scope evidence must complete the scope'
+
+$missingEvidenceIndexReport = New-TerminalScopeReport 'runs/scope-terminal-missing-index.md' @($completeItem) @($completeChain) $false
+$missingEvidenceIndex = Invoke-ScopeScenario @{
+  scenario_type = 'scope-engine'; operation = 'complete-scope'
+  work_items = @($completeItem)
+  terminal_artifacts = @($completeTerminal)
+  responsibility_chain_artifacts = @($completeChain.Artifacts)
+  terminal_scope_report = $missingEvidenceIndexReport
+}
+Assert-Equal $missingEvidenceIndex.scope_status 'scope-blocked' 'Scope completion must require the terminal Evidence Index'
+Assert-Equal $missingEvidenceIndex.reason 'structural-assurance-blocked' 'A missing Evidence Index must fail the canonical structural terminal gate'
+
+$corruptEvidenceIndexReport = New-TerminalScopeReport 'runs/scope-terminal-corrupt-index.md' @($completeItem) @($completeChain)
+$corruptEvidenceIndexReport.evidence_index[0].purpose = 'caller-attested-summary'
+$corruptEvidenceIndex = Invoke-ScopeScenario @{
+  scenario_type = 'scope-engine'; operation = 'complete-scope'
+  work_items = @($completeItem)
+  terminal_artifacts = @($completeTerminal)
+  responsibility_chain_artifacts = @($completeChain.Artifacts)
+  terminal_scope_report = $corruptEvidenceIndexReport
+}
+Assert-Equal $corruptEvidenceIndex.scope_status 'scope-blocked' 'Evidence Index purpose and mapping must be exact'
+Assert-Equal $corruptEvidenceIndex.reason 'structural-assurance-blocked' 'A corrupt Evidence Index must fail the structural terminal gate'
+
+$directReviewOnlyTerminal = New-TerminalResponsibilityArtifact $completeItem.terminal_evidence $completeItem.work_item_id $completeItem.status $completeReview.artifact_reference
+$directReviewOnlyTerminal.mode_constraint = 'incremental/preserve-existing'
+$directReviewOnlyTerminal.responsibility_chain_references = @($completeReview.artifact_reference)
+$directReviewOnlyCompletion = Invoke-ScopeScenario @{
+  scenario_type = 'scope-engine'
+  operation = 'complete-scope'
+  work_items = @($completeItem)
+  terminal_artifacts = @($directReviewOnlyTerminal)
+  responsibility_evidence_artifacts = @($completeReview)
   terminal_scope_report = @{
-    artifact_reference = 'runs/scope-terminal.md'
+    artifact_reference = 'runs/scope-terminal-direct-review.md'
     artifact_type = 'migration-scope-terminal-report'
     master_plan_ref = 'runs/master-plan@3.md'
     master_plan_revision = 3
     immutable = $true
+    responsibility_handoff = @{
+      responsibility_contract_version = 1
+      tree_conformance = 'PASS'
+      responsibility_conformance = 'PASS'
+      verification_ownership = 'PASS'
+      architecture_state = 'PASS'
+      evidence_references = @('runs/complete.md')
+    }
     items = @(
-      @{ work_item_id = 'WORK-ADMIN-COMPLETE'; status = 'complete'; terminal_evidence = 'runs/complete.md'; architecture_state = 'PASS'; selector_schema_state = 'PASS' },
-      @{ work_item_id = 'WORK-ADMIN-CANCELLED'; status = 'cancelled-approved'; terminal_evidence = 'decisions/cancelled.md'; architecture_state = 'PASS'; selector_schema_state = 'PASS' },
-      @{ work_item_id = 'WORK-ADMIN-NA'; status = 'not-applicable-approved'; terminal_evidence = 'decisions/not-applicable.md'; architecture_state = 'PASS'; selector_schema_state = 'PASS' }
+      @{ work_item_id = 'WORK-ADMIN-COMPLETE'; status = 'complete'; terminal_evidence = 'runs/complete.md'; architecture_state = 'PASS'; selector_schema_state = 'PASS' }
     )
   }
 }
-Assert-Equal $allComplete.scope_status 'scope-complete' 'All required terminal-success items with scope evidence must complete the scope'
+Assert-Equal $directReviewOnlyCompletion.scope_status 'scope-blocked' 'A direct review reference cannot replace the ordered verification/parity/regression/KB terminal chain'
+Assert-Equal $directReviewOnlyCompletion.reason 'structural-assurance-blocked' 'An incomplete terminal responsibility chain must emit the structural diagnostic'
+
+$missingV1Terminal = New-TerminalResponsibilityArtifact $completeItem.terminal_evidence $completeItem.work_item_id $completeItem.status $completeChain.FinalReference $completeChain.References $completeChain.ModeConstraint
+$missingV1Terminal.Remove('responsibility_handoff')
+$missingV1Completion = Invoke-ScopeScenario @{
+  scenario_type = 'scope-engine'
+  operation = 'complete-scope'
+  work_items = @($completeItem)
+  terminal_artifacts = @($missingV1Terminal)
+  responsibility_chain_artifacts = @($completeChain.Artifacts)
+  terminal_scope_report = @{
+    artifact_reference = 'runs/scope-terminal-missing-v1.md'
+    artifact_type = 'migration-scope-terminal-report'
+    master_plan_ref = 'runs/master-plan@3.md'
+    master_plan_revision = 3
+    immutable = $true
+    responsibility_handoff = @{
+      responsibility_contract_version = 1
+      tree_conformance = 'PASS'
+      responsibility_conformance = 'PASS'
+      verification_ownership = 'PASS'
+      architecture_state = 'PASS'
+      evidence_references = @($completeChain.FinalReference)
+    }
+    items = @(
+      @{ work_item_id = 'WORK-ADMIN-COMPLETE'; status = 'complete'; terminal_evidence = 'runs/complete.md'; architecture_state = 'PASS'; selector_schema_state = 'PASS' }
+    )
+  }
+}
+Assert-Equal $missingV1Completion.scope_status 'scope-blocked' 'A terminal artifact without the exact v1 responsibility handoff cannot complete scope'
+Assert-Equal $missingV1Completion.reason 'structural-assurance-blocked' 'Missing v1 terminal responsibility provenance must emit the structural diagnostic'
+
+$mixedVersionTerminal = New-TerminalResponsibilityArtifact $completeItem.terminal_evidence $completeItem.work_item_id $completeItem.status $completeChain.FinalReference $completeChain.References $completeChain.ModeConstraint
+$mixedVersionTerminal.responsibility_handoff.responsibility_contract_version = 2
+$mixedVersionCompletion = Invoke-ScopeScenario @{
+  scenario_type = 'scope-engine'
+  operation = 'complete-scope'
+  work_items = @($completeItem)
+  terminal_artifacts = @($mixedVersionTerminal)
+  responsibility_chain_artifacts = @($completeChain.Artifacts)
+  terminal_scope_report = @{
+    artifact_reference = 'runs/scope-terminal-mixed-v1-v2.md'
+    artifact_type = 'migration-scope-terminal-report'
+    master_plan_ref = 'runs/master-plan@3.md'
+    master_plan_revision = 3
+    immutable = $true
+    responsibility_handoff = @{
+      responsibility_contract_version = 1
+      tree_conformance = 'PASS'
+      responsibility_conformance = 'PASS'
+      verification_ownership = 'PASS'
+      architecture_state = 'PASS'
+      evidence_references = @($completeChain.FinalReference)
+    }
+    items = @(
+      @{ work_item_id = 'WORK-ADMIN-COMPLETE'; status = 'complete'; terminal_evidence = 'runs/complete.md'; architecture_state = 'PASS'; selector_schema_state = 'PASS' }
+    )
+  }
+}
+Assert-Equal $mixedVersionCompletion.scope_status 'scope-blocked' 'Mixed v1/v2 terminal evidence cannot complete scope'
+Assert-Equal $mixedVersionCompletion.reason 'structural-assurance-blocked' 'Mixed responsibility versions must emit the structural diagnostic'
+
+$selfLabeledGreenfieldChain = New-ResponsibilityChain 'runs/self-labeled-greenfield-chain' $completeItem.work_item_id 'greenfield/design-new'
+$selfLabeledGreenfieldTerminal = New-TerminalResponsibilityArtifact $completeItem.terminal_evidence $completeItem.work_item_id $completeItem.status $selfLabeledGreenfieldChain.FinalReference $selfLabeledGreenfieldChain.References 'greenfield/design-new'
+$selfLabeledGreenfield = Invoke-ScopeScenario @{
+  scenario_type = 'scope-engine'; operation = 'complete-scope'
+  work_items = @($completeItem)
+  terminal_artifacts = @($selfLabeledGreenfieldTerminal)
+  responsibility_chain_artifacts = @($selfLabeledGreenfieldChain.Artifacts)
+  terminal_scope_report = (New-TerminalScopeReport 'runs/scope-terminal-self-labeled-greenfield.md' @($completeItem) @($selfLabeledGreenfieldChain))
+}
+Assert-Equal $selfLabeledGreenfield.scope_status 'scope-blocked' 'An incremental approved work item cannot self-label greenfield to omit regression'
+Assert-Equal $selfLabeledGreenfield.reason 'structural-assurance-blocked' 'Mode/chain mismatch must fail the structural terminal gate'
+
+$approvedGreenfieldItem = New-WorkItem 'WORK-ADMIN-GREENFIELD' 1 @() 'complete'
+$approvedGreenfieldItem.mode_constraint = 'greenfield/design-new'
+$approvedGreenfieldItem.terminal_evidence = 'runs/greenfield-terminal.md'
+$approvedGreenfieldChain = New-ResponsibilityChain 'runs/approved-greenfield-chain' $approvedGreenfieldItem.work_item_id $approvedGreenfieldItem.mode_constraint
+$approvedGreenfieldTerminal = New-TerminalResponsibilityArtifact $approvedGreenfieldItem.terminal_evidence $approvedGreenfieldItem.work_item_id $approvedGreenfieldItem.status $approvedGreenfieldChain.FinalReference $approvedGreenfieldChain.References $approvedGreenfieldItem.mode_constraint
+$approvedGreenfield = Invoke-ScopeScenario @{
+  scenario_type = 'scope-engine'; operation = 'complete-scope'
+  work_items = @($approvedGreenfieldItem)
+  terminal_artifacts = @($approvedGreenfieldTerminal)
+  responsibility_chain_artifacts = @($approvedGreenfieldChain.Artifacts)
+  terminal_scope_report = (New-TerminalScopeReport 'runs/scope-terminal-approved-greenfield.md' @($approvedGreenfieldItem) @($approvedGreenfieldChain))
+}
+Assert-Equal $approvedGreenfield.scope_status 'scope-complete' 'An authoritative greenfield work item must use the legitimate four-stage terminal chain'
+
+foreach ($lifecycleMutation in @(
+  @{ Name = 'result'; Field = 'result'; Value = 'partial' },
+  @{ Name = 'approval-source'; Field = 'approval_source'; Value = 'automation' },
+  @{ Name = 'status'; Field = 'status'; Value = 'draft' }
+)) {
+  $lifecycleChain = New-ResponsibilityChain "runs/lifecycle-$($lifecycleMutation.Name)-chain" $completeItem.work_item_id
+  $lifecycleChain.Artifacts[0][$lifecycleMutation.Field] = $lifecycleMutation.Value
+  $lifecycleTerminal = New-TerminalResponsibilityArtifact $completeItem.terminal_evidence $completeItem.work_item_id $completeItem.status $lifecycleChain.FinalReference $lifecycleChain.References $lifecycleChain.ModeConstraint
+  $lifecycleCompletion = Invoke-ScopeScenario @{
+    scenario_type = 'scope-engine'; operation = 'complete-scope'
+    work_items = @($completeItem)
+    terminal_artifacts = @($lifecycleTerminal)
+    responsibility_chain_artifacts = @($lifecycleChain.Artifacts)
+    terminal_scope_report = (New-TerminalScopeReport "runs/scope-terminal-lifecycle-$($lifecycleMutation.Name).md" @($completeItem) @($lifecycleChain))
+  }
+  Assert-Equal $lifecycleCompletion.scope_status 'scope-blocked' "Initial review $($lifecycleMutation.Name) must be approved/complete/human"
+}
+
+$sourceDiffMismatchChain = New-ResponsibilityChain 'runs/source-diff-mismatch-chain' $completeItem.work_item_id
+foreach ($artifact in @($sourceDiffMismatchChain.Artifacts)) {
+  $artifact.evidence_reference = "source-diff:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa..bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb#$($completeItem.work_item_id)"
+}
+$sourceDiffMismatchTerminal = New-TerminalResponsibilityArtifact $completeItem.terminal_evidence $completeItem.work_item_id $completeItem.status $sourceDiffMismatchChain.FinalReference $sourceDiffMismatchChain.References $sourceDiffMismatchChain.ModeConstraint
+$sourceDiffMismatchCompletion = Invoke-ScopeScenario @{
+  scenario_type = 'scope-engine'; operation = 'complete-scope'
+  work_items = @($completeItem)
+  terminal_artifacts = @($sourceDiffMismatchTerminal)
+  responsibility_chain_artifacts = @($sourceDiffMismatchChain.Artifacts)
+  terminal_scope_report = (New-TerminalScopeReport 'runs/scope-terminal-source-diff-mismatch.md' @($completeItem) @($sourceDiffMismatchChain))
+}
+Assert-Equal $sourceDiffMismatchCompletion.scope_status 'scope-blocked' 'Source-diff SHA pair must equal immutable Task Provenance SHAs'
+
+$crossRunChain = New-ResponsibilityChain 'runs/cross-run-chain' $completeItem.work_item_id
+foreach ($artifact in @($crossRunChain.Artifacts)) { $artifact.run_id = 'RUN-FOREIGN-999' }
+$crossRunTerminal = New-TerminalResponsibilityArtifact $completeItem.terminal_evidence $completeItem.work_item_id $completeItem.status $crossRunChain.FinalReference $crossRunChain.References $crossRunChain.ModeConstraint
+$crossRunCompletion = Invoke-ScopeScenario @{
+  scenario_type = 'scope-engine'; operation = 'complete-scope'
+  work_items = @($completeItem)
+  terminal_artifacts = @($crossRunTerminal)
+  responsibility_chain_artifacts = @($crossRunChain.Artifacts)
+  terminal_scope_report = (New-TerminalScopeReport 'runs/scope-terminal-cross-run.md' @($completeItem) @($crossRunChain))
+}
+Assert-Equal $crossRunCompletion.scope_status 'scope-blocked' 'A digest-valid responsibility chain from another run cannot complete scope'
+
+$foreignPlanChain = New-ResponsibilityChain 'runs/foreign-plan-chain' $completeItem.work_item_id
+foreach ($artifact in @($foreignPlanChain.Artifacts)) { $artifact.master_plan_ref = 'runs/foreign-master-plan.md' }
+$foreignPlanTerminal = New-TerminalResponsibilityArtifact $completeItem.terminal_evidence $completeItem.work_item_id $completeItem.status $foreignPlanChain.FinalReference $foreignPlanChain.References $foreignPlanChain.ModeConstraint
+$foreignPlanCompletion = Invoke-ScopeScenario @{
+  scenario_type = 'scope-engine'; operation = 'complete-scope'
+  work_items = @($completeItem)
+  terminal_artifacts = @($foreignPlanTerminal)
+  responsibility_chain_artifacts = @($foreignPlanChain.Artifacts)
+  terminal_scope_report = (New-TerminalScopeReport 'runs/scope-terminal-foreign-plan.md' @($completeItem) @($foreignPlanChain))
+}
+Assert-Equal $foreignPlanCompletion.scope_status 'scope-blocked' 'Responsibility artifacts must bind the current approved master plan'
 
 $optionalBlocker = New-WorkItem 'WORK-ADMIN-OPTIONAL-BLOCKED' 4 @() 'blocked' $false
 $optionalBlocker.has_blocker = $true
 $blockedCompletion = Invoke-ScopeScenario @{
   scenario_type = 'scope-engine'
   operation = 'complete-scope'
   work_items = @($completeItem, $optionalBlocker)
 }
 Assert-Equal $blockedCompletion.scope_status 'scope-blocked' 'Any remaining blocker must prevent requested-scope completion'
 
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/validate-migration-framework.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/validate-migration-framework.ps1
index 25e8a36..aa49c74 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/validate-migration-framework.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/validate-migration-framework.ps1
@@ -1449,22 +1449,22 @@ function Test-FlexibleScopeFixtureEnvelope([string]$FixturePath) {
   }
   try {
     $fixture = Get-Content -Raw -Encoding utf8 -LiteralPath $resolvedFixturePath | ConvertFrom-Json
   }
   catch {
     $errors.Add('Flexible scope E2E fixture must be valid JSON')
     return
   }
   $expectedFields = @(
     'expected_diagnostic', 'expected_scope_state', 'legacy_conversion_ref',
-    'master_plan_ref', 'master_spec_ref', 'predecessor_ref', 'scenario_id',
-    'target_evidence_ref', 'terminal_report_ref'
+    'master_plan_ref', 'master_spec_ref', 'predecessor_ref',
+    'responsibility_chain_refs', 'scenario_id', 'target_evidence_ref', 'terminal_report_ref'
   )
   $actualFields = @($fixture.PSObject.Properties.Name)
   [Array]::Sort($actualFields, [StringComparer]::Ordinal)
   if (($actualFields -join '|') -cne ($expectedFields -join '|')) {
     $errors.Add('Flexible scope E2E fixture must declare the exact evidence envelope')
     return
   }
   foreach ($field in @('scenario_id', 'expected_diagnostic', 'expected_scope_state')) {
     if ([string]::IsNullOrWhiteSpace([string]$fixture.$field)) {
       $errors.Add("Flexible scope E2E fixture field must not be blank: $field")
@@ -1535,41 +1535,300 @@ function Test-FlexibleScopeFixtureEnvelope([string]$FixturePath) {
     }
     $rows = [Collections.Generic.List[object]]::new()
     foreach ($line in @($lines | Select-Object -Skip 2)) {
       if ($line -match '^\|\|' -or $line -match '\|\|$') { $errors.Add("$Context table has invalid framing: $Heading"); continue }
       $cells = @(& $split $line)
       if ($cells.Count -ne $Columns.Count -or @($cells | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -gt 0) { $errors.Add("$Context table has invalid cardinality: $Heading"); continue }
       $row = [ordered]@{}; for ($i=0; $i -lt $Columns.Count; $i++) { $row[$Columns[$i]] = $cells[$i] }; $rows.Add([pscustomobject]$row)
     }
     return @($rows)
   }
+  $specText = Get-Content -Raw -Encoding utf8 -LiteralPath $resolvedEvidence.master_spec_ref
+  $planText = Get-Content -Raw -Encoding utf8 -LiteralPath $resolvedEvidence.master_plan_ref
+  $predecessorText = Get-Content -Raw -Encoding utf8 -LiteralPath $resolvedEvidence.predecessor_ref
+  $targetText = Get-Content -Raw -Encoding utf8 -LiteralPath $resolvedEvidence.target_evidence_ref
+  $specFm = & $frontMatter $specText 'Flexible scope master spec'
+  $planFm = & $frontMatter $planText 'Flexible scope master plan'
+  $preFm = & $frontMatter $predecessorText 'Flexible scope predecessor'
+  $targetFm = & $frontMatter $targetText 'Flexible scope target evidence'
+  $scopeRunDirectory = [IO.Path]::GetFullPath((Split-Path -Parent $resolvedEvidence.master_plan_ref))
+  $masterScopeColumns = @('Run ID','Master Spec Reference','Master Spec ID','Master Spec Revision','Master Plan Reference','Master Plan ID','Master Plan Revision')
+  $readMasterScopeContext = {
+    param([string]$Text,[string]$Context)
+    $normalized = & $normalize $Text
+    $baseHeader = '| ' + ($masterScopeColumns -join ' | ') + ' |'
+    $workItemColumns = @($masterScopeColumns + 'Work Item ID')
+    $workItemHeader = '| ' + ($workItemColumns -join ' | ') + ' |'
+    if ($normalized -cmatch ('(?m)^' + [regex]::Escape($workItemHeader) + '$')) {
+      return @(& $table $Text 'Master Scope Context' $workItemColumns $Context)
+    }
+    if ($normalized -cmatch ('(?m)^' + [regex]::Escape($baseHeader) + '$')) {
+      return @(& $table $Text 'Master Scope Context' $masterScopeColumns $Context)
+    }
+    return @()
+  }
+  $resolveQueueResponsibilityAuthority = {
+    param([string]$Reference)
+    $predecessorScope = @(& $readMasterScopeContext $predecessorText 'Flexible scope predecessor responsibility authority')
+    $predecessorHandoff = @(& $table $predecessorText 'Architecture Responsibility Handoff' @('Responsibility Contract Version','Tree Conformance','Responsibility Conformance','Verification Ownership','Architecture Conformance State','Evidence References') 'Flexible scope predecessor responsibility authority')
+    if ($predecessorScope.Count -ne 1 -or $predecessorHandoff.Count -ne 1) { return $false }
+    $derivedPredecessorArchitecture = if (
+      $predecessorHandoff[0].'Tree Conformance' -ceq 'PASS' -and
+      $predecessorHandoff[0].'Responsibility Conformance' -ceq 'PASS' -and
+      $predecessorHandoff[0].'Verification Ownership' -ceq 'PASS'
+    ) { 'PASS' } else { 'BLOCKED' }
+    if (
+      $predecessorHandoff[0].'Responsibility Contract Version' -cne '1' -or
+      $derivedPredecessorArchitecture -cne 'PASS' -or
+      $predecessorHandoff[0].'Architecture Conformance State' -cne $derivedPredecessorArchitecture -or
+      $predecessorHandoff[0].'Evidence References' -cne $Reference
+    ) { return $false }
+
+    $referenceMatch = [regex]::Match($Reference, '^(?<path>[^#]+)#sha256:(?<digest>[0-9a-f]{64})$')
+    if (
+      -not $referenceMatch.Success -or
+      [IO.Path]::IsPathRooted($referenceMatch.Groups['path'].Value) -or
+      $referenceMatch.Groups['path'].Value -match '(^|[\/])\.\.([\/]|$)'
+    ) { return $false }
+    $path = [IO.Path]::GetFullPath((Join-Path $root $referenceMatch.Groups['path'].Value))
+    if (
+      -not $path.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase) -or
+      -not (Test-Path -LiteralPath $path -PathType Leaf) -or
+      [IO.Path]::GetFullPath((Split-Path -Parent $path)) -cne $scopeRunDirectory
+    ) { return $false }
+    $bytes = [IO.File]::ReadAllBytes($path)
+    $sha = [Security.Cryptography.SHA256]::Create()
+    try { $actualDigest = ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','').ToLowerInvariant() }
+    finally { $sha.Dispose() }
+    if ($actualDigest -cne $referenceMatch.Groups['digest'].Value) { return $false }
+    try { $text = [Text.UTF8Encoding]::new($false, $true).GetString($bytes) }
+    catch { return $false }
+    $normalized = & $normalize $text
+    $frontMatterMatch = [regex]::Match($normalized, '\A---\n(?<body>.*?)\n---\n', 'Singleline')
+    if (-not $frontMatterMatch.Success) { return $false }
+    $topLevel = @{}
+    foreach ($line in $frontMatterMatch.Groups['body'].Value -split "`n") {
+      $fieldMatch = [regex]::Match($line, '^(?<key>[a-z_][a-z0-9_]*):[ \t]*(?<value>\S.*?)$')
+      if ($fieldMatch.Success) {
+        if ($topLevel.ContainsKey($fieldMatch.Groups['key'].Value)) { return $false }
+        $topLevel[$fieldMatch.Groups['key'].Value] = $fieldMatch.Groups['value'].Value.Trim()
+      }
+    }
+    $topKeys = @($topLevel.Keys | Sort-Object)
+    $contractMatch = [regex]::Match($frontMatterMatch.Groups['body'].Value, '(?m)^responsibility_contract:\n  version: 1\n  applicability: required$')
+    $authorityScope = @(& $readMasterScopeContext $text 'Queue responsibility authority')
+    $authorityHandoff = @(& $table $text 'Architecture Responsibility Handoff' @('Responsibility Contract Version','Tree Conformance','Responsibility Conformance','Verification Ownership','Architecture Conformance State','Evidence References') 'Queue responsibility authority')
+    if (
+      ($topKeys -join '|') -cne 'approval_source|artifact_type|produced_at|result|status' -or
+      $topLevel.artifact_type -cne 'migration-queue-responsibility-authority' -or
+      $topLevel.status -cne 'approved' -or $topLevel.result -cne 'complete' -or
+      $topLevel.approval_source -cne 'human' -or
+      $topLevel.produced_at -cnotmatch '^20[0-9]{2}-[0-9]{2}-[0-9]{2}$' -or
+      -not $contractMatch.Success -or $authorityScope.Count -ne 1 -or $authorityHandoff.Count -ne 1
+    ) { return $false }
+    $derivedAuthorityArchitecture = if (
+      $authorityHandoff[0].'Tree Conformance' -ceq 'PASS' -and
+      $authorityHandoff[0].'Responsibility Conformance' -ceq 'PASS' -and
+      $authorityHandoff[0].'Verification Ownership' -ceq 'PASS'
+    ) { 'PASS' } else { 'BLOCKED' }
+    if (
+      $authorityHandoff[0].'Responsibility Contract Version' -cne '1' -or
+      $derivedAuthorityArchitecture -cne 'PASS' -or
+      $authorityHandoff[0].'Architecture Conformance State' -cne $derivedAuthorityArchitecture -or
+      $authorityHandoff[0].'Evidence References' -cne [string]$fixture.master_plan_ref
+    ) { return $false }
+    foreach ($column in $masterScopeColumns) {
+      if ($predecessorScope[0].$column -cne $authorityScope[0].$column) { return $false }
+    }
+    return (
+      -not [string]::IsNullOrWhiteSpace($authorityScope[0].'Run ID') -and
+      $authorityScope[0].'Master Spec Reference' -ceq [string]$fixture.master_spec_ref -and
+      $authorityScope[0].'Master Spec ID' -ceq [string]$specFm.master_spec_id -and
+      $authorityScope[0].'Master Spec Revision' -ceq [string]$specFm.revision -and
+      $authorityScope[0].'Master Plan Reference' -ceq [string]$fixture.master_plan_ref -and
+      $authorityScope[0].'Master Plan ID' -ceq [string]$planFm.master_plan_id -and
+      $authorityScope[0].'Master Plan Revision' -ceq [string]$planFm.revision
+    )
+  }
+  $predecessorAuthorityHandoff = @(& $table $predecessorText 'Architecture Responsibility Handoff' @('Responsibility Contract Version','Tree Conformance','Responsibility Conformance','Verification Ownership','Architecture Conformance State','Evidence References') 'Flexible scope predecessor responsibility authority')
+  $queueResponsibilityAuthorityValid = (
+    $predecessorAuthorityHandoff.Count -eq 1 -and
+    (& $resolveQueueResponsibilityAuthority ([string]$predecessorAuthorityHandoff[0].'Evidence References'))
+  )
+  $resolveResponsibilityEvidence = {
+    param([string]$Reference,[string]$ExpectedWorkItem,[object]$ExpectedHandoff,[string]$ExpectedRunId,[string]$Context)
+    $referenceMatch=[regex]::Match($Reference,'^(?<path>[^#]+)#sha256:(?<digest>[0-9a-f]{64})$')
+    if(-not$referenceMatch.Success-or[IO.Path]::IsPathRooted($referenceMatch.Groups['path'].Value)-or$referenceMatch.Groups['path'].Value-match'(^|[\/])\.\.([\/]|$)'){return $false}
+    $path=[IO.Path]::GetFullPath((Join-Path $root $referenceMatch.Groups['path'].Value))
+    if(-not$path.StartsWith($rootPrefix,[StringComparison]::OrdinalIgnoreCase)-or-not(Test-Path -LiteralPath $path -PathType Leaf)-or[IO.Path]::GetFullPath((Split-Path -Parent $path))-cne$scopeRunDirectory){return $false}
+    $bytes=[IO.File]::ReadAllBytes($path);$sha=[Security.Cryptography.SHA256]::Create()
+    try{$actualDigest=([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}
+    if($actualDigest-cne$referenceMatch.Groups['digest'].Value){return $false}
+    try{$text=[Text.UTF8Encoding]::new($false,$true).GetString($bytes)}catch{return $false}
+    $normalized=&$normalize $text
+    $frontMatterMatch=[regex]::Match($normalized,'\A---\n(?<body>.*?)\n---\n','Singleline')
+    if(-not$frontMatterMatch.Success){return $false}
+    $topLevel=@{}
+    foreach($line in $frontMatterMatch.Groups['body'].Value -split "`n"){
+      $fieldMatch=[regex]::Match($line,'^(?<key>[a-z_][a-z0-9_]*):[ \t]*(?<value>\S.*?)$')
+      if($fieldMatch.Success){if($topLevel.ContainsKey($fieldMatch.Groups['key'].Value)){return $false};$topLevel[$fieldMatch.Groups['key'].Value]=$fieldMatch.Groups['value'].Value.Trim()}
+    }
+    $topKeys=@($topLevel.Keys|Sort-Object)
+    $contractMatch=[regex]::Match($frontMatterMatch.Groups['body'].Value,'(?m)^responsibility_contract:\n  version: 1\n  applicability: required$')
+    $scope=@(&$table $text 'Master Scope Context' @('Run ID','Master Spec Reference','Master Spec ID','Master Spec Revision','Master Plan Reference','Master Plan ID','Master Plan Revision','Work Item ID') "$Context responsibility evidence")
+    $provenance=@(&$table $text 'Task Provenance' @('Task / Unit','Task-base SHA','Final-tree SHA','Source Artifact') "$Context responsibility evidence")
+    $handoff=@(&$table $text 'Architecture Responsibility Handoff' @('Responsibility Contract Version','Tree Conformance','Responsibility Conformance','Verification Ownership','Architecture Conformance State','Evidence References') "$Context responsibility evidence")
+    if((($topKeys-join'|')-cne'approval_source|produced_at|result|status|step_id')-or-not$contractMatch.Success-or$topLevel.step_id-cne'11-ai-review'-or$topLevel.status-cne'approved'-or$topLevel.result-cne'complete'-or$topLevel.approval_source-cne'human'-or$topLevel.produced_at-cnotmatch'^20[0-9]{2}-[0-9]{2}-[0-9]{2}$'-or$scope.Count-ne1-or$provenance.Count-ne1-or$handoff.Count-ne1){return $false}
+    if($scope[0].'Run ID'-cne$ExpectedRunId-or$scope[0].'Master Spec Reference'-cne[string]$fixture.master_spec_ref-or$scope[0].'Master Spec ID'-cne[string]$specFm.master_spec_id-or$scope[0].'Master Spec Revision'-cne[string]$specFm.revision-or$scope[0].'Master Plan Reference'-cne[string]$fixture.master_plan_ref-or$scope[0].'Master Plan ID'-cne[string]$planFm.master_plan_id-or$scope[0].'Master Plan Revision'-cne[string]$planFm.revision-or$scope[0].'Work Item ID'-cne$ExpectedWorkItem){return $false}
+    if($provenance[0].'Task / Unit'-cne$ExpectedWorkItem-or$provenance[0].'Task-base SHA'-cnotmatch'^[0-9a-f]{40}$'-or$provenance[0].'Final-tree SHA'-cnotmatch'^[0-9a-f]{40}$'-or$provenance[0].'Source Artifact'-cne'implementation-report.md'){return $false}
+    foreach($field in @('Responsibility Contract Version','Tree Conformance','Responsibility Conformance','Verification Ownership','Architecture Conformance State')){if($handoff[0].$field-cne$ExpectedHandoff.$field){return $false}}
+    $expectedSourceDiff='source-diff:'+$provenance[0].'Task-base SHA'+'..'+$provenance[0].'Final-tree SHA'+'#'+$ExpectedWorkItem
+    return $handoff[0].'Evidence References' -ceq $expectedSourceDiff
+  }
+  $responsibilityChainValid=$true
+  $structuralResponsibilityChainBlocked=$false
+  $responsibilityChainByWorkItem=@{}
+  $responsibilityContractPath=Join-Path $root 'contracts/file-responsibility-conformance.md'
+  $responsibilityValidatorPath=Join-Path $root 'tests/validation/responsibility-conformance.validation.ps1'
+  if(-not (Test-Path -LiteralPath $responsibilityContractPath -PathType Leaf) -or -not (Test-Path -LiteralPath $responsibilityValidatorPath -PathType Leaf)){
+    $responsibilityChainValid=$false
+  }else{
+    . $responsibilityValidatorPath
+    $responsibilityContractText=Get-Content -Raw -Encoding utf8 -LiteralPath $responsibilityContractPath
+    $declaredChains=@($fixture.responsibility_chain_refs)
+    foreach($declaredChain in $declaredChains){
+      $chainFields=@($declaredChain.PSObject.Properties.Name|Sort-Object)
+      $workItemId=[string]$declaredChain.work_item_id
+      $artifactReferences=@($declaredChain.artifact_refs)
+      if(($chainFields-join'|')-cne'artifact_refs|work_item_id'-or[string]::IsNullOrWhiteSpace($workItemId)-or$responsibilityChainByWorkItem.ContainsKey($workItemId)-or$artifactReferences.Count-notin@(4,5)){$responsibilityChainValid=$false;continue}
+      $chainTexts=[Collections.Generic.List[string]]::new()
+      $chainReferences=[Collections.Generic.List[string]]::new()
+      $chainProvenance=[Collections.Generic.List[object]]::new()
+      $chainHandoffs=[Collections.Generic.List[object]]::new()
+      foreach($artifactReference in $artifactReferences){
+        $reference=[string]$artifactReference
+        $referenceMatch=[regex]::Match($reference,'^(?<path>[^#]+)#sha256:(?<digest>[0-9a-f]{64})$')
+        if(-not$referenceMatch.Success-or[IO.Path]::IsPathRooted($referenceMatch.Groups['path'].Value)-or$referenceMatch.Groups['path'].Value-match'(^|[\/])\.\.([\/]|$)'){$responsibilityChainValid=$false;continue}
+        $artifactPath=[IO.Path]::GetFullPath((Join-Path $root $referenceMatch.Groups['path'].Value))
+        if(-not $artifactPath.StartsWith($rootPrefix,[StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $artifactPath -PathType Leaf) -or [IO.Path]::GetFullPath((Split-Path -Parent $artifactPath))-cne$scopeRunDirectory){$responsibilityChainValid=$false;continue}
+        $artifactBytes=[IO.File]::ReadAllBytes($artifactPath);$artifactSha=[Security.Cryptography.SHA256]::Create()
+        try{$artifactDigest=([BitConverter]::ToString($artifactSha.ComputeHash($artifactBytes))).Replace('-','').ToLowerInvariant()}finally{$artifactSha.Dispose()}
+        if($artifactDigest-cne$referenceMatch.Groups['digest'].Value){$responsibilityChainValid=$false;continue}
+        try{$artifactText=[Text.UTF8Encoding]::new($false,$true).GetString($artifactBytes)}catch{$responsibilityChainValid=$false;continue}
+        $artifactProvenance=@(&$table $artifactText 'Task Provenance' @('Task / Unit','Task-base SHA','Final-tree SHA','Source Artifact') "Responsibility chain artifact $workItemId")
+        $artifactHandoff=@(&$table $artifactText 'Architecture Responsibility Handoff' @('Responsibility Contract Version','Tree Conformance','Responsibility Conformance','Verification Ownership','Architecture Conformance State','Evidence References') "Responsibility chain artifact $workItemId")
+        if($artifactProvenance.Count-ne1-or$artifactHandoff.Count-ne1){$responsibilityChainValid=$false;continue}
+        $chainReferences.Add($reference);$chainTexts.Add($artifactText);$chainProvenance.Add($artifactProvenance[0]);$chainHandoffs.Add($artifactHandoff[0])
+      }
+      if($chainTexts.Count-ne$artifactReferences.Count){$responsibilityChainValid=$false;continue}
+      $chainStepIds=@($chainTexts|ForEach-Object{$stepMatch=[regex]::Match((&$normalize $_),'(?m)^step_id: (?<step>\S+)$');if($stepMatch.Success){$stepMatch.Groups['step'].Value}else{''}})
+      $incrementalSteps=@('11-ai-review','12-verification-testing','13-verify-parity','14-verify-regression','15-knowledge-base')
+      $greenfieldSteps=@('11-ai-review','12-verification-testing','13-verify-parity','15-knowledge-base')
+      $modeConstraint=if(($chainStepIds-join'|')-ceq($incrementalSteps-join'|')){'incremental/preserve-existing'}elseif(($chainStepIds-join'|')-ceq($greenfieldSteps-join'|')){'greenfield/design-new'}else{''}
+      if([string]::IsNullOrWhiteSpace($modeConstraint)){$responsibilityChainValid=$false;continue}
+      $canonicalSourceDiff=''
+      for($provenanceIndex=0;$provenanceIndex-lt$chainProvenance.Count;$provenanceIndex++){
+        $provenanceRow=$chainProvenance[$provenanceIndex];$handoffRow=$chainHandoffs[$provenanceIndex]
+        $observedSourceDiff='source-diff:'+$provenanceRow.'Task-base SHA'+'..'+$provenanceRow.'Final-tree SHA'+'#'+$workItemId
+        if($provenanceRow.'Task / Unit'-cne$workItemId-or$provenanceRow.'Task-base SHA'-cnotmatch'^[0-9a-f]{40}$'-or$provenanceRow.'Final-tree SHA'-cnotmatch'^[0-9a-f]{40}$'-or$handoffRow.'Evidence References'-cne$observedSourceDiff){$responsibilityChainValid=$false}
+        if($provenanceIndex-eq0){$canonicalSourceDiff=$observedSourceDiff}elseif($observedSourceDiff-cne$canonicalSourceDiff){$responsibilityChainValid=$false}
+      }
+      $initialHandoff=@(& $table $chainTexts[0] 'Architecture Responsibility Handoff' @('Responsibility Contract Version','Tree Conformance','Responsibility Conformance','Verification Ownership','Architecture Conformance State','Evidence References') "Responsibility review chain $workItemId")
+      $predecessorScopeRows=@(& $readMasterScopeContext $predecessorText 'Flexible scope predecessor responsibility authority')
+      $expectedRunId=if($predecessorScopeRows.Count-eq1){[string]$predecessorScopeRows[0].'Run ID'}else{''}
+      if($initialHandoff.Count-ne1-or$initialHandoff[0].'Evidence References'-cne$canonicalSourceDiff-or-not(& $resolveResponsibilityEvidence $chainReferences[0] $workItemId $initialHandoff[0] $expectedRunId "Responsibility review chain $workItemId")){$responsibilityChainValid=$false}
+      for($chainIndex=0;$chainIndex-lt($chainTexts.Count-1);$chainIndex++){
+        $handoffDiagnostics=@(Test-ResponsibilityHandoff -SourceText $chainTexts[$chainIndex] -TargetText $chainTexts[$chainIndex+1] -ContractText $responsibilityContractText)
+        if($handoffDiagnostics.Count-ne0){$responsibilityChainValid=$false}
+      }
+      $finalHandoff=@(& $table $chainTexts[-1] 'Architecture Responsibility Handoff' @('Responsibility Contract Version','Tree Conformance','Responsibility Conformance','Verification Ownership','Architecture Conformance State','Evidence References') "Responsibility terminal chain $workItemId")
+      if($finalHandoff.Count-ne1-or$finalHandoff[0].'Responsibility Contract Version'-cne'1'){$responsibilityChainValid=$false;continue}
+      $derivedFinalArchitecture=if($finalHandoff[0].'Tree Conformance'-ceq'PASS'-and$finalHandoff[0].'Responsibility Conformance'-ceq'PASS'-and$finalHandoff[0].'Verification Ownership'-ceq'PASS'){'PASS'}else{'BLOCKED'}
+      if($finalHandoff[0].'Architecture Conformance State'-cne$derivedFinalArchitecture){$responsibilityChainValid=$false}
+      if($derivedFinalArchitecture-cne'PASS'){$structuralResponsibilityChainBlocked=$true;$responsibilityChainValid=$false}
+      $responsibilityChainByWorkItem[$workItemId]=[pscustomobject]@{FinalReference=$chainReferences[-1];Handoff=$finalHandoff[0];ModeConstraint=$modeConstraint}
+    }
+  }
+  $resolveApprovedAdapterMode = {
+    param([string]$TerminalPath,[object]$AdapterRow,[string]$ExpectedAdapter,[string]$Context)
+    $adapterMatch = [regex]::Match($ExpectedAdapter, '^migration-unit:(?<unit>\S+)$')
+    if ($null -eq $AdapterRow -or -not $adapterMatch.Success) {
+      return [pscustomobject]@{ Valid=$false; ModeConstraint='' }
+    }
+    $unitId = $adapterMatch.Groups['unit'].Value
+    $authorityReference = [string]$AdapterRow.Authority
+    $authorityRevision = [string]$AdapterRow.'Authority Revision'
+    if (
+      [string]::IsNullOrWhiteSpace($authorityReference) -or
+      [IO.Path]::IsPathRooted($authorityReference) -or
+      $authorityReference -match '(^|[\/])\.\.([\/]|$)' -or
+      $authorityRevision -cnotmatch '^[1-9][0-9]*$'
+    ) { return [pscustomobject]@{ Valid=$false; ModeConstraint='' } }
+    $authorityPath = [IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $TerminalPath) $authorityReference))
+    if (
+      -not $authorityPath.StartsWith($rootPrefix,[StringComparison]::OrdinalIgnoreCase) -or
+      -not (Test-Path -LiteralPath $authorityPath -PathType Leaf) -or
+      [IO.Path]::GetFullPath((Split-Path -Parent $authorityPath)) -cne $scopeRunDirectory
+    ) { return [pscustomobject]@{ Valid=$false; ModeConstraint='' } }
+    try { $authorityText = [Text.UTF8Encoding]::new($false,$true).GetString([IO.File]::ReadAllBytes($authorityPath)) }
+    catch { return [pscustomobject]@{ Valid=$false; ModeConstraint='' } }
+    $authorityFm = & $frontMatter $authorityText "$Context approved mode authority"
+    $authorityKeys = @($authorityFm.Keys | Sort-Object)
+    $unitColumns = @('Migration Unit ID','Plan Reference','Approval Reference','Mode Constraint','Bootstrap Scope','Foundation Baseline ID','Foundation Baseline Reference','Foundation Baseline Approval Reference','Baseline Reference','Trace IDs')
+    $unitRows = @(& $table $authorityText 'Migration Units' $unitColumns "$Context approved mode authority" | Where-Object { $_.'Migration Unit ID' -ceq $unitId })
+    $valid = (
+      ($authorityKeys -join '|') -ceq 'approval_source|produced_at|result|revision|status|step_id' -and
+      $authorityFm.step_id -ceq '08-plan-waves' -and $authorityFm.status -ceq 'approved' -and
+      $authorityFm.result -ceq 'complete' -and $authorityFm.approval_source -ceq 'human' -and
+      $authorityFm.produced_at -cmatch '^20[0-9]{2}-[0-9]{2}-[0-9]{2}$' -and
+      $authorityFm.revision -ceq $authorityRevision -and $unitRows.Count -eq 1
+    )
+    if ($unitRows.Count -eq 1) {
+      $unitRow = $unitRows[0]
+      $valid = $valid -and
+        $unitRow.'Plan Reference' -ceq ($authorityReference+'@'+$authorityRevision) -and
+        $unitRow.'Approval Reference' -ceq [string]$AdapterRow.'Approval Reference' -and
+        $unitRow.'Mode Constraint' -ceq [string]$AdapterRow.'Mode Constraint' -and
+        -not [string]::IsNullOrWhiteSpace($unitRow.'Bootstrap Scope') -and
+        -not [string]::IsNullOrWhiteSpace($unitRow.'Foundation Baseline ID') -and
+        -not [string]::IsNullOrWhiteSpace($unitRow.'Foundation Baseline Reference') -and
+        -not [string]::IsNullOrWhiteSpace($unitRow.'Foundation Baseline Approval Reference') -and
+        -not [string]::IsNullOrWhiteSpace($unitRow.'Baseline Reference') -and
+        -not [string]::IsNullOrWhiteSpace($unitRow.'Trace IDs') -and
+        $unitRow.'Mode Constraint' -cin @('incremental/preserve-existing','greenfield/design-new')
+    }
+    $mode = if ($valid) { [string]$unitRows[0].'Mode Constraint' } else { '' }
+    return [pscustomobject]@{ Valid=$valid; ModeConstraint=$mode }
+  }
   $resolveImmutableEvidence = {
     param([string]$Reference,[string]$ExpectedWorkItem,[string]$ExpectedRevision,[string]$ExpectedTraces,[string]$ExpectedAcceptance,[string]$ExpectedAdapter,[string]$ExpectedApproval,[string]$ExpectedSpecReference,[string]$ExpectedPlanReference,[string]$Context)
     $m=[regex]::Match($Reference,'^(?<path>[^#]+)#sha256:(?<digest>[0-9a-f]{64})$')
     if(-not $m.Success -or [IO.Path]::IsPathRooted($m.Groups['path'].Value) -or $m.Groups['path'].Value -match '(^|[\/])\.\.([\/]|$)'){$errors.Add("$Context requires immutable relative artifact#sha256 reference");return $false}
-    $path=[IO.Path]::GetFullPath((Join-Path $root $m.Groups['path'].Value));if(-not $path.StartsWith($rootPrefix,[StringComparison]::OrdinalIgnoreCase)-or -not(Test-Path -LiteralPath $path -PathType Leaf)){$errors.Add("$Context evidence artifact is missing or foreign");return $false}
+    $path=[IO.Path]::GetFullPath((Join-Path $root $m.Groups['path'].Value));if(-not $path.StartsWith($rootPrefix,[StringComparison]::OrdinalIgnoreCase)-or -not(Test-Path -LiteralPath $path -PathType Leaf)-or[IO.Path]::GetFullPath((Split-Path -Parent $path))-cne$scopeRunDirectory){$errors.Add("$Context evidence artifact is missing or foreign");return $false}
     $bytes=[IO.File]::ReadAllBytes($path);$sha=[Security.Cryptography.SHA256]::Create();try{$actual=([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}
     if($actual -cne $m.Groups['digest'].Value){$errors.Add("$Context evidence digest is stale");return $false}
     $text=[Text.Encoding]::UTF8.GetString($bytes);$fm=& $frontMatter $text $Context
     $keys=@($fm.Keys|Sort-Object);$expected=@('approval_source','produced_at','result','status','step_id')
     $scope=@(& $table $text 'Master Scope Context' @('Master Spec Reference','Master Spec ID','Master Spec Revision','Master Plan Reference','Master Plan ID','Master Plan Revision','Work Item ID','Work Item Approval Reference') $Context)
     $adapter=@(& $table $text 'Canonical Adapter Evidence' @('Work Item ID','Adapter Kind','External ID','Authority','Authority Revision','Approval Reference','Parent Selector','Acceptance','Trace IDs','Mode Constraint','Design Revision','Parent Work Item ID','Decomposition Decision Reference','Canonical Match') $Context)
     $assurance=@(& $table $text 'Assurance State' @('Runtime Evidence State','Architecture Conformance State','Selector Schema State') $Context)
+    $handoff=@(& $table $text 'Architecture Responsibility Handoff' @('Responsibility Contract Version','Tree Conformance','Responsibility Conformance','Verification Ownership','Architecture Conformance State','Evidence References') "$Context work-item terminal")
     $tests=@(& $table $text 'Work Item Test Evidence' @('Work Item ID','Activation Slice ID','Seam','Test','Command','Result','Trace IDs') $Context)
     $allowedTraces=@($ExpectedTraces -split '[;,]' | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Sort-Object -Unique)
     $observedTraces=@($tests | ForEach-Object { $_.'Trace IDs' -split '[;,]' } | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Sort-Object -Unique)
     $badTests=@($tests | Where-Object {
       $_.'Work Item ID' -cne $ExpectedWorkItem -or
       $_.Result -cne 'PASS' -or
       @($_.'Trace IDs' -split '[;,]' | ForEach-Object { $_.Trim() } | Where-Object { $allowedTraces -cnotcontains $_ }).Count
     })
     $adapterKind='none';$externalId='not-applicable';if($ExpectedAdapter-cmatch'^(?<kind>migration-unit|task|story|package|phase|milestone):(?<id>\S+)$'){$adapterKind=$Matches.kind;$externalId=$Matches.id}elseif($ExpectedAdapter-cne'none'){$adapterKind='invalid'}
+    $approvedMode = if($adapter.Count-eq1){& $resolveApprovedAdapterMode $path $adapter[0] $ExpectedAdapter $Context}else{[pscustomobject]@{Valid=$false;ModeConstraint=''}}
     $runtime=if($assurance.Count-eq1){$assurance[0].'Runtime Evidence State'}else{''};$architecture=if($assurance.Count-eq1){$assurance[0].'Architecture Conformance State'}else{''};$selector=if($assurance.Count-eq1){$assurance[0].'Selector Schema State'}else{''}
     $normalLifecycle=($fm.status-ceq'approved'-and$fm.result-ceq'complete'-and$fm.approval_source-ceq'human')
     $blockerHeading=[regex]::Unescape('Blocker g\u1ed1c');$evidenceHeading=[regex]::Unescape('B\u1eb1ng ch\u1ee9ng')
     $selectedUnitColumns=@('Migration Unit ID','Plan Reference','Approval Reference','Mode Constraint','Bootstrap Scope','Foundation Baseline ID','Foundation Baseline Reference','Foundation Baseline Approval Reference','Baseline Reference','Trace IDs')
     $waiverRows=@();$resumeRows=@();$activationRows=@();$waiverEvidenceRows=@();$selectedUnitRows=@();if($runtime-ceq'WAIVED'){$waiverRows=@(& $table $text $blockerHeading @('Stage / Check','Native Verdict','Command Role','Required Command Lifecycle','Command / Capability','Observed Error','Evidence Reference') $Context);$resumeRows=@(& $table $text 'Step 10 Waiver Resume State' @('Resume Phase','Baseline Action','Implementation Status','Target Mutation Evidence','Waiver Evidence') $Context);$activationRows=@(& $table $text 'Activation Slice' @('Activation Slice ID','Applicability','Seam','Input','Output','Source Reference','Trace IDs','Disposition','Status','Decision Reference','Deferred Unit ID') $Context);$waiverEvidenceRows=@(& $table $text $evidenceHeading @('Evidence','Location','Notes') $Context);$selectedUnitRows=@(& $table $text 'Selected Migration Unit' $selectedUnitColumns $Context)}
     $normalized=&$normalize $text;$waiverPattern='(?ms)^## Approved Baseline Waiver\n\n```yaml\nstatus: approved\nresult: partial\napproval_source: auto-waive\nwaiver:\n  policy: auto-waive\n  category: environment-unavailable\n  original_verdict: blocked\n  effective_action: continue\n  evidence: (?<evidence>\S+)\n```\n\n(?=## Step 10 Waiver Resume State$)';$waiverMatch=[regex]::Match($normalized,$waiverPattern)
     $activationColumns=@('Activation Slice ID','Applicability','Seam','Input','Output','Source Reference','Trace IDs','Disposition','Status','Decision Reference','Deferred Unit ID')
     $expectedSeams=@('upstream-response','requested-key','parse-model','state-holder','selector','construct','render','downstream-consumer','test')
     $predecessorActivationRows=@();$predecessorWaiverRows=@();$predecessorResumeRows=@();$predecessorEvidenceRows=@();$predecessorSelectedUnitRows=@();if($runtime -ceq 'WAIVED'){$predecessorActivationRows=@(& $table $predecessorText 'Activation Slice' $activationColumns "$Context predecessor");$predecessorWaiverRows=@(& $table $predecessorText $blockerHeading @('Stage / Check','Native Verdict','Command Role','Required Command Lifecycle','Command / Capability','Observed Error','Evidence Reference') "$Context predecessor");$predecessorResumeRows=@(& $table $predecessorText 'Step 10 Waiver Resume State' @('Resume Phase','Baseline Action','Implementation Status','Target Mutation Evidence','Waiver Evidence') "$Context predecessor");$predecessorEvidenceRows=@(& $table $predecessorText $evidenceHeading @('Evidence','Location','Notes') "$Context predecessor");$predecessorSelectedUnitRows=@(& $table $predecessorText 'Selected Migration Unit' $selectedUnitColumns "$Context predecessor")}
     $normalizedPredecessor=& $normalize $predecessorText;$predecessorWaiverMatch=[regex]::Match($normalizedPredecessor,$waiverPattern)
@@ -1679,42 +1938,52 @@ function Test-FlexibleScopeFixtureEnvelope([string]$FixturePath) {
       $waiverRows[0].'Evidence Reference' -ceq $waiverMatch.Groups['evidence'].Value -and
       $resumeRows.Count -eq 1 -and
       $resumeRows[0].'Resume Phase' -ceq 'resume-consumed' -and
       $resumeRows[0].'Baseline Action' -ceq 'skip-pre-mutation-baseline-only' -and
       $resumeRows[0].'Implementation Status' -cne 'blocked' -and
       $resumeMutationValid -and
       $resumeRows[0].'Waiver Evidence' -ceq $waiverMatch.Groups['evidence'].Value -and
       $activationValid -and $waiverEvidenceRows.Count -ge 1 -and
       $normalized -cmatch '(?ms)^## B\u1eb1ng ch\u1ee9ng\n.*?\n## \u0110i\u1ec3m ch\u01b0a r\u00f5\n\n- none\n\n## K\u1ebft lu\u1eadn\n\npartial\n?$'
     )
+    $derivedResponsibilityArchitecture=if($handoff.Count-eq1-and$handoff[0].'Tree Conformance'-ceq'PASS'-and$handoff[0].'Responsibility Conformance'-ceq'PASS'-and$handoff[0].'Verification Ownership'-ceq'PASS'){'PASS'}else{'BLOCKED'}
+    $responsibilityEvidenceValid=(
+      $handoff.Count-eq1 -and
+      $handoff[0].'Responsibility Contract Version'-ceq'1' -and
+      $handoff[0].'Tree Conformance'-ceq'PASS' -and
+      $handoff[0].'Responsibility Conformance'-ceq'PASS' -and
+      $handoff[0].'Verification Ownership'-ceq'PASS' -and
+      $handoff[0].'Architecture Conformance State'-ceq$derivedResponsibilityArchitecture -and
+      $handoff[0].'Evidence References'-cmatch'^[^#]+#sha256:[0-9a-f]{64}$'
+    )
     $valid=(
       (($keys -join '|') -ceq ($expected -join '|')) -and
       $fm.step_id -ceq '10-code-migration' -and $fm.produced_at -cmatch '^20[0-9]{2}-[0-9]{2}-[0-9]{2}$' -and
       $scope.Count -eq 1 -and
       $scope[0].'Master Spec Reference' -ceq $ExpectedSpecReference -and
       $scope[0].'Master Spec ID' -ceq $specFm.master_spec_id -and
       $scope[0].'Master Spec Revision' -ceq $specFm.revision -and
       $scope[0].'Master Plan Reference' -ceq $ExpectedPlanReference -and
       $scope[0].'Master Plan ID' -ceq $planFm.master_plan_id -and
       $scope[0].'Master Plan Revision' -ceq $ExpectedRevision -and
       $scope[0].'Work Item ID' -ceq $ExpectedWorkItem -and
       $scope[0].'Work Item Approval Reference' -ceq $ExpectedApproval -and
       $adapter.Count -eq 1 -and $adapter[0].'Work Item ID' -ceq $ExpectedWorkItem -and
       $adapter[0].'Adapter Kind' -ceq $adapterKind -and $adapter[0].'External ID' -ceq $externalId -and
       $adapter[0].Acceptance -ceq $ExpectedAcceptance -and $adapter[0].'Trace IDs' -ceq $ExpectedTraces -and
-      $adapter[0].'Canonical Match' -ceq 'PASS' -and $tests.Count -ge 1 -and $badTests.Count -eq 0 -and
+      $adapter[0].'Canonical Match' -ceq 'PASS' -and $approvedMode.Valid -and $tests.Count -ge 1 -and $badTests.Count -eq 0 -and
       (($observedTraces -join '|') -ceq ($allowedTraces -join '|')) -and
-      $architecture -ceq 'PASS' -and $selector -ceq 'PASS' -and
+      $architecture -ceq 'PASS' -and $selector -ceq 'PASS' -and $responsibilityEvidenceValid -and
       (($runtime -ceq 'PASS' -and $normalLifecycle -and -not $waiverMatch.Success) -or
        ($runtime -ceq 'WAIVED' -and $eligibleWaiver))
     )
-    if(-not$valid){$errors.Add("$Context implementation evidence binding is invalid [scope=$($scope.Count), adapter=$($adapter.Count), assurance=$($assurance.Count), tests=$($tests.Count), runtime=$runtime, architecture=$architecture, selector=$selector, lifecycle=$normalLifecycle, waiver=$eligibleWaiver, waiverMatch=$($waiverMatch.Success), waiverRows=$($waiverRows.Count), traces=$($observedTraces-join';')/$($allowedTraces-join';'), specRef=$($scope[0].'Master Spec Reference')/$ExpectedSpecReference, planRef=$($scope[0].'Master Plan Reference')/$ExpectedPlanReference, approval=$($scope[0].'Work Item Approval Reference')/$ExpectedApproval]")};[pscustomobject]@{Valid=$valid;Runtime=$runtime;Architecture=$architecture;Selector=$selector}
+    if(-not$valid){$observedSpecRef=if($scope.Count-eq1){$scope[0].'Master Spec Reference'}else{'missing'};$observedPlanRef=if($scope.Count-eq1){$scope[0].'Master Plan Reference'}else{'missing'};$observedApproval=if($scope.Count-eq1){$scope[0].'Work Item Approval Reference'}else{'missing'};$errors.Add("$Context implementation evidence binding is invalid [scope=$($scope.Count), adapter=$($adapter.Count), assurance=$($assurance.Count), tests=$($tests.Count), runtime=$runtime, architecture=$architecture, selector=$selector, responsibilityEvidence=$responsibilityEvidenceValid, approvedMode=$($approvedMode.Valid), lifecycle=$normalLifecycle, waiver=$eligibleWaiver, waiverMatch=$($waiverMatch.Success), waiverRows=$($waiverRows.Count), traces=$($observedTraces-join';')/$($allowedTraces-join';'), specRef=$observedSpecRef/$ExpectedSpecReference, planRef=$observedPlanRef/$ExpectedPlanReference, approval=$observedApproval/$ExpectedApproval]")};[pscustomobject]@{Valid=$valid;Runtime=$runtime;Architecture=$architecture;Selector=$selector;ModeConstraint=[string]$approvedMode.ModeConstraint;Handoff=if($handoff.Count-eq1){$handoff[0]}else{$null}}
   }
   $resolveHistoricalEvidence={param([string]$Reference,[string]$LegacyUnit,[string]$Context)
     $columns=@('Migration Unit ID','Plan Reference','Approval Reference','Mode Constraint','Bootstrap Scope','Foundation Baseline ID','Foundation Baseline Reference','Foundation Baseline Approval Reference','Baseline Reference','Trace IDs')
     $referenceMatch=[regex]::Match($Reference,'^(?<path>[^#]+)#sha256:(?<digest>[0-9a-f]{64})$')
     if(-not $referenceMatch.Success){$errors.Add("$Context historical reference invalid");return $false}
     $path=[IO.Path]::GetFullPath((Join-Path $root $referenceMatch.Groups['path'].Value))
     if(-not $path.StartsWith($rootPrefix,[StringComparison]::OrdinalIgnoreCase) -or -not(Test-Path -LiteralPath $path -PathType Leaf)){return $false}
     $bytes=[IO.File]::ReadAllBytes($path);$sha=[Security.Cryptography.SHA256]::Create()
     try{$actual=([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}
     if($actual -cne $referenceMatch.Groups['digest'].Value){return $false}
@@ -1769,46 +2038,39 @@ function Test-FlexibleScopeFixtureEnvelope([string]$FixturePath) {
     ){return $false}
     foreach($column in $columns){if($rows[0].$column -cne $authorityRows[0].$column){return $false}}
     return (
       $rows[0].'Approval Reference' -cmatch '^approval:HUMAN-' -and
       $rows[0].'Mode Constraint' -cin @('incremental/preserve-existing','greenfield/design-new') -and
       $rows[0].'Bootstrap Scope' -cin @('required','not-required') -and
       -not [string]::IsNullOrWhiteSpace($rows[0].'Trace IDs')
     )
   }
 
-  $specText = Get-Content -Raw -Encoding utf8 -LiteralPath $resolvedEvidence.master_spec_ref
-  $planText = Get-Content -Raw -Encoding utf8 -LiteralPath $resolvedEvidence.master_plan_ref
-  $predecessorText = Get-Content -Raw -Encoding utf8 -LiteralPath $resolvedEvidence.predecessor_ref
-  $targetText = Get-Content -Raw -Encoding utf8 -LiteralPath $resolvedEvidence.target_evidence_ref
-  $specFm = & $frontMatter $specText 'Flexible scope master spec'
-  $planFm = & $frontMatter $planText 'Flexible scope master plan'
-  $preFm = & $frontMatter $predecessorText 'Flexible scope predecessor'
-  $targetFm = & $frontMatter $targetText 'Flexible scope target evidence'
   . (Join-Path $root 'tests/validation/scope-artifacts.validation.ps1')
   $renderValidationRoot=Join-Path $root ('.flexible-scope-canonical-'+[guid]::NewGuid().ToString('N'))
   try{
    New-Item -ItemType Directory -Path (Join-Path $renderValidationRoot 'templates/migration') -Force|Out-Null
    Copy-Item -LiteralPath (Join-Path $root 'contracts') -Destination (Join-Path $renderValidationRoot 'contracts') -Recurse
    Copy-Item -LiteralPath $resolvedEvidence.master_spec_ref -Destination (Join-Path $renderValidationRoot 'templates/migration/master-spec.md')
    Copy-Item -LiteralPath $resolvedEvidence.master_plan_ref -Destination (Join-Path $renderValidationRoot 'templates/migration/master-plan.md')
    Test-ScopeArtifacts $renderValidationRoot (Get-Content -Raw -Encoding utf8 (Join-Path $root 'contracts/migration-scope-orchestration.md'))
   }finally{if(Test-Path -LiteralPath $renderValidationRoot){Remove-Item -LiteralPath $renderValidationRoot -Recurse -Force}}
   $planRows = @(& $table $planText 'Work Items' @('Work Item ID','Title','Required','Dependencies','Plan Order','Acceptance','Trace IDs','Delivery Adapter','Status','Latest Attempt','Terminal Evidence','Approval Reference') 'Flexible scope master plan')
   $planApprovalRows=@(& $table $planText 'Approval Record' @('Approval Reference','Status','Approved At') 'Flexible scope master plan')
   $planRevisionRows=@(& $table $planText 'Revision History' @('Artifact ID','Revision','Supersedes','Change Summary','Affected Work Items','Approval Reference') 'Flexible scope master plan')
   $diagnostic = 'scope-ready'; $scopeState = 'planned'
   $specKeys=@($specFm.Keys|Sort-Object);$canonicalSpecKeys=@('approval_source','artifact_type','master_spec_id','produced_at','requested_scope_id','requested_scope_kind','result','revision','status','supersedes')
   $planKeys=@($planFm.Keys|Sort-Object);$canonicalPlanKeys=@('artifact_type','execution_policy','master_plan_id','master_spec_id','master_spec_revision','max_concurrency','produced_at','revision','scope_status','status','supersedes')
   if(($specKeys-join'|')-cne($canonicalSpecKeys-join'|')-or($planKeys-join'|')-cne($canonicalPlanKeys-join'|')){$diagnostic='master-artifact-schema-invalid';$scopeState='scope-blocked'}
   elseif($planApprovalRows.Count-ne1-or$planApprovalRows[0].Status-cne'approved'-or$planApprovalRows[0].'Approval Reference'-cnotmatch'^approval:HUMAN-'-or$planRevisionRows.Count-ne1-or$planRevisionRows[0].Revision-cne$planFm.revision-or$planRevisionRows[0].'Approval Reference'-cne$planApprovalRows[0].'Approval Reference'){$diagnostic='master-artifact-current-approval-invalid';$scopeState='scope-blocked'}
   elseif ($preFm.status -cne 'approved') { $diagnostic='predecessor-not-approved'; $scopeState='scope-blocked' }
+  elseif (-not $queueResponsibilityAuthorityValid) { $diagnostic='structural-assurance-blocked'; $scopeState='scope-blocked' }
   elseif ($specFm.status -cne 'approved' -or $planFm.status -cne 'approved') { $diagnostic='master-artifacts-unapproved'; $scopeState='scope-blocked' }
   elseif ($specFm.requested_scope_kind -ceq 'unresolved') { $diagnostic='scope-question-required'; $scopeState='scope-blocked' }
   elseif ($planFm.revision -cne '1' -and ([string]::IsNullOrWhiteSpace([string]$planFm.supersedes) -or $planFm.supersedes -in @('none','not-applicable'))) { $diagnostic='revision-chain-invalid'; $scopeState='scope-blocked' }
   elseif (@($planRows | Group-Object 'Work Item ID' | Where-Object Count -ne 1).Count -gt 0) { $diagnostic='work-item-set-invalid'; $scopeState='scope-blocked' }
   else {
     $ids=@($planRows | ForEach-Object { $_.'Work Item ID' })
     foreach($row in $planRows){
       if($row.Required -notin @('yes','no') -or $row.Status -notin @('proposed','pending','ready','in-progress','blocked','complete','cancelled-approved','not-applicable-approved') -or $row.'Plan Order' -cnotmatch '^[1-9][0-9]*$' -or [string]::IsNullOrWhiteSpace($row.'Approval Reference')){$diagnostic='work-item-row-invalid';$scopeState='scope-blocked'}
       if($row.Status -eq 'complete' -and $row.'Terminal Evidence' -eq 'none'){$diagnostic='work-item-row-invalid';$scopeState='scope-blocked'}
     }
@@ -1853,45 +2115,68 @@ function Test-FlexibleScopeFixtureEnvelope([string]$FixturePath) {
       if($diagnostic -cne 'legacy-conversion-invalid'){$diagnostic='legacy-conversion-approved-no-scope-inference';$scopeState='planned'}
     }
   }
 
   if ($resolvedEvidence.ContainsKey('terminal_report_ref')) {
     $priorDiagnostic=$diagnostic;$priorScopeState=$scopeState;$priorBlocked=$scopeState-ceq'scope-blocked'
     $reportText=Get-Content -Raw -Encoding utf8 -LiteralPath $resolvedEvidence.terminal_report_ref
     $reportFm=& $frontMatter $reportText 'Terminal scope report'
     $contextRows=@(& $table $reportText 'Master Revision Context' @('Master Spec Reference','Master Spec Revision','Master Plan Reference','Master Plan Revision','Terminal Report Reference') 'Terminal scope report')
     $reportRows=@(& $table $reportText 'Work Item Terminal Evidence' @('Work Item ID','Required','Status','Terminal Evidence','Runtime Evidence State','Architecture Conformance State','Selector Schema State','Blocker','Plan Revision') 'Terminal scope report')
-    $calc=@(& $table $reportText 'Scope Completion Calculation' @('Graph State','Required Items','Required Terminal Evidence','Architecture State','Selector Schema State','Remaining Blockers','Calculated Terminal Verdict') 'Terminal scope report')
+    $calc=@(& $table $reportText 'Scope Completion Calculation' @('Graph State','Required Items','Required Terminal Evidence','Tree Conformance','Responsibility Conformance','Verification Ownership','Architecture State','Selector Schema State','Remaining Blockers','Calculated Terminal Verdict') 'Terminal scope report')
+    $handoff=@(& $table $reportText 'Architecture Responsibility Handoff' @('Responsibility Contract Version','Tree Conformance','Responsibility Conformance','Verification Ownership','Architecture Conformance State','Evidence References') 'Terminal scope report')
     $evidenceRows=@(& $table $reportText 'Evidence Index' @('Evidence ID','Artifact Reference','Work Item ID','Purpose') 'Terminal scope report')
     $blockerRows=@(& $table $reportText 'Blockers and Dispositions' @('Work Item ID','Blocker','Disposition','Decision Reference') 'Terminal scope report')
     $approvalRows=@(& $table $reportText 'Approval Record' @('Decision','Approver','Evidence','Decided At') 'Terminal scope report')
     $revisionRows=@(& $table $reportText 'Revision History' @('Artifact ID','Revision','Supersedes','Change Summary','Affected Work Items','Approval Reference') 'Terminal scope report')
     $planIds=@($planRows|ForEach-Object{$_.'Work Item ID'}|Sort-Object);$reportIds=@($reportRows|ForEach-Object{$_.'Work Item ID'}|Sort-Object)
     $reportKeys=@($reportFm.Keys|Sort-Object);$expectedReportKeys=@('approval_source','artifact_type','master_plan_id','master_plan_revision','master_spec_id','master_spec_revision','produced_at','result','scope_status','status')
-    $valid=(($reportKeys -join '|') -ceq ($expectedReportKeys -join '|') -and $reportFm.artifact_type -ceq 'migration-scope-terminal-report' -and $reportFm.master_spec_id -ceq $specFm.master_spec_id -and $reportFm.master_plan_id -ceq $planFm.master_plan_id -and $reportFm.master_spec_revision -ceq $specFm.revision -and $reportFm.master_plan_revision -ceq $planFm.revision -and $reportFm.status -ceq 'approved' -and $reportFm.result -ceq 'complete' -and $reportFm.approval_source -ceq 'human' -and $reportFm.produced_at -cmatch '^20[0-9]{2}-[0-9]{2}-[0-9]{2}$' -and $reportFm.scope_status -in @('scope-in-progress','scope-blocked','scope-complete') -and ($planIds -join '|') -ceq ($reportIds -join '|') -and $reportIds.Count -eq $planIds.Count -and $contextRows.Count -eq 1 -and $calc.Count -eq 1 -and $approvalRows.Count -eq 1 -and $revisionRows.Count -eq 1)
+    $derivedReportArchitecture=if($handoff.Count-eq1-and$handoff[0].'Tree Conformance'-ceq'PASS'-and$handoff[0].'Responsibility Conformance'-ceq'PASS'-and$handoff[0].'Verification Ownership'-ceq'PASS'){'PASS'}else{'BLOCKED'}
+    $structuralTerminalBlocked=($structuralResponsibilityChainBlocked -or ($handoff.Count-eq1-and($handoff[0].'Tree Conformance'-cne'PASS'-or$handoff[0].'Responsibility Conformance'-cne'PASS'-or$handoff[0].'Verification Ownership'-cne'PASS'-or$handoff[0].'Architecture Conformance State'-cne'PASS')))
+    $chainIds=@($responsibilityChainByWorkItem.Keys|Sort-Object)
+    $terminalSuccessIds=@($planRows|Where-Object{$_.Status-in@('complete','cancelled-approved','not-applicable-approved')}|ForEach-Object{$_.'Work Item ID'}|Sort-Object)
+    $valid=($responsibilityChainValid -and (($chainIds-join'|')-ceq($terminalSuccessIds-join'|')) -and ($reportKeys -join '|') -ceq ($expectedReportKeys -join '|') -and $reportFm.artifact_type -ceq 'migration-scope-terminal-report' -and $reportFm.master_spec_id -ceq $specFm.master_spec_id -and $reportFm.master_plan_id -ceq $planFm.master_plan_id -and $reportFm.master_spec_revision -ceq $specFm.revision -and $reportFm.master_plan_revision -ceq $planFm.revision -and $reportFm.status -ceq 'approved' -and $reportFm.result -ceq 'complete' -and $reportFm.approval_source -ceq 'human' -and $reportFm.produced_at -cmatch '^20[0-9]{2}-[0-9]{2}-[0-9]{2}$' -and $reportFm.scope_status -in @('scope-in-progress','scope-blocked','scope-complete') -and ($planIds -join '|') -ceq ($reportIds -join '|') -and $reportIds.Count -eq $planIds.Count -and $contextRows.Count -eq 1 -and $calc.Count -eq 1 -and $handoff.Count -eq 1 -and $handoff[0].'Responsibility Contract Version' -ceq '1' -and $handoff[0].'Tree Conformance' -cin @('PASS','BLOCKED') -and $handoff[0].'Responsibility Conformance' -cin @('PASS','BLOCKED') -and $handoff[0].'Verification Ownership' -cin @('PASS','BLOCKED') -and $handoff[0].'Architecture Conformance State' -ceq $derivedReportArchitecture -and $approvalRows.Count -eq 1 -and $revisionRows.Count -eq 1)
     if($contextRows.Count -eq 1 -and ($contextRows[0].'Master Spec Reference' -cne 'master-spec.md' -or $contextRows[0].'Master Spec Revision' -cne $specFm.revision -or $contextRows[0].'Master Plan Reference' -cne 'master-plan.md' -or $contextRows[0].'Master Plan Revision' -cne $planFm.revision -or $contextRows[0].'Terminal Report Reference' -cne 'scope-terminal-report.md')){$valid=$false}
     if($approvalRows.Count -eq 1 -and ($approvalRows[0].Decision -cne 'approved' -or $approvalRows[0].Approver -cne 'human' -or $approvalRows[0].Evidence -cnotmatch '^approval:HUMAN-' -or $approvalRows[0].'Decided At' -cnotmatch '^20[0-9]{2}-[0-9]{2}-[0-9]{2}$')){$valid=$false}
-    if($revisionRows.Count -eq 1 -and ($revisionRows[0].Revision -cne '1' -or $revisionRows[0].Supersedes -cne 'not-applicable' -or $revisionRows[0].'Affected Work Items' -cne 'all' -or $revisionRows[0].'Approval Reference' -cne $approvalRows[0].Evidence)){$valid=$false}
+    if($revisionRows.Count -eq 1 -and ($revisionRows[0].Revision -cne '1' -or $revisionRows[0].Supersedes -cne 'not-applicable' -or $revisionRows[0].'Affected Work Items' -cne 'all' -or $approvalRows.Count -ne 1 -or $revisionRows[0].'Approval Reference' -cne $approvalRows[0].Evidence)){$valid=$false}
     $evidenceIds=@($evidenceRows|ForEach-Object{$_.'Work Item ID'}|Sort-Object);$blockerIds=@($blockerRows|ForEach-Object{$_.'Work Item ID'}|Sort-Object)
-    if(($evidenceIds-join'|') -cne ($planIds-join'|') -or ($blockerIds-join'|') -cne ($planIds-join'|') -or @($evidenceRows|Group-Object 'Evidence ID'|Where-Object Count -ne 1).Count -gt 0){$valid=$false}
+    if(($evidenceIds-join'|') -cne ($terminalSuccessIds-join'|') -or ($blockerIds-join'|') -cne ($planIds-join'|') -or @($evidenceRows|Group-Object 'Evidence ID'|Where-Object Count -ne 1).Count -gt 0){$valid=$false}
+    $resolvedResponsibilityTerminals=[Collections.Generic.List[string]]::new()
     foreach($p in $planRows){
       $r=@($reportRows|Where-Object{$_.'Work Item ID' -ceq $p.'Work Item ID'});if($r.Count-ne 1 -or $r[0].Required-cne$p.Required -or $r[0].Status-cne$p.Status -or $r[0].'Terminal Evidence'-cne$p.'Terminal Evidence' -or $r[0].'Plan Revision'-cne$planFm.revision){$valid=$false;continue}
       $e=@($evidenceRows|Where-Object{$_.'Work Item ID' -ceq $p.'Work Item ID'});$b=@($blockerRows|Where-Object{$_.'Work Item ID' -ceq $p.'Work Item ID'})
-      if($e.Count-ne1 -or $e[0].'Artifact Reference' -cne $r[0].'Terminal Evidence' -or $b.Count-ne1 -or $b[0].Blocker -cne $r[0].Blocker -or ($r[0].Blocker-ceq'none' -and ($b[0].Disposition-cne'not-applicable' -or $b[0].'Decision Reference'-cne'not-applicable'))){$valid=$false}
+      $chainEntry=if($responsibilityChainByWorkItem.ContainsKey([string]$p.'Work Item ID')){$responsibilityChainByWorkItem[[string]$p.'Work Item ID']}else{$null}
+      $terminalSuccess=$p.Status-in@('complete','cancelled-approved','not-applicable-approved')
+      if(($terminalSuccess-and($e.Count-ne1-or$null-eq$chainEntry-or$e[0].'Artifact Reference'-cne$chainEntry.FinalReference-or$e[0].Purpose-cne'architecture-responsibility-sub-verdicts'))-or(-not$terminalSuccess-and$e.Count-ne0)-or$b.Count-ne1-or$b[0].Blocker-cne$r[0].Blocker-or($r[0].Blocker-ceq'none'-and($b[0].Disposition-cne'not-applicable'-or$b[0].'Decision Reference'-cne'not-applicable'))){$valid=$false}
+      if($terminalSuccess-and$null-ne$chainEntry-and$handoff.Count-eq1){foreach($field in @('Responsibility Contract Version','Tree Conformance','Responsibility Conformance','Verification Ownership','Architecture Conformance State')){if($chainEntry.Handoff.$field-cne$handoff[0].$field){$valid=$false}}}
       if($r[0].'Runtime Evidence State' -notin @('PASS','FAIL','NOT_RUN','WAIVED') -or $r[0].'Architecture Conformance State' -notin @('PASS','BLOCKED') -or $r[0].'Selector Schema State' -notin @('PASS','BLOCKED')){$valid=$false}
-      if($p.Status-in@('complete','cancelled-approved','not-applicable-approved')){$terminalBinding=& $resolveImmutableEvidence $r[0].'Terminal Evidence' $p.'Work Item ID' $planFm.revision $p.'Trace IDs' $p.Acceptance $p.'Delivery Adapter' $p.'Approval Reference' ([string]$fixture.master_spec_ref) ([string]$fixture.master_plan_ref) 'Terminal scope report';if(-not$terminalBinding.Valid-or$r[0].'Runtime Evidence State'-cne$terminalBinding.Runtime-or$r[0].'Architecture Conformance State'-cne$terminalBinding.Architecture-or$r[0].'Selector Schema State'-cne$terminalBinding.Selector){$valid=$false}}elseif($r[0].'Terminal Evidence'-cne'none'){$valid=$false}
+      if($terminalSuccess){
+        $terminalBindingResults=@(& $resolveImmutableEvidence $r[0].'Terminal Evidence' $p.'Work Item ID' $planFm.revision $p.'Trace IDs' $p.Acceptance $p.'Delivery Adapter' $p.'Approval Reference' ([string]$fixture.master_spec_ref) ([string]$fixture.master_plan_ref) 'Terminal scope report')
+        $terminalBindings=@($terminalBindingResults|Where-Object{$null-ne$_-and$null-ne$_.PSObject.Properties['Valid']})
+        $terminalBinding=if($terminalBindings.Count-eq1){$terminalBindings[0]}else{$null}
+        if($null-eq$terminalBinding-or-not$terminalBinding.Valid-or$r[0].'Runtime Evidence State'-cne$terminalBinding.Runtime-or$r[0].'Architecture Conformance State'-cne$terminalBinding.Architecture-or$r[0].'Selector Schema State'-cne$terminalBinding.Selector-or$null-eq$chainEntry-or$terminalBinding.ModeConstraint-cne$chainEntry.ModeConstraint-or$null-eq$terminalBinding.Handoff-or$terminalBinding.Handoff.'Evidence References'-cne$chainEntry.FinalReference){$valid=$false}
+        else{
+          foreach($field in @('Responsibility Contract Version','Tree Conformance','Responsibility Conformance','Verification Ownership','Architecture Conformance State')){if($terminalBinding.Handoff.$field-cne$chainEntry.Handoff.$field){$valid=$false}}
+          $resolvedResponsibilityTerminals.Add([string]$chainEntry.FinalReference)
+        }
+      }elseif($r[0].'Terminal Evidence'-cne'none'){$valid=$false}
       if($r[0].Status -in @('complete','cancelled-approved','not-applicable-approved')){if($r[0].Blocker -cne 'none'){$valid=$false}}elseif($r[0].Status-ceq'blocked'-and$r[0].Blocker-ceq'none'){$valid=$false}
       if($r[0].'Runtime Evidence State' -ceq 'WAIVED' -and $r[0].Status -cne 'complete'){$valid=$false}
     }
-    $formula=($calc[0].'Graph State'-ceq'valid' -and $calc[0].'Required Items'-ceq'all-terminal-success' -and $calc[0].'Required Terminal Evidence'-ceq'all-required-terminal-evidence' -and $calc[0].'Architecture State'-ceq'PASS' -and $calc[0].'Selector Schema State'-ceq'PASS' -and $calc[0].'Remaining Blockers'-ceq'none' -and @($reportRows|Where-Object{$_.Required-ceq'yes' -and ($_.Status -notin @('complete','cancelled-approved','not-applicable-approved') -or $_.'Terminal Evidence'-ceq'none' -or $_.'Runtime Evidence State'-notin@('PASS','WAIVED') -or $_.'Architecture Conformance State'-cne'PASS' -or $_.'Selector Schema State'-cne'PASS' -or $_.Blocker-cne'none')}).Count-eq0)
+    if($handoff.Count-eq1){
+      $declaredResponsibilityTerminals=@($handoff[0].'Evidence References'-split';'|ForEach-Object{$_.Trim()}|Where-Object{$_})
+      if(($declaredResponsibilityTerminals-join'|')-cne($resolvedResponsibilityTerminals.ToArray()-join'|')-or@($declaredResponsibilityTerminals|Group-Object|Where-Object Count -ne 1).Count -gt 0){$valid=$false}
+      if($calc.Count-eq1-and($calc[0].'Tree Conformance'-cne$handoff[0].'Tree Conformance'-or$calc[0].'Responsibility Conformance'-cne$handoff[0].'Responsibility Conformance'-or$calc[0].'Verification Ownership'-cne$handoff[0].'Verification Ownership'-or$calc[0].'Architecture State'-cne$handoff[0].'Architecture Conformance State')){$valid=$false}
+    }else{$valid=$false}
+    $formula=($calc[0].'Graph State'-ceq'valid' -and $calc[0].'Required Items'-ceq'all-terminal-success' -and $calc[0].'Required Terminal Evidence'-ceq'all-required-terminal-evidence' -and $calc[0].'Tree Conformance'-ceq'PASS' -and $calc[0].'Responsibility Conformance'-ceq'PASS' -and $calc[0].'Verification Ownership'-ceq'PASS' -and $calc[0].'Architecture State'-ceq'PASS' -and $calc[0].'Selector Schema State'-ceq'PASS' -and $calc[0].'Remaining Blockers'-ceq'none' -and @($reportRows|Where-Object{$_.Required-ceq'yes' -and ($_.Status -notin @('complete','cancelled-approved','not-applicable-approved') -or $_.'Terminal Evidence'-ceq'none' -or $_.'Runtime Evidence State'-notin@('PASS','WAIVED') -or $_.'Architecture Conformance State'-cne'PASS' -or $_.'Selector Schema State'-cne'PASS' -or $_.Blocker-cne'none')}).Count-eq0)
     $computedVerdict=if($formula){'scope-complete'}elseif(@($reportRows|Where-Object{$_.Required-ceq'yes'-and $_.Status-eq'blocked'}).Count){'scope-blocked'}else{'scope-in-progress'}
-    if(-not $valid -or $calc[0].'Calculated Terminal Verdict' -cne $computedVerdict -or $reportFm.scope_status -cne $computedVerdict){$diagnostic='terminal-scope-report-invalid';$scopeState='scope-blocked'}elseif($formula){$diagnostic='scope-completion-calculated';$scopeState='scope-complete'}
+    if(-not $valid -or $calc[0].'Calculated Terminal Verdict' -cne $computedVerdict -or $reportFm.scope_status -cne $computedVerdict){$diagnostic=if($structuralTerminalBlocked){'structural-assurance-blocked'}else{'terminal-scope-report-invalid'};$scopeState='scope-blocked'}elseif($formula){$diagnostic='scope-completion-calculated';$scopeState='scope-complete'}
     if($priorBlocked){$diagnostic=$priorDiagnostic;$scopeState=$priorScopeState}
   }
   Write-Output "DIAGNOSTIC: $diagnostic"
   Write-Output "SCOPE_STATE: $scopeState"
   if ($diagnostic -cne [string]$fixture.expected_diagnostic -or $scopeState -cne [string]$fixture.expected_scope_state) { $errors.Add("Flexible scope rendered fixture outcome mismatch: expected $($fixture.expected_diagnostic)/$($fixture.expected_scope_state), got $diagnostic/$scopeState") }
 }
 
 function Test-FlexibleScopeIntegration([bool]$InvokeModules) {
   $scopeContractPath = Join-Path $root 'contracts/migration-scope-orchestration.md'
   $conformanceContractPath = Join-Path $root 'contracts/target-structure-conformance.md'
@@ -1923,30 +2208,40 @@ function Test-FlexibleScopeIntegration([bool]$InvokeModules) {
   if (Test-Path -LiteralPath $terminalTemplatePath -PathType Leaf) {
     $terminalTemplate = Get-Content -Raw -Encoding utf8 -LiteralPath $terminalTemplatePath
     @(
       'artifact_type: migration-scope-terminal-report',
       'master_spec_revision:',
       'master_plan_revision:',
       'scope_status:',
       '## Master Revision Context',
       '## Work Item Terminal Evidence',
       '## Scope Completion Calculation',
+      '## Architecture Responsibility Handoff',
       '## Evidence Index',
       '## Blockers and Dispositions',
       '## Approval Record',
       '## Revision History'
     ) | ForEach-Object { Require-Token $terminalTemplate $_ 'Migration scope terminal report template' }
+    @(
+      'ordered immutable terminal evidence references resolved from Work Item Terminal Evidence',
+      'Terminal Evidence` resolves only the immutable work-item terminal artifact',
+      'same final ordered-chain artifact referenced by the work-item terminal handoff',
+      'architecture-responsibility-sub-verdicts'
+    ) | ForEach-Object { Require-Token $terminalTemplate $_ 'Migration scope terminal report responsibility provenance' }
     Test-MarkdownTableExactColumns $terminalTemplate 'Work Item Terminal Evidence' `
       @('Work Item ID', 'Required', 'Status', 'Terminal Evidence', 'Runtime Evidence State', 'Architecture Conformance State', 'Selector Schema State', 'Blocker', 'Plan Revision') `
       'Migration scope terminal report template'
     Test-MarkdownTableExactColumns $terminalTemplate 'Scope Completion Calculation' `
-      @('Graph State', 'Required Items', 'Required Terminal Evidence', 'Architecture State', 'Selector Schema State', 'Remaining Blockers', 'Calculated Terminal Verdict') `
+      @('Graph State', 'Required Items', 'Required Terminal Evidence', 'Tree Conformance', 'Responsibility Conformance', 'Verification Ownership', 'Architecture State', 'Selector Schema State', 'Remaining Blockers', 'Calculated Terminal Verdict') `
+      'Migration scope terminal report template'
+    Test-MarkdownTableExactColumns $terminalTemplate 'Architecture Responsibility Handoff' `
+      @('Responsibility Contract Version', 'Tree Conformance', 'Responsibility Conformance', 'Verification Ownership', 'Architecture Conformance State', 'Evidence References') `
       'Migration scope terminal report template'
   }
 
   foreach ($schemaRequirement in @(
     'artifact_type: migration-scope-terminal-report',
     'Work Item Terminal Evidence',
     'Scope Completion Calculation',
     'fresh human approval gate'
   )) {
     $schemaPath = Join-Path $root 'skills/aitoolkit-schemas/SKILL.md'
@@ -6367,20 +6662,31 @@ function Test-Skills {
     'Test-StructuralGate' `
     'Structural pre-edit gate' `
     $root `
     $conformanceContractText
   Invoke-MigrationValidationModule `
     'tests/validation/architecture-review.validation.ps1' `
     'Test-ArchitectureReview' `
     'Architecture-first review order' `
     $root `
     $conformanceContractText
+  $migrateSkillPath = Join-Path $root 'skills/aitoolkit/migrate/SKILL.md'
+  if (-not (Test-Path -LiteralPath $migrateSkillPath -PathType Leaf)) {
+    $errors.Add('Missing migration orchestrator responsibility rollout contract')
+  }
+  elseif ($null -eq $script:MigrationResponsibilityRolloutValidator) {
+    $errors.Add('Architecture review validator did not expose its private migration responsibility rollout validator')
+  }
+  else {
+    $migrateSkillText = Get-Content -Raw -Encoding utf8 -LiteralPath $migrateSkillPath
+    foreach ($diagnostic in @(& $script:MigrationResponsibilityRolloutValidator $migrateSkillText)) { $errors.Add($diagnostic) }
+  }
   $languageProducerSkills = @(
     'migration/validate-inputs', 'migration/discovery', 'migration/analyze-requirements-uiux',
     'migration/build-inventory', 'migration/feature-mapping', 'migration/analyze-gaps-conflicts',
     'migration/technical-design', 'migration/plan-waves', 'migration/bootstrap-target',
     'migration/code-migration', 'migration/verify-parity', 'migration/verify-regression',
     'migration-onboarding/inspect-project', 'migration-onboarding/classify-mode',
     'migration-onboarding/create-project-pack', 'shared/ai-review',
     'shared/verification-testing', 'shared/knowledge-base'
   )
   foreach ($languageProducerSkill in $languageProducerSkills) {
@@ -7378,26 +7684,28 @@ function Test-Orchestrators {
       $skillContract.Context
     @(
       '`workflow_type: migration`', 'feature and bugfix', 'immediate predecessor',
       '`Selected Migration Unit`', '`migration_unit_id`', 'plan reference',
       'approval reference', 'mode constraint', '`Bootstrap Scope`', 'Foundation Baseline ID',
       'foundation baseline reference', 'foundation baseline approval reference', 'baseline reference', 'trace IDs',
       '`result: complete | blocked`', '`result: blocked`'
     ) | ForEach-Object {
       Require-Token $extensionText $_ $skillContract.Context
     }
-    @(
-      'Architecture Responsibility Handoff', 'immediate', 'ordinally exact',
-      'Architecture Conformance State', 'Evidence References',
-      'cumulative artifacts', 'directory scans', 'result: blocked'
-    ) | ForEach-Object {
-      Require-Token $skillText $_ "$($skillContract.Context) responsibility provenance"
+    if ($skillContract.Path -cne 'skills/shared/ai-review/SKILL.md') {
+      @(
+        'Architecture Responsibility Handoff', 'immediate', 'ordinally exact',
+        'Architecture Conformance State', 'Evidence References',
+        'cumulative artifacts', 'directory scans', 'result: blocked'
+      ) | ForEach-Object {
+        Require-Token $skillText $_ "$($skillContract.Context) responsibility provenance"
+      }
     }
   }
 
   foreach ($verificationTemplateContract in @(
     [pscustomobject]@{ Path = 'templates/migration/regression-report.md'; Context = 'Migration regression verification template' }
   )) {
     $templatePath = Join-Path $root $verificationTemplateContract.Path
     if (-not (Test-Path $templatePath)) { continue }
     $templateText = Get-Content -Raw -Encoding utf8 $templatePath
     Test-MarkdownTableColumns `
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/architecture-review.validation.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/architecture-review.validation.ps1
index f7cd40c..701d0a9 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/architecture-review.validation.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/architecture-review.validation.ps1
@@ -1,10 +1,92 @@
+$script:MigrationResponsibilityRolloutValidator = {
+  param([AllowEmptyString()][string]$MigrateText)
+
+  $diagnostics = [Collections.Generic.List[string]]::new()
+  $invalid = $false
+  $normalized = (($MigrateText -replace "`r`n", "`n") -replace "`r", "`n")
+  $heading = 'Responsibility v1 rollout and safe post-implementation stop'
+  $headingMatches = @([regex]::Matches($normalized, '(?m)^## ' + [regex]::Escape($heading) + '$'))
+  if ($headingMatches.Count -ne 1) {
+    $invalid = $true
+  }
+  else {
+    $tail = $normalized.Substring($headingMatches[0].Index + $headingMatches[0].Length)
+    $nextHeading = [regex]::Match($tail, '(?m)^## ')
+    $section = if ($nextHeading.Success) { $tail.Substring(0, $nextHeading.Index) } else { $tail }
+    $requiredStatements = @(
+      'Resolve exactly one immediate-predecessor `Architecture Responsibility Handoff` with responsibility contract version `1` and immutable `Evidence References` before queue selection, resume, parity, regression, delivery, Knowledge Base completion, or terminal completion.',
+      'Queue selection, resume, and dependency unlock require the predecessor handoff to resolve exactly one immutable authority artifact with approved/complete/human lifecycle, current run/master-spec/master-plan binding, and exact v1 PASS sub-verdicts; absent, pre-v1, mismatched, stale, cross-run, or caller-attested fields derive BLOCKED before production.',
+      'Work Item Terminal Evidence references only the immutable work-item terminal artifact; its exact v1 handoff Evidence References equals the final artifact of the mode-aware ordered chain, and the terminal report Evidence Index uses that same final artifact for each terminal-success item only.',
+      'The terminal chain uses the approved migration-unit mode from its step-8 authority record, never a terminal or chain self-label; the initial review is approved/complete/human, every chain artifact stays in the current run and binds the current master spec/plan/work item, and each source-diff SHA pair exactly equals immutable Task Provenance.',
+      '`architecture_conformance_state` is derived: it is `PASS` only when Tree Conformance, Responsibility Conformance, and Verification Ownership are all `PASS`; otherwise it is `BLOCKED`.',
+      'Runtime `auto-waive` never changes Tree, Responsibility, or Verification Ownership sub-verdicts.',
+      'Do not create a Phase 2 remediation artifact or work item automatically.',
+      'implementation `draft/blocked` -> AI review `Reject` -> work item `blocked` -> dependent item non-eligible -> parity/regression/delivery/KB/terminal completion blocked -> approved design/master-plan revision required'
+    )
+    foreach ($statement in $requiredStatements) {
+      if (-not $section.Contains($statement)) { $invalid = $true }
+    }
+
+    $lines = @($section -split "`n")
+    $tables = [Collections.Generic.List[object]]::new()
+    for ($index = 0; $index -lt $lines.Count; $index++) {
+      if ($lines[$index] -cnotmatch '^\|.*\|$') { continue }
+      $start = $index
+      while ($index -lt $lines.Count -and $lines[$index] -cmatch '^\|.*\|$') { $index++ }
+      $tables.Add(@($lines[$start..($index - 1)]))
+    }
+    if ($tables.Count -ne 1) {
+      $invalid = $true
+    }
+    else {
+      $tableLines = @($tables[0])
+      $splitRow = {
+        param([string]$Line)
+        if ($Line -cne $Line.Trim() -or $Line -cnotmatch '^\|[^|]+(?:\|[^|]+)*\|$') { return @() }
+        return @($Line.Substring(1, $Line.Length - 2).Split('|') | ForEach-Object { $_.Trim() })
+      }
+      $columns = @(
+        'Input / condition', 'Compatibility disposition', 'Derived architecture state',
+        'Queue and selection', 'Downstream boundary', 'Required resume authority'
+      )
+      $expectedRows = @(
+        @('v1 exact handoff; Tree PASS; Responsibility PASS; Verification PASS; immutable evidence resolves', 'executable', 'PASS', 'current approved work item only', 'normal gates', 'current approved design/master-plan'),
+        @('any structural sub-verdict BLOCKED or missing or mismatched immutable evidence link', 'blocked', 'BLOCKED', 'scope-blocked; next eligible item: none; no dependent selection', 'stop before parity, regression, delivery, KB, and terminal completion', 'approved design/master-plan revision required'),
+        @('completed pre-v1 artifact', 'historical-only', 'not executable', 'no selection or resume from artifact', 'no downstream completion authority', 'approved v1 backfill before future executable work'),
+        @('in-progress pre-v1 artifact', 'blocked', 'BLOCKED', 'no resume; no production mutation; no dependent selection', 'stop before parity, regression, delivery, KB, and terminal completion', 'approved design/master-plan revision with v1 backfill required'),
+        @('mixed v1/v2 or cross-run evidence', 'blocked', 'BLOCKED', 'scope-blocked; next eligible item: none; no dependent selection', 'stop before parity, regression, delivery, KB, and terminal completion', 'approved design/master-plan revision required')
+      )
+      if ($tableLines.Count -ne ($expectedRows.Count + 2)) {
+        $invalid = $true
+      }
+      else {
+        $actualColumns = @(& $splitRow $tableLines[0])
+        $delimiter = @(& $splitRow $tableLines[1])
+        if (
+          ($actualColumns -join '|') -cne ($columns -join '|') -or
+          $delimiter.Count -ne $columns.Count -or
+          @($delimiter | Where-Object { $_ -cnotmatch '^:?-{3,}:?$' }).Count -gt 0
+        ) {
+          $invalid = $true
+        }
+        for ($rowIndex = 0; $rowIndex -lt $expectedRows.Count; $rowIndex++) {
+          $actualRow = @(& $splitRow $tableLines[$rowIndex + 2])
+          if (($actualRow -join '|') -cne ($expectedRows[$rowIndex] -join '|')) { $invalid = $true }
+        }
+      }
+    }
+  }
+  if ($invalid) { $diagnostics.Add('migration-responsibility-rollout-invalid') }
+  return $diagnostics.ToArray()
+}
+
 function Test-ArchitectureReview([string]$Root, [string]$ContractText) {
   $contractPath = Join-Path $Root 'contracts/target-structure-conformance.md'
   if (-not (Test-Path -LiteralPath $contractPath -PathType Leaf)) {
     $errors.Add('Missing target structure conformance contract resource')
     return
   }
   @(
     '## Architecture-first review order',
     'Architecture-first review order: master-scope/work-item alignment -> project rule resolution -> canonical selector -> architecture conformance with matrix/exemplars -> production activation path -> behavior, failure modes, security, performance, and tests -> change hygiene.',
     'Architecture Conformance Verdict: PASS | BLOCKED',
diff --git a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/scope-engine.validation.ps1 b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/scope-engine.validation.ps1
index 11f5a44..39363de 100644
--- a/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/scope-engine.validation.ps1
+++ b/AIToolkit/AIToolkit-main/aitoolkit/tests/validation/scope-engine.validation.ps1
@@ -300,20 +300,105 @@ function Test-ScopeEngine([string]$Root, [string]$ContractText) {
       }
       if ($activeAttemptCount -eq 1 -and $inProgressItems.Count -eq 1) {
         if ([string]$activeAttemptRecord.work_item_id -cne [string]$inProgressItems[0].work_item_id) {
           return [pscustomobject]@{ result = 'plan-invalid'; reason = 'active-attempt-item-mismatch'; scope_status = 'scope-blocked' }
         }
         if ([string]$activeAttemptRecord.attempt_id -cne [string]$inProgressItems[0].latest_attempt) {
           return [pscustomobject]@{ result = 'plan-invalid'; reason = 'active-attempt-latest-mismatch'; scope_status = 'scope-blocked' }
         }
       }
 
+      foreach ($item in $items) {
+        if (-not ([bool]$item.required -or [bool]$item.optional_execution_approved)) { continue }
+        $authorityReference = if ($null -ne $item.PSObject.Properties['responsibility_evidence']) { [string]$item.responsibility_evidence } else { '' }
+        $authorityArtifacts = @($scenario.orchestration_context.resolved_artifacts | Where-Object {
+          [string]$_.artifact_reference -ceq $authorityReference
+        })
+        $authority = if ($authorityArtifacts.Count -eq 1) { $authorityArtifacts[0] } else { $null }
+        $authorityHandoff = if ($null -ne $authority -and $null -ne $authority.PSObject.Properties['responsibility_handoff']) { $authority.responsibility_handoff } else { $null }
+        $derivedAuthorityArchitecture = if (
+          $null -ne $authorityHandoff -and
+          [string]$authorityHandoff.tree_conformance -ceq 'PASS' -and
+          [string]$authorityHandoff.responsibility_conformance -ceq 'PASS' -and
+          [string]$authorityHandoff.verification_ownership -ceq 'PASS'
+        ) { 'PASS' } else { 'BLOCKED' }
+        $authorityValid =
+          -not [string]::IsNullOrWhiteSpace($authorityReference) -and
+          $authorityReference -cne 'none' -and
+          $null -ne $authority -and
+          [bool]$authority.immutable -and
+          [string]$authority.artifact_type -ceq 'migration-work-item-responsibility-authority' -and
+          [string]$authority.status -ceq 'approved' -and
+          [string]$authority.result -ceq 'complete' -and
+          [string]$authority.approval_source -ceq 'human' -and
+          [string]$authority.run_id -ceq [string]$context.run_id -and
+          [string]$authority.master_spec_ref -ceq [string]$context.master_spec_ref -and
+          [string]$authority.master_spec_id -ceq [string]$context.master_spec_id -and
+          [int]$authority.master_spec_revision -eq [int]$context.latest_spec_revision -and
+          [string]$authority.master_plan_ref -ceq [string]$context.master_plan_ref -and
+          [string]$authority.master_plan_id -ceq [string]$context.master_plan_id -and
+          [int]$authority.master_plan_revision -eq [int]$context.current_plan_revision -and
+          [string]$authority.work_item_id -ceq [string]$item.work_item_id -and
+          [string]$authority.mode_constraint -ceq [string]$item.mode_constraint -and
+          $null -ne $authorityHandoff -and
+          [int]$authorityHandoff.responsibility_contract_version -eq 1 -and
+          [string]$authorityHandoff.tree_conformance -ceq 'PASS' -and
+          [string]$authorityHandoff.responsibility_conformance -ceq 'PASS' -and
+          [string]$authorityHandoff.verification_ownership -ceq 'PASS' -and
+          [string]$authorityHandoff.architecture_state -ceq $derivedAuthorityArchitecture -and
+          $derivedAuthorityArchitecture -ceq 'PASS' -and
+          [string]$authorityHandoff.evidence_reference -ceq [string]$context.master_plan_ref -and
+          [string]$item.tree_conformance -ceq [string]$authorityHandoff.tree_conformance -and
+          [string]$item.responsibility_conformance -ceq [string]$authorityHandoff.responsibility_conformance -and
+          [string]$item.verification_ownership -ceq [string]$authorityHandoff.verification_ownership -and
+          [string]$item.architecture_state -ceq [string]$authorityHandoff.architecture_state
+        if (-not $authorityValid) {
+          $item.tree_conformance = 'BLOCKED'
+          $item.responsibility_conformance = 'BLOCKED'
+          $item.verification_ownership = 'BLOCKED'
+          $item.architecture_state = 'BLOCKED'
+          $existingDiagnostic = if ($null -ne $item.PSObject.Properties['responsibility_diagnostic']) { [string]$item.responsibility_diagnostic } else { '' }
+          if ([string]::IsNullOrWhiteSpace($existingDiagnostic) -or $existingDiagnostic -ceq 'none') {
+            $item | Add-Member -NotePropertyName responsibility_diagnostic -NotePropertyValue 'structural-assurance-blocked' -Force
+          }
+        }
+      }
+
+      $structuralBlockers = @($items | Where-Object {
+        ([bool]$_.required -or [bool]$_.optional_execution_approved) -and
+        (
+          [string]$_.tree_conformance -cne 'PASS' -or
+          [string]$_.responsibility_conformance -cne 'PASS' -or
+          [string]$_.verification_ownership -cne 'PASS' -or
+          [string]$_.architecture_state -cne 'PASS'
+        )
+      })
+      if ($structuralBlockers.Count -gt 0) {
+        $responsibilityBlocker = @($structuralBlockers | Where-Object {
+          [string]$_.responsibility_conformance -cne 'PASS'
+        } | Select-Object -First 1)
+        $responsibilityDiagnostic = if ($responsibilityBlocker.Count -eq 1) {
+          [string]$responsibilityBlocker[0].responsibility_diagnostic
+        }
+        else { '' }
+        return [pscustomobject]@{
+          result = 'scope-blocked'
+          reason = if (
+            [string]::IsNullOrWhiteSpace($responsibilityDiagnostic) -or
+            $responsibilityDiagnostic -ceq 'none'
+          ) { 'structural-assurance-blocked' } else { $responsibilityDiagnostic }
+          scope_status = 'scope-blocked'
+          work_item_id = ''
+          reconciled_work_item_id = ''
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
@@ -348,23 +433,30 @@ function Test-ScopeEngine([string]$Root, [string]$ContractText) {
           $dependencyId = [string]$dependency
           if ([string]::IsNullOrWhiteSpace($dependencyId) -or $dependencyId -ceq 'none') { continue }
           if ($terminalSuccessStates -cnotcontains [string]$itemById[$dependencyId].status) {
             $dependenciesTerminal = $false
             break
           }
         }
         $approvalCurrent = [int]$item.approval_revision -eq [int]$scenario.current_plan_revision
         $noBlocker = -not [bool]$item.has_blocker
         $adapterValid = [bool]$item.adapter_valid
-        $assurancePass =
-          $item.architecture_state -ceq 'PASS' -and
-          $item.selector_schema_state -ceq 'PASS'
+        $tree = [string]$item.tree_conformance
+        $responsibility = [string]$item.responsibility_conformance
+        $verification = [string]$item.verification_ownership
+        $architectureState = [string]$item.architecture_state
+        $architecturePass =
+          $tree -ceq 'PASS' -and
+          $responsibility -ceq 'PASS' -and
+          $verification -ceq 'PASS' -and
+          $architectureState -ceq 'PASS'
+        $assurancePass = $architecturePass -and $item.selector_schema_state -ceq 'PASS'
         if (
           -not $requiredOrApprovedOptional -or
           -not $selectableState -or
           -not $dependenciesTerminal -or
           -not $approvalCurrent -or
           -not $noBlocker -or
           -not $adapterValid -or
           -not $assurancePass
         ) {
           continue
@@ -400,23 +492,29 @@ function Test-ScopeEngine([string]$Root, [string]$ContractText) {
           adapter_kind = [string]$selectedItem.adapter_kind
           migration_unit_id = if ($selectedItem.adapter_kind -ceq 'migration-unit') { [string]$selectedItem.external_id } else { 'not-applicable' }
           reconciled_work_item_id = $reconciledWorkItemId
         }
       }
 
       $requiredNonTerminal = @($items | Where-Object {
         [bool]$_.required -and $terminalSuccessStates -cnotcontains [string]$_.status
       })
       if ($requiredNonTerminal.Count -gt 0) {
+        $responsibilityBlocked = @($requiredNonTerminal | Where-Object {
+          [string]$_.responsibility_conformance -cne 'PASS'
+        })
         return [pscustomobject]@{
           result = 'scope-blocked'
-          reason = 'required-work-remains-without-eligible-item'
+          reason = if ($responsibilityBlocked.Count -gt 0) {
+            $diagnostic = [string]$responsibilityBlocked[0].responsibility_diagnostic
+            if ([string]::IsNullOrWhiteSpace($diagnostic) -or $diagnostic -ceq 'none') { 'structural-assurance-blocked' } else { $diagnostic }
+          } else { 'required-work-remains-without-eligible-item' }
           scope_status = 'scope-blocked'
           work_item_id = ''
           reconciled_work_item_id = $reconciledWorkItemId
         }
       }
       return [pscustomobject]@{
         result = 'no-eligible-item'
         reason = 'master-plan-must-calculate-scope-completion'
         scope_status = 'scope-in-progress'
         work_item_id = ''
@@ -475,31 +573,20 @@ function Test-ScopeEngine([string]$Root, [string]$ContractText) {
       $remainingBlockers = @($items | Where-Object { $_.status -ceq 'blocked' -or [bool]$_.has_blocker })
       if ($remainingBlockers.Count -gt 0) {
         return [pscustomobject]@{ result = 'scope-not-complete'; reason = 'blocker-remains'; scope_status = 'scope-blocked' }
       }
       $requiredNonTerminal = @($items | Where-Object {
         [bool]$_.required -and $terminalSuccessStates -cnotcontains [string]$_.status
       })
       if ($requiredNonTerminal.Count -gt 0) {
         return [pscustomobject]@{ result = 'scope-not-complete'; reason = 'required-work-remains'; scope_status = 'scope-in-progress' }
       }
-      foreach ($item in $items) {
-        if ($item.status -cne 'complete') { continue }
-        if (
-          [string]::IsNullOrWhiteSpace([string]$item.terminal_evidence) -or
-          [string]$item.terminal_evidence -ceq 'none' -or
-          $item.architecture_state -cne 'PASS' -or
-          $item.selector_schema_state -cne 'PASS'
-        ) {
-          return [pscustomobject]@{ result = 'scope-not-complete'; reason = 'completed-item-evidence-or-assurance-invalid'; scope_status = 'scope-blocked' }
-        }
-      }
       $terminalReportRef = [string]$scenario.terminal_scope_report_ref
       $terminalReports = @($scenario.orchestration_context.resolved_artifacts | Where-Object {
         [string]$_.artifact_reference -ceq $terminalReportRef
       })
       if (
         @('', 'pending', 'none', 'not-applicable') -ccontains $terminalReportRef -or
         $terminalReports.Count -ne 1 -or
         $terminalReports[0].artifact_type -cne 'migration-scope-terminal-report' -or
         -not [bool]$terminalReports[0].immutable -or
         [string]$terminalReports[0].master_plan_ref -cne [string]$scenario.orchestration_context.master_plan_ref -or
@@ -522,20 +609,212 @@ function Test-ScopeEngine([string]$Root, [string]$ContractText) {
         ) {
           $reportIdSetValid = $false
         }
       }
       foreach ($planItemId in $planReportIds) {
         if (-not $reportedIds.Contains($planItemId)) { $reportIdSetValid = $false }
       }
       if (-not $reportIdSetValid) {
         return [pscustomobject]@{ result = 'scope-not-complete'; reason = 'terminal-scope-report-id-set-mismatch'; scope_status = 'scope-blocked' }
       }
+
+      $resolvedTerminalReferences = [Collections.Generic.List[string]]::new()
+      foreach ($item in $items) {
+        if ($terminalSuccessStates -cnotcontains [string]$item.status) { continue }
+        $tree = [string]$item.tree_conformance
+        $responsibility = [string]$item.responsibility_conformance
+        $verification = [string]$item.verification_ownership
+        $architectureState = [string]$item.architecture_state
+        $architecturePass =
+          $tree -ceq 'PASS' -and
+          $responsibility -ceq 'PASS' -and
+          $verification -ceq 'PASS' -and
+          $architectureState -ceq 'PASS'
+        if (
+          [string]::IsNullOrWhiteSpace([string]$item.terminal_evidence) -or
+          [string]$item.terminal_evidence -ceq 'none' -or
+          -not $architecturePass -or
+          $item.selector_schema_state -cne 'PASS'
+        ) {
+          $diagnostic = [string]$item.responsibility_diagnostic
+          $reason = if ($responsibility -cne 'PASS' -and -not [string]::IsNullOrWhiteSpace($diagnostic) -and $diagnostic -cne 'none') { $diagnostic } else { 'structural-assurance-blocked' }
+          return [pscustomobject]@{ result = 'scope-not-complete'; reason = $reason; scope_status = 'scope-blocked' }
+        }
+
+        $terminalArtifacts = @($scenario.orchestration_context.resolved_artifacts | Where-Object {
+          [string]$_.artifact_reference -ceq [string]$item.terminal_evidence
+        })
+        if (
+          $terminalArtifacts.Count -ne 1 -or
+          -not [bool]$terminalArtifacts[0].immutable -or
+          [string]$terminalArtifacts[0].artifact_type -cne 'migration-work-item-terminal' -or
+          [string]$terminalArtifacts[0].work_item_id -cne [string]$item.work_item_id -or
+          [int]$terminalArtifacts[0].plan_revision -ne [int]$scenario.current_plan_revision -or
+          [string]$terminalArtifacts[0].status -cne [string]$item.status -or
+          [string]$terminalArtifacts[0].run_id -cne [string]$scenario.orchestration_context.run_id -or
+          [string]$terminalArtifacts[0].master_spec_ref -cne [string]$scenario.orchestration_context.master_spec_ref -or
+          [string]$terminalArtifacts[0].master_spec_id -cne [string]$scenario.orchestration_context.master_spec_id -or
+          [int]$terminalArtifacts[0].master_spec_revision -ne [int]$scenario.orchestration_context.latest_spec_revision -or
+          [string]$terminalArtifacts[0].master_plan_ref -cne [string]$scenario.orchestration_context.master_plan_ref -or
+          [string]$terminalArtifacts[0].master_plan_id -cne [string]$scenario.orchestration_context.master_plan_id -or
+          [int]$terminalArtifacts[0].master_plan_revision -ne [int]$scenario.current_plan_revision -or
+          [string]$terminalArtifacts[0].mode_constraint -cne [string]$item.mode_constraint
+        ) {
+          return [pscustomobject]@{ result = 'scope-not-complete'; reason = 'structural-assurance-blocked'; scope_status = 'scope-blocked' }
+        }
+
+        $terminalArtifact = $terminalArtifacts[0]
+        $handoff = $terminalArtifact.responsibility_handoff
+        $derivedArchitecture = if (
+          [string]$handoff.tree_conformance -ceq 'PASS' -and
+          [string]$handoff.responsibility_conformance -ceq 'PASS' -and
+          [string]$handoff.verification_ownership -ceq 'PASS'
+        ) { 'PASS' } else { 'BLOCKED' }
+        $modeConstraint = [string]$item.mode_constraint
+        $expectedResponsibilitySteps = if ($modeConstraint -ceq 'incremental/preserve-existing') {
+          @('11-ai-review', '12-verification-testing', '13-verify-parity', '14-verify-regression', '15-knowledge-base')
+        }
+        elseif ($modeConstraint -ceq 'greenfield/design-new') {
+          @('11-ai-review', '12-verification-testing', '13-verify-parity', '15-knowledge-base')
+        }
+        else { @() }
+        $responsibilityChainReferences = @($terminalArtifact.responsibility_chain_references)
+        if (
+          $null -eq $handoff -or
+          [int]$handoff.responsibility_contract_version -ne 1 -or
+          [string]$handoff.tree_conformance -cne 'PASS' -or
+          [string]$handoff.responsibility_conformance -cne 'PASS' -or
+          [string]$handoff.verification_ownership -cne 'PASS' -or
+          [string]$handoff.architecture_state -cne $derivedArchitecture -or
+          $derivedArchitecture -cne 'PASS' -or
+          $expectedResponsibilitySteps.Count -eq 0 -or
+          $responsibilityChainReferences.Count -ne $expectedResponsibilitySteps.Count -or
+          @($responsibilityChainReferences | Group-Object | Where-Object Count -ne 1).Count -gt 0 -or
+          [string]$handoff.evidence_reference -cne [string]$responsibilityChainReferences[-1] -or
+          $tree -cne [string]$handoff.tree_conformance -or
+          $responsibility -cne [string]$handoff.responsibility_conformance -or
+          $verification -cne [string]$handoff.verification_ownership -or
+          $architectureState -cne [string]$handoff.architecture_state
+        ) {
+          $diagnostic = [string]$item.responsibility_diagnostic
+          $reason = if ([string]$handoff.responsibility_conformance -cne 'PASS' -and -not [string]::IsNullOrWhiteSpace($diagnostic) -and $diagnostic -cne 'none') { $diagnostic } else { 'structural-assurance-blocked' }
+          return [pscustomobject]@{ result = 'scope-not-complete'; reason = $reason; scope_status = 'scope-blocked' }
+        }
+
+        $previousResponsibilityReference = ''
+        $canonicalSourceDiff = ''
+        $finalResponsibilityArtifact = $null
+        for ($chainIndex = 0; $chainIndex -lt $responsibilityChainReferences.Count; $chainIndex++) {
+          $chainReference = [string]$responsibilityChainReferences[$chainIndex]
+          $chainArtifacts = @($scenario.orchestration_context.resolved_artifacts | Where-Object {
+            [string]$_.artifact_reference -ceq $chainReference
+          })
+          if ($chainArtifacts.Count -ne 1) {
+            return [pscustomobject]@{ result = 'scope-not-complete'; reason = 'structural-assurance-blocked'; scope_status = 'scope-blocked' }
+          }
+          $chainArtifact = $chainArtifacts[0]
+          $chainArchitecture = if (
+            [string]$chainArtifact.tree_conformance -ceq 'PASS' -and
+            [string]$chainArtifact.responsibility_conformance -ceq 'PASS' -and
+            [string]$chainArtifact.verification_ownership -ceq 'PASS'
+          ) { 'PASS' } else { 'BLOCKED' }
+          if (
+            -not [bool]$chainArtifact.immutable -or
+            [string]$chainArtifact.artifact_type -cne 'migration-responsibility-handoff' -or
+            [string]$chainArtifact.run_id -cne [string]$scenario.orchestration_context.run_id -or
+            [string]$chainArtifact.master_spec_ref -cne [string]$scenario.orchestration_context.master_spec_ref -or
+            [string]$chainArtifact.master_spec_id -cne [string]$scenario.orchestration_context.master_spec_id -or
+            [int]$chainArtifact.master_spec_revision -ne [int]$scenario.orchestration_context.latest_spec_revision -or
+            [string]$chainArtifact.master_plan_ref -cne [string]$scenario.orchestration_context.master_plan_ref -or
+            [string]$chainArtifact.master_plan_id -cne [string]$scenario.orchestration_context.master_plan_id -or
+            [int]$chainArtifact.master_plan_revision -ne [int]$scenario.current_plan_revision -or
+            [string]$chainArtifact.work_item_id -cne [string]$item.work_item_id -or
+            [string]$chainArtifact.mode_constraint -cne $modeConstraint -or
+            [string]$chainArtifact.step_id -cne [string]$expectedResponsibilitySteps[$chainIndex] -or
+            [int]$chainArtifact.responsibility_contract_version -ne 1 -or
+            $chainArchitecture -cne 'PASS' -or
+            [string]$chainArtifact.architecture_state -cne $chainArchitecture -or
+            [string]::IsNullOrWhiteSpace([string]$chainArtifact.evidence_reference) -or
+            [string]$chainArtifact.evidence_reference -ceq 'none' -or
+            [string]$chainArtifact.task_base_sha -cnotmatch '^[0-9a-f]{40}$' -or
+            [string]$chainArtifact.final_tree_sha -cnotmatch '^[0-9a-f]{40}$' -or
+            [string]$chainArtifact.evidence_reference -cne ("source-diff:$([string]$chainArtifact.task_base_sha)..$([string]$chainArtifact.final_tree_sha)#$([string]$item.work_item_id)") -or
+            ($chainIndex -eq 0 -and (
+              [string]$chainArtifact.status -cne 'approved' -or
+              [string]$chainArtifact.result -cne 'complete' -or
+              [string]$chainArtifact.approval_source -cne 'human'
+            )) -or
+            ($chainIndex -gt 0 -and [string]$chainArtifact.source_artifact_reference -cne $previousResponsibilityReference) -or
+            ($chainIndex -gt 0 -and [string]$chainArtifact.evidence_reference -cne $canonicalSourceDiff)
+          ) {
+            return [pscustomobject]@{ result = 'scope-not-complete'; reason = 'structural-assurance-blocked'; scope_status = 'scope-blocked' }
+          }
+          foreach ($field in @('tree_conformance', 'responsibility_conformance', 'verification_ownership', 'architecture_state')) {
+            if ([string]$chainArtifact.$field -cne [string]$handoff.$field) {
+              return [pscustomobject]@{ result = 'scope-not-complete'; reason = 'structural-assurance-blocked'; scope_status = 'scope-blocked' }
+            }
+          }
+          if ($chainIndex -eq 0) { $canonicalSourceDiff = [string]$chainArtifact.evidence_reference }
+          $previousResponsibilityReference = $chainReference
+          $finalResponsibilityArtifact = $chainArtifact
+        }
+        if ($null -eq $finalResponsibilityArtifact) {
+          return [pscustomobject]@{ result = 'scope-not-complete'; reason = 'structural-assurance-blocked'; scope_status = 'scope-blocked' }
+        }
+        $resolvedTerminalReferences.Add([string]$handoff.evidence_reference)
+      }
+      $reportHandoff = $terminalReport.responsibility_handoff
+      $reportArchitecture = if (
+        [string]$reportHandoff.tree_conformance -ceq 'PASS' -and
+        [string]$reportHandoff.responsibility_conformance -ceq 'PASS' -and
+        [string]$reportHandoff.verification_ownership -ceq 'PASS'
+      ) { 'PASS' } else { 'BLOCKED' }
+      $reportedTerminalReferences = @($reportHandoff.evidence_references)
+      if (
+        $null -eq $reportHandoff -or
+        [int]$reportHandoff.responsibility_contract_version -ne 1 -or
+        [string]$reportHandoff.tree_conformance -cne 'PASS' -or
+        [string]$reportHandoff.responsibility_conformance -cne 'PASS' -or
+        [string]$reportHandoff.verification_ownership -cne 'PASS' -or
+        [string]$reportHandoff.architecture_state -cne $reportArchitecture -or
+        $reportArchitecture -cne 'PASS' -or
+        ($reportedTerminalReferences -join '|') -cne ($resolvedTerminalReferences.ToArray() -join '|') -or
+        [string]$terminalReport.run_id -cne [string]$scenario.orchestration_context.run_id -or
+        [string]$terminalReport.master_spec_ref -cne [string]$scenario.orchestration_context.master_spec_ref -or
+        [string]$terminalReport.master_spec_id -cne [string]$scenario.orchestration_context.master_spec_id -or
+        [int]$terminalReport.master_spec_revision -ne [int]$scenario.orchestration_context.latest_spec_revision -or
+        [string]$terminalReport.master_plan_id -cne [string]$scenario.orchestration_context.master_plan_id
+      ) {
+        return [pscustomobject]@{ result = 'scope-not-complete'; reason = 'structural-assurance-blocked'; scope_status = 'scope-blocked' }
+      }
+      if ($null -ne $terminalReport.PSObject.Properties['evidence_index']) {
+        $evidenceIndexRows = @($terminalReport.evidence_index)
+      }
+      else { $evidenceIndexRows = @() }
+      $terminalSuccessIds = @($items | Where-Object { $terminalSuccessStates -ccontains [string]$_.status } | ForEach-Object { [string]$_.work_item_id })
+      $indexedWorkItemIds = @($evidenceIndexRows | ForEach-Object { [string]$_.work_item_id })
+      if (
+        $evidenceIndexRows.Count -ne $terminalSuccessIds.Count -or
+        ($indexedWorkItemIds -join '|') -cne ($terminalSuccessIds -join '|') -or
+        @($evidenceIndexRows | Group-Object evidence_id | Where-Object Count -ne 1).Count -gt 0
+      ) {
+        return [pscustomobject]@{ result = 'scope-not-complete'; reason = 'structural-assurance-blocked'; scope_status = 'scope-blocked' }
+      }
+      for ($evidenceIndex = 0; $evidenceIndex -lt $evidenceIndexRows.Count; $evidenceIndex++) {
+        if (
+          [string]::IsNullOrWhiteSpace([string]$evidenceIndexRows[$evidenceIndex].evidence_id) -or
+          [string]$evidenceIndexRows[$evidenceIndex].artifact_reference -cne [string]$resolvedTerminalReferences[$evidenceIndex] -or
+          [string]$evidenceIndexRows[$evidenceIndex].purpose -cne 'architecture-responsibility-sub-verdicts'
+        ) {
+          return [pscustomobject]@{ result = 'scope-not-complete'; reason = 'structural-assurance-blocked'; scope_status = 'scope-blocked' }
+        }
+      }
       foreach ($item in $items) {
         $matchingRows = @($reportRows | Where-Object { $_.work_item_id -ceq [string]$item.work_item_id })
         if (
           $matchingRows.Count -ne 1 -or
           (
             $terminalSuccessStates -ccontains [string]$item.status -and
             (
               [string]::IsNullOrWhiteSpace([string]$item.terminal_evidence) -or
               [string]$item.terminal_evidence -ceq 'none'
             )

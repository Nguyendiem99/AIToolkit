---
name: ai-review
description: Bước AI Review của AIToolKit (khung dùng chung, mọi workflow, mọi ngôn ngữ) — review diff theo intent + failure mode phổ quát, phân loại Critical/Major/Minor theo blast-radius, đếm Critical để gate. Đọc artifact bước trước do orchestrator truyền, ghi review-report.md.
---

# Shared — AI Review

Orchestrator gọi skill này, truyền: run_dir + `workflow_type` + đường dẫn artifact bước trước. Chạy inline.

**Core principle:** Review **diff** đối chiếu *ý định* và *các kiểu lỗi đã biết*; phân loại theo **mức tác hại (blast radius)**, không theo khẩu vị.

Đây là wrapper AIToolKit trên superpowers:requesting-code-review — **REQUIRED SUB-SKILL**. superpowers lo phần dispatch reviewer sạch context; skill này thêm **rubric mức độ + dimensions + project rules** và chuẩn hoá report.

## Ngôn ngữ artifact

Nhận `artifact_language` do orchestrator truyền khi `workflow_type: migration`. Hiện chỉ hỗ trợ `artifact_language: vi`: đọc `templates/migration/review-report.md` và viết tiêu đề, tóm tắt, blocker, khuyến nghị và nội dung gate bằng tiếng Việt UTF-8; giữ nguyên mọi field machine-readable, enum, ID, path, command, log, trace field và cột bảng contract. Feature/bugfix đọc `templates/review-report.md` và giữ contract hiện có.

## Project rule resolution

1. The caller-provided `workflow_type` is authoritative for this run, including when `docs/aitoolkit/project.yaml` contains a `migration` section. Never read or override workflow type from the persistent profile. Read explicit review values such as `review_focus` verbatim without treating migration configuration as the current workflow.
2. When a profile supplies `project_pack.path`, resolve it relative to the project root and route through its index to `references/architecture-rules.md` and `references/testing-rules.md`; never depend on runtime auto-discovery.
3. For `workflow_type: migration`, a reviewed project pack is mandatory: require the profile, a non-null/current `project_pack.reviewed_at` already accepted by migration step 01, the pack path/index, and applicable `mandatory-review` rules. Any missing/stale input or applicable mandatory rule records the exact gap, `Rule Resolution: BLOCKED`, and migration `result: blocked` before reviewer dispatch.
4. For feature/bugfix without an explicit mandatory rule declaration, degrade gracefully: do not require a migration profile or project pack; set Rule Resolution to RESOLVED with optional/degraded gaps and run the universal review dimensions.
5. A feature/bugfix rule becomes blocking only when a readable profile or pack explicitly declares that applicable rule mandatory. Then resolve and enforce it exactly; a missing explicitly mandatory rule blocks with the existing non-migration schema and `Verdict: Reject`.
6. `references/testing-rules.md`, `review_focus`, and convention supplements remain optional unless explicitly promoted. Missing optional coverage is recorded and never claimed as applied.

## Architecture-first migration review gates

Với `workflow_type: migration`, thực hiện đúng thứ tự gate sau; chỉ đi tiếp khi gate trước có đủ bằng chứng:

1. Master scope and work-item alignment.
2. Project rule resolution.
3. Canonical selector validation.
4. Tree conformance from final inventory and source/diff evidence.
5. Responsibility conformance against planned responsibility evidence.
6. Verification ownership from final inventory and source/diff evidence.
7. Production activation-path validation.
8. Behavior, failure modes, security, performance, and tests.
9. Change hygiene.

Architecture-first review order: master/work-item -> rules -> selector -> tree -> responsibility -> verification ownership -> activation -> behavior/security/performance -> hygiene.

Derive every `M/A/R/C/D` changed Git path from the pinned comparison and reconcile it one-to-one to exactly one implementation `Change Hygiene` row with exact status mapping `A/C = new`, `M/R = existing`, and `D = deleted`. Require a canonical identifier/list in `Edited Region / Symbol`, an exact `none` or path-scoped safe formatter command, and exact `none` or `confirmed:MAJOR-*` unrelated-diff disposition. Reject wildcards, whole-repository regions, and repository-wide formatter operands including `.`, `*`, and `--all`. Reconcile every implementation row one-to-one to independent review Scope/Formatter/Unrelated-Diff/Severity/SHA evidence; each confirmed unrelated diff requires exactly one matching `Major` finding and blocks Change Hygiene. Normalize repository separators to `/` once across design, review, Git, hygiene, verification binding, and source evidence; reject aliases, absolute paths, and traversal. Independently classify production paths by the canonical roots in the file-responsibility contract and parse owner markers only for production-classified or explicitly selected authority paths: markerless executable content remains unowned even beside a valid block, while irrelevant docs are not promoted by incidental markers. Compare pinned base and final content for surviving `M/R` paths so removed responsibility blocks enter deletion reconciliation. Every deleted Git path needs exact task-base source/removal-diff checkpoint evidence even when it has no owner. A removed block in a surviving file uses `File Kind = existing`; a deleted file uses `File Kind = deleted` and does not require a final-tree path. Preserve both sides of a rename, classify it as production when either side is production, resolve base evidence at the old path, and require explicit `<old path>-><new path>` mapping in checkpoint and review diff evidence.

Classify `C` by the destination only: copying a production source into an excluded destination does not transfer production ownership. `R` remains movement and preserves old/new authority.

Read Git name-status and tree paths with NUL delimiters. Canonical paths preserve embedded spaces and Unicode under NFC normalization, but reject controls, contract delimiters, absolute paths, empty/dot/traversal segments, and aliases. Normalize a single trailing source-root separator before comparing it with the resolved Git top level.

Consume responsibility and verification metadata through the contract's language-valid semantic marker encoding. Recognize only an exact whole-line `// arc:<payload>` in documented slash-comment languages or `# arc:<payload>` in documented hash-comment/PowerShell languages, then review the projected `@...`, `route ...`, or `scenario ...` payload. Require an exact same-ID `@ownership-begin` / `@ownership-end` pair for every owner, reject missing/malformed/mismatched/nested/overlapping ranges, and treat all imports, re-exports, directives, module declarations, shared wiring, and symbol bodies outside a range as unowned executable content. Never infer ownership from the first brace-balanced or indented unit. Ordinary comments, disabled prefixes, block-commented sentinels, and sentinel-like string content stay inert; never demand language-invalid bare pseudo-statements from a real producer.

The reviewer independently inspects the final inventory and task-base/final-tree source diff. Implementation self-attestation is not semantic PASS evidence. For every selected Verification Ownership row, resolve `Evidence Path` from the pinned final-tree SHA, locate exactly its named scenario, and bind the scenario's exact verification owner, production responsibility, capability, evidence kind, disposition, and production path/symbol to the independent final production inventory. `production-composition` also binds the exact production route and provider. An unchanged verification file is valid final-tree source evidence without a fabricated diff; missing, foreign, stale, self-attested, or test-only registry/provider evidence is `BLOCKED`. This is framework-neutral source-contract validation and must not infer authority from a language-specific AST. Never discard a base-only deleted responsibility after checking its removal diff: reconcile its owner, path, public symbols, capabilities, effects, architecture/co-location authority, verification owners, routes, and providers to one exact approved design removal decision, one `Change Hygiene` row with `File Kind = deleted`, and one independent Responsibility Review Evidence row using task-base source plus removal-diff references. A missing or partial reconciliation is an unplanned deletion and blocks Tree and Responsibility conformance. Missing master context, canonical selector, conformance matrix, exemplar, actual/planned tree evidence, responsibility review evidence, verification ownership evidence, or applicable production activation evidence records the matching verdict as `BLOCKED`, sets the overall verdict to `Reject`, and stops before reviewer dispatch and before behavior analysis. Rule Resolution remains an independent first severity gate and cannot be weakened by architecture ordering.

Require exactly one Architecture Conformance Verdict, exactly one Canonical Selector Verdict, exactly one Tree Conformance Verdict, exactly one Responsibility Conformance Verdict, exactly one Verification Ownership Verdict, and exactly one Production Activation-path Verdict. Any `BLOCKED` verdict makes the overall verdict `Reject`, independently of severity counts.

## Mandatory architecture findings

Review invented aggregate state; direct widget service/router calls; raw layout replacing the target wrapper; missing unit boundary; wrong localization mechanism; missing lifecycle gate; tests bypassing the production provider; missing production subscription key; planned/actual tree drift; source/diff inventory that exposes an omitted owner, public symbol, effect, route, or provider; an unplanned full deletion of an owned responsibility; and unapproved structural deviation. Classify a missing production subscription key as `Critical`. An unapproved structural deviation is at least `Major` and is `Critical` when activation, routing, or rendering fails.

## Việc cần làm (thứ tự)

1. **Nạp hợp đồng và nguồn rule, chưa đánh giá gate.** Đọc `aitoolkit-schemas`, `shared/change-hygiene.md`; `workflow_type: migration` đọc `templates/migration/review-report.md`, feature/bugfix đọc `templates/review-report.md`; sau đó đọc [severity-rubric.md](severity-rubric.md) và nạp profile/project-pack candidates. Ở bước này chỉ load resource, không evaluate `Rule Resolution` và không dispatch reviewer. Áp dụng scope, existing-file formatting và final-diff requirements của shared contract như universal hard review rule. Nếu có `review_focus` → bơm vào danh sách quan tâm.
2. **Khoanh vùng review.** Artifact **bước ngay trước** (artifact code/fix) = đường dẫn orchestrator truyền vào. Require its recorded task-base SHA and final-tree SHA, validate both against the current task provenance, and review exactly `task-base..final-tree` plus necessary context. Never fall back to `HEAD~1`, because checkpoint commits may hide earlier task changes. Block missing or mismatched provenance before reviewer dispatch.
3. **Chạy architecture-first gates rồi dispatch reviewer.** Với migration, đầu tiên đọc và validate `Master Scope Context` cùng work-item alignment; chỉ sau khi master alignment đã được đánh giá mới evaluate `Rule Resolution` từ resources đã nạp ở bước 1. Tiếp theo validate canonical selector; `Conformance Matrix Reference`, exemplars, final-tree inventory, và `Actual File Tree vs Planned File Tree` cho Tree; planned responsibility và `Responsibility Review Evidence` cho Responsibility; verification ownership; rồi mới `Production Activation Path Evidence`, đúng thứ tự master/work-item -> rules -> selector -> tree -> responsibility -> verification ownership -> activation -> behavior/security/performance -> hygiene. Reviewer tự inspect task-base/final-tree diff và ghi source/diff evidence immutable cho từng owner; không sao chép implementation PASS là semantic PASS. Chỉ khi các gate cấu trúc cho phép mới dùng superpowers:requesting-code-review để giao diff + intent cho reviewer subagent (không đưa lịch sử phiên). Yêu cầu nó soi theo **dimensions** dưới đây + project rules đã resolve. Procedure ordering: load rule resources without evaluating Rule Resolution. Procedure ordering: validate Master Scope Context/work-item alignment before evaluating Rule Resolution.
4. **Phân loại** mọi phát hiện theo rubric Critical/Major/Minor (xem [severity-rubric.md](severity-rubric.md)). Phân vân giữa 2 mức → **chọn mức cao hơn**.
5. **Phán quyết** theo first gate trong rubric: evaluate `Rule Resolution` trước, chỉ khi `RESOLVED` mới xét severity counts. Ghi `<run_dir>/review-report.md` theo template với lifecycle ban đầu `status: draft`; draft artifacts omit approval_source. Ghi `result: complete` chỉ khi review có đủ evidence và `result: blocked` khi bất kỳ gate bắt buộc nào không resolve. Preserve the validated task-base SHA and final-tree SHA for downstream verification/delivery. Sau SOFT gate, orchestrator chỉ được finalize cùng artifact thành `status: approved`, thêm `approval_source: human` khi human phê duyệt một review `result: complete`; draft, blocked, rejected hoặc non-human approval không phải executable downstream authority.

## Dimensions (language-agnostic — soi *vấn đề*, không soi cú pháp một ngôn ngữ)

1. **Đúng ý định** — code làm đúng yêu cầu gốc (artifact bước trước)? Có làm dư/thiếu?
2. **Xử lý lỗi & edge** — null/empty, biên, input xấu, đường thất bại; lỗi bị nuốt?
3. **Bảo mật** — injection, secret hard-code, thiếu authz/validation, dữ liệu nhạy cảm log ra.
4. **Tài nguyên & hiệu năng** — leak (file/handle/subscription), vòng lặp/độ phức tạp xấu, N+1.
5. **Concurrency** — race, shared state không bảo vệ, thiếu dọn dẹp bất đồng bộ.
6. **Tương thích hợp đồng/API** — phá vỡ caller hiện có, đổi behavior public không cố ý.
7. **Độ đủ của test** — hành vi mới có test? bug có regression test? (không tự viết test ở đây — đó là bước verification).
8. **Khả đọc/bảo trì** — tên, ranh giới, trùng lặp; chỉ là Minor trừ khi che giấu lỗi thật.
9. **Project rules** — convention, performance, security, lifecycle/null handling, và mandatory review rules đã resolve.
10. **Change hygiene** — reject unrelated formatting, whole-file churn in existing files, encoding/line-ending churn, and changes outside the approved task/unit. A confirmed violation is at least Major; elevate it to Critical when it hides or causes a correctness, data-loss, security, or contract defect.
11. **Activation Slice (migration only)** — read `aitoolkit/contracts/activation-slice.md` as the sole definition source, preserve the predecessor's stable ID, every seam row, and trace IDs, then compare the diff and tests against the approved slice. Do not reproduce or narrow the canonical schema. A missing seam that prevents activation is `Critical`. Untraced duplicate ownership or missing lifecycle coverage is at least `Major`, and becomes `Critical` when it causes a correctness failure.

## Rubric mức độ (tóm tắt — chi tiết ở severity-rubric.md)

| Mức | Nghĩa | Hành động gate |
|---|---|---|
| **Critical** | Sai đúng / mất dữ liệu / lỗ hổng bảo mật / crash / phá vỡ hợp đồng hiện có / không đảo ngược | **Chặn** — phải sửa trước khi đi tiếp |
| **Major** | Thiếu xử lý lỗi, thiếu test cho hành vi mới, hồi quy hiệu năng, vi phạm project rule cứng | Sửa trước khi merge |
| **Minor** | Style, naming, micro-opt, doc | Ghi nhận, không chặn |

Blocking condition: `Rule Resolution: BLOCKED`, bất kỳ architecture-first verdict nào là `BLOCKED`, hoặc `Critical count > 0`. Mandatory rule-resolution gap là independent blocking condition, ghi riêng và không bịa một Critical finding. **Major KHÔNG tự lọt êm:** ghi vào report với verdict `Approve-with-fixes` và được **mang tới bước tạo code / gerrit** để xử lý trước merge; đừng coi `Approve-with-fixes` là "xong".

Giữ nguyên severity gate dùng chung: Blocking condition: `Rule Resolution: BLOCKED` or `Critical count > 0`. Migration áp dụng thêm ba architecture-first verdict như các gate độc lập phía trên.

Rule Resolution is evaluated before severity counts. Vì vậy `Rule Resolution: BLOCKED` với 0 Critical và 0 Major vẫn có verdict `Reject`; không được suy `Approve` từ counts.

Only exact `Critical count: 0` with exact overall `Verdict: Approve` is executable and may seed verification. `Approve-with-fixes`, `Reject`, invalid or positive Critical count, and every `BLOCKED` architecture verdict remain non-executable even when an Architecture Responsibility Handoff row says `PASS`.

## Migration-only handoff extension

Preserve the immediate predecessor Activation Slice envelope without loss: keep the complete case-sensitive slice ID set, Applicability, all nine canonical seam rows, and every predecessor Source Reference and Trace ID. Source Reference enrichment is append-only, and predecessor Trace IDs remain a subset of successor Trace IDs. Never reconstruct it from cumulative artifacts.

Khi orchestrator gọi step này với `workflow_type: migration`, trước hết copy nguyên vẹn `Master Scope Context` của work item, exact `Delivery Adapter Kind`, và ghi đúng một `Delivery Adapter Mode Constraint` bằng `Canonical Adapter Evidence.Mode Constraint` của implementation predecessor. Chỉ khi `Delivery Adapter Kind` là `migration-unit`, immediate predecessor mới phải chứa đúng một section `Selected Migration Unit`; validate và copy nguyên vẹn `migration_unit_id`, plan reference, approval reference, mode constraint, `Bootstrap Scope`, Foundation Baseline ID, foundation baseline reference, foundation baseline approval reference, baseline reference, và trace IDs sang report mới. Với adapter khác, bỏ section `Selected Migration Unit` và không suy ra unit từ diff.

Migration review là producer gốc của responsibility handoff (`responsibility handoff origin producer`), không copy handoff từ implementation. Dùng `templates/migration/review-report.md` và emit đúng một bounded front matter với exact top-level key order/cardinality `step_id`, `status`, `result`, `approval_source`, `produced_at`, `responsibility_contract`; keys quoted, case-variant, hyphenated, duplicate, extra, hoặc reordered đều invalid. `produced_at` phải là calendar date hợp lệ theo exact `yyyy-MM-dd`, không blank hay malformed. `step_id` phải exact canonical `11-ai-review`; discriminator là `responsibility_contract.version: 1`, `applicability: required`. Draft artifacts omit `approval_source`; approved executable artifacts dùng exact `approved/complete/human`, và review `Reject`, Critical-bearing, hoặc otherwise non-PASS không được seed downstream execution. Copy ordinally exact tám field `Run ID`, master spec reference/ID/revision, master plan reference/ID/revision và `Work Item ID` từ immediate predecessor; không reconstruct từ cumulative artifacts hoặc directory scan.

Emit đúng một `Task Provenance` row. Resolve assurance identity từ approved current adapter authority: với `migration-unit`, `Task / Unit` phải bằng exact `Selected Migration Unit.Migration Unit ID`; với `task | story | package | phase | milestone | none`, nó phải bằng current `Master Scope Context.Work Item ID`. `Task-base SHA` và `Final-tree SHA` phải là hai SHA đã validate và dùng để review exact diff; `Source Artifact` phải resolve đúng immediate predecessor `implementation-report.md`. Missing, placeholder, stale, cross-run, cross-work-item, hoặc mismatch với implementation `Change Hygiene` là `result: blocked`.

Sau khi independent inventory review hoàn tất, emit đúng một `Architecture Responsibility Handoff` row theo canonical `aitoolkit/contracts/file-responsibility-conformance.md`. Preserve ba semantic verdict do review độc lập tạo ra; every handoff Tree, Responsibility, and Verification Ownership cell must equal its visible review verdict exactly, and the handoff Architecture cell must equal the visible Tree/Responsibility/Verification-derived Architecture verdict. Derive `Architecture Conformance State = PASS` chỉ khi Tree, Responsibility và Verification Ownership đều `PASS`, ngược lại `BLOCKED`. `Evidence References` phải là exact `source-diff:<task-base SHA>..<final-tree SHA>#<WORK-*>` bind cùng row `Task Provenance`; không dùng implementation self-attestation, review filename, caller aggregate, hoặc evidence từ run khác.

`verification-testing` là immediate consumer: nó chỉ copy ordinally exact `Task Provenance` và `Architecture Responsibility Handoff` từ review artifact đã `approved/complete/human`. Một review còn `draft`, `blocked`, stale, cross-run, sai immediate predecessor hoặc có handoff không khớp provenance không được khởi tạo terminal chain.

Đồng thời đọc `aitoolkit/contracts/activation-slice.md`, validate section `Activation Slice`, và copy nguyên vẹn cùng stable ID, mọi seam row và trace IDs sang report. Thiếu, duplicate, đổi tên hoặc mất trace làm handoff `result: blocked`; không suy lại slice từ diff.

- Ghi front matter migration là `result: complete | blocked` ngoài lifecycle `status: draft`.
- Thiếu, mơ hồ, hoặc mismatch bất kỳ field nào thì ghi `result: blocked`; không được suy selector/baseline từ diff hoặc artifact cũ.
- Với feature and bugfix, không áp dụng extension, không yêu cầu các field này, và giữ nguyên output contract hiện có.

## Red Flags — DỪNG

- "Thay đổi nhỏ, khỏi review" → mọi diff đều review.
- Bới style Minor mà bỏ sót Critical đúng-sai.
- Duyệt khi còn Critical chưa xử lý.
- Cãi phản hồi kỹ thuật đúng thay vì sửa.
- Tự sửa code trong bước này (sai vai — xem Ranh giới).

## Rationalization table

| Lý do nguỵ biện | Sự thật |
|---|---|
| "Code rõ ràng, chắc đúng" | Rõ với bạn ≠ đúng. Soi theo dimensions |
| "Không có test nhưng hiển nhiên đúng" | Thiếu test cho hành vi mới = Major |
| "Chỉ đổi 1 dòng" | 1 dòng vẫn có thể là Critical |
| "Optional project rule thiếu nên khỏi review" | Vẫn review theo 8 dimensions phổ quát và ghi degraded coverage |
| "Phân vân Major/Critical, cho Major" | Phân vân → chọn mức CAO hơn |

## Hợp đồng đầu ra (`review-report.md`)

1. **Rule Resolution**: `RESOLVED | BLOCKED`, mandatory rule gaps, optional gaps/degraded coverage. Đây là first gate.
2. **Tổng quan**: phạm vi (SHA `BASE..HEAD`), profile/pack path và project rules áp dụng.
3. **Findings** nhóm theo mức; mỗi cái: `file:line` + vấn đề + **fix đề xuất**.
4. **Critical count** và **Major count** (hai số nguyên không âm) — severity gates sau Rule Resolution.
5. **Verdict**: `Approve` (rule resolution resolved, all architecture-first verdicts pass, 0 Critical, 0 Major) | `Approve-with-fixes` (các gate resolved/pass, còn Major) | `Reject` khi rule resolution blocked, Tree, Responsibility, hoặc Verification Ownership `BLOCKED`, bất kỳ architecture-first verdict nào blocked, hoặc còn Critical. Reject when rule resolution is blocked, an architecture-first verdict is blocked, or Critical remains.
   Reject when rule resolution is blocked or Critical remains. Với migration, cũng Reject khi bất kỳ architecture-first verdict nào là `BLOCKED`.
6. **Migration only**: preserve exact `Master Scope Context`, `Delivery Adapter Kind`, and `Delivery Adapter Mode Constraint`; emit canonical bounded front matter, exact `Task Provenance`, và exactly one v1 `Architecture Responsibility Handoff` derived from independent review evidence; preserve bảng `Selected Migration Unit` chỉ cho adapter `migration-unit`; preserve `Activation Slice` và migration `result`. Feature/bugfix bỏ qua các field này.
7. **Change Hygiene**: record task/unit scope, changed-file evidence, formatter commands, unrelated-diff verdict, severity, and derive exact `Change Hygiene Verdict: PASS | BLOCKED`.
8. **Migration blocked only**: when the routed output is `result: blocked` and Activation Slice/handoff validation is otherwise valid, emit exactly one `Domain Blocker` table with non-placeholder `Blocker` and `Evidence Reference`; omit it from non-blocked migration output. Feature/bugfix behavior is unchanged.

For an executable migration review, render every canonical gate exactly once:
Rule Resolution, Canonical Selector, Architecture Conformance, Tree
Conformance, Responsibility Conformance, Verification Ownership, Production
Activation-path, Behavior Analysis State, and Change Hygiene. Derive the
overall verdict from those visible gates plus the exact Critical and Major
counts. Do not emit an approval whose visible gate or count would derive a
different verdict.

## Ranh giới

- CHỈ review + báo cáo; KHÔNG tự sửa code (dev sửa, hoặc quay lại bước tạo code nếu Critical).
- KHÔNG chạy test (đó là bước verification-testing) và KHÔNG upload Gerrit.

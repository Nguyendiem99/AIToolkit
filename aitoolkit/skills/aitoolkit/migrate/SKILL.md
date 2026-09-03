---
name: migrate
description: Use when a language-agnostic migration must progress through evidence-backed steps under an explicit greenfield or incremental project profile.
---

# AIToolKit — Migration Orchestrator

Bạn là orchestrator chạy inline cùng context người dùng. Điều phối đúng step-skill và human gate; không nhúng logic triển khai của từng bước.

**Core principle:** Scope plane chọn đúng một approved work item; execution plane chỉ chuyển tiếp một artifact đã được kiểm tra, đúng mode/policy và đúng selected work item. `migration_unit_id` chỉ là delivery adapter tùy chọn; không đoán input hoặc tự vượt gate.

Đọc skill `aitoolkit-schemas` trước để áp dụng profile, front matter và artifact contract.

## Scope plane: chuẩn bị, queue và resume

Đọc `contracts/migration-scope-orchestration.md` làm canonical authority; không sao chép hoặc tự mở rộng enum, transition hay completion formula. Scope plane không sửa target source. Trước pipeline 15 bước, chạy đúng thứ tự sau:

1. **Resolve requested scope**
2. **Create/resolve master spec**
3. **Create/resolve master plan**
4. **Validate approved revision chain**
5. **Select/resume one work item**
6. **Resolve optional adapter**
7. **Run execution pipeline**
8. **Apply atomic transition**
9. **Continue queue without repeated soft-scope prompt**

### Resolve requested scope

Nhận explicit orchestration context gồm user request và stable conversation/evidence reference. Ghi canonical `requested_scope` trước khi tạo executable work item. Tên folder, menu, package hoặc file chỉ là evidence: do not scan directories to infer requested scope or revision state.

Dùng requested-scope kinds từ canonical contract. `unresolved` asks exactly one scope question and blocks before step 01; không tạo work item, master execution attempt hoặc todo 15 bước. Request `explicit-item` chỉ mở minimum scope và dependency context cần cho item đó, không tự mở rộng thành module/project. Project không dùng migration-unit taxonomy vẫn tạo generic work items.

`unresolved` emits exactly one question block with a stable ID and concrete prompt. Question phải nêu concrete ambiguous scope ID và các boundary choice được contract cho phép; không chỉ ghi counter/flag, không emit câu thứ hai trong cùng resolution attempt.

### Master artifacts và revision gate

Tạo hoặc resolve `<RUN_DIR>/master-spec.md` và `<RUN_DIR>/master-plan.md`. Trước mọi production mutation, require exactly one latest approved linear revision của master spec và exactly one latest approved linear revision của master plan liên kết đúng spec revision; cả hai phải fresh, không missing, forked, cyclic, stale hoặc blocked. Resolve bằng explicit artifact references từ orchestration context; không quét artifact directory để đoán latest revision.

Executable input requires explicit `master_spec_ref` and `master_plan_ref` that resolve exact immutable current artifact type, ID and revision; blank, `pending`, `none` and `not-applicable` references or evidence are invalid. `status: approved` không đủ nếu approval/freshness reference là placeholder; resolved master plan phải bind exact master-spec reference, ID và revision.

Approved revision là immutable: do not edit an approved master artifact in place. Scope, requirement, success criterion, required disposition, work-item set, dependency, order, acceptance, adapter, selector hoặc structural decision thay đổi phải tạo revision kế tiếp đúng `+1`, giữ stable master ID, trỏ `supersedes` tới immediate predecessor, ghi change summary/affected items, giữ valid completed evidence của item không bị ảnh hưởng và đưa approval của item bị ảnh hưởng về `pending`. Chỉ revision mới đã duyệt được phép tiếp tục mutation.

Every work-item structural change must be declared in `affected_work_items`, including added or removed items, and every affected item in the new revision has `approval_reference: pending`. Structural comparison bao gồm title, required disposition, dependencies, Plan Order, acceptance, trace, adapter và toàn bộ selector fields; revision chain giữ nguyên master-spec/master-plan artifact ID.

Revision comparison includes requested boundary, requirements, success criteria, required disposition and structural decisions, and rejects duplicate current or proposed work-item IDs before map construction. Bất kỳ master-level change nào cũng phải khai affected work items và invalidate approval tương ứng.

Every affected_work_items ID resolves in the current/proposed canonical union; unmappable master-level change conservatively affects every canonical item.

### Queue, eligibility và deterministic selection

Validate graph trước selection; missing dependency hoặc cycle làm plan invalid và `scope-blocked`. Version đầu giữ `max_concurrency: 1`; nhiều hơn một item `in-progress` là invalid. Công thức eligibility bắt buộc là: required-or-approved-optional AND pending-or-ready AND dependencies-terminal-success AND current approval AND no blocker AND adapter-valid AND assurance-pass. Không có eligible item nhưng còn required blocker thì kết luận `scope-blocked`.

Executable operations validate requested scope, then current approved master spec, then current approved linked master plan before queue or transition logic. Gate dùng canonical artifact rows, approval/freshness evidence và executable linear-chain validation; không nhận boolean “approved/current” thay artifact evidence.

Với cùng approved plan revision và evidence state, chọn đúng một item theo dependency depth ascending, then `Plan Order` ascending, then ordinal `Work Item ID` ascending. Không chọn theo folder order, discovery order hoặc lần xuất hiện trong hội thoại.

Queue operations consume exactly the work-item rows bound to the current approved master-plan artifact, never a caller subset or forged queue. Exact bound copy/hash phải gồm toàn bộ required/optional rows và metadata; caller không được thêm, bỏ hoặc thay row cho select, transition hay completion.

Trước selection mới, reconcile an `in-progress` attempt before selecting a new work item. Nếu immutable attempt artifact có terminal evidence hợp lệ, áp dụng missing terminal transition atomically rồi mới select; nếu attempt chưa terminal, resume chính attempt đó. Không brainstorm lại approved scope trừ khi user explicit yêu cầu scope change.

The sole active attempt must belong to the sole in-progress item and equal that item's latest_attempt before resume reconciliation.

### Adapter, attempt và atomic transition

Mọi invocation truyền `master_spec_ref`, `master_plan_ref`, `master_plan_revision` và `work_item_id`. Resolve adapter sau khi chọn work item. Với generic work item, adapter `none` keeps `migration_unit_id: not-applicable`; không phát minh external ID. Với adapter `migration-unit`, selector phải resolve đúng một canonical approved row và tiếp tục giữ one-unit-one-change. Adapter draft, duplicate, stale, mismatch hoặc external-only block trước execution.

Ngay trước execution, atomically đổi selected item `ready -> in-progress`, tạo immutable attempt ID và bind current plan revision; không overwrite attempt artifact. Sau execution, áp dụng đúng một transition từ canonical contract, cập nhật latest terminal evidence và giữ toàn bộ attempt history. Chỉ scope plane được sửa master-plan state; execution step-skill chỉ trả immutable attempt evidence/work-item verdict.

Selection starts atomically as `pending -> ready -> in-progress` or `ready -> in-progress`. Validate immutable `attempt_history` globally by unique attempt ID, exact `work_item_id`, exact current `plan_revision`, status and artifact reference. Trước start, chặn ID đã xuất hiện ở bất kỳ item history nào và chặn mọi item khác đang `in-progress`; resume/terminal transition phải bind đúng latest attempt record.

Attempt and terminal artifacts resolve from the explicit artifact registry by exact reference and bind immutable status, attempt ID, work-item ID and plan revision. Single-in-progress validation counts both work-item states and every immutable attempt record; native blocker transition targets exactly `latest_attempt`.

Successful completion cần immutable terminal artifact khớp attempt/work item/plan revision. Blocker, cancellation and non-applicability transitions require exact immutable terminal or approval evidence. Không chuyển state chỉ từ boolean, label hoặc caller assertion.

### Queue continuation và completion

Step 15 completes only the current execution attempt and work item; nó không kết luận module, project hoặc requested scope hoàn tất. Sau atomic work-item transition, tính lại queue trên current approved master-plan revision. Khi còn required item non-terminal, verdict là `scope-in-progress` và tiếp tục deterministic selection mà không hỏi lại soft-scope question.

Only the approved master plan may conclude `scope-complete`, và chỉ sau khi canonical completion formula đạt đủ: mọi required item terminal-success, graph hợp lệ, không blocker, completed-item architecture/selector-schema đều `PASS`, và terminal scope report liệt kê toàn bộ evidence. Attempt completion, work-item completion và requested-scope completion luôn là ba quyết định riêng.

Scope completion calculates the dependency graph and validates every required terminal-report row; it never trusts caller-provided graph-valid or report-complete booleans. Terminal report phải immutable, có exact work-item status, terminal evidence và assurance fields khớp master-plan rows.

Terminal scope report resolves from the artifact registry, binds the current master-plan reference/revision and enumerates the exact approved plan rows. Caller-provided report object hoặc subset không có exact registry binding không được dùng để kết luận scope.

Terminal scope report Work Item IDs have bidirectional exact set and cardinality equality with current approved plan rows; duplicate, missing or extra IDs block.

## Chuẩn bị run

1. Hoàn tất scope resolution và đặt `<slug>` từ resolved requested scope; không hỏi thêm câu scope nếu record đã resolved. Dùng ngày hiện tại theo `YYYY-MM-DD`.
2. Đặt `RUN_DIR = <project>/docs/aitoolkit/<date>-migration-<slug>/` và tạo thư mục khi cần.
3. Tạo/resolve master spec và master plan, validate approved revision chain rồi select/resume đúng một work item theo scope plane.
4. Đặt per-run `workflow_type: migration`. Giá trị orchestrator-provided này là authoritative; không đọc workflow hiện tại từ persistent profile.
5. Đọc `<project>/docs/aitoolkit/project.yaml`, project pack tại path trong profile, source/target và tài liệu được profile trỏ tới. Không tự suy ra giá trị còn thiếu.
6. Resolve automation mode, artifact language và optional delivery adapter trước step 01.
7. Chỉ sau khi selected work item đã atomically `in-progress`, tạo TodoWrite gồm đúng 15 mục execution plane theo Bảng bước. Chỉ một mục `in_progress` tại một thời điểm.

## Ngôn ngữ artifact

Trước step 01, resolve `artifact_language` đúng một lần từ `output.artifact_language` trong profile. Profile cũ thiếu `output` hoặc `output.artifact_language` dùng legacy fallback `vi` và không bị rewrite chỉ để áp dụng fallback. The currently supported value is `vi`; giá trị khác làm `result: blocked` trước step 01.

Pass the resolved `artifact_language` in every migration step invocation. Với `artifact_language: vi`, mọi tiêu đề, tóm tắt, blocker, khuyến nghị và nội dung gate được viết bằng tiếng Việt UTF-8; giữ nguyên mọi field machine-readable, enum, ID, path, command, log, trace field và cột bảng contract.

For migration step 11 use `templates/migration/review-report.md`; for migration step 12 use `templates/migration/verification-report.md`. The shared `templates/review-report.md` and `templates/verification-report.md` remain the feature/bugfix legacy templates and are not migration rendering sources.

Không dịch, di chuyển hoặc sửa tài liệu nguồn. Source documents và nội dung dưới legacy/target roots chỉ được đọc làm evidence; mọi output mới chỉ ghi vào phạm vi migration đã khai báo.

## Automation mode resolution

Before step 01, resolve exactly once the per-run `automation_mode`. CLI takes precedence over profile. A missing `automation` section or missing `automation.mode` uses the legacy default `interactive`; the supported profile enum is `interactive`, `auto`, or `auto-waive`. Do not rewrite the profile while applying the default. Pass the resolved `automation_mode` in every migration step invocation.

| CLI flags | Profile `automation.mode` | Resolution/action |
|---|---|---|
| none | missing | `automation_mode: interactive` |
| none | `interactive` | `automation_mode: interactive` |
| none | `auto` | `automation_mode: auto` |
| none | `auto-waive` | `automation_mode: auto-waive` |
| `--auto` | missing or any supported value | `automation_mode: auto` |
| `--auto-waive` | missing or any supported value | `automation_mode: auto-waive` |
| `--auto --auto-waive` | any | `result: blocked` before step 01 |
| any | outside the supported enum | `result: blocked` before step 01 |

The two blocked resolution cases stop the run without invoking step 01. Report the conflicting flags or invalid profile value and require correction; never guess a mode.

## Automation gate policy

Apply this table only after validating the current artifact contract. Automatic approval changes the artifact front matter in place and then follows the same todo and handoff transition as a human approval.

| Artifact result | Gate | interactive | auto | auto-waive |
|---|---|---|---|---|
| `complete` | soft | ask the user | `status: approved`; `approval_source: auto`; without question | `status: approved`; `approval_source: auto-waive`; without question |
| `blocked` | any | stop before approval | stop before approval | stop before approval |
| any | HARD | stop for explicit confirmation | stop for explicit confirmation | stop for explicit confirmation |

In all modes, blocked artifacts are not auto-approved by the gate policy: keep `status: draft`, present the blockers and stop. HARD gates are never auto-approved: stop and wait for explicit human confirmation in every mode. The only earlier transition from a native blocked artifact is the environment-waiver classifier below. Partial is route-specific: only an approved step-01 input-qualification artifact or the exact resumed step-10 approved/partial/auto-waive tuple may continue; every other partial artifact stops as invalid.

## Waiver-eligible environment blockers

Classify from the step's native blocker plus its verbatim evidence. A label without the cited capability, command-start, or availability error is not enough. These rows are eligible only when the command role and required-command lifecycle satisfy priority 3 in the decision order below; a failed availability check is not itself a failed test, build, or baseline.

| Native blocker | Required evidence | Category | interactive | auto | auto-waive |
|---|---|---|---|---|---|
| dependency/tool executable absent | verbatim executable lookup or start error | `environment-unavailable` | stop with native blocker | stop with native blocker | continue with exact partial waiver |
| device/emulator/service unavailable | verbatim device/emulator/service probe or start error | `environment-unavailable` | stop with native blocker | stop with native blocker | continue with exact partial waiver |
| network dependency unavailable | verbatim network resolution or connection error | `environment-unavailable` | stop with native blocker | stop with native blocker | continue with exact partial waiver |
| command cannot start because environment capability is absent | verbatim command-start error naming the absent capability | `environment-unavailable` | stop with native blocker | stop with native blocker | continue with exact partial waiver |
| pre-mutation baseline cannot be collected solely for one of those reasons | verbatim pre-mutation command/capability error recorded before target edit | `environment-unavailable` | stop with native blocker | stop with native blocker | continue with exact partial waiver |

## Environment blocker decision order

Evaluate lower priority numbers first. Record the evidence command role and required-command lifecycle before classification. A nonzero availability probe is capability evidence, not a correctness/regression result from the required command. Any started required command is waiver-ineligible, whether or not it produces a correctness/regression result.

| Priority | Scenario | Evidence Command Role | Required Command Lifecycle | Classification | interactive | auto | auto-waive |
|---|---|---|---|---|---|---|---|
| 1 | required command starts and returns real failure while environment symptom also exists | `required test/build/baseline command` | `started-and-produced-correctness/regression-result` | `waiver-ineligible` | stop with native blocker | stop with native blocker | stop with native blocker |
| 2 | required command starts but produces no correctness/regression result while environment symptom also exists | `required test/build/baseline command` | `started-without-correctness/regression-result` | `waiver-ineligible` | stop with native blocker | stop with native blocker | stop with native blocker |
| 3 | required command never starts because a failed availability probe establishes an absent dependency | `availability probe` | `not-started` | `environment-unavailable` | stop with native blocker | stop with native blocker | continue with exact partial waiver |
| 4 | command role or lifecycle missing, ambiguous or contradictory | `missing-or-ambiguous` | `unknown-or-contradictory` | `waiver-ineligible` | stop with native blocker | stop with native blocker | stop with native blocker |

## Waiver-ineligible blockers

Apply the decision order before the taxonomy. Priority 1 and every other ineligible condition win over an environment symptom. Do not split, relabel, or selectively waive a blocker that also contains one of these conditions.

| Native blocker | interactive | auto | auto-waive |
|---|---|---|---|
| required test/build/baseline command started and returned failure, with or without a correctness/regression result | stop with native blocker | stop with native blocker | stop with native blocker |
| schema/frontmatter/handoff invalid | stop with native blocker | stop with native blocker | stop with native blocker |
| source/target path invalid or outside scope | stop with native blocker | stop with native blocker | stop with native blocker |
| mode/policy/unit/foundation selector invalid, stale or ambiguous | stop with native blocker | stop with native blocker | stop with native blocker |
| parity/regression detects a new failure | stop with native blocker | stop with native blocker | stop with native blocker |
| destructive target is outside scope | stop with native blocker | stop with native blocker | stop with native blocker |
| HARD gate | stop with native blocker | stop with native blocker | stop with native blocker |

## Environment waiver transition

For `workflow_type: migration`, only the migration orchestrator may classify continuation. First apply the ordered role/lifecycle decision above. Require all of these predicates at once: resolved `automation_mode: auto-waive`, a soft gate, native `result: blocked`, required-command lifecycle `not-started`, one or more eligible causes all classified `environment-unavailable` from the required evidence, and no waiver-ineligible condition. Preserve the native blocker and evidence verbatim, plus the evidence command role and required-command lifecycle, for every eligible cause in the artifact body; never ask the step-skill to approve itself or manufacture a waiver. Classification may create an approved partial artifact only for the incremental step-10 pre-mutation baseline resume described below; every other blocked step remains draft/blocked and stops.

The only allowed continuation artifact is:

```yaml
status: approved
result: partial
approval_source: auto-waive
waiver:
  policy: auto-waive
  category: environment-unavailable
  original_verdict: blocked
  effective_action: continue
  evidence: <verbatim capability/command error reference>
```

| Native check state | Continuation check state | Forbidden state |
|---|---|---|
| `NOT_RUN + BLOCKED` | `NOT_RUN + WAIVED` | `PASS` |

The transition never changes an unexecuted or unavailable check to `PASS`. If any predicate is absent, leave `status: draft` and `result: blocked`, then stop. An environment waiver never advances a non-step-10 artifact as partial. This classifier applies only to the migration orchestrator; feature and bugfix behavior is unchanged.

## Step 10 pre-mutation baseline waiver resume

Do not use ordinary Environment waiver transition downstream continuation for a step 10 artifact that blocked before target edits. The orchestrator records the exact approved waiver and evidence before re-entry. Re-entry receives the same selected unit, plan/approval references, mode constraint, source/target, and resolved automation mode.

| Priority | Candidate | Re-entry decision | Step 10 todo | Downstream |
|---|---|---|---|---|
| 1 | waiver-ineligible blocker, started required command, schema/frontmatter/handoff error, or HARD gate | forbidden | `in_progress` | forbidden |
| 2 | incremental step 10 pre-mutation baseline unavailable; separate availability probe; required command not-started; target unedited; exact waiver approved | re-invoke `migration/code-migration` with approved waiver artifact | `in_progress` | forbidden until resumed implementation receives normal approval |
| 3 | resumed step 10 retains exact waiver and records target source mutation with unit and trace evidence | validate exact approved/partial/auto-waive outcome | `in_progress` until exact valid partial outcome; then `completed` | allowed only after exact valid partial outcome |
| 4 | resumed step 10 has no target source mutation, loses waiver/evidence, or returns any blocker | stop with native blocker | `in_progress` | forbidden |

The approved waiver authorizes skipping only unavailable pre-mutation baseline collection; it does not excuse implementation. Re-entry remains step 10 and must produce target mutation evidence while retaining the canonical waiver. Therefore its only valid successful state is exactly `status: approved`, `result: partial`, and `approval_source: auto-waive`; `result: complete` is invalid. Until that exact valid partial artifact exists, keep step 10 `in_progress`, retain step 10 as the latest executed artifact, and do not invoke step 11.

For resumed step 10, this exact approved/partial/auto-waive tuple overrides generic steps 1 and 6.

## Mode and migration unit gate

Sau khi step 01 được duyệt, kiểm tra lại gate này trước các step phụ thuộc mode (07, 09, 10 và 14). Trước mọi nhánh, validate `work_item_id`, `master_spec_ref`, `master_plan_ref`, current approved `master_plan_revision`, acceptance/trace và assurance của selected work item.

Với adapter `none` hoặc generic adapter không phải `migration-unit`, không chạy migration-unit selector gate và không sinh `UNIT-*`; truyền `migration_unit_id: not-applicable`, giữ selected work-item acceptance làm execution boundary và thực thi one-work-item-one-change. Mode/foundation/baseline rules vẫn áp dụng theo selected work item. Với adapter `migration-unit`, giữ toàn bộ gate dưới đây và one-unit-one-change:

- `mode: unknown`, policy `unknown`, hoặc cặp mode/policy sai invariant → dừng, trình phần thiếu và hỏi người dùng; không đoán hoặc tự sửa profile.
- Cặp hợp lệ `greenfield` / `design-new` branches on the selected unit, not mode alone. For selected `Bootstrap Scope = required`, require `Foundation Baseline ID = pending-bootstrap` and allow this route only when no approved foundation baseline exists; this first-foundation route does not require an approved foundation baseline before step 09. Run step 09, approve its bootstrap artifact with exactly one approved `FOUNDATION-*` record whose `Source Migration Unit ID` matches the selected unit, then pass that record to step 10.
- For selected greenfield `Bootstrap Scope = not-required`, skip step 09 and pass the approved migration plan plus `foundation_baseline_id` to step 10. Resolve exactly one approved foundation baseline record from the approved target baseline/project pack with a current target baseline reference, foundation baseline approval reference, matching design revision, and freshness evidence; missing ID/approval reference or stale/unapproved/mismatched evidence yields `result: blocked`.
- Base route `migration/verify-regression` chỉ hỗ trợ incremental. Greenfield always skips step 14; no base or project-specific regression route executes. The orchestrator does not invoke migration/verify-regression for greenfield. Sau parity, greenfield giữ `13-parity-report.md` làm latest executed artifact và chuyển thẳng tới Knowledge Capture.
- Cặp hợp lệ `incremental` / `preserve-existing` → skip step 09. Step 10 invocation tự resolve command và ghi comparable `pre-change regression baseline` trước mọi target edit; absence before step 10 invocation is not itself a blocker, nhưng không tạo được comparable baseline thì phải block trước edit. Step 14 là bắt buộc: an approved waiver can cover only a continuing baseline failure and cannot waive or skip step 14.
- Selector validation: `migration_unit_id` must resolve to exactly one approved migration unit with matching mode constraint, approval reference, and `Bootstrap Scope`; missing or ambiguous selection yields `result: blocked`. Greenfield `not-required` additionally requires the explicit `foundation_baseline_id` resolution above. Draft, mismatched, or multiply matched records also block; never select implicitly.

## Bảng bước (migration)

| # | skill | artifact | approver | gate | condition/prompt |
|---|---|---|---|---|---|
| 01 | migration/validate-inputs | `01-input-report.md` | PM/Tech Lead | soft | Duyệt input, profile và project pack? |
| 02 | migration/discovery | `02-discovery.md` | PM/Tech Lead | soft | Duyệt discovery scope và evidence? |
| 03 | migration/analyze-requirements-uiux | `03-requirements-uiux.md` | Product/UX | soft | Duyệt requirements/UIUX? |
| 04 | migration/build-inventory | `04-inventory.md` | Product/Tech Lead | soft | Duyệt migration inventory? |
| 05 | migration/feature-mapping | `05-mapping.md` | Product/Tech Lead | soft | Duyệt mapping source-to-target? |
| 06 | migration/analyze-gaps-conflicts | `06-gaps-conflicts.md` | Decision owner | soft | Duyệt gap/conflict decisions? |
| 07 | migration/technical-design | `07-technical-design.md` | Tech Lead | soft | Duyệt design/conformance theo mode? |
| 08 | migration/plan-waves | `08-migration-plan.md` | Tech Lead/Developer | soft | Duyệt ordered migration units? |
| 09 | migration/bootstrap-target | `09-bootstrap-report.md` | Developer | soft | Chỉ greenfield selected unit có Bootstrap Scope required; duyệt bootstrap/foundation record? |
| 10 | migration/code-migration | `10-implementation-report.md` | Developer | soft | Duyệt implementation của selected unit? |
| 11 | shared/ai-review | `review-report.md` | Reviewer | soft | Duyệt AI review? |
| 12 | shared/verification-testing | `verification-report.md` | Dev/QA | soft | Duyệt verification evidence? |
| 13 | migration/verify-parity | `13-parity-report.md` | Product/UX/QA | soft | Duyệt parity verdict? |
| 14 | migration/verify-regression | `14-regression-report.md` | QA | soft | Incremental only; mandatory; duyệt regression verdict? |
| 15 | shared/knowledge-base | `kb-entry.md` | — | none | always; terminal |

## Migration handoff envelope

Mọi artifact step 01–15 phải có `Master Scope Context` và forward ordinal-exact `master_spec_ref`, `master_plan_ref`, `master_plan_revision`, `work_item_id`, attempt ID/current attempt reference và delivery-adapter kind từ immediate predecessor. Thiếu hoặc mismatch field làm artifact `result: blocked`; step-skill không quét cumulative artifact directory để bù dữ liệu.

Với generic adapter, `Master Scope Context` là execution identity đầy đủ và mọi migration-unit/foundation selector field là `not-applicable` theo canonical contract. Với adapter `migration-unit`, full selected-unit envelope begins after step 08 approval and selector choice: step 09 creates it for greenfield, while step 10 creates it directly from the approved plan for incremental. Step 08 remains an ordered collection of candidate units and is not forced to claim one selected unit.

Mỗi selected-unit artifact sau điểm đó phải có một section `Selected Migration Unit` chuyển tiếp nguyên vẹn:

- `migration_unit_id`, plan reference, approval reference, mode constraint, `Bootstrap Scope` và full trace IDs;
- Foundation Baseline ID, foundation baseline reference, và foundation baseline approval reference: a required plan row starts with `pending-bootstrap`, then step 09 replaces it with an approved `FOUNDATION-*` record; a later greenfield unit resolves the exact ID from the approved target baseline/project pack; incremental records `not-applicable`;
- pre-change regression baseline reference: `not-applicable` cho greenfield, `pending-before-edit` khi incremental chưa vào step 10, rồi đổi thành reference tới evidence đã capture trước edit;
- với migration run, artifact từ shared skill dùng front matter `result: complete | blocked`; `partial` chỉ thuộc approved step-01 input qualification hoặc exact resumed step-10 waiver tuple theo `aitoolkit-schemas`.

Steps 11-13 phải copy `Master Scope Context` và adapter-specific envelope từ predecessor sang output. Với migration-unit adapter, không làm mất selected-unit identity, foundation baseline hoặc regression baseline reference. Incremental step 14 also preserves the parity verdict and adds the regression verdict; greenfield không thực thi step 14. Gate của từng step kiểm tra section này; thiếu field bắt buộc thì artifact giữ draft, ghi `result: blocked` và dừng.

## Handoff giữa các bước

Với mọi step được gọi, truyền `RUN_DIR`, profile, project pack, source/target, per-run `automation_mode`, resolved `artifact_language`, `master_spec_ref`, `master_plan_ref`, `master_plan_revision`, `work_item_id`, attempt reference, resolved delivery adapter và path của artifact vừa được thực thi gần nhất.

`Immediate predecessor artifact = exactly one orchestrator-provided path`.

- Step 01 không có predecessor. Mỗi step bình thường nhận đúng `latest executed artifact`; step bị skip không tạo predecessor mới.
- Generic work item dùng `Master Scope Context` làm selector xuyên suốt; adapter `none` truyền mọi migration-unit selector field là `not-applicable` và không bị block chỉ vì project không có unit taxonomy.
- Step 09 nhận migration plan đã duyệt và orchestrator-provided `migration_unit_id` chỉ khi selected greenfield unit có `Bootstrap Scope = required`, `Foundation Baseline ID = pending-bootstrap`, và `Foundation Approval Reference = pending-step09-approval`.
- Step 10 greenfield foundation nhận bootstrap record đã duyệt cùng chính `migration_unit_id`; approved `FOUNDATION-*` record's `Source Migration Unit ID` matches that selected unit, while plan reference và approval reference phải trỏ cùng selected unit.
- Step 10 later-greenfield `not-required` nhận trực tiếp migration plan đã duyệt cùng `migration_unit_id` và `foundation_baseline_id`; không gọi bootstrap.
- Step 10 incremental nhận trực tiếp migration plan đã duyệt cùng `migration_unit_id`, yêu cầu `Bootstrap Scope = not-required` và baseline trước edit; không gọi bootstrap.
- Khi gọi shared step 11 và 12 với `workflow_type: migration`, truyền predecessor duy nhất và yêu cầu `Migration-only handoff extension`; feature/bugfix invocation không nhận extension này.
- Các step 11–13, và incremental step 14, phải forward Migration handoff envelope qua artifact của mình. Nếu predecessor không đủ evidence bắt buộc thì step hiện tại trả `result: blocked`; orchestrator không nạp thêm danh sách artifact cũ để lấp chỗ trống.
- Step 15 Knowledge Capture nhận authoritative `workflow_type: migration`, `knowledge_step_id: 15-knowledge-base`, và exact immediate terminal artifact do orchestrator cung cấp theo policy:
  - greenfield → `13-parity-report.md` → knowledge-base
  - incremental → `14-regression-report.md` → knowledge-base
- When the run created a foundation baseline, step 15 preserves its `foundation_baseline_id` from the implementation and terminal artifacts in a project-pack update proposal; it does not edit the canonical pack.
- Sau một conditional/optional skip, step được gọi tiếp theo nhận đúng artifact của step thực thi gần nhất.

## Step execution protocol

Với từng hàng theo thứ tự:

For approved continuation, validate approved artifact before you continue from approved artifact.

Run the Environment waiver transition before applying the blocked-stop rule. When an artifact has `result: blocked`, stop before approval gate and downstream execution. Keep `status: draft` and the current todo in progress.

Every conditional or optional skip preserves latest executed artifact for the next invoked step.

Step 10 exception: when its first artifact is blocked before edits by an eligible incremental baseline availability failure, step 5 records the exact approved waiver but does not mark the todo complete and does not advance. It immediately re-invokes `migration/code-migration` with that approved waiver artifact and the same `migration_unit_id`, plan/approval references, mode constraint, source/target, and resolved `automation_mode`. Only a resumed artifact with target mutation evidence and exactly `status: approved`, `result: partial`, and `approval_source: auto-waive` may complete step 10 and permit step 11; this overrides the generic approved-complete handling and the separate step-01 partial-input route in steps 1 and 6. A resumed blocker, `result: complete`, missing or mismatched waiver, missing target source mutation evidence, started required command, ineligible blocker, or HARD gate keeps the todo `in_progress` and stops.

1. Kiểm tra mode/condition và artifact hiện có của chính hàng đó. Artifact có `status: approved` và `result: complete` được xác thực rồi dùng để đánh dấu todo `completed` và tiếp tục. Approved `partial` chỉ được tiếp tục cho step-01 input qualification hoặc exact resumed step-10 tuple; mọi partial khác dừng vì sai contract. Artifact draft chưa blocked được trình lại đúng gate; chỉ gọi lại step-skill khi chưa có output hoặc người dùng yêu cầu sửa.
2. Với step 09, áp dụng selected-unit Bootstrap Scope; step 14 chỉ chạy cho incremental. Greenfield skip step 14 vô điều kiện và mọi skip đều giữ nguyên `latest executed artifact`.
3. Đặt todo `in_progress`, gọi route trong bảng, truyền đúng handoff ở trên và feedback nếu đây là vòng sửa. Skill ghi đúng artifact của hàng với `status: draft`.
4. Đọc front matter trước khi hỏi approval. Nếu thiếu artifact, lỗi thực thi khiến không tạo được artifact hợp contract, hoặc contract sai thì dừng và báo evidence hiện có. A native command/capability error recorded in a contract-valid blocked artifact proceeds to the classifier in step 5.
5. Nếu artifact có `result: blocked`, giữ nguyên native blocker/evidence rồi áp dụng đúng Environment waiver transition. Chỉ eligible incremental step-10 pre-mutation baseline blocker mới được đổi atomically sang exact approved partial waiver và check state `NOT_RUN + WAIVED`; giữ todo step 10 `in_progress`, không chạy downstream, và re-invoke chính step 10 theo resume protocol. Mọi trường hợp còn lại: trình blockers, Unknowns và path; giữ `status: draft`, giữ todo hiện tại `in_progress`, rồi dừng. Không mở approval gate và không chạy step sau.
6. Nếu không blocked, trình tóm tắt và path rồi áp dụng Automation gate policy:
   - `none` → todo `completed`.
   - `soft` + `interactive` → hỏi **Duyệt** hoặc **Từ chối + feedback**. Duyệt thì đổi artifact thành `status: approved`, ghi `approval_source: human`, todo `completed`; từ chối thì gọi lại đúng step với feedback, không sửa step đã duyệt khác.
   - `soft` + `auto` hoặc `auto-waive` → với `result: complete`, hoặc step-01 input qualification có route-authorized `result: partial`, không hỏi người dùng; đổi artifact thành `status: approved`, ghi `approval_source` đúng bằng mode đã resolve, rồi đánh dấu todo `completed`. Exact resumed step-10 partial dùng exception ở trên, không đi qua generic gate này.
     - Riêng step 09 gate approval thay `pending-step09-approval` trong cả `Selected Migration Unit` và `Bản ghi baseline nền tảng` bằng tham chiếu bootstrap artifact đã duyệt chính xác trong cùng một thao tác, đổi `Approval Status = pending-approval` thành `Approval Status = approved`, rồi đổi frontmatter thành `status: approved`. Step 10 không bao giờ dùng bản nháp pending.
   - `HARD` → cảnh báo hành động không thể đảo ngược và yêu cầu xác nhận tường minh đúng prompt. Không chấp nhận “ok” mơ hồ và không tự vượt gate.
7. Sau step 15, ghi immutable terminal attempt artifact rồi yêu cầu scope plane áp dụng atomic work-item transition. Chỉ báo execution attempt/work item hiện tại hoàn tất và liệt kê artifact trong `RUN_DIR`; không báo requested scope hoàn tất tại execution plane. Nếu master-plan completion calculation chưa đạt, giữ `scope-in-progress` hoặc `scope-blocked` rồi select/resume queue theo current approved revision. Chỉ terminal scope report của approved master plan mới được báo requested scope hoàn tất.

## Nguyên tắc

- Chỉ điều phối, condition, handoff và gate. Logic chuyên môn nằm trong step-skill.
- Artifact execution draft có thể được step-skill sửa theo feedback; approved master artifact không bao giờ sửa tại chỗ. Scope change luôn tạo revision mới và qua gate lại.
- Không dùng kho điều phối tập trung hoặc cơ chế tự động tiếp tục ẩn; tiến độ được chứng minh bằng artifact front matter trong `RUN_DIR`.
- Soft gate tuân theo per-run `automation_mode`; HARD gate không bao giờ được tự vượt.

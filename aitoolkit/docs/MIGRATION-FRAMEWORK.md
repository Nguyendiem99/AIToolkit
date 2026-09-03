# Language-agnostic migration framework

AIToolkit keeps migration orchestration native to prompt skills: an orchestrator skill owns step order and human gates, step skills exchange Markdown artifacts, and approved artifacts in `RUN_DIR` provide continuation evidence. The framework does not add a workflow manifest, state engine, private run store, or automatic gate bypass.

## Migration user workflow

1. Prepare migration sources and documents.
2. Run `/aitoolkit:migration-onboarding` with `--legacy`, `--target`, the repeatable `--requirements`, `--uiux`, `--migration-docs`, and `--architecture-docs` flags, or let it read the optional inbox.
3. Review the generated profile at `<RUN_DIR>/project-draft/project.yaml`, generated pack at `<RUN_DIR>/project-draft/migration-project`, and review artifact at `<RUN_DIR>/04-project-pack-review.md`.
4. Obtain explicit Tech Lead approval; the HARD gate publishes those exact staged bytes to canonical `docs/aitoolkit/project.yaml` and `docs/aitoolkit/migration-project`.
5. Run `/aitoolkit:migrate <feature-slug>`.
6. Migration ends at Knowledge Capture after the mode-specific verification path.
7. Gerrit, CCC, and Release are separate delivery skills invoked only by explicit calls after migration.

## Two-plane scope orchestration

Scope plane là authority bền vững phía trên pipeline 15 bước. Nó resolve requested scope, tạo hoặc đọc approved `master-spec.md` và `master-plan.md`, kiểm revision chain, dependency graph, queue, scope change và terminal report. Scope plane không mutation target source. Execution plane chỉ nhận một approved work item tại một thời điểm, resolve optional delivery adapter, tạo immutable attempt và trả work-item evidence cho atomic master-plan transition.

Luồng chuẩn:

```text
requested scope
  -> approved master spec revision
  -> approved master plan revision
  -> deterministic next-eligible work item
  -> optional delivery adapter
  -> one immutable execution attempt
  -> terminal evidence and atomic transition
  -> next work item or calculated scope verdict
```

Master spec giữ intended outcome, scope boundary, requirements, measurable success criteria, unknowns và approval. Master plan giữ generic work items, dependencies, order, acceptance/trace, adapter, attempt history, transition log và scope calculation. Approved revisions bất biến; thay boundary, requirement, work-item set, dependency, acceptance, selector hoặc structural decision phải tạo revision kế tiếp, chỉ invalidate affected approval và giữ evidence hợp lệ của item không bị ảnh hưởng.

### Generic work item và adapter examples

Ví dụ có canonical migration unit:

```yaml
work_item_id: WORK-ADMIN-LOCKS
delivery_adapter:
  kind: migration-unit
  external_id: UNIT-ADM-002
  authority: 08-migration-plan.md
  authority_revision: 3
  approval_reference: approval:UNIT-ADM-002
  parent_selector: not-applicable
```

Selector phải match đúng một approved canonical row về mode, acceptance, trace, dependency và design revision. External-only, duplicate, draft hoặc stale selector đều block.

Ví dụ project không dùng unit:

```yaml
work_item_id: WORK-BILLING-EXPORT
delivery_adapter:
  kind: none
  external_id: not-applicable
  authority: not-applicable
  authority_revision: not-applicable
  approval_reference: not-applicable
  parent_selector: not-applicable
```

Work item vẫn có acceptance, trace, dependency, approval và terminal evidence đầy đủ; orchestrator không phát minh `UNIT-*`.

### Resume, assurance và completion

Resume dùng explicit master references, chọn latest approved linear revisions, reconcile item/attempt `in-progress`, rồi chọn cùng next item theo dependency depth, `Plan Order`, ordinal `Work Item ID`. Missing/forked/cyclic/stale chain block; workflow không brainstorm lại approved scope nếu người dùng không yêu cầu scope change.

Ba assurance state độc lập. `auto-waive` chỉ có thể chuyển eligible runtime evidence từ `NOT_RUN + BLOCKED` thành `NOT_RUN + WAIVED`; runtime `FAIL`, architecture `BLOCKED` hoặc selector/schema `BLOCKED` không được waiver. Structural blocker dừng queue trước edit.

Attempt completion, work-item completion và requested-scope completion là ba quyết định riêng. Một item complete khi acceptance riêng có immutable terminal evidence. Khi còn required item, scope là `scope-in-progress`. Chỉ master plan được kết luận `scope-complete`, sau khi mọi required item terminal-success, graph valid, không blocker, completed-item architecture/selector-schema `PASS`, và `scope-terminal-report.md` enumerate exact toàn bộ required/optional rows cùng evidence và calculated verdict.

Historical unit-only run vẫn đọc được nhưng không resume thẳng tới mutation. Compatibility conversion tạo master spec/plan revision 1 từ approved evidence, một work item cho mỗi canonical legacy unit, giữ exact selector và terminal evidence hợp lệ, rồi dừng ở fresh approval gate; nó không suy module/project completion từ một unit.

## Tự động hóa và ngôn ngữ artifact

- Profile mới mặc định `automation.mode: interactive` và `output.artifact_language: vi`; profile cũ thiếu hai field dùng fallback tương ứng `interactive` và `vi`. Vì vậy artifact migration được sinh mặc định tiếng Việt UTF-8, còn key/enums/ID/path/command/log và cột bảng machine-readable giữ nguyên.
- Thứ tự phân giải mode là CLI flag → `automation.mode` trong profile → `interactive`. `--auto` tự duyệt soft gate không bị blocked, không hỏi và không waiver; gặp blocker hoặc HARD gate thì dừng.
- `--auto-waive` cũng không hỏi ở soft gate và chỉ waiver blocker `environment-unavailable` có bằng chứng thật. Lỗi correctness, schema, path, selector, regression, scope và HARD gate luôn dừng.
- Evidence giữ nghĩa thật: `PASS`, `FAIL`, `BLOCKED`, `WAIVED`, `NOT_RUN`. Check được waiver phải là `NOT_RUN + WAIVED`, có `result: partial` và không phải `PASS`; không ghi giả test đã chạy.
- Tài liệu nguồn luôn read-only: workflow không dịch, di chuyển hoặc rewrite source document.


Onboarding records only evidence it can inspect. Unknown paths, commands, architecture decisions, or behavior remain `unknown` or `null`; a dependent step returns `result: blocked` instead of guessing. Onboarding stages profile and pack changes for a Tech Lead HARD review gate and does not edit production source.

## Profile and project pack

The project-owned profile is `docs/aitoolkit/project.yaml`. It selects `greenfield` or `incremental`, the corresponding architecture policy, source and target paths, command evidence, verification policies, and the project pack path. Migration also requires a non-null RFC 3339 `project_pack.reviewed_at` and an approved `project_pack.review_evidence`; a missing or stale revision comparison blocks step 01.

The default project pack is `docs/aitoolkit/migration-project`. Its short `SKILL.md` routes the migration steps to evidence-backed project references for the legacy system, target baseline, architecture, mapping, UI/UX, testing, and definition of done. Project-specific technology knowledge belongs there, not in migration core.

Commands resolve in this order: explicit profile, existing project scripts/config, marker detection, then a human gate. A missing required command is a blocker; it is never reported as executed.

## Greenfield walkthrough

Use `examples/migration/greenfield/docs/aitoolkit/project.yaml`. Its invariant is `greenfield` with `design-new`.

1. Onboarding inspects the legacy inputs and confirms that the target has no stable architectural baseline.
2. Discovery, requirements, inventory, mapping, and gap analysis produce evidence-backed approved artifacts.
3. Technical design proposes the target foundation and stops at the **Tech Lead design gate**.
4. Only after that approval may a selected foundation unit with `Bootstrap Scope = required` enter **bootstrap** and create an approved foundation baseline record.
5. A later unit with `Bootstrap Scope = not-required` skips bootstrap, resolves exactly one approved foundation-baseline selector from the plan, and enters **implementation** from that plan. A required unit instead uses its approved bootstrap artifact. Parity evidence follows, greenfield skips step 14 unconditionally, and `13-parity-report.md` goes directly to Knowledge Capture.

The greenfield fixture is illustrative: its commands remain `null`, so a real run must resolve them from the target project or stop for human input.

## Incremental walkthrough

Use `examples/migration/incremental/docs/aitoolkit/project.yaml`. Its invariant is `incremental` with `preserve-existing`.

1. Discovery treats existing target source and approved decisions as the architectural authority.
2. Mapping uses reuse, extend, create, replace, or omit; technical design demonstrates **target conformance** rather than introducing a competing pattern.
3. Before any target edit, the selected unit captures a comparable pre-change regression **baseline**. If the baseline cannot be established, editing is blocked.
4. The orchestrator follows **no bootstrap** behavior and invokes implementation directly from the approved plan and selected unit.
5. Review, verification, and parity preserve the selected-unit handoff; **regression verification** is mandatory and compares against the baseline.

Replacement, platform-dependency change, or out-of-scope refactoring requires an explicit approved decision. An unresolved conflict remains blocked.

## Migration completion and gates

Every migration artifact has independent workflow approval (`status: draft | approved`) and a business-outcome enum (`result: complete | partial | blocked`). The enum is route-limited: the canonical Activation Slice contract permits `partial` only for the approved step-01 input-qualification predecessor and the exact step-10 `approved/partial/auto-waive` baseline-waiver tuple; steps 02–09 and 11–14 use `complete | blocked`. A blocked artifact remains draft, keeps the current todo in progress, and stops before the normal approval gate and downstream execution.

The migration orchestrator has exactly 15 steps. Greenfield passes `13-parity-report.md` to terminal Knowledge Capture; incremental passes `14-regression-report.md`. Knowledge Capture reads the complete `RUN_DIR`, writes `kb-entry.md`, and is the last execution-plane step. To continue an interrupted run, invoke the same workflow and slug; the scope plane validates explicit approved master revisions and immutable attempt evidence directly without a manifest, database-backed state engine, or private run store.

Delivery does not run implicitly. Gerrit, CCC, and Release remain available as separate skills only when the user makes a new explicit call after migration has ended.

## Static verification evidence

| Date | Check | Status | Evidence or blocker |
|---|---|---|---|
| 2026-08-11 | `validate-migration-framework.ps1 -Check Docs` | PASS | `PASS: migration framework (Docs)` |
| 2026-08-11 | `validate-migration-framework.ps1 -Check All` | PASS | `PASS: migration framework (All)` |
| 2026-08-11 | `validate-migration-framework.Tests.ps1` | PASS | `PASS: focused migration framework tests` |
| 2026-08-11 | `git diff --check` | PASS | Exit code 0; output contained only line-ending conversion notices. |
| 2026-08-11 | `claude plugin validate .\aitoolkit` | BLOCKED | The `claude` CLI is unavailable in this verification environment; plugin validation was not run. |

## Manual runtime evidence

The scenarios below were run in disposable target projects with Codex CLI 0.146.0. Reaching an expected human gate with a readable artifact is PASS for the onboarding walkthrough; a pre-gate contract stop remains BLOCKED and is not promoted from static evidence.

| Date | Runtime | Scenario | Status | Observed gate / artifact | Evidence or blocker |
|---|---|---|---|---|---|
| 2026-08-11 | Codex CLI 0.146.0 | onboarding | PASS | Paused at the expected Step 02 PM/Tech Lead soft approval gate; produced readable docs/aitoolkit/2026-08-11-migration-onboarding-target/02-project-inspection.md | Codex stopped at the gate with status draft and result partial; no approval was inferred. |
| 2026-08-11 | Codex CLI 0.146.0 | greenfield | BLOCKED | Step 01 produced docs/aitoolkit/2026-08-11-migration-foundation-example/01-input-report.md; no approval gate opened | Missing approved project-pack review metadata: reviewed_at and review_evidence were null, so the artifact returned result blocked. |
| 2026-08-11 | Codex CLI 0.146.0 | incremental | BLOCKED | Step 01 produced docs/aitoolkit/2026-08-11-migration-preserve-existing-example/01-input-report.md; no approval gate opened | Missing approved project-pack review metadata: reviewed_at and review_evidence were null, so the artifact returned result blocked. |
| 2026-08-11 | Codex CLI 0.146.0 | interactive-default | BLOCKED | Runtime did not start; no migration artifact was produced | `codex exec` returned `Failed to load cloud config bundle (workspace-managed policies)` before onboarding or migration could execute. |
| 2026-08-11 | Codex CLI 0.146.0 | auto | BLOCKED | Runtime did not start; no migration artifact was produced | The same cloud-config error occurred before `--auto` behavior could be observed; static mutation evidence is not promoted to runtime PASS. |
| 2026-08-11 | Codex CLI 0.146.0 | auto-waive | BLOCKED | Runtime did not start; no migration artifact was produced | The same cloud-config error occurred before `--auto-waive` behavior could be observed; no waiver artifact or PASS claim was created. |

When a runtime is available, replace a BLOCKED row only after recording the exact runtime/version, date, observed gate, and artifact path. Do not infer PASS from static validation.

## Acceptance matrix

The follow-up acceptance matrix below maps the streamlined migration-boundary criteria to implementation files, static assertions, and current manual evidence. A BLOCKED manual row is evidence of non-execution, not a pass.

| # | Acceptance criterion | Files | Validator assertion | Manual evidence |
|---|---|---|---|---|
| 1 | Migration has exactly 15 steps and ends at Knowledge Capture | `skills/aitoolkit/migrate/SKILL.md`; `tests/validate-migration-framework.ps1` | Orchestrator row count, terminal-row, and predecessor mutations | Static orchestrator evidence; runtime scenarios remain BLOCKED. |
| 2 | Migration has no Gerrit, CCC, or Release route | `skills/aitoolkit/migrate/SKILL.md`; `docs/MIGRATION-FRAMEWORK.md` | Orchestrator forbidden-route and Docs stale-claim mutations | Static boundary evidence; no delivery runtime inferred. |
| 3 | Gerrit, CCC, and Release remain separate delivery skills invoked only by explicit calls | `skills/shared/{gerrit-automation,ccc-automation,release}`; user docs | Compatibility existence checks and Docs workflow checks | Independent delivery invocation was not run. |
| 4 | The first greenfield foundation unit uses required bootstrap with foundation_baseline_id pending-bootstrap | `skills/migration/{plan-waves,bootstrap-target}`; greenfield fixture | Skills lifecycle mutations plus Docs parsed fixture checks | Greenfield runtime is BLOCKED before observation. |
| 5 | Later greenfield unit uses an approved foundation baseline and does not bootstrap | `skills/migration/{plan-waves,code-migration}`; greenfield fixture | Later-baseline, approval-reference, and no-rerun mutations | Greenfield runtime is BLOCKED before observation. |
| 6 | Incremental preserve-existing does not bootstrap and regression remains required | `skills/aitoolkit/migrate/SKILL.md`; incremental fixture | Orchestrator route plus Docs no-bootstrap/regression checks | Incremental runtime is BLOCKED before observation. |
| 7 | Onboarding generates profile and project pack drafts and publishes only after Tech Lead approval | `skills/aitoolkit/migration-onboarding/SKILL.md`; `skills/migration-onboarding/create-project-pack/SKILL.md` | Onboarding staged-publication and HARD-gate mutations | Onboarding reached Step 02 and produced the inspection artifact; Step 04 draft generation and HARD publication were not observed. |
| 8 | Onboarding accepts explicit document flags and an optional inbox | `commands/migration-onboarding.md`; onboarding orchestrator and resolver | Onboarding argument, resolver-order, and absent-inbox checks | Input resolution was not run interactively. |
| 9 | Onboarding never moves or modifies source documents or production source | onboarding orchestrator; `skills/migration-onboarding/inspect-project/SKILL.md` | Source-immutability and production-edit mutations | No runtime mutation claim; scenario remains BLOCKED. |
| 10 | Claude and Codex docs describe the ordered user workflow | `README.md`; `docs/MIGRATION-FRAMEWORK.md`; `docs/RUN-ON-CODEX.md`; `CONTRIBUTING.md` | Seven-stage workflow order and stale-claim checks | Static documentation evidence only. |
| 11 | Static validator has positive and negative coverage for pipeline boundaries and both greenfield paths | both validator scripts; migration orchestrator; both fixtures | Full selector run plus real-file pressure mutations | Fresh static results are recorded above. |
| 12 | Manual runtime and plugin evidence records only truthful PASS or BLOCKED status | manual and static evidence tables; Docs validator tests | False-PASS, rejected-gate, invalid-artifact, and vague-blocker mutations | Current unavailable execution remains explicitly BLOCKED. |

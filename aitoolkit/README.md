# AIToolKit — Agentic SDLC Kit

Bộ kit điều phối quy trình phát triển phần mềm bằng AI, đóng gói dưới dạng Claude Code plugin thuần prompt. Workflow thật nằm trong orchestrator skill, tiến độ nằm trong artifact Markdown, và mọi human gate vẫn do người dùng quyết định.

## Cài đặt

Qua marketplace local `aitoolkit-local` (khai trong `.claude-plugin/marketplace.json` ở gốc repo):

```text
claude plugin marketplace add <đường-dẫn-repo>
claude plugin install aitoolkit@aitoolkit-local
```

Sửa kit rồi cài lại: xem `CONTRIBUTING.md` §9. Mỗi release phải bump version, uninstall bản snapshot cũ, install lại và mở runtime mới.

## Migration user workflow

1. Prepare migration sources and documents.
2. Run `/aitoolkit:migration-onboarding` with `--legacy`, `--target`, the repeatable `--requirements`, `--uiux`, `--migration-docs`, and `--architecture-docs` flags, or let it read the optional inbox.
3. Review the generated profile at `<RUN_DIR>/project-draft/project.yaml`, generated pack at `<RUN_DIR>/project-draft/migration-project`, and review artifact at `<RUN_DIR>/04-project-pack-review.md`.
4. Obtain explicit Tech Lead approval; the HARD gate publishes those exact staged bytes to canonical `docs/aitoolkit/project.yaml` and `docs/aitoolkit/migration-project`.
5. Run `/aitoolkit:migrate <feature-slug>`.
6. Migration ends at Knowledge Capture after the mode-specific verification path.
7. Gerrit, CCC, and Release are separate delivery skills invoked only by explicit calls after migration.

## Scope orchestration linh động

Migration dùng mô hình hai tầng. **Scope plane** resolve requested scope, duy trì `master-spec.md`/`master-plan.md`, dependency graph, revision, queue và terminal verdict; tầng này không sửa target source. **Execution plane** nhận đúng một approved work item (`max_concurrency: 1`), chạy một immutable attempt và trả terminal evidence; nó không được tự thêm item hoặc báo toàn bộ scope complete.

`work_item` là khái niệm chung. Project không có unit vẫn chạy được bằng adapter `none`; project có canonical migration plan có thể gắn adapter `migration-unit`, nhưng selector phải resolve đúng approved row. Ví dụ unit: `WORK-ADMIN-LOCKS -> migration-unit:UNIT-ADM-002`. Ví dụ không dùng unit: `WORK-BILLING-EXPORT -> none`, với acceptance/trace riêng và không phát minh external ID.

Resume đọc explicit latest approved linear master revisions, reconcile attempt `in-progress`, rồi chọn deterministic theo dependency depth, `Plan Order`, `Work Item ID`; không quét thư mục để đoán state. Thay scope/dependency/acceptance/selector/architecture tạo immutable revision mới và duyệt lại affected items. Attempt complete chỉ kết thúc một lần chạy; work-item complete chỉ kết thúc acceptance của item; `scope-complete` chỉ do master plan tính khi mọi required item terminal-success, graph hợp lệ, architecture/selector-schema `PASS`, không blocker và terminal scope report liệt kê đủ evidence.

Historical unit-only runs phải qua compatibility conversion và approval mới trước mutation: tạo master spec/plan revision 1, một work item cho mỗi canonical legacy unit, giữ exact adapter/evidence hợp lệ và không suy module completion từ một unit.

## Tự động hóa và ngôn ngữ artifact

- Profile mới mặc định `automation.mode: interactive` và `output.artifact_language: vi`; profile cũ thiếu hai field dùng fallback tương ứng `interactive` và `vi`. Vì vậy artifact migration được sinh mặc định tiếng Việt UTF-8, còn key/enums/ID/path/command/log và cột bảng machine-readable giữ nguyên.
- Thứ tự phân giải mode là CLI flag → `automation.mode` trong profile → `interactive`. `--auto` tự duyệt soft gate không bị blocked, không hỏi và không waiver; gặp blocker hoặc HARD gate thì dừng.
- `--auto-waive` cũng không hỏi ở soft gate và chỉ waiver blocker `environment-unavailable` có bằng chứng thật. Lỗi correctness, schema, path, selector, regression, scope và HARD gate luôn dừng.
- Evidence giữ nghĩa thật: `PASS`, `FAIL`, `BLOCKED`, `WAIVED`, `NOT_RUN`. Check được waiver phải là `NOT_RUN + WAIVED`, có `result: partial` và không phải `PASS`; không ghi giả test đã chạy.
- Tài liệu nguồn luôn read-only: workflow không dịch, di chuyển hoặc rewrite source document.


Onboarding phân loại một trong hai mode:

- `greenfield` đi cùng `architecture_policy: design-new`: Tech Lead phải duyệt technical design; foundation unit `required` bootstrap, còn later unit `not-required` bỏ bootstrap và dùng approved foundation baseline.
- `incremental` đi cùng `architecture_policy: preserve-existing`: giữ target architecture, không bootstrap, capture baseline trước khi sửa và bắt buộc regression verification.

Giá trị còn `unknown` hoặc `null` không được đoán. Step phụ thuộc phải ghi `result: blocked`, trình evidence/unknowns và dừng trước gate kế tiếp. Hướng dẫn đầy đủ và evidence walkthrough: `docs/MIGRATION-FRAMEWORK.md`.

## Các workflow khác

- `/aitoolkit:bugfix <bug-slug>` — reproduce, root cause, fix rồi dùng các shared review/test/release step.
- `/aitoolkit:feature <feature-slug>` — requirements, design, implement rồi dùng các shared step.
- Nói rõ trong yêu cầu để bỏ bước optional như CCC hoặc Release. Gerrit và Release HARD gate không bao giờ tự vượt.

Artifact của mỗi run nằm tại `docs/aitoolkit/<date>-<workflow>-<slug>/`. Profile `docs/aitoolkit/project.yaml` cung cấp command, mode, policy và đường dẫn project pack. Không có workflow manifest, state engine hoặc private run store; orchestrator đọc artifact đã approved để tiếp tục run.

Migration chỉ dùng project pack khi `reviewed_at`/`review_evidence` còn khớp current revisions. Feature/bugfix vẫn chạy universal review và default Gerrit/CCC khi không có explicit mandatory pack rule.

## Chạy trên Codex

Codex không gọi custom Claude slash command. Dùng AGENTS.md bootstrap hoặc Codex wrapper:

```text
$aitoolkit migration-onboarding --legacy <path> --target <path> [--requirements <path> ...] [--uiux <path> ...] [--migration-docs <path> ...] [--architecture-docs <path> ...]
$aitoolkit migrate <feature-slug>
```

Xem `docs/RUN-ON-CODEX.md` và thư mục `codex/`.

## Cùng phát triển

- `CONTRIBUTING.md` — kiến trúc, invariant, cách thêm workflow và verification bắt buộc.
- `docs/MIGRATION-FRAMEWORK.md` — onboarding, greenfield/incremental walkthrough, manual evidence và acceptance matrix.
- `../docs/superpowers/specs/2026-08-07-language-agnostic-migration-framework-design.md` — design nguồn.
- Skill `aitoolkit-schemas` — hợp đồng project profile và artifact.

Chạy static validation trước khi commit:

```powershell
& .\aitoolkit\tests\validate-migration-framework.ps1 -Check All
claude plugin validate .\aitoolkit
git diff --check
```

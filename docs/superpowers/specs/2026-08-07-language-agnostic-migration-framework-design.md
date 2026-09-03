# Language-Agnostic Migration Framework — Thiết kế Superpowers-native

- **Ngày tạo:** 2026-08-07
- **Trạng thái:** Draft để review
- **Phạm vi:** Refactor workflow migration hiện tại thành framework không phụ thuộc công nghệ nhưng giữ nguyên cơ chế điều phối thuần Superpowers

## 1. Bối cảnh

AIToolkit hiện dùng orchestrator skill viết bằng Markdown, bảng bước, TodoWrite, artifact có frontmatter và human gate. Workflow không còn YAML manifest, state machine, `state.json`, `.aitoolkit/run-*`, engine resume hay dry-run stub. Mỗi run ghi artifact vào:

```text
<project>/docs/aitoolkit/<yyyy-mm-dd>-<workflow>-<slug>/
```

Workflow migration hiện vẫn gắn trực tiếp với webOS/QML → Flutter, Luna Service, Clean Architecture, Riverpod và lệnh Flutter. Mục tiêu mới là giữ nguyên cơ chế Superpowers-native nhưng tách kiến thức công nghệ/dự án khỏi migration core.

Khi áp dụng vào dự án thật, onboarding khảo sát legacy, target, tài liệu và toolchain rồi tạo project migration pack. Migration orchestrator và step-skill generic đọc pack này thay vì hardcode stack.

Framework hỗ trợ:

1. **Greenfield:** target chưa có baseline kiến trúc đáng kể; agent được đề xuất kiến trúc mới nhưng không bootstrap hoặc implement trước Tech Lead gate.
2. **Incremental:** target đã có code/feature; agent phải bảo toàn kiến trúc và convention hiện có theo thứ tự `reuse → extend compatibly → create following existing pattern`.

## 2. Mục tiêu

1. Giữ orchestrator skill, bảng bước, TodoWrite, artifact Markdown và human gate hiện tại.
2. Làm migration core language/framework-agnostic.
3. Tách knowledge webOS/QML/Flutter/LGE thành project pack mẫu.
4. Thêm onboarding thuần Superpowers để tạo/cập nhật project profile và project pack.
5. Hỗ trợ greenfield và incremental bằng policy viết rõ trong orchestrator/step-skill.
6. Bảo đảm traceability từ requirements/UIUX/legacy đến target files và verification evidence.
7. Dùng `unknown`/gap/`BLOCKED` khi thiếu evidence; không tự đoán command, architecture hoặc behavior.
8. Không làm thay đổi hành vi workflow feature và bugfix ngoài việc shared skill đọc rule từ profile/project pack.

## 3. Ngoài phạm vi

- Không khôi phục workflow manifest, conductor engine, `state.json`, `--resume`, `.aitoolkit/run-*` hoặc dependency invalidation engine.
- Không xây AST/compiler chuyển đổi chung cho mọi ngôn ngữ.
- Không tự động cải tổ architecture trong incremental mode.
- Không tự vượt soft/hard gate.
- Không tích hợp sâu Figma, Jira, Gerrit API hoặc CI; pack có thể chỉ dẫn công cụ hiện có.
- Không cam kết pixel-perfect/behavior parity nếu không có baseline đủ dùng.

## 4. Nguyên tắc bất biến

### 4.1 Orchestrator thuần Superpowers

`skills/aitoolkit/migrate/SKILL.md` là nguồn sự thật của thứ tự bước và gate. Command chỉ là launcher mỏng. Orchestrator:

- tạo `RUN_DIR` trong `docs/aitoolkit/`;
- tạo TodoWrite theo bảng bước;
- truyền đường dẫn artifact trước cho step kế;
- đọc `result` của artifact để đi tiếp hoặc dừng;
- xử lý mode condition bằng lời, không qua manifest interpreter;
- giữ hard gate Gerrit/Release như hiện tại.

Tiếp tục run dở bằng cách đọc artifact có `status: approved` trong `RUN_DIR`; không có state store riêng.

### 4.2 Core không biết công nghệ

Migration orchestrator, migration step-skill và generic migration template không chứa tên ngôn ngữ, framework, architecture, package manager hoặc command cụ thể. Chúng chỉ dùng:

- project profile;
- project migration pack;
- artifact trước;
- source/doc evidence;
- quyết định đã được duyệt.

### 4.3 Evidence trước kết luận

Mọi feature, mapping, command, architecture rule và parity verdict phải liên kết tới evidence. Giá trị chưa xác định là `unknown` kèm gap/câu hỏi. Nếu gap chặn bước kế, artifact trả `result: blocked` và orchestrator dừng ở gate.

### 4.4 Incremental bảo toàn target

Trong incremental mode:

- target source và quyết định kiến trúc đã duyệt là chuẩn cho architecture/convention;
- mapping dùng `reuse`, `extend`, `create`, `replace` hoặc `omit`;
- `replace` cần quyết định riêng được duyệt;
- không thêm pattern cạnh tranh, đổi dependency nền tảng hoặc refactor ngoài scope;
- architecture concern ngoài scope được ghi technical debt.

### 4.5 Greenfield có design gate

Trong greenfield mode, technical design được đề xuất architecture/foundation mới. Tech Lead phải duyệt trước bootstrap. Sau bootstrap đầu tiên, các migration unit sau tuân architecture đã duyệt như target baseline.

Bootstrap là quyết định theo selected unit, không phải theo mode một cách vô điều kiện. Foundation unit có `Bootstrap Scope = required` chạy bootstrap và tạo approved foundation-baseline record. Later greenfield unit có `Bootstrap Scope = not-required` bỏ qua bootstrap, chọn một approved foundation-baseline record/target-baseline reference từ migration plan, và block nếu selector, approval hoặc freshness evidence thiếu/sai/stale.

### 4.6 Artifact là interface

Step-skill không gọi trực tiếp step-skill khác và không tra state store. Orchestrator truyền path artifact trước. Project pack cung cấp knowledge nhưng output của step vẫn theo template generic.

## 5. Kiến trúc

```text
Claude/Codex entry point
  └── thin command/router
        └── Superpowers orchestrator skill
              ├── Bảng bước + mode policy + human gate
              ├── Project profile resolver
              ├── Project migration pack resolver
              └── Generic migration step-skills
                    └── Markdown artifacts in docs/aitoolkit/<run>/
```

### 5.1 Cấu trúc AIToolkit

```text
aitoolkit/
├── commands/
│   ├── migrate.md
│   └── migration-onboarding.md
├── skills/
│   ├── aitoolkit/
│   │   ├── migrate/SKILL.md
│   │   └── migration-onboarding/SKILL.md
│   ├── migration/
│   │   ├── validate-inputs/
│   │   ├── discovery/
│   │   ├── analyze-requirements-uiux/
│   │   ├── build-inventory/
│   │   ├── feature-mapping/
│   │   ├── analyze-gaps-conflicts/
│   │   ├── technical-design/
│   │   ├── plan-waves/
│   │   ├── bootstrap-target/
│   │   ├── code-migration/
│   │   ├── verify-parity/
│   │   └── verify-regression/
│   ├── migration-onboarding/
│   │   ├── inspect-project/
│   │   ├── classify-mode/
│   │   └── create-project-pack/
│   └── shared/
├── templates/migration/
├── examples/project-packs/webos-qml-flutter/
└── tests/validate-migration-framework.ps1
```

Tên skill `feature-mapping` và `code-migration` được giữ để giảm thay đổi route hiện tại; nội dung được generic hóa.

### 5.2 Cấu trúc trong project đích

```text
<project>/docs/aitoolkit/
├── project.yaml
├── migration-project/
│   ├── SKILL.md
│   └── references/
│       ├── legacy-system.md
│       ├── target-baseline.md
│       ├── architecture-rules.md
│       ├── mapping-rules.md
│       ├── uiux-rules.md
│       ├── testing-rules.md
│       └── definition-of-done.md
└── <date>-<workflow>-<slug>/
    └── artifacts...
```

Project pack được version-control cùng project. Nó là reference pack do orchestrator đọc theo path trong profile, không phụ thuộc runtime tự động discover skill cục bộ.

## 6. Project profile contract

File mặc định: `<project>/docs/aitoolkit/project.yaml`.

```yaml
schema_version: 1
project:
  id: unknown

change_type: migration

migration:
  mode: unknown # greenfield | incremental | unknown
  unit: feature
  architecture_policy: unknown # design-new | preserve-existing | unknown

legacy:
  path: null
  language: unknown
  framework: unknown

target:
  path: null
  language: unknown
  framework: unknown

documents:
  requirements: []
  migration: []
  uiux: []

base_branch: null
test_cmd: null
lint_cmd: null
build_cmd: null
coverage_cmd: null
review_focus: []

verification:
  behavior_parity: required # required | optional | unavailable
  regression: optional
  visual_fidelity: optional

project_pack:
  path: docs/aitoolkit/migration-project
  reviewed_at: null
  review_evidence: null
```

Invariants:

- `greenfield` ⇒ `architecture_policy: design-new`.
- `incremental` ⇒ `architecture_policy: preserve-existing`.
- Migration step 01 chỉ chấp nhận pack khi `reviewed_at` là RFC 3339 non-null, `review_evidence` trỏ approved pack-review artifact, và recorded revisions khớp profile/pack/source/target/documents hiện tại; stale hoặc không so sánh được ⇒ `blocked`.
- Field cần thiết còn `unknown`/`null` ⇒ step phụ thuộc trả `blocked`.
- Command resolution giữ thứ tự hiện tại: explicit profile → existing project scripts/config → marker detection → human gate.

## 7. Artifact contract

Mọi artifact migration là Markdown có frontmatter:

```yaml
---
step_id: 01-validate-inputs
status: draft # draft | approved
result: complete # complete | partial | blocked
produced_at: 2026-08-07
---
```

- `status` phục vụ human gate và tiếp tục run.
- `result` là verdict nghiệp vụ:
  - `complete`: đủ output/evidence;
  - `partial`: còn gap nhưng không chặn bước kế;
  - `blocked`: thiếu input/evidence/decision bắt buộc, orchestrator dừng.
- Lỗi thực thi không cần `result: failed`; skill báo lỗi và không được coi artifact là hoàn tất.
- Artifact có `Evidence`, `Unknowns` và `Verdict` khi phù hợp.
- Artifact đã approved chỉ được sửa khi gate yêu cầu rerun; thay đổi phải được trình duyệt lại.
- Từ selected unit sau step 08, migration artifact giữ envelope gồm unit/plan/approval/mode/Bootstrap Scope, Foundation Baseline ID/reference/approval, regression baseline reference và trace IDs. Step 14 giữ parity verdict và thêm regression verdict; Gerrit đọc exact immediate predecessor.

## 8. Onboarding workflow

Entry point: `/aitoolkit:migration-onboarding` hoặc Codex router với workflow `migration-onboarding`.

Onboarding là orchestrator skill riêng, không dùng manifest và không sinh production code.

| # | Step | Output | Gate |
|---|---|---|---|
| 01 | Validate input paths/documents | onboarding input report | Block khi thiếu input bắt buộc |
| 02 | Inspect legacy, target, docs và toolchain | inspection report | PM/Tech Lead |
| 03 | Classify greenfield/incremental | mode proposal | Tech Lead |
| 04 | Create/update profile và project pack | pack review report | Tech Lead HARD review gate |

Onboarding chỉ ghi dữ liệu có evidence. Khi cập nhật pack, report liệt kê rule thay đổi và các run/artifact cũ có thể cần xem lại; framework không tự invalidation bằng state engine.

## 9. Migration workflow

Migration orchestrator mở rộng bảng bước hiện có:

| # | Step | Artifact | Gate/condition |
|---|---|---|---|
| 01 | Validate inputs/profile/pack | `01-input-report.md` | Block nếu thiếu bắt buộc |
| 02 | Discover legacy và target | `02-discovery.md` | PM/Tech Lead |
| 03 | Analyze requirements/UIUX | `03-requirements-uiux.md` | Product/UX |
| 04 | Build migration inventory | `04-inventory.md` | Product/Tech Lead |
| 05 | Map source to target | `05-mapping.md` | Product/Tech Lead |
| 06 | Analyze gaps/conflicts | `06-gaps-conflicts.md` | Decision owner |
| 07 | Technical design/conformance | `07-technical-design.md` | Tech Lead |
| 08 | Plan migration waves/units | `08-migration-plan.md` | Tech Lead/Developer |
| 09 | Bootstrap target | `09-bootstrap-report.md` | Greenfield only; Developer |
| 10 | Implement approved migration unit | `10-implementation-report.md` | Developer |
| 11 | AI review | `review-report.md` | Reviewer |
| 12 | Verification testing | `verification-report.md` | Dev/QA |
| 13 | Verify parity | `13-parity-report.md` | Product/UX/QA |
| 14 | Verify target regression | `14-regression-report.md` | Incremental only; QA |
| 15 | Gerrit automation | `gerrit-report.md` | HARD |
| 16 | CCC | `ccc-package.md` | Optional |
| 17 | Release | `release-report.md` | Optional, HARD |
| 18 | Knowledge base | `kb-entry.md` | None |

Conditional behavior được mô tả trong orchestrator:

- mode `greenfield`: chạy step 09 chỉ khi selected unit có `Bootstrap Scope = required`; unit `not-required` dùng approved foundation baseline và bỏ step 09; bỏ step 14 nếu regression policy không yêu cầu;
- mode `incremental`: bỏ step 09, bắt buộc baseline trước implementation và chạy step 14 trừ waiver đã duyệt;
- mode `unknown`: dừng trước mode-dependent step và hỏi người dùng;
- optional CCC/Release giữ cách hỏi/bỏ qua hiện tại.

## 10. Traceability và conflict

Mỗi migration unit phải nối được:

```text
requirement/UIUX evidence
  → legacy feature/component/service
  → mapping decision
  → target design element
  → changed target files
  → test/visual evidence
  → parity/regression verdict
```

Thiếu mắt xích bắt buộc thì verdict tối đa là `partial`.

Nguồn sự thật phụ thuộc loại quyết định:

| Quyết định | Thứ tự ưu tiên |
|---|---|
| Architecture/convention incremental | approved decision → target source → target architecture docs |
| Architecture greenfield | approved target design |
| Business behavior | approved requirements → observable legacy behavior |
| Desired UI/UX | approved UIUX → approved requirements → observable legacy UI |
| Build/test command | profile → project scripts/config → toolchain detection → human input |

Conflict record ghi evidence, ảnh hưởng, lựa chọn, approver và quyết định. Step phụ thuộc conflict chưa giải quyết trả `blocked`.

## 11. Project pack contract

`migration-project/SKILL.md` là index ngắn, chỉ dẫn step-skill đọc reference phù hợp. Pack phải có:

- legacy taxonomy và behavior notes;
- target baseline/architecture/convention;
- mapping rules;
- UIUX rules;
- test/build/review/release rules;
- definition of done;
- evidence hoặc nguồn cho từng rule quan trọng.

Pack không được ghi command chưa xác nhận. Script chỉ được thêm khi dự án thật sự cần thao tác deterministic lặp lại; base framework không phụ thuộc script của pack.

## 12. Tách compatibility knowledge

Knowledge webOS/QML/Flutter hiện có được chuyển sang:

```text
examples/project-packs/webos-qml-flutter/
```

Generic migration core không chứa `QML`, `Luna Service`, `Flutter`, `Riverpod`, `Clean Architecture`, `flutter analyze` hoặc `flutter test`. Shared skill không phụ thuộc trực tiếp `lge-rules`; chúng đọc project pack/profile và degrade hoặc `BLOCKED` theo mức bắt buộc.

## 13. Verification

### 13.1 Static validator

PowerShell validator là công cụ development, không phải runtime dependency. Nó kiểm tra:

- skill/template/command bắt buộc tồn tại;
- profile và artifact token bắt buộc;
- orchestrator có đủ bước, gate và mode branch;
- generic core không rò rỉ technology token;
- project pack mẫu chứa knowledge đã tách;
- command/router trỏ tới orchestrator tồn tại;
- UTF-8 và mojibake.

### 13.2 Manual scenarios

Hai walkthrough nhỏ chứng minh:

- greenfield foundation: design gate → bootstrap → implementation; later unit: approved foundation baseline → implementation không bootstrap; regression optional theo profile;
- incremental: baseline → preserve-existing → không bootstrap → regression bắt buộc;
- onboarding không sửa production code;
- `blocked` dừng ở gate;
- artifact approved cho phép đọc lại và tiếp tục run theo cơ chế hiện tại.

Không khôi phục dry-run engine, stub step hoặc state-resume fixture.

## 14. Rollout

1. Cập nhật schema/profile/artifact contract và validator.
2. Generic hóa migration templates và front-half skills.
3. Thêm mode-aware design/plan/bootstrap/implementation/parity/regression skills.
4. Cập nhật migration orchestrator table và conditional policy.
5. Thêm onboarding orchestrator + command/router.
6. Tách LGE/webOS/QML/Flutter knowledge thành example project pack và cập nhật shared skill.
7. Cập nhật docs, Codex surface, plugin metadata và chạy verification.

Mỗi pha giữ feature/bugfix workflow chạy được và không khôi phục engine đã loại bỏ.

## 15. Tiêu chí chấp nhận

1. Không có workflow manifest, state engine hoặc `.aitoolkit/run-*` mới.
2. Migration core không chứa knowledge công nghệ cụ thể.
3. Project profile hỗ trợ mode/policy và vẫn tương thích command resolution hiện tại.
4. Onboarding tạo/cập nhật profile + pack nhưng không sửa production source.
5. Greenfield không implement trước Tech Lead design gate.
6. Incremental giữ target architecture, không bootstrap và có regression verification.
7. Artifact có evidence/unknown/verdict và `result: blocked` dừng workflow.
8. Mỗi migration unit có traceability end-to-end.
9. webOS/QML/Flutter workflow được biểu diễn bằng example pack, không bằng core hardcode.
10. Feature và bugfix workflow không bị thay đổi ngoài shared rule resolution tương thích.
11. Claude command và Codex router đều gọi đúng orchestrator skill.
12. Static validator và hai manual walkthrough cho kết quả có evidence.

## 16. Quyết định thiết kế đã chốt

- Giữ Superpowers-native orchestration; không phục hồi engine/manifest/state.
- Giữ artifact Markdown và `docs/aitoolkit/` làm nơi lưu profile, pack và run artifact.
- Project pack được resolve qua path trong profile; không giả định runtime tự discover local skill.
- Giữ tên route migration hiện có khi có thể để giảm blast radius.
- Mode condition là policy trong orchestrator/step-skill.
- Validator chỉ phục vụ phát triển; runtime vẫn thuần prompt.

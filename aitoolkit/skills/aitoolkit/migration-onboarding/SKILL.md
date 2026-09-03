---
name: migration-onboarding
description: Use when a project needs an evidence-backed migration profile and project pack before running the language-agnostic migration workflow.
---

# AIToolKit — Migration Onboarding Orchestrator

Điều phối onboarding inline trong context của người dùng. Workflow chỉ khảo sát và ghi tài liệu dưới `docs/aitoolkit/`; không sửa source, cấu hình build, dependency hay workspace của legacy/target.

**Core principle:** Evidence quyết định profile. Deadline, tên file, marker đơn lẻ và mong muốn demo không phải bằng chứng đủ để tự chốt mode, architecture hoặc command.

## Argument contract

Derive `<project>` from the current target-project context; never parse project root from positional arguments. The accepted flags are `--legacy`, `--target`, `--requirements`, `--uiux`, `--migration-docs`, and `--architecture-docs`. Parse `$ARGUMENTS` only as `--legacy <path>` and `--target <path>` plus the four categorized document flags. All four document flags are repeatable and accept a file or directory. If the current target-project context is not uniquely identifiable, block input validation and ask the user to open or identify the target project before parsing flags.

## Chuẩn bị run

1. Resolve project root from the current target-project context; parse only legacy/target/docs paths from `$ARGUMENTS`, then ask for any required path that remains missing or ambiguous.
2. Đặt `RUN_DIR = <project>/docs/aitoolkit/<date>-migration-onboarding-<slug>/` và tạo TodoWrite đúng 4 mục trong bảng dưới; chỉ một mục `in_progress`.
3. Chỉ tạo hoặc cập nhật `docs/aitoolkit/project.yaml`, `docs/aitoolkit/migration-project/` và artifact trong `RUN_DIR`.
4. Đọc `aitoolkit-schemas` trước khi ghi profile hoặc artifact.

## Ngôn ngữ artifact

Resolve per-run `artifact_language: vi` trước step 01 và stage `output.artifact_language: vi` trong profile mới. The currently supported value is `vi`; onboarding không tự suy ra hoặc sinh giá trị khác.

Pass `artifact_language` in every onboarding step invocation. Với `artifact_language: vi`, mọi tiêu đề, tóm tắt, blocker, khuyến nghị và nội dung gate được viết bằng tiếng Việt UTF-8; giữ nguyên mọi field machine-readable, enum, ID, path, command, log, trace field và cột bảng contract.

Không dịch, di chuyển hoặc sửa tài liệu nguồn. Các document input và mọi file dưới legacy/target roots luôn byte-for-byte read-only; chỉ profile, project pack và artifact mới trong phạm vi `docs/aitoolkit/` được ghi.

## Bảng bước (migration onboarding)

| # | skill | artifact | approver | gate | prompt |
|---|---|---|---|---|---|
| 01 | `inline (orchestrator)` | `01-onboarding-input.md` | — | block-only | Các path bắt buộc có tồn tại, đọc được và phân biệt rõ legacy/target không? |
| 02 | `migration-onboarding/inspect-project` | `02-project-inspection.md` | PM/Tech Lead | soft | Duyệt inspection evidence và Unknowns? |
| 03 | `migration-onboarding/classify-mode` | `03-mode-proposal.md` | Tech Lead | soft | Duyệt mode/architecture-policy proposal và command resolution? |
| 04 | `migration-onboarding/create-project-pack` | `04-project-pack-review.md` | Tech Lead | HARD | Xác nhận project profile và toàn bộ project pack? |

## Input validation contract

Step 01 là kiểm tra cơ học của orchestrator, không phải suy luận chuyên môn:

1. Xác nhận project root, legacy path và target path được định danh rõ, tồn tại khi được khai báo, và đọc được. Documents có thể là danh sách rỗng nhưng phải được ghi rõ.
2. Không yêu cầu target có production code; target rỗng hoặc placeholder là evidence để step 03 xử lý, không phải lý do tự chốt greenfield.
3. Ghi `<RUN_DIR>/01-onboarding-input.md` từ `templates/migration/onboarding-input.md`, với path tuyệt đối/ổn định, owner, Evidence và Unknowns.
4. Path thiếu, cùng một path bị gán cả legacy lẫn target, hoặc quyền đọc không đủ làm artifact có `result: blocked`; dừng trước step 02.

## Document resolver contract

Resolve documents in this exact order:

1. **explicit flag paths** - expand each declared file or directory under its flag category, preserving flag occurrence order and deterministic canonical-path order within a directory.
2. **matching inbox directory if present** - append every regular file, without filtering by readability or format, from the optional category inbox under `<project>`:
   - `requirements` -> `docs/aitoolkit/inputs/requirements/`
   - `uiux` -> `docs/aitoolkit/inputs/uiux/`
   - `migration` -> `docs/aitoolkit/inputs/migration/`
   - `architecture` -> `docs/aitoolkit/inputs/architecture/`
3. **canonical-path merge/dedupe** - resolve stable absolute filesystem identity and keep the first occurrence. Because explicit records are first, a duplicate discovered in an inbox keeps `Input Source = explicit`.
4. **readability/format validation** - open every resolved regular file with the available read-only tool, identify its actual format, and verify it can be decoded or inspected. Do not infer readability only from an extension.
5. **categorized Evidence records** - assign a stable unique Evidence ID and emit exactly these fields for every surviving document:

| Category | Canonical Path | Input Source | Format | Readability | Evidence ID |
|---|---|---|---|---|---|
| <requirements / uiux / migration / architecture> | <stable absolute path> | <explicit / inbox> | <detected format> | <readable> | <DOC-...> |

The resolver only reads and fingerprints inputs. It must not copy, move, rename, rewrite, normalize, or otherwise modify a supplied file or anything under the legacy/target roots. Step 01 writes the resulting records to `01-onboarding-input.md`; step 02 consumes them without reclassifying their category or source authority.

## Document resolution failures

| Condition | Result | Required behavior |
|---|---|---|
| explicit path is missing or unreadable | block | Record the path and category as a blocker; stop before step 02. |
| present inbox directory is unreadable | block | Record the matching inbox and permission/read failure; stop before step 02. |
| discovered regular file is unreadable | block; never silently omit | Record the child path, category, source, and read failure as blocker evidence; stop before step 02. |
| document format cannot be opened or decoded | block; never silently skip | Record format/readability evidence and stop before step 02. |
| optional inbox directory is absent | continue | Treat the category inbox as empty; absence alone is not a blocker. |

An explicit directory that contains no readable regular documents is valid only as an empty category input; unreadable entries or formats are blockers, not files to omit silently.

## Mode classification gate

Áp dụng sau inspection và trước khi tạo pack:

- `placeholder-only target` hoặc target không có architecture/feature đáng kể: đề xuất `mode: unknown`, giữ policy unknown, ghi `result: blocked`, rồi yêu cầu Tech Lead approval xác nhận có thật sự dùng `greenfield` / `design-new` hay không.
- Có `stable target architecture`, nhiều feature đã migrate và convention lặp lại có evidence: đề xuất cặp duy nhất `incremental` / `preserve-existing`.
- `ambiguous toolchain`, nhiều workspace/marker/command nhưng không xác định được scope có thẩm quyền: các commands remain `null`, ghi candidate kèm location, trả `result: blocked` và yêu cầu Tech Lead approval hoặc repository owner xác nhận.
- Chỉ `classify-mode` tạo proposal. Orchestrator giữ `status: draft` và không chạy step 04 cho tới khi Tech Lead duyệt đúng cặp mode/policy cùng mọi command blocker.

Khi proposal blocked cần quyết định con người, stop downstream và normal approval gate nhưng present the blocker decision cho đúng owner. Record the approved decision as evidence trong feedback có owner, decision, scope và thời điểm; sau đó rerun step 03 với evidence mới. Chỉ proposal rerun có `result: complete` or `partial` mới được mở Tech Lead soft approval gate. Đây là vòng giải quyết blocker, không phải tự duyệt artifact blocked.

Không dùng enum tự đặt như brownfield, bootstrap hoặc multi-workspace. Chỉ dùng `greenfield`, `incremental`, `unknown` và invariant trong profile contract.

## Onboarding handoff contract

`Immediate predecessor artifact = exactly one orchestrator-provided path`.

- Step 02 receives only `01-onboarding-input.md`.
- Step 03 receives only `02-project-inspection.md`; step 03 forwards all required inspection evidence references, every categorized document Evidence record, plus resolved command authority, source, scope, and blocker state into its own output.
- Step 04 receives only the approved immediate predecessor `03-mode-proposal.md`. It does not load step 02 or reconstruct missing evidence from older artifacts.
- A missing forwarded reference makes step 03 or step 04 `result: blocked`; the orchestrator never widens the input set to repair a stale handoff.

## Step execution protocol

1. Step 01 ghi artifact input. Nếu blocked, giữ todo hiện tại `in_progress` và dừng.
2. Step 02 nhận đúng input artifact và các path đã kiểm tra. Artifact draft không blocked được trình soft gate; phản hồi bị từ chối quay lại đúng step 02.
3. Step 03 nhận inspection đã approved, chỉ ghi proposal. Artifact `result: blocked` dừng trước approval; proposal đủ evidence vẫn chờ Tech Lead soft gate rồi mới đổi `status: approved`.
4. Step 04 chỉ nhận mode proposal approved. Skill ghi staged drafts và review report trong `RUN_DIR`; orchestrator không sửa canonical profile/pack và không coi draft là usable trước HARD gate.
5. Artifact có `result: blocked` luôn dừng trước normal approval gate và downstream execution. Nếu blocker yêu cầu quyết định, trình câu hỏi cho owner, lưu câu trả lời làm evidence rồi rerun chính step đó; không đổi trực tiếp blocked artifact thành approved. Artifact approved của chính step được validate trước khi tiếp tục run dở.

## Project-pack Tech Lead HARD review gate

Sau step 04, trình Tech Lead các staged drafts, rule/evidence mới, Unknowns, thay đổi so với pack cũ và các run/artifact có thể cần xem lại. HARD gate yêu cầu explicit approval bằng câu xác nhận rõ; không suy diễn từ “ok”.

Before approval, step 04 chỉ ghi dưới `<RUN_DIR>/project-draft/`, giữ `<RUN_DIR>/04-project-pack-review.md` ở `status: draft`, giữ `project_pack.reviewed_at` và `project_pack.review_evidence` là `null`, và tuyệt đối không sửa canonical hiện có. After explicit approval, validate the staged set, finalize recorded content revisions, set the RFC 3339 timestamp and review-evidence path, then publish the canonical `docs/aitoolkit/project.yaml` and `docs/aitoolkit/migration-project/` from those exact bytes as one gate action. Chỉ sau khi publish thành công mới đổi review artifact thành `status: approved` và cho downstream migration dùng pack. Từ chối hoặc yêu cầu sửa chỉ cập nhật staged drafts rồi mở lại cùng HARD gate; canonical cũ giữ nguyên.

## Boundaries

- Every onboarding step must not move, rename, rewrite, or modify any source document or any file under legacy/target roots; all inspection and format checks are read-only.

- Onboarding không sinh production code.
- Không tạo metadata điều phối, persistence store hoặc script helper cho workflow.
- Không ghi command, language, framework, architecture rule hoặc behavior không có evidence.
- Cập nhật pack không tự sửa hay invalidate run cũ; review report chỉ liệt kê ảnh hưởng để con người quyết định.

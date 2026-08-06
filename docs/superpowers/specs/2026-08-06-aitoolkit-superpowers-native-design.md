# AIToolKit — Chuyển sang cơ chế thuần Superpowers

**Ngày:** 2026-08-06
**Trạng thái:** Design — chờ duyệt
**Bối cảnh use-case:** migration/feature/bugfix cho **một tính năng nhỏ, chạy gọn trong một ngày**.

## 1. Vấn đề

AIToolKit hiện chạy theo kiểu "orchestration engine":

- `workflows/*.manifest.yaml` khai báo danh sách bước (dữ liệu).
- `commands/*.md` (conductor) lặp qua manifest, đọc/ghi `state.json`, ép gate, hỗ trợ `--resume`/`--disable`.
- `_dryrun.manifest.yaml` + `skills/_stub/*` là bộ test cho engine.

Cơ chế này khiến pipeline **hoạt động khác Superpowers**: nặng nghi thức (đọc manifest, narrate "isolate:true nên phải…"), có state-machine máy-đọc, và một tầng test (dryrun/stub) không dính tới sản phẩm. Mong muốn: pipeline chạy **y hệt Superpowers** — skill nối skill, gate là câu chữ trong skill, tiến độ qua TodoWrite, không engine.

Vì use-case là **một ngày, một tính năng nhỏ**, các thứ mà engine cung cấp gần như không cần:

| Engine cung cấp | Có cần cho use-case này? |
|---|---|
| Resume xuyên phiên qua `state.json` | Không — chạy một buổi là xong |
| Audit trail máy-đọc (mốc ký duyệt nhiều ngày) | Không |
| `--disable` step optional | Không — nói "bỏ CCC/release" là đủ |
| Gate engine-ép | Thay bằng HARD-GATE bằng câu chữ mạnh trong skill |

## 2. Mục tiêu & Không-mục-tiêu

**Mục tiêu**
- Bỏ hẳn động cơ: YAML manifest, conductor loop, `state.json`, `_dryrun`, `_stub`.
- Điều phối theo kiểu Superpowers: **orchestrator skill viết bằng văn xuôi** (giống `executing-plans`) gọi lần lượt các step-skill, xử lý gate ngay trong lời skill.
- Giữ nguyên phần **làm việc thật** của mọi step-skill (discovery, mapping, review, gerrit…). Đây là refactor tầng điều phối, KHÔNG viết lại nội dung nghiệp vụ.
- Giữ 3 pipeline (migration/feature/bugfix) và việc **tái dùng** các step-skill `shared/*` giữa chúng.

**Không-mục-tiêu**
- Không thêm resume máy-đọc, không audit trail, không `--disable` (đánh đổi đã chấp nhận ở §1).
- Không đổi nội dung template hay logic nghiệp vụ từng bước.

## 3. Kiến trúc mới

### 3.1 Orchestrator skill (thay manifest + conductor)

Mỗi pipeline có **một orchestrator viết bằng văn xuôi** — thay cho cặp `manifest.yaml` + conductor generic. Nội dung orchestrator liệt kê thẳng chuỗi bước, mỗi bước ghi rõ: `step-skill`, `approver`, `gate prompt`, và cờ optional (nếu có). Vòng đời một bước, do orchestrator điều khiển:

1. Đánh dấu todo bước này `in_progress` (TodoWrite).
2. Gọi step-skill (chạy inline). Step làm việc thật → ghi artifact vào `<project>/.aitoolkit/run-<id>/` với front-matter `status: draft`.
3. Trình tóm tắt + đường dẫn artifact cho người dùng.
4. **Gate:**
   - `soft` → dùng `AskUserQuestion`: **Duyệt** / **Từ chối + feedback**. Duyệt → sửa front-matter artifact `status: approved`, todo `completed`, sang bước kế. Từ chối → chạy lại đúng bước đó kèm feedback, không đụng bước đã duyệt.
   - `hard` (Gerrit, Release) → cảnh báo "Hành động KHÔNG THỂ đảo ngược", **yêu cầu xác nhận tường minh** (gõ đúng yêu cầu, không nhận "ok" mơ hồ). KHÔNG BAO GIỜ tự vượt.
   - `none` (Knowledge Base) → chạy xong là `completed`, không hỏi.
5. Bước cuối xong → báo hoàn tất.

**Optional (CCC, Release):** thay `--disable`, orchestrator hỏi thẳng "Chạy bước này không?" (hoặc người dùng nói bỏ trước) → bỏ thì đánh dấu todo `completed` ghi "skipped", không gọi skill.

**isolate:** bỏ khái niệm `isolate:true` trong dữ liệu. Mặc định chạy **inline** (đúng mặc định Superpowers). `dispatching-parallel-agents` vẫn dùng được cho bước thật sự nặng-và-độc-lập nếu cần, nhưng KHÔNG bị cấu hình ép — do orchestrator quyết định trong lời skill.

### 3.2 Tiến độ & lưu trạng thái

- **Tiến độ:** TodoWrite, mỗi bước một todo. Đây là "state" hiển thị, thay `state.json`.
- **Lưu trạng thái:** chỉ dựa vào **artifact ghi ra file** + front-matter `status: draft→approved`. Đủ để một run một-buổi tự thuật lại nó đã tới đâu nếu cần đọc lại. Không có `state.json`.
- **run-id + run-dir:** vẫn sinh `run-<YYYYMMDD>-<NN>` và thư mục `<project>/.aitoolkit/run-<id>/` để gom artifact (đây chỉ là thư mục, không phải engine).

### 3.3 Step-skill (giữ nội dung, bỏ khung conductor)

Mỗi `skills/**/SKILL.md` giữ nguyên phần "Việc cần làm" + template + ranh giới. Chỉ sửa **khung giao tiếp**:
- Bỏ mọi câu kiểu "được conductor gọi với `step_id`/`state.json`", "trả về đường dẫn cho conductor".
- Thay bằng: skill nhận `run_dir` + đường dẫn artifact **bước trước** (do orchestrator truyền), làm việc, ghi artifact của mình. Không tự lo gate (orchestrator lo).
- "Input bước trước" lấy trực tiếp từ đường dẫn orchestrator truyền vào, KHÔNG tra `state.json`.

### 3.4 Điểm vào (entry points)

- **Claude Code:** `commands/{migrate,feature,bugfix}.md` được viết lại thành orchestrator prose (thay nội dung conductor cũ).
- **Codex:** `codex/skills/aitoolkit/SKILL.md` + `codex/AGENTS.snippet.md` cập nhật để trỏ cùng cơ chế mới (bỏ nhắc manifest/state.json/dryrun).

## 4. Danh sách thay đổi file

### Xoá
- `aitoolkit/workflows/_dryrun.manifest.yaml`
- `aitoolkit/workflows/migration.manifest.yaml`
- `aitoolkit/workflows/feature.manifest.yaml`
- `aitoolkit/workflows/bugfix.manifest.yaml`
- `aitoolkit/skills/_stub/echo-step/SKILL.md`
- `aitoolkit/skills/_stub/fail-step/SKILL.md`
- `aitoolkit/docs/DRY-RUN.md`

### Viết lại (điều phối → orchestrator prose)
- `aitoolkit/commands/migrate.md` — orchestrator 10 bước (migration).
- `aitoolkit/commands/feature.md` — orchestrator 9 bước (feature).
- `aitoolkit/commands/bugfix.md` — orchestrator 9 bước (bugfix).

### Sửa (cắt phần engine, giữ phần còn dùng)
- `aitoolkit/skills/aitoolkit-schemas/SKILL.md` — **bỏ** mục "2. Manifest YAML" và "3. state.json"; **giữ** mục "1. Artifact front-matter" (sửa lại: input bước trước = path orchestrator truyền, không qua state.json) và "4. Project profile". Cập nhật `description` frontmatter.
- Mọi `aitoolkit/skills/**/SKILL.md` step-skill — bỏ khung "conductor/state_id/state.json", theo §3.3. (16 skill: migration×4, feature×3, bugfix×3, shared×6 — trừ `aitoolkit-schemas`; `lge-rules` chỉ chỉnh nếu có nhắc engine.)
- `aitoolkit/codex/skills/aitoolkit/SKILL.md`, `aitoolkit/codex/AGENTS.snippet.md`, `aitoolkit/codex/CODEX-SETUP-PROMPT.md` — bỏ nhắc manifest/state.json/dryrun.
- `aitoolkit/README.md`, `aitoolkit/CONTRIBUTING.md`, `aitoolkit/docs/RUN-ON-CODEX.md` — cập nhật mô tả cơ chế (bỏ dryrun/manifest/state.json).

### Không đụng
- `aitoolkit/templates/*` — nội dung artifact không đổi.
- `aitoolkit/skills/lge-rules/SKILL.md` — trừ khi có nhắc engine.

## 5. Rủi ro & Đánh đổi (đã chấp nhận)

- **Mất resume máy-đọc:** chấp nhận — run một-buổi. Nếu gián đoạn, đọc lại artifact đã ghi trong `run-<id>/` để tiếp.
- **Gate từ engine-ép → model-tuân-thủ:** giảm nhẹ độ chắc. Bù bằng ngôn ngữ HARD-GATE mạnh (kiểu Superpowers) cho Gerrit/Release, và `AskUserQuestion` bắt buộc ở mọi gate.
- **Mất `--disable`:** thay bằng orchestrator hỏi optional / người dùng nói bỏ.

## 6. Kiểm thử / nghiệm thu

Vì bỏ `_dryrun` engine-test, nghiệm thu chuyển sang **chạy thật một pipeline nhỏ** và quan sát:
- `/migrate` (hoặc `/feature`, `/bugfix`) chạy tuần tự đủ các step-skill thật.
- Dừng đúng ở mỗi gate, hỏi đúng câu, không tự vượt HARD gate.
- Từ chối một gate → chạy lại đúng bước đó kèm feedback, bước đã duyệt không đổi.
- Bước optional bỏ được khi người dùng yêu cầu.
- Artifact ghi đúng vào `run-<id>/`, front-matter `draft→approved`.
- Không còn tham chiếu `state.json`/`manifest.yaml`/`dryrun`/`_stub` nào trong code hay tài liệu.

# AIToolKit Core Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Xây lõi engine của AIToolKit — một Claude Code plugin thuần-prompt điều phối pipeline SDLC qua manifest khai báo, human gate, và state.json/resume — chứng minh bằng dry-run với step-skill giả (stub), chưa cần logic migration thật.

**Architecture:** Điều phối bằng prompt + file (không engine chạy nền), giống superpowers. Một slash command `/migrate` (CONDUCTOR) đọc một manifest YAML, chạy lần lượt các step-skill, ghi artifact `.md` + `state.json`, dừng ở human gate. Cờ `isolate` quyết định bọc step vào subagent. Toàn bộ là markdown + YAML; "test" = checklist review + kịch bản dry-run thật quan sát hành vi.

**Tech Stack:** Claude Code plugin (`.claude-plugin/plugin.json`, `commands/*.md`, `skills/<name>/SKILL.md`), YAML manifest, JSON state. Phụ thuộc chọn lọc superpowers cho cơ chế (`dispatching-parallel-agents`). Không có script/ngôn ngữ lập trình.

## Global Constraints

- **Thuần prompt:** không viết script hay code ngôn ngữ nào (Python/Node...). Chỉ markdown + YAML + JSON. Nguồn: spec §2.1, quyết định "Thuần prompt (như superpowers)".
- **Hai seam bất biến:** (1) step chỉ giao tiếp qua artifact `.md` chuẩn hoá; (2) pipeline khai báo trong manifest, conductor & step KHÔNG gọi thẳng nhau. Nguồn: spec §2.2.
- **Gate khai báo theo bước:** mặc định bật; `gate: none` cho KB; `type: hard` cho Gerrit/Release; `optional: true` cho CCC/Release. HARD gate KHÔNG BAO GIỜ tự động vượt qua. Nguồn: spec §2.4, §5.
- **Phụ thuộc lai:** dùng superpowers cho cơ chế subagent/worktree; nghiệp vụ LGE tự chứa. Nguồn: spec §3.
- **Artifact chạy thật:** đặt trong `<project>/.aitoolkit/run-<id>/`. Nguồn: spec §4.
- **Thư mục plugin gốc:** `aitoolkit/` tại repo root. Skill đặt tại `aitoolkit/skills/<name>/SKILL.md`, frontmatter bắt buộc `name` + `description`.
- **Phạm vi Plan 1:** chỉ lõi engine + stub. Step-skill migration thật thuộc Plan 2. Nguồn: spec §10.

---

### Task 1: Plugin scaffold + cấu trúc thư mục

**Files:**
- Create: `aitoolkit/.claude-plugin/plugin.json`
- Create: `aitoolkit/README.md`
- Create: `aitoolkit/.gitignore`

**Interfaces:**
- Consumes: (không có — task đầu)
- Produces: cây thư mục plugin `aitoolkit/` với `commands/`, `skills/`, `workflows/`, `templates/`, `docs/`; `plugin.json` hợp lệ khai báo `name: "aitoolkit"`, `skills: "./skills/"`.

- [ ] **Step 1: Tạo `plugin.json`**

```json
{
  "name": "aitoolkit",
  "description": "Agentic SDLC kit cho dự án LGE — điều phối pipeline migration/bugfix/feature bằng manifest khai báo, human gate, và knowledge base. Thuần prompt, chạy trên nền Claude Code.",
  "version": "0.1.0",
  "author": { "name": "LGE Team" },
  "license": "MIT",
  "keywords": ["sdlc", "migration", "flutter", "webos", "agentic", "workflow", "lge"],
  "skills": "./skills/"
}
```

- [ ] **Step 2: Tạo cây thư mục rỗng bằng `.gitkeep`**

Tạo các thư mục (mỗi thư mục 1 file `.gitkeep` rỗng để git giữ):
`aitoolkit/commands/`, `aitoolkit/skills/`, `aitoolkit/workflows/`, `aitoolkit/templates/`, `aitoolkit/docs/`

- [ ] **Step 3: Tạo `README.md`**

Nội dung tối thiểu (điền thật, không placeholder):

```markdown
# AIToolKit — Agentic SDLC Kit

Bộ kit điều phối quy trình phát triển phần mềm bằng AI cho dự án LGE, dạng Claude Code plugin thuần-prompt.

## Cài đặt
Thêm `aitoolkit/` vào danh sách plugin của Claude Code (marketplace nội bộ hoặc symlink vào `~/.claude/plugins`).

## Dùng nhanh
- `/migrate <workflow>` — chạy một pipeline theo manifest trong `workflows/<workflow>.manifest.yaml`.
- `/migrate --resume run-<id>` — chạy tiếp một run đang dở.
- `/migrate <workflow> --disable <step-id>` — tắt một bước optional (vd CCC).

Artifact mỗi lần chạy nằm ở `<project>/.aitoolkit/run-<id>/`.

## Kiến trúc
Xem `docs/superpowers/specs/2026-08-06-aitoolkit-agentic-sdlc-design.md`.
```

- [ ] **Step 4: Verify (review checklist)**

Kiểm tra:
- `plugin.json` là JSON hợp lệ: `cat aitoolkit/.claude-plugin/plugin.json | python3 -m json.tool` chạy không lỗi.
- Đủ 5 thư mục con: `ls -d aitoolkit/*/` liệt kê `commands skills workflows templates docs`.
- Không có file code (`.py`/`.js`/`.ts`) nào: `find aitoolkit -name '*.py' -o -name '*.js' -o -name '*.ts'` rỗng.

- [ ] **Step 5: Commit**

```bash
git add aitoolkit/
git commit -m "feat(aitoolkit): plugin scaffold + directory structure"
```

---

### Task 2: Contracts — artifact schema, manifest schema, state.json schema

**Files:**
- Create: `aitoolkit/skills/aitoolkit-schemas/SKILL.md`

**Interfaces:**
- Consumes: cây thư mục từ Task 1.
- Produces: 3 hợp đồng dữ liệu mà conductor và mọi step dựa vào:
  - **Artifact `.md`**: front-matter `step_id`, `run_id`, `status: draft|approved`, `produced_at`; thân theo template của bước.
  - **Manifest YAML**: `workflow` (string); `steps[]` mỗi phần tử `{ id, skill, isolate: bool, optional: bool (mặc định false), gate }` với `gate` = `none` | `{ type: soft|hard, approver, prompt }`.
  - **state.json**: `{ run_id, workflow, project_root, disabled_steps[], steps: { <id>: { status: pending|running|awaiting_gate|approved|rejected|failed|skipped, artifact_path, gate_status } }, current_step }`.

- [ ] **Step 1: Viết `SKILL.md`** (frontmatter + 3 hợp đồng, nội dung thật)

````markdown
---
name: aitoolkit-schemas
description: Hợp đồng dữ liệu của AIToolKit — cấu trúc artifact .md, manifest YAML, và state.json. Conductor và mọi step-skill PHẢI đọc skill này để đọc/ghi đúng định dạng.
---

# AIToolKit — Data Contracts

Ba định dạng dưới đây là "seam" giữa các thành phần. KHÔNG thành phần nào được phá vỡ chúng.

## 1. Artifact `.md`

Mỗi bước ghi đúng MỘT file artifact. Front-matter YAML bắt buộc:

```yaml
---
step_id: 01-discovery      # khớp id trong manifest
run_id: run-20260806-01
status: draft              # draft khi vừa sinh; approved sau khi qua gate
produced_at: 2026-08-06
---
```
Thân file theo template của bước (Plan 2 định nghĩa từng template).

## 2. Manifest YAML (`workflows/<name>.manifest.yaml`)

```yaml
workflow: <string>          # tên workflow, vd "migration"
steps:                      # thứ tự trong mảng = thứ tự chạy
  - id: <string>            # duy nhất trong manifest, vd "01-discovery"
    skill: <string>         # đường dẫn skill, vd "migration/discovery"
    isolate: <bool>         # true → conductor bọc subagent; false → chạy inline
    optional: <bool>        # (mặc định false) true → có thể tắt qua --disable
    gate: none | { type: soft|hard, approver: <string>, prompt: <string> }
```
Ràng buộc: `id` duy nhất; `skill` phải tồn tại; `gate.type` chỉ `soft`/`hard`; HARD gate không được tự động vượt.

## 3. state.json (`<project>/.aitoolkit/run-<id>/state.json`)

```json
{
  "run_id": "run-20260806-01",
  "workflow": "migration",
  "project_root": "/abs/path",
  "disabled_steps": ["08-ccc-automation", "09-release"],
  "current_step": "03-technical-design",
  "steps": {
    "01-discovery":       { "status": "approved",      "artifact_path": "01-discovery.md", "gate_status": "approved" },
    "02-feature-mapping": { "status": "approved",      "artifact_path": "02-mapping.md",   "gate_status": "approved" },
    "03-technical-design":{ "status": "awaiting_gate", "artifact_path": "03-tech-design.md","gate_status": "pending" }
  }
}
```
`status` hợp lệ: `pending | running | awaiting_gate | approved | rejected | failed | skipped`.
`gate_status`: `n/a | pending | approved | rejected`.
````

- [ ] **Step 2: Verify (review checklist chống spec §5/§6/§7)**

Đối chiếu từng dòng:
- [ ] Artifact có đủ `step_id, run_id, status, produced_at`.
- [ ] Manifest có đủ `id, skill, isolate, optional, gate`; `gate` hỗ trợ cả `none` và `{type,approver,prompt}`.
- [ ] state.json có đủ `run_id, workflow, project_root, disabled_steps, current_step, steps{}`; tập `status` khớp spec §7.
- [ ] Không mâu thuẫn tên trường với spec §5 (ví dụ manifest §5 dùng `isolate`, `optional`, `gate.type` — khớp).

- [ ] **Step 3: Commit**

```bash
git add aitoolkit/skills/aitoolkit-schemas/
git commit -m "feat(aitoolkit): data contracts — artifact/manifest/state schemas"
```

---

### Task 3: Stub step-skills + dry-run manifest

Mục tiêu: có "quân xanh" để chạy engine end-to-end mà không cần logic migration thật. Stub chỉ ghi một artifact mẫu cố định.

**Files:**
- Create: `aitoolkit/skills/_stub/echo-step/SKILL.md`
- Create: `aitoolkit/skills/_stub/fail-step/SKILL.md`
- Create: `aitoolkit/workflows/_dryrun.manifest.yaml`

**Interfaces:**
- Consumes: hợp đồng từ Task 2.
- Produces: manifest `_dryrun` với 5 bước phủ mọi nhánh engine: soft gate, hard gate, isolate, optional, no-gate; và 2 stub skill (`echo-step` ghi artifact thành công, `fail-step` cố tình báo lỗi để test error/resume).

- [ ] **Step 1: Viết `echo-step/SKILL.md`**

````markdown
---
name: echo-step
description: (Chỉ dùng cho dry-run) Ghi một artifact mẫu theo aitoolkit-schemas. Đọc artifact bước trước nếu có, không xử lý gì thật.
---

# Stub: echo-step

Khi được conductor gọi với `step_id`, `run_id`, `run_dir`:
1. Đọc `aitoolkit-schemas` để biết front-matter chuẩn.
2. Nếu bước trước có artifact trong `run_dir`, đọc và ghi 1 dòng "consumed: <tên file>".
3. Ghi file `<run_dir>/<step_id>.md` với front-matter hợp lệ (`status: draft`) và thân:
   ```
   # Stub artifact for <step_id>
   consumed: <tên artifact bước trước hoặc "none">
   ```
4. Trả về đường dẫn artifact vừa ghi.
````

- [ ] **Step 2: Viết `fail-step/SKILL.md`**

````markdown
---
name: fail-step
description: (Chỉ dùng cho dry-run) Cố tình dừng và báo lỗi để kiểm tra xử lý lỗi & resume của conductor. KHÔNG ghi artifact.
---

# Stub: fail-step

Khi được gọi: KHÔNG ghi artifact. Báo cho conductor: "STEP FAILED: fail-step mô phỏng lỗi." rồi dừng, để conductor đánh dấu `status: failed` và giữ nguyên state.
````

- [ ] **Step 3: Viết `_dryrun.manifest.yaml`**

```yaml
workflow: _dryrun
steps:
  - id: s1-soft
    skill: _stub/echo-step
    isolate: false
    gate: { type: soft, approver: "Tester", prompt: "Duyệt s1?" }
  - id: s2-isolate
    skill: _stub/echo-step
    isolate: true
    gate: { type: soft, approver: "Tester", prompt: "Duyệt s2 (isolate)?" }
  - id: s3-optional
    skill: _stub/echo-step
    isolate: false
    optional: true
    gate: { type: soft, approver: "Tester", prompt: "Duyệt s3 (optional)?" }
  - id: s4-hard
    skill: _stub/echo-step
    isolate: false
    gate: { type: hard, approver: "Tester", prompt: "HARD: xác nhận s4?" }
  - id: s5-nogate
    skill: _stub/echo-step
    isolate: false
    gate: none
```

- [ ] **Step 4: Verify (manifest hợp lệ theo Task 2)**

- [ ] Mọi `id` duy nhất; mọi `skill` trỏ tới skill tồn tại (`_stub/echo-step`, `_stub/fail-step`).
- [ ] Có đủ 5 nhánh: soft (`s1`), isolate (`s2`), optional (`s3`), hard (`s4`), no-gate (`s5`).
- [ ] `python3 -c "import yaml,sys; yaml.safe_load(open('aitoolkit/workflows/_dryrun.manifest.yaml'))"` chạy không lỗi (chỉ để kiểm YAML hợp lệ, không phải code của kit).

- [ ] **Step 5: Commit**

```bash
git add aitoolkit/skills/_stub/ aitoolkit/workflows/_dryrun.manifest.yaml
git commit -m "feat(aitoolkit): stub steps + dry-run manifest for engine testing"
```

---

### Task 4: Conductor — happy path (chạy tuần tự + artifact + state.json + soft gate)

**Files:**
- Create: `aitoolkit/commands/migrate.md`

**Interfaces:**
- Consumes: `aitoolkit-schemas` (Task 2), manifest `_dryrun` + stub (Task 3).
- Produces: slash command `/migrate <workflow>` thực hiện: sinh `run_id`, tạo `run_dir`, đọc manifest, chạy tuần tự từng bước (gọi skill), ghi artifact + cập nhật `state.json`, và DỪNG ở soft gate đầu tiên trình artifact cho người duyệt. (Optional/hard/isolate/resume để Task 5–6.)

- [ ] **Step 1: Viết `commands/migrate.md`** (phần happy path, nội dung thật)

````markdown
---
description: Chạy một pipeline SDLC của AIToolKit theo manifest khai báo (CONDUCTOR).
argument-hint: <workflow> [--resume run-<id>] [--disable <step-id>]
---

# /migrate — AIToolKit Conductor

Bạn là **nhạc trưởng**. Luôn chạy inline (cùng context với người dùng). Đọc `aitoolkit-schemas` trước tiên để biết định dạng manifest/artifact/state.

## Tham số
- `$1` = tên workflow → đọc `aitoolkit/workflows/$1.manifest.yaml`.
- `--resume run-<id>` → (Task 6).
- `--disable <step-id>` → (Task 5).

## Khởi tạo run (khi KHÔNG --resume)
1. Sinh `run_id` = `run-<YYYYMMDD>-<NN>` (NN = số thứ tự trong ngày, dò `<project>/.aitoolkit/`).
2. Tạo `run_dir = <project>/.aitoolkit/<run_id>/`.
3. Đọc manifest. Nếu thiếu file/không hợp lệ theo `aitoolkit-schemas` → báo lỗi rõ và dừng.
4. Ghi `state.json` ban đầu: mọi bước `status: pending`, `current_step` = bước đầu.

## Vòng lặp chạy bước
Với mỗi bước theo thứ tự trong manifest:
1. Cập nhật `state.json`: bước → `running`, `current_step` = bước này.
2. Gọi skill của bước (Task 4 chỉ xử lý `isolate: false` — chạy inline). Truyền `step_id`, `run_id`, `run_dir`.
3. Nhận đường dẫn artifact; cập nhật bước → `awaiting_gate` (nếu có gate) hoặc `approved` (nếu `gate: none`), ghi `artifact_path`.
4. **Nếu bước có `gate`:** DỪNG. Trình tóm tắt + đường dẫn artifact cho người dùng; hỏi đúng câu `gate.prompt`. Chờ phản hồi:
   - Duyệt → đặt `gate_status: approved`, `status: approved`, artifact front-matter `status: approved`; đi tiếp.
   - (Từ chối → Task 6.)
5. Sau bước cuối: báo hoàn tất.

## Nguyên tắc
- KHÔNG bao giờ bỏ qua gate mà không hỏi.
- Mọi thay đổi trạng thái đều ghi ngay vào `state.json` (để resume được).
- Conductor chỉ biết manifest + artifact; không nhúng logic của bất kỳ bước nào.
````

- [ ] **Step 2: Định nghĩa kịch bản dry-run A (happy path)**

Ghi tạm ra scratchpad để chạy: trong một repo mẫu rỗng, chạy `/migrate _dryrun`.
**Kỳ vọng quan sát được:**
- Tạo `<repo>/.aitoolkit/run-<...>/` và `state.json`.
- Bước `s1-soft` chạy → có `run-.../s1-soft.md` (front-matter hợp lệ, `status: draft`).
- Conductor DỪNG, hỏi đúng "Duyệt s1?" — CHƯA chạy `s2`.

- [ ] **Step 3: Chạy dry-run A và quan sát**

Chạy `/migrate _dryrun` trên repo mẫu. Xác nhận đúng 3 kỳ vọng trên. Nếu sai, sửa `migrate.md` cho tới khi khớp.

- [ ] **Step 4: Verify (bằng chứng)**

- [ ] `cat <repo>/.aitoolkit/run-*/state.json` cho thấy `s1-soft: awaiting_gate`, phần còn lại `pending`.
- [ ] `s1-soft.md` tồn tại, front-matter đủ trường.
- [ ] Conductor không tự ý chạy `s2`.

- [ ] **Step 5: Commit**

```bash
git add aitoolkit/commands/migrate.md
git commit -m "feat(aitoolkit): conductor happy path — sequential run, artifacts, state, soft gate"
```

---

### Task 5: Conductor — optional toggle, HARD gate, isolate dispatch

**Files:**
- Modify: `aitoolkit/commands/migrate.md`

**Interfaces:**
- Consumes: conductor happy-path (Task 4).
- Produces: conductor xử lý thêm: `--disable <step-id>` bỏ bước optional (→ `status: skipped`); HARD gate yêu cầu xác nhận tường minh và KHÔNG BAO GIỜ tự vượt; `isolate: true` → bọc bước vào subagent qua `superpowers:dispatching-parallel-agents`, nhận lại đường dẫn artifact.

- [ ] **Step 1: Bổ sung xử lý `--disable` + optional vào `migrate.md`**

Thêm mục sau vào phần "Khởi tạo run" và "Vòng lặp":

````markdown
## Bước optional & --disable
- Gom mọi `--disable <step-id>` vào `disabled_steps` trong state.json.
- Trong vòng lặp, nếu bước có `optional: true` VÀ nằm trong `disabled_steps`: đặt `status: skipped`, KHÔNG gọi skill, KHÔNG hỏi gate, ghi log "skipped (disabled)", đi tiếp.
- Từ chối `--disable` cho bước không `optional: true` → báo lỗi và dừng (không cho tắt bước bắt buộc).
````

- [ ] **Step 2: Bổ sung xử lý HARD gate**

````markdown
## HARD gate
Với `gate.type: hard`: trình artifact, cảnh báo "Hành động KHÔNG THỂ đảo ngược", hỏi `gate.prompt`.
- Chỉ đi tiếp khi người dùng xác nhận tường minh (gõ đúng yêu cầu, không phải "ok" mơ hồ).
- KHÔNG BAO GIỜ tự động vượt HARD gate kể cả khi chạy liên tục/resume.
````

- [ ] **Step 3: Bổ sung dispatch `isolate`**

````markdown
## isolate: true → subagent
Với bước `isolate: true`: thay vì chạy inline, dùng superpowers:dispatching-parallel-agents để spawn MỘT subagent chạy skill của bước, truyền `step_id/run_id/run_dir` và chỉ thị "ghi artifact rồi trả về đường dẫn". Conductor chỉ nhận lại đường dẫn artifact + trạng thái, không mang theo lý luận trung gian. Sau đó xử lý gate như thường.
````

- [ ] **Step 4: Kịch bản dry-run B + chạy**

Chạy `/migrate _dryrun --disable s3-optional` trên repo mẫu, duyệt lần lượt tới cuối.
**Kỳ vọng:**
- `s2-isolate` được chạy qua subagent (quan sát thấy dispatch), vẫn ra `s2-isolate.md`.
- `s3-optional` → `status: skipped`, KHÔNG có `s3-optional.md`, KHÔNG hỏi gate.
- `s4-hard` → hỏi xác nhận HARD, chỉ đi tiếp khi xác nhận tường minh.
- `s5-nogate` → chạy, KHÔNG hỏi gate.

- [ ] **Step 5: Verify (bằng chứng)**

- [ ] `state.json`: `s3-optional.status == "skipped"`, không có file `s3-optional.md`.
- [ ] Thử tắt bước bắt buộc `/migrate _dryrun --disable s1-soft` → conductor báo lỗi, không chạy.
- [ ] Log/hội thoại cho thấy `s2-isolate` chạy qua subagent, `s4-hard` chặn tới khi xác nhận.

- [ ] **Step 6: Commit**

```bash
git add aitoolkit/commands/migrate.md
git commit -m "feat(aitoolkit): conductor — optional toggle, hard gate, isolate dispatch"
```

---

### Task 6: Conductor — resume, gate rejection re-run, error handling

**Files:**
- Modify: `aitoolkit/commands/migrate.md`

**Interfaces:**
- Consumes: conductor (Task 5).
- Produces: `--resume run-<id>` đọc `state.json`, chạy tiếp từ bước chưa xong; từ chối gate (kèm feedback) → chạy lại đúng bước đó với feedback, không làm lại từ đầu; step báo lỗi → `status: failed`, giữ nguyên state, cho resume.

- [ ] **Step 1: Bổ sung `--resume` vào `migrate.md`**

````markdown
## Resume (`--resume run-<id>`)
1. Đọc `<project>/.aitoolkit/run-<id>/state.json`. Thiếu → báo lỗi, dừng.
2. Bỏ qua mọi bước `status: approved` hoặc `skipped` (KHÔNG chạy lại — artifact đã duyệt giữ nguyên).
3. Tiếp tục từ bước đầu tiên có `status ∈ {pending, running, failed, awaiting_gate, rejected}`:
   - `failed`/`running` → chạy lại bước đó từ đầu.
   - `awaiting_gate` → trình lại artifact hiện có, hỏi lại gate.
   - `rejected` → chạy lại kèm feedback đã lưu.
4. HARD gate vẫn phải hỏi lại, không tự vượt.
````

- [ ] **Step 2: Bổ sung xử lý từ chối gate**

````markdown
## Từ chối gate
Khi người dùng từ chối tại gate: lưu feedback vào state.json (`steps.<id>.feedback`), đặt `status: rejected`, `gate_status: rejected`. Chạy LẠI đúng bước đó, truyền feedback cho skill để sửa artifact. KHÔNG đụng các bước đã approved trước đó. Lặp cho tới khi được duyệt.
````

- [ ] **Step 3: Bổ sung xử lý lỗi step**

````markdown
## Lỗi step
Nếu skill báo lỗi/không trả artifact: đặt `status: failed`, ghi lý do vào state.json, DỪNG và báo người dùng cách resume: `/migrate --resume <run-id>`. KHÔNG chạy các bước sau.
````

- [ ] **Step 4: Kịch bản dry-run C + chạy**

Ba mini-kịch bản trên repo mẫu:
1. **Resume:** chạy `/migrate _dryrun`, duyệt `s1`, dừng ở gate `s2`. Bắt đầu phiên mới `/migrate --resume run-<id>` → tiếp tục từ `s2`, KHÔNG chạy lại `s1`.
2. **Từ chối gate:** tại gate `s1`, từ chối kèm feedback "đổi tiêu đề" → `s1` chạy lại, `s1-soft.md` cập nhật, các bước sau vẫn `pending`.
3. **Lỗi step:** tạm đổi `s5-nogate.skill` thành `_stub/fail-step` (hoặc thêm bước fail) → chạy tới đó thấy `status: failed`, state giữ nguyên, resume được.

- [ ] **Step 5: Verify (bằng chứng)**

- [ ] Sau resume, `s1-soft.status` vẫn `approved` và artifact không đổi mtime (không chạy lại).
- [ ] Sau từ chối, `s1-soft.md` thay đổi nội dung, `state.json` có `feedback`.
- [ ] Khi step lỗi, `state.json` có `status: failed` + lý do; `/migrate --resume` chạy tiếp được.

- [ ] **Step 6: Commit**

```bash
git add aitoolkit/commands/migrate.md
git commit -m "feat(aitoolkit): conductor — resume, gate rejection re-run, error handling"
```

---

### Task 7: Integration dry-run walkthrough + usage docs

**Files:**
- Create: `aitoolkit/docs/DRY-RUN.md`
- Modify: `aitoolkit/README.md`

**Interfaces:**
- Consumes: conductor hoàn chỉnh (Task 4–6).
- Produces: tài liệu kịch bản dry-run đầy đủ đóng vai "integration test sống"; README bổ sung mục cách chạy & sơ đồ pipeline.

- [ ] **Step 1: Viết `docs/DRY-RUN.md`** — kịch bản end-to-end đầy đủ

Nội dung: hướng dẫn từng bước chạy `/migrate _dryrun` từ `s1`→`s5`, kèm bảng "hành động → kỳ vọng quan sát" gộp cả 3 dry-run A/B/C ở Task 4–6 (happy path, optional/hard/isolate, resume/reject/fail). Đây là bài kiểm tra hồi quy thủ công cho engine.

- [ ] **Step 2: Chạy full walkthrough một lượt**

Theo `DRY-RUN.md` chạy trọn `_dryrun` (gồm nhánh `--disable s3-optional`). Mọi kỳ vọng phải khớp. Ghi lại kết quả vào cuối `DRY-RUN.md` (mục "Kết quả lần chạy gần nhất").

- [ ] **Step 3: Bổ sung README** — thêm sơ đồ 10 bước migration (tham chiếu spec §5) và ví dụ `--disable 08-ccc-automation 09-release` cho nhu cầu "chỉ Gerrit rồi KB".

- [ ] **Step 4: Verify**

- [ ] Chạy theo `DRY-RUN.md` không lệch kỳ vọng nào.
- [ ] README có mục cách chạy + ví dụ tắt CCC.

- [ ] **Step 5: Commit**

```bash
git add aitoolkit/docs/DRY-RUN.md aitoolkit/README.md
git commit -m "docs(aitoolkit): integration dry-run walkthrough + usage guide"
```

---

## Self-Review

**1. Spec coverage (đối chiếu spec):**
- §2 nguyên tắc → Global Constraints + Task 2 (seam), Task 4–6 (gate/state). ✅
- §3 quan hệ lai SP → Task 5 dùng `dispatching-parallel-agents`. ✅ (các skill SP khác thuộc Plan 2.)
- §4 kiến trúc/thư mục → Task 1. ✅
- §5 manifest 10 bước → schema ở Task 2; manifest migration THẬT thuộc Plan 2 (Plan 1 dùng `_dryrun`). Ghi rõ ở phạm vi. ✅
- §6 data flow → Task 4 vòng lặp. ✅
- §7 lỗi & resume → Task 6. ✅
- §8 mở rộng → ngoài phạm vi Plan 1 (seam đã có nhờ Task 2). ✅
- §9 kiểm thử → dry-run A/B/C + Task 7. ✅
- §10 phạm vi → khớp: Plan 1 = lõi + stub. ✅

**2. Placeholder scan:** không có TBD/TODO; mọi artifact có nội dung thật (plugin.json, schema, stub, manifest, conductor prompt, dry-run scenario). ✅

**3. Type/tên nhất quán:** trường `status/gate_status/isolate/optional/gate.type`, đường dẫn `run_dir`, `run_id`, tên bước `s1-soft..s5-nogate`, skill `_stub/echo-step`/`_stub/fail-step` — dùng nhất quán xuyên Task 2→7. ✅

**Ghi chú bàn giao:** Plan 2 (step-skill migration thật + lge-rules) sẽ thay `_dryrun.manifest.yaml` bằng `migration.manifest.yaml` và cắm skill thật vào đúng engine này — không sửa conductor.

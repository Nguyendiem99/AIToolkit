# AIToolKit → Cơ chế thuần Superpowers — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Thay động cơ điều phối YAML+conductor+state.json của AIToolKit bằng orchestrator skill viết văn xuôi (kiểu superpowers `executing-plans`), xoá dryrun/stub.

**Architecture:** 3 orchestrator skill mới (`skills/aitoolkit/{migrate,feature,bugfix}`) chứa bảng bước + giao thức chạy/gate; command rút thành launcher gọi skill; step-skill giữ nội dung nghiệp vụ, chỉ bỏ khung conductor/state.json; artifact ghi vào `docs/aitoolkit/<date>-<workflow>-<slug>/`; tiến độ qua TodoWrite.

**Tech Stack:** Claude Code plugin thuần-prompt (Markdown `SKILL.md`, slash command `.md`). KHÔNG script/runtime, KHÔNG unit test — "test" = grep xác nhận cấu trúc + không còn tham chiếu engine.

## Global Constraints

- Ngôn ngữ tài liệu: tiếng Việt, giữ giọng văn hiện có của repo.
- KHÔNG đổi nội dung `aitoolkit/templates/*` và logic nghiệp vụ từng bước — đây là refactor tầng điều phối.
- Token cấm sau khi xong (không còn xuất hiện trong `aitoolkit/`, trừ file lịch sử trong `docs/superpowers/`): `state.json`, `manifest`, `_dryrun`, `_stub`, `run_id`, `run-<id>`, `.aitoolkit/`, `--resume`, `--disable`, `isolate`, `conductor`.
- Artifact run-dir chuẩn: `<project>/docs/aitoolkit/<YYYY-MM-DD>-<workflow>-<slug>/`. Tên file artifact từng bước GIỮ NGUYÊN (`01-discovery.md`, `review-report.md`, …).
- HARD gate (Gerrit, Release) không bao giờ tự vượt — phải xác nhận tường minh.
- Mỗi task kết thúc bằng một commit riêng.

---

### Task 1: Orchestrator skill `migrate` (bản mẫu chuẩn)

**Files:**
- Create: `aitoolkit/skills/aitoolkit/migrate/SKILL.md`

**Interfaces:**
- Produces: giao thức chạy bước + gate mà Task 2 (feature/bugfix) tái dùng nguyên văn; chỉ khác Bảng bước.

- [ ] **Step 1: Tạo file orchestrator migrate với nội dung sau**

````markdown
---
name: migrate
description: Orchestrator pipeline migration của AIToolKit (10 bước discovery→mapping→tech-design→code-migration→review→test→gerrit→CCC→release→KB). Gọi step-skill tuần tự, dừng ở human gate. Kiểu Superpowers — không manifest/state.json.
---

# AIToolKit — Migration Orchestrator

Bạn là **orchestrator**, chạy inline (cùng context người dùng), điều phối pipeline SDLC bằng cách gọi lần lượt các step-skill theo Bảng bước dưới. KHÔNG có manifest/engine/state.json — cách chạy giống superpowers `executing-plans`.

Đọc skill `aitoolkit-schemas` TRƯỚC (front-matter artifact + project profile).

## Chuẩn bị run
1. Xác định `<slug>` = tên tính năng đang migrate (hỏi người dùng nếu chưa rõ); `<date>` = ngày hôm nay (YYYY-MM-DD).
2. `RUN_DIR = <project>/docs/aitoolkit/<date>-migration-<slug>/`. Tạo thư mục nếu chưa có.
3. Tạo todo list (TodoWrite): mỗi bước trong Bảng bước là một mục.

## Bảng bước (migration)
| # | skill | approver | gate | prompt |
|---|-------|----------|------|--------|
| 01 | migration/discovery       | PM/Client | soft | Xác nhận scope migration? |
| 02 | migration/feature-mapping | Client    | soft | Duyệt mapping & scope? |
| 03 | migration/technical-design| Tech Lead | soft | Duyệt thiết kế kỹ thuật? |
| 04 | migration/code-migration  | Developer | soft | Code chạy được, duyệt? |
| 05 | shared/ai-review          | Reviewer  | soft | Duyệt review? |
| 06 | shared/verification-testing| Dev/QA   | soft | Duyệt kết quả test? |
| 07 | shared/gerrit-automation  | Reviewer  | HARD | Xác nhận trước khi upload Gerrit? |
| 08 | shared/ccc-automation (optional) | PM/QA | soft | Duyệt CCC? |
| 09 | shared/release (optional) | PM        | HARD | Duyệt release? |
| 10 | shared/knowledge-base     | —         | none | — |

## Giao thức chạy mỗi bước
Với mỗi bước theo thứ tự Bảng bước:
1. TodoWrite bước → `in_progress`.
2. **Optional (08, 09):** nếu người dùng đã yêu cầu bỏ, hoặc bạn hỏi "Chạy bước này không?" và họ từ chối → todo `completed` ghi "skipped", bỏ qua, KHÔNG gọi skill.
3. Gọi step-skill (Skill tool, chạy inline). Truyền: `RUN_DIR`; đường dẫn artifact **bước ngay trước** (nếu có); input đặc thù (bước 01: đường dẫn source legacy + PRD/BRD nếu có). Skill làm việc và ghi artifact vào `RUN_DIR` với front-matter `status: draft` (tên file do skill quy định).
4. Trình cho người dùng: tóm tắt ngắn + đường dẫn artifact.
5. **Gate:**
   - `none` (10) → todo `completed`, xong.
   - `soft` → dùng AskUserQuestion (không có thì hỏi bằng text), lựa chọn rõ: **Duyệt** / **Từ chối + feedback**.
     - Duyệt → sửa front-matter artifact thành `status: approved`; todo `completed`; sang bước kế.
     - Từ chối → gọi LẠI đúng step-skill đó, truyền feedback để sửa artifact; lặp tới khi được duyệt. KHÔNG đụng bước đã duyệt.
   - `hard` (07, 09) → cảnh báo "Hành động KHÔNG THỂ đảo ngược", hỏi đúng prompt; **chỉ đi tiếp khi người dùng xác nhận tường minh** (gõ đúng yêu cầu, không nhận "ok" mơ hồ). KHÔNG BAO GIỜ tự vượt, kể cả khi chạy liên tục.
6. Sau bước 10: báo pipeline hoàn tất, liệt kê artifact trong `RUN_DIR`.

## Nguyên tắc
- Chỉ điều phối + gate; KHÔNG nhúng logic của bước (nằm trong step-skill).
- Bước lấy input bước trước từ đường dẫn bạn truyền vào — KHÔNG có state.json, KHÔNG hardcode tên file workflow khác.
- Mọi gate PHẢI hỏi người; không tự vượt, nhất là HARD gate.
- Nếu một step-skill báo lỗi/không ghi artifact: dừng, báo người dùng, giữ nguyên artifact đã có; chạy lại được bằng cách gọi lại orchestrator (đọc artifact `approved` trong RUN_DIR để biết đã tới đâu).
````

- [ ] **Step 2: Verify cấu trúc file**

Run: `cd aitoolkit && test -f skills/aitoolkit/migrate/SKILL.md && grep -c "Giao thức chạy mỗi bước" skills/aitoolkit/migrate/SKILL.md && ! grep -Eq "state\.json|manifest|isolate|run_id|conductor" skills/aitoolkit/migrate/SKILL.md && echo OK-CLEAN`
Expected: in `1`, rồi `OK-CLEAN` (file tồn tại, có giao thức, không còn token engine).

- [ ] **Step 3: Commit**

```bash
git add aitoolkit/skills/aitoolkit/migrate/SKILL.md
git commit -m "feat(aitoolkit): orchestrator skill migrate (thuần superpowers)"
```

---

### Task 2: Orchestrator skill `feature` + `bugfix`

**Files:**
- Create: `aitoolkit/skills/aitoolkit/feature/SKILL.md`
- Create: `aitoolkit/skills/aitoolkit/bugfix/SKILL.md`

**Interfaces:**
- Consumes: Giao thức chạy/gate từ Task 1 (sao nguyên văn, chỉ đổi Bảng bước + `<workflow>` trong RUN_DIR + description).

- [ ] **Step 1: Tạo `feature/SKILL.md`** — sao nguyên văn Task 1 với 3 khác biệt: (a) frontmatter dưới đây; (b) `RUN_DIR = …/<date>-feature-<slug>/`; (c) tiêu đề "Feature Orchestrator"; (d) thay Bảng bước bằng bảng feature; (e) input bước 01 = "mô tả tính năng do người dùng cung cấp".

```markdown
---
name: feature
description: Orchestrator pipeline tính năng mới của AIToolKit (9 bước requirements→design→implement→review→test→gerrit→CCC→release→KB). Gọi step-skill tuần tự, dừng ở human gate. Kiểu Superpowers — không manifest/state.json.
---
```

Bảng bước (feature):
```markdown
| # | skill | approver | gate | prompt |
|---|-------|----------|------|--------|
| 01 | feature/requirements       | PM/Client | soft | Duyệt yêu cầu tính năng? |
| 02 | feature/design             | Tech Lead | soft | Duyệt thiết kế kỹ thuật? |
| 03 | feature/implement          | Developer | soft | Hiện thực xong (test xanh), duyệt? |
| 04 | shared/ai-review           | Reviewer  | soft | Duyệt review? |
| 05 | shared/verification-testing| Dev/QA    | soft | Duyệt kết quả test? |
| 06 | shared/gerrit-automation   | Reviewer  | HARD | Xác nhận trước khi upload Gerrit? |
| 07 | shared/ccc-automation (optional) | PM/QA | soft | Duyệt CCC? |
| 08 | shared/release (optional)  | PM        | HARD | Duyệt release? |
| 09 | shared/knowledge-base      | —         | none | — |
```
(HARD gate ở 06 & 08; optional ở 07 & 08; none ở 09 — cập nhật số bước trong Giao thức cho khớp.)

- [ ] **Step 2: Tạo `bugfix/SKILL.md`** — sao nguyên văn với: frontmatter dưới đây; `RUN_DIR = …/<date>-bugfix-<slug>/`; tiêu đề "Bugfix Orchestrator"; Bảng bước bugfix; input bước 01 = "mô tả bug / link issue do người dùng cung cấp".

```markdown
---
name: bugfix
description: Orchestrator pipeline bugfix của AIToolKit (9 bước reproduce→root-cause→fix→review→test→gerrit→CCC→release→KB). Gọi step-skill tuần tự, dừng ở human gate. Kiểu Superpowers — không manifest/state.json.
---
```

Bảng bước (bugfix):
```markdown
| # | skill | approver | gate | prompt |
|---|-------|----------|------|--------|
| 01 | bugfix/reproduce           | Dev/QA    | soft | Xác nhận đã tái hiện bug? |
| 02 | bugfix/root-cause          | Tech Lead | soft | Duyệt nguyên nhân gốc? |
| 03 | bugfix/fix                 | Developer | soft | Fix xong (test xanh), duyệt? |
| 04 | shared/ai-review           | Reviewer  | soft | Duyệt review? |
| 05 | shared/verification-testing| Dev/QA    | soft | Duyệt kết quả test (không hồi quy)? |
| 06 | shared/gerrit-automation   | Reviewer  | HARD | Xác nhận trước khi upload Gerrit? |
| 07 | shared/ccc-automation (optional) | PM/QA | soft | Duyệt CCC? |
| 08 | shared/release (optional)  | PM        | HARD | Duyệt release? |
| 09 | shared/knowledge-base      | —         | none | — |
```

- [ ] **Step 3: Verify**

Run: `cd aitoolkit && for w in feature bugfix; do test -f skills/aitoolkit/$w/SKILL.md && ! grep -Eq "state\.json|manifest|isolate|run_id|conductor" skills/aitoolkit/$w/SKILL.md && echo "$w OK"; done`
Expected: `feature OK` và `bugfix OK`.

- [ ] **Step 4: Commit**

```bash
git add aitoolkit/skills/aitoolkit/feature/SKILL.md aitoolkit/skills/aitoolkit/bugfix/SKILL.md
git commit -m "feat(aitoolkit): orchestrator skill feature + bugfix"
```

---

### Task 3: Command → launcher mỏng (3 file)

**Files:**
- Modify: `aitoolkit/commands/migrate.md` (thay toàn bộ)
- Modify: `aitoolkit/commands/feature.md` (thay toàn bộ)
- Modify: `aitoolkit/commands/bugfix.md` (thay toàn bộ)

**Interfaces:**
- Consumes: orchestrator skill `aitoolkit/migrate|feature|bugfix` (Task 1, 2).

- [ ] **Step 1: Ghi đè `commands/migrate.md`**

```markdown
---
description: Chạy pipeline migration của AIToolKit (kiểu Superpowers).
argument-hint: "[tên-tính-năng]"
---

# /migrate — AIToolKit

Gọi skill **`aitoolkit/migrate`** và làm theo toàn bộ giao thức trong đó (chuẩn bị run, bảng bước, gate). Nếu `$ARGUMENTS` có nội dung, dùng làm `<slug>`/tên tính năng migrate; nếu trống, skill sẽ hỏi.
```

- [ ] **Step 2: Ghi đè `commands/feature.md`** — như trên, đổi mô tả "tính năng mới", gọi skill `aitoolkit/feature`.

```markdown
---
description: Chạy pipeline tính năng mới của AIToolKit (kiểu Superpowers).
argument-hint: "[tên-tính-năng]"
---

# /feature — AIToolKit

Gọi skill **`aitoolkit/feature`** và làm theo toàn bộ giao thức trong đó. `$ARGUMENTS` (nếu có) = tên tính năng/`<slug>`; trống thì skill sẽ hỏi.
```

- [ ] **Step 3: Ghi đè `commands/bugfix.md`** — gọi skill `aitoolkit/bugfix`.

```markdown
---
description: Chạy pipeline bugfix của AIToolKit (kiểu Superpowers).
argument-hint: "[mô-tả-bug]"
---

# /bugfix — AIToolKit

Gọi skill **`aitoolkit/bugfix`** và làm theo toàn bộ giao thức trong đó. `$ARGUMENTS` (nếu có) = mô tả bug/`<slug>`; trống thì skill sẽ hỏi.
```

- [ ] **Step 4: Verify**

Run: `cd aitoolkit && ! grep -REq "manifest|--resume|--disable|state\.json|conductor" commands/ && grep -l "aitoolkit/migrate" commands/migrate.md && echo OK`
Expected: in đường dẫn `commands/migrate.md` rồi `OK`.

- [ ] **Step 5: Commit**

```bash
git add aitoolkit/commands/
git commit -m "refactor(aitoolkit): command rút thành launcher gọi orchestrator skill"
```

---

### Task 4: Cập nhật `aitoolkit-schemas` (cắt engine)

**Files:**
- Modify: `aitoolkit/skills/aitoolkit-schemas/SKILL.md`

- [ ] **Step 1: Sửa frontmatter `description`** — thay chuỗi hiện tại thành:

```yaml
description: Hợp đồng dữ liệu của AIToolKit — cấu trúc artifact .md (front-matter) và project profile. Orchestrator và mọi step-skill PHẢI đọc skill này để đọc/ghi đúng định dạng.
```

- [ ] **Step 2: Xoá trọn mục "## 2. Manifest YAML (...)" và "## 3. state.json (...)"** (cả code block bên trong). Giữ mục 1 và 4, đánh số lại thành "## 2. Project profile".

- [ ] **Step 3: Sửa mục 1 (Artifact `.md`)** — bỏ dòng `run_id` trong ví dụ front-matter, và thay đoạn quy ước "thứ tự bước / state.json.steps[<prev_id>]" bằng:

```markdown
Front-matter YAML bắt buộc:

​```yaml
---
step_id: 01-discovery      # id bước (khớp Bảng bước của orchestrator)
status: draft              # draft khi vừa sinh; approved sau khi qua gate
produced_at: 2026-08-06
---
​```

**Đặt tên & input:**
- Bước đặc thù workflow (nửa đầu): tên theo bước, vd `01-discovery.md`, `03-fix.md`.
- Bước khung dùng chung (`shared/*`): tên theo vai trò, ổn định qua mọi workflow — `review-report.md`, `verification-report.md`, `gerrit-report.md`, `ccc-package.md`, `release-report.md`, `kb-entry.md`.
- Mọi artifact ghi vào **RUN_DIR** do orchestrator truyền (`<project>/docs/aitoolkit/<date>-<workflow>-<slug>/`).
- **Input bước trước = đường dẫn artifact orchestrator truyền vào**, KHÔNG tra state.json, KHÔNG hardcode tên file workflow khác.
```

- [ ] **Step 4: Verify**

Run: `cd aitoolkit && ! grep -Eq "state\.json|Manifest YAML|run_id|current_step" skills/aitoolkit-schemas/SKILL.md && grep -q "Project profile" skills/aitoolkit-schemas/SKILL.md && echo OK`
Expected: `OK` (không còn manifest/state.json/run_id, vẫn còn project profile).

- [ ] **Step 5: Commit**

```bash
git add aitoolkit/skills/aitoolkit-schemas/SKILL.md
git commit -m "refactor(aitoolkit): schemas bỏ manifest+state.json, giữ artifact front-matter + profile"
```

---

### Framing transform rules (dùng cho Task 5–7)

Áp cho phần **khung giao tiếp** đầu/cuối mỗi step-skill (KHÔNG đụng phần "Việc cần làm"/template):

- **R1 — dòng mở đầu:** mọi câu dạng `Conductor gọi với step_id[=..], run_id, run_dir[, ...]. [Chạy INLINE][Bước nặng → subagent/isolate]` → đổi thành `Orchestrator gọi skill này, truyền: run_dir + đường dẫn artifact bước trước[ + <input đặc thù giữ nguyên>]. Chạy inline.` (bỏ `run_id`, bỏ mọi nhắc `isolate`/`subagent`/`manifest`).
- **R2 — "conductor dừng ở gate ..."** → `orchestrator dừng ở gate ...` (giữ vai trò approver).
- **R3 — cuối bước:** `... status: draft. Trả về đường dẫn.` → `... status: draft.` (bỏ "Trả về đường dẫn"; orchestrator đọc file).
- **R4 — "step_id conductor truyền"** → `step_id` (bỏ "conductor truyền").
- **R5 — front-matter có `run_id`** (discovery Step ghi `run_id`) → bỏ `run_id`.
- **R6 — lookup artifact bước trước qua `state.json.steps[<prev_id>]` / `manifest.steps` / `current_step`** → `artifact bước trước = đường dẫn orchestrator truyền vào`.
- **R7 — description nhắc "qua state.json"** → `do orchestrator truyền`.
- **R8 — "CHỜ conductor qua HARD gate"** → `CHỜ orchestrator qua HARD gate`.
- **R9 — "(tắt được qua --disable)" / "OPTIONAL (...--disable)"** → `(bước optional — orchestrator có thể bỏ)`.

**Verify chung mỗi nhóm:** không còn token cấm trong nhóm file:
`! grep -Eq "conductor|state\.json|run_id|manifest|isolate|--disable|Trả về đường dẫn" <đường-dẫn-nhóm>`

---

### Task 5: Step-skills `migration/*` (4 file)

**Files:**
- Modify: `aitoolkit/skills/migration/discovery/SKILL.md` (dòng 8, 17 `run_id`, 18)
- Modify: `aitoolkit/skills/migration/feature-mapping/SKILL.md` (dòng 8, 15)
- Modify: `aitoolkit/skills/migration/technical-design/SKILL.md` (dòng 8, 17)
- Modify: `aitoolkit/skills/migration/code-migration/SKILL.md` (dòng 8, 15)

- [ ] **Step 1: Áp R1–R6** theo Framing transform rules cho 4 file trên. Cụ thể: dòng mở "Conductor/Được conductor gọi với step_id=…, run_id, run_dir…" → R1; discovery bỏ `run_id` trong front-matter ghi ở bước 4 (R5); mọi "Trả về đường dẫn" → bỏ (R3).

- [ ] **Step 2: Verify nhóm**

Run: `cd aitoolkit && ! grep -REq "conductor|state\.json|run_id|manifest|isolate|Trả về đường dẫn" skills/migration/ && echo OK`
Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
git add aitoolkit/skills/migration/
git commit -m "refactor(aitoolkit): migration step-skills bỏ khung conductor/state.json"
```

---

### Task 6: Step-skills `feature/*` + `bugfix/*` (6 file)

**Files:**
- Modify: `aitoolkit/skills/feature/requirements/SKILL.md` (dòng 8, 13)
- Modify: `aitoolkit/skills/feature/design/SKILL.md` (dòng 8, 14)
- Modify: `aitoolkit/skills/feature/implement/SKILL.md` (dòng 8 `isolate`, 15)
- Modify: `aitoolkit/skills/bugfix/reproduce/SKILL.md` (dòng 8, 14)
- Modify: `aitoolkit/skills/bugfix/root-cause/SKILL.md` (dòng 8 `subagent`, 14)
- Modify: `aitoolkit/skills/bugfix/fix/SKILL.md` (dòng 8 `isolate`, 15)

- [ ] **Step 1: Áp R1–R4** cho 6 file: dòng mở "Conductor gọi với step_id=…, run_id, run_dir. [Bước nặng → subagent (isolate)]" → R1 (bỏ cả cụm subagent/isolate); mọi "Trả về đường dẫn" → bỏ (R3).

- [ ] **Step 2: Verify nhóm**

Run: `cd aitoolkit && ! grep -REq "conductor|state\.json|run_id|manifest|isolate|Trả về đường dẫn" skills/feature/ skills/bugfix/ && echo OK`
Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
git add aitoolkit/skills/feature/ aitoolkit/skills/bugfix/
git commit -m "refactor(aitoolkit): feature+bugfix step-skills bỏ khung conductor/state.json"
```

---

### Task 7: Step-skills `shared/*` (6 file)

**Files:**
- Modify: `aitoolkit/skills/shared/ai-review/SKILL.md` (description dòng 3 `qua state.json`, dòng 8, 17 lookup, 20)
- Modify: `aitoolkit/skills/shared/verification-testing/SKILL.md` (description dòng 3, dòng 8 `manifest`, 25 lookup, 30, 34 `manifest.change_type`)
- Modify: `aitoolkit/skills/shared/gerrit-automation/SKILL.md` (dòng 8, 14, 15 `CHỜ conductor`)
- Modify: `aitoolkit/skills/shared/ccc-automation/SKILL.md` (dòng 8 `--disable`, 15)
- Modify: `aitoolkit/skills/shared/release/SKILL.md` (dòng 8, 14)
- Modify: `aitoolkit/skills/shared/knowledge-base/SKILL.md` (dòng 8, 11 `tra state.json`, 14)

- [ ] **Step 1: Áp R1–R9** cho 6 file:
  - ai-review + verification-testing: description bỏ "Đọc artifact bước trước qua state.json" → "do orchestrator truyền" (R7); phần "Khoanh vùng/Đọc input" thay lookup `state.json.steps[<prev_id>]`/`manifest.steps`/`current_step` bằng "artifact bước trước = đường dẫn orchestrator truyền" (R6).
  - verification-testing dòng 34 `manifest.change_type` → "orchestrator/`project-profile` khai `change_type`" (bỏ chữ `manifest`).
  - gerrit + release: "CHỜ conductor qua HARD gate" → R8; dòng mở R1.
  - ccc: "(tắt được qua --disable)" → R9.
  - knowledge-base: "LIỆT KÊ mọi artifact trong run_dir (tra state.json)" → "liệt kê mọi file `.md` trong RUN_DIR" (R6).

- [ ] **Step 2: Verify nhóm**

Run: `cd aitoolkit && ! grep -REq "conductor|state\.json|run_id|--disable|Trả về đường dẫn" skills/shared/ && ! grep -REq "manifest\." skills/shared/ && echo OK`
Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
git add aitoolkit/skills/shared/
git commit -m "refactor(aitoolkit): shared step-skills bỏ khung conductor/state.json"
```

---

### Task 8: Xoá engine (manifest, stub, DRY-RUN)

**Files:**
- Delete: `aitoolkit/workflows/_dryrun.manifest.yaml`, `aitoolkit/workflows/migration.manifest.yaml`, `aitoolkit/workflows/feature.manifest.yaml`, `aitoolkit/workflows/bugfix.manifest.yaml`
- Delete: `aitoolkit/skills/_stub/echo-step/SKILL.md`, `aitoolkit/skills/_stub/fail-step/SKILL.md` (và thư mục `_stub/`)
- Delete: `aitoolkit/docs/DRY-RUN.md`

- [ ] **Step 1: Xoá file**

```bash
cd aitoolkit
git rm workflows/_dryrun.manifest.yaml workflows/migration.manifest.yaml workflows/feature.manifest.yaml workflows/bugfix.manifest.yaml
git rm -r skills/_stub
git rm docs/DRY-RUN.md
```
(Giữ `workflows/.gitkeep` nếu cần thư mục tồn tại; nếu không còn ý nghĩa, có thể xoá cả `workflows/`.)

- [ ] **Step 2: Verify**

Run: `cd aitoolkit && ! ls workflows/*.manifest.yaml 2>/dev/null && ! test -d skills/_stub && ! test -f docs/DRY-RUN.md && echo OK`
Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
git commit -m "chore(aitoolkit): xoá engine (manifest YAML, stub, DRY-RUN)"
```

---

### Task 9: Cập nhật artefact Codex

**Files:**
- Modify: `aitoolkit/codex/skills/aitoolkit/SKILL.md`
- Modify: `aitoolkit/codex/AGENTS.snippet.md`
- Modify: `aitoolkit/codex/CODEX-SETUP-PROMPT.md`

- [ ] **Step 1: `codex/skills/aitoolkit/SKILL.md`** — viết lại thành bản Codex của orchestrator:
  - frontmatter `description`: bỏ `_dryrun`, `--resume`, `--disable`; đổi cách gọi thành `$aitoolkit <migration|bugfix|feature> [tên-tính-năng]`.
  - Bỏ mọi nhắc manifest/state.json/`isolate`/`--resume`/`--disable`/`_dryrun`.
  - Việc cần làm: đọc `aitoolkit-schemas`, rồi đọc `AITOOLKIT_HOME/aitoolkit/skills/aitoolkit/<workflow>/SKILL.md` và làm theo Bảng bước + Giao thức trong đó.
  - Ghi artifact vào `TARGET_PROJECT/docs/aitoolkit/<date>-<workflow>-<slug>/` (bỏ `.aitoolkit/`/`state.json`).
  - Giữ mục "Khác biệt runtime": gate hỏi bằng text (không AskUserQuestion); HARD gate không tự vượt; project-profile lấy lệnh test qua `TARGET_PROJECT/docs/aitoolkit/project.yaml` hoặc dò marker → nếu không rõ thì hỏi; bỏ dòng `isolate:true`/`multi_agent`.

- [ ] **Step 2: `codex/AGENTS.snippet.md`** — bỏ `_dryrun` khỏi danh sách workflow (dòng 6, 10); dòng 12 bỏ "manifest / state"; dòng 13 bỏ nhắc `workflows/<workflow>.manifest.yaml` → trỏ `skills/aitoolkit/<workflow>/SKILL.md`; dòng 14 & 17 đổi `./.aitoolkit/run-<id>/` + `state.json` → `./docs/aitoolkit/<date>-<workflow>-<slug>/`, `project.yaml` đổi đường dẫn tương ứng.

- [ ] **Step 3: `codex/CODEX-SETUP-PROMPT.md`** — bỏ trọn "## Pha 3 — Verify bằng dry-run" (dòng ~39–50) hoặc thay bằng "Verify bằng cách chạy thử một workflow nhỏ, dừng ở gate đầu"; bỏ mọi `_dryrun`, `state.json`, `run-<id>`, `--resume`, `-not -path '*/_stub/*'` (không còn `_stub`); đổi `TARGET_PROJECT/.aitoolkit/` → `TARGET_PROJECT/docs/aitoolkit/`.

- [ ] **Step 4: Verify**

Run: `cd aitoolkit && ! grep -REq "_dryrun|state\.json|manifest\.yaml|--resume|--disable|_stub|run-<id>|\.aitoolkit/" codex/ && echo OK`
Expected: `OK`.

- [ ] **Step 5: Commit**

```bash
git add aitoolkit/codex/
git commit -m "docs(codex): trỏ orchestrator skill mới, bỏ manifest/state.json/dryrun"
```

---

### Task 10: Cập nhật tài liệu gốc (README, CONTRIBUTING, RUN-ON-CODEX)

**Files:**
- Modify: `aitoolkit/README.md` (dòng 14, 16, 19, 32, 35, 50)
- Modify: `aitoolkit/CONTRIBUTING.md` (dòng 5, 12–14, 22, 24, 26, 34, 39–42, 44, 56, 65–66, 68, 76–82, 91, 96, 104, 165)
- Modify: `aitoolkit/docs/RUN-ON-CODEX.md` (dòng 5, 19, 37, 39, 52, 62, 75–83)

- [ ] **Step 1: `README.md`** — bỏ `--resume run-<id>` (dòng 16); dòng 14 mô tả chạy "theo orchestrator skill" thay `workflows/<workflow>.manifest.yaml`; dòng 19 đổi vị trí artifact → `docs/aitoolkit/<date>-<workflow>-<slug>/`, project.yaml đổi đường dẫn; dòng 32 "gate khai trong orchestrator skill" thay manifest; **xoá dòng 35** (link DRY-RUN); dòng 50 "Thêm workflow mới = thêm orchestrator skill + vài step-skill nửa đầu" thay "manifest".

- [ ] **Step 2: `CONTRIBUTING.md`** — cập nhật kiến trúc: bỏ "manifest YAML" khỏi mô tả seam, đổi sơ đồ (dòng 12–14) sang "orchestrator skill" + bỏ dòng "quản lý state.json"; xoá 4 dòng cây `*.manifest.yaml` (39–42); bỏ `isolate`/`subagent bọc bởi conductor` (dòng 26) → "bước nặng có thể dùng dispatching-parallel-agents khi cần"; đổi dòng 56/65–66/68 (state.json/run-<id>/--resume) sang mô hình artifact `docs/aitoolkit/…` + TodoWrite; sửa bảng invariant I1/I2/I7 (dòng 76–82) bỏ tham chiếu manifest/state.json — I2 đổi thành "bước lấy input bước trước từ đường dẫn orchestrator truyền"; mục "thêm workflow" (91, 96) đổi "viết manifest" → "viết orchestrator skill (Bảng bước + tái dùng shared/*)"; dòng 165 bỏ nhắc `docs/DRY-RUN.md` → "test = review checklist + chạy thử pipeline nhỏ".

- [ ] **Step 3: `docs/RUN-ON-CODEX.md`** — bỏ mọi `_dryrun`/`state.json`/`run-<id>`/`--resume`/`_stub` (dòng 5, 19, 37, 39, 52, 62, 75–83); mục "verify" đổi từ dry-run sang "chạy thử một workflow nhỏ tới gate đầu"; đổi `./.aitoolkit/` → `./docs/aitoolkit/`.

- [ ] **Step 4: Verify**

Run: `cd aitoolkit && ! grep -REq "_dryrun|DRY-RUN|state\.json|manifest\.yaml|--resume|--disable|run-<id>|\.aitoolkit/" README.md CONTRIBUTING.md docs/RUN-ON-CODEX.md && echo OK`
Expected: `OK`.

- [ ] **Step 5: Commit**

```bash
git add aitoolkit/README.md aitoolkit/CONTRIBUTING.md aitoolkit/docs/RUN-ON-CODEX.md
git commit -m "docs(aitoolkit): README/CONTRIBUTING/RUN-ON-CODEX theo cơ chế thuần superpowers"
```

---

### Task 11: Sweep toàn kit + nghiệm thu

**Files:** (không sửa mới — chỉ rà & vá sót)

- [ ] **Step 1: Grep toàn bộ token cấm trên toàn `aitoolkit/`**

Run:
```bash
cd aitoolkit && grep -REn "state\.json|_dryrun|_stub|\.manifest\.yaml|manifest\.steps|run-<id>|--resume|--disable|isolate:|conductor|\.aitoolkit/" \
  --include=*.md --include=*.yaml . || echo "CLEAN"
```
Expected: `CLEAN` (không còn dòng nào). Nếu còn → vá tại chỗ theo Framing rules, rồi chạy lại.

- [ ] **Step 2: Kiểm tra tham chiếu chéo còn sống** — không skill/command nào trỏ tới file đã xoá:

Run: `cd aitoolkit && ! grep -REq "workflows/|skills/_stub|docs/DRY-RUN" --include=*.md . && echo OK`
Expected: `OK`.

- [ ] **Step 3: Nghiệm thu thủ công (ghi lại kết quả, không tự chạy pipeline thật ở đây)** — xác nhận bằng đọc:
  - 3 orchestrator skill tồn tại, mỗi cái có Bảng bước đúng số bước (10/9/9) + HARD gate ở Gerrit/Release + none ở KB.
  - `commands/*.md` chỉ gọi skill tương ứng.
  - `aitoolkit-schemas` còn mục artifact front-matter + project profile, không còn manifest/state.json.

- [ ] **Step 4: Commit (nếu có vá sót)**

```bash
git add -A aitoolkit/
git commit -m "chore(aitoolkit): sweep dọn tham chiếu engine còn sót" || echo "nothing to commit"
```

---

## Self-Review (đã chạy khi viết plan)

- **Spec coverage:** §3.1 giao thức → Task 1; §3.4 tách skill + launcher → Task 1–3; §3.2 artifact location → Task 1 + schemas Task 4; §3.3 step-skill framing → Task 5–7; §4 xoá → Task 8; Codex/docs → Task 9–10; §6 nghiệm thu → Task 11. Đủ.
- **Placeholder scan:** orchestrator skill viết đầy đủ nội dung; framing edits có rule cụ thể R1–R9 + số dòng từng file. Không "TBD/tương tự".
- **Type consistency:** tên skill `aitoolkit/migrate|feature|bugfix` nhất quán giữa command (Task 3) và skill (Task 1–2); token cấm nhất quán giữa Global Constraints và các verify grep; RUN_DIR path đồng nhất mọi task.

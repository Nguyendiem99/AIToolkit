# AIToolKit Migration Front-Half (01–04) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Viết 4 step-skill nửa đầu của workflow migration (Discovery → Feature Mapping → Technical Design → Code Migration) cùng `lge-rules` (khung rỗng cho team điền) và các artifact template, rồi wire vào engine Plan 1 bằng `migration.manifest.yaml` (nửa sau tạm trỏ stub) để chạy được pipeline end-to-end với nửa đầu thật.

**Architecture:** Mỗi step-skill là một playbook markdown thuần-prompt tại `aitoolkit/skills/migration/<name>/SKILL.md`, đọc artifact bước trước + ghi artifact bước sau theo template, tuân `aitoolkit-schemas`. Conductor `/migrate` (Plan 1) điều phối; skill KHÔNG gọi thẳng nhau. Code Migration chạy trong git worktree qua superpowers:using-git-worktrees.

**Tech Stack:** Claude Code plugin (markdown skills, YAML manifest). Phụ thuộc chọn lọc superpowers (`using-git-worktrees`, `writing-plans`/`executing-plans`). Target sinh code: Flutter (Clean Architecture + Riverpod). Không viết script.

## Global Constraints

- **Thuần prompt:** chỉ markdown + YAML. Không script/code ngôn ngữ nào. Nguồn: quyết định "Thuần prompt".
- **Hai seam:** step chỉ giao tiếp qua artifact `.md` theo `aitoolkit-schemas`; pipeline khai báo trong manifest. Nguồn: spec §2.2.
- **Artifact front-matter bắt buộc:** `step_id, run_id, status, produced_at` (xem skill `aitoolkit-schemas`). Ghi `status: draft` khi sinh; conductor đổi `approved` sau gate.
- **Target migration:** webOS Native (Legacy) → Flutter. Kiến trúc đích: **Clean Architecture + Riverpod**, folder theo feature. Nguồn: spec bối cảnh + diagram bước 03/04.
- **lge-rules chưa có nội dung thật:** tạo khung rỗng có cấu trúc; mỗi mục chứa đúng một dòng mốc `«LGE team điền: ...»`. Bước dùng rule phải degrade gracefully khi mục rỗng (coi như "không có rule bổ sung"). Nguồn: quyết định "chưa có LGE rule, triển khai trước".
- **Phạm vi 2a:** chỉ 01–04 + lge-rules + templates + manifest (nửa sau stub). Skill 05–10 thật thuộc Plan 2b.

## File Structure

- `aitoolkit/skills/lge-rules/SKILL.md` — khung rule LGE (team điền sau).
- `aitoolkit/templates/{discovery,mapping,tech-design,migration-report}.md` — khung artifact 01–04.
- `aitoolkit/skills/migration/{discovery,feature-mapping,technical-design,code-migration}/SKILL.md` — 4 playbook.
- `aitoolkit/workflows/migration.manifest.yaml` — 10 bước; 01–04 trỏ skill thật, 05–10 tạm trỏ `_stub/echo-step`.

---

### Task 1: `lge-rules` skeleton skill

**Files:**
- Create: `aitoolkit/skills/lge-rules/SKILL.md`

**Interfaces:**
- Consumes: (không).
- Produces: skill `lge-rules` với các mục cố định — `code-convention`, `performance`, `security`, `null-safety`, `gerrit-commit`, `ccc-checklist` — mỗi mục 1 dòng mốc `«LGE team điền: ...»`. Bước khác đọc skill này; mục còn nguyên mốc ⇒ coi như không có rule bổ sung.

- [ ] **Step 1: Viết `SKILL.md`** (frontmatter + 6 mục, nội dung thật)

````markdown
---
name: lge-rules
description: Rule review & quy ước LGE cho migration Flutter (convention, performance, security, null-safety, Gerrit, CCC). Bước AI Review / Code Migration / Gerrit / CCC đọc skill này. Mục còn dòng «LGE team điền» ⇒ chưa có rule, bỏ qua mục đó.
---

# LGE Rules (khung — team điền)

Mỗi mục dưới đây: thay dòng `«LGE team điền: ...»` bằng rule thật. Khi còn nguyên mốc, coi như mục đó KHÔNG áp rule bổ sung nào (degrade gracefully).

## code-convention
«LGE team điền: naming, folder, style Dart/Flutter theo chuẩn LGE»

## performance
«LGE team điền: yêu cầu hiệu năng (rebuild, memory, startup...)»

## security
«LGE team điền: yêu cầu bảo mật (data, Luna Service, permission...)»

## null-safety
«LGE team điền: quy tắc null-safety bắt buộc»

## gerrit-commit
«LGE team điền: format commit message, Change-Id, quy ước review»

## ccc-checklist
«LGE team điền: hạng mục CCC bắt buộc + evidence cần thu thập»
````

- [ ] **Step 2: Verify**

Chạy:
```
python3 -c "import re; t=open('aitoolkit/skills/lge-rules/SKILL.md').read(); \
assert re.search(r'^name: lge-rules$',t,re.M); \
[__import__('sys').exit('missing '+m) for m in ['code-convention','performance','security','null-safety','gerrit-commit','ccc-checklist'] if m not in t]; \
assert t.count('«LGE team điền')==6; print('OK: 6 mục + 6 mốc điền')"
```
Kỳ vọng: `OK: 6 mục + 6 mốc điền`.

- [ ] **Step 3: Commit**

```bash
git add aitoolkit/skills/lge-rules/
git commit -m "feat(aitoolkit): lge-rules skeleton skill (team điền sau)"
```

---

### Task 2: Artifact templates cho 01–04

**Files:**
- Create: `aitoolkit/templates/discovery.md`
- Create: `aitoolkit/templates/mapping.md`
- Create: `aitoolkit/templates/tech-design.md`
- Create: `aitoolkit/templates/migration-report.md`

**Interfaces:**
- Consumes: `aitoolkit-schemas` (front-matter).
- Produces: 4 template rỗng có heading cố định (theo cột OUTPUT của diagram) mà skill 01–04 sẽ điền. Mỗi template mở đầu bằng front-matter mẫu với `status: draft`.

- [ ] **Step 1: `discovery.md`** (khớp diagram: feature list, screen list, dependency, Luna Service, risk & estimation)

```markdown
---
step_id: 01-discovery
run_id: <run-id>
status: draft
produced_at: <yyyy-mm-dd>
---

# Discovery — <tên module>

## Feature list
| Feature | Mô tả | Ưu tiên |
|---|---|---|

## Screen list
| Screen | Vai trò | Ghi chú |
|---|---|---|

## Dependencies
- Native/Platform:
- Luna Service:
- Thư viện bên thứ ba:

## Rủi ro & Ước lượng
| Hạng mục | Rủi ro | Ước lượng |
|---|---|---|
```

- [ ] **Step 2: `mapping.md`** (mapping matrix Native→Flutter, scope, gap analysis)

```markdown
---
step_id: 02-feature-mapping
run_id: <run-id>
status: draft
produced_at: <yyyy-mm-dd>
---

# Feature Mapping — <tên module>

## Mapping matrix (Native → Flutter)
| Thành phần Native | Tương ứng Flutter | Ghi chú |
|---|---|---|

## Scope migration
- Trong phạm vi:
- Ngoài phạm vi:

## Gap analysis
| Khoảng trống | Ảnh hưởng | Hướng xử lý |
|---|---|---|
```

- [ ] **Step 3: `tech-design.md`** (architecture, sequence, data flow — Clean Architecture + Riverpod)

```markdown
---
step_id: 03-technical-design
run_id: <run-id>
status: draft
produced_at: <yyyy-mm-dd>
---

# Technical Design — <tên module>

## Kiến trúc (Clean Architecture + Riverpod)
- Presentation:
- Domain (usecase/entity):
- Data (repository/provider):

## Folder structure
```
lib/features/<feature>/{presentation,domain,data}
```

## Sequence
<mô tả luồng chính từ UI → provider → usecase → repository>

## Data flow
<state management với Riverpod: provider nào giữ state gì>
```

- [ ] **Step 4: `migration-report.md`** (04 ghi lại đã sinh gì + nhánh)

```markdown
---
step_id: 04-code-migration
run_id: <run-id>
status: draft
produced_at: <yyyy-mm-dd>
---

# Code Migration Report — <tên module>

## Feature branch
- Branch: <tên nhánh>
- Worktree: <đường dẫn>

## File đã sinh
| File Flutter | Vai trò | Nguồn Native tương ứng |
|---|---|---|

## Ghi chú build
- Lệnh chạy thử: `flutter analyze` / `flutter test`
- Vấn đề còn lại:
```

- [ ] **Step 5: Verify**

```
ls aitoolkit/templates/{discovery,mapping,tech-design,migration-report}.md
python3 -c "import glob; [__import__('sys').exit('no frontmatter '+f) for f in glob.glob('aitoolkit/templates/*.md') if not open(f).read().startswith('---')]; print('OK: 4 templates + front-matter')"
```
Kỳ vọng: liệt kê đủ 4 file + `OK: 4 templates + front-matter`.

- [ ] **Step 6: Commit**

```bash
git add aitoolkit/templates/
git commit -m "feat(aitoolkit): artifact templates for migration steps 01-04"
```

---

### Task 3: 01 `migration/discovery`

**Files:**
- Create: `aitoolkit/skills/migration/discovery/SKILL.md`

**Interfaces:**
- Consumes: input dự án (legacy source, PRD/BRD) do người dùng trỏ tới; template `discovery.md`; `aitoolkit-schemas`.
- Produces: artifact `<run_dir>/01-discovery.md` theo template `discovery.md`, front-matter `step_id: 01-discovery`, `status: draft`. Trả về đường dẫn cho conductor.

- [ ] **Step 1: Viết `SKILL.md`**

````markdown
---
name: discovery
description: Bước 01 migration — phân tích codebase webOS Native legacy: liệt kê feature, screen, dependency, Luna Service; đánh giá rủi ro & ước lượng. Ghi 01-discovery.md.
---

# Migration 01 — Discovery

Được conductor gọi với `step_id=01-discovery`, `run_id`, `run_dir`, và đường dẫn source legacy + PRD/BRD (nếu có).

## Việc cần làm
1. Đọc `aitoolkit-schemas` (front-matter) và template `aitoolkit/templates/discovery.md`.
2. Khảo sát source legacy: dùng codebase-memory-mcp nếu đã index (get_architecture, search_graph), nếu chưa thì Grep/Glob. Với webOS chú ý: file `appinfo.json`, lời gọi **Luna Service** (`luna://`), QML/Enact component, handler sự kiện.
3. Điền template:
   - **Feature list / Screen list**: từ route/QML/manifest.
   - **Dependencies**: Luna Service, native module, package.
   - **Rủi ro & Ước lượng**: chỗ khó (native-only API, dịch vụ hệ thống), effort thô.
4. Ghi `<run_dir>/01-discovery.md` với front-matter đúng (`step_id: 01-discovery`, `run_id`, `status: draft`, `produced_at`).
5. Trả về đường dẫn artifact.

## Ranh giới
- Chỉ PHÂN TÍCH, không thiết kế Flutter (để bước 03), không map (bước 02).
- Không đoán bừa: mục không xác định được thì ghi rõ "cần xác nhận".
````

- [ ] **Step 2: Verify (review checklist)**

- [ ] Frontmatter skill có `name: discovery` + description.
- [ ] Có tham chiếu `aitoolkit-schemas` + template `discovery.md`.
- [ ] Output đúng `01-discovery.md`, `status: draft`.
- [ ] Ranh giới rõ (không lấn bước 02/03).

- [ ] **Step 3: Commit**

```bash
git add aitoolkit/skills/migration/discovery/
git commit -m "feat(aitoolkit): migration 01 discovery skill"
```

---

### Task 4: 02 `migration/feature-mapping`

**Files:**
- Create: `aitoolkit/skills/migration/feature-mapping/SKILL.md`

**Interfaces:**
- Consumes: `<run_dir>/01-discovery.md`; template `mapping.md`.
- Produces: `<run_dir>/02-mapping.md` (mapping matrix Native→Flutter, scope, gap analysis), `status: draft`.

- [ ] **Step 1: Viết `SKILL.md`**

````markdown
---
name: feature-mapping
description: Bước 02 migration — ánh xạ từng thành phần webOS Native sang tương ứng Flutter, chốt scope, phân tích gap. Đọc 01-discovery.md, ghi 02-mapping.md.
---

# Migration 02 — Feature Mapping

Conductor gọi với `step_id=02-feature-mapping`, `run_id`, `run_dir`.

## Việc cần làm
1. Đọc `aitoolkit-schemas`, template `aitoolkit/templates/mapping.md`, và `<run_dir>/01-discovery.md` (bắt buộc phải có — thiếu thì báo lỗi).
2. Với mỗi feature/screen/dependency trong discovery, điền **mapping matrix**: thành phần Native → widget/pattern Flutter tương ứng (vd QML view → Flutter Widget; Luna Service call → service/repository + platform channel).
3. Chốt **scope**: cái gì migrate, cái gì tạm ngoài phạm vi.
4. **Gap analysis**: thứ không có tương ứng thẳng (native-only) → hướng xử lý.
5. Ghi `<run_dir>/02-mapping.md`, `status: draft`. Trả về đường dẫn.

## Ranh giới
- Map ở mức thành phần, CHƯA thiết kế chi tiết kiến trúc (bước 03).
````

- [ ] **Step 2: Verify (review checklist)**

- [ ] Đọc `01-discovery.md` (nêu rõ bắt buộc, thiếu → lỗi).
- [ ] Output `02-mapping.md` có mapping matrix + scope + gap.
- [ ] Không lấn bước 03.

- [ ] **Step 3: Commit**

```bash
git add aitoolkit/skills/migration/feature-mapping/
git commit -m "feat(aitoolkit): migration 02 feature-mapping skill"
```

---

### Task 5: 03 `migration/technical-design`

**Files:**
- Create: `aitoolkit/skills/migration/technical-design/SKILL.md`

**Interfaces:**
- Consumes: `<run_dir>/02-mapping.md`; template `tech-design.md`; `lge-rules` (mục `code-convention` cho folder/naming nếu đã điền).
- Produces: `<run_dir>/03-tech-design.md` (Clean Architecture + Riverpod: architecture, folder, sequence, data flow), `status: draft`.

- [ ] **Step 1: Viết `SKILL.md`**

````markdown
---
name: technical-design
description: Bước 03 migration — thiết kế kiến trúc Flutter (Clean Architecture + Riverpod) cho phần đã map: layer, folder, sequence, data flow. Đọc 02-mapping.md, ghi 03-tech-design.md.
---

# Migration 03 — Technical Design

Conductor gọi với `step_id=03-technical-design`, `run_id`, `run_dir`. Bước này chạy INLINE (cần bàn với người) — conductor sẽ dừng ở gate Tech Lead.

## Việc cần làm
1. Đọc `aitoolkit-schemas`, template `tech-design.md`, `<run_dir>/02-mapping.md`, và `lge-rules` (mục `code-convention`; nếu còn mốc «LGE team điền» thì dùng mặc định Clean Architecture + feature-first folder).
2. Thiết kế theo **Clean Architecture + Riverpod**:
   - Chia **Presentation / Domain (usecase, entity) / Data (repository, provider)**.
   - **Folder** feature-first: `lib/features/<feature>/{presentation,domain,data}`.
   - **Sequence** luồng chính: UI → provider → usecase → repository → (platform channel tới Luna Service nếu cần).
   - **Data flow**: provider nào giữ state gì.
3. Ghi `<run_dir>/03-tech-design.md`, `status: draft`. Trả về đường dẫn.

## Ranh giới
- Thiết kế, CHƯA sinh code (bước 04).
- Bám mapping ở bước 02; phát sinh ngoài mapping phải nêu rõ.
````

- [ ] **Step 2: Verify (review checklist)**

- [ ] Đọc `02-mapping.md` + `lge-rules` (degrade khi mục còn mốc).
- [ ] Output `03-tech-design.md` có đủ architecture/folder/sequence/data-flow theo Clean Arch + Riverpod.
- [ ] Không sinh code.

- [ ] **Step 3: Commit**

```bash
git add aitoolkit/skills/migration/technical-design/
git commit -m "feat(aitoolkit): migration 03 technical-design skill"
```

---

### Task 6: 04 `migration/code-migration`

**Files:**
- Create: `aitoolkit/skills/migration/code-migration/SKILL.md`

**Interfaces:**
- Consumes: `<run_dir>/03-tech-design.md`; `lge-rules` (`code-convention`, `null-safety`); superpowers:using-git-worktrees; superpowers:writing-plans + executing-plans.
- Produces: source Flutter trong một git worktree + feature branch; artifact `<run_dir>/04-migration-report.md` (template `migration-report.md`) ghi nhánh + file đã sinh + ghi chú build. `status: draft`.

- [ ] **Step 1: Viết `SKILL.md`**

````markdown
---
name: code-migration
description: Bước 04 migration — sinh code Flutter (UI, logic, service, provider, repository) theo tech-design, trong git worktree riêng. Đọc 03-tech-design.md, ghi 04-migration-report.md.
---

# Migration 04 — Code Migration

Conductor gọi với `step_id=04-code-migration`, `run_id`, `run_dir`. Bước nặng → conductor chạy trong subagent (isolate).

## Việc cần làm
1. Đọc `aitoolkit-schemas`, template `migration-report.md`, `<run_dir>/03-tech-design.md`, `lge-rules` (`code-convention`, `null-safety`; degrade khi còn mốc).
2. Tạo workspace cô lập: dùng superpowers:using-git-worktrees để tạo worktree + feature branch cho lần migrate này.
3. Biến tech-design thành kế hoạch code rồi thực thi: dùng superpowers:writing-plans → executing-plans (TDD khi khả thi) để sinh theo layer Clean Architecture + Riverpod: entity/usecase → repository/provider → widget/UI. Áp `code-convention`/`null-safety` nếu có.
4. Chạy `flutter analyze` (và `flutter test` nếu có test) để bắt lỗi hiển nhiên; ghi kết quả.
5. Ghi `<run_dir>/04-migration-report.md`: tên nhánh, đường dẫn worktree, bảng file đã sinh (kèm nguồn Native), ghi chú build. `status: draft`. Trả về đường dẫn.

## Ranh giới
- CHỈ sinh code theo design đã duyệt (bước 03). Lệch design phải ghi rõ trong report.
- KHÔNG upload Gerrit (bước 07), KHÔNG tự merge nhánh.
````

- [ ] **Step 2: Verify (review checklist)**

- [ ] Dùng `using-git-worktrees` (cô lập) + `writing-plans`/`executing-plans`.
- [ ] Đọc `03-tech-design.md` + `lge-rules`.
- [ ] Output `04-migration-report.md` có nhánh + file đã sinh + ghi chú build.
- [ ] Ranh giới: không Gerrit, không merge.

- [ ] **Step 3: Commit**

```bash
git add aitoolkit/skills/migration/code-migration/
git commit -m "feat(aitoolkit): migration 04 code-migration skill"
```

---

### Task 7: `migration.manifest.yaml` (01–04 thật, 05–10 stub) + dry-run front-half

**Files:**
- Create: `aitoolkit/workflows/migration.manifest.yaml`

**Interfaces:**
- Consumes: 4 skill 01–04 (Task 3–6); engine Plan 1 (conductor).
- Produces: manifest 10 bước đúng spec §5. Bước 01–04 trỏ skill migration thật; bước 05–10 TẠM trỏ `_stub/echo-step` (Plan 2b thay bằng skill thật). Gate/isolate/optional đúng bảng spec §5.

- [ ] **Step 1: Viết `migration.manifest.yaml`**

```yaml
workflow: migration
steps:
  - id: 01-discovery
    skill: migration/discovery
    isolate: true
    gate: { type: soft, approver: "PM/Client", prompt: "Xác nhận scope migration?" }
  - id: 02-feature-mapping
    skill: migration/feature-mapping
    isolate: true
    gate: { type: soft, approver: "Client", prompt: "Duyệt mapping & scope?" }
  - id: 03-technical-design
    skill: migration/technical-design
    isolate: false
    gate: { type: soft, approver: "Tech Lead", prompt: "Duyệt thiết kế kỹ thuật?" }
  - id: 04-code-migration
    skill: migration/code-migration
    isolate: true
    gate: { type: soft, approver: "Developer", prompt: "Code chạy được, duyệt?" }
  # --- nửa sau: TẠM stub, Plan 2b thay bằng shared/* thật ---
  - id: 05-ai-review
    skill: _stub/echo-step
    isolate: true
    gate: { type: soft, approver: "Reviewer", prompt: "Duyệt review?" }
  - id: 06-verification-testing
    skill: _stub/echo-step
    isolate: true
    gate: { type: soft, approver: "Dev/QA", prompt: "Duyệt kết quả test?" }
  - id: 07-gerrit-automation
    skill: _stub/echo-step
    isolate: false
    gate: { type: hard, approver: "Reviewer", prompt: "Xác nhận trước khi upload Gerrit?" }
  - id: 08-ccc-automation
    skill: _stub/echo-step
    isolate: true
    optional: true
    gate: { type: soft, approver: "PM/QA", prompt: "Duyệt CCC?" }
  - id: 09-release
    skill: _stub/echo-step
    isolate: false
    optional: true
    gate: { type: hard, approver: "PM", prompt: "Duyệt release?" }
  - id: 10-knowledge-base
    skill: _stub/echo-step
    isolate: true
    gate: none
```

- [ ] **Step 2: Verify manifest hợp lệ**

```
python3 - <<'PY'
import re,os
t=open('aitoolkit/workflows/migration.manifest.yaml').read()
ids=re.findall(r'id:\s*(\S+)',t)
assert len(ids)==len(set(ids))==10, ids
for s in set(re.findall(r'skill:\s*(\S+)',t)):
    assert os.path.isfile(f'aitoolkit/skills/{s}/SKILL.md'), f'missing {s}'
assert '01-discovery' in t and 'migration/discovery' in t
assert t.count('_stub/echo-step')==6, "nửa sau phải là 6 stub"
assert 'type: hard' in t and 'gate: none' in t and 'optional: true' in t
print('OK: manifest 10 bước, 01-04 thật, 05-10 stub, gate/isolate/optional hợp lệ')
PY
```

- [ ] **Step 3: Dry-run front-half (mô phỏng/thật)**

Trên một repo mẫu, chạy `/migrate migration`. Vì skill thật cần input dự án thật, ở mức kiểm tra này chấp nhận mô phỏng: xác nhận conductor đọc `migration.manifest.yaml`, chạy `01-discovery` (đọc skill migration/discovery), tạo `run_dir` + `state.json`, dừng ở gate "Xác nhận scope migration?". Duyệt lần lượt tới `04`, quan sát artifact `01→04` sinh đúng tên; từ `05` trở đi là stub.
**Kỳ vọng ghi lại vào cuối `aitoolkit/docs/DRY-RUN.md`** (mục "migration front-half").

- [ ] **Step 4: Commit**

```bash
git add aitoolkit/workflows/migration.manifest.yaml aitoolkit/docs/DRY-RUN.md
git commit -m "feat(aitoolkit): migration manifest (01-04 real, 05-10 stub) + front-half dry-run"
```

---

## Self-Review

**1. Spec coverage:**
- §5 bước 01 → Task 3; 02 → Task 4; 03 → Task 5; 04 → Task 6. ✅
- §5 bước 05–10 → ngoài phạm vi 2a (stub trong manifest, Plan 2b làm thật). ✅
- §3 tái dùng SP: `using-git-worktrees` + `writing-plans`/`executing-plans` ở Task 6. ✅
- lge-rules (spec §4) → Task 1 (khung). ✅
- Kiến trúc đích Clean Arch + Riverpod → Task 5/6. ✅
- Manifest gate/isolate/optional đúng bảng §5 → Task 7. ✅

**2. Placeholder scan:** không có TBD/TODO trong plan. Mốc `«LGE team điền»` là NỘI DUNG artifact có chủ đích (lge-rules), đã nêu rõ cách degrade — không phải placeholder của plan. ✅

**3. Type/tên nhất quán:** id bước `01-discovery..10-knowledge-base`, tên artifact `01-discovery.md/02-mapping.md/03-tech-design.md/04-migration-report.md`, skill path `migration/<name>`, `_stub/echo-step` — nhất quán Task 1→7 và khớp `migration.manifest.yaml`. ✅

**Bàn giao Plan 2b:** thay 6 dòng `skill: _stub/echo-step` (bước 05–10) bằng `shared/<name>` thật; thêm template `review-report.md`, `verification-report.md`, `gerrit-report.md`, `ccc-package.md`, `release-report.md`; ai-review/ccc/gerrit đọc `lge-rules`. Không sửa conductor.

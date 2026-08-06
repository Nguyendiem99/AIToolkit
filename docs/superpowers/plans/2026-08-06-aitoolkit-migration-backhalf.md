# AIToolKit Migration Back-Half (05–10) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Viết 6 step-skill nửa sau — khung dùng chung — của workflow migration (AI Review → Verification & Testing → Gerrit → CCC → Release → Knowledge Base) cùng template artifact của chúng, rồi thay 6 stub trong `migration.manifest.yaml` bằng skill thật để pipeline migration đủ 10 bước thật.

**Architecture:** Mỗi step-skill là playbook markdown thuần-prompt tại `aitoolkit/skills/shared/<name>/SKILL.md`, đọc artifact bước trước + ghi artifact bước sau theo template, tuân `aitoolkit-schemas`. Các bước tái dùng skill superpowers (code-review, TDD/verification, finishing-branch) + đọc `lge-rules`. Conductor Plan 1 điều phối; KHÔNG sửa conductor.

**Tech Stack:** Claude Code plugin (markdown skills, YAML manifest). Phụ thuộc chọn lọc superpowers (`requesting-code-review`, `receiving-code-review`, `test-driven-development`, `verification-before-completion`, `finishing-a-development-branch`). Không viết script.

## Global Constraints

- **Thuần prompt:** chỉ markdown + YAML. Không script.
- **Hai seam:** step chỉ giao tiếp qua artifact `.md` theo `aitoolkit-schemas`; pipeline khai báo trong manifest; KHÔNG sửa conductor `migrate.md`. Nguồn: spec §2.2.
- **Khung dùng chung:** 6 skill này (05–10) đặt tại `skills/shared/` để bugfix/feature tái dùng. Nguồn: spec §2.3, §8.
- **Gate đúng spec §5:** 05/06/08 soft; 07/09 HARD; 10 không gate. 08 (CCC) & 09 (Release) `optional: true`.
- **lge-rules degrade:** đọc `lge-rules`; mục còn mốc «LGE team điền» ⇒ bỏ qua mục đó (không chặn).
- **Không đảo ngược:** 07 Gerrit upload & 09 Release là HARD gate — skill KHÔNG tự thực hiện hành động không đảo ngược khi chưa qua gate.
- **Phạm vi 2b:** chỉ 05–10 + template + swap manifest + integration. Không đụng 01–04, không đụng conductor.

## File Structure

- `aitoolkit/templates/{review-report,verification-report,gerrit-report,ccc-package,release-report,kb-entry}.md`
- `aitoolkit/skills/shared/{ai-review,verification-testing,gerrit-automation,ccc-automation,release,knowledge-base}/SKILL.md`
- `aitoolkit/workflows/migration.manifest.yaml` — thay 6 `_stub/echo-step` bằng `shared/<name>`.

---

### Task 1: Templates cho 05–10

**Files:**
- Create: `aitoolkit/templates/review-report.md`
- Create: `aitoolkit/templates/verification-report.md`
- Create: `aitoolkit/templates/gerrit-report.md`
- Create: `aitoolkit/templates/ccc-package.md`
- Create: `aitoolkit/templates/release-report.md`
- Create: `aitoolkit/templates/kb-entry.md`

**Interfaces:**
- Consumes: `aitoolkit-schemas` (front-matter).
- Produces: 6 template có heading cố định (theo cột OUTPUT diagram §5), mỗi cái mở đầu front-matter `status: draft` với `step_id` tương ứng.

- [ ] **Step 1: `review-report.md`** (Critical / Major / Minor — cột OUTPUT bước 05)

```markdown
---
step_id: 05-ai-review
run_id: <run-id>
status: draft
produced_at: <yyyy-mm-dd>
---

# AI Review Report — <tên module>

## Tổng quan
- Phạm vi review:
- Rule LGE áp dụng: <liệt kê mục lge-rules đã điền; nếu rỗng ghi "chưa có, dùng review chung">

## Critical
| File:line | Vấn đề | Đề xuất |
|---|---|---|

## Major
| File:line | Vấn đề | Đề xuất |
|---|---|---|

## Minor
| File:line | Vấn đề | Đề xuất |
|---|---|---|
```

- [ ] **Step 2: `verification-report.md`** (Comparison / Test result / Coverage — bước 06)

```markdown
---
step_id: 06-verification-testing
run_id: <run-id>
status: draft
produced_at: <yyyy-mm-dd>
---

# Verification & Testing Report — <tên module>

## So sánh hành vi Native vs Flutter
| Kịch bản | Native | Flutter | Khớp? |
|---|---|---|---|

## Kết quả test
- Lệnh: `flutter test`
- Pass/Fail:

## Coverage
| Thành phần | % Coverage |
|---|---|
```

- [ ] **Step 3: `gerrit-report.md`** (Commit message / Change description — bước 07)

```markdown
---
step_id: 07-gerrit-automation
run_id: <run-id>
status: draft
produced_at: <yyyy-mm-dd>
---

# Gerrit Report — <tên module>

## Commit message
```
<theo lge-rules gerrit-commit; nếu chưa có, dùng Conventional Commits>
```

## Change description
<mô tả thay đổi, phạm vi, cách test>

## Thông tin upload
- Change-Id:
- Reviewer đề xuất:
- Trạng thái: <chưa upload / đã upload sau HARD gate>
```

- [ ] **Step 4: `ccc-package.md`** (Checklist / Evidence / Release Note — bước 08)

```markdown
---
step_id: 08-ccc-automation
run_id: <run-id>
status: draft
produced_at: <yyyy-mm-dd>
---

# CCC Package — <tên module>

## Checklist
| Hạng mục CCC | Đạt? | Evidence |
|---|---|---|

## Evidence thu thập
- <link/đường dẫn tới report, test, review>

## Release note (nháp)
<tóm tắt thay đổi cho release>
```

- [ ] **Step 5: `release-report.md`** (Release Note / Go-No-Go — bước 09)

```markdown
---
step_id: 09-release
run_id: <run-id>
status: draft
produced_at: <yyyy-mm-dd>
---

# Release Report — <tên module>

## Điều kiện release
| Điều kiện | Đạt? |
|---|---|
| Review đã duyệt (05) | |
| Test đạt (06) | |
| Gerrit merged (07) | |
| CCC đạt (08, nếu bật) | |

## Quyết định
- Go / No-Go:
- Lý do:

## Release note (chốt)
<nội dung release note>
```

- [ ] **Step 6: `kb-entry.md`** (Feature / Issue / Resolution — bước 10)

```markdown
---
step_id: 10-knowledge-base
run_id: <run-id>
status: draft
produced_at: <yyyy-mm-dd>
---

# Knowledge Base Entry — <tên module>

## Tóm tắt run
- Workflow: migration
- Kết quả: <Go/No-Go, ngày>

## Artifact liên kết
| Bước | Artifact |
|---|---|
| 01 Discovery | 01-discovery.md |
| ... | ... |

## Bài học / Vấn đề & Cách xử lý
| Vấn đề | Cách xử lý |
|---|---|
```

- [ ] **Step 7: Verify**

```
python3 - <<'PY'
import glob
need={'review-report','verification-report','gerrit-report','ccc-package','release-report','kb-entry'}
have={f.split('/')[-1][:-3] for f in glob.glob('aitoolkit/templates/*.md')}
miss=need-have
assert not miss, f"thiếu template: {miss}"
for n in need:
    t=open(f'aitoolkit/templates/{n}.md').read()
    assert t.startswith('---'), f"{n}: thiếu front-matter"
print("OK: 6 template nửa sau + front-matter")
PY
```

- [ ] **Step 8: Commit**

```bash
git add aitoolkit/templates/
git commit -m "feat(aitoolkit): artifact templates for shared steps 05-10"
```

---

### Task 2: 05 `shared/ai-review`

**Files:**
- Create: `aitoolkit/skills/shared/ai-review/SKILL.md`

**Interfaces:**
- Consumes: source Flutter + `<run_dir>/04-migration-report.md`; `lge-rules` (mọi mục review); superpowers:requesting-code-review + receiving-code-review; template `review-report.md`.
- Produces: `<run_dir>/05-review-report.md` phân loại Critical/Major/Minor. `status: draft`.

- [ ] **Step 1: Viết `SKILL.md`**

````markdown
---
name: ai-review
description: Bước 05 migration (khung dùng chung) — review code Flutter theo rule LGE (convention, performance, security, null-safety), phân loại Critical/Major/Minor. Đọc 04-migration-report.md + source, ghi 05-review-report.md.
---

# Shared 05 — AI Review

Conductor gọi với `step_id=05-ai-review`, `run_id`, `run_dir`. Bước nặng → chạy trong subagent.

## Việc cần làm
1. Đọc `aitoolkit-schemas`, template `review-report.md`, `<run_dir>/04-migration-report.md` (để biết nhánh + file đã sinh), và `lge-rules` (mọi mục; mục còn mốc «LGE team điền» ⇒ bỏ qua).
2. Dùng superpowers:requesting-code-review để review code trên nhánh migration; áp thêm rule LGE đã điền (convention, performance, security, null-safety).
3. Phân loại phát hiện thành **Critical / Major / Minor**, ghi kèm `file:line` + đề xuất.
4. Ghi `<run_dir>/05-review-report.md` theo template, `status: draft`. Trả về đường dẫn.

## Ranh giới
- CHỈ review + báo cáo; KHÔNG tự sửa code (dev sửa, hoặc quay lại bước 04 nếu Critical).
- KHÔNG upload Gerrit (bước 07).
````

- [ ] **Step 2: Verify (review checklist)**

- [ ] `name: ai-review` + description; đọc `04-migration-report.md` + `lge-rules`; dùng `requesting-code-review`.
- [ ] Output `05-review-report.md` có Critical/Major/Minor.
- [ ] Ranh giới: không sửa code, không Gerrit.

- [ ] **Step 3: Commit**

```bash
git add aitoolkit/skills/shared/ai-review/
git commit -m "feat(aitoolkit): shared 05 ai-review skill"
```

---

### Task 3: 06 `shared/verification-testing`

**Files:**
- Create: `aitoolkit/skills/shared/verification-testing/SKILL.md`

**Interfaces:**
- Consumes: `<run_dir>/05-review-report.md` + source; superpowers:test-driven-development + verification-before-completion; template `verification-report.md`.
- Produces: `<run_dir>/06-verification-report.md` (so sánh Native/Flutter, kết quả test, coverage). `status: draft`.

- [ ] **Step 1: Viết `SKILL.md`**

````markdown
---
name: verification-testing
description: Bước 06 migration (khung dùng chung) — so sánh hành vi Native vs Flutter, sinh & chạy test tự động, đo coverage. Đọc 05-review-report.md + source, ghi 06-verification-report.md.
---

# Shared 06 — Verification & Testing

Conductor gọi với `step_id=06-verification-testing`, `run_id`, `run_dir`. Bước nặng → subagent.

## Việc cần làm
1. Đọc `aitoolkit-schemas`, template `verification-report.md`, `<run_dir>/05-review-report.md`.
2. Sinh test cho phần đã migrate (dùng superpowers:test-driven-development khi khả thi); chạy `flutter test`.
3. **So sánh hành vi Native vs Flutter** theo kịch bản chính (từ discovery/mapping).
4. Áp superpowers:verification-before-completion: KHÔNG kết luận "đạt" nếu chưa có bằng chứng test.
5. Ghi `<run_dir>/06-verification-report.md` (comparison, test result, coverage), `status: draft`. Trả về đường dẫn.

## Ranh giới
- Nếu test fail / hành vi lệch nghiêm trọng → nêu rõ để quay lại bước 04, KHÔNG che giấu.
````

- [ ] **Step 2: Verify (review checklist)**

- [ ] `name: verification-testing`; đọc `05-review-report.md`; dùng `test-driven-development` + `verification-before-completion`.
- [ ] Output `06-verification-report.md` có comparison + test result + coverage.

- [ ] **Step 3: Commit**

```bash
git add aitoolkit/skills/shared/verification-testing/
git commit -m "feat(aitoolkit): shared 06 verification-testing skill"
```

---

### Task 4: 07 `shared/gerrit-automation`

**Files:**
- Create: `aitoolkit/skills/shared/gerrit-automation/SKILL.md`

**Interfaces:**
- Consumes: `<run_dir>/06-verification-report.md` + nhánh migration; `lge-rules` (`gerrit-commit`); superpowers:finishing-a-development-branch; template `gerrit-report.md`.
- Produces: commit message + change description; `<run_dir>/07-gerrit-report.md`. Upload Gerrit CHỈ sau HARD gate. `status: draft`.

- [ ] **Step 1: Viết `SKILL.md`**

````markdown
---
name: gerrit-automation
description: Bước 07 migration (khung dùng chung) — tạo commit message + change description theo quy ước LGE, chuẩn bị upload Gerrit. Đọc 06-verification-report.md, ghi 07-gerrit-report.md. Upload chỉ sau HARD gate.
---

# Shared 07 — Gerrit Automation

Conductor gọi với `step_id=07-gerrit-automation`, `run_id`, `run_dir`. Chạy INLINE. Bước này có HARD gate (không đảo ngược khi upload).

## Việc cần làm
1. Đọc `aitoolkit-schemas`, template `gerrit-report.md`, `<run_dir>/06-verification-report.md`, `lge-rules` (`gerrit-commit`; nếu còn mốc dùng Conventional Commits mặc định).
2. Chuẩn bị nhánh: dùng superpowers:finishing-a-development-branch để đảm bảo nhánh sạch, test xanh.
3. Soạn **commit message** + **change description** theo `gerrit-commit`.
4. Ghi `<run_dir>/07-gerrit-report.md` với trạng thái "chưa upload".
5. **CHỜ conductor qua HARD gate** (Reviewer xác nhận). CHỈ SAU khi được duyệt mới thực hiện upload Gerrit (push refs/for/...), rồi cập nhật report + Change-Id, `status: draft` → conductor set approved.

## Ranh giới
- TUYỆT ĐỐI không upload trước khi HARD gate được duyệt.
- Không tự merge trên Gerrit (người/CI quyết).
````

- [ ] **Step 2: Verify (review checklist)**

- [ ] `name: gerrit-automation`; đọc `06-verification-report.md` + `lge-rules` gerrit-commit; dùng `finishing-a-development-branch`.
- [ ] Nêu RÕ: chỉ upload sau HARD gate.
- [ ] Output `07-gerrit-report.md` có commit message + change description + trạng thái upload.

- [ ] **Step 3: Commit**

```bash
git add aitoolkit/skills/shared/gerrit-automation/
git commit -m "feat(aitoolkit): shared 07 gerrit-automation skill"
```

---

### Task 5: 08 `shared/ccc-automation`

**Files:**
- Create: `aitoolkit/skills/shared/ccc-automation/SKILL.md`

**Interfaces:**
- Consumes: `<run_dir>/05-review-report.md` + `06-verification-report.md` + `07-gerrit-report.md`; `lge-rules` (`ccc-checklist`); template `ccc-package.md`.
- Produces: `<run_dir>/08-ccc-package.md` (checklist, evidence, release note nháp). `status: draft`. Bước OPTIONAL.

- [ ] **Step 1: Viết `SKILL.md`**

````markdown
---
name: ccc-automation
description: Bước 08 migration (khung dùng chung, OPTIONAL) — dựng CCC checklist theo chuẩn LGE, thu thập evidence, sinh release note nháp, phân tích ảnh hưởng. Ghi 08-ccc-package.md.
---

# Shared 08 — CCC Automation

Conductor gọi với `step_id=08-ccc-automation`, `run_id`, `run_dir`. Bước nặng → subagent. OPTIONAL (tắt được qua --disable).

## Việc cần làm
1. Đọc `aitoolkit-schemas`, template `ccc-package.md`, các report `05/06/07`, và `lge-rules` (`ccc-checklist`).
2. Dựng **CCC checklist**: nếu `ccc-checklist` đã điền → theo đúng hạng mục LGE; nếu còn mốc → dùng checklist tối thiểu (review đạt, test đạt, gerrit sẵn sàng) và ghi chú "cần CCC checklist LGE".
3. **Thu thập evidence**: trỏ tới các report + kết quả test/review.
4. Sinh **release note nháp** + phân tích ảnh hưởng.
5. Ghi `<run_dir>/08-ccc-package.md`, `status: draft`. Trả về đường dẫn.

## Ranh giới
- Chỉ đóng gói CCC; quyết định release ở bước 09.
````

- [ ] **Step 2: Verify (review checklist)**

- [ ] `name: ccc-automation`; đọc report 05/06/07 + `lge-rules` ccc-checklist (degrade khi rỗng).
- [ ] Output `08-ccc-package.md` có checklist + evidence + release note nháp.

- [ ] **Step 3: Commit**

```bash
git add aitoolkit/skills/shared/ccc-automation/
git commit -m "feat(aitoolkit): shared 08 ccc-automation skill"
```

---

### Task 6: 09 `shared/release`

**Files:**
- Create: `aitoolkit/skills/shared/release/SKILL.md`

**Interfaces:**
- Consumes: các report `05–08`; template `release-report.md`.
- Produces: `<run_dir>/09-release-report.md` (điều kiện release, Go/No-Go, release note chốt). `status: draft`. Bước OPTIONAL, HARD gate.

- [ ] **Step 1: Viết `SKILL.md`**

````markdown
---
name: release
description: Bước 09 migration (khung dùng chung, OPTIONAL) — kiểm điều kiện release, tổng hợp Go/No-Go, chốt release note. Ghi 09-release-report.md. HARD gate PM.
---

# Shared 09 — Release

Conductor gọi với `step_id=09-release`, `run_id`, `run_dir`. Chạy INLINE. OPTIONAL. HARD gate (PM).

## Việc cần làm
1. Đọc `aitoolkit-schemas`, template `release-report.md`, các report `05–08` (08 có thể vắng nếu bị tắt).
2. Kiểm **điều kiện release**: review duyệt (05), test đạt (06), Gerrit merged (07), CCC đạt (08 nếu bật).
3. Tổng hợp **Go/No-Go** kèm lý do; chốt **release note**.
4. Ghi `<run_dir>/09-release-report.md`, `status: draft`.
5. **CHỜ HARD gate PM.** Không công bố release trước khi được duyệt.

## Ranh giới
- Nếu điều kiện chưa đạt → No-Go, nêu rõ thiếu gì; KHÔNG ép Go.
````

- [ ] **Step 2: Verify (review checklist)**

- [ ] `name: release`; đọc report 05–08 (08 optional); HARD gate nêu rõ.
- [ ] Output `09-release-report.md` có bảng điều kiện + Go/No-Go + release note.

- [ ] **Step 3: Commit**

```bash
git add aitoolkit/skills/shared/release/
git commit -m "feat(aitoolkit): shared 09 release skill"
```

---

### Task 7: 10 `shared/knowledge-base`

**Files:**
- Create: `aitoolkit/skills/shared/knowledge-base/SKILL.md`

**Interfaces:**
- Consumes: TẤT CẢ artifact của run; template `kb-entry.md`.
- Produces: `<run_dir>/10-kb-entry.md` (tóm tắt run, liên kết artifact, bài học). KHÔNG gate.

- [ ] **Step 1: Viết `SKILL.md`**

````markdown
---
name: knowledge-base
description: Bước 10 migration (khung dùng chung) — lưu trữ toàn bộ tri thức của run (tóm tắt, liên kết artifact, bài học) vào knowledge base. Ghi 10-kb-entry.md. Không gate.
---

# Shared 10 — Knowledge Base

Conductor gọi với `step_id=10-knowledge-base`, `run_id`, `run_dir`. Bước nặng → subagent. KHÔNG gate.

## Việc cần làm
1. Đọc `aitoolkit-schemas`, template `kb-entry.md`, và LIỆT KÊ mọi artifact trong `run_dir`.
2. Tổng hợp **KB entry**: tóm tắt run (workflow, kết quả Go/No-Go), bảng liên kết artifact theo bước, bài học/vấn đề & cách xử lý.
3. (Tuỳ chọn) nếu có codebase-memory-mcp: gợi ý ingest artifact để truy vấn sau.
4. Ghi `<run_dir>/10-kb-entry.md`. Đây là bước cuối — báo pipeline hoàn tất.

## Ranh giới
- Chỉ tổng hợp & lưu; không thay đổi code hay artifact bước khác.
````

- [ ] **Step 2: Verify (review checklist)**

- [ ] `name: knowledge-base`; liệt kê mọi artifact; output `10-kb-entry.md` có tóm tắt + liên kết + bài học.
- [ ] Nêu rõ không gate, là bước cuối.

- [ ] **Step 3: Commit**

```bash
git add aitoolkit/skills/shared/knowledge-base/
git commit -m "feat(aitoolkit): shared 10 knowledge-base skill"
```

---

### Task 8: Swap manifest stub → real + integration verify

**Files:**
- Modify: `aitoolkit/workflows/migration.manifest.yaml`
- Modify: `aitoolkit/docs/DRY-RUN.md`

**Interfaces:**
- Consumes: 6 shared skill (Task 2–7).
- Produces: manifest 10 bước với 05–10 trỏ `shared/<name>` thật (không còn stub). Pipeline migration đủ 10 bước thật.

- [ ] **Step 1: Thay 6 dòng skill trong manifest**

Đổi trong `aitoolkit/workflows/migration.manifest.yaml`:
- `05-ai-review`: `skill: _stub/echo-step` → `skill: shared/ai-review`
- `06-verification-testing`: → `skill: shared/verification-testing`
- `07-gerrit-automation`: → `skill: shared/gerrit-automation`
- `08-ccc-automation`: → `skill: shared/ccc-automation`
- `09-release`: → `skill: shared/release`
- `10-knowledge-base`: → `skill: shared/knowledge-base`
Giữ nguyên `isolate`, `optional`, `gate` của từng bước.

- [ ] **Step 2: Verify manifest — không còn stub, mọi skill tồn tại**

```
python3 - <<'PY'
import re,os
t=open('aitoolkit/workflows/migration.manifest.yaml').read()
assert '_stub/echo-step' not in t, "vẫn còn stub trong migration manifest"
ids=re.findall(r'id:\s*(\S+)',t); assert len(ids)==len(set(ids))==10, ids
for s in set(re.findall(r'skill:\s*(\S+)',t)):
    assert os.path.isfile(f'aitoolkit/skills/{s}/SKILL.md'), f'missing {s}'
# gate/isolate/optional giữ đúng spec §5
assert t.count('type: hard')==2, "phải có 2 HARD gate (07,09)"
assert t.count('optional: true')==2, "phải có 2 optional (08,09)"
assert 'gate: none' in t, "10 phải không gate"
print("OK: migration 10 bước thật, không stub, gate/isolate/optional đúng spec §5")
PY
```

- [ ] **Step 3: Integration dry-run (mô phỏng)** — ghi `aitoolkit/docs/DRY-RUN.md`

Cập nhật mục "Migration full pipeline": chạy `/aitoolkit:migrate migration` chạy đủ 01→10 thật; test tắt CCC/Release: `/aitoolkit:migrate migration --disable 08-ccc-automation --disable 09-release` → pipeline thành `...07 Gerrit → 10 KB`. Ở mức kiểm tra chấp nhận mô phỏng: xác nhận wiring (mọi bước trỏ skill thật) + đường tắt CCC hợp lệ. Ghi kết quả.

- [ ] **Step 4: Commit**

```bash
git add aitoolkit/workflows/migration.manifest.yaml aitoolkit/docs/DRY-RUN.md
git commit -m "feat(aitoolkit): wire shared steps 05-10 into migration manifest (full pipeline)"
```

---

## Self-Review

**1. Spec coverage:**
- §5 bước 05→Task 2; 06→Task 3; 07→Task 4; 08→Task 5; 09→Task 6; 10→Task 7. ✅
- §3 tái dùng SP: code-review (05), TDD/verification (06), finishing-branch (07). ✅
- §2.3/§8 khung dùng chung: đặt tại `skills/shared/`. ✅
- §5 gate/isolate/optional: Task 8 verify giữ đúng (2 hard, 2 optional, 10 no-gate). ✅
- Nhu cầu "chỉ Gerrit rồi KB": Task 8 Step 3 test đường `--disable 08 09`. ✅

**2. Placeholder scan:** không có TBD/TODO trong plan. Mốc «LGE team điền» là hành vi degrade của lge-rules đã mô tả, không phải placeholder. ✅

**3. Type/tên nhất quán:** artifact `05-review-report.md`/`06-verification-report.md`/`07-gerrit-report.md`/`08-ccc-package.md`/`09-release-report.md`/`10-kb-entry.md`; skill path `shared/<name>`; step id `05..10` — khớp `migration.manifest.yaml` và template. ✅

**Bàn giao:** sau 2b, để mở workflow bugfix/feature (spec §8): viết `workflows/bugfix.manifest.yaml` tái dùng `shared/05..10`, thêm vài skill `bugfix/*` nửa đầu (wrapper quanh systematic-debugging). Không đụng conductor.

# Cùng phát triển AIToolKit

Sổ tay cho người mới tham gia. Đọc hết một lượt (~10 phút) là đủ để thêm/sửa một bước mà không phá kiến trúc.

> AIToolKit là **Claude Code plugin thuần-prompt** (skill + slash command, KHÔNG script/runtime). Nó điều phối pipeline SDLC theo phong cách superpowers: mọi thứ là prompt + file `.md`.

---

## 1. Mô hình tư duy (30 giây)

```
/aitoolkit:migrate <workflow>          ┌─ nạp orchestrator skill (Bảng bước)
        │  = ORCHESTRATOR SKILL ───────┤   gọi từng step-skill theo thứ tự
        │    chạy INLINE, giữ gate     └─ theo dõi tiến độ bằng TodoWrite
        ▼
   step-skill 01 ──artifact.md──▶ step-skill 02 ──artifact.md──▶ … ──▶ KB
```

**Hai "lằn ranh" (seam) là bất biến cốt lõi — đừng phá:**

1. **Bước ↔ bước** chỉ giao tiếp qua **artifact `.md` chuẩn hoá**. Không bước nào gọi thẳng bước khác.
2. **Pipeline** khai báo trong **Bảng bước của orchestrator skill**. Orchestrator skill chỉ biết bảng bước của nó; step-skill chỉ biết artifact vào/ra của nó.

Hệ quả: **thêm workflow mới = thêm orchestrator skill + vài skill "nửa đầu", KHÔNG đụng skill khác.**

**Skill vs Subagent:** *skill* = playbook nạp vào context; *subagent* = hộp chạy cách ly (context sạch, tốn token). Một bước là một **skill**; bước nặng có thể dùng `dispatching-parallel-agents` khi cần cách ly context.

---

## 2. Bản đồ thư mục

```
aitoolkit/
├── .claude-plugin/plugin.json     # manifest plugin (name, version — BUMP mỗi lần release)
├── commands/
│   ├── migrate.md  bugfix.md  feature.md   # LAUNCHER mỏng (2 dòng): mỗi cái chỉ gọi
│   │                                       # đúng skill orchestrator tương ứng, KHÔNG chứa logic
├── skills/
│   ├── aitoolkit-schemas/         # ★ HỢP ĐỒNG DỮ LIỆU (artifact front-matter + project-profile). Đọc TRƯỚC
│   ├── aitoolkit/{migrate,bugfix,feature}/   # ★ ORCHESTRATOR thật — Bảng bước + giao thức chạy/gate
│   │                                          #   nằm trong SKILL.md, không phải ở commands/
│   ├── migration/{discovery,feature-mapping,technical-design,code-migration}/   # nửa đầu migration
│   ├── bugfix/{reproduce,root-cause,fix}/                                       # nửa đầu bugfix
│   ├── feature/{requirements,design,implement}/                                 # nửa đầu feature
│   ├── shared/{ai-review,verification-testing,gerrit-automation,               # ★ KHUNG DÙNG CHUNG
│   │           ccc-automation,release,knowledge-base}/                          #   (mọi workflow xài lại)
│   └── lge-rules/                 # rule LGE (khung rỗng, team điền)
├── templates/                     # khung .md rỗng cho từng artifact
└── CONTRIBUTING.md                # bạn đang đọc

# Khi CHẠY trên dự án thật, artifact sinh trong repo đích (KHÔNG nằm trong plugin):
<project>/docs/aitoolkit/<date>-<workflow>-<slug>/{01-....md, review-report.md, …}
```

Slash command bị namespace theo tên plugin: `/aitoolkit:migrate`, `/aitoolkit:bugfix`, `/aitoolkit:feature`. Tham số workflow gõ sau (vd `/aitoolkit:migrate migration`).

---

## 3. Vòng đời một run

1. Orchestrator skill tạo thư mục artifact `<project>/docs/aitoolkit/<date>-<workflow>-<slug>/` và ghi Bảng bước vào TodoWrite (mọi bước `pending`).
2. Với mỗi bước theo thứ tự trong **Bảng bước**: gọi step-skill inline (hoặc dispatch subagent khi cần cách ly) → nhận đường dẫn artifact vừa ghi → đánh dấu bước đó `completed` trong TodoWrite.
3. Bước có gate: orchestrator **DỪNG**, trình artifact, hỏi qua `AskUserQuestion`. Duyệt → đi tiếp; Từ chối+feedback → chạy lại đúng bước đó.
4. Chạy lại một run dở dang bằng cách trỏ orchestrator vào thư mục artifact `docs/aitoolkit/<date>-<workflow>-<slug>/` đã có — nó đọc `status` trong front-matter từng artifact (`draft`/`approved`) để biết chạy tiếp từ bước nào. HARD gate không bao giờ tự vượt.

---

## 4. Quy ước bất biến (đừng vi phạm)

| # | Quy ước | Vì sao |
|---|---|---|
| I1 | **Orchestrator skill không nhúng logic của bước.** Chỉ đọc Bảng bước + artifact. | Giữ seam 2; thêm workflow khỏi sửa step-skill |
| I2 | **Bước lấy input bước trước từ đường dẫn orchestrator truyền**, KHÔNG hardcode tên file, KHÔNG tra state lưu riêng. | Shared skill phải chạy được với mọi workflow |
| I3 | **Artifact shared đặt tên theo VAI TRÒ**, ổn định qua mọi workflow: `review-report.md`, `verification-report.md`, `gerrit-report.md`, `ccc-package.md`, `release-report.md`, `kb-entry.md`. Bước nửa đầu đặt theo bước (`01-discovery.md`). | Để nửa sau tái dùng không phụ thuộc workflow |
| I4 | **KHÔNG hardcode ngôn ngữ/lệnh** trong logic shared skill. Lấy qua **project-profile** (xem §6). | Kit dùng cho mọi ngôn ngữ, không riêng Flutter |
| I5 | **HARD gate không bao giờ tự động vượt** (Gerrit upload, Release). | Hành động không đảo ngược |
| I6 | **Frontmatter command bắt đầu bằng `[` phải QUOTE.** Chạy `claude plugin validate` TRƯỚC khi merge. | `[` bị YAML hiểu là flow-sequence → parse fail |
| I7 | **Mỗi bước ghi `status` vào front-matter artifact ngay khi xong** (`draft` → `approved` sau gate). | Để chạy tiếp một run dở dang được |

---

## 5. Công thức: thêm một workflow mới

Ví dụ thêm `hotfix`. KHÔNG đụng `commands/migrate.md`.

1. **Viết skill nửa đầu** đặc thù, vd `skills/hotfix/triage/SKILL.md` (xem §7 cho chuẩn chất lượng). Tái dùng superpowers khi hợp (bảng §8).
2. **Viết orchestrator skill** (Bảng bước + tái dùng `shared/*`): liệt kê bước nửa đầu rồi **tái dùng `shared/*`** cho nửa sau. Mỗi dòng Bảng bước ghi `id, skill, optional?, gate?`. (Tùy chọn ghi `change_type: bugfix|feature|migration` để verification chọn đúng chiến lược test.)
3. **Thêm template** cho artifact nửa đầu vào `templates/`.
4. **Wrapper command** (tùy chọn) `commands/hotfix.md`: delegate sang orchestrator skill, ép `workflow = hotfix` — copy `bugfix.md` làm mẫu. Nhớ **quote** frontmatter (I6).
5. `claude plugin validate ./aitoolkit` → **PASS mới merge**.

Xem orchestrator có sẵn (`skills/aitoolkit/bugfix/SKILL.md`) làm mẫu chuẩn — `commands/bugfix.md` chỉ là launcher 2 dòng, không có Bảng bước.

---

## 6. Language-agnostic: project-profile (cơ chế lai)

Shared skill lấy lệnh test/lint/build và mốc diff của repo theo thứ tự ưu tiên (định nghĩa ở `aitoolkit-schemas` §2):

1. **Khai báo** — file tùy chọn `<project>/docs/aitoolkit/project.yaml` (`test_cmd`, `lint_cmd`, `build_cmd`, `base_branch`, `review_focus`, `change_type`…). Team điền 1 lần.
2. **Tự dò** — theo marker file (bảng ở `skills/shared/verification-testing/command-detection.md`: `package.json`→npm, `Cargo.toml`→cargo, `pubspec.yaml`→flutter…).
3. **Hỏi gate / BLOCKED** — không dò được thì ghi rõ, để người xác nhận; **TUYỆT ĐỐI không bịa lệnh** rồi coi như đã chạy.

Khi viết shared skill mới, **luôn** đi qua profile này thay vì viết thẳng `flutter test`/`npm test`.

---

## 7. Chuẩn chất lượng một skill (đo theo superpowers)

Skill "vỏ điều phối" (chỉ "đọc template → điền → ghi") là **chưa đạt**. Một skill tốt (xem `shared/ai-review`, `shared/verification-testing` làm mẫu) cần:

- [ ] **Frontmatter**: `name` + `description` bắt đầu bằng bối cảnh kích hoạt; nêu rõ "mọi workflow, mọi ngôn ngữ" nếu là shared.
- [ ] **Core principle / Iron Law**: 1 câu chốt đáng nhớ (vd "không tuyên bố đạt nếu chưa có bằng chứng tươi").
- [ ] **Việc cần làm** đánh số, mỗi bước cụ thể — nói cả *làm thế nào*, không chỉ *làm gì* (tránh "gesture").
- [ ] **Rubric/bảng phán đoán** khi bước cần phân loại (vd Critical/Major/Minor theo blast-radius, có định nghĩa).
- [ ] **Rationalization table + Red Flags**: chặn các lối lách khi bị áp lực.
- [ ] **Hợp đồng đầu ra**: liệt kê CHÍNH XÁC những gì artifact phải chứa + verdict rõ ràng.
- [ ] **Ranh giới**: bước này KHÔNG làm gì (tránh giẫm chân bước khác).
- [ ] **Language-agnostic** (nếu shared): mô tả *vấn đề*, không phải triệu chứng của 1 ngôn ngữ; lệnh lấy qua project-profile.
- [ ] **Tái dùng superpowers** qua marker `**REQUIRED SUB-SKILL:** Use superpowers:<tên>` — KHÔNG dùng `@` (force-load, đốt context).
- [ ] **File phụ** cho phần nặng >~80 dòng (bảng tra, rubric chi tiết) — vd `command-detection.md`, `severity-rubric.md`.

Đọc `writing-skills` của superpowers để hiểu triết lý (RED-GREEN-REFACTOR cho tài liệu). Với kit này, **pragmatic** là đủ: viết theo checklist trên rồi tự review bằng 1 subagent khó tính.

---

## 8. Tận dụng superpowers (phụ thuộc có chọn lọc)

Đừng viết lại thứ superpowers đã có. Tham chiếu qua tên, để superpowers lo cơ chế:

| Nhu cầu | Skill superpowers |
|---|---|
| Spawn step-subagent cho bước nặng | `dispatching-parallel-agents`, `subagent-driven-development` |
| Cô lập workspace khi sửa code song song | `using-git-worktrees` |
| Review code (dispatch reviewer sạch context) | `requesting-code-review` / `receiving-code-review` |
| Kỷ luật bằng chứng | `verification-before-completion` |
| Viết & chạy test | `test-driven-development` |
| Truy nguyên nhân bug | `systematic-debugging` |
| Làm rõ yêu cầu | `brainstorming` |
| Kết nhánh trước Gerrit | `finishing-a-development-branch` |
| Tự viết/nâng skill của kit | `writing-skills` |

---

## 9. Vòng lặp phát triển & cạm bẫy

```
sửa file trong aitoolkit/  →  claude plugin validate ./aitoolkit  (PHẢI pass)
   →  bump version trong .claude-plugin/plugin.json
   →  claude plugin marketplace update aitoolkit-local
   →  claude plugin uninstall aitoolkit@aitoolkit-local
   →  claude plugin install  aitoolkit@aitoolkit-local
   →  mở phiên Claude Code MỚI để thử
```

**Cạm bẫy đã gặp (đừng vấp lại):**
- Claude Code **copy snapshot** vào `~/.claude/plugins/cache/…/<version>/`, KHÔNG symlink. Không bump version → snapshot cũ vẫn chạy dù đã sửa file.
- `claude plugin install` khi version chưa gỡ sẽ báo **"already installed"** và bỏ qua → phải **uninstall trước** rồi install.
- Slash command chỉ nạp khi mở **phiên mới**.
- Frontmatter YAML: giá trị bắt đầu bằng `[` phải quote (I6).
- Kit thuần-prompt: **không** có Python/pytest — "test" nghĩa là review checklist + chạy thử pipeline nhỏ, không phải chạy unit test.

Repo là git; làm trên **nhánh riêng**, `validate` xanh rồi merge `--no-ff` vào `main`.

---

## 10. Trạng thái & việc còn mở (cho người đóng góp)

**Đã xong (v0.5.0):** orchestrator skill (Bảng bước + gate + chạy tiếp một run dở dang) chắc; 3 workflow (migration/bugfix/feature) chạy thật; `shared/ai-review` + `shared/verification-testing` đã sâu tới chuẩn superpowers + language-agnostic qua project-profile.

**Việc mở — hợp để người mới nhận:**
1. **Nâng các shared skill còn "vỏ mỏng"**: `gerrit-automation`, `ccc-automation`, `release`, `knowledge-base` — theo đúng checklist §7 (Iron Law + checklist + hợp đồng đầu ra + language-agnostic).
2. **Nâng skill nửa đầu** `bugfix/*`, `feature/*`, `migration/*` tương tự.
3. **Điền `lge-rules`** khi team cung cấp (6 mục: convention, performance, security, null-safety, gerrit-commit, ccc-checklist).
4. **Chạy thử thật** cả 3 workflow trên một repo mẫu nhỏ, ghi lại kết quả/vấn đề gặp phải.

Chọn 1 mục, làm theo §5/§7, validate, mở PR/nhánh. Mỗi skill là một đơn vị độc lập nên nhiều người làm song song không đụng nhau.

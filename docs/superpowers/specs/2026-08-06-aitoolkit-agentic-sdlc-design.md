# AIToolKit — Agentic SDLC Kit (Thiết kế)

- **Ngày:** 2026-08-06
- **Trạng thái:** Design (chờ user review → writing-plans)
- **Bối cảnh:** Dự án LGE, migration webOS Native (Legacy) → Flutter (Target). Về sau mở rộng cho bugfix và tính năng mới.

## 1. Mục tiêu

Xây một **bộ kit agentic SDLC** dạng **Claude Code plugin** để chạy quy trình phát triển phần mềm thật, tận dụng AI ở mỗi bước với human gate kiểm soát. Lần đầu làm trọn **workflow migration** (10 bước theo pipeline đã thiết kế), sao cho nửa sau tự nhiên trở thành **khung dùng chung** cho bugfix / feature về sau.

## 2. Nguyên tắc thiết kế (bất biến)

1. **Điều phối bằng prompt + file**, không phải engine chạy nền. Giống superpowers.
2. **Hai lằn ranh (seam) để dễ tách khung:**
   - Mỗi bước là unit độc lập, chỉ giao tiếp qua **artifact `.md` chuẩn hoá**.
   - Thứ tự & cấu hình các bước nằm trong **manifest khai báo**, không hardcode; conductor và step không gọi thẳng nhau.
3. **Migration làm trước & trọn vẹn.** Nửa sau (bước 05→10) là khung dùng chung.
4. **Human gate khai báo theo bước** (mặc định bật; KB không gate; Gerrit-upload & Release là HARD gate; CCC & Release có thể tắt — `optional`).
5. **Phân biệt rõ:** *skill = kiến thức/playbook* (nạp vào context, tái dùng được); *subagent = hộp cách ly để chạy* (context sạch, nặng token). Một bước là một **skill**; cờ `isolate` trong manifest quyết định có bọc subagent hay không.

## 3. Quan hệ với superpowers — Lai (phụ thuộc có chọn lọc)

- **Phụ thuộc superpowers cho CƠ CHẾ:** dispatch subagent (`dispatching-parallel-agents`, `subagent-driven-development`), cô lập workspace (`using-git-worktrees`), và vài skill lõi (`systematic-debugging`, `requesting-code-review`/`receiving-code-review`, `test-driven-development`, `verification-before-completion`, `writing-skills`).
- **Tự chứa phần NGHIỆP VỤ LGE** để dễ bàn giao: rule review LGE, Gerrit automation, CCC automation, Knowledge Base, discovery/feature-mapping đặc thù webOS→Flutter.

### Bảng tái dùng skill superpowers

| Phần AIToolKit | Skill superpowers tái dùng | Cách dùng |
|---|---|---|
| Cơ chế `isolate` của conductor | `dispatching-parallel-agents`, `subagent-driven-development` | Spawn step-subagent bằng pattern có sẵn |
| Cô lập khi Code Migration (04) | `using-git-worktrees` | Bước 04 chạy trong worktree riêng |
| AI Review (05) | `requesting-code-review` + `receiving-code-review` | Wrapper mỏng + rule LGE |
| Verification & Testing (06) | `test-driven-development`, `verification-before-completion` | Không tuyên bố xong khi chưa có bằng chứng |
| Code Migration (04) | `writing-plans` → `executing-plans` | tech-design → plan → thực thi có checkpoint |
| Bugfix / root-cause (tương lai) | `systematic-debugging` | Wrapper quanh skill này |
| Feature / requirements (tương lai) | `brainstorming` | Tái dùng nguyên |
| Kết nhánh trước Gerrit (07) | `finishing-a-development-branch` | Tận dụng |
| Tự viết step-skill của kit | `writing-skills` | Dùng để build AIToolKit |

## 4. Kiến trúc & thành phần

```
aitoolkit/                          ← plugin gốc (phân phối cho team)
├── commands/
│   └── migrate.md                  ← slash /migrate = CONDUCTOR (nhạc trưởng), chạy inline
├── workflows/
│   └── migration.manifest.yaml     ← khai báo 10 bước: id, skill, gate, isolate, optional
├── skills/
│   ├── migration/
│   │   ├── discovery/              ┐
│   │   ├── feature-mapping/        │  nửa đầu — đặc thù webOS→Flutter
│   │   ├── technical-design/       │
│   │   └── code-migration/         ┘
│   ├── shared/                     ┐  nửa sau — KHUNG DÙNG CHUNG (tái dùng bugfix/feature)
│   │   ├── ai-review/              │  (05, wrapper quanh code-review SP + rule LGE)
│   │   ├── verification-testing/   │  (06)
│   │   ├── gerrit-automation/      │  (07, tự chứa)
│   │   ├── ccc-automation/         │  (08, tự chứa, optional)
│   │   ├── release/                │  (09, optional)
│   │   └── knowledge-base/         ┘  (10, tự chứa)
│   ├── lge-rules/                  ← rule LGE: convention, perf, security, null-safety
│   └── artifact-schemas/           ← định dạng chuẩn từng .md (contract giữa các bước)
└── templates/                      ← khung rỗng discovery.md, tech-design.md...

# Khi chạy trên dự án thật, artifact sinh ra trong repo dự án:
<project>/.aitoolkit/run-<id>/
├── 01-discovery.md
├── 02-mapping.md
├── ...
├── 10-... (KB entry)
└── state.json                      ← bước nào xong, đang chờ gate nào (để RESUME)
```

### Ba thành phần cốt lõi

| Thành phần | Vai trò | Tương ứng superpowers |
|---|---|---|
| **Conductor** (`/migrate`) | Đọc manifest, gọi lần lượt step-skill, dừng ở gate, quản lý `state.json` để resume. Luôn chạy inline vì phải nói chuyện với người ở mỗi gate. | Chuỗi skill hand-off |
| **Step-skill** (×10) | Nhận artifact bước trước → làm việc → ghi artifact bước sau. `isolate: true` → conductor bọc subagent (context sạch). | Skill + subagent qua tool Agent |
| **Manifest + Artifact schema** | Khai báo pipeline + hợp đồng dữ liệu giữa các bước. | design.md/plan.md làm state |

**Bất biến:** conductor chỉ biết *manifest*; mỗi step-skill chỉ biết *artifact vào/ra của nó*. Không ai gọi thẳng ai.

## 5. Manifest migration — 10 bước

`gate` = dừng hỏi người; `isolate` = bọc subagent (nặng token); `optional` = có thể tắt.

| # | Bước (skill) | Input → Output | Gate (ai duyệt) | isolate | optional |
|---|---|---|---|---|---|
| 01 | migration/discovery | Legacy source, PRD → `discovery.md` | ✅ PM/Client (xác nhận scope) | ✅ | – |
| 02 | migration/feature-mapping | `discovery.md` → `mapping.md` | ✅ Client | ✅ | – |
| 03 | migration/technical-design | `mapping.md` → `tech-design.md` | ✅ Tech Lead | ❌ inline (cần bàn) | – |
| 04 | migration/code-migration | `tech-design.md` → Flutter source + branch | ✅ Developer | ✅ (worktree) | – |
| 05 | shared/ai-review | source → `review-report.md` | ✅ Reviewer | ✅ | – |
| 06 | shared/verification-testing | source + test → `verification-report.md` | ✅ Dev/QA | ✅ | – |
| 07 | shared/gerrit-automation | reports → commit, upload Gerrit | 🔒 HARD Reviewer (không đảo ngược) | ❌ inline | – |
| 08 | shared/ccc-automation | review report → CCC package | ✅ PM/QA | ✅ | ⚙️ optional |
| 09 | shared/release | all → release note, go/no-go | 🔒 HARD PM | ❌ inline | ⚙️ optional |
| 10 | shared/knowledge-base | mọi artifact → project KB | — không gate | ✅ | – |

Ví dụ manifest (rút gọn):

```yaml
workflow: migration
steps:
  - id: 01-discovery
    skill: migration/discovery
    isolate: true
    gate: { type: soft, approver: "PM/Client", prompt: "Xác nhận scope migration?" }
  - id: 03-technical-design
    skill: migration/technical-design
    isolate: false
    gate: { type: soft, approver: "Tech Lead", prompt: "Duyệt thiết kế kỹ thuật?" }
  - id: 07-gerrit-automation
    skill: shared/gerrit-automation
    isolate: false
    gate: { type: hard, approver: "Reviewer", prompt: "Xác nhận trước khi upload Gerrit?" }
  - id: 08-ccc-automation
    skill: shared/ccc-automation
    isolate: true
    optional: true
    gate: { type: soft, approver: "PM/QA" }
  - id: 10-knowledge-base
    skill: shared/knowledge-base
    isolate: true
    gate: none
```

**Bật/tắt CCC:** bỏ `08`, `09` → pipeline thành `...→07 Gerrit→10 KB`. Đúng nhu cầu "nhiều khi chỉ Gerrit rồi KB là xong".

## 6. Luồng dữ liệu (data flow)

1. Conductor đọc manifest → xác định danh sách bước đã bật.
2. Với mỗi bước: đọc artifact bước trước (theo schema) → chạy step-skill (inline hoặc subagent theo `isolate`) → ghi artifact bước sau → cập nhật `state.json`.
3. Nếu bước có `gate`: conductor dừng, trình artifact, chờ người duyệt.
   - Duyệt → đi tiếp.
   - Từ chối (kèm feedback) → chạy lại đúng bước đó với feedback, không làm lại từ đầu.
4. Bước cuối (KB) lưu toàn bộ artifact vào knowledge base, không gate.

## 7. Xử lý lỗi & Resume

- **`state.json`** ghi: bước xong, gate đang chờ, đường dẫn artifact.
- **Subagent lỗi/chết** → conductor giữ nguyên `state.json`, báo người dùng, cho chạy lại từ bước hỏng: `/migrate --resume run-<id>`. Artifact đã duyệt trước đó không phải làm lại.
- **HARD gate** (Gerrit upload, Release) không bao giờ tự động vượt qua.
- **Idempotent:** chạy lại một bước ghi đè đúng artifact của bước đó, không nhân bản.

## 8. Mở rộng bugfix / feature (tương lai, ngoài phạm vi lần này)

Nhờ 2 seam, thêm workflow mới = **thêm 1 manifest + vài skill nửa đầu**, KHÔNG đụng khung:

```
workflows/bugfix.manifest.yaml     ← tái dùng shared/05→10, khai báo nửa đầu mới
skills/bugfix/reproduce/           ┐ skill mới (wrapper quanh systematic-debugging)
skills/bugfix/root-cause/          ┘
commands/bugfix.md                 ← conductor mới, hoặc /migrate --workflow bugfix
```

Nửa sau (`ai-review`, `verification-testing`, `gerrit`, `ccc`, `release`, `kb`) dùng lại y nguyên.

## 9. Kiểm thử (cho bản thân kit)

- **Manifest hợp lệ:** schema validation cho file manifest (id duy nhất, skill tồn tại, gate hợp lệ).
- **Artifact contract:** mỗi step-skill có ví dụ input → output khớp `artifact-schemas`.
- **Dry-run conductor:** chạy pipeline với step-skill giả (stub) sinh artifact mẫu, kiểm tra thứ tự bước, gate dừng đúng chỗ, resume hoạt động, tắt optional hoạt động.
- **End-to-end nhỏ:** một module webOS bé chạy hết 01→10 (hoặc 01→07→10 khi tắt CCC) trên repo mẫu.

## 10. Phạm vi lần này (rõ ràng)

**Trong phạm vi:** khung conductor + manifest + `state.json`/resume; 10 step-skill migration (nửa đầu tự viết, nửa sau wrapper + tự chứa); lge-rules; artifact-schemas; templates; test cho kit.

**Ngoài phạm vi:** workflow bugfix & feature (chỉ chừa seam sẵn); tích hợp sâu Jira/Figma; dashboard; bất kỳ service chạy nền nào.

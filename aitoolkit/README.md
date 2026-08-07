# AIToolKit — Agentic SDLC Kit

Bộ kit điều phối quy trình phát triển phần mềm bằng AI cho dự án LGE, dạng Claude Code plugin thuần-prompt.

## Cài đặt
Qua marketplace local `aitoolkit-local` (khai trong `.claude-plugin/marketplace.json` ở gốc repo):
```
claude plugin marketplace add <đường-dẫn-repo>
claude plugin install aitoolkit@aitoolkit-local
```
Sửa kit rồi cài lại: xem `CONTRIBUTING.md` §9 (phải bump version + uninstall/install).

## Dùng nhanh
- `/aitoolkit:migrate <workflow>` — chạy pipeline theo orchestrator skill của workflow đó.
- `/aitoolkit:bugfix`, `/aitoolkit:feature` — chạy workflow tương ứng (wrapper).
- Nói rõ trong yêu cầu để tắt một bước optional (vd CCC) — orchestrator bỏ qua bước đó khi lập Bảng bước.

Artifact mỗi lần chạy nằm ở `docs/aitoolkit/<date>-<workflow>-<slug>/`. Tùy chọn khai `docs/aitoolkit/project.yaml` để chỉ định lệnh test/lint/build (xem `aitoolkit-schemas` §2).

### Ví dụ: chỉ chạy tới Gerrit rồi KB (bỏ CCC & Release)
```
/aitoolkit:migrate migration, bỏ qua bước 08 CCC và 09 Release
```

## Pipeline migration (10 bước)
```
01 Discovery → 02 Feature Mapping → 03 Technical Design → 04 Code Migration
→ 05 AI Review → 06 Verification & Testing → 07 Gerrit → [08 CCC*] → [09 Release*] → 10 Knowledge Base
                                                          (* optional, tắt được)
```
Mỗi bước có human gate khai trong orchestrator skill (Bảng bước); Gerrit/Release là HARD gate; KB không gate. Chi tiết: spec §5.

## Chạy trên Codex (không phải Claude Code)
Kit thuần-prompt nên chạy được trên **OpenAI Codex CLI**, nhưng Codex không có `claude plugin install`/slash-command custom. Dùng **AGENTS.md bootstrap** hoặc cài như **skill Codex** (`$aitoolkit <workflow>`). Xem `docs/RUN-ON-CODEX.md` + `codex/`.

## Cùng phát triển
- **`CONTRIBUTING.md`** — sổ tay đóng góp: bản đồ thư mục, quy ước bất biến, công thức thêm workflow / nâng skill, cạm bẫy. **Đọc đầu tiên.**
- **Kiến trúc/thiết kế:** `docs/superpowers/specs/2026-08-06-aitoolkit-agentic-sdlc-design.md`.
- **Hợp đồng dữ liệu:** skill `aitoolkit-schemas`. · **Chạy trên Codex:** `docs/RUN-ON-CODEX.md`.

## Workflow có sẵn
- **migration** (`/aitoolkit:migrate migration`) — 10 bước: 01–04 `migration/*` + 05–10 `shared/*`.
- **bugfix** (`/aitoolkit:bugfix`) — 9 bước: 01 Reproduce → 02 Root Cause → 03 Fix (`bugfix/*`) → 04–09 tái dùng `shared/*` (Review → Test → Gerrit → CCC* → Release* → KB).
- **feature** (`/aitoolkit:feature`) — 9 bước: 01 Requirements → 02 Design → 03 Implement (`feature/*`) → 04–09 tái dùng `shared/*`.

Cả ba chung khung `shared/*`. Thêm workflow mới = thêm orchestrator skill + vài step-skill nửa đầu.

> **Trạng thái (v0.5.0):** 3 workflow chạy thật. `shared/*` workflow-agnostic (artifact đặt tên theo vai trò) và language-agnostic (lệnh lấy qua project-profile). `shared/ai-review` + `shared/verification-testing` đã đạt chuẩn chất lượng; các shared skill khác còn mỏng (roadmap ở `CONTRIBUTING.md` §10). `lge-rules` là khung — team điền để các bước áp rule thật.

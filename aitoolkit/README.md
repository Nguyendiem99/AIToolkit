# AIToolKit — Agentic SDLC Kit

Bộ kit điều phối quy trình phát triển phần mềm bằng AI cho dự án LGE, dạng Claude Code plugin thuần-prompt.

## Cài đặt
Thêm `aitoolkit/` vào danh sách plugin của Claude Code (marketplace nội bộ hoặc symlink vào `~/.claude/plugins`).

## Dùng nhanh
- `/migrate <workflow>` — chạy một pipeline theo manifest trong `workflows/<workflow>.manifest.yaml`.
- `/migrate --resume run-<id>` — chạy tiếp một run đang dở.
- `/migrate <workflow> --disable <step-id>` — tắt một bước optional (vd CCC).

Artifact mỗi lần chạy nằm ở `<project>/.aitoolkit/run-<id>/`.

### Ví dụ: chỉ chạy tới Gerrit rồi KB (bỏ CCC & Release)
```
/migrate migration --disable 08-ccc-automation --disable 09-release
```

## Pipeline migration (10 bước)
```
01 Discovery → 02 Feature Mapping → 03 Technical Design → 04 Code Migration
→ 05 AI Review → 06 Verification & Testing → 07 Gerrit → [08 CCC*] → [09 Release*] → 10 Knowledge Base
                                                          (* optional, tắt được)
```
Mỗi bước có human gate khai báo trong `workflows/migration.manifest.yaml`; Gerrit/Release là HARD gate; KB không gate. Chi tiết: spec §5.

## Test engine
Xem `docs/DRY-RUN.md` — kịch bản dry-run A/B/C dùng manifest `_dryrun` + stub.

## Kiến trúc
Xem `docs/superpowers/specs/2026-08-06-aitoolkit-agentic-sdlc-design.md`.

## Workflow có sẵn
- **migration** (`/aitoolkit:migrate migration`) — 10 bước: 01–04 `migration/*` + 05–10 `shared/*`.
- **bugfix** (`/aitoolkit:bugfix`) — 9 bước: 01 Reproduce → 02 Root Cause → 03 Fix (`bugfix/*`) → 04–09 tái dùng `shared/*` (Review → Test → Gerrit → CCC* → Release* → KB).

Cả hai chung một engine (conductor) + chung khung `shared/*`. Thêm workflow mới = thêm manifest + vài skill nửa đầu, không sửa conductor.

> **Trạng thái:** migration (10 bước) + bugfix (9 bước) đều chạy thật. `shared/*` workflow-agnostic (artifact đặt tên theo vai trò). `lge-rules` là khung — team điền để các bước áp rule thật.

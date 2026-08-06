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

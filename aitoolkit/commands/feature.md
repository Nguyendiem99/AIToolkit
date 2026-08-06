---
description: "Chạy pipeline tính năng mới của AIToolKit (requirements → design → implement → review → test → gerrit → CCC → release → KB)."
argument-hint: "[--resume run-<id>] [--disable <step-id>]"
---

# /feature — AIToolKit Conductor (workflow feature)

Đây là conductor cho workflow **feature** (tính năng mới). Hành xử **y hệt** conductor `aitoolkit:migrate` — chỉ khác **workflow mặc định = `feature`** (đọc `aitoolkit/workflows/feature.manifest.yaml`).

## Cách làm
1. Đọc file `commands/migrate.md` của plugin này và làm theo TOÀN BỘ quy trình trong đó (đọc `aitoolkit-schemas`, khởi tạo run, vòng lặp chạy bước, human gate qua AskUserQuestion, resume, optional/--disable, isolate→subagent, xử lý lỗi).
2. Ép `workflow = feature`. `$ARGUMENTS` chỉ dùng cho `--resume run-<id>` và `--disable <step-id>`.

Không lặp lại logic ở đây — engine điều phối là một, chỉ đổi manifest đầu vào.

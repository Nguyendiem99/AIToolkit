---
description: "Chạy pipeline bugfix của AIToolKit (reproduce → root-cause → fix → review → test → gerrit → CCC → release → KB)."
argument-hint: "[--resume run-<id>] [--disable <step-id>]"
---

# /bugfix — AIToolKit Conductor (workflow bugfix)

Đây là conductor cho workflow **bugfix**. Hành xử **y hệt** conductor `aitoolkit:migrate` — chỉ khác **workflow mặc định = `bugfix`** (đọc `aitoolkit/workflows/bugfix.manifest.yaml`).

## Cách làm
1. Đọc file `commands/migrate.md` của plugin này và làm theo TOÀN BỘ quy trình trong đó (đọc `aitoolkit-schemas`, khởi tạo run, vòng lặp chạy bước, human gate qua AskUserQuestion, resume, optional/--disable, isolate→subagent, xử lý lỗi).
2. Ép `workflow = bugfix` (bỏ qua `$1` làm tên workflow). `$ARGUMENTS` chỉ dùng cho `--resume run-<id>` và `--disable <step-id>`.

Không lặp lại logic ở đây để tránh trùng lặp — engine điều phối là một, chỉ đổi manifest đầu vào.

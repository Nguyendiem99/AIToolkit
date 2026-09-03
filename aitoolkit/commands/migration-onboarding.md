---
description: Khảo sát dự án và tạo project profile/project pack cho migration theo evidence.
argument-hint: "--legacy <path> --target <path> [--requirements <path> ...] [--uiux <path> ...] [--migration-docs <path> ...] [--architecture-docs <path> ...]"
---

# /migration-onboarding — AIToolKit

Chỉ delegate tới skill **`aitoolkit/migration-onboarding`** và làm theo toàn bộ giao thức trong đó. Chuyển nguyên `$ARGUMENTS` làm các path đầu vào; nếu thiếu hoặc mơ hồ, skill sẽ hỏi trước khi chạy.

## Argument contract

Derive `<project>` from the current target-project context; project root is not an argument. The accepted flags are `--legacy`, `--target`, `--requirements`, `--uiux`, `--migration-docs`, and `--architecture-docs`. Parse `$ARGUMENTS` as `--legacy <path>` and `--target <path>` plus the four repeatable document flags. Every document value may identify a file or directory; do not accept positional paths.

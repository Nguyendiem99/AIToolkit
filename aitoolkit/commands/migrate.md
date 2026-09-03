---
description: Chạy pipeline migration language-agnostic của AIToolKit (kiểu Superpowers).
argument-hint: "[--auto | --auto-waive] [tên-tính-năng]"
---

# /migrate — AIToolKit

Chỉ delegate tới skill **`aitoolkit/migrate`** và làm theo toàn bộ giao thức trong đó.

Từ `$ARGUMENTS`, chấp nhận `--auto` hoặc `--auto-waive` và forward the selected flag unchanged tới orchestrator. Nếu cả hai flag cùng xuất hiện, forward both unchanged để orchestrator chặn xung đột trước step 01. Phần đối số không phải flag được dùng làm `<slug>`/tên tính năng migrate; nếu không có slug, skill sẽ hỏi.

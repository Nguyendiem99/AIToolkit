---
name: aitoolkit
description: Use when running an AIToolkit SDLC pipeline (migrate, bugfix, or feature) on Codex. Invoke as `$aitoolkit <migrate|bugfix|feature> [tên-tính-năng]`.
---

# AIToolkit orchestrator (bản Codex)

Bạn là **orchestrator** của một pipeline SDLC khai báo bằng skill. Đây là bản bootstrap để chạy trên Codex — logic thật nằm trong repo AIToolkit, đọc từ đó để tránh trùng lặp.

## Cấu hình (sửa 1 lần sau khi copy vào ~/.codex/skills/)

- **AITOOLKIT_HOME:** `/ĐỔI/THÀNH/ĐƯỜNG-DẪN/AIToolkit`  ← trỏ tới clone thật của repo AIToolkit

## Việc cần làm

1. Tham số sau `$aitoolkit` là **tên workflow** (`migrate` | `bugfix` | `feature`) kèm tên-tính-năng tùy chọn. Nếu trống → hỏi người dùng chạy workflow nào.
2. Đọc `AITOOLKIT_HOME/aitoolkit/skills/aitoolkit-schemas/SKILL.md` (hợp đồng dữ liệu) TRƯỚC.
3. Đọc `AITOOLKIT_HOME/aitoolkit/skills/aitoolkit/<workflow>/SKILL.md` và **làm theo đúng Bảng bước + Giao thức** trong đó (khởi tạo run, vòng lặp bước, gate, lỗi step).
4. Step-skill liên quan: `AITOOLKIT_HOME/aitoolkit/skills/<skill>/SKILL.md`.
5. **Ghi artifact vào `TARGET_PROJECT/docs/aitoolkit/<date>-<workflow>-<slug>/`** của PROJECT hiện tại (nơi người dùng đang làm việc), KHÔNG ghi vào AITOOLKIT_HOME.

## Khác biệt runtime (tuân thủ)

- **Gate:** không có `AskUserQuestion` → hỏi bằng **text**, nêu lựa chọn rõ (Duyệt / Từ chối+feedback). **HARD gate không bao giờ tự vượt** — chờ xác nhận tường minh.
- **Lệnh test/lint/build:** theo project-profile (`aitoolkit-schemas` §2): `TARGET_PROJECT/docs/aitoolkit/project.yaml` → tự dò marker file → hỏi nếu không rõ. KHÔNG bịa lệnh.
- Shared skill tham chiếu `superpowers:*` — cần superpowers bản Codex đã cài.

## Ranh giới

Bạn chỉ điều phối theo skill workflow + artifact; không nhúng logic của bất kỳ bước nào.

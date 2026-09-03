<!-- ▼▼▼ Dán khối này vào AGENTS.md ở gốc PROJECT ĐÍCH (project bạn muốn chạy pipeline).
        Sửa AITOOLKIT_HOME thành đường dẫn clone thật của repo AIToolkit. ▼▼▼ -->

## AIToolkit — chạy pipeline SDLC (agentic)

Project này có thể chạy workflow của AIToolkit: `migrate`, `bugfix`, `feature`.

- **AITOOLKIT_HOME:** `/ĐỔI/THÀNH/ĐƯỜNG-DẪN/AIToolkit`  ← sửa dòng này

**Khi tôi yêu cầu chạy một workflow** (vd "chạy workflow bugfix"):
1. Đóng vai **orchestrator (nhạc trưởng)**: đọc `AITOOLKIT_HOME/aitoolkit/skills/aitoolkit/<workflow>/SKILL.md` và **làm theo đúng Bảng bước + Giao thức** trong đó.
2. Đọc trước `AITOOLKIT_HOME/aitoolkit/skills/aitoolkit-schemas/SKILL.md` (hợp đồng dữ liệu: artifact / project-profile).
3. Step-skill ở `AITOOLKIT_HOME/aitoolkit/skills/`.
4. **Ghi artifact vào `./docs/aitoolkit/<date>-<workflow>-<slug>/` của PROJECT NÀY** (không ghi vào AITOOLKIT_HOME).
5. **Gate:** runtime này không có `AskUserQuestion` → hỏi tôi bằng **text**, đưa lựa chọn rõ ràng (Duyệt / Từ chối+feedback). **HARD gate không bao giờ tự vượt** — chờ tôi xác nhận tường minh.
6. Lệnh test/lint/build lấy theo **project-profile**: đọc `./docs/aitoolkit/project.yaml` nếu có → tự dò marker file → hỏi tôi nếu không rõ (KHÔNG bịa lệnh).

<!-- ▲▲▲ Hết khối AIToolkit ▲▲▲ -->

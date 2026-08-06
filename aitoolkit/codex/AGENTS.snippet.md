<!-- ▼▼▼ Dán khối này vào AGENTS.md ở gốc PROJECT ĐÍCH (project bạn muốn chạy pipeline).
        Sửa AITOOLKIT_HOME thành đường dẫn clone thật của repo AIToolkit. ▼▼▼ -->

## AIToolkit — chạy pipeline SDLC (agentic)

Project này có thể chạy workflow của AIToolkit: `migration`, `bugfix`, `feature`, và `_dryrun` (test engine).

- **AITOOLKIT_HOME:** `/ĐỔI/THÀNH/ĐƯỜNG-DẪN/AIToolkit`  ← sửa dòng này

**Khi tôi yêu cầu chạy một workflow** (vd "chạy workflow bugfix", "chạy `_dryrun`", "resume run-<id>"):
1. Đóng vai **conductor (nhạc trưởng)**: đọc `AITOOLKIT_HOME/aitoolkit/commands/migrate.md` và **làm theo đúng từng mục**.
2. Đọc trước `AITOOLKIT_HOME/aitoolkit/skills/aitoolkit-schemas/SKILL.md` (hợp đồng dữ liệu: artifact / manifest / state / project-profile).
3. Manifest ở `AITOOLKIT_HOME/aitoolkit/workflows/<workflow>.manifest.yaml`; step-skill ở `AITOOLKIT_HOME/aitoolkit/skills/`.
4. **Ghi artifact + `state.json` vào `./.aitoolkit/run-<id>/` của PROJECT NÀY** (không ghi vào AITOOLKIT_HOME).
5. **Gate:** runtime này không có `AskUserQuestion` → hỏi tôi bằng **text**, đưa lựa chọn rõ ràng (Duyệt / Từ chối+feedback). **HARD gate không bao giờ tự vượt** — chờ tôi xác nhận tường minh.
6. **Bước `isolate: true`:** nếu `~/.codex/config.toml` có `[features] multi_agent = true` thì spawn subagent; nếu không, chạy inline.
7. Lệnh test/lint/build lấy theo **project-profile**: đọc `./.aitoolkit/project.yaml` nếu có → tự dò marker file → hỏi tôi nếu không rõ (KHÔNG bịa lệnh).

<!-- ▲▲▲ Hết khối AIToolkit ▲▲▲ -->

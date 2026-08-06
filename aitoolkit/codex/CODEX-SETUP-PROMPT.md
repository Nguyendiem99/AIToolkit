# Runbook cho Codex: tự cài & chạy AIToolkit

> **Cách dùng (con người):** mở Codex trong project bạn muốn chạy pipeline, rồi dán TOÀN BỘ nội dung dưới đường kẻ cho Codex. Codex sẽ tự làm từ đầu tới lúc verify xong.

---

Bạn (Codex) sẽ cài đặt và chạy thử **AIToolkit** — một bộ kit điều phối pipeline SDLC thuần-prompt. Làm tuần tự các pha sau. Ở mỗi chỗ cần quyết định của con người thì DỪNG và hỏi ngắn gọn; còn lại tự làm.

## Pha 0 — Thu thập đầu vào (hỏi tôi nếu chưa rõ)
1. **AITOOLKIT_HOME**: đường dẫn tới clone của repo AIToolkit. Nếu tôi chưa có, hãy clone:
   ```bash
   git clone https://github.com/Nguyendiem99/AIToolkit.git
   # nếu lỗi auth (repo private): hỏi tôi URL/SSH hoặc cách truy cập
   ```
   Đặt `AITOOLKIT_HOME` = đường dẫn tuyệt đối tới thư mục `AIToolkit` vừa có. Xác nhận tồn tại `AITOOLKIT_HOME/aitoolkit/commands/migrate.md`.
2. **TARGET_PROJECT**: thư mục project tôi đang muốn chạy pipeline (thường là CWD hiện tại). Artifact sẽ ghi vào `TARGET_PROJECT/.aitoolkit/`, KHÔNG ghi vào AITOOLKIT_HOME.

## Pha 1 — Kiểm tra & bật điều kiện
1. **Multi-agent** (cho bước `isolate`): đọc `~/.codex/config.toml`. Nếu chưa có, đề xuất thêm rồi (khi tôi đồng ý) ghi:
   ```toml
   [features]
   multi_agent = true
   ```
   Nếu tôi không muốn bật: ghi nhớ rằng các bước `isolate: true` sẽ chạy **inline**.
2. **Superpowers (bản Codex)**: các bước `shared/*` tham chiếu `superpowers:*`. Kiểm tra bằng `/skills` hoặc hỏi tôi đã cài chưa. Chưa có thì vẫn chạy được workflow `_dryrun` (không cần superpowers) — cứ tiếp tục và cảnh báo tôi trước khi chạy workflow thật.

## Pha 2 — Nối bootstrap vào project (để lần sau tự nhận)
1. Mở/tạo `TARGET_PROJECT/AGENTS.md`.
2. Chèn nội dung file `AITOOLKIT_HOME/aitoolkit/codex/AGENTS.snippet.md`, thay `AITOOLKIT_HOME` bằng đường dẫn thật. (Nếu AGENTS.md đã có, chỉ thêm khối AIToolkit, đừng xoá phần khác.)
3. (Tùy chọn, nếu tôi muốn gọi bằng `$aitoolkit`): 
   ```bash
   mkdir -p ~/.codex/skills && cp -r "$AITOOLKIT_HOME/aitoolkit/codex/skills/aitoolkit" ~/.codex/skills/
   ```
   rồi sửa dòng `AITOOLKIT_HOME` trong `~/.codex/skills/aitoolkit/SKILL.md`.

## Pha 3 — Verify bằng dry-run (BẮT BUỘC trước khi chạy thật)
Chạy workflow `_dryrun` bằng cách đóng vai **conductor**:
1. Đọc `AITOOLKIT_HOME/aitoolkit/skills/aitoolkit-schemas/SKILL.md` (hợp đồng dữ liệu) TRƯỚC.
2. Đọc `AITOOLKIT_HOME/aitoolkit/commands/migrate.md` và làm theo đúng từng mục, với `workflow = _dryrun` (manifest: `AITOOLKIT_HOME/aitoolkit/workflows/_dryrun.manifest.yaml`).
3. Ghi artifact + `state.json` vào `TARGET_PROJECT/.aitoolkit/run-<id>/`.
4. Xác nhận từng hành vi engine và báo cáo cho tôi:
   - soft gate → hỏi tôi bằng **text** (Duyệt / Từ chối+feedback);
   - `s2-isolate` → spawn subagent nếu multi_agent bật, không thì inline;
   - `s3-optional` → thử bỏ qua khi tôi truyền `--disable s3-optional`;
   - `s4-hard` → **HARD gate: KHÔNG tự vượt**, chờ tôi xác nhận tường minh;
   - `s5-nogate` → chạy thẳng;
   - dừng giữa chừng rồi chứng minh `--resume run-<id>` chạy tiếp từ đúng bước dở.

## Pha 4 — Báo cáo & sẵn sàng chạy thật
Tóm tắt: AITOOLKIT_HOME, trạng thái multi_agent, superpowers, kết quả dry-run (bước nào pass, state.json ở đâu). Rồi hướng dẫn tôi chạy thật:
- `_dryrun` OK → chạy `bugfix` / `feature` / `migration` bằng đúng conductor trên.
- Nếu project không phải Flutter: tạo `TARGET_PROJECT/.aitoolkit/project.yaml` khai `test_cmd`/`lint_cmd`/`build_cmd`/`base_branch` (xem `aitoolkit-schemas` §4); không khai thì các bước tự dò marker file, không dò được thì hỏi tôi — KHÔNG bịa lệnh.

## Quy tắc bất biến (tuân thủ suốt)
- **HARD gate không bao giờ tự vượt** (Gerrit upload, Release) — luôn chờ tôi xác nhận tường minh.
- Gate hỏi bằng **text** (runtime này không có AskUserQuestion).
- Chỉ điều phối theo manifest + artifact; KHÔNG nhúng logic của bước. Mọi thay đổi trạng thái ghi ngay vào `state.json`.
- KHÔNG sửa gì trong AITOOLKIT_HOME; mọi output nằm trong TARGET_PROJECT/.aitoolkit/.
- Sandbox chặn tạo nhánh/push (detached HEAD) → commit tại chỗ, báo tôi dùng "Create branch"/"Hand off to local".

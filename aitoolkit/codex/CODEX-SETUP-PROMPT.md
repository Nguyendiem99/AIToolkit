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
   Đặt `AITOOLKIT_HOME` = đường dẫn tuyệt đối tới thư mục `AIToolkit` vừa có. Xác nhận tồn tại `AITOOLKIT_HOME/aitoolkit/skills/aitoolkit/`.
2. **TARGET_PROJECT**: thư mục project tôi đang muốn chạy pipeline (thường là CWD hiện tại). Artifact sẽ ghi vào `TARGET_PROJECT/docs/aitoolkit/`, KHÔNG ghi vào AITOOLKIT_HOME.

## Pha 1 — Kiểm tra & bật điều kiện
1. **Superpowers (bản Codex)**: các bước `shared/*` tham chiếu `superpowers:*`. Kiểm tra bằng `/skills` hoặc hỏi tôi đã cài chưa. Chưa có thì cảnh báo tôi trước khi chạy workflow thật.

## Pha 2 — Nối bootstrap vào project (để lần sau tự nhận)
1. Mở/tạo `TARGET_PROJECT/AGENTS.md`.
2. Chèn nội dung file `AITOOLKIT_HOME/aitoolkit/codex/AGENTS.snippet.md`, thay `AITOOLKIT_HOME` bằng đường dẫn thật. (Nếu AGENTS.md đã có, chỉ thêm khối AIToolkit, đừng xoá phần khác.)
3. **Đăng ký skill vào Codex** (để hiện trong `/skills` và gọi bằng `$aitoolkit`). Đăng ký CẢ CÂY `skills/`, không chỉ orchestrator:
   ```bash
   mkdir -p ~/.codex/skills
   find "$AITOOLKIT_HOME/aitoolkit/skills" -name SKILL.md \
     -exec dirname {} \; | while read d; do ln -sf "$d" ~/.codex/skills/"$(basename "$d")"; done
   ln -sf "$AITOOLKIT_HOME/aitoolkit/codex/skills/aitoolkit" ~/.codex/skills/aitoolkit
   ```
   Sửa dòng `AITOOLKIT_HOME` trong `~/.codex/skills/aitoolkit/SKILL.md`. Chạy `/skills` và xác nhận thấy `aitoolkit`, `ai-review`, `verification-testing`, `discovery`, … Nếu thiếu, kiểm tra lại cách Codex quét `~/.codex/skills/` rồi điều chỉnh. (Ghi chú: để CHẠY pipeline chỉ cần `$aitoolkit`; đăng ký cả cây chỉ để nhìn/gọi được từng skill.)

## Pha 3 — Verify bằng cách chạy thử một workflow nhỏ, dừng ở gate đầu
Chọn một workflow nhẹ (vd `bugfix`) và đóng vai **orchestrator**:
1. Đọc `AITOOLKIT_HOME/aitoolkit/skills/aitoolkit-schemas/SKILL.md` (hợp đồng dữ liệu) TRƯỚC.
2. Đọc `AITOOLKIT_HOME/aitoolkit/skills/aitoolkit/<workflow>/SKILL.md` và làm theo đúng Bảng bước + Giao thức trong đó.
3. Ghi artifact vào `TARGET_PROJECT/docs/aitoolkit/<date>-<workflow>-<slug>/`.
4. Chạy tới **gate đầu tiên** rồi DỪNG lại, báo cáo cho tôi:
   - hỏi tôi bằng **text** (Duyệt / Từ chối+feedback) nếu là soft gate;
   - nếu là HARD gate: xác nhận rõ là **KHÔNG tự vượt**, chờ tôi xác nhận tường minh trước khi đi tiếp.

## Pha 4 — Báo cáo & sẵn sàng chạy thật
Tóm tắt: AITOOLKIT_HOME, trạng thái superpowers, kết quả verify (bước nào đã chạy tới đâu, artifact ở đâu). Rồi hướng dẫn tôi chạy thật:
- Verify OK → chạy `bugfix` / `feature` / `migrate` bằng đúng orchestrator trên.
- Nếu project không phải Flutter: tạo `TARGET_PROJECT/docs/aitoolkit/project.yaml` khai `test_cmd`/`lint_cmd`/`build_cmd`/`base_branch` (xem `aitoolkit-schemas` §2); không khai thì các bước tự dò marker file, không dò được thì hỏi tôi — KHÔNG bịa lệnh.

## Quy tắc bất biến (tuân thủ suốt)
- **HARD gate không bao giờ tự vượt** (Gerrit upload, Release) — luôn chờ tôi xác nhận tường minh.
- Gate hỏi bằng **text** (runtime này không có AskUserQuestion).
- Chỉ điều phối theo skill workflow + artifact; KHÔNG nhúng logic của bước.
- KHÔNG sửa gì trong AITOOLKIT_HOME; mọi output nằm trong TARGET_PROJECT/docs/aitoolkit/.
- Sandbox chặn tạo nhánh/push (detached HEAD) → commit tại chỗ, báo tôi dùng "Create branch"/"Hand off to local".

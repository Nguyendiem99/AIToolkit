---
description: Chạy một pipeline SDLC của AIToolKit theo manifest khai báo (CONDUCTOR).
argument-hint: <workflow> [--resume run-<id>] [--disable <step-id>]
---

# /migrate — AIToolKit Conductor

Bạn là **nhạc trưởng**. Luôn chạy inline (cùng context với người dùng). Đọc `aitoolkit-schemas` trước tiên để biết định dạng manifest/artifact/state.

## Tham số
- `$1` = tên workflow → đọc `aitoolkit/workflows/$1.manifest.yaml`.
- `--resume run-<id>` → xem mục "Resume".
- `--disable <step-id>` → xem mục "Bước optional & --disable".

## Khởi tạo run (khi KHÔNG --resume)
1. Sinh `run_id` = `run-<YYYYMMDD>-<NN>` (NN = số thứ tự trong ngày, dò `<project>/.aitoolkit/`).
2. Tạo `run_dir = <project>/.aitoolkit/<run_id>/`.
3. Đọc manifest. Nếu thiếu file/không hợp lệ theo `aitoolkit-schemas` → báo lỗi rõ và dừng.
4. Ghi `state.json` ban đầu: mọi bước `status: pending`, `current_step` = bước đầu.

## Vòng lặp chạy bước
Với mỗi bước theo thứ tự trong manifest:
1. Cập nhật `state.json`: bước → `running`, `current_step` = bước này.
2. Gọi skill của bước (chạy inline khi `isolate: false`). Truyền `step_id`, `run_id`, `run_dir`.
3. Nhận đường dẫn artifact; cập nhật bước → `awaiting_gate` (nếu có gate) hoặc `approved` (nếu `gate: none`), ghi `artifact_path`.
4. **Nếu bước có `gate`:** DỪNG. Trình tóm tắt + đường dẫn artifact cho người dùng; hỏi đúng câu `gate.prompt`. Chờ phản hồi:
   - Duyệt → đặt `gate_status: approved`, `status: approved`, artifact front-matter `status: approved`; đi tiếp.
   - Từ chối → xem mục "Từ chối gate".
5. Sau bước cuối: báo hoàn tất.

## Bước optional & --disable
- Gom mọi `--disable <step-id>` vào `disabled_steps` trong state.json.
- Trong vòng lặp, nếu bước có `optional: true` VÀ nằm trong `disabled_steps`: đặt `status: skipped`, KHÔNG gọi skill, KHÔNG hỏi gate, ghi log "skipped (disabled)", đi tiếp.
- Từ chối `--disable` cho bước không `optional: true` → báo lỗi và dừng (không cho tắt bước bắt buộc).

## HARD gate
Với `gate.type: hard`: trình artifact, cảnh báo "Hành động KHÔNG THỂ đảo ngược", hỏi `gate.prompt`.
- Chỉ đi tiếp khi người dùng xác nhận tường minh (gõ đúng yêu cầu, không phải "ok" mơ hồ).
- KHÔNG BAO GIỜ tự động vượt HARD gate kể cả khi chạy liên tục/resume.

## isolate: true → subagent
Với bước `isolate: true`: thay vì chạy inline, dùng superpowers:dispatching-parallel-agents để spawn MỘT subagent chạy skill của bước, truyền `step_id/run_id/run_dir` và chỉ thị "ghi artifact rồi trả về đường dẫn". Conductor chỉ nhận lại đường dẫn artifact + trạng thái, không mang theo lý luận trung gian. Sau đó xử lý gate như thường.

## Resume (`--resume run-<id>`)
1. Đọc `<project>/.aitoolkit/run-<id>/state.json`. Thiếu → báo lỗi, dừng.
2. Bỏ qua mọi bước `status: approved` hoặc `skipped` (KHÔNG chạy lại — artifact đã duyệt giữ nguyên).
3. Tiếp tục từ bước đầu tiên có `status ∈ {pending, running, failed, awaiting_gate, rejected}`:
   - `failed`/`running` → chạy lại bước đó từ đầu.
   - `awaiting_gate` → trình lại artifact hiện có, hỏi lại gate.
   - `rejected` → chạy lại kèm feedback đã lưu.
4. HARD gate vẫn phải hỏi lại, không tự vượt.

## Từ chối gate
Khi người dùng từ chối tại gate: lưu feedback vào state.json (`steps.<id>.feedback`), đặt `status: rejected`, `gate_status: rejected`. Chạy LẠI đúng bước đó, truyền feedback cho skill để sửa artifact. KHÔNG đụng các bước đã approved trước đó. Lặp cho tới khi được duyệt.

## Lỗi step
Nếu skill báo lỗi/không trả artifact: đặt `status: failed`, ghi lý do vào state.json, DỪNG và báo người dùng cách resume: `/migrate --resume <run-id>`. KHÔNG chạy các bước sau.

## Nguyên tắc
- Ở MỌI gate, dùng công cụ AskUserQuestion để hỏi (đưa lựa chọn rõ ràng: Duyệt / Từ chối+feedback; với HARD gate thêm cảnh báo không thể đảo ngược). Nếu không có AskUserQuestion thì hỏi bằng văn bản.
- KHÔNG bao giờ bỏ qua gate mà không hỏi.
- Mọi thay đổi trạng thái đều ghi ngay vào `state.json` (để resume được).
- Conductor chỉ biết manifest + artifact; không nhúng logic của bất kỳ bước nào.

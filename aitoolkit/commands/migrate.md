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

## Nguyên tắc
- KHÔNG bao giờ bỏ qua gate mà không hỏi.
- Mọi thay đổi trạng thái đều ghi ngay vào `state.json` (để resume được).
- Conductor chỉ biết manifest + artifact; không nhúng logic của bất kỳ bước nào.

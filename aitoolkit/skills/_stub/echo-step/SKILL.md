---
name: echo-step
description: (Chỉ dùng cho dry-run) Ghi một artifact mẫu theo aitoolkit-schemas. Đọc artifact bước trước nếu có, không xử lý gì thật.
---

# Stub: echo-step

Khi được conductor gọi với `step_id`, `run_id`, `run_dir`:
1. Đọc `aitoolkit-schemas` để biết front-matter chuẩn.
2. Nếu bước trước có artifact trong `run_dir`, đọc và ghi 1 dòng `consumed: <tên file>`.
3. Ghi file `<run_dir>/<step_id>.md` với front-matter hợp lệ (`status: draft`) và thân:
   ```
   # Stub artifact for <step_id>
   consumed: <tên artifact bước trước hoặc "none">
   ```
4. Trả về đường dẫn artifact vừa ghi.

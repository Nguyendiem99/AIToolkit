---
name: requirements
description: Bước 01 feature — làm rõ yêu cầu tính năng mới (vấn đề, đối tượng, user stories, phạm vi, ràng buộc) qua brainstorming. Ghi 01-requirements.md.
---

# Feature 01 — Requirements

Orchestrator gọi skill này, truyền: `run_dir` + mô tả tính năng do người dùng cung cấp. Chạy inline — orchestrator dừng ở gate PM/Client.

## Việc cần làm
1. Đọc `aitoolkit-schemas`, template `aitoolkit/templates/requirements.md`.
2. Dùng superpowers:brainstorming để khai thác ý định & yêu cầu: vấn đề đang giải quyết, cho ai, tiêu chí thành công, user stories, phạm vi (YAGNI ruthlessly), ràng buộc & rủi ro.
3. Ghi `<run_dir>/01-requirements.md` theo template, `status: draft`.

## Ranh giới
- CHỈ làm rõ yêu cầu; CHƯA thiết kế kỹ thuật (bước 02), CHƯA code (bước 03).
- Cắt tính năng thừa (YAGNI); mục chưa rõ thì hỏi, KHÔNG tự quyết thay người dùng.

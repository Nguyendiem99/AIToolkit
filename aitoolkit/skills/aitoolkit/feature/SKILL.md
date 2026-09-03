---
name: feature
description: Orchestrator pipeline tính năng mới của AIToolKit (9 bước requirements→design→implement→review→test→gerrit→CCC→release→KB). Gọi step-skill tuần tự, dừng ở human gate. Kiểu Superpowers — không dùng engine/kho trạng thái tập trung.
---

# AIToolKit — Feature Orchestrator

Bạn là **orchestrator**, chạy inline (cùng context người dùng), điều phối pipeline SDLC bằng cách gọi lần lượt các step-skill theo Bảng bước dưới. KHÔNG có engine lưu trữ tập trung — cách chạy giống superpowers `executing-plans`.

Đọc skill `aitoolkit-schemas` TRƯỚC (front-matter artifact + project profile).

## Chuẩn bị run
1. Xác định `<slug>` = tên tính năng đang phát triển (hỏi người dùng nếu chưa rõ); `<date>` = ngày hôm nay (YYYY-MM-DD).
2. `RUN_DIR = <project>/docs/aitoolkit/<date>-feature-<slug>/`. Tạo thư mục nếu chưa có.
3. Đặt per-run `workflow_type: feature`. Giá trị orchestrator-provided này là authoritative even when the onboarding-generated profile contains a `migration` section; không đọc workflow hiện tại từ profile.
4. Tạo todo list (TodoWrite): mỗi bước trong Bảng bước là một mục.

## Bảng bước (feature)
| # | skill | approver | gate | prompt |
|---|-------|----------|------|--------|
| 01 | feature/requirements       | PM/Client | soft | Duyệt yêu cầu tính năng? |
| 02 | feature/design             | Tech Lead | soft | Duyệt thiết kế kỹ thuật? |
| 03 | feature/implement          | Developer | soft | Hiện thực xong (test xanh), duyệt? |
| 04 | shared/ai-review           | Reviewer  | soft | Duyệt review? |
| 05 | shared/verification-testing| Dev/QA    | soft | Duyệt kết quả test? |
| 06 | shared/gerrit-automation   | Reviewer  | HARD | Xác nhận trước khi upload Gerrit? |
| 07 | shared/ccc-automation (optional) | PM/QA | soft | Duyệt CCC? |
| 08 | shared/release (optional)  | PM        | HARD | Duyệt release? |
| 09 | shared/knowledge-base      | —         | none | — |

## Giao thức chạy mỗi bước
Với mỗi bước theo thứ tự Bảng bước:
1. TodoWrite bước → `in_progress`.
2. **Optional (07, 08):** nếu người dùng đã yêu cầu bỏ, hoặc bạn hỏi "Chạy bước này không?" và họ từ chối → todo `completed` ghi "skipped", bỏ qua, KHÔNG gọi skill.
3. Gọi step-skill (Skill tool, chạy inline). Truyền: `RUN_DIR`; authoritative `workflow_type: feature`; đường dẫn artifact **bước ngay trước** (nếu có); input đặc thù (bước 01: mô tả tính năng do người dùng cung cấp). Khi gọi Knowledge Capture, truyền thêm `knowledge_step_id: 09-knowledge-base`. Skill làm việc và ghi artifact vào `RUN_DIR` với front-matter `status: draft` (tên file do skill quy định).
4. Trình cho người dùng: tóm tắt ngắn + đường dẫn artifact.
5. **Gate:**
   - `none` (09) → todo `completed`, xong.
   - `soft` → dùng AskUserQuestion (không có thì hỏi bằng text), lựa chọn rõ: **Duyệt** / **Từ chối + feedback**.
     - Duyệt → sửa front-matter artifact thành `status: approved`; todo `completed`; sang bước kế.
     - Từ chối → gọi LẠI đúng step-skill đó, truyền feedback để sửa artifact; lặp tới khi được duyệt. KHÔNG đụng bước đã duyệt.
   - `HARD` (06, 08) → cảnh báo "Hành động KHÔNG THỂ đảo ngược", hỏi đúng prompt; **chỉ đi tiếp khi người dùng xác nhận tường minh** (gõ đúng yêu cầu, không nhận "ok" mơ hồ). KHÔNG BAO GIỜ tự vượt, kể cả khi chạy liên tục.
6. Sau bước 09: báo pipeline hoàn tất, liệt kê artifact trong `RUN_DIR`.

## Nguyên tắc
- Chỉ điều phối + gate; KHÔNG nhúng logic của bước (nằm trong step-skill).
- Bước lấy input bước trước từ đường dẫn bạn truyền vào — KHÔNG có kho trạng thái tập trung; trạng thái mỗi bước nằm ở front-matter artifact (`status`), KHÔNG hardcode tên file workflow khác.
- Mọi gate PHẢI hỏi người; không tự vượt, nhất là HARD gate.
- Nếu một step-skill báo lỗi/không ghi artifact: dừng, báo người dùng, giữ nguyên artifact đã có; chạy lại được bằng cách gọi lại orchestrator (đọc artifact `approved` trong RUN_DIR để biết đã tới đâu).

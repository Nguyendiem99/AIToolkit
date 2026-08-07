---
name: migrate
description: Orchestrator pipeline migration của AIToolKit (10 bước discovery→mapping→tech-design→code-migration→review→test→gerrit→CCC→release→KB). Gọi step-skill tuần tự, dừng ở human gate. Kiểu Superpowers — không dùng engine/kho trạng thái tập trung.
---

# AIToolKit — Migration Orchestrator

Bạn là **orchestrator**, chạy inline (cùng context người dùng), điều phối pipeline SDLC bằng cách gọi lần lượt các step-skill theo Bảng bước dưới. KHÔNG có engine lưu trữ tập trung — cách chạy giống superpowers `executing-plans`.

Đọc skill `aitoolkit-schemas` TRƯỚC (front-matter artifact + project profile).

## Chuẩn bị run
1. Xác định `<slug>` = tên tính năng đang migrate (hỏi người dùng nếu chưa rõ); `<date>` = ngày hôm nay (YYYY-MM-DD).
2. `RUN_DIR = <project>/docs/aitoolkit/<date>-migration-<slug>/`. Tạo thư mục nếu chưa có.
3. Tạo todo list (TodoWrite): mỗi bước trong Bảng bước là một mục.

## Bảng bước (migration)
| # | skill | approver | gate | prompt |
|---|-------|----------|------|--------|
| 01 | migration/discovery       | PM/Client | soft | Xác nhận scope migration? |
| 02 | migration/feature-mapping | Client    | soft | Duyệt mapping & scope? |
| 03 | migration/technical-design| Tech Lead | soft | Duyệt thiết kế kỹ thuật? |
| 04 | migration/code-migration  | Developer | soft | Code chạy được, duyệt? |
| 05 | shared/ai-review          | Reviewer  | soft | Duyệt review? |
| 06 | shared/verification-testing| Dev/QA   | soft | Duyệt kết quả test? |
| 07 | shared/gerrit-automation  | Reviewer  | HARD | Xác nhận trước khi upload Gerrit? |
| 08 | shared/ccc-automation (optional) | PM/QA | soft | Duyệt CCC? |
| 09 | shared/release (optional) | PM        | HARD | Duyệt release? |
| 10 | shared/knowledge-base     | —         | none | — |

## Giao thức chạy mỗi bước
Với mỗi bước theo thứ tự Bảng bước:
1. TodoWrite bước → `in_progress`.
2. **Optional (08, 09):** nếu người dùng đã yêu cầu bỏ, hoặc bạn hỏi "Chạy bước này không?" và họ từ chối → todo `completed` ghi "skipped", bỏ qua, KHÔNG gọi skill.
3. Gọi step-skill (Skill tool, chạy inline). Truyền: `RUN_DIR`; đường dẫn artifact **bước ngay trước** (nếu có); input đặc thù (bước 01: đường dẫn source legacy + PRD/BRD nếu có). Skill làm việc và ghi artifact vào `RUN_DIR` với front-matter `status: draft` (tên file do skill quy định).
4. Trình cho người dùng: tóm tắt ngắn + đường dẫn artifact.
5. **Gate:**
   - `none` (10) → todo `completed`, xong.
   - `soft` → dùng AskUserQuestion (không có thì hỏi bằng text), lựa chọn rõ: **Duyệt** / **Từ chối + feedback**.
     - Duyệt → sửa front-matter artifact thành `status: approved`; todo `completed`; sang bước kế.
     - Từ chối → gọi LẠI đúng step-skill đó, truyền feedback để sửa artifact; lặp tới khi được duyệt. KHÔNG đụng bước đã duyệt.
   - `HARD` (07, 09) → cảnh báo "Hành động KHÔNG THỂ đảo ngược", hỏi đúng prompt; **chỉ đi tiếp khi người dùng xác nhận tường minh** (gõ đúng yêu cầu, không nhận "ok" mơ hồ). KHÔNG BAO GIỜ tự vượt, kể cả khi chạy liên tục.
6. Sau bước 10: báo pipeline hoàn tất, liệt kê artifact trong `RUN_DIR`.

## Nguyên tắc
- Chỉ điều phối + gate; KHÔNG nhúng logic của bước (nằm trong step-skill).
- Bước lấy input bước trước từ đường dẫn bạn truyền vào — KHÔNG có kho trạng thái tập trung; trạng thái mỗi bước nằm ở front-matter artifact (`status`), KHÔNG hardcode tên file workflow khác.
- Mọi gate PHẢI hỏi người; không tự vượt, nhất là HARD gate.
- Nếu một step-skill báo lỗi/không ghi artifact: dừng, báo người dùng, giữ nguyên artifact đã có; chạy lại được bằng cách gọi lại orchestrator (đọc artifact `approved` trong RUN_DIR để biết đã tới đâu).

---
name: build-inventory
description: Use when discovered source items, requirements, and an existing target baseline must become one traceable migration inventory.
---

# Migration 04 — Build Inventory

**Core principle:** Không có evidence thì ghi unknown; unknown chặn quyết định thì ghi `result: blocked`.

## Ngôn ngữ artifact

Nhận `artifact_language` do orchestrator truyền. Hiện chỉ hỗ trợ `artifact_language: vi`: viết tiêu đề, tóm tắt, blocker, khuyến nghị và nội dung gate bằng tiếng Việt UTF-8; giữ nguyên mọi field machine-readable, enum, ID, path, command, log, trace field và cột bảng contract.

## Inputs

Orchestrator truyền `RUN_DIR`, đường dẫn project profile, project pack, source/target, tài liệu và đúng một artifact bước trước qua path tường minh.

`Immediate predecessor artifact = exactly one orchestrator-provided path`.

Preserve the immediate predecessor Activation Slice envelope without loss: keep the complete case-sensitive slice ID set, Applicability, all nine canonical seam rows, and every predecessor Source Reference and Trace ID. Source Reference enrichment is append-only, and predecessor Trace IDs remain a subset of successor Trace IDs. Never reconstruct it from cumulative artifacts.
Truy vết discovery/input qua stable ID và source reference đã chuyển tiếp trong artifact trước; không dựng tên hoặc nạp danh sách artifact tích lũy.

## Work item and decomposition trace

Orchestrator truyền `work_item_id`, `master_plan_ref`, `master_plan_revision`, acceptance của work item, các Trace IDs ban đầu, `parent_work_item_id` và `decomposition_decision_reference` cùng immediate predecessor. Mọi giá trị phải resolve về đúng một work item trong master-plan revision đã duyệt; không suy ra work item từ folder, package hoặc `UNIT-*`.

Nếu đây là child sau decomposition, child phải đã tồn tại trong master-plan revision mới và có cùng parent/decision đã duyệt trước khi bước 04 chạy. Bước 04 là điểm đầu tiên được phép tạo canonical front-half trace cho child; không gán delivery adapter tại đây.

Artifact phải có đúng một row cho work item trong section `Work Item Trace` với các cột `Work Item ID`, `Parent Work Item ID`, `Master Plan Reference`, `Master Plan Revision`, `Acceptance`, `Trace IDs`, `Mode Constraint`, `Design Revision`, `Decomposition Decision Reference`. Giữ nguyên work item, master-plan revision, acceptance và decomposition identity; Trace IDs từ input là tập con bắt buộc và chỉ được enrich append-only. Trước step 07, `Design Revision` có thể là `pending-step07`.

## Activation Slice responsibilities

Đọc `aitoolkit/contracts/activation-slice.md` làm nguồn định nghĩa duy nhất và dùng envelope trong template, không nhúng lại schema. Preserve the same `ACT-###` Activation Slice ID and every seam row with its trace IDs từ immediate predecessor. Với mỗi seam thiếu hoặc cần thay đổi, tạo inventory coverage có stable `ITEM-###` và trace về slice/seam; không dedupe hai seam khác nhau chỉ vì chúng nằm trong cùng component.

Mất ID, seam row hoặc trace trong handoff, hoặc thiếu coverage có thể ngăn activation, phải giữ `status: draft` và `result: blocked`; không được báo partial.

## Quy trình

1. Đọc `aitoolkit-schemas`, `aitoolkit/contracts/activation-slice.md`, project profile, project pack và artifact path orchestrator truyền.
2. Chỉ dùng taxonomy, mapping và toolchain có Evidence hoặc do project pack cung cấp.
3. Gán stable ID `ITEM-###` và Evidence cho từng record; giữ liên kết tới mọi `REQ-###`, discovery ID, source reference và target reference liên quan.
4. Ghi artifact theo `aitoolkit/templates/migration/inventory.md` trong `RUN_DIR`.
5. Dedupe theo identity/hành vi có evidence, không chỉ theo tên. Với incremental, khảo sát target baseline trước khi kết luận item chưa tồn tại.
6. Không tự gán `migrated` hoặc `omitted`; hai trạng thái này cần evidence tương ứng hoặc quyết định scope được phê duyệt.

## Evidence và Unknowns

- `Evidence` cho mỗi item phải chứng minh kind, source identity và target identity nếu có.
- `Unknowns` ghi duplicate nghi ngờ, target chưa khảo sát được, kind chưa được taxonomy định nghĩa hoặc requirement chưa liên kết.
- Unknown làm thay đổi identity, phạm vi hoặc trạng thái item phải dùng `result: blocked`.
- Thiếu target reference trong greenfield không tự nó là blocker; ghi trạng thái theo mode/policy có evidence.

## Hợp đồng đầu ra

- File: `<RUN_DIR>/04-inventory.md`.
- Front matter: `step_id: 04-build-inventory`, `status: draft`, `result: complete | blocked`, `produced_at`.
- Giữ các phần `Items`, `Evidence`, `Unknowns`, `Verdict` của template.
- Giữ section `Activation Slice` với cùng ID, toàn bộ seam rows và trace IDs từ immediate predecessor; chỉ bổ sung inventory coverage thuộc step này.
- For a routed `result: blocked` artifact whose Activation Slice and immediate-predecessor handoff are otherwise valid, emit exactly one `Domain Blocker` table with non-placeholder `Blocker` and `Evidence Reference` values; omit that section for non-blocked output.
- Mỗi row có một stable ID duy nhất, `Requirement IDs`, `Discovery IDs`, source/target references và migration status có bằng chứng.
- Giữ section `Work Item Trace` theo contract trên; generic work item không được đổi thành `UNIT-*` và không được tự sinh delivery adapter.

## Quick reference

| Trường hợp | Xử lý |
|---|---|
| Cùng tên, khác hành vi | Giữ record riêng |
| Khác tên, cùng identity có evidence | Dedupe, giữ mọi reference |
| Có target baseline nhưng chưa khảo sát | Unknown; block nếu mapping phụ thuộc |

## Common mistakes

- Dedupe chỉ bằng tên hiển thị.
- Tạo item mới mà không tìm target reference trong incremental.
- Đánh dấu trạng thái bằng cảm tính thay vì Evidence/approval.

---
name: feature-mapping
description: Use when approved migration requirements and inventory items must be mapped to a target baseline with an explicit strategy and traceable rationale.
---

# Migration 05 — Feature Mapping

**Core principle:** Không có evidence thì ghi unknown; unknown chặn quyết định thì ghi `result: blocked`.

Giữ route `feature-mapping` để tương thích với caller hiện có; contract đầu ra mới là artifact bước 05.

## Ngôn ngữ artifact

Nhận `artifact_language` do orchestrator truyền. Hiện chỉ hỗ trợ `artifact_language: vi`: viết tiêu đề, tóm tắt, blocker, khuyến nghị và nội dung gate bằng tiếng Việt UTF-8; giữ nguyên mọi field machine-readable, enum, ID, path, command, log, trace field và cột bảng contract.

## Inputs

Orchestrator truyền `RUN_DIR`, đường dẫn project profile, project pack, source/target, tài liệu và đúng một artifact bước trước qua path tường minh.

`Immediate predecessor artifact = exactly one orchestrator-provided path`.

Preserve the immediate predecessor Activation Slice envelope without loss: keep the complete case-sensitive slice ID set, Applicability, all nine canonical seam rows, and every predecessor Source Reference and Trace ID. Source Reference enrichment is append-only, and predecessor Trace IDs remain a subset of successor Trace IDs. Never reconstruct it from cumulative artifacts.
Truy vết requirements/discovery/input qua stable ID và source reference đã chuyển tiếp trong artifact trước; không dựng tên hoặc nạp danh sách artifact tích lũy.

## Work item and decomposition trace

Nhận và validate section `Work Item Trace` từ immediate predecessor cùng orchestrator-provided `work_item_id`, `master_plan_ref` và `master_plan_revision`. Copy nguyên vẹn `Work Item ID`, `Parent Work Item ID`, `Master Plan Reference`, `Master Plan Revision`, `Acceptance`, `Mode Constraint` và `Decomposition Decision Reference`; Trace IDs predecessor phải là tập con của successor và enrichment chỉ được append-only. `Design Revision` vẫn có thể là `pending-step07`.

Child decomposition không có row hợp lệ từ step 04 phải block tại đây; không tạo child, sửa parent/decision hoặc gán `UNIT-*` để lấp trace thiếu. Delivery adapter là metadata tùy chọn của generic work item, không phải taxonomy inventory/mapping.

## Activation Slice responsibilities

Đọc `aitoolkit/contracts/activation-slice.md` làm nguồn định nghĩa duy nhất; giữ nguyên stable Activation Slice ID, mọi seam row và trace IDs từ immediate predecessor. Gán strategy/disposition cho từng seam và map nó tới target reference hoặc migration unit cụ thể; không nhúng lại canonical schema trong skill.

`deferred-approved` requires both `Decision Reference` and `Deferred Unit ID`. Thiếu một trong hai field, mất seam/trace, hoặc một disposition chưa đủ evidence có thể ngăn activation thì giữ `status: draft`, ghi `result: blocked`, không dùng partial.

## Quy trình

1. Đọc `aitoolkit-schemas`, `aitoolkit/contracts/activation-slice.md`, project profile, project pack và artifact path orchestrator truyền.
2. Chỉ dùng taxonomy, mapping và toolchain có Evidence hoặc do project pack cung cấp.
3. Gán stable ID `MAP-###` và Evidence cho từng mapping; chuyển tiếp stable requirement, inventory, discovery, source và target IDs từ artifact trước.
4. Ghi artifact theo `aitoolkit/templates/migration/mapping.md` trong `RUN_DIR`.
5. Chọn strategy từ `reuse | extend | create | replace | omit` dựa trên mode, architecture policy, target baseline và project-pack rules.
6. Trong incremental, xét theo thứ tự bắt buộc `reuse → extend → create`; không tạo song song khi target hiện có đã đáp ứng requirement.
7. `replace` chỉ hợp lệ khi có approved conflict decision được trích dẫn trong Evidence. Không có approval thì ghi conflict/unknown và `result: blocked`, không tự hạ xuống strategy khác để né gate.

## Evidence và Unknowns

- `Evidence` chứng minh source behavior, requirement, target capability và decision/approval dùng để chọn strategy.
- `Unknowns` ghi target chưa khảo sát, capability chưa kiểm chứng, mapping rule thiếu hoặc approval chưa có.
- Strategy không thể chọn duy nhất từ evidence hiện có phải dùng `result: blocked`.
- `omit` cần scope decision được phê duyệt; preference hoặc deadline không phải approval.

## Hợp đồng đầu ra

- File: `<RUN_DIR>/05-mapping.md`.
- Front matter: `step_id: 05-feature-mapping`, `status: draft`, `result: complete | blocked`, `produced_at`.
- Giữ các phần `Mappings`, `Evidence`, `Unknowns`, `Verdict` của template.
- Giữ section `Activation Slice` với cùng ID và toàn bộ seam rows; chỉ bổ sung target mapping, disposition và decision/unit reference thuộc step này.
- For a routed `result: blocked` artifact whose Activation Slice and immediate-predecessor handoff are otherwise valid, emit exactly one `Domain Blocker` table with non-placeholder `Blocker` and `Evidence Reference` values; omit that section for non-blocked output.
- Mỗi row ghi `Mapping ID`, `Requirement IDs`, `Inventory IDs`, `Discovery IDs`, source/target references, một strategy, rationale dựa trên evidence và approval khi policy yêu cầu.
- Giữ đúng một section `Work Item Trace`; preserve master revision, acceptance và decomposition trace từ bước 04, đồng thời chỉ append mapping Trace IDs.

## Quick reference

| Điều kiện | Strategy |
|---|---|
| Target đã đáp ứng requirement | `reuse` |
| Target cần thay đổi nhỏ theo policy hiện có | `extend` |
| Chưa có target phù hợp | `create` |
| Target phải bị thay thế | `replace` chỉ với approved conflict decision |
| Ngoài scope | `omit` chỉ với approved scope decision |

## Common mistakes

- Tạo component song song vì thiết kế mới hấp dẫn hơn target có sẵn.
- Chọn `replace` rồi xin approval sau.
- Dùng mapping quen thuộc không có trong project pack hoặc Evidence.

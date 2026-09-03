---
name: analyze-gaps-conflicts
description: Use when migration evidence exposes missing coverage, contradictory sources, unresolved ownership, or strategy decisions that require approval.
---

# Migration 06 — Analyze Gaps and Conflicts

**Core principle:** Không có evidence thì ghi unknown; unknown chặn quyết định thì ghi `result: blocked`.

## Ngôn ngữ artifact

Nhận `artifact_language` do orchestrator truyền. Hiện chỉ hỗ trợ `artifact_language: vi`: viết tiêu đề, tóm tắt, blocker, khuyến nghị và nội dung gate bằng tiếng Việt UTF-8; giữ nguyên mọi field machine-readable, enum, ID, path, command, log, trace field và cột bảng contract.

## Inputs

Orchestrator truyền `RUN_DIR`, đường dẫn project profile, project pack, source/target, tài liệu và đúng một artifact bước trước qua path tường minh.

`Immediate predecessor artifact = exactly one orchestrator-provided path`.

Preserve the immediate predecessor Activation Slice envelope without loss: keep the complete case-sensitive slice ID set, Applicability, all nine canonical seam rows, and every predecessor Source Reference and Trace ID. Source Reference enrichment is append-only, and predecessor Trace IDs remain a subset of successor Trace IDs. Never reconstruct it from cumulative artifacts.
Truy vết inventory/requirements/discovery/input qua stable ID và source reference đã chuyển tiếp trong artifact trước; không dựng tên hoặc nạp danh sách artifact tích lũy.

## Activation Slice responsibilities

Đọc `aitoolkit/contracts/activation-slice.md` làm nguồn định nghĩa duy nhất; giữ nguyên stable Activation Slice ID, mọi seam row và trace IDs từ immediate predecessor. Mở gap cho mỗi missing seam, và mở conflict cho ownership hoặc async lifecycle mâu thuẫn; chỉ bổ sung gap/conflict evidence thuộc step này, không sao chép canonical schema.

Unresolved router ownership is a blocking conflict and requires `result: blocked`. Mọi missing seam, ownership conflict hoặc lifecycle conflict có thể ngăn activation cũng phải giữ `status: draft` và blocked, không được hạ thành partial.

## Quy trình

1. Đọc `aitoolkit-schemas`, `aitoolkit/contracts/activation-slice.md`, project profile, project pack và artifact path orchestrator truyền.
2. Chỉ dùng taxonomy, mapping và toolchain có Evidence hoặc do project pack cung cấp.
3. Gán stable ID `GAP-###` hoặc `CONFLICT-###` và Evidence cho từng record; chuyển tiếp mọi requirement, inventory, mapping và discovery ID bị ảnh hưởng.
4. Ghi artifact theo `aitoolkit/templates/migration/gaps-conflicts.md` trong `RUN_DIR`.
5. Với gap, ghi expected, observed, impact, options và evidence cần để đóng gap.
6. Với conflict, giữ evidence của mọi nguồn, precedence policy nếu có, owner quyết định và trạng thái approval. Không tự chọn một nguồn vì deadline, độ mới hoặc mức độ chi tiết.
7. Chỉ ghi decision đã được approved owner/policy xác nhận; quyết định pending hoặc thiếu owner vẫn là unknown.

## Evidence và Unknowns

- `Evidence` phải cho phép kiểm chứng từng phía của conflict và từng thiếu hụt của gap.
- `Unknowns` ghi decision/owner/evidence còn thiếu và downstream records bị chặn.
- Conflict chưa giải quyết ảnh hưởng scope, parity, architecture hoặc mapping phải dùng `result: blocked`.
- Gap không chặn được ghi trong artifact hoàn tất khi impact và follow-up owner đã rõ.

## Hợp đồng đầu ra

- File: `<RUN_DIR>/06-gaps-conflicts.md`.
- Front matter: `step_id: 06-analyze-gaps-conflicts`, `status: draft`, `result: complete | blocked`, `produced_at`.
- Giữ các phần `Gaps and Conflicts`, `Evidence`, `Unknowns`, `Verdict` của template.
- Giữ section `Activation Slice` với cùng ID, toàn bộ seam rows và trace IDs; phản ánh gap/conflict đã phân tích mà không thu hẹp slice.
- For a routed `result: blocked` artifact whose Activation Slice and immediate-predecessor handoff are otherwise valid, emit exactly one `Domain Blocker` table with non-placeholder `Blocker` and `Evidence Reference` values; omit that section for non-blocked output.
- Mỗi row có stable ID, `Requirement IDs`, `Inventory IDs`, `Mapping IDs`, `Discovery IDs`, evidence, impact, options, owner và decision/approval rõ ràng; không dùng ô trống để ngầm hiểu “không có conflict”.

## Quick reference

| Tình trạng | Kết quả |
|---|---|
| Có precedence policy áp dụng trực tiếp | Trích policy và áp decision |
| Có approved owner decision | Trích approval và cập nhật record |
| Nguồn mâu thuẫn, chưa có quyền quyết định | `blocked` |
| Gap có owner và không chặn downstream | `complete` |

## Common mistakes

- Tự ưu tiên requirements hoặc hành vi legacy khi không có precedence policy.
- Chỉ ghi một phía của conflict.
- Ghi option được đề xuất như decision đã phê duyệt.

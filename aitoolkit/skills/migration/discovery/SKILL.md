---
name: discovery
description: Use when a migration needs an evidence-based view of legacy behavior, structure, dependencies, state, services, and user-facing surfaces.
---

# Migration 02 — Discovery

**Core principle:** Không có evidence thì ghi unknown; unknown chặn quyết định thì ghi `result: blocked`.

## Ngôn ngữ artifact

Nhận `artifact_language` do orchestrator truyền. Hiện chỉ hỗ trợ `artifact_language: vi`: viết tiêu đề, tóm tắt, blocker, khuyến nghị và nội dung gate bằng tiếng Việt UTF-8; giữ nguyên mọi field machine-readable, enum, ID, path, command, log, trace field và cột bảng contract.

## Inputs

Orchestrator truyền `RUN_DIR`, đường dẫn project profile, project pack, source/tài liệu và đúng một artifact bước trước qua path tường minh.

`Immediate predecessor artifact = exactly one orchestrator-provided path`.

Discovery is the Activation Slice origin when step 01 has no envelope: create the complete canonical envelope from validated evidence. If an immediate predecessor already carries an envelope, preserve it under the contract's no-loss and append-only rules; never reconstruct from cumulative artifacts.
Chỉ khảo sát input được artifact trước xác nhận; không dựng lại tên hoặc tự tìm artifact cũ trong `RUN_DIR`.

## Activation Slice responsibilities

Đọc `aitoolkit/contracts/activation-slice.md` làm nguồn định nghĩa duy nhất; không sao chép schema hoặc tự đổi tên seam trong skill này. Phát hiện applicability từ config key, profile field, capability, feature flag, product/device type hoặc runtime selector tương đương. Với mỗi slice applicable, tạo stable `Activation Slice ID` dạng `ACT-###`; nếu artifact trước đã có slice thì giữ nguyên ID và mọi seam row.

Khảo sát cả upstream và downstream, gồm `requested-key`, `parse-model`, `downstream-consumer` và mọi seam khác do contract quy định. Ghi `missing` khi chưa có evidence thay vì suy rằng một component ở giữa chứng minh toàn bộ activation flow. Nếu một activation seam bị thiếu có thể ngăn activation, giữ `status: draft`, dùng `result: blocked`, và never `result: partial`.

## Quy trình

1. Đọc `aitoolkit-schemas`, `aitoolkit/contracts/activation-slice.md`, project profile, project pack và artifact path orchestrator truyền.
2. Chỉ dùng taxonomy, mapping và toolchain có Evidence hoặc do project pack cung cấp; nếu marker mơ hồ thì giữ loại `unknown`, không suy ra framework.
3. Gán stable ID cho từng record và Evidence trực tiếp: `FEAT-###`, `SCREEN-###`, `COMP-###`, `STATE-###`, `SERVICE-###`, `DEP-###` hoặc prefix do project pack quy định.
4. Ghi artifact theo `aitoolkit/templates/migration/discovery.md` trong `RUN_DIR`.
5. Khảo sát hành vi quan sát được, luồng tương tác, thành phần, trạng thái, tích hợp và dependency. Tách fact, inference và unknown; inference chỉ được giữ khi dẫn nguồn và gắn mức tin cậy.

## Evidence và Unknowns

- `Evidence` dùng tham chiếu kiểm chứng được như `path:line`, section tài liệu, output lệnh hoặc scenario tái hiện.
- `Unknowns` nêu câu hỏi, record bị ảnh hưởng và evidence cần thêm.
- Không có marker rõ thì không đoán language/framework/toolchain và không đưa token công nghệ vào artifact nếu project pack không cung cấp.
- Unknown làm thay đổi taxonomy, phạm vi hoặc cách đọc source phải dùng `result: blocked`; unknown không chặn được ghi rõ trong artifact hoàn tất.

## Hợp đồng đầu ra

- File: `<RUN_DIR>/02-discovery.md`.
- Front matter: `step_id: 02-discovery`, `status: draft`, `result: complete | blocked`, `produced_at`.
- Giữ các phần `Inventory`, `Evidence`, `Unknowns`, `Verdict` của template.
- Giữ section `Activation Slice`; tạo hoặc chuyển tiếp cùng stable `ACT-###` và toàn bộ seam rows theo canonical contract, chỉ bổ sung evidence thuộc trách nhiệm discovery.
- For a routed `result: blocked` artifact whose Activation Slice and immediate-predecessor handoff are otherwise valid, emit exactly one `Domain Blocker` table with non-placeholder `Blocker` and `Evidence Reference` values; omit that section for non-blocked output.
- Mỗi inventory record có stable ID trong trường `Name` hoặc theo quy ước project pack và có Source Reference riêng.

## Quick reference

| Quan sát | Xử lý |
|---|---|
| Fact có nguồn trực tiếp | Ghi record và Evidence |
| Inference được pack cho phép | Ghi nguồn và mức tin cậy |
| Marker không phân loại được | Ghi unknown; block nếu ảnh hưởng taxonomy |

## Common mistakes

- Áp taxonomy quen thuộc khi project pack không cung cấp.
- Biến suy luận từ tên file thành fact.
- Gộp nhiều hành vi vào một record khiến mất traceability.

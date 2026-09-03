---
name: analyze-requirements-uiux
description: Use when migration requirements, user journeys, interaction states, acceptance criteria, or source documents must be reconciled before planning.
---

# Migration 03 — Analyze Requirements and UI/UX

**Core principle:** Không có evidence thì ghi unknown; unknown chặn quyết định thì ghi `result: blocked`.

## Ngôn ngữ artifact

Nhận `artifact_language` do orchestrator truyền. Hiện chỉ hỗ trợ `artifact_language: vi`: viết tiêu đề, tóm tắt, blocker, khuyến nghị và nội dung gate bằng tiếng Việt UTF-8; giữ nguyên mọi field machine-readable, enum, ID, path, command, log, trace field và cột bảng contract.

## Inputs

Orchestrator truyền `RUN_DIR`, đường dẫn project profile, project pack, requirements/UIUX documents, source và đúng một artifact bước trước qua path tường minh.

`Immediate predecessor artifact = exactly one orchestrator-provided path`.

## Activation Slice responsibilities

Read `aitoolkit/contracts/activation-slice.md` as the sole canonical definition. Preserve the immediate predecessor Activation Slice envelope without loss: keep the complete case-sensitive slice ID set, Applicability, all nine canonical seam rows, and every predecessor Source Reference and Trace ID. Source Reference enrichment is append-only, and predecessor Trace IDs remain a subset of successor Trace IDs. Never reconstruct it from cumulative artifacts.

Reconcile requirements and UI/UX evidence without narrowing or reclassifying any slice. Missing, changed, or cumulative-reconstructed envelope evidence yields `status: draft` and `result: blocked`.

Truy vết dữ liệu sớm hơn bằng stable ID và source reference trong artifact trước; không dựng tên hoặc quét `RUN_DIR` để nạp artifact tích lũy.

## Quy trình

1. Đọc `aitoolkit-schemas`, project profile, project pack và artifact path orchestrator truyền.
2. Chỉ dùng taxonomy, mapping và toolchain có Evidence hoặc do project pack cung cấp.
3. Gán stable ID `REQ-###` cho requirement, `UIUX-###` cho state/interaction và Evidence cho từng record.
4. Ghi artifact theo `aitoolkit/templates/migration/requirements-uiux.md` trong `RUN_DIR`.
5. Chuẩn hóa actor, trigger, state, interaction, outcome và acceptance; liên kết mỗi requirement với discovery record liên quan.
6. Khi tài liệu và hành vi legacy mâu thuẫn, ghi cả hai nguồn cùng stable conflict ID; không tự chọn nguồn thắng nếu project pack không có precedence policy hoặc chưa có quyết định được phê duyệt.

## Evidence và Unknowns

- `Evidence` chỉ rõ document/section, source reference, log hoặc scenario quan sát được cho từng requirement và state.
- `Unknowns` nêu ambiguity, conflict, owner cần quyết định và record bị ảnh hưởng.
- Requirement thiếu acceptance kiểm chứng được phải ghi rõ evidence gap; dùng `blocked` khi gap chặn downstream, nếu không thì hoàn tất với gap được truy vết.
- Conflict ảnh hưởng phạm vi, parity hoặc mapping mà chưa có precedence/approval phải ghi `result: blocked`.

## Hợp đồng đầu ra

- File: `<RUN_DIR>/03-requirements-uiux.md`.
- Front matter: `step_id: 03-analyze-requirements-uiux`, `status: draft`, `result: complete | blocked`, `produced_at`.
- Preserve `Activation Slice` from the discovery predecessor with the identical slice set, Applicability, all nine rows, Source Reference evidence, and Trace IDs.
- For a routed `result: blocked` artifact whose Activation Slice and immediate-predecessor handoff are otherwise valid, emit exactly one `Domain Blocker` table with non-placeholder `Blocker` and `Evidence Reference` values; omit that section for non-blocked output.
- Giữ các phần `Requirements`, `Evidence`, `Unknowns`, `Verdict` của template.
- Mỗi row có stable requirement/UIUX ID, `Discovery IDs`, source và acceptance; conflict unresolved xuất hiện trong `Unknowns` với owner và decision cần thiết.

## Quick reference

| Tình huống | Xử lý |
|---|---|
| Nhiều nguồn đồng thuận | Hợp nhất và giữ mọi Evidence |
| Nguồn khác nhau nhưng không loại trừ nhau | Tách requirement/state |
| Nguồn mâu thuẫn | Ghi conflict, owner, decision; block nếu ảnh hưởng bước sau |

## Common mistakes

- Chọn tài liệu hoặc hành vi hiện tại làm “sự thật” mà không có precedence policy.
- Viết acceptance không thể quan sát hoặc kiểm chứng.
- Mất liên kết giữa interaction state và requirement.

---
name: classify-mode
description: Use when inspected migration evidence must be classified as greenfield, incremental, or unknown under a Tech Lead decision gate.
---

# Classify Migration Mode

Chỉ tạo đề xuất mode/policy từ inspection đã duyệt. Skill không bootstrap target, không viết profile và không biến deadline thành evidence.

## Ngôn ngữ artifact

Nhận `artifact_language` do orchestrator truyền. Hiện chỉ hỗ trợ `artifact_language: vi`: viết tiêu đề, tóm tắt, blocker, khuyến nghị và nội dung gate bằng tiếng Việt UTF-8; giữ nguyên mọi field machine-readable, enum, ID, path, command, log, trace field và cột bảng contract.

## Inputs

- `<RUN_DIR>`, `<project>` và `<RUN_DIR>/02-project-inspection.md` có `status: approved`.
- Profile hiện tại nếu onboarding đang cập nhật dự án đã có pack.

## Classification contract

| Observable evidence | Proposed mode | Architecture policy | Result/action |
|---|---|---|---|
| Target có stable target architecture, nhiều feature đã migrate và convention lặp lại | `incremental` | `preserve-existing` | Đề xuất cặp này; vẫn chờ Tech Lead gate |
| Target vắng hoặc là placeholder-only target, chưa có approved foundation decision | `mode: unknown` | `unknown` | `result: blocked`; cần Tech Lead confirmation trước khi đổi sang greenfield |
| Target vắng/placeholder nhưng có quyết định foundation đã approved và scoped đúng target | `greenfield` | `design-new` | Đề xuất cặp này; vẫn chờ Tech Lead gate |
| Evidence target xung đột hoặc không đủ | `mode: unknown` | `unknown` | `result: blocked`; liệt kê câu hỏi và owner |
Với ambiguous toolchain hoặc nhiều workspace/command không có authority rõ, candidate chỉ được ghi kèm scope/evidence; profile commands remain `null` và proposal trả `result: blocked`. Command resolution theo thứ tự: explicit profile -> existing project scripts/config -> marker detection -> human gate.

Chỉ các enum `greenfield | incremental | unknown` và `design-new | preserve-existing | unknown` hợp lệ. Không tạo nhãn brownfield, bootstrap, existing-target hay multi-workspace.

## Command ambiguity contract

Command resolution is orthogonal to the target mode row above. Apply this table independently after selecting mode/policy from target evidence.

| Observable command evidence | Value | Authority | Source | Scope | Blocker | Result/action |
|---|---|---|---|---|---|---|
| ambiguous toolchain hoặc conflicting workspace commands | `null` | `unknown` | candidate config/script references | one scope per candidate | required: command-authority decision | `result: blocked`; never guess or merge commands |

## Procedure

1. Kiểm tra inspection approval và trace từng kết luận tới Evidence.
2. Áp dụng đúng một hàng trong bảng. Evidence chưa phân biệt được các hàng phải chọn unknown, không chọn phương án “an toàn có vẻ hợp lý”.
3. Ghi command đã xác nhận nguyên văn cùng scope; command candidate/xung đột ở Unknowns với owner.
4. Ghi proposal ở `status: draft`. Skill không tự ghi approval hoặc sửa `project.yaml`.
5. Blocker mode, policy hoặc command cần cho migration làm `result: blocked`; orchestrator dừng trước gate. Proposal không blocked vẫn phải chờ Tech Lead duyệt.

## Blocked decision protocol

Khi output blocked vì cần lựa chọn mode, workspace hoặc command authority:

1. Orchestrator phải present the decision question cùng candidates, evidence, impact và owner; blocked artifact không được đưa qua normal approval gate.
2. Tech Lead hoặc repository owner trả lời rõ decision và scope. Record the approved decision as evidence, không chỉ ghi “đã trao đổi”.
3. Orchestrator truyền evidence/feedback đó và rerun this skill. Không sửa trực tiếp verdict cũ hoặc tự suy từ câu trả lời mơ hồ.
4. Rerun phải kiểm lại toàn bộ contract. Chỉ output mới có `result: complete` or `partial` mới đi vào Tech Lead proposal gate; nếu vẫn thiếu authority thì tiếp tục blocked.

## Inspection evidence handoff

`Bàn giao bằng chứng tài liệu` is part of this single-predecessor seam. Copy every approved step-02 record into `<RUN_DIR>/03-mode-proposal.md` with the exact columns `Category`, `Canonical Path`, `Input Source`, `Format`, `Readability`, and `Evidence ID`. Preserve the `explicit` or `inbox` source authority and category without re-resolving the original flag, scanning an inbox, or reading step 01 directly. Missing, stale, duplicate-ID, or unreadable forwarded records make the proposal `result: blocked`.

Step 03 must write the complete handoff into `<RUN_DIR>/03-mode-proposal.md`:

- Forward the approved inspection evidence references for `legacy`, `target`, `documents`, and `toolchain`; each reference keeps its source location and decision impact.
- For every command field, forward value or `null`, command authority, source, scope, and blocker ID/state.
- Preserve the approved human decision evidence used to resolve a prior blocker.
- Missing or stale evidence references produce `result: blocked`; step 04 must not reopen the inspection artifact to fill gaps.

## Output contract

Onboarding không sinh production code.

Ghi duy nhất `<RUN_DIR>/03-mode-proposal.md` theo `templates/migration/mode-proposal.md`. Proposal phải chứa mode, architecture policy, Command Resolution, Inspection Evidence Handoff, rationale, Evidence, Unknowns và Tech Lead approval status.

## Common mistakes

- Tự coi placeholder là greenfield approval.
- Gọi target đang hoạt động bằng enum ngoài contract.
- Chọn command để “bắt đầu trước” rồi hứa xác nhận sau.

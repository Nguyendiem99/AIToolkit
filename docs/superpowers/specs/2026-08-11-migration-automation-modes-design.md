# Migration Automation Modes Design

**Date:** 2026-08-11  
**Status:** approved in conversation; pending written-spec review

## Goal

Cho phép AIToolkit migration chạy không hỏi lại sau mỗi soft gate, đồng thời hỗ trợ project test không có đủ dependency, tool, device hoặc service mà không làm giả evidence.

## User interface

Migration có ba automation mode:

```text
interactive | auto | auto-waive
```

Kích hoạt theo từng run:

```text
$aitoolkit:aitoolkit migrate <slug> --auto
$aitoolkit:aitoolkit migrate <slug> --auto-waive
```

Hoặc đặt mặc định trong `docs/aitoolkit/project.yaml`:

```yaml
automation:
  mode: interactive # interactive | auto | auto-waive
```

Thứ tự resolution:

```text
CLI flag
→ project.yaml automation.mode
→ interactive
```

`--auto` và `--auto-waive` loại trừ nhau. Giá trị không hợp lệ hoặc khai báo cả hai phải dừng trước step 01.

## Mode behavior

### `interactive`

Giữ behavior hiện tại. Mỗi soft gate yêu cầu người dùng duyệt hoặc từ chối kèm feedback. `result: blocked` dừng workflow trước approval gate.

### `auto`

- Tự duyệt mọi soft gate khi artifact hợp contract và không blocked.
- Tự tiếp tục qua các step mà không hỏi người dùng.
- `result: complete` hoặc `result: partial` được phép tiếp tục nếu không có blocker.
- `result: blocked`, execution failure hoặc contract failure vẫn dừng.
- Không tự vượt HARD gate.

### `auto-waive`

Bao gồm toàn bộ behavior của `auto`, đồng thời cho phép waiver có giới hạn đối với blocker thuộc môi trường.

Waiver-eligible:

- dependency hoặc tool không cài/không khả dụng;
- device, emulator, service hoặc network dependency không khả dụng;
- command không thể chạy vì environment capability bị thiếu;
- pre-mutation baseline không thể thu thập chỉ vì một trong các environment capability trên bị thiếu.

Waiver-ineligible và luôn phải dừng:

- source/target path thiếu, sai hoặc nằm ngoài project scope;
- artifact/front matter/schema/handoff không hợp lệ;
- migration mode, policy, unit selector hoặc foundation baseline thiếu, stale, unapproved, mismatched hay ambiguous;
- command đã chạy và trả về correctness failure thật;
- parity/regression cho thấy behavior regression mới;
- thao tác có nguy cơ sửa/xóa dữ liệu ngoài phạm vi;
- HARD gate.

## Evidence contract

Automation không được ghi failure hoặc unexecuted check thành `PASS`.

Artifact tự duyệt ghi:

```yaml
status: approved
approval_source: auto | auto-waive
```

Artifact có waiver ghi `result: partial` và một section:

```yaml
waiver:
  policy: auto-waive
  category: environment-unavailable
  original_verdict: blocked
  effective_action: continue
  evidence: <command/error/capability evidence>
```

Check không chạy được ghi `NOT_RUN + WAIVED`; check đã chạy và fail giữ `FAIL` và không waiver.

Mỗi auto approval/waiver phải lưu mode, lý do và evidence trong chính artifact để Knowledge Capture tổng hợp. Không thêm state store hay resume engine.

## Default artifact language

Mọi artifact Markdown do migration onboarding và migration sinh ra mặc định dùng tiếng Việt. Người dùng không cần truyền `--lang vi` hoặc tự khai báo profile.

Project profile có contract tường minh:

```yaml
output:
  artifact_language: vi
```

Onboarding phải sinh giá trị này. Profile cũ không có `output.artifact_language` degrade về `vi`.

Phạm vi dịch sang tiếng Việt:

- tiêu đề, section heading và nội dung diễn giải;
- summary, phân tích, blocker, unknown, recommendation và gate prompt;
- human-facing table headings và table values không thuộc machine contract;
- Knowledge Capture và project-pack reference prose do AIToolkit sinh.

Không dịch các seam máy đọc:

- YAML/frontmatter keys như `step_id`, `status`, `result`, `approval_source`;
- enum như `draft`, `approved`, `complete`, `partial`, `blocked`, `PASS`, `FAIL`, `BLOCKED`, `WAIVED`, `NOT_RUN`;
- artifact names, path, route, migration unit ID, evidence ID và trace ID;
- command, log, code, API/schema identifier và exact machine-contract table field.

Artifact phải là UTF-8 và không có mojibake. Tài liệu nguồn do người dùng cung cấp không bị dịch, di chuyển hay sửa.

## Orchestrator flow

1. Parse CLI flags và profile, resolve chính xác một automation mode trước step 01.
2. Truyền `automation_mode` cho mọi step.
3. Step tạo artifact và verdict thật như hiện tại; step không tự quyết định approval.
4. Orchestrator phân loại blocker theo taxonomy trên.
5. `interactive` hỏi gate; `auto` tự duyệt non-blocked artifact; `auto-waive` tự duyệt và chỉ waive environment blocker hợp lệ.
6. Mọi mode dừng trước waiver-ineligible blocker hoặc HARD gate.
7. Knowledge Capture ghi summary của auto approvals, waivers, `NOT_RUN`, PASS và FAIL.

## Scope

Thay đổi bao gồm Codex launcher, migration orchestrator, schema/profile template, generated Markdown templates, verification/implementation handoff, Knowledge Capture, docs và validator mutations.

Không thay đổi feature/bugfix gate behavior. Không tự động upload Gerrit, chạy CCC hay Release; các delivery skill vẫn độc lập.

## Verification

Validator và focused mutations phải chứng minh:

- default vẫn interactive;
- CLI override profile;
- hai flag loại trừ nhau;
- `auto` dừng ở blocker;
- `auto-waive` tiếp tục qua environment-unavailable blocker với truthful waiver;
- `auto-waive` không waive correctness, schema, selector, scope, regression hoặc HARD-gate failure;
- Knowledge Capture không biến `NOT_RUN`, `WAIVED` hoặc `FAIL` thành `PASS`;
- onboarding sinh `output.artifact_language: vi`, profile cũ thiếu field vẫn resolve thành `vi`;
- generated Markdown prose/headings là tiếng Việt UTF-8 trong khi machine-contract fields giữ nguyên;
- source documents không bị dịch hoặc sửa;
- feature/bugfix behavior không bị thay đổi.

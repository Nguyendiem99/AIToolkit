---
step_id: <orchestrator-provided>
status: draft
result: complete
produced_at: <yyyy-mm-dd>
---

<!-- artifact_language: vi -->

# Báo cáo triển khai migration

## Selected Migration Unit

Ô `Foundation Baseline ID` ghi chính xác `foundation_baseline_id` được predecessor đã duyệt chọn hoặc tạo.

| Migration Unit ID | Plan Reference | Approval Reference | Mode Constraint | Bootstrap Scope | Foundation Baseline ID | Foundation Baseline Reference | Foundation Baseline Approval Reference | Baseline Reference | Trace IDs |
|---|---|---|---|---|---|---|---|---|---|
| <UNIT-001> | <tham chiếu plan> | <tham chiếu duyệt đơn vị> | <ràng buộc mode/policy> | <required hoặc not-required> | <FOUNDATION-* ID đã duyệt hoặc not-applicable> | <tham chiếu target-baseline đã duyệt hoặc not-applicable> | <tham chiếu duyệt hoặc not-applicable> | <tham chiếu bằng chứng hồi quy hoặc not-applicable> | <trace IDs> |

## File đã thay đổi

Lặp một row khi cùng file liên kết tới nhiều seam đã duyệt.

| Migration Unit ID | Activation Slice ID | Seam | File | Change | Trace IDs |
|---|---|---|---|---|---|
| <UNIT-001> | <ACT-001> | <canonical seam> | <path> | <thay đổi> | <approved slice/seam trace IDs> |

## Activation Slice Test Evidence

Lặp một row khi cùng test chứng minh nhiều seam đã duyệt.

| Migration Unit ID | Activation Slice ID | Seam | Test | Command | Result | Trace IDs |
|---|---|---|---|---|---|---|
| <UNIT-001> | <ACT-001> | <canonical seam> | <test/scenario> | <lệnh> | <PASS / FAIL / BLOCKED> | <approved slice/seam trace IDs> |

## Trace ID triển khai

| Trace ID | Implementation Reference |
|---|---|
| <REQ-001> | <path hoặc symbol> |

## Change Hygiene

| Task / Unit | File | File Kind | Edited Region / Symbol | Formatter Command | Unrelated Diff | Checkpoint History | Task-base SHA | Final-tree SHA |
|---|---|---|---|---|---|---|---|---|
| <UNIT-001> | <path> | <new or existing> | <region or symbol> | <command or none> | none | <checkpoint SHAs or none> | <sha> | <sha> |

## Lệnh và kết quả

| Command | Result | Evidence |
|---|---|---|
| <lệnh> | <kết quả> | <tham chiếu> |

## Blocker gốc

Ghi `not-applicable` khi không có blocker. Nếu có, giữ nguyên kết luận `BLOCKED`, vai trò lệnh, vòng đời lệnh bắt buộc và lỗi command/capability verbatim của bước. Mọi lệnh bắt buộc đã khởi chạy đều không đủ điều kiện waiver; chỉ availability probe riêng biệt với vòng đời lệnh bắt buộc `not-started` mới có thể là ứng viên environment waiver. Bước giữ artifact ở draft/blocked; chỉ orchestrator được thêm automation waiver đã duyệt.

| Stage / Check | Native Verdict | Command Role | Required Command Lifecycle | Command / Capability | Observed Error | Evidence Reference |
|---|---|---|---|---|---|---|
| <baseline trước mutation hoặc kiểm tra triển khai> | `BLOCKED` | <availability probe hoặc lệnh test/build/baseline bắt buộc> | <not-started, started-without-correctness/regression-result hoặc started-and-produced-correctness/regression-result> | <command hoặc capability verbatim> | <lỗi quan sát được verbatim> | <tham chiếu bằng chứng> |

## Approved Baseline Waiver

<!-- Chỉ dùng khi orchestrator re-invoke step 10 bằng waiver baseline đã duyệt; nếu không dùng ghi `not-applicable`. -->

```yaml
status: approved
result: partial
approval_source: auto-waive
waiver:
  policy: auto-waive
  category: environment-unavailable
  original_verdict: blocked
  effective_action: continue
  evidence: <verbatim capability/command error reference>
```

## Step 10 Waiver Resume State

| Resume Phase | Baseline Action | Implementation Status | Target Mutation Evidence | Waiver Evidence |
|---|---|---|---|---|
| `not-applicable` hoặc `resume-required` hoặc `resume-consumed` | `skip-pre-mutation-baseline-only` hoặc not-applicable | <normal outcome hoặc blocked> | <target source mutation + unit/trace evidence, hoặc none> | <exact approved waiver evidence, hoặc not-applicable> |

## Activation Slice

Ghi `not-applicable-approved` với evidence và decision reference khi unit không có activation selector; không được bỏ section.

| Activation Slice ID | Applicability | Seam | Input | Output | Source Reference | Trace IDs | Disposition | Status | Decision Reference | Deferred Unit ID |
|---|---|---|---|---|---|---|---|---|---|---|
| <ACT-001> | <applicable / not-applicable-approved / unknown> | <canonical seam> | <input> | <output> | <source reference> | <trace IDs> | <implement / reuse / deferred-approved / not-applicable-approved> | <verified / missing / conflict / unknown> | <approval reference hoặc not-applicable> | <UNIT-* hoặc not-applicable> |

## Bằng chứng

| Evidence | Location | Notes |
|---|---|---|
| <bằng chứng> | <tham chiếu> | <ghi chú> |

## Domain Blocker

Chỉ giữ section này khi front matter là `result: blocked` và Activation Slice/handoff vẫn hợp lệ; mọi output khác phải xóa toàn bộ section. Giá trị placeholder không phải evidence hợp lệ.

| Blocker | Evidence Reference |
|---|---|
| <blocker cụ thể> | <tham chiếu bằng chứng cụ thể> |
## Điểm chưa rõ

- <điểm chưa rõ hoặc giả định>

## Kết luận

<ready | partial | blocked>

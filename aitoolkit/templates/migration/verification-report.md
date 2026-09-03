---
step_id: <shared: orchestrator truyền>
status: draft
# Chỉ migration: thêm `result: complete | blocked`
produced_at: <yyyy-mm-dd>
---

<!-- artifact_language: vi -->

# Báo cáo Verification & Testing — <tên module>

## Task Provenance

| Task / Unit | Task-base SHA | Final-tree SHA | Source Artifact |
|---|---|---|---|
| <UNIT-001> | <sha> | <sha> | <review-report path> |

## Selected Migration Unit

| Migration Unit ID | Plan Reference | Approval Reference | Mode Constraint | Bootstrap Scope | Foundation Baseline ID | Foundation Baseline Reference | Foundation Baseline Approval Reference | Baseline Reference | Trace IDs |
|---|---|---|---|---|---|---|---|---|---|
| <UNIT-001> | <tham chiếu plan> | <tham chiếu duyệt đơn vị> | <ràng buộc mode/policy> | <required hoặc not-required> | <FOUNDATION-001 hoặc not-applicable> | <tham chiếu target-baseline đã duyệt hoặc not-applicable> | <tham chiếu duyệt hoặc not-applicable> | <tham chiếu bằng chứng hồi quy hoặc not-applicable> | <trace IDs> |

## Activation Slice

Chuyển tiếp nguyên vẹn envelope từ artifact ngay trước: toàn bộ stable slice ID, Applicability, chín seam row, Source Reference và Trace IDs; không dựng lại từ artifact tích lũy.

| Activation Slice ID | Applicability | Seam | Input | Output | Source Reference | Trace IDs | Disposition | Status | Decision Reference | Deferred Unit ID |
|---|---|---|---|---|---|---|---|---|---|---|
| <ACT-001> | <applicable / not-applicable-approved / unknown> | <canonical seam> | <input> | <output> | <source reference> | <trace IDs> | <implement / reuse / deferred-approved / not-applicable-approved> | <verified / missing / conflict / unknown> | <approval reference hoặc not-applicable> | <UNIT-* hoặc not-applicable> |

## Lệnh đã chạy (verbatim)
| Loại | Lệnh | Nguồn (profile/tự dò/gate) |
|---|---|---|
| test |  |  |
| lint |  |  |
| build |  |  |

## Kết quả thô
- Test: <số lượng pass/fail>, exit code:
- Lint: <số lỗi>, exit code:
- Build: exit code: <hoặc "N/A" nếu hệ sinh thái không có bước build>
- Trích đoạn output khi fail:

## Check Outcome Legal Pairs

Chọn nguyên một hàng cho mỗi kiểm tra migration, không chọn hai field độc lập. `WAIVED` yêu cầu `NOT_RUN`; `PASS + WAIVED` không hợp lệ. Only required-command lifecycle `not-started` may use `WAIVED`. Lifecycle `started-without-correctness/regression-result` requires `FAIL` + `BLOCKED`.

| Execution Status | Verification Disposition | Meaning |
|---|---|---|
| `PASS` | `verified` | required command ran and passed |
| `FAIL` | `BLOCKED` | required command started and returned failure |
| `NOT_RUN` | `BLOCKED` | required command did not run; native blocker |
| `NOT_RUN` | `WAIVED` | eligible environment blocker; orchestrator-only |

## Check Outcomes

Ghi evidence verbatim cho từng kiểm tra. Migration environment waiver dùng đúng `NOT_RUN + WAIVED` và không bao giờ là `PASS`; step-skill ghi native `NOT_RUN + BLOCKED` trước khi orchestrator quyết định tiếp tục.

| Check | Command Role | Required Command Lifecycle | Execution Status | Verification Disposition | Evidence |
|---|---|---|---|---|---|
| <kiểm tra test, lint, build, parity hoặc baseline> | <availability probe hoặc lệnh test/build/baseline bắt buộc> | <not-started, started-without-correctness/regression-result hoặc started-and-produced-correctness/regression-result> | <status từ một cặp hợp lệ> | <disposition tương ứng trong cùng cặp hợp lệ> | <bằng chứng command/output/capability verbatim> |

## Kiểm tra hành vi
| Yêu cầu / Kịch bản | Lệnh chứng minh | Kết quả thật |
|---|---|---|

## Độ phủ (nếu có coverage_cmd)
| Thành phần | % | Nhận xét chất lượng phủ |
|---|---|---|

## Khoảng trống / Rủi ro
- Chưa phủ:
- Rủi ro còn lại:

## Bằng chứng
- <tham chiếu command/output/evidence>

## Domain Blocker

Chỉ giữ section này khi front matter là `result: blocked` và Activation Slice/handoff vẫn hợp lệ; mọi output khác phải xóa toàn bộ section. Giá trị placeholder không phải evidence hợp lệ.

| Blocker | Evidence Reference |
|---|---|
| <blocker cụ thể> | <tham chiếu bằng chứng cụ thể> |
## Điểm chưa rõ
- <không có hoặc điểm chưa rõ>

## Kết luận
`PASS` | `FAIL` | `BLOCKED` | `WAIVED` — <một câu bằng chứng; WAIVED chỉ do migration orchestrator ghi và không phải PASS>

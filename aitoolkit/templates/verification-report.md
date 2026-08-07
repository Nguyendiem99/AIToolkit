---
step_id: <shared: orchestrator truyền>
run_id: <run-id>
status: draft
produced_at: <yyyy-mm-dd>
---

# Verification & Testing Report — <tên module>

## Lệnh đã chạy (verbatim)
| Loại | Lệnh | Nguồn (profile/tự dò/gate) |
|---|---|---|
| test |  |  |
| lint |  |  |
| build |  |  |

## Kết quả thô
- Test: <pass/fail count>, exit code:
- Lint: <error count>, exit code:
- Build: exit code: <hoặc "N/A" nếu hệ sinh thái không có bước build>
- Trích đoạn output khi fail:

## Behavior-check
| Yêu cầu / Kịch bản | Lệnh chứng minh | Kết quả thật |
|---|---|---|

<!-- Bugfix: ghi rõ chứng minh red-green (revert→FAIL→restore→PASS).
     Migration: mỗi hàng là 1 kịch bản, cột kết quả nêu cũ==mới hay chênh lệch. -->

## Coverage (nếu có coverage_cmd)
| Thành phần | % | Nhận xét chất lượng phủ |
|---|---|---|

## Gap / Risk
- Chưa phủ:
- Rủi ro còn lại:

## Verdict
`PASS` | `FAIL` | `BLOCKED` — <một câu bằng chứng>

---
name: verification-testing
description: Bước Verification & Testing của AIToolKit (khung dùng chung, mọi workflow, mọi ngôn ngữ) — kiểm chứng hành vi bằng bằng chứng tươi, sinh & chạy test, phán quyết PASS/FAIL/BLOCKED. Đọc artifact bước trước qua state.json, ghi verification-report.md.
---

# Shared — Verification & Testing

Conductor gọi với `step_id`, `run_id`, `run_dir` (do manifest quyết định). Bước nặng → chạy trong subagent.

**Core principle:** Chỉ bằng chứng mới đổi được trạng thái. "Nhìn có vẻ đúng" không phải bằng chứng.

## The Iron Law

```
KHÔNG TUYÊN BỐ "ĐẠT" NẾU CHƯA CHẠY LỆNH KIỂM CHỨNG TRONG CHÍNH LƯỢT NÀY.
```

Nếu bạn chưa chạy lệnh và đọc output ở lượt này, bạn không được ghi verdict PASS.
**Vi phạm câu chữ của luật = vi phạm tinh thần của luật** — diễn đạt khác đi ("chắc pass", "về cơ bản ổn") vẫn là vi phạm.

Kỷ luật này kế thừa superpowers:verification-before-completion — **REQUIRED BACKGROUND**.

## Việc cần làm (thứ tự)

1. **Đọc hợp đồng & input.** Đọc `aitoolkit-schemas`. Lấy artifact **bước ngay trước**: id liền trước `current_step` trong `manifest.steps`, rồi `state.json.steps[<prev_id>].artifact_path` (vd `review-report.md`, hoặc artifact code/fix) để biết nhánh + file đã đổi + yêu cầu gốc. Đọc template `verification-report.md`.
2. **Xác định lệnh kiểm chứng (language-agnostic).** Theo `project-profile` trong `aitoolkit-schemas` §4: (a) đọc `.aitoolkit/project.yaml`; (b) thiếu trường nào thì tự dò theo [command-detection.md](command-detection.md); (c) vẫn không rõ → ghi "chưa xác định" và để gate hỏi, KHÔNG bịa lệnh. Ghi lệnh thực tế **verbatim** vào report.
3. **Chọn chiến lược test theo loại thay đổi** (bảng dưới) và **viết test còn thiếu** (dùng superpowers:test-driven-development).
4. **Chạy** test + lint + build đã xác định. Đọc **toàn bộ** output, exit code, đếm số fail.
5. **Lập bảng behavior-check**: mỗi yêu cầu/kịch bản → lệnh chứng minh → kết quả thật.
6. **Phán quyết** PASS/FAIL/BLOCKED kèm bằng chứng, ghi `<run_dir>/verification-report.md` theo template (`step_id` conductor truyền, `status: draft`). Trả về đường dẫn.

## Chiến lược test theo loại thay đổi

Xác định **loại thay đổi** theo `project-profile` (`aitoolkit-schemas` §4): `manifest.change_type` nếu có, else suy từ tên `workflow` (migration/bugfix/feature). Không hardcode.

| Loại | Test bắt buộc | Bằng chứng "đủ" |
|---|---|---|
| **Feature/tính năng mới** (mặc định khi không rõ) | Behavior test cho mỗi hành vi trong yêu cầu + edge case | Test mô tả *hành vi mong muốn*, xanh; edge case có mặt |
| **Bugfix** | **Regression test có chứng minh red-green** | Revert fix → test PHẢI FAIL → restore fix → test PASS. Chỉ pass 1 lần KHÔNG đủ |
| **Migration** | Parity/equivalence: cùng input, so hành vi cũ vs mới | Bảng kịch bản cũ==mới; chênh lệch phải được giải thích, không giấu |

**Regression red-green (bugfix) — không thể bỏ:** một test "pass ngay từ đầu" không chứng minh nó bắt được bug. Phải thấy nó ĐỎ khi chưa có fix.

**Baseline cho parity (migration) — "hành vi cũ" lấy ở đâu:** dùng golden output/kỳ vọng đã ghi trong artifact bước trước (discovery/mapping mô tả hành vi Native mong đợi); nếu code cũ còn chạy được thì chạy nó lấy output làm mốc. KHÔNG tự bịa "chắc giống"; kịch bản nào không có mốc → liệt vào Gap, không tính là parity đã chứng minh.

## Triết lý coverage

Coverage đo *dòng code nào được chạy*, KHÔNG đo *hành vi có đúng*. Đừng chạy theo con số %.

- ✅ Đảm bảo: hành vi vừa đổi được phủ, các edge case được phủ, **đúng cái bug** được phủ bởi regression test.
- ❌ Không: nâng % bằng test rỗng/không assert, hay test getter/setter để đẹp số.
- Nếu profile có `coverage_cmd` → chạy và ghi số như tham khảo, kèm nhận xét *chất lượng* phủ, không chỉ con số.

## Bảng bằng chứng: Claim → cần gì → KHÔNG đủ

| Tuyên bố | Cần gì | KHÔNG đủ |
|---|---|---|
| Test pass | Output lệnh test: 0 fail, exit 0 | Lần chạy trước; "đáng lẽ pass" |
| Lint sạch | Output linter: 0 error | Test pass (test ≠ lint) |
| Build được | Lệnh build: exit 0 | Lint sạch (lint ≠ compile) |
| Bug đã hết | Test đúng triệu chứng gốc: pass | Đã sửa code → "chắc hết" |
| Regression test có tác dụng | Đã kiểm red-green | Test pass 1 lần |
| Hành vi tương đương (migration) | So từng kịch bản cũ vs mới | "Code tương tự nên chắc giống" |

## Red Flags — DỪNG

- Dùng "chắc", "có lẽ", "về cơ bản", "should".
- Tỏ ra hài lòng ("Ổn rồi!", "Xong!") *trước khi* chạy lệnh.
- Ghi PASS trong khi có test đỏ / có kịch bản chưa chạy.
- Tin "subagent báo thành công" mà không xem diff/kết quả thật.
- Bịa lệnh test khi không dò được, rồi coi như đã chạy.

## Rationalization table

| Lý do nguỵ biện | Sự thật |
|---|---|
| "Chắc chạy được rồi" | CHẠY lệnh đi |
| "Tôi tự tin" | Tự tin ≠ bằng chứng |
| "Lint pass là đủ" | Lint không kiểm compile/hành vi |
| "Không dò được lệnh nên bỏ qua test" | → BLOCKED + hỏi gate, không phải PASS |
| "Migration code y hệt nên khỏi so" | Parity phải chứng minh từng kịch bản |
| "Regression test pass rồi" | Chưa red-green thì chưa chứng minh gì |

## Hợp đồng đầu ra (`verification-report.md`)

Report PHẢI có, đủ để người khác tin mà không cần chạy lại:
1. **Lệnh đã chạy** (verbatim) + nguồn (profile/tự dò/gate).
2. **Kết quả thô**: pass/fail count, exit code, trích đoạn output khi fail.
3. **Bảng behavior-check**: yêu cầu → lệnh → kết quả.
4. **Coverage** (nếu có) + nhận xét chất lượng.
5. **Gap/Risk**: gì chưa phủ, rủi ro còn lại.
6. **Verdict**: `PASS` | `FAIL` | `BLOCKED` (BLOCKED = thiếu lệnh/môi trường, cần gate/team) — kèm 1 câu bằng chứng.

## Ranh giới

- CHỈ kiểm chứng + báo cáo; KHÔNG tự sửa code sản phẩm. Test fail / hành vi lệch → verdict FAIL, nêu rõ để quay lại bước tạo code. KHÔNG che giấu.
- KHÔNG nới lỏng luật vì "hết giờ" hay "chắc ổn".

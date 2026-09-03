---
name: verification-testing
description: Bước Verification & Testing của AIToolKit (khung dùng chung, mọi workflow, mọi ngôn ngữ) — kiểm chứng hành vi bằng bằng chứng tươi, sinh & chạy test, phán quyết PASS/FAIL/BLOCKED. Đọc artifact bước trước do orchestrator truyền, ghi verification-report.md.
---

# Shared — Verification & Testing

Preserve the validated task-base SHA and final-tree SHA from the explicit review predecessor in `verification-report.md`; delivery consumes only this forwarded provenance and never discovers an implementation artifact by filename.

Orchestrator gọi skill này, truyền: run_dir + `workflow_type` + đường dẫn artifact bước trước; migration còn nhận resolved per-run `automation_mode`. Chạy inline.

**Core principle:** Chỉ bằng chứng mới đổi được trạng thái. "Nhìn có vẻ đúng" không phải bằng chứng.

## Ngôn ngữ artifact

Nhận `artifact_language` do orchestrator truyền khi `workflow_type: migration`. Hiện chỉ hỗ trợ `artifact_language: vi`: đọc `templates/migration/verification-report.md` và viết tiêu đề, tóm tắt, blocker, khuyến nghị và nội dung gate bằng tiếng Việt UTF-8; giữ nguyên mọi field machine-readable, enum, ID, path, command, log, trace field và cột bảng contract. Feature/bugfix đọc `templates/verification-report.md` và giữ contract hiện có.

## The Iron Law

```
KHÔNG TUYÊN BỐ "ĐẠT" NẾU CHƯA CHẠY LỆNH KIỂM CHỨNG TRONG CHÍNH LƯỢT NÀY.
```

Nếu bạn chưa chạy lệnh và đọc output ở lượt này, bạn không được ghi verdict PASS.
**Vi phạm câu chữ của luật = vi phạm tinh thần của luật** — diễn đạt khác đi ("chắc pass", "về cơ bản ổn") vẫn là vi phạm.

Kỷ luật này kế thừa superpowers:verification-before-completion — **REQUIRED BACKGROUND**.

## Việc cần làm (thứ tự)

1. **Đọc hợp đồng & input.** Đọc `aitoolkit-schemas`. Artifact **bước ngay trước** (vd `review-report.md`, hoặc artifact code/fix) = đường dẫn orchestrator truyền vào, dùng để biết nhánh + file đã đổi + yêu cầu gốc. `workflow_type: migration` đọc `templates/migration/verification-report.md`; feature/bugfix đọc `templates/verification-report.md`.
2. **Xác định lệnh kiểm chứng (language-agnostic).** Tuân thủ đúng thứ tự trong `aitoolkit-schemas` §2: `explicit profile -> existing project scripts/config -> marker detection -> human gate`. Chỉ dùng [command-detection.md](command-detection.md) ở bước marker detection; vẫn không rõ → ghi "chưa xác định" và để gate hỏi, KHÔNG bịa lệnh. Ghi lệnh thực tế **verbatim** vào report.
3. **Chọn chiến lược test theo loại thay đổi** (bảng dưới) và **viết test còn thiếu** (dùng superpowers:test-driven-development).
4. **Chạy** test + lint + build đã xác định. Đọc **toàn bộ** output, exit code, đếm số fail.
5. **Lập bảng behavior-check**: mỗi yêu cầu/kịch bản → lệnh chứng minh → kết quả thật.
6. **Phán quyết** PASS/FAIL/BLOCKED kèm bằng chứng, ghi `<run_dir>/verification-report.md` theo template (`status: draft`).

## Chiến lược test theo loại thay đổi

The caller-provided `workflow_type` is authoritative for this run, including when `docs/aitoolkit/project.yaml` contains a `migration` section. Never read or override it from the persistent profile or infer it from `RUN_DIR`. Chọn đúng hàng `feature | bugfix | migration`; thiếu/sai enum thì ghi BLOCKED thay vì mặc định sang migration.

| Loại | Test bắt buộc | Bằng chứng "đủ" |
|---|---|---|
| **Feature/tính năng mới** (`workflow_type: feature`) | Behavior test cho mỗi hành vi trong yêu cầu + edge case | Test mô tả *hành vi mong muốn*, xanh; edge case có mặt |
| **Bugfix** (`workflow_type: bugfix`) | **Regression test có chứng minh red-green** | Revert fix → test PHẢI FAIL → restore fix → test PASS. Chỉ pass 1 lần KHÔNG đủ |
| **Migration** (`workflow_type: migration`) | Parity/equivalence: cùng input, so hành vi cũ vs mới | Bảng kịch bản cũ==mới; chênh lệch phải được giải thích, không giấu |

**Regression red-green (bugfix) — không thể bỏ:** một test "pass ngay từ đầu" không chứng minh nó bắt được bug. Phải thấy nó ĐỎ khi chưa có fix.

**Baseline cho parity (migration) — "hành vi cũ" lấy ở đâu:** dùng golden output/kỳ vọng đã ghi trong artifact bước trước (discovery/mapping mô tả hành vi Native mong đợi); nếu code cũ còn chạy được thì chạy nó lấy output làm mốc. KHÔNG tự bịa "chắc giống"; kịch bản nào không có mốc → liệt vào Gap, không tính là parity đã chứng minh.

## Migration-only handoff extension

Read `aitoolkit/contracts/activation-slice.md` as the sole canonical definition. Preserve the immediate predecessor Activation Slice envelope without loss: keep the complete case-sensitive slice ID set, Applicability, all nine canonical seam rows, and every predecessor Source Reference and Trace ID. Source Reference enrichment is append-only, and predecessor Trace IDs remain a subset of successor Trace IDs. Never reconstruct it from cumulative artifacts.

Khi orchestrator gọi step này với `workflow_type: migration`, immediate predecessor phải chứa đúng một section `Selected Migration Unit`. Validate và copy nguyên vẹn `migration_unit_id`, plan reference, approval reference, mode constraint, `Bootstrap Scope`, Foundation Baseline ID, foundation baseline reference, foundation baseline approval reference, baseline reference, và trace IDs sang report mới trước khi chạy verification.

Validate and copy the canonical `Activation Slice` section before running verification. Missing, added, reclassified, narrowed, or trace-losing slice evidence yields `status: draft` and `result: blocked`; do not infer it from the diff, source tree, or cumulative artifacts.

- Ghi front matter migration là `result: complete | blocked` ngoài lifecycle `status: draft`.
- Thiếu, mơ hồ, hoặc mismatch bất kỳ field nào thì ghi `result: blocked`; không chạy tiếp bằng selector/baseline tự suy từ source hoặc artifact cũ.
- Với feature and bugfix, không áp dụng extension, không yêu cầu các field này, và giữ nguyên output contract hiện có.

## Environment-unavailable checks

Áp dụng phần này chỉ khi caller truyền `workflow_type: migration`. `automation_mode` không cho step-skill quyền tự duyệt hoặc tự waiver.

Phân loại từng lệnh evidence theo command role và lifecycle. Executable lookup hoặc device/emulator/service/network check là `availability probe`; chỉ ghi `not-started` khi `required test/build/baseline command` chưa bắt đầu. Khi failed probe chứng minh command bắt buộc không thể start chỉ vì capability không khả dụng, ghi check native là `NOT_RUN + BLOCKED`, giữ `status: draft`, `result: blocked`, verdict `BLOCKED`, và lưu verbatim command/capability error cùng evidence reference. Nonzero của probe là capability evidence, không phải correctness/regression result. Chỉ separate-probe + `not-started` mới là environment-waiver candidate. Không ghi `WAIVED` trong step-skill output.

Sau khi step trả artifact, orchestrator-only classifier vẫn phải giữ output migration của bước verification ở `status: draft`, `result: blocked`; bước 12 không sở hữu lifecycle waiver. `NOT_RUN + WAIVED` và `result: partial` chỉ mô tả exact step-10 code-migration record được truyền vào, không phải transition của step 12. Chỉ đúng bước 10 mới có thể mang exact approved/partial waiver tuple theo Activation Slice contract. Check chưa chạy vẫn never `PASS`, và report phải giữ native blocker/evidence.

Lệnh đang được đánh giá là `required test/build/baseline command`. Ghi `started-without-correctness/regression-result` nếu process fail trước khi tạo result; ghi `started-and-produced-correctness/regression-result` nếu đã tạo result. Any started required command is waiver-ineligible, whether or not it produces a correctness/regression result. Nếu required command starts and returns a correctness/regression failure while an environment symptom also exists, chọn legal pair `FAIL` + `BLOCKED` với exit code/output thật; trường hợp này thắng environment symptom, không phải environment-unavailable và không waiver. Missing, ambiguous, hoặc contradictory role/lifecycle evidence cũng giữ `BLOCKED`. Với feature and bugfix, bỏ qua transition này và giữ behavior hiện có.

## Check Outcome Legal Pairs

Choose one complete row for each migration check. Do not select the two fields independently. `WAIVED` requires `NOT_RUN`; `PASS + WAIVED` is invalid. Only required-command lifecycle `not-started` may use `WAIVED`. Lifecycle `started-without-correctness/regression-result` requires `FAIL` + `BLOCKED`.

Với kiểm tra migration, chọn chính xác một hàng đầy đủ. Không chọn độc lập Execution Status và Verification Disposition; khi Verification Disposition là `WAIVED`, Execution Status phải là `NOT_RUN`. Chỉ vòng đời lệnh bắt buộc `not-started` mới được dùng `WAIVED`. Vòng đời `started-without-correctness/regression-result` yêu cầu `FAIL` + `BLOCKED`.

| Execution Status | Verification Disposition | Meaning |
|---|---|---|
| `PASS` | `verified` | required command ran and passed |
| `FAIL` | `BLOCKED` | required command started and returned failure |
| `NOT_RUN` | `BLOCKED` | required command did not run; native blocker |
| `NOT_RUN` | `WAIVED` | eligible environment blocker; orchestrator-only |

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
6. **Verdict**: native step verdict là `PASS` | `FAIL` | `BLOCKED` — kèm 1 câu bằng chứng.
7. **Migration only**: thêm `Kết quả từng kiểm tra`; mỗi check ghi command role, required-command lifecycle, một cặp nguyên vẹn từ `Các cặp kết quả kiểm tra hợp lệ`, và evidence. Waiver hợp lệ dùng đúng `NOT_RUN + WAIVED`; `WAIVED` chỉ xuất hiện sau orchestrator-only transition và không đồng nghĩa `PASS`. Feature/bugfix giữ output hiện có.
8. **Task Provenance**: derive exactly one row from the immediate review predecessor's `Change Hygiene`: task/unit ID, task-base SHA, and final-tree SHA remain ordinally exact, while `Source Artifact` resolves to that exact review artifact path. Missing, unrelated-source, or mismatched lineage blocks.
8. **Migration only**: preserve bảng `Selected Migration Unit`, migration `result`, native blocker/evidence và mọi waiver đã được orchestrator ghi; feature/bugfix bỏ qua field này.
9. **Migration only**: preserve bảng `Activation Slice` with the identical slice set, Applicability, all nine canonical rows, Source Reference evidence, and Trace IDs from the review predecessor.
10. **Migration blocked only**: when the routed output is `result: blocked` and Activation Slice/handoff validation is otherwise valid, emit exactly one `Domain Blocker` table with non-placeholder `Blocker` and `Evidence Reference`; omit it from non-blocked migration output. Feature/bugfix behavior is unchanged.

## Ranh giới

- CHỈ kiểm chứng + báo cáo; KHÔNG tự sửa code sản phẩm. Test fail / hành vi lệch → verdict FAIL, nêu rõ để quay lại bước tạo code. KHÔNG che giấu.
- KHÔNG nới lỏng luật vì "hết giờ" hay "chắc ổn".

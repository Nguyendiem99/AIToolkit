---
name: ai-review
description: Bước AI Review của AIToolKit (khung dùng chung, mọi workflow, mọi ngôn ngữ) — review diff theo intent + failure mode phổ quát, phân loại Critical/Major/Minor theo blast-radius, đếm Critical để gate. Đọc artifact bước trước do orchestrator truyền, ghi review-report.md.
---

# Shared — AI Review

Orchestrator gọi skill này, truyền: run_dir + đường dẫn artifact bước trước. Chạy inline.

**Core principle:** Review **diff** đối chiếu *ý định* và *các kiểu lỗi đã biết*; phân loại theo **mức tác hại (blast radius)**, không theo khẩu vị.

Đây là wrapper LGE trên superpowers:requesting-code-review — **REQUIRED SUB-SKILL**. superpowers lo phần dispatch reviewer sạch context; skill này thêm **rubric mức độ + dimensions + rule LGE** và chuẩn hoá report.

## Việc cần làm (thứ tự)

1. **Đọc hợp đồng & rule.** Đọc `aitoolkit-schemas`, template `review-report.md`, [severity-rubric.md](severity-rubric.md), và `lge-rules` (mọi mục; mục còn mốc «LGE team điền» ⇒ bỏ qua, degrade gracefully). Nếu có `docs/aitoolkit/project.yaml.review_focus` → bơm vào danh sách quan tâm.
2. **Khoanh vùng review.** Artifact **bước ngay trước** (artifact code/fix) = đường dẫn orchestrator truyền vào, để biết nhánh. Mốc diff `<base>` = `project-profile.base_branch` (§4) nếu có, else `HEAD~1`: `BASE=$(git rev-parse "<base>" 2>/dev/null || git rev-parse HEAD~1)`, `HEAD=$(git rev-parse HEAD)`. Review **diff** `BASE..HEAD` + đủ ngữ cảnh xung quanh — không review cả repo.
3. **Dispatch reviewer.** Dùng superpowers:requesting-code-review để giao diff + intent cho reviewer subagent (không đưa lịch sử phiên). Yêu cầu nó soi theo **dimensions** dưới đây + rule LGE đã điền.
4. **Phân loại** mọi phát hiện theo rubric Critical/Major/Minor (xem [severity-rubric.md](severity-rubric.md)). Phân vân giữa 2 mức → **chọn mức cao hơn**.
5. **Phán quyết** và ghi `<run_dir>/review-report.md` theo template (`status: draft`).

## Dimensions (language-agnostic — soi *vấn đề*, không soi cú pháp một ngôn ngữ)

1. **Đúng ý định** — code làm đúng yêu cầu gốc (artifact bước trước)? Có làm dư/thiếu?
2. **Xử lý lỗi & edge** — null/empty, biên, input xấu, đường thất bại; lỗi bị nuốt?
3. **Bảo mật** — injection, secret hard-code, thiếu authz/validation, dữ liệu nhạy cảm log ra.
4. **Tài nguyên & hiệu năng** — leak (file/handle/subscription), vòng lặp/độ phức tạp xấu, N+1.
5. **Concurrency** — race, shared state không bảo vệ, thiếu dọn dẹp bất đồng bộ.
6. **Tương thích hợp đồng/API** — phá vỡ caller hiện có, đổi behavior public không cố ý.
7. **Độ đủ của test** — hành vi mới có test? bug có regression test? (không tự viết test ở đây — đó là bước verification).
8. **Khả đọc/bảo trì** — tên, ranh giới, trùng lặp; chỉ là Minor trừ khi che giấu lỗi thật.
9. **Rule LGE** (nếu `lge-rules` đã điền) — convention, performance, security, null-safety.

## Rubric mức độ (tóm tắt — chi tiết ở severity-rubric.md)

| Mức | Nghĩa | Hành động gate |
|---|---|---|
| **Critical** | Sai đúng / mất dữ liệu / lỗ hổng bảo mật / crash / phá vỡ hợp đồng hiện có / không đảo ngược | **Chặn** — phải sửa trước khi đi tiếp |
| **Major** | Thiếu xử lý lỗi, thiếu test cho hành vi mới, hồi quy hiệu năng, vi phạm rule cứng LGE | Sửa trước khi merge |
| **Minor** | Style, naming, micro-opt, doc | Ghi nhận, không chặn |

Gate của bước review **chỉ chặn Critical** (verdict `Reject` khi `Critical count > 0`). **Major KHÔNG tự lọt êm:** ghi vào report với verdict `Approve-with-fixes` và được **mang tới bước tạo code / gerrit** để xử lý trước merge; đừng coi `Approve-with-fixes` là "xong".

## Red Flags — DỪNG

- "Thay đổi nhỏ, khỏi review" → mọi diff đều review.
- Bới style Minor mà bỏ sót Critical đúng-sai.
- Duyệt khi còn Critical chưa xử lý.
- Cãi phản hồi kỹ thuật đúng thay vì sửa.
- Tự sửa code trong bước này (sai vai — xem Ranh giới).

## Rationalization table

| Lý do nguỵ biện | Sự thật |
|---|---|
| "Code rõ ràng, chắc đúng" | Rõ với bạn ≠ đúng. Soi theo dimensions |
| "Không có test nhưng hiển nhiên đúng" | Thiếu test cho hành vi mới = Major |
| "Chỉ đổi 1 dòng" | 1 dòng vẫn có thể là Critical |
| "lge-rules trống nên khỏi review" | Vẫn review theo 8 dimensions phổ quát |
| "Phân vân Major/Critical, cho Major" | Phân vân → chọn mức CAO hơn |

## Hợp đồng đầu ra (`review-report.md`)

1. **Tổng quan**: phạm vi (SHA `BASE..HEAD`), rule LGE áp dụng (hoặc "chưa có").
2. **Findings** nhóm theo mức; mỗi cái: `file:line` + vấn đề + **fix đề xuất**.
3. **Critical count** (số nguyên) — dùng để gate.
4. **Verdict**: `Approve` (0 Critical, 0 Major) | `Approve-with-fixes` (còn Major) | `Reject` (còn Critical).

## Ranh giới

- CHỈ review + báo cáo; KHÔNG tự sửa code (dev sửa, hoặc quay lại bước tạo code nếu Critical).
- KHÔNG chạy test (đó là bước verification-testing) và KHÔNG upload Gerrit.

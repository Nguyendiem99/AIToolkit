# Severity Rubric (language-agnostic)

Phân loại theo **blast radius** — hậu quả nếu lỗi lọt ra sản xuất — không theo độ khó sửa hay khẩu vị. Quy tắc vàng: **phân vân giữa 2 mức → chọn mức cao hơn.** Ranh giới cứng: **kết quả sai hoặc crash trên input hợp lệ LUÔN là Critical**, bất kể đường chính hay đường phụ (chỉ null/edge trên input *bất thường* mới có thể là Major).

## Critical — CHẶN, phải sửa trước khi đi tiếp

Đặc trưng: hậu quả nghiêm trọng hoặc không đảo ngược cho người dùng/dữ liệu/hệ thống.

- Sai đúng (logic cho kết quả sai) trên đường đi chính.
- Mất/hỏng dữ liệu; ghi đè không phục hồi được.
- Lỗ hổng bảo mật: injection, secret hard-code, thiếu authz, lộ dữ liệu nhạy cảm.
- Crash/hang trên input hợp lệ.
- Phá vỡ hợp đồng công khai hiện có (đổi behavior mà caller đang dựa vào).
- Race condition gây kết quả sai không xác định.

## Major — sửa trước khi merge

Đặc trưng: sai/rủi ro thật nhưng phạm vi hẹp hoặc có đường vòng.

- Thiếu xử lý lỗi/edge (null, empty, biên, input xấu) trên đường phụ.
- **Thiếu test cho hành vi mới**, hoặc **bugfix không có regression test**.
- Hồi quy hiệu năng đáng kể (độ phức tạp xấu, leak tài nguyên, N+1).
- Vi phạm **mandatory review rule** đã resolve từ approved project profile/project pack.
- Ranh giới/trách nhiệm sai khiến dễ hỏng về sau.

## Minor — ghi nhận, không chặn

- Style, naming, format, thứ tự import.
- Micro-optimization không đo được.
- Thiếu/nhầm comment, doc.
- Trùng lặp nhỏ chưa gây lỗi.

*Ngoại lệ:* một vấn đề "trông Minor" nhưng **che giấu lỗi thật** (vd tên hàm nói dối về hành vi dẫn tới dùng sai) → nâng lên Major.

## Verdict gate

Evaluate Rule Resolution first. Chỉ khi state là `RESOLVED` mới xét severity counts. `BLOCKED` là rule-resolution gate độc lập, không phải Critical finding giả.

| Rule Resolution | Critical count | Major count | Verdict |
|---|---|---|---|
| BLOCKED | 0 | 0 | Reject |
| BLOCKED | any | any | Reject |
| RESOLVED | >=1 | any | Reject |
| RESOLVED | 0 | >=1 | Approve-with-fixes |
| RESOLVED | 0 | 0 | Approve |

`Critical count` phải xuất hiện dạng số trong `review-report.md`, nhưng severity counts không được override `Rule Resolution: BLOCKED`.

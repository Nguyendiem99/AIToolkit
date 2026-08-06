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
- Vi phạm **rule cứng** của LGE (khi `lge-rules` đã điền và đánh dấu bắt buộc).
- Ranh giới/trách nhiệm sai khiến dễ hỏng về sau.

## Minor — ghi nhận, không chặn

- Style, naming, format, thứ tự import.
- Micro-optimization không đo được.
- Thiếu/nhầm comment, doc.
- Trùng lặp nhỏ chưa gây lỗi.

*Ngoại lệ:* một vấn đề "trông Minor" nhưng **che giấu lỗi thật** (vd tên hàm nói dối về hành vi dẫn tới dùng sai) → nâng lên Major.

## Áp lên gate

- Còn ≥1 **Critical** → verdict `Reject`; conductor không nên qua gate cho tới khi hết.
- Còn **Major** (0 Critical) → `Approve-with-fixes`; ghi rõ để bước sau/dev xử lý.
- 0 Critical, 0 Major → `Approve`.

`Critical count` phải xuất hiện dạng số trong `review-report.md` để bước/gate quyết định dựa vào nó.

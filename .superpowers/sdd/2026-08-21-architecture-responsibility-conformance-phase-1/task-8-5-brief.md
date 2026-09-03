# Task 8.5: Khép seam AI-review producer sang v1 responsibility handoff

## Bối cảnh

Task 7/8 consumer đã fail-closed và yêu cầu review artifact có lifecycle/provenance/handoff v1. Task 8 final review xác nhận producer hiện tại (`shared/ai-review` và review-report template) chưa hướng dẫn hoặc dựng được envelope đó, nên pipeline thật sẽ bị chặn dù consumer đúng.

Base: `548756e2ab8089c391c87471eaab138a50532f7d`.

## Phạm vi dự kiến

- `aitoolkit/skills/shared/ai-review/SKILL.md`
- canonical review-report template thực sự được producer dùng (xác định bằng routing/integrity evidence; không sửa cả hai template nếu một file không authoritative)
- focused validation/scenario files cần thiết để chứng minh producer output đi qua `Test-ResponsibilityHandoff` và Task 8 initial-review resolver.

Mở rộng file chỉ khi có evidence trực tiếp và ghi rõ trong report. Không sửa consumer để nới validation.

## Yêu cầu

1. RED bằng artifact được render đúng theo producer/template hiện tại nhưng bị Task 7/8 consumer reject vì thiếu lifecycle/provenance/handoff v1.
2. Producer phải yêu cầu và template phải biểu diễn đúng canonical bounded front matter, independent source/diff provenance, Responsibility Handoff v1 và exact immediate-predecessor linkage mà validator hiện hành tiêu thụ.
3. Không tạo schema riêng, không copy enum sai lệch, không tự khai PASS thay cho independent inventory Task 6.
4. GREEN phải chứng minh artifact producer-realistic đi qua focused responsibility-handoff và initial-review/terminal-chain consumer; thêm negatives cho thiếu/stale/cross-run provenance nếu chưa được cover tại seam producer.
5. Chạy focused responsibility-handoff, architecture-review, Skills, Templates và `-Check All`; không chạy full mutation suite.
6. Fresh scoped review; fix findings theo SDD. Một commit duy nhất: `fix: emit responsibility review handoff evidence`.
7. Ghi `task-8-5-report.md` và cập nhật ledger. Worktree sạch, không chạm `issue/`.

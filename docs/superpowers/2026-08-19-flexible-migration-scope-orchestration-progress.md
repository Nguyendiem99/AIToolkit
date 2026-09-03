# Tiến độ Flexible Migration Scope Orchestration

**Cập nhật:** 2026-08-19
**Trạng thái tổng thể:** đang triển khai, chưa hoàn tất
**Spec:** `docs/superpowers/specs/2026-08-19-flexible-migration-scope-orchestration-design-vi.md`
**Plan:** `docs/superpowers/plans/2026-08-19-flexible-migration-scope-orchestration.md`

## Git state

- Commit chứa spec/plan: `7b68b9a docs: design flexible migration scope orchestration`.
- Commit Task 1: `test: isolate migration framework mutations`, amend từ checkpoint `96c160d` để Task 1 vẫn là đúng một commit; dùng `git log -1` để lấy SHA sau review-fix amend.
- Commit Task 2: `feat: define migration scope contracts`; SHA được ghi trong task report sau khi tạo commit.
- Integration branch: `fmso/integration`.
- Integration worktree: `AIToolkit/AIToolkit-main/.claude/worktrees/fmso-integration`.
- Repository chưa cấu hình Git remote; không thể push ra server.
- Checkout `master` có thay đổi cũ ngoài scope trong `aitoolkit/skills/aitoolkit/migrate/SKILL.md` và các issue documents; không được reset hoặc ghi đè.

## Trạng thái task

| Task | Trạng thái | Bằng chứng/ghi chú |
|---|---|---|
| Task 1 — baseline và isolated mutation tests | `complete` | Full mutation suite exit `0` trong 63m32s; main validator `All` và source-integrity PASS; commit `test: isolate migration framework mutations` |
| Task 2 — contracts/schema/interfaces | `complete` | Hai canonical contracts, schema shapes, sáu validator modules và public routing đã kiểm chứng; full mutation suite exit `0` trong 67m29.6s |
| Task 3 — master artifacts | `pending` | Foundation Task 2 sẵn sàng; có thể bắt đầu Wave 2 sau review gate |
| Task 4 — scope orchestrator | `pending` | Foundation Task 2 sẵn sàng; có thể bắt đầu Wave 2 sau review gate |
| Task 5 — canonical adapters | `pending` | Foundation Task 2 sẵn sàng; có thể bắt đầu Wave 2 sau review gate |
| Task 6 — target conformance | `pending` | Foundation Task 2 sẵn sàng; có thể bắt đầu Wave 2 sau review gate |
| Task 7 — structural pre-edit gate | `pending` | Chờ Task 5 và 6 |
| Task 8 — architecture-first review/KB | `pending` | Chờ Task 6 |
| Task 9 — integration/compatibility/E2E | `pending` | Chờ toàn bộ task trước |

Task 2 hoàn tất không có nghĩa feature tổng thể hoặc Wave 2 hoàn tất. Tasks 3–6 mới chỉ `pending/ready`, chưa triển khai.

## Task 1 đã hiện thực

Các file thuộc commit Task 1:

```text
aitoolkit/tests/helpers/IsolatedFixture.ps1
aitoolkit/tests/validate-migration-framework.ps1
aitoolkit/tests/validate-migration-framework.Tests.ps1
docs/superpowers/2026-08-19-flexible-migration-scope-orchestration-progress.md
```

- Mutation suite chạy trong fixture unique dưới system temp; source checkout được bảo vệ bằng tree digest trước/sau.
- Validator nhận `-Root`, resolve một lần, và vẫn giữ default root tương thích.
- Cleanup xác thực temp boundary/container name trước khi xóa; bounded worker pool chỉ quản lý jobs/processes do harness sở hữu.
- Mỗi final-fix cluster song song dùng fixture riêng; kết quả và diagnostics được nhận lại theo cluster order cố định.
- PowerShell 5.1 worker đặt UTF-8 deterministically trước khi launch native child để giữ diagnostics Unicode.
- Mutation CRLF, removed-route, automation soft gate và technical-design gate đều dùng alter-or-fail để fixture drift không thể biến expected-negative case thành false PASS.

## Verification Task 1

### Full mutation suite

```powershell
& .\aitoolkit\tests\validate-migration-framework.Tests.ps1
```

```text
FULL_RETRY_EXIT=0 DURATION_MS=3812467
PASS: focused migration framework tests
```

Duration 63m32s. Đây là full suite, không phải selector hoặc partial run.

### Main validator

```powershell
& .\aitoolkit\tests\validate-migration-framework.ps1 -Target All
```

```text
MAIN_ALL_EXIT=0 DURATION_MS=14990
PASS: migration framework (All)
```

### Source integrity

```powershell
& .\aitoolkit\tests\validate-migration-framework.Tests.ps1 -SourceIntegrityOnly
```

```text
SOURCE_INTEGRITY_EXIT=0 DURATION_MS=4024
PASS: source-integrity mutation scenario
```

Final hygiene có `PARSE_ERRORS=0`, `TEMP_FIXTURES=0`, `VALIDATOR_PROCESSES=0`, `git diff --check` exit `0`, và không có diff trong `aitoolkit/skills/aitoolkit/migrate/SKILL.md`.

## Performance/root-cause rulings của Task 1

1. Full-suite timeout hơn 3 giờ do hàng trăm child validator launches; riêng final-fix có 123 artifact-validator calls. Isolation smoke chỉ mất 1.25s, nên copy/digest không phải root bottleneck.
2. Tám final-fix cluster độc lập được chạy bằng bounded pool tối đa 4 worker, mỗi cluster có fixture riêng. Focused `Duplicates` + `Pipes` giảm từ 126.752s sequential xuống 26.913s sau parallelism và cache, vẫn giữ toàn bộ coverage/assertions.
3. Profiling `Contracts` xác định Activation Slice Markdown bị parse lặp lại theo section. Exact-text line-state/visible-heading cache giảm hai Contracts checks từ 43.261s xuống 8.746s; text mutation khác luôn recompute.
4. Full optimized run đầu tiên hoàn tất sau 63m40s và lộ semantic harness failures thay vì timeout. Các family Unicode, CRLF, route diagnostics, automation mutation drift và technical-design gate đều được reproduce RED, sửa tối thiểu, focused GREEN, rồi xác nhận bằng full-suite PASS 63m32s.
5. Full suite vẫn là integration gate dài khoảng 64 phút; không được coi là fast unit suite, nhưng đã nằm dưới cap 2 giờ có bằng chứng.

## Task 2 đã hiện thực

- `contracts/migration-scope-orchestration.md` là nguồn chuẩn duy nhất cho requested scope, work item, adapter, attempt, revision, transition, resume và completion.
- `contracts/target-structure-conformance.md` là nguồn chuẩn duy nhất cho tám concern, exemplar status, conformance/deviation, structural gate, ba assurance states và architecture-first review.
- `aitoolkit-schemas` chỉ bổ sung front matter, machine shape và compatibility conversion; không sao chép các canonical table/enum.
- Sáu module trong `tests/validation/` đều có đúng một entry function, body thật, contract-derived rule và được gọi qua đúng target `Contracts`, `Skills` hoặc `Orchestrators`.
- Main validator giữ nguyên `-Root` của Task 1; mutation suite thêm focused selector `-ScopeContractsOnly` nhưng không nới lỏng assertion cũ.
- Historical unit-only artifacts vẫn đọc được nhưng không thể resume tới production mutation trước compatibility conversion.

## Verification Task 2

```text
RED_CANONICAL_SOURCE_EXIT=1 DURATION_MS=4126
FAIL: Missing migration scope orchestration contract resource
FAIL: Missing target structure conformance contract resource
```

```text
SCOPE_MUTATIONS_EXIT=0 DURATION_MS=218225
PASS: migration scope contract scenarios
```

```text
Contracts PASS (4.5s)
Skills PASS (2.5s)
Orchestrators PASS (1.8s)
ROOT_OVERRIDE_PASS_EXIT=0 MUTATION_EXIT=1 SOURCE_UNCHANGED=True DURATION_MS=20982
```

```text
FULL_MUTATION_EXIT=0 DURATION_MS=4049595
PASS: focused migration framework tests
```

Full mutation suite Task 2 hoàn tất trong 67m29.6s. Đây là đúng một full run; focused scope mutations và root-override fixture là các gate riêng trước đó.

### Fix round 1 — full architecture-first order

Review phát hiện canonical contract và hai validators đã rút gọn authority order,
bỏ `master-scope/work-item alignment`, `project rule resolution`, matrix/exemplar
context và `security`, `performance`, `tests`. Exact assertion mới RED qua cả
`Contracts` và `Skills`, sau đó canonical contract cùng hai validators được khóa
theo đủ bảy bước của authority spec. Focused isolated mutation selector PASS;
full suite 67 phút không chạy lại theo fix-round ruling vì exact mutation và main
`All` cung cấp coverage cần thiết.

## Cách tiếp tục

1. Giữ commit Task 1 và Task 2 làm baseline đã kiểm chứng; không lặp lại helper/root override hoặc định nghĩa lại canonical contracts.
2. Tasks 3–6 đang `pending/ready` và có thể bắt đầu Wave 2 trong các worktree tách biệt sau review gate của Task 2.
3. Task 7 vẫn chờ Tasks 5 và 6; Task 8 vẫn chờ Task 6; Task 9 vẫn chờ toàn bộ task trước.
4. Không tuyên feature hoàn tất, scope complete hoặc Wave 2 complete chỉ dựa trên Tasks 1–2.

## Điều kiện không được tuyên bố

- Không được nói feature Flexible Migration Scope Orchestration đã hoàn tất.
- Không được nói Tasks 3–9 đã triển khai hoặc Wave 2 đã hoàn tất.
- Không được chạy Wave 2 song song nếu chưa thỏa dependency/review gate trong plan; Task 2 chỉ làm các task này sẵn sàng.

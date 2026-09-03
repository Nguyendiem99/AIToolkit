# Migration Pipeline Boundaries — Follow-up Design

- **Ngày:** 2026-08-10
- **Trạng thái:** Draft để review
- **Áp dụng cho:** Language-Agnostic Migration Framework

## 1. Mục tiêu

Đơn giản hóa migration thành workflow phân tích, hiện thực và kiểm chứng. Gerrit, CCC và Release không thuộc migration pipeline; chúng là skill độc lập, chỉ chạy khi người dùng gọi tường minh.

Framework tiếp tục hỗ trợ:

- `greenfield`: target mới, có bootstrap foundation được Tech Lead duyệt;
- `incremental`: target đã tồn tại, giữ architecture/convention và kiểm regression.

## 2. Ranh giới pipeline

Migration có đúng 15 bước:

| # | Step | Condition |
|---|---|---|
| 01 | Validate inputs/profile/pack | luôn chạy |
| 02 | Discover legacy và target | luôn chạy |
| 03 | Analyze requirements/UIUX | luôn chạy |
| 04 | Build inventory | luôn chạy |
| 05 | Map source → target | luôn chạy |
| 06 | Analyze gaps/conflicts | luôn chạy |
| 07 | Technical design/conformance | luôn chạy |
| 08 | Plan migration units | luôn chạy |
| 09 | Bootstrap foundation | chỉ greenfield unit có `Bootstrap Scope: required` |
| 10 | Implement selected unit | luôn chạy |
| 11 | AI review | luôn chạy |
| 12 | Verification testing | luôn chạy |
| 13 | Verify parity | luôn chạy |
| 14 | Verify regression | chỉ incremental |
| 15 | Knowledge capture | luôn chạy, bước cuối |

Migration không gọi hoặc route tới:

- `shared/gerrit-automation`;
- `shared/ccc-automation`;
- `shared/release`.

Ba skill trên tiếp tục tồn tại độc lập. Chúng không nhận handoff ngầm và không được migration tự kích hoạt.

## 3. Greenfield lifecycle

### 3.1 Foundation unit đầu tiên

Step 08 được phép lập kế hoạch cho foundation unit mà chưa có foundation baseline:

```yaml
migration_unit_id: UNIT-FOUNDATION
bootstrap_scope: required
foundation_baseline: pending-bootstrap
```

Sau Tech Lead design/plan gate, step 09 bootstrap unit đó. Bootstrap artifact tạo foundation baseline record:

```yaml
foundation_baseline_id: FOUNDATION-001
source_unit_id: UNIT-FOUNDATION
approval_reference: <approved-bootstrap-artifact>
status: approved
```

Step 10 của foundation unit dùng chính bootstrap artifact làm predecessor.

### 3.2 Greenfield unit về sau

Unit không thay đổi foundation dùng:

```yaml
bootstrap_scope: not-required
foundation_baseline_id: FOUNDATION-001
```

Step 09 bị skip. Step 10 đọc approved migration plan và resolve `foundation_baseline_id` trong target baseline/project pack đã được cập nhật sau bootstrap trước đó.

Nếu baseline thiếu, stale hoặc chưa approved thì `result: blocked`. Không yêu cầu baseline phải tồn tại khi lập foundation unit đầu tiên.

### 3.3 Cập nhật project pack sau bootstrap

Knowledge capture của foundation run ghi đề xuất cập nhật `target-baseline.md`. Việc cập nhật canonical project pack phải qua project-pack review gate; migration không tự sửa pack approved trong lúc chạy.

## 4. Incremental lifecycle

- `Bootstrap Scope` luôn là `not-required`.
- Target baseline và architecture hiện có là chuẩn.
- Step 10 capture baseline trước mutation.
- Step 14 regression là bắt buộc; không có whole-step waiver.
- Chỉ continuing baseline failure có thể được waiver theo identity và approval evidence.

## 5. Kết thúc và artifact handoff

Sau parity/regression, orchestrator truyền immediate predecessor cho Knowledge Capture:

- greenfield: `13-parity-report.md`;
- incremental: `14-regression-report.md`.

Knowledge Capture đọc toàn bộ artifact trong `RUN_DIR` để tổng hợp:

- selected unit và trace IDs;
- design/mapping decisions;
- changed files;
- review/test/parity/regression verdicts;
- conflicts, technical debt và lessons learned;
- foundation baseline update proposal nếu có.

Không còn yêu cầu envelope dành cho Gerrit sau bước cuối.

## 6. Onboarding ownership

Onboarding tự tạo bản nháp:

```text
docs/aitoolkit/project.yaml
docs/aitoolkit/migration-project/
├── SKILL.md
└── references/
    ├── legacy-system.md
    ├── target-baseline.md
    ├── architecture-rules.md
    ├── mapping-rules.md
    ├── uiux-rules.md
    ├── testing-rules.md
    └── definition-of-done.md
```

Người dùng không phải tự viết từ đầu. Onboarding chỉ publish canonical profile/pack sau Tech Lead review gate.

## 7. Tài liệu đầu vào

### 7.1 Truyền path hiện có

```text
/aitoolkit:migration-onboarding \
  --legacy ../legacy-app \
  --target . \
  --requirements ./requirements \
  --uiux ./design \
  --migration-docs ./migration-notes \
  --architecture-docs ./architecture
```

Mỗi option nhận file hoặc directory; option có thể lặp. Onboarding đọc tại chỗ, ghi path/evidence vào profile, không move hoặc sửa tài liệu gốc.

Project root được lấy từ current target-project context, không truyền như positional argument.

### 7.2 Inbox chuẩn tùy chọn

Nếu không truyền option tương ứng, onboarding tự dò:

```text
docs/aitoolkit/inputs/
├── requirements/
├── uiux/
├── migration/
└── architecture/
```

Inbox không bắt buộc. Explicit path có ưu tiên cao hơn inbox. Nếu cả hai cùng có dữ liệu, onboarding hợp nhất danh sách, loại duplicate bằng canonical path và ghi nguồn của từng document.

### 7.3 Định dạng và lỗi đầu vào

- File/directory không tồn tại hoặc không đọc được → `result: blocked`.
- Định dạng không đọc được → ghi unknown/blocker, không tự bỏ qua.
- Command/toolchain mơ hồ → giữ mode classification nếu mode có evidence độc lập, nhưng onboarding vẫn blocked cho tới khi command authority/scope được duyệt.
- Onboarding không sửa production source.

## 8. User workflow

```text
1. Chuẩn bị source và documents.
2. Chạy /aitoolkit:migration-onboarding ...
3. Review docs/aitoolkit/project.yaml và migration-project/.
4. Tech Lead duyệt project pack.
5. Chạy /aitoolkit:migrate <feature-slug>.
6. Duyệt artifact ở từng human gate.
7. Migration kết thúc tại Knowledge Capture.
8. Nếu cần Gerrit/CCC/Release, gọi skill độc lập trong yêu cầu riêng.
```

## 9. Thay đổi source cần thực hiện

1. Rút orchestrator migration từ 18 xuống 15 bước.
2. Xóa Gerrit/CCC/Release khỏi migration table, handoff policy, validator và docs.
3. Sửa greenfield foundation plan/bootstrap lifecycle để không deadlock.
4. Đưa Knowledge Capture thành consumer cuối của parity/regression.
5. Thêm onboarding CLI option và inbox resolver contract.
6. Giữ shared Gerrit/CCC/Release skills độc lập và không phụ thuộc migration pipeline.
7. Cập nhật fixtures, acceptance matrix và regression validator.

## 10. Tiêu chí chấp nhận

1. Migration orchestrator có đúng 15 bước và kết thúc bằng Knowledge Capture.
2. Không có Gerrit, CCC hoặc Release route trong migration orchestrator.
3. Ba delivery skill vẫn tồn tại và có thể gọi độc lập.
4. Foundation unit đầu tiên không yêu cầu baseline chưa thể tồn tại.
5. Later greenfield unit dùng approved foundation baseline và không bootstrap lại.
6. Incremental không bootstrap và regression vẫn bắt buộc.
7. Onboarding tự sinh profile/project pack draft, chỉ publish sau Tech Lead gate.
8. Onboarding chấp nhận explicit document paths và optional inbox.
9. Tài liệu gốc và production source không bị onboarding di chuyển/sửa.
10. Claude/Codex docs mô tả đúng user workflow mới.
11. Static validator có positive/negative coverage cho pipeline boundaries và hai greenfield paths.
12. Manual runtime/plugin evidence tiếp tục ghi PASS/BLOCKED trung thực.

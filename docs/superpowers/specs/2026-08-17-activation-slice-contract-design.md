# Activation Slice Contract Design

## Mục tiêu

Ngăn migration workflow kết luận một module hoặc feature đã sẵn sàng chỉ vì các component riêng lẻ tồn tại. Với feature được kích hoạt bởi config, profile hoặc capability, workflow phải truy vết và xác minh toàn bộ activation flow trước khi cho phép implementation.

## Phạm vi

Thiết kế này xử lý riêng F-01 trong remediation backlog. Nó bổ sung một contract dùng chung, cập nhật các migration step tạo hoặc chuyển tiếp evidence, cập nhật template tương ứng, và bổ sung regression validation. Nó không thay đổi command lifecycle, waiver, snapshot workspace hoặc artifact attempt semantics thuộc các finding khác.

## Kiến trúc

Tạo `aitoolkit/contracts/activation-slice.md` làm nguồn chuẩn duy nhất cho:

- điều kiện applicability;
- danh sách seam bắt buộc;
- schema của từng seam row;
- disposition và status hợp lệ;
- blocking rules;
- quy tắc chuyển tiếp giữa các artifact.

Các step-skill không sao chép lại toàn bộ định nghĩa. Chúng đọc contract dùng chung, thực hiện trách nhiệm của step, và giữ nguyên Activation Slice envelope trong handoff. Các migration template chứa section và bảng có shape cố định để validator có thể kiểm tra bằng máy.

## Điều kiện áp dụng

Activation Slice là bắt buộc khi requirement, source evidence, target convention hoặc mapping cho thấy feature/module được chọn hoặc kích hoạt bằng một trong các tín hiệu sau:

- config key;
- profile field;
- capability;
- feature flag;
- product or device type;
- runtime selector tương đương.

Nếu evidence chưa đủ để xác định có áp dụng hay không, step ghi applicability là `unknown` và `result: blocked`. Với feature không có activation selector, artifact ghi `not-applicable-approved` cùng evidence/approval reference; không được bỏ section.

## Activation flow bắt buộc

Mỗi applicable slice truy vết theo thứ tự:

1. `upstream-response`: service/config/profile response chứa activation signal.
2. `requested-key`: request hoặc subscription thực sự yêu cầu signal đó.
3. `parse-model`: parser/entity/model/copy/update path giữ signal.
4. `state-holder`: state container nhận và phát signal.
5. `selector`: provider/selector quyết định module được chọn.
6. `construct`: factory/router/controller tạo hoặc chọn strategy phù hợp.
7. `render`: entry point render module tương ứng.
8. `downstream-consumer`: route, deeplink và action flow dùng cùng quyết định.
9. `test`: acceptance evidence chứng minh activation flow và lifecycle.

Một project pack có thể đổi tên technology-specific element nhưng không được bỏ semantic seam.

## Data contract

Mỗi slice có stable ID `ACT-###`, applicability và đúng một row cho mỗi seam bắt buộc:

| Field | Contract |
|---|---|
| `Activation Slice ID` | Stable `ACT-###` |
| `Applicability` | `applicable \| not-applicable-approved \| unknown` |
| `Seam` | Một trong chín seam chuẩn |
| `Input` | Dữ liệu hoặc signal đi vào seam |
| `Output` | Dữ liệu hoặc quyết định đi ra seam |
| `Source Reference` | Reference kiểm chứng được như `path:line`, document section hoặc command evidence |
| `Trace IDs` | Requirement, discovery, inventory, mapping và conflict IDs liên quan |
| `Disposition` | `implement \| reuse \| deferred-approved \| not-applicable-approved` |
| `Status` | `verified \| missing \| conflict \| unknown` |
| `Decision Reference` | Bắt buộc cho disposition cần approval; nếu không thì `not-applicable` |
| `Deferred Unit ID` | Bắt buộc cho `deferred-approved`; nếu không thì `not-applicable` |

Không được dùng ô trống để ngầm biểu diễn `not-applicable`.

## Gate rules

Một applicable Activation Slice chỉ được coi là complete khi:

- có đủ chín seam;
- mỗi seam có source reference và trace IDs;
- mỗi seam có `Status = verified`;
- disposition thuộc enum hợp lệ;
- `deferred-approved` có decision reference và migration unit đích;
- router/controller ownership không còn conflict;
- async selector lifecycle đã được thiết kế và có test disposition.

Thiếu một điều kiện làm artifact hiện tại có `status: draft`, `result: blocked`. `partial` không hợp lệ khi thiếu seam có thể ngăn module được kích hoạt.

## Router ownership và async lifecycle

Seam `construct` phải ghi đúng một router mapping policy:

- `base-owned`;
- `specialized-owned`;
- `injected-strategy`;
- `compatibility-dual-path`.

`compatibility-dual-path` cần compatibility reason, owner, approval reference và parity-test trace. Nếu base và specialized router cùng sở hữu mapping mà không có policy được phê duyệt, tạo architecture conflict và block.

Nếu activation state có thể đến hoặc thay đổi bất đồng bộ, technical design phải ghi:

- initial loading behavior;
- update/watch strategy;
- reselection behavior;
- state preservation/reset behavior;
- failure behavior;
- lifecycle test trace.

Một one-shot read không được xem là verified nếu state có thể cập nhật sau đó mà không có evidence chứng minh immutability.

## Trách nhiệm theo step

### Discovery

Phát hiện applicability, tạo `ACT-###`, khảo sát cả upstream và downstream, và ghi `missing` thay vì suy component mẫu là đủ.

### Build Inventory

Biến mỗi seam thiếu hoặc cần thay đổi thành inventory coverage có stable trace. Không dedupe các seam khác nhau chỉ vì chúng nằm trong cùng component.

### Feature Mapping

Gán strategy/disposition cho từng seam và map sang target reference hoặc migration unit. Deferred seam phải có approved decision và unit đích.

### Analyze Gaps and Conflicts

Mở gap cho missing seam và conflict cho ownership/lifecycle mâu thuẫn. Router source-of-truth chưa quyết định là blocking conflict.

### Technical Design

Chốt data flow, router policy, async lifecycle và test strategy cho toàn slice. Design không được `complete` nếu slice chưa executable end-to-end.

### Plan Waves

Giữ các dependency seam đúng thứ tự. Một unit có thể implement một phần slice chỉ khi các seam còn lại được `deferred-approved` tới unit xác định và acceptance của unit hiện tại không tuyên bố module đã activatable.

### Code Migration

Entry gate yêu cầu Activation Slice envelope được duyệt. Changed-file rows và tests phải liên kết tới seam/trace IDs đã duyệt; implementation không tự thu hẹp slice.

### AI Review

So diff và tests với Activation Slice. Bỏ sót seam làm module không thể kích hoạt là Critical; duplication/ownership không traced hoặc thiếu lifecycle coverage ít nhất là Major, nâng lên Critical khi gây correctness failure.

## Template handoff

Các template từ discovery đến implementation và migration review chứa section `## Activation Slice`. Mỗi step giữ stable Slice ID và toàn bộ seam rows, chỉ bổ sung fields thuộc trách nhiệm step. Thiếu section, duplicate Slice ID, duplicate seam hoặc mất trace trong handoff làm artifact blocked.

## Validation strategy

Regression validation dùng fixture/mutation tests trên validator hiện có:

1. Provider/router/panel tồn tại nhưng parser thiếu activation key: discovery phải block.
2. Parser có field nhưng request không yêu cầu key: discovery phải block.
3. Async state với one-shot read và không reselection: technical design phải block.
4. Base và specialized router cùng map nhưng không có policy: gaps/design phải block.
5. Downstream deeplink/action không được trace: mapping/design phải block.
6. Deferred seam thiếu decision hoặc unit ID: plan phải block.
7. Đủ chín seam với evidence và lifecycle test: contract cho phép complete.
8. Handoff làm mất một seam hoặc đổi Slice ID: validator phải fail.

Các test được viết và quan sát fail trước khi sửa contract/template, sau đó mới thực hiện thay đổi tối thiểu để pass.

## Compatibility

Đây là contract mới cho artifact sinh sau remediation. Fixture và example artifact cũ không tự động được coi là hợp lệ cho run mới. Validator source-package vẫn có thể đọc tài liệu lịch sử, nhưng migration continuation từ artifact thiếu Activation Slice phải block và yêu cầu tạo attempt/run mới từ discovery phù hợp.

## Ngoài phạm vi

- Không định nghĩa execution-phase hoặc environment waiver mới.
- Không thay đổi human override hay immutable attempts.
- Không thêm snapshot mutation policy.
- Không giải quyết package resource locator ngoài việc referenced contract nằm trong source package và được validator kiểm tra tồn tại.

## Definition of Done

- Contract dùng chung tồn tại và không bị sao chép thành các định nghĩa mâu thuẫn.
- Mọi skill/template thuộc đường discovery-to-review có Activation Slice handoff phù hợp trách nhiệm.
- Regression tests chứng minh các failure scenario bị chặn và complete scenario được chấp nhận.
- Validator kiểm tra contract resource tồn tại và section/schema bắt buộc không bị drift.
- Bộ test liên quan pass và không sửa thay đổi người dùng đang có trong `aitoolkit/skills/aitoolkit/migrate/SKILL.md`.

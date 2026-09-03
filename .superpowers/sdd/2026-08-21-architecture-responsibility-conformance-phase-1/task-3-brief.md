### Task 3: Technical design responsibility và verification matrices

**Files:**
- Modify: `aitoolkit/skills/migration/technical-design/SKILL.md`
- Modify: `aitoolkit/templates/migration/technical-design.md`
- Modify: `aitoolkit/tests/validation/responsibility-conformance.validation.ps1`
- Modify: `aitoolkit/tests/validation/target-conformance.validation.ps1`
- Modify: `aitoolkit/tests/scenarios/target-conformance.Tests.ps1`
- Modify: `aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1`

**Interfaces:**
- Consumes: approved discovery classifications from Task 2.
- Produces: v1 `File Responsibility Matrix` và `Verification Ownership Matrix`; stable `RESP-*`/`VERIFY-OWNER-*` IDs cho plan-waves.

- [ ] **Step 1: Viết RED design fixtures A, C, D, E, G và cross-language**

Tạo concrete cases:

```powershell
Assert-DesignRejected 'aggregate capabilities require approval' $aggregateDesign 'co-location-approval-missing'
Assert-DesignAccepted 'feature-local symbols share one capability' $featureLocalDesign
Assert-DesignAccepted 'shared engine owns shared capability only' $sharedFoundationDesign
Assert-DesignRejected 'legacy debt cannot be propagated' $debtExemplarDesign 'debt-exemplar-propagation'
Assert-DesignAccepted 'approved atomic owner' $atomicDesign
```

Cross-language fixtures dùng ba owner cụ thể nhưng cùng contract:

```text
ui/admin_panel.dart#AdminPanel
backend/AdminCommandService.java#AdminCommandService
adapter/admin_pipeline.py#AdminPipeline
```

Thêm positive case một capability có `REQ-101, AC-202, WORK-ADMIN-LOCK` trong `Trace IDs` để chứng minh không bị coi multi-capability.

- [ ] **Step 2: Chạy RED focused scenarios**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-conformance.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\target-conformance.Tests.ps1
```

Expected: FAIL tại missing matrices/authority semantics.

- [ ] **Step 3: Thêm exact template sections và v1 front matter**

Trong technical-design template, thêm bounded front matter:

```yaml
responsibility_contract:
  version: 1
  applicability: required
```

Sau `Planned File Tree`, thêm đúng một `File Responsibility Matrix` và một `Verification Ownership Matrix` với exact columns từ canonical contract. `Owner Symbol` là primary public owner/module export; `Public Symbols` có thể chứa nhiều feature-local symbols; private helper không có row riêng.

- [ ] **Step 4: Implement design semantics**

`Test-ResponsibilityDesign` phải kiểm:

- exact bidirectional `(Planned Path, Planned Symbol)` coverage;
- unique `RESP-*` và `VERIFY-OWNER-*`;
- capability/trace tách biệt;
- `Atomic Boundary ID` chỉ dùng với `atomic-owner`;
- multi-capability owner cần exact approved deviation;
- shared-foundation không chứa concrete registration/effect;
- incremental authority và greenfield `approved-greenfield-design` đúng mode;
- controlled `not-applicable-approved` chỉ cho config/manifest/generated/schema/build wiring;
- behavior/routing/lifecycle/effects/destructive/composition không được miễn;
- mọi production responsibility có verification coverage hai chiều.

- [ ] **Step 5: Nối helper vào target conformance và giữ current eight-concern gates**

`Test-TargetConformance` gọi design helper sau khi current exemplar/matrix authority đã pass. Không xóa hoặc làm yếu planned-tree, boundary, activation và approved-deviation checks hiện có.

- [ ] **Step 6: Chạy GREEN và regression scenarios**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-conformance.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\target-conformance.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Contracts
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Templates
```

Expected: exit `0`; cross-language cases có cùng semantic verdict.

- [ ] **Step 7: Commit Task 3**

```powershell
git add -- aitoolkit/skills/migration/technical-design/SKILL.md aitoolkit/templates/migration/technical-design.md aitoolkit/tests/validation/responsibility-conformance.validation.ps1 aitoolkit/tests/validation/target-conformance.validation.ps1 aitoolkit/tests/scenarios/target-conformance.Tests.ps1 aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1
git commit -m "feat: require responsibility evidence in designs"
```

---


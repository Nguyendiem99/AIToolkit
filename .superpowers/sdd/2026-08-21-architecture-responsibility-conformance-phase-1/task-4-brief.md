### Task 4: Bind plan-waves work items với responsibility owners

**Files:**
- Modify: `aitoolkit/skills/migration/plan-waves/SKILL.md`
- Modify: `aitoolkit/templates/migration/migration-plan.md`
- Modify: `aitoolkit/tests/validation/responsibility-conformance.validation.ps1`
- Modify: `aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1`
- Modify: `aitoolkit/tests/validate-migration-framework.ps1`

**Interfaces:**
- Consumes: `RESP-*` set và approved design revision từ Task 3.
- Produces: exact `Responsibility Owner References` row cho mỗi work item/unit.

- [ ] **Step 1: Viết RED plan binding cases**

Thêm table fixture:

```markdown
## Responsibility Owner References

| Work Item ID | Design Revision | Responsibility IDs | Shared Foundation IDs | Integration Responsibility IDs | Independent Boundary Evidence |
|---|---|---|---|---|---|
| WORK-ADMIN-LOCK | DESIGN-ADMIN@2 | RESP-WIFI, RESP-WIRED | RESP-LOCK-GUARD | RESP-LOCK-COMPOSITION | architecture-rules.md#RULE-007 |
```

RED cases: missing `RESP-WIRED`, foreign responsibility từ work item khác, duplicate owner, stale design revision, shared foundation bị khai là concrete owner và unapproved cross-work-item reuse.

- [ ] **Step 2: Chạy RED responsibility scenarios**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-conformance.Tests.ps1
```

Expected: FAIL tại missing `Test-ResponsibilityPlan` semantics.

- [ ] **Step 3: Cập nhật plan template/skill và validation**

Plan-waves phải preserve exact ordered owner set, không định nghĩa lại matrix schema. `Test-ResponsibilityPlan` resolve IDs từ approved design, kiểm selected work item/decomposition và xác nhận unit vẫn independently implementable, reviewable, verifiable và revertible.

- [ ] **Step 4: Route plan responsibility evidence qua main validator**

Thêm template/skill contract tokens vào `validate-migration-framework.ps1`; mutation/removal của heading hoặc owner references phải làm `Templates`/`Skills` fail.

- [ ] **Step 5: Chạy GREEN**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-conformance.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Skills
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Templates
```

- [ ] **Step 6: Commit Task 4**

```powershell
git add -- aitoolkit/skills/migration/plan-waves/SKILL.md aitoolkit/templates/migration/migration-plan.md aitoolkit/tests/validation/responsibility-conformance.validation.ps1 aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1 aitoolkit/tests/validate-migration-framework.ps1
git commit -m "feat: bind migration plans to responsibility owners"
```

---


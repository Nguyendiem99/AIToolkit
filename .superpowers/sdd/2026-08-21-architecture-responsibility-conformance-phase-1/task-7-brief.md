### Task 7: Preserve responsibility provenance qua verification, parity, regression và KB

**Files:**
- Create: `aitoolkit/tests/scenarios/responsibility-handoff.Tests.ps1`
- Modify: `aitoolkit/skills/shared/verification-testing/SKILL.md`
- Modify: `aitoolkit/skills/migration/verify-parity/SKILL.md`
- Modify: `aitoolkit/skills/migration/verify-regression/SKILL.md`
- Modify: `aitoolkit/skills/shared/knowledge-base/SKILL.md`
- Modify: `aitoolkit/templates/migration/verification-report.md`
- Modify: `aitoolkit/templates/migration/parity-report.md`
- Modify: `aitoolkit/templates/migration/regression-report.md`
- Modify: `aitoolkit/templates/kb-entry.md`
- Modify: `aitoolkit/tests/validation/responsibility-conformance.validation.ps1`
- Modify: `aitoolkit/tests/validate-migration-framework.ps1`

**Interfaces:**
- Consumes: final AI review sub-verdicts/evidence từ Task 6.
- Produces: exact `Architecture Responsibility Handoff` table ở từng downstream artifact.

- [ ] **Step 1: Viết RED handoff loss/mutation scenarios**

Mỗi downstream artifact dùng table exact:

```markdown
## Architecture Responsibility Handoff

| Responsibility Contract Version | Tree Conformance | Responsibility Conformance | Verification Ownership | Architecture Conformance State | Evidence References |
|---|---|---|---|---|---|
| 1 | PASS | PASS | PASS | PASS | review-report.md#responsibility-evidence |
```

RED mutations: drop table ở parity, đổi Responsibility PASS thành BLOCKED nhưng giữ aggregate PASS, đổi evidence reference, dùng version 2, lấy table từ run khác và runtime waiver cố đổi state.

- [ ] **Step 2: Chạy RED handoff suite**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-handoff.Tests.ps1
```

Expected: FAIL vì templates/helper chưa preserve handoff.

- [ ] **Step 3: Cập nhật bốn skills và templates**

Mỗi stage phải copy exact sub-verdict/evidence từ immediate predecessor, validate version trước matrices và giữ derived aggregate. Stage không được reconstruct từ cumulative artifacts hoặc directory scan.

Knowledge Base chỉ được tính completed khi handoff PASS và evidence reference resolve immutable terminal artifact. Runtime waiver chỉ thay runtime state, không thay responsibility table.

- [ ] **Step 4: Implement handoff validator**

`Test-ResponsibilityHandoff` kiểm:

- đúng một table ở source/target;
- version/applicability hợp lệ;
- exact ordinal sub-verdict/evidence preservation;
- aggregate state đúng phép hội;
- same-run/current work-item provenance;
- BLOCKED không được chuyển thành PASS.

- [ ] **Step 5: Chạy GREEN handoff và template checks**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-handoff.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Skills
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Templates
```

- [ ] **Step 6: Commit Task 7**

```powershell
git add -- aitoolkit/skills/shared/verification-testing/SKILL.md aitoolkit/skills/migration/verify-parity/SKILL.md aitoolkit/skills/migration/verify-regression/SKILL.md aitoolkit/skills/shared/knowledge-base/SKILL.md aitoolkit/templates/migration/verification-report.md aitoolkit/templates/migration/parity-report.md aitoolkit/templates/migration/regression-report.md aitoolkit/templates/kb-entry.md aitoolkit/tests/validation/responsibility-conformance.validation.ps1 aitoolkit/tests/scenarios/responsibility-handoff.Tests.ps1 aitoolkit/tests/validate-migration-framework.ps1
git commit -m "feat: preserve responsibility verdict provenance"
```

---


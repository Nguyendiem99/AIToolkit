### Task 5: Code-migration pre-edit và planned-versus-actual responsibility gate

**Files:**
- Modify: `aitoolkit/skills/migration/code-migration/SKILL.md`
- Modify: `aitoolkit/templates/migration/implementation-report.md`
- Modify: `aitoolkit/tests/validation/responsibility-conformance.validation.ps1`
- Modify: `aitoolkit/tests/validation/structural-gate.validation.ps1`
- Modify: `aitoolkit/tests/scenarios/structural-gate.Tests.ps1`
- Modify: `aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1`

**Interfaces:**
- Consumes: approved design matrices và selected plan owner set.
- Produces: `Actual File Responsibility Matrix`, `Actual Verification Ownership Matrix` và derived sub-verdict evidence.

- [ ] **Step 1: Viết RED exact-tree false-positive và waiver cases**

Tạo fixture B: planned/actual path giống nhau nhưng actual có `WifiResetProvider` và `settings.write:wifi-reset` ngoài approved inventory. Assert:

```powershell
Assert-StructuralRejected 'tree match cannot hide extra ownership' $root 'responsibility-public-symbol-mismatch'
Assert-StructuralRejected 'runtime waiver cannot waive responsibility' $waivedRoot 'responsibility-waiver-forbidden'
```

Thêm cases: missing planned owner, extra owner, capability drift, external-effect drift, co-location rộng hơn plan, fake production binding và invalid `not-applicable-approved`.

- [ ] **Step 2: Chạy RED structural scenarios**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\structural-gate.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-conformance.Tests.ps1
```

Expected: new cases FAIL trong khi existing 130 structural cases vẫn là baseline cần giữ.

- [ ] **Step 3: Cập nhật implementation template và code-migration protocol**

Thêm v1 discriminator và exact sections:

```markdown
## Actual File Responsibility Matrix
## Actual Verification Ownership Matrix
## Architecture Responsibility Verdicts
```

Verdict table:

```text
Responsibility Contract Version | Tree Conformance | Responsibility Conformance | Verification Ownership | Architecture Conformance State | Evidence References
```

Code-migration pre-edit phải validate approved matrices trước RED/TDD/baseline/worktree mutation. Sau implementation, agent ghi actual public symbols/effects kèm source/diff evidence; self-attestation chưa phải final semantic PASS.

- [ ] **Step 4: Implement exact two-way comparison trong helper và structural gate**

`Test-ResponsibilityImplementation` so approved/actual theo `Responsibility ID` và authoritative `(path, Owner Symbol)`, rồi kiểm Public Symbols, Effects, Capability IDs, Trace IDs, architecture/co-location authority và verification rows. `Test-StructuralGate` gọi helper ngoài current tree/activation/boundary checks.

Derived state:

```powershell
$architecture = if (
  $tree -ceq 'PASS' -and
  $responsibility -ceq 'PASS' -and
  $verification -ceq 'PASS'
) { 'PASS' } else { 'BLOCKED' }
```

Caller-provided aggregate state khác derived state phải block.

- [ ] **Step 5: Chạy GREEN structural regressions**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\structural-gate.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-conformance.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Skills
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Templates
```

Expected: exit `0`; existing activation/selector/deviation checks vẫn PASS.

- [ ] **Step 6: Commit Task 5**

```powershell
git add -- aitoolkit/skills/migration/code-migration/SKILL.md aitoolkit/templates/migration/implementation-report.md aitoolkit/tests/validation/responsibility-conformance.validation.ps1 aitoolkit/tests/validation/structural-gate.validation.ps1 aitoolkit/tests/scenarios/structural-gate.Tests.ps1 aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1
git commit -m "feat: gate migration edits on responsibility"
```

---


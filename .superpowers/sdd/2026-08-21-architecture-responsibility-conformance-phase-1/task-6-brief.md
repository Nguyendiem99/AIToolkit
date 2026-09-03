### Task 6: Architecture-first AI review xác minh inventory độc lập

**Files:**
- Modify: `aitoolkit/skills/shared/ai-review/SKILL.md`
- Modify: `aitoolkit/templates/migration/review-report.md`
- Modify: `aitoolkit/tests/validation/responsibility-conformance.validation.ps1`
- Modify: `aitoolkit/tests/validation/architecture-review.validation.ps1`
- Modify: `aitoolkit/tests/scenarios/architecture-review.Tests.ps1`
- Modify: `aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1`

**Interfaces:**
- Consumes: implementation actual inventory và final task-base/final-tree diff.
- Produces: final semantic Tree, Responsibility và Verification Ownership verdicts cùng immutable evidence references.

- [ ] **Step 1: Viết RED self-attestation bypass case**

Fixture cho implementation tự khai PASS nhưng final source evidence có extra route/provider. Review phải reject:

```powershell
Assert-FailsLike 'review independently rejects omitted actual owner' {
  param($root)
  Add-SourceSymbolEvidence $root 'AdminRoute.factoryReset' 'RESP-UNPLANNED'
  Keep-ImplementationSelfAttestationPass $root
} 'responsibility-owner-extra|responsibility-public-symbol-mismatch'
```

Thêm RED cases cho thiếu từng sub-verdict, thiếu evidence reference, fake production composition và Responsibility PASS khi Verification BLOCKED.

- [ ] **Step 2: Chạy RED architecture review**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\architecture-review.Tests.ps1
```

Expected: new bypass case chưa bị reject.

- [ ] **Step 3: Cập nhật review skill/template**

Review order exact:

```text
master/work-item -> rules -> selector -> tree -> responsibility -> verification ownership -> activation -> behavior/security/performance -> hygiene
```

Template thêm `Responsibility Review Evidence`:

```text
Responsibility ID | Source/Diff Evidence | Planned Public Symbols | Actual Public Symbols | Planned Effects | Actual Effects | Verdict
```

Và thêm ba exact verdict lines. Reviewer phải inspect source/diff độc lập, không copy implementation PASS.

- [ ] **Step 4: Implement review validator**

`Test-ResponsibilityReview` kiểm exact row coverage, actual inventory evidence, verdict derivation và evidence provenance. `Test-ArchitectureReview` gọi helper trước behavior analysis; bất kỳ sub-verdict BLOCKED nào làm overall Reject, bất kể severity count.

- [ ] **Step 5: Chạy GREEN architecture scenarios**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\architecture-review.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-conformance.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Skills
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Templates
```

- [ ] **Step 6: Commit Task 6**

```powershell
git add -- aitoolkit/skills/shared/ai-review/SKILL.md aitoolkit/templates/migration/review-report.md aitoolkit/tests/validation/responsibility-conformance.validation.ps1 aitoolkit/tests/validation/architecture-review.validation.ps1 aitoolkit/tests/scenarios/architecture-review.Tests.ps1 aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1
git commit -m "feat: review migration responsibility independently"
```

---


### Task 2: Discovery exemplar classification có authority

**Files:**
- Modify: `aitoolkit/skills/migration/discovery/SKILL.md`
- Modify: `aitoolkit/templates/migration/discovery.md`
- Modify: `aitoolkit/tests/validation/responsibility-conformance.validation.ps1`
- Modify: `aitoolkit/tests/validation/target-conformance.validation.ps1`
- Modify: `aitoolkit/tests/scenarios/target-conformance.Tests.ps1`
- Modify: `aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1`

**Interfaces:**
- Consumes: `Test-ResponsibilityDiscovery` và canonical exemplar enums từ Task 1.
- Produces: exact discovery rows với `Classification Authority` và `Classification Evidence` được technical design dùng ở Task 3.

- [ ] **Step 1: Thêm RED cases cho unauthorized classification**

Thêm fixtures:

```powershell
Assert-Rejected 'agent cannot self-declare legacy debt' {
  param($root)
  Set-DiscoveryClassification $root 'legacy-debt' 'agent-opinion' 'looks aggregate'
} 'exemplar-classification-authority-missing'

Assert-Accepted 'project pack may classify compatibility-only' {
  param($root)
  Set-DiscoveryClassification $root 'compatibility-only' 'project-pack-rule' 'architecture-rules.md#RULE-007'
}
```

Thêm RED cho `preferred` chỉ có một generic file, `no-equivalent` thiếu factual search evidence, duplicate classification row và missing version.

- [ ] **Step 2: Chạy RED target/discovery scenarios**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-conformance.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\target-conformance.Tests.ps1
```

Expected: các case mới FAIL vì template/helper chưa có classification authority.

- [ ] **Step 3: Cập nhật discovery template và skill**

`Comparable Target Exemplars` thêm đúng các cột:

```text
Concern | Path | Inspected Symbols | Observed Pattern | Primary Responsibility | Owned Capabilities | Verification Owner | Comparable Reason | Evidence | Inspection Status | Classification | Classification Authority | Classification Evidence
```

Skill phải yêu cầu:

- `preferred`: repeated working evidence, không có authoritative conflict;
- `compatibility-only`: project-pack rule hoặc approved owner decision;
- `legacy-debt`: project documentation, debt record hoặc Tech Lead-approved conflict;
- `no-equivalent`: factual search/inspection evidence;
- agent opinion không phải classification authority.

- [ ] **Step 4: Hoàn thiện discovery validation và target-conformance integration**

`Test-ResponsibilityDiscovery` kiểm exact cardinality tám concerns với incremental, authority/evidence pairs, version và mode rules. `Test-TargetConformance` gọi helper bằng discovery text đang được validate, không tự copy classification enums.

- [ ] **Step 5: Chạy GREEN scenarios và selectors**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-conformance.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\target-conformance.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Skills
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Templates
```

Expected: tất cả exit `0`; debt classification không authority vẫn rejected.

- [ ] **Step 6: Commit Task 2**

```powershell
git add -- aitoolkit/skills/migration/discovery/SKILL.md aitoolkit/templates/migration/discovery.md aitoolkit/tests/validation/responsibility-conformance.validation.ps1 aitoolkit/tests/validation/target-conformance.validation.ps1 aitoolkit/tests/scenarios/target-conformance.Tests.ps1 aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1
git commit -m "feat: classify migration exemplars by authority"
```

---


### Task 8: Orchestrator, terminal formula, rollout và safe post-implementation stop

**Files:**
- Modify: `aitoolkit/skills/aitoolkit/migrate/SKILL.md`
- Modify: `aitoolkit/templates/migration/scope-terminal-report.md`
- Modify: `aitoolkit/tests/validation/scope-engine.validation.ps1`
- Modify: `aitoolkit/tests/validation/architecture-review.validation.ps1`
- Modify: `aitoolkit/tests/scenarios/scope-engine.Tests.ps1`
- Modify: `aitoolkit/tests/scenarios/flexible-scope-e2e.Tests.ps1`
- Modify: `aitoolkit/tests/scenarios/responsibility-handoff.Tests.ps1`
- Modify: `aitoolkit/tests/validate-migration-framework.ps1`

**Interfaces:**
- Consumes: terminal evidence chain có v1 handoff từ Task 7.
- Produces: fail-closed queue/terminal behavior và compatibility rollout semantics.

- [ ] **Step 1: Viết RED terminal provenance và safe-stop cases**

Thêm E2E case concrete:

```text
actual responsibility mismatch
-> implementation draft/blocked
-> review Reject
-> work item blocked
-> dependent item remains non-eligible
-> delivery and scope completion blocked
-> approved design/master-plan revision required
```

Thêm cases: aggregate PASS với Responsibility BLOCKED, missing evidence link, mixed v1/v2, historical-only artifact dùng làm executable authority, in-progress pre-v1 resume và auto-waive override.

- [ ] **Step 2: Chạy RED scope/E2E**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\scope-engine.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\flexible-scope-e2e.Tests.ps1
```

Expected: new provenance/stop cases FAIL; existing exactly-21 fixture count phải được cập nhật bằng subcases, không tăng top-level E2E count nếu suite giữ invariant 21.

- [ ] **Step 3: Cập nhật migrate orchestrator và terminal template**

Orchestrator phải:

- derive `architecture_conformance_state` từ ba sub-verdict;
- stop queue trước parity/regression/delivery/KB khi một sub-verdict BLOCKED;
- không chọn dependent work;
- require approved design/master-plan revision để resume;
- coi completed pre-v1 là `historical-only`;
- block in-progress pre-v1 và mixed-version evidence;
- không tự tạo Phase 2 remediation artifact/work item.

Terminal template thêm exact `Architecture Responsibility Handoff` và Evidence Index references; scope-complete formula phải resolve immutable sub-verdict evidence.

- [ ] **Step 4: Implement terminal/scope validation**

Trong scope engine/FlexibleScope path, kiểm phép hội:

```powershell
$architecturePass =
  $tree -ceq 'PASS' -and
  $responsibility -ceq 'PASS' -and
  $verification -ceq 'PASS' -and
  $architectureState -ceq 'PASS'
```

Nếu false, diagnostic phải là `structural-assurance-blocked` hoặc responsibility diagnostic cụ thể, state `scope-blocked`, next eligible item `none`, terminal verdict không phải `scope-complete`.

- [ ] **Step 5: Chạy GREEN scope, E2E và handoff suites**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\scope-engine.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-handoff.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\flexible-scope-e2e.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check All
```

Expected: tất cả exit `0`; E2E vẫn báo exact expected scenario count.

- [ ] **Step 6: Commit Task 8**

```powershell
git add -- aitoolkit/skills/aitoolkit/migrate/SKILL.md aitoolkit/templates/migration/scope-terminal-report.md aitoolkit/tests/validation/scope-engine.validation.ps1 aitoolkit/tests/validation/architecture-review.validation.ps1 aitoolkit/tests/scenarios/scope-engine.Tests.ps1 aitoolkit/tests/scenarios/flexible-scope-e2e.Tests.ps1 aitoolkit/tests/scenarios/responsibility-handoff.Tests.ps1 aitoolkit/tests/validate-migration-framework.ps1
git commit -m "feat: block terminal scope on responsibility defects"
```

---


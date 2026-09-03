### Task 9: Mutation coverage, toàn bộ regression gates và final evidence

**Files:**
- Modify: `aitoolkit/tests/validate-migration-framework.Tests.ps1`
- Modify: `aitoolkit/tests/validate-migration-framework.ps1`
- Modify only if a proven mutation failure requires it: responsibility-related files from Tasks 1–8

**Interfaces:**
- Consumes: final Phase 1 behavior từ Tasks 1–8.
- Produces: mutation evidence cho fixtures A–G/I, downstream preservation, safe stop và exact final-tree PASS.

- [ ] **Step 1: Viết RED mutation cases với alter-or-fail guard**

Mỗi mutation dùng helper tương đương:

```powershell
function Replace-ExactOrFail([string]$Text, [string]$From, [string]$To, [string]$Name) {
  $changed = $Text.Replace($From, $To)
  if ($changed -ceq $Text) { throw "$Name mutation was a silent no-op" }
  return $changed
}
```

Bao phủ tối thiểu:

- contract version missing/mixed;
- capability/trace conflation;
- classification authority loss;
- greenfield converted to fake deviation;
- multi-capability approval removal;
- extra public symbol/effect while tree matches;
- invalid verification not-applicable;
- fake production composition;
- implementation self-attestation bypass;
- sub-verdict loss/mutation downstream;
- runtime waiver override;
- post-implementation queue advance.

- [ ] **Step 2: Chạy focused RED mutation cluster**

Nếu suite chưa có selector riêng, thêm `-ResponsibilityConformanceOnly` vào `validate-migration-framework.Tests.ps1` và bảo đảm default invocation vẫn chạy toàn bộ suite.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.Tests.ps1 -ResponsibilityConformanceOnly
```

Expected: FAIL trước khi registration/mutations hoàn chỉnh; không có silent no-op.

- [ ] **Step 3: Hoàn thiện mutation routing và source-integrity registration**

Main validator phải nhận new contract/helper/scenarios trong Contracts, Skills, Templates, Docs và SourceIntegrity paths phù hợp. Mutation suite phải chạy fixture copy riêng, dùng LF/CRLF-independent replacement và xác nhận source digest không đổi sau mỗi isolated mutation.

- [ ] **Step 4: Chạy toàn bộ focused gates trước full suite**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-conformance.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-handoff.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\target-conformance.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\structural-gate.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\architecture-review.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\scope-engine.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\flexible-scope-e2e.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Contracts
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Skills
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Templates
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check All
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check SourceIntegrityOnly
git diff --check
```

Expected: mọi command exit `0`. Không chạy full mutation suite nếu bất kỳ focused gate nào fail.

- [ ] **Step 5: Commit final mutation coverage trước long gate**

```powershell
git add -- aitoolkit/tests/validate-migration-framework.Tests.ps1 aitoolkit/tests/validate-migration-framework.ps1 aitoolkit/contracts aitoolkit/skills aitoolkit/templates aitoolkit/tests/validation aitoolkit/tests/scenarios
git status --short
git commit -m "test: cover responsibility conformance workflow"
```

Trước commit, xác nhận `git status --short` không stage `issue/` hoặc file ngoài Phase 1.

- [ ] **Step 6: Chạy full mutation suite đúng một lần trên exact final HEAD**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.Tests.ps1
```

Expected: exit `0`, output `PASS: focused migration framework tests`. Không sửa source trong lúc suite chạy. Nếu FAIL, dừng, giữ exact diagnostics và không claim completion; chỉ chạy lại sau khi có fix mới và authorization rõ ràng cho long gate khác.

- [ ] **Step 7: Chạy fresh short gates sau full PASS**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check All
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check SourceIntegrityOnly
git diff --check HEAD^ HEAD
git status --short
git log -1 --oneline
```

Expected: All/SourceIntegrity PASS, diff check exit `0`; status chỉ còn known untracked `issue/`; HEAD không đổi sau full suite.

- [ ] **Step 8: Ghi final completion status đúng phạm vi**

Handoff phải ghi:

```text
Core false-positive: fixed
Prevention gates: complete
Safe post-implementation stop: complete
Automated remediation: pending Phase 2
Original issue: partially resolved
```

Không tuyên bố original issue closed và không tự bắt đầu Phase 2.

# Task 9 Report — Mutation coverage and final short-gate evidence

Date: 2026-08-21  
Task base: `0cbb95afb835263ecf3b52b36f5ec0605f903435`  
Final HEAD after fix round 1: `bf9aceabbb7be111639bb5e7f4d236319a53f9fb`

## Files changed

- `aitoolkit/tests/validate-migration-framework.Tests.ps1`
  - Added and isolated `-ResponsibilityConformanceOnly` routing while leaving the default invocation unchanged.
  - Added LF/CRLF-independent `Replace-ExactOrFail` behavior and an explicit LF/CRLF probe.
  - Added 15 isolated behavioral mutations covering every minimum case in the Task 9 brief.
  - Runs `SourceIntegrityOnly` in every mutation fixture and compares the source checkout digest before and after every isolated mutation.
- `aitoolkit/tests/validate-migration-framework.ps1`
  - Registered `SourceIntegrityOnly` in the validator interface.
  - Added responsibility source-integrity checks for the canonical contract, helper, scenario registrations, skills, templates, orchestrator safe stop, design, and plan.
  - Registered the responsibility source-integrity check in both `SourceIntegrityOnly` and `All`.
- `aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1`
  - Added explicit capability-versus-trace coverage.
  - Added positive greenfield authority coverage and the negative fake-deviation case required by the mutation cluster.

No `issue/`, Phase 2, or unrelated file was changed or staged.

## Strict RED evidence

The focused tests and selector pass-through were written before the production validator routing/registration change.

Command used for each RED run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.Tests.ps1 -ResponsibilityConformanceOnly
```

1. Exit `1`. The child PowerShell process initially surfaced the invalid selector as `NativeCommandError`; the relevant validator diagnostic was:

   ```text
   Cannot validate argument on parameter 'Check'. The argument "SourceIntegrityOnly" does not belong to the set "Encoding,Contracts,Templates,Skills,Orchestrators,Onboarding,Compatibility,Docs,FlexibleScope,All"...
   ```

   Reason: the new test requested the source-integrity route before the production validator registered it. The test harness was adjusted to capture the native failure as assertion evidence.

2. Exit `1`. The same invalid-selector `NativeCommandError` also escaped from a nested mutation after the failed baseline. Reason: the test-only RED harness had not yet stopped after baseline failure. The harness was corrected to report the intended single baseline failure; no production/routing change was made.

3. Exit `1`, exact focused assertion evidence:

   ```text
   FAIL: Responsibility source-integrity baseline should pass. Output: ... Cannot validate argument on parameter 'Check'. The argument "SourceIntegrityOnly" does not belong to the set "Encoding,Contracts,Templates,Skills,Orchestrators,Onboarding,Compatibility,Docs,FlexibleScope,All"...
   FAIL: Responsibility source-integrity baseline missing <PASS: migration framework (SourceIntegrityOnly)>.
   ```

   Reason: confirmed production cause was the missing `SourceIntegrityOnly` registration. Only after this focused RED was captured was the main validator changed.

No RED mutation reported `silent no-op`.

## GREEN and focused mutation evidence

Final command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.Tests.ps1 -ResponsibilityConformanceOnly
```

Exit `0`. Output contained one PASS for each of these 15 isolated behavioral mutations:

1. contract version missing
2. contract version mixed
3. capability and trace separation
4. classification authority loss
5. greenfield fake deviation
6. multi-capability approval removal
7. extra public symbol while tree matches
8. extra effect while tree matches
9. invalid verification not-applicable
10. fake production composition
11. implementation self-attestation bypass
12. downstream sub-verdict loss
13. downstream sub-verdict mutation
14. runtime waiver override
15. post-implementation queue advance

Terminal line:

```text
PASS: responsibility conformance mutation scenarios
```

During self-review, an earlier semantic run exited `1` only because the stable expected substring for the last mutation included a trailing period that the scenario assertion text does not contain. The mutant itself was killed and emitted all queue-stop failures. The matcher was narrowed to the stable text, without changing production behavior, and the final run above passed.

## Source digest integrity

Every final mutation line reported this same digest before and after its isolated fixture run:

```text
0CF2BDB09E6DC3A9E622ACFE3A4583DE02DE08DFEF221B1C24BECFDE1E3379A1
```

All 15 fixture mutations passed their per-case `SourceIntegrityOnly` check, exited the mutated behavioral scenario with code `1`, matched the expected rejection, contained no `silent no-op`, and left the shared source checkout digest unchanged. Mutation targets include LF files and CRLF/mixed files; the alter-or-fail helper also has explicit LF and CRLF probes.

## Step 4 short gates

All commands below were run before the commit and exited `0`:

| Command | Output summary |
|---|---|
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-conformance.Tests.ps1` | `PASS: responsibility conformance contract` |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-handoff.Tests.ps1` | `PASS: responsibility handoff scenarios` |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\target-conformance.Tests.ps1` | `PASS: target conformance scenarios` |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\structural-gate.Tests.ps1` | `PASS: structural gate (144 scenarios)` |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\architecture-review.Tests.ps1` | `PASS: architecture review scenarios` |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\scope-engine.Tests.ps1` | `PASS: scope engine behavioral scenarios` |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\flexible-scope-e2e.Tests.ps1` | `PASS: flexible migration scope orchestration (21 isolated E2E scenarios)` |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Contracts` | `PASS: migration framework (Contracts)` |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Skills` | `PASS: migration framework (Skills)` |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Templates` | `PASS: migration framework (Templates)` |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check All` | `PASS: migration framework (All)` |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check SourceIntegrityOnly` | `PASS: migration framework (SourceIntegrityOnly)` |
| `git diff --check` | Exit `0`; only the informational Git LF-to-CRLF working-copy warning was printed. |

After the test-only matcher correction, the focused selector, `All`, `SourceIntegrityOnly`, and `git diff --check` were refreshed successfully. After commit, exact-HEAD `All` and `SourceIntegrityOnly` were run again and both exited `0` with the same PASS lines. `git diff --check HEAD^ HEAD` also exited `0`.

The default/full `validate-migration-framework.Tests.ps1` suite was deliberately not run. The controller explicitly reserved that long suite for one run after review.

## Staged scope, commit, and final status

Pre-commit staged names were exactly:

```text
AIToolkit/AIToolkit-main/aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1
AIToolkit/AIToolkit-main/aitoolkit/tests/validate-migration-framework.Tests.ps1
AIToolkit/AIToolkit-main/aitoolkit/tests/validate-migration-framework.ps1
```

`git diff --cached --check` exited `0`. The staged diff was `3 files changed, 205 insertions(+), 3 deletions(-)`. No `issue/` or file outside Task 9/Phase 1 was staged.

The original pre-review commit was:

```text
96fe11c398d867c8d2b6a4d7f06064bb4b155569 test: cover responsibility conformance workflow
```

It was subsequently replaced in place by the fix-round amend recorded below; it is not an additional commit.

Final `git status --short` output was empty. Final `git rev-list --count 0cbb95afb835263ecf3b52b36f5ec0605f903435..HEAD` output was `1`.

## Self-review

- Verified all 15 minimum mutation categories from the brief are represented by independent case records.
- Verified mutations alter scenario or validation behavior in an isolated copy rather than merely deleting assertion labels.
- Verified each replacement uses the alter-or-fail guard and each mutant must be behaviorally killed.
- Verified source-integrity registration covers the canonical contract/helper/scenarios and Phase 1 skill/template/orchestrator/document routes; external design/plan paths are required when present in the real checkout and intentionally optional only in reduced isolated toolkit fixtures.
- Verified the new selector is passed to the isolated child while default suite routing remains unchanged.
- Verified no source edit occurred while a test process was running.
- Verified commit scope and exact message before and after commit.

## Completion scope and concerns

```text
Core false-positive: fixed
Prevention gates: complete
Safe post-implementation stop: complete
Automated remediation: pending Phase 2
Original issue: partially resolved
```

Concern: the controller-owned long/default mutation suite is intentionally pending and must be run exactly once after review. Task 9 did not start Phase 2 and does not claim the original issue is closed.

## Fix round 1/5 — scoped review corrections

Review round: 2026-08-21  
Amended commit: `bf9aceabbb7be111639bb5e7f4d236319a53f9fb` (`test: cover responsibility conformance workflow`)

### Findings and corrections

1. **Required design/plan documents now fail closed.** The prior `ExternalToFixture` marker skipped a missing document in every checkout. The validator now accepts `-AllowReducedResponsibilityFixture` only when `Root` is the `aitoolkit` directory inside the helper's specifically named temporary fixture container. Normal validation always requires both documents. The focused test creates both document registrations, verifies normal PASS, deletes only the design and verifies design-only FAIL, restores it, deletes only the plan and verifies plan-only FAIL, then verifies the explicit reduced temp fixture mode. A separate normal-checkout negative wrapper proves that passing the reduced flag outside the controlled temp fixture is rejected.

2. **Mixed line endings are byte-preserving outside the mutation span.** `Replace-ExactOrFail` now builds normalized-index-to-original-index boundaries, locates the normalized match, and splices only each matched original span. It never normalizes the full file. The mixed probe compares UTF-8 byte encodings of the entire expected and actual strings, including untouched CRLF and LF separators. A same-byte replacement is also rejected as a silent no-op.

3. **Mutation kills require specific diagnostics.** Cases now declare `ExpectedDiagnostics` allow-lists. Capability/trace requires `responsibility-capability-mismatch`; fake production composition requires `verification-production-binding-missing`; implementation self-attestation requires one of the explicit owner/public-symbol diagnostics `responsibility-owner-extra` or `responsibility-public-symbol-mismatch`. Other cases likewise use stable diagnostics rather than generic positive-scenario prefixes. The post-implementation queue case retains a specific behavioral assertion string because it is a queue outcome rather than a conformance diagnostic.

4. **Failed cases no longer print PASS.** `Format-MutationCaseOutcome` emits the PASS line only when the case added zero failures. Otherwise it emits each new failure immediately. A focused output probe asserts that a synthetic failed case contains `FAIL: probe diagnostic mismatch` and contains no mutation PASS line.

5. **TDD chronology for the responsibility scenario additions is recorded truthfully.** In the original Task 9 round, the only pre-production RED was the missing `SourceIntegrityOnly` route. No valid pre-change RED was observed specifically for the additions at the original responsibility scenario lines 395–433; those tests were added while completing the initial mutation set, so the earlier report did not establish their individual TDD provenance. No retroactive RED is claimed. In this fix round, tests/mutations were changed before the new harness/validator implementation:
   - The trace/conflation production mutation changes the design validator to count `Trace IDs` as owned capabilities. The focused RED emitted `multiple trace IDs for one capability do not create multi-capability ownership should pass but got: responsibility-capability-mismatch; co-location-approval-missing`, proving that the explicit trace test kills that intended production regression.
   - The greenfield production mutations independently require the wrong authority and allow a structural-deviation authority. They were each killed by the positive `approved greenfield design authority does not require a deviation` test or the negative `greenfield cannot be converted to fake deviation` test, respectively, with `greenfield-authority-invalid` required by the mutation matcher.

### Fix-round RED evidence

Focused command for the review RED:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.Tests.ps1 -ResponsibilityConformanceOnly
```

Exit `1`. Key exact output:

```text
FAIL: Mixed-ending alter-or-fail helper must preserve every byte outside the replaced span
FAIL: Normal source-integrity validation must fail when required design and plan documents are absent. Output: PASS: migration framework (SourceIntegrityOnly)
FAIL: Missing required design document missing <Responsibility source-integrity registration file missing: design document>. Output: PASS: migration framework (SourceIntegrityOnly)
FAIL: Missing required implementation plan missing <Responsibility source-integrity registration file missing: implementation plan>. Output: PASS: migration framework (SourceIntegrityOnly)
multiple trace IDs for one capability do not create multi-capability ownership should pass but got: responsibility-capability-mismatch; co-location-approval-missing
```

The same RED output also demonstrated the misleading-output defect: mutation lines were printed as `PASS` even for cases whose stricter diagnostic assertions were listed later as `FAIL`. It also showed that a literal pipe-separated owner/public-symbol string was not treated as an allowed-diagnostic set.

After the span-preserving implementation was first green, a separate self-review test was added before its guard fix:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.Tests.ps1 -ResponsibilityConformanceOnly
```

Exit `1`, exact output:

```text
FAIL: Alter-or-fail helper must reject a replacement that leaves identical bytes
```

The helper then received the minimal final byte-equality guard.

### Fix-round GREEN and affected gates

| Command | Exit/output |
|---|---|
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.Tests.ps1 -ResponsibilityConformanceOnly` | Exit `0`; 17/17 isolated behavioral mutations; `PASS: responsibility conformance mutation scenarios`; every case reported digest `70A6B5BD247220AA802992751FDA6FFC1A07D81E976D88DEEC6142C824257F97`. |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-conformance.Tests.ps1` | Exit `0`; `PASS: responsibility conformance contract`. |
| Normal-checkout negative wrapper around `validate-migration-framework.ps1 -Check SourceIntegrityOnly -Root .\aitoolkit -AllowReducedResponsibilityFixture` | Inner validator exit `1` with `Reduced responsibility fixture flag is only valid for an isolated AIToolkit test fixture`; wrapper exit `0`, `PASS: normal checkout cannot opt into reduced responsibility fixture mode`. |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check All` | Exit `0`; `PASS: migration framework (All)`. |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check SourceIntegrityOnly` | Exit `0`; `PASS: migration framework (SourceIntegrityOnly)`. |
| PowerShell AST parse for all three changed scripts | Exit `0`; all three `PARSE PASS`. |
| `git diff --check` | Exit `0`; only the existing informational LF-to-CRLF working-copy warning. |

The focused selector's document fixture also produced these behavior results inside its successful run: complete normal fixture exit `0`; design-only deletion exit `1` with only the design diagnostic; plan-only deletion exit `1` with only the plan diagnostic; explicitly reduced controlled fixture exit `0`.

### Fix-round scope and self-review

- Changed only the same three Task 9 files from the original commit.
- Verified the replacement helper changes all normalized matches while preserving every byte outside matched original spans and retains both not-found and same-byte silent no-op guards.
- Verified the reduced-fixture opt-in cannot be used against the real/normal checkout.
- Verified all mutation expected diagnostics are explicit; the only multi-diagnostic allowance is the documented owner/public-symbol pair.
- Verified failed-case output is generated from only the failures added by that case.
- No source edit occurred while a test process was running.
- The default/full mutation suite was not run; it remains reserved for the controller's single post-review run.
- Phase 2 remains out of scope; the original issue remains partially resolved.

After amend, the focused selector was run again on exact HEAD `bf9aceabbb7be111639bb5e7f4d236319a53f9fb` and exited `0` with the same 17/17 PASS lines and digest `70A6B5BD247220AA802992751FDA6FFC1A07D81E976D88DEEC6142C824257F97`. Exact-HEAD `All` and `SourceIntegrityOnly` were also rerun and exited `0` with their expected PASS lines.

## Final whole-branch review fix wave

Review wave: 2026-08-21  
Commit policy: amend the single Task 9 commit, message unchanged as `test: cover responsibility conformance workflow`.  
Amended SHA: `894b20ab882eb16a6c7dd4ab09120aa7c566096c`.

### Files changed in this wave

- `aitoolkit/contracts/file-responsibility-conformance.md`
- `aitoolkit/skills/shared/verification-testing/SKILL.md`
- `aitoolkit/skills/migration/verify-parity/SKILL.md`
- `aitoolkit/skills/migration/verify-regression/SKILL.md`
- `aitoolkit/templates/migration/verification-report.md`
- `aitoolkit/templates/migration/parity-report.md`
- `aitoolkit/templates/migration/regression-report.md`
- `aitoolkit/tests/validation/responsibility-conformance.validation.ps1`
- `aitoolkit/tests/validation/structural-gate.validation.ps1`
- `aitoolkit/tests/validation/target-conformance.validation.ps1`
- `aitoolkit/tests/scenarios/responsibility-handoff.Tests.ps1`
- `aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1`
- `aitoolkit/tests/scenarios/structural-gate.Tests.ps1`
- `aitoolkit/tests/scenarios/target-conformance.Tests.ps1`
- `aitoolkit/tests/scenarios/architecture-review.Tests.ps1`
- `aitoolkit/tests/scenarios/flexible-scope-e2e.Tests.ps1`
- `aitoolkit/tests/validate-migration-framework.Tests.ps1`

### Per-finding RED and GREEN evidence

1. **Critical — exact step-11 review producer envelope.** Tests were added first for draft/blocked reviews, absent or non-human approval, conflicting lifecycle fields, seven-character SHAs, legacy filename evidence, cross-run scope, adapter/selected-unit mismatch, and generic adapter review-to-KB flow. Initial command:

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-handoff.Tests.ps1
   ```

   RED output stopped at: `draft review cannot seed verification expected responsibility-evidence-missing but got:`. A later self-review RED stopped at: `conflicting review lifecycle fields cannot seed verification expected responsibility-evidence-missing but got:`. GREEN exit `0` includes PASS for every negative above and all generic/migration-unit chains. The validator now requires bounded exact review top-level fields, approved/complete/human, canonical run/spec/plan/work identity, exact lowercase 40-character SHAs, exact immediate predecessor, exact `source-diff:<base>..<final>#<WORK-*>`, identical downstream master context and adapter kind, and adapter-conditional selected-unit cardinality.

2. **Important 1 — approved mode propagation.** Structural tests first created a fully aligned greenfield authority fixture and a mode/authority mismatch. RED was: `structural gate passes the approved greenfield mode to responsibility validators expected PASS, got: exemplar-classification-authority-missing`. The target test then added a source seam assertion and failed with `Target conformance must not hard-code incremental responsibility discovery mode`. GREEN: structural gate exit `0`, `PASS: structural gate (146 scenarios)`; target exit `0`, including `target conformance accepts greenfield responsibility authority under approved design mode` and rejection with `greenfield-authority-invalid`. Structural validation now derives mode from the exact external selector; target discovery and design share the single mode resolved from design authority.

3. **Important 2 — selected review owners and unchanged final-tree paths.** Tests first added a design containing another work item's responsibility/verification plus an unchanged-selected-owner git fixture. RED for the first case was: `review scopes planned owners and verification to the selected work item should pass but got: responsibility-owner-extra; responsibility-owner-missing; verification-owner-missing; responsibility-waiver-forbidden`. GREEN exit `0` includes `review scopes planned owners and verification to the selected work item` and `review loads selected owners from the final tree even when their paths are unchanged`. Review now resolves the exact owner-reference set before filtering planned owners/verifications; source inventory unions all changed/deleted paths with selected final-tree paths and requires added-diff anchors only for paths that actually changed. Changed/deleted unplanned owners remain independently inspected and rejected.

4. **Important 3 — adapter-aware downstream reports.** Static producer contract assertions and rendered behavior were written first. RED was: `skills/shared/verification-testing/SKILL.md missing adapter-aware downstream rule: Delivery Adapter Kind`. GREEN handoff output proves a generic task adapter reaches verification, parity, and terminal KB with no selected-unit section, while migration-unit omission and generic invention are rejected. Verification/parity/regression skills and templates now preserve `Master Scope Context` and `Delivery Adapter Kind`, conditionally preserve `Selected Migration Unit` only for `migration-unit`, and omit it otherwise.

5. **Important 4 — approved decomposition reuse.** An approved parent/child plan with the same exact decision, master revision, design revision, and responsibility traces was added before validator changes. RED was: `approved parent-child decomposition may reuse an exactly traced responsibility should pass but got: responsibility-owner-extra`. GREEN includes `approved parent-child decomposition may reuse an exactly traced responsibility`; the pre-existing unapproved cross-work-item reuse rejection also remains PASS. Reuse is allowed only when the plan itself is approved and the exact adapter rows form a direct parent/child relation under the same canonical `DEC-*`, master, and design tuple.

6. **Important 5 — canonical verification ID family.** The contract test was changed to `VERIFY-OWNER-###` first and failed with `Verification owner family drift fixture replacement failed`. GREEN changes the canonical examples and all scenario/source markers to `VERIFY-OWNER-*`, removes `(VER|VERIFY-OWNER)` parsing, and adds `ARC-CONTRACT-VERIFICATION-ID-FAMILY`. The mutation uses `VER-###` only as the deliberately rejected mutant. Self-review further narrowed the placeholder regex so `#` is legal only in the literal schema placeholder, never in a concrete ID.

### Flexible-scope regression RCA and correction

The first complete Step-4 flexible gate ended with exit `1` and exact failures:

```text
FAIL: S05 expected validator success but exited 1: DIAGNOSTIC: terminal-scope-report-invalid
SCOPE_STATE: scope-blocked
FAIL: S20 expected validator success but exited 1: DIAGNOSTIC: terminal-scope-report-invalid
SCOPE_STATE: scope-blocked
FAIL: S20-greenfield-four-stage-chain expected validator success but exited 1: DIAGNOSTIC: terminal-scope-report-invalid
SCOPE_STATE: scope-blocked
FAIL: S20-valid-waiver expected validator success but exited 1: DIAGNOSTIC: terminal-scope-report-invalid
SCOPE_STATE: scope-blocked
```

Trace evidence: `validate-migration-framework.ps1` line 1744 calls `Test-ResponsibilityHandoff` on every adjacent responsibility-chain artifact. The E2E review/downstream fixture producers carried run/master/provenance tables but did not render `Delivery Adapter Kind`; downstream artifacts also omitted the migration-unit selected-unit envelope. The known-good responsibility-handoff fixture rendered both. Single root-cause hypothesis: the fixtures no longer represented a canonical migration-unit producer envelope, so every newly strict chain edge was invalid. The validator was not weakened. The smallest fixture producer correction rendered the exact adapter and conditional selected-unit data. Focused GREEN:

- `flexible-scope-e2e.Tests.ps1 -OnlyScenario S05`: exit `0`, one selected scenario PASS.
- `flexible-scope-e2e.Tests.ps1 -OnlyScenario S20`: exit `0`, S20 plus its negative, waiver, cross-run, greenfield, and source-diff subcases PASS.
- Full Step-4 rerun: exit `0`, `PASS: flexible migration scope orchestration (21 isolated E2E scenarios)`.

A later `All` gate exposed one preserved-token regression: `FAIL: Migration parity handoff missing: immediate predecessor`. The parity skill retained the behavior but not that exact framework token. The minimal wording correction restored it; fresh Skills and All both exited `0`.

### Final focused mutation and Step-4 short gates

Focused selector on the final pre-amend tree:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.Tests.ps1 -ResponsibilityConformanceOnly
```

Exit `0`; 17/17 isolated mutations; exact final line `PASS: responsibility conformance mutation scenarios`. Every mutation reported the unchanged source digest `4374F341ECAB8CFAD2494CE68A675F17F90EC3E4BC1FD52B766B88A9BA3C79CF`.

| Step-4 command | Final result |
|---|---|
| `responsibility-conformance.Tests.ps1` | Exit `0`; `PASS: responsibility conformance contract`. |
| `responsibility-handoff.Tests.ps1` | Exit `0`; `PASS: responsibility handoff scenarios`. |
| `target-conformance.Tests.ps1` | Exit `0`; `PASS: target conformance scenarios`. |
| `structural-gate.Tests.ps1` | Exit `0`; `PASS: structural gate (146 scenarios)`. |
| `architecture-review.Tests.ps1` | Exit `0`; `PASS: architecture review scenarios`. |
| `scope-engine.Tests.ps1` | Exit `0`; `PASS: scope engine behavioral scenarios`. |
| `flexible-scope-e2e.Tests.ps1` | Exit `0`; `PASS: flexible migration scope orchestration (21 isolated E2E scenarios)`. |
| `validate-migration-framework.ps1 -Check Contracts` | Exit `0`; `PASS: migration framework (Contracts)`. |
| `validate-migration-framework.ps1 -Check Skills` | Exit `0`; `PASS: migration framework (Skills)`. |
| `validate-migration-framework.ps1 -Check Templates` | Exit `0`; `PASS: migration framework (Templates)`. |
| `validate-migration-framework.ps1 -Check All` | Exit `0`; `PASS: migration framework (All)`. |
| `validate-migration-framework.ps1 -Check SourceIntegrityOnly` | Exit `0`; `PASS: migration framework (SourceIntegrityOnly)`. |
| `git diff --check` | Exit `0`; informational LF-to-CRLF working-copy warnings only. |

### Final self-review, scope, and concerns

- All six final-review findings have direct focused coverage and minimal production/routing changes.
- Review owner selection is exact and occurs before source inventory; changed-path discovery remains broader than selected-owner discovery.
- Review-to-terminal handoff validation is fail-closed for lifecycle, identity, immutable provenance/evidence, immediate predecessor, adapter, and selected-unit cardinality.
- `VER-*` remains only in the explicit negative mutant/test description; production contracts, validators, fixtures, and accepted examples use only `VERIFY-OWNER-*`.
- No source edit occurred while any test process was running.
- The default/full mutation suite was not run. It remains reserved for the controller's one post-review execution.
- No Phase 2 work was started; automated remediation remains pending Phase 2 and the original issue remains partially resolved.
- Staged-scope audit and exact-HEAD post-amend verification are recorded below after amend.

### Amend, staged scope, and exact-HEAD verification

- Staged scope contained exactly the 17 final-wave files listed above; no `main/`, `issue/`, report artifact, or file outside Phase 1 was staged. `git diff --cached --check` exited `0`.
- `git commit --amend --no-edit` produced exactly one commit after Task BASE: `894b20ab882eb16a6c7dd4ab09120aa7c566096c test: cover responsibility conformance workflow`.
- `git rev-list --count 0cbb95afb835263ecf3b52b36f5ec0605f903435..HEAD` returned `1`.
- The amended commit contains 18 files total because it preserves the original Task 9 main-validator change in addition to the 17 files staged by this wave.
- Exact-HEAD focused selector exited `0`, emitted all 17 mutation PASS lines and final `PASS: responsibility conformance mutation scenarios`; every line retained digest `4374F341ECAB8CFAD2494CE68A675F17F90EC3E4BC1FD52B766B88A9BA3C79CF`.
- Exact-HEAD `-Check All` exited `0`: `PASS: migration framework (All)`.
- Exact-HEAD `-Check SourceIntegrityOnly` exited `0`: `PASS: migration framework (SourceIntegrityOnly)`.
- `git diff --check HEAD^ HEAD` exited `0` with no output.
- Final `git status --porcelain=v1` produced no output: worktree clean.
- Final commit message is unchanged and exact; the default/full mutation suite was not run.

## Final review fix round 2

Review round: 2026-08-21  
Commit policy: amend the sole Task 9 commit; exact message remains `test: cover responsibility conformance workflow`.  
Starting SHA: `894b20ab882eb16a6c7dd4ab09120aa7c566096c`.

### Files changed in this round

- `aitoolkit/contracts/activation-slice.md`
- `aitoolkit/tests/scenarios/flexible-scope-e2e.Tests.ps1`
- `aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1`
- `aitoolkit/tests/scenarios/responsibility-handoff.Tests.ps1`
- `aitoolkit/tests/scenarios/structural-gate.Tests.ps1`
- `aitoolkit/tests/scenarios/target-conformance.Tests.ps1`
- `aitoolkit/tests/validate-migration-framework.ps1`
- `aitoolkit/tests/validation/responsibility-conformance.validation.ps1`
- `aitoolkit/tests/validation/target-conformance.validation.ps1`

### Finding 2 — external approved target mode authority

Tests were added before production changes. Exact RED command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\target-conformance.Tests.ps1
```

Exit `1`; exact stopping evidence: `target conformance rejects design mode that mismatches external approved profile should fail but passed`. The GREEN implementation removes the incremental default, reads `docs/aitoolkit/project.yaml` as the external persisted authority, requires exactly one canonical `migration.mode`/`architecture_policy` pair whenever discovery/design artifacts exist, passes that exact mode to both responsibility helpers, and rejects a bounded design Architecture row that disagrees. The same scenario later exited `0`, including true external incremental/greenfield positives, the mismatch negative, and `Missing approved migration mode authority` when the profile is absent. Empty contract-only roots remain valid because there is no target artifact integration to authorize.

### Finding 3 — current work-item binding and unchanged owner evidence

The owner-reference and source-only tests were written before validator changes. The first combined scenario run stopped earlier at the decomposition RED, so those later assertions were not reached; no pre-change output is invented. Their GREEN run proves exact owner-reference-to-`Change Hygiene` Task/Unit binding, selected final-tree loading for unchanged owners, source evidence without a diff, and rejection of a claimed current-SHA diff.

Self-review then found a distinct unproven gap and followed a new exact RED-to-GREEN cycle. RED command was the same responsibility scenario, exit `1`, with exact output: `review rejects foreign-SHA diff anchors for unchanged selected owner paths expected responsibility-evidence-missing but got:`. GREEN exit `0` includes:

- `PASS: review owner references bind the exact current work item provenance`
- `PASS: review loads unchanged selected owners from pinned final-tree source evidence without fabricated diff anchors`
- `PASS: review rejects fabricated diff anchors for unchanged selected owner paths`
- `PASS: review rejects foreign-SHA diff anchors for unchanged selected owner paths`

The validator now records whether each pinned final-tree path changed. Changed owners require exact source plus exact task-base/final-tree diff anchors; unchanged owners require exact pinned source anchors and reject every diff URI for that path/anchor, regardless of claimed SHA. All changed and deleted paths continue to be inventoried separately for unplanned owners.

### Finding 4 — adapter-aware canonical contract and approved plan binding

Tests were added before production changes. Exact RED command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-handoff.Tests.ps1
```

Exit `1`; exact output: `Activation contract missing canonical adapter-aware selected-unit rule: Adapter Kind Applicability`. GREEN handoff exit `0` proves migration-unit ordinal preservation through KB, generic review-to-verification-to-parity-to-KB omission, rejection of generic invention, caller self-attestation against a different approved plan, and fail-closed behavior with no plan authority. The sole activation contract now states migration-unit exact-row preservation for steps 11–15 and generic exact absence for steps 11–15. `Test-ResponsibilityHandoff` consumes approved current plan text, binds master plan ID/revision/work item and adapter kind, accepts either the canonical detailed `Delivery Adapter Selection` table or canonical master `Work Items` adapter authority, and compares all ten selected-unit fields ordinally at every migration-unit edge.

### Finding 5 — exact decomposition authorization

Tests were added before production changes. Exact RED command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-conformance.Tests.ps1
```

Exit `1`; exact stopping evidence: `decomposition without approval source cannot authorize reuse expected responsibility-owner-extra but got:`. GREEN exit `0` covers the exact approved route plus draft, absent approval source, non-human approval, mutable reference, and foreign decision negatives. Cross-work-item reuse now requires the exact approved/complete/human plan envelope, one direct parent/child adapter relationship, the same decision/master revision/design revision, both work-item traces on the reused responsibility, one exact `Approved Decomposition Decisions` row, a canonical human approval, and the immutable exact reference `<master-plan-reference>@revision=<revision>:<DEC-*>`.

### Systematic-debugging RCA during affected integration gates

1. The first structural rerun exited `1`: `canonical Task 6 fixture expected PASS, got: Missing approved migration mode authority`. Trace showed its nested target-conformance root had design/discovery artifacts but no profile. The fixture was updated to include the external incremental profile; rerun exited `0`, `PASS: structural gate (146 scenarios)`.
2. The first whole Flexible rerun after fail-closed mode exited `1` with every scenario reporting `Missing approved migration mode authority`. The isolated toolkit fixture likewise lacked the project profile. Adding the external fixture profile removed that failure without weakening validation.
3. The next whole Flexible run exited `1` with `Test-ResponsibilityHandoff : The property 'Count' cannot be found on this object` at the line-1745 chain call. Comparison with the standalone passing fixture isolated strict-mode scalar unrolling in the new plan table result. Typed-array initialization removed the runtime error.
4. Focused `flexible-scope-e2e.Tests.ps1 -OnlyScenario S20` then exited `1` with `DIAGNOSTIC: terminal-scope-report-invalid`. Trace from producer through review/downstream artifacts showed `UNIT-E2E` self-labels while the approved master selected `UNIT-A`/`UNIT-B`. The smallest correction rendered the approved selected row and let the handoff validator read canonical Work Items authority. Focused S20 then exited `0`: `PASS: flexible migration scope orchestration (1 selected isolated E2E scenario(s))`; whole Flexible later exited `0`: `PASS: flexible migration scope orchestration (21 isolated E2E scenarios)`.

### Final Step-4 gates after the last fix

| Command | Result |
|---|---|
| `responsibility-conformance.Tests.ps1` | Exit `0`; `PASS: responsibility conformance contract`. |
| `responsibility-handoff.Tests.ps1` | Exit `0`; `PASS: responsibility handoff scenarios`. |
| `target-conformance.Tests.ps1` | Exit `0`; `PASS: target conformance scenarios`. |
| `structural-gate.Tests.ps1` | Exit `0`; `PASS: structural gate (146 scenarios)`. |
| `architecture-review.Tests.ps1` | Exit `0`; `PASS: architecture review scenarios`. |
| `scope-engine.Tests.ps1` | Exit `0`; `PASS: scope engine behavioral scenarios`. |
| `flexible-scope-e2e.Tests.ps1` | Exit `0`; `PASS: flexible migration scope orchestration (21 isolated E2E scenarios)`. |
| `validate-migration-framework.ps1 -Check Contracts` | Exit `0`; `PASS: migration framework (Contracts)`. |
| `validate-migration-framework.ps1 -Check Skills` | Exit `0`; `PASS: migration framework (Skills)`. |
| `validate-migration-framework.ps1 -Check Templates` | Exit `0`; `PASS: migration framework (Templates)`. |
| `validate-migration-framework.ps1 -Check All` | Exit `0`; `PASS: migration framework (All)`. |
| `validate-migration-framework.ps1 -Check SourceIntegrityOnly` | Exit `0`; `PASS: migration framework (SourceIntegrityOnly)`. |
| `git diff --check` | Exit `0`; only informational LF-to-CRLF working-copy warnings. |

Final pre-amend focused selector:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.Tests.ps1 -ResponsibilityConformanceOnly
```

Exit `0`; all 17 isolated mutations PASS and final line is `PASS: responsibility conformance mutation scenarios`. Every mutation reported the same unchanged source digest `632B11E056381C8DF920F386BD5588F17D5D0B7CC420FF0F9509CA1F9F49726F`.

### Self-review and concerns before amend

- Exact external mode authority is independent from design self-attestation and fails closed only when target artifacts require integration.
- Owner selection binds the sole reference row to exact current implementation provenance; unchanged paths cannot claim any diff anchor.
- Adapter kind comes from approved/current plan authority, migration-unit rows are exact and ordinal through terminal KB, and generic adapters omit the section.
- Decomposition reuse has a strict human lifecycle and an exact revision-bound decision record; ordinary single-work-item draft planning remains allowed.
- No source edit occurred while a test process was running.
- The default/full mutation suite was not run and remains reserved for the controller.
- No Phase 2 work was started; automated remediation remains pending Phase 2 and the original issue remains only partially resolved.
- Amend SHA, staged scope, exact-HEAD evidence, and final status are appended below after amend.

### Amended commit and exact-HEAD verification

The staged-scope audit contained exactly the nine round-2 files listed above. `git diff --cached --check` exited `0`; `git status --short` showed each as staged and no unstaged file, `issue/`, `main/`, or out-of-scope path. The sole Task 9 commit was amended in place:

```text
81f3f2a22b96cebc56e413be986494dc2080f22a test: cover responsibility conformance workflow
```

Fresh verification on that exact HEAD:

| Command | Result |
|---|---|
| `validate-migration-framework.Tests.ps1 -ResponsibilityConformanceOnly` | Exit `0`; all 17 mutations PASS; `PASS: responsibility conformance mutation scenarios`. |
| `validate-migration-framework.ps1 -Check All` | Exit `0`; `PASS: migration framework (All)`. |
| `validate-migration-framework.ps1 -Check SourceIntegrityOnly` | Exit `0`; `PASS: migration framework (SourceIntegrityOnly)`. |
| `git diff --check HEAD^ HEAD` | Exit `0`; no diagnostics. |
| `git rev-list --count 0cbb95afb835263ecf3b52b36f5ec0605f903435..HEAD` | `1`. |
| `git status --short` | Empty; worktree clean. |

Every exact-HEAD isolated mutation again reported source digest `632B11E056381C8DF920F386BD5588F17D5D0B7CC420FF0F9509CA1F9F49726F`, proving source bytes remained unchanged across every fixture mutation. The first exact-HEAD selector invocation completed but its detached command-capture session lost the buffered output; after confirming that process had ended, the selector was rerun once to capture the exit/output above. No source changed between those runs.

Final scoped status: Core false-positive: fixed. Prevention gates: complete. Safe post-implementation stop: complete. Automated remediation: pending Phase 2. Original issue: partially resolved.

## Final review fix round 4

Review date: 2026-08-22  
Starting SHA: `59178caf1ebf475a02a176ad7f95c34495817d00`.  
Commit policy: amend the same sole Task 9 commit; retain message `test: cover responsibility conformance workflow`.

### Round-4 files

- `aitoolkit/contracts/migration-scope-orchestration.md`
- `aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1`
- `aitoolkit/tests/scenarios/responsibility-handoff.Tests.ps1`
- `aitoolkit/tests/scenarios/scope-artifacts.Tests.ps1`
- `aitoolkit/tests/scenarios/structural-gate.Tests.ps1`
- `aitoolkit/tests/scenarios/target-conformance.Tests.ps1`
- `aitoolkit/tests/validation/responsibility-conformance.validation.ps1`
- `aitoolkit/tests/validation/scope-artifacts.validation.ps1`
- `aitoolkit/tests/validation/structural-gate.validation.ps1`
- `aitoolkit/tests/validation/target-conformance.validation.ps1`

### Finding 1 - exact project-profile authority and cited revisions

Tests changed first so the positive profile cited real `legacy`, `target`, and structured requirement-document paths with immutable SHA-256 revisions. Exact RED command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\target-conformance.Tests.ps1
```

Exit `1`; exact stopping output: `discovery accepts approved no-equivalent gap should pass but failed: Stale approved migration mode authority`. This proved the validator still forced `Source/Target/Document Revisions = not-applicable` even when the approved profile cited real inputs.

GREEN validation now checks the complete canonical top-level and section key sets, exact structured document records, unique evidence IDs, canonical contained paths, migration mode/policy consistency, approved/complete/human review lifecycle, profile/pack revisions, a one-to-one document evidence table, exact current source/target/document content revisions, and a resolved non-placeholder approval. It accepts `not-applicable` only when no source, target, or document is cited. Final scenario exit `0` includes the real-revision positive and negatives for stale source bytes, mismatched review revision, unsupported alias, duplicate key, deeply nested alias, and traversal path.

Two self-review REDs tightened the exact parser:

- deeply nested alias: exit `1`, expected `Invalid approved migration mode authority` but received `Stale approved migration mode authority`; GREEN rejects every extra non-document section line before freshness;
- traversal source path: exit `1`, expected `Invalid approved migration mode authority` but received `Stale approved migration mode authority`; GREEN rejects `.` and `..` canonical-path segments.

### Finding 2 - canonical selector authority, `none`, and exact Work Item set

Tests preceded implementation. Focused RED evidence:

| Command | Exit and exact gap |
|---|---|
| `scope-artifacts.Tests.ps1` | Exit `1`; `FAIL: duplicate-one/missing-another selector set must be rejected; got:`. |
| `responsibility-handoff.Tests.ps1` | Exit `1`; `none selector retains approved generic delivery adapter with Work Item assurance identity should pass but got: responsibility-evidence-missing`. |
| `responsibility-handoff.Tests.ps1` self-review | Exit `1`; `approved plan selector set equality is independent of row order should pass but got: responsibility-evidence-missing`. |
| `responsibility-handoff.Tests.ps1` concrete-adapter self-review | Exit `1`; `package selector preserves its concrete external authority and Work Item assurance identity should pass but got: responsibility-evidence-missing`. |

GREEN semantics are now canonical and shared by scope and handoff validation:

- every Work Item ID appears exactly once in `Delivery Adapter Selection`, proved by ordinal `HashSet.SetEquals` plus duplicate rejection rather than row counts;
- `Adapter Kind = none` requires all five selector authority fields to be exactly `not-applicable`, while the Work Item may retain `none` or its approved internal `generic:<adapter-id>` delivery metadata;
- every concrete adapter kind requires a concrete external ID, authority, positive authority revision, and resolved approval; canonical IDs such as `pkg:admin-locks` are accepted;
- Work Item acceptance/trace/adapter equality and adapter-aware assurance provenance remain bound to approved plan authority.

Final `scope-artifacts.Tests.ps1` and `responsibility-handoff.Tests.ps1` each exited `0`, including reordered-set positive, duplicate-one/missing-another negative, `none` plus generic positive, and package selector positive.

### Finding 3 - immutable approved decomposition plan revision

Tests preceded implementation. Exact RED command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-conformance.Tests.ps1
```

Exit `1`; exact stopping evidence: `approved decomposition plan without immutable front-matter revision cannot authorize reuse expected responsibility-owner-extra but got:`. A later self-review RED on an approved non-decomposition plan exited `1` with `approved plan rejects a non-decomposition adapter revision mismatch expected responsibility-owner-extra but got:`. That second RED proved revision binding had to apply to every approved adapter row, not only a reused responsibility branch.

GREEN requires an approved plan to have the exact approved/complete/human envelope, one positive front-matter revision, the same run as the approved design, and every adapter/decomposition-decision revision equal to that immutable plan revision. Decision evidence uses that front-matter revision rather than trusting the row's own assertion. Placeholder terms `PENDING`, `TBD`, `UNKNOWN`, or `PLACEHOLDER` are rejected anywhere inside a decomposition approval, including `approval:TECH-LEAD-ADMIN-PENDING`. The structural selected-plan projection now preserves the exact approved plan revision. Final responsibility scenario exit `0` covers positive immutable revision plus missing, mismatch, non-decomposition mismatch, and suffix-placeholder negatives.

### Systematic-debugging RCA during round 4

1. The first global adapter-revision binding made structural exit `1` with `responsibility-owner-extra`. The fixture had a responsibility-plan revision `3` but asserted adapter/master revision `4`. After a dedicated non-decomposition RED confirmed the requirement applies globally, the canonical plan/selector/report fixture was aligned to one immutable revision `4`; structural then exited `0`, `PASS: structural gate (146 scenarios)`.
2. The first ordinal-set implementation used the two-argument generic `HashSet` constructor. Windows PowerShell 5.1 could not bind that overload and handoff exited `1`: `Cannot find an overload for "new" and the argument count: "2"`. The compatible comparer-only constructor plus explicit `Add` loop preserved the same set semantics; rerun exited `0`.
3. Optional decomposition-table initialization unrolled an empty `if` result to `$null` under strict mode. Responsibility scenarios exited `1`: `The property 'Count' cannot be found on this object`. Wrapping the complete conditional in `@(...)` made the zero-row case a real array; rerun exited `0`.
4. A PowerShell AST audit initially exited `1` because `git diff --name-only` paths were already relative to the outer git root and the audit joined them to the nested project root. Rerunning against `git rev-parse --show-toplevel` exited `0`; all nine modified PowerShell files reported `PARSE PASS`.

### Focused GREEN evidence before final gates

| Command | Result |
|---|---|
| `target-conformance.Tests.ps1` | Exit `0`; `PASS: target conformance scenarios`. |
| `scope-artifacts.Tests.ps1` | Exit `0`; `PASS: scope artifact scenarios`. |
| `responsibility-handoff.Tests.ps1` | Exit `0`; `PASS: responsibility handoff scenarios`. |
| `responsibility-conformance.Tests.ps1` | Exit `0`; `PASS: responsibility conformance contract`. |
| `structural-gate.Tests.ps1` | Exit `0`; `PASS: structural gate (146 scenarios)`. |
| `flexible-scope-e2e.Tests.ps1 -OnlyScenario S04` | Exit `0`; `PASS: flexible migration scope orchestration (1 selected isolated E2E scenario(s))`. |
| `flexible-scope-e2e.Tests.ps1 -OnlyScenario S06` | Exit `0`; `PASS: flexible migration scope orchestration (1 selected isolated E2E scenario(s))`. |
| PowerShell AST parse against all modified `.ps1` files | Exit `0`; every file `PARSE PASS`. |

### Final Step-4 evidence

All commands below were started only after the last source edit.

| Command | Result |
|---|---|
| `responsibility-conformance.Tests.ps1` | Exit `0`; `PASS: responsibility conformance contract`. |
| `responsibility-handoff.Tests.ps1` | Exit `0`; `PASS: responsibility handoff scenarios`. |
| `target-conformance.Tests.ps1` | Exit `0`; `PASS: target conformance scenarios`. |
| `structural-gate.Tests.ps1` | Exit `0`; `PASS: structural gate (146 scenarios)`. |
| `architecture-review.Tests.ps1` | Exit `0`; `PASS: architecture review scenarios`. |
| `scope-engine.Tests.ps1` | Exit `0`; `PASS: scope engine behavioral scenarios`. |
| `flexible-scope-e2e.Tests.ps1` | Exit `0`; `PASS: flexible migration scope orchestration (21 isolated E2E scenarios)`. |
| `validate-migration-framework.ps1 -Check Contracts` | Exit `0`; `PASS: migration framework (Contracts)`. |
| `validate-migration-framework.ps1 -Check Skills` | Exit `0`; `PASS: migration framework (Skills)`. |
| `validate-migration-framework.ps1 -Check Templates` | Exit `0`; `PASS: migration framework (Templates)`. |
| `validate-migration-framework.ps1 -Check All` | Exit `0`; `PASS: migration framework (All)`. |
| `validate-migration-framework.ps1 -Check SourceIntegrityOnly` | Exit `0`; `PASS: migration framework (SourceIntegrityOnly)`. |
| `git diff --check` | Exit `0`; informational LF-to-CRLF warnings only. |

Focused mutation selector:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.Tests.ps1 -ResponsibilityConformanceOnly
```

Exit `0`; all 17 isolated mutations PASS with final `PASS: responsibility conformance mutation scenarios`. Every mutation retained source digest `C2CB32032EB100F6AACC52B238F02D23E06483A3AEF93DA236BECFA48E001201`.

### Self-review and scope before amend

- The project profile is validated as exact canonical authority rather than a mode-only shape, and real cited source/target/document bytes are revision-bound to the human review.
- Selector cardinality is an order-independent bijection over unique Work Item IDs; `none` cannot invent external authority and may retain only the approved internal generic delivery adapter.
- Concrete adapter IDs preserve their canonical syntax and adapter-aware assurance identity.
- Approved decomposition authority cannot omit or self-assert a mutable revision; every adapter and decision is bound to the plan's exact front-matter revision.
- No production source was edited while the final Step-4 tests were running.
- The default/full mutation suite was not run. No Phase 2 file or behavior was created.
- Staged-scope audit, amended SHA, exact-HEAD selector/All/SourceIntegrity evidence, commit count, and clean status are appended below after amend.

## Final whole-branch review fix wave — round 3

Review round: 2026-08-22  
Starting SHA: `81f3f2a22b96cebc56e413be986494dc2080f22a`.  
Commit policy: amend the same sole Task 9 commit; retain exact message `test: cover responsibility conformance workflow`.

### Files changed in round 3

- `aitoolkit/contracts/activation-slice.md`
- `aitoolkit/contracts/migration-scope-orchestration.md`
- `aitoolkit/skills/migration/code-migration/SKILL.md`
- `aitoolkit/skills/migration/verify-parity/SKILL.md`
- `aitoolkit/skills/migration/verify-regression/SKILL.md`
- `aitoolkit/skills/shared/ai-review/SKILL.md`
- `aitoolkit/skills/shared/verification-testing/SKILL.md`
- `aitoolkit/templates/migration/master-plan.md`
- `aitoolkit/templates/migration/parity-report.md`
- `aitoolkit/templates/migration/regression-report.md`
- `aitoolkit/templates/migration/review-report.md`
- `aitoolkit/templates/migration/verification-report.md`
- `aitoolkit/tests/scenarios/flexible-scope-e2e.Tests.ps1`
- `aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1`
- `aitoolkit/tests/scenarios/responsibility-handoff.Tests.ps1`
- `aitoolkit/tests/scenarios/scope-artifacts.Tests.ps1`
- `aitoolkit/tests/scenarios/structural-gate.Tests.ps1`
- `aitoolkit/tests/scenarios/target-conformance.Tests.ps1`
- `aitoolkit/tests/validate-migration-framework.ps1`
- `aitoolkit/tests/validation/responsibility-conformance.validation.ps1`
- `aitoolkit/tests/validation/scope-artifacts.validation.ps1`
- `aitoolkit/tests/validation/structural-gate.validation.ps1`
- `aitoolkit/tests/validation/target-conformance.validation.ps1`

### Finding 1 — authoritative project-profile lifecycle, freshness, evidence, and true greenfield persistence

Focused tests were added before the stricter parser. RED command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\target-conformance.Tests.ps1
```

Exit `1`; exact missing behavior: `target conformance rejects stale profile content after project-pack review should fail but passed`.

The first GREEN attempt exited `1` at the pre-existing positive `discovery accepts approved no-equivalent gap should pass but failed: Missing approved migration mode authority`. Systematic-debugging trace established that the strict markdown-table reader split on LF but retained terminal CR bytes, so CRLF table frames did not match. Trimming the separator CR was the smallest parser correction; no lifecycle check was weakened.

Final target scenario exit `0` proves:

- exact canonical full project profile keys and exactly one canonical `migration.mode/unit/architecture_policy`;
- approved/complete/human project-pack review;
- exact reviewed-at, normalized profile SHA-256, pack-tree SHA-256, source/document revision evidence, and resolved Tech Lead approval;
- rejection of stale content, non-approved review, duplicate top-level mode, noncanonical mode key, missing authority, internal mode/policy mismatch, and design/profile mismatch;
- external incremental and greenfield positives.

S20 now uses `Write-ApprovedProjectProfile` and persists a full externally reviewed `greenfield/design-new` profile before the greenfield positive. It explicitly inspects the persisted profile values before validation and restores the reviewed incremental profile afterward.

### Finding 2 — adapter-aware assurance provenance and exact current selector authority

Tests preceded implementation. First valid RED handoff command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-handoff.Tests.ps1
```

Exit `1`; exact behavior gap: `migration-unit assurance provenance cannot use Work Item identity expected responsibility-evidence-missing but got:`. A separate contract RED exited `1` with `Activation contract missing canonical adapter-aware selected-unit rule: Adapter Kind=migration-unit => Task / Unit=Selected Migration Unit.Migration Unit ID; Adapter Kind=generic => Task / Unit=Master Scope Context.Work Item ID`.

GREEN handoff exit `0` proves migration-unit provenance uses the approved unit, generic provenance uses the Work Item, migration-unit selected rows remain ordinally identical through KB, generic chains omit them, and missing/pending/stale/mismatched/self-attested selector authority fails closed.

The canonical master plan and migration-scope contract now contain one `Delivery Adapter Selection` row per Work Item. Scope-artifact validation binds selector cardinality, Work Item identity, adapter, acceptance, and traces. `Test-ResponsibilityHandoff` additionally binds exact master plan ID/revision, resolved approval, external authority/revision, mode, design revision, and selected-unit fields. The activation contract, skills, and review/verification/parity/regression templates use adapter-aware assurance identity.

#### Integration RCA and focused regressions

1. First S20 integration after the handoff change exited `1` at three positives with `DIAGNOSTIC: terminal-scope-report-invalid`. Trace showed the fixture had created a selector-bearing local `$plan` and then overwritten it with the rendered canonical master plan. Adding the selector to the actual canonical master-plan schema exposed an exact RED, `FAIL: master plan sections must be exact`. The canonical contract/template/scope parser were updated together; `scope-artifacts.Tests.ps1` then exited `0`.
2. The waiver positive later failed because it expanded Work Item traces while leaving selector and downstream selected-unit traces stale. The fixture now updates the selector and every immutable responsibility-chain artifact, rebinding each SHA reference. A stale `$originalTerminal` snapshot then reintroduced the old final-chain reference; reading the current terminal after rebinding fixed that producer-only defect. Focused S20 finally exited `0`: `PASS: flexible migration scope orchestration (1 selected isolated E2E scenario(s))`.
3. The first full 21-case run then exited `1` only for S04 and S06: `master plan selector must match Work Item authority: WORK-E2E-A` and `master plan Delivery Adapter Selection must contain exactly one row per Work Item`. S04 now records internal `generic:*` work under selector kind `none`; S06 creates exact selector rows for every added Work Item. Focused S04 and S06 each exited `0`, and the final full run exited `0`: `PASS: flexible migration scope orchestration (21 isolated E2E scenarios)`.

### Finding 3 — immutable decomposition requires approved human design and plan authority

Tests were added before validator changes. RED command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-conformance.Tests.ps1
```

Exit `1`; exact gap: `decomposition design without approval source cannot authorize reuse expected responsibility-owner-extra but got:`.

GREEN exit `0` proves the one exact approved route plus rejection for missing/non-human design approval, cross-run design, draft/missing/non-human plan approval, mutable or foreign decision evidence, and pending placeholder approval. Reuse requires approved/complete/human design and plan envelopes on the same run, direct traced parent/child authority, one exact decision row, resolved `approval:TECH-LEAD-*`, and immutable `<plan>@revision=<n>:<DEC-*>`.

Structural integration initially exited `1` with `responsibility-owner-extra`; trace showed the canonical responsibility plan includes a numeric revision, while the new envelope shape accepted only the reduced focused fixture. The validator now accepts either exact canonical shape with one positive revision or the reduced projection without it. Structural then exposed its legitimate split authority: Task 6 stays a draft immutable design plus a separately verified human approval artifact. The structural gate now projects that verified approval into the responsibility-plan check, while requiring the referenced Task 8 plan itself to be approved/complete/human with a canonical run ID. Final structural exit `0`: `PASS: structural gate (146 scenarios)`.

### Final focused and Step-4 evidence

All commands below were run after the last source change.

| Command | Result |
|---|---|
| `responsibility-conformance.Tests.ps1` | Exit `0`; `PASS: responsibility conformance contract`. |
| `responsibility-handoff.Tests.ps1` | Exit `0`; `PASS: responsibility handoff scenarios`. |
| `target-conformance.Tests.ps1` | Exit `0`; `PASS: target conformance scenarios`. |
| `structural-gate.Tests.ps1` | Exit `0`; `PASS: structural gate (146 scenarios)`. |
| `architecture-review.Tests.ps1` | Exit `0`; `PASS: architecture review scenarios`. |
| `scope-engine.Tests.ps1` | Exit `0`; `PASS: scope engine behavioral scenarios`. |
| `flexible-scope-e2e.Tests.ps1` | Exit `0`; `PASS: flexible migration scope orchestration (21 isolated E2E scenarios)`. |
| `validate-migration-framework.ps1 -Check Contracts` | Exit `0`; `PASS: migration framework (Contracts)`. |
| `validate-migration-framework.ps1 -Check Skills` | Exit `0`; `PASS: migration framework (Skills)`. |
| `validate-migration-framework.ps1 -Check Templates` | Exit `0`; `PASS: migration framework (Templates)`. |
| `validate-migration-framework.ps1 -Check All` | Exit `0`; `PASS: migration framework (All)`. |
| `validate-migration-framework.ps1 -Check SourceIntegrityOnly` | Exit `0`; `PASS: migration framework (SourceIntegrityOnly)`. |
| `git diff --check` | Exit `0`; informational LF-to-CRLF working-copy warnings only. |

Focused mutation selector:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.Tests.ps1 -ResponsibilityConformanceOnly
```

Exit `0`; all 17 isolated mutations PASS and final line is `PASS: responsibility conformance mutation scenarios`. Every mutation reported identical unchanged source digest `6F6F0FB8900BE819AA6A8A701008C3084EBADB3E4C1E2B9EB7A5056D920D7F35`.

### Self-review and pre-amend status

- Project mode now comes only from a canonical, reviewed, revision-bound external profile whenever target responsibility artifacts require it.
- Assurance provenance is adapter-aware end to end, and the canonical master plan supplies one current selector authority row per Work Item.
- Decomposition approval is jointly bound to immutable human-approved design and plan authority on the same run.
- S20's greenfield positive uses a genuinely persisted reviewed greenfield profile; unchanged-owner evidence and generic adapter omission remain covered by prior focused cases.
- No source edit occurred while a test process was active.
- The default/full mutation suite was not run; it remains reserved for the controller.
- No Phase 2 work was started. Automated remediation remains pending Phase 2; the original issue remains partially resolved.
- Staged-scope audit, amended SHA, and exact-HEAD verification follow below.

### Round-3 amend and exact-HEAD verification

- Staged scope contained exactly the 23 round-3 files listed above; no `main/`, `issue/`, report artifact, or out-of-scope path was staged.
- `git diff --cached --check` exited `0`.
- `git commit --amend --no-edit` produced `59178caf1ebf475a02a176ad7f95c34495817d00 test: cover responsibility conformance workflow`.
- The sole amended Task 9 commit contains 26 files total, preserving the original Task 9 mutation/main-validator files plus prior review-wave corrections.
- Exact-HEAD focused selector exited `0`; all 17 isolated mutations PASS with final `PASS: responsibility conformance mutation scenarios`. Every case retained source digest `6F6F0FB8900BE819AA6A8A701008C3084EBADB3E4C1E2B9EB7A5056D920D7F35`.
- Exact-HEAD `-Check All` exited `0`: `PASS: migration framework (All)`.
- Exact-HEAD `-Check SourceIntegrityOnly` exited `0`: `PASS: migration framework (SourceIntegrityOnly)`.
- `git diff --check HEAD^ HEAD` exited `0` with no diagnostics.
- `git rev-list --count 0cbb95afb835263ecf3b52b36f5ec0605f903435..HEAD` returned `1`.
- `git status --porcelain=v1 --untracked-files=all` produced no output; worktree clean.
- The default/full mutation suite was not run. No Phase 2 change was made.

Final scoped status: Core false-positive: fixed. Prevention gates: complete. Safe post-implementation stop: complete. Automated remediation: pending Phase 2. Original issue: partially resolved.

## Final review fix round 4 - amended completion

The detailed round-4 RED/GREEN/RCA log above is completed by this final chronological record.

- Staged scope contained exactly the ten round-4 files listed in the detailed log. `git diff --name-only` after staging was empty, so there were no unstaged source changes; no `main/`, `issue/`, report artifact, or Phase 2 path was staged.
- `git diff --cached --check` exited `0`; staged diff was `429 insertions(+), 47 deletions(-)` across those ten files.
- `git commit --amend --no-edit` produced `cb15cf1d3cb66cdbf062b27eb90e3131e30d49fb test: cover responsibility conformance workflow`.
- The amended sole Task 9 commit still contains 26 files total and keeps the original commit message.
- Exact-HEAD `validate-migration-framework.Tests.ps1 -ResponsibilityConformanceOnly` exited `0`; all 17 mutations PASS with final `PASS: responsibility conformance mutation scenarios` and unchanged source digest `C2CB32032EB100F6AACC52B238F02D23E06483A3AEF93DA236BECFA48E001201`.
- Exact-HEAD `validate-migration-framework.ps1 -Check All` exited `0`: `PASS: migration framework (All)`.
- Exact-HEAD `validate-migration-framework.ps1 -Check SourceIntegrityOnly` exited `0`: `PASS: migration framework (SourceIntegrityOnly)`.
- `git diff --check HEAD^ HEAD` exited `0` with no diagnostics.
- `git rev-list --count 0cbb95afb835263ecf3b52b36f5ec0605f903435..HEAD` returned `1`.
- `git diff --name-only HEAD^ HEAD | Measure-Object` returned `26` files for the sole cumulative Task 9 commit.
- `git status --porcelain=v1 --untracked-files=all` produced no output; the linked worktree is clean.
- The default/full mutation suite was not run. No Phase 2 change was made.

Final scoped status: Core false-positive: fixed. Prevention gates: complete. Safe post-implementation stop: complete. Automated remediation: pending Phase 2. Original issue: partially resolved.

## Final review fix round 5

Round 5 started from `cb15cf1d3cb66cdbf062b27eb90e3131e30d49fb` and changed exactly six files: the target-conformance, structural-gate, and responsibility-conformance validators plus their three focused scenario suites. Tests were written and observed failing before each corresponding validator change.

### RED evidence

- Project profile shape: `target-conformance.Tests.ps1` exited `1` at the new PowerShell 5.1 boundary case: `target conformance rejects blank base_branch without borrowing test_cmd on PowerShell 5.1 should fail but passed`. The focused matrix also covers a second blank scalar, nested scalar/list/map content beneath every top-level scalar namespace, every duplicate scalar key, and an unknown scalar alias while refreshing the cited profile revision so freshness could not mask the parser defect.
- Selector pairing: `structural-gate.Tests.ps1` exited `1` at `none selector preserves the exact approved generic delivery adapter expected PASS, got: Structural gate external Work Item and all canonical selector fields must agree exactly`. The same pre-implementation test set adds rejection for a concrete `Parent Selector` under `none` and for a stale `generic:*` adapter that disagrees with approved Task 6 evidence.
- Whole-plan decomposition: `responsibility-conformance.Tests.ps1` exited `1` at `unused pending decomposition decision cannot remain in an approved plan expected responsibility-owner-extra but got:`. Its pre-implementation cases also cover unused mutable evidence, orphan and duplicate decisions, a foreign adapter decision, and a positive full plan with an otherwise-unused sibling decision. Structural coverage changed the sibling-row projection bypass from accepted to rejected.

### GREEN implementation and regression trace

- Profile parsing is line-bounded, requires exactly the canonical top-level keys, rejects duplicate/unknown keys, rejects children beneath scalar namespaces, and validates canonical nested shapes without weakening the existing reviewed revision/freshness checks.
- A canonical `none` selector requires `Parent Selector = not-applicable`; its Work Item may retain the exact approved `none` or `generic:<adapter-id>` delivery adapter. Existing Task 6 binding still rejects stale or mismatched generic values, and migration-unit behavior is unchanged.
- Every approved decomposition decision row is validated, including unused rows, for exact unique IDs, non-placeholder resolved human authority, same-run approved plan/design revisions, immutable evidence, and exact parent/child adapter bindings. Structural validation now passes the full responsibility plan instead of a one-row projection.
- The first responsibility GREEN attempt exposed a Windows PowerShell strict-mode regression when an empty conditional assignment unrolled to `$null` and `.Count` failed. Materializing `[object[]]$decisionRows = @(...)` fixed that representation defect; no authority check was relaxed.

Final affected scenarios after the last source edit all exited `0`: responsibility conformance, responsibility handoff, target conformance, structural gate (`149 scenarios`), architecture review, scope artifacts, scope engine, and flexible-scope E2E (`21 isolated E2E scenarios`). The PowerShell AST parse of all six changed files passed.

### Step 4, focused selector, and exact-HEAD evidence

All 13 Step 4 gates passed after the last source change: the seven required scenario suites; `-Check Contracts`, `Skills`, `Templates`, `All`, and `SourceIntegrityOnly`; and `git diff --check` (only informational LF-to-CRLF working-copy notices before staging). The additional `scope-artifacts.Tests.ps1` regression also passed.

The focused `validate-migration-framework.Tests.ps1 -ResponsibilityConformanceOnly` run exited `0`; all 17 isolated mutations passed with final `PASS: responsibility conformance mutation scenarios` and source digest `2E14FC4216501C466671AFCB89DA8EB118C0D0E9AFB0B1E5E9068F5EECF61D16`.

The staged-scope audit contained exactly the six round-5 files above. `git diff --cached --check` exited `0`, the pre-amend commit count from Task 9 base was `1`, and `git commit --amend --no-edit` produced `49a8904f67b982a9370d0c43f9f35ba8797d42de test: cover responsibility conformance workflow`. The sole cumulative Task 9 commit still contains 26 files.

At exact HEAD `49a8904f67b982a9370d0c43f9f35ba8797d42de`, the focused responsibility selector passed again with the same digest, `-Check All` passed, `-Check SourceIntegrityOnly` passed, `git diff --check HEAD^ HEAD` produced no diagnostics, and `git rev-list --count 0cbb95afb835263ecf3b52b36f5ec0605f903435..HEAD` returned `1`. `git status --porcelain=v1 --untracked-files=all` produced no output.

The default/full mutation suite was not run. No Phase 2 work was started. Automated remediation remains pending Phase 2; the original issue remains partially resolved.

## User-approved breaker exception cycle 2

Breaker exception date: 2026-08-22  
Starting exact HEAD: `8e245079aeb41525d48b433eb959e0d7a4f6b2a0`  
Commit policy: amend the same sole Task 9 commit over `0cbb95afb835263ecf3b52b36f5ec0605f903435`; do not create another commit.  
Scope policy: treat the five fresh whole-branch findings as one complete fix wave; do not run the default/full mutation suite and do not start Phase 2 work.

### Finding verification and technical disposition

1. **C1 - canonical migration-unit Plan Reference.** The finding is confirmed. The approved activation/scope contracts carry separate `Authority` and positive `Authority Revision`, while the responsibility handoff contract carries one composite Plan Reference. Structural validation incorrectly compared the selected row to raw `Authority`; implementation/review/verification fixtures used the composite. The one canonical external representation is now exact case-sensitive `Authority@AuthorityRevision`. Technical correction: an `Authority` that already contains `@` is rejected; the validator never silently concatenates an embedded or conflicting revision source.
2. **C2 - responsibility review envelope binding.** The finding is confirmed. `Test-ResponsibilityReview` previously assessed review semantics and internally self-consistent provenance without binding the review to the exact implementation or an independently supplied approved master plan. PASS now requires exact run/spec/plan/work-item scope, adapter, conditional selected unit, task/source artifact/base/final 40-SHAs, source-diff evidence, version-1 responsibility handoff, and approved external plan authority.
3. **I1 - whole-plan selector columns 9-12.** The finding is confirmed. Exact selector set/cardinality checks existed, but `Mode Constraint`, `Design Revision`, `Parent Work Item ID`, and `Decomposition Decision Reference` were not validated for every Work Item and selector order was not bound to Work Item order. Technical clarification: the approved master plan is the immutable selector authority in this contract; no separate design-record table is defined here. The validator therefore binds every row to the approved plan's canonical design reference, parent/decision pairing, exact Work Item set, and ordinal order, rather than inventing a new record type.
4. **I2 - Boundary Kind, Conformance, and Public Symbols.** The finding is confirmed against the approved design/spec. Exact Boundary Kind values are `domain,data,application,presentation,adapter,integration,config,test,project-defined`; Conformance values are `yes,no,blocked`. The old contract example (`atomic-owner`/`PASS`) contradicted the approved enum. Exact lone `none` is a truthful Public Symbols sentinel; empty, malformed, case-variant, or mixed sentinel rows are invalid. `yes` requires `n/a` deviation; `no` requires one exact approved structural deviation; `blocked` is diagnostic and cannot pass conformance.
5. **I3 - legacy project profile.** The finding is confirmed. The schema documents `automation.mode` and `output.style` defaults, so legacy omission is valid. The target parser had incorrectly made both keys mandatory. Omission now applies the documented local defaults (`interactive`, `vi`), while present sections remain strict and malformed aliases/duplicates remain rejected. No mandatory key was invented.

### RED, GREEN, RCA, and regression evidence

- **C1 RED:** `structural-gate.Tests.ps1` exited `1` after the canonical positive was changed to `08-migration-plan.md@4`; the raw-Authority comparison rejected it. **GREEN/RCA:** structural, implementation, review, and handoff validation now share the exact composite and reject embedded, stale, or mismatched revisions. A composed migration implementation -> review -> verification test reuses the same selected row; stale implementation, mismatched review, and stale verification controls all reject. Final structural result is exit `0`, `PASS: structural gate (151 scenarios)`.
- **C2 RED:** `responsibility-conformance.Tests.ps1` exited `1` because a substituted review Run ID was accepted and the negative assertion received no diagnostic. **GREEN/RCA:** review validation now consumes exact implementation and approved-plan envelopes instead of trusting self-attestation. Substituted run/work item/adapter/final SHA/source artifact, stale source diff, non-v1 handoff, cross-plan implementation, and draft external plan all reject. Responsibility conformance and architecture-review integration both exit `0`.
- **I1 RED:** `scope-artifacts.Tests.ps1` exited `1`; stale/fabricated mode, stale/fabricated design, fabricated parent, unbound decision, and reordered sibling selector rows were accepted. **GREEN/RCA:** all selector rows validate columns 9-12, canonical sentinels, parent/decision pairing, uniform immutable mode/design authority, exact set/uniqueness, and Work Item ordinal order. Responsibility handoff performs the same whole-plan binding. Scope artifacts and handoff suites exit `0`.
- **I2 RED:** `responsibility-conformance.Tests.ps1` exited `1` because the truthful canonical `Public Symbols = none` positive was rejected. **GREEN/RCA:** contract example/schema and validator now use the approved exact enums and the lone sentinel, with conformance/deviation semantics enforced. Contract negatives cover invalid Boundary Kind, invalid Conformance, and mixed `none`; design negatives cover empty/malformed sentinels and invalid deviation semantics. Responsibility conformance exits `0`.
- **I3 RED:** `target-conformance.Tests.ps1` exited `1` because a valid legacy profile omitting both defaulted keys was rejected. **GREEN/RCA:** the parser applies documented defaults only when absent, validates exact shapes when present, and rejects alias/duplicate forms. The exact legacy positive and malformed negatives pass; target conformance exits `0`.

No source edit occurred while a test process was active. The failed supplemental AST invocation used root-relative Git paths from the nested project directory and therefore read no files; it was a command-path error, not a source failure. The corrected repository-root AST invocation parsed all 11 changed PowerShell files successfully.

### Affected suites, Step 4, and focused selector

All commands below ran after the last source change.

| Command | Result |
|---|---|
| `responsibility-conformance.Tests.ps1` | Exit `0`; `PASS: responsibility conformance contract`. |
| `responsibility-handoff.Tests.ps1` | Exit `0`; `PASS: responsibility handoff scenarios`. |
| `target-conformance.Tests.ps1` | Exit `0`; `PASS: target conformance scenarios`. |
| `structural-gate.Tests.ps1` | Exit `0`; `PASS: structural gate (151 scenarios)`. |
| `architecture-review.Tests.ps1` | Exit `0`; `PASS: architecture review scenarios`. |
| `scope-artifacts.Tests.ps1` | Exit `0`; `PASS: scope artifact scenarios`. |
| `scope-engine.Tests.ps1` | Exit `0`; `PASS: scope engine behavioral scenarios`. |
| `flexible-scope-e2e.Tests.ps1` | Exit `0`; `PASS: flexible migration scope orchestration (21 isolated E2E scenarios)`. |
| `validate-migration-framework.ps1 -Check Contracts` | Exit `0`; `PASS: migration framework (Contracts)`. |
| `validate-migration-framework.ps1 -Check Skills` | Exit `0`; `PASS: migration framework (Skills)`. |
| `validate-migration-framework.ps1 -Check Templates` | Exit `0`; `PASS: migration framework (Templates)`. |
| `validate-migration-framework.ps1 -Check All` | Exit `0`; `PASS: migration framework (All)`. |
| `validate-migration-framework.ps1 -Check SourceIntegrityOnly` | Exit `0`; `PASS: migration framework (SourceIntegrityOnly)`. |
| `git diff --check` | Exit `0`; informational LF-to-CRLF working-copy notices only. |

Focused selector:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.Tests.ps1 -ResponsibilityConformanceOnly
```

Exit `0`; all 17 isolated mutations passed, final `PASS: responsibility conformance mutation scenarios`, unchanged source digest `E28746D406014AA26C6BCE87F739844C90136B5E0828FED06995E5BC7234674C`.

### Staged-scope audit before amend

The audit contained exactly 21 approved cycle-2 files: three contracts, seven templates, six scenario suites, and five validators. There were no extra or missing paths and no unstaged project changes. Cached diff was `587 insertions(+), 27 deletions(-)`; `git diff --cached --check` exited `0`; the pre-amend commit count from the Task 9 base remained `1`. The report artifact is ignored and was not staged. No `main/`, `issue/`, unrelated refactor, default/full mutation run, or Phase 2 work was included.

The amended SHA and exact-HEAD verification are recorded immediately below after the amend.

## User-approved breaker exception

Breaker exception date: 2026-08-22  
Starting exact HEAD: `49a8904f67b982a9370d0c43f9f35ba8797d42de`  
Commit policy: amend the same sole Task 9 commit; do not create a second commit.  
Final amended HEAD: `8e245079aeb41525d48b433eb959e0d7a4f6b2a0`

### Scope

Exactly four project files changed:

- `aitoolkit/tests/scenarios/target-conformance.Tests.ps1`
- `aitoolkit/tests/validation/target-conformance.validation.ps1`
- `aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1`
- `aitoolkit/tests/validation/responsibility-conformance.validation.ps1`

No default/full `validate-migration-framework.Tests.ps1` run, Phase 2 work, `main/`, `issue/`, contract, template, skill, or unrelated refactor was included.

### Finding 1 - documented non-empty `review_focus` block list

Code verification found that `review_focus` was classified as a scalar. The exact documented non-empty block-list shape was therefore rejected, while the scalar YAML alias `review_focus: *focus` was accepted. Tests were added before the parser change.

RED command for both independent observations:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\target-conformance.Tests.ps1
```

First RED exited `1` with:

```text
target conformance accepts documented non-empty review_focus block list should pass but failed: Invalid approved migration mode authority
```

The scalar-alias case was then moved ahead of the stopping positive assertion; the second RED exited `1` with:

```text
target conformance rejects scalar YAML alias for review_focus should fail but passed
```

Minimal GREEN makes `review_focus` a line-bounded list namespace: exact `[]` remains valid, a non-empty block list of canonical string items is valid, a blank list cannot borrow the next top-level line, and scalar, nested, or unknown aliases fail closed. The same command then exited `0`, including:

```text
PASS: target conformance rejects scalar YAML alias for review_focus
PASS: target conformance accepts documented non-empty review_focus block list
PASS: target conformance rejects nested YAML alias in review_focus block list
PASS: target conformance rejects unknown nested alias key in review_focus block list
PASS: target conformance scenarios
```

### Finding 2 - whole-plan authority for non-decomposition adapters

Code verification found an immediate `continue` when `Decomposition Decision Reference = not-applicable`; those adapter rows skipped master-reference and parent-authority validation. A batched focused test recorded all gaps in one RED without masking later cases.

RED command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-conformance.Tests.ps1
```

Exit `1`; the canonical positive passed, while all four invalid rows were accepted with no diagnostic:

```text
PASS: canonical not-applicable adapter keeps exact current master and parent authority
not-applicable adapter rejects mutable master-plan.md@latest reference expected responsibility-owner-extra but got:
not-applicable adapter rejects an existing foreign parent expected responsibility-owner-extra but got:
not-applicable adapter rejects an orphan parent expected responsibility-owner-extra but got:
not-applicable adapter rejects an invalid parent sentinel expected responsibility-owner-extra but got:
```

Minimal GREEN validates every adapter row against exact `master-plan.md`, a positive/current master revision, and canonical parent authority. A row with `Decomposition Decision Reference = not-applicable` requires exact `Parent Work Item ID = not-applicable` but does not require a decomposition decision. The same command then exited `0`, including:

```text
PASS: canonical not-applicable adapter keeps exact current master and parent authority
PASS: not-applicable adapter rejects mutable master-plan.md@latest reference
PASS: not-applicable adapter rejects an existing foreign parent
PASS: not-applicable adapter rejects an orphan parent
PASS: not-applicable adapter rejects an invalid parent sentinel
PASS: responsibility conformance contract
```

### Affected and final short-gate evidence

- `scope-artifacts.Tests.ps1`: exit `0`, `PASS: scope artifact scenarios`.
- PowerShell AST parse of all four changed scripts: exit `0`; four `PARSE PASS` lines.
- All 13 Task 9 Step-4 gates ran after the last source edit and exited `0`: responsibility conformance; responsibility handoff; target conformance; structural gate (`149 scenarios`); architecture review; scope engine; flexible-scope E2E (`21 isolated E2E scenarios`); `Contracts`; `Skills`; `Templates`; `All`; `SourceIntegrityOnly`; and `git diff --check` (informational LF-to-CRLF notices only).
- Focused `validate-migration-framework.Tests.ps1 -ResponsibilityConformanceOnly`: exit `0`; all 17 isolated mutations passed, final `PASS: responsibility conformance mutation scenarios`, unchanged source digest `2C9A47C7265584106BA52ED5BF19EB3CB0B910544A8359882162B34928A4E885`.
- The default/full mutation suite was deliberately not run.

### Amend and exact-HEAD evidence

The staged-scope audit contained exactly the four files listed above; cached diff was `136 insertions(+), 4 deletions(-)`, `git diff --cached --check` exited `0`, there were no unstaged project files, and the pre-amend Task 9 commit count was `1`. `git commit --amend --no-edit` produced `8e245079aeb41525d48b433eb959e0d7a4f6b2a0 test: cover responsibility conformance workflow`; the sole cumulative Task 9 commit still contains 26 files.

On exact HEAD `8e245079aeb41525d48b433eb959e0d7a4f6b2a0`:

- `validate-migration-framework.Tests.ps1 -ResponsibilityConformanceOnly` exited `0`; all 17 mutations passed with final `PASS: responsibility conformance mutation scenarios` and unchanged digest `2C9A47C7265584106BA52ED5BF19EB3CB0B910544A8359882162B34928A4E885`.
- `validate-migration-framework.ps1 -Check All` exited `0`: `PASS: migration framework (All)`.
- `validate-migration-framework.ps1 -Check SourceIntegrityOnly` exited `0`: `PASS: migration framework (SourceIntegrityOnly)`.
- `git diff --check HEAD^ HEAD` exited `0` with no diagnostics.
- `git rev-list --count 0cbb95afb835263ecf3b52b36f5ec0605f903435..HEAD` returned `1`.
- `git diff --name-only HEAD^ HEAD | Measure-Object` returned `26` files.
- `git status --porcelain=v1 --untracked-files=all` produced no output; the worktree is clean.

The default/full mutation suite was not run. No Phase 2 work was started. Automated remediation remains pending Phase 2; the original issue remains partially resolved.

## User-approved breaker exception cycle 2 - amended completion

- `git commit --amend --no-edit` produced `d689029e276ab1b810d14691f0e6b52345ed92ed test: cover responsibility conformance workflow`; no second commit was created. The sole cumulative Task 9 commit contains 30 files.
- At exact HEAD `d689029e276ab1b810d14691f0e6b52345ed92ed`, `validate-migration-framework.Tests.ps1 -ResponsibilityConformanceOnly` exited `0`; all 17 isolated mutations passed with final `PASS: responsibility conformance mutation scenarios` and unchanged digest `E28746D406014AA26C6BCE87F739844C90136B5E0828FED06995E5BC7234674C`.
- Exact-HEAD `validate-migration-framework.ps1 -Check All` exited `0`: `PASS: migration framework (All)`.
- Exact-HEAD `validate-migration-framework.ps1 -Check SourceIntegrityOnly` exited `0`: `PASS: migration framework (SourceIntegrityOnly)`.
- `git diff --check HEAD^ HEAD` exited `0` with no diagnostics.
- `git rev-list --count 0cbb95afb835263ecf3b52b36f5ec0605f903435..HEAD` returned `1`.
- `git diff --name-only HEAD^ HEAD | Measure-Object` returned `30` cumulative Task 9 files.
- `git status --porcelain=v1 --untracked-files=all` produced no output; the linked worktree is clean. The ignored report update does not alter repository status.
- The default/full mutation suite was not run. No Phase 2 work, `main/`, or `issue/` change was made.

Final scoped status: all five cycle-2 breaker findings are fixed with prevention tests; automated remediation remains pending Phase 2 and the original issue remains partially resolved.

## User-approved breaker exception cycle 3

Breaker exception date: 2026-08-22  
Task base: `0cbb95afb835263ecf3b52b36f5ec0605f903435`  
Starting exact HEAD: `d689029e276ab1b810d14691f0e6b52345ed92ed`  
Commit policy: amend the same sole Task 9 commit; do not create a second commit.

### Verified scope and reviewer-statement corrections

Every statement was checked against the actual producer, consumer, and canonical contract before editing. All four reported defects were confirmed; no reviewer statement required semantic correction. The important ownership clarifications were: Knowledge Base is the terminal producer at `templates/kb-entry.md` plus `skills/shared/knowledge-base/SKILL.md`; AI review must resolve verification source independently from the pinned final tree rather than compare two artifact attestations; not-applicable eligibility belongs to the canonical verification/boundary enums rather than filenames or prose; and generic `Parent Selector` authority comes from the complete ordered selector map, including downstream whole-plan validation.

Exactly these 11 project files changed in cycle 3:

- `aitoolkit/contracts/migration-scope-orchestration.md`
- `aitoolkit/skills/shared/ai-review/SKILL.md`
- `aitoolkit/skills/shared/knowledge-base/SKILL.md`
- `aitoolkit/templates/kb-entry.md`
- `aitoolkit/templates/migration/review-report.md`
- `aitoolkit/tests/scenarios/architecture-review.Tests.ps1`
- `aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1`
- `aitoolkit/tests/scenarios/responsibility-handoff.Tests.ps1`
- `aitoolkit/tests/scenarios/scope-artifacts.Tests.ps1`
- `aitoolkit/tests/validation/responsibility-conformance.validation.ps1`
- `aitoolkit/tests/validation/scope-artifacts.validation.ps1`

No Phase 2, `main/`, `issue/`, default/full mutation-suite, or unrelated change was included.

### C1 - actual Knowledge Base terminal producer

RED command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-handoff.Tests.ps1
```

Exit `1`: `producer-rendered terminal Knowledge Base preserves the regression handoff envelope should pass but got: responsibility-evidence-missing`.

Root cause: the synthetic handoff fixture carried fields that the real `kb-entry.md` producer omitted. Minimal GREEN added canonical ordinal `Master Scope Context`, exact `Delivery Adapter Kind`, adapter-aware `Task Provenance`, conditional `Selected Migration Unit`, and exact v1 responsibility handoff to the actual KB template and terminal producer rules. The same command then exited `0`, including the real-template positive plus loss, mutation, wrong-adapter, cross-scope, and provenance negatives.

### I1 - independent Verification Ownership source

RED command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-conformance.Tests.ps1
```

Exit `1`: `review rejects missing verification evidence path expected verification-production-binding-missing but got:` no diagnostic.

Root cause: review matched planned and implementation Verification Ownership rows but never loaded their evidence path/scenario. Minimal GREEN resolves each path with `git show <final-tree>:<path>`, locates exactly the named scenario, verifies exact owner/responsibility/capability/evidence-kind/disposition/production path-symbol markers, and binds `production-composition` to the exact route/provider line in pinned production source. An unchanged verification file is accepted from final-tree source without a fabricated diff. Missing path/scenario, foreign owner, stale scenario, self-attestation, fake registry, and fake provider all reject.

The first final-gate attempt also exposed two integration RCAs. A one-element regex collection was scalar-unwrapped under strict mode; storing its explicit integer count fixed the implementation without weakening checks. Then `architecture-review.Tests.ps1` correctly failed because its positive pinned-source producer had no verification source; its base tree now contains the real canonical scenario, with the incremental provider variant updated in the same final tree. Focused architecture review then exited `0`.

### I2 - canonical not-applicable-approved eligibility

RED used the responsibility-conformance command above and exited `1`: `config-looking path cannot authorize not-applicable-approved expected verification-disposition-invalid but got:` no diagnostic.

Root cause: design and implementation used different prose/path substring heuristics. Minimal GREEN introduces one shared structured predicate requiring exact canonical `Boundary Kind=config`, `Evidence Kind=static-structure|generator-verification`, `Verification Disposition=not-applicable-approved`, `External Effects=none`, and exact Tech Lead/owner approval tied to the production responsibility suffix. Legal config, manifest, generated, schema, and build-wiring positives pass; behavior, routing, lifecycle, effect, destructive, composition, path-looking, effectful, wrong-kind, foreign, malformed, and free-form approval negatives reject. The former `administer build wiring` design/implementation divergence now passes both validators through the same helper.

### I3 - generic Parent Selector

RED command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\scope-artifacts.Tests.ps1
```

Exit `1` with six exact failures showing missing, foreign, mismatched, missing-parent, duplicate-identity, and reordered parent authority was accepted or only incidentally syntax-rejected. Minimal GREEN builds the complete ordered selector map, requires unique external selector identities, resolves the exact parent Work Item selector, preserves the root/`none` `not-applicable` sentinel, and requires parent-before-child ordering. `responsibility-handoff.Tests.ps1` first reproduced the downstream missing-parent-selector acceptance, then passed the same whole-plan positive and negative set after the downstream validator fix.

### Final pre-amend verification

Affected suites after the last source edit:

- `responsibility-conformance.Tests.ps1`: exit `0`, `PASS: responsibility conformance contract`.
- `responsibility-handoff.Tests.ps1`: exit `0`, `PASS: responsibility handoff scenarios`.
- `scope-artifacts.Tests.ps1`: exit `0`, `PASS: scope artifact scenarios`.
- `architecture-review.Tests.ps1`: exit `0`, `PASS: architecture review scenarios`.
- PowerShell AST parsing of all five changed scripts: exit `0`, five `PARSE PASS` lines.

All 13 Task 9 Step-4 gates were restarted after the final source edit and exited `0`: responsibility conformance; responsibility handoff; target conformance; structural gate (`151 scenarios`); architecture review; scope engine; flexible-scope E2E (`21 isolated E2E scenarios`); `Contracts`; `Skills`; `Templates`; `All`; `SourceIntegrityOnly`; and `git diff --check`.

Focused command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.Tests.ps1 -ResponsibilityConformanceOnly
```

Exit `0`; all 17 isolated mutations passed, final `PASS: responsibility conformance mutation scenarios`, unchanged source digest `D4242A550707837DF91D960318FEAD153634215691DC7AF2B91AF6DBD9D72C50`.

The default/full `validate-migration-framework.Tests.ps1` suite was deliberately not run.

### Cycle 3 staged audit, amend, and exact-HEAD completion

The staged-scope audit contained exactly the 11 approved cycle-3 files listed above, no extras or omissions, and no unstaged project changes. Cached diff was `440 insertions(+), 18 deletions(-)`; `git diff --cached --check` exited `0`; the pre-amend Task 9 commit count from `0cbb95afb835263ecf3b52b36f5ec0605f903435` remained `1`. The ignored report was not staged.

`git commit --amend --no-edit` produced `5cf9c54cf8a5a3038e3e0aa63d87b15220927877 test: cover responsibility conformance workflow`; no second commit was created. The sole cumulative Task 9 commit now contains 32 files.

On exact HEAD `5cf9c54cf8a5a3038e3e0aa63d87b15220927877`:

- `validate-migration-framework.Tests.ps1 -ResponsibilityConformanceOnly` exited `0`; all 17 isolated mutations passed, final `PASS: responsibility conformance mutation scenarios`, unchanged digest `D4242A550707837DF91D960318FEAD153634215691DC7AF2B91AF6DBD9D72C50`.
- `validate-migration-framework.ps1 -Check All` exited `0`: `PASS: migration framework (All)`.
- `validate-migration-framework.ps1 -Check SourceIntegrityOnly` exited `0`: `PASS: migration framework (SourceIntegrityOnly)`.
- `git diff --check HEAD^ HEAD` exited `0` with no diagnostics.
- `git rev-list --count 0cbb95afb835263ecf3b52b36f5ec0605f903435..HEAD` returned `1`.
- `git diff --name-only HEAD^ HEAD | Measure-Object` returned `32` cumulative Task 9 files.
- `git status --porcelain=v1 --untracked-files=all` produced no output; the linked worktree is clean. The ignored report update does not alter repository status.

The default/full mutation suite was not run. No Phase 2 work, `main/`, or `issue/` change was made. Final scoped status: all four cycle-3 breaker findings are fixed with producer-realistic and whole-plan prevention tests; automated remediation remains pending Phase 2 and the original issue remains partially resolved.

## User-approved breaker exception cycle 4

Date: 2026-08-22

This exception wave started from clean Task 9 HEAD `5cf9c54cf8a5a3038e3e0aa63d87b15220927877` over base `0cbb95afb835263ecf3b52b36f5ec0605f903435`. It remains a single Task 9 commit and is amended in place. Scope is limited to:

- `aitoolkit/tests/scenarios/flexible-scope-e2e.Tests.ps1`
- `aitoolkit/tests/scenarios/responsibility-handoff.Tests.ps1`
- `aitoolkit/tests/scenarios/scope-artifacts.Tests.ps1`
- `aitoolkit/tests/validation/responsibility-conformance.validation.ps1`

### Finding verification and root cause

1. The real Knowledge Base producer template has the canonical terminal envelope `Master Scope Context` -> `Task Provenance` -> conditional `Selected Migration Unit` -> `Architecture Responsibility Handoff`, with the exact delivery-adapter line between master scope and provenance. The validator already checked heading cardinality, but not ordinal placement. Therefore a reordered envelope could pass, and the real renderer's generic/none selected-unit omission was not covered.
2. The scope validator fully validated selector rows, but downstream handoff validation only fully validated the selected child. Referenced generic parents were checked for plan relations without independently validating selector identity, adapter kind, external identity/sentinel, authority, positive authority revision, and approval reference. A self-consistent malformed or stale parent could therefore pass downstream validation.
3. Scope selector sets/maps already used `StringComparer.Ordinal`. Downstream handoff sets did too, but four identity maps used ordinary PowerShell hashtables, whose lookup is case-insensitive on Windows PowerShell 5.1. Case-distinct canonical selector identities could collide and case-only references could bind accidentally.

### RED evidence

- After adding real-renderer Knowledge Base positives for migration-unit/generic/none and negatives for retained/missing selected units plus reordered/duplicate envelope sections, `responsibility-handoff.Tests.ps1` exited `1` at `producer-rendered terminal Knowledge Base rejects reordered canonical envelope sections expected responsibility-evidence-missing but got:`.
- Scope parent-row negatives were already green at the authoritative scope validator. The equivalent downstream cases produced the intended RED: `responsibility-handoff.Tests.ps1` exited `1` at `generic child handoff rejects an unsupported parent adapter kind expected responsibility-evidence-missing but got:`.
- The ordinal tests produced the intended split: `scope-artifacts.Tests.ps1` exited `0`, while `responsibility-handoff.Tests.ps1` exited `1` at `generic child handoff preserves case-only distinct canonical selector identities should pass but got: responsibility-evidence-missing`.

### Minimal GREEN changes

- Terminal Knowledge Base validation now enforces canonical section order and exact conditional cardinality at the authoritative handoff seam. Migration-unit renderings preserve exactly one ordinal `Selected Migration Unit`; generic/none renderings omit it. Existing exact checks for Master Scope Context, Delivery Adapter Kind, Task Provenance, and the v1 handoff block remain enforced.
- Downstream selector validation now validates every canonical row, including referenced generic parents, for exact selector identity, adapter kind, external ID/sentinel, authority, positive authority revision, resolved approval reference, canonical parent/decomposition fields, exact work-item binding, and parent-before-child order. Missing, foreign, duplicate, stale, and mismatched parents fail; root/none sentinels remain valid.
- All downstream selector identity maps now use PS5.1-compatible generic dictionaries constructed with `[StringComparer]::Ordinal`; the scoped audit found no remaining ordinary selector identity maps. Tests prove case-only distinct canonical IDs are allowed, case-only mismatches do not bind, and exact duplicate identity is rejected.
- The first post-change flexible E2E run exposed a producer-realism regression in its local downstream-artifact fixture: it emitted the handoff block before the selected-unit block. The fixture was corrected to match the real canonical producer. Focused `S05` and `S20` then both exited `0` before the complete Step 4 rerun.

### Pre-amend verification

All commands below were run after the last source edit and exited `0`:

- `responsibility-conformance.Tests.ps1`: `PASS: responsibility conformance contract`
- `responsibility-handoff.Tests.ps1`: `PASS: responsibility handoff scenarios`
- `target-conformance.Tests.ps1`: `PASS: target conformance scenarios`
- `structural-gate.Tests.ps1`: `PASS: structural gate (151 scenarios)`
- `architecture-review.Tests.ps1`: `PASS: architecture review scenarios`
- `scope-engine.Tests.ps1`: `PASS: scope engine behavioral scenarios`
- `flexible-scope-e2e.Tests.ps1`: `PASS: flexible migration scope orchestration (21 isolated E2E scenarios)`
- `validate-migration-framework.ps1 -Check Contracts`: `PASS: migration framework (Contracts)`
- `validate-migration-framework.ps1 -Check Skills`: `PASS: migration framework (Skills)`
- `validate-migration-framework.ps1 -Check Templates`: `PASS: migration framework (Templates)`
- `validate-migration-framework.ps1 -Check All`: `PASS: migration framework (All)`
- `validate-migration-framework.ps1 -Check SourceIntegrityOnly`: `PASS: migration framework (SourceIntegrityOnly)`
- `git diff --check`: no diagnostics (only Git line-ending notices)
- `scope-artifacts.Tests.ps1`: `PASS: scope artifact scenarios`
- PowerShell parser audit of all four changed scripts: no parse errors
- Focused selector `validate-migration-framework.Tests.ps1 -ResponsibilityConformanceOnly`: `PASS: responsibility conformance mutation scenarios`; all 17 mutations passed; digest `3C35219E896F8A9CE1045FA773D037AC38810D3A7CAA127942EB867D30247E87`

The default/full mutation suite was not run. No Phase 2 work, `main/`, or `issue/` change was made.

### Exact-HEAD completion

The sole Task 9 commit was amended to `5f0a42178ebb8b28772afa43eb4d4ce5f7db5725` (`test: cover responsibility conformance workflow`). Fresh verification against that exact commit produced:

- Focused `-ResponsibilityConformanceOnly`: exit `0`; all 17 mutations passed; digest `3C35219E896F8A9CE1045FA773D037AC38810D3A7CAA127942EB867D30247E87`.
- `validate-migration-framework.ps1 -Check All`: exit `0`, `PASS: migration framework (All)`.
- `validate-migration-framework.ps1 -Check SourceIntegrityOnly`: exit `0`, `PASS: migration framework (SourceIntegrityOnly)`.
- `git diff --check HEAD^ HEAD`: exit `0`, no diagnostics.
- `git rev-list --count 0cbb95afb835263ecf3b52b36f5ec0605f903435..HEAD`: `1`.
- `git diff --name-only HEAD^ HEAD | Measure-Object`: `32` cumulative Task 9 files; the four cycle-4 files are present in the amended commit.
- `git status --porcelain=v1 --untracked-files=all`: no output; the linked worktree is clean. The ignored report update does not alter repository status.

The default/full mutation suite was not run. No Phase 2 work, `main/`, or `issue/` change was made. Final scoped status: all three cycle-4 findings are fixed and covered at the authoritative producer/validator seams; automated remediation remains pending Phase 2 and the original issue remains partially resolved.

## User-approved breaker exception cycle 5

Date: 2026-08-22  
Starting exact HEAD: `5f0a42178ebb8b28772afa43eb4d4ce5f7db5725`  
Final amended HEAD: `e80ca585f6cc9b1dedf6bc988b0fc984225a1f8e`  
Commit policy: the same sole Task 9 commit was amended in place; no second commit was created.

### Finding verification and root cause

The authoritative `templates/kb-entry.md` producer places the canonical terminal envelope as one H2 block: `Master Scope Context` -> `Task Provenance` -> conditional `Selected Migration Unit` -> `Architecture Responsibility Handoff`. The `knowledge-base` skill requires this exact adapter-aware order. Real Knowledge Base sections such as `Tóm tắt run` and `Xác minh đầu cuối` are valid outside that block, and H3/body content remains valid within its sections.

The step-15 validator already enforced exact cardinality for `Master Scope Context`, `Task Provenance`, `Architecture Responsibility Handoff`, and adapter-aware `Selected Migration Unit`. Its order check compared only the character index of each canonical heading, so any unrelated H2 could interleave two canonical slots while the required headings still appeared once and in relative order. This was the single confirmed root cause.

Exactly these two project files changed in cycle 5:

- `aitoolkit/tests/scenarios/responsibility-handoff.Tests.ps1`
- `aitoolkit/tests/validation/responsibility-conformance.validation.ps1`

No template, skill, contract, Phase 2, `main/`, `issue/`, or unrelated file changed.

### Strict TDD RED evidence

The scenario test was changed before production validation. It renders the real UTF-8 `kb-entry.md` template for `migration-unit`, generic `task`, and `none`, then converts each rendering independently to LF and CRLF. The two actual post-envelope producer sections are discovered from that rendered template rather than fabricated or hard-coded in an encoding-sensitive PowerShell source file.

The first test invocation exposed only a Windows PowerShell 5.1 source-encoding parser error from newly hard-coded Vietnamese literals. The test harness was corrected to discover those headings from the UTF-8 template at runtime; production code was still unchanged. The valid RED command was then:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-handoff.Tests.ps1
```

It exited `1`. Under both LF and CRLF, the current validator accepted every real-section interleaving with no diagnostic:

- `Tóm tắt run` and `Xác minh đầu cuối` separately between `Master Scope Context` and `Task Provenance` for all three adapter shapes;
- both real H2 sections separately between `Task Provenance` and `Selected Migration Unit` for `migration-unit`;
- both real H2 sections separately between `Selected Migration Unit` and `Architecture Responsibility Handoff` for `migration-unit`;
- both real H2 sections separately between `Task Provenance` and `Architecture Responsibility Handoff` for generic and `none`.

All 28 invalid interleavings reported `expected responsibility-evidence-missing but got:` with an empty diagnostic set. In the same RED run, canonical positives and positives with an actual surrounding H2 before and remaining actual H2 sections after the envelope passed; an H3 plus ordinary body text inside the envelope also passed. Heading-line-only duplicate/missing mutations for every required canonical heading and every adapter/EOL shape were already rejected, confirming the gap was contiguity rather than cardinality.

### Minimal GREEN

The step-15-only order check now parses exact line-start `## ` headings, locates the unique `Master Scope Context`, and compares the adapter-derived canonical heading array with the same-length contiguous H2 slice. `migration-unit` requires exactly one `Selected Migration Unit` in its canonical slot; generic and `none` omit it. Existing global cardinality, adapter-line placement, table, provenance, scope, and responsibility checks remain unchanged.

The parser does not require the envelope to be the first or final H2 block. It therefore accepts valid real producer sections before and after the block and ignores H3/subheading and ordinary body content. The affected scenario then exited `0` with every LF/CRLF positive, all 28 interleaving negatives, every heading-only duplicate/missing negative, and terminal `PASS: responsibility handoff scenarios`.

### Final pre-amend verification

After the final test precision edit, all 13 Task 9 Step-4 gates were restarted against the exact candidate tree and exited `0`:

- `responsibility-conformance.Tests.ps1`: `PASS: responsibility conformance contract`
- `responsibility-handoff.Tests.ps1`: `PASS: responsibility handoff scenarios`
- `target-conformance.Tests.ps1`: `PASS: target conformance scenarios`
- `structural-gate.Tests.ps1`: `PASS: structural gate (151 scenarios)`
- `architecture-review.Tests.ps1`: `PASS: architecture review scenarios`
- `scope-engine.Tests.ps1`: `PASS: scope engine behavioral scenarios`
- `flexible-scope-e2e.Tests.ps1`: `PASS: flexible migration scope orchestration (21 isolated E2E scenarios)`
- `Contracts`, `Skills`, `Templates`, `All`, and `SourceIntegrityOnly`: each reported its canonical framework PASS line
- `git diff --check`: exit `0`; only informational LF-to-CRLF working-copy notices were emitted

Both changed PowerShell files passed AST parsing. The focused `-ResponsibilityConformanceOnly` selector then exited `0`; all 17 isolated mutations passed with unchanged source digest `14CE0C32B8CA573C1F895BAA5931DAF9D33616354DB730F6D102EC4E725AAC28` and terminal `PASS: responsibility conformance mutation scenarios`.

### Staged audit, amend, and exact-HEAD evidence

The staged-scope audit contained exactly the two approved files above, no unstaged project files, and no file under Phase 2, `main/`, or `issue/`. `git diff --cached --check` exited `0`; the cycle-5 cached delta was `2 files changed, 112 insertions(+), 7 deletions(-)`. The pre-amend count from Task 9 base `0cbb95afb835263ecf3b52b36f5ec0605f903435` remained `1`.

`git commit --amend --no-edit` produced `e80ca585f6cc9b1dedf6bc988b0fc984225a1f8e` (`test: cover responsibility conformance workflow`). On that exact HEAD:

- focused `-ResponsibilityConformanceOnly`: exit `0`, all 17 mutations PASS, digest `14CE0C32B8CA573C1F895BAA5931DAF9D33616354DB730F6D102EC4E725AAC28`;
- `validate-migration-framework.ps1 -Check All`: exit `0`, `PASS: migration framework (All)`;
- `validate-migration-framework.ps1 -Check SourceIntegrityOnly`: exit `0`, `PASS: migration framework (SourceIntegrityOnly)`;
- `git diff --check HEAD^ HEAD`: exit `0`;
- `git status --porcelain=v1 --untracked-files=all`: no output;
- `git rev-list --count 0cbb95afb835263ecf3b52b36f5ec0605f903435..HEAD`: `1`;
- cumulative Task 9 file count: `32`;
- HEAD remained exactly `e80ca585f6cc9b1dedf6bc988b0fc984225a1f8e` throughout verification.

The default/full `validate-migration-framework.Tests.ps1` suite was not run. No Phase 2, `main/`, or `issue/` change was made. The one cycle-5 Important finding is fixed with real-producer, adapter-aware, LF/CRLF prevention coverage; automated remediation remains pending Phase 2 and the original issue remains partially resolved.

## User-approved breaker exception cycle 6

Date: 2026-08-24  
Starting exact HEAD: `e80ca585f6cc9b1dedf6bc988b0fc984225a1f8e`  
Final amended HEAD: `8b0b73dd01d0dd2815118377d26f85e0ca11fcef`  
Commit policy: amend the same sole Task 9 commit; do not create a second commit.

### Finding verification and root cause

The shared `Get-ArcStrictMarkdownTable` helper accepted the first exact canonical H2 it found and returned that table without first proving that the heading occurred exactly once. A later duplicate, including a conflicting or malformed second copy, could therefore be ignored. The audited call sites are artifact-level canonical tables. Implementation and review documents are passed separately, so legitimate same-named headings in those two bounded inputs remain separately scoped. `Delivery Adapter Kind` remains a line representation with its existing exact-count check, and conditional `Selected Migration Unit` retains its adapter-aware check.

Exactly these two project files changed in cycle 6:

- `aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1`
- `aitoolkit/tests/validation/responsibility-conformance.validation.ps1`

No template, skill, contract, Phase 2, `main/`, `issue/`, or unrelated project file changed.

### Strict TDD RED and minimal GREEN

The scenario was changed before production validation. The valid unmodified-production RED command was:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-conformance.Tests.ps1
```

It exited `1`: a duplicate `Planned File Tree` placed before the canonical section was accepted, so the expected stable `ARC-CONTRACT-HEADING-CARDINALITY: Planned File Tree` diagnostic was absent. The initial ordering of new tests first exposed the known first-match behavior through the fenced-code positive; duplicate coverage was placed first to make the causal RED explicit before production changed.

The minimal shared repair scans exact external H2 heading lines, ignores fenced Markdown code blocks, requires exactly one canonical heading, and returns no content when cardinality is not one. Missing headings keep the existing `ARC-CONTRACT-MISSING-TABLE` diagnostic; duplicates use the stable `ARC-CONTRACT-HEADING-CARDINALITY: <heading>` diagnostic. The first GREEN attempt exposed a Windows PowerShell 5.1 variable collision because `$matches` and automatic `$Matches` are case-insensitive aliases; renaming the collection to `$headingMatches` resolved that implementation defect without broadening scope.

Coverage proves LF and CRLF behavior for canonical singles, exact duplicates before and after, malformed second copies, and non-H2 prose/H3/blockquote/fenced examples. It covers design `Planned File Tree`; review `Master Scope Context`, `Task Provenance`, `Architecture Responsibility Handoff`, and `Responsibility Review Evidence`; a conflicting second `Responsibility Review Evidence`; line-form `Delivery Adapter Kind`; and conditional `Selected Migration Unit`.

### Accidental full invocation and fresh authorization

One command was incorrectly invoked in session `13651`:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File aitoolkit/tests/validate-migration-framework.Tests.ps1 -ContractsOnly
```

`validate-migration-framework.Tests.ps1` does not declare `-ContractsOnly`, so the argument was unbound and the harness fell through to its default/full path. After corrected scenario gates 1-7 had passed, that accidental invocation exited `1` in unrelated Activation Slice contract clusters: assurance-provenance `Delivery Adapter Kind`, activation-blocking lifecycle, downstream handoff lineage, selected-unit provenance, and migration-template result-set assertions. The run was not restarted. Source remained at the two unstaged cycle-6 files, amend was frozen, and a process audit confirmed no surviving validation process.

The user then explicitly authorized continuation from the preserved candidate. The corrected gate contract uses the seven scenario scripts, followed by the main `validate-migration-framework.ps1 -Check Contracts`, `Skills`, `Templates`, `All`, and `SourceIntegrityOnly` checks, then `git diff --check`. Only the focused `validate-migration-framework.Tests.ps1 -ResponsibilityConformanceOnly` selector is authorized; no further unselected/default/full invocation was made.

### Corrected pre-amend verification

After the final source edit, the focused duplicate-heading scenario exited `0`. All 13 corrected Step-4 gates then passed:

- `responsibility-conformance.Tests.ps1`: `PASS: responsibility conformance contract`
- `responsibility-handoff.Tests.ps1`: `PASS: responsibility handoff scenarios`
- `target-conformance.Tests.ps1`: `PASS: target conformance scenarios`
- `structural-gate.Tests.ps1`: `PASS: structural gate (151 scenarios)`
- `architecture-review.Tests.ps1`: `PASS: architecture review scenarios`
- `scope-engine.Tests.ps1`: `PASS: scope engine behavioral scenarios`
- `flexible-scope-e2e.Tests.ps1`: `PASS: flexible migration scope orchestration (21 isolated E2E scenarios)`
- `validate-migration-framework.ps1 -Check Contracts`: `PASS: migration framework (Contracts)`
- `validate-migration-framework.ps1 -Check Skills`: `PASS: migration framework (Skills)`
- `validate-migration-framework.ps1 -Check Templates`: `PASS: migration framework (Templates)`
- `validate-migration-framework.ps1 -Check All`: `PASS: migration framework (All)`
- `validate-migration-framework.ps1 -Check SourceIntegrityOnly`: `PASS: migration framework (SourceIntegrityOnly)`
- direct `git diff --check`: exit `0`; only informational LF-to-CRLF working-copy notices were emitted. The first wrapper promoted those stderr notices to a PowerShell terminating error before reading Git's exit code; the exact direct command established the authoritative gate result.

The focused `-ResponsibilityConformanceOnly` selector then exited `0`; all 17 isolated mutations passed with unchanged source digest `8FAC5C405EF5664669E7F1C50F925DAB343E5C05E0765CDD1235E8D721B21F93` and terminal `PASS: responsibility conformance mutation scenarios`.

### Staged audit, amend, and exact-HEAD evidence

The staged-scope audit contained exactly the two approved cycle-6 files, no unstaged project files, and no file under Phase 2, `main/`, or `issue/`. Both PowerShell files passed AST parsing. `git diff --cached --check` exited `0`; the cycle-6 cached delta was `2 files changed, 179 insertions(+), 3 deletions(-)`. The pre-amend count from Task 9 base `0cbb95afb835263ecf3b52b36f5ec0605f903435` remained `1`.

`git commit --amend --no-edit` produced `8b0b73dd01d0dd2815118377d26f85e0ca11fcef` (`test: cover responsibility conformance workflow`). On that exact HEAD:

- focused `-ResponsibilityConformanceOnly`: exit `0`, all 17 mutations PASS, digest `8FAC5C405EF5664669E7F1C50F925DAB343E5C05E0765CDD1235E8D721B21F93`;
- `validate-migration-framework.ps1 -Check All`: exit `0`, `PASS: migration framework (All)`;
- `validate-migration-framework.ps1 -Check SourceIntegrityOnly`: exit `0`, `PASS: migration framework (SourceIntegrityOnly)`;
- `git diff --check HEAD^ HEAD`: exit `0`;
- `git status --porcelain=v1 --untracked-files=all`: no output;
- `git rev-list --count 0cbb95afb835263ecf3b52b36f5ec0605f903435..HEAD`: `1`;
- cumulative Task 9 file count: `32`;
- HEAD remained exactly `8b0b73dd01d0dd2815118377d26f85e0ca11fcef` throughout verification.

No further unselected/default/full invocation was made after the fresh authorization. No Phase 2, `main/`, or `issue/` change was made. The cycle-6 Important finding is fixed with exact heading-cardinality enforcement and scoped LF/CRLF prevention coverage; automated remediation remains pending Phase 2 and the original issue remains partially resolved.

## User-approved breaker exception cycle 7

Date: 2026-08-24  
Starting exact HEAD: `8b0b73dd01d0dd2815118377d26f85e0ca11fcef`  
Commit policy: amend the same sole Task 9 commit; do not create a second commit.

### Authorization and preserved safety history

The user authorized exactly four Important corrections: HTML-comment exclusion in shared Markdown heading/table parsing; CommonMark-compatible backtick fence opener semantics; shared visible-H2/cardinality handling for conditional `Selected Migration Unit` at the implementation, review, and handoff paths; and deterministic structural diagnostics with stage-level early return instead of generic evidence-error cascades. The two review Minors were to be recorded unless they could be resolved mechanically.

The cycle-6 accidental-full history remains part of the authorization record. In cycle 6, the unsupported `-ContractsOnly` argument was passed to `validate-migration-framework.Tests.ps1`, fell through to the default/full suite, and stopped on unrelated Activation Slice failures. Work was frozen and the user explicitly reauthorized continuation with the corrected 13-command Step-4 contract plus only the focused `-ResponsibilityConformanceOnly` mutation selector. Cycle 7 did not invoke the unselected/default/full suite. It used only the seven named scenario scripts, the five named `validate-migration-framework.ps1 -Check` modes, `git diff --check`, and the explicitly authorized focused mutation selector.

### Verification and root causes

All four findings were verified against the exact starting tree before implementation:

1. `Get-ArcMarkdownH2HeadingMatches` tracked fenced blocks but not single-line or multiline HTML comments. `Get-ArcStrictMarkdownTable` then sliced the original unfiltered text. A commented canonical H2 inflated heading cardinality, while a comment-only canonical H2/table could satisfy the parser or contribute table content.
2. The fence opener accepted arbitrary text after a backtick run. An info string containing a backtick was therefore treated as a valid backtick fence and could hide a later real canonical heading or duplicate. The existing closer correctly required the same marker, at least the opener length, no more than three leading spaces, and a whitespace-only tail.
3. Implementation, review, and handoff each retained raw regex counts for conditional `Selected Migration Unit`. Those counts disagreed with the shared parser, so fenced/commented examples could be counted even when the table parser ignored them.
4. Structural duplicate/missing errors were followed by generic responsibility errors in design, plan, implementation, review provenance, and handoff consumers. For example, duplicate `Master Scope Context` produced `ARC-CONTRACT-HEADING-CARDINALITY: Master Scope Context` plus `responsibility-evidence-missing`; missing or duplicate `Change Hygiene` could similarly cascade through review provenance.

Review of the initial repairs exposed related same-root defects before commit: comment deletion could assemble an H2/fence marker or move H2/table markers to column zero; a multiline-comment continuation line could incorrectly authorize an exposed marker; contract-schema table loss could cascade into enum errors; a shared global error list could make valid `Change Hygiene` provenance look absent; and the Knowledge Base envelope still compared raw heading text after comment removal. Each was reproduced before its correction and kept within the approved shared-parser/structural-diagnostic scope.

### Strict RED-to-GREEN evidence

Tests were added before each production correction. Representative valid RED observations were:

- a commented `Planned File Tree` duplicate returned `ARC-CONTRACT-HEADING-CARDINALITY: Planned File Tree`;
- an invalid backtick info string hid a later real heading/duplicate;
- a fenced implementation `Selected Migration Unit` example returned `responsibility-evidence-missing`;
- duplicate `Master Scope Context` returned the canonical cardinality diagnostic followed by generic `responsibility-evidence-missing`;
- a comment-prefixed fake table was parsed as canonical content and returned `responsibility-owner-missing`;
- the multiline continuation fixture returned `ARC-CONTRACT-MALFORMED-TABLE: Planned File Tree` because a hidden raw marker incorrectly authorized a later exposed marker.

The shared parser now:

- recognizes a fence only from the raw line, rejects backtick openers whose info string contains any backtick, permits backticks in tilde-fence info, and preserves the existing strict closer rules;
- projects fenced content and statefully removes single-line/multiline HTML comments while retaining every LF/CRLF line boundary;
- normalizes ASCII whitespace between canonical heading tokens after comment removal;
- records raw structural-marker provenance so comment removal cannot assemble a fence/H2 marker or move an H2/table marker to column zero, including on lines that begin inside a multiline comment;
- makes strict-table extraction consume the same visible projection as heading cardinality.

Implementation, review, and handoff conditional `Selected Migration Unit` validation now use the shared visible-H2/cardinality/table helpers. Real missing/duplicate sections are rejected, fenced/commented examples are ignored, and generic/`none` adapters still reject a real Selected section while ignoring hidden examples. Structural table/heading phases now return their exact ordered diagnostics before legacy semantic checks can add same-root generic evidence errors. The contract schema, design, plan, implementation, review, `Change Hygiene` provenance, handoff, and Knowledge Base envelope consumers were aligned with that rule.

Coverage is case-sensitive and exact for diagnostic count and order. LF and CRLF matrices cover single-line/multiline comments, comment-only canonical sections, inline heading/table comments, line-boundary preservation, marker assembly/origin, valid three/four/five-character backtick and tilde fences, longer/shorter/malformed/wrong-marker closers, invalid backtick info, canonical and missing/duplicate/malformed headings/tables, `Responsibility Review Evidence`, design `Planned File Tree`, and conditional Selected sections across implementation/review/handoff.

The two review Minors were mechanically resolved:

- the `Delivery Adapter Kind` before/after mutations now insert genuinely distinct one-space-indented lines on opposite sides of the canonical line;
- malformed/conflicting section copies now run both before and after the canonical section, with alter-or-fail fixture helpers preventing silent no-op mutations.

Exactly these six project files changed in cycle 7:

- `aitoolkit/tests/validation/responsibility-conformance.validation.ps1`
- `aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1`
- `aitoolkit/tests/scenarios/responsibility-handoff.Tests.ps1`
- `aitoolkit/tests/scenarios/architecture-review.Tests.ps1`
- `aitoolkit/tests/validate-migration-framework.Tests.ps1`
- `aitoolkit/tests/validate-migration-framework.ps1`

The last three contain only affected exact-diagnostic/mutation/source-integrity expectation updates required by the changed structural contract. No template, skill, canonical contract, Phase 2, `main/`, `issue/`, or unrelated project file changed.

### Deferred review notes outside the approved cycle-7 paths

`tests/validation/structural-gate.validation.ps1` and an independent parser in `tests/validate-migration-framework.ps1` retain their own raw Selected-heading/section parsing. They are outside the explicitly approved responsibility implementation/review/handoff paths and were not changed. The structural-gate suite still passed all 151 scenarios. This is recorded as a follow-up rather than silently expanding the breaker exception.

### Final no-edit pre-amend verification

After all source and affected expectation edits, the complete corrected 13-command Step-4 sequence was restarted on one no-edit candidate. Every command exited `0`:

- `responsibility-conformance.Tests.ps1`: `PASS: responsibility conformance contract`
- `responsibility-handoff.Tests.ps1`: `PASS: responsibility handoff scenarios`
- `target-conformance.Tests.ps1`: `PASS: target conformance scenarios`
- `structural-gate.Tests.ps1`: `PASS: structural gate (151 scenarios)`
- `architecture-review.Tests.ps1`: `PASS: architecture review scenarios`
- `scope-engine.Tests.ps1`: `PASS: scope engine behavioral scenarios`
- `flexible-scope-e2e.Tests.ps1`: `PASS: flexible migration scope orchestration (21 isolated E2E scenarios)`
- `validate-migration-framework.ps1 -Check Contracts`: `PASS: migration framework (Contracts)`
- `validate-migration-framework.ps1 -Check Skills`: `PASS: migration framework (Skills)`
- `validate-migration-framework.ps1 -Check Templates`: `PASS: migration framework (Templates)`
- `validate-migration-framework.ps1 -Check All`: `PASS: migration framework (All)`
- `validate-migration-framework.ps1 -Check SourceIntegrityOnly`: `PASS: migration framework (SourceIntegrityOnly)`
- `git diff --check`: exit `0`; only informational LF-to-CRLF working-copy notices were emitted.

All six changed PowerShell files passed AST parsing. The focused `validate-migration-framework.Tests.ps1 -ResponsibilityConformanceOnly` selector was then rerun without edits and exited `0`; all 17 isolated mutations passed with source digest `8649BC458D45ABBEB22BE0BD489A6C677D932C8481414EEAFFA373B39FDB9F6B` and terminal `PASS: responsibility conformance mutation scenarios`.

No unselected/default/full mutation-suite invocation occurred in cycle 7.

### Staged audit, amend, and exact-HEAD evidence

The cached-scope audit contained exactly the six cycle-7 files listed above, with no unstaged project diff. `git diff --cached --check` exited `0`; the cycle-7 cached delta was `6 files changed, 518 insertions(+), 119 deletions(-)`. All six scripts passed PowerShell AST parsing, and the pre-amend count from Task 9 base `0cbb95afb835263ecf3b52b36f5ec0605f903435` remained `1`.

`git commit --amend --no-edit` produced `0a703bcc9812510643076ae3143713478ef4b873` (`test: cover responsibility conformance workflow`). Fresh verification on that exact HEAD produced:

- `responsibility-conformance.Tests.ps1`: exit `0`, `PASS: responsibility conformance contract`;
- `responsibility-handoff.Tests.ps1`: exit `0`, `PASS: responsibility handoff scenarios`;
- focused `-ResponsibilityConformanceOnly`: exit `0`, all 17 mutations PASS, digest `8649BC458D45ABBEB22BE0BD489A6C677D932C8481414EEAFFA373B39FDB9F6B`;
- `validate-migration-framework.ps1 -Check All`: exit `0`, `PASS: migration framework (All)`;
- `validate-migration-framework.ps1 -Check SourceIntegrityOnly`: exit `0`, `PASS: migration framework (SourceIntegrityOnly)`;
- `git diff --check HEAD^ HEAD`: exit `0`, no diagnostics;
- `git status --porcelain=v1 --untracked-files=all`: no output;
- `git rev-list --count 0cbb95afb835263ecf3b52b36f5ec0605f903435..HEAD`: `1`;
- cumulative Task 9 file count: `32`;
- `git diff --name-only 8b0b73dd01d0dd2815118377d26f85e0ca11fcef HEAD`: exactly the six audited cycle-7 files;
- HEAD remained exactly `0a703bcc9812510643076ae3143713478ef4b873` throughout the final verification.

No unselected/default/full suite was run in cycle 7. No Phase 2, `main/`, or `issue/` change was made. Scoped review found no remaining blocker in the approved implementation/review/handoff paths. The separate structural-gate/main-validator raw-parser sites remain explicitly deferred rather than being changed outside authorization.

## 2026-08-25 — breaker exception cycle 8: inline-code-safe visible Markdown comments

The approved cycle began from exact clean HEAD `0a703bcc9812510643076ae3143713478ef4b873` with Task 9 base `0cbb95afb835263ecf3b52b36f5ec0605f903435` and exactly one commit in `BASE..HEAD`. The remaining Important finding was verified before implementation: the visible-Markdown projection treated HTML-comment delimiters inside CommonMark code spans as parser state and treated every line-start backtick run of length three or more as a block boundary even when the existing fence parser rejected that line.

### Root cause and strict RED→GREEN evidence

`Get-ArcVisibleMarkdownText` searched raw lines for `<!--` and `-->` without tracking inline code spans. Its canonical `-->` search also did not recognize the valid compact CommonMark comment forms `<!-->` and `<!--->`. The first multiline implementation used a duplicated fence-like boundary regex; unlike `Get-ArcMarkdownFenceOpening`, that regex did not reject a backtick fence whose info string contains a backtick.

Three strict failing-test checkpoints preceded their corresponding source edits:

- RED 1: `responsibility-conformance.Tests.ps1` exited `1` with `inline-code HTML comment delimiters must leave both Probe headings visible (LF); got 1`.
- RED 2: after adding multiline coverage, it exited `1` with `multiline inline-code delimiters must leave duplicate Probe tables unparsed (LF); got 3 row(s)`.
- RED 3: after independent review found the fence-validity interaction, it exited `1` with `an invalid backtick fence inside multiline inline code must not hide the duplicate Probe table (LF); got 3 row(s)`.

The final implementation tracks exact-length maximal backtick runs, accepts only an equal-length closing run, protects matched same-line and multiline code spans from HTML-comment state, leaves unmatched runs literal, and recognizes `<!-->`, `<!--->`, and canonical `<!-- ... -->`. Multiline search still stops at protected structural/block boundaries, but fence boundaries now call the existing `Get-ArcMarkdownFenceOpening` parser so invalid backtick-info openers cannot diverge from fenced-code behavior. Raw marker provenance, fenced-code hiding, LF/CRLF boundaries, and Windows PowerShell 5.1 compatibility remain intact.

The LF/CRLF matrix covers inline `<!--`/`-->`, multiline spans, three- and seven-backtick exact matching with shorter/longer internal runs, unmatched spans, real comments immediately before/after inline code, compact comments before/between duplicate canonical sections, and the invalid-fence interaction. Every duplicate probe asserts zero extracted table rows and the exact sole `ARC-CONTRACT-HEADING-CARDINALITY` diagnostic. The final responsibility-conformance scenario run exited `0` with both newline variants passing and terminal `PASS: responsibility conformance contract`. Independent final read-only review reported no remaining Critical or Major finding; direct Windows PowerShell 5.1 probes and newline preservation were clean.

Exactly these two project files changed in cycle 8:

- `aitoolkit/tests/validation/responsibility-conformance.validation.ps1`
- `aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1`

No template, skill, canonical contract, deferred raw parser, Phase 2, `main/`, `issue/`, or unrelated project file changed.

### Final no-edit pre-amend verification

Both changed scripts parsed with zero Windows PowerShell 5.1 AST errors. After the final source edit, the complete corrected 13-command sequence ran without intervening edits and every command exited `0`:

- `responsibility-conformance.Tests.ps1`: `PASS: responsibility conformance contract`
- `responsibility-handoff.Tests.ps1`: `PASS: responsibility handoff scenarios`
- `target-conformance.Tests.ps1`: `PASS: target conformance scenarios`
- `structural-gate.Tests.ps1`: `PASS: structural gate (151 scenarios)`
- `architecture-review.Tests.ps1`: `PASS: architecture review scenarios`
- `scope-engine.Tests.ps1`: `PASS: scope engine behavioral scenarios`
- `flexible-scope-e2e.Tests.ps1`: `PASS: flexible migration scope orchestration (21 isolated E2E scenarios)`
- `validate-migration-framework.ps1 -Check Contracts`: `PASS: migration framework (Contracts)`
- `validate-migration-framework.ps1 -Check Skills`: `PASS: migration framework (Skills)`
- `validate-migration-framework.ps1 -Check Templates`: `PASS: migration framework (Templates)`
- `validate-migration-framework.ps1 -Check All`: `PASS: migration framework (All)`
- `validate-migration-framework.ps1 -Check SourceIntegrityOnly`: `PASS: migration framework (SourceIntegrityOnly)`
- `git diff --check`: exit `0`; only informational LF-to-CRLF working-copy notices were emitted.

The focused `validate-migration-framework.Tests.ps1 -ResponsibilityConformanceOnly` selector then exited `0`; all 17 isolated mutations passed with source digest `79CC9247AA63107E544024AD3FDA351BA4C8DB3F78A26C12E155FC6150E2884F` and terminal `PASS: responsibility conformance mutation scenarios`.

No unselected/default/full suite was run in cycle 8.

### Staged audit, amend, and exact-HEAD evidence

The cached audit contained exactly the two cycle-8 files above, with no unstaged project diff. `git diff --cached --check` exited `0`, and the pre-amend count from the fixed Task 9 base remained `1`. `git commit --amend --no-edit` preserved the sole subject `test: cover responsibility conformance workflow` and produced final HEAD `1001e2ce525d84bec710d93232498583a6d82b67`.

Fresh checks on that exact HEAD produced:

- `validate-migration-framework.ps1 -Check All`: exit `0`, `PASS: migration framework (All)`;
- `validate-migration-framework.ps1 -Check SourceIntegrityOnly`: exit `0`, `PASS: migration framework (SourceIntegrityOnly)`;
- `git diff --check HEAD^ HEAD`: exit `0`, no diagnostics;
- `git status --porcelain=v1 --untracked-files=all`: no output;
- `git rev-list --count 0cbb95afb835263ecf3b52b36f5ec0605f903435..HEAD`: `1`;
- cumulative Task 9 `HEAD^..HEAD` file count: `32`;
- HEAD: `1001e2ce525d84bec710d93232498583a6d82b67`.

The project worktree remained clean. No unselected/default/full suite invocation occurred.

## 2026-08-25 - final whole-review six-finding fix wave

Starting exact HEAD: `1001e2ce525d84bec710d93232498583a6d82b67`  
Fixed Task 9 base: `0cbb95afb835263ecf3b52b36f5ec0605f903435`  
Commit policy: amend the existing sole Task 9 commit; never create a second commit.  
Suite policy: the default/full mutation suite remained locked; only `-ResponsibilityConformanceOnly` was authorized.

### Claim verification and root causes

All three Critical and three Important claims were checked against the exact clean starting tree before source edits. All six were confirmed.

1. **Pinned changed-path inventory and deleted responsibility reconciliation.** Independent review derived production inventory from responsibility-marker matches, so markerless production `M/A/R/C` paths could be omitted. It also inspected final content only for surviving files, so a responsibility block removed from an `M/R` file disappeared before deletion reconciliation. `Change Hygiene` was not reconciled one-to-one to the pinned Git name-status inventory.
2. **Executable downstream lifecycle and whole-chain scope validation.** Review lifecycle was checked more strongly than steps 12-15, and terminal scope validation did not enforce the canonical lifecycle on every node. Draft/blocked/automatic or structurally non-canonical downstream artifacts could therefore remain executable when they were not the head artifact.
3. **Overall review conclusion authority.** Architecture sub-verdict PASS could seed verification even when the review's actual overall verdict was `Reject` or its Critical count was positive. The queue/handoff contract did not bind executability to exact `Critical count: 0` plus exact `Verdict: Approve`.
4. **Mode-dependent regression transition.** Generic and `none` adapter paths allowed parity to jump directly to Knowledge Base regardless of approved mode. The transition was derived incompletely from artifact shape instead of the approved master-plan adapter/mode authority. Incremental requires regression; approved greenfield may omit it.
5. **Comparable-exemplar schema conflict.** Discovery responsibility production already emitted the canonical 13-column table, while the target contract/validator still authorized a seven-column table. The mixed producer/consumer authority made a composed discovery artifact non-portable.
6. **Canonical deleted Change Hygiene rows.** Implementation accepted only `new|existing`, required a final-tree file for all rows, and had no exact pinned base-source/removal-diff pair for deletion. This contradicted independent review's base-only deletion evidence model.

### Strict RED-to-GREEN evidence

One finding at a time, focused tests were added and observed failing before its implementation correction:

- **Finding 5 RED:** the canonical 13-column discovery producer could not compose with the target contract, while a legacy seven-column authority remained acceptable. The target contract, validator, mutation expectation, and composed target scenario now use exactly the 13 canonical columns; implicit seven-column input is rejected. `target-conformance.Tests.ps1` then exited `0`.
- **Finding 3 RED:** an overall `Reject` review and a Critical-bearing review could still seed verification while their architecture responsibility handoff row said PASS. Review parsing now requires one exact executable conclusion (`Critical count: 0`, `Verdict: Approve`) and rejects `Reject`, `Approve-with-fixes`, positive/invalid Critical counts, and blocked architecture verdicts. Architecture review and handoff scenarios then exited `0`.
- **Finding 2 RED:** a draft downstream assurance artifact was accepted, and lifecycle changes on non-head chain nodes were not inspected by terminal scope. Steps 12-15 now require exact canonical top-level front matter plus `approved/complete/human`, exact same-run context, and ordinal handoff. Draft, blocked, auto, extra-key, duplicate-key, and cross-run controls reject; scope tests mutate every downstream node. Handoff and scope-engine scenarios then exited `0`.
- **Finding 4 RED:** incremental generic and `none` paths accepted parity-to-KB without regression. Handoff transitions now use the approved master-plan mode: incremental parity must flow through regression to KB, while greenfield parity may flow directly to KB. Incremental generic/none negative controls and an approved greenfield positive then passed.
- **Finding 1 RED:** a markerless added `src` route was accepted because it never entered the responsibility inventory. The validator now parses pinned `git diff --name-status --find-renames --find-copies-harder --diff-filter=ACMRD`, classifies canonical production roots independently of markers, reconciles every changed path to exact hygiene kind (`A/C=new`, `M/R=existing`, `D=deleted`), and compares pinned base/final responsibility blocks on surviving `M/R` paths. Direct `A/M/R/C`, omitted-path, markerless-route, and removed-owner controls then passed in architecture review.
- **Finding 6 RED:** a deleted hygiene row had no executable evidence form. The initial positive fixture was itself invalid because it used a synthetic `none` checkpoint; it was corrected before implementation to create a real pinned Git deletion. `deleted` now requires exact `source:<base>:<path>; diff:<base>..<final>:<path>`, does not require final-tree existence, and rejects missing, stale, or foreign evidence in LF and CRLF fixtures. Responsibility conformance and architecture review then exited `0`.

The source, contracts, skills, and templates were aligned with those rules. The canonical 13-column exemplar schema is singular; review producers expose exact Critical count and verdict seams; steps 12-15 expose canonical executable lifecycle; incremental parity/regression/KB guidance matches the validator; and implementation/Change Hygiene documentation explicitly supports pinned deletions and responsibility-block removal from surviving files.

### Gate-7 fixture RCA discovered during the no-edit sequence

The first corrected full `flexible-scope-e2e.Tests.ps1` run exited `1` only after its process had ended; no edit occurred while it was active. S05/S20 chains were rejected because `New-ResponsibilityReviewEvidence` replaced the verdict placeholder but its Critical-count regex was not CRLF-safe. The fixture helper was corrected to render exactly one CRLF/LF-safe `Critical count: 0` and exactly one `Verdict: Approve`, with alter-or-fail cardinality guards. A rerun cleared S05, ordinary S20, and the waiver controls but retained one valid failure: `S20-greenfield-four-stage-chain`.

That remaining RED exposed two fixture-authority mismatches introduced by the stronger whole-chain validation. The purported greenfield positive reused incremental-labeled review/verification/parity/KB nodes, and then changed only the legacy authority/profile while leaving canonical `master-plan.md` Delivery Adapter Selection incremental. The fixture now renders a dedicated greenfield review -> verification -> parity -> KB chain, points the four-stage manifest to those immutable references, and changes/restores both canonical master-plan mode and legacy plan/profile only around the approved positive. The incremental self-label negative still runs before the authorities change. Focused `-OnlyScenario S20` then exited `0`; the full 21-scenario gate 7 rerun also exited `0`. No production validator was changed for this fixture repair.

### Final no-edit pre-amend verification

After the last fixture edit, the complete corrected 13-command sequence was restarted and every command exited `0`:

- `responsibility-conformance.Tests.ps1`: `PASS: responsibility conformance contract`;
- `responsibility-handoff.Tests.ps1`: `PASS: responsibility handoff scenarios`;
- `target-conformance.Tests.ps1`: `PASS: target conformance scenarios`;
- `structural-gate.Tests.ps1`: `PASS: structural gate (151 scenarios)`;
- `architecture-review.Tests.ps1`: `PASS: architecture review scenarios`;
- `scope-engine.Tests.ps1`: `PASS: scope engine behavioral scenarios`;
- `flexible-scope-e2e.Tests.ps1`: `PASS: flexible migration scope orchestration (21 isolated E2E scenarios)`;
- `validate-migration-framework.ps1 -Check Contracts`: `PASS: migration framework (Contracts)`;
- `validate-migration-framework.ps1 -Check Skills`: `PASS: migration framework (Skills)`;
- `validate-migration-framework.ps1 -Check Templates`: `PASS: migration framework (Templates)`;
- `validate-migration-framework.ps1 -Check All`: `PASS: migration framework (All)`;
- `validate-migration-framework.ps1 -Check SourceIntegrityOnly`: `PASS: migration framework (SourceIntegrityOnly)`;
- `git diff --check`: exit `0`; only informational LF-to-CRLF working-copy warnings were emitted.

The only authorized mutation command, `validate-migration-framework.Tests.ps1 -ResponsibilityConformanceOnly`, was rerun after the final edit and exited `0`: all 17/17 isolated mutations passed, source digest `DF3FA6FDAD3C1DF14F6495A9D9DD8C678E0A5F9706D124C87DEC6BD31AED3C86`, terminal `PASS: responsibility conformance mutation scenarios`. The unselected/default/full mutation suite was never invoked in this wave.

### Pre-amend scope audit

The project delta contains exactly 25 approved files: two contracts, seven skills/shared guidance files, six templates, three validators, six scenario test files, and the focused mutation expectation file. The main framework validator, Phase 2 paths, `main/`, `issue/`, and unrelated files were not changed. This report and `progress.md` are the only authorized non-project evidence files to append before amend.

### Staged audit, amend, and exact-HEAD evidence

The cache contained exactly those 25 approved project files, `git diff --cached --check` exited `0`, and there were zero unstaged tracked paths. The pre-amend Task 9 count remained one. `git commit --amend --no-edit` preserved subject `test: cover responsibility conformance workflow` and produced exact HEAD `686492cbdc09475024c455213c3f4bf7ba7dc76a`.

Fresh verification on that exact HEAD produced:

- focused `validate-migration-framework.Tests.ps1 -ResponsibilityConformanceOnly`: exit `0`, all 17/17 mutations PASS, digest `DF3FA6FDAD3C1DF14F6495A9D9DD8C678E0A5F9706D124C87DEC6BD31AED3C86`;
- `validate-migration-framework.ps1 -Check All`: exit `0`, `PASS: migration framework (All)`;
- `validate-migration-framework.ps1 -Check SourceIntegrityOnly`: exit `0`, `PASS: migration framework (SourceIntegrityOnly)`;
- `git diff --check HEAD^ HEAD`: exit `0`, no diagnostics;
- `git status --porcelain=v1 --untracked-files=all`: no output;
- `git rev-list --count 0cbb95afb835263ecf3b52b36f5ec0605f903435..HEAD`: `1`;
- cumulative Task 9 `HEAD^..HEAD` file count: `36`;
- final-review wave delta `1001e2ce525d84bec710d93232498583a6d82b67..HEAD`: exactly the 25 audited project files;
- HEAD remained `686492cbdc09475024c455213c3f4bf7ba7dc76a` throughout exact-HEAD verification.

The ignored persistent report and ledger are updated. No unselected/default/full mutation invocation occurred, and there is no remaining implementation concern in the authorized six-finding scope.

## SDD fix round 1/5 after final whole-review wave

The round began from exact clean HEAD `686492cbdc09475024c455213c3f4bf7ba7dc76a`; Task 9 remained exactly one commit over `0cbb95afb835263ecf3b52b36f5ec0605f903435`. All eight scoped claims were verified against source before tests or implementation edits.

### Root-cause verification

1. **C1 — downstream chain lifecycle and dependency unlock.** `Test-ScopeEngine` wrapped `status=approved/result=complete/approval_source=human` in `chainIndex -eq 0`, so steps 12–15 bypassed lifecycle checks. `successful-terminal-artifact` reused that function, and selection unlocked a dependency using status alone without validating the completed dependency's terminal responsibility chain.
2. **C2 — case-variant review step.** Handoff step membership and PowerShell hashtable lookup were case-insensitive, but the Reject/Critical and derived-PASS checks used case-sensitive equality. `11-AI-REVIEW` therefore skipped the review conclusion gates and could seed verification.
3. **C3 — mixed owned/unowned production content.** The pinned parser ignored all lines before the first `@responsibility` marker. A markerless route/provider added before an unchanged valid block disappeared from semantic ownership inspection.
4. **C4 — incidental non-production markers.** Every changed final path was parsed for owners before production classification. Complete marker examples in docs/tests/templates could become false owner authority even though Change Hygiene correctly needed to retain every changed Git path.
5. **C5 — destination-only rename authority.** Name-status classification used only the destination `Path`. A production-to-docs rename lost production classification, removed owners were labeled with the new path, and base evidence attempted `base:<new path>`. Review/hygiene had no explicit old-to-new mapping.
6. **I1 — non-bijective Change Hygiene and partial deletion evidence.** The two reconciliation loops required at least one match, not exactly one, so duplicate rows passed. Exact base/removal checkpoint evidence was enforced only inside deleted-owner reconciliation, not for every deleted Git path.
7. **I2 — fail-open executable front matter.** Top-level key discovery recognized only lowercase underscore keys and sorted them. Quoted, hyphenated, and case-variant extras were invisible; order was discarded; `produced_at` presence was checked only as a key and accepted blank or impossible dates.
8. **I3 — inconsistent repository path comparison.** Only the production classifier normalized backslashes. Design, implementation, review evidence, selected paths, Git inventory, Change Hygiene, and verification binding compared raw strings, causing Windows-path false negatives and alias ambiguity.

### Strict focused RED -> GREEN evidence

- **C1 RED:** focused scope scenarios exited `1`: invalid downstream steps 12–15 transitioned successfully and four invalid completed dependencies unlocked their dependents. **GREEN:** lifecycle checks now apply to every node, and selection validates a completed dependency's terminal chain before unlock. `scope-engine.Tests.ps1` exited `0`.
- **C2 RED:** a `11-AI-REVIEW` source with `Reject` returned no handoff diagnostics. **GREEN:** step IDs must be one exact canonical ordinal value before lifecycle/conclusion evaluation; Reject and Critical case-variant controls pass. `responsibility-handoff.Tests.ps1` exited `0`.
- **C3 RED:** `route RogueRoute -> RogueProvider` before an unchanged owner block produced no inventory error. **GREEN:** global production route cardinality must equal routes assigned inside parsed responsibility blocks.
- **C4 RED/GREEN:** incidental non-production owner markers were confirmed to enter the active inventory. Changed files are now parsed only when canonically production-classified or explicitly selected by approved owner authority, while all Git paths remain in Change Hygiene. The non-production ignored positive and explicitly-selected positive both pass.
- **C5 RED:** the composed src-to-docs rename with explicit old-to-new checkpoint/review evidence remained blocked; destination-only evidence was not distinguished. **GREEN:** records retain `BasePath`, `FinalPath`, `RenameMapping`, and production classification from either side; deleted owner evidence resolves the old path; hygiene/review require `old->new`. Destination-only negative and explicit mapping positive pass.
- **I1 RED:** a duplicate Change Hygiene row passed, and an ownerless deleted README with `Checkpoint History=none` passed. **GREEN:** both directions require exactly one match; every `D` path requires exact base-source/removal-diff evidence. Duplicate, missing checkpoint, and exact ownerless-deletion positive pass.
- **I3 RED:** a fully composed review using Windows separators failed `responsibility-evidence-missing`. **GREEN:** one canonical repository-path conversion is applied before every authority comparison; the composed Windows positive, slash/backslash duplicate negative, and parent-segment negative pass. `architecture-review.Tests.ps1` exited `0`.
- **I2 RED:** a quoted extra front-matter key returned no diagnostic. **GREEN:** executable handoff front matter requires exact ordered top-level keys `step_id|status|result|approval_source|produced_at|responsibility_contract`, exact canonical step ID, and PowerShell 5.1-compatible `DateTime.TryParseExact('yyyy-MM-dd')`. Quoted/hyphenated/case-variant extras, blank/invalid date, and reordered keys reject; producer-composed positives pass.

The contract, implementation/review templates, and AI-review skill now state one-to-one hygiene, every-path deletion checkpoints, production classification across both rename sides, explicit rename mapping, canonical repository paths, restricted owner parsing, mixed markerless-content rejection, and exact executable front-matter authority.

### Fresh affected and authorized gate evidence

The affected scenario terminals were all green: responsibility conformance, responsibility handoff, architecture review, and scope engine. The first affected responsibility-conformance rerun found one fixture-only ordering mismatch: its draft-to-approved renderer inserted `approval_source` before `result`; the fixture was changed to render the newly enforced canonical order, after which the complete scenario exited `0`.

The corrected 13-command sequence was then restarted and completed without edits or overlap:

- responsibility conformance: `PASS: responsibility conformance contract`;
- responsibility handoff: `PASS: responsibility handoff scenarios`;
- target conformance: `PASS: target conformance scenarios`;
- structural gate: `PASS: structural gate (151 scenarios)`;
- architecture review: `PASS: architecture review scenarios`;
- scope engine: `PASS: scope engine behavioral scenarios`;
- Flexible Scope gate 7: exit `0`, `PASS: flexible migration scope orchestration (21 isolated E2E scenarios)` after approximately eleven minutes in one uninterrupted session;
- Contracts, Skills, Templates, All, and SourceIntegrityOnly: each exact validator command exited `0`;
- `git diff --check`: exit `0`, with only informational LF-to-CRLF working-copy warnings.

The only authorized mutation command, `validate-migration-framework.Tests.ps1 -ResponsibilityConformanceOnly`, exited `0`: all 17/17 named mutations passed, digest `AC8DE5FFC6D774DA01B833BE3C2A1A2ECA78B4819F311D875D49BDC231B883C7`, terminal `PASS: responsibility conformance mutation scenarios`. The default/full mutation suite was not invoked.

### Scope and deferred Minor

The project wave changes ten approved files: one contract, one skill, two templates, two production validators, and four scenario files. No Phase 2, `main/`, `issue/`, default mutation selector, or unrelated project path changed. This ignored report and `progress.md` are the only persistent evidence updates.

The review Minor requesting a real discovery-template/skill composed renderer test is recorded as deferred: it is outside these inventory, lifecycle, handoff, hygiene, and path fixes, and no mechanical in-scope change was justified. Existing canonical target/discovery gates remain green; the omission is test-depth only, not a known runtime defect.

### Amend and exact-HEAD verification

The staged cache contained exactly the ten audited project files, `git diff --cached --check` exited `0`, there were no unstaged tracked files, and the pre-amend Task 9 count was one. `git commit --amend --no-edit` preserved subject `test: cover responsibility conformance workflow` and produced `e04242560502ea8c9d5e99998c57bff56fe460d3`.

Fresh verification on that exact HEAD completed without edits:

- focused `-ResponsibilityConformanceOnly`: exit `0`, all 17/17 mutations PASS, digest `AC8DE5FFC6D774DA01B833BE3C2A1A2ECA78B4819F311D875D49BDC231B883C7`;
- `validate-migration-framework.ps1 -Check All`: exit `0`;
- `validate-migration-framework.ps1 -Check SourceIntegrityOnly`: exit `0`;
- `git diff --check HEAD^ HEAD`: exit `0`, no diagnostics;
- `git status --porcelain=v1 --untracked-files=all`: no output;
- `git rev-list --count 0cbb95afb835263ecf3b52b36f5ec0605f903435..HEAD`: `1`;
- round delta `686492c..HEAD`: exactly 10 audited project files;
- cumulative Task 9 commit: 36 files;
- final HEAD remained `e04242560502ea8c9d5e99998c57bff56fe460d3`.

No default/full mutation invocation occurred in this round.

## SDD fix round 2/5: reconciliation and canonical path authority

Starting authority was the exact clean sole Task 9 commit `e04242560502ea8c9d5e99998c57bff56fe460d3`; `git rev-list --count 0cbb95afb835263ecf3b52b36f5ec0605f903435..HEAD` returned `1`. The three scoped review claims were verified against source before modification.

### C1 - reconciled dependency bypassed terminal responsibility authority

Root cause: selection validated terminal responsibility authority for dependencies while their persisted status was still `in-progress`. Reconciliation then changed the item to `complete`, after which dependency selection trusted the new terminal status without re-running the authority gate.

Strict RED added an in-progress dependency whose latest attempt was complete and whose `terminal_evidence` matched the attempt artifact, but which had no canonical terminal responsibility chain. The focused scope run failed exactly because the dependent was selected (`selected`, `eligible-by-depth-plan-order-id`) instead of returning `scope-blocked`. The existing reconciliation positive was strengthened to use a complete, human-approved, same-run canonical terminal chain, and the fixture resolver now avoids synthesizing a duplicate generic attempt artifact when the supplied terminal artifact is that attempt artifact.

GREEN: complete-dependency terminal authority validation now executes after reconciliation and before dependency unlock. Missing authority returns `terminal-responsibility-authority-invalid`; the canonical-chain positive selects the dependent and exposes the reconciled work-item ID. `scope-engine.Tests.ps1` exited `0` with `PASS: scope engine behavioral scenarios`.

### C2 - hyphenated canonical review evidence rejected by a second brittle regex

Root cause: review evidence was first normalized correctly, but the later validation regex used `[^#;\r\n>-]+`, accidentally excluding the hyphen character that the canonical repository-path grammar permits. Separate parsing at the two sites also admitted ambiguity risk.

Strict RED renamed the production owner to the valid canonical path `src/admin-route.source` with explicit old-to-new checkpoint and review mapping. The composed review failed with `responsibility-evidence-missing; responsibility-waiver-forbidden`. Source-mapping delimiter and parent-traversal negatives were added alongside it.

GREEN: `ConvertTo-ArcCanonicalReviewEvidenceItem` is now the single parser/normalizer for `source:` and `diff:` evidence. It validates SHA/range shape, permits exactly zero mapping delimiters for source and at most one for diff, canonicalizes one or two repository paths through `ConvertTo-ArcCanonicalRepositoryPath`, and reconstructs the exact canonical item. Both initial normalization and later evidence validation use it. The hyphen positive and delimiter/traversal negatives all pass in `architecture-review.Tests.ps1`.

### I1 - pinned production-binding comparison was slash-only and raw

Root cause: `Test-ArcPinnedVerificationOwnershipEvidence` parsed planned and source `@production-binding` paths with slash-only regexes, then compared raw spellings. This rejected an equivalent Windows separator and could ignore a second alias-spelled marker because it did not match the slash-only source regex.

Strict RED changed and committed the actual pinned `test/admin_route_test.ps1` marker to `src\admin_route.source`, advanced the fixture final SHA, updated provenance/artifact SHA references, and ran it with exact changed-test Change Hygiene. The composed positive failed with `verification-production-binding-missing; responsibility-waiver-forbidden`. Alias-duplicate, parent-traversal, and canonical mismatch negatives were added.

GREEN: verification evidence paths, planned binding paths, and every pinned marker path now pass through the shared canonical repository-path normalizer before comparison. Marker cardinality is evaluated before accepting the normalized path, so slash/backslash aliases cannot hide duplicates. The actual pinned-source Windows positive and all three ambiguity/mismatch negatives pass.

### Round 2 no-edit verification before amend

Affected suites passed: responsibility conformance, architecture review, and scope engine. The corrected 13-command contract then passed without edits:

1. `responsibility-conformance.Tests.ps1`: exit `0`, `PASS: responsibility conformance contract`;
2. `responsibility-handoff.Tests.ps1`: exit `0`, `PASS: responsibility handoff scenarios`;
3. `target-conformance.Tests.ps1`: exit `0`, `PASS: target conformance scenarios`;
4. `structural-gate.Tests.ps1`: exit `0`, `PASS: structural gate (151 scenarios)`;
5. `architecture-review.Tests.ps1`: exit `0`, `PASS: architecture review scenarios`;
6. `scope-engine.Tests.ps1`: exit `0`, `PASS: scope engine behavioral scenarios`;
7. `flexible-scope-e2e.Tests.ps1`: exit `0`, `PASS: flexible migration scope orchestration (21 isolated E2E scenarios)`, one uninterrupted session, 650.7 seconds;
8. `validate-migration-framework.ps1 -Check Contracts`: exit `0`;
9. `-Check Skills`: exit `0`;
10. `-Check Templates`: exit `0`;
11. `-Check All`: exit `0`;
12. `-Check SourceIntegrityOnly`: exit `0`;
13. direct `git diff --check`: exit `0`, with only informational LF-to-CRLF working-copy notices.

The only authorized mutation selector, `validate-migration-framework.Tests.ps1 -ResponsibilityConformanceOnly`, exited `0`; all 17/17 isolated mutations passed with source digest `098986284A1808D6743D2BE0918B3296E92E2A16321725B4B0A10403AA3715E7` and terminal `PASS: responsibility conformance mutation scenarios`. The default/full mutation suite was not invoked. The discovery template/skill composed-renderer Minor remains ledger-only and deferred to its owning scope.

### Round 2 amend and exact-HEAD evidence

The staged cache contained exactly the four audited round-2 project files, `git diff --cached --check` exited `0`, there were no unstaged tracked project files, and the Task 9 count remained one. `git commit --amend --no-edit` preserved subject `test: cover responsibility conformance workflow` and produced `ed6e436f9d7a7cf24981bf0a06178329a70b94f0`.

Fresh checks on that exact HEAD, with no intervening edits, produced:

- focused `-ResponsibilityConformanceOnly`: exit `0`, all 17/17 mutations PASS, digest `098986284A1808D6743D2BE0918B3296E92E2A16321725B4B0A10403AA3715E7`;
- `validate-migration-framework.ps1 -Check All`: exit `0`, `PASS: migration framework (All)`;
- `validate-migration-framework.ps1 -Check SourceIntegrityOnly`: exit `0`, `PASS: migration framework (SourceIntegrityOnly)`;
- `git diff --check HEAD^ HEAD`: exit `0`;
- `git status --porcelain=v1 --untracked-files=all`: no output;
- `git rev-list --count 0cbb95afb835263ecf3b52b36f5ec0605f903435..HEAD`: `1`;
- final HEAD: `ed6e436f9d7a7cf24981bf0a06178329a70b94f0`.

No default/full mutation invocation occurred in round 2.

## SDD fix round 3/5: unconditional reconciled-completion authority

Starting authority was exact clean HEAD `ed6e436f9d7a7cf24981bf0a06178329a70b94f0`, with one Task 9 commit above fixed base `0cbb95afb835263ecf3b52b36f5ec0605f903435`.

### Critical claim, root cause, RED, and GREEN

The review claim was confirmed. Round 2 moved complete-dependency authority checks after reconciliation, but the check still iterated only the set of IDs referenced as dependencies. A sole in-progress item could reconcile to `complete` without appearing in that set; the empty dependency loop then allowed an unrelated ready item to be selected without validating the newly completed item's terminal responsibility authority.

Strict RED created no-dependent reconciliation scenarios and asserted result, reason, scope status, selected item, and reconciled item. Missing terminal authority, terminal pre-v1/cross-run/evidence mismatch, and every one of the five chain nodes mutated independently across `status`, `result`, and human `approval_source` all exposed the bypass: the engine returned `selected` / `eligible-by-depth-plan-order-id` / `scope-in-progress` and chose unrelated work. A canonical terminal-chain positive already selected the unrelated item and recorded the reconciled work item. An initial terminal work-item mismatch probe was rejected earlier by immutable attempt-artifact binding, so it was replaced before implementation by a handoff evidence mismatch that isolates the reviewed reconciliation gap.

GREEN adds an unconditional post-reconciliation gate for every newly reconciled `complete` item, before the existing dependency authority loop and before any selection. It requires non-placeholder terminal evidence and exact `testTerminalResponsibilityAuthority`; failure returns `scope-blocked`, `terminal-responsibility-authority-invalid`, no selected work item, and the reconciled ID. The prior dependency-referenced path remains intact. `scope-engine.Tests.ps1` exits `0` with `PASS: scope engine behavioral scenarios` across missing, terminal-authority, all node lifecycle/authority, canonical no-dependent, and existing dependency cases.

### Round 3 no-edit verification before amend

The affected scope suite passed. The corrected 13-command contract then passed without edits:

1. responsibility conformance PASS;
2. responsibility handoff PASS;
3. target conformance PASS;
4. structural gate PASS (151 scenarios);
5. architecture review PASS;
6. scope engine PASS;
7. Flexible Scope PASS (21 isolated E2E scenarios), one uninterrupted session, exit `0`, 630.9 seconds;
8-12. Contracts, Skills, Templates, All, and SourceIntegrityOnly each exited `0`;
13. direct `git diff --check` exited `0`, with only informational LF-to-CRLF working-copy notices.

The only authorized mutation selector, `validate-migration-framework.Tests.ps1 -ResponsibilityConformanceOnly`, exited `0`; all 17/17 isolated mutations passed with source digest `87756F0A0B3B4538477EC0F10711784C2505C8F8CC3175086C844D83A9E1B7EE` and terminal `PASS: responsibility conformance mutation scenarios`. The default/full mutation suite was not invoked. The previously deferred discovery composed-renderer Minor remains unchanged and out of this one-Critical round.

### Round 3 amend and exact-HEAD evidence

The staged cache contained exactly the two audited round-3 project files, cached diff check passed, there were no unstaged tracked project files, and the Task 9 count remained one. `git commit --amend --no-edit` preserved the sole commit and produced `bb0ee9612943bc2d9836c2ad66b762f56535fe1c`.

Fresh no-edit checks on that exact HEAD produced focused 17/17 PASS at unchanged digest `87756F0A0B3B4538477EC0F10711784C2505C8F8CC3175086C844D83A9E1B7EE`, `-Check All` PASS, `-Check SourceIntegrityOnly` PASS, `git diff --check HEAD^ HEAD` exit `0`, clean porcelain status, and Task 9 commit count `1`. No default/full mutation invocation occurred in round 3.

## SDD fix round 4/5: exact reconciled terminal result authority

Starting authority was exact clean HEAD `bb0ee9612943bc2d9836c2ad66b762f56535fe1c`, with exactly one Task 9 commit above fixed base `0cbb95afb835263ecf3b52b36f5ec0605f903435`.

### Contract and root-cause verification

The Critical claim was confirmed. The shared `Test-TerminalResponsibilityAuthority` predicate verified the immutable terminal envelope, work item, plan/run/spec bindings, v1 handoff, mode-aware ordered chain, and every chain node's exact `approved/complete/human` lifecycle, but it did not inspect the terminal artifact's own `result`. The round-3 unconditional reconciliation gate and the dependency-unlock gate both delegated to this incomplete predicate after setting the reconciled item status to `complete`. In contrast, the normal `successful-terminal-artifact` transition independently required both terminal `status` and `result` to be exact `complete` before calling the same shared predicate.

The lifecycle contract has a broad artifact result enum (`complete | partial | blocked`), but explicitly states that `blocked` stops the orchestrator and that a failed execution cannot be recorded as completed. The scope contract permits `in-progress -> complete` only for a valid successful terminal artifact. Therefore this completion-authority predicate must accept only exact, case-sensitive `result = complete`; `blocked`, malformed, blank, and case-variant values are non-authoritative for reconciliation.

### Strict RED and minimal GREEN

Before the production edit, `scope-engine.Tests.ps1` added a real-behavior 2-by-5 matrix covering both no-dependent unrelated selection and dependent unlock. Each path used a terminal artifact whose status remained exact `complete`, with result `complete`, `blocked`, `fail`, empty, or noncanonical `Complete`. Every case asserted exact `result`, `scope_status`, `reconciled_work_item_id`, and selected/empty `work_item_id`; rejected cases also asserted `terminal-responsibility-authority-invalid`.

The strict RED command exited `1`. Both canonical `complete` positives and every exact reconciled-ID assertion passed. All eight non-complete cases were incorrectly accepted as `selected`, `eligible-by-depth-plan-order-id`, `scope-in-progress`, selecting the unrelated or dependent item; this produced 32 exact failed outcome assertions and isolated the omitted terminal-result check.

GREEN adds one case-sensitive condition to the shared predicate: terminal artifact `result` must equal `complete`. The first post-fix run correctly killed the new negatives and exposed two older scope-completion positives whose test factory omitted `result` entirely. The factory was completed with canonical `result = complete`, matching the real terminal structure; the predicate was not weakened. The fresh affected run then exited `0` with `PASS: scope engine behavioral scenarios`.

### Round 4 no-edit verification before amend

The corrected 13-command sequence ran sequentially without source edits or overlapping suites and all commands exited `0`:

1. responsibility conformance PASS;
2. responsibility handoff PASS;
3. target conformance PASS;
4. structural gate PASS (151 scenarios);
5. architecture review PASS;
6. scope engine PASS;
7. Flexible Scope PASS (21 isolated E2E scenarios);
8-12. Contracts, Skills, Templates, All, and SourceIntegrityOnly each PASS;
13. direct `git diff --check` PASS with only informational LF-to-CRLF working-copy notices.

The only authorized mutation selector, `validate-migration-framework.Tests.ps1 -ResponsibilityConformanceOnly`, exited `0`; all 17/17 isolated mutations passed with unchanged source digest `9A7070E2D52DEF83E9DF22FDDD1FEB36F71F06AD853C045CB5C81D5B9F8C7650` and terminal `PASS: responsibility conformance mutation scenarios`.

The audited round scope is exactly two project files: `aitoolkit/tests/scenarios/scope-engine.Tests.ps1` and `aitoolkit/tests/validation/scope-engine.validation.ps1`. No Phase 2, `main/`, `issue/`, deferred discovery-renderer Minor, or unrelated path changed. The default/full mutation suite was not invoked.

### Round 4 amend and exact-HEAD evidence

The staged cache contained exactly the two audited round-4 project files, `git diff --cached --check` exited `0`, no tracked unstaged project file remained, and the pre-amend Task 9 count was one. `git commit --amend --no-edit` preserved subject `test: cover responsibility conformance workflow` and produced `c0acc0b823acfa7967400a188c4ba7d32cdc31ab`.

Fresh checks on that exact HEAD, with no intervening project edit, produced:

- focused `-ResponsibilityConformanceOnly`: exit `0`, all 17/17 mutations PASS, digest `9A7070E2D52DEF83E9DF22FDDD1FEB36F71F06AD853C045CB5C81D5B9F8C7650`;
- `validate-migration-framework.ps1 -Check All`: exit `0`, `PASS: migration framework (All)`;
- `validate-migration-framework.ps1 -Check SourceIntegrityOnly`: exit `0`, `PASS: migration framework (SourceIntegrityOnly)`;
- `git diff --check HEAD^ HEAD`: exit `0`, no diagnostics;
- `git status --porcelain=v1 --untracked-files=all`: no output;
- `git rev-list --count 0cbb95afb835263ecf3b52b36f5ec0605f903435..HEAD`: `1`;
- round delta `bb0ee9612943bc2d9836c2ad66b762f56535fe1c..HEAD`: exactly the two audited project files;
- cumulative Task 9 commit: 36 files;
- exact HEAD remained `c0acc0b823acfa7967400a188c4ba7d32cdc31ab`.

No default/full mutation invocation occurred in round 4.

## Final whole-review 9C+2I authority and integrity fix wave

Starting authority was exact clean HEAD `c0acc0b823acfa7967400a188c4ba7d32cdc31ab`. The fixed Task 9 base remained `0cbb95afb835263ecf3b52b36f5ec0605f903435`, `BASE..HEAD` contained exactly one commit, and its subject remained `test: cover responsibility conformance workflow`. All eleven review claims were checked against their actual producer/consumer paths before implementation. No subagent or reviewer was used, no suite overlapped another suite or an edit, and the default/full mutation suite was not invoked.

### Root cause, strict RED, and GREEN evidence

1. **C1 - Verification Ownership aggregate authority.** `Test-ResponsibilityImplementation` trusted the caller-supplied aggregate row after only checking that row-level verdicts belonged to the enum. It did not derive aggregate Verification Ownership from every required actual row, and it did not require a canonical non-placeholder evidence path plus a non-placeholder symbol/scenario. Strict RED showed that a required `BLOCKED` row and placeholder evidence still allowed aggregate PASS. GREEN tracks all required rows, requires exact `PASS`, requires an exact canonical repository path, rejects placeholder evidence values, and derives the aggregate `PASS/BLOCKED` value. A later corrected-gate RED exposed an over-restrictive symbol-shaped scenario regex: legitimate `lock controller contract` prose was rejected. The rule was corrected to preserve non-placeholder descriptive scenarios while retaining exact canonical path enforcement. Explicit descriptive-scenario positive and backslash-path negative probes now pass.
2. **C2 - extension-bound discovery evidence.** Preferred and no-equivalent discovery evidence used hard-coded `.md|.ps1|.dart` allowlists. Java/Python RED inputs were rejected despite canonical safe references. GREEN uses shared language-agnostic parsing for safe canonical repository paths with either an ordered line/range or an exact anchor, and a separate canonical search envelope. Java, Python, Rust, Kotlin, Java no-equivalent, and JSON search positives pass; traversal, empty path segment, and ambiguous line-plus-anchor negatives reject.
3. **C3 - markerless framework-neutral executable content.** Pinned source inspection primarily reconciled markers and route cardinality, so arbitrary executable content outside marked blocks could disappear. Before/between/after RED fixtures were accepted. GREEN constructs bounded responsibility blocks, marks their covered line ranges, and rejects nonblank/noncomment content outside them. All three placement negatives reject and the blank/comment-only positive passes.
4. **C4 - body-only owner binding.** Changed-owner detection required an added diff hunk to repeat an owner metadata anchor. Ordinary literal/control-flow/body changes inside an otherwise valid owner block therefore failed `responsibility-evidence-missing`. GREEN compares the exact bounded owner block at base and final trees, so body-only changes inherit that owner/path without fabricated metadata. Literal, control-flow, and ordinary-body positives bind with `IsChanged=true`; a real executable line after the block remains unowned and rejects.
5. **C5 - immutable JSON Boolean coercion.** Scope authority paths used `[bool]$value`; in PowerShell a non-empty JSON string such as `"false"` coerces to true. Strict negatives covered master spec, master plan, queue responsibility authority, attempt artifacts, reconciliation terminal and every chain node, terminal scope report/artifact/node, successful completion, blocker, cancellation, and non-applicability. GREEN uses one runtime-type predicate requiring `System.Boolean` and exact `$true` at every immutable authority check. `scope-engine.Tests.ps1` passes all string-false negatives.
6. **C6 - initial terminal-chain predecessor.** Both reconciliation and complete-scope chain loops bound only nodes after index 0 to their immediate predecessors. Index 0 could cite an arbitrary source artifact. Focused reconciliation and completion REDs accepted `forged-predecessor.md`. GREEN binds index 0 to immutable Task Provenance `source_artifact_reference` (`implementation-report.md`) and preserves later immediate-predecessor binding.
7. **C7 - coordinated terminal-chain SHA/evidence forgery.** Chain nodes were checked for internal SHA shape and self-consistent `source-diff`, allowing all nodes to repeat one coordinated forged pair. RED changed every node to `aaaa.../bbbb...` and remained authoritative. GREEN requires a canonical terminal `task_provenance` envelope and binds every node's task-base SHA, final-tree SHA, and evidence reference exactly to it in both reconciliation and completion paths. Both all-node forgery negatives reject.
8. **C8 - approved-plan mode authority.** Handoff validated approved plan ID/revision but read its mode before binding the plan's master-spec identity/revision to the source artifact. A foreign spec could therefore control greenfield regression ordering. Cross-spec ID/revision, foreign plan ID, stale plan revision, and draft-plan RED probes exposed the gap. GREEN requires one exact approved migration-master-plan whose `master_spec_id`, `master_spec_revision`, `master_plan_id`, and revision all equal the source Master Scope Context before mode is used. All five negatives reject; canonical greenfield omission remains valid.
9. **C9 - review checkout authority.** Pinned review verified that supplied SHAs resolved but did not bind `FinalTreeSha` to current authorized checkout HEAD, require the actual Git root, or require a clean checkout. A stale-but-existing final SHA approved after checkout advance. GREEN requires `SourceRoot` to resolve to the Git top-level, current `HEAD` to equal `FinalTreeSha`, and porcelain status including untracked files to be empty before pinned inspection. Stale-head, dirty-checkout, and nested-root negatives reject.
10. **I1 - raw Markdown verdict/control parsing.** Responsibility review and architecture-template checks read several verdict/adapter/behavior/policy fields from raw Markdown, so fenced or HTML-commented examples could satisfy controls. RED confirmed a fenced Architecture Conformance verdict produced zero responsibility diagnostics and a fenced template verdict passed; additional commented/fenced controls reproduced the same class. GREEN projects semantic visible Markdown before parsing responsibility verdicts, overall verdict/count, adapter kind, and architecture template verdict, behavior state, selected-unit policy, and adapter controls. Responsibility and architecture suites pass every new hidden-control negative.
11. **I2 - raw-token source-integrity registration.** `SourceIntegrityOnly` used `IndexOf` against scenario text, so a commented-out assertion still registered coverage. Strict RED commented a parse-valid one-line `Assert-Equal` and the mutated fixture incorrectly returned `PASS: migration framework (SourceIntegrityOnly)`. GREEN parses each scenario once, finds assertion `CommandAst` nodes, requires exact command name plus registration text, and excludes function bodies and uninvoked script-block expressions. The commented mutation now emits `Responsibility source-integrity coverage missing: post-implementation queue advance`, while active baseline registrations pass.

### Affected checks and corrected no-edit gate sequence

The affected responsibility, handoff, architecture, scope, and flexible-scope consumers passed during focused RED/GREEN work. The first corrected structural-gate run found the legitimate descriptive C1 scenario compatibility issue documented above; the sequence stopped, the focused positive/negative correction went RED to GREEN, and the entire corrected sequence was restarted from command 1 on one unchanged tree.

The restarted corrected 13 commands all exited `0`:

1. `responsibility-conformance.Tests.ps1`: `PASS: responsibility conformance contract`;
2. `responsibility-handoff.Tests.ps1`: `PASS: responsibility handoff scenarios`;
3. `target-conformance.Tests.ps1`: `PASS: target conformance scenarios`;
4. `structural-gate.Tests.ps1`: `PASS: structural gate (151 scenarios)`;
5. `architecture-review.Tests.ps1`: `PASS: architecture review scenarios`;
6. `scope-engine.Tests.ps1`: `PASS: scope engine behavioral scenarios`;
7. `flexible-scope-e2e.Tests.ps1`: `PASS: flexible migration scope orchestration (21 isolated E2E scenarios)`;
8. `validate-migration-framework.ps1 -Check Contracts`: `PASS: migration framework (Contracts)`;
9. `-Check Skills`: `PASS: migration framework (Skills)`;
10. `-Check Templates`: `PASS: migration framework (Templates)`;
11. `-Check All`: `PASS: migration framework (All)`;
12. `-Check SourceIntegrityOnly`: `PASS: migration framework (SourceIntegrityOnly)`;
13. `git diff --check`: exit `0`, with only informational LF-to-CRLF working-copy notices.

The final pre-amend focused command `validate-migration-framework.Tests.ps1 -ResponsibilityConformanceOnly` exited `0`: all 17/17 isolated behavioral mutations passed, every case retained source digest `1728E09B074E5EC505643425C2300BF99DE95AF6DC379CA583183EC0DDCAD91C`, and the terminal line was `PASS: responsibility conformance mutation scenarios`. This run also proved the I2 active-registration baseline and commented-registration negative.

### Pre-amend scope, AST, and diff audit

The wave delta contains exactly ten expected project files and zero extras:

- `aitoolkit/contracts/file-responsibility-conformance.md`;
- `aitoolkit/tests/scenarios/architecture-review.Tests.ps1`;
- `aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1`;
- `aitoolkit/tests/scenarios/responsibility-handoff.Tests.ps1`;
- `aitoolkit/tests/scenarios/scope-engine.Tests.ps1`;
- `aitoolkit/tests/validate-migration-framework.Tests.ps1`;
- `aitoolkit/tests/validate-migration-framework.ps1`;
- `aitoolkit/tests/validation/architecture-review.validation.ps1`;
- `aitoolkit/tests/validation/responsibility-conformance.validation.ps1`;
- `aitoolkit/tests/validation/scope-engine.validation.ps1`.

All nine changed PowerShell files parse with zero AST errors. The exact changed-file-set audit reports `changed=10 expected=10 missing=0 extra=0`. No Phase 2, `main/`, `issue/`, deferred discovery-renderer scope, or unrelated path changed. HEAD remains `c0acc0b823acfa7967400a188c4ba7d32cdc31ab`, `BASE..HEAD` count remains `1`, and the commit subject is unchanged. The persistent report and ledger are ignored evidence files and are not part of the project delta. Staging, amend, and exact-HEAD verification follow this checkpoint.

### Staged audit, amend, and exact-HEAD evidence

The explicit cache contained exactly the ten audited files (`cached=10 missing=0 extra=0`), `git diff --cached --check` exited `0`, and zero unstaged tracked paths remained. Immediately before amend, HEAD was still `c0acc0b823acfa7967400a188c4ba7d32cdc31ab`, Task 9 count was `1`, and the subject was exact. `git commit --amend --no-edit` preserved the sole Task 9 commit and produced exact HEAD `79462ad41c20c7529448be4e836fd95ac2ac49ad`.

Fresh checks on that exact HEAD, with no intervening project edit, produced:

- focused `validate-migration-framework.Tests.ps1 -ResponsibilityConformanceOnly`: exit `0`, all 17/17 mutations PASS, unchanged digest `1728E09B074E5EC505643425C2300BF99DE95AF6DC379CA583183EC0DDCAD91C`;
- `validate-migration-framework.ps1 -Check All`: exit `0`, `PASS: migration framework (All)`;
- `validate-migration-framework.ps1 -Check SourceIntegrityOnly`: exit `0`, `PASS: migration framework (SourceIntegrityOnly)`;
- `git diff --check HEAD^ HEAD`: exit `0`, no diagnostics;
- `git status --porcelain=v1 --untracked-files=all`: no output;
- `git rev-list --count 0cbb95afb835263ecf3b52b36f5ec0605f903435..HEAD`: `1`;
- cumulative Task 9 commit file count: `36`;
- subject: `test: cover responsibility conformance workflow`;
- HEAD remained exactly `79462ad41c20c7529448be4e836fd95ac2ac49ad` throughout final verification.

The final 9C+2I implementation scope is complete with no remaining scoped implementation concern. The default/full mutation suite was never invoked in this wave and remains controller-owned.

## Residual whole-review fix round 1 - lexical ownership, visible review authority, and executable registration reachability

### Clean start and confirmed root causes

This residual round began from exact clean HEAD `79462ad41c20c7529448be4e836fd95ac2ac49ad`. The fixed Task 9 base remained `0cbb95afb835263ecf3b52b36f5ec0605f903435`, the range count remained exactly one, and the subject remained `test: cover responsibility conformance workflow`.

- **C (shared C3/C4):** `Test-ArcCommentOnlySourceLine` trusted a line prefix alone, so executable `;danger()`, `--counter`, `*ptr = value`, and code after an inline block comment could be blessed as comment-only. `Get-ArcResponsibilitySourceBlocks` counted raw braces, so braces inside strings/comments could truncate or extend an owner block and hide later rogue code.
- **I1:** architecture-review template validation built semantic visible Markdown but still passed raw template slices into required-table, heading-order, selector, architecture, responsibility-evidence, activation, and selected-unit extraction. A second defect surfaced under GREEN: an empty required-table section returned `$null` without a missing-table diagnostic.
- **I2:** SourceIntegrity coverage registration excluded function definitions and scriptblock expressions only. A `CommandAst` under `if ($false)` or a class method therefore counted as active despite being unreachable/non-top-level.

### Strict focused RED -> GREEN

- **C RED:** the expanded real-Git architecture-review probe exited `1` at `legitimate language comment matrix (LF) should remain valid: responsibility-evidence-missing; responsibility-evidence-missing`. The matrix covered LF/CRLF, `#`, `//`, `-- `, `; `, `/* */`, `<!-- -->`, and `<# #>` comments, the four executable-prefix/trailing-code negatives, and braces inside strings/comments. **GREEN:** a stateful source lexer now distinguishes blank/comment-only content from code, continues scanning after block-comment closure, and emits brace-only structural text with strings/comments removed. Owner boundaries consume that lexical view. Both line endings, all negatives, brace-bound positives, rogue-after-owner detection, and existing body-only edits pass.
- **I1 RED:** the semantic template scenario exited `1` because `a fenced Master Scope Context table ... expected failure but passed`. **GREEN:** all review-template authority/control extraction now consumes `Get-ArcVisibleMarkdownText`; empty required-table sections emit a deterministic missing-table error. Fenced/commented Master Scope Context, Task Provenance, Architecture Responsibility Handoff, Responsibility Review Evidence, selector, architecture, and activation content all reject, while canonical visible content passes.
- **I2 RED:** `validate-migration-framework.Tests.ps1 -ResponsibilityConformanceOnly` exited `1` because the parse-valid literal-false mutation returned `PASS: migration framework (SourceIntegrityOnly)`. **GREEN:** registration commands must now have a root executable ancestor chain. Direct top-level commands pass; the two existing top-level LF/CRLF loops pass only through a statically nonempty, variable-free literal array. Literal-false branches, uninvoked functions, uninvoked scriptblocks, class methods, and every other non-approved ancestor shape reject. The complete focused suite exited `0`.

### Fresh affected, corrected, and focused evidence

Affected architecture-review scenarios exited `0`, including the new LF/CRLF real-Git lexical and semantic-visible authority matrix. The focused SourceIntegrity/mutation suite exited `0`, including all four parse-valid unreachable-registration negatives. All five changed PowerShell files parsed with zero AST errors and direct `git diff --check` exited `0` with only informational LF-to-CRLF working-copy notices.

The corrected 13-command sequence was restarted after the final implementation edit and ran serially on one unchanged tree. All commands exited `0`:

1. responsibility conformance: `PASS: responsibility conformance contract`;
2. responsibility handoff: `PASS: responsibility handoff scenarios`;
3. target conformance: `PASS: target conformance scenarios`;
4. structural gate: `PASS: structural gate (151 scenarios)`;
5. architecture review: `PASS: architecture review scenarios`;
6. scope engine: `PASS: scope engine behavioral scenarios`;
7. flexible scope E2E: `PASS: flexible migration scope orchestration (21 isolated E2E scenarios)`;
8. Contracts: `PASS: migration framework (Contracts)`;
9. Skills: `PASS: migration framework (Skills)`;
10. Templates: `PASS: migration framework (Templates)`;
11. All: `PASS: migration framework (All)`;
12. SourceIntegrityOnly: `PASS: migration framework (SourceIntegrityOnly)`;
13. direct `git diff --check`: exit `0` with only informational line-ending notices.

The final pre-amend `-ResponsibilityConformanceOnly` run exited `0`; all 17/17 named mutations passed at source digest `7893DF7998BC5E50E986624F4CC5E5291F1B81BB88E75AB879E962EB6E4EA241`, ending with `PASS: responsibility conformance mutation scenarios`. The default/full mutation suite was not invoked.

### Scope and pre-amend audit

The residual delta is exactly five approved project files: `aitoolkit/tests/scenarios/architecture-review.Tests.ps1`, `aitoolkit/tests/validate-migration-framework.Tests.ps1`, `aitoolkit/tests/validate-migration-framework.ps1`, `aitoolkit/tests/validation/architecture-review.validation.ps1`, and `aitoolkit/tests/validation/responsibility-conformance.validation.ps1`. No Phase 2, `main/`, `issue/`, or unrelated path changed. Staging, amend, and exact-HEAD evidence follow.

### Staged audit, amend, and exact-HEAD evidence

The explicit cache contained exactly those five files, cached diff-check exited `0`, and no unstaged tracked path remained. Immediately before amend, HEAD was `79462ad41c20c7529448be4e836fd95ac2ac49ad`, the Task 9 count was `1`, and the subject was exact. `git commit --amend --no-edit` produced `75d208469933ce44f711ecf5fe970c7ee328d5bb` while preserving the sole Task 9 commit and its subject.

Fresh verification on that exact HEAD, with no intervening project edit, produced:

- focused `-ResponsibilityConformanceOnly`: exit `0`, all 17/17 mutations PASS, digest `7893DF7998BC5E50E986624F4CC5E5291F1B81BB88E75AB879E962EB6E4EA241`;
- `-Check All`: exit `0`, `PASS: migration framework (All)`;
- `-Check SourceIntegrityOnly`: exit `0`, `PASS: migration framework (SourceIntegrityOnly)`;
- `git diff --check HEAD^ HEAD`: exit `0`, no diagnostics;
- porcelain status including untracked files: zero entries;
- `BASE..HEAD` count: `1`;
- cumulative Task 9 commit file count: `36`;
- subject: `test: cover responsibility conformance workflow`;
- HEAD remained `75d208469933ce44f711ecf5fe970c7ee328d5bb` throughout exact-HEAD verification.

Residual round 1 is complete with no remaining scoped implementation concern. The default/full mutation suite was not invoked and remains controller-owned.

## Residual whole-review fix round 2 - multiline literals, indented Markdown, and static foreach authority

### Clean start and root causes

The round began from exact clean HEAD `75d208469933ce44f711ecf5fe970c7ee328d5bb`, with fixed Task 9 base `0cbb95afb835263ecf3b52b36f5ec0605f903435`, range count `1`, and unchanged subject `test: cover responsibility conformance workflow`.

- **C:** the lexical scanner persisted block comments but reset string state on every line. Java text blocks and C# raw strings therefore exposed literal braces to owner-depth accounting; a literal `}` could truncate a valid owner, while a literal `{` could keep the owner open through later rogue code. Unterminated multiline literals had no explicit ambiguity state.
- **I1:** semantic visible Markdown removed fences, HTML comments, and protected inline spans, but retained CommonMark indented code. Four-space/tab-indented verdicts and controls could therefore satisfy executable template authority.
- **I2:** foreach reachability required exactly one nonempty `ArrayExpressionAst` without variables. It rejected provably nonempty comma literal arrays and integer literal ranges, while accepting dynamic command/subexpression bodies inside `@(...)`.

### Strict focused RED -> GREEN

- **C RED:** architecture-review exited `1` at the LF Java text-block positive with three `responsibility-evidence-missing` diagnostics. The new real-Git LF/CRLF matrix covers Java text-block and C# raw-string positives, rogue-after-owner negatives, and unterminated ambiguity. **GREEN:** the shared lexical scanner now carries matching three-or-more quote-run state across lines, removes multiline literal braces from structural depth, resumes scanning after the closing delimiter, and marks unterminated literal/comment state ambiguous. Pinned inventory rejects any ambiguity. The full architecture-review suite exited `0`.
- **I1 RED:** architecture-review exited `1` because `a four-space-indented overall verdict ... expected failure but passed`. **GREEN:** shared visible Markdown computes leading indentation columns with tab stops and blanks lines at four or more columns unless already inside a fence/comment or continuing a protected inline span. Four-space verdict/selector/table and tab adapter/heading cases reject; one-to-three-space visible headings and controls pass. The full architecture-review suite exited `0`.
- **I2 RED:** the focused runner exited `1`: comma literal arrays and `1..2` were incorrectly missing coverage, while `@(Get-Nothing)` and `@($(Get-Nothing))` incorrectly returned SourceIntegrity PASS. **GREEN:** a recursive AST literal predicate accepts only constant strings/scalars, static arrays, static `[pscustomobject]` hashtables, and exact integer literal ranges. Empty arrays, commands, subexpressions, variables, and uncertain contexts reject. Explicit `@(...)`, comma arrays, ranges, and both actual LF/CRLF registrations pass. The focused suite exited `0`.

### Affected and gate evidence

Affected architecture-review and focused SourceIntegrity/mutation scenarios passed. The delta contains exactly four approved PowerShell files, all four parse with zero AST errors, and direct diff-check exits `0` with only informational line-ending notices.

The corrected 13-command sequence was restarted after the final edit and ran serially on one unchanged tree. Every command exited `0`: responsibility conformance; responsibility handoff; target conformance; structural gate with 151 scenarios; architecture review; scope engine; flexible-scope E2E with 21 isolated scenarios; Contracts; Skills; Templates; All; SourceIntegrityOnly; and direct `git diff --check`.

The final pre-amend `-ResponsibilityConformanceOnly` run exited `0`; all 17/17 named mutations passed at digest `7E47DE3C4F7644715B70314CBD29F9A536149216FA50D03A0DF8476DDE702665`, ending with `PASS: responsibility conformance mutation scenarios`. The default/full mutation suite was not invoked.

### Pre-amend scope audit

The residual round changes exactly `aitoolkit/tests/scenarios/architecture-review.Tests.ps1`, `aitoolkit/tests/validate-migration-framework.Tests.ps1`, `aitoolkit/tests/validate-migration-framework.ps1`, and `aitoolkit/tests/validation/responsibility-conformance.validation.ps1`. No Phase 2, `main/`, `issue/`, or unrelated path changed. Staging, amend, and exact-HEAD evidence follow.

### Staged audit, amend, and exact-HEAD evidence

The explicit cache contained exactly those four project files, cached diff-check exited `0`, and no unstaged tracked path remained. Immediately before amend, HEAD was `75d208469933ce44f711ecf5fe970c7ee328d5bb`; the Task 9 range count was `1` and the subject was exact. `git commit --amend --no-edit` produced `a8f99d4b738d7c6795f389b00e76128692c32787` while preserving the sole Task 9 commit and subject.

Fresh verification on that exact HEAD produced:

- focused `-ResponsibilityConformanceOnly`: exit `0`, 17/17 mutations PASS at digest `7E47DE3C4F7644715B70314CBD29F9A536149216FA50D03A0DF8476DDE702665`;
- `-Check All`: exit `0`, `PASS: migration framework (All)`;
- `-Check SourceIntegrityOnly`: exit `0`, `PASS: migration framework (SourceIntegrityOnly)`;
- `git diff --check HEAD^ HEAD`: exit `0` with no diagnostics;
- porcelain status including untracked paths: zero entries;
- fixed-base range count: `1`;
- cumulative Task 9 commit file count: `36`;
- subject: `test: cover responsibility conformance workflow`;
- HEAD remained exactly `a8f99d4b738d7c6795f389b00e76128692c32787` throughout verification.

Residual round 2 is complete with no remaining scoped implementation concern. The default/full mutation suite was not invoked and remains controller-owned.

## Residual whole-review fix round 3 - redirected foreach collections and dominated registrations

### Clean start and root causes

The round began from exact clean HEAD `a8f99d4b738d7c6795f389b00e76128692c32787`, with fixed Task 9 base `0cbb95afb835263ecf3b52b36f5ec0605f903435`, range count `1`, and exact subject `test: cover responsibility conformance workflow`.

- **C1:** the static collection predicate recursively inspected expression values but skipped `CommandExpressionAst.Redirections`. At runtime, redirected explicit arrays, comma literal arrays, integer ranges, and nested redirected expressions produce zero foreach iterations, yet SourceIntegrity classified them as provably active. AST characterization confirmed that the redirection belongs to `CommandExpressionAst`; nested pipeline recursion also jumped directly to `.Expression`, bypassing that node.
- **C2:** executable-ancestor validation proved that a registration was inside a supported top-level foreach, but never related its containing pipeline to sibling statement order. A direct preceding `break`, `continue`, `return`, `throw`, or `exit` therefore dominated the registration while the registration still counted active.

### Strict focused RED -> GREEN

- **C1 RED:** the focused runner exited `1`; all four redirected collection forms incorrectly returned `PASS: migration framework (SourceIntegrityOnly)`. The test matrix retains the unredirected explicit-array, comma-array, and integer-range positives and adds an unredirected nested-array positive. **GREEN:** every recursively accepted AST node now rejects a nonempty `Redirections` property, top-level collection classification explicitly rejects redirected command expressions, and pipeline recursion visits the command-expression node instead of bypassing it. The first minimal attempt rejected the three top-level cases but left the nested case RED, which isolated the pipeline unwrap defect; after correcting that edge, the complete focused suite exited `0`.
- **C2 RED:** the focused runner exited `1`; registrations after each of direct `break`, `continue`, `return`, `throw`, and `exit` incorrectly satisfied SourceIntegrity. Conditional-preceding and trailing-transfer positives already passed. **GREEN:** the classifier records the command's containing statement, scans only earlier direct siblings in the same foreach `StatementBlockAst`, and rejects those five unconditional transfer AST types. It does not descend into conditional statements and does not inspect transfers after the registration. The complete focused suite exited `0`.

### Affected and gate evidence

Standalone `-Check SourceIntegrityOnly` exited `0`. Both changed PowerShell files parsed with zero Windows PowerShell 5.1 AST errors, and direct `git diff --check` exited `0`.

The corrected 13-command sequence ran serially on one unchanged tree and every command exited `0`:

1. responsibility conformance: `PASS: responsibility conformance contract`;
2. responsibility handoff: `PASS: responsibility handoff scenarios`;
3. target conformance: `PASS: target conformance scenarios`;
4. structural gate: `PASS: structural gate (151 scenarios)`;
5. architecture review: `PASS: architecture review scenarios`;
6. scope engine: `PASS: scope engine behavioral scenarios`;
7. flexible scope E2E: `PASS: flexible migration scope orchestration (21 isolated E2E scenarios)`;
8. Contracts: `PASS: migration framework (Contracts)`;
9. Skills: `PASS: migration framework (Skills)`;
10. Templates: `PASS: migration framework (Templates)`;
11. All: `PASS: migration framework (All)`;
12. SourceIntegrityOnly: `PASS: migration framework (SourceIntegrityOnly)`;
13. direct `git diff --check`: exit `0`.

The final pre-amend `-ResponsibilityConformanceOnly` run exited `0`; all 17/17 named mutations passed at digest `2DB58D62F5E359705277EE9B9BDB199E1CAED23CA759240CB480D3824CA57D0D`, ending with `PASS: responsibility conformance mutation scenarios`. The default/full mutation suite was not invoked.

### Pre-amend scope audit

The residual round changes exactly `aitoolkit/tests/validate-migration-framework.Tests.ps1` and `aitoolkit/tests/validate-migration-framework.ps1`: 74 insertions and 2 deletions. No Phase 2, `main/`, `issue/`, or unrelated project path changed. Staging, amend, and exact-HEAD evidence follow.

### Staged audit, amend, and exact-HEAD evidence

The explicit cache contained exactly the two audited project files, cached diff-check exited `0`, and no unstaged tracked project path remained. Immediately before amend, HEAD was `a8f99d4b738d7c6795f389b00e76128692c32787`; the fixed-base range count was `1` and the subject was exact. `git commit --amend --no-edit` produced `9f467ad09f5d3cf9a182cce2d6e8dc1edc2ad969` while preserving the sole Task 9 commit and its subject.

Fresh no-edit verification on that exact HEAD produced:

- focused `-ResponsibilityConformanceOnly`: exit `0`, all 17/17 mutations PASS at digest `2DB58D62F5E359705277EE9B9BDB199E1CAED23CA759240CB480D3824CA57D0D`;
- `-Check All`: exit `0`, `PASS: migration framework (All)`;
- `-Check SourceIntegrityOnly`: exit `0`, `PASS: migration framework (SourceIntegrityOnly)`;
- `git diff --check HEAD^ HEAD`: exit `0`;
- porcelain status including untracked paths: zero entries;
- fixed-base range count: `1`;
- cumulative Task 9 commit file count: `36`;
- subject: `test: cover responsibility conformance workflow`;
- HEAD before and after verification: `9f467ad09f5d3cf9a182cce2d6e8dc1edc2ad969`.

Residual round 3 is complete with no remaining scoped implementation concern. The default/full mutation suite was not invoked and remains controller-owned.

## Fresh whole-rereview fix wave - all 9 Critical and 5 Important findings

### Clean start and operating constraints

This wave began from exact clean HEAD `9f467ad09f5d3cf9a182cce2d6e8dc1edc2ad969`. The fixed Task 9 base remained `0cbb95afb835263ecf3b52b36f5ec0605f903435`, `BASE..HEAD` contained exactly one commit, and the subject remained `test: cover responsibility conformance workflow`. Each of the fourteen rereview claims was reproduced before its implementation change and taken through a focused RED -> GREEN boundary. The work was serial: no edit or second suite overlapped an active suite, no subagent/reviewer changed the tree, and no Phase 2, `main/`, or `issue/` path entered scope.

### Critical findings: confirmed RED -> GREEN

1. **C1 - complete derived review authority.** RED probes showed that an executable review could omit or contradict canonical Rule Resolution, Canonical Selector, Production Activation-path, behavior, Change Hygiene, architecture/tree/responsibility/verification verdicts, and Critical/Major counts without all omissions participating in the final decision. GREEN makes every gate and both counts cardinal, validates exact enums, derives behavior execution from the structural gates, derives the overall verdict from all visible gates plus finding counts, and requires the handoff cells to equal the visible derived architecture sub-verdicts. Contract, AI-review skill, and review template now describe the same executable formula.
2. **C2 - language-aware executable classification.** RED covered spaced C/JavaScript decrement and empty statements plus Rust/C# directives outside responsibility blocks; the language-blind prefix rules could treat valid executable syntax as comments. GREEN selects comment grammar by canonical path/language, preserves real SQL/Lisp/Python/PowerShell/C-family comments, and treats unsupported or ambiguous source conservatively so executable content is owned or rejected. LF and CRLF matrices pass.
3. **C3 - adapter-aware terminal task identity.** RED showed terminal scope artifacts could keep a Work Item in `task_unit` for a migration-unit adapter. GREEN derives terminal identity from the approved selector: selected migration-unit ID for `migration-unit`, Work Item ID for `generic`/`none`, in reconciliation and completion paths. Scope artifacts, scope engine, structural scenarios, and contract prose agree.
4. **C4 - shared semantic visible Markdown.** RED demonstrated that fenced, commented, or four-space/tab-indented authority-bearing headings/tables could inflate structural-gate and flexible-scope counts. GREEN routes those consumers through the shared semantic visible-Markdown projection while preserving canonical visible Markdown. Focused scope-artifact, scope-engine, structural, and end-to-end positives/negatives pass.
5. **C5 - commented production owners are inactive.** RED showed a wholly commented owner/route could enter pinned inventory and satisfy review. GREEN inventory consumes only active semantic responsibility metadata; comment-wrapped ordinary source remains inert and markerless executable production content still fails closed.
6. **C6 - commented verification evidence is inactive.** RED showed commented scenario/subject/provider/binding metadata could satisfy verification ownership. GREEN projects verification metadata through the same language-aware active-source model. Fully commented and block-commented evidence rejects; active language-valid evidence passes.
7. **C7 - JavaScript regex braces are inert.** RED showed braces inside a JavaScript regex literal could alter responsibility-block depth and swallow a later rogue statement. GREEN lexical state recognizes regex literals in expression context, including escapes/character classes, removes their braces from structural accounting, and leaves later rogue code unowned. LF/CRLF positives and negatives pass.
8. **C8 - task-base must be an ancestor.** RED accepted a reachable but unrelated task-base commit. GREEN requires `merge-base --is-ancestor <task-base> <final-head>` before pinned inventory acceptance; an unrelated reachable commit now rejects deterministically.
9. **C9 - named-block terminal dominance.** RED showed top-level/named-block registration after an unconditional `return`, `throw`, or `exit` could satisfy SourceIntegrity even though unreachable. GREEN applies same-block preceding terminal dominance to named blocks as well as supported loops, while conditional or trailing transfers do not create false negatives. Structural-gate registration coverage increased to 154 scenarios.

### Important findings: confirmed RED -> GREEN

10. **I10 - exact Change Hygiene reconciliation.** RED cases accepted noncanonical edited regions, repository-wide formatters, substring-only path operands, invalid unrelated-diff dispositions, missing/duplicate review rows, and confirmed unrelated diffs without an exact Major finding. GREEN validates every A/M/C/R/D changed path, canonical region, exact whitespace/quoted formatter operand, unrelated-diff enum, and bijective implementation/review rows; confirmed items require one exact Major finding and count/verdict agreement. A scoped rereview caught `src/admin_route.source.bak` falsely satisfying `src/admin_route.source`; that permanent negative went RED before exact operand parsing made it GREEN.
11. **I11 - handoff equality.** RED accepted a contradictory BLOCKED handoff under visible PASS verdicts. GREEN derives the architecture handoff and requires each cell to equal its visible source verdict; producer and validator now reject disagreement.
12. **I12 - destination-based copy classification.** RED treated a production-to-excluded copy like a production destination requiring ownership. GREEN parses copy records distinctly and classifies the destination by destination policy; rename continues to preserve old/new movement authority and deletion checkpoint semantics.
13. **I13 - safe canonical Git paths.** RED characterization exposed line-splitting/alias risks for spaces, Unicode, control characters, and a trailing source-root separator. GREEN consumes NUL-delimited `git diff --name-status -z`, preserves Unicode/spaces, canonicalizes separators and the authorized root, and rejects traversal, aliases, malformed rename/copy records, and control characters. The real-Git Unicode/space copy scenario passes.
14. **I14 - language-valid semantic marker encoding.** RED showed real Dart comment-wrapped `arc:` metadata was inert because consumers required invalid bare pseudo-statements. GREEN defines and consumes `// arc:<payload>` for C-family sources and `# arc:<payload>` for hash-comment languages, while ordinary commented-out legacy markers remain inert. Contract, code-migration skill, AI-review skill, and implementation template specify the encoding. Composed Dart, Java, JavaScript-module, Python, C#, and Rust LF/CRLF positives pass with matching inert negatives. A scoped language-table review added permanent PowerShell hash-comment and `.mjs`/`.cjs` slash-comment cases: both failed first, then passed after the extension tables were corrected.

One I14 GREEN run also exposed that a bare legacy route header could absorb following rogue code. The route is now a header only when its block carries active semantic metadata; the permanent boundary regression passes. No remaining Critical or Major finding was found in the subsequent fresh scoped and whole-delta rereviews.

### Compatibility corrections discovered by the corrected gate

The first corrected responsibility-conformance run stopped on canonical fixtures that predated mandatory Change Hygiene review reconciliation. The fixtures were updated, not weakened: the canonical review now has an exact PASS hygiene table and zero-Major sentinel; stale verification variants add their matching review row; migration-unit fixtures use the selected unit identity on both sides; and the unchanged-owner Git fixture uses the valid exact pair `notes.txt#DocumentationNote`. Each failure stopped the sequence, received an isolated correction, and restarted at command 1. The final sequence below ran on one unchanged tree.

### Fresh affected, corrected13, and focused17 evidence

Affected architecture-review, scope-engine, scope-artifacts, structural-gate, and SourceIntegrity checks passed before the corrected sequence. Both the scoped and whole-delta rereviews were clean before any gate beyond the authorized set was considered.

The final corrected 13-command sequence ran serially and every command exited `0`:

1. responsibility conformance: `PASS: responsibility conformance contract`;
2. responsibility handoff: `PASS: responsibility handoff scenarios`;
3. target conformance: `PASS: target conformance scenarios`;
4. structural gate: `PASS: structural gate (154 scenarios)`;
5. architecture review: `PASS: architecture review scenarios`;
6. scope engine: `PASS: scope engine behavioral scenarios`;
7. flexible scope E2E: `PASS: flexible migration scope orchestration (21 isolated E2E scenarios)`;
8. Contracts: `PASS: migration framework (Contracts)`;
9. Skills: `PASS: migration framework (Skills)`;
10. Templates: `PASS: migration framework (Templates)`;
11. All: `PASS: migration framework (All)`;
12. SourceIntegrityOnly: `PASS: migration framework (SourceIntegrityOnly)`;
13. direct `git diff --check`: exit `0`, with informational LF-to-CRLF working-copy notices only.

The final pre-amend focused command `validate-migration-framework.Tests.ps1 -ResponsibilityConformanceOnly` exited `0`: all 17/17 isolated behavioral mutations passed, each retained source digest `F6912DF9AEA7CE0021F3245E2DA38EDAA2012DBD1A80D5087C3BF53001BD4DD3`, and the terminal line was `PASS: responsibility conformance mutation scenarios`. The default/full mutation suite was never invoked in this wave and remains controller-owned.

### Pre-amend scope, AST, and diff audit

The wave delta is exactly the following 18 project files (1,125 insertions, 119 deletions), with zero untracked or out-of-scope project paths:

- `aitoolkit/contracts/file-responsibility-conformance.md`;
- `aitoolkit/contracts/target-structure-conformance.md`;
- `aitoolkit/skills/migration/code-migration/SKILL.md`;
- `aitoolkit/skills/shared/ai-review/SKILL.md`;
- `aitoolkit/templates/migration/implementation-report.md`;
- `aitoolkit/templates/migration/review-report.md`;
- `aitoolkit/tests/scenarios/architecture-review.Tests.ps1`;
- `aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1`;
- `aitoolkit/tests/scenarios/scope-artifacts.Tests.ps1`;
- `aitoolkit/tests/scenarios/scope-engine.Tests.ps1`;
- `aitoolkit/tests/scenarios/structural-gate.Tests.ps1`;
- `aitoolkit/tests/validate-migration-framework.Tests.ps1`;
- `aitoolkit/tests/validate-migration-framework.ps1`;
- `aitoolkit/tests/validation/architecture-review.validation.ps1`;
- `aitoolkit/tests/validation/responsibility-conformance.validation.ps1`;
- `aitoolkit/tests/validation/scope-artifacts.validation.ps1`;
- `aitoolkit/tests/validation/scope-engine.validation.ps1`;
- `aitoolkit/tests/validation/structural-gate.validation.ps1`.

All 12 changed PowerShell scripts parse with zero Windows PowerShell AST errors. Added-line hazard review found no debug/placeholder commands, and direct diff-check is clean. HEAD remains exact clean start `9f467ad09f5d3cf9a182cce2d6e8dc1edc2ad969`, `BASE..HEAD` count remains `1`, and the subject is exact. The persistent report and ledger are ignored evidence files outside the project delta. Explicit staging, amend, and exact-HEAD verification follow this checkpoint.

### Staged audit, amend, and exact-HEAD evidence

The explicit cache contained exactly the 18 audited project files (`cached=18 expected=18 missing=0 extra=0`), `git diff --cached --check` exited `0`, and zero unstaged tracked paths remained. Immediately before amend, HEAD was still `9f467ad09f5d3cf9a182cce2d6e8dc1edc2ad969`, the fixed-base range count was `1`, and the subject was exact. `git commit --amend --no-edit` preserved the sole Task 9 commit and produced exact HEAD `0f1174cce3df056dacbe049bdee575d977ef7ec7`.

Fresh no-edit verification on that exact HEAD produced:

- focused `validate-migration-framework.Tests.ps1 -ResponsibilityConformanceOnly`: exit `0`, all 17/17 mutations PASS with unchanged digest `F6912DF9AEA7CE0021F3245E2DA38EDAA2012DBD1A80D5087C3BF53001BD4DD3`;
- `validate-migration-framework.ps1 -Check All`: exit `0`, `PASS: migration framework (All)`;
- `validate-migration-framework.ps1 -Check SourceIntegrityOnly`: exit `0`, `PASS: migration framework (SourceIntegrityOnly)`;
- `git diff --check HEAD^ HEAD`: exit `0`, no diagnostics;
- `git status --porcelain=v1 --untracked-files=all`: zero entries;
- `git rev-list --count 0cbb95afb835263ecf3b52b36f5ec0605f903435..HEAD`: `1`;
- cumulative Task 9 commit file count: `36`;
- subject: `test: cover responsibility conformance workflow`;
- HEAD before and after verification: `0f1174cce3df056dacbe049bdee575d977ef7ec7`.

The fresh whole-rereview 9C+5I wave is complete with no remaining scoped implementation concern. The default/full mutation suite was never invoked and remains controller-owned.

## Fresh scoped-review residual wave: C1/C2/C4/I10

This residual wave began from exact clean HEAD `0f1174cce3df056dacbe049bdee575d977ef7ec7`; the fixed Task 9 base remains `0cbb95afb835263ecf3b52b36f5ec0605f903435`, with exactly one Task 9 commit and subject `test: cover responsibility conformance workflow`. Work remained confined to seven approved project PowerShell files. No Phase 2, `main/`, or `issue/` path changed.

### Confirmed residuals and strict RED -> GREEN

1. **C1 - executable review authority and handoff.** Focused negatives proved that a static-looking review could omit or contradict Rule Resolution, Canonical Selector, Production Activation, Behavior, Change Hygiene, architecture/tree/responsibility/verification verdicts, and exact Critical/Major counts unless every field participated in one derived state. GREEN centralizes that derivation, validates exact finding-table counts and overall conclusion, and prevents verification handoff from seeding from omitted, contradictory, non-approved, or nonzero-finding review evidence.
2. **C2 - persistent JavaScript/TypeScript template state.** RED showed multiline template literal braces could alter owner depth or swallow later rogue code. GREEN carries raw-template/interpolation/nested-template state across lines, treats raw braces as inert, resumes ordinary lexical analysis after closing delimiters, and fails closed at EOF for unterminated raw/interpolation state. The adversarial closing-backtick-then-division case initially failed because `/` was classified as a regex; emitting a neutral operand marker on template close made valid LF/CRLF division GREEN while ambiguity negatives remained blocking.
3. **C4 - semantic Selected Migration Unit authority.** RED cases showed fenced, HTML-commented, and indented headings/tables could influence conditional Selected Migration Unit detection. GREEN uses shared semantic-visible Markdown for heading cardinality and generic UNIT-row checks. LF/CRLF decoys remain inert, visible rogue rows produce the exact generic-adapter diagnostic, and the CRLF case asserts the rogue row is preserved byte-for-byte on disk. The row predicate also accepts optional CR defensively even though the structural caller normalizes report input before projection.
4. **I10 - exactly path-scoped formatter evidence.** RED accepted unrelated operands, aliases/traversal, subtree/repository-wide operands, extensionless command-word operands, arbitrary executables, and extensionless paths hidden in inline switches. GREEN tokenizes the complete command, requires a recognized formatter or explicit launcher grammar, accepts only the exact canonical target once, validates known typed option values, and rejects every remaining positional or path-bearing operand. A final independent rereview found separated path switches consuming the target and inverted `ruff`/`biome` grammar; permanent negatives now reject separated `--stdin-filepath`/`--ignore-path` and bare direct/wrapped/module forms, while direct, `npx`, and Python-module `ruff`/`biome format` positives pass.

The first affected flexible-scope E2E run exposed a canonical fixture that still rendered placeholder review controls. The producer fixture was updated to render the complete executable review state and exact zero counts; the 21-scenario suite then passed without weakening production validation.

### Fresh verification before amend

Affected responsibility-conformance, responsibility-handoff, structural-gate, and architecture-review suites passed after the final fixes. Architecture includes the C1 review derivation/handoff cases, C2 LF/CRLF template cases, and the complete I10 command matrix; structural gate ends with `PASS: structural gate (168 scenarios)`.

The corrected 13-command sequence was restarted after the final production edit and ran serially on one unchanged tree. Every command exited `0`:

1. responsibility conformance: `PASS: responsibility conformance contract`;
2. responsibility handoff: `PASS: responsibility handoff scenarios`;
3. target conformance: `PASS: target conformance scenarios`;
4. structural gate: `PASS: structural gate (168 scenarios)`;
5. architecture review: `PASS: architecture review scenarios`;
6. scope engine: `PASS: scope engine behavioral scenarios`;
7. flexible scope E2E: `PASS: flexible migration scope orchestration (21 isolated E2E scenarios)`;
8. Contracts: `PASS: migration framework (Contracts)`;
9. Skills: `PASS: migration framework (Skills)`;
10. Templates: `PASS: migration framework (Templates)`;
11. All: `PASS: migration framework (All)`;
12. SourceIntegrityOnly: `PASS: migration framework (SourceIntegrityOnly)`;
13. direct `git diff --check`: exit `0`, with informational line-ending notices only.

The final pre-amend focused `validate-migration-framework.Tests.ps1 -ResponsibilityConformanceOnly` run exited `0`: all 17/17 isolated behavioral mutations passed with unchanged source digest `CFEA48F5BCABB7A358E13FF0A8B9247FABF657D99111D3DA083423766B3EBD44`, ending with `PASS: responsibility conformance mutation scenarios`. The default/full mutation suite was not invoked. The final independent scoped rereview reported no remaining Critical, Major, or Important gap.

The pre-amend delta is exactly seven approved project files (704 insertions, 34 deletions), all seven parse with zero Windows PowerShell 5.1 AST errors, and direct diff-check is clean:

- `aitoolkit/tests/scenarios/architecture-review.Tests.ps1`;
- `aitoolkit/tests/scenarios/flexible-scope-e2e.Tests.ps1`;
- `aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1`;
- `aitoolkit/tests/scenarios/responsibility-handoff.Tests.ps1`;
- `aitoolkit/tests/scenarios/structural-gate.Tests.ps1`;
- `aitoolkit/tests/validation/responsibility-conformance.validation.ps1`;
- `aitoolkit/tests/validation/structural-gate.validation.ps1`.

The persistent report and ledger remain ignored evidence outside the project delta. Explicit staging, amend, and exact-HEAD verification follow this checkpoint.

### Staged audit, amend, and exact-HEAD evidence

The explicit cache contained exactly the seven audited project files (`cached=7 expected=7 missing=0 extra=0`), `git diff --cached --check` exited `0`, and zero unstaged tracked paths remained. Immediately before amend, HEAD was exact `0f1174cce3df056dacbe049bdee575d977ef7ec7`, its parent was the fixed base, `BASE..HEAD` count was `1`, and the subject was exact. `git commit --amend --no-edit` preserved the sole Task 9 commit and produced final HEAD `08f172da2d9ba61305c613a07c1a8463b396797b`.

Fresh no-edit verification on that exact HEAD produced:

- focused `validate-migration-framework.Tests.ps1 -ResponsibilityConformanceOnly`: exit `0`, all 17/17 mutations PASS with unchanged digest `CFEA48F5BCABB7A358E13FF0A8B9247FABF657D99111D3DA083423766B3EBD44`;
- `validate-migration-framework.ps1 -Check All`: exit `0`, `PASS: migration framework (All)`;
- `validate-migration-framework.ps1 -Check SourceIntegrityOnly`: exit `0`, `PASS: migration framework (SourceIntegrityOnly)`;
- `git diff --check HEAD^ HEAD`: exit `0`, no diagnostics;
- `git status --porcelain=v1 --untracked-files=all`: zero entries;
- parent: `0cbb95afb835263ecf3b52b36f5ec0605f903435`;
- `git rev-list --count 0cbb95afb835263ecf3b52b36f5ec0605f903435..HEAD`: `1`;
- cumulative Task 9 commit file count: `36`;
- subject: `test: cover responsibility conformance workflow`;
- HEAD before and after exact-HEAD verification: `08f172da2d9ba61305c613a07c1a8463b396797b`.

The fresh scoped-review residual wave is complete with no remaining scoped Critical, Major, or Important concern. The default/full mutation suite was never invoked and remains controller-owned.

## Fresh scoped lexer/formatter residual follow-up: C2a/C2b/I10

This follow-up began from exact clean HEAD `08f172da2d9ba61305c613a07c1a8463b396797b`; its parent remains fixed Task 9 base `0cbb95afb835263ecf3b52b36f5ec0605f903435`, the range count remains one, and the subject remains `test: cover responsibility conformance workflow`. Work is confined to the architecture-review scenario and responsibility-conformance validator. No Phase 2, `main/`, or `issue/` path changed.

### Strict RED -> GREEN and independent review

1. **C2a - significant JavaScript/TypeScript interpolation token state.** The first RED architecture run rejected valid LF/CRLF `${value++ / 2}`, `${value-- / 2}`, and multiline `${value` then `/ 2}` with `responsibility-evidence-missing`. GREEN carries explicit `RegexCanStart` state across interpolation lines and blank/comment spans, distinguishes even postfix `++`/`--` runs from odd runs ending in binary `+`/`-`, and emits neutral operand markers for completed string/template/regex literals. Permanent controls prove unmatched `{` and `}` inside real interpolation regex literals remain inert, while an unclosed regex fails closed.
2. **C2b - ordinary JavaScript/TypeScript string boundaries.** RED showed backticks inside `'...'` or `"..."` were treated as escapes and every ordinary string left open at EOL was accepted. GREEN recognizes only backslash escaping for JS/TS ordinary strings, accepts literal backticks and backslash-escaped quotes, and marks every unclosed ordinary string line ambiguous, including interpolation lines, under LF and CRLF.
3. **I10 - exact formatter command grammar.** RED accepted direct generic `format`/`fmt`, unknown and cross-tool options, generic package scripts, and unsupported module wrappers. GREEN first resolves an exact executable/wrapper/subcommand grammar, admits only explicit platform suffixes, applies per-formatter switch/scalar arity and value rules with ordinal option keys, and counts the canonical path exactly once only as a positional operand. The table-driven matrix covers every formatter ID and launcher branch plus unknown executable/suffix/option, wrong-case option, missing/wrong scalar, switch-with-value, option-value path, duplicate/foreign operands, and generic `format`/`fmt` negatives.

The first independent read-only review found three additional Critical boundaries: arbitrary executable suffix stripping, case-insensitive scalar-option lookup, and raw-prefix slash carry that mishandled carried unary keywords and `value+++`/`value---`. A second strict RED reproduced all three. The final implementation uses an explicit permitted suffix set, ordinal option-key membership, and carried regex-start token category. The independent re-review found all prior Critical and Important findings resolved, no new Critical or Important issue, and returned `Ready - Yes`.

### Fresh verification before amend

Affected responsibility-conformance, responsibility-handoff, and architecture-review suites exited `0`; architecture ends with `PASS: architecture review scenarios` and includes the full LF/CRLF/adversarial lexer and formatter grammar matrix.

The corrected 13-command sequence was restarted after the final production edit and ran serially on one unchanged tree. Commands 1-12 all exited `0`: responsibility conformance; responsibility handoff; target conformance; structural gate with 168 scenarios; architecture review; scope engine; flexible-scope E2E with 21 isolated scenarios; Contracts; Skills; Templates; All; and SourceIntegrityOnly. The wrapper promoted Git's informational LF-to-CRLF stderr notice during command 13, so the exact direct `git diff --check` was immediately rerun on the unchanged tree and exited `0` with warnings only.

The only authorized mutation selector, `validate-migration-framework.Tests.ps1 -ResponsibilityConformanceOnly`, exited `0`: all 17/17 isolated mutations passed with unchanged source digest `66CB0C0C3A666731F6AADE1DBDC620AA60476801E03161EC25981643B1B23065`, ending with `PASS: responsibility conformance mutation scenarios`. The default/full mutation suite was not invoked.

The pre-amend delta is exactly two approved project files (483 insertions, 128 deletions), and both parse with zero Windows PowerShell 5.1 AST errors:

- `aitoolkit/tests/scenarios/architecture-review.Tests.ps1`;
- `aitoolkit/tests/validation/responsibility-conformance.validation.ps1`.

Direct diff-check is clean, the pre-amend HEAD/parent/range/subject audit is exact, and the persistent report and ledger remain ignored evidence outside the project delta. Explicit staging, amend, and exact-HEAD verification follow this checkpoint.

### Staged audit, amend, and exact-HEAD evidence

The explicit cache contained exactly the two audited project files (`cached=2 expected=2 missing=0 extra=0`), `git diff --cached --check` exited `0`, and zero unstaged tracked paths remained. Immediately before amend, HEAD was exact `08f172da2d9ba61305c613a07c1a8463b396797b`, its parent was the fixed base, `BASE..HEAD` count was `1`, and the subject was exact. `git commit --amend --no-edit` preserved the sole Task 9 commit and produced final HEAD `19e044d5576394ec4b68cb02b099b3ddc3453809`.

Fresh no-edit verification on that exact HEAD produced:

- focused `validate-migration-framework.Tests.ps1 -ResponsibilityConformanceOnly`: exit `0`, all 17/17 mutations PASS with unchanged digest `66CB0C0C3A666731F6AADE1DBDC620AA60476801E03161EC25981643B1B23065`;
- `validate-migration-framework.ps1 -Check All`: exit `0`, `PASS: migration framework (All)`;
- `validate-migration-framework.ps1 -Check SourceIntegrityOnly`: exit `0`, `PASS: migration framework (SourceIntegrityOnly)`;
- `git diff --check HEAD^ HEAD`: exit `0`, no diagnostics;
- `git status --porcelain=v1 --untracked-files=all`: zero entries;
- parent: `0cbb95afb835263ecf3b52b36f5ec0605f903435`;
- `git rev-list --count 0cbb95afb835263ecf3b52b36f5ec0605f903435..HEAD`: `1`;
- cumulative Task 9 commit file count: `36`;
- subject: `test: cover responsibility conformance workflow`;
- HEAD before and after exact-HEAD verification: `19e044d5576394ec4b68cb02b099b3ddc3453809`.

The fresh scoped lexer/formatter residual follow-up is complete with no remaining scoped Critical, Major, or Important concern. The default/full mutation suite was never invoked and remains controller-owned.

## Fresh token/context and ordinal-case follow-up: C2a/I10

This follow-up began from exact clean HEAD `19e044d5576394ec4b68cb02b099b3ddc3453809`; its parent remains fixed Task 9 base `0cbb95afb835263ecf3b52b36f5ec0605f903435`, the range count remains one, and the subject remains `test: cover responsibility conformance workflow`. Work is confined to the architecture-review scenario and responsibility-conformance validator. No Phase 2, `main/`, or `issue/` path changed.

### Confirmed root causes, architectural ruling, and strict RED -> GREEN

1. **C2a - JavaScript/TypeScript slash eligibility is token/context state.** Strict LF/CRLF RED proved that raw-suffix eligibility left regex braces structural at statement positions after `if (...)` and `do`, misclassified `else /{/`, left spread-context `/}/g` structural inside nested template interpolation, and did not fail closed for the corresponding unterminated statement regex. The permanent matrix covers `if (...) /}/`, `else /{/`, `do /}/`, `[... /}/g]`, paired division after value-ending parentheses/member access/postfix update/spread values, odd `+++`/`---` operator runs, nested templates, an unterminated fail-closed case, and a closed regex followed by later rogue code.

   **Architectural ruling:** raw source-suffix regex eligibility is rejected. The lexer now carries an explicit per-root/per-interpolation code state with token category, regex-start eligibility, pending control-header state, and a parenthesis-context stack. Control-header closes, statement prefixes, spread, member access, postfix/update runs, operands, operators, and delimiters transition that state explicitly; nested template interpolation owns its own state and returns an operand to its parent when closed. String, template, and regex literals remain inert, while unterminated lexical state remains ambiguous and therefore fails closed.

2. **I10 - formatter grammar is ordinal at every grammar position.** Strict RED accepted uppercase or mixed executable, wrapper, module flag, and subcommand variants including `PRETTIER`, `Prettier`, `NPX`, `ruff FORMAT`, `python -M`, `npm EXEC`, `dotnet CSHARPIER`, and `GO FMT`. GREEN removes executable normalization and uses ordinal membership for executable suffixes, launcher words, module flags, formatter names, and subcommands. Canonical lower-case command forms remain valid; option keys retain their existing ordinal enforcement.

The final strict RED architecture run failed on both LF and CRLF statement/spread structural-token assertions, the `else` ownership case, the unterminated fail-closed assertion, and all eight case-variant command negatives. After the state-machine and ordinal-grammar implementation, the same unchanged tests passed.

### Fresh verification before amend

Affected responsibility-conformance, responsibility-handoff, and architecture-review suites exited `0`; architecture includes the fresh C2a LF/CRLF token-output and I10 exact-case matrix and ends with `PASS: architecture review scenarios`.

The corrected 13-command sequence ran serially on one unchanged tree and all 13 commands passed: responsibility conformance; responsibility handoff; target conformance; structural gate with 168 scenarios; architecture review; scope engine; flexible-scope E2E with 21 isolated scenarios; Contracts; Skills; Templates; All; SourceIntegrityOnly; and direct `git diff --check` with informational line-ending notices only. The terminal checkpoint was `PASS: corrected 13/13 serial gates`.

The only authorized mutation selector, `validate-migration-framework.Tests.ps1 -ResponsibilityConformanceOnly`, exited `0`: all 17/17 isolated mutations passed with unchanged source digest `A381C0A1A467B1B0728A42E88AA1305738E2CF7B028B0EC0037D60A77FF15848`, ending with `PASS: responsibility conformance mutation scenarios`. The default/full mutation suite was not invoked.

The pre-amend delta is exactly two approved project files (342 insertions, 53 deletions), and both parse with zero Windows PowerShell 5.1 AST errors:

- `aitoolkit/tests/scenarios/architecture-review.Tests.ps1`;
- `aitoolkit/tests/validation/responsibility-conformance.validation.ps1`.

Direct diff-check is clean, pre-amend HEAD/parent/range/subject are exact, and the persistent report and ledger remain ignored evidence outside the project delta. Explicit staging, amend, and exact-HEAD verification follow this checkpoint.

### Staged audit, amend, and exact-HEAD evidence

The explicit cache contained exactly the two audited project files (`cached=2 expected=2 missing=0 extra=0`), `git diff --cached --check` exited `0`, and zero unstaged tracked paths remained. Immediately before amend, HEAD was exact `19e044d5576394ec4b68cb02b099b3ddc3453809`, its parent was the fixed base, `BASE..HEAD` count was `1`, and the subject was exact. `git commit --amend --no-edit` preserved the sole Task 9 commit and produced final HEAD `9ba7a1f81b6f029eadc321ac3b601a40ade22a17`.

Fresh no-edit verification on that exact HEAD produced:

- focused `validate-migration-framework.Tests.ps1 -ResponsibilityConformanceOnly`: exit `0`, all 17/17 mutations PASS with unchanged digest `A381C0A1A467B1B0728A42E88AA1305738E2CF7B028B0EC0037D60A77FF15848`;
- `validate-migration-framework.ps1 -Check All`: exit `0`, `PASS: migration framework (All)`;
- `validate-migration-framework.ps1 -Check SourceIntegrityOnly`: exit `0`, `PASS: migration framework (SourceIntegrityOnly)`;
- `git diff --check HEAD^ HEAD`: exit `0`, no diagnostics;
- `git status --porcelain=v1 --untracked-files=all`: zero entries;
- parent: `0cbb95afb835263ecf3b52b36f5ec0605f903435`;
- `git rev-list --count 0cbb95afb835263ecf3b52b36f5ec0605f903435..HEAD`: `1`;
- cumulative Task 9 commit file count: `36`;
- subject: `test: cover responsibility conformance workflow`;
- HEAD before and after exact-HEAD verification: `9ba7a1f81b6f029eadc321ac3b601a40ade22a17`.

The fresh token/context and ordinal-case follow-up is complete. The default/full mutation suite was never invoked and remains controller-owned.

## Final JavaScript/TypeScript typed lexical-model follow-up: C2a/C2b

This final follow-up began from exact clean HEAD `9ba7a1f81b6f029eadc321ac3b601a40ade22a17`. Its parent remains fixed Task 9 base `0cbb95afb835263ecf3b52b36f5ec0605f903435`, `BASE..HEAD` remains one commit, and the subject remains `test: cover responsibility conformance workflow`. Work is confined to the architecture-review scenario and responsibility-conformance validator; I10 remained clean and was not changed.

### Confirmed findings and strict RED -> GREEN evidence

The first unchanged-production LF/CRLF aggregate RED exited `1` with 18 failures spanning all five reviewed model gaps:

1. a typed block close must permit a statement-position regex while an object-literal close must preserve division;
2. `for await` must preserve its pending control-header identity through `await`;
3. `break`/`continue` labels and `debugger` must apply restricted-production EOL/ASI state without changing an ordinary operand continuation into statement start;
4. TypeScript postfix non-null `!` must preserve an operand, while JavaScript/TypeScript prefix `!` and binary `!=` remain operators;
5. ordinary single- and double-quoted JavaScript strings may cross LF/CRLF only through an escaped line continuation; an unescaped EOL remains ambiguous and fails closed.

The first GREEN closed those witnesses, but independent read-only review found four model residuals. A second aggregate RED captured 16 failures (eight LF and eight CRLF): the declaration-body latch was consumed by a parameter-default object; `async`/`export` declaration position was lost; binding-less `catch` and `case`/ordinary labels did not open statement blocks; semicolons inside a `for` header incorrectly entered statement start; and an empty physical line after one escaped string EOL bypassed the continued-string scanner. The depth-scoped implementation closed the full matrix, but a final review found contextual-keyword ambiguity. A third aggregate RED captured exactly six failures (three LF and three CRLF): `catch`/`case`/`default` object keys falsely changed brace context, and `async:` could not resolve as a label, leaving its following regex brace structural and allowing later rogue code to be swallowed.

The final unchanged matrix passed all original, residual, and contextual cases under LF and CRLF. Each behavior has language-valid positive controls plus the relevant division, rogue/fail-open, or unescaped/unterminated fail-closed control. Node `v24.18.0` accepted every JavaScript witness, including declaration defaults and modifiers, binding-less catch, case/ordinary labels, `for (;; {} / 2)`, object property keys, async labels, and quoted continuations. A TypeScript compiler was not installed, so the TypeScript-only postfix non-null fixture was verified by the lexer matrix rather than a compiler invocation.

### Architectural ruling

JavaScript/TypeScript slash eligibility and structural ownership are a typed lexical-state problem, not a raw-source suffix problem. Raw-string and per-spelling exceptions remain rejected. Every root and template interpolation owns an independent code state containing regex-start and statement-start eligibility, typed parenthesis and brace stacks, depth-scoped declaration contexts, control-header identity (including `for-header`/`for-await`), restricted-production state, conditional/label state, and operator fixity. Block, object, and value-block closes transition differently; function/class bodies are claimed only at their recorded delimiter depth; contextual words resolve from statement position and colon; and ordinary quoted continuations carry explicit quote/start/code-state until closure or an ambiguous physical EOL/EOF. Literal bodies remain structurally inert, and any unresolved lexical boundary fails closed.

The final independent rereview returned CLEAN with `0 Critical / 0 Major / 0 Minor` in requested C2a/C2b scope. Its exact WinPS 5.1 LF/CRLF probes were 10/10, Node accepted all contextual witnesses, both changed scripts parsed cleanly, direct diff-check was clean, and only the expected two files were modified.

### Fresh verification before amend

Affected responsibility-conformance, responsibility-handoff, and architecture-review suites each exited `0`; architecture includes the full prior and new LF/CRLF adversarial matrix and ends with `PASS: architecture review scenarios`.

The corrected 13-command sequence was restarted after the final production edit and ran serially on one unchanged tree. All commands exited `0`: responsibility conformance; responsibility handoff; target conformance; structural gate with 168 scenarios; architecture review; scope engine; flexible-scope E2E with 21 isolated scenarios; Contracts; Skills; Templates; All; SourceIntegrityOnly; and direct `git diff --check` with informational LF-to-CRLF notices only.

The only authorized mutation selector, `validate-migration-framework.Tests.ps1 -ResponsibilityConformanceOnly`, exited `0`: all 17/17 isolated mutations passed with unchanged source digest `3F857E9CDA59FD270CC2290C1DF2750B1044B65F277E98C9DCDFAD8101B7A494`, ending with `PASS: responsibility conformance mutation scenarios`. The default/full mutation suite was not invoked.

The pre-amend delta is exactly two approved project files (915 insertions, 26 deletions), and both parse with zero Windows PowerShell 5.1 AST errors:

- `aitoolkit/tests/scenarios/architecture-review.Tests.ps1`;
- `aitoolkit/tests/validation/responsibility-conformance.validation.ps1`.

Direct diff-check is clean; pre-amend HEAD, fixed parent, one-commit range, 36-file cumulative commit scope, and subject are exact. The persistent report and ledger remain ignored evidence outside the project delta. Explicit staging, amend, and exact-HEAD verification follow this checkpoint.

### Staged audit, amend, and exact-HEAD evidence

The explicit cache contained exactly the two audited project files (`cached=2 expected=2 missing=0 extra=0`), `git diff --cached --check` exited `0`, and zero unstaged tracked paths remained. Immediately before amend, HEAD was exact `9ba7a1f81b6f029eadc321ac3b601a40ade22a17`, its parent was the fixed base, `BASE..HEAD` count was `1`, and the subject was exact. `git commit --amend --no-edit` preserved the sole Task 9 commit and produced final HEAD `75fa8c9c0a8b656aa729a90bbe27e9ae995cae95`.

Fresh no-edit verification on that exact HEAD produced:

- focused `validate-migration-framework.Tests.ps1 -ResponsibilityConformanceOnly`: exit `0`, all 17/17 mutations PASS with unchanged digest `3F857E9CDA59FD270CC2290C1DF2750B1044B65F277E98C9DCDFAD8101B7A494`;
- `validate-migration-framework.ps1 -Check All`: exit `0`, `PASS: migration framework (All)`;
- `validate-migration-framework.ps1 -Check SourceIntegrityOnly`: exit `0`, `PASS: migration framework (SourceIntegrityOnly)`;
- `git diff --check HEAD^ HEAD`: exit `0`, no diagnostics;
- `git status --porcelain=v1 --untracked-files=all`: zero entries;
- parent: `0cbb95afb835263ecf3b52b36f5ec0605f903435`;
- `git rev-list --count 0cbb95afb835263ecf3b52b36f5ec0605f903435..HEAD`: `1`;
- cumulative Task 9 commit file count: `36`;
- subject: `test: cover responsibility conformance workflow`;
- HEAD before and after exact-HEAD verification: `75fa8c9c0a8b656aa729a90bbe27e9ae995cae95`.

The final JavaScript/TypeScript typed lexical-model follow-up is complete with no remaining scoped review finding. The default/full mutation suite was never invoked and remains controller-owned.

## Final whole-review authority/handoff/range/adapter wave: C1/C2/C3/I1

This wave began from exact clean HEAD `75fa8c9c0a8b656aa729a90bbe27e9ae995cae95`; the fixed parent remains `0cbb95afb835263ecf3b52b36f5ec0605f903435`, the Task 9 range remains one commit, and the subject remains `test: cover responsibility conformance workflow`. Scope is exactly the four final whole-review findings plus their directly exposed producer/consumer residuals. No Phase 2, `main/`, or `issue/` path changed.

### Confirmed root causes and architectural corrections

1. **C1 - initial migration selection consumes approved pre-edit authority.** The obsolete/synthetic queue-responsibility handoff was removed from the initial selection boundary. Scope selection now derives exact ordered selector and responsibility/verification-owner authority from the approved master plan and canonical technical design. It validates canonical selector identity, unversioned authority plus positive revision, strict resolved approval, exact mode, parent/root mapping, plan-wide ordering and mode consistency, and ordinal uniqueness. Canonical design rows accept `test` and every documented boundary kind; `Conformance=yes` passes, `blocked` fails, and `no` passes only through one exact, unique, non-placeholder approved `DEV-*` join. Real rendered master-plan/design -> selection positives cover canonical `yes` and approved `no`; stale, foreign, duplicate, reordered, malformed, mixed-valid/malformed, placeholder-deviation, cross-category, and reused-owner attacks fail before selection. Post-review `Architecture Responsibility Handoff` remains a distinct downstream artifact and never authorizes pre-edit selection.
2. **C2 - immutable handoff evidence and terminal-chain authority are separate values.** `Architecture Responsibility Handoff.Evidence References` now remains the exact source-diff reference from review through verification, parity, optional regression, KB, terminal report, and scope completion. A separate Terminal Chain Reference and Evidence Index bind the mode-aware final assurance artifact. Producers no longer overload one parameter for both values; validators preserve plan order and reject swapped, missing, reordered, source-diff-as-chain, or chain-as-handoff mutations. The real KB template was corrected so it instructs producers to preserve source-diff rather than resolve the handoff cell to a terminal artifact.
3. **C3 - source ownership uses explicit paired, non-overlapping ranges.** Every active range is delimited by exact case-sensitive `@ownership-begin RESP-*` / `@ownership-end RESP-*` whole-line sentinels. There is no brace, indentation, first-symbol, or EOF inference, including neutral `.source` fixtures. One parser owns both coverage and metadata. Imports, re-exports, module docstrings, future/use-strict/package/namespace/preprocessor directives, classes, functions, and all other executable module content must be inside exactly one range; only lexical preamble may remain outside. Real LF/CRLF JavaScript and Python modules cover imports plus multiple public symbols, adjacent ranges, rogue/outside code, malformed/orphan/mismatched/duplicate/nested/crossed delimiters, and active unknown or argument-less `@ownership-*` sentinels. String, disabled-comment, and block-comment lookalikes remain inert.
4. **I1 - Selected Migration Unit is adapter-conditional and the public Gerrit gate is composed.** `migration-unit` requires exactly one canonical ten-field selected-unit envelope. `task | story | package | phase | milestone | none` requires zero such sections and uses `Master Scope Context.Work Item ID` as generic delivery identity. The public Gerrit validator now requires the approved plan plus the ordered review -> verification -> parity -> optional regression -> KB -> Gerrit chain, runs the canonical handoff gate on every edge, intrinsically validates KB/Gerrit lifecycle and provenance, and binds the selected tuple and SHA/source-diff lineage to upstream authority rather than accepting paired equality. Incremental and greenfield real-template positives plus generic/none positives pass; coherent paired unit, plan, approval, mode, foundation, baseline, trace, provenance, lifecycle, and ordering forgeries fail. The Gerrit skill retains the compatibility phrase `same migration_unit_id` inside the stronger approved-plan-to-chain requirement.

### Review-driven residual fixes

The first final scoped review found `0 Critical / 3 Important / 0 Minor`: scope-engine used a lossy/noncanonical design projection, selector authority was incomplete, and KB -> Gerrit equality did not establish intrinsic plan/review lineage. A C1-only adversarial follow-up found `0 Critical / 2 Important / 0 Minor`: malformed duplicate/placeholder deviation rows and permissive selector approval/mode/plan-wide consistency still failed open. Strict RED probes reproduced every attack before implementation; the canonical full-row, DEV-join, selector-map, composed-chain, and intrinsic-envelope corrections above closed them. Earlier provisional KB-template and ownership-namespace gaps were likewise captured by real-template and LF/CRLF tests before GREEN.

### Verification and invocation record before amend

Affected scenario suites are GREEN: scope engine, responsibility conformance, responsibility handoff, scope artifacts, architecture review, focused flexible-scope S06 and S20, and the full 21-scenario Flexible Scope E2E. Architecture review ended `PASS: architecture review scenarios` with 304 emitted PASS lines and zero FAIL lines. The full E2E ended `PASS: flexible migration scope orchestration (21 isolated E2E scenarios)`.

One unsupported invocation was made and is recorded explicitly: `validate-migration-framework.Tests.ps1 -ContractsOnly`. That wrapper does not authorize the selector; it entered its default path and exited `1` after about 34 seconds on an isolated-child PowerShell dot-source infrastructure error. It was not treated as contract evidence, was not restarted, and an immediate audit found the same 28 intended project files with clean direct diff-check. From that point forward only the exact command whitelist was used.

On the later frozen tree, corrected gates 1-10 were GREEN through Templates, then main `-Check All` exposed one static compatibility RED: `Shared Gerrit standalone migration invocation missing: same migration_unit_id`. The strengthened Gerrit wording had accidentally removed that pinned phrase. Restoring it inside the stronger approved-plan/ordered-chain rule made focused `-Check All` GREEN. Because the only final edit was wording in the Gerrit skill, the preserved behavioral evidence was not duplicated. Post-edit affected checks are all GREEN: main `-Check All`, main `-Check Skills`, responsibility-handoff scenarios, main `-Check SourceIntegrityOnly`, and direct `git diff --check` (informational LF-to-CRLF warnings only).

A user interruption occurred while an unnecessary corrected-sequence restart was beginning. The unified command was aborted without a captured terminal. A read-only process audit confirmed no surviving arc-phase1 PowerShell/test process; the already-complete Flexible21 session was closed after its recorded exit-0 sentinel. HEAD remained `75fa8c9`, exactly the same 28 intended project paths remained modified, and direct diff-check remained clean. No duplicate long/full run followed. Fresh scoped review, explicit staging/amend, and exact-HEAD verification follow this checkpoint.

### Fresh scoped residual review and C1 closure

The required fresh read-only scoped review returned `0 Critical / 3 Important / 0 Minor`, `NOT READY`. It confirmed three residual model gaps: the shared pre-edit design helper rejected canonical root-level repository paths while accepting forged classification authority/evidence and the rendered consumer mishandled the canonical test-owner sentinel; the public Gerrit gate depended on a test-only `Approved Migration Unit Authority` heading absent from real producers; and parity/regression overall PASS rows were not derived from their scenario rows. C2 and C3 remained clean. No review process edited, staged, or committed the tree and no broad/default suite ran.

C1 strict unit RED exited `1` with exactly five assertions: valid root-level authority was blocked, while forged classification authority and forged classification evidence both selected and emitted the wrong reason. GREEN now reuses the canonical repository-path normalizer, applies the same classification-authority/evidence grammar as approved discovery/design production, preserves root-level owner/target/evidence paths, and handles `Boundary Kind=test` with exact `Verification Owner References=not-applicable` in the rendered validator. Permanent unit controls include root-level positive plus authority/evidence forgeries. The first two rendered S06 attempts failed for test-fixture reasons (a noncontiguous inserted matrix row, then a semicolon where the canonical ordered owner list uses commas); neither was accepted as behavioral evidence. After correcting only those fixtures, frozen-tree S06 session `23989` exited `0` with `PASS: flexible migration scope orchestration (1 selected isolated E2E scenario(s))`, covering real rendered root-level, classification-forgery, and test-owner authority. `scope-engine.Tests.ps1` likewise exits `0` with `PASS: scope engine behavioral scenarios`.

The remaining two Important findings are being repaired together: master-plan selector authority plus the real step-10 implementation Selected row replace the synthetic heading, and canonical parity/regression scenario rows derive and bind their overall verdicts before Knowledge Base/Gerrit execution. Their RED/GREEN terminal, final scoped rereview, stage/amend, and exact-HEAD evidence follow.

### I1 real-origin, intrinsic-verdict, and evidence-lineage closure

The public Gerrit gate no longer consumes the test-only `Approved Migration Unit Authority` heading. A strict whitelist-only RED exited `1` at the canonical migration-unit positive with `responsibility-evidence-missing`, proving the old gate rejected the real producer shape once that invented heading was removed. GREEN binds approved-plan `Delivery Adapter Selection` authority to the exact approved/complete/human step-10 implementation artifact, including canonical adapter evidence, Change Hygiene task/SHA provenance, and all ten Selected Migration Unit fields. Every downstream review, verification, parity, optional regression, KB, and Gerrit artifact must preserve that exact origin; generic/none adapters require the selected-unit section to be absent.

Parity and regression now consume exact localized scenario tables, derive aggregate verdicts with `BLOCKED > FAIL > PASS`, reject aggregate/scenario contradictions, and require regression to preserve the parity verdict and evidence lineage. The whitelist-only responsibility-handoff suite exited `0` with `PASS: responsibility handoff scenarios` after positives for incremental, greenfield, generic, and none plus missing/duplicate/malformed/fail/blocked/placeholder and coherent all-chain authority attacks.

The first frozen-tree rereview after those fixes returned `0 Critical / 1 Important / 0 Minor`, `NOT READY`: the gate rejected the canonical regression evidence-enrichment form while accepting a concrete but unrelated Gerrit evidence cell. A final strict RED exited `1` with `public Gerrit gate accepts canonical regression evidence enriched from exact parity evidence should pass but got: responsibility-evidence-missing`. GREEN now accepts regression evidence only when it is exact parity evidence or the ordinal form `<parity evidence>; <non-whitespace regression evidence>`, and it requires Gerrit evidence to equal the mode-dependent immediate predecessor: regression evidence for incremental and parity evidence for greenfield. Permanent positives and foreign/mismatched incremental and greenfield negatives pass. The final fresh read-only scoped rereview returned `0 Critical / 0 Important / 0 Minor`, `READY`; no review process edited, tested, staged, or committed the tree.

### Final frozen verification before amend

On the final unchanged tree, the affected responsibility-handoff and responsibility-conformance suites both exited `0`, ending `PASS: responsibility handoff scenarios` and `PASS: responsibility conformance contract`. Scope-engine and rendered S06 remained GREEN from the same architectural wave. Post-final-edit main `-Check All` and `-Check SourceIntegrityOnly` both exited `0`; the earlier frozen `-Check Skills` result remains GREEN because no later skill file changed. Direct `git diff --check` exited `0` with informational LF-to-CRLF warnings only.

The pre-amend project delta is exactly the 28 approved paths, with 3,696 insertions and 435 deletions. HEAD remains exact `75fa8c9c0a8b656aa729a90bbe27e9ae995cae95`; the persistent report and ledger remain ignored evidence outside the project delta. No selectorless/default/full mutation suite was invoked. Explicit cache staging, amend of the sole Task 9 commit, and exact-HEAD verification follow this checkpoint.

### Staged audit, amend, and exact-HEAD evidence

The explicit cache contained exactly the 28 audited project paths (`cached=28 expected=28 missing=0 extra=0 unstaged=0`), and `git diff --cached --check` exited `0`. Immediately before amend, HEAD was exact `75fa8c9c0a8b656aa729a90bbe27e9ae995cae95`, its parent was the fixed base, `BASE..HEAD` count was `1`, and the subject was exact. `git commit --amend --no-edit` preserved the sole Task 9 commit and produced final HEAD `344366d75311ee59a63c0bbaaa249d8620c2397c`.

Fresh no-edit verification on that exact HEAD produced:

- authorized focused `validate-migration-framework.Tests.ps1 -ResponsibilityConformanceOnly`: exit `0`, all 17/17 isolated mutations PASS with unchanged source digest `B4878CA7DB4DAED04983B383D046EC8D2CBAE04B544E6FCA7054A8C9361B43A9`, ending `PASS: responsibility conformance mutation scenarios`;
- `validate-migration-framework.ps1 -Check All`: exit `0`, `PASS: migration framework (All)`;
- `validate-migration-framework.ps1 -Check SourceIntegrityOnly`: exit `0`, `PASS: migration framework (SourceIntegrityOnly)`;
- `git diff --check HEAD^ HEAD`: exit `0`, no diagnostics;
- `git status --porcelain=v1 --untracked-files=all`: zero entries;
- parent: `0cbb95afb835263ecf3b52b36f5ec0605f903435`;
- `git rev-list --count 0cbb95afb835263ecf3b52b36f5ec0605f903435..HEAD`: `1`;
- cumulative Task 9 commit file count: `41`;
- subject: `test: cover responsibility conformance workflow`;
- HEAD before and after exact-HEAD verification: `344366d75311ee59a63c0bbaaa249d8620c2397c`.

The final4 scoped fix wave is complete and ready for the controller's fresh whole-commit review. The selectorless/default/full mutation suite was never invoked in this final wave and remains locked until that whole review is clean.

## Final whole-review Critical: executable master-plan responsibility discriminator

This narrow follow-up began from exact clean HEAD `344366d75311ee59a63c0bbaaa249d8620c2397c`. Its parent remains fixed Task 9 base `0cbb95afb835263ecf3b52b36f5ec0605f903435`, the range count remains one, and the subject remains `test: cover responsibility conformance workflow`. The confirmed defect was that the executable master plan already carried the pre-edit `Delivery Adapter Selection` and `Responsibility Owner References` authority rows, but its canonical template/schema and current-plan resolver had no responsibility-contract discriminator.

### Strict RED -> GREEN

The first Windows PowerShell 5.1 scope-engine RED exited `1`: the real master-plan producer contained zero canonical discriminator blocks, and missing, pre-v1, unsupported, duplicate, and mixed-plan current revisions fell through to `scope-blocked / planned-responsibility-authority-invalid` instead of the required `orchestration-blocked / responsibility-contract-version-invalid / master-plan` result. The first scope-artifacts RED also exited `1` for both LF and CRLF because the rendered producer lacked the canonical nested block. A later exact-shape RED proved an extra indented child was accepted. Static Contracts/Skills REDs independently proved the schema, scope contract, and plan-waves producer contract were missing the discriminator.

GREEN adds exactly this bounded block to the canonical master-plan template and schema:

```yaml
responsibility_contract:
  version: 1
  applicability: required
```

The migrate and plan-waves producers now require that exact block before materializing executable planned authority. The scope orchestration contract specifies the stable `responsibility-contract-version-invalid` diagnostic and historical compatibility boundary. The Markdown artifact validator parses the nested block under normalized LF/CRLF, rejects missing/pre-v1/unsupported/duplicate/mixed or extra-child shapes, and returns before section or table consumption. The structured current-plan resolver applies the same exact two-child v1 gate after immutable current-plan identity/link checks and before resume reconciliation or any selector/owner-row projection. The rendered flexible-scope parser recognizes the new canonical key and does not invoke planned-responsibility resolution unless the plan discriminator is valid.

Historical approved revisions 1 and 2 remain readable without the block; only current executable revision 3 carries v1. The independent target-conformance external-plan parser was reviewed and classified as a separate compatibility follow-up because it does not resolve the scope/current-plan responsibility-owner authority covered by this Critical; it was not changed in this narrow wave.

### Fresh pre-amend verification and checkpoint

Fresh affected checks on the final unchanged tree all exited `0`:

- `scope-engine.Tests.ps1`: `PASS: scope engine behavioral scenarios`, including real producer -> current-plan selection and poisoned-row missing/pre-v1/unsupported/duplicate/mixed negatives;
- `scope-artifacts.Tests.ps1`: `PASS: scope artifact scenarios`, including LF/CRLF canonical, missing, pre-v1, unsupported, duplicate, and extra-child cases;
- `validate-migration-framework.ps1 -Check Contracts`: `PASS: migration framework (Contracts)`;
- `-Check Skills`: `PASS: migration framework (Skills)`;
- `-Check Templates`: `PASS: migration framework (Templates)`;
- `-Check Orchestrators`: `PASS: migration framework (Orchestrators)`;
- `-Check All`: `PASS: migration framework (All)`;
- `-Check SourceIntegrityOnly`: `PASS: migration framework (SourceIntegrityOnly)`;
- authorized focused `validate-migration-framework.Tests.ps1 -ResponsibilityConformanceOnly`: all 17/17 isolated mutations PASS with unchanged source digest `F84660FFD47AA32E1103C2A5BE6B7B8F3ACEA1F6F976A871C6A3A07E517D365B`, ending `PASS: responsibility conformance mutation scenarios`;
- direct `git diff --check`: exit `0`, with informational LF-to-CRLF working-copy notices only.

All five changed PowerShell files parse with zero Windows PowerShell 5.1 AST errors. The exact wave delta is ten intended project files, 195 insertions and 13 deletions, with no untracked or out-of-scope path. `git ls-files --eol` confirms the pre-existing mixed working-tree endings remain localized while the main validator remains forced LF. No long flexible-scope E2E was duplicated because the focused real producer -> current-plan scenario proves this front-matter-only path. No selectorless/default/full mutation invocation occurred. Explicit staging, amend of the sole Task 9 commit, and exact-HEAD verification follow this checkpoint.

### Staged audit, amend, and exact-HEAD evidence

The explicit cache contained exactly the ten audited project paths (`cached=10 expected=10 missing=0 extra=0 unstaged=0`), and `git diff --cached --check` exited `0`. The report and ledger remained ignored. Immediately before amend, HEAD was exact `344366d75311ee59a63c0bbaaa249d8620c2397c`, its parent was the fixed base, `BASE..HEAD` count was `1`, and the subject was exact. `git commit --amend --no-edit` preserved the sole Task 9 commit and produced exact HEAD `98f181a08989e72111335833373e2f54841373d0`.

Fresh no-edit verification on that exact HEAD produced:

- `scope-engine.Tests.ps1`: exit `0`, `PASS: scope engine behavioral scenarios`;
- `scope-artifacts.Tests.ps1`: exit `0`, `PASS: scope artifact scenarios`;
- authorized focused `validate-migration-framework.Tests.ps1 -ResponsibilityConformanceOnly`: exit `0`, all 17/17 isolated mutations PASS with unchanged source digest `F84660FFD47AA32E1103C2A5BE6B7B8F3ACEA1F6F976A871C6A3A07E517D365B`, ending `PASS: responsibility conformance mutation scenarios`;
- `validate-migration-framework.ps1 -Check All`: exit `0`, `PASS: migration framework (All)`;
- `validate-migration-framework.ps1 -Check SourceIntegrityOnly`: exit `0`, `PASS: migration framework (SourceIntegrityOnly)`;
- `git diff --check HEAD^ HEAD`: exit `0`, no diagnostics;
- `git diff --check 344366d75311ee59a63c0bbaaa249d8620c2397c HEAD`: exit `0`, no diagnostics;
- `git status --porcelain=v1 --untracked-files=all`: zero entries, with clean unstaged and cached diffs;
- parent: `0cbb95afb835263ecf3b52b36f5ec0605f903435`;
- `git rev-list --count 0cbb95afb835263ecf3b52b36f5ec0605f903435..HEAD`: `1`;
- cumulative Task 9 commit file count: `41`; discriminator wave file count: `10`;
- subject: `test: cover responsibility conformance workflow`;
- HEAD before and after exact-HEAD verification: `98f181a08989e72111335833373e2f54841373d0`.

This narrow Critical is complete for the canonical producer -> scope/current-plan responsibility-authority path. The selectorless/default/full mutation suite and duplicate long E2E were not invoked.

## Final discriminator residual closure: raw JSON and standalone resume

This follow-up began from exact clean HEAD `98f181a08989e72111335833373e2f54841373d0`, with fixed Task 9 parent `0cbb95afb835263ecf3b52b36f5ec0605f903435`, one commit in the range, and subject `test: cover responsibility conformance workflow`. Scope is exactly the two residual whole-review Criticals: duplicate/type-preserving validation of the current executable master-plan discriminator before JSON projection, and the same latest-plan gate for standalone `validate-resume`.

### Three strict RED rounds and confirmed root cause

The unchanged-production Windows PowerShell 5.1 scope-engine run exited `1`. Real raw JSON duplicate plan keys in invalid-first/valid-last order, duplicate `version` and `applicability` children, singleton contract/child arrays, and scalar type confusion survived `ConvertFrom-Json` and fell through to `no-eligible-item`. Standalone `validate-resume` returned `resume-ready / latest-approved-linear-revision` for latest-plan missing, v0, v2, duplicate, mixed, non-scalar, missing-child, and extra-child discriminators. A positive chain with historical revision 1 missing the discriminator, historical revision 2 at v0, and latest revision 3 at canonical v1 remained `resume-ready`, proving the compatibility boundary independently.

A first review-driven adversarial round then proved that selecting the raw plan by a stricter revision lexeme failed open when the projected engine accepted decimal `3.0`/`1.0` or duplicate revision members. A second review-driven round proved the same mismatch for standalone JSON revision string `"1"` and Boolean `true`; all four added assertions were RED before the final correction. A singleton-array revision was also probed, but the existing projected revision-chain conversion already rejected it before `resume-ready`, so it was not retained as a fail-open regression case.

The root cause was normalization order plus duplicated identity semantics: Windows PowerShell 5.1 collapsed duplicate JSON members and singleton arrays before the existing `PSObject.Properties` and string-cast checks, the direct resume branch never consumed the discriminator, and a separate raw identity selector could not exactly mirror every projected `[int]` coercion.

### GREEN implementation

`scope-engine.validation.ps1` now uses the .NET runtime JSON reader to inspect a typed XML projection of the raw JSON before `ConvertFrom-Json`. That reader preserves duplicate sibling members, member order, and JSON value types. For every plan-array element, raw validation requires one direct `responsibility_contract` object, exactly two direct children, one numeric scalar `version` with exact value `1`, and one string scalar `applicability` with exact value `required`; duplicate, mixed, missing, extra, array, object, string-number, or otherwise non-scalar shapes receive a false raw state.

The final design deliberately does not reimplement plan identity in the raw layer. Before projection it records a strict discriminator-valid Boolean for every raw element, preserving original array ordinal. The existing authoritative projected selectors identify the current queue plan or latest approved standalone-resume plan, then bind that projected object back to its original array index. A raw/projected count mismatch, missing index, or false state fails closed with the canonical discriminator diagnostic. This closes decimal, string, Boolean, duplicate-member, and future projection-coercion bypasses without making historical non-latest pre-v1 revisions executable authority.

The stored raw verdict is consumed at the existing semantic gate point: after current-plan identity/link validation for queue operations and after revision-chain validation immediately before `resume-ready`. This preserves established fork, spec-chain, and plan-ID diagnostics. The helper logic is implemented as private scriptblocks so the validation module retains its exact single exported function. Final independent narrow rereview reported `0 Critical / 0 Important`, and direct probes confirmed that latest revision `"1"`, `true`, and `1.0` without the discriminator all block while a historical missing pre-v1 revision with canonical latest still resumes.

### Fresh pre-amend checkpoint

Fresh verification on one frozen tree produced:

- `scope-engine.Tests.ps1`: initial strict RED exit `1`, then final exit `0`, `PASS: scope engine behavioral scenarios`;
- `scope-artifacts.Tests.ps1`: exit `0`, `PASS: scope artifact scenarios`;
- `validate-migration-framework.ps1 -Check All`: an intermediate RED identified the forbidden extra exported helper functions; after folding them into private scriptblocks, the fresh rerun exited `0`, `PASS: migration framework (All)`;
- `validate-migration-framework.ps1 -Check SourceIntegrityOnly`: exit `0`, `PASS: migration framework (SourceIntegrityOnly)`;
- authorized focused `validate-migration-framework.Tests.ps1 -ResponsibilityConformanceOnly`: exit `0`, all 17/17 isolated mutations PASS at digest `E8C1BD72FE2232ED163021C6EBC2326B90700D7B479DA6235BB0CCB0BD63CE84`;
- both changed PowerShell files parse with zero Windows PowerShell 5.1 AST errors;
- direct `git diff --check`: exit `0`, with informational LF-to-CRLF working-copy notices only.

The exact project delta is two intended files, 343 insertions and 6 deletions: the scope-engine validator and its scenario suite. No selectorless/default/full mutation invocation and no flexible-scope E2E invocation occurred. Explicit staging, amend of the sole Task 9 commit, and fresh exact-HEAD verification follow this checkpoint.

### Staged audit, amend, and exact-HEAD evidence

The explicit cache contained exactly the two audited project paths, with zero unstaged paths, and `git diff --cached --check` exited `0`. The report and ledger remained ignored. Immediately before amend, HEAD was exact `98f181a08989e72111335833373e2f54841373d0`, its parent was fixed base `0cbb95afb835263ecf3b52b36f5ec0605f903435`, the base-to-HEAD range count was `1`, and the subject was exact. `git commit --amend --no-edit` preserved the sole Task 9 commit and produced exact HEAD `1e217c510461936ea780bb60834d1dc1ec376889`.

Fresh no-edit verification on that exact HEAD produced:

- `scope-engine.Tests.ps1`: exit `0`, `PASS: scope engine behavioral scenarios`;
- `scope-artifacts.Tests.ps1`: exit `0`, `PASS: scope artifact scenarios`;
- `validate-migration-framework.ps1 -Check All`: exit `0`, `PASS: migration framework (All)`;
- `validate-migration-framework.ps1 -Check SourceIntegrityOnly`: exit `0`, `PASS: migration framework (SourceIntegrityOnly)`;
- authorized focused `validate-migration-framework.Tests.ps1 -ResponsibilityConformanceOnly`: exit `0`, all 17/17 isolated mutations PASS at unchanged digest `E8C1BD72FE2232ED163021C6EBC2326B90700D7B479DA6235BB0CCB0BD63CE84`, ending `PASS: responsibility conformance mutation scenarios`;
- both changed PowerShell files parsed with zero Windows PowerShell 5.1 AST errors;
- `git diff --check HEAD^ HEAD` and `git diff --check 98f181a08989e72111335833373e2f54841373d0 HEAD`: exit `0`, no diagnostics;
- `git status --porcelain=v1 --untracked-files=all`: zero entries, with clean unstaged and cached diffs;
- parent: `0cbb95afb835263ecf3b52b36f5ec0605f903435`;
- `git rev-list --count 0cbb95afb835263ecf3b52b36f5ec0605f903435..HEAD`: `1`;
- cumulative Task 9 commit file count: `41`; residual discriminator wave file count: `2`;
- wave delta: `343` insertions and `6` deletions;
- subject: `test: cover responsibility conformance workflow`;
- HEAD before and after exact-HEAD verification: `1e217c510461936ea780bb60834d1dc1ec376889`.

The final independent narrow rereview is clean with no remaining Critical or Important finding. The branch/worktree checkpoint is preserved at the amended commit. No selectorless/default/full mutation invocation and no flexible-scope E2E invocation occurred in this residual wave.

## Selectorless default-suite infrastructure RCA and repair

This follow-up began from exact clean HEAD `1e217c510461936ea780bb60834d1dc1ec376889`, with fixed Task 9 parent `0cbb95afb835263ecf3b52b36f5ec0605f903435`, one commit in the range, and subject `test: cover responsibility conformance workflow`. The controller-authorized selectorless/default full run (session 97014) exited `1` after about 30 seconds before a canonical terminal. The retained nested failure was:

```text
powershell.exe : powershell.exe : . : The term
...validate-migration-framework.Tests.ps1:61 char:20
    $childOutput = & (Get-Process -Id $PID).Path @childArguments 2>&1
...NativeCommandError
'C:\Users\diemnk2\AppData\Local\Temp\aitoolkit-framework-tests-21148-430091b2939b4c31aacea68b645b4b5a\aito...
...validate-migration-framework.Tests.ps1:276 char:13
    $output = & $powershell @arguments 2>&1
...NativeCommandError
```

The top-level wrapper had already removed its temporary fixture, and a process audit found no survivor. The full suite was not restarted.

### Confirmed root cause and strict RED

A clean isolated-copy matrix proved the fixture copy and unmodified `Contracts`, `FlexibleScope`, `Templates`, `Skills`, `Orchestrators`, `Onboarding`, `Compatibility`, and `Docs` validators were healthy. A bounded replay then isolated the existing missing-resource mutation: it removes `tests/validation/responsibility-conformance.validation.ps1` and invokes `Contracts`. `Test-Contracts` invoked `scope-artifacts.validation.ps1` before reaching its later missing-helper guard; `scope-artifacts.validation.ps1:3` unconditionally dot-sourced that now-missing helper. The minimal direct fixture reproducer exited `1` with the same full error:

```text
. : The term 'C:\Users\diemnk2\AppData\Local\Temp\aitoolkit-framework-tests-...\aitoolkit\tests\validation\responsibility-conformance.validation.ps1' is not recognized ...
At ...\tests\validation\scope-artifacts.validation.ps1:3 char:7
    . (Join-Path $PSScriptRoot 'responsibility-conformance.validation ...
FullyQualifiedErrorId : CommandNotFoundException
```

The regression was added first to the existing isolated `-IsolationSmokeOnly` route; no selector was invented. The RED command was:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.Tests.ps1 -IsolationSmokeOnly
```

It exited `1` with both intended assertions:

```text
FAIL: Missing responsibility helper must emit the canonical diagnostic. Output: . : The term '<temporary helper path>' ...
FAIL: Missing responsibility helper must not escape as a dot-source command-not-found error. Output: . : The term '<temporary helper path>' ...
```

### Minimal GREEN and review corrections

`Test-Contracts` now checks the responsibility validation helper after the established Activation Slice/profile gates and reads, but before invoking the first dependent validation module. A missing helper therefore exits through the canonical `FAIL: Missing responsibility conformance validation helper` result instead of native stderr. The isolation regression invokes the real Windows PowerShell 5.1 validator, requires exit `1` plus that canonical diagnostic, rejects the escaped dot-source/`CommandNotFoundException` signature, and restores exact helper bytes in `finally`.

The first independent read-only review returned `0 Critical / 2 Important / 0 Minor`: fail closed around fixture removal/restoration, and preserve earlier Activation Slice/profile diagnostic precedence. The regression now requires an initial helper leaf, uses terminating removal, proves the mutation was not a no-op, and byte-compares the restoration. The production preflight was moved behind the earlier gates while remaining ahead of `scope-artifacts`. The fresh read-only rereview returned `0 Critical / 0 Important / 0 Minor`, `Ready: Yes`; neither review edited the tree or ran tests.

### Fresh frozen-tree verification before amend

Every post-final-edit command ran serially and exited `0`:

- `validate-migration-framework.Tests.ps1 -IsolationSmokeOnly`: `PASS: migration framework tests isolated under <temporary root>`;
- `validate-migration-framework.Tests.ps1 -SourceIntegrityOnly`: `PASS: source-integrity mutation scenario`;
- `validate-migration-framework.ps1 -Check All`: `PASS: migration framework (All)`;
- `validate-migration-framework.ps1 -Check SourceIntegrityOnly`: `PASS: migration framework (SourceIntegrityOnly)`;
- authorized focused `validate-migration-framework.Tests.ps1 -ResponsibilityConformanceOnly`: all 17/17 isolated mutations PASS with unchanged source digest `B3930F825F71C047E63BCDE741F6A2D124EE42EED4B77814439AD2004DF73889`, ending `PASS: responsibility conformance mutation scenarios`;
- both changed PowerShell files parse with zero Windows PowerShell 5.1 AST errors;
- direct `git diff --check`: exit `0`, no diagnostics.

The frozen project delta is exactly the two intended validator/test files, 55 insertions and zero deletions. No validation process remained active at the checkpoint. The selectorless/default/full suite was not rerun and remains controller-owned. Explicit two-file staging, amend of the sole Task 9 commit, and fresh exact-HEAD verification follow this checkpoint.

### Staged audit, amend, and exact-HEAD evidence

The explicit cache contained exactly the two audited project paths (`cached=2 expected=2 missing=0 extra=0 unstaged=0`), and `git diff --cached --check` exited `0`. Immediately before amend, HEAD remained exact `1e217c510461936ea780bb60834d1dc1ec376889`, its parent was fixed base `0cbb95afb835263ecf3b52b36f5ec0605f903435`, the range count was `1`, and the subject was exact. `git commit --amend --no-edit` preserved the sole Task 9 commit and produced exact HEAD `388a9fa110df072ca3d6617c34b0abc2a4223c47`.

Fresh no-edit verification on that exact HEAD produced:

- `validate-migration-framework.Tests.ps1 -IsolationSmokeOnly`: exit `0`, `PASS: migration framework tests isolated under <temporary root>`;
- `validate-migration-framework.Tests.ps1 -SourceIntegrityOnly`: exit `0`, `PASS: source-integrity mutation scenario`;
- `validate-migration-framework.ps1 -Check All`: exit `0`, `PASS: migration framework (All)`;
- `validate-migration-framework.ps1 -Check SourceIntegrityOnly`: exit `0`, `PASS: migration framework (SourceIntegrityOnly)`;
- authorized focused `validate-migration-framework.Tests.ps1 -ResponsibilityConformanceOnly`: exit `0`, all 17/17 isolated mutations PASS at unchanged digest `B3930F825F71C047E63BCDE741F6A2D124EE42EED4B77814439AD2004DF73889`, ending `PASS: responsibility conformance mutation scenarios`;
- both changed PowerShell files parse with zero Windows PowerShell 5.1 AST errors;
- `git diff --check HEAD^ HEAD` and `git diff --check 1e217c510461936ea780bb60834d1dc1ec376889 HEAD`: exit `0`, no diagnostics;
- `git status --porcelain=v1 --untracked-files=all`: zero entries, with clean unstaged and cached diffs;
- parent: `0cbb95afb835263ecf3b52b36f5ec0605f903435`;
- `git rev-list --count 0cbb95afb835263ecf3b52b36f5ec0605f903435..HEAD`: `1`;
- cumulative Task 9 commit file count: `41`; infrastructure repair wave file count: `2`;
- subject: `test: cover responsibility conformance workflow`;
- HEAD before and after the exact-HEAD audit: `388a9fa110df072ca3d6617c34b0abc2a4223c47`.

The selectorless default-suite infrastructure repair is complete and independently reviewed clean. The original controller run remains the only selectorless/default/full invocation in this wave; it was not rerun after the repair and remains reserved for the controller.

## Selectorless full terminal-failure closure

This closure began from exact clean HEAD `388a9fa110df072ca3d6617c34b0abc2a4223c47`, fixed parent `0cbb95afb835263ecf3b52b36f5ec0605f903435`, one Task 9 commit, and the unchanged subject `test: cover responsibility conformance workflow`. The exact selectorless command was always:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.Tests.ps1
```

The first clean default run, session `9389`, ran for about 91 minutes and exited `1`. Its terminal evidence grouped into four stale/full-only clusters:

- Flexible S20 expected `scope-completion-calculated / scope-complete` but the generated completed review retained a `Domain Blocker`, so the validator correctly returned `structural-assurance-blocked / scope-blocked` and the 21-scenario sentinel was absent.
- Activation review -> verification -> parity -> regression fixtures lacked the exact downstream delivery-adapter authority, causing `assurance provenance current/predecessor requires exact Delivery Adapter Kind`; their approved/complete lifecycle then correctly conflicted with activation-blocking errors.
- The review migration template did not declare the canonical `complete | blocked` result set.
- Placeholder SHA, wrong task/unit, blocked-domain, and lifecycle negatives were masked by the missing adapter baseline; one non-blocking fixture also retained `Domain Blocker`.

The process tree and isolated fixture were gone after terminal, and the source checkout remained byte-clean. No selector was invented for the main wrapper; focused reproduction used only declared direct scenario/final-fix switches.

### Shared adapter/mode repair and strict review-driven closure

Static trace plus supported focused REDs proved that stale fixtures exposed a wider direct-handoff authority gap. The final implementation established one canonical, mode-aware envelope instead of merely teaching fixtures to satisfy a new string check:

- downstream artifacts preserve exact visible `Delivery Adapter Kind` and `Delivery Adapter Mode Constraint` evidence in canonical order;
- step 10 resolves strict `Canonical Adapter Evidence`, binds all thirteen selector fields to the approved step-8 `Delivery Adapter Selection`, and correlates migration-unit authority to `Master Scope Context` plus `Selected Migration Unit`;
- task/story/package/phase/milestone/none direct step-8 routes use Work Item changed-file/test evidence and forbid invented selected-unit state;
- migration-unit routes preserve selected-unit authority and the approved mode; greenfield generic routes cannot fabricate regression;
- step 15 has mode-aware greenfield parity -> KB and incremental regression -> KB predecessor routes;
- FlexibleScope terminal evidence accepts every public generic adapter while correlating strict visible kind/mode authority to the approved plan;
- visible evidence rejects HTML-comment synthesis, malformed bullet markers, hanging-indent prose, duplicates, hidden authority, drift, and wrong canonical ordering;
- generated completed review fixtures remove the optional `Domain Blocker` section fail-closed, and the review template declares `result: complete | blocked`.

Review found and closed the inline multiline-comment bypass, incomplete migration selector correlation, generic greenfield regression bypass, malformed bullet-marker acceptance, generic FlexibleScope rejection, and step-15 authority gap. Fresh direct and broad evidence on the final frozen tree included:

- Activation final-fix `Resume`, `Downstream`, and corrected `Lifecycle`: PASS;
- Flexible S05 generic and original failing S20: PASS;
- full Flexible 21 scenarios: `PASS: flexible migration scope orchestration (21 isolated E2E scenarios)`;
- Activation final-fix `-Cluster All`: PASS;
- `validate-migration-framework.ps1 -Check All`: `PASS: migration framework (All)`;
- `validate-migration-framework.ps1 -Check SourceIntegrityOnly`: `PASS: migration framework (SourceIntegrityOnly)`;
- authorized focused 17 responsibility mutations: PASS;
- final whole-delta rereview: `0 Critical / 0 Major / 0 Minor`, `Ready: Yes`.

The explicit 24-path stage audit reported `expected=24 actual=24 missing=0 extra=0 unstaged=0`, with cached diff-check exit `0`. The sole commit was amended from `388a9fa` to `fe145011d45867f3f53b2dd5b1f2baca83e4e5ca`; exact-HEAD short gates were green.

### First exact full retry: full-only PowerShell fixture runtime RED

The selectorless run on `fe145011`, session `98836`, exited `1` after about 28 minutes with the retained runtime error:

```text
Cannot convert value "## Delivery Adapter Selection ..." to type System.Int32
...validate-migration-framework.Tests.ps1:1951
  + "`n`n$incrementalDeliveryAdapterSelection"
InvalidCastFromStringToInteger
```

The full-only approved-plan fixture split one string concatenation across a statement boundary, so Windows PowerShell treated the line-leading `+` as unary numeric conversion. The minimal correction kept both fragments in the same assignment and interpolated string. A direct AST/runtime binding sentinel, main All/SourceIntegrityOnly, focused 17, diff-check, and independent one-file rereview (`0/0/0`, Ready) passed. The one-file stage audit was exact, and the sole commit was amended to `080e990de79fcc10ccf3fb0fa5f4cf266232e712`.

### Second exact full retry: stale full-only resume and diagnostic expectations

The selectorless run on `080e990`, session `27376`, remained healthy through its natural terminal at about 109 minutes and exited `1`. Exact failures were:

- the structurally valid, quoted-YAML, and literal-scalar step-10 waiver-resume positives all reported `resume predecessor Canonical Adapter Evidence section must appear exactly once; found 0`, followed by the expected lifecycle consequence;
- four current step-10 selected-unit negatives expected legacy linkage strings, while canonical binding correctly emitted role-specific missing-row, duplicate-row, duplicate-section, and overlapping-table diagnostics.

Systematic trace classified this as zero production defects: one stale full fixture and four stale assertions. The current resume artifact already used the canonical producer shape; its handcrafted predecessor contained only the base Activation Slice plus `Selected Migration Unit`, omitting `Master Scope Context` and `Canonical Adapter Evidence`. Production correctly binds both current and resume-predecessor step-10 authority before legacy linkage validation. The supported direct pre-edit controls confirmed this classification:

- session `96504`, `-Cluster Resume`: exit `0`, `PASS: Activation Slice final-fix scenarios (Resume)`;
- session `77744`, `-Cluster Downstream`: exit `0`, `PASS: Activation Slice final-fix scenarios (Downstream)`.

The minimal two-file correction therefore changed tests only:

- construct the full-only resume predecessor in producer order: Master Scope, Canonical Adapter Evidence, then Selected Migration Unit, without forbidden implementation records;
- update exactly four obsolete full expected strings to the canonical `current implementation Selected Migration Unit ...` diagnostics;
- add direct Resume coverage for missing predecessor canonical authority, quoted YAML success, and same-decoded literal-scalar success;
- add direct Downstream coverage for missing/duplicate selected-unit rows, duplicate section, and overlapping table, all from a known-valid producer baseline.

Post-edit direct Resume session `68897` and Downstream session `96188` both exited `0`. Literal `-Check All`, literal `-Check SourceIntegrityOnly`, and focused 17 passed; focused output SHA-256 was `8D9F441ACA7962B97E6FABBEED75C7C1A65B179DEC6677B7143384B9F31E1DBD`, with responsibility source digest `A72A707C31A4E2EE8A08BFC9433AB8A7F458B8831FBD6B642975D78B56F27A50`. The frozen two-file diff hash was `41fe072a3a2281b84063ef5d904e84f488856a61`. Fresh independent review returned `0 Critical / 0 Major / 0 Minor`, `Ready: Yes`, with no masking, producer-fidelity, PowerShell 5.1, scope, or whitespace finding.

The exact stage audit reported `expected=2 cached=2 missing=0 extra=0 unstaged=0`; cached diff-check exited `0`. The sole commit was amended from `080e990` to final HEAD `b8d5cb24743fe5360282a1aa4274445fdf2a67aa`. Exact-HEAD AST, literal All, literal SourceIntegrityOnly, and focused 17 reruns all passed with the same focused digest.

### Final selectorless GREEN and identity audit

The one final selectorless run on frozen clean HEAD `b8d5cb24743fe5360282a1aa4274445fdf2a67aa`, session `29610`, ran for about 110.7 minutes. Interruption audits preserved the same process tree; CPU, descendant, and phase checks showed real progress through Flexible E2E, activation/final-fix clusters, Contracts, Docs, Templates, and Skills. It terminated naturally with exit `0` and exact output:

```text
PASS: focused migration framework tests
SELECTORLESS_DEFAULT_FINAL_RETRY_EXIT=0
```

The post-terminal audit confirms:

- HEAD: `b8d5cb24743fe5360282a1aa4274445fdf2a67aa`;
- parent: `0cbb95afb835263ecf3b52b36f5ec0605f903435`;
- base-to-HEAD commit count: `1`;
- subject: `test: cover responsibility conformance workflow`;
- cumulative committed paths: `42`;
- `git status --short`: zero entries;
- unstaged and cached diff-check: exit `0`;
- matching validation processes: `0`;
- current selectorless-run isolated temp directories: `0`.

The full terminal-failure wave is complete: all focused failures are closed, all required exact-head gates pass, the selectorless default suite passes on the final clean commit, and no production source was changed for the final stale-fixture/expectation closure.

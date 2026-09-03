# Task 6 Report - Independent Migration Responsibility Review

## Scope

Implemented Task 6 from base `454ae863fbfdf433fa96be0d28150eedd5545a18`.

The architecture-first review independently derives Tree, Responsibility, and
Verification Ownership from the approved plan, implementation matrices, and a
pinned final-source/task-base..final-tree inventory. The implementation report's
self-attested PASS is never semantic PASS. Any derived structural BLOCKED state
forces architecture BLOCKED and overall Reject.

## Files changed

- `aitoolkit/skills/shared/ai-review/SKILL.md`
- `aitoolkit/templates/migration/review-report.md`
- `aitoolkit/tests/validation/responsibility-conformance.validation.ps1`
- `aitoolkit/tests/validation/architecture-review.validation.ps1`
- `aitoolkit/tests/scenarios/architecture-review.Tests.ps1`
- `aitoolkit/tests/scenarios/responsibility-conformance.Tests.ps1`

## TDD evidence

### Initial RED

Added the original architecture-first fixture and ran:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\architecture-review.Tests.ps1
```

Observed the pre-implementation failure that the existing validator had neither
the required architecture-first ordering nor the independent review gate:

```text
complete architecture-first review and scope-aware KB contract expected PASS but failed:
AI Review architecture gates require exact architecture-first review gate order;
AI Review architecture gates missing: Missing master context, canonical selector,
conformance matrix, exemplar, actual/planned tree evidence, or applicable
production activation evidence
```

### Review-round remediation RED

The first implementation was reviewed and found to compare only review and
implementation artifacts. Before the remediation, I added a genuine pinned Git
source/diff fixture with a real extra production route/provider and verification
owner. Both implementation and review artifacts self-attested PASS, while the
extra owner existed only in the final source and task-base..final-tree diff.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\architecture-review.Tests.ps1
```

Observed the required RED failure:

```text
review independently rejects omitted actual owner (LF) expected failure but passed
```

This proved the prior validator did not inspect the pinned source or diff.

### GREEN implementation

Implemented the minimal source-backed remediation:

- requires design, implementation, review, and provenance artifacts together;
- resolves exact 40-character task-base and final-tree commits in the declared
  source repository, then inventories changed final files and their diffs;
- uses language-neutral `source:<sha>:<path>#<anchor>` and
  `diff:<base>..<final>:<path>#<anchor>` references, without extension allowlists;
- compares approved planned matrices, implementation actual matrices, and the
  independently derived source inventory as separate authorities;
- derives structural and aggregate verdicts, rejecting self-attested PASS on
  every inconsistency;
- captures source symbols, effects, routes/providers, and verification owners;
- proves the omitted real owner is rejected under both LF and CRLF; and
- places Tree before Responsibility before Verification Ownership in the review
  procedure after master/work-item, rules, and selector.

One focused post-implementation failure exposed that canonical fixture IDs use
`VERIFY-OWNER-*`, while the first extractor accepted only `VER-*`. The extractor
was expanded to accept both canonical forms; this was a parser compatibility
fix, not a fixture or validator weakening.

## Final verification

All focused gates were re-run after the remediation and exited `0`:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\architecture-review.Tests.ps1
# PASS: architecture review scenarios

powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-conformance.Tests.ps1
# PASS: responsibility conformance contract

powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Skills
# PASS: migration framework (Skills)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Templates
# PASS: migration framework (Templates)

git diff --check
# exit 0
```

## Self-review

Confirmed that the amend changes only the six Task 6-owned files, the template
remains in the same sole Task 6 commit, evidence parsing has no language or file
extension allowlist, all fixture mutations assert an actual change, and the
report remains ignored outside the source commit.

## Commit

Amended sole Task 6 commit: `8735e790ffd933c6211132a2f90bce48e8c4e35a`
`feat: review migration responsibility independently`

## Review round 2 remediation

### RED

Added focused tests before changing the validator and ran the architecture
scenario suite. The caller-substituted review-provenance case failed as
required because it still passed:

```text
review rejects caller-substituted provenance (LF) expected failure but passed
```

The substituted range was internally valid: its review source/diff references
and provenance SHA were coordinated, but its final-tree SHA differed from the
implementation artifact's canonical `Change Hygiene` row. This demonstrated
that review provenance was caller controlled.

The responsibility suite then reproduced the design-authority gap:

```text
review rejects an unapproved planned design (LF) expected responsibility-owner-extra but got:
```

It also added a stale implementation design-revision case and a coordinated
plan/implementation authority and co-location self-attestation case. Finally,
an incremental source fixture retained its responsibility declaration before
task base and changed only the provider route; the old declaration-hunk rule
would reject it.

### GREEN

The minimal repair now:

- derives task-base and final-tree SHA from the implementation artifact's
  canonical `Change Hygiene` table and rejects review-provenance mismatch or
  omission;
- requires `07-technical-design`, `approved`, `complete`, and one canonical
  design revision, then binds implementation owner references to that revision;
- compares all responsibility matrix properties that determine Task 6
  semantics, including owner/path, public symbols, capability IDs, effects,
  authority, co-location policy, and verification references;
- independently inventories corresponding final-source annotations and compares
  them to planned and actual matrices; and
- treats a changed owner symbol, capability, verification owner, route, or
  provider as diff evidence for an existing final-tree owner, so an unchanged
  declaration is not required in the diff hunk.

Both new provenance cases and all semantic drift cases run under LF and CRLF.

Fresh post-repair gates:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\architecture-review.Tests.ps1
# PASS: architecture review scenarios

powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-conformance.Tests.ps1
# PASS: responsibility conformance contract

powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Skills
# PASS: migration framework (Skills)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Templates
# PASS: migration framework (Templates)
```

## Review round 3 remediation

### RED

Repaired the architecture scenario coverage before changing the validator:

- the missing-`Change Hygiene` fixture now writes and verifies the selected LF
  or CRLF encoding before the guarded removal;
- incremental acceptance now uses a substantive, alter-or-fail artifact probe
  under both LF and CRLF instead of running once outside the loop; and
- a realistic source fixture starts with an annotated legacy route at task base,
  deletes it in the final tree, and retains the final planned admin route.

The deletion case failed before implementation as expected:

```text
review accepts inspected deleted final-tree owner (LF) expected PASS but failed:
responsibility-evidence-missing
```

The old inventory treated every `git diff --name-only` path as final-tree
content, so `git show <final>:src/obsolete_route.source` failed for a valid
deleted path.

### GREEN

The inventory now separates A/M/C/R final paths from D paths. It inventories
only final-tree source for the former. For a deleted path, it reads the
task-base source and validates each removed responsibility's owner, public
symbol, capability, effect, authority, co-location policy, verification owner,
and route/provider anchors against deletion-diff lines. A removed planned owner
still fails normal final-inventory coverage; an inspected, unplanned legacy
removal no longer produces a false missing-evidence block.

The new missing-Hygiene, incremental, and deletion scenarios all pass under LF
and CRLF. Fresh focused gate results remain:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\architecture-review.Tests.ps1
# PASS: architecture review scenarios

powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-conformance.Tests.ps1
# PASS: responsibility conformance contract

powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Skills
# PASS: migration framework (Skills)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Templates
# PASS: migration framework (Templates)
```

## Concerns

No known concerns. The source inventory intentionally uses explicit
responsibility annotations in focused fixtures so the language-neutral validator
can associate symbols, effects, providers, and verification owners with a
responsibility without relying on a language extension or parser.

## Review round 4 remediation

### RED

Added a focused full-file deletion case before changing the validator. The
fixture removes a real base owner together with its responsibility annotation,
public symbol, capability, effect, verification owner, route, and provider while
leaving all final planned/actual/review artifacts self-consistent. The case runs
under LF and CRLF.

The pre-repair architecture scenario run exited `1` for the intended reason:

```text
review rejects unplanned full deleted owner (LF) expected failure but passed
```

This proved that removal-diff inspection alone did not establish deletion
authority.

### Root cause and repair

`Test-ArcDeletedSourceEvidence` verified that base annotations and route/provider
anchors appeared on deleted diff lines. `Get-ArcPinnedSourceInventory` then
discarded every validated deleted owner, so `Test-ResponsibilityReview` had no
deleted inventory to reconcile with approval, actual implementation evidence, or
the independent review.

The minimal repair now:

- retains deleted owners separately from active final-tree owners, including
  owner/path, public symbols, capabilities, effects, architecture and co-location
  authority, verification owners, routes, and providers;
- requires one exact approved design removal decision covering that complete
  base inventory;
- requires one implementation `Change Hygiene` row for the same path and owner
  with `File Kind = deleted`;
- requires one independent Responsibility Review Evidence row whose immutable
  references use task-base source and the task-base..final-tree removal diff;
- requires exact `removed` actual public-symbol/effect states; and
- rejects missing, partial, duplicate, or unplanned deletion reconciliation while
  keeping the final planned and actual owner matrices exact.

The first GREEN attempt exposed a fixture-only table construction error: the new
approval rows were inserted after the blank line terminating strict Markdown
tables and therefore were not parsed. The fixture was corrected to insert rows
inside the tables; validator strictness was unchanged.

### GREEN and final verification

The focused architecture suite now proves both outcomes under LF and CRLF:

```text
PASS: review rejects unplanned full deleted owner (LF)
PASS: review accepts approved obsolete deleted owner (LF)
PASS: review rejects unplanned full deleted owner (CRLF)
PASS: review accepts approved obsolete deleted owner (CRLF)
```

Fresh final gates all exited `0`:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\architecture-review.Tests.ps1
# PASS: architecture review scenarios

powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-conformance.Tests.ps1
# PASS: responsibility conformance contract

powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Skills
# PASS: migration framework (Skills)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Templates
# PASS: migration framework (Templates)

git diff --check
# exit 0
```

### Round 4 self-review

Round 4 changes remain within four Task 6-owned files; the sole Task 6 diff from
base still contains exactly the six files listed in the brief. The deletion
authority comes from the approved design rather than implementation
self-attestation, active planned/actual owner coverage remains exact, review
evidence is pinned to immutable task-base/final-tree commits, and no language or
file-extension allowlist was introduced. No known concerns.

Final amended sole Task 6 commit: `8735e790ffd933c6211132a2f90bce48e8c4e35a`
`feat: review migration responsibility independently`

# Reviewable Change Hygiene Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enforce minimal task-scoped formatting for every code-producing workflow and require one final task commit plus ancestry-preserving rebase for LGE Gerrit delivery.

**Architecture:** Add one shared Markdown contract as the normative source, then make implementation, review, and delivery skills consume it. Keep LGE-specific upstream names and commands in the reviewed webOS/QML-to-Flutter project pack. Extend the existing PowerShell validator and real-file mutation suite so missing, weakened, or polarity-reversed rules fail.

**Tech Stack:** Markdown skill contracts and templates; PowerShell static validator and mutation tests; Git.

## Global Constraints

- Existing-file formatting is limited to the edited region or minimum adjacent syntax required for validity.
- New files may be formatted completely.
- Repository-wide formatting, unrelated line-ending/encoding/import-order/whitespace/wrapping churn, and mixed task scope are forbidden.
- Local checkpoint commits are allowed, but one approved task or `UNIT-###` produces exactly one final Gerrit commit.
- Squash may consolidate only the current task's commits; it must never simulate synchronization with upstream.
- LGE synchronization uses the reviewed upstream value and rebase; merge-base must equal the fetched upstream tip.
- Correctness, ancestry, commit-integrity, and diff-scope failures block and are not waiver-eligible.
- Gerrit upload remains behind its existing HARD gate.

---

### Task 1: Enforce Reviewable Change Hygiene End to End

**Files:**
- Create: `aitoolkit/skills/shared/change-hygiene.md`
- Modify: `aitoolkit/skills/migration/plan-waves/SKILL.md`
- Modify: `aitoolkit/skills/migration/code-migration/SKILL.md`
- Modify: `aitoolkit/skills/feature/implement/SKILL.md`
- Modify: `aitoolkit/skills/bugfix/fix/SKILL.md`
- Modify: `aitoolkit/skills/shared/ai-review/SKILL.md`
- Modify: `aitoolkit/skills/shared/gerrit-automation/SKILL.md`
- Modify: `aitoolkit/templates/migration/migration-plan.md`
- Modify: `aitoolkit/templates/migration/implementation-report.md`
- Modify: `aitoolkit/templates/review-report.md`
- Modify: `aitoolkit/templates/migration/review-report.md`
- Modify: `aitoolkit/templates/gerrit-report.md`
- Modify: `aitoolkit/examples/project-packs/webos-qml-flutter/references/architecture-rules.md`
- Modify: `aitoolkit/examples/project-packs/webos-qml-flutter/references/testing-rules.md`
- Modify: `aitoolkit/examples/project-packs/webos-qml-flutter/references/definition-of-done.md`
- Modify: `aitoolkit/tests/validate-migration-framework.ps1`
- Modify: `aitoolkit/tests/validate-migration-framework.Tests.ps1`

**Interfaces:**
- Consumes: approved task or migration-unit scope; reviewed project pack; caller-provided workflow type; existing Gerrit HARD gate.
- Produces: shared hygiene rules; task/change boundary evidence; LGE upstream ancestry evidence; validator failures for weakened contracts.

- [ ] **Step 1: Add failing validator assertions**

Add `Test-ReviewableChangeHygiene` to `validate-migration-framework.ps1`. It must require:

```powershell
$requiredUniversalConsumers = @(
  'skills/migration/code-migration/SKILL.md',
  'skills/feature/implement/SKILL.md',
  'skills/bugfix/fix/SKILL.md',
  'skills/shared/ai-review/SKILL.md',
  'skills/shared/gerrit-automation/SKILL.md'
)
```

The new check rejects missing or weakened semantics for existing-file minimal formatting, full formatting of new files, repository-wide formatter prohibition, final-diff inspection, Major-or-higher review classification, one-unit/one-change planning, one final task commit, task-local squash only, rebase instead of squash-copy synchronization, merge-base equality, post-rebase verification, and non-waivable blockers.

Call the check from the relevant `Skills`, `Templates`, and `Compatibility` selectors without changing selector names or exit behavior.

- [ ] **Step 2: Add real-file RED mutations**

In `validate-migration-framework.Tests.ps1`, mutate operative source files one at a time inside `try/finally`, restore the exact original bytes, and assert exit code 1 plus the focused failure message. Include these polarity mutations:

```powershell
'existing files: edited region only' -> 'existing files: format the complete file'
'never run a repository-wide formatter' -> 'run a repository-wide formatter'
'one final commit' -> 'multiple final commits'
'git rebase' -> 'git merge --squash'
'merge-base equals upstream tip' -> 'merge-base may remain stale'
'not waiver-eligible' -> 'may be auto-waived'
```

Also remove the shared-contract reference from every consumer in separate mutations, remove the plan unit/change boundary, and remove one artifact evidence field so routing-only token checks cannot pass.

- [ ] **Step 3: Run RED verification**

Run serially and allow the mutation suite to finish so all `finally` restorations execute:

```powershell
& ./aitoolkit/tests/validate-migration-framework.ps1 -Check Skills
& ./aitoolkit/tests/validate-migration-framework.ps1 -Check Templates
& ./aitoolkit/tests/validate-migration-framework.ps1 -Check Compatibility
& ./aitoolkit/tests/validate-migration-framework.Tests.ps1
```

Expected: the affected selectors and focused suite fail only because the new shared contract, consumer references, evidence sections, and LGE rules do not yet exist.

- [ ] **Step 4: Create the shared operative contract**

Create `aitoolkit/skills/shared/change-hygiene.md` with sections `Scope`, `Formatting and diff`, `Task and commit boundary`, `Review severity`, `Delivery evidence`, and `Non-waivable failures`. Use explicit normative statements:

```text
Never run a repository-wide formatter for a scoped functional task.
An existing file may contain formatting changes only in the edited region or minimum adjacent syntax required for validity.
A new file may be formatted completely.
Inspect the final diff and remove every untraced or formatting-only change.
Local checkpoint commits may be consolidated, but one task has exactly one final delivery commit.
Squash only the current task's own commits; never use squash to incorporate an upstream branch.
Ancestry, commit-integrity, correctness, and diff-scope failures are not waiver-eligible.
```

- [ ] **Step 5: Wire planning and implementation consumers**

Update `plan-waves` so every `UNIT-###` is one independently implementable, testable, reviewable, revertible Gerrit change. Add an exact `Delivery Change Boundary` field to the migration-plan template.

Update all three code-producing skills to read `shared/change-hygiene.md` before editing, preserve approved scope, record formatter commands, inspect the final diff, and block unrelated churn. Update the migration implementation template with:

```markdown
## Change Hygiene

| Task / Unit | File | File Kind | Edited Region / Symbol | Formatter Command | Unrelated Diff |
|---|---|---|---|---|---|
```

The report must distinguish `new` from `existing` files and record `none` for unrelated diff before continuation.

- [ ] **Step 6: Wire review and Gerrit enforcement**

Update AI Review to read the shared contract and classify confirmed unrelated formatting or mixed-scope churn as at least Major. Add a `Change Hygiene` result to both review templates.

Update Gerrit Automation to read the shared contract and resolve project-pack ancestry rules. Before its HARD gate it must record upstream ref/SHA, merge-base SHA, final task commit count, final commit SHA, task/unit ID, diff-scope verdict, and post-rebase verification evidence. It may consolidate task-local checkpoints into one final commit, but must reject squash-copy synchronization and more than one final task commit.

Add a `Branch and Commit Integrity` table to `gerrit-report.md` containing those exact fields.

- [ ] **Step 7: Add LGE project-pack rules**

In the webOS/QML-to-Flutter example pack:

- `architecture-rules.md` declares `git fetch origin`, `git rebase origin/develop`, forbidden `git merge --squash origin/develop`/snapshot-copy sync, conflict resolution against current upstream behavior, and merge-base equality;
- `testing-rules.md` requires `flutter-webos analyze` and `flutter-webos test` after rebase and records their exits;
- `definition-of-done.md` requires exactly one final task commit, permits only task-local consolidation, requires immediate review submission, and blocks ancestry/diff/verification failures before Gerrit upload.

Keep these rules project-specific; universal skills must consume resolved values rather than hard-code `origin/develop` or Flutter commands.

- [ ] **Step 8: Run GREEN verification and inspect scope**

Run:

```powershell
& ./aitoolkit/tests/validate-migration-framework.ps1 -Check Skills
& ./aitoolkit/tests/validate-migration-framework.ps1 -Check Templates
& ./aitoolkit/tests/validate-migration-framework.ps1 -Check Compatibility
& ./aitoolkit/tests/validate-migration-framework.Tests.ps1
& ./aitoolkit/tests/validate-migration-framework.ps1 -Check All
git diff --check
git status --short
```

Expected: all validators print `PASS`, the mutation suite exits 0 after restoring fixtures, `git diff --check` exits 0, and status contains only the files listed in this task plus the pre-existing untracked `.task3-scratch/` outside the toolkit repository.

- [ ] **Step 9: Review and create one implementation commit**

Inspect the complete diff against `71da623`, verify every changed line traces to this task, and commit all implementation files once:

```powershell
git add aitoolkit docs/superpowers/plans/2026-08-12-reviewable-change-hygiene.md
git commit -m "feat: enforce reviewable task changes"
```

Expected: exactly one implementation commit after the approved design commit; no checkpoint implementation commit is submitted.

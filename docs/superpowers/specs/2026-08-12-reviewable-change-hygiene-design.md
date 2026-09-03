# Reviewable Change Hygiene Design

**Date:** 2026-08-12  
**Status:** Proposed  
**Scope:** AIToolkit code-producing workflows and LGE migration delivery rules

## 1. Objective

AIToolkit must produce changes that remain reviewable in repositories with many contributors:

- formatting must not create unrelated diff outside the code needed by the task;
- one approved task unit must become one final Gerrit commit;
- local checkpoint commits may exist during implementation, but must be consolidated before delivery;
- synchronizing an LGE branch with `develop` must preserve Git ancestry through rebase, never through a squash-copy of `develop`.

These controls address two independent failure modes. Formatting noise increases review cost and conflict probability. Squash-copy synchronization hides ancestry, leaves the merge base stale, fails to follow upstream deletions, and makes later conflict resolution unreliable.

## 2. Rule ownership

### 2.1 Universal change-hygiene contract

Formatting and diff-scope rules apply to every project and workflow that edits source code. A shared contract under `aitoolkit/skills/shared/` is the single normative source. Code-producing, review, and delivery skills must read and enforce it rather than maintaining divergent copies.

The universal consumers are:

- `migration/code-migration`;
- `feature/implement`;
- `bugfix/fix`;
- `shared/ai-review`;
- `shared/gerrit-automation`.

### 2.2 Project-pack delivery rules

The LGE branch synchronization policy belongs to the reviewed project pack because branch names, required commands, and Gerrit practices are project-specific. The webOS/QML-to-Flutter example pack will record the policy in:

- `references/architecture-rules.md` for branch ancestry and upstream synchronization;
- `references/definition-of-done.md` for final commit and Gerrit eligibility;
- `references/testing-rules.md` for the required post-rebase verification commands.

Projects that do not declare this policy keep their own approved integration strategy. AIToolkit must not invent `origin/develop` for them.

## 3. Universal formatting and diff rules

Every source-editing task must satisfy all of the following:

1. Change only files, symbols, and behavior traced to the approved task or migration unit.
2. Do not run a repository-wide formatter as part of a scoped functional change.
3. A new file may be formatted in full.
4. In an existing file, formatting changes are allowed only in the edited region or in the minimum adjacent syntax required to keep the code valid.
5. Do not introduce unrelated line-ending, encoding, import-order, whitespace, wrapping, or generated-file changes.
6. Inspect the final diff against the task base and remove untraced or formatting-only changes.
7. If a mandatory formatter necessarily rewrites unrelated portions of an existing file, stop and report the conflict. Formatting cleanup must be separately approved and delivered as its own task; it must not be hidden in the functional commit.

The contract controls observable diff, not the formatter executable. A project may use any formatter as long as the final committed diff obeys these rules.

## 4. Task, migration unit, and commit boundary

For migration, one approved `UNIT-###` is the delivery task boundary. Each unit must be implementable, testable, reviewable, revertible, and deliverable independently.

During implementation, TDD or recovery checkpoints may create multiple local commits. Before Gerrit preparation:

- consolidate only the commits belonging to the current task into exactly one final commit;
- do not include a second task or migration unit in that commit;
- do not discard traceability: the final commit message and Gerrit description retain the task/unit ID and evidence links;
- do not upload checkpoint commits individually.

The final one-commit requirement applies to the submitted Gerrit change, not to private implementation history.

## 5. LGE synchronization contract

For a project pack that declares the LGE `develop` policy, delivery must use this sequence:

1. Fetch the remote.
2. Rebase the task branch onto the current approved upstream branch, normally `origin/develop`.
3. Drop obsolete squash-sync commits if they become empty during rebase.
4. Resolve conflicts using current upstream behavior and the task's approved intent. Do not restore stale copied snapshots merely to preserve the old branch state.
5. Verify that `git merge-base <upstream> HEAD` equals `git rev-parse <upstream>`.
6. Run the project-pack static-analysis and test commands on the rebased result.
7. Consolidate the current task's commits into one final commit without changing the verified tree.
8. Re-check commit scope and request review immediately rather than accumulating unrelated open changes.

Forbidden synchronization methods:

- `git merge --squash origin/develop`;
- copying upstream files and committing the resulting snapshot as a sync;
- using a normal one-parent commit to claim that upstream ancestry was incorporated;
- silently keeping upstream-deleted code because it existed in an earlier copied snapshot.

Squash remains allowed only for consolidating the current task's own commits after ancestry has been updated correctly.

## 6. Workflow integration

### 6.1 Plan Waves

`plan-waves` must define each migration unit as one independently reviewable Gerrit change. Acceptance data includes the expected target area and enough scope evidence to distinguish task changes from unrelated formatting.

### 6.2 Code-producing skills

`code-migration`, `feature/implement`, and `bugfix/fix` read the shared change-hygiene contract before editing. Their reports record:

- task or unit boundary;
- changed files and symbols;
- whether each file is new or existing;
- formatter commands, if any;
- confirmation that the final diff contains no unrelated formatting;
- local checkpoint commits, when present, as non-delivery history.

### 6.3 AI Review

AI Review checks both behavioral correctness and reviewability. Unrelated formatting, whole-file churn, encoding/line-ending churn, or changes outside approved trace scope are project-rule violations.

For this hard universal rule, a confirmed violation is **Major** unless it hides a correctness, data-loss, security, or contract defect that warrants **Critical**. It must be fixed before merge; it is not downgraded to a style-only Minor.

### 6.4 Gerrit Automation

Gerrit preparation resolves the project-pack integration policy, then verifies:

- the branch has the required ancestry;
- the final tree has fresh required verification evidence;
- exactly one final commit represents the task relative to the declared upstream;
- the commit contains no second task/unit and no unrelated formatting;
- task-local squash did not replace the required upstream rebase.

Failure of a mandatory ancestry, verification, commit-count, or diff-scope check blocks before the existing Gerrit HARD upload gate. The skill never auto-uploads or auto-merges.

## 7. Evidence and failure handling

The workflow must preserve exact commands, upstream SHA, merge-base SHA, final commit SHA/count, changed-file summary, formatter commands, test output, and exit status in its artifacts.

When the declared upstream is unavailable, the rebase conflicts are unresolved, verification fails, the merge base is stale, or the final commit contains unrelated changes, the result is blocked. Automation modes and waivers cannot bypass correctness, ancestry, commit-integrity, or diff-scope failures.

## 8. Validation strategy

Static validators and focused real-file mutations must prove that:

1. all code-producing skills read the universal hygiene contract;
2. existing-file whole-file formatting and unrelated diff are forbidden;
3. new files may be formatted completely;
4. AI Review classifies hard hygiene violations as at least Major;
5. Plan Waves maps one migration unit to one reviewable change;
6. Gerrit allows task-local consolidation but rejects multiple final task commits;
7. the LGE pack requires rebase and merge-base equality;
8. the LGE pack rejects squash-copy synchronization while allowing squash of task-local commits;
9. required analyze/test commands run after rebase;
10. failures block before the Gerrit upload HARD gate.

Mutation cases must include removal or polarity reversal of each operative rule so token presence alone cannot make the validator pass.

## 9. Non-goals

- AIToolkit will not force every project to use an `origin/develop` branch.
- AIToolkit will not automatically abandon existing Gerrit changes.
- AIToolkit will not silently rewrite public branch history without the normal delivery authorization.
- This design does not change migration automation-waiver eligibility.
- This design does not make Gerrit, CCC, or Release implicit migration stages.

## 10. Acceptance criteria

The design is complete when a generated workflow can demonstrate all of the following:

- functional commits contain only task-relevant code and minimal local formatting;
- a migration unit produces one final Gerrit commit even if local checkpoints existed;
- LGE upstream synchronization advances the merge base through rebase;
- squash-copy synchronization is rejected;
- review and delivery block noisy or mixed-scope changes;
- project-specific branch and command values remain sourced from the reviewed project pack.

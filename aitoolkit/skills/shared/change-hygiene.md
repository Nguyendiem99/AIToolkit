# Shared Change Hygiene

## Scope

Apply this contract to every code-producing, code-review, and delivery workflow. Trace every changed file and symbol to one approved task or migration unit. Do not combine independent tasks in one diff.

## Formatting and diff

Never run a repository-wide formatter for a scoped functional task.

An existing file may contain formatting changes only in the edited region or minimum adjacent syntax required for validity. A new file may be formatted completely. Do not introduce unrelated encoding, line-ending, import-order, whitespace, wrapping, generated-file, or cleanup churn.

Inspect the final diff and remove every untraced or formatting-only change. If a mandatory formatter necessarily rewrites unrelated portions of an existing file, block and request a separately approved formatting task instead of mixing that churn into the functional change.

## Task and commit boundary

Local checkpoint commits are private implementation history. They may be consolidated before delivery, but one task has exactly one final delivery commit. A migration `UNIT-###` is one task and one independently reviewable change.

Squash only the current task's own commits; never use squash to incorporate an upstream branch. Resolve and follow the reviewed project-pack integration policy before consolidating the task without changing its verified tree.

## Review severity

Confirmed unrelated formatting, whole-file churn in an existing file, mixed task scope, or untraced changes are at least Major. Use Critical when the churn hides or causes a correctness, data-loss, security, or contract defect.

## Delivery evidence

Record the task/unit ID, base and final commit, changed files/symbols, file kind (`new` or `existing`), formatter commands, final diff-scope verdict, and any project-required ancestry and verification evidence.

## Non-waivable failures

Ancestry, commit-integrity, correctness, and diff-scope failures are not waiver-eligible. They block before irreversible delivery actions and remain subject to the existing Gerrit HARD gate.

## Quick reference

| Situation | Required action |
|---|---|
| Existing source file | Keep formatting within the edited region or minimum adjacent syntax. |
| New source file | Full-file formatting is allowed. |
| Formatter rewrites unrelated code | Stop and separate the formatting work. |
| Multiple local checkpoints | Consolidate only this task into one final delivery commit. |
| Upstream synchronization | Follow the reviewed ancestry-preserving project policy; never squash-copy upstream. |

## Common mistakes

- Treating formatter output as automatically in scope.
- Mixing opportunistic cleanup with a functional task.
- Uploading checkpoint commits as separate changes for one task.
- Using squash to imitate an upstream merge or rebase.

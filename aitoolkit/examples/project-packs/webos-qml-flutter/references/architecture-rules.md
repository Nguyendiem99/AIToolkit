# Architecture Rules

## Mandatory review rules

Rule class: `mandatory-review`.

- Use Clean Architecture boundaries: Presentation owns widgets and interaction state; Domain owns entities/use cases; Data owns repository implementations, providers, and platform adapters.
- Use Riverpod for reactive ownership according to the approved target baseline. Providers expose state and operations; widgets do not own service transport.
- Dependency direction is Presentation → Domain ← Data. Platform APIs remain behind repository/platform bridge interfaces.
- Apply null-safety at external-data and platform boundaries; model missing, malformed, error, and cancellation outcomes explicitly.
- Preserve subscription/resource lifecycle: release signal listeners, provider subscriptions, and native bridge handles when their owner is disposed.
- For incremental work, existing approved target architecture wins. A conflict is recorded and approved before changing the boundary.
- LGE conventions with project evidence are binding. Do not invent an LGE-specific naming, security, performance, or folder rule when the project pack has no approved rule.

If this section, its `mandatory-review` classification, or an applicable mandatory rule cannot be read, AI review records the exact gap and blocks. Migration artifacts use `result: blocked`; other workflows preserve their existing report schema.

## Optional convention supplements

- Compatibility default: organize new greenfield code feature-first under `lib/features/<feature>/{presentation,domain,data}`.
- Review unnecessary rebuilds, startup work, retained subscriptions, and sensitive platform data when relevant to the diff.

## Upstream synchronization

Before Gerrit delivery, run `git fetch origin` and `git rebase origin/develop`. Resolve conflicts against current upstream behavior and the approved task intent; do not restore a stale copied snapshot. Drop obsolete squash-sync commits when they become empty during rebase.

The command `git merge --squash origin/develop` is forbidden. Copying develop files and committing the snapshot as synchronization is also forbidden. Squash is allowed only to consolidate the current task's local checkpoint commits after the rebase.

Verify `git merge-base origin/develop HEAD` against `git rev-parse origin/develop`. The merge-base must equal the upstream tip. A mismatch blocks delivery.

Missing optional supplements degrade review explicitly; they do not replace the universal review dimensions.

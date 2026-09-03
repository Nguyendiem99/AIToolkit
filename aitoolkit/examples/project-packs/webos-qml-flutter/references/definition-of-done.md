# Definition of Done

## Mandatory release rules

Rule class: `mandatory-release`.

- Every selected migration unit traces implementation to an approved plan, source evidence, mapping, and target baseline.
- Mandatory review has no blocking finding, required fixes are resolved or explicitly owned, and the final review verdict is recorded.
- Every required test/static-analysis command has fresh evidence with command, scope, output summary, and exit status.
- Behavior parity and required regression evidence satisfy the approved profile; unresolved mandatory gaps block release.
- Gerrit preparation follows the approved project commit/change-description convention, includes traceability, and is never uploaded before its HARD gate.
- CCC evidence links the approved review, verification, and Gerrit reports plus release-note and impact analysis.
- Known gaps, waivers, owners, approvals, and remaining risk are explicit; missing mandatory evidence blocks release.
- Each approved task or migration unit is exactly one final task commit. Task-local checkpoint commits may be consolidated, but no second task/unit may share that commit.
- Upstream ancestry follows the approved rebase policy: run `git rebase origin/develop`, then require `git merge-base origin/develop HEAD` to equal `git rev-parse origin/develop`. Task-local consolidation never substitutes for upstream synchronization.
- Submit the completed task and request review immediately instead of accumulating unrelated open changes.
- Stale ancestry, failed post-rebase verification, multiple final task commits, or a failed diff-scope verdict blocks before the Gerrit upload HARD gate and is not waiver-eligible.

If this section, its `mandatory-release` classification, or an applicable mandatory rule cannot be read, Gerrit/CCC/release preparation records the exact gap and blocks. Migration artifacts use `result: blocked`; other workflows preserve their existing report schema.

## Optional release evidence

Coverage, visual comparison, performance measurements, and device logs degrade with an explicit note unless the project profile promotes them to mandatory.

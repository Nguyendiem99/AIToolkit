# Testing Rules

## Required commands

- Confirm the target project authority and scope for `flutter analyze`; run it verbatim and record output/exit status.
- Confirm the target project authority and scope for `flutter test`; run it verbatim and record output/exit status.
- Apply approved LGE conventions to required review/test evidence. If no project-specific LGE convention is approved, record that gap rather than inventing one.
- After the rebase, run `flutter-webos analyze` and record its output and exit status.
- After the rebase, run `flutter-webos test` and record its output and exit status.

These example commands become authoritative only after the target profile or project configuration confirms them. Command ambiguity is a blocker, not permission to guess.

## Optional evidence

- Coverage output, golden/visual comparison, performance measurements, device logs, and manual focus-navigation evidence are optional unless the profile or definition of done marks them required.
- When optional evidence is unavailable, record the degraded coverage and continue; never claim the missing check ran.

## Behavior scenarios

Test property-derived state changes, signal/event payload and ordering, Loader lifecycle states, model/delegate identity/selection updates, and Luna/native bridge success, error, subscription, cancellation, and cleanup paths when they are in scope.

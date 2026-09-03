---
name: webos-qml-flutter-project-pack
description: Use when a migration project needs the reviewed compatibility example for this legacy and target stack.
---

# Compatibility Project Pack Index

This index only routes consumers to project knowledge. Copy the pack into the project, review its evidence, and set `project_pack.path` in `docs/aitoolkit/project.yaml`; do not treat example defaults as project approval.

## Reference routing

| Consumer need | Reference |
|---|---|
| Legacy taxonomy, runtime behavior, platform integration | [legacy-system.md](references/legacy-system.md) |
| Target component and state baseline | [target-baseline.md](references/target-baseline.md) |
| Architecture, convention, and mandatory review rules | [architecture-rules.md](references/architecture-rules.md) |
| Source-to-target transformation | [mapping-rules.md](references/mapping-rules.md) |
| Visual, focus, loading, and error-state parity | [uiux-rules.md](references/uiux-rules.md) |
| Static analysis, test commands, and optional evidence | [testing-rules.md](references/testing-rules.md) |
| Gerrit, CCC, release evidence, and completion | [definition-of-done.md](references/definition-of-done.md) |

## Common mistakes

- Reading every reference instead of routing by the decision being made.
- Using this example without project review or without recording evidence for local deviations.
- Adding commands or rules to the index; detailed knowledge belongs in `references/`.

# Target Baseline

## Target conventions

- The target is a Flutter application whose UI unit is a widget/component.
- Represent source property behavior as derived/reactive state; do not duplicate derivable state.
- Represent a source signal as an event/callback with an explicit payload and lifecycle owner.
- Represent model/delegate behavior with the target list pattern, stable item identity, selection state, and deterministic updates.
- Isolate Luna/native integration behind a repository/platform bridge so presentation and domain code do not depend on transport details.
- Preserve an existing approved target structure in incremental mode. Use the project architecture reference, not this example, when they conflict.

## Baseline evidence

Before changing an incremental target, record its current folder/module boundaries, state ownership, navigation/focus behavior, platform integration seam, and authoritative build/test commands. A placeholder-only target is not evidence of an established baseline.

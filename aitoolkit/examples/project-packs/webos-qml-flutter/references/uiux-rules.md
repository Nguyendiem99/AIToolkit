# UIUX Rules

## UIUX migration rules

- Preserve approved layout, copy, visibility, and interaction behavior of each QML screen unless an approved UIUX source changes it.
- Preserve focus entry, traversal, restoration, and selected-item behavior for remote/keyboard navigation.
- Treat each QML Loader path as observable UI state: loading, loaded, empty, error, retry, inactive, and disposal where present.
- Preserve model/delegate item identity so selection and focus do not jump after collection updates.
- Capture screenshots or other approved visual evidence at comparable states and viewport/device conditions.

## Conflict policy

Desired UIUX evidence outranks observed legacy UI; approved requirements are next; observable legacy behavior is the fallback. Record conflicts, impact, owner, and decision rather than blending sources.

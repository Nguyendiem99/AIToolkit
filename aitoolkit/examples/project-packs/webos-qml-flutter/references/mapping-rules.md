# Mapping Rules

## Required mappings

| Legacy construct | Target construct | Behavior to preserve |
|---|---|---|
| QML view | Flutter widget/component | Visible states, navigation/focus behavior, and lifecycle |
| property binding | derived/reactive state | Dependencies, transformation, initial value, and update timing |
| signal | event/callback | Payload, emitter/handler ordering, errors, and disposal |
| model/delegate | target list pattern | Stable identity, rendering, selection, and incremental updates |
| Luna/native service | repository/platform bridge | Schema, permissions, subscriptions, cancellation, cleanup, and error mapping |

## Gap policy

Every mapped unit cites discovery evidence. A native-only capability without a verified target equivalent remains a gap with impact, proposed treatment, owner, and approval status; it is not silently dropped.

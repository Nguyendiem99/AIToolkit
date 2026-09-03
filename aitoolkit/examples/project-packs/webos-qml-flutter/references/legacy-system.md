# Legacy System

## Legacy patterns

- A webOS application is commonly described by `appinfo.json`; use routes and QML view entry points to inventory screens and features.
- A QML property binding is reactive data flow. Capture its source, transformation, consumers, and default value rather than copying only the displayed value.
- A QML signal is an event boundary. Record emitters, handlers, payload shape, ordering, and lifecycle.
- A QML `Loader` is a dynamic component/lifecycle boundary. Record source selection, activation, loading, empty, error, and destruction behavior.
- A QML model/delegate pair defines collection identity, item rendering, selection, and update behavior; preserve all four concerns in the migration inventory.
- A Luna Service call (`luna://`) or other native bridge is a platform dependency. Record URI/API, request and response schemas, subscription behavior, permissions, errors, cancellation, and cleanup.

## Evidence to capture

| Area | Evidence |
|---|---|
| Views and navigation | QML source, route registration, screenshots or approved UI documents |
| Reactive behavior | Property declarations, bindings, signal connections, state transitions |
| Dynamic content | Loader source/activation and model/delegate identity/update behavior |
| Platform integration | Luna/native call sites, manifests, permissions, schemas, logs |

Unknown behavior remains an explicit gap with an owner; it is never inferred solely from a target pattern.

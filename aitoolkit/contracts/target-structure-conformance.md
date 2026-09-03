# Target Structure Conformance Contract

This resource is the canonical source for target exemplar, structural
conformance, assurance-state, pre-edit gate, and architecture-first review
semantics. Skills and schemas reference it instead of redefining its tables or
enums.

## Comparable Target Exemplars

| Concern | Path | Inspected Symbols | Observed Pattern | Comparable Reason | Evidence | Status |
|---|---|---|---|---|---|---|
| applicable structural concern | real target path | fully inspected symbols | observed working pattern | why the exemplar is comparable | exact evidence reference | exemplar status |

Exemplar status: `verified | no-equivalent | unknown`.

Incremental discovery records exactly these eight concerns:

1. `module/container composition`
2. `main/child presentation boundaries`
3. `unit/component organization`
4. `controller/provider/state pattern`
5. `routing and lifecycle`
6. `localization`
7. `service/config subscription and normalization`
8. `test harness and production-boundary tests`

Each applicable concern requires a complete working exemplar. `no-equivalent`
must pass through gaps/conflicts. A missing or `unknown` concern blocks
discovery; implementation must not invent a pattern.

## Target Structure Conformance Matrix

| Concern | Working Exemplar | Observed Target Pattern | Proposed Path/Symbol | Conforms | Deviation Reference |
|---|---|---|---|---|---|
| one of the eight concerns | exact exemplar reference | evidence-backed target convention | planned path and symbol | `yes` or `no` | approval reference or `not-applicable` |

Every applicable concern has coverage. A `Conforms = no` row requires a resolved conflict and Tech Lead approval in `Deviation Reference`.

Generic technology guidance is not evidence. The matrix includes the planned
file tree and provider, router, localization, subscription, state, and lifecycle
boundaries. Missing evidence, unresolved deviation, or incomplete coverage
blocks technical design.

## Conformance and deviation semantics

`Conforms = yes` means the proposed path and symbol follow the fully inspected
working target pattern. `Conforms = no` means an intentional structural
deviation; it is valid only with a resolved conflict and exact Tech Lead
approval. Unapproved structural deviation is at least Major and becomes
Critical when activation, routing, or rendering fails.

## Structural pre-edit gate

Before any target mutation, code migration verifies:

1. the work item belongs to the approved master-plan revision;
2. its adapter selector is canonical and matches the work item;
3. its conformance matrix is approved;
4. cited exemplar paths and symbols were fully inspected;
5. proposed files and classes match the planned file tree;
6. state, routing, localization, subscription, and lifecycle use target boundaries;
7. every new abstraction has an approved deviation;
8. the production activation path is complete when applicable;
9. architecture conformance and selector/schema states are both `PASS`.

The structural pre-edit gate blocks before target edit and is not waiver-eligible.

The implementation report records `Master Scope Context`, `Conformance Matrix
Reference`, `Actual File Tree vs Planned File Tree`, `Exemplar Deviations`, and
`Production Activation Path Evidence`.

## Assurance State

| Runtime Evidence State | Architecture Conformance State | Selector Schema State |
|---|---|---|
| `PASS`, `FAIL`, `NOT_RUN`, or `WAIVED` | `PASS` or `BLOCKED` | `PASS` or `BLOCKED` |

The three assurance states are independent:

```text
runtime_evidence_state: PASS | FAIL | NOT_RUN | WAIVED
architecture_conformance_state: PASS | BLOCKED
selector_schema_state: PASS | BLOCKED
```

`auto-waive` may change eligible runtime evidence only from `NOT_RUN + BLOCKED`
to `NOT_RUN + WAIVED`. It never waives master approval, exemplar inspection,
the conformance matrix, canonical selector, schema validation, static
architecture review, or a correctness failure.

## Architecture-first review order

Architecture-first review order: master-scope/work-item alignment -> project rule resolution -> canonical selector -> architecture conformance with matrix/exemplars -> production activation path -> behavior, failure modes, security, performance, and tests -> change hygiene.

Review checks invented aggregate state, direct widget service/router calls, raw
layout in place of a target wrapper, missing unit boundary, wrong localization,
missing lifecycle gate, tests that bypass the production provider, missing
production subscription keys, planned/actual tree drift, and unapproved
structural deviations before lower-level behavior analysis.

## Architecture review verdicts

```text
Architecture Conformance Verdict: PASS | BLOCKED
Canonical Selector Verdict: PASS | BLOCKED
Production Activation-path Verdict: PASS | BLOCKED | NOT_APPLICABLE
```

Any `BLOCKED` verdict makes the overall verdict `Reject`.

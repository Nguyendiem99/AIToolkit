# Target Structure Conformance Contract

This resource is the canonical source for target exemplar, structural
conformance, assurance-state, pre-edit gate, and architecture-first review
semantics. Skills and schemas reference it instead of redefining its tables or
enums.

File responsibility, capability ownership, co-location, verification ownership,
and their canonical enums are solely governed by
`contracts/file-responsibility-conformance.md`. This contract does not redefine
them.

## Comparable Target Exemplars

| Concern | Path | Inspected Symbols | Observed Pattern | Primary Responsibility | Owned Capabilities | Verification Owner | Comparable Reason | Evidence | Inspection Status | Classification | Classification Authority | Classification Evidence |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| applicable structural concern | real target path | fully inspected symbols | observed working pattern | concrete reason-to-change | CAP-EXAMPLE | VERIFY-OWNER-EXAMPLE | why the exemplar is comparable | exact evidence reference | verified | preferred | factual-discovery-evidence | working-evidence:target/example.dart#Example |

`Inspection Status` and `Classification` are independent. Inspection Status:
`verified | no-equivalent | unknown`. Classification:
`preferred | compatibility-only | legacy-debt | no-equivalent`. Classification
authority and immutable evidence follow
`contracts/file-responsibility-conformance.md`; no seven-column discovery adapter is executable in responsibility contract v1.

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

```text
Structural PASS = Tree PASS AND Responsibility PASS AND Verification Ownership PASS
```

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
Rule Resolution Verdict: RESOLVED | BLOCKED
Architecture Conformance Verdict: PASS | BLOCKED
Canonical Selector Verdict: PASS | BLOCKED
Tree Conformance Verdict: PASS | BLOCKED
Responsibility Conformance Verdict: PASS | BLOCKED
Verification Ownership Verdict: PASS | BLOCKED
Production Activation-path Verdict: PASS | BLOCKED | NOT_APPLICABLE
Behavior Analysis State: NOT_RUN | COMPLETE
Change Hygiene Verdict: PASS | BLOCKED
```

An executable review also contains exact non-negative Critical and Major
counts. Any `BLOCKED` verdict makes the overall verdict `Reject`.
Any blocking gate or positive Critical count derives overall `Reject`;
otherwise a positive Major count derives `Approve-with-fixes`, and only zero
Critical plus zero Major with all gates resolved/pass and behavior complete
derives `Approve`.
The `Architecture Responsibility Handoff` Tree, Responsibility, Verification
Ownership, and Architecture cells equal their visible verdicts exactly; the
Architecture cell is the same Tree/Responsibility/Verification-derived state.
A contradictory handoff is not executable producer authority.

# Migration Scope Orchestration Contract

This resource is the canonical source for requested-scope, work-item, delivery-
adapter, attempt, revision, transition, resume, and completion semantics. Skills
and artifact schemas reference this contract instead of redefining its tables or
enums.

## Requested Scope

| Kind | ID | Statement | Source | Resolution Evidence |
|---|---|---|---|---|
| scope kind | stable scope ID | user-requested outcome | `user` or approved source | stable evidence reference |

Requested scope kinds: `project | module | feature | task | explicit-item | unresolved`.

Resolve requested scope before selecting an execution item. Folder, menu,
package, and file names are evidence only. `unresolved` blocks and cannot create
an executable work item. An explicit item request creates only the minimum scope
and dependency context required for that item.

## Master artifacts

Production mutation requires one approved, fresh, non-forked master spec and one
approved, fresh master plan linked to that exact spec revision. The master spec
defines the required outcome; the master plan defines the dependency graph and
the way the requested scope will be completed. Missing, draft, stale, forked, or
blocked master artifacts prohibit production mutation.

## Work Item

| Work Item ID | Title | Required | Dependencies | Plan Order | Acceptance | Trace IDs | Delivery Adapter | Status | Latest Attempt | Terminal Evidence | Approval Reference |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `WORK-<SCOPE>-<NAME>` | independently reviewable outcome | `yes` or `no` | work-item IDs or `none` | unique positive integer | traceable measurable outcome | stable trace IDs | adapter record or `none` | work-item state | attempt ID or `none` | exact artifact reference or `none` | exact approval or `pending` |

Scope states: `planned | scope-in-progress | scope-blocked | scope-complete | scope-cancelled-approved`.

Work-item states: `proposed | pending | ready | in-progress | blocked | complete | cancelled-approved | not-applicable-approved`.

Attempt completion, work-item completion, and requested-scope completion are
independent states. A completed item never implies module or project completion.

## Delivery adapter kinds

Delivery adapter kinds: `migration-unit | task | story | package | phase | milestone | none`.

```yaml
delivery_adapter:
  kind: migration-unit
  external_id: UNIT-ADM-002
  authority: 08-migration-plan.md
  authority_revision: 3
  approval_reference: approval:UNIT-ADM-002
  parent_selector: not-applicable
```

`none` keeps all selector fields `not-applicable`. An orchestrator never invents
an external ID. A `migration-unit` selector resolves exactly one approved
canonical row whose mode, acceptance, trace, dependency, and design revision
match; draft, duplicate, stale, mismatched, or external-only selectors block.

## Decomposition

```yaml
decomposition:
  parent_work_item_id: WORK-ADMIN-LOCKS
  child_work_item_ids:
    - WORK-ADMIN-SIMPLE-LOCKS
    - WORK-ADMIN-ADVANCED-LOCKS
  decision_reference: DEC-ARCH-014
```

Decomposition creates a new master-plan revision and canonical child selectors must be approved before adapter assignment.

Decompose only when an item is not independently implementable, testable, or
revertible; its behaviors have different dependencies; target evidence requires
a different boundary; or an approved scope revision changes the delivery
boundary. A child using `migration-unit` returns through inventory, mapping,
gaps/conflicts, technical design, and plan waves before selector approval.

## Eligibility

An item is eligible only when it is required or explicitly approved as optional,
is `pending` or `ready`, has only terminal-success dependencies, has approval for
the current plan revision, has no blocking unknown or conflict, resolves any
adapter canonically, has architecture and selector/schema `PASS`, and no other
item is `in-progress`. Cycles and missing dependencies invalidate and block the
plan.

## Deterministic selection order

Selection order: dependency depth ascending -> Plan Order ascending -> ordinal Work Item ID ascending.

Version 1 selects exactly one eligible work item. Given the same approved plan
revision and evidence state, initial selection and resume select the same next
eligible item.

## Atomic transitions

Before execution, atomically transition `ready -> in-progress`, record an
immutable attempt ID, and bind it to the current plan revision. After execution,
apply exactly one valid transition:

| Evidence or decision | Atomic transition |
|---|---|
| valid successful terminal artifact | `in-progress -> complete` |
| native blocker | `in-progress -> blocked` |
| approved cancellation | `pending|ready|blocked -> cancelled-approved` |
| approved non-applicability | `pending|ready -> not-applicable-approved` |

Master-plan updates preserve attempt history, point to the latest terminal
evidence, and never overwrite an attempt artifact.

## Attempt

| Attempt ID | Work Item ID | Plan Revision | Status | Artifact Reference |
|---|---|---|---|---|
| immutable attempt ID | stable work-item ID | exact approved plan revision | `in-progress`, `complete`, or `blocked` | exact immutable artifact reference |

## Terminal-success states

Terminal-success states: `complete | cancelled-approved | not-applicable-approved`.

No eligible item while a required blocker remains yields `scope-blocked`. Every
required item in a terminal-success state is necessary, but not by itself
sufficient, for `scope-complete`.

## Resume reconciliation

Resume resolves the latest approved master-spec revision and the latest approved
master-plan revision linked to it, verifies freshness and one linear revision
chain, then reconciles an `in-progress` item with its immutable attempt artifact.

Resume reconciliation applies a missing terminal transition from valid evidence before selecting another work item.

A non-terminal attempt resumes instead of selecting a new item. With no
`in-progress` item, resume applies deterministic selection. Missing, forked,
cyclic, or stale revision chains block. Approved scope is not brainstormed again
unless the user requests a scope change.

## Revision

| Artifact ID | Revision | Supersedes | Change Summary | Affected Work Items | Approval Reference |
|---|---|---|---|---|---|
| stable master artifact ID | positive integer | prior artifact revision or `not-applicable` | exact approved change | work-item IDs or `none` | exact approval or `pending` |

Approved revisions are immutable and form one linear, non-forked, non-cyclic chain.

A requested boundary, requirement, success criterion, required disposition,
work-item set, dependency, order, acceptance, adapter, selector, or structural
decision change creates a new revision. The revision keeps the stable master ID,
increments by exactly one, points `Supersedes` to its immediate predecessor,
records affected items, invalidates affected approvals, preserves unaffected
valid completed evidence, and passes the applicable approval gate.

## Scope completion

Scope-completion formula: every required work item is terminal-success AND no blocker remains AND the dependency graph is valid AND completed-item architecture conformance is PASS AND completed-item selector/schema is PASS AND the terminal scope report enumerates all evidence.

If one item is complete while another required item remains, the only valid
scope verdict is `scope-in-progress`.

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

Every executable master plan declares exactly one bounded `responsibility_contract` discriminator with exact `version: 1` and `applicability: required` before any planned authority row is consumed. Missing, pre-v1, unsupported, duplicate, or mixed plan discriminators block current-plan selection, resume, dependency unlock, and production mutation with `responsibility-contract-version-invalid`; completed historical pre-v1 revisions remain readable but cannot serve as current executable authority.

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

## Delivery Adapter Selection

| Work Item ID | Adapter Kind | External ID | Authority | Authority Revision | Approval Reference | Parent Selector | Acceptance | Trace IDs | Mode Constraint | Design Revision | Parent Work Item ID | Decomposition Decision Reference |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `WORK-<SCOPE>-<NAME>` | canonical adapter kind | exact external selector ID or `not-applicable` | approved selector authority or `not-applicable` | positive authority revision or `not-applicable` | resolved approval evidence or `not-applicable` | approved parent selector or `not-applicable` | exact Work Item acceptance | exact Work Item trace IDs | approved mode/architecture policy | approved design revision | approved parent work item or `not-applicable` | immutable decomposition decision or `not-applicable` |

For `migration-unit`, every `Selected Migration Unit.Plan Reference` is the single canonical composite `Authority@Authority Revision`, with the authority and positive revision copied exactly from `Delivery Adapter Selection`. `Authority` itself MUST NOT contain `@`; consumers MUST reject stale, conflicting, or pre-composed authority/revision sources instead of concatenating them silently.

`Parent Selector` is resolved only from the complete ordered `Delivery Adapter Selection` map. Every non-`none` child whose parent adapter is non-`none` copies the exact parent `External ID`; a root, a `none` child, or a child of a `none` parent uses the lone `not-applicable` sentinel. Selector identities are unique, and a canonical parent row precedes its child. Missing, foreign, duplicate, mismatched, or reordered parent authority is invalid in the master plan and every downstream whole-plan consumer.

Every Work Item has exactly one corresponding selector row. Adapter kind,
external ID, approval, acceptance, trace, mode, and design revision are resolved
from approved current authority; caller repetition is not authority.

## Responsibility Owner References

| Work Item ID | Design Revision | Responsibility IDs | Shared Foundation IDs | Integration Responsibility IDs | Independent Boundary Evidence |
|---|---|---|---|---|---|
| `WORK-<SCOPE>-<NAME>` | exact approved `DESIGN-*@<revision>` from the selector row | ordered concrete `RESP-*` set | ordered shared-foundation `RESP-*` set or `not-applicable` | ordered integration/composition `RESP-*` set or `not-applicable` | immutable rule, decision, or approval reference |

Initial queue selection, resume, and dependency unlock derive planned responsibility authority only from the current approved master plan's exact `Delivery Adapter Selection` and `Responsibility Owner References` rows plus the one approved immutable technical-design artifact matching the same Work Item and design revision. Every referenced responsibility and verification owner must resolve bidirectionally in that design. Responsibility rows use the canonical File Responsibility Matrix vocabulary: `Conformance = yes` passes directly, `Conformance = no` passes only when its exact `DEV-*` joins one approved structural-deviation row with a canonical conflict, resolved decision, and Tech Lead approval, and `Conformance = blocked` always blocks. `PASS` is the derived design-gate outcome, never a responsibility-row value. Missing, stale, foreign, duplicate, overlapping-category, cross-work-item, or caller-attested rows yield `planned-responsibility-authority-invalid` before production mutation. This pre-edit planned authority is distinct from the post-implementation `Architecture Responsibility Handoff`; no handoff artifact is fabricated to authorize the first work item.

```yaml
delivery_adapter:
  kind: migration-unit
  external_id: UNIT-ADM-002
  authority: 08-migration-plan.md
  authority_revision: 3
  approval_reference: approval:UNIT-ADM-002
  parent_selector: not-applicable
```

`none` keeps all selector fields `not-applicable`; its Work Item `Delivery Adapter`
is either `none` or the exact approved internal `generic:<adapter-id>` record.
That generic record is delivery metadata, not an external selector, and assurance
provenance remains keyed by the Work Item. An orchestrator never invents an
external ID. A `migration-unit` selector resolves exactly one approved
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

For every terminal-success Work Item, the terminal artifact's v1 handoff `Evidence References` remains the exact review-originated `source-diff:<task-base>..<final-tree>#<WORK-*>` preserved through Knowledge Base. A separate `Terminal Chain Reference` resolves the final mode-aware chain/KB artifact, and the terminal report Evidence Index binds that same final artifact. Terminal aggregation never rewrites or overloads the immutable handoff evidence cell.

The immutable work-item terminal artifact declares that separate binding exactly once and outside the handoff table:

| Work Item ID | Artifact Reference |
|---|---|
| `WORK-<SCOPE>-<NAME>` | immutable final mode-aware chain/KB `artifact#sha256:<digest>` reference |

This table appears under exactly one `## Terminal Chain Reference` heading. Its Work Item ID equals the terminal artifact identity, and its artifact reference equals the last resolved chain entry. A source-diff, review/intermediate artifact, stale digest, duplicate section, or cross-work-item final reference is invalid terminal authority. Work-item terminal rows, scope handoff source-diffs, and Evidence Index rows retain current master-plan order.

If one item is complete while another required item remains, the only valid
scope verdict is `scope-in-progress`.

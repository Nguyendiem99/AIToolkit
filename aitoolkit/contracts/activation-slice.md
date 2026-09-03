# Activation Slice Contract

## Applicability

An Activation Slice is required when a requirement, source evidence, target
convention, or mapping identifies a config key, profile field, capability,
feature flag, product/device type, or equivalent runtime selector. Each slice
uses a stable `ACT-###` ID and one applicability value:

`applicable | not-applicable-approved | unknown`

`not-applicable-approved` requires evidence and an approval reference. When
applicability cannot be established, record `unknown` and block the artifact.

## Canonical seams

Every slice, including `applicable`, `not-applicable-approved`, and `unknown`,
contains exactly one row for each semantic seam, in this order:

1. `upstream-response`
2. `requested-key`
3. `parse-model`
4. `state-holder`
5. `selector`
6. `construct`
7. `render`
8. `downstream-consumer`
9. `test`

Technology-specific names may be used in evidence, but do not replace these
nine semantic seam names.

## Artifact row schema

| Activation Slice ID | Applicability | Seam | Input | Output | Source Reference | Trace IDs | Disposition | Status | Decision Reference | Deferred Unit ID |
|---|---|---|---|---|---|---|---|---|---|---|
| `ACT-###` | applicability enum | canonical seam | activation input | seam output | evidence location | related trace IDs | disposition enum | status enum | approval or `not-applicable` | deferred unit or `not-applicable` |

`Disposition` is one of:

`implement | reuse | deferred-approved | not-applicable-approved`

`Status` is one of:

`verified | missing | conflict | unknown`

## Identifier formats

Identifiers use ASCII digits only.

| Identifier | Required format |
|---|---|
| Activation Slice ID | `ACT-[0-9]{3}` |
| Migration Unit ID | `UNIT-[0-9]{3}` |
| Deferred Unit ID | `UNIT-[0-9]{3}` |
| Parity test Trace ID | `PARITY-[0-9]{3}` |

## Field requirements

| Field | Required value |
|---|---|
| Input | `<non-empty>` |
| Output | `<non-empty>` |
| Source Reference | `<non-empty>` |
| Trace IDs | `<non-empty>` |

## Legal row combinations

The following table is exhaustive. `not-applicable` is an exact sentinel, not
an empty cell. `<approval-reference>` is non-empty and is not the
`not-applicable` sentinel. The Router evidence schema is the one explicit
override: a `compatibility-dual-path` construct row uses its required approval
reference instead of the ordinary Decision Reference sentinel.

| Applicability | Disposition | Status | Decision Reference | Deferred Unit ID |
|---|---|---|---|---|
| `applicable` | `implement` | `verified` | `not-applicable` | `not-applicable` |
| `applicable` | `implement` | `missing` | `not-applicable` | `not-applicable` |
| `applicable` | `implement` | `conflict` | `not-applicable` | `not-applicable` |
| `applicable` | `implement` | `unknown` | `not-applicable` | `not-applicable` |
| `applicable` | `reuse` | `verified` | `not-applicable` | `not-applicable` |
| `applicable` | `reuse` | `missing` | `not-applicable` | `not-applicable` |
| `applicable` | `reuse` | `conflict` | `not-applicable` | `not-applicable` |
| `applicable` | `reuse` | `unknown` | `not-applicable` | `not-applicable` |
| `applicable` | `deferred-approved` | `verified` | `<approval-reference>` | `UNIT-[0-9]{3}` |
| `applicable` | `deferred-approved` | `missing` | `<approval-reference>` | `UNIT-[0-9]{3}` |
| `applicable` | `deferred-approved` | `conflict` | `<approval-reference>` | `UNIT-[0-9]{3}` |
| `applicable` | `deferred-approved` | `unknown` | `<approval-reference>` | `UNIT-[0-9]{3}` |
| `not-applicable-approved` | `not-applicable-approved` | `verified` | `<approval-reference>` | `not-applicable` |
| `unknown` | `implement` | `unknown` | `not-applicable` | `not-applicable` |
| `unknown` | `reuse` | `unknown` | `not-applicable` | `not-applicable` |

All seams use a canonical seam name. A `not-applicable-approved` row therefore
records approval evidence for each of the same nine semantic seams; it does not
invent a placeholder seam. An `unknown` slice is always activation-blocking.

## Completion and blocking rules

An applicable slice is complete only when all nine seams have source evidence,
trace IDs, and `Status = verified`, and its router and async lifecycle are
resolved. Missing or conflicting activation evidence that can prevent
activation must be recorded as:

```yaml
status: draft
result: blocked
```

It must not be reported as `partial`.

Front matter uses exactly one of these lifecycle pairs:

`Approval source` is one of:

`human | auto | auto-waive`

Every approved artifact carries exactly one canonical `approval_source`. Draft
artifacts may omit it; when present it still uses the canonical enum.

| Slice state | Status | Result |
|---|---|---|
| `non-blocking` | `draft` | `complete` |
| `non-blocking` | `approved` | `complete` |
| `activation-blocking` | `draft` | `blocked` |
| `domain-blocking` | `draft` | `blocked` |
| `step-10 baseline-waiver resume` | `approved` | `partial` |

`approved`, `complete`, and `partial` are invalid in the corresponding field
when activation-blocking evidence exists. A structurally complete slice must
use one of the two `non-blocking` rows unless its canonical step reports a
truthful domain blocker or it is the exact step-10 baseline-waiver resume
described below. `domain-blocking` applies only to a canonical routed step with
its immediate predecessor; it never makes malformed activation or handoff
evidence valid. Activation validation is one-way: a valid slice does not
prohibit the domain-blocked lifecycle or the exact partial outcome for the
non-activation baseline concern.

## Domain-blocker evidence

A routed `draft/blocked` artifact whose Activation Slice and handoff are
otherwise valid records at least one truthful domain blocker. Parity and
regression may use their canonical structured blocked scenario and overall
verdict as this evidence; every other routed step uses the record below.

| Section | Required columns | Cardinality | Value predicates |
|---|---|---|---|
| `Domain Blocker` | `Blocker, Evidence Reference` | `at-least-one` | `non-empty-non-placeholder` |

## Placeholder value semantics

`non-empty-non-placeholder` compares the whole rendered cell value after
outer Markdown emphasis, code, or link decoration is removed. Matching is
case-insensitive. Concrete references such as `artifacts/none/error.log` are
not placeholders merely because a path segment resembles a sentinel.

| Predicate | Exact sentinels | Pattern sentinel |
|---|---|---|
| `non-empty-non-placeholder` | `TBD, TODO, TBC, pending, unknown, N/A, null, none, unset, placeholder, not-applicable, pending-before-edit, pending-bootstrap, pending-step09-approval, pending-approval, -, ???` | `angle-bracket-placeholder` |

Technical design is not executable until router ownership and asynchronous reselection/lifecycle decisions are resolved.

## Step 10 baseline-waiver resume

This lifecycle is available only when activation validation itself is
non-blocking. The current artifact and a resumed step-10 predecessor use the
exact established tuple below; no other partial lifecycle is valid.

| Field | Required value |
|---|---|
| `step_id` | `10-code-migration` |
| `status` | `approved` |
| `result` | `partial` |
| `approval_source` | `auto-waive` |
| `waiver.policy` | `auto-waive` |
| `waiver.category` | `environment-unavailable` |
| `waiver.original_verdict` | `blocked` |
| `waiver.effective_action` | `continue` |
| `waiver.evidence` | `<non-empty>` |

## Step 10 resume evidence

The approved waiver body repeats the approved lifecycle and waiver mapping; it
does not replace front matter. A resumed invocation preserves the native
blocker and approved waiver body ordinally from its immediate step-10
predecessor. Each declared record has exactly the cardinality shown.

| Record | Section | Required columns or fields | Cardinality | Preservation |
|---|---|---|---|---|
| `native-blocker` | `Blocker gốc` | `Stage / Check, Native Verdict, Command Role, Required Command Lifecycle, Command / Capability, Observed Error, Evidence Reference` | `exactly-one-row` | `ordinal-exact-predecessor` |
| `approved-waiver-body` | `Approved Baseline Waiver` | `status, result, approval_source, waiver.policy, waiver.category, waiver.original_verdict, waiver.effective_action, waiver.evidence` | `exactly-one-yaml-record` | `exact-front-matter-and-ordinal-exact-predecessor` |
| `resume-state` | `Step 10 Waiver Resume State` | `Resume Phase, Baseline Action, Implementation Status, Target Mutation Evidence, Waiver Evidence` | `exactly-one-row` | `canonical-resume-state` |

## Step 10 resume state

The predecessor is the approved blocked-baseline waiver record awaiting
re-entry. The current artifact proves that re-entry consumed only that baseline
exception and still mutated target source for the selected unit. Target mutation
evidence names the exact selected Migration Unit ID and at least one of its
selected-unit Trace IDs. `Waiver Evidence` equals `waiver.evidence` ordinally.

| Artifact role | Resume Phase | Baseline Action | Implementation Status | Target Mutation Evidence | Waiver Evidence |
|---|---|---|---|---|---|
| `predecessor` | `resume-required` | `skip-pre-mutation-baseline-only` | `blocked` | `none` | `exact waiver.evidence` |
| `current` | `resume-consumed` | `skip-pre-mutation-baseline-only` | `<non-blocked>` | `<selected Migration Unit ID and Trace ID>` | `exact waiver.evidence` |

## Step 10 native blocker eligibility

The native blocker remains the existing waiver-eligible pre-mutation baseline
record. Preserving identical text cannot turn a required command result into an
availability probe.

| Field | Required value |
|---|---|
| `Stage / Check` | `pre-mutation baseline` |
| `Native Verdict` | `BLOCKED` |
| `Command Role` | `availability probe` |
| `Required Command Lifecycle` | `not-started` |
| `Evidence Reference` | `exact waiver.evidence` |

## Immediate predecessor roles and lifecycle

Validate this role and lifecycle edge before comparing Activation Slice or any
selected-unit envelope. `draft/blocked` is the only current lifecycle admitted
after an activation or handoff error. `<canonical>` requires the predecessor's
own canonical front matter, including exactly one approval source. The
`discovery-origin` creates the first envelope only when step 01 has none; if
step 01 already carries a canonical envelope, discovery preserves it exactly
like every other handoff. `<not-applicable>` means the route has not selected a
migration unit yet and the current artifact must not contain a visible
`Selected Migration Unit` section.

Its `Plan Reference` is always the exact composite `Delivery Adapter Selection.Authority@Delivery Adapter Selection.Authority Revision`. The revision is a positive integer and `Authority` is an unversioned value that MUST NOT itself contain `@`; all implementation, review, verification, parity, regression, and knowledge-base handoffs preserve this value byte-for-byte.

| Route | Current step ID | Current lifecycle | Predecessor step ID | Predecessor Status | Predecessor Result | Predecessor Approval Source | Predecessor Waiver | Selected Mode Constraint | Selected Bootstrap Scope |
|---|---|---|---|---|---|---|---|---|---|
| `discovery-origin` | `02-discovery` | `draft/complete, approved/complete, draft/blocked` | `01-validate-inputs` | `approved` | `complete, partial` | `<canonical>` | `<any>` | `<not-applicable>` | `<not-applicable>` |
| `handoff` | `03-analyze-requirements-uiux` | `draft/complete, approved/complete, draft/blocked` | `02-discovery` | `approved` | `complete` | `<canonical>` | `<any>` | `<not-applicable>` | `<not-applicable>` |
| `handoff` | `04-build-inventory` | `draft/complete, approved/complete, draft/blocked` | `03-analyze-requirements-uiux` | `approved` | `complete` | `<canonical>` | `<any>` | `<not-applicable>` | `<not-applicable>` |
| `handoff` | `05-feature-mapping` | `draft/complete, approved/complete, draft/blocked` | `04-build-inventory` | `approved` | `complete` | `<canonical>` | `<any>` | `<not-applicable>` | `<not-applicable>` |
| `handoff` | `06-analyze-gaps-conflicts` | `draft/complete, approved/complete, draft/blocked` | `05-feature-mapping` | `approved` | `complete` | `<canonical>` | `<any>` | `<not-applicable>` | `<not-applicable>` |
| `handoff` | `07-technical-design` | `draft/complete, approved/complete, draft/blocked` | `06-analyze-gaps-conflicts` | `approved` | `complete` | `<canonical>` | `<any>` | `<not-applicable>` | `<not-applicable>` |
| `handoff` | `08-plan-waves` | `draft/complete, approved/complete, draft/blocked` | `07-technical-design` | `approved` | `complete` | `<canonical>` | `<any>` | `<not-applicable>` | `<not-applicable>` |
| `bootstrap` | `09-bootstrap-target` | `draft/complete, approved/complete, draft/blocked` | `08-plan-waves` | `approved` | `complete` | `<canonical>` | `<any>` | `greenfield/design-new` | `required` |
| `initial` | `10-code-migration` | `draft/complete, approved/complete, draft/blocked` | `08-plan-waves` | `approved` | `complete` | `<canonical>` | `<any>` | `<canonical>` | `not-required` |
| `initial` | `10-code-migration` | `draft/complete, approved/complete, draft/blocked` | `09-bootstrap-target` | `approved` | `complete` | `<canonical>` | `<any>` | `greenfield/design-new` | `required` |
| `baseline-waiver-resume` | `10-code-migration` | `approved/partial, draft/blocked` | `10-code-migration` | `approved` | `partial` | `auto-waive` | `exact-baseline-waiver` | `incremental/preserve-existing` | `not-required` |
| `post-implementation` | `11-ai-review` | `draft/complete, approved/complete, draft/blocked` | `10-code-migration` | `approved` | `complete` | `<canonical>` | `<any>` | `<canonical>` | `<canonical>` |
| `post-waiver-resume` | `11-ai-review` | `draft/complete, approved/complete, draft/blocked` | `10-code-migration` | `approved` | `partial` | `auto-waive` | `exact-baseline-waiver` | `incremental/preserve-existing` | `not-required` |
| `handoff` | `12-verification-testing` | `draft/complete, approved/complete, draft/blocked` | `11-ai-review` | `approved` | `complete` | `<canonical>` | `<any>` | `<canonical>` | `<canonical>` |
| `handoff` | `13-verify-parity` | `draft/complete, approved/complete, draft/blocked` | `12-verification-testing` | `approved` | `complete` | `<canonical>` | `<any>` | `<canonical>` | `<canonical>` |
| `handoff` | `14-verify-regression` | `draft/complete, approved/complete, draft/blocked` | `13-verify-parity` | `approved` | `complete` | `<canonical>` | `<any>` | `incremental/preserve-existing` | `not-required` |
| `handoff` | `15-knowledge-base` | `draft/complete, approved/complete, draft/blocked` | `13-verify-parity` | `approved` | `complete` | `<canonical>` | `<any>` | `greenfield/design-new` | `<canonical>` |
| `handoff` | `15-knowledge-base` | `draft/complete, approved/complete, draft/blocked` | `14-verify-regression` | `approved` | `complete` | `<canonical>` | `<any>` | `incremental/preserve-existing` | `not-required` |

## Bootstrap selected-unit handoff

Step 09 resolves exactly one approved, greenfield, bootstrap-required ordered
plan row. It preserves the mapped identity fields. A pre-mutation blocker keeps
the plan sentinels and has no foundation record. A completed pre-gate draft has
created the foundation but retains the pending approval sentinel. Approval
atomically replaces that sentinel with one approved foundation record. Every
declared required column is non-empty, and every Migration Unit ID uses the
canonical identifier format.

| Current lifecycle | Current step ID | Predecessor step ID | Current Unit Section | Predecessor Unit Section | Exact mapped fields | Predecessor predicates | Current predicates | Foundation Section | Foundation required columns | Foundation predicates |
|---|---|---|---|---|---|---|---|---|---|---|
| `draft/blocked` | `09-bootstrap-target` | `08-plan-waves` | `Selected Migration Unit` | `Các đơn vị migration theo thứ tự` | `Migration Unit ID, Approval Reference, Mode Constraint, Bootstrap Scope, Trace IDs` | `Approval Status=approved; Foundation Baseline ID=pending-bootstrap; Foundation Approval Reference=pending-step09-approval` | `Mode Constraint=greenfield/design-new; Bootstrap Scope=required; Foundation Baseline ID=pending-bootstrap; Foundation Baseline Reference=not-applicable; Foundation Baseline Approval Reference=pending-step09-approval; Baseline Reference=not-applicable` | `<absent>` | `<not-applicable>` | `<absent>` |
| `draft/complete` | `09-bootstrap-target` | `08-plan-waves` | `Selected Migration Unit` | `Các đơn vị migration theo thứ tự` | `Migration Unit ID, Approval Reference, Mode Constraint, Bootstrap Scope, Trace IDs` | `Approval Status=approved; Foundation Baseline ID=pending-bootstrap; Foundation Approval Reference=pending-step09-approval` | `Mode Constraint=greenfield/design-new; Bootstrap Scope=required; Foundation Baseline ID=FOUNDATION-*; Foundation Baseline Reference=<non-sentinel>; Foundation Baseline Approval Reference=pending-step09-approval; Baseline Reference=not-applicable` | `Bản ghi baseline nền tảng` | `Foundation Baseline ID, Source Migration Unit ID, Target Baseline Reference, Approval Reference, Approval Status, Evidence` | `Approval Reference=pending-step09-approval; Approval Status=pending-approval; selected-unit-correlated` |
| `approved/complete` | `09-bootstrap-target` | `08-plan-waves` | `Selected Migration Unit` | `Các đơn vị migration theo thứ tự` | `Migration Unit ID, Approval Reference, Mode Constraint, Bootstrap Scope, Trace IDs` | `Approval Status=approved; Foundation Baseline ID=pending-bootstrap; Foundation Approval Reference=pending-step09-approval` | `Mode Constraint=greenfield/design-new; Bootstrap Scope=required; Foundation Baseline ID=FOUNDATION-*; Foundation Baseline Reference=<non-sentinel>; Foundation Baseline Approval Reference=<approved-reference>; Baseline Reference=not-applicable` | `Bản ghi baseline nền tảng` | `Foundation Baseline ID, Source Migration Unit ID, Target Baseline Reference, Approval Reference, Approval Status, Evidence` | `Approval Status=approved; selected-unit-correlated` |

## Step 10 predecessor unit selection

Initial step 10 accepts the approved plan or approved bootstrap artifact. A
baseline-waiver resume accepts only the exact prior step-10 waiver artifact and
preserves its complete selected-unit record. Step 08 remains an ordered
collection of candidate units: step 10 resolves its current selected unit to
exactly one approved matching plan row.

| Invocation | Predecessor step ID | Current Unit Section | Predecessor Unit Section | Predecessor Unit Selection | Predecessor Unit Required Columns | Predecessor Unit Approval | Required Mode Constraint | Required Bootstrap Scope | Selected Unit Preservation | Foundation Record |
|---|---|---|---|---|---|---|---|---|---|---|
| `initial` | `08-plan-waves` | `Selected Migration Unit` | `Các đơn vị migration theo thứ tự` | `exactly-one-approved-current-match` | `Order, Migration Unit ID, Bootstrap Scope, Foundation Baseline ID, Foundation Approval Reference, Dependencies, Acceptance, Mode Constraint, Trace IDs, Delivery Change Boundary, Approval Reference, Approval Status` | `Approval Status=approved` | `<canonical>` | `not-required` | `mapped-plan-fields` | `mode-aware-direct-plan` |
| `initial` | `09-bootstrap-target` | `Selected Migration Unit` | `Selected Migration Unit` | `exactly-one-current-match` | `Migration Unit ID, Plan Reference, Approval Reference, Mode Constraint, Bootstrap Scope, Foundation Baseline ID, Foundation Baseline Reference, Foundation Baseline Approval Reference, Baseline Reference, Trace IDs` | `<not-applicable>` | `greenfield/design-new` | `required` | `ordinal-exact-predecessor` | `approved-matching` |
| `baseline-waiver-resume` | `10-code-migration` | `Selected Migration Unit` | `Selected Migration Unit` | `ordinal-exact-current` | `Migration Unit ID, Plan Reference, Approval Reference, Mode Constraint, Bootstrap Scope, Foundation Baseline ID, Foundation Baseline Reference, Foundation Baseline Approval Reference, Baseline Reference, Trace IDs` | `<not-applicable>` | `incremental/preserve-existing` | `not-required` | `ordinal-exact-predecessor` | `<not-applicable>` |

## Direct-plan foundation state

The direct step-08 to step-10 route resolves exactly one mode row below. The
incremental route carries no foundation. A later-greenfield route correlates
its selected tuple to exactly one approved foundation record in the immediate
plan predecessor; an apparently resolved tuple without that record is invalid.

| Mode Constraint | Bootstrap Scope | Plan Foundation Baseline ID | Plan Foundation Approval Reference | Current Foundation Baseline ID | Current Foundation Baseline Reference | Current Foundation Baseline Approval Reference | Current Baseline Reference | Foundation Section | Foundation required columns | Foundation predicates |
|---|---|---|---|---|---|---|---|---|---|---|
| `incremental/preserve-existing` | `not-required` | `not-applicable` | `not-applicable` | `not-applicable` | `not-applicable` | `not-applicable` | `<resolved-pre-mutation-baseline-reference>` | `<not-applicable>` | `<not-applicable>` | `<not-applicable>` |
| `greenfield/design-new` | `not-required` | `FOUNDATION-*` | `<approved-reference>` | `same-plan` | `same-approved-record` | `same-plan` | `not-applicable` | `Baseline nền tảng đã duyệt` | `Foundation Baseline ID, Target Baseline Reference, Approval Reference, Approval Status, Evidence` | `exactly-one-approved-selected-match` |

## Delivery adapter evidence by artifact role

Adapter authority is role-specific. Step 10 resolves the exact visible
producer table and never falls back to a downstream bullet. Steps 11 through 15
resolve exactly one visible `Delivery Adapter Kind` bullet and one visible
`Delivery Adapter Mode Constraint` bullet. A visible bullet uses the exact
case-sensitive label, zero to three leading spaces, a `-` marker, and at least
one following space or tab. Comment, fence, indented-code, hanging-paragraph,
wrong-case, and malformed-marker decoys do not count.

| Artifact step IDs | Canonical source | Required schema | Cardinality |
|---|---|---|---|
| `10-code-migration` | `Canonical Adapter Evidence` | `Work Item ID, Adapter Kind, External ID, Authority, Authority Revision, Approval Reference, Parent Selector, Acceptance, Trace IDs, Mode Constraint, Design Revision, Parent Work Item ID, Decomposition Decision Reference, Canonical Match` | `exactly-one-visible-row` |
| `11-ai-review, 12-verification-testing, 13-verify-parity, 14-verify-regression, 15-knowledge-base` | `Delivery Adapter Kind, Delivery Adapter Mode Constraint` | `Adapter Kind, Mode Constraint` | `exactly-one-visible-line-each` |

For a `migration-unit` step-10 producer, the canonical row's `Work Item ID`
equals `Master Scope Context.Work Item ID`; `External ID`, `Approval Reference`,
`Mode Constraint`, and `Trace IDs` equal their `Selected Migration Unit`
counterparts ordinally. `Authority` is non-empty and unversioned, `Authority
Revision` is a positive integer, and `Selected Migration Unit.Plan Reference`
is their exact `Authority@Authority Revision` composite.

Step 11 binds both downstream bullets to the step-10 canonical row. Each later
edge preserves both values byte-for-byte from its immediate predecessor. A
`migration-unit` mode also equals `Selected Migration Unit.Mode Constraint`.
Generic adapters have no selected-unit row and therefore carry the implicit
`Bootstrap Scope = not-required`; their explicit mode is still approved-plan
authority, never caller-attested. Greenfield chains terminate directly from
step 13 at step 15, while incremental chains require step 14 before step 15.

## Downstream selected-unit handoff

Downstream assurance artifacts bind their adapter kind to the approved current
master-plan selection. Migration-unit artifacts preserve exactly one complete
selected-unit row ordinally from their immediate predecessor; generic adapters
omit the section.

| Current step ID | Adapter Kind Applicability | Section | Required columns | Preservation |
|---|---|---|---|---|
| `11-ai-review` | `migration-unit` | `Selected Migration Unit` | `Migration Unit ID, Plan Reference, Approval Reference, Mode Constraint, Bootstrap Scope, Foundation Baseline ID, Foundation Baseline Reference, Foundation Baseline Approval Reference, Baseline Reference, Trace IDs` | `ordinal-exact-predecessor` |
| `12-verification-testing` | `migration-unit` | `Selected Migration Unit` | `Migration Unit ID, Plan Reference, Approval Reference, Mode Constraint, Bootstrap Scope, Foundation Baseline ID, Foundation Baseline Reference, Foundation Baseline Approval Reference, Baseline Reference, Trace IDs` | `ordinal-exact-predecessor` |
| `13-verify-parity` | `migration-unit` | `Selected Migration Unit` | `Migration Unit ID, Plan Reference, Approval Reference, Mode Constraint, Bootstrap Scope, Foundation Baseline ID, Foundation Baseline Reference, Foundation Baseline Approval Reference, Baseline Reference, Trace IDs` | `ordinal-exact-predecessor` |
| `14-verify-regression` | `migration-unit` | `Selected Migration Unit` | `Migration Unit ID, Plan Reference, Approval Reference, Mode Constraint, Bootstrap Scope, Foundation Baseline ID, Foundation Baseline Reference, Foundation Baseline Approval Reference, Baseline Reference, Trace IDs` | `ordinal-exact-predecessor` |
| `15-knowledge-base` | `migration-unit` | `Selected Migration Unit` | `Migration Unit ID, Plan Reference, Approval Reference, Mode Constraint, Bootstrap Scope, Foundation Baseline ID, Foundation Baseline Reference, Foundation Baseline Approval Reference, Baseline Reference, Trace IDs` | `ordinal-exact-predecessor` |
| `11-ai-review, 12-verification-testing, 13-verify-parity, 14-verify-regression, 15-knowledge-base` | `task, story, package, phase, milestone, none` | `<absent>` | `<not-applicable>` | `ordinal-absence` |

## Regression parity handoff

Regression consumes exactly one structured overall parity verdict and evidence
reference from its immediate parity predecessor. It preserves the verdict
ordinally and retains the predecessor evidence reference exactly or enriches it
with `; <non-whitespace regression evidence>`.

| Current step ID | Predecessor step ID | Predecessor section | Predecessor required columns | Parity Verdict Values | Regression Predecessor Parity Values | Current section | Current required columns | Regression Applicability | Regression Verdict Values | Required Mode Constraint | Required Bootstrap Scope | Evidence preservation |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `14-verify-regression` | `13-verify-parity` | `Parity Verdict` | `Parity Verdict, Evidence Reference` | `pass, fail, blocked` | `pass, fail` | `Kết luận xác minh migration` | `Parity Verdict, Regression Applicability, Regression Verdict, Evidence Reference` | `required` | `pass, fail, blocked` | `incremental/preserve-existing` | `not-required` | `exact or <predecessor>; <non-whitespace evidence>` |

## Assurance task provenance handoff

Verification anchors exactly one `Task Provenance` row to the immediate review
artifact's `Change Hygiene` row. Parity and regression then preserve that
lineage through their immediate predecessor's `Task Provenance` row. Every
declared field mapping is ordinal-exact. The current `Source Artifact` must
resolve to the exact artifact path supplied as the immediate predecessor; an
unrelated, stale, or merely different path is invalid.
Both lineage rows resolve assurance identity from the approved adapter: a
`migration-unit` binds `Task / Unit` to its selected Migration Unit ID, while a
generic adapter binds `Task / Unit` to the current `Master Scope Context` Work
Item ID. Their task-base and final-tree references are resolved non-placeholder
values.

| Current step ID | Predecessor step ID | Current section | Current required columns | Predecessor section | Predecessor required columns | Preserved field mapping | Intrinsic predicates | Source Artifact rule |
|---|---|---|---|---|---|---|---|---|
| `12-verification-testing` | `11-ai-review` | `Task Provenance` | `Task / Unit, Task-base SHA, Final-tree SHA, Source Artifact` | `Change Hygiene` | `Task / Unit, Scope Evidence, Formatter Evidence, Unrelated Diff, Severity, Task-base SHA, Final-tree SHA` | `Task / Unit=Task / Unit, Task-base SHA=Task-base SHA, Final-tree SHA=Final-tree SHA` | `Adapter Kind=migration-unit => Task / Unit=Selected Migration Unit.Migration Unit ID; Adapter Kind=generic => Task / Unit=Master Scope Context.Work Item ID, Task-base SHA=non-empty-non-placeholder, Final-tree SHA=non-empty-non-placeholder` | `resolves-to-immediate-predecessor-path` |
| `13-verify-parity` | `12-verification-testing` | `Task Provenance` | `Task / Unit, Task-base SHA, Final-tree SHA, Source Artifact` | `Task Provenance` | `Task / Unit, Task-base SHA, Final-tree SHA, Source Artifact` | `Task / Unit=Task / Unit, Task-base SHA=Task-base SHA, Final-tree SHA=Final-tree SHA` | `Adapter Kind=migration-unit => Task / Unit=Selected Migration Unit.Migration Unit ID; Adapter Kind=generic => Task / Unit=Master Scope Context.Work Item ID, Task-base SHA=non-empty-non-placeholder, Final-tree SHA=non-empty-non-placeholder` | `resolves-to-immediate-predecessor-path` |
| `14-verify-regression` | `13-verify-parity` | `Task Provenance` | `Task / Unit, Task-base SHA, Final-tree SHA, Source Artifact` | `Task Provenance` | `Task / Unit, Task-base SHA, Final-tree SHA, Source Artifact` | `Task / Unit=Task / Unit, Task-base SHA=Task-base SHA, Final-tree SHA=Final-tree SHA` | `Adapter Kind=migration-unit => Task / Unit=Selected Migration Unit.Migration Unit ID; Adapter Kind=generic => Task / Unit=Master Scope Context.Work Item ID, Task-base SHA=non-empty-non-placeholder, Final-tree SHA=non-empty-non-placeholder` | `resolves-to-immediate-predecessor-path` |

## Assurance verdict consistency

The structured row is the sole overall verdict surface; a visible legacy
`Kết luận` section is forbidden. Each assurance report contains at least one
scenario row. Scenario verdicts use the declared enum and aggregate in this
order: `blocked` if any scenario is blocked, otherwise `fail` if any scenario
fails, otherwise `pass`. The aggregate equals the structured overall verdict.
A structured `blocked` overall verdict uses `draft/blocked`; `pass` or `fail`
uses a complete lifecycle.

| Step ID | Overall section | Overall verdict field | Scenario section | Scenario required columns | Verdict values | Aggregate |
|---|---|---|---|---|---|---|
| `13-verify-parity` | `Parity Verdict` | `Parity Verdict` | `Kịch bản` | `Scenario, Baseline, Actual, Verdict` | `pass, fail, blocked` | `blocked-any; else-fail-any; else-pass` |
| `14-verify-regression` | `Kết luận xác minh migration` | `Regression Verdict` | `Kịch bản` | `Scenario, Baseline, Actual, Delta Class, Waiver Reference, Trace IDs, Verdict` | `pass, fail, blocked` | `blocked-any; else-fail-any; else-pass` |

## Router ownership

The `construct` seam records exactly one approved router mapping policy:

- `base-owned`
- `specialized-owned`
- `injected-strategy`
- `compatibility-dual-path`

`compatibility-dual-path` requires a compatibility reason, owner, approval
reference, and parity-test trace. Unresolved ownership conflicts block the
slice.

## Router evidence schema

| Router Policy | Artifact location | Required key | Required value |
|---|---|---|---|
| `base-owned` | `construct.Output` | `policy` | `exact` |
| `specialized-owned` | `construct.Output` | `policy` | `exact` |
| `injected-strategy` | `construct.Output` | `policy` | `exact` |
| `compatibility-dual-path` | `construct.Output` | `policy` | `exact` |
| `compatibility-dual-path` | `construct.Source Reference` | `compatibility-reason` | `compatibility-reason=<non-empty>` |
| `compatibility-dual-path` | `construct.Source Reference` | `router-owner` | `router-owner=<non-empty>` |
| `compatibility-dual-path` | `construct.Decision Reference` | `approval-reference` | `<non-not-applicable>` |
| `compatibility-dual-path` | `construct.Trace IDs` | `parity-test` | `PARITY-###` |

## Async lifecycle

If activation state can arrive or change asynchronously, the design records:

- initial loading behavior;
- update/watch strategy;
- reselection behavior;
- state preservation/reset behavior;
- failure behavior; and
- lifecycle test trace.

A one-shot read is not verified when state can later change without evidence
that the state is immutable.

## Async evidence schema

| Classification | Artifact location | Required key | Required value |
|---|---|---|---|
| `async` | `selector.Input` | `async-classification` | `async-classification=async` |
| `async` | `selector.Output` | `initial-loading` | `initial-loading=<non-empty>` |
| `async` | `selector.Output` | `update-watch` | `update-watch=<non-empty>` |
| `async` | `selector.Output` | `reselection` | `reselection=<non-empty>` |
| `async` | `selector.Output` | `state-preservation-reset` | `state-preservation-reset=<non-empty>` |
| `async` | `selector.Output` | `failure-behavior` | `failure-behavior=<non-empty>` |
| `async` | `test.Output` | `lifecycle-test-trace` | `lifecycle-test-trace=<trace-id>` |
| `immutable` | `selector.Input` | `async-classification` | `async-classification=immutable` |
| `immutable` | `selector.Source Reference` | `immutability-evidence` | `immutability-evidence=<non-empty>` |

## Handoff invariants

Each artifact preserves the complete, case-sensitive set of stable Activation
Slice IDs, the applicability of every slice, and all seam rows. No applicability
transition is implicitly approved. A handoff may enrich its owned fields and
Source Reference evidence, but must not add, remove, duplicate, or rename a
slice or semantic seam. For each `(Activation Slice ID, Seam)` pair, predecessor
Trace IDs are an append-only subset of successor Trace IDs.
Source Reference enrichment is also append-only: the successor retains the
predecessor value as an exact prefix and may append `; <new evidence>`.

## Source Reference enrichment

Source Reference is either retained exactly or enriched with the exact
semicolon-space separator and a trimmed, non-empty evidence suffix.

| Field | Allowed successor shape |
|---|---|
| `Source Reference` | `exact or <predecessor>; <non-whitespace evidence>` |

## Implementation linkage

Every completed step-10 output resolves every implementation record against the
approved Activation Slice envelope in its valid immediate predecessor,
including a bootstrap predecessor on the greenfield foundation route. Step 11
revalidates those records against the step-10 predecessor's preserved envelope.
A normal complete output contains at least one row in every applicable
changed-file and test-evidence section. A structurally valid `draft/blocked`
pre-mutation output may omit those records; if an applicable section is present,
it remains fully validated. Generic Work Item rows bind their `Work Item ID`
ordinally to the step-10 `Canonical Adapter Evidence` row. Their non-empty Trace
IDs are subsets of both that canonical adapter row and the cited approved
`(Activation Slice ID, Seam)` trace set. A file or test that covers more than one
seam repeats one structured row per link.

| Record | Current step ID | Allowed predecessor step IDs | Adapter Kind Applicability | Section | Required columns |
|---|---|---|---|---|---|
| `selected-unit` | `10-code-migration` | `08-plan-waves, 09-bootstrap-target, 10-code-migration` | `migration-unit` | `Selected Migration Unit` | `Migration Unit ID, Plan Reference, Approval Reference, Mode Constraint, Bootstrap Scope, Foundation Baseline ID, Foundation Baseline Reference, Foundation Baseline Approval Reference, Baseline Reference, Trace IDs` |
| `changed-file` | `10-code-migration` | `08-plan-waves, 09-bootstrap-target, 10-code-migration` | `migration-unit` | `File đã thay đổi` | `Migration Unit ID, Activation Slice ID, Seam, File, Change, Trace IDs` |
| `test-evidence` | `10-code-migration` | `08-plan-waves, 09-bootstrap-target, 10-code-migration` | `migration-unit` | `Activation Slice Test Evidence` | `Migration Unit ID, Activation Slice ID, Seam, Test, Command, Result, Trace IDs` |
| `work-item-changed-file` | `10-code-migration` | `08-plan-waves, 09-bootstrap-target, 10-code-migration` | `task, story, package, phase, milestone, none` | `Work Item Changed Files` | `Work Item ID, Activation Slice ID, Seam, File, Change, Trace IDs` |
| `work-item-test-evidence` | `10-code-migration` | `08-plan-waves, 09-bootstrap-target, 10-code-migration` | `task, story, package, phase, milestone, none` | `Work Item Test Evidence` | `Work Item ID, Activation Slice ID, Seam, Test, Command, Result, Trace IDs` |

Each link uses an approved slice ID and canonical seam from that predecessor.
Its non-empty Trace IDs are a subset of the predecessor Trace IDs stored for
the same `(Activation Slice ID, Seam)` pair. Prose elsewhere in the report does
not replace these records.

## Quick reference

Start with applicability, trace all nine seams in order, select one router
policy, document async lifecycle where relevant, and use `test` evidence to
verify the end-to-end activation flow.

## Common mistakes

- Treating a downstream panel or provider as proof that the module activates.
- Omitting `requested-key` or `parse-model` because a later seam exists.
- Reporting an activation-blocking missing seam as `partial`.
- Allowing base and specialized routers to own the same mapping without an
  approved policy.

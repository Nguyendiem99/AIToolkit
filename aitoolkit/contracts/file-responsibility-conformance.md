---
version: 1
applicability: required
---

# File Responsibility Conformance Contract

This is the sole canonical authority for responsibility conformance. Other
contracts and schemas route here and must not duplicate its enums or tables.

## Contract Version

```text
version = 1
applicability = required
```

## Exemplar Classification

```text
Inspection Status = verified | no-equivalent | unknown
Classification = preferred | compatibility-only | legacy-debt | no-equivalent
```

## Architecture Authority

```text
Architecture Authority = target-exemplar | approved-greenfield-design | approved-structural-deviation
```

`approved-greenfield-design` is positive design authority, not a fake
deviation. Greenfield work does not manufacture an exemplar deviation merely
because no prior target exists.

## File Responsibility Matrix

```text
Boundary Kind = domain | data | application | presentation | adapter | integration | config | test | project-defined
Conformance = yes | no | blocked
```

| Responsibility ID | Owner Path | Owner Symbol | Boundary Kind | Primary Responsibility | Owned Capability IDs | Trace IDs | Atomic Boundary ID | Public Symbols | External Effects | Target Exemplar | Exemplar Classification | Classification Authority | Classification Evidence | Architecture Authority | Co-location Policy | Co-location Evidence | Verification Owner References | Conformance | Deviation Reference |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| RESP-### | canonical path | publicSymbol | presentation | one responsibility | CAP-### | TRACE-### | not-applicable | publicSymbol | none | target/reference#Symbol | preferred | factual-discovery-evidence | inspection:path:1-20 | target-exemplar | feature-local | evidence reference | VERIFY-OWNER-### | yes | not-applicable |

Each row names its capability independently from its trace. The matrix has
exactly twenty columns; a capability identifier must never be inferred from a
class name or line range.
`Public Symbols` is either a non-empty canonical symbol list or the exact lone
sentinel `none` when the responsibility truthfully exports no public symbols;
the sentinel cannot be mixed with symbols. `Conformance = no` requires an exact
approved `DEV-*` reference and may still gate PASS under that approval.
`Conformance = blocked` is always blocking.

## Co-location Semantics

```text
Co-location Policy = feature-local | shared-foundation | atomic-owner | approved-deviation | not-applicable
```

`not-applicable` is a disposition, not evidence that a capability is absent.
An atomic owner keeps an inseparable capability boundary together; shared
foundation is not a license to spread unrelated feature responsibility.

## Verification Ownership Matrix

| Verification Owner ID | Production Responsibility ID | Capability ID | Evidence Path | Evidence Symbol or Scenario | Evidence Kind | Verification Disposition | Production Binding Evidence | Decision Reference | Verdict | Deviation Reference |
|---|---|---|---|---|---|---|---|---|---|---|
| VERIFY-OWNER-### | RESP-### | CAP-### | evidence path | scenario | unit | required | binding evidence | decision reference | PASS | not-applicable |

```text
Evidence Kind = unit | integration | contract | production-composition | static-structure | generator-verification
Verification Disposition = required | not-applicable-approved
```

Evidence Kind and Verification Disposition are separate fields. A
`not-applicable-approved` disposition needs its approval reference and does
not change the structural verdict.

## Actual Responsibility Evidence

Actual responsibility is recorded against owned capability IDs, atomic
boundary IDs, and evidence references. It is not established by a heuristic
class-name match, a line count, or a file-location guess.

## Changed Git Path Classification and Reconciliation

Independent review derives the changed-path inventory from the immutable pinned
`task-base..final-tree` Git comparison, including `M`, `A`, `R`, `C`, and `D`.
Repository-relative paths rooted at `src/`, `lib/`, `app/`, `apps/*/src|lib|app`,
`packages/*/src|lib|app`, `server/`, `client/`, `frontend/`, or `backend/` are
canonically production-classified; nested test, spec, doc, script, tool,
generated, build, and distribution roots are excluded unless an approved
responsibility explicitly selects them. Marker presence never determines
whether a changed path enters the inventory. Normalize repository-relative
backslashes to `/` once before comparing design, review, Git, Change Hygiene,
verification binding, or source evidence; absolute paths, empty segments, and
`.`/`..` segments are invalid. Canonical Git inventory is NUL-delimited,
preserves Unicode letters and embedded spaces with NFC normalization, and
rejects control characters or contract-delimiter ambiguity. Equivalent source
root spellings with one trailing directory separator resolve to the same Git
root.

### Language-valid semantic marker encoding

Real source and verification producers emit each responsibility-contract
payload as an exact whole-line language comment. C-family comment languages
(`.c`, `.h`, `.cc`, `.cpp`, `.java`, `.js`, `.ts`, `.dart`, `.cs`, `.rs`,
`.go`, `.swift`, `.kt`, and `.scala`, including their recognized variants) use
`// arc:@responsibility RESP-*` for owner declarations, `// arc:@...` for the
remaining owner or verification fields, paired `// arc:@ownership-begin RESP-*`
and `// arc:@ownership-end RESP-*` range delimiters, `// arc:route` for
production route evidence, and `// arc:scenario` for verification execution evidence. Hash
comment languages (`.py`, `.sh`, `.rb`, `.pl`, `.yaml`, `.toml`, and
PowerShell source) use `# arc:@responsibility RESP-*`, `# arc:@...`, paired
`# arc:@ownership-begin RESP-*` and `# arc:@ownership-end RESP-*`, `# arc:route`,
and `# arc:scenario` respectively. The consumer strips exactly
one recognized `arc:` comment sentinel and evaluates its payload as semantic
metadata; it does not require a language-invalid bare pseudo-statement.

The sentinel must occupy the whole active lexical line apart from whitespace.
Each owner declaration and its metadata is followed by exactly one begin marker
with the same case-sensitive responsibility ID and exactly one matching end
marker. Ranges are inclusive, ordered, non-nesting, and non-overlapping. Missing,
orphan, duplicate, malformed, crossed, or mismatched delimiters fail closed; the
consumer never infers a range end from braces, indentation, the next declaration,
or end of file. Every active semantic payload beginning with `@ownership-` is
reserved; only the exact `@ownership-begin RESP-*` and `@ownership-end RESP-*`
grammars are accepted, so unknown or malformed ownership-prefixed markers fail
closed. Ordinary comments such as `// disabled arc:@responsibility ...`,
block-commented sentinels, and sentinel-like text inside string literals are inert.
Bare contract payloads are valid only when the same explicit begin/end pair is
present; there is no start-only compatibility form.

Parse owner markers only from canonically
production-classified paths or paths explicitly selected by approved owner
authority. Framework-neutral executable content in a production path must be
covered by a responsibility range; markerless content before, between, or
after valid ranges is still unowned and blocks conformance. Module imports and
re-exports, module docstrings, future imports, directive prologues, package or
namespace declarations, preprocessor directives, attributes, and shared wiring
are owned source and must occur inside exactly one explicit range. They receive
an integration/configuration responsibility when they do not belong to a
feature owner; there is no implicit module-level exemption. Blank lines and
comment-only content outside a block remain valid. Ordinary literal,
control-flow, and body-only edits inside a bounded responsibility block inherit
that block's owner and path; an added diff hunk does not repeat metadata merely
to prove the binding.

Every changed Git path reconciles one-to-one to exactly one implementation `Change Hygiene` row using
`A/C = new`, `M/R = existing`, and `D = deleted`. Every production-classified
changed path additionally reconciles to an active responsibility or an
approved deletion. For `M/R`, compare pinned base and final contents so a
removed responsibility block enters the deletion flow even when its file
survives. Every `D` path, whether or not it contains an owner, and every removed
block uses exact immutable evidence
`source:<task-base SHA>:<path>; diff:<task-base SHA>..<final-tree SHA>:<path>`;
the deleted path is not required in final-tree. Omitted paths, markerless
production changes, duplicate/surplus rows, stale or foreign evidence, and
unapproved removals block. A rename preserves both old and new path authority,
is production-classified when either side is production, and uses exact
`source:<task-base SHA>:<old path>; diff:<task-base SHA>..<final-tree SHA>:<old path>-><new path>`
in Change Hygiene; responsibility diff evidence uses the same explicit
`<old path>-><new path>` mapping while base-source evidence resolves the old path.
A copy is classified only by its destination: a production source copied to an
excluded destination does not transfer production ownership to that new path.
Unlike rename, copy does not remove or move the source authority.

Each implementation hygiene row names one canonical edited region: an ordinal
identifier or an exact comma-and-space-separated identifier list, never a
placeholder, wildcard, whole-file, or repository-wide claim. `Formatter
Command` is exact `none` or a safe command scoped to that row's canonical path;
repository-wide operands such as `.`, `*`, or `--all` are invalid. `Unrelated
Diff` is exact `none` or `confirmed:MAJOR-*`. Independent review reconciles each
implementation row one-to-one using exact
`<canonical path>#<edited region>` Scope Evidence, formatter evidence,
disposition, severity, and pinned SHAs. Every confirmed unrelated diff maps to
exactly one `Major` finding and makes Change Hygiene `BLOCKED`; surplus,
missing, duplicate, or contradictory review/finding rows block review.

## Review Verdicts

```text
Verdict = PASS | BLOCKED
```

Structural responsibility remains `PASS` or `BLOCKED` independently of runtime
waivers. A runtime waiver changes neither responsibility ownership nor the
structural verdict.

## Downstream Handoff

Discovery, design, plan, implementation, review, and handoff artifacts carry
the same owned capability IDs, trace IDs, atomic boundary IDs, authority, and
verification references forward without collapsing capability into trace.

## Compatibility and Rollout

Compatibility-only and legacy-debt classification retain their explicit
authority and evidence. Rollout decisions cannot downgrade required structural
responsibility checks.

## Stable Diagnostics

Validators return stable diagnostics for domain-invalid inputs and only throw
for I/O or programming errors. Stable diagnostics identify the stage and the
missing contract-version requirement.

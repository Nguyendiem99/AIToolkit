# Task 2 Report — Discovery exemplar classification authority

## Status

DONE

## Commit

`19225b064763a27f834411e3b6f843b6678a9b0a` — `feat: classify migration exemplars by authority`

## Files

- Updated discovery instructions and template with the v1 responsibility-contract front matter and the thirteen-column exemplar row shape.
- Implemented `Test-ResponsibilityDiscovery` classification authority/evidence, incremental cardinality, duplicate-row, and artifact-version checks.
- Routed target conformance through that helper using the discovery text under validation, without duplicating classification enums there.
- Added scenario coverage for agent-opinion rejection, accepted project-pack classification, insufficient preferred/no-equivalent evidence, duplicate classification rows, missing version, and target integration.

## RED evidence

Before the implementation, the responsibility scenario failed because agent opinion produced no diagnostic:

```text
agent cannot self-declare legacy debt expected exemplar-classification-authority-missing but got:
```

The target scenario also failed after its fixture adopted the thirteen-column row shape because target conformance still expected the old seven-column discovery table.

## GREEN evidence

All required focused gates exit 0:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\responsibility-conformance.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\scenarios\target-conformance.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Skills
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aitoolkit\tests\validate-migration-framework.ps1 -Check Templates
```

Relevant confirmations include `PASS: agent cannot self-declare legacy debt`, `PASS: project pack may classify compatibility-only`, `PASS: target conformance rejects discovery agent-opinion classification`, and `PASS: target conformance rejects discovery missing responsibility version`.

## Self-review

- Classification values are derived from the canonical responsibility contract; target conformance delegates discovery classification validation to the helper instead of copying those enums.
- The target helper import is scoped to avoid leaking `Set-StrictMode` into existing target validation logic.
- Only the six Task 2 paths are modified; no `issue/` path is staged.
- `git diff --check` is clean.

## Concerns

None for the required focused gates.

## Fix Round 1 (review findings)

Amended the Task 2 commit to `da96e92e46edb7fbe01e4c61ede40c918c655d21`; it remains the only commit on top of base `1e9c3a3f031079eeb1fdb4c3d2483cf5750f5ac6`.

- Bound each compatibility-only and legacy-debt authority to its own immutable evidence grammar, with every cross-pair rejected.
- Required preferred evidence to contain two distinct canonical file/line-or-section references, and rejected weak prose, duplicate references, and authoritative-conflict entries.
- Parsed only the bounded `responsibility_contract` child block; it rejects unknown, duplicate, unsupported, and wrong-scoped version children.
- Required a real discovery artifact/table, a non-placeholder primary responsibility, canonical `CAP-*` capability list, and `VERIFY-OWNER-*`; target conformance enforces the same row fields while delegating classification checks to the discovery helper.
- Updated the template with the three legacy-debt authority choices and `Inspection Status` terminology.

### Fix-round RED evidence

The new mismatch probe failed before the implementation change:

```text
project-pack authority rejects owner-decision evidence expected exemplar-classification-authority-missing but got:
```

The no-equivalent inspection-artifact case was also RED before its precise path/section branch was added:

```text
no-equivalent accepts immutable inspection path evidence should pass but got: exemplar-classification-authority-missing
```

### Fix-round GREEN evidence

All focused Task 2 gates passed after the amendment, including the new pair, duplicate/weak evidence, bounded-front-matter, empty-discovery, and responsibility-field coverage:

```text
PASS: responsibility conformance contract
PASS: target conformance scenarios
PASS: migration framework (Skills)
PASS: migration framework (Templates)
```

`git diff --check` and `git diff --cached --check` were clean before amend; only the six Task 2 owned paths were staged.

## Fix Round 2 (preferred conflict evidence)

Amended the single Task 2 commit to `dc083f7cfc9bdf08c375e443c4be3d593f1825c7`; it remains one commit above base `1e9c3a3f031079eeb1fdb4c3d2483cf5750f5ac6`.

### RED evidence

Before the fix, this immutable authoritative-conflict reference was accepted as `preferred`:

```text
preferred rejects immutable conflict decision references expected exemplar-classification-authority-missing but got:
```

### GREEN evidence

- Preferred validation now rejects canonical immutable `.md#CONFLICT-*` and `.md#DEBT-*` decision identifiers, in addition to explicit conflict-prefixed evidence.
- Regression coverage rejects both `architecture-rules.md#CONFLICT-007` and `debt-register.md#DEBT-007`.
- An ordinary `conflict_resolver.dart:10-80` source reference remains accepted, avoiding a filename-word false positive.
- `responsibility-conformance.Tests.ps1` and `target-conformance.Tests.ps1` pass; `git diff --check` and staged diff checks were clean.

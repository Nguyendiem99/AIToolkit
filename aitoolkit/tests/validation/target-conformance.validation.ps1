function Test-TargetConformance([string]$Root, [string]$ContractText) {
  $contractPath = Join-Path $Root 'contracts/target-structure-conformance.md'
  if (-not (Test-Path -LiteralPath $contractPath -PathType Leaf)) {
    $errors.Add('Missing target structure conformance contract resource')
    return
  }
  if ([string]::IsNullOrWhiteSpace($ContractText)) {
    $errors.Add('Target structure conformance contract must not be empty')
    return
  }

  Test-MarkdownTableExactColumns $ContractText 'Comparable Target Exemplars' `
    @('Concern', 'Path', 'Inspected Symbols', 'Observed Pattern', 'Comparable Reason', 'Evidence', 'Status') `
    'Target structure conformance contract'
  Test-MarkdownTableExactColumns $ContractText 'Target Structure Conformance Matrix' `
    @('Concern', 'Working Exemplar', 'Observed Target Pattern', 'Proposed Path/Symbol', 'Conforms', 'Deviation Reference') `
    'Target structure conformance contract'
  Test-MarkdownTableExactColumns $ContractText 'Assurance State' `
    @('Runtime Evidence State', 'Architecture Conformance State', 'Selector Schema State') `
    'Target structure conformance contract'

  @(
    'module/container composition',
    'main/child presentation boundaries',
    'unit/component organization',
    'controller/provider/state pattern',
    'routing and lifecycle',
    'localization',
    'service/config subscription and normalization',
    'test harness and production-boundary tests',
    'Exemplar status: `verified | no-equivalent | unknown`.',
    'A `Conforms = no` row requires a resolved conflict and Tech Lead approval in `Deviation Reference`.',
    'The structural pre-edit gate blocks before target edit and is not waiver-eligible.',
    'runtime_evidence_state: PASS | FAIL | NOT_RUN | WAIVED',
    'architecture_conformance_state: PASS | BLOCKED',
    'selector_schema_state: PASS | BLOCKED',
    'Architecture-first review order: master-scope/work-item alignment -> project rule resolution -> canonical selector -> architecture conformance with matrix/exemplars -> production activation path -> behavior, failure modes, security, performance, and tests -> change hygiene.'
  ) | ForEach-Object {
    Require-Token $ContractText $_ 'Target structure conformance contract'
  }
}

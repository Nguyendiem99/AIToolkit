function Test-StructuralGate([string]$Root, [string]$ContractText) {
  $contractPath = Join-Path $Root 'contracts/target-structure-conformance.md'
  if (-not (Test-Path -LiteralPath $contractPath -PathType Leaf)) {
    $errors.Add('Missing target structure conformance contract resource')
    return
  }
  @(
    '## Structural pre-edit gate',
    'The structural pre-edit gate blocks before target edit and is not waiver-eligible.',
    'architecture conformance and selector/schema states are both `PASS`',
    'runtime_evidence_state: PASS | FAIL | NOT_RUN | WAIVED',
    'architecture_conformance_state: PASS | BLOCKED',
    'selector_schema_state: PASS | BLOCKED'
  ) | ForEach-Object {
    Require-Token $ContractText $_ 'Structural pre-edit gate contract'
  }
}

function Test-ScopeEngine([string]$Root, [string]$ContractText) {
  $contractPath = Join-Path $Root 'contracts/migration-scope-orchestration.md'
  if (-not (Test-Path -LiteralPath $contractPath -PathType Leaf)) {
    $errors.Add('Missing migration scope orchestration contract resource')
    return
  }
  @(
    '## Deterministic selection order',
    'Selection order: dependency depth ascending -> Plan Order ascending -> ordinal Work Item ID ascending.',
    'Terminal-success states: `complete | cancelled-approved | not-applicable-approved`.',
    'Resume reconciliation applies a missing terminal transition from valid evidence before selecting another work item.',
    'Approved revisions are immutable and form one linear, non-forked, non-cyclic chain.'
  ) | ForEach-Object {
    Require-Token $ContractText $_ 'Migration scope engine contract'
  }
}

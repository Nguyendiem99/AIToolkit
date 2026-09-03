function Test-DeliveryAdapters([string]$Root, [string]$ContractText) {
  $contractPath = Join-Path $Root 'contracts/migration-scope-orchestration.md'
  if (-not (Test-Path -LiteralPath $contractPath -PathType Leaf)) {
    $errors.Add('Missing migration scope orchestration contract resource')
    return
  }
  @(
    '## Delivery adapter kinds',
    'Delivery adapter kinds: `migration-unit | task | story | package | phase | milestone | none`.',
    'external_id: UNIT-ADM-002',
    'parent_selector: not-applicable',
    '## Decomposition',
    'Decomposition creates a new master-plan revision and canonical child selectors must be approved before adapter assignment.'
  ) | ForEach-Object {
    Require-Token $ContractText $_ 'Migration delivery adapter contract'
  }
}

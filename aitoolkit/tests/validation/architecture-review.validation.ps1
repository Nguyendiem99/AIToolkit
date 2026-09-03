function Test-ArchitectureReview([string]$Root, [string]$ContractText) {
  $contractPath = Join-Path $Root 'contracts/target-structure-conformance.md'
  if (-not (Test-Path -LiteralPath $contractPath -PathType Leaf)) {
    $errors.Add('Missing target structure conformance contract resource')
    return
  }
  @(
    '## Architecture-first review order',
    'Architecture-first review order: master-scope/work-item alignment -> project rule resolution -> canonical selector -> architecture conformance with matrix/exemplars -> production activation path -> behavior, failure modes, security, performance, and tests -> change hygiene.',
    'Architecture Conformance Verdict: PASS | BLOCKED',
    'Canonical Selector Verdict: PASS | BLOCKED',
    'Production Activation-path Verdict: PASS | BLOCKED | NOT_APPLICABLE',
    'Any `BLOCKED` verdict makes the overall verdict `Reject`.'
  ) | ForEach-Object {
    Require-Token $ContractText $_ 'Architecture review contract'
  }
}

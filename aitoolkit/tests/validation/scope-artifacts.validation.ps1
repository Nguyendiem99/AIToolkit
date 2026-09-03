function Test-ScopeArtifacts([string]$Root, [string]$ContractText) {
  $contractPath = Join-Path $Root 'contracts/migration-scope-orchestration.md'
  if (-not (Test-Path -LiteralPath $contractPath -PathType Leaf)) {
    $errors.Add('Missing migration scope orchestration contract resource')
    return
  }
  if ([string]::IsNullOrWhiteSpace($ContractText)) {
    $errors.Add('Migration scope orchestration contract must not be empty')
    return
  }

  Test-MarkdownTableExactColumns $ContractText 'Requested Scope' `
    @('Kind', 'ID', 'Statement', 'Source', 'Resolution Evidence') `
    'Migration scope orchestration contract'
  Test-MarkdownTableExactColumns $ContractText 'Work Item' `
    @(
      'Work Item ID', 'Title', 'Required', 'Dependencies', 'Plan Order',
      'Acceptance', 'Trace IDs', 'Delivery Adapter', 'Status', 'Latest Attempt',
      'Terminal Evidence', 'Approval Reference'
    ) `
    'Migration scope orchestration contract'
  Test-MarkdownTableExactColumns $ContractText 'Attempt' `
    @('Attempt ID', 'Work Item ID', 'Plan Revision', 'Status', 'Artifact Reference') `
    'Migration scope orchestration contract'
  Test-MarkdownTableExactColumns $ContractText 'Revision' `
    @('Artifact ID', 'Revision', 'Supersedes', 'Change Summary', 'Affected Work Items', 'Approval Reference') `
    'Migration scope orchestration contract'

  @(
    'Requested scope kinds: `project | module | feature | task | explicit-item | unresolved`.',
    'Scope states: `planned | scope-in-progress | scope-blocked | scope-complete | scope-cancelled-approved`.',
    'Work-item states: `proposed | pending | ready | in-progress | blocked | complete | cancelled-approved | not-applicable-approved`.',
    'Delivery adapter kinds: `migration-unit | task | story | package | phase | milestone | none`.',
    'Selection order: dependency depth ascending -> Plan Order ascending -> ordinal Work Item ID ascending.',
    'Terminal-success states: `complete | cancelled-approved | not-applicable-approved`.',
    'Resume reconciliation applies a missing terminal transition from valid evidence before selecting another work item.',
    'Approved revisions are immutable and form one linear, non-forked, non-cyclic chain.',
    'Decomposition creates a new master-plan revision and canonical child selectors must be approved before adapter assignment.',
    'Scope-completion formula: every required work item is terminal-success AND no blocker remains AND the dependency graph is valid AND completed-item architecture conformance is PASS AND completed-item selector/schema is PASS AND the terminal scope report enumerates all evidence.'
  ) | ForEach-Object {
    Require-Token $ContractText $_ 'Migration scope orchestration contract'
  }
}

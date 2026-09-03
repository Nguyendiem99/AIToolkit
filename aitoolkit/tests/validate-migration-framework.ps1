param(
  [Alias('Target')]
  [ValidateSet('Encoding','Contracts','Templates','Skills','Orchestrators','Onboarding','Compatibility','Docs','All')]
  [string]$Check = 'All',
  [string]$Root = (Join-Path $PSScriptRoot '..'),
  [string]$ActivationSliceArtifactPath = '',
  [string]$PredecessorActivationSliceArtifactPath = '',
  [string]$ActivationSliceContractFixturePath = ''
)

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath($Root)
$errors = [Collections.Generic.List[string]]::new()
$script:markdownLineStateCacheText = $null
$script:markdownLineStateCacheStates = $null
$script:markdownVisibleHeadingCacheText = $null
$script:markdownVisibleHeadingCacheRecords = $null

function Require-Token([string]$Text, [string]$Token, [string]$Context) {
  if ($Text -notmatch [regex]::Escape($Token)) { $errors.Add("$Context missing: $Token") }
}

function Invoke-MigrationValidationModule(
  [string]$RelativePath,
  [string]$EntryFunction,
  [string]$RequiredRuleToken,
  [string]$ValidationRoot,
  [string]$ContractText
) {
  $modulePath = Join-Path $root $RelativePath
  $moduleName = Split-Path $modulePath -Leaf
  if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) {
    $errors.Add("Missing validation module: $RelativePath")
    return
  }

  $parseTokens = $null
  $parseErrors = $null
  $moduleAst = [Management.Automation.Language.Parser]::ParseFile(
    $modulePath,
    [ref]$parseTokens,
    [ref]$parseErrors
  )
  if (@($parseErrors).Count -gt 0) {
    $errors.Add("Validation module $moduleName has PowerShell parse errors")
    return
  }

  $functionDefinitions = @($moduleAst.FindAll({
    param($node)
    $node -is [Management.Automation.Language.FunctionDefinitionAst]
  }, $true))
  if (
    $functionDefinitions.Count -ne 1 -or
    $functionDefinitions[0].Name -cne $EntryFunction
  ) {
    $errors.Add("Validation module $moduleName must export exactly one function: $EntryFunction")
    return
  }

  $entryDefinition = $functionDefinitions[0]
  $signaturePattern = '(?s)^function\s+' + [regex]::Escape($EntryFunction) +
    '\s*\(\s*\[string\]\$Root\s*,\s*\[string\]\$ContractText\s*\)'
  if ($entryDefinition.Extent.Text -cnotmatch $signaturePattern) {
    $errors.Add("Validation module $moduleName has invalid entry signature: $EntryFunction([string]`$Root, [string]`$ContractText)")
    return
  }
  if ($entryDefinition.Body.EndBlock.Statements.Count -eq 0) {
    $errors.Add("Validation module $moduleName entry function body must not be empty")
    return
  }
  if ($entryDefinition.Body.Extent.Text -cnotmatch [regex]::Escape($RequiredRuleToken)) {
    $errors.Add("Validation module $moduleName missing contract-derived rule: $RequiredRuleToken")
    return
  }

  . $modulePath
  if (-not (Test-Path -LiteralPath "Function:$EntryFunction")) {
    $errors.Add("Validation module $moduleName entry function is not reachable: $EntryFunction")
    return
  }
  & $EntryFunction $ValidationRoot $ContractText
}

function ConvertFrom-Utf8Base64([string]$Value) {
  return [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Value))
}

function Trim-AsciiSpaceTab([string]$Value) {
  if ($null -eq $Value) { return '' }
  return $Value.Trim([char[]]@([char]0x20, [char]0x09))
}

function Test-MarkdownBlankLine([string]$Value) {
  return $Value -cmatch '^[ \t]*$'
}

function Test-ActivationSlicePlaceholderValue([string]$Value, [object]$Definition) {
  if ([string]::IsNullOrWhiteSpace($Value)) { return $true }
  $rules = @($Definition.PlaceholderRules)
  if ($rules.Count -ne 1) { return $true }
  $rule = $rules[0]
  if ((Get-ActivationSliceCellValue $rule 'Predicate') -cne 'non-empty-non-placeholder') {
    return $true
  }
  $candidate = Trim-AsciiSpaceTab $Value
  for ($iteration = 0; $iteration -lt 4; $iteration++) {
    $decoration = [regex]::Match(
      $candidate,
      '^(?:(?<marker>\*{1,3}|_{1,3}|~{2})(?<body>.+)\k<marker>|\[(?<linkbody>[^\]]+)\]\([^)]*\))$'
    )
    if (-not $decoration.Success) { break }
    $candidate = if ($decoration.Groups['body'].Success) {
      Trim-AsciiSpaceTab $decoration.Groups['body'].Value
    }
    else {
      Trim-AsciiSpaceTab $decoration.Groups['linkbody'].Value
    }
  }
  $candidate = [Net.WebUtility]::HtmlDecode($candidate)
  if (
    (Get-ActivationSliceCellValue $rule 'Pattern sentinel') -ceq 'angle-bracket-placeholder' -and
    $candidate -cmatch '^<[^>]+>$'
  ) {
    return $true
  }
  $sentinels = @(
    (Get-ActivationSliceCellValue $rule 'Exact sentinels').Split(',') |
      ForEach-Object { Trim-AsciiSpaceTab $_ } |
      Where-Object { $_ -ne '' }
  )
  return $sentinels -icontains $candidate
}

function ConvertFrom-MarkdownHeadingInlineText(
  [string]$Value,
  [Collections.Generic.HashSet[string]]$ReferenceLabels
) {
  $rendered = $Value
  $protected = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
  $rendered = [regex]::Replace(
    $rendered,
    '\\(?<character>[!"#$%&''()*+,\-./:;<=>?@\[\\\]^_`{|}~])',
    {
      param($match)
      $token = [string][char](0xE000 + $protected.Count)
      $protected[$token] = $match.Groups['character'].Value
      return $token
    }
  )
  $rendered = [regex]::Replace(
    $rendered,
    '(?<ticks>`+)(?<body>.*?)\k<ticks>',
    {
      param($match)
      $body = [regex]::Replace($match.Groups['body'].Value, '[ \t\r\n]+', ' ')
      if ($body.Length -ge 2 -and $body[0] -ceq ' ' -and $body[$body.Length - 1] -ceq ' ' -and $body -cnotmatch '^ +$') {
        $body = $body.Substring(1, $body.Length - 2)
      }
      $token = [string][char](0xE000 + $protected.Count)
      $protected[$token] = $body
      return $token
    }
  )
  for ($iteration = 0; $iteration -lt 4; $iteration++) {
    $previous = $rendered
    $rendered = [regex]::Replace($rendered, '!?(?:\[(?<label>[^\]]+)\])(?:\([^)]*\)|\[[^\]]*\])', '${label}')
    $rendered = [regex]::Replace(
      $rendered,
      '!?(?:\[(?<label>[^\]]+)\])',
      {
        param($match)
        $label = [regex]::Replace($match.Groups['label'].Value, '[ \t]+', ' ')
        if ($null -ne $ReferenceLabels -and $ReferenceLabels.Contains($label)) {
          return $match.Groups['label'].Value
        }
        return $match.Value
      }
    )
    $rendered = [regex]::Replace($rendered, '</?[A-Za-z][^>]*>', '')
    $rendered = [regex]::Replace($rendered, '[*_~]', '')
    if ($rendered -ceq $previous) { break }
  }
  foreach ($token in $protected.Keys) {
    $rendered = $rendered.Replace($token, $protected[$token])
  }
  $rendered = [Net.WebUtility]::HtmlDecode($rendered)
  $rendered = [regex]::Replace($rendered, '[ \t]+', ' ')
  return Trim-AsciiSpaceTab $rendered
}

function Get-MarkdownLineStates([string]$Text) {
  if (
    $null -ne $script:markdownLineStateCacheStates -and
    $Text -ceq $script:markdownLineStateCacheText
  ) {
    return @($script:markdownLineStateCacheStates)
  }

  $states = [Collections.Generic.List[object]]::new()
  $lines = @($Text -split '\r?\n')
  $inFence = $false
  $fenceCharacter = ''
  $fenceLength = 0
  $inHtmlComment = $false
  $htmlEndPattern = ''
  $htmlUntilBlank = $false
  $paragraphOpen = $false
  $inPipeTable = $false
  $inFrontMatter = $lines.Count -gt 0 -and $lines[0] -ceq '---'
  $htmlBlockTags = @(
    'address', 'article', 'aside', 'base', 'basefont', 'blockquote', 'body',
    'caption', 'center', 'col', 'colgroup', 'dd', 'details', 'dialog', 'dir',
    'div', 'dl', 'dt', 'fieldset', 'figcaption', 'figure', 'footer', 'form',
    'frame', 'frameset', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'head',
    'header', 'hr', 'html', 'iframe', 'legend', 'li', 'link', 'main', 'menu',
    'menuitem', 'nav', 'noframes', 'ol', 'optgroup', 'option', 'p', 'param',
    'search', 'section', 'summary', 'table', 'tbody', 'td', 'tfoot', 'th',
    'thead', 'title', 'tr', 'track', 'ul'
  )
  $htmlBlockTagPattern = $htmlBlockTags -join '|'

  for ($index = 0; $index -lt $lines.Count; $index++) {
    $line = $lines[$index]
    $isPipeTableLine = $false
    if ($line -match '^[ ]{0,3}\|.*\|[ \t]*$') {
      if ($inPipeTable) {
        $isPipeTableLine = $true
      }
      elseif ($index + 1 -lt $lines.Count) {
        $headerCells = @(Split-MarkdownTableLine $line)
        $delimiterCells = @(Split-MarkdownTableLine $lines[$index + 1])
        $validDelimiterCells = @($delimiterCells | Where-Object { $_ -cmatch '^:?-{3,}:?$' })
        $isPipeTableLine = (
          $headerCells.Count -gt 0 -and
          $delimiterCells.Count -eq $headerCells.Count -and
          $validDelimiterCells.Count -eq $delimiterCells.Count
        )
      }
    }
    $excluded = $false
    $exclusionKind = ''
    $fenceEvent = ''
    $stateFenceCharacter = ''
    $stateFenceLength = 0
    $fenceInfo = ''
    $paragraphOpenBefore = $paragraphOpen
    if ($inFrontMatter) {
      $excluded = $true
      $exclusionKind = 'frontmatter'
      if ($index -gt 0 -and $line -ceq '---') {
        $inFrontMatter = $false
      }
    }
    elseif ($inFence) {
      $excluded = $true
      $exclusionKind = 'fence'
      $closingMatch = [regex]::Match($line, '^[ ]{0,3}(?<fence>`{3,}|~{3,})[ \t]*$')
      if ($closingMatch.Success) {
        $marker = $closingMatch.Groups['fence'].Value
        if ($marker.Substring(0, 1) -ceq $fenceCharacter -and $marker.Length -ge $fenceLength) {
          $fenceEvent = 'close'
          $stateFenceCharacter = $fenceCharacter
          $stateFenceLength = $fenceLength
          $inFence = $false
          $fenceCharacter = ''
          $fenceLength = 0
        }
      }
      if ([string]::IsNullOrWhiteSpace($fenceEvent)) { $fenceEvent = 'content' }
    }
    elseif ($inHtmlComment) {
      $excluded = $true
      $exclusionKind = 'html'
      if ($line.IndexOf('-->', [StringComparison]::Ordinal) -ge 0) { $inHtmlComment = $false }
    }
    elseif (-not [string]::IsNullOrWhiteSpace($htmlEndPattern)) {
      $excluded = $true
      $exclusionKind = 'html'
      if ($line -match $htmlEndPattern) { $htmlEndPattern = '' }
    }
    elseif ($htmlUntilBlank) {
      if (Test-MarkdownBlankLine $line) {
        $htmlUntilBlank = $false
      }
      else {
        $excluded = $true
        $exclusionKind = 'html'
      }
    }
    elseif ($line -cmatch '^(?: {4,}|\t)') {
      if (-not $paragraphOpen) {
        $excluded = $true
        $exclusionKind = 'indented'
      }
    }
    else {
      $openingMatch = [regex]::Match($line, '^[ ]{0,3}(?<fence>`{3,}|~{3,})(?<info>.*)$')
      $validFenceOpening = $openingMatch.Success
      if ($validFenceOpening) {
        $marker = $openingMatch.Groups['fence'].Value
        $info = $openingMatch.Groups['info'].Value
        if ($marker.Substring(0, 1) -ceq '`' -and $info.IndexOf('`', [StringComparison]::Ordinal) -ge 0) {
          $validFenceOpening = $false
        }
      }
      if ($validFenceOpening) {
        $inFence = $true
        $fenceCharacter = $marker.Substring(0, 1)
        $fenceLength = $marker.Length
        $excluded = $true
        $exclusionKind = 'fence'
        $fenceEvent = 'open'
        $stateFenceCharacter = $fenceCharacter
        $stateFenceLength = $fenceLength
        $fenceInfo = Trim-AsciiSpaceTab $info
      }
      elseif ($line -cmatch '^[ ]{0,3}<!--') {
        $excluded = $true
        $exclusionKind = 'html'
        if ($line.IndexOf('-->', [StringComparison]::Ordinal) -lt 0) {
          $inHtmlComment = $true
        }
      }
      elseif ($line -match '^[ ]{0,3}<(?<tag>script|pre|style|textarea)(?:[ \t>]|$)') {
        $excluded = $true
        $exclusionKind = 'html'
        $tag = $Matches['tag'].ToLowerInvariant()
        $closingPattern = "</$([regex]::Escape($tag))[ \t]*>"
        if ($line -notmatch $closingPattern) { $htmlEndPattern = $closingPattern }
      }
      elseif ($line -cmatch '^[ ]{0,3}<\?') {
        $excluded = $true
        $exclusionKind = 'html'
        if ($line -cnotmatch '\?>') { $htmlEndPattern = '\?>' }
      }
      elseif ($line -cmatch '^[ ]{0,3}<!\[CDATA\[') {
        $excluded = $true
        $exclusionKind = 'html'
        if ($line -cnotmatch '\]\]>') { $htmlEndPattern = '\]\]>' }
      }
      elseif ($line -cmatch '^[ ]{0,3}<![A-Z]') {
        $excluded = $true
        $exclusionKind = 'html'
        if ($line -cnotmatch '>') { $htmlEndPattern = '>' }
      }
      elseif ($line -match "^[ ]{0,3}</?(?<blocktag>$htmlBlockTagPattern)(?:[ \t]|/?>|$)") {
        $excluded = $true
        $exclusionKind = 'html'
        $htmlUntilBlank = $true
      }
      elseif (
        -not $paragraphOpen -and
        (
          $line -match '^[ ]{0,3}</[A-Za-z][A-Za-z0-9-]*[ \t]*>[ \t]*$' -or
          $line -match '^[ ]{0,3}<[A-Za-z][A-Za-z0-9-]*(?:[ \t]+[A-Za-z_:][A-Za-z0-9_.:-]*(?:[ \t]*=[ \t]*(?:[^ \t"''=<>`]+|''[^'']*''|"[^"]*"))?)*[ \t]*/?>[ \t]*$'
        )
      ) {
        $excluded = $true
        $exclusionKind = 'html'
        $htmlUntilBlank = $true
      }
    }

    $states.Add([pscustomobject]@{
      Index = $index
      Text = $line
      Excluded = $excluded
      ExclusionKind = $exclusionKind
      FenceEvent = $fenceEvent
      FenceCharacter = $stateFenceCharacter
      FenceLength = $stateFenceLength
      FenceInfo = $fenceInfo
      ParagraphOpenBefore = $paragraphOpenBefore
    })
    if (Test-MarkdownBlankLine $line) {
      $paragraphOpen = $false
    }
    elseif ($excluded) {
      $paragraphOpen = $false
    }
    elseif (
      $line -match '^[ ]{0,3}#{1,6}(?:[ \t]+|[ \t]*$)' -or
      $line -match '^[ ]{0,3}(?:(?:\*[ \t]*){3,}|(?:_[ \t]*){3,}|(?:-[ \t]*){3,})$' -or
      $line -match '^[ ]{0,3}(?:>|(?:[*+-]|[0-9]{1,9}[.)])[ \t]+)' -or
      $line -match '^[ ]{0,3}\[[^\]]+\]:' -or
      $isPipeTableLine
    ) {
      $paragraphOpen = $false
    }
    else {
      $paragraphOpen = $true
    }
    $inPipeTable = $isPipeTableLine
  }
  $script:markdownLineStateCacheText = $Text
  $script:markdownLineStateCacheStates = @($states)
  return @($script:markdownLineStateCacheStates)
}

function Get-MarkdownFencedCodeBlocks([string]$Text) {
  $blocks = [Collections.Generic.List[object]]::new()
  $current = $null
  foreach ($state in @(Get-MarkdownLineStates $Text)) {
    if ($state.FenceEvent -ceq 'open') {
      $current = [pscustomobject]@{
        Character = $state.FenceCharacter
        Length = $state.FenceLength
        Info = $state.FenceInfo
        Lines = [Collections.Generic.List[string]]::new()
      }
    }
    elseif ($state.FenceEvent -ceq 'close' -and $null -ne $current) {
      $blocks.Add([pscustomobject]@{
        Character = $current.Character
        Length = $current.Length
        Info = $current.Info
        Body = @($current.Lines) -join [Environment]::NewLine
      })
      $current = $null
    }
    elseif ($state.FenceEvent -ceq 'content' -and $null -ne $current) {
      $current.Lines.Add($state.Text)
    }
  }
  return @($blocks)
}

function Get-MarkdownVisibleHeadingRecords([string]$Text) {
  if (
    $null -ne $script:markdownVisibleHeadingCacheRecords -and
    $Text -ceq $script:markdownVisibleHeadingCacheText
  ) {
    return @($script:markdownVisibleHeadingCacheRecords)
  }

  $states = @(Get-MarkdownLineStates $Text)
  $headings = [Collections.Generic.List[object]]::new()
  $referenceLabels = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  foreach ($referenceState in $states) {
    if ($referenceState.Excluded) { continue }
    $referenceDefinition = [regex]::Match(
      $referenceState.Text,
      '^[ ]{0,3}\[(?<label>[^\]]+)\]:[ \t]*(?:\S.*)?$'
    )
    if ($referenceDefinition.Success) {
      $label = [regex]::Replace($referenceDefinition.Groups['label'].Value, '[ \t]+', ' ')
      [void]$referenceLabels.Add($label)
    }
  }
  for ($index = 0; $index -lt $states.Count; $index++) {
    $state = $states[$index]
    if ($state.Excluded) { continue }
    $atx = [regex]::Match(
      $state.Text,
      '^[ ]{0,3}(?<marker>#{1,6})(?:[ \t]+(?<name>.*)|[ \t]*)$',
      [Text.RegularExpressions.RegexOptions]::CultureInvariant
    )
    if ($atx.Success) {
      $name = Trim-AsciiSpaceTab $atx.Groups['name'].Value
      $name = [regex]::Replace($name, '[ \t]+#+[ \t]*$', '')
      $name = ConvertFrom-MarkdownHeadingInlineText $name $referenceLabels
      $headings.Add([pscustomobject]@{
        Index = $state.Index
        EndIndex = $state.Index
        Level = $atx.Groups['marker'].Value.Length
        Name = $name
      })
      continue
    }
    if ($index -eq 0) { continue }
    $setext = [regex]::Match(
      $state.Text,
      '^[ ]{0,3}(?<marker>=+|-+)[ \t]*$',
      [Text.RegularExpressions.RegexOptions]::CultureInvariant
    )
    $previous = $states[$index - 1]
    if (
      $setext.Success -and
      $state.ParagraphOpenBefore -and
      -not $previous.Excluded -and
      -not (Test-MarkdownBlankLine $previous.Text)
    ) {
      $paragraphStart = $index - 1
      while (
        $paragraphStart -gt 0 -and
        $states[$paragraphStart].ParagraphOpenBefore
      ) {
        $paragraphStart--
      }
      $paragraphName = @(
        $states[$paragraphStart..($index - 1)] |
          ForEach-Object { Trim-AsciiSpaceTab $_.Text }
      ) -join ' '
      $headings.Add([pscustomobject]@{
        Index = $states[$paragraphStart].Index
        EndIndex = $state.Index
        Level = if ($setext.Groups['marker'].Value[0] -ceq '=') { 1 } else { 2 }
        Name = ConvertFrom-MarkdownHeadingInlineText $paragraphName $referenceLabels
      })
    }
  }
  $script:markdownVisibleHeadingCacheText = $Text
  $script:markdownVisibleHeadingCacheRecords = @($headings)
  return @($script:markdownVisibleHeadingCacheRecords)
}

function Get-MarkdownSectionHeadings([string]$Text, [string]$SectionName) {
  return @(
    Get-MarkdownVisibleHeadingRecords $Text |
      Where-Object { $_.Level -eq 2 -and $_.Name -ceq $SectionName }
  )
}

function Get-MarkdownSectionBody([string]$Text, [string]$SectionName, [string]$Context) {
  $states = @(Get-MarkdownLineStates $Text)
  $headings = @(Get-MarkdownSectionHeadings $Text $SectionName)
  if ($headings.Count -eq 0) {
    $errors.Add("$Context missing section: $SectionName")
    return ''
  }
  if ($headings.Count -ne 1) {
    $errors.Add("$Context section must appear exactly once: $SectionName; found $($headings.Count)")
    return ''
  }

  $start = $headings[0].EndIndex + 1
  $end = $states.Count
  $terminatingHeadings = @(
    Get-MarkdownVisibleHeadingRecords $Text |
      Where-Object { $_.Index -ge $start -and $_.Level -le 2 } |
      Sort-Object Index
  )
  if ($terminatingHeadings.Count -gt 0) {
    $end = $terminatingHeadings[0].Index
  }
  if ($start -ge $end) { return '' }
  return (($states[$start..($end - 1)] | ForEach-Object { $_.Text }) -join [Environment]::NewLine)
}

function Require-TokenOrder(
  [string]$Text,
  [string]$First,
  [string]$Second,
  [string]$Context
) {
  $firstIndex = $Text.IndexOf($First, [StringComparison]::OrdinalIgnoreCase)
  $secondIndex = $Text.IndexOf($Second, [StringComparison]::OrdinalIgnoreCase)
  if ($firstIndex -lt 0 -or $secondIndex -lt 0 -or $firstIndex -ge $secondIndex) {
    $errors.Add("$Context requires order: $First before $Second")
  }
}

function Resolve-MigrationProfileSettings(
  [string]$Text,
  [string]$Context,
  [bool]$RequireGeneratedDefaults = $false
) {
  $resolved = [ordered]@{
    automation_mode = 'interactive'
    artifact_language = 'vi'
  }
  $contracts = @(
    [pscustomobject]@{
      Section = 'automation'; Field = 'mode'; Allowed = @('interactive', 'auto', 'auto-waive')
      Default = 'interactive'; ResultField = 'automation_mode'
    }
    [pscustomobject]@{
      Section = 'output'; Field = 'artifact_language'; Allowed = @('vi')
      Default = 'vi'; ResultField = 'artifact_language'
    }
  )

  foreach ($contract in $contracts) {
    $sectionPattern = "(?ms)^$([regex]::Escape($contract.Section)):\s*\r?\n(?<body>.*?)(?=^[A-Za-z_][A-Za-z0-9_-]*:\s*(?:\S.*)?$|\z)"
    $sectionMatch = [regex]::Match($Text, $sectionPattern)
    if (-not $sectionMatch.Success) {
      if ($RequireGeneratedDefaults) {
        $errors.Add("$Context must declare generated default $($contract.Section).$($contract.Field): $($contract.Default)")
      }
      continue
    }

    $fieldMatches = [regex]::Matches(
      $sectionMatch.Groups['body'].Value,
      "(?m)^  $([regex]::Escape($contract.Field)):\s*(?<value>\S.*?)\s*$"
    )
    if ($fieldMatches.Count -ne 1) {
      $errors.Add("$Context must declare exactly one $($contract.Section).$($contract.Field)")
      continue
    }

    $value = $fieldMatches[0].Groups['value'].Value
    if ($value -notin $contract.Allowed) {
      $errors.Add("$Context invalid $($contract.Section).$($contract.Field): $value")
      continue
    }
    if ($RequireGeneratedDefaults -and $value -cne $contract.Default) {
      $errors.Add("$Context generated default $($contract.Section).$($contract.Field) must be $($contract.Default)")
      continue
    }
    $resolved[$contract.ResultField] = $value
  }

  return [pscustomobject]$resolved
}

function Test-AutomationArtifactContract([string]$SchemaText) {
  $context = 'Migration automation artifact schema'
  Require-Token $SchemaText 'approval_source: human | auto | auto-waive' $context
  $contractMatch = [regex]::Match(
    $SchemaText,
    '(?ms)^An artifact with an automation waiver uses exactly this YAML shape:\s*\r?\n\s*```yaml\s*\r?\n(?<body>.*?)^```\s*$'
  )
  if (-not $contractMatch.Success) {
    $errors.Add("$context missing canonical waiver example")
    return
  }

  $body = $contractMatch.Groups['body'].Value
  $statusMatches = [regex]::Matches($body, '(?m)^status:\s*(?<value>\S.*?)\s*$')
  $resultMatches = [regex]::Matches($body, '(?m)^result:\s*(?<value>\S.*?)\s*$')
  $approvalMatches = [regex]::Matches($body, '(?m)^approval_source:\s*(?<value>\S.*?)\s*$')
  if ($statusMatches.Count -ne 1 -or $statusMatches[0].Groups['value'].Value -cne 'approved') {
    $errors.Add("$context waiver requires exactly one status: approved")
  }
  if ($resultMatches.Count -ne 1 -or $resultMatches[0].Groups['value'].Value -cne 'partial') {
    $errors.Add("$context waiver requires result: partial")
  }
  if ($approvalMatches.Count -ne 1 -or $approvalMatches[0].Groups['value'].Value -notin @('human', 'auto', 'auto-waive')) {
    $invalidApproval = if ($approvalMatches.Count -eq 1) { $approvalMatches[0].Groups['value'].Value } else { '<missing-or-duplicate>' }
    $errors.Add("$context invalid approval_source: $invalidApproval")
  }
  elseif ($approvalMatches[0].Groups['value'].Value -cne 'auto-waive') {
    $errors.Add("$context waiver requires approval_source: auto-waive")
  }

  $waiverMatch = [regex]::Match(
    $body,
    '(?ms)^waiver:\s*\r?\n(?<fields>(?:^  [A-Za-z_][A-Za-z0-9_-]*:\s*[^\r\n]+(?:\r?\n|\z))+)'
  )
  $expectedKeys = @('policy', 'category', 'original_verdict', 'effective_action', 'evidence')
  $actualKeys = if ($waiverMatch.Success) {
    @(
      [regex]::Matches($waiverMatch.Groups['fields'].Value, '(?m)^  (?<key>[A-Za-z_][A-Za-z0-9_-]*):') |
        ForEach-Object { $_.Groups['key'].Value }
    )
  }
  else {
    @()
  }
  if ((($actualKeys | Sort-Object) -join '|') -cne (($expectedKeys | Sort-Object) -join '|')) {
    $errors.Add("$context waiver fields must be exactly: $($expectedKeys -join ', ')")
  }

  $expectedValues = [ordered]@{
    policy = 'auto-waive'
    category = 'environment-unavailable'
    original_verdict = 'blocked'
    effective_action = 'continue'
  }
  foreach ($field in $expectedValues.Keys) {
    $matches = [regex]::Matches(
      $waiverMatch.Groups['fields'].Value,
      "(?m)^  $([regex]::Escape($field)):\s*(?<value>\S.*?)\s*$"
    )
    if ($matches.Count -ne 1 -or $matches[0].Groups['value'].Value -cne $expectedValues[$field]) {
      $errors.Add("$context waiver.$field must be $($expectedValues[$field])")
    }
  }
  $evidenceMatches = [regex]::Matches($waiverMatch.Groups['fields'].Value, '(?m)^  evidence:\s*(?<value>\S.*?)\s*$')
  if ($evidenceMatches.Count -ne 1 -or $evidenceMatches[0].Groups['value'].Value -in @('', 'null', '<none>')) {
    $errors.Add("$context waiver.evidence must be non-empty")
  }
}

function Test-ActivationSliceRuleTable(
  [string]$Text,
  [string]$SectionName,
  [string[]]$Columns,
  [object[]]$ExpectedRows,
  [string]$Context,
  [string]$RuleLabel = ''
) {
  $rows = @(Get-ActivationSliceContractTableRules $SectionName $Text)
  $separator = ([char]0x001F).ToString()
  $actualRows = @($rows | ForEach-Object {
    $row = $_
    (@($Columns | ForEach-Object { Get-ActivationSliceCellValue $row $_ }) -join $separator)
  })
  $expectedValues = @($ExpectedRows | ForEach-Object { @($_) -join $separator })
  if (($actualRows -join "`n") -cne ($expectedValues -join "`n")) {
    $label = if ([string]::IsNullOrWhiteSpace($RuleLabel)) { $SectionName } else { $RuleLabel }
    $errors.Add("$Context $label rules must match the canonical definition")
  }
}

function Test-ActivationSliceContract([string]$Text) {
  $context = 'Activation Slice contract'
  if ($Text -notmatch '\A# Activation Slice Contract\s*(?:\r?\n|\z)') {
    $errors.Add("$context missing heading: Activation Slice Contract")
  }

  $requiredSections = @(
    'Applicability',
    'Canonical seams',
    'Artifact row schema',
    'Identifier formats',
    'Field requirements',
    'Legal row combinations',
    'Completion and blocking rules',
    'Domain-blocker evidence',
    'Placeholder value semantics',
    'Step 10 baseline-waiver resume',
    'Step 10 resume evidence',
    'Step 10 resume state',
    'Step 10 native blocker eligibility',
    'Immediate predecessor roles and lifecycle',
    'Bootstrap selected-unit handoff',
    'Step 10 predecessor unit selection',
    'Direct-plan foundation state',
    'Downstream selected-unit handoff',
    'Regression parity handoff',
    'Assurance task provenance handoff',
    'Assurance verdict consistency',
    'Router ownership',
    'Router evidence schema',
    'Async lifecycle',
    'Async evidence schema',
    'Handoff invariants',
    'Source Reference enrichment',
    'Implementation linkage',
    'Quick reference',
    'Common mistakes'
  )
  $sectionBodies = @{}
  foreach ($section in $requiredSections) {
    $sectionBodies[$section] = Get-MarkdownSectionBody $Text $section $context
  }

  $approvalSources = @(Get-ActivationSliceContractEnumValues 'Approval source' $Text)
  if (($approvalSources -join '|') -cne 'human|auto|auto-waive') {
    $errors.Add("$context Approval source values must be exactly: human, auto, auto-waive")
  }

  $activationSliceSchemaColumns = @(
    'Activation Slice ID', 'Applicability', 'Seam', 'Input', 'Output',
    'Source Reference', 'Trace IDs', 'Disposition', 'Status',
    'Decision Reference', 'Deferred Unit ID'
  )
  $actualSchemaColumns = @(Get-ActivationSliceContractColumns $Text)
  $columnSeparator = ([char]0x001F).ToString()
  if (($actualSchemaColumns -join $columnSeparator) -cne ($activationSliceSchemaColumns -join $columnSeparator)) {
    $errors.Add("$context artifact row schema must be exactly: $($activationSliceSchemaColumns -join ' | ')")
  }

  $expectedSeams = @(
    'upstream-response',
    'requested-key',
    'parse-model',
    'state-holder',
    'selector',
    'construct',
    'render',
    'downstream-consumer',
    'test'
  )
  $seamMatches = [regex]::Matches($sectionBodies['Canonical seams'], '(?m)^(?<index>\d+)\.\s+`(?<seam>[^`]+)`\s*$')
  $actualSeams = @($seamMatches | ForEach-Object { $_.Groups['seam'].Value })
  $actualIndexes = @($seamMatches | ForEach-Object { [int]$_.Groups['index'].Value })
  $expectedIndexes = 1..$expectedSeams.Count
  if (
    $actualSeams.Count -ne $expectedSeams.Count -or
    ($actualSeams -join '|') -cne ($expectedSeams -join '|') -or
    ($actualIndexes -join '|') -cne ($expectedIndexes -join '|')
  ) {
    $errors.Add("$context canonical seams must be exactly: $($expectedSeams -join ', ')")
  }

  $canonicalRuleTables = @(
    [pscustomobject]@{
      Section = 'Identifier formats'
      Columns = @('Identifier', 'Required format')
      Rows = @(
        @('Activation Slice ID', 'ACT-[0-9]{3}'),
        @('Migration Unit ID', 'UNIT-[0-9]{3}'),
        @('Deferred Unit ID', 'UNIT-[0-9]{3}'),
        @('Parity test Trace ID', 'PARITY-[0-9]{3}')
      )
      Label = 'Identifier formats'
    }
    [pscustomobject]@{
      Section = 'Field requirements'
      Columns = @('Field', 'Required value')
      Rows = @(
        @('Input', '<non-empty>'),
        @('Output', '<non-empty>'),
        @('Source Reference', '<non-empty>'),
        @('Trace IDs', '<non-empty>')
      )
      Label = 'Field requirements'
    }
    [pscustomobject]@{
      Section = 'Legal row combinations'
      Columns = @('Applicability', 'Disposition', 'Status', 'Decision Reference', 'Deferred Unit ID')
      Rows = @(
        @('applicable', 'implement', 'verified', 'not-applicable', 'not-applicable'),
        @('applicable', 'implement', 'missing', 'not-applicable', 'not-applicable'),
        @('applicable', 'implement', 'conflict', 'not-applicable', 'not-applicable'),
        @('applicable', 'implement', 'unknown', 'not-applicable', 'not-applicable'),
        @('applicable', 'reuse', 'verified', 'not-applicable', 'not-applicable'),
        @('applicable', 'reuse', 'missing', 'not-applicable', 'not-applicable'),
        @('applicable', 'reuse', 'conflict', 'not-applicable', 'not-applicable'),
        @('applicable', 'reuse', 'unknown', 'not-applicable', 'not-applicable'),
        @('applicable', 'deferred-approved', 'verified', '<approval-reference>', 'UNIT-[0-9]{3}'),
        @('applicable', 'deferred-approved', 'missing', '<approval-reference>', 'UNIT-[0-9]{3}'),
        @('applicable', 'deferred-approved', 'conflict', '<approval-reference>', 'UNIT-[0-9]{3}'),
        @('applicable', 'deferred-approved', 'unknown', '<approval-reference>', 'UNIT-[0-9]{3}'),
        @('not-applicable-approved', 'not-applicable-approved', 'verified', '<approval-reference>', 'not-applicable'),
        @('unknown', 'implement', 'unknown', 'not-applicable', 'not-applicable'),
        @('unknown', 'reuse', 'unknown', 'not-applicable', 'not-applicable')
      )
      Label = 'Legal row combinations'
    }
    [pscustomobject]@{
      Section = 'Completion and blocking rules'
      Columns = @('Slice state', 'Status', 'Result')
      Rows = @(
        @('non-blocking', 'draft', 'complete'),
        @('non-blocking', 'approved', 'complete'),
        @('activation-blocking', 'draft', 'blocked'),
        @('domain-blocking', 'draft', 'blocked'),
        @('step-10 baseline-waiver resume', 'approved', 'partial')
      )
      Label = 'Completion and blocking rules lifecycle'
    }
    [pscustomobject]@{
      Section = 'Domain-blocker evidence'
      Columns = @('Section', 'Required columns', 'Cardinality', 'Value predicates')
      Rows = @(, @('Domain Blocker', 'Blocker, Evidence Reference', 'at-least-one', 'non-empty-non-placeholder'))
      Label = 'Domain-blocker evidence'
    }
    [pscustomobject]@{
      Section = 'Placeholder value semantics'
      Columns = @('Predicate', 'Exact sentinels', 'Pattern sentinel')
      Rows = @(, @('non-empty-non-placeholder', 'TBD, TODO, TBC, pending, unknown, N/A, null, none, unset, placeholder, not-applicable, pending-before-edit, pending-bootstrap, pending-step09-approval, pending-approval, -, ???', 'angle-bracket-placeholder'))
      Label = 'Placeholder value semantics'
    }
    [pscustomobject]@{
      Section = 'Step 10 baseline-waiver resume'
      Columns = @('Field', 'Required value')
      Rows = @(
        @('step_id', '10-code-migration'),
        @('status', 'approved'),
        @('result', 'partial'),
        @('approval_source', 'auto-waive'),
        @('waiver.policy', 'auto-waive'),
        @('waiver.category', 'environment-unavailable'),
        @('waiver.original_verdict', 'blocked'),
        @('waiver.effective_action', 'continue'),
        @('waiver.evidence', '<non-empty>')
      )
      Label = 'Step 10 baseline-waiver resume'
    }
    [pscustomobject]@{
      Section = 'Step 10 resume evidence'
      Columns = @('Record', 'Section', 'Required columns or fields', 'Cardinality', 'Preservation')
      Rows = @(
        @(
          'native-blocker',
          (ConvertFrom-Utf8Base64 'QmxvY2tlciBn4buRYw=='),
          'Stage / Check, Native Verdict, Command Role, Required Command Lifecycle, Command / Capability, Observed Error, Evidence Reference',
          'exactly-one-row',
          'ordinal-exact-predecessor'
        ),
        @(
          'approved-waiver-body',
          'Approved Baseline Waiver',
          'status, result, approval_source, waiver.policy, waiver.category, waiver.original_verdict, waiver.effective_action, waiver.evidence',
          'exactly-one-yaml-record',
          'exact-front-matter-and-ordinal-exact-predecessor'
        ),
        @(
          'resume-state',
          'Step 10 Waiver Resume State',
          'Resume Phase, Baseline Action, Implementation Status, Target Mutation Evidence, Waiver Evidence',
          'exactly-one-row',
          'canonical-resume-state'
        )
      )
      Label = 'Step 10 resume evidence'
    }
    [pscustomobject]@{
      Section = 'Step 10 resume state'
      Columns = @('Artifact role', 'Resume Phase', 'Baseline Action', 'Implementation Status', 'Target Mutation Evidence', 'Waiver Evidence')
      Rows = @(
        @('predecessor', 'resume-required', 'skip-pre-mutation-baseline-only', 'blocked', 'none', 'exact waiver.evidence'),
        @('current', 'resume-consumed', 'skip-pre-mutation-baseline-only', '<non-blocked>', '<selected Migration Unit ID and Trace ID>', 'exact waiver.evidence')
      )
      Label = 'Step 10 resume state'
    }
    [pscustomobject]@{
      Section = 'Step 10 native blocker eligibility'
      Columns = @('Field', 'Required value')
      Rows = @(
        @('Stage / Check', 'pre-mutation baseline'),
        @('Native Verdict', 'BLOCKED'),
        @('Command Role', 'availability probe'),
        @('Required Command Lifecycle', 'not-started'),
        @('Evidence Reference', 'exact waiver.evidence')
      )
      Label = 'Step 10 native blocker eligibility'
    }
    [pscustomobject]@{
      Section = 'Immediate predecessor roles and lifecycle'
      Columns = @(
        'Route', 'Current step ID', 'Current lifecycle', 'Predecessor step ID',
        'Predecessor Status', 'Predecessor Result', 'Predecessor Approval Source',
        'Predecessor Waiver', 'Selected Mode Constraint', 'Selected Bootstrap Scope'
      )
      Rows = @(
        @('discovery-origin', '02-discovery', 'draft/complete, approved/complete, draft/blocked', '01-validate-inputs', 'approved', 'complete, partial', '<canonical>', '<any>', '<not-applicable>', '<not-applicable>'),
        @('handoff', '03-analyze-requirements-uiux', 'draft/complete, approved/complete, draft/blocked', '02-discovery', 'approved', 'complete', '<canonical>', '<any>', '<not-applicable>', '<not-applicable>'),
        @('handoff', '04-build-inventory', 'draft/complete, approved/complete, draft/blocked', '03-analyze-requirements-uiux', 'approved', 'complete', '<canonical>', '<any>', '<not-applicable>', '<not-applicable>'),
        @('handoff', '05-feature-mapping', 'draft/complete, approved/complete, draft/blocked', '04-build-inventory', 'approved', 'complete', '<canonical>', '<any>', '<not-applicable>', '<not-applicable>'),
        @('handoff', '06-analyze-gaps-conflicts', 'draft/complete, approved/complete, draft/blocked', '05-feature-mapping', 'approved', 'complete', '<canonical>', '<any>', '<not-applicable>', '<not-applicable>'),
        @('handoff', '07-technical-design', 'draft/complete, approved/complete, draft/blocked', '06-analyze-gaps-conflicts', 'approved', 'complete', '<canonical>', '<any>', '<not-applicable>', '<not-applicable>'),
        @('handoff', '08-plan-waves', 'draft/complete, approved/complete, draft/blocked', '07-technical-design', 'approved', 'complete', '<canonical>', '<any>', '<not-applicable>', '<not-applicable>'),
        @('bootstrap', '09-bootstrap-target', 'draft/complete, approved/complete, draft/blocked', '08-plan-waves', 'approved', 'complete', '<canonical>', '<any>', 'greenfield/design-new', 'required'),
        @('initial', '10-code-migration', 'draft/complete, approved/complete, draft/blocked', '08-plan-waves', 'approved', 'complete', '<canonical>', '<any>', '<canonical>', 'not-required'),
        @('initial', '10-code-migration', 'draft/complete, approved/complete, draft/blocked', '09-bootstrap-target', 'approved', 'complete', '<canonical>', '<any>', 'greenfield/design-new', 'required'),
        @('baseline-waiver-resume', '10-code-migration', 'approved/partial, draft/blocked', '10-code-migration', 'approved', 'partial', 'auto-waive', 'exact-baseline-waiver', 'incremental/preserve-existing', 'not-required'),
        @('post-implementation', '11-ai-review', 'draft/complete, approved/complete, draft/blocked', '10-code-migration', 'approved', 'complete', '<canonical>', '<any>', '<canonical>', '<canonical>'),
        @('post-waiver-resume', '11-ai-review', 'draft/complete, approved/complete, draft/blocked', '10-code-migration', 'approved', 'partial', 'auto-waive', 'exact-baseline-waiver', 'incremental/preserve-existing', 'not-required'),
        @('handoff', '12-verification-testing', 'draft/complete, approved/complete, draft/blocked', '11-ai-review', 'approved', 'complete', '<canonical>', '<any>', '<canonical>', '<canonical>'),
        @('handoff', '13-verify-parity', 'draft/complete, approved/complete, draft/blocked', '12-verification-testing', 'approved', 'complete', '<canonical>', '<any>', '<canonical>', '<canonical>'),
        @('handoff', '14-verify-regression', 'draft/complete, approved/complete, draft/blocked', '13-verify-parity', 'approved', 'complete', '<canonical>', '<any>', 'incremental/preserve-existing', 'not-required')
      )
      Label = 'Immediate predecessor roles and lifecycle'
    }
    [pscustomobject]@{
      Section = 'Bootstrap selected-unit handoff'
      Columns = @(
        'Current lifecycle', 'Current step ID', 'Predecessor step ID', 'Current Unit Section',
        'Predecessor Unit Section', 'Exact mapped fields', 'Predecessor predicates',
        'Current predicates', 'Foundation Section', 'Foundation required columns',
        'Foundation predicates'
      )
      Rows = @(
        @(
          'draft/blocked', '09-bootstrap-target', '08-plan-waves', 'Selected Migration Unit',
          (ConvertFrom-Utf8Base64 'Q8OhYyDEkcahbiB24buLIG1pZ3JhdGlvbiB0aGVvIHRo4bupIHThu7E='),
          'Migration Unit ID, Approval Reference, Mode Constraint, Bootstrap Scope, Trace IDs',
          'Approval Status=approved; Foundation Baseline ID=pending-bootstrap; Foundation Approval Reference=pending-step09-approval',
          'Mode Constraint=greenfield/design-new; Bootstrap Scope=required; Foundation Baseline ID=pending-bootstrap; Foundation Baseline Reference=not-applicable; Foundation Baseline Approval Reference=pending-step09-approval; Baseline Reference=not-applicable',
          '<absent>', '<not-applicable>', '<absent>'
        ),
        @(
          'draft/complete', '09-bootstrap-target', '08-plan-waves', 'Selected Migration Unit',
          (ConvertFrom-Utf8Base64 'Q8OhYyDEkcahbiB24buLIG1pZ3JhdGlvbiB0aGVvIHRo4bupIHThu7E='),
          'Migration Unit ID, Approval Reference, Mode Constraint, Bootstrap Scope, Trace IDs',
          'Approval Status=approved; Foundation Baseline ID=pending-bootstrap; Foundation Approval Reference=pending-step09-approval',
          'Mode Constraint=greenfield/design-new; Bootstrap Scope=required; Foundation Baseline ID=FOUNDATION-*; Foundation Baseline Reference=<non-sentinel>; Foundation Baseline Approval Reference=pending-step09-approval; Baseline Reference=not-applicable',
          (ConvertFrom-Utf8Base64 'QuG6o24gZ2hpIGJhc2VsaW5lIG7hu4FuIHThuqNuZw=='),
          'Foundation Baseline ID, Source Migration Unit ID, Target Baseline Reference, Approval Reference, Approval Status, Evidence',
          'Approval Reference=pending-step09-approval; Approval Status=pending-approval; selected-unit-correlated'
        ),
        @(
          'approved/complete', '09-bootstrap-target', '08-plan-waves', 'Selected Migration Unit',
          (ConvertFrom-Utf8Base64 'Q8OhYyDEkcahbiB24buLIG1pZ3JhdGlvbiB0aGVvIHRo4bupIHThu7E='),
          'Migration Unit ID, Approval Reference, Mode Constraint, Bootstrap Scope, Trace IDs',
          'Approval Status=approved; Foundation Baseline ID=pending-bootstrap; Foundation Approval Reference=pending-step09-approval',
          'Mode Constraint=greenfield/design-new; Bootstrap Scope=required; Foundation Baseline ID=FOUNDATION-*; Foundation Baseline Reference=<non-sentinel>; Foundation Baseline Approval Reference=<approved-reference>; Baseline Reference=not-applicable',
          (ConvertFrom-Utf8Base64 'QuG6o24gZ2hpIGJhc2VsaW5lIG7hu4FuIHThuqNuZw=='),
          'Foundation Baseline ID, Source Migration Unit ID, Target Baseline Reference, Approval Reference, Approval Status, Evidence',
          'Approval Status=approved; selected-unit-correlated'
        )
      )
      Label = 'Bootstrap selected-unit handoff'
    }
    [pscustomobject]@{
      Section = 'Step 10 predecessor unit selection'
      Columns = @(
        'Invocation', 'Predecessor step ID', 'Current Unit Section',
        'Predecessor Unit Section', 'Predecessor Unit Selection',
        'Predecessor Unit Required Columns', 'Predecessor Unit Approval',
        'Required Mode Constraint', 'Required Bootstrap Scope',
        'Selected Unit Preservation', 'Foundation Record'
      )
      Rows = @(
        @(
          'initial', '08-plan-waves', 'Selected Migration Unit',
          (ConvertFrom-Utf8Base64 'Q8OhYyDEkcahbiB24buLIG1pZ3JhdGlvbiB0aGVvIHRo4bupIHThu7E='),
          'exactly-one-approved-current-match',
          'Order, Migration Unit ID, Bootstrap Scope, Foundation Baseline ID, Foundation Approval Reference, Dependencies, Acceptance, Mode Constraint, Trace IDs, Delivery Change Boundary, Approval Reference, Approval Status',
          'Approval Status=approved', '<canonical>', 'not-required',
          'mapped-plan-fields', 'mode-aware-direct-plan'
        ),
        @(
          'initial', '09-bootstrap-target', 'Selected Migration Unit',
          'Selected Migration Unit', 'exactly-one-current-match',
          'Migration Unit ID, Plan Reference, Approval Reference, Mode Constraint, Bootstrap Scope, Foundation Baseline ID, Foundation Baseline Reference, Foundation Baseline Approval Reference, Baseline Reference, Trace IDs',
          '<not-applicable>', 'greenfield/design-new', 'required',
          'ordinal-exact-predecessor', 'approved-matching'
        ),
        @(
          'baseline-waiver-resume', '10-code-migration', 'Selected Migration Unit',
          'Selected Migration Unit', 'ordinal-exact-current',
          'Migration Unit ID, Plan Reference, Approval Reference, Mode Constraint, Bootstrap Scope, Foundation Baseline ID, Foundation Baseline Reference, Foundation Baseline Approval Reference, Baseline Reference, Trace IDs',
          '<not-applicable>', 'incremental/preserve-existing', 'not-required',
          'ordinal-exact-predecessor', '<not-applicable>'
        )
      )
      Label = 'Step 10 predecessor unit selection'
    }
    [pscustomobject]@{
      Section = 'Direct-plan foundation state'
      Columns = @(
        'Mode Constraint', 'Bootstrap Scope', 'Plan Foundation Baseline ID',
        'Plan Foundation Approval Reference', 'Current Foundation Baseline ID',
        'Current Foundation Baseline Reference', 'Current Foundation Baseline Approval Reference',
        'Current Baseline Reference', 'Foundation Section', 'Foundation required columns',
        'Foundation predicates'
      )
      Rows = @(
        @(
          'incremental/preserve-existing', 'not-required', 'not-applicable', 'not-applicable',
          'not-applicable', 'not-applicable', 'not-applicable', '<resolved-pre-mutation-baseline-reference>',
          '<not-applicable>', '<not-applicable>', '<not-applicable>'
        ),
        @(
          'greenfield/design-new', 'not-required', 'FOUNDATION-*', '<approved-reference>',
          'same-plan', 'same-approved-record', 'same-plan', 'not-applicable',
          (ConvertFrom-Utf8Base64 'QmFzZWxpbmUgbuG7gW4gdOG6o25nIMSRw6MgZHV54buHdA=='),
          'Foundation Baseline ID, Target Baseline Reference, Approval Reference, Approval Status, Evidence',
          'exactly-one-approved-selected-match'
        )
      )
      Label = 'Direct-plan foundation state'
    }
    [pscustomobject]@{
      Section = 'Downstream selected-unit handoff'
      Columns = @('Current step ID', 'Section', 'Required columns', 'Preservation')
      Rows = @(
        @('11-ai-review', 'Selected Migration Unit', 'Migration Unit ID, Plan Reference, Approval Reference, Mode Constraint, Bootstrap Scope, Foundation Baseline ID, Foundation Baseline Reference, Foundation Baseline Approval Reference, Baseline Reference, Trace IDs', 'ordinal-exact-predecessor'),
        @('12-verification-testing', 'Selected Migration Unit', 'Migration Unit ID, Plan Reference, Approval Reference, Mode Constraint, Bootstrap Scope, Foundation Baseline ID, Foundation Baseline Reference, Foundation Baseline Approval Reference, Baseline Reference, Trace IDs', 'ordinal-exact-predecessor'),
        @('13-verify-parity', 'Selected Migration Unit', 'Migration Unit ID, Plan Reference, Approval Reference, Mode Constraint, Bootstrap Scope, Foundation Baseline ID, Foundation Baseline Reference, Foundation Baseline Approval Reference, Baseline Reference, Trace IDs', 'ordinal-exact-predecessor'),
        @('14-verify-regression', 'Selected Migration Unit', 'Migration Unit ID, Plan Reference, Approval Reference, Mode Constraint, Bootstrap Scope, Foundation Baseline ID, Foundation Baseline Reference, Foundation Baseline Approval Reference, Baseline Reference, Trace IDs', 'ordinal-exact-predecessor')
      )
      Label = 'Downstream selected-unit handoff'
    }
    [pscustomobject]@{
      Section = 'Regression parity handoff'
      Columns = @(
        'Current step ID', 'Predecessor step ID', 'Predecessor section',
        'Predecessor required columns', 'Parity Verdict Values',
        'Regression Predecessor Parity Values', 'Current section',
        'Current required columns', 'Regression Applicability',
        'Regression Verdict Values', 'Required Mode Constraint',
        'Required Bootstrap Scope', 'Evidence preservation'
      )
      Rows = @(,
        @(
          '14-verify-regression', '13-verify-parity', 'Parity Verdict',
          'Parity Verdict, Evidence Reference', 'pass, fail, blocked', 'pass, fail',
          (ConvertFrom-Utf8Base64 'S+G6v3QgbHXhuq1uIHjDoWMgbWluaCBtaWdyYXRpb24='),
          'Parity Verdict, Regression Applicability, Regression Verdict, Evidence Reference',
          'required', 'pass, fail, blocked', 'incremental/preserve-existing', 'not-required',
          'exact or <predecessor>; <non-whitespace evidence>'
        )
      )
      Label = 'Regression parity handoff'
    }
    [pscustomobject]@{
      Section = 'Assurance verdict consistency'
      Columns = @(
        'Step ID', 'Overall section', 'Overall verdict field', 'Scenario section',
        'Scenario required columns', 'Verdict values', 'Aggregate'
      )
      Rows = @(
        @(
          '13-verify-parity', 'Parity Verdict', 'Parity Verdict',
          (ConvertFrom-Utf8Base64 'S+G7i2NoIGLhuqNu'),
          'Scenario, Baseline, Actual, Verdict', 'pass, fail, blocked',
          'blocked-any; else-fail-any; else-pass'
        ),
        @(
          '14-verify-regression',
          (ConvertFrom-Utf8Base64 'S+G6v3QgbHXhuq1uIHjDoWMgbWluaCBtaWdyYXRpb24='),
          'Regression Verdict', (ConvertFrom-Utf8Base64 'S+G7i2NoIGLhuqNu'),
          'Scenario, Baseline, Actual, Delta Class, Waiver Reference, Trace IDs, Verdict', 'pass, fail, blocked',
          'blocked-any; else-fail-any; else-pass'
        )
      )
      Label = 'Assurance verdict consistency'
    }
    [pscustomobject]@{
      Section = 'Assurance task provenance handoff'
      Columns = @(
        'Current step ID', 'Predecessor step ID', 'Current section',
        'Current required columns', 'Predecessor section',
        'Predecessor required columns', 'Preserved field mapping',
        'Intrinsic predicates', 'Source Artifact rule'
      )
      Rows = @(
        @('12-verification-testing', '11-ai-review', 'Task Provenance', 'Task / Unit, Task-base SHA, Final-tree SHA, Source Artifact', 'Change Hygiene', 'Task / Unit, Scope Evidence, Formatter Evidence, Unrelated Diff, Severity, Task-base SHA, Final-tree SHA', 'Task / Unit=Task / Unit, Task-base SHA=Task-base SHA, Final-tree SHA=Final-tree SHA', 'Task / Unit=Selected Migration Unit.Migration Unit ID, Task-base SHA=non-empty-non-placeholder, Final-tree SHA=non-empty-non-placeholder', 'resolves-to-immediate-predecessor-path'),
        @('13-verify-parity', '12-verification-testing', 'Task Provenance', 'Task / Unit, Task-base SHA, Final-tree SHA, Source Artifact', 'Task Provenance', 'Task / Unit, Task-base SHA, Final-tree SHA, Source Artifact', 'Task / Unit=Task / Unit, Task-base SHA=Task-base SHA, Final-tree SHA=Final-tree SHA', 'Task / Unit=Selected Migration Unit.Migration Unit ID, Task-base SHA=non-empty-non-placeholder, Final-tree SHA=non-empty-non-placeholder', 'resolves-to-immediate-predecessor-path'),
        @('14-verify-regression', '13-verify-parity', 'Task Provenance', 'Task / Unit, Task-base SHA, Final-tree SHA, Source Artifact', 'Task Provenance', 'Task / Unit, Task-base SHA, Final-tree SHA, Source Artifact', 'Task / Unit=Task / Unit, Task-base SHA=Task-base SHA, Final-tree SHA=Final-tree SHA', 'Task / Unit=Selected Migration Unit.Migration Unit ID, Task-base SHA=non-empty-non-placeholder, Final-tree SHA=non-empty-non-placeholder', 'resolves-to-immediate-predecessor-path')
      )
      Label = 'Assurance task provenance handoff'
    }
    [pscustomobject]@{
      Section = 'Source Reference enrichment'
      Columns = @('Field', 'Allowed successor shape')
      Rows = @(,
        @('Source Reference', 'exact or <predecessor>; <non-whitespace evidence>')
      )
      Label = 'Source Reference enrichment'
    }
    [pscustomobject]@{
      Section = 'Implementation linkage'
      Columns = @('Record', 'Current step ID', 'Allowed predecessor step IDs', 'Section', 'Required columns')
      Rows = @(
        @(
          'selected-unit',
          '10-code-migration',
          '08-plan-waves, 09-bootstrap-target, 10-code-migration',
          'Selected Migration Unit',
          'Migration Unit ID, Plan Reference, Approval Reference, Mode Constraint, Bootstrap Scope, Foundation Baseline ID, Foundation Baseline Reference, Foundation Baseline Approval Reference, Baseline Reference, Trace IDs'
        ),
        @(
          'changed-file',
          '10-code-migration',
          '08-plan-waves, 09-bootstrap-target, 10-code-migration',
          (ConvertFrom-Utf8Base64 'RmlsZSDEkcOjIHRoYXkgxJHhu5Vp'),
          'Migration Unit ID, Activation Slice ID, Seam, File, Change, Trace IDs'
        ),
        @(
          'test-evidence',
          '10-code-migration',
          '08-plan-waves, 09-bootstrap-target, 10-code-migration',
          'Activation Slice Test Evidence',
          'Migration Unit ID, Activation Slice ID, Seam, Test, Command, Result, Trace IDs'
        )
      )
      Label = 'Implementation linkage'
    }
  )
  foreach ($ruleTable in $canonicalRuleTables) {
    Test-MarkdownTableExactColumns $Text $ruleTable.Section $ruleTable.Columns $context
    Test-ActivationSliceRuleTable `
      $Text `
      $ruleTable.Section `
      $ruleTable.Columns `
      $ruleTable.Rows `
      $context `
      $ruleTable.Label
  }

  Test-MarkdownTableExactColumns `
    $Text `
    'Router evidence schema' `
    @('Router Policy', 'Artifact location', 'Required key', 'Required value') `
    $context
  Test-MarkdownTableExactColumns `
    $Text `
    'Async evidence schema' `
    @('Classification', 'Artifact location', 'Required key', 'Required value') `
    $context
  Test-ActivationSliceRuleTable `
    $Text `
    'Router evidence schema' `
    @('Router Policy', 'Artifact location', 'Required key', 'Required value') `
    @(
      @('base-owned', 'construct.Output', 'policy', 'exact'),
      @('specialized-owned', 'construct.Output', 'policy', 'exact'),
      @('injected-strategy', 'construct.Output', 'policy', 'exact'),
      @('compatibility-dual-path', 'construct.Output', 'policy', 'exact'),
      @('compatibility-dual-path', 'construct.Source Reference', 'compatibility-reason', 'compatibility-reason=<non-empty>'),
      @('compatibility-dual-path', 'construct.Source Reference', 'router-owner', 'router-owner=<non-empty>'),
      @('compatibility-dual-path', 'construct.Decision Reference', 'approval-reference', '<non-not-applicable>'),
      @('compatibility-dual-path', 'construct.Trace IDs', 'parity-test', 'PARITY-###')
    ) `
    $context
  Test-ActivationSliceRuleTable `
    $Text `
    'Async evidence schema' `
    @('Classification', 'Artifact location', 'Required key', 'Required value') `
    @(
      @('async', 'selector.Input', 'async-classification', 'async-classification=async'),
      @('async', 'selector.Output', 'initial-loading', 'initial-loading=<non-empty>'),
      @('async', 'selector.Output', 'update-watch', 'update-watch=<non-empty>'),
      @('async', 'selector.Output', 'reselection', 'reselection=<non-empty>'),
      @('async', 'selector.Output', 'state-preservation-reset', 'state-preservation-reset=<non-empty>'),
      @('async', 'selector.Output', 'failure-behavior', 'failure-behavior=<non-empty>'),
      @('async', 'test.Output', 'lifecycle-test-trace', 'lifecycle-test-trace=<trace-id>'),
      @('immutable', 'selector.Input', 'async-classification', 'async-classification=immutable'),
      @('immutable', 'selector.Source Reference', 'immutability-evidence', 'immutability-evidence=<non-empty>')
    ) `
    $context
}

function Test-Contracts {
  $schemaPath = Join-Path $root 'skills/aitoolkit-schemas/SKILL.md'
  $profilePath = Join-Path $root 'templates/migration/project-profile.yaml'
  $scopeContractPath = Join-Path $root 'contracts/migration-scope-orchestration.md'
  $conformanceContractPath = Join-Path $root 'contracts/target-structure-conformance.md'
  $activationContractPath = if ([string]::IsNullOrWhiteSpace($ActivationSliceContractFixturePath)) {
    Join-Path $root 'contracts/activation-slice.md'
  }
  else {
    [IO.Path]::GetFullPath($ActivationSliceContractFixturePath)
  }
  if (-not (Test-Path $activationContractPath)) { $errors.Add('Missing Activation Slice contract resource'); return }
  if (-not (Test-Path $profilePath)) { $errors.Add('Missing project profile template'); return }
  $schemaText = Get-Content -Raw -Encoding utf8 $schemaPath
  $profileText = Get-Content -Raw -Encoding utf8 $profilePath
  $activationContractText = Get-Content -Raw -Encoding utf8 $activationContractPath
  if (-not (Test-Path -LiteralPath $scopeContractPath -PathType Leaf)) {
    $errors.Add('Missing migration scope orchestration contract resource')
  }
  else {
    $scopeContractText = Get-Content -Raw -Encoding utf8 $scopeContractPath
    Invoke-MigrationValidationModule `
      'tests/validation/scope-artifacts.validation.ps1' `
      'Test-ScopeArtifacts' `
      'Requested Scope' `
      $root `
      $scopeContractText
  }
  if (-not (Test-Path -LiteralPath $conformanceContractPath -PathType Leaf)) {
    $errors.Add('Missing target structure conformance contract resource')
  }
  else {
    $conformanceContractText = Get-Content -Raw -Encoding utf8 $conformanceContractPath
    Invoke-MigrationValidationModule `
      'tests/validation/target-conformance.validation.ps1' `
      'Test-TargetConformance' `
      'Comparable Target Exemplars' `
      $root `
      $conformanceContractText
  }
  $text = $schemaText + $profileText
  Test-ActivationSliceContract $activationContractText
  @(
    'ACT-###',
    'applicable | not-applicable-approved | unknown',
    'upstream-response',
    'requested-key',
    'parse-model',
    'state-holder',
    'selector',
    'construct',
    'render',
    'downstream-consumer',
    'test',
    'implement | reuse | deferred-approved | not-applicable-approved',
    'verified | missing | conflict | unknown',
    'base-owned',
    'specialized-owned',
    'injected-strategy',
    'compatibility-dual-path',
    'Router Policy | Artifact location | Required key | Required value',
    'compatibility-reason=<non-empty>',
    'router-owner=<non-empty>',
    'PARITY-###',
    'Classification | Artifact location | Required key | Required value',
    'async-classification=async',
    'async-classification=immutable',
    'initial-loading=<non-empty>',
    'update-watch=<non-empty>',
    'reselection=<non-empty>',
    'state-preservation-reset=<non-empty>',
    'failure-behavior=<non-empty>',
    'lifecycle-test-trace=<trace-id>',
    'immutability-evidence=<non-empty>',
    'status: draft',
    'result: blocked',
    'It must not be reported as `partial`.',
    'Technical design is not executable until router ownership and asynchronous reselection/lifecycle decisions are resolved.'
  ) | ForEach-Object {
    if ($activationContractText -cnotmatch [regex]::Escape($_)) {
      $errors.Add("Activation Slice contract missing: $_")
    }
  }
  [void](Resolve-MigrationProfileSettings $profileText 'Migration project profile template' $true)
  $legacyProfileText = [regex]::Replace($profileText, '(?ms)^automation:\s*\r?\n  mode:\s*interactive\s*\r?\n', '', 1)
  $legacyProfileText = [regex]::Replace($legacyProfileText, '(?ms)^output:\s*\r?\n  artifact_language:\s*vi\s*\r?\n', '', 1)
  if ($legacyProfileText -ceq $profileText) {
    $errors.Add('Legacy migration project profile compatibility fixture must omit generated automation/output sections')
  }
  $legacySettings = Resolve-MigrationProfileSettings $legacyProfileText 'Legacy migration project profile'
  if ($legacySettings.automation_mode -cne 'interactive' -or $legacySettings.artifact_language -cne 'vi') {
    $errors.Add('Legacy migration project profile must resolve missing automation/output to interactive and vi')
  }
  Require-Token $schemaText 'A legacy profile that omits `automation` and `output` resolves to `automation.mode: interactive` and `output.artifact_language: vi`; it remains valid and is not rewritten merely to apply these fallbacks.' 'Migration profile compatibility'
  @(
    'artifact_type: migration-master-spec',
    'artifact_type: migration-master-plan',
    'work_item_id: WORK-<SCOPE>-<NAME>',
    'attempt_id: ATTEMPT-<WORK-ITEM>-<NN>',
    'delivery_adapter:',
    'decomposition:',
    'supersedes: <artifact-id>@<revision> | not-applicable',
    'runtime_evidence_state: <value from target-structure-conformance.md>',
    'architecture_conformance_state: <value from target-structure-conformance.md>',
    'selector_schema_state: <value from target-structure-conformance.md>',
    'Historical unit-only artifacts remain readable, but they must not resume to production mutation before compatibility conversion.'
  ) | ForEach-Object {
    Require-Token $schemaText $_ 'Migration scope artifact schema'
  }
  if ($schemaText -match '(?m)^\s*(?:runtime_evidence_state|architecture_conformance_state|selector_schema_state):\s*(?:PASS|FAIL|NOT_RUN|WAIVED|BLOCKED)(?:\s*\||\s*$)') {
    $errors.Add('Migration scope artifact schema must reference canonical assurance enums instead of duplicating them')
  }
  Test-AutomationArtifactContract $schemaText
  @('schema_version: 1','migration:','mode: unknown','architecture_policy: unknown',
    'project_pack:','docs/aitoolkit/migration-project','reviewed_at: null','review_evidence: null',
    'result: complete | partial | blocked','Foundation Baseline ID','Foundation Baseline Reference',
    'Foundation Baseline Approval Reference','workflow_type: feature | bugfix | migration',
    'caller-provided','authoritative') |
    ForEach-Object { Require-Token $text $_ 'Contracts' }
  if ($text -notmatch 'greenfield.*design-new' -or $text -notmatch 'incremental.*preserve-existing') {
    $errors.Add('Missing migration mode invariant')
  }
  if ($profileText -match '(?m)^change_type\s*:') {
    $errors.Add('Migration project profile template must not declare top-level change_type')
  }

  $documentsMatch = [regex]::Match(
    $profileText,
    '(?ms)^documents:\s*\r?\n(?<body>(?:^  [A-Za-z_][A-Za-z0-9_-]*:\s*\[\]\s*\r?\n)+)'
  )
  $documentBody = if ($documentsMatch.Success) { $documentsMatch.Groups['body'].Value } else { '' }
  $expectedDocumentCategories = @('requirements', 'uiux', 'migration', 'architecture')
  foreach ($category in $expectedDocumentCategories) {
    $categoryMatches = [regex]::Matches($documentBody, "(?m)^  $([regex]::Escape($category)):\s*\[\]\s*$")
    if ($categoryMatches.Count -ne 1) {
      $errors.Add("Migration project profile documents must declare exactly one ${category}: [] list")
    }
  }
  $actualDocumentCategories = @(
    [regex]::Matches($documentBody, '(?m)^  (?<category>[A-Za-z_][A-Za-z0-9_-]*):\s*\[\]\s*$') |
      ForEach-Object { $_.Groups['category'].Value }
  )
  foreach ($unexpectedCategory in $actualDocumentCategories | Where-Object { $_ -notin $expectedDocumentCategories }) {
    $errors.Add("Migration project profile documents contains unexpected category: $unexpectedCategory")
  }
  $expectedDocumentEntryKeys = @('path', 'input_source', 'format', 'readability', 'evidence_id')
  $expectedDocumentEntrySignature = (($expectedDocumentEntryKeys | Sort-Object) -join '|')
  $profileEntrySchemaMatch = [regex]::Match(
    $profileText,
    '(?ms)^# Each non-empty documents list entry has exactly these keys and no others:\s*\r?\n(?<body>(?:^# (?:- |  )[A-Za-z_][A-Za-z0-9_-]*:[^\r\n]*(?:\r?\n|\z))+)'
  )
  $profileDocumentEntryKeys = if ($profileEntrySchemaMatch.Success) {
    @(
      [regex]::Matches($profileEntrySchemaMatch.Groups['body'].Value, '(?m)^# (?:- |  )(?<key>[A-Za-z_][A-Za-z0-9_-]*):') |
        ForEach-Object { $_.Groups['key'].Value }
    )
  }
  else {
    @()
  }
  if ((($profileDocumentEntryKeys | Sort-Object) -join '|') -cne $expectedDocumentEntrySignature) {
    $errors.Add('Migration project profile document entry keys must be exactly: path, input_source, format, readability, evidence_id')
  }

  $schemaEntryMatch = [regex]::Match(
    $schemaText,
    '(?ms)^Every non-empty item in any of the four `documents` lists.*?\r?\n\s*```yaml\s*\r?\n(?<body>.*?)^```\s*$'
  )
  $schemaDocumentEntryKeys = if ($schemaEntryMatch.Success) {
    @(
      [regex]::Matches($schemaEntryMatch.Groups['body'].Value, '(?m)^(?:- |  )(?<key>[A-Za-z_][A-Za-z0-9_-]*):') |
        ForEach-Object { $_.Groups['key'].Value }
    )
  }
  else {
    @()
  }
  if ((($schemaDocumentEntryKeys | Sort-Object) -join '|') -cne $expectedDocumentEntrySignature) {
    $errors.Add('Migration project profile schema document entry keys must be exactly: path, input_source, format, readability, evidence_id')
  }

  $expectedDocumentEntryKeys | ForEach-Object {
    Require-Token $profileText $_ 'Migration project profile document entry schema'
    Require-Token $schemaText $_ 'Migration project profile schema document entry'
  }
  Require-Token $profileText 'exactly these keys and no others' 'Migration project profile document entry schema'
  Require-Token $schemaText 'exactly' 'Migration project profile schema document entry'

  if ($schemaText -match '(?is)Migration Gerrit.{0,180}(?:immediate|predecessor)') {
    $errors.Add('Data contracts must not require an implicit Migration Gerrit predecessor')
  }
}

function Test-IsAllowedCanonicalWordMatch([string]$Text, [Text.RegularExpressions.Match]$Match) {
  if ($Match.Value[0] -ne [char]0x00C2 -or $Match.Index -eq 0) { return $false }
  if (-not [char]::IsLetter($Text[$Match.Index - 1])) { return $false }

  $start = $Match.Index - 1
  while ($start -gt 0 -and [char]::IsLetter($Text[$start - 1])) { $start-- }
  $end = $Match.Index + $Match.Length
  while ($end -lt $Text.Length -and [char]::IsLetter($Text[$end])) { $end++ }
  $word = $Text.Substring($start, $end - $start)
  $circumflexA = ([char]0x00C2).ToString()
  $allowedWords = @("C${circumflexA}Y", "PH${circumflexA}N")
  return $word.IsNormalized([Text.NormalizationForm]::FormC) -and $allowedWords -ccontains $word
}

function Test-Encoding {
  $mojibakeTokens = @(
      ([char]0x00C3).ToString() + '.'
      ([char]0x00C2).ToString() + '.'
      ([char]0x00E2).ToString() + ([char]0x2020).ToString()
      ([char]0x00E2).ToString() + ([char]0x20AC).ToString() + ([char]0x201D).ToString()
      ([char]0x00C4).ToString() + ([char]0x2018).ToString()
      ([char]0x00C6).ToString() + ([char]0x00B0).ToString()
  )
  $mojibakePattern = ($mojibakeTokens -join '|')
  Get-ChildItem -Path $root -Recurse -File |
    Where-Object { $_.Extension -in '.md', '.yaml', '.yml', '.json', '.ps1' } |
    ForEach-Object {
      $text = Get-Content -Raw -Encoding utf8 $_.FullName
      foreach ($match in [regex]::Matches($text, $mojibakePattern)) {
        # The exact pattern overlaps two reviewed NFC Vietnamese words; every other match fails.
        if (Test-IsAllowedCanonicalWordMatch $text $match) { continue }
        $errors.Add("Encoding mojibake: $($_.FullName)")
        break
      }
    }
}

function Test-TemplateFrontMatter([string]$Text, [string]$TemplateName) {
  $match = [regex]::Match(
    $Text,
    '\A---\r?\n(?<frontMatter>.*?)\r?\n---(?=\r?\n|\z)',
    [Text.RegularExpressions.RegexOptions]::Singleline
  )
  if (-not $match.Success) {
    $errors.Add("Template $TemplateName missing YAML front matter")
    return
  }

  $frontMatter = $match.Groups['frontMatter'].Value
  $fields = @(
    [pscustomobject]@{ Name = 'status'; Values = @('draft', 'approved') }
    [pscustomobject]@{ Name = 'result'; Values = @('complete', 'partial', 'blocked') }
  )
  foreach ($field in $fields) {
    $fieldPattern = "(?m)^$([regex]::Escape($field.Name)):\s*(?<value>\S.*?)\s*$"
    $fieldMatches = [regex]::Matches($frontMatter, $fieldPattern)
    if ($fieldMatches.Count -ne 1) {
      $errors.Add("Template $TemplateName $($field.Name) must appear exactly once in YAML front matter")
      continue
    }

    $value = $fieldMatches[0].Groups['value'].Value.Trim()
    if ($value -notin $field.Values) {
      $errors.Add("Template $TemplateName invalid $($field.Name): $value")
    }
  }
}

function Test-MigrationTechnologyTokens([string]$Text, [string]$Context) {
  $technologyTokens = @(
    'QML', 'Luna Service', 'Flutter', 'Riverpod', 'Clean Architecture',
    'flutter analyze', 'flutter test', 'LGE conventions'
  )
  foreach ($technologyToken in $technologyTokens) {
    $pattern = "(?i)(?<![A-Za-z0-9])$([regex]::Escape($technologyToken))(?![A-Za-z0-9])"
    if ($Text -match $pattern) {
      $errors.Add("$Context contains prohibited technology token: $technologyToken")
    }
  }
}

function Get-ActivationSliceContractColumns([string]$ContractText = '') {
  $contractPath = Join-Path $root 'contracts/activation-slice.md'
  if ([string]::IsNullOrWhiteSpace($ContractText)) {
    if (-not (Test-Path $contractPath)) {
      $errors.Add('Missing Activation Slice contract resource')
      return @()
    }
    $ContractText = Get-Content -Raw -Encoding utf8 $contractPath
  }

  $schemaSection = Get-MarkdownSectionBody `
    $ContractText `
    'Artifact row schema' `
    'Activation Slice contract'
  if ($schemaSection -eq '') { return @() }

  $tableBlocks = @(Get-MarkdownTableBlocks $schemaSection)
  if ($tableBlocks.Count -ne 1) {
    $errors.Add("Activation Slice contract Artifact row schema table must appear exactly once; found $($tableBlocks.Count)")
    return @()
  }
  $expectedColumns = @(
    'Activation Slice ID', 'Applicability', 'Seam', 'Input', 'Output',
    'Source Reference', 'Trace IDs', 'Disposition', 'Status',
    'Decision Reference', 'Deferred Unit ID'
  )
  $header = @(Split-MarkdownTableLine $tableBlocks[0].Lines[0])
  $rows = @(Get-MarkdownTableRows `
    $ContractText `
    'Artifact row schema' `
    'Activation Slice contract Artifact row schema' `
    $expectedColumns)
  if ($rows.Count -ne 1) {
    $errors.Add("Activation Slice contract Artifact row schema must contain exactly one schema row; found $($rows.Count)")
  }
  else {
    $expectedValues = @(
      'ACT-###', 'applicability enum', 'canonical seam', 'activation input',
      'seam output', 'evidence location', 'related trace IDs', 'disposition enum',
      'status enum', 'approval or `not-applicable`', 'deferred unit or `not-applicable`'
    )
    $actualValues = @($expectedColumns | ForEach-Object { Get-ActivationSliceCellValue $rows[0] $_ })
    if (($actualValues -join ([char]0x001F)) -cne ($expectedValues -join ([char]0x001F))) {
      $errors.Add('Activation Slice contract Artifact row schema row must match the canonical definition')
    }
  }
  return @($header)
}

function Get-ActivationSliceContractSeams([string]$ContractText = '') {
  $contractPath = Join-Path $root 'contracts/activation-slice.md'
  if ([string]::IsNullOrWhiteSpace($ContractText)) {
    if (-not (Test-Path $contractPath)) {
      $errors.Add('Missing Activation Slice contract resource')
      return @()
    }
    $ContractText = Get-Content -Raw -Encoding utf8 $contractPath
  }

  $seamsSection = Get-MarkdownSectionBody `
    $ContractText `
    'Canonical seams' `
    'Activation Slice contract'
  if ($seamsSection -eq '') { return @() }

  return @(
    [regex]::Matches($seamsSection, '(?m)^\d+\.\s+`(?<seam>[^`]+)`\s*$') |
      ForEach-Object { $_.Groups['seam'].Value }
  )
}

function Get-ActivationSliceContractEnumValues([string]$Name, [string]$ContractText = '') {
  $contractPath = Join-Path $root 'contracts/activation-slice.md'
  if ([string]::IsNullOrWhiteSpace($ContractText)) {
    if (-not (Test-Path $contractPath)) {
      $errors.Add('Missing Activation Slice contract resource')
      return @()
    }
    $ContractText = Get-Content -Raw -Encoding utf8 $contractPath
  }

  $pattern = if ($Name -ceq 'Applicability') {
    '(?ms)one applicability value:\s*\r?\n\s*`(?<values>[^`]+)`'
  }
  else {
    "(?ms)``$([regex]::Escape($Name))`` is one of:\s*\r?\n\s*``(?<values>[^``]+)``"
  }
  $match = [regex]::Match($ContractText, $pattern)
  if (-not $match.Success) {
    $errors.Add("Activation Slice contract missing $Name enum")
    return @()
  }
  return @(
    $match.Groups['values'].Value.Split('|') |
      ForEach-Object { $_.Trim() } |
      Where-Object { $_ -ne '' }
  )
}

function Get-ActivationSliceRouterRules([string]$ContractText = '') {
  $contractPath = Join-Path $root 'contracts/activation-slice.md'
  if ([string]::IsNullOrWhiteSpace($ContractText)) {
    if (-not (Test-Path $contractPath)) {
      $errors.Add('Missing Activation Slice contract resource')
      return @()
    }
    $ContractText = Get-Content -Raw -Encoding utf8 $contractPath
  }
  return @(Get-ActivationSliceContractTableRules 'Router evidence schema' $ContractText)
}

function Get-ActivationSliceAsyncRules([string]$ContractText = '') {
  $contractPath = Join-Path $root 'contracts/activation-slice.md'
  if ([string]::IsNullOrWhiteSpace($ContractText)) {
    if (-not (Test-Path $contractPath)) {
      $errors.Add('Missing Activation Slice contract resource')
      return @()
    }
    $ContractText = Get-Content -Raw -Encoding utf8 $contractPath
  }
  return @(Get-ActivationSliceContractTableRules 'Async evidence schema' $ContractText)
}

function Get-ActivationSliceContractTableRules(
  [string]$SectionName,
  [string]$ContractText = ''
) {
  $contractPath = Join-Path $root 'contracts/activation-slice.md'
  if ([string]::IsNullOrWhiteSpace($ContractText)) {
    if (-not (Test-Path $contractPath)) {
      $errors.Add('Missing Activation Slice contract resource')
      return @()
    }
    $ContractText = Get-Content -Raw -Encoding utf8 $contractPath
  }
  $context = 'Activation Slice contract'
  $sectionText = Get-MarkdownSectionBody $ContractText $SectionName $context
  if ($sectionText -eq '') { return @() }
  $tableBlocks = @(Get-MarkdownTableBlocks $sectionText)
  if ($tableBlocks.Count -ne 1) {
    $errors.Add("$context $SectionName rule table must appear exactly once; found $($tableBlocks.Count)")
    return @()
  }
  $rows = @(Get-MarkdownTableRows $ContractText $SectionName $context)
  $expectedCardinality = switch -CaseSensitive ($SectionName) {
    'Identifier formats' { 4 }
    'Field requirements' { 4 }
    'Legal row combinations' { 15 }
    'Completion and blocking rules' { 5 }
    'Domain-blocker evidence' { 1 }
    'Step 10 baseline-waiver resume' { 9 }
    'Step 10 resume evidence' { 3 }
    'Step 10 resume state' { 2 }
    'Step 10 native blocker eligibility' { 5 }
    'Immediate predecessor roles and lifecycle' { 16 }
    'Bootstrap selected-unit handoff' { 3 }
    'Step 10 predecessor unit selection' { 3 }
    'Direct-plan foundation state' { 2 }
    'Downstream selected-unit handoff' { 4 }
    'Regression parity handoff' { 1 }
    'Assurance task provenance handoff' { 3 }
    'Assurance verdict consistency' { 2 }
    'Source Reference enrichment' { 1 }
    'Router evidence schema' { 8 }
    'Async evidence schema' { 9 }
    default { -1 }
  }
  if ($expectedCardinality -ge 0 -and $rows.Count -ne $expectedCardinality) {
    $errors.Add("$context $SectionName rule table must contain exactly $expectedCardinality canonical rows; found $($rows.Count)")
  }
  $serializedRows = @($tableBlocks[0].Lines | Select-Object -Skip 2 | ForEach-Object { $_.Trim() })
  $uniqueRows = @(Get-CaseSensitiveUniqueStrings $serializedRows)
  if ($uniqueRows.Count -ne $serializedRows.Count) {
    $errors.Add("$context $SectionName rule table must not contain duplicate rows")
  }
  return @($rows)
}

function Test-ActivationSliceTemplateEnvelope(
  [string]$Text,
  [string[]]$ExpectedColumns,
  [string]$Context
) {
  $sectionName = 'Activation Slice'
  $headingMatches = @(Get-MarkdownSectionHeadings $Text $sectionName)
  if ($headingMatches.Count -eq 0) {
    $errors.Add("$Context missing canonical Activation Slice heading")
    return
  }
  if ($headingMatches.Count -ne 1) {
    $errors.Add("$Context canonical Activation Slice heading must appear exactly once; found $($headingMatches.Count)")
    return
  }

  [void](Get-MarkdownTableRows $Text $sectionName $Context $ExpectedColumns)
}

function Test-VietnameseArtifactTemplate(
  [string]$Text,
  [string]$Context,
  [string]$ExpectedTitle,
  [bool]$RequireConclusion = $true
) {
  Require-Token $Text '<!-- artifact_language: vi -->' "$Context language intent"
  Require-Token $Text $ExpectedTitle "$Context Vietnamese title"
  $requiredGeneratedSections = @(
    (ConvertFrom-Utf8Base64 'IyMgQuG6sW5nIGNo4bupbmc=')
    (ConvertFrom-Utf8Base64 'IyMgxJBp4buDbSBjaMawYSByw7U=')
  )
  if ($RequireConclusion) {
    $requiredGeneratedSections += ConvertFrom-Utf8Base64 'IyMgS+G6v3QgbHXhuq1u'
  }
  $requiredGeneratedSections | ForEach-Object {
    Require-Token $Text $_ "$Context Vietnamese generated prose"
  }

  Test-NoEnglishOnlyGeneratedPlaceholder $Text $Context
}

function Test-NoEnglishOnlyGeneratedPlaceholder([string]$Text, [string]$Context) {
  $englishOnlyPlaceholderPattern = '(?i)<(?:english-only placeholder|summary|notes|unknown or assumption|finding|rationale|decision|impact|options|owner|none or exact blocking gaps|none or recorded degraded coverage|profile/pack path \+ mandatory rules \+ optional gaps/degraded coverage|availability probe or required test/build/baseline command|matching disposition from the same legal pair|status from one legal pair|verbatim command/output/capability evidence|pass/fail count|error count|test, lint, build, parity, or baseline check)>'
  if ($Text -match $englishOnlyPlaceholderPattern) {
    $errors.Add("$Context contains English-only generated placeholder: $($Matches[0])")
  }
}

function Test-CanonicalSelectedMigrationUnitHeading([string]$Text, [string]$Context) {
  $canonicalHeading = '## Selected Migration Unit'
  $translatedHeading = '## ' + (ConvertFrom-Utf8Base64 'xJDGoW4gduG7iyBtaWdyYXRpb24gxJHGsOG7o2MgY2jhu41u')
  $canonicalCount = [regex]::Matches(
    $Text,
    "(?m)^$([regex]::Escape($canonicalHeading))\r?$"
  ).Count
  if ($canonicalCount -ne 1) {
    $errors.Add("$Context canonical selected-unit heading must appear exactly once; found $canonicalCount")
  }
  if ($Text -match "(?m)^$([regex]::Escape($translatedHeading))\r?$") {
    $errors.Add("$Context contains translated machine-contract heading: $translatedHeading")
  }
}

function Test-ArtifactLanguageProducer([string]$Text, [string]$Context) {
  @(
    (ConvertFrom-Utf8Base64 'IyMgTmfDtG4gbmfhu68gYXJ0aWZhY3Q='),
    '`artifact_language: vi`',
    (ConvertFrom-Utf8Base64 'dGnhur9uZyBWaeG7h3QgVVRGLTg='),
    'machine-readable'
  ) | ForEach-Object { Require-Token $Text $_ "$Context artifact language" }
}

function Test-SourceDocumentTranslationBoundary([string]$Text, [string]$Context) {
  $sourceBoundary = ConvertFrom-Utf8Base64 'S2jDtG5nIGThu4tjaCwgZGkgY2h1eeG7g24gaG/hurdjIHPhu61hIHTDoGkgbGnhu4d1IG5ndeG7k24='
  $translationAuthorizationPattern = ConvertFrom-Utf8Base64 'KD9pcykoPzptYXl8Y2FufGPDsyB0aOG7g3zEkcaw4bujYyBwaMOpcCkuezAsODB9KD86dHJhbnNsYXRlfGThu4tjaCkuezAsODB9KD86c291cmNlIGRvY3VtZW50cz98dMOgaSBsaeG7h3Ugbmd14buTbik='
  Require-Token $Text $sourceBoundary "$Context source-document boundary"
  if ($Text -match $translationAuthorizationPattern) {
    $errors.Add("$Context must not authorize source-document translation")
  }
}

function Test-VerificationOutcomeLegalPairs([string]$Text, [string]$Context) {
  $sectionName = 'Check Outcome Legal Pairs'
  Test-MarkdownTableExactColumns `
    $Text `
    $sectionName `
    @('Execution Status', 'Verification Disposition', 'Meaning') `
    $Context
  $sectionText = Get-MarkdownSectionBody $Text $sectionName $Context
  @(
    'Only required-command lifecycle `not-started` may use `WAIVED`.',
    'Lifecycle `started-without-correctness/regression-result` requires `FAIL` + `BLOCKED`.'
  ) | ForEach-Object {
    Require-Token $sectionText $_ $Context
  }
  $rows = @(Get-MarkdownTableRows $Text $sectionName $Context)
  $expectedPairs = @(
    [pscustomobject]@{
      Status = '`PASS`'; Disposition = '`verified`'; Meaning = 'required command ran and passed'
    }
    [pscustomobject]@{
      Status = '`FAIL`'; Disposition = '`BLOCKED`'; Meaning = 'required command started and returned failure'
    }
    [pscustomobject]@{
      Status = '`NOT_RUN`'; Disposition = '`BLOCKED`'; Meaning = 'required command did not run; native blocker'
    }
    [pscustomobject]@{
      Status = '`NOT_RUN`'; Disposition = '`WAIVED`'; Meaning = 'eligible environment blocker; orchestrator-only'
    }
  )
  if ($rows.Count -ne $expectedPairs.Count) {
    $errors.Add("$Context must contain exactly $($expectedPairs.Count) legal status/disposition pairs; found $($rows.Count)")
  }
  foreach ($expected in $expectedPairs) {
    $matches = @($rows | Where-Object {
      $_.'Execution Status' -ceq $expected.Status -and
      $_.'Verification Disposition' -ceq $expected.Disposition
    })
    if ($matches.Count -ne 1 -or $matches[0].Meaning -cne $expected.Meaning) {
      $errors.Add("$Context legal pair invalid: $($expected.Status) + $($expected.Disposition)")
    }
  }
  $waivedRows = @($rows | Where-Object { $_.'Verification Disposition' -ceq '`WAIVED`' })
  if (
    $waivedRows.Count -ne 1 -or
    $waivedRows[0].'Execution Status' -cne '`NOT_RUN`'
  ) {
    $errors.Add("$Context requires Execution Status = NOT_RUN whenever Verification Disposition = WAIVED")
  }
}

function Test-Step10ResumeOrchestrator([string]$Text) {
  $sectionName = 'Step 10 pre-mutation baseline waiver resume'
  $context = 'Migration step 10 baseline-waiver resume'
  Test-MarkdownTableExactColumns `
    $Text `
    $sectionName `
    @('Priority', 'Candidate', 'Re-entry decision', 'Step 10 todo', 'Downstream') `
    $context
  $sectionText = Get-MarkdownSectionBody $Text $sectionName $context
  @(
    'Do not use ordinary Environment waiver transition downstream continuation for a step 10 artifact that blocked before target edits.',
    'The orchestrator records the exact approved waiver and evidence before re-entry.',
    'Re-entry receives the same selected unit, plan/approval references, mode constraint, source/target, and resolved automation mode.',
    'For resumed step 10, this exact approved/partial/auto-waive tuple overrides generic steps 1 and 6.'
  ) | ForEach-Object { Require-Token $sectionText $_ $context }

  $rows = @(Get-MarkdownTableRows $Text $sectionName $context)
  $expectedRows = @(
    [pscustomobject]@{
      Priority = '1'
      Candidate = 'waiver-ineligible blocker, started required command, schema/frontmatter/handoff error, or HARD gate'
      Decision = 'forbidden'
      Todo = '`in_progress`'
      Downstream = 'forbidden'
    }
    [pscustomobject]@{
      Priority = '2'
      Candidate = 'incremental step 10 pre-mutation baseline unavailable; separate availability probe; required command not-started; target unedited; exact waiver approved'
      Decision = 're-invoke `migration/code-migration` with approved waiver artifact'
      Todo = '`in_progress`'
      Downstream = 'forbidden until resumed implementation receives normal approval'
    }
    [pscustomobject]@{
      Priority = '3'
      Candidate = 'resumed step 10 retains exact waiver and records target source mutation with unit and trace evidence'
      Decision = 'validate exact approved/partial/auto-waive outcome'
      Todo = '`in_progress` until exact valid partial outcome; then `completed`'
      Downstream = 'allowed only after exact valid partial outcome'
    }
    [pscustomobject]@{
      Priority = '4'
      Candidate = 'resumed step 10 has no target source mutation, loses waiver/evidence, or returns any blocker'
      Decision = 'stop with native blocker'
      Todo = '`in_progress`'
      Downstream = 'forbidden'
    }
  )
  if ($rows.Count -ne $expectedRows.Count) {
    $errors.Add("$context must contain exactly $($expectedRows.Count) states; found $($rows.Count)")
  }
  foreach ($expected in $expectedRows) {
    $matches = @($rows | Where-Object { $_.Candidate -ceq $expected.Candidate })
    if ($matches.Count -ne 1) {
      $errors.Add("$context candidate missing or duplicated: $($expected.Candidate)")
      continue
    }
    $row = $matches[0]
    if (
      $row.Priority -cne $expected.Priority -or
      $row.'Re-entry decision' -cne $expected.Decision -or
      $row.'Step 10 todo' -cne $expected.Todo -or
      $row.Downstream -cne $expected.Downstream
    ) {
      $errors.Add("$context candidate invalid: $($expected.Candidate)")
    }
  }
}

function Test-Templates {
  $templateRoot = Join-Path $root 'templates/migration'
  $templateNames = @(
    'input-report', 'discovery', 'requirements-uiux', 'inventory', 'mapping',
    'gaps-conflicts', 'technical-design', 'migration-plan', 'bootstrap-report',
    'implementation-report', 'parity-report', 'regression-report', 'onboarding-input',
    'project-inspection', 'mode-proposal', 'project-pack-review'
  )
  $actualTemplateNames = @(
    Get-ChildItem -Path $templateRoot -File -Filter '*.md' |
      ForEach-Object { $_.BaseName }
  )
  $unexpectedTemplateNames = $actualTemplateNames | Where-Object { $_ -notin ($templateNames + @('review-report', 'verification-report')) }
  $unexpectedTemplateNames | ForEach-Object {
    $errors.Add("Unexpected migration template: $_.md")
  }

  $vietnameseTitles = @{
    'input-report' = (ConvertFrom-Utf8Base64 'IyBCw6FvIGPDoW8gxJHhuqd1IHbDoG8gbWlncmF0aW9u')
    'discovery' = (ConvertFrom-Utf8Base64 'IyBLaOG6o28gc8OhdCBtaWdyYXRpb24=')
    'requirements-uiux' = (ConvertFrom-Utf8Base64 'IyBZw6p1IGPhuqd1IHbDoCBVSS9VWCBtaWdyYXRpb24=')
    'inventory' = (ConvertFrom-Utf8Base64 'IyBEYW5oIG3hu6VjIG1pZ3JhdGlvbg==')
    'mapping' = (ConvertFrom-Utf8Base64 'IyDDgW5oIHjhuqEgbWlncmF0aW9u')
    'gaps-conflicts' = (ConvertFrom-Utf8Base64 'IyBLaG/huqNuZyB0cuG7kW5nIHbDoCB4dW5nIMSR4buZdCBtaWdyYXRpb24=')
    'technical-design' = (ConvertFrom-Utf8Base64 'IyBUaGnhur90IGvhur8ga+G7uSB0aHXhuq10IG1pZ3JhdGlvbg==')
    'migration-plan' = (ConvertFrom-Utf8Base64 'IyBL4bq/IGhv4bqhY2ggbWlncmF0aW9u')
    'bootstrap-report' = (ConvertFrom-Utf8Base64 'IyBCw6FvIGPDoW8gYm9vdHN0cmFwIG1pZ3JhdGlvbg==')
    'implementation-report' = (ConvertFrom-Utf8Base64 'IyBCw6FvIGPDoW8gdHJp4buDbiBraGFpIG1pZ3JhdGlvbg==')
    'parity-report' = (ConvertFrom-Utf8Base64 'IyBCw6FvIGPDoW8gdMawxqFuZyDEkcawxqFuZyBtaWdyYXRpb24=')
    'regression-report' = (ConvertFrom-Utf8Base64 'IyBCw6FvIGPDoW8gaOG7k2kgcXV5IG1pZ3JhdGlvbg==')
    'onboarding-input' = (ConvertFrom-Utf8Base64 'IyDEkOG6p3UgdsOgbyBvbmJvYXJkaW5nIG1pZ3JhdGlvbg==')
    'project-inspection' = (ConvertFrom-Utf8Base64 'IyBLaOG6o28gc8OhdCBk4buxIMOhbiBtaWdyYXRpb24=')
    'mode-proposal' = (ConvertFrom-Utf8Base64 'IyDEkOG7gSB4deG6pXQgY2jhur8gxJHhu5kgbWlncmF0aW9u')
    'project-pack-review' = (ConvertFrom-Utf8Base64 'IyDEkMOhbmggZ2nDoSBwcm9qZWN0IHBhY2sgbWlncmF0aW9u')
  }
  $selectedMigrationUnitSection = 'Selected Migration Unit'
  $nativeBlockersSection = ConvertFrom-Utf8Base64 'QmxvY2tlciBn4buRYw=='
  $checkOutcomesSection = 'Check Outcomes'
  $runSummarySection = ConvertFrom-Utf8Base64 'VMOzbSB04bqvdCBydW4='
  $terminalVerificationSection = ConvertFrom-Utf8Base64 'WMOhYyBtaW5oIMSR4bqndSBjdeG7kWk='
  $artifactLinksSection = ConvertFrom-Utf8Base64 'TGnDqm4ga+G6v3QgYXJ0aWZhY3Q='
  $lessonsSection = ConvertFrom-Utf8Base64 'QsOgaSBo4buNYyB2w6AgY8OhY2ggeOG7rSBsw70='
  $automationWaiversSection = ConvertFrom-Utf8Base64 'QXV0b21hdGlvbiB3YWl2ZXI='
  $foundationRecordSection = ConvertFrom-Utf8Base64 'QuG6o24gZ2hpIGJhc2VsaW5lIG7hu4FuIHThuqNuZw=='
  $orderedUnitsSection = ConvertFrom-Utf8Base64 'Q8OhYyDEkcahbiB24buLIG1pZ3JhdGlvbiB0aGVvIHRo4bupIHThu7E='
  $approvedBaselinesSection = ConvertFrom-Utf8Base64 'QmFzZWxpbmUgbuG7gW4gdOG6o25nIMSRw6MgZHV54buHdA=='

  foreach ($templateName in $templateNames) {
    $templatePath = Join-Path $templateRoot "$templateName.md"
    if (-not (Test-Path $templatePath)) {
      $errors.Add("Missing migration template: $templateName.md")
      continue
    }

    $text = Get-Content -Raw -Encoding utf8 $templatePath
    Test-TemplateFrontMatter $text "$templateName.md"
    Test-VietnameseArtifactTemplate `
      $text `
      "Template $templateName.md" `
      $vietnameseTitles[$templateName] `
      ($templateName -cne 'parity-report')
    Test-MigrationTechnologyTokens $text "Template $templateName.md"
  }

  $activationSliceDefinition = Get-ActivationSliceContractDefinition
  $activationSliceTemplateColumns = @($activationSliceDefinition.Columns)
  foreach ($activationSliceTemplateName in @(
    'discovery.md',
    'requirements-uiux.md',
    'inventory.md',
    'mapping.md',
    'gaps-conflicts.md',
    'technical-design.md',
    'migration-plan.md',
    'bootstrap-report.md',
    'implementation-report.md',
    'review-report.md',
    'verification-report.md',
    'parity-report.md',
    'regression-report.md'
  )) {
    $activationSliceTemplatePath = Join-Path $templateRoot $activationSliceTemplateName
    if (-not (Test-Path $activationSliceTemplatePath)) {
      $errors.Add("Missing Activation Slice template: $activationSliceTemplateName")
      continue
    }
    Test-ActivationSliceTemplateEnvelope `
      (Get-Content -Raw -Encoding utf8 $activationSliceTemplatePath) `
      $activationSliceTemplateColumns `
      "Template $activationSliceTemplateName Activation Slice envelope"
  }

  $domainBlockerRules = @($activationSliceDefinition.DomainBlockerRules)
  if ($domainBlockerRules.Count -ne 1) {
    $errors.Add("Migration blocked-output templates require exactly one canonical Domain Blocker rule")
  }
  else {
    $domainBlockerRule = $domainBlockerRules[0]
    $domainBlockerColumns = @(
      (Get-ActivationSliceCellValue $domainBlockerRule 'Required columns').Split(',') |
        ForEach-Object { Trim-AsciiSpaceTab $_ } |
        Where-Object { $_ -ne '' }
    )
    foreach ($domainBlockerTemplateName in @(
      'discovery.md', 'requirements-uiux.md', 'inventory.md', 'mapping.md',
      'gaps-conflicts.md', 'technical-design.md', 'migration-plan.md',
      'bootstrap-report.md', 'implementation-report.md', 'review-report.md',
      'verification-report.md'
    )) {
      $domainBlockerTemplatePath = Join-Path $templateRoot $domainBlockerTemplateName
      if (-not (Test-Path -LiteralPath $domainBlockerTemplatePath)) { continue }
      Test-MarkdownTableExactColumns `
        (Get-Content -Raw -Encoding utf8 -LiteralPath $domainBlockerTemplatePath) `
        (Get-ActivationSliceCellValue $domainBlockerRule 'Section') `
        $domainBlockerColumns `
        "Template $domainBlockerTemplateName blocked-output evidence"
    }
    $bootstrapTemplateText = Get-Content -Raw -Encoding utf8 -LiteralPath (Join-Path $templateRoot 'bootstrap-report.md')
    @('result: blocked', 'blocked-foundation-section=absent', 'blocked-selected-state=pending', 'Domain Blocker') | ForEach-Object {
      Require-Token $bootstrapTemplateText $_ 'Template bootstrap-report.md blocked-output shape'
    }
  }

  $workflowScopedSharedTemplates = @(
    [pscustomobject]@{
      Name = 'review-report.md'
      LegacyTitle = (ConvertFrom-Utf8Base64 'IyBBSSBSZXZpZXcgUmVwb3J0IOKAlCA8bW9kdWxlIG5hbWU+')
      MigrationPath = 'migration/review-report.md'
      MigrationTitle = (ConvertFrom-Utf8Base64 'IyBCw6FvIGPDoW8gQUkgUmV2aWV3IOKAlCA8dMOqbiBtb2R1bGU+')
    }
    [pscustomobject]@{
      Name = 'verification-report.md'
      LegacyTitle = (ConvertFrom-Utf8Base64 'IyBWZXJpZmljYXRpb24gJiBUZXN0aW5nIFJlcG9ydCDigJQgPG1vZHVsZSBuYW1lPg==')
      MigrationPath = 'migration/verification-report.md'
      MigrationTitle = (ConvertFrom-Utf8Base64 'IyBCw6FvIGPDoW8gVmVyaWZpY2F0aW9uICYgVGVzdGluZyDigJQgPHTDqm4gbW9kdWxlPg==')
    }
  )
  foreach ($sharedTemplate in $workflowScopedSharedTemplates) {
    $sharedTemplatePath = Join-Path $root "templates/$($sharedTemplate.Name)"
    if (-not (Test-Path $sharedTemplatePath)) {
      $errors.Add("Missing shared migration template: $($sharedTemplate.Name)")
      continue
    }
    $sharedTemplateText = Get-Content -Raw -Encoding utf8 $sharedTemplatePath
    Require-Token $sharedTemplateText $sharedTemplate.LegacyTitle "Template $($sharedTemplate.Name) legacy feature/bugfix rendering"
    if ($sharedTemplateText -match '<!-- artifact_language: vi -->' -or $sharedTemplateText -match [regex]::Escape($sharedTemplate.MigrationTitle)) {
      $errors.Add("Template $($sharedTemplate.Name) must remain legacy feature/bugfix language; migration rendering belongs in $($sharedTemplate.MigrationPath)")
    }
    $migrationTemplatePath = Join-Path $root "templates/$($sharedTemplate.MigrationPath)"
    if (-not (Test-Path $migrationTemplatePath)) {
      $errors.Add("Missing migration-specific shared-step template: $($sharedTemplate.MigrationPath)")
      continue
    }
    $migrationTemplateText = Get-Content -Raw -Encoding utf8 $migrationTemplatePath
    Test-VietnameseArtifactTemplate $migrationTemplateText "Template $($sharedTemplate.MigrationPath)" $sharedTemplate.MigrationTitle
  }

  $knowledgeTemplatePath = Join-Path $root 'templates/kb-entry.md'
  if (Test-Path $knowledgeTemplatePath) {
    $knowledgeTemplateText = Get-Content -Raw -Encoding utf8 $knowledgeTemplatePath
    Require-Token $knowledgeTemplateText '<!-- artifact_language: vi -->' 'Template kb-entry.md language intent'
    Require-Token `
      $knowledgeTemplateText `
      (ConvertFrom-Utf8Base64 'IyBN4bulYyBLbm93bGVkZ2UgQmFzZQ==') `
      'Template kb-entry.md Vietnamese title'
    Test-NoEnglishOnlyGeneratedPlaceholder $knowledgeTemplateText 'Template kb-entry.md'
  }

  $selectedUnitTemplatePaths = @(
    'migration/bootstrap-report.md',
    'migration/implementation-report.md',
    'migration/parity-report.md',
    'migration/regression-report.md',
    'migration/review-report.md',
    'migration/verification-report.md'
  )
  foreach ($selectedUnitTemplatePath in $selectedUnitTemplatePaths) {
    $selectedUnitTemplateFullPath = Join-Path $root "templates/$selectedUnitTemplatePath"
    if (-not (Test-Path $selectedUnitTemplateFullPath)) { continue }
    Test-CanonicalSelectedMigrationUnitHeading `
      (Get-Content -Raw -Encoding utf8 $selectedUnitTemplateFullPath) `
      "Template $([IO.Path]::GetFileName($selectedUnitTemplatePath))"
  }

  $mappingPath = Join-Path $templateRoot 'mapping.md'
  if (Test-Path $mappingPath) {
    Require-Token (Get-Content -Raw -Encoding utf8 $mappingPath) 'reuse | extend | create | replace | omit' 'Template mapping.md'
  }

  $implementationPath = Join-Path $templateRoot 'implementation-report.md'
  if (Test-Path $implementationPath) {
    $implementationText = Get-Content -Raw -Encoding utf8 $implementationPath
    @(
      (ConvertFrom-Utf8Base64 'IyMgRmlsZSDEkcOjIHRoYXkgxJHhu5Vp')
      (ConvertFrom-Utf8Base64 'IyMgVHJhY2UgSUQgdHJp4buDbiBraGFp')
    ) | ForEach-Object {
      Require-Token $implementationText $_ 'Template implementation-report.md'
    }
    $implementationSelectedUnit = Get-MarkdownSectionBody `
      $implementationText `
      $selectedMigrationUnitSection `
      'Template implementation-report.md'
    Require-Token $implementationSelectedUnit '`foundation_baseline_id`' 'Template implementation-report.md Selected Migration Unit'
    foreach ($linkRule in $activationSliceDefinition.LinkRules) {
      $linkSection = Get-ActivationSliceCellValue $linkRule 'Section'
      $linkColumns = @(
        (Get-ActivationSliceCellValue $linkRule 'Required columns').Split(',') |
          ForEach-Object { $_.Trim() } |
          Where-Object { $_ -ne '' }
      )
      Test-MarkdownTableExactColumns `
        $implementationText `
        $linkSection `
        $linkColumns `
        "Template implementation-report.md $((Get-ActivationSliceCellValue $linkRule 'Record')) linkage"
    }
    Test-MarkdownTableExactColumns `
      $implementationText `
      $nativeBlockersSection `
      @(
        'Stage / Check', 'Native Verdict', 'Command Role', 'Required Command Lifecycle',
        'Command / Capability', 'Observed Error', 'Evidence Reference'
      ) `
      'Template implementation-report.md native blocker evidence'
    $implementationNativeBlockers = Get-MarkdownSectionBody `
      $implementationText `
      $nativeBlockersSection `
      'Template implementation-report.md native blocker evidence'
    @('`BLOCKED`', 'verbatim', 'orchestrator') | ForEach-Object {
      Require-Token $implementationNativeBlockers $_ 'Template implementation-report.md native blocker evidence'
    }
    Test-MarkdownTableExactColumns `
      $implementationText `
      'Step 10 Waiver Resume State' `
      @('Resume Phase', 'Baseline Action', 'Implementation Status', 'Target Mutation Evidence', 'Waiver Evidence') `
      'Template implementation-report.md step 10 waiver resume state'
    $resumeState = Get-MarkdownSectionBody `
      $implementationText `
      'Step 10 Waiver Resume State' `
      'Template implementation-report.md step 10 waiver resume state'
    @(
      '`not-applicable`', '`resume-required`', '`resume-consumed`',
      '`skip-pre-mutation-baseline-only`', 'target source mutation', 'exact approved waiver evidence'
    ) | ForEach-Object {
      Require-Token $resumeState $_ 'Template implementation-report.md step 10 waiver resume state'
    }
    $approvedWaiver = Get-MarkdownSectionBody `
      $implementationText `
      'Approved Baseline Waiver' `
      'Template implementation-report.md approved baseline waiver'
    @(
      'status: approved', 'result: partial', 'approval_source: auto-waive',
      'policy: auto-waive', 'category: environment-unavailable',
      'original_verdict: blocked', 'effective_action: continue',
      'evidence: <verbatim capability/command error reference>'
    ) | ForEach-Object {
      Require-Token $approvedWaiver $_ 'Template implementation-report.md approved baseline waiver'
    }
  }

  $verificationTemplatePath = Join-Path $root 'templates/migration/verification-report.md'
  if (Test-Path $verificationTemplatePath) {
    $verificationTemplateText = Get-Content -Raw -Encoding utf8 $verificationTemplatePath
    Test-VerificationOutcomeLegalPairs `
      $verificationTemplateText `
      'Template verification-report.md legal check outcomes'
    Test-MarkdownTableExactColumns `
      $verificationTemplateText `
      $checkOutcomesSection `
      @(
        'Check', 'Command Role', 'Required Command Lifecycle',
        'Execution Status', 'Verification Disposition', 'Evidence'
      ) `
      'Template verification-report.md truthful check outcomes'
    $verificationCheckOutcomes = Get-MarkdownSectionBody `
      $verificationTemplateText `
      $checkOutcomesSection `
      'Template verification-report.md truthful check outcomes'
    @('`NOT_RUN + WAIVED`', (ConvertFrom-Utf8Base64 'a2jDtG5nIGJhbyBnaeG7nSBsw6AgYFBBU1Ng'), 'verbatim') | ForEach-Object {
      Require-Token $verificationCheckOutcomes $_ 'Template verification-report.md truthful check outcomes'
    }
  }

  foreach ($templateName in @('parity-report', 'regression-report')) {
    $templatePath = Join-Path $templateRoot "$templateName.md"
    if (-not (Test-Path $templatePath)) { continue }
    $text = Get-Content -Raw -Encoding utf8 $templatePath
    $assuranceStepId = if ($templateName -ceq 'parity-report') {
      '13-verify-parity'
    }
    else {
      '14-verify-regression'
    }
    $assuranceRules = @($activationSliceDefinition.AssuranceVerdictRules | Where-Object {
      (Get-ActivationSliceCellValue $_ 'Step ID') -ceq $assuranceStepId
    })
    if ($assuranceRules.Count -ne 1) {
      $errors.Add("Template $templateName.md assurance verdict contract must resolve exactly one rule; found $($assuranceRules.Count)")
    }
    else {
      $assuranceRule = $assuranceRules[0]
      $overallColumns = @(
        (Get-ActivationSliceCellValue $assuranceRule 'Overall required columns').Split(',') |
          ForEach-Object { Trim-AsciiSpaceTab $_ } |
          Where-Object { $_ -ne '' }
      )
      $scenarioColumns = @(
        (Get-ActivationSliceCellValue $assuranceRule 'Scenario required columns').Split(',') |
          ForEach-Object { Trim-AsciiSpaceTab $_ } |
          Where-Object { $_ -ne '' }
      )
      $overallRows = @(Get-MarkdownTableRows `
        $text `
        (Get-ActivationSliceCellValue $assuranceRule 'Overall section') `
        "Template $templateName.md assurance verdict" `
        $overallColumns)
      if ($overallRows.Count -ne 1) {
        $errors.Add("Template $templateName.md assurance verdict must contain exactly one row; found $($overallRows.Count)")
      }
      $scenarioRows = @(Get-MarkdownTableRows `
        $text `
        (Get-ActivationSliceCellValue $assuranceRule 'Scenario section') `
        "Template $templateName.md assurance scenarios" `
        $scenarioColumns)
      if ($scenarioRows.Count -lt 1) {
        $errors.Add("Template $templateName.md assurance scenarios require at least one row")
      }
    }
    $requiredOutcomeSections = @(
      (ConvertFrom-Utf8Base64 'IyMgS+G7i2NoIGLhuqNu')
      (ConvertFrom-Utf8Base64 'IyMgTOG7h25oIC8gQuG6sW5nIGNo4bupbmc=')
    )
    if ($templateName -ceq 'regression-report') {
      $requiredOutcomeSections += ConvertFrom-Utf8Base64 'IyMgS+G6v3QgbHXhuq1u'
    }
    $requiredOutcomeSections | ForEach-Object {
      Require-Token $text $_ "Template $templateName.md"
    }
  }

  $kbTemplatePath = Join-Path $root 'templates/kb-entry.md'
  if (-not (Test-Path $kbTemplatePath)) {
    $errors.Add('Missing shared terminal template: kb-entry.md')
  }
  else {
    $kbTemplateText = Get-Content -Raw -Encoding utf8 $kbTemplatePath
    $kbFrontMatter = [regex]::Match(
      $kbTemplateText,
      '\A---\r?\n(?<body>.*?)\r?\n---',
      [Text.RegularExpressions.RegexOptions]::Singleline
    )
    if (
      -not $kbFrontMatter.Success -or
      $kbFrontMatter.Groups['body'].Value -notmatch '(?m)^step_id:\s*<orchestrator-provided-step-id>\s*$'
    ) {
      $errors.Add('Template kb-entry.md step_id must be orchestrator-provided')
    }
    if ($kbTemplateText -notmatch [regex]::Escape('<orchestrator-provided-workflow-type>')) {
      $errors.Add('Template kb-entry.md workflow type must be orchestrator-provided')
    }
    @($runSummarySection, $terminalVerificationSection, $artifactLinksSection, $lessonsSection) | ForEach-Object {
      $null = Get-MarkdownSectionBody $kbTemplateText $_ 'Template kb-entry.md'
    }
    Test-MarkdownTableColumns `
      $kbTemplateText `
      $terminalVerificationSection `
      @('Workflow Type', 'Mode', 'Migration Unit ID', 'Terminal Verification Artifact', 'Verification Verdict', 'Completion Verdict') `
      'Template kb-entry.md'
    Test-MarkdownTableColumns `
      $kbTemplateText `
      $artifactLinksSection `
      @('Step ID', 'Artifact Path', 'Status', 'Result / Verdict') `
      'Template kb-entry.md'
    Test-MarkdownTableExactColumns `
      $kbTemplateText `
      $automationWaiversSection `
      @('Artifact', 'Stage / Check', 'Outcome', 'Category', 'Original Verdict', 'Evidence') `
      'Template kb-entry.md automation waivers'
    $kbAutomationWaivers = Get-MarkdownSectionBody `
      $kbTemplateText `
      $automationWaiversSection `
      'Template kb-entry.md automation waivers'
    @('`NOT_RUN + WAIVED`', '`environment-unavailable`', (ConvertFrom-Utf8Base64 'a2jDtG5nIGJhbyBnaeG7nQ=='), '`PASS`', '`complete`') | ForEach-Object {
      Require-Token $kbAutomationWaivers $_ 'Template kb-entry.md automation waivers'
    }
    if ($kbAutomationWaivers -match '(?i)PASS\s*\+\s*WAIVED|WAIVED\s*\+\s*PASS') {
      $errors.Add('Template kb-entry.md must not combine PASS with WAIVED')
    }
    @('Completion Verdict', 'Release Verdict', 'not-run') | ForEach-Object {
      Require-Token $kbTemplateText $_ 'Template kb-entry.md workflow-aware verdict'
    }
    if ($kbTemplateText -match '(?m)^step_id:\s*10-knowledge-base\s*$' -or $kbTemplateText -match '(?m)^- Workflow:\s*migration\s*$') {
      $errors.Add('Template kb-entry.md must not hardcode legacy migration numbering or workflow')
    }
  }

  $bootstrapReportPath = Join-Path $templateRoot 'bootstrap-report.md'
  if (Test-Path $bootstrapReportPath) {
    $bootstrapReportText = Get-Content -Raw -Encoding utf8 $bootstrapReportPath
    $bootstrapSelectedUnit = Get-MarkdownSectionBody `
      $bootstrapReportText `
      $selectedMigrationUnitSection `
      'Template bootstrap-report.md'
    Test-MarkdownTableColumns `
      $bootstrapReportText `
      $selectedMigrationUnitSection `
      @('Migration Unit ID', 'Plan Reference', 'Approval Reference', 'Bootstrap Scope') `
      'Template bootstrap-report.md'
    Require-Token $bootstrapSelectedUnit 'pending-step09-approval' 'Template bootstrap-report.md draft Selected Migration Unit'
    if ($bootstrapSelectedUnit -match '(?i)approved step-09 gate reference') {
      $errors.Add('Template bootstrap-report.md draft Selected Migration Unit preclaims approved foundation reference')
    }
    Test-MarkdownTableColumns `
      $bootstrapReportText `
      $foundationRecordSection `
      @(
        'Foundation Baseline ID', 'Source Migration Unit ID', 'Target Baseline Reference',
        'Approval Reference', 'Approval Status', 'Evidence'
      ) `
      'Template bootstrap-report.md'
    @('pending-bootstrap', 'FOUNDATION-*', 'pending-step09-approval', 'pending-approval', (ConvertFrom-Utf8Base64 'bmd1ecOqbiB04but')) | ForEach-Object {
      Require-Token $bootstrapReportText $_ 'Template bootstrap-report.md foundation lifecycle'
    }
  }

  $migrationPlanPath = Join-Path $templateRoot 'migration-plan.md'
  if (Test-Path $migrationPlanPath) {
    $migrationPlanText = Get-Content -Raw -Encoding utf8 $migrationPlanPath
    Test-MarkdownTableColumns `
      $migrationPlanText `
      $orderedUnitsSection `
      @(
        'Migration Unit ID', 'Dependencies', 'Acceptance', 'Mode Constraint', 'Bootstrap Scope', 'Foundation Baseline ID',
        'Foundation Approval Reference', 'Trace IDs', 'Approval Reference', 'Approval Status'
      ) `
      'Template migration-plan.md'
    Test-MarkdownTableColumns `
      $migrationPlanText `
      $approvedBaselinesSection `
      @(
        'Foundation Baseline ID', 'Target Baseline Reference', 'Approval Reference',
        'Approval Status', 'Evidence'
      ) `
      'Template migration-plan.md'
    $migrationUnitTable = Get-MarkdownSectionBody `
      $migrationPlanText `
      $orderedUnitsSection `
      'Template migration-plan.md'
    @('pending-bootstrap', (ConvertFrom-Utf8Base64 'Rk9VTkRBVElPTi0qIElEIMSRw6MgZHV54buHdA=='), 'not-applicable') | ForEach-Object {
      Require-Token $migrationUnitTable $_ 'Template migration-plan.md foundation lifecycle'
    }
  }
}

function Test-MarkdownTableColumns(
  [string]$Text,
  [string]$SectionName,
  [string[]]$RequiredColumns,
  [string]$Context
) {
  $sectionText = Get-MarkdownSectionBody $Text $SectionName $Context
  if ($sectionText -eq '') { return }
  $tableBlocks = @(Get-MarkdownTableBlocks $sectionText)
  if ($tableBlocks.Count -eq 0) {
    $errors.Add("$Context $SectionName missing Markdown table")
    return
  }
  $headerColumns = @(Split-MarkdownTableLine $tableBlocks[0].Lines[0])
  foreach ($requiredColumn in $RequiredColumns) {
    if ($requiredColumn -notin $headerColumns) {
      $errors.Add("$Context $SectionName table missing column: $requiredColumn")
    }
  }
}

function Test-MarkdownTableExactColumns(
  [string]$Text,
  [string]$SectionName,
  [string[]]$ExpectedColumns,
  [string]$Context
) {
  $sectionText = Get-MarkdownSectionBody $Text $SectionName $Context
  if ($sectionText -eq '') { return }

  $tableBlocks = @(Get-MarkdownTableBlocks $sectionText)
  if ($tableBlocks.Count -eq 0) {
    $errors.Add("$Context $SectionName missing Markdown table header")
    return
  }
  $actualColumns = @(Split-MarkdownTableLine $tableBlocks[0].Lines[0])
  $columnSeparator = ([char]0x001F).ToString()
  if (($actualColumns -join $columnSeparator) -cne ($ExpectedColumns -join $columnSeparator)) {
    $errors.Add("$Context $SectionName table columns must be exactly: $($ExpectedColumns -join ' | ')")
  }
}

function Split-MarkdownTableLine([string]$Line) {
  $trimmedLine = Trim-AsciiSpaceTab $Line
  if ($trimmedLine.Length -lt 2 -or $trimmedLine[0] -cne '|' -or $trimmedLine[$trimmedLine.Length - 1] -cne '|') {
    return @()
  }

  $trailingBackslashCount = 0
  for ($trailingIndex = $trimmedLine.Length - 2; $trailingIndex -ge 0 -and $trimmedLine[$trailingIndex] -ceq '\'; $trailingIndex--) {
    $trailingBackslashCount++
  }
  if (($trailingBackslashCount % 2) -eq 1) { return @() }

  $content = $trimmedLine.Substring(1, $trimmedLine.Length - 2)
  $cells = [Collections.Generic.List[string]]::new()
  $cell = [Text.StringBuilder]::new()
  $index = 0
  while ($index -lt $content.Length) {
    $character = $content[$index]
    if ($character -ceq '\') {
      $runStart = $index
      while ($index -lt $content.Length -and $content[$index] -ceq '\') { $index++ }
      $runLength = $index - $runStart
      if ($index -lt $content.Length -and $content[$index] -ceq '|') {
        for ($pair = 0; $pair -lt [Math]::Floor($runLength / 2); $pair++) {
          [void]$cell.Append([char]'\')
        }
        if (($runLength % 2) -eq 1) {
          [void]$cell.Append('|')
        }
        else {
          $cells.Add((Trim-AsciiSpaceTab $cell.ToString()))
          [void]$cell.Clear()
        }
        $index++
        continue
      }
      for ($slash = 0; $slash -lt $runLength; $slash++) {
        [void]$cell.Append([char]'\')
      }
      continue
    }
    elseif ($character -ceq '|') {
      $cells.Add((Trim-AsciiSpaceTab $cell.ToString()))
      [void]$cell.Clear()
    }
    else {
      [void]$cell.Append($character)
    }
    $index++
  }
  $cells.Add((Trim-AsciiSpaceTab $cell.ToString()))
  return @($cells)
}

function Get-ActivationSliceContractDefinition {
  $contractPath = Join-Path $root 'contracts/activation-slice.md'
  if (-not (Test-Path $contractPath)) {
    $errors.Add('Missing Activation Slice contract resource')
    return [pscustomobject]@{
      Columns = @(); Seams = @(); Applicability = @(); Dispositions = @(); Statuses = @(); ApprovalSources = @()
      IdentifierRules = @(); FieldRules = @(); RowRules = @(); FrontMatterRules = @(); LinkRules = @()
      DomainBlockerRules = @(); PlaceholderRules = @(); WaiverRules = @(); ResumeEvidenceRules = @(); ResumeStateRules = @(); NativeBlockerRules = @(); HandoffRules = @()
      BootstrapUnitRules = @(); Step10UnitRules = @(); DirectPlanFoundationRules = @()
      DownstreamUnitRules = @(); RegressionParityRules = @(); AssuranceProvenanceRules = @(); AssuranceVerdictRules = @()
      SourceReferenceRules = @(); RouterRules = @(); AsyncRules = @()
    }
  }
  $contractText = Get-Content -Raw -Encoding utf8 $contractPath
  return [pscustomobject]@{
    Columns = @(Get-ActivationSliceContractColumns $contractText)
    Seams = @(Get-ActivationSliceContractSeams $contractText)
    Applicability = @(Get-ActivationSliceContractEnumValues 'Applicability' $contractText)
    Dispositions = @(Get-ActivationSliceContractEnumValues 'Disposition' $contractText)
    Statuses = @(Get-ActivationSliceContractEnumValues 'Status' $contractText)
    ApprovalSources = @(Get-ActivationSliceContractEnumValues 'Approval source' $contractText)
    IdentifierRules = @(Get-ActivationSliceContractTableRules 'Identifier formats' $contractText)
    FieldRules = @(Get-ActivationSliceContractTableRules 'Field requirements' $contractText)
    RowRules = @(Get-ActivationSliceContractTableRules 'Legal row combinations' $contractText)
    FrontMatterRules = @(Get-ActivationSliceContractTableRules 'Completion and blocking rules' $contractText)
    DomainBlockerRules = @(Get-ActivationSliceContractTableRules 'Domain-blocker evidence' $contractText)
    PlaceholderRules = @(Get-ActivationSliceContractTableRules 'Placeholder value semantics' $contractText)
    WaiverRules = @(Get-ActivationSliceContractTableRules 'Step 10 baseline-waiver resume' $contractText)
    ResumeEvidenceRules = @(Get-ActivationSliceContractTableRules 'Step 10 resume evidence' $contractText)
    ResumeStateRules = @(Get-ActivationSliceContractTableRules 'Step 10 resume state' $contractText)
    NativeBlockerRules = @(Get-ActivationSliceContractTableRules 'Step 10 native blocker eligibility' $contractText)
    HandoffRules = @(Get-ActivationSliceContractTableRules 'Immediate predecessor roles and lifecycle' $contractText)
    BootstrapUnitRules = @(Get-ActivationSliceContractTableRules 'Bootstrap selected-unit handoff' $contractText)
    Step10UnitRules = @(Get-ActivationSliceContractTableRules 'Step 10 predecessor unit selection' $contractText)
    DirectPlanFoundationRules = @(Get-ActivationSliceContractTableRules 'Direct-plan foundation state' $contractText)
    DownstreamUnitRules = @(Get-ActivationSliceContractTableRules 'Downstream selected-unit handoff' $contractText)
    RegressionParityRules = @(Get-ActivationSliceContractTableRules 'Regression parity handoff' $contractText)
    AssuranceProvenanceRules = @(Get-ActivationSliceContractTableRules 'Assurance task provenance handoff' $contractText)
    AssuranceVerdictRules = @(Get-ActivationSliceContractTableRules 'Assurance verdict consistency' $contractText)
    SourceReferenceRules = @(Get-ActivationSliceContractTableRules 'Source Reference enrichment' $contractText)
    LinkRules = @(Get-ActivationSliceImplementationLinkRules $contractText)
    RouterRules = @(Get-ActivationSliceRouterRules $contractText)
    AsyncRules = @(Get-ActivationSliceAsyncRules $contractText)
  }
}

function Get-MarkdownTableBlocks([string]$SectionText) {
  $sectionLineStates = @(Get-MarkdownLineStates $SectionText)
  $tableBlocks = [Collections.Generic.List[object]]::new()
  $currentTable = [Collections.Generic.List[string]]::new()
  foreach ($lineState in $sectionLineStates) {
    $line = $lineState.Text
    if ($lineState.Excluded) {
      if ($currentTable.Count -gt 0) {
        $tableBlocks.Add([pscustomobject]@{ Lines = @($currentTable) })
        $currentTable = [Collections.Generic.List[string]]::new()
      }
      continue
    }

    if ($line -match '^[ ]{0,3}\|.*\|[ \t]*$') {
      $currentTable.Add($line)
    }
    elseif ($currentTable.Count -gt 0) {
      $tableBlocks.Add([pscustomobject]@{ Lines = @($currentTable) })
      $currentTable = [Collections.Generic.List[string]]::new()
    }
  }
  if ($currentTable.Count -gt 0) {
    $tableBlocks.Add([pscustomobject]@{ Lines = @($currentTable) })
  }
  return @($tableBlocks)
}

function Get-MarkdownTableRows(
  [string]$Text,
  [string]$SectionName,
  [string]$Context,
  [string[]]$ExpectedColumns = @()
) {
  $sectionText = Get-MarkdownSectionBody $Text $SectionName $Context
  if ($sectionText -eq '') { return @() }

  $tableBlocks = @(Get-MarkdownTableBlocks $sectionText)

  $tableLines = @()
  if ($ExpectedColumns.Count -gt 0) {
    $columnSeparator = ([char]0x001F).ToString()
    $expectedHeader = $ExpectedColumns -join $columnSeparator
    $matchingTables = @(
      $tableBlocks |
        Where-Object {
          $candidateHeader = @(Split-MarkdownTableLine $_.Lines[0])
          ($candidateHeader -join $columnSeparator) -ceq $expectedHeader
        }
    )
    $overlappingNonCanonicalTables = @(
      $tableBlocks |
        Where-Object {
          $candidateHeader = @(Split-MarkdownTableLine $_.Lines[0])
          $isCanonical = ($candidateHeader -join $columnSeparator) -ceq $expectedHeader
          $overlapCount = @($candidateHeader | Where-Object { $ExpectedColumns -ccontains $_ }).Count
          -not $isCanonical -and $overlapCount -gt 0
        }
    )
    if ($overlappingNonCanonicalTables.Count -gt 0) {
      $errors.Add("$Context structured section contains additional overlapping record table")
    }
    if ($matchingTables.Count -ne 1) {
      $errors.Add("$Context canonical Activation Slice table must appear exactly once; found $($matchingTables.Count)")
      return @()
    }
    if ($overlappingNonCanonicalTables.Count -gt 0) { return @() }
    $tableLines = @($matchingTables[0].Lines)
  }
  elseif ($tableBlocks.Count -gt 0) {
    $tableLines = @($tableBlocks[0].Lines)
  }

  if ($tableLines.Count -lt 2) {
    $errors.Add("$Context missing Markdown table")
    return @()
  }

  $header = @(Split-MarkdownTableLine $tableLines[0])
  $delimiter = @(Split-MarkdownTableLine $tableLines[1])
  if ($delimiter.Count -ne $header.Count) {
    $errors.Add("$Context canonical Activation Slice table delimiter has $($delimiter.Count) cells; expected $($header.Count)")
    return @()
  }
  $validDelimiterCells = @($delimiter | Where-Object { $_ -cmatch '^:?-{3,}:?$' })
  if ($validDelimiterCells.Count -ne $delimiter.Count) {
    if ($validDelimiterCells.Count -eq 0) {
      $errors.Add("$Context canonical Activation Slice table delimiter must immediately follow its header")
    }
    else {
      $errors.Add("$Context canonical Activation Slice table delimiter has invalid Markdown syntax")
    }
    return @()
  }

  $rows = [Collections.Generic.List[object]]::new()
  foreach ($line in $tableLines | Select-Object -Skip 2) {
    $cells = @(Split-MarkdownTableLine $line)
    if ($cells.Count -ne $header.Count) {
      $errors.Add("$Context row has $($cells.Count) cells; expected $($header.Count): $line")
      continue
    }

    $record = [ordered]@{}
    for ($index = 0; $index -lt $header.Count; $index++) {
      $record[$header[$index]] = $cells[$index]
    }
    $rows.Add([pscustomobject]$record)
  }
  return @($rows)
}

function Get-ActivationSliceImplementationLinkRules([string]$ContractText) {
  $context = 'Activation Slice implementation linkage contract'
  $sectionName = 'Implementation linkage'
  $sectionCount = @(Get-MarkdownSectionHeadings $ContractText $sectionName).Count
  if ($sectionCount -ne 1) {
    $errors.Add("$context section must appear exactly once; found $sectionCount")
    return @()
  }

  $sectionText = Get-MarkdownSectionBody $ContractText $sectionName $context
  $tableBlocks = @(Get-MarkdownTableBlocks $sectionText)
  $expectedColumns = @('Record', 'Current step ID', 'Allowed predecessor step IDs', 'Section', 'Required columns')
  $columnSeparator = ([char]0x001F).ToString()
  $expectedHeader = $expectedColumns -join $columnSeparator
  $matchingTables = @($tableBlocks | Where-Object {
    (@(Split-MarkdownTableLine $_.Lines[0]) -join $columnSeparator) -ceq $expectedHeader
  })
  if ($tableBlocks.Count -ne 1 -or $matchingTables.Count -ne 1) {
    $errors.Add("$context rule table must appear exactly once; found $($tableBlocks.Count)")
    return @()
  }

  $rows = @(Get-MarkdownTableRows $ContractText $sectionName $context $expectedColumns)
  foreach ($recordName in @('selected-unit', 'changed-file', 'test-evidence')) {
    $recordCount = @($rows | Where-Object {
      (Get-ActivationSliceCellValue $_ 'Record') -ceq $recordName
    }).Count
    if ($recordCount -ne 1) {
      $errors.Add("$context must declare exactly one $recordName rule; found $recordCount")
    }
  }
  if ($rows.Count -ne 3) {
    $errors.Add("$context rule table must contain exactly three canonical rows; found $($rows.Count)")
  }
  return @($rows)
}

function Get-ActivationSliceCellValue([object]$Row, [string]$Column) {
  $value = Trim-AsciiSpaceTab ([string]$Row.$Column)
  $leadingTicks = 0
  while ($leadingTicks -lt $value.Length -and $value[$leadingTicks] -ceq '`') { $leadingTicks++ }
  $trailingTicks = 0
  while (
    $trailingTicks -lt ($value.Length - $leadingTicks) -and
    $value[$value.Length - 1 - $trailingTicks] -ceq '`'
  ) { $trailingTicks++ }
  if ($leadingTicks -eq 0 -and $trailingTicks -eq 0) { return $value }
  if ($leadingTicks -ne $trailingTicks -or ($leadingTicks + $trailingTicks) -ge $value.Length) {
    return $value
  }
  $delimiter = '`' * $leadingTicks
  $body = $value.Substring($leadingTicks, $value.Length - $leadingTicks - $trailingTicks)
  if ($body.IndexOf($delimiter, [StringComparison]::Ordinal) -ge 0) { return $value }
  if (
    $body.Length -ge 2 -and
    $body[0] -ceq ' ' -and
    $body[$body.Length - 1] -ceq ' ' -and
    $body.Trim(' ').Length -gt 0
  ) {
    return $body.Substring(1, $body.Length - 2)
  }
  return $body
}

function Get-CaseSensitiveUniqueStrings([object[]]$Values) {
  $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  $result = [Collections.Generic.List[string]]::new()
  foreach ($value in $Values) {
    $text = [string]$value
    if ($seen.Add($text)) { $result.Add($text) }
  }
  return @($result)
}

function New-ActivationSliceArtifactState {
  return [pscustomobject]@{
    Slices = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    Order = @()
    Text = ''
    FrontMatter = [pscustomobject]@{
      StepId = ''; Status = ''; Result = ''; ApprovalSource = ''; ApprovalSourceCount = 0
      TopLevelKeys = @()
      Waiver = [ordered]@{}; WaiverKeys = @(); WaiverBlockCount = 0; WaiverIsValid = $false
    }
    HasBlockingErrors = $false
    LinkBlockingErrorCount = 0
  }
}

function Get-ActivationSliceIdentifierPattern([object]$Definition, [string]$Identifier) {
  $rule = @($Definition.IdentifierRules | Where-Object {
    (Get-ActivationSliceCellValue $_ 'Identifier') -ceq $Identifier
  })
  if ($rule.Count -ne 1) { return '' }
  return Get-ActivationSliceCellValue $rule[0] 'Required format'
}

function ConvertFrom-ActivationSliceYamlKey([string]$Token) {
  $trimmed = Trim-AsciiSpaceTab $Token
  if (
    $trimmed.Length -gt 0 -and
    ([char]::IsWhiteSpace($trimmed[0]) -or [char]::IsWhiteSpace($trimmed[$trimmed.Length - 1]))
  ) {
    return [pscustomobject]@{ IsValid = $false; Value = '' }
  }
  if ($trimmed -cmatch '^[A-Za-z_][A-Za-z0-9_-]*$') {
    return [pscustomobject]@{ IsValid = $true; Value = $trimmed }
  }
  $singleQuoted = [regex]::Match($trimmed, "^'(?<value>(?:[^']|'')*)'$", [Text.RegularExpressions.RegexOptions]::CultureInvariant)
  if ($singleQuoted.Success) {
    $decoded = $singleQuoted.Groups['value'].Value.Replace("''", "'")
    if ($decoded -cnotmatch '^[A-Za-z_][A-Za-z0-9_-]*$') {
      return [pscustomobject]@{ IsValid = $false; Value = '' }
    }
    return [pscustomobject]@{
      IsValid = $true
      Value = $decoded
    }
  }
  if ($trimmed.StartsWith('"', [StringComparison]::Ordinal)) {
    if (-not $trimmed.EndsWith('"', [StringComparison]::Ordinal)) {
      return [pscustomobject]@{ IsValid = $false; Value = '' }
    }
    try {
      $decoded = ConvertFrom-Json -InputObject $trimmed -ErrorAction Stop
      if ($decoded -isnot [string] -or $decoded -cnotmatch '^[A-Za-z_][A-Za-z0-9_-]*$') {
        return [pscustomobject]@{ IsValid = $false; Value = '' }
      }
      return [pscustomobject]@{ IsValid = $true; Value = $decoded }
    }
    catch {
      return [pscustomobject]@{ IsValid = $false; Value = '' }
    }
  }
  return [pscustomobject]@{ IsValid = $false; Value = '' }
}

function ConvertFrom-ActivationSliceYamlInlineScalar([string]$Token) {
  $trimmed = Trim-AsciiSpaceTab $Token
  if (
    $trimmed.Length -gt 0 -and
    ([char]::IsWhiteSpace($trimmed[0]) -or [char]::IsWhiteSpace($trimmed[$trimmed.Length - 1]))
  ) {
    return [pscustomobject]@{ IsValid = $false; Value = $null }
  }
  if ($trimmed -eq '' -or $trimmed -ceq '~' -or $trimmed -cmatch '^(?i:null)$') {
    return [pscustomobject]@{ IsValid = $true; Value = $null }
  }
  $singleQuoted = [regex]::Match($trimmed, "^'(?<value>(?:[^']|'')*)'$", [Text.RegularExpressions.RegexOptions]::CultureInvariant)
  if ($singleQuoted.Success) {
    return [pscustomobject]@{
      IsValid = $true
      Value = $singleQuoted.Groups['value'].Value.Replace("''", "'")
    }
  }
  if (
    $trimmed.StartsWith("'", [StringComparison]::Ordinal) -or
    $trimmed.EndsWith("'", [StringComparison]::Ordinal)
  ) {
    return [pscustomobject]@{ IsValid = $false; Value = $null }
  }
  if ($trimmed.StartsWith('"', [StringComparison]::Ordinal)) {
    if (-not $trimmed.EndsWith('"', [StringComparison]::Ordinal)) {
      return [pscustomobject]@{ IsValid = $false; Value = $null }
    }
    try {
      $decoded = ConvertFrom-Json -InputObject $trimmed -ErrorAction Stop
      if ($decoded -isnot [string]) {
        return [pscustomobject]@{ IsValid = $false; Value = $null }
      }
      return [pscustomobject]@{ IsValid = $true; Value = $decoded }
    }
    catch {
      return [pscustomobject]@{ IsValid = $false; Value = $null }
    }
  }
  if ($trimmed.EndsWith('"', [StringComparison]::Ordinal)) {
    return [pscustomobject]@{ IsValid = $false; Value = $null }
  }
  $reservedStarts = @('-', '?', ':', ',', '[', ']', '{', '}', '#', '&', '*', '!', '|', '>', '%', '@', '`')
  if (
    $reservedStarts -ccontains [string]$trimmed[0] -or
    $trimmed -match '(?:^|[ \t])#' -or
    $trimmed -match ':(?:[ \t]|$)'
  ) {
    return [pscustomobject]@{ IsValid = $false; Value = $null }
  }
  return [pscustomobject]@{ IsValid = $true; Value = $trimmed }
}

function ConvertFrom-ActivationSliceRestrictedYaml([string]$FrontMatter) {
  $lines = @($FrontMatter -split '\r?\n')
  $topLevelEntries = [Collections.Generic.List[object]]::new()
  $waiverMappings = [Collections.Generic.List[object]]::new()
  $isValid = $true
  $lineIndex = 0
  while ($lineIndex -lt $lines.Count) {
    $line = $lines[$lineIndex]
    if ($line -cmatch '^[ \t]*$' -or $line -cmatch '^[ \t]*#') {
      $lineIndex++
      continue
    }
    if ($line -match '^[ \t]') {
      $isValid = $false
      $lineIndex++
      continue
    }
    $entryMatch = [regex]::Match(
      $line,
      '^(?<key>.+?)[ \t]*:(?:[ \t]+(?<value>.*)|(?<value>))$',
      [Text.RegularExpressions.RegexOptions]::CultureInvariant
    )
    if (-not $entryMatch.Success) {
      $isValid = $false
      $lineIndex++
      continue
    }
    $key = ConvertFrom-ActivationSliceYamlKey $entryMatch.Groups['key'].Value
    if (-not $key.IsValid) {
      $isValid = $false
      $lineIndex++
      continue
    }
    $rawValue = $entryMatch.Groups['value'].Value
    $topLevelEntry = [pscustomobject]@{ Key = $key.Value; Value = $null }
    $topLevelEntries.Add($topLevelEntry)

    if ($key.Value -cne 'waiver') {
      $scalar = ConvertFrom-ActivationSliceYamlInlineScalar $rawValue
      if ($scalar.IsValid) {
        $topLevelEntry.Value = $scalar.Value
      }
      else {
        $isValid = $false
      }
      $lineIndex++
      continue
    }

    $waiverValues = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    $waiverKeys = [Collections.Generic.List[string]]::new()
    $waiverIsValid = (Trim-AsciiSpaceTab $rawValue) -ceq ''
    $lineIndex++
    while ($lineIndex -lt $lines.Count) {
      $waiverLine = $lines[$lineIndex]
      if ($waiverLine -cmatch '^[ \t]*$' -or $waiverLine -cmatch '^[ \t]*#') {
        $lineIndex++
        continue
      }
      if ($waiverLine -notmatch '^[ \t]') { break }
      if ($waiverLine -match '^[ ]*\t') {
        $waiverIsValid = $false
        $isValid = $false
        $lineIndex++
        continue
      }
      $fieldMatch = [regex]::Match(
        $waiverLine,
        '^  (?! )(?<key>.+?)[ \t]*:(?:[ \t]+(?<value>.*)|(?<value>))$',
        [Text.RegularExpressions.RegexOptions]::CultureInvariant
      )
      if (-not $fieldMatch.Success) {
        $waiverIsValid = $false
        $isValid = $false
        $lineIndex++
        continue
      }
      $waiverKey = ConvertFrom-ActivationSliceYamlKey $fieldMatch.Groups['key'].Value
      if (-not $waiverKey.IsValid -or $waiverKeys -ccontains $waiverKey.Value) {
        $waiverIsValid = $false
        $isValid = $false
        $lineIndex++
        continue
      }

      $waiverRawValue = Trim-AsciiSpaceTab $fieldMatch.Groups['value'].Value
      $decodedValue = $null
      if ($waiverRawValue -cmatch '^\|(?<chomp>[-+]?)$') {
        $chomp = $Matches.chomp
        $blockLines = [Collections.Generic.List[string]]::new()
        $lineIndex++
        while ($lineIndex -lt $lines.Count) {
          $blockLine = $lines[$lineIndex]
          if ([string]::IsNullOrWhiteSpace($blockLine)) {
            $blockLines.Add('')
            $lineIndex++
            continue
          }
          if ($blockLine -match '^  (?! )') { break }
          if ($blockLine -notmatch '^[ \t]') { break }
          if ($blockLine -notmatch '^    ') {
            $waiverIsValid = $false
            $isValid = $false
            $lineIndex++
            continue
          }
          $blockLines.Add($blockLine.Substring(4))
          $lineIndex++
        }
        $rawBlockValue = ($blockLines -join "`n") + "`n"
        $trimmedBlockValue = $rawBlockValue.TrimEnd([char[]]"`r`n")
        $decodedValue = switch -CaseSensitive ($chomp) {
          '-' { $trimmedBlockValue }
          '+' { $rawBlockValue }
          default { $trimmedBlockValue + "`n" }
        }
      }
      else {
        $scalar = ConvertFrom-ActivationSliceYamlInlineScalar $waiverRawValue
        if ($scalar.IsValid) {
          $decodedValue = $scalar.Value
        }
        else {
          $waiverIsValid = $false
          $isValid = $false
        }
        $lineIndex++
      }
      $waiverKeys.Add($waiverKey.Value)
      $waiverValues[$waiverKey.Value] = $decodedValue
    }
    $waiverMappings.Add([pscustomobject]@{
      IsValid = $waiverIsValid
      Values = $waiverValues
      Keys = @($waiverKeys)
    })
  }

  return [pscustomobject]@{
    IsValid = $isValid
    TopLevelEntries = @($topLevelEntries)
    WaiverMappings = @($waiverMappings)
  }
}

function Get-ActivationSliceFrontMatter(
  [string]$Text,
  [string]$Context,
  [bool]$RequireArtifactFields = $true
) {
  $match = [regex]::Match(
    $Text,
    '\A---\r?\n(?<frontMatter>.*?)\r?\n---(?=\r?\n|\z)',
    [Text.RegularExpressions.RegexOptions]::Singleline
  )
  if (-not $match.Success) {
    $errors.Add("$Context missing YAML front matter")
    return [pscustomobject]@{
      StepId = ''; Status = ''; Result = ''; ApprovalSource = ''; ApprovalSourceCount = 0
      TopLevelKeys = @()
      Waiver = [ordered]@{}; WaiverKeys = @(); WaiverBlockCount = 0; WaiverIsValid = $false
    }
  }

  $decoded = ConvertFrom-ActivationSliceRestrictedYaml $match.Groups['frontMatter'].Value
  $topLevelValues = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
  $topLevelCounts = [Collections.Generic.Dictionary[string,int]]::new([StringComparer]::Ordinal)
  $topLevelKeys = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  $frontMatterIsValid = $decoded.IsValid
  foreach ($entry in $decoded.TopLevelEntries) {
    if (-not $topLevelKeys.Add($entry.Key)) {
      $frontMatterIsValid = $false
      $errors.Add("$Context duplicate top-level YAML key: $($entry.Key)")
    }
    if (-not $topLevelCounts.ContainsKey($entry.Key)) { $topLevelCounts[$entry.Key] = 0 }
    $topLevelCounts[$entry.Key]++
    if ($entry.Key -cin @('status', 'result', 'step_id', 'approval_source', 'produced_at')) {
      if ($null -eq $entry.Value -or [string]::IsNullOrWhiteSpace([string]$entry.Value)) {
        $frontMatterIsValid = $false
      }
      $topLevelValues[$entry.Key] = [string]$entry.Value
    }
  }

  if ($RequireArtifactFields) {
    foreach ($field in @('status', 'result', 'step_id', 'produced_at')) {
      $count = if ($topLevelCounts.ContainsKey($field)) { [int]$topLevelCounts[$field] } else { 0 }
      if ($count -ne 1) { $errors.Add("$Context front matter must contain exactly one $field") }
    }
  }
  $stepIdCount = if ($topLevelCounts.ContainsKey('step_id')) { [int]$topLevelCounts['step_id'] } else { 0 }
  $approvalSourceCount = if ($topLevelCounts.ContainsKey('approval_source')) { [int]$topLevelCounts['approval_source'] } else { 0 }
  foreach ($field in @('status', 'result', 'step_id', 'approval_source', 'produced_at', 'waiver')) {
    if ($topLevelCounts.ContainsKey($field) -and [int]$topLevelCounts[$field] -gt 1) {
      $frontMatterIsValid = $false
    }
  }
  if (-not $frontMatterIsValid) {
    $errors.Add("$Context invalid or ambiguous YAML front matter")
  }

  $waiverMapping = if ($decoded.WaiverMappings.Count -eq 1) {
    $decoded.WaiverMappings[0]
  }
  else {
    [pscustomobject]@{
      IsValid = $false
      Values = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
      Keys = @()
    }
  }
  return [pscustomobject]@{
    StepId = if ($stepIdCount -eq 1) { [string]$topLevelValues['step_id'] } else { '' }
    Status = if ($topLevelCounts.ContainsKey('status') -and $topLevelCounts['status'] -eq 1) { [string]$topLevelValues['status'] } else { '' }
    Result = if ($topLevelCounts.ContainsKey('result') -and $topLevelCounts['result'] -eq 1) { [string]$topLevelValues['result'] } else { '' }
    ApprovalSource = if ($approvalSourceCount -eq 1) { [string]$topLevelValues['approval_source'] } else { '' }
    ApprovalSourceCount = $approvalSourceCount
    TopLevelKeys = @($decoded.TopLevelEntries | ForEach-Object { $_.Key })
    Waiver = $waiverMapping.Values
    WaiverKeys = @($waiverMapping.Keys)
    WaiverBlockCount = $decoded.WaiverMappings.Count
    WaiverIsValid = $waiverMapping.IsValid
  }
}

function Test-ActivationSliceExactBaselineWaiver(
  [object]$FrontMatter,
  [object]$Definition
) {
  $rules = @($Definition.WaiverRules)
  if ($rules.Count -eq 0) { return $false }
  if ($FrontMatter.WaiverBlockCount -ne 1 -or -not $FrontMatter.WaiverIsValid) { return $false }

  $expectedWaiverKeys = @(
    $rules |
      ForEach-Object { Get-ActivationSliceCellValue $_ 'Field' } |
      Where-Object { $_.StartsWith('waiver.', [StringComparison]::Ordinal) } |
      ForEach-Object { $_.Substring('waiver.'.Length) }
  )
  $actualWaiverKeys = @($FrontMatter.WaiverKeys)
  if ($actualWaiverKeys.Count -ne $expectedWaiverKeys.Count) { return $false }
  foreach ($expectedWaiverKey in $expectedWaiverKeys) {
    if ($actualWaiverKeys -cnotcontains $expectedWaiverKey) { return $false }
  }

  foreach ($rule in $rules) {
    $field = Get-ActivationSliceCellValue $rule 'Field'
    $requiredValue = Get-ActivationSliceCellValue $rule 'Required value'
    $actualValue = switch -CaseSensitive ($field) {
      'step_id' { $FrontMatter.StepId }
      'status' { $FrontMatter.Status }
      'result' { $FrontMatter.Result }
      'approval_source' {
        if ($FrontMatter.ApprovalSourceCount -eq 1) { $FrontMatter.ApprovalSource } else { '' }
      }
      default {
        if ($field.StartsWith('waiver.', [StringComparison]::Ordinal)) {
          $waiverKey = $field.Substring('waiver.'.Length)
          [string]$FrontMatter.Waiver[$waiverKey]
        }
        else { '' }
      }
    }
    if ($requiredValue -ceq '<non-empty>') {
      if ([string]::IsNullOrWhiteSpace($actualValue)) { return $false }
    }
    elseif ([string]$actualValue -cne $requiredValue) {
      return $false
    }
  }
  return $true
}

function Test-ActivationSliceWaiverPreserved(
  [object]$CurrentFrontMatter,
  [object]$PredecessorFrontMatter
) {
  if (
    $CurrentFrontMatter.WaiverBlockCount -ne 1 -or
    $PredecessorFrontMatter.WaiverBlockCount -ne 1 -or
    -not $CurrentFrontMatter.WaiverIsValid -or
    -not $PredecessorFrontMatter.WaiverIsValid
  ) {
    return $false
  }
  $currentKeys = @($CurrentFrontMatter.WaiverKeys)
  $predecessorKeys = @($PredecessorFrontMatter.WaiverKeys)
  if ($currentKeys.Count -ne $predecessorKeys.Count) { return $false }
  foreach ($key in $predecessorKeys) {
    if ($currentKeys -cnotcontains $key) { return $false }
    if ([string]$CurrentFrontMatter.Waiver[$key] -cne [string]$PredecessorFrontMatter.Waiver[$key]) {
      return $false
    }
  }
  return $true
}

function Get-ActivationSliceResumeEvidenceRule(
  [object]$Definition,
  [string]$Record,
  [string]$Context
) {
  $rules = @($Definition.ResumeEvidenceRules | Where-Object {
    (Get-ActivationSliceCellValue $_ 'Record') -ceq $Record
  })
  if ($rules.Count -ne 1) {
    $errors.Add("$Context resume contract must declare exactly one $Record record; found $($rules.Count)")
    return $null
  }
  return $rules[0]
}

function Get-ActivationSliceResumeTableRow(
  [string]$Text,
  [string]$Role,
  [object]$Rule,
  [string]$Context
) {
  $record = Get-ActivationSliceCellValue $Rule 'Record'
  $section = Get-ActivationSliceCellValue $Rule 'Section'
  $columns = @(
    (Get-ActivationSliceCellValue $Rule 'Required columns or fields').Split(',') |
      ForEach-Object { $_.Trim() } |
      Where-Object { $_ -ne '' }
  )
  $sectionCount = @(Get-MarkdownSectionHeadings $Text $section).Count
  if ($sectionCount -ne 1) {
    $errors.Add("$Context resume $Role $section section must appear exactly once; found $sectionCount")
    return $null
  }
  $sectionText = Get-MarkdownSectionBody $Text $section "$Context resume $Role $section"
  $tableCount = @(Get-MarkdownTableBlocks $sectionText).Count
  if ($tableCount -ne 1) {
    $errors.Add("$Context resume $Role $record table must appear exactly once; found $tableCount")
    return $null
  }
  $rows = @(Get-MarkdownTableRows $Text $section "$Context resume $Role $record" $columns)
  if ($rows.Count -ne 1) {
    $errors.Add("$Context resume $Role $record record must contain exactly one row; found $($rows.Count)")
    return $null
  }
  foreach ($column in $columns) {
    if ([string]::IsNullOrWhiteSpace((Get-ActivationSliceCellValue $rows[0] $column))) {
      $errors.Add("$Context resume $Role $record record requires non-empty $column")
    }
  }
  return $rows[0]
}

function Get-ActivationSliceResumeWaiverBody(
  [string]$Text,
  [string]$Role,
  [object]$Rule,
  [string]$Context
) {
  $section = Get-ActivationSliceCellValue $Rule 'Section'
  $sectionCount = @(Get-MarkdownSectionHeadings $Text $section).Count
  if ($sectionCount -ne 1) {
    $errors.Add("$Context resume $Role $section section must appear exactly once; found $sectionCount")
    return $null
  }
  $sectionText = Get-MarkdownSectionBody $Text $section "$Context resume $Role $section"
  $yamlRecords = @(Get-MarkdownFencedCodeBlocks $sectionText | Where-Object { $_.Info -ceq 'yaml' })
  if ($yamlRecords.Count -ne 1) {
    $errors.Add("$Context resume $Role approved-waiver YAML record must appear exactly once; found $($yamlRecords.Count)")
    return $null
  }
  $body = Get-ActivationSliceFrontMatter `
    ("---`n" + $yamlRecords[0].Body.TrimEnd([char[]]"`r`n") + "`n---") `
    "$Context resume $Role approved-waiver body" `
    $false
  $expectedTopLevelKeys = @('status', 'result', 'approval_source', 'waiver')
  if (
    $body.TopLevelKeys.Count -ne $expectedTopLevelKeys.Count -or
    (@($body.TopLevelKeys | Where-Object { $expectedTopLevelKeys -cnotcontains $_ }).Count -gt 0)
  ) {
    $errors.Add("$Context resume $Role approved-waiver body fields must be exactly: $($expectedTopLevelKeys -join ', ')")
  }
  return $body
}

function Test-ActivationSliceEvidenceNamesExactValue([string]$Evidence, [string]$Value) {
  if ([string]::IsNullOrWhiteSpace($Evidence) -or [string]::IsNullOrWhiteSpace($Value)) { return $false }
  $pattern = "(?<![A-Za-z0-9_-])$([regex]::Escape($Value))(?![A-Za-z0-9_-])"
  return [regex]::IsMatch(
    $Evidence,
    $pattern,
    [Text.RegularExpressions.RegexOptions]::CultureInvariant
  )
}

function Test-ActivationSliceResumeWaiverBodyMatches(
  [object]$Body,
  [object]$FrontMatter
) {
  return (
    $null -ne $Body -and
    $Body.Status -ceq $FrontMatter.Status -and
    $Body.Result -ceq $FrontMatter.Result -and
    $Body.ApprovalSourceCount -eq 1 -and
    $FrontMatter.ApprovalSourceCount -eq 1 -and
    $Body.ApprovalSource -ceq $FrontMatter.ApprovalSource -and
    (Test-ActivationSliceWaiverPreserved $Body $FrontMatter)
  )
}

function Test-ActivationSliceNativeBlockerEligibility(
  [object]$Row,
  [object]$FrontMatter,
  [object]$Definition,
  [string]$Context
) {
  if ($null -eq $Row) { return }
  $rules = @($Definition.NativeBlockerRules)
  if ($rules.Count -ne 5) {
    $errors.Add("$Context resume contract must declare the canonical native-blocker eligibility fields")
    return
  }
  $isEligible = $true
  foreach ($rule in $rules) {
    $field = Get-ActivationSliceCellValue $rule 'Field'
    $expected = Get-ActivationSliceCellValue $rule 'Required value'
    if ($expected -ceq 'exact waiver.evidence') { $expected = [string]$FrontMatter.Waiver['evidence'] }
    if ((Get-ActivationSliceCellValue $Row $field) -cne $expected) { $isEligible = $false }
  }
  if (-not $isEligible) {
    $errors.Add("$Context resume native-blocker record violates canonical baseline-resume eligibility")
  }
}

function Test-ActivationSliceConsumedResumeState(
  [object]$StateRow,
  [object]$Artifact,
  [object]$SelectedUnit,
  [object]$Definition,
  [string]$Context
) {
  if ($null -eq $StateRow -or $null -eq $SelectedUnit) { return }
  $rules = @($Definition.ResumeStateRules | Where-Object {
    (Get-ActivationSliceCellValue $_ 'Artifact role') -ceq 'current'
  })
  if ($rules.Count -ne 1) {
    $errors.Add("$Context resume contract must declare exactly one current state row")
    return
  }
  $rule = $rules[0]
  $shapeValid =
    (Get-ActivationSliceCellValue $StateRow 'Resume Phase') -ceq (Get-ActivationSliceCellValue $rule 'Resume Phase') -and
    (Get-ActivationSliceCellValue $StateRow 'Baseline Action') -ceq (Get-ActivationSliceCellValue $rule 'Baseline Action') -and
    -not [string]::IsNullOrWhiteSpace((Get-ActivationSliceCellValue $StateRow 'Implementation Status')) -and
    (Get-ActivationSliceCellValue $StateRow 'Implementation Status') -cne 'blocked'
  if (-not $shapeValid) { $errors.Add("$Context resume current state must match the canonical current row") }
  if ((Get-ActivationSliceCellValue $StateRow 'Waiver Evidence') -cne [string]$Artifact.FrontMatter.Waiver['evidence']) {
    $errors.Add("$Context resume state Waiver Evidence must equal waiver.evidence ordinally")
  }
  $targetEvidence = Get-ActivationSliceCellValue $StateRow 'Target Mutation Evidence'
  $selectedUnitId = Get-ActivationSliceCellValue $SelectedUnit 'Migration Unit ID'
  $selectedTraceIds = @(
    (Get-ActivationSliceCellValue $SelectedUnit 'Trace IDs').Split(',') |
      ForEach-Object { $_.Trim() } |
      Where-Object { $_ -ne '' }
  )
  $hasSelectedTrace = @($selectedTraceIds | Where-Object {
    Test-ActivationSliceEvidenceNamesExactValue $targetEvidence $_
  }).Count -gt 0
  if (
    -not (Test-ActivationSliceEvidenceNamesExactValue $targetEvidence $selectedUnitId) -or
    -not $hasSelectedTrace
  ) {
    $errors.Add("$Context resume target mutation evidence must name selected Migration Unit ID and Trace ID")
  }
}

function Test-ActivationSliceStep10ResumeEvidence(
  [object]$Artifact,
  [object]$Predecessor,
  [object]$CurrentSelectedUnit,
  [object]$PredecessorSelectedUnit,
  [string[]]$SelectedUnitColumns,
  [object]$Definition,
  [string]$Context
) {
  [void](Test-ActivationSliceSelectedUnitIntrinsicState $CurrentSelectedUnit $Definition $Context)
  [void](Test-ActivationSliceSelectedUnitIntrinsicState $PredecessorSelectedUnit $Definition $Context)
  $nativeRule = Get-ActivationSliceResumeEvidenceRule $Definition 'native-blocker' $Context
  $waiverBodyRule = Get-ActivationSliceResumeEvidenceRule $Definition 'approved-waiver-body' $Context
  $stateRule = Get-ActivationSliceResumeEvidenceRule $Definition 'resume-state' $Context
  if ($null -eq $nativeRule -or $null -eq $waiverBodyRule -or $null -eq $stateRule) { return }

  $predecessorImplementationSectionCount = @(
    $Definition.LinkRules |
      Where-Object { (Get-ActivationSliceCellValue $_ 'Record') -cne 'selected-unit' } |
      Where-Object {
        @(Get-MarkdownSectionHeadings $Predecessor.Text (Get-ActivationSliceCellValue $_ 'Section')).Count -gt 0
      }
  ).Count
  if ($predecessorImplementationSectionCount -gt 0) {
    $errors.Add("$Context resume predecessor must not contain implementation evidence before re-entry")
  }

  $currentNative = Get-ActivationSliceResumeTableRow $Artifact.Text 'current' $nativeRule $Context
  $predecessorNative = Get-ActivationSliceResumeTableRow $Predecessor.Text 'predecessor' $nativeRule $Context
  Test-ActivationSliceNativeBlockerEligibility $currentNative $Artifact.FrontMatter $Definition $Context
  Test-ActivationSliceNativeBlockerEligibility $predecessorNative $Predecessor.FrontMatter $Definition $Context
  if ($null -ne $currentNative -and $null -ne $predecessorNative) {
    $nativeColumns = @(
      (Get-ActivationSliceCellValue $nativeRule 'Required columns or fields').Split(',') |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne '' }
    )
    $nativeChanged = @($nativeColumns | Where-Object {
      (Get-ActivationSliceCellValue $currentNative $_) -cne
        (Get-ActivationSliceCellValue $predecessorNative $_)
    }).Count -gt 0
    if ($nativeChanged) {
      $errors.Add("$Context resume native-blocker record must match predecessor ordinally")
    }
  }

  $currentWaiverBody = Get-ActivationSliceResumeWaiverBody $Artifact.Text 'current' $waiverBodyRule $Context
  $predecessorWaiverBody = Get-ActivationSliceResumeWaiverBody $Predecessor.Text 'predecessor' $waiverBodyRule $Context
  if (
    -not (Test-ActivationSliceResumeWaiverBodyMatches $currentWaiverBody $Artifact.FrontMatter) -or
    -not (Test-ActivationSliceResumeWaiverBodyMatches $predecessorWaiverBody $Predecessor.FrontMatter) -or
    -not (Test-ActivationSliceResumeWaiverBodyMatches $currentWaiverBody $predecessorWaiverBody)
  ) {
    $errors.Add("$Context resume approved-waiver body must match front matter and predecessor ordinally")
  }

  $currentState = Get-ActivationSliceResumeTableRow $Artifact.Text 'current' $stateRule $Context
  $predecessorState = Get-ActivationSliceResumeTableRow $Predecessor.Text 'predecessor' $stateRule $Context
  $currentStateRules = @($Definition.ResumeStateRules | Where-Object {
    (Get-ActivationSliceCellValue $_ 'Artifact role') -ceq 'current'
  })
  $predecessorStateRules = @($Definition.ResumeStateRules | Where-Object {
    (Get-ActivationSliceCellValue $_ 'Artifact role') -ceq 'predecessor'
  })
  if ($currentStateRules.Count -ne 1 -or $predecessorStateRules.Count -ne 1) {
    $errors.Add("$Context resume contract must declare exactly one current and predecessor state row")
    return
  }
  Test-ActivationSliceConsumedResumeState $currentState $Artifact $CurrentSelectedUnit $Definition $Context
  if ($null -ne $predecessorState) {
    $predecessorRule = $predecessorStateRules[0]
    $predecessorStateShapeValid = $true
    foreach ($field in @('Resume Phase', 'Baseline Action', 'Implementation Status', 'Target Mutation Evidence')) {
      if ((Get-ActivationSliceCellValue $predecessorState $field) -cne (Get-ActivationSliceCellValue $predecessorRule $field)) {
        $predecessorStateShapeValid = $false
      }
    }
    if (-not $predecessorStateShapeValid) {
      $errors.Add("$Context resume predecessor state must match the canonical predecessor row")
    }
    if ((Get-ActivationSliceCellValue $predecessorState 'Waiver Evidence') -cne [string]$Predecessor.FrontMatter.Waiver['evidence']) {
      $errors.Add("$Context resume predecessor state Waiver Evidence must equal waiver.evidence ordinally")
    }
  }
}

function Test-ActivationSlicePostWaiverResumePredecessor(
  [object]$Predecessor,
  [object]$Definition,
  [string]$Context
) {
  if ($Predecessor.FrontMatter.Result -cne 'partial') { return }
  $selectedUnit = Get-ActivationSliceCanonicalSelectedUnitRow `
    $Predecessor $Definition 'post-waiver predecessor' $Context
  if ($null -eq $selectedUnit) { return }
  [void](Test-ActivationSliceSelectedUnitIntrinsicState $selectedUnit $Definition $Context)
  if (
    (Get-ActivationSliceCellValue $selectedUnit 'Mode Constraint') -cne 'incremental/preserve-existing' -or
    (Get-ActivationSliceCellValue $selectedUnit 'Bootstrap Scope') -cne 'not-required'
  ) {
    $errors.Add("$Context post-waiver resume requires incremental/preserve-existing and not-required selected unit")
  }
  if (
    (Get-ActivationSliceCellValue $selectedUnit 'Baseline Reference') -cne
      [string]$Predecessor.FrontMatter.Waiver['evidence']
  ) {
    $errors.Add("$Context resume selected-unit Baseline Reference must equal waiver.evidence ordinally")
  }
  $nativeRule = Get-ActivationSliceResumeEvidenceRule $Definition 'native-blocker' $Context
  $waiverBodyRule = Get-ActivationSliceResumeEvidenceRule $Definition 'approved-waiver-body' $Context
  $stateRule = Get-ActivationSliceResumeEvidenceRule $Definition 'resume-state' $Context
  if ($null -eq $nativeRule -or $null -eq $waiverBodyRule -or $null -eq $stateRule) { return }
  $native = Get-ActivationSliceResumeTableRow `
    $Predecessor.Text 'post-waiver predecessor' $nativeRule $Context
  Test-ActivationSliceNativeBlockerEligibility `
    $native $Predecessor.FrontMatter $Definition $Context
  $waiverBody = Get-ActivationSliceResumeWaiverBody `
    $Predecessor.Text 'post-waiver predecessor' $waiverBodyRule $Context
  if (-not (Test-ActivationSliceResumeWaiverBodyMatches $waiverBody $Predecessor.FrontMatter)) {
    $errors.Add("$Context resume approved-waiver body must match front matter ordinally")
  }
  $state = Get-ActivationSliceResumeTableRow `
    $Predecessor.Text 'post-waiver predecessor' $stateRule $Context
  Test-ActivationSliceConsumedResumeState `
    $state $Predecessor $selectedUnit $Definition $Context
}

function Test-ActivationSliceImplementationPredecessorForReview(
  [object]$Predecessor,
  [object]$Definition,
  [string]$Context
) {
  $selectedUnit = Get-ActivationSliceCanonicalSelectedUnitRow `
    $Predecessor $Definition 'implementation predecessor' $Context
  if ($null -eq $selectedUnit) { return }
  [void](Test-ActivationSliceSelectedUnitIntrinsicState $selectedUnit $Definition $Context)
  Test-ActivationSliceImplementationEvidenceRecords `
    $Predecessor $Predecessor $selectedUnit $Definition $Context
}

function Test-ActivationSliceDomainBlockerAbsence(
  [object]$State,
  [object]$Definition,
  [string]$Context
) {
  $rules = @($Definition.DomainBlockerRules)
  if ($rules.Count -ne 1) { return }
  $section = Get-ActivationSliceCellValue $rules[0] 'Section'
  if (@(Get-MarkdownSectionHeadings $State.Text $section).Count -gt 0) {
    $errors.Add("$Context non-blocking lifecycle must not contain $section")
  }
}

function Test-ActivationSliceDomainBlockerEvidence(
  [object]$State,
  [object]$Definition,
  [string]$Context
) {
  if ($State.FrontMatter.StepId -cin @('13-verify-parity', '14-verify-regression')) {
    Test-ActivationSliceDomainBlockerAbsence $State $Definition $Context
    return
  }
  $rules = @($Definition.DomainBlockerRules)
  if ($rules.Count -ne 1) {
    $errors.Add("$Context domain-blocker evidence contract must contain exactly one rule")
    return
  }
  $rule = $rules[0]
  $valuePredicate = Get-ActivationSliceCellValue $rule 'Value predicates'
  if ($valuePredicate -cne 'non-empty-non-placeholder') {
    $errors.Add("$Context domain-blocker evidence contract must require non-empty-non-placeholder values")
    return
  }
  $section = Get-ActivationSliceCellValue $rule 'Section'
  $columns = @(
    (Get-ActivationSliceCellValue $rule 'Required columns').Split(',') |
      ForEach-Object { Trim-AsciiSpaceTab $_ } |
      Where-Object { $_ -ne '' }
  )
  $sectionCount = @(Get-MarkdownSectionHeadings $State.Text $section).Count
  if ($sectionCount -ne 1) {
    $errors.Add("$Context domain-blocking lifecycle requires canonical blocker evidence")
    return
  }
  $rows = @(Get-MarkdownTableRows $State.Text $section "$Context domain blocker" $columns)
  if ($rows.Count -lt 1) {
    $errors.Add("$Context domain-blocking lifecycle requires canonical blocker evidence")
    return
  }
  foreach ($row in $rows) {
    foreach ($column in $columns) {
      $value = Get-ActivationSliceCellValue $row $column
      if (
        Test-ActivationSlicePlaceholderValue $value $Definition
      ) {
        $errors.Add("$Context domain blocker requires non-placeholder $column")
      }
    }
  }
}

function Test-ActivationSliceFrontMatter(
  [object]$State,
  [bool]$HasBlockingErrors,
  [string]$Context,
  [object]$Definition,
  [bool]$AllowDomainBlocked = $false,
  [bool]$AllowDiscoveryInputPartial = $false
) {
  $approvalSourceIsCanonical =
    $State.FrontMatter.ApprovalSourceCount -eq 1 -and
    $Definition.ApprovalSources -ccontains $State.FrontMatter.ApprovalSource
  if ($State.FrontMatter.Status -ceq 'approved' -and -not $approvalSourceIsCanonical) {
    $errors.Add("$Context approved front matter requires exactly one approval_source: human, auto, or auto-waive")
  }
  elseif ($State.FrontMatter.ApprovalSourceCount -gt 0 -and -not $approvalSourceIsCanonical) {
    $errors.Add("$Context front matter approval_source must be human, auto, or auto-waive")
  }
  $discoveryInputPartial =
    $AllowDiscoveryInputPartial -and
    $State.FrontMatter.StepId -ceq '01-validate-inputs' -and
    $State.FrontMatter.Status -ceq 'approved' -and
    $State.FrontMatter.Result -ceq 'partial'
  if ($discoveryInputPartial) {
    if ($HasBlockingErrors) {
      $errors.Add("$Context activation-blocking errors require front matter status: draft and result: blocked; found status: approved, result: partial")
    }
    if ($State.FrontMatter.WaiverBlockCount -gt 0) {
      $errors.Add("$Context step-01 approved/partial input state must not carry the step-10 waiver mapping")
    }
    Test-ActivationSliceDomainBlockerAbsence $State $Definition $Context
    return
  }
  $resumeTupleIsValid = $true
  if ($State.FrontMatter.Result -ceq 'partial') {
    if ($State.FrontMatter.WaiverBlockCount -ne 1) {
      $errors.Add("$Context step-10 baseline-waiver resume requires exactly one waiver mapping; found $($State.FrontMatter.WaiverBlockCount)")
      $resumeTupleIsValid = $false
    }
    elseif (-not (Test-ActivationSliceExactBaselineWaiver $State.FrontMatter $Definition)) {
      $errors.Add("$Context step-10 baseline-waiver resume requires exact approved/partial/auto-waive waiver tuple")
      $resumeTupleIsValid = $false
    }
  }
  $sliceState = if ($HasBlockingErrors) {
    'activation-blocking'
  }
  elseif ($State.FrontMatter.Result -ceq 'partial') {
    'step-10 baseline-waiver resume'
  }
  elseif (
    $AllowDomainBlocked -and
    $State.FrontMatter.Status -ceq 'draft' -and
    $State.FrontMatter.Result -ceq 'blocked'
  ) {
    'domain-blocking'
  }
  else {
    'non-blocking'
  }
  $allowedRules = @($Definition.FrontMatterRules | Where-Object {
    (Get-ActivationSliceCellValue $_ 'Slice state') -ceq $sliceState
  })
  $isAllowed = @($allowedRules | Where-Object {
    (Get-ActivationSliceCellValue $_ 'Status') -ceq $State.FrontMatter.Status -and
    (Get-ActivationSliceCellValue $_ 'Result') -ceq $State.FrontMatter.Result
  }).Count -eq 1
  if ($sliceState -ceq 'step-10 baseline-waiver resume') {
    Test-ActivationSliceDomainBlockerAbsence $State $Definition $Context
    if ($resumeTupleIsValid -and $isAllowed) {
      return
    }
    return
  }
  if ($isAllowed) {
    if ($sliceState -ceq 'domain-blocking') {
      Test-ActivationSliceDomainBlockerEvidence $State $Definition $Context
    }
    else {
      Test-ActivationSliceDomainBlockerAbsence $State $Definition $Context
    }
    if ($State.FrontMatter.WaiverBlockCount -gt 0) {
      $errors.Add("$Context waiver mapping is valid only for the exact step-10 approved/partial/auto-waive resume lifecycle")
    }
    return
  }

  if ($HasBlockingErrors) {
    $errors.Add("$Context activation-blocking errors require front matter status: draft and result: blocked; found status: $($State.FrontMatter.Status), result: $($State.FrontMatter.Result)")
  }
  else {
    $errors.Add("$Context complete Activation Slice requires front matter draft/complete or approved/complete; found status: $($State.FrontMatter.Status), result: $($State.FrontMatter.Result)")
  }
}

function Test-ActivationSliceRows(
  [string]$SliceId,
  [object[]]$Rows,
  [string]$Context,
  [object]$Definition
) {
  $sliceContext = "$Context slice $SliceId"
  $expectedSeams = @($Definition.Seams)
  $applicabilityValues = @($Definition.Applicability)
  $dispositionValues = @($Definition.Dispositions)
  $statusValues = @($Definition.Statuses)
  $fieldRules = @($Definition.FieldRules)
  $rowRules = @($Definition.RowRules)
  $routerRules = @($Definition.RouterRules)
  $asyncRules = @($Definition.AsyncRules)

  $applicabilities = @(Get-CaseSensitiveUniqueStrings @(
    $Rows | ForEach-Object { Get-ActivationSliceCellValue $_ 'Applicability' }
  ))
  $hasCanonicalApplicability = `
    $applicabilities.Count -eq 1 -and `
    $applicabilityValues -ccontains $applicabilities[0]
  if (-not $hasCanonicalApplicability) {
    $displayApplicability = if ($applicabilities.Count -eq 0) { '<none>' } else { $applicabilities -join ', ' }
    $errors.Add("$sliceContext must use one canonical applicability value; found $displayApplicability")
  }
  $applicability = if ($applicabilities.Count -eq 1) { $applicabilities[0] } else { '' }
  $actualSeams = @($Rows | ForEach-Object { Get-ActivationSliceCellValue $_ 'Seam' })
  $traceIdsBySeam = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
  $sourceReferencesBySeam = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)

  foreach ($expectedSeam in $expectedSeams) {
    $seamCount = @($actualSeams | Where-Object { $_ -ceq $expectedSeam }).Count
    if ($seamCount -ne 1) {
      $errors.Add("$sliceContext missing or duplicated canonical seam: $expectedSeam")
    }
  }
  foreach ($actualSeam in $actualSeams) {
    if ($expectedSeams -cnotcontains $actualSeam) {
      $errors.Add("$sliceContext contains non-canonical seam: $actualSeam")
    }
  }
  if (($actualSeams -join '|') -cne ($expectedSeams -join '|')) {
    $errors.Add("$sliceContext seams must use canonical order")
  }
  if ($hasCanonicalApplicability -and $applicability -ceq 'unknown') {
    $errors.Add("$sliceContext unknown applicability blocks the Activation Slice")
  }

  foreach ($row in $Rows) {
    $seam = Get-ActivationSliceCellValue $row 'Seam'
    $input = Get-ActivationSliceCellValue $row 'Input'
    $output = Get-ActivationSliceCellValue $row 'Output'
    $sourceReference = Get-ActivationSliceCellValue $row 'Source Reference'
    $traceIds = Get-ActivationSliceCellValue $row 'Trace IDs'
    $disposition = Get-ActivationSliceCellValue $row 'Disposition'
    $status = Get-ActivationSliceCellValue $row 'Status'
    $decisionReference = Get-ActivationSliceCellValue $row 'Decision Reference'
    $deferredUnitId = Get-ActivationSliceCellValue $row 'Deferred Unit ID'

    foreach ($fieldRule in $fieldRules) {
      $field = Get-ActivationSliceCellValue $fieldRule 'Field'
      $requiredValue = Get-ActivationSliceCellValue $fieldRule 'Required value'
      $actualValue = Get-ActivationSliceCellValue $row $field
      if ($requiredValue -ceq '<non-empty>' -and [string]::IsNullOrWhiteSpace($actualValue)) {
        $requirement = if ($field -in @('Input', 'Output')) { "non-empty $field" } else { $field }
        $errors.Add("$sliceContext seam $seam requires $requirement")
      }
    }
    $traceIdsBySeam[$seam] = @(Get-CaseSensitiveUniqueStrings @(
      $traceIds.Split(',') |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne '' }
    ))
    $sourceReferencesBySeam[$seam] = $sourceReference
    if ($dispositionValues -cnotcontains $disposition -or $statusValues -cnotcontains $status) {
      $errors.Add("$sliceContext seam $seam has invalid disposition/status pair: $disposition/$status")
    }
    $matchingRowRules = @($rowRules | Where-Object {
      (Get-ActivationSliceCellValue $_ 'Applicability') -ceq $applicability -and
      (Get-ActivationSliceCellValue $_ 'Disposition') -ceq $disposition -and
      (Get-ActivationSliceCellValue $_ 'Status') -ceq $status
    })
    if ($matchingRowRules.Count -ne 1) {
      $errors.Add("$sliceContext seam $seam has invalid applicability/disposition/status combination: $applicability/$disposition/$status")
    }
    else {
      $rowRule = $matchingRowRules[0]
      $expectedDecision = Get-ActivationSliceCellValue $rowRule 'Decision Reference'
      $expectedDeferredUnit = Get-ActivationSliceCellValue $rowRule 'Deferred Unit ID'
      $routerApprovalOverride = `
        $seam -ceq 'construct' -and `
        $output -ceq 'compatibility-dual-path'

      if (
        $expectedDecision -ceq 'not-applicable' -and
        -not $routerApprovalOverride -and
        $decisionReference -cne 'not-applicable'
      ) {
        $errors.Add("$sliceContext ordinary seam $seam requires Decision Reference sentinel not-applicable")
      }
      elseif (
        $expectedDecision -ceq '<approval-reference>' -and
        ([string]::IsNullOrWhiteSpace($decisionReference) -or $decisionReference -ceq 'not-applicable')
      ) {
        $errors.Add("$sliceContext $disposition seam $seam requires Decision Reference")
      }

      if ($expectedDeferredUnit -ceq 'not-applicable' -and $deferredUnitId -cne 'not-applicable') {
        $prefix = if ($disposition -ceq 'not-applicable-approved') { 'not-applicable-approved' } else { 'ordinary' }
        $errors.Add("$sliceContext $prefix seam $seam requires Deferred Unit ID sentinel not-applicable")
      }
      elseif ($expectedDeferredUnit -ceq 'UNIT-[0-9]{3}' -and $deferredUnitId -cnotmatch '^UNIT-[0-9]{3}$') {
        $errors.Add("$sliceContext deferred-approved seam $seam requires Deferred Unit ID format UNIT-[0-9]{3}")
      }
    }
    if ($applicability -ceq 'applicable' -and $status -cne 'verified') {
      $errors.Add("$sliceContext applicable seam $seam is not verified: $status")
    }
  }

  if ($hasCanonicalApplicability -and $applicability -ceq 'applicable') {
    $constructRows = @($Rows | Where-Object { (Get-ActivationSliceCellValue $_ 'Seam') -ceq 'construct' })
    if ($constructRows.Count -eq 1) {
      $constructOutput = Get-ActivationSliceCellValue $constructRows[0] 'Output'
      $policyRules = @($routerRules | Where-Object {
        (Get-ActivationSliceCellValue $_ 'Required key') -ceq 'policy'
      })
      $routerPolicies = @(
        $policyRules |
          ForEach-Object { Get-ActivationSliceCellValue $_ 'Router Policy' } |
          Where-Object { $constructOutput -cmatch "(?<![A-Za-z0-9-])$([regex]::Escape($_))(?![A-Za-z0-9-])" }
      )
      if ($routerPolicies.Count -ne 1) {
        $errors.Add("$sliceContext construct Output must record exactly one approved router policy; found $($routerPolicies.Count)")
      }
      elseif ($constructOutput -cne $routerPolicies[0]) {
        $errors.Add("$sliceContext construct Output router policy must be the exact canonical value: $($routerPolicies[0])")
      }
      else {
        $selectedPolicy = $routerPolicies[0]
        $dependencyRules = @($routerRules | Where-Object {
          (Get-ActivationSliceCellValue $_ 'Router Policy') -ceq $selectedPolicy -and
          (Get-ActivationSliceCellValue $_ 'Required key') -cne 'policy'
        })
        foreach ($dependencyRule in $dependencyRules) {
          $location = Get-ActivationSliceCellValue $dependencyRule 'Artifact location'
          $column = $location.Substring('construct.'.Length)
          $requiredKey = Get-ActivationSliceCellValue $dependencyRule 'Required key'
          $requiredValue = Get-ActivationSliceCellValue $dependencyRule 'Required value'
          $actualValue = Get-ActivationSliceCellValue $constructRows[0] $column
          $hasRequiredValue = switch -CaseSensitive ($requiredValue) {
            'compatibility-reason=<non-empty>' { $actualValue -cmatch '(?:^|;\s*)compatibility-reason=[^;\s][^;]*(?:;|$)' }
            'router-owner=<non-empty>' { $actualValue -cmatch '(?:^|;\s*)router-owner=[^;\s][^;]*(?:;|$)' }
            '<non-not-applicable>' { -not [string]::IsNullOrWhiteSpace($actualValue) -and $actualValue -cne 'not-applicable' }
            'PARITY-###' { $actualValue -cmatch '(?:^|,\s*)PARITY-[0-9]{3}(?:,|$)' }
            default { $false }
          }
          if (-not $hasRequiredValue) {
            $dependencyLabel = switch -CaseSensitive ($requiredKey) {
              'compatibility-reason' { 'compatibility-reason in construct Source Reference' }
              'router-owner' { 'router-owner in construct Source Reference' }
              'approval-reference' { 'construct Decision Reference' }
              'parity-test' { 'parity-test Trace ID' }
            }
            $errors.Add("$sliceContext $selectedPolicy requires $dependencyLabel")
          }
        }
      }
    }

    $selectorRows = @($Rows | Where-Object { (Get-ActivationSliceCellValue $_ 'Seam') -ceq 'selector' })
    $testRows = @($Rows | Where-Object { (Get-ActivationSliceCellValue $_ 'Seam') -ceq 'test' })
    if ($selectorRows.Count -eq 1) {
      $selectorInput = Get-ActivationSliceCellValue $selectorRows[0] 'Input'
      $classificationRules = @($asyncRules | Where-Object {
        (Get-ActivationSliceCellValue $_ 'Required key') -ceq 'async-classification'
      })
      $classifications = @(
        $classificationRules |
          Where-Object {
            $requiredValue = Get-ActivationSliceCellValue $_ 'Required value'
            $selectorInput -cmatch "(?:^|;\s*)$([regex]::Escape($requiredValue))(?:;|$)"
          } |
          ForEach-Object { Get-ActivationSliceCellValue $_ 'Classification' }
      )
      if ($classifications.Count -ne 1) {
        $errors.Add("$sliceContext selector Input requires exactly one async classification; found $($classifications.Count)")
      }
      else {
        $classification = $classifications[0]
        $dependencyRules = @($asyncRules | Where-Object {
          (Get-ActivationSliceCellValue $_ 'Classification') -ceq $classification -and
          (Get-ActivationSliceCellValue $_ 'Required key') -cne 'async-classification'
        })
        $missingEvidence = [Collections.Generic.List[string]]::new()
        foreach ($dependencyRule in $dependencyRules) {
          $location = Get-ActivationSliceCellValue $dependencyRule 'Artifact location'
          $locationParts = $location.Split('.', 2)
          $targetRows = @(if ($locationParts[0] -ceq 'selector') { $selectorRows } else { $testRows })
          $requiredKey = Get-ActivationSliceCellValue $dependencyRule 'Required key'
          $requiredValue = Get-ActivationSliceCellValue $dependencyRule 'Required value'
          $hasEvidence = $false
          if ($targetRows.Count -eq 1) {
            $actualValue = Get-ActivationSliceCellValue $targetRows[0] $locationParts[1]
            if ($requiredValue -ceq "$requiredKey=<non-empty>") {
              $hasEvidence = $actualValue -cmatch "(?:^|;\s*)$([regex]::Escape($requiredKey))=[^;\s][^;]*(?:;|$)"
            }
            elseif ($requiredValue -ceq "$requiredKey=<trace-id>") {
              $traceMatch = [regex]::Match(
                $actualValue,
                "(?:^|;\s*)$([regex]::Escape($requiredKey))=(?<trace>[^;]+?)(?:;|$)"
              )
              $testTraceIds = @(
                (Get-ActivationSliceCellValue $targetRows[0] 'Trace IDs').Split(',') |
                  ForEach-Object { $_.Trim() }
              )
              $traceValue = if ($traceMatch.Success) { $traceMatch.Groups['trace'].Value.Trim() } else { '' }
              $hasEvidence = -not [string]::IsNullOrWhiteSpace($traceValue) -and $testTraceIds -ccontains $traceValue
            }
          }
          if (-not $hasEvidence) { $missingEvidence.Add($requiredKey) }
        }
        if ($missingEvidence.Count -gt 0) {
          if ($classification -ceq 'async') {
            $errors.Add("$sliceContext async classification missing lifecycle evidence: $($missingEvidence -join ', ')")
          }
          elseif ($classification -ceq 'immutable') {
            $errors.Add("$sliceContext immutable classification requires immutability-evidence in selector Source Reference")
          }
        }
      }
    }
  }

  return [pscustomobject]@{
    Id = $SliceId
    Applicability = $applicability
    Seams = $actualSeams
    TraceIds = $traceIdsBySeam
    SourceReferences = $sourceReferencesBySeam
  }
}

function Test-ActivationSliceArtifact(
  [string]$Text,
  [string]$Context,
  [object]$Definition
) {
  $state = New-ActivationSliceArtifactState
  $state.Text = $Text
  $state.FrontMatter = Get-ActivationSliceFrontMatter $Text $Context
  $activationErrorStart = $errors.Count
  $sectionName = 'Activation Slice'
  $sectionCount = @(Get-MarkdownSectionHeadings $Text $sectionName).Count
  if ($sectionCount -ne 1) {
    $errors.Add("$Context canonical Activation Slice section must appear exactly once; found $sectionCount")
    $state.HasBlockingErrors = $true
    return $state
  }

  $rows = @(Get-MarkdownTableRows $Text $sectionName $Context @($Definition.Columns))
  if ($rows.Count -eq 0) {
    $errors.Add("$Context must contain at least one Activation Slice row")
    $state.HasBlockingErrors = $true
    return $state
  }

  $activationIdPattern = Get-ActivationSliceIdentifierPattern $Definition 'Activation Slice ID'
  $rowGroups = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
  $sliceOrder = [Collections.Generic.List[string]]::new()
  foreach ($row in $rows) {
    $sliceId = Get-ActivationSliceCellValue $row 'Activation Slice ID'
    if ([string]::IsNullOrWhiteSpace($activationIdPattern) -or $sliceId -cnotmatch "^$activationIdPattern$") {
      $expectedPattern = if ([string]::IsNullOrWhiteSpace($activationIdPattern)) { 'ACT-[0-9]{3}' } else { $activationIdPattern }
      $errors.Add("$Context invalid Activation Slice ID: $sliceId; expected $expectedPattern")
    }
    if (-not $rowGroups.ContainsKey($sliceId)) {
      $rowGroups[$sliceId] = [Collections.Generic.List[object]]::new()
      $sliceOrder.Add($sliceId)
    }
    $rowGroups[$sliceId].Add($row)
  }

  foreach ($sliceId in $sliceOrder) {
    $slice = Test-ActivationSliceRows $sliceId @($rowGroups[$sliceId]) $Context $Definition
    $state.Slices[$sliceId] = $slice
  }
  $state.Order = @($sliceOrder)
  $state.HasBlockingErrors = $errors.Count -gt $activationErrorStart
  return $state
}

function Test-ActivationSliceHandoff([object]$Predecessor, [object]$Successor, [object]$Definition) {
  $sourceReferenceRules = @($Definition.SourceReferenceRules | Where-Object {
    (Get-ActivationSliceCellValue $_ 'Field') -ceq 'Source Reference'
  })
  $sourceReferenceShape = if ($sourceReferenceRules.Count -eq 1) {
    Get-ActivationSliceCellValue $sourceReferenceRules[0] 'Allowed successor shape'
  }
  else {
    ''
  }
  if ($sourceReferenceShape -cne 'exact or <predecessor>; <non-whitespace evidence>') {
    $errors.Add('Activation Slice contract must declare the canonical Source Reference enrichment shape')
  }
  $predecessorIds = @($Predecessor.Order)
  $successorIds = @($Successor.Order)
  $lostSliceIds = @($predecessorIds | Where-Object { $successorIds -cnotcontains $_ })
  $addedSliceIds = @($successorIds | Where-Object { $predecessorIds -cnotcontains $_ })

  if ($predecessorIds.Count -eq 1 -and $successorIds.Count -eq 1 -and $predecessorIds[0] -cne $successorIds[0]) {
    $errors.Add("Activation Slice handoff changed Activation Slice ID from $($predecessorIds[0]) to $($successorIds[0])")
  }
  foreach ($sliceId in $lostSliceIds) {
    $errors.Add("Activation Slice handoff lost Activation Slice ID: $sliceId")
  }
  foreach ($sliceId in $addedSliceIds) {
    $errors.Add("Activation Slice handoff added Activation Slice ID: $sliceId")
  }

  foreach ($sliceId in $predecessorIds | Where-Object { $successorIds -ccontains $_ }) {
    $predecessorSlice = $Predecessor.Slices[$sliceId]
    $successorSlice = $Successor.Slices[$sliceId]
    if ($predecessorSlice.Applicability -cne $successorSlice.Applicability) {
      $errors.Add("Activation Slice handoff slice $sliceId changed Applicability from $($predecessorSlice.Applicability) to $($successorSlice.Applicability)")
    }
    if (($predecessorSlice.Seams -join '|') -cne ($successorSlice.Seams -join '|')) {
      if ($predecessorIds.Count -eq 1 -and $successorIds.Count -eq 1) {
        $errors.Add('Activation Slice handoff changed canonical seam set')
      }
      else {
        $errors.Add("Activation Slice handoff slice $sliceId changed canonical seam set")
      }
    }
    foreach ($seam in $Definition.Seams) {
      $predecessorSourceReference = [string]$predecessorSlice.SourceReferences[$seam]
      $successorSourceReference = [string]$successorSlice.SourceReferences[$seam]
      $sourceReferenceAppendPrefix = "$predecessorSourceReference; "
      $sourceReferenceSuffix = if ($successorSourceReference.StartsWith($sourceReferenceAppendPrefix, [StringComparison]::Ordinal)) {
        $successorSourceReference.Substring($sourceReferenceAppendPrefix.Length)
      }
      else {
        ''
      }
      $hasValidSourceReferenceAppend = `
        -not [string]::IsNullOrWhiteSpace($sourceReferenceSuffix) -and `
        $sourceReferenceSuffix -ceq $sourceReferenceSuffix.Trim()
      $preservesSourceReference = `
        $sourceReferenceShape -ceq 'exact or <predecessor>; <non-whitespace evidence>' -and `
        (
          $successorSourceReference -ceq $predecessorSourceReference -or
          $hasValidSourceReferenceAppend
        )
      if (-not $preservesSourceReference) {
        $hasMalformedAppendPrefix = $successorSourceReference.StartsWith("$predecessorSourceReference;", [StringComparison]::Ordinal)
        if ($hasMalformedAppendPrefix -and $predecessorIds.Count -eq 1 -and $successorIds.Count -eq 1) {
          $errors.Add("Activation Slice handoff seam $seam has invalid Source Reference enrichment after: $predecessorSourceReference")
        }
        elseif ($hasMalformedAppendPrefix) {
          $errors.Add("Activation Slice handoff slice $sliceId seam $seam has invalid Source Reference enrichment after: $predecessorSourceReference")
        }
        elseif ($predecessorIds.Count -eq 1 -and $successorIds.Count -eq 1) {
          $errors.Add("Activation Slice handoff seam $seam lost predecessor Source Reference evidence: $predecessorSourceReference")
        }
        else {
          $errors.Add("Activation Slice handoff slice $sliceId seam $seam lost predecessor Source Reference evidence: $predecessorSourceReference")
        }
      }
      $predecessorTraceIds = @($predecessorSlice.TraceIds[$seam])
      $successorTraceIds = @($successorSlice.TraceIds[$seam])
      $lostTraceIds = @(
        $predecessorTraceIds |
          Where-Object { $successorTraceIds -cnotcontains $_ }
      )
      if ($lostTraceIds.Count -gt 0) {
        if ($predecessorIds.Count -eq 1 -and $successorIds.Count -eq 1) {
          $errors.Add("Activation Slice handoff seam $seam lost predecessor Trace IDs: $($lostTraceIds -join ', ')")
        }
        else {
          $errors.Add("Activation Slice handoff slice $sliceId seam $seam lost predecessor Trace IDs: $($lostTraceIds -join ', ')")
        }
      }
    }
  }
}

function Get-ActivationSliceImmediatePredecessorRule(
  [object]$Predecessor,
  [object]$Successor,
  [object]$Definition,
  [string]$Context
) {
  $matchingRules = @($Definition.HandoffRules | Where-Object {
    $rule = $_
    $currentLifecycles = @(
      (Get-ActivationSliceCellValue $rule 'Current lifecycle').Split(',') |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne '' }
    )
    $currentLifecycle = "$($Successor.FrontMatter.Status)/$($Successor.FrontMatter.Result)"
    $approvalSource = Get-ActivationSliceCellValue $rule 'Predecessor Approval Source'
    $waiverRule = Get-ActivationSliceCellValue $rule 'Predecessor Waiver'
    $predecessorResults = @(
      (Get-ActivationSliceCellValue $rule 'Predecessor Result').Split(',') |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne '' }
    )
    $approvalSourceMatches = switch -CaseSensitive ($approvalSource) {
      '<canonical>' {
        $Predecessor.FrontMatter.ApprovalSourceCount -eq 1 -and
        $Definition.ApprovalSources -ccontains $Predecessor.FrontMatter.ApprovalSource
      }
      '<any>' { $true }
      default {
        $Predecessor.FrontMatter.ApprovalSourceCount -eq 1 -and
        $approvalSource -ceq $Predecessor.FrontMatter.ApprovalSource
      }
    }
    (Get-ActivationSliceCellValue $rule 'Current step ID') -ceq $Successor.FrontMatter.StepId -and
    $currentLifecycles -ccontains $currentLifecycle -and
    (Get-ActivationSliceCellValue $rule 'Predecessor step ID') -ceq $Predecessor.FrontMatter.StepId -and
    (Get-ActivationSliceCellValue $rule 'Predecessor Status') -ceq $Predecessor.FrontMatter.Status -and
    $predecessorResults -ccontains $Predecessor.FrontMatter.Result -and
    $approvalSourceMatches -and
    (
      $waiverRule -ceq '<any>' -or
      ($waiverRule -ceq 'exact-baseline-waiver' -and
        (Test-ActivationSliceExactBaselineWaiver $Predecessor.FrontMatter $Definition))
    )
  })
  if ($matchingRules.Count -ne 1) {
    $errors.Add("$Context immediate-predecessor role/lifecycle invalid")
    return $null
  }
  return $matchingRules[0]
}

function Get-ActivationSliceExactHandoffRow(
  [string]$Text,
  [string]$Section,
  [string[]]$Columns,
  [string]$Role,
  [string]$Context
) {
  $headingCount = @(Get-MarkdownSectionHeadings $Text $Section).Count
  if ($headingCount -ne 1) {
    $errors.Add("$Context $Role $Section section must appear exactly once; found $headingCount")
    return $null
  }
  $rows = @(Get-MarkdownTableRows $Text $Section "$Context $Role $Section" $Columns)
  if ($rows.Count -ne 1) {
    $errors.Add("$Context $Role $Section must contain exactly one row; found $($rows.Count)")
    return $null
  }
  return $rows[0]
}

function Get-ActivationSliceCanonicalSelectedUnitRow(
  [object]$Artifact,
  [object]$Definition,
  [string]$Role,
  [string]$Context
) {
  $selectedRules = @($Definition.LinkRules | Where-Object {
    (Get-ActivationSliceCellValue $_ 'Record') -ceq 'selected-unit'
  })
  if ($selectedRules.Count -ne 1) {
    $errors.Add("$Context selected-unit contract must declare exactly one canonical record")
    return $null
  }
  $rule = $selectedRules[0]
  $columns = @(
    (Get-ActivationSliceCellValue $rule 'Required columns').Split(',') |
      ForEach-Object { $_.Trim() } |
      Where-Object { $_ -ne '' }
  )
  $row = Get-ActivationSliceExactHandoffRow `
    $Artifact.Text `
    (Get-ActivationSliceCellValue $rule 'Section') `
    $columns `
    $Role `
    $Context
  if ($null -ne $row) {
    Test-ActivationSliceRequiredHandoffRow $row $columns $Definition "$Context $Role"
  }
  return $row
}

function Test-ActivationSliceRequiredHandoffRow(
  [object]$Row,
  [string[]]$Columns,
  [object]$Definition,
  [string]$Context
) {
  foreach ($column in $Columns) {
    if ([string]::IsNullOrWhiteSpace((Get-ActivationSliceCellValue $Row $column))) {
      $errors.Add("$Context requires non-empty $column")
    }
  }
  if ($Columns -ccontains 'Migration Unit ID') {
    $pattern = Get-ActivationSliceIdentifierPattern $Definition 'Migration Unit ID'
    $unitId = Get-ActivationSliceCellValue $Row 'Migration Unit ID'
    if (
      -not [string]::IsNullOrWhiteSpace($unitId) -and
      ([string]::IsNullOrWhiteSpace($pattern) -or $unitId -cnotmatch "^$pattern$")
    ) {
      $expected = if ([string]::IsNullOrWhiteSpace($pattern)) { 'UNIT-[0-9]{3}' } else { $pattern }
      $errors.Add("$Context Migration Unit ID must match $expected`: $unitId")
    }
  }
}

function Test-ActivationSliceResolvedEvidenceReference([string]$Value, [object]$Definition) {
  return -not (Test-ActivationSlicePlaceholderValue $Value $Definition)
}

function Test-ActivationSliceSelectedUnitIntrinsicState(
  [object]$Row,
  [object]$Definition,
  [string]$Context,
  [bool]$AllowPendingBootstrapApproval = $false
) {
  if ($null -eq $Row) { return $false }
  $mode = Get-ActivationSliceCellValue $Row 'Mode Constraint'
  $scope = Get-ActivationSliceCellValue $Row 'Bootstrap Scope'
  $foundationId = Get-ActivationSliceCellValue $Row 'Foundation Baseline ID'
  $foundationReference = Get-ActivationSliceCellValue $Row 'Foundation Baseline Reference'
  $foundationApproval = Get-ActivationSliceCellValue $Row 'Foundation Baseline Approval Reference'
  $baselineReference = Get-ActivationSliceCellValue $Row 'Baseline Reference'
  if ($mode -ceq 'incremental/preserve-existing' -and $scope -ceq 'not-required') {
    $incrementalRules = @($Definition.DirectPlanFoundationRules | Where-Object {
      (Get-ActivationSliceCellValue $_ 'Mode Constraint') -ceq $mode -and
      (Get-ActivationSliceCellValue $_ 'Bootstrap Scope') -ceq $scope
    })
    $valid =
      $incrementalRules.Count -eq 1 -and
      (Get-ActivationSliceCellValue $incrementalRules[0] 'Current Baseline Reference') -ceq '<resolved-pre-mutation-baseline-reference>' -and
      $foundationId -ceq 'not-applicable' -and
      $foundationReference -ceq 'not-applicable' -and
      $foundationApproval -ceq 'not-applicable' -and
      (Test-ActivationSliceResolvedEvidenceReference $baselineReference $Definition)
    if (-not $valid) {
      $errors.Add("$Context selected unit violates canonical incremental foundation predicates")
    }
    return $valid
  }
  if ($mode -ceq 'greenfield/design-new' -and $scope -cin @('required', 'not-required')) {
    $approvalValid =
      ($AllowPendingBootstrapApproval -and $foundationApproval -ceq 'pending-step09-approval') -or
      (Test-ActivationSliceResolvedEvidenceReference $foundationApproval $Definition)
    $valid =
      $foundationId -cmatch '^FOUNDATION-[A-Za-z0-9._-]+$' -and
      (Test-ActivationSliceResolvedEvidenceReference $foundationReference $Definition) -and
      $approvalValid -and
      $baselineReference -ceq 'not-applicable'
    if (-not $valid) {
      $errors.Add("$Context selected unit violates canonical greenfield foundation predicates")
    }
    return $valid
  }
  $errors.Add("$Context selected unit has unsupported mode/bootstrap predicates")
  return $false
}

function Test-ActivationSlicePreselectionArtifactState(
  [object]$Artifact,
  [object]$Definition,
  [string]$Role,
  [string]$Context
) {
  $rules = @($Definition.HandoffRules | Where-Object {
    (Get-ActivationSliceCellValue $_ 'Current step ID') -ceq $Artifact.FrontMatter.StepId -and
    (Get-ActivationSliceCellValue $_ 'Selected Mode Constraint') -ceq '<not-applicable>' -and
    (Get-ActivationSliceCellValue $_ 'Selected Bootstrap Scope') -ceq '<not-applicable>'
  })
  if ($rules.Count -eq 0) { return }
  $sectionCount = @(Get-MarkdownSectionHeadings $Artifact.Text 'Selected Migration Unit').Count
  if ($sectionCount -ne 0) {
    $errors.Add("$Context $Role pre-selection artifact forbids Selected Migration Unit section; found $sectionCount")
  }
}

function Test-ActivationSliceSelectedRoute(
  [object]$Artifact,
  [object]$Rule,
  [object]$Definition,
  [string]$Context
) {
  $expectedMode = Get-ActivationSliceCellValue $Rule 'Selected Mode Constraint'
  $expectedScope = Get-ActivationSliceCellValue $Rule 'Selected Bootstrap Scope'
  if ($expectedMode -ceq '<not-applicable>' -and $expectedScope -ceq '<not-applicable>') {
    $sectionCount = @(Get-MarkdownSectionHeadings $Artifact.Text 'Selected Migration Unit').Count
    if ($sectionCount -ne 0) {
      $errors.Add("$Context pre-selection route forbids Selected Migration Unit section; found $sectionCount")
      return $false
    }
    return $true
  }
  $route = Get-ActivationSliceCellValue $Rule 'Route'
  $role = switch -CaseSensitive ($route) {
    'bootstrap' { 'bootstrap current' }
    'baseline-waiver-resume' { 'resume current' }
    'post-waiver-resume' { 'post-waiver current' }
    default { 'route current' }
  }
  $row = Get-ActivationSliceCanonicalSelectedUnitRow $Artifact $Definition $role $Context
  if ($null -eq $row) { return $false }
  $actualMode = Get-ActivationSliceCellValue $row 'Mode Constraint'
  $actualScope = Get-ActivationSliceCellValue $row 'Bootstrap Scope'
  $canonicalPair =
    ($actualMode -ceq 'incremental/preserve-existing' -and $actualScope -ceq 'not-required') -or
    ($actualMode -ceq 'greenfield/design-new' -and $actualScope -cin @('required', 'not-required'))
  $modeMatches = if ($expectedMode -ceq '<canonical>') { $canonicalPair } else { $actualMode -ceq $expectedMode }
  $scopeMatches = if ($expectedScope -ceq '<canonical>') { $canonicalPair } else { $actualScope -ceq $expectedScope }
  if ($modeMatches -and $scopeMatches) { return $true }

  $predecessorStepId = Get-ActivationSliceCellValue $Rule 'Predecessor step ID'
  if ($route -ceq 'bootstrap') {
    $errors.Add("$Context bootstrap route requires selected-unit Mode Constraint greenfield/design-new and Bootstrap Scope required")
  }
  elseif ($route -ceq 'initial' -and $predecessorStepId -ceq '08-plan-waves') {
    $errors.Add("$Context initial plan route requires selected-unit Bootstrap Scope not-required")
  }
  elseif ($route -ceq 'baseline-waiver-resume') {
    $errors.Add("$Context resume selected-unit Mode Constraint must be incremental/preserve-existing")
  }
  elseif ($route -ceq 'post-waiver-resume') {
    $errors.Add("$Context post-waiver resume requires incremental/preserve-existing and not-required selected unit")
  }
  elseif ($Artifact.FrontMatter.StepId -ceq '14-verify-regression') {
    $errors.Add("$Context regression route requires selected-unit Mode Constraint incremental/preserve-existing and Bootstrap Scope not-required")
  }
  else {
    $errors.Add("$Context selected-unit mode/bootstrap pair is invalid for route $route")
  }
  return $false
}

function Test-ActivationSliceBootstrapHandoff(
  [object]$Predecessor,
  [object]$Successor,
  [object]$Definition,
  [string]$Context
) {
  if ($Successor.FrontMatter.StepId -cne '09-bootstrap-target') { return }
  $currentLifecycle = "$($Successor.FrontMatter.Status)/$($Successor.FrontMatter.Result)"
  $rules = @($Definition.BootstrapUnitRules | Where-Object {
    (Get-ActivationSliceCellValue $_ 'Current step ID') -ceq $Successor.FrontMatter.StepId -and
    (Get-ActivationSliceCellValue $_ 'Predecessor step ID') -ceq $Predecessor.FrontMatter.StepId -and
    (Get-ActivationSliceCellValue $_ 'Current lifecycle') -ceq $currentLifecycle
  })
  if ($rules.Count -ne 1) {
    $errors.Add("$Context bootstrap selected-unit contract must resolve exactly one rule; found $($rules.Count)")
    return
  }
  $rule = $rules[0]
  $currentRow = Get-ActivationSliceCanonicalSelectedUnitRow $Successor $Definition 'bootstrap current' $Context

  $planRules = @($Definition.Step10UnitRules | Where-Object {
    (Get-ActivationSliceCellValue $_ 'Predecessor step ID') -ceq '08-plan-waves'
  })
  if ($planRules.Count -ne 1) {
    $errors.Add("$Context bootstrap contract requires one canonical ordered-plan rule")
    return
  }
  $planRule = $planRules[0]
  $planColumns = @(
    (Get-ActivationSliceCellValue $planRule 'Predecessor Unit Required Columns').Split(',') |
      ForEach-Object { $_.Trim() } |
      Where-Object { $_ -ne '' }
  )
  $planSection = Get-ActivationSliceCellValue $rule 'Predecessor Unit Section'
  $planHeadingCount = @(Get-MarkdownSectionHeadings $Predecessor.Text $planSection).Count
  $planRows = @()
  if ($planHeadingCount -ne 1) {
    $errors.Add("$Context bootstrap predecessor $planSection section must appear exactly once; found $planHeadingCount")
  }
  else {
    $planRows = @(Get-MarkdownTableRows $Predecessor.Text $planSection "$Context bootstrap predecessor" $planColumns)
  }
  foreach ($planRowCandidate in $planRows) {
    Test-ActivationSliceRequiredHandoffRow `
      $planRowCandidate $planColumns $Definition "$Context bootstrap predecessor ordered-unit record"
  }
  if ($null -eq $currentRow) { return }
  $currentUnitId = Get-ActivationSliceCellValue $currentRow 'Migration Unit ID'
  $matchingPlanRows = @($planRows | Where-Object {
    (Get-ActivationSliceCellValue $_ 'Migration Unit ID') -ceq $currentUnitId -and
    (Get-ActivationSliceCellValue $_ 'Approval Status') -ceq 'approved'
  })
  if ($matchingPlanRows.Count -ne 1) {
    $errors.Add("$Context bootstrap requires exactly one approved predecessor ordered-unit record matching $currentUnitId; found $($matchingPlanRows.Count)")
    return
  }
  $planRow = $matchingPlanRows[0]
  foreach ($field in @(
    (Get-ActivationSliceCellValue $rule 'Exact mapped fields').Split(',') |
      ForEach-Object { $_.Trim() } |
      Where-Object { $_ -ne '' }
  )) {
    if ((Get-ActivationSliceCellValue $currentRow $field) -cne (Get-ActivationSliceCellValue $planRow $field)) {
      $errors.Add("$Context bootstrap selected-unit mapped field changed: $field")
    }
  }
  if (
    (Get-ActivationSliceCellValue $planRow 'Foundation Baseline ID') -cne 'pending-bootstrap' -or
    (Get-ActivationSliceCellValue $planRow 'Foundation Approval Reference') -cne 'pending-step09-approval'
  ) {
    $errors.Add("$Context bootstrap predecessor must carry the pending foundation sentinels")
  }
  $foundationId = Get-ActivationSliceCellValue $currentRow 'Foundation Baseline ID'
  $foundationReference = Get-ActivationSliceCellValue $currentRow 'Foundation Baseline Reference'
  $foundationApproval = Get-ActivationSliceCellValue $currentRow 'Foundation Baseline Approval Reference'
  $baselineReference = Get-ActivationSliceCellValue $currentRow 'Baseline Reference'
  if ($currentLifecycle -ceq 'draft/blocked') {
    if (
      (Get-ActivationSliceCellValue $currentRow 'Mode Constraint') -cne 'greenfield/design-new' -or
      (Get-ActivationSliceCellValue $currentRow 'Bootstrap Scope') -cne 'required' -or
      $foundationId -cne 'pending-bootstrap' -or
      $foundationReference -cne 'not-applicable' -or
      $foundationApproval -cne 'pending-step09-approval' -or
      $baselineReference -cne 'not-applicable'
    ) {
      $errors.Add("$Context bootstrap blocked current selected unit must retain the canonical pending tuple")
    }
    $resolvedFoundationSections = @(
      $Definition.BootstrapUnitRules |
        ForEach-Object { Get-ActivationSliceCellValue $_ 'Foundation Section' } |
        Where-Object { $_ -cne '<absent>' } |
        Select-Object -Unique
    )
    if ($resolvedFoundationSections.Count -ne 1) {
      $errors.Add("$Context bootstrap contract must declare exactly one resolved foundation section")
      return
    }
    $foundationHeadingCount = @(
      Get-MarkdownSectionHeadings $Successor.Text $resolvedFoundationSections[0]
    ).Count
    if ($foundationHeadingCount -ne 0) {
      $errors.Add("$Context bootstrap blocked current must not contain a foundation record")
    }
    return
  }
  if ($currentLifecycle -ceq 'draft/complete') {
    if (
      (Get-ActivationSliceCellValue $currentRow 'Mode Constraint') -cne 'greenfield/design-new' -or
      (Get-ActivationSliceCellValue $currentRow 'Bootstrap Scope') -cne 'required' -or
      $foundationId -cnotmatch '^FOUNDATION-[A-Za-z0-9._-]+$' -or
      -not (Test-ActivationSliceResolvedEvidenceReference $foundationReference $Definition) -or
      $foundationApproval -cne 'pending-step09-approval' -or
      $baselineReference -cne 'not-applicable'
    ) {
      $errors.Add("$Context bootstrap draft current selected unit violates canonical pending-approval predicates")
    }
  }
  else {
    Test-ActivationSliceResolvedFoundationSelectedUnit $currentRow $Definition 'bootstrap current' $Context
  }

  $foundationSection = Get-ActivationSliceCellValue $rule 'Foundation Section'
  $foundationColumns = @(
    (Get-ActivationSliceCellValue $rule 'Foundation required columns').Split(',') |
      ForEach-Object { $_.Trim() } |
      Where-Object { $_ -ne '' }
  )
  $foundationRow = Get-ActivationSliceExactHandoffRow `
    $Successor.Text $foundationSection $foundationColumns 'bootstrap current' $Context
  if ($null -eq $foundationRow) { return }
  foreach ($column in $foundationColumns) {
    if ([string]::IsNullOrWhiteSpace((Get-ActivationSliceCellValue $foundationRow $column))) {
      $errors.Add("$Context bootstrap foundation record requires non-empty $column")
    }
  }
  $expectedFoundationApproval = if ($currentLifecycle -ceq 'draft/complete') {
    'pending-step09-approval'
  }
  else {
    $foundationApproval
  }
  $expectedFoundationStatus = if ($currentLifecycle -ceq 'draft/complete') {
    'pending-approval'
  }
  else {
    'approved'
  }
  if (
    (Get-ActivationSliceCellValue $foundationRow 'Foundation Baseline ID') -cne $foundationId -or
    (Get-ActivationSliceCellValue $foundationRow 'Source Migration Unit ID') -cne $currentUnitId -or
    (Get-ActivationSliceCellValue $foundationRow 'Target Baseline Reference') -cne $foundationReference -or
    (Get-ActivationSliceCellValue $foundationRow 'Approval Reference') -cne $expectedFoundationApproval -or
    (Get-ActivationSliceCellValue $foundationRow 'Approval Status') -cne $expectedFoundationStatus
  ) {
    $errors.Add("$Context bootstrap foundation record must correlate with the selected unit and lifecycle")
  }
}

function Test-ActivationSliceResolvedFoundationSelectedUnit(
  [object]$Row,
  [object]$Definition,
  [string]$Role,
  [string]$Context
) {
  if ($null -eq $Row) { return }
  if (
    (Get-ActivationSliceCellValue $Row 'Mode Constraint') -cne 'greenfield/design-new' -or
    (Get-ActivationSliceCellValue $Row 'Bootstrap Scope') -cne 'required' -or
    (Get-ActivationSliceCellValue $Row 'Foundation Baseline ID') -cnotmatch '^FOUNDATION-[A-Za-z0-9._-]+$' -or
    -not (Test-ActivationSliceResolvedEvidenceReference (Get-ActivationSliceCellValue $Row 'Foundation Baseline Reference') $Definition) -or
    -not (Test-ActivationSliceResolvedEvidenceReference (Get-ActivationSliceCellValue $Row 'Foundation Baseline Approval Reference') $Definition) -or
    (Get-ActivationSliceCellValue $Row 'Baseline Reference') -cne 'not-applicable'
  ) {
    $errors.Add("$Context $Role selected unit violates canonical resolved-foundation predicates")
  }
}

function Test-ActivationSliceDownstreamSelectedUnitHandoff(
  [object]$Predecessor,
  [object]$Successor,
  [object]$Definition,
  [string]$Context
) {
  $rules = @($Definition.DownstreamUnitRules | Where-Object {
    (Get-ActivationSliceCellValue $_ 'Current step ID') -ceq $Successor.FrontMatter.StepId
  })
  if ($rules.Count -eq 0) { return }
  if ($rules.Count -ne 1) {
    $errors.Add("$Context downstream selected-unit contract must resolve exactly one rule; found $($rules.Count)")
    return
  }
  $rule = $rules[0]
  if ((Get-ActivationSliceCellValue $rule 'Preservation') -cne 'ordinal-exact-predecessor') {
    $errors.Add("$Context downstream selected-unit contract requires ordinal-exact-predecessor preservation")
    return
  }
  $section = Get-ActivationSliceCellValue $rule 'Section'
  $columns = @(
    (Get-ActivationSliceCellValue $rule 'Required columns').Split(',') |
      ForEach-Object { $_.Trim() } |
      Where-Object { $_ -ne '' }
  )
  $currentRow = Get-ActivationSliceExactHandoffRow $Successor.Text $section $columns 'downstream current' $Context
  $predecessorRow = Get-ActivationSliceExactHandoffRow $Predecessor.Text $section $columns 'downstream predecessor' $Context
  if ($null -eq $currentRow -or $null -eq $predecessorRow) { return }
  Test-ActivationSliceRequiredHandoffRow $currentRow $columns $Definition "$Context downstream current selected-unit"
  Test-ActivationSliceRequiredHandoffRow $predecessorRow $columns $Definition "$Context downstream predecessor selected-unit"
  [void](Test-ActivationSliceSelectedUnitIntrinsicState $currentRow $Definition $Context)
  [void](Test-ActivationSliceSelectedUnitIntrinsicState $predecessorRow $Definition $Context)
  foreach ($column in $columns) {
    $currentValue = Get-ActivationSliceCellValue $currentRow $column
    $predecessorValue = Get-ActivationSliceCellValue $predecessorRow $column
    if ([string]::IsNullOrWhiteSpace($currentValue)) {
      $errors.Add("$Context downstream current selected-unit requires non-empty $column")
    }
    if ([string]::IsNullOrWhiteSpace($predecessorValue)) {
      $errors.Add("$Context downstream predecessor selected-unit requires non-empty $column")
    }
    if ($currentValue -cne $predecessorValue) {
      $errors.Add("$Context downstream selected-unit field changed: $column")
    }
  }
}

function Test-ActivationSliceParityVerdictArtifact(
  [object]$Artifact,
  [object]$Definition,
  [string]$Role,
  [string]$Context
) {
  $rules = @($Definition.RegressionParityRules)
  if ($rules.Count -ne 1) {
    $errors.Add("$Context parity verdict contract must declare exactly one rule")
    return $null
  }
  $rule = $rules[0]
  $columns = @(
    (Get-ActivationSliceCellValue $rule 'Predecessor required columns').Split(',') |
      ForEach-Object { $_.Trim() } |
      Where-Object { $_ -ne '' }
  )
  $row = Get-ActivationSliceExactHandoffRow `
    $Artifact.Text `
    (Get-ActivationSliceCellValue $rule 'Predecessor section') `
    $columns `
    $Role `
    $Context
  if ($null -eq $row) { return $null }
  $allowedVerdicts = @(
    (Get-ActivationSliceCellValue $rule 'Parity Verdict Values').Split(',') |
      ForEach-Object { $_.Trim() } |
      Where-Object { $_ -ne '' }
  )
  if ($allowedVerdicts -cnotcontains (Get-ActivationSliceCellValue $row 'Parity Verdict')) {
    $errors.Add("$Context current Parity Verdict must be pass, fail, or blocked")
  }
  if ([string]::IsNullOrWhiteSpace((Get-ActivationSliceCellValue $row 'Evidence Reference'))) {
    $errors.Add("$Context current Parity Verdict requires non-empty Evidence Reference")
  }
  return $row
}

function Test-ActivationSliceAssuranceProvenanceHandoff(
  [object]$Predecessor,
  [object]$Successor,
  [object]$Definition,
  [string]$Context,
  [string]$PredecessorPath,
  [string]$SuccessorPath
) {
  $rules = @($Definition.AssuranceProvenanceRules | Where-Object {
    (Get-ActivationSliceCellValue $_ 'Current step ID') -ceq $Successor.FrontMatter.StepId -and
    (Get-ActivationSliceCellValue $_ 'Predecessor step ID') -ceq $Predecessor.FrontMatter.StepId
  })
  if ($rules.Count -eq 0) { return }
  if ($rules.Count -ne 1) {
    $errors.Add("$Context assurance provenance contract must resolve exactly one rule; found $($rules.Count)")
    return
  }
  $rule = $rules[0]
  $currentSection = Get-ActivationSliceCellValue $rule 'Current section'
  $currentColumns = @(
    (Get-ActivationSliceCellValue $rule 'Current required columns').Split(',') |
      ForEach-Object { Trim-AsciiSpaceTab $_ } |
      Where-Object { $_ -ne '' }
  )
  $predecessorSection = Get-ActivationSliceCellValue $rule 'Predecessor section'
  $predecessorColumns = @(
    (Get-ActivationSliceCellValue $rule 'Predecessor required columns').Split(',') |
      ForEach-Object { Trim-AsciiSpaceTab $_ } |
      Where-Object { $_ -ne '' }
  )
  $currentRow = Get-ActivationSliceExactHandoffRow `
    $Successor.Text $currentSection $currentColumns 'assurance current' $Context
  $predecessorRow = Get-ActivationSliceExactHandoffRow `
    $Predecessor.Text $predecessorSection $predecessorColumns 'assurance predecessor' $Context
  if ($null -eq $currentRow -or $null -eq $predecessorRow) { return }
  foreach ($rowSpec in @(
    [pscustomobject]@{ Row = $currentRow; Columns = $currentColumns; Role = 'current'; Artifact = $Successor },
    [pscustomobject]@{ Row = $predecessorRow; Columns = $predecessorColumns; Role = 'predecessor'; Artifact = $Predecessor }
  )) {
    foreach ($column in $rowSpec.Columns) {
      if ([string]::IsNullOrWhiteSpace((Get-ActivationSliceCellValue $rowSpec.Row $column))) {
        $errors.Add("$Context assurance provenance $($rowSpec.Role) requires non-empty $column")
      }
    }
    $intrinsicPredicates = Get-ActivationSliceCellValue $rule 'Intrinsic predicates'
    if ($intrinsicPredicates -cne 'Task / Unit=Selected Migration Unit.Migration Unit ID, Task-base SHA=non-empty-non-placeholder, Final-tree SHA=non-empty-non-placeholder') {
      $errors.Add("$Context assurance provenance contract has invalid intrinsic predicates")
      continue
    }
    $selectedUnit = Get-ActivationSliceCanonicalSelectedUnitRow `
      $rowSpec.Artifact $Definition "assurance $($rowSpec.Role)" $Context
    if (
      $null -ne $selectedUnit -and
      (Get-ActivationSliceCellValue $rowSpec.Row 'Task / Unit') -cne
        (Get-ActivationSliceCellValue $selectedUnit 'Migration Unit ID')
    ) {
      $errors.Add("$Context assurance provenance $($rowSpec.Role) Task / Unit must equal Selected Migration Unit.Migration Unit ID")
    }
    foreach ($shaColumn in @('Task-base SHA', 'Final-tree SHA')) {
      if (Test-ActivationSlicePlaceholderValue (Get-ActivationSliceCellValue $rowSpec.Row $shaColumn) $Definition) {
        $errors.Add("$Context assurance provenance $($rowSpec.Role) requires non-placeholder $shaColumn")
      }
    }
  }
  foreach ($mapping in @(
    (Get-ActivationSliceCellValue $rule 'Preserved field mapping').Split(',') |
      ForEach-Object { Trim-AsciiSpaceTab $_ } |
      Where-Object { $_ -ne '' }
  )) {
    $parts = @($mapping.Split('=') | ForEach-Object { Trim-AsciiSpaceTab $_ })
    if ($parts.Count -ne 2 -or [string]::IsNullOrWhiteSpace($parts[0]) -or [string]::IsNullOrWhiteSpace($parts[1])) {
      $errors.Add("$Context assurance provenance contract has invalid field mapping: $mapping")
      continue
    }
    if ((Get-ActivationSliceCellValue $currentRow $parts[0]) -cne (Get-ActivationSliceCellValue $predecessorRow $parts[1])) {
      $errors.Add("$Context assurance provenance field changed: $($parts[0])")
    }
  }
  $currentSource = Get-ActivationSliceCellValue $currentRow 'Source Artifact'
  $resolvedCurrentSource = ''
  try {
    if (-not [string]::IsNullOrWhiteSpace($currentSource)) {
      $resolvedCurrentSource = if ([IO.Path]::IsPathRooted($currentSource)) {
        [IO.Path]::GetFullPath($currentSource)
      }
      else {
        $successorDirectory = [IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($SuccessorPath))
        [IO.Path]::GetFullPath((Join-Path $successorDirectory $currentSource))
      }
    }
  }
  catch {
    $resolvedCurrentSource = ''
  }
  $resolvedPredecessorPath = try {
    [IO.Path]::GetFullPath($PredecessorPath)
  }
  catch {
    ''
  }
  $pathComparison = if ([IO.Path]::DirectorySeparatorChar -ceq '\') {
    [StringComparison]::OrdinalIgnoreCase
  }
  else {
    [StringComparison]::Ordinal
  }
  if (
    (Get-ActivationSliceCellValue $rule 'Source Artifact rule') -cne 'resolves-to-immediate-predecessor-path' -or
    [string]::IsNullOrWhiteSpace($resolvedCurrentSource) -or
    -not $resolvedCurrentSource.Equals($resolvedPredecessorPath, $pathComparison)
  ) {
    $errors.Add("$Context assurance provenance Source Artifact must resolve to the immediate predecessor path")
  }
}

function Test-ActivationSliceRegressionParityHandoff(
  [object]$Predecessor,
  [object]$Successor,
  [object]$Definition,
  [string]$Context
) {
  $rules = @($Definition.RegressionParityRules | Where-Object {
    (Get-ActivationSliceCellValue $_ 'Current step ID') -ceq $Successor.FrontMatter.StepId -and
    (Get-ActivationSliceCellValue $_ 'Predecessor step ID') -ceq $Predecessor.FrontMatter.StepId
  })
  if ($rules.Count -eq 0) { return }
  if ($rules.Count -ne 1) {
    $errors.Add("$Context regression parity contract must resolve exactly one rule; found $($rules.Count)")
    return
  }
  Test-ActivationSliceAssuranceVerdictConsistency `
    $Predecessor $Definition "$Context predecessor"
  $rule = $rules[0]
  $predecessorSection = Get-ActivationSliceCellValue $rule 'Predecessor section'
  $predecessorColumns = @(
    (Get-ActivationSliceCellValue $rule 'Predecessor required columns').Split(',') |
      ForEach-Object { $_.Trim() } |
      Where-Object { $_ -ne '' }
  )
  $currentSection = Get-ActivationSliceCellValue $rule 'Current section'
  $currentColumns = @(
    (Get-ActivationSliceCellValue $rule 'Current required columns').Split(',') |
      ForEach-Object { $_.Trim() } |
      Where-Object { $_ -ne '' }
  )
  $predecessorRow = Get-ActivationSliceExactHandoffRow `
    $Predecessor.Text $predecessorSection $predecessorColumns 'regression predecessor' $Context
  $currentRow = Get-ActivationSliceExactHandoffRow `
    $Successor.Text $currentSection $currentColumns 'regression current' $Context
  if ($null -eq $predecessorRow -or $null -eq $currentRow) { return }

  $predecessorVerdict = Get-ActivationSliceCellValue $predecessorRow 'Parity Verdict'
  $predecessorEvidence = Get-ActivationSliceCellValue $predecessorRow 'Evidence Reference'
  $parityVerdictValues = @(
    (Get-ActivationSliceCellValue $rule 'Regression Predecessor Parity Values').Split(',') |
      ForEach-Object { $_.Trim() } |
      Where-Object { $_ -ne '' }
  )
  if ($parityVerdictValues -cnotcontains $predecessorVerdict) {
    $errors.Add("$Context regression predecessor Parity Verdict must be pass or fail")
  }
  if ([string]::IsNullOrWhiteSpace($predecessorEvidence)) {
    $errors.Add("$Context regression predecessor parity verdict requires non-empty Evidence Reference")
  }
  foreach ($column in $currentColumns) {
    if ([string]::IsNullOrWhiteSpace((Get-ActivationSliceCellValue $currentRow $column))) {
      $errors.Add("$Context regression current verdict requires non-empty $column")
    }
  }
  if (
    (Get-ActivationSliceCellValue $currentRow 'Regression Applicability') -cne
      (Get-ActivationSliceCellValue $rule 'Regression Applicability')
  ) {
    $errors.Add("$Context Regression Applicability must be required")
  }
  $regressionVerdictValues = @(
    (Get-ActivationSliceCellValue $rule 'Regression Verdict Values').Split(',') |
      ForEach-Object { $_.Trim() } |
      Where-Object { $_ -ne '' }
  )
  if ($regressionVerdictValues -cnotcontains (Get-ActivationSliceCellValue $currentRow 'Regression Verdict')) {
    $errors.Add("$Context Regression Verdict must be pass, fail, or blocked")
  }
  if ((Get-ActivationSliceCellValue $currentRow 'Parity Verdict') -cne $predecessorVerdict) {
    $errors.Add("$Context regression must preserve predecessor Parity Verdict ordinally")
  }
  $currentEvidence = Get-ActivationSliceCellValue $currentRow 'Evidence Reference'
  $appendPrefix = "$predecessorEvidence; "
  $appendSuffix = if ($currentEvidence.StartsWith($appendPrefix, [StringComparison]::Ordinal)) {
    $currentEvidence.Substring($appendPrefix.Length)
  }
  else { '' }
  $preservesEvidence =
    (Get-ActivationSliceCellValue $rule 'Evidence preservation') -ceq 'exact or <predecessor>; <non-whitespace evidence>' -and
    (
      $currentEvidence -ceq $predecessorEvidence -or
      (-not [string]::IsNullOrWhiteSpace($appendSuffix) -and $appendSuffix -ceq $appendSuffix.Trim())
    )
  if (-not $preservesEvidence) {
    $errors.Add("$Context regression must preserve predecessor parity Evidence Reference")
  }
}

function Test-ActivationSliceAssuranceVerdictConsistency(
  [object]$Artifact,
  [object]$Definition,
  [string]$Context
) {
  $rules = @($Definition.AssuranceVerdictRules | Where-Object {
    (Get-ActivationSliceCellValue $_ 'Step ID') -ceq $Artifact.FrontMatter.StepId
  })
  if ($rules.Count -eq 0) { return }
  if ($rules.Count -ne 1) {
    $errors.Add("$Context assurance verdict contract must resolve exactly one rule; found $($rules.Count)")
    return
  }
  $rule = $rules[0]
  $regressionRules = @($Definition.RegressionParityRules)
  if ($regressionRules.Count -ne 1) {
    $errors.Add("$Context assurance verdict contract requires exactly one regression parity rule")
    return
  }
  $regressionRule = $regressionRules[0]
  $overallField = Get-ActivationSliceCellValue $rule 'Overall verdict field'
  $overallColumns = if ($Artifact.FrontMatter.StepId -ceq '13-verify-parity') {
    @(
      (Get-ActivationSliceCellValue $regressionRule 'Predecessor required columns').Split(',') |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne '' }
    )
  }
  else {
    @(
      (Get-ActivationSliceCellValue $regressionRule 'Current required columns').Split(',') |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne '' }
    )
  }
  $overallRow = Get-ActivationSliceExactHandoffRow `
    $Artifact.Text `
    (Get-ActivationSliceCellValue $rule 'Overall section') `
    $overallColumns `
    'assurance current' `
    $Context
  if ($null -eq $overallRow) { return }

  $legacyConclusionSection = ConvertFrom-Utf8Base64 'S+G6v3QgbHXhuq1u'
  $legacyCount = @(
    Get-MarkdownVisibleHeadingRecords $Artifact.Text |
      Where-Object { $_.Name -ceq $legacyConclusionSection }
  ).Count
  if ($legacyCount -ne 0) {
    $errors.Add("$Context overall verdict must use only the canonical structured row; legacy Kết luận section found $legacyCount")
  }

  $scenarioColumns = @(
    (Get-ActivationSliceCellValue $rule 'Scenario required columns').Split(',') |
      ForEach-Object { $_.Trim() } |
      Where-Object { $_ -ne '' }
  )
  $scenarioSection = Get-ActivationSliceCellValue $rule 'Scenario section'
  $scenarioHeadingCount = @(Get-MarkdownSectionHeadings $Artifact.Text $scenarioSection).Count
  if ($scenarioHeadingCount -ne 1) {
    $errors.Add("$Context assurance scenario section must appear exactly once; found $scenarioHeadingCount")
    return
  }
  $scenarioRows = @(Get-MarkdownTableRows `
    $Artifact.Text $scenarioSection "$Context assurance scenarios" $scenarioColumns)
  if ($scenarioRows.Count -eq 0) {
    $errors.Add("$Context assurance scenarios require at least one row")
    return
  }
  $allowedValues = @(
    (Get-ActivationSliceCellValue $rule 'Verdict values').Split(',') |
      ForEach-Object { $_.Trim() } |
      Where-Object { $_ -ne '' }
  )
  $scenarioVerdicts = [Collections.Generic.List[string]]::new()
  foreach ($scenarioRow in $scenarioRows) {
    foreach ($column in $scenarioColumns) {
      if ([string]::IsNullOrWhiteSpace((Get-ActivationSliceCellValue $scenarioRow $column))) {
        $errors.Add("$Context assurance scenario requires non-empty $column")
      }
    }
    $verdict = Get-ActivationSliceCellValue $scenarioRow 'Verdict'
    if ($allowedValues -cnotcontains $verdict) {
      $errors.Add("$Context assurance scenario Verdict must be pass, fail, or blocked")
    }
    $scenarioVerdicts.Add($verdict)
  }
  $aggregate = if ($scenarioVerdicts -ccontains 'blocked') {
    'blocked'
  }
  elseif ($scenarioVerdicts -ccontains 'fail') {
    'fail'
  }
  else {
    'pass'
  }
  $overallVerdict = Get-ActivationSliceCellValue $overallRow $overallField
  if ($overallVerdict -cne $aggregate) {
    $errors.Add("$Context overall verdict does not match scenario aggregate: $aggregate")
  }
  if (
    $overallVerdict -ceq 'blocked' -and
    ($Artifact.FrontMatter.Status -cne 'draft' -or $Artifact.FrontMatter.Result -cne 'blocked')
  ) {
    $errors.Add("$Context structured blocked verdict requires front matter draft/blocked")
  }
  elseif (
    $overallVerdict -cne 'blocked' -and
    $Artifact.FrontMatter.Result -cne 'complete'
  ) {
    $errors.Add("$Context pass/fail structured verdict requires result: complete")
  }
}

function Test-ActivationSliceImplementationEvidenceRecords(
  [object]$Artifact,
  [object]$ApprovedEnvelope,
  [object]$SelectedUnit,
  [object]$Definition,
  [string]$Context
) {
  if ($null -eq $SelectedUnit) { return }
  $identifierRules = @($Definition.IdentifierRules | Where-Object {
    (Get-ActivationSliceCellValue $_ 'Identifier') -ceq 'Migration Unit ID'
  })
  if ($identifierRules.Count -ne 1) {
    $errors.Add("$Context implementation evidence contract requires one Migration Unit ID format")
    return
  }
  $unitPattern = Get-ActivationSliceCellValue $identifierRules[0] 'Required format'
  $selectedUnitId = Get-ActivationSliceCellValue $SelectedUnit 'Migration Unit ID'
  foreach ($linkRule in @($Definition.LinkRules | Where-Object {
    (Get-ActivationSliceCellValue $_ 'Record') -cne 'selected-unit'
  })) {
    $record = Get-ActivationSliceCellValue $linkRule 'Record'
    $section = Get-ActivationSliceCellValue $linkRule 'Section'
    $columns = @(
      (Get-ActivationSliceCellValue $linkRule 'Required columns').Split(',') |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne '' }
    )
    $headingCount = @(Get-MarkdownSectionHeadings $Artifact.Text $section).Count
    if ($headingCount -ne 1) {
      $errors.Add("$Context $record structured section must appear exactly once; found $headingCount")
      continue
    }
    $rows = @(Get-MarkdownTableRows $Artifact.Text $section "$Context $record linkage" $columns)
    if ($rows.Count -eq 0) {
      $errors.Add("$Context $record linkage requires at least one structured record")
      continue
    }
    foreach ($row in $rows) {
      foreach ($column in $columns) {
        if ([string]::IsNullOrWhiteSpace((Get-ActivationSliceCellValue $row $column))) {
          $errors.Add("$Context $record record requires non-empty $column")
        }
      }
      $unitId = Get-ActivationSliceCellValue $row 'Migration Unit ID'
      if (-not [string]::IsNullOrWhiteSpace($unitId) -and $unitId -cnotmatch "^$unitPattern$") {
        $errors.Add("$Context $record Migration Unit ID must match $unitPattern`: $unitId")
      }
      elseif ($unitId -cne $selectedUnitId) {
        $errors.Add("$Context $record Migration Unit ID $unitId does not match selected Migration Unit ID $selectedUnitId")
      }
      $sliceId = Get-ActivationSliceCellValue $row 'Activation Slice ID'
      $seam = Get-ActivationSliceCellValue $row 'Seam'
      $traceIds = @(
        (Get-ActivationSliceCellValue $row 'Trace IDs').Split(',') |
          ForEach-Object { $_.Trim() } |
          Where-Object { $_ -ne '' }
      )
      if ([string]::IsNullOrWhiteSpace($sliceId) -or [string]::IsNullOrWhiteSpace($seam) -or $traceIds.Count -eq 0) {
        continue
      }
      if (-not $ApprovedEnvelope.Slices.ContainsKey($sliceId)) {
        $errors.Add("$Context $record link references unknown approved Activation Slice ID: $sliceId")
        continue
      }
      $slice = $ApprovedEnvelope.Slices[$sliceId]
      if ($slice.Seams -cnotcontains $seam) {
        $errors.Add("$Context $record link $sliceId references unknown approved seam: $seam")
        continue
      }
      $approvedTraceIds = @($slice.TraceIds[$seam])
      $unapprovedTraceIds = @($traceIds | Where-Object { $approvedTraceIds -cnotcontains $_ })
      if ($unapprovedTraceIds.Count -gt 0) {
        $errors.Add("$Context $record link $sliceId/$seam has unapproved Trace IDs: $($unapprovedTraceIds -join ', ')")
      }
    }
  }
}

function Test-ActivationSliceDirectPlanFoundationState(
  [object]$CurrentRow,
  [object]$PlanRow,
  [object]$Predecessor,
  [object]$Definition,
  [string]$Context
) {
  $mode = Get-ActivationSliceCellValue $CurrentRow 'Mode Constraint'
  $scope = Get-ActivationSliceCellValue $CurrentRow 'Bootstrap Scope'
  $rules = @($Definition.DirectPlanFoundationRules | Where-Object {
    (Get-ActivationSliceCellValue $_ 'Mode Constraint') -ceq $mode -and
    (Get-ActivationSliceCellValue $_ 'Bootstrap Scope') -ceq $scope
  })
  if ($rules.Count -ne 1) {
    $errors.Add("$Context direct-plan foundation state must resolve exactly one mode rule; found $($rules.Count)")
    return
  }
  $rule = $rules[0]
  if ($mode -ceq 'incremental/preserve-existing') {
    $isValid =
      (Get-ActivationSliceCellValue $PlanRow 'Foundation Baseline ID') -ceq (Get-ActivationSliceCellValue $rule 'Plan Foundation Baseline ID') -and
      (Get-ActivationSliceCellValue $PlanRow 'Foundation Approval Reference') -ceq (Get-ActivationSliceCellValue $rule 'Plan Foundation Approval Reference') -and
      (Get-ActivationSliceCellValue $CurrentRow 'Foundation Baseline ID') -ceq (Get-ActivationSliceCellValue $rule 'Current Foundation Baseline ID') -and
      (Get-ActivationSliceCellValue $CurrentRow 'Foundation Baseline Reference') -ceq (Get-ActivationSliceCellValue $rule 'Current Foundation Baseline Reference') -and
      (Get-ActivationSliceCellValue $CurrentRow 'Foundation Baseline Approval Reference') -ceq (Get-ActivationSliceCellValue $rule 'Current Foundation Baseline Approval Reference') -and
      (Get-ActivationSliceCellValue $rule 'Current Baseline Reference') -ceq '<resolved-pre-mutation-baseline-reference>' -and
      (Test-ActivationSliceResolvedEvidenceReference (Get-ActivationSliceCellValue $CurrentRow 'Baseline Reference') $Definition)
    if (-not $isValid) {
      $errors.Add("$Context direct-plan foundation state violates the incremental canonical tuple")
    }
    return
  }

  $planFoundationId = Get-ActivationSliceCellValue $PlanRow 'Foundation Baseline ID'
  $planApproval = Get-ActivationSliceCellValue $PlanRow 'Foundation Approval Reference'
  $currentFoundationId = Get-ActivationSliceCellValue $CurrentRow 'Foundation Baseline ID'
  $currentReference = Get-ActivationSliceCellValue $CurrentRow 'Foundation Baseline Reference'
  $currentApproval = Get-ActivationSliceCellValue $CurrentRow 'Foundation Baseline Approval Reference'
  $tupleIsValid =
    $mode -ceq 'greenfield/design-new' -and
    $planFoundationId -cmatch '^FOUNDATION-[A-Za-z0-9._-]+$' -and
    (Test-ActivationSliceResolvedEvidenceReference $planApproval $Definition) -and
    $currentFoundationId -ceq $planFoundationId -and
    (Test-ActivationSliceResolvedEvidenceReference $currentReference $Definition) -and
    $currentApproval -ceq $planApproval -and
    (Get-ActivationSliceCellValue $CurrentRow 'Baseline Reference') -ceq 'not-applicable'
  if (-not $tupleIsValid) {
    $errors.Add("$Context direct-plan foundation state violates the greenfield canonical tuple")
  }

  $foundationSection = Get-ActivationSliceCellValue $rule 'Foundation Section'
  $foundationColumns = @(
    (Get-ActivationSliceCellValue $rule 'Foundation required columns').Split(',') |
      ForEach-Object { $_.Trim() } |
      Where-Object { $_ -ne '' }
  )
  $foundationRow = Get-ActivationSliceExactHandoffRow `
    $Predecessor.Text $foundationSection $foundationColumns 'direct-plan predecessor' $Context
  if ($null -eq $foundationRow) { return }
  foreach ($column in $foundationColumns) {
    if ([string]::IsNullOrWhiteSpace((Get-ActivationSliceCellValue $foundationRow $column))) {
      $errors.Add("$Context direct-plan predecessor foundation record requires non-empty $column")
    }
  }
  if (
    (Get-ActivationSliceCellValue $foundationRow 'Foundation Baseline ID') -cne $planFoundationId -or
    (Get-ActivationSliceCellValue $foundationRow 'Target Baseline Reference') -cne $currentReference -or
    (Get-ActivationSliceCellValue $foundationRow 'Approval Reference') -cne $planApproval -or
    (Get-ActivationSliceCellValue $foundationRow 'Approval Status') -cne 'approved'
  ) {
    $errors.Add("$Context direct-plan predecessor foundation record must match the approved selected tuple")
  }
}

function Test-ActivationSliceImplementationLinks(
  [string]$Text,
  [object]$Artifact,
  [object]$Predecessor,
  [string]$Context,
  [object]$Definition,
  [object]$HandoffRule
) {
  $linkRules = @($Definition.LinkRules)
  if ($linkRules.Count -eq 0) { return }
  $currentStepIds = @(Get-CaseSensitiveUniqueStrings @(
    $linkRules | ForEach-Object { Get-ActivationSliceCellValue $_ 'Current step ID' }
  ))
  if ($currentStepIds.Count -ne 1) {
    $errors.Add("$Context implementation linkage contract must declare exactly one current step ID")
    return
  }
  $currentStepId = $currentStepIds[0]
  $linkSections = @(Get-CaseSensitiveUniqueStrings @(
    $linkRules |
      Where-Object { (Get-ActivationSliceCellValue $_ 'Record') -cne 'selected-unit' } |
      ForEach-Object { Get-ActivationSliceCellValue $_ 'Section' }
  ))
  $hasLinkSection = @(
    $linkSections | Where-Object { @(Get-MarkdownSectionHeadings $Text $_).Count -gt 0 }
  ).Count -gt 0
  if ($Artifact.FrontMatter.StepId -cne $currentStepId) {
    if ($hasLinkSection) {
      $errors.Add("$Context implementation linkage sections require front matter step_id: $currentStepId")
    }
    return
  }
  $invocation = if ($null -ne $HandoffRule) {
    Get-ActivationSliceCellValue $HandoffRule 'Route'
  }
  elseif ($Artifact.FrontMatter.Result -ceq 'partial') {
    'baseline-waiver-resume'
  }
  else {
    'initial'
  }
  $predecessorRules = @($Definition.Step10UnitRules | Where-Object {
    (Get-ActivationSliceCellValue $_ 'Invocation') -ceq $invocation
  })
  $allowedPredecessorStepIds = @($predecessorRules | ForEach-Object {
    Get-ActivationSliceCellValue $_ 'Predecessor step ID'
  })
  if ($null -eq $Predecessor) {
    if ($invocation -ceq 'baseline-waiver-resume') {
      $errors.Add("$Context baseline-waiver resume requires predecessor step_id: $($allowedPredecessorStepIds -join ' or ')")
    }
    else {
      $errors.Add("$Context implementation links require predecessor front matter status: approved and result: complete")
    }
    return
  }
  if ($allowedPredecessorStepIds -cnotcontains $Predecessor.FrontMatter.StepId) {
    if ($invocation -ceq 'baseline-waiver-resume') {
      $errors.Add("$Context baseline-waiver resume requires predecessor step_id: $($allowedPredecessorStepIds -join ' or ')")
    }
    else {
      $errors.Add("$Context implementation links require approved immediate predecessor step_id: $($allowedPredecessorStepIds -join ' or ')")
    }
    return
  }

  $matchingPredecessorRules = @($predecessorRules | Where-Object {
    (Get-ActivationSliceCellValue $_ 'Predecessor step ID') -ceq $Predecessor.FrontMatter.StepId
  })
  if ($null -eq $HandoffRule -or $Predecessor.HasBlockingErrors -or $matchingPredecessorRules.Count -ne 1) {
    if ($invocation -ceq 'baseline-waiver-resume') {
      $errors.Add("$Context baseline-waiver resume predecessor requires exact approved/partial/auto-waive waiver tuple")
    }
    else {
      $errors.Add("$Context implementation links require predecessor front matter status: approved and result: complete")
    }
    return
  }
  $matchingPredecessorRule = $matchingPredecessorRules[0]
  if (
    $invocation -ceq 'baseline-waiver-resume' -and
    -not (Test-ActivationSliceWaiverPreserved $Artifact.FrontMatter $Predecessor.FrontMatter)
  ) {
    $errors.Add("$Context baseline-waiver resume must preserve predecessor waiver fields verbatim")
  }

  $linkBlockingErrorStart = $errors.Count
  try {
  $selectedUnitRules = @($linkRules | Where-Object {
    (Get-ActivationSliceCellValue $_ 'Record') -ceq 'selected-unit'
  })
  if ($selectedUnitRules.Count -ne 1) {
    $errors.Add("$Context implementation linkage contract must declare exactly one selected-unit record")
    return
  }
  $selectedUnitRule = $selectedUnitRules[0]
  $selectedUnitSection = Get-ActivationSliceCellValue $matchingPredecessorRule 'Current Unit Section'
  if ($selectedUnitSection -cne (Get-ActivationSliceCellValue $selectedUnitRule 'Section')) {
    $errors.Add("$Context implementation linkage contract selected-unit section does not match Step 10 unit selection")
    return
  }
  $selectedUnitColumns = @(
    (Get-ActivationSliceCellValue $selectedUnitRule 'Required columns').Split(',') |
      ForEach-Object { $_.Trim() } |
      Where-Object { $_ -ne '' }
  )
  $migrationUnitIdRules = @($Definition.IdentifierRules | Where-Object {
    (Get-ActivationSliceCellValue $_ 'Identifier') -ceq 'Migration Unit ID'
  })
  if ($migrationUnitIdRules.Count -ne 1) {
    $errors.Add("$Context implementation linkage contract must declare exactly one Migration Unit ID format")
    return
  }
  $migrationUnitIdPattern = Get-ActivationSliceCellValue $migrationUnitIdRules[0] 'Required format'

  $currentSelectedUnitHeadingCount = @(Get-MarkdownSectionHeadings $Text $selectedUnitSection).Count
  $currentSelectedUnitRows = @()
  if ($currentSelectedUnitHeadingCount -ne 1) {
    $errors.Add("$Context current selected-unit section must appear exactly once; found $currentSelectedUnitHeadingCount")
  }
  else {
    $currentSelectedUnitRows = @(Get-MarkdownTableRows `
      $Text `
      $selectedUnitSection `
      "$Context current selected-unit linkage" `
      $selectedUnitColumns)
  }
  if ($currentSelectedUnitRows.Count -ne 1) {
    $errors.Add("$Context requires exactly one current Selected Migration Unit record; found $($currentSelectedUnitRows.Count)")
  }

  $currentSelectedUnitId = ''
  $predecessorSelectedUnitId = ''
  if ($currentSelectedUnitRows.Count -eq 1) {
    foreach ($column in $selectedUnitColumns) {
      if ([string]::IsNullOrWhiteSpace((Get-ActivationSliceCellValue $currentSelectedUnitRows[0] $column))) {
        $errors.Add("$Context selected-unit record requires non-empty $column")
      }
    }
    $currentSelectedUnitId = Get-ActivationSliceCellValue $currentSelectedUnitRows[0] 'Migration Unit ID'
    if (
      -not [string]::IsNullOrWhiteSpace($currentSelectedUnitId) -and
      $currentSelectedUnitId -cnotmatch "^$migrationUnitIdPattern$"
    ) {
      $errors.Add("$Context selected-unit Migration Unit ID must match $migrationUnitIdPattern`: $currentSelectedUnitId")
    }
    [void](Test-ActivationSliceSelectedUnitIntrinsicState $currentSelectedUnitRows[0] $Definition $Context)
    $requiredMode = Get-ActivationSliceCellValue $matchingPredecessorRule 'Required Mode Constraint'
    $requiredScope = Get-ActivationSliceCellValue $matchingPredecessorRule 'Required Bootstrap Scope'
    $actualMode = Get-ActivationSliceCellValue $currentSelectedUnitRows[0] 'Mode Constraint'
    $actualScope = Get-ActivationSliceCellValue $currentSelectedUnitRows[0] 'Bootstrap Scope'
    $canonicalPair =
      ($actualMode -ceq 'incremental/preserve-existing' -and $actualScope -ceq 'not-required') -or
      ($actualMode -ceq 'greenfield/design-new' -and $actualScope -cin @('required', 'not-required'))
    $modeMatches = if ($requiredMode -ceq '<canonical>') { $canonicalPair } else { $actualMode -ceq $requiredMode }
    $scopeMatches = if ($requiredScope -ceq '<canonical>') { $canonicalPair } else { $actualScope -ceq $requiredScope }
    if (-not $modeMatches -or -not $scopeMatches) {
      if ($invocation -ceq 'baseline-waiver-resume') {
        $errors.Add("$Context resume selected-unit Mode Constraint must be incremental/preserve-existing")
      }
      elseif ($Predecessor.FrontMatter.StepId -ceq '08-plan-waves') {
        $errors.Add("$Context initial plan route requires selected-unit Bootstrap Scope not-required")
      }
      else {
        $errors.Add("$Context bootstrap implementation route requires greenfield/design-new and required selected unit")
      }
    }
  }

  $predecessorUnitSection = Get-ActivationSliceCellValue $matchingPredecessorRule 'Predecessor Unit Section'
  $predecessorUnitSelection = Get-ActivationSliceCellValue $matchingPredecessorRule 'Predecessor Unit Selection'
  $predecessorUnitColumns = @(
    (Get-ActivationSliceCellValue $matchingPredecessorRule 'Predecessor Unit Required Columns').Split(',') |
      ForEach-Object { $_.Trim() } |
      Where-Object { $_ -ne '' }
  )
  $predecessorUnitApproval = Get-ActivationSliceCellValue $matchingPredecessorRule 'Predecessor Unit Approval'
  if (
    [string]::IsNullOrWhiteSpace($predecessorUnitSection) -or
    [string]::IsNullOrWhiteSpace($predecessorUnitSelection) -or
    $predecessorUnitColumns.Count -eq 0 -or
    [string]::IsNullOrWhiteSpace($predecessorUnitApproval)
  ) {
    $errors.Add("$Context implementation linkage contract predecessor unit rule is incomplete")
    return
  }
  $predecessorUnitHeadingCount = @(Get-MarkdownSectionHeadings $Predecessor.Text $predecessorUnitSection).Count
  $predecessorUnitRows = @()
  if ($predecessorUnitHeadingCount -ne 1) {
    $errors.Add("$Context predecessor unit section must appear exactly once; found $predecessorUnitHeadingCount")
  }
  else {
    $predecessorUnitRows = @(Get-MarkdownTableRows `
      $Predecessor.Text `
      $predecessorUnitSection `
      "$Context predecessor unit linkage" `
      $predecessorUnitColumns)
  }

  $selectionBehavior = if ($predecessorUnitSelection -ceq 'ordinal-exact-current') {
    'exactly-one-current-match'
  }
  else {
    $predecessorUnitSelection
  }
  $matchingPredecessorUnitRows = @()
  switch -CaseSensitive ($selectionBehavior) {
    'exactly-one-approved-current-match' {
      $approvalSeparator = $predecessorUnitApproval.IndexOf('=', [StringComparison]::Ordinal)
      if ($approvalSeparator -le 0 -or $approvalSeparator -eq ($predecessorUnitApproval.Length - 1)) {
        $errors.Add("$Context implementation linkage contract predecessor unit approval rule is invalid")
        return
      }
      $approvalColumn = $predecessorUnitApproval.Substring(0, $approvalSeparator).Trim()
      $approvalValue = $predecessorUnitApproval.Substring($approvalSeparator + 1).Trim()
      if ($predecessorUnitColumns -cnotcontains $approvalColumn) {
        $errors.Add("$Context implementation linkage contract predecessor unit approval column is not declared: $approvalColumn")
        return
      }
      foreach ($predecessorUnitRow in $predecessorUnitRows) {
        foreach ($column in $predecessorUnitColumns) {
          if ([string]::IsNullOrWhiteSpace((Get-ActivationSliceCellValue $predecessorUnitRow $column))) {
            $errors.Add("$Context predecessor ordered-unit record requires non-empty $column")
          }
        }
      }
      $matchingPredecessorUnitRows = @($predecessorUnitRows | Where-Object {
        (Get-ActivationSliceCellValue $_ 'Migration Unit ID') -ceq $currentSelectedUnitId -and
        (Get-ActivationSliceCellValue $_ $approvalColumn) -ceq $approvalValue
      })
      if ($matchingPredecessorUnitRows.Count -ne 1) {
        $errors.Add("$Context requires exactly one approved predecessor ordered-unit record matching current Migration Unit ID $currentSelectedUnitId; found $($matchingPredecessorUnitRows.Count)")
      }
      else {
        $predecessorSelectedUnitId = Get-ActivationSliceCellValue $matchingPredecessorUnitRows[0] 'Migration Unit ID'
      }
    }
    'exactly-one-current-match' {
      if ($predecessorUnitRows.Count -ne 1) {
        $errors.Add("$Context requires exactly one predecessor Selected Migration Unit record; found $($predecessorUnitRows.Count)")
      }
      else {
        $matchingPredecessorUnitRows = @($predecessorUnitRows[0])
        foreach ($column in $predecessorUnitColumns) {
          if ([string]::IsNullOrWhiteSpace((Get-ActivationSliceCellValue $predecessorUnitRows[0] $column))) {
            $errors.Add("$Context predecessor selected-unit record requires non-empty $column")
          }
        }
        $predecessorSelectedUnitId = Get-ActivationSliceCellValue $predecessorUnitRows[0] 'Migration Unit ID'
        [void](Test-ActivationSliceSelectedUnitIntrinsicState $predecessorUnitRows[0] $Definition $Context)
        if (
          -not [string]::IsNullOrWhiteSpace($predecessorSelectedUnitId) -and
          $predecessorSelectedUnitId -cnotmatch "^$migrationUnitIdPattern$"
        ) {
          $errors.Add("$Context predecessor selected-unit Migration Unit ID must match $migrationUnitIdPattern`: $predecessorSelectedUnitId")
        }
        if (
          $currentSelectedUnitId -cmatch "^$migrationUnitIdPattern$" -and
          $predecessorSelectedUnitId -cmatch "^$migrationUnitIdPattern$" -and
          $currentSelectedUnitId -cne $predecessorSelectedUnitId
        ) {
          $errors.Add("$Context current Selected Migration Unit ID $currentSelectedUnitId does not match predecessor $predecessorSelectedUnitId")
        }
      }
    }
    default {
      $errors.Add("$Context implementation linkage contract has unsupported predecessor unit selection: $predecessorUnitSelection")
      return
    }
  }

  if ($currentSelectedUnitRows.Count -eq 1 -and $matchingPredecessorUnitRows.Count -eq 1) {
    $currentSelectedUnitRow = $currentSelectedUnitRows[0]
    $predecessorSelectedUnitRow = $matchingPredecessorUnitRows[0]
    $preservation = Get-ActivationSliceCellValue $matchingPredecessorRule 'Selected Unit Preservation'
    if ($preservation -ceq 'ordinal-exact-predecessor') {
      $changeLabel = if ($Predecessor.FrontMatter.StepId -ceq '09-bootstrap-target') { 'bootstrap' } else { 'resume' }
      foreach ($column in $selectedUnitColumns) {
        if (
          (Get-ActivationSliceCellValue $currentSelectedUnitRow $column) -cne
            (Get-ActivationSliceCellValue $predecessorSelectedUnitRow $column)
        ) {
          $errors.Add("$Context $changeLabel selected-unit field changed: $column")
        }
      }
    }
    elseif ($preservation -ceq 'mapped-plan-fields') {
      foreach ($fieldPair in @(
        @('Migration Unit ID', 'Migration Unit ID'),
        @('Approval Reference', 'Approval Reference'),
        @('Mode Constraint', 'Mode Constraint'),
        @('Bootstrap Scope', 'Bootstrap Scope'),
        @('Foundation Baseline ID', 'Foundation Baseline ID'),
        @('Foundation Baseline Approval Reference', 'Foundation Approval Reference'),
        @('Trace IDs', 'Trace IDs')
      )) {
        if (
          (Get-ActivationSliceCellValue $currentSelectedUnitRow $fieldPair[0]) -cne
            (Get-ActivationSliceCellValue $predecessorSelectedUnitRow $fieldPair[1])
        ) {
          $errors.Add("$Context initial selected-unit mapped field changed: $($fieldPair[0])")
        }
      }
      if ((Get-ActivationSliceCellValue $matchingPredecessorRule 'Foundation Record') -ceq 'mode-aware-direct-plan') {
        Test-ActivationSliceDirectPlanFoundationState `
          $currentSelectedUnitRow `
          $predecessorSelectedUnitRow `
          $Predecessor `
          $Definition `
          $Context
      }
    }
    else {
      $errors.Add("$Context implementation linkage contract has unsupported selected-unit preservation: $preservation")
    }

    if ($invocation -ceq 'baseline-waiver-resume') {
      foreach ($resumeRow in @($currentSelectedUnitRow, $predecessorSelectedUnitRow)) {
        if (
          (Get-ActivationSliceCellValue $resumeRow 'Baseline Reference') -cne
            [string]$Artifact.FrontMatter.Waiver['evidence']
        ) {
          $errors.Add("$Context resume selected-unit Baseline Reference must equal waiver.evidence ordinally")
        }
      }
      Test-ActivationSliceStep10ResumeEvidence `
        $Artifact `
        $Predecessor `
        $currentSelectedUnitRow `
        $predecessorSelectedUnitRow `
        $selectedUnitColumns `
        $Definition `
        $Context
    }

    if ((Get-ActivationSliceCellValue $matchingPredecessorRule 'Foundation Record') -ceq 'approved-matching') {
      Test-ActivationSliceResolvedFoundationSelectedUnit `
        $predecessorSelectedUnitRow $Definition 'bootstrap predecessor' $Context
      $bootstrapRules = @($Definition.BootstrapUnitRules | Where-Object {
        (Get-ActivationSliceCellValue $_ 'Current lifecycle') -ceq 'approved/complete'
      })
      if ($bootstrapRules.Count -ne 1) {
        $errors.Add("$Context bootstrap foundation contract must declare exactly one rule")
      }
      else {
        $bootstrapRule = $bootstrapRules[0]
        $foundationColumns = @(
          (Get-ActivationSliceCellValue $bootstrapRule 'Foundation required columns').Split(',') |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ -ne '' }
        )
        $foundationSection = Get-ActivationSliceCellValue $bootstrapRule 'Foundation Section'
        $foundationRow = Get-ActivationSliceExactHandoffRow `
          $Predecessor.Text $foundationSection $foundationColumns 'bootstrap predecessor' $Context
        if ($null -ne $foundationRow) {
          foreach ($column in $foundationColumns) {
            if ([string]::IsNullOrWhiteSpace((Get-ActivationSliceCellValue $foundationRow $column))) {
              $errors.Add("$Context bootstrap predecessor foundation record requires non-empty $column")
            }
          }
          if (
            (Get-ActivationSliceCellValue $foundationRow 'Foundation Baseline ID') -cne (Get-ActivationSliceCellValue $predecessorSelectedUnitRow 'Foundation Baseline ID') -or
            (Get-ActivationSliceCellValue $foundationRow 'Source Migration Unit ID') -cne (Get-ActivationSliceCellValue $predecessorSelectedUnitRow 'Migration Unit ID') -or
            (Get-ActivationSliceCellValue $foundationRow 'Target Baseline Reference') -cne (Get-ActivationSliceCellValue $predecessorSelectedUnitRow 'Foundation Baseline Reference') -or
            (Get-ActivationSliceCellValue $foundationRow 'Approval Reference') -cne (Get-ActivationSliceCellValue $predecessorSelectedUnitRow 'Foundation Baseline Approval Reference') -or
            (Get-ActivationSliceCellValue $foundationRow 'Approval Status') -cne 'approved'
          ) {
            $errors.Add("$Context bootstrap predecessor foundation record must correlate with selected unit and be approved")
          }
        }
      }
    }
  }

  if (
    $currentSelectedUnitRows.Count -eq 1 -and
    ($Artifact.FrontMatter.Result -cne 'blocked' -or $hasLinkSection)
  ) {
    Test-ActivationSliceImplementationEvidenceRecords `
      $Artifact $Predecessor $currentSelectedUnitRows[0] $Definition $Context
  }
  }
  finally {
    $Artifact.LinkBlockingErrorCount = $errors.Count - $linkBlockingErrorStart
  }
}

function Test-ApprovedFixtureArtifactFrontMatter([string]$Text, [string]$StepId, [string]$Context) {
  $expectedPattern = "\A---\r?\nstep_id: $([regex]::Escape($StepId))\r?\nstatus: approved\r?\nresult: complete\r?\napproval_source: human\r?\nproduced_at: 2026-08-11\r?\n---(?:\r?\n|\z)"
  if ($Text -notmatch $expectedPattern) {
    $errors.Add("$Context front matter must exactly declare step_id, approved status, complete result, human approval source, and produced_at")
  }
}

function Test-ApprovedFixtureArtifactRoute(
  [string]$CurrentPath,
  [string]$PredecessorPath,
  [string]$Context
) {
  $definition = Get-ActivationSliceContractDefinition
  $predecessorText = Get-Content -Raw -Encoding utf8 -LiteralPath $PredecessorPath
  $currentText = Get-Content -Raw -Encoding utf8 -LiteralPath $CurrentPath
  $predecessor = Test-ActivationSliceArtifact $predecessorText "$Context predecessor" $definition
  Test-ActivationSliceFrontMatter `
    $predecessor `
    $predecessor.HasBlockingErrors `
    "$Context predecessor" `
    $definition
  Test-ActivationSlicePreselectionArtifactState `
    $predecessor $definition 'predecessor' $Context

  $current = Test-ActivationSliceArtifact $currentText "$Context current" $definition
  $currentHasBlockingErrors = $current.HasBlockingErrors
  $handoffErrorStart = $errors.Count
  $handoffRule = Get-ActivationSliceImmediatePredecessorRule `
    $predecessor $current $definition $Context
  if ($null -ne $handoffRule) {
    $routeErrorStart = $errors.Count
    [void](Test-ActivationSliceSelectedRoute $current $handoffRule $definition $Context)
    Test-ActivationSliceBootstrapHandoff $predecessor $current $definition $Context
    if ($errors.Count -eq $routeErrorStart) {
      Test-ActivationSliceHandoff $predecessor $current $definition
      Test-ActivationSliceDownstreamSelectedUnitHandoff `
        $predecessor $current $definition $Context
      Test-ActivationSliceRegressionParityHandoff `
        $predecessor $current $definition $Context
    }
  }
  $currentHasBlockingErrors = $currentHasBlockingErrors -or ($errors.Count -gt $handoffErrorStart)
  Test-ActivationSliceImplementationLinks `
    $currentText $current $predecessor $Context $definition $handoffRule
  $currentHasBlockingErrors = `
    $currentHasBlockingErrors -or ($current.LinkBlockingErrorCount -gt 0)
  $assuranceErrorStart = $errors.Count
  Test-ActivationSliceAssuranceVerdictConsistency $current $definition $Context
  $currentHasBlockingErrors = `
    $currentHasBlockingErrors -or ($errors.Count -gt $assuranceErrorStart)
  Test-ActivationSliceFrontMatter `
    $current $currentHasBlockingErrors $Context $definition ($null -ne $handoffRule)
}

function Test-TruthfulMigrationWaiverSkills {
  $orchestratorPath = Join-Path $root 'skills/aitoolkit/migrate/SKILL.md'
  $codeMigrationPath = Join-Path $root 'skills/migration/code-migration/SKILL.md'
  $verificationPath = Join-Path $root 'skills/shared/verification-testing/SKILL.md'
  $knowledgePath = Join-Path $root 'skills/shared/knowledge-base/SKILL.md'
  foreach ($requiredPath in @($orchestratorPath, $codeMigrationPath, $verificationPath, $knowledgePath)) {
    if (-not (Test-Path $requiredPath)) {
      $errors.Add("Truthful migration waiver contract missing file: $requiredPath")
      return
    }
  }

  $orchestratorText = Get-Content -Raw -Encoding utf8 $orchestratorPath
  $eligibleSection = 'Waiver-eligible environment blockers'
  Test-MarkdownTableExactColumns `
    $orchestratorText `
    $eligibleSection `
    @('Native blocker', 'Required evidence', 'Category', 'interactive', 'auto', 'auto-waive') `
    'Migration environment-waiver eligibility'
  $eligibleRows = @(Get-MarkdownTableRows `
    $orchestratorText `
    $eligibleSection `
    'Migration environment-waiver eligibility')
  $eligibleBlockers = @(
    'dependency/tool executable absent'
    'device/emulator/service unavailable'
    'network dependency unavailable'
    'command cannot start because environment capability is absent'
    'pre-mutation baseline cannot be collected solely for one of those reasons'
  )
  if ($eligibleRows.Count -ne $eligibleBlockers.Count) {
    $errors.Add("Migration environment-waiver eligibility must contain exactly $($eligibleBlockers.Count) scenarios; found $($eligibleRows.Count)")
  }
  foreach ($blocker in $eligibleBlockers) {
    $matches = @($eligibleRows | Where-Object { $_.'Native blocker' -ceq $blocker })
    if ($matches.Count -ne 1) {
      $errors.Add("Migration environment-waiver eligible scenario missing or duplicated: $blocker")
      continue
    }
    $row = $matches[0]
    if (
      $row.Category -cne '`environment-unavailable`' -or
      $row.interactive -cne 'stop with native blocker' -or
      $row.auto -cne 'stop with native blocker' -or
      $row.'auto-waive' -cne 'continue with exact partial waiver'
    ) {
      $errors.Add("Migration environment-waiver eligible scenario has invalid mode action: $blocker")
    }
    if ([string]::IsNullOrWhiteSpace($row.'Required evidence') -or $row.'Required evidence' -notmatch '(?i)verbatim') {
      $errors.Add("Migration environment-waiver eligible scenario lacks verbatim evidence: $blocker")
    }
  }

  $decisionSection = 'Environment blocker decision order'
  Test-MarkdownTableExactColumns `
    $orchestratorText `
    $decisionSection `
    @(
      'Priority', 'Scenario', 'Evidence Command Role', 'Required Command Lifecycle',
      'Classification', 'interactive', 'auto', 'auto-waive'
    ) `
    'Migration environment-waiver decision order'
  $decisionText = Get-MarkdownSectionBody `
    $orchestratorText `
    $decisionSection `
    'Migration environment-waiver decision order'
  @(
    'Evaluate lower priority numbers first.',
    'A nonzero availability probe is capability evidence, not a correctness/regression result from the required command.',
    'Any started required command is waiver-ineligible, whether or not it produces a correctness/regression result.'
  ) | ForEach-Object {
    Require-Token $decisionText $_ 'Migration environment-waiver decision order'
  }
  $decisionRows = @(Get-MarkdownTableRows `
    $orchestratorText `
    $decisionSection `
    'Migration environment-waiver decision order')
  $expectedDecisionRows = @(
    [pscustomobject]@{
      Priority = '1'
      Scenario = 'required command starts and returns real failure while environment symptom also exists'
      Role = '`required test/build/baseline command`'
      Lifecycle = '`started-and-produced-correctness/regression-result`'
      Classification = '`waiver-ineligible`'
      Interactive = 'stop with native blocker'
      Auto = 'stop with native blocker'
      AutoWaive = 'stop with native blocker'
    }
    [pscustomobject]@{
      Priority = '2'
      Scenario = 'required command starts but produces no correctness/regression result while environment symptom also exists'
      Role = '`required test/build/baseline command`'
      Lifecycle = '`started-without-correctness/regression-result`'
      Classification = '`waiver-ineligible`'
      Interactive = 'stop with native blocker'
      Auto = 'stop with native blocker'
      AutoWaive = 'stop with native blocker'
    }
    [pscustomobject]@{
      Priority = '3'
      Scenario = 'required command never starts because a failed availability probe establishes an absent dependency'
      Role = '`availability probe`'
      Lifecycle = '`not-started`'
      Classification = '`environment-unavailable`'
      Interactive = 'stop with native blocker'
      Auto = 'stop with native blocker'
      AutoWaive = 'continue with exact partial waiver'
    }
    [pscustomobject]@{
      Priority = '4'
      Scenario = 'command role or lifecycle missing, ambiguous or contradictory'
      Role = '`missing-or-ambiguous`'
      Lifecycle = '`unknown-or-contradictory`'
      Classification = '`waiver-ineligible`'
      Interactive = 'stop with native blocker'
      Auto = 'stop with native blocker'
      AutoWaive = 'stop with native blocker'
    }
  )
  if ($decisionRows.Count -ne $expectedDecisionRows.Count) {
    $errors.Add("Migration environment-waiver decision order must contain exactly $($expectedDecisionRows.Count) scenarios; found $($decisionRows.Count)")
  }
  foreach ($expected in $expectedDecisionRows) {
    $matches = @($decisionRows | Where-Object { $_.Scenario -ceq $expected.Scenario })
    if ($matches.Count -ne 1) {
      $errors.Add("Migration environment-waiver decision scenario missing or duplicated: $($expected.Scenario)")
      continue
    }
    $row = $matches[0]
    if (
      $row.Priority -cne $expected.Priority -or
      $row.'Evidence Command Role' -cne $expected.Role -or
      $row.'Required Command Lifecycle' -cne $expected.Lifecycle -or
      $row.Classification -cne $expected.Classification -or
      $row.interactive -cne $expected.Interactive -or
      $row.auto -cne $expected.Auto -or
      $row.'auto-waive' -cne $expected.AutoWaive
    ) {
      $errors.Add("Migration environment-waiver decision scenario invalid: $($expected.Scenario)")
    }
  }

  $ineligibleSection = 'Waiver-ineligible blockers'
  Test-MarkdownTableExactColumns `
    $orchestratorText `
    $ineligibleSection `
    @('Native blocker', 'interactive', 'auto', 'auto-waive') `
    'Migration waiver-ineligible taxonomy'
  $ineligibleRows = @(Get-MarkdownTableRows `
    $orchestratorText `
    $ineligibleSection `
    'Migration waiver-ineligible taxonomy')
  $ineligibleBlockers = @(
    'required test/build/baseline command started and returned failure, with or without a correctness/regression result'
    'schema/frontmatter/handoff invalid'
    'source/target path invalid or outside scope'
    'mode/policy/unit/foundation selector invalid, stale or ambiguous'
    'parity/regression detects a new failure'
    'destructive target is outside scope'
    'HARD gate'
  )
  if ($ineligibleRows.Count -ne $ineligibleBlockers.Count) {
    $errors.Add("Migration waiver-ineligible taxonomy must contain exactly $($ineligibleBlockers.Count) scenarios; found $($ineligibleRows.Count)")
  }
  foreach ($blocker in $ineligibleBlockers) {
    $matches = @($ineligibleRows | Where-Object { $_.'Native blocker' -ceq $blocker })
    if ($matches.Count -ne 1) {
      $errors.Add("Migration waiver-ineligible scenario missing or duplicated: $blocker")
      continue
    }
    $row = $matches[0]
    if (
      $row.interactive -cne 'stop with native blocker' -or
      $row.auto -cne 'stop with native blocker' -or
      $row.'auto-waive' -cne 'stop with native blocker'
    ) {
      $errors.Add("Migration waiver-ineligible scenario must stop in every mode: $blocker")
    }
  }

  $transitionText = Get-MarkdownSectionBody `
    $orchestratorText `
    'Environment waiver transition' `
    'Migration environment-waiver transition'
  @(
    'only the migration orchestrator', '`workflow_type: migration`',
    'one or more eligible causes all classified `environment-unavailable`',
    'no waiver-ineligible condition',
    'preserve the native blocker and evidence verbatim',
    'feature and bugfix behavior is unchanged'
  ) | ForEach-Object {
    Require-Token $transitionText $_ 'Migration environment-waiver transition'
  }
  $continuationMatch = [regex]::Match(
    $transitionText,
    '(?ms)```yaml\s*\r?\n(?<body>.*?)^```\s*$'
  )
  if (-not $continuationMatch.Success) {
    $errors.Add('Migration environment-waiver transition missing canonical continuation artifact')
  }
  else {
    $body = $continuationMatch.Groups['body'].Value
    $topLevelValues = [ordered]@{
      status = 'approved'
      result = 'partial'
      approval_source = 'auto-waive'
    }
    foreach ($field in $topLevelValues.Keys) {
      $matches = [regex]::Matches(
        $body,
        "(?m)^$([regex]::Escape($field)):\s*(?<value>\S.*?)\s*$"
      )
      if ($matches.Count -ne 1 -or $matches[0].Groups['value'].Value -cne $topLevelValues[$field]) {
        $errors.Add("Migration environment-waiver continuation requires $field`: $($topLevelValues[$field])")
      }
    }

    $waiverMatch = [regex]::Match(
      $body,
      '(?ms)^waiver:\s*\r?\n(?<fields>(?:^  [A-Za-z_][A-Za-z0-9_-]*:\s*[^\r\n]+(?:\r?\n|\z))+)')
    $expectedWaiver = [ordered]@{
      policy = 'auto-waive'
      category = 'environment-unavailable'
      original_verdict = 'blocked'
      effective_action = 'continue'
      evidence = '<verbatim capability/command error reference>'
    }
    $actualKeys = if ($waiverMatch.Success) {
      @(
        [regex]::Matches($waiverMatch.Groups['fields'].Value, '(?m)^  (?<key>[A-Za-z_][A-Za-z0-9_-]*):') |
          ForEach-Object { $_.Groups['key'].Value }
      )
    }
    else { @() }
    if ((($actualKeys | Sort-Object) -join '|') -cne (($expectedWaiver.Keys | Sort-Object) -join '|')) {
      $errors.Add('Migration environment-waiver continuation fields must be exactly: policy, category, original_verdict, effective_action, evidence')
    }
    foreach ($field in $expectedWaiver.Keys) {
      $matches = [regex]::Matches(
        $waiverMatch.Groups['fields'].Value,
        "(?m)^  $([regex]::Escape($field)):\s*(?<value>\S.*?)\s*$"
      )
      if ($matches.Count -ne 1 -or $matches[0].Groups['value'].Value -cne $expectedWaiver[$field]) {
        $errors.Add("Migration environment-waiver continuation requires waiver.$field`: $($expectedWaiver[$field])")
      }
    }
  }

  Test-MarkdownTableExactColumns `
    $orchestratorText `
    'Environment waiver transition' `
    @('Native check state', 'Continuation check state', 'Forbidden state') `
    'Migration truthful waived-check transition'
  $checkRows = @(Get-MarkdownTableRows `
    $orchestratorText `
    'Environment waiver transition' `
    'Migration truthful waived-check transition')
  if (
    $checkRows.Count -ne 1 -or
    $checkRows[0].'Native check state' -cne '`NOT_RUN + BLOCKED`' -or
    $checkRows[0].'Continuation check state' -cne '`NOT_RUN + WAIVED`' -or
    $checkRows[0].'Forbidden state' -cne '`PASS`'
  ) {
    $errors.Add('Migration truthful waived-check transition must be NOT_RUN + BLOCKED -> NOT_RUN + WAIVED and forbid PASS')
  }
  if ($transitionText -match '(?i)PASS\s*\+\s*WAIVED|WAIVED\s*\+\s*PASS') {
    $errors.Add('Migration environment waiver must not combine PASS with WAIVED')
  }
  $executionProtocol = Get-MarkdownSectionBody `
    $orchestratorText `
    'Step execution protocol' `
    'Migration environment-waiver execution seam'
  Require-Token `
    $executionProtocol `
    'A native command/capability error recorded in a contract-valid blocked artifact proceeds to the classifier in step 5.' `
    'Migration environment-waiver execution seam'

  $codeMigrationText = Get-Content -Raw -Encoding utf8 $codeMigrationPath
  $nativeBlockerText = Get-MarkdownSectionBody `
    $codeMigrationText `
    'Native blocker evidence' `
    'Code Migration native blocker evidence'
  @(
    '`automation_mode`', '`status: draft`', '`result: blocked`',
    'verbatim', '`availability probe`', '`required test/build/baseline command`',
    '`not-started`', '`started-without-correctness/regression-result`',
    '`started-and-produced-correctness/regression-result`',
    'Any started required command is waiver-ineligible, whether or not it produces a correctness/regression result.',
    'required command starts and returns a correctness/regression failure while an environment symptom also exists',
    'pre-mutation baseline', 'before any target edit',
    'does not approve', 'does not add a `waiver`'
  ) | ForEach-Object {
    Require-Token $nativeBlockerText $_ 'Code Migration native blocker evidence'
  }

  $resumeSection = 'Approved baseline-waiver resume'
  Test-MarkdownTableExactColumns `
    $codeMigrationText `
    $resumeSection `
    @('Resume outcome', 'Result', 'Waiver retention', 'Downstream eligibility') `
    'Code Migration approved baseline-waiver resume'
  $resumeText = Get-MarkdownSectionBody `
    $codeMigrationText `
    $resumeSection `
    'Code Migration approved baseline-waiver resume'
  @(
    'skip only pre-mutation baseline collection',
    'same `migration_unit_id`, plan/approval references, mode constraint, source/target, and `automation_mode`',
    '`Baseline Reference` cites the approved waiver evidence',
    '`Approved Baseline Waiver`',
    'The resumed invocation still performs selector validation, target source edits, TDD, and the required implementation flow.'
  ) | ForEach-Object {
    Require-Token $resumeText $_ 'Code Migration approved baseline-waiver resume'
  }
  $resumeRows = @(Get-MarkdownTableRows `
    $codeMigrationText `
    $resumeSection `
    'Code Migration approved baseline-waiver resume')
  $expectedResumeRows = @(
    [pscustomobject]@{
      Outcome = 'target source mutation recorded with selected unit and trace evidence; normal implementation outcome'
      Result = '`status: approved`; `result: partial`; `approval_source: auto-waive`'
      Retention = 'retain exact approved waiver and native evidence verbatim'
      Downstream = 'allowed only on this exact valid partial outcome'
    }
    [pscustomobject]@{
      Outcome = 'no target source mutation'
      Result = '`blocked`'
      Retention = 'retain exact approved waiver and native evidence verbatim'
      Downstream = 'forbidden'
    }
    [pscustomobject]@{
      Outcome = 'waiver/evidence missing, stale, mismatched, or altered'
      Result = '`blocked`'
      Retention = 'report mismatch; do not reconstruct'
      Downstream = 'forbidden'
    }
    [pscustomobject]@{
      Outcome = 'waiver-ineligible blocker, started required command, or HARD gate'
      Result = '`blocked`'
      Retention = 'retain supplied evidence verbatim'
      Downstream = 'forbidden'
    }
  )
  if ($resumeRows.Count -ne $expectedResumeRows.Count) {
    $errors.Add("Code Migration approved baseline-waiver resume must contain exactly $($expectedResumeRows.Count) outcomes; found $($resumeRows.Count)")
  }
  foreach ($expected in $expectedResumeRows) {
    $matches = @($resumeRows | Where-Object { $_.'Resume outcome' -ceq $expected.Outcome })
    if ($matches.Count -ne 1) {
      $errors.Add("Code Migration approved baseline-waiver resume outcome missing or duplicated: $($expected.Outcome)")
      continue
    }
    $row = $matches[0]
    if (
      $row.Result -cne $expected.Result -or
      $row.'Waiver retention' -cne $expected.Retention -or
      $row.'Downstream eligibility' -cne $expected.Downstream
    ) {
      $errors.Add("Code Migration approved baseline-waiver resume outcome invalid: $($expected.Outcome)")
    }
  }

  $verificationText = Get-Content -Raw -Encoding utf8 $verificationPath
  Test-VerificationOutcomeLegalPairs `
    $verificationText `
    'Shared verification legal check outcomes'
  $environmentChecks = Get-MarkdownSectionBody `
    $verificationText `
    'Environment-unavailable checks' `
    'Shared verification environment-unavailable checks'
  @(
    '`workflow_type: migration`', '`NOT_RUN + BLOCKED`', '`NOT_RUN + WAIVED`',
    '`status: draft`', '`result: blocked`', '`result: partial`',
    'verbatim', '`availability probe`', '`required test/build/baseline command`',
    '`not-started`', '`started-without-correctness/regression-result`',
    '`started-and-produced-correctness/regression-result`', '`FAIL`',
    'Any started required command is waiver-ineligible, whether or not it produces a correctness/regression result.',
    'required command starts and returns a correctness/regression failure while an environment symptom also exists',
    'never `PASS`', 'orchestrator-only', 'feature and bugfix'
  ) | ForEach-Object {
    Require-Token $environmentChecks $_ 'Shared verification environment-unavailable checks'
  }
  if ($environmentChecks -match '(?i)PASS\s*\+\s*WAIVED|WAIVED\s*\+\s*PASS') {
    $errors.Add('Shared verification must not combine PASS with WAIVED')
  }

  $knowledgeText = Get-Content -Raw -Encoding utf8 $knowledgePath
  $knowledgeWaivers = Get-MarkdownSectionBody `
    $knowledgeText `
    'Migration automation waivers' `
    'Knowledge Capture migration automation waivers'
  @(
    '`workflow_type: migration`', 'every artifact', 'exactly five waiver fields',
    '`NOT_RUN + WAIVED`', '`Verification Verdict: WAIVED`',
    '`Completion Verdict: partial`', 'never', '`PASS`', '`complete`',
    'feature and bugfix behavior is unchanged'
  ) | ForEach-Object {
    Require-Token $knowledgeWaivers $_ 'Knowledge Capture migration automation waivers'
  }
}

function Test-Skills {
  $skillRoot = Join-Path $root 'skills/migration'
  $templateRoot = Join-Path $root 'templates/migration'
  $scopeContractPath = Join-Path $root 'contracts/migration-scope-orchestration.md'
  $conformanceContractPath = Join-Path $root 'contracts/target-structure-conformance.md'
  $scopeContractText = if (Test-Path -LiteralPath $scopeContractPath -PathType Leaf) {
    Get-Content -Raw -Encoding utf8 $scopeContractPath
  }
  else {
    $errors.Add('Missing migration scope orchestration contract resource')
    ''
  }
  $conformanceContractText = if (Test-Path -LiteralPath $conformanceContractPath -PathType Leaf) {
    Get-Content -Raw -Encoding utf8 $conformanceContractPath
  }
  else {
    $errors.Add('Missing target structure conformance contract resource')
    ''
  }
  Invoke-MigrationValidationModule `
    'tests/validation/delivery-adapters.validation.ps1' `
    'Test-DeliveryAdapters' `
    'Delivery adapter kinds' `
    $root `
    $scopeContractText
  Invoke-MigrationValidationModule `
    'tests/validation/structural-gate.validation.ps1' `
    'Test-StructuralGate' `
    'Structural pre-edit gate' `
    $root `
    $conformanceContractText
  Invoke-MigrationValidationModule `
    'tests/validation/architecture-review.validation.ps1' `
    'Test-ArchitectureReview' `
    'Architecture-first review order' `
    $root `
    $conformanceContractText
  $languageProducerSkills = @(
    'migration/validate-inputs', 'migration/discovery', 'migration/analyze-requirements-uiux',
    'migration/build-inventory', 'migration/feature-mapping', 'migration/analyze-gaps-conflicts',
    'migration/technical-design', 'migration/plan-waves', 'migration/bootstrap-target',
    'migration/code-migration', 'migration/verify-parity', 'migration/verify-regression',
    'migration-onboarding/inspect-project', 'migration-onboarding/classify-mode',
    'migration-onboarding/create-project-pack', 'shared/ai-review',
    'shared/verification-testing', 'shared/knowledge-base'
  )
  foreach ($languageProducerSkill in $languageProducerSkills) {
    $languageProducerPath = Join-Path $root "skills/$languageProducerSkill/SKILL.md"
    if (-not (Test-Path $languageProducerPath)) {
      $errors.Add("Missing artifact language producer: $languageProducerSkill/SKILL.md")
      continue
    }
    Test-ArtifactLanguageProducer `
      (Get-Content -Raw -Encoding utf8 $languageProducerPath) `
      "Skill $languageProducerSkill/SKILL.md"
  }
  foreach ($sharedTemplateRoute in @(
    [pscustomobject]@{ Skill = 'shared/ai-review'; Migration = 'templates/migration/review-report.md'; Legacy = 'templates/review-report.md' }
    [pscustomobject]@{ Skill = 'shared/verification-testing'; Migration = 'templates/migration/verification-report.md'; Legacy = 'templates/verification-report.md' }
  )) {
    $sharedSkillText = Get-Content -Raw -Encoding utf8 (Join-Path $root "skills/$($sharedTemplateRoute.Skill)/SKILL.md")
    @($sharedTemplateRoute.Migration, $sharedTemplateRoute.Legacy, '`workflow_type: migration`', 'feature/bugfix') | ForEach-Object {
      Require-Token $sharedSkillText $_ "Skill $($sharedTemplateRoute.Skill)/SKILL.md workflow-specific template route"
    }
  }
  $frontHalfSkills = @(
    [pscustomobject]@{ Skill = 'validate-inputs'; Template = 'input-report'; Artifact = '01-input-report.md'; StepId = '01-validate-inputs' }
    [pscustomobject]@{ Skill = 'discovery'; Template = 'discovery'; Artifact = '02-discovery.md'; StepId = '02-discovery' }
    [pscustomobject]@{ Skill = 'analyze-requirements-uiux'; Template = 'requirements-uiux'; Artifact = '03-requirements-uiux.md'; StepId = '03-analyze-requirements-uiux' }
    [pscustomobject]@{ Skill = 'build-inventory'; Template = 'inventory'; Artifact = '04-inventory.md'; StepId = '04-build-inventory' }
    [pscustomobject]@{ Skill = 'feature-mapping'; Template = 'mapping'; Artifact = '05-mapping.md'; StepId = '05-feature-mapping' }
    [pscustomobject]@{ Skill = 'analyze-gaps-conflicts'; Template = 'gaps-conflicts'; Artifact = '06-gaps-conflicts.md'; StepId = '06-analyze-gaps-conflicts' }
  )
  $executionSkills = @(
    [pscustomobject]@{
      Skill = 'technical-design'; Artifact = '07-technical-design.md'; StepId = '07-technical-design'
      PolicyTokens = @('design-new', 'preserve-existing', 'Tech Lead gate')
    }
    [pscustomobject]@{
      Skill = 'plan-waves'; Artifact = '08-migration-plan.md'; StepId = '08-plan-waves'
      PolicyTokens = @('approved migration unit', 'trace ID')
    }
    [pscustomobject]@{
      Skill = 'bootstrap-target'; Artifact = '09-bootstrap-report.md'; StepId = '09-bootstrap-target'
      PolicyTokens = @('greenfield', 'result: blocked')
    }
    [pscustomobject]@{
      Skill = 'code-migration'; Artifact = '10-implementation-report.md'; StepId = '10-code-migration'
      PolicyTokens = @(
        'approved migration unit', 'trace ID',
        'explicit profile -> existing project scripts/config -> marker detection -> human gate'
      )
    }
    [pscustomobject]@{
      Skill = 'verify-parity'; Artifact = '13-parity-report.md'; StepId = '13-verify-parity'
      PolicyTokens = @('required baseline', 'result: blocked')
    }
    [pscustomobject]@{
      Skill = 'verify-regression'; Artifact = '14-regression-report.md'; StepId = '14-verify-regression'
      PolicyTokens = @('incremental', 'baseline failure', 'waiver')
    }
  )
  $outputContractToken = [Text.Encoding]::UTF8.GetString(
    [Convert]::FromBase64String('SOG7o3AgxJHhu5NuZyDEkeG6p3UgcmE=')
  )
  $requiredTokens = @('Core principle', 'Evidence', 'Unknowns', 'result: blocked', $outputContractToken)
  $immediatePredecessorToken = 'Immediate predecessor artifact = exactly one orchestrator-provided path'
  $activationSkillContracts = @(
    [pscustomobject]@{
      Skill = 'migration/discovery'
      Tokens = @(
        'contracts/activation-slice.md', 'Activation Slice ID', 'ACT-###',
        'requested-key', 'parse-model', 'downstream-consumer', 'result: blocked',
        'never `result: partial`'
      )
    }
    [pscustomobject]@{
      Skill = 'migration/build-inventory'
      Tokens = @(
        'contracts/activation-slice.md', 'Activation Slice',
        'Preserve the same `ACT-###` Activation Slice ID and every seam row with its trace IDs'
      )
    }
    [pscustomobject]@{
      Skill = 'migration/feature-mapping'
      Tokens = @(
        'contracts/activation-slice.md', 'Activation Slice',
        '`deferred-approved` requires both `Decision Reference` and `Deferred Unit ID`'
      )
    }
    [pscustomobject]@{
      Skill = 'migration/analyze-gaps-conflicts'
      Tokens = @(
        'contracts/activation-slice.md', 'Activation Slice',
        'Unresolved router ownership is a blocking conflict and requires `result: blocked`.'
      )
    }
    [pscustomobject]@{
      Skill = 'migration/technical-design'
      Tokens = @(
        'contracts/activation-slice.md', 'Activation Slice', 'router policy',
        'initial loading, update/watch, reselection, failure behavior, and lifecycle test'
      )
    }
    [pscustomobject]@{
      Skill = 'migration/plan-waves'
      Tokens = @(
        'contracts/activation-slice.md', 'Activation Slice', 'deferred-approved', 'activatable',
        'Acceptance must not declare the module `activatable` while any required seam is `deferred-approved`.'
      )
    }
    [pscustomobject]@{
      Skill = 'migration/code-migration'
      Tokens = @(
        'contracts/activation-slice.md',
        'Validate the approved `Activation Slice` at the `Entry gate`'
      )
    }
    [pscustomobject]@{
      Skill = 'shared/ai-review'
      Tokens = @(
        'contracts/activation-slice.md', 'Activation Slice',
        'A missing seam that prevents activation is `Critical`.',
        'Untraced duplicate ownership or missing lifecycle coverage is at least `Major`, and becomes `Critical` when it causes a correctness failure.'
      )
    }
  )
  foreach ($activationSkillContract in $activationSkillContracts) {
    $activationSkillPath = Join-Path $root "skills/$($activationSkillContract.Skill)/SKILL.md"
    if (-not (Test-Path $activationSkillPath)) {
      $errors.Add("Missing Activation Slice skill: $($activationSkillContract.Skill)/SKILL.md")
      continue
    }
    $activationSkillText = Get-Content -Raw -Encoding utf8 $activationSkillPath
    $activationSkillContract.Tokens | ForEach-Object {
      Require-Token `
        $activationSkillText `
        $_ `
        "Skill $($activationSkillContract.Skill)/SKILL.md Activation Slice responsibility"
    }
  }
  foreach ($domainBlockerSkill in @(
    'migration/discovery', 'migration/analyze-requirements-uiux',
    'migration/build-inventory', 'migration/feature-mapping',
    'migration/analyze-gaps-conflicts', 'migration/technical-design',
    'migration/plan-waves', 'migration/bootstrap-target',
    'migration/code-migration', 'shared/ai-review',
    'shared/verification-testing'
  )) {
    $domainBlockerSkillPath = Join-Path $root "skills/$domainBlockerSkill/SKILL.md"
    if (-not (Test-Path -LiteralPath $domainBlockerSkillPath)) { continue }
    $domainBlockerSkillText = Get-Content -Raw -Encoding utf8 -LiteralPath $domainBlockerSkillPath
    @('Domain Blocker', 'non-placeholder', 'Evidence Reference') | ForEach-Object {
      Require-Token $domainBlockerSkillText $_ "Skill $domainBlockerSkill/SKILL.md blocked-output evidence"
    }
  }
  $activationEnvelopeRequirement = 'Preserve the immediate predecessor Activation Slice envelope without loss: keep the complete case-sensitive slice ID set, Applicability, all nine canonical seam rows, and every predecessor Source Reference and Trace ID. Source Reference enrichment is append-only, and predecessor Trace IDs remain a subset of successor Trace IDs. Never reconstruct it from cumulative artifacts.'
  $discoveryOriginRequirement = "Discovery is the Activation Slice origin when step 01 has no envelope: create the complete canonical envelope from validated evidence. If an immediate predecessor already carries an envelope, preserve it under the contract's no-loss and append-only rules; never reconstruct from cumulative artifacts."
  $discoveryActivationSkillPath = Join-Path $root 'skills/migration/discovery/SKILL.md'
  if (Test-Path $discoveryActivationSkillPath) {
    Require-Token `
      (Get-Content -Raw -Encoding utf8 $discoveryActivationSkillPath) `
      $discoveryOriginRequirement `
      'Skill migration/discovery/SKILL.md Activation Slice origin'
  }
  foreach ($activationChainSkill in @(
    'migration/analyze-requirements-uiux',
    'migration/build-inventory',
    'migration/feature-mapping',
    'migration/analyze-gaps-conflicts',
    'migration/technical-design',
    'migration/plan-waves',
    'migration/bootstrap-target',
    'migration/code-migration',
    'shared/ai-review',
    'shared/verification-testing',
    'migration/verify-parity',
    'migration/verify-regression'
  )) {
    $activationChainSkillPath = Join-Path $root "skills/$activationChainSkill/SKILL.md"
    if (-not (Test-Path $activationChainSkillPath)) {
      $errors.Add("Missing Activation Slice chain skill: $activationChainSkill/SKILL.md")
      continue
    }
    $activationChainSkillText = Get-Content -Raw -Encoding utf8 $activationChainSkillPath
    Require-Token $activationChainSkillText 'aitoolkit/contracts/activation-slice.md' "Skill $activationChainSkill/SKILL.md Activation Slice chain"
    Require-Token $activationChainSkillText $activationEnvelopeRequirement "Skill $activationChainSkill/SKILL.md Activation Slice chain"
  }
  foreach ($completeOrBlockedSkill in @(
    'migration/discovery',
    'migration/analyze-requirements-uiux',
    'migration/build-inventory',
    'migration/feature-mapping',
    'migration/analyze-gaps-conflicts',
    'migration/technical-design',
    'migration/plan-waves',
    'migration/bootstrap-target',
    'shared/ai-review',
    'shared/verification-testing',
    'migration/verify-parity',
    'migration/verify-regression'
  )) {
    $lifecyclePath = Join-Path $root "skills/$completeOrBlockedSkill/SKILL.md"
    if (-not (Test-Path $lifecyclePath)) { continue }
    $lifecycleText = Get-Content -Raw -Encoding utf8 $lifecyclePath
    Require-Token $lifecycleText 'result: complete | blocked' "Skill $completeOrBlockedSkill migration lifecycle"
    if (
      $lifecycleText.Contains('result: complete | partial | blocked') -or
      $lifecycleText.Contains('`status: approved`, `result: partial`')
    ) {
      $errors.Add("Skill $completeOrBlockedSkill authorizes partial outside the exact step-10 lifecycle")
    }
  }
  $codeMigrationActivationPath = Join-Path $skillRoot 'code-migration/SKILL.md'
  if (Test-Path $codeMigrationActivationPath) {
    $codeMigrationActivationText = Get-Content -Raw -Encoding utf8 $codeMigrationActivationPath
    $codeMigrationActivationOutput = Get-MarkdownSectionBody `
      $codeMigrationActivationText `
      $outputContractToken `
      'Skill migration/code-migration/SKILL.md Activation Slice output contract'
    Require-Token `
      $codeMigrationActivationOutput `
      'Every changed-file row and every test evidence record must link to the approved Activation Slice seam and its trace IDs.' `
      'Skill migration/code-migration/SKILL.md Activation Slice output contract'
  }
  $templateTableContracts = @{
    'requirements-uiux' = [pscustomobject]@{ Section = (ConvertFrom-Utf8Base64 'WcOqdSBj4bqndQ=='); Columns = @('Discovery IDs') }
    'inventory' = [pscustomobject]@{ Section = (ConvertFrom-Utf8Base64 'SOG6oW5nIG3hu6Vj'); Columns = @('Requirement IDs', 'Discovery IDs') }
    'mapping' = [pscustomobject]@{ Section = (ConvertFrom-Utf8Base64 'w4FuaCB44bqh'); Columns = @('Mapping ID', 'Requirement IDs', 'Inventory IDs', 'Discovery IDs') }
    'gaps-conflicts' = [pscustomobject]@{ Section = (ConvertFrom-Utf8Base64 'S2hv4bqjbmcgdHLhu5FuZyB2w6AgeHVuZyDEkeG7mXQ='); Columns = @('Requirement IDs', 'Inventory IDs', 'Mapping IDs', 'Discovery IDs') }
  }

  foreach ($frontHalfSkill in $frontHalfSkills) {
    $skillName = $frontHalfSkill.Skill
    $skillPath = Join-Path $skillRoot "$skillName/SKILL.md"
    if (-not (Test-Path $skillPath)) {
      $errors.Add("Missing migration skill: $skillName/SKILL.md")
    }
    else {
      $skillText = Get-Content -Raw -Encoding utf8 $skillPath
      $requiredTokens | ForEach-Object { Require-Token $skillText $_ "Skill $skillName/SKILL.md" }
      Require-Token $skillText "<RUN_DIR>/$($frontHalfSkill.Artifact)" "Skill $skillName/SKILL.md output"
      Require-Token $skillText "step_id: $($frontHalfSkill.StepId)" "Skill $skillName/SKILL.md output"
      $inputsText = ''
      $inputsMatch = [regex]::Match(
        $skillText,
        '(?ms)^## Inputs\s*\r?\n(?<body>.*?)(?=^## |\z)'
      )
      if (-not $inputsMatch.Success) {
        $errors.Add("Skill $skillName/SKILL.md missing Inputs section")
      }
      else {
        $inputsText = $inputsMatch.Groups['body'].Value
        if ($inputsText -match '(?i)(?<![A-Za-z0-9])\d{2}-[A-Za-z0-9-]+\.md(?![A-Za-z0-9])') {
          $errors.Add("Skill $skillName/SKILL.md Inputs hardcodes numbered artifact path")
        }
      }
      if ($skillName -ne 'validate-inputs') {
        Require-Token $inputsText $immediatePredecessorToken "Skill $skillName/SKILL.md Inputs"
      }
      Test-MigrationTechnologyTokens $skillText "Skill $skillName/SKILL.md"
    }

    $templateName = $frontHalfSkill.Template
    $templatePath = Join-Path $templateRoot "$templateName.md"
    if (-not (Test-Path $templatePath)) {
      $errors.Add("Missing migration template for skill $skillName`: $templateName.md")
      continue
    }
    $templateText = Get-Content -Raw -Encoding utf8 $templatePath
    Test-MigrationTechnologyTokens $templateText "Front-half template $templateName.md"
    if ($templateTableContracts.ContainsKey($templateName)) {
      $tableContract = $templateTableContracts[$templateName]
      Test-MarkdownTableColumns `
        $templateText `
        $tableContract.Section `
        $tableContract.Columns `
        "Front-half template $templateName.md"
    }
  }

  $validateInputsPath = Join-Path $skillRoot 'validate-inputs/SKILL.md'
  if (Test-Path $validateInputsPath) {
    $validateInputsText = Get-Content -Raw -Encoding utf8 $validateInputsPath
    $validateInputsProcedureSection = [Text.Encoding]::UTF8.GetString(
      [Convert]::FromBase64String('UXV5IHRyw6xuaA==')
    )
    $validateInputsProcedure = Get-MarkdownSectionBody $validateInputsText $validateInputsProcedureSection 'Skill validate-inputs/SKILL.md project-pack review gate'
    @(
      '`project_pack.reviewed_at`', 'non-null', 'parseable', 'review evidence',
      'stale', 'newer than', '`result: blocked`',
      'A missing, null, invalid, or stale `project_pack.reviewed_at` yields `result: blocked`.'
    ) | ForEach-Object {
      Require-Token $validateInputsProcedure $_ 'Skill validate-inputs/SKILL.md project-pack review gate'
    }
  }

  foreach ($executionSkill in $executionSkills) {
    $skillName = $executionSkill.Skill
    $skillPath = Join-Path $skillRoot "$skillName/SKILL.md"
    if (-not (Test-Path $skillPath)) {
      $errors.Add("Missing migration skill: $skillName/SKILL.md")
      continue
    }

    $skillText = Get-Content -Raw -Encoding utf8 $skillPath
    $requiredTokens | ForEach-Object { Require-Token $skillText $_ "Skill $skillName/SKILL.md" }
    $executionSkill.PolicyTokens | ForEach-Object {
      Require-Token $skillText $_ "Skill $skillName/SKILL.md policy"
    }
    Require-Token $skillText "<RUN_DIR>/$($executionSkill.Artifact)" "Skill $skillName/SKILL.md output"
    Require-Token $skillText "step_id: $($executionSkill.StepId)" "Skill $skillName/SKILL.md output"

    $inputsMatch = [regex]::Match(
      $skillText,
      '(?ms)^## Inputs\s*\r?\n(?<body>.*?)(?=^## |\z)'
    )
    if (-not $inputsMatch.Success) {
      $errors.Add("Skill $skillName/SKILL.md missing Inputs section")
    }
    else {
      $inputsText = $inputsMatch.Groups['body'].Value
      Require-Token $inputsText $immediatePredecessorToken "Skill $skillName/SKILL.md Inputs"
      if ($skillName -in 'bootstrap-target', 'code-migration') {
        Require-Token $inputsText '`migration_unit_id`' "Skill $skillName/SKILL.md Inputs"
        Require-Token $inputsText 'alongside that path' "Skill $skillName/SKILL.md Inputs"
      }
      if ($skillName -eq 'code-migration') {
        Require-Token $inputsText '`foundation_baseline_id`' "Skill $skillName/SKILL.md Inputs"
      }
      if ($inputsText -match '(?i)(?<![A-Za-z0-9])\d{2}-[A-Za-z0-9-]+\.md(?![A-Za-z0-9])') {
        $errors.Add("Skill $skillName/SKILL.md Inputs hardcodes numbered artifact path")
      }
    }
    Test-MigrationTechnologyTokens $skillText "Skill $skillName/SKILL.md"
  }

  $sectionContracts = @(
    [pscustomobject]@{
      Skill = 'technical-design'; Section = 'Mode policy'
      Tokens = @('greenfield', 'design-new', 'Tech Lead gate', 'incremental', 'preserve-existing', 'result: blocked')
    }
    [pscustomobject]@{
      Skill = 'bootstrap-target'; Section = 'Mode gate'
      Tokens = @(
        'greenfield', 'incremental', 'refuse execution', 'result: blocked',
        '`migration_unit_id`', 'immediate predecessor migration plan',
        'exactly one approved bootstrap-scoped migration unit',
        '`Bootstrap Scope = required`', '`not-required`', 'scope mismatch',
        '`Foundation Baseline ID = pending-bootstrap`',
        '`Foundation Approval Reference = pending-step09-approval`',
        'does not require an existing foundation baseline before step 09',
        'no approved foundation baseline exists'
      )
    }
    [pscustomobject]@{
      Skill = 'bootstrap-target'; Section = 'Procedure'
      Tokens = @(
        '`Approval Status = pending-approval`', '`pending-step09-approval`',
        'step-09 gate atomically', '`Approval Status = approved`',
        'exact approved bootstrap artifact reference'
      )
    }
    [pscustomobject]@{
      Skill = 'plan-waves'; Section = 'Procedure'
      Tokens = @(
        '`Bootstrap Scope`', '`required | not-required`',
        'greenfield', 'design-new', 'incremental', 'preserve-existing',
        'every unit uses `not-required`', 'wrong-mode scope yields `result: blocked`'
      )
    }
    [pscustomobject]@{
      Skill = 'code-migration'; Section = 'Entry gate'
      Tokens = @(
        '`migration_unit_id`', 'exactly one approved migration unit',
        'preserved bootstrap record', 'directly against the immediate predecessor migration plan',
        'selector mismatch yields `result: blocked`', 'preserved `Bootstrap Scope = required`',
        'incremental `Bootstrap Scope = not-required`', 'greenfield `Bootstrap Scope = not-required`',
        '`foundation_baseline_id`', 'exactly one approved foundation baseline record',
        'target baseline reference', 'foundation baseline approval reference', 'result: blocked',
        '`Foundation Baseline ID = pending-bootstrap`', 'approved `FOUNDATION-*` record',
        '`Source Migration Unit ID` matches', 'approved target baseline/project pack'
      )
    }
    [pscustomobject]@{
      Skill = 'code-migration'; Section = 'Pre-mutation gate'
      Tokens = @(
        'absence before invocation is not a blocker', 'resolve required commands',
        'capture a comparable pre-change regression baseline', 'before any target edit',
        'command resolution or baseline capture fails', 'result: blocked'
      )
    }
    [pscustomobject]@{
      Skill = 'verify-parity'; Section = 'Baseline gate'
      Tokens = @('required baseline', 'result: blocked', 'Never mark that scenario or the report PASS')
    }
    [pscustomobject]@{
      Skill = 'verify-regression'; Section = 'Applicability and baseline gate'
      Tokens = @('mandatory for incremental', 'cannot be waived or skipped', 'missing command or comparable baseline', 'result: blocked', 'human gate')
    }
    [pscustomobject]@{
      Skill = 'verify-regression'; Section = 'Procedure'
      Tokens = @('continuing baseline failure', 'scoped to identity', 'never covers a candidate-only or worsened failure')
    }
  )
  foreach ($contract in $sectionContracts) {
    $skillPath = Join-Path $skillRoot "$($contract.Skill)/SKILL.md"
    if (-not (Test-Path $skillPath)) { continue }
    $skillText = Get-Content -Raw -Encoding utf8 $skillPath
    $sectionText = Get-MarkdownSectionBody $skillText $contract.Section "Skill $($contract.Skill)/SKILL.md policy"
    $contract.Tokens | ForEach-Object {
      Require-Token $sectionText $_ "Skill $($contract.Skill)/SKILL.md section $($contract.Section)"
    }
  }

  $bootstrapTargetPath = Join-Path $skillRoot 'bootstrap-target/SKILL.md'
  $codeMigrationPath = Join-Path $skillRoot 'code-migration/SKILL.md'
  $bootstrapReportPath = Join-Path $templateRoot 'bootstrap-report.md'
  $migrationPlanPath = Join-Path $templateRoot 'migration-plan.md'
  if (
    (Test-Path $bootstrapTargetPath) -and
    (Test-Path $codeMigrationPath) -and
    (Test-Path $bootstrapReportPath) -and
    (Test-Path $migrationPlanPath)
  ) {
    $bootstrapTargetText = Get-Content -Raw -Encoding utf8 $bootstrapTargetPath
    $bootstrapOutput = Get-MarkdownSectionBody $bootstrapTargetText $outputContractToken 'Skill bootstrap-target/SKILL.md output'
    $bootstrapHandoffTokens = @(
      'Preserve `Selected Migration Unit`', '`migration_unit_id`', 'plan reference', 'approval reference',
      'mode constraint', '`Bootstrap Scope`', 'Foundation Baseline ID', 'foundation baseline reference',
      'foundation baseline approval reference', 'baseline reference', 'trace IDs'
    )
    $missingBootstrapHandoff = $false
    foreach ($token in $bootstrapHandoffTokens) {
      if ($bootstrapOutput -notmatch [regex]::Escape($token)) { $missingBootstrapHandoff = $true }
    }
    if ($missingBootstrapHandoff) {
      $errors.Add('Skill bootstrap-target/SKILL.md output missing selected-unit handoff contract')
    }

    $codeMigrationText = Get-Content -Raw -Encoding utf8 $codeMigrationPath
    $codeMigrationOutput = Get-MarkdownSectionBody $codeMigrationText $outputContractToken 'Skill code-migration/SKILL.md output'
    Require-Token $codeMigrationOutput '`foundation_baseline_id`' 'Skill code-migration/SKILL.md output'

    $bootstrapReportText = Get-Content -Raw -Encoding utf8 $bootstrapReportPath
    Test-MarkdownTableColumns `
      $bootstrapReportText `
      'Selected Migration Unit' `
      @(
        'Migration Unit ID', 'Plan Reference', 'Approval Reference', 'Bootstrap Scope',
        'Foundation Baseline ID', 'Foundation Baseline Reference', 'Foundation Baseline Approval Reference'
      ) `
      'Bootstrap handoff template'

    $migrationPlanText = Get-Content -Raw -Encoding utf8 $migrationPlanPath
    Test-MarkdownTableColumns `
      $migrationPlanText `
      (ConvertFrom-Utf8Base64 'Q8OhYyDEkcahbiB24buLIG1pZ3JhdGlvbiB0aGVvIHRo4bupIHThu7E=') `
      @(
        'Migration Unit ID', 'Mode Constraint', 'Bootstrap Scope', 'Foundation Baseline ID',
        'Trace IDs', 'Approval Reference', 'Approval Status'
      ) `
      'Approved migration-plan handoff'
  }

  $planWavesPath = Join-Path $skillRoot 'plan-waves/SKILL.md'
  if (Test-Path $planWavesPath) {
    $planWavesText = Get-Content -Raw -Encoding utf8 $planWavesPath
    $planWavesProcedure = Get-MarkdownSectionBody $planWavesText 'Procedure' 'Skill plan-waves/SKILL.md policy'
    $foundationBaselineContract = Get-MarkdownSectionBody $planWavesText 'Foundation baseline contract' 'Skill plan-waves/SKILL.md foundation baseline contract'
    $planWavesOutput = Get-MarkdownSectionBody $planWavesText $outputContractToken 'Skill plan-waves/SKILL.md output'
    Require-Token $planWavesOutput '`Bootstrap Scope`' 'Skill plan-waves/SKILL.md output'
    Require-Token $planWavesOutput '`Foundation Baseline ID`' 'Skill plan-waves/SKILL.md output'
    @(
      'exactly one approved `Foundation Baseline ID`', '`Bootstrap Scope = not-required`',
      'target baseline reference', 'approval reference', 'missing, stale, or mismatched', '`result: blocked`',
      '`Foundation Baseline ID = pending-bootstrap`',
      '`Foundation Approval Reference = pending-step09-approval`',
      'must not resolve or require an existing foundation baseline before step 09',
      'missing ID or approval reference',
      'incremental', '`Foundation Baseline ID = not-applicable`',
      'exactly one initial', 'only when no approved foundation baseline exists',
      'If a current approved foundation baseline already exists',
      'all subsequent greenfield units use `Bootstrap Scope = not-required`'
    ) | ForEach-Object {
      Require-Token $foundationBaselineContract $_ 'Skill plan-waves/SKILL.md foundation baseline contract'
    }
    if ($foundationBaselineContract -match '(?is)later greenfield unit.{0,120}may use.{0,80}`Bootstrap Scope = required`') {
      $errors.Add('Skill plan-waves/SKILL.md foundation baseline contract allows later greenfield required bootstrap')
    }
    $greenfieldApprovalPattern = '(?is)greenfield.{0,80}design-new.{0,160}Tech Lead approval'
    $incrementalApprovalPattern = '(?is)incremental.{0,80}preserve-existing.{0,160}target conformance.{0,160}without a Tech Lead gate.{0,160}architecture conflict.{0,160}approval from its owner'
    if ($planWavesProcedure -notmatch $greenfieldApprovalPattern -or $planWavesProcedure -notmatch $incrementalApprovalPattern) {
      $errors.Add('Skill plan-waves/SKILL.md Procedure missing mode-scoped design approval policy')
    }
  }

  $verifyRegressionPath = Join-Path $skillRoot 'verify-regression/SKILL.md'
  if (Test-Path $verifyRegressionPath) {
    $verifyRegressionText = Get-Content -Raw -Encoding utf8 $verifyRegressionPath
    $regressionApplicability = Get-MarkdownSectionBody $verifyRegressionText 'Applicability and baseline gate' 'Skill verify-regression/SKILL.md policy'
    if ($regressionApplicability -match '(?i)regression-step waiver') {
      $errors.Add('Skill verify-regression/SKILL.md permits a whole regression-step waiver')
    }
  }

  if (Test-Path $codeMigrationPath) {
    $codeMigrationText = Get-Content -Raw -Encoding utf8 $codeMigrationPath
    $procedureText = Get-MarkdownSectionBody $codeMigrationText 'Procedure' 'Skill code-migration/SKILL.md policy'
    Require-TokenOrder `
      $procedureText `
      'explicit profile -> existing project scripts/config -> marker detection -> human gate' `
      'capture a comparable pre-change regression baseline' `
      'Skill code-migration/SKILL.md Procedure'
    Require-TokenOrder `
      $procedureText `
      'explicit profile -> existing project scripts/config -> marker detection -> human gate' `
      'superpowers:test-driven-development' `
      'Skill code-migration/SKILL.md Procedure'
    Require-TokenOrder `
      $procedureText `
      'capture a comparable pre-change regression baseline' `
      'evaluate the pre-mutation gate' `
      'Skill code-migration/SKILL.md Procedure'
    Require-TokenOrder `
      $procedureText `
      'evaluate the pre-mutation gate' `
      'superpowers:test-driven-development' `
      'Skill code-migration/SKILL.md Procedure'
  }

  $mappingSkillPath = Join-Path $skillRoot 'feature-mapping/SKILL.md'
  if (Test-Path $mappingSkillPath) {
    $mappingSkillText = Get-Content -Raw -Encoding utf8 $mappingSkillPath
    $incrementalOrder = [Text.Encoding]::UTF8.GetString(
      [Convert]::FromBase64String('cmV1c2Ug4oaSIGV4dGVuZCDihpIgY3JlYXRl')
    )
    @('name: feature-mapping', $incrementalOrder, 'approved conflict decision') |
      ForEach-Object { Require-Token $mappingSkillText $_ 'Skill feature-mapping/SKILL.md policy' }
  }

  Test-TruthfulMigrationWaiverSkills
}

function Test-Orchestrators {
  $scopeContractPath = Join-Path $root 'contracts/migration-scope-orchestration.md'
  $scopeContractText = if (Test-Path -LiteralPath $scopeContractPath -PathType Leaf) {
    Get-Content -Raw -Encoding utf8 $scopeContractPath
  }
  else {
    $errors.Add('Missing migration scope orchestration contract resource')
    ''
  }
  Invoke-MigrationValidationModule `
    'tests/validation/scope-engine.validation.ps1' `
    'Test-ScopeEngine' `
    'Deterministic selection order' `
    $root `
    $scopeContractText
  $orchestratorPath = Join-Path $root 'skills/aitoolkit/migrate/SKILL.md'
  $commandPath = Join-Path $root 'commands/migrate.md'
  $codexLauncherPath = Join-Path $root 'codex/skills/aitoolkit/SKILL.md'
  if (-not (Test-Path $orchestratorPath)) {
    $errors.Add('Missing migration orchestrator: skills/aitoolkit/migrate/SKILL.md')
    return
  }
  if (-not (Test-Path $commandPath)) {
    $errors.Add('Missing migrate command: commands/migrate.md')
    return
  }
  if (-not (Test-Path $codexLauncherPath)) {
    $errors.Add('Missing Codex launcher: codex/skills/aitoolkit/SKILL.md')
    return
  }

  $orchestratorText = Get-Content -Raw -Encoding utf8 $orchestratorPath
  Test-Step10ResumeOrchestrator $orchestratorText
  $onboardingOrchestratorPath = Join-Path $root 'skills/aitoolkit/migration-onboarding/SKILL.md'
  $onboardingOrchestratorText = if (Test-Path $onboardingOrchestratorPath) {
    Get-Content -Raw -Encoding utf8 $onboardingOrchestratorPath
  }
  else {
    $errors.Add('Missing migration onboarding orchestrator: skills/aitoolkit/migration-onboarding/SKILL.md')
    ''
  }
  $commandText = Get-Content -Raw -Encoding utf8 $commandPath
  $codexLauncherText = Get-Content -Raw -Encoding utf8 $codexLauncherPath
  Test-ArtifactLanguageProducer $orchestratorText 'Migration orchestrator'
  Test-ArtifactLanguageProducer $onboardingOrchestratorText 'Migration onboarding orchestrator'
  @(
    'legacy fallback `vi`',
    'currently supported value is `vi`',
    'Pass the resolved `artifact_language` in every migration step invocation',
    '`templates/migration/review-report.md`',
    '`templates/migration/verification-report.md`'
  ) | ForEach-Object { Require-Token $orchestratorText $_ 'Migration orchestrator artifact language resolution' }
  @(
    'artifact_language: vi',
    'currently supported value is `vi`',
    'Pass `artifact_language` in every onboarding step invocation'
  ) | ForEach-Object { Require-Token $onboardingOrchestratorText $_ 'Migration onboarding artifact language resolution' }
  Test-SourceDocumentTranslationBoundary $orchestratorText 'Migration orchestrator'
  Test-SourceDocumentTranslationBoundary $onboardingOrchestratorText 'Migration onboarding orchestrator'
  $workflowOrchestratorContracts = @(
    [pscustomobject]@{
      Name = 'feature'; Label = 'Feature'; Workflow = 'feature'; KnowledgeStep = '09-knowledge-base'
      WorkflowError = 'Feature orchestrator must provide authoritative workflow_type: feature even when the onboarding profile contains migration settings'
    }
    [pscustomobject]@{
      Name = 'bugfix'; Label = 'Bugfix'; Workflow = 'bugfix'; KnowledgeStep = '09-knowledge-base'
      WorkflowError = 'Bugfix orchestrator must provide authoritative workflow_type: bugfix even when the onboarding profile contains migration settings'
    }
    [pscustomobject]@{
      Name = 'migrate'; Label = 'Migrate'; Workflow = 'migration'; KnowledgeStep = '15-knowledge-base'
      WorkflowError = 'Migration orchestrator must provide authoritative workflow_type: migration'
    }
  )
  $onboardingProfilePath = Join-Path $root 'templates/migration/project-profile.yaml'
  $onboardingProfileText = if (Test-Path $onboardingProfilePath) {
    Get-Content -Raw -Encoding utf8 $onboardingProfilePath
  }
  else { '' }
  foreach ($workflowContract in $workflowOrchestratorContracts) {
    $workflowPath = Join-Path $root "skills/aitoolkit/$($workflowContract.Name)/SKILL.md"
    if (-not (Test-Path $workflowPath)) {
      $errors.Add("Missing workflow orchestrator: skills/aitoolkit/$($workflowContract.Name)/SKILL.md")
      continue
    }
    $workflowText = Get-Content -Raw -Encoding utf8 $workflowPath
    $workflowToken = "``workflow_type: $($workflowContract.Workflow)``"
    $hasWorkflowAuthority = $workflowText.Contains($workflowToken) -and $workflowText -match '(?i)authoritative'
    if ($workflowContract.Name -in 'feature', 'bugfix') {
      $hasWorkflowAuthority = $hasWorkflowAuthority -and
        $workflowText -match '(?is)onboarding-generated profile.{0,100}`migration` section'
    }
    if (-not $hasWorkflowAuthority) {
      $errors.Add($workflowContract.WorkflowError)
    }
    $knowledgeToken = '`knowledge_step_id: ' + $workflowContract.KnowledgeStep + '`'
    if ($workflowText -notmatch [regex]::Escape($knowledgeToken)) {
      $errors.Add("$($workflowContract.Label) orchestrator must provide $($workflowContract.KnowledgeStep) to Knowledge Capture")
    }
  }
  if ($onboardingProfileText -notmatch '(?m)^migration:\s*' -or $onboardingProfileText -match '(?m)^change_type\s*:') {
    $errors.Add('Cross-workflow authority scenario requires an onboarding profile with migration settings and no persistent change_type')
  }
  $stepTableSection = [Text.Encoding]::UTF8.GetString(
    [Convert]::FromBase64String('QuG6o25nIGLGsOG7m2MgKG1pZ3JhdGlvbik=')
  )
  $featureSlugHint = [Text.Encoding]::UTF8.GetString(
    [Convert]::FromBase64String('YXJndW1lbnQtaGludDogIlstLWF1dG8gfCAtLWF1dG8td2FpdmVdIFt0w6puLXTDrW5oLW7Eg25nXSI=')
  )
  $rows = @(Get-MarkdownTableRows $orchestratorText $stepTableSection 'Migration orchestrator')
  $expectedSteps = @(
    [pscustomobject]@{ Id = '01'; Route = 'migration/validate-inputs' }
    [pscustomobject]@{ Id = '02'; Route = 'migration/discovery' }
    [pscustomobject]@{ Id = '03'; Route = 'migration/analyze-requirements-uiux' }
    [pscustomobject]@{ Id = '04'; Route = 'migration/build-inventory' }
    [pscustomobject]@{ Id = '05'; Route = 'migration/feature-mapping' }
    [pscustomobject]@{ Id = '06'; Route = 'migration/analyze-gaps-conflicts' }
    [pscustomobject]@{ Id = '07'; Route = 'migration/technical-design' }
    [pscustomobject]@{ Id = '08'; Route = 'migration/plan-waves' }
    [pscustomobject]@{ Id = '09'; Route = 'migration/bootstrap-target' }
    [pscustomobject]@{ Id = '10'; Route = 'migration/code-migration' }
    [pscustomobject]@{ Id = '11'; Route = 'shared/ai-review' }
    [pscustomobject]@{ Id = '12'; Route = 'shared/verification-testing' }
    [pscustomobject]@{ Id = '13'; Route = 'migration/verify-parity' }
    [pscustomobject]@{ Id = '14'; Route = 'migration/verify-regression' }
    [pscustomobject]@{ Id = '15'; Route = 'shared/knowledge-base' }
  )

  if ($rows.Count -ne $expectedSteps.Count) {
    $errors.Add("Migration orchestrator step table must contain exactly 15 rows; found $($rows.Count)")
  }

  $ids = @($rows | ForEach-Object { $_.'#'.Trim('`') })
  $routes = @($rows | ForEach-Object { $_.skill.Trim('`') })
  if (($ids | Select-Object -Unique).Count -ne $ids.Count) {
    $errors.Add('Migration orchestrator step IDs must be unique')
  }
  if (($routes | Select-Object -Unique).Count -ne $routes.Count) {
    $errors.Add('Migration orchestrator skill routes must be unique')
  }

  foreach ($removedDeliveryRoute in @('shared/gerrit-automation', 'shared/ccc-automation', 'shared/release')) {
    if ($removedDeliveryRoute -in $routes) {
      $errors.Add("Migration orchestrator step table contains removed delivery route: $removedDeliveryRoute")
    }
  }

  for ($index = 0; $index -lt [Math]::Min($rows.Count, $expectedSteps.Count); $index++) {
    $actualId = $ids[$index]
    $actualRoute = $routes[$index]
    $expected = $expectedSteps[$index]
    if ($actualId -ne $expected.Id -or $actualRoute -ne $expected.Route) {
      $errors.Add(
        "Migration orchestrator row $($index + 1) must be $($expected.Id) -> $($expected.Route); found $actualId -> $actualRoute"
      )
    }
  }

  $knowledgeRows = @($rows | Where-Object { $_.skill.Trim('`') -eq 'shared/knowledge-base' })
  $knowledgeIsLast = $rows.Count -gt 0 -and $rows[-1].skill.Trim('`') -eq 'shared/knowledge-base'
  if ($knowledgeRows.Count -ne 1 -or $knowledgeRows[0].'#'.Trim('`') -ne '15' -or -not $knowledgeIsLast) {
    $errors.Add('Migration orchestrator Knowledge Capture must be step 15 and the last row')
  }
  elseif (
    $knowledgeRows[0].artifact -ne '`kb-entry.md`' -or
    $knowledgeRows[0].gate -ne 'none' -or
    $knowledgeRows[0].'condition/prompt' -ne 'always; terminal'
  ) {
    $errors.Add('Migration orchestrator Knowledge Capture row must use kb-entry.md, no gate, and always; terminal')
  }

  $terminalArrow = ([char]0x2192).ToString()
  @(
    "greenfield $terminalArrow ``13-parity-report.md`` $terminalArrow knowledge-base"
    "incremental $terminalArrow ``14-regression-report.md`` $terminalArrow knowledge-base"
  ) | ForEach-Object {
    Require-Token $orchestratorText $_ 'Migration orchestrator terminal predecessor policy'
  }

  $bootstrapRow = $rows | Where-Object { $_.skill.Trim('`') -eq 'migration/bootstrap-target' }
  if ($null -eq $bootstrapRow -or (($bootstrapRow.psobject.Properties.Value -join ' ') -notmatch '(?i)greenfield')) {
    $errors.Add('Migration orchestrator bootstrap-target route must be conditional on greenfield')
  }
  $regressionRow = $rows | Where-Object { $_.skill.Trim('`') -eq 'migration/verify-regression' }
  if ($null -eq $regressionRow -or (($regressionRow.psobject.Properties.Value -join ' ') -notmatch '(?i)incremental')) {
    $errors.Add('Migration orchestrator verify-regression route must be conditional on incremental')
  }
  if (
    $null -ne $regressionRow -and
    (($regressionRow.psobject.Properties.Value -join ' ') -match '(?i)greenfield|project-specific|mode-compatible project route')
  ) {
    $errors.Add('Migration orchestrator verify-regression row must be incremental-only')
  }

  @(
    'result: blocked', 'mode: unknown', 'status: approved', 'status: draft',
    '`migration_unit_id`', '`Bootstrap Scope`',
    '`greenfield` / `design-new`', '`incremental` / `preserve-existing`',
    'Immediate predecessor artifact = exactly one orchestrator-provided path',
    'pre-change regression baseline', 'cannot waive or skip step 14',
    'latest executed artifact'
  ) | ForEach-Object {
    Require-Token $orchestratorText $_ 'Migration orchestrator contract'
  }
  @(
    '| `complete` | soft |'
    'result: complete | blocked'
    'Partial is route-specific: only an approved step-01 input-qualification artifact or the exact resumed step-10 approved/partial/auto-waive tuple may continue; every other partial artifact stops as invalid.'
    'An environment waiver never advances a non-step-10 artifact as partial.'
  ) | ForEach-Object {
    Require-Token $orchestratorText $_ 'Migration orchestrator route-specific partial lifecycle'
  }
  foreach ($forbiddenGenericPartial in @(
    '| `complete` or `partial` | soft |'
    'result: complete | partial | blocked'
    'Artifact có `status: approved` và `result: complete` hoặc `partial`'
    'với `result: complete` hoặc `partial`, không hỏi người dùng'
  )) {
    if ($orchestratorText.Contains($forbiddenGenericPartial)) {
      $errors.Add("Migration orchestrator authorizes generic partial continuation: $forbiddenGenericPartial")
    }
  }

  $modeGateText = Get-MarkdownSectionBody `
    $orchestratorText `
    'Mode and migration unit gate' `
    'Migration orchestrator mode policy'
  @(
    'absence before step 10 invocation is not itself a blocker',
    'does not invoke migration/verify-regression',
    'Greenfield always skips step 14; no base or project-specific regression route executes.',
    '`Bootstrap Scope = required`', '`Bootstrap Scope = not-required`',
    'skip step 09', 'pass the approved migration plan plus `foundation_baseline_id` to step 10',
    'exactly one approved foundation baseline record', 'target baseline reference',
    'foundation baseline approval reference',
    '`Foundation Baseline ID = pending-bootstrap`',
    'does not require an approved foundation baseline before step 09',
    'approved `FOUNDATION-*` record', '`Source Migration Unit ID` matches',
    'only when no approved foundation baseline exists'
  ) | ForEach-Object {
    Require-Token $modeGateText $_ 'Migration orchestrator mode policy'
  }
  if ($modeGateText -match '(?is)greenfield.{0,120}(?:may|can|approved).{0,120}(?:step 14|regression route)') {
    $errors.Add('Migration orchestrator must not permit a greenfield regression execution route')
  }

  $handoffText = Get-MarkdownSectionBody `
    $orchestratorText `
    'Migration handoff envelope' `
    'Migration orchestrator handoff'
  @(
    'Selected Migration Unit', '`migration_unit_id`', 'plan reference', 'approval reference',
    '`Bootstrap Scope`', 'Foundation Baseline ID', 'foundation baseline reference',
    'foundation baseline approval reference', 'pre-change regression baseline reference', 'Steps 11-13',
    'result: complete | blocked', 'approved step-01 input qualification', 'exact resumed step-10 waiver tuple',
    'after step 08 approval and selector choice'
  ) | ForEach-Object {
    Require-Token $handoffText $_ 'Migration orchestrator handoff'
  }

  $selectorTokens = @(
    '`migration_unit_id`', 'exactly one approved migration unit', 'approval reference',
    '`Bootstrap Scope`', 'missing or ambiguous selection yields `result: blocked`'
  )
  $selectorTokens | ForEach-Object {
    Require-Token $modeGateText $_ 'Migration orchestrator selector validation'
  }

  $protocolText = Get-MarkdownSectionBody `
    $orchestratorText `
    'Step execution protocol' `
    'Migration orchestrator execution policy'
  @(
    'validate approved artifact', 'continue from approved artifact',
    'result: blocked', 'status: draft', 'approval gate', 'downstream execution',
    'skip preserves latest executed artifact'
  ) | ForEach-Object {
    Require-Token $protocolText $_ 'Migration orchestrator execution policy'
  }
  Require-TokenOrder `
    $protocolText `
    'validate approved artifact' `
    'continue from approved artifact' `
    'Migration orchestrator approved continuation'
  Require-TokenOrder `
    $protocolText `
    'result: blocked' `
    'approval gate' `
    'Migration orchestrator blocked handling'
  @(
    'step 09 gate approval', (ConvertFrom-Utf8Base64 'dHJvbmcgY8O5bmcgbeG7mXQgdGhhbyB0w6Fj'), '`pending-step09-approval`',
    '`Approval Status = pending-approval`', '`Approval Status = approved`',
    (ConvertFrom-Utf8Base64 'dGhhbSBjaGnhur91IGJvb3RzdHJhcCBhcnRpZmFjdCDEkcOjIGR1eeG7h3QgY2jDrW5oIHjDoWM='),
    ('`Selected Migration Unit`' + (ConvertFrom-Utf8Base64 'IHbDoCBgQuG6o24gZ2hpIGJhc2VsaW5lIG7hu4FuIHThuqNuZ2A='))
  ) | ForEach-Object {
    Require-Token $protocolText $_ 'Migration orchestrator bootstrap approval transition'
  }
  Require-TokenOrder `
    $protocolText `
    'result: blocked' `
    'downstream execution' `
    'Migration orchestrator blocked handling'

  $automationResolutionText = Get-MarkdownSectionBody `
    $orchestratorText `
    'Automation mode resolution' `
    'Migration automation resolution'
  @(
    'before step 01', 'resolve exactly once', '`automation_mode`',
    'every migration step invocation', 'CLI takes precedence over profile'
  ) | ForEach-Object {
    Require-Token $automationResolutionText $_ 'Migration automation resolution'
  }
  Test-MarkdownTableExactColumns `
    $orchestratorText `
    'Automation mode resolution' `
    @('CLI flags', 'Profile `automation.mode`', 'Resolution/action') `
    'Migration automation resolution'
  $automationResolutionRows = @(Get-MarkdownTableRows `
    $orchestratorText `
    'Automation mode resolution' `
    'Migration automation resolution')
  $expectedAutomationResolutionRows = @(
    [pscustomobject]@{ Name = 'legacy default'; Cli = 'none'; Profile = 'missing'; Action = '`automation_mode: interactive`' }
    [pscustomobject]@{ Name = 'profile interactive'; Cli = 'none'; Profile = '`interactive`'; Action = '`automation_mode: interactive`' }
    [pscustomobject]@{ Name = 'profile auto'; Cli = 'none'; Profile = '`auto`'; Action = '`automation_mode: auto`' }
    [pscustomobject]@{ Name = 'profile auto-waive'; Cli = 'none'; Profile = '`auto-waive`'; Action = '`automation_mode: auto-waive`' }
    [pscustomobject]@{ Name = 'CLI auto override'; Cli = '`--auto`'; Profile = 'missing or any supported value'; Action = '`automation_mode: auto`' }
    [pscustomobject]@{ Name = 'CLI auto-waive override'; Cli = '`--auto-waive`'; Profile = 'missing or any supported value'; Action = '`automation_mode: auto-waive`' }
    [pscustomobject]@{ Name = 'conflicting CLI flags'; Cli = '`--auto --auto-waive`'; Profile = 'any'; Action = '`result: blocked` before step 01' }
    [pscustomobject]@{ Name = 'unknown profile enum'; Cli = 'any'; Profile = 'outside the supported enum'; Action = '`result: blocked` before step 01' }
  )
  foreach ($expectedRow in $expectedAutomationResolutionRows) {
    $matches = @($automationResolutionRows | Where-Object {
      $_.'CLI flags' -ceq $expectedRow.Cli -and $_.'Profile `automation.mode`' -ceq $expectedRow.Profile
    })
    if ($matches.Count -ne 1 -or $matches[0].'Resolution/action' -cne $expectedRow.Action) {
      $errors.Add("Migration automation resolution scenario invalid: $($expectedRow.Name)")
    }
  }

  $automationGateText = Get-MarkdownSectionBody `
    $orchestratorText `
    'Automation gate policy' `
    'Migration automation gate policy'
  Test-MarkdownTableExactColumns `
    $orchestratorText `
    'Automation gate policy' `
    @('Artifact result', 'Gate', 'interactive', 'auto', 'auto-waive') `
    'Migration automation gate policy'
  $automationGateRows = @(Get-MarkdownTableRows `
    $orchestratorText `
    'Automation gate policy' `
    'Migration automation gate policy')
  $nonBlockedSoftRow = @($automationGateRows | Where-Object {
    $_.'Artifact result' -ceq '`complete`' -and $_.Gate -ceq 'soft'
  })
  if (
    $nonBlockedSoftRow.Count -ne 1 -or
    $nonBlockedSoftRow[0].interactive -cne 'ask the user' -or
    $nonBlockedSoftRow[0].auto -cne '`status: approved`; `approval_source: auto`; without question' -or
    $nonBlockedSoftRow[0].'auto-waive' -cne '`status: approved`; `approval_source: auto-waive`; without question'
  ) {
    $errors.Add('Migration automation non-blocked soft-gate policy invalid')
  }
  $blockedRow = @($automationGateRows | Where-Object { $_.'Artifact result' -ceq '`blocked`' -and $_.Gate -ceq 'any' })
  if (
    $blockedRow.Count -ne 1 -or
    $blockedRow[0].interactive -cne 'stop before approval' -or
    $blockedRow[0].auto -cne 'stop before approval' -or
    $blockedRow[0].'auto-waive' -cne 'stop before approval'
  ) {
    $errors.Add('Migration automation blocked-artifact policy invalid')
  }
  $hardRow = @($automationGateRows | Where-Object { $_.'Artifact result' -ceq 'any' -and $_.Gate -ceq 'HARD' })
  if (
    $hardRow.Count -ne 1 -or
    $hardRow[0].interactive -cne 'stop for explicit confirmation' -or
    $hardRow[0].auto -cne 'stop for explicit confirmation' -or
    $hardRow[0].'auto-waive' -cne 'stop for explicit confirmation'
  ) {
    $errors.Add('Migration automation HARD-gate policy invalid')
  }
  @(
    'blocked artifacts are not auto-approved',
    'HARD gates are never auto-approved'
  ) | ForEach-Object {
    Require-Token $automationGateText $_ 'Migration automation gate policy'
  }

  $handoffColumns = @(
    'Migration Unit ID', 'Plan Reference', 'Approval Reference',
    'Mode Constraint', 'Bootstrap Scope', 'Foundation Baseline ID',
    'Foundation Baseline Reference', 'Foundation Baseline Approval Reference',
    'Baseline Reference', 'Trace IDs'
  )
  foreach ($templateContract in @(
    [pscustomobject]@{ Path = 'templates/migration/bootstrap-report.md'; Context = 'Migration bootstrap handoff template' }
    [pscustomobject]@{ Path = 'templates/migration/implementation-report.md'; Context = 'Migration implementation handoff template' }
    [pscustomobject]@{ Path = 'templates/migration/review-report.md'; Context = 'Migration review handoff template' }
    [pscustomobject]@{ Path = 'templates/migration/verification-report.md'; Context = 'Migration verification handoff template' }
    [pscustomobject]@{ Path = 'templates/migration/parity-report.md'; Context = 'Migration parity handoff template' }
    [pscustomobject]@{ Path = 'templates/migration/regression-report.md'; Context = 'Migration regression handoff template' }
  )) {
    $templatePath = Join-Path $root $templateContract.Path
    if (-not (Test-Path $templatePath)) {
      $errors.Add("Missing template: $($templateContract.Path)")
      continue
    }
    $templateText = Get-Content -Raw -Encoding utf8 $templatePath
    Test-MarkdownTableColumns `
      $templateText `
      'Selected Migration Unit' `
      $handoffColumns `
      $templateContract.Context
    if ($templateContract.Path -in 'templates/migration/review-report.md', 'templates/migration/verification-report.md') {
      Require-Token `
        $templateText `
        (ConvertFrom-Utf8Base64 'Q2jhu4kgbWlncmF0aW9uOiB0aMOqbSBgcmVzdWx0OiBjb21wbGV0ZSB8IGJsb2NrZWRg') `
        $templateContract.Context
    }
  }

  foreach ($skillContract in @(
    [pscustomobject]@{ Path = 'skills/shared/ai-review/SKILL.md'; Context = 'Shared AI review migration extension' }
    [pscustomobject]@{ Path = 'skills/shared/verification-testing/SKILL.md'; Context = 'Shared verification migration extension' }
    [pscustomobject]@{ Path = 'skills/migration/verify-parity/SKILL.md'; Context = 'Migration parity handoff' }
    [pscustomobject]@{ Path = 'skills/migration/verify-regression/SKILL.md'; Context = 'Migration regression handoff' }
  )) {
    $skillPath = Join-Path $root $skillContract.Path
    if (-not (Test-Path $skillPath)) {
      $errors.Add("Missing skill: $($skillContract.Path)")
      continue
    }
    $skillText = Get-Content -Raw -Encoding utf8 $skillPath
    $extensionText = Get-MarkdownSectionBody `
      $skillText `
      'Migration-only handoff extension' `
      $skillContract.Context
    @(
      '`workflow_type: migration`', 'feature and bugfix', 'immediate predecessor',
      '`Selected Migration Unit`', '`migration_unit_id`', 'plan reference',
      'approval reference', 'mode constraint', '`Bootstrap Scope`', 'Foundation Baseline ID',
      'foundation baseline reference', 'foundation baseline approval reference', 'baseline reference', 'trace IDs',
      '`result: complete | blocked`', '`result: blocked`'
    ) | ForEach-Object {
      Require-Token $extensionText $_ $skillContract.Context
    }
  }

  foreach ($verificationTemplateContract in @(
    [pscustomobject]@{ Path = 'templates/migration/regression-report.md'; Context = 'Migration regression verification template' }
  )) {
    $templatePath = Join-Path $root $verificationTemplateContract.Path
    if (-not (Test-Path $templatePath)) { continue }
    $templateText = Get-Content -Raw -Encoding utf8 $templatePath
    Test-MarkdownTableColumns `
      $templateText `
      (ConvertFrom-Utf8Base64 'S+G6v3QgbHXhuq1uIHjDoWMgbWluaCBtaWdyYXRpb24=') `
      @('Parity Verdict', 'Regression Applicability', 'Regression Verdict', 'Evidence Reference') `
      $verificationTemplateContract.Context
  }

  foreach ($sharedDeliveryContract in @(
    [pscustomobject]@{ Path = 'skills/shared/gerrit-automation/SKILL.md'; Tokens = @('HARD gate', 'upload Gerrit') }
    [pscustomobject]@{ Path = 'skills/shared/ccc-automation/SKILL.md'; Tokens = @('OPTIONAL', 'optional') }
    [pscustomobject]@{ Path = 'skills/shared/release/SKILL.md'; Tokens = @('OPTIONAL', 'HARD gate') }
  )) {
    $sharedDeliveryPath = Join-Path $root $sharedDeliveryContract.Path
    if (-not (Test-Path $sharedDeliveryPath)) {
      $errors.Add("Missing independent shared skill: $($sharedDeliveryContract.Path)")
      continue
    }
    $sharedDeliveryText = Get-Content -Raw -Encoding utf8 $sharedDeliveryPath
    foreach ($token in $sharedDeliveryContract.Tokens) {
      Require-Token $sharedDeliveryText $token "Independent shared skill $($sharedDeliveryContract.Path)"
    }
  }

  $knowledgeSkillPath = Join-Path $root 'skills/shared/knowledge-base/SKILL.md'
  if (-not (Test-Path $knowledgeSkillPath)) {
    $errors.Add('Missing terminal shared skill: skills/shared/knowledge-base/SKILL.md')
  }
  else {
    $knowledgeSkillText = Get-Content -Raw -Encoding utf8 $knowledgeSkillPath
    @(
      'Terminal input artifact = exactly one orchestrator-provided path',
      'terminal input artifact',
      'scan all `.md` artifacts in `RUN_DIR`',
      'authoritative `workflow_type`', '`knowledge_step_id`',
      '`15-knowledge-base`', '`09-knowledge-base`'
    ) | ForEach-Object {
      Require-Token $knowledgeSkillText $_ 'Knowledge Capture terminal input contract'
    }
    $knowledgeVerdict = Get-MarkdownSectionBody `
      $knowledgeSkillText `
      'Workflow-aware terminal verdict' `
      'Knowledge Capture workflow-aware terminal verdict'
    @(
      'Migration greenfield', '`13-parity-report.md`', 'migration incremental',
      '`14-regression-report.md`', 'Feature and bugfix', '`verification-report.md`',
      'Release Verdict', '`not-run`', (ConvertFrom-Utf8Base64 'buG6sW0gdHJvbmcgYFJVTl9ESVJg'),
      '`Completion Verdict: complete`', '`status: approved`', '`result: complete`',
      '`Verification Verdict: PASS`', (ConvertFrom-Utf8Base64 'cGFyaXR5IGV2aWRlbmNlIGPDuW5nIHJ1biDEkcOjIGR1eeG7h3Q=')
    ) | ForEach-Object {
      Require-Token $knowledgeVerdict $_ 'Knowledge Capture workflow-aware terminal verdict'
    }
    $knowledgeFoundationProposal = Get-MarkdownSectionBody `
      $knowledgeSkillText `
      'Migration foundation update proposal' `
      'Knowledge Capture migration foundation contract'
    @(
      'project-pack update proposal', '`target-baseline.md`', '`foundation_baseline_id`',
      'Source Migration Unit ID', 'Foundation Baseline Approval Reference',
      'implementation artifact', 'terminal artifact',
      'never edits the canonical project pack', 'project-pack review gate'
    ) | ForEach-Object {
      Require-Token $knowledgeFoundationProposal $_ 'Knowledge Capture migration foundation contract'
    }
  }

  foreach ($forbiddenToken in @('manifest.yaml', 'state.json', '.aitoolkit/run', '--resume')) {
    if ($orchestratorText -match [regex]::Escape($forbiddenToken)) {
      $errors.Add("Migration orchestrator contains prohibited persistence token: $forbiddenToken")
    }
  }

  Require-Token $commandText $featureSlugHint 'Migrate command'
  Require-Token $commandText '$ARGUMENTS' 'Migrate command'
  Require-Token $commandText '<slug>' 'Migrate command'
  foreach ($launcherContract in @(
    [pscustomobject]@{ Text = $commandText; Context = 'Migrate command automation flags' }
    [pscustomobject]@{ Text = $codexLauncherText; Context = 'Codex launcher automation flags' }
  )) {
    Require-Token $launcherContract.Text '`--auto`' $launcherContract.Context
    Require-Token $launcherContract.Text '`--auto-waive`' $launcherContract.Context
    Require-Token $launcherContract.Text 'forward the selected flag unchanged' $launcherContract.Context
    Require-Token $launcherContract.Text 'forward both unchanged' $launcherContract.Context
  }
  $delegateMatches = [regex]::Matches($commandText, '(?i)aitoolkit/migrate')
  if ($delegateMatches.Count -ne 1) {
    $errors.Add("Migrate command must delegate exactly once to aitoolkit/migrate; found $($delegateMatches.Count)")
  }
}

function Test-Onboarding {
  $commandPath = Join-Path $root 'commands/migration-onboarding.md'
  $orchestratorPath = Join-Path $root 'skills/aitoolkit/migration-onboarding/SKILL.md'
  $routerPath = Join-Path $root 'codex/skills/aitoolkit/SKILL.md'
  $stepRoot = Join-Path $root 'skills/migration-onboarding'
  $stepTableSection = [Text.Encoding]::UTF8.GetString(
    [Convert]::FromBase64String('QuG6o25nIGLGsOG7m2MgKG1pZ3JhdGlvbiBvbmJvYXJkaW5nKQ==')
  )
  $noDefaultScripts = [Text.Encoding]::UTF8.GetString(
    [Convert]::FromBase64String('S2jDtG5nIHThuqFvIGBzY3JpcHRzL2AgbeG6t2MgxJHhu4tuaC4=')
  )
  $routeOnlyKnowledge = [Text.Encoding]::UTF8.GetString(
    [Convert]::FromBase64String('a2jDtG5nIGNo4bupYSBwcm9qZWN0IGtub3dsZWRnZQ==')
  )
  $noProductionCode = [Text.Encoding]::UTF8.GetString(
    [Convert]::FromBase64String('T25ib2FyZGluZyBraMO0bmcgc2luaCBwcm9kdWN0aW9uIGNvZGU=')
  )
  $routerSectionName = [Text.Encoding]::UTF8.GetString(
    [Convert]::FromBase64String('Vmnhu4djIGPhuqduIGzDoG0=')
  )

  foreach ($requiredFile in @($commandPath, $orchestratorPath, $routerPath)) {
    if (-not (Test-Path $requiredFile)) {
      $relativePath = $requiredFile.Substring($root.Length).TrimStart('\').Replace('\', '/')
      $errors.Add("Missing onboarding file: $relativePath")
    }
  }

  if (Test-Path $commandPath) {
    $commandText = Get-Content -Raw -Encoding utf8 $commandPath
    $delegateMatches = [regex]::Matches($commandText, '(?i)aitoolkit/migration-onboarding')
    if ($delegateMatches.Count -ne 1) {
      $errors.Add("Migration onboarding command must delegate exactly once to aitoolkit/migration-onboarding; found $($delegateMatches.Count)")
    }
    Require-Token $commandText '$ARGUMENTS' 'Migration onboarding command'
    $frontMatter = [regex]::Match($commandText, '\A---\r?\n(?<body>.*?)\r?\n---', 'Singleline')
    $expectedArgumentHint = 'argument-hint: "--legacy <path> --target <path> [--requirements <path> ...] [--uiux <path> ...] [--migration-docs <path> ...] [--architecture-docs <path> ...]"'
    if (-not $frontMatter.Success -or $frontMatter.Groups['body'].Value -notmatch "(?m)^$([regex]::Escape($expectedArgumentHint))\s*$") {
      $errors.Add('Migration onboarding command argument-hint must expose the named legacy, target, and repeatable categorized document flags')
    }
    $commandArguments = Get-MarkdownSectionBody $commandText 'Argument contract' 'Migration onboarding command'
    @(
      'current target-project context', '`$ARGUMENTS`', 'project root is not an argument',
      '`--legacy`', '`--target`', '`--requirements`', '`--uiux`', '`--migration-docs`',
      '`--architecture-docs`', 'repeatable', 'file or directory'
    ) |
      ForEach-Object { Require-Token $commandArguments $_ 'Migration onboarding command argument contract' }
  }

  if (Test-Path $orchestratorPath) {
    $orchestratorText = Get-Content -Raw -Encoding utf8 $orchestratorPath
    $rows = @(Get-MarkdownTableRows $orchestratorText $stepTableSection 'Migration onboarding orchestrator')
    $expectedSteps = @(
      [pscustomobject]@{ Id = '01'; Skill = 'inline (orchestrator)'; Artifact = '01-onboarding-input.md'; Gate = 'block-only' }
      [pscustomobject]@{ Id = '02'; Skill = 'migration-onboarding/inspect-project'; Artifact = '02-project-inspection.md'; Gate = 'soft' }
      [pscustomobject]@{ Id = '03'; Skill = 'migration-onboarding/classify-mode'; Artifact = '03-mode-proposal.md'; Approver = 'Tech Lead'; Gate = 'soft' }
      [pscustomobject]@{ Id = '04'; Skill = 'migration-onboarding/create-project-pack'; Artifact = '04-project-pack-review.md'; Approver = 'Tech Lead'; Gate = 'HARD' }
    )
    if ($rows.Count -ne $expectedSteps.Count) {
      $errors.Add("Migration onboarding orchestrator step table must contain exactly 4 rows; found $($rows.Count)")
    }
    for ($index = 0; $index -lt [Math]::Min($rows.Count, $expectedSteps.Count); $index++) {
      $expected = $expectedSteps[$index]
      $actualId = $rows[$index].'#'.Trim('`')
      $actualSkill = $rows[$index].skill.Trim('`')
      $actualArtifact = $rows[$index].artifact.Trim('`')
      $actualGate = $rows[$index].gate.Trim('`')
      $actualApprover = $rows[$index].approver.Trim('`')
      $wrongApprover = $null -ne $expected.Approver -and $actualApprover -ne $expected.Approver
      if (
        $actualId -ne $expected.Id -or $actualSkill -ne $expected.Skill -or
        $actualArtifact -ne $expected.Artifact -or $actualGate -ne $expected.Gate -or $wrongApprover
      ) {
        $errors.Add("Migration onboarding row $($index + 1) must be $($expected.Id) -> $($expected.Skill) -> $($expected.Artifact) with gate $($expected.Gate); found $actualId -> $actualSkill -> $actualArtifact with gate $actualGate")
      }
    }

    $modeGate = Get-MarkdownSectionBody $orchestratorText 'Mode classification gate' 'Migration onboarding mode gate'
    @(
      'placeholder-only target', '`mode: unknown`', '`result: blocked`',
      'stable target architecture', '`incremental` / `preserve-existing`',
      'ambiguous toolchain', 'commands remain `null`', 'Tech Lead approval',
      'present the blocker decision', 'record the approved decision as evidence',
      'rerun step 03', '`result: complete` or `partial`'
    ) | ForEach-Object { Require-Token $modeGate $_ 'Migration onboarding mode gate' }

    $argumentContract = Get-MarkdownSectionBody $orchestratorText 'Argument contract' 'Migration onboarding orchestrator arguments'
    @(
      'current target-project context', 'never parse project root', '`--legacy`', '`--target`',
      '`--requirements`', '`--uiux`', '`--migration-docs`', '`--architecture-docs`',
      'repeatable', 'file or directory'
    ) |
      ForEach-Object { Require-Token $argumentContract $_ 'Migration onboarding orchestrator arguments' }

    $documentResolver = Get-MarkdownSectionBody $orchestratorText 'Document resolver contract' 'Migration onboarding document resolver'
    @(
      'docs/aitoolkit/inputs/requirements/', 'docs/aitoolkit/inputs/uiux/',
      'docs/aitoolkit/inputs/migration/', 'docs/aitoolkit/inputs/architecture/',
      'explicit flag paths', 'matching inbox directory if present', 'canonical-path merge/dedupe',
      'readability/format validation', 'categorized Evidence records',
      'Category', 'Canonical Path', 'Input Source', 'Format', 'Readability', 'Evidence ID'
    ) | ForEach-Object { Require-Token $documentResolver $_ 'Migration onboarding document resolver' }
    Require-TokenOrder $documentResolver 'explicit flag paths' 'matching inbox directory if present' 'Migration onboarding document resolver priority'
    Require-TokenOrder $documentResolver 'matching inbox directory if present' 'canonical-path merge/dedupe' 'Migration onboarding document resolver priority'
    Require-TokenOrder $documentResolver 'canonical-path merge/dedupe' 'readability/format validation' 'Migration onboarding document resolver priority'
    Require-TokenOrder $documentResolver 'readability/format validation' 'categorized Evidence records' 'Migration onboarding document resolver priority'

    $inboxCollectionRule = [regex]::Match(
      $documentResolver,
      '(?m)^2\.\s+\*\*matching inbox directory if present\*\*\s+-\s+(?<body>.*)$'
    )
    if (
      -not $inboxCollectionRule.Success -or
      $inboxCollectionRule.Groups['body'].Value -notmatch 'append every regular file' -or
      $inboxCollectionRule.Groups['body'].Value -notmatch 'without filtering by readability or format' -or
      $inboxCollectionRule.Groups['body'].Value -match '(?i)only readable|filter(?:ed|ing)? before validation'
    ) {
      $errors.Add('Migration onboarding inbox collection must collect every regular file before readability/format validation')
    }

    $dedupeRule = [regex]::Match(
      $documentResolver,
      '(?m)^3\.\s+\*\*canonical-path merge/dedupe\*\*\s+-\s+(?<body>.*)$'
    )
    $dedupeBody = if ($dedupeRule.Success) { $dedupeRule.Groups['body'].Value } else { '' }
    if (
      -not $dedupeRule.Success -or
      $dedupeBody -notmatch 'stable absolute filesystem identity' -or
      $dedupeBody -notmatch 'keep the first occurrence' -or
      $dedupeBody -notmatch 'explicit records are first' -or
      $dedupeBody -notmatch 'Input Source = explicit' -or
      $dedupeBody -match '(?i)keep the last|Input Source = inbox'
    ) {
      $errors.Add('Migration onboarding canonical dedupe must use stable absolute identity, first-wins, and explicit source authority')
    }

    $failureRows = @(Get-MarkdownTableRows $orchestratorText 'Document resolution failures' 'Migration onboarding document failures')
    $requiredFailureRows = @(
      [pscustomobject]@{ Condition = 'explicit path is missing or unreadable'; Behavior = 'block' }
      [pscustomobject]@{ Condition = 'present inbox directory is unreadable'; Behavior = 'block' }
      [pscustomobject]@{ Condition = 'discovered regular file is unreadable'; Behavior = 'block; never silently omit' }
      [pscustomobject]@{ Condition = 'document format cannot be opened or decoded'; Behavior = 'block; never silently skip' }
      [pscustomobject]@{ Condition = 'optional inbox directory is absent'; Behavior = 'continue' }
    )
    foreach ($requiredFailureRow in $requiredFailureRows) {
      $failureRow = $failureRows | Where-Object { $_.Condition -match [regex]::Escape($requiredFailureRow.Condition) }
      if ($null -eq $failureRow -or $failureRow.Result -notmatch $requiredFailureRow.Behavior) {
        $errors.Add("Migration onboarding document failure must $($requiredFailureRow.Behavior): $($requiredFailureRow.Condition)")
      }
    }

    $boundaries = Get-MarkdownSectionBody $orchestratorText 'Boundaries' 'Migration onboarding boundaries'
    @('must not move, rename, rewrite, or modify', 'source document', 'legacy/target roots') |
      ForEach-Object { Require-Token $boundaries $_ 'Migration onboarding read-only boundary' }

    $handoffContract = Get-MarkdownSectionBody $orchestratorText 'Onboarding handoff contract' 'Migration onboarding handoff'
    @(
      'Immediate predecessor artifact = exactly one orchestrator-provided path',
      'step 03 forwards', 'inspection evidence references', 'command authority',
      'step 04 receives only', '`03-mode-proposal.md`'
    ) | ForEach-Object { Require-Token $handoffContract $_ 'Migration onboarding handoff' }

    $stepProtocol = Get-MarkdownSectionBody $orchestratorText 'Step execution protocol' 'Migration onboarding execution policy'
    $blockedRuleMatch = [regex]::Match($stepProtocol, '(?m)^5\.\s*(?<body>.*)$')
    if (-not $blockedRuleMatch.Success) {
      $errors.Add('Migration onboarding execution policy missing numbered blocked-handling rule 5')
    }
    else {
      $blockedRule = $blockedRuleMatch.Groups['body'].Value
      Require-TokenOrder $blockedRule 'result: blocked' 'normal approval gate' 'Migration onboarding blocked handling'
      Require-TokenOrder $blockedRule 'result: blocked' 'downstream execution' 'Migration onboarding blocked handling'
    }

    $packGate = Get-MarkdownSectionBody $orchestratorText 'Project-pack Tech Lead HARD review gate' 'Migration onboarding pack gate'
    @(
      'step 04', 'Tech Lead', 'HARD', 'explicit approval',
      'staged drafts', 'before approval', 'publish the canonical',
      '`docs/aitoolkit/project.yaml`', '`docs/aitoolkit/migration-project/`',
      '`project_pack.reviewed_at`', '`project_pack.review_evidence`', 'recorded content revisions',
      'RFC 3339', '`status: approved`', 'downstream migration'
    ) | ForEach-Object { Require-Token $packGate $_ 'Migration onboarding pack gate' }
    Require-TokenOrder $packGate 'staged drafts' 'explicit approval' 'Migration onboarding staged publication'
    Require-TokenOrder $packGate 'explicit approval' 'publish the canonical' 'Migration onboarding staged publication'
    Require-TokenOrder $packGate 'publish the canonical' '`status: approved`' 'Migration onboarding staged publication'
    Require-TokenOrder $packGate '`status: approved`' 'downstream migration' 'Migration onboarding staged publication'
  }

  $stepContracts = @(
    [pscustomobject]@{
      Name = 'inspect-project'; OutputTokens = @(
        '<RUN_DIR>/02-project-inspection.md',
        'must not move, rename, rewrite, or modify'
      )
      Section = 'Evidence contract'; SectionTokens = @('legacy', 'target', 'documents', 'toolchain', 'placeholder-only')
    }
    [pscustomobject]@{
      Name = 'classify-mode'; OutputTokens = @('<RUN_DIR>/03-mode-proposal.md')
      Section = 'Classification contract'; SectionTokens = @(
        'placeholder-only target', '`mode: unknown`', '`result: blocked`', 'Tech Lead confirmation',
        'stable target architecture', '`incremental`', '`preserve-existing`'
      )
      ExtraSection = 'Blocked decision protocol'; ExtraSectionTokens = @(
        'present the decision question', 'record the approved decision as evidence',
        'rerun this skill', '`result: complete` or `partial`'
      )
      HandoffSection = 'Inspection evidence handoff'; HandoffSectionTokens = @(
        'legacy', 'target', 'documents', 'toolchain', 'command authority',
        'source', 'scope', 'blocker', '<RUN_DIR>/03-mode-proposal.md',
        (ConvertFrom-Utf8Base64 'QsOgbiBnaWFvIGLhurFuZyBjaOG7qW5nIHTDoGkgbGnhu4d1'), 'Category', 'Canonical Path', 'Input Source',
        'Format', 'Readability', 'Evidence ID'
      )
    }
    [pscustomobject]@{
      Name = 'create-project-pack'; OutputTokens = @(
        '<project>/docs/aitoolkit/project.yaml',
        '<project>/docs/aitoolkit/migration-project/SKILL.md',
        '<project>/docs/aitoolkit/migration-project/references/legacy-system.md',
        '<project>/docs/aitoolkit/migration-project/references/target-baseline.md',
        '<project>/docs/aitoolkit/migration-project/references/architecture-rules.md',
        '<project>/docs/aitoolkit/migration-project/references/mapping-rules.md',
        '<project>/docs/aitoolkit/migration-project/references/uiux-rules.md',
        '<project>/docs/aitoolkit/migration-project/references/testing-rules.md',
        '<project>/docs/aitoolkit/migration-project/references/definition-of-done.md',
        '<RUN_DIR>/project-draft/project.yaml',
        '<RUN_DIR>/project-draft/migration-project/SKILL.md',
        '<RUN_DIR>/04-project-pack-review.md', '`reviewed_at`', '`review_evidence`',
        (ConvertFrom-Utf8Base64 'YMSQ4buZIG3hu5tpIGPhu6dhIHJldmlld2A='), 'content revisions', '`automation.mode: interactive`',
        '`output.artifact_language: vi`', 'must not modify source documents'
      )
      Section = 'Pack index contract'; SectionTokens = @('route-only index', 'references/', $routeOnlyKnowledge, $noDefaultScripts)
      ExtraSection = 'Staging contract'; ExtraSectionTokens = @(
        '<RUN_DIR>/project-draft/', 'must not modify canonical',
        'HARD gate', 'publish canonical outputs'
      )
      HandoffSection = 'Project profile document contract'; HandoffSectionTokens = @(
        'requirements', 'uiux', 'migration', 'architecture', 'Canonical Path',
        'Input Source', 'explicit', 'inbox', 'Evidence ID', '<RUN_DIR>/03-mode-proposal.md',
        'exactly the four categorized lists', 'contains exactly `path`, `input_source`, `format`, `readability`, and `evidence_id`',
        'no missing or extra keys'
      )
    }
  )

  foreach ($contract in $stepContracts) {
    $skillPath = Join-Path $stepRoot "$($contract.Name)/SKILL.md"
    if (-not (Test-Path $skillPath)) {
      $errors.Add("Missing migration onboarding skill: $($contract.Name)/SKILL.md")
      continue
    }
    $skillText = Get-Content -Raw -Encoding utf8 $skillPath
    $outputContract = Get-MarkdownSectionBody $skillText 'Output contract' "Onboarding skill $($contract.Name) output"
    @($noProductionCode) + $contract.OutputTokens | ForEach-Object {
      Require-Token $outputContract $_ "Onboarding skill $($contract.Name) output"
    }
    $sectionText = Get-MarkdownSectionBody $skillText $contract.Section "Onboarding skill $($contract.Name) policy"
    $contract.SectionTokens | ForEach-Object {
      Require-Token $sectionText $_ "Onboarding skill $($contract.Name) section $($contract.Section)"
    }
    if ($null -ne $contract.ExtraSection) {
      $extraSectionText = Get-MarkdownSectionBody $skillText $contract.ExtraSection "Onboarding skill $($contract.Name) policy"
      $contract.ExtraSectionTokens | ForEach-Object {
        Require-Token $extraSectionText $_ "Onboarding skill $($contract.Name) section $($contract.ExtraSection)"
      }
    }
    if ($null -ne $contract.HandoffSection) {
      $handoffSectionText = Get-MarkdownSectionBody $skillText $contract.HandoffSection "Onboarding skill $($contract.Name) handoff"
      $contract.HandoffSectionTokens | ForEach-Object {
        Require-Token $handoffSectionText $_ "Onboarding skill $($contract.Name) section $($contract.HandoffSection)"
      }
    }
    if ($contract.Name -eq 'create-project-pack') {
      $inputsText = Get-MarkdownSectionBody $skillText 'Inputs' 'Onboarding skill create-project-pack inputs'
      Require-Token $inputsText 'Immediate predecessor artifact = exactly one orchestrator-provided path' 'Onboarding skill create-project-pack inputs'
      Require-Token $inputsText '<RUN_DIR>/03-mode-proposal.md' 'Onboarding skill create-project-pack inputs'
      if ($inputsText -match '(?i)(?<![A-Za-z0-9])(?:01|02|04)-[A-Za-z0-9-]+\.md(?![A-Za-z0-9])') {
        $errors.Add('Onboarding skill create-project-pack Inputs reads a non-predecessor numbered artifact')
      }
    }
  }

  $classifyPath = Join-Path $stepRoot 'classify-mode/SKILL.md'
  if (Test-Path $classifyPath) {
    $classifyText = Get-Content -Raw -Encoding utf8 $classifyPath
    $classificationRows = @(Get-MarkdownTableRows $classifyText 'Classification contract' 'Onboarding classification policy')
    $placeholderRow = $classificationRows | Where-Object { $_.'Observable evidence' -match '(?i)placeholder-only' }
    if ($null -eq $placeholderRow -or $placeholderRow.'Proposed mode' -notmatch 'unknown' -or $placeholderRow.'Architecture policy' -notmatch 'unknown' -or $placeholderRow.'Result/action' -notmatch 'result: blocked') {
      $errors.Add('Onboarding classification table must keep placeholder-only target unknown/blocked')
    }
    $stableRow = $classificationRows | Where-Object { $_.'Observable evidence' -match '(?i)stable target architecture' }
    if ($null -eq $stableRow -or $stableRow.'Proposed mode' -notmatch 'incremental' -or $stableRow.'Architecture policy' -notmatch 'preserve-existing') {
      $errors.Add('Onboarding classification table must propose incremental/preserve-existing for stable target')
    }
    $commandRows = @(Get-MarkdownTableRows $classifyText 'Command ambiguity contract' 'Onboarding command ambiguity policy')
    $ambiguousRow = $commandRows | Where-Object { $_.'Observable command evidence' -match '(?i)ambiguous toolchain' }
    if (
      $null -eq $ambiguousRow -or $ambiguousRow.Value -notmatch 'null' -or
      $ambiguousRow.Authority -notmatch 'unknown' -or $ambiguousRow.Blocker -notmatch 'required' -or
      $ambiguousRow.'Result/action' -notmatch 'result: blocked'
    ) {
      $errors.Add('Onboarding classification table must keep ambiguous toolchain commands null/blocked')
    }
  }

  $modeTemplatePath = Join-Path $root 'templates/migration/mode-proposal.md'
  if (-not (Test-Path $modeTemplatePath)) {
    $errors.Add('Missing onboarding template: templates/migration/mode-proposal.md')
  }
  else {
    $modeTemplateText = Get-Content -Raw -Encoding utf8 $modeTemplatePath
    $proposalRows = @(Get-MarkdownTableRows $modeTemplateText (ConvertFrom-Utf8Base64 'xJDhu4EgeHXhuqV0') 'Onboarding mode proposal template')
    if ($proposalRows.Count -ne 1 -or $proposalRows[0].Mode -notmatch 'unknown') {
      $errors.Add('Onboarding mode proposal template must express greenfield, incremental, and unknown')
    }
    Test-MarkdownTableColumns $modeTemplateText (ConvertFrom-Utf8Base64 'UGjDom4gZ2nhuqNpIGzhu4duaA==') @('Command Field', 'Value', 'Authority', 'Source', 'Scope', 'Blocker') 'Onboarding mode proposal template'
    Test-MarkdownTableColumns $modeTemplateText (ConvertFrom-Utf8Base64 'QsOgbiBnaWFvIGLhurFuZyBjaOG7qW5nIGto4bqjbyBzw6F0') @('Area', 'Evidence References') 'Onboarding mode proposal template'
  }

  $documentRecordColumns = @('Category', 'Canonical Path', 'Input Source', 'Format', 'Readability', 'Evidence ID')
  $documentEvidenceChain = @(
    [pscustomobject]@{
      Path = 'templates/migration/onboarding-input.md'; Section = (ConvertFrom-Utf8Base64 'QuG6o24gZ2hpIGLhurFuZyBjaOG7qW5nIHTDoGkgbGnhu4d1')
      Context = 'Onboarding input template'
    }
    [pscustomobject]@{
      Path = 'templates/migration/project-inspection.md'; Section = (ConvertFrom-Utf8Base64 'QuG6o24gZ2hpIGLhurFuZyBjaOG7qW5nIHTDoGkgbGnhu4d1')
      Context = 'Onboarding project inspection template'
    }
    [pscustomobject]@{
      Path = 'templates/migration/mode-proposal.md'; Section = (ConvertFrom-Utf8Base64 'QsOgbiBnaWFvIGLhurFuZyBjaOG7qW5nIHTDoGkgbGnhu4d1')
      Context = 'Onboarding mode proposal template'
    }
    [pscustomobject]@{
      Path = 'templates/migration/project-pack-review.md'; Section = (ConvertFrom-Utf8Base64 'QuG6sW5nIGNo4bupbmcgdMOgaSBsaeG7h3UgcHJvZmlsZQ==')
      Context = 'Onboarding project pack review template'
    }
  )
  foreach ($documentEvidenceStage in $documentEvidenceChain) {
    $documentEvidencePath = Join-Path $root $documentEvidenceStage.Path
    if (-not (Test-Path $documentEvidencePath)) {
      $errors.Add("Missing onboarding template: $($documentEvidenceStage.Path)")
      continue
    }
    $documentEvidenceText = Get-Content -Raw -Encoding utf8 $documentEvidencePath
    Test-MarkdownTableColumns `
      $documentEvidenceText `
      $documentEvidenceStage.Section `
      $documentRecordColumns `
      $documentEvidenceStage.Context
    Test-MarkdownTableExactColumns `
      $documentEvidenceText `
      $documentEvidenceStage.Section `
      $documentRecordColumns `
      $documentEvidenceStage.Context
  }

  if (Test-Path $routerPath) {
    $routerText = Get-Content -Raw -Encoding utf8 $routerPath
    $routingSection = Get-MarkdownSectionBody $routerText $routerSectionName 'Codex AIToolkit router'
    @('`migration-onboarding`', '`migrate`', '`bugfix`', '`feature`') | ForEach-Object {
      Require-Token $routingSection $_ 'Codex AIToolkit router workflows'
    }
    Require-Token $routingSection 'skills/aitoolkit/<workflow>/SKILL.md' 'Codex AIToolkit router path'
    $routerArguments = Get-MarkdownSectionBody $routerText 'Migration onboarding argument contract' 'Codex AIToolkit router arguments'
    @(
      'current target-project context', 'project root', '`--legacy`', '`--target`',
      '`--requirements`', '`--uiux`', '`--migration-docs`', '`--architecture-docs`', 'repeatable'
    ) |
      ForEach-Object { Require-Token $routerArguments $_ 'Codex AIToolkit router arguments' }
  }

  foreach ($path in @($orchestratorPath) + @($stepContracts | ForEach-Object { Join-Path $stepRoot "$($_.Name)/SKILL.md" })) {
    if (-not (Test-Path $path)) { continue }
    $text = Get-Content -Raw -Encoding utf8 $path
    foreach ($forbiddenToken in @('manifest.yaml', 'state.json', '.aitoolkit/run-', '--resume')) {
      if ($text -match [regex]::Escape($forbiddenToken)) {
        $relativePath = $path.Substring($root.Length).TrimStart('\').Replace('\', '/')
        $errors.Add("Onboarding file $relativePath contains prohibited persistence token: $forbiddenToken")
      }
    }
  }
}

function Test-Compatibility {
  $packRoot = Join-Path $root 'examples/project-packs/webos-qml-flutter'
  $packIndexPath = Join-Path $packRoot 'SKILL.md'
  $referenceRoot = Join-Path $packRoot 'references'
  $referenceNames = @(
    'legacy-system', 'target-baseline', 'architecture-rules', 'mapping-rules',
    'uiux-rules', 'testing-rules', 'definition-of-done'
  )
  $expectedReferencePaths = @($referenceNames | ForEach-Object { "references/$_.md" })
  $allowedPackFiles = @('SKILL.md') + $expectedReferencePaths

  if (-not (Test-Path $packIndexPath)) {
    $errors.Add('Missing compatibility pack index: examples/project-packs/webos-qml-flutter/SKILL.md')
  }
  else {
    $packIndexText = Get-Content -Raw -Encoding utf8 $packIndexPath
    $routingRows = @(Get-MarkdownTableRows $packIndexText 'Reference routing' 'Compatibility pack index')
    if ($routingRows.Count -ne $referenceNames.Count) {
      $errors.Add("Compatibility pack index Reference routing must contain exactly $($referenceNames.Count) rows; found $($routingRows.Count)")
    }
    $routedReferencePaths = [Collections.Generic.List[string]]::new()
    foreach ($routingRow in $routingRows) {
      $referenceCell = [string]$routingRow.Reference
      $referenceStyleMatches = [regex]::Matches($referenceCell, '\[[^\]\r\n]+\]\[[^\]\r\n]*\]')
      if ($referenceStyleMatches.Count -gt 0) {
        $errors.Add("Compatibility pack index Reference routing does not allow reference-style links: $referenceCell")
        continue
      }
      $inlineRouteMatches = [regex]::Matches($referenceCell, '\[[^\]\r\n]+\]\((?<path>[^)\r\n]+)\)')
      $autolinkRouteMatches = [regex]::Matches(
        $referenceCell,
        '<(?<path>(?:[A-Za-z][A-Za-z0-9+.-]{1,31}:[^<>\s]*|[^<>\s@]+@[^<>\s@]+))>'
      )
      $residualReferenceCell = [regex]::Replace($referenceCell, '!?\[[^\]\r\n]+\]\([^)\r\n]+\)', '')
      $residualReferenceCell = [regex]::Replace(
        $residualReferenceCell,
        '<(?:[A-Za-z][A-Za-z0-9+.-]{1,31}:[^<>\s]*|[^<>\s@]+@[^<>\s@]+)>',
        ''
      )
      if ($residualReferenceCell -match '(?<!\!)\[[^\]\r\n]+\]') {
        $errors.Add("Compatibility pack index Reference routing does not allow shortcut reference links: $referenceCell")
        continue
      }
      $routeTargets = @($inlineRouteMatches | ForEach-Object { $_.Groups['path'].Value.Trim() }) +
        @($autolinkRouteMatches | ForEach-Object { $_.Groups['path'].Value.Trim() })
      if ($routeTargets.Count -ne 1) {
        $errors.Add("Compatibility pack index Reference routing row must contain exactly one Markdown link target; found $($routeTargets.Count): $referenceCell")
        continue
      }
      $routedReferencePaths.Add($routeTargets[0])
    }
    if ($routedReferencePaths.Count -ne $expectedReferencePaths.Count) {
      $errors.Add("Compatibility pack index Reference routing must contain exactly $($expectedReferencePaths.Count) Markdown link targets; found $($routedReferencePaths.Count)")
    }
    foreach ($expectedReferencePath in $expectedReferencePaths) {
      $routeCount = @($routedReferencePaths | Where-Object { $_ -eq $expectedReferencePath }).Count
      if ($routeCount -ne 1) {
        $errors.Add("Compatibility pack index Reference routing must contain $expectedReferencePath exactly once; found $routeCount")
      }
    }
    $routedReferencePaths | Where-Object { $_ -notin $expectedReferencePaths } | ForEach-Object {
      $errors.Add("Compatibility pack index Reference routing contains unexpected path: $_")
    }
    $packBody = [regex]::Replace($packIndexText, '\A---\r?\n.*?\r?\n---\r?\n', '', 'Singleline')
    Test-MigrationTechnologyTokens $packBody 'Compatibility pack route-only index'
    $indexSections = @([regex]::Matches($packBody, '(?m)^##\s+(?<name>.+?)\s*$') | ForEach-Object { $_.Groups['name'].Value })
    foreach ($unexpectedSection in $indexSections | Where-Object { $_ -notin 'Reference routing', 'Common mistakes' }) {
      $errors.Add("Compatibility pack index contains non-routing section: $unexpectedSection")
    }
  }

  if (Test-Path $packRoot) {
    $actualPackFiles = @(
      Get-ChildItem -Path $packRoot -Recurse -File | ForEach-Object {
        $_.FullName.Substring($packRoot.Length).TrimStart('\').Replace('\', '/')
      }
    )
    foreach ($allowedPackFile in $allowedPackFiles) {
      if ($allowedPackFile -notin $actualPackFiles) {
        $errors.Add("Missing compatibility pack file: $allowedPackFile")
      }
    }
    $actualPackFiles | Where-Object { $_ -notin $allowedPackFiles } | ForEach-Object {
      $errors.Add("Unexpected compatibility pack file: $_")
    }
  }

  $actualReferenceNames = @()
  if (Test-Path $referenceRoot) {
    $actualReferenceNames = @(
      Get-ChildItem -Path $referenceRoot -File -Filter '*.md' |
        ForEach-Object { $_.BaseName }
    )
  }
  foreach ($referenceName in $referenceNames) {
    if ($referenceName -notin $actualReferenceNames) {
      $errors.Add("Missing compatibility reference: references/$referenceName.md")
    }
  }
  $actualReferenceNames | Where-Object { $_ -notin $referenceNames } | ForEach-Object {
    $errors.Add("Unexpected compatibility reference: references/$_.md")
  }

  $referenceContracts = @(
    [pscustomobject]@{
      Name = 'legacy-system'; Section = 'Legacy patterns'; Tokens = @(
        'webOS', 'QML', 'property binding', 'signal', 'Loader', 'model/delegate',
        'Luna Service', 'native bridge'
      )
    }
    [pscustomobject]@{
      Name = 'target-baseline'; Section = 'Target conventions'; Tokens = @(
        'Flutter', 'widget/component', 'reactive state', 'event/callback',
        'target list pattern', 'repository/platform bridge'
      )
    }
    [pscustomobject]@{
      Name = 'architecture-rules'; Section = 'Mandatory review rules'; Tokens = @(
        'mandatory-review', 'Clean Architecture', 'Riverpod', 'LGE conventions',
        'Presentation', 'Domain', 'Data'
      )
    }
    [pscustomobject]@{
      Name = 'mapping-rules'; Section = 'Required mappings'; Tokens = @(
        'QML view', 'Flutter widget/component', 'property binding', 'derived/reactive state',
        'signal', 'event/callback', 'model/delegate', 'target list pattern',
        'Luna/native service', 'repository/platform bridge'
      )
    }
    [pscustomobject]@{
      Name = 'uiux-rules'; Section = 'UIUX migration rules'; Tokens = @(
        'QML', 'Loader', 'focus', 'loading', 'empty', 'error'
      )
    }
    [pscustomobject]@{
      Name = 'testing-rules'; Section = 'Required commands'; Tokens = @(
        'flutter analyze', 'flutter test', 'LGE conventions'
      )
    }
    [pscustomobject]@{
      Name = 'definition-of-done'; Section = 'Mandatory release rules'; Tokens = @(
        'mandatory-release', 'review', 'test', 'Gerrit', 'CCC', 'evidence'
      )
    }
  )
  foreach ($contract in $referenceContracts) {
    $referencePath = Join-Path $referenceRoot "$($contract.Name).md"
    if (-not (Test-Path $referencePath)) { continue }
    $referenceText = Get-Content -Raw -Encoding utf8 $referencePath
    $sectionText = Get-MarkdownSectionBody $referenceText $contract.Section "Compatibility reference $($contract.Name)"
    foreach ($token in $contract.Tokens) {
      Require-Token $sectionText $token "Compatibility reference $($contract.Name) $($contract.Section)"
    }
  }
  $testingRulesPath = Join-Path $referenceRoot 'testing-rules.md'
  if (Test-Path $testingRulesPath) {
    $testingRulesText = Get-Content -Raw -Encoding utf8 $testingRulesPath
    $optionalEvidenceText = Get-MarkdownSectionBody $testingRulesText 'Optional evidence' 'Compatibility reference testing-rules'
    @('optional', 'degraded coverage') | ForEach-Object {
      Require-Token $optionalEvidenceText $_ 'Compatibility reference testing-rules Optional evidence'
    }
  }

  foreach ($corePath in @('skills/migration', 'templates/migration', 'skills/aitoolkit/migrate')) {
    $absoluteCorePath = Join-Path $root $corePath
    Get-ChildItem -Path $absoluteCorePath -Recurse -File | ForEach-Object {
      $relativePath = $_.FullName.Substring($root.Length).TrimStart('\').Replace('\', '/')
      Test-MigrationTechnologyTokens (Get-Content -Raw -Encoding utf8 $_.FullName) "Migration core $relativePath"
    }
  }

  $workflowAuthorityPhrase = 'caller-provided `workflow_type` is authoritative'
  foreach ($consumerName in @('ai-review', 'verification-testing', 'gerrit-automation', 'ccc-automation')) {
    $consumerPath = Join-Path $root "skills/shared/$consumerName/SKILL.md"
    if (-not (Test-Path $consumerPath)) {
      $errors.Add("Missing shared workflow consumer: $consumerName/SKILL.md")
      continue
    }
    $consumerText = Get-Content -Raw -Encoding utf8 $consumerPath
    Require-Token $consumerText $workflowAuthorityPhrase "Shared skill $consumerName workflow authority"
    @('persistent profile', '`migration` section') | ForEach-Object {
      Require-Token $consumerText $_ "Shared skill $consumerName workflow authority"
    }
  }

  $sharedContracts = @(
    [pscustomobject]@{
      Name = 'ai-review'; Tokens = @(
        'docs/aitoolkit/project.yaml', 'project_pack.path', 'references/architecture-rules.md',
        'references/testing-rules.md', 'mandatory-review', 'optional', 'degrade', 'BLOCKED',
        'workflow_type: migration', 'feature/bugfix'
      ); Dependencies = @('skills/shared/ai-review/severity-rubric.md', 'templates/review-report.md')
    }
    [pscustomobject]@{
      Name = 'gerrit-automation'; Tokens = @(
        'docs/aitoolkit/project.yaml', 'project_pack.path', 'references/definition-of-done.md',
        'references/architecture-rules.md', 'mandatory-release', 'optional', 'degrade', 'BLOCKED',
        'workflow_type: migration', 'feature/bugfix'
      ); Dependencies = @('templates/gerrit-report.md')
    }
    [pscustomobject]@{
      Name = 'ccc-automation'; Tokens = @(
        'docs/aitoolkit/project.yaml', 'project_pack.path', 'references/definition-of-done.md',
        'references/testing-rules.md', 'mandatory-release', 'optional', 'degrade', 'BLOCKED',
        'workflow_type: migration', 'feature/bugfix'
      ); Dependencies = @('templates/ccc-package.md')
    }
  )
  foreach ($contract in $sharedContracts) {
    $sharedPath = Join-Path $root "skills/shared/$($contract.Name)/SKILL.md"
    if (-not (Test-Path $sharedPath)) {
      $errors.Add("Missing shared compatibility consumer: $($contract.Name)/SKILL.md")
      continue
    }
    $sharedText = Get-Content -Raw -Encoding utf8 $sharedPath
    if ($sharedText -match '(?i)(?<![A-Za-z0-9-])lge-rules(?![A-Za-z0-9-])') {
      $errors.Add("Shared skill $($contract.Name) directly depends on deprecated lge-rules")
    }
    $resolutionText = Get-MarkdownSectionBody $sharedText 'Project rule resolution' "Shared skill $($contract.Name)"
    foreach ($token in $contract.Tokens) {
      Require-Token $resolutionText $token "Shared skill $($contract.Name) project rule resolution"
    }
    @(
      'For feature/bugfix without an explicit mandatory rule declaration',
      'degrade gracefully', 'do not require a migration profile or project pack',
      'For `workflow_type: migration`', 'reviewed project pack'
    ) | ForEach-Object {
      Require-Token $resolutionText $_ "Shared skill $($contract.Name) feature/bugfix compatibility"
    }
    if ($contract.Name -eq 'ai-review') {
      Require-Token $resolutionText 'universal review dimensions' 'Shared skill ai-review feature/bugfix compatibility'
    }
    elseif ($contract.Name -eq 'gerrit-automation') {
      Require-Token $resolutionText 'Conventional Commits' 'Shared skill gerrit-automation feature/bugfix compatibility'
    }
    elseif ($contract.Name -eq 'ccc-automation') {
      Require-Token $resolutionText 'default checklist' 'Shared skill ccc-automation feature/bugfix compatibility'
    }
    Require-TokenOrder $resolutionText 'docs/aitoolkit/project.yaml' 'project_pack.path' "Shared skill $($contract.Name) project rule resolution"
    if ($contract.Name -eq 'ai-review') {
      Require-Token $sharedText 'Blocking condition: `Rule Resolution: BLOCKED` or `Critical count > 0`.' 'Shared AI review independent rule-resolution gate'
      Require-Token $sharedText 'Reject when rule resolution is blocked or Critical remains.' 'Shared AI review verdict contract'
      Require-Token $sharedText 'Rule Resolution is evaluated before severity counts.' 'Shared AI review first gate contract'
    }
    foreach ($dependency in $contract.Dependencies) {
      $dependencyPath = Join-Path $root $dependency
      if (-not (Test-Path $dependencyPath)) {
        $errors.Add("Missing shared compatibility dependency: $dependency")
        continue
      }
      $dependencyText = Get-Content -Raw -Encoding utf8 $dependencyPath
      if ($dependencyText -match '(?i)(?<![A-Za-z0-9-])lge-rules(?![A-Za-z0-9-])') {
        $errors.Add("Shared dependency $dependency directly depends on deprecated lge-rules")
      }
    }
  }

  $gerritPath = Join-Path $root 'skills/shared/gerrit-automation/SKILL.md'
  if (Test-Path $gerritPath) {
    $gerritText = Get-Content -Raw -Encoding utf8 $gerritPath
    $standaloneMigration = Get-MarkdownSectionBody `
      $gerritText `
      'Standalone migration invocation' `
      'Shared skill gerrit-automation'
    @(
      'explicit completed `RUN_DIR`', 'terminal `kb-entry.md`', 'derive `RUN_DIR`',
      '`step_id: 15-knowledge-base`', 'inside that same run directory',
      'Terminal Verification Artifact', 'within the resolved `RUN_DIR`',
      'Greenfield / `design-new`', '`13-parity-report.md`', 'must not resolve or execute step 14',
      'Incremental / `preserve-existing`', '`14-regression-report.md`',
      'exactly one `Selected Migration Unit`', 'same `migration_unit_id`',
      'never requires an implicit migration-orchestrator handoff',
      '`Completion Verdict: complete`', '`status: approved`', '`result: complete`',
      '`Verification Verdict: PASS`', 'same-run approved parity evidence'
    ) | ForEach-Object {
      Require-Token $standaloneMigration $_ 'Shared Gerrit standalone migration invocation'
    }
    if ($gerritText -match '(?is)(?<!never )requires.{0,120}(?:(?:migration orchestrator|migration-orchestrator).{0,80}(?:handoff|predecessor)|(?:handoff|predecessor).{0,80}(?:migration orchestrator|migration-orchestrator))') {
      $errors.Add('Shared Gerrit must not require an implicit migration-orchestrator handoff')
    }
    $featureBugfixInvocation = Get-MarkdownSectionBody `
      $gerritText `
      'Feature and bugfix invocation' `
      'Shared Gerrit feature/bugfix invocation'
    @('`workflow_type`', '`<RUN_DIR>/verification-report.md`', 'do not require migration-only sections') | ForEach-Object {
      Require-Token $featureBugfixInvocation $_ 'Shared Gerrit feature/bugfix invocation'
    }
  }

  $reviewRubricPath = Join-Path $root 'skills/shared/ai-review/severity-rubric.md'
  if (Test-Path $reviewRubricPath) {
    $reviewRubricText = Get-Content -Raw -Encoding utf8 $reviewRubricPath
    $verdictGateText = Get-MarkdownSectionBody $reviewRubricText 'Verdict gate' 'Shared AI review severity rubric'
    @('Evaluate Rule Resolution first', 'severity counts') | ForEach-Object {
      Require-Token $verdictGateText $_ 'Shared AI review severity rubric Verdict gate'
    }
    Require-TokenOrder $verdictGateText 'Evaluate Rule Resolution first' 'severity counts' 'Shared AI review severity rubric gate order'
    $verdictRows = @(Get-MarkdownTableRows $reviewRubricText 'Verdict gate' 'Shared AI review severity rubric')
    $blockedZeroRow = @($verdictRows | Where-Object {
      $_.'Rule Resolution' -eq 'BLOCKED' -and $_.'Critical count' -eq '0' -and $_.'Major count' -eq '0'
    })
    if ($blockedZeroRow.Count -ne 1 -or $blockedZeroRow[0].Verdict -ne 'Reject') {
      $errors.Add('Shared AI review verdict gate must Reject BLOCKED Rule Resolution with 0 Critical and 0 Major')
    }
  }

  $reviewTemplatePath = Join-Path $root 'templates/review-report.md'
  if (Test-Path $reviewTemplatePath) {
    $reviewTemplateText = Get-Content -Raw -Encoding utf8 $reviewTemplatePath
    $ruleResolutionTemplate = Get-MarkdownSectionBody $reviewTemplateText 'Rule Resolution' 'Shared review report template'
    @('RESOLVED | BLOCKED', 'Mandatory rule gaps', 'Optional gaps/degraded coverage') | ForEach-Object {
      Require-Token $ruleResolutionTemplate $_ 'Shared review report template Rule Resolution'
    }
    Require-TokenOrder $reviewTemplateText '## Rule Resolution' '## Critical' 'Shared review report first gate field order'
  }

  $legacyShimPath = Join-Path $root 'skills/lge-rules/SKILL.md'
  if (-not (Test-Path $legacyShimPath)) {
    $errors.Add('Missing deprecated lge-rules compatibility shim')
  }
  else {
    $legacyShimText = Get-Content -Raw -Encoding utf8 $legacyShimPath
    @('deprecated', 'one release cycle', 'project_pack.path', 'compatibility shim') | ForEach-Object {
      Require-Token $legacyShimText $_ 'Deprecated lge-rules compatibility shim'
    }
  }
}

function Test-MigrationUserWorkflow(
  [string]$Text,
  [string]$SectionName,
  [string]$Context,
  [string]$OnboardingCommand,
  [string]$MigrateCommand
) {
  $sectionText = Get-MarkdownSectionBody $Text $SectionName $Context
  if ($sectionText -eq '') { return }

  $matches = @([regex]::Matches($sectionText, '(?m)^\s*(?<number>\d+)\.\s+(?<text>.+?)\s*$'))
  if ($matches.Count -ne 7) {
    $errors.Add("$Context $SectionName must contain exactly seven numbered steps; found $($matches.Count)")
    return
  }

  $stepContracts = @(
    [pscustomobject]@{ Number = '1'; Tokens = @('Prepare', 'sources', 'documents') }
    [pscustomobject]@{
      Number = '2'
      Tokens = @(
        $OnboardingCommand, '--legacy', '--target', '--requirements', '--uiux',
        '--migration-docs', '--architecture-docs', 'optional inbox'
      )
    }
    [pscustomobject]@{
      Number = '3'
      Tokens = @(
        'Review', 'generated', '<RUN_DIR>/project-draft/project.yaml',
        '<RUN_DIR>/project-draft/migration-project', '<RUN_DIR>/04-project-pack-review.md'
      )
    }
    [pscustomobject]@{
      Number = '4'
      Tokens = @(
        'Tech Lead', 'approval', 'publishes', 'exact staged bytes',
        'docs/aitoolkit/project.yaml', 'docs/aitoolkit/migration-project'
      )
    }
    [pscustomobject]@{ Number = '5'; Tokens = @($MigrateCommand) }
    [pscustomobject]@{ Number = '6'; Tokens = @('Migration ends at Knowledge Capture') }
    [pscustomobject]@{ Number = '7'; Tokens = @('Gerrit', 'CCC', 'Release', 'separate', 'explicit calls') }
  )
  for ($index = 0; $index -lt $stepContracts.Count; $index++) {
    $contract = $stepContracts[$index]
    $match = $matches[$index]
    if ($match.Groups['number'].Value -ne $contract.Number) {
      $errors.Add("$Context $SectionName step $($index + 1) must use list number $($contract.Number)")
    }
    foreach ($token in $contract.Tokens) {
      Require-Token $match.Groups['text'].Value $token "$Context $SectionName step $($contract.Number)"
    }
  }
}

function Test-MigrationDocumentationBoundaries([string]$Text, [string]$Context) {
  if ($Text -match '(?i)(?:/aitoolkit:|\$aitoolkit\s+)migration-onboarding\s+<legacy-path>') {
    $errors.Add("$Context must not document positional migration-onboarding paths")
  }

  foreach ($line in $Text -split '\r?\n') {
    if ($line -notmatch '(?i)\b18(?:-|\s+)step(?:s)?\b|\b18\s+bước\b') { continue }
    $historicalRemoval = $line -match '(?i)(?:\b(?:old|legacy|former)\b.{0,30}\b18(?:-|\s+)step(?:s)?\b.{0,50}\b(?:removed|retired|replaced|reduced|no longer used)\b|\b(?:removed|retired|replaced|reduced)\b.{0,50}\b(?:old|legacy|former)\b.{0,30}\b18(?:-|\s+)step(?:s)?\b)'
    if (-not $historicalRemoval) {
      $errors.Add("$Context must not claim an 18-step migration pipeline")
      break
    }
  }

  $migrationDeliveryPatterns = @(
    '(?i)\bmigration\s+(?:Gerrit|CCC|Release)\b'
    '(?i)\bmigration\s+(?:(?:automatically|implicitly)\s+)?(?:runs?|invokes?|includes?|routes?|hands?\s+off\s+to|consumes?)\b.{0,60}\b(?:Gerrit|CCC|Release)\b'
    '(?i)\bmigration\s+(?:pipeline|workflow)\s+(?:(?:automatically|implicitly)\s+)?(?:runs?|invokes?|includes?|routes?)\b.{0,60}\b(?:Gerrit|CCC|Release)\b'
    '(?i)\b(?:Gerrit|CCC|Release)\b\s+(?:is|are)\s+(?:an?\s+)?migration\s+(?:step|stage|route|handoff)\b'
  )
  foreach ($pattern in $migrationDeliveryPatterns) {
    if ($Text -match $pattern) {
      $errors.Add("$Context must not claim migration runs Gerrit, CCC, or Release")
      break
    }
  }

  $userAuthoredPackPatterns = @(
    '(?i)\busers?\s+(?:must|should|need(?:s)?\s+to|(?:is|are)\s+required\s+to)\s+(?:author|write|create|prepare|maintain)\b.{0,40}\bproject\s+pack\b'
    '(?i)\bproject\s+pack\b.{0,30}\b(?:must|should)\s+be\s+(?:user-authored|written|created|prepared|maintained)\b'
  )
  foreach ($pattern in $userAuthoredPackPatterns) {
    if ($Text -match $pattern) {
      $errors.Add("$Context must not require a user-authored project pack")
      break
    }
  }
}

function Get-YamlTopLevelSectionBody(
  [string]$Text,
  [string]$SectionName,
  [string]$Context
) {
  $pattern = "(?ms)^$([regex]::Escape($SectionName)):\s*\r?\n(?<body>.*?)(?=^[A-Za-z_][A-Za-z0-9_-]*:\s*(?:\S.*)?$|\z)"
  $match = [regex]::Match($Text, $pattern)
  if (-not $match.Success) {
    $errors.Add("$Context missing top-level YAML section: $SectionName")
    return ''
  }
  return $match.Groups['body'].Value
}

function Test-YamlSectionScalar(
  [string]$SectionText,
  [string]$SectionName,
  [string]$Field,
  [string]$ExpectedValue,
  [string]$Context
) {
  $matches = [regex]::Matches(
    $SectionText,
    "(?m)^  $([regex]::Escape($Field)):\s*(?<value>\S.*?)\s*$"
  )
  if ($matches.Count -ne 1 -or $matches[0].Groups['value'].Value -ne $ExpectedValue) {
    $errors.Add("$Context $SectionName section must declare exactly one ${Field}: $ExpectedValue")
  }
}

function Get-YamlIndentedSectionBody(
  [string]$Text,
  [string]$SectionName,
  [int]$Indent,
  [string]$Context
) {
  $prefix = ' ' * $Indent
  $pattern = "(?ms)^$prefix$([regex]::Escape($SectionName)):\s*\r?\n(?<body>.*?)(?=^$prefix[A-Za-z_][A-Za-z0-9_-]*:\s*(?:\S.*)?$|\z)"
  $match = [regex]::Match($Text, $pattern)
  if (-not $match.Success) {
    $errors.Add("$Context missing YAML section: $SectionName")
    return ''
  }
  return $match.Groups['body'].Value
}

function Test-YamlIndentedScalar(
  [string]$SectionText,
  [string]$Field,
  [string]$ExpectedValue,
  [int]$Indent,
  [string]$Context
) {
  $prefix = ' ' * $Indent
  $matches = [regex]::Matches(
    $SectionText,
    "(?m)^$prefix$([regex]::Escape($Field)):\s*(?<value>\S.*?)\s*$"
  )
  if ($matches.Count -ne 1 -or $matches[0].Groups['value'].Value -ne $ExpectedValue) {
    $errors.Add("$Context must declare exactly one ${Field}: $ExpectedValue")
  }
}

function Test-MigrationExampleFixture(
  [string]$RelativePath,
  [string]$Mode,
  [string]$ArchitecturePolicy,
  [string]$RegressionPolicy
) {
  $fixturePath = Join-Path $root $RelativePath
  if (-not (Test-Path $fixturePath)) {
    $errors.Add("Missing migration example fixture: $RelativePath")
    return
  }

  $fixtureText = Get-Content -Raw -Encoding utf8 $fixturePath
  [void](Resolve-MigrationProfileSettings $fixtureText "Migration example fixture $RelativePath" $true)
  @(
    'test_cmd: null'
    'lint_cmd: null'
    'build_cmd: null'
  ) | ForEach-Object {
    Require-Token $fixtureText $_ "Migration example fixture $RelativePath"
  }

  foreach ($rootContract in @(
    [pscustomobject]@{ Field = 'schema_version'; Value = '1' }
  )) {
    $rootMatches = [regex]::Matches(
      $fixtureText,
      "(?m)^$([regex]::Escape($rootContract.Field)):\s*(?<value>\S.*?)\s*$"
    )
    if ($rootMatches.Count -ne 1 -or $rootMatches[0].Groups['value'].Value -ne $rootContract.Value) {
      $errors.Add("Migration example fixture $RelativePath must declare exactly one top-level $($rootContract.Field): $($rootContract.Value)")
    }
  }
  if ($fixtureText -match '(?m)^change_type\s*:') {
    $errors.Add("Migration example fixture $RelativePath must not persist top-level change_type")
  }

  $context = "Migration example fixture $RelativePath"
  $migrationSection = Get-YamlTopLevelSectionBody $fixtureText 'migration' $context
  Test-YamlSectionScalar $migrationSection 'migration' 'mode' $Mode $context
  Test-YamlSectionScalar $migrationSection 'migration' 'unit' 'feature' $context
  Test-YamlSectionScalar $migrationSection 'migration' 'architecture_policy' $ArchitecturePolicy $context
  $documentsSection = Get-YamlTopLevelSectionBody $fixtureText 'documents' $context
  foreach ($documentCategory in @('requirements', 'uiux', 'migration', 'architecture')) {
    $documentMatches = [regex]::Matches(
      $documentsSection,
      "(?m)^  $([regex]::Escape($documentCategory)):\s*\[\]\s*$"
    )
    if ($documentMatches.Count -ne 1) {
      $errors.Add("$context documents section must declare exactly one ${documentCategory}: []")
    }
  }

  if ($Mode -eq 'greenfield') {
    $fixtureScenarios = Get-YamlTopLevelSectionBody $fixtureText 'fixture_scenarios' $context
    Test-YamlSectionScalar $fixtureScenarios 'fixture_scenarios' 'foundation_plan' 'docs/aitoolkit/fixture-artifacts/08-foundation-migration-plan.md' $context
    Test-YamlSectionScalar $fixtureScenarios 'fixture_scenarios' 'later_plan' 'docs/aitoolkit/fixture-artifacts/08-later-migration-plan.md' $context
    Test-YamlSectionScalar $fixtureScenarios 'fixture_scenarios' 'foundation_approval' 'docs/aitoolkit/fixture-artifacts/09-bootstrap-report.md' $context
    Test-YamlSectionScalar $fixtureScenarios 'fixture_scenarios' 'approved_target_baseline' 'docs/aitoolkit/migration-project/references/target-baseline.md' $context

    $fixtureProjectRoot = [IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $fixturePath) '../..'))
    $foundationPlanPath = Join-Path $fixtureProjectRoot 'docs/aitoolkit/fixture-artifacts/08-foundation-migration-plan.md'
    $laterPlanPath = Join-Path $fixtureProjectRoot 'docs/aitoolkit/fixture-artifacts/08-later-migration-plan.md'
    $packIndexPath = Join-Path $fixtureProjectRoot 'docs/aitoolkit/migration-project/SKILL.md'
    $targetBaselinePath = Join-Path $fixtureProjectRoot 'docs/aitoolkit/migration-project/references/target-baseline.md'
    $bootstrapApprovalPath = Join-Path $fixtureProjectRoot 'docs/aitoolkit/fixture-artifacts/09-bootstrap-report.md'
    foreach ($requiredFixturePath in @($foundationPlanPath, $laterPlanPath, $packIndexPath, $targetBaselinePath, $bootstrapApprovalPath)) {
      if (-not (Test-Path $requiredFixturePath)) {
        $errors.Add("$context approved foundation reference missing fixture file: $requiredFixturePath")
      }
    }
    $planColumns = @(
      'Order', 'Migration Unit ID', 'Bootstrap Scope', 'Foundation Baseline ID',
      'Foundation Approval Reference', 'Dependencies', 'Acceptance', 'Mode Constraint',
      'Trace IDs', 'Delivery Change Boundary', 'Approval Reference', 'Approval Status'
    )
    $orderedUnitsSection = ConvertFrom-Utf8Base64 'Q8OhYyDEkcahbiB24buLIG1pZ3JhdGlvbiB0aGVvIHRo4bupIHThu7E='
    $foundationRecordSection = ConvertFrom-Utf8Base64 'QuG6o24gZ2hpIGJhc2VsaW5lIG7hu4FuIHThuqNuZw=='
    $baselineColumns = @('Foundation Baseline ID', 'Target Baseline Reference', 'Approval Reference', 'Approval Status', 'Evidence')
    if (Test-Path $foundationPlanPath) {
      $foundationPlanText = Get-Content -Raw -Encoding utf8 $foundationPlanPath
      $foundationPlanContext = "$context foundation migration plan"
      Test-ApprovedFixtureArtifactFrontMatter $foundationPlanText '08-plan-waves' $foundationPlanContext
      Test-MarkdownTableExactColumns $foundationPlanText $orderedUnitsSection $planColumns $foundationPlanContext
      Test-MarkdownTableExactColumns $foundationPlanText 'Approved Foundation Baselines' $baselineColumns $foundationPlanContext
      @('Evidence', 'Unknowns', 'Verdict') | ForEach-Object {
        [void](Get-MarkdownSectionBody $foundationPlanText $_ $foundationPlanContext)
      }
      $foundationRows = @(Get-MarkdownTableRows $foundationPlanText $orderedUnitsSection $foundationPlanContext)
      if ($foundationRows.Count -ne 1) {
        $errors.Add("$foundationPlanContext must contain exactly one ordered migration unit")
      }
      else {
        $foundationExpected = [ordered]@{
          'Migration Unit ID' = 'UNIT-001'; 'Bootstrap Scope' = 'required';
          'Foundation Baseline ID' = 'pending-bootstrap'; 'Foundation Approval Reference' = 'pending-step09-approval';
          'Mode Constraint' = 'greenfield/design-new'; 'Approval Status' = 'approved'
        }
        foreach ($field in $foundationExpected.Keys) {
          if ($foundationRows[0].$field -cne $foundationExpected[$field]) {
            $errors.Add("$foundationPlanContext $field must be $($foundationExpected[$field])")
          }
        }
      }
      $foundationBaselines = @(Get-MarkdownTableRows $foundationPlanText 'Approved Foundation Baselines' $foundationPlanContext)
      if ($foundationBaselines.Count -ne 0) {
        $errors.Add("$foundationPlanContext must not preclaim an approved foundation baseline")
      }
    }
    if (Test-Path $laterPlanPath) {
      $laterPlanText = Get-Content -Raw -Encoding utf8 $laterPlanPath
      $laterPlanContext = "$context later migration plan"
      Test-ApprovedFixtureArtifactFrontMatter $laterPlanText '08-plan-waves' $laterPlanContext
      Test-MarkdownTableExactColumns $laterPlanText $orderedUnitsSection $planColumns $laterPlanContext
      Test-MarkdownTableExactColumns $laterPlanText 'Approved Foundation Baselines' $baselineColumns $laterPlanContext
      @('Evidence', 'Unknowns', 'Verdict') | ForEach-Object {
        [void](Get-MarkdownSectionBody $laterPlanText $_ $laterPlanContext)
      }
      $laterRows = @(Get-MarkdownTableRows $laterPlanText $orderedUnitsSection $laterPlanContext)
      $laterBaselines = @(Get-MarkdownTableRows $laterPlanText 'Approved Foundation Baselines' $laterPlanContext)
      if ($laterRows.Count -ne 1) { $errors.Add("$laterPlanContext must contain exactly one ordered migration unit") }
      if ($laterBaselines.Count -ne 1) { $errors.Add("$laterPlanContext must contain exactly one approved foundation baseline") }
      if ($laterRows.Count -eq 1) {
        $laterExpected = [ordered]@{
          'Migration Unit ID' = 'UNIT-002'; 'Bootstrap Scope' = 'not-required';
          'Foundation Baseline ID' = 'FOUNDATION-EXAMPLE-001';
          'Foundation Approval Reference' = 'docs/aitoolkit/fixture-artifacts/09-bootstrap-report.md#FOUNDATION-EXAMPLE-001';
          'Mode Constraint' = 'greenfield/design-new'; 'Approval Status' = 'approved'
        }
        foreach ($field in $laterExpected.Keys) {
          if ($laterRows[0].$field -cne $laterExpected[$field]) { $errors.Add("$laterPlanContext $field must be $($laterExpected[$field])") }
        }
      }
      if ($laterBaselines.Count -eq 1) {
        $laterBaselineExpected = [ordered]@{
          'Foundation Baseline ID' = 'FOUNDATION-EXAMPLE-001';
          'Target Baseline Reference' = 'docs/aitoolkit/migration-project/references/target-baseline.md#FOUNDATION-EXAMPLE-001';
          'Approval Reference' = 'docs/aitoolkit/fixture-artifacts/09-bootstrap-report.md#FOUNDATION-EXAMPLE-001';
          'Approval Status' = 'approved'
        }
        foreach ($field in $laterBaselineExpected.Keys) {
          if ($laterBaselines[0].$field -cne $laterBaselineExpected[$field]) { $errors.Add("$laterPlanContext approved baseline $field must be $($laterBaselineExpected[$field])") }
        }
        @('DESIGN-EXAMPLE-001', 'Freshness Evidence current') | ForEach-Object {
          Require-Token $laterBaselines[0].Evidence $_ "$laterPlanContext approved baseline evidence"
        }
      }
    }
    if (Test-Path $packIndexPath) {
      $packIndexText = Get-Content -Raw -Encoding utf8 $packIndexPath
      $packContext = "$context project pack route"
      $packFrontMatterPattern = '\A---\r?\nname: greenfield-migration-project-fixture\r?\ndescription: \S.*?\r?\n---(?:\r?\n|\z)'
      if ($packIndexText -notmatch $packFrontMatterPattern) {
        $errors.Add("$packContext must declare canonical skill front matter")
      }
      Test-MarkdownTableExactColumns $packIndexText 'Reference routing' @('Consumer need', 'Reference') $packContext
      [void](Get-MarkdownSectionBody $packIndexText 'Common mistakes' $packContext)
      $packRoutes = @(Get-MarkdownTableRows $packIndexText 'Reference routing' $packContext)
      $expectedPackReferences = @(
        'legacy-system.md', 'target-baseline.md', 'architecture-rules.md', 'mapping-rules.md',
        'uiux-rules.md', 'testing-rules.md', 'definition-of-done.md'
      )
      if ($packRoutes.Count -ne $expectedPackReferences.Count) {
        $errors.Add("$packContext must contain exactly $($expectedPackReferences.Count) routes")
      }
      foreach ($referenceName in $expectedPackReferences) {
        $referenceTarget = "references/$referenceName"
        $routeCount = @($packRoutes | Where-Object { $_.Reference -match "\($([regex]::Escape($referenceTarget))\)" }).Count
        if ($routeCount -ne 1) { $errors.Add("$packContext must route $referenceTarget exactly once") }
        $referencePath = Join-Path (Split-Path -Parent $packIndexPath) $referenceTarget
        if (-not (Test-Path $referencePath)) { $errors.Add("$packContext missing routed file: $referencePath") }
      }
    }
    if (Test-Path $targetBaselinePath) {
      $targetBaselineText = Get-Content -Raw -Encoding utf8 $targetBaselinePath
      @(
        'FOUNDATION-EXAMPLE-001', 'UNIT-001', 'target', 'DESIGN-EXAMPLE-001',
        'docs/aitoolkit/fixture-artifacts/09-bootstrap-report.md#FOUNDATION-EXAMPLE-001',
        'Approval Status', '| approved |', 'Freshness Evidence', 'current'
      ) | ForEach-Object { Require-Token $targetBaselineText $_ "$context approved target baseline" }
    }
    if (Test-Path $bootstrapApprovalPath) {
      $bootstrapApprovalText = Get-Content -Raw -Encoding utf8 $bootstrapApprovalPath
      $bootstrapContext = "$context approved bootstrap artifact"
      Test-ApprovedFixtureArtifactFrontMatter $bootstrapApprovalText '09-bootstrap-target' $bootstrapContext
      $selectedColumns = @(
        'Migration Unit ID', 'Plan Reference', 'Approval Reference', 'Mode Constraint', 'Bootstrap Scope',
        'Foundation Baseline ID', 'Foundation Baseline Reference', 'Foundation Baseline Approval Reference',
        'Baseline Reference', 'Trace IDs'
      )
      $recordColumns = @(
        'Foundation Baseline ID', 'Source Migration Unit ID', 'Target Baseline Reference',
        'Approval Reference', 'Approval Status', 'Evidence'
      )
      Test-MarkdownTableExactColumns $bootstrapApprovalText 'Selected Migration Unit' $selectedColumns $bootstrapContext
      Test-MarkdownTableExactColumns $bootstrapApprovalText $foundationRecordSection $recordColumns $bootstrapContext
      Test-MarkdownTableExactColumns $bootstrapApprovalText 'Bootstrap Results' @('Item', 'Command', 'Result', 'Notes') $bootstrapContext
      @('Evidence', 'Unknowns', 'Verdict') | ForEach-Object {
        [void](Get-MarkdownSectionBody $bootstrapApprovalText $_ $bootstrapContext)
      }
      $selectedRows = @(Get-MarkdownTableRows $bootstrapApprovalText 'Selected Migration Unit' $bootstrapContext)
      $recordRows = @(Get-MarkdownTableRows $bootstrapApprovalText $foundationRecordSection $bootstrapContext)
      if ($selectedRows.Count -ne 1) { $errors.Add("$bootstrapContext must contain exactly one selected migration unit") }
      if ($recordRows.Count -ne 1) { $errors.Add("$bootstrapContext must contain exactly one foundation baseline record") }
      if ($selectedRows.Count -eq 1) {
        @('UNIT-001', 'required', 'FOUNDATION-EXAMPLE-001', 'greenfield/design-new') | ForEach-Object {
          Require-Token ($selectedRows[0].PSObject.Properties.Value -join ' | ') $_ "$bootstrapContext selected unit"
        }
      }
      if ($recordRows.Count -eq 1) {
        $recordExpected = [ordered]@{
          'Foundation Baseline ID' = 'FOUNDATION-EXAMPLE-001'; 'Source Migration Unit ID' = 'UNIT-001';
          'Target Baseline Reference' = 'docs/aitoolkit/migration-project/references/target-baseline.md#FOUNDATION-EXAMPLE-001';
          'Approval Reference' = 'docs/aitoolkit/fixture-artifacts/09-bootstrap-report.md#FOUNDATION-EXAMPLE-001';
          'Approval Status' = 'approved'
        }
        foreach ($field in $recordExpected.Keys) {
          if ($recordRows[0].$field -cne $recordExpected[$field]) { $errors.Add("$bootstrapContext $field must be $($recordExpected[$field])") }
        }
        @('DESIGN-EXAMPLE-001', 'freshness current', 'changed paths', 'command evidence') | ForEach-Object {
          Require-Token $recordRows[0].Evidence $_ "$bootstrapContext foundation evidence"
        }
      }
    }
    if ((Test-Path $foundationPlanPath) -and (Test-Path $bootstrapApprovalPath)) {
      Test-ApprovedFixtureArtifactRoute `
        $bootstrapApprovalPath `
        $foundationPlanPath `
        "$context approved foundation fixture route"
    }
  }
  else {
    $exampleUnits = Get-YamlIndentedSectionBody $migrationSection 'example_units' 2 "$context migration section"
    $incrementalUnit = Get-YamlIndentedSectionBody $exampleUnits 'incremental' 4 "$context example units"
    Test-YamlIndentedScalar $incrementalUnit 'migration_unit_id' 'UNIT-001' 6 "$context incremental unit"
    Test-YamlIndentedScalar $incrementalUnit 'bootstrap_scope' 'not-required' 6 "$context incremental unit"
    Test-YamlIndentedScalar $incrementalUnit 'foundation_baseline_id' 'not-applicable' 6 "$context incremental unit"
  }

  $verificationSection = Get-YamlTopLevelSectionBody $fixtureText 'verification' $context
  Test-YamlSectionScalar $verificationSection 'verification' 'behavior_parity' 'required' $context
  Test-YamlSectionScalar $verificationSection 'verification' 'regression' $RegressionPolicy $context
  Test-YamlSectionScalar $verificationSection 'verification' 'visual_fidelity' 'optional' $context

  $projectPackSection = Get-YamlTopLevelSectionBody $fixtureText 'project_pack' $context
  Test-YamlSectionScalar $projectPackSection 'project_pack' 'path' 'docs/aitoolkit/migration-project' $context

  foreach ($pathSectionName in @('legacy', 'target')) {
    $pathSection = Get-YamlTopLevelSectionBody $fixtureText $pathSectionName $context
    $pathMatches = [regex]::Matches($pathSection, '(?m)^  path:\s*(?<value>\S.*?)\s*$')
    if ($pathMatches.Count -ne 1 -or $pathMatches[0].Groups['value'].Value -in @('', 'null', 'unknown')) {
      $errors.Add("$context $pathSectionName section must declare exactly one concrete path")
    }
  }
}

function New-RequiredCapabilityClause(
  [string]$Name,
  [string]$PositivePattern,
  [string]$CapabilityPattern,
  [string]$ActionPattern,
  [string]$StatePattern,
  [switch]$AllowDirectAbsence
) {
  $capability = "(?:\b(?:$CapabilityPattern)\b)"
  $action = "(?:\b(?:$ActionPattern)\b)"
  $state = "(?:\b(?:$StatePattern)\b)"
  $article = "(?:(?:a|an|the|any)\s+)?"
  $activeNegation = "(?:does\s+not|doesn['’]t|cannot|fails?\s+to)"
  $denyPatterns = [Collections.Generic.List[string]]::new()
  if (-not $AllowDirectAbsence) {
    $denyPatterns.Add("(?:\b(?:no|not|without)\b\s+$article$capability|\blacks?\b\s+$article$capability)")
  }
  $negatedAction = "(?:(?:$activeNegation|\b(?:no|not|without|lacks?)\b)\s+$action\s+$article$capability)"
  $trailingAction = "(?:$capability.{0,30}$activeNegation\s+$action)"
  $trailingState = "(?:$capability.{0,15}(?:(?:is|are|was|were)\s+not|\bnot\b)\s+$state)"
  $trailingDirectNegation = "(?:$capability.{0,15}(?:is|are|was|were|has|have|with)\s+(?:no|not|without)\b\s+$article(?:$action|$state))"
  $trailingLack = "(?:$capability.{0,15}(?:lacks?|is\s+lacking)\b\s+$article(?:$action|$state))"
  @($negatedAction, $trailingAction, $trailingState, $trailingDirectNegation, $trailingLack) |
    ForEach-Object { $denyPatterns.Add($_) }

  [pscustomobject]@{
    Name = $Name
    PositivePattern = $PositivePattern
    DenyPattern = "(?i)(?:$($denyPatterns -join '|'))"
  }
}

function Test-Docs {
  $readmePath = Join-Path $root 'README.md'
  $contributingPath = Join-Path $root 'CONTRIBUTING.md'
  $migrationGuidePath = Join-Path $root 'docs/MIGRATION-FRAMEWORK.md'
  $codexGuidePath = Join-Path $root 'docs/RUN-ON-CODEX.md'

  foreach ($requiredDoc in @($readmePath, $contributingPath, $migrationGuidePath, $codexGuidePath)) {
    if (-not (Test-Path $requiredDoc)) {
      $errors.Add("Missing migration documentation: $requiredDoc")
    }
  }

  $languageAndAutomationDocTokens = @(
    '`output.artifact_language: vi`',
    (ConvertFrom-Utf8Base64 'beG6t2MgxJHhu4tuaCB0aeG6v25nIFZp4buHdA=='),
    '`--auto`',
    '`--auto-waive`',
    'CLI',
    '`NOT_RUN + WAIVED`',
    (ConvertFrom-Utf8Base64 'a2jDtG5nIHBo4bqjaSBgUEFTU2A=')
  )

  if (Test-Path $readmePath) {
    $readmeText = Get-Content -Raw -Encoding utf8 $readmePath
    $languageAndAutomationDocTokens | ForEach-Object { Require-Token $readmeText $_ 'README migration automation/language guidance' }
    Test-MigrationUserWorkflow `
      $readmeText `
      'Migration user workflow' `
      'README' `
      '/aitoolkit:migration-onboarding' `
      '/aitoolkit:migrate <feature-slug>'
    Test-MigrationDocumentationBoundaries $readmeText 'README'
    @('greenfield', 'incremental') | ForEach-Object {
      Require-Token $readmeText $_ 'README migration modes'
    }
  }

  if (Test-Path $migrationGuidePath) {
    $migrationGuideText = Get-Content -Raw -Encoding utf8 $migrationGuidePath
    $languageAndAutomationDocTokens | ForEach-Object { Require-Token $migrationGuideText $_ 'Migration framework automation/language guidance' }
    Test-MigrationUserWorkflow `
      $migrationGuideText `
      'Migration user workflow' `
      'Migration framework guide' `
      '/aitoolkit:migration-onboarding' `
      '/aitoolkit:migrate <feature-slug>'
    Test-MigrationDocumentationBoundaries $migrationGuideText 'Migration framework guide'

    $greenfieldWalkthrough = Get-MarkdownSectionBody $migrationGuideText 'Greenfield walkthrough' 'Migration framework guide'
    @('greenfield', 'design-new', 'Tech Lead design gate', 'bootstrap', 'implementation') |
      ForEach-Object { Require-Token $greenfieldWalkthrough $_ 'Migration framework guide Greenfield walkthrough' }
    Require-TokenOrder $greenfieldWalkthrough 'Tech Lead design gate' 'bootstrap' 'Migration framework greenfield gate order'
    Require-TokenOrder $greenfieldWalkthrough 'bootstrap' 'implementation' 'Migration framework greenfield execution order'

    $incrementalWalkthrough = Get-MarkdownSectionBody $migrationGuideText 'Incremental walkthrough' 'Migration framework guide'
    @('incremental', 'preserve-existing', 'baseline', 'target conformance', 'no bootstrap', 'regression verification') |
      ForEach-Object { Require-Token $incrementalWalkthrough $_ 'Migration framework guide Incremental walkthrough' }
    Require-TokenOrder $incrementalWalkthrough 'baseline' 'implementation' 'Migration framework incremental baseline order'

    $manualRows = @(Get-MarkdownTableRows $migrationGuideText 'Manual runtime evidence' 'Migration framework guide')
    foreach ($scenario in @('onboarding', 'greenfield', 'incremental')) {
      $scenarioRows = @($manualRows | Where-Object { $_.Scenario -eq $scenario })
      if ($scenarioRows.Count -ne 1) {
        $errors.Add("Migration framework manual evidence must contain exactly one $scenario scenario")
        continue
      }
      $row = $scenarioRows[0]
      if ($row.Status -notin @('PASS', 'BLOCKED')) {
        $errors.Add("Migration framework manual evidence $scenario status must be PASS or BLOCKED")
      }
      foreach ($field in @('Date', 'Runtime', 'Observed gate / artifact', 'Evidence or blocker')) {
        $value = [string]$row.$field
        if ([string]::IsNullOrWhiteSpace($value) -or $value -match '^(TBD|TODO|-)$') {
          $errors.Add("Migration framework manual evidence $scenario missing field: $field")
        }
      }
      $runtime = [string]$row.Runtime
      $observed = [string]$row.'Observed gate / artifact'
      $evidence = [string]$row.'Evidence or blocker'
      $negativeEvidencePattern = '(?i)unavailable|not available|not run|not observed|no artifact|could not|blocked|unknown|reject(?:ed|ion)?|fail(?:ed|ure)?|den(?:y|ied|ial)|not approved|errors?|not\s+valid|invalid|corrupt(?:ed|ion)?|unreadable'
      if ($row.Status -eq 'PASS') {
        $manualEvidenceText = $observed + ' ' + $evidence
        $hasObservedGate = $manualEvidenceText -match '(?i)(?:\bapproved\b.{0,60}\bgate\b|\bgate\b.{0,60}\bapproved\b|\bpaused\b.{0,60}\bexpected\b.{0,60}\bgate\b|\bexpected\b.{0,60}\bgate\b.{0,60}\bpaused\b)'
        $hasArtifactPath = $manualEvidenceText -match '(?i)(?:\b(?:produced|readable)\b.{0,120}docs/aitoolkit/[^\s;]+\.md|docs/aitoolkit/[^\s;]+\.md.{0,120}\b(?:produced|readable)\b)'
        $containsNegativeEvidence = ($runtime + ' ' + $observed + ' ' + $evidence) -match $negativeEvidencePattern
        if (-not $hasObservedGate -or -not $hasArtifactPath -or $containsNegativeEvidence) {
          $errors.Add("Migration framework manual evidence $scenario PASS requires an approved or expected paused gate and a produced readable artifact")
        }
      }
      elseif ($row.Status -eq 'BLOCKED') {
        $hasConcreteReason = $evidence.Length -ge 30 -and $evidence -match '(?i)unavailable|not available|could not|missing|blocked'
        if (-not $hasConcreteReason) {
          $errors.Add("Migration framework manual evidence $scenario BLOCKED requires a concrete blocker")
        }
      }
    }

    $acceptanceRows = @(Get-MarkdownTableRows $migrationGuideText 'Acceptance matrix' 'Migration framework guide')
    # Follow-up criteria for the streamlined migration boundary.
    $acceptanceContracts = @(
      [pscustomobject]@{
        Number = 1
        Tokens = @('exactly 15 steps', 'Knowledge Capture')
        PositivePattern = '(?i)\bMigration\b.*\bexactly 15 steps\b.*\bends at Knowledge Capture\b'
        DenyPattern = '(?i)\b(?:not|without)\b.{0,40}\b15 steps\b|\bKnowledge Capture\b.{0,40}\bnot\b.{0,20}\b(?:last|terminal|end)\b'
      }
      [pscustomobject]@{
        Number = 2
        Tokens = @('no Gerrit', 'CCC', 'Release route')
        PositivePattern = '(?i)\bMigration\b.*\bno Gerrit\b.*\bCCC\b.*\bRelease route\b'
        DenyPattern = '(?i)\bMigration\b.*\b(?:runs?|invokes?|includes?)\b.{0,50}\b(?:Gerrit|CCC|Release)\b'
      }
      [pscustomobject]@{
        Number = 3
        Tokens = @('Gerrit', 'CCC', 'Release', 'separate delivery skills', 'explicit calls')
        PositivePattern = '(?i)\bGerrit\b.*\bCCC\b.*\bRelease\b.*\bseparate delivery skills\b.*\bexplicit calls\b'
        DenyPattern = '(?i)\b(?:automatic|implicit|migration-owned)\b.{0,40}\b(?:calls?|skills?|stages?)\b'
      }
      [pscustomobject]@{
        Number = 4
        Tokens = @('first greenfield foundation unit', 'required bootstrap', 'pending-bootstrap')
        PositivePattern = '(?i)\bfirst greenfield foundation unit\b.*\brequired bootstrap\b.*\bpending-bootstrap\b'
        DenyPattern = '(?i)\bfirst greenfield foundation unit\b.*\brequires?\b.{0,40}\bapproved foundation baseline\b'
      }
      [pscustomobject]@{
        Number = 5
        Tokens = @('Later greenfield unit', 'approved foundation baseline', 'does not bootstrap')
        PositivePattern = '(?i)\bLater greenfield unit\b.*\bapproved foundation baseline\b.*\bdoes not bootstrap\b'
        DenyPattern = '(?i)\bLater greenfield unit\b.*\b(?:reruns?|requires?) bootstrap\b'
      }
      [pscustomobject]@{
        Number = 6
        Tokens = @('Incremental', 'preserve-existing', 'does not bootstrap', 'regression remains required')
        PositivePattern = '(?i)\bIncremental\b.*\bpreserve-existing\b.*\bdoes not bootstrap\b.*\bregression remains required\b'
        DenyPattern = '(?i)\bIncremental\b.*\b(?:may|required to) bootstrap\b|\bregression\b.*\boptional\b'
      }
      [pscustomobject]@{
        Number = 7
        Tokens = @('Onboarding generates', 'profile', 'project pack drafts', 'Tech Lead approval')
        PositivePattern = '(?i)\bOnboarding generates\b.*\bprofile\b.*\bproject pack drafts\b.*\bpublishes only after Tech Lead approval\b'
        DenyPattern = '(?i)\busers?\b.*\b(?:author|write|create)\b.*\bproject pack\b|\bpublishes? before\b.*\bTech Lead approval\b'
      }
      [pscustomobject]@{
        Number = 8
        Tokens = @('Onboarding accepts', 'explicit document flags', 'optional inbox')
        PositivePattern = '(?i)\bOnboarding accepts\b.*\bexplicit document flags\b.*\boptional inbox\b'
        DenyPattern = '(?i)\binbox\b.*\bmandatory\b|\bdoes not accept\b.*\bexplicit document flags\b'
      }
      [pscustomobject]@{
        Number = 9
        Tokens = @('Onboarding never moves or modifies', 'source documents', 'production source')
        PositivePattern = '(?i)\bOnboarding never moves or modifies\b.*\bsource documents\b.*\bproduction source\b'
        DenyPattern = '(?i)\bOnboarding\b.*\b(?:may|does|will)\s+(?:move|modify|rewrite)\b.*\b(?:source documents|production source)\b'
      }
      [pscustomobject]@{
        Number = 10
        Tokens = @('Claude', 'Codex', 'ordered user workflow')
        PositivePattern = '(?i)\bClaude\b.*\bCodex\b.*\bdescribe the ordered user workflow\b'
        DenyPattern = '(?i)\b(?:Claude|Codex)\b.*\b(?:omits?|reorders?|contradicts?)\b.*\bworkflow\b'
      }
      [pscustomobject]@{
        Number = 11
        Tokens = @('Static validator', 'positive and negative coverage', 'pipeline boundaries', 'both greenfield paths')
        PositivePattern = '(?i)\bStatic validator\b.*\bpositive and negative coverage\b.*\bpipeline boundaries\b.*\bboth greenfield paths\b'
        DenyPattern = '(?i)\b(?:no|without|lacks?)\b.{0,40}\b(?:positive|negative) coverage\b'
      }
      [pscustomobject]@{
        Number = 12
        Tokens = @('Manual runtime', 'plugin evidence', 'truthful PASS or BLOCKED')
        PositivePattern = '(?i)\bManual runtime\b.*\bplugin evidence\b.*\btruthful PASS or BLOCKED\b'
        DenyPattern = '(?i)\b(?:fake|invented|unverified) PASS\b|\btruthful PASS or BLOCKED\b.*\bnot recorded\b'
      }
    )
    foreach ($contract in $acceptanceContracts) {
      $criterion = $contract.Number
      $criterionRows = @($acceptanceRows | Where-Object { $_.'#' -eq [string]$criterion })
      if ($criterionRows.Count -ne 1) {
        $errors.Add("Migration framework acceptance matrix must contain exactly one criterion $criterion")
        continue
      }
      foreach ($field in @('Acceptance criterion', 'Files', 'Validator assertion', 'Manual evidence')) {
        $value = [string]$criterionRows[0].$field
        if ([string]::IsNullOrWhiteSpace($value) -or $value -match '^(TBD|TODO|-)$') {
          $errors.Add("Migration framework acceptance criterion $criterion missing field: $field")
        }
      }
      foreach ($token in $contract.Tokens) {
        Require-Token ([string]$criterionRows[0].'Acceptance criterion') $token "Migration framework acceptance criterion $criterion meaning"
      }
      $criterionMeaning = [string]$criterionRows[0].'Acceptance criterion'
      $requiredCapabilitiesValid = $true
      if ($null -ne $contract.RequiredCapabilities) {
        foreach ($capability in @($contract.RequiredCapabilities)) {
          if ($criterionMeaning -notmatch $capability.PositivePattern -or $criterionMeaning -match $capability.DenyPattern) {
            $requiredCapabilitiesValid = $false
            break
          }
        }
      }
      if ($criterionMeaning -notmatch $contract.PositivePattern -or $criterionMeaning -match $contract.DenyPattern -or -not $requiredCapabilitiesValid) {
        $errors.Add("Migration framework acceptance criterion $criterion policy semantics invalid")
      }
    }

    $staticRows = @(Get-MarkdownTableRows $migrationGuideText 'Static verification evidence' 'Migration framework guide')
    $staticContracts = @(
      [pscustomobject]@{ Check = 'validate-migration-framework.ps1 -Check Docs'; ExpectedStatus = 'PASS' }
      [pscustomobject]@{ Check = 'validate-migration-framework.ps1 -Check All'; ExpectedStatus = 'PASS' }
      [pscustomobject]@{ Check = 'validate-migration-framework.Tests.ps1'; ExpectedStatus = 'PASS' }
      [pscustomobject]@{ Check = 'git diff --check'; ExpectedStatus = 'PASS' }
    )
    foreach ($staticContract in $staticContracts) {
      $matchingRows = @($staticRows | Where-Object {
        ([string]$_.Check).Trim().Trim([char]0x0060) -eq $staticContract.Check
      })
      if ($matchingRows.Count -ne 1) {
        $errors.Add("Migration framework static verification must contain exactly one $($staticContract.Check) row")
        continue
      }
      $staticEvidence = [string]$matchingRows[0].'Evidence or blocker'
      $verificationContradictionPattern = '(?i)\bfail(?:ed|ure|s)?\b|\berrors?\b|\breject(?:ed|ion)?\b|\bden(?:y|ied|ial)\b|\bnot\s+valid\b|\binvalid\b|\bunavailable\b|\bnot\s+run\b|\bblocked\b|\bcould\s+not\b|\bexit code\s*[1-9]\d*\b'
      $hasPositiveStaticEvidence = $staticEvidence -match '(?i)\bPASS(?:ED)?\b|\bexit code\s*0\b|\bvalidation\s+(?:succeeded|successful)\b|\bsuccess(?:ful|fully)?\b' -and
        $staticEvidence -notmatch $verificationContradictionPattern
      if ($matchingRows[0].Status -ne $staticContract.ExpectedStatus -or -not $hasPositiveStaticEvidence) {
        $errors.Add("Migration framework static verification $($staticContract.Check) must record positive PASS evidence without contradiction")
      }
    }

    $pluginCommand = 'claude plugin validate .\aitoolkit'
    $pluginRows = @($staticRows | Where-Object {
      ([string]$_.Check).Trim().Trim([char]0x0060) -eq $pluginCommand
    })
    if ($pluginRows.Count -ne 1) {
      $errors.Add("Migration framework static verification must contain exactly one $pluginCommand row")
    }
    else {
      $pluginRow = $pluginRows[0]
      $pluginEvidence = [string]$pluginRow.'Evidence or blocker'
      $pluginContradictionPattern = '(?i)\bfail(?:ed|ure|s)?\b|\berrors?\b|\breject(?:ed|ion)?\b|\bden(?:y|ied|ial)\b|\bnot\s+valid\b|\binvalid\b|\bunavailable\b|\bnot\s+run\b|\bblocked\b|\bcould\s+not\b|\bexit code\s*[1-9]\d*\b'
      if ($pluginRow.Status -eq 'PASS') {
        $hasPositivePluginEvidence = $pluginEvidence -match '(?i)\bPASS(?:ED)?\b|\bexit code\s*0\b|\b(?:plugin )?validation\s+(?:succeeded|successful)\b|\bsuccess(?:ful|fully)?\b'
        if (-not $hasPositivePluginEvidence -or $pluginEvidence -match $pluginContradictionPattern) {
          $errors.Add('Migration framework plugin validation PASS requires explicit successful validation evidence without contradiction')
        }
      }
      elseif ($pluginRow.Status -eq 'BLOCKED') {
        $hasConcretePluginBlocker = $pluginEvidence.Length -ge 30 -and
          $pluginEvidence -match '(?i)claude' -and
          $pluginEvidence -match '(?i)unavailable' -and
          $pluginEvidence -match '(?i)not run'
        if (-not $hasConcretePluginBlocker) {
          $errors.Add('Migration framework plugin validation BLOCKED requires a concrete unavailable-CLI reason')
        }
      }
      else {
        $errors.Add('Migration framework plugin validation status must be PASS or BLOCKED')
      }
    }
  }

  if (Test-Path $contributingPath) {
    $contributingText = Get-Content -Raw -Encoding utf8 $contributingPath
    $languageAndAutomationDocTokens | ForEach-Object { Require-Token $contributingText $_ 'Contributing migration automation/language guidance' }
    Test-MigrationUserWorkflow `
      $contributingText `
      'Migration user workflow' `
      'Contributing guide' `
      '/aitoolkit:migration-onboarding' `
      '/aitoolkit:migrate <feature-slug>'
    Test-MigrationDocumentationBoundaries $contributingText 'Contributing guide'
    @(
      'examples/migration/greenfield/docs/aitoolkit/project.yaml'
      'examples/migration/incremental/docs/aitoolkit/project.yaml'
      'validate-migration-framework.ps1 -Check Docs'
      'migration core'
      'project pack'
    ) | ForEach-Object { Require-Token $contributingText $_ 'Contributing migration framework guidance' }
  }

  if (Test-Path $codexGuidePath) {
    $codexGuideText = Get-Content -Raw -Encoding utf8 $codexGuidePath
    $languageAndAutomationDocTokens | ForEach-Object { Require-Token $codexGuideText $_ 'Codex migration automation/language guidance' }
    Test-MigrationUserWorkflow `
      $codexGuideText `
      'Migration user workflow' `
      'Codex guide' `
      '$aitoolkit migration-onboarding' `
      '$aitoolkit migrate <feature-slug>'
    Test-MigrationDocumentationBoundaries $codexGuideText 'Codex guide'
    @(
      '$aitoolkit migration-onboarding'
      '$aitoolkit migrate <feature-slug>'
      'greenfield'
      'incremental'
      'docs/aitoolkit/project.yaml'
      'docs/aitoolkit/migration-project'
    ) | ForEach-Object { Require-Token $codexGuideText $_ 'Codex migration framework guidance' }
  }

  Test-MigrationExampleFixture 'examples/migration/greenfield/docs/aitoolkit/project.yaml' 'greenfield' 'design-new' 'optional'
  Test-MigrationExampleFixture 'examples/migration/incremental/docs/aitoolkit/project.yaml' 'incremental' 'preserve-existing' 'required'

  $pluginPath = Join-Path $root '.claude-plugin/plugin.json'
  if (-not (Test-Path $pluginPath)) {
    $errors.Add('Missing Claude plugin metadata')
    return
  }

  try {
    $plugin = Get-Content -Raw -Encoding utf8 $pluginPath | ConvertFrom-Json
  }
  catch {
    $errors.Add("Claude plugin metadata is not valid JSON: $($_.Exception.Message)")
    return
  }

  if ($plugin.version -ne '0.7.0') {
    $errors.Add("Claude plugin metadata version must be 0.7.0; found $($plugin.version)")
  }
  foreach ($token in @('orchestrator skill', 'human gate')) {
    Require-Token ([string]$plugin.description) $token 'Claude plugin description'
  }
  if ([string]$plugin.description -match '(?i)manifest') {
    $errors.Add('Claude plugin description must not claim a manifest workflow')
  }

  $keywords = @($plugin.keywords | ForEach-Object { ([string]$_).ToLowerInvariant() })
  foreach ($requiredKeyword in @('migration', 'agentic', 'workflow')) {
    if ($requiredKeyword -notin $keywords) {
      $errors.Add("Claude plugin keywords missing: $requiredKeyword")
    }
  }
  $allowedKeywords = @('sdlc', 'migration', 'agentic', 'workflow')
  foreach ($keyword in $keywords) {
    if ($keyword -notin $allowedKeywords) {
      $errors.Add("Claude plugin contains stack-specific or unsupported keyword: $keyword")
    }
  }
}

function Test-ReviewableChangeHygiene {
  $contractPath = Join-Path $root 'skills/shared/change-hygiene.md'
  if (-not (Test-Path $contractPath)) {
    $errors.Add('Missing shared change-hygiene contract')
    return
  }

  $contractText = Get-Content -Raw -Encoding utf8 $contractPath
  @(
    'Never run a repository-wide formatter for a scoped functional task.'
    'An existing file may contain formatting changes only in the edited region or minimum adjacent syntax required for validity.'
    'A new file may be formatted completely.'
    'Inspect the final diff and remove every untraced or formatting-only change.'
    'one task has exactly one final delivery commit'
    "Squash only the current task's own commits; never use squash to incorporate an upstream branch."
    'Ancestry, commit-integrity, correctness, and diff-scope failures are not waiver-eligible.'
  ) | ForEach-Object { Require-Token $contractText $_ 'Shared change-hygiene contract' }

  if ($contractText -match '(?i)existing file.{0,100}(format (the )?(complete|entire|whole) file|repository-wide formatter)') {
    $errors.Add('Shared change-hygiene contract permits broad formatting of an existing file')
  }
  if ($contractText -match '(?i)repository-wide format(ting|ter).{0,80}(is allowed|is permitted|when mandatory)') {
    $errors.Add('Shared change-hygiene contract permits repository-wide formatting')
  }
  if ($contractText -match '(?i)new file.{0,80}(must not|cannot|forbidden).{0,30}format') {
    $errors.Add('Shared change-hygiene contract forbids complete formatting of a new file')
  }
  if ($contractText -match '(?i)(skip|omit|do not).{0,40}(inspect|review).{0,30}final diff') {
    $errors.Add('Shared change-hygiene contract permits skipping final diff inspection')
  }
  if ($contractText -match '(?i)squash.{0,80}(upstream branch.{0,30}(allowed|permitted)|may incorporate an upstream)') {
    $errors.Add('Shared change-hygiene contract permits upstream squash incorporation')
  }
  if ($contractText -match '(?i)(ancestry|commit-integrity|diff-scope).{0,120}(may be auto-?waived|are waiver-eligible)') {
    $errors.Add('Shared change-hygiene contract permits integrity failures to be waived')
  }

  foreach ($relativePath in @(
    'skills/migration/code-migration/SKILL.md'
    'skills/feature/implement/SKILL.md'
    'skills/bugfix/fix/SKILL.md'
    'skills/shared/ai-review/SKILL.md'
    'skills/shared/gerrit-automation/SKILL.md'
  )) {
    $consumerPath = Join-Path $root $relativePath
    if (-not (Test-Path $consumerPath)) {
      $errors.Add("Missing change-hygiene consumer: $relativePath")
      continue
    }
    $consumerText = Get-Content -Raw -Encoding utf8 $consumerPath
    Require-Token $consumerText 'shared/change-hygiene.md' "Change-hygiene consumer $relativePath"
  }

  $planWavesText = Get-Content -Raw -Encoding utf8 (Join-Path $root 'skills/migration/plan-waves/SKILL.md')
  @('one `UNIT-###`', 'one independently reviewable Gerrit change', 'implementable', 'testable', 'revertible') |
    ForEach-Object { Require-Token $planWavesText $_ 'Plan-waves delivery boundary' }

  $aiReviewText = Get-Content -Raw -Encoding utf8 (Join-Path $root 'skills/shared/ai-review/SKILL.md')
  @('at least Major', 'task-base SHA', 'task-base..final-tree', 'block missing or mismatched provenance') |
    ForEach-Object { Require-Token $aiReviewText $_ 'AI Review change-hygiene scope' }

  $gerritText = Get-Content -Raw -Encoding utf8 (Join-Path $root 'skills/shared/gerrit-automation/SKILL.md')
  @('one final task commit', 'task-local checkpoint commits', 'task-base SHA', 'actual task commit count', 'exactly `1`', 'references/testing-rules.md', 'upstream SHA', 'merge-base SHA', 'final commit SHA', 'diff-scope verdict', 'before the HARD gate') |
    ForEach-Object { Require-Token $gerritText $_ 'Gerrit branch and commit integrity' }
  if (
    $gerritText -match '(?i)(integrity|diff-scope|ancestry).{0,120}(may be auto-?waived|are waiver-eligible)' -or
    $gerritText -match '(?i)blocked.{0,40}(but )?may be auto-?waived'
  ) {
    $errors.Add('Gerrit branch and commit integrity permits waiver')
  }

  foreach ($templateContract in @(
    [pscustomobject]@{ Path = 'templates/migration/migration-plan.md'; Token = 'Delivery Change Boundary' }
    [pscustomobject]@{ Path = 'templates/migration/implementation-report.md'; Token = '## Change Hygiene' }
    [pscustomobject]@{ Path = 'templates/review-report.md'; Token = '## Change Hygiene' }
    [pscustomobject]@{ Path = 'templates/migration/review-report.md'; Token = '## Change Hygiene' }
    [pscustomobject]@{ Path = 'templates/gerrit-report.md'; Token = '## Branch and Commit Integrity' }
  )) {
    $templateText = Get-Content -Raw -Encoding utf8 (Join-Path $root $templateContract.Path)
    Require-Token $templateText $templateContract.Token "Change-hygiene template $($templateContract.Path)"
  }
  $changeColumns = @('Task / Unit', 'File', 'File Kind', 'Edited Region / Symbol', 'Formatter Command', 'Unrelated Diff', 'Checkpoint History', 'Task-base SHA', 'Final-tree SHA')
  Test-MarkdownTableExactColumns (Get-Content -Raw -Encoding utf8 (Join-Path $root 'templates/migration/implementation-report.md')) 'Change Hygiene' $changeColumns 'Migration implementation change hygiene'
  Test-MarkdownTableExactColumns (Get-Content -Raw -Encoding utf8 (Join-Path $root 'templates/implement-report.md')) 'Change Hygiene' $changeColumns 'Feature implementation change hygiene'
  Test-MarkdownTableExactColumns (Get-Content -Raw -Encoding utf8 (Join-Path $root 'templates/fix-report.md')) 'Change Hygiene' $changeColumns 'Bugfix implementation change hygiene'
  Test-MarkdownTableExactColumns (Get-Content -Raw -Encoding utf8 (Join-Path $root 'templates/gerrit-report.md')) 'Branch and Commit Integrity' @('Task-base SHA', 'Upstream Ref', 'Upstream SHA', 'Merge-base SHA', 'Final Commit SHA', 'Actual Task Commit Count', 'Task / Unit ID', 'Diff-scope Verdict', 'Formatter Evidence', 'Post-integration Verification') 'Gerrit branch and commit integrity'
  $orderedMigrationUnitsSection = ConvertFrom-Utf8Base64 'Q8OhYyDEkcahbiB24buLIG1pZ3JhdGlvbiB0aGVvIHRo4bupIHThu7E='
  Test-MarkdownTableExactColumns (Get-Content -Raw -Encoding utf8 (Join-Path $root 'templates/migration/migration-plan.md')) $orderedMigrationUnitsSection @('Order', 'Migration Unit ID', 'Bootstrap Scope', 'Foundation Baseline ID', 'Foundation Approval Reference', 'Dependencies', 'Acceptance', 'Mode Constraint', 'Trace IDs', 'Delivery Change Boundary', 'Approval Reference', 'Approval Status') 'Migration plan delivery boundary'
  $reviewColumns = @('Task / Unit', 'Scope Evidence', 'Formatter Evidence', 'Unrelated Diff', 'Severity', 'Task-base SHA', 'Final-tree SHA')
  Test-MarkdownTableExactColumns (Get-Content -Raw -Encoding utf8 (Join-Path $root 'templates/review-report.md')) 'Change Hygiene' $reviewColumns 'Feature/bugfix review provenance'
  Test-MarkdownTableExactColumns (Get-Content -Raw -Encoding utf8 (Join-Path $root 'templates/migration/review-report.md')) 'Change Hygiene' $reviewColumns 'Migration review provenance'
  $provenanceColumns = @('Task / Unit', 'Task-base SHA', 'Final-tree SHA', 'Source Artifact')
  Test-MarkdownTableExactColumns (Get-Content -Raw -Encoding utf8 (Join-Path $root 'templates/verification-report.md')) 'Task Provenance' $provenanceColumns 'Feature/bugfix verification provenance'
  Test-MarkdownTableExactColumns (Get-Content -Raw -Encoding utf8 (Join-Path $root 'templates/migration/verification-report.md')) 'Task Provenance' $provenanceColumns 'Migration verification provenance'
  Test-MarkdownTableExactColumns (Get-Content -Raw -Encoding utf8 (Join-Path $root 'templates/kb-entry.md')) 'Task Provenance' $provenanceColumns 'Knowledge Base task provenance'
  Test-MarkdownTableExactColumns (Get-Content -Raw -Encoding utf8 (Join-Path $root 'templates/migration/parity-report.md')) 'Task Provenance' $provenanceColumns 'Migration parity task provenance'
  Test-MarkdownTableExactColumns (Get-Content -Raw -Encoding utf8 (Join-Path $root 'templates/migration/regression-report.md')) 'Task Provenance' $provenanceColumns 'Migration regression task provenance'

  $referenceRoot = Join-Path $root 'examples/project-packs/webos-qml-flutter/references'
  $architectureText = Get-Content -Raw -Encoding utf8 (Join-Path $referenceRoot 'architecture-rules.md')
  @('git fetch origin', 'git rebase origin/develop', 'git merge --squash origin/develop', 'forbidden', 'git merge-base origin/develop HEAD', 'git rev-parse origin/develop', 'The merge-base must equal the upstream tip.') |
    ForEach-Object { Require-Token $architectureText $_ 'LGE ancestry rules' }
  if (
    $architectureText -match '(?i)(allow|use|required).{0,40}git merge --squash origin/develop' -or
    $architectureText -match '(?i)git merge --squash origin/develop.{0,40}(allow|permitted|required)'
  ) {
    $errors.Add('LGE ancestry rules permit squash-copy synchronization')
  }

  $testingText = Get-Content -Raw -Encoding utf8 (Join-Path $referenceRoot 'testing-rules.md')
  @('after the rebase', 'flutter-webos analyze', 'flutter-webos test', 'exit status') |
    ForEach-Object { Require-Token $testingText $_ 'LGE post-rebase verification' }
  if ($testingText -match '(?i)(skip|optional|not required).{0,60}(flutter-webos analyze|flutter-webos test|after the rebase)') {
    $errors.Add('LGE post-rebase verification permits required commands to be skipped')
  }

  $dodText = Get-Content -Raw -Encoding utf8 (Join-Path $referenceRoot 'definition-of-done.md')
  @('exactly one final task commit', 'task-local', 'request review immediately', 'git rebase origin/develop', 'git merge-base origin/develop HEAD', 'git rev-parse origin/develop', 'ancestry', 'diff-scope', 'before the Gerrit upload HARD gate') |
    ForEach-Object { Require-Token $dodText $_ 'LGE task delivery rules' }
}

if (-not [string]::IsNullOrWhiteSpace($ActivationSliceArtifactPath)) {
  if (-not (Test-Path -LiteralPath $ActivationSliceArtifactPath)) {
    $errors.Add("Activation Slice artifact not found: $ActivationSliceArtifactPath")
  }
  else {
    $activationSliceDefinition = Get-ActivationSliceContractDefinition
    $artifactText = Get-Content -Raw -Encoding utf8 -LiteralPath $ActivationSliceArtifactPath
    $artifact = Test-ActivationSliceArtifact $artifactText 'Activation Slice artifact' $activationSliceDefinition
    $artifactHasBlockingErrors = $artifact.HasBlockingErrors
    $predecessor = $null
    $handoffRule = $null
    $discoveryOriginWithoutEnvelope = $false
    $roleCurrentStepIds = @($activationSliceDefinition.HandoffRules | ForEach-Object {
      Get-ActivationSliceCellValue $_ 'Current step ID'
    })
    if (-not [string]::IsNullOrWhiteSpace($PredecessorActivationSliceArtifactPath)) {
      if (-not (Test-Path -LiteralPath $PredecessorActivationSliceArtifactPath)) {
        $errors.Add("Activation Slice predecessor artifact not found: $PredecessorActivationSliceArtifactPath")
      }
      else {
        $predecessorText = Get-Content -Raw -Encoding utf8 -LiteralPath $PredecessorActivationSliceArtifactPath
        if (
          $artifact.FrontMatter.StepId -ceq '02-discovery' -and
          @(Get-MarkdownSectionHeadings $predecessorText 'Activation Slice').Count -eq 0
        ) {
          $discoveryOriginWithoutEnvelope = $true
          $predecessor = New-ActivationSliceArtifactState
          $predecessor.Text = $predecessorText
          $predecessor.FrontMatter = Get-ActivationSliceFrontMatter `
            $predecessorText 'Activation Slice predecessor'
          $predecessor.HasBlockingErrors = $false
          Test-ActivationSliceFrontMatter `
            $predecessor `
            $false `
            'Activation Slice predecessor' `
            $activationSliceDefinition `
            $false `
            $true
        }
        else {
          $predecessor = Test-ActivationSliceArtifact $predecessorText 'Activation Slice predecessor' $activationSliceDefinition
          Test-ActivationSliceFrontMatter `
            $predecessor `
            $predecessor.HasBlockingErrors `
            'Activation Slice predecessor' `
            $activationSliceDefinition `
            $false `
            ($artifact.FrontMatter.StepId -ceq '02-discovery')
        }
        Test-ActivationSlicePreselectionArtifactState `
          $predecessor $activationSliceDefinition 'predecessor' 'Activation Slice artifact'
        $handoffErrorStart = $errors.Count
        $handoffRule = Get-ActivationSliceImmediatePredecessorRule `
          $predecessor `
          $artifact `
          $activationSliceDefinition `
          'Activation Slice artifact'
        if ($null -ne $handoffRule) {
          $routeErrorStart = $errors.Count
          [void](Test-ActivationSliceSelectedRoute `
            $artifact $handoffRule $activationSliceDefinition 'Activation Slice artifact')
          Test-ActivationSliceBootstrapHandoff `
            $predecessor $artifact $activationSliceDefinition 'Activation Slice artifact'
          if (
            $artifact.FrontMatter.StepId -ceq '11-ai-review' -and
            $predecessor.FrontMatter.StepId -ceq '10-code-migration'
          ) {
            Test-ActivationSliceImplementationPredecessorForReview `
              $predecessor $activationSliceDefinition 'Activation Slice artifact'
          }
          if ((Get-ActivationSliceCellValue $handoffRule 'Route') -ceq 'post-waiver-resume') {
            Test-ActivationSlicePostWaiverResumePredecessor `
              $predecessor $activationSliceDefinition 'Activation Slice artifact'
          }
          if ($artifact.FrontMatter.StepId -ceq '13-verify-parity') {
            [void](Test-ActivationSliceParityVerdictArtifact `
              $artifact $activationSliceDefinition 'current' 'Activation Slice artifact')
          }
          if ($errors.Count -eq $routeErrorStart) {
            if (
              (Get-ActivationSliceCellValue $handoffRule 'Route') -cne 'discovery-origin' -or
              -not $discoveryOriginWithoutEnvelope
            ) {
              Test-ActivationSliceHandoff $predecessor $artifact $activationSliceDefinition
            }
            Test-ActivationSliceDownstreamSelectedUnitHandoff `
              $predecessor $artifact $activationSliceDefinition 'Activation Slice artifact'
            Test-ActivationSliceAssuranceProvenanceHandoff `
              $predecessor `
              $artifact `
              $activationSliceDefinition `
              'Activation Slice artifact' `
              $PredecessorActivationSliceArtifactPath `
              $ActivationSliceArtifactPath
            Test-ActivationSliceRegressionParityHandoff `
              $predecessor $artifact $activationSliceDefinition 'Activation Slice artifact'
          }
        }
        $artifactHasBlockingErrors = $artifactHasBlockingErrors -or ($errors.Count -gt $handoffErrorStart)
      }
    }
    elseif ($roleCurrentStepIds -ccontains $artifact.FrontMatter.StepId) {
      $errors.Add("Activation Slice artifact step_id $($artifact.FrontMatter.StepId) requires immediate predecessor artifact")
      $artifactHasBlockingErrors = $true
    }
    Test-ActivationSliceImplementationLinks `
      $artifactText `
      $artifact `
      $predecessor `
      'Activation Slice artifact' `
      $activationSliceDefinition `
      $handoffRule
    $artifactHasBlockingErrors = $artifactHasBlockingErrors -or ($artifact.LinkBlockingErrorCount -gt 0)
    $assuranceErrorStart = $errors.Count
    Test-ActivationSliceAssuranceVerdictConsistency `
      $artifact $activationSliceDefinition 'Activation Slice artifact'
    $artifactHasBlockingErrors = $artifactHasBlockingErrors -or ($errors.Count -gt $assuranceErrorStart)
    Test-ActivationSliceFrontMatter `
      $artifact `
      $artifactHasBlockingErrors `
      'Activation Slice artifact' `
      $activationSliceDefinition `
      ($null -ne $handoffRule)
  }

  if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Output "FAIL: $_" }
    exit 1
  }
  Write-Output 'PASS: Activation Slice artifact'
  exit 0
}
elseif (-not [string]::IsNullOrWhiteSpace($PredecessorActivationSliceArtifactPath)) {
  $errors.Add('Activation Slice predecessor requires ActivationSliceArtifactPath')
}

if ($Check -in 'Contracts', 'All') { Test-Contracts }
if ($Check -in 'Encoding', 'All') { Test-Encoding }
if ($Check -in 'Templates', 'All') { Test-Templates }
if ($Check -in 'Skills', 'All') { Test-Skills }
if ($Check -in 'Orchestrators', 'All') { Test-Orchestrators }
if ($Check -in 'Onboarding', 'All') { Test-Onboarding }
if ($Check -in 'Compatibility', 'All') { Test-Compatibility }
if ($Check -in 'Docs', 'All') { Test-Docs }
if ($Check -in 'Skills', 'Templates', 'Compatibility', 'All') { Test-ReviewableChangeHygiene }

if ($errors.Count -gt 0) {
  $errors | ForEach-Object { Write-Output "FAIL: $_" }
  exit 1
}

Write-Output "PASS: migration framework ($Check)"

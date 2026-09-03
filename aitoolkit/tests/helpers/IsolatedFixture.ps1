function New-IsolatedAitoolkitFixture([string]$SourceRoot) {
  $sourcePath = [IO.Path]::GetFullPath($SourceRoot)
  if (-not (Test-Path -LiteralPath $sourcePath -PathType Container)) {
    throw "Fixture source root does not exist: $sourcePath"
  }

  $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd(
    [IO.Path]::DirectorySeparatorChar,
    [IO.Path]::AltDirectorySeparatorChar
  )
  $container = [IO.Path]::GetFullPath((Join-Path $tempRoot "aitoolkit-framework-tests-$PID-$([guid]::NewGuid().ToString('N'))"))
  if (-not $container.StartsWith($tempRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing non-temp fixture path: $container"
  }

  New-Item -ItemType Directory -Path $container -Force | Out-Null
  try {
    Copy-Item -LiteralPath $sourcePath -Destination $container -Recurse -Force
    return [IO.Path]::GetFullPath((Join-Path $container 'aitoolkit'))
  }
  catch {
    if (Test-Path -LiteralPath $container) {
      Remove-Item -LiteralPath $container -Recurse -Force
    }
    throw
  }
}

function Get-TreeDigest([string]$Root) {
  $rootPath = [IO.Path]::GetFullPath($Root).TrimEnd(
    [IO.Path]::DirectorySeparatorChar,
    [IO.Path]::AltDirectorySeparatorChar
  )
  if (-not (Test-Path -LiteralPath $rootPath -PathType Container)) {
    throw "Digest root does not exist: $rootPath"
  }

  $files = @(
    Get-ChildItem -LiteralPath $rootPath -Recurse -File |
      ForEach-Object {
        $_.FullName.Substring($rootPath.Length).TrimStart(
            [IO.Path]::DirectorySeparatorChar,
            [IO.Path]::AltDirectorySeparatorChar
          ).Replace([IO.Path]::DirectorySeparatorChar, '/').Replace([IO.Path]::AltDirectorySeparatorChar, '/')
      }
  )
  [Array]::Sort($files, [StringComparer]::Ordinal)
  $hash = [Security.Cryptography.SHA256]::Create()
  try {
    foreach ($relativePath in $files) {
      $pathBytes = [Text.Encoding]::UTF8.GetBytes($relativePath)
      $separator = [byte[]]@(0)
      [void]$hash.TransformBlock($pathBytes, 0, $pathBytes.Length, $pathBytes, 0)
      [void]$hash.TransformBlock($separator, 0, $separator.Length, $separator, 0)
      $filePath = Join-Path $rootPath ($relativePath.Replace('/', [IO.Path]::DirectorySeparatorChar))
      $bytes = [IO.File]::ReadAllBytes($filePath)
      [void]$hash.TransformBlock($bytes, 0, $bytes.Length, $bytes, 0)
    }
    [void]$hash.TransformFinalBlock([byte[]]@(), 0, 0)
    return ([BitConverter]::ToString($hash.Hash)).Replace('-', '')
  }
  finally {
    $hash.Dispose()
  }
}

function Invoke-IsolatedMutation([string]$SourceRoot, [scriptblock]$Mutation) {
  $fixtureRoot = New-IsolatedAitoolkitFixture -SourceRoot $SourceRoot
  try {
    return (& $Mutation $fixtureRoot)
  }
  finally {
    Remove-IsolatedAitoolkitFixture -FixtureRoot $fixtureRoot
  }
}

function Remove-IsolatedAitoolkitFixture([string]$FixtureRoot) {
  $fixturePath = [IO.Path]::GetFullPath($FixtureRoot).TrimEnd(
    [IO.Path]::DirectorySeparatorChar,
    [IO.Path]::AltDirectorySeparatorChar
  )
  $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd(
    [IO.Path]::DirectorySeparatorChar,
    [IO.Path]::AltDirectorySeparatorChar
  )
  $container = [IO.Path]::GetDirectoryName($fixturePath)
  if (
    [IO.Path]::GetFileName($fixturePath) -cne 'aitoolkit' -or
    -not $fixturePath.StartsWith($tempRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or
    -not ([IO.Path]::GetFileName($container) -cmatch '^aitoolkit-framework-tests-\d+-[0-9a-f]{32}$')
  ) {
    throw "Refusing to remove non-temp AIToolkit fixture: $fixturePath"
  }
  if (Test-Path -LiteralPath $container) {
    Remove-Item -LiteralPath $container -Recurse -Force
  }
}

param(
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $repoRoot 'outputs\SLE_AB_H3863_source.zip'
}
$OutputPath = [System.IO.Path]::GetFullPath($OutputPath)
$expectedOutputs = [System.IO.Path]::GetFullPath((Join-Path $repoRoot 'outputs')).TrimEnd('\') + '\'
if (-not $OutputPath.StartsWith($expectedOutputs, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to replace an archive outside the repository outputs directory: $OutputPath"
}

$include = @(
    'card_ws63', 'common', 'detector_a', 'detector_b', 'docs', 'firmware',
    'platform', 'tests', 'tools', 'README.md', 'WORK_PROGRESS.md'
)
$files = foreach ($item in $include) {
    $path = Join-Path $repoRoot $item
    if (Test-Path -LiteralPath $path -PathType Container) {
        Get-ChildItem -LiteralPath $path -Recurse -File
    } elseif (Test-Path -LiteralPath $path -PathType Leaf) {
        Get-Item -LiteralPath $path
    }
}
$files = $files | Where-Object {
    $_.Extension -notin @('.exe', '.obj', '.pdb', '.ilk', '.zip') -and
    $_.FullName -notmatch '[\\/]tempFiles[\\/]'
} | Sort-Object FullName -Unique

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$parent = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Force -Path $parent | Out-Null
$stream = [System.IO.File]::Open($OutputPath, [System.IO.FileMode]::Create,
    [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
try {
    $archive = [System.IO.Compression.ZipArchive]::new(
        $stream, [System.IO.Compression.ZipArchiveMode]::Create, $false)
    try {
        foreach ($file in $files) {
            $relative = $file.FullName.Substring($repoRoot.Length).TrimStart('\').Replace('\', '/')
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $archive, $file.FullName, $relative,
                [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
        }
    } finally {
        $archive.Dispose()
    }
} finally {
    $stream.Dispose()
}

$hash = (Get-FileHash -LiteralPath $OutputPath -Algorithm SHA256).Hash
Write-Host "Source archive: $OutputPath"
Write-Host "Entries: $($files.Count)"
Write-Host "SHA256: $hash"

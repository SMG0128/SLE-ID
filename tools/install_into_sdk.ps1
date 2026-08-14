param(
    [Parameter(Mandatory = $true)]
    [string]$SdkRoot
)

$ErrorActionPreference = 'Stop'
$sourceRoot = Split-Path -Parent $PSScriptRoot
$sdkSource = Join-Path $SdkRoot 'src'
if (Test-Path (Join-Path $SdkRoot 'build.py')) {
    $sdkSource = $SdkRoot
}
$buildFile = Join-Path $sdkSource 'build.py'
if (-not (Test-Path -LiteralPath $buildFile)) {
    throw "SDK root is invalid; build.py not found under $SdkRoot or $SdkRoot\src"
}

$sdkSource = [System.IO.Path]::GetFullPath($sdkSource)
$sourceRoot = [System.IO.Path]::GetFullPath($sourceRoot)

function Assert-ChildPath {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Parent
    )
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $fullParent = [System.IO.Path]::GetFullPath($Parent).TrimEnd('\') + '\'
    if (-not $fullPath.StartsWith($fullParent, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to modify path outside expected parent: $fullPath"
    }
    return $fullPath
}

$customRoot = Join-Path $sdkSource 'application\samples\custom'
$target = Join-Path $customRoot 'sle_ab'
$cardTarget = Join-Path $customRoot 'sle_card'
$customRoot = Assert-ChildPath -Path $customRoot -Parent $sdkSource
$target = Assert-ChildPath -Path $target -Parent $customRoot
$cardTarget = Assert-ChildPath -Path $cardTarget -Parent $customRoot
New-Item -ItemType Directory -Force -Path $customRoot | Out-Null
New-Item -ItemType Directory -Force -Path $target | Out-Null

Copy-Item -LiteralPath (Join-Path $sourceRoot 'firmware\h3863\sle_ab\CMakeLists.txt') -Destination $target -Force
Copy-Item -LiteralPath (Join-Path $sourceRoot 'firmware\h3863\sle_ab\Kconfig') -Destination $target -Force
Copy-Item -LiteralPath (Join-Path $sourceRoot 'firmware\h3863\sle_ab\h3863_sle_ab.c') -Destination $target -Force
Copy-Item -LiteralPath (Join-Path $sourceRoot 'firmware\h3863\sle_ab\sle_ab_dual_client.c') -Destination $target -Force
Copy-Item -LiteralPath (Join-Path $sourceRoot 'firmware\h3863\sle_ab\sle_ab_dual_client.h') -Destination $target -Force

if (Test-Path -LiteralPath $cardTarget) { Remove-Item -LiteralPath $cardTarget -Recurse -Force }
Copy-Item -LiteralPath (Join-Path $sourceRoot 'firmware\h3863\sle_card') `
    -Destination $cardTarget -Recurse

$sharedFolders = @('common', 'detector_a', 'detector_b', 'card_ws63')
foreach ($folder in $sharedFolders) {
    $destination = Assert-ChildPath -Path (Join-Path $customRoot $folder) -Parent $customRoot
    if (Test-Path -LiteralPath $destination) { Remove-Item -LiteralPath $destination -Recurse -Force }
    Copy-Item -LiteralPath (Join-Path $sourceRoot $folder) -Destination $destination -Recurse
}

Copy-Item -LiteralPath (Join-Path $sourceRoot 'firmware\h3863\custom_CMakeLists.txt') `
    -Destination (Join-Path $customRoot 'CMakeLists.txt') -Force
Copy-Item -LiteralPath (Join-Path $sourceRoot 'firmware\h3863\custom_Kconfig') `
    -Destination (Join-Path $customRoot 'Kconfig') -Force

$rootKconfig = Join-Path $sdkSource 'application\samples\Kconfig'
$sourceLine = 'osource "application/samples/custom/Kconfig"'
$content = Get-Content -Raw -LiteralPath $rootKconfig
if (-not $content.Contains($sourceLine)) {
    Copy-Item -LiteralPath $rootKconfig -Destination "$rootKconfig.sle_ab.bak" -Force
    Add-Content -LiteralPath $rootKconfig -Value "`r`n# SLE detector A/B project`r`n$sourceLine`r`n"
}

Write-Host "Installed SLE A/B sources to: $target"
Write-Host "Installed SLE Card C sources to: $cardTarget"
Write-Host 'Original root Kconfig backup: application\samples\Kconfig.sle_ab.bak (created on first install)'

param(
    [Parameter(Mandatory = $true)]
    [string]$SdkRoot
)

$ErrorActionPreference = 'Stop'
$sdkSource = Join-Path $SdkRoot 'src'
if (Test-Path -LiteralPath (Join-Path $SdkRoot 'build.py')) {
    $sdkSource = $SdkRoot
}
$sdkSource = [System.IO.Path]::GetFullPath($sdkSource)
$nvConfig = Join-Path $sdkSource 'middleware\chips\ws63\nv\include\nv_config.h'
$keyIdHeader = Join-Path $sdkSource 'middleware\chips\ws63\nv\nv_config\include\key_id.h'
foreach ($required in @($nvConfig, $keyIdHeader)) {
    if (-not (Test-Path -LiteralPath $required)) {
        throw "Required WS63 NV definition not found: $required"
    }
}

$configText = Get-Content -Raw -LiteralPath $nvConfig
$sizeMatch = [regex]::Match($configText, 'NV_NORMAL_KVALUE_MAX_LEN\s+(\d+)')
if (-not $sizeMatch.Success -or [int]$sizeMatch.Groups[1].Value -lt 768) {
    throw 'WS63 normal NV value limit is missing or smaller than the 768-byte Card slot.'
}
$keyText = Get-Content -Raw -LiteralPath $keyIdHeader
if ($keyText -notmatch 'NV_ID_USER_NORMAL_AREA_START\s+0x5000') {
    throw 'WS63 user-normal NV region no longer starts at 0x5000; review Card key allocation.'
}

$projectCopies = @(
    [System.IO.Path]::GetFullPath((Join-Path $sdkSource 'application\samples\custom\card_ws63')),
    [System.IO.Path]::GetFullPath((Join-Path $sdkSource 'application\samples\custom\sle_card'))
)
$searchRoots = @(
    (Join-Path $sdkSource 'middleware'),
    (Join-Path $sdkSource 'application')
)
$patterns = @('0x5C10', '0x5C11')
$collisions = New-Object System.Collections.Generic.List[string]
foreach ($file in Get-ChildItem -LiteralPath $searchRoots -Recurse -File -Include *.c,*.h,*.json,*.cfg) {
    $fullPath = $file.FullName
    $isProjectCopy = $false
    foreach ($projectCopy in $projectCopies) {
        if ($fullPath.StartsWith($projectCopy + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
            $isProjectCopy = $true
            break
        }
    }
    if ($isProjectCopy) { continue }
    foreach ($pattern in $patterns) {
        if (Select-String -LiteralPath $fullPath -Pattern "(?i)$pattern\b" -Quiet) {
            $collisions.Add("$pattern in $fullPath")
        }
    }
}
if ($collisions.Count -ne 0) {
    throw "Card NV key collision(s) require manual review:`n$($collisions -join "`n")"
}

Write-Host 'Card NV allocation check passed: 0x5C10/0x5C11, slot size 768 bytes.'

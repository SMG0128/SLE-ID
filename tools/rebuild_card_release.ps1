param(
    [Parameter(Mandatory = $true)]
    [string]$SdkRoot
)

$ErrorActionPreference = 'Stop'
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkSource = Join-Path $SdkRoot 'src'
if (Test-Path -LiteralPath (Join-Path $SdkRoot 'build.py')) {
    $sdkSource = $SdkRoot
}
$sdkSource = [System.IO.Path]::GetFullPath($sdkSource)
$configTool = Join-Path $PSScriptRoot 'set_sdk_kconfig.py'
$configFile = Join-Path $sdkSource 'build\config\target_config\ws63\menuconfig\acore\ws63_liteos_app.config'
$packageFile = Join-Path $sdkSource 'output\ws63\fwpkg\ws63-liteos-app\ws63-liteos-app_all.fwpkg'
$pythonExe = 'D:\hispark\tools\python\python.exe'
$outputs = Join-Path $repoRoot 'outputs'
$configs = Join-Path $repoRoot 'firmware\h3863\configs'
$buildToolPaths = @(
    'D:\hispark\tools\Windows\cc_riscv32_musl_win\bin',
    'D:\hispark\tools\python\Scripts',
    'D:\hispark\tools\python\Lib\site-packages\cmake\data\bin',
    'D:\hispark\tools\Windows\ninja'
)

foreach ($required in @($configTool, $configFile, $pythonExe) + $buildToolPaths) {
    if (-not (Test-Path -LiteralPath $required)) {
        throw "Required SDK file not found: $required"
    }
}

& (Join-Path $PSScriptRoot 'install_into_sdk.ps1') -SdkRoot $SdkRoot

& $pythonExe $configTool --sdk-source $sdkSource --config $configFile `
    SAMPLE_ENABLE=y SAMPLE_SUPPORT_SLE_AB=n SAMPLE_SUPPORT_SLE_CARD=y `
    SLE_CARD_FIRMWARE_VERSION=0x00010100 SLE_CARD_STORE_RAM=y
if ($LASTEXITCODE -ne 0) { throw 'Unable to select the Card C SDK configuration.' }

$env:Path = (($buildToolPaths + @($env:Path)) -join ';')
Push-Location $sdkSource
try {
    & $pythonExe 'build.py' ws63-liteos-app -c -ninja
    if ($LASTEXITCODE -ne 0) { throw 'Card C SDK build failed.' }
} finally {
    Pop-Location
}

if (-not (Test-Path -LiteralPath $packageFile)) {
    throw "Firmware package not generated: $packageFile"
}
New-Item -ItemType Directory -Force -Path $outputs,$configs | Out-Null
$outputPackage = Join-Path $outputs 'card_c_h3863_ram_all.fwpkg'
Copy-Item -LiteralPath $packageFile -Destination $outputPackage -Force
Copy-Item -LiteralPath $configFile `
    -Destination (Join-Path $configs 'ws63_liteos_app_card_c_ram.config') -Force

& (Join-Path $PSScriptRoot 'rebuild_source_archive.ps1')

$hashFile = Join-Path $outputs 'SHA256SUMS.txt'
$hashNames = @(
    'detector_a_h3863_all.fwpkg',
    'detector_b_h3863_all.fwpkg',
    'card_c_h3863_ram_all.fwpkg',
    'SLE_AB_H3863_source.zip'
)
$hashLines = foreach ($name in $hashNames) {
    $path = Join-Path $outputs $name
    if (Test-Path -LiteralPath $path) {
        "{0}  {1}" -f (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash,$name
    }
}
Set-Content -LiteralPath $hashFile -Value $hashLines -Encoding ascii

Write-Host "Card C RAM bring-up firmware: $outputPackage"
$hashLines | ForEach-Object { Write-Host $_ }

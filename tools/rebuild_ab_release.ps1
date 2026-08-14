param(
    [Parameter(Mandatory = $true)]
    [string]$SdkRoot,

    [ValidateSet('A', 'B')]
    [string[]]$Roles = @('A', 'B')
)

$ErrorActionPreference = 'Stop'
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkSource = Join-Path $SdkRoot 'src'
if (Test-Path -LiteralPath (Join-Path $SdkRoot 'build.py')) {
    $sdkSource = $SdkRoot
}
$sdkSource = [System.IO.Path]::GetFullPath($sdkSource)
$buildFile = Join-Path $sdkSource 'build.py'
$configTool = Join-Path $PSScriptRoot 'set_sdk_kconfig.py'
$configFile = Join-Path $sdkSource 'build\config\target_config\ws63\menuconfig\acore\ws63_liteos_app.config'
$packageFile = Join-Path $sdkSource 'output\ws63\fwpkg\ws63-liteos-app\ws63-liteos-app_all.fwpkg'
$outputs = Join-Path $repoRoot 'outputs'
$configs = Join-Path $repoRoot 'firmware\h3863\configs'
$pythonExe = 'D:\hispark\tools\python\python.exe'
$buildToolPaths = @(
    'D:\hispark\tools\Windows\cc_riscv32_musl_win\bin',
    'D:\hispark\tools\python\Scripts',
    'D:\hispark\tools\python\Lib\site-packages\cmake\data\bin',
    'D:\hispark\tools\Windows\ninja'
)

foreach ($required in @($buildFile, $configTool, $configFile, $pythonExe) + $buildToolPaths) {
    if (-not (Test-Path -LiteralPath $required)) {
        throw "Required SDK file not found: $required"
    }
}

function Invoke-Native {
    param([Parameter(Mandatory = $true)][scriptblock]$Command)
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "Native command failed with exit code $LASTEXITCODE"
    }
}

function Set-AbRole {
    param([Parameter(Mandatory = $true)][ValidateSet('A', 'B')][string]$Role)
    $roleSymbol = "SLE_AB_ROLE_$Role=y"
    Invoke-Native {
        & $pythonExe $configTool --sdk-source $sdkSource --config $configFile `
            SAMPLE_ENABLE=y SAMPLE_SUPPORT_SLE_AB=y SAMPLE_SUPPORT_SLE_CARD=n $roleSymbol
    }
    $expected = "CONFIG_SLE_AB_ROLE_$Role=y"
    if (-not (Select-String -LiteralPath $configFile -SimpleMatch $expected -Quiet)) {
        throw "Kconfig did not select role $Role"
    }
    if (-not (Select-String -LiteralPath $configFile -SimpleMatch '# CONFIG_SAMPLE_SUPPORT_SLE_CARD is not set' -Quiet)) {
        throw "A/B release must not include the independent Card C application"
    }
}

function Build-And-Collect {
    param([Parameter(Mandatory = $true)][ValidateSet('A', 'B')][string]$Role)
    Set-AbRole -Role $Role
    Push-Location $sdkSource
    try {
        Invoke-Native { & $pythonExe 'build.py' ws63-liteos-app -c -ninja }
    } finally {
        Pop-Location
    }
    if (-not (Test-Path -LiteralPath $packageFile)) {
        throw "Firmware package not generated: $packageFile"
    }
    $mapFiles = Get-ChildItem -LiteralPath (Join-Path $sdkSource 'output\ws63') -Recurse -File `
        -Include '*.map','*.nm' -ErrorAction SilentlyContinue
    foreach ($mapFile in $mapFiles) {
        if (Select-String -LiteralPath $mapFile.FullName -Pattern 'sle_card_entry|h3863_sle_card' -Quiet) {
            throw "A/B release unexpectedly contains Card C symbols: $($mapFile.FullName)"
        }
    }
    $lowerRole = $Role.ToLowerInvariant()
    Copy-Item -LiteralPath $packageFile `
        -Destination (Join-Path $outputs "detector_${lowerRole}_h3863_all.fwpkg") -Force
    Copy-Item -LiteralPath $configFile `
        -Destination (Join-Path $configs "ws63_liteos_app_detector_${lowerRole}.config") -Force
}

New-Item -ItemType Directory -Force -Path $outputs | Out-Null
New-Item -ItemType Directory -Force -Path $configs | Out-Null
$env:Path = (($buildToolPaths + @($env:Path)) -join ';')

& (Join-Path $PSScriptRoot 'install_into_sdk.ps1') -SdkRoot $SdkRoot
foreach ($role in $Roles) {
    Build-And-Collect -Role $role
}

$sourceArchive = Join-Path $outputs 'SLE_AB_H3863_source.zip'
& (Join-Path $PSScriptRoot 'rebuild_source_archive.ps1') -OutputPath $sourceArchive

$hashTargets = @(
    'detector_a_h3863_all.fwpkg',
    'detector_b_h3863_all.fwpkg'
)
if (Test-Path -LiteralPath (Join-Path $outputs 'card_c_h3863_ram_all.fwpkg')) {
    $hashTargets += 'card_c_h3863_ram_all.fwpkg'
}
$hashTargets += 'SLE_AB_H3863_source.zip'
$hashLines = foreach ($name in $hashTargets) {
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $outputs $name)).Hash
    "$hash  $name"
}
Set-Content -LiteralPath (Join-Path $outputs 'SHA256SUMS.txt') -Value $hashLines -Encoding ascii

Write-Host "A/B release rebuild completed for role(s): $($Roles -join ', ')"
$hashLines | ForEach-Object { Write-Host $_ }

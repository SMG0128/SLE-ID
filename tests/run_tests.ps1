$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$output = Join-Path $PSScriptRoot 'test_ab.exe'
$sources = @(
    (Join-Path $PSScriptRoot 'test_ab.c'),
    (Join-Path $root 'common\src\ab_protocol.c'),
    (Join-Path $root 'common\src\ab_messages.c'),
    (Join-Path $root 'detector_a\src\passage_fsm.c'),
    (Join-Path $root 'detector_a\src\detector_a_core.c'),
    (Join-Path $root 'detector_b\src\policy_engine.c'),
    (Join-Path $root 'detector_b\src\detector_b_core.c')
)
$includes = @(
    "-I$(Join-Path $root 'common\include')",
    "-I$(Join-Path $root 'detector_a\include')",
    "-I$(Join-Path $root 'detector_b\include')"
)
& gcc -std=c99 -Wall -Wextra -Werror @includes @sources -o $output
if ($LASTEXITCODE -ne 0) { throw 'Compilation failed.' }
& $output
if ($LASTEXITCODE -ne 0) { throw 'Tests failed.' }

$cardOutput = Join-Path $PSScriptRoot 'test_card.exe'
$cardSources = @(
    (Join-Path $PSScriptRoot 'test_card.c'),
    (Join-Path $root 'card_ws63\src\credential_store.c'),
    (Join-Path $root 'card_ws63\src\card_service.c')
)
$cardIncludes = @(
    "-I$(Join-Path $root 'card_ws63\include')",
    "-I$(Join-Path $root 'common\include')"
)
& gcc -std=c99 -Wall -Wextra -Werror @cardIncludes @cardSources -o $cardOutput
if ($LASTEXITCODE -ne 0) { throw 'Card test compilation failed.' }
& $cardOutput
if ($LASTEXITCODE -ne 0) { throw 'Card tests failed.' }

$authOutput = Join-Path $PSScriptRoot 'test_card_auth.exe'
$authSources = @(
    (Join-Path $PSScriptRoot 'test_card_auth.c'),
    (Join-Path $root 'card_ws63\src\credential_store.c'),
    (Join-Path $root 'card_ws63\src\card_crypto.c'),
    (Join-Path $root 'card_ws63\src\card_auth.c')
)
& gcc -std=c99 -Wall -Wextra -Werror @cardIncludes @authSources -o $authOutput
if ($LASTEXITCODE -ne 0) { throw 'Card authentication test compilation failed.' }
& $authOutput
if ($LASTEXITCODE -ne 0) { throw 'Card authentication tests failed.' }

$threePartyOutput = Join-Path $PSScriptRoot 'test_three_party_auth.exe'
$threePartySources = @(
    (Join-Path $PSScriptRoot 'test_three_party_auth.c'),
    (Join-Path $root 'common\src\ab_messages.c'),
    (Join-Path $root 'card_ws63\src\credential_store.c'),
    (Join-Path $root 'card_ws63\src\card_crypto.c'),
    (Join-Path $root 'card_ws63\src\card_auth.c'),
    (Join-Path $root 'detector_b\src\detector_b_auth.c')
)
$threePartyIncludes = @(
    "-I$(Join-Path $root 'common\include')",
    "-I$(Join-Path $root 'card_ws63\include')",
    "-I$(Join-Path $root 'detector_b\include')"
)
& gcc -std=c99 -Wall -Wextra -Werror @threePartyIncludes @threePartySources -o $threePartyOutput
if ($LASTEXITCODE -ne 0) { throw 'Three-party authentication test compilation failed.' }
& $threePartyOutput
if ($LASTEXITCODE -ne 0) { throw 'Three-party authentication tests failed.' }

$relayOutput = Join-Path $PSScriptRoot 'test_auth_relay.exe'
$relaySources = @(
    (Join-Path $PSScriptRoot 'test_auth_relay.c'),
    (Join-Path $root 'common\src\ab_protocol.c'),
    (Join-Path $root 'common\src\ab_messages.c'),
    (Join-Path $root 'detector_a\src\detector_a_auth_relay.c')
)
$relayIncludes = @(
    "-I$(Join-Path $root 'common\include')",
    "-I$(Join-Path $root 'detector_a\include')"
)
& gcc -std=c99 -Wall -Wextra -Werror @relayIncludes @relaySources -o $relayOutput
if ($LASTEXITCODE -ne 0) { throw 'Detector A authentication relay test compilation failed.' }
& $relayOutput
if ($LASTEXITCODE -ne 0) { throw 'Detector A authentication relay tests failed.' }

$gatewayOutput = Join-Path $PSScriptRoot 'test_gateway.exe'
$gatewaySources = @(
    (Join-Path $PSScriptRoot 'test_gateway.c'),
    (Join-Path $root 'common\src\ab_protocol.c'),
    (Join-Path $root 'common\src\ab_messages.c'),
    (Join-Path $root 'detector_b\src\detector_b_gateway.c')
)
$gatewayIncludes = @(
    "-I$(Join-Path $root 'common\include')",
    "-I$(Join-Path $root 'detector_b\include')"
)
& gcc -std=c99 -Wall -Wextra -Werror @gatewayIncludes @gatewaySources -o $gatewayOutput
if ($LASTEXITCODE -ne 0) { throw 'Detector B gateway test compilation failed.' }
& $gatewayOutput
if ($LASTEXITCODE -ne 0) { throw 'Detector B gateway tests failed.' }

$cardTool = Join-Path $root 'tools\card_serial_tool.ps1'
& $cardTool -Action Info -DryRun | Out-Null
& $cardTool -Action List -DryRun | Out-Null
& $cardTool -Action Provision -DryRun -PermissionId 1 -OrganizationId 100 `
    -Scope Checkpoint -ScopeId 7 -CredentialVersion 1 -KeyVersion 1 `
    -KeyHex ('11' * 32) | Out-Null
& $cardTool -Action State -DryRun -PermissionId 1 -State Frozen | Out-Null
Write-Host 'All Card serial provisioning tool dry-run tests passed.'

$smokeTool = Join-Path $root 'tools\ab_security_smoke.ps1'
[void][scriptblock]::Create((Get-Content -LiteralPath $smokeTool -Raw))
Write-Host 'A/B security smoke script syntax test passed.'

$adminCompatTool = Join-Path $root 'tools\admin_gateway_compat.ps1'
[void][scriptblock]::Create((Get-Content -LiteralPath $adminCompatTool -Raw))
$adminCompatResult = & $adminCompatTool -Action SelfTest | ConvertFrom-Json
if ($adminCompatResult.status -ne 'PASS' -or
    $adminCompatResult.heartbeatIntervalMs -ne 1000) {
    throw 'Admin gateway compatibility self-test failed.'
}
Write-Host 'Admin gateway compatibility mapping self-test passed.'

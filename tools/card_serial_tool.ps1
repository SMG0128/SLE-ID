[CmdletBinding()]
param(
    [ValidateSet('Info', 'List', 'Provision', 'State')]
    [string]$Action = 'Info',
    [string]$Port,
    [int]$BaudRate = 115200,
    [switch]$DryRun,
    [switch]$ShowFrames,
    [uint32]$PermissionId = 0,
    [uint32]$OrganizationId = 0,
    [ValidateSet('Global', 'Organization', 'Site', 'Checkpoint')]
    [string]$Scope = 'Organization',
    [uint32]$ScopeId = 0,
    [uint32]$ValidFrom = 0,
    [uint32]$ValidTo = 0,
    [uint32]$PolicyFlags = 0,
    [uint32]$UsageLimit = [uint32]::MaxValue,
    [uint32]$UsageCount = 0,
    [uint32]$CredentialVersion = 1,
    [uint32]$KeyVersion = 1,
    [string]$KeyHex,
    [ValidateSet('Active', 'Frozen', 'Lost', 'Expired', 'Revoked')]
    [string]$State = 'Active',
    [uint32]$HostId = 0x48000001,
    [int]$TimeoutMs = 4000
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:MessageId = [uint32]1
$randomBytes = New-Object byte[] 4
$random = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$random.GetBytes($randomBytes)
$script:BootId = [BitConverter]::ToUInt32($randomBytes, 0)
if ($script:BootId -eq 0) { $script:BootId = 1 }
$random.Dispose()

function Add-U16Le {
    param([System.Collections.Generic.List[byte]]$Bytes, [uint16]$Value)
    $Bytes.Add([byte]($Value -band 0xff))
    $Bytes.Add([byte](($Value -shr 8) -band 0xff))
}

function Add-U32Le {
    param([System.Collections.Generic.List[byte]]$Bytes, [uint32]$Value)
    0..3 | ForEach-Object { $Bytes.Add([byte](($Value -shr (8 * $_)) -band 0xff)) }
}

function Read-U16Le {
    param([byte[]]$Bytes, [int]$Offset)
    return [uint16]([uint16]$Bytes[$Offset] -bor ([uint16]$Bytes[$Offset + 1] -shl 8))
}

function Read-U32Le {
    param([byte[]]$Bytes, [int]$Offset)
    return [uint32]([uint32]$Bytes[$Offset] -bor
        ([uint32]$Bytes[$Offset + 1] -shl 8) -bor
        ([uint32]$Bytes[$Offset + 2] -shl 16) -bor
        ([uint32]$Bytes[$Offset + 3] -shl 24))
}

function Get-Crc16Ccitt {
    param([byte[]]$Bytes)
    [uint16]$crc = 0xffff
    foreach ($value in $Bytes) {
        $crc = [uint16]($crc -bxor ([uint16]$value -shl 8))
        for ($bit = 0; $bit -lt 8; $bit++) {
            if (($crc -band 0x8000) -ne 0) {
                $crc = [uint16]((($crc -shl 1) -bxor 0x1021) -band 0xffff)
            } else {
                $crc = [uint16](($crc -shl 1) -band 0xffff)
            }
        }
    }
    return $crc
}

function Get-Crc32 {
    param([byte[]]$Bytes)
    [uint32]$crc = [uint32]::MaxValue
    [uint32]$polynomial = [Convert]::ToUInt32('EDB88320', 16)
    foreach ($value in $Bytes) {
        $crc = [uint32]($crc -bxor [uint32]$value)
        for ($bit = 0; $bit -lt 8; $bit++) {
            if (($crc -band 1) -ne 0) {
                $crc = [uint32](($crc -shr 1) -bxor $polynomial)
            } else {
                $crc = [uint32]($crc -shr 1)
            }
        }
    }
    return [uint32]($crc -bxor [uint32]::MaxValue)
}

function ConvertTo-Hex {
    param([byte[]]$Bytes)
    return -join ($Bytes | ForEach-Object { $_.ToString('x2') })
}

function ConvertFrom-Hex {
    param([string]$Text)
    if (($Text.Length -band 1) -ne 0 -or $Text -notmatch '^[0-9a-fA-F]+$') {
        throw 'Invalid hexadecimal protocol frame.'
    }
    $bytes = New-Object byte[] ($Text.Length / 2)
    for ($i = 0; $i -lt $bytes.Length; $i++) {
        $bytes[$i] = [Convert]::ToByte($Text.Substring($i * 2, 2), 16)
    }
    return $bytes
}

function New-ProtocolFrame {
    param([byte]$Type, [byte[]]$Payload = @())
    if ($Payload.Length -gt 64) { throw 'Protocol payload exceeds 64 bytes.' }
    $bytes = [System.Collections.Generic.List[byte]]::new()
    $bytes.Add(0x53); $bytes.Add(0x4c); $bytes.Add(2); $bytes.Add($Type)
    $bytes.Add(1); $bytes.Add(4) # ACK_REQUIRED, HOST
    Add-U32Le $bytes $HostId
    Add-U32Le $bytes $script:BootId
    Add-U32Le $bytes $script:MessageId
    $script:MessageId++
    Add-U16Le $bytes ([uint16]$Payload.Length)
    $bytes.AddRange($Payload)
    $crcInput = $bytes.GetRange(2, $bytes.Count - 2).ToArray()
    Add-U16Le $bytes (Get-Crc16Ccitt $crcInput)
    return $bytes.ToArray()
}

function Read-ProtocolFrame {
    param([byte[]]$Bytes)
    if ($Bytes.Length -lt 22 -or $Bytes[0] -ne 0x53 -or $Bytes[1] -ne 0x4c -or
        $Bytes[2] -ne 2) { throw 'Malformed Protocol V2 response.' }
    $payloadLength = Read-U16Le $Bytes 18
    if ($Bytes.Length -ne 22 + $payloadLength) { throw 'Protocol response length mismatch.' }
    $crcInput = $Bytes[2..(19 + $payloadLength)]
    $expected = Read-U16Le $Bytes (20 + $payloadLength)
    if ((Get-Crc16Ccitt $crcInput) -ne $expected) { throw 'Protocol response CRC16 mismatch.' }
    [pscustomobject]@{
        Type = $Bytes[3]
        Flags = $Bytes[4]
        SourceRole = $Bytes[5]
        SourceId = Read-U32Le $Bytes 6
        Payload = if ($payloadLength -eq 0) { [byte[]]@() } else { [byte[]]$Bytes[20..(19 + $payloadLength)] }
    }
}

function New-RequestId {
    $bytes = New-Object byte[] 4
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $rng.GetBytes($bytes)
    $rng.Dispose()
    $value = [BitConverter]::ToUInt32($bytes, 0)
    if ($value -eq 0) { return [uint32]1 }
    return $value
}

function Write-DryRunFrame {
    param([string]$Label, [byte[]]$Frame)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $digest = ConvertTo-Hex ($sha.ComputeHash($Frame))
    $sha.Dispose()
    Write-Host ("DRY-RUN {0}: bytes={1} sha256={2}" -f $Label, $Frame.Length, $digest)
    if ($ShowFrames) {
        Write-Warning 'The following frame may contain credential key material.'
        Write-Host ('proto ' + (ConvertTo-Hex $Frame))
    }
}

function Read-SerialProtocolFrame {
    param([System.IO.Ports.SerialPort]$Serial)
    while ($true) {
        try { $line = $Serial.ReadLine().Trim() }
        catch [System.TimeoutException] { throw "Timed out waiting for Card response on $Port." }
        if ($line -match '^\[C\]\[PROTO-ERROR\]\s+(.+)$') { throw "Card rejected frame: $($Matches[1])" }
        if ($line -match '^\[C\]\[PROTO\]\s+([0-9a-fA-F]+)$') {
            return Read-ProtocolFrame (ConvertFrom-Hex $Matches[1])
        }
    }
}

function Send-ProtocolFrame {
    param([System.IO.Ports.SerialPort]$Serial, [string]$Label, [byte[]]$Frame)
    if ($DryRun) {
        Write-DryRunFrame $Label $Frame
        return $null
    }
    $Serial.WriteLine('proto ' + (ConvertTo-Hex $Frame))
    return Read-SerialProtocolFrame $Serial
}

function Assert-ResultOk {
    param($Response, [uint32]$RequestId, [string]$Stage)
    if ($null -eq $Response) { return }
    if ($Response.Type -ne 0x44 -or $Response.Payload.Length -ne 18) {
        throw "$Stage returned an unexpected message type or length."
    }
    $actualRequest = Read-U32Le $Response.Payload 0
    $status = $Response.Payload[5]
    if ($actualRequest -ne $RequestId) { throw "$Stage requestId mismatch." }
    if ($status -ne 0) { throw "$Stage failed with Card service status $status." }
}

function New-CredentialBytes {
    if ($PermissionId -eq 0 -or $OrganizationId -eq 0) {
        throw 'Provision requires non-zero -PermissionId and -OrganizationId.'
    }
    if ($CredentialVersion -eq 0 -or $KeyVersion -eq 0) {
        throw 'Provision requires non-zero credential and key versions.'
    }
    if ($UsageCount -gt $UsageLimit) { throw 'UsageCount cannot exceed UsageLimit.' }
    if ($ValidTo -ne 0 -and $ValidFrom -gt $ValidTo) { throw 'ValidFrom cannot exceed ValidTo.' }
    if ($KeyHex -notmatch '^[0-9a-fA-F]{64}$') { throw 'Provision requires exactly 32 key bytes as 64 hex characters.' }
    $scopeValue = @{ Global = 0; Organization = 1; Site = 2; Checkpoint = 3 }[$Scope]
    $bytes = [System.Collections.Generic.List[byte]]::new()
    Add-U32Le $bytes $PermissionId
    Add-U32Le $bytes $OrganizationId
    $bytes.Add([byte]$scopeValue)
    Add-U32Le $bytes $ScopeId
    Add-U32Le $bytes $ValidFrom
    Add-U32Le $bytes $ValidTo
    Add-U32Le $bytes $PolicyFlags
    Add-U32Le $bytes $UsageLimit
    Add-U32Le $bytes $UsageCount
    Add-U32Le $bytes $CredentialVersion
    Add-U32Le $bytes $KeyVersion
    $bytes.AddRange([byte[]](ConvertFrom-Hex $KeyHex))
    $bytes.Add(0) # ACTIVE on provision
    $bytes.AddRange([byte[]](0, 0, 0, 0))
    if ($bytes.Count -ne 78) { throw 'Internal credential encoding error.' }
    return $bytes.ToArray()
}

$serial = $null
try {
    if (-not $DryRun) {
        if ([string]::IsNullOrWhiteSpace($Port)) { throw '-Port is required unless -DryRun is used.' }
        $serial = [System.IO.Ports.SerialPort]::new(
            $Port, $BaudRate, [System.IO.Ports.Parity]::None, 8,
            [System.IO.Ports.StopBits]::One)
        $serial.NewLine = "`n"
        $serial.ReadTimeout = $TimeoutMs
        $serial.WriteTimeout = $TimeoutMs
        $serial.DtrEnable = $false
        $serial.RtsEnable = $false
        $serial.Open()
        Start-Sleep -Milliseconds 150
        $serial.DiscardInBuffer()
    }

    switch ($Action) {
        'Info' {
            $response = Send-ProtocolFrame $serial 'CARD_INFO' (New-ProtocolFrame 0x40)
            if ($null -ne $response) {
                if ($response.Type -ne 0x40 -or $response.Payload.Length -ne 16) { throw 'Invalid CARD_INFO response.' }
                [pscustomobject]@{
                    Protocol = $response.Payload[0]
                    Capacity = $response.Payload[1]
                    CredentialCount = $response.Payload[2]
                    CardId = ('0x{0:x8}' -f (Read-U32Le $response.Payload 4))
                    FirmwareVersion = ('0x{0:x8}' -f (Read-U32Le $response.Payload 8))
                    Generation = Read-U32Le $response.Payload 12
                }
            }
        }
        'List' {
            $requestId = New-RequestId
            $payload = [System.Collections.Generic.List[byte]]::new(); Add-U32Le $payload $requestId
            $frame = New-ProtocolFrame 0x45 $payload.ToArray()
            if ($DryRun) { Write-DryRunFrame 'CREDENTIAL_LIST' $frame; break }
            $serial.WriteLine('proto ' + (ConvertTo-Hex $frame))
            while ($true) {
                $response = Read-SerialProtocolFrame $serial
                if ($response.Type -eq 0x44) { Assert-ResultOk $response $requestId 'LIST'; break }
                if ($response.Type -ne 0x45 -or $response.Payload.Length -ne 48) { throw 'Invalid CREDENTIAL_LIST item.' }
                [pscustomobject]@{
                    Index = $response.Payload[4]
                    Total = $response.Payload[5]
                    PermissionId = Read-U32Le $response.Payload 6
                    OrganizationId = Read-U32Le $response.Payload 10
                    Scope = @('Global', 'Organization', 'Site', 'Checkpoint')[$response.Payload[14]]
                    ScopeId = Read-U32Le $response.Payload 15
                    ValidFrom = Read-U32Le $response.Payload 19
                    ValidTo = Read-U32Le $response.Payload 23
                    PolicyFlags = ('0x{0:x8}' -f (Read-U32Le $response.Payload 27))
                    UsageLimit = Read-U32Le $response.Payload 31
                    UsageCount = Read-U32Le $response.Payload 35
                    CredentialVersion = Read-U32Le $response.Payload 39
                    KeyVersion = Read-U32Le $response.Payload 43
                    State = @('Active', 'Frozen', 'Lost', 'Expired', 'Revoked')[$response.Payload[47]]
                }
            }
        }
        'Provision' {
            $credential = New-CredentialBytes
            $requestId = New-RequestId
            $begin = [System.Collections.Generic.List[byte]]::new()
            Add-U32Le $begin $requestId
            Add-U16Le $begin ([uint16]$credential.Length)
            Add-U32Le $begin (Get-Crc32 $credential)
            $response = Send-ProtocolFrame $serial 'CREDENTIAL_BEGIN' (New-ProtocolFrame 0x41 $begin.ToArray())
            Assert-ResultOk $response $requestId 'BEGIN'
            for ($offset = 0; $offset -lt $credential.Length; $offset += 48) {
                $length = [Math]::Min(48, $credential.Length - $offset)
                $chunk = [System.Collections.Generic.List[byte]]::new()
                Add-U32Le $chunk $requestId
                Add-U16Le $chunk ([uint16]$offset)
                $chunk.Add([byte]$length)
                $chunk.AddRange([byte[]]$credential[$offset..($offset + $length - 1)])
                $response = Send-ProtocolFrame $serial "CREDENTIAL_CHUNK@$offset" (New-ProtocolFrame 0x42 $chunk.ToArray())
                Assert-ResultOk $response $requestId "CHUNK@$offset"
            }
            $commit = [System.Collections.Generic.List[byte]]::new(); Add-U32Le $commit $requestId
            $response = Send-ProtocolFrame $serial 'CREDENTIAL_COMMIT' (New-ProtocolFrame 0x43 $commit.ToArray())
            Assert-ResultOk $response $requestId 'COMMIT'
            if (-not $DryRun) {
                [pscustomobject]@{
                    Result = 'Provisioned'
                    RequestId = $requestId
                    PermissionId = Read-U32Le $response.Payload 6
                    CredentialVersion = Read-U32Le $response.Payload 10
                    Generation = Read-U32Le $response.Payload 14
                }
            }
        }
        'State' {
            if ($PermissionId -eq 0) { throw 'State requires non-zero -PermissionId.' }
            $requestId = New-RequestId
            $stateValue = @{ Active = 0; Frozen = 1; Lost = 2; Expired = 3; Revoked = 4 }[$State]
            $payload = [System.Collections.Generic.List[byte]]::new()
            Add-U32Le $payload $requestId
            Add-U32Le $payload $PermissionId
            $payload.Add([byte]$stateValue)
            $response = Send-ProtocolFrame $serial 'CARD_STATE_SET' (New-ProtocolFrame 0x46 $payload.ToArray())
            Assert-ResultOk $response $requestId 'STATE_SET'
            if (-not $DryRun) {
                [pscustomobject]@{
                    Result = 'StateUpdated'
                    PermissionId = Read-U32Le $response.Payload 6
                    CredentialVersion = Read-U32Le $response.Payload 10
                    Generation = Read-U32Le $response.Payload 14
                    State = $State
                }
            }
        }
    }
} finally {
    if ($null -ne $serial) {
        if ($serial.IsOpen) { $serial.Close() }
        $serial.Dispose()
    }
}

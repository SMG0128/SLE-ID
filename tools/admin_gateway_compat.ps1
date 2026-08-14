[CmdletBinding()]
param(
    [ValidateSet('SelfTest', 'Listen', 'Policy', 'Confirm')]
    [string]$Action = 'SelfTest',
    [string]$Port,
    [int]$BaudRate = 115200,
    [int]$TimeoutMs = 5000,
    [uint32]$PermissionId = 0,
    [uint32]$OrganizationId = 0,
    [uint32]$PolicyVersion = 0,
    [switch]$AllowExecute,
    [switch]$ForceConfirm,
    [switch]$UserConfirm,
    [switch]$OfflineAllowed,
    [switch]$AlertOnDenial,
    [uint32]$RequestId = 0,
    [uint32]$EventId = 0,
    [ValidateSet('Approve', 'Reject')]
    [string]$ConfirmResult = 'Approve',
    [uint32]$HostId = 0x48000001
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

$script:ProtocolVersion = [byte]2
$script:HostRole = [byte]4
$script:MessageId = [uint32]1
$script:TextOnline = -join ([char[]]@(0x5728, 0x7ebf))
$script:TextSuccess = -join ([char[]]@(0x6210, 0x529f))
$script:TextFailure = -join ([char[]]@(0x5931, 0x8d25))
$script:TextPending = -join ([char[]]@(0x5f85, 0x5b9a))
$bootBytes = New-Object byte[] 4
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$rng.GetBytes($bootBytes)
$rng.Dispose()
$script:BootId = [BitConverter]::ToUInt32($bootBytes, 0)
if ($script:BootId -eq 0) { $script:BootId = 1 }

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
    return [uint16]([uint16]$Bytes[$Offset] -bor
        ([uint16]$Bytes[$Offset + 1] -shl 8))
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

function New-RequestId {
    $bytes = New-Object byte[] 4
    $random = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $random.GetBytes($bytes)
    $random.Dispose()
    $value = [BitConverter]::ToUInt32($bytes, 0)
    return [uint32]$(if ($value -eq 0) { 1 } else { $value })
}

function New-ProtocolFrame {
    param(
        [byte]$Type,
        [byte[]]$Payload = @(),
        [byte]$SourceRole = $script:HostRole,
        [uint32]$SourceId = $HostId,
        [uint32]$BootId = $script:BootId,
        [uint32]$MessageId = 0,
        [byte]$Flags = 0
    )
    if ($Payload.Length -gt 64) { throw 'Protocol payload exceeds 64 bytes.' }
    if ($MessageId -eq 0) {
        $MessageId = $script:MessageId
        $script:MessageId++
    }
    $bytes = [System.Collections.Generic.List[byte]]::new()
    $bytes.Add(0x53); $bytes.Add(0x4c); $bytes.Add($script:ProtocolVersion)
    $bytes.Add($Type); $bytes.Add($Flags); $bytes.Add($SourceRole)
    Add-U32Le $bytes $SourceId
    Add-U32Le $bytes $BootId
    Add-U32Le $bytes $MessageId
    Add-U16Le $bytes ([uint16]$Payload.Length)
    $bytes.AddRange($Payload)
    Add-U16Le $bytes (Get-Crc16Ccitt $bytes.GetRange(2, $bytes.Count - 2).ToArray())
    return $bytes.ToArray()
}

function ConvertTo-ProtocolFrame {
    param([byte[]]$Bytes)
    if ($Bytes.Length -lt 22 -or $Bytes[0] -ne 0x53 -or $Bytes[1] -ne 0x4c -or
        $Bytes[2] -ne $script:ProtocolVersion) { throw 'Malformed Protocol V2 frame.' }
    $payloadLength = Read-U16Le $Bytes 18
    if ($payloadLength -gt 64 -or $Bytes.Length -ne 22 + $payloadLength) {
        throw 'Protocol V2 length mismatch.'
    }
    $expected = Read-U16Le $Bytes (20 + $payloadLength)
    $actual = Get-Crc16Ccitt $Bytes[2..(19 + $payloadLength)]
    if ($actual -ne $expected) { throw 'Protocol V2 CRC mismatch.' }
    return [pscustomobject]@{
        Type = $Bytes[3]
        Flags = $Bytes[4]
        SourceRole = $Bytes[5]
        SourceId = Read-U32Le $Bytes 6
        BootId = Read-U32Le $Bytes 10
        MessageId = Read-U32Le $Bytes 14
        Payload = if ($payloadLength -eq 0) {
            [byte[]]@()
        } else {
            [byte[]]$Bytes[20..(19 + $payloadLength)]
        }
    }
}

function Read-BufferedFrames {
    param([System.Collections.Generic.List[byte]]$Buffer)
    $frames = [System.Collections.Generic.List[object]]::new()
    while ($Buffer.Count -ge 2) {
        $magic = -1
        for ($i = 0; $i + 1 -lt $Buffer.Count; $i++) {
            if ($Buffer[$i] -eq 0x53 -and $Buffer[$i + 1] -eq 0x4c) {
                $magic = $i
                break
            }
        }
        if ($magic -lt 0) {
            $keepS = $Buffer[$Buffer.Count - 1] -eq 0x53
            $Buffer.Clear()
            if ($keepS) { $Buffer.Add(0x53) }
            break
        }
        if ($magic -gt 0) { $Buffer.RemoveRange(0, $magic) }
        if ($Buffer.Count -lt 20) { break }
        if ($Buffer[2] -ne $script:ProtocolVersion -or $Buffer[5] -gt 4) {
            $Buffer.RemoveAt(0)
            continue
        }
        $header = $Buffer.GetRange(0, 20).ToArray()
        $payloadLength = Read-U16Le $header 18
        if ($payloadLength -gt 64) {
            $Buffer.RemoveAt(0)
            continue
        }
        $total = 22 + $payloadLength
        if ($Buffer.Count -lt $total) { break }
        $candidate = $Buffer.GetRange(0, $total).ToArray()
        try {
            $frames.Add((ConvertTo-ProtocolFrame $candidate))
            $Buffer.RemoveRange(0, $total)
        } catch {
            $Buffer.RemoveAt(0)
        }
    }
    return $frames.ToArray()
}

function Format-DeviceId {
    param([uint32]$SourceId)
    return ('DEV-{0:X8}' -f $SourceId)
}

function Format-CardId {
    param([uint32]$CardId)
    return ('CARD-{0:X8}' -f $CardId)
}

function Format-FirmwareVersion {
    param([uint32]$Version)
    return ('v{0}.{1}.{2}' -f (($Version -shr 16) -band 0xff),
        (($Version -shr 8) -band 0xff), ($Version -band 0xff))
}

function Get-EventKey {
    param([uint32]$SourceId, [uint32]$BootId, [uint32]$EventId)
    return ('EV-{0:X8}-{1:X8}-{2:D10}' -f $SourceId, $BootId, $EventId)
}

function Get-ActionName {
    param([byte]$Value)
    return @('record', 'wait_confirm', 'execute', 'deny', 'alert')[$Value]
}

function Get-ConfirmName {
    param([byte]$Value)
    return @('not_required', 'pending', 'approved', 'rejected', 'timeout', 'offline')[$Value]
}

function Get-ExecutionName {
    param([byte]$Value)
    return @('not_requested', 'pending', 'success', 'failed')[$Value]
}

function Get-ReasonName {
    param([byte]$Value)
    $names = @('none', 'no_permission', 'out_of_scope', 'not_yet_valid', 'expired',
        'usage_exhausted', 'frozen', 'lost', 'revoked', 'key_version_mismatch',
        'key_failed', 'replay_suspected', 'policy_stale', 'backend_offline',
        'confirm_rejected', 'confirm_timeout', 'confirm_offline', 'execution_failed',
        'link_lost', 'duplicate_event', 'busy', 'stale_request', 'bad_message')
    return $(if ($Value -lt $names.Count) { $names[$Value] } else { "unknown_$Value" })
}

function Get-AlarmMapping {
    param([byte]$Reason, [byte]$Execution)
    if ($Execution -eq 3 -or $Reason -eq 17) { return @('execute_failed', 'high') }
    switch ($Reason) {
        4 { return @('license_expired', 'high') }
        7 { return @('lost_report', 'severe') }
        10 { return @('key_failed', 'severe') }
        11 { return @('suspected_replay', 'severe') }
        { $_ -in 14, 15, 16 } { return @('confirm_rejected', 'high') }
        default { return @('unauthorized', 'normal') }
    }
}

function Convert-EventPayload {
    param([byte[]]$Payload, [bool]$Alert)
    if ($Payload.Length -ne 40) { throw 'EVENT_REPORT/ALERT_REPORT payload must be 40 bytes.' }
    $eventId = Read-U32Le $Payload 0
    $sourceId = Read-U32Le $Payload 4
    $bootId = Read-U32Le $Payload 8
    $cardId = Read-U32Le $Payload 12
    $permissionId = Read-U32Le $Payload 16
    $auth = $Payload[25]
    $action = $Payload[26]
    $confirm = $Payload[27]
    $execution = $Payload[28]
    $reason = $Payload[29]
    $eventKey = Get-EventKey $sourceId $bootId $eventId
    $result = if ($confirm -eq 1) { $script:TextPending } elseif (
        $auth -eq 1 -and $action -notin 3, 4 -and $execution -ne 3) {
        $script:TextSuccess
    } else {
        $script:TextFailure
    }
    $base = [ordered]@{
        kind = $(if ($Alert) { 'alarm' } else { 'event' })
        eventId = $eventKey
        rawEventId = $eventId
        sourceId = ('0x{0:X8}' -f $sourceId)
        bootId = ('0x{0:X8}' -f $bootId)
        device = Format-DeviceId $sourceId
        cardId = Format-CardId $cardId
        permissionId = $permissionId
        result = $result
        status = Get-ActionName $action
        auth = $auth
        action = Get-ActionName $action
        confirm = Get-ConfirmName $confirm
        execution = Get-ExecutionName $execution
        reason = Get-ReasonName $reason
        direction = @('unknown', 'in', 'out')[$Payload[24]]
        distanceCm = Read-U16Le $Payload 30
        confidence = $Payload[32]
        eventState = $Payload[33]
        deviceTimestampMs = Read-U32Le $Payload 20
        decisionTimestampMs = Read-U32Le $Payload 34
        receivedAt = [DateTime]::UtcNow.ToString('o')
    }
    if ($Alert) {
        $mapping = Get-AlarmMapping $reason $execution
        $base.type = $mapping[0]
        $base.level = $mapping[1]
        $base.handleStatus = 'unhandled'
    }
    return [pscustomobject]$base
}

function ConvertTo-AdminMessage {
    param($Frame)
    switch ($Frame.Type) {
        0x30 {
            if ($Frame.Payload.Length -ne 20) { throw 'HEARTBEAT payload must be 20 bytes.' }
            $firmware = Read-U32Le $Frame.Payload 4
            return [pscustomobject][ordered]@{
                kind = 'device'
                id = Format-DeviceId $Frame.SourceId
                sourceId = ('0x{0:X8}' -f $Frame.SourceId)
                bootId = ('0x{0:X8}' -f $Frame.BootId)
                status = $script:TextOnline
                firmware = Format-FirmwareVersion $firmware
                heartbeat = 1
                usbConnected = $true
                policyVersion = ('POL-{0}' -f (Read-U32Le $Frame.Payload 8))
                uptimeSeconds = [math]::Floor((Read-U32Le $Frame.Payload 0) / 1000)
                queueDepth = $Frame.Payload[12]
                hostRecognized = $Frame.Payload[13] -ne 0
                queueOverflows = Read-U16Le $Frame.Payload 14
                frameCount = Read-U32Le $Frame.Payload 16
                receivedAt = [DateTime]::UtcNow.ToString('o')
            }
        }
        0x61 {
            return [pscustomobject][ordered]@{
                kind = 'policy_result'
                requestId = Read-U32Le $Frame.Payload 0
                status = $Frame.Payload[4]
                policyVersion = Read-U32Le $Frame.Payload 5
            }
        }
        0x62 { return Convert-EventPayload $Frame.Payload $false }
        0x63 { return Convert-EventPayload $Frame.Payload $true }
        0x64 {
            if ($Frame.Payload.Length -ne 24) { throw 'CONFIRM_REQUEST payload must be 24 bytes.' }
            return [pscustomobject][ordered]@{
                kind = 'confirm_request'
                requestId = Read-U32Le $Frame.Payload 0
                eventId = Read-U32Le $Frame.Payload 4
                cardId = Format-CardId (Read-U32Le $Frame.Payload 8)
                permissionId = Read-U32Le $Frame.Payload 12
                deviceTimestampMs = Read-U32Le $Frame.Payload 16
                action = Get-ActionName $Frame.Payload[20]
                direction = @('unknown', 'in', 'out')[$Frame.Payload[21]]
            }
        }
        0x66 {
            return [pscustomobject][ordered]@{
                kind = 'command_result'
                requestId = Read-U32Le $Frame.Payload 0
                commandType = $Frame.Payload[4]
                status = $Frame.Payload[5]
                resultValue = Read-U32Le $Frame.Payload 6
            }
        }
        default {
            return [pscustomobject][ordered]@{
                kind = 'protocol_frame'
                type = ('0x{0:X2}' -f $Frame.Type)
                sourceId = ('0x{0:X8}' -f $Frame.SourceId)
                messageId = $Frame.MessageId
                payloadLength = $Frame.Payload.Length
            }
        }
    }
}

function New-AckFrame {
    param([uint32]$AcknowledgedMessageId)
    $payload = [System.Collections.Generic.List[byte]]::new()
    Add-U32Le $payload $AcknowledgedMessageId
    $payload.Add(0)
    return New-ProtocolFrame -Type 0x7f -Payload $payload.ToArray() -Flags 2
}

function New-PolicyFrame {
    if ($PermissionId -eq 0 -or $OrganizationId -eq 0 -or $PolicyVersion -eq 0) {
        throw 'Policy requires non-zero PermissionId, OrganizationId and PolicyVersion.'
    }
    if ($RequestId -eq 0) { $script:PolicyRequestId = New-RequestId } else { $script:PolicyRequestId = $RequestId }
    [uint16]$flags = 0
    if ($AllowExecute) { $flags = $flags -bor 0x0001 }
    if ($ForceConfirm) { $flags = $flags -bor 0x0002 }
    if ($UserConfirm) { $flags = $flags -bor 0x0004 }
    if ($OfflineAllowed) { $flags = $flags -bor 0x0008 }
    if ($AlertOnDenial) { $flags = $flags -bor 0x0010 }
    $payload = [System.Collections.Generic.List[byte]]::new()
    Add-U32Le $payload $script:PolicyRequestId
    Add-U32Le $payload $PermissionId
    Add-U32Le $payload $PolicyVersion
    Add-U32Le $payload $OrganizationId
    Add-U16Le $payload $flags
    Add-U16Le $payload 0
    return New-ProtocolFrame -Type 0x60 -Payload $payload.ToArray()
}

function New-ConfirmFrame {
    if ($RequestId -eq 0 -or $EventId -eq 0) {
        throw 'Confirm requires the RequestId and EventId from CONFIRM_REQUEST.'
    }
    $payload = [System.Collections.Generic.List[byte]]::new()
    Add-U32Le $payload $RequestId
    Add-U32Le $payload $EventId
    $payload.Add($(if ($ConfirmResult -eq 'Approve') { 2 } else { 3 }))
    return New-ProtocolFrame -Type 0x65 -Payload $payload.ToArray()
}

function New-GatewayPort {
    if ([string]::IsNullOrWhiteSpace($Port)) { throw '-Port is required for live actions.' }
    $serial = [System.IO.Ports.SerialPort]::new(
        $Port, $BaudRate, [System.IO.Ports.Parity]::None, 8,
        [System.IO.Ports.StopBits]::One)
    $serial.ReadTimeout = 50
    $serial.WriteTimeout = 1000
    $serial.DtrEnable = $false
    $serial.RtsEnable = $false
    $serial.Open()
    return $serial
}

function Write-Frame {
    param([System.IO.Ports.SerialPort]$Serial, [byte[]]$Frame)
    $Serial.BaseStream.Write($Frame, 0, $Frame.Length)
    $Serial.BaseStream.Flush()
}

function Invoke-LiveReceive {
    param([System.IO.Ports.SerialPort]$Serial, [bool]$Continuous)
    $buffer = [System.Collections.Generic.List[byte]]::new()
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    $heartbeatAt = 0L
    while ($Continuous -or $watch.ElapsedMilliseconds -lt $TimeoutMs) {
        if ($watch.ElapsedMilliseconds -ge $heartbeatAt) {
            Write-Frame $Serial (New-ProtocolFrame -Type 0x30)
            $heartbeatAt = $watch.ElapsedMilliseconds + 1000
        }
        $available = $Serial.BytesToRead
        if ($available -gt 0) {
            $bytes = New-Object byte[] $available
            [void]$Serial.Read($bytes, 0, $bytes.Length)
            $buffer.AddRange($bytes)
            foreach ($frame in (Read-BufferedFrames $buffer)) {
                if (($frame.Flags -band 1) -ne 0) { Write-Frame $Serial (New-AckFrame $frame.MessageId) }
                ConvertTo-AdminMessage $frame | ConvertTo-Json -Depth 8 -Compress
                if (-not $Continuous -and $frame.Type -in 0x61, 0x66) { return }
            }
        }
        Start-Sleep -Milliseconds 10
    }
    if (-not $Continuous) { throw "Timed out waiting for gateway response on $Port." }
}

function Invoke-SelfTest {
    [uint32]$bSource = [Convert]::ToUInt32('B0000001', 16)
    [uint32]$bBoot = [Convert]::ToUInt32('B0070001', 16)
    [uint32]$aSource = [Convert]::ToUInt32('A0000001', 16)
    [uint32]$aBoot = [Convert]::ToUInt32('A0070001', 16)
    [uint32]$card = [Convert]::ToUInt32('CA000001', 16)
    $heartbeat = [System.Collections.Generic.List[byte]]::new()
    Add-U32Le $heartbeat 12345
    Add-U32Le $heartbeat 0x00010002
    Add-U32Le $heartbeat 2
    $heartbeat.Add(3); $heartbeat.Add(1); Add-U16Le $heartbeat 4; Add-U32Le $heartbeat 99
    $heartbeatFrame = New-ProtocolFrame -Type 0x30 -Payload $heartbeat.ToArray() `
        -SourceRole 3 -SourceId $bSource -BootId $bBoot -MessageId 10

    $event = [System.Collections.Generic.List[byte]]::new()
    Add-U32Le $event 7; Add-U32Le $event $aSource; Add-U32Le $event $aBoot
    Add-U32Le $event $card; Add-U32Le $event 9; Add-U32Le $event 1000
    $event.Add(1); $event.Add(1); $event.Add(2); $event.Add(0); $event.Add(2); $event.Add(0)
    Add-U16Le $event 80; $event.Add(90); $event.Add(3); Add-U32Le $event 1100
    Add-U16Le $event 0
    $eventFrame = New-ProtocolFrame -Type 0x62 -Payload $event.ToArray() `
        -SourceRole 3 -SourceId $bSource -BootId $bBoot -MessageId 11 -Flags 1

    $alertPayload = $event.ToArray()
    $alertPayload[26] = 4
    $alertPayload[28] = 0
    $alertPayload[29] = 11
    $alertFrame = New-ProtocolFrame -Type 0x63 -Payload $alertPayload `
        -SourceRole 3 -SourceId $bSource -BootId $bBoot -MessageId 12 -Flags 1

    $confirm = [System.Collections.Generic.List[byte]]::new()
    Add-U32Le $confirm 77; Add-U32Le $confirm 7; Add-U32Le $confirm $card
    Add-U32Le $confirm 9; Add-U32Le $confirm 1200
    $confirm.Add(1); $confirm.Add(1); Add-U16Le $confirm 0
    $confirmFrame = New-ProtocolFrame -Type 0x64 -Payload $confirm.ToArray() `
        -SourceRole 3 -SourceId $bSource -BootId $bBoot -MessageId 13 -Flags 1

    $device = ConvertTo-AdminMessage (ConvertTo-ProtocolFrame $heartbeatFrame)
    $mappedEvent = ConvertTo-AdminMessage (ConvertTo-ProtocolFrame $eventFrame)
    $mappedAlert = ConvertTo-AdminMessage (ConvertTo-ProtocolFrame $alertFrame)
    $mappedConfirm = ConvertTo-AdminMessage (ConvertTo-ProtocolFrame $confirmFrame)
    if ($device.firmware -ne 'v1.0.2' -or $device.policyVersion -ne 'POL-2' -or
        $mappedEvent.result -ne $script:TextSuccess -or $mappedEvent.eventId -notmatch '^EV-A0000001-A0070001-' -or
        $mappedAlert.type -ne 'suspected_replay' -or $mappedAlert.level -ne 'severe' -or
        $mappedConfirm.kind -ne 'confirm_request' -or $mappedConfirm.requestId -ne 77) {
        throw 'Admin compatibility self-test mapping failed.'
    }
    [pscustomobject]@{
        status = 'PASS'
        protocol = 'SLE-AB-V2'
        heartbeatIntervalMs = 1000
        device = $device
        event = $mappedEvent
        alarm = $mappedAlert
        confirm = $mappedConfirm
    } | ConvertTo-Json -Depth 8
}

if ($Action -eq 'SelfTest') {
    Invoke-SelfTest
    exit 0
}

$serial = $null
try {
    $serial = New-GatewayPort
    if ($Action -eq 'Policy') {
        Write-Frame $serial (New-PolicyFrame)
        Invoke-LiveReceive $serial $false
    } elseif ($Action -eq 'Confirm') {
        Write-Frame $serial (New-ConfirmFrame)
        Invoke-LiveReceive $serial $false
    } else {
        Invoke-LiveReceive $serial $true
    }
} finally {
    if ($null -ne $serial) {
        if ($serial.IsOpen) { $serial.Close() }
        $serial.Dispose()
    }
}

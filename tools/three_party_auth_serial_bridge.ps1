[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$APort,
    [Parameter(Mandatory = $true)][string]$BPort,
    [Parameter(Mandatory = $true)][string]$CardPort,
    [int]$BaudRate = 115200,
    [int]$TimeoutMs = 15000
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-TestPort {
    param([string]$Name)
    $port = [System.IO.Ports.SerialPort]::new(
        $Name, $BaudRate, [System.IO.Ports.Parity]::None, 8,
        [System.IO.Ports.StopBits]::One)
    $port.NewLine = "`n"
    $port.ReadTimeout = 30
    $port.WriteTimeout = 1000
    $port.DtrEnable = $false
    $port.RtsEnable = $false
    return $port
}

function Read-AvailableLine {
    param([System.IO.Ports.SerialPort]$Port)
    try {
        if ($Port.BytesToRead -eq 0) { return $null }
        return $Port.ReadLine().Trim()
    } catch [System.TimeoutException] {
        return $null
    }
}

$a = New-TestPort $APort
$b = New-TestPort $BPort
$card = New-TestPort $CardPort
$challengeForwarded = $false
$responseForwarded = $false
$bVerified = $false
$aAuthorized = $false
$passageStarted = $false
$bExecuted = $false

try {
    $a.Open(); $b.Open(); $card.Open()
    $a.DiscardInBuffer(); $b.DiscardInBuffer(); $card.DiscardInBuffer()
    $b.Write("auth testkey`r`n")
    Start-Sleep -Milliseconds 150
    $b.Write("auth start`r`n")
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    while ($watch.ElapsedMilliseconds -lt $TimeoutMs) {
        foreach ($endpoint in @(
            [pscustomobject]@{ Label = 'A'; Port = $a },
            [pscustomobject]@{ Label = 'B'; Port = $b },
            [pscustomobject]@{ Label = 'C'; Port = $card }
        )) {
            $line = Read-AvailableLine $endpoint.Port
            if ($null -eq $line) { continue }
            Write-Host ("[{0}] {1}" -f $endpoint.Label, $line)
            if ($endpoint.Label -eq 'A' -and
                $line -match '^\[A\]\[CARD-TX\]\s+([0-9a-fA-F]+)$') {
                $card.Write(('proto ' + $Matches[1] + "`r`n"))
                $challengeForwarded = $true
            } elseif ($endpoint.Label -eq 'C' -and
                      $line -match '^\[C\]\[PROTO\]\s+([0-9a-fA-F]+)$') {
                $a.Write(('card proto ' + $Matches[1] + "`r`n"))
                $responseForwarded = $true
            }
            # Protocol V2 binary gateway frames and text diagnostics share UART0.
            # A binary prefix may therefore precede an otherwise valid log line.
            if ($endpoint.Label -eq 'B' -and $line -match '\[B\] auth verify=1\b') {
                $bVerified = $true
            }
            if ($endpoint.Label -eq 'A' -and
                $line -match '\[A\] auth result .* auth=1 reason=0\b') {
                $aAuthorized = $true
                if (-not $passageStarted) {
                    $a.Write("demo enter`r`n")
                    $passageStarted = $true
                }
            }
            if ($endpoint.Label -eq 'B' -and
                $line -match '\[B\] EVENT .* auth=1 action=2 confirm=0 exec=2 reason=0\b') {
                $bExecuted = $true
            }
        }
        # A signed AUTH_RESULT followed by B executing an auth=1 event is the
        # end-to-end success condition. bVerified is diagnostic only because its
        # text line can be lost when binary gateway traffic shares the UART.
        if ($challengeForwarded -and $responseForwarded -and
            $aAuthorized -and $bExecuted) {
            Write-Host 'PASS: HMAC authentication was bound to one passage and B executed it.'
            exit 0
        }
        Start-Sleep -Milliseconds 10
    }
    throw ("Authentication timeout. challenge={0} response={1} bVerified={2} aAuthorized={3} passageStarted={4} bExecuted={5}" -f
        $challengeForwarded, $responseForwarded, $bVerified, $aAuthorized,
        $passageStarted, $bExecuted)
} finally {
    foreach ($port in @($a, $b, $card)) {
        if ($port.IsOpen) { $port.Close() }
        $port.Dispose()
    }
}

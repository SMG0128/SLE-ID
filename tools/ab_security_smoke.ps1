[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Port1,
    [Parameter(Mandatory = $true)][string]$Port2,
    [int]$BaudRate = 115200,
    [int]$TimeoutMs = 15000
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-SmokePort {
    param([string]$Name)
    $port = [System.IO.Ports.SerialPort]::new(
        $Name, $BaudRate, [System.IO.Ports.Parity]::None, 8,
        [System.IO.Ports.StopBits]::One)
    $port.ReadTimeout = 30
    $port.WriteTimeout = 1000
    $port.DtrEnable = $false
    $port.RtsEnable = $false
    return $port
}

function Read-PortLines {
    param([pscustomobject]$Endpoint)
    $lines = [System.Collections.Generic.List[string]]::new()
    if ($Endpoint.Port.BytesToRead -gt 0) {
        $Endpoint.Buffer += $Endpoint.Port.ReadExisting()
    }
    while (($newline = $Endpoint.Buffer.IndexOf("`n", [StringComparison]::Ordinal)) -ge 0) {
        $line = $Endpoint.Buffer.Substring(0, $newline).Trim()
        $Endpoint.Buffer = $Endpoint.Buffer.Substring($newline + 1)
        if ($line.Length -gt 0) { $lines.Add($line) }
    }
    return $lines
}

if ($Port1 -eq $Port2) { throw 'Port1 and Port2 must be different.' }
$ports = @($Port1, $Port2)
$endpoints = @()
$a = $null
$b = $null
$bDenied = $false
$aReceivedDecision = $false
$actuatorActivated = $false

try {
    foreach ($name in $ports) {
        $port = New-SmokePort $name
        try {
            $port.Open()
        } catch {
            throw "Unable to open $name. Close VS Code serial monitors and retry. $($_.Exception.Message)"
        }
        $port.DiscardInBuffer()
        $endpoints += [pscustomobject]@{ Name = $name; Port = $port; Buffer = ''; Role = '' }
    }

    foreach ($endpoint in $endpoints) { $endpoint.Port.Write("status`r`n") }
    $detect = [System.Diagnostics.Stopwatch]::StartNew()
    while ($detect.ElapsedMilliseconds -lt 5000 -and ($null -eq $a -or $null -eq $b)) {
        foreach ($endpoint in $endpoints) {
            foreach ($line in (Read-PortLines $endpoint)) {
                Write-Host ("[{0}] {1}" -f $endpoint.Name, $line)
                if ($line -match '^\[A\] state=') {
                    $endpoint.Role = 'A'
                    $a = $endpoint
                } elseif ($line -match '^\[B\] rx=') {
                    $endpoint.Role = 'B'
                    $b = $endpoint
                }
            }
        }
        Start-Sleep -Milliseconds 20
    }
    if ($null -eq $a -or $null -eq $b -or $a.Name -eq $b.Name) {
        throw 'Unable to identify one Detector A and one Detector B. Check firmware, baud rate and UART RX/TX.'
    }
    Write-Host ("Detected Detector A={0}, Detector B={1}" -f $a.Name, $b.Name)

    $b.Port.Write("policy execute`r`n")
    Start-Sleep -Milliseconds 100
    $a.Port.Write("auth ok`r`n")
    Start-Sleep -Milliseconds 100
    $a.Port.Write("demo enter`r`n")

    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    while ($watch.ElapsedMilliseconds -lt $TimeoutMs) {
        foreach ($endpoint in $endpoints) {
            foreach ($line in (Read-PortLines $endpoint)) {
                Write-Host ("[{0}] {1}" -f $endpoint.Role, $line)
                if ($endpoint.Role -eq 'B' -and $line -match '^\[B\] actuator ON\b') {
                    $actuatorActivated = $true
                }
                if ($endpoint.Role -eq 'B' -and
                    $line -match '^\[B\] EVENT .* auth=0 action=4 confirm=0 exec=0 reason=1\b') {
                    $bDenied = $true
                }
                if ($endpoint.Role -eq 'A' -and
                    $line -match '^\[A\] decision .* action=4 confirm=0 exec=0 reason=1\b') {
                    $aReceivedDecision = $true
                }
            }
        }
        if ($actuatorActivated) {
            throw 'FAIL: B activated GPIO for an authorization that was not bound to an HMAC session.'
        }
        if ($bDenied -and $aReceivedDecision) {
            Write-Host 'PASS: unbound local authorization was rejected and GPIO stayed off.'
            exit 0
        }
        Start-Sleep -Milliseconds 10
    }
    throw ("Smoke test timeout. bDenied={0} aDecision={1} actuator={2}. Confirm both boards show bridge ready." -f
        $bDenied, $aReceivedDecision, $actuatorActivated)
} finally {
    foreach ($endpoint in $endpoints) {
        if ($endpoint.Port.IsOpen) { $endpoint.Port.Close() }
        $endpoint.Port.Dispose()
    }
}

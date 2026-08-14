param(
    [Parameter(Mandatory = $true)][string]$InputPath,
    [Parameter(Mandatory = $true)][string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$inputResolved = (Resolve-Path -LiteralPath $InputPath).Path
$outputDirectory = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
$outputResolved = Join-Path (Resolve-Path -LiteralPath $outputDirectory).Path (Split-Path -Leaf $OutputPath)

$word = $null
$document = $null
try {
    Write-Host "Starting Word automation"
    $word = New-Object -ComObject Word.Application
    $word.Visible = $false
    $word.DisplayAlerts = 0
    Write-Host "Opening $inputResolved"
    $document = $word.Documents.Open($inputResolved, $false, $true)
    Write-Host "Exporting $outputResolved"
    $document.SaveAs2($outputResolved, 17)
    Write-Host "Export complete"
}
finally {
    if ($null -ne $document) {
        $document.Close($false)
        [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($document)
    }
    if ($null -ne $word) {
        $word.Quit()
        [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($word)
    }
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
}

if (-not (Test-Path -LiteralPath $outputResolved)) {
    throw "PDF was not created: $outputResolved"
}
Get-Item -LiteralPath $outputResolved | Select-Object FullName, Length, LastWriteTime

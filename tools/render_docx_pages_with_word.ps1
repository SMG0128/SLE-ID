param(
    [Parameter(Mandatory = $true)][string]$InputPath,
    [Parameter(Mandatory = $true)][string]$OutputDirectory,
    [int]$Width = 1360,
    [int]$Height = 1760
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$inputResolved = (Resolve-Path -LiteralPath $InputPath).Path
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$outputResolved = (Resolve-Path -LiteralPath $OutputDirectory).Path

$word = $null
$document = $null
try {
    $word = New-Object -ComObject Word.Application
    $word.Visible = $false
    $word.DisplayAlerts = 0
    $document = $word.Documents.Open($inputResolved, $false, $true)
    $window = $document.Windows.Item(1)
    $window.View.Type = 3
    $document.Repaginate()
    $pageCount = $document.ComputeStatistics(2)
    Write-Host "Pages: $pageCount"

    for ($index = 1; $index -le $pageCount; $index++) {
        $page = $window.Panes.Item(1).Pages.Item($index)
        [byte[]]$bits = $page.EnhMetaFileBits
        $emfPath = Join-Path $outputResolved ('page-{0:D2}.emf' -f $index)
        $pngPath = Join-Path $outputResolved ('page-{0:D2}.png' -f $index)
        [IO.File]::WriteAllBytes($emfPath, $bits)

        $source = [System.Drawing.Image]::FromFile($emfPath)
        try {
            $bitmap = New-Object System.Drawing.Bitmap($Width, $Height)
            try {
                $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
                try {
                    $graphics.Clear([System.Drawing.Color]::White)
                    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                    $graphics.DrawImage($source, 0, 0, $Width, $Height)
                }
                finally {
                    $graphics.Dispose()
                }
                $bitmap.Save($pngPath, [System.Drawing.Imaging.ImageFormat]::Png)
            }
            finally {
                $bitmap.Dispose()
            }
        }
        finally {
            $source.Dispose()
        }
        Remove-Item -LiteralPath $emfPath -Force
        Write-Host "Rendered page $index"
    }
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

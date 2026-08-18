# SLE-ID 三端认证回归测试（2026-08-18）
# 前置：A 板（Detector A 固件）接 COM8；B 板接 COM7；Card C 接 COM14；后端运行中。
# 用法：powershell -ExecutionPolicy Bypass -File .\tools\three_board_auth_regression.ps1

$ErrorActionPreference = 'Continue'
$baud = 115200

function Send-Cmd($portName, $cmd, $waitMs = 700) {
    try {
        $port = [System.IO.Ports.SerialPort]::new($portName, $baud, 'None', 8, 'One')
        $port.DtrEnable = $false
        $port.RtsEnable = $false
        $port.ReadTimeout = 300
        $port.WriteTimeout = 300
        $port.Open()
        $port.WriteLine($cmd)
        Start-Sleep -Milliseconds $waitMs
        $data = $port.ReadExisting()
        $port.Close()
        return $data
    } catch {
        return "ERROR: $($_.Exception.Message)"
    }
}

function Assert-Contains($text, $pattern, $label) {
    if ($text -match $pattern) {
        Write-Host "[PASS] $label" -ForegroundColor Green
        return $true
    }
    Write-Host "[FAIL] $label" -ForegroundColor Red
    Write-Host "       expected: $pattern"
    Write-Host "       got: $($text.Trim())"
    return $false
}

$pass = 0
$fail = 0

Write-Host "===== 1. Card C 状态（写卡后应 count>=1） =====" -ForegroundColor Cyan
$cardStatus = Send-Cmd 'COM14' 'status'
Write-Host $cardStatus.Trim()
if (Assert-Contains $cardStatus 'count=1' 'Card C count=1') { $pass++ } else { $fail++ }
if (Assert-Contains $cardStatus 'generation=1' 'Card C generation=1') { $pass++ } else { $fail++ }

Write-Host "===== 2. A 板状态（Detector A 固件） =====" -ForegroundColor Cyan
$aStatus = Send-Cmd 'COM8' 'status'
Write-Host $aStatus.Trim()
if (Assert-Contains $aStatus '\[A\]' 'A board responds') { $pass++ } else { $fail++ }

Write-Host "===== 3. B 板状态 =====" -ForegroundColor Cyan
$bStatus = Send-Cmd 'COM7' 'status'
Write-Host $bStatus.Trim()
if (Assert-Contains $bStatus '\[B\]' 'B board responds') { $pass++ } else { $fail++ }

Write-Host "===== 4. A 连接 B/Card 状态 =====" -ForegroundColor Cyan
# A 的 status 输出应包含 ready B=1 与 ready Card=1
if (Assert-Contains $aStatus 'ready B=1|B ... ready=1|B=1' 'A sees B ready') { $pass++ } else { $fail++ }
if (Assert-Contains $aStatus 'ready Card=1|Card ... ready=1' 'A sees Card ready') { $pass++ } else { $fail++ }

Write-Host "===== 5. 认证主路径（B: auth testkey + auth start; A: demo enter） =====" -ForegroundColor Cyan
Write-Host "-- B 安装测试凭据 --"
$r1 = Send-Cmd 'COM7' 'auth testkey' 600
Write-Host $r1.Trim()
Write-Host "-- B 开启认证窗口 --"
$r2 = Send-Cmd 'COM7' 'auth start' 400
Write-Host $r2.Trim()
Write-Host "-- A 触发 demo enter（窗口内） --"
$r3 = Send-Cmd 'COM8' 'demo enter' 1500
Write-Host $r3.Trim()

Write-Host "===== 6. 认证结果检查 =====" -ForegroundColor Cyan
$bAfter = Send-Cmd 'COM7' 'status'
Write-Host $bAfter.Trim()
if (Assert-Contains $bAfter 'auth consume=1|consumed=1' 'B consumed auth') { $pass++ } else { $fail++ }

Write-Host ""
Write-Host "===== 结果: $pass PASS / $fail FAIL =====" -ForegroundColor Yellow
if ($fail -eq 0) { Write-Host "三端认证回归通过。" -ForegroundColor Green } else { Write-Host "存在失败项，见上方日志。" -ForegroundColor Red }

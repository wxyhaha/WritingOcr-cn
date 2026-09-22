[CmdletBinding()]
param(
    [string]$PackageDirectory = ""
)

$ErrorActionPreference = "Stop"
if (-not $PackageDirectory) {
    $root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
    $PackageDirectory = Join-Path $root "release\HandwritingOCR"
}

$package = (Resolve-Path $PackageDirectory).Path
$python = Join-Path $package "runtime\python\python.exe"
$worker = Join-Path $package "ocr-worker\main.py"
$cache = Join-Path $package "runtime\models\paddlex"
$stdout = Join-Path $package "worker-smoke.stdout.log"
$stderr = Join-Path $package "worker-smoke.stderr.log"
$port = 18767

if (-not (Test-Path -LiteralPath $python)) { throw "Bundled Python not found: $python" }
if (-not (Test-Path -LiteralPath $worker)) { throw "OCR worker not found: $worker" }
if (-not (Test-Path -LiteralPath $cache)) { throw "Bundled PaddleX cache not found: $cache" }

$oldPort = $env:OCR_PORT
$oldHost = $env:OCR_HOST
$oldCache = $env:PADDLE_PDX_CACHE_HOME
$oldRoots = $env:OCR_ALLOWED_ROOTS
$env:OCR_PORT = [string]$port
$env:OCR_HOST = "127.0.0.1"
$env:PADDLE_PDX_CACHE_HOME = $cache
$env:OCR_ALLOWED_ROOTS = Join-Path $env:TEMP "HandwritingOCR-release-smoke"
New-Item -ItemType Directory -Path $env:OCR_ALLOWED_ROOTS -Force | Out-Null

$process = $null
$ready = $false
$lastHealth = ""
try {
    $process = Start-Process -FilePath $python -ArgumentList @($worker) -WorkingDirectory $package `
        -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru -WindowStyle Hidden

    for ($i = 0; $i -lt 90; $i++) {
        Start-Sleep -Seconds 2
        try {
            $health = Invoke-RestMethod "http://127.0.0.1:$port/health" -TimeoutSec 5
            $lastHealth = $health | ConvertTo-Json -Compress
            if ($health.status -eq "ready") {
                $ready = $true
                break
            }
        }
        catch {
            $lastHealth = $_.Exception.Message
        }

        if ($process.HasExited) {
            break
        }
    }
}
finally {
    if ($process -and -not $process.HasExited) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        $process.WaitForExit(5000) | Out-Null
    }
    if ($null -eq $oldPort) { Remove-Item Env:OCR_PORT -ErrorAction SilentlyContinue } else { $env:OCR_PORT = $oldPort }
    if ($null -eq $oldHost) { Remove-Item Env:OCR_HOST -ErrorAction SilentlyContinue } else { $env:OCR_HOST = $oldHost }
    if ($null -eq $oldCache) { Remove-Item Env:PADDLE_PDX_CACHE_HOME -ErrorAction SilentlyContinue } else { $env:PADDLE_PDX_CACHE_HOME = $oldCache }
    if ($null -eq $oldRoots) { Remove-Item Env:OCR_ALLOWED_ROOTS -ErrorAction SilentlyContinue } else { $env:OCR_ALLOWED_ROOTS = $oldRoots }
}

Write-Host "Release OCR smoke test: $([bool]$ready)"
Write-Host "Health: $lastHealth"
if (Test-Path -LiteralPath $stderr) {
    Write-Host "--- worker stderr (tail) ---"
    Get-Content -LiteralPath $stderr -Tail 30
}
Remove-Item -LiteralPath $stdout, $stderr -Force -ErrorAction SilentlyContinue
if (-not $ready) {
    throw "Bundled OCR Worker did not become ready"
}

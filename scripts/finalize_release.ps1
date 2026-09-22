[CmdletBinding()]
param(
    [string]$PackageDirectory = "",
    [switch]$BuildInstaller
)

$ErrorActionPreference = "Stop"
if (-not $PackageDirectory) {
    $root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
    $PackageDirectory = Join-Path $root "release\HandwritingOCR"
}

$stage = (Resolve-Path $PackageDirectory).Path
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

Get-ChildItem -LiteralPath $stage -Recurse -Directory -Filter "__pycache__" -ErrorAction SilentlyContinue |
    Sort-Object FullName -Descending |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Get-ChildItem -LiteralPath $stage -Recurse -File -Include "*.pyc", "*.pyo" -ErrorAction SilentlyContinue |
    Remove-Item -Force -ErrorAction SilentlyContinue

$files = Get-ChildItem -LiteralPath $stage -Recurse -File
$manifest = [ordered]@{
    product = "HandwritingOCR"
    version = "1.0.0"
    architecture = "x64"
    createdAt = (Get-Date).ToUniversalTime().ToString("o")
    python = "3.13.4"
    bundledPython = Test-Path -LiteralPath (Join-Path $stage "runtime\python\python.exe")
    bundledModels = Test-Path -LiteralPath (Join-Path $stage "runtime\models\paddlex\official_models")
    ocrWorker = "PP-OCRv5 / PaddleOCR 3.7.0"
    packageSizeMB = [math]::Round((($files | Measure-Object Length -Sum).Sum / 1MB), 1)
}
$manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $stage "release-manifest.json") -Encoding UTF8

if ($BuildInstaller) {
    $iscc = $null
    $command = Get-Command iscc.exe -ErrorAction SilentlyContinue
    if ($command) { $iscc = $command.Source }
    $known = @(
        "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
        "C:\Program Files\Inno Setup 6\ISCC.exe",
        (Join-Path $env:LOCALAPPDATA "Programs\Inno Setup 6\ISCC.exe")
    ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $iscc) { $iscc = $known }
    if (-not $iscc) { throw "未找到 Inno Setup ISCC.exe" }

    $output = Join-Path (Split-Path $stage -Parent) "installer"
    New-Item -ItemType Directory -Path $output -Force | Out-Null
    & $iscc "/Qp" "/DStagingDir=$stage" "/DOutputDir=$output" (Join-Path $root "installer\HandwritingOCR.iss")
    if ($LASTEXITCODE -ne 0) { throw "Inno Setup 编译失败 ($LASTEXITCODE)" }
}

$files = Get-ChildItem -LiteralPath $stage -Recurse -File
[pscustomobject]@{
    PackageDirectory = $stage
    Files = $files.Count
    SizeMB = [math]::Round((($files | Measure-Object Length -Sum).Sum / 1MB), 1)
    ModelsIncluded = Test-Path -LiteralPath (Join-Path $stage "runtime\models\paddlex\official_models")
} | Format-List

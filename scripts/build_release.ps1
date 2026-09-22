[CmdletBinding()]
param(
    [ValidateSet("Release", "Debug")]
    [string]$Configuration = "Release",
    [string]$PythonVersion = "3.13.4",
    [string]$PipIndexUrl = "https://pypi.tuna.tsinghua.edu.cn/simple",
    [switch]$SkipBuild,
    [switch]$SkipModelWarmup,
    [switch]$SkipArchive,
    [switch]$SkipInstaller
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$dist = Join-Path $root "dist\HandwritingOCR"
$releaseRoot = Join-Path $root "release"
$stage = Join-Path $releaseRoot "HandwritingOCR"
$cache = Join-Path $releaseRoot ".cache"
$runtime = Join-Path $stage "runtime"
$pythonDir = Join-Path $runtime "python"
$modelCache = Join-Path $runtime "models\paddlex"

function Write-Step([string]$message) {
    Write-Host "`n==> $message" -ForegroundColor Cyan
}

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $false)][string[]]$Arguments = @(),
        [Parameter(Mandatory = $false)][string]$WorkingDirectory = $root
    )

    Push-Location $WorkingDirectory
    try {
        & $FilePath @Arguments
        if ($LASTEXITCODE -ne 0) {
            throw "命令失败 ($LASTEXITCODE): $FilePath $($Arguments -join ' ')"
        }
    }
    finally {
        Pop-Location
    }
}

function Ensure-Directory([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
}

function Download-IfMissing([string]$uri, [string]$target) {
    if (Test-Path -LiteralPath $target) {
        # A previous interrupted download may have left a partial archive.
        # Validate ZIP files before trusting the cache entry.
        if ([IO.Path]::GetExtension($target) -ieq ".zip") {
            try {
                $archive = [IO.Compression.ZipFile]::OpenRead($target)
                $archive.Dispose()
                return
            }
            catch {
                Remove-Item -LiteralPath $target -Force
            }
        }
        else {
            return
        }
    }

    Write-Host "Downloading $uri"
    $partial = "$target.partial"
    if (Test-Path -LiteralPath $partial) {
        Remove-Item -LiteralPath $partial -Force
    }

    & curl.exe --location --fail --silent --show-error --retry 5 --retry-all-errors --connect-timeout 30 --output $partial $uri
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $partial)) {
        Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue
        throw "下载失败: $uri"
    }
    Move-Item -LiteralPath $partial -Destination $target -Force
}

function Find-VcVars64 {
    $candidates = @(
        (Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"),
        (Join-Path $env:ProgramFiles "Microsoft Visual Studio\Installer\vswhere.exe")
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

    foreach ($vswhere in $candidates) {
        $installPath = (& $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath | Select-Object -First 1)
        if ($installPath) {
            $vcvars = Join-Path ([string]$installPath).Trim() "VC\Auxiliary\Build\vcvars64.bat"
            if (Test-Path -LiteralPath $vcvars) {
                return $vcvars
            }
        }
    }

    $fallback = Join-Path $env:ProgramFiles "Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
    if (Test-Path -LiteralPath $fallback) {
        return $fallback
    }
    return $null
}

function Build-DesktopApp {
    $preset = if ($Configuration -eq "Debug") { "windows-msvc-debug" } else { "windows-msvc-release" }
    $buildPreset = if ($Configuration -eq "Debug") { "debug" } else { "release" }
    $vcvars = Find-VcVars64

    if ($vcvars) {
        $command = "call `"$vcvars`" && cd /d `"$root`" && cmake --preset $preset && cmake --build --preset $buildPreset"
        Invoke-Checked -FilePath "cmd.exe" -Arguments @("/d", "/s", "/c", $command)
    }
    else {
        Invoke-Checked -FilePath "cmake" -Arguments @("--preset", $preset)
        Invoke-Checked -FilePath "cmake" -Arguments @("--build", "--preset", $buildPreset)
    }
}

function Get-PythonTag([string]$version) {
    $parts = $version.Split('.')
    if ($parts.Count -lt 2) {
        throw "PythonVersion 必须形如 3.13.4"
    }
    return "python$($parts[0])$($parts[1])"
}

Write-Step "检查构建产物"
if (-not $SkipBuild) {
    Build-DesktopApp
}
if (-not (Test-Path -LiteralPath (Join-Path $dist "HandwritingOCR.exe"))) {
    throw "未找到桌面程序: $dist\HandwritingOCR.exe"
}

Write-Step "创建干净发布目录"
Ensure-Directory $releaseRoot
Ensure-Directory $cache
if (Test-Path -LiteralPath $stage) {
    Remove-Item -LiteralPath $stage -Recurse -Force
}
New-Item -ItemType Directory -Path $stage -Force | Out-Null
Copy-Item -Path (Join-Path $dist "*") -Destination $stage -Recurse -Force

# Remove development-only Python bytecode from the copied worker.
Get-ChildItem -LiteralPath $stage -Recurse -Directory -Filter "__pycache__" -ErrorAction SilentlyContinue |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Get-ChildItem -LiteralPath $stage -Recurse -File -Include "*.pyc", "*.pyo" -ErrorAction SilentlyContinue |
    Remove-Item -Force -ErrorAction SilentlyContinue

Write-Step "准备内置 Python $PythonVersion"
Ensure-Directory $runtime
Ensure-Directory $cache
$pythonZip = Join-Path $cache "python-$PythonVersion-embed-amd64.zip"
$pythonUri = "https://www.python.org/ftp/python/$PythonVersion/python-$PythonVersion-embed-amd64.zip"
Download-IfMissing $pythonUri $pythonZip
if (Test-Path -LiteralPath $pythonDir) {
    Remove-Item -LiteralPath $pythonDir -Recurse -Force
}
New-Item -ItemType Directory -Path $pythonDir -Force | Out-Null
Expand-Archive -LiteralPath $pythonZip -DestinationPath $pythonDir -Force

$pythonTag = Get-PythonTag $PythonVersion
$pthFile = Get-ChildItem -LiteralPath $pythonDir -File -Filter "*._pth" | Select-Object -First 1
if (-not $pthFile) {
    throw "内置 Python 压缩包中没有 *._pth 配置文件"
}
Ensure-Directory (Join-Path $pythonDir "Lib\site-packages")
@(
    "$pythonTag.zip",
    ".",
    "Lib/site-packages",
    "import site"
) | Set-Content -LiteralPath $pthFile.FullName -Encoding Ascii

$pythonExe = Join-Path $pythonDir "python.exe"
if (-not (Test-Path -LiteralPath $pythonExe)) {
    throw "内置 Python 解压失败: $pythonExe"
}

$getPip = Join-Path $cache "get-pip.py"
Download-IfMissing "https://bootstrap.pypa.io/get-pip.py" $getPip
$env:PYTHONNOUSERSITE = "1"
Invoke-Checked -FilePath $pythonExe -Arguments @($getPip, "--disable-pip-version-check") -WorkingDirectory $pythonDir

Write-Step "安装锁定的 OCR 依赖"
$requirements = Join-Path $root "requirements.txt"
$installArgs = @(
    "-m", "pip", "install", "--disable-pip-version-check", "--timeout", "120",
    "-r", $requirements,
    "-i", $PipIndexUrl,
    "--trusted-host", ([Uri]$PipIndexUrl).Host
)
try {
    Invoke-Checked -FilePath $pythonExe -Arguments $installArgs -WorkingDirectory $root
}
catch {
    Write-Warning "指定镜像安装失败，改用官方 PyPI 重试。"
    Invoke-Checked -FilePath $pythonExe -Arguments @(
        "-m", "pip", "install", "--disable-pip-version-check", "--timeout", "120", "-r", $requirements
    ) -WorkingDirectory $root
}

Invoke-Checked -FilePath $pythonExe -Arguments @(
    "-c", "import fastapi, paddle, paddleocr, paddlex, docx; print('Bundled OCR runtime imports OK')"
) -WorkingDirectory $pythonDir

if (-not $SkipModelWarmup) {
    Write-Step "下载并预热 PP-OCRv5 模型"
    Ensure-Directory $modelCache
    $oldCache = $env:PADDLE_PDX_CACHE_HOME
    $oldModelSource = $env:PADDLE_PDX_MODEL_SOURCE
    try {
        $env:PADDLE_PDX_CACHE_HOME = $modelCache
        $warmupScript = Join-Path $root "scripts\warmup_ocr.py"
        Invoke-Checked -FilePath $pythonExe -Arguments @($warmupScript) -WorkingDirectory $root
    }
    finally {
        if ($null -eq $oldCache) { Remove-Item Env:PADDLE_PDX_CACHE_HOME -ErrorAction SilentlyContinue } else { $env:PADDLE_PDX_CACHE_HOME = $oldCache }
        if ($null -eq $oldModelSource) { Remove-Item Env:PADDLE_PDX_MODEL_SOURCE -ErrorAction SilentlyContinue } else { $env:PADDLE_PDX_MODEL_SOURCE = $oldModelSource }
    }
}
else {
    Write-Warning "已跳过模型预热；发布包首次识别时仍可能需要联网下载模型。"
}

Write-Step "加入运行时启动器和发布说明"
Copy-Item (Join-Path $root "scripts\release-launch.bat") (Join-Path $stage "release-launch.bat") -Force
Copy-Item (Join-Path $root "scripts\diagnose-release.bat") (Join-Path $stage "diagnose-release.bat") -Force
Copy-Item (Join-Path $root "scripts\release-readme.txt") (Join-Path $stage "README-发布版.txt") -Force
Copy-Item $requirements (Join-Path $runtime "requirements.txt") -Force

if (-not (Test-Path -LiteralPath (Join-Path $stage "vc_redist.x64.exe"))) {
    Write-Step "下载 Microsoft Visual C++ 运行库"
    $vcCache = Join-Path $cache "vc_redist.x64.exe"
    Download-IfMissing "https://aka.ms/vs/17/release/vc_redist.x64.exe" $vcCache
    Copy-Item $vcCache (Join-Path $stage "vc_redist.x64.exe") -Force
}

# Imports and the smoke test can recreate Python bytecode in the staged worker.
# It is not required at runtime and should not make release artifacts depend on
# the build machine's import history.
Get-ChildItem -LiteralPath $stage -Recurse -Directory -Filter "__pycache__" -ErrorAction SilentlyContinue |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Get-ChildItem -LiteralPath $stage -Recurse -File -Include "*.pyc", "*.pyo" -ErrorAction SilentlyContinue |
    Remove-Item -Force -ErrorAction SilentlyContinue

$manifest = [ordered]@{
    product = "HandwritingOCR"
    version = "1.0.0"
    architecture = "x64"
    createdAt = (Get-Date).ToUniversalTime().ToString("o")
    python = $PythonVersion
    bundledPython = Test-Path -LiteralPath $pythonExe
    bundledModels = Test-Path -LiteralPath (Join-Path $modelCache "official_models")
    ocrWorker = "PP-OCRv5 / PaddleOCR 3.7.0"
    packageSizeMB = [math]::Round(((Get-ChildItem -LiteralPath $stage -Recurse -File | Measure-Object Length -Sum).Sum / 1MB), 1)
}
$manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $stage "release-manifest.json") -Encoding UTF8

$zipPath = Join-Path $releaseRoot "HandwritingOCR-1.0.0-win-x64.zip"
if (-not $SkipArchive) {
    Write-Step "生成便携发布压缩包"
    if (Test-Path -LiteralPath $zipPath) {
        Remove-Item -LiteralPath $zipPath -Force
    }
    Compress-Archive -Path (Join-Path $stage "*") -DestinationPath $zipPath -CompressionLevel Optimal
}

if (-not $SkipInstaller) {
    $iscc = $null
    $isccCommand = Get-Command iscc.exe -ErrorAction SilentlyContinue
    if ($isccCommand) {
        $iscc = $isccCommand.Source
    }
    $knownIscc = @(
        "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
        "C:\Program Files\Inno Setup 6\ISCC.exe",
        (Join-Path $env:LOCALAPPDATA "Programs\Inno Setup 6\ISCC.exe")
    ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $iscc) { $iscc = $knownIscc }

    if ($iscc) {
        Write-Step "生成 Inno Setup 安装包"
        $installerDir = Join-Path $releaseRoot "installer"
        Ensure-Directory $installerDir
        Invoke-Checked -FilePath $iscc -Arguments @(
            "/Qp",
            "/DStagingDir=$stage",
            "/DOutputDir=$installerDir",
            (Join-Path $root "installer\HandwritingOCR.iss")
        ) -WorkingDirectory $root
    }
    else {
        Write-Warning "未找到 Inno Setup ISCC.exe，已生成便携目录和 ZIP；安装包需安装 Inno Setup 后重跑并加 -SkipBuild。"
    }
}

$hash = $null
if (Test-Path -LiteralPath $zipPath) {
    $hash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash
}
Write-Host "`n发布完成：" -ForegroundColor Green
Write-Host "  目录: $stage"
if ($hash) { Write-Host "  ZIP : $zipPath"; Write-Host "  SHA256: $hash" }
Write-Host "  启动: $stage\release-launch.bat"

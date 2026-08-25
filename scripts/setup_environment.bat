@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0.."

echo ==============================================================================
echo   Handwriting Chinese OCR - Automatic Python Environment Setup
echo ==============================================================================
echo.

set "FOUND_PY="

for /d %%d in ("%LOCALAPPDATA%\Programs\Python\Python*") do (
    if exist "%%d\python.exe" (
        "%%d\python.exe" -c "import sys; exit(0 if sys.version_info >= (3, 10) and sys.maxsize > 2**32 else 1)" >nul 2>nul
        if !errorlevel! equ 0 (
            set "FOUND_PY=%%d\python.exe"
            goto :py_found
        )
    )
)

for /d %%d in ("C:\Python*") do (
    if exist "%%d\python.exe" (
        "%%d\python.exe" -c "import sys; exit(0 if sys.version_info >= (3, 10) and sys.maxsize > 2**32 else 1)" >nul 2>nul
        if !errorlevel! equ 0 (
            set "FOUND_PY=%%d\python.exe"
            goto :py_found
        )
    )
)

where py >nul 2>nul
if %errorlevel% equ 0 (
    py -3 -c "import sys; exit(0 if sys.version_info >= (3, 10) and sys.maxsize > 2**32 else 1)" >nul 2>nul
    if !errorlevel! equ 0 (
        set "FOUND_PY=py"
        goto :py_found
    )
)

where python >nul 2>nul
if %errorlevel% equ 0 (
    python -c "import sys; exit(0 if sys.version_info >= (3, 10) and sys.maxsize > 2**32 else 1)" >nul 2>nul
    if !errorlevel! equ 0 (
        set "FOUND_PY=python"
        goto :py_found
    )
)

:py_install
echo [Setup] No Python 3.10+ (64-bit) detected.
echo [Setup] Installing official Python 3.12 (64-bit)...
echo.

where winget >nul 2>nul
if %errorlevel% equ 0 (
    echo [Setup] Installing Python 3.12 via winget...
    winget install Python.Python.3.12 --silent --accept-package-agreements --accept-source-agreements
)

for /d %%d in ("%LOCALAPPDATA%\Programs\Python\Python312*") do (
    if exist "%%d\python.exe" (
        set "FOUND_PY=%%d\python.exe"
        goto :py_found
    )
)

if not defined FOUND_PY (
    echo [Setup] Downloading Python 3.12.8 from python.org...
    set "INSTALLER=%TEMP%\python-3.12.8-amd64.exe"
    powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; (New-Object System.Net.WebClient).DownloadFile('https://www.python.org/ftp/python/3.12.8/python-3.12.8-amd64.exe', '%INSTALLER%')"
    
    if exist "%INSTALLER%" (
        echo [Setup] Running silent installer...
        start /wait "" "%INSTALLER%" /quiet InstallAllUsers=0 PrependPath=1 Include_test=0
        del /f /q "%INSTALLER%" >nul 2>nul
    )
)

for /d %%d in ("%LOCALAPPDATA%\Programs\Python\Python*") do (
    if exist "%%d\python.exe" set "FOUND_PY=%%d\python.exe"
)
if not defined FOUND_PY set "FOUND_PY=python"

:py_found
echo.
echo [Setup] Using Python: !FOUND_PY!
echo [Setup] Installing locked dependencies from requirements.txt...
echo.

"!FOUND_PY!" -m pip install --upgrade pip -i https://pypi.tuna.tsinghua.edu.cn/simple --trusted-host pypi.tuna.tsinghua.edu.cn
"!FOUND_PY!" -m pip install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple --trusted-host pypi.tuna.tsinghua.edu.cn

if %errorlevel% neq 0 (
    echo [Warning] Tsinghua mirror failed, falling back to official PyPI...
    "!FOUND_PY!" -m pip install -r requirements.txt
)

echo.
echo ==============================================================================
echo   [SUCCESS] Python and dependencies installed successfully!
echo ==============================================================================
echo.
endlocal
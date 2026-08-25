@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

echo ====================================================
echo   Build and Run Handwriting Chinese OCR Digitalizer
echo ====================================================
echo.

:: 1. Locate Visual Studio vcvars64.bat dynamically via vswhere
set "VS_INSTALL_DIR="
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "%VSWHERE%" set "VSWHERE=%ProgramFiles%\Microsoft Visual Studio\Installer\vswhere.exe"

if exist "%VSWHERE%" (
    for /f "usebackq tokens=*" %%i in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do (
        set "VS_INSTALL_DIR=%%i"
    )
)

if defined VS_INSTALL_DIR (
    if exist "!VS_INSTALL_DIR!\VC\Auxiliary\Build\vcvars64.bat" (
        echo [Env] Initializing Visual Studio environment from: !VS_INSTALL_DIR!
        call "!VS_INSTALL_DIR!\VC\Auxiliary\Build\vcvars64.bat"
    )
) else (
    if exist "%ProgramFiles%\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" (
        call "%ProgramFiles%\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
    )
)

:: 2. Auto-detect Qt6 if not in PATH
where qmake >nul 2>nul
if %errorlevel% neq 0 (
    if exist "C:\Qt\6.5.3\msvc2019_64\bin" (
        set "PATH=C:\Qt\6.5.3\msvc2019_64\bin;!PATH!"
    )
    for /d %%d in ("C:\Qt\6.*\msvc*_64\bin") do (
        if exist "%%d" set "PATH=%%d;!PATH!"
    )
    for /d %%d in ("D:\Qt\6.*\msvc*_64\bin") do (
        if exist "%%d" set "PATH=%%d;!PATH!"
    )
)

:: 3. Auto-detect Python Scripts (cmake, ninja, uvicorn)
for /d %%d in ("%APPDATA%\Python\Python*\Scripts") do if exist "%%d" set "PATH=%%d;!PATH!"
for /d %%d in ("%LOCALAPPDATA%\Programs\Python\Python*\Scripts") do if exist "%%d" set "PATH=%%d;!PATH!"

:: 4. Locate Python with dependencies
set "PYTHON_EXE="
for %%v in (Python313 Python312 Python311 Python310) do (
    if exist "%LOCALAPPDATA%\Programs\Python\%%v\python.exe" (
        "%LOCALAPPDATA%\Programs\Python\%%v\python.exe" -c "import fastapi, paddleocr" >nul 2>nul
        if !errorlevel! equ 0 (
            set "PYTHON_EXE=%LOCALAPPDATA%\Programs\Python\%%v\python.exe"
            goto :found_python_build
        )
    )
)

for %%v in (Python313 Python312 Python311 Python310) do (
    if exist "%LOCALAPPDATA%\Programs\Python\%%v\python.exe" (
        set "PYTHON_EXE=%LOCALAPPDATA%\Programs\Python\%%v\python.exe"
        goto :check_deps_build
    )
)

where py >nul 2>nul
if %errorlevel% equ 0 (
    set "PYTHON_EXE=py"
    goto :check_deps_build
)

where python >nul 2>nul
if %errorlevel% equ 0 set "PYTHON_EXE=python"

:check_deps_build
if not defined PYTHON_EXE (
    call "%~dp0scripts\setup_environment.bat"
    for %%v in (Python313 Python312 Python311 Python310) do (
        if exist "%LOCALAPPDATA%\Programs\Python\%%v\python.exe" set "PYTHON_EXE=%LOCALAPPDATA%\Programs\Python\%%v\python.exe"
    )
)

:found_python_build
echo.
echo [1/3] Building C++ application...
if not exist build (
    cmake -B build -S . -DCMAKE_BUILD_TYPE=Release
)
cmake --build build --config Release
if %errorlevel% neq 0 (
    echo [ERROR] Build failed!
    pause
    exit /b %errorlevel%
)

echo.
echo [2/3] Checking OCR Worker...
netstat -ano | findstr /R /C:":8766 " >nul
if %errorlevel% neq 0 (
    echo Starting OCR Worker via !PYTHON_EXE!...
    start "OCR-Worker" /min cmd /c "!PYTHON_EXE! \"%~dp0ocr-worker\main.py\""
    ping 127.0.0.1 -n 3 >nul
)

echo.
echo [3/3] Launching Desktop App...
start "" "%~dp0build\HandwritingOCR.exe"
endlocal
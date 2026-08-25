@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

echo ====================================================
echo   Handwriting Chinese OCR Digitalizer (MVP)
echo ====================================================
echo.

:: 1. Auto-detect Qt6
where qmake >nul 2>nul
if %errorlevel% neq 0 (
    if exist "C:\Qt\6.5.3\msvc2019_64\bin" set "PATH=C:\Qt\6.5.3\msvc2019_64\bin;!PATH!"
    for /d %%d in ("C:\Qt\6.*\msvc*_64\bin") do if exist "%%d" set "PATH=%%d;!PATH!"
    for /d %%d in ("D:\Qt\6.*\msvc*_64\bin") do if exist "%%d" set "PATH=%%d;!PATH!"
)

:: 2. Auto-detect Python Scripts
for /d %%d in ("%APPDATA%\Python\Python*\Scripts") do if exist "%%d" set "PATH=%%d;!PATH!"
for /d %%d in ("%LOCALAPPDATA%\Programs\Python\Python*\Scripts") do if exist "%%d" set "PATH=%%d;!PATH!"

:: 3. Find Python Interpreter with Dependencies
set "PYTHON_EXE="

:: First priority: Check Python with PaddleOCR already installed
for %%v in (Python313 Python312 Python311 Python310) do (
    if exist "%LOCALAPPDATA%\Programs\Python\%%v\python.exe" (
        "%LOCALAPPDATA%\Programs\Python\%%v\python.exe" -c "import fastapi, paddleocr" >nul 2>nul
        if !errorlevel! equ 0 (
            set "PYTHON_EXE=%LOCALAPPDATA%\Programs\Python\%%v\python.exe"
            goto :found_python
        )
    )
    if exist "C:\%%v\python.exe" (
        "C:\%%v\python.exe" -c "import fastapi, paddleocr" >nul 2>nul
        if !errorlevel! equ 0 (
            set "PYTHON_EXE=C:\%%v\python.exe"
            goto :found_python
        )
    )
)

:: Second priority: Any Python >= 3.10 (will install requirements if needed)
for %%v in (Python313 Python312 Python311 Python310) do (
    if exist "%LOCALAPPDATA%\Programs\Python\%%v\python.exe" (
        set "PYTHON_EXE=%LOCALAPPDATA%\Programs\Python\%%v\python.exe"
        goto :check_deps
    )
    if exist "C:\%%v\python.exe" (
        set "PYTHON_EXE=C:\%%v\python.exe"
        goto :check_deps
    )
)

where py >nul 2>nul
if %errorlevel% equ 0 (
    py -3 -c "import sys; exit(0 if sys.version_info >= (3, 10) and sys.maxsize > 2**32 else 1)" >nul 2>nul
    if !errorlevel! equ 0 (
        set "PYTHON_EXE=py"
        goto :check_deps
    )
)

where python >nul 2>nul
if %errorlevel% equ 0 (
    python -c "import sys; exit(0 if sys.version_info >= (3, 10) and sys.maxsize > 2**32 else 1)" >nul 2>nul
    if !errorlevel! equ 0 (
        set "PYTHON_EXE=python"
        goto :check_deps
    )
)

:missing_python
echo [Env] No valid Python 3.10+ (64-bit) found. Installing Python 3.12...
call "%~dp0scripts\setup_environment.bat"
for %%v in (Python313 Python312 Python311 Python310) do (
    if exist "%LOCALAPPDATA%\Programs\Python\%%v\python.exe" set "PYTHON_EXE=%LOCALAPPDATA%\Programs\Python\%%v\python.exe"
)

:check_deps
"!PYTHON_EXE!" -c "import fastapi, paddleocr" >nul 2>nul
if !errorlevel! neq 0 (
    echo [Env] Installing OCR dependencies into !PYTHON_EXE!...
    "!PYTHON_EXE!" -m pip install -r "%~dp0requirements.txt" -i https://pypi.tuna.tsinghua.edu.cn/simple --trusted-host pypi.tuna.tsinghua.edu.cn
)

:found_python
echo [Env] Using Python: !PYTHON_EXE!

netstat -ano | findstr /R /C:":8766 " >nul
if %errorlevel% neq 0 (
    echo Starting OCR Worker...
    start "OCR-Worker" /min cmd /c "!PYTHON_EXE! \"%~dp0ocr-worker\main.py\""
    ping 127.0.0.1 -n 3 >nul
)

echo Launching Desktop Application...
start "" "%~dp0build\HandwritingOCR.exe"

endlocal
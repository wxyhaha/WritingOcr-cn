@echo off
setlocal
cd /d "%~dp0"

set "APP_ROOT=%~dp0"
set "PYTHON_EXE=%APP_ROOT%runtime\python\python.exe"
set "MODEL_CACHE=%APP_ROOT%runtime\models\paddlex"

if not exist "%APP_ROOT%HandwritingOCR.exe" (
    echo [Error] HandwritingOCR.exe was not found.
    pause
    exit /b 1
)

if exist "%APP_ROOT%vc_redist.x64.exe" if not exist "%WINDIR%\System32\vcruntime140_1.dll" (
    echo Installing Microsoft Visual C++ runtime...
    start /wait "" "%APP_ROOT%vc_redist.x64.exe" /install /quiet /norestart
)

if not exist "%PYTHON_EXE%" (
    echo [Error] Bundled Python runtime is missing.
    call "%APP_ROOT%diagnose-release.bat"
    pause
    exit /b 1
)

set "PYTHON_EXECUTABLE=%PYTHON_EXE%"
set "PADDLE_PDX_CACHE_HOME=%MODEL_CACHE%"
set "PATH=%APP_ROOT%runtime\python;%APP_ROOT%runtime\python\Scripts;%PATH%"

"%PYTHON_EXE%" -c "import fastapi, paddle, paddleocr, paddlex, docx" >nul 2>nul
if errorlevel 1 (
    echo [Error] Bundled OCR runtime is incomplete.
    call "%APP_ROOT%diagnose-release.bat"
    pause
    exit /b 1
)

start "" "%APP_ROOT%HandwritingOCR.exe"
endlocal

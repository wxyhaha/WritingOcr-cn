@echo off
setlocal
cd /d "%~dp0"

set "PYTHON_EXE=%~dp0runtime\python\python.exe"
set "MODEL_CACHE=%~dp0runtime\models\paddlex"

echo ============================================================
echo HandwritingOCR release diagnostics
echo ============================================================
echo Install directory: %~dp0
echo.

if not exist "%~dp0HandwritingOCR.exe" echo [FAIL] Desktop executable is missing.
if exist "%~dp0vc_redist.x64.exe" (echo [ OK ] VC++ redistributable is bundled.) else (echo [WARN] VC++ redistributable is missing.)
if exist "%PYTHON_EXE%" (echo [ OK ] Bundled Python is present.) else (echo [FAIL] Bundled Python is missing.)
if exist "%MODEL_CACHE%" (echo [ OK ] PaddleX model cache is present.) else (echo [WARN] PaddleX model cache is missing; first OCR may need internet.)

if exist "%PYTHON_EXE%" (
    "%PYTHON_EXE%" -c "import sys; print('[INFO] Python:', sys.version); import fastapi, paddle, paddleocr, paddlex, docx; print('[ OK ] OCR dependencies import successfully.')"
    if errorlevel 1 echo [FAIL] OCR dependency import failed.
)

echo.
echo Application logs: %%USERPROFILE%%\Documents\HandwritingOCR\logs\app.log
echo OCR worker port: 127.0.0.1:18766
echo LAN upload port: 18765
echo.
pause
endlocal

@echo off
setlocal
cd /d "%~dp0"

echo ====================================================
echo   Handwriting Chinese OCR Digitalizer (MVP)
echo ====================================================
echo.

:: 1. Locate Python interpreter
set "PYTHON_EXE=py"
if exist "C:\Users\Administrator\AppData\Local\Programs\Python\Python313\python.exe" (
    set "PYTHON_EXE=C:\Users\Administrator\AppData\Local\Programs\Python\Python313\python.exe"
)

:: 2. Check and start Python OCR Worker if not running
netstat -ano | findstr /R /C:":8766 " >nul
if %errorlevel% neq 0 (
    echo [1/2] Starting OCR Worker on port 8766...
    start "OCR-Worker" /min "%PYTHON_EXE%" "%~dp0ocr-worker\main.py"
    ping 127.0.0.1 -n 4 >nul
) else (
    echo [1/2] OCR Worker is already running on port 8766.
)

:: 3. Start Desktop App
echo [2/2] Launching Desktop App...
start "" "%~dp0build\HandwritingOCR.exe"

echo.
echo Application started successfully!
endlocal

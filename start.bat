@echo off
setlocal
cd /d "%~dp0"

echo ====================================================
echo   Handwriting Chinese OCR Digitalizer (MVP)
echo ====================================================
echo.
echo Launching Application...
start "" "%~dp0build\HandwritingOCR.exe"

endlocal

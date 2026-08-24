@echo off
setlocal
cd /d "%~dp0"

echo ====================================================
echo   Build and Run Handwriting Chinese OCR Digitalizer
echo ====================================================
echo.

call "%ProgramFiles%\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" 10.0.26100.0

set PATH=C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\14.44.35207\bin\Hostx64\x64;C:\Program Files (x86)\Windows Kits\10\bin\10.0.26100.0\x64;C:\Qt\6.5.3\msvc2019_64\bin;C:\Users\Administrator\AppData\Roaming\Python\Python313\Scripts;C:\Users\Administrator\AppData\Local\Programs\Python\Python313\Scripts;%PATH%

echo [1/3] Building C++ application...
cmake --build build --config Release
if %errorlevel% neq 0 (
    echo Build failed!
    pause
    exit /b %errorlevel%
)

echo.
echo [2/3] Checking OCR Worker...
netstat -ano | findstr /R /C:":8766 " >nul
if %errorlevel% neq 0 (
    echo Starting OCR Worker...
    start "OCR-Worker" /min py -3.13 ocr-worker/main.py
    ping 127.0.0.1 -n 3 >nul
)

echo.
echo [3/3] Launching Desktop App...
start "" "build\HandwritingOCR.exe"
endlocal

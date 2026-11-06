@echo off
setlocal EnableDelayedExpansion

title Windows Node.js, npm ve Git Kurulumu

:: 1. Yonetici Yetkisi Kontrolu
openfiles >nul 2>&1
if '%errorlevel%' NEQ '0' (
    echo [BILGI] Yonetici (Administrator) yetkisi isteniyor...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -ArgumentList '%*' -Verb RunAs"
    exit /b
)

:: 2. Calisma Dizinine Gec
cd /d "%~dp0"

echo ==========================================================
echo     Windows Node.js, npm ve Git Otomatik Kurulumu
echo ==========================================================
echo.

:: 3. PowerShell Kurulum Scriptini Calistir
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-node.ps1" %*

set SCRIPT_EXIT_CODE=%errorlevel%

echo.
if %SCRIPT_EXIT_CODE% EQU 0 (
    echo [BASARILI] Islem tamamlandi.
) else (
    echo [HATA] Kurulum sirasinda bir hata olustu. Hata Kodu: %SCRIPT_EXIT_CODE%
)

echo.
pause
exit /b %SCRIPT_EXIT_CODE%


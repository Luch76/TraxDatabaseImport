@echo off
setlocal

echo =============================================
echo TRAX import pipeline started at %date% %time%
echo =============================================
echo.

call run-01.bat
if errorlevel 1 (
    echo run-01.bat failed. Exiting.
    echo Failed at %date% %time%
    exit /b 1
)

call run-02.bat
if errorlevel 1 (
    echo run-02.bat failed. Exiting.
    echo Failed at %date% %time%
    exit /b 1
)

echo.
echo =============================================
echo TRAX import pipeline finished at %date% %time%
echo =============================================
echo Both scripts executed successfully.
exit /b 0

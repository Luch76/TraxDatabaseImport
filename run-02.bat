@echo off
setlocal enabledelayedexpansion

REM Read environment variables from env.ini
for /f "tokens=1,* delims==" %%A in (env.ini) do (
    if "%%A"=="CONTAINER_NAME" set "CONTAINER_NAME=%%B"
    if "%%A"=="FILE_DMP_ZIP" set "FILE_DMP_ZIP=%%B"
    if "%%A"=="DB_CONNECT" set "DB_CONNECT=%%B"
    if "%%A"=="DB_SYS_CONNECT" set "DB_SYS_CONNECT=%%B"
)

REM Normalize optional quotes in env.ini values.
set "DB_CONNECT=%DB_CONNECT:"=%"
set "DB_SYS_CONNECT=%DB_SYS_CONNECT:"=%"

if not defined CONTAINER_NAME (
    echo Missing required setting CONTAINER_NAME in env.ini
    exit /b 1
)
if not defined FILE_DMP_ZIP (
    echo Missing required setting FILE_DMP_ZIP in env.ini
    exit /b 1
)
if not defined DB_CONNECT (
    echo Missing required setting DB_CONNECT in env.ini
    exit /b 1
)

set "FOLDER_DMP=/opt/oracle/dmp"

REM Match the filename inside /opt/oracle/dmp where run-01 copied the zip
for %%F in ("!FILE_DMP_ZIP!") do set "DMP_ZIP_CONTAINER_NAME=%%~nxF"

REM Ensure the phase-1 container exists and is running
docker inspect "%CONTAINER_NAME%" >nul 2>&1
if errorlevel 1 (
    echo Container '%CONTAINER_NAME%' not found. Run run-01.bat first.
    exit /b 1
)

docker start "%CONTAINER_NAME%" >nul 2>&1

REM Copy phase-2 assets into the existing container
docker cp imp02.sh %CONTAINER_NAME%:%FOLDER_DMP%/
docker cp imp-data.ini %CONTAINER_NAME%:%FOLDER_DMP%/
docker cp env.ini %CONTAINER_NAME%:%FOLDER_DMP%/
docker cp disable-fk-triggers.sql %CONTAINER_NAME%:%FOLDER_DMP%/
docker cp enable-fk-triggers.sql %CONTAINER_NAME%:%FOLDER_DMP%/
docker cp "300 - Shrink UndoTablespace.sql" %CONTAINER_NAME%:%FOLDER_DMP%/

REM Wait until Oracle service FREEPDB1 is reachable before running import steps
echo Waiting for Oracle service to become ready...
set "MAX_WAIT_SECONDS=300"
set "SLEEP_SECONDS=3"
set /a "MAX_ATTEMPTS=MAX_WAIT_SECONDS/SLEEP_SECONDS"
if !MAX_ATTEMPTS! lss 1 set "MAX_ATTEMPTS=1"
set "ATTEMPT=0"

:wait_loop
docker exec "%CONTAINER_NAME%" bash -lc "echo 'exit' | sqlplus -L -s '!DB_CONNECT!' >/dev/null 2>&1"
if %errorlevel% equ 0 (
    echo Oracle is ready.
    goto oracle_ready
)

set /a ATTEMPT+=1
if !ATTEMPT! geq !MAX_ATTEMPTS! (
    echo Timed out waiting for Oracle service after %MAX_WAIT_SECONDS%s
    exit /b 1
)

timeout /t 3 /nobreak
goto wait_loop

:oracle_ready
REM Convert to LF in the container in case this file was copied with CRLF from Windows.
docker exec -u root "%CONTAINER_NAME%" bash -lc "sed -i 's/\r$//' %FOLDER_DMP%/imp02.sh"
if errorlevel 1 (
    echo Failed to normalize imp02.sh line endings inside container.
    exit /b 1
)
docker exec -u root "%CONTAINER_NAME%" bash -lc "sed -i 's/\r$//' %FOLDER_DMP%/env.ini"
if errorlevel 1 (
    echo Failed to normalize env.ini line endings inside container.
    exit /b 1
)

REM Run phase 2 (data import) inside the existing container.
REM imp02.sh sources env.ini in the container, so avoid passing credentials
REM through docker exec where cmd.exe quoting is fragile.
docker exec -u root "%CONTAINER_NAME%" bash "%FOLDER_DMP%/imp02.sh"
set "PHASE2_RC=%ERRORLEVEL%"
if not "%PHASE2_RC%"=="0" (
    echo Phase 2 import failed with exit code %PHASE2_RC%.
    exit /b %PHASE2_RC%
)

REM Delete the unzipped dmp files
docker exec -u root "!CONTAINER_NAME!" bash -c "rm -rf !FOLDER_DMP!/*.dmp"
if errorlevel 1 (
    echo Failed to clean up extracted .dmp files.
    exit /b 1
)

endlocal



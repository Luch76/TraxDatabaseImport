@echo off
setlocal enabledelayedexpansion

REM Read environment variables from env.ini
for /f "tokens=1,* delims==" %%A in (env.ini) do (
    if "%%A"=="CONTAINER_NAME" set "CONTAINER_NAME=%%B"
    if "%%A"=="FILE_DMP_ZIP" set "FILE_DMP_ZIP=%%B"
    if "%%A"=="DB_CONNECT" set "DB_CONNECT=%%B"
    if "%%A"=="DB_SYS_CONNECT" set "DB_SYS_CONNECT=%%B"
)

set "FOLDER_DMP=/opt/oracle/dmp"

REM Match the filename inside /opt/oracle/dmp where run-01 copied the zip
for %%F in ("!FILE_DMP_ZIP!") do set "DMP_ZIP_CONTAINER_NAME=%%~nxF"

REM Ensure the phase-1 container exists and is running
docker ps -a --format "{{.Names}}" | findstr /R "^%CONTAINER_NAME%$" >nul 2>&1
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

for /f "tokens=1-4 delims=/:.," %%a in ('wmic os get LocalDateTime ^| findstr [0-9]') do (
    set "START_TIME=%%a%%b%%c%%d"
)

:wait_loop
docker exec "%CONTAINER_NAME%" bash -lc "echo 'exit' | sqlplus -L -s '!DB_CONNECT!' >nul 2>&1"
if %errorlevel% equ 0 (
    echo Oracle is ready.
    goto oracle_ready
)

REM Calculate elapsed time
for /f "tokens=1-4 delims=/:.," %%a in ('wmic os get LocalDateTime ^| findstr [0-9]') do (
    set "NOW=%%a%%b%%c%%d"
)

REM Simple time comparison (this is a limitation of batch - may need adjustment for complex timing)
if %NOW% geq %START_TIME% (
    set /a ELAPSED=NOW-START_TIME
    if !ELAPSED! geq %MAX_WAIT_SECONDS% (
        echo Timed out waiting for Oracle service after %MAX_WAIT_SECONDS%s
        exit /b 1
    )
)

timeout /t 3 /nobreak
goto wait_loop

:oracle_ready
REM Run phase 2 (data import) inside the existing container
docker exec -u root -it ^
    -e FILE_DMP_ZIP="!DMP_ZIP_CONTAINER_NAME!" ^
    -e ORACLE_CONNECT_STRING="!DB_CONNECT!" ^
    -e ORACLE_SYS_CONNECT="!DB_SYS_CONNECT!" ^
    "%CONTAINER_NAME%" bash "%FOLDER_DMP%/imp02.sh"

REM Delete the unzipped dmp files
docker exec -u root -it "%CONTAINER_NAME%" bash -c "rm -rf %FOLDER_DMP%/*.dmp"

endlocal



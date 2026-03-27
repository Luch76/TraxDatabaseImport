@echo off
setlocal enabledelayedexpansion

REM Read environment variables from env.ini
for /f "tokens=1,* delims==" %%A in (env.ini) do (
    if "%%A"=="CONTAINER_NAME" set "CONTAINER_NAME=%%B"
    if "%%A"=="FILE_DMP_ZIP" set "FILE_DMP_ZIP=%%B"
    if "%%A"=="PORT" set "PORT=%%B"
    if "%%A"=="DB_CONNECT" set "DB_CONNECT=%%B"
    if "%%A"=="SCHEMA_OWNER" set "SCHEMA_OWNER=%%B"
)

set "FOLDER_DMP=/opt/oracle/dmp"

REM Support FILE_DMP_ZIP as either relative (alaska\file.zip) or full path
set "DMP_ZIP_HOST_PATH=%FILE_DMP_ZIP%"
if not exist "!DMP_ZIP_HOST_PATH!" (
    if exist ".!FILE_DMP_ZIP!" (
        set "DMP_ZIP_HOST_PATH=.!FILE_DMP_ZIP!"
    )
)

if not exist "!DMP_ZIP_HOST_PATH!" (
    echo Dump zip not found: '!FILE_DMP_ZIP!'
    echo Expected an existing file path relative to this folder, for example: alaska\AS_ODB_Dump.zip
    exit /b 1
)

REM Get just the filename (basename) of the zip file
for %%F in ("!DMP_ZIP_HOST_PATH!") do set "DMP_ZIP_CONTAINER_NAME=%%~nxF"

REM Drop existing container if it exists
for /f "tokens=*" %%A in ('docker ps -aq -f name=%CONTAINER_NAME%') do (
    echo Container %CONTAINER_NAME% already exists. Removing it...
    docker rm -f %CONTAINER_NAME%
)

REM Create the database container for phase 1 (structure import)
docker run -d --name %CONTAINER_NAME% -p %PORT%:1521 -e ORACLE_PASSWORD=traxlocal gvenzl/oracle-free:23-full ^
    -e FILE_DMP_ZIP="!DMP_ZIP_CONTAINER_NAME!" ^
    -e ORACLE_CONNECT_STRING="!DB_CONNECT!" ^
    -e SCHEMA_OWNER="!SCHEMA_OWNER!"

docker exec %CONTAINER_NAME% rm -rf %FOLDER_DMP%
docker exec %CONTAINER_NAME% mkdir -p %FOLDER_DMP%

REM Copy export dump files to the container
docker cp "!DMP_ZIP_HOST_PATH!" "%CONTAINER_NAME%:%FOLDER_DMP%/"

docker cp imp01.sh %CONTAINER_NAME%:%FOLDER_DMP%/
docker cp imp-structure.ini %CONTAINER_NAME%:%FOLDER_DMP%/
docker cp env.ini %CONTAINER_NAME%:%FOLDER_DMP%/
docker cp "100 - Create User.sql" %CONTAINER_NAME%:%FOLDER_DMP%/
docker cp "125 - Grant as SYS.sql" %CONTAINER_NAME%:%FOLDER_DMP%/
docker cp "175 - traxdoc link.sql" %CONTAINER_NAME%:%FOLDER_DMP%/

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
REM Run phase 1 script inside the container as root user
docker exec -u root -it ^
    -e FILE_DMP_ZIP="!DMP_ZIP_CONTAINER_NAME!" ^
    %CONTAINER_NAME% bash %FOLDER_DMP%/imp01.sh

REM Cleanup: for gzip inputs, remove archive after extraction and keep .dmp files
if "!DMP_ZIP_CONTAINER_NAME:~-3!"==".gz" (
    docker exec -u root -it "%CONTAINER_NAME%" rm -f "%FOLDER_DMP%/!DMP_ZIP_CONTAINER_NAME!"
)

endlocal



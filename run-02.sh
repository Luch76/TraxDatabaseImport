#!/bin/bash

set -euo pipefail

# Read environment variables from env.ini
source env.ini

CONTAINER_NAME=$CONTAINER_NAME
FOLDER_DMP="/opt/oracle/dmp"

# Match the filename inside /opt/oracle/dmp where run-01 copied the zip.
DMP_ZIP_CONTAINER_NAME="$(basename "$FILE_DMP_ZIP")"

# Ensure the phase-1 container exists and is running
if ! docker ps -a --format '{{.Names}}' | grep -Fxq "$CONTAINER_NAME"; then
	echo "Container '$CONTAINER_NAME' not found. Run ./run-01.sh first."
	exit 1
fi

docker start "$CONTAINER_NAME" >/dev/null

# Copy phase-2 assets into the existing container
docker cp imp02.sh "$CONTAINER_NAME":"$FOLDER_DMP"/
docker cp imp-data.ini "$CONTAINER_NAME":"$FOLDER_DMP"/
docker cp env.ini "$CONTAINER_NAME":"$FOLDER_DMP"/
docker cp disable-fk-triggers.sql "$CONTAINER_NAME":"$FOLDER_DMP"/
docker cp enable-fk-triggers.sql "$CONTAINER_NAME":"$FOLDER_DMP"/
docker cp "300 - Shrink UndoTablespace.sql" "$CONTAINER_NAME":"$FOLDER_DMP"/

# Wait until Oracle service FREEPDB1 is reachable before running import steps.
echo "Waiting for Oracle service to become ready..."
MAX_WAIT_SECONDS=300
START_TIME=$(date +%s)
while true; do
	if docker exec "$CONTAINER_NAME" bash -lc "echo 'exit' | sqlplus -L -s '$DB_CONNECT' >/dev/null 2>&1"; then
		echo "Oracle is ready."
		break
	fi

	NOW=$(date +%s)
	ELAPSED=$((NOW - START_TIME))
	if [ "$ELAPSED" -ge "$MAX_WAIT_SECONDS" ]; then
		echo "Timed out waiting for Oracle service after ${MAX_WAIT_SECONDS}s"
		exit 1
	fi

	sleep 3
done

# Run phase 2 (data import) inside the existing container
docker exec -u root \
	-e FILE_DMP_ZIP="$DMP_ZIP_CONTAINER_NAME" \
	-e ORACLE_CONNECT_STRING="$DB_CONNECT" \
	-e ORACLE_SYS_CONNECT="${DB_SYS_CONNECT:-}" \
	"$CONTAINER_NAME" bash "$FOLDER_DMP"/imp02.sh

# Delete the unzipped dmp files
docker exec -u root "$CONTAINER_NAME" bash -c "rm -rf $FOLDER_DMP/*.dmp"



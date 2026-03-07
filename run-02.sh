#!/bin/bash

set -euo pipefail

# Read environment variables from env.ini
source env.ini

CONTAINER_NAME=$CONTAINER_NAME
FOLDER_DMP="/opt/oracle/dmp"

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

# Run phase 2 (data import) inside the existing container
docker exec -u root -it \
	-e FILE_DMP_ZIP="$FILE_DMP_ZIP" \
	-e ORACLE_CONNECT_STRING="$DB_CONNECT" \
	"$CONTAINER_NAME" bash "$FOLDER_DMP"/imp02.sh

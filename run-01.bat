#!/bin/bash

# Read environment variables from env.ini
source env.ini

CONTAINER_NAME=$CONTAINER_NAME
FOLDER_DMP="/opt/oracle/dmp"

# Support FILE_DMP_ZIP as either relative (alaska/file.zip) or slash-prefixed (/alaska/file.zip).
DMP_ZIP_HOST_PATH="$FILE_DMP_ZIP"
if [ ! -f "$DMP_ZIP_HOST_PATH" ] && [[ "$DMP_ZIP_HOST_PATH" == /* ]] && [ -f ".${DMP_ZIP_HOST_PATH}" ]; then
	DMP_ZIP_HOST_PATH=".${DMP_ZIP_HOST_PATH}"
fi

if [ ! -f "$DMP_ZIP_HOST_PATH" ]; then
	echo "Dump zip not found: '$FILE_DMP_ZIP'"
	echo "Expected an existing file path relative to this folder, for example: alaska/AS_ODB_Dump.zip"
	exit 1
fi

# Inside the container, the file is copied to /opt/oracle/dmp/<basename>.
DMP_ZIP_CONTAINER_NAME="$(basename "$DMP_ZIP_HOST_PATH")"

# Drop existing container if it exists
if [ "$(docker ps -aq -f name=$CONTAINER_NAME)" ]; then
	echo "Container $CONTAINER_NAME already exists. Removing it..."
	docker rm -f $CONTAINER_NAME
fi

# Create the database container for phase 1 (structure import)
docker run -d --name $CONTAINER_NAME -p $PORT:1521 -e ORACLE_PASSWORD=traxlocal gvenzl/oracle-free:23-full \
-e FILE_DMP_ZIP="$DMP_ZIP_CONTAINER_NAME" \
-e ORACLE_CONNECT_STRING="$DB_CONNECT" \
-e SCHEMA_OWNER="$SCHEMA_OWNER"
    
docker exec $CONTAINER_NAME rm -rf $FOLDER_DMP
docker exec $CONTAINER_NAME mkdir -p $FOLDER_DMP

# Copy export dump files to the container
docker cp "$DMP_ZIP_HOST_PATH" "$CONTAINER_NAME":"$FOLDER_DMP"/

docker cp imp01.sh $CONTAINER_NAME:$FOLDER_DMP/
docker cp imp-structure.ini $CONTAINER_NAME:$FOLDER_DMP/
docker cp env.ini $CONTAINER_NAME:$FOLDER_DMP/
docker cp "100 - Create User.sql" $CONTAINER_NAME:$FOLDER_DMP/
docker cp "125 - Grant as SYS.sql" $CONTAINER_NAME:$FOLDER_DMP/
docker cp "175 - traxdoc link.sql" $CONTAINER_NAME:$FOLDER_DMP/

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

# Run phase 1 script inside the container as root user
docker exec -u root -it \
	-e FILE_DMP_ZIP="$DMP_ZIP_CONTAINER_NAME" \
	$CONTAINER_NAME bash $FOLDER_DMP/imp01.sh

# Cleanup: for gzip inputs, remove archive after extraction and keep .dmp files.
if [[ "$DMP_ZIP_CONTAINER_NAME" == *.gz ]]; then
	docker exec -u root -it "$CONTAINER_NAME" rm -f "$FOLDER_DMP/$DMP_ZIP_CONTAINER_NAME"
fi



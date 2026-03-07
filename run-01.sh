#!/bin/bash

# Read environment variables from env.ini
source env.ini

CONTAINER_NAME=$CONTAINER_NAME
FOLDER_DMP="/opt/oracle/dmp"

# Drop existing container if it exists
if [ "$(docker ps -aq -f name=$CONTAINER_NAME)" ]; then
	echo "Container $CONTAINER_NAME already exists. Removing it..."
	docker rm -f $CONTAINER_NAME
fi

# Create the database container for phase 1 (structure import)
docker run -d --name $CONTAINER_NAME -p $PORT:1521 -e ORACLE_PASSWORD=traxlocal gvenzl/oracle-free:23-full \
-e FILE_DMP_ZIP="$FILE_DMP_ZIP" \
-e ORACLE_CONNECT_STRING="$DB_CONNECT" \
-e SCHEMA_OWNER="$SCHEMA_OWNER"
    
docker exec $CONTAINER_NAME rm -rf $FOLDER_DMP
docker exec $CONTAINER_NAME mkdir -p $FOLDER_DMP

# Copy export dump files to the container
docker cp $FILE_DMP_ZIP $CONTAINER_NAME:$FOLDER_DMP/

docker cp imp01.sh $CONTAINER_NAME:$FOLDER_DMP/
docker cp imp-structure.ini $CONTAINER_NAME:$FOLDER_DMP/
docker cp env.ini $CONTAINER_NAME:$FOLDER_DMP/
docker cp "100 - Create User.sql" $CONTAINER_NAME:$FOLDER_DMP/
docker cp "125 - Grant as SYS.sql" $CONTAINER_NAME:$FOLDER_DMP/
docker cp "175 - traxdoc link.sql" $CONTAINER_NAME:$FOLDER_DMP/

# Run phase 1 script inside the container as root user
docker exec -u root -it \
	-e FILE_DMP_ZIP="$FILE_DMP_ZIP" \
	$CONTAINER_NAME bash $FOLDER_DMP/imp01.sh

# Cleanup: remove compressed dump, keep extracted .dmp for phase 2 data import
docker exec -u root -it $CONTAINER_NAME rm -f $FOLDER_DMP/$FILE_DMP_ZIP



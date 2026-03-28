#!/bin/bash

set -euo pipefail

# Load optional environment values copied from host.
if [ -f /opt/oracle/dmp/env.ini ]; then
	# Windows copies can preserve CRLF; normalize before sourcing.
	sed -i 's/\r$//' /opt/oracle/dmp/env.ini
	source /opt/oracle/dmp/env.ini
fi

: "${FILE_DMP_ZIP:?FILE_DMP_ZIP is required (e.g. expdp_xxx.dmp.gz)}"
: "${SCHEMA_OWNER:?SCHEMA_OWNER is required}"
DB_CONNECT="${ORACLE_CONNECT_STRING:-system/traxlocal@FREEPDB1}"
SYS_CONNECT="${ORACLE_SYS_CONNECT:-sys/traxlocal@FREEPDB1 as sysdba}"
SCHEMA_CONNECT="${ORACLE_SCHEMA_CONNECT:-$SCHEMA_OWNER/$SCHEMA_OWNER@FREEPDB1}"

# env.ini may contain a host path (for example alaska/file.zip). Inside the
# container, the archive is copied under /opt/oracle/dmp using its basename.
if [ ! -f "$FILE_DMP_ZIP" ] && [ -f "/opt/oracle/dmp/$(basename "$FILE_DMP_ZIP")" ]; then
	FILE_DMP_ZIP="$(basename "$FILE_DMP_ZIP")"
fi

run_impdp_allow_warnings() {
	set +e
	"$@"
	rc=$?
	set -e
	if [ "$rc" -ne 0 ] && [ "$rc" -ne 5 ]; then
		echo "impdp failed with exit code $rc"
		exit "$rc"
	fi
	if [ "$rc" -eq 5 ]; then
		echo "impdp completed with warnings (exit code 5); continuing"
	fi
}

# Navigate to the dmp directory
cd /opt/oracle/dmp

# Unzip dump file if gz is present
if [[ "$FILE_DMP_ZIP" == *.gz ]] && [ -f "$FILE_DMP_ZIP" ]; then
	gunzip -f "$FILE_DMP_ZIP"
fi

# Extract dump files if a zip archive is provided.
if [[ "$FILE_DMP_ZIP" == *.zip ]] && [ -f "$FILE_DMP_ZIP" ]; then
	unzip -o "$FILE_DMP_ZIP"
fi

echo "All files unzipped successfully"

DMP_FILE="${FILE_DMP_ZIP%.gz}"

if [[ "$FILE_DMP_ZIP" == *.zip ]]; then
	DMP_FILE=""
fi

# Set read permissions on the unzipped files
if [ -n "$DMP_FILE" ] && [ -f "$DMP_FILE" ]; then
	chmod 644 "$DMP_FILE"
fi

if ls -1 *.dmp >/dev/null 2>&1; then
	chmod 644 ./*.dmp
fi

# Step 0: create target users/directories before import (run as SYS).
sqlplus -s "$SYS_CONNECT" <<EOF
WHENEVER SQLERROR EXIT SQL.SQLCODE
DEFINE SCHEMA_OWNER=$SCHEMA_OWNER
@"/opt/oracle/dmp/100 - Create User.sql"
@"/opt/oracle/dmp/125 - Grant as SYS.sql"
EXIT
EOF

# Step 0b: connect as schema owner and run schema-level link script.
sqlplus -s "$SCHEMA_CONNECT" <<EOF
WHENEVER SQLERROR EXIT SQL.SQLCODE
DEFINE SCHEMA_OWNER=$SCHEMA_OWNER
@"/opt/oracle/dmp/175 - traxdoc link.sql"
EXIT
EOF

# Step 1: import DB structure only (no data)
run_impdp_allow_warnings impdp "$DB_CONNECT" parfile=imp-structure.ini

echo "Structure import completed successfully"

#!/bin/bash

set -euo pipefail

# Load optional environment values copied from host.
if [ -f /opt/oracle/dmp/env.ini ]; then
	source /opt/oracle/dmp/env.ini
fi

: "${FILE_DMP_ZIP:?FILE_DMP_ZIP is required (e.g. expdp_xxx.dmp.gz)}"
: "${SCHEMA_OWNER:?SCHEMA_OWNER is required}"
DB_CONNECT="${ORACLE_CONNECT_STRING:-system/traxlocal@FREEPDB1}"
SYS_CONNECT="${ORACLE_SYS_CONNECT:-sys/traxlocal@FREEPDB1 as sysdba}"

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

echo "All files unzipped successfully"

DMP_FILE="${FILE_DMP_ZIP%.gz}"

# Set read permissions on the unzipped files
chmod 644 "$DMP_FILE"

# Step 0: create target users/directories before import (run as SYS).
sqlplus -s "$SYS_CONNECT" <<EOF
WHENEVER SQLERROR EXIT SQL.SQLCODE
DEFINE TRAX_SCHEMA=$SCHEMA_OWNER
@"/opt/oracle/dmp/100 - Create User.sql"
EXIT
EOF

# Step 1: import DB structure only (no data)
run_impdp_allow_warnings impdp "$DB_CONNECT" parfile=imp-structure.ini

echo "Structure import completed successfully"

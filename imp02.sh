#!/bin/bash

set -euo pipefail

# Load optional environment values copied from host.
if [ -f /opt/oracle/dmp/env.ini ]; then
	source /opt/oracle/dmp/env.ini
fi

SYSTEM_CONNECT="${ORACLE_CONNECT_STRING:-system/traxlocal@FREEPDB1}"
: "${SCHEMA_OWNER:?SCHEMA_OWNER is required}"
SCHEMA_CONNECT="${ORACLE_SCHEMA_CONNECT:-$SCHEMA_OWNER/$SCHEMA_OWNER@FREEPDB1}"

if [[ ! "$SYSTEM_CONNECT" =~ ^[sS][yY][sS][tT][eE][m]/ ]]; then
	echo "ORACLE_CONNECT_STRING must use SYSTEM user (example: system/password@service)"
	exit 1
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

cd /opt/oracle/dmp

# Make sure dump file exists for phase 2 import.
if [ -n "${FILE_DMP_ZIP:-}" ] && [[ "$FILE_DMP_ZIP" == *.gz ]] && [ -f "$FILE_DMP_ZIP" ]; then
	gunzip -f "$FILE_DMP_ZIP"
fi

DMP_FILE="${FILE_DMP_ZIP%.gz}"
if [ ! -f "$DMP_FILE" ]; then
	echo "Required dump file '$DMP_FILE' not found in /opt/oracle/dmp"
	exit 1
fi

chmod 644 "$DMP_FILE"

# Disable FK constraints and triggers before data load.
sqlplus -s "$SCHEMA_CONNECT" @disable-fk-triggers.sql

# Import data only.
run_impdp_allow_warnings impdp "$SYSTEM_CONNECT" parfile=imp-data.ini

# Re-enable FK constraints and triggers after data load.
sqlplus -s "$SCHEMA_CONNECT" @enable-fk-triggers.sql

echo "Data import completed successfully"

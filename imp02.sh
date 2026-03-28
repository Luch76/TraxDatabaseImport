#!/bin/bash

set -euo pipefail

# Load optional environment values copied from host.
if [ -f /opt/oracle/dmp/env.ini ]; then
	# Windows copies can preserve CRLF; normalize before sourcing.
	sed -i 's/\r$//' /opt/oracle/dmp/env.ini
	source /opt/oracle/dmp/env.ini
fi

SYSTEM_CONNECT="${ORACLE_CONNECT_STRING:-system/traxlocal@FREEPDB1}"
: "${SCHEMA_OWNER:?SCHEMA_OWNER is required}"
SCHEMA_CONNECT="${ORACLE_SCHEMA_CONNECT:-$SCHEMA_OWNER/$SCHEMA_OWNER@FREEPDB1}"
DEFAULT_SYS_CONNECT="$(echo "$SYSTEM_CONNECT" | sed -E 's/^[sS][yY][sS][tT][eE][m]/sys/') as sysdba"
SYS_CONNECT="${ORACLE_SYS_CONNECT:-$DEFAULT_SYS_CONNECT}"

if [[ ! "$SYSTEM_CONNECT" =~ ^[sS][yY][sS][tT][eE][m]/ ]]; then
	echo "ORACLE_CONNECT_STRING must use SYSTEM user (example: system/password@service)"
	exit 1
fi

if [[ ! "$SYS_CONNECT" =~ ^[sS][yY][sS]/ ]]; then
	echo "ORACLE_SYS_CONNECT must use SYS user (example: sys/password@service as sysdba)"
	exit 1
fi

# env.ini may contain a host path (for example alaska/file.zip). Inside the
# container, the archive is copied under /opt/oracle/dmp using its basename.
if [ -n "${FILE_DMP_ZIP:-}" ] && [ ! -f "$FILE_DMP_ZIP" ] && [ -f "/opt/oracle/dmp/$(basename "$FILE_DMP_ZIP")" ]; then
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

run_sqlplus_script() {
	connect_string="$1"
	script_path="$2"
	sqlplus -L -s "$connect_string" <<SQL
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT SQL.SQLCODE
@"$script_path"
EXIT
SQL
}

cd /opt/oracle/dmp

# Make sure dump file exists for phase 2 import.
if [ -n "${FILE_DMP_ZIP:-}" ] && [[ "$FILE_DMP_ZIP" == *.gz ]] && [ -f "$FILE_DMP_ZIP" ]; then
	gunzip -f "$FILE_DMP_ZIP"
fi

if [ -n "${FILE_DMP_ZIP:-}" ] && [[ "$FILE_DMP_ZIP" == *.zip ]] && [ -f "$FILE_DMP_ZIP" ]; then
	unzip -o "$FILE_DMP_ZIP"
fi

DMP_FILE="${FILE_DMP_ZIP%.gz}"
if [ -n "${FILE_DMP_ZIP:-}" ] && [[ "$FILE_DMP_ZIP" == *.zip ]]; then
	DMP_FILE=""
fi
if [ -f "$DMP_FILE" ]; then
	chmod 644 "$DMP_FILE"
elif ls -1 *.dmp >/dev/null 2>&1; then
	chmod 644 ./*.dmp
	echo "Archive '${FILE_DMP_ZIP:-<unset>}' not found; using existing extracted .dmp files"
else
	echo "Required dump archive '$DMP_FILE' not found in /opt/oracle/dmp and no .dmp files are available"
	exit 1
fi

# Disable FK constraints and triggers before data load.
run_sqlplus_script "$SCHEMA_CONNECT" "disable-fk-triggers.sql"

# Import data only.
run_impdp_allow_warnings impdp "$SYSTEM_CONNECT" parfile=imp-data.ini

# Re-enable FK constraints and triggers after data load.
run_sqlplus_script "$SCHEMA_CONNECT" "enable-fk-triggers.sql"

# Run post-import maintenance as SYS.
run_sqlplus_script "$SYS_CONNECT" "300 - Shrink UndoTablespace.sql"

echo "Data import completed successfully"

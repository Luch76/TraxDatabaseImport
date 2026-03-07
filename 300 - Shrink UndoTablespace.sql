-- 0) Connect as SYS in the correct container
ALTER SESSION SET CONTAINER=FREEPDB1;

-- 1) Sanity checks
SHOW PARAMETER undo;
SELECT tablespace_name, retention FROM dba_tablespaces WHERE tablespace_name='UNDOTBS1';

-- If this says GUARANTEE, disable it (prevents reuse)
ALTER TABLESPACE undotbs1 RETENTION NOGUARANTEE;

-- 2) Create a smaller UNDO TS (adjust size/maxsize to your limit)
CREATE UNDO TABLESPACE undotbs2
  DATAFILE '/opt/oracle/oradata/FREE/FREEPDB1/undotbs02.dbf'
  SIZE 1024M
  AUTOEXTEND ON NEXT 64M MAXSIZE 3072M;

-- 3) Switch UNDO to new TS
ALTER SYSTEM SET undo_tablespace=undotbs2 SCOPE=BOTH;

-- 4) Wait/check until old undo has no ACTIVE extents
SELECT status, ROUND(SUM(bytes)/1024/1024) mb
FROM dba_undo_extents
WHERE tablespace_name='UNDOTBS1'
GROUP BY status;

-- 5) Drop old big file
DROP TABLESPACE undotbs1 INCLUDING CONTENTS AND DATAFILES;

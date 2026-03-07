WHENEVER SQLERROR EXIT SQL.SQLCODE
SET SERVEROUTPUT ON

BEGIN
  FOR r IN (
    SELECT owner, table_name, constraint_name
    FROM dba_constraints
    WHERE owner = 'ODB'
      AND constraint_type = 'R'
      AND status = 'ENABLED'
  ) LOOP
    EXECUTE IMMEDIATE
      'ALTER TABLE "' || r.owner || '"."' || r.table_name ||
      '" DISABLE CONSTRAINT "' || r.constraint_name || '"';
  END LOOP;

  FOR t IN (
    SELECT owner, trigger_name
    FROM dba_triggers
    WHERE owner = 'ODB'
      AND status = 'ENABLED'
  ) LOOP
    EXECUTE IMMEDIATE
      'ALTER TRIGGER "' || t.owner || '"."' || t.trigger_name || '" DISABLE';
  END LOOP;
END;
/

EXIT
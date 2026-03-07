WHENEVER SQLERROR EXIT SQL.SQLCODE
SET SERVEROUTPUT ON

BEGIN
  FOR t IN (
    SELECT trigger_name
    FROM user_triggers
    WHERE status = 'DISABLED'
  ) LOOP
    EXECUTE IMMEDIATE
      'ALTER TRIGGER "' || t.trigger_name || '" ENABLE';
  END LOOP;

  FOR r IN (
    SELECT table_name, constraint_name
    FROM user_constraints
    WHERE constraint_type = 'R'
      AND status = 'DISABLED'
  ) LOOP
    EXECUTE IMMEDIATE
      'ALTER TABLE "' || r.table_name ||
      '" ENABLE NOVALIDATE CONSTRAINT "' || r.constraint_name || '"';
  END LOOP;
END;
/

EXIT
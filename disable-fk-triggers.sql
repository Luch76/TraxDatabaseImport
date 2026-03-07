WHENEVER SQLERROR EXIT SQL.SQLCODE
SET SERVEROUTPUT ON

BEGIN
  FOR r IN (
    SELECT table_name, constraint_name
    FROM user_constraints
    WHERE constraint_type = 'R'
      AND status = 'ENABLED'
  ) LOOP
    EXECUTE IMMEDIATE
      'ALTER TABLE "' || r.table_name ||
      '" DISABLE CONSTRAINT "' || r.constraint_name || '"';
  END LOOP;

  FOR t IN (
    SELECT trigger_name
    FROM user_triggers
    WHERE status = 'ENABLED'
  ) LOOP
    EXECUTE IMMEDIATE
      'ALTER TRIGGER "' || t.trigger_name || '" DISABLE';
  END LOOP;
END;
/

EXIT
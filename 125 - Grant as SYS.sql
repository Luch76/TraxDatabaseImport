-- This SQL must be run as the SYS user.
-- It is safe to re-run.
DEFINE ODB=&TRAX_SCHEMA
set echo on
show user;

Grant CONNECT TO "&ODB";
Grant RESOURCE TO "&ODB";
GRANT CREATE DATABASE LINK TO "&ODB";
GRANT EXECUTE     ON  "SYS"."DBMS_ALERT" TO "&ODB";
GRANT EXECUTE     ON  "SYS"."DBMS_SESSION" TO "&ODB";
GRANT EXECUTE ANY CLASS TO "&ODB" ;
grant DEBUG CONNECT SESSION TO "&ODB";
grant DEBUG ANY PROCEDURE to &ODB;
GRANT "CTXAPP" TO "&ODB";
ALTER USER "&ODB" DEFAULT ROLE  ALL;
GRANT EXECUTE ON  "CTXSYS"."CTX_DDL" TO "&ODB";
GRANT CREATE MATERIALIZED VIEW TO "&ODB";
GRANT CREATE VIEW TO "&ODB";
GRANT CREATE TABLE TO "&ODB";
GRANT QUERY REWRITE TO "&ODB";
CREATE OR REPLACE CONTEXT "MY_CTX" USING "&ODB".PKG_IFACE_GL_INTERFACE;
CREATE OR REPLACE CONTEXT "PKG_SECURITY" USING "&ODB".PKG_SECURITY_IN_TRAX;
CREATE OR REPLACE CONTEXT "ECTM_CTX" USING "&ODB".PKG_IFACE_ECTM;
GRANT "JAVADEBUGPRIV" TO "&ODB";
GRANT "JAVAIDPRIV" TO "&ODB";
GRANT "JAVASYSPRIV" TO "&ODB";
GRANT "JAVAUSERPRIV" TO "&ODB";
GRANT "JAVA_ADMIN" TO "&ODB";
GRANT "JAVA_DEPLOY" TO "&ODB";
exec dbms_java.grant_permission('&ODB', 'SYS:java.util.PropertyPermission', 'javax.xml.transform.TransformerFactory', 'write' );
GRANT SELECT ON  "SYS"."DBA_RGROUP" TO "&ODB";
GRANT SELECT ON  "SYS"."ALL_DB_LINKS" TO "&ODB";
GRANT SELECT ON  "SYS"."ALL_DIRECTORIES" TO "&ODB";
GRANT SELECT ON  "SYS"."DBA_OBJECTS" TO "&ODB";
--2008/02/09
GRANT SELECT ON  "SYS"."V_$SESSION"  TO "&ODB";
GRANT SELECT ON  "SYS"."GV_$SESSION"  TO "&ODB";
--2008/03/19
GRANT SELECT ON  "SYS"."V_$OPEN_CURSOR"  TO "&ODB";
--2009 03-05
GRANT ON COMMIT REFRESH TO "&ODB";
GRANT create session to "&ODB";
--2009 07-07
grant select on v_$mystat TO "&ODB";
--2011-06-21
GRANT EXECUTE ON  "SYS"."DBMS_CRYPTO" TO "&ODB";

-- Drop and Create the MATERIALIZED VIEW  ac_actual_flights_view - should not be under SYS
drop MATERIALIZED VIEW  "SYS"."AC_ACTUAL_FLIGHTS_VIEW";
drop table "SYS"."AC_ACTUAL_FLIGHTS_VIEW";

drop materialized view log on "SYS"."AC_ACTUAL_FLIGHTS";
--CREATE MATERIALIZED VIEW LOG ON "SYS"."AC_ACTUAL_FLIGHTS" WITH ROWID;


-- 2009 03-23
GRANT EXECUTE ON UTL_SMTP TO "&ODB";
GRANT EXECUTE ON UTL_TCP TO "&ODB";
GRANT EXECUTE ON UTL_URL TO "&ODB";
GRANT EXECUTE ON UTL_HTTP TO "&ODB";
GRANT EXECUTE     ON  "SYS"."DBMS_SQL" TO "&ODB";
GRANT EXECUTE     ON  "SYS"."DBMS_JOB" TO "&ODB";
GRANT EXECUTE     ON  "SYS"."DBMS_LOCK" TO "&ODB";

GRANT CREATE JOB TO "&ODB";
GRANT MANAGE SCHEDULER TO "&ODB";

declare
    i_checkDB integer; 
begin
    -- check if the database is 11g
    SELECT COUNT(*)
    INTO i_checkDB
    FROM ALL_OBJECTS
    WHERE OBJECT_NAME = 'DBA_NETWORK_ACLS'
      AND OWNER = 'SYS';
    
    if (i_checkDB >= 1) then
      execute immediate 'GRANT EXECUTE ON DBMS_NETWORK_ACL_ADMIN TO "&ODB"';
    end if;
end;
/

-- 2010 09-16
GRANT AQ_ADMINISTRATOR_ROLE TO "&ODB";
GRANT EXECUTE ON "SYS"."DBMS_AQADM" TO "&ODB";
GRANT EXECUTE ON "SYS"."DBMS_AQ" TO "&ODB";

-- -------------------------
CREATE OR REPLACE PACKAGE "SYS"."TRAX_SYS" as
	procedure kill_session ( v_sid number, v_serial number );
	procedure CleanUp_Sessions(MYUSER VARCHAR2);
	procedure CleanUp_TraxDoc_Sessions(MYUSER VARCHAR2);
	procedure CleanUp_TRAX_Sessions(MYUSER VARCHAR2);
	procedure change_parallell_jobs( num_of_jobs number );
end TRAX_SYS
;
/

CREATE OR REPLACE PACKAGE BODY "SYS"."TRAX_SYS" AS

procedure kill_session ( v_sid number, v_serial number )
 is
 v_varchar2 varchar2(100);
  begin
 execute immediate 'ALTER SYSTEM KILL SESSION '''
 || v_sid || ',' || v_serial || '''';

end;

procedure CleanUp_Sessions(MYUSER VARCHAR2)
IS
l_sid number;
l_serial number;

cursor c1 is     select sid, serial# from v$session
                 where username = MYUSER and osuser = 'SYSTEM';
begin

  begin
  open c1;
  loop
  fetch c1 into l_sid,l_serial;
  EXIT WHEN c1%NOTFOUND;
      kill_session(l_sid,l_serial);
  end loop;
  close c1;
  EXCEPTION
  WHEN OTHERS THEN
    NULL;
  END;

END CleanUp_Sessions
;

procedure CleanUp_TraxDoc_Sessions(MYUSER VARCHAR2)
IS
l_sid number;
l_serial number;

cursor c1 is     select distinct s.sid, s.serial# from v$session s, dba_jobs b
                 where username = MYUSER and osuser = 'SYSTEM' 
                 and (b.what like ('PKG_TRAXDOC_JOB_CALL%') or 
                      b.what IN ( 'CTX_DDL.OPTIMIZE_INDEX('||'''I_TRAXDOC_CONTENT'''||', '||'''FULL'''||');',
                                  'CTX_DDL.SYNC_INDEX('||'''I_TRAXDOC_CONTENT'''||');',
                                  'CTX_DDL.OPTIMIZE_INDEX('||'''I_TRAXDOC_CONTENT_REV'''||', '||'''FULL'''||');',
                                  'CTX_DDL.SYNC_INDEX('||'''I_TRAXDOC_CONTENT_REV'''||');'));
begin

  begin
  open c1;
  loop
  fetch c1 into l_sid,l_serial;
  EXIT WHEN c1%NOTFOUND;
      kill_session(l_sid,l_serial);
  end loop;
  close c1;
  EXCEPTION
  WHEN OTHERS THEN
    NULL;
  END;

END CleanUp_TraxDoc_Sessions
;

procedure CleanUp_Trax_Sessions(MYUSER VARCHAR2)
IS
l_sid number;
l_serial number;

cursor c1 is     select distinct s.sid, s.serial# from v$session s, dba_jobs b
                 where username = MYUSER and osuser = 'SYSTEM' and b.what like ('PKG_JOB_CALL%');
begin

  begin
  open c1;
  loop
  fetch c1 into l_sid,l_serial;
  EXIT WHEN c1%NOTFOUND;
      kill_session(l_sid,l_serial);
  end loop;
  close c1;
  EXCEPTION
  WHEN OTHERS THEN
    NULL;
  END;

END CleanUp_Trax_Sessions
;

procedure change_parallell_jobs ( num_of_jobs number )
 is
 v_varchar2 varchar2(100);
  begin
 execute immediate 'ALTER SYSTEM set job_queue_processes = ' || num_of_jobs ;
 
 
end;


END;
/

DECLARE 
I_TABLES NUMBER(2,0);




BEGIN

SELECT COUNT (*)
INTO I_TABLES
FROM "SYS"."ALL_TABLES" 
WHERE "OWNER" = 'TRAXCORP' AND
      "TABLE_NAME" IN ('TRAX_CUSTOMER_RELEASE', 'TRAX_DISCREPANCY_CUST_SUP_SCPT','TRAX_DISCREPANCY_EMAIL_HISTORY', 
                       'TRAX_DISCREPANCY_RELEASES', 'TRAX_DISCREPENCY_TESTING_SCRIP', 'TRAX_CUSTOMER_RELEASE_AUDIT');


IF I_TABLES = 0 THEN

DELETE
FROM "&ODB"."MAIN"
WHERE "&ODB"."MAIN"."TRANSACTION" = 2 AND
      "&ODB"."MAIN"."CATEGORY" IN ( 'DETAIL', 'SUBDETAIL') AND
      "&ODB"."MAIN"."CATEGORY_TITLE" IN ('Trax Customer Release', 'Trax Discrepancy - All', 'Trax Discrepancy - Reviewed', 'Trax Discrepancy - Testing', 
       					'Trax Discrepancy Print', 'Trax Discrepancy Report', 'Trax Assignment', 'Trax Assignment IT Department',
				        'Trax Testing Log Manager','Trax Accounting', 'Trax Conversion Tracking Print', 'Trax Conversion Tracking', 'Trax Employee Daily Status',
                          		'Trax Documentation', 'Customer Support Dashboard', 'Trax Conversion Dataelements','CS Manager',
                          		'Last Modified PBL Report') OR
      "&ODB"."MAIN"."CATEGORY_TITLE" LIKE '%Fax Coversheet%';

DELETE
FROM "&ODB"."SECURITY_DETAIL" 
WHERE "&ODB"."SECURITY_DETAIL"."TRANSACTION" = 2 AND
      "&ODB"."SECURITY_DETAIL"."CATEGORY_TITLE" in ('Trax discrepancy print','Trax Customer Release','Trax Discrepancy - All', 
      						   'Trax Assignment', 'Trax Discrepancy Print', 'TRAX Discrepancy Report', 'Trax Discrepancy Invoice Report',
						   'Trax Discrepancy Testing Audit', 'Customer status report all', 'Customer status report',
						   'Trax Testing Log Manager', 'Trax Discrepancy Report Testing Button', 'Trax Accounting', 
						   'Trax Conversion Tracking Print', 'Trax Conversion Tracking', 'Trax Employee Daily Status',
                          			   'Trax Documentation', 'Customer Support Dashboard', 'Trax Conversion Dataelements','CS Manager',
                          			   'Last Modified PBL Report') OR
      "&ODB"."SECURITY_DETAIL"."CATEGORY_TITLE" LIKE '%Fax Coversheet%';

COMMIT;

END IF;

END;
/

declare     
    i_checkDB number;
    i_check_ACL number;
begin  
    -- check if the database is 11g
    SELECT COUNT(*)
    INTO i_checkDB
    FROM ALL_OBJECTS
    WHERE OBJECT_NAME = 'DBA_NETWORK_ACLS'
      AND OWNER = 'SYS';
    
    if (i_checkDB >= 1) then
      SELECT COUNT(*)
        INTO I_CHECK_ACL
        FROM SYS.DBA_NETWORK_ACLS DNA
       WHERE DNA."ACL" like '%utlpkg.xml';
		 
    
      if (I_CHECK_ACL >= 1) then
        sys.dbms_network_acl_admin.drop_acl(acl => 'utlpkg.xml');
      end if;
	  
      sys.dbms_network_acl_admin.create_acl(
        acl => 'utlpkg.xml',
        description => 'Normal Access',
        principal => '&ODB',
        is_grant => TRUE,
        privilege => 'connect',
        start_date => null,
        end_date => null);

		
      sys.dbms_network_acl_admin.add_privilege ( 
        acl => 'utlpkg.xml',
        principal => '&ODB',
        is_grant => TRUE,
        privilege => 'connect',
        start_date => null, 
        end_date => null) ;
		
      sys.dbms_network_acl_admin.assign_acl ( 
        acl => 'utlpkg.xml',
        host => '*', 
        lower_port => 1, 
        upper_port => 65535);
        
    commit;
  end if;
END;
/


-- -----------------------------------------
GRANT EXECUTE ON "SYS"."TRAX_SYS" TO "&ODB"; 
-- ------------------------------
GRANT EXECUTE     ON  "SYS"."DBMS_LOCK" TO  "&ODB";
Grant select any table to "&ODB";
grant select on v_$sqltext to "&ODB";
grant select on V$SQLAREA to "&ODB";


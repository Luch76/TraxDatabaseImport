create user &&SCHEMA_OWNER identified by &&SCHEMA_OWNER;
create user TRAX_READONLY identified by TRAX_READONLY; 
create user TRAX_RO identified by TRAX_RO; 

grant unlimited tablespace to &&SCHEMA_OWNER;
ALTER USER &&SCHEMA_OWNER QUOTA UNLIMITED ON USERS;

create OR REPLACE directory DMP as '/opt/oracle/dmp';
grant read, write on directory DMP to system;

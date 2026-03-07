create user &&TRAX_SCHEMA identified by &&TRAX_SCHEMA;
create user TRAX_READONLY identified by TRAX_READONLY; 
create user TRAX_RO identified by TRAX_RO; 

grant unlimited tablespace to &&TRAX_SCHEMA;
ALTER USER &&TRAX_SCHEMA QUOTA UNLIMITED ON USERS;

create OR REPLACE directory DMP as '/opt/oracle/dmp';
grant read, write on directory DMP to system;

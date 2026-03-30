


Hawaii: 
Load Task cards: 
@'/Users/luch/Warez/TraxDatabaseImport/DMP/2026-03-07 - TASK_CARD v11.sql/2026-03-07 - TASK_CARD v11.sql';
(TC data was not loaded because TC_XML field being too large)
;

Alaska
;
@'/Users/luch/Downloads/2026-03-07 - TASK_CARD v11.sql'
;

Email is: host.docker.internal or 10.211.55.2
;

UPDATE TRAX_GLOBAL_FILES TGF
SET TGF."SMTP_SERVER_ADDRESS" = 'host.docker.internal'
WHERE 1=1
;
commit;


SELECT STC."CONFIG_OTHER"
FROM SYSTEM_TRAN_CONFIG STC
WHERE 1=1
AND STC."SYSTEM_CODE" = 'VERSION'
;
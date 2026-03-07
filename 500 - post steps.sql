


Hawaii: 
Load Task cards: 
@'/Users/luch/Warez/TraxDatabaseImport/hawaii/2026-03-04 - HA TC.sql';
(TC data was not loaded because TC_XML field being too large)
;



UPDATE TRAX_GLOBAL_FILES TGF
SET TGF."SMTP_SERVER_ADDRESS" = '10.211.55.2'
WHERE 1=1
;
commit;

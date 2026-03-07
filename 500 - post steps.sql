

Load Task cards: @'/Users/luch/Downloads/2026-03-04 - HA TC.sql'
(TC data was not loaded because TC_XML field being too large)

Set email-server in Settings, Profile Master, Servers-tab

Assign user Luch to profiles: 'TRAX ADMIN', 'IT_ADMIN'

;

@'/Users/luch/Warez/Dmp/2026-03-04 - Hawaiian/enable-fk-triggers.sql';



UPDATE TRAX_GLOBAL_FILES TGF
SET TGF."SMTP_SERVER_ADDRESS" = '10.211.55.2'
WHERE 1=1
;

10.211.55.2

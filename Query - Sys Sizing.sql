SELECT 
    ROUND(SUM(bytes) / 1024 / 1024 / 1024, 2) AS "Allocated_GB",
    12 AS "Limit_GB",
    ROUND((SUM(bytes) / 1024 / 1024 / 1024) / 12 * 100, 2) AS "Pct_of_Limit"
FROM dba_data_files
;


SELECT 
    tablespace_name, 
    ROUND(SUM(bytes) / 1024 / 1024, 2) as "Used_MB" 
FROM dba_segments 
GROUP BY tablespace_name
;


ALTER TABLESPACE USERS SHRINK SPACE;

select tablespace_name, sum(ROUND((bytes) / 1024 / 1024 / 1024, 2)) AS size_gb
from
(
    SELECT 
        tablespace_name, 
        owner, 
        segment_name, 
        segment_type, 
        ROUND(sum(bytes) / 1024 / 1024 / 1024, 2) AS size_gb, 
        BYTES
    FROM dba_segments
    WHERE 1=1
    -- and tablespace_name = 'USERS'
    -- and segment_type = 'TABLE'
    GROUP BY tablespace_name, owner, segment_name, segment_type, BYTES
    ORDER BY size_gb DESC
) s
where 1=1
group by tablespace_name
;

SELECT ROUND(SUM(bytes) / 1024 / 1024 / 1024, 2) AS total_segments_gb
FROM dba_segments
WHERE tablespace_name = 'USERS'
;


SELECT 
    f.tablespace_name,
    ROUND(f.allocated_gb, 2) AS allocated_gb,
    ROUND(s.used_gb, 2) AS used_gb,
    ROUND(f.allocated_gb - s.used_gb, 2) AS empty_space_waiting_to_be_shrunk
FROM 
    (SELECT tablespace_name, SUM(bytes)/1024/1024/1024 allocated_gb FROM dba_data_files GROUP BY tablespace_name) f
JOIN 
    (SELECT tablespace_name, SUM(bytes)/1024/1024/1024 used_gb FROM dba_segments GROUP BY tablespace_name) s
ON f.tablespace_name = s.tablespace_name
WHERE f.tablespace_name = 'USERS'
;



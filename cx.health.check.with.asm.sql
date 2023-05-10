/***************************************************************
http://jadecat.com/tuts/colorsplus.html

bgcolor="#000000"	Black
bgcolor="#808080"	Gray
bgcolor="#C0C0C0"	Silver
bgcolor="#FFFFFF"	White

bgcolor="#008000"	Green
bgcolor="#00FF00"	Lime

bgcolor="#808000"	Olive (light brown)

bgcolor="#800080"	Purple
bgcolor="#000080"	Navy
bgcolor="#0000FF"	Blue
bgcolor="#008080"	Teal
bgcolor="#00FFFF"	Aqua

bgcolor="#800000"	Maroon
bgcolor="#FF0000"	Red
bgcolor="#FF00FF"	Fuchsia (pink)

bgcolor="#FFFF00"	Yellow

#FF9900	orange
#FF0033	mild red

***************************************************************/

--WHENEVER OSERROR EXIT
--WHENEVER SQLERROR EXIT SQL.SQLCODE
--
SET FEEDBACK OFF HEADING OFF VERIFY OFF NEWPAGE NONE TRIMOUT ON TRIMSPOOL ON FLUSH OFF LINESIZE 999
--SET NULL '-'
--
-- Define the colour for just information columns
DEFINE info=&1
DEFINE output=&2
--
-- Spring green
DEFINE acceptable=#00FF7F
-- almost red
DEFINE warning=#FF8000
-- Red
DEFINE danger=#FF0066
--
SPOOL &output APPEND
--
--
SELECT 'host='||LOWER(HOST_NAME)||'<br>['||version||']'
FROM v$instance;
PROMPT </td>
--
-- For RAC there is more than 1 default Undo tablespace
--VAR u VARCHAR2(30);
--EXEC select upper(value) into :u from v$system_parameter2 where name='undo_tablespace';
--
PROMPT <td
SELECT
  DECODE(rownum,1,
    CASE
      WHEN CURRENT_UTILIZATION/LIMIT_VALUE*100 >=98
      THEN ' BGCOLOR="&danger">' 
      WHEN CURRENT_UTILIZATION/LIMIT_VALUE*100 >=90
      THEN ' BGCOLOR="&warning">'
      ELSE ' BGCOLOR="&acceptable">'
    END,
    '<a title="processes: warning >=90%, danger >=98%">'
  ),
  '['||INST_ID||']',
  	CURRENT_UTILIZATION||'<sub>now</sub> '||
	MAX_UTILIZATION||'<sub>peak</sub> '||
	LIMIT_VALUE||'<sub>limit</sub><br>'
FROM (
  SELECT * FROM gv$resource_limit 
  WHERE resource_name='processes'
  ORDER BY CURRENT_UTILIZATION/LIMIT_VALUE DESC
);
PROMPT </td>
--
PROMPT <td
SELECT
  DECODE(rownum,1,
    CASE
      WHEN CURRENT_UTILIZATION/LIMIT_VALUE*100 >=98
      THEN ' BGCOLOR="&danger">'
      WHEN CURRENT_UTILIZATION/LIMIT_VALUE*100 >=90
      THEN ' BGCOLOR="&warning">'
      ELSE ' BGCOLOR="&acceptable">'
    END, 
    '<a title="sessions: warning >=90%, danger >=98%">'
  ),
  '['||INST_ID||']',
  	CURRENT_UTILIZATION||'<sub>now</sub> '||
	MAX_UTILIZATION||'<sub>peak</sub> '||
	LIMIT_VALUE||'<sub>limit</sub><br>'
FROM (
  SELECT * FROM gv$resource_limit 
  WHERE resource_name='sessions'
  ORDER BY CURRENT_UTILIZATION/LIMIT_VALUE DESC
);
SELECT '<br>['||INST_ID||'] sessions active='||count(*)
FROM gv$session
WHERE status='ACTIVE' AND type!='BACKGROUND' 
GROUP BY INST_ID
ORDER BY count(*) DESC;
PROMPT </td>
--
PROMPT <td BGCOLOR="&info"><a title="Top 5 user sessions">
SELECT * from (
  select a||'='||count(b)||'<br>' from
  (
    select '['||INST_ID||']'||LOWER(USERNAME)||'@'||LOWER(machine) a, username b
    from gv$session
    where username is not null
  )
  group by a
  order by count(b) desc
)
where rownum<6;
PROMPT </td>
--
-- <!--largest % of non-Undo tablespace capacity: warning >=80%, danger >=90%
-- Note: Assume all free space can be reused
-- Factor in current bytes greater tham max bytes
-- Also disregard the Undo tablespaces-->
PROMPT <td
SELECT
  DECODE(rownum,1,
    CASE
      WHEN pct_used >=90
      THEN ' BGCOLOR="&danger">'
      WHEN pct_used >=80
      THEN ' BGCOLOR="&warning">'
      ELSE ' BGCOLOR="&acceptable">'
    END
  ),
  DECODE(rownum,1,
    '<a title="Largest utilisation% of non-Undo tablespace capacity: warning >=80%, danger >=90%">'
--||'total.dbf.files='||(select CEIL(SUM(gb)) from (select SUM(bytes/1024/1024/1024) gb from dba_data_files
--		 union all
--		 select SUM(bytes/1024/1024/1024) gb from dba_temp_files))||'GB<br>'
  ),
  pct_used||'%<sup>'||tablespace_name||'</sup><sub>'||max||'GB max</sub><br>'
FROM
  (SELECT
    m.tablespace_name, CEIL((1-(m.max-a.alloc+f.free)/m.max)*100) pct_used, CEIL(m.max) max
  FROM
    (select tablespace_name, SUM(CASE WHEN bytes>maxbytes THEN bytes ELSE maxbytes END)/1024/1024/1024 max
    from dba_data_files
    group by tablespace_name) m,
    (select tablespace_name, sum(bytes)/1024/1024/1024 alloc
    from dba_data_files
    group by tablespace_name) a,
    (select tablespace_name, sum(bytes)/1024/1024/1024 free
    from dba_free_space
    group by tablespace_name) f
  WHERE m.tablespace_name=a.tablespace_name
    AND m.tablespace_name=f.tablespace_name
    AND m.tablespace_name not in (select tablespace_name from dba_tablespaces where contents='UNDO')
  ORDER BY 2 desc)
WHERE rownum<5;
PROMPT </td>
--
-- <!--Undo - unexpired extent reuse: warning >=80% in last 12hrs
-- Note1: v$undostat returns NULL values if the system is in manual undo management mode.
-- Note2: Undo tablespace filling can also indicate poor performing DML.
-- Note3: default: Re-use all unexpired undo extents before autoextending the datafile.-->
PROMPT <td
-- ###############################################
-- ################ re-evaluate ##################
-- ###############################################
SELECT
  CASE
    WHEN MAX(UNXPSTEALCNT) >=80 OR MAX(NOSPACEERRCNT) >0
    THEN ' BGCOLOR="&warning">'
    ELSE ' BGCOLOR="&acceptable">'
  END,
  '<a title="unexpired extent reuse: warning >=80% in last 12hrs - consumed space: warning = error">',
  --'['||u.INST_ID||']'||
  CEIL(MAX(UNXPSTEALCNT/
	(select count(*) 
	 from dba_extents 
	 where tablespace_name in 
		(select tablespace_name 
		from dba_tablespaces 
		where contents=UPPER(s.value))
	))*100)||'%<sub>steals</sub><br>',
  --'['||u.INST_ID||']'||
  CEIL(MAX(UNDOBLKS/
	(select sum(BLOCKS) 
	 from dba_data_files 
	 where tablespace_name in 
		(select tablespace_name 
		from dba_tablespaces 
		where contents=UPPER(s.value))
	))*100)||'%<sub>blocks</sub>'
FROM gv$undostat u, gv$system_parameter2 s
WHERE u.inst_id=s.inst_id
	AND s.name='undo_tablespace'
	AND u.end_time>sysdate-0.5;
PROMPT </td>
--
/*
PROMPT <td
SELECT
  CASE
    WHEN MAX(NOSPACEERRCNT) >0
    THEN ' BGCOLOR="&warning">'
    ELSE ' BGCOLOR="&acceptable">'
  END,
  '<a title="Undo - consumed space: danger = error">',
  CEIL(MAX(UNDOBLKS/
	(select sum(BLOCKS) from dba_data_files where tablespace_name = :u))*100)||'%'
from v$undostat 
where end_time>sysdate-0.5;
PROMPT </td>
*/
--
PROMPT <td
WITH a AS (
  select trunc(COMPLETION_TIME) t, ROUND(sum(blocks*block_size)/1024/1024/1024,1) GB
  from v$archived_log
  where DEST_ID=1
	and trunc(COMPLETION_TIME)<trunc(sysdate)
  group by trunc(COMPLETION_TIME)
  order by trunc(COMPLETION_TIME) desc
),
b AS (
  select ROUND(sum(blocks*block_size)/1024/1024/1024,1) GB
  from v$archived_log
  where DEST_ID=1
	and trunc(COMPLETION_TIME)=trunc(sysdate)
)
SELECT
  -- Only alert if the archives are 0.1GB more than the prev max
  -- Note: avoid alerting when the maximum is zero.
  CASE
    WHEN (select gb from b) > (select max(GB)+0.05 from a)
    THEN ' BGCOLOR="&danger">'
    ELSE ' BGCOLOR="&acceptable">'
  END
  ||'<a title="Archivelogs per day (GB)">',
  (select gb||'<sub>today</sub>/' from b)
FROM dual
UNION ALL
-- break after 7 days
select null, GB||DECODE(rownum,6,'<BR>',13,'<BR>','/') 
from a 
where rownum<22
UNION ALL
select '<br>Peak over past '||ROUND(sysdate-min(t))||' days is ', max(GB)||'GB' 
from a;
PROMPT </td>
--
PROMPT <td
SELECT
  CASE
    WHEN count(sid) >0
    THEN ' BGCOLOR="&warning">'
    ELSE ' BGCOLOR="&acceptable">'
  END,
  '<a title="Excessive long running blocking locks: warning >10 minutes">', 
  DECODE(count(sid),0,'-',count(sid))
from gv$lock 
where block=1 and ctime>600;
PROMPT </td>
--
PROMPT <td
SELECT
  CASE
    WHEN count(s.sid) >0
    THEN ' BGCOLOR="&warning">'
    ELSE ' BGCOLOR="&acceptable">'
  END,
  '<a title="Excessive long running operations: warning >1hr">',
  DECODE(count(s.sid),0,'-',max(s.username||' '||program))
FROM gv$session_longops l, gv$session s
WHERE l.INST_ID=s.INST_ID AND l.SID=s.SID AND l.SERIAL#=s.SERIAL#
  AND CEIL(sofar/DECODE(totalwork,0,1,totalwork)*100)!=100
  AND ELAPSED_SECONDS > 3600;
PROMPT </td>
--
--
-- TOTAL_MB: Total capacity of the disk group (in megabytes) 
-- FREE_MB: Unused capacity of the disk group (in megabytes) 
-- REQUIRED_MIRROR_FREE_MB: Amount of space that is required to be available in a given disk group
--	in order to restore redundancy after one or more disk failures. The amount of space displayed
--	in this column takes mirroring effects into account.
-- USABLE_FILE_MB: Amount of free space that can be safely utilized taking mirroring into account
--	and yet be able to restore redundancy after a disk failure.
--
--NAME TOTAL_MB FREE_MB REQUIRED_MIRROR_FREE_MB USABLE_FILE_MB
--DAT001  122880    3438 0    3438
--DAT002   40960   10199 0   10199
--DAT003 3276800 1265625 0 1265625
--FRA001  122880  118844 0  118844
--
PROMPT <td
SET SERVEROUTPUT ON SIZE 1000000
DECLARE
  stmnt VARCHAR2(1000);
BEGIN
  FOR item 
  IN (
	SELECT
	  DECODE(rownum,1,
	    CASE
	      WHEN CEIL((total_mb-usable_file_mb)/total_mb*100) >=90
	      THEN ' BGCOLOR="&danger">' 
	      WHEN CEIL((total_mb-usable_file_mb)/total_mb*100) >=80
	      THEN ' BGCOLOR="&warning">'
	      ELSE ' BGCOLOR="&acceptable">'
	    END
	  ) a,
	  DECODE(rownum,1,
	    '<a title="asm: warning >=80%, danger >=90%">'
	  ) b,
	  name||'=' c,
	  CEIL((total_mb-usable_file_mb)/total_mb*100)||'%<br>['||ROUND(total_mb/1024)||'GB]<br>' d
	FROM
	(SELECT name, total_mb, usable_file_mb
	  FROM V$ASM_DISKGROUP
	  WHERE (name LIKE '%DAT%' OR name LIKE '%FRA%')
	  ORDER BY (total_mb-usable_file_mb)/total_mb desc)
	WHERE rownum<4
  )
  LOOP
    BEGIN
      DBMS_OUTPUT.PUT_LINE(item.a||item.b||item.c||item.d);
    EXCEPTION
    -- Note: the NO_DATA_FOUND exception is predefined
      WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('-');
    END;
  END LOOP;
END;
/
PROMPT </td>
--
PROMPT <td
SELECT
  CASE
    WHEN count(*) >0
    THEN ' BGCOLOR="&warning">'
    ELSE ' BGCOLOR="&acceptable">'
  END,
  '<a title="files that require media recovery">',
  DECODE(count(*),0,'none',count(*))
FROM v$recover_file;
PROMPT </td>
--
--
select '<!--' from dual;
--
SET PAGESIZE 9999 LINESIZE 132 APPINFO OFF FLUSH OFF SERVEROUTPUT OFF TRIMSPOOL ON ARRAYSIZE 100 TRIMOUT ON
alter session set nls_date_format = 'dd-mm-yyyy hh24:mi:ss';
SET FEEDBACK ON HEADING ON
--
SELECT begin_time, end_time,
  UNXPSTEALCNT "attemptstealUnexpExt", 
  UNXPBLKRELCNT "releasedUnexpBlks", 
  UNXPBLKREUCNT "reusedUnexpBlks", 
  EXPSTEALCNT "attemptstealExpExt", 
  EXPBLKRELCNT "stolenExpBlks",
  EXPBLKREUCNT "reusedExpBlks"
FROM gv$undostat
WHERE UNXPSTEALCNT>0 OR UNXPBLKRELCNT>0 OR UNXPBLKREUCNT>0
 OR EXPSTEALCNT>0 OR EXPBLKRELCNT>0 OR EXPBLKREUCNT>0;
--
-- snapshot of what is happening at 15 sec intervals
-- from 10g upwards
SELECT begin_time, end_time FROM V$SESSMETRIC where rownum=1;
column username form A10
column program form A50
SELECT S.INST_ID, S.SESSION_ID, P.USERNAME, P.PROGRAM, P.STATUS, 
	S.CPU, S.PHYSICAL_READS, S.LOGICAL_READS, S.PGA_MEMORY 
FROM GV$SESSMETRIC S, GV$SESSION P 
WHERE s.session_id=p.sid AND s.INST_ID=p.INST_ID;
--
/*
SELECT s.inst_id, class, username, name, value 
FROM gv$statname n, gv$session s, gv$sesstat t
WHERE s.sid=t.sid AND n.statistic#=t.statistic# AND s.type='USER'
  AND value>0 and class=2
ORDER BY class, username, value DESC;
--
SELECT s.inst_id, e.wait_class, username, e.event, e.TIME_WAITED 
FROM gv$session s, GV$SESSION_EVENT e
WHERE s.sid=e.sid AND s.type='USER' and e.TIME_WAITED>0 and e.wait_class='Commit'
ORDER BY e.wait_class, username, e.TIME_WAITED;
--
SELECT s.inst_id, e.wait_class, username, e.event, e.TIME_WAITED
FROM gv$session s, GV$SESSION_EVENT e
WHERE s.sid=e.sid AND s.type='USER' and e.TIME_WAITED>0 and e.wait_class='Configuration'
ORDER BY e.wait_class, username, e.TIME_WAITED;
--
-- Approximate database work
SELECT s.inst_id, s.sid, logon_time, username, s.status, 
	(select name from audit_actions where action=command) "command", value 
FROM gv$statname n, gv$session s, gv$sesstat t
WHERE s.sid=t.sid AND n.statistic#=t.statistic# AND s.type='USER'
  AND value>0 and n.name IN ('db block changes')
ORDER BY value DESC;
--
-- application of rollback entries to get a consistent read
-- (consistent changes should be smaller than consistent gets)
SELECT s.inst_id, s.sid, logon_time, username, s.status,
	 (select name from audit_actions where action=command) "command", value 
FROM gv$statname n, gv$session s, gv$sesstat t
WHERE s.sid=t.sid AND n.statistic#=t.statistic# AND s.type='USER'
  AND value>0 and n.name IN ('consistent gets','consistent changes')
ORDER BY value DESC;
*/
--
--
--
--
PROMPT ###################### SHARED POOL Reserved ######################
SELECT
 case
   WHEN (select value from v$system_parameter2 where name='shared_pool_reserved_size')>0
   THEN (select 'FREE_SPACE, AVG_FREE_SIZE, FREE_COUNT, MAX_FREE_SIZE = '||
	ROUND(FREE_SPACE/1024/1024,1)||'MB, '||
	ROUND(AVG_FREE_SIZE/1024/1024,1)||'MB, '||
	FREE_COUNT||', '||
	ROUND(MAX_FREE_SIZE/1024/1024,1)||'MB'||CHR(10)||
	'USED_SPACE, AVG_USED_SIZE, USED_COUNT, MAX_USED_SIZE = '||
	ROUND(USED_SPACE/1024/1024,1)||'MB, '||
	ROUND(AVG_USED_SIZE/1024/1024,1)||'MB, '||
	USED_COUNT||', '||
	ROUND(MAX_USED_SIZE/1024/1024,1)||'MB'||CHR(10)||
	'REQUESTS, REQUEST_MISSES, LAST_MISS_SIZE, MAX_MISS_SIZE = '||
	REQUESTS||', '||REQUEST_MISSES||', '||
	ROUND(LAST_MISS_SIZE/1024/1024,1)||'MB, '||
	ROUND(MAX_MISS_SIZE/1024/1024,1)||'MB'
	 from V$SHARED_POOL_RESERVED)
 end "valid if S_P_R_S is set",
 (select 'REQUEST_FAILURES, LAST_FAILURE_SIZE = '||
	REQUEST_FAILURES||', '||ROUND(LAST_FAILURE_SIZE/1024/1024,1)||'MB'||CHR(10)||
	'ABORTED_REQUEST_THRESHOLD, ABORTED_REQUESTS, LAST_ABORTED_SIZE = '||
	ROUND(ABORTED_REQUEST_THRESHOLD/1024/1024,1)||'MB, '||ABORTED_REQUESTS||', '||
	ROUND(LAST_ABORTED_SIZE/1024/1024,1)||'MB'
 from V$SHARED_POOL_RESERVED) "always valid"
FROM dual;
--
/*
*/
SET FEEDBACK OFF HEADING OFF
--
select '-->' from dual;
--
spool off
--
EXIT




--VAR u NUMBER;
--VAR z VARCHAR2(30);
--EXEC select distinct trunc(first_time) into :z, ROUND(sum(blocks*block_size)/1024/1024/1024,1) into :u -
--  from v$archived_log -
--  group by trunc(first_time);
--PRINT '<br>max='||MAX(:u)||'GB'

SELECT
  DECODE(rownum,1,
    CASE
      WHEN CEIL((total_mb-usable_file_mb)/total_mb*100) >=90
      THEN ' BGCOLOR="&danger">' 
      WHEN CEIL((total_mb-usable_file_mb)/total_mb*100) >=80
      THEN ' BGCOLOR="&warning">'
      WHEN NULL
      THEN ' BGCOLOR="&acceptable">'
      ELSE ' BGCOLOR="&acceptable">'
    END
  ),
  DECODE(rownum,1,
    '<a title="asm: warning >=80%, danger >=90%">'
  ),
  name||'=',
  CEIL((total_mb-usable_file_mb)/total_mb*100)||'<br>'
FROM
(SELECT name, total_mb, usable_file_mb
  FROM V$ASM_DISKGROUP
  WHERE (name LIKE 'DAT%' OR name LIKE 'FRA%')
  ORDER BY (total_mb-usable_file_mb)/total_mb desc)
WHERE rownum<4;

--select name, 
--	round(sum(total_mb)/1024,2) total_gb,
--	round(sum(free_mb)/1024,2) free_gb,
--	round(sum(free_mb)/sum(total_mb)*100,2) pct_free
--from v$asm_disk 
--where group_number<>0
-- and (name like '%DAT%' OR name like '%FRA%')
--group by name;

-- 직전 SQL의 실행계획 + Adaptive Plan 정보(비활성 오퍼레이션은 '-' 로 표시)
set pagesize 0
set heading off
set feedback off
select plan_table_output
from   table(dbms_xplan.display_cursor(null, null, 'ALLSTATS LAST +ADAPTIVE'));
set pagesize 100
set heading on
set feedback on

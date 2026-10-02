-- 직전 SQL의 실행계획 + Hint Report 출력 (week11 전용 헬퍼)
--   common/xplan.sql 과 같지만, 힌트가 적용되었는지(U = Unused) 보여주는 Hint Report 를 함께 출력한다.

set pagesize 0
set heading off
set feedback off
select plan_table_output
from   table(dbms_xplan.display_cursor(null, null, 'ALLSTATS LAST +HINT_REPORT'));
set pagesize 100
set heading on
set feedback on

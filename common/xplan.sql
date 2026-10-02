-- 직전에 실행한 SQL의 실제 실행계획과 실행 통계 출력
--   읽을 컬럼: Starts, E-Rows(예상) / A-Rows(실제), Buffers(논리 I/O), Reads(물리 I/O), A-Time
--   전제: session_init 의 statistics_level = all (또는 /*+ gather_plan_statistics */ 힌트)
--   주의: 대상 SQL 바로 다음에 호출할 것. 사이에 다른 SQL이 끼면 그 SQL의 계획이 나온다.
--         결과가 여러 건이면 set feedback only 로 끝까지 fetch 해야 A-Rows가 정확하다.

set pagesize 0
set heading off
set feedback off
select plan_table_output
from   table(dbms_xplan.display_cursor(null, null, 'ALLSTATS LAST'));
set pagesize 100
set heading on
set feedback on

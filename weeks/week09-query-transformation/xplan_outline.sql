-- 직전 SQL의 실행계획 + 쿼리 블록 이름(ALIAS) + Outline Data
--   Outline Data 에 UNNEST, MERGE, PUSH_PRED, OR_EXPAND, ELIMINATE_JOIN 같은 힌트가 보이면
--   옵티마이저가 그 변환을 적용했다는 뜻이다. 쿼리 블록 이름(SEL$1, SEL$2 ...)이 어떻게 바뀌었는지도 본다.
set pagesize 0
set heading off
set feedback off
select plan_table_output
from   table(dbms_xplan.display_cursor(null, null, 'ALLSTATS LAST +ALIAS +OUTLINE'));
set pagesize 100
set heading on
set feedback on

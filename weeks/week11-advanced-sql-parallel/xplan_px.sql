-- 병렬 SQL 전용 실행계획 출력 (week11 전용 헬퍼)
--   사용: @@xplan_px <태그>   예) 대상 SQL에 /* w11_px_a */ 주석을 넣고 @@xplan_px w11_px_a
--
-- common/xplan.sql 과 다른 점
--   1) 'ALLSTATS LAST' 는 QC(코디네이터) 몫의 통계만 보여준다. 병렬 SQL은 PX 서버 몫까지 합친 누적값('ALLSTATS')으로 본다.
--   2) TQ, IN-OUT, PQ Distrib 컬럼이 나오도록 ALL 레벨을 쓴다.
--   3) 직전 SQL이 아니라 태그 주석으로 커서를 찾는다. 그래서 v$pq_sesstat 조회를 먼저 한 뒤에 호출해도 된다.

set pagesize 0
set heading off
set feedback off
select t.plan_table_output
from  (select sql_id, child_number
       from   v$sql
       where  sql_text like '%/* &1 */%'
       and    sql_text not like '%v$sql%'
       order  by last_active_time desc
       fetch  first 1 rows only) s,
       table(dbms_xplan.display_cursor(s.sql_id, s.child_number, 'ALL ALLSTATS -PROJECTION -ALIAS -OUTLINE')) t;
set pagesize 100
set heading on
set feedback on

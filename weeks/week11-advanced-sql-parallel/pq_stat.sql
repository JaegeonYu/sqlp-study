-- 직전 SQL이 실제로 병렬로 실행되었는지 확인 (week11 전용 헬퍼)
--   LAST_QUERY: 직전 SQL 값 / SESSION_TOTAL: 세션 누적
--   Queries Parallelized·DML Parallelized = 1 이면 병렬 실행, Server Threads = 사용한 PX 서버 수

column statistic format a30
set feedback off
select statistic, last_query, session_total
from   v$pq_sesstat
where  statistic in ('Queries Parallelized', 'DML Parallelized', 'Server Threads', 'Allocation Height', 'DFO Trees');
set feedback on

-- 세션 통계 스냅샷 시작. 측정할 SQL 앞에서 호출하고, 끝나면 mystat_end 를 호출한다.
--   스냅샷 저장 자체도 약간의 logical read / execute를 발생시킨다(수십 단위 오차).

set feedback off
delete from mystat_snap;
insert into mystat_snap (name, value)
select s.name, m.value
from   v$mystat m
       join v$statname s on s.statistic# = m.statistic#
where  s.name in (
         'session logical reads', 'consistent gets', 'db block gets',
         'physical reads', 'physical reads direct',
         'redo size', 'undo change vector size',
         'data blocks consistent reads - undo records applied',
         'table scan rows gotten', 'table fetch by rowid',
         'sorts (memory)', 'sorts (disk)',
         'parse count (total)', 'parse count (hard)', 'execute count',
         'user calls', 'SQL*Net roundtrips to/from client');
set feedback on

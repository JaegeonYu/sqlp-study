-- Call·I/O 관련 세션 통계 스냅샷 시작 (common/mystat_begin 의 week03 전용판, 같은 mystat_snap 사용)
set feedback off
delete from mystat_snap;
insert into mystat_snap (name, value)
select s.name, m.value
from   v$mystat m
       join v$statname s on s.statistic# = m.statistic#
where  s.name in (
         'user calls', 'recursive calls', 'execute count', 'user commits',
         'SQL*Net roundtrips to/from client',
         'session logical reads', 'consistent gets', 'redo size',
         'physical reads', 'physical reads direct',
         'physical read total IO requests', 'physical read total multi block requests',
         'CPU used by this session');
set feedback on

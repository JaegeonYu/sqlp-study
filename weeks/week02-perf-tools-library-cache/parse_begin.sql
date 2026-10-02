-- 파싱 관련 세션 통계 스냅샷 시작 (common/mystat_begin 의 파싱 전용판, 같은 mystat_snap 테이블 사용)
set feedback off
delete from mystat_snap;
insert into mystat_snap (name, value)
select s.name, m.value
from   v$mystat m
       join v$statname s on s.statistic# = m.statistic#
where  s.name in (
         'parse count (total)', 'parse count (hard)', 'parse count (failures)',
         'session cursor cache hits', 'session cursor cache count',
         'execute count', 'parse time elapsed', 'parse time cpu');
set feedback on

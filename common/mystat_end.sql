-- mystat_begin 이후 증가한 세션 통계 출력 (0인 항목은 생략)

column stat_name format a55
column delta     format 999,999,999,999
set feedback off
select b.name                 as stat_name,
       m.value - b.value      as delta
from   mystat_snap b
       join v$statname s on s.name = b.name
       join v$mystat   m on m.statistic# = s.statistic#
where  m.value - b.value > 0
order  by b.name;
set feedback on

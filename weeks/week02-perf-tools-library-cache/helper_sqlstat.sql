-- V$SQL에서 태그(주석)로 SQL 찾기: 커서 수 요약 + 상위 5개 상세
--   사용: @@helper_sqlstat <태그>     예) @@helper_sqlstat w02_bind
--   태그는 SQL 안의 주석(/* w02_bind */)으로 붙여 둔다.
--   command_type 47(PL/SQL 익명 블록)은 제외한다. 블록 안에 태그 문자열이 들어 있기 때문.

column sql_id    format a13
column child     format 99999
column execs     format 999,999
column parses    format 999,999
column gets      format 999,999,999
column sql_text  format a70
set feedback off

select /* helper_sqlstat */
       count(*)                 as cursors,
       count(distinct sql_id)   as sql_ids,
       sum(executions)          as execs,
       sum(parse_calls)         as parses,
       sum(buffer_gets)         as gets
from   v$sql
where  sql_text like '%&1%'
and    sql_text not like '%helper_sqlstat%'
and    command_type <> 47;

select /* helper_sqlstat */
       sql_id,
       child_number             as child,
       executions               as execs,
       parse_calls              as parses,
       buffer_gets              as gets,
       substr(sql_text, 1, 70)  as sql_text
from   v$sql
where  sql_text like '%&1%'
and    sql_text not like '%helper_sqlstat%'
and    command_type <> 47
order  by sql_id, child_number
fetch  first 5 rows only;
set feedback on

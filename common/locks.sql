-- STUDY 계정 세션들의 대기/블로킹 관계와 보유·요청 중인 Lock 조회
--   Lock 실습 중 "세 번째 터미널"에서 실행하면 보기 좋다.
--   LMODE/REQUEST: 2=RS(SS), 3=RX(SX), 4=S, 5=SRX(SSX), 6=X

column sid             format 9999
column blocker         format 9999
column event           format a40
column wait_obj        format a20
column object_name     format a20
column sql_id          format a13
column type            format a4
set feedback off

prompt
prompt [세션: 누가 누구를 기다리는가]
select s.sid,
       s.blocking_session  as blocker,
       s.event,
       s.seconds_in_wait   as wait_sec,
       o.object_name       as wait_obj,
       s.sql_id
from   v$session s
       left join dba_objects o on o.object_id = s.row_wait_obj#
where  s.username = 'STUDY'
and    s.sid <> sys_context('userenv', 'sid')
order  by s.sid;

prompt
prompt [Lock: TX(행/트랜잭션), TM(테이블)]
select l.sid,
       l.type,
       o.object_name,
       l.lmode,
       l.request,
       l.block
from   v$lock l
       left join dba_objects o on l.type = 'TM' and o.object_id = l.id1
where  l.type in ('TX', 'TM')
and    l.sid in (select sid from v$session where username = 'STUDY')
order  by l.sid, l.type, o.object_name;
set feedback on

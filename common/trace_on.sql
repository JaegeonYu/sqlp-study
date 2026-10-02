-- SQL 트레이스 시작 (대기 이벤트 포함)
--   사용: @@../../common/trace_on <식별자>     예) @@../../common/trace_on week00
--   종료: @@../../common/trace_off  → 호스트에서 scripts/tkprof.sh <식별자>

alter session set tracefile_identifier = '&1';
exec dbms_session.session_trace_enable(waits => true, binds => false)

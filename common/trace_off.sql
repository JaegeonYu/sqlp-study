-- SQL 트레이스 종료 후 트레이스 파일 위치 출력

exec dbms_session.session_trace_disable

column trace_file format a100
select value as trace_file
from   v$diag_info
where  name = 'Default Trace File';

prompt 호스트 터미널에서 TKPROF 실행:  bash scripts/tkprof.sh <식별자>   (PowerShell: .\scripts\tkprof.ps1 <식별자>)

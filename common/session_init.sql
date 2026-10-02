-- 모든 실습 스크립트가 맨 처음 호출하는 공통 세션 설정
--   사용: @@../../common/session_init   (주차 폴더 기준)

set serveroutput off
set linesize 250
set pagesize 100
set trimout on
set trimspool on
set tab off
set verify off
set long 100000

-- 모든 SQL의 실제 실행 통계(A-Rows, Buffers, A-Time) 수집 → common/xplan.sql 로 확인
alter session set statistics_level = all;
alter session set nls_date_format = 'YYYY-MM-DD';
-- GTT(mystat_snap) 변경분의 Undo를 TEMP에 기록 → 세션 통계 측정 오차 최소화
alter session set temp_undo_enabled = true;

-- 세션 통계 스냅샷 보관용 (common/mystat_begin.sql, mystat_end.sql)
create global temporary table if not exists mystat_snap (
  name  varchar2(64),
  value number
) on commit preserve rows;

-- week08 lab: 옵티마이저 원리 — 통계, 카디널리티, 바인드 피킹, 동적 샘플링
@@../../common/session_init

column column_name format a12
column histogram   format a15
column density     format 0.0000000
column ext_name    format a40
column notes       format a30

prompt
prompt ===== [1] 옵티마이저가 보는 컬럼 통계 =====
select column_name, num_distinct, num_nulls, density, histogram, num_buckets
from   user_tab_col_statistics
where  table_name = 'BIG_TABLE'
order  by column_name;
prompt 관찰: status 의 NUM_DISTINCT=2, HISTOGRAM=NONE. 이 정보만으로 status = 'N' 의 건수를 어떻게 추정할까?

prompt
prompt ===== [2] 히스토그램 없음: 'WAIT'(1%)를 50%로 착각 =====
exec dbms_stats.gather_table_stats(user, 'W08_ORDERS', method_opt => 'for all columns size 1', no_invalidate => false)
select sum(amt) from w08_orders where state = 'WAIT';
@@../../common/xplan
prompt 관찰: E-Rows 는 100K(=20만/NDV 2), A-Rows 는 2,000. 인덱스가 있는데 FULL 을 고른 이유는?

prompt
prompt ===== [3] 도수분포(Frequency) 히스토그램 수집 후 =====
exec dbms_stats.gather_table_stats(user, 'W08_ORDERS', method_opt => 'for all columns size 1 for columns state size 254', no_invalidate => false)
select column_name, endpoint_number, endpoint_actual_value
from   user_histograms
where  table_name = 'W08_ORDERS' and column_name = 'STATE'
order  by endpoint_number;
prompt 관찰: ENDPOINT_NUMBER 는 누적 건수다. 'DONE' 과 'WAIT' 의 건수를 읽어 보자.
select sum(amt) from w08_orders where state = 'WAIT';
@@../../common/xplan
prompt 관찰: E-Rows 가 실제와 맞아지자 액세스 경로가 어떻게 바뀌었나? Buffers 는?
prompt       no_invalidate => false 를 빼면 기존 커서가 한동안 재사용될 수 있다(Rolling Invalidation).

prompt
prompt ===== [4] BIG_TABLE.status 도 같은 현상 =====
exec dbms_stats.gather_table_stats(user, 'BIG_TABLE', method_opt => 'for all columns size 1', no_invalidate => false)
select count(*) from big_table where status = 'N';
@@../../common/xplan
exec dbms_stats.gather_table_stats(user, 'BIG_TABLE', method_opt => 'for all columns size 1 for columns status size 254', no_invalidate => false)
select count(*) from big_table where status = 'N';
@@../../common/xplan
prompt 관찰: E-Rows 500K → 10K. 계획(FULL)은 그대로라면 왜일까? ('N' 행은 100건마다 하나씩 전 블록에 흩어져 있다)
exec dbms_stats.gather_table_stats(user, 'BIG_TABLE', method_opt => 'for all columns size 1', no_invalidate => false)

prompt
prompt ===== [5] 범위 조건의 선택도와 범위 밖 값 =====
select count(*) from big_table where cust_id between 1 and 100;
@@../../common/xplan
select count(*) from big_table where reg_dt > date '2024-09-20';
@@../../common/xplan
select count(*) from big_table where reg_dt > date '2025-06-01';
@@../../common/xplan
prompt 관찰: 범위 선택도 ≈ (조건 범위) / (high - low). reg_dt 최대값은 2024-09-26. 범위 밖 조건의 E-Rows 는 0이 아니라 얼마로 나오나?

prompt
prompt ===== [6] 결합 조건: 컬럼 간 상관관계 =====
select count(*) from w08_addr where city_cd = 5 and zip_cd = 55;
@@../../common/xplan
prompt 관찰: E-Rows = 10만 × (1/100) × (1/1000) = 1. 실제는 100건. 옵티마이저는 두 조건이 독립이라고 가정한다.
declare
  l_name varchar2(128);
begin
  l_name := dbms_stats.create_extended_stats(user, 'W08_ADDR', '(CITY_CD, ZIP_CD)');
exception
  when others then
    if sqlcode != -20007 then raise; end if;   -- 이미 있으면 무시
end;
/
exec dbms_stats.gather_table_stats(user, 'W08_ADDR', method_opt => 'for all columns size 1', no_invalidate => false)
select extension_name as ext_name, extension
from   user_stat_extensions
where  table_name = 'W08_ADDR';
select count(*) from w08_addr where city_cd = 5 and zip_cd = 55;
@@../../common/xplan
prompt 관찰: 컬럼 그룹 통계(확장 통계) 수집 후 E-Rows 는? 컬럼 그룹의 NUM_DISTINCT 는 몇일까?

prompt
prompt ===== [7] 바인드 피킹과 Adaptive Cursor Sharing =====
alter system flush shared_pool;
variable st varchar2(10)
prompt --- [7-a] 첫 실행 'WAIT' (하드 파싱 → 'WAIT' 를 엿보고 계획 결정)
exec :st := 'WAIT'
select /* w08_acs */ sum(amt) from w08_orders where state = :st;
@@../../common/xplan
prompt --- [7-b] 'DONE' (같은 커서 재사용)
exec :st := 'DONE'
select /* w08_acs */ sum(amt) from w08_orders where state = :st;
@@../../common/xplan
prompt --- [7-c] 'DONE' 한 번 더
select /* w08_acs */ sum(amt) from w08_orders where state = :st;
@@../../common/xplan
prompt --- [7-d] 'WAIT' 다시
exec :st := 'WAIT'
select /* w08_acs */ sum(amt) from w08_orders where state = :st;
@@../../common/xplan
select child_number, executions, buffer_gets, plan_hash_value,
       is_bind_sensitive as sens, is_bind_aware as aware, is_shareable as shr
from   v$sql
where  sql_text like 'select /* w08_acs */%'
order  by child_number;
prompt 관찰: [7-b] 는 'WAIT' 용 계획으로 'DONE' 19.8만 건을 처리했다(Buffers). 몇 번째 실행부터 새 child 커서가 생기는가?

prompt
prompt ===== [8] 통계가 없는 테이블: 동적 샘플링 =====
select num_rows, last_analyzed from user_tables where table_name = 'W08_NOSTAT';
select count(*) from w08_nostat where grp_id = 7;
@@../../common/xplan
prompt 관찰: 실행계획 하단 Note 에 dynamic statistics(동적 샘플링) 가 표시되는가? E-Rows 는 실제(1,000)와 얼마나 가까운가?

prompt
prompt ===== [9] 23ai 실시간 통계(Real-Time Statistics) 관찰 =====
select num_rows, notes from user_tab_statistics where table_name = 'W08_RTS';
insert into w08_rts select id, grp_id, amount from big_table where id between 10001 and 20000;
commit;
select num_rows, notes from user_tab_statistics where table_name = 'W08_RTS';
prompt 관찰: 일반 INSERT 1만 건 후 NUM_ROWS 가 바뀌었나? NOTES = STATS_ON_CONVENTIONAL_DML 행이 생겼나? (Exadata/Cloud 전용 기능)

prompt
prompt ===== [10] Adaptive Plan =====
select /* w08_adaptive */ sum(b.amount)
from   w08_orders o
       join big_table b on b.id = o.ord_id
where  o.state = 'WAIT';
@@xplan_adaptive
prompt 관찰: Note 에 "this is an adaptive plan" 이 있는가? '-' 로 표시된 오퍼레이션은 실행 중 버려진 후보다.

prompt
prompt ===== [11] optimizer_mode: 첫 행 vs 전체 처리 =====
prompt --- [11-a] all_rows (기본)
set feedback only
select * from big_table where grp_id = 5 order by id;
set feedback on
@@../../common/xplan
prompt --- [11-b] first_rows_1
alter session set optimizer_mode = first_rows_1;
set feedback only
select * from big_table where grp_id = 5 order by id;
set feedback on
@@../../common/xplan
alter session set optimizer_mode = all_rows;
prompt 관찰: first_rows_1 은 왜 정렬을 피하는 계획을 골랐나? 1만 건을 끝까지 읽을 때는 어느 쪽이 Buffers 가 적은가?

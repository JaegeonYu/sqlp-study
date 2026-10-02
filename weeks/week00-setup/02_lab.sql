-- week00 lab: 실행계획과 측정 도구 익히기
--   실행: bash scripts/run.sh weeks/week00-setup/02_lab.sql
--   각 단계의 "관찰" 질문에 대한 답을 result.md 1번 표에 적는다.
@@../../common/session_init

prompt
prompt ===== [1] BIG_TABLE 규모 =====
select table_name, num_rows, blocks, avg_row_len
from   user_tables
where  table_name = 'BIG_TABLE';
prompt 관찰: 블록 수(BLOCKS)를 기억해 두자. 아래 [2]의 Buffers와 비교한다.

prompt
prompt ===== [2] 테이블 전체 스캔으로 1주일치 집계 =====
select /*+ full(b) */ count(*), sum(amount)
from   big_table b
where  reg_dt between date '2023-01-01' and date '2023-01-07';
@@../../common/xplan
prompt 관찰: 7,000건을 구하려고 Buffers를 얼마나 읽었나? [1]의 BLOCKS와 비교해 보자.

prompt
prompt ===== [3] 인덱스 범위 스캔으로 같은 집계 =====
select /*+ index(b w00_reg_dt_ix) */ count(*), sum(amount)
from   big_table b
where  reg_dt between date '2023-01-01' and date '2023-01-07';
@@../../common/xplan
prompt 관찰: Buffers가 몇 분의 1로 줄었나? 인덱스 스캔과 테이블 액세스 단계가 각각 몇 블록을 읽었나?
prompt       (힌트: reg_dt는 날짜순으로 저장되어 있다)

prompt
prompt ===== [4] 세션 통계로 같은 비교 =====
prompt --- [4-a] FULL
@@../../common/mystat_begin
select /*+ full(b) */ count(*), sum(amount)
from   big_table b
where  reg_dt between date '2023-01-01' and date '2023-01-07';
@@../../common/mystat_end
prompt --- [4-b] INDEX
@@../../common/mystat_begin
select /*+ index(b w00_reg_dt_ix) */ count(*), sum(amount)
from   big_table b
where  reg_dt between date '2023-01-01' and date '2023-01-07';
@@../../common/mystat_end
prompt 관찰: session logical reads 와 [2], [3]의 Buffers 가 거의 같은가? table scan rows gotten, table fetch by rowid 는 각각 무엇을 센 값인가?

prompt
prompt ===== [5] 예상(E-Rows) vs 실제(A-Rows) =====
select count(*)
from   big_table
where  status = 'N';
@@../../common/xplan
prompt 관찰: E-Rows 는 왜 500,000 근처일까? (status 는 값이 2개뿐이고 히스토그램이 없다) 실제는 몇 건인가?

prompt
prompt ===== [6] AUTOTRACE 통계 =====
set autotrace traceonly statistics
select *
from   big_table
where  cust_id = 77;
set autotrace off
prompt 관찰: consistent gets, SQL*Net roundtrips, rows processed. cust_id 에는 인덱스가 없다.

prompt
prompt ===== [7] SQL 트레이스 → TKPROF =====
@@../../common/trace_on week00
select /*+ index(b w00_reg_dt_ix) */ count(*), sum(amount)
from   big_table b
where  reg_dt between date '2023-01-01' and date '2023-01-07';
select /*+ full(b) */ count(*), sum(amount)
from   big_table b
where  reg_dt between date '2023-01-01' and date '2023-01-07';
@@../../common/trace_off
prompt 관찰: TKPROF 의 query(=consistent gets), disk, Row Source Operation 을 [2], [3]과 비교해 보자.

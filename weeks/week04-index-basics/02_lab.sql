-- week04 lab: 인덱스 구조, 스캔 방식, 인덱스를 못 타는 조건
--   실행: bash scripts/run.sh weeks/week04-index-basics/02_lab.sql
@@../../common/session_init

-- 재실행 대비: 실습 중 만드는 인덱스는 먼저 지우고 시작
drop index if exists w04_upper_name_fx;
drop index if exists w04_closed_id_ix;

prompt
prompt ===== [1] B*Tree 구조: 딕셔너리 통계 =====
column index_name format a20
select index_name, blevel, leaf_blocks, distinct_keys, num_rows
from   user_indexes
where  table_name = 'BIG_TABLE'
order  by index_name;
prompt 관찰: BLEVEL 이 2 라면 루트 → 브랜치 → 리프까지 몇 블록을 읽어야 리프에 도착하나? 100만 건인데 왜 이렇게 낮은가?

prompt
prompt ===== [1-b] B*Tree 구조: VALIDATE STRUCTURE (index_stats) =====
analyze index w04_reg_dt_ix validate structure;
select height, blocks, br_blks, lf_blks, br_rows, lf_rows, pct_used
from   index_stats;
prompt 관찰: HEIGHT = BLEVEL + 1 인가? 리프 블록 하나에 키가 평균 몇 개(LF_ROWS / LF_BLKS) 들어 있나?

prompt
prompt ===== [2] 스캔 방식 =====
prompt --- [2-a] INDEX UNIQUE SCAN : PK = 상수
select * from big_table where id = 777;
@@../../common/xplan
prompt 관찰: Buffers 는 (BLEVEL + 1) + 테이블 1블록 과 같은가?

prompt --- [2-b] INDEX RANGE SCAN : 하루치 1,000건 (인덱스만으로 처리)
select count(*) from big_table where reg_dt = date '2023-01-01';
@@../../common/xplan
prompt 관찰: 테이블 액세스 단계가 없다. 왜 테이블을 읽지 않아도 되는가?

prompt --- [2-c] INDEX RANGE SCAN DESCENDING : 최근 5건
select /*+ index_desc(b w04_reg_dt_ix) */ id, reg_dt
from   big_table b
where  reg_dt >= date '2024-09-20'
order  by reg_dt desc
fetch  first 5 rows only;
@@../../common/xplan
prompt 관찰: SORT ORDER BY 가 없다. 인덱스를 거꾸로 읽어 정렬을 대신했다. A-Rows 가 5 근처에서 멈춘 단계는?

prompt --- [2-d] INDEX FULL SCAN (MIN/MAX)
select max(reg_dt) from big_table;
@@../../common/xplan
prompt 관찰: 100만 건 중 최댓값을 Buffers 몇 개로 구했나?

prompt --- [2-e] INDEX FULL SCAN : 리프 블록을 처음부터 끝까지 순서대로
alter system flush buffer_cache;
@@../../common/trace_on week04
select /*+ index(b big_table_pk) */ count(*) from big_table b;
@@../../common/xplan

prompt --- [2-f] INDEX FAST FULL SCAN : 인덱스 세그먼트 전체를 Multiblock I/O 로
alter system flush buffer_cache;
select /*+ index_ffs(b big_table_pk) */ count(*) from big_table b;
@@../../common/xplan
@@../../common/trace_off
prompt 관찰: [2-e]와 [2-f]의 Buffers 는 비슷한데 A-Time 은? TKPROF(bash scripts/tkprof.sh week04)의 대기 이벤트
prompt       db file sequential read / db file scattered read(또는 direct path read) 를 비교하자. 결과 정렬 순서는 둘 중 누가 보장하나?

prompt --- [2-g] INDEX SKIP SCAN : 선두 컬럼(status) 조건 없이 (status, reg_dt) 인덱스 사용
select /*+ index_ss(b w04_status_dt_ix) */ count(*)
from   big_table b
where  reg_dt = date '2023-01-01';
@@../../common/xplan
prompt 관찰: status 값이 'N','Y' 두 개뿐이라 인덱스를 몇 번 "점프"해서 읽었나? 선두 컬럼의 NDV 가 1만 개였다면?

prompt
prompt ===== [3] 인덱스 컬럼 가공 =====
prompt --- [3-a] 함수로 가공
select count(*), sum(amount) from big_table where trunc(reg_dt) = date '2023-03-01';
@@../../common/xplan
prompt --- [3-b] 가공하지 않은 범위 조건
select count(*), sum(amount) from big_table
where  reg_dt >= date '2023-03-01' and reg_dt < date '2023-03-02';
@@../../common/xplan
prompt --- [3-c] 연산으로 가공
select * from big_table where id + 1 = 778;
@@../../common/xplan
prompt 관찰: Predicate Information 에서 access( ) 와 filter( ) 중 어디에 조건이 들어갔나? 그것이 인덱스 사용 여부를 결정한다.

prompt
prompt ===== [4] 묵시적 형변환: VARCHAR2 컬럼 = 숫자 =====
select * from w04_code where code = 123;
@@../../common/xplan
select * from w04_code where code = '00000123';
@@../../common/xplan
prompt 관찰: 첫 번째 SQL의 Predicate Information 에 TO_NUMBER("CODE") 가 보이는가? 오라클은 문자와 숫자를 비교할 때 어느 쪽을 변환하나?

prompt
prompt ===== [5] LIKE: 앞부분 고정 vs 앞부분 %  =====
set feedback only
select * from w04_code where name like 'Name777%';
set feedback on
@@../../common/xplan
select count(*) from w04_code where name like '%777';
@@../../common/xplan
prompt 관찰: '%777' 은 인덱스의 어느 지점에서 스캔을 시작해야 할지 알 수 없다. 옵티마이저는 무엇을 골랐나?

prompt
prompt ===== [6] 부정형 조건 =====
select count(*) from big_table where status <> 'Y';
@@../../common/xplan
select count(*) from big_table where status = 'N';
@@../../common/xplan
prompt 관찰: 값이 'Y','N' 두 개뿐이라는 "업무 지식"이 있으면 <> 를 = 로 바꿀 수 있다. Buffers 차이는?

prompt
prompt ===== [7] IS NULL: 단일 컬럼 인덱스에는 NULL 이 저장되지 않는다 =====
set feedback only
select * from w04_code where closed_dt is null;
set feedback on
@@../../common/xplan
prompt --- 해결: NOT NULL 컬럼을 뒤에 붙인 결합 인덱스 (closed_dt, id)
create index w04_closed_id_ix on w04_code (closed_dt, id);
set feedback only
select * from w04_code where closed_dt is null;
set feedback on
@@../../common/xplan
prompt 관찰: 결합 인덱스에서는 모든 컬럼이 NULL 인 행만 빠진다. 그래서 (closed_dt, id) 에는 closed_dt 가 NULL 인 행도 들어 있다.

prompt
prompt ===== [8] OR 조건 =====
set feedback only
select * from big_table where reg_dt = date '2023-01-01' or id between 1 and 500;
set feedback on
@@../../common/xplan
set feedback only
select /*+ full(b) */ * from big_table b where reg_dt = date '2023-01-01' or id between 1 and 500;
set feedback on
@@../../common/xplan
prompt 관찰: 첫 번째 계획에 VW_ORE / UNION-ALL / CONCATENATION 이 보이는가? OR 를 두 개의 인덱스 액세스로 나눈 것(OR-Expansion)이다.

prompt
prompt ===== [9] 함수 기반 인덱스(FBI) =====
select * from w04_code where upper(name) = 'NAME777';
@@../../common/xplan
create index w04_upper_name_fx on w04_code (upper(name));
select * from w04_code where upper(name) = 'NAME777';
@@../../common/xplan
prompt 관찰: 같은 SQL인데 인덱스가 생기자 계획이 바뀌었다. FBI의 단점(DML 비용, 정확히 같은 식이어야 함)은 무엇일까?

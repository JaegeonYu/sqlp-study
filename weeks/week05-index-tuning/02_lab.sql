-- week05 lab: 인덱스 활용 — 클러스터링 팩터, 손익분기점, 결합 인덱스 순서, 커버링, 소트 생략, IOT
--   실행: bash scripts/run.sh weeks/week05-index-tuning/02_lab.sql
@@../../common/session_init

-- 재실행 대비: 실습 중 만드는 인덱스는 먼저 지우고 시작
drop index if exists w05_rnd_amt_ix;

prompt
prompt ===== [1] 클러스터링 팩터(CF) =====
column index_name format a16
select i.index_name,
       i.clustering_factor,
       t.blocks   as table_blocks,
       t.num_rows as table_rows
from   user_indexes i
       join user_tables t on t.table_name = i.table_name
where  i.index_name in ('W05_CUST_IX', 'W05_RND_IX')
order  by i.index_name;
prompt 관찰: CF 가 테이블 블록 수에 가까운 인덱스와 행 수에 가까운 인덱스는 각각 어느 쪽인가?
prompt       CF = "인덱스 순서대로 테이블을 읽을 때 블록을 갈아타는 횟수" 로 해석해 보자.

prompt
prompt ===== [2] 같은 1,000건, 다른 비용 =====
select /*+ index(b w05_cust_ix) */ count(*), sum(amount)
from   big_table b
where  cust_id between 1 and 10;
@@../../common/xplan
select /*+ index(b w05_rnd_ix) */ count(*), sum(amount)
from   big_table b
where  rnd_id between 1 and 10;
@@../../common/xplan
prompt 관찰: INDEX RANGE SCAN 단계의 Buffers 는 비슷한데 TABLE ACCESS 단계는? 차이가 곧 CF 차이다.

prompt
prompt ===== [3] 인덱스 손익분기점: 비율을 늘려 가며 INDEX vs FULL =====
@@breakeven
prompt 관찰: rnd_ix(CF 나쁨)는 몇 % 부근에서 FULL 보다 LIO 가 많아지나? cust_ix(CF 좋음)는 20% 에서도 FULL 보다 적은가?
prompt       "인덱스는 5~20% 까지" 같은 고정 규칙이 왜 위험한지 설명해 보자.

prompt
prompt ===== [4] 결합 인덱스 컬럼 순서: = 조건 선두 vs 범위 조건 선두 =====
prompt --- [4-a] (grp_id, reg_dt) : = 컬럼이 선두
select /*+ index(b w05_grp_dt_ix) */ count(*)
from   big_table b
where  grp_id = 7
and    reg_dt between date '2023-01-01' and date '2023-03-31';
@@../../common/xplan
prompt --- [4-b] (reg_dt, grp_id) : 범위 컬럼이 선두, Range Scan 강제
select /*+ index_rs_asc(b w05_dt_grp_ix) */ count(*)
from   big_table b
where  grp_id = 7
and    reg_dt between date '2023-01-01' and date '2023-03-31';
@@../../common/xplan
prompt --- [4-c] (reg_dt, grp_id) : 옵티마이저에 인덱스만 지정
select /*+ index(b w05_dt_grp_ix) */ count(*)
from   big_table b
where  grp_id = 7
and    reg_dt between date '2023-01-01' and date '2023-03-31';
@@../../common/xplan
prompt 관찰: 결과는 같은 900건. [4-a] 와 [4-b] 의 Buffers 차이는? [4-b] 의 Predicate Information 에서 grp_id = 7 은
prompt       access 범위를 줄이지 못하고 filter 로만 쓰인다(범위 조건 뒤의 컬럼). [4-c] 에서 옵티마이저는 무엇을 골랐나?
prompt       (reg_dt 값마다 grp_id = 7 위치로 "점프"하는 Skip Scan. 그래도 [4-a] 보다 많이 읽는다)

prompt
prompt ===== [5] 커버링 인덱스: 테이블 액세스 제거 =====
set feedback only
select /*+ index(b w05_rnd_ix) */ rnd_id, sum(amount)
from   big_table b
where  rnd_id between 1 and 100
group  by rnd_id;
set feedback on
@@../../common/xplan
create index w05_rnd_amt_ix on big_table (rnd_id, amount);
set feedback only
select /*+ index(b w05_rnd_amt_ix) */ rnd_id, sum(amount)
from   big_table b
where  rnd_id between 1 and 100
group  by rnd_id;
set feedback on
@@../../common/xplan
prompt 관찰: TABLE ACCESS 단계가 사라졌다. Buffers 는 몇 분의 1 이 됐나? 대가(인덱스 크기, DML 부담)는 무엇인가?

prompt
prompt ===== [6] 인덱스로 ORDER BY 생략 + 부분범위처리 =====
prompt --- [6-a] (grp_id, reg_dt) 역순 → 정렬 없이 10건에서 멈춤
select /*+ index_desc(b w05_grp_dt_ix) */ id, reg_dt, amount
from   big_table b
where  grp_id = 7
order  by reg_dt desc
fetch  first 10 rows only;
@@../../common/xplan
prompt --- [6-b] FULL 후 정렬
select /*+ full(b) */ id, reg_dt, amount
from   big_table b
where  grp_id = 7
order  by reg_dt desc
fetch  first 10 rows only;
@@../../common/xplan
prompt --- [6-c] (reg_dt, grp_id) 역순 → 정렬 컬럼이 선두, 조건 컬럼은 두 번째
select /*+ index_desc(b w05_dt_grp_ix) */ id, reg_dt, amount
from   big_table b
where  grp_id = 7
order  by reg_dt desc
fetch  first 10 rows only;
@@../../common/xplan
prompt 관찰: [6-a] 에 SORT ORDER BY 가 있나? [6-b] 는 1만 건을 모두 읽고 정렬했다.
prompt       [6-c] 는 조건 컬럼이 선두가 아닌데도 빠르다. grp_id = 7 인 행이 날짜마다 고르게 있기 때문이다. grp_id 가 드문 값이었다면?

prompt
prompt ===== [7] IOT: 테이블 자체가 PK 순서로 저장된다 =====
select sum(amount) from w05_heap where cust_id = 77;
@@../../common/xplan
select sum(amount) from w05_iot where cust_id = 77;
@@../../common/xplan
prompt 관찰: 힙 테이블(무작위 저장)은 100건을 찾으려고 테이블 블록을 몇 개 읽었나? IOT 는 TABLE ACCESS 단계 자체가 없다.

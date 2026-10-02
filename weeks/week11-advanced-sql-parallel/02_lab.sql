-- week11 lab: 고급 SQL 활용, 병렬 처리
@@../../common/session_init

prompt
prompt ===== [1] 같은 테이블을 여러 번 읽는 집계 vs 한 번 스캔 =====
prompt --- [1-a] union all 로 연도별 합계 (BIG_TABLE 3번 스캔)
select 2022 as yr, sum(amount) as amt
from   big_table
where  reg_dt < date '2023-01-01'
union all
select 2023, sum(amount)
from   big_table
where  reg_dt >= date '2023-01-01' and reg_dt < date '2024-01-01'
union all
select 2024, sum(amount)
from   big_table
where  reg_dt >= date '2024-01-01';
@@../../common/xplan
prompt --- [1-b] CASE 로 한 번 스캔 (결과를 가로로 펼침)
select sum(case when reg_dt <  date '2023-01-01' then amount end)                               as amt_2022,
       sum(case when reg_dt >= date '2023-01-01' and reg_dt < date '2024-01-01' then amount end) as amt_2023,
       sum(case when reg_dt >= date '2024-01-01' then amount end)                               as amt_2024
from   big_table;
@@../../common/xplan
prompt 관찰: Buffers 가 몇 배 차이 나는가? 결과를 세로(행)로 보여줘야 한다면 한 번 스캔을 유지한 채 어떻게 바꿀 수 있을까?

prompt
prompt ===== [2] WITH 절: materialize vs inline =====
prompt --- [2-a] materialize: 집계를 한 번만 하고 임시 테이블로 재사용
set feedback only
with t as (
  select /*+ materialize */ grp_id, sum(amount) as amt, count(*) as cnt
  from   big_table
  group  by grp_id
)
select a.grp_id, a.amt, b.amt as prev_amt
from   t a, t b
where  b.grp_id = a.grp_id - 1;
set feedback on
@@../../common/xplan
prompt --- [2-b] inline: WITH 절을 참조할 때마다 다시 집계
set feedback only
with t as (
  select /*+ inline */ grp_id, sum(amount) as amt, count(*) as cnt
  from   big_table
  group  by grp_id
)
select a.grp_id, a.amt, b.amt as prev_amt
from   t a, t b
where  b.grp_id = a.grp_id - 1;
set feedback on
@@../../common/xplan
prompt 관찰: 2-a 의 TEMP TABLE TRANSFORMATION, LOAD AS SELECT 단계를 찾아라. BIG_TABLE 을 몇 번 읽었나? 이 예제에서는 분석함수 lag 로 WITH 절 자체를 없앨 수도 있다.

prompt
prompt ===== [3] MERGE: UPDATE + INSERT 를 한 문장으로 =====
prompt --- [3-a] UPDATE 한 번 + INSERT 한 번 (cust_id 1~1000 은 갱신, 1001~2000 은 신규)
@@../../common/mystat_begin
update w11_cust_sum s
set   (total_amt, cnt, upd_dt) = (select sum(b.amount), count(*), sysdate
                                  from   big_table b
                                  where  b.cust_id = s.cust_id)
where  s.cust_id <= 2000;
insert into w11_cust_sum (cust_id, total_amt, cnt, upd_dt)
select b.cust_id, sum(b.amount), count(*), sysdate
from   big_table b
where  b.cust_id <= 2000
and    not exists (select 1 from w11_cust_sum s where s.cust_id = b.cust_id)
group  by b.cust_id;
@@../../common/mystat_end
rollback;
prompt --- [3-b] MERGE
merge into w11_cust_sum s
using (select cust_id, sum(amount) as total_amt, count(*) as cnt
       from   big_table
       where  cust_id <= 2000
       group  by cust_id) b
on    (s.cust_id = b.cust_id)
when matched then
  update set s.total_amt = b.total_amt, s.cnt = b.cnt, s.upd_dt = sysdate
when not matched then
  insert (cust_id, total_amt, cnt, upd_dt) values (b.cust_id, b.total_amt, b.cnt, sysdate);
@@../../common/xplan
rollback;
@@../../common/mystat_begin
merge into w11_cust_sum s
using (select cust_id, sum(amount) as total_amt, count(*) as cnt
       from   big_table
       where  cust_id <= 2000
       group  by cust_id) b
on    (s.cust_id = b.cust_id)
when matched then
  update set s.total_amt = b.total_amt, s.cnt = b.cnt, s.upd_dt = sysdate
when not matched then
  insert (cust_id, total_amt, cnt, upd_dt) values (b.cust_id, b.total_amt, b.cnt, sysdate);
@@../../common/mystat_end
rollback;
prompt 관찰: 3-a 와 3-b 의 session logical reads, execute count 차이는? MERGE 실행계획에서 원본 집계는 몇 번 일어났나?

prompt
prompt ===== [4] 그룹 내 Top-N: 상관 서브쿼리 vs 윈도우 함수 =====
prompt --- [4-a] 고객별 금액 상위 3건 (cust_id 1~100): 행마다 "나보다 큰 건수" 를 센다
set feedback only
select cust_id, id, amount
from   big_table b
where  b.cust_id <= 100
and   (select count(*)
       from   big_table b2
       where  b2.cust_id = b.cust_id
       and    b2.amount  > b.amount) < 3;
set feedback on
@@../../common/xplan
prompt --- [4-b] row_number() 한 번으로
set feedback only
select cust_id, id, amount
from  (select cust_id, id, amount,
              row_number() over (partition by cust_id order by amount desc) as rn
       from   big_table
       where  cust_id <= 100)
where  rn <= 3;
set feedback on
@@../../common/xplan
prompt 관찰: 결과는 둘 다 300건. 4-a 의 서브쿼리 단계 Starts 와 전체 Buffers 는? 4-b 의 WINDOW SORT PUSHED RANK 는 무엇을 줄여주는가?

prompt
prompt ===== [5] 이 DB에서 병렬 처리가 가능한가? =====
prompt     Oracle 23ai Free 는 병렬 실행(Parallel execution) 옵션이 꺼져 있다. 직접 확인해 보자.
column parameter format a30
column value     format a20
select parameter, value
from   v$option
where  parameter like 'Parallel%';
column name format a30
select name, value
from   v$parameter
where  name in ('cpu_count', 'parallel_max_servers', 'parallel_servers_target',
                'parallel_degree_policy', 'parallel_min_servers');
prompt 관찰: Parallel execution 값은? parallel_max_servers 는?

prompt
prompt ===== [6] parallel 힌트를 줘도 직렬로 수행된다: Hint Report 읽기 =====
set feedback only
select /*+ full(b) parallel(b 2) */ grp_id, sum(amount)
from   big_table b
group  by grp_id;
set feedback on
@@pq_stat
set feedback only
select /*+ full(b) parallel(b 2) */ grp_id, sum(amount)
from   big_table b
group  by grp_id;
set feedback on
@@xplan_hint
prompt 관찰: Queries Parallelized 가 0 인가? Hint Report 에서 parallel(b 2) 앞의 U 는 무엇을 뜻하는가?
prompt       PX 오퍼레이션이 있는 병렬 실행계획 읽기는 README 의 "병렬 실행계획 읽기" 예시로 연습한다.

prompt
prompt ===== [7] 병렬 DML 도 마찬가지: append 힌트만 적용된다 =====
-- 이전 단계에서 열린 트랜잭션이 있으면 parallel dml 상태를 바꿀 수 없으므로 먼저 커밋
commit;
alter session enable parallel dml;
insert /*+ append parallel(w 2) */ into w11_copy w
select /*+ full(b) parallel(b 2) */ *
from   big_table b
where  id <= 200000;
@@xplan_hint
commit;
alter session disable parallel dml;
prompt 관찰: LOAD AS SELECT(직접 경로 적재)는 적용되었는가? parallel 힌트는? DML Parallelized 는 아래와 같다.
@@pq_stat

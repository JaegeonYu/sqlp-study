-- week10 lab: 소트 튜닝
--   실행계획의 OMem(최적 메모리 예상), 1Mem(One-pass 예상), Used-Mem(실제 사용), Used-Tmp(디스크 사용)를 본다.
@@../../common/session_init
-- 수십만 건을 fetch 하는 단계가 있어 한 번에 가져오는 건수를 늘린다 (소트 수치에는 영향 없음)
set arraysize 500

prompt
prompt ===== [1] 소트가 발생하는 오퍼레이션 =====
prompt --- [1-a] SORT AGGREGATE: 이름은 SORT 지만 실제 정렬은 하지 않는다
select count(*), max(amount)
from   big_table
where  grp_id = 1;
@@../../common/xplan

prompt --- [1-b] SORT ORDER BY
set feedback only
select /*+ full(b) */ id, amount
from   big_table b
where  grp_id = 1
order  by amount;
set feedback on
@@../../common/xplan

prompt --- [1-c] HASH GROUP BY (기본) vs SORT GROUP BY (no_use_hash_aggregation)
set feedback only
select /*+ full(b) */ cust_id, sum(amount)
from   big_table b
where  cust_id <= 2000
group  by cust_id;
set feedback on
@@../../common/xplan
set feedback only
select /*+ full(b) no_use_hash_aggregation */ cust_id, sum(amount)
from   big_table b
where  cust_id <= 2000
group  by cust_id;
set feedback on
@@../../common/xplan

prompt --- [1-d] HASH UNIQUE / SORT UNIQUE (distinct)
set feedback only
select /*+ full(b) */ distinct rnd_id
from   big_table b
where  grp_id = 1;
set feedback on
@@../../common/xplan
set feedback only
select /*+ full(b) */ distinct rnd_id
from   big_table b
where  grp_id = 1
order  by rnd_id;
set feedback on
@@../../common/xplan

prompt --- [1-e] SORT JOIN (Sort Merge Join)
set feedback only
select /*+ leading(g) use_merge(b) full(b) */ g.grp_name, b.id, b.amount
from   w10_grp g, big_table b
where  b.grp_id = g.grp_id
and    g.grp_id between 1 and 3;
set feedback on
@@../../common/xplan

prompt --- [1-f] WINDOW SORT
set feedback only
select /*+ full(b) */ id, grp_id, amount,
       row_number() over (partition by grp_id order by amount desc) as rn
from   big_table b
where  grp_id between 1 and 2;
set feedback on
@@../../common/xplan
prompt 관찰: 각 오퍼레이션의 Used-Mem 은? HASH GROUP BY 와 SORT GROUP BY 의 결과 순서와 메모리 차이는? 1-d 에서 order by 를 붙이면 왜 SORT UNIQUE 로 바뀌는가?

prompt
prompt ===== [2] 메모리 소트 vs 디스크 소트 =====
prompt --- [2-a] 자동 PGA 관리 (기본)
set feedback only
select /*+ full(b) */ id, rnd_id, reg_dt, amount
from   big_table b
where  grp_id <= 20
order  by rnd_id, amount;
set feedback on
@@../../common/xplan
@@../../common/mystat_begin
set feedback only
select /*+ full(b) */ id, rnd_id, reg_dt, amount
from   big_table b
where  grp_id <= 20
order  by rnd_id, amount;
set feedback on
@@../../common/mystat_end

prompt --- [2-b] 수동 관리 + sort_area_size 64KB 로 소트 공간을 강제로 줄임
alter session set workarea_size_policy = manual;
alter session set sort_area_size = 65536;
set feedback only
select /*+ full(b) */ id, rnd_id, reg_dt, amount
from   big_table b
where  grp_id <= 20
order  by rnd_id, amount;
set feedback on
@@../../common/xplan
@@../../common/mystat_begin
set feedback only
select /*+ full(b) */ id, rnd_id, reg_dt, amount
from   big_table b
where  grp_id <= 20
order  by rnd_id, amount;
set feedback on
@@../../common/mystat_end
-- 세션 설정 원복
alter session set workarea_size_policy = auto;
prompt 관찰: 2-b 에서 Used-Tmp 와 sorts (disk), physical reads direct 가 나타나는가? 같은 결과인데 A-Time 은 얼마나 늘었나?

prompt
prompt ===== [3] 인덱스로 소트 생략 =====
prompt --- [3-a] FULL + SORT ORDER BY
set feedback only
select /*+ full(b) */ id, amount
from   big_table b
where  grp_id = 7
order  by amount;
set feedback on
@@../../common/xplan
prompt --- [3-b] 인덱스 (grp_id, amount, id) 순서대로 읽기 → SORT 없음
set feedback only
select /*+ index(b w10_grp_amt_ix) */ id, amount
from   big_table b
where  grp_id = 7
order  by amount;
set feedback on
@@../../common/xplan
prompt --- [3-c] MIN/MAX: INDEX RANGE SCAN (MIN/MAX) + FIRST ROW
select max(amount)
from   big_table
where  grp_id = 7;
@@../../common/xplan
prompt --- [3-d] Top-N + 인덱스: COUNT STOPKEY 로 10건만 읽고 멈춤
select *
from  (select /*+ index_desc(b w10_grp_amt_ix) */ id, amount
       from   big_table b
       where  grp_id = 7
       order  by amount desc)
where  rownum <= 10;
@@../../common/xplan
prompt 관찰: 3-b 에서 SORT ORDER BY 가 사라졌는가? 3-c, 3-d 의 Buffers 는 몇 블록인가? 인덱스 컬럼에 id 가 들어 있어 테이블 액세스도 없다.

prompt
prompt ===== [4] Top-N 소트 vs 전체 소트 (인덱스 없는 정렬 컬럼) =====
prompt --- [4-a] Top-N: fetch first (23ai 는 rownum 방식으로 변환해 SORT ORDER BY STOPKEY 로 처리)
select /*+ full(b) */ id, rnd_id
from   big_table b
order  by rnd_id desc, id
fetch  first 10 rows only;
@@../../common/xplan
prompt --- [4-b] rownum <= 10 → SORT ORDER BY STOPKEY
select *
from  (select /*+ full(b) */ id, rnd_id
       from   big_table b
       order  by rnd_id desc, id)
where  rownum <= 10;
@@../../common/xplan
prompt --- [4-c] 같은 10건이지만 Top-N 최적화를 막은 경우 (rn + 0)
select id, rnd_id
from  (select /*+ full(b) */ id, rnd_id,
              row_number() over (order by rnd_id desc, id) as rn
       from   big_table b)
where  rn + 0 <= 10;
@@../../common/xplan
prompt 관찰: 결과는 똑같이 10건인데 Used-Mem 차이는? Top-N 소트는 왜 상위 N개만 메모리에 유지하면 되는가?

prompt
prompt ===== [5] 페이징: 뒤 페이지로 갈수록 느려진다 =====
prompt     (reg_dt 는 인덱스에 없는 컬럼이라 행마다 테이블 랜덤 액세스가 일어난다)
prompt --- [5-a] 1페이지 (1~20번째)
select id, amount, reg_dt
from  (select rownum as rn, a.*
       from  (select /*+ index(b w10_grp_amt_ix) no_batch_table_access_by_rowid(b) */ id, amount, reg_dt
              from   big_table b
              where  grp_id = 7
              order  by amount, id) a
       where  rownum <= 20)
where  rn >= 1;
@@../../common/xplan
prompt --- [5-b] 400페이지 (7,981~8,000번째)
set feedback only
select id, amount, reg_dt
from  (select rownum as rn, a.*
       from  (select /*+ index(b w10_grp_amt_ix) no_batch_table_access_by_rowid(b) */ id, amount, reg_dt
              from   big_table b
              where  grp_id = 7
              order  by amount, id) a
       where  rownum <= 8000)
where  rn >= 7981;
set feedback on
@@../../common/xplan
prompt --- [5-c] 키 기반 페이징: 399페이지의 마지막 키(amount, id)를 기억해 그 다음부터 20건
column last_amt new_value last_amt noprint
column last_id  new_value last_id  noprint
select amount as last_amt, id as last_id
from  (select rownum as rn, a.*
       from  (select /*+ index(b w10_grp_amt_ix) */ id, amount
              from   big_table b
              where  grp_id = 7
              order  by amount, id) a
       where  rownum <= 7980)
where  rn = 7980;
set feedback only
select *
from  (select /*+ index(b w10_grp_amt_ix) no_batch_table_access_by_rowid(b) */ id, amount, reg_dt
       from   big_table b
       where  grp_id = 7
       and    amount >= &last_amt
       and   (amount > &last_amt or id > &last_id)
       order  by amount, id)
where  rownum <= 20;
set feedback on
@@../../common/xplan
prompt 관찰: 5-a, 5-b, 5-c 의 TABLE ACCESS BY INDEX ROWID 단계 A-Rows 와 Buffers 를 비교하라. 5-b 는 버릴 7,980건까지 왜 테이블을 읽어야 하나?
prompt       5-c 의 조건이 인덱스 액세스 조건(access)으로 쓰였는지 Predicate 정보도 확인하라.

prompt
prompt ===== [6] 불필요한 소트 제거: union vs union all, distinct vs exists =====
prompt --- [6-a] union: 두 집합이 겹치지 않는데도 중복 제거
set feedback only
select id from big_table where grp_id = 1
union
select id from big_table where grp_id = 2;
set feedback on
@@../../common/xplan
prompt --- [6-b] union all
set feedback only
select id from big_table where grp_id = 1
union all
select id from big_table where grp_id = 2;
set feedback on
@@../../common/xplan
prompt --- [6-c] 조인 후 distinct: 조건에 맞는 50만 건을 모두 읽고 중복 제거
set feedback only
select /*+ leading(g) use_nl(b) index(b w10_grp_amt_ix) */ distinct g.grp_id, g.grp_name
from   w10_grp g, big_table b
where  b.grp_id = g.grp_id
and    b.amount < 5000;
set feedback on
@@../../common/xplan
prompt --- [6-d] exists: 그룹마다 첫 건만 찾으면 멈춤
set feedback only
select g.grp_id, g.grp_name
from   w10_grp g
where  exists (select /*+ no_unnest index(b w10_grp_amt_ix) */ 1
               from   big_table b
               where  b.grp_id = g.grp_id
               and    b.amount < 5000);
set feedback on
@@../../common/xplan
prompt 관찰: 6-a 의 HASH UNIQUE 와 Used-Mem 이 6-b 에서 사라졌는가? 6-c 와 6-d 에서 big_table 인덱스 단계의 A-Rows 와 Buffers 는 몇 배 차이 나는가?

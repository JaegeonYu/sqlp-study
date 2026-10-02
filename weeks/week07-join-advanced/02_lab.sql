-- week07 lab: 스칼라 서브쿼리 캐싱, Semi/Anti 조인, Outer 조인, 고급 조인 기법
@@../../common/session_init

prompt
prompt ===== [1] 스칼라 서브쿼리 캐싱 =====
prompt --- [1-a] 함수 직접 호출 : 10만 건 x 그룹명(NDV 100)
exec w07_cnt.reset
select sum(length(w07_grp_nm(b.grp_id))) as len_sum
from   big_table b
where  b.id <= 100000;
@@../../common/xplan
select w07_cnt.calls as fn_calls from dual;

prompt --- [1-b] 스칼라 서브쿼리로 감싸기 : 같은 10만 건
exec w07_cnt.reset
select sum(length((select w07_grp_nm(b.grp_id) from dual))) as len_sum
from   big_table b
where  b.id <= 100000;
@@../../common/xplan
select w07_cnt.calls as fn_calls from dual;

prompt --- [1-c] 스칼라 서브쿼리 + 입력값 종류가 많을 때 : 고객명(NDV 10,000)
exec w07_cnt.reset
select sum(length((select w07_cust_nm(b.rnd_id) from dual))) as len_sum
from   big_table b
where  b.id <= 100000;
@@../../common/xplan
select w07_cnt.calls as fn_calls from dual;

prompt --- [1-d] 함수 대신 조인
select sum(length(g.grp_nm)) as len_sum
from   big_table b, w07_grp g
where  b.id <= 100000
and    g.grp_id = b.grp_id;
@@../../common/xplan
prompt 관찰: fn_calls 는 [1-a] 100,000 → [1-b] 약 100 → [1-c] 몇 번? A-Time 차이는? 캐시가 효과를 보는 조건은 무엇인가?

prompt
prompt ===== [2] Semi 조인 : 2023-01-01 에 주문한 고객 수 =====
prompt --- [2-a] EXISTS (옵티마이저 선택)
select count(*)
from   w07_cust c
where  exists (select 1 from big_table b
               where  b.rnd_id = c.cust_id
               and    b.reg_dt = date '2023-01-01');
@@../../common/xplan
prompt --- [2-b] IN 으로 써도 같은 계획인가
select count(*)
from   w07_cust c
where  c.cust_id in (select b.rnd_id from big_table b where b.reg_dt = date '2023-01-01');
@@../../common/xplan
prompt --- [2-c] 서브쿼리 Unnesting 을 막으면 (FILTER)
select count(*)
from   w07_cust c
where  exists (select /*+ no_unnest */ 1 from big_table b
               where  b.rnd_id = c.cust_id
               and    b.reg_dt = date '2023-01-01');
@@../../common/xplan
prompt 관찰: [2-a]의 조인 방식(SEMI)은? [2-c] FILTER 아래 서브쿼리의 Starts 는 고객 수(10,000)와 같은가? 다르다면 왜인가?

prompt
prompt ===== [3] Anti 조인과 NOT IN 의 NULL 함정 =====
prompt --- [3-a] NOT EXISTS : 블랙리스트에 없는 고객
select count(*)
from   w07_cust c
where  not exists (select 1 from w07_blacklist k where k.cust_id = c.cust_id);
@@../../common/xplan
prompt --- [3-b] NOT IN : 같은 의도인데 블랙리스트에 NULL 이 1건 있다
select count(*)
from   w07_cust c
where  c.cust_id not in (select k.cust_id from w07_blacklist k);
@@../../common/xplan
prompt --- [3-c] NOT IN + IS NOT NULL
select count(*)
from   w07_cust c
where  c.cust_id not in (select k.cust_id from w07_blacklist k where k.cust_id is not null);
@@../../common/xplan
prompt 관찰: [3-a] 9,995건 / [3-b] 0건. 왜인가? [3-b]의 조인 이름(ANTI NA / ANTI SNA)은 무엇을 뜻하는가?

prompt
prompt ===== [4] Outer 조인의 드라이빙 제약 =====
prompt --- [4-a] NL Outer : 고객(보존되는 쪽)이 드라이빙
select /*+ leading(c b) use_nl(b) index(b w07_big_rnd_dt_ix) */
       count(*), count(b.id), sum(b.amount)
from   w07_cust c
       left outer join big_table b
         on  b.rnd_id = c.cust_id
         and b.reg_dt between date '2023-01-01' and date '2023-01-31'
where  c.region_cd = 'R03' and c.grade = 'VIP';
@@../../common/xplan
prompt --- [4-b] NL 로 주문을 먼저 읽으라고 지시하면?
select /*+ leading(b c) use_nl(c) */
       count(*), count(b.id), sum(b.amount)
from   w07_cust c
       left outer join big_table b
         on  b.rnd_id = c.cust_id
         and b.reg_dt between date '2023-01-01' and date '2023-01-31'
where  c.region_cd = 'R03' and c.grade = 'VIP';
@@../../common/xplan
prompt --- [4-c] Hash Outer 는 Build 쪽을 바꿀 수 있다
select /*+ leading(c b) use_hash(b) full(b) swap_join_inputs(b) */
       count(*), count(b.id), sum(b.amount)
from   w07_cust c
       left outer join big_table b
         on  b.rnd_id = c.cust_id
         and b.reg_dt between date '2023-01-01' and date '2023-01-31'
where  c.region_cd = 'R03' and c.grade = 'VIP';
@@../../common/xplan
prompt 관찰: [4-b]의 힌트는 지켜졌는가? 무시됐다면 그 이유는? [4-c]의 HASH JOIN RIGHT OUTER 는 어느 쪽을 Build 로 썼는가?

prompt
prompt ===== [5] 누적합·직전값 : 셀프 조인 vs 윈도우 함수 =====
prompt --- [5-a] 셀프 조인
set feedback only
select a.sale_dt, a.amt,
       sum(b.amt)                                             as cum_amt,
       max(case when b.sale_dt = a.sale_dt - 1 then b.amt end) as prev_amt
from   w07_daily_sales a, w07_daily_sales b
where  b.sale_dt <= a.sale_dt
group  by a.sale_dt, a.amt
order  by a.sale_dt;
set feedback on
@@../../common/xplan
prompt --- [5-b] 윈도우 함수
set feedback only
select sale_dt, amt,
       sum(amt) over (order by sale_dt) as cum_amt,
       lag(amt) over (order by sale_dt) as prev_amt
from   w07_daily_sales
order  by sale_dt;
set feedback on
@@../../common/xplan
prompt 관찰: [5-a] 조인 단계의 A-Rows(약 50만)와 [5-b]의 A-Rows(1,000). 데이터가 10배가 되면 각각 몇 배가 될까?

prompt
prompt ===== [6] 선분이력 조인 : 주문 시점의 고객 등급 =====
prompt --- [6-a] 올바른 조인 : 주문일이 이력 구간 안에 있는 행만
select h.grade, count(*) as order_cnt
from   big_table b, w07_grade_hist h
where  b.reg_dt between date '2023-01-01' and date '2023-01-31'
and    h.cust_id = b.rnd_id
and    b.reg_dt between h.st_dt and h.ed_dt
group  by h.grade
order  by h.grade;
@@../../common/xplan
prompt --- [6-b] 실수 : 구간 조건을 빠뜨리면
select h.grade, count(*) as order_cnt
from   big_table b, w07_grade_hist h
where  b.reg_dt between date '2023-01-01' and date '2023-01-31'
and    h.cust_id = b.rnd_id
group  by h.grade
order  by h.grade;
@@../../common/xplan
prompt --- [6-c] 현재 등급(마지막 구간)으로 집계하면
select h.grade, count(*) as order_cnt
from   big_table b, w07_grade_hist h
where  b.reg_dt between date '2023-01-01' and date '2023-01-31'
and    h.cust_id = b.rnd_id
and    h.ed_dt = date '9999-12-31'
group  by h.grade
order  by h.grade;
@@../../common/xplan
prompt 관찰: [6-a] 합계 = 31,000건, [6-b]는 4배로 부풀었다. [6-a]와 [6-c]의 등급별 건수가 다른 이유는?

prompt
prompt ===== [7] 소계 만들기 : UNION ALL vs Copy_T vs ROLLUP (2023-01 그룹별 + 전체) =====
prompt --- [7-a] UNION ALL : 같은 데이터를 두 번 읽는다
set feedback only
select to_char(grp_id) as grp, sum(amount) as amt
from   big_table
where  reg_dt between date '2023-01-01' and date '2023-01-31'
group  by grp_id
union all
select 'TOTAL', sum(amount)
from   big_table
where  reg_dt between date '2023-01-01' and date '2023-01-31';
set feedback on
@@../../common/xplan
prompt --- [7-b] Copy_T : 한 번 읽고 2배로 복제
set feedback only
select decode(t.no, 1, to_char(b.grp_id), 'TOTAL') as grp, sum(b.amount) as amt
from   big_table b, w07_copy_t t
where  b.reg_dt between date '2023-01-01' and date '2023-01-31'
group  by decode(t.no, 1, to_char(b.grp_id), 'TOTAL');
set feedback on
@@../../common/xplan
prompt --- [7-c] ROLLUP
set feedback only
select nvl(to_char(grp_id), 'TOTAL') as grp, sum(amount) as amt
from   big_table
where  reg_dt between date '2023-01-01' and date '2023-01-31'
group  by rollup (grp_id);
set feedback on
@@../../common/xplan
prompt 관찰: 세 방식의 Buffers 와 조인/집계 단계의 A-Rows. Copy_T 는 왜 ROLLUP 이 없던 시절의 기법인가? 지금도 쓸모가 있을까?

-- week06 challenge: 3테이블 조인 튜닝
--   BUSAN 지역 VIP 고객의 2023년 1분기 고객별 주문 건수·금액.
--   아래 원본은 조인 순서와 방식이 잘못 고정되어 있다. 결과는 같게 유지하고 Buffers 를 최소화하라.
--   - 힌트를 바꾸거나 지워도 되고, BIG_TABLE 에 인덱스를 추가해도 된다 (이름은 W06_ 로 시작)
--   - 제출: 최종 실행계획, 조인 순서·방식을 그렇게 정한 근거, 인덱스를 추가했다면 컬럼 순서의 근거
@@../../common/session_init

prompt
prompt ===== 원본 SQL =====
set feedback only
select /*+ leading(b c r) use_nl(c) use_nl(r) full(b) */
       r.region_nm, c.cust_nm, count(*) as order_cnt, sum(b.amount) as amt
from   big_table b, w06_cust c, w06_region r
where  b.rnd_id    = c.cust_id
and    c.region_cd = r.region_cd
and    r.region_nm = 'BUSAN'
and    c.grade     = 'VIP'
and    b.reg_dt   >= date '2023-01-01'
and    b.reg_dt    < date '2023-04-01'
group  by r.region_nm, c.cust_nm
order  by amt desc;
set feedback on
@@../../common/xplan
prompt 과제: 어느 테이블에서 출발해야 하는가? 각 조인에 어떤 방식이 맞는가? BIG_TABLE 액세스에 필요한 인덱스는?

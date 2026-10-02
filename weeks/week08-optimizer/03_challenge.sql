-- week08 challenge
--   등급(grade)·티어(tier)·레벨(lvl)이 모두 3인 고객의 거래 합계.
--   옵티마이저가 고객 수를 잘못 추정해 비효율적인 조인 방법을 골랐다.
--   과제: 힌트 없이(SQL 텍스트는 그대로) 통계만 보정해서 올바른 계획이 나오게 하라.
--   조건: Adaptive Plan 이 런타임에 계획을 고쳐 주지 않도록 이 스크립트에서는 꺼 둔다.
@@../../common/session_init

alter session set optimizer_adaptive_plans = false;

prompt
prompt ===== 원본 SQL =====
select c.grade, count(*), sum(b.amount)
from   w08_cust c
       join big_table b on b.rnd_id = c.cust_id
where  c.grade = 3
and    c.tier  = 3
and    c.lvl   = 3
group  by c.grade;
@@../../common/xplan

alter session set optimizer_adaptive_plans = true;
prompt 과제: 1) w08_cust 단계의 E-Rows 와 A-Rows 를 비교하고, 그 오차가 조인 방법 선택에 어떤 영향을 줬는지 설명하라.
prompt       2) 통계를 보정한 뒤 같은 SQL 을 다시 실행해 Before/After Buffers 를 제출하라.
prompt       3) Adaptive Plan 을 켜 두면(기본값) 원본 SQL 의 결과 계획은 어떻게 달라지는가?

-- TEMP-VERIFY (검증 후 삭제)
alter session set optimizer_adaptive_plans = true;
select c.grade, count(*), sum(b.amount) from w08_cust c join big_table b on b.rnd_id = c.cust_id where c.grade = 3 and c.tier = 3 and c.lvl = 3 group by c.grade;
@@xplan_adaptive
declare l varchar2(128); begin l := dbms_stats.create_extended_stats(user, 'W08_CUST', '(GRADE, TIER, LVL)'); end;
/
exec dbms_stats.gather_table_stats(user, 'W08_CUST', method_opt => 'for all columns size 1', no_invalidate => false)
alter session set optimizer_adaptive_plans = false;
select c.grade, count(*), sum(b.amount)
from   w08_cust c
       join big_table b on b.rnd_id = c.cust_id
where  c.grade = 3
and    c.tier  = 3
and    c.lvl   = 3
group  by c.grade;
@@../../common/xplan
alter session set optimizer_adaptive_plans = true;

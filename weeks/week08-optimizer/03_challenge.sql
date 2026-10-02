-- week08 challenge
--   등급(grade)·티어(tier)·레벨(lvl)이 모두 3인 고객의 거래 합계.
--   옵티마이저가 고객 수를 잘못 추정해 비효율적인 조인 방법을 골랐다.
--   과제: 힌트 없이(SQL 텍스트는 그대로) 통계만 보정해서 올바른 계획이 나오게 하라.
@@../../common/session_init

prompt
prompt ===== 원본 SQL =====
select c.grade, count(*), sum(b.amount)
from   w08_cust c
       join big_table b on b.rnd_id = c.cust_id
where  c.grade = 3
and    c.tier  = 3
and    c.lvl   = 3
group  by c.grade;
@@xplan_adaptive
prompt 과제: 1) W08_CUST 단계의 E-Rows 와 A-Rows 를 비교하고, 그 오차가 조인 방법 선택에 어떤 영향을 줬는지 설명하라.
prompt       2) 통계를 보정한 뒤 같은 SQL 을 다시 실행해 Before/After Buffers 를 제출하라.
prompt       3) Adaptive Plan 은 기본으로 켜져 있다. 이 SQL 에서 런타임 보정이 일어나지 않은 이유를 lab [10] 의 계획과 비교해 설명하라.

-- week04 challenge: 인덱스를 못 타는 WHERE 절 고쳐 쓰기
--   C1~C4 각각, 결과는 같게 유지하면서 인덱스를 탈 수 있는 형태로 다시 쓴다.
--   C1~C3은 SQL만 고친다. C4는 인덱스를 하나 추가해도 된다 (추가했다면 DDL도 제출).
--   제출: result.md 2번에 4문제의 Before/After Buffers 표와 근거
@@../../common/session_init

-- 02_lab.sql 에서 만든 인덱스를 지우고 setup 직후 상태에서 시작
drop index if exists w04_closed_id_ix;
drop index if exists w04_upper_name_fx;

prompt
prompt ===== C1 =====
select count(*), sum(amount)
from   big_table
where  reg_dt - 7 > date '2024-09-15';
@@../../common/xplan

prompt
prompt ===== C2 =====
set feedback only
select *
from   w04_code
where  substr(code, 1, 6) = '000012';
set feedback on
@@../../common/xplan

prompt
prompt ===== C3 =====
select *
from   big_table
where  to_char(id) = '12345';
@@../../common/xplan

prompt
prompt ===== C4 =====
select count(*)
from   w04_code
where  nvl(closed_dt, date '9999-12-31') = date '9999-12-31';
@@../../common/xplan

prompt 과제: 각 SQL의 Predicate Information 에서 인덱스를 못 탄 이유를 찾고, 결과가 같은 형태로 다시 써라.
prompt       C2 는 code 가 항상 8자리라는 점, C4 는 NULL 이 인덱스에 저장되는 조건을 활용하라.

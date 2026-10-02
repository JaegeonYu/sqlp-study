-- week09 setup: 쿼리 변환 실습용 부서/사원 테이블
--   부서 100개(region 1..10, 지역당 10개), 사원 10만 명(부서당 1,000명)
--   mgr_no = ceil(emp_no / 20) → 사원 1..5,000 번이 관리자(부하 20명씩)
@@../../common/session_init

drop table if exists w09_emp  purge;
drop table if exists w09_dept purge;

create table w09_dept (
  dept_no   number       primary key,
  dept_name varchar2(30) not null,
  region    number       not null
);
insert into w09_dept
select level, 'DEPT' || level, mod(level, 10) + 1 from dual connect by level <= 100;

create table w09_emp (
  emp_no  number       primary key,
  dept_no number       not null constraint w09_emp_dept_fk references w09_dept,
  mgr_no  number,
  sal     number       not null,
  hire_dt date         not null,
  pad     varchar2(100)
);
exec dbms_random.seed(909)
insert /*+ append */ into w09_emp
select level,
       mod(level, 100) + 1,
       ceil(level / 20),
       trunc(dbms_random.value(2000, 10000)),
       date '2015-01-01' + mod(level, 3650),
       rpad('e', 100, 'e')
from   dual
connect by level <= 100000;
commit;

create index w09_emp_dept_ix on w09_emp (dept_no);
create index w09_emp_mgr_ix  on w09_emp (mgr_no);

exec dbms_stats.gather_table_stats(user, 'W09_DEPT', method_opt => 'for all columns size 1', cascade => true, no_invalidate => false)
exec dbms_stats.gather_table_stats(user, 'W09_EMP',  method_opt => 'for all columns size 1', cascade => true, no_invalidate => false)

prompt
prompt week09 준비 완료

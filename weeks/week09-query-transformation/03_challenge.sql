-- week09 challenge (미니 모의 2 실기형)
--   region = 3 인 부서(10개)마다 급여 1위 사원을 구한다.
--   결과는 같게 유지하고 Buffers 를 줄여라. 인덱스 추가가 필요하면 w09_ 접두어로 만들고 DDL 을 함께 제출한다.
@@../../common/session_init

prompt
prompt ===== 원본 SQL =====
select d.dept_no, d.dept_name, e.emp_no, e.sal
from   w09_dept d,
       (select emp_no, dept_no, sal,
               rank() over (partition by dept_no order by sal desc) rk
        from   w09_emp) e
where  e.dept_no = d.dept_no
and    d.region  = 3
and    e.rk      = 1
order  by d.dept_no, e.emp_no;
@@../../common/xplan
prompt 과제: 1) 부서 10개만 필요한데 왜 사원 10만 건을 모두 읽고 정렬했는가? 뷰 머징·조건절 Pushing 관점에서 설명하라.
prompt       2) 결과를 유지하면서 읽는 양을 줄인 SQL(+필요시 인덱스)을 작성하고 Before/After 를 비교하라.

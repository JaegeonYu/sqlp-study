-- week09 lab: 쿼리 변환 — 옵티마이저가 SQL을 어떻게 다시 쓰는가
--   각 단계는 "변환 허용" vs "변환 금지(힌트)" 를 나란히 실행해 계획 모양과 Buffers 를 비교한다.
@@../../common/session_init

prompt
prompt ===== [1] 서브쿼리 Unnesting =====
prompt --- [1-a] no_unnest: 메인 쿼리 행마다 서브쿼리를 실행(FILTER)
select count(*)
from   w09_emp e
where  exists (select /*+ no_unnest */ 1 from w09_emp x where x.mgr_no = e.emp_no);
@@../../common/xplan
prompt --- [1-b] unnest: 서브쿼리를 조인으로 풀어서 실행
select count(*)
from   w09_emp e
where  exists (select /*+ unnest */ 1 from w09_emp x where x.mgr_no = e.emp_no);
@@xplan_outline
prompt 관찰: [1-a] 서브쿼리 단계의 Starts 는 몇 번인가? [1-b] 는 어떤 조인(SEMI)으로 바뀌었고 Buffers 는?
prompt       Outline Data 에서 UNNEST 힌트와 쿼리 블록 이름을 찾아보자.

prompt
prompt ===== [2] FILTER 서브쿼리 캐싱 =====
select /* w09_filter_cache */ count(*), sum(e.sal)
from   w09_emp e
where  e.dept_no in (select /*+ no_unnest */ d.dept_no from w09_dept d where d.region = 3);
@@../../common/xplan
prompt 관찰: 메인 쿼리는 10만 건인데 서브쿼리 Starts 는 몇 번인가? 입력값(dept_no)의 종류가 100개뿐이라는 점과 연결해 보자.

prompt
prompt ===== [3] 뷰 머징 (View Merging) =====
prompt --- [3-a] no_merge: 인라인 뷰를 먼저 만들고(VIEW) 조인
select /*+ no_merge(v) */ d.dept_name, v.avg_sal
from   w09_dept d,
       (select dept_no, avg(sal) avg_sal from w09_emp group by dept_no) v
where  v.dept_no = d.dept_no
and    d.region  = 3;
@@../../common/xplan
prompt --- [3-b] merge: 뷰를 풀어서 조인한 뒤 GROUP BY
select /*+ merge(v) */ d.dept_name, v.avg_sal
from   w09_dept d,
       (select dept_no, avg(sal) avg_sal from w09_emp group by dept_no) v
where  v.dept_no = d.dept_no
and    d.region  = 3;
@@../../common/xplan
prompt 관찰: [3-a] 는 사원 10만 건을 모두 집계한 뒤 조인했다. [3-b] 에서 GROUP BY 는 조인 앞인가 뒤인가? 집계 대상 건수는?

prompt
prompt ===== [4] 조건절 Pushing =====
prompt --- [4-a] 뷰 바깥 조건이 뷰 안으로 들어간다 (Filter Pushdown)
select *
from   (select dept_no, count(*) cnt, max(sal) max_sal from w09_emp group by dept_no)
where  dept_no = 7;
@@../../common/xplan
prompt 관찰: Predicate Information 에서 dept_no = 7 이 어느 Id 에 access 조건으로 붙었나?
prompt --- [4-b] no_push_pred: 조인 조건을 뷰 안에 넣지 않음
select /*+ leading(d) use_nl(v) no_push_pred(v) */ d.dept_name, v.cnt
from   w09_dept d,
       (select dept_no, count(*) cnt from w09_emp group by dept_no) v
where  v.dept_no = d.dept_no
and    d.region  = 3;
@@../../common/xplan
prompt --- [4-c] push_pred: 조인 조건을 뷰 안으로 (Join Predicate Pushdown)
select /*+ leading(d) use_nl(v) push_pred(v) */ d.dept_name, v.cnt
from   w09_dept d,
       (select dept_no, count(*) cnt from w09_emp group by dept_no) v
where  v.dept_no = d.dept_no
and    d.region  = 3;
@@xplan_outline
prompt 관찰: [4-c] 에 VIEW PUSHED PREDICATE 가 보이는가? 뷰 내부가 부서별로 몇 번(Starts) 실행됐고 Buffers 는?

prompt
prompt ===== [5] 조건절 이행 (Transitive Predicate) =====
select count(*), sum(e.sal)
from   w09_emp e, w09_dept d
where  e.dept_no = d.dept_no
and    d.dept_no = 7;
@@../../common/xplan
prompt 관찰: SQL 에는 e.dept_no = 7 이 없다. Predicate Information 에서 W09_EMP 쪽 조건을 찾아보자.

prompt
prompt ===== [6] OR-Expansion =====
prompt --- [6-a] 기본(옵티마이저 판단)
select emp_no, mgr_no, sal from w09_emp where emp_no = 77 or mgr_no = 77;
@@../../common/xplan
prompt --- [6-b] no_or_expand
select /*+ no_or_expand */ emp_no, mgr_no, sal from w09_emp where emp_no = 77 or mgr_no = 77;
@@../../common/xplan
prompt --- [6-c] use_concat (책 시절 힌트)
select /*+ use_concat */ emp_no, mgr_no, sal from w09_emp where emp_no = 77 or mgr_no = 77;
@@xplan_outline
prompt 관찰: OR 조건이 UNION ALL 두 갈래로 나뉘었나(VW_ORE_ 뷰, CONCATENATION)? 금지했을 때는 어떤 방식으로 처리했나?

prompt
prompt ===== [7] 조인 제거 (Join Elimination) =====
prompt --- [7-a] 기본: 부서 테이블 컬럼을 쓰지 않는 조인
select count(*), sum(e.sal)
from   w09_emp e, w09_dept d
where  e.dept_no = d.dept_no;
@@../../common/xplan
prompt --- [7-b] no_eliminate_join
select /*+ no_eliminate_join(d) */ count(*), sum(e.sal)
from   w09_emp e, w09_dept d
where  e.dept_no = d.dept_no;
@@../../common/xplan
prompt 관찰: [7-a] 계획에 W09_DEPT 가 있는가? FK 와 e.dept_no NOT NULL 제약이 왜 필요한지 설명해 보자.

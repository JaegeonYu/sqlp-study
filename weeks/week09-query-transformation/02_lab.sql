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
prompt 관찰: 메인 쿼리는 10만 건인데 서브쿼리 Starts 는 몇 번인가? 입력값(dept_no)이 100종뿐이니 이상적이면 100번이다.
prompt       실제 Starts 가 100보다 훨씬 크다면, FILTER 캐시가 해시 테이블이라 입력값이 섞여 들어올 때 충돌로 재실행되기 때문이다.

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
prompt 관찰: dept_no = 7 필터가 GROUP BY 보다 먼저(테이블을 읽는 Id 에) 적용됐나? 집계 대상은 10만 건인가 1,000건인가?
prompt --- [4-b] 뷰를 머징하지 않고(no_merge), 조인 조건도 넣지 않음(no_push_pred)
select /*+ leading(d) no_merge(v) no_push_pred(v) */ d.dept_name, v.cnt
from   w09_dept d,
       (select dept_no, count(*) cnt from w09_emp group by dept_no) v
where  v.dept_no = d.dept_no
and    d.region  = 3;
@@../../common/xplan
prompt --- [4-c] 뷰는 그대로 두고 조인 조건만 뷰 안으로 (Join Predicate Pushdown)
select /*+ leading(d) use_nl(v) no_merge(v) push_pred(v) */ d.dept_name, v.cnt
from   w09_dept d,
       (select dept_no, count(*) cnt from w09_emp group by dept_no) v
where  v.dept_no = d.dept_no
and    d.region  = 3;
@@xplan_outline
prompt 관찰: [4-b] 는 사원 10만 건 전체를 집계했다. [4-c] 에 VIEW PUSHED PREDICATE 가 보이는가?
prompt       뷰 내부가 부서별로 몇 번(Starts) 실행됐고 Buffers 는? Outline 의 PUSH_PRED 를 찾아보자.
prompt       (참고: no_merge 만 걸어도 23ai 옵티마이저는 비용을 따져 스스로 JPPD 를 고른다. 머징까지 허용하면 [3-b] 처럼 뷰를 아예 풀어 버린다)

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
set feedback only
prompt --- [6-a] 기본(옵티마이저 판단)
select emp_no, mgr_no, sal from w09_emp where emp_no = 77 or mgr_no = 77;
set feedback on
@@../../common/xplan
set feedback only
prompt --- [6-b] or_expand: 23ai 의 비용 기반 OR-Expansion
select /*+ or_expand */ emp_no, mgr_no, sal from w09_emp where emp_no = 77 or mgr_no = 77;
set feedback on
@@xplan_outline
set feedback only
prompt --- [6-c] use_concat (책 시절 힌트)
select /*+ use_concat */ emp_no, mgr_no, sal from w09_emp where emp_no = 77 or mgr_no = 77;
set feedback on
@@../../common/xplan
prompt 관찰: [6-a] 기본 계획은 OR 를 어떻게 처리했나(BITMAP OR: B*Tree 인덱스 두 개를 비트맵으로 바꿔 합침)?
prompt       [6-b] 의 VW_ORE_ 뷰와 UNION-ALL, [6-c] 의 CONCATENATION 은 같은 아이디어다. 두 번째 갈래의 LNNVL 조건은 왜 필요한가?

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

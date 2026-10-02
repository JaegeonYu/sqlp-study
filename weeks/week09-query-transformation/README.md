# Week 09 — 쿼리 변환 + 미니 모의 2

| 책 | 『오라클 성능 고도화 원리와 해법 II』 4장 쿼리 변환 |
|---|---|

## 학습 목표
- 옵티마이저가 실행 전에 SQL을 **의미는 같고 더 싼 형태로 다시 쓴다**는 것을 실행계획 모양으로 확인한다.
- 대표 변환 6가지(서브쿼리 Unnesting, 뷰 머징, 조건절 Pushing, 조건절 이행, OR-Expansion, 조인 제거)를 힌트로 켜고 끄며 Buffers를 비교한다.
- `+ALIAS +OUTLINE` 포맷으로 "어떤 변환이 적용됐는지"를 읽어낼 수 있다.
- 미니 모의 2로 8~9주차를 점검한다.

## 실행
```bash
bash scripts/run.sh weeks/week09-query-transformation/01_setup.sql
bash scripts/run.sh weeks/week09-query-transformation/02_lab.sql       weeks/week09-query-transformation/submissions/<id>/lab.txt
bash scripts/run.sh weeks/week09-query-transformation/03_challenge.sql weeks/week09-query-transformation/submissions/<id>/challenge.txt
```
실습 데이터: 부서 `W09_DEPT` 100개(region 1~10, 지역당 10개), 사원 `W09_EMP` 10만 명(부서당 1,000명). 사원 1~5,000번은 관리자이고 부하가 20명씩 있습니다(`mgr_no = ceil(emp_no/20)`). FK `w09_emp.dept_no → w09_dept`, `dept_no NOT NULL`.

## 실습 구성 (`02_lab.sql`)
| # | 변환 | 비교 | 볼 것 |
|---|---|---|---|
| 1 | 서브쿼리 Unnesting | `no_unnest` vs `unnest` | FILTER의 서브쿼리 Starts, SEMI 조인으로 바뀐 뒤의 Buffers, Outline의 `UNNEST` |
| 2 | FILTER 캐싱 | `no_unnest` + 입력값 100종 | 메인 10만 건 대비 서브쿼리 Starts |
| 3 | 뷰 머징 | `no_merge` vs `merge` | GROUP BY가 조인 앞인지 뒤인지, 집계 대상 건수 |
| 4 | 조건절 Pushing | 필터 pushdown / `no_push_pred` vs `push_pred` | `VIEW PUSHED PREDICATE`, 뷰 내부 Starts |
| 5 | 조건절 이행 | — | SQL에 없는 `E.DEPT_NO=7`이 Predicate Information에 생김 |
| 6 | OR-Expansion | 기본 / `no_or_expand` / `use_concat` | `VW_ORE_` 뷰와 UNION ALL, 금지했을 때의 처리 방식 |
| 7 | 조인 제거 | 기본 vs `no_eliminate_join` | 계획에서 `W09_DEPT`가 사라지는지 |

헬퍼 `xplan_outline.sql`은 `ALLSTATS LAST +ALIAS +OUTLINE` 포맷으로 출력합니다.
- **Query Block Name / Object Alias:** `SEL$1`, `SEL$2`가 변환 뒤 `SEL$5DA710D3`처럼 합쳐진 이름으로 바뀝니다.
- **Outline Data:** 옵티마이저가 실제로 적용한 변환이 힌트 형태(`UNNEST(@"SEL$2")` 등)로 나옵니다. 이 블록을 그대로 SQL에 넣으면 계획을 고정할 수 있습니다.

더 깊이 보려면 10053 트레이스를 써 봅니다. `alter session set events '10053 trace name context forever, level 1'` 후 SQL을 **하드 파싱**시키면 변환 검토 과정이 트레이스 파일에 남습니다. 끄는 명령은 `... context off`입니다.

## 미니 모의 2
- **필기:** `mock.md`의 5문항(15분)
- **실기:** `03_challenge.sql`(30분). region 3의 부서별 급여 1위 사원을 구하는 SQL이 사원 10만 건을 모두 읽고 정렬합니다. 결과는 유지하고 Buffers를 줄입니다.
- 답안은 `submissions/<id>/mock.md`(필기)와 `result.md`(실기)에 적습니다.

## 책과 다른 점 (23ai)
<!-- CI 관찰 결과로 채움 -->

## 토론 질문
1. Unnesting이 항상 이득일까? FILTER(캐싱)가 더 나은 경우는 언제일까?
2. 뷰 머징을 막는 요소(ROWNUM, 분석 함수, 집합 연산 등)는 왜 막을 수밖에 없을까?
3. 쿼리 변환은 휴리스틱(무조건 적용)과 비용 기반(비교 후 적용)으로 나뉜다. 오늘 본 변환을 둘로 나눠 보자.

## 제출
`weeks/week09-query-transformation/submissions/<github-id>/`
- `result.md`
- `mock.md`
- `lab.txt`
- `challenge.txt`

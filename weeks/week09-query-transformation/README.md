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
| 2 | FILTER 캐싱 | `no_unnest` + 입력값 100종 | 메인 10만 건 대비 서브쿼리 Starts. 이상적이면 100번이지만, 해시 충돌 때문에 그보다 많이 실행됨 |
| 3 | 뷰 머징 | `no_merge` vs `merge` | GROUP BY가 조인 앞인지 뒤인지, 집계 대상 건수 |
| 4 | 조건절 Pushing | 필터 pushdown / `no_merge + no_push_pred` vs `no_merge + push_pred` | 필터가 GROUP BY 전에 적용되는지, `VIEW PUSHED PREDICATE`, 뷰 내부 Starts |
| 5 | 조건절 이행 | — | SQL에 없는 `E.DEPT_NO=7`이 Predicate Information에 생김 |
| 6 | OR 조건 처리 | 기본 / `or_expand` / `use_concat` | 기본은 BITMAP OR, `VW_ORE_` 뷰와 UNION-ALL, CONCATENATION과 `LNNVL` |
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
- **OR 조건의 기본 처리는 BITMAP OR입니다.** 이 환경에서 힌트 없이 실행하면 B*Tree 인덱스 두 개를 비트맵으로 바꿔 합치는 계획(`BITMAP CONVERSION ... BITMAP OR`)을 골랐습니다. 12.2부터 OR-Expansion은 비용 기반 `OR_EXPAND`(`VW_ORE_` 뷰 + UNION-ALL)로 바뀌었습니다. 책의 `USE_CONCAT`(CONCATENATION)도 여전히 동작합니다. 두 방식 모두 두 번째 갈래에 `LNNVL` 필터를 붙여 중복을 제거합니다.
- **FILTER 서브쿼리 캐시는 생각보다 자주 빗나갑니다.** 입력값이 100종인데 서브쿼리가 6,094번 실행됐습니다. 캐시가 해시 테이블이라, 값이 섞여 들어오면 충돌로 재실행되기 때문입니다.
- **Unnesting 효과:** EXISTS 서브쿼리를 `no_unnest`로 막으면 FILTER 101K Buffers, 풀면 `HASH JOIN RIGHT SEMI` 466 Buffers였습니다. Semi 조인에서도 Build/Probe가 바뀝니다(`SWAP_JOIN_INPUTS`).
- **GROUP BY 뷰의 머징과 JPPD는 비용 기반입니다(11g~).** 힌트 없이 두면 GROUP BY 뷰를 조인 뒤로 풀어 버리거나(Complex View Merging), `no_merge`만 걸어도 스스로 `VIEW PUSHED PREDICATE`를 고릅니다.
- **조인 제거는 다른 변환과 겹쳐서 일어납니다.** [5]의 조건절 이행 실습에서도 `W09_DEPT`가 FK 덕분에 계획에서 사라졌습니다.

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

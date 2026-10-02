# Week 07 — 조인 II: 스칼라 서브쿼리, Semi/Anti, 고급 조인 기법

| 책 | 『오라클 성능 고도화 원리와 해법 II』 2장 조인 원리와 활용 (후반부: 스칼라 서브쿼리, 고급 조인 기법) |
|---|---|

## 학습 목표
- 스칼라 서브쿼리 캐싱이 **함수 호출 횟수**를 얼마나 줄이는지 세어 본다. 캐시가 듣지 않는 조건(입력값 종류가 많을 때)도 확인한다.
- `EXISTS`, `IN`, `NOT EXISTS`, `NOT IN`이 Semi/Anti 조인으로 바뀌는 과정을 본다. `NOT IN`과 NULL이 만나면 결과가 왜 사라지는지 설명할 수 있다.
- Outer 조인에서 NL은 드라이빙 순서가 고정되지만 Hash는 Build를 바꿀 수 있다. 이것을 확인한다.
- 셀프 조인을 윈도우 함수로, UNION ALL을 ROLLUP으로 바꿔 **같은 데이터를 여러 번 읽는 SQL**을 한 번 읽기로 줄인다.
- 선분이력 조인의 올바른 조건과, 조건을 빠뜨렸을 때의 행 증폭을 본다.

## 데이터
| 객체 | 건수 | 설명 |
|---|---|---|
| `W07_CUST` | 10,000 | 고객 (week06과 같은 분포) |
| `W07_GRP` | 100 | BIG_TABLE.grp_id의 그룹명 |
| `W07_BLACKLIST` | 6 | 고객번호 5건 + **NULL 1건** |
| `W07_DAILY_SALES` | 1,000 | 일자별 매출 (BIG_TABLE 집계) |
| `W07_GRADE_HIST` | 40,000 | 고객 등급 선분이력, 고객당 4구간(250일씩), 마지막 구간 종료일 9999-12-31 |
| `W07_COPY_T` | 2 | 소계용 복제 테이블 |
| `W07_BIG_RND_DT_IX` | — | BIG_TABLE(rnd_id, reg_dt) |
| `W07_CNT` | — | 함수 호출 횟수 카운터 패키지 |
| `W07_GRP_RATE`, `W07_CUST_PTS`, `W07_GRP_NM` | — | 조회 함수: 그룹 할인율(NUMBER), 고객 포인트(NUMBER), 그룹명(VARCHAR2) |

BIG_TABLE의 `rnd_id`는 week06과 마찬가지로 "주문의 고객번호"로 씁니다.

## 실행
```bash
bash scripts/run.sh weeks/week07-join-advanced/01_setup.sql
bash scripts/run.sh weeks/week07-join-advanced/02_lab.sql       weeks/week07-join-advanced/submissions/<id>/lab.txt
bash scripts/run.sh weeks/week07-join-advanced/03_challenge.sql weeks/week07-join-advanced/submissions/<id>/challenge.txt
```

## 실습 (`02_lab.sql`)
| # | 내용 | 볼 것 |
|---|---|---|
| 1 | 스칼라 서브쿼리 캐싱 | `fn_calls`와 `FAST DUAL` Starts: 직접 호출 / 서브쿼리(NDV 100) / 서브쿼리(NDV 10,000) / VARCHAR2 반환 함수 / 함수 대신 조인 |
| 2 | Semi 조인 | 옵티마이저가 고른 방식(SORT UNIQUE + 조인), `EXISTS`와 `IN`의 계획이 같은지, `hash_sj`, `no_unnest` 시 FILTER의 Starts |
| 3 | Anti 조인과 NULL | `NOT EXISTS` 9,995건 vs `NOT IN` 0건, `ANTI NA`/`ANTI SNA`의 의미 |
| 4 | Outer 조인 | NL Outer의 드라이빙 고정, 힌트가 무시되는지, `HASH JOIN RIGHT OUTER` |
| 5 | 누적합·직전값 | 셀프 조인 A-Rows(약 50만) vs 윈도우 함수 |
| 6 | 선분이력 조인 | 올바른 `between` 조건, 빠뜨렸을 때 4배 증폭, 현재 등급 vs 시점 등급 |
| 7 | 소계 | UNION ALL(2회 스캔) / Copy_T(1회 스캔 + 2배 복제) / ROLLUP |

## 챌린지 (`03_challenge.sql`)
2023년 1월 그룹별 매출 리포트입니다. 원본은 BIG_TABLE을 **여러 번** 읽습니다. 그룹마다 실행되는 스칼라 서브쿼리, 전체 합계 서브쿼리, 불필요한 셀프 조인(`b2`, `b3`)이 섞여 있고, 그룹명은 함수로 가져옵니다.
- 원본 실행계획에 `b3`가 보이는가? 보이지 않는다면 옵티마이저가 무엇을 한 것인가? (9주차 "쿼리 변환"의 Join Elimination 예고편)
- 결과 100행은 그대로 두고 **BIG_TABLE을 한 번만 읽도록** 다시 씁니다. 인덱스는 추가하지 않습니다.
- 제출할 것:
  - Before/After Buffers
  - 실행계획에서 BIG_TABLE 액세스 단계의 Starts 합계
  - 쓴 기법(조건부 집계 `sum(case ...)`, `ratio_to_report` / `sum() over ()`, 조인으로 함수 대체 등)
- 생각해 볼 것: 1월 행과 12월 행을 한 번에 읽은 뒤, 어떻게 구분해서 집계할 것인가?

## 책과 다른 점 (23ai)
- **스칼라 서브쿼리 캐시 크기.** 책(10g)은 캐시 엔트리가 256개 정도라고 설명합니다. 이후 버전은 캐시 크기가 메모리 단위(`_query_execution_cache_max_size`)로 관리되는 것으로 알려져 있습니다. 그래서 **반환값이 큰 타입일수록 담을 수 있는 엔트리 수가 줄어들 수** 있습니다.
  - CI에서 처음 실행했을 때는 VARCHAR2(크기 미지정) 반환 함수의 입력값 100종을 10만 건에 적용했더니 **70,030번 호출**됐습니다. 캐시 적중률이 30% 수준이었습니다.
  - [1-b](NUMBER 반환)와 [1-d](VARCHAR2 반환)를 비교해 보세요. `cast(... as varchar2(20))`처럼 반환 크기를 줄이면 달라지는지 실험해 보는 것도 좋은 블로그 소재입니다.
- **Semi 조인 → 일반 조인 변환.** 서브쿼리 결과를 먼저 중복 제거(`SORT UNIQUE` / `HASH UNIQUE`)할 수 있으면, 옵티마이저는 Semi 조인 대신 일반 조인으로 바꾸기도 합니다. 그러면 서브쿼리 쪽이 드라이빙 테이블이 될 수 있습니다. [2-a]에서 확인하세요.
- **Null-Aware Anti Join(11g~).** 책 시절에는 `NOT IN` 서브쿼리 컬럼에 NOT NULL 제약이 없으면 Anti 조인으로 바뀌지 못하고 FILTER로 처리됐습니다. 지금은 `HASH JOIN ANTI NA`(또는 `SNA`)로 조인 처리하면서도 NULL 의미를 지킵니다. 그래도 **결과가 0건이 되는 의미 자체는 그대로**입니다.
- **Hash Outer 조인의 Build 교체(10g~).** `swap_join_inputs`로 보존되지 않는 쪽을 Build로 바꾸면 `HASH JOIN RIGHT OUTER`가 됩니다. 책에도 나오지만, 23ai에서는 옵티마이저가 힌트 없이 이렇게 고르는 경우가 많습니다.
- **Outer 조인 드라이빙 제약(12c~ 일부 완화).** ANSI 문법과 Lateral View 변환으로 이전보다 유연해졌습니다. 그래도 NL Outer에서 보존 테이블을 Inner로 두는 것은 여전히 불가능합니다. [4-b]의 실제 계획으로 확인하세요.

## 토론 질문
1. 스칼라 서브쿼리 캐싱을 노리고 `(select f(x) from dual)`로 감싸는 기법이 역효과를 낼 수 있는 경우는? (입력값 종류, 정렬 순서)
2. `DETERMINISTIC` 함수 선언과 스칼라 서브쿼리 캐싱은 무엇이 다른가? 캐시가 유지되는 범위(Fetch Call 단위 vs 쿼리 단위)는?
3. 선분이력 테이블에서 "현재 등급"을 빨리 찾으려면 어떤 인덱스가 좋을까? `ed_dt = 9999-12-31` vs `st_dt <= :d and ed_dt >= :d` 조건의 인덱스 설계 차이는?
4. 리포트 SQL을 한 번 스캔으로 만들면 Buffers는 줄지만 SQL은 복잡해진다. 실무에서 어디까지 허용할 것인가?

## 제출
`weeks/week07-join-advanced/submissions/<github-id>/`
- `result.md`
- `lab.txt`
- `challenge.txt`

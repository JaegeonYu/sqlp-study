# Week 11 — 고급 SQL 활용, 병렬 처리

| 책 | 『오라클 성능 고도화 원리와 해법 II』 6장 고급 SQL 활용, 7장 병렬 처리 |
|---|---|

## 학습 목표
- 같은 테이블을 여러 번 읽는 SQL을 **한 번 스캔**으로 바꾼다 (CASE 집계, WITH절 materialize, MERGE).
- 상관 서브쿼리로 풀던 그룹 내 순위·Top-N을 **윈도우 함수**로 바꾸고 비용 차이를 측정한다.
- 병렬 실행계획을 읽는다: PX COORDINATOR, PX SEND / RECEIVE, TQ, IN-OUT, PQ Distrib. 병렬 조인의 분배 방식(broadcast / hash)을 구분한다.
- 힌트가 실제로 적용되었는지 **Hint Report**로 확인하는 습관을 들인다.

> **주의: Oracle 23ai Free는 병렬 실행을 지원하지 않습니다.** `v$option`의 `Parallel execution`이 `FALSE`이고 `parallel_max_servers`는 1입니다. `parallel` 힌트를 줘도 옵티마이저가 무시합니다(Hint Report에 `U - parallel(b 2)`로 표시). 그래서 이번 주는 이렇게 진행합니다.
> - 병렬 처리가 **거부되는 것**을 DB에서 직접 확인합니다 (실습 [5]~[7]).
> - 병렬 실행계획 **읽기**는 아래 "병렬 실행계획 읽기" 예시로 연습합니다. 예시는 Enterprise Edition에서 나오는 전형적인 형태를 설명용으로 정리한 것으로, 이 DB에서 나온 결과가 아닙니다.

## 실행
```bash
bash scripts/run.sh weeks/week11-advanced-sql-parallel/01_setup.sql
bash scripts/run.sh weeks/week11-advanced-sql-parallel/02_lab.sql       weeks/week11-advanced-sql-parallel/submissions/<id>/lab.txt
bash scripts/run.sh weeks/week11-advanced-sql-parallel/03_challenge.sql weeks/week11-advanced-sql-parallel/submissions/<id>/challenge.txt
```

## 실습 (`02_lab.sql`)
| # | 내용 | 볼 것 |
|---|---|---|
| 1 | union all 3번 스캔 vs CASE 한 번 스캔 | Buffers 비율 (약 56,600 vs 18,870) |
| 2 | WITH절 materialize vs inline | TEMP TABLE TRANSFORMATION, BIG_TABLE 스캔 횟수 |
| 3 | UPDATE+INSERT vs MERGE | session logical reads, execute count |
| 4 | 그룹 내 Top-N: 상관 서브쿼리 vs `row_number()` | 서브쿼리 Starts(1만 번), 전체 Buffers, WINDOW SORT PUSHED RANK |
| 5 | 병렬 처리 가능 여부 | `v$option`의 Parallel execution, `parallel_max_servers` |
| 6 | `parallel` 힌트 + Hint Report | Queries Parallelized = 0, `U - parallel(b 2)` |
| 7 | 병렬 DML 시도 | `append`(LOAD AS SELECT)는 적용되고 `parallel`은 무시됨 |

`pq_stat.sql`(직전 SQL의 `v$pq_sesstat`)과 `xplan_hint.sql`(실행계획 + Hint Report)은 이번 주 전용 헬퍼입니다.

## 병렬 실행계획 읽기 (예시로 연습)
### 컬럼과 오퍼레이션
| 컬럼 / 오퍼레이션 | 의미 |
|---|---|
| PX COORDINATOR | QC(Query Coordinator). 사용자 세션이 PX 서버들의 결과를 모은다 |
| PX BLOCK ITERATOR | 테이블을 블록 범위(granule)로 나눠 PX 서버에 나눠준다 |
| PX SEND / PX RECEIVE | PX 서버 집합 사이에서 데이터를 주고받는 지점 |
| TQ | Table Queue. `Q1,00`처럼 데이터가 지나가는 통로 번호. 이름 컬럼에는 `:TQ10000`으로 나온다 |
| IN-OUT | `P->P`(서버 집합 간 재분배), `P->S`(QC로 보냄), `PCWP`/`PCWC`(같은 서버 집합 안에서 부모·자식과 이어서 처리) |
| PQ Distrib | 재분배 방식: HASH, BROADCAST, RANGE, ROUND-ROBIN, QC (RAND) 등 |

### 예시 A. 병렬 집계 `select /*+ parallel(b 2) */ grp_id, sum(amount) from big_table b group by grp_id`
```text
| Id | Operation                 | Name      |    TQ  |IN-OUT| PQ Distrib |
|  0 | SELECT STATEMENT          |           |        |      |            |
|  1 |  PX COORDINATOR           |           |        |      |            |
|  2 |   PX SEND QC (RANDOM)     | :TQ10001  |  Q1,01 | P->S | QC (RAND)  |
|  3 |    HASH GROUP BY          |           |  Q1,01 | PCWP |            |
|  4 |     PX RECEIVE            |           |  Q1,01 | PCWP |            |
|  5 |      PX SEND HASH         | :TQ10000  |  Q1,00 | P->P | HASH       |
|  6 |       HASH GROUP BY       |           |  Q1,00 | PCWP |            |
|  7 |        PX BLOCK ITERATOR  |           |  Q1,00 | PCWC |            |
|  8 |         TABLE ACCESS FULL | BIG_TABLE |  Q1,00 | PCWP |            |
```
읽는 순서:
1. 첫 번째 서버 집합(Q1,00)이 블록 범위를 나눠 읽고(7·8), 자기 몫을 먼저 부분 집계합니다(6).
2. `grp_id` 해시값으로 두 번째 서버 집합에 재분배합니다(5, P->P, HASH).
3. 두 번째 집합(Q1,01)이 받은 그룹을 최종 집계해(3) QC로 보냅니다(2, P->S).

질문: 6번(부분 집계)이 없다면 5번에서 재분배되는 행 수는 어떻게 달라질까요?

### 예시 B. 작은 테이블 broadcast `pq_distribute(b broadcast none)`
```text
| Id | Operation                  | Name      |    TQ  |IN-OUT| PQ Distrib |
|  0 | SELECT STATEMENT           |           |        |      |            |
|  1 |  SORT AGGREGATE            |           |        |      |            |
|  2 |   PX COORDINATOR           |           |        |      |            |
|  3 |    PX SEND QC (RANDOM)     | :TQ10001  |  Q1,01 | P->S | QC (RAND)  |
|  4 |     SORT AGGREGATE         |           |  Q1,01 | PCWP |            |
|  5 |      HASH JOIN             |           |  Q1,01 | PCWP |            |
|  6 |       PX RECEIVE           |           |  Q1,01 | PCWP |            |
|  7 |        PX SEND BROADCAST   | :TQ10000  |  Q1,00 | P->P | BROADCAST  |
|  8 |         PX BLOCK ITERATOR  |           |  Q1,00 | PCWC |            |
|  9 |          TABLE ACCESS FULL | W11_GRP   |  Q1,00 | PCWP |            |
| 10 |       PX BLOCK ITERATOR    |           |  Q1,01 | PCWC |            |
| 11 |        TABLE ACCESS FULL   | BIG_TABLE |  Q1,01 | PCWP |            |
```
`W11_GRP`(12건)만 모든 PX 서버에 복제(BROADCAST)합니다. 큰 `BIG_TABLE`은 각 서버가 자기가 읽은 범위 안에서 바로 조인합니다(10·11, 재분배 없음).

### 예시 C. 양쪽 hash 분배 `pq_distribute(b hash hash)`
```text
| Id | Operation                  | Name      |    TQ  |IN-OUT| PQ Distrib |
|  0 | SELECT STATEMENT           |           |        |      |            |
|  1 |  SORT AGGREGATE            |           |        |      |            |
|  2 |   PX COORDINATOR           |           |        |      |            |
|  3 |    PX SEND QC (RANDOM)     | :TQ10002  |  Q1,02 | P->S | QC (RAND)  |
|  4 |     SORT AGGREGATE         |           |  Q1,02 | PCWP |            |
|  5 |      HASH JOIN BUFFERED    |           |  Q1,02 | PCWP |            |
|  6 |       PX RECEIVE           |           |  Q1,02 | PCWP |            |
|  7 |        PX SEND HASH        | :TQ10000  |  Q1,00 | P->P | HASH       |
|  8 |         PX BLOCK ITERATOR  |           |  Q1,00 | PCWC |            |
|  9 |          TABLE ACCESS FULL | W11_GRP   |  Q1,00 | PCWP |            |
| 10 |       PX RECEIVE           |           |  Q1,02 | PCWP |            |
| 11 |        PX SEND HASH        | :TQ10001  |  Q1,01 | P->P | HASH       |
| 12 |         PX BLOCK ITERATOR  |           |  Q1,01 | PCWC |            |
| 13 |          TABLE ACCESS FULL | BIG_TABLE |  Q1,01 | PCWP |            |
```
양쪽을 모두 조인 키(`grp_id`) 해시값으로 재분배합니다. 100만 건짜리 `BIG_TABLE`도 서버 간에 이동합니다(11, P->P). `HASH JOIN BUFFERED`는 받은 데이터를 버퍼에 모았다가 조인한다는 뜻입니다.

질문: 예시 B와 C에서 서버 간에 이동하는 행 수를 각각 추정해 보세요. 두 테이블이 모두 수천만 건이면 어느 쪽을 골라야 할까요?

## 챌린지
`03_challenge.sql`: 2023년 월별 (전체 건수, `status='N'` 건수, `grp_id` 1~10 금액 합계) 리포트입니다.
- 원본은 BIG_TABLE을 **세 번** 읽어 조인합니다(Buffers 약 56,600).
- 결과(12행, 정렬 포함)를 그대로 유지하면서 **한 번만 읽도록** 다시 씁니다. 인덱스는 추가하지 않습니다.
- 추가 질문: 어떤 달에 `status='N'`이 0건이면 원본과 튜닝 SQL의 결과가 같을까요? 원본의 조인 방식이 결과에 어떤 영향을 주는지 설명하세요.

## 책과 다른 점 (23ai)
- **병렬 실행 미지원(Free 에디션):** 이 환경의 `v$option`에서 `Parallel execution = FALSE`, `parallel_max_servers = 1`입니다. `parallel` 힌트는 Hint Report에 Unused로 표시되고, 실행계획에 PX 오퍼레이션이 나오지 않습니다. 병렬 실행을 직접 측정하려면 Enterprise Edition 환경이 필요합니다.
- **Hint Report (19c~):** 실행계획 아래에 힌트별 적용 여부(`U` = Unused, `E` = Error)가 나옵니다. 책 시절에는 힌트가 무시되어도 알려주지 않아서 실행계획을 보고 추측해야 했습니다.
- **CURSOR DURATION MEMORY (12.2~):** WITH절 materialize가 실제 임시 테이블 대신 메모리 기반 임시 테이블을 씁니다. 실습 [2-a]의 `LOAD AS SELECT (CURSOR DURATION MEMORY)`가 그것입니다.
- **OPTIMIZER STATISTICS GATHERING (12c~):** 빈 테이블에 direct path로 적재하면 적재하면서 통계를 함께 수집합니다(실습 [7] 실행계획).
- **Hybrid Hash 분배 (12c~):** EE에서 힌트 없이 병렬 조인을 실행하면 PQ Distrib에 `HYBRID HASH`가 보일 수 있습니다. 실제 행 수를 보고 실행 중에 broadcast와 hash 중 하나를 고르는 방식입니다.
- **병렬 DML 관련 오류:** EE에서 병렬 DML을 커밋하기 전에 같은 테이블을 조회하면 오류(ORA-12838)가 납니다. 또 트랜잭션이 열린 상태에서는 `alter session enable parallel dml`을 실행할 수 없습니다(ORA-12841, 이 환경에서도 발생). 실습 [7]이 먼저 커밋하는 이유입니다.

## 토론 질문
1. CASE 한 번 스캔이 항상 유리할까? 각 조건이 인덱스로 아주 적은 건만 읽는 경우라면?
2. 병렬 처리로 응답 시간은 줄었는데 전체 Buffers는 그대로라면, 시스템 전체로 보면 이득일까? OLTP 시스템에서 병렬 힌트를 남발하면 어떤 일이 생길까?
3. broadcast 분배가 hash 분배보다 유리한 조건은? 양쪽 테이블이 모두 클 때 broadcast를 고르면 어떻게 될까?
4. 힌트를 줬는데 실행계획이 바뀌지 않았다면, Hint Report 외에 무엇을 의심해야 할까? (힌트 문법, 별칭, Query Block, 에디션·파라미터 제약)

## 제출
`weeks/week11-advanced-sql-parallel/submissions/<github-id>/`
- `concepts.md`: 핵심 개념 3개(자기 말로 + 실습 수치 연결)와 필기 문제 2개 ([templates/concepts.md](../../templates/concepts.md))
- `result.md`: "병렬 실행계획 읽기" 예시 A~C의 질문 답도 포함
- `lab.txt`
- `challenge.txt`

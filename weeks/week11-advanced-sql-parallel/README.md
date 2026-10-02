# Week 11 — 고급 SQL 활용, 병렬 처리

| 책 | 『오라클 성능 고도화 원리와 해법 II』 6장 고급 SQL 활용, 7장 병렬 처리 |
|---|---|

## 학습 목표
- 같은 테이블을 여러 번 읽는 SQL을 **한 번 스캔**으로 바꾼다 (CASE 집계, WITH절 materialize, MERGE).
- 상관 서브쿼리로 풀던 그룹 내 순위·Top-N을 **윈도우 함수**로 바꾸고 비용 차이를 측정한다.
- 병렬 실행계획을 읽는다: PX COORDINATOR, PX SEND / RECEIVE, TQ, IN-OUT, PQ Distrib.
- 병렬 조인의 분배 방식(broadcast / hash)을 구분하고, 병렬 DML의 조건을 이해한다.

## 실행
```bash
bash scripts/run.sh weeks/week11-advanced-sql-parallel/01_setup.sql
bash scripts/run.sh weeks/week11-advanced-sql-parallel/02_lab.sql       weeks/week11-advanced-sql-parallel/submissions/<id>/lab.txt
bash scripts/run.sh weeks/week11-advanced-sql-parallel/03_challenge.sql weeks/week11-advanced-sql-parallel/submissions/<id>/challenge.txt
```

## 실습 (`02_lab.sql`)
| # | 내용 | 볼 것 |
|---|---|---|
| 1 | union all 3번 스캔 vs CASE 한 번 스캔 | Buffers 비율 |
| 2 | WITH절 materialize vs inline | TEMP TABLE TRANSFORMATION, BIG_TABLE 스캔 횟수 |
| 3 | UPDATE+INSERT vs MERGE | session logical reads, execute count |
| 4 | 그룹 내 Top-N: 상관 서브쿼리 vs `row_number()` | 서브쿼리 Starts, 전체 Buffers, WINDOW SORT PUSHED RANK |
| 5 | 병렬 집계 (DOP 2) | `v$pq_sesstat`, PX 오퍼레이션, TQ / IN-OUT / PQ Distrib |
| 6 | 병렬 조인 분배 | `pq_distribute(b broadcast none)` vs `pq_distribute(b hash hash)` |
| 7 | 병렬 DML | DML Parallelized, LOAD AS SELECT 위치(PX COORDINATOR 위인가 아래인가) |

### 병렬 실행계획 읽는 법
| 컬럼 / 오퍼레이션 | 의미 |
|---|---|
| PX COORDINATOR | QC(Query Coordinator). 사용자 세션이 PX 서버들의 결과를 모은다 |
| PX BLOCK ITERATOR | 테이블을 블록 범위(granule)로 나눠 PX 서버에 나눠준다 |
| PX SEND / PX RECEIVE | PX 서버 집합 사이에서 데이터를 주고받는 지점 |
| TQ | Table Queue. `:TQ10000`처럼 데이터가 지나가는 통로 번호 |
| IN-OUT | `P->P`(서버 집합 간 재분배), `P->S`(QC로 보냄), `PCWP`/`PCWC`(같은 서버 집합 안에서 이어서 처리) |
| PQ Distrib | 재분배 방식: HASH, BROADCAST, RANGE, ROUND-ROBIN, QC (RANDOM) 등 |

`xplan_px.sql`과 `pq_stat.sql`은 이번 주 전용 헬퍼입니다.
- `xplan_px.sql`: 병렬 SQL은 `ALLSTATS LAST`가 QC 몫의 통계만 보여주기 때문에, PX 서버 몫까지 합친 누적값으로 출력합니다. 대상 커서는 SQL 안의 태그 주석(`/* w11_px_a */`)으로 찾습니다.
- `pq_stat.sql`: 직전 SQL이 실제로 병렬로 실행되었는지 `v$pq_sesstat`으로 확인합니다.

## 챌린지
`03_challenge.sql`: 2023년 월별 (전체 건수, `status='N'` 건수, `grp_id` 1~10 금액 합계) 리포트입니다.
- 원본은 BIG_TABLE을 **세 번** 읽어 조인합니다.
- 결과(12행, 정렬 포함)를 그대로 유지하면서 **한 번만 읽도록** 다시 씁니다. 인덱스는 추가하지 않습니다.
- 추가 질문: 어떤 달에 `status='N'`이 0건이면 원본과 튜닝 SQL의 결과가 같을까요? 원본의 조인 방식이 결과에 어떤 영향을 주는지 설명하세요.

## 책과 다른 점 (23ai)
- **CURSOR DURATION MEMORY (12.2~):** WITH절 materialize가 실제 임시 테이블 대신 메모리 기반 임시 테이블을 쓸 수 있습니다. 실행계획의 LOAD AS SELECT 옆에 `(CURSOR DURATION MEMORY)`가 보이면 이 방식입니다.
- **Free 에디션의 병렬 처리 제약:** CPU 2스레드 제한 때문에 DOP는 최대 2 정도로 봅니다. `parallel_max_servers` 같은 파라미터가 작게 잡혀 있어서 PX 서버를 못 받으면, 실행계획은 병렬인데 실제로는 직렬로 수행(downgrade)될 수 있습니다. `pq_stat` 결과로 실제 병렬 여부를 꼭 확인하세요.
- **병렬 DML 후 같은 테이블 조회:** 병렬 DML을 커밋하기 전에 같은 테이블을 조회하면 오류(ORA-12838)가 납니다. 실습 [7]은 그래서 바로 커밋합니다.
- **`pq_distribute` 외 분배 방식:** 12c부터 Hybrid Hash 분배(`HYBRID HASH`)가 생겼습니다. 실제 행 수를 보고 실행 중에 broadcast와 hash 중 하나를 고릅니다. 힌트 없이 실행하면 PQ Distrib에 HYBRID HASH가 보일 수 있습니다.

## 토론 질문
1. CASE 한 번 스캔이 항상 유리할까? 각 조건이 인덱스로 아주 적은 건만 읽는 경우라면?
2. 병렬 처리로 응답 시간은 줄었는데 전체 Buffers는 그대로라면, 시스템 전체로 보면 이득일까? OLTP 시스템에서 병렬 힌트를 남발하면 어떤 일이 생길까?
3. broadcast 분배가 hash 분배보다 유리한 조건은? 양쪽 테이블이 모두 클 때 broadcast를 고르면 어떻게 될까?

## 제출
`weeks/week11-advanced-sql-parallel/submissions/<github-id>/`
- `result.md`
- `lab.txt`
- `challenge.txt`

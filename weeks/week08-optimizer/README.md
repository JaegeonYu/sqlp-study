# Week 08 — 옵티마이저 원리

| 책 | 『오라클 성능 고도화 원리와 해법 II』 3장 옵티마이저 원리 |
|---|---|

## 학습 목표
- 옵티마이저가 통계(NDV, density, 히스토그램)로 **카디널리티(E-Rows)** 를 어떻게 계산하는지 설명할 수 있다.
- 카디널리티가 틀리면 액세스 경로와 조인 방법이 함께 틀어진다는 것을 수치로 확인한다.
- 히스토그램, 확장 통계(컬럼 그룹), 바인드 피킹, Adaptive Cursor Sharing, 동적 샘플링이 각각 어떤 문제를 풀려고 생겼는지 안다.
- "통계를 고치면 SQL을 고치지 않아도 계획이 바뀐다"를 직접 해본다.

## 실행
```bash
bash scripts/run.sh weeks/week08-optimizer/01_setup.sql
bash scripts/run.sh weeks/week08-optimizer/02_lab.sql       weeks/week08-optimizer/submissions/<id>/lab.txt
bash scripts/run.sh weeks/week08-optimizer/03_challenge.sql weeks/week08-optimizer/submissions/<id>/challenge.txt
bash scripts/run.sh weeks/week08-optimizer/99_cleanup.sql   # BIG_TABLE 통계 원복. 다음 주차 전에 꼭 실행
```

## 실습 구성 (`02_lab.sql`)
| # | 내용 | 볼 것 |
|---|---|---|
| 1 | 컬럼 통계 | `user_tab_col_statistics`의 NUM_DISTINCT, DENSITY, HISTOGRAM |
| 2 | 히스토그램 없음 | `state='WAIT'`(500건)의 E-Rows가 50%(100K)로 추정되고, 그래서 FULL을 고름 |
| 3 | Frequency 히스토그램 | `user_histograms`의 누적 건수. E-Rows 500으로 맞아지면서 INDEX RANGE SCAN으로 바뀜 |
| 4 | BIG_TABLE.status | E-Rows는 맞아져도 계획은 그대로일 수 있음. 데이터가 흩어진 정도(클러스터링)가 결정 |
| 5 | 범위 선택도 | `between`의 추정 정확도, 최대값을 벗어난 범위 조건의 E-Rows |
| 6 | 컬럼 상관관계 | 독립 가정 때문에 E-Rows 1 vs 실제 100. 확장 통계를 수집한 뒤의 E-Rows |
| 7 | 바인드 피킹 / ACS | `v$sql`의 child cursor, `IS_BIND_SENSITIVE`, `IS_BIND_AWARE` |
| 8 | 동적 샘플링 | 통계 없는 테이블의 Note 섹션, E-Rows 정확도 |
| 9 | 실시간 통계 | 일반 DML 후 `user_tab_statistics.NOTES` |
| 10 | Adaptive Plan | `+ADAPTIVE` 포맷, Note 섹션, 버려진 후보 오퍼레이션 |
| 11 | optimizer_mode | `first_rows_1`과 `all_rows`의 계획 차이(정렬 생략 vs FULL + SORT) |

## 카디널리티 공식 (오늘 꼭 익힐 것)
| 조건 | 선택도 (히스토그램 없음) |
|---|---|
| `col = 값` | 1 / NDV |
| `col between a and b` | (b − a) / (high − low) + 경계 보정 |
| `c1 = x and c2 = y` | sel(c1) × sel(c2), 즉 **독립 가정** |
| `c1 = x or c2 = y` | sel(c1) + sel(c2) − sel(c1)×sel(c2) |

카디널리티 = 테이블 건수 × 선택도. 실행계획에서 E-Rows가 A-Rows와 10배 이상 차이 나면, 그 아래로 이어지는 모든 결정(인덱스 사용 여부, 조인 순서, 조인 방법)을 의심합니다.

## 챌린지
`03_challenge.sql`: grade·tier·lvl이 모두 3인 고객(1,000명)과 BIG_TABLE을 조인합니다.
1. `W08_CUST` 단계의 E-Rows와 A-Rows를 비교하고, 그 오차가 조인 방법 선택에 준 영향을 설명합니다.
2. **힌트 없이, SQL 텍스트는 그대로 둔 채** 통계만 보정해서 올바른 계획이 나오게 합니다. Before/After Buffers를 제출합니다.
3. Adaptive Plan은 기본으로 켜져 있는데도 이 SQL에서는 런타임 보정이 일어나지 않습니다. lab [10]의 계획(Note 섹션, STATISTICS COLLECTOR)과 비교해 이유를 설명합니다.

## 책과 다른 점 (23ai)
- **통계 수집 직후 계획이 안 바뀔 수 있습니다.** 10g 이후 `dbms_stats`의 기본값은 Rolling Invalidation(`no_invalidate => AUTO_INVALIDATE`)입니다. 기존 커서를 바로 무효화하지 않으므로, 실습에서는 `no_invalidate => false`로 즉시 반영합니다.
- **CTAS·Direct Path INSERT는 통계를 자동으로 수집합니다**(12c 이후 Online Statistics Gathering). 그래서 [8]에서는 일부러 `delete_table_stats`로 통계를 지웠습니다. 통계가 없으면 `dynamic sampling (level=2)`가 Note에 표시되고 E-Rows가 실제와 근접합니다(이 환경에서 1,099 vs 1,000).
- **최대값을 벗어난 범위 조건의 E-Rows는 0이 아닙니다.** 범위 밖으로 멀어질수록 선형으로 줄어듭니다(이 환경에서 752 vs 0). 책 시절보다 보정이 정교해졌습니다.
- **Adaptive Plan(12c~).** [10]처럼 `STATISTICS COLLECTOR`를 두고 실행 중에 NL과 Hash 중 하나를 고릅니다. 다만 모든 조인에 적용되지는 않습니다. 챌린지 SQL에서는 적용되지 않았습니다.
- **실시간 통계(Real-Time Statistics, 19c~)는 Exadata·Cloud 전용입니다.** 이 Free 환경에서는 일반 INSERT 후에도 `NUM_ROWS`가 바뀌지 않았고, `NOTES`도 비어 있었습니다.
- **확장 통계(11g~).** 책이 다루는 "결합 조건의 독립 가정" 문제를 `dbms_stats.create_extended_stats`로 풀 수 있습니다. 이 환경에서 E-Rows가 1 → 100(실제 100)으로 맞아졌습니다.

## 토론 질문
1. 히스토그램을 모든 컬럼에 만들면 안 되는 이유는? (바인드 변수, 파싱 비용, 통계 수집 시간)
2. 실무에서 "어제까지 빠르던 SQL이 오늘 갑자기 느려졌다"의 흔한 원인 세 가지를 통계 관점에서 들어 보자.
3. ACS가 있으면 바인드 변수와 히스토그램을 함께 써도 안전할까? ACS가 새 child를 만들기 전 실행들은?

## 제출
`weeks/week08-optimizer/submissions/<github-id>/`
- `result.md`
- `lab.txt`
- `challenge.txt`

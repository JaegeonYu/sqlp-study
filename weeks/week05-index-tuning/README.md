# Week 05 — 인덱스 활용 + 미니 모의 1

| 책 | 『오라클 성능 고도화 원리와 해법 II』 1장 인덱스 원리와 활용 (후반부: 테이블 랜덤 액세스, 결합 인덱스 설계, IOT) |
|---|---|

## 학습 목표
- 클러스터링 팩터(CF)가 인덱스 범위 스캔 비용을 어떻게 바꾸는지 수치로 설명한다.
- 인덱스 손익분기점이 고정된 비율이 아니라 **CF와 데이터 분포에 따라 달라진다**는 것을 측정으로 확인한다.
- 결합 인덱스 컬럼 순서를 "= 조건 먼저, 범위 조건은 뒤로" 원칙에 따라 설계하고 근거를 댄다.
- 커버링 인덱스로 테이블 액세스를 없애고, 인덱스로 ORDER BY를 생략해 부분범위처리를 만든다.

## 실행
```bash
bash scripts/run.sh weeks/week05-index-tuning/01_setup.sql
bash scripts/run.sh weeks/week05-index-tuning/02_lab.sql       weeks/week05-index-tuning/submissions/<id>/lab.txt
bash scripts/run.sh weeks/week05-index-tuning/03_challenge.sql weeks/week05-index-tuning/submissions/<id>/challenge.txt
```

## 실습 데이터
| 객체 | 설명 |
|---|---|
| `w05_cust_ix(cust_id)` | 같은 값 100건이 연속 저장 → CF ≈ 테이블 블록 수 |
| `w05_rnd_ix(rnd_id)` | 무작위 저장 → CF ≈ 테이블 행 수 |
| `w05_grp_dt_ix(grp_id, reg_dt)` / `w05_dt_grp_ix(reg_dt, grp_id)` | 같은 컬럼, 순서만 다른 결합 인덱스 |
| `w05_heap` / `w05_iot` | 같은 10만 건을 무작위 순서 힙 테이블 / IOT로 저장 |
| `w05_order` (50만 건) | 미니 모의 1 실기 문제용 주문 테이블 |

## 실습 구성 (`02_lab.sql`)
| # | 내용 | 볼 것 |
|---|---|---|
| 1 | CF 조회 | `clustering_factor` vs 테이블 blocks / num_rows |
| 2 | 같은 1,000건, 다른 CF | INDEX 단계 Buffers는 비슷, TABLE ACCESS 단계가 크게 다름 |
| 3 | 손익분기점 (`breakeven.sql`) | 0.1~20% 구간에서 rnd_ix / FULL / cust_ix의 LIO와 ms |
| 4 | 결합 인덱스 순서 | `(grp_id, reg_dt)` vs `(reg_dt, grp_id)` Range Scan의 Buffers와 access/filter. 옵티마이저가 고른 Skip Scan |
| 5 | 커버링 인덱스 | `(rnd_id, amount)` 추가 후 TABLE ACCESS 제거 |
| 6 | ORDER BY 생략 + STOPKEY | 인덱스 역순 10건 vs FULL+SORT, 정렬 컬럼 선두 인덱스 |
| 7 | IOT | 힙 + PK 인덱스 vs IOT의 Buffers |

### 손익분기점 측정 표 읽는 법 ([3])
```
pct(%) | rows(approx) | rnd_ix LIO |  rnd_ix ms |   FULL LIO |    FULL ms | cust_ix LIO | cust_ix ms
```
- **rnd_ix LIO:** 대략 "읽은 행 수"만큼 늘어납니다. 행마다 다른 블록을 읽기 때문입니다.
- **FULL LIO:** 비율과 관계없이 거의 일정합니다(테이블 전체 블록).
- **cust_ix LIO:** 대략 "읽은 행 수 / 블록당 행 수"만큼만 늘어납니다.

ms는 캐시 상태에 따라 달라집니다. 판단은 LIO 위주로 하고, ms는 참고로만 봅니다.

## 미니 모의 1
[mock.md](mock.md): 필기 5문항 + 실기 1문항(`03_challenge.sql`)
- **P1:** 특정 고객의 1년치 주문(취소 제외), 최신순
- **P2:** 대기 주문 중 오래된 순 20건

인덱스 **2개 이내**로 두 SQL을 모두 빠르게 만들고, 컬럼 순서를 정한 근거를 실기 답안 형식으로 씁니다.

## 책과 다른 점 (23ai)
- **`TABLE ACCESS BY INDEX ROWID BATCHED`(12c~).** ROWID를 모아 같은 블록끼리 묶어 읽습니다. 그래서 CF가 나쁜 인덱스도 책의 계산(행마다 블록 1개)보다 Buffers가 조금 적게 나올 수 있고, 손익분기점도 책보다 약간 뒤로 밀립니다.
- **CF 계산 선호도 `TABLE_CACHED_BLOCKS`(12c~).** `dbms_stats.set_table_prefs`로 "최근 N개 블록을 다시 방문하는 것은 CF에 세지 않기"를 설정할 수 있습니다. 기본값은 1이라 책과 같은 방식으로 계산됩니다.
- **`FETCH FIRST n ROWS ONLY`(12c~).** 책의 `ROWNUM <= n` 인라인 뷰 패턴과 같은 효과입니다. 실행계획에는 `WINDOW NOSORT STOPKEY` 또는 `COUNT STOPKEY`로 나타납니다.

## 토론 질문
1. 인덱스 rebuild로 CF가 좋아질까? CF를 좋게 만드는 방법은 무엇이고, 그 대가는?
2. "인덱스는 전체의 5~20%까지만 유리하다"는 말이 [3]의 측정 결과와 맞는가?
3. `(grp_id, reg_dt)`와 `(reg_dt, grp_id)` 중 하나만 둬야 한다면, 어떤 쿼리 패턴을 근거로 고를까?
4. IOT가 유리한 테이블과 불리한 테이블의 특징은?

## 제출
`weeks/week05-index-tuning/submissions/<github-id>/`
- `result.md` (필기 답 포함)
- `lab.txt`
- `challenge.txt`

# Week 04 — 인덱스 원리

| 책 | 『오라클 성능 고도화 원리와 해법 II』 1장 인덱스 원리와 활용 (전반부: 구조, 스캔 방식, 인덱스 사용 조건) |
|---|---|

## 학습 목표
- B*Tree 구조(루트·브랜치·리프)를 딕셔너리와 `index_stats`로 확인하고, 리프에 닿기까지 몇 블록을 읽는지 설명한다.
- 7가지 스캔 방식을 실행계획으로 구분한다: Unique / Range / Range Descending / Full / Fast Full / Skip / MIN·MAX.
- "인덱스가 있는데 왜 안 타지?"를 **Predicate Information의 access/filter**로 진단한다.
- 컬럼 가공, 묵시적 형변환, `LIKE '%x'`, 부정형, `IS NULL`, OR 조건을 고쳐 쓰는 방법을 익힌다.

## 실행
```bash
bash scripts/run.sh weeks/week04-index-basics/01_setup.sql
bash scripts/run.sh weeks/week04-index-basics/02_lab.sql       weeks/week04-index-basics/submissions/<id>/lab.txt
bash scripts/tkprof.sh week04                                 > weeks/week04-index-basics/submissions/<id>/tkprof.txt
bash scripts/run.sh weeks/week04-index-basics/03_challenge.sql weeks/week04-index-basics/submissions/<id>/challenge.txt
```

## 실습 데이터
| 객체 | 설명 |
|---|---|
| `BIG_TABLE` + `w04_reg_dt_ix(reg_dt)` | 날짜순 저장, 하루 1,000건 |
| `BIG_TABLE` + `w04_status_dt_ix(status, reg_dt)` | 선두 컬럼 값이 2개('Y' 99%, 'N' 1%) → Skip Scan |
| `w04_code` (10만 건) | `code`: `'00000001'` 형태의 VARCHAR2 / `name`: `'Name1'` 대소문자 혼합 / `closed_dt`: 1%가 NULL |

## 실습 구성 (`02_lab.sql`)
| # | 내용 | 볼 것 |
|---|---|---|
| 1 | B*Tree 구조 | BLEVEL, LEAF_BLOCKS, `index_stats`의 HEIGHT·LF_ROWS/LF_BLKS |
| 2-a | Index Unique Scan | Buffers = BLEVEL + 1 + 테이블 1 |
| 2-b | Index Range Scan | 테이블 액세스 없이 인덱스만으로 처리 |
| 2-c | Range Scan Descending | SORT 없이 역순 + STOPKEY |
| 2-d | MIN/MAX | 100만 건에서 최댓값을 몇 블록으로 찾나 |
| 2-e/f | Full vs Fast Full | Buffers는 비슷, I/O 방식(대기 이벤트)과 정렬 보장 여부가 다르다 |
| 2-g | Skip Scan | 선두 컬럼 조건 없이 결합 인덱스 사용 |
| 3 | 컬럼 가공 | `trunc(reg_dt)`, `id + 1` → access가 filter로 바뀜 |
| 4 | 묵시적 형변환 | `code = 123` → `TO_NUMBER("CODE")` |
| 5 | LIKE | `'Name777%'` vs `'%777'` |
| 6 | 부정형 | `<> 'Y'` vs `= 'N'` |
| 7 | IS NULL | 단일 컬럼 인덱스는 NULL을 담지 않음 → `(closed_dt, id)` 결합 인덱스 |
| 8 | OR 조건 | OR-Expansion(VW_ORE) vs FULL |
| 9 | 함수 기반 인덱스 | `upper(name)` 인덱스 생성 전후 |

## 실행계획 읽기: access vs filter
```
Predicate Information (identified by operation id):
   2 - access("REG_DT"=TO_DATE(...))      ← 인덱스 스캔 "범위"를 결정 (읽는 양이 줄어든다)
   1 - filter(TRUNC(INTERNAL_FUNCTION("REG_DT"))=...)  ← 읽은 뒤 "버림" (읽는 양은 그대로)
```
인덱스 튜닝의 핵심은 조건을 **access**로 만드는 것입니다. 같은 인덱스를 써도 조건이 filter로만 쓰이면 스캔 범위는 줄지 않습니다.

## 챌린지 (`03_challenge.sql`)
WHERE절 4개를 결과가 같고 인덱스를 탈 수 있는 형태로 다시 씁니다.

| | 원본 조건 | 힌트 |
|---|---|---|
| C1 | `reg_dt - 7 > date '2024-09-15'` | 가공을 상수 쪽으로 옮긴다 |
| C2 | `substr(code, 1, 6) = '000012'` | code는 항상 8자리 |
| C3 | `to_char(id) = '12345'` | 형변환 방향 |
| C4 | `nvl(closed_dt, date '9999-12-31') = date '9999-12-31'` | NULL이 인덱스에 들어가는 조건 (인덱스 추가 가능) |

문제마다 Before/After Buffers 표를 만들고, "왜 access가 됐는가"를 한 줄로 적습니다.

## 책과 다른 점 (23ai)
- **OR-Expansion이 비용 기반으로 바뀌었습니다(12.2~).** 책에는 `USE_CONCAT` 힌트와 `CONCATENATION` 오퍼레이션이 나옵니다. 23ai에서는 `VW_ORE_xxx` 뷰와 `UNION-ALL` 형태로 나타나고, 힌트는 `OR_EXPAND` / `NO_OR_EXPAND`입니다(구버전 힌트도 여전히 인식).
- **`TABLE ACCESS BY INDEX ROWID BATCHED`(12c~).** 책의 `TABLE ACCESS BY INDEX ROWID`와 같은 역할이지만, ROWID를 모아 블록 단위로 묶어서 읽습니다. 그래서 Buffers가 책보다 적게 나올 수 있습니다.
- **Fast Full Scan의 Direct Path Read.** 큰 인덱스의 Fast Full Scan도 버퍼 캐시를 거치지 않고 `direct path read`로 읽을 수 있습니다(week01 실습 [4]와 같은 원리). TKPROF에서 대기 이벤트를 확인하세요.
- **`DROP/CREATE INDEX IF [NOT] EXISTS`** 문법을 씁니다(23ai 신규).

## 토론 질문
1. BLEVEL이 3에서 4로 늘면 Unique Scan 비용은 얼마나 늘까? 인덱스 높이는 언제 늘어날까?
2. Index Full Scan과 Fast Full Scan 중, `ORDER BY`를 대신할 수 있는 것은 무엇이고 왜 그럴까?
3. Skip Scan이 Range Scan보다 나은 상황이 실제로 있을까? 선두 컬럼의 NDV 기준으로 생각해 보자.
4. 묵시적 형변환으로 인덱스를 못 쓰게 되는 사례를 실무 코드(MyBatis 파라미터 타입 등)에서 찾아보자.

## 제출
`weeks/week04-index-basics/submissions/<github-id>/`
- `concepts.md`: 핵심 개념 3개(자기 말로 + 실습 수치 연결)와 필기 문제 2개 ([templates/concepts.md](../../templates/concepts.md))
- `result.md`
- `lab.txt`
- `tkprof.txt`
- `challenge.txt`

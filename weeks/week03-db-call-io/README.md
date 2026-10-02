# Week 03 — DB Call 최소화, I/O 효율화

| 책 | 『오라클 성능 고도화 원리와 해법 I』 5장 데이터베이스 Call 최소화 원리, 6장 I/O 효율화 원리 |
|---|---|

## 학습 목표
- Call의 종류(Parse / Execute / Fetch, User Call / Recursive Call)를 구분하고, Call 횟수가 성능에 주는 영향을 수치로 확인한다.
- Array 처리(arraysize, BULK COLLECT / FORALL)와 집합 처리(INSERT ... SELECT, UPDATE 한 번)로 Call을 줄인다.
- **부분범위처리**로 필요한 만큼만 읽고 멈추는 실행계획을 만든다.
- SELECT 절 사용자 정의 함수가 왜 느린지 설명하고, 스칼라 서브쿼리 캐싱이나 조인으로 바꾼다.
- 단일 블록 읽기와 멀티 블록 읽기의 차이를 I/O 요청 횟수로 확인한다.

## 실행
```bash
bash scripts/run.sh weeks/week03-db-call-io/01_setup.sql
bash scripts/run.sh weeks/week03-db-call-io/02_lab.sql weeks/week03-db-call-io/submissions/<id>/lab.txt
bash scripts/run.sh weeks/week03-db-call-io/03_challenge.sql weeks/week03-db-call-io/submissions/<id>/challenge.txt
```

이번 주 전용 헬퍼(주차 폴더 안)
| 파일 | 용도 |
|---|---|
| `stat_begin.sql` / `stat_end.sql` | user calls, recursive calls, execute count, user commits, redo, I/O 요청 횟수 전후 비교 |
| `reset_acct.sql` | 챌린지 테이블 `W03_ACCT` 초기화 (Before/After를 같은 데이터에서 측정) |

## 실습 (`02_lab.sql`)
| # | 내용 | 볼 것 |
|---|---|---|
| 1 | arraysize 2 / 15 / 100 / 1000 | SQL*Net roundtrips ≈ 건수 / arraysize, consistent gets도 함께 감소 |
| 2 | INSERT 1만 건: 한 건씩+매번 커밋 / FORALL / INSERT…SELECT | execute count, recursive calls, user commits, redo size, Elapsed |
| 3 | 첫 10건: 인덱스 순서 vs 전체 정렬 | SORT 유무, STOPKEY 단계의 A-Rows·Buffers |
| 4 | 사용자 함수 10만 회 / 스칼라 서브쿼리 / 조인 | recursive calls, Elapsed |
| 5 | `db_file_multiblock_read_count` 1 vs 128 | physical reads(블록 수)와 physical read total IO requests(요청 횟수) |

## Call 정리
| 구분 | 의미 | 실습에서 보는 통계 |
|---|---|---|
| User Call | 클라이언트(SQL*Plus, JDBC 등)가 DB에 보낸 Call | `user calls`, `SQL*Net roundtrips` |
| Recursive Call | DB 안에서 발생한 Call (PL/SQL 안의 SQL, 함수 안의 SQL, 딕셔너리 조회) | `recursive calls` |
| Parse / Execute / Fetch | Call의 단계 | `parse count`, `execute count`, TKPROF의 Parse/Execute/Fetch 행 |

PL/SQL 루프는 DB 안에서 돌기 때문에 `user calls`가 거의 늘지 않습니다. 같은 루프를 애플리케이션(Java 등)에서 돌리면 한 건마다 네트워크 왕복이 생깁니다. 이런 이유로 실무 배치에서 "한 건씩 처리"가 가장 흔한 성능 문제입니다.

## 챌린지
`03_challenge.sql`: 등급 'B' 계좌 약 33,000건을 커서 루프로 한 건씩 UPDATE하는 배치입니다.
- 결과(검증 쿼리의 `upd_cnt`, `total_balance`)는 그대로 두고 Call 수와 시간을 줄입니다.
- 측정은 반드시 `@@reset_acct`로 테이블을 초기화한 다음에 합니다. 대화형으로는 `@weeks/week03-db-call-io/reset_acct`를 실행합니다.
- result.md에 Before/After의 `execute count`, `recursive calls`, `redo size`, Elapsed, 검증 쿼리 결과를 적습니다.

## 책과 다른 점 (23ai)
- **`fetch first N rows only`(12c~).** 책 시절에는 `rownum <= N`을 인라인 뷰 바깥에 두는 방식으로 썼습니다. 실행계획에는 `COUNT STOPKEY` 대신 `WINDOW NOSORT STOPKEY` / `WINDOW SORT PUSHED RANK`가 보일 수 있습니다. 두 방식의 계획을 직접 비교해 보세요.
- **Serial Direct Path Read(11g~).** 실습 [5]의 테이블은 버퍼 캐시를 거치도록 일부러 작게(약 1,000블록) 만들었습니다. 그래도 `physical reads direct`가 나온다면 그 결과를 기록해 주세요.
- **스칼라 서브쿼리 캐시 크기.** 캐시 크기는 버전과 파라미터에 따라 다릅니다. 입력 값의 종류(NDV)가 캐시보다 많으면 효과가 줄어듭니다. 실습 [4-b]의 recursive calls로 확인합니다.
- **PL/SQL 커서 FOR 루프의 자동 Array Fetch(10g~).** 커서 FOR 루프는 내부적으로 100건씩 fetch합니다. 그래서 실습 [2-a]의 느린 원인은 SELECT가 아니라 **INSERT·COMMIT 반복**입니다.

## 토론 질문
1. arraysize를 무한정 크게 하면 좋을까? 클라이언트 메모리와 첫 화면 응답 시간 관점에서 생각해 보자.
2. 실습 [2-a]처럼 루프 안에서 커밋하면 redo 외에 무엇이 늘어날까? (`log file sync` 대기, Snapshot too old)
3. 함수를 꼭 써야 한다면 `DETERMINISTIC`, 스칼라 서브쿼리 캐싱, `RESULT_CACHE` 중 무엇을 고르겠나? 각각의 한계는?
4. 실습 [3-a]의 부분범위처리는 정렬 컬럼에 인덱스가 없으면 불가능할까?

## 제출
`weeks/week03-db-call-io/submissions/<github-id>/`
- `result.md`
- `lab.txt`
- `challenge.txt`

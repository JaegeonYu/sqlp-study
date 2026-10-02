# Week 00 — 환경 구축과 측정 도구

## 학습 목표
- 모든 스터디원이 같은 Docker DB에서 같은 수치를 재현한다
- 이후 12주 동안 쓸 "측정 언어"를 익힌다: **Buffers, Reads, E-Rows / A-Rows, consistent gets, TKPROF**
- PR로 제출하는 흐름을 한 번 끝까지 해본다

## 사전 준비
[docs/environment.md](../../docs/environment.md)를 따라 DB를 띄우고 `bash scripts/wait-db.sh`가 OK를 출력하는지 확인합니다.

## 실행
```bash
bash scripts/run.sh weeks/week00-setup/01_setup.sql        # BIG_TABLE 생성 (최초 1~3분)
bash scripts/run.sh weeks/week00-setup/02_lab.sql       weeks/week00-setup/submissions/<id>/lab.txt
bash scripts/tkprof.sh week00                          > weeks/week00-setup/submissions/<id>/tkprof.txt
bash scripts/run.sh weeks/week00-setup/03_challenge.sql weeks/week00-setup/submissions/<id>/challenge.txt
```

## 실습 구성
| # | 내용 | 볼 것 |
|---|---|---|
| 1 | 테이블 통계 | BLOCKS, NUM_ROWS |
| 2 | FULL 스캔 | Buffers ≈ 전체 블록 수 |
| 3 | INDEX RANGE SCAN | Buffers가 몇 분의 1로 줄었나. 인덱스 단계와 테이블 단계에서 각각 몇 블록을 읽었나 |
| 4 | 세션 통계 | `session logical reads`와 Buffers의 관계, `table fetch by rowid`의 의미 |
| 5 | E-Rows vs A-Rows | 히스토그램이 없을 때 카디널리티를 어떻게 추정하나 |
| 6 | AUTOTRACE | consistent gets, roundtrips |
| 7 | SQL Trace + TKPROF | query / disk / Row Source Operation |

## 실행계획 읽는 법 (오늘 꼭 익힐 것)
- **Id 순서가 곧 실행 순서는 아닙니다.** 들여쓰기가 가장 깊은 자식부터, 같은 깊이에서는 위쪽부터 실행됩니다.
- **Buffers는 누적값입니다.** 부모 행의 Buffers에는 자식들의 Buffers가 포함되어 있습니다.
- **E-Rows는 1회 실행당, A-Rows는 전체 합계입니다.** 비교할 때는 `E-Rows × Starts`와 `A-Rows`를 놓고 봅니다.

## 책과 다른 점 (23ai)
- `drop table if exists`, `create index if not exists`: 23ai에서 새로 생긴 문법입니다. 책 시절에는 PL/SQL로 예외를 처리해야 했습니다.
- `DBMS_XPLAN.DISPLAY_CURSOR`는 책에도 나오지만, 23ai에서는 CDB/PDB 환경이라 `V$` 뷰가 PDB 단위로 보입니다.
- 이 저장소는 SYSDBA 대신 **STUDY 계정**으로 실습합니다. 필요한 권한은 `docker/init/01_create_study_user.sql`에 있습니다.

## 챌린지
`03_challenge.sql`: `to_char(reg_dt, 'YYYYMM') = '202305'`
- 인덱스가 있는데 왜 쓰이지 않는지 설명합니다.
- 결과는 그대로 두고 Buffers를 줄입니다.
- result.md에 Before/After 수치와 근거를 적습니다.

## 토론 질문
1. 인덱스로 읽었는데도 FULL보다 느려지는 경우는 언제일까? (5주차 "손익분기점"의 예고편)
2. `Buffers`와 `Reads`가 같은 실행에서 크게 다르면 무엇을 의미할까?
3. AUTOTRACE의 `consistent gets`와 TKPROF의 `query`는 같은 값일까?

## 제출
`weeks/week00-setup/submissions/<github-id>/`
- `result.md` ([templates/submission.md](../../templates/submission.md)를 복사)
- `lab.txt`, `tkprof.txt`, `challenge.txt`

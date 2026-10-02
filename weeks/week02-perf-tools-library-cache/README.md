# Week 02 — 성능 관리 도구, 라이브러리 캐시

| 책 | 『오라클 성능 고도화 원리와 해법 I』 3장 오라클 성능 관리, 4장 라이브러리 캐시 최적화 원리 |
|---|---|

## 학습 목표
- **예상 계획(EXPLAIN PLAN)**과 **실제 계획(DISPLAY_CURSOR)**이 다를 수 있음을 직접 확인하고, 튜닝할 때 무엇을 근거로 삼아야 하는지 말할 수 있다.
- AUTOTRACE, V$SQL, SQL 트레이스(TKPROF)가 각각 무엇을 보여주는지 구분한다.
- 하드 파싱 / 소프트 파싱 / 세션 커서 캐시 히트의 비용 차이를 수치로 비교한다.
- 바인드 변수가 왜 필요한지, `cursor_sharing=force`가 왜 근본 해결이 아닌지 설명할 수 있다.

## 실행
```bash
bash scripts/run.sh weeks/week02-perf-tools-library-cache/01_setup.sql
bash scripts/run.sh weeks/week02-perf-tools-library-cache/02_lab.sql weeks/week02-perf-tools-library-cache/submissions/<id>/lab.txt
bash scripts/tkprof.sh week02 > weeks/week02-perf-tools-library-cache/submissions/<id>/tkprof.txt
bash scripts/run.sh weeks/week02-perf-tools-library-cache/03_challenge.sql weeks/week02-perf-tools-library-cache/submissions/<id>/challenge.txt
```

이번 주 전용 헬퍼(주차 폴더 안)
| 파일 | 용도 |
|---|---|
| `helper_sqlstat.sql <태그>` | V$SQL에서 `/* 태그 */`가 붙은 SQL의 커서 수, 실행·파싱 횟수, buffer_gets |
| `parse_begin.sql` / `parse_end.sql` | 파싱 관련 세션 통계만 골라서 전후 비교 (`session cursor cache hits` 포함) |

## 실습 (`02_lab.sql`)
| # | 내용 | 볼 것 |
|---|---|---|
| 1 | 문자형 컬럼 = 숫자 바인드 | EXPLAIN PLAN은 INDEX RANGE SCAN, 실제는 `TO_NUMBER(CUST_CODE)` 필터와 FULL 스캔 |
| 2 | AUTOTRACE 두 옵션 | traceonly explain이 보여주는 계획은 예상과 실제 중 어느 쪽인가, statistics의 consistent gets |
| 3 | V$SQL | executions·parse_calls, 옵티마이저 환경이 바뀌면 생기는 자식 커서 |
| 4 | 리터럴 2,000회 vs 바인드 2,000회 | parse count (hard), parse time, Elapsed, 공유 풀에 남은 커서 수 (CI 기준: hard 2,023 vs 2, 1.23초 vs 0.03초) |
| 5 | `cursor_sharing=force` | `:"SYS_B_0"`로 바뀐 SQL 텍스트, hard parse 감소 |
| 6 | `session_cached_cursors` 0 vs 50 | parse count (total)는 같고 `session cursor cache hits`만 달라진다 |
| 7 | SQL 트레이스 | TKPROF의 `Misses in library cache during parse` |

실습 [3]~[7]은 단계마다 `alter system flush shared_pool`로 공유 풀을 비우고 시작합니다. 그래서 여러 번 실행해도 결과가 같습니다. **운영 DB에서는 절대 하면 안 되는 명령**이고, 로컬 실습 DB라서 쓰는 것입니다.

## 실행계획 도구 정리
| 도구 | SQL 실행 | 보여주는 것 | 주의 |
|---|---|---|---|
| `EXPLAIN PLAN` + `DBMS_XPLAN.DISPLAY` | 하지 않음 | 예상 계획 | 바인드 타입·값을 모름(문자형으로 가정, 피킹 없음) |
| AUTOTRACE `traceonly explain` | SELECT는 하지 않음 | 예상 계획 | 내부적으로 EXPLAIN PLAN과 같은 한계 |
| AUTOTRACE `traceonly statistics` | 함 | 실행 통계(consistent gets 등) | 계획은 보여주지 않음 |
| `DBMS_XPLAN.DISPLAY_CURSOR` | 이미 실행된 커서 | **실제 계획 + 단계별 실행 통계** | `statistics_level=all` 또는 `gather_plan_statistics` 필요 |
| SQL 트레이스 + TKPROF | 함 | Parse/Execute/Fetch별 횟수·시간·블록, 대기 이벤트, Row Source | 트레이스 파일 접근 필요 |

## AWR / ASH (개념만)
- **AWR**(Automatic Workload Repository): 시스템 통계와 Top SQL을 주기적으로 스냅샷으로 남깁니다. 두 스냅샷 사이 구간을 리포트로 비교합니다(`awrrpt.sql`). 책의 Statspack을 이어받은 기능입니다.
- **ASH**(Active Session History): 1초마다 활성 세션의 상태(대기 이벤트, SQL ID 등)를 샘플링합니다. "그 시간에 누가 무엇을 기다렸나"를 볼 수 있습니다.
- 두 기능 모두 **Diagnostics Pack 라이선스**가 필요한 기능입니다. 이 스터디에서는 실습하지 않고 개념만 다룹니다. 시험에는 Statspack/AWR의 용도와 Response Time 분석(서비스 시간 + 대기 시간) 관점이 나옵니다.

## 챌린지
`03_challenge.sql`: 100건 구간 합계를 리터럴 동적 SQL로 3,000번 조회하는 PL/SQL 배치입니다.
- **동적 SQL 구조는 유지한 채** 바인드 변수 방식으로 고칩니다.
- `:total` 결과가 같은지 확인합니다.
- result.md에 Before/After의 `parse count (hard)`, `parse time elapsed`, Elapsed, V$SQL 커서 수를 표로 적습니다.

## 책과 다른 점 (23ai)
- **공유 풀은 CDB 전체가 공유합니다.** PDB에서 `alter system flush shared_pool`을 실행하면 그 PDB의 커서만 비워집니다.
- **AUTOTRACE `traceonly explain`은 23ai에서도 예상 계획입니다.** CI 결과에서 [2-a]는 [1-a]와 같은 INDEX RANGE SCAN이었습니다. 반면 [2-b]의 consistent gets(361)는 실제 FULL 스캔의 Buffers와 같았습니다. 한 화면 안에서 계획과 통계가 서로 다른 이야기를 하는 셈입니다.
- **Adaptive Cursor Sharing(11g~).** 책 시절에는 바인드 피킹 때문에 "첫 실행 값으로 굳어진 계획"이 큰 문제였습니다. 11g 이후에는 실행 통계를 보고 자식 커서를 새로 만들 수 있습니다. 자세한 내용은 8주차(옵티마이저)에서 다룹니다.
- **Free의 공유 풀은 작습니다.** CI 기준으로 리터럴 SQL 2,000개를 실행한 직후 V$SQL에 남은 커서는 약 1,000개였습니다. 나머지는 LRU로 이미 밀려났습니다. 리터럴 SQL이 다른 SQL의 커서까지 밀어내 하드 파싱을 연쇄로 일으키는 과정을 축소판으로 볼 수 있습니다.
- **PL/SQL의 동적 SQL 커서 재사용.** `execute immediate`로 같은 텍스트를 바인드만 바꿔 반복하면 PL/SQL이 커서를 열어 둔 채 재사용합니다. 그래서 [4-b]는 parse count (total)이 2,000이 아니라 한 자릿수로 나옵니다. 파싱 자체를 줄이는 것이 가장 좋다는 결론으로 이어집니다. 실습 [6]은 이 재사용을 피하려고 DBMS_SQL로 매번 open/close합니다.
- **`session_cached_cursors` 기본값은 50입니다.** 실습 [6]은 원래 값을 기억해 두었다가 끝나면 되돌립니다.

## 토론 질문
1. 운영 중인 SQL의 실행계획을 확인해 달라는 요청을 받았다. EXPLAIN PLAN으로 확인해도 될까? 무엇으로 확인해야 하나?
2. 애플리케이션이 바인드 변수를 쓰지 않아 하드 파싱이 많다. 코드 수정 없이 할 수 있는 조치와 그 부작용은?
3. 실습 [4]에서 리터럴 방식의 Elapsed 중 파싱에 쓴 비율은 얼마였나? 동시 사용자가 100명이라면 어떤 경합(래치/뮤텍스)이 생길까?

## 제출
`weeks/week02-perf-tools-library-cache/submissions/<github-id>/`
- `concepts.md`: 핵심 개념 3개(자기 말로 + 실습 수치 연결)와 필기 문제 2개 ([templates/concepts.md](../../templates/concepts.md))
- `result.md`
- `lab.txt`
- `tkprof.txt`
- `challenge.txt`

# Week 01 — 아키텍처, 트랜잭션과 Lock

| 책 | 『오라클 성능 고도화 원리와 해법 I』 1장 오라클 아키텍처, 2장 트랜잭션과 Lock |
|---|---|

## 학습 목표
- 오라클은 행이 아니라 **블록** 단위로 읽는다. 이것을 수치로 확인한다.
- 버퍼 캐시 히트율보다 **논리 I/O 자체**를 줄여야 하는 이유를 설명할 수 있다.
- Redo와 Undo가 언제 얼마나 생기는지 측정한다.
- 읽기 일관성, 행 Lock(TX), 테이블 Lock(TM), 데드락을 세션 여러 개로 직접 재현한다.

## 실행
```bash
bash scripts/run.sh weeks/week01-architecture-lock/01_setup.sql
bash scripts/run.sh weeks/week01-architecture-lock/02_lab.sql weeks/week01-architecture-lock/submissions/<id>/lab.txt
# 멀티 세션 실습 (아래)
bash scripts/run.sh weeks/week01-architecture-lock/03_challenge.sql weeks/week01-architecture-lock/submissions/<id>/challenge.txt
```

## 단일 세션 실습 (`02_lab.sql`)
| # | 내용 | 볼 것 |
|---|---|---|
| 1 | 같은 100건이 흩어진 블록 수 | `cust_id`(연속 저장)와 `rnd_id`(무작위)의 block_cnt |
| 2 | 인덱스 액세스 Buffers | 테이블 액세스 단계 Buffers ≈ 흩어진 블록 수 |
| 3 | 버퍼 캐시 | 재실행하면 physical reads는 0이 되지만 logical reads는 그대로 |
| 4 | 대용량 FULL 스캔 | 2회차에도 `physical reads direct`가 나오는지 |
| 5 | UPDATE 1,000건 | redo size, undo change vector size |
| 6 | conventional vs append INSERT | Redo·Undo가 몇 배 차이 나는지 |

## 멀티 세션 실습
터미널 3개를 열고 각각 `bash scripts/sql.sh`로 접속합니다(PowerShell은 `.\scripts\sql.ps1`). 접속하면 세 터미널 모두에서 먼저 아래를 실행합니다.
```sql
@common/session_init
```
**C**는 관찰용입니다. 각 단계마다 `@common/locks`를 실행합니다.

### M1. 읽기 일관성
| 순서 | 세션 A | 세션 B |
|---|---|---|
| 1 | | `update w01_acct set balance = 0 where acct_no = 1;` (커밋하지 않음) |
| 2 | `@common/mystat_begin` | |
| 3 | `select balance from w01_acct where acct_no = 1;` | |
| 4 | `@common/mystat_end` | |
| 5 | | `commit;` |
| 6 | 3번 SELECT를 다시 실행 | |

- A는 3번에서 어떤 값을 보는가? 3번에서 `data blocks consistent reads - undo records applied`가 0보다 큰가?
- A가 B를 기다렸는가? (오라클에서 읽기는 쓰기를 기다리지 않는다)

### M2. 행 Lock(TX) 대기
| 순서 | 세션 A | 세션 B | 세션 C |
|---|---|---|---|
| 1 | | `update w01_acct set balance = balance + 10 where acct_no = 2;` | |
| 2 | `update w01_acct set balance = balance + 20 where acct_no = 2;` → **대기** | | |
| 3 | | | `@common/locks` |
| 4 | | `rollback;` | |

- C의 출력에서 A의 `blocker`, `event`(enq: TX - row lock contention), A가 요청 중인 TX Lock의 `request=6`을 확인합니다.
- 4번 이후 A는 어떻게 되는가? A도 `rollback;`으로 정리합니다.

### M3. 데드락
| 순서 | 세션 A | 세션 B |
|---|---|---|
| 1 | `update w01_acct set balance = 1 where acct_no = 3;` | |
| 2 | | `update w01_acct set balance = 1 where acct_no = 4;` |
| 3 | `update w01_acct set balance = 1 where acct_no = 4;` → 대기 | |
| 4 | | `update w01_acct set balance = 1 where acct_no = 3;` |

- 약 3초 뒤 한쪽 세션에 데드락 오류(ORA-00060)가 납니다. 이때 롤백되는 범위는 **문장**인가, **트랜잭션**인가?
- 나머지 세션은 여전히 대기 중인가? 양쪽 모두 `rollback;`으로 정리합니다.

### M4. FK 인덱스가 없을 때의 TM Lock
| 순서 | 세션 A | 세션 B | 세션 C |
|---|---|---|---|
| 1 | | `update w01_child set qty = qty + 1 where child_id = 1;` | |
| 2 | `delete from w01_parent where parent_id = 10;` → **대기?** | | |
| 3 | | | `@common/locks` |
| 4 | | `rollback;` | |
| 5 | `rollback;` | | |

자식이 하나도 없는 10번 부모를 지우는데 왜 기다릴까요? C의 출력에서 `W01_CHILD`의 TM Lock을 봅니다. B가 가진 `lmode`와 A가 요청한 `request`가 무엇인지 확인하세요.

## 챌린지
- **C1.** M4를 재현합니다. 원인을 Lock 모드로 설명하고, 해결책을 적용한 뒤 다시 실험해 대기가 사라지는 것을 확인합니다. `locks.sql` 출력(전/후)을 첨부합니다.
- **C2.** 현재 스키마에서 **인덱스가 없는 FK 컬럼**을 찾는 SQL을 직접 작성합니다(`user_constraints`, `user_cons_columns`, `user_ind_columns`). 결합 FK도 고려합니다.
- **C3.** `03_challenge.sql`은 **실행 전에** 각 SQL의 Buffers를 예측해 적은 뒤 실행합니다. 예측과 실제가 다르면 그 이유를 씁니다.

## 책과 다른 점 (23ai)
- **CDB/PDB 구조.** 책은 non-CDB 기준입니다. 버퍼 캐시와 Redo는 CDB 단위로 공유되고, STUDY는 PDB(FREEPDB1) 안에 있습니다.
- **Serial Direct Path Read(11g~).** 큰 테이블을 FULL 스캔하면 버퍼 캐시를 거치지 않고 PGA로 직접 읽을 수 있습니다. 실습 [4]의 결과를 책에 나오는 "Full Scan 블록은 LRU 끝에 둔다" 설명과 비교해 보세요.
- **NOARCHIVELOG.** Free 이미지 기본값입니다. 실습 [6]의 append Redo 감소 폭은 운영(ARCHIVELOG) 환경보다 크게 나옵니다.
- **23ai 동시성 신기능.** Lock-Free Reservation(`RESERVABLE` 컬럼)과 Priority Transactions가 생겼습니다. 시험 범위는 아니고 토론거리로 다룹니다.

## 토론 질문
1. 버퍼 캐시 히트율 99%인 SQL은 튜닝이 필요 없을까?
2. 읽기 일관성 때문에 오래 걸리는 쿼리에서 ORA-01555가 나는 이유를 Undo로 설명해 보자.
3. 오라클은 왜 Lock 에스컬레이션을 하지 않을까? 행 Lock 정보는 어디에 저장될까?

## 제출
`weeks/week01-architecture-lock/submissions/<github-id>/`
- `result.md`
- `lab.txt`
- `challenge.txt`
- `locks_before.txt` / `locks_after.txt` (C1)

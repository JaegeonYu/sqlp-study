# Week 10 — 소트 튜닝

| 책 | 『오라클 성능 고도화 원리와 해법 II』 5장 소트 튜닝 |
|---|---|

## 학습 목표
- 실행계획에서 **소트가 일어나는 오퍼레이션**을 구분하고, OMem / 1Mem / Used-Mem / Used-Tmp를 읽을 수 있다.
- 소트 공간이 부족할 때 디스크 소트(One-pass / Multi-pass)로 넘어가는 것을 수치로 확인한다.
- **인덱스로 소트를 생략**하고, Top-N 쿼리가 STOPKEY로 일찍 멈추게 만든다.
- 뒤쪽 페이지일수록 느려지는 페이징의 원리를 이해하고 키 기반 페이징으로 개선한다.
- `union` → `union all`, `distinct` → `exists`로 불필요한 소트를 없앤다.

## 실행
```bash
bash scripts/run.sh weeks/week10-sort/01_setup.sql
bash scripts/run.sh weeks/week10-sort/02_lab.sql       weeks/week10-sort/submissions/<id>/lab.txt
bash scripts/run.sh weeks/week10-sort/03_challenge.sql weeks/week10-sort/submissions/<id>/challenge.txt
```

## 실습 (`02_lab.sql`)
| # | 내용 | 볼 것 |
|---|---|---|
| 1 | 소트 오퍼레이션 종류 | SORT AGGREGATE(정렬 없음), SORT ORDER BY, HASH/SORT GROUP BY, HASH/SORT UNIQUE, SORT JOIN, WINDOW SORT의 Used-Mem |
| 2 | 메모리 vs 디스크 소트 | `sort_area_size` 64KB로 줄였을 때 Used-Tmp, `sorts (disk)`, `physical reads direct`, A-Time |
| 3 | 인덱스로 소트 생략 | SORT ORDER BY가 사라지는지, MIN/MAX와 Top-N(COUNT STOPKEY)의 Buffers |
| 4 | Top-N 소트 | `fetch first`, `rownum`, 최적화를 막은 `rn + 0`이 같은 10건을 구할 때 Used-Mem 차이 |
| 5 | 페이징 | 1페이지 vs 400페이지 vs 키 기반 페이징에서 테이블 액세스 단계의 A-Rows와 Buffers |
| 6 | 불필요한 소트 제거 | union vs union all, distinct 조인 vs exists |

### 소트 관련 컬럼 읽는 법
| 컬럼 | 의미 |
|---|---|
| OMem | 디스크를 쓰지 않고 메모리에서 끝내기(Optimal) 위해 필요한 추정 메모리 |
| 1Mem | 디스크를 한 번만 거쳐(One-pass) 끝내기 위해 필요한 추정 메모리 |
| Used-Mem | 실제 사용 메모리. 괄호 안 숫자는 pass 횟수: (0)=Optimal, (1)=One-pass, (2 이상)=Multi-pass |
| Used-Tmp | 디스크(TEMP)를 쓴 양. 이 값이 있으면 디스크 소트 |

## 챌린지
`03_challenge.sql`: 게시판 목록 10페이지를 조회하는 SQL입니다.
- 원본은 `board_id`·`reg_dt` 인덱스가 없어서 전체를 읽고, 게시판 하나의 1만 건을 **전부 정렬한 뒤** 181~200번째를 잘라냅니다.
- **인덱스 설계(DDL)와 SQL 재작성**으로 Buffers와 소트 메모리를 줄입니다. 결과 20건과 순서는 같아야 합니다.
- 추가 질문: 같은 방식으로 1000페이지를 조회하면 무슨 일이 생길까요? 화면 요구사항을 어떻게 바꾸면 해결될까요?

## 책과 다른 점 (23ai)
- **HASH GROUP BY / HASH UNIQUE (10gR2~):** `group by`와 `distinct`는 기본적으로 해시 방식으로 처리되어 결과가 정렬되지 않습니다. 정렬된 결과가 필요하면 반드시 `order by`를 써야 합니다. 그룹핑 결과가 저절로 정렬된다는 말은 옛날 이야기입니다.
- **`fetch first N rows only` (12c~):** 12c에서는 내부적으로 `row_number()`로 바뀌어 WINDOW SORT PUSHED RANK로 처리되었습니다. 이 환경(23ai)에서 실습 [4-a]를 실행하면 `rownum` 방식과 똑같이 **SORT ORDER BY STOPKEY**(Used-Mem 2KB)로 처리됩니다. 반면 `row_number()`에 `rn + 0`처럼 Top-N 최적화를 막으면 100만 건을 모두 정렬해 Used-Mem이 약 25MB까지 커집니다.
- **자동 PGA 관리:** 실습 [2-b]처럼 `workarea_size_policy=manual`로 바꿔야 책에 나오는 `sort_area_size` 기반 동작을 볼 수 있습니다. Free 에디션은 PGA 크기 자체가 제한되어 있어서, [2-a]의 자동 관리 결과도 운영 DB와 다를 수 있습니다.
- **TABLE ACCESS BY INDEX ROWID BATCHED:** 12c부터 테이블 랜덤 액세스를 모아서 처리하는 BATCHED 방식이 생겼습니다. 이 방식에서는 인덱스 순서와 결과 순서가 어긋날 수 있어서, 옵티마이저가 소트를 생략하지 않기도 합니다. 실습 [5]는 `no_batch_table_access_by_rowid` 힌트로 책과 같은 방식(일반 ROWID 액세스)을 씁니다. 소트 생략을 기대했는데 SORT가 보이면 BATCHED 여부를 확인하세요.
- **Serial Direct Path Read:** 이 환경에서는 BIG_TABLE FULL 스캔이 매번 `Reads ≈ Buffers`(약 18,865블록)로 나옵니다. 버퍼 캐시를 거치지 않고 직접 읽기 때문입니다(week01 [4] 참고).

## 토론 질문
1. `order by`가 있는 SQL에서 인덱스로 소트를 생략하려면 인덱스 컬럼 순서와 WHERE 조건이 어떤 관계여야 할까? (`=` 조건 컬럼 + 정렬 컬럼)
2. 부분범위처리가 가능하려면 클라이언트(애플리케이션)는 어떻게 fetch해야 할까? 전체 건수를 먼저 세는 페이징 화면은 왜 느릴까?
3. Sort Merge Join은 언제 Hash Join보다 유리할까? (조인 조건이 `=`가 아닐 때, 이미 정렬된 입력)

## 제출
`weeks/week10-sort/submissions/<github-id>/`
- `result.md`
- `lab.txt`
- `challenge.txt`

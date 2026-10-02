# Week 06 — 조인 I: NL / Sort Merge / Hash

| 책 | 『오라클 성능 고도화 원리와 해법 II』 2장 조인 원리와 활용 (전반부: NL 조인, 소트 머지 조인, 해시 조인, 조인 순서) |
|---|---|

## 학습 목표
- 같은 조인을 세 가지 방식으로 강제 실행하고 **Buffers, A-Time, 메모리**로 비교한다.
- "소량이면 NL, 대량이면 Hash"를 외우는 대신, **언제 역전되는지 수치로** 확인한다.
- NL 조인 비용은 **드라이빙 건수 × Inner 액세스 비용**이다. Inner 인덱스와 드라이빙 순서가 왜 결정적인지 설명할 수 있다.
- Hash 조인의 Build 입력은 작은 쪽이어야 한다. 그 이유를 메모리 수치로 설명할 수 있다.

## 데이터
| 테이블 | 건수 | 설명 |
|---|---|---|
| `W06_CUST` | 10,000 | 고객. `region_cd` R01~R10 각 1,000명, `grade` VIP 1% / GOLD 9% / NORMAL 90% |
| `W06_REGION` | 10 | 지역 코드 (챌린지용) |
| `BIG_TABLE` | 1,000,000 | 주문으로 사용. **`rnd_id`를 고객번호로 쓴다.** 무작위 저장이라 한 고객의 주문 약 100건이 여러 블록에 흩어져 있다 |

인덱스: `W06_CUST_PK(cust_id)`, `W06_BIG_RND_IX(BIG_TABLE.rnd_id)`

## 실행
```bash
bash scripts/run.sh weeks/week06-join-basics/01_setup.sql
bash scripts/run.sh weeks/week06-join-basics/02_lab.sql       weeks/week06-join-basics/submissions/<id>/lab.txt
bash scripts/run.sh weeks/week06-join-basics/03_challenge.sql weeks/week06-join-basics/submissions/<id>/challenge.txt
```

## 실습 (`02_lab.sql`)
소량 조건은 VIP + R03 지역입니다(고객 10명, 주문 약 1,000건). 대량 조건은 R03 지역 전체입니다(고객 1,000명, 주문 약 100,000건).

| # | 내용 | 볼 것 |
|---|---|---|
| 1 | 두 상황의 건수 | 조인 대상이 100배 차이 |
| 2 | 소량 NL | 인덱스 `Starts`, 테이블 액세스 Buffers |
| 3 | 소량 Hash | BIG_TABLE 전체 스캔 Buffers ([2]와 비교) |
| 4 | 소량 Sort Merge | `SORT JOIN`의 OMem / Used-Mem |
| 5 | 대량 NL | 랜덤 액세스 Buffers가 전체 블록 수(약 19,000)를 넘는지 |
| 6 | 대량 Hash | 건수가 100배로 늘어도 Buffers가 거의 그대로인 이유 |
| 7 | 대량 Sort Merge | [6]과 A-Time·메모리 비교 |
| 8 | Inner 인덱스 없는 NL | `TABLE ACCESS FULL`의 Starts = 드라이빙 건수 |
| 9 | NL 드라이빙 순서 역전 | 고객 PK 인덱스 Starts 100만 번, 필터 위치 |
| 10 | Hash Build/Probe 교체 | 첫 번째 자식 = Build 입력, OMem 차이, Used-Tmp 발생 여부 |

### 실행계획 읽기 포인트
- **NL 조인:** 위쪽 자식이 Outer(드라이빙), 아래쪽 자식이 Inner입니다. Inner 단계의 `Starts`가 Outer 건수와 같은지 봅니다.
- **Hash 조인:** 첫 번째 자식이 Build(해시 테이블로 메모리에 올림), 두 번째가 Probe입니다. `OMem`은 최적 메모리 추정치, `Used-Mem`은 실제 사용량입니다.
- **Sort Merge 조인:** 양쪽 모두에 `SORT JOIN`이 붙습니다. 단, 인덱스로 이미 정렬된 쪽은 소트가 생략될 수 있습니다.

## 챌린지 (`03_challenge.sql`)
BUSAN 지역 VIP 고객의 2023년 1분기 고객별 주문 집계입니다. 원본은 `leading(b c r)`로 **BIG_TABLE에서 출발하도록** 고정되어 있습니다.
- 결과는 같게 유지하고 Buffers를 최소화합니다. BIG_TABLE에 `W06_`로 시작하는 인덱스를 추가해도 됩니다.
- 제출할 것:
  - 최종 실행계획
  - 조인 순서와 조인 방식을 정한 근거
  - 인덱스를 추가했다면 컬럼 순서를 정한 근거
  - Buffers Before/After 표
- 생각해 볼 것: `w06_region`과 `w06_cust` 중 어느 쪽이 먼저인가? BIG_TABLE 액세스에서 `rnd_id`만으로 찾고 `reg_dt`는 테이블에서 거르면, 버리는 행이 몇 건인가?

## 책과 다른 점 (23ai)
- **NL 조인 Batching(11g~).** 책의 NL 실행계획은 `NESTED LOOPS` 아래에 Outer와 `TABLE ACCESS BY INDEX ROWID`(Inner)가 붙는 단순한 모양입니다. 23ai에서는 **`NESTED LOOPS`가 두 번** 나오고 `TABLE ACCESS BY INDEX ROWID BATCHED`가 바깥쪽에 붙습니다.
  - 안쪽 NL이 Outer와 Inner 인덱스를 먼저 조인해 ROWID를 모읍니다.
  - 바깥쪽 NL이 모은 ROWID로 테이블 블록을 몰아서 읽습니다.
  - 그래서 같은 블록을 연속으로 방문하면 Buffers가 책의 계산보다 적게 나올 수 있습니다.
  - 책에 나오는 "테이블 Prefetch"가 기본 동작이 된 것으로 보면 됩니다.
- **Adaptive Plan(12c~).** 힌트 없이 실행하면 옵티마이저가 실행 중에 NL과 Hash를 바꿀 수 있습니다(`Note: this is an adaptive plan`). 이번 주 실습은 모두 힌트로 방식을 고정했습니다.
- **PGA 자동 관리.** 메모리는 `pga_aggregate_target` 범위 안에서 자동으로 배분됩니다. Free 에디션은 메모리가 2GB로 제한되어 있어서, 큰 Build 입력은 `Used-Tmp`(디스크 사용)가 나올 수 있습니다.

## 토론 질문
1. [5]에서 NL이 Hash보다 불리해진 원인은 "조인 건수"인가, "테이블 랜덤 액세스"인가? BIG_TABLE이 `cust_id`처럼 고객 순으로 저장되어 있었다면 결과가 어떻게 달라질까?
2. Hash 조인은 왜 등치(=) 조인에서만 쓸 수 있을까? 범위 조건 조인에서는 무엇을 써야 할까?
3. OLTP 화면 조회와 야간 배치에서 선호하는 조인 방식이 다른 이유는? (부분범위처리 관점)
4. [9]처럼 드라이빙 순서가 잘못된 계획은 실무에서 어떤 상황에 만들어질까? (통계, 카디널리티 추정 오류)

## 제출
`weeks/week06-join-basics/submissions/<github-id>/`
- `result.md`
- `lab.txt`
- `challenge.txt`

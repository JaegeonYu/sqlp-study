# week00 제출 — JaegeonYu

> 실행 결과 원본: `lab.txt`(02_lab), `tkprof.txt`(02_lab [7]), `challenge.txt`(03_challenge Before)

## 1. 실습 관찰 기록

| 실습 | 관찰한 수치 (Buffers / Reads / 통계값) | 한 줄 해석 |
|---|---|---|
| [1] | NUM_ROWS 1,000,000 / BLOCKS 19,044 / AVG_ROW_LEN 131 | 데이터 블록 18,865개 기준으로 블록당 약 53행이 들어 있다 |
| [2] | FULL: Buffers 18,868 / Reads 18,866 / A-Rows 7,000 | 7,000건(0.7%)을 구하려고 HWM 아래의 데이터 블록을 전부 읽었다. BLOCKS(19,044)보다 적은 이유는 1-1 참고 |
| [3] | INDEX: Buffers 154 (인덱스 21 + 테이블 133) / Reads 156 | FULL보다 약 1/122. reg_dt 순으로 저장되어 있어서 7,000건의 rowid 액세스가 133블록 안에서 끝났다 |
| [4-a] | session logical reads 18,916 / physical reads direct 18,865 / table scan rows gotten 1,000,051 | [2]의 Buffers와 거의 같다(차이 약 48은 스냅샷 SQL의 오차). FULL 스캔은 100만 행을 모두 검사했고, 버퍼 캐시를 거치지 않는 direct path read로 읽었다 |
| [4-b] | session logical reads 159 / table fetch by rowid 7,000 / table scan rows gotten 34 | [3]의 Buffers 154와 거의 같다. 인덱스에서 얻은 rowid로 테이블을 7,000번 찾아갔다 |
| [5] | E-Rows 500K / A-Rows 10,000 / Buffers 18,868 | status는 값이 2개이고 히스토그램이 없어서 옵티마이저가 균등 분포로 가정했다: 1,000,000 / NDV 2 = 500,000. 실제는 1%로, 50배 과대 추정이다 |
| [6] | consistent gets 18,897 / SQL*Net roundtrips 8 / rows processed 100 | cust_id에 인덱스가 없어서 100건을 구하려고 FULL 스캔을 했다. roundtrips 8은 arraysize 기본값(15) 기준으로 100행을 약 7번 fetch한 결과이다 |
| [7] | TKPROF FULL: query 18,868 / disk 18,865 / `direct path read` 156회<br>TKPROF INDEX: query 154 / disk 0 | TKPROF의 query = DISPLAY_CURSOR의 Buffers = AUTOTRACE의 consistent gets이다. INDEX는 앞 단계에서 읽은 블록이 캐시에 있어 disk 0이 됐지만, FULL은 매번 direct path read로 디스크에서 다시 읽었다 |

### 1-1. 전체 블록 수(19,044)와 FULL 스캔 Buffers(18,868)가 다른 이유

`dbms_space.unused_space`, `dbms_space.space_usage`, rowid로 블록 수를 세어 확인했다.

```
세그먼트 전체 할당          19,456 블록   (user_segments.BLOCKS, extent 90개)
 ├─ HWM 위 (아직 안 쓴 공간)    412 블록   → FULL 스캔도 읽지 않음
 └─ HWM 아래                19,044 블록   ← user_tables.BLOCKS
     ├─ 데이터 블록          18,865 블록   (space_usage의 full = 18,865, rowid로 센 값과 일치)
     └─ 공간관리용 메타 블록     179 블록   (세그먼트 헤더, ASSM 비트맵 블록)
```

- `user_tables.BLOCKS`는 **HWM 아래의 블록 수**이다. 데이터 블록뿐 아니라 ASSM이 빈 공간을 관리하는 비트맵 블록(L1/L2/L3 BMB)과 세그먼트 헤더도 포함한다.
- FULL 스캔은 **데이터 블록만** 읽는다. Reads 18,866과 `physical reads direct` 18,865가 데이터 블록 수와 일치한다.
- Buffers 18,868 - 18,865 = 3블록은 스캔을 시작할 때 extent 위치 등을 확인하려고 읽은 세그먼트 헤더 같은 메타 블록으로 보인다(정확한 내역은 미확인).
- 결론: **FULL 스캔 비용은 HWM 아래 데이터 블록 수에 비례한다.** DELETE로 행을 지워도 HWM은 내려가지 않으므로 FULL 스캔 비용은 그대로 남는다.

### 1-2. 실행계획(DISPLAY_CURSOR ALLSTATS LAST) 읽는 법

[3]의 결과를 예로 정리한다.

```
SQL_ID  2g82r7zqwnn5r, child number 0
Plan hash value: 2239651889
-------------------------------------------------------------------------------------------------------------------------
| Id  | Operation                            | Name          | Starts | E-Rows | A-Rows |   A-Time   | Buffers | Reads  |
-------------------------------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT                     |               |      1 |        |      1 |00:00:00.01 |     154 |    156 |
|   1 |  SORT AGGREGATE                      |               |      1 |      1 |      1 |00:00:00.01 |     154 |    156 |
|   2 |   TABLE ACCESS BY INDEX ROWID BATCHED| BIG_TABLE     |      1 |   8006 |   7000 |00:00:00.01 |     154 |    156 |
|*  3 |    INDEX RANGE SCAN                  | W00_REG_DT_IX |      1 |   8006 |   7000 |00:00:00.01 |      21 |     23 |
```

**맨 위 정보**

| 항목 | 의미 |
|---|---|
| SQL_ID | SQL 텍스트로 만든 고유 ID. 공백이나 대소문자가 하나만 달라도 다른 SQL_ID가 된다 |
| child number | 같은 SQL 텍스트라도 환경(바인드 타입, 옵티마이저 설정 등)이 다르면 자식 커서가 따로 생긴다 |
| Plan hash value | 실행계획 모양으로 만든 값. SQL이 달라도 계획이 같으면 같은 값이 나온다. [2], [5], 챌린지 Before가 모두 599409829이다 |

**표의 컬럼**

| 컬럼 | 의미 | 읽는 법 |
|---|---|---|
| Id | 오퍼레이션 번호 | `*` 표시는 아래 Predicate Information에 조건이 있다는 뜻이다 |
| Operation | 수행한 작업 | 들여쓰기가 부모-자식 관계를 나타낸다. 가장 깊은 자식부터, 같은 깊이에서는 위쪽부터 실행된다 |
| Name | 대상 객체(테이블, 인덱스) | |
| Starts | 그 오퍼레이션이 실행된 횟수 | NL 조인의 안쪽 테이블은 바깥 행 수만큼 커진다 |
| E-Rows | 옵티마이저가 예상한 행 수 | 1회 실행당 값이다 |
| A-Rows | 실제로 반환된 행 수 | 모든 실행의 합계이다. 그래서 `E-Rows × Starts`와 비교한다 |
| A-Time | 실제 걸린 시간 | 자식의 시간이 포함된 누적값이다 |
| Buffers | 논리 I/O 블록 수 (consistent gets + current gets) | 누적값이다. 튜닝 성과는 주로 이 값으로 판단한다 |
| Reads | 디스크에서 읽은 블록 수 (물리 I/O) | 누적값이다. 캐시에 있으면 0이 된다 |

**누적값이라 빼서 읽어야 한다**

| 단계 | 계산 | 실제로 읽은 블록 |
|---|---|---|
| 3. INDEX RANGE SCAN | 21 | 인덱스 21블록 |
| 2. TABLE ACCESS BY INDEX ROWID | 154 - 21 | 테이블 133블록 |
| 1. SORT AGGREGATE | 154 - 154 | 0 (집계만 함) |

- 7,000건을 rowid로 찾았는데 테이블 블록은 133개만 읽었다. reg_dt 순서대로 저장되어 있어서 같은 블록 안의 행을 연달아 읽었기 때문이다(클러스터링 팩터, 5주차).
- Reads(156)가 Buffers(154)보다 큰 이유: `BATCHED` 방식은 읽을 블록을 미리 모아 디스크에서 한꺼번에 가져온다(prefetch). 이때 실제로는 쓰지 않은 블록까지 읽어 와서 Reads가 조금 더 커질 수 있다.

**상황에 따라 추가로 나오는 컬럼**

| 컬럼 | 나오는 경우 | 의미 |
|---|---|---|
| OMem / 1Mem / Used-Mem | SORT, HASH JOIN 등 | 메모리 안에서 처리하는 데 필요한 크기 / 1-pass로 처리 가능한 크기 / 실제 사용량 |
| Writes | 정렬이나 해시가 메모리를 넘칠 때 | TEMP 공간에 쓴 블록 수 |
| Used-Tmp | 위와 같음 | 사용한 TEMP 크기 |

**Predicate Information**
- `access`: 인덱스에서 어디서부터 어디까지 읽을지(스캔 범위)를 정하는 조건이다. 읽는 양 자체가 줄어든다.
- `filter`: 일단 읽은 다음 걸러내는 조건이다. 읽는 양은 줄지 않는다.
- 같은 reg_dt 조건이 [2] FULL에서는 `filter`로, [3] INDEX에서는 `access`로 나온다.

## 2. 챌린지

### 문제 원인
- `TABLE ACCESS FULL`(Id 2)에서 1,000,000행을 모두 읽은 뒤 `filter(TO_CHAR(INTERNAL_FUNCTION("REG_DT"),'YYYYMM')='202305')`로 31,000건만 남긴다.
- `w00_reg_dt_ix`는 reg_dt **원래 값** 순서로 정렬되어 있다. 그런데 조건이 `to_char(reg_dt, ...)`처럼 **컬럼을 가공한 결과**와 비교하기 때문에 인덱스에서 스캔 시작점과 끝점을 정할 수 없다. 그래서 인덱스를 access 조건으로 쓰지 못하고 FULL 스캔을 한다.
  - `INTERNAL_FUNCTION`은 DATE를 TO_CHAR에 넘기기 전에 내부 형 변환을 했다는 표시이다.
- E-Rows도 10,000(전체의 1%)으로 실제 31,000과 차이가 난다. 함수를 씌운 조건은 컬럼 통계를 쓸 수 없어서 옵티마이저가 기본 선택도를 썼다.

### Before
```text
SQL_ID  dfu1tt7t7pmt7, child number 0
-------------------------------------
select count(*), sum(amount) from   big_table where  to_char(reg_dt,
'YYYYMM') = '202305'

Plan hash value: 599409829

---------------------------------------------------------------------------------------------------
| Id  | Operation          | Name      | Starts | E-Rows | A-Rows |   A-Time   | Buffers | Reads  |
---------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT   |           |      1 |        |      1 |00:00:00.25 |   18868 |  18865 |
|   1 |  SORT AGGREGATE    |           |      1 |      1 |      1 |00:00:00.25 |   18868 |  18865 |
|*  2 |   TABLE ACCESS FULL| BIG_TABLE |      1 |  10000 |  31000 |00:00:00.25 |   18868 |  18865 |
---------------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - filter(TO_CHAR(INTERNAL_FUNCTION("REG_DT"),'YYYYMM')='202305')
```
결과: COUNT(*) 31,000 / SUM(AMOUNT) 155,628,500

### 튜닝 SQL (+ 필요하면 인덱스 DDL)
```sql
select count(*), sum(amount)
from   big_table
where  reg_dt >= date '2023-05-01'
and    reg_dt <  date '2023-06-01';
```
- 인덱스 DDL은 없다(기존 `w00_reg_dt_ix`만 사용).
- 범위 끝을 `between ... and date '2023-05-31'`이 아니라 `< date '2023-06-01'`로 쓴 이유: reg_dt에 시각이 들어 있어도 5월 31일 23:59:59까지 정확히 포함하기 위해서이다. 현재 데이터는 시각이 없지만(`reg_dt <> trunc(reg_dt)` 0건) 데이터가 바뀌어도 결과가 같게 유지된다.

### After
```text
SQL_ID  6jb3b15qx2k3b, child number 0
-------------------------------------
select count(*), sum(amount) from   big_table where  reg_dt >= date
'2023-05-01' and    reg_dt <  date '2023-06-01'

Plan hash value: 2239651889

-------------------------------------------------------------------------------------------------------------------------
| Id  | Operation                            | Name          | Starts | E-Rows | A-Rows |   A-Time   | Buffers | Reads  |
-------------------------------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT                     |               |      1 |        |      1 |00:00:00.01 |     670 |    589 |
|   1 |  SORT AGGREGATE                      |               |      1 |      1 |      1 |00:00:00.01 |     670 |    589 |
|   2 |   TABLE ACCESS BY INDEX ROWID BATCHED| BIG_TABLE     |      1 |  32031 |  31000 |00:00:00.01 |     670 |    589 |
|*  3 |    INDEX RANGE SCAN                  | W00_REG_DT_IX |      1 |  32031 |  31000 |00:00:00.01 |      85 |      0 |
-------------------------------------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   3 - access("REG_DT">=TO_DATE(' 2023-05-01 00:00:00', 'syyyy-mm-dd hh24:mi:ss') AND "REG_DT"<TO_DATE('
              2023-06-01 00:00:00', 'syyyy-mm-dd hh24:mi:ss'))
```
결과: COUNT(*) 31,000 / SUM(AMOUNT) 155,628,500 (Before와 같음)

| 지표 | Before | After |
|---|---:|---:|
| Buffers | 18,868 | 670 |
| Reads | 18,865 | 589 |
| A-Time | 0.25s | 0.01s |
| E-Rows / A-Rows | 10,000 / 31,000 | 32,031 / 31,000 |

### 근거
1. **원인:** 인덱스 컬럼 reg_dt를 `to_char`로 가공해서 인덱스의 정렬 순서를 이용할 수 없었다. 조건은 filter로만 쓰였고, 100만 행이 들어 있는 데이터 블록 18,865개를 모두 읽었다.
2. **해결:** 컬럼은 그대로 두고 비교 값 쪽을 범위(`>= 5/1`, `< 6/1`)로 바꿨다. 같은 31,000건을 가리키는 조건이지만 인덱스의 access 조건이 된다.
3. **왜 줄어드는가:**
   - 인덱스 리프 블록 85개만 읽어 5월 범위의 rowid 31,000개를 얻었다.
   - 테이블은 670 - 85 = 585블록만 읽었다. reg_dt 순서대로 저장되어 있어서(클러스터링 팩터가 좋음) 31,000건이 연속된 블록에 모여 있다. 블록당 약 53행이므로 31,000 / 53 ≈ 585로 계산과도 맞는다.
   - 결과적으로 Buffers는 18,868 → 670으로 약 1/28로 줄었다.
   - 통계를 쓸 수 있게 되어 E-Rows(32,031)도 실제(31,000)에 가까워졌다.

## 3. 책과 다르게 나온 점
- **FULL 스캔이 버퍼 캐시를 거치지 않는다.** [2], [4-a], [7]에서 FULL 스캔은 매번 `physical reads direct` ≈ 18,865, TKPROF 대기 이벤트 `direct path read` 156회였다. 11g부터 생긴 Serial Direct Path Read로, 큰 테이블은 버퍼 캐시 대신 PGA로 바로 읽는다. 그래서 반복 실행해도 Reads가 0이 되지 않는다. 반면 인덱스 액세스는 캐시를 사용해 [7]에서 disk 0이었다.
- **`TABLE ACCESS BY INDEX ROWID BATCHED`.** 책(10g/11g)에는 `BATCHED`가 없다. 12c부터 rowid를 모아 블록 단위로 한꺼번에 읽는다. 그 결과 [3]에서 Reads(156)가 Buffers(154)보다 커졌다.
- **세그먼트 공간 관리가 ASSM(AUTO)이다.** user_tables.BLOCKS에 ASSM 비트맵 블록 179개가 포함되어 있어서 FULL 스캔 Buffers와 차이가 났다.

## 4. 질문 / 토론거리
1. FULL 스캔이 direct path read로 처리될 때, Buffers(논리 I/O)로 집계되는 18,868은 어떤 기준으로 세는 것일까? 버퍼 캐시를 거치지 않았는데도 Buffers가 Reads와 같은 값으로 나온다.
2. 챌린지 After에서 테이블 블록 585개를 읽었다. reg_dt가 무작위로 저장되어 있었다면(rnd_id처럼) 같은 31,000건에 몇 블록을 읽었을까? 그때도 인덱스가 FULL보다 유리할까? (5주차 손익분기점)
3. AUTOTRACE의 consistent gets(18,897)와 TKPROF의 query(18,868)가 약간 다른 이유는? (재귀 SQL 포함 여부)

## 5. 블로그
- 링크:

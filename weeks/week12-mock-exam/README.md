# Week 12 — 실기 모의고사와 회고

| 범위 | 『오라클 성능 고도화 원리와 해법』 I·II 전체 (특히 II권 1~5장: 인덱스, 조인, 옵티마이저, 쿼리 변환, 소트) |
|---|---|

## 진행 방식
| 시간 | 내용 |
|---|---|
| 10분 | 환경 준비: `01_setup.sql`, `02_lab.sql`(데이터 분포 확인) |
| **90분** | **실기 모의고사.** 문제 3개, 개인별로 풀고 시간을 잽니다 |
| 40분 | 상호 채점: 아래 채점 기준표로 서로 PR을 채점합니다 |
| 40분 | 12주 회고 |

```bash
bash scripts/run.sh weeks/week12-mock-exam/01_setup.sql            # 1~2분
bash scripts/run.sh weeks/week12-mock-exam/02_lab.sql              # 분포·통계·인덱스 확인
bash scripts/run.sh weeks/week12-mock-exam/03_challenge.sql weeks/week12-mock-exam/submissions/<id>/before.txt
# 풀이: submissions/<id>/answer.sql 작성 → 실행 결과를 after.txt 로 저장
```

> 실제 SQLP 실기는 DB 없이 종이에 답합니다. 문제를 풀 때는 **먼저 종이(또는 result.md)에 풀이와 예상 Buffers를 쓰고**, 그다음 DB에서 검증하세요. 예측이 틀린 부분이 가장 중요한 복습 포인트입니다.

## 데이터 모델
```
W12_CUST (2만)           W12_ORDER (50만)                  W12_ORDER_ITEM (100만)
-----------------        ------------------------          ---------------------------
cust_id   PK             order_id  PK                       order_id  ┐ PK
cust_name                cust_id   → W12_CUST               item_seq  ┘
cust_grade               order_dt  (인덱스 w12_order_dt_ix) prod_id
region                   status                             qty
join_dt                  pay_amt                            price
addr                     memo                               opt
```
| 항목 | 분포 |
|---|---|
| cust_grade | VIP 100명(0.5%), GOLD 약 1,900명, NORMAL 18,000명 |
| order_dt | 2024-01-01 ~ 2024-12-31, 하루 약 1,366건. 주문번호(order_id) 순서 = 시간 순서 |
| status | DONE 90%, CANCEL 5%, READY 5% (기간과 관계없이 고르게 분포) |
| 주문상세 | 주문 1건당 2건. 주문번호 순서대로 저장 |
| 인덱스 | 각 테이블 PK + `w12_order_dt_ix (order_dt)` |
| 통계 | 모든 컬럼 히스토그램 없음 |

## 문제

### 문제 1. VIP 고객의 최근 3개월 완료 주문 (30점)
VIP 고객 전용 화면에서, 2024년 10~12월 완료(`DONE`) 주문을 최신순으로 모두 보여줍니다. 이 화면은 하루 수천 번 호출됩니다.
```sql
select c.cust_id, c.cust_name, o.order_id, o.order_dt, o.pay_amt
from   w12_cust c, w12_order o
where  c.cust_grade = 'VIP'
and    o.cust_id    = c.cust_id
and    o.status     = 'DONE'
and    o.order_dt  >= date '2024-10-01'
and    o.order_dt   < date '2025-01-01'
order  by o.order_dt desc;
```
1. Before 실행계획에서 비효율이 생기는 오퍼레이션과 원인을 쓰시오.
2. 최적의 인덱스를 설계하시오(DDL). 컬럼 순서를 정한 근거를 쓰시오.
3. 조인 순서와 조인 방법을 정하고, 힌트를 포함한 SQL을 작성하시오.
4. 튜닝 후 예상 Buffers를 계산 근거와 함께 쓰고, 실제 결과와 비교하시오.

### 문제 2. 특정 일자 상품별 매출 Top 10 (35점)
일별 정산 배치가 하루치 주문의 상품별 매출 상위 10개를 구합니다. 취소 주문은 제외합니다.
```sql
select i.prod_id, sum(i.qty * i.price) as sales_amt, count(*) as item_cnt
from   w12_order_item i
where  i.order_id in (select o.order_id
                      from   w12_order o
                      where  to_char(o.order_dt, 'YYYYMMDD') = '20240615'
                      and    o.status <> 'CANCEL')
group  by i.prod_id
order  by sales_amt desc, i.prod_id
fetch  first 10 rows only;
```
1. Before 실행계획에서 서브쿼리가 어떻게 처리되었는지(필터 / 조인 변환 등) 쓰고, 비효율의 원인 두 가지를 쓰시오.
2. 인덱스를 추가하지 않고 SQL만 고쳐서 개선하시오. 조인 순서·방법을 정한 근거를 쓰시오.
3. 하루치가 아니라 **한 달치**를 구한다면 최적의 조인 방법이 바뀌는가? 이유와 함께 쓰시오.

### 문제 3. 배송 대기 주문 목록 페이징 (35점)
물류 담당자 화면에서 배송 대기(`READY`) 주문을 최신순으로 20건씩 보여줍니다. 아래는 3페이지(41~60번째) 조회입니다.
```sql
select *
from  (select rownum as rn, x.*
       from  (select o.order_id, o.order_dt, o.pay_amt, c.cust_name, c.cust_grade
              from   w12_order o, w12_cust c
              where  o.cust_id = c.cust_id
              and    o.status  = 'READY'
              order  by o.order_dt desc, o.order_id desc) x)
where  rn between 41 and 60;
```
1. Before 실행계획에서 (a) 읽는 범위, (b) 소트, (c) 조인 시점의 비효율을 각각 쓰시오.
2. 인덱스를 설계하고(DDL), 부분범위처리가 되도록 SQL을 다시 쓰시오.
3. 고객 테이블 조인을 **페이징 이후**로 미루는 것이 왜 유리한지 Starts와 Buffers로 설명하시오.

### 제한 조건
- 결과(행, 컬럼 값, 정렬 순서)는 원본과 같아야 합니다.
- 테이블 구조와 데이터는 바꿀 수 없습니다. 인덱스 추가와 SQL 재작성, 힌트만 허용합니다.
- 인덱스는 **문제 1·3에서 합계 2개 이하**로 추가합니다. 같은 인덱스를 두 문제가 함께 써도 됩니다. 문제 2는 인덱스를 추가할 수 없습니다.
- 각 문제의 튜닝 SQL을 실행한 뒤 `@@../../common/xplan` 결과를 after.txt에 남깁니다.

## 채점 기준표
| 항목 | 문제 1 (30) | 문제 2 (35) | 문제 3 (35) | 기준 |
|---|---:|---:|---:|---|
| 원인 파악 | 6 | 8 | 8 | 실행계획의 **어느 단계**가 **왜** 비효율인지 수치(A-Rows, Buffers, Starts)로 지적 |
| 인덱스 설계 | 8 | — | 8 | 컬럼 구성과 순서, `=` / 범위 조건, 정렬과 테이블 액세스를 모두 고려했는가 |
| SQL 재작성·힌트 | 8 | 15 | 11 | 결과가 원본과 같고, 의도한 실행계획(조인 순서·방법, STOPKEY)이 실제로 나오는가 |
| 근거 서술 | 8 | 12 | 8 | 블록 I/O 관점에서 왜 줄어드는지 설명. 예상 Buffers와 실제 비교. 문제 2-3처럼 조건이 바뀌는 경우의 판단 |

- 결과가 원본과 다르면 해당 문제의 "SQL 재작성" 점수는 0점입니다.
- 힌트만 넣었는데 실행계획이 의도대로 나오지 않았으면 부분 점수만 줍니다(실행계획으로 검증하는 것까지가 답입니다).
- 상호 채점: 리뷰어는 PR 코멘트로 항목별 점수와 감점 사유를 남깁니다.

**권장 풀이 시간:** 문제 1 25분, 문제 2 35분, 문제 3 30분

정답 풀이는 스터디가 끝난 뒤 진행자가 `answer.md`로 공개합니다.

## 책과 다른 점 (23ai)
- 문제 2의 `IN` 서브쿼리는 버전에 따라 필터, 세미 조인, 일반 조인(서브쿼리 Unnesting 후 뷰 머징) 중 어느 형태로 바뀔지 다릅니다. Before 실행계획을 보고 실제로 어떻게 변환되었는지부터 확인하세요.
- `fetch first`는 23ai에서 rownum 방식(SORT ORDER BY STOPKEY)으로 처리됩니다 (week10 참고).
- 12c 이후 Adaptive Plan이 켜져 있으면 실행 중에 NL과 Hash 조인이 바뀔 수 있습니다. 실행계획 아래 `Note`에 `this is an adaptive plan`이 보이면 `+ADAPTIVE` 형식으로 다시 확인해 보세요.

## 제출
`weeks/week12-mock-exam/submissions/<github-id>/`
- `result.md`: 문제별 답안(원인 / 인덱스 DDL / SQL / 근거 / 예상 vs 실제 Buffers)
- `answer.sql`: 튜닝 SQL과 인덱스 DDL. 실행 가능한 스크립트로 작성
- `before.txt`, `after.txt`

## 12주 회고
### 회고 질문 (각자 작성해 result.md 끝에 추가)
1. 12주 전과 비교해 실행계획을 읽는 속도와 관점이 어떻게 바뀌었나? 지금은 무엇을 가장 먼저 보는가?
2. 예측(가설)과 실제 수치가 가장 크게 달랐던 실습은 무엇이고, 그 이유는 무엇이었나?
3. 책(10g/11g)과 23ai가 가장 다르게 동작했던 부분 세 가지는?
4. 실무 SQL에 바로 적용해 본 것, 또는 적용할 것은 무엇인가?
5. 다음 스터디를 한다면 무엇을 바꾸겠는가? (진행 방식, 실습 난이도, 리뷰 방식)

### 블로그 시리즈 정리 가이드
- **목차 글 1편 작성:** 「SQLP 체화 스터디 #00 — 시리즈 목차」. 주차별 글 링크와 한 줄 요약(가장 인상 깊었던 수치 하나)을 정리합니다.
- **대표 글 3편 고르기:** 튜닝 전후 수치가 극적인 글 3편을 골라 다듬습니다. 실행계획 원문, Before/After 표, 원리 설명이 모두 있는지 확인합니다. 포트폴리오나 면접에서 "직접 측정해 본 튜닝 사례"로 쓸 수 있습니다.
- **루트 README 블로그 표**에 본인 링크를 모두 채웁니다.
- **책 원문 인용 점검:** 인용은 짧게, 출처를 표기했는지 다시 확인합니다.

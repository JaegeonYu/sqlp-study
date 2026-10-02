-- week06 lab: NL / Sort Merge / Hash 조인 비교
--   같은 결과를 내는 조인을 힌트로 방식만 바꿔 실행하고 Buffers, A-Time, 메모리(OMem / Used-Mem)를 비교한다.
--   소량 : VIP 고객 + R03 지역 → 고객 10명,    주문 약 1,000건
--   대량 : R03 지역 전체        → 고객 1,000명, 주문 약 100,000건
@@../../common/session_init

prompt
prompt ===== [1] 두 상황의 건수 확인 =====
select '소량' as case_nm, count(distinct c.cust_id) as cust_cnt, count(*) as order_cnt
from   w06_cust c, big_table b
where  b.rnd_id = c.cust_id
and    c.grade = 'VIP' and c.region_cd = 'R03'
union all
select '대량', count(distinct c.cust_id), count(*)
from   w06_cust c, big_table b
where  b.rnd_id = c.cust_id
and    c.region_cd = 'R03';
prompt 관찰: 조인 대상 건수가 100배 차이 난다. 어느 조인 방식이 유리할지 먼저 예측해 보자.

prompt
prompt ===== [2] 소량 - NL 조인 (고객 → 주문 인덱스) =====
select /*+ leading(c b) use_nl(b) index(b w06_big_rnd_ix) */
       count(*), sum(b.amount)
from   w06_cust c, big_table b
where  b.rnd_id = c.cust_id
and    c.grade = 'VIP' and c.region_cd = 'R03';
@@../../common/xplan
prompt 관찰: 인덱스 단계의 Starts(=드라이빙 건수)와 테이블 액세스 단계의 Buffers. NESTED LOOPS 가 왜 두 번 나올까?

prompt
prompt ===== [3] 소량 - Hash 조인 =====
select /*+ leading(c b) use_hash(b) full(b) */
       count(*), sum(b.amount)
from   w06_cust c, big_table b
where  b.rnd_id = c.cust_id
and    c.grade = 'VIP' and c.region_cd = 'R03';
@@../../common/xplan
prompt 관찰: 1,000건을 얻으려고 BIG_TABLE 전체를 읽었다. [2]와 Buffers 를 비교하자.

prompt
prompt ===== [4] 소량 - Sort Merge 조인 =====
select /*+ leading(c b) use_merge(b) full(b) */
       count(*), sum(b.amount)
from   w06_cust c, big_table b
where  b.rnd_id = c.cust_id
and    c.grade = 'VIP' and c.region_cd = 'R03';
@@../../common/xplan
prompt 관찰: SORT JOIN 단계의 OMem / Used-Mem. 100만 건을 정렬하는 비용은 어디에 나타나는가?

prompt
prompt ===== [5] 대량 - NL 조인 =====
select /*+ leading(c b) use_nl(b) index(b w06_big_rnd_ix) */
       count(*), sum(b.amount)
from   w06_cust c, big_table b
where  b.rnd_id = c.cust_id
and    c.region_cd = 'R03';
@@../../common/xplan
prompt 관찰: 테이블 랜덤 액세스 Buffers 가 BIG_TABLE 전체 블록 수(약 19,000)를 넘는가?

prompt
prompt ===== [6] 대량 - Hash 조인 (Build = 고객) =====
select /*+ leading(c b) use_hash(b) full(b) */
       count(*), sum(b.amount)
from   w06_cust c, big_table b
where  b.rnd_id = c.cust_id
and    c.region_cd = 'R03';
@@../../common/xplan
prompt 관찰: Buffers 는 [3]과 거의 같다. 건수가 100배가 되어도 Hash 조인 비용이 거의 그대로인 이유는?

prompt
prompt ===== [7] 대량 - Sort Merge 조인 =====
select /*+ leading(c b) use_merge(b) full(b) */
       count(*), sum(b.amount)
from   w06_cust c, big_table b
where  b.rnd_id = c.cust_id
and    c.region_cd = 'R03';
@@../../common/xplan
prompt 관찰: [6]과 Buffers 는 비슷한데 A-Time 과 메모리는? Sort Merge 가 Hash 보다 나은 경우는 언제일까?

prompt
prompt ===== [8] NL 조인인데 Inner 쪽에 인덱스가 없다면 (소량) =====
select /*+ leading(c b) use_nl(b) full(b) */
       count(*), sum(b.amount)
from   w06_cust c, big_table b
where  b.rnd_id = c.cust_id
and    c.grade = 'VIP' and c.region_cd = 'R03';
@@../../common/xplan
prompt 관찰: TABLE ACCESS FULL 의 Starts 와 Buffers. 드라이빙 10건마다 BIG_TABLE 전체를 다시 읽었다.

prompt
prompt ===== [9] NL 조인 드라이빙 순서를 뒤집으면 (소량 조건) =====
select /*+ leading(b c) use_nl(c) full(b) index(c w06_cust_pk) */
       count(*), sum(b.amount)
from   w06_cust c, big_table b
where  b.rnd_id = c.cust_id
and    c.grade = 'VIP' and c.region_cd = 'R03';
@@../../common/xplan
prompt 관찰: 고객 PK 인덱스의 Starts 는 몇 번인가? 조건(grade, region_cd)은 어디서 걸러지는가? [2]와 Buffers 차이는?

prompt
prompt ===== [10] Hash 조인 Build / Probe 를 바꾸면 (대량) =====
prompt --- [10-a] Build = 고객(작은 쪽) : [6]과 같은 힌트
select /*+ leading(c b) use_hash(b) full(b) */
       count(*), sum(b.amount)
from   w06_cust c, big_table b
where  b.rnd_id = c.cust_id
and    c.region_cd = 'R03';
@@../../common/xplan
prompt --- [10-b] Build = 주문(큰 쪽) : swap_join_inputs
select /*+ leading(c b) use_hash(b) full(b) swap_join_inputs(b) */
       count(*), sum(b.amount)
from   w06_cust c, big_table b
where  b.rnd_id = c.cust_id
and    c.region_cd = 'R03';
@@../../common/xplan
prompt 관찰: HASH JOIN 바로 아래 첫 번째 자식이 Build 입력이다. OMem / Used-Mem 은 몇 배 차이 나는가? Used-Tmp 가 생겼는가?

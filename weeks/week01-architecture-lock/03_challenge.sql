-- week01 challenge (단일 세션 부분)
--   C1(FK Lock 진단)과 C2(인덱스 없는 FK 찾기 SQL)는 README를 보고 직접 수행한다.
--   C3: 실행하기 전에 두 SQL 각각의 Buffers 를 먼저 예측해 result.md 에 적은 뒤 실행할 것.
@@../../common/session_init

prompt
prompt ===== C3-a: cust_id 50개 값 (약 5,000건) =====
select /*+ index(b w01_cust_ix) */ count(*), sum(amount)
from   big_table b
where  cust_id between 1 and 50;
@@../../common/xplan

prompt
prompt ===== C3-b: rnd_id 50개 값 (약 5,000건) =====
select /*+ index(b w01_rnd_ix) */ count(*), sum(amount)
from   big_table b
where  rnd_id between 1 and 50;
@@../../common/xplan

prompt
prompt ===== C3-c: 같은 조건을 FULL 로 =====
select /*+ full(b) */ count(*), sum(amount)
from   big_table b
where  rnd_id between 1 and 50;
@@../../common/xplan
prompt 과제: 예측과 실제의 차이를 설명하라. C3-b 와 C3-c 중 무엇이 나은가? 건수가 몇 건을 넘으면 역전될까?

-- week05 미니 모의 1 (실기형): w05_order 50만 건
--   P1, P2 를 모두 빠르게 만드는 인덱스를 "최대 2개"까지 설계하고, 필요하면 SQL 을 다시 써라.
--   기존 인덱스 w05_order_dt_ix(order_dt) 는 지워도 된다.
--   제출: 인덱스 DDL, 튜닝 SQL, Before/After 실행계획과 Buffers, 컬럼 순서를 정한 근거
--   (실기 답안처럼: 원인 → 인덱스 설계 → 튜닝 SQL → 근거)
@@../../common/session_init

prompt
prompt ===== P1: 특정 고객의 2025년 주문 (취소 제외), 최신순 =====
set feedback only
select order_id, order_dt, status, amount
from   w05_order
where  cust_no = 777
and    order_dt between date '2025-01-01' and date '2025-12-31'
and    status <> 'CANCEL'
order  by order_dt desc;
set feedback on
@@../../common/xplan

prompt
prompt ===== P2: 2025년 12월 대기(WAIT) 주문 중 오래된 순 20건 =====
select order_id, cust_no, order_dt, amount
from   w05_order
where  status = 'WAIT'
and    order_dt >= date '2025-12-01'
order  by order_dt
fetch  first 20 rows only;
@@../../common/xplan

prompt 과제: 두 SQL 의 비효율 원인을 실행계획으로 설명하고, 인덱스 2개 이내로 둘 다 Buffers 를 크게 줄여라.
prompt       P1 의 status <> 'CANCEL' 은 인덱스에 넣어야 할까? P2 는 정렬을 생략할 수 있을까?

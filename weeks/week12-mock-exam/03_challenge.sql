-- week12 실기 모의고사: 문제 3개의 원본 SQL과 Before 실행계획
--   문제 설명, 요구사항, 채점 기준은 README.md 에 있다.
--   풀이는 이 파일을 고치지 말고, 본인 submissions 폴더에 answer.sql 로 따로 작성해 실행한다.
@@../../common/session_init
set arraysize 500

prompt
prompt ===== 문제 1. VIP 고객의 최근 3개월 완료 주문 =====
set feedback only
select c.cust_id, c.cust_name, o.order_id, o.order_dt, o.pay_amt
from   w12_cust c, w12_order o
where  c.cust_grade = 'VIP'
and    o.cust_id    = c.cust_id
and    o.status     = 'DONE'
and    o.order_dt  >= date '2024-10-01'
and    o.order_dt   < date '2025-01-01'
order  by o.order_dt desc;
set feedback on
@@../../common/xplan

prompt
prompt ===== 문제 2. 특정 일자 상품별 매출 Top 10 (취소 제외) =====
select i.prod_id, sum(i.qty * i.price) as sales_amt, count(*) as item_cnt
from   w12_order_item i
where  i.order_id in (select o.order_id
                      from   w12_order o
                      where  to_char(o.order_dt, 'YYYYMMDD') = '20240615'
                      and    o.status <> 'CANCEL')
group  by i.prod_id
order  by sales_amt desc, i.prod_id
fetch  first 10 rows only;
@@../../common/xplan

prompt
prompt ===== 문제 3. 배송 대기(READY) 주문 목록 3페이지 (페이지당 20건, 최신순) =====
set feedback only
select *
from  (select rownum as rn, x.*
       from  (select o.order_id, o.order_dt, o.pay_amt, c.cust_name, c.cust_grade
              from   w12_order o, w12_cust c
              where  o.cust_id = c.cust_id
              and    o.status  = 'READY'
              order  by o.order_dt desc, o.order_id desc) x)
where  rn between 41 and 60;
set feedback on
@@../../common/xplan

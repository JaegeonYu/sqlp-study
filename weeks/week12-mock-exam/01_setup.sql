-- week12 setup: 실기 모의고사용 쇼핑몰 테이블 (고객 2만 / 주문 50만 / 주문상세 100만)
--   이번 주는 BIG_TABLE을 쓰지 않는다. 생성에 1~2분 걸린다.
@@../../common/session_init

prompt 실기 모의고사 테이블 생성 중...

drop table if exists w12_order_item purge;
drop table if exists w12_order      purge;
drop table if exists w12_cust       purge;

-- 고객 2만 명
--   cust_grade: VIP 0.5%(100명) / GOLD 약 9.5% / NORMAL 90%
--   region    : 1~10 균등
create table w12_cust as
select level                                                   as cust_id,
       'CUST-' || lpad(level, 5, '0')                          as cust_name,
       case when mod(level, 200) = 0 then 'VIP'
            when mod(level, 10)  = 0 then 'GOLD'
            else 'NORMAL' end                                  as cust_grade,
       mod(level, 10) + 1                                      as region,
       date '2015-01-01' + mod(level * 37, 3650)               as join_dt,
       rpad('a', 80, 'a')                                      as addr
from   dual
connect by level <= 20000;
alter table w12_cust add constraint w12_cust_pk primary key (cust_id);

-- 주문 50만 건 (2024년 1년치, 주문번호 = 시간 순)
--   cust_id : 고객 무작위
--   status  : DONE 90% / CANCEL 5% / READY 5%
--   order_dt: 하루 약 1,366건, 주문번호 순으로 증가
exec dbms_random.seed(20261002)
create table w12_order as
select n                                                       as order_id,
       trunc(dbms_random.value(1, 20001))                      as cust_id,
       date '2024-01-01' + (n - 1) * 366 / 500000              as order_dt,
       case mod(n, 20) when 0 then 'CANCEL' when 1 then 'READY' else 'DONE' end as status,
       mod(n * 31, 500) * 100 + 1000                           as pay_amt,
       rpad('o', 150, 'o')                                     as memo
from  (select (a.n - 1) * 1000 + b.n as n
       from   (select level n from dual connect by level <= 500) a,
              (select level n from dual connect by level <= 1000) b)
order  by n;
alter table w12_order add constraint w12_order_pk primary key (order_id);
-- 개발 초기에 만들어 둔 인덱스 (이것만 있다)
create index w12_order_dt_ix on w12_order (order_dt);

-- 주문상세 100만 건 (주문당 2건)
create table w12_order_item as
select ceil(n / 2)                                             as order_id,
       2 - mod(n, 2)                                           as item_seq,
       trunc(dbms_random.value(1, 1001))                       as prod_id,
       mod(n, 5) + 1                                           as qty,
       mod(n * 13, 100) * 500 + 500                            as price,
       rpad('i', 100, 'i')                                     as opt
from  (select (a.n - 1) * 1000 + b.n as n
       from   (select level n from dual connect by level <= 1000) a,
              (select level n from dual connect by level <= 1000) b)
order  by n;
alter table w12_order_item add constraint w12_order_item_pk primary key (order_id, item_seq);

-- 통계는 히스토그램 없이 수집 (실제 운영 DB와 같다고 가정)
exec dbms_stats.gather_table_stats(user, 'W12_CUST',       method_opt => 'for all columns size 1', cascade => true)
exec dbms_stats.gather_table_stats(user, 'W12_ORDER',      method_opt => 'for all columns size 1', cascade => true)
exec dbms_stats.gather_table_stats(user, 'W12_ORDER_ITEM', method_opt => 'for all columns size 1', cascade => true)

prompt
prompt week12 준비 완료

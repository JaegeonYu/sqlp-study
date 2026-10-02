-- week05 setup: 클러스터링 팩터, 결합 인덱스 순서, IOT 실습용 객체 + 미니 모의 1 테이블
@@../../common/session_init
@@../../common/gen_big_table

-- BIG_TABLE 인덱스 (99_cleanup에서 제거)
--   주의: SQL*Plus 에서는 세미콜론 뒤에 같은 줄 주석(-- ...)을 달면 문장이 끝나지 않는다. 주석은 윗줄에 둔다.
-- cust_id: 연속 저장 → CF 좋음 / rnd_id: 무작위 → CF 나쁨
create index if not exists w05_cust_ix   on big_table (cust_id);
create index if not exists w05_rnd_ix    on big_table (rnd_id);
-- 같은 두 컬럼, 순서만 다른 결합 인덱스: = 컬럼 선두 / 범위 컬럼 선두
create index if not exists w05_grp_dt_ix on big_table (grp_id, reg_dt);
create index if not exists w05_dt_grp_ix on big_table (reg_dt, grp_id);

-- IOT 비교용: 같은 10만 건을 (1) 무작위 순서 힙 테이블 (2) IOT 로 저장
drop table if exists w05_heap purge;
drop table if exists w05_iot  purge;
create table w05_heap as
select cust_id, id as seq, amount, pad
from   big_table
where  cust_id <= 1000
order  by rnd_id;
alter table w05_heap add constraint w05_heap_pk primary key (cust_id, seq);

create table w05_iot (
  cust_id number,
  seq     number,
  amount  number,
  pad     varchar2(100),
  constraint w05_iot_pk primary key (cust_id, seq)
) organization index;
insert into w05_iot select cust_id, seq, amount, pad from w05_heap;
commit;

-- 미니 모의 1 (03_challenge.sql): 주문 테이블 50만 건
--   cust_no  : 1..20,000 무작위 (고객당 평균 25건)
--   order_dt : 2024-01-01 ~ 2025-12-31 무작위
--   status   : DONE 90% / CANCEL 5% / WAIT 5%
drop table if exists w05_order purge;
exec dbms_random.seed(5)
create table w05_order as
select n                                                   as order_id,
       trunc(dbms_random.value(1, 20001))                  as cust_no,
       date '2024-01-01' + trunc(dbms_random.value(0, 731)) as order_dt,
       case when r < 0.90 then 'DONE'
            when r < 0.95 then 'CANCEL'
            else 'WAIT' end                                as status,
       trunc(dbms_random.value(1000, 100000))              as amount,
       rpad('x', 80, 'x')                                  as pad
from  (select (a.n - 1) * 500 + b.n as n, dbms_random.value as r
       from   (select level n from dual connect by level <= 1000) a,
              (select level n from dual connect by level <= 500)  b);
alter table w05_order add constraint w05_order_pk primary key (order_id);
create index w05_order_dt_ix on w05_order (order_dt);

exec dbms_stats.gather_table_stats(user, 'W05_HEAP',  method_opt => 'for all columns size 1', cascade => true)
exec dbms_stats.gather_table_stats(user, 'W05_IOT',   method_opt => 'for all columns size 1', cascade => true)
exec dbms_stats.gather_table_stats(user, 'W05_ORDER', method_opt => 'for all columns size 1', cascade => true)

prompt
prompt week05 준비 완료

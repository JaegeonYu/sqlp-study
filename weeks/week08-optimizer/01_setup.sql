-- week08 setup: 옵티마이저 실습용 테이블 (통계·히스토그램·확장 통계·바인드 피킹)
@@../../common/session_init
@@../../common/gen_big_table

-- 챌린지용: rnd_id 는 무작위 저장 → 인덱스로 읽으면 행마다 다른 블록
create index if not exists w08_rnd_ix on big_table (rnd_id);

-- 주문 20만 건. state 는 'DONE' 199,500건 / 'WAIT' 500건, 'WAIT' 은 테이블 끝에 몰려 있다(최근 주문).
drop table if exists w08_orders purge;
create table w08_orders as
select level                                              as ord_id,
       case when level > 199500 then 'WAIT' else 'DONE' end as state,
       date '2024-01-01' + trunc((level - 1) / 1000)      as ord_dt,
       mod(level * 13, 100000)                            as amt,
       rpad('o', 80, 'o')                                 as pad
from   dual
connect by level <= 200000;
alter table w08_orders add constraint w08_orders_pk primary key (ord_id);
create index w08_orders_state_ix on w08_orders (state);

-- 주소 10만 건. zip_cd 가 정해지면 city_cd 가 정해진다(완전 상관관계).
drop table if exists w08_addr purge;
create table w08_addr as
select level                       as addr_id,
       trunc(mod(level, 1000) / 10) as city_cd,   -- 0..99
       mod(level, 1000)             as zip_cd,    -- 0..999
       rpad('a', 50, 'a')           as pad
from   dual
connect by level <= 100000;

-- 챌린지용 고객 1만 건. grade, tier, lvl 은 항상 같은 값(상관관계 3중).
drop table if exists w08_cust purge;
create table w08_cust as
select level                as cust_id,
       mod(level, 10) + 1   as grade,
       mod(level, 10) + 1   as tier,
       mod(level, 10) + 1   as lvl,
       rpad('c', 50, 'c')   as cname
from   dual
connect by level <= 10000;
alter table w08_cust add constraint w08_cust_pk primary key (cust_id);

-- 동적 샘플링용: 통계가 없는 테이블
drop table if exists w08_nostat purge;
create table w08_nostat as select * from big_table where id <= 100000;
exec dbms_stats.delete_table_stats(user, 'W08_NOSTAT')

-- 실시간 통계 관찰용
drop table if exists w08_rts purge;
create table w08_rts as select id, grp_id, amount from big_table where id <= 10000;

-- 모든 실습 테이블은 히스토그램 없이 시작
begin
  for t in (select column_value tname from table(sys.odcivarchar2list('W08_ORDERS', 'W08_ADDR', 'W08_CUST', 'W08_RTS'))) loop
    dbms_stats.gather_table_stats(user, t.tname, method_opt => 'for all columns size 1',
                                  cascade => true, no_invalidate => false);
  end loop;
end;
/

prompt
prompt week08 준비 완료

-- week06 setup: 고객(차원) / 지역(코드) 테이블 + BIG_TABLE 조인용 인덱스
--   BIG_TABLE.rnd_id 를 "주문의 고객번호"로 사용한다. 무작위 저장이라 실제 주문 테이블처럼
--   한 고객의 주문이 여러 블록에 흩어져 있다 (고객당 약 100건).
@@../../common/session_init
@@../../common/gen_big_table

-- 고객 10,000명
--   region_cd : R01~R10, 1,000명씩 (cust_id 순서대로)
--   grade     : VIP 1%(지역당 10명) / GOLD 9% / NORMAL 90%
drop table if exists w06_cust purge;
create table w06_cust as
select level                                       as cust_id,
       'C' || lpad(level, 5, '0')                  as cust_nm,
       'R' || lpad(ceil(level / 1000), 2, '0')     as region_cd,
       case when mod(level, 100) = 0 then 'VIP'
            when mod(level, 10)  = 0 then 'GOLD'
            else 'NORMAL' end                      as grade,
       rpad('c', 50, 'c')                          as pad
from   dual
connect by level <= 10000;
alter table w06_cust add constraint w06_cust_pk primary key (cust_id);

-- 지역 코드 10건 (챌린지용)
drop table if exists w06_region purge;
create table w06_region (
  region_cd varchar2(3) constraint w06_region_pk primary key,
  region_nm varchar2(20),
  mgr_nm    varchar2(20)
);
insert into w06_region
select 'R' || lpad(level, 2, '0'),
       decode(level, 1, 'SEOUL', 2, 'BUSAN', 3, 'DAEGU', 4, 'INCHEON', 5, 'GWANGJU',
                     6, 'DAEJEON', 7, 'ULSAN', 8, 'SEJONG', 9, 'GYEONGGI', 'JEJU'),
       'MGR' || level
from   dual
connect by level <= 10;
commit;

-- NL 조인의 Inner 쪽 액세스용
create index if not exists w06_big_rnd_ix on big_table (rnd_id);

exec dbms_stats.gather_table_stats(user, 'W06_CUST',   cascade => true)
exec dbms_stats.gather_table_stats(user, 'W06_REGION', cascade => true)

prompt
prompt week06 준비 완료

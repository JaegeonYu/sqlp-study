-- week07 setup: 스칼라 서브쿼리 캐싱 / Semi·Anti 조인 / 고급 조인 기법 실습 객체
--   BIG_TABLE.rnd_id 를 "주문의 고객번호"로 사용한다 (week06과 같은 관점).
@@../../common/session_init
@@../../common/gen_big_table

-- 고객 10,000명: region_cd R01~R10 각 1,000명, grade VIP 1% / GOLD 9% / NORMAL 90%
drop table if exists w07_cust purge;
create table w07_cust as
select level                                       as cust_id,
       'C' || lpad(level, 5, '0')                  as cust_nm,
       'R' || lpad(ceil(level / 1000), 2, '0')     as region_cd,
       case when mod(level, 100) = 0 then 'VIP'
            when mod(level, 10)  = 0 then 'GOLD'
            else 'NORMAL' end                      as grade,
       mod(level * 13, 1000)                       as pts
from   dual
connect by level <= 10000;
alter table w07_cust add constraint w07_cust_pk primary key (cust_id);

-- 그룹 코드 100건 (BIG_TABLE.grp_id 1..100 의 이름, 할인율)
drop table if exists w07_grp purge;
create table w07_grp as
select level                          as grp_id,
       'GROUP-' || lpad(level, 3, '0') as grp_nm,
       mod(level * 7, 10) / 100       as disc_rate
from   dual
connect by level <= 100;
alter table w07_grp add constraint w07_grp_pk primary key (grp_id);

-- 블랙리스트: NOT IN + NULL 함정 실습 (NULL 1건 포함)
drop table if exists w07_blacklist purge;
create table w07_blacklist (cust_id number);
insert into w07_blacklist select level * 1000 from dual connect by level <= 5;
insert into w07_blacklist values (null);

-- 일자별 매출 1,000건 (누적합·직전값 실습)
drop table if exists w07_daily_sales purge;
create table w07_daily_sales as
select reg_dt as sale_dt, sum(amount) as amt, count(*) as cnt
from   big_table
group  by reg_dt;
alter table w07_daily_sales add constraint w07_daily_sales_pk primary key (sale_dt);

-- 고객 등급 선분이력: 고객마다 4구간 (250일씩, 마지막 구간 종료일 9999-12-31)
drop table if exists w07_grade_hist purge;
create table w07_grade_hist as
select c.cust_id,
       k.seq,
       date '2022-01-01' + (k.seq - 1) * 250                            as st_dt,
       case when k.seq = 4 then date '9999-12-31'
            else date '2022-01-01' + k.seq * 250 - 1 end               as ed_dt,
       case mod(c.cust_id + k.seq, 3) when 0 then 'VIP'
                                      when 1 then 'GOLD'
                                      else 'NORMAL' end                as grade
from   w07_cust c,
       (select level as seq from dual connect by level <= 4) k;
alter table w07_grade_hist add constraint w07_grade_hist_pk primary key (cust_id, st_dt);

-- 소계용 복제 테이블 (Copy_T)
drop table if exists w07_copy_t purge;
create table w07_copy_t as select level as no from dual connect by level <= 2;

commit;

-- 주문(BIG_TABLE)을 고객번호 + 일자로 찾는 인덱스
create index if not exists w07_big_rnd_dt_ix on big_table (rnd_id, reg_dt);

-- 호출 횟수 카운터 + 테스트용 함수
create or replace package w07_cnt as
  g_calls number := 0;
  procedure reset;
  function calls return number;
end w07_cnt;
/
create or replace package body w07_cnt as
  procedure reset is begin g_calls := 0; end;
  function calls return number is begin return g_calls; end;
end w07_cnt;
/
-- 그룹 할인율 조회 (NUMBER 반환, 입력값 NDV 100)
create or replace function w07_grp_rate (p_grp_id number) return number is
  l_rate number;
begin
  w07_cnt.g_calls := w07_cnt.g_calls + 1;
  select disc_rate into l_rate from w07_grp where grp_id = p_grp_id;
  return l_rate;
exception
  when no_data_found then return null;
end;
/
-- 고객 포인트 조회 (NUMBER 반환, 입력값 NDV 10,000)
create or replace function w07_cust_pts (p_cust_id number) return number is
  l_pts number;
begin
  w07_cnt.g_calls := w07_cnt.g_calls + 1;
  select pts into l_pts from w07_cust where cust_id = p_cust_id;
  return l_pts;
exception
  when no_data_found then return null;
end;
/
-- 그룹명 조회 (VARCHAR2 반환, 입력값 NDV 100) : 반환 타입에 따른 캐시 효과 비교 + 챌린지용
create or replace function w07_grp_nm (p_grp_id number) return varchar2 is
  l_nm w07_grp.grp_nm%type;
begin
  w07_cnt.g_calls := w07_cnt.g_calls + 1;
  select grp_nm into l_nm from w07_grp where grp_id = p_grp_id;
  return l_nm;
exception
  when no_data_found then return null;
end;
/

exec dbms_stats.gather_table_stats(user, 'W07_CUST',        cascade => true)
exec dbms_stats.gather_table_stats(user, 'W07_GRP',         cascade => true)
exec dbms_stats.gather_table_stats(user, 'W07_BLACKLIST')
exec dbms_stats.gather_table_stats(user, 'W07_DAILY_SALES', cascade => true)
exec dbms_stats.gather_table_stats(user, 'W07_GRADE_HIST',  cascade => true)
exec dbms_stats.gather_table_stats(user, 'W07_COPY_T')

prompt
prompt week07 준비 완료

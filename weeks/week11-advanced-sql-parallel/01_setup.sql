-- week11 setup: 고급 SQL 활용 / 병렬 처리 실습용 객체
@@../../common/session_init
@@../../common/gen_big_table

-- 그룹 내 Top-N 실습용: cust_id 별 amount 순서
create index if not exists w11_cust_amt_ix on big_table (cust_id, amount);

-- 병렬 조인 분배 방식 실습용 그룹 코드 (100건)
drop table if exists w11_grp purge;
create table w11_grp (
  grp_id   number primary key,
  grp_name varchar2(20) not null
);
insert into w11_grp select level, 'GROUP-' || level from dual connect by level <= 100;

-- MERGE 실습용 고객 집계 테이블: cust_id 1~1000 만 미리 존재 (1001~2000 은 신규)
drop table if exists w11_cust_sum purge;
create table w11_cust_sum (
  cust_id   number primary key,
  total_amt number,
  cnt       number,
  upd_dt    date
);
insert into w11_cust_sum
select level, 0, 0, date '2022-01-01' from dual connect by level <= 1000;

-- 병렬 DML 대상 빈 테이블
drop table if exists w11_copy purge;
create table w11_copy as select * from big_table where 1 = 0;

commit;
exec dbms_stats.gather_table_stats(user, 'W11_GRP')
exec dbms_stats.gather_table_stats(user, 'W11_CUST_SUM')

prompt
prompt week11 준비 완료

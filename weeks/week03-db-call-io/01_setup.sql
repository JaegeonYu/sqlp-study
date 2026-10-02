-- week03 setup: Call·I/O 실습용 테이블, 함수, 인덱스
@@../../common/session_init
@@../../common/gen_big_table

-- 부분범위처리: reg_dt 인덱스
create index if not exists w03_reg_dt_ix on big_table (reg_dt);

-- INSERT 방식 비교용 빈 테이블
drop table if exists w03_target purge;
create table w03_target as select id, cust_id, reg_dt, amount, pad from big_table where 1 = 0;

-- 사용자 정의 함수 호출 비용 비교용 코드 테이블 (grp_id 1..100)
drop table if exists w03_grp purge;
create table w03_grp (
  grp_id   number primary key,
  grp_name varchar2(30) not null
);
insert into w03_grp select level, 'GROUP-' || lpad(level, 3, '0') from dual connect by level <= 100;
commit;

create or replace function w03_grp_name (p_grp_id number) return varchar2
is
  l_name w03_grp.grp_name%type;
begin
  select grp_name into l_name from w03_grp where grp_id = p_grp_id;
  return l_name;
end;
/

-- 멀티 블록 읽기 실습용 중간 크기 테이블 (약 1,000블록 → 버퍼 캐시를 거쳐 읽힐 크기)
drop table if exists w03_scan purge;
create table w03_scan as select * from big_table where id <= 50000;

exec dbms_stats.gather_table_stats(user, 'W03_SCAN')
exec dbms_stats.gather_table_stats(user, 'W03_GRP')

-- 챌린지용 계좌 테이블
@@reset_acct

prompt
prompt week03 준비 완료

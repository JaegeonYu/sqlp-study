-- week01 setup: 블록/버퍼캐시 실습용 인덱스 + 트랜잭션/Lock 실습용 작은 테이블
@@../../common/session_init
@@../../common/gen_big_table

-- cust_id: 같은 값이 연속 저장 / rnd_id: 무작위 저장
create index if not exists w01_cust_ix on big_table (cust_id);
create index if not exists w01_rnd_ix  on big_table (rnd_id);

-- 읽기 일관성, 행 Lock, 데드락 실습
drop table if exists w01_acct purge;
create table w01_acct (
  acct_no number primary key,
  owner   varchar2(20),
  balance number not null
);
insert into w01_acct
select level, 'CUST' || level, 1000 * level from dual connect by level <= 5;

-- FK 컬럼에 인덱스가 없는 부모/자식 → TM Lock 실습
drop table if exists w01_child  purge;
drop table if exists w01_parent purge;
create table w01_parent (
  parent_id number primary key,
  name      varchar2(20)
);
create table w01_child (
  child_id  number primary key,
  parent_id number references w01_parent,
  qty       number
);
insert into w01_parent select level, 'P' || level from dual connect by level <= 10;
-- parent_id 1~9만 자식이 있음. 10번 부모는 자식이 없다.
insert into w01_child  select level, mod(level, 9) + 1, level from dual connect by level <= 100;

-- Redo/Undo 비교용 빈 테이블
drop table if exists w01_copy purge;
create table w01_copy as select * from big_table where 1 = 0;

commit;

prompt
prompt week01 준비 완료

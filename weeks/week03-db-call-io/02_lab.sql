-- week03 lab: DB Call 최소화, I/O 효율화
--   실행: bash scripts/run.sh weeks/week03-db-call-io/02_lab.sql
@@../../common/session_init

prompt
prompt ===== [1] arraysize: 한 번의 Fetch Call로 몇 건씩 가져오나 =====
prompt     같은 10,000건(id 1..10000)을 arraysize만 바꿔 끝까지 fetch 한다 (AUTOTRACE statistics)
set autotrace traceonly statistics
prompt --- arraysize 2
set arraysize 2
select * from big_table where id <= 10000;
prompt --- arraysize 15 (SQL*Plus 기본값)
set arraysize 15
select * from big_table where id <= 10000;
prompt --- arraysize 100
set arraysize 100
select * from big_table where id <= 10000;
prompt --- arraysize 1000
set arraysize 1000
select * from big_table where id <= 10000;
set autotrace off
set arraysize 15
prompt 관찰: SQL*Net roundtrips 는 대략 10,000 / arraysize 인가? consistent gets 도 함께 줄어드는 이유는?
prompt       (한 Fetch가 끝나면 블록을 놓고, 다음 Fetch에서 같은 블록을 다시 읽는다. 블록당 약 50행)

prompt
prompt ===== [2] 10,000건 INSERT: 한 건씩 + 매번 커밋 vs FORALL vs INSERT ... SELECT =====
truncate table w03_target;
prompt --- [2-a] 커서 루프로 한 건씩 INSERT, 매 건 COMMIT
@@stat_begin
set timing on
begin
  for r in (select id, cust_id, reg_dt, amount, pad from big_table where id <= 10000) loop
    insert into w03_target (id, cust_id, reg_dt, amount, pad)
    values (r.id, r.cust_id, r.reg_dt, r.amount, r.pad);
    commit;
  end loop;
end;
/
set timing off
@@stat_end

truncate table w03_target;
prompt --- [2-b] BULK COLLECT + FORALL, 마지막에 한 번 COMMIT
@@stat_begin
set timing on
declare
  type t_rows is table of w03_target%rowtype;
  l_rows t_rows;
begin
  select id, cust_id, reg_dt, amount, pad
  bulk collect into l_rows
  from big_table where id <= 10000;

  forall i in 1 .. l_rows.count
    insert into w03_target values l_rows(i);
  commit;
end;
/
set timing off
@@stat_end

truncate table w03_target;
prompt --- [2-c] INSERT ... SELECT 한 번
@@stat_begin
set timing on
insert into w03_target (id, cust_id, reg_dt, amount, pad)
select id, cust_id, reg_dt, amount, pad from big_table where id <= 10000;
commit;
set timing off
@@stat_end
prompt 관찰: execute count, recursive calls, user commits, redo size, Elapsed 를 표로 비교하자.
prompt       PL/SQL은 DB 안에서 돌기 때문에 user calls 는 거의 같다. 이 루프가 Java 같은 애플리케이션에 있었다면 user calls 와 roundtrips 는?

prompt
prompt ===== [3] 부분범위처리: 첫 10건만 필요할 때 =====
prompt --- [3-a] 인덱스 순서대로 읽다가 10건에서 멈춤
select /*+ index(b w03_reg_dt_ix) */ id, reg_dt, amount
from   big_table b
where  reg_dt >= date '2022-01-01'
order  by reg_dt
fetch  first 10 rows only;
@@../../common/xplan
prompt --- [3-b] 전부 읽고 정렬한 뒤 10건
select /*+ full(b) */ id, reg_dt, amount
from   big_table b
where  reg_dt >= date '2022-01-01'
order  by reg_dt
fetch  first 10 rows only;
@@../../common/xplan
prompt 관찰: [3-a]에 SORT 오퍼레이션이 있나? STOPKEY 가 붙은 단계의 A-Rows 와 Buffers 를 비교하자.
prompt       화면에 첫 페이지만 보여주는 온라인 조회에서 이 차이가 왜 중요한가?

prompt
prompt ===== [4] SELECT 절의 사용자 정의 함수: 행마다 SQL이 한 번씩 돈다 =====
prompt --- [4-a] 함수를 10만 번 호출
@@stat_begin
set timing on
select sum(length(w03_grp_name(grp_id))) as total_len
from   big_table
where  id <= 100000;
set timing off
@@stat_end

prompt --- [4-b] 스칼라 서브쿼리로 감싸기 (스칼라 서브쿼리 캐싱)
@@stat_begin
set timing on
select sum(length((select w03_grp_name(grp_id) from dual))) as total_len
from   big_table
where  id <= 100000;
set timing off
@@stat_end

prompt --- [4-c] 조인으로 바꾸기
@@stat_begin
set timing on
select sum(length(g.grp_name)) as total_len
from   big_table b
       join w03_grp g on g.grp_id = b.grp_id
where  b.id <= 100000;
set timing off
@@stat_end
prompt 관찰: 세 방식의 결과는 같은가? recursive calls 와 Elapsed 를 비교하자.
prompt       [4-b]의 recursive calls 가 100 근처라면, grp_id 가 100가지뿐이라는 사실과 어떻게 연결되나?

prompt
prompt ===== [5] 멀티 블록 읽기: db_file_multiblock_read_count =====
column orig_mbrc new_value orig_mbrc noprint
select value as orig_mbrc from v$parameter where name = 'db_file_multiblock_read_count';
select blocks from user_tables where table_name = 'W03_SCAN';

prompt --- [5-a] MBRC = 1 (한 번에 1블록씩)
alter session set db_file_multiblock_read_count = 1;
alter system flush buffer_cache;
@@stat_begin
select /*+ full(s) */ count(*) from w03_scan s;
@@stat_end

prompt --- [5-b] MBRC = 128
alter session set db_file_multiblock_read_count = 128;
alter system flush buffer_cache;
@@stat_begin
select /*+ full(s) */ count(*) from w03_scan s;
@@stat_end
alter session set db_file_multiblock_read_count = &orig_mbrc;
prompt 관찰: physical reads(블록 수)는 비슷한데 physical read total IO requests(요청 횟수)는 어떻게 다른가?
prompt       physical reads direct 가 나왔다면 버퍼 캐시를 거치지 않은 것이다. 어느 쪽이었나?

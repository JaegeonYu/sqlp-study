-- week02 lab: 예상 계획 vs 실제 계획, V$SQL, 하드 파싱과 바인드 변수, 커서 공유
--   실행: bash scripts/run.sh weeks/week02-perf-tools-library-cache/02_lab.sql
@@../../common/session_init

variable n number
exec :n := 77

prompt
prompt ===== [1] 예상 계획(EXPLAIN PLAN)과 실제 계획(DISPLAY_CURSOR)이 다른 경우 =====
prompt --- [1-a] 예상 계획: EXPLAIN PLAN 은 SQL을 실행하지 않고, 바인드 변수를 문자형으로 가정한다
explain plan for
select * from w02_cust where cust_code = :n;
set pagesize 0
set heading off
set feedback off
select plan_table_output from table(dbms_xplan.display(null, null, 'TYPICAL'));
set pagesize 100
set heading on
set feedback on

prompt --- [1-b] 실제 계획: :n 은 NUMBER 바인드다
select * from w02_cust where cust_code = :n;
@@../../common/xplan
prompt 관찰: [1-a]와 [1-b]의 Operation 과 Predicate Information 을 비교하자. TO_NUMBER 는 어느 쪽 컬럼에 씌워졌나?
prompt       실행계획 도구가 "실행 전 예상"인지 "실행 후 실제"인지 항상 구분해야 하는 이유는?

prompt
prompt ===== [2] AUTOTRACE: traceonly explain vs traceonly statistics =====
prompt --- [2-a] traceonly explain
set autotrace traceonly explain
select * from w02_cust where cust_code = :n;
prompt --- [2-b] traceonly statistics
set autotrace traceonly statistics
select * from w02_cust where cust_code = :n;
set autotrace off
prompt 관찰: [2-a]의 계획은 [1-a]와 [1-b] 중 어느 쪽과 같은가? [2-b]의 consistent gets 는 인덱스로 1건 읽는 양으로 보이는가?

prompt
prompt ===== [3] V$SQL: 실행 횟수, 파싱 횟수, 자식 커서 =====
alter system flush shared_pool;
select /* w02_q3 */ count(*) from w02_cust where grade = 1;
select /* w02_q3 */ count(*) from w02_cust where grade = 1;
select /* w02_q3 */ count(*) from w02_cust where grade = 1;
@@helper_sqlstat w02_q3
prompt --- 옵티마이저 환경을 바꿔 같은 SQL을 실행
alter session set optimizer_mode = first_rows_10;
select /* w02_q3 */ count(*) from w02_cust where grade = 1;
alter session set optimizer_mode = all_rows;
@@helper_sqlstat w02_q3
prompt 관찰: SQL 텍스트가 같은데 커서(child)가 왜 하나 더 생겼나? execs 와 parses 는 각각 몇인가?
prompt       (자식 커서가 생긴 이유는 V$SQL_SHARED_CURSOR 에서 볼 수 있다)

prompt
prompt ===== [4] 리터럴 SQL 2,000회 vs 바인드 SQL 2,000회 =====
alter system flush shared_pool;
prompt --- [4-a] 리터럴: 'where id = 1', 'where id = 2', ... 매번 다른 SQL
@@parse_begin
set timing on
declare
  l_amt number;
begin
  for i in 1 .. 2000 loop
    execute immediate 'select /* w02_lit */ amount from big_table where id = ' || i into l_amt;
  end loop;
end;
/
set timing off
@@parse_end
@@helper_sqlstat w02_lit

prompt --- [4-b] 바인드: 'where id = :x' 하나의 SQL
@@parse_begin
set timing on
declare
  l_amt number;
begin
  for i in 1 .. 2000 loop
    execute immediate 'select /* w02_bind */ amount from big_table where id = :x' into l_amt using i;
  end loop;
end;
/
set timing off
@@parse_end
@@helper_sqlstat w02_bind
prompt 관찰: parse count (hard), parse time elapsed, Elapsed 시간, V$SQL 커서 수(cursors)를 비교하자.
prompt       같은 일을 하는데 리터럴 방식이 공유 풀(라이브러리 캐시)에 남긴 흔적은 몇 개인가?

prompt
prompt ===== [5] cursor_sharing = force: 리터럴을 시스템이 바인드로 바꿔준다 =====
alter session set cursor_sharing = force;
@@parse_begin
declare
  l_amt number;
begin
  for i in 1 .. 2000 loop
    execute immediate 'select /* w02_force */ amount from big_table where id = ' || i into l_amt;
  end loop;
end;
/
@@parse_end
alter session set cursor_sharing = exact;
@@helper_sqlstat w02_force
prompt 관찰: sql_text 의 숫자 자리에 무엇이 들어갔나? hard parse 는 [4-a]와 비교해 어떤가?
prompt       그런데도 cursor_sharing=force 를 근본 해결책으로 권하지 않는 이유는? (힌트: 일부러 리터럴을 쓴 SQL, 히스토그램)

prompt
prompt ===== [6] session_cached_cursors: 소프트 파싱을 더 가볍게 =====
prompt     DBMS_SQL로 매번 open → parse → execute → close 하는 1,000회 루프 (같은 SQL, 바인드 사용)
column orig_scc new_value orig_scc noprint
select value as orig_scc from v$parameter where name = 'session_cached_cursors';

prompt --- [6-a] session_cached_cursors = 0
alter session set session_cached_cursors = 0;
@@parse_begin
declare
  c     integer;
  n     integer;
  l_amt number;
begin
  for i in 1 .. 1000 loop
    c := dbms_sql.open_cursor;
    dbms_sql.parse(c, 'select /* w02_scc */ amount from big_table where id = :x', dbms_sql.native);
    dbms_sql.bind_variable(c, ':x', i);
    dbms_sql.define_column(c, 1, l_amt);
    n := dbms_sql.execute_and_fetch(c);
    dbms_sql.column_value(c, 1, l_amt);
    dbms_sql.close_cursor(c);
  end loop;
end;
/
@@parse_end

prompt --- [6-b] session_cached_cursors = 50
alter session set session_cached_cursors = 50;
@@parse_begin
declare
  c     integer;
  n     integer;
  l_amt number;
begin
  for i in 1 .. 1000 loop
    c := dbms_sql.open_cursor;
    dbms_sql.parse(c, 'select /* w02_scc */ amount from big_table where id = :x', dbms_sql.native);
    dbms_sql.bind_variable(c, ':x', i);
    dbms_sql.define_column(c, 1, l_amt);
    n := dbms_sql.execute_and_fetch(c);
    dbms_sql.column_value(c, 1, l_amt);
    dbms_sql.close_cursor(c);
  end loop;
end;
/
@@parse_end
alter session set session_cached_cursors = &orig_scc;
prompt 관찰: 두 경우 모두 parse count (total) 은 약 1,000 이다. session cursor cache hits 는 어떻게 다른가?
prompt       하드 파싱 / 소프트 파싱 / 세션 커서 캐시 히트 / 아예 파싱하지 않음(커서 재사용)을 비용 순서로 정리해 보자.

prompt
prompt ===== [7] SQL 트레이스: Misses in library cache =====
alter system flush shared_pool;
@@../../common/trace_on week02
declare
  l_amt number;
begin
  for i in 1 .. 20 loop
    execute immediate 'select /* w02_tlit */ amount from big_table where id = ' || i into l_amt;
    execute immediate 'select /* w02_tbind */ amount from big_table where id = :x' into l_amt using i;
  end loop;
end;
/
@@../../common/trace_off
prompt 관찰: bash scripts/tkprof.sh week02 결과에서 w02_tlit 와 w02_tbind 의
prompt       "Misses in library cache during parse" 와 Parse/Execute 횟수를 비교하자.

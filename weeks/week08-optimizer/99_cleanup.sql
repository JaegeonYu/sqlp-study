-- week08 cleanup: 실습 객체 제거 + BIG_TABLE 통계 원복(히스토그램 제거)
@@../../common/session_init
alter session set optimizer_mode = all_rows;
alter session set optimizer_adaptive_plans = true;

drop index if exists w08_rnd_ix;
drop table if exists w08_orders purge;
drop table if exists w08_addr   purge;
drop table if exists w08_cust   purge;
drop table if exists w08_nostat purge;
drop table if exists w08_rts    purge;

exec dbms_stats.gather_table_stats(user, 'BIG_TABLE', method_opt => 'for all columns size 1', cascade => true, no_invalidate => false)

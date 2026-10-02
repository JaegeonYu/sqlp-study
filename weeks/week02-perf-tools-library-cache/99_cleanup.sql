-- week02 cleanup (BIG_TABLE은 유지)
@@../../common/session_init
alter session set cursor_sharing = exact;
alter session set optimizer_mode = all_rows;
drop table if exists w02_cust purge;

-- week04 cleanup (BIG_TABLE은 유지)
@@../../common/session_init
drop index if exists w04_reg_dt_ix;
drop index if exists w04_status_dt_ix;
drop table if exists w04_code purge;

-- week05 cleanup (BIG_TABLE은 유지)
@@../../common/session_init
drop index if exists w05_cust_ix;
drop index if exists w05_rnd_ix;
drop index if exists w05_grp_dt_ix;
drop index if exists w05_dt_grp_ix;
drop index if exists w05_rnd_amt_ix;
drop table if exists w05_heap  purge;
drop table if exists w05_iot   purge;
drop table if exists w05_order purge;

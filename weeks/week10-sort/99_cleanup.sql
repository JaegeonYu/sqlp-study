-- week10 cleanup (BIG_TABLE은 유지)
@@../../common/session_init
alter session set workarea_size_policy = auto;
drop index if exists w10_grp_amt_ix;
drop table if exists w10_grp  purge;
drop table if exists w10_post purge;

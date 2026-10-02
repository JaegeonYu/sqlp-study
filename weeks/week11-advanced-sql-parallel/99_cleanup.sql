-- week11 cleanup (BIG_TABLE은 유지)
@@../../common/session_init
rollback;
alter session disable parallel dml;
drop index if exists w11_cust_amt_ix;
drop table if exists w11_grp      purge;
drop table if exists w11_cust_sum purge;
drop table if exists w11_copy     purge;

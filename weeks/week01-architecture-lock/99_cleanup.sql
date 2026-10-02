-- week01 cleanup (BIG_TABLE은 유지)
@@../../common/session_init
drop index if exists w01_cust_ix;
drop index if exists w01_rnd_ix;
drop table if exists w01_copy   purge;
drop table if exists w01_child  purge;
drop table if exists w01_parent purge;
drop table if exists w01_acct   purge;

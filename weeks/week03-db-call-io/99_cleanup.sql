-- week03 cleanup (BIG_TABLE은 유지)
@@../../common/session_init
drop index    if exists w03_reg_dt_ix;
drop function if exists w03_grp_name;
drop table    if exists w03_target purge;
drop table    if exists w03_grp    purge;
drop table    if exists w03_scan   purge;
drop table    if exists w03_acct   purge;

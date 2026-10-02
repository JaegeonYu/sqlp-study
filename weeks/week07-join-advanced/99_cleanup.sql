-- week07 cleanup (BIG_TABLE은 유지)
--   챌린지에서 각자 만든 W07_ 인덱스까지 모두 지운다.
@@../../common/session_init
begin
  for r in (select index_name from user_indexes
            where  table_name = 'BIG_TABLE'
            and    index_name like 'W07\_%' escape '\') loop
    execute immediate 'drop index ' || r.index_name;
  end loop;
end;
/
drop function if exists w07_grp_rate;
drop function if exists w07_cust_pts;
drop function if exists w07_grp_nm;
drop package  if exists w07_cnt;
drop table if exists w07_cust        purge;
drop table if exists w07_grp         purge;
drop table if exists w07_blacklist   purge;
drop table if exists w07_daily_sales purge;
drop table if exists w07_grade_hist  purge;
drop table if exists w07_copy_t      purge;

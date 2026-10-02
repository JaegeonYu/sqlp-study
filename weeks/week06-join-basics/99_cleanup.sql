-- week06 cleanup (BIG_TABLE은 유지)
--   챌린지에서 각자 만든 W06_ 인덱스까지 모두 지운다.
@@../../common/session_init
begin
  for r in (select index_name from user_indexes
            where  table_name = 'BIG_TABLE'
            and    index_name like 'W06\_%' escape '\') loop
    execute immediate 'drop index ' || r.index_name;
  end loop;
end;
/
drop table if exists w06_cust   purge;
drop table if exists w06_region purge;

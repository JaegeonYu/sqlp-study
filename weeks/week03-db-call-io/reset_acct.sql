-- 챌린지용 W03_ACCT를 처음 상태로 되돌린다 (Before/After를 같은 데이터에서 측정하기 위해)
--   사용: @@reset_acct   (대화형: @weeks/week03-db-call-io/reset_acct)
drop table if exists w03_acct purge;
create table w03_acct (
  acct_id number primary key,
  cust_id number not null,
  grade   varchar2(1) not null,
  balance number not null,
  upd_dt  date
);
insert into w03_acct (acct_id, cust_id, grade, balance)
select level,
       ceil(level / 10),
       case mod(level, 3) when 0 then 'A' when 1 then 'B' else 'C' end,
       mod(level * 13, 100000)
from   dual
connect by level <= 100000;
commit;
exec dbms_stats.gather_table_stats(user, 'W03_ACCT')

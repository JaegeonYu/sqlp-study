-- week02 setup: 문자형 코드 테이블 (숫자 바인드와 비교하면 묵시적 형변환이 일어난다)
@@../../common/session_init
@@../../common/gen_big_table

drop table if exists w02_cust purge;
create table w02_cust as
select lpad(level, 7, '0')  as cust_code,   -- '0000001' .. '0100000' (VARCHAR2)
       'NAME' || level      as cust_name,
       mod(level, 10)       as grade
from   dual
connect by level <= 100000;

create index w02_cust_code_ix on w02_cust (cust_code);
exec dbms_stats.gather_table_stats(user, 'W02_CUST', cascade => true)

prompt
prompt week02 준비 완료

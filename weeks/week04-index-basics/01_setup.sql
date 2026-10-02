-- week04 setup: 인덱스 스캔 방식 실습용 인덱스 + 문자형 코드 테이블
@@../../common/session_init
@@../../common/gen_big_table

-- BIG_TABLE 인덱스 (99_cleanup에서 제거)
create index if not exists w04_reg_dt_ix    on big_table (reg_dt);
-- 선두 컬럼 status 의 값이 2개뿐 → Index Skip Scan 실습
create index if not exists w04_status_dt_ix on big_table (status, reg_dt);

-- 문자형 코드 테이블 (10만 건)
--   code      : '00000001' ~ '00100000' (VARCHAR2, 숫자처럼 보이는 문자) → 묵시적 형변환 실습
--   name      : 'Name1' ~ 'Name100000' (대소문자 혼합)              → LIKE, 함수 기반 인덱스 실습
--   closed_dt : 1%만 NULL                                             → IS NULL 실습
drop table if exists w04_code purge;
create table w04_code as
select level                                                       as id,
       lpad(level, 8, '0')                                         as code,
       'Name' || level                                             as name,
       case when mod(level, 100) = 0 then null
            else date '2020-01-01' + mod(level, 1000) end          as closed_dt,
       rpad('x', 100, 'x')                                         as pad
from   dual
connect by level <= 100000;

alter table w04_code add constraint w04_code_pk primary key (id);
create index w04_code_ix   on w04_code (code);
create index w04_name_ix   on w04_code (name);
create index w04_closed_ix on w04_code (closed_dt);

exec dbms_stats.gather_table_stats(user, 'W04_CODE', method_opt => 'for all columns size 1', cascade => true)

prompt
prompt week04 준비 완료

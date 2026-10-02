-- 최초 기동 시 SYSDBA로 1회 실행된다.
-- 로컬 학습 전용 계정이므로 비밀번호를 고정(study/study)하고, 튜닝 실습에 필요한 권한을 넉넉히 준다.
whenever sqlerror exit failure
alter session set container = FREEPDB1;

create user study identified by study;

grant create session, create table, create view, create sequence, create procedure,
      create synonym, create materialized view, create type, create trigger,
      unlimited tablespace
   to study;

-- 세션 파라미터 변경(statistics_level, tracefile_identifier, 힌트성 파라미터 등)
grant alter session to study;

-- V$ 뷰, DBA_ 뷰 조회: DBMS_XPLAN.DISPLAY_CURSOR, AUTOTRACE, Lock 조회에 필요
grant select any dictionary to study;

-- flush buffer_cache / shared_pool 실습용 (로컬 샌드박스에서만 부여할 것)
grant alter system to study;

exit

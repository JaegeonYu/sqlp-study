-- week09 cleanup (챌린지에서 만든 w09_ 인덱스는 테이블과 함께 삭제됨)
@@../../common/session_init
drop table if exists w09_emp  purge;
drop table if exists w09_dept purge;

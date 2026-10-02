-- week00 setup: 공통 대용량 테이블(BIG_TABLE)과 이번 주 인덱스 생성
@@../../common/session_init
@@../../common/gen_big_table

create index if not exists w00_reg_dt_ix on big_table (reg_dt);

prompt
prompt week00 준비 완료

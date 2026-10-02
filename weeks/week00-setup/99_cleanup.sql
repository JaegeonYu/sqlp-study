-- week00 cleanup: 이번 주 인덱스 제거 (BIG_TABLE은 다음 주에도 사용하므로 유지)
@@../../common/session_init
drop index if exists w00_reg_dt_ix;

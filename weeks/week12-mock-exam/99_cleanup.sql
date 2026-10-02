-- week12 cleanup: 실기 모의고사 테이블 제거 (풀이 중 만든 인덱스도 테이블과 함께 삭제됨)
@@../../common/session_init
drop table if exists w12_order_item purge;
drop table if exists w12_order      purge;
drop table if exists w12_cust       purge;

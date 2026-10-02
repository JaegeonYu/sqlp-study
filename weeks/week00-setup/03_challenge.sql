-- week00 challenge
--   아래 SQL과 결과는 같으면서 Buffers는 적게 읽는 SQL을 작성하라. 인덱스는 w00_reg_dt_ix만 쓸 수 있다.
--   제출: result.md 2번 (Before / 튜닝 SQL / After / 근거)
@@../../common/session_init

prompt
prompt ===== 원본 SQL =====
select count(*), sum(amount)
from   big_table
where  to_char(reg_dt, 'YYYYMM') = '202305';
@@../../common/xplan
prompt 과제: 인덱스가 있는데 왜 쓰이지 않았는지 설명하고, 결과는 같게 유지한 채 Buffers 를 줄여라.

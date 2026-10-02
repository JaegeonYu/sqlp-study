-- week03 challenge
--   등급 'B' 계좌의 잔액을 1% 올리고 수정일을 기록하는 배치다. 커서 루프로 한 건씩 UPDATE 한다.
--   결과(마지막 검증 쿼리)는 같게 유지하고 Call 수·Redo·시간을 줄여라.
--   측정 순서: @@reset_acct → 원본 실행 → @@reset_acct → 내 SQL 실행 (같은 데이터에서 비교)
--   제출: result.md 2번에 Before/After 의 execute count, recursive calls, redo size, Elapsed, 검증 쿼리 결과
@@../../common/session_init

@@reset_acct

prompt
prompt ===== 원본 배치 =====
@@stat_begin
set timing on
begin
  for r in (select acct_id from w03_acct where grade = 'B') loop
    update w03_acct
    set    balance = round(balance * 1.01, 2),
           upd_dt  = date '2026-01-01'
    where  acct_id = r.acct_id;
  end loop;
  commit;
end;
/
set timing off
@@stat_end

prompt
prompt ===== 검증 쿼리 (튜닝 후에도 같은 값이 나와야 한다) =====
select count(*) as upd_cnt, sum(balance) as total_balance
from   w03_acct
where  upd_dt = date '2026-01-01';
prompt 과제: 원본은 SQL을 몇 번 실행했나? 같은 결과를 내는 방법을 찾고 수치로 비교하라.

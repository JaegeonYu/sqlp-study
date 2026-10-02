-- week02 challenge
--   아래 PL/SQL 배치는 100건 구간 합계를 3,000번 조회해 더한다. 결과(:total)는 같게 유지하고
--   하드 파싱과 소요 시간을 줄이도록 고쳐라. (SQL 한 번으로 바꾸는 것도 좋지만, 이번 주 과제는
--   "동적 SQL 구조는 유지한 채" 바인드 변수로 바꾸는 것이다. 집합 처리는 다음 주 주제)
--   제출: result.md 2번에 Before/After 의 parse count (hard), parse time elapsed, Elapsed, :total
@@../../common/session_init

variable total number
alter system flush shared_pool;

prompt
prompt ===== 원본 배치 =====
@@parse_begin
set timing on
declare
  l_amt number;
  l_sum number := 0;
begin
  for i in 1 .. 3000 loop
    execute immediate
      'select /* w02_chal */ sum(amount) from big_table where id between '
      || (i * 100 - 99) || ' and ' || (i * 100)
      into l_amt;
    l_sum := l_sum + l_amt;
  end loop;
  :total := l_sum;
end;
/
set timing off
@@parse_end
@@helper_sqlstat w02_chal
print total
prompt 과제: 하드 파싱이 몇 번 일어났고 공유 풀에 커서가 몇 개 남았나? 바인드 방식으로 고친 뒤 같은 표로 비교하라.

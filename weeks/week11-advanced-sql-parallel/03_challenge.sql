-- week11 challenge: 월별 리포트 SQL을 한 번 스캔으로
--   2023년 월별로 (전체 건수, status='N' 건수, grp_id 1~10 금액 합계)를 보여주는 리포트다.
--   원본은 같은 BIG_TABLE 을 세 번 읽어 조인한다.
--   과제: 결과(12행, 컬럼과 값, 정렬 순서)는 같게 유지하고 BIG_TABLE 을 한 번만 읽도록 다시 써라. 인덱스는 추가하지 않는다.
--   제출: result.md 2번 (Before / 튜닝 SQL / After / 근거)
@@../../common/session_init

prompt
prompt ===== 원본 SQL =====
select a.mon, a.total_cnt, b.n_cnt, c.grp_amt
from  (select to_char(reg_dt, 'YYYY-MM') as mon, count(*) as total_cnt
       from   big_table
       where  reg_dt >= date '2023-01-01' and reg_dt < date '2024-01-01'
       group  by to_char(reg_dt, 'YYYY-MM')) a,
      (select to_char(reg_dt, 'YYYY-MM') as mon, count(*) as n_cnt
       from   big_table
       where  status = 'N'
       and    reg_dt >= date '2023-01-01' and reg_dt < date '2024-01-01'
       group  by to_char(reg_dt, 'YYYY-MM')) b,
      (select to_char(reg_dt, 'YYYY-MM') as mon, sum(amount) as grp_amt
       from   big_table
       where  grp_id <= 10
       and    reg_dt >= date '2023-01-01' and reg_dt < date '2024-01-01'
       group  by to_char(reg_dt, 'YYYY-MM')) c
where  b.mon = a.mon
and    c.mon = a.mon
order  by a.mon;
@@../../common/xplan
prompt 과제: BIG_TABLE 을 몇 번 읽고 있는가? 한 번 스캔으로 바꾼 뒤 Buffers 와 A-Time 을 비교하라.
prompt       추가 질문: 만약 어떤 달에 status='N' 이 한 건도 없다면 원본과 튜닝 SQL의 결과가 달라질까?

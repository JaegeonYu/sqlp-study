-- week07 challenge: 리포트 SQL 을 한 번의 스캔으로
--   2023년 1월 그룹별 매출 리포트. 그룹명, 1월 매출·건수, 전체 대비 비중(%), 전월(2022-12) 매출.
--   아래 원본은 같은 BIG_TABLE 을 여러 번 읽는다 (인라인 뷰 2개 + 스칼라 서브쿼리 3개 + 함수 호출).
--   결과(100행)는 같게 유지하고 BIG_TABLE 을 한 번만 읽도록 다시 작성하라.
--   - 인덱스 추가 없이 SQL 만 바꾼다
--   - 제출: Before/After Buffers, BIG_TABLE 스캔 횟수(실행계획에서 Starts 합계), 사용한 기법(조건부 집계, 윈도우 함수 등)
@@../../common/session_init

prompt
prompt ===== 원본 SQL =====
exec w07_cnt.reset
set feedback only
select a.grp_id,
       w07_grp_nm(a.grp_id)                                            as grp_nm,
       a.amt,
       (select count(*)
        from   big_table y
        where  y.grp_id = a.grp_id
        and    y.reg_dt between date '2023-01-01' and date '2023-01-31') as cnt,
       round(a.amt * 100 /
             (select sum(z.amount)
              from   big_table z
              where  z.reg_dt between date '2023-01-01' and date '2023-01-31'), 2) as pct,
       p.amt                                                           as prev_amt
from   (select grp_id, sum(amount) as amt
        from   big_table
        where  reg_dt between date '2023-01-01' and date '2023-01-31'
        group  by grp_id) a,
       (select b2.grp_id, sum(b2.amount) as amt
        from   big_table b2, big_table b3
        where  b3.id = b2.id
        and    b2.reg_dt between date '2022-12-01' and date '2022-12-31'
        group  by b2.grp_id) p
where  p.grp_id = a.grp_id
order  by a.grp_id;
set feedback on
@@../../common/xplan
select w07_cnt.calls as fn_calls from dual;
prompt 과제: BIG_TABLE 을 몇 번 읽었는가? 2022-12-01 ~ 2023-01-31 구간을 한 번만 읽고 같은 결과를 만들어라.

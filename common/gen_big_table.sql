-- 공통 대용량 테이블 BIG_TABLE (100만 건, 약 160MB). 이미 있으면 건너뛴다.
--
-- 여러 주차에서 재사용하도록 컬럼마다 분포를 의도적으로 설계했다.
--   id      : 1..1,000,000 PK. 입력 순서 = 저장 순서
--   cust_id : 1..10,000. 같은 값 100건이 연속 저장 → 클러스터링 팩터 좋음
--   rnd_id  : 1..10,000. 무작위 저장           → 클러스터링 팩터 나쁨
--   grp_id  : 1..100. mod 로 균등 분산          → 선택도 1%, 값마다 전 블록에 흩어짐
--   status  : 'Y' 99% / 'N' 1%                  → 분포 편중 (히스토그램 실습)
--   reg_dt  : 2022-01-01부터 하루 1,000건씩 1,000일, 날짜순 저장
--   amount  : 0..9,999
--   pad     : 행 길이 확보 (블록당 약 50행)
--
-- 규칙: BIG_TABLE에는 PK만 유지한다. 주차별 인덱스는 wNN_ 접두어로 만들고 99_cleanup.sql에서 지운다.
-- 통계는 히스토그램 없이(size 1) 수집한다. 히스토그램은 옵티마이저 주차에서 직접 만든다.

prompt BIG_TABLE 준비 중 (최초 1회 1~3분)...
declare
  l_cnt number;
begin
  select count(*) into l_cnt from user_tables where table_name = 'BIG_TABLE';
  if l_cnt = 0 then
    dbms_random.seed(20261002);
    execute immediate q'[
      create table big_table as
      select n                                            as id,
             ceil(n / 100)                                as cust_id,
             trunc(dbms_random.value(1, 10001))           as rnd_id,
             mod(n, 100) + 1                              as grp_id,
             case when mod(n, 100) = 0 then 'N' else 'Y' end as status,
             date '2022-01-01' + trunc((n - 1) / 1000)    as reg_dt,
             mod(n * 7, 10000)                            as amount,
             rpad('x', 100, 'x')                          as pad
      from  (select (a.n - 1) * 1000 + b.n as n
             from   (select level n from dual connect by level <= 1000) a,
                    (select level n from dual connect by level <= 1000) b)
      order by n
    ]';
    execute immediate 'alter table big_table add constraint big_table_pk primary key (id)';
    dbms_stats.gather_table_stats(user, 'BIG_TABLE', method_opt => 'for all columns size 1', cascade => true);
  end if;
end;
/

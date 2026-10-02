-- week05 헬퍼: 인덱스 손익분기점 측정
--   rnd_id(CF 나쁨) 인덱스 / FULL / cust_id(CF 좋음) 인덱스 로 같은 비율의 데이터를 읽고
--   session logical reads 증가량과 경과 시간(ms)을 표로 출력한다.
--   02_lab.sql [3] 에서 호출. 단독 실행: @breakeven
set serveroutput on size unlimited
declare
  type t_num is table of number;
  l_pct t_num := t_num(0.1, 1, 2, 5, 10, 20);   -- 전체 100만 건 대비 비율(%)
  l_hi  number;
  l_lio number;
  l_ms  number;
  l_line varchar2(400);

  function lio return number is
    v number;
  begin
    select m.value into v
    from   v$mystat m join v$statname s on s.statistic# = m.statistic#
    where  s.name = 'session logical reads';
    return v;
  end;

  procedure run(p_sql varchar2, p_hi number, o_lio out number, o_ms out number) is
    l0 number;
    t0 number;
    v  number;
  begin
    l0 := lio;
    t0 := dbms_utility.get_time;
    execute immediate p_sql into v using p_hi;
    o_ms  := (dbms_utility.get_time - t0) * 10;
    o_lio := lio - l0;
  end;
begin
  dbms_output.put_line('pct(%) | rows(approx) | rnd_ix LIO |  rnd_ix ms |   FULL LIO |    FULL ms | cust_ix LIO | cust_ix ms');
  dbms_output.put_line('-------+--------------+------------+------------+------------+------------+-------------+-----------');
  for i in 1 .. l_pct.count loop
    l_hi   := 10000 * l_pct(i) / 100;                 -- rnd_id, cust_id 모두 1..10,000
    l_line := to_char(l_pct(i), '9990.0') || ' | ' || lpad(1000000 * l_pct(i) / 100, 12);

    run('select /*+ index(b w05_rnd_ix) */ sum(amount) from big_table b where rnd_id between 1 and :1', l_hi, l_lio, l_ms);
    l_line := l_line || ' | ' || lpad(l_lio, 10) || ' | ' || lpad(l_ms, 10);

    run('select /*+ full(b) */ sum(amount) from big_table b where rnd_id between 1 and :1', l_hi, l_lio, l_ms);
    l_line := l_line || ' | ' || lpad(l_lio, 10) || ' | ' || lpad(l_ms, 10);

    run('select /*+ index(b w05_cust_ix) */ sum(amount) from big_table b where cust_id between 1 and :1', l_hi, l_lio, l_ms);
    l_line := l_line || ' | ' || lpad(l_lio, 11) || ' | ' || lpad(l_ms, 10);

    dbms_output.put_line(l_line);
  end loop;
end;
/
set serveroutput off

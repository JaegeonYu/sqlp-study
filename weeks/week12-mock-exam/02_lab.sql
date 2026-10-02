-- week12 lab: 문제를 풀기 전에 데이터 분포와 통계, 인덱스를 먼저 확인한다
--   실기 시험에서는 이 정보가 문제지에 표로 주어진다. 여기서는 직접 조회해서 표를 만들어 본다.
@@../../common/session_init

prompt
prompt ===== [1] 테이블 규모 =====
column table_name format a16
select table_name, num_rows, blocks, avg_row_len
from   user_tables
where  table_name like 'W12%'
order  by table_name;

prompt
prompt ===== [2] 컬럼 통계 (NDV, NULL, 히스토그램 여부) =====
column column_name format a12
column histogram   format a10
select table_name, column_name, num_distinct, num_nulls, histogram
from   user_tab_col_statistics
where  table_name like 'W12%'
order  by table_name, column_name;
prompt 관찰: 히스토그램이 없을 때 cust_grade = 'VIP' 의 예상 건수는 몇 건일까? 실제는 100건이다.

prompt
prompt ===== [3] 인덱스 목록 =====
column index_name  format a20
column columns     format a30
select i.table_name, i.index_name, i.uniqueness,
       listagg(c.column_name, ', ') within group (order by c.column_position) as columns,
       i.blevel, i.leaf_blocks, i.clustering_factor
from   user_indexes i
       join user_ind_columns c on c.index_name = i.index_name
where  i.table_name like 'W12%'
group  by i.table_name, i.index_name, i.uniqueness, i.blevel, i.leaf_blocks, i.clustering_factor
order  by i.table_name, i.index_name;
prompt 관찰: w12_order_dt_ix 의 clustering_factor 는 테이블 블록 수에 가까운가, 행 수에 가까운가? 왜 그럴까?

prompt
prompt ===== [4] 값 분포 =====
prompt --- 고객 등급
select cust_grade, count(*) as cnt from w12_cust group by cust_grade order by cnt;
prompt --- 주문 상태
select status, count(*) as cnt from w12_order group by status order by cnt;
prompt --- 월별 주문 건수
select to_char(order_dt, 'YYYY-MM') as mon, count(*) as cnt
from   w12_order
group  by to_char(order_dt, 'YYYY-MM')
order  by mon;
prompt --- 고객 1명당 주문 건수 / 주문 1건당 상세 건수
select round(count(*) / count(distinct cust_id), 1) as orders_per_cust from w12_order;
select round(count(*) / count(distinct order_id), 1) as items_per_order from w12_order_item;
prompt 관찰: VIP 고객의 최근 3개월 주문은 대략 몇 건일까? 하루 주문은 몇 건, 하루 주문의 상세는 몇 건일까? 계산 결과를 문제 풀이의 근거로 써라.

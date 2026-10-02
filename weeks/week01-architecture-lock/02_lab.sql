-- week01 lab (단일 세션): 블록 I/O, 버퍼 캐시, Redo/Undo
--   여러 세션으로 하는 읽기 일관성·Lock 실습은 README의 "멀티 세션 실습"을 따른다.
@@../../common/session_init

prompt
prompt ===== [1] 같은 100건, 몇 개의 블록에 흩어져 있나 =====
select 'cust_id = 77' as cond,
       count(*)                                                   as row_cnt,
       count(distinct dbms_rowid.rowid_relative_fno(rowid) || '.' ||
                      dbms_rowid.rowid_block_number(rowid))       as block_cnt
from   big_table
where  cust_id = 77
union all
select 'rnd_id = 77',
       count(*),
       count(distinct dbms_rowid.rowid_relative_fno(rowid) || '.' ||
                      dbms_rowid.rowid_block_number(rowid))
from   big_table
where  rnd_id = 77;
prompt 관찰: 건수는 비슷한데 블록 수는 몇 배 차이 나는가? 오라클은 행이 아니라 블록 단위로 읽는다.

prompt
prompt ===== [2] 블록이 흩어진 만큼 I/O도 늘어난다 =====
set feedback only
select /*+ index(b w01_cust_ix) */ * from big_table b where cust_id = 77;
set feedback on
@@../../common/xplan
set feedback only
select /*+ index(b w01_rnd_ix) */ * from big_table b where rnd_id = 77;
set feedback on
@@../../common/xplan
prompt 관찰: TABLE ACCESS BY INDEX ROWID 단계의 Buffers 차이 = [1]의 block_cnt 차이인가?

prompt
prompt ===== [3] 버퍼 캐시: 논리 I/O는 그대로, 물리 I/O만 사라진다 =====
alter system flush buffer_cache;
prompt --- [3-a] 캐시를 비운 직후
@@../../common/mystat_begin
select /*+ index(b w01_rnd_ix) */ sum(amount) from big_table b where rnd_id between 100 and 119;
@@../../common/mystat_end
prompt --- [3-b] 같은 SQL 재실행
@@../../common/mystat_begin
select /*+ index(b w01_rnd_ix) */ sum(amount) from big_table b where rnd_id between 100 and 119;
@@../../common/mystat_end
prompt 관찰: physical reads 는 사라졌는데 session logical reads 는 그대로다. 튜닝 목표가 히트율이 아니라 논리 I/O 인 이유는?

prompt
prompt ===== [4] 대용량 FULL 스캔은 버퍼 캐시를 거치지 않을 수 있다 =====
alter system flush buffer_cache;
prompt --- [4-a] 1회차
@@../../common/mystat_begin
select /*+ full(b) */ count(*) from big_table b;
@@../../common/mystat_end
prompt --- [4-b] 2회차
@@../../common/mystat_begin
select /*+ full(b) */ count(*) from big_table b;
@@../../common/mystat_end
prompt 관찰: 2회차에도 physical reads direct 가 나오는가? (11g 이후 Serial Direct Path Read. 책의 "Full Scan은 LRU 끝에 적재" 설명과 비교)

prompt
prompt ===== [5] UPDATE 1,000건이 남기는 Redo와 Undo =====
@@../../common/mystat_begin
update big_table set amount = amount + 1 where cust_id between 1 and 10;
@@../../common/mystat_end
rollback;
prompt 관찰: redo size, undo change vector size. 롤백은 Undo로 무엇을 되돌리는가?

prompt
prompt ===== [6] 일반 INSERT vs Direct Path INSERT (10만 건) =====
prompt --- [6-a] conventional
@@../../common/mystat_begin
insert into w01_copy select * from big_table where id <= 100000;
@@../../common/mystat_end
commit;
truncate table w01_copy;
prompt --- [6-b] direct path (append)
@@../../common/mystat_begin
insert /*+ append */ into w01_copy select * from big_table where id <= 100000;
@@../../common/mystat_end
commit;
prompt 관찰: redo size, undo 차이는 몇 배인가? 이 DB는 NOARCHIVELOG 모드다. ARCHIVELOG 운영 DB에서도 같을까?

prompt
prompt ===== [7] Lock 조회 도구 미리 보기 =====
@@../../common/locks
prompt 지금은 다른 세션이 없어서 비어 있다. 멀티 세션 실습에서 세 번째 터미널로 실행한다.

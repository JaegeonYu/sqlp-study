-- week10 setup: 소트 튜닝 실습용 인덱스, 그룹 코드 테이블, 게시판 테이블
@@../../common/session_init
@@../../common/gen_big_table

-- 인덱스로 소트 생략 / Top-N / 키 기반 페이징 / union 실습용
--   grp_id = :g 조건에서 amount, id 순으로 이미 정렬되어 있다
create index if not exists w10_grp_amt_ix on big_table (grp_id, amount, id);

-- SORT JOIN, distinct vs exists 실습용 그룹 코드 (100건)
drop table if exists w10_grp purge;
create table w10_grp (
  grp_id   number primary key,
  grp_name varchar2(20) not null
);
insert into w10_grp select level, 'GROUP-' || level from dual connect by level <= 100;

-- 챌린지용 게시판 (20만 건, 게시판 20개, 게시판당 1만 건)
--   post_id 순으로 저장, reg_dt 는 post_id 와 함께 증가
--   일부러 board_id, reg_dt 관련 인덱스를 만들지 않는다 (PK만 존재)
drop table if exists w10_post purge;
create table w10_post as
select level                                          as post_id,
       mod(level, 20) + 1                             as board_id,
       'title-' || level                              as title,
       'user' || mod(level * 13, 5000)                as writer,
       date '2025-01-01' + (level - 1) / 400          as reg_dt,
       mod(level * 17, 1000)                          as view_cnt,
       rpad('c', 200, 'c')                            as content
from   dual
connect by level <= 200000;
alter table w10_post add constraint w10_post_pk primary key (post_id);

commit;
exec dbms_stats.gather_table_stats(user, 'W10_GRP')
exec dbms_stats.gather_table_stats(user, 'W10_POST', method_opt => 'for all columns size 1', cascade => true)

prompt
prompt week10 준비 완료

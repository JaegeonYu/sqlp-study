-- week10 challenge: 게시판 목록 페이징 튜닝
--   3번 게시판(board_id = 3)을 최신 글 순으로 20건씩 보여주는 화면이다. 아래는 10페이지(181~200번째) 조회 SQL이다.
--   과제: 인덱스를 설계하고(DDL 포함) SQL을 다시 써서 Buffers 와 소트 메모리를 줄여라. 결과(20건, 순서 포함)는 같아야 한다.
--   제출: result.md 2번 (Before / 인덱스 DDL + 튜닝 SQL / After / 근거)
@@../../common/session_init

prompt
prompt ===== 원본 SQL =====
set feedback only
select *
from  (select rownum as rn, a.*
       from  (select post_id, board_id, title, writer, reg_dt, view_cnt
              from   w10_post
              where  board_id = 3
              order  by reg_dt desc) a)
where  rn between 181 and 200;
set feedback on
@@../../common/xplan
prompt 과제: 실행계획에서 비효율 두 가지(읽는 범위, 소트 방식)를 찾고, 인덱스 설계와 SQL 재작성으로 해결하라.
prompt       추가 질문: 같은 SQL로 1000페이지를 조회하면 어떻게 될까? 더 나은 방법은?

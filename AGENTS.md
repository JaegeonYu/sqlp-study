# AGENTS.md — sqlp-study 작업 가이드

AI 코딩 도구(Claude Code, Codex 등)와 사람 진행자가 이 저장소에서 작업할 때 따르는 규칙이다.
Claude Code는 `CLAUDE.md`를 통해 이 파일을 읽는다.

## 프로젝트
- SQLP 준비생 대상 12주 실습 스터디. 교재는 『오라클 성능 고도화 원리와 해법 I·II』(조시형)이다. 범위는 II권 중심이고 I권은 핵심만 다룬다.
- 학습 원칙은 **원리 → 재현 → 측정 → 글로 설명**이다. 모든 주장은 `DISPLAY_CURSOR ... 'ALLSTATS LAST'`의 Buffers / A-Rows / A-Time으로 증명한다.
- 저장소 소유자이자 진행자는 GitHub `JaegeonYu`다. 스터디원은 Collaborator로 참여하고, 주차별 결과를 PR로 제출한다.
- **공개 저장소다. 책의 코드·지문을 그대로 옮기지 않는다.** 개념을 재현하도록 새로 작성하고, 챌린지 정답은 저장소에 넣지 않는다.

## 구조
```
docker/compose.yml            gvenzl/oracle-free:23 (Oracle 23ai Free), 컨테이너명 sqlp-oracle
                              저장소 루트를 컨테이너의 /workspace 로 마운트(읽기 전용)
docker/init/*.sql             최초 기동 시 SYSDBA로 실행: STUDY 계정(study/study) 생성과 권한 부여
common/                       공통 SQL: session_init, xplan, mystat_begin/end, locks, trace_on/off, gen_big_table
scripts/                      호스트 헬퍼(sql/run/tkprof/wait-db, .sh + .ps1), scripts/ci/ (CI 전용)
weeks/weekNN-<topic>/         README.md, 01_setup.sql, 02_lab.sql, 03_challenge.sql, 99_cleanup.sql (+ 주차 전용 헬퍼)
weeks/*/submissions/<id>/     스터디원 제출물 (result.md, lab.txt ...)
templates/                    submission.md, blog-post.md
docs/                         environment.md(설치), contributing.md(제출·리뷰 규칙)
```
접속 정보: `study/study@//localhost:1521/FREEPDB1`. 스크립트는 컨테이너 안 sqlplus로 실행한다(`bash scripts/run.sh <파일>`).

## 주차 스크립트 작성 규칙
- 모든 SQL 파일은 `@@../../common/session_init`로 시작한다. 이 설정이 statistics_level=all, GTT `mystat_snap`, 출력 포맷을 맞춘다.
- 형식은 week00·week01을 따른다.
  - 단계마다 `prompt ===== [n] 제목 =====`을 붙이고, 단계 끝에 `prompt 관찰: ...` 질문을 둔다.
  - 측정할 SQL **바로 다음 줄**에 `@@../../common/xplan` 또는 mystat_begin/end를 둔다. 사이에 다른 SQL이 끼면 그 SQL의 계획이 나온다.
  - 여러 행을 반환하는 쿼리는 `set feedback only` / `set feedback on`으로 감싼다. 끝까지 fetch해야 A-Rows가 정확하다.
  - `set serveroutput on`을 쓴 뒤에는 xplan 전에 반드시 off로 돌린다. 켜져 있으면 DISPLAY_CURSOR가 dbms_output 호출 커서를 보여준다.
- 객체 이름에는 `wNN_` 접두어를 붙인다. `drop ... if exists` / `create ... if not exists`(23ai 문법)로 다시 실행해도 같은 결과가 나오게 한다.
- **주차 간 격리.** CI는 하나의 DB에서 전 주차를 순서대로 실행한다.
  - `BIG_TABLE`(100만 건, 공용)에는 PK만 남긴다. 주차 인덱스는 `99_cleanup.sql`에서 지운다.
  - BIG_TABLE 데이터를 바꾸면 rollback한다.
  - 통계를 바꿨으면 cleanup에서 `dbms_stats.gather_table_stats(user,'BIG_TABLE', method_opt=>'for all columns size 1', cascade=>true)`로 원복한다.
  - 세션 파라미터는 단계가 끝나면 되돌린다.
- BIG_TABLE의 컬럼 분포 설계는 `common/gen_big_table.sql` 주석에 있다(cust_id는 클러스터링 좋음, rnd_id는 무작위, status는 'N' 1% 등). 새 실습을 만들 때 이 분포를 먼저 활용한다.
- **출력 줄이 `ORA-`, `SP2-`, `PLS-`로 시작하면 CI가 실패로 판정한다.** 의도한 오류는 PL/SQL에서 예외를 잡아 접두어를 붙여 출력한다.
- 한 주차의 CI 실행 시간은 대략 5분 이내로 맞춘다.
- `common/`이나 `scripts/`를 바꾸면 모든 주차에 영향을 준다. 주차 하나에만 필요한 헬퍼는 그 주차 폴더에 둔다.
- README 구성: 책 대응 표(장 이름만), 학습 목표, 실행, 실습 표, (멀티 세션 실습), 챌린지, **책과 다른 점(23ai)**, 토론 질문, 제출.
  - 책은 10g/11g 기준이다. 23ai에서 다르게 나오면 결과를 억지로 맞추지 말고, 실제로 관찰한 것을 "책과 다른 점"에 기록한다.

## 검증과 CI
- `validate-sql / smoke`: SQL·스크립트(docker/, common/, scripts/, weeks/*/*.sql, 해당 워크플로)가 바뀐 PR에서 실제 Oracle을 띄워 전 주차를 `01 → 02 → 03 → 99` 순서로 실행한다. 바뀌지 않았으면 skipped(성공 처리)된다.
- `check-submission / check`: 모든 PR에서 실행된다. 제출 경로가 `submissions/<PR 작성자>/`인지, `result.md`가 작성되었는지 검사한다.
- main 브랜치 보호: PR 필수, 승인 1건, 필수 체크 `check`와 `smoke`, Squash merge만 허용, 머지 후 브랜치 자동 삭제.
  - 관리자(JaegeonYu)는 우회 가능(`enforce_admins=false`)하다. 스터디원 합류 전에 진행자 PR을 머지하기 위해서다.
- **CI 통과는 "오류 없음"만 의미한다.** 주차 스크립트를 추가하거나 바꾸면 `gh run view <run> --job <smoke job> --log`로 로그를 받아, 수치가 의도한 현상을 실제로 보여주는지 확인한다.
- 로컬 Docker는 필수가 아니다. 검증의 기준은 PR CI다.

## 작업 절차
1. `git switch main && git pull` → 작업 브랜치(`weekNN-<topic>`, `docs/...`, `ci/...`)를 만든다.
2. 변경 → 커밋 → push → PR을 연다. 제목 예: `[weekNN] <주제> 실습 추가`.
3. CI가 초록이 될 때까지 고친다(수치 확인 포함). 그다음 squash merge한다.
- 커밋 작성자는 저장소 로컬 설정 `JaegeonYu <yjk9805@naver.com>`이다. clone한 직후에는 다시 설정해야 한다.
- AI 도구가 만든 커밋·PR에는 각 도구의 attribution 규칙을 따른다.
- `.claude/worktrees/`는 Claude Code 병렬 작업용 임시 공간이므로 커밋하지 않는다(.gitignore에 포함).

## 진행 상태
- week00(환경·측정 도구), week01(아키텍처·Lock)은 main에 반영되었다.
- week02~12는 주차별 PR로 작성·검증 중이거나 반영되었다. 최신 상태는 `weeks/` 폴더와 열린 PR 목록으로 확인한다.
- 남은 일: 스터디원 Collaborator 초대, 초대 후 `enforce_admins` 활성화 검토, 스터디 후 챌린지 해설(`answer.md`) 공개.

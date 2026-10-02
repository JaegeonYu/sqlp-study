# SQLP 체화 스터디

『오라클 성능 고도화 원리와 해법』 I·II권을 교재로, **원리 → 재현 → 측정 → 글로 설명**을 12주 동안 반복하는 SQLP 실습 스터디입니다.

- 모두 같은 Docker DB(Oracle 23ai Free)와 같은 데이터로 실습합니다. 그래서 수치를 서로 비교할 수 있습니다.
- 모든 주장은 실행계획으로 증명합니다. `DISPLAY_CURSOR ... 'ALLSTATS LAST'`의 Buffers, A-Rows, A-Time을 근거로 씁니다.
- 실습 결과는 PR로 제출하고, 리뷰는 "수치 근거" 중심으로 합니다.
- 매주 블로그를 1편씩 씁니다.

> 이 저장소는 공개 저장소입니다. **책의 코드와 지문은 싣지 않습니다.** 모든 스크립트는 책의 개념을 재현하도록 새로 작성했습니다. 책은 10g/11g 기준이라 결과가 다르게 나오는 부분이 있고, 이런 부분은 각 주차 README의 "책과 다른 점"에 정리합니다.

## 빠른 시작
```bash
docker compose -f docker/compose.yml up -d
bash scripts/wait-db.sh
bash scripts/run.sh weeks/week00-setup/01_setup.sql
bash scripts/run.sh weeks/week00-setup/02_lab.sql
```
자세한 내용은 [docs/environment.md](docs/environment.md)(설치·접속·트러블슈팅), [docs/contributing.md](docs/contributing.md)(제출·리뷰 규칙), [docs/weekly-guide.md](docs/weekly-guide.md)(주차별 진행 방법·AI 활용 규칙)에 있습니다.

## 커리큘럼
| 주 | 날짜 | 책 | 주제 | 실습 핵심 | 발표 | 리뷰 순번 |
|---|---|---|---|---|---|---|
| [00](weeks/week00-setup) | | — | 환경 구축, 측정 도구 | 실행계획·세션 통계·TKPROF | 진행자 | |
| [01](weeks/week01-architecture-lock) | | I-1·2 | 아키텍처, 트랜잭션·Lock | 블록 I/O, 버퍼 캐시, Redo/Undo, TX/TM Lock | | |
| [02](weeks/week02-perf-tools-library-cache) | | I-3·4 | 성능 관리 도구, 라이브러리 캐시 | AUTOTRACE/TKPROF 심화, 바인드 변수와 하드 파싱 | | |
| [03](weeks/week03-db-call-io) | | I-5·6 | DB Call 최소화, I/O 효율화 | Array Fetch, 부분범위처리, Direct Path | | |
| [04](weeks/week04-index-basics) | | II-1 | 인덱스 원리 | B*Tree, 스캔 방식, 인덱스를 못 타는 조건 | | |
| [05](weeks/week05-index-tuning) | | II-1 | 인덱스 활용 | 클러스터링 팩터, 결합 인덱스 순서, 손익분기점 · **미니 모의 1** | | |
| [06](weeks/week06-join-basics) | | II-2 | 조인 I | NL / Sort Merge / Hash, 조인 순서 | | |
| [07](weeks/week07-join-advanced) | | II-2 | 조인 II | 스칼라 서브쿼리 캐싱, 고급 조인 기법 | | |
| [08](weeks/week08-optimizer) | | II-3 | 옵티마이저 | 통계·히스토그램, 카디널리티, 바인드 피킹 | | |
| [09](weeks/week09-query-transformation) | | II-4 | 쿼리 변환 | Unnesting, View Merging, Predicate Pushing · **미니 모의 2** | | |
| [10](weeks/week10-sort) | | II-5 | 소트 튜닝 | 소트 생략, Top-N, 페이징 | | |
| [11](weeks/week11-advanced-sql-parallel) | | II-6·7 | 고급 SQL, 병렬 처리 | 한 번 스캔 집계, 분석함수 활용 튜닝, 병렬 실행계획 읽기(Free는 병렬 미지원 → 예시 계획으로 학습) | | |
| [12](weeks/week12-mock-exam) | | — | 실기 모의, 회고 | 종합 튜닝 문제 3개, 채점 기준표 | 진행자 | |

## 세션 진행 (3시간)
| 시간 | 내용 |
|---|---|
| 40분 | 이론 발표 (순번제). 발표자는 D-3에 `theory/<id>.md`를 PR로 올리고, 리뷰 코멘트로 받은 질문에 답하는 방식으로 진행 |
| 30분 | 필기 문제풀이 |
| 60분 | 튜닝 챌린지. 각자 튜닝하고 Buffers 기록 비교 |
| 30분 | 실기 서술 첨삭 (원인 → 해결 → 근거) |

## 저장소 구조
```
docker/      Oracle 23ai Free compose, 계정 초기화 스크립트
common/      공통 스크립트: session_init, xplan, mystat_begin/end, locks, trace_on/off, gen_big_table
scripts/     호스트 헬퍼: sql / run / tkprof / wait-db (.sh, .ps1), CI 스크립트
weeks/       주차별 01_setup, 02_lab, 03_challenge, 99_cleanup, README, submissions/<id>/
templates/   실습 제출(submission), 개념 정리(concepts), 이론 노트(theory), 블로그 템플릿
```

## 블로그
| 멤버 | 00 | 01 | 02 | 03 | 04 | 05 | 06 | 07 | 08 | 09 | 10 | 11 | 12 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| | | | | | | | | | | | | | |

글 형식은 [templates/blog-post.md](templates/blog-post.md)를 따르고, 제목은 「SQLP 체화 스터디 #NN — 주제」로 통일합니다.

## 교재
- 조시형, 『오라클 성능 고도화 원리와 해법 I·II』: 메인 교재
- 한국데이터산업진흥원, 『SQL 전문가 가이드』: 시험 범위 기준
- 『SQL 자격검정 실전문제』: 필기 문제풀이

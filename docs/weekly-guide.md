# 주차별 진행 가이드

매주 **실습 → result.md 작성 → commit → PR → 리뷰 → merge**를 직접 진행하는 방법을 정리했습니다.
설치는 [environment.md](environment.md)를, 제출·리뷰 규칙은 [contributing.md](contributing.md)를 먼저 봅니다.

이 문서의 원칙은 하나입니다. **해석과 글은 내가 쓴다.** 실습에서 머리에 남는 부분은 "숫자를 보고 왜 그런지 설명하는 과정"입니다. 이 과정을 AI나 다른 사람의 답에 맡기면 PR은 올라가도 남는 것이 없습니다. AI를 어디까지 쓸지는 [7. AI 활용 규칙](#7-ai-활용-규칙)에 정리했습니다.

아래 예시는 week01 기준입니다. `week01-architecture-lock`은 해당 주차 폴더로, `<id>`는 본인 GitHub 아이디로 바꿔 읽습니다.

---

## 0. 한 주의 흐름

| 시점 | 할 일 | 결과물 |
|---|---|---|
| 스터디 3~5일 전 | 주차 README와 책 범위 읽기 → 실습 실행 | `lab.txt` |
| 스터디 2~3일 전 | 챌린지 풀기 → result.md, concepts.md 작성 | `challenge.txt`, `result.md`, `concepts.md` |
| 스터디 전날까지 | commit → push → PR 생성, 리뷰어 지정 | PR |
| 스터디 당일 | 토론, 리뷰 코멘트 반영 | 추가 커밋 |
| 스터디 이후 | 승인 1건 → Squash merge → 브랜치 정리 | main 반영 |

---

## 1. 매주 시작할 때

### 1-1. DB 켜기
Windows에서 Docker Engine을 WSL에 직접 설치했다면 **Ubuntu 터미널**에서 실행합니다. Docker Desktop을 쓴다면 아무 터미널에서나 실행하면 됩니다.

```bash
cd /mnt/c/<저장소 경로>/sqlp-study          # Docker Desktop이면 그냥 저장소 루트
docker compose -f docker/compose.yml start   # 이미 켜져 있으면 생략
bash scripts/wait-db.sh                      # "STUDY 계정 접속 OK"가 나오면 준비 완료
```

켜져 있는지는 `docker ps`로 확인합니다. `sqlp-oracle`이 `Up ... (healthy)`이면 정상입니다.

### 1-2. 브랜치 만들기
git 작업은 **Windows의 Git Bash나 VS Code**에서 합니다. 저장소가 Windows 드라이브에 있으면, WSL 안의 git은 줄바꿈과 파일 권한 차이 때문에 모든 파일이 바뀐 것처럼 보일 수 있습니다.

```bash
git switch main
git pull                                   # 최신 주차 스크립트 받기
git switch -c week01/<id>                  # 브랜치 이름: weekNN/<id>
mkdir -p weeks/week01-architecture-lock/submissions/<id>
```

### 1-3. 지난 주차 정리
지난 주차의 `99_cleanup.sql`을 아직 실행하지 않았다면 먼저 실행합니다. 지난 주에 만든 인덱스가 남아 있으면 이번 주 실행계획이 달라집니다.

```bash
bash scripts/run.sh weeks/week00-setup/99_cleanup.sql
```

---

## 2. 실습 (02_lab.sql)

### 2-1. 실행 전: README를 읽고 예측하기
주차 README의 "실습 구성" 표를 보고, 단계마다 **결과를 먼저 예측해서 메모**합니다.

```text
[2] FULL 스캔 Buffers 예측: 전체 블록 수 정도? → 약 19,000
[3] 인덱스로 같은 7,000건 → 7,000번 테이블을 찾아가니까 7,000 이상?
```

예측이 틀린 지점이 가장 많이 배우는 지점입니다. 이 메모는 result.md의 "관찰" 칸에 그대로 활용합니다.

### 2-2. 실행하고 결과 저장하기
```bash
bash scripts/run.sh weeks/week01-architecture-lock/01_setup.sql
bash scripts/run.sh weeks/week01-architecture-lock/02_lab.sql weeks/week01-architecture-lock/submissions/<id>/lab.txt
```
- 두 번째 인자로 준 파일에 결과가 저장되고, 이 파일이 **제출용 원본 결과**가 됩니다.
- 저장소의 `.sql` 파일(`01_setup`, `02_lab`, `03_challenge` 등)은 **수정하지 않습니다.** 모두가 같은 스크립트로 같은 수치를 내야 서로 비교할 수 있습니다.

### 2-3. 결과 읽기
`lab.txt`에서 `===== [n] 제목 =====` 단위로 읽습니다. 각 단계 끝의 `관찰:` 질문이 그 단계에서 답해야 할 문제입니다.

실행계획에서 먼저 볼 것:

| 컬럼 | 볼 것 |
|---|---|
| Buffers | 읽은 블록 수(논리 I/O). **누적값이라 부모 - 자식으로 빼서** 각 단계의 몫을 구합니다 |
| A-Rows / E-Rows | 실제 / 예상 행 수. 차이가 크면 옵티마이저가 잘못된 계획을 고를 수 있습니다 |
| Reads | 디스크에서 읽은 블록 수. 캐시에 있으면 0이 됩니다 |
| Predicate Information | `access`(스캔 범위를 줄이는 조건)인지 `filter`(읽은 뒤 버리는 조건)인지 |

모르는 용어가 나오면 책에서 찾고, 그래도 모르면 그 **용어 하나만** 질문합니다. "이 결과 해석해 줘"처럼 통째로 묻지 않습니다.

### 2-4. 직접 SQL을 바꿔 보기
`관찰:` 질문에 답하려면 SQL을 조금씩 바꿔 실행해 봐야 할 때가 많습니다. 두 가지 방법이 있습니다.

**방법 A: DB 툴 (DBeaver, SQL Developer 등)**

접속 정보: Host `127.0.0.1`, Port `1521`, Service name `FREEPDB1`, `study` / `study`

```sql
-- ① 접속할 때마다 한 번: 실제 실행 통계 수집
alter session set statistics_level = all;

-- ② 측정할 SQL. 나중에 찾을 수 있게 주석 꼬리표를 붙인다
select /* t01 */ count(*) from big_table where cust_id = 77;

-- ③ 그 SQL의 실제 실행계획 (꼬리표로 찾기)
select p.plan_table_output
from   v$sql s,
       table(dbms_xplan.display_cursor(s.sql_id, s.child_number, 'ALLSTATS LAST')) p
where  s.sql_text like 'select /* t01 */%';
```
- 툴의 **"Explain Plan" 버튼은 쓰지 않습니다.** 예상 계획만 나오고 Buffers 같은 실제 수치가 없습니다.
- `display_cursor(null, null, ...)`로 "직전 SQL"을 보는 방식은 툴이 뒤에서 자체 SQL을 실행하기 때문에 엉뚱한 계획이 나올 수 있습니다. 그래서 꼬리표로 찾습니다.
- 실험할 때마다 꼬리표를 바꿉니다(`t01`, `t02` …).
- 여러 행을 반환하는 SQL은 **결과를 끝까지 내려 받아야** A-Rows가 정확합니다(툴은 보통 처음 50~200행만 가져옵니다).

**방법 B: 터미널 SQL*Plus**

```bash
bash scripts/sql.sh
SQL> @common/session_init
SQL> select count(*) from big_table where cust_id = 77;
SQL> @common/xplan              -- 측정한 SQL 바로 다음에 실행
SQL> exit
```
- `xplan`은 **측정한 SQL 바로 다음에** 실행합니다. 사이에 다른 SQL이 끼면 그 SQL의 계획이 나옵니다.
- 여러 행을 반환하는 SQL은 `set feedback only`로 실행해 화면 출력 없이 끝까지 fetch하고, 다시 `set feedback on`으로 돌립니다.

### 2-5. 멀티 세션 실습이 있는 주차
week01처럼 세션 여러 개가 필요한 실습은 README의 표 순서대로 진행합니다.
- 터미널(또는 DB 툴 접속 창)을 세션 수만큼 엽니다.
- 각 세션에서 먼저 `@common/session_init`을 실행합니다.
- DB 툴로 할 때는 **자동 커밋(auto-commit)을 꺼야 합니다.** 켜져 있으면 Lock이 바로 풀려 버려서 대기 상황을 재현할 수 없습니다.
- 실습 하나가 끝날 때마다 모든 세션에서 `rollback;`을 실행하고 다음 실습으로 넘어갑니다.

---

## 3. 챌린지 (03_challenge.sql)

### 3-1. 진행 순서
1. **Before 결과 저장**
   ```bash
   bash scripts/run.sh weeks/week01-architecture-lock/03_challenge.sql weeks/week01-architecture-lock/submissions/<id>/challenge.txt
   ```
2. **원인을 실행계획에서 찾기.** 아래 순서로 봅니다.
   - Buffers가 가장 많이 늘어나는 오퍼레이션은 어디인가?
   - 그 오퍼레이션의 조건은 `access`인가, `filter`인가?
   - E-Rows와 A-Rows는 얼마나 차이 나는가?
3. **원인을 한 문장으로 적어 보기.** 쓸 수 없다면 아직 원인을 찾지 못한 것입니다.
4. **튜닝 SQL 작성 → 실행 → 실행계획 확인** (2-4의 방법 A 또는 B)
5. **결과가 Before와 같은지 반드시 확인합니다.** 건수와 합계 값을 비교합니다. 결과가 달라지면 튜닝이 아닙니다.
6. 원인과 해결 방법을 여러 개 생각해 봤다면 **모두 실행해 보고 Buffers를 비교합니다.**

### 3-2. 막혔을 때
아래 순서로 범위를 넓혀 갑니다. 처음부터 정답을 찾아보지 않습니다.
1. 주차 README의 "볼 것", "챌린지" 설명을 다시 읽습니다.
2. 책에서 해당 개념 부분을 다시 읽습니다.
3. 스터디원에게 **힌트**를 요청하거나 PR에 질문으로 남깁니다.
4. AI에게 묻는다면 "정답 말고 어디를 봐야 하는지 힌트 하나만"이라고 요청합니다.

다른 사람 PR의 챌린지 답은 **스터디 당일 전에는 보지 않습니다** (contributing.md 규칙 6).

---

## 4. result.md 작성

```bash
cp templates/submission.md weeks/week01-architecture-lock/submissions/<id>/result.md
```
첫 줄의 `weekNN 제출 — <github-id>`를 `week01 제출 — <id>`로 바꿉니다.

### 4-1. 1번 실습 관찰 기록
주차의 실습 단계 수만큼 행을 늘립니다(템플릿은 3행).

- **관찰한 수치:** lab.txt에서 그대로 옮깁니다. 반올림하거나 "많이"처럼 쓰지 않습니다.
- **한 줄 해석:** `관찰:` 질문에 대한 내 답입니다. **수치 + 이유**가 함께 있어야 합니다.

| 좋지 않은 예 | 좋은 예 |
|---|---|
| 인덱스가 훨씬 빠르다 | Buffers 18,868 → 154로 약 1/120. 인덱스 21블록 + 테이블 133블록만 읽었다 |
| 예측이 틀렸다 | E-Rows 500K / A-Rows 10,000. 히스토그램이 없어 값 2개를 반반으로 가정했다 |
| FULL 스캔이라 느리다 | 7,000건을 위해 HWM 아래 데이터 블록 18,865개를 모두 읽었다 |

예측과 결과가 달랐던 단계는 "예측 X → 실제 Y, 이유는 Z"로 적으면 가장 좋은 기록이 됩니다.

### 4-2. 2번 챌린지
| 항목 | 쓰는 법 |
|---|---|
| 문제 원인 | 실행계획의 **어느 Id**에서, **왜** 비효율이 생기는지. Predicate Information을 인용합니다 |
| Before | challenge.txt의 실행계획을 SQL_ID부터 Predicate Information까지 그대로 붙여 넣습니다 |
| 튜닝 SQL | 실제로 실행한 SQL. 인덱스를 만들었다면 DDL도 씁니다 |
| After | 튜닝 SQL의 실행계획을 같은 형식으로 붙여 넣습니다. **결과 값(건수, 합계)도 함께** 적습니다 |
| 지표 표 | Buffers, Reads, A-Time. 필요하면 E-Rows/A-Rows 행을 추가합니다 |
| 근거 | 실기 답안처럼 **원인 → 해결 방법 → 왜 줄어드는가(블록, 액세스 관점)**. "Buffers가 줄었다"에서 끝내지 말고, 어느 단계에서 몇 블록이 왜 줄었는지 씁니다 |

### 4-3. 3번 책과 다르게 나온 점
책(10g/11g) 설명대로 나오지 않은 결과를 적습니다. 주차 README의 "책과 다른 점"을 참고하되, **내 결과에서 실제로 확인한 것**만 씁니다.

### 4-4. 4번 질문 / 토론거리
실습하면서 생긴 의문을 적습니다. "왜 Reads가 Buffers보다 크지?"처럼 수치에서 나온 질문이 가장 좋은 토론거리가 됩니다. 스스로 실험해서 답을 찾았다면 답도 함께 적습니다.

### 4-5. 5번 블로그
그 주에 쓴 블로그 링크를 넣습니다. 형식은 [templates/blog-post.md](../templates/blog-post.md)를 따릅니다.

### 4-6. concepts.md (week01~11)
```bash
cp templates/concepts.md weeks/week01-architecture-lock/submissions/<id>/concepts.md
```
- 핵심 개념 3개를 **책을 덮고** 씁니다. 다 쓴 뒤에 책과 비교해 틀린 곳을 고칩니다.
- 개념마다 "이번 주 lab의 몇 번 단계, 어떤 수치로 확인했는지"를 연결합니다.
- 필기 문제 2개는 오답 선지도 그럴듯하게 만듭니다. 오답 선지를 만들려면 개념의 경계를 알아야 해서 공부가 많이 됩니다.

### 4-7. 제출 전 확인
- [ ] 수치가 lab.txt, challenge.txt의 원본 값과 일치한다
- [ ] 튜닝 SQL의 결과가 Before와 같다는 것을 적었다
- [ ] 모든 해석이 내 말로 쓰여 있다 (책이나 AI의 문장을 옮기지 않았다)
- [ ] 아무것도 보지 않고 챌린지의 원인과 해결을 1분 안에 설명할 수 있다

---

## 5. commit과 push

```bash
git status                                  # 내 submissions/<id>/ 폴더만 바뀌었는지 확인
git add weeks/week01-architecture-lock/submissions/<id>
git commit -m "week01: <id> 제출"
git push -u origin week01/<id>
```
- `git status`에 **다른 경로의 파일이 보이면 add하지 않습니다.** 다른 경로가 포함되면 `check` CI가 실패합니다.
- 리뷰를 반영할 때는 같은 브랜치에서 파일을 고친 뒤 `git add` → `git commit -m "week01: 리뷰 반영"` → `git push`를 하면 PR에 자동으로 추가됩니다.

---

## 6. PR → 리뷰 → merge

### 6-1. PR 만들기 (GitHub 웹)
1. push하면 저장소 페이지 위쪽에 **Compare & pull request** 버튼이 나옵니다. 없으면 **Pull requests → New pull request**에서 base `main`, compare `week01/<id>`를 고릅니다.
2. 제목: `[week01] <id>`
3. 본문: 템플릿이 자동으로 채워집니다. 체크리스트를 확인하며 `[ ]`를 `[x]`로 바꾸고, "리뷰어에게" 칸에 **봐 줬으면 하는 부분이나 막힌 부분**을 적습니다.
4. 오른쪽 **Reviewers**에서 README 리뷰 순번표의 리뷰어 1명을 지정합니다.
5. **Create pull request**

### 6-2. CI 확인
PR 아래쪽 Checks에서 확인합니다.

| 검사 | 의미 | 실패하면 |
|---|---|---|
| `check` | 본인 폴더만 수정했는지, result.md를 템플릿 그대로 두지 않았는지 | 다른 경로의 파일을 커밋에서 빼거나, result.md를 채웁니다 |
| `smoke` | SQL 스크립트 검증 | 제출 PR에서는 skipped가 정상입니다 |

### 6-3. 리뷰하기 (내가 리뷰어일 때)
**Files changed** 탭에서 줄 옆의 `+`를 눌러 코멘트를 남깁니다. 기준은 "수치 근거"입니다.
- "Buffers가 줄어든 이유가 테이블 랜덤 액세스 감소인지, 인덱스 스캔 범위 감소인지 구분해 주세요."
- "E-Rows와 A-Rows가 100배 차이 나는데, 이게 계획 선택에 영향을 줬을까요?"
- 다른 사람의 해석을 읽고 **내 결과와 수치가 다르면** 그 차이를 질문합니다.

다 봤으면 **Review changes**에서 Approve 또는 Request changes를 선택합니다.

### 6-4. 리뷰 받은 후
1. 코멘트에 답글을 달고, 고칠 부분은 5번처럼 같은 브랜치에 커밋 → push합니다.
2. 반영한 코멘트는 **Resolve conversation**을 누릅니다.

### 6-5. merge (작성자가 직접)
1. 승인 1건과 CI 통과를 확인합니다.
2. PR 아래쪽 merge 버튼의 화살표를 눌러 **Squash and merge**를 선택합니다.
3. 커밋 제목을 `[week01] <id> (#PR번호)` 형식으로 맞추고 **Confirm**합니다. 저장소 설정에 따라 기본값이 PR 제목이 아니라 커밋 메시지일 수 있으니 확인합니다.
4. **Delete branch**를 눌러 원격 브랜치를 지웁니다.

### 6-6. 로컬 정리
```bash
git switch main
git pull
git branch -D week01/<id>     # squash merge라 -d로는 안 지워질 수 있어 -D를 씁니다
```
마지막으로 이번 주차의 `99_cleanup.sql`을 실행해 다음 주차를 준비합니다.

---

## 7. AI 활용 규칙

AI(Claude Code, ChatGPT 등)를 쓰더라도 **해석과 글은 내가 쓰고, git 작업은 내가 직접 합니다.**

| 맡겨도 되는 것 | 맡기지 않는 것 |
|---|---|
| Docker, WSL, git 설치나 오류 해결 | result.md, concepts.md 작성 |
| 모르는 용어 하나의 뜻 | 실행계획 전체의 해석 |
| 내가 쓴 result.md에서 **틀린 곳 지적** | 챌린지 정답 |
| 챌린지 **힌트 하나** | commit, push, PR 생성, merge |
| 나에게 질문을 던지게 하기 ("이번 주 개념으로 문제 3개 내 줘") | |

요청할 때는 이렇게 말합니다.
- "정답은 말하지 말고, 어느 오퍼레이션을 봐야 하는지만 알려 줘."
- "내가 쓴 해석이야. 수치나 개념이 틀린 곳만 지적해 줘. 고친 문장은 쓰지 마."
- "Buffers가 누적값이라는 게 무슨 뜻인지 내가 설명해 볼게. 틀렸으면 알려 줘."

AI가 답을 써 줬다면 그 답을 지우고, 하루 뒤 보지 않고 다시 써 봅니다. 다시 쓸 수 있으면 내 것이 된 것입니다.

---

## 8. 자주 막히는 곳

| 증상 | 원인 / 해결 |
|---|---|
| `docker: permission denied` | WSL 사용자가 docker 그룹에 없음 → `sudo usermod -aG docker $USER` 후 터미널을 모두 닫고 PowerShell에서 `wsl --terminate <배포판 이름>` |
| `No such container` / `is not running` | 컨테이너가 꺼져 있음 → 1-1의 `start`와 `wait-db.sh` |
| 실행계획에 내가 실행한 SQL이 아닌 계획이 나옴 | xplan 앞에 다른 SQL이 끼었거나 DB 툴이 자체 SQL을 실행함 → 2-4의 꼬리표 방식 사용 |
| A-Rows가 실제 건수보다 작음 | 결과를 끝까지 fetch하지 않음 → `set feedback only` 또는 툴에서 전체 행 가져오기 |
| 지난주와 실행계획이 다르게 나옴 | 지난 주차 인덱스가 남아 있음 → 지난 주차 `99_cleanup.sql` 실행 |
| `git status`에 모든 파일이 바뀐 것으로 나옴 | WSL의 git으로 Windows 폴더를 봄 → Windows의 Git Bash나 VS Code에서 작업 |
| `check` CI 실패 | 다른 경로를 수정했거나 result.md가 템플릿 그대로임 → 6-2 참고 |

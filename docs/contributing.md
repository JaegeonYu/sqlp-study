# 제출과 리뷰 규칙

## 매주 흐름
```bash
git switch main && git pull
git switch -c week01/<github-id>

# 1) 실습 실행 + 원본 결과 저장
bash scripts/run.sh weeks/week01-architecture-lock/01_setup.sql
bash scripts/run.sh weeks/week01-architecture-lock/02_lab.sql       weeks/week01-architecture-lock/submissions/<github-id>/lab.txt
bash scripts/run.sh weeks/week01-architecture-lock/03_challenge.sql weeks/week01-architecture-lock/submissions/<github-id>/challenge.txt

# 2) 결과 정리
cp templates/submission.md weeks/week01-architecture-lock/submissions/<github-id>/result.md
#    → 표, Before/After, 근거 작성
cp templates/concepts.md   weeks/week01-architecture-lock/submissions/<github-id>/concepts.md
#    → 핵심 개념 3개(자기 말로 + 실습 수치 연결), 필기 문제 2개 출제  (week01~11 필수)

# 3) PR
git add weeks/week01-architecture-lock/submissions/<github-id>
git commit -m "week01: <github-id> 제출"
git push -u origin week01/<github-id>
#    → GitHub에서 PR 생성, 제목: [week01] <github-id>
```

## 이론 노트 (그 주 발표자)
실습은 "수치로 증명"하는 것을, 이론은 "자기 말로 설명"하는 것을 리뷰합니다. 발표 자료도 PR로 올려서 스터디 전에 미리 리뷰를 받습니다.

```
D-3  발표자: theory/<id>.md 작성 → PR 생성 (제목: [week01] 이론 노트 - <id>)
D-3~D-1  스터디원: PR 리뷰 코멘트로 질문 남기기  → 이 질문들이 발표의 중심이 됩니다
D-day  질문에 답하는 방식으로 발표 → 토론 결과를 노트에 반영해 커밋
D+1  승인 1건 → 머지 (그 주차의 공식 이론 노트로 남음)
```
```bash
git switch main && git pull
git switch -c week01/theory-<github-id>
mkdir -p weeks/week01-architecture-lock/theory
cp templates/theory.md weeks/week01-architecture-lock/theory/<github-id>.md
#    → 작성 후 add / commit / push / PR
```

**작성 원칙**
- **책을 옮기지 않습니다.** 요약과 재구성만 하고, 인용은 짧게 출처(권·장·쪽)를 붙입니다. 책 그림을 스캔하거나 촬영해 올리지 않습니다.
- **그림은 Mermaid로 직접 그립니다.** GitHub이 마크다운 안의 ` ```mermaid ` 블록을 다이어그램으로 보여줍니다.
- **모든 개념은 실습과 연결합니다.** "이번 주 `02_lab.sql`의 몇 번 단계에서, 어떤 수치로 확인되는가"를 적습니다.

**이론 PR 리뷰 기준**
- 정확성: "이 설명의 근거는 책 몇 장인가요? 23ai에서도 같은가요?"
- 연결: "이 개념이 실습의 어느 수치로 확인되나요?"
- 이해: "이 부분을 한 문장으로 다시 설명해 주실 수 있나요?"

## 규칙
1. **본인 파일만 수정합니다.** 실습 제출은 `weeks/weekNN-*/submissions/<본인 github id>/`, 이론 노트는 `weeks/weekNN-*/theory/<본인 github id>.md`입니다. 다른 경로를 건드리면 `check-submission` CI가 실패합니다.
2. **리뷰어는 1명 지정합니다.** 매주 순번표(README)에 따라 정하고, 승인 1건이 있어야 머지할 수 있습니다.
3. **리뷰 기준은 "수치 근거"입니다.** "좋아요" 대신 아래처럼 남깁니다.
   - "Buffers가 줄어든 이유가 테이블 랜덤 액세스 감소인지, 인덱스 스캔 범위 감소인지 구분해 주세요."
   - "E-Rows와 A-Rows가 100배 차이 나는데, 이게 계획 선택에 영향을 줬을까요?"
4. **머지는 작성자가 직접** Squash merge로 합니다.
5. **책 원문(코드·지문)을 그대로 옮기지 않습니다.** 공개 저장소입니다. 개념은 자기 말로 쓰고, 인용은 짧게 출처와 함께 답니다.
6. 챌린지 정답은 **스터디 당일 이후** 진행자가 `weeks/weekNN-*/answer.md`로 공개합니다. 그 전에는 다른 사람 PR의 챌린지 답을 보지 않습니다.

## 진행자용 저장소 설정 (최초 1회)
- Settings → Collaborators: 스터디원을 초대합니다 (Write 권한).
- Settings → Branches → `main` 보호 규칙:
  - Require a pull request before merging (Required approvals: 1)
  - Require status checks: `check`(check-submission), `smoke`(validate-sql)
  - `smoke`는 SQL·스크립트가 바뀐 PR에서만 실제 Oracle을 띄워 전 주차를 실행합니다. 바뀌지 않은 PR(제출 PR)에서는 skipped로 끝나고, GitHub은 이를 성공으로 처리합니다. 그래서 스크립트가 깨진 PR은 머지되지 않고, 제출 PR은 바로 통과합니다.
- Settings → General → Pull Requests: Squash merge만 허용합니다.

## 주차 스크립트 작성 규칙 (진행자)
- 폴더 이름: `weeks/weekNN-<topic>/`. 파일은 `01_setup.sql`, `02_lab.sql`, `03_challenge.sql`, `99_cleanup.sql`, `README.md`입니다.
- 모든 SQL 스크립트는 첫 줄에서 `@@../../common/session_init`을 호출합니다.
- 다시 실행해도 같은 결과가 나와야 합니다. `drop ... if exists`와 `create ... if not exists`를 씁니다.
- `BIG_TABLE`에는 PK만 남겨 둡니다. 주차 인덱스는 `wNN_` 접두어를 붙이고 `99_cleanup.sql`에서 지웁니다.
- 출력 줄이 `ORA-`, `SP2-`, `PLS-`로 시작하지 않아야 합니다. CI가 이런 줄을 오류로 판단합니다. 의도적으로 오류를 보여주는 실습은 PL/SQL 예외 처리로 감싸서, 메시지 앞에 다른 글자가 오도록 출력합니다.
- `BIG_TABLE`의 데이터를 바꾸는 실습은 반드시 `rollback`합니다. 통계를 바꾸는 실습(히스토그램 등)은 `99_cleanup.sql`에서 `method_opt => 'for all columns size 1'`로 다시 수집해 원래대로 돌려놓습니다. CI는 전 주차를 한 DB에서 순서대로 실행하므로, 앞 주차의 흔적이 다음 주차 결과를 바꾸면 안 됩니다.
- 세션 파라미터를 바꾸는 실습은 해당 단계가 끝나면 원래 값으로 되돌립니다.

#!/usr/bin/env bash
# CI: 제출 PR 규칙 검사
#   1) submissions 아래 변경은 weeks/weekNN-<topic>/submissions/<PR 작성자 id>/ 안에서만
#   2) 변경된 제출 폴더마다 result.md 가 있고 템플릿 그대로가 아닐 것
#      week01~11 은 concepts.md(개념 정리 + 문제 출제)도 필수
#   3) 이론 노트는 weeks/weekNN-<topic>/theory/<PR 작성자 id>.md 만 추가·수정 가능
# 환경변수: AUTHOR, BASE_SHA, HEAD_SHA
set -euo pipefail

author_lc="$(tr '[:upper:]' '[:lower:]' <<< "$AUTHOR")"
changed="$(git diff --name-only --diff-filter=ACMR "$BASE_SHA" "$HEAD_SHA" -- 'weeks/*/submissions/*' 'weeks/*/theory/*')"
fail=0
declare -A dirs=()
theory_cnt=0

err() { echo "::error file=$1::$2"; fail=1; }

# 템플릿 자리표시자가 남아 있으면 미작성으로 본다
check_filled() {
  local f="$1" label="$2"
  if [ ! -f "$f" ]; then
    echo "::error::$f 가 없습니다 ($label)"
    fail=1
  elif grep -q '<github-id>' "$f"; then
    err "$f" "템플릿의 <github-id> 를 본인 id로 바꾸고 내용을 채워주세요"
  fi
}

while IFS= read -r path; do
  [ -z "$path" ] && continue
  if [[ "$path" =~ ^weeks/week[0-9]{2}-[a-z0-9-]+/submissions/([^/]+)/.+ ]]; then
    owner_lc="$(tr '[:upper:]' '[:lower:]' <<< "${BASH_REMATCH[1]}")"
    [ "$owner_lc" != "$author_lc" ] && err "$path" "본인 폴더(submissions/$AUTHOR/)만 수정할 수 있습니다"
    dirs["$(cut -d/ -f1-4 <<< "$path")"]=1
  elif [[ "$path" =~ ^weeks/week[0-9]{2}-[a-z0-9-]+/theory/([^/]+)\.md$ ]]; then
    owner_lc="$(tr '[:upper:]' '[:lower:]' <<< "${BASH_REMATCH[1]}")"
    [ "$owner_lc" != "$author_lc" ] && err "$path" "이론 노트는 본인 파일(theory/$AUTHOR.md)만 수정할 수 있습니다"
    check_filled "$path" "templates/theory.md 를 복사해서 작성"
    theory_cnt=$((theory_cnt + 1))
  else
    case "$path" in
      */theory/*) err "$path" "경로 규칙 위반 (weeks/weekNN-<topic>/theory/<github-id>.md)" ;;
      *)          err "$path" "경로 규칙 위반 (weeks/weekNN-<topic>/submissions/<github-id>/<file>)" ;;
    esac
  fi
done <<< "$changed"

for d in "${!dirs[@]}"; do
  check_filled "$d/result.md" "templates/submission.md 를 복사해서 작성"
  week="$(sed -E 's#^weeks/week([0-9]{2}).*#\1#' <<< "$d")"
  if [ "$((10#$week))" -ge 1 ] && [ "$((10#$week))" -le 11 ]; then
    check_filled "$d/concepts.md" "templates/concepts.md 를 복사해서 작성"
  fi
done

[ $fail -eq 0 ] && echo "제출 규칙 OK (제출 폴더 ${#dirs[@]}개, 이론 노트 ${theory_cnt}개)"
exit $fail

#!/usr/bin/env bash
# CI: 제출 PR 규칙 검사
#   1) submissions 아래 변경은 weeks/weekNN-<topic>/submissions/<PR 작성자 id>/ 안에서만
#   2) 변경된 제출 폴더마다 result.md 가 있고, 템플릿 그대로가 아닐 것
# 환경변수: AUTHOR, BASE_SHA, HEAD_SHA
set -euo pipefail

author_lc="$(tr '[:upper:]' '[:lower:]' <<< "$AUTHOR")"
changed="$(git diff --name-only --diff-filter=ACMR "$BASE_SHA" "$HEAD_SHA" -- 'weeks/*/submissions/*')"
fail=0
declare -A dirs=()

while IFS= read -r path; do
  [ -z "$path" ] && continue
  if [[ "$path" =~ ^weeks/week[0-9]{2}-[a-z0-9-]+/submissions/([^/]+)/.+ ]]; then
    owner_lc="$(tr '[:upper:]' '[:lower:]' <<< "${BASH_REMATCH[1]}")"
    if [ "$owner_lc" != "$author_lc" ]; then
      echo "::error file=$path::본인 폴더(submissions/$AUTHOR/)만 수정할 수 있습니다"
      fail=1
    fi
    dirs["$(cut -d/ -f1-4 <<< "$path")"]=1
  else
    echo "::error file=$path::경로 규칙 위반 (weeks/weekNN-<topic>/submissions/<github-id>/<file>)"
    fail=1
  fi
done <<< "$changed"

for d in "${!dirs[@]}"; do
  if [ ! -f "$d/result.md" ]; then
    echo "::error::$d/result.md 가 없습니다 (templates/submission.md 를 복사해서 작성)"
    fail=1
  elif grep -q '<github-id>' "$d/result.md"; then
    echo "::error file=$d/result.md::템플릿의 <github-id> 를 본인 id로 바꾸고 내용을 채워주세요"
    fail=1
  fi
done

[ $fail -eq 0 ] && echo "제출 규칙 OK (${#dirs[@]}개 폴더)"
exit $fail

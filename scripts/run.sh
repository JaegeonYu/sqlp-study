#!/usr/bin/env bash
# SQL 파일을 비대화형으로 실행하고 결과를 화면과 파일에 남긴다 (PR 제출용 원본 결과)
#   bash scripts/run.sh weeks/week00-setup/02_lab.sql
#   bash scripts/run.sh weeks/week00-setup/02_lab.sql weeks/week00-setup/submissions/<id>/lab.txt
set -euo pipefail
export MSYS_NO_PATHCONV=1

script="${1:?실행할 SQL 파일 경로를 입력하세요 (저장소 루트 기준)}"
out="${2:-}"
script="${script#./}"
dir="$(dirname "$script")"
file="$(basename "$script")"

run() {
  docker exec -w "/workspace/$dir" sqlp-oracle \
    sqlplus -L -s study/study@//localhost:1521/FREEPDB1 @"$file" < /dev/null
}

if [ -n "$out" ]; then
  mkdir -p "$(dirname "$out")"
  run | tee "$out"
else
  run
fi

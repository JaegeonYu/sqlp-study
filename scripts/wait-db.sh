#!/usr/bin/env bash
# DB 준비 완료(초기화 스크립트 포함)까지 대기 후 STUDY 접속 확인
#   bash scripts/wait-db.sh [최대대기초=600]
set -euo pipefail
export MSYS_NO_PATHCONV=1

limit="${1:-600}"
elapsed=0
until docker logs sqlp-oracle 2>&1 | grep -q "DATABASE IS READY TO USE"; do
  if [ "$elapsed" -ge "$limit" ]; then
    echo "시간 초과: DB가 ${limit}초 안에 준비되지 않았습니다." >&2
    docker logs --tail 50 sqlp-oracle >&2
    exit 1
  fi
  sleep 5
  elapsed=$((elapsed + 5))
done

result="$(echo "select 'STUDY_LOGIN_OK' from dual;" \
  | docker exec -i sqlp-oracle sqlplus -L -s study/study@//localhost:1521/FREEPDB1)"
if ! grep -q STUDY_LOGIN_OK <<< "$result"; then
  echo "DB는 떴지만 STUDY 접속에 실패했습니다:" >&2
  echo "$result" >&2
  exit 1
fi
echo "DB 준비 완료 (${elapsed}s). STUDY 계정 접속 OK"

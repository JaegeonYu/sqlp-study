#!/usr/bin/env bash
# DB 준비 완료(초기화 스크립트 포함)까지 대기 후 STUDY 접속 확인
#   bash scripts/wait-db.sh [최대대기초=600]
#   로그 문구("DATABASE IS READY TO USE")는 보지 않는다.
#   - pipefail 상태에서 docker logs | grep -q 는 grep이 먼저 끝나 SIGPIPE로 실패 처리되어, 로그가 길면 영원히 기다린다.
#   - 재기동한 컨테이너는 이전 기동의 문구가 로그에 남아 있어 준비 전에도 통과한다.
#   대신 컨테이너 healthcheck가 healthy이고 STUDY 접속이 실제로 성공할 때까지 기다린다.
set -euo pipefail
export MSYS_NO_PATHCONV=1

limit="${1:-600}"
elapsed=0

study_login() {
  echo "select 'STUDY_LOGIN_OK' from dual;" \
    | docker exec -i sqlp-oracle sqlplus -L -s study/study@//localhost:1521/FREEPDB1 2>&1 || true
}

while :; do
  state="$(docker inspect -f '{{.State.Status}} {{if .State.Health}}{{.State.Health.Status}}{{end}}' sqlp-oracle 2>/dev/null || echo missing)"
  case "$state" in
    missing)
      echo "sqlp-oracle 컨테이너가 없습니다. 먼저 docker compose -f docker/compose.yml up -d 를 실행하세요." >&2
      exit 1 ;;
    exited*|dead*)
      echo "sqlp-oracle 컨테이너가 종료되었습니다 ($state):" >&2
      docker logs --tail 50 sqlp-oracle >&2
      exit 1 ;;
    "running healthy")
      # 최초 기동이면 healthy 이후에도 init 스크립트(STUDY 생성)가 돌고 있을 수 있다
      if grep -q STUDY_LOGIN_OK <<< "$(study_login)"; then
        echo "DB 준비 완료 (${elapsed}s). STUDY 계정 접속 OK"
        exit 0
      fi ;;
  esac
  if [ "$elapsed" -ge "$limit" ]; then
    echo "시간 초과: DB가 ${limit}초 안에 준비되지 않았습니다 (상태: $state)." >&2
    study_login >&2
    docker logs --tail 50 sqlp-oracle >&2
    exit 1
  fi
  sleep 5
  elapsed=$((elapsed + 5))
done

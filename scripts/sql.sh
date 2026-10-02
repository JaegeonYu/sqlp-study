#!/usr/bin/env bash
# STUDY 계정으로 대화형 SQL*Plus 접속 (작업 디렉터리 = 저장소 루트)
#   bash scripts/sql.sh
#   SQL> @weeks/week00-setup/02_lab.sql
set -euo pipefail
export MSYS_NO_PATHCONV=1   # Git Bash가 /workspace 경로를 C:/... 로 바꾸지 않도록

docker exec -it -w /workspace sqlp-oracle \
  sqlplus -L study/study@//localhost:1521/FREEPDB1

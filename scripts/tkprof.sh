#!/usr/bin/env bash
# trace_on 에서 지정한 식별자의 최신 트레이스 파일을 TKPROF로 포맷해 출력
#   bash scripts/tkprof.sh week00
#   bash scripts/tkprof.sh week00 > weeks/week00-setup/submissions/<id>/tkprof.txt
set -euo pipefail
export MSYS_NO_PATHCONV=1

id="${1:?트레이스 식별자를 입력하세요 (예: week00)}"
docker exec sqlp-oracle bash /workspace/scripts/container/tkprof-inner.sh "$id"

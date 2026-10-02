#!/usr/bin/env bash
# 컨테이너 안에서 실행된다 (scripts/tkprof.sh, tkprof.ps1 이 호출)
set -euo pipefail

id="$1"
trc="$(find /opt/oracle/diag/rdbms -iname "*_${id}.trc" -printf '%T@ %p\n' 2>/dev/null \
       | sort -rn | head -1 | cut -d' ' -f2-)"

if [ -z "$trc" ]; then
  echo "트레이스 파일을 찾지 못했습니다: *_${id}.trc  (trace_on/trace_off 를 실행했는지 확인)" >&2
  exit 1
fi

out="/tmp/${id}.prf"
tkprof "$trc" "$out" sys=no sort=prsela,exeela,fchela > /dev/null
echo "# source: $trc"
cat "$out"

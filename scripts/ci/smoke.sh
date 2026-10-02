#!/usr/bin/env bash
# CI: 모든 주차의 01_setup → 02_lab → 03_challenge → 99_cleanup 을 순서대로 실행해
#     SQL 오류(ORA-)나 SQL*Plus 오류(SP2-)가 없는지 확인한다.
set -uo pipefail
export MSYS_NO_PATHCONV=1

fail=0
for wk in weeks/week*/; do
  wk="${wk%/}"
  for f in 01_setup.sql 02_lab.sql 03_challenge.sql 99_cleanup.sql; do
    [ -f "$wk/$f" ] || continue
    echo "::group::$wk/$f"
    out="$(docker exec -i -w "/workspace/$wk" sqlp-oracle \
             sqlplus -L -s study/study@//localhost:1521/FREEPDB1 <<EOF 2>&1
whenever sqlerror exit failure
whenever oserror exit failure
@$f
exit
EOF
)"
    rc=$?
    echo "$out"
    echo "::endgroup::"
    if [ $rc -ne 0 ]; then
      echo "::error file=$wk/$f::종료 코드 $rc"
      fail=1
    elif grep -qE '^(ORA-|SP2-|PLS-)' <<< "$out"; then
      echo "::error file=$wk/$f::출력에 오류 메시지가 있습니다"
      fail=1
    fi
  done
done
exit $fail

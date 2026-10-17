#!/bin/sh
# Compare two smoke runs game by game.
# Usage: sh compare-all.sh <base_dir> <cand_dir>
# Each dir holds nes/ snes/ gba/ md/ sms/ subdirs (as smoke.sh writes).
# Prints markdown; exits 0 iff every game MATCHes.
set -e
SDIR=$(cd "$(dirname "$0")" && pwd)
BASE=$1; CAND=$2
DIFF=0
echo "# Smoke compare: $BASE vs $CAND"
echo ""
for core in nes snes gba md sms; do
  echo "## core $core"
  case $core in
    nes) SR="--sr 48000";;
    snes) SR="";;
    gba|md|sms) SR="--sr 48000";;
  esac
  if [ ! -d "$BASE/$core" ] || [ ! -d "$CAND/$core" ]; then
    echo "(missing on one side; skipped)"
    continue
  fi
  for log in "$BASE/$core"/*.log; do
    [ -f "$log" ] || continue
    game=$(basename "$log" .log)
    # shellcheck disable=SC2086
    if python3 "$SDIR/compare.py" $SR "$BASE/$core" "$CAND/$core" "$game"; then
      :
    else
      DIFF=1
    fi
    echo ""
  done
done
if [ "$DIFF" = 0 ]; then echo "SUITE: ALL MATCH"; else echo "SUITE: DIFFS FOUND"; fi
exit $DIFF

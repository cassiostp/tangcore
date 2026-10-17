#!/bin/sh
# Run one SMS game through a built smoke model (on the host).
# Usage: sh run_game.sh <TAG> <GAME> <ROMFILE> <FRAMES> <OUTDIR> [SCRIPT]
# Env: SMOKE_BUILD (model root), SMOKE_SMS_SRC (smstang checkout for mboot.hex).
# SMOKE_DRY_RUN (if set: sleep instead of simulating, for limiter tests).
set -e
SDIR=$(cd "$(dirname "$0")" && pwd)
ROOT=$PWD
TAG=$1; GAME=$2; ROM=$3; FRAMES=$4; OUT=$5; SCRIPT=${6:-$SDIR/../inputs/sms_default.txt}
case $OUT in /*) ;; *) OUT=$ROOT/$OUT;; esac
case $ROM in /*) ;; *) ROM=$ROOT/$ROM;; esac
case $SCRIPT in /*) ;; *) SCRIPT=$ROOT/$SCRIPT;; esac
BLD=${SMOKE_BUILD:-$SDIR/build}
SRC=${SMOKE_SMS_SRC:-$SDIR}
B=$BLD/sms/$TAG
if [ -n "$SMOKE_DRY_RUN" ]; then
  mkdir -p "$OUT"
  sleep $((${SMOKE_DRY_SLEEP:-8} + ${#GAME} % 7))
  echo "DRYRUN_OK game=$GAME frames=$FRAMES"
  exit 0
fi
test -x "$B/obj/obj/Vsmstang_smoke" || { echo "model $TAG not built"; exit 1; }
mkdir -p "$OUT"
rm -f "$OUT/$GAME".log "$OUT/$GAME".aud "$OUT/$GAME".stdout "$OUT/$GAME".stderr "$OUT/$GAME"_f*.ppm
cp -f "$SRC/src/mboot.hex" "$OUT/mboot.hex" 2>/dev/null || true
DUMPS=$(python3 -c "print(','.join(str(f) for f in [60,300,600,900,1200] if f <= $FRAMES))")
echo "game=$GAME frames=$FRAMES dumps=$DUMPS"
T0=$(date +%s)
(cd "$OUT" && nice -n 19 "$B/obj/obj/Vsmstang_smoke" "$ROM" "$FRAMES" "$GAME" "$SCRIPT" "$DUMPS" >"$GAME.stdout" 2>"$GAME.stderr")
T1=$(date +%s)
echo "RUN_OK game=$GAME frames=$FRAMES wall=$((T1 - T0))s"

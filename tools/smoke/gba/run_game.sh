#!/bin/sh
# Run one GBA game through a built smoke model (on the host).
# Usage: sh run_game.sh <TAG> <GAME> <ROMFILE> <FRAMES> <OUTDIR>
# Env: SMOKE_BUILD (model root).
# SMOKE_DRY_RUN (if set: sleep instead of simulating, for limiter tests).
# Default input (compiled into the model, see tb_smoke_gba.cpp): A held 10
# frames of every 120, Start at 900-910. Dumps at 60/300/600/900/1200/1800.
set -e
SDIR=$(cd "$(dirname "$0")" && pwd)
ROOT=$PWD
TAG=$1; GAME=$2; ROM=$3; FRAMES=$4; OUT=$5
case $OUT in /*) ;; *) OUT=$ROOT/$OUT;; esac
case $ROM in /*) ;; *) ROM=$ROOT/$ROM;; esac
BLD=${SMOKE_BUILD:-$SDIR/build}
SRC=${SMOKE_GBA_SRC:-$SDIR}
B=$BLD/gba/$TAG
if [ -n "$SMOKE_DRY_RUN" ]; then
  mkdir -p "$OUT"
  sleep $((${SMOKE_DRY_SLEEP:-8} + ${#GAME} % 7))
  echo "DRYRUN_OK game=$GAME frames=$FRAMES"
  exit 0
fi
test -x "$B/obj/obj/Vgbatang_smoke" || { echo "model $TAG not built"; exit 1; }
mkdir -p "$OUT"
rm -f "$OUT/$GAME".log "$OUT/$GAME".aud "$OUT/$GAME".stdout "$OUT/$GAME".stderr "$OUT/$GAME"_f*.ppm "$OUT/$GAME"_save.bin
for hx in gba_bios_cultofgba.hex gba_bios_normmatt.hex; do
  cp -f "$SRC/src/memory/$hx" "$OUT/$hx" 2>/dev/null || true
done
DUMPS=$(python3 -c "print(','.join(str(f) for f in [60,300,600,900,1200,1800] if f <= $FRAMES))")
echo "game=$GAME frames=$FRAMES dumps=$DUMPS"
T0=$(date +%s)
(cd "$OUT" && "$B/obj/obj/Vgbatang_smoke" "$ROM" "$FRAMES" "$GAME" "$DUMPS" >"$GAME.stdout" 2>"$GAME.stderr")
T1=$(date +%s)
# normalize names to the suite convention (<game>.log already; .aud already)
echo "RUN_OK game=$GAME frames=$FRAMES wall=$((T1 - T0))s"

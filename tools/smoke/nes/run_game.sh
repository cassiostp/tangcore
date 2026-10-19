#!/bin/sh
# Run one NES game through a built smoke model (on the host).
# Usage: sh run_game.sh <TAG> <GAME> <ROMFILE> <FRAMES> <OUTDIR> [SCRIPT]
# Env: SMOKE_BUILD (model root), SMOKE_NES_SRC (nestang checkout, unused
# except for future DSP-hex-style needs; kept for symmetry),
# SMOKE_DRY_RUN (if set: sleep instead of simulating, for limiter tests).
set -e
SDIR=$(cd "$(dirname "$0")" && pwd)
ROOT=$PWD
TAG=$1; GAME=$2; ROM=$3; FRAMES=$4; OUT=$5; SCRIPT=${6:-$SDIR/../inputs/nes_default.txt}
case $OUT in /*) ;; *) OUT=$ROOT/$OUT;; esac
case $ROM in /*) ;; *) ROM=$ROOT/$ROM;; esac
BLD=${SMOKE_BUILD:-$SDIR/build}
B=$BLD/nes/$TAG
if [ -n "$SMOKE_DRY_RUN" ]; then
  mkdir -p "$OUT"
  sleep $((${SMOKE_DRY_SLEEP:-8} + ${#GAME} % 7))
  echo "DRYRUN_OK game=$GAME frames=$FRAMES"
  exit 0
fi
test -x "$B/obj/obj/Vnestang_smoke" || { echo "model $TAG not built"; exit 1; }
mkdir -p "$OUT" "$BLD/tmp"
rm -f "$OUT/$GAME".log "$OUT/$GAME".aud "$OUT/$GAME".stdout "$OUT/$GAME".stderr "$OUT/$GAME"_f*.ppm "$OUT/$GAME"_save.bin
R=$BLD/tmp/nes-$TAG-$GAME
rm -rf "$R"; mkdir -p "$R/roms"
SZ=$(python3 "$SDIR/make_rom.py" "$ROM" "$R/roms/game.hex" | grep '^SIZE=' | cut -d= -f2)
echo "$SZ" > "$R/roms/size.txt"
echo "game=$GAME size=$SZ frames=$FRAMES"
MCLK=$((FRAMES * 370000 + 5000000))
DUMPS=$(python3 -c "print(','.join(str(f) for f in [60,300,600,900,1200,1800] if f <= $FRAMES))")
echo "clk budget: $MCLK dumps: $DUMPS"
T0=$(date +%s)
(cd "$R" && "$B/obj/obj/Vnestang_smoke" -m "$MCLK" -o "$OUT/$GAME" -i "$SCRIPT" -d "$DUMPS" >"$OUT/$GAME.stdout" 2>"$OUT/$GAME.stderr")
T1=$(date +%s)
echo "RUN_OK game=$GAME frames=$FRAMES wall=$((T1 - T0))s"

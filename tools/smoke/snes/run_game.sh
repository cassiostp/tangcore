#!/bin/sh
# Run one SNES game through a built smoke model (on the host).
# Usage: sh run_game.sh <TAG> <GAME> <ROMFILE> <FRAMES> <OUTDIR> [SCRIPT]
#   TAG: model tag under $SMOKE_BUILD/snes/ (built by build.sh).
#   GAME: short name. ROMFILE: local ROM path (.sfc/.smc).
#   FRAMES: SNES frames to simulate. OUTDIR: per-run output dir (created).
#   SCRIPT: input script (default ../inputs/snes_default.txt).
# Env: SMOKE_BUILD (model root), SMOKE_SNES_SRC (snestang checkout for DSP hex).
set -e
SDIR=$(cd "$(dirname "$0")" && pwd)
ROOT=$PWD
TAG=$1; GAME=$2; ROM=$3; FRAMES=$4; OUT=$5; SCRIPT=${6:-$SDIR/../inputs/snes_default.txt}
case $OUT in /*) ;; *) OUT=$ROOT/$OUT;; esac
case $ROM in /*) ;; *) ROM=$ROOT/$ROM;; esac
BLD=${SMOKE_BUILD:-$SDIR/build}
SRC=${SMOKE_SNES_SRC:?set SMOKE_SNES_SRC to the snestang checkout}
B=$BLD/snes/$TAG
test -x "$B/obj/obj/Vsnestang_smoke" || { echo "model $TAG not built"; exit 1; }
mkdir -p "$OUT" "$BLD/tmp"
rm -f "$OUT/$GAME".log "$OUT/$GAME".aud "$OUT/$GAME".stdout "$OUT/$GAME".stderr "$OUT/$GAME"_f*.ppm "$OUT/$GAME"_bsram.bin "$OUT/$GAME"_aram.bin
R=$BLD/tmp/snes-$TAG-$GAME
rm -rf "$R"; mkdir -p "$R/roms"
SZ=$(python3 "$SDIR/make_rom.py" "$ROM" "$R/roms/game.hex" | grep '^SIZE=' | cut -d= -f2)
echo "$SZ" > "$R/roms/size.txt"
echo "game=$GAME size=$SZ frames=$FRAMES"
cp -f "$SRC/src/chip/DSP/"*.hex "$R/" 2>/dev/null || true
if [ ! -s "$R/random_4m_words.hex" ]; then
  python3 -c "open('$R/random_4m_words.hex','w').write('0000\n' * (4 * 1024 * 1024))"
fi
MCLK=$((FRAMES * 357380 + 20000000))
DUMPS=$(python3 -c "print(','.join(str(f) for f in [60,300,600,900,1200,1800,2400,3600] if f <= $FRAMES))")
echo "mclk budget: $MCLK dumps: $DUMPS"
T0=$(date +%s)
(cd "$R" && "$B/obj/obj/Vsnestang_smoke" -m "$MCLK" -o "$OUT/$GAME" -i "$SCRIPT" -d "$DUMPS" >"$OUT/$GAME.stdout" 2>"$OUT/$GAME.stderr")
T1=$(date +%s)
echo "RUN_OK game=$GAME frames=$FRAMES wall=$((T1 - T0))s"

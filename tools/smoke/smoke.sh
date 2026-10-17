#!/bin/sh
# TangCore smoke suite: every local ROM through each core in simulation.
#
# One command runs everything at given refs and writes a dated report:
#   sh smoke.sh --tag <run-tag> [--nes REF] [--snes REF] [--gba REF]
#               [--md REF] [--sms REF] [--jobs N] [--frames SCALE]
#
# Refs default to the round-5 integration heads. Each --<core> REF is any
# git ref of that core's repo (SHA, branch). Models build in docker
# (foreground); games run on the host, up to --jobs in parallel (default 4;
# keep to at most half the machine's cores — a GBA run uses ~4 threads).
# Outputs land in $SMOKE_ROOT/runs/<date>-<tag>/ with a REPORT.md comparing
# against $SMOKE_ROOT/baseline/ (the last accepted run; first run with
# --accept becomes the baseline).
#
# ROMs and everything derived stay under $SMOKE_ROOT (default
# ~/tangcore-smoke), never in the repo. Needs network once (SMS homebrew).
set -e
SDIR=$(cd "$(dirname "$0")" && pwd)
ROOT=$PWD

TAG=""
NES_REF=34d0349
SNES_REF=bab1dff
GBA_REF=39cbf2e
MD_REF=73c3147
SMS_REF=5159ae1
JOBS=4
ACCEPT=0
SHORT=0
while [ $# -gt 0 ]; do
  case $1 in
    --tag) TAG=$2; shift 2;;
    --nes) NES_REF=$2; shift 2;;
    --snes) SNES_REF=$2; shift 2;;
    --gba) GBA_REF=$2; shift 2;;
    --md) MD_REF=$2; shift 2;;
    --sms) SMS_REF=$2; shift 2;;
    --jobs) JOBS=$2; shift 2;;
    --accept) ACCEPT=1; shift;;
    --short) SHORT=1; shift;;
    *) echo "unknown arg $1"; exit 1;;
  esac
done
test -n "$TAG" || { echo "--tag required"; exit 1; }
# --short: routine regression depth (GBA still clears the ~65-frame PSG
# onset with margin). Full depth is for pre-QA weekends.
if [ "$SHORT" = 1 ]; then F_NES=900; F_SNES=600; F_GBA=400; F_MD=450; F_SMS=300;
else F_NES=1800; F_SNES=1200; F_GBA=1250; F_MD=900; F_SMS=600; fi

SMOKE_ROOT=${SMOKE_ROOT:-$HOME/tangcore-smoke}
ROMS=${SMOKE_ROMS:-$HOME/tangcore-test-bundle/test roms}
WORK=$SMOKE_ROOT/work
export SMOKE_BUILD=$SMOKE_ROOT/build
DATE=$(date +%Y%m%d-%H%M)
OUT=$SMOKE_ROOT/runs/$DATE-$TAG
mkdir -p "$OUT" "$WORK/checkouts"
echo "smoke run $TAG -> $OUT (jobs=$JOBS)"

# ---- checkouts (fresh clones, like every round-5 task) ----
co() { # co <core> <repo> <ref>
  D=$WORK/checkouts/$1-$TAG
  if [ ! -d "$D" ]; then git clone -q "https://github.com/cassiostp/$2.git" "$D"; fi
  git -C "$D" fetch -q origin
  git -C "$D" checkout -q "$3"
  echo "$1 @ $(git -C "$D" rev-parse --short HEAD)"
}
co nestang nestang "$NES_REF"
co snestang snestang "$SNES_REF"
co gbatang gbatang "$GBA_REF"
co mdtang mdtang "$MD_REF"
co smstang smstang "$SMS_REF"

# ---- builds (docker, foreground) ----
echo "=== builds ==="
docker run --rm --name smoke_build_nes_$TAG --user "$(id -u):$(id -g)" --entrypoint sh \
  -e CCACHE_DISABLE=1 -e JOBS=6 -e SMOKE_BUILD=/b \
  -v "$SDIR:/s" -v "$WORK/checkouts/nestang-$TAG:/r:ro" -v "$SMOKE_BUILD:/b" \
  -w /s/nes verilator/verilator:latest build.sh "nes-$TAG" /r
docker run --rm --name smoke_build_snes_$TAG --user "$(id -u):$(id -g)" --entrypoint sh \
  -e CCACHE_DISABLE=1 -e JOBS=6 -e SMOKE_BUILD=/b \
  -v "$SDIR:/s" -v "$WORK/checkouts/snestang-$TAG:/r:ro" -v "$SMOKE_BUILD:/b" \
  -w /s/snes verilator/verilator:latest build.sh "snes-$TAG" /r
docker run --rm --name smoke_build_gba_$TAG --user "$(id -u):$(id -g)" --entrypoint sh \
  -e CCACHE_DISABLE=1 -e JOBS=4 -e SMOKE_BUILD=/b \
  -v "$SDIR:/s" -v "$WORK/checkouts/gbatang-$TAG:/r:ro" -v "$SMOKE_BUILD:/b" \
  -w /s/gba verilator/verilator:v5.028 build.sh "gba-$TAG" /r
docker run --rm --name smoke_build_md_$TAG --user "$(id -u):$(id -g)" --entrypoint sh \
  -e CCACHE_DISABLE=1 -e JOBS=6 -e SMOKE_BUILD=/b \
  -v "$SDIR:/s" -v "$WORK/checkouts/mdtang-$TAG:/r:ro" -v "$SMOKE_BUILD:/b" \
  -w /s/md verilator/verilator:latest build.sh "md-$TAG" /r
docker run --rm --name smoke_build_sms_$TAG --user "$(id -u):$(id -g)" --entrypoint sh \
  -e CCACHE_DISABLE=1 -e JOBS=6 -e SMOKE_BUILD=/b \
  -v "$SDIR:/s" -v "$WORK/checkouts/smstang-$TAG:/r:ro" -v "$SMOKE_BUILD:/b" \
  -w /s/sms verilator/verilator:latest build.sh "sms-$TAG" /r
echo BUILD_ALL_OK

# ---- SMS homebrew (own dir, downloaded once) ----
SMSROM=$SMOKE_ROOT/roms/sms/peterlemon/VDP/HelloWorld/HelloWorld.sms
SMSAUD=$SMOKE_ROOT/roms/sms/peterlemon/PSG/SMSAudio/SMSAudio.sms
if [ ! -f "$SMSROM" ]; then
  mkdir -p "$SMOKE_ROOT/roms/sms"
  git clone --depth 1 https://github.com/PeterLemon/SMS.git "$SMOKE_ROOT/roms/sms/peterlemon"
fi

# ---- runs (host, parallel lanes) ----
echo "=== runs ==="
export SMOKE_SNES_SRC=$WORK/checkouts/snestang-$TAG
export SMOKE_GBA_SRC=$WORK/checkouts/gbatang-$TAG
export SMOKE_MD_SRC=$WORK/checkouts/mdtang-$TAG
export SMOKE_SMS_SRC=$WORK/checkouts/smstang-$TAG
LANES=""
run_bg() { # run_bg <log> <cmd...>
  LOG=$1; shift
  while [ "$(jobs -p | wc -l)" -ge "$JOBS" ]; do sleep 20; done
  "$@" >"$LOG" 2>&1 &
}
SN=$SDIR/snes/run_game.sh; NE=$SDIR/nes/run_game.sh
GB=$SDIR/gba/run_game.sh; MD=$SDIR/md/run_game.sh; SM=$SDIR/sms/run_game.sh
# NES (1800 frames = 30 s)
run_bg "$OUT/run-nes.log" sh "$NE" "nes-$TAG" smb3 "$ROMS/NES/Super Mario Bros. 3 (USA) (Rev 1).nes" $F_NES "$OUT/nes"
run_bg "$OUT/run-nes2.log" sh "$NE" "nes-$TAG" zelda "$ROMS/NES/Legend of Zelda, The (USA) (Rev 1).nes" $F_NES "$OUT/nes"
run_bg "$OUT/run-nes3.log" sh "$NE" "nes-$TAG" rockman3 "$ROMS/NES/Rockman 3 - Dr. Wily no Saigo! (Japan).nes" $F_NES "$OUT/nes"
run_bg "$OUT/run-nes4.log" sh "$NE" "nes-$TAG" rockman4 "$ROMS/NES/Rockman 4 - Aratanaru Yabou!! (Japan).nes" $F_NES "$OUT/nes"
# SNES (1200 frames = 20 s; CX4/SA-1 games cannot boot in Verilator: skipped)
run_bg "$OUT/run-snes.log" sh "$SN" "snes-$TAG" zelda "$ROMS/SNES/Legend of Zelda, The - A Link to the Past (USA).sfc" $F_SNES "$OUT/snes"
run_bg "$OUT/run-snes2.log" sh "$SN" "snes-$TAG" smw "$ROMS/SNES/Super Mario World (U) [!].smc" $F_SNES "$OUT/snes"
run_bg "$OUT/run-snes3.log" sh "$SN" "snes-$TAG" starfox "$ROMS/SNES/Star Fox (USA) (Rev 2).sfc" $F_SNES "$OUT/snes"
run_bg "$OUT/run-snes4.log" sh "$SN" "snes-$TAG" yoshi "$ROMS/SNES/Super Mario World 2 - Yoshi's Island (U) (V1.1).smc" $F_SNES "$OUT/snes"
run_bg "$OUT/run-snes5.log" sh "$SN" "snes-$TAG" mariokart "$ROMS/SNES/Super Mario Kart (USA).sfc" $F_SNES "$OUT/snes"
# GBA (1250 frames)
run_bg "$OUT/run-gba.log" sh "$GB" "gba-$TAG" aria "$ROMS/GBA/Castlevania - Aria of Sorrow (USA).gba" $F_GBA "$OUT/gba"
run_bg "$OUT/run-gba2.log" sh "$GB" "gba-$TAG" minish "$ROMS/GBA/Legend of Zelda, The - The Minish Cap (USA).gba" $F_GBA "$OUT/gba"
run_bg "$OUT/run-gba3.log" sh "$GB" "gba-$TAG" firered "$ROMS/GBA/Pokemon - FireRed Version (USA, Europe) (Rev 1).gba" $F_GBA "$OUT/gba"
run_bg "$OUT/run-gba4.log" sh "$GB" "gba-$TAG" zero "$ROMS/GBA/Metroid - Zero Mission (USA).gba" $F_GBA "$OUT/gba"
run_bg "$OUT/run-gba5.log" sh "$GB" "gba-$TAG" kirby "$ROMS/GBA/Kirby & The Amazing Mirror (USA).gba" $F_GBA "$OUT/gba"
run_bg "$OUT/run-gba6.log" sh "$GB" "gba-$TAG" mario "$ROMS/GBA/Mario & Luigi - Superstar Saga (USA).gba" $F_GBA "$OUT/gba"
wait
# Genesis (900 frames) + SMS homebrew (600 frames)
run_bg "$OUT/run-md.log" sh "$MD" "md-$TAG" sonic2 "$ROMS/Genesis/Sonic The Hedgehog 2 (World) (Rev A).md" $F_MD "$OUT/md"
run_bg "$OUT/run-md2.log" sh "$MD" "md-$TAG" ps2 "$ROMS/Genesis/Phantasy Star II (USA, Europe) (Rev A).md" $F_MD "$OUT/md"
run_bg "$OUT/run-sms.log" sh "$SM" "sms-$TAG" hello "$SMSROM" $F_SMS "$OUT/sms"
run_bg "$OUT/run-sms2.log" sh "$SM" "sms-$TAG" smsaudio "$SMSAUD" $F_SMS "$OUT/sms"
wait
echo RUN_ALL_OK

# ---- compare against baseline ----
echo "=== compare ==="
if [ ! -d "$SMOKE_ROOT/baseline" ]; then
  echo "no baseline yet; this run becomes reference material only."
  echo "re-run with --accept once reviewed to bless it as the baseline."
else
  sh "$SDIR/compare-all.sh" "$SMOKE_ROOT/baseline" "$OUT" >"$OUT/REPORT.md" 2>&1 || true
  cat "$OUT/REPORT.md"
fi
if [ "$ACCEPT" = 1 ]; then
  rm -rf "$SMOKE_ROOT/baseline"
  mkdir -p "$SMOKE_ROOT/baseline"
  for d in nes snes gba md sms; do
    if [ -d "$OUT/$d" ]; then cp -r "$OUT/$d" "$SMOKE_ROOT/baseline/$d"; fi
  done
  echo "accepted as new baseline"
fi
echo "SMOKE_DONE $OUT"

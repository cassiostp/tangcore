#!/bin/sh
# Build one SMS smoke model at a given ref.
# Usage: build.sh <TAG> <SRCDIR>
# Env: SMOKE_BUILD (model root, default ./build), JOBS (default 8).
# Run inside the verilator docker image. Source list from
# verilator/Makefile (upstream), sim_main.cpp replaced by tb_smoke_sms.cpp,
# stale verilog test_loader.v dropped (its instantiation is commented out;
# ROMs stream through rom_do like sim_main).
set -e
SDIR=$(cd "$(dirname "$0")" && pwd)
TAG=$1; SRC=$(cd "$2" && pwd)
BLD=${SMOKE_BUILD:-$SDIR/build}
JOBS=${JOBS:-8}
B=$BLD/sms/$TAG
R=$SRC
mkdir -p "$B/obj"
cp -f "$SDIR/tb_smoke_sms.cpp" "$B/obj/"
D=$R/src
SRCS="$D/smstang_top.sv \
 $D/jt89/jt89.v $D/jt89/jt89_mixer.v $D/jt89/jt89_noise.v $D/jt89/jt89_tone.v $D/jt89/jt89_vol.v \
 $D/t80/t80s.v $D/t80/t80.v $D/t80/t80_alu.v $D/t80/t80_mcode.v $D/t80/t80_reg.v \
 $D/vm2413_verilog/vm2413.sv $D/vm2413_verilog/attacktable.sv $D/vm2413_verilog/controller.sv $D/vm2413_verilog/envelopegenerator.sv \
 $D/vm2413_verilog/envelopememory.sv $D/vm2413_verilog/feedbackmemory.sv $D/vm2413_verilog/lineartable.sv \
 $D/vm2413_verilog/opll.sv $D/vm2413_verilog/outputgenerator.sv $D/vm2413_verilog/outputmemory.sv $D/vm2413_verilog/phasegenerator.sv \
 $D/vm2413_verilog/phasememory.sv $D/vm2413_verilog/registermemory.sv $D/vm2413_verilog/sinetable.sv $D/vm2413_verilog/slotcounter.sv \
 $D/vm2413_verilog/temporalmixer.sv $D/vm2413_verilog/voicememory.sv $D/vm2413_verilog/voicerom.sv $D/vm2413_verilog/operator.sv \
 $D/verilator/sdram_sim.v \
 $D/audiomix.v $D/dpram.v $D/hybrid_pwm_sd.v $D/io.v $D/MC8123.v $D/parts.v \
 $D/SEGASYS1_PRGDEC.v $D/spram.v $D/sprom.v $D/system.v $D/vdp.v $D/vdp_background.v \
 $D/vdp_cram.v $D/vdp_main.v $D/vdp_sprites.v $D/vdp_sprite_shifter.v $D/video.v \
 $D/cheatcodes.sv $D/compressor.sv $D/lightgun.sv"
verilator --top-module smstang_top +1800-2023ext+sv \
 -Wno-PINMISSING -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC \
 -cc --exe -o Vsmstang_smoke -CFLAGS "-O3" -I$D $SRCS "$B/obj/tb_smoke_sms.cpp" \
 --Mdir "$B/obj/obj" >"$B/obj/last-step.log" 2>&1; rc=$?; tail -5 "$B/obj/last-step.log"; test $rc -eq 0
make -j"$JOBS" -C "$B/obj/obj" -f Vsmstang_top.mk Vsmstang_smoke >"$B/obj/last-step.log" 2>&1; rc=$?; tail -5 "$B/obj/last-step.log"; test $rc -eq 0
test -x "$B/obj/obj/Vsmstang_smoke"
cp -f "$D/mboot.hex" "$B/obj/obj/mboot.hex" 2>/dev/null || true
echo BUILD_OK

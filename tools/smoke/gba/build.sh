#!/bin/sh
# Build one GBA smoke model at a given ref.
# Usage: build.sh <TAG> <SRCDIR>
# Env: SMOKE_BUILD (model root, default ./build), JOBS (default $(nproc)).
# Run inside the verilator docker image. The produced binary runs on the
# host (single process, --threads 4 at sim time). Adapted from the QA4
# gbaaudio probe (same fast SDRAM-poke ROM load, same per-frame aggregates).
set -e
SDIR=$(cd "$(dirname "$0")" && pwd)
TAG=$1; SRC=$(cd "$2" && pwd)
BLD=${SMOKE_BUILD:-$SDIR/build}
JOBS=${JOBS:-$(nproc)}
B=$BLD/gba/$TAG
R=$SRC
mkdir -p "$B/obj" "$B/run"
cp -f "$SDIR/tb_smoke_gba.cpp" "$SDIR/prelude.sv" "$B/obj/"
# Pre-frame-lock refs (before the upstream VERILATOR rel_toggle release)
# halt at the first vblank in sim: inject the identical sim-only shim so
# old and new builds run unhalted and compare apples-to-apples.
TOPSIM="$R/src/gbatang_top.sv"
if ! grep -q "rel_toggle_sim" "$R/src/gbatang_top.sv"; then
  python3 - "$R/src/gbatang_top.sv" "$B/obj/gbatang_top_sim.sv" <<'EOF'
import sys
src, dst = sys.argv[1], sys.argv[2]
t = open(src).read()
anchor = "wire hblank_trigger, vblank_trigger, videodma_start, videodma_stop;"
assert anchor in t, "vblank_trigger anchor not found"
shim = anchor + """
`ifdef VERILATOR
// SMOKE: no video module in the Verilator build to drive rel_toggle:
// release the native-rate frame lock from vblank itself (same as upstream
// 365e8a1). Sim-only; hardware unaffected.
reg rel_toggle_sim = 0;
always @(posedge clk16)
    if (vblank_trigger) rel_toggle_sim <= ~rel_toggle_sim;
assign rel_toggle = rel_toggle_sim;
`endif
"""
open(dst, "w").write(t.replace(anchor, shim, 1))
print("rel_toggle shim injected")
EOF
  TOPSIM="$B/obj/gbatang_top_sim.sv"
fi
D=$R/src
SRCS="$B/obj/prelude.sv $D/boards/verilator_sim.v $TOPSIM $D/cpu/gba_cpu.v $D/cpu/gba_cpu_thumbdecoder.v \
$D/memory/gba_dma.v $D/memory/gba_dma_module.sv $D/gpu/gba_drawer_merge.v $D/gpu/gba_drawer_mode0.v \
$D/gpu/gba_drawer_mode2.v \
$D/gpu/gba_drawer_mode345.v $D/gpu/gba_drawer_obj.sv $D/gpu/gba_gpu_colorshade.sv $D/gpu/gba_gpu_drawer.v \
$D/gpu/gba_gpu_timing.v $D/gpu/gba_gpu.v $D/gpu/gba_timer_module.v $D/gpu/gba_timer.v $D/gpu/linebuffer.v $D/common/sim_dpram_be.sv \
$D/memory/gba_memory.sv $D/memory/gba_flash_sram.sv $D/common/sim_spram_be.sv $D/common/eprocreg_gba.sv \
$D/common/syncramdual.v $D/common/dpram32_block.v $D/memory/gba_eeprom.sv $D/memory/mem_eeprom_sim.v \
$D/common/syncramdualnotpow2.v $D/peripherals/gba_joypad.v $D/memory/sdram_sim.v \
$D/sound/gba_sound.v $D/common/dual_clk_fifo.v $D/cpu/gba_interrupts.v \
$D/sound/gba_sound_ch1.v $D/sound/gba_sound_ch3.v $D/sound/gba_sound_ch4.v $D/sound/gba_sound_dma.v $D/memory/gba_gpio_rtc.v"
verilator --top-module gbatang_top +define+CONFIG_H --Mdir "$B/obj/obj" -O3 --threads 4 \
 -Wno-WIDTH -Wno-PINMISSING -Wno-UNOPTFLAT -Wno-BLKLOOPINIT -Wno-MULTIDRIVEN \
 -cc --exe -o Vgbatang_smoke -CFLAGS "-O3" -I$D -I$D/arm -I$D/common $SRCS "$B/obj/tb_smoke_gba.cpp" >"$B/obj/last-step.log" 2>&1; rc=$?; tail -5 "$B/obj/last-step.log"; test $rc -eq 0
make -j"$JOBS" -C "$B/obj/obj" -f Vgbatang_top.mk Vgbatang_smoke >"$B/obj/last-step.log" 2>&1; rc=$?; tail -5 "$B/obj/last-step.log"; test $rc -eq 0
test -x "$B/obj/obj/Vgbatang_smoke"
echo BUILD_OK

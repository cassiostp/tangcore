#!/bin/sh
# Build one NES smoke model at a given ref.
# Usage: build.sh <TAG> <SRCDIR>
# Env: SMOKE_BUILD (model root, default ./build), SMOKE_NES_MAXSIZE
#   (GameData array size, default 524304 = suite max +16), JOBS (default 10).
# Run inside the verilator docker image. The produced binary runs on the host.
# The model matches the 138K hardware config (+define+MEGA138K for the VRC
#-family ext-audio path); VRC7 FM uses the sim stub (silent in sim, as in
# every iverilog/Verilator NES sim).
set -e
SDIR=$(cd "$(dirname "$0")" && pwd)
TAG=$1; SRC=$(cd "$2" && pwd)
BLD=${SMOKE_BUILD:-$SDIR/build}
MAXS=${SMOKE_NES_MAXSIZE:-524304}
JOBS=${JOBS:-10}
B=$BLD/nes/$TAG
R=$SRC
mkdir -p "$B/obj" "$B/gen"
# patched top: joypad shim + audio tap (sample is unconsumed under VERILATOR)
python3 - "$R/src/nestang_top.sv" "$B/gen/nestang_top_sim.sv" <<'EOF'
import sys
src, dst = sys.argv[1], sys.argv[2]
t = open(src).read()
anchor = "assign overlay = 1'b0;"
assert anchor in t, "VERILATOR overlay anchor not found"
inject = anchor + """
reg [11:0] tb_joy1 /*verilator public*/ = 12'b0;
assign joy1_btns = tb_joy1;
reg [15:0] tb_sample /*verilator public*/ = 16'b0;
always @(posedge clk) tb_sample <= sample;
"""
open(dst, "w").write(t.replace(anchor, inject, 1))
print("patched top written")
EOF
# patched GameData: suite-max array, runtime stream length via roms/size.txt
python3 - "$R/src/game_data.v" "$B/gen/game_data_sim.v" "$MAXS" <<'EOF'
import sys
src, dst, maxs = sys.argv[1], sys.argv[2], sys.argv[3]
t = open(src).read()
t = t.replace("localparam INES_SIZE = 28688;", "localparam INES_SIZE = %s;" % maxs)
t = t.replace('"roms/nes15.hex"', '"roms/game.hex"')
t = t.replace("if (addr == INES_SIZE-1) begin        // done",
              "if (addr == LAST) begin        // done (runtime length)")
anchor = "reg [$clog2(INES_SIZE)-1:0] addr = 0;"
assert anchor in t
t = t.replace(anchor, anchor + """
reg [$clog2(INES_SIZE)-1:0] LAST;
initial begin
   integer fdfd;
   LAST = $clog2(INES_SIZE)'(INES_SIZE - 1);
   fdfd = $fopen("roms/size.txt", "r");
   if (fdfd != 0) begin
      if ($fscanf(fdfd, "%d", LAST) != 1) LAST = $clog2(INES_SIZE)'(INES_SIZE - 1);
      $fclose(fdfd);
   end
end""", 1)
open(dst, "w").write(t)
print("patched gamedata written")
EOF
# gen copy of generic.sv: drop Mapper28's redundant `wire prg_allow;`
# (it also has an `output prg_allow` port; Gowin tolerates the pair,
# Verilator calls it a duplicate. Port declares the net; behavior unchanged.)
python3 - "$R/src/mappers/generic.sv" "$B/gen/generic_sim.sv" <<'EOF'
import sys
src, dst = sys.argv[1], sys.argv[2]
lines = open(src).read().splitlines(True)
mod = None
out = []
removed = 0
for ln in lines:
    if ln.startswith("module "):
        mod = ln.split("(")[0].split()[1]
    if mod == "Mapper28" and ln.strip() == "wire prg_allow;":
        removed += 1
        out.append("// SMOKE: redundant with the output port\n")
        continue
    out.append(ln)
assert removed == 1, removed
open(dst, "w").write("".join(out))
print("generic_sim written")
EOF
grep -q "localparam INES_SIZE = $MAXS;" "$B/gen/game_data_sim.v"
cp -f "$SDIR/tb_smoke_nes.cpp" "$B/obj/"
verilator --top-module nestang_top --cc --exe \
  +define+MEGA138K \
  -CFLAGS "-O2" \
  -Wno-PINMISSING -Wno-IMPLICIT -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC -Wno-CASEINCOMPLETE -Wno-UNDRIVEN -Wno-BLKLOOPINIT -Wno-CASEX -Wno-CASEOVERLAP \
  -I"$R/src" \
  --Mdir "$B/obj/obj" --prefix Vnestang_smoke \
  -o Vnestang_smoke \
  "$R/src/verilator/config.sv" \
  "$B/gen/nestang_top_sim.sv" \
  "$B/gen/game_data_sim.v" \
  "$R/src/verilator/sdram_sim.v" \
  "$R/src/verilator/eseopll_stub.v" \
  "$R/src/apu.v" \
  "$R/src/autofire.v" \
  "$R/src/cart.sv" \
  "$R/src/compat.v" \
  "$R/src/dpram.v" \
  "$R/src/EEPROM_24C0x.sv" \
  "$R/src/game_loader.v" \
  "$B/gen/generic_sim.sv" \
  "$R/src/mappers/iir_filter.v" \
  "$R/src/mappers/JYCompany.sv" \
  "$R/src/mappers/misc.sv" \
  "$R/src/mappers/MMC1.sv" \
  "$R/src/mappers/MMC2.sv" \
  "$R/src/mappers/MMC3.sv" \
  "$R/src/mappers/MMC5.sv" \
  "$R/src/mappers/Namco.sv" \
  "$R/src/mappers/Sachen.sv" \
  "$R/src/mappers/Sunsoft.sv" \
  "$R/src/mappers/VRC.sv" \
  "$R/src/nes.v" \
  "$R/src/ppu.v" \
  "$R/src/t65/T65_Pack.v" \
  "$R/src/t65/T65.v" \
  "$R/src/t65/T65_ALU.v" \
  "$R/src/t65/T65_MCode.v" \
  "$B/obj/tb_smoke_nes.cpp"
make -C "$B/obj/obj" -f Vnestang_smoke.mk Vnestang_smoke -j"$JOBS"
echo BUILD_OK

#!/bin/sh
# Build one SNES smoke model at a given ref.
# Usage: sh build.sh <TAG> <SRCDIR>
#   TAG: e.g. round5, qa4. SRCDIR: snestang checkout at the wanted ref.
# Env: SMOKE_BUILD (model root, default ./build), SMOKE_SNES_MAXSIZE
#   (loader array size, default 4194816 = 4MB suite max), JOBS (default 10).
#   SMOKE_REAL_SDRAM=1 builds the sim/realsdram model (real sdram_snes +
#   sdram_chip) instead of src/verilator/sdram_sim.v. Same binary name and
#   CLI, so run_game.sh is unchanged.
# Run inside the verilator docker image (see smoke.sh); the produced binary
# runs on the host (arm64).
# The model carries the smoke joypad shim (tb_joy1) and CHIP_GSU, matching
# the console138k hardware config (CX4/SA-1 are VHDL: excluded, as in every
# Verilator SNES sim; their games cannot boot here).
set -e
SDIR=$(cd "$(dirname "$0")" && pwd)
TAG=$1; SRC=$(cd "$2" && pwd)
BLD=${SMOKE_BUILD:-$SDIR/build}
MAXS=${SMOKE_SNES_MAXSIZE:-4194816}
JOBS=${JOBS:-10}
B=$BLD/snes/$TAG
R=$SRC
mkdir -p "$B/obj" "$B/gen"
if [ -n "$SMOKE_REAL_SDRAM" ]; then
  # joypad shim plus loader held until sdram_busy falls (see sim/realsdram)
  python3 "$R/sim/realsdram/patch_top.py" "$R/src/snestang_top.v" "$B/gen/snestang_top_sim.v"
else
# patched top: joypad shim right after the VERILATOR `else line
python3 - "$R/src/snestang_top.v" "$B/gen/snestang_top_sim.v" <<'EOF'
import sys
src, dst = sys.argv[1], sys.argv[2]
lines = open(src).read().splitlines(True)
inject = [
    "reg [11:0] tb_joy1 /*verilator public*/ = 12'b0;\n",
    "controller_adapter tb_joy1_adapter (.clk(mclk), .snes_buttons({4'b0, tb_joy1}),\n",
    "    .snes_joy_strb(snes_joy_strb), .snes_joy_clk(snes_joy1_clk), .snes_joy_di(snes_joy1_di[0]));\n",
    "assign snes_joy1_di[1] = 1'b1;\n",
    "assign snes_joy2_di = 2'b11;\n",
]
out, done = [], False
for ln in lines:
    out.append(ln)
    if not done and ln.startswith("`else") and "VERILATOR" in ln and "ifndef" not in ln:
        out.extend(inject)
        done = True
assert done, "VERILATOR else not found"
open(dst, "w").write("".join(out))
print("patched top written")
EOF
fi
# sim config: tree config + CHIP_GSU (console138k has it)
sed 's|// `define CHIP_GSU|`define CHIP_GSU|' "$R/src/verilator/config.v" > "$B/gen/config_gsu.v"
grep -q '^`define CHIP_GSU' "$B/gen/config_gsu.v"
# quiet copies: neutralize the RTL's unconditional $fdisplay debug lines
# (stderr on every DMA/APU/DSPn event; display-only, no side effects) so
# overnight runs are not I/O-bound. Each $fdisplay(...) statement becomes
# `begin end` (paren-aware, so if/else bodies keep their shape).
# Diff-checked below: only display statements change.
python3 - "$R" "$B/gen" <<'EOF'
import sys
srcroot, genroot = sys.argv[1], sys.argv[2]
import os
files = ["cpu.v", "smp.v", "dsp.v", "ppuhoam.v",
         "spc700/spc700.v", "chip/DSP/DSPn.v"]
for rel in files:
    src = os.path.join(srcroot, "src", rel)
    dst = os.path.join(genroot, rel)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    t = open(src).read()
    out, i, n = [], 0, len(t)
    changed = 0
    while i < n:
        if t.startswith("$fdisplay", i) and (i == 0 or not (t[i-1].isalnum() or t[i-1] == '_')):
            # only neutralize calls outside // and /* */ comments
            j = i
            depth = 0
            instr = False
            while j < n:
                c = t[j]
                if instr:
                    if c == '"': instr = False
                elif c == '"': instr = True
                elif c == '(': depth += 1
                elif c == ')':
                    depth -= 1
                    if depth == 0:
                        break
                elif c == ';' and depth == 0:
                    break
                j += 1
            assert j < n and t[j] in ');', (rel, t[max(0,i-60):i+60])
            if t[j] == ')':
                assert t[j+1] == ';', (rel, t[max(0,i-60):i+80])
                j += 1
            out.append("begin end // SMOKE-QUIET was $fdisplay")
            i = j + 1
            changed += 1
        else:
            out.append(t[i])
            i += 1
    open(dst, "w").write("".join(out))
    print("%s: neutralized %d" % (rel, changed))
EOF
echo "--- quiet-copy diff (must show display statements only):"
diff -r "$R/src" "$B/gen" 2>/dev/null | grep '^[<>]' | grep -v "SMOKE-QUIET" | head -5 || true
TOPMOD=snestang_top
MEMSRC="$R/src/verilator/sdram_sim.v"
TBCPP="$B/obj/tb_smoke_snes.cpp"
LOADER="$SDIR/loader_smoke.v"
if [ -n "$SMOKE_REAL_SDRAM" ]; then
  TOPMOD=snes_realsdram_top
  sed -e 's/inout  reg \[15:0\] SDRAM_DQ/inout [15:0] SDRAM_DQ/' \
      -e 's/output reg  \[7:0\] bsram_dout/output [7:0] bsram_dout/' \
      "$R/src/sdram_cl2_2ch.v" > "$B/gen/sdram_snes_sim.v"
  ! grep -q "inout  reg" "$B/gen/sdram_snes_sim.v"
  ! grep -q "output reg  \[7:0\] bsram_dout" "$B/gen/sdram_snes_sim.v"
  MEMSRC="$B/gen/sdram_snes_sim.v $R/sim/cosim/sdram_chip.sv $R/sim/realsdram/snes_realsdram_top.sv"
  TBCPP="$R/sim/realsdram/tb_realsdram.cpp"
  LOADER="$R/sim/realsdram/test_loader.v"
else
  cp -f "$SDIR/tb_smoke_snes.cpp" "$B/obj/"
fi
# (quiet copies above replace these in the verilate line)
sed "s/@SIZE@/$MAXS/" "$LOADER" > "$B/obj/test_loader.v"
grep -q "localparam SIZE = $MAXS;" "$B/obj/test_loader.v"
EXTRA="$R/src/sa1_rom_cache.v $R/src/bwram_256k.v"
for f in $EXTRA; do test -f "$f" || EXTRA=$(echo "$EXTRA" | sed "s|$f||"); done
# shellcheck disable=SC2086
verilator --top-module "$TOPMOD" --cc --exe \
  -CFLAGS "-O2" \
  -Wno-PINMISSING -Wno-IMPLICIT -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC -Wno-CASEINCOMPLETE -Wno-CASEOVERLAP -Wno-UNDRIVEN \
  -I"$R/src" -I"$R/src/spc700" -I"$R/src/65C816" \
  --Mdir "$B/obj/obj" --prefix Vsnestang_smoke \
  -o Vsnestang_smoke \
  "$B/gen/config_gsu.v" \
  "$B/obj/test_loader.v" \
  $MEMSRC \
  "$B/gen/dsp.v" "$B/gen/snestang_top_sim.v" "$B/gen/smp.v" \
  "$R/src/controller_adapter.sv" \
  "$R/src/spc700/_spc700_package.v" "$R/src/spc700/addrgen.v" \
  "$R/src/spc700/addsub.v" "$R/src/spc700/alu.v" "$R/src/spc700/bcdadj.v" \
  "$R/src/spc700/mcode.v" "$R/src/spc700/muldiv.v" "$B/gen/spc700/spc700.v" \
  "$B/gen/cpu.v" "$R/src/ppu.v" "$R/src/CEGen.v" "$R/src/main.v" \
  "$R/src/ppucgram.v" "$R/src/chip/DSP/srtc_time_pack.v" \
  "$B/gen/ppuhoam.v" "$R/src/ppuoam.v" \
  "$R/src/65C816/common.sv" "$R/src/65C816/ALU.v" "$R/src/65C816/AddSubBCD.v" \
  "$R/src/65C816/AddrGen.v" "$R/src/65C816/BCDAdder.v" \
  "$R/src/65C816/bit_adder.v" "$R/src/65C816/mcode.sv" \
  "$R/src/65C816/P65C816.v" \
  "$R/src/chip/DSP/DSP_LHRomMap.v" "$R/src/chip/DSP/OBC1.v" \
  "$R/src/chip/DSP/SRTC.v" "$B/gen/chip/DSP/DSPn.v" \
  "$R/src/chip/GSU/GSU_PKG.v" "$R/src/chip/GSU/GSU.v" "$R/src/chip/GSU/GSUMap.v" \
  $EXTRA \
  "$R/src/smc_parser.v" "$R/src/SNES.v" "$R/src/vram.v" "$R/src/swram.v" \
  "$TBCPP"
make -C "$B/obj/obj" -f Vsnestang_smoke.mk Vsnestang_smoke -j"$JOBS"
echo BUILD_OK

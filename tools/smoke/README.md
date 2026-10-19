# TangCore smoke suite: every local ROM through each core in simulation

Overnight regression suite. For each core and each game ROM it builds (or
reuses) a full-system Verilator model at a given git ref, loads the ROM
through a back door (the core's own loader or a direct SDRAM poke — never
the firmware UART), runs a scripted input sequence, and captures frames at
fixed points (PPM), the audio stream, and save RAM, plus a hash of each. A
second run at another ref is compared frame-by-frame: the report flags the
first differing frame, pixels changed, audio RMS/spectrum change, and save
diffs. Baseline-free failures (black/frozen picture, silence, hang) are
flagged too.

ROMs and everything derived from them (frames, audio, saves, hashes,
baselines, reports) stay on the local machine under `~/tangcore-smoke/`,
never in this repo. Only harness code, input scripts (button timings) and
docs live here under `tools/smoke/`.

## One command

```sh
sh tools/smoke/smoke.sh --tag <run-tag> [--nes REF] [--snes REF] [--gba REF] \
    [--md REF] [--sms REF] [--jobs N] [--short] [--accept] [--dry-run]
```

Refs default to the round-5 integration heads. Each ref is any git ref of
that core's repo, so the suite compares arbitrary builds. It clones each
core fresh, builds the five models in docker, runs all games (at most
`--jobs`, default 4, at once across all cores — one global token bucket,
so a slow GBA leg no longer wedges the other cores behind a batch `wait`),
and writes a dated report to `~/tangcore-smoke/runs/<date>-<tag>/REPORT.md`
against the stored baseline. The first reviewed run takes `--accept` to
become the baseline.
`--dry-run` skips checkouts, builds and models (each game stub just
sleeps) to exercise the limiter without ROMs, network or docker; every
run appends `START`/`END` lines to `<out>/timeline.log` so the peak
overlap can be checked. Slots are per game run, not per thread: a GBA
model is built `--threads 4`, so one GBA run can occupy ~4 threads and
peak load is roughly 4x(concurrent GBA runs) + 1x(the rest) — keep
`--jobs` at most half the machine's cores. Build containers run through
`$DOCKER_RUN` (the `simrun` helper when it is on PATH, else plain
`docker run --rm`), with ccache on under `simrun`.
`--short` runs routine depth (NES 900 / SNES 600 / GBA 400 / MD 450 /
SMS 300 frames); full depth (1800/1200/1250/900/600) is for pre-QA
weekends — the GBA leg dominates either way (see Known limits).

Game list: NES (SMB3, Zelda, Rockman 3/4); SNES (Zelda, SMW, Star Fox,
Yoshi's Island, Mario Kart); GBA (all six local ROMs); Genesis (Sonic 2,
Phantasy Star II); SMS (two PeterLemon homebrew ROMs, downloaded once —
see below). CX4 games (Mega Man X3) and SA-1 games (Kirby Super Star,
Bomberman 5) cannot boot in Verilator (their RTL is VHDL) and are skipped
in sim; their coverage is hardware QA.

Containers are all named `${SIM_PREFIX:-sim<PID>}_smoke_*`: set `SIM_PREFIX`
when sharing the machine so two runs cannot clash. Sim-only build patches (display
neutralization, joypad shims, suite-max loader arrays) are documented
below; none change simulated behavior.

## Layout

- `smoke.sh` — the overnight runner (build + run + compare + dated report).
- `compare.py` / `compare-all.sh` — per-game and whole-run comparators.
- `inputs/` — button-timing scripts (`<frame> <buttons-hex>` edges; the
  value persists until the next edge). SNES/NES/MD/SMS layout is each
  core's 12-bit SNES-layout word; GBA inputs are compiled into its model
  (A 10/120 frames, Start at 900-910) and documented in
  `inputs/gba_default.txt`.
- `snes/` `nes/` `md/` `sms/` `gba/` — per-core harness: `build.sh` (docker
  Verilator model at a ref), `run_game.sh` (one game on the host),
  `tb_smoke_*` (capture main), plus `make_rom.py` ROM packers (SNES/NES).

## Per-core notes

**SNES** (`snes/`): full `snestang_top` (VERILATOR branch, `sdram_sim.v`
timing model) with `CHIP_GSU` (matches console138k; CX4/SA-1 excluded —
VHDL). ROMs stream through the real loader/`smc_parser` from a
`make_rom.py` `.hex` (64-byte validated header block + image; per-game
length via `roms/size.txt`, one model build serves all sizes). Joypad via
a `tb_joy1` + `controller_adapter` shim (same shape as the snesrain
harness). Capture: `rgb_out`/`x_out`/`y_out` pixels (vhash + PPM),
`audio_ready` stereo @~32 kHz, BSRAM + ARAM images + FNV hashes.
Frame counting: `y_out = {FIELD, OUT_Y}` with FIELD alternating every
SNES frame, so the `480->0` down-wrap lands every TWO SNES frames (the
`224->256` step is only +32 and is not counted); `frame = ff*2`. This is
also why older harnesses measured "~715k mclk per frame": that interval
is two SNES frames plus the sim-only 13-cycle frame-sync halt (~357,380
mclk per true frame, matching the core's documented 357,366). Build
neutralizes the RTL's unconditional `$fdisplay` debug lines (stderr on
every DMA/APU/DSPn event) in build-time copies — display-only statements
become `begin end`, verified by diff; overnight runs would otherwise be
I/O-bound.

**NES** (`nes/`): full `nestang_top` (VERILATOR branch,
`verilator/sdram_sim.v`, `+define+MEGA138K` for the VRC ext-audio path).
ROMs stream through the real `GameData`/`GameLoader` path (suite-max
array, per-game length via `roms/size.txt`). Joypad via a `tb_joy1` shim
on `joy1_btns`; audio via a `tb_sample` tap (`sample` is unconsumed under
VERILATOR and would otherwise be optimized away). Capture: `color`
indices + `cycle`/`scanline` (vhash + index PPMs; the canonical 64-entry
palette is applied offline for thumbnails), `sample` decimated to ~48
kHz, 8 KB battery window at SDRAM `0x3C0000`. VRC7 FM uses the sim stub
(silent in sim, as in every non-Gowin NES sim). `mappers/generic.sv`
Mapper28's redundant `wire prg_allow` (it also has an `output prg_allow`
port; Gowin tolerates the pair) is dropped in the build copy.

**Genesis** (`md/`): full `mdtang_top` (VERILATOR branch), source list
from `verilator/Makefile`, `sim_main.cpp` replaced by a headless main
(same loader protocol, clocks, `ce_pix`/`red`/`green`/`blue` capture and
48 kHz audio; upstream's `md->hs` renamed to the current `hsync`).
`fx68k/*.mem` microcode is staged into the run dir. SRAM window
(`0x820000`, 128 KB) dumped at end.

**SMS** (`sms/`): full `smstang_top` (VERILATOR branch), source list from
`verilator/Makefile` minus the stale `test_loader.v` (its instantiation
is commented out; ROMs stream through `rom_do` like `sim_main`),
headless main (`ce_pix`/`x`/`y`/`color` capture, VS frame ends, 48 kHz
audio). No save image (homebrew ROMs have no battery RAM). `mboot.hex`
staged into the run dir. ROMs: PeterLemon SMS `HelloWorld` (video) and
`SMSAudio` (PSG), cloned once to `~/tangcore-smoke/roms/sms/`.

**GBA** (`gba/`): adapted from the QA4 `gbaaudio` probe (same fast
SDRAM-poke ROM load, per-frame FIFO/PSG aggregates, 48 kHz audio, PPM
dumps, backup-RAM image), plus per-frame FNV hashes and configurable
dump frames. The committed `gba_bios_*.hex` files are staged into the run
dir. Refs predating the upstream VERILATOR frame-lock release get the
identical sim-only `rel_toggle` shim injected at build time (otherwise
they halt at the first vblank in sim); newer refs are untouched. GBA
builds use `verilator/verilator:v5.028` (the `:latest` image rejects the
RTL's non-ANSI parameter lists).

## Capture format (per game run `<out>/<game>.*`)

- `<game>.log` — `F <frame> ... vhash=<hex> nz=<nonzero-px>` per frame,
  `END ...` with frame/sample counts.
- `<game>.aud` — raw s16le stereo (32 kHz SNES, 48 kHz others).
- `<game>_f<frame>.ppm` — frame dumps at fixed frames.
- `<game>_{bsram,aram,save}.bin` — end-of-run images (core-dependent).
- `compare.py` reports: first differing frame, dump pixel diffs,
  windowed audio RMS + correlation + spectral distance, image diffs, and
  the baseline-relative black/frozen/silence/hang flags.

## Known limits

- Scripts drive boot/title/demo only; no game is played deep (Zelda
  naming, GSU later levels). Deterministic, but a bug past the script
  horizon is missed — same as any smoke test.
- Golden content is behavioral (the last accepted build), not a hardware
  reference: a bug present in the baseline stays green until heard/seen
  on hardware.
- Frame counts can drift ±1 ff between content-divergent builds (GSU wait
  states move frame boundaries); identical builds are bit-identical
  (verified by re-running).

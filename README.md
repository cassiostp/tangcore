# TangCore for the Tang Console 138K

A fork of [nand2mario's TangCore](https://github.com/nand2mario/tangcore), the FPGA gaming distribution for Sipeed Tang boards, **focused on the [Sipeed Tang Console 138K](https://sipeed.com/tangconsole)**. Every change here is built for, and tested on, the 138K. The goal is console-accurate play: games at their original speed, saves that just work, and the cartridge chips the big games need.

<div align="center">
  <img src="doc/tangcore-nes.png" width="300" />
  <img src="doc/tangcore-snes.png" width="300" />
  <img src="doc/tangcore-gba.png" width="300" />
  <img src="doc/tangcore-genesis.png" width="300" />
</div>

## Systems

| System | Core | Upstream |
|---|---|---|
| NES / Famicom | [nestang](https://github.com/cassiostp/nestang) | [nand2mario/nestang](https://github.com/nand2mario/nestang) |
| Super Nintendo | [snestang](https://github.com/cassiostp/snestang) | [nand2mario/snestang](https://github.com/nand2mario/snestang) |
| Game Boy Advance | [gbatang](https://github.com/cassiostp/gbatang) | [nand2mario/gbatang](https://github.com/nand2mario/gbatang) |
| Genesis / Mega Drive | [mdtang](https://github.com/cassiostp/mdtang) | [nand2mario/mdtang](https://github.com/nand2mario/mdtang) |
| Master System / Game Gear | [smstang](https://github.com/cassiostp/smstang) | [nand2mario/smstang](https://github.com/nand2mario/smstang) |

The firmware that runs the menu, the SD card, USB and saves on the board's BL616 microcontroller is [firmware-bl616](https://github.com/cassiostp/firmware-bl616). The menu's own FPGA design is [monitorcore](https://github.com/cassiostp/monitorcore).

## What this fork adds

On top of upstream TangCore:

- **Original game speed.** The HDMI output runs at each console's own refresh rate instead of 60.00 Hz, and the core is locked to it. Games run within 0.04 % of the original hardware, never slower, and the picture never tears. A standard-60 Hz build stays available for displays that refuse a native rate.

  | Console | Original | HDMI output |
  |---|---|---|
  | NES, SNES | 60.10 Hz | 60.11 Hz |
  | Genesis, Master System | 59.92 Hz | 59.93 Hz |
  | Game Boy Advance | 59.73 Hz | 59.75 Hz |

- **Battery saves on every core.** They're written to the SD card as the game saves:
  - NES and SNES;
  - Genesis, including EEPROM games;
  - GBA: SRAM, Flash and EEPROM, plus the real-time clock;
  - Master System.

  Super FX and SA-1 games save when you open the game menu, because their save RAM doubles as the chip's work memory.
- **An in-game menu**, opened with a button combination. It pauses the game and covers:
  - reset and close;
  - video settings;
  - the save status.
- **Video options:**
  - scanlines, with darkness and thickness;
  - brightness, contrast, saturation and gamma;
  - CRT masks;
  - the LCD grid for GBA and Game Gear;
  - Sharp and Soft smoothing.
- **More games:**
  - NES: the Konami VRC family and MMC5 with their sound chips, and Sunsoft 5B audio.
  - SNES:
    - Super FX (Star Fox, Yoshi's Island);
    - SA-1 (Kirby Super Star, Super Mario RPG);
    - CX4 (Mega Man X2/X3);
    - S-RTC;
    - blended hi-res text.
  - Genesis: 8 MB ROMs (Super Street Fighter II) and EEPROM saves.
  - GBA: the cartridge real-time clock and the Boktai solar sensor.
  - Game Gear mode.
- **A wall clock** (Options → Date & time) for the games that use one.
- **Faster loading:** GBA ROMs load about 4x faster over a negotiated 8 Mbaud link, checked by CRC.
- **Sound fixes:**
  - SNES: no crackle on high notes, and sound effects in Zelda 3's rain;
  - GBA: the tone channels at their real pitch;
  - Genesis: music pitch exact;
  - NES: no DC offset.
- **Reliability:**
  - USB pads recover after reloads;
  - menus can't be wedged by a stuck button;
  - the link between the BL616 and the FPGA heals itself;
  - a firmware watchdog restarts the firmware.
- **Diagnostics:**
  - a USB debug console over the BL616 port (live log and commands, no adapter);
  - a post-mortem log on the card after MODE;
  - on-screen diagnostic rows.
- **Experimental:** black frame insertion at 120 Hz on the NES (480p and 720p), for sharper motion on LCDs.

The newest of these are in each repository's `int/round5` branch while they're tested on hardware. They reach `main`/`master` once that test passes. Known problems are tracked as [issues](https://github.com/cassiostp/tangcore/issues) here and in [firmware-bl616](https://github.com/cassiostp/firmware-bl616/issues).

## Hardware

| Board | Status in this fork |
|---|---|
| **Tang Console 138K** | **The target.** Everything is built and tested on it. |
| Tang Console 60K | The cores still build, without the SNES coprocessors (Super FX, SA-1, CX4). Not tested on hardware here; 60K-only problems are filed with the [`console60k`](https://github.com/cassiostp/tangcore/issues?q=label%3Aconsole60k) label. |
| Tang Primer 25K, Mega 60K/138K, Nano 20K | Inherited from upstream; not built or tested here. |

## Installing

There are no releases from this fork yet. The firmware and cores are built by GitHub Actions (see [AGENTS.md](AGENTS.md) for the commands). With TangCore firmware already on the board:
1. Copy the cores into `cores/console138k/` on the SD card.
2. Flash the firmware from **Options → Flash mode**.

Never overwrite Sipeed's partner image at flash address 0x0. The [user guide](docs/user-guide/installation.md) covers first-time installation and controllers.

## Development

- **Branches:** fixes and features go on `fix/*` and `feature/*` branches. They're collected on `int/<round>`, built for hardware testing as `qa/<round>`, and merged into `main`/`master` once a round passes.
- **Issues:** cores and tooling are tracked [here](https://github.com/cassiostp/tangcore/issues), the firmware in [firmware-bl616](https://github.com/cassiostp/firmware-bl616/issues).
- **Testing:**
  - every core build fails on any timing violation;
  - each core has simulation benches in `sim/`;
  - the firmware runs on Linux in a host simulator, against a fake FPGA or the real cores' RTL in Verilator;
  - [`tools/smoke/`](tools/smoke) runs every local test ROM through its core in full simulation and compares the result with the last good build.
- **Working on it:** read [AGENTS.md](AGENTS.md), and the `AGENTS.md` in each repository.

Upstream's architecture and core-development guides are in [`docs/dev-guide/`](docs/dev-guide).

## Credits

[nand2mario](https://github.com/nand2mario) wrote TangCore and the cores this fork builds on. The cores also draw on:
- the MiSTer FPGA cores and their developers;
- srg320's SNES coprocessor designs (SA-1, Super FX, CX4);
- [hdl-util/hdmi](https://github.com/hdl-util/hdmi);
- [openFPGALoader](https://github.com/trabucayre/openFPGALoader) by Gwenhael Goavec-Merou.

## License

TangCore firmware is licensed under Apache 2.0. Each core keeps its original license; see its repository.

# TangCore Retro Gaming Installation Guide

## 🎮 Supported Devices

| Board Model       | FPGA Capacity | Compatible Cores             | Status        |
|-------------------|---------------|------------------------------|---------------|
| Tang Console 60K  | 60K LUT       | All cores                    | ✔️ Great     |
| Tang Console 138K | 138K LUT      | All cores                    | ✔️ Great     |
| Tang Primer 25K   | 25K LUT       | NESTang, SNESTang            | ✔️ Experimental (v0.7) |
NESTang/SNESTang   |

---

## 📦 Pre-Install Checklist
- [ ] Bouffalo Flash Cube v1.1 (in `tools/bflb_tools/bouffalo_flash_cube` of [Bouffalo SDK](https://github.com/bouffalolab/bouffalo_sdk), also a [local standalone version here](https://nand2mario.github.io/tangcore/user-guide/assets/bouffalo_flash_cube-1.1.zip))
- [ ] MicroSD card or USB 2.0 drive (FAT32/exFAT, ≤32GB recommended)
- [ ] USB-C OTG adapter with **power pass-through**
- [ ] Valid GBA BIOS (`gba_bios.bin`)
- [ ] Valid PC/XT BIOS (`bios.bin`)
- [ ] Latest [TangCore Release Package](https://github.com/nand2mario/tangcore/releases)

---

## 🔧 Firmware Installation

1. Extract release package
2. Launch Flash Cube → **Browse** → Select:
   ```bash
   /firmware-bl616/flash_<board-model>.ini
   ```
   *(e.g., `flash_console60k.ini`)*

3. Boot Mode Activation:
   - Hold **BOOT** button → Connect USB → Release after connection

   ![Boot Button](boot_button.jpg)

   - Note for Tang Primer 25K: the primer does not have a BOOT button. [Short these two pins](https://nand2mario.github.io/tangcore/user-guide/primer25k.jpg) and connect USB instead.

4. Flash Process:
   - Refresh COM ports → Select Port/SN → **Download**
   - Confirm success screen:

   ![Firmware Flash Success](dev_cube.png)  
   *Green status indicates successful programming*

---

## 🕹️ Game System Setup

### SD/USB drive content
```bash
📁 /                
├── 📁 cores/        # `cores` directory from release
│    ├── 📁 console60k/
│    └── 📁 console138k/
├── 📁 nes/          # .nes rom files
├── 📁 snes/         # .smc/.sfc files
├── 📁 gba/
│    └── 🗎 gba_bios.bin  # GBA BIOS
├── 📁 genesis/      # .bin/.md/.gen files
├── 📁 sms/          # .sms/.sg/.gg files
└── 📁 pc/           # .img floppy images
│    └── 🗎 bios.bin  # PC 5160 BIOS
```

The ROM folders list only the files the core can load: NES `.nes`; SNES `.smc` `.sfc`; Game Boy Advance `.gba`; MegaDrive/Genesis `.bin` `.md` `.gen`; Master System `.sms` `.sg` and Game Gear `.gg`; PC/XT floppy images `.img`. The `gba_bios.bin` in the GBA folder is hidden; it's loaded automatically. Folders are always listed. The Cores folder lists everything.

### Game saves

Games with battery-backed saves keep them on the drive: Master System and Game Gear games (such as Phantasy Star) in `saves/sms/<game>.sav`, SNES games (such as Super Mario World) in `saves/snes/<game>.sav`, NES games (such as The Legend of Zelda) in `saves/nes/<game>.sav`, MegaDrive/Genesis games (such as Phantasy Star II) in `saves/genesis/<game>.sav`, Game Boy Advance games (such as Pokémon Emerald) in `saves/gba/<game>.sav`. The folders are created when needed, and games without battery-backed RAM get no file. A save is written about 1 second after the game's first write to its battery RAM (about 4 seconds if the game's save was already written to the card in the last 10 seconds); a failed write is retried every 3 seconds, up to 5 times. A pending save is also flushed when you open a menu, load another game, reset or close the game, so it survives power-off. Opening the game menu checks a small save (up to 16 KB) against the core and writes it if the card differs. Super FX and SA-1 battery games save when the game menu opens (or the game closes): their save RAM doubles as the chip's work memory, so there are no writes while the game runs. While a SNES save is written the game pauses briefly (a few hundredths of a second for most games, about a second and a half for the largest 128 KB saves). The game menu shows a save status line: "Saved to card 12s ago" (seconds, minutes or hours depending on age), "Save on card is current", "Save: waiting to write", "Save FAILED: <reason>" (reasons: no reply, mkdir, create file, card write, card sync, rename), "Save: none written yet", "No battery save in this ROM" (NES, Game Boy Advance and MegaDrive/Genesis ROMs without battery RAM) or "No save RAM in this ROM" (SNES ROMs without save RAM). PC/XT has no battery saves and shows no line. A save made in the last ~1.3 s before pressing MODE is lost, because MODE reloads the FPGA and restarts the MCU at once. The files hold the raw save RAM, like MiSTer's cores (a MegaDrive/Genesis file is the start of MiSTer's 64 KB image). Genesis games with serial EEPROM keep the chip contents in the same file. The GBA save chip is detected from the ROM: SRAM/FRAM games keep 32 KB, Flash 64 or 128 KB, EEPROM 8 KB, and RTC games append the clock block described under [GBA](gba.md).

### Hardware Assembly
1. Connect components as shown (DS2 controller setup shown):
   ![](tangcore-user.jpg)

   *Left: OTG+USB | Right: DS2 PMOD+Wireless Receiver | Top: HDMI output*

2. Power sequence:
   - Insert USB drive → Connect OTG → Apply power

3. Initial Boot:
   - FPGA auto-programs (5-7 sec)
   - Main menu appears 

   ![](tangcore-menu.png)

   *Navigation using gamepad*

---

---

[Report Issue](https://github.com/nand2mario/tangcore/issues)


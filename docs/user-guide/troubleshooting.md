# Troubleshooting

## There's no video output

Check the following,

* Have you flashed the correct firmware for your board with Bouffalo Flash Cube? There's one .ini file for each board.
* Make sure USB drive contains `/cores/<your_board>/monitor.bin`. This is the bitstream that displays the menu.
* For Primer/Console, use USB-OTG dongle with power pass-through to connect USB and power.
* For Mega, either use OTG or the USB-A Host port on the board to connect USB drive. If USB-A is used, make sure the switch below is set to "DBG" instead of "FPGA".
* Do NOT connect the board to PC for power when you intend to run TangCore. Use a separate power supply. The Sipeed firmware enters JTAG/debug mode when PC is detected.
* For Tang Mega, don't forget to turn on power (long press POWER button on top)

## I cannot navigate the menu

Check controller connection. Dualshock controller support is most stable:

* For Mega, insert the DS2 pmod into the left pmod socket (pmod0).
* For Console, use the top pmod socket (pmod1).
* For Primer, use the middle pmod socket for DS2.

If you use USB controllers,

* Only the Sipeed-provided USB gamepads can be used with the on-board USB-A port. If a pad stops answering (a lost packet, an FPGA reload, a core load), the FPGA resets the port and sets the pad up again by itself in about 0.5 s; unplugging is not needed.
* Other types of USB gamepads needs a USB hub to work. Please follow instructions on the [controllers page](controllers.md).


## The menu misbehaves: no cursor, frozen, or only the TangCore title

Turn on the diagnostic line under **Options → Diagnostics**, or put `diag=1` in `tangcore.cfg` on the SD card. Two lines then appear on the top rows of every menu:

```
J000000 H000000 a00 c0  s  0 #07
SV w12 s3 f0 n0 b0 -C
```

| Part | Meaning |
|---|---|
| `J` | Buttons from the FPGA for players 1 and 2, 3 hex digits (12 bits) each. Pads in the console's two USB-A ports are read by the FPGA and appear here. |
| `H` | Pads read by the BL616 MCU, 3 hex digits (12 bits) per player. |
| `a` | First digit: the action the firmware is about to take. Second digit: 1 while a button combination is held. |
| `c` | The core the FPGA is running. 0 is the menu core. |
| `s` | Longest silent gap seen from the FPGA, in ms, capped at 999. |
| `#` | A counter that changes 4 times a second. It stops if the firmware's main loop stops. |
| `SV` | Battery-save counters: `w` saves written, `s` saves found already current, `f` failed, `n` save blocks the FPGA never answered, `b` save blocks cut short. `O` shows the UART receive FIFO overflowed at least once (`-` if not). `C` shows the game announced a save write (`-` if not). |

How to read it:

- **`J` or `H` changes while nobody is touching the pad:** the pad or its cable is faulty.
- **The second `a` digit stays 1:** the firmware thinks a combination is held, for example from a stuck button.
- **`#` stops counting:** the firmware has stopped responding. It restarts itself; see below.

If a menu over a running game stops answering for a second, wait: after a second of silence from the FPGA the firmware re-syncs the link by itself and the menu comes back (a `link: ... resync` line in the [debug log](debug-console.md)).

## The firmware stops responding

If the firmware ever hangs, a hardware watchdog restarts it by itself within about 15-20 seconds.

Pressing **MODE** reloads the FPGA from its flash (the menu core) and restarts the firmware; a short press is enough. In a game the firmware notices at once, when the reloaded FPGA answers as the menu core; in menus it takes about 200 ms. It works from any screen, including error message boxes. Message boxes close with **A**, **B** or **START**.

## An SNES game does not work

The core runs games with DSP-1/2/3/4, S-RTC and OBC-1. Daikaijuu Monogatari II uses the S-RTC clock; it reads the console clock, so set it under **Options → Date & time**.

Cartridges with S-DD1 (Star Ocean, Street Fighter Alpha 2), SPC7110, ST018 or BS-X show a "<chip> cartridge not supported yet" message and return to the browser. Dismiss it with **A**, **B** or **START**.

Super FX, SA-1 and CX4 cartridges load, but this build of the core has no such chip, so those games don't run.

## An NES game does not work

The core runs games on the common mappers, including MMC1 and MMC3, Sunsoft FME-7 and Namco 163 (with its expansion sound). Konami VRC, MMC5 and FDS games do not run in this build: those mapper slots are disabled in the core.

## A Genesis game does not work

ROMs up to 8 MB are supported, including Super Street Fighter II at 5 MB. Larger ROMs are refused. Games with serial EEPROM saves (NBA Jam TE, Wonder Boy in Monster World, Micro Machines 2) keep them in `saves/genesis/<game>.sav` like any battery-backed game.


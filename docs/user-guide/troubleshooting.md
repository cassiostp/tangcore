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

## The firmware stops responding

If the firmware ever hangs, a hardware watchdog restarts it by itself within about 15-20 seconds.

Pressing **MODE** reloads the FPGA from its flash (the menu core) and restarts the firmware; a short press is enough. In a game the firmware notices at once, when the reloaded FPGA answers as the menu core; in menus it takes about 200 ms. It works from any screen, including error message boxes. Message boxes close with **A**, **B** or **START**.

## An SNES game does not work

The supported SNES extension chips are DSP-1/2/3/4, S-RTC and OBC-1. SA-1 cartridges are not supported (Kirby Super Star, Super Mario RPG and Kirby's Dream Land 3, among others), and neither is Super FX (GSU).

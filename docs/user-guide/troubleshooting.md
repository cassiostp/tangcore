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

* Only the Sipeed-provided USB gamepads can be used with the on-board USB-A port. If it is not recognized, replug the pad.
* Other types of USB gamepads needs a USB hub to work. Please follow instructions on the [controllers page](controllers.md).


## The menu misbehaves: no cursor, frozen, or only the TangCore title

Turn on the diagnostic line under **Options → Diagnostics**, or put `diag=1` in `tangcore.cfg` on the SD card. A line like this then appears on the top row of every menu:

```
J00000000 H00000000 a00 c0  #123
```

| Part | Meaning |
|---|---|
| `J` | Buttons on the pads in the console's two USB-A ports: 4 hex digits per pad, player 1 then player 2. |
| `H` | Buttons on the pads in the BL616 USB-C port: 4 hex digits per pad, player 1 then player 2. |
| `a` | First digit: the action the firmware is about to take. Second digit: 1 while a button combination is held. |
| `c` | The core the FPGA is running. 0 is the menu core. |
| `#` | A counter that keeps changing while the menu is responsive. |

How to read it:

- **`J` or `H` changes while nobody is touching the pad:** the pad or its cable is faulty.
- **The second `a` digit stays 1:** the firmware thinks a combination is held, for example from a stuck button.
- **`#` stops counting:** the firmware has stopped responding. It restarts itself; see below.

## The firmware stops responding

If the firmware ever hangs, a hardware watchdog restarts it by itself within about 15-20 seconds.

Pressing **MODE** also restarts everything, from any screen, including error message boxes. Message boxes close with **A**, **B** or **START**.

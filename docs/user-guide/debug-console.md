# USB debug console

Watch and query the running firmware from a PC over USB. No serial adapter is needed.

You need: the SD card inserted (the console refuses to start when TangCore booted from a USB drive), a pad in one of the bottom USB-A ports, power on the power port, and a data cable for the BL616 port.

Start it:

1. Power on with the PC **unplugged** (a PC attached at power-up starts the board in debugger mode instead of TangCore).
2. **Options → USB debug console → ON**. Pads and drives on the BL616 port stop working while it is on; the bottom USB-A pads keep working.
3. Plug the PC into the BL616 port. It appears as a serial device (`/dev/ttyACM0` on Linux; `1209:0001` in `lsusb`). The OTG adapter or hub must come off that port: it acts as a device while the console is on.
4. Open any terminal: `tio /dev/ttyACM0`, `screen /dev/ttyACM0`, or `scripts/usbconsole.py` from the firmware repo (adds timestamps and saves a transcript file, best for catching a hang).

You get a live log stream and a `tc>` prompt. Commands:

| Command | What it does |
|---|---|
| `help` | Lists the commands. |
| `status` | Diagnostic rows, running core, uptime, heap. |
| `tasks` | Task states and stack high-water marks. |
| `log` | Dumps the log kept in RAM. |
| `saves` | Battery-save counters. |
| `link` | MCU to FPGA link counters. |
| `sniff on\|off` | One line per second with MCU to FPGA frame counts. |
| `wdtest` | Stalls the watchdog on purpose; asks for confirmation first. |
| `reboot` | Restarts the MCU (unplug the PC first, or the board starts in debugger mode). |

If the terminal is closed the firmware drops output instead of blocking. Nothing on the PC side can hang the firmware.

**MODE** with the console on reloads the menu without resetting the MCU, so the connection (and the transcript) stays up. The running game closes; a save written in the last second may not have reached the card yet. With the console off MODE behaves as described under [troubleshooting](troubleshooting.md).

Stop it: **Options → USB debug console → OFF**, then unplug the PC. The USB host (pads and drive) starts again. If BL616-port pads do not come back, power-cycle with the PC unplugged. The console is never remembered across power cycles; it is off after every boot.

Logs without a PC: the log is kept in RAM across MODE and watchdog resets. After such a reset the previous boot's log is written to `tangcore/lastlog.txt` on the card. The last three are kept (`lastlog.txt`, `lastlog1.txt`, `lastlog2.txt`). **Options → Save debug log** writes the current log to `tangcore/debuglog.txt` at any time.

Watch out: if the only pad is on the BL616 port, switching the console on leaves no working pad to switch it off again. Use a bottom USB-A pad, or type `reboot` in the console, unplug the PC and power-cycle.

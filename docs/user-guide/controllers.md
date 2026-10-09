# Game Controllers

TangCore supports several types of game controllers including Dualshock 2 (DS2), USB HID, and USB Xinput devices. Controller compatibility will continue to improve with future updates. 

Instructions for USB controllers,

* To connect the SNES-style USB controllers sold by Sipeed with Tang Console, you can plug them into the bottom two USA-A ports of the board. These two ports are connected to the FPGA, and currently the FPGA only supports this model of USB gamepad directly.
* **For other USB controllers, you need a USB hub** with at least 3 ports - one for the USB drive and two for controllers. The hub also needs to support "power passthrough", so it provides power to the board. Here is [a list of working USB hubs](https://github.com/nand2mario/tangcore/wiki/Compatible-USB-Hubs). The hub should be plugged into the bottom-left USB-C port of the board, i.e. connecting to the BL616 MCU.

Here are some test results for controllers.

| Controller | Status | Photo |
|-----|-----|-----|
| DualShock 2 or compatible | ✅ Fully working (requires DS2 PMOD adapter) | ![](gamepad_ds2.jpg){: style="width:150px"} |
| Sipeed SNES-style USB Controller | ✅ Fully working | ![](gamepad_snes.jpg){: style="width:150px"} |
| 8BitDo SN30 Pro Wired Controller | ✅ Fully working (USB hub needed) | ![](gamepad_sn30pro.jpg){: style="width:150px"} |
| 8BitDo Wireless USB Adapter | ✅ Fully working (USB hub needed) | ![](gamepad_8bitdo_adapter.jpg){: style="width:150px"} |

My personal favorite is the 8BitDo wireless adapter paired with an 8BitDo Pro 2 controller. It offers excellent button layout, reliable wireless connectivity, and minimal input lag. Please note that each adapter can only pair with one controller, so you'll need two adapters for two-player gaming.


## Ports

The two bottom USB-A ports are wired to the FPGA. The **left** one is player 1 and the **right** one is player 2. Most NES, SNES and Genesis games only respond to player 1, so plug a single pad into the left port. Game Boy Advance reads both ports as its one player.

## In-game controls

| Action | How |
|---|---|
| Open the game menu | Press **Select + Start + L** together. |
| Back to the game | Press **Select + Start + L** again, or choose **Resume**. |
| Quit the game | Hold **Select + Start + R** for 3 seconds, or choose **Quit game** in the game menu. |
| Restart everything | Press **MODE** on the console. It's like a power cycle. |

The game menu has **Resume**, **Quit game** and **<< Main menu**. On PC/XT it also has **Floppy drives**. **<< Main menu** keeps the game loaded, and the main menu then shows a **Game menu** item that leads back to it. On a USB keyboard, **F12** opens the game menu too.

The two button combinations can be changed under **Options** in the main menu:

1. Select **Menu** or **Quit**.
2. Hold the 3 buttons you want, all at once, for about a second, until "got it" appears.
3. Select **Save**.

A combination must be exactly 3 buttons and include **Select** or **Start**, so it can't go off by accident during play.

Settings are saved to `tangcore.cfg` in the root of the SD card or USB drive. You can also edit that file directly, for example `menu_combo=SELECT+START+L`.

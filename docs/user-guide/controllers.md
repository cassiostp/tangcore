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


## In-game controls

| Action | How |
|---|---|
| Open the in-game menu | Hold **Select** and press **Right** on the D-pad. Choose **<< Main Menu** to leave the game. |
| Go straight to the main menu | Hold **Select + Start + L** for a moment. |
| Reset the game | Hold **Select + Start + R** for a moment. |
| Reset the game (console button) | Tap **MODE**. |
| Go to the main menu (console button) | Hold **MODE** for 3 seconds. |

The two button combinations can be changed under **Options** in the main menu:

1. Select **Menu** or **Reset**.
2. Hold the 3 buttons you want, all at once, for about a second.
3. Select **Save**.

A combination must be exactly 3 buttons and include **Select** or **Start**, so it can't go off by accident during play. It also can't include both Select and Right, because that pair opens the in-game menu. Options can also change how long MODE has to be held, from 2 to 5 seconds.

Settings are saved to `tangcore.cfg` in the root of the SD card or USB drive. You can also edit that file directly, for example `menu_combo=SELECT+START+L`.

!!! note "How MODE works"
    MODE is the FPGA's reconfiguration button, so pressing it always reloads the FPGA, which drops the running game. TangCore notices this and either restarts the game or returns to the main menu, depending on how long MODE was held. Restarting means reloading the core and the ROM, so a tap takes a few seconds, and longer for big GBA ROMs. To reset a game instantly, use the reset combination instead.

On NES, SNES, Game Boy Advance, Master System and PC/XT, the reset combination restarts the game straight away. On Genesis it reloads the ROM, which takes a moment.

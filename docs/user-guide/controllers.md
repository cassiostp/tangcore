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

The two bottom USB-A ports are wired to the FPGA and support low-speed HID controllers only, such as simple USB SNES-style pads. The **left** one is player 1 and the **right** one is player 2. Most NES, SNES and Genesis games only respond to player 1, so plug a single pad into the left port. Game Boy Advance reads both ports as its one player.

The BL616 USB-C port (the one used for flashing, not the power port) is wired to the BL616 MCU. With a USB-C OTG adapter or a hub it works with full-speed USB controllers, including Xbox 360-style (XInput) wired controllers, up to 2 XInput pads.

## In-game controls

| Action | How |
|---|---|
| Open the game menu | Press **Select + Start + L** together. |
| Back to the game | Press **Select + Start + L** again, or choose **Resume**. |
| Close the game | Hold **Select + Start + R** for 3 seconds (by default), or choose **Close game** in the game menu. |
| Restart everything | Press **MODE** on the console. It's like a power cycle. |

The game menu has **Resume**, **Reset**, **Video...**, **Close game** and **<< Main menu**. On PC/XT it also has **Floppy drives**. **<< Main menu** keeps the game loaded, and the main menu then shows a **Game menu** item that leads back to it. On a USB keyboard, **F12** opens the game menu too.

## Video

**Video...** in the game menu changes how the picture looks. It has **Scanlines...**, **Color...**, **CRT mask...** and, on Game Boy Advance and Game Gear, **LCD grid...**. Changes reach the game at once and are stored when you leave a screen. Each screen has a **Preview** that hides the menu over the game, so you can see the result; **A** or **B** goes back. The game stays paused during a preview, except on SNES and MegaDrive/Genesis, where it keeps running but gets no button presses.

The settings apply to every core. They need the core .bin files from the same TangCore release; older cores ignore them. PC/XT has none of them.

### Scanlines

**Scanlines...** darkens thin lines between the lines of the game's picture, for a CRT look. Changes reach the game at once and are stored when you leave the screen.

* **Scanlines** — ON/OFF, off by default.
* **Darkness** — 25 %, 50 %, 75 % (the default) or 100 % (black).
* **Lines** — Thin or Thick.
* **Scale** — **Integer** makes every line of the game the same height on the TV, so the scanlines are evenly spaced; the picture gets a little smaller, with a border above and below. **Full** keeps the full-size picture and puts the lines at a fixed spacing on the TV; on Game Boy Advance and Master System they then don't line up with the game's lines.
* **Preview** — **Left/Right** changes the darkness, **Up/Down** the line thickness, **Start** the scale and **Select** turns them on or off.

### Color

* **Brightness**, **Contrast**, **Saturation** — from -4 to +3, 0 (the default) leaves the picture as the game draws it. Saturation -4 is black and white.
* **Gamma** — **Off**, **Darker**, **Brighter** or **CRT** (slightly darker mid-tones, like a CRT TV).
* **Reset colors** — puts all four back to their defaults.
* **Preview** — **Left/Right** changes the brightness, **Up/Down** the contrast, **Select** the saturation and **Start** the gamma.

### CRT mask

Imitates the pattern of red, green and blue stripes or dots on a CRT screen.

* **Mask** — **Off** (the default), **Grille** (vertical stripes), **Slot** (stripes broken into slots) or **Dot**.
* **Strength** — 1 to 4. A stronger mask makes the picture darker; raise **Brightness** under **Color...** to make up for it.
* **Preview** — **Left/Right** changes the strength, **Up/Down** the mask.

### LCD grid

On Game Boy Advance and Game Gear, draws the thin gaps between the pixels of a handheld's LCD screen. With the grid on, the picture uses the integer scale (see **Scale** above), even with scanlines off.

* **Grid** — ON/OFF, off by default.
* **Strength** — 1 to 4.
* **Preview** — **Left/Right** changes the strength, **Up/Down** turns the grid on or off.

## Options

The two button combinations can be changed under **Options** in the main menu:

1. Select **Menu** or **Reset**.
2. Hold the 3 buttons you want, all at once, for about a second, until "got it" appears.
3. Select **Save**.

A combination must be exactly 3 buttons and include **Select** or **Start**, so it can't go off by accident during play.

**Options** has these items:

* **Menu** — the button combination that opens the game menu.
* **Reset** — the button combination that resets the game. Keep holding it for **Hold to close** and the game closes.
* **Reset combo** — ON/OFF, turns the Reset combination on or off.
* **Hold to close** — how long the Reset combination must be held to close the game, from 2 to 5 seconds.
* **Diagnostics** — ON/OFF, shows a diagnostic line on the top row of menus, see [troubleshooting](troubleshooting.md).
* **Pause in game menu** — ON/OFF, on by default. While any menu is shown over a running game (the game menu, the main menu or Options), the game is paused and silent. It continues when you choose **Resume**. With it off, the game keeps running behind the menu. Either way the game never receives button presses while a menu is shown. Needs the updated cores; PC/XT keeps running.
* **Flash mode...** — restarts the console ready to be flashed on the BL616 USB-C port.
* **Save** — applies the changes and stores them.
* **<< Back** — leaves without saving.

The changes take effect when you choose **Save**. They are saved to `tangcore.cfg` in the root of the SD card or USB drive. You can also edit that file directly, for example `menu_combo=SELECT+START+L`, `pause_in_menu=0` or the video settings `scanlines=1`, `scanline_darkness=75`, `scanline_thick=0`, `scanline_full=0`, `video_brightness=0`, `video_contrast=0`, `video_saturation=0`, `video_gamma=0` (0 off, 1 darker, 2 brighter, 3 CRT), `crt_mask=0` (0 off, 1 grille, 2 slot, 3 dot), `crt_mask_strength=1`, `lcd_grid=0` and `lcd_grid_strength=1` (strengths go from 0 to 3, shown as 1 to 4).

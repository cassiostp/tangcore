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

The two bottom USB-A ports are wired to the FPGA and support low-speed HID controllers only, such as simple USB SNES-style pads. The **left** one is player 1 and the **right** one is player 2. Most NES, SNES and Genesis games only respond to player 1, so plug a single pad into the left port. Game Boy Advance reads both ports as its one player. If a pad stops answering, the FPGA resets the port and sets the pad up again by itself in about 0.5 s; unplugging is not needed.

The BL616 USB-C port (the one used for flashing, not the power port) is wired to the BL616 MCU. With a USB-C OTG adapter or a hub it works with full-speed USB controllers, including Xbox 360-style (XInput) wired controllers, up to 2 XInput pads.

## In-game controls

| Action | How |
|---|---|
| Open the game menu | Press **Select + Start + L** together. |
| Back to the game | Press **Select + Start + L** again, or choose **Resume**. |
| Close the game | Hold **Select + Start + R** for 3 seconds (by default), or choose **Close game** in the game menu. |
| Restart everything | Press **MODE** on the console. It reloads the FPGA from its flash (the menu core) and restarts the firmware; a short press is enough. |

The game menu has **Resume**, **Reset**, **Video...**, **Close game** and **<< Main menu**. On PC/XT it also has **Floppy drives**. Games with a sunlight sensor (Boktai 1/2/3) also have **Solar**. **Game options** and **Save states** are shown but not available yet. **<< Main menu** keeps the game loaded, and the main menu then shows a **Game menu** item that leads back to it. On a USB keyboard, **F12** opens the game menu too.

## Video

The HDMI output runs at each console's own refresh rate: NES and SNES 60.11 Hz, MegaDrive/Genesis and Master System 59.93 Hz, Game Boy Advance 59.75 Hz. The menu itself runs at standard 60.00 Hz. **Display** under **Options** in the main menu switches the games to 120 Hz (480p): the picture then runs at twice the console's own rate, from a separate `<core>_120hz.bin` next to the 60 Hz `<core>.bin` in `cores/console138k` (see [installation](installation.md)). The monitor must accept 480p at about 120 Hz. The 120 Hz builds run on the Console 138K.

**Video...** in the game menu changes how the picture looks. It has **Scanlines...**, **Color...**, **CRT mask...**, on Game Boy Advance and Game Gear **LCD grid...**, and **Scale**. While a 120 Hz build runs it also has **BFI**. Changes reach the game at once and are stored when you leave a screen. Scanlines, Color, CRT mask and LCD grid each have a **Preview** that hides the menu over the game, so you can see the result; **A** or **B** goes back. **A** on **Scale** switches it between Full and Integer. The game stays paused during a preview, except on SNES and MegaDrive/Genesis, where it keeps running but gets no button presses.

The settings apply to every core. They need the core .bin files from the same TangCore release; older cores ignore them. PC/XT has none of them.

### Scanlines

**Scanlines...** darkens thin lines between the lines of the game's picture, for a CRT look. Changes reach the game at once and are stored when you leave the screen.

* **Scanlines** — ON/OFF, off by default.
* **Darkness** — 25 %, 50 %, 75 % (the default) or 100 % (black).
* **Lines** — Thin or Thick.
* **Preview** — **Left/Right** changes the darkness, **Up/Down** the line thickness and **Select** turns them on or off.

### Scale

**Scale** in the Video menu sets how the game's picture fills the TV, whether scanlines are on or off:

* **Full** (the default) — the picture fills the screen and the scanlines sit at a fixed spacing on the TV; on Game Boy Advance and Master System they then don't line up with the game's lines.
* **Integer** — every line of the game gets the same whole number of TV rows, so the scanlines are evenly spaced; the picture gets a little smaller, with a border above and below.

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

### BFI

**BFI** in the Video menu is black-frame insertion, shown only while a 120 Hz build runs. Each game frame is shown on two screen refreshes; BFI darkens the second one, the way a CRT's phosphor fades between passes. It applies at once and is remembered.

* **Off** — both refreshes are lit: the normal picture. On a high-refresh LCD, 120 Hz alone is already worth it: the faster refresh speeds up the panel's overdrive, so there is less smearing even with BFI off.
* **Black** (the default) — every other refresh is black. Motion looks sharpest, but the picture is dimmer and flickers at 60 Hz.
* **Dim** — every other refresh is at half brightness. Less flicker than Black, less sharp.
* **Rolling** — instead of flashing the whole screen, a soft band of brightness sweeps down the screen about once a second. Same average brightness as Black, without the full-screen flash. Only the NES core does this; the other cores show Black instead.

The game menu is never blanked: it stays lit on every refresh, in every mode.

At 120 Hz, **Scale** works as at 60 Hz. **Full** fills a 4:3 640×480 picture on NES, SNES, MegaDrive/Genesis and Master System, and 533×480 on Game Gear. **Integer** gives every game line two TV lines, centred: 640×448 on NES, SNES and MegaDrive/Genesis (512×448 in the Genesis' 256-pixel-wide mode) and 512×384 on Master System; Game Gear gets three, 480×432. Game Boy Advance always shows a 3× picture that fills the whole 720×480 frame.

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
* **Display** — **60 Hz (720p)** or **120 Hz (480p)**, 60 Hz by default. A game started with 120 Hz loads the `<core>_120hz.bin` build when one is on the card, and the 60 Hz build with a one-line notice when there isn't. It takes effect on the next load.
* **Pause in game menu** — ON/OFF, on by default. While any menu is shown over a running game (the game menu, the main menu or Options), the game is paused and silent. It continues when you choose **Resume**. With it off, the game keeps running behind the menu. Either way the game never receives button presses while a menu is shown. Game Boy Advance, MegaDrive/Genesis and Master System pause; NES, SNES and PC/XT keep running.
* **Date & time** — the console clock, for example `2026-10-13 12:34`. It opens a field editor (see below). Games with a real-time clock read this clock.
* **Flash mode...** — restarts the console ready to be flashed on the BL616 USB-C port.
* **USB debug console** — ON/OFF, off by default. Streams the firmware log to a PC and takes commands, see the [USB debug console](debug-console.md) page.
* **Save debug log** — writes the log kept in RAM to `tangcore/debuglog.txt`.
* **Save** — applies the changes and stores them.
* **<< Back** — leaves without saving.

**Options** has 13 items in a 12-row window: scroll with **Up/Down**, and a `^` at the top edge means there is more above, `v` at the bottom more below. **Up** on the first item wraps to the last, **Down** on the last wraps to the first. Each press moves one step; holding the button does not repeat. The same wrap-around works in every menu.

### Date & time

The console has no battery-backed clock, so the clock is kept in software. It runs while the console is on, including across a MODE press, and stands still while the console is off. It is stored whenever settings are saved and every few minutes while idle in the menu. If the clock was never set it runs from 2000-01-01, so time-based events still advance within a session.

The editor shows Year, Month, Day, Hour and Minute. **Up/Down** picks the field, **Left/Right** changes it, **A** saves (seconds restart at 0), **B** cancels. The field wraps around: **Up** on Year goes to Minute, **Down** on Minute back to Year.

The changes take effect when you choose **Save**. They are saved to `tangcore.cfg` in the root of the SD card or USB drive. You can also edit that file directly, for example `menu_combo=SELECT+START+L`, `pause_in_menu=0` or the video settings `scanlines=1`, `scanline_darkness=75`, `scanline_thick=0`, `scale=full` (full or integer), `video_brightness=0`, `video_contrast=0`, `video_saturation=0`, `video_gamma=0` (0 off, 1 darker, 2 brighter, 3 CRT), `crt_mask=0` (0 off, 1 grille, 2 slot, 3 dot), `crt_mask_strength=1`, `lcd_grid=0`, `lcd_grid_strength=1` (strengths go from 0 to 3, shown as 1 to 4), `display=120` (60 for the 60 Hz build, 120 for the 120 Hz build), `bfi=black` (off, black, dim or rolling; only the 120 Hz build reads it) and `solar_pct=50` (Boktai sunlight, 0 to 100).


# Game Boy Advance core

The GBA core requires a BIOS to function properly. It is not distributed with TangCore because it is copyright protected. It should be located at `/gba/gba_bios.bin`, 16KB in size. An open source BIOS is included with TangCore, and will be used if the official BIOS is not found.

The BIOS is loaded automatically and does not show up in the GBA ROM list.

ROMs load over a faster link: the firmware negotiates the rate up with the core (up to 8 Mbaud) and checks the streamed bytes against a CRC the core reports back. If the check fails the screen says `Load check failed, retrying at 2M...` and the ROM goes again at the normal rate.

## Real-time clock

Games with a real-time clock read the console clock (**Options → Date & time**): Pokémon Ruby, Sapphire and Emerald (berries, tides, daily events), the Boktai trilogy, Sennen Kazoku and Rockman EXE 4.5, among others. A game that sets its own clock (Pokémon's clock set at game start) keeps that offset in its save file.

Pokémon and Boktai saves carry one extra 512-byte block with the clock, in the same layout the MiSTer GBA core uses, so `.sav` files move between the two. mGBA uses a different 16-byte footer instead: strip its last 16 bytes to move a save from mGBA, or strip the trailing 512-byte block to move one the other way.

## Sunlight (Boktai 1/2/3)

**Solar** in the game menu is the cartridge's sunlight sensor, as a light level. The Boktai games need sunlight to charge the Solar Gun. Turn it up for bright sun, down for shade or night. Each press adds 10 % and wraps to 0 %. It applies at once and is remembered.


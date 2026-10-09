# Debugging your core

## GAO debugging

Gowin FPGA debugging is mostly done through Gowin Analyzer Oscilloscope (GAO) over JTAG. JTAG is normally provided by the Sipeed BL616 firmware through USB. Now that TangCore has taken over the BL616, we need another way to provide JTAG functionality. We can do that with SOM connector on the FPGA module:

![](som-debug.jpg)

Here we use the 8-pin debug wire (provided by Sipeed with their boards), and Sipeed RV Debugger dongle (available on Sipeed store) to connect JTAG and UART (BL616_UART_TX to the RV debugger's RX pin).

This way we can use Gowin Analyzer Oscilloscope to debug our gateware as normal. You can also put the debugging bitstream (`ao_0.bin`) on the USB drive and use TangCore menu to program it if you need to.

## Monitor MCU-FPGA communcation

The BL616 MCU acts as the master in UART communication. Communication happens in commands and responses. If you need to observe the communication to help debugging your core, you can do that with the script `firmware-bl616/scripts/liveuart.py`. It will try to decode and dump the communication. There are two streams - BL616 to FPGA, and FPGA to BL616. So it would be better if you use a 2-UART USB-serial adapter, and connect the wires like this:

![](tangcore_uart.drawio.svg)

The TX pin carries the BL616-to-FPGA stream, and vice versa. For instance, core loading looks like this with `python tangcore\firmware-bl616\scripts\liveuart.py <com_port>` on the TX line,

```
fatfs: found /dev/sda
mount_volume: disk_initialize success
mount_volume: find_volume()=0

Writing 2303277 bytes...
ID=0001481b, status=70006020
Erase: pollFlag...
Erase: OK
Erase: disableCfg...
Erase: disableCfg done...
Erase: status=0x30000020

Erasing again...
ID=0001481b, status=30000020
Erase: pollFlag...
Erase: OK
Erase: disableCfg...
Erase: disableCfg done...
Erase: status=0x30000020

Load SRAM

Usercode=0x0000, status=0x70006020

Time: total=2169121 us, jtag=0 us, flash=0 us, writetdi=75 us<get_core_id>
<overlay_state:b'\x01'>

       -== TangCore ==-
NES
SNES
Game Boy Advance
MegaDrive / Genesis
Cores
Options
Version: Mar  7 2025<get_core_id>
<overlay_state:b'\x01'>
```

In addition to the text messages. Those in brackets (e.g. `<get_core_id>`) are commands sent to the FPGA, as listed in the protocol description next section. So this `printf`-style debugging is helpful in checking what is happening in realtime. You can check the firmware source code (`firmware-bl616/main.c`) to pinpoint problems.

You can also watch the traffic the other way (FPGA to MCU) on the other pin (BL616_UART_RX) with `python liveuart.py -f <com_port>`. It contains mostly joypad status updates and responses to other commands from the MCU.

## UART Protocol

The protocol is handled in `iosys_bl616.v`. The link runs at 2 Mbaud, 8N1. Every message in either direction is a frame:

```
0xAA  len[15:0]  cmd  payload
```

`len` is big-endian and counts the command byte plus the payload.

Commands from BL616 to FPGA:

| Command | Description |
|-----|-----|
|0x01|Get core ID (response 0x01). Used to identify the core and check that it's ready.|
|0x02|Get core config string (response 0x02)|
|0x03 x[31:0]|Set core config status|
|0x04 x[7:0] y[7:0]|Move overlay text cursor to (x, y)|
|0x05 <string>|Display string from cursor (length from the frame header)|
|0x06 loading_state[7:0]|Set loading state (0: core running, non-0: loading)|
|0x07 <data>|Load data to `rom_do` (length from the frame header)|
|0x08 x[7:0]|x[0] turns the overlay on/off|
|0x09 hid1[15:0] hid2[15:0]|USB joystick state from the BL616|
|0x0a <data_sector>|A 512-byte sector for the floppy data FIFO|
|0x0b addr[15:0] data[15:0]|Write to the disk management interface|
|0x0c <scancode>|PS/2 scancode (length from the frame header)|
|0x0d <string>|Debug print; cores ignore it|

Responses from FPGA to BL616:

| Response | Description |
|-----|-----|
|0x01 core_id[7:0]|Core ID|
|0x02 <string>|Core config string (length from the frame header)|
|0x03 joy1[15:0] joy2[15:0]|DS2/SNES joypad state. Sent when it changes, at most every 20 ms.|
|0x04 lba[15:0] <data_512>|Write a sector to disk|
|0x05 lba[15:0]|Read a sector from disk (answered with command 0x0a)|



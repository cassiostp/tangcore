#!/usr/bin/env python3
"""NES ROM -> smoke-loader .hex (host-side, ROM-derived output stays local).

GameData streams the whole iNES image (16-byte header included; the
GameLoader parses it). Output: one %02x byte per line. Prints SIZE=<n>.

Usage: make_rom.py <src.nes> <dst.hex>
"""
import sys

src, dst = sys.argv[1], sys.argv[2]
raw = open(src, "rb").read()
print("src bytes: %d" % len(raw))
assert raw[:4] == b"NES\x1a", "not an iNES ROM"
prg = raw[4] * 16384
chr = raw[5] * 8192
print("prg=%d chr=%d mapper=%d" % (prg, chr, (raw[6] >> 4) | (raw[7] & 0xF0)))
with open(dst, "w") as f:
    for b in raw:
        f.write("%02x\n" % b)
print("wrote %s entries=%d" % (dst, len(raw)))
print("SIZE=%d" % len(raw))

#!/usr/bin/env python3
"""Compare one smoke run against its baseline.

Usage: compare.py <base_dir> <cand_dir> <game> [--out report.md]
Both dirs hold <game>.log, <game>.aud, <game>_f<frame>.ppm, <game>_save.bin /
<game>_bsram.bin. Prints a markdown fragment and exits 0 (match) / 1 (diff).
Not ROM-derived: hashes/counts only. (PPM thumbnails referenced by path stay
local; only counts/hashes go into committed reports.)
"""
import hashlib
import os
import re
import struct
import sys

import numpy as np


def parse_log(path):
    frames = []
    end = {}
    with open(path) as f:
        for ln in f:
            m = re.match(r"F (\d+) .*?(?:samp=(\d+) )?vhash=([0-9a-f]+) nz=(\d+)", ln)
            if m:
                frames.append((int(m.group(1)), int(m.group(2) or 0),
                               m.group(3), int(m.group(4))))
            m = re.match(r"END .*?frames=(\d+) samples=(\d+)", ln)
            if m:
                end = {"frames": int(m.group(1)), "samples": int(m.group(2)), "done": True}
            m = re.match(r"# done frames=(\d+) samples=(\d+)", ln)
            if m:
                end = {"frames": int(m.group(1)), "samples": int(m.group(2)), "done": True}
    return frames, end


def read_ppm(path):
    d = open(path, "rb").read()
    assert d[:2] == b"P6", path
    i = d.index(b"255\n") + 4
    return np.frombuffer(d[i:], dtype=np.uint8)


def aud_rms(path, sr=32000, win=0.25):
    d = open(path, "rb").read()
    n = len(d) // 4
    a = np.frombuffer(d[:n * 4], dtype=np.int16).astype(np.float64).reshape(-1, 2)
    if len(a) == 0:
        return np.array([]), 0.0, 0
    # input files are ~32kHz DSP samples (SNES) or ~48kHz (others); treat
    # generically: window = sr samples
    w = int(sr * win)
    nr = len(a) // w
    rms = np.sqrt((a[:nr * w].reshape(nr, w, 2) ** 2).mean(axis=(1, 2)))
    peak = float(np.abs(a).max())
    nz = int((np.abs(a).max(axis=1) > 200).sum())
    return rms, peak, nz


def spectrum_change(bpath, cpath, sr=32000, nsec=5):
    """Mean abs difference of normalized log spectra over the first nsec."""
    def spec(p):
        d = open(p, "rb").read()
        n = min(len(d) // 4, sr * nsec)
        if n < 1024:
            return None
        a = np.frombuffer(d[:n * 4], dtype=np.int16).astype(np.float64).reshape(-1, 2)[:, 0]
        a -= a.mean()
        S = np.abs(np.fft.rfft(a * np.hanning(len(a))))
        S /= (S.max() or 1.0)
        return S
    sb, sc = spec(bpath), spec(cpath)
    if sb is None or sc is None or len(sb) != len(sc):
        return None
    return float(np.abs(np.log10(sb + 1e-6) - np.log10(sc + 1e-6)).mean())


def main():
    args = sys.argv[1:]
    sr = 32000
    if "--sr" in args:
        sr = int(args[args.index("--sr") + 1])
        args = [a for a in args if a not in ("--sr", str(sr))]
    base, cand, game = args[0], args[1], args[2]
    out = args[4] if len(args) > 4 and args[3] == "--out" else None
    if out is None and len(args) > 4 and args[3] == "--out":
        out = args[4]
    L = []
    diff = False

    bf, bend = parse_log(os.path.join(base, game + ".log"))
    cf, cend = parse_log(os.path.join(cand, game + ".log"))
    L.append("## %s" % game)
    L.append("base frames=%s samples=%s%s; cand frames=%s samples=%s%s" %
             (bend.get("frames", len(bf)), bend.get("samples"),
              "" if bend.get("done") else " (partial)",
              cend.get("frames", len(cf)), cend.get("samples"),
              "" if cend.get("done") else " (partial)"))
    if bend.get("done") and cend.get("done") and bend.get("frames") != cend.get("frames"):
        L.append("FLAG: frame count differs (hang/crash suspected)")
        diff = True

    # video hash sequence
    n = min(len(bf), len(cf))
    first = next((i for i in range(n) if bf[i][2] != cf[i][2]), None)
    if first is None:
        if len(bf) != len(cf):
            L.append("video: first %d frames identical; %s run longer (%d vs %d)" %
                     (n, "base" if len(bf) > len(cf) else "cand", len(bf), len(cf)))
        else:
            L.append("video: %d frames, all vhash identical" % n)
    else:
        L.append("FLAG: video first differs at frame %d (base %s cand %s)" %
                 (bf[first][0], bf[first][2], cf[first][2]))
        diff = True

    # absolute picture checks on candidate, relative to base: a condition
    # both builds share (static demo, silent title) is reported, not a diff.
    def is_black(fr): return len(fr) > 0 and all(r[3] == 0 for r in fr)
    def is_frozen(fr): return len(fr) > 12 and len(set(r[2] for r in fr[10:])) <= 1
    if cf:
        cb, fb = is_black(cf), is_frozen(cf)
        bb, fb0 = is_black(bf), is_frozen(bf)
        if cb and not bb:
            L.append("FLAG: candidate picture BLACK throughout (%d frames)" % len(cf))
            diff = True
        elif cb:
            L.append("note: picture black throughout in both builds")
        if fb and not fb0:
            L.append("FLAG: candidate picture FROZEN (one vhash after boot)")
            diff = True
        elif fb:
            L.append("note: picture static in both builds (nz last=%d)" % cf[-1][3])
        if not cb and not fb:
            L.append("picture: nonzero, animating (nz last=%d)" % cf[-1][3])

    # PPM dumps
    for f in sorted(os.listdir(base)):
        m = re.match(re.escape(game) + r"_f(\d+)\.ppm$", f)
        if not m:
            continue
        cb = os.path.join(base, f)
        cc = os.path.join(cand, f)
        if not os.path.exists(cc):
            L.append("FLAG: dump %s missing in candidate" % f)
            diff = True
            continue
        a, b = read_ppm(cb), read_ppm(cc)
        if a.shape != b.shape:
            L.append("FLAG: dump %s shape %s vs %s" % (f, a.shape, b.shape))
            diff = True
            continue
        nd = int((a != b).reshape(-1, 3).any(axis=1).sum())
        if nd:
            L.append("FLAG: dump %s differs: %d/%d px (%.2f%%)" %
                     (f, nd, a.shape[0] // 3, 100.0 * nd / (a.shape[0] // 3)))
            diff = True
        else:
            L.append("dump %s: pixel-identical" % f)

    # audio
    rb, pb, zb = aud_rms(os.path.join(base, game + ".aud"), sr=sr)
    rc, pc, zc = aud_rms(os.path.join(cand, game + ".aud"), sr=sr)
    if len(rb) == 0 or len(rc) == 0:
        if not (bend.get("done") and cend.get("done")) and abs(len(rb) - len(rc)) <= 2:
            L.append("audio: partial runs (%d/%d windows); skipped" % (len(rb), len(rc)))
        else:
            L.append("FLAG: audio length/empty differs (base %d cand %d windows)" %
                     (len(rb), len(rc)))
            diff = True
    elif len(rb) != len(rc) and min(len(rb), len(rc)) / max(len(rb), len(rc)) < 0.75 and max(len(rb), len(rc)) >= 4:
        L.append("FLAG: audio window count differs (base %d cand %d)" % (len(rb), len(rc)))
        diff = True
    else:
        nw = min(len(rb), len(rc))
        rb, rc = rb[:nw], rc[:nw]
        drms = float(np.abs(rb - rc).max())
        if len(rb) > 2 and rb.std() > 0 and rc.std() > 0:
            corr = float(np.corrcoef(rb, rc)[0, 1])
        else:
            corr = 1.0 if drms == 0 else 0.0
        sp = spectrum_change(os.path.join(base, game + ".aud"),
                             os.path.join(cand, game + ".aud"), sr=sr)
        L.append("audio: windows=%d base_rms=%.1f cand_rms=%.1f max_win_drms=%.1f corr=%.4f spec=%.3f peak=%d/%d" %
                 (len(rb), rb.mean(), rc.mean(), drms, corr,
                  sp if sp is not None else -1, pb, pc))
        if zc == 0 and len(rc):
            if zb > 0:
                L.append("FLAG: candidate audio SILENT throughout")
                diff = True
            else:
                L.append("note: audio silent in both builds")
        elif drms > 0.5 * (rb.mean() + 1.0) or corr < 0.99 or (sp is not None and sp > 0.15):
            L.append("FLAG: audio differs (rms/spectrum)")
            diff = True

    # GBA PSG aggregate compare: per-frame wrap=a,b,c totals (pitch proxy).
    # The PSG pitch defect is invisible in .aud at title (digital silence in
    # both builds) but changes wavetable-wrap rates ~3.2x once channels go
    # on-idle (~frame 65 in Aria). Sum over frames >= 65, flag ratio > 1.5.
    def gba_wraps(path):
        tot = [0, 0, 0]
        n = 0
        with open(path) as f:
            for ln in f:
                m = re.match(r"F (\d+) .*?wrap=(\d+),(\d+),(\d+)", ln)
                if m and int(m.group(1)) >= 65:
                    for i in range(3):
                        tot[i] += int(m.group(2 + i))
                    n += 1
        return tot, n
    bw, bn = gba_wraps(os.path.join(base, game + ".log"))
    cw, cn = gba_wraps(os.path.join(cand, game + ".log"))
    if bn > 10 and cn > 10 and sum(bw) + sum(cw) > 0:
        rs = []
        for i in range(3):
            if bw[i] + cw[i] > 0:
                rs.append(max(bw[i], cw[i]) / (min(bw[i], cw[i]) or 1))
        rmax = max(rs) if rs else 1.0
        L.append("psg wraps base=%s cand=%s over %d/%d frames ratio=%.2f" %
                 (bw, cw, bn, cn, rmax))
        if rmax > 1.5:
            L.append("FLAG: PSG wrap rate differs (pitch change)")
            diff = True

    # save images (any *_save.bin / *_bsram.bin / *_aram.bin)
    for f in sorted(os.listdir(base)):
        if not (f.startswith(game) and f.endswith(".bin")):
            continue
        cb = os.path.join(base, f)
        cc = os.path.join(cand, f)
        if not os.path.exists(cc):
            L.append("FLAG: image %s missing in candidate" % f)
            diff = True
            continue
        a, b = open(cb, "rb").read(), open(cc, "rb").read()
        if a == b:
            L.append("image %s: identical (%d B)" % (f, len(a)))
        else:
            nd = sum(1 for x, y in zip(a, b) if x != y) + abs(len(a) - len(b))
            firstd = next((i for i, (x, y) in enumerate(zip(a, b)) if x != y), -1)
            L.append("FLAG: image %s differs: %d/%d B first@%d" % (f, nd, len(a), firstd))
            diff = True

    L.append("verdict: %s" % ("DIFF" if diff else "MATCH"))
    txt = "\n".join(L) + "\n"
    if out:
        open(out, "w").write(txt)
    print(txt, end="")
    return 1 if diff else 0


if __name__ == "__main__":
    sys.exit(main())

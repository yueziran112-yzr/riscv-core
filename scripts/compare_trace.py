#!/usr/bin/env python3
"""Compare two commit logs line by line (retired PC, instruction, rd write).
Works for  DUT-vs-DUT (pipeline vs single-cycle)  and  DUT-vs-Spike (--log-commits).
usage: compare_trace.py ref.log dut.log [--min-pc 0x80000000] [--slack 8]
The first differing line is the first wrong instruction -> start debugging there."""
import re, sys, argparse
ap = argparse.ArgumentParser()
ap.add_argument("ref"); ap.add_argument("dut")
ap.add_argument("--min-pc", type=lambda x: int(x, 0), default=0x80000000,
                help="ignore Spike's boot-ROM instructions below this PC")
ap.add_argument("--slack", type=int, default=8,
                help="allowed length difference (a pipeline stops a few instructions earlier)")
a = ap.parse_args()

# core   0: 3 0x80000000 (0x00000297) x5  0x80000000          (Spike --log-commits style)
pat = re.compile(r"0x([0-9a-fA-F]+)\s+\(0x([0-9a-fA-F]+)\)(?:\s+x(\d+)\s+0x([0-9a-fA-F]+))?")
def load(path):
    out = []
    for ln in open(path):
        m = pat.search(ln)
        if not m: continue
        pc = int(m.group(1), 16)
        if pc < a.min_pc: continue
        rd = int(m.group(3)) if m.group(3) else None
        val = int(m.group(4), 16) & 0xFFFFFFFF if m.group(4) else None
        out.append((pc & 0xFFFFFFFF, int(m.group(2), 16), rd, val))
    return out

ref, dut = load(a.ref), load(a.dut)
n = min(len(ref), len(dut))
for i in range(n):
    if ref[i] != dut[i]:
        fmt = lambda t: f"pc={t[0]:08x} instr={t[1]:08x} " + (f"x{t[2]}={t[3]:08x}" if t[2] is not None else "(no reg write)")
        print(f"MISMATCH at commit #{i}\n  ref: {fmt(ref[i])}\n  dut: {fmt(dut[i])}")
        sys.exit(1)
if abs(len(ref) - len(dut)) > a.slack:
    print(f"LENGTH differs too much: ref={len(ref)} dut={len(dut)}"); sys.exit(1)
print(f"OK: {n} commits identical (ref={len(ref)}, dut={len(dut)})")
